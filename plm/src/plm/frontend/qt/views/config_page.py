from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import make_icon_button, rounded_widget_region
from plm.frontend.qt.widgets.config_editor import CsvTableEditor, GenerationEditor
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.styles.tokens import (
    SPACING_LG, SPACING_MD,
)


class ConfigTabBar(QtWidgets.QTabBar):
    """Keep the full label visible when the selected tab becomes bold."""

    def tabSizeHint(self, index):
        self.ensurePolished()
        option = QtWidgets.QStyleOptionTab()
        self.initStyleOption(option, index)
        font = QtGui.QFont(self.font())
        font.setBold(True)
        metrics = QtGui.QFontMetrics(font)
        text_width = max(metrics.horizontalAdvance(option.text),
                         metrics.boundingRect(option.text).width())
        size = self.style().sizeFromContents(
            QtWidgets.QStyle.CT_TabBarTab, option,
            QtCore.QSize(text_width + 2, metrics.height()), self,
        )
        return super().tabSizeHint(index).expandedTo(size)

    def minimumTabSizeHint(self, index):
        return self.tabSizeHint(index)


class EscapeLineEdit(QtWidgets.QLineEdit):
    escapePressed = QtCore.pyqtSignal()
    focusLost = QtCore.pyqtSignal()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.escapePressed.emit()
            event.accept()
            return
        super().keyPressEvent(event)

    def focusOutEvent(self, event):
        super().focusOutEvent(event)
        # Also finish when the name is unchanged; editingFinished may not fire.
        if event.reason() != QtCore.Qt.PopupFocusReason:
            self.focusLost.emit()


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
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setFixedHeight(48)
        self._original_title = ""
        self._editing_title = False
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(SPACING_LG, 0, 0, 0)
        layout.setSpacing(0)
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
        self.title_edit.focusLost.connect(self.save_title)
        self.title_edit.escapePressed.connect(self.cancel_title)
        layout.addWidget(self.title_edit, 0, QtCore.Qt.AlignVCenter)
        layout.addStretch(1)
        self.log_btn = make_icon_button(
            "panel-bottom", "显示/隐藏输出面板", "HeaderButton", 46, 18
        )
        self.artifacts_btn = make_icon_button(
            "panel-right", "显示/隐藏 Artifacts", "HeaderButton", 46, 18
        )
        self.log_btn.setFixedSize(46, self.height())
        self.artifacts_btn.setFixedSize(46, self.height())
        self.log_btn.clicked.connect(self.logToggleRequested.emit)
        self.artifacts_btn.clicked.connect(self.artifactsToggleRequested.emit)
        layout.addWidget(self.log_btn, 0, QtCore.Qt.AlignVCenter)
        layout.addWidget(self.artifacts_btn, 0, QtCore.Qt.AlignVCenter)

    def enter_edit_mode(self):
        self._original_title = self.title_label.text()
        self._editing_title = True
        self.title_edit.setText(self._original_title)
        self.title_label.hide()
        self.title_edit.show()
        self.title_edit.selectAll()
        self.title_edit.setFocus(QtCore.Qt.OtherFocusReason)

    def save_title(self):
        if not self._editing_title:
            return
        self._editing_title = False
        new_title = self.title_edit.text().strip() or self._original_title
        self.title_label.setText(new_title)
        self.title_edit.hide()
        self.title_label.show()
        self.titleChanged.emit(new_title)

    def cancel_title(self):
        if not self._editing_title:
            return
        self._editing_title = False
        self.title_edit.hide()
        self.title_label.setText(self._original_title)
        self.title_label.show()


class ConfigTabPage(QtWidgets.QWidget):
    def __init__(self, editor, fill_editor=False, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigTabPage")
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(SPACING_LG, SPACING_LG, SPACING_LG, SPACING_LG)
        root.setSpacing(0)

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


class ConfigPage(QtWidgets.QFrame):
    """Region 2 with an absolute-positioned Region 5 overlay."""

    MAX_HISTORY = 50

    logToggleRequested = QtCore.pyqtSignal()
    dirtyChanged = QtCore.pyqtSignal(bool)
    generateRequested = QtCore.pyqtSignal()
    historyChanged = QtCore.pyqtSignal()

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.setObjectName("ConfigPage")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.dirty = False
        self.validation_issues = ()
        self._first_error = None
        self._history = []
        self._history_index = -1
        self._saved_content = None
        self.artifacts_width = 380
        self.restore_artifacts_width = 380
        self.artifacts_maximized = False

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        self.header = ConfigHeader()
        self.header.logToggleRequested.connect(self.logToggleRequested.emit)
        self.header.artifactsToggleRequested.connect(self.toggle_artifacts)
        root.addWidget(self.header)
        root.addSpacing(SPACING_MD)

        self.config_area = QtWidgets.QWidget()
        self.config_area.setObjectName("ConfigArea")
        config_layout = QtWidgets.QVBoxLayout(self.config_area)
        config_layout.setContentsMargins(0, 0, 0, 0)
        self.tabs = QtWidgets.QTabWidget()
        self.tabs.setObjectName("ConfigTabs")
        self.tabs.setTabBar(ConfigTabBar(self.tabs))
        self.tabs.tabBar().setExpanding(False)
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
        for tab_name, editor, fill_editor in (
            ("Controller", self.controllers_editor, True),
            ("LaneMapping", self.mapping_editor, True),
            ("Signals", self.signals_editor, True),
            ("Generation", self.generation_editor, False),
        ):
            self.tabs.addTab(
                ConfigTabPage(editor, fill_editor=fill_editor), tab_name
            )
        config_layout.addWidget(self.tabs, 1)
        root.addWidget(self.config_area, 1)

        self.artifacts_panel = ArtifactsPanel(
            self.config_area, editor_path_provider=editor_path_provider
        )
        self.artifacts_panel.maximizeRequested.connect(self.toggle_artifacts_maximized)
        self.artifacts_panel.widthRequested.connect(self._on_artifacts_width_requested)
        self._artifacts_animation = QtCore.QPropertyAnimation(
            self.artifacts_panel, b"geometry", self
        )
        self._artifacts_animation.setDuration(200)
        self._artifacts_animation.setEasingCurve(QtCore.QEasingCurve.OutCubic)
        self._hide_artifacts_after_animation = False
        self._artifacts_animation.finished.connect(
            self._finish_artifacts_animation
        )
        self.tabs.currentChanged.connect(
            lambda _index: self.artifacts_panel.raise_()
            if self.artifacts_panel.isVisible() else None
        )
        self.artifacts_panel.hide()
        self.config_area.installEventFilter(self)

    def update_title(self, project_name):
        self.header.title_label.setText(project_name)

    def _mark_dirty(self):
        self.mapping_editor.controllers = self.controllers_editor.rows()
        payload = self.content()
        if self._history and payload == self._history[self._history_index]:
            return
        self._history = self._history[:self._history_index + 1]
        self._history.append(payload)
        if len(self._history) > self.MAX_HISTORY:
            del self._history[:-self.MAX_HISTORY]
        self._history_index = len(self._history) - 1
        self._update_dirty()
        self.historyChanged.emit()

    def _update_dirty(self):
        self.dirty = self.content() != self._saved_content
        self.dirtyChanged.emit(self.dirty)

    def mark_saved(self):
        self._saved_content = self.content()
        self._update_dirty()

    def finish_editing(self):
        focus = QtWidgets.QApplication.focusWidget()
        for editor in (self.controllers_editor, self.mapping_editor, self.signals_editor):
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
        self._history = [self.content()]
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

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.setMask(rounded_widget_region(self.rect(), (12, 8, 8, 8)))

    def toggle_artifacts(self):
        target = self._artifacts_target_geometry()
        if target is None:
            self.artifacts_panel.setVisible(not self.artifacts_panel.isVisible())
            return
        reopening = (
            self._artifacts_animation.state() == QtCore.QAbstractAnimation.Running
            and self._hide_artifacts_after_animation
        )
        if not self.artifacts_panel.isVisible() or reopening:
            start = (
                self.artifacts_panel.geometry()
                if reopening
                else QtCore.QRect(
                    self.config_area.width(), 0, 0, target.height()
                )
            )
            self._animate_artifacts(start, target, hide_after=False)
            return
        end = QtCore.QRect(
            self.config_area.width(),
            0,
            0,
            self.config_area.height(),
        )
        self._animate_artifacts(
            self.artifacts_panel.geometry(), end, hide_after=True
        )

    def toggle_artifacts_maximized(self):
        if not self.artifacts_panel.isVisible():
            return
        if self.artifacts_maximized:
            self.artifacts_maximized = False
            self.artifacts_width = self.restore_artifacts_width
        else:
            self.restore_artifacts_width = self.artifacts_panel.width()
            self.artifacts_maximized = True
        self.artifacts_panel.set_maximized(self.artifacts_maximized)
        self.reposition_artifacts()

    def _artifacts_target_geometry(self):
        total_w = self.config_area.width()
        total_h = self.config_area.height()
        if total_w <= 0 or total_h <= 0:
            return None
        panel_w = (
            total_w
            if self.artifacts_maximized
            else min(self.artifacts_width, total_w)
        )
        return QtCore.QRect(total_w - panel_w, 0, panel_w, total_h)

    def _animate_artifacts(self, start, end, hide_after):
        self._artifacts_animation.stop()
        self._hide_artifacts_after_animation = hide_after
        self.artifacts_panel.setGeometry(start)
        self.artifacts_panel.show()
        self.artifacts_panel.raise_()
        self._artifacts_animation.setStartValue(start)
        self._artifacts_animation.setEndValue(end)
        self._artifacts_animation.start()

    def _finish_artifacts_animation(self):
        if self._hide_artifacts_after_animation:
            self.artifacts_panel.hide()
        self._hide_artifacts_after_animation = False

    def reposition_artifacts(self):
        if self._artifacts_animation.state() == QtCore.QAbstractAnimation.Running:
            self._artifacts_animation.stop()
            if self._hide_artifacts_after_animation:
                self.artifacts_panel.hide()
            self._hide_artifacts_after_animation = False
        if not self.artifacts_panel.isVisible():
            return
        target = self._artifacts_target_geometry()
        if target is None:
            return
        self.artifacts_panel.setGeometry(target)
        self.artifacts_panel.raise_()

    def _on_artifacts_width_requested(self, width):
        if self.artifacts_maximized:
            return
        maximum = max(1, self.config_area.width())
        minimum = min(300, maximum)
        self.artifacts_width = max(minimum, min(int(width), maximum))
        self.reposition_artifacts()
