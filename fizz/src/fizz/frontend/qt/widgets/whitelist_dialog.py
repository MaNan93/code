"""Token whitelist editor -- one identifier per line; saved to disk as a
verible obfuscator map file (identity mapping) usable directly as
--load_map to seed those tokens as untouched by obfuscation."""

from PyQt5 import QtGui, QtWidgets

from fizz import core


class WhitelistDialog(QtWidgets.QDialog):
    def __init__(self, path, parent=None):
        super().__init__(parent)
        self.path = path
        self.setWindowTitle("编辑 Token 白名单")
        self.resize(420, 480)

        hint = QtWidgets.QLabel(
            "每行一个 token（信号名/参数名等），混淆时这些 token 会保持原样。\n"
            f"保存到: {path}"
        )
        hint.setWordWrap(True)

        self.text_edit = QtWidgets.QTextEdit()
        self.text_edit.setFont(QtGui.QFont("Consolas", 10))
        self.text_edit.setPlainText("\n".join(core.read_whitelist_tokens(path)))

        btn_row = QtWidgets.QHBoxLayout()
        btn_row.addStretch(1)
        cancel_btn = QtWidgets.QPushButton("取消")
        cancel_btn.clicked.connect(self.reject)
        save_btn = QtWidgets.QPushButton("保存")
        save_btn.setObjectName("primaryBtn")
        save_btn.clicked.connect(self._save)
        btn_row.addWidget(cancel_btn)
        btn_row.addWidget(save_btn)

        layout = QtWidgets.QVBoxLayout(self)
        layout.addWidget(hint)
        layout.addWidget(self.text_edit, 1)
        layout.addLayout(btn_row)

    def _save(self):
        tokens = [line.strip() for line in self.text_edit.toPlainText().splitlines()]
        try:
            core.write_whitelist_tokens(self.path, tokens)
        except OSError as e:
            QtWidgets.QMessageBox.critical(self, "错误", f"保存白名单失败:\n{e}")
            return
        self.accept()
