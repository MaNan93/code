"""Collect a project name and a user-selected parent directory."""

import os
from pathlib import Path

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.widgets.common import load_lucide_icon
from plm.frontend.qt.styles.tokens import BG_SURFACE, SPACING_MD, SPACING_XL, TEXT_MAIN


class NewProjectDialog(QtWidgets.QDialog):
    def __init__(self, location, parent=None):
        super().__init__(parent)
        self.setWindowTitle("新建项目")
        self.resize(540, 238)

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(SPACING_XL, SPACING_XL, SPACING_XL, SPACING_XL)
        root.setSpacing(SPACING_MD)

        title = QtWidgets.QLabel("新建项目")
        title.setObjectName("NewProjectDialogTitle")
        root.addWidget(title)
        subtitle = QtWidgets.QLabel("创建一个新的 PLM 配置工作区。")
        subtitle.setObjectName("NewProjectDialogSubtitle")
        root.addWidget(subtitle)
        root.addSpacing(4)

        form = QtWidgets.QFormLayout()
        form.setContentsMargins(0, 0, 0, 0)
        form.setHorizontalSpacing(SPACING_MD)
        form.setVerticalSpacing(SPACING_MD)

        self.name = QtWidgets.QLineEdit()
        self.name.setPlaceholderText("例如：pcie-x8")
        home_location = os.path.expanduser("~")
        default_location = (
            os.path.expanduser(str(location))
            if location
            else os.path.expanduser("~/plm-projects")
        )
        if os.path.normpath(default_location) == os.path.normpath(home_location):
            default_location = os.path.expanduser("~/plm-projects")
        self.location = QtWidgets.QLineEdit(default_location)

        location_row = QtWidgets.QHBoxLayout()
        location_row.setSpacing(SPACING_MD)
        location_row.addWidget(self.location, 1)
        browse = QtWidgets.QPushButton("浏览…")
        browse.clicked.connect(self.browse)
        location_row.addWidget(browse)

        form.addRow("项目名称", self.name)
        form.addRow("保存位置", location_row)
        root.addLayout(form)

        buttons = QtWidgets.QDialogButtonBox(
            QtWidgets.QDialogButtonBox.Ok | QtWidgets.QDialogButtonBox.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        create_button = buttons.button(QtWidgets.QDialogButtonBox.Ok)
        create_button.setText("创建项目")
        create_button.setObjectName("PrimaryBtn")
        create_button.setIcon(load_lucide_icon("rocket", BG_SURFACE, 18))
        create_button.setIconSize(QtCore.QSize(18, 18))
        cancel_button = buttons.button(QtWidgets.QDialogButtonBox.Cancel)
        cancel_button.setText("取消")
        cancel_button.setIcon(load_lucide_icon("x", TEXT_MAIN, 18))
        cancel_button.setIconSize(QtCore.QSize(18, 18))
        root.addWidget(buttons)

    def browse(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(
            self, "选择保存位置", self.location.text() or os.path.expanduser("~")
        )
        if path:
            self.location.setText(path)

    def values(self):
        return self.name.text().strip(), self.location.text().strip()
