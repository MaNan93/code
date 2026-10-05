"""Shared low-level helpers for Qt widgets."""

import os
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets

from plm.core.paths import PLM_ROOT
from plm.frontend.qt.styles.tokens import RADIUS_CARD, SHADOW_SM, TEXT_SUB

LUCIDE_ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
APP_ICON_PATH = Path(__file__).resolve().parents[1] / "assets" / "app_icon.svg"
PROJECT_ROOT = PLM_ROOT
ICON_SIZE = 18


@lru_cache(maxsize=256)
def load_lucide_icon(name, color=TEXT_SUB, size=ICON_SIZE, align_visible_left=False):
    path = LUCIDE_ICON_DIR / f"{name}.svg"
    source = QtGui.QPixmap(size, size)
    source.fill(QtCore.Qt.transparent)
    renderer = QtSvg.QSvgRenderer(str(path))
    if not renderer.isValid():
        return QtGui.QIcon(source)
    painter = QtGui.QPainter(source)
    painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
    renderer.render(painter)
    painter.end()
    colored = QtGui.QPixmap(size, size)
    colored.fill(QtCore.Qt.transparent)
    painter = QtGui.QPainter(colored)
    painter.drawPixmap(0, 0, source)
    painter.setCompositionMode(QtGui.QPainter.CompositionMode_SourceIn)
    painter.fillRect(colored.rect(), QtGui.QColor(color))
    painter.end()
    if align_visible_left:
        visible_bounds = QtGui.QRegion(colored.mask()).boundingRect()
        if visible_bounds.isValid() and visible_bounds.left() > 0:
            aligned = QtGui.QPixmap(size, size)
            aligned.fill(QtCore.Qt.transparent)
            painter = QtGui.QPainter(aligned)
            painter.drawPixmap(-visible_bounds.left(), 0, colored)
            painter.end()
            colored = aligned
    return QtGui.QIcon(colored)


def make_icon_button(icon_name, tooltip, object_name="IconButton", button_size=28,
                     icon_size=ICON_SIZE, color=TEXT_SUB):
    button = QtWidgets.QPushButton()
    button.setObjectName(object_name)
    button.setIcon(load_lucide_icon(icon_name, color, icon_size))
    button.setIconSize(QtCore.QSize(icon_size, icon_size))
    button.setFixedSize(button_size, button_size)
    button.setToolTip(tooltip)
    button.setCursor(QtCore.Qt.PointingHandCursor)
    return button


def apply_drop_shadow(widget, offset=None, blur_radius=None, alpha=None, shadow=SHADOW_SM):
    preset = shadow or SHADOW_SM
    final_offset = preset["offset"] if offset is None else offset
    final_blur = preset["blur_radius"] if blur_radius is None else blur_radius
    final_rgba = preset["rgba"]
    final_alpha = final_rgba[3] if alpha is None else alpha
    effect = QtWidgets.QGraphicsDropShadowEffect(widget)
    effect.setOffset(*final_offset)
    effect.setBlurRadius(final_blur)
    effect.setColor(QtGui.QColor(final_rgba[0], final_rgba[1], final_rgba[2], final_alpha))
    widget.setGraphicsEffect(effect)
    return effect


def open_in_file_manager(path):
    resolved_path = Path(path).resolve()
    if not resolved_path.exists():
        return False
    try:
        if sys.platform == "win32":
            os.startfile(str(resolved_path))
        elif sys.platform == "darwin":
            subprocess.Popen(["open", str(resolved_path)])
        else:
            subprocess.Popen(["xdg-open", str(resolved_path)])
    except OSError:
        return False
    return True


class StyledMenu(QtWidgets.QMenu):
    """Rounded popup clipped at the native window boundary."""
    RADIUS = float(RADIUS_CARD)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground)
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.FramelessWindowHint | QtCore.Qt.NoDropShadowWindowHint)

    def _apply_round_mask(self):
        if self.width() <= 0 or self.height() <= 0:
            return
        rect = QtCore.QRectF(self.rect()).adjusted(0.0, 0.0, -1.0, -1.0)
        path = QtGui.QPainterPath()
        path.addRoundedRect(rect, self.RADIUS, self.RADIUS)
        self.setMask(QtGui.QRegion(path.toFillPolygon().toPolygon()))

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._apply_round_mask()

    def showEvent(self, event):
        self._apply_round_mask()
        super().showEvent(event)
