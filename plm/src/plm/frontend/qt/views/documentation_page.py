from pathlib import Path
import re
import unicodedata
from PyQt5 import QtCore, QtGui, QtWidgets, sip
from plm.frontend.qt.services.tasks import TaskRunner
from plm.frontend.qt.widgets.document_browser import DocumentationBrowser
from plm.frontend.qt.styles.tokens import get_theme_color
from plm.frontend.qt.styles.tokens import (
    FONT_CODE_PRIMARY, FONT_WEIGHT_MEDIUM, FONT_SIZE_BODY,
    FONT_SIZE_DOC_TITLE, FONT_SIZE_DOC_SECTION, FONT_SIZE_DOC_SUBSECTION,
)
from .secondary_page import SecondaryPage
DOCS_DIR = Path(__file__).resolve().parents[3] / "docs"

class DocumentationPage(SecondaryPage):
    def __init__(self, parent=None):
        super().__init__("docs", parent)

    def _build_content(self):
        return self._build_docs_content()

    def _build_docs_content(self):
        content = QtWidgets.QWidget()
        content.setObjectName("SecondaryContent")
        layout = QtWidgets.QVBoxLayout(content)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        self.doc_browser = DocumentationBrowser()
        self.doc_browser.setObjectName("DocumentationBrowser")
        self.doc_browser.setOpenExternalLinks(True)
        self.doc_browser.setSearchPaths([str(DOCS_DIR)])
        self.doc_browser.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarAsNeeded)
        self._apply_document_css()
        layout.addWidget(self.doc_browser, 1)
        return content

    def _apply_document_css(self):
        doc_css = """
        h1 {{ color: {text_main}; font-size: {heading_size}px; font-weight: 600; margin: 16px 0 8px 0; }}
        h2, h3 {{ color: {text_main}; font-size: {subheading_size}px; font-weight: 600; margin: 12px 0 6px 0; }}
        p {{ color: {text_main}; font-size: {body_size}px; line-height: 160%; margin: 4px 0 10px 0; }}
        table {{ border-collapse: collapse; border: none; }}
        th {{ background-color: {bg_subtle}; color: {text_main}; font-size: {body_size}px; font-weight: {header_weight}; padding: 8px 16px; }}
        td {{ color: {text_main}; font-size: {body_size}px; font-weight: 400; padding: 8px 16px; }}
        """.format(
            text_main=get_theme_color("text_main"), bg_subtle=get_theme_color("bg_subtle"),
            heading_size=FONT_SIZE_DOC_TITLE,
            subheading_size=FONT_SIZE_DOC_SECTION,
            body_size=FONT_SIZE_BODY,
            header_weight=FONT_WEIGHT_MEDIUM,
        )
        self.doc_browser.document().setDefaultStyleSheet(doc_css)

    def refresh_theme(self):
        self._apply_document_css()
        if hasattr(self, "_markdown"):
            self._render_document(self._markdown)

    def _render_document(self, markdown, reset_scroll=False):
        self._markdown = markdown
        previous = self.doc_browser.document()
        cursor = self.doc_browser.textCursor()
        position, anchor = cursor.position(), cursor.anchor()
        horizontal = self.doc_browser.horizontalScrollBar().value()
        vertical = self.doc_browser.verticalScrollBar().value()
        document = QtGui.QTextDocument(self.doc_browser)
        document.setDefaultFont(previous.defaultFont())
        document.setDefaultStyleSheet(previous.defaultStyleSheet())
        document.setUndoRedoEnabled(previous.isUndoRedoEnabled())
        document.setMarkdown(markdown)
        self._format_document(document)
        self.doc_browser.setDocument(document)
        if not reset_scroll:
            cursor = QtGui.QTextCursor(document)
            limit = document.characterCount() - 1
            cursor.setPosition(min(anchor, limit))
            cursor.setPosition(min(position, limit), QtGui.QTextCursor.KeepAnchor)
            self.doc_browser.setTextCursor(cursor)
        if not sip.isdeleted(previous):
            previous.deleteLater()
        self.doc_browser.horizontalScrollBar().setValue(0 if reset_scroll else horizontal)
        self.doc_browser.verticalScrollBar().setValue(0 if reset_scroll else vertical)

    def _show_section(self, index):
        docs = (
            (
                "qt_frontend_guide.md",
                None,
            ),
            (
                "tool_usage.md",
                "## 2. 配置文件格式（`config/` 下三个 CSV）",
            ),
            (
                "tool_usage.md",
                "## 3. `plm generate`：生成匹配的 RTL 与 testbench",
            ),
        )
        filename, section = docs[index]
        self._load_document(filename, section)

    @staticmethod
    def _extract_markdown_section(markdown, heading):
        if not heading:
            return markdown
        lines = markdown.splitlines()
        def normalize(title):
            title = unicodedata.normalize("NFKC", title).casefold()
            title = title.translate(str.maketrans({"`": "", "*": "", "_": "", "~": "",
                                                   "–": "-", "—": "-"}))
            return re.sub(r"\s+", "", title)

        heading_pattern = re.compile(r"^\s*(#{1,6})\s+(.+?)\s*#*\s*$")
        target = heading_pattern.match(heading.strip())
        wanted = normalize(target.group(2) if target else heading.strip())
        start = None
        level = None
        fence = None
        for index, line in enumerate(lines):
            delimiter = re.match(r"^\s*(`{3,}|~{3,})", line)
            if delimiter:
                marker = delimiter.group(1)
                if fence is None:
                    fence = marker
                elif marker[0] == fence[0] and len(marker) >= len(fence):
                    fence = None
                continue
            match = heading_pattern.match(line) if fence is None else None
            if match is None:
                continue
            next_level = len(match.group(1))
            if start is None:
                if normalize(match.group(2)) == wanted:
                    start, level = index, next_level
            elif next_level <= level:
                return "\n".join(lines[start:index])
        return markdown if start is None else "\n".join(lines[start:])

    def _load_document(self, filename, section=None):
        if not hasattr(self, "tasks"):
            self.tasks = TaskRunner(self)
            self._document_revision = 0
        self._document_revision += 1
        revision = self._document_revision
        path = DOCS_DIR / filename

        def read(_progress):
            markdown = path.read_text(encoding="utf-8")
            return DocumentationPage._extract_markdown_section(markdown, section)

        def finished(markdown):
            if revision == self._document_revision:
                # Format before attaching: each edit otherwise lays out the
                # visible browser again, including Markdown table insertion.
                self._render_document(markdown, reset_scroll=True)

        def failed(error):
            if revision == self._document_revision:
                self.doc_browser.setPlainText(f"无法读取文档：{path}\n\n{error}")

        self.tasks.submit(read, finished, failed)

    def _format_document(self, document=None):
        document = document if document is not None else self.doc_browser.document()
        cursor = QtGui.QTextCursor(document)
        cursor.beginEditBlock()
        try:
            self._format_document_blocks(document)
        finally:
            cursor.endEditBlock()

    @staticmethod
    def _drop_empty_fence_tails(document):
        """Qt's Markdown import ends every fence with an empty code line."""
        fence = QtGui.QTextFormat.BlockCodeFence
        tails = []
        block = document.begin()
        while block.isValid():
            if (block.blockFormat().property(fence) and not block.text()
                    and block.previous().isValid()
                    and block.previous().blockFormat().property(fence)
                    and not block.next().blockFormat().property(fence)):
                tails.append(block.position())
            block = block.next()
        for position in reversed(tails):
            cursor = QtGui.QTextCursor(document)
            cursor.setPosition(position)
            cursor.deletePreviousChar()

    def _format_document_blocks(self, document):
        self._drop_empty_fence_tails(document)
        formatted_tables = set()
        block = document.begin()
        while block.isValid():
            cursor = QtGui.QTextCursor(block)
            block_format = block.blockFormat()
            heading_level = block_format.headingLevel()
            if heading_level:
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                heading_format = QtGui.QTextCharFormat()
                heading_format.setForeground(QtGui.QColor(get_theme_color("text_main")))
                heading_format.setFontFamily(self.doc_browser.font().family())
                heading_format.clearProperty(QtGui.QTextFormat.FontSizeAdjustment)
                heading_format.setProperty(
                    QtGui.QTextFormat.FontPixelSize,
                    (FONT_SIZE_DOC_TITLE if heading_level == 1 else
                     FONT_SIZE_DOC_SECTION if heading_level == 2 else FONT_SIZE_DOC_SUBSECTION),
                )
                heading_format.setFontWeight(QtGui.QFont.Bold)
                cursor.setCharFormat(heading_format)
                block_format.setTopMargin(16 if heading_level == 1 else 12)
                block_format.setBottomMargin(8 if heading_level == 1 else 6)
                block_format.setLeftMargin(12)
                # BlockUnderCursor also selects the separator that ends the
                # previous block; a block format set through that selection
                # would restyle the previous paragraph as well.
                QtGui.QTextCursor(block).setBlockFormat(block_format)
            elif cursor.currentTable() is None:
                block_format.setLineHeight(
                    160, QtGui.QTextBlockFormat.ProportionalHeight
                )
                cursor.setBlockFormat(block_format)

            if block.text().strip().startswith("操作："):
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                note_format = QtGui.QTextCharFormat()
                note_format.setForeground(QtGui.QColor(get_theme_color("text_muted")))
                note_format.setProperty(
                    QtGui.QTextFormat.FontPixelSize, FONT_SIZE_BODY
                )
                cursor.mergeCharFormat(note_format)

            table = cursor.currentTable()
            if table is not None and table.firstPosition() not in formatted_tables:
                formatted_tables.add(table.firstPosition())
                table_format = table.format()
                table_format.setBorder(0)
                table_format.setBorderStyle(QtGui.QTextFrameFormat.BorderStyle_None)
                table_format.setCellPadding(8)
                table_format.setCellSpacing(0)
                table_format.setWidth(
                    QtGui.QTextLength(QtGui.QTextLength.PercentageLength, 100)
                )
                table.setFormat(table_format)
                for column in range(table.columns()):
                    cell = table.cellAt(0, column)
                    cell_format = cell.format()
                    cell_format.setBackground(QtGui.QColor(get_theme_color("bg_subtle")))
                    cell.setFormat(cell_format)
                    cell_cursor = cell.firstCursorPosition()
                    cell_cursor.setPosition(
                        cell.lastCursorPosition().position(),
                        QtGui.QTextCursor.KeepAnchor,
                    )
                    header_format = QtGui.QTextCharFormat()
                    header_format.setForeground(QtGui.QColor(get_theme_color("text_main")))
                    header_format.setProperty(
                        QtGui.QTextFormat.FontPixelSize, FONT_SIZE_BODY
                    )
                    header_format.setFontWeight(QtGui.QFont.Medium)
                    cell_cursor.mergeCharFormat(header_format)
            if block_format.property(QtGui.QTextFormat.BlockCodeFence):
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                code_format = QtGui.QTextCharFormat()
                code_format.setFontFamilies([FONT_CODE_PRIMARY, "Courier New", "monospace"])
                code_format.setForeground(QtGui.QColor(get_theme_color("text_document_code")))
                code_format.setProperty(
                    QtGui.QTextFormat.FontPixelSize, FONT_SIZE_BODY
                )
                cursor.setCharFormat(code_format)
                own = QtGui.QTextCursor(block)
                own.setBlockCharFormat(code_format)
                fence = QtGui.QTextFormat.BlockCodeFence
                first = not block.previous().blockFormat().property(fence)
                last = not block.next().blockFormat().property(fence)
                block_format.clearBackground()
                block_format.setLeftMargin(12)
                block_format.setRightMargin(12)
                # Reserve padding around the whole painted fence, keeping
                # adjacent source lines together.
                block_format.setTopMargin(10 if first else 0)
                block_format.setBottomMargin(10 if last else 0)
                # Keep the native glyph line height within the rounded box.
                block_format.setLineHeight(0, QtGui.QTextBlockFormat.SingleHeight)
                own.setBlockFormat(block_format)
            block = block.next()
