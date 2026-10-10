"""Workflow regression tests using disposable files and hidden Qt windows."""

import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

os.environ.setdefault(
    "QT_QPA_PLATFORM", "windows" if sys.platform == "win32" else "offscreen"
)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from fizz.frontend.qt.main_window import MainWindow
from fizz.frontend.qt.services import tasks
from fizz.frontend.qt.widgets.preferences_dialog import PreferencesDialog
from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from fizz import core


class FrontendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="fizz-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = core.FizzConfig(str(self.root / "fizz.ini"))
        self.settings = QtCore.QSettings(
            str(self.root / "desktop.ini"), QtCore.QSettings.IniFormat
        )
        self.window = self.make_window()
        self.controller = self.window.controller
        self.controller.stop_timers()
        self.merge = self.window.pages["merge"]
        self.rlskit = self.window.pages["rlskit"]

    def make_window(self):
        window = MainWindow(
            config=self.config, settings=self.settings, script_dir=str(self.root)
        )
        window.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        window.show()
        self.app.processEvents()
        self.addCleanup(self.dispose_window, window)
        return window

    def dispose_window(self, window):
        for worker in window.controller.active_workers():
            worker.requestInterruption()
            worker.wait(5000)
        window.close()
        window.deleteLater()
        self.app.processEvents()

    def wait_until(self, predicate, timeout=3):
        deadline = time.monotonic() + timeout
        while not predicate() and time.monotonic() < deadline:
            self.app.processEvents()
            QtTest.QTest.qWait(10)
        self.assertTrue(predicate(), "Qt workflow did not finish")

    def prepare_sources(self):
        (self.root / "defs.svh").write_text("`define DATA_WIDTH 8\n", encoding="utf-8")
        (self.root / "top.sv").write_text(
            '`include "defs.svh"\nmodule top();\nendmodule\n', encoding="utf-8"
        )
        (self.root / "top_tb.sv").write_text(
            "module top_tb(); endmodule\n", encoding="utf-8"
        )
        msg = self.root / "generalMessage.txt"
        msg.write_text(
            'included file "defs.svh"\nsource file "top.sv"\nsource file "top_tb.sv"\nsource file "top.sv"\n',
            encoding="utf-8",
        )
        self.merge.msg_path_edit.setText(str(msg))
        self.controller._parse()

    def test_navigation_retains_page_values(self):
        self.merge.file_filter_edit.setText("*_tb.sv")
        for key, button in self.window.nav_panel.buttons.items():
            button.click()
            self.assertEqual(self.window.current_workflow, key)
            self.assertIs(
                self.window.view_stack.currentWidget(), self.window.pages[key]
            )
        self.assertEqual(self.merge.file_filter_edit.text(), "*_tb.sv")

    def test_shortcuts_select_each_workflow(self):
        for index, key in enumerate(self.window.pages, 1):
            shortcut = next(
                s
                for s in self.window.shortcuts
                if s.key().toString() == f"Ctrl+{index}"
            )
            shortcut.activated.emit()
            self.assertEqual(self.window.current_workflow, key)

    def test_sidebar_animation_preserves_selection_and_centers_icons(self):
        nav = self.window.nav_panel
        self.window.select_workflow("rlskit")
        nav.toggle_collapse()
        self.wait_until(
            lambda: nav.animation.state() == QtCore.QAbstractAnimation.Stopped
        )
        self.assertEqual(nav.width(), 56)
        for button in [*nav.buttons.values(), nav.settings_btn, nav.docs_btn]:
            self.assertEqual(button.text(), "")
            self.assertEqual(button.x() + button.width() / 2, 28)
            self.assertTrue(button.toolTip())
        nav.toggle_collapse()
        self.wait_until(
            lambda: nav.animation.state() == QtCore.QAbstractAnimation.Stopped
        )
        self.assertEqual(nav.width(), 260)
        self.assertTrue(nav.buttons["rlskit"].isChecked())

    def test_layout_persistence_restores_page_sidebar_and_size(self):
        self.window.resize(1120, 740)
        self.window.select_workflow("vcs")
        self.window.nav_panel.set_collapsed(True, animate=False)
        self.window.close()
        restored = self.make_window()
        self.assertEqual(restored.current_workflow, "vcs")
        self.assertTrue(restored.nav_panel.is_collapsed)
        self.assertEqual(restored.size(), QtCore.QSize(1120, 740))

    def test_minimum_window_can_scroll_to_obfuscate_action(self):
        self.window.resize(900, 640)
        self.window.select_workflow("obf")
        self.app.processEvents()
        page = self.window.pages["obf"]
        self.assertGreater(page.scroll.verticalScrollBar().maximum(), 0)
        page.scroll.ensureWidgetVisible(page.obf_run_btn)
        self.app.processEvents()
        action_rect = QtCore.QRect(
            page.obf_run_btn.mapTo(page.scroll.viewport(), QtCore.QPoint()),
            page.obf_run_btn.size(),
        )
        self.assertTrue(page.scroll.viewport().rect().contains(action_rect))
        self.assertGreaterEqual(page.log_panel.height(), 130)

    def test_default_window_shows_obfuscate_action_without_scrolling(self):
        self.window.select_workflow("obf")
        self.app.processEvents()
        page = self.window.pages["obf"]
        action_rect = QtCore.QRect(
            page.obf_run_btn.mapTo(page.scroll.viewport(), QtCore.QPoint()),
            page.obf_run_btn.size(),
        )
        self.assertTrue(page.scroll.viewport().rect().contains(action_rect))

    def test_merge_parse_filter_and_restore_order(self):
        self.prepare_sources()
        self.assertEqual(self.merge.file_listwidget.count(), 3)
        self.merge.file_filter_edit.setText("*_tb.sv")
        self.controller._apply_filter()
        self.assertEqual(
            self.controller.included_files + self.controller.source_files,
            ["defs.svh", "top.sv"],
        )
        self.merge.file_filter_edit.clear()
        self.controller._apply_filter()
        self.assertEqual(self.controller.source_files, ["top.sv", "top_tb.sv"])

    def test_merge_worker_writes_real_output_and_updates_ui(self):
        self.prepare_sources()
        self.merge.file_filter_edit.setText("*_tb.sv")
        self.controller._apply_filter()
        self.merge.merge_btn.click()
        self.assertFalse(self.merge.merge_btn.isEnabled())
        self.wait_until(lambda: self.merge.merge_btn.isEnabled())
        self.controller._merge_worker.wait(1000)
        text = (self.root / "one.sv").read_text(encoding="utf-8")
        self.assertIn("`define DATA_WIDTH", text)
        self.assertIn("module top()", text)
        self.assertNotIn("module top_tb", text)
        self.assertIn("合并完成", self.merge.merge_status_label.text())
        self.assertEqual(self.merge.merge_progress.value(), 2)

    def test_merge_failure_recovers_button(self):
        self.prepare_sources()
        with (
            patch.object(core, "merge_files", side_effect=OSError("write denied")),
            patch.object(QtWidgets.QMessageBox, "critical") as error,
        ):
            self.merge.merge_btn.click()
            self.wait_until(lambda: self.merge.merge_btn.isEnabled())
            self.assertIn("write denied", error.call_args.args[-1])
            self.assertEqual(self.merge.merge_status_label.text(), "合并失败")

    def test_vcs_worker_arguments_logs_and_recovery(self):
        page = self.window.pages["vcs"]
        source, key = self.root / "source.sv", self.root / "key.txt"
        source.write_text("module top(); endmodule", encoding="utf-8")
        key.write_text("key", encoding="utf-8")
        page.vcs_src_edit.setText(str(source))
        page.vcs_key_edit.setText(str(key))

        def run(src, key_path, options, on_line):
            on_line("VCS ready\n")
            return 0

        with patch.object(core, "run_vcs_protect", side_effect=run) as tool:
            page.vcs_run_btn.click()
            self.wait_until(lambda: page.vcs_run_btn.isEnabled())
        self.assertEqual(tool.call_args.args[:2], (str(source), str(key)))
        self.assertIn("VCS ready", page.vcs_log.toPlainText())
        self.assertIn("退出码: 0", page.vcs_log.toPlainText())

    def test_obfuscator_defaults_and_real_worker_wiring(self):
        page = self.window.pages["obf"]
        source = self.root / "input.sv"
        source.write_text("module input(); endmodule", encoding="utf-8")
        page.obf_src_edit.setText(str(source))
        self.assertEqual(page.obf_out_edit.text(), str(self.root / "input_obf.sv"))

        def run(src, out, save_map, load_map, tool, on_line):
            Path(out).write_text("module a(); endmodule", encoding="utf-8")
            on_line("Obfuscate ready\n")
            return 0

        with patch.object(core, "run_obfuscate", side_effect=run):
            page.obf_run_btn.click()
            self.wait_until(lambda: page.obf_run_btn.isEnabled())
        self.assertTrue((self.root / "input_obf.sv").is_file())
        self.assertIn("Obfuscate ready", page.obf_log.toPlainText())

    def test_preferences_apply_and_preserve_whitelist(self):
        self.window.pages["obf"].obf_whitelist_edit.setText(
            str(self.root / "tokens.map")
        )
        values = {
            "exclude_dirs": "testbench",
            "exclude_files": "*_tb.sv",
            "vcs_key_file": "key.txt",
            "vcs_options": "-ipopt=overwrite",
            "obfuscator_path": "verible-custom",
            "ftp_url": "ftp://example/releases/",
            "ftp_username": "user",
            "ftp_password": "secret",
        }
        dialog = Mock(action="save")
        dialog.exec_.return_value = QtWidgets.QDialog.Accepted
        dialog.values.return_value = values
        with patch(
            "fizz.frontend.qt.controllers.app_controller.PreferencesDialog",
            return_value=dialog,
        ):
            self.controller._open_preferences_dialog()
        saved = self.config.load()
        self.assertEqual(saved["obfuscator_path"], "verible-custom")
        self.assertEqual(saved["ftp_username"], "user")
        self.assertEqual(saved["whitelist_file"], str(self.root / "tokens.map"))

    def test_preferences_password_mask_and_control_heights(self):
        dialog = PreferencesDialog({}, lambda value: str(self.root), self.window)
        self.assertEqual(dialog.ftp_password.echoMode(), QtWidgets.QLineEdit.Password)
        self.assertEqual(dialog.ftp_password.height(), 40)
        dialog.deleteLater()

    def test_rlskit_preview_and_release_note_roundtrip(self):
        self.rlskit.rlskit_suffix_edit.setText("V2P1")
        self.controller._update_rlskit_preview()
        self.assertEqual(
            self.rlskit.rlskit_dst_edit.text(),
            str(self.root) + core.full_suffix("V2P1"),
        )
        self.rlskit.rn_text.setPlainText("版本说明\n修复接口\n")
        with patch.object(QtWidgets.QMessageBox, "information"):
            self.controller._save_release_note()
        self.rlskit.rn_text.clear()
        self.controller._load_release_note()
        self.assertIn("修复接口", self.rlskit.rn_text.toPlainText())

    def test_rlskit_progress_supports_archives_over_two_gib(self):
        self.controller._on_rlskit_upload_progress(3 * 1024**3, 4 * 1024**3)
        self.assertEqual(self.rlskit.rlskit_upload_progress.value(), 75)
        self.assertTrue(self.rlskit.rlskit_cancel_btn.isEnabled())
        self.assertIn("3072.0/4096.0 MB", self.rlskit.rlskit_upload_status.text())
        self.controller._on_rlskit_upload_progress(0, 0)
        self.assertEqual(self.rlskit.rlskit_upload_progress.maximum(), 0)
        self.controller._on_rlskit_upload_progress(1, 2)
        self.assertEqual(self.rlskit.rlskit_upload_progress.value(), 50)

    def test_rlskit_cancel_requests_interruption(self):
        worker = Mock()
        worker.isRunning.return_value = True
        self.controller._rlskit_worker = worker
        self.controller._on_rlskit_upload_progress(1, 2)
        self.rlskit.rlskit_cancel_btn.click()
        worker.requestInterruption.assert_called_once()
        self.assertFalse(self.rlskit.rlskit_cancel_btn.isEnabled())
        worker.isRunning.return_value = False
        self.controller._on_rlskit_cancelled()
        self.assertTrue(self.rlskit.rlskit_run_btn.isEnabled())
        self.assertEqual(self.rlskit.rlskit_upload_status.text(), "上传已取消")

    def test_existing_remote_archive_prompts_and_reuses_archive(self):
        self.controller._rlskit_run_ctx = (str(self.root), "V1P0", "user", "password")
        result = core.RLskitResult()
        result.upload_skipped = True
        result.tar_file = str(self.root / "built.tar.gz")
        result.target_url = "ftp://example/built.tar.gz"
        with (
            patch.object(
                QtWidgets.QMessageBox,
                "question",
                return_value=QtWidgets.QMessageBox.Yes,
            ),
            patch.object(self.controller, "_start_rlskit_overwrite") as retry,
        ):
            self.controller._on_rlskit_done(result)
        retry.assert_called_once_with(
            result.tar_file, result.target_url, "user", "password"
        )
        with (
            patch.object(
                QtWidgets.QMessageBox, "question", return_value=QtWidgets.QMessageBox.No
            ),
            patch.object(self.controller, "_start_rlskit_overwrite") as retry,
        ):
            self.controller._on_rlskit_done(result)
        retry.assert_not_called()

    def test_rlskit_worker_completion_updates_checksum_and_history(self):
        result = core.RLskitResult()
        result.tar_file = str(self.root / "package.tar.gz")
        result.target_url = "ftp://example/package.tar.gz"
        result.cksum = "12345 99 package.tar.gz"
        result.upload_ok = True

        def package(*args, on_line, on_progress, should_cancel):
            on_line("Package ready\n")
            on_progress(3 * 1024**3, 4 * 1024**3)
            return result

        with patch.object(core, "run_rlskit_package", side_effect=package):
            self.rlskit.rlskit_run_btn.click()
            self.wait_until(lambda: self.rlskit.rlskit_run_btn.isEnabled())
        self.assertEqual(self.rlskit.rlskit_upload_progress.value(), 100)
        self.assertEqual(self.rlskit.rlskit_upload_status.text(), "上传完成")
        self.controller._copy_cksum()
        self.assertEqual(self.app.clipboard().text(), result.cksum)
        self.assertTrue(self.config.load_rlskit_for_dir(str(self.root)))

    def test_postsim_search_and_analysis_uses_full_item_path(self):
        nested = self.root / "logs"
        nested.mkdir()
        log = nested / "timing.log"
        log.write_text(
            "Timing violation in tb.dut\nsetup violation\n", encoding="utf-8"
        )
        page = self.window.pages["postsim"]
        self.controller._postsim_search()
        self.assertEqual(page.postsim_list.count(), 1)
        page.postsim_list.setCurrentRow(0)
        with patch(
            "fizz.frontend.qt.controllers.app_controller.TimingViolationDialog"
        ) as dialog:
            page.analyze_btn.click()
        self.assertEqual(dialog.call_args.args[0], str(log))
        self.assertEqual(dialog.call_args.args[1][0]["instance"], "tb.dut")

    def test_logs_preserve_plaintext_and_clear(self):
        page = self.window.pages["vcs"]
        self.controller._log_append(page.vcs_log, "<top> & input\n")
        self.assertIn("<top> & input", page.vcs_log.toPlainText())
        page.log_panel.clear_btn.click()
        self.assertEqual(page.vcs_log.toPlainText(), "")

    def test_close_is_deferred_while_worker_is_running(self):
        worker = Mock()
        worker.isRunning.return_value = True
        self.controller._merge_worker = worker
        event = QtGui.QCloseEvent()
        self.window.closeEvent(event)
        self.assertFalse(event.isAccepted())
        worker.isRunning.return_value = False
        self.window.closeEvent(event)
        self.assertTrue(event.isAccepted())

    def test_workers_compatibility_imports_still_resolve(self):
        from fizz.frontend.qt.workers import RLskitUploadWorker

        self.assertIs(RLskitUploadWorker, tasks.RLskitUploadWorker)

    def test_checksum_reset_timer_stops_when_window_closes(self):
        self.controller.rlskit_cksum = "12345 99 package.tar.gz"
        self.controller._copy_cksum()
        self.assertTrue(self.controller._cksum_timer.isActive())
        self.window.close()
        self.assertFalse(self.controller._cksum_timer.isActive())


if __name__ == "__main__":
    unittest.main()
