#!/usr/bin/env python3
"""
plm_web -- PIPE Lane Mapper config editor + generator, HTML/browser front end.

Same role as the Qt front end (plm.frontend.qt): a thin front end over the
three config CSVs / gen_flags.txt that plm.core.generator reads (via
plm.cli.main), and over that generation pipeline itself, but served over
HTTP to a browser instead of a desktop window. Built on Flask
(pip install "plm[web]"). The Qt front end is untouched; this is an
independent, coexisting entry point.

Doesn't duplicate any generation or validation logic: editing writes the
same plain CSV/gen_flags.txt files a human would hand-edit, /api/validate
calls plm.core.model.Config directly, and /api/generate/stream shells out
to `python -m plm.cli.main generate ...`, the same way the Makefile does,
streaming output back as Server-Sent Events.

The server holds exactly one piece of session state: the currently-open
workspace path (this is a single-user, single-process, local-only tool --
no auth, no concurrent-client handling). Every read/write goes straight to
disk; there is no server-side copy of table contents between requests.

Run: python3 -m plm.frontend.web.app [--port N] [--no-browser]
(or, once installed: plm-web [--port N] [--no-browser])
"""

import argparse
import sys
import webbrowser
from pathlib import Path

try:
    from flask import Flask, jsonify, request
except ImportError:
    sys.exit(
        "plm-web needs Flask. Install it with:\n"
        '    pip install "plm[web]"\n'
        "(or, offline, transfer the flask/werkzeug/jinja2/markupsafe/click/"
        "itsdangerous/blinker wheels to this machine and pip install those)."
    )

from plm.frontend.web.workspace_state import ApiError, load_last_workspace

WEB_DIR = Path(__file__).resolve().parent / "static"

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


# Import at the bottom, after `app` exists: routes.py does
# `from plm.frontend.web.app import app` and decorates it with
# @app.route(...) -- the standard way to avoid a circular import between
# "the module that owns `app`" and "the module that registers routes onto
# it" when they're kept in separate files.
from plm.frontend.web import routes  # noqa: E402,F401


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, default=8642, help="TCP port to listen on (default: 8642)")
    ap.add_argument("--host", default="127.0.0.1", help="bind address (default: 127.0.0.1, local-only)")
    ap.add_argument("--no-browser", action="store_true", help="don't auto-open a browser tab")
    args = ap.parse_args()

    last = load_last_workspace()
    if last is not None:
        routes.current_workspace = last

    url = f"http://{args.host}:{args.port}/"
    print(f"plm_web serving on {url}  (Ctrl+C to stop)")
    if not args.no_browser:
        webbrowser.open(url)
    app.run(host=args.host, port=args.port, threaded=True, debug=False)


if __name__ == "__main__":
    main()
