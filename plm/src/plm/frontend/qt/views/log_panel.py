from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt.widgets.common import ICON_SIZE, make_icon_button

class LogPanel(QtWidgets.QFrame):
    """Region 4: output tab, clear action, and auto-scrolling log."""

    closeRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("LogPanel")
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        header = QtWidgets.QFrame()
        header.setObjectName("LogHeader")
        header.setFixedHeight(32)
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(16, 0, 12, 0)
        header_layout.setSpacing(8)
        title = QtWidgets.QLabel("输出")
        title.setObjectName("LogTabTitle")
        header_layout.addWidget(title)
        header_layout.addStretch(1)
        self.clear_btn = make_icon_button(
            "trash-2", "清空日志", "LogClearButton", 20, 20
        )
        self.clear_btn.clicked.connect(self.clear)
        header_layout.addWidget(self.clear_btn)
        self.close_btn = make_icon_button(
            "x", "关闭输出面板", "LogCloseBtn", 24, ICON_SIZE
        )
        self.close_btn.clicked.connect(self.closeRequested.emit)
        header_layout.addWidget(self.close_btn)
        root.addWidget(header)
        self.output = QtWidgets.QPlainTextEdit()
        self.output.setObjectName("LogOutput")
        self.output.setReadOnly(True)
        root.addWidget(self.output, 1)

    def append_log(self, text):
        self.output.appendPlainText(text)
        bar = self.output.verticalScrollBar()
        bar.setValue(bar.maximum())

    def clear(self):
        self.output.clear()
