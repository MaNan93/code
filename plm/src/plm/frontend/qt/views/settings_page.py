import sys

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.core.verible import (
    DEFAULT_VERIBLE_FLAGS, VERIBLE_ALIGN_PARAMS, VERIBLE_INDENT_PARAMS,
    VERIBLE_BOOL_PARAMS, VERIBLE_INT_PARAMS, VERIBLE_STR_PARAMS, find_verible,
)
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.styles.tokens import (
    CONTROL_HEIGHT, FORMATTER_MAX_WIDTH, SPACING_LG, SPACING_MD,
)
from plm.frontend.qt.widgets.common import StyledComboBox
from .secondary_page import SecondaryPage


def _executable_filter():
    return "Executables (*.exe);;All files (*)" if sys.platform == "win32" else "All files (*)"


class _FormatterControlDelegate(QtWidgets.QStyledItemDelegate):
    def paint(self, painter, option, index):
        option = QtWidgets.QStyleOptionViewItem(option)
        option.state &= ~QtWidgets.QStyle.State_MouseOver
        super().paint(painter, option, index)

    def updateEditorGeometry(self, editor, option, index):
        super().updateEditorGeometry(editor, option, index)
        if isinstance(editor, (QtWidgets.QComboBox, QtWidgets.QLineEdit)):
            rect = editor.geometry()
            height = editor.minimumHeight()
            rect.setTop(option.rect.top() + (option.rect.height() - height) // 2)
            rect.setHeight(height)
            editor.setGeometry(rect)


class _FormatterTable(QtWidgets.QTableWidget):
    """Keep formatter rows at a fixed height."""

    ROW_HEIGHT = CONTROL_HEIGHT

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._row_height_timer = QtCore.QTimer(self)
        self._row_height_timer.setSingleShot(True)
        self._row_height_timer.timeout.connect(self.applyRowHeight)

    def scheduleRowHeight(self):
        if not self._row_height_timer.isActive():
            self._row_height_timer.start(0)

    def eventFilter(self, watched, event):
        if event.type() == QtCore.QEvent.FocusIn:
            row = watched.property("formatterRow")
            if row is not None:
                self.selectRow(int(row))
        return super().eventFilter(watched, event)

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
        self.scheduleRowHeight()


class SettingsPage(SecondaryPage):
    themeChanged = QtCore.pyqtSignal(str)

    def refresh_theme(self):
        from plm.frontend.qt.styles.tokens import get_active_theme
        previous = self.theme_combo.blockSignals(True)
        self.theme_combo.setCurrentIndex(self.theme_combo.findData(get_active_theme()))
        self.theme_combo.blockSignals(previous)

    def __init__(self, parent=None, preferences=None):
        self.initial_preferences = {
            "theme": "light",
            "editor_path": DEFAULT_EDITOR,
            "verible_path": "",
            "verible_flags": None,
            **(preferences or {}),
        }
        self.flag_table = None
        self._flag_controls = {}
        self._fill_flags(self.initial_preferences["verible_flags"])
        super().__init__("settings", parent)
        self._detection_started = False

    def showEvent(self, event):
        super().showEvent(event)
        if not self._detection_started:
            self._detection_started = True
            self._detect_verible()

    def _build_content(self):
        return self._build_settings_content()

    def _setting_row(self, label, control):
        row = QtWidgets.QFrame()
        row.setObjectName("SettingsRow")
        row.setFixedHeight(CONTROL_HEIGHT)
        row_layout = QtWidgets.QHBoxLayout(row)
        row_layout.setContentsMargins(16, 0, 16, 0)
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
        editor_control.setFixedSize(280, CONTROL_HEIGHT)
        editor_layout = QtWidgets.QHBoxLayout(editor_control)
        editor_layout.setContentsMargins(0, 0, 0, 0)
        editor_layout.setSpacing(8)
        self.editor_path_edit = QtWidgets.QLineEdit(
            preferences["editor_path"]
        )
        self.editor_path_edit.setObjectName("SettingsEditorPath")
        self.editor_path_edit.setFixedHeight(CONTROL_HEIGHT)
        browse_btn = QtWidgets.QPushButton("浏览…")
        browse_btn.setObjectName("SettingsBrowseButton")
        browse_btn.setMinimumWidth(68)
        browse_btn.clicked.connect(self._browse_editor)
        editor_layout.addWidget(self.editor_path_edit, 1, QtCore.Qt.AlignVCenter)
        editor_layout.addWidget(browse_btn, 0, QtCore.Qt.AlignVCenter)

        self.theme_combo = StyledComboBox()
        self.theme_combo.setObjectName("SettingsTheme")
        self.theme_combo.addItem("浅色", "light")
        self.theme_combo.addItem("深色", "dark")
        self.theme_combo.setCurrentIndex(max(0, self.theme_combo.findData(preferences["theme"])))
        self.theme_combo.currentIndexChanged.connect(
            lambda _index: self.themeChanged.emit(self.theme_combo.currentData())
        )
        self.setting_rows = {
            "theme": self._setting_row("界面主题", self.theme_combo),
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
        self.save_settings_btn.clicked.connect(self._save_settings)
        actions.addWidget(self.save_settings_btn)
        layout.addLayout(actions)
        self._bottom_stretch_index = layout.count()
        layout.addStretch(1)
        return content

    def _show_section(self, index):
        visible_rows = ({"theme", "editor"}, set())[index]
        for name, row in self.setting_rows.items():
            row.setVisible(name in visible_rows)
        is_formatter = index == 1
        if is_formatter:
            self._ensure_formatter_controls()
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
        # Share the tabs' left edge; the table uses the available height.
        self.settings_content_layout.setContentsMargins(
            0,
            0,
            0,
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
        panel.setMaximumWidth(FORMATTER_MAX_WIDTH)
        layout = QtWidgets.QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, SPACING_LG)
        layout.setSpacing(SPACING_MD)
        path_row = QtWidgets.QHBoxLayout()
        self.verible_path_edit = QtWidgets.QLineEdit(preferences["verible_path"])
        self.verible_path_edit.setPlaceholderText("留空自动搜索 verible-verilog-format")
        path_row.addWidget(self.verible_path_edit, 1)
        browse_button = QtWidgets.QPushButton("浏览…")
        browse_button.setObjectName("SettingsSecondaryButton")
        browse_button.clicked.connect(self._browse_verible)
        path_row.addWidget(browse_button)
        layout.addLayout(path_row)
        return panel

    def _ensure_formatter_controls(self):
        if self.flag_table is not None:
            return
        groups = ((VERIBLE_ALIGN_PARAMS, ("align", "flush-left", "preserve", "infer")),
                  (VERIBLE_INDENT_PARAMS, ("indent", "wrap")),
                  (VERIBLE_BOOL_PARAMS, ("true", "false")),
                  (VERIBLE_INT_PARAMS, None),
                  (VERIBLE_STR_PARAMS, ("auto", "LF", "CR", "CRLF")))
        self.flag_table = _FormatterTable(sum(len(params) for params, _ in groups), 2)
        self.flag_table.setUpdatesEnabled(False)
        self.flag_table.setObjectName("ConfigDataTable")
        self.flag_table.setProperty("formatterTable", True)
        self.flag_table.setShowGrid(False)
        self.flag_table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.flag_table.setItemDelegate(_FormatterControlDelegate(self.flag_table))
        self.flag_table.setHorizontalHeaderLabels(("参数", "值"))
        self.flag_table.horizontalHeader().setDefaultAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
        self.flag_table.verticalHeader().hide()
        rows = self.flag_table.verticalHeader()
        rows.setSectionResizeMode(QtWidgets.QHeaderView.Fixed)
        rows.setMinimumSectionSize(CONTROL_HEIGHT)
        rows.setMaximumSectionSize(CONTROL_HEIGHT)
        rows.setDefaultSectionSize(CONTROL_HEIGHT)
        formatter_header = self.flag_table.horizontalHeader()
        formatter_header.hide()
        formatter_header.setFixedHeight(CONTROL_HEIGHT)
        formatter_header.setSectionResizeMode(0, QtWidgets.QHeaderView.ResizeToContents)
        formatter_header.setSectionResizeMode(1, QtWidgets.QHeaderView.Fixed)
        self.flag_table.setAlternatingRowColors(True)
        self.flag_table.setVerticalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.flag_table.setHorizontalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.flag_table.setSizeAdjustPolicy(QtWidgets.QAbstractScrollArea.AdjustIgnored)
        self.flag_table.setMinimumHeight(240)
        row = 0
        for params, choices in groups:
            for name in params:
                item = QtWidgets.QTableWidgetItem(name)
                item.setFlags(item.flags() & ~QtCore.Qt.ItemIsEditable)
                self.flag_table.setItem(row, 0, item)
                value_item = QtWidgets.QTableWidgetItem()
                value_item.setFlags(value_item.flags() & ~QtCore.Qt.ItemIsEditable)
                self.flag_table.setItem(row, 1, value_item)
                default_value = DEFAULT_VERIBLE_FLAGS[name]
                if choices:
                    control = StyledComboBox()
                    control.setFixedHeight(CONTROL_HEIGHT - 4)
                    control.addItem(f"{default_value} (default)", default_value)
                    for choice in choices:
                        if choice != default_value:
                            control.addItem(choice, choice)
                    control.setToolTip(f"PLM 默认值：{default_value}")
                    control.currentIndexChanged.connect(self._flags_changed)
                else:
                    control = QtWidgets.QLineEdit()
                    control.setFixedHeight(CONTROL_HEIGHT - 4)
                    control.setToolTip(f"PLM 默认值：{default_value}")
                    if name in VERIBLE_INT_PARAMS:
                        control.setValidator(QtGui.QIntValidator(0, 2147483647, control))
                        control.setAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
                    control.textChanged.connect(self._flags_changed)
                control.setProperty("formatterRow", row)
                control.installEventFilter(self.flag_table)
                value_cell = QtWidgets.QWidget()
                value_cell.setObjectName("FormatterValueCell")
                value_layout = QtWidgets.QHBoxLayout(value_cell)
                value_layout.setContentsMargins(0, 2, 0, 2)
                value_layout.addWidget(control)
                self.flag_table.setCellWidget(row, 1, value_cell)
                self._flag_controls[name] = control
                row += 1
        self.formatter_panel.layout().addWidget(self.flag_table, 1)
        self._fill_flags(self._original_flags)
        self.flag_table.applyRowHeight()
        formatter_header.setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeToContents)
        self.flag_table.setUpdatesEnabled(True)

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() in (QtCore.QEvent.FontChange, QtCore.QEvent.StyleChange) and self.flag_table is not None:
            self.flag_table.scheduleRowHeight()

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
        initial_path = self.verible_path_edit.text().strip()
        detecting_status = "正在检测 Verible…"

        def update_status(message):
            # Detection may finish after a save or validation error.
            if self.settings_status.text() == detecting_status:
                self.settings_status.setText(message)

        def finished(found):
            if self.verible_path_edit.text().strip() != initial_path:
                update_status("")
                return
            if found:
                self.verible_path_edit.setText(found)
            update_status("" if found else "未找到 Verible，可手动选择路径。")

        self.settings_status.setText(detecting_status)
        self.tasks.submit(lambda _progress: find_verible(initial_path or None), finished,
                          lambda error: update_status(f"检测失败：{error}"))

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
        if self.flag_table is None:
            validator = QtGui.QIntValidator(0, 2147483647)
            for name in VERIBLE_INT_PARAMS:
                value = self._original_flags[name]
                if value.strip() and validator.validate(value, 0)[0] != QtGui.QValidator.Acceptable:
                    self._select_section(1)
                    break
        for name in VERIBLE_INT_PARAMS:
            control = self._flag_controls.get(name)
            if control is None:
                continue
            if control.text().strip() and not control.hasAcceptableInput():
                self.settings_status.setText(f"{name} 必须是非负整数。")
                formatter_index = next((i for i, button in enumerate(self.menu_buttons)
                                        if button.text() == "工具"), 1)
                self._select_section(formatter_index)
                row = list(self._flag_controls).index(name)
                self.flag_table.scrollToItem(self.flag_table.item(row, 0))
                control.setFocus(QtCore.Qt.OtherFocusReason)
                control.selectAll()
                return
        preferences = self._preferences()
        self.preferencesSaved.emit(preferences)
        self.settings_status.setText("设置已保存")

