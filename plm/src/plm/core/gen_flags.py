"""
Generation-flag vocabulary shared by the CLI and the Qt front end.

These four flags -- arch, pclk-mode, sel-mode, dpr -- are generation
*inputs*: they decide what the emitted RTL structurally looks like, not how
it is displayed.

The CLI only ever takes them as command-line arguments; it does not read any
file for them (see tool_architecture.md section 5 for why the old
gen_flags.txt-as-argparse-defaults machinery was dropped). The Qt front end
remembers a workspace's choices in that workspace's own gen_flags.txt --
plm.core.workspace owns that file, and the front end passes whatever its
Generation page shows on the command line like any other caller would.

So this module holds only the shared vocabulary -- the legal values, and the
value-level rules relating them -- with no file I/O of its own.
"""

# --arch names the PHY macro family a config set targets; each one only ever
# works with one --pclk-mode, since that's a property of the macro, not an
# independent choice -- original_pipe (a classic PIPE PHY) always drives its
# own PCLK out to the MAC, serdes (a SerDes-style macro) always expects the
# MAC side to hand it a reference clock instead. Both generators validate a
# config's --arch/--pclk-mode combination against this table (see
# validate_arch()) so a mismatched pair is caught at generation time instead
# of surfacing later as a confusing elaboration/simulation failure.
ARCH_PCLK_MODE = {
    "original_pipe": "pclk_as_phy_output",
    "serdes": "pclk_as_phy_input",
}
PCLK_MODE_ARCH = {v: k for k, v in ARCH_PCLK_MODE.items()}

# Plain value tuples (no "(default: ...)"/placeholder entries -- that's a
# Qt-combobox-specific display concern) shared by the CLI's own argparse
# choices and by the front end's arch/pclk-mode/sel-mode selection widgets.
ARCH_VALUES = ("original_pipe", "serdes")
PCLK_MODE_VALUES = ("pclk_as_phy_output", "pclk_as_phy_input")
SEL_MODE_VALUES = ("sync", "comb")


def validate_arch(arch, pclk_mode):
    """Raise SystemExit if --arch and --pclk-mode disagree about which
    clock architecture is in use. See ARCH_PCLK_MODE above."""
    required = ARCH_PCLK_MODE[arch]
    if pclk_mode != required:
        raise SystemExit(
            f"--arch {arch} only supports --pclk-mode {required} (got --pclk-mode {pclk_mode})"
        )


def complete_arch_pclk(arch, pclk_mode):
    """Fill in whichever of (arch, pclk-mode) the other one implies.

    The two are one fact written two ways (see ARCH_PCLK_MODE), so a
    hand-written gen_flags.txt that pins only one of them means the same thing
    as one that pins both.

    Values that aren't recognized come back as None; a pair that is fully
    specified is returned unchanged even when it disagrees, so the conflict
    still surfaces through validate_arch()'s own error at generation time
    rather than being silently rewritten here.
    """
    arch = arch if arch in ARCH_VALUES else None
    pclk_mode = pclk_mode if pclk_mode in PCLK_MODE_VALUES else None
    if arch is None and pclk_mode is not None:
        arch = PCLK_MODE_ARCH[pclk_mode]
    elif pclk_mode is None and arch is not None:
        pclk_mode = ARCH_PCLK_MODE[arch]
    return arch, pclk_mode
