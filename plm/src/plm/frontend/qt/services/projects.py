"""Project discovery independent of Qt widgets."""

from pathlib import Path
from typing import List
import shutil

from plm.frontend.qt.models import ProjectInfo
from plm.core.paths import is_deletable_workspace


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

    def _find(self, name):
        matches = [project for project in self.discover() if project.name == name]
        if len(matches) != 1:
            raise ValueError(f"项目 {name!r} 不存在或名称不唯一")
        return matches[0]

    def _project_dir(self, project):
        config_dir = project.config_dir.resolve()
        roots = (self.project_root / "test", self.project_root / "configs")
        if not any(config_dir.is_relative_to(root.resolve()) for root in roots):
            raise ValueError("项目目录不在允许的工作区内")
        project_dir = config_dir.parent if config_dir.name.casefold() == "config" else config_dir
        if any(project_dir == root.resolve() for root in roots):
            raise ValueError("不能修改项目列表根目录")
        return project_dir

    def rename(self, old_name, new_name):
        new_name = new_name.strip()
        if (not new_name or new_name in (".", "..") or
                "/" in new_name or "\\" in new_name or Path(new_name).name != new_name):
            raise ValueError("项目名不能包含路径分隔符或为空")
        project = self._find(old_name)
        source = self._project_dir(project)
        target = source.with_name(new_name)
        if target.exists():
            raise FileExistsError(f"项目目录已存在：{target}")
        source.rename(target)
        return target / "config" if project.config_dir.name.casefold() == "config" else target

    def delete(self, name):
        project_dir = self._project_dir(self._find(name))
        if not is_deletable_workspace(project_dir):
            raise ValueError("该目录缺少 .plm-workspace 标记，不能删除项目")
        shutil.rmtree(project_dir)
