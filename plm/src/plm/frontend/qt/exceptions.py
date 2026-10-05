"""Report uncaught Qt callback errors without terminating the event loop."""

import logging
import sys

from PyQt5 import QtWidgets


def report_exception(kind, error, traceback):
    logging.getLogger(__name__).error(
        "Unhandled Qt callback error", exc_info=(kind, error, traceback)
    )
    try:
        window = QtWidgets.QApplication.activeWindow()
        if window is not None and hasattr(window, "log_panel"):
            window.log_panel.append_log(f"界面操作失败：{error}")
    except Exception:
        logging.getLogger(__name__).exception("Cannot display callback error")


def install_exception_handler():
    sys.excepthook = report_exception
