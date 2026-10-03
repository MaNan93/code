"""Collect a project name and a user-selected parent directory."""

import os
from pathlib import Path

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.widgets.common import load_lucide_icon


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
        home_location = os.path.expanduser("~")
        default_location = (
            os.path.expanduser(str(location))
            if location
            else os.path.expanduser("~/plm-projects")
        )
        if os.path.normpath(default_location) == os.path.normpath(home_location):
            default_location = os.path.expanduser("~/plm-projects")
        self.location = QtWidgets.QLineEdit(default_location)
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
        create_button = buttons.button(QtWidgets.QDialogButtonBox.Ok)
        create_button.setText("创建项目")
        create_button.setObjectName("CreateProjectButton")
        create_button.setIcon(load_lucide_icon("rocket", "#FFFFFF", 20))
        create_button.setIconSize(QtCore.QSize(20, 20))
        cancel_button = buttons.button(QtWidgets.QDialogButtonBox.Cancel)
        cancel_button.setText("取消")
        cancel_button.setIcon(load_lucide_icon("x", "#333333", 20))
        cancel_button.setIconSize(QtCore.QSize(20, 20))
        form.addRow(buttons)

    def browse(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(
            self, "选择保存位置", self.location.text() or os.path.expanduser("~")
        )
        if path:
            self.location.setText(path)

    def values(self):
        return self.name.text().strip(), self.location.text().strip()
