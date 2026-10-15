"""Rendered document decorations preserve native text, selection and scrolling."""

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtGui, QtWidgets
from plm.frontend.qt.services.themes import apply_application_theme
from plm.frontend.qt.styles.tokens import FONT_SIZE_BODY, get_theme_color
from plm.frontend.qt.views.documentation_page import DocumentationPage
from qt_test_support import dispose_new_widgets, preserve_application_state, wait_for_idle


class DocumentDecorationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        preserve_application_state(self, self.app)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.page = DocumentationPage()
        self.page.resize(800, 600)
        self.page.show()
        wait_for_idle(self.app)

    def test_headings_and_rounded_code_are_painted_in_both_themes(self):
        markdown = "# Main heading\n\nProse.\n\n```sv\nmodule sample;\nendmodule\n```\n\n## Section\n\nAfter."
        for theme in ("light", "dark"):
            with self.subTest(theme=theme):
                apply_application_theme(theme)
                self.page._render_document(markdown, reset_scroll=True)
                self.app.processEvents()
                browser = self.page.doc_browser
                headings, fences = browser.decoration_rects()
                self.assertEqual(len(headings), 2)
                self.assertEqual(len(fences), 1)
                self.assertGreater(headings[0].height(), headings[1].height())
                block = browser.document().begin()
                self.assertGreater(block.begin().fragment().charFormat().property(QtGui.QTextFormat.FontPixelSize), FONT_SIZE_BODY)
                picture = browser.viewport().grab().toImage()
                ratio = picture.devicePixelRatio()
                def color(x, y):
                    return picture.pixelColor(round(x * ratio), round(y * ratio)).name()
                heading, fence = headings[0], fences[0]
                self.assertEqual(color(heading.center().x(), heading.center().y()), get_theme_color("primary").lower())
                # Sample empty right-side padding, away from native text.
                self.assertEqual(color(fence.right() - 10, fence.center().y()), get_theme_color("bg_document_code").lower())
                self.assertNotEqual(color(fence.left(), fence.top()), get_theme_color("bg_document_code").lower())
                self.assertIn("module sample;\nendmodule", browser.toPlainText())

    def test_decorations_follow_scroll_and_selection_stays_native(self):
        self.page._render_document("# Heading\n\n```sv\nmodule sample;\nendmodule\n```\n\n" + "Paragraph.\n\n" * 70)
        browser = self.page.doc_browser
        self.app.processEvents()
        before = browser.decoration_rects()[1][0]
        browser.verticalScrollBar().setValue(30)
        self.app.processEvents()
        after = browser.decoration_rects()[1][0]
        self.assertAlmostEqual(before.top() - after.top(), 30, delta=1)
        cursor = browser.document().find("module sample;")
        browser.setTextCursor(cursor)
        self.assertEqual(browser.textCursor().selectedText(), "module sample;")
        browser.copy()
        self.assertEqual(self.app.clipboard().text(), "module sample;")

    def test_table_after_code_does_not_cover_the_bottom_rounded_corners(self):
        self.page._render_document("```sv\nmodule sample;\nendmodule\n```\n\n| A | B |\n|---|---|\n| x | y |")
        browser = self.page.doc_browser
        self.app.processEvents()
        fence = browser.decoration_rects()[1][0]
        document = browser.document()
        table = next(frame for frame in document.rootFrame().childFrames()
                     if isinstance(frame, QtGui.QTextTable))
        first = document.begin()
        offset = browser.cursorRect(QtGui.QTextCursor(first)).top() - document.documentLayout().blockBoundingRect(first).top()
        table_top = document.documentLayout().frameBoundingRect(table).top() + offset
        self.assertGreaterEqual(table_top - fence.bottom(), 6)


if __name__ == "__main__":
    unittest.main()
