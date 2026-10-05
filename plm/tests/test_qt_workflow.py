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
from qt_test_support import dispose_new_widgets


class QtWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name).resolve()
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
        warning.assert_not_called()
        self.assertTrue(page.dirty)
        self.assertEqual((self.root / "test/demo/config/controllers.csv").read_text(), csv_text)
        page.controllers_editor.table.item(0, 0).setText("0")

        page.generation_editor.generate_btn.click()
        self.assertTrue((self.root / "test/demo/rtl/src/pipe_lane_mapper.sv").is_file())
        self.assertTrue((self.root / "test/demo/tb/tb_pipe_lane_mapper.sv").is_file())
        panel = page.artifacts_panel
        files = [Path(panel.file_selector.itemData(i)) for i in range(panel.file_selector.count())]
        generated = self.root / "test/demo/rtl/src/pipe_lane_mapper.sv"
        panel.file_selector.setCurrentIndex(files.index(generated))
        self.assertEqual(panel.preview.toPlainText(), generated.read_text())
        self.assertIn("endmodule", panel.preview.toPlainText())
        self.assertTrue(panel.preview.isReadOnly())
        self.assertIn("生成完成", window.log_panel.status_label.text())

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
        self.assertIsNone(controller.current_name)
        self.assertIsNone(window.nav_panel.project_list.selected_project_name)
        window.nav_panel.project_list.select_project("demo")
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

    def test_output_state_generation_integrity_and_noop(self):
        controller, window = self._editing_window()
        panel = window.config_page.artifacts_panel
        self.assertEqual(controller.generation_state, "ready")
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertIn(
            "输出已是最新",
            window.config_page.generation_editor.status_label.text(),
        )
        self.assertNotIn("输出已是最新", panel.status.text())
        self.assertIn("行", panel.status.text())
        files = self.workspaces.output_files(controller.current_project)
        stamps = {path: path.stat().st_mtime_ns for path in files}
        controller.generate_current()
        self.assertEqual(stamps, {path: path.stat().st_mtime_ns for path in files})
        self.assertIn("输出已是最新", window.log_panel.status_label.text())
        top = controller.current_project.config_dir.parent / "rtl/src/pipe_lane_mapper.sv"
        original = top.read_bytes()
        top.write_bytes(original + b"// modified output\n")
        controller.refresh_artifacts()
        self.assertEqual(controller.generation_state, "out_of_date")
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertEqual(top.read_bytes(), original)
        manifest = top.parent.parent / "manifest.json"
        manifest.write_text("broken json", encoding="utf-8")
        controller.refresh_artifacts()
        self.assertEqual(controller.generation_state, "out_of_date")
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        top.unlink()
        controller.refresh_artifacts()
        self.assertEqual(controller.generation_state, "out_of_date")
        controller.generate_current()
        self.assertTrue(top.exists())
        self.assertEqual(controller.generation_state, "up_to_date")

    def test_application_activation_marks_modified_output_out_of_date(self):
        controller, window = self._editing_window()
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        top = controller.current_project.config_dir.parent / "rtl/src/pipe_lane_mapper.sv"
        top.write_text(
            top.read_text(encoding="utf-8") + "// externally modified\n",
            encoding="utf-8",
        )

        window.eventFilter(
            self.app, QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
        )
        self.app.processEvents()
        self.assertEqual(controller.generation_state, "out_of_date")

    def test_output_state_edit_undo_save_and_project_switch(self):
        from PyQt5 import QtTest
        controller, window = self._editing_window()
        page = window.config_page
        controller.generate_current()
        page.controllers_editor.table.item(0, 1).setText("changed_controller")
        self.assertEqual(controller.generation_state, "out_of_date")
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "out_of_date")
        page.undo()
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "up_to_date")
        page.redo()
        self.assertTrue(controller.save_current())
        self.assertEqual(controller.generation_state, "out_of_date")
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        page.generation_editor.sel_mode.setCurrentText("comb")
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "out_of_date")
        page.undo()
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "up_to_date")
        original = controller.current_name
        other = next(p.name for p in self.projects.discover() if p.name != original)
        controller.select_project(other)
        self.assertEqual(controller.generation_state, "ready")
        controller.select_project(original)
        self.assertEqual(controller.generation_state, "up_to_date")
        controller.rename_project(original, "renamed_current")
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertTrue(page.artifacts_panel.current_path.is_file())
        self.assertIn("renamed_current", str(page.artifacts_panel.current_path))

    def test_output_state_failed_invalid_and_external_changes(self):
        from PyQt5 import QtTest
        controller, window = self._editing_window()
        page = window.config_page
        def fail(*args, **kwargs):
            self.assertEqual(controller.generation_state, "generating")
            self.assertFalse(page.generation_editor.generate_btn.isEnabled())
            raise ValueError("simulated generation failure")
        with patch("plm.frontend.qt.services.workspaces.generate", side_effect=fail), \
                patch.object(QtWidgets.QMessageBox, "warning"):
            controller.generate_current()
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "failed")
        self.assertIn("simulated", page.generation_editor.status_label.toolTip())
        self.assertTrue(page.generation_editor.generate_btn.isEnabled())
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        page.controllers_editor.table.item(0, 0).setText("invalid")
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "invalid")
        page.undo()
        QtTest.QTest.qWait(200)
        self.assertEqual(controller.generation_state, "up_to_date")
        path = controller.current_project.controllers_csv
        path.write_text(path.read_text().replace("CtrlX16", "external_controller"), encoding="utf-8")
        controller.refresh_artifacts()
        self.assertEqual(controller.generation_state, "external_changed")
        self.assertTrue(controller.reload_current())
        self.assertEqual(controller.generation_state, "out_of_date")

    def test_output_state_recognizes_cli_outputs_from_aligned_csv(self):
        from contextlib import redirect_stdout
        from io import StringIO
        from plm.core.service import generate
        project = self.projects.discover()[0]
        project.controllers_csv.write_text(project.controllers_csv.read_text().replace(",", ", "), encoding="utf-8")
        before = self.workspaces.signature(project)
        payload = self.workspaces.load(project)
        with redirect_stdout(StringIO()):
            generate(project.config_dir, project.config_dir.parent / "rtl", self.workspaces._options(payload))
        controller, window = self._editing_window()
        self.assertEqual(controller.current_project.config_dir, project.config_dir)
        self.assertFalse(window.config_page.dirty)
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertEqual(self.workspaces.signature(project), before)

    def test_output_state_without_project_disables_generation(self):
        controller, window = self._editing_window()
        for project in list(self.projects.discover()):
            controller.archive_project(project.name)
        self.assertIsNone(controller.current_project)
        self.assertEqual(controller.generation_state, "no_project")
        self.assertFalse(window.config_page.generation_editor.generate_btn.isEnabled())
        self.assertEqual(window.config_page.artifacts_panel.status.text(), "请选择项目")

    def test_lane_grid_tracks_controllers_and_paints_ranges(self):
        controller, window = self._editing_window()
        page = window.config_page
        grid = page.mapping_editor.editor
        table = page.mapping_editor.table
        page.tabs.setCurrentIndex(1)
        self.assertEqual(len(grid.controllers), page.controllers_editor.table.rowCount())
        self.assertGreaterEqual(len(grid.controllers), 2)
        target_id = str(grid.controllers[1]["ctrl_id"])
        before = [table.item(0, column).text() for column in range(1, 4)]

        grid._set_active_controller(target_id)
        grid._begin_paint(0, 0)
        grid._continue_paint(0, 2)
        grid._end_paint()
        self.assertEqual(
            [table.item(0, column).text() for column in range(1, 4)],
            [f"{target_id}-0", f"{target_id}-1", f"{target_id}-2"],
        )
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(
            [table.item(0, column).text() for column in range(1, 4)], before
        )

    def test_lane_grid_manual_edit_is_preserved_and_undoable(self):
        controller, window = self._editing_window()
        page = window.config_page
        table = page.mapping_editor.table
        page.tabs.setCurrentIndex(1)
        original = table.item(0, 1).text()
        table.item(0, 1).setText("1-3")
        self.app.processEvents()
        self.assertEqual(page.mapping_editor.rows()[0]["lane0"], "1-3")
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(table.item(0, 1).text(), original)

    def test_table_editors_preserve_invalid_values_for_core_validation(self):
        controller, window = self._editing_window()
        page = window.config_page
        table = page.controllers_editor.table
        table.item(0, 2).setText("abc")
        controller.validate_current()
        # Format-level errors do not necessarily have an exact cell coordinate,
        # but the editor must keep the user's value and core must reject it.
        self.assertEqual(table.item(0, 2).text(), "abc")
        self.assertEqual(controller.generation_state, "invalid")

        rows = page.signals_editor.rows()
        rows[0]["signal_type"] = "unknown"
        page.signals_editor.set_rows(rows)
        combo = page.signals_editor.table.cellWidget(0, 1)
        self.assertIsInstance(combo, QtWidgets.QComboBox)
        self.assertEqual(combo.currentText(), "unknown")
        self.assertEqual(
            [combo.itemText(i) for i in range(combo.count())],
            ["perlane", "shared", "unknown"],
        )

    def test_live_errors_and_focus_use_core_coordinates_without_dirtying_data(self):
        controller, window = self._editing_window()
        page = window.config_page
        self.assertFalse(page.dirty)
        controller.validate_current()
        self.assertFalse(page.dirty)
        page.mapping_editor.table.item(0, 1).setText("99-0")
        controller.validate_current()
        item = page.mapping_editor.table.item(0, 1)
        self.assertIn("undefined", item.toolTip())
        self.assertIn((0, 1), page.mapping_editor.editor._cell_errors)
        with patch.object(QtWidgets.QMessageBox, "warning"):
            self.assertFalse(controller.save_current())
        self.assertEqual(page.tabs.currentIndex(), 1)
        self.assertEqual(page.mapping_editor.table.currentColumn(), 1)
        page.undo()
        controller.validate_current()
        self.assertNotIn((0, 1), page.mapping_editor.editor._cell_errors)
        self.assertNotIn("undefined", page.mapping_editor.table.item(0, 1).toolTip().lower())
        self.assertFalse(page.dirty)

    def test_live_validation_timer_and_duplicate_ids_mark_both_rows(self):
        from PyQt5 import QtTest
        controller, window = self._editing_window()
        page = window.config_page
        page.controllers_editor.table.item(1, 0).setText("0")
        QtTest.QTest.qWait(200)
        for row in (0, 1):
            self.assertIn("Duplicate", page.controllers_editor.table.item(row, 0).toolTip())
        page.undo()
        QtTest.QTest.qWait(200)
        self.assertFalse(page.controllers_editor.table.item(0, 0).toolTip())
        self.assertFalse(page.controllers_editor.table.item(1, 0).toolTip())


    def test_new_project_uses_standard_projects_directory(self):
        controller, window = self._editing_window()
        captured = {}

        class FakeDialog:
            def __init__(self, location, parent=None):
                captured["location"] = Path(location)

            def exec_(self):
                return QtWidgets.QDialog.Rejected

        with patch("plm.frontend.qt.controllers.app_controller.NewProjectDialog", FakeDialog):
            controller.new_project()
        self.assertEqual(captured["location"], Path.home() / "plm-projects")


if __name__ == "__main__":
    unittest.main()
