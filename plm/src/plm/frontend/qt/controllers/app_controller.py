"""Compose views, filesystem discovery, and user preferences."""

from PyQt5 import QtGui, QtWidgets

from plm.frontend.qt.models.preferences import DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.core.validation import ValidationError
from plm.frontend.qt.views.documentation_page import DocumentationPage
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import PROJECT_ROOT


class AppController:
    def __init__(self, project_service=None, settings_store=None, workspace_service=None):
        self.projects = project_service or ProjectService(PROJECT_ROOT)
        self.settings = settings_store or SettingsStore()
        self.workspaces = workspace_service or WorkspaceService()
        self.current_name = None
        self.current_project = None

    def create_navigation(self):
        states = self.settings.get_project_states()
        projects = [
            info for info in self.projects.discover()
            if not states.get(info.name) or not states[info.name].is_archived
        ]
        projects.sort(key=lambda info: (not states.get(info.name, None) or not states[info.name].is_pinned, info.name.casefold()))
        return NavPanel(
            projects=projects,
            recent_project=self.settings.recent_project(),
        )

    def connect_navigation(self, nav, config_page, log_panel, window):
        self.nav = nav
        self.config_page = config_page
        self.log_panel = log_panel
        self.window = window
        nav.new_chat_requested.connect(window.on_new_chat)
        nav.save_requested.connect(window.on_save)
        nav.settings_requested.connect(window.on_open_settings)
        nav.docs_requested.connect(window.on_open_docs)
        nav.project_selected.connect(self.select_project)
        nav.project_archived.connect(self.archive_project)
        nav.project_deleted.connect(self.delete_project)
        nav.project_renamed.connect(self.rename_project)
        nav.project_pinned.connect(self.pin_project)
        config_page.generateRequested.connect(self.generate_current)
        config_page.artifacts_panel.refreshRequested.connect(self.refresh_artifacts)
        nav.emit_current_project()
        self._show_empty_project()

    def _project(self, name):
        return next((info for info in self.projects.discover() if info.name == name), None)

    def select_project(self, name):
        if name == self.current_name:
            return
        if self.current_name and self.config_page.dirty:
            answer = QtWidgets.QMessageBox.question(
                self.window, "未保存的修改", "当前项目有未保存的修改，是否先保存？",
                QtWidgets.QMessageBox.Save | QtWidgets.QMessageBox.Discard | QtWidgets.QMessageBox.Cancel,
                QtWidgets.QMessageBox.Save,
            )
            if answer == QtWidgets.QMessageBox.Cancel or (
                answer == QtWidgets.QMessageBox.Save and not self.save_current()
            ):
                self.nav.project_list.select_project(self.current_name)
                return
        project = self._project(name)
        if project is None:
            return
        try:
            payload = self.workspaces.load(project)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "加载项目失败", str(error))
            if self.current_name:
                self.nav.project_list.select_project(self.current_name)
            return
        self.current_name = name
        self.current_project = project
        self.config_page.set_content(payload)
        self.config_page.update_title(name)
        self.settings.set_recent_project(name)
        self.refresh_artifacts()
        self.log_panel.append_log(f"已打开项目：{name}")

    def save_current(self):
        if self.current_project is None:
            return False
        try:
            self.workspaces.save(self.current_project, self.config_page.content())
        except (OSError, ValueError, ValidationError) as error:
            self.log_panel.append_log(f"保存失败：{error}")
            QtWidgets.QMessageBox.warning(self.window, "保存失败", str(error))
            return False
        self.config_page.dirty = False
        self.config_page.dirtyChanged.emit(False)
        self.log_panel.append_log(f"已保存配置：{self.current_name}")
        return True

    def generate_current(self):
        if self.current_project is None:
            return
        try:
            result, files, report = self.workspaces.generate(
                self.current_project, self.config_page.content(),
                progress=lambda phase: self.log_panel.append_log(f"生成：{phase}"),
            )
        except (OSError, ValueError, ValidationError) as error:
            self.log_panel.append_log(f"生成失败：{error}")
            QtWidgets.QMessageBox.warning(self.window, "生成失败", str(error))
            return
        self.config_page.dirty = False
        self.config_page.dirtyChanged.emit(False)
        self.config_page.artifacts_panel.set_files(files, self.current_project.config_dir.parent)
        if report.strip():
            self.log_panel.append_log(report.strip())
        self.log_panel.append_log(
            f"{'生成完成' if result.generated else '输出已是最新'}：{len(files)} 个文件"
        )

    def refresh_artifacts(self):
        if self.current_project is None:
            self.config_page.artifacts_panel.set_files([])
            return
        files = self.workspaces.output_files(self.current_project)
        self.config_page.artifacts_panel.set_files(files, self.current_project.config_dir.parent)

    def archive_project(self, name):
        if self.current_name == name and self.config_page.dirty and not self.save_current():
            return
        state = self.settings.get_project_state(name)
        state.is_archived = True
        self.settings.save_project_state(state)
        self.settings.clear_recent_project(name)
        if self.current_name == name:
            self.current_name = None
            self.current_project = None
        self.nav.apply_remove(name)
        self._show_empty_project()

    def delete_project(self, name):
        try:
            self.projects.delete(name)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "删除失败", str(error))
            return
        self.settings.remove_project_state(name)
        if self.current_name == name:
            self.current_name = None
            self.current_project = None
        self.nav.apply_remove(name)
        self._show_empty_project()

    def _show_empty_project(self):
        if self.nav.project_list.count() == 0:
            self.config_page.set_content({})
            self.config_page.update_title("无项目")
            self.refresh_artifacts()

    def rename_project(self, old_name, new_name):
        try:
            config_dir = self.projects.rename(old_name, new_name)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "重命名失败", str(error))
            return
        state = self.settings.get_project_state(old_name)
        self.settings.remove_project_state(old_name)
        state.name = new_name
        self.settings.save_project_state(state)
        if self.current_name == old_name:
            self.current_name = new_name
            self.current_project = self._project(new_name)
            self.settings.set_recent_project(new_name)
            self.config_page.update_title(new_name)
        self.nav.apply_rename(old_name, new_name, config_dir)

    def pin_project(self, name):
        state = self.settings.get_project_state(name)
        state.is_pinned = True
        self.settings.save_project_state(state)
        self.nav.apply_pin(name)

    def create_secondary_page(self, page, parent):
        if page == "settings":
            return SettingsPage(parent, preferences=self.settings.preferences())
        return DocumentationPage(parent)

    def save_preferences(self, preferences):
        self.settings.save_preferences(preferences)
        self.apply_preferences(preferences)

    def apply_preferences(self, preferences):
        from plm.frontend.qt.styles import build_app_stylesheet

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
