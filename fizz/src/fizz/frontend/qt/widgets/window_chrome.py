"""Frameless title bar, drag gestures and edge resizing."""

from PyQt5 import QtCore, QtWidgets

from fizz.frontend.qt.styles.tokens import PRIMARY
from fizz.frontend.qt.widgets.common import icon_button, load_lucide_icon


class WindowTitleBar(QtWidgets.QFrame):
    def __init__(self, window):
        super().__init__(window)
        self.window = window
        self.drag_offset = None
        self.setObjectName("WindowTitleBar")
        self.setFixedHeight(44)
        row = QtWidgets.QHBoxLayout(self)
        row.setContentsMargins(18, 0, 0, 0)
        row.setSpacing(8)
        logo = QtWidgets.QLabel()
        logo.setPixmap(load_lucide_icon("file-code-corner", PRIMARY).pixmap(20, 20))
        logo.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        row.addWidget(logo)
        brand = QtWidgets.QLabel("fizz")
        brand.setObjectName("WindowBrandName")
        brand.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        row.addWidget(brand)
        self.collapse_btn = icon_button("panel-left", "收起侧栏")
        row.addWidget(self.collapse_btn)
        row.addStretch(1)
        self.minimize_btn = self._control(
            "minus", "最小化", "minimize", window.showMinimized
        )
        self.maximize_btn = self._control(
            "square", "最大化", "maximize", self.toggle_maximized
        )
        self.close_btn = self._control("x", "关闭", "close", window.close)
        for widget in (self.minimize_btn, self.maximize_btn, self.close_btn):
            row.addWidget(widget)

    def _control(self, icon, tooltip, role, callback):
        widget = QtWidgets.QPushButton()
        widget.setObjectName("WindowControlButton")
        widget.setProperty("role", role)
        widget.setFixedSize(46, 44)
        widget.setIcon(load_lucide_icon(icon))
        widget.setToolTip(tooltip)
        widget.setAccessibleName(tooltip)
        widget.clicked.connect(callback)
        return widget

    def sidebar_changed(self, collapsed):
        self.collapse_btn.setIcon(
            load_lucide_icon("panel-right" if collapsed else "panel-left")
        )
        self.collapse_btn.setToolTip("展开侧栏" if collapsed else "收起侧栏")

    def toggle_maximized(self):
        self.window.showNormal() if self.window.isMaximized() else self.window.showMaximized()
        self.update_window_state()

    def update_window_state(self):
        maximized = self.window.isMaximized()
        self.maximize_btn.setIcon(load_lucide_icon("copy" if maximized else "square"))
        self.maximize_btn.setToolTip("还原" if maximized else "最大化")

    def mouseDoubleClickEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.toggle_maximized()
            event.accept()

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.drag_offset = event.globalPos() - self.window.frameGeometry().topLeft()
            if (
                self.window.windowHandle()
                and self.window.windowHandle().startSystemMove()
            ):
                self.drag_offset = None
            event.accept()

    def mouseMoveEvent(self, event):
        if self.drag_offset is not None and event.buttons() & QtCore.Qt.LeftButton:
            if self.window.isMaximized():
                self.window.showNormal()
                self.drag_offset = QtCore.QPoint(self.window.width() // 2, 22)
            self.window.move(event.globalPos() - self.drag_offset)
            event.accept()

    def mouseReleaseEvent(self, event):
        self.drag_offset = None


class ResizeHandle(QtWidgets.QWidget):
    def __init__(self, window, edges, cursor):
        super().__init__(window)
        self.window = window
        self.edges = edges
        self.origin = None
        self.setCursor(cursor)
        self.setStyleSheet("background: transparent;")

    def mousePressEvent(self, event):
        if event.button() != QtCore.Qt.LeftButton:
            return
        handle = self.window.windowHandle()
        if handle and handle.startSystemResize(self.edges):
            return
        self.origin = event.globalPos()
        self.initial_geometry = self.window.geometry()
        event.accept()

    def mouseMoveEvent(self, event):
        if self.origin is None:
            return
        delta = event.globalPos() - self.origin
        rect = QtCore.QRect(self.initial_geometry)
        if self.edges & QtCore.Qt.LeftEdge:
            rect.setLeft(
                min(
                    rect.right() - self.window.minimumWidth() + 1,
                    rect.left() + delta.x(),
                )
            )
        if self.edges & QtCore.Qt.RightEdge:
            rect.setRight(
                max(
                    rect.left() + self.window.minimumWidth() - 1,
                    rect.right() + delta.x(),
                )
            )
        if self.edges & QtCore.Qt.TopEdge:
            rect.setTop(
                min(
                    rect.bottom() - self.window.minimumHeight() + 1,
                    rect.top() + delta.y(),
                )
            )
        if self.edges & QtCore.Qt.BottomEdge:
            rect.setBottom(
                max(
                    rect.top() + self.window.minimumHeight() - 1,
                    rect.bottom() + delta.y(),
                )
            )
        self.window.setGeometry(rect)

    def mouseReleaseEvent(self, event):
        self.origin = None


def create_resize_handles(window):
    qt = QtCore.Qt
    specs = (
        (qt.LeftEdge, qt.SizeHorCursor),
        (qt.RightEdge, qt.SizeHorCursor),
        (qt.TopEdge, qt.SizeVerCursor),
        (qt.BottomEdge, qt.SizeVerCursor),
        (qt.LeftEdge | qt.TopEdge, qt.SizeFDiagCursor),
        (qt.RightEdge | qt.BottomEdge, qt.SizeFDiagCursor),
        (qt.RightEdge | qt.TopEdge, qt.SizeBDiagCursor),
        (qt.LeftEdge | qt.BottomEdge, qt.SizeBDiagCursor),
    )
    return [ResizeHandle(window, edges, cursor) for edges, cursor in specs]


def position_resize_handles(window):
    width, height, margin = window.width(), window.height(), 5
    rects = (
        (0, margin, margin, height - 2 * margin),
        (width - margin, margin, margin, height - 2 * margin),
        (margin, 0, width - 2 * margin, margin),
        (margin, height - margin, width - 2 * margin, margin),
        (0, 0, margin, margin),
        (width - margin, height - margin, margin, margin),
        (width - margin, 0, margin, margin),
        (0, height - margin, margin, margin),
    )
    for handle, rect in zip(window.resize_handles, rects):
        handle.setGeometry(*rect)
        handle.setVisible(not window.isMaximized())
        handle.raise_()
