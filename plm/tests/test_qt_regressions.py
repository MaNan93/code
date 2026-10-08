"""Regression coverage for GUI callbacks, layout, and editing gestures."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from PyQt5 import QtCore, QtGui, QtTest, QtWidgets, sip
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.views.config_page import ConfigPage
from plm.frontend.qt.views.documentation_page import DocumentationPage
from plm.frontend.qt.styles.tokens import FONT_CODE_PRIMARY
from plm.frontend.qt.widgets.common import load_lucide_icon
from plm.frontend.qt.widgets.lanegrid import LaneGrid
from plm.frontend.qt.widgets.tables import _PaddedItemDelegate


class QtRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        isolate_host_formatter(self, self.app)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name)
        for name in ("demo", "other"):
            scaffold_default_content(self.root / "test" / name)
        settings = SettingsStore(QtCore.QSettings(
            str(self.root / "settings.ini"), QtCore.QSettings.IniFormat
        ))
        self.controller = AppController(ProjectService(self.root), settings)
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
            wait_for_idle(self.app)
        self.window.show()
        wait_for_idle(self.app)
    def test_invalid_save_reports_inline_without_modal_dialog(self):
        page = self.window.config_page
        page.controllers_editor.table.item(0, 0).setText("invalid-id")
        before = self.controller.current_project.controllers_csv.read_bytes()
        with patch.object(QtWidgets.QMessageBox, "warning") as warning:
            self.window.nav_panel.save_btn.click()
            wait_for_idle(self.app)
        warning.assert_not_called()
        self.assertTrue(page.validation_issues)
        self.assertTrue(page.dirty)
        self.assertEqual(self.controller.current_project.controllers_csv.read_bytes(), before)
        self.assertIn("保存失败", self.window.log_panel.output.toPlainText())

    def test_secondary_page_close_resets_nav_and_switch_preserves_active_page(self):
        nav = self.window.nav_panel
        self.window.on_open_settings()
        self.assertTrue(nav.settings_btn.property("selected"))
        self.window.on_open_docs()
        self.assertFalse(nav.settings_btn.property("selected"))
        self.assertTrue(nav.docs_btn.property("selected"))
        self.window.view_stack.currentWidget().back_btn.click()
        wait_for_idle(self.app)
        self.assertIs(self.window.view_stack.currentWidget(), self.window.main_container)
        self.assertFalse(nav.docs_btn.property("selected"))
        self.window.on_open_settings()
        QtTest.QTest.keyClick(self.window.view_stack.currentWidget(), QtCore.Qt.Key_Escape)
        self.assertIs(self.window.view_stack.currentWidget(), self.window.main_container)
        self.assertFalse(nav.settings_btn.property("selected"))

    def test_invalid_formatter_value_reveals_focuses_and_selects_input(self):
        self.window.on_open_settings()
        page = self.window.view_stack.currentWidget()
        self.assertEqual([button.text() for button in page.menu_buttons],
                         ["General", "Formatter"])
        control = page._flag_controls["column_limit"]
        control.setText("-1")
        page._select_section(0)
        saved = QtTest.QSignalSpy(page.preferencesSaved)
        page._save_settings()
        wait_for_idle(self.app)
        self.assertTrue(page.menu_buttons[1].property("selected"))
        self.assertTrue(control.hasFocus())
        self.assertEqual(control.selectedText(), "-1")
        self.assertEqual(len(saved), 0)
        self.assertIn("column_limit", page.settings_status.text())

    def test_executable_browsers_use_platform_appropriate_filters(self):
        self.window.on_open_settings()
        page = self.window.view_stack.currentWidget()
        for platform in ("win32", "linux", "darwin"):
            with self.subTest(platform=platform), \
                    patch("plm.frontend.qt.views.settings_page.sys.platform", platform), \
                    patch.object(QtWidgets.QFileDialog, "getOpenFileName", return_value=("/tmp/tool", "")) as choose:
                for browse in (page._browse_editor, page._browse_verible):
                    browse()
                    file_filter = choose.call_args.args[3]
                    self.assertEqual(file_filter.split(";;")[0],
                                     "Executables (*.exe)" if platform == "win32" else "All files (*)")

    def test_formatter_value_column_fits_controls_with_large_font(self):
        self.window.on_open_settings()
        page = self.window.view_stack.currentWidget()
        page._select_section(1)
        font = QtGui.QFont(page.font())
        font.setPixelSize(20)
        page.setFont(font)
        wait_for_idle(self.app)
        header = page.flag_table.horizontalHeader()
        self.assertEqual(header.sectionResizeMode(1), QtWidgets.QHeaderView.ResizeToContents)
        for control in page._flag_controls.values():
            self.assertGreaterEqual(header.sectionSize(1), control.sizeHint().width())
            self.assertGreaterEqual(control.width(), control.sizeHint().width())

    def test_markdown_extraction_normalizes_titles_and_ignores_fenced_headings(self):
        markdown = "# Intro\n```md\n## Target: config/\n```\n  ## **Target： `config/`** ##  \nbody\n```\n## Not a heading\n```\n### Detail\nmore\n## Next\nother"
        section = DocumentationPage._extract_markdown_section(markdown, " ## Target: `config/` ")
        self.assertIn("body", section)
        self.assertIn("## Not a heading", section)
        self.assertIn("### Detail", section)
        self.assertNotIn("## Next", section)
        self.assertNotIn("# Intro", section)
        self.assertEqual(DocumentationPage._extract_markdown_section(markdown, "## Missing"), markdown)

    def test_document_tables_and_code_blocks_have_adaptive_formats(self):
        self.window.on_open_docs()
        page = self.window.view_stack.currentWidget()
        page.doc_browser.setMarkdown("| A | B |\n|---|---|\n| x | y |\n\n```python\nprint('hello')\n```")
        page._format_document()
        document = page.doc_browser.document()
        tables = [frame for frame in document.rootFrame().childFrames() if isinstance(frame, QtGui.QTextTable)]
        self.assertEqual(tables[0].format().width().type(), QtGui.QTextLength.PercentageLength)
        self.assertEqual(tables[0].format().width().rawValue(), 100)
        block = document.begin()
        code_blocks = []
        while block.isValid():
            if block.blockFormat().property(QtGui.QTextFormat.BlockCodeFence):
                code_blocks.append(block)
            block = block.next()
        self.assertTrue(code_blocks)
        for block in code_blocks:
            self.assertEqual(block.blockFormat().background().color().name().lower(), "#f1f5f9")
            self.assertGreater(block.blockFormat().leftMargin(), 0)
            self.assertGreater(block.blockFormat().rightMargin(), 0)
            self.assertIn(FONT_CODE_PRIMARY, block.charFormat().fontFamilies())

    def test_missing_activated_project_keeps_current_selection(self):
        before = self.controller.current_project
        with patch.object(self.controller.projects, "discover", return_value=[]):
            self.assertFalse(self.controller._activate_path(self.root / "missing/config"))
        self.assertIs(self.controller.current_project, before)

    def test_missing_renamed_project_does_not_drop_preferences(self):
        before = self.controller.current_project
        with patch.object(self.controller.projects, "rename", return_value=self.root / "renamed/config"), \
                patch.object(self.controller.projects, "discover", return_value=[]), \
                patch.object(self.controller.settings, "remove_project_state") as remove:
            self.controller.rename_project(before.name, "renamed")
            wait_for_idle(self.app)
        remove.assert_not_called()
        self.assertIs(self.controller.current_project, before)

    def test_replaced_project_list_keeps_stretch(self):
        nav = self.window.nav_panel
        nav.set_projects(self.controller.projects.discover(), "demo")
        self.assertEqual(nav.layout().stretch(nav.layout().indexOf(nav.project_list)), 1)

    def test_table_relayout_ignores_already_deleted_cell_widgets(self):
        delegate = _PaddedItemDelegate()
        self.addCleanup(delegate.deleteLater)
        editor = QtWidgets.QComboBox()
        option = QtWidgets.QStyleOptionViewItem()
        option.rect = QtCore.QRect(0, 0, 200, 40)
        delegate.updateEditorGeometry(editor, option, QtCore.QModelIndex())
        self.assertEqual(editor.geometry(), QtCore.QRect(8, 1, 184, 38))
        sip.delete(editor)
        delegate.updateEditorGeometry(editor, option, QtCore.QModelIndex())

    def test_empty_selection_clears_rows_without_loading_another_project(self):
        projects = self.window.nav_panel.project_list
        signals = QtTest.QSignalSpy(projects.projectSelected)
        self.assertIsNone(projects.select_project(""))
        wait_for_idle(self.app)
        self.assertEqual(len(signals), 0)
        self.assertIsNone(projects.selected_project_name)
        self.assertTrue(all(not item.header.property("selected") for item in projects.project_widgets))

    def test_focusing_error_before_validation_is_safe(self):
        page = ConfigPage()
        self.addCleanup(page.deleteLater)
        page.focus_first_error()
        self.assertEqual(page.validation_issues, ())

    def test_icon_is_not_rendered_again_on_repeated_hover(self):
        icon = load_lucide_icon("pin", "#123456", 17)
        with patch("plm.frontend.qt.widgets.common.QtSvg.QSvgRenderer", side_effect=AssertionError("rendered twice")):
            again = load_lucide_icon("pin", "#123456", 17)
        self.assertEqual(icon.cacheKey(), again.cacheKey())

    def test_callback_exception_does_not_abort_the_process(self):
        code = '''
from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt.exceptions import install_exception_handler
app = QtWidgets.QApplication([])
install_exception_handler()
button = QtWidgets.QPushButton()
def fail():
    raise RuntimeError("injected callback failure")
button.clicked.connect(fail)
QtCore.QTimer.singleShot(0, button.click)
QtCore.QTimer.singleShot(50, app.quit)
app.exec_()
print("event loop survived")
'''
        result = subprocess.run([sys.executable, "-c", code],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("event loop survived", result.stdout)
        self.assertIn("injected callback failure", result.stderr)

    def lane_grid(self):
        grid = LaneGrid()
        grid.set_columns(2)
        grid.set_controllers([{"ctrl_id": "0", "ctrl_name": "C", "max_width": "2"}])
        grid.set_rows([{"mode": "0", "lane0": "0-1", "lane1": "0-0"}])
        grid.resize(500, 250)
        grid.show()
        wait_for_idle(self.app)
        self.addCleanup(grid.close)
        self.addCleanup(grid.deleteLater)
        return grid

    def test_double_click_edits_original_value_without_painting(self):
        grid = self.lane_grid()
        table = grid.table
        point = table.visualItemRect(table.item(0, 1)).center()
        changes = QtTest.QSignalSpy(grid.changed)
        QtTest.QTest.mouseClick(table.viewport(), QtCore.Qt.LeftButton, pos=point)
        self.assertEqual(grid.get_rows()[0]["lane0"], "0-1")
        QtTest.QTest.mouseDClick(table.viewport(), QtCore.Qt.LeftButton, pos=point)
        QtTest.QTest.mouseRelease(table.viewport(), QtCore.Qt.LeftButton, pos=point)
        editor = table.findChild(QtWidgets.QLineEdit)
        self.assertIsNotNone(editor)
        self.assertEqual(editor.text(), "0-1")
        QtTest.QTest.qWait(QtWidgets.QApplication.doubleClickInterval() + 30)
        self.assertEqual(grid.get_rows()[0]["lane0"], "0-1")
        self.assertEqual(len(changes), 0)

    def test_single_click_paints_only_after_release_and_double_click_window(self):
        grid = self.lane_grid()
        point = grid.table.visualItemRect(grid.table.item(0, 1)).center()
        QtTest.QTest.mousePress(grid.table.viewport(), QtCore.Qt.LeftButton, pos=point)
        self.assertEqual(grid.get_rows()[0]["lane0"], "0-1")
        QtTest.QTest.mouseRelease(grid.table.viewport(), QtCore.Qt.LeftButton, pos=point)
        QtTest.QTest.qWait(QtWidgets.QApplication.doubleClickInterval() + 30)
        self.assertEqual(grid.get_rows()[0]["lane0"], "0-0")

    def test_drag_threshold_prevents_accidental_paint_and_drags_paint_a_range(self):
        grid = self.lane_grid()
        table = grid.table
        start = table.visualItemRect(table.item(0, 1)).center()
        end = table.visualItemRect(table.item(0, 2)).center()
        QtTest.QTest.mousePress(table.viewport(), QtCore.Qt.LeftButton, pos=start)
        for point in (start + QtCore.QPoint(1, 0), end):
            event = QtGui.QMouseEvent(QtCore.QEvent.MouseMove, QtCore.QPointF(point),
                                     QtCore.Qt.NoButton, QtCore.Qt.LeftButton, QtCore.Qt.NoModifier)
            self.app.sendEvent(table.viewport(), event)
            if point != end:
                self.assertFalse(grid._drag_active)
                self.assertEqual(grid.get_rows()[0]["lane0"], "0-1")
        self.assertTrue(grid._drag_active)
        QtTest.QTest.mouseRelease(table.viewport(), QtCore.Qt.LeftButton, pos=end)
        self.assertEqual([grid.get_rows()[0][f"lane{i}"] for i in range(2)], ["0-0", "0-1"])

    def test_reloading_rows_cancels_deferred_clicks(self):
        grid = self.lane_grid()
        point = grid.table.visualItemRect(grid.table.item(0, 1)).center()
        QtTest.QTest.mouseClick(grid.table.viewport(), QtCore.Qt.LeftButton, pos=point)
        replacement = [{"mode": "0", "lane0": "", "lane1": "0-1"}]
        grid.set_rows(replacement)
        QtTest.QTest.qWait(QtWidgets.QApplication.doubleClickInterval() + 30)
        self.assertEqual(grid.get_rows(), replacement)

    def test_many_lanes_keep_readable_widths_and_scroll_horizontally(self):
        grid = self.lane_grid()
        grid.set_columns(32)
        wait_for_idle(self.app)
        self.assertEqual(grid.table.horizontalScrollBarPolicy(), QtCore.Qt.ScrollBarAsNeeded)
        self.assertGreater(grid.table.horizontalScrollBar().maximum(), 0)
        self.assertGreaterEqual(grid.table.columnWidth(1), grid.table.fontMetrics().horizontalAdvance("31"))
        grid.set_columns(2)
        wait_for_idle(self.app)
        self.assertEqual(grid.table.horizontalScrollBarPolicy(), QtCore.Qt.ScrollBarAlwaysOff)

    def test_hidden_log_stays_hidden_during_resize_and_can_be_reopened(self):
        self.window.hide_log()
        for width, height in ((1100, 700), (1500, 1000)):
            self.window.resize(width, height)
            wait_for_idle(self.app)
            self.assertEqual(self.window.content_splitter.sizes()[1], 0)
        self.window.toggle_log()
        self.assertGreater(self.window.content_splitter.sizes()[1], 0)

    def test_external_change_validation_is_debounced_without_modal_warning(self):
        controller = self.controller
        controller.current_project.controllers_csv.write_text("externally modified", encoding="utf-8")
        with patch.object(QtWidgets.QMessageBox, "warning") as warning:
            controller.validate_current()
            controller.validate_current()
            self.assertTrue(controller._validation_running)
            self.assertEqual(len(controller.tasks._tasks), 1)
            wait_for_idle(self.app)
        warning.assert_not_called()
        self.assertEqual(controller.generation_state, "external_changed")
        self.assertFalse(controller._validation_running)
