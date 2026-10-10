"""Shared Lucide icons, sections, fields and desktop controls."""

from functools import lru_cache

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets

from fizz.frontend.qt.styles.tokens import CONTROL_HEIGHT, ICON_DIR, ICON_SIZE, TEXT_SUB


@lru_cache(maxsize=128)
def load_lucide_icon(name, color=TEXT_SUB, size=ICON_SIZE):
    data = (ICON_DIR / f"{name}.svg").read_text(encoding="utf-8")
    renderer = QtSvg.QSvgRenderer(
        QtCore.QByteArray(data.replace("currentColor", color).encode())
    )
    # Render at 2x, keeping sharp glyphs on high DPI displays.
    pixmap = QtGui.QPixmap(size * 2, size * 2)
    pixmap.fill(QtCore.Qt.transparent)
    painter = QtGui.QPainter(pixmap)
    renderer.render(painter)
    painter.end()
    pixmap.setDevicePixelRatio(2)
    return QtGui.QIcon(pixmap)


def button(text, callback, icon=None, primary=False):
    widget = QtWidgets.QPushButton(text)
    widget.setFixedHeight(CONTROL_HEIGHT)
    widget.setCursor(QtCore.Qt.PointingHandCursor)
    if icon:
        widget.setIcon(load_lucide_icon(icon, "#FFFFFF" if primary else TEXT_SUB))
        widget.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
    if primary:
        widget.setObjectName("PrimaryBtn")
    widget.clicked.connect(callback)
    return widget


def icon_button(icon, tooltip, callback=None):
    widget = QtWidgets.QToolButton()
    widget.setFixedSize(32, 32)
    widget.setIcon(load_lucide_icon(icon))
    widget.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
    widget.setToolTip(tooltip)
    widget.setAccessibleName(tooltip)
    widget.setCursor(QtCore.Qt.PointingHandCursor)
    if callback:
        widget.clicked.connect(callback)
    return widget


def line_edit(text="", placeholder="", readonly=False):
    widget = QtWidgets.QLineEdit(text)
    widget.setFixedHeight(CONTROL_HEIGHT)
    widget.setMinimumWidth(0)
    widget.setPlaceholderText(placeholder)
    widget.setReadOnly(readonly)
    return widget


class Section(QtWidgets.QFrame):
    def __init__(self, title, parent=None):
        super().__init__(parent)
        self.setObjectName("Section")
        self.body = QtWidgets.QVBoxLayout(self)
        self.body.setContentsMargins(16, 12, 16, 12)
        self.body.setSpacing(10)
        label = QtWidgets.QLabel(title)
        label.setObjectName("SectionTitle")
        self.body.addWidget(label)

    def field(self, label, widget, *actions):
        row = QtWidgets.QHBoxLayout()
        row.setSpacing(8)
        if label:
            title = QtWidgets.QLabel(label)
            title.setBuddy(widget)
            row.addWidget(title)
        row.addWidget(widget, 1)
        for action in actions:
            row.addWidget(action)
        self.body.addLayout(row)
        return row


class FixedHeightItemDelegate(QtWidgets.QStyledItemDelegate):
    def sizeHint(self, option, index):
        hint = super().sizeHint(option, index)
        hint.setHeight(CONTROL_HEIGHT)
        return hint


class AdaptiveColumns(QtWidgets.QWidget):
    """Place form sections side by side when there is room for their fields."""

    def __init__(self, left, right, parent=None):
        super().__init__(parent)
        self.sections = (left, right)
        self.columns = 1
        self.grid = QtWidgets.QGridLayout(self)
        self.grid.setContentsMargins(0, 0, 0, 0)
        self.grid.setSpacing(12)
        self.grid.addWidget(left, 0, 0)
        self.grid.addWidget(right, 1, 0)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        columns = 2 if self.width() >= 820 else 1
        if columns == self.columns:
            return
        self.columns = columns
        for index, section in enumerate(self.sections):
            self.grid.removeWidget(section)
            self.grid.addWidget(section, index // columns, index % columns)
        self.grid.setColumnStretch(0, 1)
        self.grid.setColumnStretch(1, 1 if columns == 2 else 0)
        self.updateGeometry()


def polish_controls(root):
    """Apply the same control grid to dialogs and combo popup rows."""
    for widget in root.findChildren(QtWidgets.QWidget):
        if isinstance(
            widget, (QtWidgets.QLineEdit, QtWidgets.QComboBox, QtWidgets.QSpinBox)
        ):
            widget.setFixedHeight(CONTROL_HEIGHT)
        elif (
            isinstance(widget, QtWidgets.QPushButton)
            and widget.objectName() != "WindowControlButton"
        ):
            widget.setMinimumHeight(CONTROL_HEIGHT)
        if isinstance(widget, QtWidgets.QComboBox):
            widget.setItemDelegate(FixedHeightItemDelegate(widget))
        if isinstance(widget, QtWidgets.QTableWidget):
            widget.verticalHeader().setDefaultSectionSize(CONTROL_HEIGHT)
