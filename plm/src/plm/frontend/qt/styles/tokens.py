"""BeautifulUI design tokens shared by QSS and Qt widgets."""

from pathlib import Path
import sys

PRIMARY = "#3B82F6"
PRIMARY_HOVER = "#2563EB"
PRIMARY_LIGHT = "#DBEAFE"
BG_MAIN = "#FFFFFF"
BG_SURFACE = "#FFFFFF"
BG_SIDEBAR = "#F1F5F9"
BG_SIDEBAR_INACTIVE = "#F8FAFC"
BG_SUBTLE = "#F1F5F9"
BORDER = "#E2E8F0"
BORDER_HOVER = "#CBD5E1"
BORDER_FOCUS = "#3B82F6"
TEXT_MAIN = "#1E293B"
TEXT_SUB = "#64748B"
TEXT_HEADER = "#475569"
TEXT_MUTED = "#94A3B8"
DANGER = "#EF4444"
SUCCESS = "#10B981"

FONT_UI_PRIMARY = {"win32": "Segoe UI", "darwin": ".AppleSystemUIFont"}.get(sys.platform, "sans-serif")
FONT_FAMILY = f'"{FONT_UI_PRIMARY}", sans-serif'
FONT_CODE_PRIMARY = FONT_UI_PRIMARY
FONT_MONO = FONT_FAMILY
ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
UI_CONTENT_SCALE = 1.2
FONT_SCALE = 1.0
CONTROL_HEIGHT = 34


def scale_content_size(size):
    """Scale glyphs without changing the window's layout grid."""
    return round(size * UI_CONTENT_SCALE)


def scale_font_size(size):
    """Compatibility helper: all UI font sizes now resolve to 14 px."""
    return FONT_SIZE_BODY


def shrink_font_size(size):
    """Compatibility helper for the uniform 14 px font token."""
    return FONT_SIZE_BODY


FONT_SIZE_BODY = 14
FONT_SIZE_SM = FONT_SIZE_BODY
FONT_SIZE_LG = FONT_SIZE_BODY
ICON_SIZE = scale_content_size(18)
ICON_SIZE_SM = 14

RADIUS_CHIP = 6
RADIUS_CONTROL = 6
RADIUS_CARD = 10

SPACING_XS = 4
SPACING_SM = 8
SPACING_MD = 12
SPACING_LG = 16
SPACING_XL = 24

SHADOW_SM = {"blur_radius": 4, "offset": (0, 1), "rgba": (0, 0, 0, 20)}

QSS_TOKENS = {
    "control_height": f"{CONTROL_HEIGHT}px",
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_light": PRIMARY_LIGHT,
    "bg_main": BG_MAIN,
    "bg_surface": BG_SURFACE,
    "bg_sidebar": BG_SIDEBAR,
    "bg_sidebar_inactive": BG_SIDEBAR_INACTIVE,
    "bg_subtle": BG_SUBTLE,
    "border": BORDER,
    "border_hover": BORDER_HOVER,
    "border_focus": BORDER_FOCUS,
    "text_main": TEXT_MAIN,
    "text_sub": TEXT_SUB,
    "text_header": TEXT_HEADER,
    "text_muted": TEXT_MUTED,
    "danger": DANGER,
    "success": SUCCESS,
    "font_family": FONT_FAMILY,
    "font_mono": FONT_MONO,
    "font_size_body": f"{FONT_SIZE_BODY}px",
    "font_size_sm": f"{FONT_SIZE_SM}px",
    "font_size_lg": f"{FONT_SIZE_LG}px",
    "font_size_12": f"{shrink_font_size(12)}px",
    "font_size_13": f"{shrink_font_size(13)}px",
    "chevron_right_icon": (ICON_DIR / "chevron-right.svg").as_posix(),
    "chevron_down_icon": (ICON_DIR / "tree-chevron-down.svg").as_posix(),
    "radius_chip": f"{RADIUS_CHIP}px",
    "radius_control": f"{RADIUS_CONTROL}px",
    "radius_card": f"{RADIUS_CARD}px",
    "spacing_xs": f"{SPACING_XS}px",
    "spacing_sm": f"{SPACING_SM}px",
    "spacing_md": f"{SPACING_MD}px",
    "spacing_lg": f"{SPACING_LG}px",
}
