"""Basic smoke test for the Qt frontend after layout fixes."""
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


def main():
    main_window.STATE_FILE = ROOT / "work" / "smoke_state.json"
    if main_window.STATE_FILE.is_file():
        main_window.STATE_FILE.unlink()

    app = QtWidgets.QApplication([])
    app.setStyle("Fusion")
    app.setFont(QtGui.QFont("Segoe UI", 13))
    app.setStyleSheet(STYLESHEET)

    window = MainWindow()
    ws = ROOT / "configs" / "quad"
    if not ws.is_dir():
        ws = ROOT / "test" / "quad"
    assert ws.is_dir(), ws
    window._open_workspace(ws)
    window.show()
    app.processEvents()

    # Toggle through tabs
    for i in range(window.tabs.count()):
        window.tabs.setCurrentIndex(i)
        app.processEvents()

    # Apply largest allowed font and re-toggle tabs
    window._apply_font({"fontFamily": "Segoe UI", "fontSize": 16})
    app.processEvents()
    for i in range(window.tabs.count()):
        window.tabs.setCurrentIndex(i)
        app.processEvents()

    # Test table insert/delete
    rows_before = window.controllers_table.table.rowCount()
    window.controllers_table.insert_row_below(0)
    assert window.controllers_table.table.rowCount() == rows_before + 1
    window.controllers_table.delete_row(0)
    assert window.controllers_table.table.rowCount() == rows_before

    # Test lane grid paint on a single cell
    window.tabs.setCurrentIndex(1)
    app.processEvents()
    grid = window.lane_grid
    if grid.controllers:
        grid._set_active_controller(grid.controllers[0]["ctrl_id"])
        grid._begin_paint(0, 0)
        grid._end_paint()
        assert grid.data[0].get("lane0", ""), "lane paint did not write"

    print("smoke test passed")
    window.close()


if __name__ == "__main__":
    main()
