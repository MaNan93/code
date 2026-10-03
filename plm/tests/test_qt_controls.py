"""Fast functional checks for buttons and menus; no animation/layout assertions."""

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
        self.window.nav_panel.new_chat_btn.click()
        self.app.processEvents()
        menu = self.controller.project_menu
        actions = [a for a in menu.actions() if not a.isSeparator()]
        self.assertEqual(
            [a.text() for a in actions],
            ["新建项目", "打开项目…", "重新加载当前项目"],
        )
        self.assertTrue(actions[-1].isEnabled())
        self.controller.hide_project_menu()


if __name__ == "__main__":
    unittest.main()
