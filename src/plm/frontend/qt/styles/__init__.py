"""Application-wide Qt stylesheet loading and customization."""

from pathlib import Path

from .tokens import COLORS


_STYLE_PATH = Path(__file__).with_name("app.qss")
def _load_qss():
    qss = _STYLE_PATH.read_text(encoding="utf-8")
    # Replace only named design tokens; longer names must precede prefixes.
    for name in sorted(COLORS, key=len, reverse=True):
        qss = qss.replace(f"${name}", COLORS[name])
    return qss


APP_QSS = _load_qss()


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
