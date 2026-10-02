"""Collect a project name and a user-selected parent directory."""

from pathlib import Path
from PyQt5 import QtWidgets


class NewProjectDialog(QtWidgets.QDialog):
    def __init__(self, location, parent=None):
        super().__init__(parent)
        self.setWindowTitle("新建项目")
        self.resize(520, 180)
        self.setStyleSheet("""
            QDialog { background: white; }
            QLineEdit { border: 1px solid #D9D9D9; border-radius: 6px; padding: 6px; }
            QPushButton { border: 1px solid #D9D9D9; border-radius: 6px; padding: 6px 14px; background: white; }
            QPushButton#CreateProjectButton { background: #1677FF; border-color: #1677FF; color: white; }
        """)
        form = QtWidgets.QFormLayout(self)
        form.setContentsMargins(20, 20, 20, 20)
        form.setSpacing(12)
        self.name = QtWidgets.QLineEdit()
        self.location = QtWidgets.QLineEdit(str(location))
        row = QtWidgets.QHBoxLayout()
        row.addWidget(self.location)
        browse = QtWidgets.QPushButton("浏览…")
        browse.clicked.connect(self.browse)
        row.addWidget(browse)
        form.addRow("项目名称", self.name)
        form.addRow("保存位置", row)
        buttons = QtWidgets.QDialogButtonBox(
            QtWidgets.QDialogButtonBox.Ok | QtWidgets.QDialogButtonBox.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        buttons.button(QtWidgets.QDialogButtonBox.Ok).setText("创建项目")
        buttons.button(QtWidgets.QDialogButtonBox.Ok).setObjectName("CreateProjectButton")
        buttons.button(QtWidgets.QDialogButtonBox.Cancel).setText("取消")
        form.addRow(buttons)

    def browse(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(
            self, "选择保存位置", self.location.text() or str(Path.home())
        )
        if path:
            self.location.setText(path)

    def values(self):
        return self.name.text().strip(), self.location.text().strip()
