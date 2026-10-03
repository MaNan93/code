"""Compatibility styling aliases backed by the BeautifulUI token set."""
from PyQt5 import QtWidgets
from plm.frontend.qt.styles.tokens import (
    BG_SUBTLE, BORDER, BORDER_HOVER, PRIMARY, TEXT_MAIN, TEXT_MUTED, TEXT_SUB, SHADOW_MD,
)
from plm.frontend.qt.widgets.common import apply_drop_shadow

ACCENT = PRIMARY
BORDER_STRONG = BORDER_HOVER
TEXT = TEXT_MAIN
TEXT_SECONDARY = TEXT_SUB
TEXT_TERTIARY = TEXT_MUTED
BG_HOVER = BG_SUBTLE


class RoundedComboBox(QtWidgets.QComboBox):
    """Compatibility alias; visual styling comes from the application QSS."""


def add_shadow(widget, blur=None, offset=None, alpha=None):
    return apply_drop_shadow(widget, offset=offset, blur_radius=blur, alpha=alpha, shadow=SHADOW_MD)
