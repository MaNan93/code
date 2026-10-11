import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from PyQt5 import QtCore

from plm.frontend.qt.models import ProjectInfo, ProjectState
from plm.frontend.qt.services import ProjectService, SettingsStore


class ProjectServiceTests(unittest.TestCase):
    def test_discover_returns_project_info_with_explicit_csv_paths(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory).resolve()
            config_dir = root / "test" / "demo" / "config"
            config_dir.mkdir(parents=True)
            for filename in (
                "controllers.csv",
                "lane_mapping.csv",
                "pipe_signals.csv",
            ):
                (config_dir / filename).write_text("", encoding="utf-8")

            projects = ProjectService(root).discover()

            self.assertEqual(len(projects), 1)
            project = projects[0]
            self.assertIsInstance(project, ProjectInfo)
            self.assertEqual(project.name, "demo")
            self.assertEqual(project.config_dir, config_dir.resolve())
            self.assertEqual(project.controllers_csv, config_dir / "controllers.csv")
            self.assertEqual(project.lane_mapping_csv, config_dir / "lane_mapping.csv")
            self.assertEqual(project.pipe_signals_csv, config_dir / "pipe_signals.csv")


class EditorCommandTests(unittest.TestCase):
    def test_editor_setting_may_carry_arguments_or_be_a_path_with_spaces(self):
        import sys
        from plm.frontend.qt.views.artifact_interactions import editor_command

        self.assertEqual(
            editor_command(f'"{sys.executable}" -g --flag'), [sys.executable, "-g", "--flag"]
        )
        with tempfile.TemporaryDirectory(prefix="editor with spaces ") as directory:
            tool = Path(directory) / "my editor"
            tool.write_text("", encoding="utf-8")
            self.assertEqual(editor_command(str(tool)), [str(tool)])
        with self.assertRaisesRegex(OSError, "未找到"):
            editor_command("definitely-not-an-editor-xyz --flag")
        with self.assertRaises(OSError):
            editor_command("")


class ProjectDiscoveryTests(unittest.TestCase):
    def test_only_openable_config_directories_are_listed(self):
        from plm.core.workspace import scaffold_default_content

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            scaffold_default_content(root / "test/good")
            loose = root / "test/loose"
            loose.mkdir()
            for path in (root / "test/good/config").glob("*.csv"):
                (loose / path.name).write_bytes(path.read_bytes())
            self.assertEqual([p.name for p in ProjectService(root).discover()], ["good"])


class SettingsStoreProjectStateTests(unittest.TestCase):
    def test_project_states_round_trip_independently_from_static_info(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            settings = QtCore.QSettings(
                str(Path(temporary_directory).resolve() / "settings.ini"),
                QtCore.QSettings.IniFormat,
            )
            store = SettingsStore(settings)
            last_opened = datetime(2026, 10, 1, 9, 30, tzinfo=timezone.utc)
            expected = ProjectState(
                name="demo/project",
                is_archived=True,
                is_pinned=True,
                last_opened=last_opened,
            )

            store.save_project_state(expected)

            self.assertEqual(store.get_project_state(expected.name), expected)
            self.assertEqual(store.get_project_states(), {expected.name: expected})

    def test_selecting_recent_project_updates_last_opened(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            settings = QtCore.QSettings(
                str(Path(temporary_directory).resolve() / "settings.ini"),
                QtCore.QSettings.IniFormat,
            )
            store = SettingsStore(settings)

            store.set_recent_project("demo")

            self.assertEqual(store.recent_project(), "demo")
            self.assertIsNotNone(store.get_project_state("demo").last_opened)


if __name__ == "__main__":
    unittest.main()
