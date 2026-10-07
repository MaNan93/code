"""Release widgets owned by a test, including their native Qt resources."""

import time

from PyQt5 import QtCore, QtTest, QtWidgets
from plm.frontend.qt.services.tasks import TaskRunner


def wait_for_idle(app, timeout=10000):
    """Pump real queued worker callbacks and debounced validation in tests."""
    deadline = time.monotonic() + timeout / 1000
    while time.monotonic() < deadline:
        app.processEvents()
        widgets = app.topLevelWidgets()
        runners = [
            runner for widget in widgets for runner in widget.findChildren(TaskRunner)
        ]
        timers = [
            timer for widget in widgets for timer in widget.findChildren(QtCore.QTimer)
            if timer.isSingleShot() and timer.isActive()
        ]
        if not any(runner._tasks for runner in runners) and not timers:
            return
        QtTest.QTest.qWait(5)
    raise AssertionError("Qt workers or debounced callbacks did not finish within 10 seconds")


def dispose_new_widgets(app, existing):
    wait_for_idle(app)
    for widget in app.topLevelWidgets():
        if widget in existing:
            continue
        # Avoid unsaved-change prompts during fixture cleanup.
        if hasattr(widget, "config_page"):
            widget.config_page.mark_saved()
        widget.close()
        widget.deleteLater()
    QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
