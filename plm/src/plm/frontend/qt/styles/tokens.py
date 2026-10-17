"""Modern desktop design tokens shared by QSS, painters and widgets.

Controls use a 32 px grid with 13 px text and 16 px Lucide icons.
"""

from pathlib import Path
import sys

# neutral ramp: slate surfaces and text, independent of the primary hue
N0 = "#FFFFFF"
N25 = "#F8FAFC"
N50 = "#F1F5F9"
N100 = "#E2E8F0"
N200 = "#CBD5E1"
N300 = "#94A3B8"
N400 = "#64748B"
# Small muted labels meet 4.5:1 on every resting surface.
N450 = "#475569"
N500 = "#334155"
N600 = "#1E293B"
N800 = "#0F172A"

# primary ramp
P50 = "#EEF2FF"
P100 = "#E0E7FF"
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
PRIMARY_ACTIVE = P700
PRIMARY_SOFT = P50
PRIMARY_PRESSED = P100
BG_MAIN = N0
BG_SURFACE = N0
# Light chrome; panel outlines preserve the boundary against white surfaces.
BG_SIDEBAR = N25
BG_SIDEBAR_HOVER = "#EDF2F7"
BG_CARD = N50
BG_SUBTLE = N50
BG_ALTERNATE = N25
BG_HOVER = N100
BG_SWITCH_HOVER = N50
BG_FOCUS = N100
# GitHub Primer light surfaces and foregrounds for the source viewer.
BG_ARTIFACTS = "#FFFFFF"
DIFF_ADDED_BG = "#E6FFEC"
DIFF_REMOVED_BG = "#FFF1F0"
DIFF_ADDED_GUTTER = "#CCFFD8"
DIFF_REMOVED_GUTTER = "#FFDEDB"
DIFF_HUNK_BG = "#DDF4FF"
BG_ARTIFACTS_HEADER = BG_SUBTLE
BORDER_ARTIFACTS = N200
TEXT_ARTIFACTS = "#1F2328"
TEXT_ARTIFACTS_MUTED = "#59636E"
ACCENT_ARTIFACTS = "#0969DA"
BG_DOCUMENT_CODE = "#182238"
TEXT_DOCUMENT_CODE = "#E2E8F0"
BORDER_DOCUMENT_CODE = "#334155"
BORDER = N100
# Outline of the top-level panels (config, output, settings, docs).
BORDER_PANEL = N200
BORDER_HOVER = N300
BORDER_CHECKBOX = N400
BORDER_FOCUS = P500
TEXT_MAIN = N800
TEXT_SUB = N500
TEXT_HEADER = N600
TEXT_MUTED = N450
TOOLTIP_BG = N800
TOOLTIP_TEXT = N0
TEXT_ON_PRIMARY = N0
TEXT_PRIMARY = PRIMARY

SYNTAX_COMMENT = "#57606A"
SYNTAX_KEYWORD = "#CF222E"
SYNTAX_PORT = "#953800"
SYNTAX_NUMBER = "#0550AE"
SYNTAX_STRING = "#0A3069"
SYNTAX_DIRECTIVE = SYNTAX_KEYWORD
TEXT_ON_LIGHT_SWATCH = "#000000"
TEXT_ON_DARK_SWATCH = N0
LANE_GRID_PALETTE = ("#4F46E5", "#0D9488", "#7C3AED", "#D97706", "#059669", "#E11D48")

NAV_ITEM_GAP = 2

FONT_UI_PRIMARY = {"win32": "Segoe UI", "darwin": ".AppleSystemUIFont"}.get(sys.platform, "Roboto")
FONT_FAMILY = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif'
FONT_CODE_PRIMARY = {"win32": "Consolas", "darwin": "Menlo"}.get(sys.platform, "JetBrains Mono")
FONT_MONO = f'"{FONT_CODE_PRIMARY}", "Cascadia Code", "Courier New", monospace'
ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
FONT_SCALE = 1.0
CONTROL_HEIGHT = 32
TITLEBAR_HEIGHT = 44
HEADER_HEIGHT = 40
TITLEBAR_BUTTON_WIDTH = 46
LOG_HEADER_HEIGHT = 32
LOG_STATUS_HEIGHT = 24
ARTIFACTS_TOOLBAR_HEIGHT = HEADER_HEIGHT
ARTIFACTS_BORDER_WIDTH = 1
NAV_EXPANDED_WIDTH = 260
NAV_COLLAPSED_WIDTH = 56
ARTIFACTS_DEFAULT_WIDTH = 380
ARTIFACTS_MIN_WIDTH = 300
PANEL_ANIMATION_DURATION = 200
LINE_HEIGHT = 20
CONTROL_PADDING_Y = 6
CONTROL_PADDING_X = 12
FIELD_PADDING_Y = 4
ICON_TEXT_GAP = 6
MENU_RADIUS = 6
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


FONT_SIZE_BODY = 13
FONT_SIZE_TITLE = 14
FONT_SIZE_SMALL = 12
FONT_SIZE_DOC_TITLE = 18
FONT_SIZE_DOC_SECTION = 15
FONT_SIZE_DOC_SUBSECTION = 14
ICON_SIZE = 16
ICON_GLYPH_SIZE = 16
ICON_BUTTON_SIZE = 28

RADIUS_CHIP = 4
RADIUS_CONTROL = 6
RADIUS_CARD = 16
RADIUS_HOVER = 6
RADIUS_WINDOW = 16

SPACING_XS = 4
SPACING_SM = 8
SPACING_MD = 12
SPACING_LG = 16
SPACING_XL = 24
SPLITTER_HANDLE_SIZE = 6
SPLITTER_HIGHLIGHT_SIZE = 2
TOAST_BOTTOM_MARGIN = 32
TOAST_FADE_IN = 150
TOAST_HOLD = 1800
TOAST_FADE_OUT = 200

FORM_FIELD_MAX_WIDTH = 360
FORM_LABEL_WIDTH = 140
FORM_MAX_WIDTH = 760
SETTINGS_MAX_WIDTH = 760
DOCS_MAX_WIDTH = 800
FORM_ACTION_WIDTH = 120
FORMATTER_MAX_WIDTH = SETTINGS_MAX_WIDTH
TAB_PADDING_X = SPACING_LG
TAB_INDICATOR_HEIGHT = 2
LANE_SWATCH_MAX_WIDTH = 200
STATUS_DOT_INSET = SPACING_SM
STATUS_DOT_RADIUS = 2.5
STATUS_TEXT_INSET = 10
STATUS_PADDING_Y = 3
PALETTE_ROW_SPACING = 6
CHECKBOX_INDICATOR_SIZE = ICON_SIZE
CHECKBOX_BORDER_WIDTH = 1
CHECKBOX_INDICATOR_CONTENT_SIZE = CHECKBOX_INDICATOR_SIZE - 2 * CHECKBOX_BORDER_WIDTH

# Keep nav icons centered on the collapsed rail in both states.
NAV_ICON_INSET = (NAV_COLLAPSED_WIDTH - ICON_SIZE) // 2 - SPACING_MD

SHADOW_SM = {"blur_radius": 4, "offset": (0, 1), "rgba": (0, 0, 0, 20)}

QSS_TOKENS = {
    "control_height": f"{CONTROL_HEIGHT}px",
    "titlebar_button_width": f"{TITLEBAR_BUTTON_WIDTH}px",
    "control_padding_y": f"{CONTROL_PADDING_Y}px",
    "control_padding_x": f"{CONTROL_PADDING_X}px",
    "field_padding_y": f"{FIELD_PADDING_Y}px",
    "nav_icon_inset": f"{NAV_ICON_INSET}px",
    "menu_radius": f"{MENU_RADIUS}px",
    "menu_padding": f"{MENU_PADDING}px",
    "menu_gap": f"{MENU_GAP}px",
    "menu_min_width": f"{MENU_MIN_WIDTH}px",
    "menu_item_padding_x": f"{MENU_ITEM_PADDING_X}px",
    "menu_outer_padding": f"{MENU_SHADOW_MARGIN + MENU_PADDING}px",
    "menu_bottom_padding": f"{MENU_SHADOW_MARGIN + MENU_PADDING - MENU_GAP}px",
    "icon_size": f"{ICON_SIZE}px",
    "icon_button_size": f"{ICON_BUTTON_SIZE}px",
    "icon_glyph_size": f"{ICON_GLYPH_SIZE}px",
    "primary": PRIMARY,
    "primary_hover": PRIMARY_HOVER,
    "primary_soft": PRIMARY_SOFT,
    "primary_pressed": PRIMARY_PRESSED,
    "bg_main": BG_MAIN,
    "bg_surface": BG_SURFACE,
    "bg_sidebar": BG_SIDEBAR,
    "bg_sidebar_hover": BG_SIDEBAR_HOVER,
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
    "border_panel": BORDER_PANEL,
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
    "font_size_title": f"{FONT_SIZE_TITLE}px",
    "font_size_small": f"{FONT_SIZE_SMALL}px",
    "tab_padding_x": f"{TAB_PADDING_X}px",
    "tab_indicator_height": f"{TAB_INDICATOR_HEIGHT}px",
    "status_padding_y": f"{STATUS_PADDING_Y}px",
    "checkbox_indicator_content_size": f"{CHECKBOX_INDICATOR_CONTENT_SIZE}px",
    "checkbox_border_width": f"{CHECKBOX_BORDER_WIDTH}px",
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

# Constants above remain the light-theme compatibility API. Painters resolve
# roles at paint time; QSS receives a fresh snapshot of the selected theme.
LIGHT_COLORS = {
    name.lower(): value for name, value in list(globals().items())
    if name.startswith(("BG_", "BORDER", "TEXT_", "PRIMARY", "TOOLTIP_",
                        "DIFF_", "SYNTAX_", "ACCENT_")) and isinstance(value, str)
}
for _semantic in SEMANTIC_COLORS:
    for _suffix in ("", "_bg", "_text"):
        _role = _semantic + _suffix
        LIGHT_COLORS[_role] = globals()[_role.upper()]

DARK_COLORS = {
    "bg_main": "#121316", "bg_surface": "#1A1B20",
    "bg_sidebar": "#0E0F12", "bg_sidebar_hover": "#1D1E24",
    "bg_card": "#22242B", "bg_subtle": "#22242B",
    "bg_alternate": "#18191E", "bg_hover": "#2B2E38",
    "bg_switch_hover": "#2B2E38", "bg_focus": "#323642",
    # Keep white button labels readable, including their brighter hover state.
    "primary": "#605CE5", "primary_hover": "#6763DF",
    "primary_active": "#4F46E5",
    "primary_soft": "#25283D", "primary_pressed": "#323642",
    "border": "#282B34", "border_panel": "#282B34",
    "border_hover": "#3E4351", "border_focus": "#818CF8",
    "border_checkbox": "#747D8F",
    "text_main": "#F3F4F6", "text_sub": "#B4B9C5",
    "text_header": "#E5E7EB", "text_muted": "#A1A6B2",
    "text_on_primary": "#FFFFFF", "text_primary": "#A5B4FC",
    "text_on_light_swatch": "#000000", "text_on_dark_swatch": "#FFFFFF",
    "tooltip_bg": "#2B2E38", "tooltip_text": "#F3F4F6",
    "bg_artifacts": "#16171C", "bg_artifacts_header": "#22242B",
    "border_artifacts": "#2A2D36", "text_artifacts": "#F3F4F6",
    "text_artifacts_muted": "#B4B9C5", "accent_artifacts": "#A5B4FC",
    "diff_added_bg": "#12261E", "diff_removed_bg": "#3B1C1D",
    "diff_added_gutter": "#17392A", "diff_removed_gutter": "#54272A",
    "diff_hunk_bg": "#172B42",
    "bg_document_code": "#16171C", "text_document_code": "#E5E7EB",
    "border_document_code": "#2A2D36",
    "syntax_comment": "#94A3B8", "syntax_keyword": "#FF7B72",
    "syntax_port": "#FFA657", "syntax_number": "#79C0FF",
    "syntax_string": "#A5D6FF", "syntax_directive": "#FF7B72",
    "info_bg": "#12253D", "info": "#60A5FA", "info_text": "#60A5FA",
    "success_bg": "#0D2E23", "success": "#10B981", "success_text": "#34D399",
    "warning_bg": "#332408", "warning": "#F59E0B", "warning_text": "#FBBF24",
    "danger_bg": "#351416", "danger": "#EF4444", "danger_text": "#F87171",
}
if LIGHT_COLORS.keys() != DARK_COLORS.keys():
    raise ValueError("Light and dark themes must define the same color roles")
QSS_TOKENS.update(LIGHT_COLORS)

_active_theme = "light"


def normalize_theme(theme):
    return theme if theme in ("light", "dark") else "light"


def set_active_theme(theme):
    global _active_theme
    _active_theme = normalize_theme(theme)


def get_active_theme():
    return _active_theme


def get_theme_colors(theme=None):
    name = get_active_theme() if theme is None else normalize_theme(theme)
    return dict(DARK_COLORS if name == "dark" else LIGHT_COLORS)


def get_theme_color(role):
    return (DARK_COLORS if _active_theme == "dark" else LIGHT_COLORS)[role.lower()]


def get_qss_tokens(theme="light"):
    from .icon_assets import themed_icon_path
    colors = get_theme_colors(theme)
    return {**QSS_TOKENS, **colors,
            "splitter_handle_size": f"{SPLITTER_HANDLE_SIZE}px",
            "chevron_right_icon": themed_icon_path(ICON_DIR / "chevron-right.svg", colors["text_sub"]),
            "chevron_down_icon": themed_icon_path(ICON_DIR / "tree-chevron-down.svg", colors["text_sub"]),
            "checkmark_icon": themed_icon_path(ICON_DIR / "check.svg", colors["text_on_primary"]),
            "checkmark_disabled_icon": themed_icon_path(ICON_DIR / "check.svg", colors["text_muted"])}
