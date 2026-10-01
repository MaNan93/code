"""Project discovery independent of Qt widgets."""

from pathlib import Path
from typing import List

from plm.frontend.qt.models import ProjectInfo


class ProjectService:
    """Find valid PLM configuration directories below a repository root."""

    REQUIRED_FILES = frozenset(
        {"controllers.csv", "lane_mapping.csv", "pipe_signals.csv"}
    )

    def __init__(self, project_root):
        self.project_root = Path(project_root).resolve()

    def discover(self) -> List[ProjectInfo]:
        discovered = []
        seen = set()
        for search_root in (
            self.project_root / "test",
            self.project_root / "configs",
        ):
            if not search_root.is_dir():
                continue
            for controllers_file in search_root.rglob("controllers.csv"):
                config_dir = controllers_file.parent.resolve()
                if config_dir in seen:
                    continue
                try:
                    file_names = {
                        path.name for path in config_dir.iterdir() if path.is_file()
                    }
                except OSError:
                    continue
                if not self.REQUIRED_FILES.issubset(file_names):
                    continue
                seen.add(config_dir)
                project_name = (
                    config_dir.parent.name
                    if config_dir.name.casefold() == "config"
                    else config_dir.name
                )
                discovered.append(
                    ProjectInfo(
                        name=project_name,
                        config_dir=config_dir,
                        controllers_csv=config_dir / "controllers.csv",
                        lane_mapping_csv=config_dir / "lane_mapping.csv",
                        pipe_signals_csv=config_dir / "pipe_signals.csv",
                    )
                )
        return sorted(discovered, key=lambda project: project.name.casefold())
