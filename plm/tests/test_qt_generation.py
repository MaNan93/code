"""Formatter persistence, generation option linkage and clock/DPR acceptance."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt5 import QtCore, QtTest, QtWidgets

from plm.core.validation import ValidationError
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.views.settings_page import SettingsPage


class GenerationIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="plm generation test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        scaffold_default_content(self.root / "test/demo")
        self.store = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
        self.service = WorkspaceService()

    def window(self):
        controller = AppController(ProjectService(self.root), self.store, self.service)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.show()
        self.app.processEvents()
        self.addCleanup(lambda: (window.config_page.mark_saved(), window.close()))
        return controller, window

    def test_formatter_flags_none_empty_and_custom_round_trip(self):
        for flags in (None, {}, {"column_limit": "88", "indentation_spaces": "0"}):
            self.store.save_preferences({"verible_path": "tool with spaces/formatter.exe", "verible_flags": flags})
            reloaded = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
            self.assertEqual(reloaded.formatter_preferences()["verible_flags"], flags)
            page = SettingsPage(preferences=reloaded.preferences())
            self.addCleanup(page.close)
            page.font_size_spin.setValue(15)
            self.assertEqual(page._preferences()["verible_flags"], flags)
            page._fill_flags({})
            self.assertEqual(page._preferences()["verible_flags"], {})
            page._fill_flags(None)
            self.assertIsNone(page._preferences()["verible_flags"])

    def test_formatter_parameter_validation_and_detection(self):
        page = SettingsPage(preferences=self.store.preferences())
        self.addCleanup(page.close)
        spy = QtTest.QSignalSpy(page.preferencesSaved)
        page._flag_controls["column_limit"].setText("invalid")
        page.save_settings_btn.click()
        self.assertEqual(len(spy), 0)
        self.assertIn("column_limit", page.settings_status.text())
        page._flag_controls["column_limit"].setText("96")
        page.save_settings_btn.click()
        self.assertEqual(spy[0][0]["verible_flags"]["column_limit"], "96")
        with patch("plm.frontend.qt.views.settings_page.find_verible", return_value="C:/tools with spaces/verible.exe"):
            page._detect_verible()
        self.assertEqual(page.verible_path_edit.text(), "C:/tools with spaces/verible.exe")

    def test_formatter_settings_reach_subprocess_and_invalidate_outputs(self):
        executable = self.root / "tool with spaces" / "verible-verilog-format.exe"
        executable.parent.mkdir()
        executable.write_bytes(b"mock formatter binary")
        self.store.save_preferences({"verible_path": str(executable), "verible_flags": {"column_limit": "88"}})
        controller, window = self.window()
        calls = []
        def formatter(args, **kwargs):
            calls.append((args, kwargs))
            return subprocess.CompletedProcess(args, 0, stdout=kwargs["input"], stderr=b"")
        with patch("plm.core.verible.subprocess.run", side_effect=formatter):
            controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertTrue(calls)
        for args, kwargs in calls:
            self.assertEqual(args, [str(executable), "--column_limit=88", "--inplace", "-"])
            self.assertIsInstance(kwargs["input"], bytes)
            self.assertNotIn("shell", kwargs)
        controller.save_preferences({**self.store.preferences(), "verible_flags": {"column_limit": "96"}})
        self.assertFalse(window.config_page.dirty)
        self.assertEqual(controller.generation_state, "out_of_date")
        with patch("plm.core.verible.subprocess.run", side_effect=formatter):
            controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertIn("--column_limit=96", calls[-1][0])
        manifest = json.loads((controller.current_project.config_dir.parent / "rtl/manifest.json").read_text())
        self.assertEqual(manifest["formatter"]["flags"], {"column_limit": "96"})
        self.assertNotIn("verible", (controller.current_project.config_dir / "gen_flags.txt").read_text())

    def test_missing_explicit_formatter_keeps_valid_generation_and_logs_fallback(self):
        self.store.save_preferences({"verible_path": str(self.root / "missing.exe"), "verible_flags": {}})
        controller, window = self.window()
        controller.generate_current()
        self.assertEqual(controller.generation_state, "up_to_date")
        self.assertIn("Verible 不可用", window.log_panel.output.toPlainText())

    def test_dpr_sync_linkage_is_one_undoable_edit_and_loaded_errors_survive(self):
        controller, window = self.window()
        page = window.config_page
        page.generation_editor.sel_mode.setCurrentText("comb")
        page.generation_editor.dpr.setChecked(True)
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
                    controller.generate_current()
                    self.assertEqual(controller.generation_state, "up_to_date")
                    top = (controller.current_project.config_dir.parent / "rtl/src/pipe_lane_mapper.sv").read_text()
                    self.assertEqual("input logic dpr_pclk," in top, arch == "serdes" and dpr)
                    self.assertEqual("output logic dpr_pclk," in top, arch == "original_pipe" and dpr)
                    self.assertNotIn("dft_mode", top)
                    self.assertEqual(editor.pclk_mode.currentText(), "pclk_as_phy_input" if arch == "serdes" else "pclk_as_phy_output")
        editor.pclk_mode.setCurrentText("pclk_as_phy_output")
        self.assertEqual(editor.arch.currentText(), "original_pipe")


if __name__ == "__main__":
    unittest.main()
