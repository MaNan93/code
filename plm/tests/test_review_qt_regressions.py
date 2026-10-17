"""Interaction and persistence boundaries from the October code review."""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets, sip
from plm.core import plan as plan_module
from plm.core.gen_flags import GenerationOptions
from plm.core.service import generate
from plm.core.workspace import save_workspace_content
from plm.frontend.qt.models import ProjectInfo
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.services.themes import apply_application_theme
from plm.frontend.qt.views.config_page import ConfigPage
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import StyledMenu
from plm.frontend.qt.widgets.project_list import ProjectList
from qt_test_support import dispose_new_widgets, preserve_application_state
from test_core import valid_payload


class ReviewQtRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))

    def test_pinned_row_survives_deferred_deletion_and_remains_selectable(self):
        projects = []
        for name in ("A", "B"):
            config = Path(tempfile.gettempdir()) / name / "config"
            projects.append(ProjectInfo(name, config, config / "controllers.csv",
                                        config / "lane_mapping.csv", config / "pipe_signals.csv"))
        view = ProjectList(projects)
        target = view.project_widgets[1]
        view.select_project("B", emit_signal=False)
        view.apply_pin("B")
        self.app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        self.assertFalse(sip.isdeleted(target))
        self.assertIs(view.itemWidget(view.item(0)), target)
        self.assertEqual(view.select_project("B"), "B")

    def test_cancelled_table_lane_and_project_menus_are_released(self):
        page = ConfigPage()
        page.set_content(valid_payload())
        table = page.controllers_editor.editor
        lane = page.mapping_editor.editor
        config = Path(tempfile.gettempdir()) / "demo/config"
        view = ProjectList([ProjectInfo("demo", config, config / "controllers.csv",
                                        config / "lane_mapping.csv", config / "pipe_signals.csv")])
        with patch.object(StyledMenu, "exec_", return_value=None):
            for _ in range(10):
                table._show_row_context_menu(0, QtCore.QPoint())
                lane._on_row_context_menu(0, QtCore.QPoint())
                view.project_widgets[0].show_more_menu()
        self.app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        self.assertEqual(table.findChildren(StyledMenu), [])
        self.assertEqual(lane.findChildren(StyledMenu), [])
        self.assertEqual(view.findChildren(StyledMenu), [])

    def test_saved_prefix_is_an_undo_boundary(self):
        page = ConfigPage()
        page.set_content(valid_payload())
        field = page.generation_editor.module_prefix
        field.setText("soc")
        page.mark_saved()
        field.setText("soc2")
        page.undo()
        self.assertEqual(field.text(), "soc")
        self.assertFalse(page.dirty)

    def test_edit_while_save_is_pending_keeps_the_saved_snapshot_in_history(self):
        page = ConfigPage()
        page.set_content(valid_payload())
        field = page.generation_editor.module_prefix
        field.setText("soc")
        saved = page.content()
        page.end_edit_group()  # The asynchronous save captures this boundary.
        field.setText("soc2")
        page.mark_saved(saved)
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(field.text(), "soc")
        self.assertFalse(page.dirty)

    def test_unrelated_edits_do_not_rebuild_controller_palette(self):
        page = ConfigPage()
        page.set_content(valid_payload())
        grid = page.mapping_editor.editor
        with patch.object(grid, "_render_palette", wraps=grid._render_palette) as rebuild:
            for value in ("s", "so", "soc"):
                page.generation_editor.module_prefix.setText(value)
            self.assertEqual(rebuild.call_count, 0)
            page.controllers_editor.table.item(0, 1).setText("Renamed")
            self.assertEqual(rebuild.call_count, 1)

    def test_formatter_widgets_are_created_only_when_editing_and_keep_values(self):
        page = SettingsPage(preferences={"verible_path": "not-installed"})
        before = len(self.app.allWidgets())
        page._select_section(1)
        self.assertEqual(page._flag_controls.created, {})
        self.assertLess(len(self.app.allWidgets()) - before, 60)
        page.show()
        page.formatter_group.setCurrentIndex(2)
        row = tuple(page._flag_controls).index("column_limit")
        page.flag_table.setCurrentCell(row, 1)
        page.flag_table.setFocus()
        QtTest.QTest.keyClick(page.flag_table, QtCore.Qt.Key_F2)
        control = page._flag_controls["column_limit"]
        control.setText("87")
        page._select_section(0)
        apply_application_theme("dark")
        page._select_section(1)
        self.assertIs(page._flag_controls["column_limit"], control)
        self.assertEqual(page._formatter_flags()["column_limit"], "87")
        self.assertEqual(set(page._flag_controls.created), {"column_limit"})

    def test_clean_validation_reuses_the_disk_plan_and_keeps_csv_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            workspace = root / "examples/demo"
            save_workspace_content(workspace, valid_payload())
            csv = workspace / "config/controllers.csv"
            csv.write_bytes(csv.read_bytes().replace(b",", b", "))
            project = ProjectService(root).discover()[0]
            service = WorkspaceService()
            with patch("plm.core.verible.find_verible", return_value=None):
                generate(project.config_dir, workspace / "rtl", GenerationOptions(quiet=True), log=lambda _: None)
                payload = service.load(project)
                with patch.object(plan_module, "_generator_fingerprint", wraps=plan_module._generator_fingerprint) as count:
                    plan = service.validate(payload, project=project, use_disk=True)
                    state = service.output_state(project, payload, plan=plan, use_disk=True)
                self.assertEqual(state, "up_to_date")
                self.assertEqual(count.call_count, 1)


class ExamplePreferenceMigrationTests(unittest.TestCase):
    def test_known_repository_example_state_and_paths_migrate_once(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            old = root / "test/demo"
            save_workspace_content(old, valid_payload())
            service = ProjectService(root)
            settings = SettingsStore(QtCore.QSettings(str(root / "settings.ini"), QtCore.QSettings.IniFormat))
            settings.bind_projects(service.discover(), project_root=root)
            state = settings.get_project_state("demo")
            state.is_pinned = state.is_archived = True
            settings.save_project_state(state)
            settings.set_recent_project("demo")
            settings.save_project_paths([old / "config"])
            (root / "examples").mkdir()
            old.rename(root / "examples/demo")
            settings.bind_projects(service.discover(), project_root=root)
            state = settings.get_project_state("demo")
            self.assertTrue(state.is_pinned)
            self.assertTrue(state.is_archived)
            self.assertEqual(settings.recent_path(), str(root / "examples/demo/config"))
            self.assertEqual(settings.project_paths(), [str(root / "examples/demo/config")])
            # Already-written destination preferences win on subsequent binds.
            state.is_pinned = False
            settings.save_project_state(state)
            settings.bind_projects(service.discover(), project_root=root)
            self.assertFalse(settings.get_project_state("demo").is_pinned)

    def test_existing_legacy_and_same_named_external_projects_are_not_merged(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            for folder in ("test/demo", "examples/demo", "outside/demo"):
                save_workspace_content(root / folder, valid_payload())
            service = ProjectService(root)
            service.register(root / "outside/demo")
            settings = SettingsStore(QtCore.QSettings(str(root / "settings.ini"), QtCore.QSettings.IniFormat))
            settings.bind_projects(service.discover(), project_root=root)
            projects = service.discover()
            old = next(p for p in projects if p.config_dir.parent.parent.name == "test")
            state = settings.get_project_state(old.name)
            state.is_archived = True
            settings.save_project_state(state)
            settings.bind_projects(projects, project_root=root)
            for project in projects:
                self.assertEqual(settings.get_project_state(project.name).is_archived, project == old)
