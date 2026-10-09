"""Deterministic checks for superseded read-only Qt worker requests."""

import os
import threading
import time
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets

from plm.frontend.qt.services.tasks import TaskCancelled, TaskRunner


class TaskCoalescingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.runner = TaskRunner()
        self.releases = []

    def tearDown(self):
        for release in self.releases:
            release.set()
        self.wait_until(lambda: not self.runner._tasks)
        self.runner.deleteLater()
        self.app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)

    def release_event(self):
        release = threading.Event()
        self.releases.append(release)
        return release

    def wait_until(self, predicate):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            self.app.processEvents()
            if predicate():
                return
            QtTest.QTest.qWait(1)
        self.fail("Worker callbacks did not reach the expected state")

    def test_latest_requests_keep_one_running_and_only_the_newest_pending(self):
        started = threading.Event()
        release = self.release_event()
        executed, completed, failed, progress, cancelled = [], [], [], [], []

        def original(report):
            executed.append("original")
            report(10, "queued before supersession")
            started.set()
            if not release.wait(3):
                raise RuntimeError("Original worker was not released")
            try:
                report(90, "obsolete progress")
            except TaskCancelled:
                cancelled.append(True)
            return "obsolete result"

        self.runner.submit_latest(
            "preview", original, completed.append, failed.append,
            lambda percent, message: progress.append((percent, message)),
        )
        self.assertTrue(started.wait(2))
        for request in range(1, 10):
            def operation(report, current=request):
                executed.append(current)
                report(100, f"request {current}")
                return current

            self.runner.submit_latest(
                "preview", operation, completed.append, failed.append,
                lambda percent, message: progress.append((percent, message)),
            )
            self.assertEqual(len(self.runner._tasks), 2)
            self.assertEqual(len(self.runner._pending), 1)

        self.app.processEvents()
        self.assertEqual(executed, ["original"])
        self.assertEqual(progress, [])
        release.set()
        self.wait_until(lambda: not self.runner._tasks)
        self.assertEqual(executed, ["original", 9])
        self.assertEqual(completed, [9])
        self.assertEqual(failed, [])
        self.assertEqual(progress, [(100, "request 9")])
        self.assertEqual(cancelled, [True])
        self.assertEqual(self.runner._latest, {})
        self.assertEqual(self.runner._pending, {})
        self.assertEqual(self.runner._task_keys, {})

    def test_obsolete_failure_does_not_block_the_latest_request(self):
        started = threading.Event()
        release = self.release_event()
        completed, failed = [], []

        def original(_report):
            started.set()
            if not release.wait(3):
                raise RuntimeError("Original worker was not released")
            raise RuntimeError("obsolete failure")

        self.runner.submit_latest("diff", original, completed.append, failed.append)
        self.assertTrue(started.wait(2))
        self.runner.submit_latest(
            "diff", lambda _report: "current diff", completed.append, failed.append
        )
        release.set()
        self.wait_until(lambda: not self.runner._tasks)
        self.assertEqual(completed, ["current diff"])
        self.assertEqual(failed, [])

    def test_cancel_latest_removes_pending_and_suppresses_running_callbacks(self):
        started = threading.Event()
        release = self.release_event()
        executed, completed, failed, progress = [], [], [], []

        def original(report):
            executed.append("original")
            report(10, "queued")
            started.set()
            if not release.wait(3):
                raise RuntimeError("Original worker was not released")
            return "obsolete"

        self.runner.submit_latest(
            "scan", original, completed.append, failed.append,
            lambda *values: progress.append(values),
        )
        self.assertTrue(started.wait(2))
        self.runner.submit_latest(
            "scan", lambda _report: executed.append("pending"),
            completed.append, failed.append,
        )
        self.runner.cancel_latest("scan")
        release.set()
        self.wait_until(lambda: not self.runner._tasks)
        self.assertEqual(executed, ["original"])
        self.assertEqual(completed, [])
        self.assertEqual(failed, [])
        self.assertEqual(progress, [])

    def test_regular_submit_runs_every_request(self):
        executed, completed, failed = [], [], []
        for request in range(6):
            def operation(_report, current=request):
                executed.append(current)
                return current

            self.runner.submit(operation, completed.append, failed.append)
        self.wait_until(lambda: not self.runner._tasks)
        self.assertCountEqual(executed, range(6))
        self.assertCountEqual(completed, range(6))
        self.assertEqual(failed, [])


if __name__ == "__main__":
    unittest.main()
