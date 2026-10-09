"""Download unmodified official Lucide SVG assets used by the Qt front end."""

from pathlib import Path
from urllib.request import urlopen


BASE_URL = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons"
ICON_NAMES = (
    "layout-dashboard",
    "arrow-left",
    "arrow-right-left",
    "panel-left",
    "x",
    "panel-bottom",
    "panel-right",
    "square-pen",
    "save",
    "file-text",
    "file-code-corner",
    "file-braces-corner",
    "settings",
    "trash-2",
    "archive",
    "folder",
    "folder-open",
    "pin",
    "pencil",
    "refresh-cw",
    "git-compare",
    "search",
    "link",
    "file-x",
    "more-horizontal",
    "maximize",
    "rocket",
    "minus",
    "square",
    "copy",
    "chevron-down",
    "chevron-right",
    "tree-chevron-down",
)
# Lucide renamed this icon upstream but the application keeps the requested
# stable asset filename.
UPSTREAM_NAMES = {
    "more-horizontal": "ellipsis",
    "trash-2": "trash",
    "tree-chevron-down": "chevron-down",
}

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "src" / "plm" / "frontend" / "qt" / "assets" / "icons"


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in ICON_NAMES:
        upstream_name = UPSTREAM_NAMES.get(name, name)
        url = f"{BASE_URL}/{upstream_name}.svg"
        with urlopen(url, timeout=30) as response:
            svg = response.read().decode("utf-8")
        if "<svg" not in svg:
            raise ValueError(f"Downloaded content is not SVG: {url}")
        destination = OUTPUT_DIR / f"{name}.svg"
        destination.write_text(svg, encoding="utf-8", newline="\n")
        print(f"downloaded {name}.svg")


if __name__ == "__main__":
    main()
