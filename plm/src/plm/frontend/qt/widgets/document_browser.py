"""Native selectable rich text with painted heading accents and code fences."""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.styles.tokens import get_theme_color


class DocumentationBrowser(QtWidgets.QTextBrowser):
    def decoration_rects(self):
        """Return document decorations in viewport coordinates, including scroll."""
        document = self.document()
        layout = document.documentLayout()
        first = document.begin()
        bounds = layout.blockBoundingRect(first)
        cursor = self.cursorRect(QtGui.QTextCursor(first))
        offset = QtCore.QPointF(cursor.x() - bounds.x() - first.blockFormat().leftMargin(),
                               cursor.y() - bounds.y())
        headings, fences = [], []
        block = first
        fence_rect = None
        while block.isValid():
            block_format = block.blockFormat()
            rect = layout.blockBoundingRect(block).translated(offset)
            if block_format.headingLevel():
                headings.append(QtCore.QRectF(rect.left(), rect.top(), 4, rect.height()))
            if block_format.property(QtGui.QTextFormat.BlockCodeFence):
                fence_rect = rect if fence_rect is None else fence_rect.united(rect)
            elif fence_rect is not None:
                fences.append(fence_rect.adjusted(0, -4, 0, 4))
                fence_rect = None
            block = block.next()
        if fence_rect is not None:
            fences.append(fence_rect.adjusted(0, -4, 0, 4))
        return headings, fences

    def paintEvent(self, event):
        # QTextBrowser draws its selectable text over this underlay. No HTML
        # tables or fake characters are inserted into copied Markdown content.
        painter = QtGui.QPainter(self.viewport())
        painter.setClipRegion(event.region())
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        headings, fences = self.decoration_rects()
        painter.setBrush(QtGui.QColor(get_theme_color("bg_document_code")))
        painter.setPen(QtGui.QPen(QtGui.QColor(get_theme_color("border_document_code")), 1))
        for rect in fences:
            if rect.intersects(QtCore.QRectF(event.rect())):
                painter.drawRoundedRect(rect.adjusted(.5, .5, -.5, -.5), 6, 6)
        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(QtGui.QColor(get_theme_color("primary")))
        for rect in headings:
            if rect.intersects(QtCore.QRectF(event.rect())):
                painter.drawRoundedRect(rect, 2, 2)
        painter.end()
        super().paintEvent(event)
