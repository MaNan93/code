"""Release packaging, FTP progress and editable release notes."""

from PyQt5 import QtCore, QtGui, QtWidgets

from fizz import core
from fizz.frontend.qt.views.log_panel import LogPanel
from fizz.frontend.qt.views.workflow_page import WorkflowPage
from fizz.frontend.qt.widgets.common import Section, button, icon_button, line_edit


class RLskitPage(WorkflowPage):
    def __init__(self, workflow, controller):
        super().__init__(workflow)
        source = Section("发布目录")
        self.rlskit_src_edit = line_edit(placeholder="选择需要打包的目录")
        source.field(
            "源目录",
            self.rlskit_src_edit,
            icon_button("folder-open", "选择源目录", controller._browse_rlskit_src),
        )
        self.rlskit_suffix_edit = line_edit(core.DEFAULT_VERSION)
        self.rlskit_dst_edit = line_edit(readonly=True)
        source.field("版本号", self.rlskit_suffix_edit)
        source.field("目标目录", self.rlskit_dst_edit)
        self.form.addWidget(source)

        ftp = Section("FTP 上传")
        self.rlskit_ftp_url_edit = line_edit(
            placeholder="留空则仅打包；ftp://host/path/"
        )
        ftp.field(
            "URL",
            self.rlskit_ftp_url_edit,
            button("浏览 FTP", controller._browse_ftp, "folder-open"),
        )
        self.rlskit_ftp_user_edit = line_edit(placeholder="用户名")
        self.rlskit_ftp_pass_edit = line_edit(placeholder="密码")
        self.rlskit_ftp_pass_edit.setEchoMode(QtWidgets.QLineEdit.Password)
        row = ftp.field("用户", self.rlskit_ftp_user_edit)
        row.addWidget(QtWidgets.QLabel("密码"))
        row.addWidget(self.rlskit_ftp_pass_edit, 1)
        self.rlskit_upload_status = QtWidgets.QLabel("等待上传")
        self.rlskit_upload_status.setObjectName("Hint")
        self.rlskit_upload_progress = QtWidgets.QProgressBar()
        self.rlskit_upload_progress.setRange(0, 100)
        self.rlskit_upload_progress.setValue(0)
        self.rlskit_upload_progress.setTextVisible(False)
        ftp.body.addWidget(self.rlskit_upload_status)
        ftp.body.addWidget(self.rlskit_upload_progress)
        self.form.addWidget(ftp)

        self.rlskit_copy_btn = button("cksum copy", controller._copy_cksum, "copy")
        self.rlskit_copy_btn.setEnabled(False)
        self.rlskit_cancel_btn = button(
            "取消上传", controller._cancel_rlskit_upload, "x"
        )
        self.rlskit_cancel_btn.setEnabled(False)
        self.rlskit_run_btn = button(
            "打包并上传", controller._run_rlskit, "archive", True
        )
        row = QtWidgets.QHBoxLayout()
        row.addWidget(self.rlskit_copy_btn)
        row.addWidget(
            icon_button("file-text", "查看发布历史", controller._open_history_view)
        )
        row.addStretch(1)
        row.addWidget(self.rlskit_cancel_btn)
        row.addWidget(self.rlskit_run_btn)
        self.form.addLayout(row)
        self.form.addStretch(1)

        self.output_tabs = QtWidgets.QTabWidget()
        self.output_tabs.setMinimumHeight(180)
        self.log_panel = LogPanel()
        self.rlskit_log = self.log_panel.output
        self.output_tabs.addTab(self.log_panel, "输出日志")
        notes = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(notes)
        layout.setContentsMargins(16, 8, 16, 12)
        tools = QtWidgets.QHBoxLayout()
        tools.addWidget(
            icon_button(
                "refresh-cw", "刷新 Release Note", controller._load_release_note
            )
        )
        tools.addWidget(
            icon_button(
                "save", "保存 Release Note（Ctrl+S）", controller._save_release_note
            )
        )
        tools.addStretch(1)
        layout.addLayout(tools)
        self.rn_text = QtWidgets.QTextEdit()
        self.rn_text.setAcceptRichText(False)
        layout.addWidget(self.rn_text, 1)
        self.save_shortcut = QtWidgets.QShortcut(
            QtGui.QKeySequence("Ctrl+S"), self.rn_text
        )
        self.save_shortcut.setContext(QtCore.Qt.WidgetWithChildrenShortcut)
        self.save_shortcut.activated.connect(controller._save_release_note)
        self.output_tabs.addTab(notes, "Release Note")
        self.add_output(self.output_tabs)
