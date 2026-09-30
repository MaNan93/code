"""QSS theme for the plmConsultant desktop interface."""

import sys

from PyQt5 import QtGui, QtWidgets


BG_SIDEBAR = "#F1F1F5"
BORDER = "#E0E0E0"
BORDER_STRONG = "#D0D0D0"
TEXT = "#333333"
ACCENT = "#1677FF"


def add_shadow(widget, blur=16, offset=(0, 2), alpha=25):
    effect = QtWidgets.QGraphicsDropShadowEffect(widget)
    effect.setBlurRadius(blur)
    effect.setOffset(*offset)
    effect.setColor(QtGui.QColor(20, 28, 40, alpha))
    widget.setGraphicsEffect(effect)


def apply_titlebar_theme(window):
    if sys.platform != "win32":
        return
    try:
        import ctypes

        def colorref(value):
            value = value.lstrip("#")
            red, green, blue = (int(value[index:index + 2], 16) for index in (0, 2, 4))
            return red | (green << 8) | (blue << 16)

        caption = ctypes.c_int(colorref(BG_SIDEBAR))
        text = ctypes.c_int(colorref(TEXT))
        hwnd = int(window.winId())
        ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, 35, ctypes.byref(caption), ctypes.sizeof(caption))
        ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, 36, ctypes.byref(text), ctypes.sizeof(text))
    except (AttributeError, OSError, ValueError):
        pass


class RoundedComboBox(QtWidgets.QComboBox):
    pass
