"""sv-merge: Robust, Dependency-Aware SystemVerilog & Verilog Filelist Merger."""

from .version import __version__
from .colors import Colors, log_info, log_warn, log_error
from .parser import FlistParser
from .analyzer import DependencyAnalyzer
from .merger import Merger
from .cli import main

__all__ = [
    "__version__",
    "Colors",
    "log_info",
    "log_warn",
    "log_error",
    "FlistParser",
    "DependencyAnalyzer",
    "Merger",
    "main",
]
