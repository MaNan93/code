"""Compose views, filesystem discovery, and user preferences."""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.models.preferences import DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.core.validation import ValidationError, ValidationIssue
from plm.frontend.qt.views.documentation_page import DocumentationPage
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import PROJECT_ROOT
from plm.frontend.qt.views.new_project_dialog import NewProjectDialog
from pathlib import Path


class AppController:
    def __init__(self, project_service=None, settings_store=None, workspace_service=None):
        self.projects = project_service or ProjectService(PROJECT_ROOT)
        self.settings = settings_store or SettingsStore()
        self.workspaces = workspace_service or WorkspaceService()
        self.current_name = None
        self.current_project = None
        self._saved_signature = None
        for path in self.settings.project_paths():
            try:
                self.projects.register(path)
            except (OSError, ValueError):
                continue

    def _available_projects(self):
        discovered = self.projects.discover()
        self.settings.bind_projects(discovered)
        projects = [p for p in discovered if not self.settings.get_project_state(p.name).is_archived]
        return sorted(projects, key=lambda p: (
            not self.settings.get_project_state(p.name).is_pinned, p.name.casefold()
        ))

    def create_navigation(self):
        projects = self._available_projects()
        recent = next((p.name for p in projects if str(p.config_dir) == self.settings.recent_path()),
                      self.settings.recent_project())
        return NavPanel(
            projects=projects,
            recent_project=recent,
        )

    def connect_navigation(self, nav, config_page, log_panel, window):
        self.nav = nav
        self.config_page = config_page
        self.log_panel = log_panel
        self.window = window
        self.validation_timer = QtCore.QTimer(window)
        self.validation_timer.setSingleShot(True)
        self.validation_timer.setInterval(150)
        self.validation_timer.timeout.connect(self.validate_current)
        config_page.historyChanged.connect(self.validation_timer.start)
        nav.new_chat_requested.connect(self.show_project_menu)
        nav.new_chat_btn.setToolTip("新建或打开 PLM 项目")
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

    def validate_current(self):
        if self.current_project is None:
            self.config_page.set_validation_issues(())
            return
        try:
            self.workspaces.validate(self.config_page.content())
            issues = ()
        except ValidationError as error:
            issues = error.issues
        except (OSError, ValueError) as error:
            issues = (ValidationIssue("format", str(error)),)
        self.config_page.set_validation_issues(issues)

    def _show_validation_error(self, error):
        if isinstance(error, ValidationError):
            self.config_page.set_validation_issues(error.issues)
            self.config_page.focus_first_error()

    def show_project_menu(self):
        self.hide_project_menu()
        menu = QtWidgets.QMenu(self.window)
        self.project_menu = menu
        menu.addAction("新建项目", self.new_project)
        menu.addAction("打开项目…", self.open_project)
        menu.addSeparator()
        reload_action = menu.addAction("重新加载当前项目", self.reload_current)
        reload_action.setEnabled(self.current_project is not None)
        button = self.nav.new_chat_btn
        menu.popup(button.mapToGlobal(button.rect().bottomLeft()))

    def hide_project_menu(self):
        menu = getattr(self, "project_menu", None)
        if menu is not None:
            menu.close()
            menu.deleteLater()
            self.project_menu = None

    def _confirm_switch(self):
        self.config_page.finish_editing()
        if not self.current_project or not self.config_page.dirty:
            return True
        answer = QtWidgets.QMessageBox.question(
            self.window, "未保存的修改", "当前项目有未保存的修改，是否先保存？",
            QtWidgets.QMessageBox.Save | QtWidgets.QMessageBox.Discard | QtWidgets.QMessageBox.Cancel,
            QtWidgets.QMessageBox.Save,
        )
        return answer != QtWidgets.QMessageBox.Cancel and (
            answer != QtWidgets.QMessageBox.Save or self.save_current()
        )

    def _activate_path(self, config_dir):
        projects = self._available_projects()
        project = next(p for p in self.projects.discover() if p.config_dir == config_dir)
        state = self.settings.get_project_state(project.name)
        state.is_archived = False
        self.settings.save_project_state(state)
        projects = self._available_projects()
        self.settings.save_project_paths(self.projects.external_dirs)
        self.nav.set_projects(projects, project.name)
        # The caller has already resolved unsaved edits before changing the list.
        self.current_name = None
        self.select_project(project.name)

    def open_project(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(
            self.window, "打开 PLM 项目", str(self.current_project.config_dir.parent if self.current_project else Path.home())
        )
        if not path:
            return
        try:
            previous_dirs = set(self.projects.external_dirs)
            config_dir = self.projects.register(path)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "打开项目失败", str(error))
            return
        if not self._confirm_switch():
            self.projects.external_dirs = previous_dirs
            return
        self._activate_path(config_dir)

    def new_project(self):
        default = self.current_project.config_dir.parent.parent if self.current_project else Path.home()
        dialog = NewProjectDialog(default, self.window)
        if dialog.exec_() != QtWidgets.QDialog.Accepted:
            return
        name, location = dialog.values()
        if not location:
            QtWidgets.QMessageBox.warning(self.window, "新建项目失败", "请选择保存位置")
            return
        if not self._confirm_switch():
            return
        try:
            config_dir = self.projects.create(location, name)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "新建项目失败", str(error))
            return
        self._activate_path(config_dir)

    def _project(self, name):
        return next((info for info in self.projects.discover() if info.name == name), None)

    def select_project(self, name):
        if name == self.current_name:
            return
        if not self._confirm_switch():
            self.nav.project_list.select_project(self.current_name)
            return
        project = self._project(name)
        if project is None:
            return
        try:
            payload = self.workspaces.load(project)
            signature = self.workspaces.signature(project)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "加载项目失败", str(error))
            if self.current_name:
                self.nav.project_list.select_project(self.current_name)
            return
        self.current_name = name
        self.current_project = project
        self._saved_signature = signature
        self.config_page.set_content(payload)
        self.config_page.update_title(name)
        self.settings.set_recent_project(name)
        self.refresh_artifacts()
        self.log_panel.append_log(f"已打开项目：{name}")

    def _check_external_changes(self):
        try:
            if self.workspaces.signature(self.current_project) == self._saved_signature:
                return True
            message = "配置文件已被外部修改。请先重新加载当前项目，再保存或生成。"
        except OSError as error:
            message = f"无法检查配置文件：{error}"
        self.log_panel.append_log(message)
        QtWidgets.QMessageBox.warning(self.window, "配置文件发生变化", message)
        return False

    def reload_current(self):
        if self.current_project is None:
            return False
        self.config_page.finish_editing()
        if self.config_page.dirty:
            answer = QtWidgets.QMessageBox.question(
                self.window, "重新加载项目", "重新加载会丢弃未保存的修改，是否继续？",
                QtWidgets.QMessageBox.Discard | QtWidgets.QMessageBox.Cancel,
                QtWidgets.QMessageBox.Cancel,
            )
            if answer != QtWidgets.QMessageBox.Discard:
                return False
        try:
            payload = self.workspaces.load(self.current_project)
            signature = self.workspaces.signature(self.current_project)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "重新加载失败", str(error))
            return False
        self.config_page.set_content(payload)
        self._saved_signature = signature
        self.refresh_artifacts()
        self.log_panel.append_log(f"已重新加载项目：{self.current_name}")
        return True

    def save_current(self):
        if self.current_project is None:
            return False
        self.config_page.finish_editing()
        if not self._check_external_changes():
            return False
        try:
            self.workspaces.save(self.current_project, self.config_page.content())
            self._mark_current_saved()
        except (OSError, ValueError, ValidationError) as error:
            self._show_validation_error(error)
            self.log_panel.append_log(f"保存失败：{error}")
            QtWidgets.QMessageBox.warning(self.window, "保存失败", str(error))
            return False
        self.log_panel.append_log(f"已保存配置：{self.current_name}")
        return True

    def _mark_current_saved(self):
        self._saved_signature = self.workspaces.signature(self.current_project)
        self.config_page.mark_saved()

    def generate_current(self):
        if self.current_project is None:
            return
        self.config_page.finish_editing()
        if not self._check_external_changes():
            return
        try:
            result, files, report = self.workspaces.generate(
                self.current_project, self.config_page.content(),
                progress=lambda phase: self.log_panel.append_log(f"生成：{phase}"),
                on_saved=self._mark_current_saved,
            )
        except (OSError, ValueError, ValidationError) as error:
            self._show_validation_error(error)
            self.log_panel.append_log(f"生成失败：{error}")
            QtWidgets.QMessageBox.warning(self.window, "生成失败", str(error))
            return
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
        self.config_page.finish_editing()
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
        preferred = self.current_project.config_dir if self.current_project and self.current_name != name else None
        try:
            self.projects.delete(name)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "删除失败", str(error))
            return
        self.settings.remove_project_state(name)
        self.settings.save_project_paths(self.projects.external_dirs)
        projects = self._available_projects()
        target = next((p for p in projects if p.config_dir == preferred), None)
        self.nav.set_projects(projects, target.name if target else "")
        if target:
            self.current_project = target
            self.current_name = target.name
            self.config_page.update_title(target.name)
            self.settings.set_recent_project(target.name)
        else:
            self.current_name = None
            self.current_project = None
            self.nav.emit_current_project()
        self._show_empty_project()

    def _show_empty_project(self):
        if self.nav.project_list.count() == 0:
            self.config_page.set_content({})
            self.config_page.update_title("无项目")
            self.refresh_artifacts()

    def _refresh_project_names(self):
        # Names may change when a duplicate is introduced, renamed or removed.
        projects = self._available_projects()
        by_path = {p.config_dir: p for p in projects}
        self.nav.blockSignals(True)
        try:
            for widget in self.nav.project_list.project_widgets:
                project = by_path.get(widget.project_path)
                if project and widget.project_name != project.name:
                    self.nav.apply_rename(widget.project_name, project.name, project.config_dir)
        finally:
            self.nav.blockSignals(False)
        if self.current_project and self.current_project.config_dir in by_path:
            self.current_project = by_path[self.current_project.config_dir]
            self.current_name = self.current_project.name
            self.nav.current_project_name = self.current_name
            self.config_page.update_title(self.current_name)
            self.settings.set_recent_project(self.current_name)

    def rename_project(self, old_name, new_name):
        state = self.settings.get_project_state(old_name)
        try:
            config_dir = self.projects.rename(old_name, new_name)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "重命名失败", str(error))
            return
        self.settings.remove_project_state(old_name)
        discovered = self.projects.discover()
        self.settings.bind_projects(discovered)
        renamed = next(p for p in discovered if p.config_dir == config_dir)
        state.name = renamed.name
        self.settings.save_project_state(state)
        self.settings.save_project_paths(self.projects.external_dirs)
        if self.current_name == old_name:
            self.current_name = renamed.name
            self.current_project = renamed
            self.settings.set_recent_project(renamed.name)
            self.config_page.update_title(renamed.name)
        self.nav.apply_rename(old_name, renamed.name, config_dir)
        self._refresh_project_names()

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
