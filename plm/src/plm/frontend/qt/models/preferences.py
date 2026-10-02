"""Defaults shared by preferences storage and presentation."""

import sys

DEFAULT_FONT_FAMILY = "Microsoft YaHei UI"
DEFAULT_FONT_SIZE = 13
DEFAULT_EDITOR = "notepad++" if sys.platform == "win32" else "gvim"
