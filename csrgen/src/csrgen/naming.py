"""Resolve module names and output paths independently from the input stem."""
from pathlib import Path

from .diagnostics import TableError
from .validation import validate_identifier


def resolve_module_name(source, module=None, module_prefix=None):
    base = Path(source).stem if module is None else module
    if module_prefix is not None:
        if not module_prefix:
            raise TableError("module prefix must not be empty")
        name = f"{module_prefix}_{base}"
    else:
        name = base
    try:
        validate_identifier(name, "module name")
    except TableError as exc:
        if module is None:
            raise TableError(f"{exc}; use --module to override the input filename") from exc
        raise
    return name


def resolve_output_path(source, output=None, file_prefix=None):
    source = Path(source)
    if output is not None and file_prefix is not None:
        raise TableError("output and file prefix cannot be combined")
    filename = f"{source.stem}.sv"
    if file_prefix is not None:
        if not file_prefix or any(ord(ch) < 32 or ch in '<>:"/\\|?*' for ch in file_prefix):
            raise TableError("file prefix must be nonempty and contain no path separators or invalid filename characters")
        filename = f"{file_prefix}_{source.stem}.sv"
    destination = Path(output) if output is not None else Path(filename)
    if destination.resolve() == source.resolve():
        raise TableError("output must not overwrite the input XLSX")
    return destination
