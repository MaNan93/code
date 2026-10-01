"""Static project metadata and mutable user state."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


@dataclass(frozen=True)
class ProjectInfo:
    """Immutable project information discovered from the filesystem."""

    name: str
    config_dir: Path
    controllers_csv: Path
    lane_mapping_csv: Path
    pipe_signals_csv: Path


@dataclass
class ProjectState:
    """Mutable per-project preferences persisted by ``SettingsStore``."""

    name: str
    is_archived: bool = False
    is_pinned: bool = False
    last_opened: datetime | None = None
