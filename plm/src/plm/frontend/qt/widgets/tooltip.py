"""Compact tooltips with genuinely transparent, antialiased rounded corners."""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.styles.tokens import FONT_UI_PRIMARY, shrink_font_size


class RoundedToolTip(QtWidgets.QWidget):
    BACKGROUND = "#202123"
    RADIUS = 10
    MAX_TEXT_WIDTH = 360

    def __init__(self):
        super().__init__(None, QtCore.Qt.ToolTip | QtCore.Qt.FramelessWindowHint
                         | QtCore.Qt.NoDropShadowWindowHint)
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground, True)
        self.setAttribute(QtCore.Qt.WA_ShowWithoutActivating, True)
        self.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents, True)
        self.setFocusPolicy(QtCore.Qt.NoFocus)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(10, 6, 10, 6)
        self.label = QtWidgets.QLabel()
        self.label.setTextFormat(QtCore.Qt.PlainText)
        self.label.setWordWrap(True)
        self.label.setMaximumWidth(self.MAX_TEXT_WIDTH)
        self.label.setStyleSheet(
            f'background: transparent; border: none; color: white; '
            f'font-family: "{FONT_UI_PRIMARY}"; '
            f'font-size: {shrink_font_size(12)}px; padding: 0;'
        )
        layout.addWidget(self.label)

    def show_text(self, text, position, owner):
        self.label.setText(text)
        self.adjustSize()
        screen = QtWidgets.QApplication.screenAt(position) or owner.screen()
        available = screen.availableGeometry()
        self.resize(min(self.width(), available.width()),
                    min(self.height(), available.height()))
        x = max(available.left(), min(position.x(), available.right() + 1 - self.width()))
        y = position.y()
        if y + self.height() > available.bottom() + 1:
            y = owner.mapToGlobal(QtCore.QPoint()).y() - self.height() - 6
        y = max(available.top(), min(y, available.bottom() + 1 - self.height()))
        self.move(x, y)
        self.show()

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        path = QtGui.QPainterPath()
        path.addRoundedRect(QtCore.QRectF(self.rect()), self.RADIUS, self.RADIUS)
        painter.fillPath(path, QtGui.QColor(self.BACKGROUND))


class ToolTipController(QtCore.QObject):
    """Replace native tooltip windows while retaining Qt's hover delay."""

    def __init__(self, app):
        super().__init__(app)
        self.popup = None
        self._owner = None
        self._hide_timer = QtCore.QTimer(self)
        self._hide_timer.setSingleShot(True)
        self._hide_timer.timeout.connect(self.hide)
        app.installEventFilter(self)

    def hide(self):
        self._hide_timer.stop()
        self._owner = None
        if self.popup is not None:
            self.popup.hide()

    def _popup_destroyed(self):
        self.popup = None

    def eventFilter(self, watched, event):
        kind = event.type()
        if kind == QtCore.QEvent.ToolTip and isinstance(watched, QtWidgets.QWidget):
            text = watched.toolTip()
            if text:
                if self.popup is None:
                    self.popup = RoundedToolTip()
                    self.popup.destroyed.connect(self._popup_destroyed)
                self._owner = watched
                QtWidgets.QToolTip.hideText()
                position = event.globalPos() + QtCore.QPoint(12, 18)
                if isinstance(watched, QtWidgets.QAbstractButton):
                    position = watched.mapToGlobal(QtCore.QPoint(0, watched.height() + 6))
                self.popup.show_text(text, position, watched)
                duration = watched.toolTipDuration()
                self._hide_timer.start(duration if duration > 0 else 6000)
            else:
                self.hide()
            event.accept()
            return True
        if kind in (QtCore.QEvent.MouseButtonPress, QtCore.QEvent.MouseButtonDblClick,
                    QtCore.QEvent.Wheel, QtCore.QEvent.WindowDeactivate):
            self.hide()
        elif watched is self._owner and kind in (QtCore.QEvent.Leave, QtCore.QEvent.Hide):
            self.hide()
        return super().eventFilter(watched, event)


def install_tooltips(app):
    if not hasattr(app, "_rounded_tooltips"):
        app._rounded_tooltips = ToolTipController(app)
    return app._rounded_tooltips
