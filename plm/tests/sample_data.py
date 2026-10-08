"""Read-only regression inputs, separate from users' editable test/ workspaces."""

from pathlib import Path


SAMPLES_DIR = Path(__file__).resolve().parent / "fixtures" / "samples"


def sample_config(name):
    """Return a checked-in config; copy it before exercising write operations."""
    directory = SAMPLES_DIR / name / "config"
    if not directory.is_dir():
        raise FileNotFoundError(f"Missing regression fixture: {name}")
    return directory
