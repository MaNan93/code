"""Configuration editors used by the refactored ConfigPage.

The table and lane-mapping interactions intentionally reuse the original
main-branch EditableTable and LaneGrid behavior: row drag/reorder, row context
menus, controller swatches and paint-drag lane assignment.  This module keeps
the small API expected by the refactored view/controller layer.
"""

from PyQt5 import QtCore, QtWidgets

from plm.core.gen_flags import (
    ARCH_PCLK_MODE,
    ARCH_VALUES,
    BUS_TYPE_VALUES,
    PCLK_MODE_VALUES,
)
from plm.frontend.qt.widgets.lanegrid import LaneGrid
from plm.frontend.qt.widgets.common import StatusBadge, StyledComboBox
from plm.frontend.qt.widgets.tables import EditableTable
from plm.frontend.qt.styles.tokens import (
    FORM_ACTION_WIDTH, FORM_FIELD_MAX_WIDTH, FORM_MAX_WIDTH, SPACING_MD, SPACING_XL,
)


LANE_COUNTS = (2, 4, 8, 16, 32)
TABLE_VISIBLE_ROWS = 10


class LaneCountCombo(StyledComboBox):
    """Product-mode lane picker with QSpinBox-compatible value helpers."""

    def value(self):
        try:
            return max(1, int(self.currentText().lstrip("xX")))
        except ValueError:
            return 1

    def setValue(self, value):
        value = max(1, int(value))
        label = f"x{value}"
        if self.findText(label) < 0:
            self.addItem(label)
        self.setCurrentText(label)


class CsvTableEditor(QtWidgets.QWidget):
    """Config-table facade shared by CSV-backed editor pages."""

    changed = QtCore.pyqtSignal()

    def __init__(self, columns, mapping=False, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigCsvEditor")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.mapping = mapping
        self._keys = tuple(columns)
        self._controllers = []

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(10)

        if mapping:
            controls = QtWidgets.QHBoxLayout()
            controls.addWidget(QtWidgets.QLabel("Num of Lanes"))
            self.lane_count = LaneCountCombo()
            self.lane_count.setObjectName("LaneCount")
            self.lane_count.addItems([f"x{value}" for value in LANE_COUNTS])
            self.lane_count.setCurrentText(f"x{max(1, len(columns) - 1)}")
            self.lane_count.currentTextChanged.connect(self._change_lane_count)
            controls.addWidget(self.lane_count)
            controls.addStretch(1)
            layout.addLayout(controls)

            self.editor = LaneGrid()
            self.editor.layout().removeWidget(self.editor.palette_bar)
            controls.takeAt(2)
            controls.addSpacing(SPACING_MD)
            controls.addWidget(self.editor.palette_bar, 1)
            self.table = self.editor.table
            self.editor.set_columns(self.lane_count.value())
            self.editor.changed.connect(self.changed.emit)
            self._setup_table_layout(layout)
            return

        specs = []
        headings = {"ctrl_id": "编号", "ctrl_name": "控制器名称", "max_width": "最大通道数",
                    "signal_name": "信号名称", "signal_type": "类型", "direction": "方向",
                    "width": "位宽", "safe_state": "安全值", "tie_off": "Tie-off"}
        for key in self._keys:
            spec = {"key": key, "heading": headings.get(key, key)}
            if key in ("ctrl_id", "max_width"):
                spec["alignment"] = QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
            elif key == "ctrl_name":
                spec["alignment"] = QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
            elif key == "signal_name":
                spec.update(min_width=256, alignment=QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
            elif key == "signal_type":
                spec.update(options=["perlane", "shared"], switch=True, width=112)
            elif key == "direction":
                spec.update(options=["mac2phy", "phy2mac"], switch=True, width=120)
            elif key == "width":
                spec["width"] = 64
                spec["alignment"] = QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter
            elif key == "safe_state":
                spec["width"] = 96
            elif key == "tie_off":
                spec["width"] = 72
            if key in ("safe_state", "tie_off"):
                spec["alignment"] = QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter
            specs.append(spec)

        self.editor = EditableTable(
            specs,
            id_column="ctrl_id" if "ctrl_id" in self._keys else None,
            equal_columns="ctrl_id" in self._keys,
        )
        if "ctrl_id" in self._keys:
            self.setMaximumWidth(800)
        self.table = self.editor.table
        self.editor.changed.connect(self.changed.emit)
        self._setup_table_layout(layout)

    def _setup_table_layout(self, layout):
        """Let tables fill the editor width and share a content-based height."""
        self.table.setMouseTracking(True)
        self.table.setShowGrid(True)
        self.table.setGridStyle(QtCore.Qt.SolidLine)
        layout.addWidget(self.editor)
        layout.addStretch(1)
        self.table.model().rowsInserted.connect(self._update_table_height)
        self.table.model().rowsRemoved.connect(self._update_table_height)
        self.table.verticalHeader().sectionResized.connect(self._update_table_height)
        self.table.horizontalHeader().geometriesChanged.connect(self._update_table_height)
        self.table.horizontalScrollBar().rangeChanged.connect(self._update_table_height)
        self._update_table_height()

    def _update_table_height(self, *_args):
        # Wrap short tables; long tables retain their native vertical scrollbar.
        visible_rows = min(self.table.rowCount(), TABLE_VISIBLE_ROWS)
        body_height = sum(self.table.rowHeight(row) for row in range(visible_rows))
        if not visible_rows:
            body_height = self.table.verticalHeader().defaultSectionSize()
        height = self.table.horizontalHeader().height() + body_height
        height += 2 * self.table.frameWidth()
        if self.table.horizontalScrollBar().maximum() > 0:
            height += self.table.horizontalScrollBar().sizeHint().height()
        # Allow the table to shrink with its page; its own scrollbar handles overflow.
        self.table.setProperty("contentHeight", height)
        self.table.setMaximumHeight(height)
        self.table.updateGeometry()

    @property
    def controllers(self):
        return list(self._controllers)

    @controllers.setter
    def controllers(self, rows):
        self._controllers = [dict(row) for row in (rows or [])]
        if self.mapping:
            self.editor.set_controllers(self._controllers)

    def columns(self):
        if self.mapping:
            return ["mode"] + [
                f"lane{index}" for index in range(self.editor.lane_count)
            ]
        return list(self._keys)

    def rows(self):
        return self.editor.get_rows()

    def set_rows(self, rows, columns=None):
        if not self.mapping:
            self.editor.set_rows(rows)
            return

        count = len(columns) - 1 if columns is not None else self.lane_count.value()
        self.lane_count.blockSignals(True)
        self.lane_count.clear()
        labels = [f"x{value}" for value in LANE_COUNTS]
        label = f"x{count}"
        if label not in labels:
            labels.append(label)
        self.lane_count.addItems(labels)
        self.lane_count.setCurrentText(label)
        self.lane_count.blockSignals(False)
        self.editor.set_columns(count)
        normalized = []
        for source in rows or []:
            row = {"mode": str(source.get("mode", ""))}
            for lane in range(count):
                row[f"lane{lane}"] = str(source.get(f"lane{lane}", ""))
            normalized.append(row)
        self.editor.set_rows(normalized)
        self.editor.set_controllers(self._controllers)

    def _change_lane_count(self, text):
        if not self.mapping:
            return
        try:
            count = int(text.lstrip("xX"))
        except ValueError:
            return
        if count < 1:
            return
        rows = []
        for source in self.editor.get_rows():
            row = {"mode": source.get("mode", "")}
            for lane in range(count):
                row[f"lane{lane}"] = source.get(f"lane{lane}", "0-0")
            rows.append(row)
        self.editor.set_columns(count)
        self.editor.set_rows(rows)
        self.changed.emit()

    def set_cell_errors(self, errors):
        if self.mapping:
            self.editor.set_cell_errors(errors)
            return
        translated = {}
        for (row, column), message in (errors or {}).items():
            key = self._keys[column] if isinstance(column, int) else column
            translated[(row, key)] = message
        self.editor.set_cell_errors(translated)

    # Small public helper used by tests and programmatic row insertion.
    def add_row(self):
        if self.mapping:
            self.editor._insert_row_below(len(self.editor.data) - 1)
        else:
            self.editor.insert_row_below(self.table.rowCount() - 1)


class GenerationEditor(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()
    generateRequested = QtCore.pyqtSignal()
    _UNKNOWN_VALUE_ROLE = QtCore.Qt.UserRole + 17

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMaximumWidth(FORM_MAX_WIDTH)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(SPACING_MD)
        self.architecture_card = QtWidgets.QGroupBox("硬件与架构")
        self.architecture_card.setObjectName("FormCard")
        architecture = QtWidgets.QFormLayout(self.architecture_card)
        architecture.setFormAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)
        architecture.setSpacing(SPACING_MD)
        architecture.setContentsMargins(16, 24, 16, 16)
        architecture.setFieldGrowthPolicy(QtWidgets.QFormLayout.AllNonFixedFieldsGrow)
        architecture.setRowWrapPolicy(QtWidgets.QFormLayout.WrapLongRows)
        layout.addWidget(self.architecture_card)
        self.arch = StyledComboBox()
        self.arch.addItems(ARCH_VALUES)
        self.pclk_mode = StyledComboBox()
        self.pclk_mode.addItems(PCLK_MODE_VALUES)
        # PCLK direction is a property of the selected PHY architecture, not
        # an independent generation choice.
        self.pclk_mode.setEnabled(False)
        self.pclk_mode.setToolTip("PCLK 模式由 PHY 架构自动决定。")
        self.bus_type = StyledComboBox()
        self.bus_type.addItems(BUS_TYPE_VALUES)
        self.bus_type.setCurrentText("bus")
        self.bus_type.setToolTip("flat：一维向量；bus：二维 lane 数组。")
        for control in (self.arch, self.pclk_mode, self.bus_type):
            control.setMaximumWidth(FORM_FIELD_MAX_WIDTH)
        self.dpr = QtWidgets.QCheckBox("启用 DPR")
        self.dpr.setToolTip("启用后选择信号经同步器（sync）；不启用为组合直通（comb）。")
        architecture.addRow("PHY 架构", self.arch)
        architecture.addRow("PCLK 模式", self.pclk_mode)
        architecture.addRow("Connection 总线类型", self.bus_type)
        architecture.addRow("DPR", self.dpr)
        for row in range(architecture.rowCount()):
            architecture.itemAt(row, QtWidgets.QFormLayout.LabelRole).widget().setMinimumWidth(120)
        self.naming_card = QtWidgets.QGroupBox("模块与命名")
        self.naming_card.setObjectName("FormCard")
        naming = QtWidgets.QFormLayout(self.naming_card)
        naming.setFormAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignTop)
        naming.setSpacing(SPACING_MD)
        naming.setContentsMargins(16, 24, 16, 16)
        naming.setFieldGrowthPolicy(QtWidgets.QFormLayout.AllNonFixedFieldsGrow)
        naming.setRowWrapPolicy(QtWidgets.QFormLayout.WrapLongRows)
        layout.addWidget(self.naming_card)
        self._prefix_edits = {}
        for name, label, description, example in (
            ("module_prefix", "模块名前缀", "模块和 package 名称前缀", "soc_"),
            ("file_prefix", "文件名前缀", "所有 .sv 文件名称前缀", "rtl_"),
            ("macro_prefix", "宏名前缀", "宏名称前缀", "SOC_"),
        ):
            edit = QtWidgets.QLineEdit()
            edit.setObjectName(name)
            edit.setAccessibleName(name)
            edit.setMaximumWidth(FORM_FIELD_MAX_WIDTH)
            edit.setPlaceholderText(description)
            edit.setToolTip(f"自动补齐末尾下划线，例如 {example.rstrip('_')} → {example}；已有 _ 不重复添加，留空保持原名称。")
            edit.textChanged.connect(self.changed.emit)
            self._prefix_edits[name] = edit
            setattr(self, name, edit)
            naming.addRow(label, edit)
            naming.labelForField(edit).setMinimumWidth(120)
        self.generate_btn = QtWidgets.QPushButton("生成 RTL / TB")
        self.generate_btn.setObjectName("ConfigGenerateButton")
        self.generate_btn.setFixedWidth(FORM_ACTION_WIDTH)
        self.generate_btn.clicked.connect(self.generateRequested.emit)
        # Not a form row: the page pins this bar below the scrolled form, so
        # the primary action stays visible at any window height.
        self.footer = QtWidgets.QWidget()
        self.footer.setObjectName("GenerationFooter")
        actions = QtWidgets.QHBoxLayout(self.footer)
        actions.setContentsMargins(0, SPACING_XL, 0, 0)
        self.status_label = StatusBadge("请选择项目")
        self.status_label.setObjectName("GenerationStatus")
        # Left-aligned: the artifacts drawer slides in over the right edge.
        actions.setSpacing(SPACING_MD)
        actions.addWidget(self.generate_btn)
        actions.addWidget(
            self.status_label, 0, QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
        )
        actions.addStretch(1)
        self.arch.currentIndexChanged.connect(self._sync_pclk)
        for control in (self.arch, self.pclk_mode, self.bus_type):
            control.currentIndexChanged.connect(self.changed.emit)
        self.dpr.toggled.connect(lambda _enabled: self.changed.emit())
        self._label_timer = QtCore.QTimer(self)
        self._label_timer.setSingleShot(True)
        self._label_timer.timeout.connect(self._align_form_labels)
        self._label_timer.start(0)

    def _align_form_labels(self):
        labels = []
        for card in (self.architecture_card, self.naming_card):
            form = card.layout()
            labels.extend(form.itemAt(row, QtWidgets.QFormLayout.LabelRole).widget()
                          for row in range(form.rowCount()))
        width = max(label.fontMetrics().horizontalAdvance(label.text()) for label in labels)
        for label in labels:
            label.setMinimumWidth(width)

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() in (QtCore.QEvent.FontChange, QtCore.QEvent.StyleChange) and hasattr(self, "_label_timer"):
            self._label_timer.start(0)

    @classmethod
    def _set_combo_value(cls, combo, value):
        """Show an unknown loaded value instead of silently replacing it.

        Unknown items are transient: once a known value is loaded or chosen,
        stale unknown choices are removed from the combo again.
        """
        value = "" if value is None else str(value)
        for index in range(combo.count() - 1, -1, -1):
            if combo.itemData(index, cls._UNKNOWN_VALUE_ROLE):
                combo.removeItem(index)
        index = combo.findText(value)
        if index < 0 and value:
            combo.addItem(value)
            index = combo.count() - 1
            combo.setItemData(index, True, cls._UNKNOWN_VALUE_ROLE)
        if index >= 0:
            combo.setCurrentIndex(index)

    def set_output_state(self, state, text, detail=""):
        self.status_label.setText(text)
        self.status_label.setToolTip(detail)
        self.status_label.setProperty("state", state)
        self.status_label.style().unpolish(self.status_label)
        self.status_label.style().polish(self.status_label)
        self.generate_btn.setEnabled(state not in ("no_project", "generating"))

    def _sync_pclk(self, _index):
        target = ARCH_PCLK_MODE.get(self.arch.currentText())
        if target is None:
            return
        self.pclk_mode.blockSignals(True)
        self._set_combo_value(self.pclk_mode, target)
        self.pclk_mode.blockSignals(False)

    def set_flags(self, flags):
        controls = (self.arch, self.pclk_mode, self.bus_type, self.dpr,
                    *self._prefix_edits.values())
        for widget in controls:
            widget.blockSignals(True)
        arch = flags.get("arch") or (
            "serdes" if flags.get("pclk-mode") == "pclk_as_phy_input" else "original_pipe"
        )
        self._set_combo_value(self.arch, arch)
        pclk_mode = flags.get("pclk-mode") or ARCH_PCLK_MODE.get(arch)
        if pclk_mode:
            self._set_combo_value(self.pclk_mode, pclk_mode)
        self._set_combo_value(self.bus_type, flags.get("bus-type") or "bus")
        self.dpr.setChecked(bool(flags.get("dpr")))
        for name, edit in self._prefix_edits.items():
            edit.setText(flags.get(name) or "")
        for widget in controls:
            widget.blockSignals(False)

    def flags(self):
        flags = {
            "arch": self.arch.currentText(),
            "pclk-mode": self.pclk_mode.currentText(),
            "dpr": self.dpr.isChecked(),
            "bus-type": self.bus_type.currentText(),
        }
        flags.update({name: edit.text() for name, edit in self._prefix_edits.items() if edit.text()})
        return flags
