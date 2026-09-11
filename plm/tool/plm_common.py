"""
Shared infrastructure for the PIPE lane mapper generators.

tool/plm_gen_rtl.py (RTL) and tool/plm_gen_tb.py (testbench) are separate,
independently runnable tools -- one config set's RTL and TB no longer have
to be regenerated together. What they still share lives here: locating a
config set on disk, loading its CSVs is plm_config.load()'s job, but
resolving the --config argument into concrete paths, and the
verible-verilog-format auto-formatting pass, are identical in both tools,
so they're defined once and imported by each.
"""

import csv
import shutil
import subprocess
from pathlib import Path

from plm_config import _stripped

SCRIPT_DIR = Path(__file__).resolve().parent  # .../plm/tool
PLM_ROOT = SCRIPT_DIR.parent  # .../plm
CONFIGS_ROOT = PLM_ROOT / "configs"  # .../plm/configs
BUILTIN_CFG = SCRIPT_DIR / "config"  # built-in default CSVs (if shipped alongside the tool)
COMMON_DIR = (
    SCRIPT_DIR / "common"
)  # hand-written common modules (config-independent, shipped with the tool)
TB_MAKEFILE = (
    SCRIPT_DIR / "tb_makefile.mk"
)  # hand-written VCS/Verdi Makefile (config-independent), copied to <set>/tb/Makefile
CSV_NAMES = ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv")


def has_csvs(d):
    d = Path(d)
    return d.is_dir() and all((d / n).is_file() for n in CSV_NAMES)


def clog2(n):
    """Python equivalent of SystemVerilog's $clog2 -- the generator always
    knows the mode count at generation time, so the mode port's width can
    be computed once here and emitted as a literal, instead of carrying an
    NM parameter through every module just to recompute $clog2(NM) at
    elaboration time."""
    if n <= 1:
        return 0
    return (n - 1).bit_length()


def mode_width(n):
    """Bit width of the `mode` select port, for n modes. At least 1, even
    for a single-mode config: true $clog2 semantics give clog2(1) == 0,
    which would emit an invalid `[-1:0]` port range -- the mode port still
    has to exist and be connectable even when there's nothing to select
    between."""
    return max(1, clog2(n))


def find_verible(verible_path=None):
    """Locate verible-verilog-format, checked in priority order:
    1. verible_path, if given (e.g. via --verible-path) -- used as-is,
       not even checked for existence, so a bad explicit path fails loudly
       via format_sv()'s own subprocess error handling rather than being
       silently skipped like the other tiers.
    2. A copy sitting next to the current working directory (the directory
       the command was run from) -- for a vendored/portable copy that
       isn't installed anywhere on PATH.
    3. PATH, via shutil.which.
    Returns None if none of these find anything.
    """
    if verible_path:
        return verible_path
    for name in ("verible-verilog-format", "verible-verilog-format.exe"):
        local = Path.cwd() / name
        if local.is_file():
            return str(local)
    return shutil.which("verible-verilog-format")


# verible-verilog-format flags this project knows how to drive, grouped by
# value shape -- shared by format_sv() (which flag=value pairs to build)
# and by plm_web.py's Settings UI (which control to render for each one).
# Every value type reads as a plain string on the CLI ("true"/"false" for
# booleans included), so DEFAULT_VERIBLE_FLAGS's values are already in
# their final CLI-ready form.
VERIBLE_ALIGN_PARAMS = (
    "assignment_statement_alignment", "case_items_alignment", "class_member_variable_alignment",
    "distribution_items_alignment", "enum_assignment_statement_alignment", "formal_parameters_alignment",
    "module_net_variable_alignment", "named_parameter_alignment", "named_port_alignment",
    "port_declarations_alignment", "struct_union_members_alignment",
)  # each: "align" | "flush-left"
VERIBLE_INDENT_PARAMS = (
    "formal_parameters_indentation", "named_parameter_indentation",
    "named_port_indentation", "port_declarations_indentation",
)  # each: "indent" | "wrap"
VERIBLE_BOOL_PARAMS = (
    "compact_indexing_and_selections", "expand_coverpoints",
    "port_declarations_right_align_packed_dimensions", "port_declarations_right_align_unpacked_dimensions",
    "try_wrap_long_lines", "wrap_end_else_clauses", "verify", "verify_convergence", "failsafe_success",
)  # each: "true" | "false"
VERIBLE_INT_PARAMS = (
    "column_limit", "indentation_spaces", "line_break_penalty",
    "over_column_limit_penalty", "max_search_states",
)
VERIBLE_STR_PARAMS = ("lines", "line_terminator", "stdin_name")  # free-form -- "lines" e.g. "3-5,10-12"

# This project's own long-standing defaults (not verible's own out-of-the-box
# defaults) -- unlisted params are simply never passed, so verible's own
# built-in default applies. --inplace/stdin plumbing stays hardcoded below,
# not exposed here (changing it would break the stdin-pipe invocation itself).
DEFAULT_VERIBLE_FLAGS = {
    "assignment_statement_alignment": "align",
    "case_items_alignment": "align",
    "distribution_items_alignment": "align",
    "formal_parameters_alignment": "align",
    "formal_parameters_indentation": "indent",
    "named_parameter_alignment": "align",
    "named_parameter_indentation": "indent",
    "named_port_alignment": "align",
    "named_port_indentation": "indent",
    "port_declarations_alignment": "align",
    "port_declarations_indentation": "indent",
    "port_declarations_right_align_packed_dimensions": "true",
    "struct_union_members_alignment": "align",
    "wrap_end_else_clauses": "true",
    "indentation_spaces": "4",
    "column_limit": "120",
}


def format_sv(text, verible_path=None, verible_flags=None):
    """Best-effort auto-format via verible-verilog-format, if it can be found.

    The generators build .sv content as hand-typed Python string literals,
    so their whitespace/alignment is only as consistent as whoever last
    edited that literal -- there's no single source of truth for spacing
    the way there is for the logic itself. Piping the final text through a
    real formatter fixes that at the one place all output funnels through,
    instead of hand-aligning every literal (impractical and easy to drift
    again on the next edit). This is cosmetic polish, not a functional
    requirement, so silently return the text unchanged if the tool can't
    be found or fails for any reason.

    verible_path, if given (e.g. via --verible-path), takes priority over
    find_verible()'s other lookup tiers (cwd, then PATH) -- see there.

    verible_flags, if given, is a {flag_name: value} dict (value already a
    plain string, e.g. from plm_web.py's Settings UI) that replaces
    DEFAULT_VERIBLE_FLAGS entirely -- not merged with it -- so the caller
    controls the full set. None (the default) uses this project's own
    long-standing defaults, unchanged from before verible_flags existed.
    """
    exe = find_verible(verible_path)
    if exe is None:
        return text
    flags = DEFAULT_VERIBLE_FLAGS if verible_flags is None else verible_flags
    args = [exe]
    for key, val in flags.items():
        if val is None or val == "":
            continue
        args.append(f"--{key}={val}")
    args += [
        "--inplace",  # ignored for stdin ("-"); verible falls back to stdout
        "-",
    ]
    try:
        # Pass/receive raw bytes rather than text=True: subprocess's text
        # mode runs stdin through the platform's default newline
        # translation, which silently turns every "\n" into "\r\n" on
        # Windows before verible ever sees it -- verible then trips its own
        # internal "formatted output doesn't match input" self-check on
        # those injected \r's and returns the input unformatted. Encoding
        # ourselves sends exactly the bytes we mean to send.
        r = subprocess.run(args, input=text.encode("utf-8"), capture_output=True, timeout=10)
        if r.returncode == 0 and r.stdout:
            formatted = r.stdout.decode("utf-8")
            # Formatting must only touch whitespace -- the token stream has
            # to come out identical. This caught a real bug: piping a
            # ~4.4KB file through verible with enough alignment flags
            # active occasionally returned stdout silently truncated at a
            # 4096-byte boundary (classic pipe-buffer size) with returncode
            # still 0 -- no exception, no nonzero exit, just quietly
            # corrupted RTL. Comparing token streams catches that (and any
            # other misbehavior) before it can reach disk.
            if "".join(formatted.split()) == "".join(text.split()):
                return formatted
    except (OSError, subprocess.SubprocessError):
        pass
    return text


def list_configs():
    """List every subdirectory of configs/ that looks like a config set, for
    use in error messages."""
    if not CONFIGS_ROOT.is_dir():
        return []
    return sorted(p.name for p in CONFIGS_ROOT.iterdir() if p.is_dir() and has_csvs(p / "config"))


def resolve_set(arg):
    """Resolve the --config argument into (csv_dir, out_rtl).

    Convention: a config set is a directory; its generated RTL always goes
    to <set>/rtl/ and its testbench to <set>/tb/ (derived by each tool's
    main() as out_rtl.parent / "tb"); CSVs are looked up in <set>/config/
    first, then <set>/ itself.

    The --config value is first tried as a set name under configs/:
      --config demo               -> configs/demo/config/, output to configs/demo/rtl/
      --config config_multi_modes -> configs/config_multi_modes/config/
    If not found there, it's tried as a path given directly (absolute or
    relative, so directories outside configs/ also work):
      --config ../other/my_set    -> my_set/config/ (or my_set/ itself)
      --config config-1/config    -> same as above; passing the config
                                      subdirectory is attributed to its
                                      parent set
    With no --config, there's no default guess -- with multiple configs
    coexisting, guessing wrong is more trouble than just erroring out, so
    it lists the available set names under configs/ instead.
    """
    if arg is None:
        avail = list_configs()
        raise SystemExit(
            "A config set must be given via --config."
            + (
                f" Available: {', '.join(avail)}"
                if avail
                else f" There are no config sets under {CONFIGS_ROOT} yet."
            )
        )

    named = CONFIGS_ROOT / arg
    if has_csvs(named / "config"):
        return named / "config", named / "rtl"

    set_dir = Path(arg).resolve()
    if has_csvs(set_dir / "config"):
        return set_dir / "config", set_dir / "rtl"
    if has_csvs(set_dir):
        # What was passed in is some set's config subdirectory (e.g.
        # config-1/config): attribute it to the parent set, output still
        # goes to config-1/rtl
        if set_dir.name == "config" and set_dir.parent != SCRIPT_DIR:
            return set_dir, set_dir.parent / "rtl"
        return set_dir, set_dir / "rtl"
    if has_csvs(BUILTIN_CFG):
        return BUILTIN_CFG, set_dir / "rtl"

    avail = list_configs()
    raise SystemExit(
        f"Config set '{arg}' not found: no CSVs "
        f"({', '.join(CSV_NAMES)}) under any of "
        f"{named}/config, {set_dir}/config, {set_dir}."
        + (f" Available sets under {CONFIGS_ROOT}: {', '.join(avail)}" if avail else "")
    )


SET_FLAGS_FILENAME = "gen_flags.txt"

# pclk-mode's values were renamed (phy-output/phy-input-max-pclk ->
# pclk_as_phy_output/pclk_as_phy_input) for clearer, more consistent
# terminology. A gen_flags.txt written before the rename still has the old
# value on disk -- translate it here so an old config set keeps working
# without the user having to hand-edit the file; new writes only ever use
# the new names (see plmConsultant.py's own writer).
_PCLK_MODE_MIGRATION = {
    "phy-output": "pclk_as_phy_output",
    "phy-input-max-pclk": "pclk_as_phy_input",
}

# --arch names the PHY macro family a config set targets; each one only ever
# works with one --pclk-mode, since that's a property of the macro, not an
# independent choice -- original_pipe (a classic PIPE PHY) always drives its
# own PCLK out to the MAC, serdes (a SerDes-style macro) always expects the
# MAC side to hand it a reference clock instead. Both tools validate a
# config's --arch/--pclk-mode combination against this table (see
# validate_arch()) so a mismatched pair is caught at generation time instead
# of surfacing later as a confusing elaboration/simulation failure.
ARCH_PCLK_MODE = {
    "original_pipe": "pclk_as_phy_output",
    "serdes": "pclk_as_phy_input",
}
PCLK_MODE_ARCH = {v: k for k, v in ARCH_PCLK_MODE.items()}

# Plain value tuples (no "(default: ...)"/placeholder entries -- that's a
# Tk-combobox-specific display concern, see plmConsultant.py's ARCH_MODES
# etc.) shared by every front end's gen_flags.txt read/write and by their
# arch/pclk-mode/sel-mode selection widgets.
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


def load_set_flags(csv_dir, filename=SET_FLAGS_FILENAME):
    """Read <csv_dir>/gen_flags.txt if present: one 'key = value' per line
    (blank lines and '#' comments ignored), key is a CLI flag name with its
    leading '--' stripped (e.g. 'pclk-mode'). Lets a config set pin its own
    fixed generation flags (e.g. which --pclk-mode it demonstrates) right
    next to its CSVs -- self-contained with the rest of the config set,
    instead of living in the top-level Makefile where it's easy to add a
    new config set and forget to also wire up its flags there.

    Returns {} if the file doesn't exist. See apply_set_flags() for how a
    tool's argparse.ArgumentParser consumes the result.
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
    others -- e.g. a 'sel-mode' entry meant for plm_gen_rtl.py's parser is
    simply not one of plm_gen_tb.py's own options, so plm_gen_tb.py's
    parser drops it rather than choking on it. The same gen_flags.txt can
    therefore be shared by both tools.

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


# ---------------------------------------------------------------- CSV / gen_flags IO
# Shared by every front end (plmConsultant.py, plm_web.py, plm_qt.py) that
# edits the three config CSVs + gen_flags.txt: comma-aligned CSV writing,
# existing-line-ending preservation, and the same required-column checks,
# so all three tools read and write byte-identical files. Each front end
# is responsible for translating its own widget/request state into the
# plain rows/flags shapes these functions take, and back.


def existing_line_ending(path):
    """Detect the line ending already used by path, so writing back to it
    doesn't silently rewrite every single line just from an untouched
    load-then-save round trip. Falls back to plain "\\n" for a file that
    doesn't exist yet -- these configs are meant to be Linux-readable
    regardless of which OS a given front end runs on, so a brand-new file
    shouldn't default to the local OS's convention (os.linesep is CRLF on
    Windows)."""
    path = Path(path)
    if path.is_file():
        with open(path, "rb") as f:
            head = f.read(65536)
        if b"\r\n" in head:
            return "\r\n"
        if b"\n" in head:
            return "\n"
    return "\n"


def read_csv_rows(path, required_cols=None):
    """required_cols, if given, is checked against the file's actual
    header before any row is accepted -- a header that's missing, blank,
    or just doesn't match must be treated as a load failure, not silently
    accepted as "0 useful columns, every field defaults to blank": the
    latter is how a garbled file on disk turns into a table full of blank
    rows that then look empty in the GUI with no error shown at all -- and
    the very next Save/Validate (which always writes the tables back out
    first) overwrites the original file with those blanks, destroying
    whatever was actually in it.

    Header and values are both whitespace-stripped (same _stripped()
    plm_config.py itself uses) -- a comma-aligned CSV padded with spaces
    for readability is a legitimate, common style, not a malformed file.
    """
    path = Path(path)
    if not path.is_file():
        return []
    with open(path, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        rd.fieldnames = [c.strip() if c else c for c in (rd.fieldnames or [])]
        if required_cols and not set(required_cols) <= set(rd.fieldnames):
            missing = sorted(set(required_cols) - set(rd.fieldnames))
            raise ValueError(
                f"{path}: header is missing {', '.join(missing)} "
                f"(found: {', '.join(rd.fieldnames) or '(no header)'})"
            )
        return [dict(r) for r in _stripped(rd)]


def read_mapping_csv(path):
    path = Path(path)
    if not path.is_file():
        return [], 4
    with open(path, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        fieldnames = [c.strip() if c else c for c in (rd.fieldnames or [])]
        rd.fieldnames = fieldnames
        if "mode" not in fieldnames:
            raise ValueError(
                f"{path}: header is missing 'mode' (found: {', '.join(fieldnames) or '(no header)'})"
            )
        lane_cols = [c for c in fieldnames if c != "mode"]
        rows = [dict(r) for r in _stripped(rd)]
    return rows, max(1, len(lane_cols))


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


def write_aligned_csv(path, header, rows, eol):
    """Write a CSV with every column comma-aligned (each field padded with
    spaces after its comma so the next column lines up), for hand-editing
    readability. header/rows entries are plain values (not yet
    comma-escaped) -- this domain (signal/controller names, small
    integers, mode indices) never needs CSV quoting, so this skips the csv
    module entirely rather than fighting it over inserted alignment spaces.
    """
    all_rows = [list(header)] + [list(r) for r in rows]
    ncols = len(header)
    widths = [max(len(str(row[i])) for row in all_rows) for i in range(ncols)]
    with open(path, "w", newline="", encoding="utf-8") as f:
        for row in all_rows:
            cells = []
            for i, v in enumerate(row):
                v = str(v)
                cells.append((v + ",").ljust(widths[i] + 2) if i < ncols - 1 else v)
            f.write("".join(cells) + eol)


def write_controllers_csv(path, rows):
    if not rows:
        raise ValueError("Controllers table is empty -- at least one controller is required.")
    path = Path(path)
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(
        path,
        ["ctrl_id", "ctrl_name", "max_width"],
        [[r.get("ctrl_id", ""), r.get("ctrl_name", ""), r.get("max_width", "")] for r in rows],
        eol,
    )


def write_signals_csv(path, rows):
    if not rows:
        raise ValueError("Pipe Signals table is empty -- at least one signal is required.")
    path = Path(path)
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(
        path,
        ["signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"],
        [
            [
                r.get("signal_name", ""),
                r.get("signal_type", "") or "perlane",
                r.get("direction", ""),
                r.get("width", ""),
                r.get("safe_state", ""),
                r.get("tie_off", ""),
            ]
            for r in rows
        ],
        eol,
    )


def write_mapping_csv(path, lane_count, rows):
    if not rows:
        raise ValueError("Lane Mapping table is empty -- at least one mode row is required.")
    path = Path(path)
    cols = ["mode"] + [f"lane{l}" for l in range(lane_count)]
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(path, cols, [[r.get(c, "") for c in cols] for r in rows], eol)


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


def default_verible_path(explicit=""):
    """explicit (e.g. from gen_flags.txt) always wins; otherwise fall back
    to whatever find_verible() locates on PATH, if anything."""
    return explicit or find_verible() or ""


def load_default_signals():
    """Copy an existing bundled sample workspace's pipe_signals.csv as a
    ready-made starting point for a brand-new, still-empty workspace --
    this project's own bundled sample workspaces (configs/test_quad, etc.)
    always exist regardless of which workspace is currently open, so
    they're a reliable template source."""
    for name in list_configs():
        src = CONFIGS_ROOT / name / "config" / "pipe_signals.csv"
        if src.is_file():
            return read_csv_rows(src)
    return []


def workspace_content(ws_root):
    """Load the four config files under ws_root/config into a plain JSON-
    serializable dict shape: {"controllers", "signals", "mapping": {...},
    "gen_flags": {...}, "empty"}. Raises ValueError on a genuine parse
    failure; a workspace with no config yet returns an empty-but-valid
    shape instead of raising."""
    ws_root = Path(ws_root)
    cfg_dir = ws_root / "config"
    if not has_csvs(cfg_dir):
        return {
            "controllers": [],
            "signals": [],
            "mapping": {"lane_count": 4, "rows": []},
            "gen_flags": {"arch": None, "pclk-mode": None, "sel-mode": None,
                          "dpr": False, "verible-path": default_verible_path()},
            "empty": True,
        }
    ctrls = read_csv_rows(cfg_dir / "controllers.csv", ("ctrl_id", "ctrl_name", "max_width"))
    sigs = read_csv_rows(
        cfg_dir / "pipe_signals.csv",
        ("signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"),
    )
    mapping_rows, lane_count = read_mapping_csv(cfg_dir / "lane_mapping.csv")
    flags = read_gen_flags(cfg_dir / "gen_flags.txt")
    flags["verible-path"] = default_verible_path(flags.get("verible-path", ""))
    return {
        "controllers": ctrls,
        "signals": sigs,
        "mapping": {"lane_count": lane_count, "rows": mapping_rows},
        "gen_flags": flags,
        "empty": False,
    }


def save_workspace_content(ws_root, payload):
    ws_root = Path(ws_root)
    cfg_dir = ws_root / "config"
    cfg_dir.mkdir(parents=True, exist_ok=True)
    mapping = payload.get("mapping") or {}
    write_controllers_csv(cfg_dir / "controllers.csv", payload.get("controllers") or [])
    write_signals_csv(cfg_dir / "pipe_signals.csv", payload.get("signals") or [])
    write_mapping_csv(cfg_dir / "lane_mapping.csv", int(mapping.get("lane_count") or 4), mapping.get("rows") or [])
    write_gen_flags(cfg_dir / "gen_flags.txt", payload.get("gen_flags") or {})


def scaffold_default_content(ws_root):
    """Seed sensible starting content for a brand-new, empty workspace."""
    payload = {
        "controllers": [{"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "4"}],
        "signals": load_default_signals(),
        "mapping": {"lane_count": 4, "rows": [{"mode": "0", "lane0": "0-0", "lane1": "0-1",
                                                "lane2": "0-2", "lane3": "0-3"}]},
        "gen_flags": {"arch": None, "pclk-mode": None, "sel-mode": None,
                      "dpr": False, "verible-path": default_verible_path()},
    }
    save_workspace_content(ws_root, payload)
    return payload
