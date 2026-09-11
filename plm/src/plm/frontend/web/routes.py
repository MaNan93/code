"""
Route handlers for the web front end.

Each api_* function takes (query, body) and returns a JSON-serializable
dict, or raises ApiError; the @app.route functions right below it are a
thin Flask-specific wrapper that calls the matching api_* function and
jsonify()s the result. Split out this way so the actual behavior is
testable without going through Flask's request/response machinery at all.
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

from flask import Response, jsonify, request, send_from_directory

from plm.core.model import Config
from plm.core.paths import CONFIGS_ROOT, PLM_ROOT, has_csvs
from plm.core.verible import (
    DEFAULT_VERIBLE_FLAGS,
    VERIBLE_ALIGN_PARAMS,
    VERIBLE_BOOL_PARAMS,
    VERIBLE_INDENT_PARAMS,
    VERIBLE_INT_PARAMS,
    VERIBLE_STR_PARAMS,
    find_verible,
)
from plm.core.workspace import (
    load_default_signals,
    save_workspace_content,
    scaffold_default_content,
    workspace_content,
)
from plm.frontend.web.app import WEB_DIR, _body, _query, app
from plm.frontend.web.workspace_state import (
    ApiError,
    _read_state_file,
    _write_state_file,
    add_recent_workspace,
    load_last_workspace,
    load_recent_workspaces,
    save_last_workspace,
    valid_name,
)

# The only server-side session state this tool keeps -- see app.py's
# module docstring. main() may set this once at startup (reopening the
# last workspace); every handler below that needs it does `global
# current_workspace` to read/mutate this same module attribute.
current_workspace = None  # Path | None


# ---------------------------------------------------------------- API route handlers


def api_recent(query, body):
    return {"recent": [str(p) for p in load_recent_workspaces()],
            "last": str(load_last_workspace()) if load_last_workspace() else None}


def api_recent_remove(query, body):
    """Drops one path from the recent list only -- unlike
    api_workspace_delete, this never touches the filesystem."""
    raw = (body or {}).get("path")
    if not raw:
        raise ApiError("path is required")
    data = _read_state_file()
    data["recent"] = [p for p in data.get("recent", []) if p != raw]
    _write_state_file(data)
    return {"removed": raw}


def api_browse(query, body):
    default_dir = CONFIGS_ROOT if CONFIGS_ROOT.is_dir() else Path.home()
    raw = query.get("path") or str(default_dir)
    d = Path(raw)
    if not d.is_dir():
        raise ApiError(f"Not a directory: {d}")
    entries = []
    try:
        children = sorted(d.iterdir(), key=lambda p: p.name.lower())
    except OSError as e:
        raise ApiError(str(e)) from e
    for c in children:
        if c.is_dir() and not c.name.startswith("."):
            entries.append({"name": c.name, "path": str(c), "workspace": has_csvs(c / "config")})
    parent = str(d.parent) if d.parent != d else None
    return {"path": str(d), "parent": parent, "entries": entries}


def api_workspace_open(query, body):
    global current_workspace
    raw = (body or {}).get("path")
    if not raw:
        raise ApiError("path is required")
    ws = Path(raw)
    if not ws.is_dir():
        raise ApiError(f"Not a directory: {ws}")
    content = workspace_content(ws)  # raises ValueError on real parse failure -- leaves current_workspace untouched
    current_workspace = ws
    add_recent_workspace(ws)
    save_last_workspace(ws)  # auto-reopen this workspace next time plm_web starts
    return {"workspace": str(ws), **content}


def api_workspace_new(query, body):
    global current_workspace
    # parent is optional -- "New" is a naming action, not a "browse to a
    # location" one (see app.js's openNewWorkspaceFlow): the frontend
    # sends the currently-open workspace's own parent dir when one is
    # open, and nothing at all otherwise, in which case this falls back
    # to the same default api_browse itself starts from.
    parent = (body or {}).get("parent") or (CONFIGS_ROOT if CONFIGS_ROOT.is_dir() else Path.home())
    name = (body or {}).get("name")
    name = valid_name(name)
    ws = Path(parent) / name
    if ws.exists():
        raise ApiError(f"{ws} already exists.")
    ws.mkdir(parents=True)
    payload = scaffold_default_content(ws)
    current_workspace = ws
    add_recent_workspace(ws)
    save_last_workspace(ws)
    return {"workspace": str(ws), **payload, "empty": False}


def api_workspace_save(query, body):
    if current_workspace is None:
        raise ApiError("No workspace open.")
    save_workspace_content(current_workspace, body or {})
    return {"workspace": str(current_workspace), "saved": True}


def api_workspace_save_as(query, body):
    global current_workspace
    new_path = (body or {}).get("new_path")
    if not new_path:
        raise ApiError("new_path is required")
    ws = Path(new_path)
    ws.mkdir(parents=True, exist_ok=True)
    payload = {k: (body or {}).get(k) for k in ("controllers", "signals", "mapping", "gen_flags")}
    save_workspace_content(ws, payload)
    current_workspace = ws
    add_recent_workspace(ws)
    save_last_workspace(ws)
    return {"workspace": str(ws), "saved": True}


def api_workspace_delete(query, body):
    global current_workspace
    raw = (body or {}).get("path")
    if not raw:
        raise ApiError("path is required")
    ws = Path(raw)
    if not ws.is_dir():
        raise ApiError(f"Not a directory: {ws}")
    shutil.rmtree(ws)
    if current_workspace == ws:
        current_workspace = None
    return {"deleted": str(ws)}


def api_workspace_current(query, body):
    return {"workspace": str(current_workspace) if current_workspace else None}


def api_validate(query, body):
    if current_workspace is None:
        raise ApiError("No workspace open.")
    save_workspace_content(current_workspace, body or {})
    cfg_dir = current_workspace / "config"
    try:
        cfg = Config(cfg_dir)
    except SystemExit as e:
        return {"ok": False, "errors": [str(e)]}
    errs = cfg.validate()
    return {"ok": not errs, "errors": errs}


def api_verible_detect(query, body):
    return {"path": find_verible(None)}


def api_verible_schema(query, body):
    """Describes the verible-verilog-format flags the Settings UI can show,
    so app.js builds that (fairly large) form from one source of truth
    instead of duplicating plm.core.verible's own lists by hand."""
    return {
        "align_params": list(VERIBLE_ALIGN_PARAMS),
        "indent_params": list(VERIBLE_INDENT_PARAMS),
        "bool_params": list(VERIBLE_BOOL_PARAMS),
        "int_params": list(VERIBLE_INT_PARAMS),
        "str_params": list(VERIBLE_STR_PARAMS),
        "defaults": DEFAULT_VERIBLE_FLAGS,
    }


def api_default_signals(query, body):
    return {"signals": load_default_signals()}


# ---------------------------------------------------------------- generate (SSE)


def stream_generate(targets, verible_path=None, verible_flags=None):
    """Runs `python -m plm.cli.main generate rtl`/`generate tb` against the
    current workspace, yielding each line of stdout as an SSE event as it
    arrives. Flask's dev server handles each request on its own thread
    (threaded=True in app.main()), so this can just block synchronously
    instead of needing a worker thread + queue.

    verible_path and verible_flags, if given, come from this browser's
    global Settings (see app.js's loadSettings) -- unlike the rest of
    Generation Flags, neither is ever written into a workspace's own
    gen_flags.txt, only passed as --verible-path/--verible-flags on this
    one invocation. verible_flags is already a JSON string here (built by
    app.js from its settings object) -- passed straight through to the
    CLI's own --verible-flags, which does the actual json.loads()."""

    def emit(event, data):
        return f"event: {event}\ndata: {json.dumps(data)}\n\n"

    if current_workspace is None:
        yield emit("log", {"line": "No workspace open.\n"})
        yield emit("done", {"returncode": 1})
        return

    to_run = [t for t in targets if t in ("rtl", "tb")]
    overall_rc = 0
    for target in to_run:
        cmd = [sys.executable, "-m", "plm.cli.main", "generate", target, "--config", str(current_workspace)]
        if verible_path:
            cmd += ["--verible-path", verible_path]
        if verible_flags:
            cmd += ["--verible-flags", verible_flags]
        yield emit("log", {"line": f"$ {' '.join(cmd)}\n"})
        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1, cwd=str(PLM_ROOT),
            )
            for line in proc.stdout:
                yield emit("log", {"line": line})
            proc.wait()
            if proc.returncode not in (0, 1):
                yield emit("log", {"line": f"[exit code {proc.returncode}]\n\n"})
            if proc.returncode != 0:
                overall_rc = proc.returncode
        except OSError as e:
            yield emit("log", {"line": f"Failed to launch generate {target}: {e}\n"})
            overall_rc = 1
    yield emit("done", {"returncode": overall_rc})


# ---------------------------------------------------------------- routes


@app.route("/")
def route_index():
    return send_from_directory(WEB_DIR, "index.html")


@app.route("/docs/<path:name>")
def route_docs(name):
    """Serve the project's own docs/ files (read-only) so the in-app Doc
    button can open them. Restricted to plain .md files directly under
    docs/, so this can't be used to read arbitrary paths."""
    docs_dir = (PLM_ROOT / "docs").resolve()
    target = (docs_dir / name).resolve()
    if docs_dir not in target.parents or target.suffix.lower() != ".md":
        return jsonify({"error": "invalid docs path"}), 400
    if not target.is_file():
        return jsonify({"error": f"no such doc: {name}"}), 404
    return send_from_directory(docs_dir, name, mimetype="text/plain; charset=utf-8")


@app.route("/<path:filename>")
def route_static(filename):
    if filename.startswith("api/"):
        return jsonify({"error": f"no such route: GET /{filename}"}), 404
    return send_from_directory(WEB_DIR, filename)


@app.route("/api/recent", methods=["GET"])
def route_recent():
    return jsonify(api_recent(_query(), {}))


@app.route("/api/recent/remove", methods=["POST"])
def route_recent_remove():
    return jsonify(api_recent_remove({}, _body()))


@app.route("/api/browse", methods=["GET"])
def route_browse():
    return jsonify(api_browse(_query(), {}))


@app.route("/api/workspace/open", methods=["POST"])
def route_workspace_open():
    return jsonify(api_workspace_open({}, _body()))


@app.route("/api/workspace/new", methods=["POST"])
def route_workspace_new():
    return jsonify(api_workspace_new({}, _body()))


@app.route("/api/workspace/save", methods=["POST"])
def route_workspace_save():
    return jsonify(api_workspace_save({}, _body()))


@app.route("/api/workspace/save_as", methods=["POST"])
def route_workspace_save_as():
    return jsonify(api_workspace_save_as({}, _body()))


@app.route("/api/workspace/delete", methods=["POST"])
def route_workspace_delete():
    return jsonify(api_workspace_delete({}, _body()))


@app.route("/api/workspace/current", methods=["GET"])
def route_workspace_current():
    return jsonify(api_workspace_current({}, {}))


@app.route("/api/validate", methods=["POST"])
def route_validate():
    return jsonify(api_validate({}, _body()))


@app.route("/api/verible/detect", methods=["GET"])
def route_verible_detect():
    return jsonify(api_verible_detect({}, {}))


@app.route("/api/verible/schema", methods=["GET"])
def route_verible_schema():
    return jsonify(api_verible_schema({}, {}))


@app.route("/api/default-signals", methods=["GET"])
def route_default_signals():
    return jsonify(api_default_signals({}, {}))


@app.route("/api/generate/stream", methods=["GET"])
def route_generate_stream():
    targets = (request.args.get("target") or "all").split(",")
    if "all" in targets:
        targets = ["rtl", "tb"]
    verible_path = request.args.get("verible_path")
    verible_flags = request.args.get("verible_flags")
    return Response(
        stream_generate(targets, verible_path=verible_path, verible_flags=verible_flags),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
