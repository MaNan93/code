"""BeautifulUI design tokens shared by QSS and Qt widgets."""

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

FONT_FAMILY = ('"Inter", "Microsoft YaHei UI", "PingFang SC", '
               '"Noto Sans CJK SC", "SimHei", "SimSun", sans-serif')
FONT_MONO = '"JetBrains Mono", "Consolas", "Courier New", monospace'
UI_CONTENT_SCALE = 1.2


def scale_content_size(size):
    """Scale fonts and glyphs without changing the window's layout grid."""
    return round(size * UI_CONTENT_SCALE)


FONT_SIZE_BODY = scale_content_size(13)
FONT_SIZE_SM = scale_content_size(12)
FONT_SIZE_LG = scale_content_size(15)
ICON_SIZE = scale_content_size(18)
ICON_SIZE_SM = scale_content_size(16)

RADIUS_CHIP = 6
RADIUS_CONTROL = 8
RADIUS_CARD = 10

SPACING_XS = 4
SPACING_SM = 8
SPACING_MD = 12
SPACING_LG = 16
SPACING_XL = 24

SHADOW_SM = {"blur_radius": 4, "offset": (0, 1), "rgba": (0, 0, 0, 20)}
SHADOW_MD = {"blur_radius": 8, "offset": (0, 2), "rgba": (0, 0, 0, 30)}
SHADOW_LG = {"blur_radius": 12, "offset": (0, 4), "rgba": (0, 0, 0, 50)}

QSS_TOKENS = {
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
    "radius_chip": f"{RADIUS_CHIP}px",
    "radius_control": f"{RADIUS_CONTROL}px",
    "radius_card": f"{RADIUS_CARD}px",
    "spacing_xs": f"{SPACING_XS}px",
    "spacing_sm": f"{SPACING_SM}px",
    "spacing_md": f"{SPACING_MD}px",
    "spacing_lg": f"{SPACING_LG}px",
}
