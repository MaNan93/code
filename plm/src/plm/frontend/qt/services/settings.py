"""Persistent application preferences isolated from Qt widgets."""

import json

from datetime import datetime, timezone
from typing import Dict
from urllib.parse import quote, unquote

from PyQt5 import QtCore

from plm.frontend.qt.models import ProjectState
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR


class SettingsStore:
    """Typed access to the settings keys used by the desktop frontend."""

    def __init__(self, settings=None):
        self._settings = (
            settings
            if settings is not None
            else QtCore.QSettings("plm", "plmConsultant")
        )
        self._project_paths = {}

    def bind_projects(self, projects):
        self._project_paths = {p.name: str(p.config_dir) for p in projects}
        for name, path in self._project_paths.items():
            old = "projects/state/" + quote(name, safe="")
            new = "projects/state/" + quote(path, safe="")
            if self._settings.contains(old + "/is_archived") and not self._settings.contains(new + "/is_archived"):
                for key in ("is_archived", "is_cleared", "is_pinned", "last_opened"):
                    self._settings.setValue(new + "/" + key, self._settings.value(old + "/" + key))
                self._settings.remove(old)
        self._settings.sync()

    def project_paths(self):
        return self._settings.value("projects/paths", [], type=list)

    def save_project_paths(self, paths):
        self._settings.setValue("projects/paths", sorted(str(p) for p in paths))
        self._settings.sync()

    def recent_path(self):
        return self._settings.value("navigation/recent_path", "", type=str)

    def recent_project(self):
        return self._settings.value("navigation/recent_project", "", type=str)

    def set_recent_project(self, project_name):
        self._settings.setValue("navigation/recent_project", project_name)
        if project_name in self._project_paths:
            self._settings.setValue("navigation/recent_path", self._project_paths[project_name])
        state = self.get_project_state(project_name)
        state.last_opened = datetime.now(timezone.utc)
        self.save_project_state(state)

    def clear_recent_project(self, project_name):
        if self.recent_project() == project_name:
            self._settings.remove("navigation/recent_project")
            self._settings.remove("navigation/recent_path")

    def remove_project_state(self, name):
        self._settings.beginGroup("projects/state")
        self._settings.remove(self._project_group(name))
        self._settings.endGroup()
        self.clear_recent_project(name)
        self._settings.sync()

    def _project_group(self, name):
        return quote(self._project_paths.get(name, name), safe="")

    def get_project_state(self, name: str) -> ProjectState:
        self._settings.beginGroup("projects/state")
        self._settings.beginGroup(self._project_group(name))
        archived = self._settings.value("is_archived", False, type=bool)
        cleared = self._settings.value("is_cleared", False, type=bool)
        pinned = self._settings.value("is_pinned", False, type=bool)
        last_opened_value = self._settings.value("last_opened", "", type=str)
        self._settings.endGroup()
        self._settings.endGroup()
        try:
            last_opened = (
                datetime.fromisoformat(last_opened_value)
                if last_opened_value
                else None
            )
        except ValueError:
            last_opened = None
        return ProjectState(
            name=name,
            is_archived=archived,
            is_cleared=cleared,
            is_pinned=pinned,
            last_opened=last_opened,
        )

    def get_project_states(self) -> Dict[str, ProjectState]:
        self._settings.beginGroup("projects/state")
        encoded_names = self._settings.childGroups()
        self._settings.endGroup()
        names = (unquote(encoded_name) for encoded_name in encoded_names)
        return {name: self.get_project_state(name) for name in names}

    def save_project_state(self, state: ProjectState):
        self._settings.beginGroup("projects/state")
        self._settings.beginGroup(self._project_group(state.name))
        self._settings.setValue("is_archived", state.is_archived)
        self._settings.setValue("is_cleared", state.is_cleared)
        self._settings.setValue("is_pinned", state.is_pinned)
        self._settings.setValue(
            "last_opened",
            state.last_opened.isoformat() if state.last_opened else "",
        )
        self._settings.endGroup()
        self._settings.endGroup()
        self._settings.sync()

    def preferences(self):
        return {
            "editor_path": self._settings.value(
                "tools/editor_path", DEFAULT_EDITOR, type=str
            ),
            **self.formatter_preferences(),
        }

    def formatter_preferences(self):
        flags = None
        if self._settings.contains("tools/verible_flags"):
            try:
                value = json.loads(self._settings.value("tools/verible_flags", "", type=str))
                if isinstance(value, dict):
                    flags = value
            except (ValueError, TypeError):
                pass
        return {
            "verible_path": self._settings.value("tools/verible_path", "", type=str),
            "verible_flags": flags,
        }

    def save_preferences(self, preferences):
        self._settings.setValue(
            "tools/editor_path", preferences.get("editor_path") or DEFAULT_EDITOR
        )
        if "verible_path" in preferences:
            self._settings.setValue("tools/verible_path", preferences["verible_path"] or "")
        if "verible_flags" in preferences:
            if preferences["verible_flags"] is None:
                self._settings.remove("tools/verible_flags")
            else:
                self._settings.setValue("tools/verible_flags", json.dumps(preferences["verible_flags"], sort_keys=True))
        self._settings.sync()

    def editor_path(self):
        return self._settings.value(
            "tools/editor_path", DEFAULT_EDITOR, type=str
        )
