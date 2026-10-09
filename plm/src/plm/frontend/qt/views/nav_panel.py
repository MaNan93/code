"""Left navigation view: actions, project list and footer."""

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    load_lucide_icon,
)
from plm.frontend.qt.widgets.project_list import ProjectList
from plm.frontend.qt.styles.tokens import (
    PRIMARY,
    SPACING_MD,
    SPACING_SM,
    TEXT_SUB,
    NAV_EXPANDED_WIDTH,
    NAV_COLLAPSED_WIDTH,
    PANEL_ANIMATION_DURATION,
)


class NavPanel(QtWidgets.QFrame):
    """Region 3: actions, draggable projects, and footer navigation."""

    new_chat_requested = QtCore.pyqtSignal()
    collapsedChanged = QtCore.pyqtSignal(bool)
    open_project_requested = QtCore.pyqtSignal()
    save_requested = QtCore.pyqtSignal()
    settings_requested = QtCore.pyqtSignal()
    docs_requested = QtCore.pyqtSignal()
    project_archived = QtCore.pyqtSignal(str)
    project_deleted = QtCore.pyqtSignal(str)
    project_renamed = QtCore.pyqtSignal(str, str)
    project_pinned = QtCore.pyqtSignal(str)
    project_selected = QtCore.pyqtSignal(str)
    project_reload_requested = QtCore.pyqtSignal(str)

    def __init__(self, projects=(), recent_project="", parent=None):
        super().__init__(parent)
        self.setObjectName("NavPanel")
        self.expanded_width = NAV_EXPANDED_WIDTH
        self.collapsed_width = NAV_COLLAPSED_WIDTH
        self.is_collapsed = False
        self.is_animating = False
        self._target_collapsed = False
        self.setFixedWidth(self.expanded_width)

        self.animation_min = QtCore.QPropertyAnimation(self, b"minimumWidth", self)
        self.animation_max = QtCore.QPropertyAnimation(self, b"maximumWidth", self)
        for animation in (
            self.animation_min,
            self.animation_max,
        ):
            animation.setDuration(PANEL_ANIMATION_DURATION)
            animation.setEasingCurve(QtCore.QEasingCurve.OutCubic)
        self.animation_group = QtCore.QParallelAnimationGroup(self)
        self.animation_group.addAnimation(self.animation_min)
        self.animation_group.addAnimation(self.animation_max)
        self.animation_group.finished.connect(self._on_collapse_animation_finished)
        root = QtWidgets.QVBoxLayout(self)
        root.setSizeConstraint(QtWidgets.QLayout.SetNoConstraint)
        root.setContentsMargins(SPACING_MD, SPACING_MD, SPACING_MD, SPACING_SM)
        root.setSpacing(0)

        self.new_chat_btn = self._action_button(
            "square-pen", "新建项目", self.new_chat_requested
        )
        self.new_chat_btn.setToolTip("新建项目")
        self.new_chat_btn.setAccessibleName("新建项目")
        self.open_project_btn = self._action_button(
            "folder-open", "打开项目", self.open_project_requested
        )
        self.save_btn = self._action_button("save", "保存", self.save_requested)
        self.new_chat_row, self.new_chat_row_layout = self._nav_row(
            self.new_chat_btn
        )
        self.save_row, self.save_row_layout = self._nav_row(self.save_btn)
        root.addWidget(self.new_chat_row)
        self.open_project_row, self.open_project_row_layout = self._nav_row(
            self.open_project_btn
        )
        root.addWidget(self.open_project_row)
        root.addWidget(self.save_row)
        root.addSpacing(SPACING_MD)

        self.project_separator = QtWidgets.QFrame()
        self.project_separator.setObjectName("ProjectSectionSeparator")
        self.project_separator.setFixedHeight(1)
        root.addWidget(self.project_separator)
        root.addSpacing(SPACING_SM)
        config_projects = tuple(projects)
        self.project_list = ProjectList(config_projects)
        self.project_list.projectArchived.connect(self._project_archived)
        self.project_list.projectDeleted.connect(self._project_deleted)
        self.project_list.projectRenamed.connect(self._project_renamed)
        self.project_list.projectPinned.connect(self.project_pinned.emit)
        self.project_list.projectSelected.connect(self._project_selected)
        self.project_list.projectReloadRequested.connect(self.project_reload_requested.emit)
        root.addWidget(self.project_list, 1)

        self.current_project_name = self.project_list.select_project(
            recent_project or (config_projects[0].name if config_projects else ""),
            emit_signal=False,
        )

        self.collapsed_projects = QtWidgets.QWidget()
        # Fill the project-list space while collapsed, keeping the footer below.
        collapsed_projects_layout = QtWidgets.QVBoxLayout(self.collapsed_projects)
        collapsed_projects_layout.setContentsMargins(0, 0, 0, 0)
        collapsed_projects_layout.setSpacing(0)
        collapsed_projects_layout.setAlignment(
            QtCore.Qt.AlignTop | QtCore.Qt.AlignHCenter
        )
        collapsed_projects_layout.addStretch(1)
        self.collapsed_projects.hide()
        root.addWidget(self.collapsed_projects, 1)

        self.footer_separator = QtWidgets.QFrame()
        self.footer_separator.setObjectName("ProjectSectionSeparator")
        self.footer_separator.setFixedHeight(1)
        root.addWidget(self.footer_separator)
        root.addSpacing(SPACING_SM)

        self.footer = QtWidgets.QWidget()
        footer_layout = QtWidgets.QVBoxLayout(self.footer)
        footer_layout.setContentsMargins(0, 0, 0, 0)
        footer_layout.setSpacing(0)
        self.docs_btn = self._footer_button(
            "file-text", "文档", self.docs_requested
        )
        self.settings_btn = self._footer_button(
            "settings", "设置", self.settings_requested
        )
        self.settings_row, self.settings_row_layout = self._nav_row(
            self.settings_btn
        )
        self.docs_row, self.docs_row_layout = self._nav_row(self.docs_btn)
        footer_layout.addWidget(self.settings_row)
        footer_layout.addWidget(self.docs_row)
        root.addWidget(self.footer)

        for button in (
            self.new_chat_btn, self.open_project_btn, self.save_btn,
            self.settings_btn, self.docs_btn,
        ):
            button.setMinimumWidth(0)
            button.setMaximumWidth(QtWidgets.QWIDGETSIZE_MAX)
            button.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Fixed)

    def toggle_collapse(self):
        if self.is_animating:
            return

        self._target_collapsed = not self.is_collapsed
        start_width = self.width()
        end_width = (
            self.collapsed_width if self._target_collapsed else self.expanded_width
        )
        if self._target_collapsed:
            # Remove text before the width animation so it cannot be squeezed
            # or wrapped while the panel is shrinking.
            self._set_expanded_content_visible(False)

        self.is_animating = True
        for animation in (self.animation_min, self.animation_max):
            animation.setStartValue(start_width)
            animation.setEndValue(end_width)
        self.animation_group.start()

    def _on_collapse_animation_finished(self):
        self.is_collapsed = self._target_collapsed
        self.setFixedWidth(self.collapsed_width if self.is_collapsed else self.expanded_width)
        if not self.is_collapsed:
            # Restore expanded content only after the panel has enough room.
            self._set_expanded_content_visible(True)
        self.is_animating = False
        self.collapsedChanged.emit(self.is_collapsed)

    def _set_expanded_content_visible(self, visible):
        self.setProperty("collapsed", not visible)
        self.style().unpolish(self)
        self.style().polish(self)
        layout = self.layout()
        if layout is not None:
            layout.activate()

        self.new_chat_btn.setText("新建项目" if visible else "")
        self.open_project_btn.setText("打开项目" if visible else "")
        self.save_btn.setText("保存" if visible else "")
        self.settings_btn.setText("设置" if visible else "")
        self.docs_btn.setText("文档" if visible else "")

        self.project_list.setVisible(visible)
        self.collapsed_projects.setVisible(not visible)

    @staticmethod
    def _nav_row(widget):
        row = QtWidgets.QWidget()
        row.setObjectName("NavRow")
        layout = QtWidgets.QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(widget)
        return row, layout

    def _action_button(self, icon_name, text, requested_signal):
        button = QtWidgets.QPushButton(text)
        button.setToolTip(text)
        button.setObjectName("NavActionButton")
        button.setFocusPolicy(QtCore.Qt.StrongFocus)
        button.setIcon(load_lucide_icon(icon_name, align_visible_left=True))
        button.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        button.setCursor(QtCore.Qt.PointingHandCursor)
        button.clicked.connect(
            lambda _checked=False: requested_signal.emit()
        )
        return button

    def _footer_button(self, icon_name, text, requested_signal):
        button = QtWidgets.QPushButton(text)
        button.setToolTip(text)
        button.setObjectName("NavFooterButton")
        button.setFocusPolicy(QtCore.Qt.StrongFocus)
        button.setIcon(load_lucide_icon(icon_name, align_visible_left=True))
        button.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        button.setCursor(QtCore.Qt.PointingHandCursor)
        button.clicked.connect(
            lambda _checked=False: requested_signal.emit()
        )
        return button

    def _project_archived(self, project_name):
        self.project_archived.emit(project_name)

    def _project_deleted(self, project_name):
        self.project_deleted.emit(project_name)

    def _project_renamed(self, old_name, new_name):
        self.project_renamed.emit(old_name, new_name)

    def apply_rename(self, old_name, new_name, config_dir):
        self.project_list.apply_rename(old_name, new_name, config_dir)

    def apply_remove(self, name):
        self.project_list.apply_remove(name)
        self.current_project_name = self.project_list.selected_project_name

    def set_projects(self, projects, selected_name):
        old = self.project_list
        self.project_list = ProjectList(projects)
        self.project_list.projectArchived.connect(self._project_archived)
        self.project_list.projectDeleted.connect(self._project_deleted)
        self.project_list.projectRenamed.connect(self._project_renamed)
        self.project_list.projectPinned.connect(self.project_pinned.emit)
        self.project_list.projectSelected.connect(self._project_selected)
        self.project_list.projectReloadRequested.connect(self.project_reload_requested.emit)
        self.layout().replaceWidget(old, self.project_list)
        self.layout().setStretch(self.layout().indexOf(self.project_list), 1)
        old.hide()
        old.deleteLater()
        self.project_list.setVisible(not self.is_collapsed)
        self.current_project_name = self.project_list.select_project(selected_name, emit_signal=False)

    def apply_pin(self, name):
        self.project_list.apply_pin(name)

    def _project_selected(self, project_name):
        self.current_project_name = project_name
        self.project_selected.emit(project_name)

    def emit_current_project(self):
        if self.current_project_name:
            self.project_selected.emit(self.current_project_name)

    def set_active(self, name):
        for button, value in ((self.docs_btn, "docs"), (self.settings_btn, "settings")):
            selected = name == value
            button.setProperty("selected", selected)
            color = PRIMARY if selected else TEXT_SUB
            icon_name = "file-text" if value == "docs" else "settings"
            button.setIcon(
                load_lucide_icon(icon_name, color, align_visible_left=True)
            )
            button.style().unpolish(button)
            button.style().polish(button)
