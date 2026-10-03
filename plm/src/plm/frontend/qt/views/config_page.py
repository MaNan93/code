from PyQt5 import QtCore, QtGui, QtWidgets
from copy import deepcopy
from plm.frontend.qt.widgets.common import apply_drop_shadow, make_icon_button
from plm.frontend.qt.widgets.config_editor import CsvTableEditor, GenerationEditor
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
    def __init__(self, title, description, editor, fill_editor=False, parent=None):
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
        content_layout.setSpacing(0)
        content_layout.addWidget(editor, 1 if fill_editor else 0)
        if not fill_editor:
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
    dirtyChanged = QtCore.pyqtSignal(bool)
    generateRequested = QtCore.pyqtSignal()
    historyChanged = QtCore.pyqtSignal()

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.setObjectName("ConfigPage")
        self.dirty = False
        self._history = []
        self._history_index = -1
        self._saved_content = None
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
        self.controllers_editor = CsvTableEditor(("ctrl_id", "ctrl_name", "max_width"))
        self.mapping_editor = CsvTableEditor(("mode", "lane0", "lane1", "lane2", "lane3"), mapping=True)
        self.signals_editor = CsvTableEditor((
            "signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"
        ))
        self.generation_editor = GenerationEditor()
        for editor in (self.controllers_editor, self.mapping_editor, self.signals_editor,
                       self.generation_editor):
            editor.changed.connect(self._mark_dirty)
        self.generation_editor.generateRequested.connect(self.generateRequested.emit)
        for tab_name, title, description, editor, fill_editor in (
            ("Controller", "Controller Configuration", "配置控制器 ID、名称和最大 Lane 宽度。", self.controllers_editor, False),
            ("LaneMapping", "Lane Mapping Configuration", "配置物理 Lane 与控制器 Lane 的映射关系。", self.mapping_editor, False),
            ("Signals", "PIPE Signals", "配置 PIPE 信号、方向、位宽与安全值。", self.signals_editor, True),
            ("Generation", "Generation Settings", "选择生成参数并生成匹配的 RTL 和 Testbench。", self.generation_editor, False),
        ):
            self.tabs.addTab(
                ConfigTabPage(title, description, editor, fill_editor=fill_editor), tab_name
            )
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

    def _mark_dirty(self):
        self.mapping_editor.controllers = self.controllers_editor.rows()
        payload = self.content()
        if self._history and payload == self._history[self._history_index]:
            return
        self._history = self._history[:self._history_index + 1]
        self._history.append(deepcopy(payload))
        self._history_index += 1
        self._update_dirty()
        self.historyChanged.emit()

    def _update_dirty(self):
        self.dirty = self.content() != self._saved_content
        self.dirtyChanged.emit(self.dirty)

    def mark_saved(self):
        self._saved_content = deepcopy(self.content())
        self._update_dirty()

    def finish_editing(self):
        focus = QtWidgets.QApplication.focusWidget()
        for editor in (self.controllers_editor, self.mapping_editor, self.signals_editor):
            editor.table.itemDelegate().finish_editing()
            if focus and editor.table.isAncestorOf(focus):
                editor.table.setFocus()
                break

    def can_undo(self):
        return self._history_index > 0

    def can_redo(self):
        return self._history_index + 1 < len(self._history)

    def undo(self):
        self.finish_editing()
        if self.can_undo():
            self._history_index -= 1
            self._load_content(self._history[self._history_index])
            self._update_dirty()
            self.historyChanged.emit()

    def redo(self):
        self.finish_editing()
        if self.can_redo():
            self._history_index += 1
            self._load_content(self._history[self._history_index])
            self._update_dirty()
            self.historyChanged.emit()

    def set_content(self, payload):
        self._load_content(payload)
        self._history = [deepcopy(self.content())]
        self._history_index = 0
        self.mark_saved()
        self.historyChanged.emit()

    def _load_content(self, payload):
        self.controllers_editor.set_rows(payload.get("controllers", []))
        self.mapping_editor.controllers = self.controllers_editor.rows()
        mapping = payload.get("mapping") or {}
        lanes = int(mapping.get("lane_count") or 4)
        self.mapping_editor.set_rows(mapping.get("rows", []), ["mode"] + [
            f"lane{index}" for index in range(lanes)
        ])
        self.signals_editor.set_rows(payload.get("signals", []))
        self.generation_editor.set_flags(payload.get("gen_flags") or {})

    def set_validation_issues(self, issues):
        self.validation_issues = tuple(issues)
        self._first_error = None
        first_issue_index = len(issues)
        for tab, name, editor in ((0, "controllers", self.controllers_editor),
                                  (1, "mapping", self.mapping_editor),
                                  (2, "signals", self.signals_editor)):
            errors = {}
            columns = editor.columns()
            for issue_index, issue in enumerate(issues):
                if issue.table != name or issue.row is None or issue.column is None:
                    continue
                col = columns.index(issue.column) if issue.column in columns else issue.column
                row = issue.row
                if name == "controllers" and issue.layer == "topology":
                    row = next((i for i, value in enumerate(editor.rows()) if value["ctrl_id"] == str(issue.row)), row)
                if isinstance(col, int) and 0 <= col < len(columns) and 0 <= row < editor.table.rowCount():
                    errors[(row, col)] = str(issue)
                    if issue_index < first_issue_index:
                        first_issue_index = issue_index
                        self._first_error = (tab, editor.table, row, col)
            editor.set_cell_errors(errors)
        self.header.setToolTip("\n".join(str(issue) for issue in issues))
        self.generation_editor.setToolTip("\n".join(str(issue) for issue in issues if issue.layer == "generation"))

    def focus_first_error(self):
        if self._first_error:
            tab, table, row, col = self._first_error
            self.tabs.setCurrentIndex(tab)
            table.setCurrentCell(row, col)
            table.scrollToItem(table.item(row, col))
            table.setFocus()
        elif any(issue.layer == "generation" for issue in self.validation_issues):
            self.tabs.setCurrentIndex(3)

    def content(self):
        return {
            "controllers": self.controllers_editor.rows(),
            "mapping": {
                "lane_count": self.mapping_editor.lane_count.value(),
                "rows": self.mapping_editor.rows(),
            },
            "signals": self.signals_editor.rows(),
            "gen_flags": self.generation_editor.flags(),
        }

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
        else:
            self._resize_editors(self.config_area.width() - 48)

    def _resize_editors(self, available_width):
        for editor in (self.controllers_editor, self.mapping_editor,
                       self.signals_editor, self.generation_editor):
            editor.setMaximumWidth(max(280, available_width))

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
        self._resize_editors(panel_x - 48)
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
