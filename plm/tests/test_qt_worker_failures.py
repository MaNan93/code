"""Worker exceptions release keys, and the GUI entry point drains its pool."""

import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import Mock, patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets
from plm.frontend.qt.services.tasks import TaskRunner


class WorkerLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.runner = TaskRunner()
        self.release = threading.Event()

    def tearDown(self):
        self.release.set()
        self.wait_until(lambda: not self.runner._tasks)
        self.runner.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)

    def wait_until(self, predicate):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            self.app.processEvents()
            if predicate():
                return
            QtTest.QTest.qWait(1)
        self.fail("Worker lifecycle did not settle")

    def test_base_exceptions_report_failure_and_release_the_task(self):
        for exception in (SystemExit("invalid configuration"), KeyboardInterrupt()):
            failures = []

            def fail(_progress):
                raise exception

            self.runner.submit(fail, lambda _result: None, failures.append)
            self.wait_until(lambda: not self.runner._tasks)
            self.assertEqual(failures, [exception])

    def test_superseded_base_exception_releases_the_latest_pending_request(self):
        started = threading.Event()
        completed, failed = [], []

        def fail_after_release(_progress):
            started.set()
            self.release.wait(2)
            raise SystemExit("obsolete configuration")

        self.runner.submit_latest("read", fail_after_release, completed.append, failed.append)
        self.assertTrue(started.wait(1))
        self.runner.submit_latest("read", lambda _progress: "new config", completed.append, failed.append)
        self.release.set()
        self.wait_until(lambda: not self.runner._tasks)
        self.assertEqual(completed, ["new config"])
        self.assertEqual(failed, [])
        self.assertEqual(self.runner._latest, {})
        self.assertEqual(self.runner._pending, {})

    def test_gui_entry_point_waits_for_running_workers_when_its_loop_returns(self):
        from plm.frontend.qt import main as gui

        started, finished = threading.Event(), threading.Event()
        callbacks = []

        def work(_progress):
            started.set()
            self.release.wait(2)
            finished.set()

        def run_loop():
            self.runner.submit(work, callbacks.append, callbacks.append)
            self.assertTrue(started.wait(1))
            timer = threading.Timer(0.02, self.release.set)
            timer.start()
            self.addCleanup(timer.join)
            return 17

        application = Mock()
        application.exec_.side_effect = run_loop
        with patch.object(gui.QtWidgets, "QApplication", return_value=application), patch.object(gui, "MainWindow"):
            self.assertEqual(gui.main([]), 17)
        self.assertTrue(finished.is_set(), "Entry point returned with worker Python code still running")
        self.wait_until(lambda: not self.runner._tasks)
        self.assertEqual(callbacks, [None])

    def test_natural_window_close_does_not_hang_with_a_worker_in_flight(self):
        script = '''
import threading
import time
from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt import main as gui
from plm.frontend.qt.services.tasks import TaskRunner

class Window(QtWidgets.QWidget):
    def __init__(self):
        super().__init__()
        self.started = threading.Event()
        self.tasks = TaskRunner(self)
        self.tasks.submit(self.work, lambda result: None, lambda error: None)
        QtCore.QTimer.singleShot(10, self.close_when_started)

    def work(self, report):
        self.started.set()
        time.sleep(0.25)
        report(100, "done")
        print("WORKER_FINISHED", flush=True)

    def close_when_started(self):
        if self.started.is_set():
            self.close()
        else:
            QtCore.QTimer.singleShot(10, self.close_when_started)

gui.MainWindow = Window
print("MAIN_RESULT", gui.main([]), flush=True)
'''
        environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", PYTHONNOUSERSITE="1")
        environment.pop("PYTHONHOME", None)
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [sys.executable, "-X", "faulthandler", "-c", script],
                cwd=directory, env=environment, capture_output=True, text=True, timeout=15,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("WORKER_FINISHED", result.stdout)
        self.assertIn("MAIN_RESULT 0", result.stdout)
        self.assertLess(result.stdout.index("WORKER_FINISHED"), result.stdout.index("MAIN_RESULT 0"))


if __name__ == "__main__":
    unittest.main()
