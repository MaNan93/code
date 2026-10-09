"""Defaults shared by preferences storage and presentation."""

import sys

DEFAULT_EDITOR = "notepad++" if sys.platform == "win32" else "gvim"
