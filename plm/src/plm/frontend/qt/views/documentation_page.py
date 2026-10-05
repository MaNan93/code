from pathlib import Path
from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.styles.tokens import (
    BG_SUBTLE, BORDER, FONT_MONO, TEXT_MAIN, TEXT_MUTED, TEXT_SUB,
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
        self.doc_browser = QtWidgets.QTextBrowser()
        self.doc_browser.setObjectName("DocumentationBrowser")
        self.doc_browser.setOpenExternalLinks(True)
        self.doc_browser.setSearchPaths([str(DOCS_DIR)])
        self.doc_browser.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarAsNeeded)
        doc_css = """
        h1 {{ color: {text_main}; font-size: 16px; font-weight: 600; margin: 16px 0 8px 0; }}
        h2, h3 {{ color: {text_main}; font-size: 14px; font-weight: 600; margin: 12px 0 6px 0; }}
        p {{ color: {text_main}; font-size: 13px; line-height: 160%; margin: 4px 0 10px 0; }}
        table {{ border-collapse: collapse; border: 1px solid {border}; border-radius: 6px; }}
        th {{ background-color: {bg_subtle}; color: {text_main}; font-size: 13px; font-weight: 600; padding: 8px 12px; border-bottom: 1px solid {border}; }}
        td {{ color: {text_main}; font-size: 13px; font-weight: 400; padding: 8px 12px; }}
        """.format(text_main=TEXT_MAIN, border=BORDER, bg_subtle=BG_SUBTLE)
        self.doc_browser.document().setDefaultStyleSheet(doc_css)
        layout.addWidget(self.doc_browser, 1)
        return content

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
        try:
            start = next(i for i, line in enumerate(lines) if line.strip() == heading)
        except StopIteration:
            return markdown
        level = len(heading) - len(heading.lstrip("#"))
        end = len(lines)
        for index in range(start + 1, len(lines)):
            stripped = lines[index].lstrip()
            if not stripped.startswith("#"):
                continue
            next_level = len(stripped) - len(stripped.lstrip("#"))
            if next_level <= level:
                end = index
                break
        return "\n".join(lines[start:end])

    def _load_document(self, filename, section=None):
        path = DOCS_DIR / filename
        try:
            markdown = path.read_text(encoding="utf-8")
        except OSError as error:
            self.doc_browser.setPlainText(f"无法读取文档：{path}\n\n{error}")
            return
        self.doc_browser.setMarkdown(
            self._extract_markdown_section(markdown, section)
        )
        self._format_document()
        self.doc_browser.verticalScrollBar().setValue(0)

    def _format_document(self):
        document = self.doc_browser.document()
        formatted_tables = set()
        block = document.begin()
        while block.isValid():
            cursor = QtGui.QTextCursor(block)
            block_format = block.blockFormat()
            heading_level = block_format.headingLevel()
            if heading_level:
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                heading_format = QtGui.QTextCharFormat()
                heading_format.setForeground(QtGui.QColor(TEXT_MAIN))
                heading_format.setFontFamily(self.doc_browser.font().family())
                heading_format.clearProperty(QtGui.QTextFormat.FontSizeAdjustment)
                heading_format.setProperty(
                    QtGui.QTextFormat.FontPixelSize,
                    16 if heading_level == 1 else 14,
                )
                heading_format.setFontWeight(QtGui.QFont.Bold)
                cursor.setCharFormat(heading_format)
                block_format.setTopMargin(16 if heading_level == 1 else 12)
                block_format.setBottomMargin(8 if heading_level == 1 else 6)
                cursor.setBlockFormat(block_format)
            elif cursor.currentTable() is None:
                block_format.setLineHeight(
                    160, QtGui.QTextBlockFormat.ProportionalHeight
                )
                cursor.setBlockFormat(block_format)

            if block.text().strip().startswith("操作："):
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                note_format = QtGui.QTextCharFormat()
                note_format.setForeground(QtGui.QColor(TEXT_MUTED))
                note_format.setProperty(QtGui.QTextFormat.FontPixelSize, 12)
                cursor.mergeCharFormat(note_format)

            table = cursor.currentTable()
            if table is not None and table.firstPosition() not in formatted_tables:
                formatted_tables.add(table.firstPosition())
                table_format = table.format()
                table_format.setBorder(1)
                table_format.setBorderStyle(QtGui.QTextFrameFormat.BorderStyle_Solid)
                table_format.setBorderBrush(QtGui.QColor(BORDER))
                table_format.setCellPadding(8)
                table_format.setCellSpacing(0)
                table_format.setWidth(
                    QtGui.QTextLength(QtGui.QTextLength.FixedLength, 600)
                )
                table.setFormat(table_format)
                for column in range(table.columns()):
                    cell = table.cellAt(0, column)
                    cell_format = cell.format()
                    cell_format.setBackground(QtGui.QColor(BG_SUBTLE))
                    cell.setFormat(cell_format)
                    cell_cursor = cell.firstCursorPosition()
                    cell_cursor.setPosition(
                        cell.lastCursorPosition().position(),
                        QtGui.QTextCursor.KeepAnchor,
                    )
                    header_format = QtGui.QTextCharFormat()
                    header_format.setForeground(QtGui.QColor(TEXT_MAIN))
                    header_format.setProperty(QtGui.QTextFormat.FontPixelSize, 13)
                    header_format.setFontWeight(QtGui.QFont.Bold)
                    cell_cursor.mergeCharFormat(header_format)
            if block_format.property(QtGui.QTextFormat.BlockCodeFence):
                cursor.select(QtGui.QTextCursor.BlockUnderCursor)
                code_format = QtGui.QTextCharFormat()
                code_format.setFontFamilies(["JetBrains Mono", "Consolas", "Courier New", "monospace"])
                code_format.setProperty(QtGui.QTextFormat.FontPixelSize, 13)
                cursor.setCharFormat(code_format)
                block_format.setLineHeight(
                    160, QtGui.QTextBlockFormat.ProportionalHeight
                )
                cursor.setBlockFormat(block_format)
            block = block.next()
