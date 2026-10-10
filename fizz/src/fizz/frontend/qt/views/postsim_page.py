"""Simulation log discovery and timing-analysis entry point."""

from PyQt5 import QtWidgets

from fizz.frontend.qt.views.workflow_page import WorkflowPage
from fizz.frontend.qt.widgets.common import Section, button, icon_button, line_edit


class PostsimPage(WorkflowPage):
    def __init__(self, workflow, controller):
        super().__init__(workflow)
        search = Section("搜索日志")
        self.postsim_dir_edit = line_edit(controller.script_dir)
        self.postsim_pattern_edit = line_edit("*.log", "例如 *.log, test?.txt")
        search.field(
            "搜索目录",
            self.postsim_dir_edit,
            icon_button("folder-open", "选择搜索目录", controller._postsim_browse_dir),
        )
        search.field(
            "匹配规则",
            self.postsim_pattern_edit,
            button("搜索", controller._postsim_search, "search"),
        )
        self.form.addWidget(search)
        results = Section("匹配文件 · 双击分析")
        self.postsim_list = QtWidgets.QListWidget()
        self.postsim_list.setMinimumHeight(200)
        self.postsim_list.itemDoubleClicked.connect(controller._postsim_analyze_item)
        results.body.addWidget(self.postsim_list, 1)
        row = QtWidgets.QHBoxLayout()
        self.postsim_stats_label = QtWidgets.QLabel("匹配文件数：0")
        self.postsim_stats_label.setObjectName("Hint")
        row.addWidget(self.postsim_stats_label)
        row.addStretch(1)
        self.analyze_btn = button(
            "分析选中", controller._postsim_analyze_selected, "search", True
        )
        row.addWidget(self.analyze_btn)
        results.body.addLayout(row)
        self.form.addWidget(results, 1)
