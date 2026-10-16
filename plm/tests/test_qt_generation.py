"""Formatter persistence, generation option linkage and clock/DPR acceptance."""

import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from PyQt5 import QtCore, QtTest, QtWidgets

from plm.core.validation import ValidationError
from plm.core.verible import DEFAULT_VERIBLE_FLAGS
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.styles.tokens import CONTROL_HEIGHT
from plm.frontend.qt.views.settings_page import SettingsPage


class GenerationIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        isolate_host_formatter(self, self.app)
        self.temp = tempfile.TemporaryDirectory(prefix="plm generation test ")
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name).resolve()
        scaffold_default_content(self.root / "test/demo")
        self.store = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
        self.service = WorkspaceService()

    def window(self):
        controller = AppController(ProjectService(self.root), self.store, self.service)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
            wait_for_idle(self.app)
        window.show()
        wait_for_idle(self.app)
        self.addCleanup(lambda: (window.config_page.mark_saved(), window.close()))
        return controller, window

    def test_formatter_flags_none_empty_and_custom_round_trip(self):
        for flags in (None, {}, {"column_limit": "88", "indentation_spaces": "0"}):
            self.store.save_preferences({"verible_path": "tool with spaces/formatter.exe", "verible_flags": flags})
            wait_for_idle(self.app)
            reloaded = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
            self.assertEqual(reloaded.formatter_preferences()["verible_flags"], flags)
            page = SettingsPage(preferences=reloaded.preferences())
            self.addCleanup(page.close)
            expected = dict(DEFAULT_VERIBLE_FLAGS)
            if flags:
                expected.update(flags)
            self.assertEqual(page._preferences()["verible_flags"], expected)
            self.assertIsNone(page.flag_table)
            page._select_section(1)
            self.assertEqual(page._preferences()["verible_flags"], expected)
            self.assertEqual(page.flag_table.rowCount(), len(DEFAULT_VERIBLE_FLAGS))
            page._fill_flags({})
            self.assertEqual(page._preferences()["verible_flags"], DEFAULT_VERIBLE_FLAGS)
            page._fill_flags(None)
            self.assertEqual(page._preferences()["verible_flags"], DEFAULT_VERIBLE_FLAGS)

    def test_saving_invalid_loaded_flags_reveals_tools_without_prior_visit(self):
        page = SettingsPage(preferences={"verible_flags": {"column_limit": "-1"}})
        self.addCleanup(page.close)
        self.assertIsNone(page.flag_table)
        saved = QtTest.QSignalSpy(page.preferencesSaved)
        page._save_settings()
        self.assertEqual(len(saved), 0)
        self.assertTrue(page.menu_buttons[1].property("selected"))
        self.assertEqual(page._flag_controls["column_limit"].text(), "-1")
        self.assertIn("column_limit", page.settings_status.text())

    def test_startup_auto_detects_formatter_without_overwriting_an_explicit_path(self):
        detected = str(self.root / "tools" / "verible-verilog-format.exe")
        with patch("plm.core.verible.find_verible", return_value=detected) as find:
            controller = AppController(ProjectService(self.root), self.store, self.service)
        find.assert_called_once_with()
        self.assertEqual(controller.workspaces.formatter_provider()["verible_path"], detected)
        self.assertEqual(self.store.formatter_preferences()["verible_path"], "")

        page = controller.create_secondary_page("settings", None)
        self.addCleanup(page.close)
        self.assertEqual(page.verible_path_edit.text(), detected)

        explicit = str(self.root / "custom" / "formatter.exe")
        self.store.save_preferences({"verible_path": explicit})
        with patch(
            "plm.core.verible.find_verible",
            side_effect=AssertionError("explicit formatter path must be preserved"),
        ):
            explicit_controller = AppController(
                ProjectService(self.root), self.store, WorkspaceService()
            )
        self.assertEqual(
            explicit_controller.workspaces.formatter_provider()["verible_path"], explicit
        )

    def test_default_generation_is_independent_of_the_host_formatter(self):
        controller, window = self.window()
        with patch(
            "plm.core.verible.shutil.which", return_value="machine-formatter.bat"
        ), patch(
            "plm.core.verible.subprocess.run",
            side_effect=AssertionError("default UI test invoked the host formatter"),
        ) as run:
            controller.generate_current()
            wait_for_idle(self.app)

        self.assertEqual(controller.generation_state, "up_to_date")
        run.assert_not_called()
        manifest = json.loads(
            (controller.current_project.config_dir.parent / "rtl/manifest.json").read_text()
        )
        self.assertEqual(manifest["formatter"]["engine"], "none")

    def test_bus_type_is_undoable_persisted_and_invalidates_generated_outputs(self):
        controller, window = self.window()
        page = window.config_page
        editor = page.generation_editor
        self.assertEqual(editor.bus_type.currentText(), "bus")
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        editor.bus_type.setCurrentText("flat")
        wait_for_idle(self.app)
        self.assertTrue(page.dirty)
        self.assertEqual(controller.generation_state, "out_of_date")
        page.undo()
        self.assertEqual(editor.bus_type.currentText(), "bus")
        page.redo()
        self.assertEqual(editor.bus_type.currentText(), "flat")
        wait_for_idle(self.app)
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        root = controller.current_project.config_dir.parent
        source = (root / "rtl/src/pipe_lane_mapper_connection.sv").read_text()
        self.assertIn("[NL * ", source)
        self.assertNotIn(" [0:NL-1]", source.split(");", 1)[0])
        self.assertEqual(self.service.load(controller.current_project)["gen_flags"]["bus-type"], "flat")
        controller.reload_project(controller.current_project.name)
        wait_for_idle(self.app)
        self.assertEqual(editor.bus_type.currentText(), "flat")
        self.assertFalse(page.dirty)

    def test_unknown_bus_type_reports_generation_validation_error(self):
        controller, window = self.window()
        payload = window.config_page.content()
        payload["gen_flags"]["bus-type"] = "unknown"
        window.config_page.set_content(payload)
        self.assertEqual(window.config_page.generation_editor.bus_type.currentText(), "unknown")
        with self.assertRaisesRegex(ValidationError, "bus_type"):
            self.service.validate(window.config_page.content())

    def test_prefix_inputs_are_undoable_and_persist_across_reload(self):
        controller, window = self.window()
        page = window.config_page
        editor = page.generation_editor
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        prefixes = {"module_prefix": "soc_", "file_prefix": "rtl_", "macro_prefix": "SOC_"}
        for name, value in prefixes.items():
            getattr(editor, name).setText(value)
        self.assertTrue(page.dirty)
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "out_of_date")
        page.undo()
        self.assertEqual(editor.macro_prefix.text(), "")
        self.assertEqual(editor.module_prefix.text(), "soc_")
        page.redo()
        self.assertEqual(editor.macro_prefix.text(), "SOC_")
        controller.save_current()
        wait_for_idle(self.app)
        self.assertFalse(page.dirty)
        loaded = self.service.load(controller.current_project)["gen_flags"]
        for name, value in prefixes.items():
            self.assertEqual(loaded[name], value)
        controller.reload_project(controller.current_project.name)
        wait_for_idle(self.app)
        for name, value in prefixes.items():
            self.assertEqual(getattr(editor, name).text(), value)
        self.assertFalse(page.dirty)
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        root = controller.current_project.config_dir.parent
        top = root / "rtl/src/rtl_pipe_lane_mapper.sv"
        self.assertIn("module soc_pipe_lane_mapper #(", top.read_text())
        self.assertIn("`ifdef SOC_DUMP_FSDB", (root / "tb/rtl_tb_pipe_lane_mapper.sv").read_text())
        self.assertFalse((root / "rtl/src/pipe_lane_mapper.sv").exists())
        self.assertIn(top.resolve(), self.service.output_files(controller.current_project))
        controller.reload_project(controller.current_project.name)
        wait_for_idle(self.app)
        # Explicit reload retains its existing policy of requesting regeneration.
        for name, value in prefixes.items():
            self.assertEqual(getattr(editor, name).text(), value)
        self.assertEqual(self.service.output_state(
            controller.current_project, page.content(), use_disk=True,
        ), "up_to_date")
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")

    def test_invalid_prefix_cannot_save_over_a_valid_workspace(self):
        controller, window = self.window()
        signature = self.service.signature(controller.current_project)
        window.config_page.generation_editor.file_prefix.setText("../escape/")
        # Unlike an invalid table cell, this can never be written: the value
        # becomes part of output file paths.
        with self.assertRaisesRegex(ValueError, "file_prefix"):
            self.service.save(controller.current_project, window.config_page.content())
        self.assertEqual(self.service.signature(controller.current_project), signature)

    def test_formatter_parameter_validation_and_detection(self):
        page = SettingsPage(preferences=self.store.preferences())
        self.addCleanup(page.close)
        page._show_section(1)
        page.formatter_group.setCurrentIndex(3)
        page.show()
        wait_for_idle(self.app)
        row = list(page._flag_controls).index("verify_convergence")
        self.assertEqual(page.flag_table.rowHeight(row), CONTROL_HEIGHT)
        self.assertFalse(page.flag_table.showGrid())
        self.assertTrue(page.flag_table.property("formatterTable"))
        self.assertEqual(page._flag_controls["verify_convergence"].minimumHeight(), CONTROL_HEIGHT - 4)
        self.assertGreaterEqual(
            page.flag_table.rowHeight(row),
            page._flag_controls["verify_convergence"].minimumHeight(),
        )
        spy = QtTest.QSignalSpy(page.preferencesSaved)
        page._flag_controls["column_limit"].setText("invalid")
        page.save_settings_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(len(spy), 0)
        self.assertIn("column_limit", page.settings_status.text())
        page._flag_controls["column_limit"].setText("96")
        page.save_settings_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(spy[0][0]["verible_flags"]["column_limit"], "96")
        with patch("plm.frontend.qt.views.settings_page.find_verible", return_value="C:/tools with spaces/verible.exe"):
            page._detect_verible()
            wait_for_idle(self.app)
        self.assertEqual(page.verible_path_edit.text(), "C:/tools with spaces/verible.exe")

    def test_formatter_settings_reach_subprocess_and_invalidate_outputs(self):
        executable = self.root / "tool with spaces" / "verible-verilog-format.exe"
        executable.parent.mkdir()
        executable.write_bytes(b"mock formatter binary")
        self.store.save_preferences({"verible_path": str(executable), "verible_flags": {"column_limit": "88"}})
        wait_for_idle(self.app)
        controller, window = self.window()
        calls = []
        def formatter(args, **kwargs):
            calls.append((args, kwargs))
            return subprocess.CompletedProcess(args, 0, stdout=kwargs["input"], stderr=b"")
        with patch("plm.core.verible.subprocess.run", side_effect=formatter):
            controller.generate_current()
            wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertTrue(calls)
        for args, kwargs in calls:
            self.assertEqual(args, [str(executable), "--column_limit=88", "--inplace", "-"])
            self.assertIsInstance(kwargs["input"], bytes)
            self.assertNotIn("shell", kwargs)
        controller.save_preferences({**self.store.preferences(), "verible_flags": {"column_limit": "96"}})
        wait_for_idle(self.app)
        self.assertFalse(window.config_page.dirty)
        self.assertEqual(controller.generation_state, "out_of_date")
        with patch("plm.core.verible.subprocess.run", side_effect=formatter):
            controller.generate_current()
            wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertIn("--column_limit=96", calls[-1][0])
        manifest = json.loads((controller.current_project.config_dir.parent / "rtl/manifest.json").read_text())
        self.assertEqual(manifest["formatter"]["flags"], {"column_limit": "96"})
        self.assertNotIn("verible", (controller.current_project.config_dir / "gen_flags.txt").read_text())

    def test_missing_explicit_formatter_keeps_valid_generation_and_logs_fallback(self):
        self.store.save_preferences({"verible_path": str(self.root / "missing.exe"), "verible_flags": {}})
        wait_for_idle(self.app)
        controller, window = self.window()
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertIn("Verible 不可用", window.log_panel.output.toPlainText())

    def test_dpr_alone_decides_the_select_mode_and_is_one_undoable_edit(self):
        controller, window = self.window()
        page = window.config_page
        self.assertEqual(self.service.validate(page.content()).options.sel_mode, "comb")
        page.generation_editor.dpr.setChecked(True)
        wait_for_idle(self.app)
        self.assertEqual(self.service.validate(page.content()).options.sel_mode, "sync")
        page.undo()
        self.assertFalse(page.generation_editor.dpr.isChecked())
        page.redo()
        self.assertTrue(page.generation_editor.dpr.isChecked())
        # A sel-mode key left in an older gen_flags.txt is ignored.
        legacy = page.content()
        legacy["gen_flags"]["sel-mode"] = "comb"
        page.set_content(legacy)
        self.assertNotIn("sel-mode", page.content()["gen_flags"])
        self.assertEqual(self.service.validate(page.content()).options.sel_mode, "sync")

    def test_topology_error_marks_the_controller_row_not_the_ctrl_id(self):
        controller, window = self.window()
        page = window.config_page
        payload = page.content()
        payload["controllers"] = [
            {"ctrl_id": "1", "ctrl_name": "Ctrl1", "max_width": "1"},
            {"ctrl_id": "0", "ctrl_name": "Ctrl10", "max_width": "9"},
        ]
        payload["mapping"] = {"lane_count": 2, "rows": [{"mode": "0", "lane0": "0-0", "lane1": "1-0"}]}
        page.set_content(payload)
        page._mark_dirty()
        controller.validate_current()
        wait_for_idle(self.app)
        table = page.controllers_editor.table
        marked = {row for row in range(table.rowCount()) if table.item(row, 2).toolTip()}
        self.assertEqual(marked, {1})
        self.assertIn("Ctrl10", table.item(1, 2).toolTip())

    def test_sidebar_follows_a_switch_that_saved_first(self):
        scaffold_default_content(self.root / "test/other")
        controller, window = self.window()
        page, nav = window.config_page, window.nav_panel
        first = controller.current_name
        other = "other" if first == "demo" else "demo"
        page.controllers_editor.table.item(0, 1).setText("Edited")
        wait_for_idle(self.app)
        self.assertTrue(page.dirty)
        with patch.object(QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.Save):
            nav.project_list.select_project(other)
            wait_for_idle(self.app)
        self.assertEqual(controller.current_name, other)
        self.assertEqual(nav.project_list.selected_project_name, other)
        self.assertEqual(nav.current_project_name, other)

    def test_failed_header_rename_restores_the_title(self):
        scaffold_default_content(self.root / "test/other")
        controller, window = self.window()
        header = window.config_page.header
        first = controller.current_name
        taken = "other" if first == "demo" else "demo"
        header.enter_edit_mode()
        header.title_edit.setText(taken)
        header.save_title()
        wait_for_idle(self.app)
        self.assertEqual(controller.current_name, first)
        self.assertEqual(header.title_label.text(), first)
        self.assertTrue((self.root / "test" / first).is_dir())

    def test_generate_bar_stays_visible_below_the_scrolled_form(self):
        controller, window = self.window()
        page = window.config_page
        page.tabs.setCurrentIndex(3)
        wait_for_idle(self.app)
        tab = page.tabs.widget(3)
        editor = page.generation_editor
        button = editor.generate_btn
        self.assertFalse(tab.scroll.isAncestorOf(button))
        controls = (editor.arch, editor.pclk_mode, editor.bus_type, *editor._prefix_edits.values())
        for width, height in ((960, 640), (1600, 1000)):
            window.resize(width, height)
            wait_for_idle(self.app)
            with self.subTest(size=(width, height)):
                positions = [control.mapTo(editor, QtCore.QPoint()).x() for control in controls]
                self.assertEqual(len(set(positions)), 1, f"field starts: {positions}")
                for control in controls:
                    self.assertGreater(control.width(), 0)
                    self.assertLessEqual(control.width(), 360)
                    self.assertEqual(control.height(), 32)
                self.assertEqual(button.size(), QtCore.QSize(120, 32))
                bottom = button.mapTo(tab, QtCore.QPoint(0, button.height())).y()
                self.assertLessEqual(bottom, tab.height())
                self.assertTrue(button.isVisible())
                before = button.mapTo(tab, QtCore.QPoint())
                tab.scroll.verticalScrollBar().setValue(tab.scroll.verticalScrollBar().maximum())
                self.app.processEvents()
                self.assertEqual(button.mapTo(tab, QtCore.QPoint()), before)

    def test_typing_a_prefix_is_one_undo_step(self):
        controller, window = self.window()
        page = window.config_page
        start = page._history_index
        for character in "soc_top":
            page.generation_editor.module_prefix.insert(character)
        self.assertEqual(page._history_index, start + 1)
        page.generation_editor.file_prefix.insert("r")
        self.assertEqual(page._history_index, start + 2)
        page.undo()
        page.undo()
        self.assertEqual(page.generation_editor.module_prefix.text(), "")
        page.redo()
        self.assertEqual(page.generation_editor.module_prefix.text(), "soc_top")
        # Typing again after an undo/redo starts a new step.
        page.generation_editor.module_prefix.insert("x")
        self.assertEqual(page._history_index, start + 2)

    def test_new_mode_row_starts_valid(self):
        controller, window = self.window()
        page = window.config_page
        before = page.mapping_editor.rows()
        page.mapping_editor.add_row()
        rows = page.mapping_editor.rows()
        self.assertEqual(len(rows), len(before) + 1)
        self.assertEqual(rows[-1]["mode"], str(len(before)))
        self.assertEqual(
            {key: value for key, value in rows[-1].items() if key != "mode"},
            {key: value for key, value in before[-1].items() if key != "mode"},
        )
        self.service.validate(page.content())

    def test_generation_log_does_not_swap_process_stdout(self):
        import sys
        controller, window = self.window()
        seen = []
        real_generate = self.service.generate

        def spy(*args, **kwargs):
            before = sys.stdout
            result = real_generate(*args, **kwargs)
            seen.append(sys.stdout is before)
            return result

        with patch.object(self.service, "generate", side_effect=spy), \
                patch("plm.core.exporter.print", create=True) as printed:
            _result, _files, report = self.service.generate(
                controller.current_project, window.config_page.content()
            )
        self.assertEqual(seen, [True])
        printed.assert_not_called()
        self.assertIn("generated", report)

    def test_generation_status_strip_does_not_outlive_its_project(self):
        scaffold_default_content(self.root / "test/other")
        controller, window = self.window()
        strip = window.log_panel.status_label
        controller.generate_current()
        wait_for_idle(self.app)
        self.assertIn("生成完成", strip.text())
        other = "other" if controller.current_name == "demo" else "demo"
        window.nav_panel.project_list.select_project(other)
        wait_for_idle(self.app)
        self.assertEqual(controller.current_name, other)
        self.assertEqual(strip.text(), "")
        self.assertFalse(window.log_panel.status_bar.isVisible())

    def test_long_project_name_is_elided_with_the_full_name_on_hover(self):
        long_name = "a_rather_long_project_name_for_the_sidebar_to_elide"
        scaffold_default_content(self.root / "test" / long_name)
        controller, window = self.window()
        row = next(w for w in window.nav_panel.project_list.project_widgets if w.project_name == long_name)
        row.project_name_label.repaint()
        self.assertEqual(row.project_name_label.text(), long_name)
        self.assertEqual(row.header.toolTip(), long_name)
        short = next(w for w in window.nav_panel.project_list.project_widgets if w.project_name == "demo")
        short.project_name_label.repaint()
        self.assertEqual(short.header.toolTip(), "")

    def test_documentation_code_fence_does_not_restyle_its_neighbours(self):
        from PyQt5 import QtGui
        from plm.frontend.qt.views.documentation_page import DocumentationPage

        page = DocumentationPage()
        self.addCleanup(page.close)
        document = QtGui.QTextDocument()
        document.setMarkdown("intro `x`:\n\n```bash\none\ntwo\n```\n\nafter\n")
        page._format_document(document)
        blocks = []
        block = document.begin()
        while block.isValid():
            blocks.append((block.text(), bool(block.blockFormat().property(QtGui.QTextFormat.BlockCodeFence)),
                           block.blockFormat().background().style() != QtCore.Qt.NoBrush))
            block = block.next()
        # The browser paints rounded code backgrounds beneath native text.
        # Block brushes stay empty so they cannot cover the rounded corners.
        self.assertEqual(blocks, [
            ("intro x:", False, False), ("one", True, False), ("two", True, False), ("after", False, False),
        ])

    def test_error_summary_names_the_first_error_and_jumps_to_it(self):
        controller, window = self.window()
        page = window.config_page
        summary = page.error_summary
        self.assertFalse(summary.isVisible())
        page.mapping_editor.table.item(0, 2).setText("9-0")
        page.controllers_editor.table.item(0, 1).setText("bad name")
        controller.validate_current()
        wait_for_idle(self.app)
        self.assertTrue(summary.isVisible())
        self.assertIn("ctrl_name", summary.text())
        self.assertNotIn("\n", summary.text())
        page.tabs.setCurrentIndex(3)
        QtTest.QTest.mouseClick(summary, QtCore.Qt.LeftButton)
        self.assertEqual(page.tabs.currentIndex(), 0)
        self.assertEqual(page.controllers_editor.table.currentColumn(), 1)
        page.undo()
        page.undo()
        controller.validate_current()
        wait_for_idle(self.app)
        self.assertFalse(summary.isVisible())

    def test_editors_are_locked_until_a_project_is_open(self):
        controller, window = self.window()
        page = window.config_page
        editors = (page.controllers_editor, page.mapping_editor, page.signals_editor, page.generation_editor)
        self.assertTrue(all(editor.isEnabled() for editor in editors))
        controller.archive_project(controller.current_name)
        wait_for_idle(self.app)
        self.assertIsNone(controller.current_project)
        self.assertFalse(any(editor.isEnabled() for editor in editors))
        self.assertTrue(page.tabs.isEnabled())
        self.assertFalse(page.generation_editor.generate_btn.isEnabled())
        self.assertFalse(page.error_summary.isVisible())

    def test_generate_sits_left_of_the_status_clear_of_the_drawer(self):
        controller, window = self.window()
        page = window.config_page
        page.tabs.setCurrentIndex(3)
        page.toggle_artifacts()
        QtTest.QTest.qWait(500)
        wait_for_idle(self.app)
        editor = page.generation_editor
        self.assertLess(editor.generate_btn.x(), editor.status_label.x())
        button_right = editor.generate_btn.mapTo(page, QtCore.QPoint(editor.generate_btn.width(), 0)).x()
        self.assertLess(button_right, page.artifacts_panel.geometry().left())

    def test_both_pclk_modes_generate_with_and_without_dpr(self):
        controller, window = self.window()
        editor = window.config_page.generation_editor
        for arch in ("original_pipe", "serdes"):
            for dpr in (False, True):
                with self.subTest(arch=arch, dpr=dpr):
                    editor.arch.setCurrentText(arch)
                    editor.dpr.setChecked(dpr)
                    wait_for_idle(self.app)
                    controller.generate_current()
                    wait_for_idle(self.app)
                    self.assertEqual(controller.generation_state, "up_to_date")
                    top = (controller.current_project.config_dir.parent / "rtl/src/pipe_lane_mapper.sv").read_text()
                    self.assertEqual(bool(re.search(r"\binput\s+logic\s+dpr_pclk\s*,", top)), arch == "serdes" and dpr)
                    self.assertEqual(bool(re.search(r"\boutput\s+logic\s+dpr_pclk\s*,", top)), arch == "original_pipe" and dpr)
                    self.assertNotIn("dft_mode", top)
                    self.assertEqual(editor.pclk_mode.currentText(), "pclk_as_phy_input" if arch == "serdes" else "pclk_as_phy_output")
        self.assertFalse(editor.pclk_mode.isEnabled())
        self.assertEqual(
            editor.pclk_mode.toolTip(),
            "PCLK 模式由 PHY 架构自动决定。",
        )
        editor.arch.setCurrentText("original_pipe")
        self.assertEqual(editor.pclk_mode.currentText(), "pclk_as_phy_output")


if __name__ == "__main__":
    unittest.main()
