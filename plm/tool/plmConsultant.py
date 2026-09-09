#!/usr/bin/env python3
"""
plmConsultant -- PIPE Lane Mapper config editor + generator GUI.

A thin, stdlib-only (tkinter) front end over the same three config CSVs /
gen_flags.txt that tool/plm_gen_rtl.py and tool/plm_gen_tb.py read, and
over those two tools themselves. It doesn't duplicate any generation or
validation logic -- editing writes the same plain files a human would
hand-edit, "Validate" calls plm_config.Config directly, and "Generate"
just shells out to the two real CLI tools, the same way the Makefile
does, and streams their output.

A "workspace" is a single config set's own directory -- it holds config/
directly (the three CSVs + gen_flags.txt) plus whatever rtl/ and tb/ the
generators have written into it, exactly the shape resolve_set() already
expects (--config <dir>). It is an arbitrary directory chosen at runtime
(see PlmGui._set_workspace), not a path fixed at import time -- this
project's own configs/test_quad, configs/test_bifurcate, etc. are each
independently a workspace; configs/ itself is just a folder of examples,
not a workspace. A workspace holds exactly one config, not a collection
of named sets.

Run: python tool/plmConsultant.py
"""

import csv
import json
import math
import queue
import shutil
import subprocess
import sys
import threading
import time
import tkinter as tk
import webbrowser
from pathlib import Path
from tkinter import filedialog, messagebox, simpledialog, ttk

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from plm_common import (  # noqa: E402
    CONFIGS_ROOT,
    PLM_ROOT,
    _PCLK_MODE_MIGRATION,
    find_verible,
    has_csvs,
    list_configs,
)
from plm_config import Config, _stripped  # noqa: E402

PCLK_MODES = ["(default: pclk_as_phy_output)", "pclk_as_phy_output", "pclk_as_phy_input"]
SEL_MODES = ["(default: sync)", "sync", "comb"]
DIRECTIONS = ["mac2phy", "phy2mac"]
SIGNAL_TYPES = ["perlane", "shared"]
LANE_COUNTS = ["1", "2", "4", "8", "16", "32"]
ACTIVITY_ITEMS = ["Controllers", "Lane Mapping", "Pipe Signals", "Generation Flags"]

# Remembers the last workspace directory across runs -- a workspace is
# often outside this repo entirely (a consultant's own working directory
# for a given engagement), so this lives in the user's home directory
# rather than next to the project.
WORKSPACE_STATE_FILE = Path.home() / ".plmconsultant_workspace.json"


# ---------------------------------------------------------------- editable table


class EditableTable(ttk.Frame):
    """A ttk.Treeview with double-click-to-edit cells, plus add/delete-row
    buttons. Cell values are always strings; combobox_values gives certain
    columns a dropdown editor instead of a free-text Entry.

    id_column, if given, names a column that's treated as a pure row-order
    index rather than free-form data: it's kept non-editable and
    auto-renumbered to 0,1,2,... on every add/delete/reorder (Controllers'
    ctrl_id -- position IS its identity). Setting it also swaps the
    Move Up/Move Down buttons for drag-to-reorder on the rows themselves.
    """

    def __init__(self, parent, columns, combobox_values=None, col_width=110, height=8,
                 id_column=None, add_label="+ Row", delete_label="- Row"):
        super().__init__(parent)
        self.col_keys = [c[0] for c in columns]
        self.combobox_values = combobox_values or {}
        self.id_column = id_column

        self.tree = ttk.Treeview(
            self, columns=self.col_keys, show="headings", height=height, selectmode="browse"
        )
        for key, heading in columns:
            self.tree.heading(key, text=heading)
            self.tree.column(key, width=col_width, anchor="w")
        # ttk.Treeview draws no gridlines of its own -- without something to
        # tell rows apart, a mostly-empty table reads as one blank block and
        # the row count is illegible. Alternating background bands fix that.
        self.tree.tag_configure("evenrow", background="#ffffff")
        self.tree.tag_configure("oddrow", background="#e8edf3")
        vsb = ttk.Scrollbar(self, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vsb.set)
        self.tree.grid(row=0, column=0, columnspan=3, sticky="nsew")
        vsb.grid(row=0, column=3, sticky="ns")
        self.grid_columnconfigure(0, weight=1)

        btns = ttk.Frame(self)
        btns.grid(row=1, column=0, columnspan=4, sticky="w", pady=(4, 0))
        ttk.Button(btns, text=add_label, command=self.add_row).pack(side="left")
        ttk.Button(btns, text=delete_label, command=self.delete_selected).pack(side="left", padx=(6, 0))
        if id_column is None:
            ttk.Button(btns, text="Move Up", command=lambda: self._move(-1)).pack(
                side="left", padx=(6, 0)
            )
            ttk.Button(btns, text="Move Down", command=lambda: self._move(1)).pack(
                side="left", padx=(6, 0)
            )
        else:
            ttk.Label(btns, text="(drag a row to reorder)").pack(side="left", padx=(10, 0))

        self.tree.bind("<Double-1>", self._on_double_click)
        self._editor = None
        self._editor_click_binding = None

        self._drag_iid = None
        self._drag_moved = False
        self._drag_tooltip = None
        if id_column is not None:
            # add="+" on press keeps the Treeview's own click-to-select
            # binding; motion/release are NOT additive -- they replace
            # browse-mode's default "drag extends selection" behavior with
            # reordering instead.
            self.tree.bind("<ButtonPress-1>", self._on_drag_press, add="+")
            self.tree.bind("<B1-Motion>", self._on_drag_motion)
            self.tree.bind("<ButtonRelease-1>", self._on_drag_release)

    # -- data in/out -------------------------------------------------
    def get_rows(self):
        rows = []
        for iid in self.tree.get_children():
            vals = self.tree.item(iid)["values"]
            rows.append({k: str(v) for k, v in zip(self.col_keys, vals)})
        return rows

    def set_rows(self, rows):
        self.tree.delete(*self.tree.get_children())
        for r in rows:
            self.tree.insert("", "end", values=[r.get(k, "") for k in self.col_keys])
        self._restripe()
        self._renumber_id_column()

    def set_columns(self, columns, combobox_values=None):
        """Rebuild with a new column set, preserving values for columns
        that exist both before and after (used when lane count changes)."""
        old_rows = self.get_rows()
        self.col_keys = [c[0] for c in columns]
        self.combobox_values = combobox_values or {}
        self.tree.configure(columns=self.col_keys)
        for key, heading in columns:
            self.tree.heading(key, text=heading)
            self.tree.column(key, width=90, anchor="w")
        new_rows = [{k: r.get(k, "") for k in self.col_keys} for r in old_rows]
        self.set_rows(new_rows)

    # -- row ops -------------------------------------------------------
    def add_row(self):
        iid = self.tree.insert("", "end", values=["" for _ in self.col_keys])
        self._restripe()
        self._renumber_id_column()
        # Select/focus the new row so it's obvious where it landed, instead
        # of leaving the just-added row indistinguishable from the rest.
        self._select_row(iid)

    def delete_selected(self):
        sel = self.tree.selection()
        if sel:
            self.tree.delete(*sel)
            self._restripe()
            self._renumber_id_column()
            children = self.tree.get_children()
            if children:
                self._select_row(children[-1])

    def _select_row(self, iid):
        self.tree.selection_set(iid)
        self.tree.focus(iid)
        self.tree.see(iid)

    def _renumber_id_column(self):
        if self.id_column is None:
            return
        for i, iid in enumerate(self.tree.get_children()):
            self.tree.set(iid, self.id_column, str(i))

    # -- drag-to-reorder (id_column tables only) ---------------------------
    def _on_drag_press(self, event):
        self._drag_iid = self.tree.identify_row(event.y) or None
        self._drag_moved = False

    def _on_drag_motion(self, event):
        if self._drag_iid is None or not self.tree.exists(self._drag_iid):
            return
        # tree.move() alone is easy to miss mid-drag -- a swatch that
        # visibly tracks the cursor makes "yes, this is doing something"
        # unambiguous, regardless of whether this particular motion event
        # lands on a new target row. Reposition rather than recreate so it
        # doesn't flicker on every step.
        x, y = event.x_root + 12, event.y_root + 12
        if self._drag_tooltip is None:
            self._drag_tooltip = _make_drag_ghost(self.tree, x, y, "#4C78A8")
        else:
            self._drag_tooltip.wm_geometry(f"+{x}+{y}")
        target = self.tree.identify_row(event.y)
        if not target or target == self._drag_iid:
            return
        self.tree.move(self._drag_iid, "", self.tree.index(target))
        self._drag_moved = True
        self._restripe()

    def _on_drag_release(self, event):
        if self._drag_moved:
            self._renumber_id_column()
        if self._drag_tooltip is not None:
            self._drag_tooltip.destroy()
            self._drag_tooltip = None
        self._drag_iid = None
        self._drag_moved = False

    def _move(self, delta):
        sel = self.tree.selection()
        if not sel:
            return
        iid = sel[0]
        idx = self.tree.index(iid)
        new_idx = max(0, min(len(self.tree.get_children()) - 1, idx + delta))
        self.tree.move(iid, "", new_idx)
        self._restripe()

    def _restripe(self):
        for i, iid in enumerate(self.tree.get_children()):
            self.tree.item(iid, tags=("evenrow" if i % 2 == 0 else "oddrow",))

    # -- inline editing --------------------------------------------------
    def _on_double_click(self, event):
        if self._editor is not None:
            self._close_editor(save=True)
        row = self.tree.identify_row(event.y)
        col = self.tree.identify_column(event.x)
        if not row or not col:
            return
        col_idx = int(col[1:]) - 1
        if col_idx < 0 or col_idx >= len(self.col_keys):
            return
        key = self.col_keys[col_idx]
        if key == self.id_column:
            return  # auto-numbered by row position, not directly editable
        bbox = self.tree.bbox(row, col)
        if not bbox:
            return
        x, y, w, h = bbox
        current = self.tree.set(row, key)
        # Treeview only selects whole rows -- clicking to edit one cell
        # would otherwise highlight the entire row behind the small editor
        # overlay, when the editor itself already marks which cell is
        # active. Deselecting leaves just the one cell looking "focused".
        self.tree.selection_remove(row)

        if key in self.combobox_values:
            editor = ttk.Combobox(self.tree, values=self.combobox_values[key], state="readonly")
            editor.set(current)
        else:
            editor = ttk.Entry(self.tree)
            editor.insert(0, current)
            editor.select_range(0, "end")
        editor.place(x=x, y=y, width=w, height=h)
        editor.focus_set()
        self._editor = (editor, row, key)
        editor.bind("<Return>", lambda e: self._close_editor(save=True))
        editor.bind("<Escape>", lambda e: self._close_editor(save=False))
        if isinstance(editor, ttk.Combobox):
            # Not FocusOut: opening a readonly Combobox's own dropdown list
            # transiently blurs it in Tk's Windows theme, which would
            # otherwise destroy the editor (dropdown and all) before the
            # click on an option even lands -- this is why the dropdown
            # looked like it "closed instantly". ComboboxSelected already
            # commits on a real choice; Escape still cancels. But with
            # FocusOut gone, nothing else closes the editor on a plain
            # click elsewhere (e.g. the Save button, or another cell) --
            # watch clicks at the toplevel instead, same trick as
            # LaneMappingGrid's inline editor. The dropdown's own popup
            # list is a separate Tk toplevel, so clicks inside it never
            # reach this binding -- only a genuine click elsewhere does.
            editor.bind("<<ComboboxSelected>>", lambda e: self._close_editor(save=True))

            def on_click_outside(event, ed=editor):
                if event.widget is not ed:
                    self._close_editor(save=True)

            toplevel = self.winfo_toplevel()
            self._editor_click_binding = (toplevel, toplevel.bind("<Button-1>", on_click_outside, add="+"))
        else:
            editor.bind("<FocusOut>", lambda e: self._close_editor(save=True))

    def _close_editor(self, save):
        if self._editor is None:
            return
        editor, row, key = self._editor
        self._editor = None
        if self._editor_click_binding is not None:
            toplevel, bind_id = self._editor_click_binding
            toplevel.unbind("<Button-1>", bind_id)
            self._editor_click_binding = None
        if save and self.tree.exists(row):
            self.tree.set(row, key, editor.get())
        editor.destroy()


# ---------------------------------------------------------------- toolbar icons
#
# Text-based icons (emoji/dingbats) depend on whatever emoji font the host
# happens to have -- reliable on Windows (Segoe UI Emoji), inconsistent to
# outright broken on a lot of Linux setups with no color-emoji font
# installed. Drawing flat-color bitmaps by hand with tk.PhotoImage sidesteps
# fonts entirely -- raw pixel data renders identically on every platform Tk
# runs on, at the cost of the icons being simple geometric shapes rather
# than polished glyphs (tooltips carry the exact meaning regardless).


def _icon_blank(size=16):
    return tk.PhotoImage(width=size, height=size)


def _fill_rect(img, x0, y0, x1, y1, color):
    img.put(color, to=(x0, y0, x1, y1))


def _icon_plus(color="#2f6f3e"):
    img = _icon_blank()
    _fill_rect(img, 7, 3, 9, 13, color)
    _fill_rect(img, 3, 7, 13, 9, color)
    return img


def _icon_folder(color="#c98a1a"):
    img = _icon_blank()
    _fill_rect(img, 2, 4, 7, 6, color)
    _fill_rect(img, 2, 6, 14, 13, color)
    return img


def _icon_pin(color="#3a6ea5"):
    img = _icon_blank()
    _fill_rect(img, 3, 3, 13, 12, color)
    _fill_rect(img, 6, 4, 10, 6, "#ffffff")
    return img


def _icon_refresh(color="#3a6ea5"):
    img = _icon_blank()
    cx = cy = 7.5
    r_out, r_in = 6.5, 4.0
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - cx, y - cy)
            if r_in <= d <= r_out and not (-0.7 < math.atan2(y - cy, x - cx) < 0.7):
                img.put(color, to=(x, y, x + 1, y + 1))
    for i, y in enumerate(range(4, 7)):
        _fill_rect(img, 10 - i, y, 13 - i, y + 1, color)
    return img


def _icon_check(color="#2e8b57"):
    img = _icon_blank()
    for x, y in [(3, 8), (4, 9), (5, 10), (6, 11), (7, 10), (8, 8), (9, 6), (10, 4), (11, 3), (12, 2)]:
        _fill_rect(img, x, y, x + 2, y + 2, color)
    return img


def _icon_chip(color="#555555"):
    img = _icon_blank()
    _fill_rect(img, 4, 4, 12, 12, color)
    for x in (2, 6, 10):
        _fill_rect(img, x, 1, x + 2, 4, color)
        _fill_rect(img, x, 12, x + 2, 15, color)
    return img


def _icon_flask(color="#8a5fbf"):
    img = _icon_blank()
    _fill_rect(img, 7, 2, 9, 6, color)
    _fill_rect(img, 4, 6, 12, 8, color)
    _fill_rect(img, 3, 8, 13, 13, color)
    return img


def _icon_run_all(color="#c0392b"):
    img = _icon_blank()
    for i in range(5):
        _fill_rect(img, 3 + i, 3 + i, 5 + i, 5 + i, color)
        _fill_rect(img, 3 + i, 11 - i, 5 + i, 13 - i, color)
    return img


def _icon_question(color="#2f6f8f"):
    img = _icon_blank()
    _fill_rect(img, 5, 3, 11, 5, color)   # top bar
    _fill_rect(img, 9, 5, 11, 7, color)   # stroke down from the right end
    _fill_rect(img, 6, 7, 9, 9, color)    # curl back toward the middle
    _fill_rect(img, 6, 9, 8, 11, color)   # stem
    _fill_rect(img, 6, 12, 8, 14, color)  # dot
    return img


class _ToolTip:
    """Minimal hover tooltip. Toolbar buttons go icon-only to stay compact,
    so this is how their meaning stays discoverable without permanent
    on-screen text next to every one of them."""

    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tip = None
        widget.bind("<Enter>", self._show)
        widget.bind("<Leave>", self._hide)

    def _show(self, event=None):
        if self.tip is not None:
            return
        x = self.widget.winfo_rootx() + 4
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 4
        self.tip = tk.Toplevel(self.widget)
        self.tip.wm_overrideredirect(True)
        self.tip.wm_geometry(f"+{x}+{y}")
        tk.Label(
            self.tip, text=self.text, background="#ffffe0", relief="solid", borderwidth=1,
            padx=4, pady=2, font=("", 9),
        ).pack()

    def _hide(self, event=None):
        if self.tip is not None:
            self.tip.destroy()
            self.tip = None


def _make_hover_popup(parent, x_root, y_root, text):
    """Small floating label at (x_root, y_root); returns None (nothing
    created) for empty text. Shared by What's This? and the recent
    workspace list's path-on-hover tooltip."""
    if not text:
        return None
    tip = tk.Toplevel(parent)
    tip.wm_overrideredirect(True)
    tip.wm_geometry(f"+{x_root}+{y_root}")
    tk.Label(
        tip, text=text, background="#ffffe0", relief="solid", borderwidth=1,
        padx=6, pady=4, font=("", 9), wraplength=320, justify="left",
    ).pack()
    return tip


def _make_drag_ghost(parent, x_root, y_root, color, size=16):
    """Small floating colored dot that follows the cursor during a drag --
    a plain relief/color change on the row or cell being dragged over
    reads as static, not as "something is moving"; a dot that visibly
    tracks the cursor does. No text, just a soft circular marker standing
    in for the thing being dragged (real ghost-drag previews need a live
    widget snapshot, well beyond what a stdlib-only app can do cheaply --
    this is the lightest stand-in that still reads as motion).

    Uses -transparentcolor (Windows only) so just the dot is visible, not
    a hard-edged box around it; falls back to a plain square swatch
    wherever that attribute isn't available."""
    tip = tk.Toplevel(parent)
    tip.wm_overrideredirect(True)
    tip.wm_geometry(f"{size}x{size}+{x_root}+{y_root}")
    matte = "#123456"  # arbitrary -- nothing else on the page uses this exact color
    canvas = tk.Canvas(tip, width=size, height=size, highlightthickness=0, background=matte)
    canvas.pack(fill="both", expand=True)
    try:
        tip.configure(background=matte)
        tip.wm_attributes("-transparentcolor", matte)
    except tk.TclError:
        canvas.configure(background="#f4f4f4")  # no transparency support -- a light square instead of dark
    try:
        tip.wm_attributes("-alpha", 0.85)
    except tk.TclError:
        pass
    canvas.create_oval(1, 1, size - 1, size - 1, fill=color, outline="")
    return tip


def _contrast_text_color(hex_color):
    """Pick black or white text for readable contrast against hex_color."""
    hex_color = hex_color.lstrip("#")
    r, g, b = int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16)
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return "#000000" if luminance > 140 else "#ffffff"


class LaneMappingGrid(ttk.Frame):
    """Direct-manipulation grid for lane_mapping.csv: every cell is
    colored by which controller currently owns it -- a real WYSIWYG view
    of the topology, not a text description of a selection.

    Click a controller swatch in the palette bar to make it the "active
    paint controller", then click-and-drag across a block of cells (one
    or more mode rows x one or more lane columns) to paint them: on every
    drag step the whole dragged block is repainted from a snapshot taken
    at press time, so the color and port numbers update live as the drag
    grows or shrinks, and backtracking un-paints cleanly. Releasing just
    stops tracking -- the paint is already applied. A plain click with no
    movement paints nothing (so it doesn't fight with double-click).
    Double-click a single cell to hand-type its exact value instead.

    ttk.Treeview has no per-cell background of its own (only a per-row
    tag), so this is a plain grid of tk.Label cells inside a scrollable
    canvas rather than a Treeview.
    """

    PALETTE = [
        "#4C78A8", "#F58518", "#54A24B", "#E45756", "#72B7B2",
        "#EECA3B", "#B279A2", "#FF9DA6", "#9D755D", "#17BECF",
        "#B5B02B", "#7B6FD1",
    ]
    UNASSIGNED_BG = "#e6e6e6"
    HEADER_BG = "#d8d8d8"

    def __init__(self, parent, cell_w=6, height=260):
        super().__init__(parent)
        self.lane_count = 0
        self._data = []  # [{"mode": "0", "lane0": "0-0", ...}, ...]
        self._controllers = []  # [{"ctrl_id": .., "ctrl_name": ..}, ...]
        self._color_by_id = {}
        self.active_ctrl_id = None
        self.cell_w = cell_w
        self._max_cols_configured = 0  # highest column index ever weighted, see _rebuild_grid

        self.rowconfigure(1, weight=1)
        self.columnconfigure(0, weight=1)

        # -- palette bar: click a swatch to make it the active paint controller
        palette_bar = ttk.Frame(self)
        palette_bar.grid(row=0, column=0, columnspan=2, sticky="ew", pady=(0, 4))
        ttk.Label(palette_bar, text="Paint controller:").pack(side="left")
        self.palette_inner = ttk.Frame(palette_bar)
        self.palette_inner.pack(side="left", padx=(4, 12))
        self._palette_buttons = {}

        # -- scrollable cell grid (vertical only -- lane count is capped by
        # the GUI's own picker, so columns always re-fit the available
        # width instead of needing horizontal scroll; mode rows are
        # unbounded, so vertical scrolling stays)
        self.canvas = tk.Canvas(self, highlightthickness=0, height=height, background="white")
        vsb = ttk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        self.grid_inner = tk.Frame(self.canvas, background="white")
        self.grid_inner.bind(
            "<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all"))
        )
        self._canvas_window_id = self.canvas.create_window((0, 0), window=self.grid_inner, anchor="nw")
        # Columns are always resized to exactly fill the canvas width, so
        # changing lane count re-aligns them instead of triggering scroll.
        self.canvas.bind("<Configure>", self._on_canvas_configure)
        self.canvas.configure(yscrollcommand=vsb.set)
        self.canvas.grid(row=1, column=0, sticky="nsew")
        vsb.grid(row=1, column=1, sticky="ns")

        self._cell_labels = {}  # (row_idx, lane_idx) -> Label
        self._mode_labels = {}  # row_idx -> Label
        self._label_to_cell = {}  # widget -> ("lane", row_idx, lane_idx) | ("mode", row_idx, None)
        self._editor = None
        self._editor_click_binding = None

        self._drag_active = False
        self._drag_moved = False
        self._drag_anchor = None
        self._drag_current = None
        self._drag_snapshot = None

        self._mode_drag_row = None
        self._mode_drag_target = None
        self._mode_drag_moved = False
        self._mode_drag_tooltip = None

    # -- public data interface (kept close to EditableTable's, so the rest
    # of PlmGui barely has to change) ---------------------------------
    @property
    def col_keys(self):
        return ["mode"] + [f"lane{i}" for i in range(self.lane_count)]

    def get_rows(self):
        return [dict(r) for r in self._data]

    def set_rows(self, rows):
        self._data = [dict(r) for r in rows]
        self._rebuild_grid()

    def set_columns(self, columns, combobox_values=None):
        """columns is [("mode","mode"), ("lane0","lane0"), ...] -- same
        shape PlmGui._mapping_columns() already builds."""
        self.lane_count = max(0, len(columns) - 1)
        self._rebuild_grid()

    def set_controllers(self, rows):
        """Rebuild the palette from the Controllers tab's current rows.
        Call whenever those rows might have changed (config load, or
        switching into this tab)."""
        self._controllers = [r for r in rows if (r.get("ctrl_id", "") or "").strip() != ""]
        self._color_by_id = {
            r["ctrl_id"]: self.PALETTE[i % len(self.PALETTE)] for i, r in enumerate(self._controllers)
        }
        if self.active_ctrl_id not in self._color_by_id:
            self.active_ctrl_id = self._controllers[0]["ctrl_id"] if self._controllers else None
        self._rebuild_palette()
        self._refresh_cell_styles()

    def add_mode_row(self):
        next_mode = len(self._data)
        row = {"mode": str(next_mode)}
        for l in range(self.lane_count):
            row[f"lane{l}"] = "0-0"
        self._data.append(row)
        self._rebuild_grid()

    def remove_last_mode_row(self):
        if self._data:
            self._data.pop()
            self._rebuild_grid()

    def _delete_row(self, row_idx):
        if 0 <= row_idx < len(self._data):
            del self._data[row_idx]
            self._rebuild_grid()

    # -- mode-row drag-to-reorder ------------------------------------------
    # Deliberately NOT live during the drag: reordering needs to
    # destroy/recreate the mode Label widgets, and doing that mid-gesture
    # would kill the implicit mouse grab those widgets' own <B1-Motion>
    # binding relies on to keep receiving events. Instead this just tracks
    # a drop target and highlights it, applying the actual reorder once on
    # release when destroying widgets is safe.
    DRAG_TARGET_BG = "#ffe08a"

    def _on_mode_press(self, row_idx):
        self._mode_drag_row = row_idx
        self._mode_drag_target = row_idx
        self._mode_drag_moved = False

    def _on_mode_motion(self, event):
        if self._mode_drag_row is None:
            return
        # A relief/background change on the target cell is easy to miss
        # mid-drag with the cursor sitting right on top of it -- a swatch
        # that visibly follows the cursor makes "yes, this is doing
        # something" unambiguous, regardless of what's under the cursor
        # right now. Reposition rather than recreate so it doesn't flicker.
        x, y = event.x_root + 12, event.y_root + 12
        if self._mode_drag_tooltip is None:
            self._mode_drag_tooltip = _make_drag_ghost(self, x, y, self.DRAG_TARGET_BG)
        else:
            self._mode_drag_tooltip.wm_geometry(f"+{x}+{y}")
        widget = self.winfo_containing(event.x_root, event.y_root)
        cell = self._label_to_cell.get(widget)
        if cell is None or cell[0] != "mode":
            return
        _, target_idx, _ = cell
        if target_idx == self._mode_drag_target:
            return
        prev_lbl = self._mode_labels.get(self._mode_drag_target)
        if prev_lbl is not None:
            prev_lbl.configure(relief="ridge", background=self.HEADER_BG)
        self._mode_drag_target = target_idx
        self._mode_drag_moved = True
        widget.configure(relief="solid", background=self.DRAG_TARGET_BG)

    def _on_mode_release(self, event):
        if self._mode_drag_tooltip is not None:
            self._mode_drag_tooltip.destroy()
            self._mode_drag_tooltip = None
        if self._mode_drag_row is None:
            return
        target_lbl = self._mode_labels.get(self._mode_drag_target)
        if target_lbl is not None:
            target_lbl.configure(relief="ridge", background=self.HEADER_BG)
        if self._mode_drag_moved and self._mode_drag_target != self._mode_drag_row:
            row = self._data.pop(self._mode_drag_row)
            self._data.insert(self._mode_drag_target, row)
            # Sequential by position, same "always 0,1,2,..." convention as
            # Controllers' ctrl_id -- but only enforced here, right after a
            # drag; a value the user later hand-edits via double-click
            # sticks until the next drag.
            for i, r in enumerate(self._data):
                r["mode"] = str(i)
            self._rebuild_grid()
        self._mode_drag_row = None
        self._mode_drag_target = None
        self._mode_drag_moved = False

    # -- palette --------------------------------------------------------
    def _rebuild_palette(self):
        for w in self.palette_inner.winfo_children():
            w.destroy()
        self._palette_buttons = {}
        for c in self._controllers:
            cid = c["ctrl_id"]
            color = self._color_by_id[cid]
            btn = tk.Button(
                self.palette_inner, text=c.get("ctrl_name", cid) or cid, background=color,
                foreground=_contrast_text_color(color), activebackground=color,
                relief=("sunken" if cid == self.active_ctrl_id else "raised"),
                borderwidth=3, padx=6, command=lambda cid=cid: self._set_active_controller(cid),
            )
            btn.pack(side="left", padx=2)
            self._palette_buttons[cid] = btn

    def _set_active_controller(self, cid):
        self.active_ctrl_id = cid
        for c, btn in self._palette_buttons.items():
            btn.configure(relief=("sunken" if c == cid else "raised"))

    # -- grid construction ------------------------------------------------
    def _rebuild_grid(self):
        for w in self.grid_inner.winfo_children():
            w.destroy()
        self._cell_labels = {}
        self._mode_labels = {}
        self._label_to_cell = {}

        tk.Label(
            self.grid_inner, text="mode", width=self.cell_w, relief="ridge", background=self.HEADER_BG
        ).grid(row=0, column=0, sticky="nsew")
        for l in range(self.lane_count):
            tk.Label(
                self.grid_inner, text=f"L{l}", width=self.cell_w, relief="ridge", background=self.HEADER_BG
            ).grid(row=0, column=l + 1, sticky="nsew")

        for r, row in enumerate(self._data):
            mode_lbl = tk.Label(
                self.grid_inner, width=self.cell_w, relief="ridge", background=self.HEADER_BG
            )
            mode_lbl.grid(row=r + 1, column=0, sticky="nsew")
            mode_lbl.bind("<Double-1>", lambda e, rr=r, lb=mode_lbl: self._edit_mode(rr, lb))
            mode_lbl.bind("<Button-3>", lambda e, rr=r: self._mode_context_menu(e, rr))
            mode_lbl.bind("<ButtonPress-1>", lambda e, rr=r: self._on_mode_press(rr))
            mode_lbl.bind("<B1-Motion>", self._on_mode_motion)
            mode_lbl.bind("<ButtonRelease-1>", self._on_mode_release)
            self._mode_labels[r] = mode_lbl
            self._label_to_cell[mode_lbl] = ("mode", r, None)

            for l in range(self.lane_count):
                lbl = tk.Label(self.grid_inner, width=self.cell_w, relief="solid", borderwidth=1)
                lbl.grid(row=r + 1, column=l + 1, sticky="nsew")
                lbl.bind("<ButtonPress-1>", lambda e, rr=r, ll=l: self._on_press(rr, ll))
                lbl.bind("<B1-Motion>", self._on_motion)
                lbl.bind("<ButtonRelease-1>", lambda e: self._on_release())
                lbl.bind("<Double-1>", lambda e, rr=r, ll=l, lb=lbl: self._edit_lane(rr, ll, lb))
                self._cell_labels[(r, l)] = lbl
                self._label_to_cell[lbl] = ("lane", r, l)

        # Equal weight on every column (mode included) so they share the
        # row evenly instead of bunching up on the left with the rest of
        # the row left blank. Column weight config persists on grid_inner
        # independently of the widgets that occupy it -- destroying and
        # recreating the Labels above doesn't clear it, so shrinking lane
        # count (e.g. 16 -> 4) would otherwise leave the old, now-empty
        # higher-numbered columns still weighted and competing for space,
        # squeezing the visible columns into less than the full width.
        # Reset every column this grid has ever weighted before reapplying.
        self._max_cols_configured = max(self._max_cols_configured, self.lane_count + 1)
        for c in range(self._max_cols_configured):
            self.grid_inner.columnconfigure(c, weight=(1 if c <= self.lane_count else 0))

        self._refresh_cell_styles()
        self._on_canvas_configure()

    def _on_canvas_configure(self, event=None):
        # Force the embedded frame to exactly the canvas width (never
        # wider) so grid's equal-weight columns always divide up the real
        # available space -- no horizontal overflow, so no need to scroll.
        width = event.width if event is not None else self.canvas.winfo_width()
        self.canvas.itemconfigure(self._canvas_window_id, width=width)

    def _refresh_cell_styles(self):
        for (r, l), lbl in self._cell_labels.items():
            val = self._data[r].get(f"lane{l}", "") if r < len(self._data) else ""
            has_dash = "-" in val
            cid = val.split("-", 1)[0] if has_dash else None
            port = val.split("-", 1)[1] if has_dash else val
            color = self._color_by_id.get(cid, self.UNASSIGNED_BG)
            lbl.configure(
                text=port, background=color,
                foreground=_contrast_text_color(color) if cid in self._color_by_id else "#333333",
            )
        for r, lbl in self._mode_labels.items():
            lbl.configure(text=self._data[r].get("mode", "") if r < len(self._data) else "")

    # -- paint-drag ---------------------------------------------------------
    def _on_press(self, r, l):
        self._drag_active = True
        self._drag_moved = False
        self._drag_anchor = (r, l)
        self._drag_current = (r, l)
        self._drag_snapshot = [dict(row) for row in self._data]

    def _on_motion(self, event):
        if not self._drag_active:
            return
        widget = self.winfo_containing(event.x_root, event.y_root)
        cell = self._label_to_cell.get(widget)
        if cell is None or cell[0] != "lane":
            return
        _, r, l = cell
        if (r, l) != self._drag_current:
            self._drag_current = (r, l)
            self._drag_moved = True
            self._paint_current_rect()

    def _on_release(self):
        self._drag_active = False

    def _paint_current_rect(self):
        self._data = [dict(row) for row in self._drag_snapshot]
        r0, l0 = self._drag_anchor
        r1, l1 = self._drag_current
        row_lo, row_hi = sorted((r0, r1))
        lane_lo, lane_hi = sorted((l0, l1))
        if self.active_ctrl_id is not None:
            start_port = 0  # every controller's own lane numbering starts at 0
            for r in range(row_lo, row_hi + 1):
                if r >= len(self._data):
                    continue
                for i, l in enumerate(range(lane_lo, lane_hi + 1)):
                    self._data[r][f"lane{l}"] = f"{self.active_ctrl_id}-{start_port + i}"
        self._refresh_cell_styles()

    # -- manual single-cell edit -------------------------------------------
    def _edit_lane(self, r, l, label):
        self._begin_inline_edit(
            label,
            get=lambda: self._data[r].get(f"lane{l}", ""),
            set_=lambda v: (self._data[r].__setitem__(f"lane{l}", v), self._refresh_cell_styles()),
        )

    def _edit_mode(self, r, label):
        self._begin_inline_edit(
            label,
            get=lambda: self._data[r].get("mode", ""),
            set_=lambda v: (self._data[r].__setitem__("mode", v), self._refresh_cell_styles()),
        )

    def _begin_inline_edit(self, label, get, set_):
        if self._editor is not None:
            self._close_editor()
        entry = tk.Entry(self.grid_inner)
        entry.insert(0, get())
        entry.select_range(0, "end")
        entry.place(
            x=label.winfo_x(), y=label.winfo_y(),
            width=label.winfo_width(), height=label.winfo_height(),
        )
        entry.focus_set()
        self._editor = entry

        def commit(save):
            if self._editor is None:
                return
            val = entry.get()
            self._teardown_editor()
            if save:
                set_(val)

        entry.bind("<Return>", lambda e: commit(True))
        entry.bind("<Escape>", lambda e: commit(False))
        entry.bind("<FocusOut>", lambda e: commit(True))

        def on_click_outside(event):
            # tk.Label cells (unlike Entry/Combobox) don't take keyboard
            # focus on a plain click, so FocusOut alone never fires when
            # clicking one -- watch clicks at the toplevel instead and
            # commit whenever one lands on something other than the editor.
            if event.widget is not entry:
                commit(True)

        toplevel = self.winfo_toplevel()
        self._editor_click_binding = (toplevel, toplevel.bind("<Button-1>", on_click_outside, add="+"))

    def _teardown_editor(self):
        if self._editor is not None:
            self._editor.destroy()
            self._editor = None
        if self._editor_click_binding is not None:
            toplevel, bind_id = self._editor_click_binding
            toplevel.unbind("<Button-1>", bind_id)
            self._editor_click_binding = None

    def _close_editor(self):
        self._teardown_editor()

    # -- row context menu ---------------------------------------------------
    def _mode_context_menu(self, event, row_idx):
        menu = tk.Menu(self, tearoff=0)
        menu.add_command(label="Delete this mode row", command=lambda: self._delete_row(row_idx))
        menu.tk_popup(event.x_root, event.y_root)


# ---------------------------------------------------------------- main app


class PlmGui(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("plmConsultant")
        self.geometry("1180x760")

        self.workspace_root = self._load_last_workspace()  # None until Open/New Workspace
        self._update_title()
        self.log_queue = queue.Queue()

        self._help_texts = {}  # widget -> "What's This?" description
        self._whats_this_active = False
        self._whats_this_last_widget = None
        self._whats_this_popup = None

        self._recent_paths = []  # recent_list row index -> full workspace Path
        self._recent_tooltip = None
        self._recent_tooltip_row = None

        self._build_layout()
        self._refresh_recent_list()
        self._load_workspace_content()
        self.after(100, self._poll_log_queue)

        # Bound once, gated on _whats_this_active, rather than dynamically
        # bound/unbound on enter/exit -- simpler than juggling bind_all's
        # global (and easy to clobber) "all" bindtag.
        self.bind_all("<Motion>", self._on_whats_this_motion, add="+")
        self.bind_all("<Escape>", self._on_whats_this_cancel, add="+")
        self.bind_all("<Button-3>", self._on_whats_this_cancel, add="+")
        self.bind("<F1>", lambda e: self._start_whats_this())

    # ------------------------------------------------------------ workspace
    MAX_RECENT_WORKSPACES = 10

    @staticmethod
    def _read_state_file():
        if not WORKSPACE_STATE_FILE.is_file():
            return {}
        try:
            return json.loads(WORKSPACE_STATE_FILE.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    @staticmethod
    def _write_state_file(data):
        try:
            WORKSPACE_STATE_FILE.write_text(json.dumps(data), encoding="utf-8")
        except OSError:
            pass  # remembering workspace state is a convenience, not required

    @staticmethod
    def _load_last_workspace():
        raw = PlmGui._read_state_file().get("workspace")
        if not raw:
            return None
        path = Path(raw)
        return path if path.is_dir() else None

    @staticmethod
    def _save_last_workspace(path):
        data = PlmGui._read_state_file()
        data["workspace"] = str(path)
        PlmGui._write_state_file(data)

    @staticmethod
    def _load_recent_workspaces():
        """Most-recently-used first, silently dropping any path that no
        longer exists (deleted or moved since it was last opened)."""
        raw = PlmGui._read_state_file().get("recent", [])
        return [p for p in (Path(r) for r in raw) if p.is_dir()]

    @staticmethod
    def _add_recent_workspace(path):
        """Automatic history, unlike Remember Workspace's explicit pin --
        every switch (Open/New/Save As) updates this, the same way a
        browser's or editor's "recent" list updates just from visiting."""
        data = PlmGui._read_state_file()
        path_str = str(path)
        recent = [p for p in data.get("recent", []) if p != path_str]
        recent.insert(0, path_str)
        data["recent"] = recent[: PlmGui.MAX_RECENT_WORKSPACES]
        PlmGui._write_state_file(data)

    def _workspace_status_text(self):
        return f"Workspace: {self.workspace_root}" if self.workspace_root else \
            "Workspace: (none open -- File > Open/New Workspace)"

    def _workspace_title_text(self):
        return f"Workspace: {self.workspace_root.name}" if self.workspace_root else "(no workspace open)"

    def _update_title(self):
        self.title(f"plmConsultant - {self.workspace_root.name}" if self.workspace_root else "plmConsultant")

    def _valid_name(self, name):
        name = (name or "").strip()
        if not name or any(c in name for c in ' /\\:*?"<>|'):
            messagebox.showerror("Invalid name", "Use a plain folder name, no spaces or path characters.")
            return None
        return name

    def _set_workspace(self, path, load=True):
        previous_root = self.workspace_root
        self.workspace_root = Path(path)
        if load and not self._load_workspace_content():
            # Load failed (bad/corrupt CSVs, already reported via its own
            # "Load failed" dialog) -- roll back to the previous workspace
            # rather than leaving workspace_root pointed at one whose
            # content was never actually loaded into the tables (they
            # still hold whatever the previous workspace had). Otherwise
            # the next Save/Validate -- both write the tables out first --
            # would silently write that stale content into the new,
            # broken workspace's files.
            self.workspace_root = previous_root
            return
        self.workspace_var.set(self._workspace_status_text())
        self.set_label.configure(text=self._workspace_title_text())
        self._update_title()
        self._add_recent_workspace(self.workspace_root)
        self._refresh_recent_list()
        self._log(f"Workspace set to {self.workspace_root}\n")

    def _refresh_recent_list(self):
        self.recent_list.delete(0, "end")
        self._recent_tooltip_row = None  # rows shifted -- any hover-tracked index is now stale
        self._recent_paths = self._load_recent_workspaces()
        for p in self._recent_paths:
            # Full paths get too long to read in a narrow sidebar -- show
            # just the folder name, full path is a hover away (see
            # _on_recent_hover) since names alone can collide across
            # different parent directories.
            self.recent_list.insert("end", p.name)

    def _on_recent_hover(self, event):
        idx = self.recent_list.nearest(event.y)
        bbox = self.recent_list.bbox(idx)
        if bbox is None or not (bbox[1] <= event.y <= bbox[1] + bbox[3]):
            idx = None
        if idx == self._recent_tooltip_row:
            return
        self._recent_tooltip_row = idx
        if self._recent_tooltip is not None:
            self._recent_tooltip.destroy()
            self._recent_tooltip = None
        if idx is not None and 0 <= idx < len(self._recent_paths):
            self._recent_tooltip = _make_hover_popup(
                self.recent_list, event.x_root + 12, event.y_root + 12, str(self._recent_paths[idx])
            )

    def _hide_recent_tooltip(self, event=None):
        if self._recent_tooltip is not None:
            self._recent_tooltip.destroy()
            self._recent_tooltip = None
        self._recent_tooltip_row = None

    def _open_recent_workspace(self, event=None):
        sel = self.recent_list.curselection()
        if not sel:
            return
        self._set_workspace(self._recent_paths[sel[0]])

    def _remember_workspace(self):
        """Pin the current workspace as the one to auto-open next run.
        Unrelated to Save Workspace (which writes config/*.csv to disk) --
        this only records a path in WORKSPACE_STATE_FILE, and only when
        explicitly asked: nothing here auto-persists just from switching."""
        if self.workspace_root is None:
            messagebox.showwarning("No workspace", "Open or create a workspace first.")
            return
        self._save_last_workspace(self.workspace_root)
        self._log(f"'{self.workspace_root}' will auto-open the next time plmConsultant starts.\n")

    def _open_workspace(self):
        chosen = filedialog.askdirectory(
            title="Open workspace",
            initialdir=str(self.workspace_root) if self.workspace_root else str(CONFIGS_ROOT),
            mustexist=True,
        )
        if chosen:
            self._set_workspace(chosen)

    def _new_workspace(self):
        parent = filedialog.askdirectory(
            title="Choose a parent directory for the new workspace",
            initialdir=str(self.workspace_root) if self.workspace_root else str(CONFIGS_ROOT),
            mustexist=True,
        )
        if not parent:
            return
        name = simpledialog.askstring("New workspace", "Workspace folder name:", parent=self)
        if not name:
            return
        name = self._valid_name(name)
        if not name:
            return
        ws_dir = Path(parent) / name
        if ws_dir.exists():
            messagebox.showerror("Already exists", f"{ws_dir} already exists.")
            return
        ws_dir.mkdir(parents=True)
        self._set_workspace(ws_dir, load=False)
        self._scaffold_default_content()
        self._log(f"Created new (unsaved) workspace skeleton at '{ws_dir}'. Edit the tabs, then "
                   f"click Save Workspace.\n")

    def _delete_workspace(self):
        if self.workspace_root is None:
            messagebox.showwarning("No workspace", "Open or create a workspace first.")
            return
        ws = self.workspace_root
        if not messagebox.askyesno(
            "Delete workspace", f"Permanently delete '{ws}' and everything under it "
            f"(config, generated rtl/tb)? This cannot be undone."
        ):
            return
        shutil.rmtree(ws)
        self.workspace_root = None
        self.workspace_var.set(self._workspace_status_text())
        self.set_label.configure(text=self._workspace_title_text())
        self._update_title()
        self._clear_tabs()
        self._log(f"Deleted workspace {ws}.\n")

    def _save_workspace_as(self):
        if self.workspace_root is None:
            messagebox.showwarning("No workspace", "Open or create a workspace first.")
            return
        parent = filedialog.askdirectory(
            title="Choose a parent directory for the copy",
            initialdir=str(self.workspace_root.parent), mustexist=True,
        )
        if not parent:
            return
        name = simpledialog.askstring("Save Workspace As", "New workspace folder name:", parent=self)
        if not name:
            return
        name = self._valid_name(name)
        if not name:
            return
        new_dir = Path(parent) / name
        if new_dir.exists():
            messagebox.showerror("Already exists", f"{new_dir} already exists.")
            return
        cfg_dir = new_dir / "config"
        cfg_dir.mkdir(parents=True)
        try:
            self._write_config_files(cfg_dir)
        except Exception as e:  # noqa: BLE001
            messagebox.showerror("Save Workspace As failed", str(e))
            return
        self._set_workspace(new_dir, load=False)  # already have the content in memory
        self._log(f"Saved a copy of the workspace as {new_dir}\n")

    # ------------------------------------------------------------ menu / toolbar / status bar
    def _build_menu(self):
        menubar = tk.Menu(self, tearoff=0)
        self.config(menu=menubar)

        file_menu = tk.Menu(menubar, tearoff=0)
        file_menu.add_command(label="Open Workspace...", command=self._open_workspace)
        file_menu.add_command(label="New Workspace...", command=self._new_workspace)
        file_menu.add_command(label="Save Workspace As...", command=self._save_workspace_as)
        file_menu.add_command(label="Delete Workspace", command=self._delete_workspace)
        file_menu.add_separator()
        file_menu.add_command(label="Save Workspace", command=self._save_all)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self._on_exit)
        menubar.add_cascade(label="File", menu=file_menu)

        help_menu = tk.Menu(menubar, tearoff=0)
        help_menu.add_command(label="What's This?  (F1)", command=self._start_whats_this)
        help_menu.add_separator()
        help_menu.add_command(label="About", command=self._show_about)
        help_menu.add_command(label="Documentation", command=self._open_docs)
        menubar.add_cascade(label="Help", menu=help_menu)

    def _build_toolbar(self):
        toolbar = ttk.Frame(self, padding=(6, 4))
        toolbar.pack(fill="x", side="top")
        # Keep references -- Tk drops a PhotoImage as soon as nothing holds
        # onto it, which would blank every icon out from under the buttons.
        self._toolbar_icons = []
        self._toolbar_button(toolbar, _icon_plus, "Create Workspace...", self._new_workspace)
        self._toolbar_button(toolbar, _icon_folder, "Open Workspace...", self._open_workspace)
        self._toolbar_button(
            toolbar, _icon_pin, "Remember Workspace (auto-open next launch)", self._remember_workspace
        )
        self._toolbar_button(toolbar, _icon_refresh, "Refresh Workspace", self._load_workspace_content)
        ttk.Separator(toolbar, orient="vertical").pack(side="left", fill="y", padx=8)
        self._toolbar_button(toolbar, _icon_check, "Validate", self._validate)
        ttk.Separator(toolbar, orient="vertical").pack(side="left", fill="y", padx=8)
        self._toolbar_button(toolbar, _icon_chip, "Generate RTL", self._gen_rtl)
        self._toolbar_button(toolbar, _icon_flask, "Generate TB", self._gen_tb)
        self._toolbar_button(toolbar, _icon_run_all, "Generate All", self._gen_all)
        ttk.Separator(toolbar, orient="vertical").pack(side="left", fill="y", padx=8)
        self._toolbar_button(toolbar, _icon_question, "What's This?  (F1)", self._start_whats_this)
        ttk.Separator(self, orient="horizontal").pack(fill="x", side="top")

    def _toolbar_button(self, parent, icon_fn, tooltip, command):
        img = icon_fn()
        self._toolbar_icons.append(img)
        btn = ttk.Button(parent, image=img, command=command)
        btn.pack(side="left", padx=(2, 0))
        _ToolTip(btn, tooltip)
        self._register_help(btn, tooltip)
        return btn

    def _build_status_bar(self):
        # Packed side="bottom" before root's fill="both"/expand=True is
        # created below, so it reserves its slice of the window instead of
        # being crowded out -- pack() allocates space in call order.
        status = ttk.Frame(self, padding=(6, 2))
        status.pack(fill="x", side="bottom")
        self.workspace_var = tk.StringVar(value=self._workspace_status_text())
        ttk.Label(status, textvariable=self.workspace_var).pack(anchor="w")
        ttk.Separator(self, orient="horizontal").pack(fill="x", side="bottom")

    def _on_exit(self):
        self.destroy()

    def _show_about(self):
        messagebox.showinfo(
            "About plmConsultant",
            "plmConsultant\n\n"
            "Config editor and RTL/TB generator front end for the PIPE Lane "
            "Mapper (plm) generator.\n\n"
            "A thin wrapper over tool/plm_gen_rtl.py, tool/plm_gen_tb.py and "
            "plm_config.py -- no generation or validation logic is duplicated here.",
        )

    def _open_docs(self):
        doc_path = PLM_ROOT / "docs" / "tool_usage.md"
        if doc_path.is_file():
            webbrowser.open(doc_path.resolve().as_uri())
        else:
            messagebox.showinfo("Documentation", f"Documentation file not found:\n{doc_path}")

    # ------------------------------------------------------------ what's this?
    def _register_help(self, widget, text):
        """Attach a "What's This?" description to widget. Doesn't touch its
        normal bindings -- lookup happens by hit-testing under the cursor
        while What's This mode is active, not via a binding on the widget
        itself, so this never interferes with the widget's real behavior."""
        self._help_texts[widget] = text

    def _start_whats_this(self):
        self._whats_this_active = True
        self.config(cursor="question_arrow")
        self._log("What's This? -- hover any control to see what it does. Esc or right-click to exit.\n")

    def _on_whats_this_cancel(self, event=None):
        if self._whats_this_active:
            self._whats_this_active = False
            self.config(cursor="")
            self._hide_whats_this_popup()

    def _on_whats_this_motion(self, event):
        if not self._whats_this_active:
            return
        widget = self.winfo_containing(event.x_root, event.y_root)
        if widget is self._whats_this_last_widget:
            return
        self._whats_this_last_widget = widget
        self._show_whats_this_popup(event.x_root, event.y_root, self._help_texts.get(widget))

    def _show_whats_this_popup(self, x_root, y_root, text):
        self._hide_whats_this_popup()
        self._whats_this_popup = _make_hover_popup(self, x_root + 14, y_root + 14, text)

    def _hide_whats_this_popup(self):
        if self._whats_this_popup is not None:
            self._whats_this_popup.destroy()
            self._whats_this_popup = None

    # ------------------------------------------------------------ layout
    def _build_layout(self):
        self._build_menu()
        self._build_toolbar()
        self._build_status_bar()

        # Outer split is vertical: [Activity | editor] on top, console
        # spanning the FULL window width underneath -- Activity is only as
        # tall as the editor beside it, not the whole window, so it stops
        # leaving room for the console instead of running the console's
        # full height down past it.
        main_pane = ttk.Panedwindow(self, orient="vertical")
        main_pane.pack(fill="both", expand=True)

        top_pane = ttk.Panedwindow(main_pane, orient="horizontal")
        main_pane.add(top_pane, weight=3)

        # -- left: Activity nav + Recent (recently opened workspaces),
        # switched by two plain toggle buttons pinned to the bottom of this
        # panel (i.e. right above the console). A ttk.Notebook could do
        # this too, but its "south" tab strip renders oddly in some themes
        # for a 2-item switcher this small -- plain buttons give exact
        # control over position and left/right order instead. A workspace
        # holds exactly one config, so there's no set-picker to browse here
        # -- switching between configs means switching workspaces (File
        # menu / toolbar), not selecting from a list; Recent is just a
        # shortcut back to recently opened ones.
        left = ttk.Frame(top_pane, padding=6)
        top_pane.add(left, weight=1)

        self._sidebar_pages = {}  # name -> frame, for the toggle switcher below
        sidebar_content = ttk.Frame(left)
        sidebar_content.pack(fill="both", expand=True)

        activity_tab = ttk.Frame(sidebar_content)
        self._sidebar_pages["Activity"] = activity_tab
        self.activity_list = tk.Listbox(activity_tab, exportselection=False)
        for item in ACTIVITY_ITEMS:
            self.activity_list.insert("end", item)
        self.activity_list.selection_set(0)
        self.activity_list.bind("<<ListboxSelect>>", self._on_activity_select)
        self.activity_list.pack(fill="both", expand=True)
        self._register_help(self.activity_list, "Pick which section to edit: Controllers, Lane "
                             "Mapping, Pipe Signals, or Generation Flags.")

        recent_tab = ttk.Frame(sidebar_content)
        self._sidebar_pages["Recent"] = recent_tab
        self.recent_list = tk.Listbox(recent_tab, exportselection=False)
        self.recent_list.pack(fill="both", expand=True)
        self.recent_list.bind("<Double-1>", self._open_recent_workspace)
        self.recent_list.bind("<Motion>", self._on_recent_hover)
        self.recent_list.bind("<Leave>", self._hide_recent_tooltip)
        self._register_help(self.recent_list, "Recently opened workspaces (hover an entry for its "
                             "full path) -- double-click one to switch to it.")

        for page in self._sidebar_pages.values():
            page.place(in_=sidebar_content, x=0, y=0, relwidth=1, relheight=1)

        switcher = ttk.Frame(left)
        switcher.pack(fill="x", side="bottom", pady=(4, 0))
        self._sidebar_buttons = {}
        for name in ("Recent", "Activity"):  # left-to-right order
            # Plain tk.Button, not ttk -- same reason as LaneMappingGrid's
            # palette swatches: ttk widgets are theme-styled and won't take
            # a direct relief override to show which page is active.
            btn = tk.Button(switcher, text=name, relief="raised", borderwidth=2,
                             command=lambda n=name: self._show_sidebar_page(n))
            btn.pack(side="left", fill="x", expand=True)
            self._sidebar_buttons[name] = btn
        self._show_sidebar_page("Activity")

        editor_frame = ttk.Frame(top_pane, padding=6)
        top_pane.add(editor_frame, weight=4)

        self.set_label = ttk.Label(editor_frame, text=self._workspace_title_text(), font=("", 11, "bold"))
        self.set_label.pack(anchor="w")

        # The Activity list on the left is the only navigation for the
        # editor's own sections now -- hide the editor notebook's own tab
        # strip rather than showing two redundant ways to switch sections.
        ttk.Style(self).layout("TNotebook.Tab", [])

        self.nb = ttk.Notebook(editor_frame)
        self.nb.pack(fill="both", expand=True, pady=(4, 0))

        self._build_controllers_tab()
        self._build_lane_mapping_tab()
        self._build_signals_tab()
        self._build_genflags_tab()
        self.nb.bind("<<NotebookTabChanged>>", self._on_tab_changed)

        # -- console: full window width, below both Activity and the editor
        console_frame = ttk.Frame(main_pane, padding=(0, 4, 0, 0))
        main_pane.add(console_frame, weight=2)
        self.console = tk.Text(
            console_frame, height=12, background="#ffffff", foreground="#1a1a1a",
            insertbackground="#1a1a1a", font=("Consolas", 9), state="disabled", wrap="word",
        )
        cvsb = ttk.Scrollbar(console_frame, orient="vertical", command=self.console.yview)
        self.console.configure(yscrollcommand=cvsb.set)
        self.console.pack(side="left", fill="both", expand=True)
        cvsb.pack(side="right", fill="y")
        self._register_help(self.console, "Shows what each action (Validate, Generate RTL/TB/All, "
                             "workspace operations) reported, with a timestamp per line.")

    def _on_activity_select(self, event=None):
        sel = self.activity_list.curselection()
        if sel:
            self.nb.select(sel[0])

    def _show_sidebar_page(self, name):
        self._sidebar_pages[name].lift()
        for n, btn in self._sidebar_buttons.items():
            btn.configure(relief=("sunken" if n == name else "raised"))

    def _build_controllers_tab(self):
        tab = ttk.Frame(self.nb, padding=6)
        self.nb.add(tab, text="Controllers")
        ttk.Label(
            tab,
            text="ctrl_id: auto-numbered by row order (0, 1, 2, ...) -- drag a row to reorder.  "
            "ctrl_name: signal-name prefix (lowercased).  max_width: this controller's real max "
            "lane count.",
        ).pack(anchor="w", pady=(0, 4))
        self.controllers_table = EditableTable(
            tab,
            columns=[("ctrl_id", "ctrl_id"), ("ctrl_name", "ctrl_name"), ("max_width", "max_width")],
            col_width=140,
            id_column="ctrl_id",
            add_label="ctrl+",
            delete_label="ctrl-",
        )
        self.controllers_table.pack(fill="both", expand=True)
        self._register_help(self.controllers_table.tree, "One row per PIPE/PCIe controller. "
                             "ctrl_id is auto-numbered by row position -- drag a row to reorder. "
                             "ctrl_name is used as the generated RTL signal-name prefix; max_width "
                             "is its real max lane count.")

    def _build_lane_mapping_tab(self):
        tab = ttk.Frame(self.nb, padding=6)
        self.nb.add(tab, text="Lane Mapping")
        top = ttk.Frame(tab)
        top.pack(fill="x", pady=(0, 4))
        ttk.Label(top, text="Number of lanes:").pack(side="left")
        self.lane_count_var = tk.StringVar(value="4")
        self.lane_count_combo = ttk.Combobox(
            top, textvariable=self.lane_count_var, values=LANE_COUNTS, state="readonly", width=6
        )
        self.lane_count_combo.pack(side="left", padx=(4, 4))
        self.lane_count_combo.bind("<<ComboboxSelected>>", lambda e: self._apply_lane_count())
        self._register_help(self.lane_count_combo, "Total PHY lane count for this workspace. "
                             "Restricted to power-of-2 values here for usability -- the underlying "
                             "generator actually supports any width.")
        mode_plus = ttk.Button(top, text="Mode +", command=self._add_mode_row)
        mode_plus.pack(side="left", padx=(12, 0))
        self._register_help(mode_plus, "Add a mode row. Each mode is one complete assignment of "
                             "every PHY lane to some controller -- e.g. one bifurcation option.")
        mode_minus = ttk.Button(top, text="Mode -", command=self._remove_mode_row)
        mode_minus.pack(side="left", padx=(4, 0))
        self._register_help(mode_minus, "Remove the last mode row.")
        ttk.Label(
            tab, text="Click a controller swatch below to make it the active paint controller, "
            "then click-and-drag across lane cells (one or more modes x one or more lanes) to "
            "paint them that color -- colors and port numbers update live as you drag. "
            "Drag a mode cell up/down to reorder that mode (renumbers 0, 1, 2, ... after the "
            "drop); right-click one to delete it; double-click any single cell to type its exact "
            "ctrl_id-ctrl_lane value instead.",
            wraplength=880, justify="left",
        ).pack(anchor="w", pady=(0, 4))
        self.mapping_table = LaneMappingGrid(tab)
        self.mapping_table.pack(fill="both", expand=True)
        self._register_help(self.mapping_table.canvas, "Click a controller swatch, then drag "
                             "across lane cells to paint them that controller's color. Right-click "
                             "a mode cell for row options; double-click any cell to type its exact "
                             "value.")

    def _set_lane_count_display(self, n):
        """Update the lane-count combobox to show n. The GUI restricts new
        choices to power-of-2 values (LANE_COUNTS), but a config set loaded
        from disk may legitimately have an arbitrary lane count -- plm
        itself supports any width, only the GUI's own picker is narrowed
        for usability -- so a value outside LANE_COUNTS is appended just so
        it can be displayed, not offered as a normal choice going forward."""
        values = list(LANE_COUNTS)
        if str(n) not in values:
            values.append(str(n))
        self.lane_count_combo.configure(values=values)
        self.lane_count_var.set(str(n))

    def _mapping_columns(self, lane_count):
        cols = [("mode", "mode")]
        for l in range(lane_count):
            cols.append((f"lane{l}", f"lane{l}"))
        return cols

    def _apply_lane_count(self):
        try:
            n = int(self.lane_count_var.get())
            if n < 1:
                raise ValueError
        except ValueError:
            messagebox.showerror("Invalid lane count", "Lane count must be a positive integer.")
            return
        self.mapping_table.set_columns(self._mapping_columns(n))

    def _add_mode_row(self):
        self.mapping_table.add_mode_row()

    def _remove_mode_row(self):
        self.mapping_table.remove_last_mode_row()

    def _on_tab_changed(self, event=None):
        if self.nb.tab(self.nb.select(), "text") == "Lane Mapping":
            self.mapping_table.set_controllers(self.controllers_table.get_rows())

    def _build_signals_tab(self):
        tab = ttk.Frame(self.nb, padding=6)
        self.nb.add(tab, text="Pipe Signals")
        ttk.Label(
            tab,
            text="signal_type: perlane (default -- independent per lane) or shared (one value "
            "across a controller's own lanes).  direction: mac2phy or phy2mac.  safe_state / "
            "tie_off: integer literal (0, 1, 0x50, ...) or 'lane0' for tie_off.",
            wraplength=880, justify="left",
        ).pack(anchor="w", pady=(0, 4))
        self.signals_table = EditableTable(
            tab,
            columns=[
                ("signal_name", "signal_name"),
                ("signal_type", "signal_type"),
                ("direction", "direction"),
                ("width", "width"),
                ("safe_state", "safe_state"),
                ("tie_off", "tie_off"),
            ],
            combobox_values={"signal_type": SIGNAL_TYPES, "direction": DIRECTIONS},
            col_width=130,
            height=22,  # PIPE's own signal set runs to ~35 signals -- default height=8 forced constant scrolling
        )
        self.signals_table.pack(fill="both", expand=True)
        self._register_help(self.signals_table.tree, "The PIPE-level pin list: each row is one "
                             "signal's direction, width, safe/idle state, and tie-off value.")
        btn_row = ttk.Frame(tab)
        btn_row.pack(fill="x", pady=(4, 0))
        ttk.Button(
            btn_row, text="Load default PIPE signal set...", command=self._load_default_signals
        ).pack(side="left")

    def _build_genflags_tab(self):
        tab = ttk.Frame(self.nb, padding=6)
        self.nb.add(tab, text="Generation Flags")
        ttk.Label(
            tab,
            text="Optional per-config-set defaults, written to config/gen_flags.txt. Both "
            "generators read this file automatically; an explicit command-line flag still "
            "overrides it. Leave a dropdown on its (default: ...) entry to omit that key.",
            wraplength=760,
            justify="left",
        ).pack(anchor="w", pady=(0, 8))

        row1 = ttk.Frame(tab)
        row1.pack(anchor="w", pady=2)
        ttk.Label(row1, text="pclk-mode:", width=14).pack(side="left")
        self.pclk_mode_var = tk.StringVar(value=PCLK_MODES[0])
        pclk_combo = ttk.Combobox(
            row1, textvariable=self.pclk_mode_var, values=PCLK_MODES, state="readonly", width=28
        )
        pclk_combo.pack(side="left")
        self._register_help(pclk_combo, "Which clock domain the PHY-facing pclk output comes "
                             "from: pclk_as_phy_output (PHY drives it), or pclk_as_phy_input "
                             "(each controller supplies its own).")

        row2 = ttk.Frame(tab)
        row2.pack(anchor="w", pady=2)
        ttk.Label(row2, text="sel-mode:", width=14).pack(side="left")
        self.sel_mode_var = tk.StringVar(value=SEL_MODES[0])
        sel_combo = ttk.Combobox(
            row2, textvariable=self.sel_mode_var, values=SEL_MODES, state="readonly", width=28
        )
        sel_combo.pack(side="left")
        self._register_help(sel_combo, "Whether the mode-select decode is registered (sync) or "
                             "combinational (comb) in the generated RTL.")

        row_dpr = ttk.Frame(tab)
        row_dpr.pack(anchor="w", pady=2)
        self.dpr_var = tk.BooleanVar(value=False)
        dpr_check = ttk.Checkbutton(row_dpr, text="dpr", variable=self.dpr_var)
        dpr_check.pack(side="left")
        self._register_help(
            dpr_check,
            "Generate the DPR (diagnostic probe) overlay: a virtual controller with link "
            "width NL, connected 1:1 to every PHY lane. A live v_lane_mask input lets it "
            "override any lane's data/reset/clock at runtime, independent of mode -- for "
            "probing which PHY tx/rx connections are actually present. Adds new top-level "
            "ports (v_lane_mask, dpr_rst_n, dpr_mac2phy, dpr_phy2mac, dpr_pclk, ...) to the "
            "generated RTL and testbench. Off by default.",
        )

        row3 = ttk.Frame(tab)
        row3.pack(anchor="w", pady=(10, 2))
        ttk.Label(row3, text="verible-path:", width=14).pack(side="left")
        self.verible_path_var = tk.StringVar(value="")
        verible_entry = ttk.Entry(row3, textvariable=self.verible_path_var, width=44)
        verible_entry.pack(side="left")
        self._register_help(verible_entry, "Path to verible-verilog-format, used to auto-format "
                             "generated RTL/TB. Auto-detected from PATH if found; clear this field "
                             "to go back to auto-detection.")
        ttk.Button(row3, text="Browse...", command=self._browse_verible_path).pack(side="left", padx=(4, 0))
        ttk.Label(
            tab, text="Auto-filled from whatever verible-verilog-format is found on PATH, if any -- "
            "override here or via Browse... to pin a specific binary for this workspace, or clear "
            "the field to fall back to auto-detection again.",
            wraplength=760, justify="left",
        ).pack(anchor="w", pady=(2, 0))

    def _browse_verible_path(self):
        path = filedialog.askopenfilename(
            title="Select verible-verilog-format binary",
            filetypes=[("Executable", "*.exe"), ("All files", "*.*")],
        )
        if path:
            self.verible_path_var.set(path)

    def _default_verible_path(self, explicit=""):
        """explicit (e.g. from gen_flags.txt) always wins; otherwise fall
        back to whatever find_verible() locates on PATH, if anything."""
        return explicit or find_verible() or ""

    # ------------------------------------------------------------ workspace content
    def _clear_tabs(self):
        """Blank the tabs out -- used when no workspace is open (e.g. right
        after Delete Workspace)."""
        self.controllers_table.set_rows([])
        self.mapping_table.set_columns(self._mapping_columns(4))
        self.mapping_table.set_rows([])
        self.mapping_table.set_controllers([])
        self._set_lane_count_display(4)
        self.signals_table.set_rows([])
        self.pclk_mode_var.set(PCLK_MODES[0])
        self.sel_mode_var.set(SEL_MODES[0])
        self.dpr_var.set(False)
        self.verible_path_var.set(self._default_verible_path())

    def _scaffold_default_content(self):
        """Seed sensible starting content for a brand-new, empty workspace."""
        self.controllers_table.set_rows([{"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "4"}])
        self.mapping_table.set_columns(self._mapping_columns(4))
        self.mapping_table.set_rows([{"mode": "0", "lane0": "0-0", "lane1": "0-1", "lane2": "0-2", "lane3": "0-3"}])
        self.mapping_table.set_controllers(self.controllers_table.get_rows())
        self._set_lane_count_display(4)
        self._load_default_signals(silent=True)
        self.pclk_mode_var.set(PCLK_MODES[0])
        self.sel_mode_var.set(SEL_MODES[0])
        self.dpr_var.set(False)
        self.verible_path_var.set(self._default_verible_path())

    def _load_workspace_content(self):
        """(Re)load config/*.csv + gen_flags.txt from the current workspace
        into the tabs, discarding any unsaved in-memory edits. Also used as
        "Refresh Workspace" to pick up changes made outside the GUI.

        Returns True on success -- including the legitimate "no config here
        yet" case for a brand-new workspace -- and False only when CSVs
        exist but failed to parse (already reported via its own "Load
        failed" dialog), so _set_workspace() can tell a real load failure
        apart from a normal empty workspace and roll back instead of
        switching to a workspace whose content was never actually loaded.
        """
        if self.workspace_root is None:
            return True
        cfg_dir = self.workspace_root / "config"
        if not has_csvs(cfg_dir):
            self._clear_tabs()
            self._log(f"No config found under {cfg_dir} yet -- fill in the tabs and Save Workspace.\n")
            return True
        try:
            ctrls = self._read_csv(cfg_dir / "controllers.csv", ("ctrl_id", "ctrl_name", "max_width"))
            sigs = self._read_csv(
                cfg_dir / "pipe_signals.csv",
                ("signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"),
            )
            mapping_rows, lane_count = self._read_mapping_csv(cfg_dir / "lane_mapping.csv")
        except Exception as e:  # noqa: BLE001 -- surface any parse issue to the user, not just SystemExit
            messagebox.showerror("Load failed", f"Could not load {cfg_dir}:\n{e}")
            return False

        self.controllers_table.set_rows(ctrls)
        self.signals_table.set_rows(sigs)
        self._set_lane_count_display(lane_count)
        self.mapping_table.set_columns(self._mapping_columns(lane_count))
        self.mapping_table.set_rows(mapping_rows)
        self.mapping_table.set_controllers(self.controllers_table.get_rows())

        flags = self._read_gen_flags(cfg_dir / "gen_flags.txt")
        self.pclk_mode_var.set(flags.get("pclk-mode", PCLK_MODES[0]))
        self.sel_mode_var.set(flags.get("sel-mode", SEL_MODES[0]))
        self.dpr_var.set(flags.get("dpr", False))
        self.verible_path_var.set(self._default_verible_path(flags.get("verible-path", "")))
        self._log(f"Loaded {cfg_dir}.\n")
        return True

    # ------------------------------------------------------------ file IO helpers
    @staticmethod
    def _existing_line_ending(path):
        """Detect the line ending already used by path, so writing back to
        it doesn't silently rewrite every single line just from an
        untouched load-then-save round trip. Falls back to plain "\\n" for
        a file that doesn't exist yet -- these configs are meant to be
        Linux-readable regardless of which OS the GUI itself runs on, so a
        brand-new file shouldn't default to the local OS's convention
        (os.linesep is CRLF on Windows)."""
        path = Path(path)
        if path.is_file():
            with open(path, "rb") as f:
                head = f.read(65536)
            if b"\r\n" in head:
                return "\r\n"
            if b"\n" in head:
                return "\n"
        return "\n"

    @staticmethod
    def _read_csv(path, required_cols=None):
        """required_cols, if given, is checked against the file's actual
        header before any row is accepted -- a header that's missing,
        blank (e.g. a stray leading blank line pushes csv.DictReader's
        real header down into a bogus "extra" data row, per Python's own
        documented restkey behavior), or just doesn't match must be
        treated as a load failure, not silently accepted as "0 useful
        columns, every field defaults to blank": the latter is how a
        garbled file on disk turns into a table full of blank rows that
        then look empty in the GUI with no error shown at all -- and the
        very next Save/Validate (which always writes the tables back out
        first) overwrites the original file with those blanks, destroying
        whatever was actually in it.

        Header and values are both whitespace-stripped (same _stripped()
        plm_config.py already uses for the real CLI tools) -- a
        comma-aligned CSV padded with spaces for readability is a
        legitimate, common style, not a malformed file, so it must parse
        identically to an unpadded one rather than failing the
        required_cols check on "signal_type" != "  signal_type".
        """
        if not path.is_file():
            return []
        with open(path, newline="", encoding="utf-8") as f:
            rd = csv.DictReader(f)
            rd.fieldnames = [c.strip() if c else c for c in (rd.fieldnames or [])]
            if required_cols and not set(required_cols) <= set(rd.fieldnames):
                missing = sorted(set(required_cols) - set(rd.fieldnames))
                raise ValueError(
                    f"{path}: header is missing {', '.join(missing)} "
                    f"(found: {', '.join(rd.fieldnames) or '(no header)'})"
                )
            return [dict(r) for r in _stripped(rd)]

    @staticmethod
    def _read_mapping_csv(path):
        if not path.is_file():
            return [], 4
        with open(path, newline="", encoding="utf-8") as f:
            rd = csv.DictReader(f)
            fieldnames = [c.strip() if c else c for c in (rd.fieldnames or [])]
            rd.fieldnames = fieldnames
            if "mode" not in fieldnames:
                raise ValueError(
                    f"{path}: header is missing 'mode' "
                    f"(found: {', '.join(fieldnames) or '(no header)'})"
                )
            lane_cols = [c for c in fieldnames if c != "mode"]
            rows = [dict(r) for r in _stripped(rd)]
        return rows, max(1, len(lane_cols))

    @staticmethod
    def _read_gen_flags(path):
        flags = {}
        if not path.is_file():
            return flags
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line or "=" not in line:
                continue
            k, _, v = line.partition("=")
            flags[k.strip()] = v.strip()
        # Old gen_flags.txt files may still have pclk-mode's pre-rename value
        # on disk (phy-output/phy-input-max-pclk) -- migrate it before the
        # comparison below, so an old config set keeps loading correctly.
        raw_pclk_mode = flags.get("pclk-mode", "")
        pclk_mode_val = _PCLK_MODE_MIGRATION.get(raw_pclk_mode, raw_pclk_mode)
        return {
            "pclk-mode": pclk_mode_val if pclk_mode_val in ("pclk_as_phy_output", "pclk_as_phy_input")
            else PCLK_MODES[0],
            "sel-mode": "comb" if flags.get("sel-mode") == "comb"
            else ("sync" if flags.get("sel-mode") == "sync" else SEL_MODES[0]),
            # Same boolean parsing as plm_common.apply_set_flags(), so the
            # GUI and the CLI tools agree on what counts as "true" in this file.
            "dpr": flags.get("dpr", "").strip().lower() in ("1", "true", "yes", "on"),
            "verible-path": flags.get("verible-path", ""),
        }

    # ------------------------------------------------------------ saving
    def _save_all(self):
        if self.workspace_root is None:
            messagebox.showwarning("No workspace", "Open or create a workspace first.")
            return
        cfg_dir = self.workspace_root / "config"
        cfg_dir.mkdir(parents=True, exist_ok=True)
        try:
            self._write_config_files(cfg_dir)
        except Exception as e:  # noqa: BLE001
            messagebox.showerror("Save failed", str(e))
            return
        self._log(f"Saved {cfg_dir}/*.\n")

    def _write_config_files(self, cfg_dir):
        """Write all four config files (the three CSVs + gen_flags.txt) to
        cfg_dir from the tabs' current in-memory state. Shared by Save
        (writes to the current set's own directory) and Save As (writes to
        a freshly created sibling directory instead)."""
        self._write_controllers_csv(cfg_dir / "controllers.csv")
        self._write_signals_csv(cfg_dir / "pipe_signals.csv")
        self._write_mapping_csv(cfg_dir / "lane_mapping.csv")
        self._write_gen_flags(cfg_dir / "gen_flags.txt")

    @staticmethod
    def _write_aligned_csv(path, header, rows, eol):
        """Write a CSV with every column comma-aligned (each field padded
        with spaces after its comma so the next column lines up), for
        hand-editing readability. This is a legitimate, common CSV style --
        _read_csv/_read_mapping_csv (and plm_config.py's own readers)
        already strip whitespace around every field, so a round trip
        through the GUI keeps looking the way a hand-aligned file did,
        instead of collapsing back to comma-with-no-spaces.

        header/rows entries are plain values (not yet comma-escaped) --
        this domain (signal/controller names, small integers, mode
        indices) never needs CSV quoting, so this skips the csv module
        entirely rather than fighting it over inserted alignment spaces.
        """
        all_rows = [list(header)] + [list(r) for r in rows]
        ncols = len(header)
        widths = [max(len(str(row[i])) for row in all_rows) for i in range(ncols)]
        with open(path, "w", newline="", encoding="utf-8") as f:
            for row in all_rows:
                cells = []
                for i, v in enumerate(row):
                    v = str(v)
                    cells.append((v + ",").ljust(widths[i] + 2) if i < ncols - 1 else v)
                f.write("".join(cells) + eol)

    def _write_controllers_csv(self, path):
        rows = self.controllers_table.get_rows()
        if not rows:
            raise ValueError("Controllers table is empty -- at least one controller is required.")
        eol = self._existing_line_ending(path)  # must read this *before* opening "w" truncates the file
        self._write_aligned_csv(
            path,
            ["ctrl_id", "ctrl_name", "max_width"],
            [[r.get("ctrl_id", ""), r.get("ctrl_name", ""), r.get("max_width", "")] for r in rows],
            eol,
        )

    def _write_signals_csv(self, path):
        rows = self.signals_table.get_rows()
        if not rows:
            raise ValueError("Pipe Signals table is empty -- at least one signal is required.")
        eol = self._existing_line_ending(path)  # must read this *before* opening "w" truncates the file
        self._write_aligned_csv(
            path,
            ["signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"],
            [
                [
                    r.get("signal_name", ""),
                    r.get("signal_type", "") or "perlane",
                    r.get("direction", ""),
                    r.get("width", ""),
                    r.get("safe_state", ""),
                    r.get("tie_off", ""),
                ]
                for r in rows
            ],
            eol,
        )

    def _write_mapping_csv(self, path):
        rows = self.mapping_table.get_rows()
        if not rows:
            raise ValueError("Lane Mapping table is empty -- at least one mode row is required.")
        cols = self.mapping_table.col_keys
        eol = self._existing_line_ending(path)  # must read this *before* opening "w" truncates the file
        self._write_aligned_csv(path, cols, [[r.get(c, "") for c in cols] for r in rows], eol)

    def _write_gen_flags(self, path):
        lines = [
            "# 支持: pclk-mode = pclk_as_phy_output | pclk_as_phy_input",
            "#       sel-mode  = sync | comb",
            "#       dpr       = true | false",
        ]
        header_lines = len(lines)
        pclk = self.pclk_mode_var.get()
        sel = self.sel_mode_var.get()
        dpr = self.dpr_var.get()
        verible = self.verible_path_var.get().strip()
        if pclk in ("pclk_as_phy_output", "pclk_as_phy_input"):
            lines.append(f"pclk-mode = {pclk}")
        if sel in ("sync", "comb"):
            lines.append(f"sel-mode = {sel}")
        if dpr:
            lines.append("dpr = true")
        if verible:
            lines.append(f"verible-path = {verible}")
        if len(lines) == header_lines:
            # nothing but the header comment lines -- no point writing a
            # file that would set no keys at all.
            if path.is_file():
                path.unlink()
            return
        eol = self._existing_line_ending(path)  # must read this *before* truncating the file
        # newline="" (like the CSV writers) so the \n's already joined into
        # the text below are written as-is, not translated to os.linesep --
        # write_text()'s default newline=None would silently flip an
        # existing LF file to CRLF (or vice versa) on every save.
        with open(path, "w", newline="", encoding="utf-8") as f:
            f.write(eol.join(lines) + eol)

    def _load_default_signals(self, silent=False):
        # Prefer copying an existing config's signal list as a ready-made,
        # already-valid starting point over hand-authoring PIPE's ~35
        # signals from scratch -- this project's own bundled sample
        # workspaces (configs/test_quad, etc.) always exist regardless of
        # which workspace is currently open, so they're a reliable template
        # source for a brand-new, still-empty workspace.
        for name in list_configs():
            src = CONFIGS_ROOT / name / "config" / "pipe_signals.csv"
            if src.is_file():
                self.signals_table.set_rows(self._read_csv(src))
                if not silent:
                    self._log(f"Loaded pipe_signals.csv from {CONFIGS_ROOT / name} as a starting point.\n")
                return
        if not silent:
            messagebox.showinfo(
                "No template found", "No bundled sample workspace has a pipe_signals.csv to copy from."
            )

    # ------------------------------------------------------------ validate
    def _validate(self):
        if self.workspace_root is None:
            messagebox.showwarning("No workspace", "Open or create a workspace first.")
            return
        self._save_all()
        cfg_dir = self.workspace_root / "config"
        self._log(f"--- validating {cfg_dir} ---\n")
        try:
            cfg = Config(cfg_dir)
        except SystemExit as e:
            self._log(f"{e}\n")
            return
        errs = cfg.validate()
        if errs:
            self._log("Config validation failed:\n")
            for e in errs:
                self._log(f"  - {e}\n")
        else:
            self._log("OK -- config is valid.\n")

    # ------------------------------------------------------------ generation
    def _gen_rtl(self):
        self._run_tool("plm_gen_rtl.py")

    def _gen_tb(self):
        self._run_tool("plm_gen_tb.py")

    def _gen_all(self):
        self._run_tool("plm_gen_rtl.py", then=lambda: self._run_tool("plm_gen_tb.py"))

    def _run_tool(self, script, then=None):
        if self.workspace_root is None:
            messagebox.showwarning("No workspace", "Open or create a workspace first.")
            return
        self._save_all()
        cmd = [sys.executable, str(SCRIPT_DIR / script), "--config", str(self.workspace_root)]
        self._log(f"$ {' '.join(cmd)}\n")

        def worker():
            try:
                proc = subprocess.Popen(
                    cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    text=True, bufsize=1, cwd=str(SCRIPT_DIR.parent),
                )
                for line in proc.stdout:
                    self.log_queue.put(line)
                proc.wait()
                # 0/1 are the ordinary success/failure outcomes and the
                # surrounding output already makes that clear -- only an
                # unusual code (e.g. a native crash) is worth calling out.
                if proc.returncode not in (0, 1):
                    self.log_queue.put(f"[exit code {proc.returncode}]\n\n")
            except Exception as e:  # noqa: BLE001
                self.log_queue.put(f"Failed to launch {script}: {e}\n")
            if then:
                self.after(0, then)

        threading.Thread(target=worker, daemon=True).start()

    # ------------------------------------------------------------ console / logging
    def _log(self, text):
        self.log_queue.put(text)

    def _poll_log_queue(self):
        try:
            while True:
                text = self.log_queue.get_nowait()
                stamped = f"[{time.strftime('%H:%M:%S')}] {text}"
                self.console.configure(state="normal")
                self.console.insert("end", stamped)
                self.console.see("end")
                self.console.configure(state="disabled")
        except queue.Empty:
            pass
        self.after(100, self._poll_log_queue)


if __name__ == "__main__":
    app = PlmGui()
    app.mainloop()
