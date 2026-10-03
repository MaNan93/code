"""Application-wide Qt stylesheet loading and customization."""

from pathlib import Path

from .tokens import FONT_FAMILY, QSS_TOKENS

_STYLE_PATH = Path(__file__).with_name("app.qss")
_CJK_FONT_FALLBACKS = (
    "Microsoft YaHei UI",
    "PingFang SC",
    "Noto Sans CJK SC",
    "SimHei",
    "SimSun",
)


def _font_family_stack(font_family):
    requested = (font_family or "Inter").replace('"', "").strip()
    families = (requested, "Inter", *_CJK_FONT_FALLBACKS)
    seen = set()
    ordered = []
    for family in families:
        key = family.casefold()
        if family and key not in seen:
            seen.add(key)
            ordered.append(f'"{family}"')
    ordered.append("sans-serif")
    return ", ".join(ordered)


def _render_qss(overrides=None):
    qss = _STYLE_PATH.read_text(encoding="utf-8")
    tokens = dict(QSS_TOKENS)
    if overrides:
        tokens.update(overrides)
    for name in sorted(tokens, key=len, reverse=True):
        qss = qss.replace(f"${name}", str(tokens[name]))
    return qss


APP_QSS = _render_qss()


def build_app_stylesheet(font_family, font_size):
    size = int(font_size or 13)
    return _render_qss({
        "font_family": _font_family_stack(font_family),
        "font_size_body": f"{size}px",
    })


__all__ = ["APP_QSS", "build_app_stylesheet", "FONT_FAMILY"]
