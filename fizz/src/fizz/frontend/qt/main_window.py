"""Fizz desktop shell; workflows are composed from independent views."""

from PyQt5 import QtCore, QtGui, QtWidgets

from fizz.frontend.qt.controllers.app_controller import AppController
from fizz.frontend.qt.models.workflows import WORKFLOWS
from fizz.frontend.qt.services.settings import SettingsService
from fizz.frontend.qt.styles import APP_QSS
from fizz.frontend.qt.views.merge_page import MergePage
from fizz.frontend.qt.views.nav_panel import NavPanel
from fizz.frontend.qt.views.obfuscator_page import ObfuscatorPage
from fizz.frontend.qt.views.postsim_page import PostsimPage
from fizz.frontend.qt.views.rlskit_page import RLskitPage
from fizz.frontend.qt.views.vcs_page import VcsPage
from fizz.frontend.qt.widgets.common import load_lucide_icon, polish_controls
from fizz.frontend.qt.widgets.window_chrome import (
    WindowTitleBar,
    create_resize_handles,
    position_resize_handles,
)


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self, *, config=None, settings=None, script_dir=None):
        super().__init__()
        self.setWindowTitle("fizz · SystemVerilog 工具箱")
        self.setWindowIcon(load_lucide_icon("file-code-corner"))
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.FramelessWindowHint)
        self.setStyleSheet(APP_QSS)
        self.resize(1280, 880)
        self.setMinimumSize(900, 640)
        self.controller = AppController(self, config=config, script_dir=script_dir)
        self.settings_service = SettingsService(settings)
        central = QtWidgets.QWidget()
        root = QtWidgets.QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        self.title_bar = WindowTitleBar(self)
        root.addWidget(self.title_bar)
        body = QtWidgets.QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)
        self.nav_panel = NavPanel()
        body.addWidget(self.nav_panel)
        self.view_stack = QtWidgets.QStackedWidget()
        self.view_stack.setObjectName("ViewStack")
        body.addWidget(self.view_stack, 1)
        root.addLayout(body, 1)
        self.setCentralWidget(central)
        self.pages = {}
        page_types = (MergePage, VcsPage, ObfuscatorPage, RLskitPage, PostsimPage)
        for workflow, page_type in zip(WORKFLOWS, page_types):
            page = page_type(workflow, self.controller)
            self.pages[workflow.key] = page
            setattr(self.controller.pages, workflow.key, page)
            self.view_stack.addWidget(page)
        self.current_workflow = "merge"
        self.nav_panel.workflowSelected.connect(self.select_workflow)
        self.nav_panel.settingsRequested.connect(
            self.controller._open_preferences_dialog
        )
        self.nav_panel.docsRequested.connect(self.controller._show_about)
        self.nav_panel.collapsedChanged.connect(self.title_bar.sidebar_changed)
        self.title_bar.collapse_btn.clicked.connect(self.nav_panel.toggle_collapse)
        self._install_shortcuts()
        self.statusBar().setSizeGripEnabled(False)
        self.statusBar().showMessage("就绪")
        self.resize_handles = create_resize_handles(self)
        screen = QtWidgets.QApplication.primaryScreen()
        self.move(screen.availableGeometry().center() - self.rect().center())
        polish_controls(self)
        self.controller.initialize()
        self.settings_service.restore(self)

    def _install_shortcuts(self):
        self.shortcuts = []
        actions = [
            ("Ctrl+P", self.controller._open_preferences_dialog),
            ("Ctrl+B", self.nav_panel.toggle_collapse),
            ("F1", self.controller._show_about),
        ]
        actions.extend(
            (f"Ctrl+{i + 1}", lambda key=workflow.key: self.select_workflow(key))
            for i, workflow in enumerate(WORKFLOWS)
        )
        for key, callback in actions:
            shortcut = QtWidgets.QShortcut(QtGui.QKeySequence(key), self)
            shortcut.activated.connect(callback)
            self.shortcuts.append(shortcut)

    def select_workflow(self, key):
        if key not in self.pages:
            return
        self.current_workflow = key
        self.view_stack.setCurrentWidget(self.pages[key])
        self.nav_panel.select_workflow(key)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if hasattr(self, "resize_handles"):
            position_resize_handles(self)

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() == QtCore.QEvent.WindowStateChange and hasattr(
            self, "resize_handles"
        ):
            self.title_bar.update_window_state()
            position_resize_handles(self)

    def showEvent(self, event):
        super().showEvent(event)
        position_resize_handles(self)

    def closeEvent(self, event):
        if self.controller.active_workers():
            self.statusBar().showMessage(
                "任务正在运行，请等待完成；FTP 上传可在 RLskit 页面取消。"
            )
            event.ignore()
            return
        self.controller.stop_timers()
        self.settings_service.save(self)
        super().closeEvent(event)
