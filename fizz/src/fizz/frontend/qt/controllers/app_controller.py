"""Coordinate Fizz workflows; views own widgets and core owns algorithms."""

import os
import subprocess
from types import SimpleNamespace

from PyQt5 import QtCore, QtGui, QtWidgets

from fizz import core
from fizz.frontend.qt.services.tasks import (
    LineStreamWorker,
    MergeWorker,
    RLskitUploadWorker,
    RLskitWorker,
)
from fizz.frontend.qt.widgets.common import polish_controls
from fizz.frontend.qt.widgets.ftp_browser import FtpBrowserDialog
from fizz.frontend.qt.widgets.history_dialog import RLskitHistoryDialog
from fizz.frontend.qt.widgets.postsim_dialog import TimingViolationDialog
from fizz.frontend.qt.widgets.preferences_dialog import PreferencesDialog
from fizz.frontend.qt.widgets.whitelist_dialog import WhitelistDialog

ABOUT_TEXT = "fizz 工具功能说明\n\n1. 合并\n- 从 generalMessage.txt 提取 included/source file 并按顺序合并\n- 支持过滤目录/文件、注释 include、可选 strip-comments、protect 插桩\n\n2. VCS Protect\n- 调用 vcs -ipprotect 对源文件做加密保护\n\n3. Obfuscator\n- 调用 verible-verilog-obfuscate 做混淆\n- 支持 load_map/save_map\n\n4. RLskit\n- 目录复制、打包 tar.gz、计算 cksum、可选 FTP 上传\n- 支持 FTP 目录浏览与 Release Note 编辑\n\n5. 后仿分析\n- 递归搜索日志文件，提取 Timing violation 并支持 waive"


class AppController(QtCore.QObject):
    def __init__(self, window, config=None, script_dir=None):
        super().__init__(window)
        self.window = window
        self.config = config if config is not None else core.FizzConfig()
        self.script_dir = script_dir or os.getcwd()
        self.pages = SimpleNamespace()
        self.included_files = []
        self.source_files = []
        self._raw_included_files = []
        self._raw_source_files = []
        self.rlskit_cksum = ""
        self._merge_worker = self._obf_worker = None
        self._vcs_worker = self._rlskit_worker = None
        self._rlskit_src_timer = QtCore.QTimer(self, singleShot=True, interval=500)
        self._rlskit_src_timer.timeout.connect(self._do_rlskit_src_changed)
        self._postsim_timer = QtCore.QTimer(self, singleShot=True, interval=300)
        self._postsim_timer.timeout.connect(self._postsim_search)
        self._cksum_timer = QtCore.QTimer(self, singleShot=True, interval=800)
        self._cksum_timer.timeout.connect(self._restore_cksum_button)

    def initialize(self):
        self.config.ensure_exists()
        self._load_config()
        self._set_defaults()
        self.pages.obf.obf_src_edit.textChanged.connect(self._update_obf_defaults)
        self._update_obf_defaults()
        self.pages.rlskit.rlskit_src_edit.textChanged.connect(
            self._on_rlskit_src_changed
        )
        self.pages.rlskit.rlskit_suffix_edit.textChanged.connect(
            self._update_rlskit_preview
        )
        self.pages.postsim.postsim_dir_edit.textChanged.connect(self._postsim_debounce)
        self.pages.postsim.postsim_pattern_edit.textChanged.connect(
            self._postsim_debounce
        )
        self._do_rlskit_src_changed()
        self._postsim_timer.start()

    def active_workers(self):
        return [
            worker
            for worker in (
                self._merge_worker,
                self._vcs_worker,
                self._obf_worker,
                self._rlskit_worker,
            )
            if worker is not None and worker.isRunning()
        ]

    def stop_timers(self):
        self._rlskit_src_timer.stop()
        self._postsim_timer.stop()
        self._cksum_timer.stop()

    def _dialog_initial_dir(self, current_value):
        value = os.path.expanduser((current_value or "").strip())
        if not value:
            return self.script_dir
        if os.path.isdir(value):
            return value
        parent = os.path.dirname(value)
        if parent and os.path.isdir(parent):
            return parent
        return self.script_dir

    def _open_preferences_dialog(self):
        values = {
            "exclude_dirs": self.pages.merge.dir_filter_edit.text(),
            "exclude_files": self.pages.merge.file_filter_edit.text(),
            "vcs_key_file": self.pages.vcs.vcs_key_edit.text(),
            "vcs_options": self.pages.vcs.vcs_opt_edit.text(),
            "obfuscator_path": self.pages.obf.obf_tool_edit.text(),
            "ftp_url": self.pages.rlskit.rlskit_ftp_url_edit.text(),
            "ftp_username": self.pages.rlskit.rlskit_ftp_user_edit.text(),
            "ftp_password": self.pages.rlskit.rlskit_ftp_pass_edit.text(),
        }
        dlg = PreferencesDialog(values, self._dialog_initial_dir, self.window)
        if dlg.exec_() != QtWidgets.QDialog.Accepted:
            return
        new_values = dlg.values()
        self.pages.merge.dir_filter_edit.setText(new_values["exclude_dirs"])
        self.pages.merge.file_filter_edit.setText(new_values["exclude_files"])
        self.pages.vcs.vcs_key_edit.setText(new_values["vcs_key_file"])
        self.pages.vcs.vcs_opt_edit.setText(new_values["vcs_options"])
        self.pages.obf.obf_tool_edit.setText(new_values["obfuscator_path"])
        self.pages.rlskit.rlskit_ftp_url_edit.setText(new_values["ftp_url"])
        self.pages.rlskit.rlskit_ftp_user_edit.setText(new_values["ftp_username"])
        self.pages.rlskit.rlskit_ftp_pass_edit.setText(new_values["ftp_password"])
        self._save_config()
        self.window.statusBar().showMessage("配置已保存")
        if dlg.action == "open":
            self._open_config_file()

    def _open_config_file(self):
        self.config.ensure_exists()
        try:
            subprocess.Popen(["gvim", self.config.path])
        except FileNotFoundError:
            QtWidgets.QMessageBox.critical(
                self.window,
                "错误",
                "未找到 gvim 命令，请确认 gvim 已安装并在 PATH 中。",
            )
        except OSError as e:
            QtWidgets.QMessageBox.critical(
                self.window, "错误", f"打开配置文件失败:\n{e}"
            )

    def _show_about(self):
        dlg = QtWidgets.QDialog(self.window)
        dlg.setWindowTitle("fizz 使用说明")
        dlg.resize(int(self.window.width() * 0.7), int(self.window.height() * 0.6))
        layout = QtWidgets.QVBoxLayout(dlg)
        text = QtWidgets.QTextEdit()
        text.setReadOnly(True)
        text.setPlainText(ABOUT_TEXT)
        text.setFont(QtGui.QFont("Consolas", 10))
        layout.addWidget(text, 1)
        close_btn = QtWidgets.QPushButton("关闭")
        close_btn.clicked.connect(dlg.accept)
        btn_row = QtWidgets.QHBoxLayout()
        btn_row.addStretch(1)
        btn_row.addWidget(close_btn)
        btn_row.addStretch(1)
        layout.addLayout(btn_row)
        polish_controls(dlg)
        dlg.exec_()

    def _load_config(self):
        data = self.config.load()
        self.pages.merge.dir_filter_edit.setText(data["exclude_dirs"])
        self.pages.merge.file_filter_edit.setText(data["exclude_files"])
        self.pages.vcs.vcs_key_edit.setText(data["vcs_key_file"])
        self.pages.vcs.vcs_opt_edit.setText(
            data["vcs_options"] or core.DEFAULT_VCS_OPTIONS
        )
        self.pages.obf.obf_tool_edit.setText(
            data["obfuscator_path"] or core.DEFAULT_OBF_TOOL
        )
        self.pages.obf.obf_whitelist_edit.setText(data["whitelist_file"])
        self.pages.rlskit.rlskit_ftp_url_edit.setText(data["ftp_url"])
        self.pages.rlskit.rlskit_ftp_user_edit.setText(data["ftp_username"])
        self.pages.rlskit.rlskit_ftp_pass_edit.setText(data["ftp_password"])
        if data["last_version"]:
            self.pages.rlskit.rlskit_suffix_edit.setText(data["last_version"])

    def _save_config(self):
        self.config.save(
            {
                "exclude_dirs": self.pages.merge.dir_filter_edit.text(),
                "exclude_files": self.pages.merge.file_filter_edit.text(),
                "vcs_key_file": self.pages.vcs.vcs_key_edit.text(),
                "vcs_options": self.pages.vcs.vcs_opt_edit.text(),
                "obfuscator_path": self.pages.obf.obf_tool_edit.text(),
                "whitelist_file": self.pages.obf.obf_whitelist_edit.text(),
                "ftp_url": self.pages.rlskit.rlskit_ftp_url_edit.text(),
                "ftp_username": self.pages.rlskit.rlskit_ftp_user_edit.text(),
                "ftp_password": self.pages.rlskit.rlskit_ftp_pass_edit.text(),
                "last_version": self.pages.rlskit.rlskit_suffix_edit.text(),
            }
        )

    def _set_defaults(self):
        default_msg = os.path.join(self.script_dir, "generalMessage.txt")
        self.pages.merge.msg_path_edit.setText(default_msg)
        self.pages.merge.out_path_edit.setText(os.path.join(self.script_dir, "one.sv"))
        if os.path.isdir(self.script_dir):
            self.pages.rlskit.rlskit_src_edit.setText(self.script_dir)
        self.pages.vcs.vcs_src_edit.setText(os.path.join(self.script_dir, "one.sv"))
        pciegen = os.environ.get("PCIEGEN", "")
        if pciegen and (not self.pages.vcs.vcs_key_edit.text().strip()):
            self.pages.vcs.vcs_key_edit.setText(os.path.join(pciegen, "sim2-key.txt"))
        if os.path.isfile(default_msg):
            self._parse()
        self.pages.obf.obf_src_edit.setText(os.path.join(self.script_dir, "one.sv"))

    def _browse_msg(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self.window,
            "选择消息文件",
            self.script_dir,
            "Text files (*.txt);;All files (*.*)",
        )
        if path:
            self.pages.merge.msg_path_edit.setText(path)

    def _browse_out(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self.window,
            "保存合并结果",
            self.script_dir,
            "SystemVerilog (*.sv);;Verilog (*.v);;Text (*.txt);;All (*.*)",
        )
        if path:
            self.pages.merge.out_path_edit.setText(path)

    def _parse(self):
        msg_path = self.pages.merge.msg_path_edit.text().strip()
        if not msg_path:
            QtWidgets.QMessageBox.warning(self.window, "提示", "请先选择消息文件。")
            return
        if not os.path.isfile(msg_path):
            QtWidgets.QMessageBox.critical(
                self.window, "错误", f"文件不存在:\n{msg_path}"
            )
            return
        try:
            inc, src = core.parse_general_message(msg_path)
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            QtWidgets.QMessageBox.critical(self.window, "错误", f"读取文件失败:\n{e}")
            return
        self._raw_included_files = inc
        self._raw_source_files = src
        dir_text = self.pages.merge.dir_filter_edit.text()
        file_text = self.pages.merge.file_filter_edit.text()
        if core.split_patterns(dir_text) or core.split_patterns(file_text):
            self.included_files = core.filter_files(inc, dir_text, file_text)
            self.source_files = core.filter_files(src, dir_text, file_text)
            self._refresh_list()
            self.pages.merge.merge_status_label.setText(
                f"解析完成: included {len(inc)}->{len(self.included_files)}, source {len(src)}->{len(self.source_files)}"
            )
        else:
            self.included_files = list(inc)
            self.source_files = list(src)
            self._refresh_list()
            self.pages.merge.merge_status_label.setText(
                f"解析完成: included={len(inc)}, source={len(src)}"
            )

    def _apply_filter(self):
        if not self._raw_included_files and (not self._raw_source_files):
            self._parse()
            return
        dir_text = self.pages.merge.dir_filter_edit.text()
        file_text = self.pages.merge.file_filter_edit.text()
        self.included_files = core.filter_files(
            self._raw_included_files, dir_text, file_text
        )
        self.source_files = core.filter_files(
            self._raw_source_files, dir_text, file_text
        )
        self._refresh_list()
        self.pages.merge.merge_status_label.setText(
            f"过滤后: included {len(self._raw_included_files)}->{len(self.included_files)}, source {len(self._raw_source_files)}->{len(self.source_files)}"
        )

    def _refresh_list(self):
        self.pages.merge.file_listwidget.clear()
        self.pages.merge.file_listwidget.addItems(self.included_files)
        self.pages.merge.file_listwidget.addItems(self.source_files)

    def _file_list_context_menu(self, pos):
        menu = QtWidgets.QMenu(self.window)
        menu.addAction("复制路径", self._file_list_copy)
        menu.addSeparator()
        menu.addAction("全选 (Ctrl+A)", self.pages.merge.file_listwidget.selectAll)
        menu.addAction("取消全选", self.pages.merge.file_listwidget.clearSelection)
        menu.addAction("反选", self._file_list_invert)
        menu.exec_(self.pages.merge.file_listwidget.mapToGlobal(pos))

    def _file_list_copy(self):
        paths = [
            item.text() for item in self.pages.merge.file_listwidget.selectedItems()
        ]
        if paths:
            QtWidgets.QApplication.clipboard().setText("\n".join(paths))
            self.window.statusBar().showMessage(f"已复制 {len(paths)} 个路径到剪贴板")

    def _file_list_invert(self):
        for i in range(self.pages.merge.file_listwidget.count()):
            item = self.pages.merge.file_listwidget.item(i)
            item.setSelected(not item.isSelected())

    def _merge(self):
        all_files = list(self.included_files) + list(self.source_files)
        if not all_files:
            QtWidgets.QMessageBox.warning(self.window, "提示", "没有要合并的文件。")
            return
        out_path = self.pages.merge.out_path_edit.text().strip()
        if not out_path:
            QtWidgets.QMessageBox.warning(self.window, "提示", "请指定输出文件路径。")
            return
        msg_dir = os.path.dirname(
            os.path.abspath(self.pages.merge.msg_path_edit.text())
        )
        protect = self.pages.merge.protect_check.isChecked()
        top_name = self.pages.merge.top_file_edit.text().strip()
        strip = self.pages.merge.strip_comments_check.isChecked()
        self.pages.merge.merge_progress.setMaximum(len(all_files))
        self.pages.merge.merge_progress.setValue(0)
        self.pages.merge.merge_btn.setEnabled(False)
        self.pages.merge.merge_status_label.setText("合并中...")
        self._merge_worker = MergeWorker(
            all_files,
            out_path,
            msg_dir,
            self.script_dir,
            protect,
            top_name,
            strip,
            self.window,
        )
        self._merge_worker.progress.connect(
            lambda i, t: self.pages.merge.merge_progress.setValue(i)
        )
        self._merge_worker.finished_ok.connect(
            lambda result: self._on_merge_done(result, out_path, len(all_files))
        )
        self._merge_worker.failed.connect(self._on_merge_failed)
        self._merge_worker.start()

    def _on_merge_done(self, result, out_path, total):
        self.pages.merge.merge_progress.setValue(total)
        self.pages.merge.merge_btn.setEnabled(True)
        if result.missing:
            self.pages.merge.merge_status_label.setText(
                f"合并完成 (缺 {len(result.missing)} 个): {total} 个文件, {result.merged_lines} 行 → {os.path.basename(out_path)}"
            )
        else:
            self.pages.merge.merge_status_label.setText(
                f"合并完成: {total} 个文件, {result.merged_lines} 行 → {os.path.basename(out_path)}"
            )

    def _on_merge_failed(self, message):
        self.pages.merge.merge_btn.setEnabled(True)
        self.pages.merge.merge_status_label.setText("合并失败")
        QtWidgets.QMessageBox.critical(
            self.window, "错误", f"写入输出文件失败:\n{message}"
        )

    def _browse_vcs_src(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self.window,
            "选择源文件",
            self.script_dir,
            "SystemVerilog (*.sv);;Verilog (*.v);;All (*.*)",
        )
        if path:
            self.pages.vcs.vcs_src_edit.setText(path)

    def _browse_vcs_key(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self.window,
            "选择密钥文件",
            self._dialog_initial_dir(self.pages.vcs.vcs_key_edit.text()),
            "Text files (*.txt);;All (*.*)",
        )
        if path:
            self.pages.vcs.vcs_key_edit.setText(path)

    def _log_append(self, widget, text):
        ts = QtCore.QTime.currentTime().toString("HH:mm:ss")
        lines = text.split("\n")
        for i, line in enumerate(lines):
            stripped = line.lstrip()
            if stripped:
                if stripped.startswith(">"):
                    stripped = stripped[1:].lstrip()
                lines[i] = f"{ts} > {stripped}"
        text = "\n".join(lines)
        cursor = widget.textCursor()
        cursor.movePosition(QtGui.QTextCursor.End)
        cursor.insertText(text)
        widget.setTextCursor(cursor)
        widget.ensureCursorVisible()

    def _run_vcs(self):
        src_path = os.path.expanduser(self.pages.vcs.vcs_src_edit.text().strip())
        key_path = os.path.expanduser(self.pages.vcs.vcs_key_edit.text().strip())
        opts = self.pages.vcs.vcs_opt_edit.text().strip()
        if not src_path:
            QtWidgets.QMessageBox.warning(self.window, "提示", "请选择源文件。")
            return
        if not os.path.isfile(src_path):
            QtWidgets.QMessageBox.critical(
                self.window, "错误", f"源文件不存在:\n{src_path}"
            )
            return
        if not key_path:
            QtWidgets.QMessageBox.warning(self.window, "提示", "请选择密钥文件。")
            return
        if not os.path.isfile(key_path):
            QtWidgets.QMessageBox.critical(
                self.window, "错误", f"密钥文件不存在:\n{key_path}"
            )
            return
        cmd_preview = ["vcs", "-ipprotect", key_path] + opts.split() + [src_path]
        self._log_append(self.pages.vcs.vcs_log, f"> {' '.join(cmd_preview)}\n\n")
        self.pages.vcs.vcs_run_btn.setEnabled(False)
        self._vcs_worker = LineStreamWorker(
            core.run_vcs_protect,
            src_path,
            key_path,
            opts,
            not_found_message="找不到 vcs 命令，请确认 VCS 已安装且在 PATH 中。",
            parent=self.window,
        )
        self._vcs_worker.line.connect(
            lambda text: self._log_append(self.pages.vcs.vcs_log, text)
        )
        self._vcs_worker.finished_ok.connect(self._on_vcs_done)
        self._vcs_worker.failed.connect(self._on_vcs_failed)
        self._vcs_worker.start()

    def _on_vcs_done(self, returncode):
        self._log_append(
            self.pages.vcs.vcs_log, f"\n--- VCS 退出码: {returncode} ---\n"
        )
        self.pages.vcs.vcs_run_btn.setEnabled(True)

    def _on_vcs_failed(self, message):
        self._log_append(self.pages.vcs.vcs_log, f"\n[错误] {message}\n")
        self.pages.vcs.vcs_run_btn.setEnabled(True)

    def _browse_obf_src(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self.window,
            "选择源文件",
            self._dialog_initial_dir(self.pages.obf.obf_src_edit.text()),
            "SystemVerilog (*.sv);;Verilog (*.v);;All (*.*)",
        )
        if path:
            self.pages.obf.obf_src_edit.setText(path)

    def _browse_obf_out(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self.window,
            "保存混淆结果",
            self._dialog_initial_dir(
                self.pages.obf.obf_out_edit.text() or self.pages.obf.obf_src_edit.text()
            ),
            "SystemVerilog (*.sv);;Verilog (*.v);;All (*.*)",
        )
        if path:
            self.pages.obf.obf_out_edit.setText(path)

    def _browse_obf_load_map(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self.window,
            "选择 load_map 文件",
            self._dialog_initial_dir(
                self.pages.obf.obf_load_map_edit.text()
                or self.pages.obf.obf_src_edit.text()
            ),
            "Map (*.map);;All (*.*)",
        )
        if path:
            self.pages.obf.obf_load_map_edit.setText(path)

    def _browse_obf_save_map(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self.window,
            "保存 save_map 文件",
            self._dialog_initial_dir(
                self.pages.obf.obf_save_map_edit.text()
                or self.pages.obf.obf_src_edit.text()
            ),
            "Map (*.map);;All (*.*)",
        )
        if path:
            self.pages.obf.obf_save_map_edit.setText(path)

    def _update_obf_defaults(self):
        src = self.pages.obf.obf_src_edit.text().strip()
        if not src:
            return
        d = os.path.dirname(src)
        name, ext = os.path.splitext(os.path.basename(src))
        self.pages.obf.obf_out_edit.setText(os.path.join(d, f"{name}_obf{ext}"))
        self.pages.obf.obf_save_map_edit.setText(os.path.join(d, "restore.map"))

    def _browse_obf_whitelist(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self.window,
            "选择白名单文件",
            self._dialog_initial_dir(
                self.pages.obf.obf_whitelist_edit.text() or core.DEFAULT_WHITELIST_FILE
            ),
            "Map (*.map);;All (*.*)",
        )
        if path:
            self.pages.obf.obf_whitelist_edit.setText(path)

    def _edit_obf_whitelist(self):
        path = (
            self.pages.obf.obf_whitelist_edit.text().strip()
            or core.DEFAULT_WHITELIST_FILE
        )
        self.pages.obf.obf_whitelist_edit.setText(path)
        dlg = WhitelistDialog(path, self.window)
        if dlg.exec_() == QtWidgets.QDialog.Accepted:
            self._save_config()
            self.window.statusBar().showMessage(
                f"白名单已保存: {os.path.basename(path)}"
            )

    def _run_obfuscate(self):
        src_path = os.path.expanduser(self.pages.obf.obf_src_edit.text().strip())
        out_path = self.pages.obf.obf_out_edit.text().strip()
        save_map = self.pages.obf.obf_save_map_edit.text().strip()
        tool_bin = self.pages.obf.obf_tool_edit.text().strip() or core.DEFAULT_OBF_TOOL
        first_obf = self.pages.obf.obf_first_check.isChecked()
        if not src_path or not os.path.isfile(src_path):
            QtWidgets.QMessageBox.critical(
                self.window, "错误", f"源文件不存在:\n{src_path}"
            )
            return
        if not out_path:
            QtWidgets.QMessageBox.warning(self.window, "提示", "请指定输出文件。")
            return
        if first_obf:
            load_map = self.pages.obf.obf_whitelist_edit.text().strip()
            if not load_map or not os.path.isfile(load_map):
                QtWidgets.QMessageBox.warning(
                    self.window, "提示", "请先编辑并保存白名单文件。"
                )
                return
        else:
            load_map = self.pages.obf.obf_load_map_edit.text().strip()
        self._log_append(self.pages.obf.obf_log, f"> {tool_bin} < {src_path}\n\n")
        if first_obf:
            self._log_append(
                self.pages.obf.obf_log,
                f"  (首次混淆: 以白名单 {load_map} 作为 load_map)\n\n",
            )
        self.pages.obf.obf_run_btn.setEnabled(False)
        self._save_config()
        self._obf_worker = LineStreamWorker(
            core.run_obfuscate,
            src_path,
            out_path,
            save_map,
            load_map,
            tool_bin,
            not_found_message=f"找不到 {tool_bin}，请确认工具路径正确且可执行。",
            parent=self.window,
        )
        self._obf_worker.line.connect(
            lambda text: self._log_append(self.pages.obf.obf_log, text)
        )
        self._obf_worker.finished_ok.connect(
            lambda rc: self._on_obf_done(rc, tool_bin, first_obf, save_map)
        )
        self._obf_worker.failed.connect(self._on_obf_failed)
        self._obf_worker.start()

    def _on_obf_done(self, returncode, tool_bin, first_obf, save_map):
        name = os.path.basename(tool_bin)
        if returncode != 0:
            self._log_append(
                self.pages.obf.obf_log, f"\n[错误] {name} 退出码: {returncode}\n"
            )
        else:
            self._log_append(self.pages.obf.obf_log, f"\n--- {name} 完成 ---\n")
            if first_obf and save_map:
                self.pages.obf.obf_first_check.setChecked(False)
                self.pages.obf.obf_load_map_edit.setText(save_map)
                self._save_config()
                self._log_append(
                    self.pages.obf.obf_log,
                    f"  (白名单已并入 {save_map}；后续混淆将从这份 map 继续，已自动取消勾选“首次混淆”)\n",
                )
        self.pages.obf.obf_run_btn.setEnabled(True)

    def _on_obf_failed(self, message):
        self._log_append(self.pages.obf.obf_log, f"\n[错误] {message}\n")
        self.pages.obf.obf_run_btn.setEnabled(True)

    def _browse_rlskit_src(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(
            self.window, "选择源目录", self.script_dir
        )
        if path:
            self.pages.rlskit.rlskit_src_edit.setText(path)

    def _browse_ftp(self):
        dlg = FtpBrowserDialog(
            self.pages.rlskit.rlskit_ftp_url_edit.text().strip(),
            self.pages.rlskit.rlskit_ftp_user_edit.text().strip(),
            self.pages.rlskit.rlskit_ftp_pass_edit.text(),
            self.window,
        )
        if dlg.exec_() == QtWidgets.QDialog.Accepted and dlg.selected_url:
            self.pages.rlskit.rlskit_ftp_url_edit.setText(dlg.selected_url)

    def _full_suffix(self):
        return core.full_suffix(self.pages.rlskit.rlskit_suffix_edit.text())

    def _update_rlskit_preview(self):
        src = self.pages.rlskit.rlskit_src_edit.text().strip()
        suffix = self._full_suffix()
        if src and suffix:
            parent = os.path.dirname(src)
            name = os.path.basename(src)
            self.pages.rlskit.rlskit_dst_edit.setText(
                os.path.join(parent, name + suffix)
            )
        else:
            self.pages.rlskit.rlskit_dst_edit.setText("")

    def _on_rlskit_src_changed(self):
        self._rlskit_src_timer.start()

    def _do_rlskit_src_changed(self):
        self._update_rlskit_preview()
        self._load_release_note()
        src = self.pages.rlskit.rlskit_src_edit.text().strip()
        if src and os.path.isdir(src):
            values = self.config.load_rlskit_for_dir(src)
            if values:
                if "ftp_url" in values:
                    self.pages.rlskit.rlskit_ftp_url_edit.setText(values["ftp_url"])
                if "ftp_username" in values:
                    self.pages.rlskit.rlskit_ftp_user_edit.setText(
                        values["ftp_username"]
                    )
                if "ftp_password" in values:
                    self.pages.rlskit.rlskit_ftp_pass_edit.setText(
                        values["ftp_password"]
                    )
                if "last_version" in values:
                    self.pages.rlskit.rlskit_suffix_edit.setText(values["last_version"])

    def _release_note_path(self):
        return core.release_note_path(self.pages.rlskit.rlskit_src_edit.text().strip())

    def _load_release_note(self):
        path = self._release_note_path()
        content = core.load_release_note(path) if path else None
        if content is not None:
            self.pages.rlskit.rn_text.setPlainText(content)
        else:
            self.pages.rlskit.rn_text.clear()
            if path:
                self.pages.rlskit.rn_text.setPlainText(
                    f"; 未找到 Release_Note.txt\n; 路径: {path}\n"
                )

    def _save_release_note(self):
        path = self._release_note_path()
        if not path:
            QtWidgets.QMessageBox.warning(
                self.window, "提示", "请先在 RLskit 页面中选择源目录。"
            )
            return
        core.save_release_note(path, self.pages.rlskit.rn_text.toPlainText())
        QtWidgets.QMessageBox.information(
            self.window, "提示", f"已保存: {os.path.basename(path)}"
        )

    def _copy_cksum(self):
        if not self.rlskit_cksum:
            QtWidgets.QMessageBox.warning(
                self.window, "提示", "暂无 cksum 值，请先执行打包。"
            )
            return
        QtWidgets.QApplication.clipboard().setText(self.rlskit_cksum)
        self.window.statusBar().showMessage(f"cksum 已复制: {self.rlskit_cksum}")
        self.pages.rlskit.rlskit_copy_btn.setText("Copied")
        self._cksum_timer.start()

    def _restore_cksum_button(self):
        self.pages.rlskit.rlskit_copy_btn.setText("cksum copy")

    def _open_history_view(self):
        dlg = RLskitHistoryDialog(self.config, self.window)
        dlg.exec_()

    def _run_rlskit(self):
        src = self.pages.rlskit.rlskit_src_edit.text().strip()
        suffix = self._full_suffix()
        raw_ver = self.pages.rlskit.rlskit_suffix_edit.text().strip()
        ftp_url = self.pages.rlskit.rlskit_ftp_url_edit.text().strip()
        ftp_user = self.pages.rlskit.rlskit_ftp_user_edit.text().strip()
        ftp_pass = self.pages.rlskit.rlskit_ftp_pass_edit.text()
        if not src or not os.path.isdir(src):
            QtWidgets.QMessageBox.critical(self.window, "错误", "请选择有效的源目录。")
            return
        if not suffix:
            QtWidgets.QMessageBox.warning(self.window, "提示", "请填写版本号。")
            return
        self.pages.rlskit.rlskit_run_btn.setEnabled(False)
        self.pages.rlskit.rlskit_upload_progress.setRange(0, 100)
        self.pages.rlskit.rlskit_upload_progress.setValue(0)
        self.pages.rlskit.rlskit_upload_status.setText("准备打包...")
        self._rlskit_run_ctx = (src, raw_ver, ftp_user, ftp_pass)
        self._rlskit_worker = RLskitWorker(
            src, suffix, ftp_url, ftp_user, ftp_pass, parent=self.window
        )
        self._rlskit_worker.line.connect(
            lambda text: self._log_append(self.pages.rlskit.rlskit_log, text)
        )
        self._rlskit_worker.upload_progress.connect(self._on_rlskit_upload_progress)
        self._rlskit_worker.finished_ok.connect(self._on_rlskit_done)
        self._rlskit_worker.failed.connect(self._on_rlskit_failed)
        self._rlskit_worker.cancelled.connect(self._on_rlskit_cancelled)
        self._rlskit_worker.start()

    def _on_rlskit_done(self, result):
        src, raw_ver, ftp_user, ftp_pass = self._rlskit_run_ctx
        self.pages.rlskit.rlskit_run_btn.setEnabled(True)
        self.pages.rlskit.rlskit_cancel_btn.setEnabled(False)
        if result.cksum:
            self.rlskit_cksum = result.cksum
            self.window.statusBar().showMessage(f"cksum: {result.cksum}")
            self.pages.rlskit.rlskit_copy_btn.setEnabled(True)
        self._save_config()
        if result.upload_ok:
            self.pages.rlskit.rlskit_upload_progress.setValue(100)
            self.pages.rlskit.rlskit_upload_status.setText("上传完成")
            self.config.save_rlskit_upload_history(
                src, result.tar_file, result.target_url, raw_ver
            )
        elif result.upload_skipped:
            self.pages.rlskit.rlskit_upload_status.setText("远端已存在")
            answer = QtWidgets.QMessageBox.question(
                self.window,
                "远端文件已存在",
                f"FTP 上已经存在同名文件：\n{result.target_url}\n\n是否覆盖？",
                QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No,
                QtWidgets.QMessageBox.No,
            )
            if answer == QtWidgets.QMessageBox.Yes:
                self._start_rlskit_overwrite(
                    result.tar_file, result.target_url, ftp_user, ftp_pass
                )
        elif result.upload_attempted:
            self.pages.rlskit.rlskit_upload_status.setText("上传失败")
        else:
            self.pages.rlskit.rlskit_upload_status.setText("未上传")

    def _start_rlskit_overwrite(self, tar_file, target_url, ftp_user, ftp_pass):
        self.pages.rlskit.rlskit_run_btn.setEnabled(False)
        self.pages.rlskit.rlskit_upload_progress.setRange(0, 100)
        self.pages.rlskit.rlskit_upload_progress.setValue(0)
        self.pages.rlskit.rlskit_upload_status.setText("准备覆盖...")
        self._rlskit_worker = RLskitUploadWorker(
            tar_file, target_url, ftp_user, ftp_pass, parent=self.window
        )
        self._rlskit_worker.line.connect(
            lambda text: self._log_append(self.pages.rlskit.rlskit_log, text)
        )
        self._rlskit_worker.upload_progress.connect(self._on_rlskit_upload_progress)
        self._rlskit_worker.finished_ok.connect(self._on_rlskit_overwrite_done)
        self._rlskit_worker.failed.connect(self._on_rlskit_failed)
        self._rlskit_worker.cancelled.connect(self._on_rlskit_cancelled)
        self._rlskit_worker.start()

    def _on_rlskit_overwrite_done(self, result):
        self.pages.rlskit.rlskit_run_btn.setEnabled(True)
        self.pages.rlskit.rlskit_cancel_btn.setEnabled(False)
        if result.upload_ok:
            src, raw_ver, _, _ = self._rlskit_run_ctx
            self.pages.rlskit.rlskit_upload_progress.setValue(100)
            self.pages.rlskit.rlskit_upload_status.setText("覆盖完成")
            self.config.save_rlskit_upload_history(
                src, result.tar_file, result.target_url, raw_ver
            )
        else:
            self.pages.rlskit.rlskit_upload_status.setText("覆盖失败")

    def _on_rlskit_upload_progress(self, current, total):
        self.pages.rlskit.rlskit_cancel_btn.setEnabled(True)
        if total <= 0:
            self.pages.rlskit.rlskit_upload_progress.setRange(0, 0)
            self.pages.rlskit.rlskit_upload_status.setText("正在上传...")
            return
        if self.pages.rlskit.rlskit_upload_progress.maximum() == 0:
            self.pages.rlskit.rlskit_upload_progress.setRange(0, 100)
        percent = min(100, int(current * 100 / total))
        self.pages.rlskit.rlskit_upload_progress.setValue(percent)
        self.pages.rlskit.rlskit_upload_status.setText(
            f"上传中 {current / 1048576:.1f}/{total / 1048576:.1f} MB"
        )

    def _cancel_rlskit_upload(self):
        worker = self._rlskit_worker
        if worker is None or not worker.isRunning():
            return
        worker.requestInterruption()
        self.pages.rlskit.rlskit_cancel_btn.setEnabled(False)
        self.pages.rlskit.rlskit_upload_status.setText("正在取消...")

    def _on_rlskit_cancelled(self):
        self.pages.rlskit.rlskit_run_btn.setEnabled(True)
        self.pages.rlskit.rlskit_cancel_btn.setEnabled(False)
        self.pages.rlskit.rlskit_upload_status.setText("上传已取消")
        self._log_append(self.pages.rlskit.rlskit_log, "\n[已取消] 上传任务已停止。\n")

    def _on_rlskit_failed(self, message):
        self.pages.rlskit.rlskit_run_btn.setEnabled(True)
        self.pages.rlskit.rlskit_cancel_btn.setEnabled(False)
        self.pages.rlskit.rlskit_upload_progress.setRange(0, 100)
        if self.pages.rlskit.rlskit_upload_status.text().startswith("上传"):
            self.pages.rlskit.rlskit_upload_status.setText("上传失败")
        else:
            self.pages.rlskit.rlskit_upload_status.setText("执行失败")
        self._log_append(self.pages.rlskit.rlskit_log, f"\n[错误] {message}\n")

    def _postsim_browse_dir(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(self.window, "选择搜索目录")
        if path:
            self.pages.postsim.postsim_dir_edit.setText(path)

    def _postsim_debounce(self):
        self._postsim_timer.start()

    def _postsim_search(self):
        self.pages.postsim.postsim_list.clear()
        dir_path = self.pages.postsim.postsim_dir_edit.text().strip()
        pattern = self.pages.postsim.postsim_pattern_edit.text().strip()
        if not dir_path or not os.path.isdir(dir_path):
            self.pages.postsim.postsim_stats_label.setText(
                "匹配文件数：0 (请选择有效目录)"
            )
            self.window.statusBar().showMessage("后仿: 目录无效")
            return
        try:
            matched = core.search_postsim_files(dir_path, pattern)
        except OSError as e:
            self.pages.postsim.postsim_stats_label.setText(f"搜索出错: {e}")
            return
        for fp in matched:
            rel = os.path.relpath(fp, dir_path)
            item = QtWidgets.QListWidgetItem(rel)
            item.setData(QtCore.Qt.UserRole, fp)
            self.pages.postsim.postsim_list.addItem(item)
        self.pages.postsim.postsim_stats_label.setText(f"匹配文件数：{len(matched)}")
        self.window.statusBar().showMessage(f"后仿: 找到 {len(matched)} 个文件")

    def _postsim_analyze_item(self, item):
        self._postsim_analyze(item.data(QtCore.Qt.UserRole))

    def _postsim_analyze_selected(self):
        items = self.pages.postsim.postsim_list.selectedItems()
        if not items:
            QtWidgets.QMessageBox.information(
                self.window, "提示", "请先选择要分析的文件。"
            )
            return
        self._postsim_analyze(items[0].data(QtCore.Qt.UserRole))

    def _postsim_analyze(self, file_path):
        try:
            results = core.analyze_timing_violations(file_path)
        except core.EmptyFileError:
            QtWidgets.QMessageBox.warning(
                self.window, "提示", f"文件为空或不存在:\n{file_path}"
            )
            return
        except core.UnknownEncodingError:
            QtWidgets.QMessageBox.critical(
                self.window, "错误", f"无法识别文件编码:\n{file_path}"
            )
            return
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            QtWidgets.QMessageBox.critical(self.window, "分析失败", str(e))
            return
        dlg = TimingViolationDialog(file_path, results, self.window)
        dlg.exec_()
