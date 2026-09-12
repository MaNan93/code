"""
plm_qt_theme -- QSS port of the web front end's light "ChatGPT-inspired"
theme (tool/web/style.css's `:root` block; the dark `[data-theme="dark"]`
variant is never actually toggled on there either -- `<body
data-theme="light">` is hardcoded -- so light is the one theme worth
porting here for parity).

Values below are copy-pasted from style.css's :root, not re-derived, so
this stays a faithful port rather than a fresh design -- see that file if
the web theme's colors/radii ever change and this should follow.
"""

from PyQt5 import QtCore, QtGui, QtWidgets

BG = "#ffffff"
BG_ELEVATED = "#f7f7f8"
BG_SIDEBAR = "#f9f9f9"
BG_HOVER = "#ececec"
BG_ACTIVE = "#e3e3e3"
BORDER = "#e5e5e5"
BORDER_STRONG = "#d4d4d4"
TEXT = "#0d0d0d"
TEXT_SECONDARY = "#5d5d5d"
TEXT_TERTIARY = "#8e8e8e"
ACCENT = "#10a37f"
ACCENT_HOVER = "#0e906f"
DANGER = "#ef4146"

RADIUS_SM = 8
RADIUS_MD = 12
RADIUS_PILL = 14  # QSS has no CSS-style "999px + overflow" pill trick -- a
# radius about half the tab/pill's own height reads as fully rounded ends.


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

STYLESHEET = f"""
QWidget {{
    background: {BG};
    color: {TEXT};
    font-size: 13px;
}}
QLabel {{
    background: transparent;
}}

/* -- sidebar ------------------------------------------------------- */
QWidget#sidebar,
QWidget#sidebar QWidget {{
    background: #F0F3F9;
}}
QWidget#sidebar {{
    border-right: 2px solid {BORDER_STRONG};
}}
QToolButton#edgeToggle {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: 8px;
    color: {TEXT_SECONDARY};
    font-size: 13px;
}}
QToolButton#edgeToggle:hover {{
    background: {BG_HOVER};
    border-color: {BORDER_STRONG};
    color: {TEXT};
}}
QLabel#brandName {{
    font-weight: 600;
    font-size: 14px;
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
    font-size: 11px;
    font-weight: 600;
}}
QListWidget#recentList {{
    background: #F0F3F9;
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
QListWidget#recentList[collapsed="true"]::item {{
    padding-left: 0;
    padding-right: 0;
}}

/* -- pill tabs --------------------------------------------------------- */
QTabWidget::pane {{
    border: none;
    top: -1px;
}}
QTabWidget#settingsTabs::pane {{
    top: 6px;
}}
QTabBar {{
    background: transparent;
}}
QTabBar::tab {{
    background: transparent;
    color: {TEXT_SECONDARY};
    padding: 9px 16px;
    margin-right: 6px;
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    font-size: 13px;
    font-weight: 500;
}}
QTabBar::tab:hover {{
    background: {BG_HOVER};
    color: {TEXT};
}}
QTabBar::tab:selected {{
    background: transparent;
    color: {TEXT};
    border-bottom: 2px solid {ACCENT};
    font-weight: 600;
}}

/* -- cards ------------------------------------------------------------- */
QFrame#editorShell {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-top-left-radius: {RADIUS_MD}px;
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
    font-size: 13px;
}}

/* -- buttons ------------------------------------------------------------ */
QPushButton {{
    border: 1px solid {BORDER};
    background: {BG};
    color: {TEXT};
    padding: 7px 14px;
    border-radius: {RADIUS_SM}px;
}}
QPushButton:hover {{
    background: {BG_HOVER};
    border-color: {BORDER_STRONG};
}}
QPushButton#primaryBtn {{
    background: {ACCENT};
    color: white;
    border-color: {ACCENT};
    font-weight: 600;
}}
QPushButton#primaryBtn:hover {{
    background: {ACCENT_HOVER};
    border-color: {ACCENT_HOVER};
}}
QPushButton#dangerAction {{
    color: {DANGER};
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
QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox {{
    border: 1px solid {BORDER};
    background: {BG};
    color: {TEXT};
    padding: 5px 8px;
    border-radius: {RADIUS_SM}px;
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
    border-top-right-radius: {RADIUS_SM - 1}px;
    border-bottom-right-radius: {RADIUS_SM - 1}px;
}}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus {{
    border-color: {ACCENT};
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
QHeaderView::section {{
    background: {BG_ELEVATED};
    color: {TEXT_SECONDARY};
    padding: 6px 8px;
    border: none;
    border-bottom: 1px solid {BORDER};
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
}}

/* -- LaneGrid palette bar (pill swatches) ------------------------------- */
QWidget#lgPaletteBar {{
    background: transparent;
}}
QPushButton#lgSwatch {{
    font-size: 12.5px;
    font-weight: 600;
    border-radius: 14px;
    padding: 5px 13px;
    min-width: 0;
}}
QPushButton#lgSwatch:hover {{
    border-color: {BORDER_STRONG};
}}

/* -- LaneGrid +/- row action buttons ----------------------------------- */
QToolButton#lgPlusBtn, QToolButton#lgMinusBtn {{
    border: 1px solid {BORDER};
    border-radius: 6px;
    background: {BG};
    color: {TEXT_SECONDARY};
    padding: 2px;
    min-width: 24px;
    min-height: 24px;
    max-width: 24px;
    max-height: 24px;
    font-size: 15px;
}}
QToolButton#lgPlusBtn:hover {{
    color: {ACCENT};
    border-color: {ACCENT};
    background: {BG_HOVER};
}}
QToolButton#lgMinusBtn:hover {{
    color: {DANGER};
    border-color: {DANGER};
    background: {BG_HOVER};
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
    font-size: 9px;
}}

/* -- log panel ------------------------------------------------------------ */
QFrame#logCard {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
}}
QWidget#logHeader {{ background: transparent; }}
QLabel#logTitle {{
    color: {TEXT};
    font-size: 13px;
    font-weight: 600;
    padding: 0;
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
    font-size: 12px;
}}

/* -- generated RTL preview ---------------------------------------------- */
QSplitter#contentSplitter::handle {{ background: {BORDER_STRONG}; }}
QFrame#rtlPreviewPanel {{
    background: {BG};
    border-left: 1px solid {BORDER_STRONG};
}}
QLabel#rtlPreviewTitle {{
    font-size: 13px;
    font-weight: 600;
}}
QLabel#previewStatus {{ color: {TEXT_TERTIARY}; }}
QPlainTextEdit#rtlPreviewCode {{
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    background: #fbfbfb;
    color: #24292f;
    padding: 10px;
    font-family: Consolas, "SF Mono", Menlo, monospace;
    font-size: 12px;
}}
QToolButton#previewHeaderBtn {{
    min-width: 28px;
    max-width: 28px;
    min-height: 28px;
    max-height: 28px;
    border: none;
    border-radius: 7px;
    background: transparent;
    color: {TEXT_SECONDARY};
    font-size: 18px;
}}
QToolButton#previewHeaderBtn:hover {{ background: {BG_HOVER}; }}
QWidget#previewControls {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-radius: 10px;
}}
QToolButton#previewControlBtn {{
    min-width: 30px;
    max-width: 30px;
    min-height: 30px;
    max-height: 30px;
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
    alternate-background-color: #fbfbfb;
    selection-background-color: #dff4ee;
    selection-color: {TEXT};
}}
QToolButton#rowPlusBtn, QToolButton#rowMinusBtn {{
    border: 1px solid {BORDER};
    border-radius: 6px;
    background: {BG};
    color: {TEXT_SECONDARY};
    min-width: 24px;
    min-height: 24px;
    max-width: 24px;
    max-height: 24px;
    font-size: 15px;
}}
QToolButton#rowPlusBtn:hover {{ color: {ACCENT}; border-color: {ACCENT}; }}
QToolButton#rowMinusBtn:hover {{ color: {DANGER}; border-color: {DANGER}; }}
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
QScrollBar:vertical {{ background: transparent; width: 10px; margin: 2px; }}
QScrollBar::handle:vertical {{
    background: #c9c9c9;
    border-radius: 4px;
    min-height: 28px;
}}
QScrollBar::handle:vertical:hover {{ background: #aaaaaa; }}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
    background: transparent;
    border: none;
    height: 0;
}}
QToolTip {{
    background: {TEXT};
    color: white;
    border: none;
    padding: 5px 7px;
}}
"""
