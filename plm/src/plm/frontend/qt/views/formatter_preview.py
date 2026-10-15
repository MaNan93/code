"""Debounced Verible previews from a snapshot of unsaved formatter options."""

from PyQt5 import QtCore, QtWidgets

from plm.core.verible import VERIBLE_INT_PARAMS, format_sv
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.widgets.code_preview import CodePreview
from plm.frontend.qt.widgets.common import StyledComboBox


SAMPLES = (
    ("对齐与缩进", """module preview(input logic clk, input logic rst_n,
input logic [7:0] data_i, output logic [7:0] data_o);
logic [7:0] short_name;
logic [7:0] longer_name;
assign short_name=data_i;
assign longer_name = data_i+8'd1;
always_ff @(posedge clk) begin
if(rst_n) begin
data_o<=longer_name;
end else begin
data_o <= '0;
end
end
endmodule
"""),
    ("端口与实例", """module preview(input logic clk,
input logic [7:0] data_i, output logic [7:0] data_o);
helper #(.WIDTH(8), .DEPTH(16)) u_helper (
.clk(clk),
.data_i(data_i),
.data_o(data_o)
);
endmodule
"""),
)


class FormatterPreview(QtWidgets.QWidget):
    MAX_SOURCE_BYTES = 64 * 1024

    def __init__(self, parent=None):
        super().__init__(parent)
        self._path = ""
        self._flags = {}
        self._revision = 0
        self._completed_snapshot = None
        self.tasks = TaskRunner(self)
        self.timer = QtCore.QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.setInterval(250)
        self.timer.timeout.connect(self._submit)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        actions = QtWidgets.QHBoxLayout()
        self.sample_combo = StyledComboBox()
        self.sample_combo.addItems([title for title, _source in SAMPLES])
        actions.addWidget(self.sample_combo)
        actions.addStretch(1)
        self.refresh_button = QtWidgets.QPushButton("更新预览")
        actions.addWidget(self.refresh_button)
        layout.addLayout(actions)
        self.splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        self.source = CodePreview()
        self.source.setReadOnly(False)
        self.source.setAccessibleName("预览源代码")
        self.source.setPlainText(SAMPLES[0][1])
        self.result = CodePreview()
        self.result.setAccessibleName("格式化结果")
        self.result.setPlaceholderText("格式化结果将在这里显示")
        for title, editor in (("源代码（可编辑）", self.source), ("格式化结果", self.result)):
            column = QtWidgets.QWidget()
            column_layout = QtWidgets.QVBoxLayout(column)
            column_layout.setContentsMargins(0, 0, 0, 0)
            column_layout.addWidget(QtWidgets.QLabel(title))
            column_layout.addWidget(editor, 1)
            self.splitter.addWidget(column)
        self.splitter.setChildrenCollapsible(False)
        layout.addWidget(self.splitter, 1)
        self.status = QtWidgets.QLabel("选择 Verible 后查看实际格式化结果；参数无需先保存。")
        self.status.setWordWrap(True)
        self.status.setMaximumHeight(64)
        layout.addWidget(self.status)
        self.source.textChanged.connect(self.invalidate)
        self.sample_combo.currentIndexChanged.connect(
            lambda index: self.source.setPlainText(SAMPLES[index][1]))
        self.refresh_button.clicked.connect(self.invalidate)

    def set_options(self, path, flags):
        if path == self._path and flags == self._flags:
            return
        self._path, self._flags = path, dict(flags)
        self.invalidate()

    def _snapshot(self):
        return self.source.toPlainText(), self._path, tuple(sorted(self._flags.items()))

    def invalidate(self, *_):
        self._revision += 1
        self._completed_snapshot = None
        self.tasks.cancel_latest("formatter-preview")
        self.result.clear()
        self.status.setText("等待更新预览…")
        if self.isVisible():
            self.timer.start()

    def showEvent(self, event):
        super().showEvent(event)
        if self._completed_snapshot != self._snapshot():
            self.timer.start()

    def hideEvent(self, event):
        self.timer.stop()
        self.tasks.cancel_latest("formatter-preview")
        super().hideEvent(event)

    def _submit(self):
        if not self.isVisible():
            return
        snapshot = self._snapshot()
        text, path, items = snapshot
        flags, revision = dict(items), self._revision

        def failed(error):
            if revision == self._revision:
                self.result.clear()
                message = str(error)
                self.status.setText("无法预览：" + message[:300])
                self.status.setToolTip(message)
                self._completed_snapshot = snapshot

        if not text.strip():
            failed(ValueError("请输入需要预览的 SystemVerilog 代码。"))
            return
        if len(text.encode("utf-8")) > self.MAX_SOURCE_BYTES:
            failed(ValueError("预览代码请限制在 64 KiB 以内。"))
            return
        for name in VERIBLE_INT_PARAMS:
            value = str(flags.get(name, "")).strip()
            if value and (not value.isascii() or not value.isdecimal() or len(value) > 10
                          or int(value) > 2147483647):
                failed(ValueError(f"{name} 必须是非负整数。"))
                return
        self.status.setText("正在生成预览…")

        def finished(formatted):
            if revision == self._revision:
                self.result.setPlainText(formatted)
                self.status.setText("预览已更新 · 使用当前未保存参数")
                self.status.setToolTip("")
                self._completed_snapshot = snapshot

        # The worker receives plain Python snapshots and never reads widgets.
        self.tasks.submit_latest(
            "formatter-preview",
            lambda _progress: format_sv(text, path or None, flags, strict=True, timeout=3),
            finished, failed,
        )
