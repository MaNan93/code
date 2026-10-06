import os
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.main_window import MainWindow


class QtRestoredBehaviorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")

    def setUp(self):
        self.window = MainWindow()
        self.window.show()
        self.app.processEvents()

    def tearDown(self):
        self.window.config_page.mark_saved()
        self.window.close()
        for widget in self.app.topLevelWidgets():
            widget.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(
            None, QtCore.QEvent.DeferredDelete
        )
        self.app.processEvents()

    def test_settings_and_docs_use_stacked_page_routing(self):
        self.window.on_open_settings()
        self.app.processEvents()

        settings = self.window.view_stack.currentWidget()
        self.assertEqual(settings.page, "settings")
        self.assertFalse(self.window.main_container.isVisible())

        self.window.on_open_docs()
        self.app.processEvents()
        self.assertEqual(self.window.view_stack.currentWidget().page, "docs")
        self.window._close_secondary_page()
        self.app.processEvents()
        self.assertIs(self.window.view_stack.currentWidget(), self.window.main_container)

    def test_application_activation_rechecks_external_state(self):
        with patch.object(self.window.controller, "validate_current") as validate:
            self.window._application_state_changed(QtCore.Qt.ApplicationActive)
            self.app.processEvents()

        validate.assert_called_once_with()

    def test_activation_filter_follows_window_visibility_lifecycle(self):
        self.assertTrue(self.window._activation_connected)
        self.window.config_page.mark_saved()
        self.assertTrue(self.window.close())
        self.assertFalse(self.window._activation_connected)

        with patch.object(self.window.controller, "validate_current") as validate:
            self.window._application_state_changed(QtCore.Qt.ApplicationActive)
            self.app.processEvents()
        validate.assert_not_called()

        self.window.show()
        self.app.processEvents()
        self.assertTrue(self.window._activation_connected)
        with patch.object(self.window.controller, "validate_current") as validate:
            self.window._application_state_changed(QtCore.Qt.ApplicationActive)
            self.app.processEvents()
        validate.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
