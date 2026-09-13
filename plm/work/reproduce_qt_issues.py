"""Reproduce Qt layout issues with large font size and bifurcate workspace."""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt import main_window
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.widgets.theme import STYLESHEET


def metrics(window):
    print("sidebar width:", window.sidebar.width())
    print("topbar height:", window.topbar.height())
    header = window.signals_table.table.horizontalHeader()
    cols = [header.sectionSize(i) for i in range(header.count())]
    print("signals columns:", cols, "total", sum(cols))
    print("signals viewport:", window.signals_table.table.viewport().width())
    print("lane viewport:", window.lane_grid.table.viewport().width())
    print("lane col widths:", [window.lane_grid.table.columnWidth(i) for i in range(window.lane_grid.table.columnCount())])


def capture(window, app, w, h, suffix=""):
    window.resize(w, h)
    app.processEvents()
    out = ROOT / "work" / f"repro-{suffix}-{w}x{h}.png"
    window.grab().save(str(out))
    print(f"saved {out}")
    metrics(window)


def main():
    # Use a throwaway state file so user settings (e.g. an oversized saved
    # font) don't interfere with the baseline/default captures.
    main_window.STATE_FILE = ROOT / "work" / "repro_state.json"
    if main_window.STATE_FILE.is_file():
        main_window.STATE_FILE.unlink()

    app = QtWidgets.QApplication([])
    app.setStyle("Fusion")
    app.setFont(QtGui.QFont("Segoe UI", 13))
    app.setStyleSheet(STYLESHEET)

    window = MainWindow()
    ws = ROOT / "configs" / "bifurcate"
    if ws.is_dir():
        window._open_workspace(ws)
    window.show()
    app.processEvents()

    # Default font first
    print("=== default font ===")
    window.tabs.setCurrentIndex(2)  # Pipe Signals
    app.processEvents()
    capture(window, app, 1600, 900, "default")

    # Large font (will be clamped to 16)
    print("\n=== large font ===")
    window._apply_font({"fontFamily": "Segoe UI", "fontSize": 18.5})
    app.processEvents()
    window.tabs.setCurrentIndex(2)  # Pipe Signals
    app.processEvents()
    capture(window, app, 1600, 900, "large")

    window.tabs.setCurrentIndex(1)  # Lane Mapping
    app.processEvents()
    capture(window, app, 1600, 900, "large-lane")
    capture(window, app, 900, 620, "large-lane")

    window.close()


if __name__ == "__main__":
    main()
