"""Interpret mapped cells as fields and enforce register content rules."""
import re

from .diagnostics import TableError
from .models import Field, Register
from .validation import _normalize_reserved, validate_aw, validate_registers
from .values import _empty, _hex_cell, _integer


def parse_registers(rows, aw=16):
    validate_aw(aw)
    registers = {}
    current_offset = None
    offset_rows = {}
    for row in rows:
        row_num, cells = row.number, row.values
        if all(_empty(value) for value in cells.values()):
            continue
        label = f"row {row_num}"
        if not _empty(cells["offset"]):
            offset = _hex_cell(cells["offset"], label + " offset")
            # Repeating the offset on consecutive rows is fine; returning to an
            # earlier one would silently merge two register blocks.
            if offset != current_offset and offset in offset_rows:
                raise TableError(f"{label}: duplicate register offset 0x{offset:X}, "
                                 f"already defined at row {offset_rows[offset]}")
            offset_rows.setdefault(offset, row_num)
            current_offset = offset
        if _empty(cells["signal"]):
            if any(not _empty(cells[key]) for key in ("reset", "bit", "access")):
                raise TableError(f"{label}: signal is missing")
            # Permit a row containing only a register offset / description.
            continue
        if current_offset is None:
            raise TableError(f"{label}: first field requires an offset")
        name = str(cells["signal"]).strip()
        reserved = name.lower() == "reserved"
        required = ("bit",) if reserved else ("reset", "bit", "access")
        for key in required:
            if _empty(cells[key]):
                raise TableError(f"{label}: {key} is missing")
        bit = str(cells["bit"]).strip()
        # Excel reads an integer-valued numeric cell as int (occasionally float).
        if isinstance(cells["bit"], (int, float)) and not isinstance(cells["bit"], bool):
            bit = str(_integer(cells["bit"], 10, label + " bit"))
        match = re.fullmatch(r"\[?\s*(\d+)\s*(?::\s*(\d+)\s*)?\]?", bit)
        if not match:
            raise TableError(f"{label}: invalid bit range {cells['bit']!r}; use 0 or 30:3")
        msb = int(match[1])
        lsb = int(match[2]) if match[2] is not None else msb
        item = Field(
            name, msb, lsb,
            cells["reset"] if reserved else _hex_cell(cells["reset"], label + " reset"),
            str(cells["access"] or "").strip().lower(),
            str(cells.get("description") or "").strip(), row_num,
        )
        item = _normalize_reserved(item, current_offset)
        reg = registers.setdefault(current_offset, Register(current_offset))
        reg.fields.append(item)
    result = sorted(registers.values(), key=lambda reg: reg.offset)
    validate_registers(result, aw)
    return result
