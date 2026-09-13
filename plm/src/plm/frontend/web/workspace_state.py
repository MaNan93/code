"""
Recent-workspace / last-workspace state file for the web front end.

A small, independent copy of the Qt front end's own equivalent (see
plm.frontend.qt.main_window) -- kept separate (own state file, own copy
of the logic) so the two front ends never interfere with each other just
from both being open at once, per this project's "coexist" decision.
"""

import json
from pathlib import Path

from plm.core.paths import is_workspace_root

STATE_FILE = Path.home() / ".plm_web_workspace.json"
MAX_RECENT_WORKSPACES = 10


class ApiError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def _read_state_file():
    if not STATE_FILE.is_file():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _write_state_file(data):
    try:
        STATE_FILE.write_text(json.dumps(data), encoding="utf-8")
    except OSError:
        pass  # remembering workspace state is a convenience, not required


def load_recent_workspaces():
    raw = _read_state_file().get("recent", [])
    return [p for p in (Path(r) for r in raw) if is_workspace_root(p)]


def add_recent_workspace(path):
    """Appends path if it's not already listed -- an already-listed entry
    keeps its existing position instead of jumping to the front on every
    open, so the Recent list holds still and isn't reordered by use."""
    data = _read_state_file()
    path_str = str(path)
    recent = data.get("recent", [])
    if path_str not in recent:
        recent.append(path_str)
    # Still capped, but trimmed from the oldest (front) end now that the
    # list is insertion-ordered rather than most-recently-used-first.
    data["recent"] = recent[-MAX_RECENT_WORKSPACES:]
    _write_state_file(data)


def save_last_workspace(path):
    data = _read_state_file()
    data["workspace"] = str(path)
    _write_state_file(data)


def load_last_workspace():
    raw = _read_state_file().get("workspace")
    if not raw:
        return None
    path = Path(raw)
    return path if is_workspace_root(path) else None


def valid_name(name):
    name = (name or "").strip()
    if not name or any(c in name for c in ' /\\:*?"<>|'):
        raise ApiError('Use a plain folder name, no spaces or path characters.')
    return name
