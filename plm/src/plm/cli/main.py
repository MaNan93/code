#!/usr/bin/env python3
"""
plm -- generate matched RTL and testbench outputs from three configuration CSVs.

    plm generate  --config SET  [flags]   generate RTL + testbench
    plm validate  --config SET            parse + check, write nothing
    plm -gui                              launch the Qt front end

RTL and testbench are one output set. Generation stages both and replaces
SET/rtl and SET/tb only after every step succeeds.
"""

import argparse
import json
import sys

from plm.core.gen_flags import (
    ARCH_VALUES,
    PCLK_MODE_VALUES,
    SEL_MODE_VALUES,
    GenerationOptions,
)
from plm.core.paths import resolve_set
from plm.core.service import generate
from plm.core.validation import ValidationError, load_validated_config


ARCH_HELP = (
    "PHY family: original_pipe requires pclk_as_phy_output; "
    "serdes requires pclk_as_phy_input."
)
PCLK_MODE_HELP = "PCLK architecture: PHY output or controller-provided PHY input."
DPR_HELP = (
    "Generate the DPR diagnostic-probe overlay. Requires --sel-mode sync; "
    "PHY-input mode needs an external dpr_pclk."
)


def _add_config_arg(parser):
    parser.add_argument(
        "--config", default=None, metavar="SET",
        help="Directory holding the three config CSVs (or its parent).",
    )


def _add_generation_args(parser):
    parser.add_argument(
        "--sel-mode", choices=list(SEL_MODE_VALUES), default="sync",
        help="sync=break-before-make plus synchronization; "
        "comb=passthrough for a shared clock domain only",
    )
    parser.add_argument(
        "--arch", choices=list(ARCH_VALUES), default="original_pipe", help=ARCH_HELP
    )
    parser.add_argument(
        "--pclk-mode", choices=list(PCLK_MODE_VALUES),
        default="pclk_as_phy_output", help=PCLK_MODE_HELP,
    )
    parser.add_argument(
        "--verible-path", default=None, metavar="PATH",
        help="Path to verible-verilog-format. Defaults to searching PATH.",
    )
    parser.add_argument(
        "--verible-flags", default=None, metavar="JSON",
        help="JSON object of formatter flags, replacing the defaults.",
    )
    parser.add_argument("--dpr", action="store_true", help=DPR_HELP)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--events-json", action="store_true", help=argparse.SUPPRESS)


def _parse_verible_flags(raw):
    if not raw:
        return None
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SystemExit(
            f"--verible-flags must be valid JSON: {error.msg}"
        ) from error
    if not isinstance(value, dict):
        raise SystemExit("--verible-flags must be a JSON object")
    return value


def _emit_event(enabled, phase):
    if enabled:
        print("PLM_EVENT " + json.dumps({"phase": phase}, sort_keys=True), flush=True)


def cmd_generate(argv):
    parser = argparse.ArgumentParser(
        prog="plm generate",
        description="Generate matched PIPE lane mapper RTL and testbench outputs",
    )
    _add_config_arg(parser)
    _add_generation_args(parser)
    args = parser.parse_args(argv)
    csv_dir, out_rtl = resolve_set(args.config)
    options = GenerationOptions(
        arch=args.arch,
        pclk_mode=args.pclk_mode,
        sel_mode=args.sel_mode,
        dpr=args.dpr,
        verible_path=args.verible_path,
        verible_flags=_parse_verible_flags(args.verible_flags),
        quiet=args.quiet,
    )
    print(f"Config: {csv_dir}")
    try:
        result = generate(
            csv_dir,
            out_rtl,
            options,
            progress=lambda phase: _emit_event(args.events_json, phase),
        )
    except ValidationError as error:
        raise SystemExit(f"Generation validation failed:\n{error}") from error
    if not result.generated:
        print("Outputs are up to date; generation skipped.")


def cmd_validate(argv):
    parser = argparse.ArgumentParser(
        prog="plm validate",
        description="Parse and validate a PIPE lane mapper config set",
    )
    _add_config_arg(parser)
    args = parser.parse_args(argv)
    csv_dir, _out_rtl = resolve_set(args.config)
    try:
        cfg = load_validated_config(csv_dir)
    except ValidationError as error:
        raise SystemExit(f"Config validation failed:\n{error}") from error
    print(f"Config: {csv_dir}")
    print("OK -- config is valid.\n")
    print(cfg.report())


def cmd_gui(argv):
    from plm.frontend.qt.main import main as qt_main
    return qt_main(argv)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] in (["-gui"], ["--gui"]):
        return cmd_gui(argv[1:])
    if argv in (["-h"], ["--help"]):
        print(__doc__)
        return 0
    if argv[:1] == ["generate"]:
        return cmd_generate(argv[1:])
    if argv[:1] == ["validate"]:
        return cmd_validate(argv[1:])
    print(__doc__)
    if argv:
        sys.exit(f"plm: unknown command {' '.join(argv)!r}")
    sys.exit(2)


if __name__ == "__main__":
    main()
