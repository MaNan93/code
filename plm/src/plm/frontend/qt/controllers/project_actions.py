"""Focused controller actions preserving the AppController interface."""

from pathlib import Path


class ProjectActions:
    """GUI orchestration; filesystem work runs through TaskRunner."""

    def archive_project(self, name):
        if (self._generation_running or self._save_running
                or self._load_running or self._project_operation_running):
            return
        self.config_page.finish_editing()
        if self.current_name == name and self.config_page.dirty:
            self._after_save = lambda: self.archive_project(name)
            self.save_current()
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
        if (self._generation_running or self._save_running
                or self._load_running or self._project_operation_running):
            return
        self._project_io(
            lambda: self.projects.delete(name),
            lambda _result, discovered: self._finish_delete(name, preferred, discovered),
            "删除失败",
        )

    def _finish_delete(self, name, preferred, discovered):
        self.settings.remove_project_state(name)
        self.settings.save_project_paths(self.projects.external_dirs)
        projects = self._available_projects(discovered)
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

    def _refresh_project_names(self, discovered):
        projects = self._available_projects(discovered)
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
        if (self._generation_running or self._save_running
                or self._load_running or self._project_operation_running):
            return
        state = self.settings.get_project_state(old_name)
        self._project_io(
            lambda: self.projects.rename(old_name, new_name),
            lambda config_dir, discovered: self._finish_rename(old_name, state, config_dir, discovered),
            "重命名失败",
        )

    def _finish_rename(self, old_name, state, config_dir, discovered):
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
        self._refresh_project_names(discovered)
        self.refresh_artifacts()
        self._update_window_title()

    def pin_project(self, name):
        state = self.settings.get_project_state(name)
        state.is_pinned = True
        self.settings.save_project_state(state)
        self.nav.apply_pin(name)
