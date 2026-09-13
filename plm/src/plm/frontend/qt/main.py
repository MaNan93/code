#!/usr/bin/env python3
"""
plm-qt -- PIPE Lane Mapper config editor + generator, PyQt5 desktop front end.

Run: python3 -m plm.frontend.qt.main
(or, once installed: plm-qt)
"""

import sys
from pathlib import Path

try:
    from PyQt5 import QtCore, QtGui, QtWidgets
except ImportError:
    sys.exit(
        "plm-qt needs PyQt5. Install it with:\n"
        '    pip install "plm[qt]"\n'
        "(or, offline, transfer the PyQt5/PyQt5-sip wheels to this machine and pip install those)."
    )

from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.widgets.theme import STYLESHEET, apply_titlebar_theme

APP_ICON_PATH = Path(__file__).resolve().parent.parent / "web" / "static" / "mario_icon.png"


def main():
    if hasattr(QtCore.Qt, "AA_EnableHighDpiScaling"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    if hasattr(QtCore.Qt, "AA_UseHighDpiPixmaps"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    app = QtWidgets.QApplication(sys.argv)
    app.setApplicationName("plmConsultant")
    if APP_ICON_PATH.is_file():
        # Set on the app, not just the main window, so every top-level
        # window/dialog (Settings, Documentation, ...) that doesn't set
        # its own icon inherits this one for free.
        app.setWindowIcon(QtGui.QIcon(str(APP_ICON_PATH)))
    # Custom QSS on QTabBar/QPushButton/etc. renders inconsistently (tabs
    # overlapping, buttons losing their box) under whichever native style
    # (windowsvista, GTK, ...) is active by default -- each native style
    # bakes in its own tab-overlap/button-chrome metrics that generic QSS
    # doesn't fully override. Fusion is Qt's own style, built to be styled,
    # so switching to it before applying the stylesheet is what makes the
    # QSS below render the way it's written rather than fighting the
    # platform style underneath it.
    app.setStyle("Fusion")
    # Set a real UI font before building any widget, not just inside
    # MainWindow._apply_font() -- QApplication's own untouched default
    # font is locale-dependent (on a Chinese-locale Windows install it
    # can resolve to SimSun, a legacy bitmap CJK font, even for an
    # English UI), and every widget built against that default bakes in
    # its bad metrics at construction time. Setting this first means
    # MainWindow's own _apply_font() call later is just adjusting size,
    # not recovering from an already-wrong family.
    app.setFont(QtGui.QFont("Segoe UI", 13))
    app.setStyleSheet(STYLESHEET)
    win = MainWindow()
    apply_titlebar_theme(win)
    win.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
