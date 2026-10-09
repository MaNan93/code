"""Read-only source viewer with line numbers and SystemVerilog highlighting."""

import re

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import StyledMenu
from plm.frontend.qt.styles.tokens import (
    BG_ARTIFACTS, FONT_CODE_PRIMARY, FONT_SIZE_BODY, TEXT_MUTED,
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
    PORT_CONTEXT = re.compile(r";|\b(?:input|output|inout)\b")

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
        if self.enabled == enabled:
            return
        self.enabled = enabled
        self.rehighlight()

    @staticmethod
    def _utf16_offsets(text):
        # Most RTL is ASCII, so Python and QTextDocument positions already agree.
        if text.isascii():
            return None
        # Compute positions once per block rather than encoding every token prefix.
        offsets = [0]
        position = 0
        for character in text:
            position += 2 if ord(character) > 0xFFFF else 1
            offsets.append(position)
        return offsets

    def _format(self, offsets, start, end, kind):
        # QTextDocument positions count UTF-16 code units, including emoji.
        offset = start if offsets is None else offsets[start]
        length = end - start if offsets is None else offsets[end] - offset
        self.setFormat(offset, length, self.formats[kind])

    def highlightBlock(self, text):
        self.setCurrentBlockState(0)
        if not self.enabled:
            return
        offsets = self._utf16_offsets(text)
        start = 0
        if self.previousBlockState() == 1:
            end = text.find("*/")
            if end < 0:
                self._format(offsets, 0, len(text), "comment")
                self.setCurrentBlockState(1)
                return
            start = end + 2
            self._format(offsets, 0, start, "comment")
        # Preserve the existing block-local, semicolon-delimited port context while
        # scanning it once, including context before an already-open comment ends.
        context_events = self.PORT_CONTEXT.finditer(text)
        context_event = next(context_events, None)
        in_port_statement = False
        for match in self.TOKENS.finditer(text, start):
            kind = match.lastgroup
            if kind == "word":
                if match.group() in self.KEYWORDS:
                    kind = "keyword"
                else:
                    while (
                        context_event is not None
                        and context_event.end() <= match.start()
                    ):
                        in_port_statement = context_event.group() != ";"
                        context_event = next(context_events, None)
                    if not in_port_statement:
                        continue
                    kind = "port"
            self._format(offsets, match.start(), match.end(), kind)
            if (
                kind == "comment"
                and match.group().startswith("/*")
                and not match.group().endswith("*/")
            ):
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
        font = QtGui.QFont(FONT_CODE_PRIMARY)
        font.setStyleHint(QtGui.QFont.Monospace)
        font.setFixedPitch(True)
        font.setPixelSize(FONT_SIZE_BODY)
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
        painter.fillRect(event.rect(), QtGui.QColor(BG_ARTIFACTS))
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
