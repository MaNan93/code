#!/usr/bin/env python3
"""
plm_web -- PIPE Lane Mapper config editor + generator, HTML/browser front end.

Same role as plmConsultant.py (a thin front end over the three config CSVs
/ gen_flags.txt that plm_gen_rtl.py and plm_gen_tb.py read, and over those
two tools themselves), but served over HTTP to a browser instead of a
Tkinter window. Built on Flask (pip install flask). plmConsultant.py is
untouched; this is an independent, coexisting entry point.

Like plmConsultant.py, this doesn't duplicate any generation or validation
logic: editing writes the same plain CSV/gen_flags.txt files a human would
hand-edit, /api/validate calls plm_config.Config directly, and
/api/generate/stream shells out to the two real CLI tools, the same way
the Makefile (and plmConsultant.py) does, streaming their output back as
Server-Sent Events.

The server holds exactly one piece of session state: the currently-open
workspace path (this is a single-user, single-process, local-only tool --
no auth, no concurrent-client handling). Every read/write goes straight to
disk; there is no server-side copy of table contents between requests.

Run: python3 tool/plm_web.py [--port N] [--no-browser]
"""

import argparse
import json
import shutil
import subprocess
import sys
import webbrowser
from pathlib import Path

try:
    from flask import Flask, Response, jsonify, request, send_from_directory
except ImportError:
    sys.exit(
        "plm_web needs Flask. Install it with:\n"
        "    pip install flask\n"
        "(or, offline, transfer the flask/werkzeug/jinja2/markupsafe/click/"
        "itsdangerous/blinker wheels to this machine and pip install those)."
    )

SCRIPT_DIR = Path(__file__).resolve().parent
WEB_DIR = SCRIPT_DIR / "web"
sys.path.insert(0, str(SCRIPT_DIR))
from plm_common import (  # noqa: E402
    CONFIGS_ROOT,
    DEFAULT_VERIBLE_FLAGS,
    PLM_ROOT,
    VERIBLE_ALIGN_PARAMS,
    VERIBLE_BOOL_PARAMS,
    VERIBLE_INDENT_PARAMS,
    VERIBLE_INT_PARAMS,
    VERIBLE_STR_PARAMS,
    find_verible,
    has_csvs,
    load_default_signals,
    save_workspace_content,
    scaffold_default_content,
    workspace_content,
)
from plm_config import Config  # noqa: E402

STATE_FILE = Path.home() / ".plm_web_workspace.json"
MAX_RECENT_WORKSPACES = 10

# The only server-side session state this tool keeps -- see module docstring.
current_workspace = None  # Path | None


# ---------------------------------------------------------------- small errors


class ApiError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


# ---------------------------------------------------------------- recent-workspace state file
# A small, independent copy of plmConsultant.py's own
# _read_state_file/_write_state_file/_load_recent_workspaces/etc.
# (plmConsultant.py:948-996) -- kept separate (own state file, own copy of
# the logic) so the two tools never interfere with each other just from
# both being open, per this project's "coexist, don't refactor the
# existing tool" decision.


def _read_state_file():
    if not STATE_FILE.is_file():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _write_state_file(data):
    try:
        STATE_FILE.write_text(json.dumps(data), encoding="utf-8")
    except OSError:
        pass  # remembering workspace state is a convenience, not required


def load_recent_workspaces():
    raw = _read_state_file().get("recent", [])
    return [p for p in (Path(r) for r in raw) if p.is_dir()]


def add_recent_workspace(path):
    """Appends path if it's not already listed -- an already-listed entry
    keeps its existing position instead of jumping to the front on every
    open, so the Recent list holds still and isn't reordered by use."""
    data = _read_state_file()
    path_str = str(path)
    recent = data.get("recent", [])
    if path_str not in recent:
        recent.append(path_str)
    # Still capped, but trimmed from the oldest (front) end now that the
    # list is insertion-ordered rather than most-recently-used-first.
    data["recent"] = recent[-MAX_RECENT_WORKSPACES:]
    _write_state_file(data)


def save_last_workspace(path):
    data = _read_state_file()
    data["workspace"] = str(path)
    _write_state_file(data)


def load_last_workspace():
    raw = _read_state_file().get("workspace")
    if not raw:
        return None
    path = Path(raw)
    return path if path.is_dir() else None


def valid_name(name):
    name = (name or "").strip()
    if not name or any(c in name for c in ' /\\:*?"<>|'):
        raise ApiError('Use a plain folder name, no spaces or path characters.')
    return name


# CSV / gen_flags read-write, and the workspace_content/save_workspace_content/
# scaffold_default_content helpers built on top of them, now live in
# plm_common.py (shared with plmConsultant.py and plm_qt.py) -- see the
# import block above.


# ---------------------------------------------------------------- API route handlers
# Each handler takes (query, body) and returns a JSON-serializable dict, or
# raises ApiError. query is a dict[str, str] (first value of each parsed
# query param); body is the parsed JSON request body (or {} for GET).


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
    instead of duplicating tool/plm_common.py's own lists by hand."""
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


API_ROUTES = {
    ("GET", "/api/recent"): api_recent,
    ("POST", "/api/recent/remove"): api_recent_remove,
    ("GET", "/api/browse"): api_browse,
    ("POST", "/api/workspace/open"): api_workspace_open,
    ("POST", "/api/workspace/new"): api_workspace_new,
    ("POST", "/api/workspace/save"): api_workspace_save,
    ("POST", "/api/workspace/save_as"): api_workspace_save_as,
    ("POST", "/api/workspace/delete"): api_workspace_delete,
    ("GET", "/api/workspace/current"): api_workspace_current,
    ("POST", "/api/validate"): api_validate,
    ("GET", "/api/verible/detect"): api_verible_detect,
    ("GET", "/api/default-signals"): api_default_signals,
}


# ---------------------------------------------------------------- generate (SSE)


def stream_generate(targets, verible_path=None, verible_flags=None):
    """Runs plm_gen_rtl.py and/or plm_gen_tb.py against the current
    workspace, yielding each line of stdout as an SSE event as it arrives.
    Same subprocess invocation shape as plmConsultant.py's _run_tool
    (plmConsultant.py:2041-2068); Flask's dev server handles each request on
    its own thread (threaded=True in main()), so this can just block
    synchronously instead of needing plmConsultant.py's queue+poll (Tk's
    mainloop can't block, this request thread can).

    verible_path and verible_flags, if given, come from this browser's
    global Settings (see app.js's loadSettings) -- unlike the rest of
    Generation Flags, neither is ever written into a workspace's own
    gen_flags.txt, only passed as --verible-path/--verible-flags on this
    one invocation. verible_flags is already a JSON string here (built by
    app.js from its settings object) -- passed straight through to the
    generator's own --verible-flags, which does the actual json.loads()."""

    def emit(event, data):
        return f"event: {event}\ndata: {json.dumps(data)}\n\n"

    if current_workspace is None:
        yield emit("log", {"line": "No workspace open.\n"})
        yield emit("done", {"returncode": 1})
        return

    scripts = {"rtl": "plm_gen_rtl.py", "tb": "plm_gen_tb.py"}
    to_run = [scripts[t] for t in targets if t in scripts]
    overall_rc = 0
    for script in to_run:
        cmd = [sys.executable, str(SCRIPT_DIR / script), "--config", str(current_workspace)]
        if verible_path:
            cmd += ["--verible-path", verible_path]
        if verible_flags:
            cmd += ["--verible-flags", verible_flags]
        yield emit("log", {"line": f"$ {' '.join(cmd)}\n"})
        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1, cwd=str(SCRIPT_DIR.parent),
            )
            for line in proc.stdout:
                yield emit("log", {"line": line})
            proc.wait()
            if proc.returncode not in (0, 1):
                yield emit("log", {"line": f"[exit code {proc.returncode}]\n\n"})
            if proc.returncode != 0:
                overall_rc = proc.returncode
        except OSError as e:
            yield emit("log", {"line": f"Failed to launch {script}: {e}\n"})
            overall_rc = 1
    yield emit("done", {"returncode": overall_rc})


# ---------------------------------------------------------------- Flask app / routes

app = Flask(__name__)


@app.errorhandler(ApiError)
def handle_api_error(e):
    return jsonify({"error": str(e)}), e.status


@app.errorhandler(Exception)
def handle_unexpected_error(e):  # noqa: BLE001 -- surface any unexpected failure as JSON, not a bare 500 page
    # Flask/Werkzeug always dispatches to the most specific matching
    # errorhandler, so handle_api_error (registered for ApiError) already
    # takes any ApiError before this generic one ever sees it.
    return jsonify({"error": f"{type(e).__name__}: {e}"}), 500


def _body():
    return request.get_json(silent=True) or {}


def _query():
    return request.args


@app.route("/")
def route_index():
    return send_from_directory(WEB_DIR, "index.html")


@app.route("/docs/<path:name>")
def route_docs(name):
    """Serve the project's own docs/ files (read-only) so the in-app Doc
    button can open them -- mirrors plmConsultant.py's _open_docs
    (plmConsultant.py:1243), which opened docs/tool_usage.md in a browser.
    Restricted to plain .md files directly under docs/, so this can't be
    used to read arbitrary paths."""
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


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=8642, help="TCP port to listen on (default: 8642)")
    ap.add_argument("--host", default="127.0.0.1", help="bind address (default: 127.0.0.1, local-only)")
    ap.add_argument("--no-browser", action="store_true", help="don't auto-open a browser tab")
    args = ap.parse_args()

    global current_workspace
    last = load_last_workspace()
    if last is not None:
        current_workspace = last

    url = f"http://{args.host}:{args.port}/"
    print(f"plm_web serving on {url}  (Ctrl+C to stop)")
    if not args.no_browser:
        webbrowser.open(url)
    app.run(host=args.host, port=args.port, threaded=True, debug=False)


if __name__ == "__main__":
    main()
