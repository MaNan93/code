"""Application-wide Qt stylesheet loading and customization."""

from pathlib import Path

from .tokens import COLORS


_STYLE_PATH = Path(__file__).with_name("app.qss")
_CJK_FONT_FALLBACKS = (
    "Microsoft YaHei UI",
    "PingFang SC",
    "Noto Sans CJK SC",
    "SimHei",
    "SimSun",
)


def _load_qss():
    qss = _STYLE_PATH.read_text(encoding="utf-8")
    # Replace only named design tokens; longer names must precede prefixes.
    for name in sorted(COLORS, key=len, reverse=True):
        qss = qss.replace(f"${name}", COLORS[name])
    return qss


APP_QSS = _load_qss()


def _font_family_stack(font_family):
    """Put the user font first while retaining CJK glyph fallbacks."""
    requested = (font_family or "Microsoft YaHei UI").replace('"', "").strip()
    families = (requested, *_CJK_FONT_FALLBACKS)
    seen = set()
    ordered = []
    for family in families:
        key = family.casefold()
        if family and key not in seen:
            seen.add(key)
            ordered.append(f'"{family}"')
    ordered.append("sans-serif")
    return ", ".join(ordered)


def build_app_stylesheet(font_family, font_size):
    """Return the shared stylesheet with user font preferences applied."""
    family_stack = _font_family_stack(font_family)
    size = int(font_size or 13)
    return APP_QSS.replace(
        'font-family: "Microsoft YaHei UI", "Segoe UI", "PingFang SC", sans-serif;',
        f"font-family: {family_stack};",
        1,
    ).replace("font-size: 13px;", f"font-size: {size}px;", 1)


__all__ = ["APP_QSS", "build_app_stylesheet"]
