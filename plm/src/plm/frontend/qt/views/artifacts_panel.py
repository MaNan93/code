"""Complete generated-file previews in the floating Artifacts panel."""

import shutil
import subprocess
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.widgets.code_preview import CodePreview
from plm.frontend.qt.widgets.common import (
    ICON_SIZE, apply_drop_shadow, make_icon_button, open_in_file_manager,
)


class ArtifactsPanel(QtWidgets.QFrame):
    maximizeRequested = QtCore.pyqtSignal()
    refreshRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.editor_path_provider = editor_path_provider or (lambda: DEFAULT_EDITOR)
        self.workspace_root = None
        self.current_path = None
        self._readable = False
        self._file_status = "尚无生成文件"
        self._file_error = ""
        self._output_text = ""
        self._output_detail = ""
        self.setObjectName("ArtifactsPanel")
        apply_drop_shadow(self, offset=(0, 2), blur_radius=12, alpha=30)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(12, 0, 12, 12)
        root.setSpacing(12)
        toolbar = QtWidgets.QWidget()
        toolbar.setObjectName("ArtifactsToolbar")
        toolbar.setFixedHeight(40)
        toolbar_layout = QtWidgets.QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(16, 0, 16, 0)
        toolbar_layout.setSpacing(8)
        self.toolbar_buttons = []
        for index, (icon, tooltip) in enumerate((
            ("folder", "打开输出文件夹"), ("refresh-cw", "刷新文件"),
            ("square-pen", "在编辑器中打开"), ("braces", "Verilog 语法高亮"),
            ("search", "搜索文件内容 (Ctrl+F)"), ("link", "复制文件路径"),
            ("file", "选择文件"), ("more-horizontal", "更多"), ("maximize", "展开"),
        )):
            button = make_icon_button(icon, tooltip, "ArtifactsToolButton", 24, ICON_SIZE)
            toolbar_layout.addWidget(button)
            self.toolbar_buttons.append(button)
            if index == 0:
                toolbar_layout.addStretch(1)
        root.addWidget(toolbar)
        self.file_selector = QtWidgets.QComboBox()
        self.file_selector.setObjectName("ArtifactFileSelector")
        self.file_selector.setSizeAdjustPolicy(QtWidgets.QComboBox.AdjustToMinimumContentsLengthWithIcon)
        self.file_selector.setMinimumContentsLength(10)
        self.file_selector.currentIndexChanged.connect(self._load_selected)
        root.addWidget(self.file_selector)

        self.search_bar = QtWidgets.QWidget()
        search_layout = QtWidgets.QHBoxLayout(self.search_bar)
        search_layout.setContentsMargins(0, 0, 0, 0)
        search_layout.setSpacing(4)
        self.search_input = QtWidgets.QLineEdit()
        self.search_input.setObjectName("ArtifactSearchInput")
        self.search_input.setPlaceholderText("搜索当前文件")
        self.search_status = QtWidgets.QLabel()
        search_layout.addWidget(self.search_input, 1)
        search_layout.addWidget(self.search_status)
        for label, tooltip, callback in (("↑", "上一个 (Shift+F3)", lambda: self.find_text(True)),
                                          ("↓", "下一个 (F3)", self.find_text),
                                          ("×", "关闭搜索", self.hide_search)):
            button = QtWidgets.QPushButton(label)
            button.setObjectName("ArtifactsToolButton")
            button.setFixedSize(24, 24)
            button.setToolTip(tooltip)
            button.clicked.connect(callback)
            search_layout.addWidget(button)
        root.addWidget(self.search_bar)
        self.search_bar.hide()
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
        for index, callback in ((0, self.open_folder), (1, self.refreshRequested.emit),
                                (2, self.open_in_editor), (4, self.show_search),
                                (5, self.copy_path), (6, self.file_selector.showPopup),
                                (8, self.maximizeRequested.emit)):
            self.toolbar_buttons[index].clicked.connect(callback)
        self.more_menu = QtWidgets.QMenu(self)
        self.copy_content_action = self.more_menu.addAction("复制文件内容", self.copy_contents)
        self.toolbar_buttons[7].setMenu(self.more_menu)
        for key, callback in (("Ctrl+F", self.show_search), ("F3", self.find_text),
                              ("Shift+F3", lambda: self.find_text(True)),
                              ("Shift+Return", lambda: self.find_text(True)),
                              ("Escape", self.hide_search)):
            shortcut = QtWidgets.QShortcut(QtGui.QKeySequence(key), self)
            shortcut.setContext(QtCore.Qt.WidgetWithChildrenShortcut)
            shortcut.activated.connect(callback)
        self.set_files([])

    def set_files(self, files, root=None):
        root = Path(root).resolve() if root is not None else None
        previous = self.current_path if root == self.workspace_root else None
        self.workspace_root = root
        self.file_selector.blockSignals(True)
        self.file_selector.clear()
        for value in files:
            path = Path(value).resolve()
            try:
                display = path.relative_to(root) if root else path.name
            except ValueError:
                display = path.name
            self.file_selector.addItem(str(display), str(path))
        index = self.file_selector.findData(str(previous)) if previous is not None else -1
        self.file_selector.setCurrentIndex(index if index >= 0 else (0 if files else -1))
        self.file_selector.blockSignals(False)
        self.file_selector.setEnabled(bool(files))
        self._load_selected()

    def _load_selected(self, *_):
        value = self.file_selector.currentData()
        self.current_path = Path(value) if value is not None else None
        self.preview.clear()
        self._readable = False
        self.search_status.clear()
        self.file_selector.setToolTip(str(self.current_path or ""))
        self._file_error = ""
        if self.current_path is None:
            self.preview.setPlaceholderText("尚无生成文件")
            self._file_status = "尚无生成文件"
        else:
            try:
                text = self.current_path.read_text(encoding="utf-8")
            except (OSError, UnicodeError) as error:
                self.preview.setPlaceholderText("无法预览该文件，请刷新或选择其他文件")
                self._file_status = "无法读取文件"
                self._file_error = str(error)
            else:
                self._readable = True
                self.preview.setPlaceholderText("文件为空")
                self.preview.setPlainText(text)
                self.preview.moveCursor(QtGui.QTextCursor.Start)
                self.preview.horizontalScrollBar().setValue(0)
                self._file_status = f"{self.file_selector.currentIndex() + 1}/{self.file_selector.count()} · {len(text.splitlines())} 行"
        self._update_status()
        self._update_highlighting()
        self.preview.line_numbers.setVisible(self._readable)
        for index in (0, 2, 5, 6):
            self.toolbar_buttons[index].setEnabled(self.current_path is not None)
        self.toolbar_buttons[4].setEnabled(self._readable)
        self.copy_content_action.setEnabled(self._readable)
        if self._readable and self.search_input.text():
            self._search_changed()

    def set_output_state(self, state, text, detail=""):
        self._output_text = text
        self._output_detail = detail
        self.status.setProperty("state", state)
        self.status.style().unpolish(self.status)
        self.status.style().polish(self.status)
        self._update_status()

    def _update_status(self):
        parts = [self._file_status] if self.current_path is not None or not self._output_text else []
        if self._output_text:
            parts.append(self._output_text)
        self.status.setText(" · ".join(parts))
        self.status.setToolTip("\n".join(part for part in (self._file_error, self._output_detail) if part))

    def _update_highlighting(self, *_):
        is_verilog = self.current_path is not None and self.current_path.suffix.lower() in (".v", ".sv", ".vh", ".svh")
        self.highlight_button.setEnabled(self._readable and is_verilog)
        self.preview.highlighter.set_enabled(self._readable and is_verilog and self.highlight_button.isChecked())

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
        flags = QtGui.QTextDocument.FindBackward if backwards else QtGui.QTextDocument.FindFlags()
        found = self.preview.find(query, flags)
        if not found:
            self.preview.moveCursor(QtGui.QTextCursor.End if backwards else QtGui.QTextCursor.Start)
            found = self.preview.find(query, flags)
        self.search_status.setText("" if found else "未找到")
        return found

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
