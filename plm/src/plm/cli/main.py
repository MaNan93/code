#!/usr/bin/env python3
"""
plm -- unified CLI for the PIPE Lane Mapper generator/validator.

Replaces the two old standalone scripts (plm_gen_rtl.py / plm_gen_tb.py)
with subcommands of one entry point, reconciling the ways they used to be
invoked (the Makefile: a bare config-set name + --quiet; the web/Qt front
ends: a full workspace path + --verible-path/--verible-flags, no --quiet)
as different combinations of the same optional flags.

    plm generate rtl  --config X [--sel-mode {sync,comb}] [--arch ...] [--pclk-mode ...]
                       [--verible-path P] [--verible-flags JSON] [--dpr] [--quiet]
    plm generate tb   --config X [--arch ...] [--pclk-mode ...]
                       [--verible-path P] [--verible-flags JSON] [--dpr] [--quiet]
    plm generate all  --config X [--sel-mode ...] [--arch ...] [--pclk-mode ...]
                       [--verible-path P] [--verible-flags JSON] [--dpr] [--quiet]
    plm validate      --config X

--config accepts either a bare config-set name (resolved under test/)
or a full path -- resolve_set() already makes that transparent, see
plm.core.paths.

Also runnable as `python -m plm.cli.main ...` without relying on the
`plm` console-script being on PATH -- this is how the web/Qt front ends
and the Makefile invoke it (via sys.executable -m, not the installed
script name), since that only depends on the interpreter being able to
import plm, not on PATH having the venv's script directory on it.
"""

import argparse
import json
import sys

from plm.core.exporter import export_rtl, export_tb
from plm.core.gen_flags import apply_set_flags, load_set_flags, validate_arch
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


def _resolve_with_set_flags(config_arg):
    """The gen_flags.txt-as-argparse-defaults trick: resolve --config first
    (via a throwaway pre-parse), load that config set's own gen_flags.txt,
    and return (csv_dir, out_rtl, set_flags) for the caller to fold into
    its real parse via apply_set_flags()."""
    csv_dir, out_rtl = resolve_set(config_arg)
    set_flags = load_set_flags(csv_dir)
    return csv_dir, out_rtl, set_flags


def _parse_subcommand(ap, argv, set_flags):
    return ap.parse_args(apply_set_flags(ap, set_flags) + argv)


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


def cmd_generate_rtl(argv):
    pre_ap = argparse.ArgumentParser(add_help=False)
    _add_config_arg(pre_ap)
    pre_args, _ = pre_ap.parse_known_args(argv)
    csv_dir, out_rtl, set_flags = _resolve_with_set_flags(pre_args.config)

    ap = argparse.ArgumentParser(prog="plm generate rtl", description="Generate PIPE lane mapper RTL")
    _add_config_arg(ap)
    _add_shared_gen_args(ap, sel_mode=True)
    a = _parse_subcommand(ap, argv, set_flags)

    verible_flags = _parse_verible_flags(a.verible_flags)
    validate_arch(a.arch, a.pclk_mode)
    if a.dpr and a.sel_mode != "sync":
        # DPR is merged into each group's own pipe_lane_sel_sync as one more
        # candidate branch, gated by the SAME SEL_SYNC parameter --sel-mode
        # drives for the group's real candidates -- --sel-mode comb is only
        # safe when every branch shares one clock domain, which DPR (v_lane_mask
        # driven independently of mode) can't guarantee.
        raise SystemExit("--dpr requires --sel-mode sync (got --sel-mode comb)")

    cfg = load(csv_dir)
    print(f"Config: {csv_dir}")
    export_rtl(
        cfg, out_rtl,
        pclk_mode=a.pclk_mode, sel_mode=a.sel_mode, dpr=a.dpr,
        verible_path=a.verible_path, verible_flags=verible_flags, quiet=a.quiet,
    )


def cmd_generate_tb(argv):
    pre_ap = argparse.ArgumentParser(add_help=False)
    _add_config_arg(pre_ap)
    pre_args, _ = pre_ap.parse_known_args(argv)
    csv_dir, out_rtl, set_flags = _resolve_with_set_flags(pre_args.config)

    ap = argparse.ArgumentParser(prog="plm generate tb", description="Generate PIPE lane mapper testbench")
    _add_config_arg(ap)
    _add_shared_gen_args(ap, sel_mode=False)
    a = _parse_subcommand(ap, argv, set_flags)

    verible_flags = _parse_verible_flags(a.verible_flags)
    validate_arch(a.arch, a.pclk_mode)

    cfg = load(csv_dir)
    print(f"Config: {csv_dir}")
    export_tb(
        cfg, out_rtl,
        pclk_mode=a.pclk_mode, dpr=a.dpr,
        verible_path=a.verible_path, verible_flags=verible_flags, quiet=a.quiet,
    )


def cmd_generate_all(argv):
    pre_ap = argparse.ArgumentParser(add_help=False)
    _add_config_arg(pre_ap)
    pre_args, _ = pre_ap.parse_known_args(argv)
    csv_dir, out_rtl, set_flags = _resolve_with_set_flags(pre_args.config)

    ap = argparse.ArgumentParser(prog="plm generate all", description="Generate PIPE lane mapper RTL + testbench")
    _add_config_arg(ap)
    _add_shared_gen_args(ap, sel_mode=True)
    a = _parse_subcommand(ap, argv, set_flags)

    verible_flags = _parse_verible_flags(a.verible_flags)
    validate_arch(a.arch, a.pclk_mode)
    if a.dpr and a.sel_mode != "sync":
        raise SystemExit("--dpr requires --sel-mode sync (got --sel-mode comb)")

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


SUBCOMMANDS = {
    ("generate", "rtl"): cmd_generate_rtl,
    ("generate", "tb"): cmd_generate_tb,
    ("generate", "all"): cmd_generate_all,
    ("validate",): cmd_validate,
}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["generate"] and len(argv) >= 2 and argv[1] in ("rtl", "tb", "all"):
        SUBCOMMANDS[("generate", argv[1])](argv[2:])
    elif argv[:1] == ["validate"]:
        SUBCOMMANDS[("validate",)](argv[1:])
    else:
        print(__doc__)
        if argv:
            sys.exit(f"plm: unknown command {' '.join(argv)!r}")
        sys.exit(2)


if __name__ == "__main__":
    main()
