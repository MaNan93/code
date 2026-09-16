#!/usr/bin/env python3
"""
plm -- unified CLI for the PIPE Lane Mapper generator/validator.

Replaces the two old standalone scripts (plm_gen_rtl.py / plm_gen_tb.py)
with subcommands of one entry point, reconciling the ways they used to be
invoked (the Makefile: a bare config-set name + --quiet; the Qt front
end: a full workspace path + --verible-path/--verible-flags, no --quiet)
as different combinations of the same optional flags.

    plm generate rtl  --config X [--sel-mode {sync,comb}] [--arch ...] [--pclk-mode ...]
                       [--verible-path P] [--verible-flags JSON] [--dpr] [--quiet]
    plm generate tb   --config X [--arch ...] [--pclk-mode ...]
                       [--verible-path P] [--verible-flags JSON] [--dpr] [--quiet]
    plm generate all  --config X [--sel-mode ...] [--arch ...] [--pclk-mode ...]
                       [--verible-path P] [--verible-flags JSON] [--dpr] [--quiet]
    plm validate      --config X

Every generation flag is passed on the command line. There is no per-config-set
file pinning them -- a config set is exactly its three CSVs, and the caller
(the Makefile, or the Qt front end's Generation page) supplies the flags.

--config accepts either a bare config-set name (resolved under test/)
or a full path -- resolve_set() already makes that transparent, see
plm.core.paths.

Also runnable as `python -m plm.cli.main ...` without relying on the
`plm` console-script being on PATH -- this is how the Qt front end and the
Makefile invoke it (via sys.executable -m, not the installed script name),
since that only depends on the interpreter being able to import plm, not on
PATH having the venv's script directory on it.

    plm -gui

`-gui` (also accepted as `--gui`) launches the Qt desktop front end.
"""

import argparse
import json
import sys

from plm.core.exporter import export_rtl, export_tb
from plm.core.gen_flags import validate_arch
from plm.core.model import load
from plm.core.paths import resolve_set

ARCH_CHOICES = ["original_pipe", "serdes"]
PCLK_MODE_CHOICES = ["pclk_as_phy_output", "pclk_as_phy_input"]
SEL_MODE_CHOICES = ["sync", "comb"]

ARCH_HELP = (
    "Which PHY macro family this config set targets: original_pipe (a classic "
    "PIPE PHY, only supports --pclk-mode pclk_as_phy_output) or serdes (a "
    "SerDes-style macro, only supports --pclk-mode pclk_as_phy_input). Purely "
    "a cross-check against --pclk-mode."
)
PCLK_MODE_HELP = (
    "Which clock architecture the design uses: pclk_as_phy_output (default) -- "
    "each PHY lane generates its own PCLK, ctrl_pclk is derived from it and "
    "echoed back; pclk_as_phy_input -- each controller has its own external "
    "reference clock and does its own division. Must match between an rtl and "
    "tb generated for the same config set."
)
VERIBLE_PATH_HELP = (
    "Path to verible-verilog-format, for auto-formatting generated .sv files. "
    "Defaults to searching PATH; if not found either way, output is left "
    "unformatted (cosmetic, not required)."
)
VERIBLE_FLAGS_HELP = (
    "JSON object of verible-verilog-format flags, replacing this tool's own "
    "default flag set entirely. Advanced; normally left unset."
)
DPR_HELP = (
    "Also (RTL) / also instantiate (testbench) the DPR (diagnostic probe) "
    "overlay -- must match between an rtl and tb generated for the same "
    "config set."
)


def _add_config_arg(ap):
    ap.add_argument(
        "--config",
        default=None,
        metavar="SET",
        help="Config set: a name under test/, or a path. Omitting it lists "
        "the available set names.",
    )


def _add_shared_gen_args(ap, *, sel_mode):
    if sel_mode:
        ap.add_argument(
            "--sel-mode", choices=SEL_MODE_CHOICES, default="sync",
            help="Which SYNC parameter the group's pipe_lane_sel_sync module uses: "
            "sync=SYNC=1 (default, non-overlap + a two-stage synchronizer, safe "
            "across clock domains); comb=SYNC=0 (combinational passthrough, only "
            "safe when the candidate controllers share one clock domain)",
        )
    ap.add_argument("--arch", choices=ARCH_CHOICES, default="original_pipe", help=ARCH_HELP)
    ap.add_argument("--pclk-mode", choices=PCLK_MODE_CHOICES, default="pclk_as_phy_output", help=PCLK_MODE_HELP)
    ap.add_argument("--verible-path", default=None, metavar="PATH", help=VERIBLE_PATH_HELP)
    ap.add_argument("--verible-flags", default=None, metavar="JSON", help=VERIBLE_FLAGS_HELP)
    ap.add_argument("--dpr", action="store_true", help=DPR_HELP)
    ap.add_argument("--quiet", action="store_true")


def _parse_verible_flags(raw):
    if not raw:
        return None
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as e:
        raise SystemExit(f"--verible-flags must be valid JSON: {e.msg}") from e
    if not isinstance(value, dict):
        raise SystemExit("--verible-flags must be a JSON object")
    return value


def validate_dpr(dpr, pclk_mode, sel_mode=None):
    """Reject the --dpr combinations this generator can't produce working RTL
    for. Shared by all three generate subcommands so `generate tb` can't
    quietly accept a pairing `generate rtl` refuses.

    sel_mode is None for `generate tb`, which has no --sel-mode of its own.
    """
    if not dpr:
        return
    if sel_mode is not None and sel_mode != "sync":
        # DPR is merged into each group's own pipe_lane_sel_sync as one more
        # candidate branch, gated by the SAME SEL_SYNC parameter --sel-mode
        # drives for the group's real candidates -- --sel-mode comb is only
        # safe when every branch shares one clock domain, which DPR (v_lane_mask
        # driven independently of mode) can't guarantee.
        raise SystemExit(f"--dpr requires --sel-mode sync (got --sel-mode {sel_mode})")
    if pclk_mode == "pclk_as_phy_input":
        # In this scheme there is no free-running per-lane PHY clock for DPR to
        # take its own working clock from. gen_clk_mux_phy_input would derive
        # dpr_pclk from real_pclk[] -- the ALREADY-GATED clk_or output of the
        # lane's real candidates -- which deadlocks: handing the lane to DPR
        # gates every real branch off, real_pclk[] stops, dpr_pclk stops, and
        # the DPR branch flop inside pipe_lane_sel_sync (clocked by dpr_pclk)
        # can never change again, so the lane is neither usable by DPR nor
        # releasable back to its real owner. pclk_as_phy_output has no such
        # loop: there dpr_pclk comes from phy_pclk_out[], which PHY drives
        # unconditionally. Refused here rather than emitting RTL that
        # elaborates and simulates right up until the first v_lane_mask
        # assertion. See design_notes.md 4.x.
        raise SystemExit(
            "--dpr is not supported with --pclk-mode pclk_as_phy_input: DPR has no "
            "free-running clock source in that architecture, so the generated "
            "dpr_pclk would stop the moment DPR takes a lane. Use --pclk-mode "
            "pclk_as_phy_output (--arch original_pipe) for a DPR overlay."
        )


def cmd_generate_rtl(argv):
    ap = argparse.ArgumentParser(prog="plm generate rtl", description="Generate PIPE lane mapper RTL")
    _add_config_arg(ap)
    _add_shared_gen_args(ap, sel_mode=True)
    a = ap.parse_args(argv)
    csv_dir, out_rtl = resolve_set(a.config)

    verible_flags = _parse_verible_flags(a.verible_flags)
    validate_arch(a.arch, a.pclk_mode)
    validate_dpr(a.dpr, a.pclk_mode, a.sel_mode)

    cfg = load(csv_dir)
    print(f"Config: {csv_dir}")
    export_rtl(
        cfg, out_rtl,
        pclk_mode=a.pclk_mode, sel_mode=a.sel_mode, dpr=a.dpr,
        verible_path=a.verible_path, verible_flags=verible_flags, quiet=a.quiet,
    )


def cmd_generate_tb(argv):
    ap = argparse.ArgumentParser(prog="plm generate tb", description="Generate PIPE lane mapper testbench")
    _add_config_arg(ap)
    _add_shared_gen_args(ap, sel_mode=False)
    a = ap.parse_args(argv)
    csv_dir, out_rtl = resolve_set(a.config)

    verible_flags = _parse_verible_flags(a.verible_flags)
    validate_arch(a.arch, a.pclk_mode)
    validate_dpr(a.dpr, a.pclk_mode)

    cfg = load(csv_dir)
    print(f"Config: {csv_dir}")
    export_tb(
        cfg, out_rtl,
        pclk_mode=a.pclk_mode, dpr=a.dpr,
        verible_path=a.verible_path, verible_flags=verible_flags, quiet=a.quiet,
    )


def cmd_generate_all(argv):
    ap = argparse.ArgumentParser(prog="plm generate all", description="Generate PIPE lane mapper RTL + testbench")
    _add_config_arg(ap)
    _add_shared_gen_args(ap, sel_mode=True)
    a = ap.parse_args(argv)
    csv_dir, out_rtl = resolve_set(a.config)

    verible_flags = _parse_verible_flags(a.verible_flags)
    validate_arch(a.arch, a.pclk_mode)
    validate_dpr(a.dpr, a.pclk_mode, a.sel_mode)

    cfg = load(csv_dir)
    print(f"Config: {csv_dir}")
    export_rtl(
        cfg, out_rtl,
        pclk_mode=a.pclk_mode, sel_mode=a.sel_mode, dpr=a.dpr,
        verible_path=a.verible_path, verible_flags=verible_flags, quiet=a.quiet,
    )
    export_tb(
        cfg, out_rtl,
        pclk_mode=a.pclk_mode, dpr=a.dpr,
        verible_path=a.verible_path, verible_flags=verible_flags, quiet=a.quiet,
    )


def cmd_validate(argv):
    ap = argparse.ArgumentParser(prog="plm validate", description="Parse and validate a PIPE lane mapper config set")
    _add_config_arg(ap)
    a = ap.parse_args(argv)
    csv_dir, _out_rtl = resolve_set(a.config)
    cfg = load(csv_dir)  # load() itself prints errors + sys.exit(1) on a validation failure
    print(f"Config: {csv_dir}")
    print("OK -- config is valid.\n")
    print(cfg.report())


def cmd_gui(argv):
    """Launch the only supported graphical front end (Qt)."""
    from plm.frontend.qt.main import main as qt_main
    return qt_main(argv)


SUBCOMMANDS = {
    ("generate", "rtl"): cmd_generate_rtl,
    ("generate", "tb"): cmd_generate_tb,
    ("generate", "all"): cmd_generate_all,
    ("validate",): cmd_validate,
}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] in (["-gui"], ["--gui"]):
        return cmd_gui(argv[1:])
    if argv in (["-h"], ["--help"]):
        print(__doc__)
        return 0
    if argv[:1] == ["generate"] and len(argv) >= 2 and argv[1] in ("rtl", "tb", "all"):
        return SUBCOMMANDS[("generate", argv[1])](argv[2:])
    elif argv[:1] == ["validate"]:
        return SUBCOMMANDS[("validate",)](argv[1:])
    else:
        print(__doc__)
        if argv:
            sys.exit(f"plm: unknown command {' '.join(argv)!r}")
        sys.exit(2)


if __name__ == "__main__":
    main()
