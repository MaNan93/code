# Python environment

Use **uv** with this project's `.venv` and the locked dependencies:

```bash
uv sync --extra qt --locked
uv run python run.py -gui
uv run python -m unittest discover -s tests -v
```

Run Python commands through `uv run`. Dependencies and the optional `qt` group
are declared in [pyproject.toml](pyproject.toml). Directory responsibilities,
build commands and current documentation are indexed in [README.md](README.md)
and [docs/README.md](docs/README.md). Keep version history according to
[AGENTS.md](AGENTS.md).
