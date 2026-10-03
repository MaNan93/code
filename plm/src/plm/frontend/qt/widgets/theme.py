"""Compatibility styling helpers for restored legacy Qt widgets.

Keep the restored table/lane-grid behavior without bringing back the old
font/theme stack. New UI code should continue using plm.frontend.qt.styles
and widgets.common directly.
"""

from PyQt5 import QtWidgets

from plm.frontend.qt.widgets.common import apply_drop_shadow

ACCENT = "#1677FF"
BORDER = "#E0E0E0"
BORDER_STRONG = "#B8BDC6"
TEXT = "#333333"
TEXT_SECONDARY = "#666666"
TEXT_TERTIARY = "#8C8C8C"
BG_HOVER = "#F5F5F5"


class RoundedComboBox(QtWidgets.QComboBox):
    """Compatibility alias; visual styling comes from the application QSS."""


def add_shadow(widget, blur=8, offset=(0, 1), alpha=30):
    return apply_drop_shadow(widget, offset=offset, blur_radius=blur, alpha=alpha)
