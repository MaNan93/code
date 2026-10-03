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
        self.assertIsNotNone(self.window.placeholder_overlay)
        self.assertTrue(self.window.placeholder_overlay.isVisible())

        self.window.on_open_docs()
        self.app.processEvents()
        self.assertIsInstance(
            self.window.centralWidget().graphicsEffect(),
            QtWidgets.QGraphicsBlurEffect,
        )
        self.window._close_placeholder()
        self.app.processEvents()
        self.assertIsNone(self.window.placeholder_overlay)
        self.assertIsNone(self.window.centralWidget().graphicsEffect())

    def test_application_activation_rechecks_external_state(self):
        with patch.object(self.window.controller, "validate_current") as validate:
            event = QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
            QtCore.QCoreApplication.sendEvent(self.app, event)
            self.app.processEvents()

        validate.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
