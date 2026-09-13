"""
gen_flags.txt read/write -- a config set's own pinned generation defaults.

Two shapes of this same one file are needed:
  - load_set_flags/apply_set_flags: raw {cli-flag-name: value-string},
    consumed as argparse defaults by the CLI (cli/main.py).
  - read_gen_flags/write_gen_flags: the front ends' own typed shape
    (unset arch/pclk-mode/sel-mode as None, dpr as bool), consumed by
    plm.core.workspace and the Qt front end's Generation page.
Both flavors operate on the same file, so they live together here rather
than being split by which caller happens to use them.
"""

from pathlib import Path

SET_FLAGS_FILENAME = "gen_flags.txt"

# pclk-mode's values were renamed (phy-output/phy-input-max-pclk ->
# pclk_as_phy_output/pclk_as_phy_input) for clearer, more consistent
# terminology. A gen_flags.txt written before the rename still has the old
# value on disk -- translate it here so an old config set keeps working
# without the user having to hand-edit the file; new writes only ever use
# the new names.
_PCLK_MODE_MIGRATION = {
    "phy-output": "pclk_as_phy_output",
    "phy-input-max-pclk": "pclk_as_phy_input",
}

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
# Qt-combobox-specific display concern) shared by every front end's
# gen_flags.txt read/write and by their arch/pclk-mode/sel-mode selection
# widgets.
ARCH_VALUES = ("original_pipe", "serdes")
PCLK_MODE_VALUES = ("pclk_as_phy_output", "pclk_as_phy_input")
SEL_MODE_VALUES = ("sync", "comb")


def existing_line_ending(path):
    """Detect the line ending already used by path, so writing back to it
    doesn't silently rewrite every single line just from an untouched
    load-then-save round trip. Falls back to plain "\\n" for a file that
    doesn't exist yet -- these configs are meant to be Linux-readable
    regardless of which OS a given front end runs on, so a brand-new file
    shouldn't default to the local OS's convention (os.linesep is CRLF on
    Windows).

    Lives here (not in plm.core.workspace, which also needs it for the
    CSV writers) so that module can depend on this one for
    read_gen_flags/write_gen_flags without a two-way import cycle --
    plm.core.workspace imports this function back from here."""
    path = Path(path)
    if path.is_file():
        with open(path, "rb") as f:
            head = f.read(65536)
        if b"\r\n" in head:
            return "\r\n"
        if b"\n" in head:
            return "\n"
    return "\n"


def validate_arch(arch, pclk_mode):
    """Raise SystemExit if --arch and --pclk-mode disagree about which
    clock architecture is in use. See ARCH_PCLK_MODE above."""
    required = ARCH_PCLK_MODE[arch]
    if pclk_mode != required:
        raise SystemExit(
            f"--arch {arch} only supports --pclk-mode {required} (got --pclk-mode {pclk_mode})"
        )


def load_set_flags(csv_dir, filename=SET_FLAGS_FILENAME):
    """Read <csv_dir>/gen_flags.txt if present: one 'key = value' per line
    (blank lines and '#' comments ignored), key is a CLI flag name with its
    leading '--' stripped (e.g. 'pclk-mode'). Lets a config set pin its own
    fixed generation flags (e.g. which --pclk-mode it demonstrates) right
    next to its CSVs -- self-contained with the rest of the config set,
    instead of living in the top-level Makefile where it's easy to add a
    new config set and forget to also wire up its flags there.

    Returns {} if the file doesn't exist. See apply_set_flags() for how the
    CLI's argparse.ArgumentParser consumes the result.
    """
    path = Path(csv_dir) / filename
    if not path.is_file():
        return {}
    flags = {}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if "=" not in line:
            raise SystemExit(f"{path}:{lineno}: expected 'key = value', got: {raw!r}")
        key, _, value = line.partition("=")
        key = key.strip().lstrip("-")
        if key == "config":
            raise SystemExit(f"{path}:{lineno}: 'config' can't be set from within a config set's own flags file")
        value = value.strip()
        if key == "pclk-mode":
            value = _PCLK_MODE_MIGRATION.get(value, value)
        flags[key] = value
    return flags


def apply_set_flags(ap, set_flags):
    """Turn set_flags (from load_set_flags()) into a list of argv tokens
    for the flags this parser (ap) actually defines, silently dropping any
    others -- e.g. a 'sel-mode' entry meant for `plm generate rtl` is
    simply not one of `plm generate tb`'s own options, so that subcommand's
    parser drops it rather than choking on it. The same gen_flags.txt can
    therefore be shared by both.

    Prepend the returned tokens to sys.argv[1:] before calling
    ap.parse_args(): a value from the file then acts as a per-config-set
    default -- an explicit CLI flag, appearing later in the combined argv,
    still wins via argparse's normal last-occurrence-wins behavior, and a
    file-provided value still goes through the same argparse `choices=`
    validation a CLI-typed value would (instead of silently sitting in the
    namespace unchecked, the way argparse.set_defaults() would leave it).
    """
    known = {}
    for action in ap._actions:
        for opt in action.option_strings:
            known[opt.lstrip("-")] = action

    tokens = []
    for key, value in set_flags.items():
        action = known.get(key)
        if action is None:
            continue
        if action.nargs == 0:  # e.g. store_true, takes no value
            if value.strip().lower() in ("1", "true", "yes", "on"):
                tokens.append(f"--{key}")
        else:
            tokens += [f"--{key}", value]
    return tokens


def read_gen_flags(path):
    """Read <config>/gen_flags.txt into {"arch", "pclk-mode", "sel-mode",
    "dpr", "verible-path"}. Unlike load_set_flags() (which returns raw
    key/value strings for argparse to consume), this returns the front
    ends' own shape: unset/unrecognized arch/pclk-mode/sel-mode come back
    as None (not a placeholder string -- each front end maps that to
    whatever its own "unset" widget value is), dpr is already a bool.
    """
    path = Path(path)
    flags = {}
    if path.is_file():
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line or "=" not in line:
                continue
            k, _, v = line.partition("=")
            flags[k.strip()] = v.strip()
    raw_pclk_mode = flags.get("pclk-mode", "")
    pclk_mode_val = _PCLK_MODE_MIGRATION.get(raw_pclk_mode, raw_pclk_mode)
    pclk_mode_val = pclk_mode_val if pclk_mode_val in PCLK_MODE_VALUES else None
    arch_val = PCLK_MODE_ARCH.get(pclk_mode_val)
    sel_val = flags.get("sel-mode")
    sel_val = sel_val if sel_val in SEL_MODE_VALUES else None
    return {
        "arch": arch_val,
        "pclk-mode": pclk_mode_val,
        "sel-mode": sel_val,
        "dpr": flags.get("dpr", "").strip().lower() in ("1", "true", "yes", "on"),
        "verible-path": flags.get("verible-path", ""),
    }


def write_gen_flags(path, flags):
    path = Path(path)
    lines = [
        "# 支持: arch      = original_pipe | serdes",
        "#       pclk-mode = pclk_as_phy_output | pclk_as_phy_input",
        "#       sel-mode  = sync | comb",
        "#       dpr       = true | false (dpr=true requires sel-mode=sync)",
    ]
    header_lines = len(lines)
    arch = flags.get("arch")
    pclk = flags.get("pclk-mode")
    sel = flags.get("sel-mode")
    dpr = bool(flags.get("dpr"))
    verible = (flags.get("verible-path") or "").strip()
    if arch in ARCH_VALUES:
        lines.append(f"arch = {arch}")
    if pclk in PCLK_MODE_VALUES:
        lines.append(f"pclk-mode = {pclk}")
    if sel in SEL_MODE_VALUES:
        lines.append(f"sel-mode = {sel}")
    if dpr:
        lines.append("dpr = true")
    if verible:
        lines.append(f"verible-path = {verible}")
    if len(lines) == header_lines:
        # nothing but the header comment lines -- no point writing a file
        # that would set no keys at all.
        if path.is_file():
            path.unlink()
        return
    eol = existing_line_ending(path)  # must read this *before* truncating the file
    # newline="" (like the CSV writers) so the \n's already joined into the
    # text below are written as-is, not translated to os.linesep --
    # write_text()'s default newline=None would silently flip an existing
    # LF file to CRLF (or vice versa) on every save.
    with open(path, "w", newline="", encoding="utf-8") as f:
        f.write(eol.join(lines) + eol)
