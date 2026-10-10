"""PLM-style animated navigation rail and footer actions."""

from PyQt5 import QtCore, QtWidgets

from fizz import __version__
from fizz.frontend.qt.models.workflows import WORKFLOWS
from fizz.frontend.qt.styles.tokens import (
    CONTROL_HEIGHT,
    ICON_SIZE,
    NAV_COLLAPSED_WIDTH,
    NAV_EXPANDED_WIDTH,
    PANEL_ANIMATION_DURATION,
)
from fizz.frontend.qt.widgets.common import load_lucide_icon


class NavPanel(QtWidgets.QFrame):
    workflowSelected = QtCore.pyqtSignal(str)
    settingsRequested = QtCore.pyqtSignal()
    docsRequested = QtCore.pyqtSignal()
    collapsedChanged = QtCore.pyqtSignal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("NavPanel")
        self.is_collapsed = False
        self.setFixedWidth(NAV_EXPANDED_WIDTH)
        self.root = QtWidgets.QVBoxLayout(self)
        self.root.setContentsMargins(12, 16, 12, 12)
        self.root.setSpacing(4)
        self.section_title = QtWidgets.QLabel("工具")
        self.section_title.setObjectName("SectionTitle")
        self.root.addWidget(self.section_title)
        self.root.addSpacing(8)
        self.buttons = {}
        self.group = QtWidgets.QButtonGroup(self)
        self.group.setExclusive(True)
        for workflow in WORKFLOWS:
            widget = self._button(workflow.title, workflow.icon)
            widget.setCheckable(True)
            widget.clicked.connect(
                lambda checked, key=workflow.key: self.workflowSelected.emit(key)
            )
            self.group.addButton(widget)
            self.buttons[workflow.key] = widget
            self.root.addWidget(widget)
        self.root.addStretch(1)
        self.settings_btn = self._button("设置", "settings")
        self.docs_btn = self._button("使用说明", "file-text")
        self.settings_btn.clicked.connect(self.settingsRequested.emit)
        self.docs_btn.clicked.connect(self.docsRequested.emit)
        self.root.addWidget(self.settings_btn)
        self.root.addWidget(self.docs_btn)
        self.version_label = QtWidgets.QLabel(f"fizz {__version__}")
        self.version_label.setObjectName("VersionLabel")
        self.root.addWidget(self.version_label)
        self.animation = QtCore.QVariantAnimation(self)
        self.animation.setDuration(PANEL_ANIMATION_DURATION)
        self.animation.setEasingCurve(QtCore.QEasingCurve.OutCubic)
        self.animation.valueChanged.connect(
            lambda value: self.setFixedWidth(int(value))
        )
        self.animation.finished.connect(self._finish_animation)

    @staticmethod
    def _button(text, icon):
        widget = QtWidgets.QPushButton(text)
        widget.setProperty("label", text)
        widget.setObjectName("NavButton")
        widget.setIcon(load_lucide_icon(icon))
        widget.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        widget.setFixedHeight(CONTROL_HEIGHT)
        widget.setMinimumWidth(0)
        widget.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Fixed)
        widget.setToolTip(text)
        widget.setAccessibleName(text)
        widget.setCursor(QtCore.Qt.PointingHandCursor)
        return widget

    def toggle_collapse(self):
        self.set_collapsed(not self.is_collapsed)

    def set_collapsed(self, collapsed, animate=True):
        self.animation.stop()
        self.is_collapsed = bool(collapsed)
        if collapsed:
            self._show_labels(False)
        width = NAV_COLLAPSED_WIDTH if collapsed else NAV_EXPANDED_WIDTH
        if animate:
            self.animation.setStartValue(self.width())
            self.animation.setEndValue(width)
            self.animation.start()
        else:
            self.setFixedWidth(width)
            self._finish_animation()

    def _finish_animation(self):
        self._show_labels(not self.is_collapsed)
        self.collapsedChanged.emit(self.is_collapsed)

    def _show_labels(self, visible):
        self.section_title.setVisible(visible)
        self.version_label.setVisible(visible)
        for widget in [*self.buttons.values(), self.settings_btn, self.docs_btn]:
            widget.setText(widget.property("label") if visible else "")
            widget.setObjectName("NavButton" if visible else "NavIconBtn")
            widget.style().unpolish(widget)
            widget.style().polish(widget)
        self.root.setContentsMargins(12 if visible else 8, 16, 12 if visible else 8, 12)

    def select_workflow(self, key):
        self.buttons[key].setChecked(True)
