"""Frameless PLM desktop window with a full-width custom title bar."""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.exceptions import install_exception_handler
from plm.frontend.qt.services.themes import apply_application_theme
from plm.frontend.qt.styles.tokens import SPACING_MD
from plm.frontend.qt.widgets.content_splitter import ContentSplitter
from plm.frontend.qt.widgets.toast import ToastNotification
from plm.frontend.qt.styles.tokens import get_active_theme, get_theme_color
from plm.frontend.qt.styles.tokens import (
    CONTROL_HEIGHT,
    FONT_SIZE_BODY,
    FONT_UI_PRIMARY,
    ICON_SIZE,
    ICON_BUTTON_SIZE,
    SPACING_XS,
    SPACING_SM,
    TITLEBAR_HEIGHT,
    TITLEBAR_BUTTON_WIDTH,
    RADIUS_WINDOW,
    LOG_COLLAPSED_HEIGHT,
    PANEL_ANIMATION_DURATION,
)
from plm.frontend.qt.views.config_page import ConfigPage
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.widgets.common import (
    ContentIconStyle, install_button_sizing, load_lucide_icon, make_icon_button,
)
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
        self._shadow_pixmap = QtGui.QPixmap()
        self._shadow_cache_key = None

    def _update_shadow_cache(self):
        ratio = self.devicePixelRatioF()
        key = (self.width(), self.height(), self.SHADOW_MARGIN, ratio)
        if key == self._shadow_cache_key:
            return
        self._shadow_cache_key = key
        self._shadow_pixmap = QtGui.QPixmap(
            round(self.width() * ratio), round(self.height() * ratio)
        )
        self._shadow_pixmap.setDevicePixelRatio(ratio)
        self._shadow_pixmap.fill(QtCore.Qt.transparent)
        if self._shadow_pixmap.isNull():
            return
        painter = QtGui.QPainter(self._shadow_pixmap)
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

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setCompositionMode(QtGui.QPainter.CompositionMode_Source)
        if self.shadow_enabled:
            self._update_shadow_cache()
            painter.drawPixmap(0, 0, self._shadow_pixmap)
        else:
            painter.fillRect(self.rect(), QtCore.Qt.transparent)
        painter.end()


class WindowShell(QtWidgets.QWidget):
    """Paint the window perimeter with translucent, antialiased edges."""

    RADIUS = float(RADIUS_WINDOW)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("WindowShell")
        self.setProperty("maximized", False)

    def paintEvent(self, event):
        maximized = self.property("maximized") in (True, "true")
        inactive = self.property("windowActive") in (False, "false")
        color = get_theme_color("bg_subtle") if inactive else get_theme_color("bg_sidebar")
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

    HEIGHT = TITLEBAR_HEIGHT

    def __init__(self, window):
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
            load_lucide_icon("layout-dashboard", 'primary', ICON_SIZE).pixmap(ICON_SIZE, ICON_SIZE)
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
        self.collapse_btn = make_icon_button(
            "panel-left", "收起侧边栏", "NavCollapseButton", ICON_BUTTON_SIZE, ICON_SIZE
        )
        layout.addSpacing(SPACING_SM)
        layout.addWidget(self.collapse_btn, 0, QtCore.Qt.AlignVCenter)
        self.actions_layout = QtWidgets.QHBoxLayout()
        self.actions_layout.setContentsMargins(0, 0, 0, 0)
        self.actions_layout.setSpacing(SPACING_SM)
        layout.addStretch(1)
        layout.addLayout(self.actions_layout)
        layout.addSpacing(SPACING_MD)

        self.minimize_btn = WindowControlButton("minimize", "最小化", self)
        self.maximize_btn = WindowControlButton("maximize", "最大化", self)
        self.close_btn = WindowControlButton("close", "关闭", self)
        self.minimize_btn.clicked.connect(window.showMinimized)
        self.maximize_btn.clicked.connect(self.toggle_maximized)
        self.close_btn.clicked.connect(window.close)
        for button in (self.minimize_btn, self.maximize_btn, self.close_btn):
            layout.addWidget(button, 0, QtCore.Qt.AlignVCenter)
        window.windowTitleChanged.connect(self.title_label.setText)

    def add_panel_action(self, button):
        self.actions_layout.addWidget(button, 0, QtCore.Qt.AlignVCenter)

    def refresh_theme(self):
        self.logo_label.setPixmap(load_lucide_icon(
            "layout-dashboard", 'primary', ICON_SIZE
        ).pixmap(ICON_SIZE, ICON_SIZE))

    def update_sidebar_state(self, collapsed):
        self.collapse_btn.setIcon(load_lucide_icon(
            "panel-right" if collapsed else "panel-left", 'text_sub',
        ))
        self.collapse_btn.setToolTip("展开侧边栏" if collapsed else "收起侧边栏")

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
        "minimize": "minus",
        "maximize": "square",
        "close": "x",
    }

    def __init__(self, role, tooltip, parent=None):
        super().__init__(parent)
        self._role = role
        self._restored_icon = False
        self._icon_name = self.ICONS[role]
        self._icon_size = ICON_SIZE
        self.setObjectName("WindowControlButton")
        self.setProperty("role", role)
        self.setFixedWidth(TITLEBAR_BUTTON_WIDTH)
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
        color = "text_on_primary" if self._role == "close" and hovered else "text_sub"
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
        font.setPixelSize(round(FONT_SIZE_BODY))
        font.setStyleStrategy(QtGui.QFont.PreferAntialias)
        font.setHintingPreference(QtGui.QFont.PreferFullHinting)
        app.setFont(font)
        if not isinstance(app.style(), ContentIconStyle):
            app.setStyle(ContentIconStyle(app.style().objectName()))
        apply_application_theme(self.controller.settings.theme())
        install_button_sizing(app)
        install_tooltips(app)
        self.setWindowTitle("plmConsultant")
        self.resize(1280, 800)
        self.setMinimumSize(960, 640)
        self.setWindowIcon(load_lucide_icon("layout-dashboard", 'primary'))
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
        self.title_bar = WindowTitleBar(self)
        self.title_bar.collapse_btn.clicked.connect(self.nav_panel.toggle_collapse)
        self.nav_panel.collapsedChanged.connect(self.title_bar.update_sidebar_state)
        shell_layout.addWidget(self.title_bar)

        self.body_container = QtWidgets.QWidget()
        self.body_container.setObjectName("BodyContainer")
        body_layout = QtWidgets.QHBoxLayout(self.body_container)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(0)
        body_layout.addWidget(self.nav_panel)

        self.content_splitter = ContentSplitter()
        self.content_splitter.setObjectName("ContentSplitter")
        self.content_splitter.setContentsMargins(0, 0, 0, 0)
        self.content_splitter.setChildrenCollapsible(True)
        self.config_page = ConfigPage(
            editor_path_provider=self.controller.settings.editor_path
        )
        self.log_toggle_button = make_icon_button(
            "panel-bottom", "显示/隐藏输出面板", "HeaderButton", ICON_BUTTON_SIZE, ICON_SIZE
        )
        self.artifacts_toggle_button = make_icon_button(
            "panel-right", "显示/隐藏 Artifacts", "HeaderButton", ICON_BUTTON_SIZE, ICON_SIZE
        )
        self.theme_toggle_button = make_icon_button(
            "moon", "切换到深色模式", "HeaderButton", ICON_BUTTON_SIZE, ICON_SIZE
        )
        self.theme_toggle_button.clicked.connect(self._toggle_theme_shortcut)
        self.title_bar.add_panel_action(self.log_toggle_button)
        self.title_bar.add_panel_action(self.artifacts_toggle_button)
        self.title_bar.add_panel_action(self.theme_toggle_button)
        self._update_theme_toggle_icon()
        self.log_toggle_button.clicked.connect(self.toggle_log)
        self.artifacts_toggle_button.clicked.connect(self.config_page.toggle_artifacts)
        self.log_panel = LogPanel()
        self.log_panel.closeRequested.connect(self.hide_log)
        self.content_splitter.addWidget(self.config_page)
        self.content_splitter.addWidget(self.log_panel)
        self.content_splitter.setStretchFactor(0, 3)
        self.content_splitter.setStretchFactor(1, 1)
        self.main_container = QtWidgets.QWidget()
        self.main_container.setObjectName("MainContainer")
        main_layout = QtWidgets.QVBoxLayout(self.main_container)
        main_layout.setContentsMargins(*([SPACING_XS] * 4))
        main_layout.setSpacing(0)
        main_layout.addWidget(self.content_splitter, 1)
        self.collapsed_log = QtWidgets.QPushButton("输出日志  ·  就绪")
        self.collapsed_log.setObjectName("LogCollapsedButton")
        self.collapsed_log.setIcon(load_lucide_icon("panel-bottom", "text_sub"))
        self.collapsed_log.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.collapsed_log.setFixedHeight(CONTROL_HEIGHT)
        self.collapsed_log.setToolTip("展开输出日志；生成时会自动展开。")
        self.collapsed_log.clicked.connect(self.show_log)
        self.log_panel.statusChanged.connect(self.update_log_summary)
        self.collapsed_log_bar = QtWidgets.QFrame()
        self.collapsed_log_bar.setObjectName("LogCollapsedBar")
        self.collapsed_log_bar.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.collapsed_log_bar.setFixedHeight(LOG_COLLAPSED_HEIGHT)
        collapsed_layout = QtWidgets.QHBoxLayout(self.collapsed_log_bar)
        collapsed_layout.setContentsMargins(0, 0, SPACING_XS, 0)
        collapsed_layout.setSpacing(0)
        collapsed_layout.addWidget(self.collapsed_log, 1)
        self.collapsed_log_clear = make_icon_button(
            "trash-2", "清空日志", "LogClearButton", ICON_BUTTON_SIZE, ICON_SIZE)
        self.collapsed_log_clear.clicked.connect(self.log_panel.clear)
        collapsed_layout.addWidget(self.collapsed_log_clear)
        main_layout.addWidget(self.collapsed_log_bar)
        self.log_panel.hide()
        self._log_expanded = False
        self._log_animation = QtCore.QVariantAnimation(self)
        self._log_animation.setDuration(PANEL_ANIMATION_DURATION)
        self._log_animation.setEasingCurve(QtCore.QEasingCurve.InOutCubic)
        self._log_animation.valueChanged.connect(self._set_log_extent)
        self._log_animation.finished.connect(self._finish_log_animation)
        self.log_panel.setSizePolicy(QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Ignored)
        self.log_panel.layout().setSizeConstraint(QtWidgets.QLayout.SetNoConstraint)

        self.view_stack = QtWidgets.QStackedWidget(self.body_container)
        self.view_stack.setObjectName("ViewStack")
        self.view_stack.setContentsMargins(0, 0, 0, 0)
        self.view_stack.addWidget(self.main_container)
        self.view_stack.setCurrentWidget(self.main_container)
        body_layout.addWidget(self.view_stack, 1)
        shell_layout.addWidget(self.body_container, 1)
        self.setCentralWidget(self.window_backdrop)
        self.toast = ToastNotification(self)
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
        for index in range(self.config_page.tabs.count()):
            scroll = self.config_page.tabs.widget(index).scroll
            if scroll is not None:
                self._enable_background_focus(scroll)
                self._enable_background_focus(scroll.widget())

    def _toggle_theme_shortcut(self):
        self.apply_theme("dark" if get_active_theme() == "light" else "light")

    def _update_theme_toggle_icon(self):
        dark = get_active_theme() == "dark"
        self.theme_toggle_button.setIcon(load_lucide_icon("sun" if dark else "moon", "text_sub", ICON_SIZE))
        self.theme_toggle_button.setToolTip("切换到浅色模式" if dark else "切换到深色模式")
        self.theme_toggle_button.setAccessibleName(self.theme_toggle_button.toolTip())

    def apply_theme(self, theme):
        from PyQt5 import sip
        scrolls = [(area, area.horizontalScrollBar().value(), area.verticalScrollBar().value())
                   for area in self.findChildren(QtWidgets.QAbstractScrollArea)]
        apply_application_theme(theme)
        self.setWindowIcon(load_lucide_icon("layout-dashboard", 'primary'))
        self.controller.settings.save_theme(get_active_theme())
        self._update_theme_toggle_icon()
        self.toast.reposition()
        def restore_scrolls():
            for area, horizontal, vertical in scrolls:
                if not sip.isdeleted(area):
                    area.horizontalScrollBar().setValue(horizontal)
                    area.verticalScrollBar().setValue(vertical)
        restore_scrolls()
        timer = QtCore.QTimer(self)
        timer.setSingleShot(True)
        timer.timeout.connect(restore_scrolls)
        timer.timeout.connect(timer.deleteLater)
        timer.start(0)

    def show_toast(self, text, level="success"):
        self.toast.show_message(text, level)

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
            app.installEventFilter(self)
            self._activation_connected = True

    def _disconnect_application_state(self):
        if not self._activation_connected:
            return
        app = QtWidgets.QApplication.instance()
        if app is not None:
            app.applicationStateChanged.disconnect(self._application_state_changed)
            app.removeEventFilter(self)
        self._activation_connected = False

    def eventFilter(self, watched, event):
        if (event.type() == QtCore.QEvent.MouseButtonPress
                and isinstance(watched, QtWidgets.QWidget)
                and watched.window() is self):
            editor = QtWidgets.QApplication.focusWidget()
            # Clicking a label or blank area does not normally move Qt focus.
            # End the edit before delivering that click, while keeping clicks
            # inside composite controls and their popup menus intact.
            if editor is not None:
                if isinstance(editor.parentWidget(), (QtWidgets.QAbstractSpinBox, QtWidgets.QComboBox)):
                    editor = editor.parentWidget()
                if watched is not editor and not editor.isAncestorOf(watched):
                    self._finish_focused_edit()
        return super().eventFilter(watched, event)

    @staticmethod
    def _enable_background_focus(container):
        if container.objectName() in {"ConfigScroll", "ConfigScrollContent", "SecondaryPage"}:
            container.setFocusPolicy(QtCore.Qt.ClickFocus)

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
        if not self.log_panel.isHidden():
            self.content_splitter.setSizes(self._log_sizes)

    def update_log_summary(self, text):
        self.collapsed_log.setText("输出日志  ·  " + (text or "就绪"))
        self.collapsed_log.setToolTip(text or "展开输出日志")

    def show_log(self):
        if self._log_expanded:
            return
        self._log_animation.stop()
        start = 0 if self.log_panel.isHidden() else self.content_splitter.sizes()[1]
        self._log_expanded = True
        total = sum(self.content_splitter.sizes())
        self.collapsed_log_bar.hide()
        self.log_panel.show()
        self.content_splitter.setStretchFactor(1, 0)
        bottom = min(max(140, self._log_sizes[1]), max(140, total // 2))
        self._animate_log(start, bottom)

    def _set_log_extent(self, value):
        total = sum(self.content_splitter.sizes())
        extent = max(0, min(round(value), total))
        self.content_splitter.setSizes([max(1, total - extent), extent])

    def _animate_log(self, start, end):
        self.main_container.layout().activate()
        self._log_animation.setStartValue(start)
        self._log_animation.setEndValue(end)
        self._set_log_extent(start)
        if not self.isVisible() or start == end:
            self._set_log_extent(end)
            self._finish_log_animation()
        else:
            self._log_animation.start()

    def _finish_log_animation(self):
        if self._log_expanded:
            self._log_sizes = self.content_splitter.sizes()
        else:
            self.log_panel.hide()
            self.collapsed_log_bar.show()

    def toggle_log(self):
        if self._log_expanded:
            self.hide_log()
        else:
            self.show_log()

    def hide_log(self):
        if not self._log_expanded:
            return
        sizes = self.content_splitter.sizes()
        self.content_splitter.setStretchFactor(1, 0)
        if self._log_animation.state() == QtCore.QAbstractAnimation.Running:
            # A reversal keeps the intended open height rather than storing
            # whichever partial frame happened to be on screen.
            if self._log_expanded:
                self._log_sizes[1] = round(self._log_animation.endValue())
        elif sizes[1] > 0:
            self._log_sizes = sizes
        self._log_animation.stop()
        self._log_expanded = False
        self._animate_log(sizes[1], 0)

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
        if page == "settings":
            widget.themeChanged.connect(self.apply_theme)
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
