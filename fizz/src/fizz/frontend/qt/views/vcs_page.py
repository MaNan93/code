"""VCS protection form and output."""

from fizz import core
from fizz.frontend.qt.views.log_panel import LogPanel
from fizz.frontend.qt.views.workflow_page import WorkflowPage
from fizz.frontend.qt.widgets.common import Section, button, icon_button, line_edit


class VcsPage(WorkflowPage):
    def __init__(self, workflow, controller):
        super().__init__(workflow)
        files = Section("源文件与密钥")
        self.vcs_src_edit = line_edit(placeholder="需要保护的 .sv 文件")
        self.vcs_key_edit = line_edit(placeholder="VCS -ipprotect 密钥文件")
        files.field(
            "源文件",
            self.vcs_src_edit,
            icon_button("folder-open", "选择源文件", controller._browse_vcs_src),
        )
        files.field(
            "密钥文件",
            self.vcs_key_edit,
            icon_button("folder-open", "选择密钥文件", controller._browse_vcs_key),
        )
        self.form.addWidget(files)
        options = Section("保护选项")
        self.vcs_opt_edit = line_edit(core.DEFAULT_VCS_OPTIONS)
        options.field("", self.vcs_opt_edit)
        self.form.addWidget(options)
        self.vcs_run_btn = button(
            "执行 VCS Protect", controller._run_vcs, "file-braces-corner", True
        )
        self.action_row(self.vcs_run_btn)
        self.form.addStretch(1)
        self.log_panel = LogPanel()
        self.vcs_log = self.log_panel.output
        self.add_output(self.log_panel)
