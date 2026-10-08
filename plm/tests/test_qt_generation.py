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
            page._fill_flags({})
            self.assertEqual(page._preferences()["verible_flags"], DEFAULT_VERIBLE_FLAGS)
            page._fill_flags(None)
            self.assertEqual(page._preferences()["verible_flags"], DEFAULT_VERIBLE_FLAGS)

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

    def test_formatter_parameter_validation_and_detection(self):
        page = SettingsPage(preferences=self.store.preferences())
        self.addCleanup(page.close)
        page._show_section(1)
        page.show()
        wait_for_idle(self.app)
        row = list(page._flag_controls).index("verify_convergence")
        self.assertEqual(page.flag_table.rowHeight(row), 40)
        self.assertFalse(page.flag_table.showGrid())
        self.assertTrue(page.flag_table.property("formatterTable"))
        self.assertEqual(page._flag_controls["verify_convergence"].minimumHeight(), 36)
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

    def test_dpr_sync_linkage_is_one_undoable_edit_and_loaded_errors_survive(self):
        controller, window = self.window()
        page = window.config_page
        page.generation_editor.sel_mode.setCurrentText("comb")
        page.generation_editor.dpr.setChecked(True)
        wait_for_idle(self.app)
        self.assertEqual(page.generation_editor.sel_mode.currentText(), "sync")
        self.assertFalse(page.generation_editor.sel_mode.isEnabled())
        page.undo()
        self.assertEqual(page.generation_editor.sel_mode.currentText(), "comb")
        self.assertFalse(page.generation_editor.dpr.isChecked())
        self.assertTrue(page.generation_editor.sel_mode.isEnabled())
        page.redo()
        self.assertEqual(page.generation_editor.sel_mode.currentText(), "sync")
        bad = page.content()
        bad["gen_flags"]["sel-mode"] = "comb"
        page.set_content(bad)
        self.assertEqual(page.generation_editor.sel_mode.currentText(), "comb")
        with self.assertRaises(ValidationError):
            self.service.validate(page.content())

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
