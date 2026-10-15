"""Optional SystemVerilog formatting independent of code generation."""
from .diagnostics import CodeToolError
from .tooling import run_rtl_tool


def format_rtl(rtl, executable="verible-verilog-format"):
    report = run_rtl_tool(rtl, executable, ["--failsafe_success=false"])
    if not report.stdout.strip():
        raise CodeToolError(f"{executable}: formatter returned empty output")
    return report.stdout
