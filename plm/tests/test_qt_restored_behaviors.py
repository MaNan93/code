import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.core.workspace import scaffold_default_content


class QtRestoredBehaviorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)
        cls.app.setStyle("Fusion")

    def setUp(self):
        isolate_host_formatter(self, self.app)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name).resolve()
        scaffold_default_content(self.root / "test/demo")
        settings = SettingsStore(QtCore.QSettings(
            str(self.root / "settings.ini"), QtCore.QSettings.IniFormat
        ))
        controller = AppController(ProjectService(self.root), settings)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            self.window = MainWindow()
            wait_for_idle(self.app)
        self.window.show()
        wait_for_idle(self.app)

    def test_settings_and_docs_use_stacked_page_routing(self):
        self.window.on_open_settings()
        wait_for_idle(self.app)

        settings = self.window.view_stack.currentWidget()
        self.assertEqual(settings.page, "settings")
        self.assertFalse(self.window.main_container.isVisible())

        self.window.on_open_docs()
        wait_for_idle(self.app)
        self.assertEqual(self.window.view_stack.currentWidget().page, "docs")
        self.window._close_secondary_page()
        wait_for_idle(self.app)
        self.assertIs(self.window.view_stack.currentWidget(), self.window.main_container)

    def test_application_activation_rechecks_external_state(self):
        with patch.object(self.window.controller, "validate_current") as validate:
            self.window._application_state_changed(QtCore.Qt.ApplicationActive)
            wait_for_idle(self.app)

        validate.assert_called_once_with()

    def test_activation_filter_follows_window_visibility_lifecycle(self):
        self.assertTrue(self.window._activation_connected)
        self.window.config_page.mark_saved()
        self.assertTrue(self.window.close())
        self.assertFalse(self.window._activation_connected)

        with patch.object(self.window.controller, "validate_current") as validate:
            self.window._application_state_changed(QtCore.Qt.ApplicationActive)
            wait_for_idle(self.app)
        validate.assert_not_called()

        self.window.show()
        wait_for_idle(self.app)
        self.assertTrue(self.window._activation_connected)
        with patch.object(self.window.controller, "validate_current") as validate:
            self.window._application_state_changed(QtCore.Qt.ApplicationActive)
            wait_for_idle(self.app)
        validate.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
