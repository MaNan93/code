# Python environment

This project uses **uv** to manage its Python environment. Do not use a bare `python` command to run or install anything in this repo — use `uv run` instead.

- Virtual environment: `.venv` (created with `uv venv --python 3.12`)
- Dependencies: declared in [pyproject.toml](pyproject.toml), optional groups `web` (Flask) and `qt` (PyQt5)
- VSCode/editor interpreter path is pinned in `.vscode/settings.json`

Examples:

```bash
uv run python run.py
uv run pytest
uv run plm-web
```

To install or sync dependencies:

```bash
uv pip install -e ".[web,qt]"
```

`uv run` always resolves to this project's `.venv`, regardless of what `python` points to globally or in whatever terminal/agent is invoking it.
