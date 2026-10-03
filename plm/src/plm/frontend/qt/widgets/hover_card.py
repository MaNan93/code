"""Project details popup used by the navigation project list."""

from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.styles.tokens import SHADOW_LG, TEXT_MAIN, TEXT_MUTED, TEXT_SUB

from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    apply_drop_shadow,
    load_lucide_icon,
    open_in_file_manager,
)


class HoverIconButton(QtWidgets.QPushButton):
    """Small Lucide button whose glyph changes color on hover."""

    def __init__(self, icon_name, normal_color, hover_color, size=16, parent=None):
        super().__init__(parent)
        self.icon_name = icon_name
        self.normal_color = normal_color
        self.hover_color = hover_color
        self.icon_size = size
        self.setIconSize(QtCore.QSize(size, size))
        self._set_icon_color(normal_color)

    def _set_icon_color(self, color):
        self.setIcon(load_lucide_icon(self.icon_name, color, self.icon_size))

    def enterEvent(self, event):
        self._set_icon_color(self.hover_color)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._set_icon_color(self.normal_color)
        super().leaveEvent(event)


class HoverCard(QtWidgets.QFrame):
    """Shared project-details popup displayed beside a project row."""

    pointerEntered = QtCore.pyqtSignal()
    pointerLeft = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent, QtCore.Qt.ToolTip | QtCore.Qt.FramelessWindowHint)
        self.setObjectName("ProjectHoverCard")
        self.setFixedWidth(260)
        apply_drop_shadow(self, shadow=SHADOW_LG)
        self.project_path = None

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(16, 12, 16, 12)
        root.setSpacing(0)

        title_row = QtWidgets.QHBoxLayout()
        title_row.setSpacing(8)
        folder_icon = QtWidgets.QLabel()
        folder_icon.setFixedSize(ICON_SIZE, ICON_SIZE)
        folder_icon.setPixmap(
            load_lucide_icon("folder", TEXT_SUB).pixmap(ICON_SIZE, ICON_SIZE)
        )
        self.name_label = QtWidgets.QLabel()
        self.name_label.setObjectName("HoverProjectName")
        self.pin_btn = HoverIconButton("pin", TEXT_MUTED, TEXT_SUB, 18)
        self.pin_btn.setObjectName("HoverPinButton")
        self.pin_btn.setFixedSize(24, 24)
        self.pin_btn.setCursor(QtCore.Qt.PointingHandCursor)
        title_row.addWidget(folder_icon)
        title_row.addWidget(self.name_label)
        title_row.addStretch(1)
        title_row.addWidget(self.pin_btn)
        root.addLayout(title_row)

        root.addSpacing(8)
        divider = QtWidgets.QFrame()
        divider.setObjectName("HoverCardDivider")
        divider.setFixedHeight(1)
        root.addWidget(divider)
        root.addSpacing(8)

        path_row = QtWidgets.QHBoxLayout()
        path_row.setSpacing(8)
        path_icon = QtWidgets.QLabel()
        path_icon.setFixedSize(ICON_SIZE, ICON_SIZE)
        path_icon.setPixmap(
            load_lucide_icon("folder-open", TEXT_SUB).pixmap(
                ICON_SIZE, ICON_SIZE
            )
        )
        self.path_label = QtWidgets.QLabel()
        self.path_label.setObjectName("HoverProjectPath")
        self.path_label.setSizePolicy(
            QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Preferred
        )
        self.open_btn = HoverIconButton(
            "external-link", TEXT_SUB, TEXT_MAIN, 18
        )
        self.open_btn.setObjectName("HoverOpenButton")
        self.open_btn.setFixedSize(24, 24)
        self.open_btn.setCursor(QtCore.Qt.PointingHandCursor)
        self.open_btn.setToolTip("打开文件夹")
        self.open_btn.clicked.connect(self.open_folder)
        path_row.addWidget(path_icon)
        path_row.addWidget(self.path_label, 1)
        path_row.addWidget(self.open_btn)
        root.addLayout(path_row)

    def set_project(self, project_name, project_path):
        self.project_path = Path(project_path).resolve()
        full_path = str(self.project_path)
        self.name_label.setText(project_name)
        self.path_label.setToolTip(full_path)
        metrics = QtGui.QFontMetrics(self.path_label.font())
        self.path_label.setText(
            metrics.elidedText(full_path, QtCore.Qt.ElideMiddle, 140)
        )

    def open_folder(self):
        if self.project_path is not None:
            open_in_file_manager(self.project_path)

    def enterEvent(self, event):
        self.pointerEntered.emit()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.pointerLeft.emit()
        super().leaveEvent(event)
