"""
plm_qt_settings -- SettingsDialog, a port of the web front end's Settings
modal (tool/web/index.html's #settings-modal + the openSettingsModal/
buildVeribleFlagsForm/commitSettings family in tool/web/app.js).

Same General / Formatter split: General holds app-wide font preferences;
Formatter holds verible-path (+ Auto-detect) and the full verible flag set,
built directly from plm_common.py's own Python constants -- no schema
endpoint needed here the way plm_web.py's /api/verible/schema is, since
there's no JSON/HTTP boundary to cross.

Like the web version, verible-path/verible-flags are settings-level only:
never written into any workspace's own gen_flags.txt, only passed as
--verible-path/--verible-flags at Generate time (see plm_qt.py's
_run_tool). veribleFlags stays None until the user actually saves Settings
once; an explicitly-saved {} (every field cleared) means "no overrides,
use verible's own raw defaults" -- a different, real choice from "never
touched this panel, use this project's own defaults".
"""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.core.verible import (
    DEFAULT_VERIBLE_FLAGS,
    VERIBLE_BOOL_PARAMS,
    VERIBLE_INDENT_PARAMS,
    VERIBLE_INT_PARAMS,
    VERIBLE_ALIGN_PARAMS,
    find_verible,
)
from plm.frontend.qt.widgets.theme import RoundedComboBox, add_shadow, apply_titlebar_theme

DEFAULT_SETTINGS = {
    "veriblePath": "",
    "editorPath": "gvim",
    "fontFamily": "",
    "fontSize": 13.5,
    "veribleFlags": None,
}


class _SettingsTabBar(QtWidgets.QTabBar):
    """Give settings tabs enough room at every supported app font size."""

    def tabSizeHint(self, index):
        hint = super().tabSizeHint(index)
        metrics = QtGui.QFontMetrics(self.font())
        text_width = metrics.horizontalAdvance(self.tabText(index))
        # Match the pill QSS's own "padding: 8px 16px" instead of a taller
        # ad-hoc value -- keeps the selected tab's filled chip snug around
        # the text instead of ballooning into a big blank rectangle.
        tab_height = max(32, metrics.height() + 16)
        return QtCore.QSize(max(hint.width(), text_width + 36), max(hint.height(), tab_height))


class SettingsDialog(QtWidgets.QDialog):
    def __init__(self, parent, settings):
        super().__init__(parent)
        self.setWindowTitle("Settings")
        self.setWindowFlag(QtCore.Qt.WindowContextHelpButtonHint, False)
        self.resize(560, 520)
        apply_titlebar_theme(self)
        self._settings = {**DEFAULT_SETTINGS, **(settings or {})}
        self._flag_widgets = {}  # param -> QComboBox/QLineEdit

        outer = QtWidgets.QVBoxLayout(self)
        tabs = QtWidgets.QTabWidget()
        tabs.setObjectName("settingsTabs")
        tab_bar = _SettingsTabBar(tabs)
        tab_bar.setExpanding(False)
        tab_bar.setUsesScrollButtons(False)
        tab_bar.setElideMode(QtCore.Qt.ElideNone)
        add_shadow(tab_bar, blur=10, offset=(0, 2), alpha=30)
        tabs.setTabBar(tab_bar)
        tabs.addTab(self._build_general_tab(), "General")
        tabs.addTab(self._build_formatter_tab(), "Formatter")
        outer.addWidget(tabs, stretch=1)

        buttons = QtWidgets.QDialogButtonBox(QtWidgets.QDialogButtonBox.Save | QtWidgets.QDialogButtonBox.Cancel)
        buttons.button(QtWidgets.QDialogButtonBox.Save).setObjectName("primaryBtn")
        for role in (QtWidgets.QDialogButtonBox.Save, QtWidgets.QDialogButtonBox.Cancel):
            add_shadow(buttons.button(role), blur=10, offset=(0, 1), alpha=40)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        outer.addWidget(buttons)

    # ------------------------------------------------------------ General
    def _build_general_tab(self):
        tab = QtWidgets.QWidget()
        form = QtWidgets.QFormLayout(tab)

        self.font_family_edit = QtWidgets.QLineEdit(self._settings.get("fontFamily") or "")
        self.font_family_edit.setPlaceholderText("system default")
        form.addRow("Font:", self.font_family_edit)

        self.font_size_spin = QtWidgets.QDoubleSpinBox()
        self.font_size_spin.setRange(11, 16)
        self.font_size_spin.setDecimals(1)
        self.font_size_spin.setValue(self._settings.get("fontSize") or DEFAULT_SETTINGS["fontSize"])
        form.addRow("Font size:", self.font_size_spin)

        editor_row = QtWidgets.QWidget()
        editor_layout = QtWidgets.QHBoxLayout(editor_row)
        editor_layout.setContentsMargins(0, 0, 0, 0)
        editor_layout.setSpacing(8)
        self.editor_path_edit = QtWidgets.QLineEdit(self._settings.get("editorPath") or "gvim")
        self.editor_path_edit.setPlaceholderText("gvim")
        editor_layout.addWidget(self.editor_path_edit, stretch=1)
        editor_browse = QtWidgets.QPushButton("Browse")
        editor_browse.clicked.connect(self._browse_editor)
        add_shadow(editor_browse, blur=10, offset=(0, 1), alpha=40)
        editor_layout.addWidget(editor_browse)
        form.addRow("Editor:", editor_row)

        return tab

    # ------------------------------------------------------------ Formatter
    def _build_formatter_tab(self):
        tab = QtWidgets.QWidget()
        outer = QtWidgets.QVBoxLayout(tab)

        path_row = QtWidgets.QHBoxLayout()
        self.verible_path_edit = QtWidgets.QLineEdit(self._settings.get("veriblePath") or "")
        path_row.addWidget(self.verible_path_edit, stretch=1)
        detect_btn = QtWidgets.QPushButton("Auto-detect")
        detect_btn.clicked.connect(self._on_detect)
        add_shadow(detect_btn, blur=10, offset=(0, 1), alpha=40)
        path_row.addWidget(detect_btn)
        outer.addLayout(path_row)

        hint = QtWidgets.QLabel("Use verible-verilog-format to format Verilog files.")
        hint.setObjectName("hint")
        hint.setWordWrap(True)
        outer.addWidget(hint)

        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QtWidgets.QFrame.NoFrame)
        form_host = QtWidgets.QWidget()
        self._flags_form = QtWidgets.QFormLayout(form_host)
        scroll.setWidget(form_host)
        outer.addWidget(scroll, stretch=1)

        self._build_flags_form(self._settings.get("veribleFlags"))

        reset_btn = QtWidgets.QPushButton("Reset to default")
        reset_btn.clicked.connect(lambda: self._build_flags_form(None))
        add_shadow(reset_btn, blur=10, offset=(0, 1), alpha=40)
        outer.addWidget(reset_btn)

        return tab

    def _build_flags_form(self, current_flags):
        while self._flags_form.count():
            item = self._flags_form.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
        self._flag_widgets = {}
        flags = current_flags or {}

        def section(title, params, make_control):
            if not params:
                return
            header = QtWidgets.QLabel(title)
            header.setStyleSheet("font-weight: 600; font-size: 11px; text-transform: uppercase; margin-top: 8px;")
            self._flags_form.addRow(header)
            for param in params:
                control = make_control()
                value = flags[param] if param in flags else (DEFAULT_VERIBLE_FLAGS.get(param) or "")
                self._set_control_value(control, value)
                self._flags_form.addRow(param, control)
                self._flag_widgets[param] = control

        section("Alignment", VERIBLE_ALIGN_PARAMS, lambda: self._make_select(["align", "flush-left"]))
        section("Indentation", VERIBLE_INDENT_PARAMS, lambda: self._make_select(["indent", "wrap"]))
        section("Boolean", VERIBLE_BOOL_PARAMS, lambda: self._make_select(["true", "false"]))
        section("Integer", VERIBLE_INT_PARAMS, self._make_int_edit)
        # Other (line_terminator, lines, stdin_name, ...) intentionally
        # hidden, same as the web form: too niche to deserve form space.

    @staticmethod
    def _make_select(options):
        combo = RoundedComboBox()
        for opt in options:
            combo.addItem(opt, opt)
        return combo

    @staticmethod
    def _make_int_edit():
        edit = QtWidgets.QLineEdit()
        edit.setValidator(QtGui.QIntValidator())
        return edit

    @staticmethod
    def _set_control_value(control, value):
        if isinstance(control, QtWidgets.QComboBox):
            idx = control.findData(value)
            control.setCurrentIndex(idx if idx >= 0 else 0)
        else:
            control.setText(str(value) if value else "")

    def _read_flags_form(self):
        flags = {}
        for param, control in self._flag_widgets.items():
            val = control.currentData() if isinstance(control, QtWidgets.QComboBox) else control.text().strip()
            if val:
                flags[param] = val
        return flags

    def _on_detect(self):
        found = find_verible(None)
        if found:
            self.verible_path_edit.setText(found)
        else:
            QtWidgets.QMessageBox.information(self, "Not found", "No verible-verilog-format found on PATH.")

    def _browse_editor(self):
        path, _selected_filter = QtWidgets.QFileDialog.getOpenFileName(
            self,
            "Choose editor",
            self.editor_path_edit.text().strip(),
            "Executables (*.exe);;All files (*)",
        )
        if path:
            self.editor_path_edit.setText(path)

    # ------------------------------------------------------------ result
    def get_settings(self):
        return {
            "veriblePath": self.verible_path_edit.text().strip(),
            "editorPath": self.editor_path_edit.text().strip() or "gvim",
            "fontFamily": self.font_family_edit.text().strip(),
            "fontSize": self.font_size_spin.value(),
            "veribleFlags": self._read_flags_form(),
        }
