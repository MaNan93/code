"""Orchestrate reading, layout, parsing, emission, review and formatting."""
from dataclasses import dataclass, field

from .formatter import format_rtl
from .layout import TableLayout, map_rows
from .models import Register
from .naming import resolve_module_name
from .parser import parse_registers
from .quality import review_rtl
from .reader import ReadOptions, read_table, read_xlsx_table
from .rtl import generate_rtl
from .tooling import ToolReport
from .validation import validate_aw


@dataclass(frozen=True)
class GenerationOptions:
    read: ReadOptions = field(default_factory=ReadOptions)
    layout: TableLayout = field(default_factory=TableLayout)
    module: str | None = None
    aw: int = 16
    lint: bool = False
    format: bool = False
    lint_tool: str = "verilator"
    format_tool: str = "verible-verilog-format"
    module_prefix: str | None = None


@dataclass(frozen=True)
class GenerationResult:
    registers: list[Register]
    rtl: str
    reviews: tuple[ToolReport, ...] = ()


def read_xlsx(path, sheet="sheet1", aw=16, *, layout=None):
    """Backward-compatible XLSX API with an optional explicit table layout."""
    validate_aw(aw)
    table = read_xlsx_table(path, ReadOptions(sheet=sheet))
    return parse_registers(map_rows(table, layout), aw=aw)


def run_pipeline(path, options=None, *, readers=None):
    options = options or GenerationOptions()
    validate_aw(options.aw)
    module = resolve_module_name(path, options.module, options.module_prefix)
    table = read_table(path, options.read, readers=readers)
    registers = parse_registers(map_rows(table, options.layout), aw=options.aw)
    rtl = generate_rtl(registers, module=module, aw=options.aw)
    reviews = []
    if options.lint:
        reviews.append(review_rtl(rtl, module, options.lint_tool))
    if options.format:
        rtl = format_rtl(rtl, options.format_tool)
        if options.lint:
            reviews.append(review_rtl(rtl, module, options.lint_tool))
    return GenerationResult(registers, rtl, tuple(reviews))
