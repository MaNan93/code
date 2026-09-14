"""Lightweight syntax highlighting for the read-only Preview editor."""

from PyQt5 import QtCore, QtGui


def _format(foreground, *, background=None, bold=False, italic=False):
    value = QtGui.QTextCharFormat()
    value.setForeground(QtGui.QColor(foreground))
    if background:
        value.setBackground(QtGui.QColor(background))
    if bold:
        value.setFontWeight(QtGui.QFont.Bold)
    if italic:
        value.setFontItalic(True)
    return value


class CodeHighlighter(QtGui.QSyntaxHighlighter):
    """Highlight SystemVerilog/Verilog, CSV and unified-diff documents."""

    _KEYWORDS = (
        "always", "always_comb", "always_ff", "always_latch", "and", "assign",
        "automatic", "begin", "case", "casex", "casez", "default", "else",
        "end", "endcase", "endfunction", "endgenerate", "endmodule", "endpackage",
        "endtask", "for", "force", "forever", "fork", "function", "generate",
        "genvar", "if", "initial", "input", "interface", "localparam", "logic",
        "module", "or", "output", "package", "parameter", "posedge", "negedge",
        "reg", "release", "repeat", "return", "signed", "struct", "task",
        "typedef", "union", "unsigned", "wait", "while", "wire",
    )

    def __init__(self, document):
        super().__init__(document)
        self._language = "text"
        self._enabled = True
        self._formats = {
            "keyword": _format("#8250df", bold=True),
            "number": _format("#0550ae"),
            "string": _format("#0a3069"),
            "comment": _format("#6e7781", italic=True),
            "directive": _format("#cf222e"),
            "system": _format("#953800"),
            "csv_header": _format("#8250df", bold=True),
            "diff_add": _format("#1a7f37", background="#dafbe1"),
            "diff_remove": _format("#cf222e", background="#ffebe9"),
            "diff_hunk": _format("#0550ae", background="#ddf4ff", bold=True),
            "diff_meta": _format("#57606a", background="#f6f8fa", bold=True),
        }
        words = "|".join(self._KEYWORDS)
        self._verilog_rules = (
            (QtCore.QRegularExpression(rf"\b(?:{words})\b"), "keyword"),
            (QtCore.QRegularExpression(r"\B\$[A-Za-z_][A-Za-z0-9_$]*"), "system"),
            (QtCore.QRegularExpression(r"`[A-Za-z_][A-Za-z0-9_]*"), "directive"),
            (QtCore.QRegularExpression(r"\b(?:\d+'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|\d+(?:\.\d+)?)\b"), "number"),
            (QtCore.QRegularExpression(r'"(?:\\.|[^"\\])*"'), "string"),
            (QtCore.QRegularExpression(r"//.*$"), "comment"),
        )
        self._block_comment_start = QtCore.QRegularExpression(r"/\*")
        self._block_comment_end = QtCore.QRegularExpression(r"\*/")

    def set_language(self, language):
        language = (language or "text").lower().lstrip(".")
        if language in {"sv", "svh", "v", "vh", "f"}:
            language = "verilog"
        self._language = language
        self.rehighlight()

    def set_enabled(self, enabled):
        self._enabled = bool(enabled)
        self.rehighlight()

    def highlightBlock(self, text):
        if not self._enabled:
            self.setCurrentBlockState(0)
            return
        if self._language == "diff":
            self._highlight_diff(text)
        elif self._language == "csv":
            if self.currentBlock().blockNumber() == 0:
                self.setFormat(0, len(text), self._formats["csv_header"])
        elif self._language == "verilog":
            self._highlight_verilog(text)

    def _highlight_diff(self, text):
        if text.startswith("@@"):
            kind = "diff_hunk"
        elif text.startswith(("---", "+++")):
            kind = "diff_meta"
        elif text.startswith("+"):
            kind = "diff_add"
        elif text.startswith("-"):
            kind = "diff_remove"
        else:
            return
        self.setFormat(0, len(text), self._formats[kind])

    def _highlight_verilog(self, text):
        for expression, kind in self._verilog_rules:
            match = expression.globalMatch(text)
            while match.hasNext():
                result = match.next()
                self.setFormat(
                    result.capturedStart(),
                    result.capturedLength(),
                    self._formats[kind],
                )

        self.setCurrentBlockState(0)
        start = 0
        if self.previousBlockState() != 1:
            start = self._block_comment_start.match(text).capturedStart()
        while start >= 0:
            end_match = self._block_comment_end.match(text, start + 2)
            end = end_match.capturedStart()
            if end < 0:
                self.setCurrentBlockState(1)
                length = len(text) - start
            else:
                length = end - start + end_match.capturedLength()
            self.setFormat(start, length, self._formats["comment"])
            if end < 0:
                break
            start = self._block_comment_start.match(text, start + length).capturedStart()
