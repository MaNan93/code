"""
verible-verilog-format invocation -- best-effort auto-formatting of
generated SystemVerilog text.
"""

import hashlib
import shutil
import subprocess
from functools import lru_cache
from pathlib import Path


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
# and by the Qt Settings UI (which control to render for each one).
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
# Only user-facing formatting controls belong in the Settings table.
# ``lines`` (partial formatting) and ``stdin_name`` (diagnostics only) are
# invocation details and are intentionally not exposed by PLM.
VERIBLE_STR_PARAMS = ("line_terminator",)

# PLM's formatter preset.  Every parameter exposed by the UI has one explicit
# value here; ``(default)`` in Settings always means this PLM preset, never a
# second Verible-internal default system.  Values that were previously omitted
# use Verible's effective defaults so existing generated formatting is stable.
DEFAULT_VERIBLE_FLAGS = {
    "assignment_statement_alignment": "align",
    "case_items_alignment": "align",
    "class_member_variable_alignment": "infer",
    "distribution_items_alignment": "align",
    "enum_assignment_statement_alignment": "infer",
    "formal_parameters_alignment": "align",
    "module_net_variable_alignment": "infer",
    "named_parameter_alignment": "align",
    "named_port_alignment": "align",
    "port_declarations_alignment": "align",
    "struct_union_members_alignment": "align",
    "formal_parameters_indentation": "indent",
    "named_parameter_indentation": "indent",
    "named_port_indentation": "indent",
    "port_declarations_indentation": "indent",
    "compact_indexing_and_selections": "true",
    "expand_coverpoints": "false",
    "port_declarations_right_align_packed_dimensions": "true",
    "port_declarations_right_align_unpacked_dimensions": "false",
    "try_wrap_long_lines": "false",
    "wrap_end_else_clauses": "true",
    "verify": "false",
    "verify_convergence": "true",
    "failsafe_success": "true",
    "column_limit": "120",
    "indentation_spaces": "4",
    "line_break_penalty": "2",
    "over_column_limit_penalty": "100",
    "max_search_states": "100000",
    "line_terminator": "auto",
}


@lru_cache(maxsize=8)
def _binary_hash(path, size, mtime_ns):
    """Return an executable identity, cached until its stat changes."""
    del size, mtime_ns
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def formatter_identity(verible_path=None, verible_flags=None):
    """Describe every formatter input that can change emitted whitespace."""
    flags = DEFAULT_VERIBLE_FLAGS if verible_flags is None else verible_flags
    normalized_flags = {
        str(key): str(value)
        for key, value in sorted(flags.items())
        if value is not None and value != ""
    }
    executable = find_verible(verible_path)
    if executable is None:
        return {"engine": "none", "flags": normalized_flags}

    resolved = shutil.which(executable)
    if resolved is None:
        candidate = Path(executable).expanduser()
        if candidate.is_file():
            resolved = str(candidate.resolve())
    if resolved is None:
        return {
            "engine": "unavailable",
            "requested": str(executable),
            "flags": normalized_flags,
        }

    path = Path(resolved)
    stat = path.stat()
    return {
        "engine": "verible-verilog-format",
        "binary_sha256": _binary_hash(
            str(path.resolve()), stat.st_size, stat.st_mtime_ns
        ),
        "flags": normalized_flags,
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
    plain string, e.g. from a front end's Settings UI) that replaces
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
