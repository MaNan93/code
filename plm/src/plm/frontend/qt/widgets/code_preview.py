"""Read-only source viewer with line numbers and SystemVerilog highlighting."""

import re

from PyQt5 import QtCore, QtGui, QtWidgets


class VerilogHighlighter(QtGui.QSyntaxHighlighter):
    KEYWORDS = set("""module endmodule input output inout wire reg logic bit tri tri0 tri1
        parameter localparam integer int real time signed unsigned assign always always_comb
        always_ff always_latch initial begin end if else case casex casez endcase default
        for foreach while repeat forever generate endgenerate genvar function endfunction
        task endtask automatic posedge negedge or not and nand nor xor xnor buf interface
        endinterface modport typedef struct packed enum union package endpackage import
        include timescale default_nettype return assert property endproperty sequence
        endsequence disable iff wait fork join join_any join_none force release deassign
        unique priority inside cover assume void event string byte shortint longint
        supply0 supply1 specify endspecify class endclass extends virtual new null this
        const static rand randc constraint endclocking clocking program endprogram""".split())
    TOKENS = re.compile(
        r'(?P<comment>//[^\n]*|/\*.*?(?:\*/|$))'
        r'|(?P<string>"(?:\\.|[^"\\])*")'
        r'|(?P<directive>`[A-Za-z_][A-Za-z0-9_$]*)'
        r"|(?P<number>\b\d[\d_]*\s*'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|"
        r"'[01xXzZ]|\b\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?\b)"
        r'|(?P<word>\b[A-Za-z_][A-Za-z0-9_$]*\b)', re.DOTALL
    )

    def __init__(self, document):
        super().__init__(document)
        self.enabled = True
        self.formats = {}
        for name, color in (("comment", "#6A737D"), ("keyword", "#D73A49"),
                            ("string", "#032F62"), ("number", "#005CC5"),
                            ("directive", "#6F42C1")):
            fmt = QtGui.QTextCharFormat()
            fmt.setForeground(QtGui.QColor(color))
            self.formats[name] = fmt

    def set_enabled(self, enabled):
        self.enabled = enabled
        self.rehighlight()

    def _format(self, text, start, end, kind):
        # QTextDocument positions count UTF-16 code units, including non-ASCII comments.
        offset = len(text[:start].encode("utf-16-le")) // 2
        length = len(text[start:end].encode("utf-16-le")) // 2
        self.setFormat(offset, length, self.formats[kind])

    def highlightBlock(self, text):
        self.setCurrentBlockState(0)
        if not self.enabled:
            return
        start = 0
        if self.previousBlockState() == 1:
            end = text.find("*/")
            if end < 0:
                self._format(text, 0, len(text), "comment")
                self.setCurrentBlockState(1)
                return
            start = end + 2
            self._format(text, 0, start, "comment")
        for match in self.TOKENS.finditer(text, start):
            kind = match.lastgroup
            if kind == "word":
                if match.group() not in self.KEYWORDS:
                    continue
                kind = "keyword"
            self._format(text, match.start(), match.end(), kind)
            if kind == "comment" and match.group().startswith("/*") and not match.group().endswith("*/"):
                self.setCurrentBlockState(1)


class LineNumberArea(QtWidgets.QWidget):
    def __init__(self, editor):
        super().__init__(editor)
        self.editor = editor

    def sizeHint(self):
        return QtCore.QSize(self.editor.line_number_width(), 0)

    def paintEvent(self, event):
        self.editor.paint_line_numbers(event)


class CodePreview(QtWidgets.QPlainTextEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactCodePreview")
        self.setReadOnly(True)
        self.setLineWrapMode(QtWidgets.QPlainTextEdit.NoWrap)
        font = QtGui.QFontDatabase.systemFont(QtGui.QFontDatabase.FixedFont)
        font.setPointSize(10)
        self.setFont(font)
        self.line_numbers = LineNumberArea(self)
        self.highlighter = VerilogHighlighter(self.document())
        self.blockCountChanged.connect(self.update_line_number_width)
        self.updateRequest.connect(self.update_line_number_area)
        self.update_line_number_width()

    def line_number_width(self):
        return 16 + self.fontMetrics().horizontalAdvance("9") * len(str(self.blockCount()))

    def update_line_number_width(self, *_):
        width = self.line_number_width()
        self.setViewportMargins(width, 0, 0, 0)
        rect = self.contentsRect()
        self.line_numbers.setGeometry(rect.left(), rect.top(), width, rect.height())
        self.line_numbers.update()

    def update_line_number_area(self, rect, dy):
        if dy:
            self.line_numbers.scroll(0, dy)
        else:
            self.line_numbers.update(0, rect.y(), self.line_numbers.width(), rect.height())
        if rect.contains(self.viewport().rect()):
            self.update_line_number_width()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        rect = self.contentsRect()
        self.line_numbers.setGeometry(rect.left(), rect.top(), self.line_number_width(), rect.height())

    def paint_line_numbers(self, event):
        painter = QtGui.QPainter(self.line_numbers)
        painter.fillRect(event.rect(), QtGui.QColor("#F6F8FA"))
        painter.setFont(self.font())
        painter.setPen(QtGui.QColor("#8C959F"))
        block = self.firstVisibleBlock()
        number = block.blockNumber()
        top = int(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        while block.isValid() and top <= event.rect().bottom():
            height = int(self.blockBoundingRect(block).height())
            if block.isVisible() and top + height >= event.rect().top():
                painter.drawText(0, top, self.line_numbers.width() - 6,
                                 self.fontMetrics().height(), QtCore.Qt.AlignRight, str(number + 1))
            top += height
            block = block.next()
            number += 1
