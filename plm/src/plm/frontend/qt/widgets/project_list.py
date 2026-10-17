"""Flat draggable project list used by the navigation panel."""

from pathlib import Path
from typing import Iterable

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.models import ProjectInfo
from plm.frontend.qt.widgets.project_item import ProjectItemWidget


class ProjectList(QtWidgets.QListWidget):
    """Draggable flat project list populated from static project information."""

    projectArchived = QtCore.pyqtSignal(str)
    projectDeleted = QtCore.pyqtSignal(str)
    projectRenamed = QtCore.pyqtSignal(str, str)
    projectPinned = QtCore.pyqtSignal(str)
    projectSelected = QtCore.pyqtSignal(str)
    projectReloadRequested = QtCore.pyqtSignal(str)

    def __init__(self, projects: Iterable[ProjectInfo], parent=None):
        super().__init__(parent)
        self.setObjectName("ProjectList")
        self.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        self.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        self.setDefaultDropAction(QtCore.Qt.MoveAction)
        self.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        self.setSpacing(0)
        self.project_widgets = []
        self.selected_project_name = None
        for project in projects:
            item = QtWidgets.QListWidgetItem()
            widget = ProjectItemWidget(
                project.name, project_path=project.config_dir.parent
            )
            widget.layout().setContentsMargins(0, 0, 0, 0)
            widget.pinRequested.connect(self.pin_project)
            widget.renameRequested.connect(self.rename_project)
            widget.renameCommitted.connect(self._commit_rename)
            widget.archiveRequested.connect(self.archive_project)
            widget.deleteRequested.connect(self.delete_project)
            widget.projectSelected.connect(self.select_project)
            widget.reloadRequested.connect(lambda row: self.projectReloadRequested.emit(row.project_name))
            self.addItem(item)
            self.setItemWidget(item, widget)
            self.project_widgets.append(widget)
            self._resize_item(item, widget)

    def select_project(self, project_name, emit_signal=True):
        selected_widget = next(
            (
                widget
                for widget in self.project_widgets
                if widget.project_name == project_name
            ),
            None,
        )
        if selected_widget is None and project_name and self.project_widgets:
            selected_widget = self.project_widgets[0]
        if selected_widget is None:
            self.selected_project_name = None
            self.clearSelection()
            self.setCurrentRow(-1)
            for widget in self.project_widgets:
                widget.set_selected(False)
            return None

        self.selected_project_name = selected_widget.project_name
        for widget in self.project_widgets:
            widget.set_selected(widget is selected_widget)
        _row, item = self._item_for_widget(selected_widget)
        if item is not None:
            self.setCurrentItem(item)
        if emit_signal:
            self.projectSelected.emit(self.selected_project_name)
        return self.selected_project_name

    def _item_for_widget(self, widget):
        for row in range(self.count()):
            item = self.item(row)
            if self.itemWidget(item) is widget:
                return row, item
        return -1, None

    def pin_project(self, widget):
        self.projectPinned.emit(widget.project_name)

    def apply_pin(self, name):
        widget = next((w for w in self.project_widgets if w.project_name == name), None)
        if widget is None:
            return
        row, item = self._item_for_widget(widget)
        if item is None or row == 0:
            return
        # Moving model rows preserves index widgets and their ownership.
        # removeItemWidget() schedules the old widget for deletion.
        if not self.model().moveRows(QtCore.QModelIndex(), row, 1, QtCore.QModelIndex(), 0):
            return
        self.project_widgets.remove(widget)
        self.project_widgets.insert(0, widget)
        self.select_project(self.selected_project_name, emit_signal=False)

    def rename_project(self, widget):
        widget.begin_rename()

    def _commit_rename(self, widget, new_name):
        if widget in self.project_widgets:
            self.projectRenamed.emit(widget.project_name, new_name)

    def apply_rename(self, old_name, new_name, config_dir):
        widget = next((w for w in self.project_widgets if w.project_name == old_name), None)
        if widget is None:
            return
        widget.rename(new_name)
        widget.project_path = Path(config_dir).resolve().parent
        if self.selected_project_name == old_name:
            self.selected_project_name = new_name
            self.projectSelected.emit(new_name)

    def archive_project(self, widget):
        message = (
            f"确定要归档项目「{widget.project_name}」吗？\n\n"
            "归档后，项目会从当前列表移除，但源文件不会删除。"
        )
        answer = QtWidgets.QMessageBox.question(
            self,
            "归档项目",
            message,
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No,
            QtWidgets.QMessageBox.No,
        )
        if answer != QtWidgets.QMessageBox.Yes:
            return
        self.projectArchived.emit(widget.project_name)

    def delete_project(self, widget):
        message = (
            f"确定要删除项目「{widget.project_name}」吗？\n\n"
            "此操作会同时删除源文件，且不可恢复。"
        )
        answer = QtWidgets.QMessageBox.question(
            self,
            "删除项目",
            message,
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No,
            QtWidgets.QMessageBox.No,
        )
        if answer != QtWidgets.QMessageBox.Yes:
            return
        self.projectDeleted.emit(widget.project_name)

    def apply_remove(self, name):
        widget = next((w for w in self.project_widgets if w.project_name == name), None)
        if widget is not None:
            self._remove_project(widget)

    def _remove_project(self, widget):
        row, item = self._item_for_widget(widget)
        if item is None:
            return
        was_selected = widget.project_name == self.selected_project_name
        self.removeItemWidget(item)
        removed_item = self.takeItem(row)
        del removed_item
        self.project_widgets.remove(widget)
        widget.deleteLater()
        if was_selected:
            self.selected_project_name = None
            if self.project_widgets:
                self.select_project(self.project_widgets[0].project_name)

    def _resize_item(self, item, widget):
        item.setSizeHint(widget.sizeHint())
