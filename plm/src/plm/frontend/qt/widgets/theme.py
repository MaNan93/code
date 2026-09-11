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

STYLESHEET = f"""
QWidget {{
    background: {BG};
    color: {TEXT};
    font-size: 13px;
}}

/* -- sidebar ------------------------------------------------------- */
QWidget#sidebar {{
    background: {BG_SIDEBAR};
    border-right: 1px solid {BORDER};
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
    padding: 9px 12px;
    border: 1px solid transparent;
    border-radius: {RADIUS_SM}px;
    background: transparent;
    color: {TEXT};
}}
QPushButton#sidebarBtn:hover {{
    background: {BG_HOVER};
    border-color: {BORDER};
}}
QLabel#sectionHeader {{
    color: {TEXT_TERTIARY};
    font-size: 11px;
    font-weight: 600;
}}
QListWidget#recentList {{
    background: transparent;
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

/* -- topbar ---------------------------------------------------------- */
QWidget#topbar {{
    background: {BG_ELEVATED};
    border-bottom: 1px solid {BORDER};
}}
QLabel#workspaceTitle {{
    font-weight: 600;
    font-size: 14.5px;
}}

/* -- pill tabs --------------------------------------------------------- */
QTabWidget::pane {{
    border: none;
    top: -1px;
}}
QTabBar {{
    background: transparent;
}}
QTabBar::tab {{
    background: transparent;
    color: {TEXT_SECONDARY};
    padding: 7px 16px;
    margin-right: 4px;
    border: 1px solid transparent;
    border-radius: {RADIUS_PILL}px;
    font-size: 13px;
    font-weight: 500;
}}
QTabBar::tab:hover {{
    background: {BG_HOVER};
    color: {TEXT};
}}
QTabBar::tab:selected {{
    background: {BG_ACTIVE};
    color: {TEXT};
}}

/* -- cards ------------------------------------------------------------- */
QFrame#card {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
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
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus {{
    border-color: {ACCENT};
}}
QCheckBox {{
    spacing: 8px;
}}

/* -- tables -------------------------------------------------------------- */
QTableWidget {{
    background: {BG};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    gridline-color: {BORDER};
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

/* -- log panel ------------------------------------------------------------ */
QFrame#logCard {{
    background: {BG_ELEVATED};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
}}
QToolButton#logToggle {{
    border: none;
    background: transparent;
    color: {TEXT_TERTIARY};
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    padding: 8px 12px;
}}
QPlainTextEdit#logConsole {{
    border: none;
    border-top: 1px solid {BORDER};
    background: transparent;
    color: {TEXT_SECONDARY};
    font-family: Consolas, "SF Mono", Menlo, monospace;
    font-size: 12px;
}}

/* -- modals / settings --------------------------------------------------- */
QDialog {{
    background: {BG};
}}
"""
