"""Allow `python -m vmodeditor` to run the CLI."""

from .cli import main

raise SystemExit(main())
