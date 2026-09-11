// EditableTable -- a small, dependency-free editable <table> component.
//
// Layout per row (always):
//   [drag handle] <data columns...> [+ button] [- button]
//
// Drag-to-reorder is enabled unconditionally -- no Up/Down arrows.
// If `idColumn` is set, that column is rendered as a read-only index and
// gets auto-renumbered on every insert/delete/reorder.
//
// Mirrors plmConsultant.py's EditableTable (tool/plmConsultant.py:76) but
// with the + / - / drag controls as per-row icons, and no bottom
// + Row / - Row button row.
"use strict";

class EditableTable {
  // columns: [{key, heading, options?: [...], width?: "34%"}] -- options
  //          makes that column a <select> instead of a free-text <input>;
  //          width (any CSS length) pins that column, and the remaining
  //          columns share whatever space is left.
  // idColumn: optional key of a column that's a pure row-order index
  //          (0, 1, 2, ...); kept read-only and auto-renumbered after
  //          every insert / delete / drag-reorder.
  constructor(container, {columns, idColumn = null}) {
    this.container = typeof container === "string" ? document.getElementById(container) : container;
    this.idColumn = idColumn;
    this.columns = columns;
    this.rows = []; // seed values; live data always read from DOM via getRows()
    this._dragFrom = null;
    this._render();
  }

  setColumns(columns) {
    this.columns = columns;
    this._render();
  }

  getRows() {
    // Pull current values out of the live DOM (not this.rows, which is
    // only used to seed rendering) so an in-progress edit is captured
    // even without a blur event.
    const out = [];
    for (const tr of this.tbody.children) {
      const row = {};
      for (const col of this.columns) {
        const el = tr.querySelector(`[data-key="${col.key}"]`);
        row[col.key] = el ? el.value : "";
      }
      out.push(row);
    }
    return out;
  }

  setRows(rows) {
    this.rows = (rows || []).map((r) => ({...r}));
    if (this.idColumn) this._renumber();
    this._renderBody();
  }

  insertRowBelow(idx) {
    const row = {};
    for (const col of this.columns) row[col.key] = col.options ? col.options[0] : "";
    this.rows = this.getRows();
    this.rows.splice(idx + 1, 0, row);
    if (this.idColumn) this._renumber();
    this._renderBody();
  }

  deleteRow(idx) {
    this.rows = this.getRows();
    this.rows.splice(idx, 1);
    if (this.idColumn) this._renumber();
    this._renderBody();
  }

  _renumber() {
    this.rows.forEach((r, i) => { r[this.idColumn] = String(i); });
  }

  _render() {
    this.container.innerHTML = "";
    const table = document.createElement("table");
    table.className = "edit-table";

    // colgroup: handle (fixed), data cols (per-column width if the column
    // config sets one, otherwise auto-distribute the leftover space),
    // actions (fixed). With table-layout: fixed the browser keeps any
    // explicit column width and splits the remaining space across the
    // unspecified columns.
    const colgroup = document.createElement("colgroup");
    const handleCol = document.createElement("col");
    handleCol.className = "handle-col";
    colgroup.appendChild(handleCol);
    for (const col of this.columns) {
      const c = document.createElement("col");
      if (col.width) c.style.width = col.width;
      colgroup.appendChild(c);
    }
    const actionsCol = document.createElement("col");
    actionsCol.className = "actions-col";
    colgroup.appendChild(actionsCol);
    table.appendChild(colgroup);

    const thead = document.createElement("thead");
    const htr = document.createElement("tr");
    const handleTh = document.createElement("th");
    handleTh.className = "rowhandle-th";
    htr.appendChild(handleTh);
    for (const col of this.columns) {
      const th = document.createElement("th");
      th.textContent = col.heading || col.key;
      htr.appendChild(th);
    }
    const actionsTh = document.createElement("th");
    actionsTh.className = "rowactions-th";
    htr.appendChild(actionsTh);
    thead.appendChild(htr);
    table.appendChild(thead);

    this.tbody = document.createElement("tbody");
    table.appendChild(this.tbody);
    this.container.appendChild(table);

    this._renderBody();
  }

  _renderBody() {
    this.tbody.innerHTML = "";
    this.rows.forEach((row, idx) => {
      const tr = document.createElement("tr");
      tr.className = idx % 2 ? "oddrow" : "evenrow";

      // 1. drag handle
      const handle = document.createElement("td");
      handle.className = "rowhandle";
      handle.textContent = "\u2261"; // ≡
      handle.draggable = true;
      handle.title = "Drag to reorder";
      handle.ondragstart = (e) => {
        this._dragFrom = idx;
        e.dataTransfer.effectAllowed = "move";
        e.dataTransfer.setData("text/plain", String(idx));
      };
      tr.appendChild(handle);

      // 2. data columns
      for (const col of this.columns) {
        const td = document.createElement("td");
        let el;
        if (col.options) {
          el = document.createElement("select");
          for (const opt of col.options) {
            const o = document.createElement("option");
            o.value = opt;
            o.textContent = opt;
            el.appendChild(o);
          }
        } else {
          el = document.createElement("input");
          el.type = "text";
        }
        el.dataset.key = col.key;
        el.value = row[col.key] != null ? row[col.key] : "";
        if (col.key === this.idColumn) el.readOnly = true;
        td.appendChild(el);
        tr.appendChild(td);
      }

      // 3. actions column: + (insert below) / - (delete this row)
      const actions = document.createElement("td");
      actions.className = "rowactions";
      const plusBtn = document.createElement("button");
      plusBtn.className = "row-action-btn plus";
      plusBtn.type = "button";
      plusBtn.textContent = "+";
      plusBtn.title = "Insert row below";
      plusBtn.onclick = (e) => { e.stopPropagation(); this.insertRowBelow(idx); };
      actions.appendChild(plusBtn);
      const minusBtn = document.createElement("button");
      minusBtn.className = "row-action-btn minus";
      minusBtn.type = "button";
      minusBtn.textContent = "\u2212"; // −
      minusBtn.title = "Delete this row";
      minusBtn.onclick = (e) => { e.stopPropagation(); this.deleteRow(idx); };
      actions.appendChild(minusBtn);
      tr.appendChild(actions);

      // 4. drop target on the whole row (so the user can drop anywhere,
      //    not just onto the small handle cell)
      tr.ondragover = (e) => { e.preventDefault(); e.dataTransfer.dropEffect = "move"; };
      tr.ondrop = (e) => {
        e.preventDefault();
        const from = this._dragFrom != null ? this._dragFrom : Number(e.dataTransfer.getData("text/plain"));
        const to = idx;
        if (Number.isInteger(from) && from !== to) {
          this.rows = this.getRows();
          const [moved] = this.rows.splice(from, 1);
          this.rows.splice(to, 0, moved);
          if (this.idColumn) this._renumber();
          this._renderBody();
        }
        this._dragFrom = null;
      };

      this.tbody.appendChild(tr);
    });
  }
}