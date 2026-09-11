"use strict";

// ---------------------------------------------------------------- state

let currentWorkspace = null; // string | null
let lastLoadedEmpty = true;

const controllersTable = new EditableTable("controllers-table", {
  columns: [
    {key: "ctrl_id", heading: "ctrl_id"},
    {key: "ctrl_name", heading: "ctrl_name"},
    {key: "max_width", heading: "max_width"},
  ],
  idColumn: "ctrl_id",
});

const signalsTable = new EditableTable("signals-table", {
  // signal_name has no fixed width, so it absorbs all the leftover space
  // after the narrow numeric/enum columns -- keeping the three small
  // columns compact gives signal_name the room it needs.
  columns: [
    {key: "signal_name", heading: "signal_name"},
    {key: "signal_type", heading: "signal_type", options: ["perlane", "shared"], width: "108px"},
    {key: "direction", heading: "direction", options: ["mac2phy", "phy2mac"], width: "128px"},
    {key: "width", heading: "width", width: "66px"},
    {key: "safe_state", heading: "safe_state", width: "84px"},
    {key: "tie_off", heading: "tie_off", width: "66px"},
  ],
  idColumn: null,
});

// Lane Mapping: the drag-paint grid (lanegrid.js). Columns are rebuilt
// whenever the lane count changes.
let mappingLaneCount = 4;
const mappingTable = new LaneGrid("mapping-table");
mappingTable.setColumns(mappingColumns(mappingLaneCount));

function mappingColumns(n) {
  const cols = [{key: "mode", heading: "mode"}];
  for (let l = 0; l < n; l++) cols.push({key: `lane${l}`, heading: `lane${l}`});
  return cols;
}

// ---------------------------------------------------------------- console

function logLine(text, isErr) {
  const el = document.getElementById("console");
  const stamp = new Date().toTimeString().slice(0, 8);
  const span = document.createElement("span");
  if (isErr) span.className = "err";
  span.textContent = `[${stamp}] ${text}`;
  el.appendChild(span);
  el.scrollTop = el.scrollHeight;
}

// ---------------------------------------------------------------- fetch helpers

async function apiGet(path) {
  const res = await fetch(path);
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

async function apiPost(path, body) {
  const res = await fetch(path, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(body || {}),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

// ---------------------------------------------------------------- workspace

function updateWorkspaceUI() {
  // Show only the workspace's folder name (last path segment), never the
  // full path -- the full path used to live here and the user explicitly
  // removed it. document.title echoes the same name in the browser tab.
  const folderName = currentWorkspace
    ? currentWorkspace.split(/[\\/]/).filter(Boolean).pop()
    : null;
  document.getElementById("workspace-title").textContent = folderName || "No workspace open";
  document.title = folderName ? `plmConsultant - ${folderName}` : "plmConsultant";
}

function applyContent(content) {
  controllersTable.setRows(content.controllers || []);
  signalsTable.setRows(content.signals || []);
  const mapping = content.mapping || {lane_count: 4, rows: []};
  mappingLaneCount = mapping.lane_count || 4;
  // The dropdown offers only x2/x4/x8/x16/x32, but a legacy config can
  // carry any lane_count (e.g. test_quad has 12). If the loaded value
  // isn't one of the standard options, inject a temporary option so the
  // dropdown reflects the real count instead of silently snapping to the
  // first entry -- picking a standard value then replaces it.
  const laneSel = document.getElementById("lane-count-select");
  const custom = laneSel.querySelector("option[data-custom]");
  if (custom) custom.remove();
  if (laneSel.querySelector(`option[value="${mappingLaneCount}"]`)) {
    laneSel.value = String(mappingLaneCount);
  } else {
    const opt = document.createElement("option");
    opt.value = String(mappingLaneCount);
    opt.textContent = `x${mappingLaneCount}`;
    opt.dataset.custom = "1";
    laneSel.appendChild(opt);
    laneSel.value = String(mappingLaneCount);
  }
  mappingTable.setColumns(mappingColumns(mappingLaneCount));
  mappingTable.setRows(mapping.rows || []);
  mappingTable.setControllers(content.controllers || []);

  const flags = content.gen_flags || {};
  document.getElementById("flag-arch").value = flags["arch"] || "";
  document.getElementById("flag-pclk-mode").value = flags["pclk-mode"] || "";
  document.getElementById("flag-sel-mode").value = flags["sel-mode"] || "";
  document.getElementById("flag-dpr").checked = !!flags["dpr"];
  onDprToggle();

  lastLoadedEmpty = !!content.empty;
}

async function refreshRecent() {
  try {
    const data = await apiGet("/api/recent");
    const ul = document.getElementById("recent-list");
    ul.innerHTML = "";
    for (const p of data.recent) {
      const li = document.createElement("li");
      li.className = "recent-item" + (p === currentWorkspace ? " active" : "");
      const name = p.split(/[\\/]/).filter(Boolean).pop() || p;
      // Icon-only avatar shown when the sidebar is collapsed: initials from
      // the first letter of each "_"/"-"/" " separated segment, so
      // "test_maxpclk" -> "TM" and "test_finegrain" -> "TF" stay distinct.
      // CSS reads it via li::before { content: attr(data-initial) }.
      const parts = name.split(/[_\-\s]+/).filter(Boolean);
      li.dataset.initial = (
        parts.length > 1
          ? parts.slice(0, 2).map((s) => s[0]).join("")
          : name.slice(0, 2)
      ).toUpperCase();
      // The click handler lives on the <li> (not the inner name span), so a
      // collapsed rail item is still clickable even though the span is
      // display:none. The kebab stops propagation, so it never double-fires.
      li.title = p;
      li.onclick = () => openWorkspace(p);

      const nameSpan = document.createElement("span");
      nameSpan.className = "recent-name";
      nameSpan.textContent = name;
      li.appendChild(nameSpan);

      const kebab = document.createElement("button");
      kebab.className = "recent-kebab";
      kebab.textContent = "⋮";
      kebab.title = "More";
      kebab.onclick = (e) => {
        e.stopPropagation();
        const r = kebab.getBoundingClientRect();
        showDropdownMenu(r.right, r.bottom + 2, [
          {label: "Remove from list", action: () => removeRecentEntry(p)},
          {label: "Delete project", danger: true, action: () => deleteWorkspaceAt(p)},
        ], "right");
      };
      li.appendChild(kebab);

      ul.appendChild(li);
    }
  } catch (e) {
    logLine(`Failed to load recent workspaces: ${e.message}\n`, true);
  }
}

function parentDir(path) {
  const sep = path.includes("\\") ? "\\" : "/";
  const parts = path.split(sep).filter(Boolean);
  parts.pop();
  const isWindows = /^[a-zA-Z]:$/.test(parts[0] || "");
  return (isWindows ? "" : sep) + parts.join(sep);
}

async function openWorkspace(path) {
  try {
    const content = await apiPost("/api/workspace/open", {path});
    currentWorkspace = content.workspace;
    applyContent(content);
    updateWorkspaceUI();
    logLine(`Workspace set to ${currentWorkspace}\n`);
    refreshRecent();
  } catch (e) {
    logLine(`Open failed: ${e.message}\n`, true);
    alert(`Open failed: ${e.message}`);
  }
}

async function newWorkspace(parent, name) {
  try {
    const content = await apiPost("/api/workspace/new", {parent, name});
    currentWorkspace = content.workspace;
    applyContent(content);
    updateWorkspaceUI();
    logLine(`Created new workspace at ${currentWorkspace}\n`);
    refreshRecent();
  } catch (e) {
    logLine(`New workspace failed: ${e.message}\n`, true);
    alert(`New workspace failed: ${e.message}`);
  }
}

function gatherPayload() {
  return {
    controllers: controllersTable.getRows(),
    signals: signalsTable.getRows(),
    mapping: {lane_count: mappingLaneCount, rows: mappingTable.getRows()},
    gen_flags: {
      "arch": document.getElementById("flag-arch").value || null,
      "pclk-mode": document.getElementById("flag-pclk-mode").value || null,
      "sel-mode": document.getElementById("flag-sel-mode").value || null,
      "dpr": document.getElementById("flag-dpr").checked,
    },
  };
}

async function saveWorkspaceAs(newPath) {
  try {
    const payload = gatherPayload();
    payload.new_path = newPath;
    const res = await apiPost("/api/workspace/save_as", payload);
    currentWorkspace = res.workspace;
    updateWorkspaceUI();
    logLine(`Saved a copy to ${currentWorkspace}.\n`);
    refreshRecent();
  } catch (e) {
    logLine(`Save As failed: ${e.message}\n`, true);
    alert(`Save As failed: ${e.message}`);
  }
}

async function deleteWorkspaceAt(path) {
  if (!confirm(`Permanently delete '${path}' and everything under it (config, generated rtl/tb)? This cannot be undone.`)) return;
  try {
    await apiPost("/api/workspace/delete", {path});
    logLine(`Deleted workspace ${path}.\n`);
    if (path === currentWorkspace) {
      currentWorkspace = null;
      applyContent({controllers: [], signals: [], mapping: {lane_count: 4, rows: []}, gen_flags: {}, empty: true});
      updateWorkspaceUI();
    }
    refreshRecent();
  } catch (e) {
    logLine(`Delete failed: ${e.message}\n`, true);
    alert(`Delete failed: ${e.message}`);
  }
}

async function removeRecentEntry(path) {
  try {
    await apiPost("/api/recent/remove", {path});
    logLine(`Removed ${path} from Recent.\n`);
    refreshRecent();
  } catch (e) {
    logLine(`Remove failed: ${e.message}\n`, true);
  }
}

// ---------------------------------------------------------------- dropdown menu

let openDropdown = null;

function showDropdownMenu(x, y, items, align) {
  hideDropdownMenu();
  const menu = document.createElement("ul");
  menu.className = "dropdown-menu";
  menu.style.top = `${y}px`;
  if (align === "right") menu.style.right = `${window.innerWidth - x}px`;
  else menu.style.left = `${x}px`;
  for (const item of items) {
    const li = document.createElement("li");
    li.textContent = item.label;
    if (item.danger) li.classList.add("danger");
    li.onclick = (e) => { e.stopPropagation(); hideDropdownMenu(); item.action(); };
    menu.appendChild(li);
  }
  document.body.appendChild(menu);
  openDropdown = menu;
  setTimeout(() => document.addEventListener("click", hideDropdownMenu, {once: true}), 0);
}

function hideDropdownMenu() {
  if (openDropdown) { openDropdown.remove(); openDropdown = null; }
}

// ---------------------------------------------------------------- browse modal

let browseCallback = null;
let browseCurrentPath = null;

async function openBrowseModal(startPath, title, onSelect) {
  document.getElementById("browse-title").textContent = title;
  browseCallback = onSelect;
  document.getElementById("browse-modal").classList.remove("hidden");
  await browseTo(startPath);
}

async function browseTo(path) {
  try {
    const data = await apiGet(`/api/browse?path=${encodeURIComponent(path)}`);
    browseCurrentPath = data.path;
    document.getElementById("browse-path").textContent = data.path;
    const ul = document.getElementById("browse-list");
    ul.innerHTML = "";
    if (data.parent) {
      const li = document.createElement("li");
      li.textContent = ".. (up)";
      li.onclick = () => browseTo(data.parent);
      ul.appendChild(li);
    }
    for (const entry of data.entries) {
      const li = document.createElement("li");
      li.textContent = entry.workspace ? `${entry.name}  (workspace)` : entry.name;
      if (entry.workspace) li.classList.add("workspace-hit");
      li.ondblclick = () => browseTo(entry.path);
      li.onclick = () => browseTo(entry.path);
      ul.appendChild(li);
    }
  } catch (e) {
    logLine(`Browse failed: ${e.message}\n`, true);
  }
}

function closeBrowseModal() {
  document.getElementById("browse-modal").classList.add("hidden");
  browseCallback = null;
}

// ---------------------------------------------------------------- gen flags sync

let archPclkSyncActive = false;

function onArchChange() {
  if (archPclkSyncActive) return;
  const archEl = document.getElementById("flag-arch");
  const pclkEl = document.getElementById("flag-pclk-mode");
  const map = {original_pipe: "pclk_as_phy_output", serdes: "pclk_as_phy_input"};
  if (map[archEl.value]) {
    archPclkSyncActive = true;
    pclkEl.value = map[archEl.value];
    archPclkSyncActive = false;
  }
}

function onPclkChange() {
  if (archPclkSyncActive) return;
  const archEl = document.getElementById("flag-arch");
  const pclkEl = document.getElementById("flag-pclk-mode");
  const map = {pclk_as_phy_output: "original_pipe", pclk_as_phy_input: "serdes"};
  if (map[pclkEl.value]) {
    archPclkSyncActive = true;
    archEl.value = map[pclkEl.value];
    archPclkSyncActive = false;
  }
}

function onDprToggle() {
  const dpr = document.getElementById("flag-dpr").checked;
  const selEl = document.getElementById("flag-sel-mode");
  if (dpr) {
    selEl.value = "sync";
    selEl.disabled = true;
  } else {
    selEl.disabled = false;
  }
}

// ---------------------------------------------------------------- validate / generate

async function runSave() {
  if (!currentWorkspace) { alert("Open or create a workspace first."); return; }
  try {
    await apiPost("/api/workspace/save", gatherPayload());
    logLine(`Saved ${currentWorkspace}.\n`);
  } catch (e) {
    logLine(`Save failed: ${e.message}\n`, true);
    alert(`Save failed: ${e.message}`);
  }
}

async function runValidate() {
  if (!currentWorkspace) { alert("Open or create a workspace first."); return; }
  logLine(`--- validating ${currentWorkspace}/config ---\n`);
  try {
    const res = await apiPost("/api/validate", gatherPayload());
    if (res.ok) {
      logLine("OK -- config is valid.\n");
    } else {
      logLine("Config validation failed:\n", true);
      for (const e of res.errors) logLine(`  - ${e}\n`, true);
    }
  } catch (e) {
    logLine(`Validate failed: ${e.message}\n`, true);
  }
}

function runGenerate(target) {
  if (!currentWorkspace) { alert("Open or create a workspace first."); return; }
  apiPost("/api/workspace/save", gatherPayload())
    .then(() => {
      const settings = loadSettings();
      const veriblePath = settings.veriblePath ? `&verible_path=${encodeURIComponent(settings.veriblePath)}` : "";
      // null = Settings was never saved -> omit entirely, let the generator
      // fall back to this project's own defaults. An explicitly-saved {}
      // (every field cleared) is still sent, and means "no overrides at
      // all, use verible's own raw defaults" -- see loadSettings/commitSettings.
      const veribleFlags = settings.veribleFlags != null
        ? `&verible_flags=${encodeURIComponent(JSON.stringify(settings.veribleFlags))}` : "";
      const es = new EventSource(`/api/generate/stream?target=${target}${veriblePath}${veribleFlags}`);
      es.addEventListener("log", (ev) => {
        const data = JSON.parse(ev.data);
        logLine(data.line);
      });
      es.addEventListener("done", (ev) => {
        const data = JSON.parse(ev.data);
        if (data.returncode !== 0) logLine(`[generate finished, exit code ${data.returncode}]\n`, true);
        else logLine("[generate finished]\n");
        es.close();
      });
      es.onerror = () => {
        es.close();
      };
    })
    .catch((e) => logLine(`Generate failed: ${e.message}\n`, true));
}

// ---------------------------------------------------------------- settings (global, this browser only)
// verible-path here is a global default, unlike the rest of Generation
// Flags (still per-workspace, written to config/gen_flags.txt) -- it's
// passed to plm_gen_rtl.py/plm_gen_tb.py as --verible-path at generate
// time (see runGenerate) instead of ever being written into a workspace's
// own files.

const SETTINGS_KEY = "plm_web_settings";
// veribleFlags is null until the user actually saves Settings once -- see
// runGenerate, which only adds --verible-flags at all once it's non-null
// (an explicitly-saved {} means "no overrides, use verible's own raw
// defaults", a real and different choice from "never touched this panel,
// use this project's own defaults" -- see stream_generate()'s docstring in
// plm_web.py).
const DEFAULT_SETTINGS = {veriblePath: "", fontFamily: "", fontSize: 13.5, veribleFlags: null};

let veribleSchema = null; // {align_params, indent_params, bool_params, int_params, str_params, defaults}

async function loadVeribleSchema() {
  if (veribleSchema) return veribleSchema;
  veribleSchema = await apiGet("/api/verible/schema");
  return veribleSchema;
}

function loadSettings() {
  try {
    return {...DEFAULT_SETTINGS, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}")};
  } catch (e) {
    return {...DEFAULT_SETTINGS};
  }
}

function saveSettings(settings) {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch (e) { /* private browsing / storage disabled -- settings just won't persist */ }
}

function applySettings(settings) {
  const root = document.documentElement.style;
  if (settings.fontFamily) root.setProperty("--font", settings.fontFamily);
  else root.removeProperty("--font");
  document.body.style.fontSize = settings.fontSize ? `${settings.fontSize}px` : "";
}

// -- verible flags form (dynamically built from /api/verible/schema) ----

function veribleFlagRow(param, controlEl) {
  const row = document.createElement("div");
  row.className = "flag-row";
  const label = document.createElement("label");
  label.textContent = param;
  label.title = param;
  label.htmlFor = `vf-${param}`;
  controlEl.id = `vf-${param}`;
  row.appendChild(label);
  row.appendChild(controlEl);
  return row;
}

function veribleSelect(options) {
  const sel = document.createElement("select");
  const optDefault = document.createElement("option");
  optDefault.value = "";
  optDefault.textContent = "(tool default)";
  sel.appendChild(optDefault);
  for (const opt of options) {
    const o = document.createElement("option");
    o.value = opt;
    o.textContent = opt;
    sel.appendChild(o);
  }
  return sel;
}

function buildVeribleFlagsForm(currentFlags) {
  const schema = veribleSchema;
  const container = document.getElementById("verible-flags-form");
  container.innerHTML = "";
  const flags = currentFlags || {};

  const section = (title, params, makeControl) => {
    if (!params.length) return;
    const h = document.createElement("h5");
    h.textContent = title;
    container.appendChild(h);
    const grid = document.createElement("div");
    grid.className = "flag-grid";
    for (const param of params) {
      const control = makeControl(param);
      const value = Object.prototype.hasOwnProperty.call(flags, param)
        ? flags[param] : (schema.defaults[param] || "");
      control.value = value;
      grid.appendChild(veribleFlagRow(param, control));
    }
    container.appendChild(grid);
  };

  section("Alignment", schema.align_params, () => veribleSelect(["align", "flush-left"]));
  section("Indentation", schema.indent_params, () => veribleSelect(["indent", "wrap"]));
  section("Boolean", schema.bool_params, () => veribleSelect(["true", "false"]));
  section("Integer", schema.int_params, () => {
    const inp = document.createElement("input");
    inp.type = "number";
    return inp;
  });
  // Other (line_terminator, lines, ...) intentionally hidden in the UI:
  // too niche to deserve form space, and verible's own defaults are sane.
}

function readVeribleFlagsForm() {
  const schema = veribleSchema;
  const allParams = [
    ...schema.align_params, ...schema.indent_params, ...schema.bool_params,
    ...schema.int_params, ...schema.str_params,
  ];
  const flags = {};
  for (const param of allParams) {
    const el = document.getElementById(`vf-${param}`);
    const val = el ? el.value.trim() : "";
    if (val) flags[param] = val;
  }
  return flags;
}

function switchSettingsTab(name) {
  for (const btn of document.querySelectorAll(".settings-tab")) {
    btn.classList.toggle("active", btn.dataset.stab === name);
  }
  for (const pane of document.querySelectorAll(".settings-tabpane")) {
    pane.classList.toggle("active", pane.id === `settings-tab-${name}`);
  }
}

async function openSettingsModal() {
  const s = loadSettings();
  document.getElementById("settings-verible-path").value = s.veriblePath || "";
  document.getElementById("settings-font-family").value = s.fontFamily || "";
  document.getElementById("settings-font-size").value = s.fontSize || DEFAULT_SETTINGS.fontSize;
  switchSettingsTab("general");
  // Show the modal immediately; load the verible flag schema
  // asynchronously so the UI doesn't block on a network round-trip.
  document.getElementById("settings-modal").classList.remove("hidden");
  const formContainer = document.getElementById("verible-flags-form");
  const placeholder = document.createElement("p");
  placeholder.className = "hint-sm";
  placeholder.textContent = "Loading flag schema…";
  formContainer.innerHTML = "";
  formContainer.appendChild(placeholder);
  try {
    await loadVeribleSchema();
    buildVeribleFlagsForm(s.veribleFlags);
  } catch (e) {
    formContainer.innerHTML = "";
    logLine(`Failed to load verible flag schema: ${e.message}\n`, true);
  }
}

function closeSettingsModal() {
  document.getElementById("settings-modal").classList.add("hidden");
}

function commitSettings() {
  const settings = {
    veriblePath: document.getElementById("settings-verible-path").value.trim(),
    fontFamily: document.getElementById("settings-font-family").value.trim(),
    fontSize: parseFloat(document.getElementById("settings-font-size").value) || DEFAULT_SETTINGS.fontSize,
    veribleFlags: veribleSchema ? readVeribleFlagsForm() : loadSettings().veribleFlags,
  };
  saveSettings(settings);
  applySettings(settings);
  closeSettingsModal();
}

// ---------------------------------------------------------------- sidebar collapse

function setupResizers() {
  // ChatGPT-style sidebar: collapse via the topbar hamburger, no drag-resize.
  // (The original tool exposed a draggable sidebar divider; we drop it in
  // favor of a cleaner fixed-width pane that slides off-screen.)
  const sidebar = document.getElementById("sidebar");
  const toggle = document.getElementById("btn-collapse-sidebar");
  if (toggle && sidebar) {
    const KEY = "plm_web_sidebar_collapsed";
    try { if (localStorage.getItem(KEY) === "1") sidebar.classList.add("collapsed"); } catch (e) { /* ignore */ }
    toggle.onclick = () => {
      sidebar.classList.toggle("collapsed");
      try { localStorage.setItem(KEY, sidebar.classList.contains("collapsed") ? "1" : "0"); } catch (e) { /* ignore */ }
    };
  }
}

// ---------------------------------------------------------------- wiring

function switchPage(name) {
  for (const btn of document.querySelectorAll(".tab-btn")) {
    btn.classList.toggle("active", btn.dataset.page === name);
  }
  for (const page of document.querySelectorAll(".page")) {
    page.classList.toggle("active", page.id === `page-${name}`);
  }
  if (name === "lanemapping") {
    // Pick up any live, unsaved edits from the Controllers tab -- mirrors
    // plmConsultant.py's _on_tab_changed (tool/plmConsultant.py:1498).
    mappingTable.setControllers(controllersTable.getRows());
  }
}

document.addEventListener("DOMContentLoaded", () => {
  setupResizers();
  applySettings(loadSettings());

  for (const btn of document.querySelectorAll(".tab-btn")) {
    btn.onclick = () => switchPage(btn.dataset.page);
  }

  const openNewWorkspaceFlow = () => {
    // "New" creates a config set -- it's a naming action, not a "find an
    // existing location" action, so it shouldn't reuse Open's browse-first
    // flow. Just ask for a name; the new config lands next to whatever's
    // currently open (or the server's own sensible default -- see
    // api_browse/api_workspace_new -- when nothing is open yet). Use Save
    // As afterwards to relocate it if the default location isn't right.
    const name = prompt("New config name:");
    if (!name) return;
    const parent = currentWorkspace ? parentDir(currentWorkspace) : null;
    newWorkspace(parent, name);
  };

  document.getElementById("btn-open").onclick = () => {
    openBrowseModal(currentWorkspace || "", "Open workspace", (path) => {
      closeBrowseModal();
      openWorkspace(path);
    });
  };

  document.getElementById("btn-new").onclick = openNewWorkspaceFlow;
  // (the original topbar also had a duplicate #btn-new-top; the new layout
  // exposes New only in the sidebar, so we don't wire a second handler.)

  document.getElementById("btn-settings").onclick = openSettingsModal;
  document.getElementById("btn-doc").onclick = () => {
    // Mirrors plmConsultant.py's _open_docs (plmConsultant.py:1243): open the
    // project's own docs/tool_usage.md.
    window.open("/docs/tool_usage.md", "_blank", "noopener");
  };
  for (const btn of document.querySelectorAll(".settings-tab")) {
    btn.onclick = () => switchSettingsTab(btn.dataset.stab);
  }
  document.getElementById("settings-save").onclick = commitSettings;
  document.getElementById("settings-cancel").onclick = closeSettingsModal;
  document.getElementById("settings-verible-detect").onclick = async () => {
    try {
      const res = await apiGet("/api/verible/detect");
      document.getElementById("settings-verible-path").value = res.path || "";
      logLine(res.path ? `Found verible at ${res.path}\n` : "No verible-verilog-format found on PATH.\n");
    } catch (e) {
      logLine(`Auto-detect failed: ${e.message}\n`, true);
    }
  };
  document.getElementById("settings-verible-reset").onclick = async () => {
    try {
      await loadVeribleSchema();
      buildVeribleFlagsForm(null); // null -> every row falls back to schema.defaults
    } catch (e) {
      logLine(`Reset failed: ${e.message}\n`, true);
    }
  };

  // (the original topbar had a #btn-save-as button for "save to a new
  // workspace folder"; the new layout exposes only Save in the sidebar,
  // so we don't wire a second handler.)

  document.getElementById("btn-save").onclick = runSave;
  document.getElementById("btn-validate").onclick = runValidate;
  document.getElementById("btn-gen-rtl").onclick = () => runGenerate("rtl");
  document.getElementById("btn-gen-tb").onclick = () => runGenerate("tb");
  document.getElementById("btn-gen-all").onclick = () => runGenerate("all");

  document.getElementById("browse-select").onclick = () => {
    if (browseCallback) browseCallback(browseCurrentPath);
  };
  document.getElementById("browse-cancel").onclick = closeBrowseModal;

  document.getElementById("flag-arch").onchange = onArchChange;
  document.getElementById("flag-pclk-mode").onchange = onPclkChange;
  document.getElementById("flag-dpr").onchange = onDprToggle;

  document.getElementById("lane-count-select").onchange = () => {
    const sel = document.getElementById("lane-count-select");
    const n = parseInt(sel.value, 10);
    if (!Number.isInteger(n) || n < 1) return;
    // Drop the legacy-value placeholder (if any) as soon as a standard
    // x2/x4/x8/x16/x32 value is chosen -- it's only there to display a
    // non-standard count loaded from an older config.
    const custom = sel.querySelector("option[data-custom]");
    if (custom) custom.remove();
    mappingLaneCount = n;
    mappingTable.setColumns(mappingColumns(n));
  };

  refreshRecent();
  apiGet("/api/workspace/current").then((res) => {
    if (res.workspace) openWorkspace(res.workspace);
  });
});
