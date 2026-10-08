"""Single project-row widget used by the navigation project list."""

from pathlib import Path

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.styles.tokens import CONTROL_HEIGHT, DANGER, ICON_SIZE_SM, TEXT_SUB
from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    PROJECT_ROOT,
    StyledMenu,
    load_lucide_icon,
    make_icon_button,
    open_in_file_manager,
)


class ProjectContextMenu(StyledMenu):
    """Use the same rounded popup styling as every other PLM context menu."""

    def __init__(self, parent):
        super().__init__(parent)
        self.setObjectName("ProjectContextMenu")

class ProjectItemWidget(QtWidgets.QWidget):
    """Single-line selectable project row with semantic interaction signals."""

    pinRequested = QtCore.pyqtSignal(object)
    renameRequested = QtCore.pyqtSignal(object)
    renameCommitted = QtCore.pyqtSignal(object, str)
    archiveRequested = QtCore.pyqtSignal(object)
    deleteRequested = QtCore.pyqtSignal(object)
    reloadRequested = QtCore.pyqtSignal(object)
    projectSelected = QtCore.pyqtSignal(str)

    def __init__(self, project_name, project_path=None, parent=None):
        super().__init__(parent)
        self.setObjectName("ProjectItem")
        self.project_name = project_name
        self.project_path = Path(project_path or PROJECT_ROOT / project_name).resolve()
        self._renaming = False
        self._menu_open = False
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        self.header = QtWidgets.QPushButton()
        self.header.setObjectName("ProjectButton")
        self.header.setFocusPolicy(QtCore.Qt.StrongFocus)
        self.header.setCursor(QtCore.Qt.PointingHandCursor)
        self.header.clicked.connect(self._header_clicked)
        self.header.setMouseTracking(True)
        self.header.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.header.customContextMenuRequested.connect(self.show_context_menu)
        header_layout = QtWidgets.QHBoxLayout(self.header)
        header_layout.setContentsMargins(12, 0, 12, 0)
        header_layout.setSpacing(0)
        self.folder_icon = QtWidgets.QLabel()
        self.folder_icon.setObjectName("ProjectFolderIcon")
        self.folder_icon.setFixedSize(ICON_SIZE_SM, ICON_SIZE_SM)
        self.folder_icon.setAlignment(QtCore.Qt.AlignCenter)
        self.folder_icon.setPixmap(
            load_lucide_icon(
                "folder", TEXT_SUB, ICON_SIZE_SM, align_visible_left=True
            ).pixmap(ICON_SIZE_SM, ICON_SIZE_SM)
        )
        self.folder_icon.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        self.project_name_label = QtWidgets.QLabel(self.project_name)
        self.project_name_label.setObjectName("ProjectName")
        self.project_name_label.setSizePolicy(
            QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Preferred
        )
        self.project_name_label.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        self.project_name_edit = QtWidgets.QLineEdit()
        self.project_name_edit.setObjectName("ProjectNameEditor")
        self.project_name_edit.setFixedHeight(CONTROL_HEIGHT)
        self.project_name_edit.setSizePolicy(
            QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Fixed
        )
        self.project_name_edit.hide()
        self.project_name_edit.installEventFilter(self)
        self.project_name_edit.returnPressed.connect(self._finish_rename)
        header_layout.addWidget(self.folder_icon)
        header_layout.addSpacing(8)
        header_layout.addWidget(self.project_name_label, 1)
        header_layout.addWidget(self.project_name_edit, 1, QtCore.Qt.AlignVCenter)
        self.archive_btn = make_icon_button(
            "archive", "归档项目", "ProjectArchiveBtn", 24, ICON_SIZE_SM
        )
        self.open_folder_btn = make_icon_button(
            "folder-open", "打开项目文件夹", "ProjectOpenBtn", 24, ICON_SIZE_SM
        )
        self.open_folder_btn.clicked.connect(self.open_folder)
        self.more_btn = make_icon_button(
            "more-horizontal", "更多操作", "ProjectMoreBtn", 24, ICON_SIZE_SM
        )
        self.archive_btn.clicked.connect(
            lambda: self.archiveRequested.emit(self)
        )
        self.more_btn.clicked.connect(self.show_more_menu)
        self.archive_btn.hide()
        self.open_folder_btn.hide()
        self.more_btn.hide()
        header_layout.addWidget(self.archive_btn)
        header_layout.addSpacing(0)
        header_layout.addWidget(self.open_folder_btn)
        header_layout.addSpacing(0)
        header_layout.addWidget(self.more_btn)
        root.addWidget(self.header)
        self.header.installEventFilter(self)

    def _header_clicked(self, _checked=False):
        self.projectSelected.emit(self.project_name)

    def open_folder(self):
        open_in_file_manager(self.project_path)

    def set_selected(self, selected):
        self.header.setProperty("selected", selected)
        self.project_name_label.setProperty("selected", selected)
        for widget in (self.header, self.project_name_label):
            widget.style().unpolish(widget)
            widget.style().polish(widget)

    def eventFilter(self, watched, event):
        if watched is self.project_name_edit:
            if event.type() == QtCore.QEvent.KeyPress and event.key() == QtCore.Qt.Key_Escape:
                self._finish_rename(cancel=True)
                return True
            if event.type() == QtCore.QEvent.FocusOut and event.reason() != QtCore.Qt.PopupFocusReason:
                self._finish_rename()
        if watched is self.header:
            if event.type() == QtCore.QEvent.Enter:
                self.archive_btn.show()
                self.open_folder_btn.show()
                self.more_btn.show()
            elif event.type() == QtCore.QEvent.Leave:
                if not self._renaming and not self._menu_open:
                    self.archive_btn.hide()
                    self.open_folder_btn.hide()
                    self.more_btn.hide()
            elif (
                event.type() == QtCore.QEvent.MouseButtonDblClick
                and event.button() == QtCore.Qt.LeftButton
            ):
                self.renameRequested.emit(self)
                return True
        return super().eventFilter(watched, event)

    def begin_rename(self):
        self._renaming = True
        self.project_name_edit.setText(self.project_path.name)
        self.project_name_label.hide()
        self.archive_btn.show()
        self.open_folder_btn.show()
        self.more_btn.show()
        self.project_name_edit.show()
        self.project_name_edit.setFocus(QtCore.Qt.OtherFocusReason)
        self.project_name_edit.selectAll()

    def _finish_rename(self, cancel=False):
        if not self._renaming:
            return
        self._renaming = False
        new_name = self.project_name_edit.text().strip()
        self.project_name_edit.hide()
        self.project_name_label.show()
        self.archive_btn.setVisible(self.header.underMouse())
        self.open_folder_btn.setVisible(self.header.underMouse())
        self.more_btn.setVisible(self.header.underMouse())
        if not cancel and new_name and new_name != self.project_path.name:
            self.renameCommitted.emit(self, new_name)

    def show_context_menu(self, pos):
        menu = self.build_more_menu()
        menu.exec_(self.header.mapToGlobal(pos))

    def _set_menu_open(self, opened):
        self._menu_open = opened
        self.header.setProperty("menuOpen", opened)
        actions_visible = opened or self._renaming or self.header.underMouse()
        for widget in (self.header, self.archive_btn, self.open_folder_btn, self.more_btn):
            if widget is not self.header:
                widget.setVisible(actions_visible)
            widget.style().unpolish(widget)
            widget.style().polish(widget)
            widget.update()
        # Child buttons can leave stale pixels in their parent's backing store.
        self.update()
        if self.parentWidget() is not None:
            self.parentWidget().update()

    def show_more_menu(self):
        menu = self.build_more_menu()
        menu.exec_(
            self.more_btn.mapToGlobal(QtCore.QPoint(0, self.more_btn.height() + 4))
        )

    def build_more_menu(self):
        menu = ProjectContextMenu(self)
        menu.aboutToShow.connect(lambda: self._set_menu_open(True))
        menu.aboutToHide.connect(lambda: self._set_menu_open(False))
        pin_action = menu.addAction(
            load_lucide_icon("pin", TEXT_SUB, ICON_SIZE), "置顶"
        )
        rename_action = menu.addAction(
            load_lucide_icon("pencil", TEXT_SUB, ICON_SIZE), "重命名"
        )
        menu.addSeparator()
        open_action = menu.addAction(
            load_lucide_icon("folder-open", TEXT_SUB, ICON_SIZE),
            "在资源管理器中打开",
        )
        reload_action = menu.addAction(
            load_lucide_icon("refresh-cw", TEXT_SUB, ICON_SIZE), "Reload",
        )
        reload_action.setToolTip("重新加载配置文件，并将所有生成文件标记为过期")
        menu.addSeparator()
        archive_action = menu.addAction(
            load_lucide_icon("archive", TEXT_SUB, ICON_SIZE), "归档"
        )
        delete_action = menu.addAction(
            load_lucide_icon("trash-2", DANGER, ICON_SIZE), "删除"
        )

        pin_action.triggered.connect(lambda: self.pinRequested.emit(self))
        rename_action.triggered.connect(menu.close)
        rename_action.triggered.connect(lambda: self.renameRequested.emit(self))
        open_action.triggered.connect(self.open_folder)
        reload_action.triggered.connect(lambda: self.reloadRequested.emit(self))
        archive_action.triggered.connect(lambda: self.archiveRequested.emit(self))
        delete_action.triggered.connect(lambda: self.deleteRequested.emit(self))
        return menu

    def rename(self, new_name):
        self.project_name = new_name
        self.project_name_label.setText(new_name)
