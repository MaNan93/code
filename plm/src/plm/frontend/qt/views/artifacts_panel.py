"""Generated-file tree and previews in the floating Artifacts panel."""

import difflib
import shutil
import subprocess
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.models.artifacts import ArtifactSelection
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.widgets.code_preview import CodePreview
from plm.frontend.qt.widgets.common import (
    ICON_SIZE, StyledMenu, apply_drop_shadow, load_lucide_icon, make_icon_button, open_in_file_manager,
)
from plm.frontend.qt.styles.tokens import PRIMARY, SUCCESS, TEXT_MUTED


_STATUS_COLORS = {
    "New": SUCCESS,
    "Modified": PRIMARY,
    "Unchanged": TEXT_MUTED,
}


class ArtifactsPanel(QtWidgets.QFrame):
    maximizeRequested = QtCore.pyqtSignal()
    refreshRequested = QtCore.pyqtSignal()
    widthRequested = QtCore.pyqtSignal(int)
    RESIZE_EDGE_WIDTH = 6

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.editor_path_provider = editor_path_provider or (lambda: DEFAULT_EDITOR)
        self.workspace_root = None
        self.selection = ArtifactSelection()
        self._tree_items = {}
        self._readable = False
        self._file_status = "尚无生成文件"
        self._file_error = ""
        self._output_state = "no_project"
        self._output_text = ""
        self._output_detail = ""
        self._file_statuses = {}
        self._current_contents = {}
        self._previous_contents = {}
        self.is_maximized = False
        self._resize_origin_x = None
        self._resize_origin_width = None
        self.setObjectName("ArtifactsPanel")
        self.setMouseTracking(True)
        apply_drop_shadow(self, offset=(-4, 0), blur_radius=16, alpha=36)

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(16, 0, 16, 16)
        root.setSpacing(12)
        toolbar = QtWidgets.QWidget()
        self.toolbar = toolbar
        toolbar.setObjectName("ArtifactsToolbar")
        toolbar.setFixedHeight(40)
        toolbar_layout = QtWidgets.QHBoxLayout(toolbar)
        self.toolbar_layout = toolbar_layout
        toolbar_layout.setContentsMargins(16, 0, 16, 0)
        toolbar_layout.setSpacing(8)
        self.toolbar_buttons = []
        # Keep the original 0..8 public toolbar list stable. Diff is a new
        # control, but is intentionally separate from that compatibility list.
        for index, (icon, tooltip) in enumerate((
            ("folder", "打开输出文件夹"),
            ("refresh-cw", "刷新文件"),
            ("square-pen", "在编辑器中打开"),
            ("braces", "Verilog 语法高亮"),
            ("search", "搜索文件内容 (Ctrl+F)"),
            ("link", "复制文件路径"),
            ("file", "显示/隐藏文件树"),
            ("more-horizontal", "更多"),
            ("maximize", "展开"),
        )):
            button = make_icon_button(icon, tooltip, "ArtifactsToolButton", 28, ICON_SIZE)
            toolbar_layout.addWidget(button)
            self.toolbar_buttons.append(button)
            if index == 0:
                toolbar_layout.addStretch(1)
        self.diff_button = make_icon_button(
            "git-compare", "显示与上一次预览的差异", "ArtifactsToolButton", 28, ICON_SIZE
        )
        toolbar_layout.addWidget(self.diff_button)
        root.addWidget(toolbar)

        self.file_tree = QtWidgets.QTreeWidget(self)
        self.file_tree.setObjectName("ArtifactFileTree")
        self.file_tree.setHeaderHidden(True)
        self.file_tree.setIndentation(16)
        self.file_tree.setMaximumHeight(190)
        self.file_tree.itemClicked.connect(self._tree_item_clicked)
        root.addWidget(self.file_tree)
        self.file_tree.hide()

        self.search_bar = QtWidgets.QWidget()
        self.search_bar.setObjectName("ArtifactSearchBar")
        search_layout = QtWidgets.QHBoxLayout(self.search_bar)
        search_layout.setContentsMargins(0, 0, 12, 0)
        search_layout.setSpacing(8)
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setObjectName("ArtifactSearchInput")
        self.search_input.setPlaceholderText("搜索当前文件")
        self.search_status = QtWidgets.QLabel()
        search_layout.addWidget(self.search_input, 1)
        search_layout.addWidget(self.search_status)
        for label, tooltip, callback in (
            ("↑", "上一个 (Shift+F3)", lambda: self.find_text(True)),
            ("↓", "下一个 (F3)", self.find_text),
            ("×", "关闭搜索", self.hide_search),
        ):
            button = QtWidgets.QPushButton(label)
            button.setObjectName("ArtifactsToolButton")
            button.setFixedSize(24, 24)
            button.setToolTip(tooltip)
            button.clicked.connect(callback)
            search_layout.addWidget(button)
        root.addWidget(self.search_bar)
        self.search_bar.hide()

        self.empty_state = QtWidgets.QWidget()
        empty_layout = QtWidgets.QVBoxLayout(self.empty_state)
        empty_layout.setContentsMargins(0, 0, 0, 0)
        empty_layout.setSpacing(8)
        empty_layout.addSpacing(52)
        empty_icon = QtWidgets.QLabel()
        empty_icon.setAlignment(QtCore.Qt.AlignCenter)
        empty_icon.setPixmap(load_lucide_icon("file-x", TEXT_MUTED, 48).pixmap(48, 48))
        empty_layout.addWidget(empty_icon)
        self.empty_text = QtWidgets.QLabel("暂无生成文件")
        self.empty_text.setObjectName("ArtifactEmptyText")
        self.empty_text.setAlignment(QtCore.Qt.AlignCenter)
        empty_layout.addWidget(self.empty_text)
        empty_layout.addStretch(1)
        root.addWidget(self.empty_state, 1)

        self.preview = CodePreview()
        self.preview.setPlaceholderText("尚无生成文件")
        root.addWidget(self.preview, 1)
        self.status = QtWidgets.QLabel("尚无生成文件")
        self.status.setObjectName("ArtifactStatus")
        root.addWidget(self.status)

        self.search_input.textChanged.connect(self._search_changed)
        self.search_input.returnPressed.connect(self.find_text)
        self.highlight_button = self.toolbar_buttons[3]
        self.highlight_button.setCheckable(True)
        self.highlight_button.setChecked(True)
        self.highlight_button.toggled.connect(self._update_highlighting)
        self.tree_button = self.toolbar_buttons[6]
        self.tree_button.setCheckable(True)
        self.tree_button.setChecked(False)
        self.tree_button.toggled.connect(self._set_tree_visible)
        self.diff_button.setCheckable(True)
        self.diff_button.toggled.connect(self._load_selected)

        for index, callback in (
            (0, self.open_folder),
            (1, self.refreshRequested.emit),
            (2, self.open_in_editor),
            (4, self.show_search),
            (5, self.copy_path),
            (8, self.maximizeRequested.emit),
        ):
            self.toolbar_buttons[index].clicked.connect(callback)

        self.more_menu = StyledMenu(self)
        self.more_menu.addAction("打开输出文件夹", self.open_folder)
        self.more_menu.addAction("刷新文件", self.refreshRequested.emit)
        self.more_menu.addAction("在编辑器中打开", self.open_in_editor)
        self.more_menu.addAction("搜索当前文件", self.show_search)
        self.more_menu.addAction("复制文件路径", self.copy_path)
        self.more_menu.addAction("显示/隐藏文件树", self.tree_button.toggle)
        self.more_menu.addAction("切换 Verilog 高亮", self.highlight_button.toggle)
        self.more_menu.addAction("显示/隐藏差异", self.diff_button.toggle)
        self.more_menu.addSeparator()
        self.copy_content_action = self.more_menu.addAction("复制文件内容", self.copy_contents)
        self.toolbar_buttons[7].setMenu(self.more_menu)
        for key, callback in (
            ("Ctrl+F", self.show_search),
            ("F3", self.find_text),
            ("Shift+F3", lambda: self.find_text(True)),
            ("Shift+Return", lambda: self.find_text(True)),
            ("Escape", self.hide_search),
        ):
            shortcut = QtWidgets.QShortcut(QtGui.QKeySequence(key), self)
            shortcut.setContext(QtCore.Qt.WidgetWithChildrenShortcut)
            shortcut.activated.connect(callback)
        self.preview.viewport().installEventFilter(self)
        self.file_tree.viewport().installEventFilter(self)
        self.set_files([])
        self._apply_toolbar_density(self.width())

    def _read_contents(self, files):
        contents = {}
        for value in files:
            path = Path(value).resolve()
            try:
                contents[str(path)] = path.read_text(encoding="utf-8")
            except (OSError, UnicodeError):
                continue
        return contents

    def set_files(self, files, root=None, statuses=None):
        root = Path(root).resolve() if root is not None else None
        files = [Path(value).resolve() for value in files]
        self.selection.set_files(files, keep_current=root == self.workspace_root)
        files = self.selection.files
        if root == self.workspace_root:
            self._previous_contents = dict(self._current_contents)
        else:
            self._previous_contents = {}
        self._current_contents = self._read_contents(files)
        self._file_statuses = dict(statuses or {})
        self.workspace_root = root

        self._rebuild_tree(files, root)
        self._load_selected()

    @property
    def current_path(self):
        return self.selection.current_path

    def select_file(self, path):
        if not self.selection.select(path):
            return False
        self._load_selected()
        return True

    def _rebuild_tree(self, files, root):
        self.file_tree.clear()
        self._tree_items.clear()
        nodes = {}
        selected_item = None
        for path in files:
            try:
                relative = path.relative_to(root) if root else Path(path.name)
            except ValueError:
                relative = Path(path.name)
            parent = self.file_tree.invisibleRootItem()
            parts = relative.parts
            for index, part in enumerate(parts):
                key = parts[: index + 1]
                is_file = index == len(parts) - 1
                if key in nodes:
                    parent = nodes[key]
                    continue
                label = part
                if is_file:
                    status = self._file_statuses.get(relative.as_posix(), "")
                    if status:
                        label = f"{part}   {status}"
                item = QtWidgets.QTreeWidgetItem(parent, [label])
                nodes[key] = item
                if is_file:
                    self._tree_items[path] = item
                    item.setData(0, QtCore.Qt.UserRole, str(path))
                    item.setToolTip(0, str(relative))
                    status = self._file_statuses.get(relative.as_posix(), "")
                    if status in _STATUS_COLORS:
                        item.setForeground(0, QtGui.QBrush(QtGui.QColor(_STATUS_COLORS[status])))
                    if self.current_path == path:
                        selected_item = item
                parent = item
        self.file_tree.expandAll()
        if selected_item is not None:
            self.file_tree.setCurrentItem(selected_item)

    def _tree_item_clicked(self, item, _column):
        value = item.data(0, QtCore.Qt.UserRole)
        if not value:
            item.setExpanded(not item.isExpanded())
            return
        if self.select_file(value):
            self.tree_button.setChecked(False)

    def _diff_available(self):
        if self.current_path is None:
            return False
        key = str(self.current_path)
        return (
            key in self._previous_contents
            and key in self._current_contents
            and self._previous_contents[key] != self._current_contents[key]
        )

    def _load_selected(self, *_):
        self.empty_state.setVisible(self.current_path is None)
        self.preview.setVisible(self.current_path is not None)
        self.preview.clear()
        self._readable = False
        self.search_status.clear()
        self.preview.setToolTip(str(self.current_path or ""))
        self._file_error = ""
        text = ""
        if self.current_path is None:
            self.preview.setPlaceholderText("尚无生成文件")
            self._file_status = "尚无生成文件"
        else:
            key = str(self.current_path)
            text = self._current_contents.get(key, "")
            if key not in self._current_contents:
                try:
                    text = self.current_path.read_text(encoding="utf-8")
                except (OSError, UnicodeError) as error:
                    self.preview.setPlaceholderText("无法预览该文件，请刷新或选择其他文件")
                    self._file_status = "无法读取文件"
                    self._file_error = str(error)
                else:
                    self._current_contents[key] = text
                    self._readable = True
            else:
                self._readable = True
            if self._readable:
                self.preview.setPlaceholderText("文件为空")
                if self.diff_button.isChecked() and self._diff_available():
                    previous = self._previous_contents[key]
                    relative = self.current_path.name
                    if self.workspace_root is not None:
                        try:
                            relative = self.current_path.relative_to(self.workspace_root).as_posix()
                        except ValueError:
                            pass
                    text = "".join(difflib.unified_diff(
                        previous.splitlines(keepends=True),
                        text.splitlines(keepends=True),
                        fromfile=f"previous/{relative}",
                        tofile=f"current/{relative}",
                    ))
                self.preview.setPlainText(text)
                self.preview.moveCursor(QtGui.QTextCursor.Start)
                self.preview.horizontalScrollBar().setValue(0)
                self._file_status = (
                    f"{self.selection.current_index + 1}/{len(self.selection.files)}"
                    f" · {len(text.splitlines())} 行"
                )
        diff_available = self._diff_available()
        self.diff_button.setEnabled(diff_available)
        if not diff_available and self.diff_button.isChecked():
            self.diff_button.blockSignals(True)
            self.diff_button.setChecked(False)
            self.diff_button.blockSignals(False)
        self._update_status()
        self._update_highlighting()
        self.preview.line_numbers.setVisible(self._readable)
        for index in (0, 2, 5):
            self.toolbar_buttons[index].setEnabled(self.current_path is not None)
        self.toolbar_buttons[4].setEnabled(self._readable)
        self.copy_content_action.setEnabled(self._readable)
        if self._readable and self.search_input.text():
            self._search_changed()
        self._select_tree_path()

    def _select_tree_path(self):
        item = self._tree_items.get(self.current_path)
        if item is not None:
            self.file_tree.setCurrentItem(item)

    def set_output_state(self, state, text, detail=""):
        self._output_state = state
        self._output_text = text
        self._output_detail = detail
        self.status.setProperty("state", state)
        self.status.style().unpolish(self.status)
        self.status.style().polish(self.status)
        self._update_status()

    def _update_status(self):
        parts = [self._file_status] if self.current_path is not None or not self._output_text else []
        # "Up to date" already has a dedicated green status beside Generate.
        # Keep the preview footer focused on file position/line count and only
        # repeat generation state here when it needs attention.
        show_output_state = self._output_text and not (
            self._output_state == "up_to_date" and self.current_path is not None
        )
        if show_output_state:
            parts.append(self._output_text)
        self.status.setText(" · ".join(parts))
        self.status.setToolTip("\n".join(part for part in (self._file_error, self._output_detail) if part))

    def _update_highlighting(self, *_):
        is_verilog = (
            self.current_path is not None
            and self.current_path.suffix.lower() in (".v", ".sv", ".vh", ".svh")
        )
        enabled = self._readable and is_verilog and not self.diff_button.isChecked()
        self.highlight_button.setEnabled(self._readable and is_verilog)
        self.preview.highlighter.set_enabled(enabled and self.highlight_button.isChecked())

    def show_search(self):
        if self._readable:
            self.search_bar.show()
            self.search_input.setFocus()
            self.search_input.selectAll()

    def hide_search(self):
        self.search_bar.hide()
        self.preview.setFocus()

    def _search_changed(self, *_):
        self.preview.moveCursor(QtGui.QTextCursor.Start)
        self.find_text()

    def find_text(self, backwards=False):
        query = self.search_input.text()
        if not query or not self._readable:
            self.search_status.clear()
            return False
        if query.startswith(":"):
            value = query[1:].strip()
            if not value.isdigit() or int(value) < 1:
                self.search_status.setText("无效行号")
                return False
            line = int(value)
            block = self.preview.document().findBlockByNumber(line - 1)
            if not block.isValid():
                self.search_status.setText("行号超出范围")
                return False
            self.preview.setTextCursor(QtGui.QTextCursor(block))
            self.preview.centerCursor()
            self.search_status.setText(f"第 {line} 行")
            return True
        flags = QtGui.QTextDocument.FindBackward if backwards else QtGui.QTextDocument.FindFlags()
        found = self.preview.find(query, flags)
        if not found:
            self.preview.moveCursor(QtGui.QTextCursor.End if backwards else QtGui.QTextCursor.Start)
            found = self.preview.find(query, flags)
        self.search_status.setText("" if found else "未找到")
        return found

    def _set_tree_visible(self, visible):
        self.file_tree.setVisible(visible)

    def _apply_toolbar_density(self, width):
        # Keep file tree, More and maximize always reachable. Less critical
        # controls collapse into More before they can overlap at narrow widths.
        width = int(width)
        self.toolbar_buttons[0].setVisible(width >= 280)
        self.toolbar_buttons[1].setVisible(width >= 320)
        self.highlight_button.setVisible(width >= 360)
        self.toolbar_buttons[2].setVisible(width >= 420)
        self.toolbar_buttons[4].setVisible(width >= 420)
        self.toolbar_buttons[5].setVisible(width >= 470)
        self.diff_button.setVisible(width >= 520)
        for index in (6, 7, 8):
            self.toolbar_buttons[index].show()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._apply_toolbar_density(event.size().width())

    def set_maximized(self, maximized: bool):
        self.is_maximized = bool(maximized)
        if self.is_maximized:
            self._resize_origin_x = None
            self._resize_origin_width = None
            self.unsetCursor()

    def mousePressEvent(self, event):
        if (
            not self.is_maximized
            and event.button() == QtCore.Qt.LeftButton
            and event.pos().x() <= self.RESIZE_EDGE_WIDTH
        ):
            self._resize_origin_x = event.globalPos().x()
            self._resize_origin_width = self.width()
            self.setCursor(QtCore.Qt.SplitHCursor)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if (
            not self.is_maximized
            and self._resize_origin_x is not None
            and event.buttons() & QtCore.Qt.LeftButton
        ):
            delta = self._resize_origin_x - event.globalPos().x()
            self.widthRequested.emit(self._resize_origin_width + delta)
            event.accept()
            return
        if not self.is_maximized and event.pos().x() <= self.RESIZE_EDGE_WIDTH:
            self.setCursor(QtCore.Qt.SplitHCursor)
        else:
            self.unsetCursor()
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton and self._resize_origin_x is not None:
            self._resize_origin_x = None
            self._resize_origin_width = None
            if event.pos().x() > self.RESIZE_EDGE_WIDTH:
                self.unsetCursor()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def leaveEvent(self, event):
        if self._resize_origin_x is None:
            self.unsetCursor()
        super().leaveEvent(event)

    def eventFilter(self, watched, event):
        if event.type() == QtCore.QEvent.MouseButtonPress and self.file_tree.isVisible():
            if watched is self.preview.viewport():
                self.tree_button.setChecked(False)
            elif watched is self.file_tree.viewport() and self.file_tree.itemAt(event.pos()) is None:
                self.tree_button.setChecked(False)
        return super().eventFilter(watched, event)

    def copy_path(self):
        if self.current_path is not None:
            QtWidgets.QApplication.clipboard().setText(str(self.current_path))

    def copy_contents(self):
        if self._readable:
            QtWidgets.QApplication.clipboard().setText(self.preview.toPlainText())

    def open_folder(self):
        if self.current_path is not None and not open_in_file_manager(self.current_path.parent):
            QtWidgets.QMessageBox.warning(self, "无法打开文件夹", str(self.current_path.parent))

    def open_in_editor(self):
        if self.current_path is None:
            return
        if not self.current_path.is_file():
            QtWidgets.QMessageBox.warning(self, "无法打开文件", "文件已不存在，请刷新文件列表。")
            return
        editor = self.editor_path_provider()
        configured_path = Path(editor).expanduser()
        executable = str(configured_path) if configured_path.is_file() else shutil.which(editor)
        if executable is None:
            QtWidgets.QMessageBox.warning(self, "无法打开编辑器", f"未找到 {editor}，请在设置中配置编辑器。")
            return
        try:
            subprocess.Popen([executable, str(self.current_path)])
        except OSError as error:
            QtWidgets.QMessageBox.warning(self, "无法打开编辑器", str(error))
