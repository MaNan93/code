"""Persistent application preferences isolated from Qt widgets."""

import sys

from PyQt5 import QtCore


DEFAULT_FONT_FAMILY = "Microsoft YaHei UI"
DEFAULT_FONT_SIZE = 13
DEFAULT_EDITOR = "notepad++" if sys.platform == "win32" else "gvim"


class SettingsStore:
    """Typed access to the settings keys used by the desktop frontend."""

    def __init__(self, settings=None):
        self._settings = (
            settings
            if settings is not None
            else QtCore.QSettings("plm", "plmConsultant")
        )

    def recent_project(self):
        return self._settings.value("navigation/recent_project", "", type=str)

    def set_recent_project(self, project_name):
        self._settings.setValue("navigation/recent_project", project_name)

    def preferences(self):
        return {
            "font_family": self._settings.value(
                "appearance/font_family", DEFAULT_FONT_FAMILY, type=str
            ),
            "font_size": self._settings.value(
                "appearance/font_size", DEFAULT_FONT_SIZE, type=int
            ),
            "editor_path": self._settings.value(
                "tools/editor_path", DEFAULT_EDITOR, type=str
            ),
        }

    def save_preferences(self, preferences):
        self._settings.setValue(
            "appearance/font_family",
            preferences.get("font_family") or DEFAULT_FONT_FAMILY,
        )
        self._settings.setValue(
            "appearance/font_size",
            int(preferences.get("font_size") or DEFAULT_FONT_SIZE),
        )
        self._settings.setValue(
            "tools/editor_path", preferences.get("editor_path") or DEFAULT_EDITOR
        )
        self._settings.sync()

    def editor_path(self):
        return self._settings.value(
            "tools/editor_path", DEFAULT_EDITOR, type=str
        )
