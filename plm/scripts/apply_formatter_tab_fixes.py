from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative, old, new):
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"anchor not found in {relative}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep Verible's built-in defaults separate from this project's formatter preset.
replace_once(
    "src/plm/core/verible.py",
    '''VERIBLE_STR_PARAMS = ("lines", "line_terminator", "stdin_name")  # free-form -- "lines" e.g. "3-5,10-12"\n\n# This project's own long-standing defaults''',
    '''VERIBLE_STR_PARAMS = ("lines", "line_terminator", "stdin_name")  # free-form -- "lines" e.g. "3-5,10-12"\n\n# Built-in defaults reported by current verible-verilog-format --helpfull.\n# These are intentionally distinct from DEFAULT_VERIBLE_FLAGS below, which\n# is PLM's own formatting preset.  An empty UI value means "do not pass this\n# flag", so Verible uses the corresponding value from this mapping.\nVERIBLE_BUILTIN_DEFAULTS = {\n    **{name: "infer" for name in VERIBLE_ALIGN_PARAMS},\n    **{name: "wrap" for name in VERIBLE_INDENT_PARAMS},\n    "compact_indexing_and_selections": "true",\n    "expand_coverpoints": "false",\n    "port_declarations_right_align_packed_dimensions": "false",\n    "port_declarations_right_align_unpacked_dimensions": "false",\n    "try_wrap_long_lines": "false",\n    "wrap_end_else_clauses": "false",\n    "verify": "false",\n    "verify_convergence": "true",\n    "failsafe_success": "true",\n    "column_limit": "100",\n    "indentation_spaces": "2",\n    "line_break_penalty": "2",\n    "over_column_limit_penalty": "100",\n    "max_search_states": "100000",\n    "lines": "",\n    "line_terminator": "auto",\n    "stdin_name": "<stdin>",\n}\n\n# This project's own long-standing defaults''',
)

# Formatter UI: real defaults in controls + top-aligned, fill-height layout.
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,\n    VERIBLE_BOOL_PARAMS, VERIBLE_INT_PARAMS, VERIBLE_STR_PARAMS, find_verible,''',
    '''    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,\n    VERIBLE_BOOL_PARAMS, VERIBLE_BUILTIN_DEFAULTS, VERIBLE_INT_PARAMS,\n    VERIBLE_STR_PARAMS, find_verible,''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        content, layout = self._content_shell(\n            "General", "配置会保存在本机，并在下次启动时自动恢复。"\n        )\n        preferences = self.initial_preferences''',
    '''        content, layout = self._content_shell(\n            "General", "配置会保存在本机，并在下次启动时自动恢复。"\n        )\n        self.settings_content_layout = layout\n        preferences = self.initial_preferences''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        self.formatter_panel = self._build_formatter(preferences)\n        layout.addWidget(self.formatter_panel, 1)''',
    '''        self.formatter_panel = self._build_formatter(preferences)\n        self._formatter_layout_index = layout.count()\n        layout.addWidget(self.formatter_panel, 1)''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        layout.addLayout(actions)\n        layout.addStretch(1)\n        return content''',
    '''        layout.addLayout(actions)\n        self._bottom_stretch_index = layout.count()\n        layout.addStretch(1)\n        return content''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        self.formatter_panel.setVisible(index == 3)''',
    '''        is_formatter = index == 3\n        self.formatter_panel.setVisible(is_formatter)\n        # Formatter uses the whole content column: top aligned, 32 px side\n        # padding / 24 px vertical padding, with its table taking all spare\n        # height and the global actions pinned to the bottom.  Other Settings\n        # tabs retain their existing margins and stretch behavior.\n        self.settings_content_layout.setContentsMargins(\n            32 if is_formatter else 0,\n            24 if is_formatter else 0,\n            32 if is_formatter else 0,\n            24 if is_formatter else 0,\n        )\n        self.settings_content_layout.setStretch(\n            self._formatter_layout_index, 1 if is_formatter else 0\n        )\n        self.settings_content_layout.setStretch(\n            self._bottom_stretch_index, 0 if is_formatter else 1\n        )''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        layout = QtWidgets.QVBoxLayout(panel)\n        layout.setContentsMargins(0, 0, 0, 0)\n        layout.setSpacing(12)''',
    '''        layout = QtWidgets.QVBoxLayout(panel)\n        layout.setContentsMargins(0, 0, 0, 16)\n        layout.setSpacing(12)''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        self.flag_table.setAlternatingRowColors(True)\n        self._flag_controls = {}\n        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left")),\n                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),\n                  (VERIBLE_BOOL_PARAMS, ("true", "false")),''',
    '''        self.flag_table.setAlternatingRowColors(True)\n        self.flag_table.setVerticalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)\n        self.flag_table.setHorizontalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)\n        self.flag_table.setSizeAdjustPolicy(QtWidgets.QAbstractScrollArea.AdjustIgnored)\n        self.flag_table.setMinimumHeight(240)\n        self._flag_controls = {}\n        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left", "preserve", "infer")),\n                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),\n                  (VERIBLE_BOOL_PARAMS, ("true", "false")),''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''                if choices:\n                    control = QtWidgets.QComboBox()\n                    control.addItem("工具默认值", "")\n                    for choice in choices:\n                        control.addItem(choice, choice)\n                    control.currentIndexChanged.connect(self._flags_changed)\n                else:\n                    control = QtWidgets.QLineEdit()\n                    if name in VERIBLE_INT_PARAMS:\n                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))\n                    control.textChanged.connect(self._flags_changed)''',
    '''                default_value = VERIBLE_BUILTIN_DEFAULTS.get(name, "")\n                if choices:\n                    control = QtWidgets.QComboBox()\n                    control.addItem(f"{default_value} (default)", "")\n                    for choice in choices:\n                        if choice != default_value:\n                            control.addItem(choice, choice)\n                    control.currentIndexChanged.connect(self._flags_changed)\n                else:\n                    control = QtWidgets.QLineEdit()\n                    if default_value:\n                        control.setPlaceholderText(f"{default_value} (default)")\n                    if name in VERIBLE_INT_PARAMS:\n                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))\n                    control.textChanged.connect(self._flags_changed)''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''            if isinstance(control, QtWidgets.QComboBox):\n                index = control.findData(value)\n                if index < 0:\n                    control.addItem(value, value)\n                    index = control.count() - 1\n                control.setCurrentIndex(index)''',
    '''            if isinstance(control, QtWidgets.QComboBox):\n                default_value = VERIBLE_BUILTIN_DEFAULTS.get(name, "")\n                if not value or value == default_value:\n                    index = 0\n                else:\n                    index = control.findData(value)\n                    if index < 0:\n                        control.addItem(value, value)\n                        index = control.count() - 1\n                control.setCurrentIndex(index)''',
)

# Add focused assertions + a visual capture of one real-default dropdown.
replace_once(
    "scripts/capture_ui.py",
    '''        w.placeholder_overlay.menu_buttons[idx].click()\n        page=w.placeholder_overlay\n        if name == "general":''',
    '''        w.placeholder_overlay.menu_buttons[idx].click()\n        page=w.placeholder_overlay\n        if name == "formatter":\n            assert page.settings_content_layout.getContentsMargins() == (32,24,32,24)\n            assert page.settings_content_layout.stretch(page._formatter_layout_index) == 1\n            assert page.settings_content_layout.stretch(page._bottom_stretch_index) == 0\n            align_control=page._flag_controls["assignment_statement_alignment"]\n            assert align_control.itemText(0) == "infer (default)"\n            assert align_control.itemData(0) == ""\n            assert [align_control.itemText(i) for i in range(1, align_control.count())] == [\n                "align", "flush-left", "preserve"\n            ]\n            indent_control=page._flag_controls["formal_parameters_indentation"]\n            assert indent_control.itemText(0) == "wrap (default)"\n            assert page.flag_table.verticalScrollMode() == QtWidgets.QAbstractItemView.ScrollPerPixel\n        if name == "general":''',
)
replace_once(
    "scripts/capture_ui.py",
    '''        if name == "appearance":\n            font_combo=w.findChild(QtWidgets.QComboBox,"SettingsFontFamily")''',
    '''        if name == "formatter":\n            align_control=page._flag_controls["assignment_statement_alignment"]\n            align_control.showPopup()\n            screen_shot("04-settings-formatter-defaults")\n            align_control.hidePopup()\n        if name == "appearance":\n            font_combo=w.findChild(QtWidgets.QComboBox,"SettingsFontFamily")''',
)

print("Formatter review fixes applied")
