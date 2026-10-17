"""Interaction and rendered geometry contracts for the fourth UI pass."""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.styles.tokens import (
    CHECKBOX_INDICATOR_SIZE, PALETTE_ROW_SPACING,
    SETTINGS_MAX_WIDTH, SPACING_LG, SPACING_SM, get_active_theme, get_theme_color,
)
from plm.frontend.qt.widgets.common import icon_descriptor
from plm.frontend.qt.widgets.controller_swatch import ControllerSwatch


class Phase4Tests(unittest.TestCase):
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
        self.settings_path = str(self.root / "settings.ini")
        self.store = SettingsStore(QtCore.QSettings(self.settings_path, QtCore.QSettings.IniFormat))
        self.controller = AppController(ProjectService(self.root), self.store)
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)

    def capture(self, name, widget=None):
        directory = os.environ.get("PLM_PHASE4_SCREENSHOT_DIR")
        if directory:
            output = Path(directory)
            output.mkdir(parents=True, exist_ok=True)
            self.assertTrue((widget or self.window).grab().save(str(output / f"{name}.png")))

    def test_theme_shortcut_persists_and_refreshes_open_settings_without_saving_drafts(self):
        self.window.apply_theme("light")
        self.window.on_open_settings()
        settings = self.window.view_stack.currentWidget()
        settings.editor_path_edit.setText("unsaved-editor-draft")
        for theme, icon, tooltip in (("dark", "sun", "切换到浅色模式"),
                                     ("light", "moon", "切换到深色模式")):
            QtTest.QTest.mouseClick(self.window.theme_toggle_button, QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assertEqual(get_active_theme(), theme)
            self.assertEqual(self.store.theme(), theme)
            self.assertEqual(settings.theme_combo.currentData(), theme)
            self.assertEqual(settings.editor_path_edit.text(), "unsaved-editor-draft")
            self.assertNotEqual(self.store.preferences()["editor_path"], "unsaved-editor-draft")
            self.assertEqual(icon_descriptor(self.window.theme_toggle_button.icon())[0], icon)
            self.assertEqual(self.window.theme_toggle_button.toolTip(), tooltip)
            reloaded = SettingsStore(QtCore.QSettings(self.settings_path, QtCore.QSettings.IniFormat))
            self.assertEqual(reloaded.theme(), theme)
            self.capture(f"{theme}-theme-shortcut", self.window.title_bar)
        self.window._close_secondary_page()
        pages = self.window.view_stack.count()
        QtTest.QTest.mouseClick(self.window.theme_toggle_button, QtCore.Qt.LeftButton)
        wait_for_idle(self.app)
        self.assertEqual(get_active_theme(), "dark")
        self.assertEqual(self.window.view_stack.count(), pages)

    def test_header_log_toggle_and_clear_action_work(self):
        window = self.window
        for theme in ("light", "dark"):
            window.apply_theme(theme)
            window.hide_log()
            wait_for_idle(self.app)
            window.log_panel.append_log("old log content")
            window.log_panel.set_status("生成完成：18 个文件")
            window.log_panel.clear_btn.click()
            wait_for_idle(self.app)
            self.assertEqual(window.log_panel.output.toPlainText(), "")
            self.assertEqual(window.log_panel.status_label.text(), "")
            self.assertTrue(window.log_panel.status_bar.isHidden())
            self.assertFalse(window.log_panel.isVisible())
            QtTest.QTest.mouseClick(window.log_toggle_button, QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assertTrue(window.log_panel.isVisible())

    def test_many_controller_swatches_wrap_with_spacing_and_top_alignment(self):
        wrapper = self.window.config_page.mapping_editor
        self.window.config_page.tabs.setCurrentIndex(1)
        grid = wrapper.editor
        grid.set_controllers([{"ctrl_id": str(index), "ctrl_name": f"Controller_{index}_" + "LongName" * 5,
                               "max_width": "4"} for index in range(12)])
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            for width, height in ((960, 640), (1280, 800), (1600, 900)):
                with self.subTest(theme=theme, width=width):
                    self.window.resize(width, height)
                    wait_for_idle(self.app)
                    buttons = grid.palette_bar.findChildren(ControllerSwatch)
                    self.assertEqual(len(buttons), 12)
                    rows = {}
                    for button in buttons:
                        rect = button.geometry()
                        self.assertTrue(grid.palette_bar.rect().contains(rect), (rect, grid.palette_bar.rect()))
                        self.assertTrue(button.display_text().startswith(button.controller_id + ": "))
                        rows.setdefault(rect.top(), []).append(rect)
                    self.assertGreater(len(rows), 1)
                    previous_bottom = None
                    for y, rects in sorted(rows.items()):
                        if previous_bottom is not None:
                            self.assertGreaterEqual(y - previous_bottom - 1, PALETTE_ROW_SPACING)
                        rects.sort(key=lambda rect: rect.left())
                        for left, right in zip(rects, rects[1:]):
                            self.assertGreaterEqual(right.left() - left.right() - 1, SPACING_SM)
                        previous_bottom = max(rect.bottom() for rect in rects)
                    top = buttons[0].mapTo(wrapper, QtCore.QPoint()).y()
                    self.assertEqual(top, wrapper.lane_count.mapTo(wrapper, QtCore.QPoint()).y())
                    self.capture(f"{theme}-controllers-{width}")

    def test_settings_tabs_keep_the_same_container_origin_width_and_top_spacing(self):
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            self.window.on_open_settings()
            settings = self.window.view_stack.currentWidget()
            for width, height in ((960, 640), (1280, 800), (1600, 900)):
                with self.subTest(theme=theme, width=width):
                    self.window.resize(width, height)
                    origins = []
                    for index in (0, 1, 0):
                        QtTest.QTest.mouseClick(settings.menu_buttons[index], QtCore.Qt.LeftButton)
                        wait_for_idle(self.app)
                        panel = settings.page_panel
                        content = settings.general_card if index == 0 else settings.formatter_panel
                        position = panel.mapTo(self.window, QtCore.QPoint())
                        content_position = content.mapTo(self.window, QtCore.QPoint())
                        origins.append((position.x(), position.y(), panel.width(),
                                        content_position.x(), content_position.y()))
                        self.assertEqual(panel.maximumWidth(), SETTINGS_MAX_WIDTH)
                        self.assertEqual(settings.content_top_spacing.sizeHint().height(), SPACING_LG)
                        self.capture(f"{theme}-settings-{index}-{width}")
                    self.assertEqual(origins[0], origins[1])
                    self.assertEqual(origins[1], origins[2])
            self.window._close_secondary_page()

    def test_artifacts_drawer_keeps_a_flat_border_without_a_gradient_shadow(self):
        page = self.window.config_page
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            wait_for_idle(self.app)
            before = page.grab().toImage()
            page.toggle_artifacts()
            page._artifacts_animation.setCurrentTime(page._artifacts_animation.duration() // 2)
            self.app.processEvents()
            wait_for_idle(self.app)
            self.assertTrue(page.artifacts_panel.isVisible())
            ratio = page.devicePixelRatioF()
            after = page.grab().toImage()
            y = round((page.height() - 100) * ratio)
            for gap in (2, 6, 12, 17):
                x = round((page.artifacts_panel.x() - gap) * ratio)
                self.assertEqual(after.pixelColor(x, y), before.pixelColor(x, y))
            self.capture(f"{theme}-flat-artifacts")
            page.toggle_artifacts_maximized()
            self.window.resize(1100, 760)
            wait_for_idle(self.app)
            self.assertTrue(page.artifacts_panel.isVisible())
            page.toggle_artifacts_maximized()
            page.hide_artifacts()
            wait_for_idle(self.app)
            self.assertFalse(page.artifacts_panel.isVisible())

    def test_search_clear_buttons_are_centered_and_clear_the_actual_filter(self):
        page = self.window.config_page
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            for tab, editor in ((0, page.controllers_editor.editor), (2, page.signals_editor.editor)):
                page.tabs.setCurrentIndex(tab)
                search = editor.search_input
                search.setText("no_matching_row")
                wait_for_idle(self.app)
                clear = search.findChild(QtWidgets.QToolButton)
                self.assertIsNotNone(clear)
                self.assertTrue(clear.isVisible())
                self.assertLessEqual(abs(clear.y() + clear.height() / 2 - search.height() / 2), 0.5)
                self.assertTrue(search.rect().contains(clear.geometry()))
                self.capture(f"{theme}-search-{tab}", search)
                QtTest.QTest.mouseClick(clear, QtCore.Qt.LeftButton)
                wait_for_idle(self.app)
                self.assertEqual(search.text(), "")
                self.assertTrue(all(not editor.table.isRowHidden(row) for row in range(editor.table.rowCount())))

    def test_plain_add_row_text_preserves_insertion_and_undo(self):
        page = self.window.config_page
        for tab, editor in ((0, page.controllers_editor.editor), (2, page.signals_editor.editor)):
            page.tabs.setCurrentIndex(tab)
            self.assertEqual([editor.add_button.text(), editor.duplicate_button.text(), editor.delete_button.text()],
                             ["添加行", "复制行", "删除行"])
            before = editor.table.rowCount()
            QtTest.QTest.mouseClick(editor.add_button, QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assertEqual(editor.table.rowCount(), before + 1)
            page.undo()
            wait_for_idle(self.app)
            self.assertEqual(editor.table.rowCount(), before)

    def test_checkbox_has_visible_fixed_indicator_and_themed_checked_disabled_states(self):
        page = self.window.config_page
        page.tabs.setCurrentIndex(3)
        checkbox = page.generation_editor.dpr
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            for checked in (False, True):
                checkbox.setEnabled(True)
                checkbox.setChecked(checked)
                QtTest.QTest.mouseMove(self.window.title_bar, QtCore.QPoint(200, 10))
                wait_for_idle(self.app)
                option = QtWidgets.QStyleOptionButton()
                checkbox.initStyleOption(option)
                rect = checkbox.style().subElementRect(QtWidgets.QStyle.SE_CheckBoxIndicator, option, checkbox)
                self.assertEqual(rect.size(), QtCore.QSize(CHECKBOX_INDICATOR_SIZE, CHECKBOX_INDICATOR_SIZE))
                ratio = checkbox.devicePixelRatioF()
                image = checkbox.grab().toImage()
                colors = [image.pixelColor(x, y).name()
                          for x in range(round(rect.left() * ratio), round((rect.right() + 1) * ratio))
                          for y in range(round(rect.top() * ratio), round((rect.bottom() + 1) * ratio))]
                self.assertGreater(colors.count(get_theme_color("primary" if checked else "border_checkbox").lower()), 4)
                if checked:
                    self.assertGreater(colors.count(get_theme_color("text_on_primary").lower()), 4)
                self.capture(f"{theme}-checkbox-{'checked' if checked else 'unchecked'}", checkbox)
                QtTest.QTest.mouseClick(checkbox, QtCore.Qt.LeftButton, pos=rect.center())
                wait_for_idle(self.app)
                self.assertEqual(checkbox.isChecked(), not checked)
                self.assertEqual(page.generation_editor.flags()["dpr"], not checked)
            for checked in (False, True):
                checkbox.setChecked(checked)
                checkbox.setEnabled(False)
                wait_for_idle(self.app)
                self.assertFalse(checkbox.isEnabled())
                self.capture(f"{theme}-checkbox-disabled-{'checked' if checked else 'unchecked'}", checkbox)
        checkbox.setEnabled(True)


if __name__ == "__main__":
    unittest.main()
