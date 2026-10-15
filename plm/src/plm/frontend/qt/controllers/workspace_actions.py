"""Focused controller actions preserving the AppController interface."""

import hashlib
from copy import copy
from pathlib import Path
from plm.core.validation import ValidationError, ValidationIssue


# Mirrors the artifact drawer's preview cap: a diff baseline only has to
# cover what the drawer can render.
MAX_BASELINE_BYTES = 200 * 1024


class SavedGenerationError(Exception):
    """Keep the successful save checkpoint when later generation fails."""

    def __init__(self, error, signature):
        super().__init__(str(error))
        self.error = error
        self.signature = signature


class WorkspaceActions:
    """GUI orchestration; filesystem work runs through TaskRunner."""

    def _content_changed(self):
        self._validation_revision += 1
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
        if (self._validation_running or self._generation_running or self._save_running
                or self._load_running or self._project_operation_running):
            self.validation_timer.start()
            return
        # This check consumes the pending edit debounce for the same snapshot.
        self.validation_timer.stop()
        project = self.current_project
        payload = self.config_page.content()
        revision = self._validation_revision
        saved_signature = self._saved_signature
        use_disk = not self.config_page.dirty
        # [REFACTORED]: Snapshot QSettings on the GUI thread, never in a worker.
        service = self._worker_service()
        self._validation_running = True

        def check(_progress):
            try:
                plan = service.validate(payload)
                issues = ()
            except ValidationError as error:
                plan, issues = None, error.issues
            except (OSError, ValueError) as error:
                plan, issues = None, (ValidationIssue("format", str(error)),)
            if service.signature(project) != saved_signature:
                return issues, "external_changed"
            if issues:
                return issues, "invalid"
            return issues, service.output_state(project, payload, plan=plan, use_disk=use_disk)

        def finished(result):
            self._validation_running = False
            if project != self.current_project or revision != self._validation_revision:
                self.validation_timer.start()
                return
            if self._generation_running:
                return
            issues, state = result
            if state == "up_to_date" and project.config_dir in self._reload_stale_projects:
                state = "out_of_date"
            self.config_page.set_validation_issues(issues)
            if self._generation_failure:
                self._set_output_state("failed", self._generation_failure)
            else:
                self._set_output_state(state, "\n".join(map(str, issues)))

        def failed(error):
            self._validation_running = False
            if project == self.current_project and revision == self._validation_revision:
                self._set_output_state("failed", f"无法检查生成状态：{error}")

        self.tasks.submit(check, finished, failed)

    def _worker_service(self):
        preferences = self.settings.formatter_preferences()
        service = copy(self.workspaces)
        service.formatter_provider = lambda: preferences
        return service

    def _show_validation_error(self, error):
        if isinstance(error, ValidationError):
            self.config_page.set_validation_issues(error.issues)
            self.config_page.focus_first_error()

    def save_current(self):
        if (self.current_project is None or self._save_running or self._generation_running
                or self._load_running or self._project_operation_running):
            return False
        self.config_page.finish_editing()
        project = self.current_project
        payload = self.config_page.content()
        saved = self._saved_signature
        service = self._worker_service()
        self._save_running = True
        self._validation_revision += 1

        def save(_progress):
            if service.signature(project) != saved:
                raise ValueError("配置文件已被外部修改，请通过“打开项目”重新打开。")
            service.save(project, payload)
            return service.signature(project)

        def failed(error):
            self._save_running = False
            self._after_save = None
            self._show_validation_error(error)
            self.validate_current()
            self.log_panel.append_log(f"保存失败：{error}")

        def finished(signature):
            self._save_running = False
            continuation, self._after_save = self._after_save, None
            if project != self.current_project:
                return
            self._saved_signature = signature
            self._validation_revision += 1
            self.config_page.mark_saved(payload)
            self.validate_current()
            self.log_panel.append_log(f"已保存配置：{self.current_name}")
            self.window.show_toast("✓ 配置已保存", "success")
            if continuation and not self.config_page.dirty:
                continuation()

        self.tasks.submit(save, finished, failed)
        # Pending persistence cannot authorize a destructive project switch.
        return False

    @staticmethod
    def _artifact_snapshot(files, root, texts=True):
        """Digests of artifact files under root, plus their contents.

        The pre-generation call captures contents as well: the generator is
        about to overwrite those files, and the drawer needs that text as its
        diff baseline. Without it, only files the user happened to preview
        would have anything to compare against.
        """
        root = Path(root).resolve()
        signature = {}
        baseline = {}
        for value in files:
            path = Path(value).resolve()
            try:
                relative = path.relative_to(root).as_posix()
                hasher = hashlib.sha256()
                captured = bytearray()
                with path.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(65536), b""):
                        hasher.update(chunk)
                        if texts and len(captured) <= MAX_BASELINE_BYTES:
                            captured.extend(chunk)
            except (OSError, ValueError):
                continue
            signature[relative] = hasher.hexdigest()
            if texts and len(captured) <= MAX_BASELINE_BYTES:
                try:
                    baseline[relative] = bytes(captured).decode("utf-8")
                except UnicodeDecodeError:
                    pass
        return signature, baseline

    @staticmethod
    def _artifact_statuses(before, after, texts=None):
        """Per-file New/Modified/Unchanged plus the pre-generation text.

        Only files that actually change carry a baseline; an unchanged file
        has nothing to diff, and a new one starts from empty.
        """
        statuses = {}
        baselines = {}
        for relative, digest in after.items():
            if relative not in before:
                statuses[relative] = "New"
            elif before[relative] != digest:
                statuses[relative] = "Modified"
            else:
                statuses[relative] = "Unchanged"
                continue
            baselines[relative] = (texts or {}).get(relative, "")
        return statuses, baselines

    def generate_current(self):
        if (self.current_project is None or self._generation_running or self._save_running
                or self._load_running or self._project_operation_running):
            return
        self.config_page.finish_editing()
        project = self.current_project
        payload = self.config_page.content()
        service = self._worker_service()
        signature = self._saved_signature
        force = project.config_dir in self._reload_stale_projects
        root = project.config_dir.parent
        self._generation_running = True
        self._validation_revision += 1
        self._generation_failure = None
        self.log_panel.set_status("")
        self.window.show_log()
        self._set_output_state("generating", "正在校验、保存并生成 RTL 和 Testbench。")
        self.config_page.tabs.setEnabled(False)
        self.nav.setEnabled(False)

        def generate(progress):
            if service.signature(project) != signature:
                raise ValueError("配置文件已被外部修改，请通过“打开项目”重新打开。")
            before, before_texts = self._artifact_snapshot(service.output_files(project), root)
            progress(10, "正在生成")
            saved = None

            def on_saved():
                nonlocal saved
                saved = service.signature(project)

            try:
                result, files, report = service.generate(
                    project, payload, progress=lambda phase: progress(50, str(phase)),
                    on_saved=on_saved,
                    **({"force": True} if force else {}),
                )
                after, _ = self._artifact_snapshot(files, root, texts=False)
                progress(100, "生成完成")
                statuses, baselines = self._artifact_statuses(before, after, before_texts)
                return (
                    result, files, report, statuses, baselines,
                    service.signature(project),
                )
            except Exception as error:
                if saved is not None:
                    raise SavedGenerationError(error, saved) from error
                raise

        def unlock():
            self._generation_running = False
            self.config_page.tabs.setEnabled(True)
            self.nav.setEnabled(True)

        def failed(error):
            unlock()
            if isinstance(error, SavedGenerationError):
                self._saved_signature = error.signature
                self._validation_revision += 1
                self.config_page.mark_saved(payload)
                error = error.error
            self._generation_failure = str(error)
            self._show_validation_error(error)
            self.refresh_artifacts()
            self.log_panel.append_log(f"生成失败：{error}")
            self.window.show_log()

        def finished(data):
            unlock()
            if project != self.current_project:
                return
            result, files, report, statuses, baselines, saved = data
            self._saved_signature = saved
            self._reload_stale_projects.discard(project.config_dir)
            self._validation_revision += 1
            self.config_page.mark_saved(payload)
            self.config_page.artifacts_panel.set_files(
                files, root, statuses=statuses, baselines=baselines
            )
            self.validate_current()
            if report.strip():
                self.log_panel.append_log(report.strip())
            self.log_panel.append_log(
                f"{'生成完成' if result.generated else '输出已是最新'}：{len(files)} 个文件"
            )
            if result.generated:
                self.window.show_toast("✓ RTL 与测试用例生成成功", "success")
            else:
                self.window.show_toast("输出已是最新，无需重新生成", "info")

        self.tasks.submit(
            generate, finished, failed,
            lambda percent, message: self.log_panel.append_log(f"生成 {percent}%：{message}"),
        )

    def refresh_artifacts(self):
        if self.current_project is None:
            self.tasks.cancel_latest("artifact-scan")
            self.config_page.artifacts_panel.set_files([])
            self.validate_current()
            return
        project = self.current_project
        service = self._worker_service()

        def finished(files):
            if project == self.current_project:
                self.config_page.artifacts_panel.set_files(files, project.config_dir.parent)

        def scan(progress):
            progress.check_cancelled()
            files = service.output_files(project)
            progress.check_cancelled()
            return files

        self.tasks.submit_latest(
            "artifact-scan", scan, finished,
            lambda error: self.log_panel.append_log(f"扫描产物失败：{error}"),
        )
        self.validate_current()
