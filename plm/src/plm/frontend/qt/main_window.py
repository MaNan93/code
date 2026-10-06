"""Codex-style PyQt5 views for plmConsultant using the native title bar."""

import sys
import ctypes
from ctypes import wintypes
from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.exceptions import install_exception_handler
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.styles.tokens import BG_CHROME, BG_CHROME_INACTIVE, BG_SURFACE, FONT_SIZE_BODY, PRIMARY
from plm.frontend.qt.views.config_page import ConfigPage
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.widgets.common import load_lucide_icon

__all__ = ["MainWindow"]


class MainWindow(QtWidgets.QMainWindow):
    """Native QMainWindow with a fixed sidebar and vertically split content."""

    def __init__(self):
        super().__init__()
        install_exception_handler()
        self.controller = AppController()
        app = QtWidgets.QApplication.instance()
        font = QtGui.QFont("Inter")
        font.setPixelSize(FONT_SIZE_BODY)
        font.setStyleStrategy(QtGui.QFont.PreferAntialias)
        font.setHintingPreference(QtGui.QFont.PreferFullHinting)
        app.setFont(font)
        palette = app.palette()
        palette.setColor(QtGui.QPalette.Window, QtGui.QColor(BG_SURFACE))
        app.setPalette(palette)
        app.setStyleSheet(APP_QSS)
        self.setWindowTitle("plmConsultant")
        self.resize(1400, 900)
        self.setMinimumSize(960, 640)
        self.setWindowIcon(load_lucide_icon("layout-dashboard", PRIMARY))
        self._log_sizes = [700, 200]
        self._activation_connected = False

        self.main_container = QtWidgets.QWidget()
        self.main_container.setObjectName("MainContainer")
        main_layout = QtWidgets.QHBoxLayout(self.main_container)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        self.nav_panel = self.controller.create_navigation()
        main_layout.addWidget(self.nav_panel)

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
        main_layout.addWidget(self.content_splitter, 1)
        self.content_splitter.setStretchFactor(0, 3)
        self.content_splitter.setStretchFactor(1, 1)
        self.view_stack = QtWidgets.QStackedWidget(self)
        self.view_stack.setObjectName("ViewStack")
        self.view_stack.addWidget(self.main_container)
        self.view_stack.setCurrentWidget(self.main_container)
        self.setCentralWidget(self.view_stack)

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
        self._enable_background_focus(self.main_container)

    def _connect_application_state(self):
        if self._activation_connected:
            return
        app = QtWidgets.QApplication.instance()
        if app is not None:
            app.applicationStateChanged.connect(self._application_state_changed)
            self._activation_connected = True

    def _disconnect_application_state(self):
        if not self._activation_connected:
            return
        app = QtWidgets.QApplication.instance()
        if app is not None:
            app.applicationStateChanged.disconnect(self._application_state_changed)
        self._activation_connected = False

    @staticmethod
    def _enable_background_focus(container):
        # Blank areas take focus through Qt's normal mouse dispatch. Editors
        # and item views keep their native focus-out commit behavior.
        for widget in [container, *container.findChildren(QtWidgets.QWidget)]:
            if type(widget) in (QtWidgets.QWidget, QtWidgets.QFrame) or widget is container:
                if widget.focusPolicy() == QtCore.Qt.NoFocus:
                    widget.setFocusPolicy(QtCore.Qt.ClickFocus)

    def _application_state_changed(self, state):
        if state == QtCore.Qt.ApplicationActive:
            QtCore.QTimer.singleShot(0, self._refresh_after_activation)
        else:
            self._finish_focused_edit()

    def showEvent(self, event):
        self._connect_application_state()
        super().showEvent(event)
        self._sync_window_chrome()

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() == QtCore.QEvent.ActivationChange and hasattr(self, "nav_panel"):
            self._sync_window_chrome()

    def _sync_window_chrome(self):
        active = self.isActiveWindow()
        self.nav_panel.setProperty("windowActive", active)
        self.nav_panel.style().unpolish(self.nav_panel)
        self.nav_panel.style().polish(self.nav_panel)
        self.nav_panel.update()
        color = BG_CHROME if active else BG_CHROME_INACTIVE
        self._set_native_caption_color(color)

    def _set_native_caption_color(self, color):
        if sys.platform != "win32" or QtGui.QGuiApplication.platformName() != "windows":
            return
        if sys.getwindowsversion().build < 22000:
            return
        try:
            # DWMWA_CAPTION_COLOR uses COLORREF (0x00BBGGRR), not Qt's RGB order.
            setter = ctypes.WinDLL("dwmapi").DwmSetWindowAttribute
            setter.argtypes = [wintypes.HWND, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD]
            setter.restype = wintypes.LONG
            rgb = QtGui.QColor(color)
            value = wintypes.DWORD(rgb.red() | (rgb.green() << 8) | (rgb.blue() << 16))
            setter(wintypes.HWND(int(self.winId())), 35, ctypes.byref(value), ctypes.sizeof(value))
        except (AttributeError, OSError):
            # Native caption coloring is optional on unsupported platforms.
            return

    def _update_history_actions(self):
        self.undo_action.setEnabled(self.config_page.can_undo())
        self.redo_action.setEnabled(self.config_page.can_redo())

    def closeEvent(self, event):
        self.controller.hide_project_menu()
        if not self.controller.confirm_switch():
            event.ignore()
            return
        self._disconnect_application_state()
        super().closeEvent(event)

    def _finish_focused_edit(self):
        editor = QtWidgets.QApplication.focusWidget()
        if not isinstance(editor, (QtWidgets.QLineEdit, QtWidgets.QAbstractSpinBox, QtWidgets.QComboBox)):
            return
        if not self.isAncestorOf(editor):
            return
        # A spin box or editable combo owns its internal line edit's focus.
        if isinstance(editor.parentWidget(), (QtWidgets.QAbstractSpinBox, QtWidgets.QComboBox)):
            editor = editor.parentWidget()
        editor.clearFocus()

    def _refresh_after_activation(self):
        if self.isVisible():
            self.controller.validate_current()

    def _apply_initial_sizes(self):
        self.content_splitter.setSizes(self._log_sizes)

    def toggle_log(self):
        sizes = self.content_splitter.sizes()
        total = sum(sizes)
        if sizes[1] > 0:
            self.hide_log()
        else:
            self.content_splitter.setStretchFactor(1, 1)
            bottom = max(140, int(total * 0.25))
            self.content_splitter.setSizes([max(1, total - bottom), bottom])

    def hide_log(self):
        sizes = self.content_splitter.sizes()
        self.content_splitter.setStretchFactor(1, 0)
        if sizes[1] <= 0:
            return
        self._log_sizes = sizes
        self.content_splitter.setSizes([sum(sizes), 0])


    def on_save(self):
        self.controller.hide_project_menu()
        self.nav_panel.set_active(None)
        self.controller.save_current()

    def on_open_settings(self):
        self.controller.hide_project_menu()
        self._show_secondary_page("settings")

    def on_open_docs(self):
        self.controller.hide_project_menu()
        self._show_secondary_page("docs")

    def _show_secondary_page(self, page):
        self._close_secondary_page()
        widget = self.controller.create_secondary_page(page, self)
        self._enable_background_focus(widget)
        widget.closeRequested.connect(self._close_secondary_page)
        widget.preferencesSaved.connect(self.controller.save_preferences)
        self.view_stack.addWidget(widget)
        self.view_stack.setCurrentWidget(widget)
        self.nav_panel.set_active(page)
        self.undo_action.setEnabled(False)
        self.redo_action.setEnabled(False)
        widget.setFocus(QtCore.Qt.OtherFocusReason)

    def _close_secondary_page(self):
        widget = self.view_stack.currentWidget()
        if widget is not self.main_container:
            self.view_stack.setCurrentWidget(self.main_container)
            self.view_stack.removeWidget(widget)
            widget.deleteLater()
        self.nav_panel.set_active(None)
        self._update_history_actions()

if __name__ == "__main__":
    from plm.frontend.qt.main import main
    sys.exit(main())
