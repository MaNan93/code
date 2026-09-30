#!/usr/bin/env python3
"""
plm -gui -- PIPE Lane Mapper config editor and generator.

Run: python run.py -gui
(or, once installed: plm -gui)
"""

import sys

try:
    from PyQt5 import QtCore, QtGui, QtWidgets
except ImportError:
    sys.exit(
        "plm -gui needs PyQt5. Install it with:\n"
        '    pip install "plm[qt]"\n'
        "(or, offline, transfer the PyQt5/PyQt5-sip wheels to this machine and pip install those)."
    )

from plm.frontend.qt.main_window import APP_ICON_PATH, APP_QSS, MainWindow


def main(argv=None):
    if hasattr(QtCore.Qt, "AA_EnableHighDpiScaling"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    if hasattr(QtCore.Qt, "AA_UseHighDpiPixmaps"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    argv = sys.argv[1:] if argv is None else list(argv)
    app = QtWidgets.QApplication([sys.argv[0], *argv])
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
    font = QtGui.QFont()
    font.setFamily("Microsoft YaHei UI")
    font.setStyleStrategy(QtGui.QFont.PreferAntialias)
    font.setHintingPreference(QtGui.QFont.PreferFullHinting)
    app.setFont(font)
    # Built here rather than imported as a constant: the sheet names the
    # vendored "72" family, and fonts can only be registered once a
    # QApplication exists.
    app.setStyleSheet(APP_QSS)
    win = MainWindow()
    win.show()
    return app.exec_()


if __name__ == "__main__":
    sys.exit(main())
