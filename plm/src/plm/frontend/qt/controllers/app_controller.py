"""Compose frontend views and asynchronous controller actions."""

from PyQt5 import QtCore
from plm.core import verible
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.views.documentation_page import DocumentationPage
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import PROJECT_ROOT
from .workspace_actions import WorkspaceActions
from .project_navigation import ProjectNavigation
from .project_actions import ProjectActions


class AppController(WorkspaceActions, ProjectNavigation, ProjectActions):
    def __init__(self, project_service=None, settings_store=None, workspace_service=None):
        self.projects = project_service or ProjectService(PROJECT_ROOT)
        self.settings = settings_store or SettingsStore()
        self.workspaces = workspace_service or WorkspaceService()
        self._detected_verible_path = ""
        if not self.settings.formatter_preferences().get("verible_path"):
            try:
                self._detected_verible_path = verible.find_verible() or ""
            except OSError:
                # Formatter discovery is optional and must never prevent the
                # application from opening.
                pass
        self.workspaces.formatter_provider = self._formatter_preferences
        self.current_name = None
        self.current_project = None
        self._saved_signature = None
        self._generation_failure = None
        self._reload_stale_projects = set()
        self._validation_revision = 0
        self._validation_running = False
        self._generation_running = False
        self._save_running = False
        self._after_save = None
        self._load_revision = 0
        self._load_running = False
        self._project_operation_running = False
        self._initial_project_paths = self.settings.project_paths()
        self._discovered_projects = []

    def connect_navigation(self, nav, config_page, log_panel, window):
        self.nav = nav
        self.config_page = config_page
        self.log_panel = log_panel
        self.window = window
        self.tasks = TaskRunner(window)
        self.validation_timer = QtCore.QTimer(window)
        self.validation_timer.setSingleShot(True)
        self.validation_timer.setInterval(350)
        self.validation_timer.timeout.connect(self.validate_current)
        config_page.historyChanged.connect(self._content_changed)
        config_page.dirtyChanged.connect(self._update_window_title)
        config_page.header.titleChanged.connect(self.rename_current_from_header)
        nav.new_chat_requested.connect(self.new_project)
        nav.open_project_requested.connect(self.open_project)
        nav.save_requested.connect(window.on_save)
        nav.settings_requested.connect(window.on_open_settings)
        nav.docs_requested.connect(window.on_open_docs)
        nav.project_selected.connect(self.select_project)
        nav.project_reload_requested.connect(self.reload_project)
        nav.project_archived.connect(self.archive_project)
        nav.project_deleted.connect(self.delete_project)
        nav.project_renamed.connect(self.rename_project)
        nav.project_pinned.connect(self.pin_project)
        config_page.generateRequested.connect(self.generate_current)
        config_page.artifacts_panel.refreshRequested.connect(self.refresh_artifacts)
        self._show_empty_project()
        self._update_window_title()
        paths = tuple(self._initial_project_paths)
        nav.setEnabled(False)

        def discover(_progress):
            for path in paths:
                try:
                    self.projects.register(path)
                except (OSError, ValueError):
                    continue
            return self.projects.discover()

        def discovered(result):
            nav.setEnabled(True)
            projects = self._available_projects(result)
            recent = next(
                (p.name for p in projects if str(p.config_dir) == self.settings.recent_path()),
                self.settings.recent_project(),
            )
            nav.set_projects(projects, recent or (projects[0].name if projects else ""))
            nav.emit_current_project()

        def failed(error):
            nav.setEnabled(True)
            self.log_panel.append_log(f"扫描项目失败：{error}")

        self.tasks.submit(discover, discovered, failed)

    def _update_window_title(self, *_):
        if not hasattr(self, "window"):
            return
        marker = " *" if self.current_name and self.config_page.dirty else ""
        self.window.setWindowTitle(f"plmConsultant{marker}")
        self.config_page.header.set_path(self.current_project.config_dir.parent if self.current_project else None)

    def _set_output_state(self, state, detail=""):
        labels = {
            "no_project": "请选择项目", "ready": "尚未生成", "invalid": "配置有误",
            "up_to_date": "输出已是最新", "out_of_date": "输出已过期",
            "external_changed": "配置已被外部修改，请重新打开项目", "generating": "生成中…", "failed": "生成失败",
        }
        self.generation_state = state
        text = labels[state]
        self.window.update_log_summary(text)
        self.config_page.generation_editor.set_output_state(state, text, detail)
        self.config_page.artifacts_panel.set_output_state(state, text, detail)

    def create_secondary_page(self, page, parent):
        if page == "settings":
            preferences = self.settings.preferences()
            preferences.update(self._formatter_preferences())
            return SettingsPage(parent, preferences=preferences)
        return DocumentationPage(parent)

    def _formatter_preferences(self):
        preferences = self.settings.formatter_preferences()
        if not preferences.get("verible_path") and self._detected_verible_path:
            preferences = dict(preferences, verible_path=self._detected_verible_path)
        return preferences

    def save_preferences(self, preferences):
        self.settings.save_preferences(preferences)
        self.validate_current()
