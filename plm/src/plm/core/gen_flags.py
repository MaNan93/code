"""
Generation-flag vocabulary shared by the CLI and the Qt front end.

These flags -- arch, pclk-mode, dpr, bus-type -- are generation
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

from dataclasses import dataclass
import re

# --arch names the PHY macro family a config set targets; each one only ever
# works with one --pclk-mode, since that's a property of the macro, not an
# independent choice -- original_pipe (a classic PIPE PHY) always drives its
# own PCLK out to the MAC, serdes (a SerDes-style macro) always expects the
# MAC side to hand it a reference clock instead. Both generators validate a
# config's --arch/--pclk-mode combination against this table (see
# GenerationOptions.errors()) so a mismatched pair is caught at generation time instead
# of surfacing later as a confusing elaboration/simulation failure.
ARCH_PCLK_MODE = {
    "original_pipe": "pclk_as_phy_output",
    "serdes": "pclk_as_phy_input",
}
PCLK_MODE_ARCH = {v: k for k, v in ARCH_PCLK_MODE.items()}

# Plain value tuples (no "(default: ...)"/placeholder entries -- that's a
# Qt-combobox-specific display concern) shared by the CLI's own argparse
# choices and by the front end's arch/pclk-mode selection widgets.
ARCH_VALUES = ("original_pipe", "serdes")
PCLK_MODE_VALUES = ("pclk_as_phy_output", "pclk_as_phy_input")
BUS_TYPE_VALUES = ("flat", "bus")


@dataclass(frozen=True)
class GenerationOptions:
    """One immutable generation option set shared by every front end.

    Presentation-only switches such as ``quiet`` and formatter settings live
    here too. :meth:`manifest_dict` keeps structural design values; the plan
    fingerprints formatter settings and the resolved formatter separately.
    """

    arch: str = "original_pipe"
    pclk_mode: str = "pclk_as_phy_output"
    dpr: bool = False
    verible_path: str = None
    verible_flags: dict = None
    quiet: bool = False
    bus_type: str = "bus"
    module_prefix: str = ""
    file_prefix: str = ""
    macro_prefix: str = ""

    @property
    def sel_mode(self):
        """SEL_SYNC's generated default: "sync" with DPR, otherwise "comb".

        Not a choice. Without DPR, ownership only changes with ``mode``, and
        ``mode`` only changes while the affected lanes are held in reset, so
        the select is static whenever it matters and synchronizing it buys
        nothing. DPR's v_lane_mask moves at run time and needs the
        non-overlap synchronizer.
        """
        return "sync" if self.dpr else "comb"

    def errors(self):
        errors = []
        if self.arch not in ARCH_VALUES:
            errors.append(f"arch must be one of {', '.join(ARCH_VALUES)} (got {self.arch!r})")
        if self.pclk_mode not in PCLK_MODE_VALUES:
            errors.append(
                f"pclk_mode must be one of {', '.join(PCLK_MODE_VALUES)} "
                f"(got {self.pclk_mode!r})"
            )
        if self.bus_type not in BUS_TYPE_VALUES:
            errors.append(
                f"bus_type must be one of {', '.join(BUS_TYPE_VALUES)} "
                f"(got {self.bus_type!r})"
            )
        if self.arch in ARCH_PCLK_MODE and self.pclk_mode in PCLK_MODE_VALUES:
            required = ARCH_PCLK_MODE[self.arch]
            if self.pclk_mode != required:
                errors.append(
                    f"arch {self.arch} only supports pclk_mode {required} "
                    f"(got {self.pclk_mode})"
                )
        if self.verible_flags is not None and not isinstance(self.verible_flags, dict):
            errors.append("verible_flags must be a JSON object")
        for name in ("module_prefix", "macro_prefix", "file_prefix"):
            value = getattr(self, name)
            if name == "file_prefix":
                pattern = r"[A-Za-z0-9_.-]*"
                allowed = "letters, digits, underscore, dot or hyphen"
            else:
                pattern = r"(?:[A-Za-z_][A-Za-z0-9_]*)?"
                allowed = "an ASCII identifier prefix starting with a letter or underscore"
            if not isinstance(value, str) or not re.fullmatch(pattern, value):
                errors.append(f"{name} must be empty or {allowed} (got {value!r})")
        return errors

    def validated(self):
        errors = self.errors()
        if errors:
            raise ValueError("; ".join(errors))
        return self

    def manifest_dict(self):
        result = {
            "arch": self.arch,
            "pclk_mode": self.pclk_mode,
            "sel_mode": self.sel_mode,
            "dpr": bool(self.dpr),
            "bus_type": self.bus_type,
        }
        for name in ("module_prefix", "file_prefix", "macro_prefix"):
            if getattr(self, name):
                result[name] = getattr(self, name)
        return result



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
