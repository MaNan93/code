"""Application-wide Qt stylesheet loading."""

from pathlib import Path

from .tokens import FONT_FAMILY, QSS_TOKENS

_STYLE_PATH = Path(__file__).with_name("app.qss")


def _render_qss():
    qss = _STYLE_PATH.read_text(encoding="utf-8")
    tokens = dict(QSS_TOKENS)
    for name in sorted(tokens, key=len, reverse=True):
        qss = qss.replace(f"${name}", str(tokens[name]))
    return qss


APP_QSS = _render_qss()


__all__ = ["APP_QSS", "FONT_FAMILY"]
