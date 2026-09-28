"""Timing-violation results dialog for the post-sim analysis tab.

Double-click a cell to copy it; select rows and click "waived" to drop them
from the table and append `instance {...} {noTiming}` lines to
notimingcheck.lst for the simulator to pick up next run."""

from PyQt5 import QtWidgets

from fizz import core

_PLACEHOLDERS = ("未提取到", "无后续内容", "", "-", "未找到 Timing violation")


class TimingViolationDialog(QtWidgets.QDialog):
    def __init__(self, file_path, results, parent=None):
        super().__init__(parent)
        self.file_path = file_path
        self.results = list(results)

        self.setWindowTitle("Timing Violation 分析")
        self.resize(1050, 550)

        file_label = QtWidgets.QLabel(f"文件：{file_path}")
        file_label.setWordWrap(True)

        header_row = QtWidgets.QHBoxLayout()
        self.count_label = QtWidgets.QLabel()
        self.count_label.setStyleSheet("font-weight: bold;")
        header_row.addWidget(self.count_label)
        header_row.addStretch(1)
        waive_btn = QtWidgets.QPushButton("waived")
        waive_btn.clicked.connect(self._waive_selected)
        header_row.addWidget(waive_btn)
        self.show_more = QtWidgets.QCheckBox("show more")
        self.show_more.toggled.connect(self._refresh)
        header_row.addWidget(self.show_more)

        self.table = QtWidgets.QTableWidget(0, 3)
        self.table.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QtWidgets.QAbstractItemView.ExtendedSelection)
        self.table.cellDoubleClicked.connect(self._copy_cell)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(file_label)
        layout.addLayout(header_row)
        layout.addWidget(self.table, 1)

        self._refresh()

    def _columns(self):
        if self.show_more.isChecked():
            return [("No.", 50), ("Instance", 230), ("Info", 400), ("Path", 230), ("Line", 90)]
        return [("No.", 50), ("Instance", 260), ("Info", 700)]

    def _row_values(self, idx, r):
        if self.show_more.isChecked():
            return [str(idx + 1), r["instance"], r["info"], r["path"], r["line_number"]]
        return [str(idx + 1), r["instance"], r["info"]]

    def _refresh(self):
        columns = self._columns()
        self.table.setColumnCount(len(columns))
        self.table.setHorizontalHeaderLabels([c[0] for c in columns])
        self.table.setRowCount(0)

        rows = self.results if self.results else [None]
        self.table.setRowCount(len(rows))
        for r_idx, r in enumerate(rows):
            values = self._row_values(r_idx, r) if r is not None else (
                ["-", "未找到 Timing violation", "", "", ""][:len(columns)]
            )
            for c_idx, text in enumerate(values):
                item = QtWidgets.QTableWidgetItem(text)
                if text not in _PLACEHOLDERS:
                    item.setToolTip(text)
                self.table.setItem(r_idx, c_idx, item)

        for c_idx, (_, width) in enumerate(columns):
            self.table.setColumnWidth(c_idx, width)

        self.count_label.setText(f"匹配数：{len(self.results)}")

    def _copy_cell(self, row, column):
        item = self.table.item(row, column)
        if item is None:
            return
        text = item.text()
        if text and text not in _PLACEHOLDERS:
            QtWidgets.QApplication.clipboard().setText(text)

    def _waive_selected(self):
        rows = sorted({idx.row() for idx in self.table.selectedIndexes()})
        if not rows:
            QtWidgets.QMessageBox.information(self, "提示", "请先选择需要移除的行")
            return

        instances = set()
        for row in rows:
            item = self.table.item(row, 1)
            if item is None:
                continue
            instance = item.text()
            if instance and instance not in _PLACEHOLDERS:
                instances.add(instance)
        if not instances:
            return

        self.results[:] = [r for r in self.results if r["instance"] not in instances]
        try:
            core.write_waive_instances(instances)
        except OSError as e:
            QtWidgets.QMessageBox.critical(self, "错误", f"写入文件失败:\n{e}")
            return

        self._refresh()
        QtWidgets.QMessageBox.information(
            self, "成功", f"已移除 {len(instances)} 个 instance，结果已写入 notimingcheck.lst",
        )
