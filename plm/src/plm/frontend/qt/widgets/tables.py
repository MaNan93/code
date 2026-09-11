"""
plm_qt_tables -- EditableTable, a small QTableWidget-based editable table
for plm_qt.py's Controllers and Pipe Signals tabs.

Mirrors table.js's public shape (tool/web/table.js) and behavior: a plain
column list (some columns free-text, some a fixed dropdown), per-row +/-
buttons, and drag-to-reorder -- with an optional id_column that's read-only
and auto-renumbered (0, 1, 2, ...) after every insert/delete/reorder, the
same as both table.js and plmConsultant.py's own Tkinter EditableTable
(tool/plmConsultant.py:76) use it for Controllers' ctrl_id.

Row reorder uses QHeaderView.setSectionsMovable(True) on the vertical
header: dragging a row handle only moves the header visually, so
_on_row_moved() re-reads the header's new visual order to physically
reorder the underlying data, then resets the header back to an identity
mapping before re-rendering -- otherwise each successive drag would
compound on top of the last one's now-stale visual/logical mapping.
"""

from PyQt5 import QtCore, QtWidgets


class EditableTable(QtWidgets.QWidget):
    # columns: [{"key", "heading"?, "options"?: [...]}] -- options makes
    #          that column a QComboBox instead of a free-text cell.
    # id_column: optional key of a column that's a pure row-order index
    #          (0, 1, 2, ...), kept read-only and auto-renumbered after
    #          every insert / delete / drag-reorder.
    def __init__(self, columns, id_column=None, parent=None):
        super().__init__(parent)
        self.columns = columns
        self.id_column = id_column
        self._data = []  # seed values; live data always read from the widgets via get_rows()
        self._building = False  # guards _on_row_moved against signals fired by our own re-render

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.table = QtWidgets.QTableWidget()
        self.table.setColumnCount(len(columns) + 1)  # + one actions column
        self.table.setHorizontalHeaderLabels([c.get("heading", c["key"]) for c in columns] + [""])
        header = self.table.horizontalHeader()
        header.setMinimumSectionSize(72)
        header.setTextElideMode(QtCore.Qt.ElideRight)
        metrics = header.fontMetrics()
        for index, column in enumerate(columns):
            if column.get("width"):
                header.setSectionResizeMode(index, QtWidgets.QHeaderView.Fixed)
                heading = column.get("heading", column["key"])
                text_width = (
                    metrics.horizontalAdvance(heading)
                    if hasattr(metrics, "horizontalAdvance")
                    else metrics.width(heading)
                )
                self.table.setColumnWidth(index, max(int(column["width"]), text_width + 28))
            else:
                header.setSectionResizeMode(index, QtWidgets.QHeaderView.Stretch)
        header.setSectionResizeMode(len(columns), QtWidgets.QHeaderView.Fixed)
        self.table.setColumnWidth(len(columns), 72)
        self.table.setHorizontalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.table.verticalHeader().setDefaultSectionSize(38)
        self.table.verticalHeader().setMinimumSectionSize(34)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectItems)
        self.table.setSelectionMode(QtWidgets.QAbstractItemView.ExtendedSelection)
        self.table.verticalHeader().setSectionsMovable(True)
        self.table.verticalHeader().sectionMoved.connect(self._on_row_moved)
        layout.addWidget(self.table)

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
        if self.id_column:
            self._renumber()
        self._render_body()

    def insert_row_below(self, idx):
        self._data = self.get_rows()
        new_row = {c["key"]: (c["options"][0] if c.get("options") else "") for c in self.columns}
        self._data.insert(idx + 1, new_row)
        if self.id_column:
            self._renumber()
        self._render_body()

    def delete_row(self, idx):
        self._data = self.get_rows()
        if len(self._data) <= 1:
            return  # always keep at least one row -- an empty table can't be saved anyway
        del self._data[idx]
        if self.id_column:
            self._renumber()
        self._render_body()

    def _renumber(self):
        for i, r in enumerate(self._data):
            r[self.id_column] = str(i)

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
                    combo = QtWidgets.QComboBox()
                    combo.addItems(col["options"])
                    if value in col["options"]:
                        combo.setCurrentText(value)
                    self.table.setCellWidget(r, c, combo)
                else:
                    item = QtWidgets.QTableWidgetItem(str(value))
                    if key == self.id_column:
                        item.setFlags(item.flags() & ~QtCore.Qt.ItemIsEditable)
                    self.table.setItem(r, c, item)
            self.table.setCellWidget(r, len(self.columns), self._make_actions_widget(r))
        self._building = False

    def _make_actions_widget(self, row_idx):
        widget = QtWidgets.QWidget()
        hl = QtWidgets.QHBoxLayout(widget)
        hl.setContentsMargins(2, 0, 2, 0)
        hl.setSpacing(2)
        plus = QtWidgets.QToolButton()
        plus.setObjectName("rowPlusBtn")
        plus.setText("+")
        plus.setToolTip("Insert row below")
        plus.clicked.connect(lambda _checked=False, i=row_idx: self.insert_row_below(i))
        minus = QtWidgets.QToolButton()
        minus.setObjectName("rowMinusBtn")
        minus.setText("−")
        minus.setToolTip("Delete this row")
        minus.clicked.connect(lambda _checked=False, i=row_idx: self.delete_row(i))
        hl.addWidget(plus)
        hl.addWidget(minus)
        return widget

    # ------------------------------------------------------------ drag-to-reorder
    def _on_row_moved(self, logical_index, old_visual, new_visual):
        if self._building:
            return
        header = self.table.verticalHeader()
        live = self.get_rows()
        new_data = [live[header.logicalIndex(v)] for v in range(len(live))]
        self._data = new_data
        if self.id_column:
            self._renumber()
        self._reset_header_order()
        self._render_body()

    def _reset_header_order(self):
        """Restore the vertical header to an identity visual<->logical
        mapping. Needed because _render_body() rebuilds row content in the
        new order but the header itself keeps its own separate visual
        permutation across content changes -- without this, a second drag
        would compound on top of the first one's now-stale mapping."""
        header = self.table.verticalHeader()
        header.blockSignals(True)
        for logical in range(header.count()):
            current_visual = header.visualIndex(logical)
            if current_visual != logical:
                header.moveSection(current_visual, logical)
        header.blockSignals(False)
