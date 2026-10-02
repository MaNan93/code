from PyQt5 import QtGui, QtWidgets
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR, DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from plm.frontend.qt.widgets.common import LUCIDE_ICON_DIR
from .secondary_page import SecondaryPage

class SettingsPage(SecondaryPage):
    def __init__(self, parent=None, preferences=None):
        self.initial_preferences = preferences or {
            "font_family": DEFAULT_FONT_FAMILY,
            "font_size": DEFAULT_FONT_SIZE,
            "editor_path": DEFAULT_EDITOR,
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
            titles = ("General", "Appearance", "Tools")
            descriptions = (
                "配置会保存在本机，并在下次启动时自动恢复。",
                "调整整个应用的字体与字号。",
                "设置从 Artifacts 面板打开文件时使用的编辑器。",
            )
            visible_rows = (
                {"font", "size", "editor"},
                {"font", "size"},
                {"editor"},
            )[index]
            self.heading_label.setText(titles[index])
            self.description_label.setText(descriptions[index])
            for name, row in self.setting_rows.items():
                row.setVisible(name in visible_rows)

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
        }

    def _save_settings(self):
        preferences = self._preferences()
        self.preferencesSaved.emit(preferences)
        self.settings_status.setText("设置已保存")

    def _reset_settings(self):
        self.font_family_combo.setCurrentFont(QtGui.QFont(DEFAULT_FONT_FAMILY))
        self.font_size_spin.setValue(DEFAULT_FONT_SIZE)
        self.editor_path_edit.setText(DEFAULT_EDITOR)
        self._save_settings()
