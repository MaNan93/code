"""Allow `python -m modeditor` to run the CLI."""

from .cli import main as modeditor_cli

raise SystemExit(modeditor_cli())
