"""Paint hover feedback without changing the splitter's hit rectangle."""

from PyQt5 import QtGui, QtWidgets

from plm.frontend.qt.styles.tokens import SPLITTER_HIGHLIGHT_SIZE, get_theme_color


class ContentSplitterHandle(QtWidgets.QSplitterHandle):
    def enterEvent(self, event):
        super().enterEvent(event)
        self.update()

    def leaveEvent(self, event):
        super().leaveEvent(event)
        self.update()

    def paintEvent(self, event):
        if self.underMouse():
            painter = QtGui.QPainter(self)
            painter.fillRect(0, 0, self.width(), SPLITTER_HIGHLIGHT_SIZE,
                             QtGui.QColor(get_theme_color("primary")))
