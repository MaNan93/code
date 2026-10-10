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
from fizz.frontend.qt.styles import APP_QSS
from fizz.frontend.qt.styles.tokens import FONT_SIZE_BODY
from fizz.frontend.qt.widgets.common import load_lucide_icon


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
    font = QtGui.QFont("Segoe UI")
    font.setPixelSize(FONT_SIZE_BODY)
    app.setFont(font)
    app.setStyleSheet(APP_QSS)
    app.setWindowIcon(load_lucide_icon("file-code-corner"))
    win = MainWindow()
    win.show()
    return app.exec_()


if __name__ == "__main__":
    sys.exit(main())
