"""Download the Lucide SVG assets used by the Qt front end.

Install the one script dependency first:
    uv pip install requests
"""

from pathlib import Path

import requests


BASE_URL = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons"
ICON_NAMES = (
    "layout-dashboard",
    "arrow-left",
    "panel-left",
    "x",
    "panel-bottom",
    "panel-right",
    "square-pen",
    "save",
    "file-text",
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
)
# Lucide renamed this icon upstream but the application keeps the requested
# stable asset filename.
UPSTREAM_NAMES = {
    "more-horizontal": "ellipsis",
    "trash-2": "trash",
}

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "src" / "plm" / "frontend" / "qt" / "assets" / "icons"


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with requests.Session() as session:
        for name in ICON_NAMES:
            upstream_name = UPSTREAM_NAMES.get(name, name)
            url = f"{BASE_URL}/{upstream_name}.svg"
            response = session.get(url, timeout=30)
            response.raise_for_status()
            if "<svg" not in response.text:
                raise ValueError(f"Downloaded content is not SVG: {url}")
            destination = OUTPUT_DIR / f"{name}.svg"
            destination.write_text(response.text, encoding="utf-8")
            print(f"downloaded {name}.svg")


if __name__ == "__main__":
    main()
