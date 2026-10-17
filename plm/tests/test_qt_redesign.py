"""Editing, filtering and drawer behavior of the revised Qt workspace."""

import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets
from qt_test_support import dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle
from sample_data import sample_config
from test_qt_colors import luminance
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.widgets.config_editor import GenerationEditor
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.styles.tokens import LANE_GRID_PALETTE, get_theme_color, set_active_theme
from plm.frontend.qt.widgets.lanegrid import (
    PAINT_OPACITY, PREVIEW_OPACITY, _contrast_text_color, _marker_background_color,
)


class RedesignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        preserve_application_state(self, self.app)
        isolate_host_formatter(self, self.app)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(temporary.name)
        shutil.copytree(sample_config("dpr"), self.root / "test/demo/config")
        self.controller = AppController(ProjectService(self.root), SettingsStore(
            QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat)))
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)

    def test_table_filter_preserves_content_and_deletes_the_visible_source_row(self):
        page = self.window.config_page
        editor = page.controllers_editor.editor
        before = page.content()
        editor.search_input.setText("CtrlC")
        self.assertEqual(page.content(), before)
        self.assertFalse(page.dirty)
        self.assertTrue(editor.table.isRowHidden(0))
        self.assertEqual(editor.table.currentRow(), 2)
        editor.delete_button.click()
        self.assertNotIn("CtrlC", [row["ctrl_name"] for row in editor.get_rows()])
        self.assertEqual(len(editor.get_rows()), 3)
        page.undo()
        self.assertEqual(page.content(), before)

    def test_copy_row_allocates_unique_identifier_and_name_and_can_be_undone(self):
        page = self.window.config_page
        editor = page.controllers_editor.editor
        before = page.content()
        editor.table.setCurrentCell(0, 1)
        editor.duplicate_button.click()
        rows = editor.get_rows()
        self.assertEqual(len(rows), 5)
        self.assertEqual(len({row["ctrl_id"] for row in rows}), 5)
        self.assertEqual(rows[1]["ctrl_name"], "CtrlA_copy")
        self.assertEqual(rows[1]["max_width"], rows[0]["max_width"])
        page.undo()
        self.assertEqual(page.content(), before)

    def test_no_matches_disables_row_actions_and_add_reveals_the_new_row(self):
        editor = self.window.config_page.controllers_editor.editor
        editor.search_input.setText("no-such-controller")
        self.assertFalse(editor.delete_button.isEnabled())
        self.assertFalse(editor.duplicate_button.isEnabled())
        editor.add_button.click()
        self.assertEqual(editor.search_input.text(), "")
        self.assertEqual(editor.table.rowCount(), 5)
        self.assertFalse(editor.table.isRowHidden(4))

    def test_formatter_search_spans_categories_and_save_preserves_hidden_values(self):
        self.window.on_open_settings()
        wait_for_idle(self.app)
        settings = self.window.view_stack.currentWidget()
        settings.menu_buttons[1].click()
        settings.formatter_search.setText("column_limit")
        row = list(settings._flag_controls).index("column_limit")
        self.assertFalse(settings.flag_table.isRowHidden(row))
        settings._flag_controls["column_limit"].setText("137")
        settings.formatter_search.clear()
        self.assertTrue(settings.flag_table.isRowHidden(row))
        settings.save_settings_btn.click()
        flags = self.controller.settings.formatter_preferences()["verible_flags"]
        self.assertEqual(flags["column_limit"], "137")
        self.assertIn("formal_parameters_indentation", flags)
        self.assertIn("assignment_statement_alignment", flags)

    def test_log_starts_collapsed_and_remembers_its_expanded_height(self):
        window = self.window
        self.assertFalse(window.log_panel.isVisible())
        self.assertTrue(window.log_toggle_button.isVisible())
        window.log_toggle_button.click()
        wait_for_idle(self.app)
        window.content_splitter.setSizes([400, 180])
        height = window.content_splitter.sizes()[1]
        window.hide_log()
        window.resize(1400, 950)
        wait_for_idle(self.app)
        self.assertFalse(window.log_panel.isVisible())
        window.show_log()
        wait_for_idle(self.app)
        self.assertAlmostEqual(window.content_splitter.sizes()[1], height, delta=2)

    def test_generation_failure_reopens_a_manually_collapsed_log(self):
        with patch.object(self.controller.workspaces, "generate", side_effect=ValueError("test generation failure")):
            self.controller.generate_current()
            self.assertTrue(self.window.log_panel.isVisible())
            self.window.hide_log()
            wait_for_idle(self.app)
        self.assertTrue(self.window.log_panel.isVisible())
        self.assertIn("test generation failure", self.window.log_panel.output.toPlainText())

    def test_log_clear_resets_summary_without_opening_panel(self):
        window = self.window
        window.log_panel.append_log("old output")
        window.log_panel.set_status("生成完成：18 个文件")
        self.assertIn("18", window.log_panel.status_label.text())
        window.log_panel.clear_btn.click()
        self.assertEqual(window.log_panel.output.toPlainText(), "")
        self.assertEqual(window.log_panel.status_label.text(), "")
        self.assertTrue(window.log_panel.status_bar.isHidden())
        self.assertFalse(window.log_panel.isVisible())
        window.show_log()
        wait_for_idle(self.app)
        self.assertTrue(window.log_panel.clear_btn.isVisible())

    def test_primary_pressed_and_disabled_hover_use_readable_colors(self):
        window = self.window
        window.config_page.tabs.setCurrentIndex(3)
        button = window.config_page.generation_editor.generate_btn
        for theme in ("light", "dark"):
            window.apply_theme(theme)
            button.setEnabled(True)
            button.setDown(True)
            self.app.processEvents()
            picture = button.grab().toImage()
            ratio = picture.devicePixelRatio()
            self.assertEqual(picture.pixelColor(round(5 * ratio), round(button.height() / 2 * ratio)).name(),
                             get_theme_color("primary_active").lower())
            button.setDown(False)
            button.setEnabled(False)
            QtTest.QTest.mouseMove(button, button.rect().center())
            self.app.processEvents()
            picture = button.grab().toImage()
            self.assertEqual(picture.pixelColor(round(5 * ratio), round(button.height() / 2 * ratio)).name(),
                             get_theme_color("bg_subtle").lower())

    @patch("sys.excepthook")
    def test_generation_cards_align_under_a_host_style_that_centers_forms(self, callback_errors):
        class CenteredFormStyle(QtWidgets.QProxyStyle):
            def polish(self, target):
                result = super().polish(target)
                if isinstance(target, (QtWidgets.QLineEdit, QtWidgets.QComboBox)):
                    target.setAttribute(QtCore.Qt.WA_LayoutUsesWidgetRect, False)
                return result

            def styleHint(self, hint, option=None, widget=None, returnData=None):
                if hint == QtWidgets.QStyle.SH_FormLayoutFormAlignment:
                    return int(QtCore.Qt.AlignHCenter | QtCore.Qt.AlignTop)
                return super().styleHint(hint, option, widget, returnData)

        # macOS centers forms by default, so the naming card used to shift
        # right when its fixed-width fields left spare horizontal space.
        self.app.setStyle(CenteredFormStyle("Fusion"))
        editor = GenerationEditor()
        # Exceed the initial 120px label column even with narrow Latin fallback
        # fonts, reproducing the stale naming-card column on every platform.
        editor.architecture_card.layout().labelForField(editor.bus_type).setMargin(20)
        editor.show()
        controls = (editor.arch, editor.pclk_mode, editor.bus_type, *editor._prefix_edits.values())
        for width in (520, 760):
            editor.resize(width, 600)
            wait_for_idle(self.app)
            positions = [control.mapTo(editor, QtCore.QPoint()).x() for control in controls]
            with self.subTest(width=width, positions=positions):
                details = [(card.geometry().getRect(), card.layout().getContentsMargins(),
                            [(card.layout().itemAt(row, QtWidgets.QFormLayout.LabelRole).widget().geometry().getRect())
                             for row in range(card.layout().rowCount())],
                            [(card.layout().itemAt(row, QtWidgets.QFormLayout.FieldRole).geometry().getRect(),
                              card.layout().itemAt(row, QtWidgets.QFormLayout.FieldRole).widget().geometry().getRect(),
                              card.layout().itemAt(row, QtWidgets.QFormLayout.FieldRole).widget().testAttribute(QtCore.Qt.WA_LayoutUsesWidgetRect))
                             for row in range(card.layout().rowCount())])
                           for card in (editor.architecture_card, editor.naming_card)]
                self.assertEqual(len(set(positions)), 1, f"card/label geometry: {details}")
        callback_errors.assert_not_called()

    def test_log_animation_has_intermediate_frames_and_can_reverse_twice(self):
        window = self.window
        window.show_log()
        window._log_animation.setCurrentTime(70)
        self.app.processEvents()
        self.assertEqual(window._log_animation.state(), QtCore.QAbstractAnimation.Running)
        self.assertGreater(window.content_splitter.sizes()[1], 0)
        self.assertLess(window.content_splitter.sizes()[1], 200)
        window.toggle_log()
        window._log_animation.setCurrentTime(35)
        window.toggle_log()
        wait_for_idle(self.app)
        self.assertTrue(window.log_panel.isVisible())
        self.assertAlmostEqual(window.content_splitter.sizes()[1], 200, delta=2)

    def test_log_collapse_finishes_after_resize_and_retains_its_height(self):
        window = self.window
        window.show_log()
        wait_for_idle(self.app)
        window.content_splitter.setSizes([400, 170])
        height = window.content_splitter.sizes()[1]
        window.hide_log()
        window.resize(960, 640)
        wait_for_idle(self.app)
        self.assertFalse(window.log_panel.isVisible())
        window.show_log()
        wait_for_idle(self.app)
        self.assertAlmostEqual(window.content_splitter.sizes()[1], height, delta=2)

    def test_project_path_and_small_window_document_container(self):
        path = str(self.controller.current_project.config_dir.parent)
        self.assertEqual(self.window.config_page.header.path_label.toolTip(), path)
        self.window.resize(960, 640)
        self.window.on_open_docs()
        wait_for_idle(self.app)
        docs = self.window.view_stack.currentWidget()
        self.assertLessEqual(docs.page_panel.width(), docs.width() - 48)
        self.assertGreater(len(docs.doc_browser.toPlainText()), 100)

    def test_lane_text_meets_aa_after_selection_and_hover_compositing(self):
        for theme in ("light", "dark"):
            set_active_theme(theme)
            for surface in ("bg_surface", "primary_soft"):
                for color in LANE_GRID_PALETTE:
                    background = _marker_background_color(color, PAINT_OPACITY, get_theme_color(surface))
                    for hover in (None, *LANE_GRID_PALETTE):
                        painted = (_marker_background_color(hover, PREVIEW_OPACITY, background)
                                   if hover else background)
                        text = _contrast_text_color(painted)
                        low, high = sorted((luminance(text), luminance(painted)))
                        self.assertGreaterEqual((high + .05) / (low + .05), 4.5)


if __name__ == "__main__":
    unittest.main()
