"""Fast functional checks for buttons and menus; no animation/layout assertions."""

import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import wait_for_idle
from PyQt5 import QtCore, QtTest, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import PROJECT_ROOT


class QtControlLogicTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        shutil.copytree(
            PROJECT_ROOT / "test/bifurcate/config",
            self.root / "test/demo/config",
        )
        self.store = SettingsStore(
            QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat)
        )
        controller = AppController(
            ProjectService(self.root), self.store, WorkspaceService()
        )
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            self.window = MainWindow()
            wait_for_idle(self.app)
        self.controller = controller
        self.window.show()
        wait_for_idle(self.app)
        self.addCleanup(self._close_window)

    def _close_window(self):
        self.window.config_page.mark_saved()
        self.window._close_secondary_page()
        self.window.close()
        self.window.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        wait_for_idle(self.app)

    @staticmethod
    def _menu_class_selecting(label):
        base_menu = QtWidgets.QMenu

        class SelectingMenu(base_menu):
            def exec_(self, _pos):
                return next(action for action in self.actions() if action.text() == label)

        return SelectingMenu

    def test_header_log_and_artifacts_buttons_toggle_panels(self):
        page = self.window.config_page
        self.assertFalse(page.artifacts_panel.isVisible())
        shown = QtTest.QSignalSpy(page._artifacts_animation.finished)
        page.header.artifacts_btn.click()
        wait_for_idle(self.app)
        self.assertTrue(page.artifacts_panel.isVisible())
        self.assertTrue(shown.wait(1000))
        hidden = QtTest.QSignalSpy(page._artifacts_animation.finished)
        page.header.artifacts_btn.click()
        wait_for_idle(self.app)
        self.assertTrue(hidden.wait(1000))
        self.assertFalse(page.artifacts_panel.isVisible())

        self.assertGreater(self.window.content_splitter.sizes()[1], 0)
        page.header.log_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(self.window.content_splitter.sizes()[1], 0)
        page.header.log_btn.click()
        wait_for_idle(self.app)
        self.assertGreater(self.window.content_splitter.sizes()[1], 0)

    def test_log_clear_and_close_buttons_execute_actions(self):
        panel = self.window.log_panel
        panel.append_log("ordinary log line")
        panel.append_log("生成完成：3 个文件")
        self.assertIn("ordinary log line", panel.output.toPlainText())
        self.assertEqual(panel.status_label.text(), "生成完成：3 个文件")

        panel.clear_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(panel.output.toPlainText(), "")
        self.assertEqual(panel.status_label.text(), "")
        self.assertFalse(panel.status_bar.isVisible())

        self.assertGreater(self.window.content_splitter.sizes()[1], 0)
        panel.close_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(self.window.content_splitter.sizes()[1], 0)

    def test_settings_save_and_auto_detect_are_wired(self):
        self.window.nav_panel.settings_btn.click()
        wait_for_idle(self.app)
        wait_for_idle(self.app)
        page = self.window.view_stack.currentWidget()
        self.assertIsInstance(page, SettingsPage)

        page.editor_path_edit.setText("custom-editor")
        page.save_settings_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(
            self.store.preferences()["editor_path"], "custom-editor"
        )

        detect = next(
            button for button in page.findChildren(QtWidgets.QPushButton)
            if button.text() == "自动检测"
        )
        with patch(
            "plm.frontend.qt.views.settings_page.find_verible",
            return_value="/tools/verible-verilog-format",
        ):
            detect.click()
            wait_for_idle(self.app)
        self.assertEqual(
            page.verible_path_edit.text(), "/tools/verible-verilog-format"
        )

    def test_new_project_button_opens_creation_dialog_directly(self):
        with patch("plm.frontend.qt.controllers.project_navigation.NewProjectDialog") as dialog:
            dialog.return_value.exec_.return_value = QtWidgets.QDialog.Rejected
            self.window.nav_panel.new_chat_btn.click()
        dialog.assert_called_once()
        self.assertFalse(hasattr(self.controller, "project_menu"))
        self.assertFalse(hasattr(self.controller, "reload_current"))

    def test_open_project_button_opens_selected_workspace(self):
        external = self.root / "external/opened"
        shutil.copytree(PROJECT_ROOT / "test/bifurcate/config", external / "config")
        with patch.object(
            QtWidgets.QFileDialog, "getExistingDirectory", return_value=str(external)
        ):
            self.window.nav_panel.open_project_btn.click()
            wait_for_idle(self.app)
        self.assertEqual(self.controller.current_project.config_dir, external / "config")
        self.assertEqual(self.window.config_page.header.title_label.text(), "opened")
        self.assertIn(external / "config", self.controller.projects.external_dirs)

    def test_project_context_menu_has_no_redundant_clear_action(self):
        widget = self.window.nav_panel.project_list.project_widgets[0]
        pin = QtTest.QSignalSpy(widget.pinRequested)

        menu = widget.build_more_menu()
        actions = [action for action in menu.actions() if not action.isSeparator()]
        self.assertEqual(
            [action.text() for action in actions],
            ["置顶", "重命名", "在资源管理器中打开", "归档", "删除"],
        )
        next(action for action in actions if action.text() == "置顶").trigger()
        wait_for_idle(self.app)
        self.assertEqual(len(pin), 1)
        self.assertIs(pin[0][0], widget)
        menu.close()
        menu.deleteLater()

    def test_header_inline_rename_updates_real_project(self):
        header = self.window.config_page.header
        header.enter_edit_mode()
        header.title_edit.setText("renamed")
        header.save_title()
        wait_for_idle(self.app)
        self.assertEqual(self.controller.current_name, "renamed")
        self.assertEqual(
            self.controller.current_project.config_dir,
            self.root / "test/renamed/config",
        )
        self.assertTrue((self.root / "test/renamed/config/controllers.csv").is_file())
        self.assertFalse((self.root / "test/demo").exists())

    def test_table_context_menu_inserts_and_deletes_rows(self):
        page = self.window.config_page
        editor = page.controllers_editor.editor
        before = editor.table.rowCount()
        with patch(
            "plm.frontend.qt.widgets.tables.StyledMenu",
            self._menu_class_selecting("在下方插入行"),
        ):
            editor._show_row_context_menu(0, QtCore.QPoint())
        self.assertEqual(editor.table.rowCount(), before + 1)
        self.assertTrue(page.dirty)

        with patch(
            "plm.frontend.qt.widgets.tables.StyledMenu",
            self._menu_class_selecting("删除当前行"),
        ):
            editor._show_row_context_menu(1, QtCore.QPoint())
        self.assertEqual(editor.table.rowCount(), before)

    def test_lane_grid_context_menu_inserts_and_deletes_modes(self):
        page = self.window.config_page
        grid = page.mapping_editor.editor
        before = grid.table.rowCount()
        with patch(
            "plm.frontend.qt.widgets.lanegrid.StyledMenu",
            self._menu_class_selecting("Insert row below"),
        ):
            grid._on_row_context_menu(0, QtCore.QPoint())
        self.assertEqual(grid.table.rowCount(), before + 1)
        self.assertTrue(page.dirty)

        with patch(
            "plm.frontend.qt.widgets.lanegrid.StyledMenu",
            self._menu_class_selecting("Delete current row"),
        ):
            grid._on_row_context_menu(1, QtCore.QPoint())
        self.assertEqual(grid.table.rowCount(), before)

    def test_controller_and_lane_rows_reorder_and_undo(self):
        page = self.window.config_page
        controller_editor = page.controllers_editor.editor
        controller_before = page.controllers_editor.rows()
        self.assertGreaterEqual(len(controller_before), 2)
        controller_editor._on_row_drop(0, 1)
        controller_after = page.controllers_editor.rows()
        self.assertEqual(controller_after[0], controller_before[1])
        self.assertEqual(controller_after[1], controller_before[0])
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(page.controllers_editor.rows(), controller_before)

        grid = page.mapping_editor.editor
        mapping_before = page.mapping_editor.rows()
        self.assertGreaterEqual(len(mapping_before), 2)
        grid._on_row_drop(0, 1)
        mapping_after = page.mapping_editor.rows()
        self.assertEqual(mapping_after[0], mapping_before[1])
        self.assertEqual(mapping_after[1], mapping_before[0])
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(page.mapping_editor.rows(), mapping_before)


if __name__ == "__main__":
    unittest.main()
