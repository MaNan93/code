"""Run directly and resolve the same-named package from src/csrgen."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

# This file also wins the normal import lookup when cwd is the project root.
# Load the actual package explicitly so `import csrgen`, console scripts, and
# `python -m csrgen` continue to work from this directory.
_package_dir = Path(__file__).resolve().parent / "src" / "csrgen"
_spec = spec_from_file_location(
    "csrgen", _package_dir / "__init__.py",
    submodule_search_locations=[str(_package_dir)],
)
_package = module_from_spec(_spec)
sys.modules["csrgen"] = _package
_spec.loader.exec_module(_package)

from csrgen.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
