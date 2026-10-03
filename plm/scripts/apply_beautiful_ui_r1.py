#!/usr/bin/env python3
"""One-shot BeautifulUI visual redesign for the PLM Qt r1 baseline."""
from pathlib import Path
import re

ROOT = Path("src/plm/frontend/qt")


def write(rel, text):
    path = ROOT / rel
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def replace(rel, old, new, count=-1, required=True):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    if required and old not in text:
        raise RuntimeError(f"pattern not found in {rel}: {old[:80]!r}")
    text2 = text.replace(old, new, count)
    path.write_text(text2, encoding="utf-8")


TOKENS = '''"""BeautifulUI design tokens shared by QSS and Qt widgets."""

PRIMARY = "#3B82F6"
PRIMARY_HOVER = "#2563EB"
PRIMARY_LIGHT = "#EFF6FF"
BG_MAIN = "#F7F9FC"
BG_SURFACE = "#FFFFFF"
BG_SUBTLE = "#F1F5F9"
BORDER = "#E2E8F0"
BORDER_HOVER = "#CBD5E1"
BORDER_FOCUS = "#3B82F6"
TEXT_MAIN = "#1E293B"
TEXT_SUB = "#64748B"
TEXT_MUTED = "#94A3B8"
DANGER = "#EF4444"
SUCCESS = "#10B981"

FONT_FAMILY = '\"Inter\", \"Microsoft YaHei UI\", \"PingFang SC\", sans-serif'
FONT_MONO = '\"JetBrains Mono\", \"Consolas\", \"Courier New\", monospace'
FONT_SIZE_BODY = 13
FONT_SIZE_SM = 12
FONT_SIZE_LG = 15

RADIUS_CHIP = 6
RADIUS_CONTROL = 8
RADIUS_CARD = 10
RADIUS_WINDOW = 14

SPACING_XS = 4
SPACING_SM = 8
SPACING_MD = 12
SPACING_LG = 16
SPACING_XL = 24

SHADOW_SM = {"blur_radius": 4, "offset": (0, 1), "rgba": (0, 0, 0, 20)}
SHADOW_MD = {"blur_radius": 8, "offset": (0, 2), "rgba": (0, 0, 0, 30)}
SHADOW_LG = {"blur_radius": 12, "offset": (0, 4), "rgba": (0, 0, 0, 50)}

QSS_TOKENS = {
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_light": PRIMARY_LIGHT,
    "bg_main": BG_MAIN,
    "bg_surface": BG_SURFACE,
    "bg_subtle": BG_SUBTLE,
    "border": BORDER,
    "border_hover": BORDER_HOVER,
    "border_focus": BORDER_FOCUS,
    "text_main": TEXT_MAIN,
    "text_sub": TEXT_SUB,
    "text_muted": TEXT_MUTED,
    "danger": DANGER,
    "success": SUCCESS,
    "font_family": FONT_FAMILY,
    "font_mono": FONT_MONO,
    "font_size_body": f"{FONT_SIZE_BODY}px",
    "font_size_sm": f"{FONT_SIZE_SM}px",
    "font_size_lg": f"{FONT_SIZE_LG}px",
    "radius_chip": f"{RADIUS_CHIP}px",
    "radius_control": f"{RADIUS_CONTROL}px",
    "radius_card": f"{RADIUS_CARD}px",
    "radius_window": f"{RADIUS_WINDOW}px",
    "spacing_xs": f"{SPACING_XS}px",
    "spacing_sm": f"{SPACING_SM}px",
    "spacing_md": f"{SPACING_MD}px",
    "spacing_lg": f"{SPACING_LG}px",
    "spacing_xl": f"{SPACING_XL}px",
}

COLORS = {
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_light": PRIMARY_LIGHT,
    "bg_main": BG_MAIN,
    "bg_surface": BG_SURFACE,
    "bg_subtle": BG_SUBTLE,
    "border": BORDER,
    "border_hover": BORDER_HOVER,
    "border_focus": BORDER_FOCUS,
    "text_main": TEXT_MAIN,
    "text_sub": TEXT_SUB,
    "text_muted": TEXT_MUTED,
    "danger": DANGER,
    "success": SUCCESS,
}
'''
write("styles/tokens.py", TOKENS)

STYLE_INIT = '''"""Application-wide Qt stylesheet loading and customization."""

from pathlib import Path

from .tokens import FONT_FAMILY, QSS_TOKENS

_STYLE_PATH = Path(__file__).with_name("app.qss")
_CJK_FONT_FALLBACKS = (
    "Microsoft YaHei UI",
    "PingFang SC",
    "Noto Sans CJK SC",
    "SimHei",
    "SimSun",
)


def _font_family_stack(font_family):
    requested = (font_family or "Inter").replace('"', "").strip()
    families = (requested, "Inter", *_CJK_FONT_FALLBACKS)
    seen = set()
    ordered = []
    for family in families:
        key = family.casefold()
        if family and key not in seen:
            seen.add(key)
            ordered.append(f'"{family}"')
    ordered.append("sans-serif")
    return ", ".join(ordered)


def _render_qss(overrides=None):
    qss = _STYLE_PATH.read_text(encoding="utf-8")
    tokens = dict(QSS_TOKENS)
    if overrides:
        tokens.update(overrides)
    for name in sorted(tokens, key=len, reverse=True):
        qss = qss.replace(f"${name}", str(tokens[name]))
    return qss


APP_QSS = _render_qss()


def build_app_stylesheet(font_family, font_size):
    size = int(font_size or 13)
    return _render_qss({
        "font_family": _font_family_stack(font_family),
        "font_size_body": f"{size}px",
    })


__all__ = ["APP_QSS", "build_app_stylesheet", "FONT_FAMILY"]
'''
write("styles/__init__.py", STYLE_INIT)

QSS = r'''QWidget {
    background-color: $bg_main;
    color: $text_main;
    font-family: $font_family;
    font-size: $font_size_body;
    font-weight: normal;
}
QWidget:disabled { color: $text_muted; }
QLabel { background: transparent; }
QMainWindow, QWidget#AppRoot { background-color: $bg_main; }

QPushButton {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_control;
    padding: $spacing_sm $spacing_lg;
    color: $text_main;
    font-size: $font_size_body;
}
QPushButton:hover {
    background-color: $bg_subtle;
    border-color: $border_hover;
}
QPushButton:pressed { background-color: $border; }
QPushButton:disabled {
    background-color: $bg_subtle;
    color: $text_muted;
    border-color: $border;
}
QPushButton#PrimaryBtn, QPushButton#SettingsPrimaryButton,
QPushButton#ConfigGenerateButton, QPushButton#CreateProjectButton {
    background-color: $primary;
    border: none;
    color: $bg_surface;
}
QPushButton#PrimaryBtn:hover, QPushButton#SettingsPrimaryButton:hover,
QPushButton#ConfigGenerateButton:hover, QPushButton#CreateProjectButton:hover {
    background-color: $primary_hover;
}
QPushButton#SettingsSecondaryButton, QPushButton#SettingsBrowseButton,
QPushButton#ConfigRowButton {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_control;
}

QLineEdit, QComboBox, QSpinBox {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_control;
    padding: $spacing_sm $spacing_md;
    color: $text_main;
    font-size: $font_size_body;
    selection-background-color: $primary_light;
    selection-color: $text_main;
}
QLineEdit:hover, QComboBox:hover, QSpinBox:hover { border-color: $border_hover; }
QLineEdit:focus, QComboBox:focus, QSpinBox:focus { border: 1px solid $border_focus; }
QComboBox::drop-down { border: none; width: 32px; }
QComboBox QAbstractItemView {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_control;
    selection-background-color: $primary_light;
    selection-color: $text_main;
    outline: none;
    padding: $spacing_xs;
}

QFrame#Card, QWidget#Card, QFrame#ProjectHoverCard {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_card;
}

QTableWidget {
    background-color: $bg_surface;
    alternate-background-color: $bg_surface;
    border: none;
    gridline-color: $bg_subtle;
    color: $text_main;
    font-size: $font_size_body;
    outline: none;
}
QTableWidget::item {
    padding: $spacing_sm $spacing_md;
    border: none;
    border-bottom: 1px solid $bg_subtle;
}
QTableWidget::item:selected {
    background-color: $primary_light;
    color: $text_main;
}
QHeaderView::section {
    background-color: $bg_subtle;
    border: none;
    border-bottom: 1px solid $border;
    padding: $spacing_sm $spacing_md;
    font-weight: bold;
    color: $text_main;
}
QTableCornerButton::section { background-color: $bg_subtle; border: none; }

QMenu {
    min-width: 180px;
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_card;
    padding: 6px;
}
QMenu::item {
    min-height: 28px;
    padding: $spacing_sm $spacing_lg;
    border-radius: $radius_chip;
    color: $text_main;
}
QMenu::item:selected {
    background-color: $primary_light;
    color: $primary;
}
QMenu::item:disabled { color: $text_muted; }
QMenu::separator {
    height: 1px;
    background-color: $border;
    margin: $spacing_xs $spacing_sm;
}

QTabWidget::pane { border: none; background: transparent; }
QTabBar { background: transparent; }
QTabBar::tab {
    background: transparent;
    color: $text_sub;
    padding: $spacing_sm $spacing_lg;
    border: none;
    border-bottom: 2px solid transparent;
    font-size: $font_size_body;
}
QTabBar::tab:selected {
    color: $primary;
    border-bottom: 2px solid $primary;
    font-weight: bold;
}
QTabBar::tab:hover:!selected { color: $text_main; }

QScrollBar:vertical {
    background: transparent;
    width: 6px;
    margin: 0;
}
QScrollBar::handle:vertical {
    background: $border_hover;
    border-radius: 3px;
    min-height: 30px;
}
QScrollBar::handle:vertical:hover { background: $text_muted; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: transparent; }
QScrollBar:horizontal {
    background: transparent;
    height: 6px;
    margin: 0;
}
QScrollBar::handle:horizontal {
    background: $border_hover;
    border-radius: 3px;
    min-width: 30px;
}
QScrollBar::handle:horizontal:hover { background: $text_muted; }
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal { width: 0; }

QSplitter::handle { background-color: transparent; }
QSplitter::handle:horizontal { width: 4px; }
QSplitter::handle:horizontal:hover { background-color: $border_hover; }
QSplitter::handle:vertical { height: 1px; }
QSplitter#MainSplitter { background-color: $bg_main; }

QFrame#NavPanel {
    background-color: $bg_main;
    border-right: 1px solid $border;
}
QFrame#NavPanel[collapsed="true"] {
    background-color: $bg_main;
    border-right: 1px solid $border;
}
QWidget#NavBrandRow { background: transparent; }
QLabel#NavAppName {
    color: $text_main;
    font-size: $font_size_lg;
    font-weight: bold;
}
QLabel#ProjectSectionTitle {
    color: $text_muted;
    font-size: $font_size_sm;
    font-weight: bold;
    padding: $spacing_xs $spacing_md;
}
QListWidget#ProjectList {
    background: transparent;
    border: none;
    outline: none;
    padding: 0;
}
QListWidget#ProjectList::item { background: transparent; border: none; padding: 0; }
QPushButton#NavActionButton, QPushButton#NavFooterButton,
QPushButton#ProjectButton {
    min-height: 36px;
    max-height: 36px;
    background: transparent;
    border: none;
    border-radius: $radius_control;
    padding: 0 $spacing_md;
    color: $text_main;
    text-align: left;
}
QPushButton#NavActionButton:hover, QPushButton#NavFooterButton:hover,
QPushButton#ProjectButton:hover, QPushButton#NavIconBtn:hover,
QPushButton#NavCollapseButton:hover, QPushButton#ProjectArchiveBtn:hover,
QPushButton#ProjectMoreBtn:hover {
    background-color: $bg_subtle;
    border: none;
}
QPushButton#ProjectButton[selected="true"], QPushButton#NavFooterButton[selected="true"] {
    background-color: $primary_light;
    color: $primary;
    font-weight: bold;
}
QLabel#ProjectName { color: $text_main; font-size: $font_size_body; }
QLabel#ProjectName[selected="true"] { color: $primary; font-weight: bold; }
QPushButton#NavIconBtn, QPushButton#NavCollapseButton {
    min-width: 36px; max-width: 36px; min-height: 36px; max-height: 36px;
    background: transparent; border: none; border-radius: $radius_control; padding: 0;
}
QPushButton#ProjectArchiveBtn, QPushButton#ProjectMoreBtn {
    min-width: 28px; max-width: 28px; min-height: 28px; max-height: 28px;
    background: transparent; border: none; border-radius: $radius_chip; padding: 0;
}
QLabel#HoverProjectName { color: $text_main; font-size: $font_size_body; font-weight: bold; }
QLabel#HoverProjectPath { color: $text_sub; font-size: $font_size_sm; }
QFrame#HoverCardDivider { background-color: $border; border: none; }
QPushButton#HoverPinButton, QPushButton#HoverOpenButton {
    background: transparent; border: none; border-radius: $radius_chip; padding: 0;
}
QPushButton#HoverPinButton:hover, QPushButton#HoverOpenButton:hover { background: $bg_subtle; }

QFrame#ConfigPage { background-color: $bg_main; border: none; }
QFrame#ConfigHeader {
    background-color: $bg_surface;
    border: none;
    border-bottom: 1px solid $border;
}
QLabel#ConfigSessionTitle {
    color: $text_main;
    font-size: $font_size_lg;
    font-weight: bold;
}
QLineEdit#ConfigSessionEditor { min-height: 32px; }
QPushButton#HeaderButton, QPushButton#ArtifactsToolButton,
QPushButton#LogClearButton, QPushButton#LogCloseBtn,
QPushButton#PlaceholderBackButton {
    background: transparent;
    border: none;
    border-radius: $radius_control;
    padding: 0;
}
QPushButton#HeaderButton:hover, QPushButton#ArtifactsToolButton:hover,
QPushButton#LogClearButton:hover, QPushButton#LogCloseBtn:hover,
QPushButton#PlaceholderBackButton:hover { background-color: $bg_subtle; }
QPushButton#ArtifactsToolButton:checked { background-color: $primary_light; }
QWidget#ConfigArea, QScrollArea#ConfigScroll, QWidget#ConfigScrollContent { background: $bg_main; border: none; }
QTabWidget#ConfigTabs::pane { border: none; background: transparent; top: -1px; }
QLabel#ConfigTitle { color: $text_main; font-size: $font_size_lg; font-weight: bold; }
QLabel#ConfigDescription { color: $text_sub; font-size: $font_size_body; }
QTableWidget#ConfigDataTable { background-color: $bg_surface; }

QFrame#ArtifactsPanel {
    background-color: $bg_surface;
    border: 1px solid $border;
    border-radius: $radius_card;
}
QWidget#ArtifactsToolbar, QWidget#ArtifactSearchBar { background: transparent; }
QPlainTextEdit#ArtifactCodePreview {
    background-color: $bg_surface;
    color: $text_main;
    border: none;
    border-radius: $radius_control;
    selection-background-color: $primary_light;
    selection-color: $text_main;
    font-family: $font_mono;
    font-size: $font_size_sm;
}
QTreeWidget#ArtifactFileTree {
    background-color: $bg_surface;
    color: $text_main;
    border: 1px solid $border;
    border-radius: $radius_control;
    outline: none;
    padding: $spacing_xs;
}
QTreeWidget#ArtifactFileTree::item { min-height: 28px; border-radius: $radius_chip; }
QTreeWidget#ArtifactFileTree::item:selected { background: $primary_light; color: $primary; }
QLabel#ArtifactEmptyText, QLabel#ArtifactStatus {
    color: $text_muted;
    font-size: $font_size_body;
}
QLabel#ArtifactStatus { font-size: $font_size_sm; }

QFrame#LogPanel {
    background-color: $bg_surface;
    border: none;
    border-top: 1px solid $border;
}
QFrame#LogHeader { background-color: $bg_surface; border: none; }
QLabel#LogTabTitle { color: $text_main; font-size: $font_size_body; font-weight: bold; }
QPlainTextEdit#LogOutput {
    background-color: $bg_surface;
    color: $text_main;
    border: none;
    padding: $spacing_sm $spacing_lg;
    font-family: $font_mono;
    font-size: $font_size_sm;
}
QFrame#LogStatusBar {
    background: $bg_subtle;
    border: none;
    border-top: 1px solid $border;
}
QLabel#LogStatusText { color: $text_sub; font-size: $font_size_sm; }

QLabel#GenerationStatus, QLabel#ArtifactStatus { color: $text_muted; }
QLabel#GenerationStatus[state="up_to_date"], QLabel#ArtifactStatus[state="up_to_date"] { color: $success; }
QLabel#GenerationStatus[state="out_of_date"], QLabel#ArtifactStatus[state="out_of_date"],
QLabel#GenerationStatus[state="external_changed"], QLabel#ArtifactStatus[state="external_changed"] { color: $text_sub; }
QLabel#GenerationStatus[state="failed"], QLabel#ArtifactStatus[state="failed"],
QLabel#GenerationStatus[state="invalid"], QLabel#ArtifactStatus[state="invalid"] { color: $danger; }

QFrame#PlaceholderOverlay, QWidget#PlaceholderPageArea { background-color: $bg_main; }
QFrame#PlaceholderDialogHeader {
    background-color: $bg_surface;
    border: none;
    border-bottom: 1px solid $border;
}
QLabel#PlaceholderDialogTitle {
    color: $text_main;
    font-size: $font_size_lg;
    font-weight: bold;
}
QWidget#PlaceholderPagePanel, QWidget#PlaceholderContent, QWidget#PlaceholderTabs { background: transparent; }
QFrame#PlaceholderTabDivider { background-color: $border; border: none; }
QPushButton#PlaceholderMenuButton {
    min-height: 36px; max-height: 36px;
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    color: $text_sub;
    font-size: $font_size_body;
    padding: 0 $spacing_md;
}
QPushButton#PlaceholderMenuButton:hover { background: transparent; color: $text_main; }
QPushButton#PlaceholderMenuButton[selected="true"] {
    background: transparent;
    color: $primary;
    border-bottom: 2px solid $primary;
    font-weight: bold;
}
QLabel#PlaceholderHeading { color: $text_main; font-size: $font_size_lg; font-weight: bold; }
QLabel#PlaceholderDescription { color: $text_sub; font-size: $font_size_body; }
QFrame#PlaceholderSettingRow {
    background-color: transparent;
    border: none;
    border-bottom: 1px solid $border;
}
QLabel#PlaceholderRowLabel { color: $text_main; font-size: $font_size_body; }
QLabel#SettingsStatus { color: $text_sub; font-size: $font_size_sm; }
QFontComboBox#SettingsFontFamily, QComboBox#SettingsFontFamily,
QSpinBox#SettingsFontSize, QLineEdit#SettingsEditorPath { min-height: 36px; max-height: 36px; }

QDialog { background-color: $bg_main; color: $text_main; }
QDialogButtonBox { background: transparent; }
QToolTip {
    background-color: $text_main;
    color: $bg_surface;
    border: none;
    border-radius: $radius_chip;
    padding: $spacing_xs $spacing_sm;
    font-size: $font_size_sm;
}
'''
write("styles/app.qss", QSS)

COMMON = '''"""Shared low-level helpers for Qt widgets."""

import os
import subprocess
import sys
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets

from plm.core.paths import PLM_ROOT
from plm.frontend.qt.styles.tokens import RADIUS_CARD, SHADOW_SM, TEXT_SUB

LUCIDE_ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
APP_ICON_PATH = Path(__file__).resolve().parents[1] / "assets" / "app_icon.svg"
PROJECT_ROOT = PLM_ROOT
ICON_SIZE = 18


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
'''
write("widgets/common.py", COMMON)

THEME = '''"""Compatibility styling aliases backed by the BeautifulUI token set."""
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
'''
write("widgets/theme.py", THEME)

replace("models/preferences.py", 'DEFAULT_FONT_FAMILY = "Microsoft YaHei UI"', 'DEFAULT_FONT_FAMILY = "Inter"')
replace("main.py", 'from plm.frontend.qt.styles import APP_QSS\n', 'from plm.frontend.qt.styles import APP_QSS\nfrom plm.frontend.qt.models.preferences import DEFAULT_FONT_FAMILY\n')
replace("main.py", 'font.setFamily("Microsoft YaHei UI")', 'font.setFamily(DEFAULT_FONT_FAMILY)')

# Nav geometry and icon colors.
replace("views/nav_panel.py", 'from plm.frontend.qt.widgets.project_list import ProjectList\n', 'from plm.frontend.qt.widgets.project_list import ProjectList\nfrom plm.frontend.qt.styles.tokens import PRIMARY, SPACING_MD, SPACING_SM, TEXT_SUB\n')
replace("views/nav_panel.py", 'self.expanded_width = 260\n        self.collapsed_width = 56\n        self.expanded_min_width = 200\n        self.expanded_max_width = 400', 'self.expanded_width = 240\n        self.collapsed_width = 56\n        self.expanded_min_width = 240\n        self.expanded_max_width = 240')
replace("views/nav_panel.py", 'root.setContentsMargins(12, 8, 12, 8)\n        root.setSpacing(8)', 'root.setContentsMargins(SPACING_MD, SPACING_SM, SPACING_MD, SPACING_SM)\n        root.setSpacing(SPACING_SM)')
replace("views/nav_panel.py", '"layout-dashboard", "#1677FF", align_visible_left=True\n            ).pixmap(20, 20)\n        )\n        self.logo_label.setFixedSize(20, 20)', '"layout-dashboard", PRIMARY, 18, align_visible_left=True\n            ).pixmap(18, 18)\n        )\n        self.logo_label.setFixedSize(18, 18)')
replace("views/nav_panel.py", '"panel-left", "收起侧边栏", "NavCollapseButton", 32, ICON_SIZE', '"panel-left", "收起侧边栏", "NavCollapseButton", 36, ICON_SIZE')
replace("views/nav_panel.py", '"#666666",\n            )', 'TEXT_SUB,\n            )', required=False)
replace("views/nav_panel.py", 'button.setFixedSize(32, 32)', 'button.setFixedSize(36, 36)')
replace("views/nav_panel.py", '"NavIconBtn",\n            32,\n            ICON_SIZE,', '"NavIconBtn",\n            36,\n            ICON_SIZE,')
replace("views/nav_panel.py", 'color = "#1677FF" if selected else "#666666"', 'color = PRIMARY if selected else TEXT_SUB')
replace("views/nav_panel.py", 'load_lucide_icon("file-text", "#1677FF"', 'load_lucide_icon("file-text", PRIMARY', required=False)
replace("views/nav_panel.py", 'load_lucide_icon("settings", "#1677FF"', 'load_lucide_icon("settings", PRIMARY', required=False)
replace("views/nav_panel.py", '"#666666"', 'TEXT_SUB', required=False)
replace("views/nav_panel.py", '"#1677FF"', 'PRIMARY', required=False)

# Main card/header layout.
replace("views/config_page.py", 'from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel\n', 'from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel\nfrom plm.frontend.qt.styles.tokens import (\n    BG_SURFACE, BORDER_HOVER, SHADOW_SM, SPACING_LG, SPACING_SM, TEXT_MUTED,\n)\n')
replace("views/config_page.py", 'self.setFixedHeight(56)', 'self.setFixedHeight(48)', count=1)
replace("views/config_page.py", 'layout.setContentsMargins(20, 8, 12, 8)\n        layout.setSpacing(8)', 'layout.setContentsMargins(SPACING_LG, 0, SPACING_LG, 0)\n        layout.setSpacing(SPACING_SM)')
replace("views/config_page.py", '"panel-bottom", "显示/隐藏输出面板", "HeaderButton", 28', '"panel-bottom", "显示/隐藏输出面板", "HeaderButton", 32, 18')
replace("views/config_page.py", '"panel-right", "显示/隐藏 Artifacts", "HeaderButton", 28', '"panel-right", "显示/隐藏 Artifacts", "HeaderButton", 32, 18')
replace("views/config_page.py", 'super().__init__(parent)\n        root = QtWidgets.QVBoxLayout(self)\n        root.setContentsMargins(20, 16, 20, 16)', 'super().__init__(parent)\n        self.setObjectName("Card")\n        apply_drop_shadow(self, shadow=SHADOW_SM)\n        root = QtWidgets.QVBoxLayout(self)\n        root.setContentsMargins(SPACING_LG, SPACING_LG, SPACING_LG, SPACING_LG)', count=1)
replace("views/config_page.py", 'painter.setPen(QtGui.QPen(QtGui.QColor("#C0C4CC"), 1))\n        painter.setBrush(QtGui.QColor("#FFFFFF"))', 'painter.setPen(QtGui.QPen(QtGui.QColor(BORDER_HOVER), 1))\n        painter.setBrush(QtGui.QColor(BG_SURFACE))')
replace("views/config_page.py", 'painter.setBrush(QtGui.QColor("#A0A5B0"))', 'painter.setBrush(QtGui.QColor(TEXT_MUTED))')
replace("views/config_page.py", '        apply_drop_shadow(self)\n', '', count=1)
replace("views/config_page.py", 'root.addSpacing(12)', 'root.addSpacing(SPACING_LG)', count=1)

# Artifacts styling and empty state.
replace("views/artifacts_panel.py", 'from plm.frontend.qt.widgets.common import (\n    ICON_SIZE, apply_drop_shadow, make_icon_button, open_in_file_manager,\n)\n', 'from plm.frontend.qt.widgets.common import (\n    ICON_SIZE, StyledMenu, apply_drop_shadow, load_lucide_icon, make_icon_button, open_in_file_manager,\n)\nfrom plm.frontend.qt.styles.tokens import PRIMARY, SHADOW_MD, SUCCESS, TEXT_MUTED\n')
replace("views/artifacts_panel.py", '_STATUS_COLORS = {\n    "New": "#107E3E",\n    "Modified": "#1677FF",\n    "Unchanged": "#8C8C8C",\n}', '_STATUS_COLORS = {\n    "New": SUCCESS,\n    "Modified": PRIMARY,\n    "Unchanged": TEXT_MUTED,\n}')
replace("views/artifacts_panel.py", 'apply_drop_shadow(self, offset=(0, 2), blur_radius=12, alpha=30)', 'apply_drop_shadow(self, shadow=SHADOW_MD)')
replace("views/artifacts_panel.py", 'root.setContentsMargins(12, 0, 12, 12)', 'root.setContentsMargins(16, 0, 16, 16)')
replace("views/artifacts_panel.py", 'button = make_icon_button(icon, tooltip, "ArtifactsToolButton", 24, ICON_SIZE)', 'button = make_icon_button(icon, tooltip, "ArtifactsToolButton", 28, ICON_SIZE)')
replace("views/artifacts_panel.py", '"git-compare", "显示与上一次预览的差异", "ArtifactsToolButton", 24, ICON_SIZE', '"git-compare", "显示与上一次预览的差异", "ArtifactsToolButton", 28, ICON_SIZE')
replace("views/artifacts_panel.py", '        self.search_bar = QtWidgets.QWidget()\n', '        self.search_bar = QtWidgets.QWidget()\n        self.search_bar.setObjectName("ArtifactSearchBar")\n')
old_preview = '''        self.preview = CodePreview()\n        self.preview.setPlaceholderText("尚无生成文件")\n        root.addWidget(self.preview, 1)\n'''
new_preview = '''        self.empty_state = QtWidgets.QWidget()\n        empty_layout = QtWidgets.QVBoxLayout(self.empty_state)\n        empty_layout.setContentsMargins(0, 0, 0, 0)\n        empty_layout.setSpacing(8)\n        empty_layout.addStretch(1)\n        empty_icon = QtWidgets.QLabel()\n        empty_icon.setAlignment(QtCore.Qt.AlignCenter)\n        empty_icon.setPixmap(load_lucide_icon("file-x", TEXT_MUTED, 48).pixmap(48, 48))\n        empty_layout.addWidget(empty_icon)\n        self.empty_text = QtWidgets.QLabel("暂无生成文件")\n        self.empty_text.setObjectName("ArtifactEmptyText")\n        self.empty_text.setAlignment(QtCore.Qt.AlignCenter)\n        empty_layout.addWidget(self.empty_text)\n        empty_layout.addStretch(1)\n        root.addWidget(self.empty_state, 1)\n\n        self.preview = CodePreview()\n        self.preview.setPlaceholderText("尚无生成文件")\n        root.addWidget(self.preview, 1)\n'''
replace("views/artifacts_panel.py", old_preview, new_preview)
replace("views/artifacts_panel.py", 'self.more_menu = QtWidgets.QMenu(self)', 'self.more_menu = StyledMenu(self)')
replace("views/artifacts_panel.py", '        self.current_path = Path(value) if value is not None else None\n        self.preview.clear()', '        self.current_path = Path(value) if value is not None else None\n        self.empty_state.setVisible(self.current_path is None)\n        self.preview.setVisible(self.current_path is not None)\n        self.preview.clear()')

# Log uses shared QSS only.
replace("views/log_panel.py", '"trash-2", "清空日志", "LogClearButton", 20, 20', '"trash-2", "清空日志", "LogClearButton", 24, ICON_SIZE')
pattern = re.compile(r'        self\.status_bar\.setStyleSheet\(\n(?:.*\n){5}        \)\n')
path = ROOT / "views/log_panel.py"
text = path.read_text(encoding="utf-8")
text2, n = pattern.subn('', text, count=1)
if n != 1:
    raise RuntimeError("could not remove LogStatusBar inline style")
path.write_text(text2, encoding="utf-8")

# Settings: Inter first; no inline combo QSS; 40px formatter rows.
replace("views/settings_page.py", 'RECOMMENDED_FONT_CHOICES = (\n    "Microsoft YaHei UI",', 'RECOMMENDED_FONT_CHOICES = (\n    "Inter",\n    "Microsoft YaHei UI",')
path = ROOT / "views/settings_page.py"
text = path.read_text(encoding="utf-8")
text = re.sub(r'        chevron_path = .*?\n        self\.font_family_combo\.setStyleSheet\(\n(?:.*\n){5}        \)\n', '', text, count=1)
text = text.replace('        self.flag_table.verticalHeader().hide()\n', '        self.flag_table.verticalHeader().hide()\n        self.flag_table.verticalHeader().setDefaultSectionSize(40)\n')
path.write_text(text, encoding="utf-8")

# Secondary Settings/Docs shell.
replace("views/secondary_page.py", 'from plm.frontend.qt.widgets.common import make_icon_button\n', 'from plm.frontend.qt.widgets.common import make_icon_button\nfrom plm.frontend.qt.styles.tokens import SPACING_LG, SPACING_SM, SPACING_XL, TEXT_MAIN\n')
replace("views/secondary_page.py", 'header.setFixedHeight(56)', 'header.setFixedHeight(48)')
replace("views/secondary_page.py", 'header_layout.setContentsMargins(20, 0, 20, 0)\n        header_layout.setSpacing(12)', 'header_layout.setContentsMargins(SPACING_LG, 0, SPACING_LG, 0)\n        header_layout.setSpacing(SPACING_SM)')
replace("views/secondary_page.py", '"arrow-left", "返回", "PlaceholderBackButton", 32, 20, "#333333"', '"arrow-left", "返回", "PlaceholderBackButton", 32, 18, TEXT_MAIN')
replace("views/secondary_page.py", 'page_area_layout.setContentsMargins(32, 40, 32, 40)', 'page_area_layout.setContentsMargins(SPACING_XL, SPACING_XL, SPACING_XL, SPACING_XL)')

# New-project dialog inherits the global theme.
replace("views/new_project_dialog.py", 'from plm.frontend.qt.widgets.common import load_lucide_icon\n', 'from plm.frontend.qt.widgets.common import load_lucide_icon\nfrom plm.frontend.qt.styles.tokens import BG_SURFACE, SPACING_MD, SPACING_XL, TEXT_MAIN\n')
path = ROOT / "views/new_project_dialog.py"
text = path.read_text(encoding="utf-8")
text = re.sub(r'        self\.setStyleSheet\(""".*?        """\)\n', '', text, count=1, flags=re.S)
text = text.replace('form.setContentsMargins(20, 20, 20, 20)\n        form.setSpacing(12)', 'form.setContentsMargins(SPACING_XL, SPACING_XL, SPACING_XL, SPACING_XL)\n        form.setSpacing(SPACING_MD)')
text = text.replace('create_button.setObjectName("CreateProjectButton")', 'create_button.setObjectName("PrimaryBtn")')
text = text.replace('load_lucide_icon("rocket", "#FFFFFF", 20)', 'load_lucide_icon("rocket", BG_SURFACE, 18)')
text = text.replace('QtCore.QSize(20, 20)', 'QtCore.QSize(18, 18)')
text = text.replace('load_lucide_icon("x", "#333333", 20)', 'load_lucide_icon("x", TEXT_MAIN, 18)')
path.write_text(text, encoding="utf-8")

# Project item icons consume token colors.
replace("widgets/project_item.py", 'from plm.frontend.qt.widgets.common import (', 'from plm.frontend.qt.styles.tokens import DANGER, TEXT_SUB\nfrom plm.frontend.qt.widgets.common import (')
replace("widgets/project_item.py", '"folder", "#666666", align_visible_left=True', '"folder", TEXT_SUB, align_visible_left=True')
replace("widgets/project_item.py", 'load_lucide_icon("pin", "#666666", 16)', 'load_lucide_icon("pin", TEXT_SUB, 18)')
replace("widgets/project_item.py", 'load_lucide_icon("pencil", "#666666", 16)', 'load_lucide_icon("pencil", TEXT_SUB, 18)')
replace("widgets/project_item.py", 'load_lucide_icon("folder-open", "#666666", 16)', 'load_lucide_icon("folder-open", TEXT_SUB, 18)')
replace("widgets/project_item.py", 'load_lucide_icon("archive", "#666666", 16)', 'load_lucide_icon("archive", TEXT_SUB, 18)')
replace("widgets/project_item.py", 'load_lucide_icon("trash-2", "#CF222E", 16)', 'load_lucide_icon("trash-2", DANGER, 18)')

# Table row height and drag-handle color.
replace("widgets/tables.py", 'from plm.frontend.qt.widgets.theme import ACCENT, RoundedComboBox\n', 'from plm.frontend.qt.widgets.theme import ACCENT, RoundedComboBox\nfrom plm.frontend.qt.styles.tokens import TEXT_SUB\n')
replace("widgets/tables.py", '"vertical-grip", color="#758ca4", size=18', '"vertical-grip", color=TEXT_SUB, size=18')
replace("widgets/tables.py", '        row_header = self.table.verticalHeader()\n', '        row_header = self.table.verticalHeader()\n        row_header.setDefaultSectionSize(40)\n')

# Code preview follows the neutral/blue palette and mono token.
replace("widgets/code_preview.py", 'from PyQt5 import QtCore, QtGui, QtWidgets\n', 'from PyQt5 import QtCore, QtGui, QtWidgets\nfrom plm.frontend.qt.styles.tokens import (\n    BG_SUBTLE, FONT_MONO, PRIMARY, PRIMARY_HOVER, TEXT_MAIN, TEXT_MUTED, TEXT_SUB,\n)\n')
replace("widgets/code_preview.py", 'for name, color in (("comment", "#6A737D"), ("keyword", "#D73A49"),\n                            ("string", "#032F62"), ("number", "#005CC5"),\n                            ("directive", "#6F42C1")):', 'for name, color in (("comment", TEXT_MUTED), ("keyword", PRIMARY),\n                            ("string", TEXT_SUB), ("number", PRIMARY_HOVER),\n                            ("directive", TEXT_SUB)):')
replace("widgets/code_preview.py", 'font = QtGui.QFontDatabase.systemFont(QtGui.QFontDatabase.FixedFont)\n        font.setPointSize(10)', 'font = QtGui.QFont("JetBrains Mono")\n        font.setStyleHint(QtGui.QFont.Monospace)\n        font.setPointSize(10)')
replace("widgets/code_preview.py", 'painter.fillRect(event.rect(), QtGui.QColor("#F6F8FA"))', 'painter.fillRect(event.rect(), QtGui.QColor(BG_SUBTLE))')
replace("widgets/code_preview.py", 'painter.setPen(QtGui.QColor("#8C959F"))', 'painter.setPen(QtGui.QColor(TEXT_MUTED))')

# LaneGrid custom painting uses only the shared design tokens.
replace("widgets/lanegrid.py", 'from plm.frontend.qt.widgets.theme import BORDER, BORDER_STRONG, TEXT, add_shadow\n', 'from plm.frontend.qt.widgets.theme import BORDER, BORDER_STRONG, TEXT, add_shadow\nfrom plm.frontend.qt.styles.tokens import (\n    BG_MAIN, BG_SUBTLE, BG_SURFACE, DANGER, PRIMARY, SUCCESS, TEXT_MAIN, TEXT_MUTED, TEXT_SUB,\n)\n')
old_palette = '''LANE_GRID_PALETTE = [\n    "#4C78A8", "#F58518", "#54A24B", "#E45756", "#72B7B2",\n    "#EECA3B", "#B279A2", "#FF9DA6", "#9D755D", "#17BECF",\n    "#B5B02B", "#7B6FD1",\n]\nLANE_GRID_UNASSIGNED_BG = "#e6e6e6"'''
new_palette = '''LANE_GRID_PALETTE = [\n    PRIMARY, TEXT_SUB, SUCCESS, DANGER, TEXT_MUTED,\n    PRIMARY, TEXT_SUB, SUCCESS, DANGER, TEXT_MUTED,\n    PRIMARY, TEXT_SUB,\n]\nLANE_GRID_UNASSIGNED_BG = BG_SUBTLE'''
replace("widgets/lanegrid.py", old_palette, new_palette)
replace("widgets/lanegrid.py", 'return "#000000" if luminance > 140 else "#ffffff"', 'return TEXT_MAIN if luminance > 140 else BG_SURFACE')
replace("widgets/lanegrid.py", 'QtGui.QColor("#bb0000")', 'QtGui.QColor(DANGER)', required=False)
replace("widgets/lanegrid.py", 'fill="#f7f7f7" stroke="#202124"', 'fill="{BG_MAIN}" stroke="{TEXT_MAIN}"')
replace("widgets/lanegrid.py", 'fill="#c7c9cc" \'\n        \'stroke="#202124"', 'fill="{TEXT_MUTED}" \'\n        \'stroke="{TEXT_MAIN}"')
replace("widgets/lanegrid.py", 'fill="{color}" stroke="#202124"', 'fill="{color}" stroke="{TEXT_MAIN}"')
replace("widgets/lanegrid.py", 'stroke="#ffffff"', 'stroke="{BG_SURFACE}"')
# Make the SVG fragments above interpolate token constants as well as the active lane color.
replace("widgets/lanegrid.py", '        \'fill="{BG_MAIN}" stroke="{TEXT_MAIN}" stroke-width="1.5" stroke-linejoin="round"/>\'', '        f\'fill="{BG_MAIN}" stroke="{TEXT_MAIN}" stroke-width="1.5" stroke-linejoin="round"/>\'')
replace("widgets/lanegrid.py", '        \'stroke="{TEXT_MAIN}" stroke-width="1.3" stroke-linejoin="round"/>\'', '        f\'stroke="{TEXT_MAIN}" stroke-width="1.3" stroke-linejoin="round"/>\'')
replace("widgets/lanegrid.py", '        \'stroke-opacity=".8" stroke-width="1.2" stroke-linecap="round"/>\'', '        f\'stroke-opacity=".8" stroke-width="1.2" stroke-linecap="round"/>\'')

# Sanity check: forbidden legacy design colors must not remain in Qt Python/QSS.
forbidden = ("#F1F1F5", "#1677FF", "#8C92A4", "#E6F0FF", "#333333", "#666666")
violations = []
for path in ROOT.rglob("*"):
    if path.suffix not in {".py", ".qss"}:
        continue
    if path.name == "tokens.py":
        continue
    text = path.read_text(encoding="utf-8")
    for color in forbidden:
        if color.lower() in text.lower():
            violations.append(f"{path.relative_to(ROOT)}: {color}")
if violations:
    raise RuntimeError("legacy colors remain:\n" + "\n".join(violations))

print("BeautifulUI r1 visual redesign applied")
