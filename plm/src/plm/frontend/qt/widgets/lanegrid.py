"""Paint-and-drag lane-mapping grid for the Qt desktop front end.

Rows are editable modes and columns are PHY lanes. Controller swatches set
the active paint value; dragging paints a range with hover preview and a
coloured pen cursor. Rows can be reordered directly or edited through the
context menu.
"""

import copy

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.widgets.common import StyledMenu, apply_drop_shadow
from plm.frontend.qt.widgets.tables import RowDragTable
from plm.frontend.qt.styles.tokens import (
    BG_MAIN, BG_SUBTLE, BG_SURFACE, BORDER, BORDER_HOVER, DANGER, FONT_SIZE_SM,
    PRIMARY, PRIMARY_HOVER,
    RADIUS_CHIP, SHADOW_SM, SPACING_LG, SPACING_MD, SPACING_XS, SUCCESS,
    TEXT_MAIN, TEXT_MUTED, TEXT_SUB,
)

LANE_GRID_PALETTE = [
    PRIMARY, TEXT_SUB, SUCCESS, DANGER, TEXT_MUTED,
    PRIMARY, TEXT_SUB, SUCCESS, DANGER, TEXT_MUTED,
    PRIMARY, TEXT_SUB,
]
LANE_GRID_UNASSIGNED_BG = BG_SUBTLE

# Keep the mode column compact and let the active lane columns consume the
# remaining viewport width evenly. This avoids the large dead area that used
# to appear in x2/x4/x8 configurations while still fitting x32 without a
# horizontal scrollbar.
LANE_MODE_W = 64


def _ui_scale():
    """Scaling factor relative to the 13 px design baseline."""
    app = QtWidgets.QApplication.instance()
    px = app.font().pixelSize() if app else 13
    return max(px, 11) / 13.0

# Paint stroke and hover-preview opacity constants.
PAINT_OPACITY = 0.58
PREVIEW_OPACITY = 0.78

def _contrast_text_color(hex_color):
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return TEXT_MAIN if luminance > 140 else BG_SURFACE


def _darken_color(hex_color, factor=0.82):
    """Darken a hex colour toward black (1 = unchanged, 0 = black)."""
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    target = 0x1a
    r = int(r * factor + target * (1 - factor))
    g = int(g * factor + target * (1 - factor))
    b = int(b * factor + target * (1 - factor))
    return f"#{r:02x}{g:02x}{b:02x}"


def _make_pen_cursor(color):
    """Build a crisp paint-brush cursor with the active controller colour."""
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'
        '<path d="M15.2 20.2L25.8 9.6c1.8-1.8 1.8-4.6 0-6.4s-4.6-1.8-6.4 0L8.8 13.8z" '
        f'fill="{BG_MAIN}" stroke="{TEXT_MAIN}" stroke-width="1.5" stroke-linejoin="round"/>'
        '<path d="M11.4 12.1l8.5 8.5-3.2 3.2-8.5-8.5z" fill="{TEXT_MUTED}" '
        f'stroke="{TEXT_MAIN}" stroke-width="1.3" stroke-linejoin="round"/>'
        f'<path d="M8.5 15.2c-2.7 2.5-3.4 5.2-3.7 8.2-.2 1.9-1 3.7-2.5 5.4 '
        f'4.3-.1 7.8-1.4 10.2-4.9z" fill="{color}" stroke="{TEXT_MAIN}" stroke-width="1.5" '
        'stroke-linejoin="round"/>'
        '<path d="M4.2 27.3c1.8-.2 3.2-.7 4.3-1.5" fill="none" stroke="{BG_SURFACE}" '
        f'stroke-opacity=".8" stroke-width="1.2" stroke-linecap="round"/>'
        '</svg>'
    )
    # Load from the SVG source via QImage's SVG support
    img = QtGui.QImage()
    img.loadFromData(svg.encode('utf-8'))
    if img.isNull():
        # Fallback: use a simple crosshair cursor if SVG loading fails
        return None
    pixmap = QtGui.QPixmap.fromImage(img)
    return QtGui.QCursor(pixmap, 3, 29)


class _LaneCellDelegate(QtWidgets.QStyledItemDelegate):
    """Paint contiguous controller assignments as rounded marker bands."""

    def __init__(self, grid, parent=None):
        super().__init__(parent)
        self._grid = grid

    def paint(self, painter, option, index):
        grid = self._grid
        r, c = index.row(), index.column()
        if c == 0:
            styled = QtWidgets.QStyleOptionViewItem(option)
            self.initStyleOption(styled, index)
            text = styled.text
            styled.text = ""
            style = styled.widget.style() if styled.widget else QtWidgets.QApplication.style()
            style.drawControl(QtWidgets.QStyle.CE_ItemViewItem, styled, painter, styled.widget)
            text_rect = option.rect.adjusted(12, 0, -12, 0)
            selected = bool(option.state & QtWidgets.QStyle.State_Selected)
            role = QtGui.QPalette.HighlightedText if selected else QtGui.QPalette.Text
            painter.save()
            painter.setPen(styled.palette.color(role))
            painter.drawText(
                text_rect,
                styled.displayAlignment | QtCore.Qt.AlignVCenter,
                option.fontMetrics.elidedText(text, styled.textElideMode, text_rect.width()),
            )
            if (r, c) in grid._cell_errors:
                painter.setPen(QtGui.QPen(QtGui.QColor(DANGER), 2))
                painter.drawRect(option.rect.adjusted(1, 1, -2, -2))
            painter.restore()
            return
        if c < 1 or c > grid.lane_count:
            super().paint(painter, option, index)
            return
        lane_idx = c - 1
        val = index.data(QtCore.Qt.DisplayRole) or ""
        has_dash = "-" in val
        cid = val.split("-", 1)[0] if has_dash else None
        port = val[val.index("-") + 1:] if has_dash else val
        paint_color = grid.color_by_id.get(cid) if cid else None

        is_hover = (not grid._drag_active and grid._hover_cell is not None
                    and grid._hover_cell[0] == r and grid._hover_cell[1] == lane_idx)
        active_color = grid.color_by_id.get(grid.active_ctrl_id) if grid.active_ctrl_id else None

        rect = option.rect
        painter.save()

        # Background
        if paint_color:
            painter.fillRect(rect, QtGui.QColor(grid._bg_color))
        else:
            painter.fillRect(rect, QtGui.QColor(LANE_GRID_UNASSIGNED_BG))
        if option.state & QtWidgets.QStyle.State_Selected:
            painter.fillRect(rect, QtGui.QColor(SUCCESS + "18"))

        # Adjacent cells assigned to the same controller join into one
        # continuous marker band. Only the two outer ends retain rounded caps.
        if paint_color:
            joins_left = self._paint_color_at(r, lane_idx - 1) == paint_color
            joins_right = self._paint_color_at(r, lane_idx + 1) == paint_color
            self._draw_marker_band(
                painter, rect, paint_color, PAINT_OPACITY, joins_left, joins_right
            )

        # A hover preview is a self-contained rounded marker dab.
        if is_hover and active_color and not paint_color:
            self._draw_marker_band(painter, rect, active_color, PREVIEW_OPACITY, False, False)
        elif is_hover and active_color and paint_color != active_color:
            self._draw_marker_band(painter, rect, active_color, PREVIEW_OPACITY, False, False)

        # Draw text
        if paint_color:
            text_color = QtGui.QColor(_darken_color(paint_color, 0.82))
            painter.setPen(text_color)
            font = painter.font()
            font.setBold(True)
            painter.setFont(font)
        elif is_hover and active_color:
            text_color = QtGui.QColor(_darken_color(active_color, 0.84))
            painter.setPen(text_color)
            font = painter.font()
            font.setBold(True)
            painter.setFont(font)
        else:
            painter.setPen(QtGui.QColor(TEXT_MAIN))

        painter.drawText(rect, QtCore.Qt.AlignCenter, port)
        if (r, c) in grid._cell_errors:
            painter.setPen(QtGui.QPen(QtGui.QColor(DANGER), 2))
            painter.drawRect(rect.adjusted(1, 1, -2, -2))

        painter.restore()

    def _paint_color_at(self, row, lane):
        grid = self._grid
        if row < 0 or row >= len(grid.data) or lane < 0 or lane >= grid.lane_count:
            return None
        value = grid.data[row].get(f"lane{lane}", "")
        controller_id = value.split("-", 1)[0] if "-" in value else None
        return grid.color_by_id.get(controller_id) if controller_id else None

    def updateEditorGeometry(self, editor, option, index):
        if index.column() == 0:
            editor.setGeometry(option.rect.adjusted(12, 1, -12, -1))
        else:
            super().updateEditorGeometry(editor, option, index)
    @staticmethod
    def _draw_marker_band(painter, rect, color, opacity, joins_left, joins_right):
        """Draw one clipped segment of a continuous, round-ended marker band."""
        inset_y = max(3, int(rect.height() * 0.16))
        band_height = max(4, rect.height() - 2 * inset_y)
        radius = min(8.0, band_height / 2.0)
        left = rect.left() - radius if joins_left else rect.left() + 2
        right = rect.right() + radius if joins_right else rect.right() - 2
        band = QtCore.QRectF(left, rect.top() + inset_y, right - left, band_height)
        fill = QtGui.QColor(color)
        fill.setAlphaF(opacity)

        painter.save()
        painter.setClipRect(rect)
        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(fill)
        painter.drawRoundedRect(band, radius, radius)
        painter.restore()


class _FlowLayout(QtWidgets.QLayout):
    """A left-to-right, top-to-bottom wrapping layout for the palette
    bar so controller swatches reflow instead of overflowing the lane
    mapping page at narrow widths or larger font sizes."""

    def __init__(self, parent=None, margin=0, h_spacing=6, v_spacing=6):
        super().__init__(parent)
        if parent is not None:
            self.setContentsMargins(margin, margin, margin, margin)
        self._h_spacing = h_spacing
        self._v_spacing = v_spacing
        self._items = []

    def addItem(self, item):
        self._items.append(item)

    def count(self):
        return len(self._items)

    def itemAt(self, index):
        if 0 <= index < len(self._items):
            return self._items[index]
        return None

    def takeAt(self, index):
        if 0 <= index < len(self._items):
            return self._items.pop(index)
        return None

    def expandingDirections(self):
        return QtCore.Qt.Orientations(0)

    def hasHeightForWidth(self):
        return True

    def heightForWidth(self, width):
        return self._do_layout(QtCore.QRect(0, 0, width, 0), True)

    def setGeometry(self, rect):
        super().setGeometry(rect)
        self._do_layout(rect, False)

    def sizeHint(self):
        width = max((item.sizeHint().width() for item in self._items), default=0)
        return QtCore.QSize(width, self.heightForWidth(max(width, 1)))

    def minimumSize(self):
        size = QtCore.QSize()
        for item in self._items:
            size = size.expandedTo(item.minimumSize().expandedTo(item.sizeHint()))
        margin = self.contentsMargins()
        size += QtCore.QSize(margin.left() + margin.right(), margin.top() + margin.bottom())
        return size

    def _do_layout(self, rect, test_only):
        x = rect.x()
        y = rect.y()
        line_height = 0
        for item in self._items:
            space_x = self._h_spacing
            space_y = self._v_spacing
            next_x = x + item.sizeHint().width() + space_x
            if next_x - space_x > rect.right() and line_height > 0:
                x = rect.x()
                y += line_height + space_y
                next_x = x + item.sizeHint().width() + space_x
                line_height = 0
            if not test_only:
                item.setGeometry(QtCore.QRect(QtCore.QPoint(x, y), item.sizeHint()))
            x = next_x
            line_height = max(line_height, item.sizeHint().height())
        return y + line_height - rect.y()


class LaneGrid(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()

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
        self._hover_cell = None  # (row, lane) under the cursor, for pen preview
        self._pen_cursor = None  # cached QCursor for the active controller
        self._bg_color = BG_SURFACE  # card background, set from theme
        self._cell_errors = {}

        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Palette bar: holds pill-style swatch buttons
        self.palette_bar = QtWidgets.QWidget()
        self.palette_bar.setObjectName("lgPaletteBar")
        palette_outer = QtWidgets.QVBoxLayout(self.palette_bar)
        palette_outer.setContentsMargins(0, 0, 0, int(8 * _ui_scale()))
        palette_outer.setSpacing(int(6 * _ui_scale()))
        # Use a flow layout so swatches wrap to multiple rows instead of
        # overflowing the lane mapping page at narrow widths.
        self._palette_flow = _FlowLayout(h_spacing=int(6 * _ui_scale()), v_spacing=int(6 * _ui_scale()))
        palette_outer.addLayout(self._palette_flow)
        layout.addWidget(self.palette_bar)

        self.table = _LaneTable(self)
        self.table.setObjectName("laneGrid")
        self.table.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        self.table.setHorizontalScrollMode(QtWidgets.QAbstractItemView.ScrollPerPixel)
        self.table.rowContextMenuRequested.connect(self._on_row_context_menu)
        lane_header = self.table.horizontalHeader()
        lane_header.setMinimumSectionSize(1)
        lane_header.setDefaultAlignment(QtCore.Qt.AlignCenter)
        self.table.setEditTriggers(
            QtWidgets.QAbstractItemView.DoubleClicked
            | QtWidgets.QAbstractItemView.EditKeyPressed
        )
        row_header = self.table.verticalHeader()
        row_header.hide()
        self.table.rowMoveRequested.connect(self._on_row_drop)
        row_header.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        row_header.customContextMenuRequested.connect(self._on_header_context_menu)
        self.table.itemChanged.connect(self._on_item_changed)
        # Enable mouse tracking so we get mouseMoveEvent even without a button held
        self.table.setMouseTracking(True)
        self.table.viewport().setMouseTracking(True)
        # Install the custom delegate for lane cells (columns 1..lane_count)
        self._delegate = _LaneCellDelegate(self, self.table)
        self.table.setItemDelegate(self._delegate)
        layout.addWidget(self.table)

    # ------------------------------------------------------------ public data interface
    def get_rows(self):
        return [dict(r) for r in self.data]

    def set_rows(self, rows):
        self.data = [dict(r) for r in (rows or [])]
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
        self._apply_paint_cursor()
        self._refresh_cell_styles()

    def _delete_row(self, idx):
        if len(self.data) <= 1 or not (0 <= idx < len(self.data)):
            return  # always keep at least one mode row -- an empty table can't be saved anyway
        del self.data[idx]
        self._render_body()
        self.changed.emit()

    def _insert_row_below(self, idx):
        self._insert_row_at(idx + 1 if 0 <= idx < len(self.data) else len(self.data))

    def _insert_row_above(self, idx):
        self._insert_row_at(idx if 0 <= idx < len(self.data) else len(self.data))

    def _insert_row_at(self, pos):
        row = {"mode": ""}
        for lane_idx in range(self.lane_count):
            row[f"lane{lane_idx}"] = "0-0"
        self.data.insert(pos, row)
        self._render_body()
        self.changed.emit()

    # ------------------------------------------------------------ palette
    def _render_palette(self):
        scale = _ui_scale()
        # Clear existing swatches
        while self._palette_flow.count():
            item = self._palette_flow.takeAt(0)
            w = item.widget()
            if w:
                # deleteLater() alone leaves the old coloured button visible
                # until the next event-loop turn, which can look like one long
                # brush swatch while the palette is rebuilt.
                w.hide()
                w.setParent(None)
                w.deleteLater()

        for c in self.controllers:
            cid = c["ctrl_id"]
            color = self.color_by_id[cid]
            is_active = (cid == self.active_ctrl_id)
            btn = QtWidgets.QPushButton(c.get("ctrl_name") or cid)
            btn.setObjectName("lgSwatch")
            btn.setCheckable(True)
            btn.setChecked(is_active)
            btn.setToolTip(
                f"Active brush: {c.get('ctrl_name') or cid}" if is_active
                else f"Use {c.get('ctrl_name') or cid} as the brush"
            )
            text_color = _contrast_text_color(color)
            border_color = PRIMARY_HOVER if is_active else BORDER
            outline = (
                f"border: {int(2 * scale)}px solid {border_color};" if is_active
                else f"border: {int(1 * scale)}px solid {border_color};"
            )
            btn.setStyleSheet(
                f"QPushButton#lgSwatch {{"
                f"  background-color: {color};"
                f"  color: {text_color};"
                f"  font-size: {FONT_SIZE_SM * scale:.1f}px;"
                f"  font-weight: 600;"
                f"  border-radius: {int(RADIUS_CHIP * scale)}px;"
                f"  padding: {int(SPACING_XS * scale)}px {int(SPACING_MD * scale)}px;"
                f"  {outline}"
                f"}}"
                f"QPushButton#lgSwatch:hover {{"
                f"  border-color: {BORDER_HOVER};"
                f"}}"
            )
            btn.setCursor(QtCore.Qt.PointingHandCursor)
            btn.setMinimumHeight(int((SPACING_LG * 2) * scale))
            apply_drop_shadow(
                btn,
                blur_radius=int(SHADOW_SM["blur_radius"] * scale),
                offset=(0, int(SHADOW_SM["offset"][1] * scale)),
                alpha=SHADOW_SM["rgba"][3],
                shadow=SHADOW_SM,
            )
            btn.clicked.connect(lambda _checked=False, cid=cid: self._set_active_controller(cid))
            self._palette_flow.addWidget(btn)
        self._palette_flow.invalidate()
        self.palette_bar.updateGeometry()

    def _set_active_controller(self, cid):
        self.active_ctrl_id = cid
        self._render_palette()
        self._apply_paint_cursor()
        self._refresh_cell_styles()

    # ------------------------------------------------------------ pen cursor
    def _apply_paint_cursor(self):
        """Set the table cursor to a brush nib in the active colour."""
        if self.active_ctrl_id and self.active_ctrl_id in self.color_by_id:
            color = self.color_by_id[self.active_ctrl_id]
            cursor = _make_pen_cursor(color)
            if cursor is not None:
                self._pen_cursor = cursor
                self.table.viewport().setCursor(cursor)
                return
        # Fallback: crosshair cursor
        self._pen_cursor = None
        self.table.viewport().setCursor(QtCore.Qt.CrossCursor)

    # ------------------------------------------------------------ grid construction
    def _render(self):
        self.table._cancel_pending_paint()
        self._building = True
        self.table.blockSignals(True)
        self.table.clear()
        self.table.setColumnCount(self.lane_count + 1)  # mode + lanes
        # QHeaderView can retain a stale visual section order when the lane
        # count shrinks (for example x32 -> x16). Always restore the logical
        # order so the actions column stays after the final lane.
        header = self.table.horizontalHeader()
        header.blockSignals(True)
        for logical in range(header.count()):
            current_visual = header.visualIndex(logical)
            if current_visual != logical:
                header.moveSection(current_visual, logical)
        header.setSectionsMovable(False)
        header.blockSignals(False)
        # The page already establishes that these are lanes; bare numbers stay
        # readable when all 32 columns are fitted into the viewport.
        self.table.setHorizontalHeaderLabels(["mode"] + [str(lane_idx) for lane_idx in range(self.lane_count)])
        self.table.blockSignals(False)
        self._building = False
        self._render_body()
        self._apply_lane_width()
        self._apply_paint_cursor()

    def _apply_lane_width(self):
        """Recompute every lane column's width from the table's own
        viewport width and current lane count using LANE_W_RATIO. Called
        on every resize (_LaneTable.resizeEvent) and every column-
        structure change (_render), so the grid stays proportional at any
        window size instead of just falling back on Qt's own default
        column auto-sizing."""
        if self.lane_count <= 0 or self.table.columnCount() < self.lane_count + 1:
            return
        scale = _ui_scale()
        mode_w = int(LANE_MODE_W * scale)
        # Every lane shares the complete remaining viewport. Small lane-count
        # modes therefore read like a deliberate grid rather than a narrow
        # strip stranded on the left side of the card.
        usable = max(1, self.table.viewport().width() - 1)
        avail = max(1, usable - mode_w)
        n = max(1, self.lane_count)
        lane_w, remainder = divmod(avail, n)
        font = QtGui.QFont(self.table.font())
        font.setBold(True)
        minimum = QtGui.QFontMetrics(font).horizontalAdvance(str(max(31, n - 1))) + 2 * SPACING_MD
        overflow = lane_w < minimum
        self.table.setHorizontalScrollBarPolicy(
            QtCore.Qt.ScrollBarAsNeeded if overflow else QtCore.Qt.ScrollBarAlwaysOff
        )
        if overflow:
            lane_w, remainder = minimum, 0
        self.table.setColumnWidth(0, mode_w)
        for lane_idx in range(self.lane_count):
            self.table.setColumnWidth(
                lane_idx + 1, lane_w + (1 if lane_idx < remainder else 0)
            )

        # On very narrow x32 grids, printing every two-digit lane number
        # produces an unreadable solid string. Keep spatial orientation with
        # evenly spaced labels; every header still exposes its full lane name
        # as a tooltip.
        if lane_w >= 16:
            label_step = 1
        elif lane_w >= 11:
            label_step = 2
        else:
            label_step = 4
        for lane_idx in range(self.lane_count):
            item = self.table.horizontalHeaderItem(lane_idx + 1)
            if item is not None:
                item.setText(str(lane_idx) if lane_idx % label_step == 0 or lane_idx == self.lane_count - 1 else "")
                item.setToolTip(f"Lane {lane_idx}")

    def _render_body(self):
        # A reload or row change invalidates coordinates of deferred clicks.
        self.table._cancel_pending_paint()
        self._building = True
        self.table.blockSignals(True)
        self.table.setRowCount(0)
        self.table.setRowCount(len(self.data))
        for r, row in enumerate(self.data):
            mode_item = QtWidgets.QTableWidgetItem(row.get("mode", ""))
            self.table.setItem(r, 0, mode_item)
            for lane_idx in range(self.lane_count):
                item = QtWidgets.QTableWidgetItem(row.get(f"lane{lane_idx}", ""))
                item.setToolTip(f"L{lane_idx}: {item.text()}")
                self.table.setItem(r, lane_idx + 1, item)
        self.table.blockSignals(False)
        self._building = False
        self._refresh_cell_styles()

    def set_cell_errors(self, errors):
        """Highlight invalid mode/lane cells; keys are (row, table-column)."""
        self._cell_errors = dict(errors or {})
        previous = self.table.blockSignals(True)
        try:
            for row in range(self.table.rowCount()):
                for column in range(self.table.columnCount()):
                    item = self.table.item(row, column)
                    if item is not None:
                        item.setToolTip(
                            self._cell_errors.get((row, column), "")
                            or (f"L{column - 1}: {item.text()}" if column else "")
                        )
        finally:
            self.table.blockSignals(previous)
        self._refresh_cell_styles()

    def _refresh_cell_styles(self):
        """Trigger a repaint of the table viewport so the delegate redraws
        all cells with current paint/preview state. The actual painting
        happens in _LaneCellDelegate.paint()."""
        # Clear the hover cell when refreshing during a drag
        if self._drag_active:
            self._hover_cell = None
        self.table.viewport().update()

    # ------------------------------------------------------------ native item edits
    def _on_item_changed(self, item):
        """Fires when the user commits a hand-typed edit (native
        double-click-to-edit path) -- paint-drag updates go through
        _sync_table_from_data() instead, with signals blocked, so this
        never double-applies a paint stroke."""
        if self._building:
            return
        r, c = item.row(), item.column()
        if c == 0:
            self.data[r]["mode"] = item.text()
            self.changed.emit()
            return
        if c < 1 or c > self.lane_count:
            return
        self.data[r][f"lane{c - 1}"] = item.text()
        self._refresh_cell_styles()
        self.changed.emit()

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

    def _begin_paint(self, r, lane_idx):
        self._drag_active = True
        self._drag_anchor = (r, lane_idx)
        self._drag_current = (r, lane_idx)
        self._drag_snapshot = copy.deepcopy(self.data)
        self._hover_cell = None  # suppress preview during drag
        # Called only after a drag starts or a single click is confirmed.
        self._paint_current_rect()

    def _continue_paint(self, r, lane_idx):
        if not self._drag_active:
            return
        if (r, lane_idx) != self._drag_current:
            self._drag_current = (r, lane_idx)
            self._paint_current_rect()

    def _end_paint(self):
        self._drag_active = False
        changed = self._drag_snapshot is not None and self.data != self._drag_snapshot
        # Refresh so the hover preview comes back after the stroke finishes
        self._refresh_cell_styles()
        if changed:
            self.changed.emit()

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
                for lane_idx in range(lane_lo, lane_hi + 1):
                    self.data[r][f"lane{lane_idx}"] = f"{self.active_ctrl_id}-{i}"
                    i += 1
        self._sync_table_from_data()

    def _sync_table_from_data(self):
        self._building = True
        self.table.blockSignals(True)
        for r, row in enumerate(self.data):
            for lane_idx in range(self.lane_count):
                item = self.table.item(r, lane_idx + 1)
                if item is not None:
                    item.setText(row.get(f"lane{lane_idx}", ""))
                    item.setToolTip(f"L{lane_idx}: {item.text()}")
        self.table.blockSignals(False)
        self._building = False
        self._refresh_cell_styles()

    # ------------------------------------------------------------ hover tracking
    def _on_cell_hover(self, pos):
        """Track which cell the mouse is over so the delegate can draw a
        preview. Called from _LaneTable.mouseMoveEvent when not dragging."""
        if self._drag_active:
            return
        cell = self._cell_at(pos)
        if cell != self._hover_cell:
            self._hover_cell = cell
            self.table.viewport().update()

    def _on_cell_leave(self):
        """Clear the hover when the mouse leaves the table viewport."""
        if self._hover_cell is not None:
            self._hover_cell = None
            self.table.viewport().update()

    # ------------------------------------------------------------ row reorder
    # Mirrors plm_qt_tables.EditableTable's approach: dragging a row
    # header only moves the header visually, so re-read the header's new
    # visual order to physically reorder self.data, then reset the header
    # back to identity before re-rendering.
    def _on_row_drop(self, source, destination):
        if self._building:
            return
        row = self.data.pop(source)
        self.data.insert(destination, row)
        self._render_body()
        self.changed.emit()

    def _on_header_context_menu(self, pos):
        header = self.table.verticalHeader()
        logical = header.logicalIndexAt(pos)
        if logical < 0:
            return
        menu = StyledMenu(self)
        insert_action = menu.addAction("Insert mode row below")
        delete_action = menu.addAction("Delete this mode row")
        chosen = menu.exec_(header.mapToGlobal(pos))
        if chosen == insert_action:
            self._insert_row_below(logical)
        elif chosen == delete_action:
            self._delete_row(logical)

    def _on_row_context_menu(self, row, global_pos):
        if row < 0:
            row = self.table.currentRow()
            if row < 0 and self.table.rowCount():
                row = self.table.rowCount() - 1
        if row >= 0:
            self.table.selectRow(row)
        menu = StyledMenu(self.table)
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
            self._insert_row_above(row)
        elif chosen == insert_below:
            self._insert_row_below(row)
        elif delete_current is not None and chosen == delete_current:
            self._delete_row(row)


class _LaneTable(RowDragTable):
    """Separate pending clicks, paint drags, and native double-click edits."""

    def __init__(self, grid):
        super().__init__(drag_columns={0})
        self._grid = grid
        self._press_pos = None
        self._pending_cell = None
        self._click_cell = None
        self._click_timer = QtCore.QTimer(self)
        self._click_timer.setSingleShot(True)
        self._click_timer.setTimerType(QtCore.Qt.PreciseTimer)
        self._click_timer.timeout.connect(self._commit_single_click)
        self.setMouseTracking(True)
        self.viewport().setMouseTracking(True)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        # Catches every real resize AND the 0 -> real-width transition
        # when this tab is shown for the first time (a hidden QTabWidget
        # page has zero viewport width until it is selected).
        self._grid._apply_lane_width()

    def mousePressEvent(self, event):
        if event.button() == QtCore.Qt.LeftButton:
            cell = self._grid._cell_at(event.pos())
            if cell is not None:
                self._commit_single_click()
                self._press_pos = QtCore.QPoint(event.pos())
                self._pending_cell = cell
                return  # don't let the base class turn this into a selection drag
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._pending_cell is not None and event.buttons() & QtCore.Qt.LeftButton:
            if (event.pos() - self._press_pos).manhattanLength() >= QtWidgets.QApplication.startDragDistance():
                self._grid._begin_paint(*self._pending_cell)
                self._pending_cell = None
                self._press_pos = None
            else:
                return
        if self._grid._drag_active:
            cell = self._grid._cell_at(event.pos())
            if cell is not None:
                self._grid._continue_paint(*cell)
            return
        if self._row_drag_start is not None:
            super().mouseMoveEvent(event)
            return
        # Not dragging: track hover for the pen preview
        self._grid._on_cell_hover(event.pos())
        # Don't call super().mouseMoveEvent -- it would start a selection drag
        # on the cell that was pressed. We want pure hover tracking instead.

    def mouseReleaseEvent(self, event):
        if self._grid._drag_active:
            self._grid._end_paint()
            return
        if event.button() == QtCore.Qt.LeftButton and self._pending_cell is not None:
            self._click_cell = self._pending_cell
            self._pending_cell = None
            self._press_pos = None
            # Qt sends the first release before the double-click event.
            # Wait for that decision so editing never sees a painted value.
            self._click_timer.start(QtWidgets.QApplication.doubleClickInterval() + 1)
            return
        super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        self._cancel_pending_paint()
        cell = self._grid._cell_at(event.pos())
        if cell is not None:
            item = self.itemAt(event.pos())
            if item is not None:
                self.editItem(item)
            return
        super().mouseDoubleClickEvent(event)

    def _cancel_pending_paint(self):
        self._click_timer.stop()
        self._press_pos = None
        self._pending_cell = None
        self._click_cell = None

    def _commit_single_click(self):
        cell = self._click_cell
        self._click_cell = None
        self._click_timer.stop()
        if cell is not None and self.state() != QtWidgets.QAbstractItemView.EditingState:
            self._grid._begin_paint(*cell)
            self._grid._end_paint()

    def leaveEvent(self, event):
        self._grid._on_cell_leave()
        super().leaveEvent(event)
