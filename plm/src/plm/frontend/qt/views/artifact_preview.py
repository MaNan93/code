"""Artifact drawer behavior extracted from its widget construction."""

import difflib
from pathlib import Path
from PyQt5 import QtGui


MAX_PREVIEW_BYTES = 200 * 1024

MAX_PREVIEW_CACHE_BYTES = 8 * 1024 * 1024


class ArtifactPreview:
    """Focused artifact drawer behavior; widgets are owned by ArtifactsPanel."""

    @staticmethod
    def _read_contents(files):
        contents = {}
        errors = {}
        for value in files:
            path = Path(value).resolve()
            try:
                # [REFACTORED]: Bounded reads also protect against a growing file.
                with path.open("rb") as stream:
                    data = stream.read(MAX_PREVIEW_BYTES + 1)
                if len(data) > MAX_PREVIEW_BYTES:
                    errors[str(path)] = "文件过大，请在外部编辑器中打开（预览上限 200KB）。"
                    continue
                contents[str(path)] = data.decode("utf-8")
            except (OSError, UnicodeError) as error:
                errors[str(path)] = str(error)
        return contents, errors

    def _cache_content(self, key, text):
        """Keep current and previous preview versions in one bounded LRU."""
        token = ("current", key)
        self._content_cache_bytes -= self._content_lru.pop(token, 0)
        self._current_contents[key] = text
        size = len(text.encode("utf-8"))
        self._content_lru[token] = size
        self._content_cache_bytes += size
        self._trim_content_cache()

    def _trim_content_cache(self):
        """Evict the least recently used preview until the budget holds."""
        while self._content_cache_bytes > MAX_PREVIEW_CACHE_BYTES:
            (version, oldest), size = self._content_lru.popitem(last=False)
            contents = self._current_contents if version == "current" else self._previous_contents
            contents.pop(oldest, None)
            self._content_cache_bytes -= size

    def _diff_baseline(self):
        """True when a previous preview exists for the current file.

        Deliberately independent of whether this refresh's read has landed:
        set_files() clears _current_contents up front and refills it from a
        worker, so a readiness-based check sees "no diff" for the whole read
        window and would strip the button's checked state on every
        regeneration or on every switch to a file that is not cached yet.
        """
        return self.current_path is not None and str(self.current_path) in self._previous_contents

    def _diff_available(self):
        if self.current_path is None:
            return False
        key = str(self.current_path)
        return (
            key in self._previous_contents
            and key in self._current_contents
            and self._previous_contents[key] != self._current_contents[key]
        )

    def _diff_enabled(self):
        """Whether the toggle can do anything for the current file.

        A file whose read has not landed yet stays enabled: set_files()
        empties _current_contents up front, so a purely readiness-based
        answer reads as "no diff" for the whole read window and would grey
        the button out on every regeneration.
        """
        if not self._diff_baseline():
            return False
        if str(self.current_path) not in self._current_contents:
            return True
        return self._diff_available()

    def _load_selected(self, *_):
        self._ensure_selected_contents()
        self.tasks.cancel_latest("artifact-diff")
        self._preview_revision += 1
        preview_revision = self._preview_revision
        self.empty_state.setVisible(self.current_path is None)
        self.preview.setVisible(self.current_path is not None)
        self.preview.set_diff_mode(False)
        self.preview.clear()
        self._readable = False
        self.search_status.clear()
        self.preview.setToolTip("")
        self.path_label.set_path(self.current_path, self.workspace_root)
        self._file_error = ""
        text = ""
        if self.current_path is None:
            self.preview.setPlaceholderText("尚无生成文件")
            self._file_status = "尚无生成文件"
        else:
            key = str(self.current_path)
            text = self._current_contents.get(key, "")
            if key not in self._current_contents:
                self._file_error = self._file_errors.get(key, "")
                self.preview.setPlaceholderText(
                    "正在读取文件…" if self._loading_contents else
                    self._file_error or "无法预览该文件，请刷新或选择其他文件"
                )
                self._file_status = "读取中" if self._loading_contents else "无法预览"
            else:
                self._readable = True
            if self._readable:
                self.preview.setPlaceholderText("文件为空")
                if self.diff_button.isChecked() and self._diff_available():
                    previous = self._previous_contents[key]
                    relative = self.current_path.name
                    if self.workspace_root is not None:
                        try:
                            relative = self.current_path.relative_to(self.workspace_root).as_posix()
                        except ValueError:
                            pass
                    current = text
                    self.preview.setPlaceholderText("正在计算差异…")

                    def compute_diff(progress):
                        progress.check_cancelled()
                        chunks = []
                        for chunk in difflib.unified_diff(
                            previous.splitlines(keepends=True), current.splitlines(keepends=True),
                            fromfile=f"previous/{relative}", tofile=f"current/{relative}",
                        ):
                            progress.check_cancelled()
                            chunks.append(chunk)
                            if not chunk.endswith("\n"):
                                chunks.append("\n\\ No newline at end of file\n")
                        return "".join(chunks)

                    def show_diff(diff):
                        if preview_revision == self._preview_revision:
                            self.preview.setPlainText(diff)
                            self.preview.set_diff_mode(True)
                            if self.search_input.text():
                                self._search_changed()

                    self.tasks.submit_latest(
                        "artifact-diff", compute_diff, show_diff,
                        lambda error: show_diff(str(error)),
                    )
                    text = ""
                self.preview.setPlainText(text)
                self.preview.moveCursor(QtGui.QTextCursor.Start)
                self.preview.horizontalScrollBar().setValue(0)
                # Report the file's own line count, not the diff's: while a
                # diff is pending, text is cleared and would read as 0 行.
                self._file_status = (
                    f"{self.selection.current_index + 1}/{len(self.selection.files)}"
                    f" · {len(self._current_contents.get(key, '').splitlines())} 行"
                )
        diff_enabled = self._diff_enabled()
        self.diff_button.setEnabled(diff_enabled)
        if not diff_enabled and self.diff_button.isChecked():
            self.diff_button.blockSignals(True)
            self.diff_button.setChecked(False)
            self.diff_button.blockSignals(False)
        self._update_status()
        self._update_highlighting()
        self.preview.line_numbers.setVisible(self._readable)
        for button in (self.open_editor_button, self.copy_path_button):
            button.setEnabled(self.current_path is not None)
        self.path_button.setEnabled(bool(self.selection.files))
        self.search_button.setEnabled(self._readable)
        if self._readable and self.search_input.text():
            self._search_changed()
        self._select_tree_path()

    def set_output_state(self, state, text, detail=""):
        self._output_state = state
        self._output_text = text
        self._output_detail = detail
        self._update_status()

    def _update_status(self):
        text = self._output_text
        if not text and self._readable:
            text = self._file_status
        if not self._readable and (self.current_path is not None or not text):
            text = self._file_status
        self.status_text = text
        self.toolbar.setAccessibleDescription(text)
        self.toolbar.setToolTip("\n".join(
            part for part in (text, self._file_error, self._output_detail) if part
        ))

    def _update_highlighting(self, *_):
        is_verilog = (
            self.current_path is not None
            and self.current_path.suffix.lower() in (".v", ".sv", ".vh", ".svh")
        )
        enabled = self._readable and is_verilog and not self.diff_button.isChecked()
        self.preview.highlighter.set_enabled(enabled)
