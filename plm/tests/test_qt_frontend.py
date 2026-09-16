import inspect
import os
import shutil
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
from plm.frontend.qt.widgets.settings import DEFAULT_SETTINGS, SettingsDialog
from plm.frontend.qt.widgets.tables import EditableTable
from plm.frontend.qt.widgets import theme
from plm.frontend.qt.widgets.theme import (
    BG,
    BG_ELEVATED,
    BG_SIDEBAR,
    VisibleCheckBox,
    build_stylesheet,
)


class QtFrontendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setFont(QtGui.QFont("Segoe UI", 13))
        cls.app.setStyleSheet(build_stylesheet())

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
        self.assertEqual(window.log_tab_btn.height(), window.log_more.height())
        self.assertEqual(window.report_tab_btn.height(), window.log_toggle.height())

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

        window._set_preview_search_visible(True)
        window.preview_root_btn.click()
        self.process_events()
        self.assertGreater(
            window.preview_file_tree.geometry().top(),
            window.preview_search_bar.geometry().bottom(),
        )
        window._set_preview_tree_visible(False)
        window._set_preview_search_visible(False)

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

    def test_validation_errors_go_to_the_log_page(self):
        """The PROBLEMS tree is gone: validation output is plain log text now,
        and Validate brings the LOG page forward to show it."""
        window = MainWindow()
        self.addCleanup(window.close)
        window.current_workspace = Path(self.temp.name) / "quad"
        config = mock.Mock()
        config.validate.return_value = ["controller max_width must be positive"]

        with mock.patch.object(
            window, "_save_before_action", return_value=True
        ), mock.patch.object(main_window, "Config", return_value=config):
            window._on_validate()

        text = window.log.toPlainText()
        self.assertIn("Config validation failed:", text)
        self.assertIn("controller max_width must be positive", text)
        self.assertIs(window.bottom_panel_stack.currentWidget(), window.log)
        self.assertTrue(window.log_tab_btn.isChecked())
        self.assertFalse(window.report_tab_btn.isChecked())

    def test_config_parse_failure_is_logged_not_fatal(self):
        """Config() raises SystemExit (a BaseException) on a parse failure --
        it must be caught, or it takes the whole GUI down."""
        window = MainWindow()
        self.addCleanup(window.close)
        window.current_workspace = Path(self.temp.name) / "quad"

        with mock.patch.object(
            window, "_save_before_action", return_value=True
        ), mock.patch.object(
            main_window, "Config", side_effect=SystemExit("line 3: missing ctrl_id")
        ):
            window._on_validate()

        self.assertIn("line 3: missing ctrl_id", window.log.toPlainText())

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
        window._set_generation_busy(False)

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
            captured["delete_widget"] = actions[-1].defaultWidget()
            return actions[1]

        with mock.patch.object(QtWidgets.QMenu, "exec_", choose_clear), mock.patch.object(
            window, "_remove_recent_entry"
        ) as clear:
            window._show_recent_menu(item, QtCore.QPoint())

        self.assertEqual(captured["labels"], ["Rename", "Clear", "Delete"])
        self.assertEqual(captured["delete_widget"].objectName(), "destructiveMenuItem")
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

    def test_palette_matches_sap_horizon_tokens(self):
        """Pins the palette to Horizon's published values, so a stray tweak
        to one colour shows up as a failing test rather than as a slow
        drift away from the design system. Names are the upstream tokens in
        theming-base-content's sap_horizon/variables.json."""
        self.assertEqual(BG, "#ffffff")  # sapBaseColor
        self.assertEqual(BG_ELEVATED, "#ffffff")  # sapGroup_ContentBackground
        self.assertEqual(BG_SIDEBAR, "#f5f6f7")  # sapBackgroundColor
        self.assertEqual(theme.ACCENT, "#0070f2")  # sapBrandColor
        self.assertEqual(theme.TEXT, "#131e29")  # sapTextColor
        self.assertEqual(theme.DANGER, "#aa0808")  # sapNegativeColor

    def test_sap_icon_font_backs_every_named_icon(self):
        from plm.frontend.qt.widgets import sap_icons

        self.assertTrue(sap_icons.ICON_FONT_PATH.is_file(), sap_icons.ICON_FONT_PATH)
        self.assertEqual(sap_icons.text_font_family(), "72")
        blank = []
        for name in sap_icons.CODEPOINTS:
            image = sap_icons.icon(name, "#131e29", 24).pixmap(24, 24).toImage()
            inked = sum(
                1
                for y in range(image.height())
                for x in range(image.width())
                if image.pixelColor(x, y).alpha() > 0
            )
            if inked < 8:
                blank.append(name)
        # A wrong codepoint renders as nothing (or as .notdef), which is easy
        # to miss by eye across a toolbar of small glyphs.
        self.assertEqual(blank, [], f"icons resolved to no glyph: {blank}")

    def test_preview_tree_and_drag_handle_use_official_sap_icons(self):
        from plm.frontend.qt.widgets import sap_icons, tables

        self.assertEqual(
            {
                name: sap_icons.CODEPOINTS[name]
                for name in (
                    "document",
                    "folder-blank",
                    "navigation-left-arrow",
                    "vertical-grip",
                )
            },
            {
                "document": 0xE172,
                "folder-blank": 0xE08E,
                "navigation-left-arrow": 0xE067,
                "vertical-grip": 0xE1FA,
            },
        )
        self.assertEqual(main_window._SVG_TREE_FILE, "document")
        self.assertEqual(main_window._SVG_TREE_FOLDER, "folder-blank")
        self.assertNotIn(
            "standardIcon", inspect.getsource(MainWindow._refresh_rtl_preview)
        )
        self.assertIn("sap_icons.icon", inspect.getsource(tables.drag_handle_icon))
        main_source = inspect.getsource(main_window)
        self.assertNotIn('setText("⋮")', main_source)
        self.assertNotIn('setText("›" if collapsed else "‹")', main_source)

    def _sample_workspace(self):
        """A minimal but valid workspace the real loader accepts."""
        workspace = Path(self.temp.name) / "quad"
        shutil.copytree(
            Path(main_window.PLM_ROOT) / "test" / "quad" / "config",
            workspace / "config",
        )
        return workspace

    def test_unsaved_edits_mark_the_title_and_gate_switching(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        self.process_events()

        self.assertFalse(window._is_dirty())
        self.assertNotIn("*", window.windowTitle())

        window.controllers_table.insert_row_below(0)
        self.process_events()
        self.assertTrue(window._is_dirty())
        window._poll_dirty_state()
        self.assertIn("*", window.windowTitle())

        # Cancel must leave both the edit and the open workspace alone.
        with mock.patch.object(
            QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Cancel
        ):
            self.assertFalse(window._confirm_discard_changes())
        self.assertTrue(window._is_dirty())

        # Discard drops them without writing anything.
        with mock.patch.object(
            QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Discard
        ):
            self.assertTrue(window._confirm_discard_changes())

        # Save clears the marker.
        with mock.patch.object(
            QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Save
        ):
            self.assertTrue(window._confirm_discard_changes())
        self.assertFalse(window._is_dirty())
        window._poll_dirty_state()
        self.assertNotIn("*", window.windowTitle())

    def test_revert_restores_the_version_on_disk(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        self.process_events()
        before = [row["ctrl_name"] for row in window.controllers_table.get_rows()]

        window.controllers_table.insert_row_below(0)
        self.process_events()
        self.assertTrue(window._is_dirty())

        with mock.patch.object(
            QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Yes
        ):
            window._on_revert()
        self.process_events()
        self.assertEqual(
            [row["ctrl_name"] for row in window.controllers_table.get_rows()], before
        )
        self.assertFalse(window._is_dirty())

    def test_generation_buttons_lock_while_a_run_is_in_flight(self):
        window = MainWindow()
        self.addCleanup(window.close)
        self.assertTrue(all(button.isEnabled() for button in window.generation_buttons))

        window._set_generation_busy(True)
        self.assertFalse(any(button.isEnabled() for button in window.generation_buttons))
        self.assertFalse(
            any(button.isEnabled() for button, _label in window.sidebar_action_buttons)
        )
        self.assertFalse(window.recent_list.isEnabled())
        # A second click while busy must not start another writer.
        with mock.patch.object(window, "_save_before_action") as save:
            window._run_tool("rtl")
        save.assert_not_called()

        window._set_generation_busy(False)
        self.assertTrue(all(button.isEnabled() for button in window.generation_buttons))
        self.assertTrue(
            all(button.isEnabled() for button, _label in window.sidebar_action_buttons)
        )
        self.assertTrue(window.recent_list.isEnabled())

    def test_bottom_panel_is_log_and_report(self):
        """Two pages, one widget each: the activity log and Config.report().
        The topology used to share the REPORT page under its own sub-header,
        and there used to be a third PROBLEMS page -- both are gone."""
        window = MainWindow()
        self.addCleanup(window.close)

        self.assertEqual(window.log_tab_btn.text(), "LOG")
        self.assertEqual(window.report_tab_btn.text(), "REPORT")
        self.assertEqual(window.bottom_panel_stack.count(), 2)
        self.assertIs(window.bottom_panel_stack.widget(0), window.log)
        self.assertIs(window.bottom_panel_stack.widget(1), window.topology_summary)
        # LOG is what a fresh window shows -- it is where Validate/Generate write.
        self.assertIs(window.bottom_panel_stack.currentWidget(), window.log)
        self.assertFalse(hasattr(window, "problem_tree"))
        self.assertIsNone(
            window._generation_page.findChild(
                QtWidgets.QPlainTextEdit, "topologySummary"
            )
        )

    def test_report_page_shows_the_topology_report(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        self.process_events()

        window.report_tab_btn.click()
        self.process_events()
        self.assertIs(window.bottom_panel_stack.currentWidget(), window.topology_summary)
        self.assertIn("Lane groups", window.topology_summary.toPlainText())

    def test_reset_defaults_button_is_compact(self):
        dialog = SettingsDialog(None, DEFAULT_SETTINGS)
        self.addCleanup(dialog.close)

        self.assertEqual(
            dialog.reset_defaults_btn.sizePolicy().horizontalPolicy(),
            QtWidgets.QSizePolicy.Fixed,
        )
        self.assertEqual(dialog.reset_defaults_btn.objectName(), "resetDefaultsBtn")

    def test_topology_summary_reports_lane_groups(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        self.process_events()

        text = window.topology_summary.toPlainText()
        self.assertIn("Lane groups", text)
        # Built from the live widgets, not the file on disk.
        self.assertNotEqual(text, "Open a workspace to see its lane topology.")

    def test_external_config_change_is_not_overwritten(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        controllers = workspace / "config" / "controllers.csv"
        external_text = controllers.read_text(encoding="utf-8") + "\n"
        controllers.write_text(external_text, encoding="utf-8")

        with mock.patch.object(QtWidgets.QMessageBox, "warning") as warning:
            self.assertFalse(window._on_save())

        warning.assert_called_once()
        self.assertEqual(controllers.read_text(encoding="utf-8"), external_text)

    def test_new_workspace_prompts_for_unsaved_changes_only_once(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)

        with mock.patch.object(
            window, "_confirm_discard_changes", return_value=True
        ) as confirm, mock.patch.object(
            QtWidgets.QInputDialog, "getText", return_value=("new_quad", True)
        ):
            window._on_new()

        confirm.assert_called_once()
        self.assertEqual(window.current_workspace.name, "new_quad")

    def test_invalid_topology_is_reported_without_calling_report(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        rows = window.lane_grid.get_rows()
        rows[0]["lane0"] = "99-0"
        window.lane_grid.set_rows(rows)
        window._topology_payload = None

        window._refresh_topology_summary()

        summary = window.topology_summary.toPlainText()
        self.assertIn("Config is not valid yet", summary)
        self.assertIn("undefined ctrl_id=99", summary)

    def test_preview_toolbar_compacts_before_it_can_overlap_files_button(self):
        window = MainWindow()
        self.addCleanup(window.close)

        window._apply_preview_control_density(300)
        self.assertFalse(window.preview_more_btn.isHidden())
        self.assertTrue(window.preview_edit_btn.isHidden())
        self.assertTrue(window.preview_search_btn.isHidden())
        self.assertFalse(window.preview_refresh_btn.isHidden())
        self.assertFalse(window.preview_expand_btn.isHidden())

        window._apply_preview_control_density(150)
        self.assertFalse(window.preview_more_btn.isHidden())
        self.assertTrue(window.preview_refresh_btn.isHidden())
        self.assertTrue(window.preview_expand_btn.isHidden())
        self.assertFalse(window.preview_toggle_btn.isHidden())

        window._apply_preview_control_density(800)
        self.assertTrue(window.preview_more_btn.isHidden())
        self.assertFalse(window.preview_edit_btn.isHidden())
        self.assertFalse(window.preview_search_btn.isHidden())

    def test_floating_log_stays_inside_a_narrow_main_pane(self):
        window = MainWindow()
        self.addCleanup(window.close)
        window.show()
        window._on_toggle_rtl_preview(True)
        window.content_splitter.setSizes([120, 700])
        self.process_events()

        window._position_floating_log()

        self.assertLessEqual(window.log_card.width(), window.main_area.width())
        self.assertLessEqual(
            window.log_card.geometry().right(),
            window.main_area.rect().right(),
        )

    def test_topology_refresh_is_debounced_from_generation_controls(self):
        window = MainWindow()
        self.addCleanup(window.close)
        generation_index = window.tabs.indexOf(window._generation_page)
        window.tabs.setCurrentIndex(generation_index)
        self.process_events()

        timeout_spy = QtTest.QSignalSpy(window._topology_refresh_timer.timeout)
        window._poll_dirty_state()
        QtTest.QTest.qWait(300)
        self.process_events()
        self.assertEqual(len(timeout_spy), 0)

        next_index = (
            window.sel_mode_combo.currentIndex() + 1
        ) % window.sel_mode_combo.count()
        window.sel_mode_combo.setCurrentIndex(next_index)
        QtTest.QTest.qWait(300)
        self.process_events()
        self.assertEqual(len(timeout_spy), 1)

    def test_close_is_blocked_during_generation(self):
        window = MainWindow()
        self.addCleanup(window.close)
        event = mock.Mock()
        window._set_generation_busy(True)

        with mock.patch.object(QtWidgets.QMessageBox, "warning"):
            window.closeEvent(event)

        event.ignore.assert_called_once()
        window._set_generation_busy(False)

    def test_preview_search_finds_matches_and_jumps_to_a_line(self):
        workspace = self._sample_workspace()
        rtl = workspace / "rtl" / "src"
        rtl.mkdir(parents=True)
        (rtl / "pipe_lane_mapper.sv").write_text(
            "module pipe_lane_mapper;\n  logic Marker_Signal;\nendmodule\n",
            encoding="utf-8",
        )
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        window.show()
        window._on_toggle_rtl_preview(True)
        self.process_events()

        window._selected_preview_file = rtl / "pipe_lane_mapper.sv"
        window._show_selected_preview_file()
        self.process_events()

        self.assertFalse(window.preview_search_bar.isVisible())
        window._on_preview_search_open()
        self.assertTrue(window.preview_search_bar.isVisible())

        window.preview_search_edit.setText("marker_signal")
        self.assertEqual(window.preview_search_status.text(), "1 found")
        window._preview_find_next()
        self.assertEqual(window.preview_code.textCursor().selectedText(), "Marker_Signal")

        window.preview_search_edit.setText("nothing_here")
        window._preview_find_next()
        self.assertEqual(window.preview_search_status.text(), "no match")

        window.preview_search_edit.setText(":3")
        window._preview_find_next()
        self.assertEqual(window.preview_search_status.text(), "line 3")
        self.assertEqual(window.preview_code.textCursor().blockNumber(), 2)

        window._copy_preview_path()
        self.assertEqual(
            QtWidgets.QApplication.clipboard().text(),
            str(rtl / "pipe_lane_mapper.sv"),
        )

        window._set_preview_search_visible(False)
        self.assertFalse(window.preview_search_bar.isVisible())


    def test_live_validation_marks_duplicate_controller_ids(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        first = window.controllers_table.table.item(0, 0)
        second = window.controllers_table.table.item(1, 0)
        original = second.text()

        second.setText(first.text())
        window._process_live_edits()

        self.assertIn("Duplicate ctrl_id", first.toolTip())
        self.assertIn("Duplicate ctrl_id", second.toolTip())
        self.assertGreater(window._live_validation_error_count, 0)

        second.setText(original)
        window._process_live_edits()
        self.assertNotIn("Duplicate ctrl_id", first.toolTip())

    def test_undo_redo_restores_complete_editor_snapshot(self):
        workspace = self._sample_workspace()
        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        item = window.controllers_table.table.item(0, 1)
        original = item.text()

        item.setText("RenamedCtrl")
        window._process_live_edits()
        self.assertTrue(window.undo_action.isEnabled())

        window._undo_edit()
        self.assertEqual(
            window.controllers_table.table.item(0, 1).text(), original
        )
        self.assertTrue(window.redo_action.isEnabled())

        window._redo_edit()
        self.assertEqual(
            window.controllers_table.table.item(0, 1).text(), "RenamedCtrl"
        )
        window._undo_edit()
        self.assertFalse(window._is_dirty())

    def test_generation_status_is_rendered_in_preview_tree(self):
        workspace = self._sample_workspace()
        rtl = workspace / "rtl"
        rtl.mkdir()
        modified = rtl / "modified.sv"
        unchanged = rtl / "unchanged.sv"
        modified.write_text("module old; endmodule\n", encoding="utf-8")
        unchanged.write_text("module same; endmodule\n", encoding="utf-8")

        window = MainWindow()
        self.addCleanup(window.close)
        window._open_workspace(workspace)
        window.show()
        window._on_toggle_rtl_preview(True)
        self.process_events()

        before = window._output_signature(workspace, "rtl")
        modified.write_text("module new; endmodule\n", encoding="utf-8")
        created = rtl / "created.sv"
        created.write_text("module created; endmodule\n", encoding="utf-8")
        after = window._output_signature(workspace, "rtl")
        window._show_generation_results(workspace, before, after)
        self.process_events()

        labels = []

        def collect(parent):
            for index in range(parent.childCount()):
                child = parent.child(index)
                if child.data(0, QtCore.Qt.UserRole):
                    labels.append(child.text(0))
                collect(child)

        collect(window.preview_file_tree.invisibleRootItem())
        self.assertIn("modified.sv   Modified", labels)
        self.assertIn("created.sv   New", labels)
        self.assertIn("unchanged.sv   Unchanged", labels)
        self.assertFalse(hasattr(window, "outputs_tab_btn"))


if __name__ == "__main__":
    unittest.main()
