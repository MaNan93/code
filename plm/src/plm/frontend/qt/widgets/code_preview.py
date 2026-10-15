"""Read-only source viewer with line numbers and SystemVerilog highlighting."""

import re

from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import StyledMenu
from plm.frontend.qt.styles.tokens import get_theme_color
from plm.frontend.qt.styles.tokens import (
    FONT_CODE_PRIMARY, FONT_SIZE_BODY,
)


from plm.frontend.qt.styles.tokens import (
    SYNTAX_COMMENT as SYNTAX_COMMENT, SYNTAX_KEYWORD as SYNTAX_KEYWORD,
    SYNTAX_PORT as SYNTAX_PORT, SYNTAX_NUMBER as SYNTAX_NUMBER,
    SYNTAX_STRING as SYNTAX_STRING, SYNTAX_DIRECTIVE as SYNTAX_DIRECTIVE,
)
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
        self.refresh_theme()

    def refresh_theme(self):
        for name, color in (
            ("comment", get_theme_color("syntax_comment")),
            ("keyword", get_theme_color("syntax_keyword")),
            ("port", get_theme_color("syntax_port")),
            ("string", get_theme_color("syntax_string")),
            ("number", get_theme_color("syntax_number")),
            ("directive", get_theme_color("syntax_directive")),
        ):
            fmt = QtGui.QTextCharFormat()
            fmt.setForeground(QtGui.QColor(color))
            self.formats[name] = fmt
        self.rehighlight()

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
        self._line_number_width = 0
        self._diff_mode = False
        self._diff_rows = []
        self._diff_line_digits = 1
        self.highlighter = VerilogHighlighter(self.document())
        self.blockCountChanged.connect(self.update_line_number_width)
        self.updateRequest.connect(self.update_line_number_area)
        self.textChanged.connect(self._update_diff_rows)
        self.update_line_number_width()

    def refresh_theme(self):
        self.highlighter.refresh_theme()
        self._update_diff_rows()
        self.viewport().update()
        self.line_numbers.update()

    def set_diff_mode(self, enabled):
        self._diff_mode = bool(enabled)
        self._update_diff_rows()

    @staticmethod
    def diff_rows(text):
        """Track original/new source coordinates, not unified-diff row numbers."""
        rows = []
        old = new = 0
        in_hunk = False
        for line in text.splitlines():
            hunk = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
            if hunk:
                old, new = map(int, hunk.groups())
                in_hunk = True
                rows.append((None, None, "hunk"))
            elif not in_hunk:
                rows.append((None, None, "header"))
            elif line.startswith("+"):
                rows.append((None, new, "added"))
                new += 1
            elif line.startswith("-"):
                rows.append((old, None, "removed"))
                old += 1
            elif line.startswith(" "):
                rows.append((old, new, "context"))
                old += 1
                new += 1
            else:
                rows.append((None, None, "marker"))
        return rows

    def _update_diff_rows(self):
        self._diff_rows = self.diff_rows(self.toPlainText()) if self._diff_mode else []
        self._diff_line_digits = len(str(max(
            (number for old, new, _kind in self._diff_rows
             for number in (old, new) if number is not None), default=1,
        )))
        colors = {"added": get_theme_color("diff_added_bg"), "removed": get_theme_color("diff_removed_bg"),
                  "hunk": get_theme_color("diff_hunk_bg"), "header": get_theme_color("bg_artifacts_header")}
        selections = []
        block = self.document().begin()
        for _old, _new, kind in self._diff_rows:
            if kind in colors:
                selection = QtWidgets.QTextEdit.ExtraSelection()
                selection.cursor = QtGui.QTextCursor(block)
                selection.format.setBackground(QtGui.QColor(colors[kind]))
                selection.format.setProperty(QtGui.QTextFormat.FullWidthSelection, True)
                if kind == "hunk":
                    selection.format.setForeground(QtGui.QColor(get_theme_color("accent_artifacts")))
                selections.append(selection)
            block = block.next()
        self.setExtraSelections(selections)
        self.update_line_number_width()
        self.line_numbers.update()

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
        if self._diff_mode:
            cell = LINE_NUMBER_PADDING + self.fontMetrics().horizontalAdvance("9") * self._diff_line_digits
            return 8 + 2 * cell
        digits = len(str(self.blockCount()))
        return 8 + LINE_NUMBER_PADDING + self.fontMetrics().horizontalAdvance("9") * digits

    def update_line_number_width(self, *_):
        width = self.line_number_width()
        if width == self._line_number_width:
            return
        self._line_number_width = width
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

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() == QtCore.QEvent.FontChange and hasattr(self, "line_numbers"):
            self.update_line_number_width()

    def paint_line_numbers(self, event):
        painter = QtGui.QPainter(self.line_numbers)
        painter.fillRect(event.rect(), QtGui.QColor(get_theme_color("bg_artifacts")))
        painter.setFont(self.font())
        painter.setPen(QtGui.QColor(get_theme_color("text_artifacts_muted")))
        block = self.firstVisibleBlock()
        number = block.blockNumber()
        top = int(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        while block.isValid() and top <= event.rect().bottom():
            height = int(self.blockBoundingRect(block).height())
            if block.isVisible() and top + height >= event.rect().top():
                if self._diff_mode:
                    old, new, kind = (self._diff_rows[number] if number < len(self._diff_rows)
                                      else (None, None, "context"))
                    colors = {"added": get_theme_color("diff_added_gutter"), "removed": get_theme_color("diff_removed_gutter"),
                              "hunk": get_theme_color("diff_hunk_bg"), "header": get_theme_color("bg_artifacts_header")}
                    if kind in colors:
                        painter.fillRect(0, top, self.line_numbers.width(), height,
                                         QtGui.QColor(colors[kind]))
                    cell = (self.line_numbers.width() - 8) // 2
                    for column, value in enumerate((old, new)):
                        if value is not None:
                            painter.drawText(column * cell, top, cell - 4,
                                             self.fontMetrics().height(), QtCore.Qt.AlignRight,
                                             str(value))
                    top += height
                    block = block.next()
                    number += 1
                    continue
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
