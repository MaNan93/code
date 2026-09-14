"""
plm.frontend.qt.main_window -- MainWindow, the PyQt5 desktop front end's
main window.

This is a thin desktop front end over the three config CSVs and
gen_flags.txt that plm.core.generator reads, and over that generation
pipeline itself. Config access goes straight through plm.core.workspace.
Editing writes the same plain CSV/gen_flags.txt files a human would edit;
Validate calls plm.core.model.Config directly; Generate runs
`python -m plm.cli.main generate ...`. See plm.frontend.qt.widgets.theme
for the QSS and plm.frontend.qt.widgets.settings for the Settings dialog.
"""

import json
import shutil
import sys
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.core.gen_flags import ARCH_PCLK_MODE, PCLK_MODE_ARCH
from plm.core.model import Config
from plm.core.paths import CONFIGS_ROOT, DOCS_DIR, PLM_ROOT, is_deletable_workspace, is_workspace_root
from plm.core.workspace import save_workspace_content, scaffold_default_content, workspace_content
from plm.frontend.qt.widgets.lanegrid import LaneGrid
from plm.frontend.qt.widgets.settings import DEFAULT_SETTINGS, SettingsDialog
from plm.frontend.qt.widgets.tables import EditableTable
from plm.frontend.qt.widgets.theme import (
    BG_HOVER,
    TEXT_SECONDARY,
    TEXT_TERTIARY,
    RoundedComboBox,
    VisibleCheckBox,
    add_shadow,
    apply_titlebar_theme,
    build_stylesheet,
)

STATE_FILE = Path.home() / ".plm_qt_settings.json"
MAX_RECENT_WORKSPACES = 10
DIRECTIONS = ["mac2phy", "phy2mac"]
SIGNAL_TYPES = ["perlane", "shared"]
# Placeholder-carrying dropdown value lists (Qt-widget-specific display
# concern -- see plm.core.gen_flags.ARCH_VALUES/PCLK_MODE_VALUES/
# SEL_MODE_VALUES for the plain, front-end-agnostic value tuples
# write_gen_flags() itself filters against).
ARCH_MODES = ["(default: original_pipe)", "original_pipe", "serdes"]
PCLK_MODES = ["(default: pclk_as_phy_output)", "pclk_as_phy_output", "pclk_as_phy_input"]
SEL_MODES = ["(default: sync)", "sync", "comb"]
LANE_COUNTS = ["x2", "x4", "x8", "x16", "x32"]
DOC_PATH = DOCS_DIR / "tool_usage.md"
PREVIEW_MAXIMIZE_ANIM_MS = 180



def _ui_scale():
    """Return a scaling factor relative to the 13 px design baseline so
    fixed-size UI chrome (sidebar, table columns, lane grid)
    stays proportional when the user changes the app font."""
    app = QtWidgets.QApplication.instance()
    px = app.font().pixelSize() if app else 13
    return max(px, 11) / 13.0


def _svg_icon(svg_path, color=TEXT_SECONDARY, size=22):
    """Build a monochrome QIcon from inline SVG path data."""
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="2" '
        f'stroke-linecap="round" stroke-linejoin="round">'
        f'{svg_path}</svg>'
    )
    img = QtGui.QImage()
    img.loadFromData(svg.encode('utf-8'))
    if img.isNull():
        return QtGui.QIcon()
    return QtGui.QIcon(QtGui.QPixmap.fromImage(img))


# SVG path data for each sidebar icon (stroke-based, 24x24 viewBox)
_SVG_NEW = '<path d="M12 5v14M5 12h14"/>'                        # + circle
_SVG_SAVE = '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><path d="M17 21v-8H7v8"/><path d="M7 3v5h8"/>'
_SVG_OPEN = '<path d="M3 7a2 2 0 0 1 2-2h4l2 3h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
_SVG_PREVIEW_PANEL = '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M15 4v16"/>'
_SVG_PREVIEW_EXPAND = '<path d="M8 3H3v5M16 21h5v-5M3 8l6-6M21 16l-6 6"/>'
_SVG_MORE = (
    f'<circle cx="6" cy="12" r="1" fill="{TEXT_TERTIARY}" stroke="none"/>'
    f'<circle cx="12" cy="12" r="1" fill="{TEXT_TERTIARY}" stroke="none"/>'
    f'<circle cx="18" cy="12" r="1" fill="{TEXT_TERTIARY}" stroke="none"/>'
)
_SVG_CHEVRON_DOWN = '<path d="m7 9 5 5 5-5"/>'
_SVG_CHEVRON_RIGHT = '<path d="m9 7 5 5-5 5"/>'
_SVG_REFRESH = '<path d="M20 11a8 8 0 1 0 2 5.3"/><path d="M20 4v7h-7"/>'
_SVG_EDIT = '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4z"/>'
_SVG_SETTINGS = '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>'
_SVG_DOC = '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/>'


class _StableTabBar(QtWidgets.QTabBar):
    """Keep tab labels separated under Windows DPI/font scaling."""

    def tabSizeHint(self, index):
        hint = super().tabSizeHint(index)
        metrics = self.fontMetrics()
        text = self.tabText(index)
        text_width = (
            metrics.horizontalAdvance(text)
            if hasattr(metrics, "horizontalAdvance")
            else metrics.width(text)
        )
        # Must cover the QSS pill's own horizontal padding (16px each side)
        # + tab margin (2px each side) + border (1px each side) = 38px, with
        # real slack -- horizontalAdvance() alone runs right up against that
        # budget and clips the first/last glyph (seen with "Pipe Signals").
        pad = int(48 * _ui_scale())
        # Match the QSS pill's own box: "padding: 8px 16px" + 1px border top
        # and bottom. Anything taller makes the selected tab's filled chip
        # read as an oversized white block; anything shorter squeezes the
        # label once the app font grows past the 32px floor.
        tab_height = max(32, metrics.height() + 18)
        return QtCore.QSize(max(hint.width(), text_width + pad), tab_height)


class _RecentItemRow(QtWidgets.QWidget):
    """A Recent-list row: name + an always-visible "more options" (kebab)
    button that opens the same menu right-click already offered, so the
    action isn't only discoverable by right-clicking."""

    open_requested = QtCore.pyqtSignal()
    menu_requested = QtCore.pyqtSignal(QtCore.QPoint)

    def __init__(self, text, alignment, parent=None):
        super().__init__(parent)
        self.setAttribute(QtCore.Qt.WA_StyledBackground, False)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(10, 0, 2, 0)
        layout.setSpacing(2)
        self.label = QtWidgets.QLabel(text)
        self.label.setAlignment(alignment)
        layout.addWidget(self.label, stretch=1)
        self.menu_btn = QtWidgets.QToolButton()
        self.menu_btn.setObjectName("recentMenuBtn")
        self.menu_btn.setText("⋮")
        self.menu_btn.setCursor(QtCore.Qt.PointingHandCursor)
        self.menu_btn.setToolTip("More options")
        self.menu_btn.clicked.connect(self._emit_menu_requested)
        layout.addWidget(self.menu_btn)

    def _emit_menu_requested(self):
        pos = self.menu_btn.mapToGlobal(QtCore.QPoint(0, self.menu_btn.height()))
        self.menu_requested.emit(pos)

    def mousePressEvent(self, event):
        # Only the label/background area falls through to here -- clicks on
        # menu_btn are consumed by the button itself before reaching this.
        if event.button() == QtCore.Qt.LeftButton:
            self.open_requested.emit()
        super().mousePressEvent(event)


class _LineNumberArea(QtWidgets.QWidget):
    def __init__(self, editor):
        super().__init__(editor)
        self._editor = editor

    def sizeHint(self):
        return QtCore.QSize(self._editor.line_number_area_width(), 0)

    def paintEvent(self, event):
        self._editor.paint_line_number_area(event)


class _CodePreviewEdit(QtWidgets.QPlainTextEdit):
    """Read-only code view with a synchronized, non-copyable line gutter."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.line_number_area = _LineNumberArea(self)
        self.blockCountChanged.connect(self._update_line_number_area_width)
        self.updateRequest.connect(self._update_line_number_area)
        self._update_line_number_area_width()

    def line_number_area_width(self):
        digits = max(2, len(str(max(1, self.blockCount()))))
        return 14 + self.fontMetrics().horizontalAdvance("9") * digits

    def _update_line_number_area_width(self, _count=0):
        self.setViewportMargins(self.line_number_area_width(), 0, 0, 0)

    def _update_line_number_area(self, rect, dy):
        if dy:
            self.line_number_area.scroll(0, dy)
        else:
            self.line_number_area.update(0, rect.y(), self.line_number_area.width(), rect.height())
        if rect.contains(self.viewport().rect()):
            self._update_line_number_area_width()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        contents = self.contentsRect()
        self.line_number_area.setGeometry(
            QtCore.QRect(contents.left(), contents.top(), self.line_number_area_width(), contents.height())
        )

    def paint_line_number_area(self, event):
        painter = QtGui.QPainter(self.line_number_area)
        painter.fillRect(event.rect(), QtGui.QColor(BG_HOVER))
        painter.setPen(QtGui.QColor(TEXT_TERTIARY))

        block = self.firstVisibleBlock()
        number = block.blockNumber()
        top = int(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        bottom = top + int(self.blockBoundingRect(block).height())
        while block.isValid() and top <= event.rect().bottom():
            if block.isVisible() and bottom >= event.rect().top():
                painter.drawText(
                    0,
                    top,
                    self.line_number_area.width() - 7,
                    self.fontMetrics().height(),
                    QtCore.Qt.AlignRight,
                    str(number + 1),
                )
            block = block.next()
            top = bottom
            bottom = top + int(self.blockBoundingRect(block).height())
            number += 1


# ---------------------------------------------------------------- state file
# Desktop state and settings (verible path/flags, editor, and font) live
# outside workspaces so opening the UI never changes generated inputs.


def _read_state_file():
    if not STATE_FILE.is_file():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _write_state_file(data):
    try:
        STATE_FILE.write_text(json.dumps(data), encoding="utf-8")
    except OSError:
        pass  # remembering workspace state is a convenience, not required


def load_recent_workspaces():
    raw = _read_state_file().get("recent", [])
    return [p for p in (Path(r) for r in raw) if is_workspace_root(p)]


def add_recent_workspace(path):
    """Appends path if it's not already listed -- an already-listed entry
    keeps its existing position instead of jumping to the front on every
    open, so the Recent list holds still and isn't reordered by use."""
    data = _read_state_file()
    path_str = str(path)
    recent = data.get("recent", [])
    if path_str not in recent:
        recent.append(path_str)
    data["recent"] = recent[-MAX_RECENT_WORKSPACES:]
    _write_state_file(data)


def remove_recent_workspace(path):
    data = _read_state_file()
    path_str = str(path)
    data["recent"] = [p for p in data.get("recent", []) if p != path_str]
    _write_state_file(data)


def save_last_workspace(path):
    data = _read_state_file()
    data["workspace"] = str(path)
    _write_state_file(data)


def clear_last_workspace():
    data = _read_state_file()
    data.pop("workspace", None)
    _write_state_file(data)


def load_last_workspace():
    raw = _read_state_file().get("workspace")
    if not raw:
        return None
    path = Path(raw)
    return path if is_workspace_root(path) else None


def load_settings():
    return {**DEFAULT_SETTINGS, **_read_state_file().get("settings", {})}


def save_settings(settings):
    data = _read_state_file()
    data["settings"] = settings
    _write_state_file(data)


def valid_name(name):
    name = (name or "").strip()
    if not name or any(c in name for c in ' /\\:*?"<>|'):
        raise ValueError('Use a plain folder name, no spaces or path characters.')
    return name


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.current_workspace = None  # Path | None
        self.setWindowTitle("plmConsultant")
        self.resize(1200, 780)
        self.setMinimumSize(900, 620)
        self._build_ui()
        self._apply_font(load_settings())
        self._refresh_recent()
        last = load_last_workspace()
        if last:
            self._open_workspace(last)

    # ------------------------------------------------------------ UI shell
    def _build_ui(self):
        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        root = QtWidgets.QHBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        self.sidebar = self._build_sidebar()
        root.addWidget(self.sidebar)

        self.content_splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        self.content_splitter.setObjectName("contentSplitter")
        self.content_splitter.setChildrenCollapsible(False)
        self.content_splitter.setHandleWidth(1)
        self.content_splitter.splitterMoved.connect(self._on_content_splitter_moved)
        self.content_splitter.addWidget(self._build_main())
        self.rtl_preview_panel = self._build_rtl_preview_panel()
        self.content_splitter.addWidget(self.rtl_preview_panel)
        self.content_splitter.setCollapsible(0, True)
        self.content_splitter.setCollapsible(1, False)
        self.main_area.installEventFilter(self)
        self.editor_shell.installEventFilter(self)
        self.rtl_preview_panel.installEventFilter(self)
        self.content_splitter.setStretchFactor(0, 1)
        self.content_splitter.setStretchFactor(1, 1)
        self.rtl_preview_panel.hide()
        self._preview_maximized = False
        self._preview_maximize_pending = False
        self._splitter_animation = None
        root.addWidget(self.content_splitter, stretch=1)

        self.preview_controls = self._build_preview_controls(central)

        # Edge toggle: a small button sitting on the seam between sidebar
        # and main content. It is not part of either layout
        # (Qt layouts can't place a widget "on the border" between two
        # siblings), so it's a plain child of `central` positioned by
        # hand in _position_sidebar_toggle(), called on every resize and
        # every collapse/expand.
        self.sidebar_toggle = QtWidgets.QToolButton(central)
        self.sidebar_toggle.setObjectName("edgeToggle")
        self.sidebar_toggle.setFixedSize(16, 56)
        self.sidebar_toggle.setCursor(QtCore.Qt.PointingHandCursor)
        self.sidebar_toggle.clicked.connect(self._on_toggle_sidebar)
        self._sidebar_collapsed = bool(_read_state_file().get("sidebarCollapsed"))
        self._apply_sidebar_collapsed()
        self._position_preview_controls()
        QtCore.QTimer.singleShot(0, self._position_preview_controls)

    def eventFilter(self, watched, event):
        if watched in (
            getattr(self, "main_area", None),
            getattr(self, "editor_shell", None),
            getattr(self, "rtl_preview_panel", None),
        ) and event.type() in (QtCore.QEvent.Resize, QtCore.QEvent.Move, QtCore.QEvent.Show):
            QtCore.QTimer.singleShot(0, self._position_preview_controls)
        return super().eventFilter(watched, event)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._position_sidebar_toggle()
        self._position_floating_log()
        self._position_preview_controls()

    def _position_preview_controls(self):
        if not getattr(self, "preview_controls", None):
            return
        central = self.centralWidget()
        margin = max(10, int(12 * _ui_scale()))
        tab_bar = self.tabs.tabBar()
        header_aligned = self.main_area.isVisible() and tab_bar.isVisible()
        if header_aligned:
            # QSS padding is resolved only after the window is shown, so the
            # final tab-bar height can differ from its construction-time hint.
            # Keep the preview heading on that exact live header geometry.
            self.preview_title.setFixedHeight(tab_bar.height())
            self.preview_controls.setFixedHeight(tab_bar.height())
            # Size the buttons off that same live height (minus the frame's
            # own 1 px border top and bottom) rather than a fixed px value,
            # so they track the tab pills at every app font size instead of
            # staying 30 px while everything around them grows.
            side = max(20, tab_bar.height() - 2)
            for button in self.preview_buttons:
                button.setFixedSize(side, side)
                button.setIconSize(QtCore.QSize(round(side * 0.6), round(side * 0.6)))
        self.preview_controls.adjustSize()
        if getattr(self, "rtl_preview_panel", None) and not self.rtl_preview_panel.isHidden():
            anchor = self.rtl_preview_panel
        else:
            anchor = getattr(self, "editor_shell", central)
        origin = anchor.mapTo(central, QtCore.QPoint(0, 0))
        inset = 8
        x = origin.x() + anchor.width() - self.preview_controls.width() - inset
        if header_aligned:
            tab_origin = tab_bar.mapTo(central, QtCore.QPoint(0, 0))
            y = tab_origin.y() + max(0, (tab_bar.height() - self.preview_controls.height()) // 2)
        else:
            y = origin.y() + inset
        self.preview_controls.move(max(margin, x), max(0, y))
        self.preview_controls.raise_()

    def _position_sidebar_toggle(self):
        if getattr(self, "editor_shell", None) and self.editor_shell.isVisible():
            x = self.editor_shell.mapTo(self.centralWidget(), QtCore.QPoint(0, 0)).x()
        elif not self.sidebar.isVisible():
            x = 0
        else:
            seam = self.sidebar.mapTo(self.centralWidget(), self.sidebar.rect().topRight())
            x = seam.x() + 1
        y = (self.centralWidget().height() - self.sidebar_toggle.height()) // 2
        self.sidebar_toggle.move(x - self.sidebar_toggle.width() // 2, max(0, y))
        self.sidebar_toggle.raise_()

    def _on_toggle_sidebar(self):
        self._sidebar_collapsed = not self._sidebar_collapsed
        self._apply_sidebar_collapsed()
        data = _read_state_file()
        data["sidebarCollapsed"] = self._sidebar_collapsed
        _write_state_file(data)

    def _apply_sidebar_collapsed(self):
        """Collapse the navigation sidebar to its icon rail."""
        collapsed = self._sidebar_collapsed
        scale = _ui_scale()
        # Scale sidebar widths from their 13 px baseline so larger fonts still
        # fit button labels and the brand name.
        self.sidebar.setFixedWidth(64 if collapsed else int(260 * scale))
        self.brand_name.setVisible(not collapsed)
        self.section_header.setVisible(not collapsed)
        self.brand_layout.setContentsMargins(16, 14, 16, 14)
        self.brand_left_spacer.changeSize(
            0, 0,
            QtWidgets.QSizePolicy.Fixed,
            QtWidgets.QSizePolicy.Minimum,
        )
        # Keep the logo on the same fixed left icon rail in both states.
        self.brand_layout.setStretch(0, 0)
        self.brand_layout.setStretch(3, 1)
        self.brand_layout.invalidate()
        self.brand_layout.activate()
        self.recent_list.setHorizontalScrollBarPolicy(
            QtCore.Qt.ScrollBarAlwaysOff if collapsed else QtCore.Qt.ScrollBarAsNeeded
        )
        self.recent_list.setProperty("collapsed", collapsed)
        self.recent_list.style().unpolish(self.recent_list)
        self.recent_list.style().polish(self.recent_list)
        rail_button_width = self.sidebar.width() - 16
        for button, label in self.sidebar_action_buttons + self.sidebar_bottom_buttons:
            button.setText("" if collapsed else f" {label}")
            # A tooltip repeating the label is only useful once the label
            # itself is hidden (collapsed, icon-only rail).
            button.setToolTip(label if collapsed else "")
            button.setProperty("collapsed", collapsed)
            button.setIconSize(QtCore.QSize(22, 22))
            button.setFixedHeight(42)
            button.style().unpolish(button)
            button.style().polish(button)
            if collapsed:
                button.setFixedWidth(rail_button_width)
            else:
                button.setMinimumWidth(0)
                button.setMaximumWidth(16777215)
        self._refresh_recent()
        self.sidebar_toggle.setText("›" if collapsed else "‹")
        self._position_sidebar_toggle()
        QtCore.QTimer.singleShot(0, self._position_sidebar_toggle)
        QtCore.QTimer.singleShot(0, self._position_floating_log)

    def _build_sidebar(self):
        sidebar = QtWidgets.QWidget()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(260)
        sb = QtWidgets.QVBoxLayout(sidebar)
        sb.setContentsMargins(0, 0, 0, 0)
        sb.setSpacing(0)

        header = QtWidgets.QWidget()
        hl = QtWidgets.QHBoxLayout(header)
        self.brand_layout = hl
        hl.setContentsMargins(16, 14, 16, 14)
        self.brand_left_spacer = QtWidgets.QSpacerItem(
            0, 0, QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Minimum
        )
        hl.addItem(self.brand_left_spacer)
        brand_mark = QtWidgets.QLabel()
        self.brand_mark = brand_mark
        mario = Path(__file__).resolve().parent / "assets" / "mario_icon.png"
        if mario.is_file():
            pix = QtGui.QPixmap(str(mario)).scaled(
                28, 28, QtCore.Qt.KeepAspectRatioByExpanding, QtCore.Qt.SmoothTransformation
            )
            brand_mark.setPixmap(pix)
        brand_mark.setFixedSize(28, 28)
        hl.addWidget(brand_mark)
        self.brand_name = QtWidgets.QLabel("plmConsultant")
        self.brand_name.setObjectName("brandName")
        hl.addWidget(self.brand_name)
        hl.addStretch(1)
        sb.addWidget(header)

        actions = QtWidgets.QWidget()
        al = QtWidgets.QVBoxLayout(actions)
        al.setContentsMargins(8, 4, 8, 8)
        al.setSpacing(4)
        btn_new = QtWidgets.QPushButton(" New")
        btn_save = QtWidgets.QPushButton(" Save")
        btn_open = QtWidgets.QPushButton(" Open")
        self.sidebar_action_buttons = [
            (btn_new, "New"), (btn_save, "Save"), (btn_open, "Open")
        ]
        for b, icon_svg, handler in (
            (btn_new, _SVG_NEW, self._on_new),
            (btn_save, _SVG_SAVE, self._on_save),
            (btn_open, _SVG_OPEN, self._on_open),
        ):
            b.setObjectName("sidebarBtn")
            icon = _svg_icon(icon_svg)
            if not icon.isNull():
                b.setIcon(icon)
                b.setIconSize(QtCore.QSize(22, 22))
                b.setLayoutDirection(QtCore.Qt.LeftToRight)
                b.setStyleSheet(b.styleSheet() + "" if b.styleSheet() else "")
            add_shadow(b, blur=8, offset=(0, 1), alpha=30)
            b.clicked.connect(handler)
            al.addWidget(b)
        sb.addWidget(actions)

        section = QtWidgets.QWidget()
        sl = QtWidgets.QVBoxLayout(section)
        sl.setContentsMargins(8, 8, 8, 16)
        self.section_header = QtWidgets.QLabel("最近")
        self.section_header.setObjectName("sectionHeader")
        self.section_header.setContentsMargins(2, 0, 0, 6)
        sl.addWidget(self.section_header)
        self.recent_list = QtWidgets.QListWidget()
        self.recent_list.setObjectName("recentList")
        self.recent_list.setFrameShape(QtWidgets.QFrame.NoFrame)
        self.recent_list.itemClicked.connect(self._on_recent_clicked)
        self.recent_list.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.recent_list.customContextMenuRequested.connect(self._on_recent_context_menu)
        sl.addWidget(self.recent_list, stretch=1)
        sb.addWidget(section, stretch=1)

        bottom = QtWidgets.QWidget()
        bl = QtWidgets.QVBoxLayout(bottom)
        bl.setContentsMargins(8, 8, 8, 8)
        bl.setSpacing(4)
        btn_settings = QtWidgets.QPushButton(" Settings")
        btn_doc = QtWidgets.QPushButton(" Doc")
        self.sidebar_bottom_buttons = [
            (btn_settings, "Settings"), (btn_doc, "Doc")
        ]
        for b, icon_svg, handler in (
            (btn_settings, _SVG_SETTINGS, self._on_settings),
            (btn_doc, _SVG_DOC, self._on_doc),
        ):
            b.setObjectName("sidebarBtn")
            icon = _svg_icon(icon_svg)
            if not icon.isNull():
                b.setIcon(icon)
                b.setIconSize(QtCore.QSize(22, 22))
            add_shadow(b, blur=8, offset=(0, 1), alpha=30)
            b.clicked.connect(handler)
            bl.addWidget(b)
        sb.addWidget(bottom)

        return sidebar

    def _build_main(self):
        main = QtWidgets.QWidget()
        # Let the splitter shrink this pane below the tab bar's size hint so
        # a leftward drag can reach the preview-maximize snap threshold.
        main.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Expanding)
        self.main_area = main
        mv = QtWidgets.QVBoxLayout(main)
        mv.setContentsMargins(0, 0, 0, 0)
        mv.setSpacing(0)

        content = QtWidgets.QWidget()
        cv = QtWidgets.QVBoxLayout(content)
        # Fill the main content width and meet the title bar at the top.  Keep
        # only the bottom breathing room used by the floating log card.
        cv.setContentsMargins(0, 0, 0, 12)

        self.tabs = QtWidgets.QTabWidget()
        self.tabs.setObjectName("tabs")
        tab_bar = _StableTabBar(self.tabs)
        tab_bar.setExpanding(False)
        tab_bar.setUsesScrollButtons(False)
        tab_bar.setElideMode(QtCore.Qt.ElideNone)
        add_shadow(tab_bar, blur=10, offset=(0, 2), alpha=30)
        self.tabs.setTabBar(tab_bar)
        self.tabs.addTab(self._build_controllers_tab(), "Controllers")
        self._lane_mapping_page = self._build_lane_mapping_tab()
        self.tabs.addTab(self._lane_mapping_page, "Lane Mapping")
        self.tabs.addTab(self._build_signals_tab(), "Pipe Signals")
        self.tabs.addTab(self._build_generation_tab(), "Generation")
        self.tabs.currentChanged.connect(self._on_tab_changed)

        editor_shell = QtWidgets.QFrame()
        editor_shell.setObjectName("editorShell")
        self.editor_shell = editor_shell
        editor_layout = QtWidgets.QVBoxLayout(editor_shell)
        editor_layout.setContentsMargins(0, 0, 0, 0)
        editor_layout.setSpacing(0)
        editor_layout.addWidget(self.tabs, stretch=1)
        cv.addWidget(editor_shell, stretch=1)

        mv.addWidget(content, stretch=1)

        # The log is an overlay: it never consumes vertical space from the
        # active editor. Expanded it floats across the bottom of the main
        # area; collapsed it becomes a compact button in the lower-right.
        self.log_card = self._build_log_panel()
        self.log_card.setParent(main)
        self.log_card.raise_()
        QtCore.QTimer.singleShot(0, self._position_floating_log)

        return main

    def _build_preview_controls(self, parent):
        controls = QtWidgets.QWidget(parent)
        controls.setObjectName("previewControls")
        layout = QtWidgets.QHBoxLayout(controls)
        # The frame already contributes its own 1 px border, and the buttons
        # are sized to fill the rest of the tab-bar height exactly (see
        # _position_preview_controls), so any padding here would push this
        # group taller than the tab bar and break the centre-line match.
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)

        self.preview_refresh_btn = QtWidgets.QToolButton(controls)
        self.preview_refresh_btn.setObjectName("previewControlBtn")
        self.preview_refresh_btn.setIcon(_svg_icon(_SVG_REFRESH, size=18))
        self.preview_refresh_btn.setIconSize(QtCore.QSize(18, 18))
        self.preview_refresh_btn.setToolTip("Refresh generated files")
        self.preview_refresh_btn.clicked.connect(self._refresh_rtl_preview)
        self.preview_refresh_btn.hide()

        self.preview_edit_btn = QtWidgets.QToolButton(controls)
        self.preview_edit_btn.setObjectName("previewControlBtn")
        self.preview_edit_btn.setIcon(_svg_icon(_SVG_EDIT, size=18))
        self.preview_edit_btn.setIconSize(QtCore.QSize(18, 18))
        self.preview_edit_btn.setToolTip("Edit current file in gvim")
        self.preview_edit_btn.clicked.connect(self._edit_selected_rtl_file)
        self.preview_edit_btn.hide()

        self.preview_expand_btn = QtWidgets.QToolButton(controls)
        self.preview_expand_btn.setObjectName("previewControlBtn")
        self.preview_expand_btn.setIcon(_svg_icon(_SVG_PREVIEW_EXPAND, size=18))
        self.preview_expand_btn.setIconSize(QtCore.QSize(18, 18))
        self.preview_expand_btn.setToolTip("Maximize RTL preview")
        self.preview_expand_btn.clicked.connect(self._on_toggle_preview_maximized)
        self.preview_expand_btn.hide()

        self.preview_toggle_btn = QtWidgets.QToolButton(controls)
        self.preview_toggle_btn.setObjectName("previewControlBtn")
        self.preview_toggle_btn.setCheckable(True)
        self.preview_toggle_btn.setIcon(_svg_icon(_SVG_PREVIEW_PANEL, size=18))
        self.preview_toggle_btn.setIconSize(QtCore.QSize(18, 18))
        self.preview_toggle_btn.setToolTip("Show RTL preview")
        self.preview_toggle_btn.clicked.connect(self._on_toggle_rtl_preview)

        self.preview_buttons = [
            self.preview_refresh_btn,
            self.preview_edit_btn,
            self.preview_expand_btn,
            self.preview_toggle_btn,
        ]
        for b in self.preview_buttons:
            layout.addWidget(b)
        return controls

    def _build_rtl_preview_panel(self):
        panel = QtWidgets.QFrame()
        panel.setObjectName("rtlPreviewPanel")
        layout = QtWidgets.QVBoxLayout(panel)
        # Match the tab bar's y-origin; editorShell contributes a 1 px border.
        layout.setContentsMargins(18, 1, 18, 14)
        layout.setSpacing(10)

        title_row = QtWidgets.QHBoxLayout()
        title = QtWidgets.QLabel("Preview")
        self.preview_title = title
        title.setObjectName("rtlPreviewTitle")
        title.setFixedHeight(self.tabs.tabBar().tabSizeHint(0).height())
        title_row.addWidget(title, alignment=QtCore.Qt.AlignVCenter)
        title_row.addStretch(1)
        layout.addLayout(title_row)

        self.preview_file_combo = RoundedComboBox()
        self.preview_file_combo.setObjectName("previewFileCombo")
        self.preview_file_combo.currentIndexChanged.connect(self._show_selected_rtl_file)
        layout.addWidget(self.preview_file_combo)

        self.preview_status = QtWidgets.QLabel("Generate RTL to preview the output.")
        self.preview_status.setObjectName("previewStatus")
        self.preview_status.setWordWrap(True)
        layout.addWidget(self.preview_status)

        self.preview_code = _CodePreviewEdit()
        self.preview_code.setObjectName("rtlPreviewCode")
        self.preview_code.setReadOnly(True)
        self.preview_code.setLineWrapMode(QtWidgets.QPlainTextEdit.NoWrap)
        layout.addWidget(self.preview_code, stretch=1)
        return panel

    def _on_toggle_rtl_preview(self, checked):
        if getattr(self, "_splitter_animation", None) is not None:
            self._splitter_animation.stop()
            self._splitter_animation = None
        self._preview_maximized = False
        self._preview_maximize_pending = False
        self.main_area.setVisible(True)
        self.rtl_preview_panel.setVisible(checked)
        self.preview_toggle_btn.setChecked(checked)
        self.preview_refresh_btn.setVisible(checked)
        self.preview_edit_btn.setVisible(checked)
        self.preview_expand_btn.setVisible(checked)
        self.preview_toggle_btn.setToolTip("Hide RTL preview" if checked else "Show RTL preview")
        self.preview_expand_btn.setToolTip("Maximize RTL preview")
        if checked:
            self._refresh_rtl_preview()
            total = max(800, self.content_splitter.width())
            self.content_splitter.setSizes([int(total * 0.56), int(total * 0.44)])
        self._position_preview_controls()
        QtCore.QTimer.singleShot(0, self._position_floating_log)

    def _last_tab_reveal_width(self):
        """Width the tab bar (flush with main_area's left/right edges) needs
        so its last tab -- Generation -- is fully visible and not clipped by
        a narrower left splitter pane."""
        tab_bar = self.tabs.tabBar()
        count = tab_bar.count()
        if count == 0:
            return 0
        rect = tab_bar.tabRect(count - 1)
        return rect.x() + rect.width()

    def _on_content_splitter_moved(self, position, _index):
        self._position_floating_log()
        if (
            getattr(self, "_preview_maximized", False)
            or getattr(self, "_preview_maximize_pending", False)
            or self.rtl_preview_panel.isHidden()
            or not self.main_area.isVisible()
        ):
            return
        snap_position = self._last_tab_reveal_width()
        if position <= snap_position:
            # Drag can fire splitterMoved several times before this deferred
            # call runs; latch immediately so a fast drag doesn't queue the
            # toggle twice and cancel itself back out.
            self._preview_maximize_pending = True
            QtCore.QTimer.singleShot(0, self._trigger_preview_maximize_from_snap)

    def _trigger_preview_maximize_from_snap(self):
        self._preview_maximize_pending = False
        if not self._preview_maximized:
            self._on_toggle_preview_maximized()

    def _animate_splitter_sizes(self, target_sizes, on_finished=None):
        splitter = self.content_splitter
        start_sizes = splitter.sizes()
        if getattr(self, "_splitter_animation", None) is not None:
            self._splitter_animation.stop()
        if len(start_sizes) != len(target_sizes):
            splitter.setSizes(target_sizes)
            if on_finished:
                on_finished()
            return

        anim = QtCore.QVariantAnimation(self)
        anim.setDuration(PREVIEW_MAXIMIZE_ANIM_MS)
        anim.setStartValue(0.0)
        anim.setEndValue(1.0)
        anim.setEasingCurve(QtCore.QEasingCurve.OutCubic)

        def _apply(t):
            sizes = [int(round(s + (target - s) * t)) for s, target in zip(start_sizes, target_sizes)]
            splitter.setSizes(sizes)
            self._position_preview_controls()
            self._position_floating_log()

        anim.valueChanged.connect(_apply)

        def _cleanup():
            self._splitter_animation = None
            if on_finished:
                on_finished()

        anim.finished.connect(_cleanup)
        self._splitter_animation = anim
        anim.start()

    def _on_toggle_preview_maximized(self):
        total = max(800, self.content_splitter.width())
        if not self._preview_maximized:
            self._preview_maximized = True
            self.preview_toggle_btn.setChecked(True)
            self.preview_refresh_btn.show()
            self.preview_edit_btn.show()
            self.preview_expand_btn.show()
            self.rtl_preview_panel.show()
            self.preview_expand_btn.setToolTip("Restore split preview")
            self.preview_toggle_btn.setToolTip("Hide RTL preview")
            self._refresh_rtl_preview()

            def _finish_maximize():
                # Only actually remove main_area from the layout once it has
                # visually shrunk to nothing, so the collapse reads as a
                # slide rather than an instant cut.
                if self._preview_maximized:
                    self.main_area.hide()
                self._position_preview_controls()
                self._position_floating_log()

            self._animate_splitter_sizes([0, total], on_finished=_finish_maximize)
        else:
            self._preview_maximized = False
            self.main_area.show()
            self.rtl_preview_panel.show()
            self.preview_expand_btn.setToolTip("Maximize RTL preview")
            self._animate_splitter_sizes(
                [int(total * 0.56), int(total * 0.44)],
                on_finished=lambda: (self._position_preview_controls(), self._position_floating_log()),
            )
        self._position_preview_controls()
        QtCore.QTimer.singleShot(0, self._position_floating_log)

    def _refresh_rtl_preview(self):
        previous = self.preview_file_combo.currentData()
        self.preview_file_combo.blockSignals(True)
        self.preview_file_combo.clear()
        files = []
        if self.current_workspace:
            preview_roots = (
                (self.current_workspace / "config", {".csv"}),
                (self.current_workspace / "rtl", {".sv", ".svh", ".v", ".vh", ".f"}),
            )
            for root, extensions in preview_roots:
                if root.is_dir():
                    files.extend(
                        path
                        for path in root.rglob("*")
                        if path.is_file() and path.suffix.lower() in extensions
                    )
            files.sort(key=lambda path: str(path.relative_to(self.current_workspace)).lower())
            for path in files:
                self.preview_file_combo.addItem(
                    str(path.relative_to(self.current_workspace)),
                    str(path),
                )
        if previous:
            index = self.preview_file_combo.findData(previous)
            if index >= 0:
                self.preview_file_combo.setCurrentIndex(index)
        self.preview_file_combo.blockSignals(False)
        self.preview_file_combo.setVisible(bool(files))
        if files:
            self.preview_status.hide()
            self._show_selected_rtl_file(self.preview_file_combo.currentIndex())
        else:
            self.preview_status.setText("Generate RTL to preview the output.")
            self.preview_status.show()
            self.preview_code.clear()

    def _show_selected_rtl_file(self, index):
        path_text = self.preview_file_combo.itemData(index) if index >= 0 else None
        if not path_text:
            self.preview_code.clear()
            return
        path = Path(path_text)
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as error:
            self.preview_code.setPlainText(f"Could not read {path}:\n{error}")
            return
        self.preview_code.setPlainText(text)
        self.preview_code.moveCursor(QtGui.QTextCursor.Start)

    def _edit_selected_rtl_file(self):
        index = self.preview_file_combo.currentIndex()
        path_text = self.preview_file_combo.itemData(index) if index >= 0 else None
        if not path_text:
            QtWidgets.QMessageBox.information(self, "No file", "Select a generated RTL file first.")
            return
        editor = load_settings().get("editorPath") or "gvim"
        result = QtCore.QProcess.startDetached(editor, [str(path_text)])
        started = result[0] if isinstance(result, tuple) else result
        if not started:
            QtWidgets.QMessageBox.warning(
                self,
                "Editor launch failed",
                f"Could not start '{editor}'. Set the editor path in Settings.",
            )

    def _position_floating_log(self):
        if not getattr(self, "main_area", None) or not getattr(self, "log_card", None):
            return
        scale = _ui_scale()
        margin = max(12, int(14 * scale))
        expanded = self.log_toggle.isChecked()
        # Use the editor shell's real geometry so the floating card fills the
        # same left-to-right boundary at every DPI/font size.
        if getattr(self, "editor_shell", None):
            shell_origin = self.editor_shell.mapTo(self.main_area, QtCore.QPoint(0, 0))
            x = shell_origin.x()
            width = max(240, self.editor_shell.width())
            bottom = shell_origin.y() + self.editor_shell.height()
        else:
            x = margin
            width = max(240, self.main_area.width() - 2 * margin)
            bottom = self.main_area.height() - margin
        if expanded:
            height = min(int(260 * scale), max(190, int(self.main_area.height() * 0.38)))
        else:
            # Collapsed: hug the header row's real height instead of a fixed
            # constant that was taller than "LOG" + the chevron actually need.
            margins = self.log_layout.contentsMargins()
            height = self.log_header.sizeHint().height() + margins.top() + margins.bottom()
        y = max(margin, bottom - height)
        self.log_card.setGeometry(x, y, width, height)
        self.log_card.raise_()

    @classmethod
    def _card(cls):
        """Create a card frame and return it with its content layout."""
        frame = QtWidgets.QFrame()
        frame.setObjectName("card")
        add_shadow(frame)
        layout = QtWidgets.QVBoxLayout(frame)
        layout.setContentsMargins(22, 22, 22, 22)
        return frame, layout

    def _build_controllers_tab(self):
        frame, layout = self._card()
        layout.setContentsMargins(0, 0, 0, 0)
        self.controllers_table = EditableTable(
            columns=[{"key": "ctrl_id", "heading": "ctrl_id"},
                     {"key": "ctrl_name", "heading": "ctrl_name"},
                     {"key": "max_width", "heading": "max_width"}],
            id_column="ctrl_id",
        )
        layout.addWidget(self.controllers_table)
        return frame

    def _build_signals_tab(self):
        frame, layout = self._card()
        layout.setContentsMargins(0, 0, 0, 0)
        self.signals_table = EditableTable(
            columns=[
                {"key": "signal_name", "heading": "signal_name"},
                {"key": "signal_type", "heading": "signal_type", "options": SIGNAL_TYPES, "width": 108},
                {"key": "direction", "heading": "direction", "options": DIRECTIONS, "width": 128},
                {"key": "width", "heading": "width", "width": 66},
                {"key": "safe_state", "heading": "safe_state", "width": 84},
                {"key": "tie_off", "heading": "tie_off", "width": 66},
            ],
        )
        layout.addWidget(self.signals_table)
        return frame

    def _build_lane_mapping_tab(self):
        frame, layout = self._card()
        top = QtWidgets.QHBoxLayout()
        top.addWidget(QtWidgets.QLabel("Num of Lanes"))
        self.lane_count_combo = RoundedComboBox()
        self.lane_count_combo.addItems(LANE_COUNTS)
        self.lane_count_combo.currentTextChanged.connect(self._on_lane_count_changed)
        top.addWidget(self.lane_count_combo)
        top.addStretch(1)
        layout.addLayout(top)

        self.lane_grid = LaneGrid()
        layout.addWidget(self.lane_grid, stretch=1)
        return frame

    def _build_generation_tab(self):
        frame, layout = self._card()
        form = QtWidgets.QFormLayout()
        form.setLabelAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
        form.setFormAlignment(QtCore.Qt.AlignTop)

        self.arch_combo = RoundedComboBox()
        self.arch_combo.addItems(ARCH_MODES)
        form.addRow("arch", self.arch_combo)

        self.pclk_mode_combo = RoundedComboBox()
        self.pclk_mode_combo.addItems(PCLK_MODES)
        form.addRow("pclk-mode", self.pclk_mode_combo)

        # arch and pclk-mode are two views of the same one choice (see
        # ARCH_PCLK_MODE) -- keep them in sync in both directions, guarded
        # against the recursive re-trigger a currentTextChanged inside the
        # other's handler would otherwise cause.
        self._arch_pclk_sync_active = False

        def on_arch_changed(text):
            if self._arch_pclk_sync_active:
                return
            if text in ARCH_PCLK_MODE:
                self._arch_pclk_sync_active = True
                try:
                    self.pclk_mode_combo.setCurrentText(ARCH_PCLK_MODE[text])
                finally:
                    self._arch_pclk_sync_active = False

        def on_pclk_changed(text):
            if self._arch_pclk_sync_active:
                return
            if text in PCLK_MODE_ARCH:
                self._arch_pclk_sync_active = True
                try:
                    self.arch_combo.setCurrentText(PCLK_MODE_ARCH[text])
                finally:
                    self._arch_pclk_sync_active = False

        self.arch_combo.currentTextChanged.connect(on_arch_changed)
        self.pclk_mode_combo.currentTextChanged.connect(on_pclk_changed)

        self.sel_mode_combo = RoundedComboBox()
        self.sel_mode_combo.addItems(SEL_MODES)
        form.addRow("sel-mode", self.sel_mode_combo)

        self.dpr_check = VisibleCheckBox()

        def on_dpr_toggled(checked):
            # DPR needs sel-mode=sync (comb is only safe when every branch
            # shares one clock domain, which DPR can't guarantee) -- force
            # it and lock the control while dpr is checked, rather than
            # let the user pick an unsafe combination that `plm generate
            # rtl`'s own --dpr/--sel-mode check would only reject at
            # generation time.
            if checked:
                self.sel_mode_combo.setCurrentText("sync")
                self.sel_mode_combo.setEnabled(False)
            else:
                self.sel_mode_combo.setEnabled(True)

        self.dpr_check.toggled.connect(on_dpr_toggled)
        form.addRow("dpr", self.dpr_check)
        layout.addLayout(form)

        actions_row = QtWidgets.QHBoxLayout()
        actions_row.addStretch(1)
        btn_validate = QtWidgets.QPushButton("Validate")
        btn_gen_rtl = QtWidgets.QPushButton("Generate RTL")
        btn_gen_tb = QtWidgets.QPushButton("Generate TB")
        btn_gen_all = QtWidgets.QPushButton("Generate All")
        btn_gen_all.setObjectName("primaryBtn")
        btn_validate.clicked.connect(self._on_validate)
        btn_gen_rtl.clicked.connect(self._on_gen_rtl)
        btn_gen_tb.clicked.connect(self._on_gen_tb)
        btn_gen_all.clicked.connect(self._on_gen_all)
        for b in (btn_validate, btn_gen_rtl, btn_gen_tb, btn_gen_all):
            actions_row.addWidget(b)
        layout.addLayout(actions_row)
        layout.addStretch(1)

        return frame

    def _build_log_panel(self):
        card = QtWidgets.QFrame()
        card.setObjectName("logCard")
        card.setContentsMargins(0, 0, 0, 0)
        add_shadow(card)
        self.log_layout = QtWidgets.QVBoxLayout(card)
        self.log_layout.setContentsMargins(18, 14, 18, 16)
        self.log_layout.setSpacing(10)

        header = QtWidgets.QWidget()
        header.setObjectName("logHeader")
        self.log_header = header
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(4)
        self.log_title = QtWidgets.QLabel("LOG")
        self.log_title.setObjectName("logTitle")
        self.log_title.setFixedHeight(26)
        header_layout.addWidget(self.log_title, alignment=QtCore.Qt.AlignVCenter)
        header_layout.addStretch(1)
        self.log_more = QtWidgets.QToolButton()
        self.log_more.setObjectName("logHeaderBtn")
        self.log_more.setIcon(_svg_icon(_SVG_MORE, size=16))
        self.log_more.setIconSize(QtCore.QSize(16, 16))
        self.log_more.setToolTip("Log options")
        self.log_more.clicked.connect(self._show_log_menu)
        header_layout.addWidget(self.log_more, alignment=QtCore.Qt.AlignVCenter)
        self.log_toggle = QtWidgets.QToolButton()
        self.log_toggle.setObjectName("logToggle")
        self.log_toggle.setIcon(_svg_icon(_SVG_CHEVRON_DOWN, size=16))
        self.log_toggle.setIconSize(QtCore.QSize(16, 16))
        self.log_toggle.setCheckable(True)
        self.log_toggle.setChecked(True)
        self.log_toggle.setToolButtonStyle(QtCore.Qt.ToolButtonIconOnly)
        self.log_toggle.setCursor(QtCore.Qt.PointingHandCursor)
        self.log_toggle.clicked.connect(self._on_toggle_log)
        header_layout.addWidget(self.log_toggle, alignment=QtCore.Qt.AlignVCenter)
        self.log_layout.addWidget(header)

        self.log = QtWidgets.QPlainTextEdit()
        self.log.setObjectName("logConsole")
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(2000)
        self.log.setMinimumHeight(100)
        self.log_layout.addWidget(self.log, stretch=1)

        return card

    def _on_toggle_log(self, checked):
        chevron = _SVG_CHEVRON_DOWN if checked else _SVG_CHEVRON_RIGHT
        self.log_toggle.setIcon(_svg_icon(chevron, size=16))
        self.log_more.setVisible(checked)
        self.log.setVisible(checked)
        self.log_layout.setContentsMargins(18, 14 if checked else 8, 18, 16 if checked else 8)
        self._position_floating_log()

    def _show_log_menu(self):
        menu = QtWidgets.QMenu(self.log_more)
        clear_action = menu.addAction("Clear log")
        chosen = menu.exec_(self.log_more.mapToGlobal(QtCore.QPoint(0, self.log_more.height())))
        if chosen == clear_action:
            self.log.clear()

    def _log(self, text):
        ts = QtCore.QTime.currentTime().toString("HH:mm:ss")
        self.log.appendPlainText(f"[{ts}] {text}")

    # ------------------------------------------------------------ recent list
    def _refresh_recent(self):
        self.recent_list.clear()
        collapsed = getattr(self, "_sidebar_collapsed", False)
        current = str(self.current_workspace) if self.current_workspace else None
        for p in load_recent_workspaces():
            parts = [part for part in p.name.replace("-", "_").split("_") if part]
            initials = (
                "".join(part[0] for part in parts[:2]).upper()
                if len(parts) > 1 else p.name[:2].upper()
            )
            alignment = QtCore.Qt.AlignCenter if collapsed else QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
            item = QtWidgets.QListWidgetItem()
            item.setData(QtCore.Qt.UserRole, str(p))
            self.recent_list.addItem(item)
            if collapsed:
                item.setText(initials)
                item.setTextAlignment(alignment)
                item.setToolTip(str(p))
            else:
                row = _RecentItemRow(p.name, alignment)
                row.label.setToolTip(str(p))
                row.open_requested.connect(lambda path=str(p): self._open_workspace(Path(path)))
                row.menu_requested.connect(lambda pos, it=item: self._show_recent_menu(it, pos))
                # QListWidget#recentList::item's QSS padding/margin (9px/12px
                # + 1px, 20px total vertical) shrinks a widget-item's
                # allocated height instead of adding to it -- an explicit
                # sizeHint smaller than that just collapses to 0 and the row
                # renders blank. Pad past it with real slack.
                hint = row.sizeHint()
                item.setSizeHint(QtCore.QSize(hint.width(), hint.height() + 28))
                self.recent_list.setItemWidget(item, row)
            if str(p) == current:
                item.setSelected(True)

    def _on_recent_clicked(self, item):
        # Only fires for the collapsed (icon-rail) rows -- expanded rows use
        # a custom _RecentItemRow widget that handles its own click instead.
        if self.recent_list.itemWidget(item) is None:
            self._open_workspace(Path(item.data(QtCore.Qt.UserRole)))

    def _on_recent_context_menu(self, pos):
        item = self.recent_list.itemAt(pos)
        if item is None:
            return
        self._show_recent_menu(item, self.recent_list.mapToGlobal(pos))

    def _show_recent_menu(self, item, global_pos):
        path = item.data(QtCore.Qt.UserRole)
        menu = QtWidgets.QMenu(self)
        remove_action = menu.addAction("Remove from list")
        delete_action = menu.addAction("Delete project")
        chosen = menu.exec_(global_pos)
        if chosen == remove_action:
            self._remove_recent_entry(path)
        elif chosen == delete_action:
            self._delete_workspace_at(path)

    def _remove_recent_entry(self, path):
        remove_recent_workspace(path)
        self._log(f"Removed {path} from Recent.")
        self._refresh_recent()

    def _delete_workspace_at(self, path):
        path = Path(path).resolve()
        if not is_deletable_workspace(path):
            QtWidgets.QMessageBox.warning(
                self,
                "Delete refused",
                "This directory is not a marked PLM workspace. Open and Save a "
                "legacy workspace once before deleting it.",
            )
            return
        resp = QtWidgets.QMessageBox.question(
            self,
            "Delete workspace",
            f"Permanently delete '{path}' and everything under it (config, generated rtl/tb)? "
            "This cannot be undone.",
        )
        if resp != QtWidgets.QMessageBox.Yes:
            return
        try:
            shutil.rmtree(path)
        except OSError as e:
            QtWidgets.QMessageBox.critical(self, "Delete failed", str(e))
            self._log(f"Delete failed: {e}")
            return
        remove_recent_workspace(path)
        self._log(f"Deleted workspace {path}.")
        if self.current_workspace and str(self.current_workspace) == str(path):
            self.current_workspace = None
            clear_last_workspace()
            self.controllers_table.set_rows([])
            self.signals_table.set_rows([])
            self._load_gen_flags({})
            self._set_lane_count_display(4)
            self.lane_grid.set_columns(4)
            self.lane_grid.set_rows([])
            self.lane_grid.set_controllers([])
            self._update_workspace_label()
        self._refresh_recent()

    def _update_workspace_label(self):
        if self.current_workspace:
            self.setWindowTitle(f"plmConsultant - {self.current_workspace.name}")
        else:
            self.setWindowTitle("plmConsultant")

    # ------------------------------------------------------------ workspace lifecycle
    def _open_workspace(self, path):
        path = Path(path).resolve()
        if not is_workspace_root(path):
            QtWidgets.QMessageBox.warning(
                self, "Open failed", f"Not a PLM workspace (missing config CSVs): {path}"
            )
            return
        try:
            content = workspace_content(path)
        except (ValueError, OSError) as e:
            QtWidgets.QMessageBox.critical(self, "Load failed", f"Could not load {path}:\n{e}")
            return
        self.current_workspace = path
        self.controllers_table.set_rows(content["controllers"])
        self.signals_table.set_rows(content["signals"])
        self._load_gen_flags(content["gen_flags"])
        mapping = content["mapping"]
        self._set_lane_count_display(mapping["lane_count"])
        self.lane_grid.set_columns(mapping["lane_count"])
        self.lane_grid.set_rows(mapping["rows"])
        self.lane_grid.set_controllers(self.controllers_table.get_rows())
        add_recent_workspace(path)
        save_last_workspace(path)
        self._refresh_recent()
        self._update_workspace_label()
        self._log(f"Loaded {path}.")
        if getattr(self, "rtl_preview_panel", None) and self.rtl_preview_panel.isVisible():
            self._refresh_rtl_preview()

    def _load_gen_flags(self, flags):
        # read_gen_flags()/workspace_content() return None for an
        # unset/unrecognized arch/pclk-mode/sel-mode (their shared,
        # front-end-agnostic shape) -- translate that to this GUI's own
        # "(default: ...)" placeholder option, same translation
        # plmConsultant.py's own _load_workspace_content does.
        # verible-path is a Settings-level value, never surfaced on this page (see
        # _run_tool for where it's actually used).
        self.arch_combo.setCurrentText(flags.get("arch") or ARCH_MODES[0])
        self.pclk_mode_combo.setCurrentText(flags.get("pclk-mode") or PCLK_MODES[0])
        self.sel_mode_combo.setCurrentText(flags.get("sel-mode") or SEL_MODES[0])
        self.dpr_check.setChecked(bool(flags.get("dpr")))

    def _gather_payload(self):
        """Collect the four config files' worth of content to write on
        Save, straight from the live widgets."""
        return {
            "controllers": self.controllers_table.get_rows(),
            "signals": self.signals_table.get_rows(),
            "mapping": {
                "lane_count": self.lane_grid.lane_count,
                "rows": self.lane_grid.get_rows(),
            },
            # write_gen_flags() itself filters out any value that isn't a
            # real arch/pclk-mode/sel-mode choice, so passing the combo's
            # raw currentText() straight through is safe even while it
            # still shows its own "(default: ...)" placeholder option.
            "gen_flags": {
                "arch": self.arch_combo.currentText(),
                "pclk-mode": self.pclk_mode_combo.currentText(),
                "sel-mode": self.sel_mode_combo.currentText(),
                "dpr": self.dpr_check.isChecked(),
            },
        }

    def _on_open(self):
        start_dir = str(CONFIGS_ROOT if CONFIGS_ROOT.is_dir() else Path.home())
        d = QtWidgets.QFileDialog.getExistingDirectory(self, "Open workspace", start_dir)
        if d:
            self._open_workspace(d)

    def _on_new(self):
        # "New" creates a config set -- it's a naming action, not a
        # "browse to a location" one: just ask for a
        # name, land it next to whatever's currently open (or
        # CONFIGS_ROOT/home when nothing is).
        name, ok = QtWidgets.QInputDialog.getText(self, "New workspace", "New config name:")
        if not ok:
            return
        try:
            name = valid_name(name)
        except ValueError as e:
            QtWidgets.QMessageBox.warning(self, "Invalid name", str(e))
            return
        parent = self.current_workspace.parent if self.current_workspace else (
            CONFIGS_ROOT if CONFIGS_ROOT.is_dir() else Path.home()
        )
        ws = parent / name
        if ws.exists():
            QtWidgets.QMessageBox.warning(self, "New workspace", f"{ws} already exists.")
            return
        try:
            ws.mkdir(parents=True)
            scaffold_default_content(ws)
        except (ValueError, OSError) as e:
            shutil.rmtree(ws, ignore_errors=True)
            QtWidgets.QMessageBox.critical(self, "New workspace failed", str(e))
            self._log(f"New workspace failed: {e}")
            return
        self._open_workspace(ws)

    def _on_save(self):
        if self.current_workspace is None:
            QtWidgets.QMessageBox.warning(self, "No workspace", "Open or create a workspace first.")
            return
        try:
            save_workspace_content(self.current_workspace, self._gather_payload())
        except (ValueError, OSError) as e:
            QtWidgets.QMessageBox.critical(self, "Save failed", str(e))
            self._log(f"Save failed: {e}")
            return
        self._log(f"Saved {self.current_workspace}/config/*.")

    def _on_settings(self):
        dlg = SettingsDialog(self, load_settings())
        if dlg.exec_() == QtWidgets.QDialog.Accepted:
            settings = dlg.get_settings()
            save_settings(settings)
            self._apply_font(settings)

    def _apply_font(self, settings):
        family = settings.get("fontFamily")
        size = settings.get("fontSize") or DEFAULT_SETTINGS["fontSize"]
        # Clamp to the same range the Settings dialog exposes. Sizes above
        # ~16 px blow up fixed-width UI parts (sidebar, lane grid, tables)
        # that are sized against a 13 px baseline.
        size = max(11, min(size, 16))
        # QApplication.font()'s own untouched default is locale-dependent,
        # not "the system UI font" -- on a Chinese-locale Windows install
        # it can resolve to SimSun (a legacy bitmap CJK font) even for an
        # otherwise-English UI, and asking that font to render Latin text
        # at an arbitrary pixel size is what was producing badly garbled,
        # overlapping glyphs app-wide. Naming a real UI font explicitly
        # sidesteps that; Qt's own family-substitution falls back
        # gracefully to the platform default on a machine that doesn't
        # have "Segoe UI" (e.g. the CentOS target), so this is safe
        # cross-platform, not a Windows-only fix.
        font = QtGui.QFont(family) if family else QtGui.QFont("Segoe UI")
        # setPointSizeF() with a fractional value (13.5, this app's own
        # default) also garbles text on Windows independent of the family
        # issue above -- setPixelSize() only takes an int and doesn't
        # have that problem, and is the more literal match for a size
        # that is stored as a CSS-like pixel size.
        font.setPixelSize(round(size))
        app = QtWidgets.QApplication.instance()
        app.setFont(font)
        # The app font alone changes nothing the QSS names a font-size for,
        # and it names one for QWidget -- so the sheet has to be rebuilt at
        # the new size too, or this setting only ever moves padding around.
        app.setStyleSheet(build_stylesheet(round(size)))
        self._apply_sidebar_collapsed()
        QtCore.QTimer.singleShot(0, self._position_floating_log)
        QtCore.QTimer.singleShot(0, self._position_preview_controls)

    def _on_doc(self):
        dlg = QtWidgets.QDialog(self)
        dlg.setWindowTitle("Documentation")
        dlg.setWindowFlag(QtCore.Qt.WindowContextHelpButtonHint, False)
        dlg.resize(760, 640)
        apply_titlebar_theme(dlg)
        v = QtWidgets.QVBoxLayout(dlg)
        viewer = QtWidgets.QTextBrowser()
        try:
            text = DOC_PATH.read_text(encoding="utf-8")
        except OSError as e:
            text = f"Could not load {DOC_PATH}:\n{e}"
        if hasattr(viewer, "setMarkdown"):
            viewer.setMarkdown(text)
        else:
            viewer.setPlainText(text)
        v.addWidget(viewer)
        close_btn = QtWidgets.QPushButton("Close")
        close_btn.clicked.connect(dlg.accept)
        v.addWidget(close_btn, alignment=QtCore.Qt.AlignRight)
        dlg.exec_()

    # ------------------------------------------------------------ Lane Mapping tab
    def _set_lane_count_display(self, n):
        """Update the lane-count combobox to show n. The GUI uses x-prefix
        labels (x1/x2/x4/...), but a config set
        loaded from disk may legitimately have an arbitrary lane count --
        plm itself supports any width, only this picker is narrowed for
        usability -- so a value outside LANE_COUNTS is appended just so it
        can be displayed, not offered as a normal choice going forward."""
        self.lane_count_combo.blockSignals(True)
        self.lane_count_combo.clear()
        values = list(LANE_COUNTS)
        label = f"x{n}"
        if label not in values:
            values.append(label)
        self.lane_count_combo.addItems(values)
        self.lane_count_combo.setCurrentText(label)
        self.lane_count_combo.blockSignals(False)

    def _on_lane_count_changed(self, text):
        # Text comes in "x2"/"x4"/... format (web parity). Strip the prefix.
        text = text.lstrip("xX")
        try:
            n = int(text)
            if n < 1:
                raise ValueError
        except ValueError:
            return
        self.lane_grid.set_columns(n)

    def _on_tab_changed(self, index):
        # Refresh the palette from the Controllers table's live state
        # whenever the Lane Mapping tab becomes active, so a controller
        # renamed/added/removed there shows up without a separate manual
        # sync step (mirrors plmConsultant.py's own _on_tab_changed).
        if self.tabs.widget(index) is self._lane_mapping_page:
            self.lane_grid.set_controllers(self.controllers_table.get_rows())

    # ------------------------------------------------------------ validate / generate
    def _save_before_action(self):
        """Save-before-action, same as every other front end: Validate and
        Generate must always act on current tab content, not whatever was
        last written to disk. Returns True on success, False (after
        already reporting the error) on failure."""
        if self.current_workspace is None:
            QtWidgets.QMessageBox.warning(self, "No workspace", "Open or create a workspace first.")
            return False
        try:
            save_workspace_content(self.current_workspace, self._gather_payload())
        except (ValueError, OSError) as e:
            QtWidgets.QMessageBox.critical(self, "Save failed", str(e))
            self._log(f"Save failed: {e}")
            return False
        return True

    def _on_validate(self):
        if not self._save_before_action():
            return
        cfg_dir = self.current_workspace / "config"
        self._log(f"--- validating {cfg_dir} ---")
        try:
            cfg = Config(cfg_dir)
        except SystemExit as e:
            self._log(str(e))
            return
        errs = cfg.validate()
        if errs:
            self._log("Config validation failed:")
            for e in errs:
                self._log(f"  - {e}")
        else:
            self._log("OK -- config is valid.")

    def _on_gen_rtl(self):
        self._run_tool("rtl")

    def _on_gen_tb(self):
        self._run_tool("tb")

    def _on_gen_all(self):
        self._run_tool("all")

    def _run_tool(self, target, then=None):
        """QProcess runs `python -m plm.cli.main generate <target>`
        against the current workspace asynchronously. QProcess signals
        deliver output on the Qt event loop as it arrives.

        verible-path/verible-flags come from this app's own Settings
        (see plm.frontend.qt.widgets.settings). Neither is written into
        the workspace's gen_flags.txt; both are passed only for this
        invocation."""
        if not self._save_before_action():
            return
        cmd = [sys.executable, "-m", "plm.cli.main", "generate", target, "--config", str(self.current_workspace)]
        settings = load_settings()
        verible_path = settings.get("veriblePath")
        if verible_path:
            cmd += ["--verible-path", verible_path]
        verible_flags = settings.get("veribleFlags")
        if verible_flags is not None:
            cmd += ["--verible-flags", json.dumps(verible_flags)]
        self._log(f"$ {' '.join(cmd)}")

        proc = QtCore.QProcess(self)
        proc.setWorkingDirectory(str(PLM_ROOT))
        proc.setProcessChannelMode(QtCore.QProcess.MergedChannels)

        def on_ready_read():
            data = bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
            for line in data.splitlines():
                self._log(line)

        def on_finished(exit_code, _exit_status):
            if exit_code == 0:
                self._log("[generate finished]")
                if target in ("rtl", "all"):
                    self._refresh_rtl_preview()
            else:
                self._log(f"[generate finished, exit code {exit_code}]")
            if proc in self._active_processes:
                self._active_processes.remove(proc)
            if then and exit_code == 0:
                then()

        def on_error(_error):
            if proc.state() == QtCore.QProcess.NotRunning:
                self._log(f"Failed to launch generate {target}: {proc.errorString()}")

        proc.readyReadStandardOutput.connect(on_ready_read)
        proc.finished.connect(on_finished)
        proc.errorOccurred.connect(on_error)
        # Keep a reference alive for the process's lifetime -- nothing
        # else holds one once _run_tool() returns, and PyQt can garbage
        # collect a QProcess with no live Python reference out from under
        # a still-running child.
        if not hasattr(self, "_active_processes"):
            self._active_processes = []
        self._active_processes.append(proc)
        proc.start(cmd[0], cmd[1:])
