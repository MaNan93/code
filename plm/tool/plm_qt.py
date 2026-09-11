#!/usr/bin/env python3
"""
plm_qt -- PIPE Lane Mapper config editor + generator, PyQt5 desktop front end.

Same role as plmConsultant.py (Tkinter) and plm_web.py (Flask/browser): a
thin front end over the three config CSVs / gen_flags.txt that
plm_gen_rtl.py and plm_gen_tb.py read, and over those two tools
themselves. All three tools coexist as independent entry points --
plmConsultant.py and plm_web.py are untouched by this one.

Unlike plm_web.py, there's no JSON/HTTP boundary here: config access goes
straight through plm_common.py's shared workspace_content/
save_workspace_content/scaffold_default_content (and the CSV/gen_flags
read-write functions they're built on), the same ones plmConsultant.py and
plm_web.py already use. Editing still just writes the same plain CSV/
gen_flags.txt files a human would hand-edit; Validate calls
plm_config.Config directly; Generate shells out to the two real CLI tools.

Layout and theme are a deliberate port of the web front end's current
"ChatGPT-inspired" look (tool/web/index.html + style.css), not just a
functional equivalent: same sidebar structure (brand mark, New/Save/Open,
Recent with a per-item context menu, Settings/Doc), same tab set and order
(Controllers / Lane Mapping / Pipe Signals / Generation), same Generation
page (flags + Validate/Generate actions together, no separate toolbar),
verible-path/flags living in a Settings dialog rather than per-workspace,
and a collapsible log panel -- see plm_qt_theme.py for the QSS and
plm_qt_settings.py for the Settings dialog.

Run: python3 tool/plm_qt.py
"""

import json
import shutil
import sys
from pathlib import Path

try:
    from PyQt5 import QtCore, QtGui, QtWidgets
except ImportError:
    sys.exit(
        "plm_qt needs PyQt5. Install it with:\n"
        "    pip install PyQt5\n"
        "(or, offline, transfer the PyQt5/PyQt5-sip wheels to this machine and pip install those)."
    )

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from plm_common import (  # noqa: E402
    ARCH_PCLK_MODE,
    CONFIGS_ROOT,
    PCLK_MODE_ARCH,
    PLM_ROOT,
    save_workspace_content,
    scaffold_default_content,
    workspace_content,
)
from plm_qt_tables import EditableTable  # noqa: E402
from plm_qt_lanegrid import LaneGrid  # noqa: E402
from plm_qt_settings import DEFAULT_SETTINGS, SettingsDialog  # noqa: E402
from plm_qt_theme import STYLESHEET  # noqa: E402
from plm_config import Config  # noqa: E402

STATE_FILE = Path.home() / ".plm_qt_settings.json"
MAX_RECENT_WORKSPACES = 10
DIRECTIONS = ["mac2phy", "phy2mac"]
SIGNAL_TYPES = ["perlane", "shared"]
# Placeholder-carrying dropdown value lists (Qt-widget-specific display
# concern, same as plmConsultant.py's own ARCH_MODES/PCLK_MODES/SEL_MODES --
# see plm_common.ARCH_VALUES/PCLK_MODE_VALUES/SEL_MODE_VALUES for the
# plain, front-end-agnostic value tuples write_gen_flags() itself filters
# against).
ARCH_MODES = ["(default: original_pipe)", "original_pipe", "serdes"]
PCLK_MODES = ["(default: pclk_as_phy_output)", "pclk_as_phy_output", "pclk_as_phy_input"]
SEL_MODES = ["(default: sync)", "sync", "comb"]
LANE_COUNTS = ["1", "2", "4", "8", "16", "32"]
DOC_PATH = PLM_ROOT / "docs" / "tool_usage.md"


# ---------------------------------------------------------------- state file
# An independent copy of plm_web.py's own _read_state_file/etc
# (plm_web.py:94-141) -- own state file, own copy of the logic, so the
# three front ends never interfere with each other just from more than one
# being open at once, per this project's "coexist" decision. Also holds
# this app's own Settings (verible path/flags, font) under a "settings"
# key, mirroring the web version's localStorage entry for the same data.


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
    return [p for p in (Path(r) for r in raw) if p.is_dir()]


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


def load_last_workspace():
    raw = _read_state_file().get("workspace")
    if not raw:
        return None
    path = Path(raw)
    return path if path.is_dir() else None


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
        root.addWidget(self._build_main(), stretch=1)

        # Edge toggle: a small button sitting on the seam between sidebar
        # and main content, matching the web version's floating
        # .edge-toggle (tool/web/style.css) -- not part of either layout
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

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._position_sidebar_toggle()

    def _position_sidebar_toggle(self):
        x = self.sidebar.width() if self.sidebar.isVisible() else 0
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
        self.sidebar.setVisible(not self._sidebar_collapsed)
        self.sidebar_toggle.setText("›" if self._sidebar_collapsed else "‹")
        self._position_sidebar_toggle()

    def _build_sidebar(self):
        sidebar = QtWidgets.QWidget()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(260)
        sb = QtWidgets.QVBoxLayout(sidebar)
        sb.setContentsMargins(0, 0, 0, 0)
        sb.setSpacing(0)

        header = QtWidgets.QWidget()
        hl = QtWidgets.QHBoxLayout(header)
        hl.setContentsMargins(16, 14, 16, 14)
        brand_mark = QtWidgets.QLabel()
        mario = SCRIPT_DIR / "web" / "mario.png"
        if mario.is_file():
            pix = QtGui.QPixmap(str(mario)).scaled(
                28, 28, QtCore.Qt.KeepAspectRatioByExpanding, QtCore.Qt.SmoothTransformation
            )
            brand_mark.setPixmap(pix)
        brand_mark.setFixedSize(28, 28)
        hl.addWidget(brand_mark)
        brand_name = QtWidgets.QLabel("plmConsultant")
        brand_name.setObjectName("brandName")
        hl.addWidget(brand_name)
        hl.addStretch(1)
        sb.addWidget(header)

        actions = QtWidgets.QWidget()
        al = QtWidgets.QVBoxLayout(actions)
        al.setContentsMargins(8, 4, 8, 8)
        al.setSpacing(4)
        btn_new = QtWidgets.QPushButton("New")
        btn_save = QtWidgets.QPushButton("Save")
        btn_open = QtWidgets.QPushButton("Open")
        for b, handler in ((btn_new, self._on_new), (btn_save, self._on_save), (btn_open, self._on_open)):
            b.setObjectName("sidebarBtn")
            b.clicked.connect(handler)
            al.addWidget(b)
        sb.addWidget(actions)

        section = QtWidgets.QWidget()
        sl = QtWidgets.QVBoxLayout(section)
        sl.setContentsMargins(8, 8, 8, 16)
        header_lbl = QtWidgets.QLabel("最近")
        header_lbl.setObjectName("sectionHeader")
        header_lbl.setContentsMargins(2, 0, 0, 6)
        sl.addWidget(header_lbl)
        self.recent_list = QtWidgets.QListWidget()
        self.recent_list.setObjectName("recentList")
        self.recent_list.setFrameShape(QtWidgets.QFrame.NoFrame)
        self.recent_list.itemClicked.connect(self._on_recent_clicked)
        self.recent_list.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.recent_list.customContextMenuRequested.connect(self._on_recent_context_menu)
        sl.addWidget(self.recent_list, stretch=1)
        sb.addWidget(section, stretch=1)

        bottom = QtWidgets.QWidget()
        bl = QtWidgets.QHBoxLayout(bottom)
        bl.setContentsMargins(8, 8, 8, 8)
        btn_settings = QtWidgets.QPushButton("Settings")
        btn_doc = QtWidgets.QPushButton("Doc")
        for b, handler in ((btn_settings, self._on_settings), (btn_doc, self._on_doc)):
            b.setObjectName("sidebarBtn")
            b.clicked.connect(handler)
            bl.addWidget(b)
        sb.addWidget(bottom)

        return sidebar

    def _build_main(self):
        main = QtWidgets.QWidget()
        mv = QtWidgets.QVBoxLayout(main)
        mv.setContentsMargins(0, 0, 0, 0)
        mv.setSpacing(0)

        topbar = QtWidgets.QWidget()
        topbar.setObjectName("topbar")
        topbar.setFixedHeight(56)
        tl = QtWidgets.QHBoxLayout(topbar)
        tl.setContentsMargins(18, 0, 18, 0)
        self.workspace_label = QtWidgets.QLabel("No workspace open")
        self.workspace_label.setObjectName("workspaceTitle")
        tl.addWidget(self.workspace_label)
        tl.addStretch(1)
        mv.addWidget(topbar)

        content = QtWidgets.QWidget()
        cv = QtWidgets.QVBoxLayout(content)
        cv.setContentsMargins(16, 20, 16, 12)

        self.tabs = QtWidgets.QTabWidget()
        self.tabs.setObjectName("tabs")
        self.tabs.addTab(self._build_controllers_tab(), "Controllers")
        self._lane_mapping_page = self._build_lane_mapping_tab()
        self.tabs.addTab(self._lane_mapping_page, "Lane Mapping")
        self.tabs.addTab(self._build_signals_tab(), "Pipe Signals")
        self.tabs.addTab(self._build_generation_tab(), "Generation")
        self.tabs.currentChanged.connect(self._on_tab_changed)
        cv.addWidget(self.tabs, stretch=1)

        mv.addWidget(content, stretch=1)

        # Inset the log panel from the window edges (10px top, 14px sides/
        # bottom) so it reads as its own floating card -- matching
        # #log-section's margin in style.css -- rather than a strip glued
        # flush to the window boundary.
        log_wrap = QtWidgets.QWidget()
        lw = QtWidgets.QVBoxLayout(log_wrap)
        lw.setContentsMargins(14, 10, 14, 14)
        lw.addWidget(self._build_log_panel())
        mv.addWidget(log_wrap)

        return main

    @staticmethod
    def _add_shadow(widget):
        """Qt has no CSS box-shadow equivalent in QSS -- a
        QGraphicsDropShadowEffect is the actual way to give a widget the
        soft, floating look style.css gets from --shadow-sm."""
        effect = QtWidgets.QGraphicsDropShadowEffect(widget)
        effect.setBlurRadius(16)
        effect.setOffset(0, 2)
        effect.setColor(QtGui.QColor(0, 0, 0, 35))
        widget.setGraphicsEffect(effect)

    @classmethod
    def _card(cls, hint_text=None):
        """A .card-equivalent QFrame: bg-elevated, border, radius-md,
        drop shadow, optionally with the same leading hint paragraph
        every web page starts with. Returns (frame, layout) so callers
        add their own content below the hint."""
        frame = QtWidgets.QFrame()
        frame.setObjectName("card")
        cls._add_shadow(frame)
        layout = QtWidgets.QVBoxLayout(frame)
        layout.setContentsMargins(22, 22, 22, 22)
        if hint_text:
            hint = QtWidgets.QLabel(hint_text)
            hint.setObjectName("hint")
            hint.setWordWrap(True)
            layout.addWidget(hint)
        return frame, layout

    def _build_controllers_tab(self):
        frame, layout = self._card(
            "One row per controller. ctrl_id is this row's position (0, 1, 2, ...) and "
            "auto-renumbers when you reorder. Drag a row to reorder; use the + / - at the end "
            "of a row to insert below or delete it."
        )
        self.controllers_table = EditableTable(
            columns=[{"key": "ctrl_id", "heading": "ctrl_id"},
                     {"key": "ctrl_name", "heading": "ctrl_name"},
                     {"key": "max_width", "heading": "max_width"}],
            id_column="ctrl_id",
        )
        layout.addWidget(self.controllers_table)
        return frame

    def _build_signals_tab(self):
        frame, layout = self._card(
            "One row per PIPE signal carried through the mapper. Drag a row to reorder; use "
            "the + / - at the end of a row to insert below or delete it."
        )
        self.signals_table = EditableTable(
            columns=[
                {"key": "signal_name", "heading": "signal_name"},
                {"key": "signal_type", "heading": "signal_type", "options": SIGNAL_TYPES},
                {"key": "direction", "heading": "direction", "options": DIRECTIONS},
                {"key": "width", "heading": "width"},
                {"key": "safe_state", "heading": "safe_state"},
                {"key": "tie_off", "heading": "tie_off"},
            ],
        )
        layout.addWidget(self.signals_table)
        return frame

    def _build_lane_mapping_tab(self):
        frame, layout = self._card(
            "Click a controller swatch, then click-and-drag across cells to paint them. "
            "Double-click a cell to type its exact value. Drag a row to reorder; use the + / - "
            "at the end of a row to insert below or delete it."
        )
        top = QtWidgets.QHBoxLayout()
        top.addWidget(QtWidgets.QLabel("Num of Lanes:"))
        self.lane_count_combo = QtWidgets.QComboBox()
        self.lane_count_combo.addItems(LANE_COUNTS)
        self.lane_count_combo.currentTextChanged.connect(self._on_lane_count_changed)
        top.addWidget(self.lane_count_combo)
        top.addStretch(1)
        layout.addLayout(top)

        self.lane_grid = LaneGrid()
        layout.addWidget(self.lane_grid, stretch=1)
        return frame

    def _build_generation_tab(self):
        frame, layout = self._card(
            "Optional per-config-set defaults, written to config/gen_flags.txt. Both "
            "generators read this file automatically; an explicit command-line flag still "
            "overrides it. Leave a dropdown on its \"(default: ...)\" entry to omit that key."
        )
        form = QtWidgets.QFormLayout()

        self.arch_combo = QtWidgets.QComboBox()
        self.arch_combo.addItems(ARCH_MODES)
        form.addRow("arch:", self.arch_combo)

        self.pclk_mode_combo = QtWidgets.QComboBox()
        self.pclk_mode_combo.addItems(PCLK_MODES)
        form.addRow("pclk-mode:", self.pclk_mode_combo)

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

        self.sel_mode_combo = QtWidgets.QComboBox()
        self.sel_mode_combo.addItems(SEL_MODES)
        form.addRow("sel-mode:", self.sel_mode_combo)

        self.dpr_check = QtWidgets.QCheckBox("dpr")

        def on_dpr_toggled(checked):
            # DPR needs sel-mode=sync (see plmConsultant.py's own
            # _on_dpr_toggle for why comb isn't safe with it) -- force it
            # and lock the control while dpr is checked, rather than let
            # the user pick an unsafe combination that plm_gen_rtl.py's own
            # --dpr/--sel-mode check would only reject at generation time.
            if checked:
                self.sel_mode_combo.setCurrentText("sync")
                self.sel_mode_combo.setEnabled(False)
            else:
                self.sel_mode_combo.setEnabled(True)

        self.dpr_check.toggled.connect(on_dpr_toggled)
        form.addRow("", self.dpr_check)
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
        self._add_shadow(card)
        v = QtWidgets.QVBoxLayout(card)
        v.setContentsMargins(10, 14, 10, 14)
        v.setSpacing(0)

        self.log_toggle = QtWidgets.QToolButton()
        self.log_toggle.setObjectName("logToggle")
        self.log_toggle.setText("▾ LOG")
        self.log_toggle.setCheckable(True)
        self.log_toggle.setChecked(True)
        self.log_toggle.setToolButtonStyle(QtCore.Qt.ToolButtonTextOnly)
        self.log_toggle.setCursor(QtCore.Qt.PointingHandCursor)
        self.log_toggle.clicked.connect(self._on_toggle_log)
        v.addWidget(self.log_toggle)

        self.log = QtWidgets.QPlainTextEdit()
        self.log.setObjectName("logConsole")
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(2000)
        self.log.setFixedHeight(160)
        v.addWidget(self.log)

        return card

    def _on_toggle_log(self, checked):
        self.log_toggle.setText(("▾" if checked else "▸") + " LOG")
        self.log.setVisible(checked)

    def _log(self, text):
        ts = QtCore.QTime.currentTime().toString("HH:mm:ss")
        self.log.appendPlainText(f"[{ts}] {text}")

    # ------------------------------------------------------------ recent list
    def _refresh_recent(self):
        self.recent_list.clear()
        for p in load_recent_workspaces():
            item = QtWidgets.QListWidgetItem(p.name)
            item.setToolTip(str(p))
            item.setData(QtCore.Qt.UserRole, str(p))
            self.recent_list.addItem(item)

    def _on_recent_clicked(self, item):
        self._open_workspace(Path(item.data(QtCore.Qt.UserRole)))

    def _on_recent_context_menu(self, pos):
        item = self.recent_list.itemAt(pos)
        if item is None:
            return
        path = item.data(QtCore.Qt.UserRole)
        menu = QtWidgets.QMenu(self)
        remove_action = menu.addAction("Remove from list")
        delete_action = menu.addAction("Delete project")
        chosen = menu.exec_(self.recent_list.mapToGlobal(pos))
        if chosen == remove_action:
            self._remove_recent_entry(path)
        elif chosen == delete_action:
            self._delete_workspace_at(path)

    def _remove_recent_entry(self, path):
        remove_recent_workspace(path)
        self._log(f"Removed {path} from Recent.")
        self._refresh_recent()

    def _delete_workspace_at(self, path):
        resp = QtWidgets.QMessageBox.question(
            self,
            "Delete workspace",
            f"Permanently delete '{path}' and everything under it (config, generated rtl/tb)? "
            "This cannot be undone.",
        )
        if resp != QtWidgets.QMessageBox.Yes:
            return
        shutil.rmtree(path)
        remove_recent_workspace(path)
        self._log(f"Deleted workspace {path}.")
        if str(self.current_workspace) == str(path):
            self.current_workspace = None
            self._update_workspace_label()
        self._refresh_recent()

    def _update_workspace_label(self):
        if self.current_workspace:
            self.workspace_label.setText(self.current_workspace.name)
            self.setWindowTitle(f"plmConsultant - {self.current_workspace.name}")
        else:
            self.workspace_label.setText("No workspace open")
            self.setWindowTitle("plmConsultant")

    # ------------------------------------------------------------ workspace lifecycle
    def _open_workspace(self, path):
        path = Path(path)
        if not path.is_dir():
            QtWidgets.QMessageBox.warning(self, "Open failed", f"Not a directory: {path}")
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

    def _load_gen_flags(self, flags):
        # read_gen_flags()/workspace_content() return None for an
        # unset/unrecognized arch/pclk-mode/sel-mode (their shared,
        # front-end-agnostic shape) -- translate that to this GUI's own
        # "(default: ...)" placeholder option, same translation
        # plmConsultant.py's own _load_workspace_content does.
        # verible-path is not loaded here -- like the web front end, it's a
        # Settings-level value now, never surfaced on this page (see
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
        # "browse to a location" one (matches the web front end's own
        # openNewWorkspaceFlow, fixed for the same reason): just ask for a
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
        ws.mkdir(parents=True)
        scaffold_default_content(ws)
        self._open_workspace(ws)

    def _on_save(self):
        if self.current_workspace is None:
            QtWidgets.QMessageBox.warning(self, "No workspace", "Open or create a workspace first.")
            return
        try:
            save_workspace_content(self.current_workspace, self._gather_payload())
        except ValueError as e:
            QtWidgets.QMessageBox.critical(self, "Save failed", str(e))
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
        # that was modeled on the web version's CSS pixel-based
        # font-size in the first place.
        font.setPixelSize(round(size))
        QtWidgets.QApplication.instance().setFont(font)

    def _on_doc(self):
        dlg = QtWidgets.QDialog(self)
        dlg.setWindowTitle("Documentation")
        dlg.resize(760, 640)
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
        """Update the lane-count combobox to show n. The GUI restricts new
        choices to power-of-2 values (LANE_COUNTS), but a config set
        loaded from disk may legitimately have an arbitrary lane count --
        plm itself supports any width, only this picker is narrowed for
        usability -- so a value outside LANE_COUNTS is appended just so it
        can be displayed, not offered as a normal choice going forward."""
        self.lane_count_combo.blockSignals(True)
        self.lane_count_combo.clear()
        values = list(LANE_COUNTS)
        if str(n) not in values:
            values.append(str(n))
        self.lane_count_combo.addItems(values)
        self.lane_count_combo.setCurrentText(str(n))
        self.lane_count_combo.blockSignals(False)

    def _on_lane_count_changed(self, text):
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
        except ValueError as e:
            QtWidgets.QMessageBox.critical(self, "Save failed", str(e))
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
        self._run_tool("plm_gen_rtl.py")

    def _on_gen_tb(self):
        self._run_tool("plm_gen_tb.py")

    def _on_gen_all(self):
        self._run_tool("plm_gen_rtl.py", then=lambda: self._run_tool("plm_gen_tb.py"))

    def _run_tool(self, script, then=None):
        """QProcess runs the same real CLI tool the Makefile (and the
        other two front ends) use, asynchronously -- no worker thread or
        SSE plumbing needed the way plmConsultant.py/plm_web.py require,
        since QProcess's signals already deliver output on the Qt event
        loop as it arrives.

        verible-path/verible-flags come from this app's own Settings (see
        plm_qt_settings.py) -- like the web front end, neither is ever
        written into the workspace's own gen_flags.txt, only passed as
        --verible-path/--verible-flags on this one invocation (mirrors
        plm_web.py's stream_generate, plm_web.py:326-359)."""
        if not self._save_before_action():
            return
        cmd = [sys.executable, str(SCRIPT_DIR / script), "--config", str(self.current_workspace)]
        settings = load_settings()
        verible_path = settings.get("veriblePath")
        if verible_path:
            cmd += ["--verible-path", verible_path]
        verible_flags = settings.get("veribleFlags")
        if verible_flags is not None:
            cmd += ["--verible-flags", json.dumps(verible_flags)]
        self._log(f"$ {' '.join(cmd)}")

        proc = QtCore.QProcess(self)
        proc.setWorkingDirectory(str(SCRIPT_DIR.parent))
        proc.setProcessChannelMode(QtCore.QProcess.MergedChannels)

        def on_ready_read():
            data = bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
            for line in data.splitlines():
                self._log(line)

        def on_finished(exit_code, _exit_status):
            # 0/1 are the ordinary success/failure outcomes and the
            # surrounding output already makes that clear -- only an
            # unusual code (e.g. a native crash) is worth calling out.
            if exit_code not in (0, 1):
                self._log(f"[exit code {exit_code}]")
            self._active_processes.remove(proc)
            if then:
                then()

        def on_error(_error):
            if proc.state() == QtCore.QProcess.NotRunning:
                self._log(f"Failed to launch {script}: {proc.errorString()}")

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


def main():
    app = QtWidgets.QApplication(sys.argv)
    # Custom QSS on QTabBar/QPushButton/etc. renders inconsistently (tabs
    # overlapping, buttons losing their box) under whichever native style
    # (windowsvista, GTK, ...) is active by default -- each native style
    # bakes in its own tab-overlap/button-chrome metrics that generic QSS
    # doesn't fully override. Fusion is Qt's own style, built to be styled,
    # so switching to it before applying the stylesheet is what makes the
    # QSS below render the way it's written rather than fighting the
    # platform style underneath it.
    app.setStyle("Fusion")
    # Set a real UI font before building any widget, not just inside
    # MainWindow._apply_font() -- QApplication's own untouched default
    # font is locale-dependent (on a Chinese-locale Windows install it
    # can resolve to SimSun, a legacy bitmap CJK font, even for an
    # English UI), and every widget built against that default bakes in
    # its bad metrics at construction time. Setting this first means
    # MainWindow's own _apply_font() call later is just adjusting size,
    # not recovering from an already-wrong family.
    app.setFont(QtGui.QFont("Segoe UI", 13))
    app.setStyleSheet(STYLESHEET)
    win = MainWindow()
    win.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
