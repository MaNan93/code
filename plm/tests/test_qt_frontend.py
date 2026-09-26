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
from plm.frontend.qt.main_window import MainWindow, _NewWorkspaceDialog
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
from plm.core.validation import ValidationError, ValidationIssue
from plm.core.gen_flags import GenerationOptions
from plm.core.service import generate


class QtFrontendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setFont(QtGui.QFont("Segoe UI", 13))
        cls.app.setStyleSheet(build_stylesheet())

        # Opening a modal QMessageBox under the offscreen platform is an
        # access violation in this Qt build -- verified with a three-line
        # repro, no application code involved. That kills the interpreter
        # mid-test, so unittest never reports the test AND silently skips
        # every one after it: the suite looks like it passed because most
        # of it never ran. Reaching a dialog unmocked is a test bug either
        # way, so make it raise instead of taking the process down. Tests
        # that mean to exercise a prompt patch it themselves, which wins
        # over this for the duration.
        for name in ("about", "critical", "information", "question", "warning"):
            patcher = mock.patch.object(
                QtWidgets.QMessageBox,
                name,
                side_effect=AssertionError(
                    f"QMessageBox.{name}() reached without being mocked"
                ),
            )
            patcher.start()
            cls.addClassCleanup(patcher.stop)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        state = mock.patch.object(main_window, "STATE_FILE", Path(self.temp.name) / "state.json")
        state.start()
        self.addCleanup(state.stop)
        self.addCleanup(self.destroy_test_widgets)

    def destroy_test_widgets(self):
        # close() only hides a QWidget. Destroy test windows (including
        # standalone tables/dialogs) before the next test changes app styles;
        # otherwise their timers and event filters remain active across tests.
        for widget in self.app.topLevelWidgets():
            widget.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)

    def make_window(self):
        """A MainWindow that tears down without the unsaved-changes prompt.

        close() runs that guard, and a test that left edits behind would
        otherwise open a modal from cleanup. Clearing the saved-payload
        snapshot makes _is_dirty() false, so the guard returns immediately.
        Cleanups run last-registered-first, so this is registered after the
        close it has to precede."""
        window = MainWindow()
        self.addCleanup(window.close)
        self.addCleanup(setattr, window, "_saved_payload", None)
        return window

    def process_events(self):
        self.app.processEvents()
        self.app.processEvents()

    def test_font_settings_only_reapply_styles_when_changed(self):
        window = self.make_window()
        with mock.patch.object(
            self.app, "setStyleSheet", wraps=self.app.setStyleSheet
        ) as apply_style:
            window._apply_font(DEFAULT_SETTINGS)
            apply_style.assert_not_called()
            window._apply_font({**DEFAULT_SETTINGS, "fontSize": 16})
            self.process_events()
            self.assertEqual(self.app.font().pixelSize(), 16)
            apply_style.assert_called_once()
            window._apply_font({**DEFAULT_SETTINGS, "fontSize": 16})
            apply_style.assert_called_once()
            window._apply_font(DEFAULT_SETTINGS)
            self.process_events()

    def test_window_tabs_headers_and_preview_snap(self):
        window = self.make_window()
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

        window = self.make_window()
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

    def test_generate_process_can_import_source_checkout(self):
        window = self.make_window()
        window._open_workspace(self._sample_workspace())
        with mock.patch.object(
            window, "_save_before_action", return_value=True
        ), mock.patch.object(QtCore.QProcess, "start"):
            window._run_tool()

        process = window._active_processes[-1]
        python_path = process.processEnvironment().value("PYTHONPATH").split(os.pathsep)
        self.assertIn(str(main_window.PLM_ROOT / "src"), python_path)
        window._set_generation_busy(False)

    def test_modal_dialog_blurs_only_while_open(self):
        window = self.make_window()
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

    def test_signal_enum_values_survive_render_and_can_be_corrected(self):
        table = EditableTable([
            {"key": "signal_type", "heading": "Type", "options": main_window.SIGNAL_TYPES},
            {"key": "direction", "heading": "Direction", "options": main_window.DIRECTIONS},
        ])
        self.addCleanup(table.close)
        rows = [
            {"signal_type": "unknown_type", "direction": "unknown_direction"},
            {"signal_type": "", "direction": ""},
            {"signal_type": "shared", "direction": "mac2phy"},
        ]
        table.set_rows(rows)
        self.assertEqual(table.get_rows(), rows)
        table.set_rows(table.get_rows())
        self.assertEqual(table.get_rows(), rows)
        table.table.cellWidget(0, 0).setCurrentText("perlane")
        table.table.cellWidget(0, 1).setCurrentText("mac2phy")
        self.assertEqual(table.get_rows()[0], {
            "signal_type": "perlane", "direction": "mac2phy",
        })
        self.assertEqual(table.get_rows()[1:], rows[1:])

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

    def test_signal_dropdown_values_fit_without_elision(self):
        window = self.make_window()
        window.resize(1200, 780)
        window.signals_table.set_rows([{
            "signal_name": "phy_mac_rxvalid",
            "signal_type": "perlane",
            "direction": "phy2mac",
            "width": "1",
            "safe_state": "0",
            "tie_off": "0",
        }])
        window.show()
        self.process_events()

        for column, options in ((1, main_window.SIGNAL_TYPES), (2, main_window.DIRECTIONS)):
            combo = window.signals_table.table.cellWidget(0, column)
            style_option = QtWidgets.QStyleOptionComboBox()
            combo.initStyleOption(style_option)
            text_rect = combo.style().subControlRect(
                QtWidgets.QStyle.CC_ComboBox,
                style_option,
                QtWidgets.QStyle.SC_ComboBoxEditField,
                combo,
            )
            widest = max(combo.fontMetrics().horizontalAdvance(value) for value in options)
            self.assertGreaterEqual(text_rect.width(), widest)

    def test_collapsed_log_does_not_overlap_editor(self):
        window = self.make_window()
        window.resize(1200, 780)
        window.show()
        window.log_toggle.click()
        self.process_events()
        window._position_floating_log()

        shell_bottom = window.editor_shell.mapTo(
            window.main_area, QtCore.QPoint(0, window.editor_shell.height())
        ).y()
        self.assertLessEqual(shell_bottom, window.log_card.geometry().top())

    def test_recent_menu_labels_and_actions(self):
        window = self.make_window()
        item = QtWidgets.QListWidgetItem()
        item.setData(QtCore.Qt.UserRole, str(Path(self.temp.name) / "quad"))
        captured = {}

        def choose_clear(menu, _pos):
            actions = [action for action in menu.actions() if not action.isSeparator()]
            captured["labels"] = [action.text() for action in actions]
            captured["delete_widget"] = actions[-1].defaultWidget()
            # Chosen by label, not by index: picking actions[1] silently
            # started selecting Reveal when that entry was added, so the
            # test drove a different code path than it claimed to.
            return next(a for a in actions if a.text() == "Clear")

        with mock.patch.object(QtWidgets.QMenu, "exec_", choose_clear), mock.patch.object(
            window, "_remove_recent_entry"
        ) as clear:
            window._show_recent_menu(item, QtCore.QPoint())

        self.assertEqual(
            captured["labels"], ["Rename", main_window.REVEAL_LABEL, "Clear", "Delete"]
        )
        self.assertEqual(captured["delete_widget"].objectName(), "destructiveMenuItem")
        clear.assert_called_once()

    def test_startup_restore_does_not_restore_a_cleared_recent_entry(self):
        workspace = self._sample_workspace().resolve()
        main_window.save_last_workspace(workspace)
        self.assertEqual(main_window.load_recent_workspaces(), [])

        window = self.make_window()

        self.assertEqual(window.current_workspace, workspace)
        self.assertEqual(main_window.load_recent_workspaces(), [])

        # Explicitly opening it later makes it recent again.
        window._open_workspace(workspace)
        self.assertEqual(main_window.load_recent_workspaces(), [workspace])

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

    # Deliberately not "quad": that sample is a *negative* fixture -- see
    # NEGATIVE_SAMPLES in test_core, which pins the two topology errors it
    # is meant to raise. Tests here need a workspace that validates, or
    # anything reading the topology report gets an error page instead.
    SAMPLE = "bifurcate"

    def _sample_workspace(self):
        """A copy of a bundled sample that the real loader accepts."""
        workspace = Path(self.temp.name) / self.SAMPLE
        shutil.copytree(
            Path(main_window.PLM_ROOT) / "test" / self.SAMPLE / "config",
            workspace / "config",
        )
        return workspace

    def test_unsaved_edits_mark_the_title_and_gate_switching(self):
        workspace = self._sample_workspace()
        window = self.make_window()
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
        window = self.make_window()
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
        window = self.make_window()
        self.assertEqual(
            [button.text() for button in window.generation_buttons],
            ["Generate"],
        )
        self.assertTrue(all(button.isEnabled() for button in window.generation_buttons))

        window._set_generation_busy(True)
        self.assertFalse(any(button.isEnabled() for button in window.generation_buttons))
        self.assertFalse(
            any(button.isEnabled() for button, _label in window.sidebar_action_buttons)
        )
        self.assertFalse(window.recent_list.isEnabled())
        # A second click while busy must not start another writer.
        with mock.patch.object(window, "_save_before_action") as save:
            window._run_tool()
        save.assert_not_called()

        window._set_generation_busy(False)
        self.assertTrue(all(button.isEnabled() for button in window.generation_buttons))
        self.assertTrue(
            all(button.isEnabled() for button, _label in window.sidebar_action_buttons)
        )
        self.assertTrue(window.recent_list.isEnabled())

    def test_generation_state_machine_has_visible_terminal_states(self):
        window = self.make_window()
        expected = [
            ("IDLE", "Ready"),
            ("SAVING", "Saving..."),
            ("VALIDATING", "Validating..."),
            ("GENERATING", "Generating..."),
            ("REFRESHING_PREVIEW", "Refreshing preview..."),
            ("DONE", "Generated"),
            ("STALE", "Out of date"),
            ("UP_TO_DATE", "Up to date"),
            ("FAILED", "Generation failed"),
        ]
        for state, label in expected:
            window._set_generation_state(state)
            self.assertEqual(window._generation_state, state)
            self.assertEqual(window.generation_state_label.text(), label)

        with self.assertRaises(ValueError):
            window._set_generation_state("CANCELLED")

    def test_application_activation_rechecks_output_hashes(self):
        window = self.make_window()
        with mock.patch.object(window, "_update_generation_freshness") as refresh:
            window.eventFilter(
                self.app, QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
            )
            self.process_events()
        refresh.assert_called_with(verify_files=True)

    def test_application_activation_marks_externally_edited_output_stale(self):
        workspace = self._sample_workspace()
        generate(
            workspace / "config",
            workspace / "rtl",
            GenerationOptions(quiet=True),
        )
        window = self.make_window()
        window._open_workspace(workspace)
        self.assertEqual(window._generation_state, "UP_TO_DATE")

        generated = workspace / "rtl" / "src" / "pipe_lane_mapper.sv"
        generated.write_text(
            generated.read_text(encoding="utf-8") + "// external edit\n",
            encoding="utf-8",
        )
        window.eventFilter(
            self.app, QtCore.QEvent(QtCore.QEvent.ApplicationActivate)
        )
        self.process_events()

        self.assertEqual(window._generation_state, "STALE")

    def test_bottom_panel_is_log_and_report(self):
        """Two pages, one widget each: the activity log and Config.report().
        The topology used to share the REPORT page under its own sub-header,
        and there used to be a third PROBLEMS page -- both are gone."""
        window = self.make_window()

        self.assertEqual(window.log_tab_btn.text(), "LOG")
        self.assertEqual(window.report_tab_btn.text(), "REPORT")
        self.assertEqual(window.bottom_panel_stack.count(), 2)
        self.assertIs(window.bottom_panel_stack.widget(0), window.log)
        self.assertIs(window.bottom_panel_stack.widget(1), window.topology_summary)
        # LOG is what a fresh window shows -- it is where Generate writes.
        self.assertIs(window.bottom_panel_stack.currentWidget(), window.log)
        self.assertFalse(hasattr(window, "problem_tree"))
        self.assertIsNone(
            window._generation_page.findChild(
                QtWidgets.QPlainTextEdit, "topologySummary"
            )
        )

    def test_report_page_shows_the_topology_report(self):
        workspace = self._sample_workspace()
        window = self.make_window()
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
        window = self.make_window()
        window._open_workspace(workspace)
        self.process_events()

        text = window.topology_summary.toPlainText()
        self.assertIn("Lane groups", text)
        # Built from the live widgets, not the file on disk.
        self.assertNotEqual(text, "Open a workspace to see its lane topology.")

    def test_external_config_change_is_not_overwritten(self):
        workspace = self._sample_workspace()
        window = self.make_window()
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
        window = self.make_window()
        window._open_workspace(workspace)

        target_parent = Path(self.temp.name) / "chosen-location"
        with mock.patch.object(
            window, "_confirm_discard_changes", return_value=True
        ) as confirm, mock.patch.object(
            _NewWorkspaceDialog, "exec_", return_value=QtWidgets.QDialog.Accepted
        ), mock.patch.object(
            _NewWorkspaceDialog,
            "values",
            return_value=("new_quad", str(target_parent)),
        ):
            window._on_new()

        confirm.assert_called_once()
        self.assertEqual(window.current_workspace.name, "new_quad")
        self.assertEqual(window.current_workspace.parent, target_parent)

    def test_new_workspace_dialog_browses_for_a_custom_parent(self):
        initial = Path(self.temp.name) / "initial"
        selected = Path(self.temp.name) / "selected"
        dialog = _NewWorkspaceDialog(initial)
        self.addCleanup(dialog.close)

        self.assertEqual(dialog.location_edit.text(), str(initial))
        with mock.patch.object(
            QtWidgets.QFileDialog,
            "getExistingDirectory",
            return_value=str(selected),
        ) as browse:
            dialog.browse_btn.click()

        browse.assert_called_once()
        self.assertEqual(dialog.location_edit.text(), str(selected))

    def test_invalid_topology_is_reported_without_calling_report(self):
        workspace = self._sample_workspace()
        window = self.make_window()
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
        window = self.make_window()

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
        window = self.make_window()
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

    def test_close_is_blocked_during_generation(self):
        window = self.make_window()
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
        window = self.make_window()
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
        window = self.make_window()
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

    def test_generate_focuses_first_invalid_cell(self):
        workspace = self._sample_workspace()
        window = self.make_window()
        window._open_workspace(workspace)
        table = window.controllers_table.table
        table.item(1, 0).setText(table.item(0, 0).text())
        window._process_live_edits()

        with mock.patch.object(
            window, "_save_before_action"
        ) as save, mock.patch.object(QtCore.QProcess, "start") as start:
            window._run_tool()

        save.assert_not_called()
        start.assert_not_called()
        self.assertEqual(window.tabs.currentIndex(), 0)
        self.assertEqual((table.currentRow(), table.currentColumn()), (0, 0))
        self.assertEqual(window._generation_state, "FAILED")
        self.assertIn("highlighted configuration cell", window.log.toPlainText())

    def test_generate_blocks_unlocated_validation_issue(self):
        workspace = self._sample_workspace()
        window = self.make_window()
        window._open_workspace(workspace)
        issue = ValidationIssue("generation", "formatter settings are invalid")

        with mock.patch.object(
            main_window,
            "load_generation_plan",
            side_effect=ValidationError([issue]),
        ), mock.patch.object(
            window, "_save_before_action"
        ) as save, mock.patch.object(QtCore.QProcess, "start") as start:
            window._run_tool()

        save.assert_not_called()
        start.assert_not_called()
        self.assertEqual(window._generation_state, "FAILED")
        self.assertIn("formatter settings are invalid", window.log.toPlainText())

    def test_live_validation_rejects_shared_phy2mac(self):
        workspace = self._sample_workspace()
        window = self.make_window()
        window._open_workspace(workspace)
        rows = window.signals_table.get_rows()
        row = next(i for i, value in enumerate(rows) if value["direction"] == "phy2mac")
        signal_type = window.signals_table.table.cellWidget(row, 1)
        direction = window.signals_table.table.cellWidget(row, 2)

        signal_type.setCurrentText("shared")
        window._process_live_edits()
        self.assertIn("must be perlane", signal_type.toolTip())
        self.assertIn("must be perlane", direction.toolTip())

        signal_type.setCurrentText("perlane")
        window._process_live_edits()
        self.assertNotIn("must be perlane", signal_type.toolTip())

    def test_undo_redo_restores_complete_editor_snapshot(self):
        workspace = self._sample_workspace()
        window = self.make_window()
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

        window = self.make_window()
        window._open_workspace(workspace)
        window.show()
        window._on_toggle_rtl_preview(True)
        self.process_events()

        before = window._output_signature(workspace)
        modified.write_text("module new; endmodule\n", encoding="utf-8")
        created = rtl / "created.sv"
        created.write_text("module created; endmodule\n", encoding="utf-8")
        after = window._output_signature(workspace)
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
