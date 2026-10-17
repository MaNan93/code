# PIPE Lane Mapper

PLM validates controller, lane mapping and PIPE signal CSVs, then generates a
matched SystemVerilog RTL and testbench output set. The Qt editor is optional.

Install the built wheel with `uv pip install dist/plm-3.0.5-py3-none-any.whl`,
or include the editor with
`uv pip install "dist/plm-3.0.5-py3-none-any.whl[qt]"`.
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

The Qt window opens at 1280 × 800. Configuration tables share light grid lines;
the Artifacts viewer uses a GitHub-inspired light palette with Lucide file icons.

For development, use `uv sync --extra qt` and
`uv run python -m unittest discover -s tests -v`. Tests use their own fixtures
and temporary workspaces; editable example projects under `examples/` are separate.

Current documentation and the directory layout are indexed in
[docs/README.md](docs/README.md). The latest Qt screenshots are in
[docs/screenshot/index.html](docs/screenshot/index.html).

Editable examples under `examples/` retain their input `config/` only. Generate
their ignored `rtl/` and `tb/` outputs with `make`, or for example
`uv run plm generate --config dpr --dpr`. Automatic tests continue to use the
independent, reviewed inputs and golden hashes under `tests/fixtures/`.

Rendering and theme performance can be measured with `scripts/profile_ui.py`
and `scripts/profile_themes.py`. Write temporary reports to `build/`; build
outputs, logs and caches are ignored and can be regenerated.

Build the wheel and source distribution with `uv build`. Validate release
contents, console commands, generation and the Qt editor in an independent
temporary environment with:

```text
uv run python scripts/check_wheel.py dist/plm-3.0.5-py3-none-any.whl --sdist dist/plm-3.0.5.tar.gz
```

The wheel includes the application and its runtime resources. The source
distribution also includes tests, immutable fixtures and validation scripts.

Version 3.0.1 removes `--sel-mode` (the select strategy now follows `--dpr`)
and fixes the top-level parameters as localparams; 3.0.0 changed the
generated reset port interface. See the
[release history and migration guide](src/plm/docs/release_note.md)
before updating existing RTL integrations.
