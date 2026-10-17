"""Rendered geometry and interaction contracts for the fifth UI pass."""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.styles.tokens import DARK_COLORS, get_theme_color
from plm.frontend.qt.widgets.common import RoundedCanvasFrame, icon_descriptor
from test_qt_themes import contrast


class Phase5Tests(unittest.TestCase):
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
        scaffold_default_content(self.root / "examples/demo")
        store = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
        self.controller = AppController(ProjectService(self.root), store)
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)

    def capture(self, name, widget=None):
        directory = os.environ.get("PLM_PHASE5_SCREENSHOT_DIR")
        if directory:
            output = Path(directory)
            output.mkdir(parents=True, exist_ok=True)
            self.assertTrue((widget or self.window).grab().save(str(output / f"{name}.png")))

    def glyph_origin(self, widget, rect):
        """Measure actual text pixels, excluding frame, selection and cursor."""
        # Grab the composited window: a transparent label grabbed alone stores
        # unblended RGB, whereas QLineEdit stores antialiased, opaque pixels.
        image = self.window.grab().toImage()
        offset = widget.mapTo(self.window, QtCore.QPoint())
        rect = rect.translated(offset)
        ratio = image.devicePixelRatio()
        color = QtGui.QColor(get_theme_color("text_main"))
        pixels = []
        for y in range(round(rect.top() * ratio), round((rect.bottom() + 1) * ratio)):
            for x in range(round(rect.left() * ratio), round((rect.right() + 1) * ratio)):
                actual = image.pixelColor(x, y)
                if (max(abs(actual.red() - color.red()), abs(actual.green() - color.green()),
                        abs(actual.blue() - color.blue())) <= 120
                        and max(actual.red(), actual.green(), actual.blue())
                        - min(actual.red(), actual.green(), actual.blue()) <= 45):
                    pixels.append((x / ratio - offset.x(), y / ratio - offset.y()))
        self.assertTrue(pixels, (widget.objectName(), rect))
        return min(x for x, _ in pixels), min(y for _, y in pixels)

    def test_log_is_absent_and_header_toggle_restores_height_after_reversals(self):
        window = self.window
        for theme in ("light", "dark"):
            window.apply_theme(theme)
            self.assertFalse(window.log_panel.isVisible())
            bottom = window.config_page.mapTo(window.main_container, window.config_page.rect().bottomRight())
            self.assertEqual(window.main_container.height() - bottom.y() - 1, 4)
            self.capture(f"{theme}-no-log-strip")
            QtTest.QTest.mouseClick(window.log_toggle_button, QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assertTrue(window.log_panel.isVisible())
            window.content_splitter.setSizes([400, 180])
            expected = window.content_splitter.sizes()[1]
            QtTest.QTest.mouseClick(window.log_toggle_button, QtCore.Qt.LeftButton)
            window._log_animation.setCurrentTime(50)
            self.assertTrue(window.log_panel.isVisible())
            window.resize(1100, 760)
            wait_for_idle(self.app)
            self.assertFalse(window.log_panel.isVisible())
            bottom = window.config_page.mapTo(window.main_container, window.config_page.rect().bottomRight())
            self.assertEqual(window.main_container.height() - bottom.y() - 1, 4)
            window.show_log()
            wait_for_idle(self.app)
            self.assertAlmostEqual(window.content_splitter.sizes()[1], expected, delta=2)
            window.hide_log()
            wait_for_idle(self.app)

    def test_lane_body_header_and_empty_menus_share_actions_icons_and_behavior(self):
        page = self.window.config_page
        page.tabs.setCurrentIndex(1)
        grid = page.mapping_editor.editor
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            rows = grid.get_rows()
            if len(rows) < 2:
                grid.set_rows(rows + [{**rows[0], "mode": "second_mode"}])
            for source, chosen in (("body", "在上方插入行"), ("header", "删除当前行")):
                original = grid.get_rows()
                count = grid.table.rowCount()

                def choose(menu, _pos):
                    actions = [action for action in menu.actions() if not action.isSeparator()]
                    self.assertEqual([action.text() for action in actions],
                                     ["在上方插入行", "在下方插入行", "删除当前行"])
                    self.assertEqual([icon_descriptor(action.icon())[:2] for action in actions],
                                     [("arrow-up", "text_sub"), ("arrow-down", "text_sub"), ("trash-2", "danger")])
                    if os.environ.get("PLM_PHASE5_SCREENSHOT_DIR"):
                        menu.popup(grid.table.mapToGlobal(QtCore.QPoint(40, 40)))
                        self.app.processEvents()
                        self.capture(f"{theme}-lane-menu-{source}", menu)
                        menu.hide()
                    return next(action for action in actions if action.text() == chosen)

                with patch("plm.frontend.qt.widgets.lanegrid.StyledMenu.exec_", new=choose):
                    if source == "header":
                        grid._on_header_context_menu(QtCore.QPoint(5, 5))
                    else:
                        grid._on_row_context_menu(0, QtCore.QPoint())
                self.assertEqual(grid.table.rowCount(), count + (1 if source == "body" else -1))
                grid.set_rows(original)
            grid.set_rows([])

            def insert_empty(menu, _pos):
                actions = menu.actions()
                self.assertEqual([action.text() for action in actions], ["插入行"])
                self.assertEqual(icon_descriptor(actions[0].icon())[:2], ("arrow-down", "text_sub"))
                return actions[0]

            with patch("plm.frontend.qt.widgets.lanegrid.StyledMenu.exec_", new=insert_empty):
                grid._on_row_context_menu(-1, QtCore.QPoint())
            self.assertEqual(grid.table.rowCount(), 1)

    def test_settings_and_docs_keep_the_canvas_outline_and_back_button_inside(self):
        window = self.window
        for theme in ("light", "dark"):
            window.apply_theme(theme)
            for width, height in ((960, 640), (1280, 800), (1600, 900)):
                window.resize(width, height)
                wait_for_idle(self.app)
                config = window.config_page
                baseline = QtCore.QRect(config.mapTo(window, QtCore.QPoint()), config.size())
                image = config.grab().toImage()
                for name, open_page in (("settings", window.on_open_settings), ("docs", window.on_open_docs)):
                    open_page()
                    wait_for_idle(self.app)
                    secondary = window.view_stack.currentWidget()
                    area = secondary.page_area
                    self.assertIsInstance(area, RoundedCanvasFrame)
                    self.assertEqual(QtCore.QRect(area.mapTo(window, QtCore.QPoint()), area.size()), baseline)
                    back = secondary.back_btn
                    self.assertTrue(area.isAncestorOf(back))
                    back_rect = QtCore.QRect(back.mapTo(area, QtCore.QPoint()), back.size())
                    self.assertTrue(area.rect().contains(back_rect))
                    self.assertEqual(back.mapTo(window, QtCore.QPoint()).x(),
                                     secondary.menu_buttons[0].mapTo(window, QtCore.QPoint()).x())
                    # Compare antialiased corner and straight border pixels.
                    after = area.grab().toImage()
                    for x, y in ((0, 0), (8, 2), (16, 0), (0, 16), (30, 0)):
                        ratio = area.devicePixelRatioF()
                        self.assertEqual(image.pixelColor(round(x * ratio), round(y * ratio)),
                                         after.pixelColor(round(x * ratio), round(y * ratio)))
                    self.capture(f"{theme}-{name}-{width}")
                    QtTest.QTest.mouseClick(back, QtCore.Qt.LeftButton)
                    wait_for_idle(self.app)
                    self.assertEqual(QtCore.QRect(config.mapTo(window, QtCore.QPoint()), config.size()), baseline)

    def test_table_editor_text_pixels_match_painted_cells_and_escape_cancels(self):
        page = self.window.config_page
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            for tab, table, column in ((0, page.controllers_editor.table, 1),
                                       (1, page.mapping_editor.table, 0),
                                       (2, page.signals_editor.table, 0)):
                page.tabs.setCurrentIndex(tab)
                wait_for_idle(self.app)
                index = table.model().index(0, column)
                table.setCurrentIndex(index)
                rect = table.visualRect(index)
                sample = QtCore.QRect(rect.left() + 5, rect.top() + 3, min(45, rect.width() - 10), rect.height() - 6)
                self.app.processEvents()
                before = self.glyph_origin(table.viewport(), sample)
                original = index.data()
                table.edit(index)
                wait_for_idle(self.app)
                editor = self.app.focusWidget()
                self.assertIsInstance(editor, QtWidgets.QLineEdit)
                editor.deselect()
                editor.setCursorPosition(len(editor.text()))
                editor.setReadOnly(True)  # Exclude the blinking caret from the text mask.
                self.app.processEvents()
                after = self.glyph_origin(table.viewport(), sample)
                self.assertLessEqual(abs(before[0] - after[0]), 1, (tab, before, after))
                self.assertLessEqual(abs(before[1] - after[1]), 1, (tab, before, after))
                editor.setReadOnly(False)
                self.capture(f"{theme}-table-edit-{tab}")
                editor.setText("cancelled")
                QtTest.QTest.keyClick(editor, QtCore.Qt.Key_Escape)
                wait_for_idle(self.app)
                self.assertEqual(index.data(), original)

    def test_rename_text_pixels_and_header_neighbors_stay_in_place(self):
        window = self.window
        for theme in ("light", "dark"):
            window.apply_theme(theme)
            header = window.config_page.header
            row = window.nav_panel.project_list.itemWidget(window.nav_panel.project_list.item(0))
            for name, owner, label, editor, begin, cancel in (
                ("header", header, header.title_label, header.title_edit, header.enter_edit_mode, header.cancel_title),
                ("sidebar", row, row.project_name_label, row.project_name_edit, row.begin_rename,
                 lambda: row._finish_rename(cancel=True)),
            ):
                wait_for_idle(self.app)
                origin = label.mapTo(owner, QtCore.QPoint())
                rect = QtCore.QRect(origin.x(), origin.y() + 3, min(40, label.width()), label.height() - 6)
                before = self.glyph_origin(owner, rect)
                neighbor = header.save_state.pos()
                self.capture(f"{theme}-{name}-before", owner)
                begin()
                wait_for_idle(self.app)
                editor.deselect()
                editor.setCursorPosition(len(editor.text()))
                editor.setReadOnly(True)
                self.app.processEvents()
                after = self.glyph_origin(owner, rect)
                self.assertLessEqual(abs(before[0] - after[0]), 1, (name, before, after))
                self.assertLessEqual(abs(before[1] - after[1]), 1, (name, before, after))
                if name == "header":
                    self.assertEqual(header.save_state.pos(), neighbor)
                editor.setReadOnly(False)
                self.capture(f"{theme}-{name}-editing", owner)
                cancel()

    def test_dark_palette_has_neutral_surfaces_and_readable_text_in_all_states(self):
        colors = DARK_COLORS
        self.assertEqual(colors["bg_main"], "#121316")
        self.assertEqual(colors["bg_surface"], "#1A1B20")
        for background in ("bg_main", "bg_surface", "bg_subtle", "bg_hover", "bg_focus", "primary_soft"):
            for foreground in ("text_main", "text_sub", "text_muted", "text_header"):
                self.assertGreaterEqual(contrast(colors[foreground], colors[background]), 4.5,
                                        (foreground, background))
        for background in ("primary", "primary_hover", "primary_active"):
            self.assertGreaterEqual(contrast(colors["text_on_primary"], colors[background]), 4.5)
        self.window.apply_theme("dark")
        for tab in (0, 1, 2, 3):
            self.window.config_page.tabs.setCurrentIndex(tab)
            wait_for_idle(self.app)
            self.capture(f"dark-overview-{tab}")


if __name__ == "__main__":
    unittest.main()
