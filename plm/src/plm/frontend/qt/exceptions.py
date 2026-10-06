"""Report uncaught Qt callback errors without terminating the event loop."""

import logging
import sys

from PyQt5 import QtWidgets


def report_exception(kind, error, traceback):
    logging.getLogger(__name__).error(
        "Unhandled Qt callback error", exc_info=(kind, error, traceback)
    )
    try:
        app = QtWidgets.QApplication.instance()
        if app is None:
            return
        window = app.activeWindow()
        while window is not None and not hasattr(window, "log_panel"):
            window = window.parentWidget()
        if window is None:
            window = next((widget for widget in app.topLevelWidgets()
                           if widget.isVisible() and hasattr(widget, "log_panel")), None)
        if window is not None:
            window.log_panel.append_log(f"界面操作失败：{error}")
    except Exception:
        logging.getLogger(__name__).exception("Cannot display callback error")


def install_exception_handler():
    sys.excepthook = report_exception
