"""Regression checks that UI tests respect caller-owned state and resources."""

import importlib
import os
import subprocess
import sys
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets, sip
from plm.core import verible
from plm.frontend.qt.services.tasks import TaskRunner
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state,
    wait_for_signal,
)


class QtTestIsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        preserve_application_state(self, self.app)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))

    def run_case(self, module_name, class_name, method):
        module = importlib.import_module(module_name)
        case = getattr(module, class_name)(method)
        result = unittest.TestResult()
        unittest.TestSuite([case]).run(result)
        self.assertEqual(result.testsRun, 1)
        self.assertTrue(result.wasSuccessful(), result.errors + result.failures)

    def test_ui_suite_preserves_existing_widgets_and_application_preferences(self):
        self.app.setStyle("Fusion")
        self.app.setFont(QtGui.QFont("Arial", 12))
        self.app.setStyleSheet("QWidget { color: #123456; }")
        self.app.clipboard().setText("caller-owned clipboard text")
        owned_by_caller = QtWidgets.QWidget()
        before = (
            self.app.font().toString(), QtGui.QPalette(self.app.palette()),
            self.app.styleSheet(), sys.excepthook, self.app.clipboard().text(),
            QtGui.QFontDatabase().families(),
        )

        self.run_case(
            "test_qt_frontend", "QtFrontendLayoutTests",
            "test_artifact_file_selection_and_copy_path",
        )

        self.assertFalse(sip.isdeleted(owned_by_caller))
        self.assertEqual(self.app.font().toString(), before[0])
        self.assertEqual(self.app.palette(), before[1])
        self.assertEqual(self.app.styleSheet(), before[2])
        self.assertIs(sys.excepthook, before[3])
        self.assertEqual(self.app.clipboard().text(), before[4])
        self.assertEqual(QtGui.QFontDatabase().families(), before[5])

    def test_restored_behavior_suite_uses_explicit_project_and_settings_stores(self):
        # Default stores discover user workspaces and write native user settings.
        # Catch any accidental fallback without touching those real resources.
        with patch(
            "plm.frontend.qt.controllers.app_controller.SettingsStore",
            side_effect=AssertionError("UI test reached native user settings"),
        ), patch(
            "plm.frontend.qt.controllers.app_controller.ProjectService",
            side_effect=AssertionError("UI test reached editable user samples"),
        ):
            self.run_case(
                "test_qt_restored_behaviors", "QtRestoredBehaviorTests",
                "test_settings_and_docs_use_stacked_page_routing",
            )

    def test_formatter_isolation_lasts_through_worker_callbacks_then_restores(self):
        source = "module demo; endmodule\n"
        owner = unittest.TestCase()
        self.addCleanup(owner.doCleanups)
        widget = QtWidgets.QWidget()
        runner = TaskRunner(widget)
        results, errors, callback_lookup = [], [], []
        original_lookup = verible.find_verible

        with patch.object(
            verible, "find_verible", return_value="machine-formatter.bat"
        ) as host_lookup, patch.object(
            verible.subprocess, "run",
            side_effect=AssertionError("isolated worker reached host formatter"),
        ) as run:
            isolate_host_formatter(owner, self.app)

            def completed(result):
                results.append(result)
                callback_lookup.append(verible.find_verible())

            runner.submit(lambda _progress: verible.format_sv(source), completed, errors.append)
            self.assertTrue(owner.doCleanups())

            self.assertEqual(results, [source])
            self.assertEqual(callback_lookup, [None])
            self.assertEqual(errors, [])
            self.assertEqual(runner._tasks, {})
            run.assert_not_called()
            host_lookup.assert_not_called()
            self.assertIs(verible.find_verible, host_lookup)

        self.assertIs(verible.find_verible, original_lookup)

    def test_formatter_isolation_preserves_explicit_paths_and_nested_mocks(self):
        owner = unittest.TestCase()
        self.addCleanup(owner.doCleanups)
        isolate_host_formatter(owner, self.app)
        source = "module demo; endmodule\n"

        def formatter(args, **kwargs):
            return subprocess.CompletedProcess(args, 0, stdout=kwargs["input"], stderr=b"")

        with patch.object(verible.subprocess, "run", side_effect=formatter) as run:
            for path in ("tool with spaces/formatter.exe", "missing.exe", "custom-formatter"):
                with self.subTest(path=path):
                    self.assertEqual(verible.format_sv(source, path, {}), source)
                    self.assertEqual(run.call_args.args[0], [path, "--inplace", "-"])

            with patch.object(verible, "find_verible", return_value="dedicated-mock"):
                self.assertEqual(verible.format_sv(source, verible_flags={}), source)
                self.assertEqual(run.call_args.args[0], ["dedicated-mock", "--inplace", "-"])

        self.assertIsNone(verible.find_verible())


    def test_signal_wait_accepts_a_signal_delivered_before_the_wait(self):
        timer = QtCore.QTimer()
        spy = QtTest.QSignalSpy(timer.timeout)
        timer.timeout.emit()
        wait_for_signal(spy)
        self.assertEqual(len(spy), 1)

    def test_signal_wait_processes_a_queued_signal(self):
        timer = QtCore.QTimer()
        spy = QtTest.QSignalSpy(timer.timeout)
        QtCore.QTimer.singleShot(0, timer.timeout.emit)
        wait_for_signal(spy)
        self.assertEqual(len(spy), 1)

    def test_signal_wait_reports_a_missing_signal(self):
        timer = QtCore.QTimer()
        spy = QtTest.QSignalSpy(timer.timeout)
        with self.assertRaisesRegex(AssertionError, "did not arrive within 10 ms"):
            wait_for_signal(spy, timeout=10)


if __name__ == "__main__":
    unittest.main()
