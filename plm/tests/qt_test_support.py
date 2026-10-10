"""Isolate UI tests from host tools and restore caller-owned Qt resources."""

import time
import sys
import os
from pathlib import Path
from unittest.mock import patch

from PyQt5 import QtCore, QtGui, QtTest
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.widgets.common import ContentIconStyle


def isolate_host_formatter(owner, app):
    """Use no implicit formatter in UI tests; keep explicit paths testable.

    Register this before widget/temp-directory cleanups so their workers still
    see the same formatter identity while draining. A nested formatter mock
    can override this patch in a dedicated formatter test.
    """
    patcher = patch(
        "plm.core.verible.find_verible",
        side_effect=lambda verible_path=None: verible_path or None,
    )
    patcher.start()

    def restore():
        try:
            wait_for_idle(app)
        finally:
            patcher.stop()

    owner.addCleanup(restore)


def preserve_application_state(owner, app):
    """Restore application preferences and the callback hook after a test scope."""
    register = owner.addClassCleanup if isinstance(owner, type) else owner.addCleanup
    # The Windows offscreen plugin starts without a font database. Without
    # real fonts, text-painting tests can pass while every label renders blank.
    # Borrow installed fonts for this scope and remove only those we added.
    if not QtGui.QFontDatabase().families():
        font_directory = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"
        for filename in ("segoeui.ttf", "consola.ttf"):
            path = font_directory / filename
            if path.is_file():
                font_id = QtGui.QFontDatabase.addApplicationFont(str(path))
                if font_id >= 0:
                    register(QtGui.QFontDatabase.removeApplicationFont, font_id)
    font = QtGui.QFont(app.font())
    palette = QtGui.QPalette(app.palette())
    stylesheet = app.styleSheet()
    exception_hook = sys.excepthook
    clipboard = app.clipboard()
    clipboard_data = clipboard.mimeData()
    saved_clipboard = {
        name: bytes(clipboard_data.data(name)) for name in clipboard_data.formats()
    } if clipboard_data is not None else {}
    # A stylesheet wraps the actual style in an unnamed QStyleSheetStyle.
    # Read the underlying style so restoring does not silently switch themes.
    if stylesheet:
        app.setStyleSheet("")
    style = app.style()
    has_content_icons = isinstance(style, ContentIconStyle)
    if has_content_icons:
        style = style.baseStyle()
    style_name = style.objectName() or "Fusion"
    if stylesheet:
        app.setStyleSheet(stylesheet)
        app.setFont(font)
        app.setPalette(palette)

    def restore():
        app.setStyleSheet("")
        app.setStyle(ContentIconStyle(style_name) if has_content_icons else style_name)
        app.setFont(font)
        app.setPalette(palette)
        app.setStyleSheet(stylesheet)
        if saved_clipboard:
            data = QtCore.QMimeData()
            for name, contents in saved_clipboard.items():
                data.setData(name, contents)
            clipboard.setMimeData(data)
        else:
            clipboard.clear()
        sys.excepthook = exception_hook

    register(restore)


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


def wait_for_signal(spy, timeout=2000):
    """Accept an already delivered signal before waiting for a future one."""
    if not spy and not spy.wait(timeout):
        raise AssertionError(f"Expected Qt signal did not arrive within {timeout} ms")


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
