import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
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
        widget.close()
        widget.deleteLater()
        self.app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        self.app.processEvents()

    def file(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_complete_readonly_source_and_line_numbers(self):
        text = "module generated;\n" + "assign value = " + "0" * 250 + ";\n"
        text += "\n".join(f"// line {i}" for i in range(150)) + "\nendmodule\n"
        path = self.file("rtl/generated.sv", text)
        self.panel.set_files([path], self.root)
        self.app.processEvents()
        editor = self.panel.preview
        self.assertEqual(editor.toPlainText(), text)
        self.assertGreater(editor.horizontalScrollBar().maximum(), 0)
        self.assertEqual(editor.line_numbers.width(), editor.line_number_width())
        editor.moveCursor(QtGui.QTextCursor.End)
        QtTest.QTest.keyClicks(editor, "unexpected_edit")
        self.assertEqual(editor.toPlainText(), text)
        self.panel.copy_contents()
        self.assertEqual(QtWidgets.QApplication.clipboard().text(), text)
        self.panel.copy_path()
        self.assertEqual(QtWidgets.QApplication.clipboard().text(), str(path))

    def test_refresh_retains_selected_file_and_project_switch_clears_it(self):
        one = self.file("rtl/one.sv", "module one; endmodule")
        two = self.file("tb/two.sv", "module two; endmodule")
        self.panel.set_files([one, two], self.root)
        self.panel.select_file(two)
        two.write_text("module refreshed; endmodule", encoding="utf-8")
        self.panel.set_files([one, two], self.root)
        self.assertEqual(self.panel.current_path, two)
        self.assertIn("refreshed", self.panel.preview.toPlainText())
        self.assertEqual(self.panel.current_path.relative_to(self.root), Path("tb") / "two.sv")
        self.panel.set_files([one], self.root)
        self.assertEqual(self.panel.current_path, one)
        self.panel.set_files([], self.root / "other")
        self.assertIsNone(self.panel.current_path)
        self.assertFalse(self.panel.preview.toPlainText())
        self.assertFalse(self.panel.copy_content_action.isEnabled())
        self.assertFalse(self.panel.toolbar_buttons[2].isEnabled())

    def test_missing_binary_and_empty_files_do_not_keep_old_text(self):
        valid = self.file("good.sv", "module good; endmodule")
        missing = self.root / "missing.sv"
        binary = self.root / "binary.bin"
        binary.write_bytes(b"\xff\xfe")
        empty = self.file("empty.sv", "")
        for path in (missing, binary):
            self.panel.set_files([valid, path], self.root)
            self.panel.select_file(path)
            self.assertFalse(self.panel.preview.toPlainText())
            self.assertIn("无法读取", self.panel.status.text())
            self.assertFalse(self.panel.copy_content_action.isEnabled())
            self.panel.select_file(valid)
            self.assertEqual(self.panel.preview.toPlainText(), valid.read_text())
        self.panel.set_files([empty], self.root)
        self.assertFalse(self.panel.preview.toPlainText())
        self.assertTrue(self.panel.copy_content_action.isEnabled())
        self.assertIn("0 行", self.panel.status.text())

    def test_search_wraps_both_directions_and_reports_no_match(self):
        path = self.file("search.sv", "module match;\n// middle\nendmodule // match")
        self.panel.set_files([path], self.root)
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
        self.app.processEvents()
        QtTest.QTest.keyClick(self.panel.search_input, QtCore.Qt.Key_Escape)
        self.assertFalse(self.panel.search_bar.isVisible())
        QtTest.QTest.keyClick(self.panel.preview, QtCore.Qt.Key_F, QtCore.Qt.ControlModifier)
        self.assertTrue(self.panel.search_bar.isVisible())
        self.panel.search_input.setText("match")
        QtTest.QTest.keyClick(self.panel.search_input, QtCore.Qt.Key_F3)
        self.assertEqual(self.panel.preview.textCursor().selectionStart(), last)
        QtTest.QTest.keyClick(self.panel.search_input, QtCore.Qt.Key_Return, QtCore.Qt.ShiftModifier)
        self.assertEqual(self.panel.preview.textCursor().selectionStart(), first)

    def test_file_tree_is_layout_managed_and_closes_after_selection(self):
        one = self.file("rtl/one.sv", "module one;\nendmodule\n")
        two = self.file("tb/two.sv", "module two;\nendmodule\n")
        self.panel.set_files([one, two], self.root)
        self.panel.resize(420, 630)
        self.panel.show()
        self.app.processEvents()
        preview_geometry = QtCore.QRect(self.panel.preview.geometry())

        self.panel.tree_button.click()
        self.app.processEvents()
        self.assertTrue(self.panel.file_tree.isVisible())
        self.assertIs(self.panel.file_tree.parent(), self.panel)
        self.assertLess(self.panel.preview.height(), preview_geometry.height())
        self.assertFalse(self.panel.file_tree.geometry().intersects(self.panel.preview.geometry()))

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
        current = "module one;\nassign value = 1'b1;\nendmodule\n"
        path.write_text(current, encoding="utf-8")
        self.panel.set_files(
            [path], self.root, statuses={"rtl/one.sv": "Modified"}
        )
        self.assertTrue(self.panel.diff_button.isEnabled())
        self.panel.diff_button.click()
        diff = self.panel.preview.toPlainText()
        self.assertIn("--- previous/rtl/one.sv", diff)
        self.assertIn("+++ current/rtl/one.sv", diff)
        self.assertIn("-assign value = 1'b0;", diff)
        self.assertIn("+assign value = 1'b1;", diff)
        self.panel.diff_button.click()
        self.assertEqual(self.panel.preview.toPlainText(), current)

    def test_toolbar_compacts_without_losing_more_actions(self):
        self.panel._apply_toolbar_density(320)
        self.assertFalse(self.panel.toolbar_buttons[2].isVisible())
        self.assertFalse(self.panel.toolbar_buttons[4].isVisible())
        self.assertTrue(self.panel.toolbar_buttons[6].isVisible())
        self.assertTrue(self.panel.toolbar_buttons[7].isVisible())
        self.assertTrue(self.panel.toolbar_buttons[8].isVisible())
        labels = [action.text() for action in self.panel.more_menu.actions()]
        self.assertIn("在编辑器中打开", labels)
        self.assertIn("搜索当前文件", labels)
        self.assertIn("显示/隐藏文件树", labels)
        self.panel._apply_toolbar_density(700)
        self.assertTrue(self.panel.toolbar_buttons[2].isVisible())
        self.assertTrue(self.panel.toolbar_buttons[4].isVisible())
        self.assertTrue(self.panel.diff_button.isVisible())

    def test_verilog_highlight_multiline_comments_strings_and_toggle(self):
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
        self.assertTrue(block.layout().formats()[0].format.fontItalic())
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
        self.assertFalse(self.panel.preview.highlighter.enabled)
        self.panel.select_file(verilog)
        self.assertTrue(self.panel.preview.highlighter.enabled)
        self.panel.highlight_button.click()
        self.assertFalse(self.panel.preview.highlighter.enabled)
        self.panel.set_files([verilog], self.root)
        self.assertFalse(self.panel.preview.highlighter.enabled)

    def test_toolbar_routes_to_selected_output_and_signals(self):
        path = self.file("rtl/source.sv", "module source; endmodule")
        editor = self.file("custom-editor", "editor")
        self.panel.editor_path_provider = lambda: str(editor)
        self.panel.set_files([path], self.root)
        with patch("subprocess.Popen") as popen:
            self.panel.toolbar_buttons[2].click()
            popen.assert_called_once_with([str(editor), str(path)])
        with patch("plm.frontend.qt.views.artifacts_panel.open_in_file_manager", return_value=True) as opened:
            self.panel.toolbar_buttons[0].click()
            opened.assert_called_once_with(path.parent)
        refresh = QtTest.QSignalSpy(self.panel.refreshRequested)
        maximize = QtTest.QSignalSpy(self.panel.maximizeRequested)
        self.panel.toolbar_buttons[1].click()
        self.panel.toolbar_buttons[8].click()
        self.assertEqual(len(refresh), 1)
        self.assertEqual(len(maximize), 1)
        path.unlink()
        with patch.object(QtWidgets.QMessageBox, "warning") as warning, patch("subprocess.Popen") as popen:
            self.panel.open_in_editor()
            warning.assert_called_once()
            popen.assert_not_called()

    def test_file_tree_blank_click_closes_overlay(self):
        path = self.file("rtl/one.sv", "module one;\nendmodule\n")
        self.panel.set_files([path], self.root)
        self.panel.tree_button.click()
        self.app.processEvents()
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
        self.assertFalse(self.panel.tree_button.isChecked())
        self.assertFalse(self.panel.file_tree.isVisible())


if __name__ == "__main__":
    unittest.main()
