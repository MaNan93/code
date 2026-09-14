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
from plm.frontend.qt.widgets.theme import BG, BG_ELEVATED, BG_SIDEBAR, STYLESHEET, VisibleCheckBox


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
        tab_rect = tab_bar.tabRect(window.tabs.currentIndex())
        pill_rect = tab_rect.adjusted(
            0,
            main_window.TAB_VERTICAL_GAP,
            0,
            -main_window.TAB_VERTICAL_GAP,
        )
        tab_top = tab_bar.mapTo(window.centralWidget(), pill_rect.topLeft()).y()
        root_top = window.preview_root_btn.mapTo(
            window.centralWidget(), QtCore.QPoint()
        ).y()
        root_center_y = window.preview_root_btn.mapTo(
            window.centralWidget(), window.preview_root_btn.rect().center()
        ).y()
        self.assertLessEqual(abs(root_top - tab_top), 1)
        self.assertEqual(window.preview_root_btn.height(), pill_rect.height())
        self.assertLessEqual(
            abs(window.preview_controls.geometry().center().y() - root_center_y),
            1,
        )
        root_left = window.preview_root_btn.mapTo(
            window.rtl_preview_panel, QtCore.QPoint()
        ).x()
        code_left = window.preview_code.mapTo(
            window.rtl_preview_panel, QtCore.QPoint()
        ).x()
        self.assertEqual(root_left, code_left)
        self.assertEqual(window.preview_toggle_btn.toolTip(), "Preview")
        self.assertEqual(window.preview_toggle_btn.accessibleName(), "Preview")
        self.assertEqual(window.problems_tab_btn.height(), window.log_more.height())
        self.assertEqual(window.log_tab_btn.height(), window.log_toggle.height())

        def widget_bottom(widget):
            point = widget.mapTo(
                window.centralWidget(), QtCore.QPoint(0, widget.height())
            )
            return point.y()

        doc_button = next(
            button for button, label in window.sidebar_bottom_buttons if label == "Doc"
        )
        self.assertEqual(widget_bottom(doc_button), widget_bottom(window.log_card))
        self.assertEqual(widget_bottom(window.log_card), widget_bottom(window.preview_code))

        window.content_splitter.moveSplitter(int(window.content_splitter.width() * 0.20), 1)
        QtTest.QTest.qWait(main_window.PREVIEW_MAXIMIZE_ANIM_MS + 30)
        self.process_events()
        self.assertTrue(window._preview_maximized)
        self.assertFalse(window.main_area.isVisible())
        self.assertTrue(window.rtl_preview_panel.isVisible())

    def test_preview_file_tree_replaces_file_combo(self):
        workspace = Path(self.temp.name) / "quad"
        config = workspace / "config"
        rtl = workspace / "rtl" / "common"
        config.mkdir(parents=True)
        rtl.mkdir(parents=True)
        csv_path = config / "controllers.csv"
        rtl_path = rtl / "pipe_lane_clk_gate.sv"
        csv_path.write_text("ctrl_id,ctrl_name,max_width\n0,CtrlA,12\n", encoding="utf-8")
        rtl_path.write_text("module pipe_lane_clk_gate;\nendmodule\n", encoding="utf-8")

        window = MainWindow()
        self.addCleanup(window.close)
        window.current_workspace = workspace
        window.show()
        window._on_toggle_rtl_preview(True)
        self.process_events()

        self.assertFalse(hasattr(window, "preview_file_combo"))
        self.assertIsInstance(window.preview_root_btn, QtWidgets.QToolButton)
        self.assertEqual(window.preview_root_btn.text(), "")
        self.assertEqual(
            window.preview_root_btn.toolButtonStyle(),
            QtCore.Qt.ToolButtonIconOnly,
        )
        self.assertEqual(window.preview_root_btn.accessibleName(), "Files")
        self.assertIsNone(window.preview_file_tree.graphicsEffect())
        self.assertTrue(window.preview_highlight_btn.isChecked())
        self.assertEqual(window.preview_diff_btn.accessibleName(), "Show diff")
        self.assertEqual(window.preview_file_tree.topLevelItemCount(), 2)
        self.assertEqual(
            [window.preview_file_tree.topLevelItem(i).text(0) for i in range(2)],
            ["config", "rtl"],
        )

        code_geometry = QtCore.QRect(window.preview_code.geometry())
        window.preview_root_btn.click()
        self.process_events()
        self.assertTrue(window.preview_file_tree.isVisible())
        self.assertIs(window.preview_file_tree.parent(), window.rtl_preview_panel)
        self.assertEqual(window.preview_code.geometry(), code_geometry)
        self.assertTrue(window.preview_file_tree.geometry().intersects(code_geometry))
        self.assertEqual(
            window.preview_file_tree.geometry().left(),
            code_geometry.left(),
        )
        QtTest.QTest.mouseClick(window.preview_code.viewport(), QtCore.Qt.LeftButton)
        self.process_events()
        self.assertFalse(window.preview_file_tree.isVisible())

        window.preview_root_btn.click()
        self.process_events()
        self.assertTrue(window.preview_file_tree.isVisible())

        def find_file(parent, target):
            for index in range(parent.childCount()):
                child = parent.child(index)
                if child.data(0, QtCore.Qt.UserRole) == str(target):
                    return child
                found = find_file(child, target)
                if found is not None:
                    return found
            return None

        csv_item = find_file(window.preview_file_tree.invisibleRootItem(), csv_path)
        self.assertIsNotNone(csv_item)
        window._on_preview_tree_item_clicked(csv_item, 0)
        self.assertEqual(window._selected_preview_file, csv_path)
        self.assertIn("ctrl_id,ctrl_name,max_width", window.preview_code.toPlainText())
        self.assertFalse(window.preview_file_tree.isVisible())

        window._selected_preview_file = rtl_path
        window._show_selected_preview_file()
        self.assertEqual(window.preview_highlighter._language, "verilog")
        self.assertFalse(window.preview_diff_btn.isEnabled())
        rtl_path.write_text(
            "module pipe_lane_clk_gate;\n  assign enabled = 1'b1;\nendmodule\n",
            encoding="utf-8",
        )
        window._refresh_rtl_preview()
        self.assertTrue(window.preview_diff_btn.isEnabled())
        window.preview_diff_btn.click()
        self.assertEqual(window.preview_highlighter._language, "diff")
        self.assertIn("--- previous/rtl/common/pipe_lane_clk_gate.sv", window.preview_code.toPlainText())
        self.assertIn("+  assign enabled = 1'b1;", window.preview_code.toPlainText())

    def test_validation_errors_fill_problems_panel(self):
        window = MainWindow()
        self.addCleanup(window.close)
        window.current_workspace = Path(self.temp.name) / "quad"
        config = mock.Mock()
        config.validate.return_value = ["controller max_width must be positive"]

        with mock.patch.object(
            window, "_save_before_action", return_value=True
        ), mock.patch.object(main_window, "Config", return_value=config):
            window._on_validate()

        self.assertEqual(window.problem_tree.topLevelItemCount(), 1)
        problem = window.problem_tree.topLevelItem(0)
        self.assertEqual(problem.text(0), "Error")
        self.assertEqual(problem.text(1), "controller max_width must be positive")
        self.assertEqual(problem.text(2), "config/controllers.csv")
        self.assertEqual(window.problems_tab_btn.text(), "PROBLEMS 1")
        self.assertIs(window.bottom_panel_stack.currentWidget(), window.problem_tree)

    def test_generate_output_parser_extracts_source_location(self):
        window = MainWindow()
        self.addCleanup(window.close)

        window._capture_problem_line(
            "rtl/common/pipe_lane_clk_gate.sv:12:3: error: syntax error"
        )

        self.assertEqual(window.problem_tree.topLevelItemCount(), 1)
        problem = window.problem_tree.topLevelItem(0)
        self.assertEqual(problem.text(0), "Error")
        self.assertEqual(problem.text(1), "syntax error")
        self.assertEqual(problem.text(2), "rtl/common/pipe_lane_clk_gate.sv")
        self.assertEqual(problem.text(3), "12:3")

    def test_problem_double_click_opens_preview_at_line(self):
        workspace = Path(self.temp.name) / "quad"
        source = workspace / "rtl" / "broken.sv"
        source.parent.mkdir(parents=True)
        source.write_text(
            "module broken;\n"
            "  bad syntax here\n"
            "endmodule\n",
            encoding="utf-8",
        )
        window = MainWindow()
        self.addCleanup(window.close)
        window.current_workspace = workspace
        window.show()
        self.process_events()
        window._add_problem(
            "Generate", "Error", "syntax error", source, line=2, column=3
        )

        window._on_problem_activated(window.problem_tree.topLevelItem(0), 0)
        self.process_events()

        self.assertTrue(window.rtl_preview_panel.isVisible())
        self.assertEqual(window._selected_preview_file, source)
        self.assertEqual(window.preview_code.textCursor().blockNumber(), 1)

    def test_generate_process_can_import_source_checkout(self):
        window = MainWindow()
        self.addCleanup(window.close)
        window.current_workspace = Path(self.temp.name) / "quad"
        with mock.patch.object(
            window, "_save_before_action", return_value=True
        ), mock.patch.object(QtCore.QProcess, "start"):
            window._run_tool("all")

        process = window._active_processes[-1]
        python_path = process.processEnvironment().value("PYTHONPATH").split(os.pathsep)
        self.assertIn(str(main_window.PLM_ROOT / "src"), python_path)

    def test_modal_dialog_blurs_only_while_open(self):
        window = MainWindow()
        self.addCleanup(window.close)
        dialog = QtWidgets.QDialog(window)
        blur_was_active = []

        def fake_exec():
            blur_was_active.append(
                isinstance(
                    window.centralWidget().graphicsEffect(),
                    QtWidgets.QGraphicsBlurEffect,
                )
            )
            return QtWidgets.QDialog.Rejected

        with mock.patch.object(dialog, "exec_", side_effect=fake_exec):
            result = window._exec_modal_blurred(dialog)

        self.assertEqual(result, QtWidgets.QDialog.Rejected)
        self.assertEqual(blur_was_active, [True])
        self.assertIsNone(window.centralWidget().graphicsEffect())

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

    def test_recent_menu_labels_and_actions(self):
        window = MainWindow()
        self.addCleanup(window.close)
        item = QtWidgets.QListWidgetItem()
        item.setData(QtCore.Qt.UserRole, str(Path(self.temp.name) / "quad"))
        captured = {}

        def choose_clear(menu, _pos):
            actions = [action for action in menu.actions() if not action.isSeparator()]
            captured["labels"] = [action.text() for action in actions]
            return actions[1]

        with mock.patch.object(QtWidgets.QMenu, "exec_", choose_clear), mock.patch.object(
            window, "_remove_recent_entry"
        ) as clear:
            window._show_recent_menu(item, QtCore.QPoint())

        self.assertEqual(captured["labels"], ["Rename", "Clear", "Delete"])
        clear.assert_called_once()

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

    def test_white_canvas_and_reference_gray_sidebar_palette(self):
        self.assertEqual(BG, "#ffffff")
        self.assertEqual(BG_ELEVATED, "#ffffff")
        self.assertEqual(BG_SIDEBAR, "#F6F6F6")


if __name__ == "__main__":
    unittest.main()
