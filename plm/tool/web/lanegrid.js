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

    this._editorInput = null;
    this._editorCommit = null;

    this._boundMouseMove = (e) => this._onMouseMove(e);
    this._boundMouseUp = () => { this._dragActive = false; };
    document.addEventListener("mousemove", this._boundMouseMove);
    document.addEventListener("mouseup", this._boundMouseUp);

    this._buildShell();
    this._render();
  }

  // -- public data interface -----------------------------------------
  getRows() {
    return this.data.map((r) => ({...r}));
  }

  setRows(rows) {
    this.data = (rows || []).map((r) => ({...r}));
    this._render();
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
    this._refreshCellStyles();
  }

  addRow() { this.addModeRow(); }
  addModeRow() {
    const row = {mode: String(this.data.length)};
    for (let l = 0; l < this.laneCount; l++) row[`lane${l}`] = "0-0";
    this.data.push(row);
    this._render();
  }

  deleteSelected() { this.removeLastModeRow(); }
  removeLastModeRow() {
    if (this.data.length) this.data.pop();
    this._render();
  }

  _deleteRow(idx) {
    if (idx >= 0 && idx < this.data.length) {
      this.data.splice(idx, 1);
      this._render();
    }
  }

  // -- shell (palette bar + scrollable grid area) ----------------------
  _buildShell() {
    this.container.innerHTML = "";
    const paletteBar = document.createElement("div");
    paletteBar.className = "lg-palette-bar";
    const label = document.createElement("span");
    label.textContent = "Paint controller:";
    paletteBar.appendChild(label);
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
  }

  // -- grid construction ------------------------------------------------
  _render() {
    this.table.innerHTML = "";
    this._cellEls.clear();
    this._modeEls.clear();

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
    thead.appendChild(htr);
    this.table.appendChild(thead);

    const tbody = document.createElement("tbody");
    this.data.forEach((row, r) => {
      const tr = document.createElement("tr");

      const modeTd = document.createElement("td");
      modeTd.className = "lg-mode-cell";
      modeTd.draggable = true;
      modeTd.dataset.row = String(r);
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
          this._render();
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
        td.onmousedown = (e) => { e.preventDefault(); this._onPress(r, l); };
        td.ondblclick = () => this._beginInlineEdit(
          td,
          () => this.data[r][`lane${l}`] || "",
          (v) => { this.data[r][`lane${l}`] = v; this._refreshCellStyles(); },
        );
        tr.appendChild(td);
        this._cellEls.set(`${r},${l}`, td);
      }

      tbody.appendChild(tr);
    });
    this.table.appendChild(tbody);

    this._refreshCellStyles();
  }

  _refreshCellStyles() {
    for (const [key, td] of this._cellEls) {
      const [r, l] = key.split(",").map(Number);
      const row = this.data[r];
      const val = row ? (row[`lane${l}`] || "") : "";
      const hasDash = val.includes("-");
      const cid = hasDash ? val.split("-", 1)[0] : null;
      const port = hasDash ? val.slice(val.indexOf("-") + 1) : val;
      const color = (cid != null && this.colorById[cid]) ? this.colorById[cid] : LANE_GRID_UNASSIGNED_BG;
      td.textContent = port;
      td.style.background = color;
      td.style.color = (cid != null && this.colorById[cid]) ? contrastTextColor(color) : "#333333";
    }
    for (const [r, td] of this._modeEls) {
      const row = this.data[r];
      td.textContent = row ? (row.mode || "") : "";
    }
  }

  // -- paint-drag -------------------------------------------------------
  _onPress(r, l) {
    this._dragActive = true;
    this._dragAnchor = [r, l];
    this._dragCurrent = [r, l];
    this._dragSnapshot = this.data.map((row) => ({...row}));
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
      if (input.parentNode) input.remove();
      this._editorInput = null;
      this._editorCommit = null;
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
