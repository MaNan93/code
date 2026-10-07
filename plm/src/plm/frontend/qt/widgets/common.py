"""Shared low-level helpers for Qt widgets."""

import os
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets

from plm.core.paths import PLM_ROOT
from plm.frontend.qt.styles.tokens import (
    BG_MAIN, BORDER, ICON_SIZE, ICON_SIZE_SM, RADIUS_CARD, SHADOW_SM, TEXT_SUB,
    scale_content_size,
)

LUCIDE_ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
APP_ICON_PATH = Path(__file__).resolve().parents[1] / "assets" / "app_icon.svg"
PROJECT_ROOT = PLM_ROOT


class ContentIconStyle(QtWidgets.QProxyStyle):
    """Scale native menu and dialog icons alongside explicit Lucide sizes."""

    ICON_METRICS = {
        QtWidgets.QStyle.PM_SmallIconSize,
        QtWidgets.QStyle.PM_LargeIconSize,
        QtWidgets.QStyle.PM_ButtonIconSize,
        QtWidgets.QStyle.PM_TabBarIconSize,
        QtWidgets.QStyle.PM_ToolBarIconSize,
        QtWidgets.QStyle.PM_MessageBoxIconSize,
    }

    def pixelMetric(self, metric, option=None, widget=None):
        size = super().pixelMetric(metric, option, widget)
        return scale_content_size(size) if metric in self.ICON_METRICS else size


def rounded_widget_path(rect, radii):
    """Build a vector outline with independent corner radii."""
    area = QtCore.QRectF(rect)
    limit = min(area.width(), area.height()) / 2
    tl, tr, br, bl = (min(radius, limit) for radius in radii)
    left, top, right, bottom = area.left(), area.top(), area.right(), area.bottom()
    path = QtGui.QPainterPath()
    path.moveTo(left + tl, top)
    path.lineTo(right - tr, top)
    if tr:
        path.arcTo(right - 2 * tr, top, 2 * tr, 2 * tr, 90, -90)
    path.lineTo(right, bottom - br)
    if br:
        path.arcTo(right - 2 * br, bottom - 2 * br, 2 * br, 2 * br, 0, -90)
    path.lineTo(left + bl, bottom)
    if bl:
        path.arcTo(left, bottom - 2 * bl, 2 * bl, 2 * bl, 270, -90)
    path.lineTo(left, top + tl)
    if tl:
        path.arcTo(left, top, 2 * tl, 2 * tl, 180, -90)
    path.closeSubpath()
    return path


class RoundedCanvasFrame(QtWidgets.QFrame):
    """Antialiased white canvas with an optional light border."""

    CORNER_RADII = (12, 8, 8, 8)
    BORDER_WIDTH = 1.0
    SHADOW_MARGIN = 2

    def apply_canvas_shadow(self):
        apply_drop_shadow(self, offset=(0, 0), blur_radius=4, alpha=60)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        inset = self.BORDER_WIDTH / 2
        path = rounded_widget_path(
            QtCore.QRectF(self.rect()).adjusted(inset, inset, -inset, -inset),
            self.CORNER_RADII,
        )
        painter.fillPath(path, QtGui.QColor(BG_MAIN))
        if self.BORDER_WIDTH:
            painter.setPen(QtGui.QPen(QtGui.QColor(BORDER), self.BORDER_WIDTH))
            painter.drawPath(path)
        painter.end()


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


class StatusBadge(QtWidgets.QLabel):
    """Compact status label with a palette-colored indicator dot."""

    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setContentsMargins(10, 0, 0, 0)

    def paintEvent(self, event):
        super().paintEvent(event)
        if not self.text():
            return
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(self.palette().color(QtGui.QPalette.WindowText))
        painter.drawEllipse(QtCore.QPointF(8.0, self.height() / 2.0), 2.5, 2.5)
        painter.end()


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
