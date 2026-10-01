"""Non-visual services used by the Qt presentation layer."""

from .projects import ProjectService
from .settings import (
    DEFAULT_EDITOR,
    DEFAULT_FONT_FAMILY,
    DEFAULT_FONT_SIZE,
    SettingsStore,
)

__all__ = [
    "DEFAULT_EDITOR",
    "DEFAULT_FONT_FAMILY",
    "DEFAULT_FONT_SIZE",
    "ProjectService",
    "SettingsStore",
]
