"""Compatibility theme helpers using the shared PLM-style design tokens."""

import sys
from PyQt5 import QtCore, QtGui, QtWidgets
from fizz.frontend.qt.styles import build_stylesheet, APP_QSS
from fizz.frontend.qt.styles.tokens import (
    BG_MAIN as BG,
    BG_MAIN as BG_ELEVATED,
    BG_SIDEBAR,
    BG_HOVER,
    PRIMARY_SOFT as BG_ACTIVE,
    BORDER,
    TEXT_MAIN as TEXT,
    TEXT_SUB as TEXT_SECONDARY,
    TEXT_MUTED as TEXT_TERTIARY,
    PRIMARY as ACCENT,
    PRIMARY_HOVER as ACCENT_HOVER,
    DANGER,
    FONT_SIZE_BODY,
)

BORDER_STRONG = "#CBD2DC"
BASE_FONT_PX = FONT_SIZE_BODY
STYLESHEET = APP_QSS


def add_shadow(widget, blur=16, offset=(0, 2), alpha=35):
    """Qt has no CSS box-shadow equivalent in QSS -- a
    QGraphicsDropShadowEffect is the actual way to give a widget the
    soft floating surface used by cards and controls."""
    effect = QtWidgets.QGraphicsDropShadowEffect(widget)
    effect.setBlurRadius(blur)
    effect.setOffset(*offset)
    effect.setColor(QtGui.QColor(0, 0, 0, alpha))
    widget.setGraphicsEffect(effect)


def apply_titlebar_theme(window):
    """Recolour a top-level window/dialog's native OS title bar to match
    the app's own theme.

    Qt/QSS only styles the client area -- the title bar is drawn by the
    OS. DWMWA_CAPTION_COLOR/DWMWA_TEXT_COLOR (Windows 11 build 22000+)
    are the only supported way to change that; on any older Windows, or
    any non-Windows platform, DwmSetWindowAttribute simply fails and this
    is a no-op. Call this on every top-level QMainWindow/QDialog the app
    creates (main window, Settings, the Documentation viewer, ...), not
    just the main window, since each gets its own native title bar."""
    if sys.platform != "win32":
        return
    import ctypes

    def _colorref(hex_color):
        hex_color = hex_color.lstrip("#")
        r, g, b = (int(hex_color[i : i + 2], 16) for i in (0, 2, 4))
        return r | (g << 8) | (b << 16)  # COLORREF is 0x00BBGGRR, not RGB

    try:
        hwnd = int(window.winId())
        dwmapi = ctypes.windll.dwmapi
        DWMWA_CAPTION_COLOR = 35
        DWMWA_TEXT_COLOR = 36
        caption_color = (
            BG_SIDEBAR if isinstance(window, QtWidgets.QMainWindow) else BG_ELEVATED
        )
        caption = ctypes.c_int(_colorref(caption_color))
        text = ctypes.c_int(_colorref(TEXT))
        dwmapi.DwmSetWindowAttribute(
            hwnd, DWMWA_CAPTION_COLOR, ctypes.byref(caption), ctypes.sizeof(caption)
        )
        dwmapi.DwmSetWindowAttribute(
            hwnd, DWMWA_TEXT_COLOR, ctypes.byref(text), ctypes.sizeof(text)
        )
    except (OSError, AttributeError, ValueError):
        pass


class VisibleCheckBox(QtWidgets.QCheckBox):
    """Checkbox whose square remains visible with the application QSS."""

    def sizeHint(self):
        hint = super().sizeHint()
        return QtCore.QSize(max(18, hint.width()), max(18, hint.height()))

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        size = 16
        box = QtCore.QRectF(0.5, (self.height() - size) / 2 + 0.5, size - 1, size - 1)
        checked = self.isChecked()
        fill = ACCENT if checked else BG
        border = ACCENT if checked else BORDER_STRONG
        if not self.isEnabled():
            fill = BG_ACTIVE if checked else BG_ELEVATED
            border = BORDER
        painter.setBrush(QtGui.QColor(fill))
        painter.setPen(QtGui.QPen(QtGui.QColor(border), 1))
        painter.drawRoundedRect(box, 2, 2)
        if checked:
            pen = QtGui.QPen(QtGui.QColor("#ffffff"), 2)
            pen.setCapStyle(QtCore.Qt.RoundCap)
            pen.setJoinStyle(QtCore.Qt.RoundJoin)
            painter.setPen(pen)
            mid_y = self.height() / 2
            painter.drawLine(QtCore.QPointF(4, mid_y), QtCore.QPointF(7, mid_y + 3))
            painter.drawLine(
                QtCore.QPointF(7, mid_y + 3), QtCore.QPointF(13, mid_y - 4)
            )
        if self.text():
            painter.setPen(self.palette().color(QtGui.QPalette.WindowText))
            painter.drawText(
                QtCore.QRect(24, 0, max(0, self.width() - 24), self.height()),
                QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter,
                self.text(),
            )
        painter.end()
