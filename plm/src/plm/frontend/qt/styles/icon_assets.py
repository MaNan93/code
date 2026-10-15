"""Cache theme-colored SVG files for Qt stylesheet image URLs."""

from functools import lru_cache
from pathlib import Path
from tempfile import TemporaryDirectory


@lru_cache(maxsize=1)
def _cache_directory():
    return TemporaryDirectory(prefix="plm-theme-icons-")


@lru_cache(maxsize=16)
def themed_icon_path(source, color):
    source = Path(source)
    target = Path(_cache_directory().name) / f"{source.stem}-{color.lstrip('#')}.svg"
    svg = source.read_text(encoding="utf-8").replace("currentColor", color)
    target.write_text(svg, encoding="utf-8")
    return target.as_posix()
