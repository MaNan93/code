"""Adapter from project metadata to the shared PLM workspace and generator APIs."""

from contextlib import redirect_stdout
from io import StringIO
import os
from pathlib import Path

from plm.core.exporter import MANIFEST_NAME, output_set_matches_plan, read_manifests
from plm.core.gen_flags import GenerationOptions
from plm.core.service import generate
from plm.core.validation import load_generation_plan, load_generation_plan_from_payload
from plm.core.workspace import save_workspace_content, workspace_content


class WorkspaceService:
    def __init__(self, formatter_provider=None):
        self.formatter_provider = formatter_provider or (lambda: {})

    @staticmethod
    def signature(project):
        files = []
        for name in ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv", "gen_flags.txt"):
            try:
                content = (project.config_dir / name).read_bytes()
            except FileNotFoundError:
                content = None
            files.append((name, content))
        return tuple(files)

    @staticmethod
    def _root(project):
        if project.config_dir.name != "config":
            raise ValueError(f"工作区应包含 config/ 目录：{project.config_dir}")
        return project.config_dir.parent

    def _options(self, payload):
        flags = payload.get("gen_flags") or {}
        arch = flags.get("arch") or "original_pipe"
        pclk_mode = flags.get("pclk-mode") or (
            "pclk_as_phy_input" if arch == "serdes" else "pclk_as_phy_output"
        )
        formatter = self.formatter_provider()
        return GenerationOptions(
            arch=arch,
            pclk_mode=pclk_mode,
            dpr=bool(flags.get("dpr")),
            bus_type=flags.get("bus-type") or "bus",
            module_prefix=flags.get("module_prefix", ""),
            file_prefix=flags.get("file_prefix", ""),
            macro_prefix=flags.get("macro_prefix", ""),
            verible_path=str(Path(formatter["verible_path"]).expanduser()) if formatter.get("verible_path") else None,
            verible_flags=formatter.get("verible_flags"),
        )

    def load(self, project):
        payload = workspace_content(self._root(project))
        if payload.get("empty"):
            raise ValueError(f"配置 CSV 不完整：{project.config_dir}")
        return payload

    def load_with_signature(self, project):
        """Accept a load only while the files remain at the same revision."""
        before = self.signature(project)
        payload = self.load(project)
        if self.signature(project) != before:
            raise ValueError("配置文件在加载期间被外部修改，请重新打开项目。")
        return payload, before

    def validate(self, payload):
        return load_generation_plan_from_payload(payload, self._options(payload))

    def save(self, project, payload):
        self.validate(payload)
        save_workspace_content(self._root(project), payload)

    def generate(self, project, payload, progress=None, on_saved=None, *, force=False):
        self.save(project, payload)
        if on_saved:
            on_saved()
        root = self._root(project)
        report = StringIO()
        with redirect_stdout(report):
            result = generate(
                project.config_dir, root / "rtl", self._options(payload), progress,
                **({"force": True} if force else {}),
            )
        if result.plan.formatter.get("engine") == "unavailable":
            report.write("配置的 Verible 不可用，已保留生成器原始排版。\n")
        return result, self.output_files(project), report.getvalue()

    def output_state(self, project, payload, *, plan=None, use_disk=False):
        if not self.output_files(project):
            return "ready"
        if use_disk:
            # Preserve the generation identity of untouched CSVs, including CLI outputs
            # generated from hand-aligned CSV text rather than editor serialization.
            plan = load_generation_plan(project.config_dir, self._options(payload))
        elif plan is None:
            plan = self.validate(payload)
        current = output_set_matches_plan(plan, self._root(project), verify_files=True)
        return "up_to_date" if current else "out_of_date"

    def output_files(self, project):
        root = self._root(project).resolve()
        folders = {kind: (root / kind).resolve() for kind in ("rtl", "tb")}
        safe_manifests = all(
            folder.is_relative_to(root)
            and (folder / MANIFEST_NAME).resolve().is_relative_to(folder)
            for folder in folders.values()
        )
        manifests = read_manifests(root) if safe_manifests else {}
        files = []
        for kind in ("rtl", "tb"):
            folder = folders[kind]
            if not folder.is_relative_to(root) or not folder.is_dir():
                continue
            if manifests:
                for name in (MANIFEST_NAME, *manifests[kind]["files"]):
                    path = (folder / name).resolve()
                    if path.is_relative_to(folder) and path.is_file():
                        files.append(path)
                continue
            # Legacy outputs have no manifest. Prune simulator trees before walking.
            for directory, directories, names in os.walk(folder, followlinks=False):
                directories[:] = [
                    name for name in directories
                    if name not in {"csrc", "obj_dir", "DVEfiles", "verdiLog"}
                    and not name.endswith(".daidir")
                ]
                for name in names:
                    path = Path(directory) / name
                    if name in {"simv", "simv.exe"} or path.suffix.lower() in {
                        ".fsdb", ".vcd", ".vpd", ".o", ".obj", ".dll", ".exe",
                    }:
                        continue
                    resolved = path.resolve()
                    if resolved.is_relative_to(folder) and resolved.is_file():
                        files.append(resolved)
        return sorted(files)
