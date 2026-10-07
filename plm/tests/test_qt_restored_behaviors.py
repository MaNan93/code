import os
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import wait_for_idle
from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.main_window import MainWindow


class QtRestoredBehaviorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")

    def setUp(self):
        self.window = MainWindow()
        wait_for_idle(self.app)
        self.window.show()
        wait_for_idle(self.app)

    def tearDown(self):
        self.window.config_page.mark_saved()
        self.window.close()
        for widget in self.app.topLevelWidgets():
            widget.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(
            None, QtCore.QEvent.DeferredDelete
        )
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
