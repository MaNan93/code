"""Application-wide Qt stylesheet loading."""

from pathlib import Path

from .tokens import FONT_FAMILY, get_qss_tokens

_STYLE_PATH = Path(__file__).with_name("app.qss")


def get_app_qss(theme="light"):
    qss = _STYLE_PATH.read_text(encoding="utf-8")
    tokens = get_qss_tokens(theme)
    for name in sorted(tokens, key=len, reverse=True):
        qss = qss.replace(f"${name}", str(tokens[name]))
    return qss


APP_QSS = get_app_qss()


__all__ = ["APP_QSS", "FONT_FAMILY", "get_app_qss"]
