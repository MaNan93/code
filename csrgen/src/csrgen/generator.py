"""Compatibility facade; implementation is split into independent stages."""
from .diagnostics import NumericCellWarning, ReservedFieldWarning, TableError
from .models import Field, Register
from .pipeline import read_xlsx
from .rtl import generate_rtl
from .validation import validate_aw, validate_identifier, validate_registers

__all__ = [
    "Field", "Register", "TableError", "NumericCellWarning", "ReservedFieldWarning",
    "read_xlsx", "generate_rtl", "validate_aw", "validate_identifier", "validate_registers",
]
