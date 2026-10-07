from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt.widgets.common import (
    ICON_SIZE, RoundedCanvasFrame, make_icon_button,
)


class LogPanel(RoundedCanvasFrame):
    """Region 4: output tab, clear action, and auto-scrolling log."""

    BORDER_WIDTH = 0.0

    closeRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("LogPanel")
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(1, 1, 1, self.CORNER_RADII[2])
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
            "trash-2", "清空日志", "LogClearButton", 24, ICON_SIZE
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

        self.status_bar = QtWidgets.QFrame()
        self.status_bar.setObjectName("LogStatusBar")
        self.status_bar.setFixedHeight(24)
        status_layout = QtWidgets.QHBoxLayout(self.status_bar)
        status_layout.setContentsMargins(16, 0, 12, 0)
        status_layout.setSpacing(0)
        self.status_label = QtWidgets.QLabel("")
        self.status_label.setObjectName("LogStatusText")
        status_layout.addWidget(self.status_label)
        status_layout.addStretch(1)
        self.status_bar.hide()
        root.addWidget(self.status_bar)

    def append_log(self, text):
        if text.startswith(("生成完成：", "输出已是最新：")):
            self.set_status(text)
            return
        self.output.appendPlainText(text)
        bar = self.output.verticalScrollBar()
        bar.setValue(bar.maximum())

    def set_status(self, text):
        self.status_label.setText(text)
        self.status_bar.setVisible(bool(text))

    def clear(self):
        self.output.clear()
        self.set_status("")
