"""Shared output panel, using the PLM header and quiet console surface."""

from PyQt5 import QtWidgets

from fizz.frontend.qt.widgets.common import icon_button


class LogPanel(QtWidgets.QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("LogPanel")
        self.setMinimumHeight(130)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(16, 8, 16, 12)
        root.setSpacing(0)
        header = QtWidgets.QHBoxLayout()
        title = QtWidgets.QLabel("输出日志")
        title.setObjectName("SectionTitle")
        header.addWidget(title)
        header.addStretch(1)
        self.output = QtWidgets.QTextEdit()
        self.output.setObjectName("LogOutput")
        self.output.setReadOnly(True)
        self.clear_btn = icon_button("trash-2", "清空日志", self.output.clear)
        header.addWidget(self.clear_btn)
        root.addLayout(header)
        root.addWidget(self.output, 1)
