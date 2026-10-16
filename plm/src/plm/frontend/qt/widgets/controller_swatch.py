"""Controller brush label that always keeps its numeric ID visible."""

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.styles.tokens import CONTROL_PADDING_X, LANE_SWATCH_MAX_WIDTH


class ControllerSwatch(QtWidgets.QPushButton):
    def __init__(self, controller_id, name, parent=None):
        self.controller_id = str(controller_id)
        self.controller_name = str(name)
        super().__init__(f"{self.controller_id}: {self.controller_name}", parent)
        self.setMaximumWidth(LANE_SWATCH_MAX_WIDTH)
        self.setAccessibleName(self.text())

    def sizeHint(self):
        size = super().sizeHint()
        size.setWidth(min(size.width(), self.maximumWidth()))
        return size

    def minimumSizeHint(self):
        size = super().minimumSizeHint()
        size.setWidth(self.fontMetrics().horizontalAdvance(f"{self.controller_id}: …")
                      + 2 * CONTROL_PADDING_X)
        return size

    def display_text(self):
        option = QtWidgets.QStyleOptionButton()
        self.initStyleOption(option)
        rect = self.style().subElementRect(QtWidgets.QStyle.SE_PushButtonContents, option, self)
        prefix = f"{self.controller_id}: "
        width = max(0, rect.width() - self.fontMetrics().horizontalAdvance(prefix))
        name = self.fontMetrics().elidedText(self.controller_name, QtCore.Qt.ElideRight, width)
        return prefix + name

    def paintEvent(self, event):
        option = QtWidgets.QStyleOptionButton()
        self.initStyleOption(option)
        option.text = self.display_text()
        painter = QtWidgets.QStylePainter(self)
        painter.drawControl(QtWidgets.QStyle.CE_PushButton, option)
