from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import (
    RoundedCanvasFrame,
)
from plm.frontend.qt.widgets.config_editor import CsvTableEditor, GenerationEditor
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.styles.tokens import (
    CONTROL_HEIGHT, HEADER_HEIGHT, SPACING_LG, SPACING_MD,
    ARTIFACTS_DEFAULT_WIDTH, ARTIFACTS_MIN_WIDTH,
    PANEL_ANIMATION_DURATION,
)


class ConfigTabBar(QtWidgets.QTabBar):
    """Keep the full label visible when the selected tab becomes bold."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setDrawBase(False)  # Suppress the native frame behind the QSS underline.
        self.setElideMode(QtCore.Qt.ElideNone)

    def tabSizeHint(self, index):
        self.ensurePolished()
        option = QtWidgets.QStyleOptionTab()
        self.initStyleOption(option, index)
        font = QtGui.QFont(self.font())
        font.setBold(True)
        metrics = QtGui.QFontMetrics(font)
        text_width = max(metrics.horizontalAdvance(option.text),
                         metrics.boundingRect(option.text).width())
        content_size = QtCore.QSize(text_width, metrics.height())
        styled_size = self.style().sizeFromContents(
            QtWidgets.QStyle.CT_TabBarTab, option, content_size, self,
        )
        result = super().tabSizeHint(index).expandedTo(styled_size)
        result.setHeight(CONTROL_HEIGHT)
        return result

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
    """Region 2.1: editable project title and dirty status."""

    titleChanged = QtCore.pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigHeader")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setFixedHeight(HEADER_HEIGHT)
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
        layout.addSpacing(SPACING_MD)
        self.status_badge = QtWidgets.QLabel()
        self.status_badge.setObjectName("ConfigProjectStatus")
        self.status_badge.setProperty("dirty", False)
        self.status_badge.setFixedSize(8, 8)
        self.status_badge.setToolTip("有未保存的修改")
        self.status_badge.setAccessibleName("有未保存的修改")
        self.status_badge.hide()
        layout.addWidget(self.status_badge, 0, QtCore.Qt.AlignVCenter)
        layout.addStretch(1)

    def set_dirty(self, dirty):
        self.status_badge.setProperty("dirty", bool(dirty))
        self.status_badge.setVisible(bool(dirty))
        self.status_badge.style().unpolish(self.status_badge)
        self.status_badge.style().polish(self.status_badge)

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
        self.scroll = None
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(SPACING_LG, SPACING_LG, SPACING_LG, SPACING_LG)
        root.setSpacing(0)

        if isinstance(editor, CsvTableEditor):
            # CSV tables own their scrolling and keep the header visible.
            root.addWidget(editor, 1)
            return

        scroll = QtWidgets.QScrollArea()
        self.scroll = scroll
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
        footer = getattr(editor, "footer", None)
        if footer is not None:
            root.addWidget(footer)


class ConfigPage(RoundedCanvasFrame):
    """Region 2 with an absolute-positioned Region 5 overlay."""

    MAX_HISTORY = 50
    BORDER_WIDTH = 0.0  # Let the white canvas meet the gray underlay directly.

    dirtyChanged = QtCore.pyqtSignal(bool)
    generateRequested = QtCore.pyqtSignal()
    historyChanged = QtCore.pyqtSignal()

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.setObjectName("ConfigPage")
        self.dirty = False
        self.validation_issues = ()
        self._first_error = None
        self._history = []
        self._history_index = -1
        self._typing_key = None
        self._saved_content = None
        self.artifacts_width = ARTIFACTS_DEFAULT_WIDTH
        self.restore_artifacts_width = ARTIFACTS_DEFAULT_WIDTH
        self.artifacts_maximized = False

        root = QtWidgets.QVBoxLayout(self)
        # Keep opaque content above the bottom corner arcs; no binary mask.
        root.setContentsMargins(1, 1, 1, self.CORNER_RADII[2])
        root.setSpacing(0)
        self.header = ConfigHeader()
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
            self, editor_path_provider=editor_path_provider
        )
        self.artifacts_panel.maximizeRequested.connect(self.toggle_artifacts_maximized)
        self.artifacts_panel.closeRequested.connect(self.hide_artifacts)
        self.artifacts_panel.widthRequested.connect(self._on_artifacts_width_requested)
        self._artifacts_animation = QtCore.QPropertyAnimation(
            self.artifacts_panel, b"geometry", self
        )
        self._artifacts_animation.setDuration(PANEL_ANIMATION_DURATION)
        self._artifacts_animation.setEasingCurve(QtCore.QEasingCurve.OutCubic)
        self._hide_artifacts_after_animation = False
        self._artifacts_animation.finished.connect(
            self._finish_artifacts_animation
        )
        self.tabs.currentChanged.connect(self._raise_artifacts)
        self.artifacts_panel.hide()
        self.installEventFilter(self)

    def _raise_artifacts(self, *_args):
        if self.artifacts_panel.isVisible():
            self.artifacts_panel.raise_()

    def update_title(self, project_name):
        self.header.title_label.setText(project_name)

    def _mark_dirty(self):
        self.mapping_editor.controllers = self.controllers_editor.rows()
        payload = self.content()
        if self._history and payload == self._history[self._history_index]:
            return
        typing_key = self._typed_field(self._history[self._history_index], payload) if self._history else None
        at_tip = self._history_index == len(self._history) - 1
        if typing_key is not None and typing_key == self._typing_key and at_tip and self._history_index > 0:
            # Consecutive keystrokes in one text field are a single edit.
            self._history[self._history_index] = payload
            self._update_dirty()
            self.historyChanged.emit()
            return
        self._typing_key = typing_key
        self._history = self._history[:self._history_index + 1]
        self._history.append(payload)
        if len(self._history) > self.MAX_HISTORY:
            del self._history[:-self.MAX_HISTORY]
        self._history_index = len(self._history) - 1
        self._update_dirty()
        self.historyChanged.emit()

    @staticmethod
    def _typed_field(before, after):
        """Name the one free-text generation field that differs, if that is all."""
        if {key: value for key, value in before.items() if key != "gen_flags"} != {
            key: value for key, value in after.items() if key != "gen_flags"
        }:
            return None
        old, new = before.get("gen_flags") or {}, after.get("gen_flags") or {}
        changed = [key for key in set(old) | set(new) if old.get(key) != new.get(key)]
        if len(changed) == 1 and changed[0] in ("module_prefix", "file_prefix", "macro_prefix"):
            return changed[0]
        return None

    def _update_dirty(self):
        self.dirty = self.content() != self._saved_content
        self.header.set_dirty(self.dirty)
        self.dirtyChanged.emit(self.dirty)

    def mark_saved(self, payload=None):
        self._saved_content = self.content() if payload is None else payload
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
        self._typing_key = None
        if self.can_undo():
            self._history_index -= 1
            self._load_content(self._history[self._history_index])
            self._update_dirty()
            self.historyChanged.emit()

    def redo(self):
        self.finish_editing()
        self._typing_key = None
        if self.can_redo():
            self._history_index += 1
            self._load_content(self._history[self._history_index])
            self._update_dirty()
            self.historyChanged.emit()

    def set_content(self, payload):
        self._load_content(payload)
        self._history = [self.content()]
        self._history_index = 0
        self._typing_key = None
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
                # Every layer reports the table row, never a ctrl_id.
                row = issue.row
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
        if event.type() == QtCore.QEvent.Resize and watched is self:
            self.reposition_artifacts()
        return super().eventFilter(watched, event)

    def toggle_artifacts(self):
        target = self._artifacts_rect("maximized" if self.artifacts_maximized else "expanded")
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
                else self._artifacts_rect("collapsed")
            )
            self._animate_artifacts(start, target, hide_after=False)
            return
        self.hide_artifacts()

    def hide_artifacts(self):
        if not self.artifacts_panel.isVisible():
            return
        end = self._artifacts_rect("collapsed")
        if end is None:
            self.artifacts_panel.hide()
            return
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

    def _artifacts_rect(self, state):
        """Return the drawer rectangle for one of its three layout states."""
        total_w = self.width()
        total_h = self.height()
        if total_w <= 0 or total_h <= 0:
            return None
        if state == "collapsed":
            panel_w = 0
        elif state == "maximized":
            panel_w = total_w
        elif state == "expanded":
            panel_w = min(total_w, max(ARTIFACTS_MIN_WIDTH, self.artifacts_width))
        else:
            raise ValueError(f"Unknown artifacts state: {state}")
        return QtCore.QRect(total_w - panel_w, 0, panel_w, total_h)

    def _animate_artifacts(self, start, end, hide_after):
        self._artifacts_animation.stop()
        self._hide_artifacts_after_animation = hide_after
        self.artifacts_panel.setGeometry(start)
        self.artifacts_panel.show()
        self._raise_artifacts()
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
        target = self._artifacts_rect("maximized" if self.artifacts_maximized else "expanded")
        if target is None:
            return
        self.artifacts_panel.setGeometry(target)
        self._raise_artifacts()

    def _on_artifacts_width_requested(self, width):
        if self.artifacts_maximized:
            return
        self.artifacts_width = int(width)
        target = self._artifacts_rect("expanded")
        if target is not None:
            self.artifacts_width = target.width()
        self.reposition_artifacts()
