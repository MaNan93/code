"""Cell conversion shared by register parsing and validation."""
import math
import warnings

from .diagnostics import NumericCellWarning, TableError


def _empty(value):
    return value is None or (isinstance(value, str) and not value.strip())



def _integer(value, base, label):
    if isinstance(value, bool):
        raise TableError(f"{label}: boolean values are not numbers")
    if isinstance(value, (int, float)):
        if isinstance(value, float) and (not math.isfinite(value) or not value.is_integer()):
            raise TableError(f"{label}: expected an integer, got {value!r}")
        # Excel numeric cells represent numbers, not hexadecimal digit strings.
        return int(value)
    token = str(value).strip().replace("_", "")
    if token.startswith("="):
        raise TableError(f"{label}: formulas are not supported; use a literal value")
    try:
        return int(token, base)
    except ValueError as exc:
        raise TableError(f"{label}: invalid number {value!r}") from exc



def _hex_cell(value, label):
    """Parse an offset/reset cell; warn when a numeric cell reads differently as hex."""
    number = _integer(value, 16, label)
    if not isinstance(value, str) and abs(number) >= 10:
        warnings.warn(
            f"{label}: numeric cell {number} is used as decimal (0x{number:X}); "
            f"enter it as text for hexadecimal 0x{number}",
            NumericCellWarning, stacklevel=3,
        )
    return number
