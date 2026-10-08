"""Modern desktop design tokens shared by QSS, painters and widgets.

Controls use a 40 px grid; every 18 px Lucide glyph occupies a centered 20 px slot.
"""

from pathlib import Path
import sys

PRIMARY = "#3B82F6"
PRIMARY_HOVER = "#2563EB"
PRIMARY_LIGHT = "#F2F4F7"
BG_MAIN = "#FFFFFF"
BG_SURFACE = "#FFFFFF"
BG_SIDEBAR = "#F7F8FA"
BG_SIDEBAR_INACTIVE = "#F7F8FA"
BG_SUBTLE = "#F2F4F7"
BG_ALTERNATE = "#FAFBFC"
BG_HOVER = "#E9EDF2"
BG_FOCUS = "#DDE3EB"
BG_ARTIFACTS = "#F5F4F1"
BORDER_ARTIFACTS = "#DDD9D1"
NAV_ITEM_GAP = 2
INFO_BG, INFO_TEXT = "#DBEAFE", "#1D4ED8"
SUCCESS_BG, SUCCESS_TEXT = "#DCFCE7", "#15803D"
WARNING_BG, WARNING_TEXT = "#FEF3C7", "#B45309"
DANGER_BG, DANGER_TEXT = "#FEE2E2", "#B91C1C"
BORDER = "#EEF0F3"
BORDER_HOVER = "#CBD5E1"
BORDER_FOCUS = "#3B82F6"
TEXT_MAIN = "#1F2328"
TEXT_SUB = "#64748B"
TEXT_HEADER = "#475569"
TEXT_MUTED = "#94A3B8"
DANGER = "#EF4444"
SUCCESS = "#10B981"

FONT_UI_PRIMARY = {"win32": "Segoe UI", "darwin": ".AppleSystemUIFont"}.get(sys.platform, "Roboto")
FONT_FAMILY = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif'
FONT_CODE_PRIMARY = {"win32": "Consolas", "darwin": "Menlo"}.get(sys.platform, "JetBrains Mono")
FONT_MONO = f'"{FONT_CODE_PRIMARY}", "Cascadia Code", "Courier New", monospace'
ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
UI_CONTENT_SCALE = 1.2
FONT_SCALE = 1.0
CONTROL_HEIGHT = 40
LINE_HEIGHT = 24
CONTROL_PADDING_Y = 8
CONTROL_PADDING_X = 16
ICON_TEXT_GAP = 6
MENU_RADIUS = 14
MENU_PADDING = 8
MENU_GAP = 4
MENU_ICON_TEXT_GAP = 10
MENU_ITEM_PADDING_X = 12
MENU_MIN_WIDTH = 170
MENU_SHADOW_MARGIN = 7
MENU_SHADOW_SPREAD = 5
MENU_SHADOW_OFFSET = (0, 4 / 3)
MENU_SHADOW_LAYER_ALPHA = 2
FONT_WEIGHT_NORMAL = 400
FONT_WEIGHT_MEDIUM = 500
FONT_WEIGHT_SEMIBOLD = 600


def scale_content_size(size):
    """Scale glyphs without changing the window's layout grid."""
    return round(size * UI_CONTENT_SCALE)


def scale_font_size(size):
    """Compatibility helper for the shared UI font size."""
    return FONT_SIZE_BODY


def shrink_font_size(size):
    """Compatibility helper for the shared UI font size."""
    return FONT_SIZE_BODY


FONT_SIZE_BODY = 16
FONT_SIZE_SM = FONT_SIZE_BODY
FONT_SIZE_LG = FONT_SIZE_BODY
ICON_SIZE = 20
ICON_SIZE_SM = ICON_SIZE
ICON_GLYPH_SIZE = 18
ICON_STROKE_WIDTH = 2
ICON_BUTTON_SIZE = 32

RADIUS_CHIP = CONTROL_HEIGHT // 2
RADIUS_CONTROL = 12
RADIUS_CARD = 16
RADIUS_HOVER = CONTROL_HEIGHT // 2
RADIUS_WINDOW = 16

SPACING_XS = 4
SPACING_SM = 8
SPACING_MD = 12
SPACING_LG = 16
SPACING_XL = 24

SHADOW_SM = {"blur_radius": 4, "offset": (0, 1), "rgba": (0, 0, 0, 20)}

QSS_TOKENS = {
    "control_height": f"{CONTROL_HEIGHT}px",
    "control_padding_y": f"{CONTROL_PADDING_Y}px",
    "control_padding_x": f"{CONTROL_PADDING_X}px",
    "menu_radius": f"{MENU_RADIUS}px",
    "menu_padding": f"{MENU_PADDING}px",
    "menu_gap": f"{MENU_GAP}px",
    "menu_min_width": f"{MENU_MIN_WIDTH}px",
    "menu_item_padding_x": f"{MENU_ITEM_PADDING_X}px",
    "menu_outer_padding": f"{MENU_SHADOW_MARGIN + MENU_PADDING}px",
    "menu_bottom_padding": f"{MENU_SHADOW_MARGIN + MENU_PADDING - MENU_GAP}px",
    "icon_size": f"{ICON_SIZE}px",
    "icon_glyph_size": f"{ICON_GLYPH_SIZE}px",
    "icon_button_radius": f"{ICON_BUTTON_SIZE // 2}px",
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_light": PRIMARY_LIGHT,
    "bg_main": BG_MAIN,
    "bg_surface": BG_SURFACE,
    "bg_sidebar": BG_SIDEBAR,
    "bg_sidebar_inactive": BG_SIDEBAR_INACTIVE,
    "bg_subtle": BG_SUBTLE,
    "bg_alternate": BG_ALTERNATE,
    "bg_hover": BG_HOVER,
    "bg_focus": BG_FOCUS,
    "bg_artifacts": BG_ARTIFACTS,
    "border_artifacts": BORDER_ARTIFACTS,
    "info_bg": INFO_BG,
    "info_text": INFO_TEXT,
    "success_bg": SUCCESS_BG,
    "success_text": SUCCESS_TEXT,
    "warning_bg": WARNING_BG,
    "warning_text": WARNING_TEXT,
    "danger_bg": DANGER_BG,
    "danger_text": DANGER_TEXT,
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
    "radius_hover": f"{RADIUS_HOVER}px",
    "font_weight_normal": FONT_WEIGHT_NORMAL,
    "font_weight_medium": FONT_WEIGHT_MEDIUM,
    "font_weight_semibold": FONT_WEIGHT_SEMIBOLD,
    "spacing_xs": f"{SPACING_XS}px",
    "spacing_sm": f"{SPACING_SM}px",
    "spacing_md": f"{SPACING_MD}px",
    "spacing_lg": f"{SPACING_LG}px",
}
