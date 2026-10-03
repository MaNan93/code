"""Fast functional checks for buttons and menus; no animation/layout assertions."""

import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.models.preferences import DEFAULT_FONT_SIZE
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
        self.controller = controller
        self.window.show()
        self.app.processEvents()
        self.addCleanup(self._close_window)

    def _close_window(self):
        self.window.config_page.mark_saved()
        self.window._close_placeholder()
        self.window.close()
        self.window.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        self.app.processEvents()

    def _project_menu_actions(self):
        self.window.nav_panel.new_chat_btn.click()
        self.app.processEvents()
        return [
            action for action in self.controller.project_menu.actions()
            if not action.isSeparator()
        ]

    @staticmethod
    def _choose_menu_action(label):
        def choose(menu, _pos):
            return next(action for action in menu.actions() if action.text() == label)
        return choose

    def test_header_log_and_artifacts_buttons_toggle_panels(self):
        page = self.window.config_page
        self.assertTrue(page.artifacts_panel.isVisible())
        page.header.artifacts_btn.click()
        self.assertFalse(page.artifacts_panel.isVisible())
        page.header.artifacts_btn.click()
        self.assertTrue(page.artifacts_panel.isVisible())

        self.assertGreater(self.window.content_splitter.sizes()[1], 0)
        page.header.log_btn.click()
        self.assertEqual(self.window.content_splitter.sizes()[1], 0)
        page.header.log_btn.click()
        self.assertGreater(self.window.content_splitter.sizes()[1], 0)

    def test_log_clear_and_close_buttons_execute_actions(self):
        panel = self.window.log_panel
        panel.append_log("ordinary log line")
        panel.append_log("生成完成：3 个文件")
        self.assertIn("ordinary log line", panel.output.toPlainText())
        self.assertEqual(panel.status_label.text(), "生成完成：3 个文件")

        panel.clear_btn.click()
        self.assertEqual(panel.output.toPlainText(), "")
        self.assertEqual(panel.status_label.text(), "")
        self.assertFalse(panel.status_bar.isVisible())

        self.assertGreater(self.window.content_splitter.sizes()[1], 0)
        panel.close_btn.click()
        self.assertEqual(self.window.content_splitter.sizes()[1], 0)

    def test_settings_save_reset_and_auto_detect_are_wired(self):
        self.window.nav_panel.settings_btn.click()
        self.app.processEvents()
        page = self.window.placeholder_overlay
        self.assertIsInstance(page, SettingsPage)

        page.font_size_spin.setValue(DEFAULT_FONT_SIZE + 1)
        page.save_settings_btn.click()
        self.assertEqual(
            self.store.preferences()["font_size"], DEFAULT_FONT_SIZE + 1
        )

        reset = next(
            button for button in page.findChildren(QtWidgets.QPushButton)
            if button.text() == "恢复默认"
        )
        reset.click()
        self.assertEqual(page.font_size_spin.value(), DEFAULT_FONT_SIZE)
        self.assertEqual(self.store.preferences()["font_size"], DEFAULT_FONT_SIZE)

        detect = next(
            button for button in page.findChildren(QtWidgets.QPushButton)
            if button.text() == "自动检测"
        )
        with patch(
            "plm.frontend.qt.views.settings_page.find_verible",
            return_value="/tools/verible-verilog-format",
        ):
            detect.click()
        self.assertEqual(
            page.verible_path_edit.text(), "/tools/verible-verilog-format"
        )

    def test_project_menu_button_exposes_new_open_and_reload(self):
        actions = self._project_menu_actions()
        self.assertEqual(
            [a.text() for a in actions],
            ["新建项目", "打开项目…", "重新加载当前项目"],
        )
        self.assertTrue(actions[-1].isEnabled())
        self.controller.hide_project_menu()

    def test_project_menu_open_action_opens_selected_workspace(self):
        external = self.root / "external/opened"
        shutil.copytree(PROJECT_ROOT / "test/bifurcate/config", external / "config")
        actions = self._project_menu_actions()
        open_action = next(action for action in actions if action.text() == "打开项目…")
        with patch.object(
            QtWidgets.QFileDialog, "getExistingDirectory", return_value=str(external)
        ):
            open_action.trigger()
        self.assertEqual(self.controller.current_project.config_dir, external / "config")
        self.assertEqual(self.window.config_page.header.title_label.text(), "opened")
        self.assertIn(external / "config", self.controller.projects.external_dirs)

    def test_project_menu_disables_reload_without_active_project(self):
        self.controller.archive_project("demo")
        self.assertIsNone(self.controller.current_project)
        actions = self._project_menu_actions()
        reload_action = next(
            action for action in actions if action.text() == "重新加载当前项目"
        )
        self.assertFalse(reload_action.isEnabled())
        self.controller.hide_project_menu()

    def test_project_context_menu_routes_pin_and_clear_signals(self):
        widget = self.window.nav_panel.project_list.project_widgets[0]
        pin = QtTest.QSignalSpy(widget.pinRequested)
        clear = QtTest.QSignalSpy(widget.clearRequested)

        menu = widget.build_more_menu()
        actions = [action for action in menu.actions() if not action.isSeparator()]
        self.assertEqual(
            [action.text() for action in actions],
            ["置顶", "重命名", "在资源管理器中打开", "清除", "归档", "删除"],
        )
        next(action for action in actions if action.text() == "置顶").trigger()
        next(action for action in actions if action.text() == "清除").trigger()
        self.assertEqual(len(pin), 1)
        self.assertEqual(len(clear), 1)
        self.assertIs(pin[0][0], widget)
        self.assertIs(clear[0][0], widget)
        menu.close()
        menu.deleteLater()

    def test_header_inline_rename_updates_real_project(self):
        header = self.window.config_page.header
        header.enter_edit_mode()
        header.title_edit.setText("renamed")
        header.save_title()
        self.assertEqual(self.controller.current_name, "renamed")
        self.assertEqual(
            self.controller.current_project.config_dir,
            self.root / "test/renamed/config",
        )
        self.assertTrue((self.root / "test/renamed/.plm-workspace").is_file())
        self.assertFalse((self.root / "test/demo").exists())

    def test_clear_project_can_be_explicitly_reopened(self):
        project_root = self.root / "test/demo"
        self.controller.clear_project("demo")
        self.assertIsNone(self.controller.current_project)
        self.assertEqual(self.window.nav_panel.project_list.count(), 0)
        self.assertTrue(project_root.is_dir())

        with patch.object(
            QtWidgets.QFileDialog,
            "getExistingDirectory",
            return_value=str(project_root),
        ):
            self.controller.open_project()
        self.assertEqual(self.controller.current_name, "demo")
        self.assertEqual(self.window.nav_panel.project_list.count(), 1)
        self.assertFalse(self.store.get_project_state("demo").is_cleared)

    def test_table_context_menu_inserts_and_deletes_rows(self):
        page = self.window.config_page
        editor = page.controllers_editor.editor
        before = editor.table.rowCount()
        with patch.object(
            QtWidgets.QMenu,
            "exec_",
            side_effect=self._choose_menu_action("Insert row below"),
        ):
            editor._show_row_context_menu(0, QtCore.QPoint())
        self.assertEqual(editor.table.rowCount(), before + 1)
        self.assertTrue(page.dirty)

        with patch.object(
            QtWidgets.QMenu,
            "exec_",
            side_effect=self._choose_menu_action("Delete current row"),
        ):
            editor._show_row_context_menu(1, QtCore.QPoint())
        self.assertEqual(editor.table.rowCount(), before)

    def test_lane_grid_context_menu_inserts_and_deletes_modes(self):
        page = self.window.config_page
        grid = page.mapping_editor.editor
        before = grid.table.rowCount()
        with patch.object(
            QtWidgets.QMenu,
            "exec_",
            side_effect=self._choose_menu_action("Insert row below"),
        ):
            grid._on_row_context_menu(0, QtCore.QPoint())
        self.assertEqual(grid.table.rowCount(), before + 1)
        self.assertTrue(page.dirty)

        with patch.object(
            QtWidgets.QMenu,
            "exec_",
            side_effect=self._choose_menu_action("Delete current row"),
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
