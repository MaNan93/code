"""Configuration editors used by the refactored ConfigPage.

The table and lane-mapping interactions intentionally reuse the original
main-branch EditableTable and LaneGrid behavior: row drag/reorder, row context
menus, controller swatches and paint-drag lane assignment.  This module keeps
the small API expected by the refactored view/controller layer.
"""

from PyQt5 import QtCore, QtWidgets

from plm.core.gen_flags import ARCH_VALUES, PCLK_MODE_VALUES, SEL_MODE_VALUES
from plm.frontend.qt.widgets.lanegrid import LaneGrid
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
    """Compatibility facade over the original EditableTable/LaneGrid widgets."""

    changed = QtCore.pyqtSignal()

    def __init__(self, columns, mapping=False, parent=None):
        super().__init__(parent)
        self.mapping = mapping
        self._keys = tuple(columns)
        self._controllers = []
        self._context_menu = None

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
            # ConfigPage.finish_editing historically asks every table delegate
            # to finish editing. LaneGrid commits native item edits itself, so
            # a no-op keeps that API without altering the original behavior.
            delegate = self.table.itemDelegate()
            if not hasattr(delegate, "finish_editing"):
                delegate.finish_editing = lambda: None
            layout.addWidget(self.editor, 1)
            return

        specs = []
        for key in self._keys:
            spec = {"key": key, "heading": key}
            if key == "signal_type":
                spec.update(options=["perlane", "shared"], width=108)
            elif key == "direction":
                spec.update(options=["mac2phy", "phy2mac"], width=128)
            elif key == "width":
                spec["width"] = 66
            elif key == "safe_state":
                spec["width"] = 84
            elif key == "tie_off":
                spec["width"] = 66
            specs.append(spec)

        self.editor = EditableTable(
            specs,
            id_column="ctrl_id" if "ctrl_id" in self._keys else None,
        )
        self.table = self.editor.table
        self.editor.changed.connect(self.changed.emit)
        delegate = self.table.itemDelegate()
        if not hasattr(delegate, "finish_editing"):
            delegate.finish_editing = lambda: None
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

    # Compatibility helpers retained for tests and keyboard/menu callers.
    def add_row(self):
        if self.mapping:
            self.editor._insert_row_below(len(self.editor.data) - 1)
        else:
            self.editor.insert_row_below(self.table.rowCount() - 1)

    def delete_selected_rows(self):
        row = self.table.currentRow()
        if row < 0:
            return
        if self.mapping:
            self.editor._delete_row(row)
        else:
            self.editor.delete_row(row)

    def _build_row_context_menu(self, row):
        menu = QtWidgets.QMenu(self.table)
        if row >= 0:
            if self.mapping:
                insert_above = lambda: self.editor._insert_row_above(row)
                insert_below = lambda: self.editor._insert_row_below(row)
                delete_row = lambda: self.editor._delete_row(row)
                count = len(self.editor.data)
            else:
                insert_above = lambda: self.editor.insert_row_above(row)
                insert_below = lambda: self.editor.insert_row_below(row)
                delete_row = lambda: self.editor.delete_row(row)
                count = self.table.rowCount()
            menu.addAction("Insert row above", insert_above)
            menu.addAction("Insert row below", insert_below)
            menu.addSeparator()
            action = menu.addAction("Delete current row", delete_row)
            action.setEnabled(count > 1)
        else:
            menu.addAction("Insert row", self.add_row)
        return menu


class GenerationEditor(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()
    generateRequested = QtCore.pyqtSignal()

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
        self.generate_btn = QtWidgets.QPushButton("Generate RTL + TB")
        self.generate_btn.setObjectName("ConfigGenerateButton")
        self.generate_btn.clicked.connect(self.generateRequested.emit)
        actions = QtWidgets.QHBoxLayout()
        self.status_label = QtWidgets.QLabel("请选择项目")
        self.status_label.setObjectName("GenerationStatus")
        actions.addWidget(self.status_label, 1)
        actions.addWidget(self.generate_btn)
        layout.addRow("", actions)
        self.arch.currentIndexChanged.connect(self._sync_pclk)
        for control in (self.arch, self.pclk_mode, self.sel_mode):
            control.currentIndexChanged.connect(self.changed.emit)
        self.dpr.toggled.connect(self._sync_dpr)

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
            self.sel_mode.setCurrentText("sync")
            self.sel_mode.blockSignals(False)
        self.sel_mode.setEnabled(not enabled)
        self.sel_mode.setToolTip("DPR 需要 sync 选择方式。" if enabled else "")
        self.changed.emit()

    def _sync_pclk(self, index):
        self.pclk_mode.blockSignals(True)
        self.pclk_mode.setCurrentIndex(index)
        self.pclk_mode.blockSignals(False)

    def set_flags(self, flags):
        for widget in (self.arch, self.pclk_mode, self.sel_mode, self.dpr):
            widget.blockSignals(True)
        arch = flags.get("arch") or (
            "serdes" if flags.get("pclk-mode") == "pclk_as_phy_input" else "original_pipe"
        )
        self.arch.setCurrentText(arch)
        self.pclk_mode.setCurrentText(flags.get("pclk-mode") or (
            "pclk_as_phy_input" if arch == "serdes" else "pclk_as_phy_output"
        ))
        self.sel_mode.setCurrentText(flags.get("sel-mode") or "sync")
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
