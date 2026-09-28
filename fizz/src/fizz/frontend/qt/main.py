#!/usr/bin/env python3
"""
fizz -- Qt desktop front end for the SV merge / VCS Protect / Obfuscator /
RLskit / post-sim toolkit.

Run: fizz
"""

import sys

try:
    from PyQt5 import QtCore, QtGui, QtWidgets
except ImportError:
    sys.exit(
        "fizz needs PyQt5. Install it with:\n"
        '    pip install "fizz[qt]"\n'
        "(or, offline, transfer the PyQt5/PyQt5-sip wheels to this machine and pip install those)."
    )

from fizz.frontend.qt.main_window import MainWindow
from fizz.frontend.qt.widgets.theme import apply_titlebar_theme, build_stylesheet


def main(argv=None):
    if hasattr(QtCore.Qt, "AA_EnableHighDpiScaling"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    if hasattr(QtCore.Qt, "AA_UseHighDpiPixmaps"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    argv = sys.argv[1:] if argv is None else list(argv)
    app = QtWidgets.QApplication([sys.argv[0], *argv])
    app.setApplicationName("fizz")
    # See plm.frontend.qt.main for why Fusion + an explicit font are set
    # before the stylesheet: the QSS is authored against Fusion's metrics,
    # and the platform default font can silently be a legacy CJK bitmap
    # face on a Chinese-locale Windows install.
    app.setStyle("Fusion")
    app.setFont(QtGui.QFont("Segoe UI", 13))
    app.setStyleSheet(build_stylesheet())
    win = MainWindow()
    apply_titlebar_theme(win)
    win.show()
    return app.exec_()


if __name__ == "__main__":
    sys.exit(main())
