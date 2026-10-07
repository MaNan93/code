"""Artifact drawer behavior extracted from its widget construction."""

import difflib
from pathlib import Path
from PyQt5 import QtGui


MAX_PREVIEW_BYTES = 200 * 1024

MAX_PREVIEW_CACHE_BYTES = 8 * 1024 * 1024
ARTIFACT_LANGUAGES = {
    ".sv": "SystemVerilog", ".svh": "SystemVerilog",
    ".v": "Verilog", ".vh": "Verilog", ".json": "JSON",
}


class ArtifactPreview:
    """Focused artifact drawer behavior; widgets are owned by ArtifactsPanel."""

    @staticmethod
    def _read_contents(files):
        contents = {}
        errors = {}
        total = 0
        for value in files:
            path = Path(value).resolve()
            try:
                # [REFACTORED]: Bounded reads also protect against a growing file.
                with path.open("rb") as stream:
                    data = stream.read(MAX_PREVIEW_BYTES + 1)
                if len(data) > MAX_PREVIEW_BYTES or total + len(data) > MAX_PREVIEW_CACHE_BYTES:
                    errors[str(path)] = "文件过大，请在外部编辑器中打开（预览上限 200KB）。"
                    continue
                contents[str(path)] = data.decode("utf-8")
                total += len(data)
            except (OSError, UnicodeError) as error:
                errors[str(path)] = str(error)
        return contents, errors

    def _diff_available(self):
        if self.current_path is None:
            return False
        key = str(self.current_path)
        return (
            key in self._previous_contents
            and key in self._current_contents
            and self._previous_contents[key] != self._current_contents[key]
        )

    def _load_selected(self, *_):
        self._preview_revision += 1
        preview_revision = self._preview_revision
        self.empty_state.setVisible(self.current_path is None)
        self.preview.setVisible(self.current_path is not None)
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

                    def compute_diff(_progress):
                        return "".join(difflib.unified_diff(
                            previous.splitlines(keepends=True), current.splitlines(keepends=True),
                            fromfile=f"previous/{relative}", tofile=f"current/{relative}",
                        ))

                    def show_diff(diff):
                        if preview_revision == self._preview_revision:
                            self.preview.setPlainText(diff)

                    self.tasks.submit(compute_diff, show_diff, lambda error: show_diff(str(error)))
                    text = ""
                self.preview.setPlainText(text)
                self.preview.moveCursor(QtGui.QTextCursor.Start)
                self.preview.horizontalScrollBar().setValue(0)
                self._file_status = (
                    f"{self.selection.current_index + 1}/{len(self.selection.files)}"
                    f" · {len(text.splitlines())} 行"
                )
        diff_available = self._diff_available()
        self.diff_button.setEnabled(diff_available)
        if not diff_available and self.diff_button.isChecked():
            self.diff_button.blockSignals(True)
            self.diff_button.setChecked(False)
            self.diff_button.blockSignals(False)
        self._update_status()
        self._update_highlighting()
        self.preview.line_numbers.setVisible(self._readable)
        for button in (self.open_editor_button, self.copy_path_button):
            button.setEnabled(self.current_path is not None)
        self.tree_button.setEnabled(bool(self.selection.files))
        self.search_button.setEnabled(self._readable)
        if self._readable and self.search_input.text():
            self._search_changed()
        self._select_tree_path()

    def set_output_state(self, state, text, detail=""):
        self._output_state = state
        self._output_text = text
        self._output_detail = detail
        self.status.setProperty("state", state)
        self.status.style().unpolish(self.status)
        self.status.style().polish(self.status)
        self._update_status()

    def _update_status(self):
        text = self._output_text
        if not self._readable and (self.current_path is not None or not text):
            text = self._file_status
        self.status.setText(text)
        self.status.setVisible(bool(text))
        self.file_progress.setText(
            f"{self.selection.current_index + 1}/{len(self.selection.files)}"
            + (f" · {len(self._current_contents.get(str(self.current_path), '').splitlines())} 行"
               if self._readable else "")
            if self.current_path is not None else ""
        )
        self.status.setToolTip("\n".join(part for part in (self._file_error, self._output_detail) if part))
        self._update_editor_status()

    def _update_editor_status(self):
        if not self._readable or self.current_path is None:
            self.editor_metadata.set_metadata("")
            return
        cursor = self.preview.textCursor()
        text = self._current_contents.get(str(self.current_path), "")
        newlines = "CRLF" if "\r\n" in text else "LF"
        if newlines == "CRLF" and "\n" in text.replace("\r\n", ""):
            newlines = "Mixed"
        language = ARTIFACT_LANGUAGES.get(self.current_path.suffix.lower(), "Plain Text")
        if self.diff_button.isChecked() and self._diff_available():
            language = "Diff"
        metadata = (
            f"行 {cursor.blockNumber() + 1}，"
            f"列 {cursor.positionInBlock() + 1} · {language} · UTF-8 · {newlines} · RO"
        )
        self.editor_metadata.set_metadata(metadata)

    def _update_highlighting(self, *_):
        is_verilog = (
            self.current_path is not None
            and self.current_path.suffix.lower() in (".v", ".sv", ".vh", ".svh")
        )
        enabled = self._readable and is_verilog and not self.diff_button.isChecked()
        self.preview.highlighter.set_enabled(enabled)
