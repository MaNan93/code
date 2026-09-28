"""RLskit upload history viewer -- one row per source directory ever
packaged, hover a row for its full detail, multi-select to delete."""

from PyQt5 import QtWidgets


class RLskitHistoryDialog(QtWidgets.QDialog):
    def __init__(self, config, parent=None):
        super().__init__(parent)
        self.config = config
        self.setWindowTitle("RLskit 历史查看")
        self.resize(900, 460)

        self.table = QtWidgets.QTableWidget(0, 3)
        self.table.setHorizontalHeaderLabels(["目录", "版本号", "上传时间"])
        self.table.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QtWidgets.QAbstractItemView.ExtendedSelection)
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QtWidgets.QHeaderView.Stretch)
        header.setSectionResizeMode(1, QtWidgets.QHeaderView.ResizeToContents)
        header.setSectionResizeMode(2, QtWidgets.QHeaderView.ResizeToContents)

        self.status_label = QtWidgets.QLabel("")

        btn_row = QtWidgets.QHBoxLayout()
        btn_row.addStretch(1)
        delete_btn = QtWidgets.QPushButton("删除选中")
        delete_btn.clicked.connect(self._delete_selected)
        refresh_btn = QtWidgets.QPushButton("刷新")
        refresh_btn.clicked.connect(self._refresh)
        btn_row.addWidget(delete_btn)
        btn_row.addWidget(refresh_btn)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(self.table, 1)
        layout.addWidget(self.status_label)
        layout.addLayout(btn_row)

        self._rows = []
        self._refresh()

    def _refresh(self):
        self._rows = self.config.rlskit_history_rows()
        self.table.setRowCount(len(self._rows))
        for r, row in enumerate(self._rows):
            tooltip = (
                f"目录: {row.get('path', '')}\n"
                f"版本号: {row.get('version', '')}\n"
                f"FTP路径: {row.get('ftp_path', '')}\n"
                f"上传时间: {row.get('upload_time', '')}"
            )
            for c, key in enumerate(("path", "version", "upload_time")):
                item = QtWidgets.QTableWidgetItem(row.get(key, ""))
                item.setToolTip(tooltip)
                self.table.setItem(r, c, item)
        self.status_label.setText(f"共 {len(self._rows)} 条目录历史记录")

    def _delete_selected(self):
        rows = sorted({idx.row() for idx in self.table.selectedIndexes()})
        if not rows:
            QtWidgets.QMessageBox.warning(self, "提示", "请先选择要删除的历史记录。")
            return
        if QtWidgets.QMessageBox.question(
            self, "确认", f"确认删除选中的 {len(rows)} 条历史记录？",
        ) != QtWidgets.QMessageBox.Yes:
            return
        prefixes = [self._rows[r]["prefix"] for r in rows if self._rows[r].get("prefix")]
        self.config.delete_rlskit_history_rows(prefixes)
        self._refresh()
