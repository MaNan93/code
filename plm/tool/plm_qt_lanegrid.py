"""
plm_qt_lanegrid -- LaneGrid, the paint-drag Lane Mapping grid widget for
plm_qt.py.

Port of the web front end's lanegrid.js (tool/web/lanegrid.js), itself a
port of plmConsultant.py's Tkinter LaneMappingGrid (tool/plmConsultant.py:512):
click a controller swatch to make it the "active paint controller", then
click-and-drag across a block of lane cells to paint them that controller's
color (repainted from a snapshot on every step, so backtracking un-paints
cleanly) -- a plain click with no movement still paints one cell. Rows are
modes, columns are lanes; each cell holds the raw "ctrl_id-ctrl_lane"
string the CSV already uses.

Two things are simpler here than in either older port, taking advantage of
native Qt behavior:
  - Double-click-to-edit uses the cell's own text (the raw "ctrl_id-port"
    string) via QTableWidget's native item editing -- no custom overlay
    input like lanegrid.js's needed. Qt naturally delivers a double-click
    as mousePressEvent + mouseReleaseEvent + mouseDoubleClickEvent (not a
    second mousePressEvent the way a browser's `event.detail` does), so
    the roll-back-before-editing behavior (undoing the first click's own
    paint stroke before opening the editor on the clean value) is simpler
    to express: the single mousePressEvent for the first click has already
    snapshotted and painted, so mouseDoubleClickEvent just restores that
    same snapshot before calling editItem().
  - Mode-row reorder reuses QHeaderView.setSectionsMovable(True), the same
    approach plm_qt_tables.EditableTable uses for Controllers/Pipe
    Signals, instead of lanegrid.js's native HTML5 drag-and-drop.
"""

import copy
import math

from PyQt5 import QtCore, QtGui, QtWidgets

LANE_GRID_PALETTE = [
    "#4C78A8", "#F58518", "#54A24B", "#E45756", "#72B7B2",
    "#EECA3B", "#B279A2", "#FF9DA6", "#9D755D", "#17BECF",
    "#B5B02B", "#7B6FD1",
]
LANE_GRID_UNASSIGNED_BG = "#e6e6e6"

# Lane column widths step up geometrically as the lane count drops, same
# rule as lanegrid.js's _applyLaneWidth (tool/web/lanegrid.js:126): x32 is
# the reference (fills the available width) and each halving of the lane
# count makes every lane column LANE_W_RATIO times wider -- x16 = 1.68x
# x32's width, x8 = 1.68x x16's, and so on -- recomputed on every resize
# and every lane-count change so the grid stays proportional at any window
# size instead of just using whatever QTableWidget's own auto-sizing picks.
LANE_W_RATIO = 1.68
LANE_MODE_W = 64
LANE_ACTIONS_W = 68
LANE_MIN_CELL = 26


def _contrast_text_color(hex_color):
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return "#000000" if luminance > 140 else "#ffffff"


class LaneGrid(QtWidgets.QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.lane_count = 0
        self.data = []  # [{"mode": "0", "lane0": "0-0", ...}, ...]
        self.controllers = []  # [{"ctrl_id":..., "ctrl_name":...}, ...]
        self.color_by_id = {}
        self.active_ctrl_id = None

        self._building = False  # guards signal handlers against our own re-renders
        self._drag_active = False
        self._drag_anchor = None
        self._drag_current = None
        self._drag_snapshot = None

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.palette_bar = QtWidgets.QWidget()
        self.palette_layout = QtWidgets.QHBoxLayout(self.palette_bar)
        self.palette_layout.setContentsMargins(0, 0, 0, 4)
        layout.addWidget(self.palette_bar)

        self.table = _LaneTable(self)
        self.table.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.table.verticalHeader().setSectionsMovable(True)
        self.table.verticalHeader().sectionMoved.connect(self._on_row_moved)
        self.table.verticalHeader().setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        self.table.verticalHeader().customContextMenuRequested.connect(self._on_header_context_menu)
        self.table.itemChanged.connect(self._on_item_changed)
        layout.addWidget(self.table)

    # ------------------------------------------------------------ public data interface
    def get_rows(self):
        return [dict(r) for r in self.data]

    def set_rows(self, rows):
        self.data = [dict(r) for r in (rows or [])]
        self._renumber()
        self._render_body()

    def set_columns(self, lane_count):
        """lane_count: total number of lanes. Only needed when the column
        structure itself changes -- row edits (set_rows, insert/delete/
        reorder) reuse the existing columns via _render_body() alone."""
        self.lane_count = max(0, lane_count)
        self._render()

    def set_controllers(self, rows):
        self.controllers = [r for r in (rows or []) if (r.get("ctrl_id") or "").strip() != ""]
        self.color_by_id = {}
        for i, c in enumerate(self.controllers):
            self.color_by_id[c["ctrl_id"]] = LANE_GRID_PALETTE[i % len(LANE_GRID_PALETTE)]
        if self.active_ctrl_id not in self.color_by_id:
            self.active_ctrl_id = self.controllers[0]["ctrl_id"] if self.controllers else None
        self._render_palette()
        self._refresh_cell_styles()

    def add_mode_row(self):
        self._insert_row_below(len(self.data) - 1)

    def remove_last_mode_row(self):
        if self.data:
            self._delete_row(len(self.data) - 1)

    def _delete_row(self, idx):
        if len(self.data) <= 1 or not (0 <= idx < len(self.data)):
            return  # always keep at least one mode row -- an empty table can't be saved anyway
        del self.data[idx]
        self._renumber()
        self._render_body()

    def _insert_row_below(self, idx):
        row = {"mode": "0"}
        for l in range(self.lane_count):
            row[f"lane{l}"] = "0-0"
        pos = idx + 1 if 0 <= idx < len(self.data) else len(self.data)
        self.data.insert(pos, row)
        self._renumber()
        self._render_body()

    def _renumber(self):
        for i, r in enumerate(self.data):
            r["mode"] = str(i)

    # ------------------------------------------------------------ palette
    def _render_palette(self):
        while self.palette_layout.count():
            item = self.palette_layout.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()
        for c in self.controllers:
            cid = c["ctrl_id"]
            color = self.color_by_id[cid]
            btn = QtWidgets.QPushButton(c.get("ctrl_name") or cid)
            btn.setCheckable(True)
            btn.setChecked(cid == self.active_ctrl_id)
            weight = "bold" if cid == self.active_ctrl_id else "normal"
            btn.setStyleSheet(
                f"background-color: {color}; color: {_contrast_text_color(color)}; font-weight: {weight};"
            )
            btn.clicked.connect(lambda _checked=False, cid=cid: self._set_active_controller(cid))
            self.palette_layout.addWidget(btn)
        self.palette_layout.addStretch(1)

    def _set_active_controller(self, cid):
        self.active_ctrl_id = cid
        self._render_palette()

    # ------------------------------------------------------------ grid construction
    def _render(self):
        self._building = True
        self.table.blockSignals(True)
        self.table.clear()
        self.table.setColumnCount(self.lane_count + 2)  # mode + lanes + actions
        self.table.setHorizontalHeaderLabels(["mode"] + [f"L{l}" for l in range(self.lane_count)] + [""])
        self.table.blockSignals(False)
        self._building = False
        self._render_body()
        self._apply_lane_width()

    def _apply_lane_width(self):
        """Recompute every lane column's width from the table's own
        viewport width and the current lane count -- same geometric rule
        as lanegrid.js's _applyLaneWidth (see LANE_W_RATIO above). Called
        on every resize (_LaneTable.resizeEvent) and every column-
        structure change (_render), so the grid stays proportional at any
        window size instead of just falling back on Qt's own default
        column auto-sizing."""
        if self.lane_count <= 0 or self.table.columnCount() < self.lane_count + 2:
            return
        avail = self.table.viewport().width() - LANE_MODE_W - LANE_ACTIONS_W
        n = max(1, self.lane_count)
        w32 = avail / 32 if avail > 0 else 0
        w = w32 * (LANE_W_RATIO ** math.log2(32 / n))
        min_w = max(int(w), LANE_MIN_CELL)
        self.table.setColumnWidth(0, LANE_MODE_W)
        for l in range(self.lane_count):
            self.table.setColumnWidth(l + 1, min_w)
        self.table.setColumnWidth(self.lane_count + 1, LANE_ACTIONS_W)

    def _render_body(self):
        self._building = True
        self.table.blockSignals(True)
        self.table.setRowCount(0)
        self.table.setRowCount(len(self.data))
        for r, row in enumerate(self.data):
            mode_item = QtWidgets.QTableWidgetItem(row.get("mode", ""))
            mode_item.setFlags(mode_item.flags() & ~QtCore.Qt.ItemIsEditable)
            self.table.setItem(r, 0, mode_item)
            for l in range(self.lane_count):
                item = QtWidgets.QTableWidgetItem(row.get(f"lane{l}", ""))
                self.table.setItem(r, l + 1, item)
            self.table.setCellWidget(r, self.lane_count + 1, self._make_actions_widget(r))
        self.table.blockSignals(False)
        self._building = False
        self._refresh_cell_styles()

    def _make_actions_widget(self, row_idx):
        widget = QtWidgets.QWidget()
        hl = QtWidgets.QHBoxLayout(widget)
        hl.setContentsMargins(2, 0, 2, 0)
        hl.setSpacing(2)
        plus = QtWidgets.QToolButton()
        plus.setText("+")
        plus.setToolTip("Insert mode row below")
        plus.clicked.connect(lambda _checked=False, i=row_idx: self._insert_row_below(i))
        minus = QtWidgets.QToolButton()
        minus.setText("−")
        minus.setToolTip("Delete this mode row")
        minus.clicked.connect(lambda _checked=False, i=row_idx: self._delete_row(i))
        hl.addWidget(plus)
        hl.addWidget(minus)
        return widget

    def _refresh_cell_styles(self):
        for r in range(self.table.rowCount()):
            for l in range(self.lane_count):
                item = self.table.item(r, l + 1)
                if item is None:
                    continue
                val = item.text()
                cid = val.split("-", 1)[0] if "-" in val else None
                color = self.color_by_id.get(cid) if cid else None
                if color:
                    item.setBackground(QtGui.QColor(color))
                    item.setForeground(QtGui.QColor(_contrast_text_color(color)))
                else:
                    item.setBackground(QtGui.QColor(LANE_GRID_UNASSIGNED_BG))
                    item.setForeground(QtGui.QColor("#333333"))

    # ------------------------------------------------------------ native item edits
    def _on_item_changed(self, item):
        """Fires when the user commits a hand-typed edit (native
        double-click-to-edit path) -- paint-drag updates go through
        _sync_table_from_data() instead, with signals blocked, so this
        never double-applies a paint stroke."""
        if self._building:
            return
        r, c = item.row(), item.column()
        if c < 1 or c > self.lane_count:
            return
        self.data[r][f"lane{c - 1}"] = item.text()
        self._refresh_cell_styles()

    # ------------------------------------------------------------ paint-drag
    # Called by _LaneTable's mouse event overrides below.
    def _cell_at(self, pos):
        item = self.table.itemAt(pos)
        if item is None:
            return None
        r, c = item.row(), item.column()
        if c < 1 or c > self.lane_count:
            return None
        return r, c - 1

    def _begin_paint(self, r, l):
        self._drag_active = True
        self._drag_anchor = (r, l)
        self._drag_current = (r, l)
        self._drag_snapshot = copy.deepcopy(self.data)
        # Lay the stroke down on press so a plain click (press + release,
        # no movement) still paints one cell.
        self._paint_current_rect()

    def _continue_paint(self, r, l):
        if not self._drag_active:
            return
        if (r, l) != self._drag_current:
            self._drag_current = (r, l)
            self._paint_current_rect()

    def _end_paint(self):
        self._drag_active = False

    def _paint_current_rect(self):
        if self._drag_snapshot is None:
            return
        self.data = copy.deepcopy(self._drag_snapshot)
        r0, l0 = self._drag_anchor
        r1, l1 = self._drag_current
        row_lo, row_hi = min(r0, r1), max(r0, r1)
        lane_lo, lane_hi = min(l0, l1), max(l0, l1)
        if self.active_ctrl_id is not None:
            for r in range(row_lo, row_hi + 1):
                if r >= len(self.data):
                    continue
                i = 0
                for l in range(lane_lo, lane_hi + 1):
                    self.data[r][f"lane{l}"] = f"{self.active_ctrl_id}-{i}"
                    i += 1
        self._sync_table_from_data()

    def _sync_table_from_data(self):
        self._building = True
        self.table.blockSignals(True)
        for r, row in enumerate(self.data):
            for l in range(self.lane_count):
                item = self.table.item(r, l + 1)
                if item is not None:
                    item.setText(row.get(f"lane{l}", ""))
        self.table.blockSignals(False)
        self._building = False
        self._refresh_cell_styles()

    def _rollback_to_snapshot(self):
        """Undo the just-completed first click's own paint stroke before a
        double-click opens the cell for editing -- otherwise the value the
        user meant to hand-type over would already have been overwritten
        by that first click's paint."""
        if self._drag_snapshot is not None:
            self.data = copy.deepcopy(self._drag_snapshot)
            self._sync_table_from_data()

    # ------------------------------------------------------------ row reorder
    # Mirrors plm_qt_tables.EditableTable's approach: dragging a row
    # header only moves the header visually, so re-read the header's new
    # visual order to physically reorder self.data, then reset the header
    # back to identity before re-rendering.
    def _on_row_moved(self, logical_index, old_visual, new_visual):
        if self._building:
            return
        header = self.table.verticalHeader()
        new_data = [self.data[header.logicalIndex(v)] for v in range(len(self.data))]
        self.data = new_data
        self._renumber()
        self._reset_header_order()
        self._render_body()

    def _reset_header_order(self):
        header = self.table.verticalHeader()
        header.blockSignals(True)
        for logical in range(header.count()):
            current_visual = header.visualIndex(logical)
            if current_visual != logical:
                header.moveSection(current_visual, logical)
        header.blockSignals(False)

    def _on_header_context_menu(self, pos):
        header = self.table.verticalHeader()
        logical = header.logicalIndexAt(pos)
        if logical < 0:
            return
        menu = QtWidgets.QMenu(self)
        insert_action = menu.addAction("Insert mode row below")
        delete_action = menu.addAction("Delete this mode row")
        chosen = menu.exec_(header.mapToGlobal(pos))
        if chosen == insert_action:
            self._insert_row_below(logical)
        elif chosen == delete_action:
            self._delete_row(logical)


class _LaneTable(QtWidgets.QTableWidget):
    """QTableWidget whose mouse events drive the owning LaneGrid's
    paint-drag and double-click-edit-with-rollback behavior. Qt delivers a
    double-click as mousePress+mouseRelease (first click) followed by
    mouseDoubleClick+mouseRelease (second click) rather than a second
    mousePress -- so the first click's own snapshot/paint (from
    _begin_paint) is exactly the state mouseDoubleClickEvent rolls back
    to before opening the editor."""

    def __init__(self, grid):
        super().__init__()
        self._grid = grid

    def resizeEvent(self, event):
        super().resizeEvent(event)
        # Catches every real resize AND the 0 -> real-width transition
        # when this tab is shown for the first time (a hidden QTabWidget
        # page has zero viewport width until it's actually selected) --
        # same event lanegrid.js needs its own ResizeObserver for.
        self._grid._apply_lane_width()

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            cell = self._grid._cell_at(event.pos())
            if cell is not None:
                self._grid._begin_paint(*cell)
                return  # don't let the base class turn this into a selection drag
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._grid._drag_active:
            cell = self._grid._cell_at(event.pos())
            if cell is not None:
                self._grid._continue_paint(*cell)
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self._grid._drag_active:
            self._grid._end_paint()
            return
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        cell = self._grid._cell_at(event.pos())
        if cell is not None:
            self._grid._rollback_to_snapshot()
            item = self.itemAt(event.pos())
            if item is not None:
                self.editItem(item)
            return
        super().mouseDoubleClickEvent(event)
