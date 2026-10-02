"""Codex-style PyQt5 views for plmConsultant using the native title bar."""

import shutil
import subprocess
import sys
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.services import (
    DEFAULT_EDITOR,
    DEFAULT_FONT_FAMILY,
    DEFAULT_FONT_SIZE,
    ProjectService,
    SettingsStore,
)
from plm.frontend.qt.styles import APP_QSS, build_app_stylesheet
from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    LUCIDE_ICON_DIR,
    PROJECT_ROOT,
    apply_drop_shadow,
    load_lucide_icon,
    make_icon_button,
)
from plm.frontend.qt.widgets.hover_card import HoverCard, HoverIconButton
from plm.frontend.qt.widgets.project_item import ProjectItemWidget
from plm.frontend.qt.widgets.project_list import ProjectList

__all__ = [
    "HoverCard",
    "HoverIconButton",
    "ProjectItemWidget",
    "ProjectList",
    "NavPanel",
    "MainWindow",
]


APP_ICON_PATH = Path(__file__).resolve().parent / "assets" / "app_icon.svg"
DOCS_DIR = Path(__file__).resolve().parents[2] / "docs"




class EscapeLineEdit(QtWidgets.QLineEdit):
    escapePressed = QtCore.pyqtSignal()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.escapePressed.emit()
            event.accept()
            return
        super().keyPressEvent(event)


class DoubleClickLabel(QtWidgets.QLabel):
    doubleClicked = QtCore.pyqtSignal()

    def mouseDoubleClickEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.doubleClicked.emit()
            event.accept()
            return
        super().mouseDoubleClickEvent(event)



class NavPanel(QtWidgets.QFrame):
    """Region 3: actions, draggable projects, and footer navigation."""

    new_chat_requested = QtCore.pyqtSignal()
    save_requested = QtCore.pyqtSignal()
    settings_requested = QtCore.pyqtSignal()
    docs_requested = QtCore.pyqtSignal()
    project_archived = QtCore.pyqtSignal(str)
    project_deleted = QtCore.pyqtSignal(str)
    project_renamed = QtCore.pyqtSignal(str, str)
    project_selected = QtCore.pyqtSignal(str)

    def __init__(self, parent=None, project_service=None, settings_store=None):
        super().__init__(parent)
        self.project_service = project_service or ProjectService(PROJECT_ROOT)
        self.settings_store = settings_store or SettingsStore()
        self.setObjectName("NavPanel")
        self.expanded_width = 260
        self.collapsed_width = 56
        self.expanded_min_width = 200
        self.expanded_max_width = 400
        self.is_collapsed = False
        self.is_animating = False
        self._target_collapsed = False
        self.setMinimumWidth(self.expanded_min_width)
        self.setMaximumWidth(self.expanded_max_width)

        self.animation_min = QtCore.QPropertyAnimation(self, b"minimumWidth", self)
        self.animation_max = QtCore.QPropertyAnimation(self, b"maximumWidth", self)
        for animation in (
            self.animation_min,
            self.animation_max,
        ):
            animation.setDuration(200)
            animation.setEasingCurve(QtCore.QEasingCurve.OutCubic)
        self.animation_group = QtCore.QParallelAnimationGroup(self)
        self.animation_group.addAnimation(self.animation_min)
        self.animation_group.addAnimation(self.animation_max)
        self.animation_max.valueChanged.connect(self._apply_animated_width)
        self.animation_group.finished.connect(self._on_collapse_animation_finished)
        root = QtWidgets.QVBoxLayout(self)
        root.setSizeConstraint(QtWidgets.QLayout.SetNoConstraint)
        root.setContentsMargins(12, 8, 12, 8)
        root.setSpacing(8)

        self.brand_row = QtWidgets.QWidget()
        self.brand_row.setObjectName("NavBrandRow")
        self.brand_row.setFixedHeight(40)
        self.brand_layout = QtWidgets.QHBoxLayout(self.brand_row)
        self.brand_layout.setContentsMargins(0, 0, 0, 0)
        self.brand_layout.setSpacing(0)
        self.logo_label = QtWidgets.QLabel()
        self.logo_label.setObjectName("NavLogo")
        self.logo_label.setPixmap(
            load_lucide_icon(
                "layout-dashboard", "#1677FF", align_visible_left=True
            ).pixmap(20, 20)
        )
        self.logo_label.setFixedSize(20, 20)
        self.brand_layout.addWidget(self.logo_label)
        self.brand_logo_gap = QtWidgets.QSpacerItem(
            8, 0, QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Minimum
        )
        self.brand_layout.addItem(self.brand_logo_gap)
        self.app_name_label = QtWidgets.QLabel("plmConsultant")
        self.app_name_label.setObjectName("NavAppName")
        self.brand_layout.addWidget(self.app_name_label)
        self.brand_stretch = QtWidgets.QSpacerItem(
            0, 0, QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Minimum
        )
        self.brand_layout.addItem(self.brand_stretch)
        self.brand_button_gap = QtWidgets.QSpacerItem(
            2, 0, QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Minimum
        )
        self.brand_layout.addItem(self.brand_button_gap)
        self.collapse_btn = make_icon_button(
            "panel-left", "收起侧边栏", "NavCollapseButton", 32, ICON_SIZE
        )
        self.collapse_btn.clicked.connect(self.toggle_collapse)
        self.brand_layout.addWidget(self.collapse_btn)
        self.brand_layout.setAlignment(self.collapse_btn, QtCore.Qt.AlignVCenter)
        root.addWidget(self.brand_row)

        self.new_chat_btn = self._action_button(
            "square-pen", "新对话", self.new_chat_requested
        )
        self.save_btn = self._action_button("save", "保存", self.save_requested)
        self.new_chat_row, self.new_chat_row_layout = self._nav_row(
            self.new_chat_btn
        )
        self.save_row, self.save_row_layout = self._nav_row(self.save_btn)
        root.addWidget(self.new_chat_row)
        root.addWidget(self.save_row)
        root.addSpacing(4)

        self.project_title = QtWidgets.QLabel("项目")
        self.project_title.setObjectName("ProjectSectionTitle")
        root.addWidget(self.project_title)
        config_projects = self.project_service.discover()
        self.project_list = ProjectList(config_projects)
        self.project_list.projectArchived.connect(self._project_archived)
        self.project_list.projectDeleted.connect(self._project_deleted)
        self.project_list.projectRenamed.connect(self._project_renamed)
        self.project_list.projectSelected.connect(self._project_selected)
        root.addWidget(self.project_list, 1)

        recent_project = self.settings_store.recent_project()
        self.current_project_name = self.project_list.select_project(
            recent_project, emit_signal=False
        )

        self.collapsed_projects = QtWidgets.QWidget()
        collapsed_projects_layout = QtWidgets.QVBoxLayout(self.collapsed_projects)
        collapsed_projects_layout.setContentsMargins(0, 0, 0, 0)
        collapsed_projects_layout.setSpacing(8)
        collapsed_projects_layout.setAlignment(
            QtCore.Qt.AlignTop | QtCore.Qt.AlignHCenter
        )
        self.collapsed_project_buttons = []
        for project in config_projects:
            button = self._collapsed_icon_button(
                "folder",
                project.name,
                lambda _checked=False, value=project.name: (
                    self.project_list.select_project(value)
                ),
            )
            collapsed_projects_layout.addWidget(
                button, 0, QtCore.Qt.AlignHCenter
            )
            self.collapsed_project_buttons.append(button)
        collapsed_projects_layout.addStretch(1)
        self.collapsed_projects.hide()
        root.addWidget(self.collapsed_projects, 1)

        self.footer = QtWidgets.QWidget()
        footer_layout = QtWidgets.QVBoxLayout(self.footer)
        footer_layout.setContentsMargins(0, 0, 0, 0)
        footer_layout.setSpacing(8)
        self.docs_btn = self._footer_button(
            "file-text", "Docs", self.docs_requested
        )
        self.settings_btn = self._footer_button(
            "settings", "Settings", self.settings_requested
        )
        self.settings_row, self.settings_row_layout = self._nav_row(
            self.settings_btn
        )
        self.docs_row, self.docs_row_layout = self._nav_row(self.docs_btn)
        footer_layout.addWidget(self.settings_row)
        footer_layout.addWidget(self.docs_row)
        root.addWidget(self.footer)

        self.collapsed_footer = QtWidgets.QWidget()
        collapsed_footer_layout = QtWidgets.QVBoxLayout(self.collapsed_footer)
        collapsed_footer_layout.setContentsMargins(0, 0, 0, 0)
        collapsed_footer_layout.setSpacing(8)
        collapsed_footer_layout.setAlignment(QtCore.Qt.AlignHCenter)
        self.collapsed_settings_btn = self._collapsed_icon_button(
            "settings",
            "Settings",
            lambda _checked=False: self.settings_requested.emit(),
        )
        self.collapsed_docs_btn = self._collapsed_icon_button(
            "file-text",
            "Docs",
            lambda _checked=False: self.docs_requested.emit(),
        )
        collapsed_footer_layout.addWidget(
            self.collapsed_settings_btn, 0, QtCore.Qt.AlignHCenter
        )
        collapsed_footer_layout.addWidget(
            self.collapsed_docs_btn, 0, QtCore.Qt.AlignHCenter
        )
        self.collapsed_footer.hide()
        root.addWidget(self.collapsed_footer)
        self.collapsible_widgets = [
            self.logo_label,
            self.app_name_label,
        ]

    def toggle_collapse(self):
        if self.is_animating:
            return

        self._target_collapsed = not self.is_collapsed
        start_width = self.width()
        end_width = (
            self.collapsed_width if self._target_collapsed else self.expanded_width
        )
        if not self._target_collapsed:
            self._set_expanded_content_visible(True)

        self.is_animating = True
        splitter = self.parentWidget()
        if isinstance(splitter, QtWidgets.QSplitter):
            splitter.handle(1).setEnabled(False)
        for animation in (self.animation_min, self.animation_max):
            animation.setStartValue(start_width)
            animation.setEndValue(end_width)
        self.animation_group.start()

    def _apply_animated_width(self, width):
        splitter = self.parentWidget()
        if not isinstance(splitter, QtWidgets.QSplitter) or splitter.count() != 2:
            return
        total_width = sum(splitter.sizes())
        nav_width = int(width)
        splitter.setSizes([nav_width, max(1, total_width - nav_width)])

    def _on_collapse_animation_finished(self):
        self.is_collapsed = self._target_collapsed
        if self.is_collapsed:
            self._set_expanded_content_visible(False)
        else:
            self.setMinimumWidth(self.expanded_min_width)
            self.setMaximumWidth(self.expanded_max_width)
        self.collapse_btn.setIcon(
            load_lucide_icon(
                "panel-right" if self.is_collapsed else "panel-left",
                "#666666",
            )
        )
        self.collapse_btn.setToolTip(
            "展开侧边栏" if self.is_collapsed else "收起侧边栏"
        )
        splitter = self.parentWidget()
        if isinstance(splitter, QtWidgets.QSplitter):
            splitter.handle(1).setEnabled(not self.is_collapsed)
        self.is_animating = False

    def _set_expanded_content_visible(self, visible):
        self.setProperty("collapsed", not visible)
        self.style().unpolish(self)
        self.style().polish(self)
        for widget in self.collapsible_widgets:
            widget.setVisible(visible)
        if visible:
            self.brand_logo_gap.changeSize(
                8, 0, QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Minimum
            )
            self.brand_stretch.changeSize(
                0, 0, QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Minimum
            )
            self.brand_button_gap.changeSize(
                2, 0, QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Minimum
            )
        else:
            for spacer in (
                self.brand_logo_gap,
                self.brand_stretch,
                self.brand_button_gap,
            ):
                spacer.changeSize(
                    0, 0, QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Minimum
                )
        self.brand_layout.invalidate()

        self.new_chat_btn.setText("新对话" if visible else "")
        self.save_btn.setText("保存" if visible else "")
        for button in (self.new_chat_btn, self.save_btn):
            button.setObjectName("NavActionButton" if visible else "NavIconBtn")
            if visible:
                button.setMinimumWidth(0)
                button.setMaximumWidth(QtWidgets.QWIDGETSIZE_MAX)
            else:
                button.setFixedSize(32, 32)
            button.style().unpolish(button)
            button.style().polish(button)

        self.project_title.setText("项目" if visible else "")
        self.project_list.setVisible(visible)
        self.collapsed_projects.setVisible(not visible)
        self.footer.setVisible(visible)
        self.collapsed_footer.setVisible(not visible)

    def _collapsed_icon_button(self, icon_name, tooltip, callback):
        button = make_icon_button(
            icon_name,
            tooltip,
            "NavIconBtn",
            32,
            ICON_SIZE,
        )
        button.clicked.connect(callback)
        return button

    @staticmethod
    def _nav_row(widget):
        row = QtWidgets.QWidget()
        layout = QtWidgets.QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(widget)
        return row, layout

    def _action_button(self, icon_name, text, requested_signal):
        button = QtWidgets.QPushButton(text)
        button.setObjectName("NavActionButton")
        button.setIcon(load_lucide_icon(icon_name, align_visible_left=True))
        button.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        button.setCursor(QtCore.Qt.PointingHandCursor)
        button.clicked.connect(
            lambda _checked=False: requested_signal.emit()
        )
        return button

    def _footer_button(self, icon_name, text, requested_signal):
        button = QtWidgets.QPushButton(text)
        button.setObjectName("NavFooterButton")
        button.setIcon(load_lucide_icon(icon_name, align_visible_left=True))
        button.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        button.setCursor(QtCore.Qt.PointingHandCursor)
        button.clicked.connect(
            lambda _checked=False: requested_signal.emit()
        )
        return button

    def _project_archived(self, project_name):
        self._remove_collapsed_project(project_name)
        self.project_archived.emit(project_name)

    def _project_deleted(self, project_name):
        self._remove_collapsed_project(project_name)
        self.project_deleted.emit(project_name)

    def _project_renamed(self, old_name, new_name):
        for button in self.collapsed_project_buttons:
            if button.toolTip() == old_name:
                button.setToolTip(new_name)
                break
        self.project_renamed.emit(old_name, new_name)

    def _project_selected(self, project_name):
        self.current_project_name = project_name
        self.settings_store.set_recent_project(project_name)
        self.project_selected.emit(project_name)

    def emit_current_project(self):
        if self.current_project_name:
            self.project_selected.emit(self.current_project_name)

    def _remove_collapsed_project(self, project_name):
        for button in tuple(self.collapsed_project_buttons):
            if button.toolTip() != project_name:
                continue
            self.collapsed_project_buttons.remove(button)
            button.setParent(None)
            button.deleteLater()
            break

    def set_active(self, name):
        for button, value in ((self.docs_btn, "docs"), (self.settings_btn, "settings")):
            selected = name == value
            button.setProperty("selected", selected)
            color = "#1677FF" if selected else "#666666"
            icon_name = "file-text" if value == "docs" else "settings"
            button.setIcon(
                load_lucide_icon(icon_name, color, align_visible_left=True)
            )
            button.style().unpolish(button)
            button.style().polish(button)
        self.collapsed_docs_btn.setIcon(
            load_lucide_icon("file-text", "#1677FF" if name == "docs" else "#666666")
        )
        self.collapsed_settings_btn.setIcon(
            load_lucide_icon(
                "settings", "#1677FF" if name == "settings" else "#666666"
            )
        )


class ConfigHeader(QtWidgets.QFrame):
    """Region 2.1: editable session title and panel toggles."""

    logToggleRequested = QtCore.pyqtSignal()
    artifactsToggleRequested = QtCore.pyqtSignal()
    titleChanged = QtCore.pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigHeader")
        self.setFixedHeight(56)
        self._original_title = ""
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(20, 8, 12, 8)
        layout.setSpacing(8)
        self.title_label = DoubleClickLabel("重写 PLM Qt 前端布局")
        self.title_label.setObjectName("ConfigSessionTitle")
        self.title_label.setToolTip("双击重命名")
        self.title_label.doubleClicked.connect(self.enter_edit_mode)
        layout.addWidget(self.title_label)
        self.title_edit = EscapeLineEdit()
        self.title_edit.setObjectName("ConfigSessionEditor")
        self.title_edit.hide()
        self.title_edit.returnPressed.connect(self.save_title)
        self.title_edit.editingFinished.connect(self.save_title)
        self.title_edit.escapePressed.connect(self.cancel_title)
        layout.addWidget(self.title_edit)
        layout.addStretch(1)
        self.log_btn = make_icon_button(
            "panel-bottom", "显示/隐藏输出面板", "HeaderButton", 28
        )
        self.artifacts_btn = make_icon_button(
            "panel-right", "显示/隐藏 Artifacts", "HeaderButton", 28
        )
        self.log_btn.clicked.connect(self.logToggleRequested.emit)
        self.artifacts_btn.clicked.connect(self.artifactsToggleRequested.emit)
        layout.addWidget(self.log_btn)
        layout.addWidget(self.artifacts_btn)

    def enter_edit_mode(self):
        self._original_title = self.title_label.text()
        self.title_edit.setText(self._original_title)
        self.title_label.hide()
        self.title_edit.show()
        self.title_edit.selectAll()
        self.title_edit.setFocus(QtCore.Qt.OtherFocusReason)

    def save_title(self):
        if not self.title_edit.isVisible():
            return
        new_title = self.title_edit.text().strip() or self._original_title
        self.title_label.setText(new_title)
        self.title_edit.hide()
        self.title_label.show()
        self.titleChanged.emit(new_title)

    def cancel_title(self):
        if not self.title_edit.isVisible():
            return
        self.title_edit.hide()
        self.title_label.setText(self._original_title)
        self.title_label.show()


class ConfigTabPage(QtWidgets.QWidget):
    def __init__(self, title, description, parent=None):
        super().__init__(parent)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(20, 16, 20, 16)
        root.setSpacing(0)
        heading = QtWidgets.QLabel(title)
        heading.setObjectName("ConfigTitle")
        root.addWidget(heading)
        root.addSpacing(8)
        description_label = QtWidgets.QLabel(description)
        description_label.setObjectName("ConfigDescription")
        description_label.setWordWrap(True)
        root.addWidget(description_label)
        root.addSpacing(20)

        scroll = QtWidgets.QScrollArea()
        scroll.setObjectName("ConfigScroll")
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        content = QtWidgets.QWidget()
        content.setObjectName("ConfigScrollContent")
        content_layout = QtWidgets.QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 8, 0)
        content_layout.setSpacing(16)
        for label_text in (
            "基础配置",
            "参数映射与校验",
            "生成选项（业务控件将在后续阶段接入）",
        ):
            card = QtWidgets.QFrame()
            card.setObjectName("ConfigPlaceholderCard")
            apply_drop_shadow(card)
            card_layout = QtWidgets.QHBoxLayout(card)
            card_layout.setContentsMargins(20, 16, 20, 16)
            label = QtWidgets.QLabel(label_text)
            label.setObjectName("PlaceholderLabel")
            card_layout.addWidget(label)
            card_layout.addStretch(1)
            content_layout.addWidget(card)
        content_layout.addStretch(1)
        scroll.setWidget(content)
        root.addWidget(scroll, 1)


class DragHandle(QtWidgets.QWidget):
    """White capsule handle for resizing the floating Artifacts panel."""

    def __init__(self, on_drag, on_release, parent=None):
        super().__init__(parent)
        self.on_drag = on_drag
        self.on_release = on_release
        self.drag_start_x = None
        self.setFixedSize(14, 36)
        self.setCursor(QtCore.Qt.SplitHCursor)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        capsule = QtCore.QRectF(0.5, 0.5, 13, 35)
        painter.setPen(QtGui.QPen(QtGui.QColor("#C0C4CC"), 1))
        painter.setBrush(QtGui.QColor("#FFFFFF"))
        painter.drawRoundedRect(capsule, 7, 7)
        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(QtGui.QColor("#A0A5B0"))
        painter.drawRect(QtCore.QRectF(4, 14, 1.5, 8))
        painter.drawRect(QtCore.QRectF(8.5, 14, 1.5, 8))

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            self.drag_start_x = event.globalPos().x()
            self.on_drag("start", self.drag_start_x)
            event.accept()

    def mouseMoveEvent(self, event):
        if self.drag_start_x is not None:
            self.on_drag("move", event.globalPos().x())
            event.accept()

    def mouseReleaseEvent(self, event):
        if self.drag_start_x is not None:
            self.drag_start_x = None
            self.on_release()
            event.accept()


class DiffLine(QtWidgets.QWidget):
    def __init__(self, old_number, new_number, text, mode="ctx", parent=None):
        super().__init__(parent)
        self.setObjectName("DiffLine")
        self.setProperty("mode", mode)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        for number in (old_number, new_number):
            label = QtWidgets.QLabel("" if number is None else str(number))
            label.setObjectName("DiffLineNumber")
            label.setFixedWidth(32)
            label.setAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
            layout.addWidget(label)
        prefix = "+" if mode == "add" else "-" if mode == "del" else " "
        code = QtWidgets.QLabel(f"{prefix} {text}")
        code.setObjectName("DiffCode")
        code.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        layout.addWidget(code, 1)


class FileDiffCard(QtWidgets.QFrame):
    def __init__(self, file_path, lines, parent=None):
        super().__init__(parent)
        self.file_path = Path(file_path)
        self.setObjectName("FileDiffCard")
        apply_drop_shadow(self)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 8)
        root.setSpacing(0)
        header = QtWidgets.QWidget()
        header.setObjectName("FileCardHeader")
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(16, 12, 16, 12)
        header_layout.setSpacing(8)
        marker = QtWidgets.QLabel("M")
        marker.setObjectName("ModifiedMarker")
        marker.setAlignment(QtCore.Qt.AlignCenter)
        marker.setFixedSize(20, 18)
        header_layout.addWidget(marker)
        path_label = QtWidgets.QLabel(str(file_path))
        path_label.setObjectName("FilePathLabel")
        path_label.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        header_layout.addWidget(path_label, 1)
        copy_btn = make_icon_button("link", "复制路径", "CardActionButton", 24, 16)
        open_btn = make_icon_button(
            "square-pen", "在编辑器中打开", "CardActionButton", 24, 16
        )
        copy_btn.clicked.connect(self.copy_path)
        open_btn.clicked.connect(self.open_in_editor)
        header_layout.addWidget(copy_btn)
        header_layout.addWidget(open_btn)
        root.addWidget(header)
        for old_number, new_number, text, mode in lines:
            root.addWidget(DiffLine(old_number, new_number, text, mode))

    def copy_path(self):
        QtWidgets.QApplication.clipboard().setText(str(self.file_path))

    def open_in_editor(self):
        editor = SettingsStore().editor_path()
        configured_path = Path(editor).expanduser()
        executable = str(configured_path) if configured_path.is_file() else shutil.which(editor)
        if executable is None:
            QtWidgets.QMessageBox.warning(
                self, "无法打开编辑器", f"未找到 {editor}，请先安装并加入 PATH。"
            )
            return
        try:
            subprocess.Popen([executable, str(self.file_path)])
        except OSError as error:
            QtWidgets.QMessageBox.warning(self, "无法打开编辑器", str(error))


class ArtifactsPanel(QtWidgets.QFrame):
    """Region 5: floating generated-file and diff viewer."""

    maximizeRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactsPanel")
        apply_drop_shadow(self, offset=(0, 2), blur_radius=12, alpha=30)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(12, 0, 12, 12)
        root.setSpacing(12)
        toolbar = QtWidgets.QWidget()
        toolbar.setObjectName("ArtifactsToolbar")
        toolbar.setFixedHeight(40)
        toolbar_layout = QtWidgets.QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(16, 0, 16, 0)
        toolbar_layout.setSpacing(8)
        self.toolbar_buttons = []
        for index, (icon_name, tooltip) in enumerate(
            (
                ("folder", "打开文件夹"),
                ("refresh-cw", "刷新"),
                ("square-pen", "编辑"),
                ("braces", "查看代码"),
                ("search", "搜索"),
                ("link", "复制链接"),
                ("file", "文件"),
                ("more-horizontal", "更多"),
                ("maximize", "展开"),
            )
        ):
            button = make_icon_button(
                icon_name, tooltip, "ArtifactsToolButton", 24, ICON_SIZE
            )
            toolbar_layout.addWidget(button)
            self.toolbar_buttons.append(button)
            if index == 0:
                toolbar_layout.addStretch(1)
        self.toolbar_buttons[-1].clicked.connect(self.maximizeRequested.emit)
        root.addWidget(toolbar)

        scroll = QtWidgets.QScrollArea()
        scroll.setObjectName("ArtifactsScroll")
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        content = QtWidgets.QWidget()
        content.setObjectName("ArtifactsContent")
        content_layout = QtWidgets.QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(12)
        examples = (
            (
                "src/plm/frontend/qt/main_window.py",
                ((81, 81, "class ConfigPage(QFrame):", "ctx"),
                 (82, None, "    pass", "del"),
                 (None, 82, "    artifacts_width = 400", "add")),
            ),
            (
                "src/plm/core/generator/rtl.py",
                ((21, 21, "def generate_rtl(config):", "ctx"),
                 (22, None, "    legacy_validate(config)", "del"),
                 (None, 22, "    validate_config(config)", "add"),
                 (23, 23, "    return render(config)", "ctx")),
            ),
            (
                "test/plm_config.json",
                ((4, 4, '  "lanes": [', "ctx"),
                 (5, None, '    {"id": 0}', "del"),
                 (None, 5, '    {"id": 0, "width": 8}', "add")),
            ),
        )
        for file_path, lines in examples:
            content_layout.addWidget(FileDiffCard(file_path, lines))
        content_layout.addStretch(1)
        scroll.setWidget(content)
        root.addWidget(scroll, 1)


class ConfigPage(QtWidgets.QFrame):
    """Region 2 with an absolute-positioned Region 5 overlay."""

    logToggleRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ConfigPage")
        apply_drop_shadow(self)
        self.artifacts_width = 400
        self.restore_artifacts_width = 400
        self.artifacts_maximized = False
        self.drag_start_global_x = None
        self.drag_start_width = None

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        self.header = ConfigHeader()
        self.header.logToggleRequested.connect(self.logToggleRequested.emit)
        self.header.artifactsToggleRequested.connect(self.toggle_artifacts)
        root.addWidget(self.header)
        root.addSpacing(12)

        self.config_area = QtWidgets.QWidget()
        self.config_area.setObjectName("ConfigArea")
        config_layout = QtWidgets.QVBoxLayout(self.config_area)
        config_layout.setContentsMargins(0, 0, 0, 0)
        self.tabs = QtWidgets.QTabWidget()
        self.tabs.setObjectName("ConfigTabs")
        self.tabs.setUsesScrollButtons(False)
        for tab_name, title, description in (
            ("Controller", "Controller Configuration", "配置控制器 ID、名称和最大 Lane 宽度。"),
            ("LaneMapping", "Lane Mapping Configuration", "配置物理 Lane 与控制器 Lane 的映射关系。"),
            ("Signals", "PIPE Signals", "配置 PIPE 信号、方向、位宽与安全值。"),
            ("Generation", "Generation Settings", "检查输出目录和 RTL 生成参数。"),
        ):
            self.tabs.addTab(ConfigTabPage(title, description), tab_name)
        config_layout.addWidget(self.tabs, 1)
        root.addWidget(self.config_area, 1)

        self.artifacts_panel = ArtifactsPanel(self.config_area)
        self.artifacts_panel.maximizeRequested.connect(self.toggle_artifacts_maximized)
        self.drag_handle = DragHandle(
            self.handle_artifacts_drag, self.finish_artifacts_drag, self.config_area
        )
        self.artifacts_panel.show()
        self.drag_handle.show()
        self.config_area.installEventFilter(self)
        QtCore.QTimer.singleShot(0, self.reposition_artifacts)

    def update_title(self, project_name):
        self.header.title_label.setText(project_name)

    def eventFilter(self, watched, event):
        if watched is self.config_area and event.type() == QtCore.QEvent.Resize:
            self.reposition_artifacts()
        return super().eventFilter(watched, event)

    def toggle_artifacts(self):
        visible = not self.artifacts_panel.isVisible()
        self.artifacts_panel.setVisible(visible)
        self.drag_handle.setVisible(visible and not self.artifacts_maximized)
        if visible:
            self.reposition_artifacts()
            self.artifacts_panel.raise_()
            self.drag_handle.raise_()

    def toggle_artifacts_maximized(self):
        if not self.artifacts_panel.isVisible():
            return
        if self.artifacts_maximized:
            self.artifacts_maximized = False
            self.artifacts_width = self.restore_artifacts_width
            self.drag_handle.show()
        else:
            self.restore_artifacts_width = self.artifacts_panel.width()
            self.artifacts_maximized = True
            self.drag_handle.hide()
        self.reposition_artifacts()

    def reposition_artifacts(self):
        if not self.artifacts_panel.isVisible():
            return
        total_width = self.config_area.width()
        total_height = self.config_area.height()
        if total_width <= 0 or total_height <= 0:
            return
        minimum = min(300, total_width)
        panel_width = (
            total_width
            if self.artifacts_maximized
            else max(minimum, min(self.artifacts_width, total_width))
        )
        panel_x = total_width - panel_width
        self.artifacts_panel.setGeometry(panel_x, 0, panel_width, total_height)
        handle_x = panel_x - self.drag_handle.width() // 2
        handle_y = (total_height - self.drag_handle.height()) // 2
        self.drag_handle.setGeometry(handle_x, handle_y, 14, 36)
        self.artifacts_panel.raise_()
        self.drag_handle.raise_()

    def handle_artifacts_drag(self, action, global_x):
        if action == "start":
            self.drag_start_global_x = global_x
            self.drag_start_width = self.artifacts_panel.width()
            return
        if action != "move" or self.drag_start_global_x is None:
            return
        delta = self.drag_start_global_x - global_x
        maximum = self.config_area.width()
        minimum = min(300, maximum)
        self.artifacts_width = max(
            minimum, min(self.drag_start_width + delta, maximum)
        )
        self.reposition_artifacts()

    def finish_artifacts_drag(self):
        self.drag_start_global_x = None
        self.drag_start_width = None


class LogPanel(QtWidgets.QFrame):
    """Region 4: output tab, clear action, and auto-scrolling log."""

    closeRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("LogPanel")
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        header = QtWidgets.QFrame()
        header.setObjectName("LogHeader")
        header.setFixedHeight(32)
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(16, 0, 12, 0)
        header_layout.setSpacing(8)
        title = QtWidgets.QLabel("输出")
        title.setObjectName("LogTabTitle")
        header_layout.addWidget(title)
        header_layout.addStretch(1)
        self.clear_btn = make_icon_button(
            "trash-2", "清空日志", "LogClearButton", 20, 20
        )
        self.clear_btn.clicked.connect(self.clear)
        header_layout.addWidget(self.clear_btn)
        self.close_btn = make_icon_button(
            "x", "关闭输出面板", "LogCloseBtn", 24, ICON_SIZE
        )
        self.close_btn.clicked.connect(self.closeRequested.emit)
        header_layout.addWidget(self.close_btn)
        root.addWidget(header)
        self.output = QtWidgets.QPlainTextEdit()
        self.output.setObjectName("LogOutput")
        self.output.setReadOnly(True)
        root.addWidget(self.output, 1)
        for line in (
            "[10:24:01] PLM workspace loaded",
            "[10:24:02] Controller configuration validated",
            "[10:24:03] Waiting for generation command...",
        ):
            self.append_log(line)

    def append_log(self, text):
        self.output.appendPlainText(text)
        bar = self.output.verticalScrollBar()
        bar.setValue(bar.maximum())

    def clear(self):
        self.output.clear()


class PlaceholderOverlay(QtWidgets.QFrame):
    """Full-window Settings or documentation page."""

    closeRequested = QtCore.pyqtSignal()
    preferencesSaved = QtCore.pyqtSignal(dict)

    def __init__(self, page, parent=None, settings_store=None):
        super().__init__(parent)
        self.page = page
        self.settings_store = settings_store or SettingsStore()
        self.setObjectName("PlaceholderOverlay")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setFocusPolicy(QtCore.Qt.StrongFocus)

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        header = QtWidgets.QFrame()
        header.setObjectName("PlaceholderDialogHeader")
        header.setFixedHeight(56)
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(20, 0, 20, 0)
        header_layout.setSpacing(12)
        self.back_btn = make_icon_button(
            "arrow-left", "返回", "PlaceholderBackButton", 32, 20, "#333333"
        )
        self.back_btn.clicked.connect(self.closeRequested.emit)
        header_layout.addWidget(self.back_btn)
        self.title_label = QtWidgets.QLabel(
            "Settings" if page == "settings" else "Documentation"
        )
        self.title_label.setObjectName("PlaceholderDialogTitle")
        header_layout.addWidget(self.title_label)
        header_layout.addStretch(1)
        root.addWidget(header)

        page_area = QtWidgets.QWidget()
        page_area.setObjectName("PlaceholderPageArea")
        page_area_layout = QtWidgets.QHBoxLayout(page_area)
        page_area_layout.setContentsMargins(32, 40, 32, 40)
        page_area_layout.setSpacing(0)
        page_area_layout.addStretch(1)

        self.page_panel = QtWidgets.QWidget()
        self.page_panel.setObjectName("PlaceholderPagePanel")
        self.page_panel.setFixedWidth(800)
        self.page_panel.setSizePolicy(
            QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Expanding
        )
        panel_layout = QtWidgets.QVBoxLayout(self.page_panel)
        panel_layout.setContentsMargins(0, 0, 0, 0)
        panel_layout.setSpacing(0)
        self.content = (
            self._build_settings_content()
            if page == "settings"
            else self._build_docs_content()
        )
        panel_layout.addWidget(self._build_menu(page))
        divider = QtWidgets.QFrame()
        divider.setObjectName("PlaceholderTabDivider")
        divider.setFixedHeight(1)
        panel_layout.addWidget(divider)
        panel_layout.addSpacing(24)
        panel_layout.addWidget(self.content, 1)
        page_area_layout.addWidget(self.page_panel, 0)
        page_area_layout.addStretch(1)
        root.addWidget(page_area, 1)
        self._select_section(0)

    def _build_menu(self, page):
        menu = QtWidgets.QWidget()
        menu.setObjectName("PlaceholderTabs")
        layout = QtWidgets.QHBoxLayout(menu)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        self.menu_buttons = []
        entries = (
            ("General", "Appearance", "Tools")
            if page == "settings"
            else ("Getting Started", "Configuration", "Generation")
        )
        for index, text in enumerate(entries):
            button = QtWidgets.QPushButton(text)
            button.setObjectName("PlaceholderMenuButton")
            button.setCursor(QtCore.Qt.PointingHandCursor)
            button.clicked.connect(
                lambda _checked=False, selected=index: self._select_section(selected)
            )
            layout.addWidget(button)
            self.menu_buttons.append(button)
        layout.addStretch(1)
        return menu

    def _content_shell(self, heading, description):
        content = QtWidgets.QWidget()
        content.setObjectName("PlaceholderContent")
        layout = QtWidgets.QVBoxLayout(content)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        self.heading_label = QtWidgets.QLabel(heading)
        self.heading_label.setObjectName("PlaceholderHeading")
        layout.addWidget(self.heading_label)
        layout.addSpacing(4)
        self.description_label = QtWidgets.QLabel(description)
        self.description_label.setObjectName("PlaceholderDescription")
        self.description_label.setWordWrap(True)
        layout.addWidget(self.description_label)
        layout.addSpacing(24)
        return content, layout

    def _setting_row(self, label, control):
        row = QtWidgets.QFrame()
        row.setObjectName("PlaceholderSettingRow")
        row.setFixedHeight(56)
        row_layout = QtWidgets.QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        key_label = QtWidgets.QLabel(label)
        key_label.setObjectName("PlaceholderRowLabel")
        row_layout.addWidget(key_label)
        row_layout.addStretch(1)
        row_layout.addWidget(control)
        return row

    def _build_settings_content(self):
        content, layout = self._content_shell(
            "General", "配置会保存在本机，并在下次启动时自动恢复。"
        )
        preferences = self.settings_store.preferences()

        self.font_family_combo = QtWidgets.QFontComboBox()
        self.font_family_combo.setObjectName("SettingsFontFamily")
        self.font_family_combo.setCurrentFont(
            QtGui.QFont(
                preferences["font_family"]
            )
        )
        self.font_family_combo.setFixedSize(280, 36)
        chevron_path = (LUCIDE_ICON_DIR / "chevron-down.svg").as_posix()
        self.font_family_combo.setStyleSheet(
            "QFontComboBox { border: 1px solid #E0E0E0; border-radius: 6px; }"
            "QComboBox::drop-down { border: none; width: 40px; }"
            f"QComboBox::down-arrow {{ image: url({chevron_path});"
            " width: 16px; height: 16px; }"
        )

        self.font_size_spin = QtWidgets.QSpinBox()
        self.font_size_spin.setObjectName("SettingsFontSize")
        self.font_size_spin.setRange(10, 20)
        self.font_size_spin.setButtonSymbols(QtWidgets.QAbstractSpinBox.NoButtons)
        self.font_size_spin.setValue(
            preferences["font_size"]
        )
        self.font_size_spin.setFixedSize(280, 36)

        editor_control = QtWidgets.QWidget()
        editor_control.setObjectName("SettingsEditorControl")
        editor_control.setFixedSize(280, 36)
        editor_layout = QtWidgets.QHBoxLayout(editor_control)
        editor_layout.setContentsMargins(0, 0, 0, 0)
        editor_layout.setSpacing(8)
        self.editor_path_edit = QtWidgets.QLineEdit(
            preferences["editor_path"]
        )
        self.editor_path_edit.setObjectName("SettingsEditorPath")
        self.editor_path_edit.setFixedHeight(36)
        browse_btn = QtWidgets.QPushButton("浏览…")
        browse_btn.setObjectName("SettingsBrowseButton")
        browse_btn.setFixedSize(68, 36)
        browse_btn.clicked.connect(self._browse_editor)
        editor_layout.addWidget(self.editor_path_edit)
        editor_layout.addWidget(browse_btn)

        self.setting_rows = {
            "font": self._setting_row("界面字体", self.font_family_combo),
            "size": self._setting_row("字体大小", self.font_size_spin),
            "editor": self._setting_row("默认编辑器", editor_control),
        }
        rows_layout = QtWidgets.QVBoxLayout()
        rows_layout.setContentsMargins(0, 0, 0, 0)
        rows_layout.setSpacing(0)
        for row in self.setting_rows.values():
            rows_layout.addWidget(row)
        layout.addLayout(rows_layout)
        layout.addSpacing(24)

        actions = QtWidgets.QHBoxLayout()
        actions.setSpacing(12)
        self.settings_status = QtWidgets.QLabel("")
        self.settings_status.setObjectName("SettingsStatus")
        actions.addWidget(self.settings_status)
        actions.addStretch(1)
        reset_btn = QtWidgets.QPushButton("恢复默认")
        reset_btn.setObjectName("SettingsSecondaryButton")
        reset_btn.setFixedHeight(36)
        reset_btn.clicked.connect(self._reset_settings)
        self.save_settings_btn = QtWidgets.QPushButton("保存设置")
        self.save_settings_btn.setObjectName("SettingsPrimaryButton")
        self.save_settings_btn.setFixedHeight(36)
        self.save_settings_btn.clicked.connect(self._save_settings)
        actions.addWidget(reset_btn)
        actions.addWidget(self.save_settings_btn)
        layout.addLayout(actions)
        layout.addStretch(1)
        return content

    def _build_docs_content(self):
        content, layout = self._content_shell(
            "Getting Started", "从项目配置开始，快速完成 PLM 生成流程。"
        )
        self.doc_browser = QtWidgets.QTextBrowser()
        self.doc_browser.setObjectName("DocumentationBrowser")
        self.doc_browser.setOpenExternalLinks(True)
        self.doc_browser.setSearchPaths([str(DOCS_DIR)])
        self.doc_browser.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        self.doc_browser.document().setDefaultStyleSheet(
            "h1 { color: #1A1A1A; font-size: 16px; font-weight: 600; margin: 16px 0 8px 0; }"
            "h2, h3 { color: #1A1A1A; font-size: 14px; font-weight: 600;"
            " margin: 12px 0 6px 0; }"
            "p { color: #333333; font-size: 13px; line-height: 160%;"
            " margin: 4px 0 10px 0; }"
            "table { border-collapse: collapse; border: 1px solid #EAEAEA;"
            " border-radius: 6px; }"
            "th { background-color: #F0F2F5; color: #1A1A1A; font-size: 13px;"
            " font-weight: 600; padding: 8px 12px; border-bottom: 1px solid #EAEAEA; }"
            "td { color: #333333; font-size: 13px; font-weight: 400;"
            " padding: 8px 12px; }"
        )
        layout.addWidget(self.doc_browser, 1)
        return content

    def _select_section(self, index):
        for button_index, button in enumerate(self.menu_buttons):
            button.setProperty("selected", button_index == index)
            button.style().unpolish(button)
            button.style().polish(button)

        if self.page == "settings":
            titles = ("General", "Appearance", "Tools")
            descriptions = (
                "配置会保存在本机，并在下次启动时自动恢复。",
                "调整整个应用的字体与字号。",
                "设置从 Artifacts 面板打开文件时使用的编辑器。",
            )
            visible_rows = (
                {"font", "size", "editor"},
                {"font", "size"},
                {"editor"},
            )[index]
            self.heading_label.setText(titles[index])
            self.description_label.setText(descriptions[index])
            for name, row in self.setting_rows.items():
                row.setVisible(name in visible_rows)
            return

        docs = (
            (
                "Getting Started",
                "Qt 前端的项目配置、标签页与常用操作。",
                "qt_frontend_guide.md",
                None,
            ),
            (
                "Configuration",
                "Controller、Lane Mapping 与 PIPE Signals 配置格式。",
                "tool_usage.md",
                "## 2. 配置文件格式（`config/` 下三个 CSV）",
            ),
            (
                "Generation",
                "生成 RTL 与 Testbench 的命令、参数和输出规则。",
                "tool_usage.md",
                "## 3. `plm generate`：生成匹配的 RTL 与 testbench",
            ),
        )
        title, description, filename, section = docs[index]
        self.heading_label.setText(title)
        self.description_label.setText(description)
        self._load_document(filename, section)

    @staticmethod
    def _extract_markdown_section(markdown, heading):
        if not heading:
            return markdown
        lines = markdown.splitlines()
        try:
            start = next(i for i, line in enumerate(lines) if line.strip() == heading)
        except StopIteration:
            return markdown
        level = len(heading) - len(heading.lstrip("#"))
        end = len(lines)
        for index in range(start + 1, len(lines)):
            stripped = lines[index].lstrip()
            if not stripped.startswith("#"):
                continue
            next_level = len(stripped) - len(stripped.lstrip("#"))
            if next_level <= level:
                end = index
                break
        return "\n".join(lines[start:end])

    def _load_document(self, filename, section=None):
        path = DOCS_DIR / filename
        try:
            markdown = path.read_text(encoding="utf-8")
        except OSError as error:
            self.doc_browser.setPlainText(f"无法读取文档：{path}\n\n{error}")
            return
        self.doc_browser.setMarkdown(
            self._extract_markdown_section(markdown, section)
        )
        self._format_document()
        self.doc_browser.verticalScrollBar().setValue(0)

    def _format_document(self):
        document = self.doc_browser.document()
        formatted_tables = set()
        block = document.begin()
        while block.isValid():
            cursor = QtGui.QTextCursor(block)
            block_format = block.blockFormat()
            heading_level = block_format.headingLevel()
            if heading_level:
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                heading_format = QtGui.QTextCharFormat()
                heading_format.setForeground(QtGui.QColor("#1A1A1A"))
                heading_format.setFontFamily(self.doc_browser.font().family())
                heading_format.clearProperty(QtGui.QTextFormat.FontSizeAdjustment)
                heading_format.setProperty(
                    QtGui.QTextFormat.FontPixelSize,
                    16 if heading_level == 1 else 14,
                )
                heading_format.setFontWeight(QtGui.QFont.Bold)
                cursor.setCharFormat(heading_format)
                block_format.setTopMargin(16 if heading_level == 1 else 12)
                block_format.setBottomMargin(8 if heading_level == 1 else 6)
                cursor.setBlockFormat(block_format)
            elif cursor.currentTable() is None:
                block_format.setLineHeight(
                    160, QtGui.QTextBlockFormat.ProportionalHeight
                )
                cursor.setBlockFormat(block_format)

            if block.text().strip().startswith("操作："):
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                note_format = QtGui.QTextCharFormat()
                note_format.setForeground(QtGui.QColor("#8C92A4"))
                note_format.setProperty(QtGui.QTextFormat.FontPixelSize, 12)
                cursor.mergeCharFormat(note_format)

            table = cursor.currentTable()
            if table is not None and table.firstPosition() not in formatted_tables:
                formatted_tables.add(table.firstPosition())
                table_format = table.format()
                table_format.setBorder(1)
                table_format.setBorderStyle(QtGui.QTextFrameFormat.BorderStyle_Solid)
                table_format.setBorderBrush(QtGui.QColor("#EAEAEA"))
                table_format.setCellPadding(8)
                table_format.setCellSpacing(0)
                table_format.setWidth(
                    QtGui.QTextLength(QtGui.QTextLength.FixedLength, 600)
                )
                table.setFormat(table_format)
                for column in range(table.columns()):
                    cell = table.cellAt(0, column)
                    cell_format = cell.format()
                    cell_format.setBackground(QtGui.QColor("#F0F2F5"))
                    cell.setFormat(cell_format)
                    cell_cursor = cell.firstCursorPosition()
                    cell_cursor.setPosition(
                        cell.lastCursorPosition().position(),
                        QtGui.QTextCursor.KeepAnchor,
                    )
                    header_format = QtGui.QTextCharFormat()
                    header_format.setForeground(QtGui.QColor("#1A1A1A"))
                    header_format.setProperty(QtGui.QTextFormat.FontPixelSize, 13)
                    header_format.setFontWeight(QtGui.QFont.Bold)
                    cell_cursor.mergeCharFormat(header_format)
            if block_format.property(QtGui.QTextFormat.BlockCodeFence):
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                code_format = QtGui.QTextCharFormat()
                code_format.setFontFamilies(["Consolas", "Courier New", "monospace"])
                code_format.setProperty(QtGui.QTextFormat.FontPixelSize, 13)
                cursor.setCharFormat(code_format)
                block_format.setLineHeight(
                    160, QtGui.QTextBlockFormat.ProportionalHeight
                )
                cursor.setBlockFormat(block_format)
            block = block.next()

    def _browse_editor(self):
        path, _selected_filter = QtWidgets.QFileDialog.getOpenFileName(
            self,
            "选择默认编辑器",
            self.editor_path_edit.text().strip(),
            "Executables (*.exe);;All files (*)",
        )
        if path:
            self.editor_path_edit.setText(path)

    def _preferences(self):
        return {
            "font_family": self.font_family_combo.currentFont().family(),
            "font_size": self.font_size_spin.value(),
            "editor_path": self.editor_path_edit.text().strip() or DEFAULT_EDITOR,
        }

    def _save_settings(self):
        preferences = self._preferences()
        self.settings_store.save_preferences(preferences)
        self.preferencesSaved.emit(preferences)
        self.settings_status.setText("设置已保存")

    def _reset_settings(self):
        self.font_family_combo.setCurrentFont(QtGui.QFont(DEFAULT_FONT_FAMILY))
        self.font_size_spin.setValue(DEFAULT_FONT_SIZE)
        self.editor_path_edit.setText(DEFAULT_EDITOR)
        self._save_settings()

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.closeRequested.emit()
            event.accept()
            return
        super().keyPressEvent(event)

    def resizeEvent(self, event):
        super().resizeEvent(event)


class MainWindow(QtWidgets.QMainWindow):
    """Native QMainWindow containing horizontal and vertical splitters."""

    def __init__(self):
        super().__init__()
        self.settings_store = SettingsStore()
        self._apply_preferences(self._read_preferences())
        self.setWindowTitle("plmConsultant")
        self.resize(1400, 900)
        self.setMinimumSize(960, 640)
        self.setWindowIcon(load_lucide_icon("layout-dashboard", "#1677FF"))
        self._log_sizes = [700, 200]
        self.placeholder_overlay = None

        self.main_splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        self.main_splitter.setObjectName("MainSplitter")
        self.main_splitter.setHandleWidth(4)
        self.main_splitter.setChildrenCollapsible(False)
        self.nav_panel = NavPanel(settings_store=self.settings_store)
        self.main_splitter.addWidget(self.nav_panel)

        self.content_splitter = QtWidgets.QSplitter(QtCore.Qt.Vertical)
        self.content_splitter.setObjectName("ContentSplitter")
        self.content_splitter.setHandleWidth(1)
        self.content_splitter.setChildrenCollapsible(True)
        self.config_page = ConfigPage()
        self.log_panel = LogPanel()
        self.config_page.logToggleRequested.connect(self.toggle_log)
        self.log_panel.closeRequested.connect(self.hide_log)
        self.content_splitter.addWidget(self.config_page)
        self.content_splitter.addWidget(self.log_panel)
        self.main_splitter.addWidget(self.content_splitter)
        self.main_splitter.handle(1).setCursor(QtCore.Qt.SplitHCursor)
        self.main_splitter.setStretchFactor(0, 0)
        self.main_splitter.setStretchFactor(1, 1)
        self.content_splitter.setStretchFactor(0, 3)
        self.content_splitter.setStretchFactor(1, 1)
        self.setCentralWidget(self.main_splitter)

        QtCore.QTimer.singleShot(0, self._apply_initial_sizes)

        self.nav_panel.new_chat_requested.connect(self.on_new_chat)
        self.nav_panel.save_requested.connect(self.on_save)
        self.nav_panel.settings_requested.connect(self.on_open_settings)
        self.nav_panel.docs_requested.connect(self.on_open_docs)
        self.nav_panel.project_selected.connect(self.config_page.update_title)
        self.nav_panel.emit_current_project()

    def _apply_initial_sizes(self):
        main_width = max(261, self.main_splitter.width())
        self.main_splitter.setSizes([260, main_width - 260])
        self.content_splitter.setSizes(self._log_sizes)

    def toggle_log(self):
        sizes = self.content_splitter.sizes()
        total = sum(sizes)
        if sizes[1] > 0:
            self._log_sizes = sizes
            self.content_splitter.setSizes([total, 0])
        else:
            bottom = max(140, int(total * 0.25))
            self.content_splitter.setSizes([max(1, total - bottom), bottom])

    def hide_log(self):
        sizes = self.content_splitter.sizes()
        if sizes[1] <= 0:
            return
        self._log_sizes = sizes
        self.content_splitter.setSizes([sum(sizes), 0])

    def on_new_chat(self):
        self.nav_panel.set_active(None)

    def on_save(self):
        self.nav_panel.set_active(None)
        self.log_panel.append_log("[UI] 当前配置已加入保存队列")

    def on_open_settings(self):
        self.nav_panel.set_active("settings")
        self._show_placeholder("settings")

    def on_open_docs(self):
        self.nav_panel.set_active("docs")
        self._show_placeholder("docs")

    def _show_placeholder(self, page):
        self._close_placeholder()
        self.placeholder_overlay = PlaceholderOverlay(
            page, self, settings_store=self.settings_store
        )
        self.placeholder_overlay.setGeometry(self.rect())
        self.placeholder_overlay.closeRequested.connect(self._close_placeholder)
        self.placeholder_overlay.preferencesSaved.connect(self._apply_preferences)
        self.placeholder_overlay.show()
        self.placeholder_overlay.raise_()
        self.placeholder_overlay.setFocus(QtCore.Qt.OtherFocusReason)

    def _close_placeholder(self):
        if self.placeholder_overlay is None:
            return
        overlay = self.placeholder_overlay
        self.placeholder_overlay = None
        overlay.hide()
        overlay.deleteLater()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self.placeholder_overlay is not None:
            self.placeholder_overlay.setGeometry(self.rect())

    def _read_preferences(self):
        return self.settings_store.preferences()

    def _apply_preferences(self, preferences):
        app = QtWidgets.QApplication.instance()
        if app is None:
            return
        family = preferences.get("font_family") or DEFAULT_FONT_FAMILY
        size = int(preferences.get("font_size") or DEFAULT_FONT_SIZE)
        font = QtGui.QFont(family)
        font.setPixelSize(size)
        font.setStyleStrategy(QtGui.QFont.PreferAntialias)
        app.setFont(font)
        app.setStyleSheet(build_app_stylesheet(family, size))



if __name__ == "__main__":
    if hasattr(QtCore.Qt, "AA_EnableHighDpiScaling"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    if hasattr(QtCore.Qt, "AA_UseHighDpiPixmaps"):
        QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    app = QtWidgets.QApplication(sys.argv)
    app.setStyle("Fusion")
    font = QtGui.QFont()
    font.setFamily("Microsoft YaHei UI")
    font.setStyleStrategy(QtGui.QFont.PreferAntialias)
    font.setHintingPreference(QtGui.QFont.PreferFullHinting)
    app.setFont(font)
    app.setStyleSheet(APP_QSS)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())
