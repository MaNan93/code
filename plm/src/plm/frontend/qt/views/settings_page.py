import sys

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.core.verible import (
    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,
    VERIBLE_BOOL_PARAMS, VERIBLE_INT_PARAMS, VERIBLE_STR_PARAMS, find_verible,
)
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.styles.tokens import SPACING_MD
from .secondary_page import SecondaryPage


def _executable_filter():
    return "Executables (*.exe);;All files (*)" if sys.platform == "win32" else "All files (*)"


class _FormatterControlDelegate(QtWidgets.QStyledItemDelegate):
    def updateEditorGeometry(self, editor, option, index):
        super().updateEditorGeometry(editor, option, index)
        if isinstance(editor, QtWidgets.QComboBox):
            rect = editor.geometry()
            height = editor.minimumHeight()
            rect.setTop(option.rect.top() + (option.rect.height() - height) // 2)
            rect.setHeight(height)
            editor.setGeometry(rect)


class _FormatterTable(QtWidgets.QTableWidget):
    """Keep formatter rows at a fixed height."""

    ROW_HEIGHT = 40

    def sizeHintForColumn(self, column):
        width = super().sizeHintForColumn(column)
        if column == 1:
            for row in range(self.rowCount()):
                control = self.cellWidget(row, column)
                if control is not None:
                    width = max(width, control.sizeHint().width() + 2 * SPACING_MD + 1)
        return width

    def sizeHintForRow(self, row):
        return self.ROW_HEIGHT

    def applyRowHeight(self):
        for row in range(self.rowCount()):
            self.setRowHeight(row, self.sizeHintForRow(row))

    def showEvent(self, event):
        super().showEvent(event)
        QtCore.QTimer.singleShot(0, self.applyRowHeight)


class SettingsPage(SecondaryPage):
    def __init__(self, parent=None, preferences=None):
        self.initial_preferences = {
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
        row.setObjectName("SettingsRow")
        row.setFixedHeight(56)
        row_layout = QtWidgets.QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        key_label = QtWidgets.QLabel(label)
        key_label.setObjectName("SettingsRowLabel")
        row_layout.addWidget(key_label)
        row_layout.addStretch(1)
        row_layout.addWidget(control, 0, QtCore.Qt.AlignVCenter)
        return row

    def _build_settings_content(self):
        content = QtWidgets.QWidget()
        content.setObjectName("SecondaryContent")
        layout = QtWidgets.QVBoxLayout(content)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        self.settings_content_layout = layout
        preferences = self.initial_preferences

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
        editor_layout.addWidget(self.editor_path_edit, 1, QtCore.Qt.AlignVCenter)
        editor_layout.addWidget(browse_btn, 0, QtCore.Qt.AlignVCenter)

        self.setting_rows = {
            "editor": self._setting_row("默认编辑器", editor_control),
        }
        rows_layout = QtWidgets.QVBoxLayout()
        rows_layout.setContentsMargins(0, 0, 0, 0)
        rows_layout.setSpacing(0)
        for row in self.setting_rows.values():
            rows_layout.addWidget(row)
        layout.addLayout(rows_layout)
        self.general_rows_spacing = QtWidgets.QSpacerItem(
            0, 24, QtWidgets.QSizePolicy.Minimum, QtWidgets.QSizePolicy.Fixed
        )
        layout.addItem(self.general_rows_spacing)
        self.formatter_panel = self._build_formatter(preferences)
        self._formatter_layout_index = layout.count()
        layout.addWidget(self.formatter_panel, 1)

        actions = QtWidgets.QHBoxLayout()
        actions.setSpacing(12)
        self.settings_status = QtWidgets.QLabel("")
        self.settings_status.setObjectName("SettingsStatus")
        actions.addWidget(self.settings_status)
        actions.addStretch(1)
        self.save_settings_btn = QtWidgets.QPushButton("保存设置")
        self.save_settings_btn.setObjectName("SettingsPrimaryButton")
        self.save_settings_btn.setFixedHeight(36)
        self.save_settings_btn.clicked.connect(self._save_settings)
        actions.addWidget(self.save_settings_btn)
        layout.addLayout(actions)
        self._bottom_stretch_index = layout.count()
        layout.addStretch(1)
        return content

    def _show_section(self, index):
        visible_rows = ({"editor"}, set())[index]
        for name, row in self.setting_rows.items():
            row.setVisible(name in visible_rows)
        is_formatter = index == 1
        self.formatter_panel.setVisible(is_formatter)
        self.general_rows_spacing.changeSize(
            0, 0 if is_formatter else 24,
            QtWidgets.QSizePolicy.Minimum, QtWidgets.QSizePolicy.Fixed,
        )
        self.content_top_spacing.changeSize(
            0, 12 if is_formatter else 24,
            QtWidgets.QSizePolicy.Minimum, QtWidgets.QSizePolicy.Fixed,
        )
        self.page_panel.layout().invalidate()
        # Formatter uses the whole content column: top aligned, 32 px side
        # padding / 24 px bottom padding, with its table taking all spare
        # height and the global actions pinned to the bottom.  Other Settings
        # tabs retain their existing margins and stretch behavior.
        self.settings_content_layout.setContentsMargins(
            32 if is_formatter else 0,
            0,
            32 if is_formatter else 0,
            24 if is_formatter else 0,
        )
        self.settings_content_layout.setStretch(
            self._formatter_layout_index, 1 if is_formatter else 0
        )
        self.settings_content_layout.setStretch(
            self._bottom_stretch_index, 0 if is_formatter else 1
        )

    def _build_formatter(self, preferences):
        panel = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, 16)
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
        self.flag_table = _FormatterTable(0, 2)
        self.flag_table.setObjectName("ConfigDataTable")
        self.flag_table.setProperty("formatterTable", True)
        self.flag_table.setShowGrid(False)
        self.flag_table.setItemDelegate(_FormatterControlDelegate(self.flag_table))
        self.flag_table.setHorizontalHeaderLabels(("参数", "值"))
        self.flag_table.verticalHeader().hide()
        self.flag_table.verticalHeader().setDefaultSectionSize(40)
        formatter_header = self.flag_table.horizontalHeader()
        formatter_header.setSectionResizeMode(0, QtWidgets.QHeaderView.Stretch)
        formatter_header.setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeToContents)
        self.flag_table.setAlternatingRowColors(True)
        self.flag_table.setVerticalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.flag_table.setHorizontalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.flag_table.setSizeAdjustPolicy(QtWidgets.QAbstractScrollArea.AdjustIgnored)
        self.flag_table.setMinimumHeight(240)
        self._flag_controls = {}
        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left", "preserve", "infer")),
                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),
                  (VERIBLE_BOOL_PARAMS, ("true", "false")),
                  (VERIBLE_INT_PARAMS, None),
                  (VERIBLE_STR_PARAMS, ("auto", "LF", "CR", "CRLF")))
        for params, choices in groups:
            for name in params:
                row = self.flag_table.rowCount()
                self.flag_table.insertRow(row)
                item = QtWidgets.QTableWidgetItem(name)
                item.setFlags(item.flags() & ~QtCore.Qt.ItemIsEditable)
                self.flag_table.setItem(row, 0, item)
                default_value = DEFAULT_VERIBLE_FLAGS[name]
                if choices:
                    control = QtWidgets.QComboBox()
                    control.setMinimumHeight(36)
                    control.addItem(f"{default_value} (default)", default_value)
                    for choice in choices:
                        if choice != default_value:
                            control.addItem(choice, choice)
                    control.setToolTip(f"PLM 默认值：{default_value}")
                    control.currentIndexChanged.connect(self._flags_changed)
                else:
                    control = QtWidgets.QLineEdit()
                    control.setMinimumHeight(36)
                    control.setToolTip(f"PLM 默认值：{default_value}")
                    if name in VERIBLE_INT_PARAMS:
                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))
                    control.textChanged.connect(self._flags_changed)
                self.flag_table.setCellWidget(row, 1, control)
                self._flag_controls[name] = control
        layout.addWidget(self.flag_table, 1)
        self._fill_flags(preferences["verible_flags"])
        self.flag_table.applyRowHeight()
        return panel

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() in (QtCore.QEvent.FontChange, QtCore.QEvent.StyleChange) and hasattr(self, "flag_table"):
            QtCore.QTimer.singleShot(0, self.flag_table.applyRowHeight)

    def _flags_changed(self, *_):
        self._flags_dirty = True

    def _fill_flags(self, flags):
        values = dict(DEFAULT_VERIBLE_FLAGS)
        if flags:
            values.update({key: str(value) for key, value in flags.items() if key in values})
        self._original_flags = dict(values)
        for name, control in self._flag_controls.items():
            control.blockSignals(True)
            value = values[name]
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
            return dict(self._original_flags)
        flags = {}
        for name, control in self._flag_controls.items():
            value = control.currentData() if isinstance(control, QtWidgets.QComboBox) else control.text().strip()
            flags[name] = str(value)
        return flags

    def _browse_verible(self):
        path, _filter = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择 verible-verilog-format", self.verible_path_edit.text().strip(),
            _executable_filter(),
        )
        if path:
            self.verible_path_edit.setText(path)

    def _detect_verible(self):
        if not hasattr(self, "tasks"):
            self.tasks = TaskRunner(self)

        def finished(found):
            if found:
                self.verible_path_edit.setText(found)
            self.settings_status.setText("已检测到 Verible" if found else "未找到 Verible，可手动选择路径。")

        self.settings_status.setText("正在检测 Verible…")
        self.tasks.submit(lambda _progress: find_verible(), finished,
                          lambda error: self.settings_status.setText(f"检测失败：{error}"))

    def _browse_editor(self):
        path, _selected_filter = QtWidgets.QFileDialog.getOpenFileName(
            self,
            "选择默认编辑器",
            self.editor_path_edit.text().strip(),
            _executable_filter(),
        )
        if path:
            self.editor_path_edit.setText(path)

    def _preferences(self):
        return {
            "editor_path": self.editor_path_edit.text().strip() or DEFAULT_EDITOR,
            "verible_path": self.verible_path_edit.text().strip(),
            "verible_flags": self._formatter_flags(),
        }

    def _save_settings(self):
        for name in VERIBLE_INT_PARAMS:
            control = self._flag_controls[name]
            if control.text().strip() and not control.hasAcceptableInput():
                self.settings_status.setText(f"{name} 必须是非负整数。")
                formatter_index = next((i for i, button in enumerate(self.menu_buttons)
                                        if button.text() == "Formatter"), 1)
                self._select_section(formatter_index)
                row = list(self._flag_controls).index(name)
                self.flag_table.scrollToItem(self.flag_table.item(row, 0))
                control.setFocus(QtCore.Qt.OtherFocusReason)
                control.selectAll()
                return
        preferences = self._preferences()
        self.preferencesSaved.emit(preferences)
        self.settings_status.setText("设置已保存")

