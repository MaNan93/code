from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative, old, new):
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"anchor not found in {relative}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# One explicit PLM formatter preset is the single source of truth.
replace_once(
    "src/plm/core/verible.py",
    '''VERIBLE_STR_PARAMS = ("lines", "line_terminator", "stdin_name")  # free-form -- "lines" e.g. "3-5,10-12"\n\n# Built-in defaults reported by current verible-verilog-format --helpfull.\n# These are intentionally distinct from DEFAULT_VERIBLE_FLAGS below, which\n# is PLM's own formatting preset.  An empty UI value means "do not pass this\n# flag", so Verible uses the corresponding value from this mapping.\nVERIBLE_BUILTIN_DEFAULTS = {\n    **{name: "infer" for name in VERIBLE_ALIGN_PARAMS},\n    **{name: "wrap" for name in VERIBLE_INDENT_PARAMS},\n    "compact_indexing_and_selections": "true",\n    "expand_coverpoints": "false",\n    "port_declarations_right_align_packed_dimensions": "false",\n    "port_declarations_right_align_unpacked_dimensions": "false",\n    "try_wrap_long_lines": "false",\n    "wrap_end_else_clauses": "false",\n    "verify": "false",\n    "verify_convergence": "true",\n    "failsafe_success": "true",\n    "column_limit": "100",\n    "indentation_spaces": "2",\n    "line_break_penalty": "2",\n    "over_column_limit_penalty": "100",\n    "max_search_states": "100000",\n    "lines": "",\n    "line_terminator": "auto",\n    "stdin_name": "<stdin>",\n}\n\n# This project's own long-standing defaults (not verible's own out-of-the-box\n# defaults) -- unlisted params are simply never passed, so verible's own\n# built-in default applies. --inplace/stdin plumbing stays hardcoded below,\n# not exposed here (changing it would break the stdin-pipe invocation itself).\nDEFAULT_VERIBLE_FLAGS = {\n    "assignment_statement_alignment": "align",\n    "case_items_alignment": "align",\n    "distribution_items_alignment": "align",\n    "formal_parameters_alignment": "align",\n    "formal_parameters_indentation": "indent",\n    "named_parameter_alignment": "align",\n    "named_parameter_indentation": "indent",\n    "named_port_alignment": "align",\n    "named_port_indentation": "indent",\n    "port_declarations_alignment": "align",\n    "port_declarations_indentation": "indent",\n    "port_declarations_right_align_packed_dimensions": "true",\n    "struct_union_members_alignment": "align",\n    "wrap_end_else_clauses": "true",\n    "indentation_spaces": "4",\n    "column_limit": "120",\n}''',
    '''# Only user-facing formatting controls belong in the Settings table.\n# ``lines`` (partial formatting) and ``stdin_name`` (diagnostics only) are\n# invocation details and are intentionally not exposed by PLM.\nVERIBLE_STR_PARAMS = ("line_terminator",)\n\n# PLM's formatter preset.  Every parameter exposed by the UI has one explicit\n# value here; ``(default)`` in Settings always means this PLM preset, never a\n# second Verible-internal default system.  Values that were previously omitted\n# use Verible's effective defaults so existing generated formatting is stable.\nDEFAULT_VERIBLE_FLAGS = {\n    "assignment_statement_alignment": "align",\n    "case_items_alignment": "align",\n    "class_member_variable_alignment": "infer",\n    "distribution_items_alignment": "align",\n    "enum_assignment_statement_alignment": "infer",\n    "formal_parameters_alignment": "align",\n    "module_net_variable_alignment": "infer",\n    "named_parameter_alignment": "align",\n    "named_port_alignment": "align",\n    "port_declarations_alignment": "align",\n    "struct_union_members_alignment": "align",\n    "formal_parameters_indentation": "indent",\n    "named_parameter_indentation": "indent",\n    "named_port_indentation": "indent",\n    "port_declarations_indentation": "indent",\n    "compact_indexing_and_selections": "true",\n    "expand_coverpoints": "false",\n    "port_declarations_right_align_packed_dimensions": "true",\n    "port_declarations_right_align_unpacked_dimensions": "false",\n    "try_wrap_long_lines": "false",\n    "wrap_end_else_clauses": "true",\n    "verify": "false",\n    "verify_convergence": "true",\n    "failsafe_success": "true",\n    "column_limit": "120",\n    "indentation_spaces": "4",\n    "line_break_penalty": "2",\n    "over_column_limit_penalty": "100",\n    "max_search_states": "100000",\n    "line_terminator": "auto",\n}''',
)

# Formatter UI: PLM preset shown explicitly, no blank/default ambiguity.
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,\n    VERIBLE_BOOL_PARAMS, VERIBLE_BUILTIN_DEFAULTS, VERIBLE_INT_PARAMS,\n    VERIBLE_STR_PARAMS, find_verible,''',
    '''    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,\n    VERIBLE_BOOL_PARAMS, VERIBLE_INT_PARAMS, VERIBLE_STR_PARAMS, find_verible,''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '        self.flag_table.setHorizontalHeaderLabels(("参数", "值（空白使用 Verible 默认值）"))',
    '        self.flag_table.setHorizontalHeaderLabels(("参数", "值"))',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left", "preserve", "infer")),\n                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),\n                  (VERIBLE_BOOL_PARAMS, ("true", "false")),\n                  (VERIBLE_INT_PARAMS, None), (VERIBLE_STR_PARAMS, None))''',
    '''        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left", "preserve", "infer")),\n                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),\n                  (VERIBLE_BOOL_PARAMS, ("true", "false")),\n                  (VERIBLE_INT_PARAMS, None),\n                  (VERIBLE_STR_PARAMS, ("auto", "LF", "CR", "CRLF")))''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''                default_value = VERIBLE_BUILTIN_DEFAULTS.get(name, "")\n                if choices:\n                    control = QtWidgets.QComboBox()\n                    control.addItem(f"{default_value} (default)", "")\n                    for choice in choices:\n                        if choice != default_value:\n                            control.addItem(choice, choice)\n                    control.currentIndexChanged.connect(self._flags_changed)\n                else:\n                    control = QtWidgets.QLineEdit()\n                    if default_value:\n                        control.setPlaceholderText(f"{default_value} (default)")\n                    if name in VERIBLE_INT_PARAMS:\n                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))\n                    control.textChanged.connect(self._flags_changed)''',
    '''                default_value = DEFAULT_VERIBLE_FLAGS[name]\n                if choices:\n                    control = QtWidgets.QComboBox()\n                    control.addItem(f"{default_value} (default)", default_value)\n                    for choice in choices:\n                        if choice != default_value:\n                            control.addItem(choice, choice)\n                    control.setToolTip(f"PLM 默认值：{default_value}")\n                    control.currentIndexChanged.connect(self._flags_changed)\n                else:\n                    control = QtWidgets.QLineEdit()\n                    control.setToolTip(f"PLM 默认值：{default_value}")\n                    if name in VERIBLE_INT_PARAMS:\n                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))\n                    control.textChanged.connect(self._flags_changed)''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        buttons = QtWidgets.QHBoxLayout()\n        for label, flags in (("项目默认参数", None), ("使用 Verible 默认参数", {})):\n            button = QtWidgets.QPushButton(label)\n            button.setObjectName("SettingsSecondaryButton")\n            button.clicked.connect(lambda _checked=False, value=flags: self._fill_flags(value))\n            buttons.addWidget(button)\n        buttons.addStretch(1)\n        layout.addLayout(buttons)\n        self._fill_flags(preferences["verible_flags"])''',
    '''        buttons = QtWidgets.QHBoxLayout()\n        self.reset_formatter_btn = QtWidgets.QPushButton("恢复默认参数")\n        self.reset_formatter_btn.setObjectName("SettingsSecondaryButton")\n        self.reset_formatter_btn.clicked.connect(\n            lambda: self._fill_flags(DEFAULT_VERIBLE_FLAGS)\n        )\n        buttons.addWidget(self.reset_formatter_btn)\n        buttons.addStretch(1)\n        layout.addLayout(buttons)\n        self._fill_flags(preferences["verible_flags"])''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''    def _fill_flags(self, flags):\n        self._original_flags = flags\n        values = DEFAULT_VERIBLE_FLAGS if flags is None else flags\n        self._extra_flags = {key: value for key, value in values.items() if key not in self._flag_controls}\n        for name, control in self._flag_controls.items():\n            control.blockSignals(True)\n            value = "" if values.get(name) is None else str(values.get(name))\n            if isinstance(control, QtWidgets.QComboBox):\n                default_value = VERIBLE_BUILTIN_DEFAULTS.get(name, "")\n                if not value or value == default_value:\n                    index = 0\n                else:\n                    index = control.findData(value)\n                    if index < 0:\n                        control.addItem(value, value)\n                        index = control.count() - 1\n                control.setCurrentIndex(index)\n            else:\n                control.setText(value)\n            control.blockSignals(False)\n        self._flags_dirty = False\n\n    def _formatter_flags(self):\n        if not self._flags_dirty:\n            return self._original_flags\n        flags = dict(self._extra_flags)\n        for name, control in self._flag_controls.items():\n            value = control.currentData() if isinstance(control, QtWidgets.QComboBox) else control.text().strip()\n            if value:\n                flags[name] = value\n        return flags''',
    '''    def _fill_flags(self, flags):\n        values = dict(DEFAULT_VERIBLE_FLAGS)\n        if flags:\n            values.update({key: str(value) for key, value in flags.items() if key in values})\n        self._original_flags = dict(values)\n        for name, control in self._flag_controls.items():\n            control.blockSignals(True)\n            value = values[name]\n            if isinstance(control, QtWidgets.QComboBox):\n                index = control.findData(value)\n                if index < 0:\n                    control.addItem(value, value)\n                    index = control.count() - 1\n                control.setCurrentIndex(index)\n            else:\n                control.setText(value)\n            control.blockSignals(False)\n        self._flags_dirty = False\n\n    def _formatter_flags(self):\n        if not self._flags_dirty:\n            return dict(self._original_flags)\n        flags = {}\n        for name, control in self._flag_controls.items():\n            value = control.currentData() if isinstance(control, QtWidgets.QComboBox) else control.text().strip()\n            flags[name] = str(value)\n        return flags''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '        self._fill_flags(None)\n        self._save_settings()',
    '        self._fill_flags(DEFAULT_VERIBLE_FLAGS)\n        self._save_settings()',
)

# Update the Formatter integration test to the single-preset model.
replace_once(
    "tests/test_qt_generation.py",
    '''from plm.core.validation import ValidationError\nfrom plm.core.workspace import scaffold_default_content''',
    '''from plm.core.validation import ValidationError\nfrom plm.core.verible import DEFAULT_VERIBLE_FLAGS\nfrom plm.core.workspace import scaffold_default_content''',
)
replace_once(
    "tests/test_qt_generation.py",
    '''            page.font_size_spin.setValue(15)\n            self.assertEqual(page._preferences()["verible_flags"], flags)\n            page._fill_flags({})\n            self.assertEqual(page._preferences()["verible_flags"], {})\n            page._fill_flags(None)\n            self.assertIsNone(page._preferences()["verible_flags"])''',
    '''            page.font_size_spin.setValue(15)\n            expected = dict(DEFAULT_VERIBLE_FLAGS)\n            if flags:\n                expected.update(flags)\n            self.assertEqual(page._preferences()["verible_flags"], expected)\n            page._fill_flags({})\n            self.assertEqual(page._preferences()["verible_flags"], DEFAULT_VERIBLE_FLAGS)\n            page._fill_flags(None)\n            self.assertEqual(page._preferences()["verible_flags"], DEFAULT_VERIBLE_FLAGS)''',
)

# Visual assertions: default labels now mean PLM preset.
replace_once(
    "scripts/capture_ui.py",
    '''            align_control=page._flag_controls["assignment_statement_alignment"]\n            assert align_control.itemText(0) == "infer (default)"\n            assert align_control.itemData(0) == ""\n            assert [align_control.itemText(i) for i in range(1, align_control.count())] == [\n                "align", "flush-left", "preserve"\n            ]\n            indent_control=page._flag_controls["formal_parameters_indentation"]\n            assert indent_control.itemText(0) == "wrap (default)"\n            assert page.flag_table.verticalScrollMode() == QtWidgets.QAbstractItemView.ScrollPerPixel''',
    '''            align_control=page._flag_controls["assignment_statement_alignment"]\n            assert align_control.itemText(0) == "align (default)"\n            assert align_control.itemData(0) == "align"\n            assert [align_control.itemText(i) for i in range(1, align_control.count())] == [\n                "flush-left", "preserve", "infer"\n            ]\n            indent_control=page._flag_controls["formal_parameters_indentation"]\n            assert indent_control.itemText(0) == "indent (default)"\n            assert page._flag_controls["column_limit"].text() == "120"\n            assert page.flag_table.horizontalHeaderItem(1).text() == "值"\n            button_texts=[button.text() for button in page.formatter_panel.findChildren(QtWidgets.QPushButton)]\n            assert "恢复默认参数" in button_texts\n            assert "项目默认参数" not in button_texts\n            assert "使用 Verible 默认参数" not in button_texts\n            assert page.flag_table.verticalScrollMode() == QtWidgets.QAbstractItemView.ScrollPerPixel''',
)

print("Formatter preset cleanup applied")
