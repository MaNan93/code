"""Editable Qt tables for Controllers and Pipe Signals.

Cells support free text or fixed-option combo boxes. Whole rows can be
dragged to reorder them, while a context menu inserts or deletes rows.
Controller IDs remain editable and retain their values after reordering.
"""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.widgets import sap_icons
from plm.frontend.qt.widgets.theme import ACCENT, RoundedComboBox


_DRAG_HANDLE_ICON = None


def drag_handle_icon():
    """Return the shared six-dot row-reorder handle icon."""
    global _DRAG_HANDLE_ICON
    if _DRAG_HANDLE_ICON is None:
        _DRAG_HANDLE_ICON = sap_icons.icon(
            "vertical-grip", color="#758ca4", size=18
        )
    return _DRAG_HANDLE_ICON


def drag_handle_item():
    item = QtWidgets.QTableWidgetItem()
    item.setIcon(drag_handle_icon())
    item.setToolTip("Drag to reorder")
    item.setTextAlignment(QtCore.Qt.AlignCenter)
    return item


def _ui_scale():
    """Scaling factor relative to the 13 px design baseline."""
    app = QtWidgets.QApplication.instance()
    px = app.font().pixelSize() if app else 13
    return max(px, 11) / 13.0


class RowDragTable(QtWidgets.QTableWidget):
    """Table with whole-row selection and a native drag ghost/drop line."""

    rowMoveRequested = QtCore.pyqtSignal(int, int)
    # Emitted for a right-click (or Menu-key press) anywhere in the table,
    # row == -1 if it landed on no row. A direct contextMenuEvent()
    # override, not the usual viewport()-CustomContextMenu-policy idiom --
    # that idiom silently never fires for cells with no cell widget on top
    # of them (only cells hosting a combo box got a menu), while this is
    # guaranteed to run for every click regardless of what's in the cell.
    rowContextMenuRequested = QtCore.pyqtSignal(int, QtCore.QPoint)
    MIME_TYPE = "application/x-plm-table-row"

    def __init__(self, drag_columns=None, parent=None):
        super().__init__(parent)
        self._drag_columns = set(drag_columns) if drag_columns is not None else None
        self._row_drag_start = None
        self._row_drag_source = -1
        self._drop_before_row = -1
        self.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        self.setAcceptDrops(True)
        self.viewport().setAcceptDrops(True)
        self.setDropIndicatorShown(False)

    def mousePressEvent(self, event):
        index = self.indexAt(event.pos())
        super().mousePressEvent(event)
        allowed = index.isValid() and (
            self._drag_columns is None or index.column() in self._drag_columns
        )
        if event.button() == QtCore.Qt.LeftButton and allowed:
            self.selectRow(index.row())
            self._row_drag_start = QtCore.QPoint(event.pos())
            self._row_drag_source = index.row()
        else:
            self._row_drag_start = None
            self._row_drag_source = -1

    def contextMenuEvent(self, event):
        index = self.indexAt(event.pos())
        self.rowContextMenuRequested.emit(index.row() if index.isValid() else -1, event.globalPos())
        event.accept()

    def mouseMoveEvent(self, event):
        if (
            self._row_drag_start is not None
            and event.buttons() & QtCore.Qt.LeftButton
            and (event.pos() - self._row_drag_start).manhattanLength()
            >= QtWidgets.QApplication.startDragDistance()
        ):
            row = self._row_drag_source
            rect = self.visualRect(self.model().index(row, 0))
            row_rect = QtCore.QRect(0, rect.top(), self.viewport().width(), rect.height())
            pixmap = self.viewport().grab(row_rect)
            drag = QtGui.QDrag(self)
            mime = QtCore.QMimeData()
            mime.setData(self.MIME_TYPE, str(row).encode("ascii"))
            drag.setMimeData(mime)
            drag.setPixmap(pixmap)
            drag.setHotSpot(QtCore.QPoint(min(event.pos().x(), pixmap.width() - 1), rect.height() // 2))
            drag.exec_(QtCore.Qt.MoveAction)
            self._row_drag_start = None
            self._row_drag_source = -1
            self._clear_drop_line()
            return
        super().mouseMoveEvent(event)

    def dragEnterEvent(self, event):
        if event.source() is self and event.mimeData().hasFormat(self.MIME_TYPE):
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragMoveEvent(self, event):
        if event.source() is not self or not event.mimeData().hasFormat(self.MIME_TYPE):
            event.ignore()
            return
        self._drop_before_row = self._drop_row_at(event.pos())
        self.viewport().update()
        event.acceptProposedAction()

    def dragLeaveEvent(self, event):
        self._clear_drop_line()
        super().dragLeaveEvent(event)

    def dropEvent(self, event):
        if event.source() is not self or not event.mimeData().hasFormat(self.MIME_TYPE):
            event.ignore()
            return
        source = int(bytes(event.mimeData().data(self.MIME_TYPE)).decode("ascii"))
        before = self._drop_row_at(event.pos())
        destination = before - 1 if before > source else before
        destination = max(0, min(destination, self.rowCount() - 1))
        self._clear_drop_line()
        if destination != source:
            self.rowMoveRequested.emit(source, destination)
        event.setDropAction(QtCore.Qt.MoveAction)
        event.accept()

    def _drop_row_at(self, pos):
        index = self.indexAt(pos)
        if not index.isValid():
            return self.rowCount()
        rect = self.visualRect(self.model().index(index.row(), 0))
        return index.row() + (1 if pos.y() > rect.center().y() else 0)

    def _clear_drop_line(self):
        self._drop_before_row = -1
        self.viewport().update()

    def paintEvent(self, event):
        super().paintEvent(event)
        if self._drop_before_row < 0:
            return
        if self._drop_before_row >= self.rowCount():
            rect = self.visualRect(self.model().index(self.rowCount() - 1, 0))
            y = rect.bottom()
        else:
            rect = self.visualRect(self.model().index(self._drop_before_row, 0))
            y = rect.top()
        painter = QtGui.QPainter(self.viewport())
        painter.setPen(QtGui.QPen(QtGui.QColor(ACCENT), 2))
        painter.drawLine(0, y, self.viewport().width(), y)


class _PaddedItemDelegate(QtWidgets.QStyledItemDelegate):
    """Paint table text with a reliable two-space visual inset."""

    HORIZONTAL_PADDING = 12

    def paint(self, painter, option, index):
        styled = QtWidgets.QStyleOptionViewItem(option)
        self.initStyleOption(styled, index)
        text = styled.text
        styled.text = ""
        style = styled.widget.style() if styled.widget else QtWidgets.QApplication.style()
        style.drawControl(QtWidgets.QStyle.CE_ItemViewItem, styled, painter, styled.widget)

        text_rect = option.rect.adjusted(self.HORIZONTAL_PADDING, 0, -self.HORIZONTAL_PADDING, 0)
        selected = bool(option.state & QtWidgets.QStyle.State_Selected)
        role = QtGui.QPalette.HighlightedText if selected else QtGui.QPalette.Text
        painter.save()
        painter.setPen(styled.palette.color(role))
        text = option.fontMetrics.elidedText(text, styled.textElideMode, max(0, text_rect.width()))
        painter.drawText(text_rect, styled.displayAlignment | QtCore.Qt.AlignVCenter, text)
        painter.restore()

    def updateEditorGeometry(self, editor, option, index):
        editor.setGeometry(option.rect.adjusted(self.HORIZONTAL_PADDING, 1, -self.HORIZONTAL_PADDING, -1))


class EditableTable(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()

    # columns: [{"key", "heading"?, "options"?: [...]}] -- options makes
    #          that column a QComboBox instead of a free-text cell.
    # id_column: optional key of an identifier column. It stays editable and
    #          keeps its value across reorders (the ids are referenced by
    #          lane_mapping.csv, so renumbering them would silently
    #          re-point every mapped lane); it only gets filled in for
    #          rows this widget creates itself, with the lowest integer
    #          not already taken, since a blank id fails validation.
    def __init__(self, columns, id_column=None, parent=None):
        super().__init__(parent)
        self.columns = columns
        self.id_column = id_column
        self._data = []  # seed values; live data always read from the widgets via get_rows()
        self._building = False  # guards _on_row_moved against signals fired by our own re-render
        self._column_resize_pending = False

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.table = RowDragTable()
        self.table.setItemDelegate(_PaddedItemDelegate(self.table))
        self.table.setColumnCount(len(columns))
        self.table.setHorizontalHeaderLabels([c.get("heading", c["key"]) for c in columns])
        header = self.table.horizontalHeader()
        header.setTextElideMode(QtCore.Qt.ElideRight)
        for index, column in enumerate(columns):
            header.setSectionResizeMode(index, QtWidgets.QHeaderView.Fixed)
        self.table.setHorizontalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.table.setAlternatingRowColors(True)
        self.table.rowContextMenuRequested.connect(self._on_row_context_menu)
        row_header = self.table.verticalHeader()
        row_header.hide()
        self.table.rowMoveRequested.connect(self._on_row_drop)
        self.table.itemChanged.connect(self._on_item_changed)
        layout.addWidget(self.table)
        self._schedule_column_resize()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._schedule_column_resize()

    def changeEvent(self, event):
        super().changeEvent(event)
        if event.type() in (QtCore.QEvent.FontChange, QtCore.QEvent.StyleChange):
            self._schedule_column_resize()

    def _schedule_column_resize(self):
        """Run after Qt has applied the current font and parent layout."""
        if self._column_resize_pending:
            return
        self._column_resize_pending = True
        QtCore.QTimer.singleShot(0, self._resize_columns)

    def _resize_columns(self):
        self._column_resize_pending = False
        scale = _ui_scale()
        header = self.table.horizontalHeader()
        metrics = header.fontMetrics()
        minimums = []
        flexible = []

        header.setMinimumSectionSize(int(48 * scale))
        self.table.verticalHeader().setDefaultSectionSize(int(38 * scale))
        self.table.verticalHeader().setMinimumSectionSize(int(34 * scale))

        for index, column in enumerate(self.columns):
            heading = column.get("heading", column["key"])
            text_width = (
                metrics.horizontalAdvance(heading)
                if hasattr(metrics, "horizontalAdvance")
                else metrics.width(heading)
            )
            design_width = int(column.get("width", 0) * scale)
            minimums.append(max(design_width, text_width + int(28 * scale)))
            if not column.get("width"):
                flexible.append(index)

        available = self.table.viewport().width()
        fixed_total = sum(minimums[i] for i in range(len(minimums)) if i not in flexible)
        flex_minimum = sum(minimums[i] for i in flexible)
        extra = max(0, available - fixed_total - flex_minimum)
        share, remainder = divmod(extra, len(flexible)) if flexible else (0, 0)

        for index, minimum in enumerate(minimums):
            if index in flexible:
                rank = flexible.index(index)
                minimum += share + (1 if rank < remainder else 0)
            self.table.setColumnWidth(index, minimum)

    # ------------------------------------------------------------ public data interface
    def get_rows(self):
        """Read current values straight out of the live widgets (not
        self._data, which only ever seeds a render) so an in-progress edit
        is captured even without a focus-out event."""
        rows = []
        for r in range(self.table.rowCount()):
            row = {}
            for c, col in enumerate(self.columns):
                w = self.table.cellWidget(r, c)
                if isinstance(w, QtWidgets.QComboBox):
                    row[col["key"]] = w.currentText()
                else:
                    item = self.table.item(r, c)
                    row[col["key"]] = item.text() if item else ""
            rows.append(row)
        return rows

    def set_rows(self, rows):
        self._data = [dict(r) for r in (rows or [])]
        self._render_body()

    def _on_item_changed(self, _item):
        if not self._building:
            self.changed.emit()

    def _on_combo_changed(self, _text):
        if not self._building:
            self.changed.emit()

    def set_cell_errors(self, errors):
        """Highlight invalid cells; errors maps (row, column-key) to text."""
        errors = errors or {}
        previous = self.table.blockSignals(True)
        try:
            for row in range(self.table.rowCount()):
                for column_index, column in enumerate(self.columns):
                    message = errors.get((row, column["key"]), "")
                    widget = self.table.cellWidget(row, column_index)
                    if isinstance(widget, QtWidgets.QComboBox):
                        widget.setProperty("validationError", bool(message))
                        widget.setToolTip(message)
                        widget.style().unpolish(widget)
                        widget.style().polish(widget)
                    else:
                        item = self.table.item(row, column_index)
                        if item is None:
                            continue
                        item.setToolTip(message)
                        if message:
                            item.setBackground(QtGui.QColor("#fff0f0"))
                            item.setForeground(QtGui.QColor("#bb0000"))
                        else:
                            item.setData(QtCore.Qt.BackgroundRole, None)
                            item.setData(QtCore.Qt.ForegroundRole, None)
        finally:
            self.table.blockSignals(previous)

    def insert_row_below(self, idx):
        self._insert_row_at(idx + 1)

    def insert_row_above(self, idx):
        self._insert_row_at(idx)

    def _insert_row_at(self, idx):
        self._data = self.get_rows()
        new_row = {c["key"]: (c["options"][0] if c.get("options") else "") for c in self.columns}
        if self.id_column:
            new_row[self.id_column] = self._next_free_id()
        self._data.insert(idx, new_row)
        self._render_body()
        self.changed.emit()

    def _next_free_id(self):
        """Lowest non-negative integer not already used in id_column.
        Non-numeric ids (the column is free text) just don't reserve
        anything."""
        used = set()
        for row in self._data:
            value = str(row.get(self.id_column, "")).strip()
            if value.isdigit():
                used.add(int(value))
        candidate = 0
        while candidate in used:
            candidate += 1
        return str(candidate)

    def delete_row(self, idx):
        self._data = self.get_rows()
        if len(self._data) <= 1:
            return  # always keep at least one row -- an empty table can't be saved anyway
        del self._data[idx]
        self._render_body()
        self.changed.emit()

    # ------------------------------------------------------------ rendering
    def _render_body(self):
        self._building = True
        self.table.setRowCount(0)
        self.table.setRowCount(len(self._data))
        for r, row in enumerate(self._data):
            for c, col in enumerate(self.columns):
                key = col["key"]
                value = row.get(key, "")
                if col.get("options"):
                    combo = RoundedComboBox()
                    combo.addItems(col["options"])
                    if value in col["options"]:
                        combo.setCurrentText(value)
                    combo.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
                    combo.customContextMenuRequested.connect(
                        lambda pos, widget=combo, row_index=r:
                        self._show_row_context_menu(row_index, widget.mapToGlobal(pos))
                    )
                    combo.currentTextChanged.connect(self._on_combo_changed)
                    self.table.setCellWidget(r, c, combo)
                else:
                    item = QtWidgets.QTableWidgetItem(str(value))
                    self.table.setItem(r, c, item)
        self._building = False

    def _on_row_context_menu(self, row, global_pos):
        if row < 0:
            row = self.table.currentRow()
            if row < 0 and self.table.rowCount():
                row = self.table.rowCount() - 1
        self._show_row_context_menu(row, global_pos)

    def _show_row_context_menu(self, row, global_pos):
        if row >= 0:
            self.table.selectRow(row)
        menu = QtWidgets.QMenu(self.table)
        if row >= 0:
            insert_above = menu.addAction("Insert row above")
            insert_below = menu.addAction("Insert row below")
            menu.addSeparator()
            delete_current = menu.addAction("Delete current row")
        else:
            insert_above = None
            insert_below = menu.addAction("Insert row")
            delete_current = None
        chosen = menu.exec_(global_pos)
        if insert_above is not None and chosen == insert_above:
            self.insert_row_above(row)
        elif chosen == insert_below:
            self.insert_row_below(row)
        elif delete_current is not None and chosen == delete_current:
            self.delete_row(row)

    # ------------------------------------------------------------ drag-to-reorder
    def _on_row_drop(self, source, destination):
        if self._building:
            return
        live = self.get_rows()
        row = live.pop(source)
        live.insert(destination, row)
        self._data = live
        self._render_body()
        self.changed.emit()
