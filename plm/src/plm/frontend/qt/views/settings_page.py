from PyQt5 import QtCore, QtGui, QtWidgets
from plm.core.verible import (
    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,
    VERIBLE_BOOL_PARAMS, VERIBLE_INT_PARAMS, VERIBLE_STR_PARAMS, find_verible,
)
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR, DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from plm.frontend.qt.widgets.common import LUCIDE_ICON_DIR
from .secondary_page import SecondaryPage

class SettingsPage(SecondaryPage):
    def __init__(self, parent=None, preferences=None):
        self.initial_preferences = {
            "font_family": DEFAULT_FONT_FAMILY,
            "font_size": DEFAULT_FONT_SIZE,
            "editor_path": DEFAULT_EDITOR,
            "verible_path": "",
            "verible_flags": None,
            **(preferences or {}),
        }
        super().__init__("settings", parent)

    def _build_content(self):
        return self._build_settings_content()

    def _setting_row(self, label, control):
        row = QtWidgets.QFrame()
        row.setObjectName("PlaceholderSettingRow")
        row.setFixedHeight(56)
        row_layout = QtWidgets.QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        key_label = QtWidgets.QLabel(label)
        key_label.setObjectName("PlaceholderRowLabel")
        row_layout.addWidget(key_label)
        row_layout.addStretch(1)
        row_layout.addWidget(control)
        return row

    def _build_settings_content(self):
        content, layout = self._content_shell(
            "General", "配置会保存在本机，并在下次启动时自动恢复。"
        )
        preferences = self.initial_preferences

        self.font_family_combo = QtWidgets.QFontComboBox()
        self.font_family_combo.setObjectName("SettingsFontFamily")
        self.font_family_combo.setCurrentFont(
            QtGui.QFont(
                preferences["font_family"]
            )
        )
        self.font_family_combo.setFixedSize(280, 36)
        chevron_path = (LUCIDE_ICON_DIR / "chevron-down.svg").as_posix()
        self.font_family_combo.setStyleSheet(
            "QFontComboBox { border: 1px solid #E0E0E0; border-radius: 6px; }"
            "QComboBox::drop-down { border: none; width: 40px; }"
            f"QComboBox::down-arrow {{ image: url({chevron_path});"
            " width: 16px; height: 16px; }"
        )

        self.font_size_spin = QtWidgets.QSpinBox()
        self.font_size_spin.setObjectName("SettingsFontSize")
        self.font_size_spin.setRange(10, 20)
        self.font_size_spin.setButtonSymbols(QtWidgets.QAbstractSpinBox.NoButtons)
        self.font_size_spin.setValue(
            preferences["font_size"]
        )
        self.font_size_spin.setFixedSize(280, 36)

        editor_control = QtWidgets.QWidget()
        editor_control.setObjectName("SettingsEditorControl")
        editor_control.setFixedSize(280, 36)
        editor_layout = QtWidgets.QHBoxLayout(editor_control)
        editor_layout.setContentsMargins(0, 0, 0, 0)
        editor_layout.setSpacing(8)
        self.editor_path_edit = QtWidgets.QLineEdit(
            preferences["editor_path"]
        )
        self.editor_path_edit.setObjectName("SettingsEditorPath")
        self.editor_path_edit.setFixedHeight(36)
        browse_btn = QtWidgets.QPushButton("浏览…")
        browse_btn.setObjectName("SettingsBrowseButton")
        browse_btn.setFixedSize(68, 36)
        browse_btn.clicked.connect(self._browse_editor)
        editor_layout.addWidget(self.editor_path_edit)
        editor_layout.addWidget(browse_btn)

        self.setting_rows = {
            "font": self._setting_row("界面字体", self.font_family_combo),
            "size": self._setting_row("字体大小", self.font_size_spin),
            "editor": self._setting_row("默认编辑器", editor_control),
        }
        rows_layout = QtWidgets.QVBoxLayout()
        rows_layout.setContentsMargins(0, 0, 0, 0)
        rows_layout.setSpacing(0)
        for row in self.setting_rows.values():
            rows_layout.addWidget(row)
        layout.addLayout(rows_layout)
        layout.addSpacing(24)
        self.formatter_panel = self._build_formatter(preferences)
        layout.addWidget(self.formatter_panel, 1)

        actions = QtWidgets.QHBoxLayout()
        actions.setSpacing(12)
        self.settings_status = QtWidgets.QLabel("")
        self.settings_status.setObjectName("SettingsStatus")
        actions.addWidget(self.settings_status)
        actions.addStretch(1)
        reset_btn = QtWidgets.QPushButton("恢复默认")
        reset_btn.setObjectName("SettingsSecondaryButton")
        reset_btn.setFixedHeight(36)
        reset_btn.clicked.connect(self._reset_settings)
        self.save_settings_btn = QtWidgets.QPushButton("保存设置")
        self.save_settings_btn.setObjectName("SettingsPrimaryButton")
        self.save_settings_btn.setFixedHeight(36)
        self.save_settings_btn.clicked.connect(self._save_settings)
        actions.addWidget(reset_btn)
        actions.addWidget(self.save_settings_btn)
        layout.addLayout(actions)
        layout.addStretch(1)
        return content

    def _show_section(self, index):
        titles = ("General", "Appearance", "Tools", "Formatter")
        descriptions = (
            "配置会保存在本机，并在下次启动时自动恢复。",
            "调整整个应用的字体与字号。",
            "设置从预览面板打开文件时使用的编辑器。",
            "Verible 设置用于 RTL 和 Testbench 格式化，保存后会重新检查输出状态。",
        )
        visible_rows = ({"font", "size", "editor"}, {"font", "size"}, {"editor"}, set())[index]
        self.heading_label.setText(titles[index])
        self.description_label.setText(descriptions[index])
        for name, row in self.setting_rows.items():
            row.setVisible(name in visible_rows)
        self.formatter_panel.setVisible(index == 3)

    def _build_formatter(self, preferences):
        panel = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        path_row = QtWidgets.QHBoxLayout()
        self.verible_path_edit = QtWidgets.QLineEdit(preferences["verible_path"])
        self.verible_path_edit.setPlaceholderText("留空自动搜索 verible-verilog-format")
        path_row.addWidget(self.verible_path_edit, 1)
        for label, callback in (("浏览…", self._browse_verible), ("自动检测", self._detect_verible)):
            button = QtWidgets.QPushButton(label)
            button.setObjectName("SettingsSecondaryButton")
            button.clicked.connect(callback)
            path_row.addWidget(button)
        layout.addLayout(path_row)
        self.flag_table = QtWidgets.QTableWidget(0, 2)
        self.flag_table.setObjectName("ConfigDataTable")
        self.flag_table.setHorizontalHeaderLabels(("参数", "值（空白使用 Verible 默认值）"))
        self.flag_table.verticalHeader().hide()
        self.flag_table.horizontalHeader().setSectionResizeMode(0, QtWidgets.QHeaderView.Stretch)
        self.flag_table.horizontalHeader().setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeToContents)
        self.flag_table.setAlternatingRowColors(True)
        self._flag_controls = {}
        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left")),
                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),
                  (VERIBLE_BOOL_PARAMS, ("true", "false")),
                  (VERIBLE_INT_PARAMS, None), (VERIBLE_STR_PARAMS, None))
        for params, choices in groups:
            for name in params:
                row = self.flag_table.rowCount()
                self.flag_table.insertRow(row)
                item = QtWidgets.QTableWidgetItem(name)
                item.setFlags(item.flags() & ~QtCore.Qt.ItemIsEditable)
                self.flag_table.setItem(row, 0, item)
                if choices:
                    control = QtWidgets.QComboBox()
                    control.addItem("工具默认值", "")
                    for choice in choices:
                        control.addItem(choice, choice)
                    control.currentIndexChanged.connect(self._flags_changed)
                else:
                    control = QtWidgets.QLineEdit()
                    if name in VERIBLE_INT_PARAMS:
                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))
                    control.textChanged.connect(self._flags_changed)
                self.flag_table.setCellWidget(row, 1, control)
                self._flag_controls[name] = control
        layout.addWidget(self.flag_table, 1)
        buttons = QtWidgets.QHBoxLayout()
        for label, flags in (("项目默认参数", None), ("使用 Verible 默认参数", {})):
            button = QtWidgets.QPushButton(label)
            button.setObjectName("SettingsSecondaryButton")
            button.clicked.connect(lambda _checked=False, value=flags: self._fill_flags(value))
            buttons.addWidget(button)
        buttons.addStretch(1)
        layout.addLayout(buttons)
        self._fill_flags(preferences["verible_flags"])
        return panel

    def _flags_changed(self, *_):
        self._flags_dirty = True

    def _fill_flags(self, flags):
        self._original_flags = flags
        values = DEFAULT_VERIBLE_FLAGS if flags is None else flags
        self._extra_flags = {key: value for key, value in values.items() if key not in self._flag_controls}
        for name, control in self._flag_controls.items():
            control.blockSignals(True)
            value = "" if values.get(name) is None else str(values.get(name))
            if isinstance(control, QtWidgets.QComboBox):
                index = control.findData(value)
                if index < 0:
                    control.addItem(value, value)
                    index = control.count() - 1
                control.setCurrentIndex(index)
            else:
                control.setText(value)
            control.blockSignals(False)
        self._flags_dirty = False

    def _formatter_flags(self):
        if not self._flags_dirty:
            return self._original_flags
        flags = dict(self._extra_flags)
        for name, control in self._flag_controls.items():
            value = control.currentData() if isinstance(control, QtWidgets.QComboBox) else control.text().strip()
            if value:
                flags[name] = value
        return flags

    def _browse_verible(self):
        path, _filter = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择 verible-verilog-format", self.verible_path_edit.text().strip(),
            "Executables (*.exe);;All files (*)",
        )
        if path:
            self.verible_path_edit.setText(path)

    def _detect_verible(self):
        found = find_verible()
        if found:
            self.verible_path_edit.setText(found)
        self.settings_status.setText("已检测到 Verible" if found else "未找到 Verible，可手动选择路径。")

    def _browse_editor(self):
        path, _selected_filter = QtWidgets.QFileDialog.getOpenFileName(
            self,
            "选择默认编辑器",
            self.editor_path_edit.text().strip(),
            "Executables (*.exe);;All files (*)",
        )
        if path:
            self.editor_path_edit.setText(path)

    def _preferences(self):
        return {
            "font_family": self.font_family_combo.currentFont().family(),
            "font_size": self.font_size_spin.value(),
            "editor_path": self.editor_path_edit.text().strip() or DEFAULT_EDITOR,
            "verible_path": self.verible_path_edit.text().strip(),
            "verible_flags": self._formatter_flags(),
        }

    def _save_settings(self):
        for name in VERIBLE_INT_PARAMS:
            control = self._flag_controls[name]
            if control.text().strip() and not control.hasAcceptableInput():
                self.settings_status.setText(f"{name} 必须是非负整数。")
                return
        preferences = self._preferences()
        self.preferencesSaved.emit(preferences)
        self.settings_status.setText("设置已保存")

    def _reset_settings(self):
        self.font_family_combo.setCurrentFont(QtGui.QFont(DEFAULT_FONT_FAMILY))
        self.font_size_spin.setValue(DEFAULT_FONT_SIZE)
        self.editor_path_edit.setText(DEFAULT_EDITOR)
        self.verible_path_edit.clear()
        self._fill_flags(None)
        self._save_settings()
