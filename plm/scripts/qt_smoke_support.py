"""Wait for queued GUI work before asserting or capturing smoke-test results."""

import time

from PyQt5 import QtCore, QtTest
from plm.frontend.qt.services.tasks import TaskRunner


def wait_for_idle(app, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        app.processEvents()
        widgets = app.topLevelWidgets()
        runners = [runner for widget in widgets for runner in widget.findChildren(TaskRunner)]
        timers = [timer for widget in widgets for timer in widget.findChildren(QtCore.QTimer)
                  if timer.isSingleShot() and timer.isActive()]
        if not any(runner._tasks for runner in runners) and not timers:
            return
        QtTest.QTest.qWait(5)
    raise AssertionError("GUI background work did not finish before the smoke-test timeout")


def dispose_window(app, window):
    """Finish queued work before releasing the smoke test's native resources."""
    wait_for_idle(app)
    if hasattr(window, "config_page"):
        window.config_page.mark_saved()
    window.close()
    window.deleteLater()
    QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
    QtCore.QThreadPool.globalInstance().waitForDone(10000)
    app.processEvents()
