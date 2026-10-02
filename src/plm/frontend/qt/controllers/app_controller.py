"""Compose views, filesystem discovery, and user preferences."""

from PyQt5 import QtGui, QtWidgets

from plm.frontend.qt.models.preferences import DEFAULT_FONT_FAMILY, DEFAULT_FONT_SIZE
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.views.documentation_page import DocumentationPage
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.views.settings_page import SettingsPage
from plm.frontend.qt.widgets.common import PROJECT_ROOT


class AppController:
    def __init__(self, project_service=None, settings_store=None):
        self.projects = project_service or ProjectService(PROJECT_ROOT)
        self.settings = settings_store or SettingsStore()

    def create_navigation(self):
        return NavPanel(
            projects=self.projects.discover(),
            recent_project=self.settings.recent_project(),
        )

    def connect_navigation(self, nav, config_page, log_panel, window):
        nav.new_chat_requested.connect(window.on_new_chat)
        nav.save_requested.connect(window.on_save)
        nav.settings_requested.connect(window.on_open_settings)
        nav.docs_requested.connect(window.on_open_docs)
        nav.project_selected.connect(config_page.update_title)
        nav.emit_current_project()
        nav.project_selected.connect(self.settings.set_recent_project)

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
