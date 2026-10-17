"""
verible-verilog-format invocation -- best-effort auto-formatting of
generated SystemVerilog text.
"""

import hashlib
import re
import shutil
import subprocess
from collections import OrderedDict
from functools import lru_cache
from pathlib import Path
from threading import Lock


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


# Only config-independent common modules opt in. Bound both the entry count
# and stored UTF-8 bytes so changing formatter settings cannot grow the cache
# indefinitely during a long-running GUI session.
_FORMAT_CACHE_MAX_ENTRIES = 32
_FORMAT_CACHE_MAX_BYTES = 8 * 1024 * 1024
_FORMAT_CACHE = OrderedDict()
_FORMAT_CACHE_BYTES = 0
_FORMAT_CACHE_LOCK = Lock()
_FORMAT_WRAPPER_SUFFIXES = {".bat", ".cmd", ".ps1", ".py", ".sh"}
_SV_FORMAT_TOKEN = re.compile(
    r'//[^\r\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\\[^\s]+'
    r"|[A-Za-z_$][A-Za-z0-9_$]*|[0-9][A-Za-z0-9_$]*"
    r"|<<<=|>>>=|===|!==|==\?|!=\?|<<<|>>>|<<=|>>=|\*\*>|\|->|\|=>"
    r"|&&&|<->|::|:=|:/|\+\+|--|\*\*|&&|\|\||<<|>>|<=|>="
    r"|==|!=|\+=|-=|\*=|/=|%=|&=|\|=|\^=|~&|~\||~\^|\^~|->|=>|\*\>|``|\S",
    re.DOTALL,
)


def _format_tokens(text):
    """Keep literal contents and lexical boundaries intact for cache safety.

    Comments may have their spacing changed, but remain separate tokens so
    swallowing subsequent code into a line comment is detected. This is a
    conservative formatting check, not a complete SystemVerilog parser.
    """
    return tuple(
        "".join(token.split()) if token.startswith(("//", "/*")) else token
        for token in _SV_FORMAT_TOKEN.findall(text)
    )


def _format_cache_key(source, executable, flags):
    # A wrapper's content does not identify the program it invokes. Avoid
    # reusing its output after the underlying formatter changes independently.
    resolved = shutil.which(executable) or executable
    if Path(resolved).suffix.lower() in _FORMAT_WRAPPER_SUFFIXES:
        return None
    try:
        with Path(resolved).open("rb") as handle:
            if handle.read(2) == b"#!":
                return None
        identity = formatter_identity(executable, flags)
    except OSError:
        return None
    if identity["engine"] != "verible-verilog-format":
        return None
    return (
        hashlib.sha256(source).hexdigest(),
        identity["binary_sha256"],
        tuple(identity["flags"].items()),
    )


def _cached_format(key):
    if key is None:
        return None
    with _FORMAT_CACHE_LOCK:
        entry = _FORMAT_CACHE.get(key)
        if entry is not None:
            _FORMAT_CACHE.move_to_end(key)
            return entry[0]
    return None


def _cache_format(key, formatted):
    global _FORMAT_CACHE_BYTES
    size = len(formatted.encode("utf-8"))
    if key is None or size > _FORMAT_CACHE_MAX_BYTES:
        return
    with _FORMAT_CACHE_LOCK:
        old = _FORMAT_CACHE.pop(key, None)
        if old is not None:
            _FORMAT_CACHE_BYTES -= old[1]
        _FORMAT_CACHE[key] = (formatted, size)
        _FORMAT_CACHE_BYTES += size
        while (
            len(_FORMAT_CACHE) > _FORMAT_CACHE_MAX_ENTRIES
            or _FORMAT_CACHE_BYTES > _FORMAT_CACHE_MAX_BYTES
        ):
            _, (_, removed_size) = _FORMAT_CACHE.popitem(last=False)
            _FORMAT_CACHE_BYTES -= removed_size


def format_sv(text, verible_path=None, verible_flags=None, *, cache=False, strict=False, timeout=10):
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

    ``cache=True`` lets the exporter reuse successful formatting of common
    modules across configurations. Generated files and ordinary callers keep
    the uncached behavior. A missing or failing tool is always retried, and
    output is cached only after the whitespace and token checks pass. Script
    wrappers cannot identify their downstream binary and remain uncached.

    ``strict=True`` reports missing tools, process failures and invalid output
    to interactive previews. Generator callers retain best-effort fallback.
    """
    exe = find_verible(verible_path)
    if exe is None:
        if strict:
            raise OSError("未找到 Verible，请先选择格式化工具。")
        return text
    flags = DEFAULT_VERIBLE_FLAGS if verible_flags is None else verible_flags
    source = text.encode("utf-8")
    cache_key = _format_cache_key(source, exe, flags) if cache else None
    cached = _cached_format(cache_key)
    if cached is not None:
        return cached
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
        r = subprocess.run(args, input=source, capture_output=True, timeout=timeout)
        if strict and r.returncode != 0:
            detail = r.stderr.decode("utf-8", errors="replace").strip()
            raise ValueError(detail or f"Verible 返回错误状态 {r.returncode}。")
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
            same_whitespace = "".join(formatted.split()) == "".join(text.split())
            same_tokens = _format_tokens(formatted) == _format_tokens(text)
            if same_whitespace and same_tokens:
                # A replaced executable must not poison the old binary's
                # cache entry with the new binary's output.
                if cache_key is not None and cache_key == _format_cache_key(source, exe, flags):
                    _cache_format(cache_key, formatted)
                return formatted
        if strict:
            raise ValueError("Verible 返回了空内容或改变了源代码标记，无法显示预览。")
    except (OSError, subprocess.SubprocessError, UnicodeError):
        if strict:
            raise
        pass
    return text
