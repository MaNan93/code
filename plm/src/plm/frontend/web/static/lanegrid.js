// LaneGrid -- direct-manipulation grid for lane_mapping.csv. Every cell is
// colored by which controller currently owns it -- a real WYSIWYG view of
// the topology, not a text description of a selection.
//
// Port of plmConsultant.py's LaneMappingGrid (tool/plmConsultant.py:505-908):
// click a controller swatch to make it the "active paint controller", then
// click-and-drag across a block of cells to paint them (repainted from a
// snapshot on every step, so backtracking un-paints cleanly); a plain click
// with no movement paints nothing. Double-click a cell to hand-type its
// exact value. Right-click a mode row to delete it; drag a mode row to
// reorder (native HTML5 drag-and-drop here, unlike the Tk version's manual
// ghost-follows-cursor tracking -- the browser gives this for free).
//
// Public interface deliberately mirrors EditableTable's (getRows/setRows/
// setColumns), so app.js barely has to know which one it's holding.
"use strict";

const LANE_GRID_PALETTE = [
  "#4C78A8", "#F58518", "#54A24B", "#E45756", "#72B7B2",
  "#EECA3B", "#B279A2", "#FF9DA6", "#9D755D", "#17BECF",
  "#B5B02B", "#7B6FD1",
];
const LANE_GRID_UNASSIGNED_BG = "#e6e6e6";

// Lane column widths step up geometrically as the lane count drops. x32
// is the reference -- it fills the available page width -- and each
// halving of the lane count makes every lane column 1.68x wider:
//   x32 -> 1x, x16 -> 1.68x, x8 -> 1.68^2x, x4 -> 1.68^3x ...
// (i.e. x16 is 1.68x the width of x32; x8 is 1.68x the width of x16;
// x4 is 1.68x the width of x8; and so on). The widths are recomputed on
// resize from the actual page width, so the grid stays proportional at
// any window size. The fixed columns (mode / actions) and the card
// padding are subtracted first so x32 lands exactly inside the page.
const LANE_W_RATIO = 1.68;   // column-width multiplier per halving
const LANE_MODE_W = 64;      // must match .lane-grid .lg-mode-cell min-width
const LANE_ACTIONS_W = 68;   // must match .lane-grid .lg-row-actions min-width
const LANE_CARD_PAD = 28;    // #page-lanemapping .card horizontal padding (14px x2)
const LANE_SHADOW_GAP = 20;  // breathing room so the card's shadow shows
const LANE_MIN_CELL = 26;    // absolute floor: still fits a two-digit port

function contrastTextColor(hex) {
  hex = (hex || "").replace("#", "");
  const r = parseInt(hex.slice(0, 2), 16), g = parseInt(hex.slice(2, 4), 16), b = parseInt(hex.slice(4, 6), 16);
  const luminance = 0.299 * r + 0.587 * g + 0.114 * b;
  return luminance > 140 ? "#000000" : "#ffffff";
}

class LaneGrid {
  constructor(container) {
    this.container = typeof container === "string" ? document.getElementById(container) : container;
    this.laneCount = 0;
    this.data = []; // [{mode: "0", lane0: "0-0", ...}, ...]
    this.controllers = []; // [{ctrl_id, ctrl_name}, ...]
    this.colorById = {};
    this.activeCtrlId = null;

    this._cellEls = new Map(); // "r,l" -> td
    this._modeEls = new Map(); // r -> td

    this._dragActive = false;
    this._dragAnchor = null;
    this._dragCurrent = null;
    this._dragSnapshot = null;
    this._modeDragFrom = null;
    this._hoverCell = null; // [r, l] under the cursor, for the pen preview

    this._editorInput = null;
    this._editorCommit = null;

    this._boundMouseMove = (e) => this._onMouseMove(e);
    this._boundMouseUp = () => {
      if (this._dragActive) {
        this._dragActive = false;
        // stroke finished: refresh so the hover preview comes back
        this._refreshCellStyles();
      }
    };
    document.addEventListener("mousemove", this._boundMouseMove);
    document.addEventListener("mouseup", this._boundMouseUp);

    // Lane column widths are derived from the page width, so they have to
    // be recomputed whenever the window (or the sidebar) resizes.
    this._boundResize = () => this._applyLaneWidth();
    window.addEventListener("resize", this._boundResize);

    this._buildShell();
    this._render();

    // The palette + wrapping card widths mirror the grid, but on a fresh
    // load the lane-mapping tab is display:none, so the first
    // _applyLaneWidth() reads a table width of 0 and never sets them --
    // leaving the palette at its CSS `width: 0`, which collapses every
    // grid track and makes the pills (which carry their own padding +
    // border) spill over one another. A ResizeObserver on the table
    // catches the 0 -> real-width transition when the tab is shown (and
    // every later relayout) and re-syncs them, so the pills never
    // collapse. The table is `width: max-content`, so writing the card
    // width back cannot feed into the table size -- no observer loop.
    if (typeof ResizeObserver === "function") {
      this._ro = new ResizeObserver(() => this._onTableResize());
      this._ro.observe(this.table);
    }
  }

  // Fires whenever the table's box changes -- crucially the 0 -> real
  // width transition when the lane-mapping tab is first shown (it is
  // display:none while the Controllers tab is active, so the initial
  // _applyLaneWidth() saw a host width of 0 and skipped the palette/card
  // sync). Only a change in the HOST width invalidates --lane-min-w;
  // otherwise we just re-mirror the palette / card widths, which keeps
  // the observer from ping-ponging against its own writes.
  _onTableResize() {
    const host = (this.container.closest && this.container.closest("#page-lanemapping")) || this.container;
    const hostW = host ? host.clientWidth : 0;
    if (hostW && hostW !== this._lastHostW) {
      this._applyLaneWidth();
    } else {
      this._syncSizes();
    }
  }

  // -- lane column sizing ---------------------------------------------
  // x32 fills the available width; every halving multiplies the column
  // width by LANE_W_RATIO (1.68), so x16 = 1.68 x32, x8 = 1.68 x16, ...
  // Called on every render and on window resize.
  _applyLaneWidth() {
    const host = (this.container.closest && this.container.closest("#page-lanemapping")) || this.container;
    const hostW = host ? host.clientWidth : 0;
    const n = Math.max(1, this.laneCount || 32);
    const avail = hostW - LANE_CARD_PAD - LANE_SHADOW_GAP - LANE_MODE_W - LANE_ACTIONS_W;
    const w32 = avail > 0 ? avail / 32 : 0;                       // x32 baseline
    const w = w32 * Math.pow(LANE_W_RATIO, Math.log2(32 / n));    // scale up as lanes drop
    const minW = Math.max(w, LANE_MIN_CELL);                      // never below a legible port
    this.table.style.setProperty("--lane-min-w", minW.toFixed(2) + "px");
    this._lastHostW = hostW; // let _onTableResize's guard actually skip a no-op resize

    this._syncSizes();
  }

  // The palette block is exactly as wide as the grid (see style.css), and
  // the wrapping card is grid + card padding so its rounded rectangle
  // hugs the table and the shadow stays visible. Split out of
  // _applyLaneWidth so the ResizeObserver can re-run just this part when
  // the tab becomes visible (the table's width is 0 while it is hidden,
  // so there is nothing to mirror yet -- skip in that case and let the
  // observer call back once the real width lands).
  _syncSizes() {
    if (!this.table) return;
    const tableW = this.table.getBoundingClientRect().width;
    if (!tableW) return;
    if (this._paletteInner) {
      this._paletteInner.style.width = tableW.toFixed(1) + "px";
    }
    const card = this.container.closest ? this.container.closest(".card") : null;
    if (card) {
      card.style.width = (tableW + LANE_CARD_PAD).toFixed(1) + "px";
    }
  }

  // -- public data interface -----------------------------------------
  getRows() {
    return this.data.map((r) => ({...r}));
  }

  setRows(rows) {
    this.data = (rows || []).map((r) => ({...r}));
    this._renderBody();
  }

  // columns: [{key:"mode",...}, {key:"lane0",...}, ...] -- same shape
  // app.js's mappingColumns() already builds for the old EditableTable,
  // kept as-is so the caller doesn't need to change.
  setColumns(columns) {
    this.laneCount = Math.max(0, (columns || []).length - 1);
    this._render();
  }

  setControllers(rows) {
    this.controllers = (rows || []).filter((r) => (r.ctrl_id || "").trim() !== "");
    this.colorById = {};
    this.controllers.forEach((c, i) => { this.colorById[c.ctrl_id] = LANE_GRID_PALETTE[i % LANE_GRID_PALETTE.length]; });
    if (!(this.activeCtrlId in this.colorById)) {
      this.activeCtrlId = this.controllers.length ? this.controllers[0].ctrl_id : null;
    }
    this._renderPalette();
    this._applyPaintCursor();
    this._refreshCellStyles();
  }

  addRow() { this.addModeRow(); }
  addModeRow() {
    const row = {mode: String(this.data.length)};
    for (let l = 0; l < this.laneCount; l++) row[`lane${l}`] = "0-0";
    this.data.push(row);
    this._renderBody();
  }

  deleteSelected() { this.removeLastModeRow(); }
  removeLastModeRow() {
    if (this.data.length) this.data.pop();
    this._renderBody();
  }

  _deleteRow(idx) {
    if (idx >= 0 && idx < this.data.length) {
      this.data.splice(idx, 1);
      this.data.forEach((rr, i) => { rr.mode = String(i); });
      this._renderBody();
    }
  }

  _insertRowBelow(idx) {
    if (idx < 0 || idx >= this.data.length) {
      this.addModeRow();
      return;
    }
    const row = {mode: String(idx + 1)};
    for (let l = 0; l < this.laneCount; l++) row[`lane${l}`] = "0-0";
    this.data.splice(idx + 1, 0, row);
    this.data.forEach((rr, i) => { rr.mode = String(i); });
    this._renderBody();
  }

  // -- shell (palette bar + scrollable grid area) ----------------------
  _buildShell() {
    this.container.innerHTML = "";
    const paletteBar = document.createElement("div");
    paletteBar.className = "lg-palette-bar";
    this._paletteInner = document.createElement("span");
    this._paletteInner.className = "lg-palette-inner";
    paletteBar.appendChild(this._paletteInner);
    this.container.appendChild(paletteBar);

    this._scrollArea = document.createElement("div");
    this._scrollArea.className = "lg-scroll";
    this.container.appendChild(this._scrollArea);

    this.table = document.createElement("table");
    this.table.className = "lane-grid";
    this._scrollArea.appendChild(this.table);
  }

  _renderPalette() {
    this._paletteInner.innerHTML = "";
    for (const c of this.controllers) {
      const cid = c.ctrl_id;
      const color = this.colorById[cid];
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "lg-swatch" + (cid === this.activeCtrlId ? " active" : "");
      btn.textContent = c.ctrl_name || cid;
      btn.style.background = color;
      btn.style.color = contrastTextColor(color);
      btn.onclick = () => this._setActiveController(cid);
      this._paletteInner.appendChild(btn);
    }
  }

  _setActiveController(cid) {
    this.activeCtrlId = cid;
    this._renderPalette();
    this._applyPaintCursor();
    this._refreshCellStyles();
  }

  // -- pen cursor -------------------------------------------------------
  // The lane area behaves like a pen: the cursor becomes a brush loaded
  // with the active controller's colour, and hovering a cell shows a
  // faded preview of what a click would paint. The brush is a small SVG
  // data URI whose fill is the active colour, with its hotspot at the
  // tip (3, 24) so the nib sits exactly on the cell.
  _applyPaintCursor() {
    const color = this.colorById[this.activeCtrlId] || "#6b7280";
    this.table.style.setProperty("--lane-paint-color", color);
    this.table.style.cursor = this._penCursorUrl(color);
  }

  _penCursorUrl(color) {
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26">' +
      '<path d="M2.4 23.6l1.5-5.9L16.5 5.1l4.4 4.4L8.3 22.1 2.4 23.6z" ' +
      'fill="' + color + '" stroke="#1f1f1f" stroke-width="1.3" stroke-linejoin="round"/>' +
      '<path d="M14.9 6.8l4.4 4.4" stroke="#ffffff" stroke-opacity="0.85" stroke-width="1.2"/>' +
      '</svg>';
    return 'url("data:image/svg+xml;utf8,' + encodeURIComponent(svg) + '") 3 24, crosshair';
  }

  _onCellEnter(r, l) {
    this._hoverCell = [r, l];
    this._refreshCellStyles();
  }

  _onCellLeave(r, l) {
    if (this._hoverCell && this._hoverCell[0] === r && this._hoverCell[1] === l) {
      this._hoverCell = null;
      this._refreshCellStyles();
    }
  }

  // -- grid construction ------------------------------------------------
  // _render() rebuilds the whole table (colgroup + thead + tbody) -- only
  // needed when the column structure itself changes (setColumns, i.e. the
  // lane count). Row-level edits (setRows, insert/delete/reorder a mode
  // row) reuse the existing colgroup/thead and call _renderBody() alone,
  // which is much cheaper than tearing down and recreating every lane
  // cell's event handlers on every single-row edit.
  _render() {
    this.table.innerHTML = "";

    // table-layout: auto sizes each lane column to its content. The
    // per-cell min-width is driven by --lane-min-w, computed from the
    // current lane count (see laneMinWidth) so columns widen
    // geometrically as lanes get sparser. The grid is therefore only as
    // wide as it needs to be, and the wrapping card shrinks to fit it --
    // keeping the rounded rectangle's shadow visible all the way around.
    this.table.className = "lane-grid";
    const colgroup = document.createElement("colgroup");
    const modeCol = document.createElement("col");
    modeCol.className = "lg-mode-col";
    colgroup.appendChild(modeCol);
    for (let l = 0; l < this.laneCount; l++) {
      const laneCol = document.createElement("col");
      laneCol.className = "lg-lane-col";
      colgroup.appendChild(laneCol);
    }
    const actionsCol = document.createElement("col");
    actionsCol.className = "lg-actions-col";
    colgroup.appendChild(actionsCol);
    this.table.appendChild(colgroup);

    const thead = document.createElement("thead");
    const htr = document.createElement("tr");
    const modeHeader = document.createElement("th");
    modeHeader.textContent = "mode";
    htr.appendChild(modeHeader);
    for (let l = 0; l < this.laneCount; l++) {
      const th = document.createElement("th");
      th.textContent = `L${l}`;
      htr.appendChild(th);
    }
    const actionsHeader = document.createElement("th");
    actionsHeader.className = "lg-actions-th";
    htr.appendChild(actionsHeader);
    thead.appendChild(htr);
    this.table.appendChild(thead);

    this._tbody = document.createElement("tbody");
    this.table.appendChild(this._tbody);

    this._renderBody();
    this._applyLaneWidth();
    // If the first render happened before layout (host width still 0,
    // e.g. the tab was hidden), recompute once the frame is painted.
    if (typeof requestAnimationFrame === "function") {
      requestAnimationFrame(() => this._applyLaneWidth());
    }
  }

  _renderBody() {
    this._tbody.innerHTML = "";
    this._cellEls.clear();
    this._modeEls.clear();

    const tbody = this._tbody;
    this.data.forEach((row, r) => {
      const tr = document.createElement("tr");

      const modeTd = document.createElement("td");
      modeTd.className = "lg-mode-cell";
      modeTd.draggable = true;
      modeTd.dataset.row = String(r);
      modeTd.title = "Drag to reorder";
      modeTd.ondragstart = (e) => {
        this._modeDragFrom = r;
        e.dataTransfer.effectAllowed = "move";
        e.dataTransfer.setData("text/plain", String(r));
      };
      modeTd.ondragover = (e) => { e.preventDefault(); e.dataTransfer.dropEffect = "move"; };
      modeTd.ondrop = (e) => {
        e.preventDefault();
        const from = this._modeDragFrom != null ? this._modeDragFrom : Number(e.dataTransfer.getData("text/plain"));
        if (Number.isInteger(from) && from !== r) {
          const [moved] = this.data.splice(from, 1);
          this.data.splice(r, 0, moved);
          this.data.forEach((rr, i) => { rr.mode = String(i); });
          this._renderBody();
        }
        this._modeDragFrom = null;
      };
      modeTd.ondblclick = () => this._beginInlineEdit(
        modeTd,
        () => this.data[r].mode || "",
        (v) => { this.data[r].mode = v; this._refreshCellStyles(); },
      );
      modeTd.oncontextmenu = (e) => {
        e.preventDefault();
        this._showContextMenu(e.clientX, e.clientY, [
          {label: "Delete this mode row", action: () => this._deleteRow(r)},
        ]);
      };
      tr.appendChild(modeTd);
      this._modeEls.set(r, modeTd);

      for (let l = 0; l < this.laneCount; l++) {
        const td = document.createElement("td");
        td.className = "lg-lane-cell";
        td.dataset.row = String(r);
        td.dataset.lane = String(l);
        td.onmousedown = (e) => {
          // Let clicks inside the inline editor behave normally (text
          // selection / caret placement) instead of starting a paint.
          if (e.target && e.target.classList &&
              e.target.classList.contains("lg-cell-editor")) return;
          e.preventDefault();
          this._onPress(r, l, e.detail);
        };
        td.onmouseenter = () => this._onCellEnter(r, l);
        td.onmouseleave = () => this._onCellLeave(r, l);
        td.ondblclick = () => {
          // Double-click means "edit this cell", not "paint it". The two
          // presses already laid down two strokes (see _onPress), so roll
          // the data back to the snapshot taken before the FIRST press
          // (e.detail === 1 keeps that snapshot intact on the second
          // press) and then open the inline editor on the clean value.
          if (this._dragSnapshot) {
            this.data = this._dragSnapshot.map((row) => ({...row}));
            this._refreshCellStyles();
          }
          this._beginInlineEdit(
            td,
            () => this.data[r][`lane${l}`] || "",
            (v) => { this.data[r][`lane${l}`] = v; this._refreshCellStyles(); },
          );
        };
        tr.appendChild(td);
        this._cellEls.set(`${r},${l}`, td);
      }

      // Per-row actions: + inserts a new mode row right below this one,
      // - removes this row. Replaces the old bottom + / - Mode buttons.
      const actionsTd = document.createElement("td");
      actionsTd.className = "lg-row-actions";
      const plusBtn = document.createElement("button");
      plusBtn.className = "row-action-btn plus";
      plusBtn.type = "button";
      plusBtn.textContent = "+";
      plusBtn.title = "Insert mode row below";
      plusBtn.onclick = (e) => { e.stopPropagation(); this._insertRowBelow(r); };
      actionsTd.appendChild(plusBtn);
      const minusBtn = document.createElement("button");
      minusBtn.className = "row-action-btn minus";
      minusBtn.type = "button";
      minusBtn.textContent = "\u2212"; // −
      minusBtn.title = "Delete this mode row";
      minusBtn.onclick = (e) => { e.stopPropagation(); this._deleteRow(r); };
      actionsTd.appendChild(minusBtn);
      tr.appendChild(actionsTd);

      tbody.appendChild(tr);
    });

    this._refreshCellStyles();
    this._applyPaintCursor();
  }

  _refreshCellStyles() {
    for (const [key, td] of this._cellEls) {
      // Never touch the cell that is currently being inline-edited: it
      // holds an <input>, and `td.textContent = port` would rip that
      // input straight out of the DOM. Because _onCellEnter() calls this
      // method, the editor used to vanish the instant the pointer moved
      // into ANY other cell -- which is not how the user expects to leave
      // an edit. Skipping it here means the editor only closes on an
      // explicit commit (Enter), cancel (Esc) or blur (click elsewhere).
      if (this._editorInput && td.contains(this._editorInput)) continue;
      const [r, l] = key.split(",").map(Number);
      const row = this.data[r];
      const val = row ? (row[`lane${l}`] || "") : "";
      const hasDash = val.includes("-");
      const cid = hasDash ? val.split("-", 1)[0] : null;
      const port = hasDash ? val.slice(val.indexOf("-") + 1) : val;
      const paint = (cid != null && this.colorById[cid]) ? this.colorById[cid] : null;
      td.textContent = port;
      if (paint) {
        // Painted cells read like a translucent marker stroke rather than
        // a solid fill: CSS (.lg-painted) lays a ~48% wash of the colour
        // over the card background and draws a hairline of the full
        // colour around the cell. Only --paint is set here; the colour
        // and background come from CSS so the two stay in sync.
        td.style.setProperty("--paint", paint);
        td.classList.add("lg-painted");
        td.style.removeProperty("background-color");
        td.style.removeProperty("color");
      } else {
        td.style.removeProperty("--paint");
        td.classList.remove("lg-painted");
        td.style.backgroundColor = LANE_GRID_UNASSIGNED_BG;
        td.style.color = "#333333";
      }
      // Pen preview: while hovering a cell (and not mid-stroke), tint it
      // with a faded version of the active colour so the user sees what a
      // click is about to paint. Suppressed during a drag -- the cells
      // are already being painted then.
      const preview = !this._dragActive && this.activeCtrlId != null &&
        this._hoverCell && this._hoverCell[0] === r && this._hoverCell[1] === l;
      td.classList.toggle("lg-preview", !!preview);
    }
    for (const [r, td] of this._modeEls) {
      // Same guard as the lane cells above -- the mode cell is editable
      // too (double-click the mode number).
      if (this._editorInput && td.contains(this._editorInput)) continue;
      const row = this.data[r];
      td.textContent = row ? (row.mode || "") : "";
    }
  }

  // -- paint-drag -------------------------------------------------------
  // `detail` is the mousedown click count: 1 for a plain press, 2 when
  // the press is the second half of a double-click. We snapshot the data
  // only on detail <= 1 so a double-click's roll-back (see ondblclick)
  // has a baseline from BEFORE the first stroke.
  _onPress(r, l, detail) {
    // Pressing another cell finishes any in-progress inline edit first.
    // The preventDefault() in the caller suppresses the focus change, so
    // the editor would otherwise stay open with its caret blinking. It
    // must run BEFORE the snapshot below so the committed value becomes
    // part of the paint baseline.
    if (this._editorInput) this._editorCommit(true);

    this._dragActive = true;
    this._dragAnchor = [r, l];
    this._dragCurrent = [r, l];
    if (!(detail > 1)) {
      this._dragSnapshot = this.data.map((row) => ({...row}));
    }
    // Lay the stroke down on press so a plain single click (press +
    // release with no movement) still paints one cell -- previously only
    // mouse movement triggered a paint, so clicking did nothing.
    this._paintCurrentRect();
  }

  _onMouseMove(e) {
    if (!this._dragActive) return;
    const el = document.elementFromPoint(e.clientX, e.clientY);
    const td = el && el.closest ? el.closest("td.lg-lane-cell") : null;
    if (!td || !this.table.contains(td)) return;
    const r = Number(td.dataset.row), l = Number(td.dataset.lane);
    if (r !== this._dragCurrent[0] || l !== this._dragCurrent[1]) {
      this._dragCurrent = [r, l];
      this._paintCurrentRect();
    }
  }

  _paintCurrentRect() {
    if (!this._dragSnapshot) return;
    this.data = this._dragSnapshot.map((row) => ({...row}));
    const [r0, l0] = this._dragAnchor;
    const [r1, l1] = this._dragCurrent;
    const rowLo = Math.min(r0, r1), rowHi = Math.max(r0, r1);
    const laneLo = Math.min(l0, l1), laneHi = Math.max(l0, l1);
    if (this.activeCtrlId != null) {
      for (let r = rowLo; r <= rowHi; r++) {
        if (r >= this.data.length) continue;
        let i = 0;
        for (let l = laneLo; l <= laneHi; l++) {
          this.data[r][`lane${l}`] = `${this.activeCtrlId}-${i}`;
          i++;
        }
      }
    }
    this._refreshCellStyles();
  }

  // -- inline edit --------------------------------------------------------
  _beginInlineEdit(cellEl, getValue, setValue) {
    if (this._editorInput) this._editorCommit(true);
    const input = document.createElement("input");
    input.type = "text";
    input.className = "lg-cell-editor";
    input.value = getValue();
    cellEl.textContent = "";
    cellEl.appendChild(input);
    input.focus();
    input.select();
    this._editorInput = input;
    this._editorCommit = (save) => {
      const val = input.value;
      // Detach the instance refs BEFORE removing the input. Removing a
      // focused element fires `blur` synchronously, and the blur handler
      // below re-commits whenever `this._editorInput === input` -- which
      // it still was, so the removal itself triggered a SECOND, saving
      // commit that overwrote an Escape (Escape looked broken: the value
      // got saved anyway). Nulling first makes the blur a no-op and stops
      // any re-entrant commit.
      this._editorInput = null;
      this._editorCommit = null;
      if (input.parentNode) input.remove();
      if (save) setValue(val);
      else this._refreshCellStyles();
    };
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") this._editorCommit(true);
      else if (e.key === "Escape") this._editorCommit(false);
    });
    input.addEventListener("blur", () => { if (this._editorInput === input) this._editorCommit(true); });
  }

  // -- context menu -------------------------------------------------------
  _showContextMenu(x, y, items) {
    this._hideContextMenu();
    const menu = document.createElement("ul");
    menu.className = "lg-ctx-menu";
    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
    for (const item of items) {
      const li = document.createElement("li");
      li.textContent = item.label;
      li.onclick = () => { item.action(); this._hideContextMenu(); };
      menu.appendChild(li);
    }
    document.body.appendChild(menu);
    this._ctxMenu = menu;
    setTimeout(() => document.addEventListener("click", this._boundHideCtx = () => this._hideContextMenu(), {once: true}), 0);
  }

  _hideContextMenu() {
    if (this._ctxMenu) { this._ctxMenu.remove(); this._ctxMenu = null; }
  }
}
