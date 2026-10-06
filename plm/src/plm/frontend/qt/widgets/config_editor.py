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
    PCLK_MODE_VALUES,
    SEL_MODE_VALUES,
)
from plm.frontend.qt.widgets.lanegrid import LaneGrid
from plm.frontend.qt.widgets.common import StatusBadge
from plm.frontend.qt.widgets.tables import EditableTable


LANE_COUNTS = (2, 4, 8, 16, 32)


class LaneCountCombo(QtWidgets.QComboBox):
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
            self.table = self.editor.table
            self.editor.set_columns(self.lane_count.value())
            self.editor.changed.connect(self.changed.emit)
            layout.addWidget(self.editor, 1)
            return

        specs = []
        for key in self._keys:
            spec = {"key": key, "heading": key}
            if key == "signal_type":
                spec.update(options=["perlane", "shared"], width=104)
            elif key == "direction":
                spec.update(options=["mac2phy", "phy2mac"], width=112)
            elif key == "width":
                spec["width"] = 64
            elif key == "safe_state":
                spec["width"] = 96
            elif key == "tie_off":
                spec["width"] = 72
            specs.append(spec)

        self.editor = EditableTable(
            specs,
            id_column="ctrl_id" if "ctrl_id" in self._keys else None,
        )
        self.table = self.editor.table
        self.editor.changed.connect(self.changed.emit)
        layout.addWidget(self.editor, 1)

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
        layout = QtWidgets.QFormLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        self.arch = QtWidgets.QComboBox()
        self.arch.addItems(ARCH_VALUES)
        self.pclk_mode = QtWidgets.QComboBox()
        self.pclk_mode.addItems(PCLK_MODE_VALUES)
        # PCLK direction is a property of the selected PHY architecture, not
        # an independent generation choice.
        self.pclk_mode.setEnabled(False)
        self.pclk_mode.setToolTip("PCLK 模式由 PHY 架构自动决定。")
        self.sel_mode = QtWidgets.QComboBox()
        self.sel_mode.addItems(SEL_MODE_VALUES)
        self.dpr = QtWidgets.QCheckBox("启用 DPR")
        layout.addRow("PHY 架构", self.arch)
        layout.addRow("PCLK 模式", self.pclk_mode)
        layout.addRow("选择方式", self.sel_mode)
        layout.addRow("DPR", self.dpr)
        self.generate_btn = QtWidgets.QPushButton("Generate")
        self.generate_btn.setObjectName("ConfigGenerateButton")
        self.generate_btn.clicked.connect(self.generateRequested.emit)
        actions = QtWidgets.QHBoxLayout()
        self.status_label = StatusBadge("请选择项目")
        self.status_label.setObjectName("GenerationStatus")
        actions.addWidget(
            self.status_label, 0, QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
        )
        actions.addStretch(1)
        actions.addWidget(self.generate_btn)
        layout.addRow("", actions)
        self.arch.currentIndexChanged.connect(self._sync_pclk)
        for control in (self.arch, self.pclk_mode, self.sel_mode):
            control.currentIndexChanged.connect(self.changed.emit)
        self.dpr.toggled.connect(self._sync_dpr)

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

    def _sync_dpr(self, enabled):
        if enabled:
            self.sel_mode.blockSignals(True)
            self._set_combo_value(self.sel_mode, "sync")
            self.sel_mode.blockSignals(False)
        self.sel_mode.setEnabled(not enabled)
        self.sel_mode.setToolTip("DPR 需要 sync 选择方式。" if enabled else "")
        self.changed.emit()

    def _sync_pclk(self, _index):
        target = ARCH_PCLK_MODE.get(self.arch.currentText())
        if target is None:
            return
        self.pclk_mode.blockSignals(True)
        self._set_combo_value(self.pclk_mode, target)
        self.pclk_mode.blockSignals(False)

    def set_flags(self, flags):
        for widget in (self.arch, self.pclk_mode, self.sel_mode, self.dpr):
            widget.blockSignals(True)
        arch = flags.get("arch") or (
            "serdes" if flags.get("pclk-mode") == "pclk_as_phy_input" else "original_pipe"
        )
        self._set_combo_value(self.arch, arch)
        pclk_mode = flags.get("pclk-mode") or ARCH_PCLK_MODE.get(arch)
        if pclk_mode:
            self._set_combo_value(self.pclk_mode, pclk_mode)
        self._set_combo_value(self.sel_mode, flags.get("sel-mode") or "sync")
        self.dpr.setChecked(bool(flags.get("dpr")))
        self.sel_mode.setEnabled(not self.dpr.isChecked())
        self.sel_mode.setToolTip("DPR 需要 sync 选择方式。" if self.dpr.isChecked() else "")
        for widget in (self.arch, self.pclk_mode, self.sel_mode, self.dpr):
            widget.blockSignals(False)

    def flags(self):
        return {
            "arch": self.arch.currentText(),
            "pclk-mode": self.pclk_mode.currentText(),
            "sel-mode": self.sel_mode.currentText(),
            "dpr": self.dpr.isChecked(),
        }
