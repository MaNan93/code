"""Review generated SystemVerilog with Verilator."""
from .tooling import run_rtl_tool
from .validation import validate_identifier


def review_rtl(rtl, module="apb_csr", executable="verilator"):
    validate_identifier(module, "module name")
    return run_rtl_tool(rtl, executable, ["--lint-only", "--top-module", module])
