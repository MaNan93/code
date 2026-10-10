"""Shared page chrome and a scrollable form with a resizable output area."""

from PyQt5 import QtCore, QtWidgets


class WorkflowPage(QtWidgets.QWidget):
    def __init__(self, workflow, parent=None):
        super().__init__(parent)
        self.setObjectName("WorkflowPage")
        self.root = QtWidgets.QVBoxLayout(self)
        self.root.setContentsMargins(0, 0, 0, 0)
        self.root.setSpacing(0)
        header = QtWidgets.QFrame()
        header.setObjectName("PageHeader")
        header_layout = QtWidgets.QVBoxLayout(header)
        header_layout.setContentsMargins(24, 16, 24, 16)
        header_layout.setSpacing(4)
        title = QtWidgets.QLabel(workflow.title)
        title.setObjectName("PageTitle")
        description = QtWidgets.QLabel(workflow.description)
        description.setObjectName("PageDescription")
        description.setWordWrap(True)
        header_layout.addWidget(title)
        header_layout.addWidget(description)
        self.root.addWidget(header)
        self.splitter = QtWidgets.QSplitter(QtCore.Qt.Vertical)
        self.splitter.setChildrenCollapsible(False)
        self.root.addWidget(self.splitter, 1)
        self.scroll = QtWidgets.QScrollArea()
        self.scroll.setObjectName("FormScroll")
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QtWidgets.QFrame.NoFrame)
        content = QtWidgets.QWidget()
        self.form = QtWidgets.QVBoxLayout(content)
        self.form.setContentsMargins(24, 20, 24, 20)
        self.form.setSpacing(12)
        self.scroll.setWidget(content)
        self.splitter.addWidget(self.scroll)

    def add_output(self, widget):
        self.splitter.addWidget(widget)
        self.splitter.setStretchFactor(0, 3)
        self.splitter.setStretchFactor(1, 2)
        self.splitter.setSizes([440, 220])

    def action_row(self, *buttons):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(8)
        row.addStretch(1)
        for widget in buttons:
            row.addWidget(widget)
        self.form.addLayout(row)
