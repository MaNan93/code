"""Artifact drawer behavior extracted from its widget construction."""

from pathlib import Path
from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.styles.tokens import PRIMARY, SUCCESS, TEXT_MUTED


_STATUS_COLORS = {
    "New": SUCCESS,
    "Modified": PRIMARY,
    "Unchanged": TEXT_MUTED,
}


class ArtifactFiles:
    """Focused artifact drawer behavior; widgets are owned by ArtifactsPanel."""

    def set_files(self, files, root=None, statuses=None):
        root = Path(root).resolve() if root is not None else None
        files = [Path(value).resolve() for value in files]
        if root != self.workspace_root or not files:
            self.path_button.setChecked(False)
        self.selection.set_files(files, keep_current=root == self.workspace_root)
        files = self.selection.files
        if root == self.workspace_root:
            self._previous_contents = dict(self._current_contents)
        else:
            self._previous_contents = {}
        self._current_contents = {}
        self._file_errors = {}
        self._files_revision += 1
        revision = self._files_revision
        self._loading_contents = bool(files)
        self._file_statuses = dict(statuses or {})
        self.workspace_root = root

        self._rebuild_tree(files, root)
        self._load_selected()
        if not files:
            return

        def finished(result):
            if revision != self._files_revision:
                return
            self._current_contents, self._file_errors = result
            self._loading_contents = False
            self._load_selected()

        def failed(error):
            if revision != self._files_revision:
                return
            self._loading_contents = False
            self._file_errors = {str(path): str(error) for path in files}
            self._load_selected()

        read_contents = self._read_contents
        self.tasks.submit(lambda _progress: read_contents(files), finished, failed)

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
        self.file_tree.updateGeometry()
        if selected_item is not None:
            self.file_tree.setCurrentItem(selected_item)

    def _tree_item_clicked(self, item, _column):
        value = item.data(0, QtCore.Qt.UserRole)
        if not value:
            item.setExpanded(not item.isExpanded())
            return
        if self.select_file(value):
            self.path_button.setChecked(False)

    def _select_tree_path(self):
        item = self._tree_items.get(self.current_path)
        if item is not None:
            self.file_tree.setCurrentItem(item)
