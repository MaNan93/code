"""Generated-file drawer construction and public signals."""

from collections import OrderedDict
from plm.frontend.qt.styles.tokens import get_theme_color
from plm.frontend.qt.styles.tokens import ARTIFACTS_TOOLBAR_HEIGHT
from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import set_label_icon
from plm.frontend.qt.models.artifacts import ArtifactSelection
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.widgets.code_preview import CodePreview
from plm.frontend.qt.widgets.common import (
    ICON_SIZE, StyledMenu,
    load_lucide_icon, make_icon_button,
)
from plm.frontend.qt.styles.tokens import (
    CONTROL_HEIGHT, ICON_BUTTON_SIZE,
)
from .artifact_chrome import ArtifactContent, ArtifactFilePopup, ArtifactPathButton
from .artifact_preview import ArtifactPreview
from .artifact_files import ArtifactFiles
from .artifact_interactions import ArtifactInteractions


class ArtifactFileDelegate(QtWidgets.QStyledItemDelegate):
    def sizeHint(self, option, index):
        size = super().sizeHint(option, index)
        size.setHeight(CONTROL_HEIGHT)
        return size

    def paint(self, painter, option, index):
        option = QtWidgets.QStyleOptionViewItem(option)
        option.state &= ~QtWidgets.QStyle.State_HasFocus
        super().paint(painter, option, index)


class ArtifactFileTree(QtWidgets.QTreeWidget):
    """Measure expanded rows for the screen-bounded file popup."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setItemDelegate(ArtifactFileDelegate(self))
        self.setSizePolicy(QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Preferred)
        self.itemExpanded.connect(self.updateGeometry)
        self.itemCollapsed.connect(self.updateGeometry)
        self.itemExpanded.connect(lambda item: self._update_folder_icon(item, True))
        self.itemCollapsed.connect(lambda item: self._update_folder_icon(item, False))

    def _update_folder_icon(self, item, expanded):
        if item.data(0, QtCore.Qt.UserRole) is None:
            name = "folder-open" if expanded else "folder"
            item.setIcon(0, load_lucide_icon(name, 'text_artifacts_muted'))

    def sizeHint(self):
        size = super().sizeHint()
        height = self.frameWidth() * 2
        stack = [self.topLevelItem(i) for i in range(self.topLevelItemCount())]
        while stack:
            item = stack.pop()
            if item.isHidden():
                continue
            height += self.sizeHintForIndex(self.indexFromItem(item)).height()
            if item.isExpanded():
                stack.extend(item.child(i) for i in range(item.childCount()))
        if not self.horizontalScrollBar().isHidden():
            height += self.horizontalScrollBar().sizeHint().height()
        size.setHeight(height)
        return size

    def minimumSizeHint(self):
        return QtCore.QSize(0, 0)

    def drawBranches(self, painter, rect, index):
        super().drawBranches(painter, rect, index)
        painter.save()
        painter.setPen(QtGui.QPen(QtGui.QColor(get_theme_color("border_artifacts")), 1))
        ancestor = index.parent()
        x = rect.right() - self.indentation() // 2 - self.indentation()
        while ancestor.isValid() and x >= rect.left():
            painter.drawLine(x, rect.top(), x, rect.bottom())
            x -= self.indentation()
            ancestor = ancestor.parent()
        painter.restore()


class ArtifactsPanel(
    ArtifactPreview, ArtifactFiles, ArtifactInteractions, QtWidgets.QFrame
):
    maximizeRequested = QtCore.pyqtSignal()
    closeRequested = QtCore.pyqtSignal()
    refreshRequested = QtCore.pyqtSignal()
    widthRequested = QtCore.pyqtSignal(int)
    RESIZE_EDGE_WIDTH = 6

    def refresh_theme(self):
        from .artifact_files import _STATUS_COLORS
        for path, item in self._tree_items.items():
            try:
                relative = path.relative_to(self.workspace_root).as_posix() if self.workspace_root else path.name
            except ValueError:
                relative = path.name
            role = _STATUS_COLORS.get(self._file_statuses.get(relative))
            if role:
                item.setForeground(0, QtGui.QBrush(QtGui.QColor(get_theme_color(role))))

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.editor_path_provider = editor_path_provider or (lambda: DEFAULT_EDITOR)
        self.workspace_root = None
        self.selection = ArtifactSelection()
        self._tree_items = {}
        self._readable = False
        self._file_status = "尚无生成文件"
        self.status_text = "尚无生成文件"
        self._file_error = ""
        self._output_text = ""
        self._output_detail = ""
        self._file_statuses = {}
        self._current_contents = {}
        self._previous_contents = {}
        self._content_lru = OrderedDict()
        self._content_cache_bytes = 0
        self._file_errors = {}
        self._files_revision = 0
        self._preview_revision = 0
        self._loading_contents = False
        self._loading_path = None
        self.tasks = TaskRunner(self)
        self.is_maximized = False
        self._resize_origin_x = None
        self._resize_origin_width = None
        self.setObjectName("ArtifactsPanel")
        self.setMouseTracking(True)

        outer = QtWidgets.QVBoxLayout(self)
        outer.setSizeConstraint(QtWidgets.QLayout.SetNoConstraint)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        content = ArtifactContent()
        root = QtWidgets.QVBoxLayout(content)
        self.content_layout = root
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(12)
        outer.addWidget(content, 1)
        toolbar = QtWidgets.QWidget()
        self.toolbar = toolbar
        toolbar.setObjectName("ArtifactsToolbar")
        toolbar.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        toolbar.setFixedHeight(ARTIFACTS_TOOLBAR_HEIGHT)
        toolbar_layout = QtWidgets.QHBoxLayout(toolbar)
        self.toolbar_layout = toolbar_layout
        toolbar_layout.setContentsMargins(16, 0, 16, 0)
        toolbar_layout.setSpacing(0)
        self.toolbar_buttons = []
        self.path_button = ArtifactPathButton()
        self.path_label = self.path_button.path_label
        self.toolbar_buttons.append(self.path_button)
        toolbar_layout.addWidget(self.path_button, 1)
        for name, icon, tooltip in (
            ("refresh_button", "refresh-cw", "刷新文件"),
            ("open_editor_button", "square-pen", "在编辑器中打开"),
            ("search_button", "search", "搜索文件内容 (Ctrl+F)"),
            ("copy_path_button", "link", "复制文件路径"),
            ("more_button", "more-horizontal", "更多"),
            ("maximize_button", "maximize", "展开"),
            ("close_button", "x", "关闭 Artifacts"),
        ):
            button = make_icon_button(icon, tooltip, "ArtifactsToolButton", ICON_BUTTON_SIZE, ICON_SIZE)
            button.setIcon(load_lucide_icon(icon, 'text_artifacts_muted'))
            setattr(self, name, button)
            self.toolbar_buttons.append(button)
        self.diff_button = make_icon_button(
            "git-compare", "显示与上一次预览的差异", "ArtifactsToolButton", ICON_BUTTON_SIZE, ICON_SIZE
        )
        self.diff_button.setIcon(load_lucide_icon("git-compare", 'text_artifacts_muted'))
        self.toolbar_buttons.append(self.diff_button)
        for button in (self.search_button, self.diff_button, self.copy_path_button,
                       self.open_editor_button, self.refresh_button, self.more_button,
                       self.maximize_button, self.close_button):
            toolbar_layout.addWidget(button)
        root.addWidget(toolbar)

        self.file_tree = ArtifactFileTree(self)
        self.file_tree.setObjectName("ArtifactFileTree")
        self.file_tree.setHeaderHidden(True)
        self.file_tree.setIndentation(ICON_SIZE)
        self.file_tree.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.file_tree.setRootIsDecorated(True)
        self.file_tree.itemClicked.connect(self._tree_item_clicked)
        self.file_tree.itemActivated.connect(self._tree_item_clicked)
        self.file_popup = ArtifactFilePopup(self.file_tree, self)
        self.file_popup.dismissed.connect(self._on_tree_popup_dismissed)
        self.file_popup.hide()

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
            button.setFixedWidth(ICON_BUTTON_SIZE)
            button.setToolTip(tooltip)
            button.clicked.connect(callback)
            search_layout.addWidget(button)
        root.addWidget(self.search_bar)
        self.search_bar.hide()

        self.empty_state = QtWidgets.QWidget()
        self.empty_state.setObjectName("ArtifactEmptyState")
        empty_layout = QtWidgets.QVBoxLayout(self.empty_state)
        empty_layout.setContentsMargins(0, 0, 0, 0)
        empty_layout.setSpacing(8)
        empty_layout.addSpacing(52)
        empty_icon = QtWidgets.QLabel()
        empty_icon.setAlignment(QtCore.Qt.AlignCenter)
        empty_size = ICON_SIZE
        empty_icon.setFixedSize(ICON_SIZE, ICON_SIZE)
        set_label_icon(empty_icon, "file-x", "text_artifacts_muted", empty_size)
        empty_layout.addWidget(empty_icon, 0, QtCore.Qt.AlignHCenter)
        self.empty_text = QtWidgets.QLabel("暂无生成文件")
        self.empty_text.setObjectName("ArtifactEmptyText")
        self.empty_text.setAlignment(QtCore.Qt.AlignCenter)
        empty_layout.addWidget(self.empty_text)
        empty_layout.addStretch(1)
        root.addWidget(self.empty_state, 1)

        self.preview = CodePreview()
        self.preview.setPlaceholderText("尚无生成文件")
        root.addWidget(self.preview, 1)
        self.search_input.textChanged.connect(self._search_changed)
        self.search_input.returnPressed.connect(self.find_text)
        self.path_button.toggled.connect(self._set_tree_visible)
        self.diff_button.setCheckable(True)
        self.diff_button.toggled.connect(self._load_selected)

        for button, callback in (
            (self.refresh_button, self.refreshRequested.emit),
            (self.open_editor_button, self.open_in_editor),
            (self.search_button, self.show_search),
            (self.copy_path_button, self.copy_path),
            (self.maximize_button, self.maximizeRequested.emit),
            (self.close_button, self.closeRequested.emit),
        ):
            button.clicked.connect(callback)

        self.more_menu = StyledMenu(self)
        self._overflow_actions = []
        for label, icon, button in (
            ("刷新文件", "refresh-cw", self.refresh_button),
            ("在编辑器中打开", "square-pen", self.open_editor_button),
            ("搜索当前文件", "search", self.search_button),
            ("复制文件路径", "link", self.copy_path_button),
            ("显示/隐藏差异", "git-compare", self.diff_button),
        ):
            action = self.more_menu.addAction(
                load_lucide_icon(icon, 'text_artifacts_muted'), label, button.click
            )
            action.setCheckable(button.isCheckable())
            self._overflow_actions.append((action, button))
        self.more_menu.aboutToShow.connect(self._sync_overflow_menu)
        self.more_button.setMenu(self.more_menu)
        for key, callback in (
            ("Ctrl+F", self.show_search),
            ("F3", self.find_text),
            ("Shift+F3", lambda: self.find_text(True)),
            ("Shift+Return", lambda: self.find_text(True)),
            ("Escape", self._handle_escape),
        ):
            shortcut = QtWidgets.QShortcut(QtGui.QKeySequence(key), self)
            shortcut.setContext(QtCore.Qt.WidgetWithChildrenShortcut)
            shortcut.activated.connect(callback)
        self.preview.viewport().installEventFilter(self)
        self.file_tree.viewport().installEventFilter(self)
        self.set_files([])
        self._apply_toolbar_density(self.width())
