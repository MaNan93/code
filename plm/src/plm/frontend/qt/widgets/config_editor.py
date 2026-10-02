"""Editable CSV tables and generation controls used by ConfigPage."""

from PyQt5 import QtCore, QtWidgets


class CsvTableEditor(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()

    def __init__(self, columns, mapping=False, parent=None):
        super().__init__(parent)
        self.mapping = mapping
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        toolbar = QtWidgets.QHBoxLayout()
        if mapping:
            toolbar.addWidget(QtWidgets.QLabel("Lane 数"))
            self.lane_count = QtWidgets.QSpinBox()
            self.lane_count.setObjectName("LaneCount")
            self.lane_count.setRange(1, 64)
            self.lane_count.setValue(max(1, len(columns) - 1))
            self.lane_count.valueChanged.connect(self._change_lane_count)
            toolbar.addWidget(self.lane_count)
        add_button = QtWidgets.QPushButton("添加行")
        add_button.setObjectName("ConfigRowButton")
        add_button.clicked.connect(self.add_row)
        delete_button = QtWidgets.QPushButton("删除选中行")
        delete_button.setObjectName("ConfigRowButton")
        delete_button.clicked.connect(self.delete_selected_rows)
        toolbar.addWidget(add_button)
        toolbar.addWidget(delete_button)
        toolbar.addStretch(1)
        layout.addLayout(toolbar)

        self.table = QtWidgets.QTableWidget(0, len(columns))
        self.table.setObjectName("ConfigDataTable")
        self.table.setHorizontalHeaderLabels(columns)
        self.table.horizontalHeader().setSectionResizeMode(
            QtWidgets.QHeaderView.ResizeToContents
        )
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.table.itemChanged.connect(self.changed.emit)
        layout.addWidget(self.table, 1)

    def _change_lane_count(self, count):
        columns = ["mode"] + [f"lane{index}" for index in range(count)]
        self.table.blockSignals(True)
        self.table.setColumnCount(len(columns))
        self.table.setHorizontalHeaderLabels(columns)
        self.table.blockSignals(False)
        self.changed.emit()

    def set_rows(self, rows, columns=None):
        self.table.blockSignals(True)
        if columns is not None:
            if self.mapping:
                self.lane_count.blockSignals(True)
                self.lane_count.setValue(len(columns) - 1)
                self.lane_count.blockSignals(False)
            self.table.setColumnCount(len(columns))
            self.table.setHorizontalHeaderLabels(columns)
        self.table.setRowCount(len(rows))
        keys = self.columns()
        for row_index, row in enumerate(rows):
            for col_index, key in enumerate(keys):
                self.table.setItem(row_index, col_index, QtWidgets.QTableWidgetItem(
                    str(row.get(key, ""))
                ))
        self.table.blockSignals(False)

    def columns(self):
        return [self.table.horizontalHeaderItem(i).text()
                for i in range(self.table.columnCount())]

    def rows(self):
        keys = self.columns()
        return [
            {key: (self.table.item(row, col).text() if self.table.item(row, col) else "").strip()
             for col, key in enumerate(keys)}
            for row in range(self.table.rowCount())
        ]

    def add_row(self):
        self.table.blockSignals(True)
        index = self.table.rowCount()
        self.table.insertRow(index)
        for col in range(self.table.columnCount()):
            self.table.setItem(index, col, QtWidgets.QTableWidgetItem(""))
        self.table.setCurrentCell(index, 0)
        self.table.blockSignals(False)
        self.changed.emit()

    def delete_selected_rows(self):
        self.table.blockSignals(True)
        selected = {index.row() for index in self.table.selectedIndexes()}
        for row in sorted(selected, reverse=True):
            self.table.removeRow(row)
        self.table.blockSignals(False)
        if selected:
            self.changed.emit()


class GenerationEditor(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()
    generateRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QtWidgets.QFormLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        self.arch = QtWidgets.QComboBox()
        self.arch.addItems(("original_pipe", "serdes"))
        self.pclk_mode = QtWidgets.QComboBox()
        self.pclk_mode.addItems(("pclk_as_phy_output", "pclk_as_phy_input"))
        self.sel_mode = QtWidgets.QComboBox()
        self.sel_mode.addItems(("sync", "comb"))
        self.dpr = QtWidgets.QCheckBox("启用 DPR")
        layout.addRow("PHY 架构", self.arch)
        layout.addRow("PCLK 模式", self.pclk_mode)
        layout.addRow("选择方式", self.sel_mode)
        layout.addRow("DPR", self.dpr)
        self.generate_btn = QtWidgets.QPushButton("Generate RTL + TB")
        self.generate_btn.setObjectName("ConfigGenerateButton")
        self.generate_btn.clicked.connect(self.generateRequested.emit)
        layout.addRow("", self.generate_btn)
        self.arch.currentIndexChanged.connect(self._sync_pclk)
        self.pclk_mode.currentIndexChanged.connect(self._sync_arch)
        for control in (self.arch, self.pclk_mode, self.sel_mode):
            control.currentIndexChanged.connect(self.changed.emit)
        self.dpr.toggled.connect(self.changed.emit)

    def _sync_pclk(self, index):
        self.pclk_mode.blockSignals(True)
        self.pclk_mode.setCurrentIndex(index)
        self.pclk_mode.blockSignals(False)

    def _sync_arch(self, index):
        self.arch.blockSignals(True)
        self.arch.setCurrentIndex(index)
        self.arch.blockSignals(False)

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
        for widget in (self.arch, self.pclk_mode, self.sel_mode, self.dpr):
            widget.blockSignals(False)

    def flags(self):
        return {
            "arch": self.arch.currentText(),
            "pclk-mode": self.pclk_mode.currentText(),
            "sel-mode": self.sel_mode.currentText(),
            "dpr": self.dpr.isChecked(),
        }
