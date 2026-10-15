"""User-facing panel contracts, measured after real layout and painting.

Expected values come from the UI requirements: 4 px content inset, a 1 px
#CBD5E1 outline and 16 px corners. Do not derive them from implementation tokens.
"""

import math
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state,
    wait_for_idle, wait_for_signal,
)
from sample_data import sample_config


class PanelContractTests(unittest.TestCase):
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
        shutil.copytree(sample_config("bifurcate"), self.root / "test/demo/config")
        store = SettingsStore(QtCore.QSettings(
            str(self.root / "settings.ini"), QtCore.QSettings.IniFormat,
        ))
        controller = AppController(ProjectService(self.root), store)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)
        self.page = self.window.config_page
        self.panel = self.page.artifacts_panel

    def open_drawer(self):
        finished = QtTest.QSignalSpy(self.page._artifacts_animation.finished)
        QtTest.QTest.mouseClick(self.window.artifacts_toggle_button, QtCore.Qt.LeftButton)
        wait_for_signal(finished)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.isVisible())

    def load_preview(self, *, scrollbars=False):
        text = "module panel_contract;\nendmodule\n"
        if scrollbars:
            text += "\n".join("// " + "x" * 250 for _ in range(160))
        path = self.root / "source.sv"
        path.write_text(text, encoding="utf-8")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.preview.isVisible())
        self.assertEqual(self.panel.preview.toPlainText(), text)
        return text

    def assert_content_insets(self):
        w = self.window
        shell = w.window_shell
        config_pos = self.page.mapTo(shell, QtCore.QPoint())
        nav_pos = w.nav_panel.mapTo(shell, QtCore.QPoint())
        self.assertEqual(config_pos.x() - nav_pos.x() - w.nav_panel.width(), 4)
        self.assertEqual(config_pos.y() - w.title_bar.height(), 4)
        for panel in (self.page, w.log_panel):
            if panel.isVisible() and panel.height() > 0:
                position = panel.mapTo(shell, QtCore.QPoint())
                self.assertEqual(shell.width() - position.x() - panel.width(), 4)
        bottom = w.log_panel if w.log_panel.isVisible() else self.page
        position = bottom.mapTo(shell, QtCore.QPoint())
        self.assertEqual(shell.height() - position.y() - bottom.height(), 4)

    def assert_drawer_alignment(self):
        position = self.panel.mapTo(self.window.window_shell, QtCore.QPoint())
        self.assertEqual(position.y() - self.window.title_bar.height(), 4)
        self.assertEqual(
            self.window.window_shell.width() - position.x() - self.panel.width(), 4,
        )
        self.assertEqual(self.panel.height(), self.page.height())

    def assert_outline(self, image):
        self.assertEqual(
            self.panel.contentsRect(), self.panel.rect().adjusted(1, 1, -1, -1),
            "The outline must reserve exactly one logical pixel on each side",
        )
        # Check physical pixels so the same test works with fractional/high DPI.
        ratio = image.devicePixelRatio()
        width, height = self.panel.width(), self.panel.height()
        expected = QtGui.QColor("#CBD5E1")
        expected_rgb = (expected.red(), expected.green(), expected.blue())

        def has_border(x, y, neighborhood=0):
            px = math.floor((x + 0.5) * ratio)
            py = math.floor((y + 0.5) * ratio)
            for dy in range(-neighborhood, neighborhood + 1):
                for dx in range(-neighborhood, neighborhood + 1):
                    if not (0 <= px + dx < image.width() and 0 <= py + dy < image.height()):
                        continue
                    color = image.pixelColor(px + dx, py + dy)
                    rgb = (color.red(), color.green(), color.blue())
                    # Fractional DPI splits a 1 px stroke between device pixels.
                    # Allow its antialiasing, while rejecting white/toolbar fill.
                    if max(abs(a - b) for a, b in zip(rgb, expected_rgb)) <= 16:
                        return True
            return False

        for side, x, y in (
            ("top", width // 2, 0), ("right", width - 1, height // 2),
            ("bottom", width // 2, height - 1), ("left", 0, height // 2),
        ):
            self.assertTrue(has_border(x, y), f"Missing {side} border")

        # A curved outline needs coverage along the entire arc, not just a
        # single point. Mirror independently measured points around each corner.
        arc = ((16, 0), (11, 1), (8, 2), (6, 3), (5, 4),
               (4, 5), (3, 6), (2, 8), (1, 11), (0, 16))
        for right in (False, True):
            for bottom in (False, True):
                for x, y in arc:
                    x = width - 1 - x if right else x
                    y = height - 1 - y if bottom else y
                    self.assertTrue(
                        has_border(x, y, 1),
                        f"Missing rounded outline: right={right}, bottom={bottom}, point={(x, y)}",
                    )

    def test_content_stays_four_pixels_inside_after_resize_and_window_state_changes(self):
        for size in ((960, 640), (1280, 800), (1600, 1000)):
            with self.subTest(size=size):
                self.window.resize(*size)
                wait_for_idle(self.app)
                self.assert_content_insets()
        for change in (self.window.showMaximized, self.window.showNormal):
            with self.subTest(state=change.__name__):
                change()
                wait_for_idle(self.app)
                # The offscreen plugin can maximize below the window's minimum
                # size on its tiny virtual screen; native window managers honor it.
                if self.window.width() < self.window.minimumWidth():
                    self.window.resize(self.window.minimumSize())
                    wait_for_idle(self.app)
                self.assert_content_insets()

    def test_log_toggle_and_sidebar_animation_preserve_insets(self):
        for _ in range(2):
            QtTest.QTest.mouseClick(self.window.log_toggle_button, QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assert_content_insets()
        for _ in range(2):
            finished = QtTest.QSignalSpy(self.window.nav_panel.animation_group.finished)
            QtTest.QTest.mouseClick(self.window.title_bar.collapse_btn, QtCore.Qt.LeftButton)
            wait_for_signal(finished)
            wait_for_idle(self.app)
            self.assert_content_insets()

    def test_artifacts_follow_config_bounds_with_log_hidden_and_maximized(self):
        self.open_drawer()
        self.assert_drawer_alignment()
        QtTest.QTest.mouseClick(self.window.log_toggle_button, QtCore.Qt.LeftButton)
        wait_for_idle(self.app)
        self.assert_drawer_alignment()
        QtTest.QTest.mouseClick(self.panel.maximize_button, QtCore.Qt.LeftButton)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.geometry(), self.page.rect())
        self.assert_drawer_alignment()
        self.window.resize(1450, 950)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.geometry(), self.page.rect())
        self.assert_drawer_alignment()
        QtTest.QTest.mouseClick(self.panel.maximize_button, QtCore.Qt.LeftButton)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.width(), 380)
        self.assert_drawer_alignment()

    def test_loaded_preview_has_four_borders_and_continuous_corner_arcs(self):
        self.open_drawer()
        self.load_preview()
        self.assert_outline(self.panel.grab().toImage())

    def test_loaded_source_text_is_painted_in_the_preview(self):
        if not QtGui.QFontDatabase().families():
            self.skipTest("No fonts are available to verify source text painting")
        self.open_drawer()
        self.load_preview()
        image = self.panel.preview.viewport().grab().toImage()
        ratio = image.devicePixelRatio()
        ink = 0
        # Inspect the first two source lines, away from borders and scrollbars.
        for y in range(round(60 * ratio)):
            for x in range(round(10 * ratio), min(image.width(), round(230 * ratio))):
                color = image.pixelColor(x, y)
                if min(color.red(), color.green(), color.blue()) < 160:
                    ink += 1
        self.assertGreater(ink, 80, "Source exists in the model but is not painted")

    def test_outline_survives_scrollbars_search_and_narrow_drawer(self):
        self.open_drawer()
        text = self.load_preview(scrollbars=True)
        self.assertGreater(self.panel.preview.verticalScrollBar().maximum(), 0)
        self.assertGreater(self.panel.preview.horizontalScrollBar().maximum(), 0)
        self.panel.show_search()
        self.panel.search_input.setText("panel_contract")
        wait_for_idle(self.app)
        self.assertTrue(self.panel.search_bar.isVisible())
        self.panel.widthRequested.emit(300)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.width(), 300)
        self.assert_outline(self.panel.grab().toImage())
        self.assertEqual(self.panel.preview.toPlainText(), text)
        self.panel.widthRequested.emit(650)
        wait_for_idle(self.app)
        self.assert_outline(self.panel.grab().toImage())

    def test_outline_survives_maximize_restore_and_close_reopen(self):
        self.open_drawer()
        text = self.load_preview()
        self.panel.widthRequested.emit(460)
        for _ in range(2):
            QtTest.QTest.mouseClick(self.panel.maximize_button, QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assert_outline(self.panel.grab().toImage())
        self.assertEqual(self.panel.width(), 460)
        closed = QtTest.QSignalSpy(self.page._artifacts_animation.finished)
        QtTest.QTest.mouseClick(self.panel.close_button, QtCore.Qt.LeftButton)
        wait_for_signal(closed)
        self.assertFalse(self.panel.isVisible())
        self.open_drawer()
        self.assertEqual(self.panel.width(), 460)
        self.assertEqual(self.panel.preview.toPlainText(), text)
        self.assert_outline(self.panel.grab().toImage())

    def test_corner_check_detects_the_original_unclipped_preview_bug(self):
        self.open_drawer()
        self.load_preview()
        self.assert_outline(self.panel.grab().toImage())
        content = self.panel.content_layout.parentWidget()
        mask = content.mask()
        try:
            content.clearMask()
            with self.assertRaisesRegex(AssertionError, "Missing rounded outline"):
                self.assert_outline(self.panel.grab().toImage())
        finally:
            content.setMask(mask)


    def test_reopening_during_close_animation_keeps_the_loaded_file(self):
        self.open_drawer()
        text = self.load_preview()
        finished = QtTest.QSignalSpy(self.page._artifacts_animation.finished)
        self.window.artifacts_toggle_button.click()
        self.window.artifacts_toggle_button.click()
        wait_for_signal(finished)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.isVisible())
        self.assertEqual(self.panel.width(), 380)
        self.assertEqual(self.panel.preview.toPlainText(), text)
        self.assert_drawer_alignment()
        self.assert_outline(self.panel.grab().toImage())

    def test_dragging_left_border_resizes_and_maximize_disables_drag(self):
        self.open_drawer()
        panel = self.panel
        original = panel.width()

        def drag(delta):
            position = QtCore.QPointF(0, panel.height() // 2)
            global_position = QtCore.QPointF(panel.mapToGlobal(position.toPoint()))
            for kind, offset, buttons in (
                (QtCore.QEvent.MouseButtonPress, 0, QtCore.Qt.LeftButton),
                (QtCore.QEvent.MouseMove, delta, QtCore.Qt.LeftButton),
                (QtCore.QEvent.MouseButtonRelease, delta, QtCore.Qt.NoButton),
            ):
                moved = global_position - QtCore.QPointF(offset, 0)
                local = QtCore.QPointF(panel.mapFromGlobal(moved.toPoint()))
                button = QtCore.Qt.NoButton if kind == QtCore.QEvent.MouseMove else QtCore.Qt.LeftButton
                event = QtGui.QMouseEvent(kind, local, moved, button, buttons, QtCore.Qt.NoModifier)
                QtWidgets.QApplication.sendEvent(panel, event)
            wait_for_idle(self.app)

        drag(80)
        self.assertEqual(panel.width(), original + 80)
        self.assert_drawer_alignment()
        drag(-1000)
        self.assertEqual(panel.width(), 300)
        self.assert_drawer_alignment()
        panel.maximize_button.click()
        maximized_size = panel.size()
        drag(80)
        self.assertEqual(panel.size(), maximized_size)
        panel.maximize_button.click()
        self.assertEqual(panel.width(), 300)


if __name__ == "__main__":
    unittest.main()
