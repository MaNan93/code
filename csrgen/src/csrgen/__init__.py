"""XLSX to APB3 register RTL generator."""
from .generator import Field, NumericCellWarning, Register, ReservedFieldWarning, TableError, generate_rtl, read_xlsx
from .diagnostics import CodeToolError
from .layout import TableLayout
from .pipeline import GenerationOptions, GenerationResult, run_pipeline
from .reader import ReadOptions

__all__ = [
    "Field", "NumericCellWarning", "Register", "ReservedFieldWarning", "TableError",
    "generate_rtl", "read_xlsx", "CodeToolError", "TableLayout", "ReadOptions",
    "GenerationOptions", "GenerationResult", "run_pipeline",
]
