"""Release widgets owned by a test, including their native Qt resources."""

from PyQt5 import QtCore, QtWidgets


def dispose_new_widgets(app, existing):
    for widget in app.topLevelWidgets():
        if widget in existing:
            continue
        # Avoid unsaved-change prompts during fixture cleanup.
        if hasattr(widget, "config_page"):
            widget.config_page.mark_saved()
        widget.close()
        widget.deleteLater()
    QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
