import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import preserve_application_state, wait_for_idle
from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.styles.tokens import PRIMARY_SOFT, CONTROL_HEIGHT, ICON_SIZE, RADIUS_HOVER, TEXT_ARTIFACTS_MUTED
from plm.frontend.qt.widgets.common import StyledMenu, load_lucide_icon
from plm.frontend.qt.widgets.code_preview import (
    CodePreview,
    SYNTAX_COMMENT,
    SYNTAX_KEYWORD,
    SYNTAX_STRING,
)


class ArtifactPreviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.panel = ArtifactsPanel()
        self.panel.resize(400, 630)
        self.panel.show()

    def tearDown(self):
        self._dispose_widget(self.panel)

    def _dispose_widget(self, widget):
        # Finish lazy reads before deleting the widget and its temporary files.
        wait_for_idle(self.app)
        widget.close()
        widget.deleteLater()
        self.app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        wait_for_idle(self.app)

    def file(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_toolbar_path_tracks_selection_and_elides_without_moving_buttons(self):
        one = self.file("rtl/first.sv", "module first; endmodule")
        two = self.file("rtl/pipe_lane_mapper_connection_with_a_long_integration_specific_name.sv", "module second; endmodule")
        path_width = self.panel.path_label.fontMetrics().horizontalAdvance(str(one))
        self.panel.resize(path_width + 400, 630)
        self.panel.set_files([one, two], self.root)
        wait_for_idle(self.app)
        label = self.panel.path_label
        self.assertEqual(
            self.panel.path_button.mapTo(self.panel, QtCore.QPoint()).x(),
            self.panel.preview.mapTo(self.panel, QtCore.QPoint()).x() + 16,
        )
        self.assertEqual(label.display_path, "rtl / first.sv")
        self.assertIn("<b", label.text())
        self.assertNotIn(str(self.root), label.text())
        self.assertGreater(label.x(), self.panel.path_button.arrow.geometry().right())
        self.assertFalse(self.panel.path_button.icon().pixmap(22, 22).mask().isNull())
        QtTest.QTest.mouseClick(self.panel.path_button, QtCore.Qt.LeftButton)
        self.assertTrue(self.panel.file_tree.isVisible())
        self.panel.select_file(two)
        self.assertEqual(label.toolTip(), "")
        self.assertEqual(label.accessibleName(), str(two))
        self.panel.resize(400, 630)
        wait_for_idle(self.app)
        self.assertEqual(label.toolTip(), "")
        self.assertEqual(self.panel.preview.toolTip(), "")
        self.assertNotEqual(label.display_path, f"rtl / {two.name}")
        self.assertTrue(label.display_path == two.name or "\u2026" in label.display_path)
        self.assertTrue(self.panel.maximize_button.isVisible())
        self.panel.set_files([], self.root)
        wait_for_idle(self.app)
        self.assertEqual(label.text(), "")
        self.assertEqual(label.toolTip(), "")

    def test_file_popup_preserves_preview_geometry_and_fits_screen(self):
        paths = [self.file(f"rtl/file_{i:02d}.sv", "module test; endmodule") for i in range(80)]
        self.panel.resize(1000, 630)
        self.panel.set_files(paths, self.root)
        wait_for_idle(self.app)
        geometry = self.panel.preview.geometry()
        self.panel.path_button.click()
        wait_for_idle(self.app)
        popup = self.panel.file_popup
        self.assertTrue(popup.windowFlags() & QtCore.Qt.Popup)
        self.assertTrue(popup.windowFlags() & QtCore.Qt.FramelessWindowHint)
        self.assertEqual(self.panel.preview.geometry(), geometry)
        self.assertTrue(popup.screen().availableGeometry().contains(popup.geometry()))
        self.assertLessEqual(popup.height(), popup.MAX_HEIGHT)
        self.assertGreater(self.panel.file_tree.verticalScrollBar().maximum(), 0)
        QtTest.QTest.keyClick(self.panel.file_tree, QtCore.Qt.Key_Escape)
        wait_for_idle(self.app)
        self.assertFalse(popup.isVisible())
        self.assertFalse(self.panel.path_button.isChecked())
        self.assertEqual(self.panel.preview.geometry(), geometry)
        self.panel.path_button.click()
        self.assertTrue(popup.isVisible())
        self.panel.hide()
        self.assertFalse(popup.isVisible())

    def test_preview_fills_removed_footer_and_keeps_output_status(self):
        path = self.root / "status.sv"
        path.write_bytes(b"module example;\r\nendmodule\r\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.set_output_state("out_of_date", "输出已过期")
        self.assertIsNone(self.panel.findChild(QtWidgets.QFrame, "ArtifactFooter"))
        self.assertEqual(self.panel.preview.mapTo(self.panel, self.panel.preview.rect().bottomLeft()).y(),
                         self.panel.contentsRect().bottom())
        self.assertEqual(self.panel.status_text, "输出已过期")
        self.assertIn("输出已过期", self.panel.toolbar.toolTip())
        self.panel.resize(1000, 630)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.close_button.geometry().right(), self.panel.toolbar.width() - 17)

    def test_complete_readonly_source_and_line_numbers(self):
        text = "module generated;\n" + "assign value = " + "0" * 250 + ";\n"
        text += "\n".join(f"// line {i}" for i in range(150)) + "\nendmodule\n"
        path = self.file("rtl/generated.sv", text)
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        wait_for_idle(self.app)
        editor = self.panel.preview
        self.assertEqual(editor.toPlainText(), text)
        self.assertGreater(editor.horizontalScrollBar().maximum(), 0)
        self.assertEqual(editor.line_numbers.width(), editor.line_number_width())
        font = QtGui.QFont(editor.font())
        font.setPixelSize(font.pixelSize() + 4)
        editor.setFont(font)
        wait_for_idle(self.app)
        self.assertEqual(editor.viewportMargins().left(), editor.line_number_width())
        self.assertEqual(editor.line_numbers.width(), editor.line_number_width())
        editor.moveCursor(QtGui.QTextCursor.End)
        QtTest.QTest.keyClicks(editor, "unexpected_edit")
        self.assertEqual(editor.toPlainText(), text)
        editor.selectAll()
        editor.copy()
        self.assertEqual(QtWidgets.QApplication.clipboard().text(), text)
        self.panel.copy_path()
        self.assertEqual(QtWidgets.QApplication.clipboard().text(), str(path))

    def test_file_tree_uses_medium_rows_and_capsule_selection(self):
        self.panel.setStyleSheet(APP_QSS)
        path = self.file("rtl/common/selected.sv", "module selected; endmodule")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.path_button.click()
        wait_for_idle(self.app)
        tree = self.panel.file_tree
        self.assertTrue(tree.isHeaderHidden())
        self.assertTrue(tree.rootIsDecorated())
        self.assertEqual(tree.indentation(), ICON_SIZE)
        self.assertIsNone(tree.graphicsEffect())
        item = tree.currentItem()
        file_icon = load_lucide_icon("file-code-corner", TEXT_ARTIFACTS_MUTED)
        self.assertEqual(item.icon(0).cacheKey(), file_icon.cacheKey())
        tree.collapseAll()
        tree.expandAll()
        self.assertEqual(item.icon(0).cacheKey(), file_icon.cacheKey())
        rect = tree.visualItemRect(item)
        self.assertEqual(rect.height(), CONTROL_HEIGHT)
        image = tree.viewport().grab().toImage()
        self.assertEqual(image.pixelColor(2, rect.center().y()).name(), "#ffffff")
        self.assertEqual(image.pixelColor(image.width() - 10, rect.center().y()).name(), PRIMARY_SOFT.lower())
        self.assertIn(f"border-radius: {RADIUS_HOVER}px", APP_QSS)
        self.assertNotIn("border-left: 2px solid #3B82F6", APP_QSS)
        self.assertNotIn("$chevron_", APP_QSS)

    def test_preview_context_menu_has_no_native_frame_and_preserves_copy(self):
        preview = self.panel.preview
        preview.setPlainText("module example; endmodule")
        menu = preview.createStandardContextMenu()
        self.assertIsInstance(menu, StyledMenu)
        self.assertTrue(menu.windowFlags() & QtCore.Qt.FramelessWindowHint)
        self.assertTrue(menu.windowFlags() & QtCore.Qt.NoDropShadowWindowHint)
        actions = [action for action in menu.actions() if not action.isSeparator()]
        self.assertFalse(actions[0].isEnabled())
        actions[-1].trigger()
        self.assertTrue(preview.textCursor().hasSelection())
        selected_menu = preview.createStandardContextMenu()
        copy = next(action for action in selected_menu.actions() if not action.isSeparator())
        self.assertTrue(copy.isEnabled())
        copy.trigger()
        self.assertEqual(QtWidgets.QApplication.clipboard().text(), preview.toPlainText())

    def test_refresh_retains_selected_file_and_project_switch_clears_it(self):
        one = self.file("rtl/one.sv", "module one; endmodule")
        two = self.file("tb/two.sv", "module two; endmodule")
        self.panel.set_files([one, two], self.root)
        wait_for_idle(self.app)
        self.panel.select_file(two)
        wait_for_idle(self.app)
        two.write_text("module refreshed; endmodule", encoding="utf-8")
        self.panel.set_files([one, two], self.root)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.current_path, two)
        self.assertIn("refreshed", self.panel.preview.toPlainText())
        self.assertEqual(self.panel.current_path.relative_to(self.root), Path("tb") / "two.sv")
        self.panel.set_files([one], self.root)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.current_path, one)
        self.panel.set_files([], self.root / "other")
        wait_for_idle(self.app)
        self.assertIsNone(self.panel.current_path)
        self.assertFalse(self.panel.preview.toPlainText())
        self.assertFalse(self.panel.search_button.isEnabled())
        self.assertFalse(self.panel.open_editor_button.isEnabled())

    def test_missing_binary_and_empty_files_do_not_keep_old_text(self):
        valid = self.file("good.sv", "module good; endmodule")
        missing = self.root / "missing.sv"
        binary = self.root / "binary.bin"
        binary.write_bytes(b"\xff\xfe")
        empty = self.file("empty.sv", "")
        for path in (missing, binary):
            self.panel.set_files([valid, path], self.root)
            wait_for_idle(self.app)
            self.panel.select_file(path)
            wait_for_idle(self.app)
            self.assertFalse(self.panel.preview.toPlainText())
            self.assertIn("无法预览", self.panel.status_text)
            self.assertFalse(self.panel.search_button.isEnabled())
            self.panel.select_file(valid)
            wait_for_idle(self.app)
            self.assertEqual(self.panel.preview.toPlainText(), valid.read_text())
        self.panel.set_files([empty], self.root)
        wait_for_idle(self.app)
        self.assertFalse(self.panel.preview.toPlainText())
        self.assertTrue(self.panel.search_button.isEnabled())
        self.assertIn("0 行", self.panel.status_text)

    def test_search_wraps_both_directions_and_reports_no_match(self):
        path = self.file("search.sv", "module match;\n// middle\nendmodule // match")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.show_search()
        self.assertTrue(self.panel.search_bar.isVisible())
        self.panel.search_input.setText("match")
        cursor = self.panel.preview.textCursor()
        self.assertEqual(cursor.selectedText(), "match")
        first = cursor.selectionStart()
        self.assertTrue(self.panel.find_text())
        last = self.panel.preview.textCursor().selectionStart()
        self.assertGreater(last, first)
        self.assertTrue(self.panel.find_text())
        self.assertEqual(self.panel.preview.textCursor().selectionStart(), first)
        self.assertTrue(self.panel.find_text(True))
        self.assertEqual(self.panel.preview.textCursor().selectionStart(), last)
        self.panel.search_input.setText("missing_symbol")
        self.assertEqual(self.panel.search_status.text(), "未找到")
        self.panel.search_input.clear()
        self.assertFalse(self.panel.search_status.text())
        self.panel.activateWindow()
        self.panel.search_input.setFocus()
        wait_for_idle(self.app)
        QtTest.QTest.keyClick(self.panel.search_input, QtCore.Qt.Key_Escape)
        self.assertFalse(self.panel.search_bar.isVisible())
        QtTest.QTest.keyClick(self.panel.preview, QtCore.Qt.Key_F, QtCore.Qt.ControlModifier)
        self.assertTrue(self.panel.search_bar.isVisible())
        self.panel.search_input.setText("match")
        QtTest.QTest.keyClick(self.panel.search_input, QtCore.Qt.Key_F3)
        self.assertEqual(self.panel.preview.textCursor().selectionStart(), last)
        QtTest.QTest.keyClick(self.panel.search_input, QtCore.Qt.Key_Return, QtCore.Qt.ShiftModifier)
        self.assertEqual(self.panel.preview.textCursor().selectionStart(), first)

    def test_file_tree_is_popup_managed_and_closes_after_selection(self):
        one = self.file("rtl/one.sv", "module one;\nendmodule\n")
        two = self.file("tb/two.sv", "module two;\nendmodule\n")
        self.panel.set_files([one, two], self.root)
        wait_for_idle(self.app)
        self.panel.resize(420, 630)
        self.panel.show()
        wait_for_idle(self.app)
        preview_geometry = QtCore.QRect(self.panel.preview.geometry())

        self.panel.path_button.click()
        wait_for_idle(self.app)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.file_tree.isVisible())
        self.assertIs(self.panel.file_tree.parent(), self.panel.file_popup)
        self.assertEqual(self.panel.preview.geometry(), preview_geometry)

        iterator = QtWidgets.QTreeWidgetItemIterator(self.panel.file_tree)
        target = None
        while iterator.value() is not None:
            item = iterator.value()
            if item.data(0, QtCore.Qt.UserRole) == str(two):
                target = item
                break
            iterator += 1
        self.assertIsNotNone(target)
        self.panel._tree_item_clicked(target, 0)
        self.assertEqual(self.panel.current_path, two)
        self.assertFalse(self.panel.file_tree.isVisible())

    def test_search_supports_line_jump(self):
        path = self.file("jump.sv", "line1\nline2\nline3\nline4\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.show_search()
        self.panel.search_input.setText(":3")
        self.assertEqual(self.panel.preview.textCursor().blockNumber(), 2)
        self.assertEqual(self.panel.search_status.text(), "第 3 行")
        self.panel.search_input.setText(":99")
        self.assertEqual(self.panel.search_status.text(), "行号超出范围")

    def test_diff_switches_between_unified_diff_and_current_file(self):
        path = self.file(
            "rtl/one.sv",
            "module one;\nassign value = 1'b0;\nendmodule\n",
        )
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        current = "module one;\nassign value = 1'b1;\nendmodule\n"
        path.write_text(current, encoding="utf-8")
        self.panel.set_files(
            [path], self.root, statuses={"rtl/one.sv": "Modified"}
        )
        wait_for_idle(self.app)
        self.assertTrue(self.panel.diff_button.isEnabled())
        self.panel.diff_button.click()
        wait_for_idle(self.app)
        diff = self.panel.preview.toPlainText()
        self.assertIn("--- previous/rtl/one.sv", diff)
        self.assertIn("+++ current/rtl/one.sv", diff)
        self.assertIn("-assign value = 1'b0;", diff)
        self.assertIn("+assign value = 1'b1;", diff)
        # Check the rendered row and gutter, not just QColor configuration.
        self.app.processEvents()
        preview = self.panel.preview
        viewport_image = preview.viewport().grab().toImage()
        gutter_image = preview.line_numbers.grab().toImage()
        for prefix, background, gutter in (
            ("-assign", "#ffebe9", "#ffd7d5"),
            ("+assign", "#e6ffec", "#ccffd8"),
            ("@@", "#ddf4ff", "#ddf4ff"),
        ):
            index = next(i for i, line in enumerate(diff.splitlines()) if line.startswith(prefix))
            block = preview.document().findBlockByNumber(index)
            y = int(preview.blockBoundingGeometry(block).translated(preview.contentOffset()).center().y())
            viewport_scale = viewport_image.devicePixelRatio()
            gutter_scale = gutter_image.devicePixelRatio()
            self.assertEqual(viewport_image.pixelColor(
                round(viewport_image.width() - 16 * viewport_scale), round(y * viewport_scale)).name(), background)
            self.assertEqual(gutter_image.pixelColor(
                round(gutter_image.width() - 2 * gutter_scale), round(y * gutter_scale)).name(), gutter)
        self.panel.diff_button.click()
        wait_for_idle(self.app)
        self.assertEqual(self.panel.preview.toPlainText(), current)
        self.assertEqual(self.panel.preview.extraSelections(), [])

    def test_diff_coordinates_follow_hunks_and_do_not_treat_source_as_file_headers(self):
        diff = ("--- previous/file\n+++ current/file\n@@ -115,3 +116,3 @@\n"
                " unchanged\n--- old source\n+++ new source\n tail\n"
                "\\ No newline at end of file\n@@ -200 +201 @@\n-old\n+new\n")
        self.assertEqual(CodePreview.diff_rows(diff), [
            (None, None, "header"), (None, None, "header"), (None, None, "hunk"),
            (115, 116, "context"), (116, None, "removed"), (None, 117, "added"),
            (117, 118, "context"), (None, None, "marker"), (None, None, "hunk"),
            (200, None, "removed"), (None, 201, "added"),
        ])

    def test_diff_separates_lines_without_trailing_newlines(self):
        for previous, current, markers in (
            ("before", "after", 2),
            ("before\n", "after", 1),
            ("before", "after\n", 1),
            ("same", "same\n", 1),
        ):
            with self.subTest(previous=previous, current=current):
                path = self.file("rtl/no_newline.sv", current)
                self.panel.set_files(
                    [path], self.root, baselines={"rtl/no_newline.sv": previous},
                )
                wait_for_idle(self.app)
                if not self.panel.diff_button.isChecked():
                    self.panel.diff_button.click()
                wait_for_idle(self.app)
                lines = self.panel.preview.toPlainText().splitlines()
                self.assertIn("-" + previous.rstrip("\n"), lines)
                self.assertIn("+" + current.rstrip("\n"), lines)
                self.assertEqual(lines.count("\\ No newline at end of file"), markers)
                self.panel.diff_button.click()
                wait_for_idle(self.app)
                self.assertEqual(self.panel.preview.toPlainText(), current)

    def test_toolbar_compacts_without_losing_more_actions(self):
        self.panel._apply_toolbar_density(320)
        self.assertFalse(self.panel.open_editor_button.isVisible())
        self.assertFalse(self.panel.search_button.isVisible())
        self.assertTrue(self.panel.path_button.isVisible())
        self.assertTrue(self.panel.more_button.isVisible())
        self.assertTrue(self.panel.maximize_button.isVisible())
        labels = [action.text() for action in self.panel.more_menu.actions() if action.isVisible()]
        self.assertIn("在编辑器中打开", labels)
        self.assertIn("搜索当前文件", labels)
        self.assertNotIn("显示/隐藏文件树", labels)
        self.assertNotIn("刷新文件", labels)
        self.panel._apply_toolbar_density(700)
        self.assertTrue(self.panel.open_editor_button.isVisible())
        self.assertTrue(self.panel.search_button.isVisible())
        self.assertTrue(self.panel.diff_button.isVisible())
        labels = [action.text() for action in self.panel.more_menu.actions() if action.isVisible()]
        self.assertEqual(labels, [])
        self.assertFalse(self.panel.more_button.isVisible())

    def test_overflow_actions_follow_button_enabled_states(self):
        self.panel._apply_toolbar_density(320)
        self.panel.more_menu.aboutToShow.emit()
        actions = {action.text(): action for action in self.panel.more_menu.actions()}
        self.assertFalse(actions["搜索当前文件"].isEnabled())
        path = self.file("example.v", "module example; endmodule\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.more_menu.aboutToShow.emit()
        self.assertTrue(actions["搜索当前文件"].isEnabled())
        self.assertNotIn("切换 Verilog 高亮", actions)
        self.assertNotIn("打开输出文件夹", actions)
        self.assertNotIn("复制文件内容", actions)
        actions["搜索当前文件"].trigger()
        self.assertTrue(self.panel.search_bar.isVisible())

    def test_verilog_highlight_multiline_comments_strings_and_automatic_file_detection(self):
        editor = CodePreview()
        self.addCleanup(self._dispose_widget, editor)
        editor.setPlainText('/* module\nendmodule */ module x; // endmodule\n"// /*" assign x = 8\'hFF;')
        highlighter = editor.highlighter
        highlighter.rehighlight()
        block = editor.document().firstBlock()
        self.assertEqual(block.userState(), 1)
        self.assertEqual(
            block.layout().formats()[0].format.foreground().color().name(),
            SYNTAX_COMMENT.lower(),
        )
        self.assertFalse(block.layout().formats()[0].format.fontItalic())
        block = block.next()
        formats = block.layout().formats()
        self.assertEqual(
            formats[0].format.foreground().color().name(),
            SYNTAX_COMMENT.lower(),
        )
        self.assertTrue(
            any(
                f.format.foreground().color().name() == SYNTAX_KEYWORD.lower()
                for f in formats
            )
        )
        block = block.next()
        self.assertEqual(block.userState(), 0)
        self.assertEqual(
            block.layout().formats()[0].format.foreground().color().name(),
            SYNTAX_STRING.lower(),
        )
        highlighter.set_enabled(False)
        self.assertFalse(block.layout().formats())
        path = self.file("text.txt", "module ordinary_text; endmodule")
        verilog = self.file("rtl.sv", "module rtl; endmodule")
        self.panel.set_files([path, verilog], self.root)
        wait_for_idle(self.app)
        self.assertFalse(self.panel.preview.highlighter.enabled)
        self.panel.select_file(verilog)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.preview.highlighter.enabled)
        self.assertFalse(hasattr(self.panel, "highlight_button"))
        self.panel.set_files([verilog], self.root)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.preview.highlighter.enabled)

    def test_toolbar_routes_to_selected_output_and_signals(self):
        path = self.file("rtl/source.sv", "module source; endmodule")
        editor = self.file("custom-editor", "editor")
        self.panel.editor_path_provider = lambda: str(editor)
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        with patch("subprocess.Popen") as popen:
            self.panel.open_editor_button.click()
            wait_for_idle(self.app)
            popen.assert_called_once_with([str(editor), str(path)])
        self.panel.path_button.click()
        self.assertTrue(self.panel.file_tree.isVisible())
        refresh = QtTest.QSignalSpy(self.panel.refreshRequested)
        maximize = QtTest.QSignalSpy(self.panel.maximizeRequested)
        self.panel.refresh_button.click()
        wait_for_idle(self.app)
        self.panel.maximize_button.click()
        wait_for_idle(self.app)
        self.assertEqual(len(refresh), 1)
        self.assertEqual(len(maximize), 1)
        path.unlink()
        with patch.object(QtWidgets.QMessageBox, "warning") as warning, patch("subprocess.Popen") as popen:
            self.panel.open_in_editor()
            wait_for_idle(self.app)
            warning.assert_called_once()
            popen.assert_not_called()

    def test_file_tree_blank_click_closes_overlay(self):
        path = self.file("rtl/one.sv", "module one;\nendmodule\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.path_button.click()
        wait_for_idle(self.app)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.file_tree.isVisible())

        viewport = self.panel.file_tree.viewport()
        point = QtCore.QPoint(max(1, viewport.width() - 2), max(1, viewport.height() - 2))
        if self.panel.file_tree.itemAt(point) is not None:
            point = QtCore.QPoint(max(1, viewport.width() - 2), 1)
        event = QtGui.QMouseEvent(
            QtCore.QEvent.MouseButtonPress,
            point,
            QtCore.Qt.LeftButton,
            QtCore.Qt.LeftButton,
            QtCore.Qt.NoModifier,
        )
        self.panel.eventFilter(viewport, event)
        self.assertFalse(self.panel.path_button.isChecked())
        self.assertFalse(self.panel.file_tree.isVisible())


if __name__ == "__main__":
    unittest.main()
