# PIPE Lane Mapper

PLM validates controller, lane mapping and PIPE signal CSVs, then generates a
matched SystemVerilog RTL and testbench output set. The Qt editor is optional.

Install the built wheel with `uv pip install dist/plm-2.0.7-py3-none-any.whl`,
or include the editor with
`uv pip install "dist/plm-2.0.7-py3-none-any.whl[qt]"`.
Python 3.9 or newer is required.

```text
plm validate --config /path/to/workspace
plm generate --config /path/to/workspace
plm --version
plm-gui
```

The workspace contains a `config/` directory holding `controllers.csv`,
`lane_mapping.csv` and `pipe_signals.csv`. Generation writes `rtl/` and `tb/`
beside `config/`. The Qt editor can create a workspace with default content.
Usage and editor documentation are included in the installed package.

For development, use `uv sync --extra qt` and
`uv run python -m unittest discover -s tests -v`. Tests use their own fixtures
and temporary workspaces; editable example projects under `test/` are separate.

Build the wheel and source distribution with `uv build`. Validate release
contents, console commands, generation and the Qt editor in an independent
temporary environment with:

```text
uv run python scripts/check_wheel.py dist/plm-2.0.7-py3-none-any.whl --sdist dist/plm-2.0.7.tar.gz
```

The wheel includes the application and its runtime resources. The source
distribution also includes tests, immutable fixtures and validation scripts.
