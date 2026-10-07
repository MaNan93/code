"""Regression checks for worker isolation and the current canvas layout."""

import os
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets

from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.views.artifact_preview import MAX_PREVIEW_BYTES
from qt_test_support import dispose_new_widgets, wait_for_idle


class AsyncBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name)
        scaffold_default_content(self.root / "test/demo")
        scaffold_default_content(self.root / "test/other")
        settings = SettingsStore(QtCore.QSettings(
            str(self.root / "settings.ini"), QtCore.QSettings.IniFormat
        ))
        self.controller = AppController(ProjectService(self.root), settings, WorkspaceService())
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)

    def test_worker_does_not_block_timer_and_callbacks_use_gui_thread(self):
        started, release = threading.Event(), threading.Event()
        results, progress, timer_ticks = [], [], []
        runner = TaskRunner(self.window)

        def work(report):
            started.set()
            release.wait(2)
            report(50, "halfway")
            return QtCore.QThread.currentThread() == self.app.thread()

        runner.submit(
            work,
            lambda result: results.append((result, QtCore.QThread.currentThread() == self.app.thread())),
            lambda error: self.fail(str(error)),
            lambda *_args: progress.append(QtCore.QThread.currentThread() == self.app.thread()),
        )
        try:
            self.assertTrue(started.wait(1))
            QtCore.QTimer.singleShot(0, lambda: timer_ticks.append(True))
            QtTest.QTest.qWait(30)
            self.assertEqual(timer_ticks, [True])
            self.assertFalse(results)
        finally:
            release.set()
        wait_for_idle(self.app)
        self.assertEqual(results, [(False, True)])
        self.assertEqual(progress, [True])

    def test_loading_blocks_mutations_until_new_project_is_ready(self):
        started, release = threading.Event(), threading.Event()
        original_load = WorkspaceService.load

        def load(service, project):
            started.set()
            release.wait(2)
            return original_load(service, project)

        with patch.object(WorkspaceService, "load", load):
            self.controller.select_project("other")
            try:
                self.assertTrue(started.wait(1))
                self.assertTrue(self.controller._load_running)
                self.assertFalse(self.window.nav_panel.isEnabled())
                self.assertFalse(self.controller.save_current())
                self.controller.generate_current()
                self.controller.rename_project("demo", "unexpected")
                self.assertFalse(self.controller._generation_running)
                self.assertFalse(self.controller._project_operation_running)
                self.assertTrue((self.root / "test/demo").exists())
            finally:
                release.set()
            wait_for_idle(self.app)
        self.assertEqual(self.controller.current_name, "other")
        self.assertTrue(self.window.nav_panel.isEnabled())

    def test_edit_during_save_preserves_new_changes_and_updates_saved_baseline(self):
        started, release = threading.Event(), threading.Event()
        original_save = WorkspaceService.save

        def save(service, project, payload):
            started.set()
            release.wait(2)
            original_save(service, project, payload)

        page = self.window.config_page
        page.controllers_editor.table.item(0, 1).setText("saved_snapshot")
        with patch.object(WorkspaceService, "save", save):
            self.controller.save_current()
            try:
                self.assertTrue(started.wait(1))
                page.controllers_editor.table.item(0, 1).setText("later_edit")
            finally:
                release.set()
            wait_for_idle(self.app)
        self.assertTrue(page.dirty)
        self.assertEqual(page.controllers_editor.table.item(0, 1).text(), "later_edit")
        saved = self.controller.current_project.controllers_csv.read_text()
        self.assertIn("saved_snapshot", saved)
        self.assertNotIn("later_edit", saved)
        page.undo()
        self.assertEqual(page.controllers_editor.table.item(0, 1).text(), "saved_snapshot")
        self.assertFalse(page.dirty)

    def test_hidden_log_removes_handle_and_visible_panels_have_two_pixel_gap(self):
        window = self.window
        window.hide_log()
        wait_for_idle(self.app)
        page = window.config_page
        bottom = page.mapTo(window, page.rect().bottomRight()).y() + 1
        self.assertEqual(window.height() - bottom, 5)
        window.toggle_log()
        wait_for_idle(self.app)
        page_bottom = page.mapTo(window, page.rect().bottomRight()).y() + 1
        log_top = window.log_panel.mapTo(window, QtCore.QPoint()).y()
        self.assertEqual(log_top - page_bottom, 2)
        for panel in (page, window.log_panel):
            right = panel.mapTo(window, panel.rect().bottomRight()).x() + 1
            self.assertEqual(window.width() - right, 5)
            self.assertTrue(panel.mask().isEmpty())
        self.assertEqual(page.CORNER_RADII, window.log_panel.CORNER_RADII)

    def test_oversized_preview_is_bounded_and_disables_copy(self):
        file = self.root / "oversized.sv"
        file.write_bytes(b"x" * (MAX_PREVIEW_BYTES + 1))
        panel = self.window.config_page.artifacts_panel
        panel.set_files([file], self.root)
        wait_for_idle(self.app)
        self.assertFalse(panel.preview.toPlainText())
        self.assertIn("200KB", panel.preview.placeholderText())
        self.assertFalse(panel.copy_content_action.isEnabled())

    def test_preview_ignores_result_from_an_old_workspace(self):
        started, release = threading.Event(), threading.Event()
        one, two = self.root / "one.sv", self.root / "two.sv"
        one.write_text("old workspace", encoding="utf-8")
        two.write_text("new workspace", encoding="utf-8")
        panel = self.window.config_page.artifacts_panel
        read = panel._read_contents

        def delayed(files):
            if one in files:
                started.set()
                release.wait(2)
            return read(files)

        with patch.object(panel, "_read_contents", delayed):
            panel.set_files([one], self.root)
            try:
                self.assertTrue(started.wait(1))
                panel.set_files([two], self.root)
            finally:
                release.set()
            wait_for_idle(self.app)
        self.assertEqual(panel.current_path, two)
        self.assertEqual(panel.preview.toPlainText(), "new workspace")
