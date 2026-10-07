"""Responsive file selector used by the artifact drawer toolbar."""

from html import escape

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.styles.tokens import TEXT_MAIN, TEXT_SUB


class ArtifactPathLabel(QtWidgets.QLabel):
    clicked = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactPath")
        self._full_path = ""
        self._directory = ""
        self._filename = ""
        self.display_path = ""
        self.setTextFormat(QtCore.Qt.RichText)
        self.setMinimumWidth(0)
        self.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Preferred)
        self.setAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
        self.setCursor(QtCore.Qt.PointingHandCursor)

    def set_path(self, path, root=None):
        self._full_path = str(path or "")
        self._directory = ""
        self._filename = path.name if path is not None else ""
        if path is not None:
            try:
                relative = path.relative_to(root) if root is not None else path
                self._directory = " / ".join(relative.parts[:-1])
            except ValueError:
                self._directory = "…"
        self.setToolTip(self._full_path)
        self.setAccessibleName(self._full_path)
        self._update_text()

    def _update_text(self):
        width = max(0, self.contentsRect().width() - 4)
        font = QtGui.QFont(self.font())
        font.setBold(True)
        filename_metrics = QtGui.QFontMetrics(font)
        filename = filename_metrics.elidedText(self._filename, QtCore.Qt.ElideMiddle, width)
        directory = ""
        if filename == self._filename and self._directory:
            available = width - filename_metrics.horizontalAdvance(filename)
            directory = self.fontMetrics().elidedText(
                self._directory + " / ", QtCore.Qt.ElideLeft, max(0, available)
            )
        self.display_path = directory + filename
        self.setText(
            f'<span style="color:{TEXT_SUB}">{escape(directory)}</span>'
            f'<b style="color:{TEXT_MAIN}">{escape(filename)}</b>'
            if self._filename else ""
        )

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._update_text()

    def mouseReleaseEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton and self.rect().contains(event.pos()):
            self.clicked.emit()
            event.accept()
        else:
            super().mouseReleaseEvent(event)


class ArtifactFileSelector(QtWidgets.QFrame):
    """A single hover surface for the tree toggle and file breadcrumb."""

    def __init__(self, button, label, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactFileSelector")
        self.setMinimumWidth(button.width())
        self.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Preferred)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 4, 0)
        layout.setSpacing(8)
        layout.addWidget(button)
        layout.addWidget(label, 1)
        label.clicked.connect(button.click)

    def enterEvent(self, event):
        self._set_hovered(True)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._set_hovered(False)
        super().leaveEvent(event)

    def _set_hovered(self, hovered):
        self.setProperty("hovered", hovered)
        self.style().unpolish(self)
        self.style().polish(self)
