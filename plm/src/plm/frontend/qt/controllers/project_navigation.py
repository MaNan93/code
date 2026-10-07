"""Focused controller actions preserving the AppController interface."""

import os
from pathlib import Path
from PyQt5 import QtWidgets
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.new_project_dialog import NewProjectDialog


class ProjectNavigation:
    """GUI orchestration; filesystem work runs through TaskRunner."""

    def _available_projects(self, discovered=None):
        if discovered is None:
            discovered = self._discovered_projects
        self._discovered_projects = discovered
        self.settings.bind_projects(discovered)
        projects = []
        for project in discovered:
            state = self.settings.get_project_state(project.name)
            if not state.is_archived and not state.is_cleared:
                projects.append(project)
        return sorted(projects, key=lambda p: (
            not self.settings.get_project_state(p.name).is_pinned, p.name.casefold()
        ))

    def create_navigation(self):
        return NavPanel()

    def confirm_switch(self, on_saved=None):
        if (self._generation_running or self._save_running
                or self._project_operation_running or self._load_running):
            self.log_panel.append_log("保存或生成仍在进行，请等待完成后切换或关闭。")
            return False
        self.config_page.finish_editing()
        if not self.current_project or not self.config_page.dirty:
            return True
        answer = QtWidgets.QMessageBox.question(
            self.window, "未保存的修改", "当前项目有未保存的修改，是否先保存？",
            QtWidgets.QMessageBox.Save | QtWidgets.QMessageBox.Discard | QtWidgets.QMessageBox.Cancel,
            QtWidgets.QMessageBox.Save,
        )
        if answer == QtWidgets.QMessageBox.Save:
            self._after_save = on_saved
            self.save_current()
            return False
        return answer != QtWidgets.QMessageBox.Cancel

    def _project_io(self, operation, completed, title):
        if self._project_operation_running:
            return
        self._project_operation_running = True
        self.nav.setEnabled(False)

        def run(_progress):
            value = operation()
            return value, self.projects.discover()

        def finished(result):
            self._project_operation_running = False
            self.nav.setEnabled(True)
            completed(*result)

        def failed(error):
            self._project_operation_running = False
            self.nav.setEnabled(True)
            self.log_panel.append_log(f"{title}：{error}")

        self.tasks.submit(run, finished, failed)

    def _activate_path(self, config_dir, discovered=None):
        if discovered is None:
            self._project_io(lambda: config_dir, self._activate_path, "扫描项目失败")
            return
        project = next((p for p in discovered if p.config_dir == config_dir), None)
        if project is None:
            self.log_panel.append_log(f"项目已不存在或无法读取：{config_dir}")
            return False
        self.settings.bind_projects(discovered)
        state = self.settings.get_project_state(project.name)
        state.is_archived = False
        state.is_cleared = False
        self.settings.save_project_state(state)
        projects = self._available_projects(discovered)
        self.settings.save_project_paths(self.projects.external_dirs)
        self.nav.set_projects(projects, project.name)
        self._load_project(project)

    def open_project(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(
            self.window, "打开 PLM 项目", str(self.current_project.config_dir.parent if self.current_project else Path.home())
        )
        if not path:
            return
        if not self.confirm_switch(
            on_saved=lambda: self._project_io(
                lambda: self.projects.register(path), self._activate_path, "打开项目失败"
            )
        ):
            return
        self._project_io(lambda: self.projects.register(path), self._activate_path, "打开项目失败")

    def new_project(self):
        default = os.path.expanduser("~/plm-projects")
        dialog = NewProjectDialog(default, self.window)
        if dialog.exec_() != QtWidgets.QDialog.Accepted:
            return
        name, location = dialog.values()
        if not location:
            QtWidgets.QMessageBox.warning(self.window, "新建项目失败", "请选择保存位置")
            return
        if not self.confirm_switch(
            on_saved=lambda: self._project_io(
                lambda: self.projects.create(location, name), self._activate_path, "新建项目失败"
            )
        ):
            return
        self._project_io(lambda: self.projects.create(location, name), self._activate_path, "新建项目失败")

    def _project(self, name):
        return next((info for info in self._discovered_projects if info.name == name), None)

    def select_project(self, name):
        if name == self.current_name:
            return
        if not self.confirm_switch(on_saved=lambda: self.select_project(name)):
            self.nav.project_list.select_project(self.current_name)
            return
        project = self._project(name)
        if project is None:
            return
        self._load_project(project)

    def _load_project(self, project):
        name = project.name
        self._load_revision += 1
        revision = self._load_revision
        service = self._worker_service()
        self._load_running = True
        self.nav.setEnabled(False)
        self.config_page.tabs.setEnabled(False)

        def finished(data):
            if revision != self._load_revision:
                return
            self._load_running = False
            self.nav.setEnabled(True)
            self.config_page.tabs.setEnabled(True)
            payload, signature = data
            self.current_name = name
            self.current_project = project
            self._saved_signature = signature
            self.config_page.set_content(payload)
            self.config_page.update_title(name)
            self.settings.set_recent_project(name)
            self.refresh_artifacts()
            self.log_panel.append_log(f"已打开项目：{name}")
            self._update_window_title()

        def failed(error):
            if revision == self._load_revision:
                self._load_running = False
                self.nav.setEnabled(True)
                self.config_page.tabs.setEnabled(True)
                self.log_panel.append_log(f"加载项目失败：{error}")
                self.nav.project_list.select_project(self.current_name, emit_signal=False)

        self.tasks.submit(
            lambda _progress: (service.load(project), service.signature(project)), finished, failed
        )

    def _show_empty_project(self):
        if self.current_project is None:
            self.config_page.set_content({})
            self.config_page.update_title("无项目")
            self.refresh_artifacts()
            self._update_window_title()
