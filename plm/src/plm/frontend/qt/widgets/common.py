"""Shared low-level helpers for Qt widgets."""

import os
import subprocess
import sys
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets


LUCIDE_ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
PROJECT_ROOT = Path(__file__).resolve().parents[5]
ICON_SIZE = 20


def load_lucide_icon(
    name, color="#666666", size=ICON_SIZE, align_visible_left=False
):
    """Load, rasterize, and recolor one Lucide SVG."""
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


def make_icon_button(
    icon_name,
    tooltip,
    object_name="IconButton",
    button_size=28,
    icon_size=ICON_SIZE,
    color="#666666",
):
    button = QtWidgets.QPushButton()
    button.setObjectName(object_name)
    button.setIcon(load_lucide_icon(icon_name, color, icon_size))
    button.setIconSize(QtCore.QSize(icon_size, icon_size))
    button.setFixedSize(button_size, button_size)
    button.setToolTip(tooltip)
    button.setCursor(QtCore.Qt.PointingHandCursor)
    return button


def apply_drop_shadow(widget, offset=(0, 1), blur_radius=4, alpha=15):
    """Apply one of the shared elevation levels to a widget."""
    shadow = QtWidgets.QGraphicsDropShadowEffect(widget)
    shadow.setOffset(*offset)
    shadow.setBlurRadius(blur_radius)
    shadow.setColor(QtGui.QColor(0, 0, 0, alpha))
    widget.setGraphicsEffect(shadow)
    return shadow


def open_in_file_manager(path):
    """Open a local path with the platform file manager."""
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
    """QMenu with the shared popup elevation (QSS cannot draw shadows)."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        apply_drop_shadow(self, offset=(0, 4), blur_radius=12, alpha=40)
