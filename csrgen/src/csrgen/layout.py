"""Apply explicit header and column layout to raw table cells."""
from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Mapping

from .diagnostics import TableError


TEMPLATE_COLUMNS = ("offset", "signal", "reset", "bit", "access", "description")
DEFAULT_COLUMNS = dict(zip(TEMPLATE_COLUMNS, range(2, 8)))


@dataclass(frozen=True)
class TableLayout:
    header_rows: int = 1
    columns: Mapping[str, int | None] = field(default_factory=lambda: dict(DEFAULT_COLUMNS))

    def __post_init__(self):
        if isinstance(self.header_rows, bool) or not isinstance(self.header_rows, int) or self.header_rows < 0:
            raise TableError("header_rows must be a nonnegative integer")
        columns = dict(self.columns)
        unknown = columns.keys() - set(TEMPLATE_COLUMNS)
        if unknown:
            raise TableError(f"unknown table fields: {', '.join(sorted(unknown))}")
        required = set(TEMPLATE_COLUMNS) - {"description"}
        missing = [name for name in sorted(required) if columns.get(name) is None]
        if missing:
            raise TableError(f"missing column mapping: {', '.join(missing)}")
        columns.setdefault("description", None)
        used = set()
        for name, column in columns.items():
            if column is None:
                continue
            if isinstance(column, bool) or not isinstance(column, int) or column < 1:
                raise TableError(f"{name}: column must be a positive 1-based index")
            if column in used:
                raise TableError(f"duplicate column mapping: {column}")
            used.add(column)
        object.__setattr__(self, "columns", MappingProxyType(columns))


@dataclass(frozen=True)
class MappedRow:
    number: int
    values: Mapping[str, object]


def column_number(value):
    """Accept Excel letters or a positive 1-based column number."""
    token = str(value).strip()
    if token.isascii() and token.isdigit() and int(token) > 0:
        return int(token)
    if token and token.isascii() and token.isalpha():
        result = 0
        for char in token.upper():
            result = result * 26 + ord(char) - ord("A") + 1
        return result
    raise TableError(f"invalid column {value!r}; use Excel letters or a 1-based number")


def layout_from_overrides(header_rows=1, overrides=()):
    columns = dict(DEFAULT_COLUMNS)
    seen = set()
    for override in overrides:
        name, separator, value = override.partition("=")
        name, value = name.strip().lower(), value.strip()
        if not separator or name not in TEMPLATE_COLUMNS:
            raise TableError(f"invalid column mapping {override!r}; use FIELD=COLUMN")
        if name in seen:
            raise TableError(f"duplicate column override for {name}")
        seen.add(name)
        columns[name] = None if value.lower() in {"none", "-"} else column_number(value)
    return TableLayout(header_rows=header_rows, columns=columns)


def map_rows(table, layout=None):
    layout = layout or TableLayout()
    result = []
    for row in table.rows:
        if row.number <= layout.header_rows:
            continue
        values = {name: row.cells[column - 1]
                  if column is not None and column <= len(row.cells) else None
                  for name, column in layout.columns.items()}
        result.append(MappedRow(row.number, values))
    return result
