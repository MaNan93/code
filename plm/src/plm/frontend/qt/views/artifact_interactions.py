"""Artifact drawer behavior extracted from its widget construction."""

import shutil
import subprocess
from pathlib import Path
from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import open_in_file_manager


class ArtifactInteractions:
    """Focused artifact drawer behavior; widgets are owned by ArtifactsPanel."""

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
        self._sync_overflow_menu()

    def _sync_overflow_menu(self):
        has_overflow = False
        for action, button in self._overflow_actions:
            hidden = button.isHidden()
            action.setVisible(hidden)
            action.setEnabled(button.isEnabled())
            if action.isCheckable():
                action.setChecked(button.isChecked())
            has_overflow |= hidden
        self._overflow_separator.setVisible(has_overflow)

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
        path = self.current_path
        editor = self.editor_path_provider()

        def launch(_progress):
            if not path.is_file():
                raise OSError("文件已不存在，请刷新文件列表。")
            configured_path = Path(editor).expanduser()
            executable = str(configured_path) if configured_path.is_file() else shutil.which(editor)
            if executable is None:
                raise OSError(f"未找到 {editor}，请在设置中配置编辑器。")
            subprocess.Popen([executable, str(path)])

        self.tasks.submit(launch, lambda _result: None,
                          lambda error: QtWidgets.QMessageBox.warning(self, "无法打开编辑器", str(error)))
