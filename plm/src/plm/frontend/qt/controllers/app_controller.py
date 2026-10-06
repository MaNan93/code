"""Compose views, filesystem discovery, and user preferences."""

import hashlib
import os
from pathlib import Path

from PyQt5 import QtCore, QtWidgets

from plm.core.validation import ValidationError, ValidationIssue
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.views.documentation_page import DocumentationPage
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.new_project_dialog import NewProjectDialog
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import PROJECT_ROOT, StyledMenu


class AppController:
    def __init__(self, project_service=None, settings_store=None, workspace_service=None):
        self.projects = project_service or ProjectService(PROJECT_ROOT)
        self.settings = settings_store or SettingsStore()
        self.workspaces = workspace_service or WorkspaceService()
        self.workspaces.formatter_provider = self.settings.formatter_preferences
        self.current_name = None
        self.current_project = None
        self._saved_signature = None
        self._generation_failure = None
        self._checking_external = False
        for path in self.settings.project_paths():
            try:
                self.projects.register(path)
            except (OSError, ValueError):
                continue

    def _available_projects(self):
        discovered = self.projects.discover()
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
        projects = self._available_projects()
        recent = next((p.name for p in projects if str(p.config_dir) == self.settings.recent_path()),
                      self.settings.recent_project())
        return NavPanel(projects=projects, recent_project=recent)

    def connect_navigation(self, nav, config_page, log_panel, window):
        self.nav = nav
        self.config_page = config_page
        self.log_panel = log_panel
        self.window = window
        self.validation_timer = QtCore.QTimer(window)
        self.validation_timer.setSingleShot(True)
        self.validation_timer.setInterval(150)
        self.validation_timer.timeout.connect(self.validate_current)
        config_page.historyChanged.connect(self._content_changed)
        config_page.dirtyChanged.connect(self._update_window_title)
        config_page.header.titleChanged.connect(self.rename_current_from_header)
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
        self._update_window_title()

    def _update_window_title(self, *_):
        if not hasattr(self, "window"):
            return
        marker = " *" if self.current_name and self.config_page.dirty else ""
        self.window.setWindowTitle(f"plmConsultant{marker}")

    def _set_output_state(self, state, detail=""):
        labels = {
            "no_project": "请选择项目", "ready": "尚未生成", "invalid": "配置有误",
            "up_to_date": "输出已是最新", "out_of_date": "输出已过期",
            "external_changed": "请重新加载配置", "generating": "生成中…", "failed": "生成失败",
        }
        self.generation_state = state
        text = labels[state]
        self.config_page.generation_editor.set_output_state(state, text, detail)
        self.config_page.artifacts_panel.set_output_state(state, text, detail)

    def _content_changed(self):
        self._generation_failure = None
        if self.current_project is None:
            self._set_output_state("no_project")
        else:
            has_outputs = bool(self.config_page.artifacts_panel.selection.files)
            self._set_output_state("out_of_date" if has_outputs else "ready", "配置已修改，正在检查生成状态。")
        self.validation_timer.start()

    def validate_current(self):
        if self.current_project is None:
            self.config_page.set_validation_issues(())
            self._set_output_state("no_project")
            return
        plan = None
        try:
            plan = self.workspaces.validate(self.config_page.content())
            issues = ()
        except ValidationError as error:
            issues = error.issues
        except (OSError, ValueError) as error:
            issues = (ValidationIssue("format", str(error)),)
        self.config_page.set_validation_issues(issues)
        try:
            if self.workspaces.signature(self.current_project) != self._saved_signature:
                self._set_output_state("external_changed", "配置已被外部修改。请通过项目菜单重新加载，再保存或生成。")
            elif self._generation_failure:
                self._set_output_state("failed", self._generation_failure)
            elif issues:
                self._set_output_state("invalid", "\n".join(str(issue) for issue in issues))
            else:
                state = self.workspaces.output_state(
                    self.current_project, self.config_page.content(), plan=plan,
                    use_disk=not self.config_page.dirty,
                )
                detail = {
                    "ready": "点击 Generate 生成当前配置对应的 RTL 和 Testbench。",
                    "up_to_date": "输出与当前配置、生成参数及生成器版本一致，文件完整且未被修改。",
                    "out_of_date": "配置或参数已变化，或生成文件缺失、被修改。点击 Generate 更新输出。",
                }[state]
                self._set_output_state(state, detail)
        except (OSError, ValueError) as error:
            self._set_output_state("failed", f"无法检查生成状态：{error}")

    def _show_validation_error(self, error):
        if isinstance(error, ValidationError):
            self.config_page.set_validation_issues(error.issues)
            self.config_page.focus_first_error()

    def show_project_menu(self):
        self.hide_project_menu()
        menu = StyledMenu(self.window)
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

    def confirm_switch(self):
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
        discovered = self.projects.discover()
        project = next((p for p in discovered if p.config_dir == config_dir), None)
        if project is None:
            self.log_panel.append_log(f"项目已不存在或无法读取：{config_dir}")
            return False
        self.settings.bind_projects(discovered)
        state = self.settings.get_project_state(project.name)
        state.is_archived = False
        state.is_cleared = False
        self.settings.save_project_state(state)
        projects = self._available_projects()
        self.settings.save_project_paths(self.projects.external_dirs)
        self.nav.set_projects(projects, project.name)
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
        if not self.confirm_switch():
            self.projects.external_dirs = previous_dirs
            return
        self._activate_path(config_dir)

    def new_project(self):
        default = os.path.expanduser("~/plm-projects")
        dialog = NewProjectDialog(default, self.window)
        if dialog.exec_() != QtWidgets.QDialog.Accepted:
            return
        name, location = dialog.values()
        if not location:
            QtWidgets.QMessageBox.warning(self.window, "新建项目失败", "请选择保存位置")
            return
        if not self.confirm_switch():
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
        if not self.confirm_switch():
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
        self._update_window_title()

    def _check_external_changes(self):
        if self._checking_external:
            return False
        self._checking_external = True
        try:
            return self._check_external_changes_once()
        finally:
            self._checking_external = False

    def _check_external_changes_once(self):
        try:
            if self.workspaces.signature(self.current_project) == self._saved_signature:
                return True
            message = "配置文件已被外部修改。请先重新加载当前项目，再保存或生成。"
        except OSError as error:
            message = f"无法检查配置文件：{error}"
        self._set_output_state("external_changed", message)
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
        self._update_window_title()
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
            self.validate_current()
            self.log_panel.append_log(f"保存失败：{error}")
            if not isinstance(error, ValidationError):
                QtWidgets.QMessageBox.warning(self.window, "保存失败", str(error))
            return False
        self.validate_current()
        self.log_panel.append_log(f"已保存配置：{self.current_name}")
        return True

    def _mark_current_saved(self):
        self._saved_signature = self.workspaces.signature(self.current_project)
        self.config_page.mark_saved()
        self._update_window_title()

    @staticmethod
    def _artifact_signature(files, root):
        root = Path(root).resolve()
        signature = {}
        for value in files:
            path = Path(value).resolve()
            try:
                relative = path.relative_to(root).as_posix()
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
            except (OSError, ValueError):
                continue
            signature[relative] = digest
        return signature

    @staticmethod
    def _artifact_statuses(before, after):
        statuses = {}
        for relative, digest in after.items():
            if relative not in before:
                statuses[relative] = "New"
            elif before[relative] != digest:
                statuses[relative] = "Modified"
            else:
                statuses[relative] = "Unchanged"
        return statuses

    def generate_current(self):
        if self.current_project is None:
            return
        self.config_page.finish_editing()
        if not self._check_external_changes():
            return
        root = self.current_project.config_dir.parent
        before_files = self.workspaces.output_files(self.current_project)
        before = self._artifact_signature(before_files, root)
        self._generation_failure = None
        self._set_output_state("generating", "正在校验、保存并生成 RTL 和 Testbench。")
        self.config_page.generation_editor.status_label.repaint()
        self.config_page.artifacts_panel.status.repaint()
        try:
            result, files, report = self.workspaces.generate(
                self.current_project, self.config_page.content(),
                progress=lambda phase: self.log_panel.append_log(f"生成：{phase}"),
                on_saved=self._mark_current_saved,
            )
        except (OSError, ValueError, ValidationError) as error:
            self._generation_failure = str(error)
            self._show_validation_error(error)
            self.refresh_artifacts()
            self.log_panel.append_log(f"生成失败：{error}")
            QtWidgets.QMessageBox.warning(self.window, "生成失败", str(error))
            return
        after = self._artifact_signature(files, root)
        statuses = self._artifact_statuses(before, after)
        self.config_page.artifacts_panel.set_files(files, root, statuses=statuses)
        self.validate_current()
        if report.strip():
            self.log_panel.append_log(report.strip())
        self.log_panel.append_log(
            f"{'生成完成' if result.generated else '输出已是最新'}：{len(files)} 个文件"
        )

    def refresh_artifacts(self):
        if self.current_project is None:
            self.config_page.artifacts_panel.set_files([])
            self.validate_current()
            return
        files = self.workspaces.output_files(self.current_project)
        self.config_page.artifacts_panel.set_files(files, self.current_project.config_dir.parent)
        self.validate_current()

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
        self._update_window_title()

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
        self._update_window_title()

    def _show_empty_project(self):
        if self.current_project is None:
            self.config_page.set_content({})
            self.config_page.update_title("无项目")
            self.refresh_artifacts()
            self._update_window_title()

    def _refresh_project_names(self):
        projects = self._available_projects()
        # Project rows intentionally store the workspace root because Reveal
        # opens the whole project. Match rows by that root, while controller
        # state continues to use config_dir as its stable identity.
        by_root = {p.config_dir.parent.resolve(): p for p in projects}
        by_config = {p.config_dir.resolve(): p for p in projects}
        self.nav.blockSignals(True)
        try:
            for widget in self.nav.project_list.project_widgets:
                project = by_root.get(Path(widget.project_path).resolve())
                if project and widget.project_name != project.name:
                    self.nav.apply_rename(widget.project_name, project.name, project.config_dir)
        finally:
            self.nav.blockSignals(False)
        if self.current_project:
            current = by_config.get(self.current_project.config_dir.resolve())
            if current is not None:
                self.current_project = current
                self.current_name = current.name
                self.nav.current_project_name = self.current_name
                self.config_page.update_title(self.current_name)
                self.settings.set_recent_project(self.current_name)
                self._update_window_title()

    def rename_current_from_header(self, new_name):
        if not self.current_name:
            self.config_page.update_title("无项目")
            return
        new_name = new_name.strip()
        if not new_name or new_name == self.current_name:
            self.config_page.update_title(self.current_name)
            return
        self.rename_project(self.current_name, new_name)

    def rename_project(self, old_name, new_name):
        state = self.settings.get_project_state(old_name)
        try:
            config_dir = self.projects.rename(old_name, new_name)
        except (OSError, ValueError) as error:
            QtWidgets.QMessageBox.warning(self.window, "重命名失败", str(error))
            if self.current_name == old_name:
                self.config_page.update_title(old_name)
            return
        discovered = self.projects.discover()
        renamed = next((p for p in discovered if p.config_dir == config_dir), None)
        if renamed is None:
            self.log_panel.append_log(f"重命名后的项目无法读取：{config_dir}")
            return
        self.settings.remove_project_state(old_name)
        self.settings.bind_projects(discovered)
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
        self.refresh_artifacts()
        self._update_window_title()

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
        self.validate_current()
