"""QSS theme for the plmConsultant desktop interface."""

import sys
from pathlib import Path

from PyQt5 import QtGui, QtWidgets

from plm.frontend.qt.widgets import sap_icons


BG = "#F0F0F0"
BG_ELEVATED = "#FFFFFF"
BG_SIDEBAR = "#F1F1F5"
BG_HOVER = "#E2E2EC"
BG_ACTIVE = "#E6F0FF"
BORDER = "#E0E0E0"
BORDER_STRONG = "#D0D0D0"
TEXT = "#333333"
TEXT_SECONDARY = "#555555"
TEXT_TERTIARY = "#8C92A4"
ACCENT = "#1677FF"
ACCENT_HOVER = "#4096FF"
DANGER = "#CF222E"
POSITIVE = "#1A7F37"
CRITICAL = "#D97706"


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


class VisibleCheckBox(QtWidgets.QCheckBox):
    pass


def build_stylesheet(base_px=13):
    font_family = None
    font_candidates = (
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
    )
    if QtGui.QGuiApplication.instance() is not None:
        for path in font_candidates:
            if not path.is_file():
                continue
            font_id = QtGui.QFontDatabase.addApplicationFont(str(path))
            families = (
                QtGui.QFontDatabase.applicationFontFamilies(font_id)
                if font_id >= 0
                else []
            )
            if families:
                font_family = families[-1]
                break
    font_family = font_family or sap_icons.text_font_family() or "Arial"
    small_px = max(10, base_px - 1)
    return f"""
QWidget {{
    color: {TEXT};
    background: #FFFFFF;
    font-family: "{font_family}";
    font-size: {base_px}px;
}}
QMainWindow {{ background: {BG}; }}
QLabel {{ background: transparent; }}
QSplitter::handle:horizontal {{
    background-color: transparent;
    width: 1px;
}}
QSplitter::handle:horizontal:hover {{
    background-color: transparent;
}}
QFrame#CustomTitleBar {{
    background-color: #F1F1F5;
    border-bottom: 1px solid #E0E0E0;
}}
QLabel#TitleBarTitle {{
    color: #1A1A1A;
    font-size: 13px;
    font-weight: 600;
}}
QPushButton#TitleBarBtn {{
    background-color: transparent;
    color: #333333;
    border: none;
    border-radius: 0;
    padding: 0;
}}
QPushButton#TitleBarBtn:hover {{
    background-color: #E2E2EC;
}}
QPushButton#TitleBarBtn[role="close"]:hover {{
    background-color: #E81123;
    color: #FFFFFF;
}}

QFrame#NavPanel,
QFrame#NavPanel QWidget {{ background: {BG_SIDEBAR}; }}
QFrame#NavPanel {{ border-right: 1px solid {BORDER}; }}
QFrame#NavDivider,
QFrame#NavPanel QFrame#NavDivider {{
    background-color: #E0E0E0;
    border: none;
}}
QLabel#Logo {{ color: #1A1A1A; font-size: {base_px + 4}px; font-weight: 700; }}
QPushButton#CollapseBtn {{
    border: none; border-radius: 5px; background: transparent;
    color: {TEXT_SECONDARY}; font-size: {base_px + 3}px; padding: 0;
}}
QPushButton#CollapseBtn:hover {{ background: {BG_HOVER}; color: #1A1A1A; }}
QPushButton#NewChatBtn,
QPushButton#SaveBtn {{
    background-color: transparent;
    color: #333333;
    border: none;
    border-radius: 0px;
    padding: 10px 8px;
    text-align: left;
    font-size: 13px;
    font-weight: normal;
}}
QPushButton#NewChatBtn:hover,
QPushButton#SaveBtn:hover {{
    background-color: #E2E2EC;
    color: #1A1A1A;
}}
QPushButton#NewChatBtn:pressed,
QPushButton#SaveBtn:pressed {{
    background-color: #D5D5E0;
}}
QLabel#SidebarSection {{
    color: #4A5060; font-size: {small_px}px; font-weight: 700;
    padding: 14px 3px 5px 3px;
}}
QPushButton#NavBtn {{
    min-height: 36px; background: transparent; color: #333333;
    border: none; border-radius: 5px; padding: 0 8px; text-align: left;
}}
QPushButton#NavBtn:hover {{ background-color: #E2E2EC; color: #1A1A1A; }}
QPushButton#SessionMoreBtn,
QFrame#NavPanel QPushButton#SessionMoreBtn {{
    background-color: transparent;
    border: none;
    border-radius: 4px;
    padding: 4px;
}}
QPushButton#SessionMoreBtn:hover,
QFrame#NavPanel QPushButton#SessionMoreBtn:hover {{
    background-color: #E2E2EC;
}}
QFrame#NavPanel QWidget#SessionEntry,
QFrame#NavPanel QLabel#SessionNameLabel {{
    background: transparent;
}}
QLabel#SessionNameLabel {{
    color: #333333;
    border-radius: 4px;
    padding: 4px 8px;
}}
QLabel#SessionNameLabel:hover {{
    background-color: #E2E2EC;
}}
QLabel#SessionNameLabel[selected="true"] {{
    color: #1677FF;
    font-weight: bold;
}}
QLineEdit#SessionName,
QFrame#NavPanel QLineEdit#SessionName {{
    background: #FFFFFF;
    border: 1px solid #1677FF;
    border-radius: 4px;
    padding: 4px 8px;
    color: #333333;
    font-size: 13px;
}}
QListWidget,
QFrame#NavPanel QListWidget {{
    background: transparent;
    border: none;
    outline: none;
}}
QListWidget::item {{
    height: 40px;
    border-radius: 4px;
    padding: 0 8px;
}}
QListWidget::item:hover {{
    background-color: #E2E2EC;
}}
QListWidget::item:selected {{
    background-color: #E6F0FF;
    color: #1677FF;
    font-weight: bold;
}}
QPushButton#BottomBtn {{
    min-height: 34px; background: {BG_HOVER}; color: {TEXT_SECONDARY};
    border: none; border-radius: 6px; padding: 0 10px;
}}
QPushButton#BottomBtn:hover {{ background: #D5D5E0; }}
QPushButton#BottomBtn[selected="true"] {{
    background: {BG_ACTIVE}; color: {ACCENT}; font-weight: 700;
}}

QLabel#LargePageTitle {{ color: #1A1A1A; font-size: {base_px + 9}px; font-weight: 700; }}
QLabel#SectionTitle {{ color: #1A1A1A; font-size: {base_px + 2}px; font-weight: 700; }}
QLabel#CardTitle {{ color: #1A1A1A; font-size: {base_px + 1}px; font-weight: 700; }}
QLabel#MutedText {{ color: #666666; }}
QTabWidget#ConfigTabs::pane {{
    border: none; border-radius: 0; background: #FFFFFF; top: -1px;
}}
QTabWidget#ConfigTabs QTabBar {{ background: transparent; }}
QTabWidget#ConfigTabs QTabBar::tab {{
    min-width: 100px; padding: 8px 0px; margin-right: 4px; margin-bottom: 7px;
    border: none; border-radius: 6px; background: transparent;
    color: #6B7280; text-align: center;
}}
QTabWidget#ConfigTabs QTabBar::tab:hover:!selected {{
    color: #1A1A1A; background-color: #F0F2F5;
}}
QTabWidget#ConfigTabs QTabBar::tab:selected {{
    background: #E6F0FF; color: #1677FF; font-weight: bold;
    border-bottom: 2px solid #1677FF;
}}
QFrame#ConfigHeader {{
    background-color: #F1F1F5; border-bottom: 1px solid #E0E0E0;
}}
QLabel#ConfigTitle {{
    font-size: 14px; font-weight: bold; color: #1A1A1A;
}}
QPushButton#HeaderIconBtn {{
    background-color: transparent; border: none; border-radius: 6px;
    padding: 6px; font-size: 13px; color: #666666;
}}
QPushButton#HeaderIconBtn:hover {{
    background-color: #E2E2EC; color: #1A1A1A;
}}
QPushButton#HeaderIconBtn:pressed {{
    background-color: #E6E8EC;
}}
QMenu {{
    background-color: #FFFFFF;
    border: 1px solid #EAEAEA;
    border-radius: 8px;
    padding: 6px;
}}
QMenu::item {{
    padding: 8px 24px 8px 16px;
    border-radius: 4px;
    color: #333333;
}}
QMenu::item:selected {{
    background-color: #E6F0FF;
    color: #1677FF;
}}
QMenu::separator {{
    height: 1px;
    background-color: #EAEAEA;
    margin: 4px 8px;
}}
QFrame#PlaceholderCard {{
    background: #FAFAFB; border: 1px dashed {BORDER}; border-radius: 8px;
}}
QLabel#PlaceholderText {{ color: {TEXT_TERTIARY}; }}

QFrame#RightPanel {{
    background: #FAFAFB; border: 1px solid {BORDER}; border-radius: 8px;
}}
QWidget#RightPanelToolbar {{ background: transparent; }}
QToolButton#RightPanelToolButton {{
    background: transparent; color: {TEXT_SECONDARY}; border: none;
    border-radius: 4px; padding: 0;
}}
QToolButton#RightPanelToolButton:hover {{ background: #F0F2F5; }}
QToolButton#RightPanelToolButton:checked {{ background: {BG_ACTIVE}; color: {ACCENT}; }}
QWidget#DiffContent {{ background: transparent; }}
QFrame#DiffCard {{
    background: #FFFFFF; border: 1px solid #E6E8EB; border-radius: 7px;
}}
QWidget#DiffHeader {{ background: #F7F8FA; border-bottom: 1px solid #EAECEF; }}
QLabel#DiffMarker {{
    background: #EEF0F3; color: {TEXT_SECONDARY}; border-radius: 4px; font-weight: 700;
}}
QLabel#DiffFileTitle {{ color: #1A1A1A; font-size: {small_px}px; font-weight: 700; }}
QWidget#DiffLine {{ background: #F6F8FA; min-height: 24px; }}
QWidget#DiffLine[mode="add"] {{ background: #E6FFEC; }}
QWidget#DiffLine[mode="delete"] {{ background: #FFEBE9; }}
QWidget#DiffLine QLabel {{ background: transparent; }}
QWidget#DiffLine[mode="add"] QLabel#DiffCode {{ color: {POSITIVE}; }}
QWidget#DiffLine[mode="delete"] QLabel#DiffCode {{ color: {DANGER}; }}
QLabel#DiffLineNumber {{
    color: #A0A5B0; padding-right: 7px; border-right: 1px solid #E2E4E8;
    font-family: Consolas, monospace; font-size: {small_px}px;
}}
QLabel#DiffCode {{
    color: {TEXT}; padding: 3px 7px; font-family: Consolas, monospace;
    font-size: {small_px}px;
}}

QFrame#DocCard {{ background: #FFFFFF; border: 1px solid #EAEAEA; border-radius: 8px; }}
QFrame#SettingsMenu, QFrame#SettingsMenu QWidget {{ background: #FAFAFB; }}
QFrame#SettingsMenu {{ border-right: 1px solid #EAEAEA; }}
QPushButton#SettingsMenuButton {{
    min-height: 40px; background: transparent; color: {TEXT_SECONDARY};
    border: none; border-radius: 6px; padding: 0 13px; text-align: left;
}}
QPushButton#SettingsMenuButton:hover {{ background: #F0F2F5; }}
QPushButton#SettingsMenuButton:checked {{ background: {BG_ACTIVE}; color: {ACCENT}; font-weight: 700; }}
QLabel#SettingsPlaceholder {{
    color: {TEXT_TERTIARY}; background: #FAFAFB; border: 1px dashed {BORDER};
    border-radius: 8px; qproperty-alignment: AlignCenter;
}}

QScrollArea {{ border: none; background: transparent; }}
QScrollArea > QWidget > QWidget {{ background: transparent; }}
QScrollBar:vertical {{ border: none; background: transparent; width: 6px; margin: 0; }}
QScrollBar::handle:vertical {{ background: #DCDCDC; min-height: 30px; border-radius: 3px; }}
QScrollBar::handle:vertical:hover {{ background: #BFBFBF; }}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0; }}
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{ background: transparent; }}
QToolTip {{ background: #333333; color: #FFFFFF; border: none; padding: 5px 7px; }}
"""


STYLESHEET = build_stylesheet()
