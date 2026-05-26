"""vmodeditor - Verilog/SystemVerilog module analysis and editing tool.

Uses verible-verilog-syntax CST for precise source code navigation and editing.
CLI interface compatible with modeditor.
"""

from .cli import main
from .utils import ModuleEditor

__all__ = ["main", "ModuleEditor"]
