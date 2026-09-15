"""
plm_qt_theme -- QSS theme for the Qt desktop front end, on SAP's Horizon
design tokens.

The values below are transcribed from theming-base-content's
`content/Base/baseLib/sap_horizon/variables.json` (Apache-2.0), with the
upstream token name kept in a comment so any of them can be checked
against the source. Only the tokens this app actually renders are here.

Note what this is *not*: SAP's own component library (fundamental-styles)
is HTML + CSS, and Qt style sheets are a small subset of CSS with Qt class
selectors, no flexbox/grid, no custom properties and no ::before/::after.
None of that CSS can be used directly, so the component rules further down
re-express Horizon's geometry in the vocabulary QSS actually has.
"""

import sys

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.widgets import sap_icons

BG = "#ffffff"  # sapBaseColor / sapList_Background
BG_ELEVATED = "#ffffff"  # sapGroup_ContentBackground
BG_SIDEBAR = "#f5f6f7"  # sapBackgroundColor
BG_HOVER = "#eaecee"  # sapList_Hover_Background
BG_ACTIVE = "#ebf8ff"  # sapList_SelectionBackgroundColor
BORDER = "#e5e5e5"  # sapList_BorderColor
BORDER_STRONG = "#d9d9d9"  # sapGroup_ContentBorderColor
TEXT = "#131e29"  # sapTextColor
TEXT_SECONDARY = "#556b82"  # sapContent_LabelColor
TEXT_TERTIARY = "#758ca4"  # sapContent_NonInteractiveIconColor
ACCENT = "#0070f2"  # sapBrandColor / sapButton_Emphasized_Background
ACCENT_HOVER = "#0064d9"  # sapHighlightColor
DANGER = "#aa0808"  # sapNegativeColor
POSITIVE = "#256f3a"  # sapPositiveColor
CRITICAL = "#e76500"  # sapCriticalColor
FIELD_BORDER = "#556b81"  # sapField_BorderColor
FIELD_FOCUS_BORDER = "#0032a5"  # sapField_Focus_BorderColor
BUTTON_BORDER = "#bcc3ca"  # sapButton_BorderColor
BUTTON_TEXT = "#0064d9"  # sapButton_TextColor
SCROLLBAR = "#7b91a8"  # sapScrollBar_FaceColor

# Horizon's corner radii, converted from rem at the 16 px root the tokens
# assume: sapField_BorderCornerRadius .25rem, sapButton_ .5rem,
# sapElement_ .75rem.
RADIUS_FIELD = 4
RADIUS_SM = 8
RADIUS_MD = 12
RADIUS_PILL = 14  # QSS has no CSS-style "999px + overflow" pill trick -- a
# radius about half the tab/pill's own height reads as fully rounded ends.


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
            BG_SIDEBAR
            if isinstance(window, QtWidgets.QMainWindow)
            else BG_ELEVATED
        )
        caption = ctypes.c_int(_colorref(caption_color))
        text = ctypes.c_int(_colorref(TEXT))
        dwmapi.DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, ctypes.byref(caption), ctypes.sizeof(caption))
        dwmapi.DwmSetWindowAttribute(hwnd, DWMWA_TEXT_COLOR, ctypes.byref(text), ctypes.sizeof(text))
    except (OSError, AttributeError, ValueError):
        pass


class RoundedComboBox(QtWidgets.QComboBox):
    """Combo box with a QSS-safe chevron and four visible rounded corners."""

    def paintEvent(self, event):
        super().paintEvent(event)
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        color = TEXT_TERTIARY if not self.isEnabled() else TEXT_SECONDARY
        pen = QtGui.QPen(QtGui.QColor(color), 1.5)
        pen.setCapStyle(QtCore.Qt.RoundCap)
        pen.setJoinStyle(QtCore.Qt.RoundJoin)
        painter.setPen(pen)
        center_x = self.width() - 14
        center_y = self.height() // 2
        painter.drawLine(center_x - 4, center_y - 2, center_x, center_y + 2)
        painter.drawLine(center_x, center_y + 2, center_x + 4, center_y - 2)
        painter.end()


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
            painter.drawLine(QtCore.QPointF(7, mid_y + 3), QtCore.QPointF(13, mid_y - 4))
        if self.text():
            painter.setPen(self.palette().color(QtGui.QPalette.WindowText))
            painter.drawText(
                QtCore.QRect(24, 0, max(0, self.width() - 24), self.height()),
                QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter,
                self.text(),
            )
        painter.end()

BASE_FONT_PX = 13  # every font-size below is authored against this baseline


def ui_font_stack():
    """The app font stack, led by "72" when its vendored file registered.

    Falls back to the platform UI faces if the font is missing, so a
    stripped-down install still renders sensibly instead of landing on
    whatever Qt picks by default."""
    families = []
    sap_family = sap_icons.text_font_family()
    if sap_family:
        families.append(f'"{sap_family}"')
    families += [
        '"Segoe UI"',
        '"Microsoft YaHei UI"',
        '"Microsoft YaHei"',
        '"Helvetica Neue"',
        "Arial",
        "sans-serif",
    ]
    return ", ".join(families)


def build_stylesheet(base_px=BASE_FONT_PX):
    """Build the app-wide QSS with every font-size scaled from base_px.

    A stylesheet font-size beats QApplication.setFont(), so setting the app
    font alone can never resize any text the sheet mentions -- and the sheet
    mentions QWidget, so that's everything. Changing the size in Settings
    therefore has to rebuild and re-apply this (see MainWindow._apply_font),
    not just set the app font."""

    def fs(px):
        # At the baseline the authored value is emitted verbatim, so the
        # default look is bit-for-bit what it was before this was scalable
        # (12.5px in particular must not get rounded away).
        scaled = px if base_px == BASE_FONT_PX else max(9, round(px * base_px / BASE_FONT_PX))
        return f"{scaled:g}px"

    return f"""
QWidget {{
    background: {BG};
    color: {TEXT};
    font-size: {fs(13)};
    /* "72" is SAP's own UI typeface (sapFontFamily). It covers Latin only,
       so the CJK faces stay behind it for the Chinese sidebar labels. */
    font-family: {ui_font_stack()};
}}
QLabel {{
    background: transparent;
}}

/* -- sidebar ------------------------------------------------------- */
QWidget#sidebar,
QWidget#sidebar QWidget {{
    background: {BG_SIDEBAR};
}}
QWidget#sidebar {{
    border-right: 2px solid {BORDER_STRONG};
}}
QToolButton#edgeToggle {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: 8px;
    color: {TEXT_SECONDARY};
    font-size: {fs(13)};
}}
QToolButton#edgeToggle:hover {{
    background: {BG_HOVER};
    border-color: {BORDER_STRONG};
    color: {TEXT};
}}
QLabel#brandName {{
    font-weight: 600;
    font-size: {fs(14)};
}}
QPushButton#sidebarBtn {{
    text-align: left;
    padding: 9px 10px;
    border: 1px solid transparent;
    border-radius: {RADIUS_SM}px;
    background: transparent;
    color: {TEXT};
}}
QPushButton#sidebarBtn:hover {{
    background: {BG_HOVER};
    border-color: {BORDER};
}}
QPushButton#sidebarBtn[collapsed="true"] {{
    text-align: left;
    padding: 9px 10px;
}}
QLabel#sectionHeader {{
    color: {TEXT_TERTIARY};
    font-size: {fs(11)};
    font-weight: 600;
}}
QListWidget#recentList {{
    background: {BG_SIDEBAR};
    border: none;
    outline: none;
}}
QListWidget#recentList::item {{
    padding: 9px 12px;
    border-radius: {RADIUS_SM}px;
    margin: 1px 0;
}}
QListWidget#recentList::item:hover {{
    background: {BG_HOVER};
}}
QListWidget#recentList::item:selected {{
    background: {BG_ACTIVE};
    color: {TEXT};
}}
/* setItemWidget() inserts a child QWidget over each QListWidget item.
   Keep that child transparent so the item's normal/hover/selected fill
   remains one continuous colour behind the label and menu button. */
QListWidget#recentList QWidget {{
    background: transparent;
}}
QToolButton#recentMenuBtn {{
    border: none;
    background: transparent;
    color: {TEXT_TERTIARY};
    font-size: {fs(16)};
    font-weight: 700;
    padding: 0px 4px;
    min-width: 20px;
    max-width: 20px;
    min-height: 20px;
    max-height: 20px;
    border-radius: {RADIUS_SM - 2}px;
}}
QToolButton#recentMenuBtn:hover {{
    background: {BG_ACTIVE};
    color: {TEXT};
}}
QListWidget#recentList[collapsed="true"]::item {{
    padding-left: 0;
    padding-right: 0;
}}

/* -- pill tab switcher --------------------------------------------------- */
QTabWidget::pane {{
    border: none;
    top: 0;
}}
QTabWidget#tabs::pane {{
    border-top: 2px solid {BORDER_STRONG};
}}
QTabWidget#settingsTabs::pane {{
    top: 6px;
}}
QTabBar {{
    background: transparent;
}}
/* Fiori's icon tab bar marks the active tab with a brand-coloured rule
   under it, not with a filled chip. The transparent border on the resting
   state reserves the same 3px so selecting a tab doesn't shift the text. */
QTabBar::tab {{
    background: transparent;
    color: {TEXT_SECONDARY};
    padding: 8px 16px;
    margin: 0 2px;
    border: none;
    border-bottom: 3px solid transparent;
    border-radius: 0;
    font-size: {fs(13)};
    font-weight: 400;
}}
QTabWidget#tabs QTabBar::tab {{
    margin: 4px 2px 0 2px;
}}
QTabBar::tab:hover {{
    background: {BG_HOVER};
    color: {TEXT};
}}
QTabBar::tab:selected {{
    background: transparent;
    color: {ACCENT_HOVER};
    border-bottom: 3px solid {ACCENT};
    font-weight: 700;
}}

/* -- cards ------------------------------------------------------------- */
QFrame#editorShell {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-top: none;
    border-top-left-radius: 0;
    border-top-right-radius: 0;
    border-bottom-left-radius: {RADIUS_MD}px;
    border-bottom-right-radius: {RADIUS_MD}px;
}}
QFrame#editorShell QTabWidget,
QFrame#editorShell QTabWidget::pane {{
    background: transparent;
}}
QFrame#card {{
    background: transparent;
    border: none;
    border-radius: 0;
}}
QLabel#hint {{
    color: {TEXT_SECONDARY};
    font-size: {fs(13)};
}}

/* -- buttons ------------------------------------------------------------ */
/* Horizon's default button is quiet -- white, a light grey outline, and
   the label itself in brand blue to carry the affordance. Emphasized
   (primaryBtn here) is the filled one, and a screen is meant to have at
   most one. */
QPushButton {{
    border: 1px solid {BUTTON_BORDER};
    background: {BG};
    color: {BUTTON_TEXT};
    padding: 7px 14px;
    border-radius: {RADIUS_SM}px;
}}
QPushButton:hover {{
    background: {BG_HOVER};
    border-color: {BUTTON_BORDER};
}}
QPushButton:pressed {{
    background: {ACCENT};
    border-color: {ACCENT};
    color: white;
}}
QPushButton:disabled {{
    color: {TEXT_TERTIARY};
    border-color: {BORDER};
    background: {BG};
}}
QPushButton#primaryBtn {{
    background: {ACCENT};
    color: white;
    border-color: {ACCENT};
    font-weight: 700;
}}
QPushButton#primaryBtn:hover {{
    background: {ACCENT_HOVER};
    border-color: {ACCENT_HOVER};
}}
QPushButton#primaryBtn:disabled {{
    background: {BORDER};
    border-color: {BORDER};
    color: {TEXT_TERTIARY};
}}
QToolButton {{
    border: 1px solid {BORDER};
    border-radius: 6px;
    background: {BG};
    padding: 2px;
}}
QToolButton:hover {{
    background: {BG_HOVER};
    border-color: {BORDER_STRONG};
}}

/* -- inputs -------------------------------------------------------------- */
/* Fields are the one place Horizon keeps a dark outline
   (sapField_BorderColor) and a tight 4px radius, which is what separates
   an editable field from a button at a glance. */
QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox {{
    border: 1px solid {FIELD_BORDER};
    background: {BG};
    color: {TEXT};
    padding: 5px 8px;
    border-radius: {RADIUS_FIELD}px;
}}
QComboBox {{
    padding-right: 30px;
}}
QComboBox::drop-down {{
    subcontrol-origin: border;
    subcontrol-position: top right;
    width: 28px;
    background: transparent;
    border: none;
    border-top-right-radius: {RADIUS_FIELD - 1}px;
    border-bottom-right-radius: {RADIUS_FIELD - 1}px;
}}
QLineEdit:hover, QComboBox:hover, QSpinBox:hover, QDoubleSpinBox:hover {{
    border-color: {ACCENT_HOVER};
}}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus {{
    border: 2px solid {FIELD_FOCUS_BORDER};
}}
QComboBox[validationError="true"] {{
    border: 2px solid {DANGER};
    background: #fff0f0;
}}
QLineEdit:disabled, QComboBox:disabled, QSpinBox:disabled, QDoubleSpinBox:disabled {{
    border-color: {BORDER};
    color: {TEXT_TERTIARY};
}}
QComboBox QAbstractItemView {{
    background: {BG};
    color: {TEXT};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_FIELD}px;
    outline: none;
    padding: 4px;
    selection-background-color: {BG_ACTIVE};
    selection-color: {TEXT};
}}
QComboBox QAbstractItemView::item {{
    padding: 6px 8px;
    border-radius: 2px;
}}
QCheckBox {{
    spacing: 8px;
    background: transparent;
}}

/* -- tables -------------------------------------------------------------- */
QTableWidget {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    gridline-color: {BORDER};
}}
QTableWidget::item {{
    padding-left: 10px;
    padding-right: 10px;
}}
/* Fiori column headers are sentence-case labels over a strong rule, not
   small-caps -- and the rule is what separates header from body, so it is
   darker than the row separators. */
QHeaderView::section {{
    background: {BG_ELEVATED};
    color: {TEXT_SECONDARY};
    padding: 8px;
    border: none;
    border-bottom: 2px solid {BORDER_STRONG};
    font-size: {fs(12)};
    font-weight: 700;
}}
QTableWidget::item:selected {{
    background: {BG_ACTIVE};
    color: {TEXT};
}}

/* -- LaneGrid palette bar (pill swatches) ------------------------------- */
QWidget#lgPaletteBar {{
    background: transparent;
}}
QPushButton#lgSwatch {{
    font-size: {fs(12.5)};
    font-weight: 600;
    border-radius: {RADIUS_PILL}px;
    padding: 5px 15px;
    min-width: 0;
}}
QPushButton#lgSwatch:hover {{
    border-color: {BORDER_STRONG};
}}

/* -- LaneGrid table (lane mapping grid) --------------------------------- */
QTableWidget#laneGrid {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    gridline-color: {BORDER};
    /* Disable default item selection highlight -- the delegate paints cells */
    selection-background-color: transparent;
    selection-color: {TEXT};
}}
QTableWidget#laneGrid QHeaderView::section {{
    padding: 5px 1px;
    font-size: {fs(9)};
}}

/* -- log panel ------------------------------------------------------------ */
QFrame#logCard {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
}}
QWidget#logHeader {{ background: transparent; }}
QToolButton#bottomPanelTab {{
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    background: transparent;
    color: {TEXT_SECONDARY};
    font-size: {fs(12)};
    font-weight: 600;
    padding: 0 6px;
}}
QToolButton#bottomPanelTab:hover {{
    color: {TEXT};
}}
QToolButton#bottomPanelTab:checked {{
    color: {TEXT};
    border-bottom-color: {ACCENT};
}}
QToolButton#logHeaderBtn, QToolButton#logToggle {{
    min-width: 26px;
    max-width: 26px;
    min-height: 26px;
    max-height: 26px;
    border: none;
    border-radius: 7px;
    background: transparent;
    color: {TEXT_TERTIARY};
    padding: 0;
}}
QToolButton#logHeaderBtn:hover, QToolButton#logToggle:hover {{
    background: {BG_HOVER};
    color: {TEXT};
}}
QPlainTextEdit#logConsole {{
    border: none;
    background: transparent;
    color: {TEXT_SECONDARY};
    font-family: Consolas, "SF Mono", Menlo, monospace;
    font-size: {fs(12)};
}}
QWidget#bottomPanelStack {{
    background: transparent;
}}
QTreeWidget#problemTree {{
    border: none;
    background: transparent;
    color: {TEXT};
    outline: none;
}}
QTreeWidget#problemTree::item {{
    min-height: 25px;
    padding: 2px 4px;
}}
QTreeWidget#problemTree::item:hover {{
    background: {BG_HOVER};
}}
QTreeWidget#problemTree::item:selected {{
    background: {BG_ACTIVE};
    color: {TEXT};
}}
QTreeWidget#problemTree QHeaderView::section {{
    background: {BG};
    color: {TEXT_SECONDARY};
    border: none;
    border-bottom: 1px solid {BORDER};
    padding: 5px 4px;
    font-weight: 600;
}}

/* -- generated RTL preview ---------------------------------------------- */
QSplitter#contentSplitter::handle {{ background: {BORDER_STRONG}; }}
QFrame#rtlPreviewPanel {{
    background: {BG};
    border-left: 1px solid {BORDER_STRONG};
}}
QLabel#previewStatus {{ color: {TEXT_TERTIARY}; }}
QLineEdit#previewSearchEdit {{
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 4px 8px;
    background: {BG};
}}
QLineEdit#previewSearchEdit:focus {{ border-color: {ACCENT}; }}
QLabel#previewSearchStatus {{
    color: {TEXT_TERTIARY};
    font-size: {fs(12)};
    padding: 0 4px;
}}
QToolButton#previewSearchBtn {{
    border: none;
    background: transparent;
    color: {TEXT_SECONDARY};
    border-radius: 6px;
    min-width: 22px;
    min-height: 22px;
}}
QToolButton#previewSearchBtn:hover {{ background: {BG_HOVER}; color: {TEXT}; }}
QPlainTextEdit#topologySummary {{
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    background: {BG_ELEVATED};
    color: {TEXT};
    padding: 8px;
    font-family: Consolas, "SF Mono", Menlo, monospace;
    font-size: {fs(12)};
}}
QWidget#previewHeader {{ background: transparent; }}
QToolButton#previewRootBtn {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 0;
    color: {TEXT};
}}
QToolButton#previewRootBtn:hover {{
    background: {BG_HOVER};
    border-color: {BORDER_STRONG};
}}
QToolButton#previewRootBtn:checked {{
    background: {BG_ACTIVE};
    border-color: {BORDER_STRONG};
}}
QTreeWidget#previewFileTree {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 4px;
    outline: none;
}}
QTreeWidget#previewFileTree::item {{
    min-height: 24px;
    padding: 2px 4px;
    border-radius: 5px;
}}
QTreeWidget#previewFileTree::item:hover {{
    background: {BG_HOVER};
}}
QTreeWidget#previewFileTree::item:selected {{
    background: {BG_ACTIVE};
    color: {TEXT};
}}
QPlainTextEdit#rtlPreviewCode {{
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    background: {BG_ELEVATED};
    color: {TEXT};
    padding: 10px;
    font-family: Consolas, "SF Mono", Menlo, monospace;
    font-size: {fs(12)};
}}
QWidget#previewControls {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-radius: 10px;
}}
/* Size is set in Python from the live tab-bar height (see
   MainWindow._position_preview_controls) so these track the app font. */
QToolButton#previewControlBtn {{
    border: none;
    border-radius: 8px;
    background: transparent;
}}
QToolButton#previewControlBtn:hover {{ background: {BG_HOVER}; }}
QToolButton#previewControlBtn:checked {{ background: {BG_ACTIVE}; }}

/* -- modals / settings --------------------------------------------------- */
QDialog {{
    background: {BG};
}}
/* -- desktop polish ----------------------------------------------------- */
QTableWidget {{
    alternate-background-color: {BG_ELEVATED};
    selection-background-color: {BG_ACTIVE};
    selection-color: {TEXT};
}}
QPushButton:disabled, QToolButton:disabled, QComboBox:disabled {{
    color: {TEXT_TERTIARY};
    background: {BG_ELEVATED};
    border-color: {BORDER};
}}
QMenu {{
    background: {BG};
    border: 1px solid {BORDER};
    padding: 5px;
}}
QMenu::item {{ padding: 7px 24px 7px 10px; border-radius: 6px; }}
QMenu::item:selected {{ background: {BG_HOVER}; }}
QPushButton#destructiveMenuItem {{
    border: none;
    border-radius: 6px;
    background: transparent;
    color: {DANGER};
    text-align: left;
    padding: 7px 24px 7px 10px;
    font-weight: 600;
}}
QPushButton#destructiveMenuItem:hover {{
    background: {BG_HOVER};
    color: {DANGER};
}}
QScrollBar:vertical {{ background: transparent; width: 14px; margin: 2px; }}
QScrollBar::handle:vertical {{
    background: {SCROLLBAR};
    border-radius: 4px;
    min-height: 28px;
}}
QScrollBar::handle:vertical:hover {{ background: {TEXT_SECONDARY}; }}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
    background: transparent;
    border: none;
    height: 0;
}}
QScrollBar:horizontal {{ background: transparent; height: 14px; margin: 2px; }}
QScrollBar::handle:horizontal {{
    background: {SCROLLBAR};
    border-radius: 4px;
    min-width: 28px;
}}
QScrollBar::handle:horizontal:hover {{ background: {TEXT_SECONDARY}; }}
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal,
QScrollBar::add-page:horizontal, QScrollBar::sub-page:horizontal {{
    background: transparent;
    border: none;
    width: 0;
}}
QToolTip {{
    background: {TEXT};
    color: white;
    border: none;
    padding: 5px 7px;
}}
"""


# The sheet at the default size, for callers that apply it once at startup
# before any saved font preference is known (plm.frontend.qt.main).
STYLESHEET = build_stylesheet()
