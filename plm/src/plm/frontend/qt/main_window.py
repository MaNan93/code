"""Frameless PLM desktop window with a full-width custom title bar."""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.exceptions import install_exception_handler
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.styles.tokens import (
    BG_SIDEBAR,
    BG_SIDEBAR_INACTIVE,
    BG_SURFACE,
    FONT_SIZE_BODY,
    FONT_UI_PRIMARY,
    ICON_SIZE,
    scale_content_size,
    PRIMARY,
    TEXT_SUB,
)
from plm.frontend.qt.views.config_page import ConfigPage
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.widgets.common import ContentIconStyle, load_lucide_icon
from plm.frontend.qt.widgets.tooltip import install_tooltips

__all__ = ["MainWindow"]


class WindowBackdrop(QtWidgets.QWidget):
    """Paint only the outer shadow without filtering child widgets."""

    SHADOW_MARGIN = 24
    SHADOW_LAYER_ALPHA = 6

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("WindowBackdrop")
        self.shadow_enabled = True

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode_Source)
        painter.fillRect(self.rect(), QtCore.Qt.transparent)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode_SourceOver)
        if not self.shadow_enabled:
            painter.end()
            return
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        margin = self.SHADOW_MARGIN
        rect = QtCore.QRectF(self.rect()).adjusted(margin, margin, -margin, -margin)
        # Soft overlapping fills avoid nested graphics effects on text/previews.
        color = QtGui.QColor(QtCore.Qt.black)
        for spread in range(margin, 0, -1):
            falloff = 1.0 - spread / margin
            color.setAlpha(round(self.SHADOW_LAYER_ALPHA * falloff * falloff))
            path = QtGui.QPainterPath()
            path.addRoundedRect(
                rect.adjusted(-spread, -spread, spread, spread),
                WindowShell.RADIUS + spread, WindowShell.RADIUS + spread,
            )
            painter.fillPath(path, color)
        painter.end()


class WindowShell(QtWidgets.QWidget):
    """Paint the window perimeter with translucent, antialiased edges."""

    RADIUS = 12.0

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("WindowShell")
        self.setProperty("maximized", False)

    def paintEvent(self, event):
        maximized = self.property("maximized") in (True, "true")
        inactive = self.property("windowActive") in (False, "false")
        color = BG_SIDEBAR_INACTIVE if inactive else BG_SIDEBAR
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        rect = QtCore.QRectF(self.rect())
        if maximized:
            painter.fillRect(rect, QtGui.QColor(color))
        else:
            # No QRegion mask: retain the partially transparent edge pixels.
            path = QtGui.QPainterPath()
            path.addRoundedRect(rect, self.RADIUS, self.RADIUS)
            painter.fillPath(path, QtGui.QColor(color))
        painter.end()


class WindowTitleBar(QtWidgets.QFrame):
    """Full-width brand, drag surface, and frameless window controls."""

    HEIGHT = 38

    def __init__(self, window, sidebar_button=None):
        super().__init__(window)
        self._window = window
        self._drag_offset = None
        self.setObjectName("WindowTitleBar")
        self.setFixedHeight(self.HEIGHT)

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(12, 0, 0, 0)
        layout.setSpacing(0)

        self.logo_label = QtWidgets.QLabel()
        self.logo_label.setObjectName("WindowBrandLogo")
        self.logo_label.setPixmap(
            load_lucide_icon("layout-dashboard", PRIMARY, ICON_SIZE).pixmap(ICON_SIZE, ICON_SIZE)
        )
        self.logo_label.setFixedSize(ICON_SIZE, ICON_SIZE)
        self.logo_label.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        layout.addWidget(self.logo_label, 0, QtCore.Qt.AlignVCenter)
        layout.addSpacing(8)

        self.title_label = QtWidgets.QLabel(window.windowTitle())
        self.title_label.setObjectName("WindowBrandName")
        self.title_label.setAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
        self.title_label.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        layout.addWidget(self.title_label, 0, QtCore.Qt.AlignVCenter)
        if sidebar_button is not None:
            layout.addSpacing(8)
            layout.addWidget(sidebar_button, 0, QtCore.Qt.AlignVCenter)
            sidebar_button.show()
        layout.addStretch(1)

        self.minimize_btn = WindowControlButton("minimize", "最小化", self)
        self.maximize_btn = WindowControlButton("maximize", "最大化", self)
        self.close_btn = WindowControlButton("close", "关闭", self)
        self.minimize_btn.clicked.connect(window.showMinimized)
        self.maximize_btn.clicked.connect(self.toggle_maximized)
        self.close_btn.clicked.connect(window.close)
        for button in (self.minimize_btn, self.maximize_btn, self.close_btn):
            layout.addWidget(button, 0, QtCore.Qt.AlignVCenter)
        window.windowTitleChanged.connect(self.title_label.setText)

    def toggle_maximized(self):
        if self._window.isMaximized():
            self._window.showNormal()
        else:
            self._window.showMaximized()
        self.update_window_state()

    def update_window_state(self):
        maximized = self._window.isMaximized()
        self.maximize_btn.setRestoredIcon(maximized)
        self.maximize_btn.setToolTip("还原" if maximized else "最大化")

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self._drag_offset = (
                event.globalPos() - self._window.frameGeometry().topLeft()
            )
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._drag_offset is not None and event.buttons() & QtCore.Qt.LeftButton:
            if self._window.isMaximized():
                ratio = event.pos().x() / max(1, self.width())
                self._window.showNormal()
                self.update_window_state()
                title_left = self.mapTo(self._window, QtCore.QPoint()).x()
                self._drag_offset = QtCore.QPoint(
                    title_left + int(self.width() * ratio),
                    min(event.pos().y(), self.HEIGHT),
                )
            self._window.move(event.globalPos() - self._drag_offset)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self._drag_offset = None
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self._drag_offset = None
            self.toggle_maximized()
            event.accept()
            return
        super().mouseDoubleClickEvent(event)


class WindowControlButton(QtWidgets.QPushButton):
    """Fixed-size title-bar button using centered Lucide vector icons."""

    ICONS = {
        "minimize": ("minus", 14),
        "maximize": ("square", 12),
        "close": ("x", 14),
    }

    def __init__(self, role, tooltip, parent=None):
        super().__init__(parent)
        self._role = role
        self._restored_icon = False
        self._icon_name, base_size = self.ICONS[role]
        self._icon_size = scale_content_size(base_size)
        self.setObjectName("WindowControlButton")
        self.setProperty("role", role)
        self.setFixedSize(46, WindowTitleBar.HEIGHT)
        self.setIconSize(QtCore.QSize(self._icon_size, self._icon_size))
        self.setToolTip(tooltip)
        self.setCursor(QtCore.Qt.ArrowCursor)
        self._refresh_icon()

    def setRestoredIcon(self, restored):
        restored = bool(restored)
        if self._restored_icon != restored:
            self._restored_icon = restored
            self._icon_name = "copy" if restored else "square"
            self._refresh_icon()

    def _refresh_icon(self, hovered=False):
        color = BG_SURFACE if self._role == "close" and hovered else TEXT_SUB
        self.setIcon(load_lucide_icon(self._icon_name, color, self._icon_size))

    def enterEvent(self, event):
        if self._role == "close":
            self._refresh_icon(hovered=True)
        super().enterEvent(event)

    def leaveEvent(self, event):
        if self._role == "close":
            self._refresh_icon()
        super().leaveEvent(event)


class WindowResizeHandle(QtWidgets.QWidget):
    """Thin edge target that delegates resizing to the window system."""

    def __init__(self, window, edges, cursor):
        super().__init__(window)
        self._window = window
        self._edges = edges
        self._start_global = None
        self._start_geometry = None
        self.setObjectName("WindowResizeHandle")
        self.setCursor(cursor)

    def mousePressEvent(self, event):
        if event.button() != QtCore.Qt.LeftButton or self._window.isMaximized():
            super().mousePressEvent(event)
            return
        handle = self._window.windowHandle()
        if handle is not None and hasattr(handle, "startSystemResize"):
            try:
                if handle.startSystemResize(self._edges):
                    event.accept()
                    return
            except RuntimeError:
                pass
        self._start_global = event.globalPos()
        self._start_geometry = QtCore.QRect(self._window.geometry())
        event.accept()

    def mouseMoveEvent(self, event):
        if self._start_global is None or not event.buttons() & QtCore.Qt.LeftButton:
            super().mouseMoveEvent(event)
            return
        delta = event.globalPos() - self._start_global
        rect = QtCore.QRect(self._start_geometry)
        minimum = self._window.minimumSize()
        if self._edges & QtCore.Qt.LeftEdge:
            rect.setLeft(
                min(rect.left() + delta.x(), rect.right() - minimum.width() + 1)
            )
        if self._edges & QtCore.Qt.RightEdge:
            rect.setRight(
                max(rect.right() + delta.x(), rect.left() + minimum.width() - 1)
            )
        if self._edges & QtCore.Qt.TopEdge:
            rect.setTop(
                min(rect.top() + delta.y(), rect.bottom() - minimum.height() + 1)
            )
        if self._edges & QtCore.Qt.BottomEdge:
            rect.setBottom(
                max(rect.bottom() + delta.y(), rect.top() + minimum.height() - 1)
            )
        self._window.setGeometry(rect)
        event.accept()

    def mouseReleaseEvent(self, event):
        self._start_global = None
        self._start_geometry = None
        super().mouseReleaseEvent(event)


class MainWindow(QtWidgets.QMainWindow):
    """Frameless window with full-width chrome and routed body content."""

    SHADOW_MARGIN = WindowBackdrop.SHADOW_MARGIN

    def __init__(self):
        super().__init__()
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.FramelessWindowHint)
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground, True)
        install_exception_handler()
        self.controller = AppController()
        app = QtWidgets.QApplication.instance()
        font = QtGui.QFont(FONT_UI_PRIMARY)
        font.setPixelSize(FONT_SIZE_BODY)
        font.setStyleStrategy(QtGui.QFont.PreferAntialias)
        font.setHintingPreference(QtGui.QFont.PreferFullHinting)
        app.setFont(font)
        palette = app.palette()
        palette.setColor(QtGui.QPalette.Window, QtGui.QColor(BG_SURFACE))
        app.setPalette(palette)
        if not isinstance(app.style(), ContentIconStyle):
            app.setStyle(ContentIconStyle(app.style().objectName()))
        app.setStyleSheet(APP_QSS)
        install_tooltips(app)
        self.setWindowTitle("plmConsultant")
        self.resize(1400, 900)
        self.setMinimumSize(960, 640)
        self.setWindowIcon(load_lucide_icon("layout-dashboard", PRIMARY))
        self._log_sizes = [700, 200]
        self._activation_connected = False

        self.window_shell = WindowShell(self)
        self.window_backdrop = WindowBackdrop(self)
        self._backdrop_layout = QtWidgets.QVBoxLayout(self.window_backdrop)
        self._backdrop_layout.setContentsMargins(*([self.SHADOW_MARGIN] * 4))
        self._backdrop_layout.setSpacing(0)
        self._backdrop_layout.addWidget(self.window_shell)
        shell_layout = QtWidgets.QVBoxLayout(self.window_shell)
        shell_layout.setContentsMargins(0, 0, 0, 0)
        shell_layout.setSpacing(0)

        self.nav_panel = self.controller.create_navigation()
        self.title_bar = WindowTitleBar(self, self.nav_panel.collapse_btn)
        shell_layout.addWidget(self.title_bar)

        self.body_container = QtWidgets.QWidget()
        self.body_container.setObjectName("BodyContainer")
        body_layout = QtWidgets.QHBoxLayout(self.body_container)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(0)
        body_layout.addWidget(self.nav_panel)

        self.content_splitter = QtWidgets.QSplitter(QtCore.Qt.Vertical)
        self.content_splitter.setObjectName("ContentSplitter")
        self.content_splitter.setContentsMargins(0, 0, 0, 0)
        self.content_splitter.setHandleWidth(4)
        self.content_splitter.setChildrenCollapsible(True)
        self.config_page = ConfigPage(
            editor_path_provider=self.controller.settings.editor_path
        )
        self.log_toggle_button = self.config_page.take_log_button()
        self.log_toggle_button.setFixedSize(32, 32)
        title_layout = self.title_bar.layout()
        button_index = title_layout.indexOf(self.nav_panel.collapse_btn) + 1
        title_layout.insertSpacing(button_index, 8)
        title_layout.insertWidget(
            button_index + 1, self.log_toggle_button, 0, QtCore.Qt.AlignVCenter,
        )
        self.log_panel = LogPanel()
        self.config_page.logToggleRequested.connect(self.toggle_log)
        self.log_panel.closeRequested.connect(self.hide_log)
        self.content_splitter.addWidget(self.config_page)
        self.content_splitter.addWidget(self.log_panel)
        self.content_splitter.setStretchFactor(0, 3)
        self.content_splitter.setStretchFactor(1, 1)
        self.main_container = QtWidgets.QWidget()
        self.main_container.setObjectName("MainContainer")
        main_layout = QtWidgets.QVBoxLayout(self.main_container)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        main_layout.addWidget(self.content_splitter)

        self.view_stack = QtWidgets.QStackedWidget(self.body_container)
        self.view_stack.setObjectName("ViewStack")
        self.view_stack.setContentsMargins(0, 0, 0, 0)
        self.view_stack.addWidget(self.main_container)
        self.view_stack.setCurrentWidget(self.main_container)
        body_layout.addWidget(self.view_stack, 1)
        shell_layout.addWidget(self.body_container, 1)
        self.setCentralWidget(self.window_backdrop)
        self._create_resize_handles()

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

    def _create_resize_handles(self):
        horizontal = QtCore.Qt.SizeHorCursor
        vertical = QtCore.Qt.SizeVerCursor
        diagonal_forward = QtCore.Qt.SizeFDiagCursor
        diagonal_backward = QtCore.Qt.SizeBDiagCursor
        self._resize_handles = {
            "left": WindowResizeHandle(self, QtCore.Qt.LeftEdge, horizontal),
            "right": WindowResizeHandle(self, QtCore.Qt.RightEdge, horizontal),
            "top": WindowResizeHandle(self, QtCore.Qt.TopEdge, vertical),
            "bottom": WindowResizeHandle(self, QtCore.Qt.BottomEdge, vertical),
            "top_left": WindowResizeHandle(
                self, QtCore.Qt.TopEdge | QtCore.Qt.LeftEdge, diagonal_forward
            ),
            "top_right": WindowResizeHandle(
                self, QtCore.Qt.TopEdge | QtCore.Qt.RightEdge, diagonal_backward
            ),
            "bottom_left": WindowResizeHandle(
                self, QtCore.Qt.BottomEdge | QtCore.Qt.LeftEdge, diagonal_backward
            ),
            "bottom_right": WindowResizeHandle(
                self, QtCore.Qt.BottomEdge | QtCore.Qt.RightEdge, diagonal_forward
            ),
        }

    def _update_resize_handles(self):
        border = 6
        corner = 10
        shell_rect = self.window_shell.geometry()
        origin = self.window_shell.mapTo(self, QtCore.QPoint())
        width, height = shell_rect.width(), shell_rect.height()
        geometries = {
            "left": (0, corner, border, max(0, height - 2 * corner)),
            "right": (width - border, corner, border, max(0, height - 2 * corner)),
            "top": (corner, 0, max(0, width - 2 * corner), border),
            "bottom": (corner, height - border, max(0, width - 2 * corner), border),
            "top_left": (0, 0, corner, corner),
            "top_right": (width - corner, 0, corner, corner),
            "bottom_left": (0, height - corner, corner, corner),
            "bottom_right": (width - corner, height - corner, corner, corner),
        }
        visible = not self.isMaximized() and not self.isFullScreen()
        for name, handle in self._resize_handles.items():
            x, y, w, h = geometries[name]
            handle.setGeometry(origin.x() + x, origin.y() + y, w, h)
            handle.setVisible(visible)
            if visible:
                handle.raise_()

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
        self._sync_window_chrome(state == QtCore.Qt.ApplicationActive)
        if state == QtCore.Qt.ApplicationActive:
            QtCore.QTimer.singleShot(0, self._refresh_after_activation)
        else:
            self._finish_focused_edit()

    def showEvent(self, event):
        self._connect_application_state()
        super().showEvent(event)
        self._sync_window_chrome()
        self._sync_window_frame_state()

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() == QtCore.QEvent.ActivationChange:
            if hasattr(self, "nav_panel"):
                self._sync_window_chrome()
        elif event.type() == QtCore.QEvent.WindowStateChange:
            if hasattr(self, "window_shell"):
                QtCore.QTimer.singleShot(0, self._sync_window_frame_state)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if hasattr(self, "_resize_handles"):
            self._update_resize_handles()

    def _sync_window_chrome(self, active=None):
        if active is None:
            app = QtWidgets.QApplication.instance()
            active = self.isActiveWindow() and (
                app is None or app.applicationState() == QtCore.Qt.ApplicationActive
            )
        for widget in (self.window_shell, self.nav_panel, self.title_bar):
            widget.setProperty("windowActive", "true" if active else "false")
            widget.style().unpolish(widget)
            widget.style().polish(widget)
            widget.update()

    def _sync_window_frame_state(self):
        maximized = self.isMaximized() or self.isFullScreen()
        margin = 0 if maximized else self.SHADOW_MARGIN
        self._backdrop_layout.setContentsMargins(margin, margin, margin, margin)
        self._backdrop_layout.activate()
        self.window_backdrop.shadow_enabled = not maximized
        self.window_backdrop.update()
        self.window_shell.setProperty("maximized", "true" if maximized else "false")
        self.window_shell.style().unpolish(self.window_shell)
        self.window_shell.style().polish(self.window_shell)
        for widget in (self.title_bar, self.title_bar.close_btn, self.nav_panel):
            widget.style().unpolish(widget)
            widget.style().polish(widget)
            widget.update()
        self.window_shell.update()
        self.title_bar.update_window_state()
        self._update_resize_handles()

    def _update_history_actions(self):
        self.undo_action.setEnabled(self.config_page.can_undo())
        self.redo_action.setEnabled(self.config_page.can_redo())

    def closeEvent(self, event):
        if not self.controller.confirm_switch(on_saved=self.close):
            event.ignore()
            return
        self._disconnect_application_state()
        super().closeEvent(event)

    def _finish_focused_edit(self):
        editor = QtWidgets.QApplication.focusWidget()
        if not isinstance(
            editor,
            (
                QtWidgets.QLineEdit,
                QtWidgets.QAbstractSpinBox,
                QtWidgets.QComboBox,
            ),
        ):
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
        if self.log_panel.isVisible() and sizes[1] > 0:
            self.hide_log()
        else:
            self.log_panel.show()
            self.content_splitter.setStretchFactor(1, 1)
            bottom = max(140, int(total * 0.25))
            self.content_splitter.setSizes([max(1, total - bottom), bottom])

    def hide_log(self):
        sizes = self.content_splitter.sizes()
        self.content_splitter.setStretchFactor(1, 0)
        if sizes[1] > 0:
            self._log_sizes = sizes
        # Collapsing to height zero leaves the splitter handle in the layout.
        self.log_panel.hide()
    def on_save(self):
        self.nav_panel.set_active(None)
        self.controller.save_current()

    def on_open_settings(self):
        self._show_secondary_page("settings")

    def on_open_docs(self):
        self._show_secondary_page("docs")

    def _show_secondary_page(self, page):
        self._close_secondary_page()
        widget = self.controller.create_secondary_page(page, self)
        self._enable_background_focus(widget)
        widget.closeRequested.connect(self._close_secondary_page)
        widget.preferencesSaved.connect(self.controller.save_preferences)
        self.view_stack.addWidget(widget)
        self.view_stack.setCurrentWidget(widget)
        self._update_resize_handles()
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
            self._update_resize_handles()
        self.nav_panel.set_active(None)
        self._update_history_actions()
