"""A six-pixel drag target with a two-pixel painted hover indicator."""

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.styles.tokens import (
    SPLITTER_HANDLE_SIZE,
)


class ContentSplitter(QtWidgets.QSplitter):
    def __init__(self, parent=None):
        super().__init__(QtCore.Qt.Vertical, parent)
        self.setObjectName("ContentSplitter")
        self.setHandleWidth(SPLITTER_HANDLE_SIZE)

    def createHandle(self):
        from .content_splitter_handle import ContentSplitterHandle
        return ContentSplitterHandle(self.orientation(), self)
