import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt import main_window
from plm.frontend.qt.main import APP_ICON_PATH
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.widgets.lanegrid import LaneGrid
from plm.frontend.qt.widgets.tables import EditableTable
from plm.frontend.qt.widgets.theme import STYLESHEET, VisibleCheckBox


class QtFrontendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setFont(QtGui.QFont("Segoe UI", 13))
        cls.app.setStyleSheet(STYLESHEET)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        main_window.STATE_FILE = Path(self.temp.name) / "state.json"

    def process_events(self):
        self.app.processEvents()
        self.app.processEvents()

    def test_window_tabs_headers_and_preview_snap(self):
        window = MainWindow()
        self.addCleanup(window.close)
        window.show()
        self.process_events()

        for index in range(window.tabs.count()):
            window.tabs.setCurrentIndex(index)
            self.process_events()

        window._on_toggle_rtl_preview(True)
        self.process_events()
        tab_bar = window.tabs.tabBar()
        tab_top = tab_bar.mapTo(window.centralWidget(), QtCore.QPoint()).y()
        title_top = window.preview_title.mapTo(window.centralWidget(), QtCore.QPoint()).y()
        self.assertEqual(title_top, tab_top)
        self.assertEqual(window.preview_title.height(), tab_bar.height())
        self.assertLessEqual(
            abs(window.preview_controls.geometry().center().y() - (tab_top + tab_bar.height() // 2)),
            1,
        )
        self.assertEqual(window.log_title.height(), window.log_more.height())
        self.assertEqual(window.log_title.height(), window.log_toggle.height())

        window.content_splitter.moveSplitter(int(window.content_splitter.width() * 0.20), 1)
        QtTest.QTest.qWait(main_window.PREVIEW_MAXIMIZE_ANIM_MS + 30)
        self.process_events()
        self.assertTrue(window._preview_maximized)
        self.assertFalse(window.main_area.isVisible())
        self.assertTrue(window.rtl_preview_panel.isVisible())

    def test_table_context_menu_inserts_and_deletes(self):
        table = EditableTable([
            {"key": "id", "heading": "ID"},
            {"key": "name", "heading": "NAME"},
        ])
        table.set_rows([{"id": "0", "name": "A"}, {"id": "1", "name": "B"}])

        with mock.patch.object(QtWidgets.QMenu, "exec_", lambda menu, _pos: menu.actions()[0]):
            table._show_row_context_menu(1, QtCore.QPoint())
        self.assertEqual(table.table.rowCount(), 3)
        self.assertEqual(table.get_rows()[1], {"id": "", "name": ""})

        with mock.patch.object(QtWidgets.QMenu, "exec_", lambda menu, _pos: menu.actions()[3]):
            table._show_row_context_menu(1, QtCore.QPoint())
        self.assertEqual(table.table.rowCount(), 2)

        table.set_rows([])
        with mock.patch.object(QtWidgets.QMenu, "exec_", lambda menu, _pos: menu.actions()[0]):
            table._show_row_context_menu(-1, QtCore.QPoint())
        self.assertEqual(table.table.rowCount(), 1)

    def test_lane_grid_context_menu_and_x32_layout(self):
        grid = LaneGrid()
        grid.resize(1000, 500)
        grid.set_columns(32)
        grid.set_rows([{"mode": "0"}, {"mode": "1"}])
        grid.show()
        self.process_events()
        self.assertEqual(grid.table.horizontalScrollBar().maximum(), 0)

        with mock.patch.object(QtWidgets.QMenu, "exec_", lambda menu, _pos: menu.actions()[1]):
            grid._on_row_context_menu(1, QtCore.QPoint())
        self.assertEqual(grid.table.rowCount(), 3)

    def test_checkbox_and_packaged_icon(self):
        checkbox = VisibleCheckBox()
        checkbox.resize(32, 28)
        checkbox.setChecked(True)
        checkbox.show()
        self.process_events()
        image = checkbox.grab().toImage()
        self.assertFalse(image.isNull())
        self.assertTrue(checkbox.isChecked())
        self.assertTrue(APP_ICON_PATH.is_file(), APP_ICON_PATH)


if __name__ == "__main__":
    unittest.main()
