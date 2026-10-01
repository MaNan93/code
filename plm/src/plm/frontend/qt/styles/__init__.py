"""Application-wide Qt stylesheet loading and customization."""

from pathlib import Path


_STYLE_PATH = Path(__file__).with_name("app.qss")
APP_QSS = _STYLE_PATH.read_text(encoding="utf-8")


def build_app_stylesheet(font_family, font_size):
    """Return the shared stylesheet with user font preferences applied."""
    safe_family = (font_family or "Microsoft YaHei UI").replace('"', "")
    size = int(font_size or 13)
    return APP_QSS.replace(
        'font-family: "Microsoft YaHei UI", "Segoe UI", "PingFang SC", sans-serif;',
        f'font-family: "{safe_family}", "Segoe UI", "PingFang SC", sans-serif;',
        1,
    ).replace("font-size: 13px;", f"font-size: {size}px;", 1)


__all__ = ["APP_QSS", "build_app_stylesheet"]
