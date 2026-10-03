"""Codex-style PyQt5 views for plmConsultant using the native title bar."""

import sys
from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.config_page import ConfigPage
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.widgets.common import load_lucide_icon

__all__ = ["MainWindow"]


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
        self._app_event_filter_installed = False

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
        self.redo_action.setShortcuts(
            [QtGui.QKeySequence("Ctrl+Y"), QtGui.QKeySequence("Ctrl+Shift+Z")]
        )
        self.redo_action.triggered.connect(self.config_page.redo)
        self.addActions([self.undo_action, self.redo_action])
        self.config_page.historyChanged.connect(self._update_history_actions)
        self._update_history_actions()

    def _install_app_event_filter(self):
        if self._app_event_filter_installed:
            return
        app = QtWidgets.QApplication.instance()
        if app is not None:
            app.installEventFilter(self)
            self._app_event_filter_installed = True

    def _remove_app_event_filter(self):
        if not self._app_event_filter_installed:
            return
        app = QtWidgets.QApplication.instance()
        if app is not None:
            app.removeEventFilter(self)
        self._app_event_filter_installed = False

    def showEvent(self, event):
        self._install_app_event_filter()
        super().showEvent(event)

    def _update_history_actions(self):
        self.undo_action.setEnabled(self.config_page.can_undo())
        self.redo_action.setEnabled(self.config_page.can_redo())

    def closeEvent(self, event):
        self.controller.hide_project_menu()
        if not self.controller._confirm_switch():
            event.ignore()
            return
        self._remove_app_event_filter()
        super().closeEvent(event)

    def eventFilter(self, watched, event):
        app = QtWidgets.QApplication.instance()
        if watched is app and event.type() == QtCore.QEvent.ApplicationActivate:
            # Re-check both source CSV signatures and generated-output hashes
            # when the user returns from an external editor. Defer until the
            # event is delivered, then confirm this window is still live.
            QtCore.QTimer.singleShot(0, self._refresh_after_activation)
        return super().eventFilter(watched, event)

    def _refresh_after_activation(self):
        if self.isVisible():
            self.controller.validate_current()

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

    def _set_background_blur(self, enabled):
        central = self.centralWidget()
        if central is None:
            return
        if enabled:
            effect = QtWidgets.QGraphicsBlurEffect(central)
            effect.setBlurRadius(7.0)
            central.setGraphicsEffect(effect)
        else:
            central.setGraphicsEffect(None)

    def _show_placeholder(self, page):
        self._close_placeholder()
        overlay = self.controller.create_secondary_page(page, self)
        self._set_background_blur(True)
        self.placeholder_overlay = overlay
        overlay.setGeometry(self.rect())
        overlay.closeRequested.connect(self._close_placeholder)
        overlay.preferencesSaved.connect(self.controller.save_preferences)
        overlay.show()
        overlay.raise_()
        overlay.setFocus(QtCore.Qt.OtherFocusReason)

    def _close_placeholder(self):
        overlay = self.placeholder_overlay
        self.placeholder_overlay = None
        if overlay is not None:
            overlay.hide()
            overlay.deleteLater()
        self._set_background_blur(False)

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
