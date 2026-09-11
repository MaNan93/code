#!/usr/bin/env python3
"""
run.py -- single, shallow entry point for the whole PIPE Lane Mapper toolchain.

Run this file directly instead of the deeper `python -m plm.cli.main ...`
invocation (or hunting down the plm/plm-web/plm-qt console scripts, which
need `pip install -e .` and a PATH that includes the venv's Scripts dir).
This file finds src/ next to itself and adds it to sys.path on its own, so
`generate`/`validate` work even without installing the package first; `web`
and `qt` still need their extras installed (`pip install -e ".[web]"` /
`".[qt]"`) since Flask/PyQt5 themselves aren't vendored.

    python run.py generate rtl --config quad
    python run.py generate tb  --config quad
    python run.py generate all --config quad
    python run.py validate     --config quad
    python run.py web [--port N] [--no-browser]
    python run.py qt
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv

    if argv[:1] == ["web"]:
        sys.argv = [sys.argv[0]] + argv[1:]
        from plm.frontend.web.app import main as web_main
        return web_main()

    if argv[:1] == ["qt"]:
        sys.argv = [sys.argv[0]] + argv[1:]
        from plm.frontend.qt.main import main as qt_main
        return qt_main()

    from plm.cli.main import main as cli_main
    return cli_main(argv)


if __name__ == "__main__":
    sys.exit(main())
