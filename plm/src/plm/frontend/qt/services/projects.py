"""Project discovery independent of Qt widgets."""

from pathlib import Path
from typing import List
import shutil
from collections import Counter
from dataclasses import replace

from plm.frontend.qt.models import ProjectInfo
from plm.core.paths import is_deletable_workspace
from plm.core.workspace import scaffold_default_content, workspace_content


class ProjectService:
    """Find valid PLM configuration directories below a repository root."""

    REQUIRED_FILES = frozenset(
        {"controllers.csv", "lane_mapping.csv", "pipe_signals.csv"}
    )

    def __init__(self, project_root):
        self.project_root = Path(project_root).resolve()
        # examples/ is canonical; keep discovering existing legacy workspaces.
        self._search_roots = tuple(self.project_root / name for name in ("examples", "test", "configs"))
        self.external_dirs = set()

    def register(self, path):
        root = Path(path).expanduser().resolve()
        config_dir = root if root.name == "config" else root / "config"
        if not all((config_dir / name).is_file() for name in self.REQUIRED_FILES):
            raise ValueError(f"不是 PLM 项目目录：{root}")
        workspace_content(config_dir.parent)
        self.external_dirs.add(config_dir)
        return config_dir

    def create(self, parent, name):
        name = self.valid_name(name)
        root = Path(parent).expanduser().resolve() / name
        root.mkdir(parents=True, exist_ok=False)
        try:
            scaffold_default_content(root)
            return self.register(root)
        except (OSError, ValueError):
            shutil.rmtree(root)
            raise

    @staticmethod
    def valid_name(name):
        name = name.strip()
        if (
            not name
            or name in (".", "..")
            or any(c in name for c in '/\\\\<>:"|?*')
            or any(ord(c) < 32 for c in name)
            or name.split(".")[0].upper() in {"CON", "PRN", "AUX", "NUL", *[f"COM{i}" for i in range(1, 10)], *[f"LPT{i}" for i in range(1, 10)]}
            or name.endswith((".", " "))
        ):
            raise ValueError("项目名为空或包含非法字符")
        return name

    def discover(self) -> List[ProjectInfo]:
        discovered = []
        seen = set()
        candidates = list(self.external_dirs)
        for search_root in self._search_roots:
            if not search_root.is_dir():
                continue
            candidates.extend(p.parent for p in search_root.rglob("controllers.csv"))
        for candidate in candidates:
            config_dir = candidate.resolve()
            if config_dir in seen:
                continue
            # WorkspaceService only opens <project>/config; loose CSVs in
            # some other directory would be listed and then fail to load.
            if config_dir.name != "config":
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
        counts = Counter(p.name for p in discovered)
        discovered = [
            replace(p, name=f"{p.name} [{p.config_dir.parent.parent}]")
            if counts[p.name] > 1
            else p
            for p in discovered
        ]
        return sorted(discovered, key=lambda project: project.name.casefold())

    def _find(self, name):
        matches = [project for project in self.discover() if project.name == name]
        if len(matches) != 1:
            raise ValueError(f"项目 {name!r} 不存在或名称不唯一")
        return matches[0]

    def _project_dir(self, project):
        config_dir = project.config_dir.resolve()
        roots = self._search_roots
        if config_dir not in self.external_dirs and not any(
            config_dir.is_relative_to(root.resolve()) for root in roots
        ):
            raise ValueError("项目目录不在允许的工作区内")
        project_dir = (
            config_dir.parent if config_dir.name.casefold() == "config" else config_dir
        )
        if any(project_dir == root.resolve() for root in roots):
            raise ValueError("不能修改项目列表根目录")
        return project_dir

    def rename(self, old_name, new_name):
        new_name = self.valid_name(new_name)
        project = self._find(old_name)
        source = self._project_dir(project)
        target = source.with_name(new_name)
        if target.exists():
            raise FileExistsError(f"项目目录已存在：{target}")
        source.rename(target)
        config_dir = (
            target / "config"
            if project.config_dir.name.casefold() == "config"
            else target
        )
        if project.config_dir in self.external_dirs:
            self.external_dirs.remove(project.config_dir)
            self.external_dirs.add(config_dir)
        return config_dir

    def delete(self, name):
        project = self._find(name)
        project_dir = self._project_dir(project)
        if not is_deletable_workspace(project_dir):
            raise ValueError("该目录缺少 .plm-workspace 标记，不能删除项目")
        shutil.rmtree(project_dir)
        self.external_dirs.discard(project.config_dir)
