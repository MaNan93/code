"""Left navigation view: actions, project list and footer."""

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.widgets.common import (
    ICON_SIZE,
    load_lucide_icon,
    make_icon_button,
)
from plm.frontend.qt.widgets.project_list import ProjectList
from plm.frontend.qt.styles.tokens import PRIMARY, SPACING_MD, SPACING_SM, TEXT_SUB


class NavPanel(QtWidgets.QFrame):
    """Region 3: actions, draggable projects, and footer navigation."""

    new_chat_requested = QtCore.pyqtSignal()
    save_requested = QtCore.pyqtSignal()
    settings_requested = QtCore.pyqtSignal()
    docs_requested = QtCore.pyqtSignal()
    project_archived = QtCore.pyqtSignal(str)
    project_deleted = QtCore.pyqtSignal(str)
    project_renamed = QtCore.pyqtSignal(str, str)
    project_pinned = QtCore.pyqtSignal(str)
    project_selected = QtCore.pyqtSignal(str)

    def __init__(self, projects=(), recent_project="", parent=None):
        super().__init__(parent)
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
        root.setContentsMargins(SPACING_MD, SPACING_SM, SPACING_MD, SPACING_SM)
        root.setSpacing(SPACING_SM)

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
                "layout-dashboard", PRIMARY, 18, align_visible_left=True
            ).pixmap(18, 18)
        )
        self.logo_label.setFixedSize(18, 18)
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
        config_projects = tuple(projects)
        self.project_list = ProjectList(config_projects)
        self.project_list.projectArchived.connect(self._project_archived)
        self.project_list.projectDeleted.connect(self._project_deleted)
        self.project_list.projectRenamed.connect(self._project_renamed)
        self.project_list.projectPinned.connect(self.project_pinned.emit)
        self.project_list.projectSelected.connect(self._project_selected)
        root.addWidget(self.project_list, 1)

        self.current_project_name = self.project_list.select_project(
            recent_project or (config_projects[0].name if config_projects else ""),
            emit_signal=False,
        )

        self.collapsed_projects = QtWidgets.QWidget()
        collapsed_projects_layout = QtWidgets.QVBoxLayout(self.collapsed_projects)
        self.collapsed_projects_layout = collapsed_projects_layout
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
            button.hide()
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
        if self._target_collapsed:
            self.expanded_width = start_width
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
                TEXT_SUB,
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
        # invalidate() only schedules a relayout. On Windows/offscreen the
        # animation can finish before that pass runs, leaving the collapse
        # button at its expanded x-position for a frame. Apply the geometry
        # synchronously so every collapsed icon shares the same center.
        self.brand_layout.activate()
        layout = self.layout()
        if layout is not None:
            layout.activate()

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
        row.setObjectName("NavRow")
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
        self.project_archived.emit(project_name)

    def _project_deleted(self, project_name):
        self.project_deleted.emit(project_name)

    def _project_renamed(self, old_name, new_name):
        self.project_renamed.emit(old_name, new_name)

    def apply_rename(self, old_name, new_name, config_dir):
        self.project_list.apply_rename(old_name, new_name, config_dir)
        for button in self.collapsed_project_buttons:
            if button.toolTip() == old_name:
                button.setToolTip(new_name)
                break

    def apply_remove(self, name):
        self.project_list.apply_remove(name)
        self._remove_collapsed_project(name)
        self.current_project_name = self.project_list.selected_project_name

    def set_projects(self, projects, selected_name):
        old = self.project_list
        self.project_list = ProjectList(projects)
        self.project_list.projectArchived.connect(self._project_archived)
        self.project_list.projectDeleted.connect(self._project_deleted)
        self.project_list.projectRenamed.connect(self._project_renamed)
        self.project_list.projectPinned.connect(self.project_pinned.emit)
        self.project_list.projectSelected.connect(self._project_selected)
        self.layout().replaceWidget(old, self.project_list)
        self.layout().setStretch(self.layout().indexOf(self.project_list), 1)
        old.hide()
        old.deleteLater()
        self.project_list.setVisible(not self.is_collapsed)
        self.current_project_name = self.project_list.select_project(selected_name, emit_signal=False)
        for button in tuple(self.collapsed_project_buttons):
            self._remove_collapsed_project(button.toolTip())
        for project in projects:
            button = self._collapsed_icon_button(
                "folder", project.name,
                lambda _checked=False, value=project.name: self.project_list.select_project(value),
            )
            self.collapsed_projects_layout.insertWidget(
                len(self.collapsed_project_buttons), button, 0, QtCore.Qt.AlignHCenter
            )
            self.collapsed_project_buttons.append(button)
            button.hide()

    def apply_pin(self, name):
        self.project_list.apply_pin(name)
        for button in self.collapsed_project_buttons:
            if button.toolTip() == name:
                self.collapsed_project_buttons.remove(button)
                self.collapsed_project_buttons.insert(0, button)
                self.collapsed_projects_layout.removeWidget(button)
                self.collapsed_projects_layout.insertWidget(0, button)
                break

    def _project_selected(self, project_name):
        self.current_project_name = project_name
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
            color = PRIMARY if selected else TEXT_SUB
            icon_name = "file-text" if value == "docs" else "settings"
            button.setIcon(
                load_lucide_icon(icon_name, color, align_visible_left=True)
            )
            button.style().unpolish(button)
            button.style().polish(button)
        self.collapsed_docs_btn.setIcon(
            load_lucide_icon("file-text", PRIMARY if name == "docs" else TEXT_SUB)
        )
        self.collapsed_settings_btn.setIcon(
            load_lucide_icon(
                "settings", PRIMARY if name == "settings" else TEXT_SUB
            )
        )
