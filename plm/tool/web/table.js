// EditableTable -- a small, dependency-free editable <table> component.
// Mirrors plmConsultant.py's EditableTable (tool/plmConsultant.py:76):
// double-click-free (plain inputs, always editable) grid of text/select
// cells, add/delete row buttons, and either drag-to-reorder with an
// auto-renumbered id column, or Move Up/Down buttons for a plain ordered
// list. Cell values are always strings, same as the Tk version.
"use strict";

class EditableTable {
  // columns: [{key, heading, options?: [...]}] -- options makes that
  // column a <select> instead of a free-text <input>.
  // idColumn: key of a column that's a pure row-order index (0,1,2,...),
  // kept non-editable and auto-renumbered on every add/delete/reorder --
  // enables drag-to-reorder instead of Move Up/Down buttons.
  constructor(container, {columns, idColumn = null, addLabel = "+ Row", deleteLabel = "- Row"}) {
    this.container = typeof container === "string" ? document.getElementById(container) : container;
    this.idColumn = idColumn;
    this.addLabel = addLabel;
    this.deleteLabel = deleteLabel;
    this.rows = []; // array of plain objects, key -> string
    this._dragFrom = null;
    this.setColumns(columns);
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

  addRow() {
    const row = {};
    for (const col of this.columns) row[col.key] = col.options ? col.options[0] : "";
    if (this.idColumn) row[this.idColumn] = String(this.rows.length);
    this.rows = this.getRows();
    this.rows.push(row);
    this._renderBody();
  }

  deleteSelected() {
    const sel = this.tbody.querySelector("tr.selected");
    this.rows = this.getRows();
    if (sel) {
      const idx = Array.from(this.tbody.children).indexOf(sel);
      this.rows.splice(idx, 1);
    } else if (this.rows.length) {
      this.rows.pop();
    }
    if (this.idColumn) this._renumber();
    this._renderBody();
  }

  _move(idx, delta) {
    this.rows = this.getRows();
    const j = idx + delta;
    if (j < 0 || j >= this.rows.length) return;
    [this.rows[idx], this.rows[j]] = [this.rows[j], this.rows[idx]];
    this._renderBody();
  }

  _renumber() {
    this.rows.forEach((r, i) => { r[this.idColumn] = String(i); });
  }

  _render() {
    this.container.innerHTML = "";
    const table = document.createElement("table");
    table.className = "edit-table";
    const thead = document.createElement("thead");
    const htr = document.createElement("tr");
    if (this.idColumn) {
      const th = document.createElement("th");
      th.textContent = "";
      htr.appendChild(th);
    }
    for (const col of this.columns) {
      const th = document.createElement("th");
      th.textContent = col.heading || col.key;
      htr.appendChild(th);
    }
    htr.appendChild(document.createElement("th")); // actions column
    thead.appendChild(htr);
    table.appendChild(thead);
    this.tbody = document.createElement("tbody");
    table.appendChild(this.tbody);
    this.container.appendChild(table);

    const btns = document.createElement("div");
    btns.className = "btn-row";
    const addBtn = document.createElement("button");
    addBtn.textContent = this.addLabel;
    addBtn.onclick = () => this.addRow();
    btns.appendChild(addBtn);
    const delBtn = document.createElement("button");
    delBtn.textContent = this.deleteLabel;
    delBtn.onclick = () => this.deleteSelected();
    btns.appendChild(delBtn);
    if (this.idColumn) {
      const hint = document.createElement("span");
      hint.textContent = "  (drag a row to reorder)";
      hint.style.color = "var(--muted)";
      hint.style.alignSelf = "center";
      btns.appendChild(hint);
    }
    this.container.appendChild(btns);

    this._renderBody();
  }

  _renderBody() {
    this.tbody.innerHTML = "";
    this.rows.forEach((row, idx) => {
      const tr = document.createElement("tr");
      tr.className = idx % 2 ? "oddrow" : "evenrow";
      tr.onclick = () => {
        for (const other of this.tbody.children) other.classList.remove("selected");
        tr.classList.add("selected");
      };

      if (this.idColumn) {
        const handle = document.createElement("td");
        handle.className = "rowhandle";
        handle.textContent = "≡";
        handle.draggable = true;
        handle.ondragstart = (e) => {
          this._dragFrom = idx;
          e.dataTransfer.effectAllowed = "move";
          e.dataTransfer.setData("text/plain", String(idx));
        };
        tr.appendChild(handle);
      }

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

      const actions = document.createElement("td");
      actions.className = "rowactions";
      if (!this.idColumn) {
        const up = document.createElement("button");
        up.textContent = "↑";
        up.title = "Move up";
        up.onclick = (e) => { e.stopPropagation(); this._move(idx, -1); };
        const down = document.createElement("button");
        down.textContent = "↓";
        down.title = "Move down";
        down.onclick = (e) => { e.stopPropagation(); this._move(idx, 1); };
        actions.appendChild(up);
        actions.appendChild(down);
      }
      tr.appendChild(actions);

      if (this.idColumn) {
        tr.ondragover = (e) => { e.preventDefault(); e.dataTransfer.dropEffect = "move"; };
        tr.ondrop = (e) => {
          e.preventDefault();
          const from = this._dragFrom != null ? this._dragFrom : Number(e.dataTransfer.getData("text/plain"));
          const to = idx;
          if (Number.isInteger(from) && from !== to) {
            this.rows = this.getRows();
            const [moved] = this.rows.splice(from, 1);
            this.rows.splice(to, 0, moved);
            this._renumber();
            this._renderBody();
          }
          this._dragFrom = null;
        };
      }

      this.tbody.appendChild(tr);
    });
  }
}
