"""Modern desktop design tokens shared by QSS, painters and widgets.

Controls use a 40 px grid; every 18 px Lucide glyph occupies a centered 20 px slot.
"""

from pathlib import Path
import sys

# neutral ramp: greys carry a little of the primary hue so the chrome,
# secondary text and the icons tinted with it read as one family
N0 = "#FFFFFF"
N25 = "#F8F9FE"
N50 = "#EEF1FB"
N100 = "#E4E8F7"
N200 = "#D5DBF0"
N300 = "#BCC5E3"
N400 = "#8A91B4"
# N400 is too light for 16 px text; N450 meets 4.5:1 on all resting surfaces.
N450 = "#5C638B"
N500 = "#575E87"
N600 = "#444B72"
N800 = "#1B1F3B"

# primary ramp
P50 = "#E7E9FF"
P100 = "#D4D8FF"
P500 = "#4F46E5"
P600 = "#4338CA"
P700 = "#3730A3"

# semantic pairs (background, icon, text)
SEMANTIC_COLORS = {
    "info": ("#E0E7FF", P700, P700),
    "success": ("#DCFCE7", "#16A34A", "#15803D"),
    "warning": ("#FEF3C7", "#B45309", "#B45309"),
    "danger": ("#FEE2E2", "#EF4444", "#B91C1C"),
}
INFO_BG, INFO, INFO_TEXT = SEMANTIC_COLORS["info"]
SUCCESS_BG, SUCCESS, SUCCESS_TEXT = SEMANTIC_COLORS["success"]
WARNING_BG, WARNING, WARNING_TEXT = SEMANTIC_COLORS["warning"]
DANGER_BG, DANGER, DANGER_TEXT = SEMANTIC_COLORS["danger"]

# derived roles
PRIMARY = P500
PRIMARY_HOVER = P600
PRIMARY_SOFT = P50
PRIMARY_PRESSED = P100
BG_MAIN = N0
BG_SURFACE = N0
BG_SIDEBAR = N50
BG_CARD = N50
BG_SUBTLE = N100
BG_ALTERNATE = N25
BG_HOVER = N200
BG_SWITCH_HOVER = "#E9ECF9"
BG_FOCUS = N200
# GitHub Primer light surfaces and foregrounds for the source viewer.
BG_ARTIFACTS = "#FFFFFF"
DIFF_ADDED_BG = "#E6FFEC"
DIFF_REMOVED_BG = "#FFEBE9"
DIFF_ADDED_GUTTER = "#CCFFD8"
DIFF_REMOVED_GUTTER = "#FFD7D5"
DIFF_HUNK_BG = "#DDF4FF"
BG_ARTIFACTS_HEADER = "#F6F8FA"
BORDER_ARTIFACTS = "#D1D9E0"
TEXT_ARTIFACTS = "#1F2328"
TEXT_ARTIFACTS_MUTED = "#59636E"
ACCENT_ARTIFACTS = "#0969DA"
BORDER = "#DCE1F2"
BORDER_HOVER = N300
BORDER_FOCUS = P500
TEXT_MAIN = N800
TEXT_SUB = N500
TEXT_HEADER = "#3B4268"
TEXT_MUTED = N450
TOOLTIP_BG = N800
TOOLTIP_TEXT = N0

NAV_ITEM_GAP = 2

FONT_UI_PRIMARY = {"win32": "Segoe UI", "darwin": ".AppleSystemUIFont"}.get(sys.platform, "Roboto")
FONT_FAMILY = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif'
FONT_CODE_PRIMARY = {"win32": "Consolas", "darwin": "Menlo"}.get(sys.platform, "JetBrains Mono")
FONT_MONO = f'"{FONT_CODE_PRIMARY}", "Cascadia Code", "Courier New", monospace'
ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
UI_CONTENT_SCALE = 1.2
FONT_SCALE = 1.0
CONTROL_HEIGHT = 40
TITLEBAR_HEIGHT = 44
HEADER_HEIGHT = 48
TITLEBAR_BUTTON_WIDTH = 46
TITLEBAR_CONTROLS_WIDTH = 3 * TITLEBAR_BUTTON_WIDTH
LOG_HEADER_HEIGHT = 32
LOG_STATUS_HEIGHT = 24
ARTIFACTS_TOOLBAR_HEIGHT = HEADER_HEIGHT
ARTIFACTS_BORDER_WIDTH = 1
NAV_EXPANDED_WIDTH = 260
NAV_COLLAPSED_WIDTH = 56
ARTIFACTS_DEFAULT_WIDTH = 380
ARTIFACTS_MIN_WIDTH = 300
PANEL_ANIMATION_DURATION = 200
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


FONT_SIZE_BODY = 16
ICON_SIZE = 20
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

# Keep nav icons centered on the collapsed rail in both states.
NAV_ICON_INSET = (NAV_COLLAPSED_WIDTH - ICON_SIZE) // 2 - SPACING_MD

SHADOW_SM = {"blur_radius": 4, "offset": (0, 1), "rgba": (0, 0, 0, 20)}

QSS_TOKENS = {
    "control_height": f"{CONTROL_HEIGHT}px",
    "titlebar_button_width": f"{TITLEBAR_BUTTON_WIDTH}px",
    "control_padding_y": f"{CONTROL_PADDING_Y}px",
    "control_padding_x": f"{CONTROL_PADDING_X}px",
    "nav_icon_inset": f"{NAV_ICON_INSET}px",
    "menu_radius": f"{MENU_RADIUS}px",
    "menu_padding": f"{MENU_PADDING}px",
    "menu_gap": f"{MENU_GAP}px",
    "menu_min_width": f"{MENU_MIN_WIDTH}px",
    "menu_item_padding_x": f"{MENU_ITEM_PADDING_X}px",
    "menu_outer_padding": f"{MENU_SHADOW_MARGIN + MENU_PADDING}px",
    "menu_bottom_padding": f"{MENU_SHADOW_MARGIN + MENU_PADDING - MENU_GAP}px",
    "icon_size": f"{ICON_SIZE}px",
    "icon_glyph_size": f"{ICON_GLYPH_SIZE}px",
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_soft": PRIMARY_SOFT,
    "primary_pressed": PRIMARY_PRESSED,
    "bg_main": BG_MAIN,
    "bg_surface": BG_SURFACE,
    "bg_sidebar": BG_SIDEBAR,
    "bg_card": BG_CARD,
    "bg_subtle": BG_SUBTLE,
    "bg_alternate": BG_ALTERNATE,
    "bg_hover": BG_HOVER,
    "bg_focus": BG_FOCUS,
    "bg_artifacts": BG_ARTIFACTS,
    "bg_artifacts_header": BG_ARTIFACTS_HEADER,
    "border_artifacts": BORDER_ARTIFACTS,
    "artifacts_border_width": f"{ARTIFACTS_BORDER_WIDTH}px",
    "text_artifacts": TEXT_ARTIFACTS,
    "text_artifacts_muted": TEXT_ARTIFACTS_MUTED,
    "accent_artifacts": ACCENT_ARTIFACTS,
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
    "tooltip_bg": TOOLTIP_BG,
    "tooltip_text": TOOLTIP_TEXT,
    "danger": DANGER,
    "success": SUCCESS,
    "font_family": FONT_FAMILY,
    "font_mono": FONT_MONO,
    "font_size_body": f"{FONT_SIZE_BODY}px",
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
