"""Read-only source viewer with line numbers and SystemVerilog highlighting."""

import re

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import StyledMenu
from plm.frontend.qt.styles.tokens import (
    BG_SIDEBAR_INACTIVE, BORDER, FONT_CODE_PRIMARY, TEXT_MUTED, scale_content_size,
)


SYNTAX_COMMENT = "#6E7781"
SYNTAX_KEYWORD = "#0969DA"
SYNTAX_PORT = "#0086B3"
SYNTAX_NUMBER = "#986801"
SYNTAX_STRING = "#0A3069"
SYNTAX_DIRECTIVE = "#8250DF"
LINE_NUMBER_PADDING = 12


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
        for name, color in (
            ("comment", SYNTAX_COMMENT),
            ("keyword", SYNTAX_KEYWORD),
            ("port", SYNTAX_PORT),
            ("string", SYNTAX_STRING),
            ("number", SYNTAX_NUMBER),
            ("directive", SYNTAX_DIRECTIVE),
        ):
            fmt = QtGui.QTextCharFormat()
            fmt.setForeground(QtGui.QColor(color))
            if name == "comment":
                fmt.setFontItalic(True)
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
                if match.group() in self.KEYWORDS:
                    kind = "keyword"
                elif self._is_port_identifier(text, match.start()):
                    kind = "port"
                else:
                    continue
            self._format(text, match.start(), match.end(), kind)
            if (
                kind == "comment"
                and match.group().startswith("/*")
                and not match.group().endswith("*/")
            ):
                self.setCurrentBlockState(1)

    @staticmethod
    def _is_port_identifier(text, position):
        prefix = text[:position]
        statement = prefix.rsplit(";", 1)[-1]
        return re.search(r"\b(?:input|output|inout)\b", statement) is not None


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
        font = QtGui.QFont(FONT_CODE_PRIMARY)
        font.setStyleHint(QtGui.QFont.Monospace)
        font.setPointSize(scale_content_size(10))
        self.setFont(font)
        self.line_numbers = LineNumberArea(self)
        self.highlighter = VerilogHighlighter(self.document())
        self.blockCountChanged.connect(self.update_line_number_width)
        self.updateRequest.connect(self.update_line_number_area)
        self.update_line_number_width()

    def createStandardContextMenu(self, position=None):
        native_menu = (super().createStandardContextMenu() if position is None
                       else super().createStandardContextMenu(position))
        menu = StyledMenu(self)
        for action in native_menu.actions():
            action.setParent(menu)
            menu.addAction(action)
        native_menu.deleteLater()
        return menu

    def contextMenuEvent(self, event):
        menu = self.createStandardContextMenu(event.pos())
        try:
            menu.exec_(event.globalPos())
        finally:
            menu.deleteLater()
        event.accept()

    def line_number_width(self):
        digits = len(str(self.blockCount()))
        return 8 + LINE_NUMBER_PADDING + self.fontMetrics().horizontalAdvance("9") * digits

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
            self.line_numbers.update(
                0, rect.y(), self.line_numbers.width(), rect.height()
            )
        if rect.contains(self.viewport().rect()):
            self.update_line_number_width()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        rect = self.contentsRect()
        self.line_numbers.setGeometry(
            rect.left(), rect.top(), self.line_number_width(), rect.height()
        )

    def paint_line_numbers(self, event):
        painter = QtGui.QPainter(self.line_numbers)
        painter.fillRect(event.rect(), QtGui.QColor(BG_SIDEBAR_INACTIVE))
        painter.setPen(QtGui.QColor(BORDER))
        painter.drawLine(
            self.line_numbers.width() - 1,
            event.rect().top(),
            self.line_numbers.width() - 1,
            event.rect().bottom(),
        )
        painter.setFont(self.font())
        painter.setPen(QtGui.QColor(TEXT_MUTED))
        block = self.firstVisibleBlock()
        number = block.blockNumber()
        top = int(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        while block.isValid() and top <= event.rect().bottom():
            height = int(self.blockBoundingRect(block).height())
            if block.isVisible() and top + height >= event.rect().top():
                painter.drawText(
                    0,
                    top,
                    self.line_numbers.width() - LINE_NUMBER_PADDING,
                    self.fontMetrics().height(),
                    QtCore.Qt.AlignRight,
                    str(number + 1),
                )
            top += height
            block = block.next()
            number += 1
