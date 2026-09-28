"""fizz Qt main window -- 合并 / VCS Protect / Obfuscator / RLskit / 后仿分析."""

import os
import subprocess

from PyQt5 import QtCore, QtGui, QtWidgets

from fizz import core
from fizz.frontend.qt.widgets.theme import VisibleCheckBox
from fizz.frontend.qt.widgets.preferences_dialog import PreferencesDialog
from fizz.frontend.qt.widgets.ftp_browser import FtpBrowserDialog
from fizz.frontend.qt.widgets.history_dialog import RLskitHistoryDialog
from fizz.frontend.qt.widgets.postsim_dialog import TimingViolationDialog
from fizz.frontend.qt.widgets.whitelist_dialog import WhitelistDialog
from fizz.frontend.qt.workers import MergeWorker, LineStreamWorker

ABOUT_TEXT = (
    "fizz 工具功能说明\n\n"
    "1. 合并\n"
    "- 从 generalMessage.txt 提取 included/source file 并按顺序合并\n"
    "- 支持过滤目录/文件、注释 include、可选 strip-comments、protect 插桩\n\n"
    "2. VCS Protect\n"
    "- 调用 vcs -ipprotect 对源文件做加密保护\n\n"
    "3. Obfuscator\n"
    "- 调用 verible-verilog-obfuscate 做混淆\n"
    "- 支持 load_map/save_map\n\n"
    "4. RLskit\n"
    "- 目录复制、打包 tar.gz、计算 cksum、可选 FTP 上传\n"
    "- 支持 FTP 目录浏览与 Release Note 编辑\n\n"
    "5. 后仿分析\n"
    "- 递归搜索日志文件，提取 Timing violation 并支持 waive"
)


def _group(title):
    box = QtWidgets.QGroupBox(title)
    return box


class MainWindow(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = core.FizzConfig()
        self.script_dir = os.getcwd()

        self.included_files = []
        self.source_files = []
        self._raw_included_files = []
        self._raw_source_files = []
        self.rlskit_cksum = ""

        self._merge_worker = None
        self._obf_worker = None
        self._vcs_worker = None
        self._rlskit_worker = None

        self._rlskit_src_timer = QtCore.QTimer(self, singleShot=True, interval=500)
        self._rlskit_src_timer.timeout.connect(self._do_rlskit_src_changed)

        self._postsim_timer = QtCore.QTimer(self, singleShot=True, interval=300)
        self._postsim_timer.timeout.connect(self._postsim_search)

        self.setWindowTitle("fizz - 文件合并工具")
        self.resize(885, 650)
        self.setMinimumSize(500, 400)
        self._center_on_screen()

        self._build_menu()

        self.tabs = QtWidgets.QTabWidget()
        self.tabs.addTab(self._build_merge_tab(), "合并")
        self.tabs.addTab(self._build_vcs_tab(), "VCS Protect")
        self.tabs.addTab(self._build_obf_tab(), "Obfuscator")
        self.tabs.addTab(self._build_rlskit_tab(), "RLskit")
        self.tabs.addTab(self._build_postsim_tab(), "后仿分析")
        self.setCentralWidget(self.tabs)

        self.statusBar().showMessage("就绪")

        self.config.ensure_exists()
        self._load_config()
        self._set_defaults()

        self.rlskit_src_edit.textChanged.connect(self._on_rlskit_src_changed)
        self.rlskit_suffix_edit.textChanged.connect(self._update_rlskit_preview)
        self.postsim_dir_edit.textChanged.connect(self._postsim_debounce)
        self.postsim_pattern_edit.textChanged.connect(self._postsim_debounce)
        QtCore.QTimer.singleShot(500, self._postsim_search)

    def _center_on_screen(self):
        geo = self.frameGeometry()
        center = QtWidgets.QApplication.primaryScreen().availableGeometry().center()
        geo.moveCenter(center)
        self.move(geo.topLeft())

    # ------------------------------------------------------------------
    # 菜单 / 关于 / 配置
    # ------------------------------------------------------------------
    def _build_menu(self):
        menubar = self.menuBar()

        file_menu = menubar.addMenu("File")
        pref_action = file_menu.addAction("preference...")
        pref_action.setShortcut("Ctrl+P")
        pref_action.triggered.connect(self._open_preferences_dialog)
        file_menu.addSeparator()
        exit_action = file_menu.addAction("退出")
        exit_action.triggered.connect(self.close)

        help_menu = menubar.addMenu("Help")
        about_action = help_menu.addAction("关于 fizz")
        about_action.triggered.connect(self._show_about)

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
            "exclude_dirs": self.dir_filter_edit.text(),
            "exclude_files": self.file_filter_edit.text(),
            "vcs_key_file": self.vcs_key_edit.text(),
            "vcs_options": self.vcs_opt_edit.text(),
            "obfuscator_path": self.obf_tool_edit.text(),
            "ftp_url": self.rlskit_ftp_url_edit.text(),
            "ftp_username": self.rlskit_ftp_user_edit.text(),
            "ftp_password": self.rlskit_ftp_pass_edit.text(),
        }
        dlg = PreferencesDialog(values, self._dialog_initial_dir, self)
        if dlg.exec_() != QtWidgets.QDialog.Accepted:
            return

        new_values = dlg.values()
        self.dir_filter_edit.setText(new_values["exclude_dirs"])
        self.file_filter_edit.setText(new_values["exclude_files"])
        self.vcs_key_edit.setText(new_values["vcs_key_file"])
        self.vcs_opt_edit.setText(new_values["vcs_options"])
        self.obf_tool_edit.setText(new_values["obfuscator_path"])
        self.rlskit_ftp_url_edit.setText(new_values["ftp_url"])
        self.rlskit_ftp_user_edit.setText(new_values["ftp_username"])
        self.rlskit_ftp_pass_edit.setText(new_values["ftp_password"])
        self._save_config()
        self.statusBar().showMessage("配置已保存")
        if dlg.action == "open":
            self._open_config_file()

    def _open_config_file(self):
        self.config.ensure_exists()
        try:
            subprocess.Popen(["gvim", self.config.path])
        except FileNotFoundError:
            QtWidgets.QMessageBox.critical(self, "错误", "未找到 gvim 命令，请确认 gvim 已安装并在 PATH 中。")
        except OSError as e:
            QtWidgets.QMessageBox.critical(self, "错误", f"打开配置文件失败:\n{e}")

    def _show_about(self):
        dlg = QtWidgets.QDialog(self)
        dlg.setWindowTitle("about fizz")
        dlg.resize(int(self.width() * 0.7), int(self.height() * 0.6))
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
        dlg.exec_()

    def _load_config(self):
        data = self.config.load()
        self.dir_filter_edit.setText(data["exclude_dirs"])
        self.file_filter_edit.setText(data["exclude_files"])
        self.vcs_key_edit.setText(data["vcs_key_file"])
        self.vcs_opt_edit.setText(data["vcs_options"] or core.DEFAULT_VCS_OPTIONS)
        self.obf_tool_edit.setText(data["obfuscator_path"] or core.DEFAULT_OBF_TOOL)
        self.obf_whitelist_edit.setText(data["whitelist_file"])
        self.rlskit_ftp_url_edit.setText(data["ftp_url"])
        self.rlskit_ftp_user_edit.setText(data["ftp_username"])
        self.rlskit_ftp_pass_edit.setText(data["ftp_password"])
        if data["last_version"]:
            self.rlskit_suffix_edit.setText(data["last_version"])

    def _save_config(self):
        self.config.save({
            "exclude_dirs": self.dir_filter_edit.text(),
            "exclude_files": self.file_filter_edit.text(),
            "vcs_key_file": self.vcs_key_edit.text(),
            "vcs_options": self.vcs_opt_edit.text(),
            "obfuscator_path": self.obf_tool_edit.text(),
            "whitelist_file": self.obf_whitelist_edit.text(),
            "ftp_url": self.rlskit_ftp_url_edit.text(),
            "ftp_username": self.rlskit_ftp_user_edit.text(),
            "ftp_password": self.rlskit_ftp_pass_edit.text(),
            "last_version": self.rlskit_suffix_edit.text(),
        })

    def _set_defaults(self):
        default_msg = os.path.join(self.script_dir, "generalMessage.txt")
        self.msg_path_edit.setText(default_msg)
        self.out_path_edit.setText(os.path.join(self.script_dir, "one.sv"))

        if os.path.isdir(self.script_dir):
            self.rlskit_src_edit.setText(self.script_dir)

        self.vcs_src_edit.setText(os.path.join(self.script_dir, "one.sv"))

        pciegen = os.environ.get("PCIEGEN", "")
        if pciegen and not self.vcs_key_edit.text().strip():
            self.vcs_key_edit.setText(os.path.join(pciegen, "sim2-key.txt"))

        if os.path.isfile(default_msg):
            self._parse()

        self.obf_src_edit.setText(os.path.join(self.script_dir, "one.sv"))

    # ------------------------------------------------------------------
    # 合并
    # ------------------------------------------------------------------
    def _build_merge_tab(self):
        widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(widget)

        msg_group = _group("消息文件 (generalMessage.txt)")
        msg_row = QtWidgets.QHBoxLayout(msg_group)
        self.msg_path_edit = QtWidgets.QLineEdit()
        browse_msg_btn = QtWidgets.QPushButton("浏览...")
        browse_msg_btn.clicked.connect(self._browse_msg)
        parse_btn = QtWidgets.QPushButton("解析")
        parse_btn.clicked.connect(self._parse)
        msg_row.addWidget(self.msg_path_edit, 1)
        msg_row.addWidget(browse_msg_btn)
        msg_row.addWidget(parse_btn)

        filter_group = _group("过滤规则 (通配, 逗号/分号分隔)")
        filter_layout = QtWidgets.QVBoxLayout(filter_group)
        dir_row = QtWidgets.QHBoxLayout()
        dir_row.addWidget(QtWidgets.QLabel("排除目录:"))
        self.dir_filter_edit = QtWidgets.QLineEdit()
        dir_row.addWidget(self.dir_filter_edit, 1)
        file_row = QtWidgets.QHBoxLayout()
        file_row.addWidget(QtWidgets.QLabel("排除文件:"))
        self.file_filter_edit = QtWidgets.QLineEdit()
        file_row.addWidget(self.file_filter_edit, 1)
        refilter_btn = QtWidgets.QPushButton("重新过滤")
        refilter_btn.clicked.connect(self._apply_filter)
        file_row.addWidget(refilter_btn)
        filter_layout.addLayout(dir_row)
        filter_layout.addLayout(file_row)

        list_group = _group("文件列表")
        list_layout = QtWidgets.QVBoxLayout(list_group)
        self.file_listwidget = QtWidgets.QListWidget()
        self.file_listwidget.setSelectionMode(QtWidgets.QAbstractItemView.ExtendedSelection)
        self.file_listwidget.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.file_listwidget.customContextMenuRequested.connect(self._file_list_context_menu)
        list_layout.addWidget(self.file_listwidget)

        out_group = _group("输出")
        out_layout = QtWidgets.QVBoxLayout(out_group)
        out_row = QtWidgets.QHBoxLayout()
        out_row.addWidget(QtWidgets.QLabel("输出文件:"))
        self.out_path_edit = QtWidgets.QLineEdit()
        out_row.addWidget(self.out_path_edit, 1)
        browse_out_btn = QtWidgets.QPushButton("浏览...")
        browse_out_btn.clicked.connect(self._browse_out)
        out_row.addWidget(browse_out_btn)

        protect_row = QtWidgets.QHBoxLayout()
        self.protect_check = VisibleCheckBox("protect")
        protect_row.addWidget(self.protect_check)
        protect_row.addWidget(QtWidgets.QLabel("top module file:"))
        self.top_file_edit = QtWidgets.QLineEdit(core.DEFAULT_TOP_FILE)
        protect_row.addWidget(self.top_file_edit)
        protect_row.addStretch(1)

        action_row = QtWidgets.QHBoxLayout()
        self.strip_comments_check = VisibleCheckBox("verible strip-comments")
        action_row.addWidget(self.strip_comments_check)
        action_row.addStretch(1)
        self.merge_btn = QtWidgets.QPushButton("合并")
        self.merge_btn.setObjectName("primaryBtn")
        self.merge_btn.clicked.connect(self._merge)
        action_row.addWidget(self.merge_btn)

        self.merge_progress = QtWidgets.QProgressBar()
        self.merge_status_label = QtWidgets.QLabel("就绪")

        out_layout.addLayout(out_row)
        out_layout.addLayout(protect_row)
        out_layout.addLayout(action_row)
        out_layout.addWidget(self.merge_progress)
        out_layout.addWidget(self.merge_status_label)

        layout.addWidget(msg_group)
        layout.addWidget(filter_group)
        layout.addWidget(list_group, 1)
        layout.addWidget(out_group)
        return widget

    def _browse_msg(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择消息文件", self.script_dir, "Text files (*.txt);;All files (*.*)",
        )
        if path:
            self.msg_path_edit.setText(path)

    def _browse_out(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "保存合并结果", self.script_dir,
            "SystemVerilog (*.sv);;Verilog (*.v);;Text (*.txt);;All (*.*)",
        )
        if path:
            self.out_path_edit.setText(path)

    def _parse(self):
        msg_path = self.msg_path_edit.text().strip()
        if not msg_path:
            QtWidgets.QMessageBox.warning(self, "提示", "请先选择消息文件。")
            return
        if not os.path.isfile(msg_path):
            QtWidgets.QMessageBox.critical(self, "错误", f"文件不存在:\n{msg_path}")
            return

        try:
            inc, src = core.parse_general_message(msg_path)
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, "错误", f"读取文件失败:\n{e}")
            return

        self._raw_included_files = inc
        self._raw_source_files = src

        dir_text = self.dir_filter_edit.text()
        file_text = self.file_filter_edit.text()
        if core.split_patterns(dir_text) or core.split_patterns(file_text):
            self.included_files = core.filter_files(inc, dir_text, file_text)
            self.source_files = core.filter_files(src, dir_text, file_text)
            self._refresh_list()
            self.merge_status_label.setText(
                f"解析完成: included {len(inc)}->{len(self.included_files)}, "
                f"source {len(src)}->{len(self.source_files)}"
            )
        else:
            self.included_files = list(inc)
            self.source_files = list(src)
            self._refresh_list()
            self.merge_status_label.setText(
                f"解析完成: included={len(inc)}, source={len(src)}"
            )

    def _apply_filter(self):
        if not self._raw_included_files and not self._raw_source_files:
            self._parse()
            return
        dir_text = self.dir_filter_edit.text()
        file_text = self.file_filter_edit.text()
        self.included_files = core.filter_files(self._raw_included_files, dir_text, file_text)
        self.source_files = core.filter_files(self._raw_source_files, dir_text, file_text)
        self._refresh_list()
        self.merge_status_label.setText(
            f"过滤后: included {len(self._raw_included_files)}->{len(self.included_files)}, "
            f"source {len(self._raw_source_files)}->{len(self.source_files)}"
        )

    def _refresh_list(self):
        self.file_listwidget.clear()
        self.file_listwidget.addItems(self.included_files)
        self.file_listwidget.addItems(self.source_files)

    def _file_list_context_menu(self, pos):
        menu = QtWidgets.QMenu(self)
        menu.addAction("复制路径", self._file_list_copy)
        menu.addSeparator()
        menu.addAction("全选 (Ctrl+A)", self.file_listwidget.selectAll)
        menu.addAction("取消全选", self.file_listwidget.clearSelection)
        menu.addAction("反选", self._file_list_invert)
        menu.exec_(self.file_listwidget.mapToGlobal(pos))

    def _file_list_copy(self):
        paths = [item.text() for item in self.file_listwidget.selectedItems()]
        if paths:
            QtWidgets.QApplication.clipboard().setText("\n".join(paths))
            self.statusBar().showMessage(f"已复制 {len(paths)} 个路径到剪贴板")

    def _file_list_invert(self):
        for i in range(self.file_listwidget.count()):
            item = self.file_listwidget.item(i)
            item.setSelected(not item.isSelected())

    def _merge(self):
        all_files = list(self.included_files) + list(self.source_files)
        if not all_files:
            QtWidgets.QMessageBox.warning(self, "提示", "没有要合并的文件。")
            return
        out_path = self.out_path_edit.text().strip()
        if not out_path:
            QtWidgets.QMessageBox.warning(self, "提示", "请指定输出文件路径。")
            return

        msg_dir = os.path.dirname(os.path.abspath(self.msg_path_edit.text()))
        protect = self.protect_check.isChecked()
        top_name = self.top_file_edit.text().strip()
        strip = self.strip_comments_check.isChecked()

        self.merge_progress.setMaximum(len(all_files))
        self.merge_progress.setValue(0)
        self.merge_btn.setEnabled(False)
        self.merge_status_label.setText("合并中...")

        self._merge_worker = MergeWorker(all_files, out_path, msg_dir, self.script_dir, protect, top_name, strip, self)
        self._merge_worker.progress.connect(lambda i, t: self.merge_progress.setValue(i))
        self._merge_worker.finished_ok.connect(lambda result: self._on_merge_done(result, out_path, len(all_files)))
        self._merge_worker.failed.connect(self._on_merge_failed)
        self._merge_worker.start()

    def _on_merge_done(self, result, out_path, total):
        self.merge_progress.setValue(total)
        self.merge_btn.setEnabled(True)
        if result.missing:
            self.merge_status_label.setText(
                f"合并完成 (缺 {len(result.missing)} 个): {total} 个文件, "
                f"{result.merged_lines} 行 → {os.path.basename(out_path)}"
            )
        else:
            self.merge_status_label.setText(
                f"合并完成: {total} 个文件, {result.merged_lines} 行 → {os.path.basename(out_path)}"
            )

    def _on_merge_failed(self, message):
        self.merge_btn.setEnabled(True)
        self.merge_status_label.setText("合并失败")
        QtWidgets.QMessageBox.critical(self, "错误", f"写入输出文件失败:\n{message}")

    # ------------------------------------------------------------------
    # VCS Protect
    # ------------------------------------------------------------------
    def _build_vcs_tab(self):
        widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(widget)

        src_group = _group("源文件")
        src_row = QtWidgets.QHBoxLayout(src_group)
        self.vcs_src_edit = QtWidgets.QLineEdit()
        browse_src_btn = QtWidgets.QPushButton("浏览...")
        browse_src_btn.clicked.connect(self._browse_vcs_src)
        src_row.addWidget(self.vcs_src_edit, 1)
        src_row.addWidget(browse_src_btn)

        key_group = _group("密钥文件 (-ipprotect)")
        key_row = QtWidgets.QHBoxLayout(key_group)
        self.vcs_key_edit = QtWidgets.QLineEdit()
        browse_key_btn = QtWidgets.QPushButton("浏览...")
        browse_key_btn.clicked.connect(self._browse_vcs_key)
        key_row.addWidget(self.vcs_key_edit, 1)
        key_row.addWidget(browse_key_btn)

        opt_group = _group("选项")
        opt_layout = QtWidgets.QVBoxLayout(opt_group)
        self.vcs_opt_edit = QtWidgets.QLineEdit(core.DEFAULT_VCS_OPTIONS)
        opt_layout.addWidget(self.vcs_opt_edit)

        run_row = QtWidgets.QHBoxLayout()
        run_row.addStretch(1)
        clear_btn = QtWidgets.QPushButton("清除日志")
        self.vcs_run_btn = QtWidgets.QPushButton("执行 VCS Protect")
        self.vcs_run_btn.setObjectName("primaryBtn")
        self.vcs_run_btn.clicked.connect(self._run_vcs)
        run_row.addWidget(clear_btn)
        run_row.addWidget(self.vcs_run_btn)

        log_group = _group("输出日志")
        log_layout = QtWidgets.QVBoxLayout(log_group)
        self.vcs_log = QtWidgets.QTextEdit()
        self.vcs_log.setReadOnly(True)
        self.vcs_log.setFont(QtGui.QFont("Consolas", 9))
        log_layout.addWidget(self.vcs_log)
        clear_btn.clicked.connect(self.vcs_log.clear)

        layout.addWidget(src_group)
        layout.addWidget(key_group)
        layout.addWidget(opt_group)
        layout.addLayout(run_row)
        layout.addWidget(log_group, 1)
        return widget

    def _browse_vcs_src(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择源文件", self.script_dir, "SystemVerilog (*.sv);;Verilog (*.v);;All (*.*)",
        )
        if path:
            self.vcs_src_edit.setText(path)

    def _browse_vcs_key(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择密钥文件", self._dialog_initial_dir(self.vcs_key_edit.text()),
            "Text files (*.txt);;All (*.*)",
        )
        if path:
            self.vcs_key_edit.setText(path)

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
        src_path = os.path.expanduser(self.vcs_src_edit.text().strip())
        key_path = os.path.expanduser(self.vcs_key_edit.text().strip())
        opts = self.vcs_opt_edit.text().strip()

        if not src_path:
            QtWidgets.QMessageBox.warning(self, "提示", "请选择源文件。")
            return
        if not os.path.isfile(src_path):
            QtWidgets.QMessageBox.critical(self, "错误", f"源文件不存在:\n{src_path}")
            return
        if not key_path:
            QtWidgets.QMessageBox.warning(self, "提示", "请选择密钥文件。")
            return
        if not os.path.isfile(key_path):
            QtWidgets.QMessageBox.critical(self, "错误", f"密钥文件不存在:\n{key_path}")
            return

        cmd_preview = ["vcs", "-ipprotect", key_path] + opts.split() + [src_path]
        self._log_append(self.vcs_log, f"> {' '.join(cmd_preview)}\n\n")
        self.vcs_run_btn.setEnabled(False)

        self._vcs_worker = LineStreamWorker(
            core.run_vcs_protect, src_path, key_path, opts,
            not_found_message="找不到 vcs 命令，请确认 VCS 已安装且在 PATH 中。", parent=self,
        )
        self._vcs_worker.line.connect(lambda text: self._log_append(self.vcs_log, text))
        self._vcs_worker.finished_ok.connect(self._on_vcs_done)
        self._vcs_worker.failed.connect(self._on_vcs_failed)
        self._vcs_worker.start()

    def _on_vcs_done(self, returncode):
        self._log_append(self.vcs_log, f"\n--- VCS 退出码: {returncode} ---\n")
        self.vcs_run_btn.setEnabled(True)

    def _on_vcs_failed(self, message):
        self._log_append(self.vcs_log, f"\n[错误] {message}\n")
        self.vcs_run_btn.setEnabled(True)

    # ------------------------------------------------------------------
    # Obfuscator
    # ------------------------------------------------------------------
    def _build_obf_tab(self):
        widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(widget)

        src_group = _group("源文件")
        src_row = QtWidgets.QHBoxLayout(src_group)
        self.obf_src_edit = QtWidgets.QLineEdit()
        self.obf_src_edit.textChanged.connect(self._update_obf_defaults)
        browse_src_btn = QtWidgets.QPushButton("浏览...")
        browse_src_btn.clicked.connect(self._browse_obf_src)
        src_row.addWidget(self.obf_src_edit, 1)
        src_row.addWidget(browse_src_btn)

        out_group = _group("输出文件")
        out_row = QtWidgets.QHBoxLayout(out_group)
        self.obf_out_edit = QtWidgets.QLineEdit()
        browse_out_btn = QtWidgets.QPushButton("浏览...")
        browse_out_btn.clicked.connect(self._browse_obf_out)
        out_row.addWidget(self.obf_out_edit, 1)
        out_row.addWidget(browse_out_btn)

        map_group = _group("Map 文件")
        map_layout = QtWidgets.QVBoxLayout(map_group)
        load_row = QtWidgets.QHBoxLayout()
        load_row.addWidget(QtWidgets.QLabel("load_map:"))
        self.obf_load_map_edit = QtWidgets.QLineEdit()
        load_row.addWidget(self.obf_load_map_edit, 1)
        browse_load_btn = QtWidgets.QPushButton("浏览...")
        browse_load_btn.clicked.connect(self._browse_obf_load_map)
        load_row.addWidget(browse_load_btn)
        save_row = QtWidgets.QHBoxLayout()
        save_row.addWidget(QtWidgets.QLabel("save_map:"))
        self.obf_save_map_edit = QtWidgets.QLineEdit()
        save_row.addWidget(self.obf_save_map_edit, 1)
        browse_save_btn = QtWidgets.QPushButton("浏览...")
        browse_save_btn.clicked.connect(self._browse_obf_save_map)
        save_row.addWidget(browse_save_btn)
        map_layout.addLayout(load_row)
        map_layout.addLayout(save_row)

        whitelist_group = _group("Token 白名单")
        whitelist_layout = QtWidgets.QVBoxLayout(whitelist_group)
        whitelist_row = QtWidgets.QHBoxLayout()
        whitelist_row.addWidget(QtWidgets.QLabel("白名单文件:"))
        self.obf_whitelist_edit = QtWidgets.QLineEdit()
        whitelist_row.addWidget(self.obf_whitelist_edit, 1)
        browse_whitelist_btn = QtWidgets.QPushButton("浏览...")
        browse_whitelist_btn.clicked.connect(self._browse_obf_whitelist)
        whitelist_row.addWidget(browse_whitelist_btn)
        edit_whitelist_btn = QtWidgets.QPushButton("编辑...")
        edit_whitelist_btn.clicked.connect(self._edit_obf_whitelist)
        whitelist_row.addWidget(edit_whitelist_btn)
        first_obf_row = QtWidgets.QHBoxLayout()
        self.obf_first_check = VisibleCheckBox("首次混淆 (以白名单作为 load_map)")
        first_obf_row.addWidget(self.obf_first_check)
        first_obf_row.addStretch(1)
        whitelist_layout.addLayout(whitelist_row)
        whitelist_layout.addLayout(first_obf_row)

        tool_row = QtWidgets.QHBoxLayout()
        tool_row.addWidget(QtWidgets.QLabel("混淆器:"))
        self.obf_tool_edit = QtWidgets.QLineEdit(core.DEFAULT_OBF_TOOL)
        self.obf_tool_edit.setReadOnly(True)
        tool_row.addWidget(self.obf_tool_edit, 1)

        run_row = QtWidgets.QHBoxLayout()
        run_row.addStretch(1)
        clear_btn = QtWidgets.QPushButton("清除日志")
        self.obf_run_btn = QtWidgets.QPushButton("执行 Obfuscate")
        self.obf_run_btn.setObjectName("primaryBtn")
        self.obf_run_btn.clicked.connect(self._run_obfuscate)
        run_row.addWidget(clear_btn)
        run_row.addWidget(self.obf_run_btn)

        log_group = _group("输出日志")
        log_layout = QtWidgets.QVBoxLayout(log_group)
        self.obf_log = QtWidgets.QTextEdit()
        self.obf_log.setReadOnly(True)
        self.obf_log.setFont(QtGui.QFont("Consolas", 9))
        log_layout.addWidget(self.obf_log)
        clear_btn.clicked.connect(self.obf_log.clear)

        layout.addWidget(src_group)
        layout.addWidget(out_group)
        layout.addWidget(map_group)
        layout.addWidget(whitelist_group)
        layout.addLayout(tool_row)
        layout.addLayout(run_row)
        layout.addWidget(log_group, 1)
        return widget

    def _browse_obf_src(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择源文件", self._dialog_initial_dir(self.obf_src_edit.text()),
            "SystemVerilog (*.sv);;Verilog (*.v);;All (*.*)",
        )
        if path:
            self.obf_src_edit.setText(path)

    def _browse_obf_out(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "保存混淆结果",
            self._dialog_initial_dir(self.obf_out_edit.text() or self.obf_src_edit.text()),
            "SystemVerilog (*.sv);;Verilog (*.v);;All (*.*)",
        )
        if path:
            self.obf_out_edit.setText(path)

    def _browse_obf_load_map(self):
        path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择 load_map 文件",
            self._dialog_initial_dir(self.obf_load_map_edit.text() or self.obf_src_edit.text()),
            "Map (*.map);;All (*.*)",
        )
        if path:
            self.obf_load_map_edit.setText(path)

    def _browse_obf_save_map(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "保存 save_map 文件",
            self._dialog_initial_dir(self.obf_save_map_edit.text() or self.obf_src_edit.text()),
            "Map (*.map);;All (*.*)",
        )
        if path:
            self.obf_save_map_edit.setText(path)

    def _update_obf_defaults(self):
        src = self.obf_src_edit.text().strip()
        if not src:
            return
        d = os.path.dirname(src)
        name, ext = os.path.splitext(os.path.basename(src))
        self.obf_out_edit.setText(os.path.join(d, f"{name}_obf{ext}"))
        self.obf_save_map_edit.setText(os.path.join(d, "restore.map"))

    def _browse_obf_whitelist(self):
        path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "选择白名单文件",
            self._dialog_initial_dir(self.obf_whitelist_edit.text() or core.DEFAULT_WHITELIST_FILE),
            "Map (*.map);;All (*.*)",
        )
        if path:
            self.obf_whitelist_edit.setText(path)

    def _edit_obf_whitelist(self):
        path = self.obf_whitelist_edit.text().strip() or core.DEFAULT_WHITELIST_FILE
        self.obf_whitelist_edit.setText(path)

        dlg = WhitelistDialog(path, self)
        if dlg.exec_() == QtWidgets.QDialog.Accepted:
            self._save_config()
            self.statusBar().showMessage(f"白名单已保存: {os.path.basename(path)}")

    def _run_obfuscate(self):
        src_path = os.path.expanduser(self.obf_src_edit.text().strip())
        out_path = self.obf_out_edit.text().strip()
        save_map = self.obf_save_map_edit.text().strip()
        tool_bin = self.obf_tool_edit.text().strip() or core.DEFAULT_OBF_TOOL
        first_obf = self.obf_first_check.isChecked()

        if not src_path or not os.path.isfile(src_path):
            QtWidgets.QMessageBox.critical(self, "错误", f"源文件不存在:\n{src_path}")
            return
        if not out_path:
            QtWidgets.QMessageBox.warning(self, "提示", "请指定输出文件。")
            return

        if first_obf:
            load_map = self.obf_whitelist_edit.text().strip()
            if not load_map or not os.path.isfile(load_map):
                QtWidgets.QMessageBox.warning(self, "提示", "请先编辑并保存白名单文件。")
                return
        else:
            load_map = self.obf_load_map_edit.text().strip()

        self._log_append(self.obf_log, f"> {tool_bin} < {src_path}\n\n")
        if first_obf:
            self._log_append(self.obf_log, f"  (首次混淆: 以白名单 {load_map} 作为 load_map)\n\n")
        self.obf_run_btn.setEnabled(False)
        self._save_config()

        self._obf_worker = LineStreamWorker(
            core.run_obfuscate, src_path, out_path, save_map, load_map, tool_bin,
            not_found_message=f"找不到 {tool_bin}，请确认工具路径正确且可执行。", parent=self,
        )
        self._obf_worker.line.connect(lambda text: self._log_append(self.obf_log, text))
        self._obf_worker.finished_ok.connect(lambda rc: self._on_obf_done(rc, tool_bin, first_obf, save_map))
        self._obf_worker.failed.connect(self._on_obf_failed)
        self._obf_worker.start()

    def _on_obf_done(self, returncode, tool_bin, first_obf, save_map):
        name = os.path.basename(tool_bin)
        if returncode != 0:
            self._log_append(self.obf_log, f"\n[错误] {name} 退出码: {returncode}\n")
        else:
            self._log_append(self.obf_log, f"\n--- {name} 完成 ---\n")
            if first_obf and save_map:
                self.obf_first_check.setChecked(False)
                self.obf_load_map_edit.setText(save_map)
                self._save_config()
                self._log_append(
                    self.obf_log,
                    f"  (白名单已并入 {save_map}；后续混淆将从这份 map 继续，已自动取消勾选“首次混淆”)\n",
                )
        self.obf_run_btn.setEnabled(True)

    def _on_obf_failed(self, message):
        self._log_append(self.obf_log, f"\n[错误] {message}\n")
        self.obf_run_btn.setEnabled(True)

    # ------------------------------------------------------------------
    # RLskit
    # ------------------------------------------------------------------
    def _build_rlskit_tab(self):
        widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(widget)

        src_group = _group("源目录")
        src_row = QtWidgets.QHBoxLayout(src_group)
        self.rlskit_src_edit = QtWidgets.QLineEdit()
        browse_src_btn = QtWidgets.QPushButton("浏览...")
        browse_src_btn.clicked.connect(self._browse_rlskit_src)
        src_row.addWidget(self.rlskit_src_edit, 1)
        src_row.addWidget(browse_src_btn)

        ver_group = _group("版本号")
        ver_layout = QtWidgets.QVBoxLayout(ver_group)
        v_row = QtWidgets.QHBoxLayout()
        v_row.addWidget(QtWidgets.QLabel("版本号:"))
        self.rlskit_suffix_edit = QtWidgets.QLineEdit(core.DEFAULT_VERSION)
        v_row.addWidget(self.rlskit_suffix_edit)
        v_row.addStretch(1)
        pv_row = QtWidgets.QHBoxLayout()
        pv_row.addWidget(QtWidgets.QLabel("→"))
        self.rlskit_dst_edit = QtWidgets.QLineEdit()
        self.rlskit_dst_edit.setReadOnly(True)
        pv_row.addWidget(self.rlskit_dst_edit, 1)
        ver_layout.addLayout(v_row)
        ver_layout.addLayout(pv_row)

        ftp_group = _group("FTP 上传")
        ftp_layout = QtWidgets.QVBoxLayout(ftp_group)
        f_row1 = QtWidgets.QHBoxLayout()
        f_row1.addWidget(QtWidgets.QLabel("URL:"))
        self.rlskit_ftp_url_edit = QtWidgets.QLineEdit()
        f_row1.addWidget(self.rlskit_ftp_url_edit, 1)
        browse_ftp_btn = QtWidgets.QPushButton("浏览FTP...")
        browse_ftp_btn.clicked.connect(self._browse_ftp)
        f_row1.addWidget(browse_ftp_btn)
        f_row2 = QtWidgets.QHBoxLayout()
        f_row2.addWidget(QtWidgets.QLabel("用户:"))
        self.rlskit_ftp_user_edit = QtWidgets.QLineEdit()
        f_row2.addWidget(self.rlskit_ftp_user_edit)
        f_row2.addWidget(QtWidgets.QLabel("密码:"))
        self.rlskit_ftp_pass_edit = QtWidgets.QLineEdit()
        self.rlskit_ftp_pass_edit.setEchoMode(QtWidgets.QLineEdit.Password)
        f_row2.addWidget(self.rlskit_ftp_pass_edit)
        ftp_layout.addLayout(f_row1)
        ftp_layout.addLayout(f_row2)

        run_row = QtWidgets.QHBoxLayout()
        self.rlskit_copy_btn = QtWidgets.QPushButton("cksum copy")
        self.rlskit_copy_btn.setEnabled(False)
        self.rlskit_copy_btn.clicked.connect(self._copy_cksum)
        run_row.addWidget(self.rlskit_copy_btn)
        run_row.addStretch(1)
        history_btn = QtWidgets.QPushButton("历史")
        history_btn.clicked.connect(self._open_history_view)
        run_row.addWidget(history_btn)
        self.rlskit_run_btn = QtWidgets.QPushButton("执行打包上传")
        self.rlskit_run_btn.setObjectName("primaryBtn")
        self.rlskit_run_btn.clicked.connect(self._run_rlskit)
        run_row.addWidget(self.rlskit_run_btn)

        sub_tabs = QtWidgets.QTabWidget()
        log_tab = QtWidgets.QWidget()
        log_tab_layout = QtWidgets.QVBoxLayout(log_tab)
        self.rlskit_log = QtWidgets.QTextEdit()
        self.rlskit_log.setReadOnly(True)
        self.rlskit_log.setFont(QtGui.QFont("Consolas", 9))
        log_tab_layout.addWidget(self.rlskit_log)
        sub_tabs.addTab(log_tab, "输出日志")

        rn_tab = QtWidgets.QWidget()
        rn_layout = QtWidgets.QVBoxLayout(rn_tab)
        rn_btn_row = QtWidgets.QHBoxLayout()
        rn_refresh_btn = QtWidgets.QPushButton("刷新")
        rn_refresh_btn.clicked.connect(self._load_release_note)
        rn_save_btn = QtWidgets.QPushButton("保存")
        rn_save_btn.clicked.connect(self._save_release_note)
        rn_btn_row.addWidget(rn_refresh_btn)
        rn_btn_row.addWidget(rn_save_btn)
        rn_btn_row.addStretch(1)
        self.rn_text = QtWidgets.QTextEdit()
        self.rn_text.setFont(QtGui.QFont("Consolas", 10))
        rn_save_shortcut = QtWidgets.QShortcut(QtGui.QKeySequence("Ctrl+S"), self.rn_text)
        rn_save_shortcut.setContext(QtCore.Qt.WidgetShortcut)
        rn_save_shortcut.activated.connect(self._save_release_note)
        rn_layout.addLayout(rn_btn_row)
        rn_layout.addWidget(self.rn_text, 1)
        sub_tabs.addTab(rn_tab, "Release Note")

        layout.addWidget(src_group)
        layout.addWidget(ver_group)
        layout.addWidget(ftp_group)
        layout.addLayout(run_row)
        layout.addWidget(sub_tabs, 1)
        return widget

    def _browse_rlskit_src(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(self, "选择源目录", self.script_dir)
        if path:
            self.rlskit_src_edit.setText(path)

    def _browse_ftp(self):
        dlg = FtpBrowserDialog(
            self.rlskit_ftp_url_edit.text().strip(),
            self.rlskit_ftp_user_edit.text().strip(),
            self.rlskit_ftp_pass_edit.text(),
            self,
        )
        if dlg.exec_() == QtWidgets.QDialog.Accepted and dlg.selected_url:
            self.rlskit_ftp_url_edit.setText(dlg.selected_url)

    def _full_suffix(self):
        return core.full_suffix(self.rlskit_suffix_edit.text())

    def _update_rlskit_preview(self):
        src = self.rlskit_src_edit.text().strip()
        suffix = self._full_suffix()
        if src and suffix:
            parent = os.path.dirname(src)
            name = os.path.basename(src)
            self.rlskit_dst_edit.setText(os.path.join(parent, name + suffix))
        else:
            self.rlskit_dst_edit.setText("")

    def _on_rlskit_src_changed(self):
        self._rlskit_src_timer.start()

    def _do_rlskit_src_changed(self):
        self._update_rlskit_preview()
        self._load_release_note()

        src = self.rlskit_src_edit.text().strip()
        if src and os.path.isdir(src):
            values = self.config.load_rlskit_for_dir(src)
            if values:
                if "ftp_url" in values:
                    self.rlskit_ftp_url_edit.setText(values["ftp_url"])
                if "ftp_username" in values:
                    self.rlskit_ftp_user_edit.setText(values["ftp_username"])
                if "ftp_password" in values:
                    self.rlskit_ftp_pass_edit.setText(values["ftp_password"])
                if "last_version" in values:
                    self.rlskit_suffix_edit.setText(values["last_version"])

    def _release_note_path(self):
        return core.release_note_path(self.rlskit_src_edit.text().strip())

    def _load_release_note(self):
        path = self._release_note_path()
        content = core.load_release_note(path) if path else None
        if content is not None:
            self.rn_text.setPlainText(content)
        else:
            self.rn_text.clear()
            if path:
                self.rn_text.setPlainText(f"; 未找到 Release_Note.txt\n; 路径: {path}\n")

    def _save_release_note(self):
        path = self._release_note_path()
        if not path:
            QtWidgets.QMessageBox.warning(self, "提示", "请先在 RLskit 选项卡中选择源目录。")
            return
        core.save_release_note(path, self.rn_text.toPlainText())
        QtWidgets.QMessageBox.information(self, "提示", f"已保存: {os.path.basename(path)}")

    def _copy_cksum(self):
        if not self.rlskit_cksum:
            QtWidgets.QMessageBox.warning(self, "提示", "暂无 cksum 值，请先执行打包。")
            return
        QtWidgets.QApplication.clipboard().setText(self.rlskit_cksum)
        self.statusBar().showMessage(f"cksum 已复制: {self.rlskit_cksum}")
        self.rlskit_copy_btn.setText("Copied")
        QtCore.QTimer.singleShot(800, lambda: self.rlskit_copy_btn.setText("cksum copy"))

    def _open_history_view(self):
        dlg = RLskitHistoryDialog(self.config, self)
        dlg.exec_()

    def _run_rlskit(self):
        src = self.rlskit_src_edit.text().strip()
        suffix = self._full_suffix()
        raw_ver = self.rlskit_suffix_edit.text().strip()
        ftp_url = self.rlskit_ftp_url_edit.text().strip()
        ftp_user = self.rlskit_ftp_user_edit.text().strip()
        ftp_pass = self.rlskit_ftp_pass_edit.text()

        if not src or not os.path.isdir(src):
            QtWidgets.QMessageBox.critical(self, "错误", "请选择有效的源目录。")
            return
        if not suffix:
            QtWidgets.QMessageBox.warning(self, "提示", "请填写版本号。")
            return

        self.rlskit_run_btn.setEnabled(False)
        self._rlskit_run_ctx = (src, raw_ver)

        self._rlskit_worker = LineStreamWorker(
            core.run_rlskit_package, src, suffix, ftp_url, ftp_user, ftp_pass, parent=self,
        )
        self._rlskit_worker.line.connect(lambda text: self._log_append(self.rlskit_log, text))
        self._rlskit_worker.finished_ok.connect(self._on_rlskit_done)
        self._rlskit_worker.failed.connect(self._on_rlskit_failed)
        self._rlskit_worker.start()

    def _on_rlskit_done(self, result):
        src, raw_ver = self._rlskit_run_ctx
        self.rlskit_run_btn.setEnabled(True)
        if result.cksum:
            self.rlskit_cksum = result.cksum
            self.statusBar().showMessage(f"cksum: {result.cksum}")
            self.rlskit_copy_btn.setEnabled(True)
        self._save_config()
        if result.upload_ok:
            self.config.save_rlskit_upload_history(src, result.tar_file, result.target_url, raw_ver)

    def _on_rlskit_failed(self, message):
        self.rlskit_run_btn.setEnabled(True)
        self._log_append(self.rlskit_log, f"\n[错误] {message}\n")

    # ------------------------------------------------------------------
    # 后仿分析
    # ------------------------------------------------------------------
    def _build_postsim_tab(self):
        widget = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(widget)

        dir_group = _group("搜索目录")
        dir_row = QtWidgets.QHBoxLayout(dir_group)
        self.postsim_dir_edit = QtWidgets.QLineEdit(self.script_dir)
        browse_btn = QtWidgets.QPushButton("浏览...")
        browse_btn.clicked.connect(self._postsim_browse_dir)
        dir_row.addWidget(self.postsim_dir_edit, 1)
        dir_row.addWidget(browse_btn)

        pat_group = _group("搜索规则")
        pat_row = QtWidgets.QHBoxLayout(pat_group)
        self.postsim_pattern_edit = QtWidgets.QLineEdit("*.log")
        pat_row.addWidget(self.postsim_pattern_edit, 1)
        pat_row.addWidget(QtWidgets.QLabel("(*.log, test?.txt 等)"))

        preview_group = _group("匹配文件 (双击行分析)")
        preview_layout = QtWidgets.QVBoxLayout(preview_group)
        self.postsim_list = QtWidgets.QListWidget()
        self.postsim_list.itemDoubleClicked.connect(self._postsim_analyze_item)
        preview_layout.addWidget(self.postsim_list)
        analyze_row = QtWidgets.QHBoxLayout()
        analyze_row.addStretch(1)
        analyze_btn = QtWidgets.QPushButton("分析选中")
        analyze_btn.clicked.connect(self._postsim_analyze_selected)
        analyze_row.addWidget(analyze_btn)
        preview_layout.addLayout(analyze_row)

        self.postsim_stats_label = QtWidgets.QLabel("匹配文件数：0")

        layout.addWidget(dir_group)
        layout.addWidget(pat_group)
        layout.addWidget(preview_group, 1)
        layout.addWidget(self.postsim_stats_label)
        return widget

    def _postsim_browse_dir(self):
        path = QtWidgets.QFileDialog.getExistingDirectory(self, "选择搜索目录")
        if path:
            self.postsim_dir_edit.setText(path)

    def _postsim_debounce(self):
        self._postsim_timer.start()

    def _postsim_search(self):
        self.postsim_list.clear()
        dir_path = self.postsim_dir_edit.text().strip()
        pattern = self.postsim_pattern_edit.text().strip()
        if not dir_path or not os.path.isdir(dir_path):
            self.postsim_stats_label.setText("匹配文件数：0 (请选择有效目录)")
            self.statusBar().showMessage("后仿: 目录无效")
            return

        try:
            matched = core.search_postsim_files(dir_path, pattern)
        except OSError as e:
            self.postsim_stats_label.setText(f"搜索出错: {e}")
            return

        for fp in matched:
            rel = os.path.relpath(fp, dir_path)
            item = QtWidgets.QListWidgetItem(rel)
            item.setData(QtCore.Qt.UserRole, fp)
            self.postsim_list.addItem(item)

        self.postsim_stats_label.setText(f"匹配文件数：{len(matched)}")
        self.statusBar().showMessage(f"后仿: 找到 {len(matched)} 个文件")

    def _postsim_analyze_item(self, item):
        self._postsim_analyze(item.data(QtCore.Qt.UserRole))

    def _postsim_analyze_selected(self):
        items = self.postsim_list.selectedItems()
        if not items:
            QtWidgets.QMessageBox.information(self, "提示", "请先选择要分析的文件。")
            return
        self._postsim_analyze(items[0].data(QtCore.Qt.UserRole))

    def _postsim_analyze(self, file_path):
        try:
            results = core.analyze_timing_violations(file_path)
        except core.EmptyFileError:
            QtWidgets.QMessageBox.warning(self, "提示", f"文件为空或不存在:\n{file_path}")
            return
        except core.UnknownEncodingError:
            QtWidgets.QMessageBox.critical(self, "错误", f"无法识别文件编码:\n{file_path}")
            return
        except Exception as e:
            QtWidgets.QMessageBox.critical(self, "分析失败", str(e))
            return

        dlg = TimingViolationDialog(file_path, results, self)
        dlg.exec_()
