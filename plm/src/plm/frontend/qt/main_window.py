"""PyQt5 interface shell for plmConsultant.

The module implements layout and UI interactions only. PLM workspace actions
and RTL generation are intentionally left disconnected for this phase.
"""

import sys
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets


APP_ICON_PATH = Path(__file__).resolve().parent / "assets" / "app_icon.svg"
LUCIDE_ICON_DIR = Path(__file__).resolve().parent / "assets" / "icons"
ICON_SIZE = 20


def make_label(text, object_name="", *, word_wrap=True):
    label = QtWidgets.QLabel(text)
    if object_name:
        label.setObjectName(object_name)
    label.setWordWrap(word_wrap)
    return label


def load_lucide_icon(name, color="#666666", size=ICON_SIZE):
    """Render a Lucide SVG to a monochrome QIcon at a consistent size."""
    path = LUCIDE_ICON_DIR / f"{name}.svg"
    pixmap = QtGui.QPixmap(size, size)
    pixmap.fill(QtCore.Qt.transparent)
    renderer = QtSvg.QSvgRenderer(str(path))
    if not renderer.isValid():
        return QtGui.QIcon(pixmap)
    painter = QtGui.QPainter(pixmap)
    renderer.render(painter)
    painter.end()

    colored = QtGui.QPixmap(size, size)
    colored.fill(QtCore.Qt.transparent)
    painter = QtGui.QPainter(colored)
    painter.drawPixmap(0, 0, pixmap)
    painter.setCompositionMode(QtGui.QPainter.CompositionMode_SourceIn)
    painter.fillRect(colored.rect(), QtGui.QColor(color))
    painter.end()
    return QtGui.QIcon(colored)


class SessionIconButton(QtWidgets.QPushButton):
    def __init__(self, icon_name, object_name, tooltip, parent=None):
        super().__init__(parent)
        self.icon_name = icon_name
        self.setObjectName(object_name)
        self.setIcon(load_lucide_icon(icon_name, "#8C92A4", 16))
        self.setIconSize(QtCore.QSize(16, 16))
        self.setFixedSize(24, 24)
        self.setCursor(QtCore.Qt.PointingHandCursor)
        self.setToolTip(tooltip)

    def enterEvent(self, event):
        self.setIcon(load_lucide_icon(self.icon_name, "#1677FF", 16))
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.setIcon(load_lucide_icon(self.icon_name, "#8C92A4", 16))
        super().leaveEvent(event)


class SessionNameLabel(QtWidgets.QLabel):
    clicked = QtCore.pyqtSignal()

    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setObjectName("SessionNameLabel")
        self.setCursor(QtCore.Qt.PointingHandCursor)

    def mouseReleaseEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.clicked.emit()
        super().mouseReleaseEvent(event)

    def click(self):
        """Keep compatibility with the previous QPushButton session entry."""
        self.clicked.emit()


class SessionNameEdit(QtWidgets.QLineEdit):
    cancel_requested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("SessionName")

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.cancel_requested.emit()
            event.accept()
            return
        super().keyPressEvent(event)


class SessionEntry(QtWidgets.QWidget):
    more_requested = QtCore.pyqtSignal(object)
    name_changed = QtCore.pyqtSignal(object)

    def __init__(self, text, on_activate, source_path=None, parent=None):
        super().__init__(parent)
        self.setObjectName("SessionEntry")
        self.source_path = Path(source_path).resolve() if source_path else None
        self.original_name = text
        self.is_editing = False
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        self.session_label = SessionNameLabel(text)
        self.session_label.clicked.connect(on_activate)
        layout.addWidget(self.session_label, 1)

        self.session_editor = SessionNameEdit()
        self.session_editor.returnPressed.connect(self.exit_edit_mode)
        self.session_editor.editingFinished.connect(self.exit_edit_mode)
        self.session_editor.cancel_requested.connect(self.cancel_edit_mode)
        self.session_editor.hide()
        layout.addWidget(self.session_editor, 1)

        # Compatibility alias for code that used the earlier session button.
        self.session_button = self.session_label

        self.more_button = SessionIconButton(
            "more-horizontal", "SessionMoreBtn", "更多操作"
        )
        self.more_button.clicked.connect(lambda: self.more_requested.emit(self))
        self.more_button.setVisible(False)
        layout.addWidget(self.more_button)

    def enterEvent(self, event):
        self.more_button.setVisible(True)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self.more_button.setVisible(False)
        super().leaveEvent(event)

    def enter_edit_mode(self):
        if self.is_editing:
            return
        self.is_editing = True
        self.original_name = self.session_label.text()
        self.setProperty("editing", "true")
        self.session_label.hide()
        self.session_editor.setText(self.original_name)
        self.session_editor.show()
        self.session_editor.selectAll()
        self.session_editor.setFocus(QtCore.Qt.OtherFocusReason)

    def exit_edit_mode(self):
        if not self.is_editing:
            return
        self.is_editing = False
        self.session_label.setText(self.session_editor.text())
        self.setProperty("editing", "false")
        self.session_editor.hide()
        self.session_label.show()
        self.name_changed.emit(self)

    def cancel_edit_mode(self):
        if not self.is_editing:
            return
        self.session_editor.setText(self.original_name)
        self.is_editing = False
        self.setProperty("editing", "false")
        self.session_editor.hide()
        self.session_label.setText(self.original_name)
        self.session_label.show()


class SessionActionsMenu(QtWidgets.QMenu):
    """QMenu that renders destructive actions with red text."""

    def initStyleOption(self, option, action):
        super().initStyleOption(option, action)
        if action.property("destructive"):
            destructive = QtGui.QColor("#CF222E")
            option.palette.setColor(QtGui.QPalette.Text, destructive)
            option.palette.setColor(QtGui.QPalette.ButtonText, destructive)
            option.palette.setColor(QtGui.QPalette.WindowText, destructive)


class SessionListItem(QtWidgets.QListWidgetItem):
    def __init__(self):
        super().__init__()
        self.setSizeHint(QtCore.QSize(0, 40))
        self.setFlags(
            self.flags()
            | QtCore.Qt.ItemIsDragEnabled
            | QtCore.Qt.ItemIsDropEnabled
            | QtCore.Qt.ItemIsSelectable
            | QtCore.Qt.ItemIsEnabled
        )


class DragButton(QtWidgets.QWidget):
    """A 14x36 capsule button used to resize a floating panel."""

    def __init__(self, on_drag=None, on_release=None, parent=None):
        super().__init__(parent)
        self.on_drag = on_drag
        self.on_release = on_release
        self.drag_start_x = None
        self.setCursor(QtCore.Qt.SplitHCursor)
        self.setFixedSize(14, 36)
        self.setMouseTracking(True)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        pill = QtCore.QRectF(0.5, 0.5, 13, 35)

        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(QtGui.QColor(0, 0, 0, 15))
        painter.drawRoundedRect(pill.translated(1, 1), 7, 7)

        painter.setPen(QtGui.QPen(QtGui.QColor("#C0C4CC"), 1))
        painter.setBrush(QtGui.QColor("#FFFFFF"))
        painter.drawRoundedRect(pill, 7, 7)

        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(QtGui.QColor("#A0A5B0"))
        painter.drawRect(QtCore.QRectF(4, 14, 1.5, 8))
        painter.drawRect(QtCore.QRectF(8.5, 14, 1.5, 8))

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.drag_start_x = event.globalPos().x()
            if self.on_drag:
                self.on_drag("start", self.drag_start_x)
            event.accept()

    def mouseMoveEvent(self, event):
        if self.drag_start_x is not None and self.on_drag:
            self.on_drag("move", event.globalPos().x())
            event.accept()

    def mouseReleaseEvent(self, event):
        if self.drag_start_x is not None:
            self.drag_start_x = None
            if self.on_release:
                self.on_release()
            event.accept()


class NavPanel(QtWidgets.QFrame):
    navChanged = QtCore.pyqtSignal(str)
    session_deleted = QtCore.pyqtSignal(str)
    session_archived = QtCore.pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("NavPanel")
        self.setMinimumWidth(200)
        self.setMaximumWidth(400)
        self.is_collapsed = False
        self.expanded_width = 260
        self.session_order = []
        self._session_records = {}
        self.archived_list = None
        self.archived_label = None

        self.root_layout = QtWidgets.QVBoxLayout(self)
        self.root_layout.setContentsMargins(15, 20, 15, 20)
        self.root_layout.setSpacing(10)

        brand = QtWidgets.QHBoxLayout()
        self.logo_icon = QtWidgets.QLabel()
        self.logo_icon.setObjectName("LogoIcon")
        if APP_ICON_PATH.is_file():
            self.logo_icon.setPixmap(QtGui.QIcon(str(APP_ICON_PATH)).pixmap(26, 26))
        self.logo_icon.setFixedSize(26, 26)
        brand.addWidget(self.logo_icon)
        self.logo_text = QtWidgets.QLabel("plmConsultant")
        self.logo_text.setObjectName("Logo")
        brand.addWidget(self.logo_text)
        brand.addStretch(1)
        self.collapse_btn = QtWidgets.QPushButton("«")
        self.collapse_btn.setObjectName("CollapseBtn")
        self.collapse_btn.setFixedSize(30, 30)
        self.collapse_btn.setCursor(QtCore.Qt.PointingHandCursor)
        self.collapse_btn.setToolTip("收起侧边栏")
        self.collapse_btn.clicked.connect(self.toggle_collapse)
        brand.addWidget(self.collapse_btn)
        self.root_layout.addLayout(brand)

        self.logo_divider = QtWidgets.QFrame()
        self.logo_divider.setObjectName("NavDivider")
        self.logo_divider.setFixedHeight(1)
        self.root_layout.addWidget(self.logo_divider)

        self.action_buttons_widget = QtWidgets.QWidget()
        action_buttons_layout = QtWidgets.QVBoxLayout(self.action_buttons_widget)
        action_buttons_layout.setContentsMargins(0, 0, 0, 0)
        action_buttons_layout.setSpacing(8)

        self.new_chat_btn = QtWidgets.QPushButton("新对话")
        self.new_chat_btn.setObjectName("NewChatBtn")
        self.new_chat_btn.setIcon(load_lucide_icon("square-pen", "#333333"))
        self.new_chat_btn.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.new_chat_btn.setCursor(QtCore.Qt.PointingHandCursor)
        self.new_chat_btn.clicked.connect(lambda: self.navChanged.emit("new_chat"))
        action_buttons_layout.addWidget(self.new_chat_btn)

        self.save_btn = QtWidgets.QPushButton("保存")
        self.save_btn.setObjectName("SaveBtn")
        self.save_btn.setIcon(load_lucide_icon("save", "#333333"))
        self.save_btn.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.save_btn.setCursor(QtCore.Qt.PointingHandCursor)
        self.save_btn.clicked.connect(lambda: self.navChanged.emit("save"))
        action_buttons_layout.addWidget(self.save_btn)
        self.root_layout.addWidget(self.action_buttons_widget)

        self.actions_divider = QtWidgets.QFrame()
        self.actions_divider.setObjectName("NavDivider")
        self.actions_divider.setFixedHeight(1)
        self.root_layout.addWidget(self.actions_divider)

        self.sessions_widget = QtWidgets.QWidget()
        self.sessions_layout = QtWidgets.QVBoxLayout(self.sessions_widget)
        self.sessions_layout.setContentsMargins(0, 0, 0, 0)
        self.sessions_layout.setSpacing(4)

        self.section_label = QtWidgets.QLabel("Recent sessions")
        self.section_label.setObjectName("SidebarSection")
        self.sessions_layout.addWidget(self.section_label)

        self.recent_list = self._create_session_list("RecentSessionList")
        self.recent_list.model().rowsMoved.connect(self._save_session_order)
        self.sessions_layout.addWidget(self.recent_list)

        self.session_item = self.add_session(
            "PIPE Lane Mapper 配置会话",
        )
        self.session_btn = self.session_item.session_button
        self.session_name_edit = self.session_item.session_editor
        self.session_more_btn = self.session_item.more_button
        self.root_layout.addWidget(self.sessions_widget)

        self.sessions_divider = QtWidgets.QFrame()
        self.sessions_divider.setObjectName("NavDivider")
        self.sessions_divider.setFixedHeight(1)
        self.root_layout.addWidget(self.sessions_divider)
        self.root_layout.addStretch(1)

        self.bottom_widget = QtWidgets.QWidget()
        bottom = QtWidgets.QHBoxLayout(self.bottom_widget)
        bottom.setContentsMargins(0, 0, 0, 0)
        bottom.setSpacing(8)
        self.docs_btn = QtWidgets.QPushButton("Docs")
        self.docs_btn.setObjectName("BottomBtn")
        self.docs_btn.setIcon(load_lucide_icon("file-text", "#555555"))
        self.docs_btn.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.settings_btn = QtWidgets.QPushButton("Settings")
        self.settings_btn.setObjectName("BottomBtn")
        self.settings_btn.setIcon(load_lucide_icon("settings", "#555555"))
        self.settings_btn.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        for button in (self.docs_btn, self.settings_btn):
            button.setCursor(QtCore.Qt.PointingHandCursor)
            bottom.addWidget(button)
        self.docs_btn.clicked.connect(lambda: self.navChanged.emit("docs"))
        self.settings_btn.clicked.connect(lambda: self.navChanged.emit("settings"))
        self.root_layout.addWidget(self.bottom_widget)

        self.collapsible_widgets = [
            self.logo_icon,
            self.logo_text,
            self.logo_divider,
            self.action_buttons_widget,
            self.actions_divider,
            self.sessions_widget,
            self.sessions_divider,
            self.bottom_widget,
        ]

    def _create_session_list(self, object_name):
        session_list = QtWidgets.QListWidget()
        session_list.setObjectName(object_name)
        session_list.setDragDropMode(QtWidgets.QAbstractItemView.InternalMove)
        session_list.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        session_list.setDefaultDropAction(QtCore.Qt.MoveAction)
        session_list.setDragEnabled(True)
        session_list.setAcceptDrops(True)
        session_list.setDropIndicatorShown(True)
        session_list.setVerticalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        session_list.itemSelectionChanged.connect(
            lambda current_list=session_list: self._update_session_selection(
                current_list
            )
        )
        return session_list

    def add_session(self, name, source_path=None, session_list=None):
        target_list = session_list or self.recent_list
        entry = SessionEntry(
            name,
            lambda: self.navChanged.emit("config"),
            source_path=source_path,
        )
        entry.more_requested.connect(self.show_session_menu)
        entry.name_changed.connect(lambda _: self._sync_session_order())

        item = SessionListItem()
        target_list.addItem(item)
        target_list.setItemWidget(item, entry)
        self._session_records[entry] = (target_list, item)
        self._resize_session_list(target_list)
        self._sync_session_order()
        return entry

    def show_session_menu(self, entry):
        menu = SessionActionsMenu(self)
        edit_action = menu.addAction(
            load_lucide_icon("square-pen", "#666666", 16), "编辑"
        )
        archive_action = menu.addAction(
            load_lucide_icon("archive", "#666666", 16), "归档"
        )
        delete_action = menu.addAction(
            load_lucide_icon("trash-2", "#CF222E", 16), "删除"
        )
        delete_action.setProperty("destructive", True)
        edit_action.triggered.connect(entry.enter_edit_mode)
        archive_action.triggered.connect(lambda: self.archive_session(entry))
        delete_action.triggered.connect(lambda: self.delete_session(entry))

        current_list, _ = self._session_records[entry]
        archive_action.setEnabled(current_list is self.recent_list)
        entry.actions_menu = menu
        menu.popup(
            entry.more_button.mapToGlobal(
                QtCore.QPoint(0, entry.more_button.height())
            )
        )

    def delete_session(self, entry):
        answer = QtWidgets.QMessageBox.question(
            self,
            "删除会话",
            "确定要删除该会话吗？此操作会删除源文件，不可恢复。",
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No,
            QtWidgets.QMessageBox.No,
        )
        if answer != QtWidgets.QMessageBox.Yes:
            return

        if entry.source_path is not None:
            try:
                if entry.source_path.is_file():
                    entry.source_path.unlink()
                elif entry.source_path.exists():
                    raise OSError("源路径不是普通文件")
            except OSError as error:
                QtWidgets.QMessageBox.warning(
                    self, "删除失败", f"无法删除源文件：{error}"
                )
                return

        session_name = entry.session_label.text()
        self._remove_session_entry(entry)
        self.session_deleted.emit(session_name)

    def archive_session(self, entry):
        source_list, item = self._session_records[entry]
        if source_list is not self.recent_list:
            return
        archived_list = self._ensure_archived_list()
        source_list.removeItemWidget(item)
        source_list.takeItem(source_list.row(item))
        archived_list.addItem(item)
        archived_list.setItemWidget(item, entry)
        self._session_records[entry] = (archived_list, item)
        self._resize_session_list(source_list)
        self._resize_session_list(archived_list)
        self._sync_session_order()
        self.session_archived.emit(entry.session_label.text())

    def _ensure_archived_list(self):
        if self.archived_list is None:
            self.archived_label = QtWidgets.QLabel("Archived sessions")
            self.archived_label.setObjectName("SidebarSection")
            self.sessions_layout.addWidget(self.archived_label)
            self.archived_list = self._create_session_list("ArchivedSessionList")
            self.sessions_layout.addWidget(self.archived_list)
        return self.archived_list

    def _remove_session_entry(self, entry):
        session_list, item = self._session_records.pop(entry)
        session_list.removeItemWidget(item)
        session_list.takeItem(session_list.row(item))
        entry.deleteLater()
        self._resize_session_list(session_list)
        self._sync_session_order()

    def _resize_session_list(self, session_list):
        visible_rows = max(1, min(session_list.count(), 5))
        session_list.setFixedHeight(visible_rows * 40 + 2)

    def _save_session_order(self, *args):
        QtCore.QTimer.singleShot(0, self._sync_session_order)

    def _update_session_selection(self, session_list):
        selected_items = set(session_list.selectedItems())
        for row in range(session_list.count()):
            item = session_list.item(row)
            entry = session_list.itemWidget(item)
            if entry is None:
                continue
            name_label = entry.session_label
            name_label.setProperty("selected", item in selected_items)
            name_label.style().unpolish(name_label)
            name_label.style().polish(name_label)

    def _sync_session_order(self):
        self.session_order = []
        for row in range(self.recent_list.count()):
            item = self.recent_list.item(row)
            entry = self.recent_list.itemWidget(item)
            if entry is not None:
                self.session_order.append(entry.session_label.text())

    def set_active(self, name):
        self.docs_btn.setProperty("selected", "true" if name == "docs" else "false")
        self.settings_btn.setProperty(
            "selected", "true" if name == "settings" else "false"
        )
        if name == "docs":
            self.docs_btn.setIcon(load_lucide_icon("file-text", "#1677FF"))
            self.settings_btn.setIcon(load_lucide_icon("settings", "#555555"))
        elif name == "settings":
            self.docs_btn.setIcon(load_lucide_icon("file-text", "#555555"))
            self.settings_btn.setIcon(load_lucide_icon("settings", "#1677FF"))
        else:
            self.docs_btn.setIcon(load_lucide_icon("file-text", "#555555"))
            self.settings_btn.setIcon(load_lucide_icon("settings", "#555555"))
        for button in (self.docs_btn, self.settings_btn):
            button.style().unpolish(button)
            button.style().polish(button)

    def toggle_collapse(self):
        self.is_collapsed = not self.is_collapsed
        for widget in self.collapsible_widgets:
            widget.setVisible(not self.is_collapsed)
        if self.is_collapsed:
            self.expanded_width = max(200, min(self.width(), 400))
            self.root_layout.setContentsMargins(5, 20, 5, 20)
            self.setMinimumWidth(40)
            self.setMaximumWidth(40)
            self.collapse_btn.setFixedSize(30, 30)
            self.collapse_btn.setText("»")
            self.collapse_btn.setToolTip("展开侧边栏")
        else:
            self.root_layout.setContentsMargins(15, 20, 15, 20)
            self.setMinimumWidth(200)
            self.setMaximumWidth(400)
            self.collapse_btn.setText("«")
            self.collapse_btn.setToolTip("收起侧边栏")
        splitter = self.parentWidget()
        if isinstance(splitter, QtWidgets.QSplitter):
            widths = splitter.sizes()
            total_width = sum(widths)
            nav_width = 40 if self.is_collapsed else self.expanded_width
            splitter.setSizes([nav_width, max(1, total_width - nav_width)])


class DiffLine(QtWidgets.QWidget):
    def __init__(self, old_number, new_number, text, mode="ctx", parent=None):
        super().__init__(parent)
        self.setObjectName("DiffLine")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setProperty("mode", mode)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        old_label = QtWidgets.QLabel("" if old_number is None else str(old_number))
        new_label = QtWidgets.QLabel("" if new_number is None else str(new_number))
        for number_label in (old_label, new_label):
            number_label.setObjectName("DiffLineNumber")
            number_label.setFixedWidth(34)
            number_label.setAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
            layout.addWidget(number_label)

        prefix = "+" if mode == "add" else "-" if mode == "del" else " "
        code = QtWidgets.QLabel(f"{prefix} {text}")
        code.setObjectName("DiffCode")
        code.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        layout.addWidget(code, 1)


def make_diff_line(old_number, new_number, code_text, mode="ctx"):
    """Create one dual-line-number diff row with high-contrast colouring."""
    mode = {"context": "ctx", "delete": "del"}.get(mode, mode)
    styles = {
        "add": ("#D8F5DC", "#1A7F37"),
        "del": ("#FFE0DC", "#CF222E"),
        "ctx": ("#F6F8FA", "#333333"),
    }
    normalized_mode = mode if mode in styles else "ctx"
    background, foreground = styles[normalized_mode]
    line = DiffLine(old_number, new_number, code_text, normalized_mode)
    line.setStyleSheet(
        f"""
        QWidget#DiffLine {{ background-color: {background}; min-height: 24px; }}
        QWidget#DiffLine QLabel {{ background-color: transparent; }}
        QWidget#DiffLine QLabel#DiffCode {{ color: {foreground}; }}
        """
    )
    return line


class DiffCard(QtWidgets.QFrame):
    def __init__(self, filename, lines, parent=None):
        super().__init__(parent)
        self.setObjectName("DiffCard")
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 8)
        layout.setSpacing(0)

        header = QtWidgets.QWidget()
        header.setObjectName("DiffHeader")
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(12, 9, 12, 9)
        marker = QtWidgets.QLabel("M")
        marker.setObjectName("DiffMarker")
        marker.setAlignment(QtCore.Qt.AlignCenter)
        marker.setFixedSize(22, 20)
        header_layout.addWidget(marker)
        filename_label = QtWidgets.QLabel(filename)
        filename_label.setObjectName("DiffFileTitle")
        filename_label.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        header_layout.addWidget(filename_label)
        header_layout.addStretch(1)
        layout.addWidget(header)

        for old_number, new_number, text, mode in lines:
            layout.addWidget(make_diff_line(old_number, new_number, text, mode))


class ConfigHeader(QtWidgets.QFrame):
    toggle_sidebar = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigHeader")
        self.setFixedHeight(48)

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(16, 0, 16, 0)
        layout.setSpacing(12)

        document_icon = QtWidgets.QLabel()
        document_icon.setPixmap(
            load_lucide_icon("file-text").pixmap(ICON_SIZE, ICON_SIZE)
        )
        document_icon.setFixedSize(ICON_SIZE, ICON_SIZE)
        layout.addWidget(document_icon)

        self.title_label = QtWidgets.QLabel("重写 PLM Qt 前端布局")
        self.title_label.setObjectName("ConfigTitle")
        layout.addWidget(self.title_label)

        layout.addStretch(1)

        self.sidebar_btn = QtWidgets.QPushButton()
        self.sidebar_btn.setObjectName("HeaderIconBtn")
        self.sidebar_btn.setIcon(load_lucide_icon("panel-right"))
        self.sidebar_btn.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.sidebar_btn.setFixedSize(28, 28)
        self.sidebar_btn.setCursor(QtCore.Qt.PointingHandCursor)
        self.sidebar_btn.setToolTip("打开/关闭右侧 Diff 面板")
        self.sidebar_btn.clicked.connect(self.toggle_sidebar.emit)
        layout.addWidget(self.sidebar_btn)

class ConfigPage(QtWidgets.QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.right_panel_width = 400
        self.preview_maximized = False
        self.restore_panel_width = self.right_panel_width
        self.drag_start_global_x = None
        self.drag_start_width = None

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        self.config_header = ConfigHeader()
        self.config_header.toggle_sidebar.connect(self.toggle_diff_panel)
        root.addWidget(self.config_header)

        main_content = QtWidgets.QWidget()
        main_content.setObjectName("ConfigMainContent")
        main_layout = QtWidgets.QVBoxLayout(main_content)
        main_layout.setContentsMargins(20, 10, 20, 18)
        main_layout.setSpacing(0)

        self.tabs = QtWidgets.QTabWidget()
        self.tabs.setObjectName("ConfigTabs")
        self.tabs.setUsesScrollButtons(False)
        pages = (
            ("Controller", "Controller Configuration", "在这里配置控制器 ID、名称与最大 Lane 宽度。"),
            ("LaneMapping", "Lane Mapping Configuration", "在这里配置物理 Lane 与控制器 Lane 的映射关系。"),
            ("Signals", "PIPE Signals", "在这里配置 PIPE 信号、方向、位宽和安全值。"),
            ("Generation", "Generation Settings", "RTL 生成功能将在后续阶段接入。"),
        )
        for tab_name, title, description in pages:
            page = QtWidgets.QWidget()
            page_layout = QtWidgets.QVBoxLayout(page)
            page_layout.setContentsMargins(18, 18, 18, 18)
            page_layout.setSpacing(0)
            page_layout.addWidget(make_label(title, "SectionTitle", word_wrap=False))
            page_layout.addSpacing(8)
            page_layout.addWidget(make_label(description, "MutedText"))
            page_layout.addSpacing(20)
            placeholder = QtWidgets.QFrame()
            placeholder.setObjectName("PlaceholderCard")
            placeholder_layout = QtWidgets.QVBoxLayout(placeholder)
            placeholder_layout.setContentsMargins(40, 40, 40, 40)
            placeholder_layout.addWidget(
                make_label("页面内容占位区域", "PlaceholderText"),
                alignment=QtCore.Qt.AlignTop | QtCore.Qt.AlignLeft,
            )
            page_layout.addWidget(placeholder, 1)
            self.tabs.addTab(page, tab_name)
        main_layout.addWidget(self.tabs, 1)
        root.addWidget(main_content, 1)

        self.drag_button = DragButton(
            on_drag=self.handle_drag,
            on_release=self.handle_release,
        )
        self.drag_button.setParent(self)
        self.drag_button.hide()
        # Compatibility alias for callers that used the earlier name.
        self.drag_handle = self.drag_button

        self.right_panel = QtWidgets.QFrame(self)
        self.right_panel.setObjectName("RightPanel")
        panel_shadow = QtWidgets.QGraphicsDropShadowEffect(self.right_panel)
        panel_shadow.setOffset(0, 2)
        panel_shadow.setColor(QtGui.QColor(0, 0, 0, 30))
        panel_shadow.setBlurRadius(12)
        self.right_panel.setGraphicsEffect(panel_shadow)
        self.right_panel.hide()
        panel_layout = QtWidgets.QVBoxLayout(self.right_panel)
        panel_layout.setContentsMargins(12, 10, 12, 12)
        panel_layout.setSpacing(8)

        toolbar = QtWidgets.QWidget()
        toolbar.setObjectName("RightPanelToolbar")
        toolbar_layout = QtWidgets.QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(0, 0, 0, 0)
        toolbar_layout.setSpacing(8)

        def add_tool_button(attribute, icon_name, tooltip, *, checkable=False, checked=False):
            button = QtWidgets.QToolButton()
            button.setObjectName("RightPanelToolButton")
            button.setIcon(load_lucide_icon(icon_name))
            button.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
            button.setFixedSize(24, 24)
            button.setCheckable(checkable)
            button.setChecked(checked)
            button.setToolTip(tooltip)
            button.setAccessibleName(tooltip)
            button.setCursor(QtCore.Qt.PointingHandCursor)
            setattr(self, attribute, button)
            toolbar_layout.addWidget(button)
            return button

        add_tool_button("preview_root_btn", "folder", "文件")
        toolbar_layout.addStretch(1)
        add_tool_button("preview_refresh_btn", "refresh-cw", "刷新生成文件")
        add_tool_button("preview_edit_btn", "square-pen", "编辑当前文件")
        add_tool_button(
            "preview_highlight_btn",
            "braces",
            "语法高亮",
            checkable=True,
            checked=True,
        )
        add_tool_button("preview_search_btn", "search", "在文件中查找")
        add_tool_button("preview_copy_path_btn", "link", "复制文件路径")
        add_tool_button(
            "preview_diff_btn",
            "file",
            "显示文件差异",
            checkable=True,
        )
        add_tool_button("preview_more_btn", "more-horizontal", "更多操作")
        add_tool_button("preview_expand_btn", "maximize", "最大化预览")
        self.preview_expand_btn.clicked.connect(self.toggle_preview_maximized)
        self.preview_buttons = [
            self.preview_root_btn,
            self.preview_refresh_btn,
            self.preview_edit_btn,
            self.preview_highlight_btn,
            self.preview_diff_btn,
            self.preview_search_btn,
            self.preview_copy_path_btn,
            self.preview_more_btn,
            self.preview_expand_btn,
        ]
        panel_layout.addWidget(toolbar)

        scroll = QtWidgets.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        content = QtWidgets.QWidget()
        content.setObjectName("DiffContent")
        content_layout = QtWidgets.QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(12)
        diffs = (
            (
                "src/plm/core/generator/rtl.py",
                (
                    (21, 21, "def generate_rtl(config):", "context"),
                    (22, None, "    validate_legacy_config(config)", "delete"),
                    (None, 22, "    validate_config(config)", "add"),
                    (23, 23, "    return render_modules(config)", "context"),
                ),
            ),
            (
                "src/plm/core/model.py",
                (
                    (10, 10, "class LaneMapping:", "context"),
                    (11, None, "    lanes = {}", "delete"),
                    (None, 11, "    lanes: dict[int, Lane]", "add"),
                    (12, 12, "", "context"),
                    (13, 13, "    def validate(self):", "context"),
                    (None, 14, "        return bool(self.lanes)", "add"),
                ),
            ),
            (
                "src/plm/frontend/qt/main_window.py",
                (
                    (88, 88, "class ConfigPage(QWidget):", "context"),
                    (89, None, "    pass", "delete"),
                    (None, 89, "    right_panel_width = 400", "add"),
                ),
            ),
        )
        for filename, lines in diffs:
            content_layout.addWidget(DiffCard(filename, lines))
        content_layout.addSpacing(10)
        content_layout.addStretch(1)
        scroll.setWidget(content)
        panel_layout.addWidget(scroll, 1)

    def toggle_diff_panel(self):
        if self.right_panel.isVisible():
            self.hide_diff_panel()
        else:
            self.show_diff_panel()

    def show_diff_panel(self):
        self.right_panel.show()
        self.drag_button.setVisible(not self.preview_maximized)
        self.reposition_right_panel()
        self.right_panel.raise_()
        self.drag_button.raise_()

    def hide_diff_panel(self):
        if self.preview_maximized:
            self.preview_maximized = False
            self.right_panel_width = self.restore_panel_width
            self._update_expand_button()
        self.right_panel.hide()
        self.drag_button.hide()

    def toggle_preview_maximized(self):
        if not self.right_panel.isVisible():
            return
        if self.preview_maximized:
            self.preview_maximized = False
            self.right_panel_width = self.restore_panel_width
            self.drag_button.show()
        else:
            self.restore_panel_width = self.right_panel.width()
            self.preview_maximized = True
            self.drag_button.hide()
        self._update_expand_button()
        self.reposition_right_panel()

    def _update_expand_button(self):
        if self.preview_maximized:
            label = "恢复预览"
        else:
            label = "最大化预览"
        self.preview_expand_btn.setIcon(
            load_lucide_icon("maximize")
        )
        self.preview_expand_btn.setToolTip(label)
        self.preview_expand_btn.setAccessibleName(label)

    def reposition_right_panel(self):
        if not self.right_panel.isVisible():
            return
        total_width = self.width()
        total_height = self.height()
        panel_top = self.config_header.height()
        panel_height = max(0, total_height - panel_top)
        panel_width = (
            total_width
            if self.preview_maximized
            else max(300, min(self.right_panel_width, total_width))
        )
        panel_x = total_width - panel_width
        self.right_panel.setGeometry(panel_x, panel_top, panel_width, panel_height)
        button_x = panel_x - self.drag_button.width() // 2
        button_y = panel_top + (panel_height - self.drag_button.height()) // 2
        self.drag_button.setGeometry(
            button_x,
            button_y,
            self.drag_button.width(),
            self.drag_button.height(),
        )

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.reposition_right_panel()

    def handle_drag(self, action, global_x):
        if action == "start":
            self.drag_start_global_x = global_x
            self.drag_start_width = self.right_panel.width()
            return
        if action != "move" or self.drag_start_global_x is None:
            return
        delta = self.drag_start_global_x - global_x
        self.right_panel_width = max(
            300,
            min(self.drag_start_width + delta, self.width()),
        )
        self.reposition_right_panel()

    def handle_release(self):
        self.drag_start_global_x = None
        self.drag_start_width = None


class DocsPage(QtWidgets.QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(40, 36, 40, 36)
        layout.setSpacing(14)
        layout.addWidget(make_label("Documentation", "LargePageTitle", word_wrap=False))
        layout.addWidget(make_label("PLM 配置工具的使用文档与参考资料。", "MutedText"))
        for title, description in (
            ("快速开始", "创建项目并完成第一份 Controller 配置。"),
            ("配置指南", "了解 Controller、LaneMapping、Signals 和 Generation 页面。"),
            ("数据格式", "查看 PLM 使用的 CSV 配置字段与约束。"),
            ("常见问题", "处理配置校验和界面使用中常见的问题。"),
        ):
            card = QtWidgets.QFrame()
            card.setObjectName("DocCard")
            card_layout = QtWidgets.QVBoxLayout(card)
            card_layout.setContentsMargins(20, 15, 20, 15)
            card_layout.addWidget(make_label(title, "CardTitle", word_wrap=False))
            card_layout.addWidget(make_label(description, "MutedText"))
            layout.addWidget(card)
        layout.addStretch(1)


class SettingsMenu(QtWidgets.QFrame):
    pageChanged = QtCore.pyqtSignal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("SettingsMenu")
        self.setFixedWidth(220)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(10, 24, 10, 20)
        layout.setSpacing(5)
        self.buttons = []
        group = QtWidgets.QButtonGroup(self)
        group.setExclusive(True)
        for index, text in enumerate(("General", "Formatter", "Appearance", "About")):
            button = QtWidgets.QPushButton(text)
            button.setObjectName("SettingsMenuButton")
            button.setCheckable(True)
            button.setCursor(QtCore.Qt.PointingHandCursor)
            button.setChecked(index == 0)
            button.clicked.connect(lambda _checked=False, value=index: self.pageChanged.emit(value))
            group.addButton(button)
            layout.addWidget(button)
            self.buttons.append(button)
        layout.addStretch(1)


class SettingsPage(QtWidgets.QWidget):
    closeRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        root = QtWidgets.QHBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        self.menu = SettingsMenu()
        root.addWidget(self.menu)
        self.content_stack = QtWidgets.QStackedWidget()
        for title, description in (
            ("General", "应用的常规行为设置将在这里提供。"),
            ("Formatter", "代码格式化工具路径和参数将在这里配置。"),
            ("Appearance", "字体、字号和界面密度将在这里配置。"),
            ("About", "plmConsultant — PIPE Lane Mapper 配置工具。"),
        ):
            page = QtWidgets.QWidget()
            layout = QtWidgets.QVBoxLayout(page)
            layout.setContentsMargins(40, 36, 40, 36)
            layout.setSpacing(14)
            layout.addWidget(make_label(title, "LargePageTitle", word_wrap=False))
            layout.addWidget(make_label(description, "MutedText"))
            layout.addWidget(make_label("设置内容占位区域", "SettingsPlaceholder"), 1)
            self.content_stack.addWidget(page)
        root.addWidget(self.content_stack, 1)
        self.menu.pageChanged.connect(self.content_stack.setCurrentIndex)


class CustomTitleBar(QtWidgets.QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("CustomTitleBar")
        self.setFixedHeight(36)
        self.drag_position = None

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(10, 0, 0, 0)
        layout.setSpacing(8)

        self.app_icon = QtWidgets.QLabel()
        self.app_icon.setFixedSize(18, 18)
        self.app_icon.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        if APP_ICON_PATH.is_file():
            self.app_icon.setPixmap(
                QtGui.QIcon(str(APP_ICON_PATH)).pixmap(18, 18)
            )
        layout.addWidget(self.app_icon)

        self.title_label = QtWidgets.QLabel("plmConsultant")
        self.title_label.setObjectName("TitleBarTitle")
        self.title_label.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        layout.addWidget(self.title_label)
        layout.addStretch(1)

        self.minimize_btn = self._make_control_button("─", "最小化")
        self.maximize_btn = self._make_control_button("⛶", "最大化")
        self.close_btn = self._make_control_button("✕", "关闭", role="close")
        self.minimize_btn.clicked.connect(lambda: self.window().showMinimized())
        self.maximize_btn.clicked.connect(self.toggle_maximized)
        self.close_btn.clicked.connect(lambda: self.window().close())
        layout.addWidget(self.minimize_btn)
        layout.addWidget(self.maximize_btn)
        layout.addWidget(self.close_btn)

    def _make_control_button(self, text, tooltip, role="normal"):
        button = QtWidgets.QPushButton(text)
        button.setObjectName("TitleBarBtn")
        button.setProperty("role", role)
        button.setFixedSize(46, 36)
        button.setToolTip(tooltip)
        button.setCursor(QtCore.Qt.PointingHandCursor)
        return button

    def toggle_maximized(self):
        window = self.window()
        if window.isMaximized():
            window.showNormal()
            self.maximize_btn.setText("⛶")
            self.maximize_btn.setToolTip("最大化")
        else:
            window.showMaximized()
            self.maximize_btn.setText("❐")
            self.maximize_btn.setToolTip("还原")

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.drag_position = (
                event.globalPos() - self.window().frameGeometry().topLeft()
            )
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if (
            self.drag_position is not None
            and event.buttons() & QtCore.Qt.LeftButton
            and not self.window().isMaximized()
        ):
            self.window().move(event.globalPos() - self.drag_position)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.drag_position = None
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.toggle_maximized()
            event.accept()
            return
        super().mouseDoubleClickEvent(event)


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(QtCore.Qt.FramelessWindowHint | QtCore.Qt.Window)
        self.setWindowTitle("plmConsultant")
        self.resize(1400, 850)
        self.setMinimumSize(900, 600)
        if APP_ICON_PATH.is_file():
            self.setWindowIcon(QtGui.QIcon(str(APP_ICON_PATH)))

        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        root = QtWidgets.QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        self.title_bar = CustomTitleBar()
        root.addWidget(self.title_bar)

        self.splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        self.splitter.setHandleWidth(1)
        self.splitter.setChildrenCollapsible(False)
        root.addWidget(self.splitter, 1)

        self.nav_panel = NavPanel()
        self.splitter.addWidget(self.nav_panel)
        self.stack = QtWidgets.QStackedWidget()
        self.config_page = ConfigPage()
        self.docs_page = DocsPage()
        self.settings_page = SettingsPage()
        self.stack.addWidget(self.config_page)
        self.stack.addWidget(self.docs_page)
        self.stack.addWidget(self.settings_page)
        self.splitter.addWidget(self.stack)
        self.splitter.setStretchFactor(0, 0)
        self.splitter.setStretchFactor(1, 1)
        self.splitter.setSizes([260, 1000])

        self.nav_panel.navChanged.connect(self.on_nav_changed)
        self.settings_page.closeRequested.connect(lambda: self.on_nav_changed("config"))

    def on_nav_changed(self, destination):
        if destination == "docs":
            self.config_page.hide_diff_panel()
            self.stack.setCurrentWidget(self.docs_page)
            self.nav_panel.set_active("docs")
        elif destination == "settings":
            self.config_page.hide_diff_panel()
            self.stack.setCurrentWidget(self.settings_page)
            self.nav_panel.set_active("settings")
        else:
            self.config_page.hide_diff_panel()
            self.stack.setCurrentWidget(self.config_page)
            self.nav_panel.set_active("")


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())
