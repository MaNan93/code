"""Single project-row widget used by the navigation project list."""

from pathlib import Path

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    PROJECT_ROOT,
    StyledMenu,
    load_lucide_icon,
    make_icon_button,
    open_in_file_manager,
)


class ProjectItemWidget(QtWidgets.QWidget):
    """Single-line selectable project row with semantic interaction signals."""

    hoverEntered = QtCore.pyqtSignal(object)
    hoverLeft = QtCore.pyqtSignal(object)
    pinRequested = QtCore.pyqtSignal(object)
    renameRequested = QtCore.pyqtSignal(object)
    archiveRequested = QtCore.pyqtSignal(object)
    deleteRequested = QtCore.pyqtSignal(object)
    projectSelected = QtCore.pyqtSignal(str)

    def __init__(self, project_name, project_path=None, parent=None):
        super().__init__(parent)
        self.project_name = project_name
        self.project_path = Path(project_path or PROJECT_ROOT / project_name).resolve()
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(2)
        self.header = QtWidgets.QPushButton()
        self.header.setObjectName("ProjectButton")
        self.header.setCursor(QtCore.Qt.PointingHandCursor)
        self.header.clicked.connect(self._header_clicked)
        self.header.setMouseTracking(True)
        self.header.installEventFilter(self)
        header_layout = QtWidgets.QHBoxLayout(self.header)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(0)
        self.folder_icon = QtWidgets.QLabel()
        self.folder_icon.setObjectName("ProjectFolderIcon")
        self.folder_icon.setFixedSize(ICON_SIZE, ICON_SIZE)
        self.folder_icon.setAlignment(QtCore.Qt.AlignCenter)
        self.folder_icon.setPixmap(
            load_lucide_icon(
                "folder", "#666666", align_visible_left=True
            ).pixmap(ICON_SIZE, ICON_SIZE)
        )
        self.folder_icon.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        self.project_name_label = QtWidgets.QLabel(self.project_name)
        self.project_name_label.setObjectName("ProjectName")
        self.project_name_label.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        header_layout.addWidget(self.folder_icon)
        header_layout.addSpacing(8)
        header_layout.addWidget(self.project_name_label)
        header_layout.addStretch(1)
        self.archive_btn = make_icon_button(
            "archive", "归档项目", "ProjectArchiveBtn", 24, 16
        )
        self.more_btn = make_icon_button(
            "more-horizontal", "更多操作", "ProjectMoreBtn", 24, 16
        )
        self.archive_btn.clicked.connect(
            lambda: self.archiveRequested.emit(self)
        )
        self.more_btn.clicked.connect(self.show_more_menu)
        self.archive_btn.hide()
        self.more_btn.hide()
        header_layout.addWidget(self.archive_btn)
        header_layout.addSpacing(4)
        header_layout.addWidget(self.more_btn)
        root.addWidget(self.header)

    def _header_clicked(self, _checked=False):
        self.projectSelected.emit(self.project_name)

    def set_selected(self, selected):
        self.header.setProperty("selected", selected)
        self.project_name_label.setProperty("selected", selected)
        for widget in (self.header, self.project_name_label):
            widget.style().unpolish(widget)
            widget.style().polish(widget)

    def eventFilter(self, watched, event):
        if watched is self.header:
            if event.type() == QtCore.QEvent.Enter:
                self.archive_btn.show()
                self.more_btn.show()
                self.hoverEntered.emit(self)
            elif event.type() == QtCore.QEvent.Leave:
                self.archive_btn.hide()
                self.more_btn.hide()
                self.hoverLeft.emit(self)
        return super().eventFilter(watched, event)

    def show_more_menu(self):
        menu = self.build_more_menu()
        menu.exec_(
            self.more_btn.mapToGlobal(QtCore.QPoint(0, self.more_btn.height() + 4))
        )

    def build_more_menu(self):
        menu = StyledMenu(self)
        menu.setFixedWidth(180)
        pin_action = menu.addAction(
            load_lucide_icon("pin", "#666666", 16), "置顶"
        )
        rename_action = menu.addAction(
            load_lucide_icon("pencil", "#666666", 16), "重命名"
        )
        menu.addSeparator()
        open_action = menu.addAction(
            load_lucide_icon("folder-open", "#666666", 16),
            "在资源管理器中打开",
        )
        menu.addSeparator()
        archive_action = menu.addAction(
            load_lucide_icon("archive", "#666666", 16), "归档"
        )
        delete_action = QtWidgets.QWidgetAction(menu)
        delete_action.setText("删除")
        delete_button = QtWidgets.QPushButton("删除")
        delete_button.setObjectName("ProjectDeleteMenuButton")
        delete_button.setIcon(load_lucide_icon("x", "#CF222E", 16))
        delete_button.setIconSize(QtCore.QSize(16, 16))
        delete_button.setCursor(QtCore.Qt.PointingHandCursor)
        delete_action.setDefaultWidget(delete_button)
        menu.addAction(delete_action)

        pin_action.triggered.connect(lambda: self.pinRequested.emit(self))
        rename_action.triggered.connect(lambda: self.renameRequested.emit(self))
        open_action.triggered.connect(lambda: open_in_file_manager(self.project_path))
        archive_action.triggered.connect(lambda: self.archiveRequested.emit(self))

        def request_delete():
            menu.close()
            self.deleteRequested.emit(self)

        delete_button.clicked.connect(request_delete)
        return menu

    def rename(self, new_name):
        self.project_name = new_name
        self.project_name_label.setText(new_name)
