"""FTP directory browser dialog, used by the RLskit tab to pick an upload
target directory without typing a path by hand."""

from PyQt5 import QtCore, QtWidgets

from fizz import core
from fizz.frontend.qt.workers import FtpConnectWorker, FtpListWorker


class FtpBrowserDialog(QtWidgets.QDialog):
    def __init__(self, url, user, passwd, parent=None):
        super().__init__(parent)
        self.host, self.current_path = core.parse_ftp_target(url)
        self.user = user
        self.passwd = passwd
        self.ftp = None
        self.selected_url = None
        self._worker = None

        self.setWindowTitle(f"浏览 FTP — {self.host}")
        self.resize(520, 400)

        nav_row = QtWidgets.QHBoxLayout()
        self.up_btn = QtWidgets.QPushButton("↑ 上级")
        self.up_btn.setEnabled(False)
        self.up_btn.clicked.connect(self._go_up)
        self.path_edit = QtWidgets.QLineEdit(self.current_path)
        self.path_edit.setReadOnly(True)
        nav_row.addWidget(self.up_btn)
        nav_row.addWidget(self.path_edit, 1)

        self.listbox = QtWidgets.QListWidget()
        self.listbox.itemDoubleClicked.connect(self._go_into)

        self.status_label = QtWidgets.QLabel("正在连接...")

        btn_row = QtWidgets.QHBoxLayout()
        btn_row.addStretch(1)
        cancel_btn = QtWidgets.QPushButton("取消")
        cancel_btn.clicked.connect(self.reject)
        self.ok_btn = QtWidgets.QPushButton("选择此目录")
        self.ok_btn.setObjectName("primaryBtn")
        self.ok_btn.setEnabled(False)
        self.ok_btn.clicked.connect(self._select)
        btn_row.addWidget(cancel_btn)
        btn_row.addWidget(self.ok_btn)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addLayout(nav_row)
        layout.addWidget(self.listbox, 1)
        layout.addWidget(self.status_label)
        layout.addLayout(btn_row)

        QtCore.QTimer.singleShot(0, self._connect)

    def _connect(self):
        self._worker = FtpConnectWorker(self.host, self.user, self.passwd, self.current_path, self)
        self._worker.listed.connect(self._on_connected)
        self._worker.failed.connect(lambda msg: self.status_label.setText(f"连接失败: {msg}"))
        self._worker.start()

    def _on_connected(self, pwd, entries):
        self.ftp = self._worker.ftp
        self._show_listing(pwd, entries)

    def _list(self, path):
        self.status_label.setText("加载中...")
        self._worker = FtpListWorker(self.ftp, path, self)
        self._worker.listed.connect(self._show_listing)
        self._worker.failed.connect(lambda msg: self.status_label.setText(f"错误: {msg}"))
        self._worker.start()

    def _show_listing(self, pwd, entries):
        self.current_path = pwd
        self.path_edit.setText(pwd)
        self.listbox.clear()
        for name in entries:
            self.listbox.addItem(f"[DIR]  {name}")
        self.up_btn.setEnabled(pwd != "/")
        self.ok_btn.setEnabled(True)
        self.status_label.setText(f"{pwd}  ({len(entries)} 个子目录)")

    def _go_into(self, item):
        name = item.text().replace("[DIR]  ", "", 1)
        new_path = self.current_path.rstrip("/") + "/" + name
        self._list(new_path)

    def _go_up(self):
        if self.current_path == "/":
            return
        parent = "/".join(self.current_path.rstrip("/").split("/")[:-1]) or "/"
        self._list(parent)

    def _select(self):
        path = self.current_path.rstrip("/") + "/"
        self.selected_url = f"ftp://{self.host}{path}"
        self.accept()

    def closeEvent(self, event):
        if self.ftp is not None:
            try:
                self.ftp.quit()
            except Exception:
                pass
        super().closeEvent(event)

    def reject(self):
        if self.ftp is not None:
            try:
                self.ftp.quit()
            except Exception:
                pass
        super().reject()
