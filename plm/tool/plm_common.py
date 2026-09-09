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

import shutil
import subprocess
from pathlib import Path

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


def format_sv(text, verible_path=None):
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
    """
    exe = find_verible(verible_path)
    if exe is None:
        return text
    args = [
        exe,
        "--assignment_statement_alignment=align",
        "--case_items_alignment=align",
        "--distribution_items_alignment=align",
        "--formal_parameters_alignment=align",
        "--formal_parameters_indentation=indent",
        "--named_parameter_alignment=align",
        "--named_parameter_indentation=indent",
        "--named_port_alignment=align",
        "--named_port_indentation=indent",
        "--parameter_declaration_alignment=align",
        "--port_declarations_alignment=align",
        "--port_declarations_indentation=indent",
        "--port_declarations_right_align_packed_dimensions=true",
        "--struct_union_members_alignment=align",
        "--wrap_end_else_clauses=true",
        "--indentation_spaces=4",
        "--column_limit=120",
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
