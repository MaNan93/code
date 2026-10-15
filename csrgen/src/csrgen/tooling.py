"""Run RTL tools with isolated temporary files and useful failure messages."""
from dataclasses import dataclass
from pathlib import Path
import shutil
import subprocess
import tempfile

from .diagnostics import CodeToolError


@dataclass(frozen=True)
class ToolReport:
    command: tuple[str, ...]
    stdout: str
    stderr: str


def run_rtl_tool(rtl, executable, arguments, *, timeout=60):
    resolved = shutil.which(str(executable))
    if not resolved:
        raise CodeToolError(f"RTL tool not found: {executable}")
    with tempfile.TemporaryDirectory(prefix="csrgen-") as directory:
        source = Path(directory) / "input.sv"
        source.write_text(rtl, encoding="utf-8")
        command = [resolved, *arguments, str(source)]
        try:
            result = subprocess.run(command, cwd=directory, capture_output=True,
                                    text=True, encoding="utf-8", errors="replace", timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise CodeToolError(f"{executable}: {exc}") from exc
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip() or "no diagnostics"
            raise CodeToolError(f"{executable} failed (exit {result.returncode}):\n{detail}")
        return ToolReport(tuple(command), result.stdout, result.stderr)
