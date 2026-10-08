"""Highlighter compatibility checks and an optional long-line benchmark.

Run ``uv run python tests/test_qt_highlighter_performance.py --benchmark`` to
measure several block sizes without imposing machine-dependent timing limits.
"""

import os
import statistics
import sys
import time
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.widgets.code_preview import (
    SYNTAX_COMMENT,
    SYNTAX_DIRECTIVE,
    SYNTAX_KEYWORD,
    SYNTAX_NUMBER,
    SYNTAX_PORT,
    SYNTAX_STRING,
    VerilogHighlighter,
)


class HighlighterPerformanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.document = QtGui.QTextDocument()
        self.highlighter = VerilogHighlighter(self.document)

    def tearDown(self):
        self.document.deleteLater()
        self.app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)

    def highlight(self, text):
        self.document.setPlainText(text)
        self.highlighter.rehighlight()

    def assert_token_format(self, token, color, *, block_number=0):
        block = self.document.findBlockByNumber(block_number)
        text = block.text()
        start = text.index(token)
        offset = len(text[:start].encode("utf-16-le")) // 2
        length = len(token.encode("utf-16-le")) // 2
        ranges = block.layout().formats()
        covering = [
            span for span in ranges
            if span.start <= offset and offset + length <= span.start + span.length
        ]
        if color is None:
            self.assertFalse(covering, token)
        else:
            self.assertTrue(covering, token)
            self.assertEqual(
                covering[0].format.foreground().color().name(), color.lower(), token
            )

    def test_ascii_lexical_styles_and_port_statement_boundaries(self):
        self.highlight(
            '`define WIDTH 8 input logic [7:0] data, other; wire spare; '
            'output bit result; inout tri pad; "// module" /* assign */'
        )
        for keyword in ("input", "logic", "wire", "output", "inout", "tri"):
            with self.subTest(keyword=keyword):
                self.assert_token_format(keyword, SYNTAX_KEYWORD)
        for port in ("data", "other", "result", "pad"):
            with self.subTest(port=port):
                self.assert_token_format(port, SYNTAX_PORT)
        self.assert_token_format("spare", None)
        self.assert_token_format("`define", SYNTAX_DIRECTIVE)
        self.assert_token_format("8", SYNTAX_NUMBER)
        self.assert_token_format('"// module"', SYNTAX_STRING)
        self.assert_token_format("/* assign */", SYNTAX_COMMENT)

    def test_non_bmp_characters_keep_utf16_ranges_aligned(self):
        self.highlight('😀 /* 中🛰 */ input logic data; "hi🙂" assign data = 8\'hFF;')
        for token, color in (
            ("/* 中🛰 */", SYNTAX_COMMENT),
            ("input", SYNTAX_KEYWORD),
            ("data", SYNTAX_PORT),
            ('"hi🙂"', SYNTAX_STRING),
            ("assign", SYNTAX_KEYWORD),
            ("8'hFF", SYNTAX_NUMBER),
        ):
            with self.subTest(token=token):
                self.assert_token_format(token, color)
        spans = self.document.firstBlock().layout().formats()
        comment = next(
            span for span in spans
            if span.format.foreground().color().name() == SYNTAX_COMMENT.lower()
        )
        self.assertEqual((comment.start, comment.length), (3, 9))

    def test_multiline_comments_and_following_port_declarations(self):
        self.highlight("/* 😀\n still 中🙂\n done */ input logic value;\nwire spare;")
        self.assertEqual(self.document.findBlockByNumber(0).userState(), 1)
        self.assertEqual(self.document.findBlockByNumber(1).userState(), 1)
        self.assertEqual(self.document.findBlockByNumber(2).userState(), 0)
        self.assert_token_format("/* 😀", SYNTAX_COMMENT)
        self.assert_token_format(" still 中🙂", SYNTAX_COMMENT, block_number=1)
        self.assert_token_format(" done */", SYNTAX_COMMENT, block_number=2)
        self.assert_token_format("input", SYNTAX_KEYWORD, block_number=2)
        self.assert_token_format("value", SYNTAX_PORT, block_number=2)
        self.assert_token_format("spare", None, block_number=3)

    def test_port_context_preserves_word_boundaries_and_raw_prefix_semantics(self):
        self.highlight(
            'input_extra plain; /* input */ comment_port; "output" string_port; '
            'input logic declared; ordinary;'
        )
        self.assert_token_format("input_extra", None)
        self.assert_token_format("plain", None)
        self.assert_token_format("comment_port", SYNTAX_PORT)
        self.assert_token_format("string_port", SYNTAX_PORT)
        self.assert_token_format("declared", SYNTAX_PORT)
        self.assert_token_format("ordinary", None)

    def test_port_context_remains_local_to_each_block(self):
        self.highlight("input logic first,\ncontinuation;\noutput logic second;")
        self.assert_token_format("first", SYNTAX_PORT)
        self.assert_token_format("continuation", None, block_number=1)
        self.assert_token_format("second", SYNTAX_PORT, block_number=2)

    def test_repeated_enabled_values_do_not_rehighlight(self):
        self.highlight("/* continuing\ncomment */ module example; endmodule")
        with patch.object(
            self.highlighter, "rehighlight", wraps=self.highlighter.rehighlight
        ) as rehighlight:
            self.highlighter.set_enabled(True)
            rehighlight.assert_not_called()
            self.highlighter.set_enabled(False)
            self.assertEqual(rehighlight.call_count, 1)
            self.assertFalse(self.document.firstBlock().layout().formats())
            self.assertEqual(self.document.firstBlock().userState(), 0)
            self.highlighter.set_enabled(False)
            self.assertEqual(rehighlight.call_count, 1)
            self.highlighter.set_enabled(True)
            self.assertEqual(rehighlight.call_count, 2)
            self.assertEqual(self.document.firstBlock().userState(), 1)
            self.assert_token_format("module", SYNTAX_KEYWORD, block_number=1)


def benchmark():
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    # Measure actual QTextDocument formatting rather than a tokenization-only loop.
    for label, fragment in (
        ("ASCII", "input logic [31:0] data, next_data; assign data = 32'hCAFE; "),
        ("Unicode", '/* 中😀 */ input logic data; assign data = "🙂"; '),
    ):
        for target_size in (12 * 1024, 48 * 1024, 192 * 1024):
            text = fragment * (target_size // len(fragment))
            document = QtGui.QTextDocument()
            highlighter = VerilogHighlighter(document)
            document.setPlainText(text)
            highlighter.rehighlight()
            samples = []
            for _ in range(5):
                started = time.perf_counter()
                highlighter.rehighlight()
                samples.append((time.perf_counter() - started) * 1000)
            print(f"{label:7} {len(text):6} chars: {statistics.median(samples):8.2f} ms")
            document.deleteLater()
            app.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)


if __name__ == "__main__":
    if "--benchmark" in sys.argv:
        benchmark()
    else:
        unittest.main()
