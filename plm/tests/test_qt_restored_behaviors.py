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

    def test_settings_and_docs_blur_only_the_background(self):
        self.window.on_open_settings()
        self.app.processEvents()

        effect = self.window.centralWidget().graphicsEffect()
        self.assertIsInstance(effect, QtWidgets.QGraphicsBlurEffect)
        self.assertEqual(effect.blurRadius(), 7.0)
        self.assertIsNotNone(self.window.secondary_overlay)
        self.assertTrue(self.window.secondary_overlay.isVisible())

        self.window.on_open_docs()
        self.app.processEvents()
        self.assertIsInstance(
            self.window.centralWidget().graphicsEffect(),
            QtWidgets.QGraphicsBlurEffect,
        )
        self.window._close_secondary_page()
        self.app.processEvents()
        self.assertIsNone(self.window.secondary_overlay)
        self.assertIsNone(self.window.centralWidget().graphicsEffect())

    def test_application_activation_rechecks_external_state(self):
        with patch.object(self.window.controller, "validate_current") as validate:
            event = QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
            QtCore.QCoreApplication.sendEvent(self.app, event)
            self.app.processEvents()

        validate.assert_called_once_with()

    def test_activation_filter_follows_window_visibility_lifecycle(self):
        self.assertTrue(self.window._app_event_filter_installed)
        self.window.config_page.mark_saved()
        self.assertTrue(self.window.close())
        self.assertFalse(self.window._app_event_filter_installed)

        with patch.object(self.window.controller, "validate_current") as validate:
            QtCore.QCoreApplication.sendEvent(
                self.app, QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
            )
            self.app.processEvents()
        validate.assert_not_called()

        self.window.show()
        self.app.processEvents()
        self.assertTrue(self.window._app_event_filter_installed)
        with patch.object(self.window.controller, "validate_current") as validate:
            QtCore.QCoreApplication.sendEvent(
                self.app, QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
            )
            self.app.processEvents()
        validate.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
