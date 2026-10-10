"""Obfuscator source, mapping and whitelist controls."""

from fizz import core
from fizz.frontend.qt.views.log_panel import LogPanel
from fizz.frontend.qt.views.workflow_page import WorkflowPage
from fizz.frontend.qt.widgets.common import (
    AdaptiveColumns,
    Section,
    button,
    icon_button,
    line_edit,
)
from fizz.frontend.qt.widgets.theme import VisibleCheckBox


class ObfuscatorPage(WorkflowPage):
    def __init__(self, workflow, controller):
        super().__init__(workflow)
        files = Section("输入与输出")
        self.obf_src_edit = line_edit(placeholder="需要混淆的源文件")
        self.obf_out_edit = line_edit(placeholder="混淆后的输出文件")
        files.field(
            "源文件",
            self.obf_src_edit,
            icon_button("folder-open", "选择源文件", controller._browse_obf_src),
        )
        files.field(
            "输出文件",
            self.obf_out_edit,
            icon_button("folder-open", "选择输出文件", controller._browse_obf_out),
        )
        self.obf_tool_edit = line_edit(core.DEFAULT_OBF_TOOL, readonly=True)
        self.obf_tool_edit.setToolTip("在设置中修改混淆器路径")
        files.field("混淆器", self.obf_tool_edit)
        self.form.addWidget(files)

        maps = Section("Map 文件")
        self.obf_load_map_edit = line_edit(placeholder="可选：已有的映射文件")
        self.obf_save_map_edit = line_edit(placeholder="保存本次映射")
        maps.field(
            "load_map",
            self.obf_load_map_edit,
            icon_button(
                "folder-open", "选择 load_map", controller._browse_obf_load_map
            ),
        )
        maps.field(
            "save_map",
            self.obf_save_map_edit,
            icon_button(
                "folder-open", "选择 save_map", controller._browse_obf_save_map
            ),
        )

        whitelist = Section("Token 白名单")
        self.obf_whitelist_edit = line_edit()
        whitelist.field(
            "白名单",
            self.obf_whitelist_edit,
            icon_button("folder-open", "选择白名单", controller._browse_obf_whitelist),
            button("编辑", controller._edit_obf_whitelist, "pencil"),
        )
        self.obf_first_check = VisibleCheckBox("首次混淆（以白名单作为 load_map）")
        whitelist.body.addWidget(self.obf_first_check)
        self.form.addWidget(AdaptiveColumns(maps, whitelist))
        self.obf_run_btn = button(
            "执行 Obfuscate", controller._run_obfuscate, "git-compare", True
        )
        self.action_row(self.obf_run_btn)
        self.form.addStretch(1)
        self.log_panel = LogPanel()
        self.obf_log = self.log_panel.output
        self.add_output(self.log_panel)
