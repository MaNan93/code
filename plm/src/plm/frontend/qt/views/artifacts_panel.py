"""Generated-file drawer construction and public signals."""

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.models.artifacts import ArtifactSelection
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.widgets.code_preview import CodePreview
from plm.frontend.qt.widgets.common import (
    ICON_SIZE, StatusBadge, StyledMenu, apply_drop_shadow,
    load_lucide_icon, make_icon_button,
)
from plm.frontend.qt.styles.tokens import TEXT_MUTED, scale_content_size
from .artifact_preview import ArtifactPreview
from .artifact_files import ArtifactFiles
from .artifact_interactions import ArtifactInteractions


class ArtifactsPanel(
    ArtifactPreview, ArtifactFiles, ArtifactInteractions, QtWidgets.QFrame
):
    maximizeRequested = QtCore.pyqtSignal()
    refreshRequested = QtCore.pyqtSignal()
    widthRequested = QtCore.pyqtSignal(int)
    closeRequested = QtCore.pyqtSignal()
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
        self._file_errors = {}
        self._files_revision = 0
        self._preview_revision = 0
        self._loading_contents = False
        self.tasks = TaskRunner(self)
        self.is_maximized = False
        self._resize_origin_x = None
        self._resize_origin_width = None
        self.setObjectName("ArtifactsPanel")
        self.setMouseTracking(True)
        apply_drop_shadow(self, offset=(-4, 0), blur_radius=16, alpha=36)

        root = QtWidgets.QVBoxLayout(self)
        root.setSizeConstraint(QtWidgets.QLayout.SetNoConstraint)
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
        # The full-height drawer covers ConfigHeader's toggle button.
        self.close_button = make_icon_button(
            "x", "关闭产物面板", "ArtifactsToolButton", 28, ICON_SIZE,
        )
        self.close_button.clicked.connect(self.closeRequested.emit)
        toolbar_layout.addWidget(self.close_button)
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
        empty_size = scale_content_size(48)
        empty_icon.setPixmap(
            load_lucide_icon("file-x", TEXT_MUTED, empty_size).pixmap(empty_size, empty_size)
        )
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
        self.status = StatusBadge("尚无生成文件")
        self.status.setObjectName("ArtifactStatus")
        status_row = QtWidgets.QHBoxLayout()
        status_row.setContentsMargins(0, 0, 0, 0)
        status_row.addWidget(
            self.status, 0, QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
        )
        status_row.addStretch(1)
        root.addLayout(status_row)

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
        self._overflow_actions = []
        for label, button in (
            ("打开输出文件夹", self.toolbar_buttons[0]),
            ("刷新文件", self.toolbar_buttons[1]),
            ("在编辑器中打开", self.toolbar_buttons[2]),
            ("搜索当前文件", self.toolbar_buttons[4]),
            ("复制文件路径", self.toolbar_buttons[5]),
            ("显示/隐藏文件树", self.tree_button),
            ("切换 Verilog 高亮", self.highlight_button),
            ("显示/隐藏差异", self.diff_button),
        ):
            action = self.more_menu.addAction(label, button.click)
            action.setCheckable(button.isCheckable())
            self._overflow_actions.append((action, button))
        self._overflow_separator = self.more_menu.addSeparator()
        self.copy_content_action = self.more_menu.addAction("复制文件内容", self.copy_contents)
        self.more_menu.aboutToShow.connect(self._sync_overflow_menu)
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
