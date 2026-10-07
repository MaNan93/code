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
        self.tasks.cancel_latest("artifact-read")
        self.tasks.cancel_latest("artifact-diff")
        if root == self.workspace_root:
            listed = {str(path) for path in files}
            # An unfinished refresh has no current content yet. Retain the
            # last successful preview until the replacement read completes.
            cached = {**self._previous_contents, **self._current_contents}
            previous = {}
            for _version, key in self._content_lru:
                if key in listed:
                    previous.pop(key, None)
                    previous[key] = cached[key]
            self._previous_contents = previous
        else:
            self._previous_contents = {}
        self._current_contents = {}
        self._content_lru.clear()
        self._content_cache_bytes = 0
        for key, text in self._previous_contents.items():
            size = len(text.encode("utf-8"))
            self._content_lru[("previous", key)] = size
            self._content_cache_bytes += size
        self._file_errors = {}
        self._files_revision += 1
        self._loading_contents = False
        self._loading_path = None
        self._file_statuses = dict(statuses or {})
        self.workspace_root = root

        self._rebuild_tree(files, root)
        self._load_selected()

    def _ensure_selected_contents(self):
        path = self.current_path
        key = str(path)
        if key in self._previous_contents:
            self._content_lru.move_to_end(("previous", key))
        if path is None or key in self._current_contents or key in self._file_errors:
            if self._loading_path is not None:
                self.tasks.cancel_latest("artifact-read")
            self._loading_path = None
            self._loading_contents = False
            if key in self._current_contents:
                self._content_lru.move_to_end(("current", key))
            return
        if self._loading_path == path:
            return
        revision = self._files_revision
        self._loading_path = path
        self._loading_contents = True

        def is_current():
            return revision == self._files_revision and path == self.current_path

        def finished(result):
            if not is_current():
                return
            contents, errors = result
            if key in contents:
                self._cache_content(key, contents[key])
            self._file_errors.update(errors)
            self._loading_path = None
            self._loading_contents = False
            self._load_selected()

        def failed(error):
            if not is_current():
                return
            self._loading_path = None
            self._loading_contents = False
            self._file_errors[key] = str(error)
            self._load_selected()

        read_contents = self._read_contents

        def read(progress):
            progress.check_cancelled()
            result = read_contents([path])
            progress.check_cancelled()
            return result

        self.tasks.submit_latest("artifact-read", read, finished, failed)

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
