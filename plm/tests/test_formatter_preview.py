"""A real formatter contract with asynchronous, snapshot-based UI previews."""

import os
import subprocess
import threading
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets
from plm.core.verible import format_sv
from plm.frontend.qt.views.formatter_preview import FormatterPreview, SAMPLES
from plm.frontend.qt.views.settings_page import SettingsPage
from qt_test_support import dispose_new_widgets, preserve_application_state, wait_for_idle


class StrictFormatterTests(unittest.TestCase):
    def test_failure_is_reported_for_preview_and_still_falls_back_for_generation(self):
        source = "module sample; endmodule\n"
        cases = ((1, b"", b"invalid option"), (0, b"", b""),
                 (0, b"module changed; endmodule\n", b""))
        for code, output, error in cases:
            with self.subTest(code=code, output=output), patch(
                    "plm.core.verible.subprocess.run",
                    return_value=subprocess.CompletedProcess([], code, output, error)):
                self.assertEqual(format_sv(source, "formatter.exe"), source)
                with self.assertRaises(ValueError):
                    format_sv(source, "formatter.exe", strict=True)

    def test_missing_tool_and_timeout_are_reported(self):
        with patch("plm.core.verible.find_verible", return_value=None):
            with self.assertRaises(OSError):
                format_sv("module sample; endmodule", strict=True)
        with patch("plm.core.verible.subprocess.run", side_effect=subprocess.TimeoutExpired([], 3)) as run:
            with self.assertRaises(subprocess.TimeoutExpired):
                format_sv("module sample; endmodule", "formatter.exe", strict=True, timeout=3)
            self.assertEqual(run.call_args.kwargs["timeout"], 3)

    def test_preview_checks_string_tokens_and_sends_unsaved_flags(self):
        text = 'module sample; initial $display("a b"); endmodule\n'
        with patch("plm.core.verible.subprocess.run", return_value=subprocess.CompletedProcess(
                [], 0, text.replace('"a b"', '"ab"').encode(), b"")):
            with self.assertRaises(ValueError):
                format_sv(text, "formatter.exe", {"column_limit": "87"}, strict=True)
        formatted = text.replace("; initial", ";\n  initial")
        with patch("plm.core.verible.subprocess.run", return_value=subprocess.CompletedProcess(
                [], 0, formatted.encode(), b"")) as run:
            self.assertEqual(format_sv(text, "formatter.exe", {"column_limit": "87"}, strict=True), formatted)
            self.assertIn("--column_limit=87", run.call_args.args[0])
            self.assertEqual(run.call_args.kwargs["input"], text.encode())


class FormatterPreviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        preserve_application_state(self, self.app)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))

    def test_opening_preview_uses_unsaved_options_without_saving_preferences(self):
        with patch("plm.frontend.qt.views.settings_page.find_verible", return_value=None), patch(
                "plm.frontend.qt.views.formatter_preview.format_sv", side_effect=lambda text, *_a, **_kw: text) as format:
            page = SettingsPage(preferences={"verible_path": "formatter.exe"})
            page.show()
            page.menu_buttons[1].click()
            page._flag_controls["column_limit"].setText("87")
            saved = QtTest.QSignalSpy(page.preferencesSaved)
            page.formatter_mode.setCurrentIndex(1)
            wait_for_idle(self.app)
            self.assertEqual(format.call_args.args[2]["column_limit"], "87")
            self.assertEqual(page.formatter_preview.result.toPlainText(), SAMPLES[0][1])
            self.assertEqual(len(saved), 0)

    def test_rapid_edits_are_debounced_and_run_off_the_gui_thread(self):
        threads = []
        def format(text, *_args, **_kwargs):
            threads.append(QtCore.QThread.currentThread())
            return text
        with patch("plm.frontend.qt.views.formatter_preview.format_sv", side_effect=format) as format_mock:
            preview = FormatterPreview()
            preview.show()
            for width in (80, 90, 100):
                preview.set_options("formatter.exe", {"column_limit": str(width)})
            wait_for_idle(self.app)
            self.assertEqual(format_mock.call_count, 1)
            self.assertEqual(format_mock.call_args.args[2]["column_limit"], "100")
            self.assertIsNot(threads[0], self.app.thread())

    def test_stale_worker_cannot_replace_a_newer_preview(self):
        started, release = threading.Event(), threading.Event()
        def format(text, *_args, **_kwargs):
            if text == SAMPLES[0][1]:
                started.set()
                if not release.wait(2):
                    raise TimeoutError("test did not release formatter")
            return text
        with patch("plm.frontend.qt.views.formatter_preview.format_sv", side_effect=format):
            preview = FormatterPreview()
            preview.show()
            preview.timer.stop()
            preview._submit()
            try:
                self.assertTrue(started.wait(1))
                preview.source.setPlainText("module newer; endmodule\n")
                preview.timer.stop()
                preview._submit()
            finally:
                release.set()
            wait_for_idle(self.app)
            self.assertEqual(preview.result.toPlainText(), "module newer; endmodule\n")

    def test_invalid_flags_and_failed_process_clear_the_previous_result(self):
        with patch("plm.frontend.qt.views.formatter_preview.format_sv", side_effect=lambda text, *_a, **_kw: text):
            preview = FormatterPreview()
            preview.show()
            wait_for_idle(self.app)
            self.assertTrue(preview.result.toPlainText())
        with patch("plm.frontend.qt.views.formatter_preview.format_sv", side_effect=OSError("missing tool")):
            preview.set_options("missing.exe", {})
            wait_for_idle(self.app)
            self.assertEqual(preview.result.toPlainText(), "")
            self.assertIn("missing tool", preview.status.text())
        with patch("plm.frontend.qt.views.formatter_preview.format_sv") as format:
            preview.set_options("formatter.exe", {"column_limit": "invalid"})
            wait_for_idle(self.app)
            self.assertIn("column_limit", preview.status.text())
            format.assert_not_called()

    def test_save_reveals_an_invalid_parameter_hidden_by_preview_and_filter(self):
        with patch("plm.frontend.qt.views.settings_page.find_verible", return_value=None), patch.object(
                QtWidgets.QMessageBox, "warning"):
            page = SettingsPage()
            page.show()
            page.menu_buttons[1].click()
            page._flag_controls["column_limit"].setText("invalid")
            page.formatter_group.setCurrentIndex(1)
            page.formatter_mode.setCurrentIndex(1)
            saved = QtTest.QSignalSpy(page.preferencesSaved)
            page.save_settings_btn.click()
            wait_for_idle(self.app)
            self.assertEqual(page.formatter_mode.currentIndex(), 0)
            self.assertEqual(page.formatter_search.text(), "column_limit")
            self.assertTrue(page._flag_controls["column_limit"].isVisible())
            self.assertEqual(len(saved), 0)


if __name__ == "__main__":
    unittest.main()
