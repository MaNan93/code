"""Flat draggable project list used by the navigation panel."""

from typing import Iterable

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.models import ProjectInfo
from plm.frontend.qt.widgets.hover_card import HoverCard
from plm.frontend.qt.widgets.project_item import ProjectItemWidget


class ProjectList(QtWidgets.QListWidget):
    """Draggable flat project list populated from static project information."""

    projectArchived = QtCore.pyqtSignal(str)
    projectDeleted = QtCore.pyqtSignal(str)
    projectRenamed = QtCore.pyqtSignal(str, str)
    projectPinned = QtCore.pyqtSignal(str)
    projectSelected = QtCore.pyqtSignal(str)

    def __init__(self, projects: Iterable[ProjectInfo], parent=None):
        super().__init__(parent)
        self.setObjectName("ProjectList")
        self.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        self.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        self.setDefaultDropAction(QtCore.Qt.MoveAction)
        self.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        self.hover_card = HoverCard(self)
        self.hover_card.hide()
        self._pending_hover_widget = None
        self._hover_timer = QtCore.QTimer(self)
        self._hover_timer.setSingleShot(True)
        self._hover_timer.setInterval(400)
        self._hover_timer.timeout.connect(self._show_hover_card)
        self._hide_timer = QtCore.QTimer(self)
        self._hide_timer.setSingleShot(True)
        self._hide_timer.setInterval(150)
        self._hide_timer.timeout.connect(self.hover_card.hide)
        self.hover_card.pointerEntered.connect(self._hide_timer.stop)
        self.hover_card.pointerLeft.connect(self._schedule_hover_card_hide)
        self.project_widgets = []
        self.selected_project_name = None
        for project in projects:
            item = QtWidgets.QListWidgetItem()
            widget = ProjectItemWidget(
                project.name, project_path=project.config_dir
            )
            widget.hoverEntered.connect(self._schedule_hover_card)
            widget.hoverLeft.connect(self._project_hover_left)
            widget.pinRequested.connect(self.pin_project)
            widget.renameRequested.connect(self.rename_project)
            widget.archiveRequested.connect(self.archive_project)
            widget.deleteRequested.connect(self.delete_project)
            widget.projectSelected.connect(self.select_project)
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
        if selected_widget is None and self.project_widgets:
            selected_widget = self.project_widgets[0]
        if selected_widget is None:
            self.selected_project_name = None
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
        self.removeItemWidget(item)
        self.takeItem(row)
        self.insertItem(0, item)
        self.setItemWidget(item, widget)
        self.project_widgets.remove(widget)
        self.project_widgets.insert(0, widget)
        self.select_project(self.selected_project_name, emit_signal=False)

    def rename_project(self, widget):
        old_name = widget.project_name
        new_name, accepted = QtWidgets.QInputDialog.getText(
            self,
            "重命名项目",
            "请输入新的项目名称：",
            text=old_name,
        )
        new_name = new_name.strip()
        if not accepted or not new_name or new_name == old_name:
            return
        self.projectRenamed.emit(old_name, new_name)

    def apply_rename(self, old_name, new_name, config_dir):
        widget = next((w for w in self.project_widgets if w.project_name == old_name), None)
        if widget is None:
            return
        widget.rename(new_name)
        widget.project_path = config_dir
        if self.selected_project_name == old_name:
            self.selected_project_name = new_name
            self.projectSelected.emit(new_name)
        if self.hover_card.isVisible():
            self.hover_card.set_project(new_name, config_dir)

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
        project_name = widget.project_name
        self.projectArchived.emit(project_name)

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
        project_name = widget.project_name
        self.projectDeleted.emit(project_name)

    def apply_remove(self, name):
        widget = next((w for w in self.project_widgets if w.project_name == name), None)
        if widget is not None:
            self._remove_project(widget)

    def _remove_project(self, widget):
        row, item = self._item_for_widget(widget)
        if item is None:
            return
        self._hover_timer.stop()
        self._hide_timer.stop()
        self.hover_card.hide()
        self._pending_hover_widget = None
        was_selected = widget.project_name == self.selected_project_name
        self.removeItemWidget(item)
        self.takeItem(row)
        self.project_widgets.remove(widget)
        widget.deleteLater()
        if was_selected:
            self.selected_project_name = None
            if self.project_widgets:
                self.select_project(self.project_widgets[0].project_name)

    def _schedule_hover_card(self, widget):
        self._hide_timer.stop()
        self.hover_card.hide()
        self._pending_hover_widget = widget
        self._hover_timer.start()

    def _project_hover_left(self, widget):
        if self._pending_hover_widget is widget:
            self._hover_timer.stop()
            self._pending_hover_widget = None
        self._schedule_hover_card_hide()

    def _schedule_hover_card_hide(self):
        self._hide_timer.start()

    def _show_hover_card(self):
        widget = self._pending_hover_widget
        if widget is None or not widget.header.underMouse():
            return
        self.hover_card.set_project(widget.project_name, widget.project_path)
        self.hover_card.adjustSize()
        position = widget.header.mapToGlobal(
            QtCore.QPoint(widget.header.width() + 8, 0)
        )
        screen = QtWidgets.QApplication.screenAt(position)
        if screen is not None:
            available = screen.availableGeometry()
            position.setX(min(position.x(), available.right() - self.hover_card.width()))
            position.setY(min(position.y(), available.bottom() - self.hover_card.height()))
        self.hover_card.move(position)
        self.hover_card.show()
        self.hover_card.raise_()

    def _resize_item(self, item, widget):
        item.setSizeHint(widget.sizeHint())
