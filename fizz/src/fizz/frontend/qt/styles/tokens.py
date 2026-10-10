"""Fizz desktop tokens aligned with the current PLM Qt frontend."""

from pathlib import Path

BG_MAIN = "#FFFFFF"
BG_SIDEBAR = "#F6F7F9"
BG_SUBTLE = "#EEF0F4"
BG_HOVER = "#E1E5EB"
BORDER = "#E5E8ED"
TEXT_MAIN = "#23272F"
TEXT_SUB = "#626C7B"
TEXT_MUTED = "#656E7D"
PRIMARY = "#3B82F6"
PRIMARY_HOVER = "#2563EB"
PRIMARY_SOFT = "#E8F0FE"
DANGER = "#EF4444"
FONT_FAMILY = (
    '"Microsoft YaHei UI", "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif'
)
FONT_MONO = 'Consolas, "Cascadia Code", Menlo, monospace'
FONT_SIZE_BODY = 16
CONTROL_HEIGHT = 40
ICON_SIZE = 20
NAV_EXPANDED_WIDTH = 260
NAV_COLLAPSED_WIDTH = 56
PANEL_ANIMATION_DURATION = 200
ICON_DIR = Path(__file__).resolve().parents[1] / "assets/icons"

QSS_TOKENS = {
    "bg_main": BG_MAIN,
    "bg_sidebar": BG_SIDEBAR,
    "bg_subtle": BG_SUBTLE,
    "bg_hover": BG_HOVER,
    "border": BORDER,
    "text_main": TEXT_MAIN,
    "text_sub": TEXT_SUB,
    "text_muted": TEXT_MUTED,
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_soft": PRIMARY_SOFT,
    "danger": DANGER,
    "font_family": FONT_FAMILY,
    "font_mono": FONT_MONO,
    "font_size_body": f"{FONT_SIZE_BODY}px",
}
