"""Notifications follow completed worker callbacks and have bounded lifetimes."""

import os
import shutil
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets, sip
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from sample_data import sample_config
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.widgets.toast import ToastNotification
from plm.frontend.qt.styles.tokens import TOAST_BOTTOM_MARGIN


class ToastTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        preserve_application_state(self, self.app)
        isolate_host_formatter(self, self.app)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(temporary.name)
        shutil.copytree(sample_config("bifurcate"), self.root / "test/demo/config")
        store = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
        self.controller = AppController(ProjectService(self.root), store, WorkspaceService())
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)
        self.addCleanup(self.window.toast.hide)

    def test_toast_replacement_resets_timer_and_does_not_take_focus(self):
        toast = self.window.toast
        editor = self.window.config_page.header.title_edit
        editor.show()
        editor.setFocus()
        focus = self.app.focusWidget()
        self.window.show_toast("first", "success")
        QtTest.QTest.qWait(180)
        self.assertTrue(toast.timer.isActive())
        self.window.show_toast("replacement", "info")
        self.assertFalse(toast.timer.isActive())
        self.assertEqual(toast.label.text(), "replacement")
        self.assertEqual(toast.property("level"), "info")
        self.assertIs(self.app.focusWidget(), focus)
        self.assertTrue(toast.testAttribute(QtCore.Qt.WA_TransparentForMouseEvents))
        self.assertEqual(len(self.window.findChildren(ToastNotification)), 1)
        QtTest.QTest.qWait(180)
        self.assertGreater(toast.timer.remainingTime(), 1600)
        toast._fade_out()
        QtTest.QTest.qWait(240)
        self.assertFalse(toast.isVisible())
        self.assertFalse(toast.timer.isActive())

    def test_toast_recenters_on_resize_and_stops_when_parent_closes(self):
        toast = self.window.toast
        self.window.show_toast("resize", "success")
        self.window.resize(1500, 950)
        self.app.processEvents()
        self.assertLessEqual(abs(toast.geometry().center().x() - self.window.rect().center().x()), 1)
        self.assertEqual(self.window.height() - toast.y() - toast.height(), TOAST_BOTTOM_MARGIN)
        QtTest.QTest.qWait(180)
        self.window.close()
        self.assertFalse(toast.timer.isActive())
        self.assertEqual(toast.animation.state(), QtCore.QAbstractAnimation.Stopped)

    def test_deleting_parent_during_fade_deletes_timer_and_animation(self):
        parent = QtWidgets.QWidget()
        parent.resize(500, 300)
        parent.show()
        toast = ToastNotification(parent)
        toast.show_message("closing")
        timer, animation = toast.timer, toast.animation
        parent.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        self.assertTrue(sip.isdeleted(toast))
        self.assertTrue(sip.isdeleted(timer))
        self.assertTrue(sip.isdeleted(animation))

    def test_save_waits_for_real_worker_success_and_failure_never_notifies_success(self):
        started, release = threading.Event(), threading.Event()
        original = WorkspaceService.save
        def delayed(service, project, payload):
            started.set()
            release.wait(3)
            original(service, project, payload)
        with patch.object(self.window, "show_toast") as notify:
            with patch.object(WorkspaceService, "save", delayed):
                self.controller.save_current()
                try:
                    self.assertTrue(started.wait(1))
                    self.app.processEvents()
                    notify.assert_not_called()
                finally:
                    release.set()
                wait_for_idle(self.app)
            notify.assert_called_once_with("✓ 配置已保存", "success")
            notify.reset_mock()
            with patch.object(WorkspaceService, "save", side_effect=OSError("write failed")):
                self.controller.save_current()
                wait_for_idle(self.app)
            notify.assert_not_called()
            self.assertIn("保存失败", self.window.log_panel.output.toPlainText())

    def test_generation_notifies_only_after_worker_and_distinguishes_cached_outputs(self):
        started, release = threading.Event(), threading.Event()
        original = WorkspaceService.generate
        def delayed(service, *args, **kwargs):
            started.set()
            release.wait(3)
            return original(service, *args, **kwargs)
        with patch.object(self.window, "show_toast") as notify:
            with patch.object(WorkspaceService, "generate", delayed):
                self.controller.generate_current()
                try:
                    self.assertTrue(started.wait(1))
                    self.app.processEvents()
                    notify.assert_not_called()
                finally:
                    release.set()
                wait_for_idle(self.app)
            notify.assert_called_once_with("✓ RTL 与测试用例生成成功", "success")
            notify.reset_mock()
            self.controller.generate_current()
            wait_for_idle(self.app)
            notify.assert_called_once_with("输出已是最新，无需重新生成", "info")
            notify.reset_mock()
            with patch.object(WorkspaceService, "generate", side_effect=ValueError("generation failed")):
                self.controller.generate_current()
                wait_for_idle(self.app)
            notify.assert_not_called()

    def test_stale_save_and_generation_callbacks_do_not_notify(self):
        controller = self.controller
        original_project = controller.current_project
        for operation in (controller.save_current, controller.generate_current):
            controller.current_project = original_project
            with patch.object(controller.tasks, "submit") as submit:
                operation()
                finished = submit.call_args.args[1]
                controller.current_project = SimpleNamespace(name="another project")
                with patch.object(self.window, "show_toast") as notify:
                    finished(None)
                    notify.assert_not_called()
            controller.current_project = original_project


if __name__ == "__main__":
    unittest.main()
