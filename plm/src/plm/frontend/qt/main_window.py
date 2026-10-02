"""Codex-style PyQt5 views for plmConsultant using the native title bar."""

import sys
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.views.config_page import ConfigHeader, ConfigPage, DragHandle
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    LUCIDE_ICON_DIR,
    apply_drop_shadow,
    load_lucide_icon,
    make_icon_button,
)
from plm.frontend.qt.widgets.hover_card import HoverCard, HoverIconButton
from plm.frontend.qt.widgets.project_item import ProjectItemWidget
from plm.frontend.qt.widgets.project_list import ProjectList

__all__ = [
    "HoverCard",
    "HoverIconButton",
    "ProjectItemWidget",
    "ProjectList",
    "NavPanel",
    "ArtifactsPanel",
    "ConfigHeader",
    "ConfigPage",
    "DragHandle",
    "LogPanel",
    "ICON_SIZE",
    "LUCIDE_ICON_DIR",
    "make_icon_button",
    "apply_drop_shadow",
    "MainWindow",
]


APP_ICON_PATH = Path(__file__).resolve().parent / "assets" / "app_icon.svg"
class MainWindow(QtWidgets.QMainWindow):
    """Native QMainWindow containing horizontal and vertical splitters."""

    def __init__(self):
        super().__init__()
        self.controller = AppController()
        self.settings_store = self.controller.settings
        self._apply_preferences(self._read_preferences())
        self.setWindowTitle("plmConsultant")
        self.resize(1400, 900)
        self.setMinimumSize(960, 640)
        self.setWindowIcon(load_lucide_icon("layout-dashboard", "#1677FF"))
        self._log_sizes = [700, 200]
        self.placeholder_overlay = None

        self.main_splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        self.main_splitter.setObjectName("MainSplitter")
        self.main_splitter.setHandleWidth(4)
        self.main_splitter.setChildrenCollapsible(False)
        self.nav_panel = self.controller.create_navigation()
        self.main_splitter.addWidget(self.nav_panel)

        self.content_splitter = QtWidgets.QSplitter(QtCore.Qt.Vertical)
        self.content_splitter.setObjectName("ContentSplitter")
        self.content_splitter.setHandleWidth(1)
        self.content_splitter.setChildrenCollapsible(True)
        self.config_page = ConfigPage(
            editor_path_provider=self.controller.settings.editor_path
        )
        self.log_panel = LogPanel()
        self.config_page.logToggleRequested.connect(self.toggle_log)
        self.log_panel.closeRequested.connect(self.hide_log)
        self.content_splitter.addWidget(self.config_page)
        self.content_splitter.addWidget(self.log_panel)
        self.main_splitter.addWidget(self.content_splitter)
        self.main_splitter.handle(1).setCursor(QtCore.Qt.SplitHCursor)
        self.main_splitter.setStretchFactor(0, 0)
        self.main_splitter.setStretchFactor(1, 1)
        self.content_splitter.setStretchFactor(0, 3)
        self.content_splitter.setStretchFactor(1, 1)
        self.setCentralWidget(self.main_splitter)

        QtCore.QTimer.singleShot(0, self._apply_initial_sizes)

        self.controller.connect_navigation(
            self.nav_panel, self.config_page, self.log_panel, self
        )
        self.undo_action = QtWidgets.QAction("撤销", self)
        self.undo_action.setShortcuts([QtGui.QKeySequence("Ctrl+Z")])
        self.undo_action.triggered.connect(self.config_page.undo)
        self.redo_action = QtWidgets.QAction("重做", self)
        self.redo_action.setShortcuts([QtGui.QKeySequence("Ctrl+Y"), QtGui.QKeySequence("Ctrl+Shift+Z")])
        self.redo_action.triggered.connect(self.config_page.redo)
        self.addActions([self.undo_action, self.redo_action])
        self.config_page.historyChanged.connect(self._update_history_actions)
        self._update_history_actions()

    def _update_history_actions(self):
        self.undo_action.setEnabled(self.config_page.can_undo())
        self.redo_action.setEnabled(self.config_page.can_redo())

    def closeEvent(self, event):
        self.controller.hide_project_menu()
        if not self.controller._confirm_switch():
            event.ignore()
            return
        super().closeEvent(event)

    def _apply_initial_sizes(self):
        main_width = max(261, self.main_splitter.width())
        self.main_splitter.setSizes([260, main_width - 260])
        self.content_splitter.setSizes(self._log_sizes)

    def toggle_log(self):
        sizes = self.content_splitter.sizes()
        total = sum(sizes)
        if sizes[1] > 0:
            self._log_sizes = sizes
            self.content_splitter.setSizes([total, 0])
        else:
            bottom = max(140, int(total * 0.25))
            self.content_splitter.setSizes([max(1, total - bottom), bottom])

    def hide_log(self):
        sizes = self.content_splitter.sizes()
        if sizes[1] <= 0:
            return
        self._log_sizes = sizes
        self.content_splitter.setSizes([sum(sizes), 0])

    def on_new_chat(self):
        self.controller.show_project_menu()

    def on_save(self):
        self.controller.hide_project_menu()
        self.nav_panel.set_active(None)
        self.controller.save_current()

    def on_open_settings(self):
        self.controller.hide_project_menu()
        self.nav_panel.set_active("settings")
        self._show_placeholder("settings")

    def on_open_docs(self):
        self.controller.hide_project_menu()
        self.nav_panel.set_active("docs")
        self._show_placeholder("docs")

    def _show_placeholder(self, page):
        self._close_placeholder()
        self.placeholder_overlay = self.controller.create_secondary_page(page, self)
        self.placeholder_overlay.setGeometry(self.rect())
        self.placeholder_overlay.closeRequested.connect(self._close_placeholder)
        self.placeholder_overlay.preferencesSaved.connect(self.controller.save_preferences)
        self.placeholder_overlay.show()
        self.placeholder_overlay.raise_()
        self.placeholder_overlay.setFocus(QtCore.Qt.OtherFocusReason)

    def _close_placeholder(self):
        if self.placeholder_overlay is None:
            return
        overlay = self.placeholder_overlay
        self.placeholder_overlay = None
        overlay.hide()
        overlay.deleteLater()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self.placeholder_overlay is not None:
            self.placeholder_overlay.setGeometry(self.rect())

    def _read_preferences(self):
        return self.settings_store.preferences()

    def _apply_preferences(self, preferences):
        self.controller.apply_preferences(preferences)



if __name__ == "__main__":
    if hasattr(QtCore.Qt, "AA_EnableHighDpiScaling"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    if hasattr(QtCore.Qt, "AA_UseHighDpiPixmaps"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    app = QtWidgets.QApplication(sys.argv)
    app.setStyle("Fusion")
    font = QtGui.QFont()
    font.setFamily("Microsoft YaHei UI")
    font.setStyleStrategy(QtGui.QFont.PreferAntialias)
    font.setHintingPreference(QtGui.QFont.PreferFullHinting)
    app.setFont(font)
    app.setStyleSheet(APP_QSS)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())
