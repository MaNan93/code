import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.widgets.code_preview import CodePreview


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
        self.addCleanup(self.panel.close)

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
        self.panel.file_selector.setCurrentIndex(1)
        two.write_text("module refreshed; endmodule", encoding="utf-8")
        self.panel.set_files([one, two], self.root)
        self.assertEqual(self.panel.current_path, two)
        self.assertIn("refreshed", self.panel.preview.toPlainText())
        self.assertEqual(self.panel.file_selector.currentText(), "tb/two.sv")
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
            self.panel.file_selector.setCurrentIndex(1)
            self.assertFalse(self.panel.preview.toPlainText())
            self.assertIn("无法读取", self.panel.status.text())
            self.assertFalse(self.panel.copy_content_action.isEnabled())
            self.panel.file_selector.setCurrentIndex(0)
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

    def test_verilog_highlight_multiline_comments_strings_and_toggle(self):
        editor = CodePreview()
        self.addCleanup(editor.close)
        editor.setPlainText('/* module\nendmodule */ module x; // endmodule\n"// /*" assign x = 8\'hFF;')
        highlighter = editor.highlighter
        highlighter.rehighlight()
        block = editor.document().firstBlock()
        self.assertEqual(block.userState(), 1)
        self.assertEqual(block.layout().formats()[0].format.foreground().color().name(), "#6a737d")
        block = block.next()
        formats = block.layout().formats()
        self.assertEqual(formats[0].format.foreground().color().name(), "#6a737d")
        self.assertTrue(any(f.format.foreground().color().name() == "#d73a49" for f in formats))
        block = block.next()
        self.assertEqual(block.userState(), 0)
        self.assertEqual(block.layout().formats()[0].format.foreground().color().name(), "#032f62")
        highlighter.set_enabled(False)
        self.assertFalse(block.layout().formats())
        path = self.file("text.txt", "module ordinary_text; endmodule")
        verilog = self.file("rtl.sv", "module rtl; endmodule")
        self.panel.set_files([path, verilog], self.root)
        self.assertFalse(self.panel.preview.highlighter.enabled)
        self.panel.file_selector.setCurrentIndex(1)
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


if __name__ == "__main__":
    unittest.main()
