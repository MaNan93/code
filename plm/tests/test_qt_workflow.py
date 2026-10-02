"""Integration checks for project actions and real workspace generation."""

import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.widgets.common import PROJECT_ROOT


class QtWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("demo", "other"):
            shutil.copytree(
                PROJECT_ROOT / "test/bifurcate/config",
                self.root / "test" / name / "config",
            )
        qsettings = QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat)
        self.store = SettingsStore(qsettings)
        self.projects = ProjectService(self.root)
        self.workspaces = WorkspaceService()

    def test_project_rename_archive_pin_delete_are_persistent_and_safe(self):
        self.store.set_recent_project("demo")
        controller = AppController(self.projects, self.store, self.workspaces)
        nav = controller.create_navigation()
        self.assertEqual(nav.current_project_name, "demo")

        renamed_dir = self.projects.rename("demo", "renamed")
        self.assertEqual(renamed_dir, self.root / "test/renamed/config")
        self.assertFalse((self.root / "test/demo").exists())
        with self.assertRaises(FileExistsError):
            self.projects.rename("renamed", "other")
        with self.assertRaises(ValueError):
            self.projects.delete("renamed")
        self.assertTrue(renamed_dir.exists())

        state = self.store.get_project_state("renamed")
        state.is_pinned = True
        self.store.save_project_state(state)
        state = self.store.get_project_state("other")
        state.is_archived = True
        self.store.save_project_state(state)
        refreshed = controller.create_navigation()
        self.assertEqual([w.project_name for w in refreshed.project_list.project_widgets], ["renamed"])

        payload = self.workspaces.load(self.projects._find("renamed"))
        self.workspaces.save(self.projects._find("renamed"), payload)
        self.assertTrue((self.root / "test/renamed/.plm-workspace").is_file())
        self.projects.delete("renamed")
        self.assertFalse((self.root / "test/renamed").exists())
        nav.close()
        refreshed.close()

    def test_edit_save_validate_generate_and_show_real_artifacts(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.show()
        self.app.processEvents()
        self.addCleanup(window.close)
        self.assertEqual(controller.current_name, "demo")
        page = window.config_page
        self.assertGreater(page.controllers_editor.table.rowCount(), 0)
        self.assertGreater(page.signals_editor.table.rowCount(), 0)

        item = page.controllers_editor.table.item(0, 1)
        item.setText("DemoCtrl")
        self.assertTrue(page.dirty)
        window.nav_panel.save_btn.click()
        self.assertFalse(page.dirty)
        csv_text = (self.root / "test/demo/config/controllers.csv").read_text()
        self.assertIn("DemoCtrl", csv_text)

        page.controllers_editor.table.item(0, 0).setText("invalid-id")
        self.assertTrue(page.dirty)
        with patch.object(QtWidgets.QMessageBox, "warning") as warning:
            window.nav_panel.save_btn.click()
        warning.assert_called_once()
        self.assertTrue(page.dirty)
        self.assertEqual((self.root / "test/demo/config/controllers.csv").read_text(), csv_text)
        page.controllers_editor.table.item(0, 0).setText("0")

        page.generation_editor.generate_btn.click()
        self.assertTrue((self.root / "test/demo/rtl/src/pipe_lane_mapper.sv").is_file())
        self.assertTrue((self.root / "test/demo/tb/tb_pipe_lane_mapper.sv").is_file())
        from plm.frontend.qt.views.artifacts_panel import FileDiffCard
        cards = page.artifacts_panel.findChildren(FileDiffCard)
        self.assertTrue(any(card.file_path.name == "pipe_lane_mapper.sv" for card in cards))
        self.assertIn("生成完成", window.log_panel.output.toPlainText())

    def test_project_actions_flow_through_controller_and_keep_selection(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.show()
        self.app.processEvents()
        self.addCleanup(window.close)
        nav = window.nav_panel

        other = next(w for w in nav.project_list.project_widgets if w.project_name == "other")
        nav.project_list.pin_project(other)
        self.assertTrue(self.store.get_project_state("other").is_pinned)
        self.assertEqual(nav.project_list.project_widgets[0].project_name, "other")
        self.assertEqual(controller.current_name, "demo")
        self.assertEqual(nav.project_list.itemWidget(nav.project_list.currentItem()).project_name, "demo")

        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Yes):
            nav.project_list.archive_project(other)
        self.assertTrue(self.store.get_project_state("other").is_archived)
        self.assertEqual(nav.current_project_name, "demo")
        self.assertEqual(nav.project_list.count(), 1)

        demo = nav.project_list.project_widgets[0]
        with patch.object(QtWidgets.QInputDialog, "getText", return_value=("renamed", True)):
            nav.project_list.rename_project(demo)
        self.assertEqual(nav.current_project_name, "renamed")
        self.assertEqual(self.store.recent_project(), "renamed")
        self.assertEqual(window.config_page.header.title_label.text(), "renamed")
        self.assertTrue((self.root / "test/renamed/config/controllers.csv").is_file())

        self.assertTrue(controller.save_current())
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Yes):
            nav.project_list.delete_project(demo)
        self.assertEqual(nav.project_list.count(), 0)
        self.assertEqual(window.config_page.header.title_label.text(), "无项目")
        self.assertFalse((self.root / "test/renamed").exists())

    def test_switching_projects_preserves_or_discards_unsaved_edits(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.show()
        self.app.processEvents()
        self.addCleanup(window.close)
        item = window.config_page.controllers_editor.table.item(0, 1)
        original = item.text()
        item.setText("unsaved")
        other = next(w for w in window.nav_panel.project_list.project_widgets
                     if w.project_name == "other")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Cancel):
            other.header.click()
        self.assertEqual(controller.current_name, "demo")
        self.assertEqual(window.nav_panel.current_project_name, "demo")
        self.assertEqual(item.text(), "unsaved")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard):
            other.header.click()
        self.assertEqual(controller.current_name, "other")
        self.assertEqual(window.config_page.header.title_label.text(), "other")
        self.assertIn(original, (self.root / "test/demo/config/controllers.csv").read_text())

    def test_archiving_current_project_selects_remaining_and_empty_restart(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        self.addCleanup(window.close)
        controller.archive_project("demo")
        self.assertEqual(controller.current_name, "other")
        self.assertEqual(window.nav_panel.current_project_name, "other")
        self.assertEqual(self.store.recent_project(), "other")
        controller.archive_project("other")
        self.assertIsNone(controller.current_project)
        self.assertIsNone(window.nav_panel.current_project_name)
        self.assertEqual(window.config_page.header.title_label.text(), "无项目")

        restarted = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=restarted):
            empty_window = MainWindow()
        self.addCleanup(empty_window.close)
        self.assertEqual(empty_window.nav_panel.project_list.count(), 0)
        self.assertEqual(empty_window.config_page.header.title_label.text(), "无项目")
        self.assertFalse(restarted.save_current())

    def test_new_project_uses_custom_location_and_restores_after_restart(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        self.addCleanup(window.close)
        location = self.root / "custom"
        with patch("plm.frontend.qt.controllers.app_controller.NewProjectDialog") as dialog:
            dialog.return_value.exec_.return_value = QtWidgets.QDialog.Accepted
            dialog.return_value.values.return_value = ("newdemo", str(location))
            controller.new_project()
        config = location / "newdemo/config"
        self.assertEqual(controller.current_project.config_dir, config)
        self.assertTrue((config.parent / ".plm-workspace").is_file())
        self.assertEqual(self.store.recent_path(), str(config))
        self.assertTrue(controller.save_current())
        controller.generate_current()
        self.assertTrue((config.parent / "rtl/src/pipe_lane_mapper.sv").is_file())

        restarted = AppController(ProjectService(self.root), self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=restarted):
            restored = MainWindow()
        self.addCleanup(restored.close)
        self.assertEqual(restarted.current_project.config_dir, config)

    def test_open_duplicate_names_uses_paths_and_cancel_keeps_current_edits(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        self.addCleanup(window.close)
        external = self.root / "outside/demo"
        shutil.copytree(self.root / "test/demo/config", external / "config")
        window.config_page.controllers_editor.table.item(0, 1).setText("unsaved")
        with patch.object(QtWidgets.QFileDialog, "getExistingDirectory", return_value=str(external)), \
                patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Cancel):
            controller.open_project()
        self.assertEqual(controller.current_name, "demo")
        self.assertTrue(window.config_page.dirty)
        self.assertNotIn(external / "config", self.projects.external_dirs)

        with patch.object(QtWidgets.QFileDialog, "getExistingDirectory", return_value=str(external)), \
                patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard):
            controller.open_project()
        self.assertEqual(controller.current_project.config_dir, external / "config")
        duplicates = [p for p in self.projects.discover() if p.name.startswith("demo [")]
        self.assertEqual(len(duplicates), 2)
        self.assertEqual(len({p.name for p in duplicates}), 2)
        state = self.store.get_project_state(controller.current_name)
        state.is_pinned = True
        self.store.save_project_state(state)
        other = next(p for p in duplicates if p.config_dir != external / "config")
        self.assertFalse(self.store.get_project_state(other.name).is_pinned)

        restarted = AppController(ProjectService(self.root), self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=restarted):
            restored = MainWindow()
        self.addCleanup(restored.close)
        self.assertEqual(restarted.current_project.config_dir, external / "config")

    def test_open_invalid_and_create_existing_do_not_change_current_project(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        self.addCleanup(window.close)
        before = controller.current_project
        with patch.object(QtWidgets.QFileDialog, "getExistingDirectory", return_value=str(self.root)), \
                patch.object(QtWidgets.QMessageBox, "warning") as warning:
            controller.open_project()
        warning.assert_called_once()
        self.assertEqual(controller.current_project, before)
        original = before.controllers_csv.read_bytes()
        with patch("plm.frontend.qt.controllers.app_controller.NewProjectDialog") as dialog, \
                patch.object(QtWidgets.QMessageBox, "warning") as warning:
            dialog.return_value.exec_.return_value = QtWidgets.QDialog.Accepted
            dialog.return_value.values.return_value = ("demo", str(self.root / "test"))
            controller.new_project()
        warning.assert_called_once()
        self.assertEqual(controller.current_project, before)
        self.assertEqual(before.controllers_csv.read_bytes(), original)

    def test_duplicate_rename_and_delete_keep_other_project_usable(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        self.addCleanup(window.close)
        external = self.root / "outside/demo"
        self.projects.create(external.parent, external.name)
        controller._activate_path(external / "config")
        controller.rename_project(controller.current_name, "renamed")
        self.assertEqual(controller.current_name, "renamed")
        self.assertIn("demo", [w.project_name for w in window.nav_panel.project_list.project_widgets])
        self.assertEqual(controller.current_project.config_dir, external.parent / "renamed/config")
        controller.delete_project("renamed")
        self.assertEqual(controller.current_name, "demo")
        self.assertFalse((external.parent / "renamed").exists())
        self.assertTrue(controller.save_current())
        self.assertEqual(self.store.project_paths(), [])

    def test_archived_external_project_can_be_reopened_and_restored(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        self.addCleanup(window.close)
        config = self.projects.create(self.root / "external", "custom")
        controller._activate_path(config)
        controller.archive_project("custom")
        self.assertTrue(self.store.get_project_state(str(config)).is_archived)
        with patch.object(QtWidgets.QFileDialog, "getExistingDirectory", return_value=str(config)):
            controller.open_project()
        self.assertFalse(self.store.get_project_state("custom").is_archived)
        self.assertEqual(controller.current_project.config_dir, config)

    def _editing_window(self):
        controller = AppController(self.projects, self.store, self.workspaces)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.show()
        self.app.processEvents()
        self.addCleanup(lambda: (window.config_page.mark_saved(), window.close()))
        return controller, window

    def test_close_cancel_save_failure_save_and_discard(self):
        controller, window = self._editing_window()
        table = window.config_page.controllers_editor.table
        table.item(0, 1).setText("close_edit")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Cancel):
            self.assertFalse(window.close())
        self.assertTrue(window.isVisible())
        self.assertTrue(window.config_page.dirty)
        table.item(0, 0).setText("invalid")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Save), \
                patch.object(QtWidgets.QMessageBox, "warning"):
            self.assertFalse(window.close())
        table.item(0, 0).setText("0")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Save):
            self.assertTrue(window.close())
        self.assertIn("close_edit", controller.current_project.controllers_csv.read_text())
        window.show()
        table.item(0, 1).setText("discard_edit")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard):
            self.assertTrue(window.close())
        self.assertNotIn("discard_edit", controller.current_project.controllers_csv.read_text())

    def test_external_modification_and_deletion_block_save_and_generate(self):
        controller, window = self._editing_window()
        page = window.config_page
        page.controllers_editor.table.item(0, 1).setText("local_edit")
        path = controller.current_project.controllers_csv
        original = path.read_text()
        path.write_text(original.replace("CtrlX16", "external_edit"))
        external = path.read_bytes()
        with patch.object(QtWidgets.QMessageBox, "warning") as warning:
            self.assertFalse(controller.save_current())
            controller.generate_current()
        self.assertEqual(warning.call_count, 2)
        self.assertEqual(path.read_bytes(), external)
        self.assertTrue(page.dirty)
        self.assertFalse((controller.current_project.config_dir.parent / "rtl").exists())
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard):
            self.assertTrue(controller.reload_current())
        self.assertEqual(page.controllers_editor.table.item(0, 1).text(), "external_edit")
        self.assertTrue(controller.save_current())
        flags = controller.current_project.config_dir / "gen_flags.txt"
        flags.unlink()
        with patch.object(QtWidgets.QMessageBox, "warning"):
            self.assertFalse(controller.save_current())
        self.assertFalse(flags.exists())

    def test_reload_cancel_and_malformed_file_keep_editor_and_history(self):
        controller, window = self._editing_window()
        page = window.config_page
        page.controllers_editor.table.item(0, 1).setText("local_edit")
        before = page.content()
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Cancel):
            self.assertFalse(controller.reload_current())
        self.assertEqual(page.content(), before)
        controller.current_project.controllers_csv.write_text("broken\nheader\n")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard), \
                patch.object(QtWidgets.QMessageBox, "warning"):
            self.assertFalse(controller.reload_current())
        self.assertEqual(page.content(), before)
        self.assertTrue(page.dirty)
        self.assertTrue(page.can_undo())

    def test_undo_redo_rows_lane_count_flags_and_saved_baseline(self):
        controller, window = self._editing_window()
        page = window.config_page
        original = page.content()
        page.controllers_editor.table.item(0, 1).setText("first_edit")
        self.assertTrue(controller.save_current())
        saved = page.content()
        page.mapping_editor.lane_count.setValue(8)
        page.signals_editor.add_row()
        page.generation_editor.sel_mode.setCurrentText("comb")
        last = page.content()
        for _ in range(3):
            window.undo_action.trigger()
        self.assertEqual(page.content(), saved)
        self.assertFalse(page.dirty)
        window.undo_action.trigger()
        self.assertEqual(page.content(), original)
        self.assertTrue(page.dirty)
        for _ in range(4):
            window.redo_action.trigger()
        self.assertEqual(page.content(), last)
        page.undo()
        page.controllers_editor.table.item(0, 1).setText("new_branch")
        self.assertFalse(page.can_redo())
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard):
            self.assertTrue(controller.reload_current())
        self.assertFalse(page.can_undo())
        self.assertFalse(page.can_redo())
        self.assertFalse(page.dirty)

    def test_edit_in_progress_is_committed_before_close_and_save(self):
        from PyQt5 import QtTest
        controller, window = self._editing_window()
        table = window.config_page.controllers_editor.table
        table.setCurrentCell(0, 1)
        table.editItem(table.item(0, 1))
        self.app.processEvents()
        editor = table.findChild(QtWidgets.QLineEdit)
        self.assertIsNotNone(editor)
        editor.selectAll()
        QtTest.QTest.keyClicks(editor, "in_progress")
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Cancel) as question:
            self.assertFalse(window.close())
        question.assert_called_once()
        self.assertEqual(table.item(0, 1).text(), "in_progress")
        self.assertTrue(controller.save_current())
        self.assertIn("in_progress", controller.current_project.controllers_csv.read_text())

    def test_generation_failure_after_save_keeps_saved_baseline(self):
        controller, window = self._editing_window()
        window.config_page.controllers_editor.table.item(0, 1).setText("saved_before_failure")
        with patch("plm.frontend.qt.services.workspaces.generate", side_effect=ValueError("failed")), \
                patch.object(QtWidgets.QMessageBox, "warning"):
            controller.generate_current()
        self.assertFalse(window.config_page.dirty)
        self.assertTrue(controller.save_current())


if __name__ == "__main__":
    unittest.main()
