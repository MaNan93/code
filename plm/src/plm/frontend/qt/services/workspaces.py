"""Adapter from project metadata to the shared PLM workspace and generator APIs."""

from contextlib import redirect_stdout
from io import StringIO

from plm.core.gen_flags import GenerationOptions
from plm.core.service import generate
from plm.core.validation import load_generation_plan_from_payload
from plm.core.workspace import save_workspace_content, workspace_content


class WorkspaceService:
    @staticmethod
    def _root(project):
        if project.config_dir.name != "config":
            raise ValueError(f"工作区应包含 config/ 目录：{project.config_dir}")
        return project.config_dir.parent

    @staticmethod
    def _options(payload):
        flags = payload.get("gen_flags") or {}
        arch = flags.get("arch") or "original_pipe"
        pclk_mode = flags.get("pclk-mode") or (
            "pclk_as_phy_input" if arch == "serdes" else "pclk_as_phy_output"
        )
        return GenerationOptions(
            arch=arch,
            pclk_mode=pclk_mode,
            sel_mode=flags.get("sel-mode") or "sync",
            dpr=bool(flags.get("dpr")),
        )

    def load(self, project):
        return workspace_content(self._root(project))

    def validate(self, payload):
        return load_generation_plan_from_payload(payload, self._options(payload))

    def save(self, project, payload):
        self.validate(payload)
        save_workspace_content(self._root(project), payload)

    def generate(self, project, payload, progress=None):
        self.save(project, payload)
        root = self._root(project)
        report = StringIO()
        with redirect_stdout(report):
            result = generate(project.config_dir, root / "rtl", self._options(payload), progress)
        return result, self.output_files(project), report.getvalue()

    def output_files(self, project):
        root = self._root(project)
        return sorted(
            path for folder in (root / "rtl", root / "tb")
            if folder.is_dir() for path in folder.rglob("*") if path.is_file()
        )
