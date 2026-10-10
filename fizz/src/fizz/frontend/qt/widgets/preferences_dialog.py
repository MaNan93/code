"""Preferences dialog -- edits the values persisted to ~/.fizz.ini."""

from PyQt5 import QtWidgets

from fizz.frontend.qt.widgets.common import load_lucide_icon, polish_controls


class PreferencesDialog(QtWidgets.QDialog):
    def __init__(self, values, dialog_initial_dir, parent=None):
        super().__init__(parent)
        self.setWindowTitle("fizz 设置")
        self.resize(820, 580)
        self.setMinimumSize(720, 560)
        self._dialog_initial_dir = dialog_initial_dir
        self.action = None  # "save" | "open"

        form = QtWidgets.QGridLayout()
        form.setColumnStretch(1, 1)

        self.exclude_dirs = QtWidgets.QLineEdit(values.get("exclude_dirs", ""))
        self.exclude_files = QtWidgets.QLineEdit(values.get("exclude_files", ""))
        self.vcs_key_file = QtWidgets.QLineEdit(values.get("vcs_key_file", ""))
        self.vcs_options = QtWidgets.QLineEdit(values.get("vcs_options", ""))
        self.obfuscator_path = QtWidgets.QLineEdit(values.get("obfuscator_path", ""))
        self.ftp_url = QtWidgets.QLineEdit(values.get("ftp_url", ""))
        self.ftp_username = QtWidgets.QLineEdit(values.get("ftp_username", ""))
        self.ftp_password = QtWidgets.QLineEdit(values.get("ftp_password", ""))
        self.ftp_password.setEchoMode(QtWidgets.QLineEdit.Password)

        rows = [
            ("1. 排除目录", self.exclude_dirs, None),
            ("2. 排除文件", self.exclude_files, None),
            ("3. 密钥文件", self.vcs_key_file, self._browse_vcs_key),
            ("4. VCS Protect 选项", self.vcs_options, None),
            ("5. Obfuscator 路径", self.obfuscator_path, self._browse_obf_tool),
            ("6. RLskit URL", self.ftp_url, None),
            ("   用户名", self.ftp_username, None),
            ("   密码", self.ftp_password, None),
        ]
        for row, (label, field, browse_cb) in enumerate(rows):
            form.addWidget(QtWidgets.QLabel(label), row, 0)
            form.addWidget(field, row, 1)
            if browse_cb is not None:
                btn = QtWidgets.QPushButton("浏览...")
                btn.setIcon(load_lucide_icon("folder-open"))
                btn.clicked.connect(browse_cb)
                form.addWidget(btn, row, 2)

        btn_row = QtWidgets.QHBoxLayout()
        btn_row.addStretch(1)
        open_btn = QtWidgets.QPushButton("打开配置")
        save_btn = QtWidgets.QPushButton("保存配置")
        save_btn.setObjectName("primaryBtn")
        open_btn.clicked.connect(self._on_open)
        save_btn.clicked.connect(self._on_save)
        btn_row.addWidget(open_btn)
        btn_row.addWidget(save_btn)

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(16)
        layout.addLayout(form)
        layout.addStretch(1)
        layout.addLayout(btn_row)
        polish_controls(self)

    def _browse_vcs_key(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择密钥文件", self._dialog_initial_dir(self.vcs_key_file.text()),
            "Text files (*.txt);;All (*.*)",
        )
        if path:
            self.vcs_key_file.setText(path)

    def _browse_obf_tool(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择 verible-verilog-obfuscate 可执行文件",
            self._dialog_initial_dir(self.obfuscator_path.text()),
            "Executable (*);;All (*.*)",
        )
        if path:
            self.obfuscator_path.setText(path)

    def _on_save(self):
        self.action = "save"
        self.accept()

    def _on_open(self):
        self.action = "open"
        self.accept()

    def values(self):
        return {
            "exclude_dirs": self.exclude_dirs.text().strip(),
            "exclude_files": self.exclude_files.text().strip(),
            "vcs_key_file": self.vcs_key_file.text().strip(),
            "vcs_options": self.vcs_options.text().strip(),
            "obfuscator_path": self.obfuscator_path.text().strip() or "verible-verilog-obfuscate",
            "ftp_url": self.ftp_url.text().strip(),
            "ftp_username": self.ftp_username.text().strip(),
            "ftp_password": self.ftp_password.text(),
        }
