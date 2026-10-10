"""SystemVerilog merge configuration and ordered source list."""

from PyQt5 import QtCore, QtWidgets

from fizz import core
from fizz.frontend.qt.views.workflow_page import WorkflowPage
from fizz.frontend.qt.widgets.common import Section, button, icon_button, line_edit
from fizz.frontend.qt.widgets.theme import VisibleCheckBox


class MergePage(WorkflowPage):
    def __init__(self, workflow, controller):
        super().__init__(workflow)
        source = Section("消息文件")
        self.msg_path_edit = line_edit(placeholder="选择 generalMessage.txt")
        source.field(
            "",
            self.msg_path_edit,
            icon_button("folder-open", "选择消息文件", controller._browse_msg),
            button("解析", controller._parse, "refresh-cw"),
        )
        self.form.addWidget(source)

        filters = Section("过滤规则")
        self.dir_filter_edit = line_edit(placeholder="目录通配符，逗号或分号分隔")
        self.file_filter_edit = line_edit(placeholder="文件通配符，逗号或分号分隔")
        filters.field("排除目录", self.dir_filter_edit)
        filters.field(
            "排除文件",
            self.file_filter_edit,
            button("重新过滤", controller._apply_filter, "refresh-cw"),
        )
        self.form.addWidget(filters)

        files = Section("文件列表 · 按此顺序合并")
        self.file_listwidget = QtWidgets.QListWidget()
        self.file_listwidget.setMinimumHeight(110)
        self.file_listwidget.setSelectionMode(
            QtWidgets.QAbstractItemView.ExtendedSelection
        )
        self.file_listwidget.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.file_listwidget.customContextMenuRequested.connect(
            controller._file_list_context_menu
        )
        files.body.addWidget(self.file_listwidget, 1)
        self.form.addWidget(files, 1)

        output = Section("输出配置")
        self.out_path_edit = line_edit(placeholder="合并后的 .sv 文件")
        output.field(
            "输出文件",
            self.out_path_edit,
            icon_button("folder-open", "选择输出文件", controller._browse_out),
        )
        self.protect_check = VisibleCheckBox("protect")
        self.top_file_edit = line_edit(core.DEFAULT_TOP_FILE)
        output.field("Top 文件", self.top_file_edit, self.protect_check)
        row = QtWidgets.QHBoxLayout()
        self.strip_comments_check = VisibleCheckBox("verible strip-comments")
        row.addWidget(self.strip_comments_check)
        row.addStretch(1)
        self.merge_btn = button("合并文件", controller._merge, "file-code-corner", True)
        row.addWidget(self.merge_btn)
        output.body.addLayout(row)
        self.merge_progress = QtWidgets.QProgressBar()
        self.merge_progress.setRange(0, 100)
        self.merge_progress.setValue(0)
        self.merge_progress.setTextVisible(False)
        self.merge_status_label = QtWidgets.QLabel("就绪")
        self.merge_status_label.setObjectName("Hint")
        output.body.addWidget(self.merge_progress)
        output.body.addWidget(self.merge_status_label)
        self.form.addWidget(output)
