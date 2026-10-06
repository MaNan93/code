"""Keep translucent popup painting inside the native window bounds."""

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.widgets.hover_card import HoverCard


class HoverCardRenderingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.previous_stylesheet = self.app.styleSheet()
        self.app.setStyleSheet(APP_QSS)
        self.card = HoverCard()
        self.card.set_project("demo", os.getcwd())
        self.card.move(-10000, -10000)
        self.card.adjustSize()
        self.card.show()
        self.app.processEvents()

    def tearDown(self):
        self.card.close()
        self.card.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        self.app.setStyleSheet(self.previous_stylesheet)

    def test_complete_shadow_fits_inside_translucent_window(self):
        self.assertTrue(self.card.testAttribute(QtCore.Qt.WA_TranslucentBackground))
        self.assertIsNone(self.card.graphicsEffect())
        bounds = self.card.surface.graphicsEffect().boundingRectFor(
            QtCore.QRectF(self.card.surface.rect())
        ).translated(self.card.surface.pos())
        self.assertTrue(QtCore.QRectF(self.card.rect()).contains(bounds))
        self.assertEqual(self.card.width(), 260)

    def test_window_corners_are_transparent_and_card_background_is_opaque(self):
        rendered = self.card.grab().toImage()
        self.assertEqual(rendered.pixelColor(0, 0).alpha(), 0)
        surface = self.card.surface.geometry()
        scale = rendered.devicePixelRatio()
        background = rendered.pixelColor(round(surface.center().x() * scale),
                                        round((surface.top() + 5) * scale))
        self.assertEqual(background.getRgb(), (255, 255, 255, 255))

    def test_repeated_popup_updates_do_not_report_layered_window_failures(self):
        messages = []
        previous_handler = QtCore.qInstallMessageHandler(lambda _kind, _context, message: messages.append(message))
        try:
            for index in range(10):
                self.card.hide()
                self.card.set_project(f"project-{index}", os.getcwd())
                self.card.move(-10000, -10000 + 36 * index)
                self.card.show()
                self.card.update()
                self.app.processEvents()
        finally:
            QtCore.qInstallMessageHandler(previous_handler)
        self.assertFalse([message for message in messages if "UpdateLayeredWindowIndirect" in message])
