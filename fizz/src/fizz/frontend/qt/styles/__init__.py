"""Load the standalone stylesheet; Fizz does not depend on PLM."""

from pathlib import Path

from .tokens import QSS_TOKENS


def build_stylesheet(base_px=None):
    tokens = dict(QSS_TOKENS)
    if base_px is not None:
        tokens["font_size_body"] = f"{int(base_px)}px"
    sheet = Path(__file__).with_name("app.qss").read_text(encoding="utf-8")
    for name in sorted(tokens, key=len, reverse=True):
        sheet = sheet.replace(f"${name}", tokens[name])
    return sheet


APP_QSS = build_stylesheet()
