from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import apply_drop_shadow, make_icon_button
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel

class EscapeLineEdit(QtWidgets.QLineEdit):
    escapePressed = QtCore.pyqtSignal()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.escapePressed.emit()
            event.accept()
            return
        super().keyPressEvent(event)


class DoubleClickLabel(QtWidgets.QLabel):
    doubleClicked = QtCore.pyqtSignal()

    def mouseDoubleClickEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.doubleClicked.emit()
            event.accept()
            return
        super().mouseDoubleClickEvent(event)





class ConfigHeader(QtWidgets.QFrame):
    """Region 2.1: editable session title and panel toggles."""

    logToggleRequested = QtCore.pyqtSignal()
    artifactsToggleRequested = QtCore.pyqtSignal()
    titleChanged = QtCore.pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigHeader")
        self.setFixedHeight(56)
        self._original_title = ""
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(20, 8, 12, 8)
        layout.setSpacing(8)
        self.title_label = DoubleClickLabel("重写 PLM Qt 前端布局")
        self.title_label.setObjectName("ConfigSessionTitle")
        self.title_label.setToolTip("双击重命名")
        self.title_label.doubleClicked.connect(self.enter_edit_mode)
        layout.addWidget(self.title_label)
        self.title_edit = EscapeLineEdit()
        self.title_edit.setObjectName("ConfigSessionEditor")
        self.title_edit.hide()
        self.title_edit.returnPressed.connect(self.save_title)
        self.title_edit.editingFinished.connect(self.save_title)
        self.title_edit.escapePressed.connect(self.cancel_title)
        layout.addWidget(self.title_edit)
        layout.addStretch(1)
        self.log_btn = make_icon_button(
            "panel-bottom", "显示/隐藏输出面板", "HeaderButton", 28
        )
        self.artifacts_btn = make_icon_button(
            "panel-right", "显示/隐藏 Artifacts", "HeaderButton", 28
        )
        self.log_btn.clicked.connect(self.logToggleRequested.emit)
        self.artifacts_btn.clicked.connect(self.artifactsToggleRequested.emit)
        layout.addWidget(self.log_btn)
        layout.addWidget(self.artifacts_btn)

    def enter_edit_mode(self):
        self._original_title = self.title_label.text()
        self.title_edit.setText(self._original_title)
        self.title_label.hide()
        self.title_edit.show()
        self.title_edit.selectAll()
        self.title_edit.setFocus(QtCore.Qt.OtherFocusReason)

    def save_title(self):
        if not self.title_edit.isVisible():
            return
        new_title = self.title_edit.text().strip() or self._original_title
        self.title_label.setText(new_title)
        self.title_edit.hide()
        self.title_label.show()
        self.titleChanged.emit(new_title)

    def cancel_title(self):
        if not self.title_edit.isVisible():
            return
        self.title_edit.hide()
        self.title_label.setText(self._original_title)
        self.title_label.show()


class ConfigTabPage(QtWidgets.QWidget):
    def __init__(self, title, description, parent=None):
        super().__init__(parent)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)
        root.setSpacing(0)
        heading = QtWidgets.QLabel(title)
        heading.setObjectName("ConfigTitle")
        root.addWidget(heading)
        root.addSpacing(8)
        description_label = QtWidgets.QLabel(description)
        description_label.setObjectName("ConfigDescription")
        description_label.setWordWrap(True)
        root.addWidget(description_label)
        root.addSpacing(20)

        scroll = QtWidgets.QScrollArea()
        scroll.setObjectName("ConfigScroll")
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        content = QtWidgets.QWidget()
        content.setObjectName("ConfigScrollContent")
        content_layout = QtWidgets.QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 8, 0)
        content_layout.setSpacing(16)
        for label_text in (
            "基础配置",
            "参数映射与校验",
            "生成选项（业务控件将在后续阶段接入）",
        ):
            card = QtWidgets.QFrame()
            card.setObjectName("ConfigPlaceholderCard")
            apply_drop_shadow(card)
            card_layout = QtWidgets.QHBoxLayout(card)
            card_layout.setContentsMargins(20, 16, 20, 16)
            label = QtWidgets.QLabel(label_text)
            label.setObjectName("PlaceholderLabel")
            card_layout.addWidget(label)
            card_layout.addStretch(1)
            content_layout.addWidget(card)
        content_layout.addStretch(1)
        scroll.setWidget(content)
        root.addWidget(scroll, 1)


class DragHandle(QtWidgets.QWidget):
    """White capsule handle for resizing the floating Artifacts panel."""

    def __init__(self, on_drag, on_release, parent=None):
        super().__init__(parent)
        self.on_drag = on_drag
        self.on_release = on_release
        self.drag_start_x = None
        self.setFixedSize(14, 36)
        self.setCursor(QtCore.Qt.SplitHCursor)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        capsule = QtCore.QRectF(0.5, 0.5, 13, 35)
        painter.setPen(QtGui.QPen(QtGui.QColor("#C0C4CC"), 1))
        painter.setBrush(QtGui.QColor("#FFFFFF"))
        painter.drawRoundedRect(capsule, 7, 7)
        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(QtGui.QColor("#A0A5B0"))
        painter.drawRect(QtCore.QRectF(4, 14, 1.5, 8))
        painter.drawRect(QtCore.QRectF(8.5, 14, 1.5, 8))

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.drag_start_x = event.globalPos().x()
            self.on_drag("start", self.drag_start_x)
            event.accept()

    def mouseMoveEvent(self, event):
        if self.drag_start_x is not None:
            self.on_drag("move", event.globalPos().x())
            event.accept()

    def mouseReleaseEvent(self, event):
        if self.drag_start_x is not None:
            self.drag_start_x = None
            self.on_release()
            event.accept()

class ConfigPage(QtWidgets.QFrame):
    """Region 2 with an absolute-positioned Region 5 overlay."""

    logToggleRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.setObjectName("ConfigPage")
        apply_drop_shadow(self)
        self.artifacts_width = 400
        self.restore_artifacts_width = 400
        self.artifacts_maximized = False
        self.drag_start_global_x = None
        self.drag_start_width = None

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        self.header = ConfigHeader()
        self.header.logToggleRequested.connect(self.logToggleRequested.emit)
        self.header.artifactsToggleRequested.connect(self.toggle_artifacts)
        root.addWidget(self.header)
        root.addSpacing(12)

        self.config_area = QtWidgets.QWidget()
        self.config_area.setObjectName("ConfigArea")
        config_layout = QtWidgets.QVBoxLayout(self.config_area)
        config_layout.setContentsMargins(0, 0, 0, 0)
        self.tabs = QtWidgets.QTabWidget()
        self.tabs.setObjectName("ConfigTabs")
        self.tabs.setUsesScrollButtons(False)
        for tab_name, title, description in (
            ("Controller", "Controller Configuration", "配置控制器 ID、名称和最大 Lane 宽度。"),
            ("LaneMapping", "Lane Mapping Configuration", "配置物理 Lane 与控制器 Lane 的映射关系。"),
            ("Signals", "PIPE Signals", "配置 PIPE 信号、方向、位宽与安全值。"),
            ("Generation", "Generation Settings", "检查输出目录和 RTL 生成参数。"),
        ):
            self.tabs.addTab(ConfigTabPage(title, description), tab_name)
        config_layout.addWidget(self.tabs, 1)
        root.addWidget(self.config_area, 1)

        self.artifacts_panel = ArtifactsPanel(
            self.config_area, editor_path_provider=editor_path_provider
        )
        self.artifacts_panel.maximizeRequested.connect(self.toggle_artifacts_maximized)
        self.drag_handle = DragHandle(
            self.handle_artifacts_drag, self.finish_artifacts_drag, self.config_area
        )
        self.artifacts_panel.show()
        self.drag_handle.show()
        self.config_area.installEventFilter(self)
        QtCore.QTimer.singleShot(0, self.reposition_artifacts)

    def update_title(self, project_name):
        self.header.title_label.setText(project_name)

    def eventFilter(self, watched, event):
        if watched is self.config_area and event.type() == QtCore.QEvent.Resize:
            self.reposition_artifacts()
        return super().eventFilter(watched, event)

    def toggle_artifacts(self):
        visible = not self.artifacts_panel.isVisible()
        self.artifacts_panel.setVisible(visible)
        self.drag_handle.setVisible(visible and not self.artifacts_maximized)
        if visible:
            self.reposition_artifacts()
            self.artifacts_panel.raise_()
            self.drag_handle.raise_()

    def toggle_artifacts_maximized(self):
        if not self.artifacts_panel.isVisible():
            return
        if self.artifacts_maximized:
            self.artifacts_maximized = False
            self.artifacts_width = self.restore_artifacts_width
            self.drag_handle.show()
        else:
            self.restore_artifacts_width = self.artifacts_panel.width()
            self.artifacts_maximized = True
            self.drag_handle.hide()
        self.reposition_artifacts()

    def reposition_artifacts(self):
        if not self.artifacts_panel.isVisible():
            return
        total_width = self.config_area.width()
        total_height = self.config_area.height()
        if total_width <= 0 or total_height <= 0:
            return
        minimum = min(300, total_width)
        panel_width = (
            total_width
            if self.artifacts_maximized
            else max(minimum, min(self.artifacts_width, total_width))
        )
        panel_x = total_width - panel_width
        self.artifacts_panel.setGeometry(panel_x, 0, panel_width, total_height)
        handle_x = panel_x - self.drag_handle.width() // 2
        handle_y = (total_height - self.drag_handle.height()) // 2
        self.drag_handle.setGeometry(handle_x, handle_y, 14, 36)
        self.artifacts_panel.raise_()
        self.drag_handle.raise_()

    def handle_artifacts_drag(self, action, global_x):
        if action == "start":
            self.drag_start_global_x = global_x
            self.drag_start_width = self.artifacts_panel.width()
            return
        if action != "move" or self.drag_start_global_x is None:
            return
        delta = self.drag_start_global_x - global_x
        maximum = self.config_area.width()
        minimum = min(300, maximum)
        self.artifacts_width = max(
            minimum, min(self.drag_start_width + delta, maximum)
        )
        self.reposition_artifacts()

    def finish_artifacts_drag(self):
        self.drag_start_global_x = None
        self.drag_start_width = None
