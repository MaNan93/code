#!/usr/bin/env python3
# One-shot visual polish for the BeautifulUI r1 screenshot review.
from pathlib import Path

ROOT = Path("src/plm/frontend/qt")


def replace(rel, old, new, count=-1):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"pattern not found: {rel}: {old[:80]!r}")
    path.write_text(text.replace(old, new, count), encoding="utf-8")

# Formatter editors must fit cleanly inside the 40 px table rows.
replace(
    "views/settings_page.py",
    "                    control = QtWidgets.QComboBox()\n                    control.addItem(f\"{default_value} (default)\", default_value)",
    "                    control = QtWidgets.QComboBox()\n                    control.setFixedHeight(36)\n                    control.addItem(f\"{default_value} (default)\", default_value)",
)
replace(
    "views/settings_page.py",
    "                    control = QtWidgets.QLineEdit()\n                    control.setToolTip(f\"PLM 默认值：{default_value}\")",
    "                    control = QtWidgets.QLineEdit()\n                    control.setFixedHeight(36)\n                    control.setToolTip(f\"PLM 默认值：{default_value}\")",
)

# Lane brush chip follows the same compact token system instead of the old pill outline.
replace(
    "widgets/lanegrid.py",
    "from plm.frontend.qt.styles.tokens import (\n    BG_MAIN, BG_SUBTLE, BG_SURFACE, DANGER, PRIMARY, SUCCESS, TEXT_MAIN, TEXT_MUTED, TEXT_SUB,\n)",
    "from plm.frontend.qt.styles.tokens import (\n    BG_MAIN, BG_SUBTLE, BG_SURFACE, DANGER, FONT_SIZE_SM, PRIMARY, PRIMARY_HOVER,\n    RADIUS_CHIP, SHADOW_SM, SPACING_LG, SPACING_MD, SPACING_XS, SUCCESS,\n    TEXT_MAIN, TEXT_MUTED, TEXT_SUB,\n)",
)
replace(
    "widgets/lanegrid.py",
    "            # Pill shape: fully rounded ends, border, active gets inner ring.\n            # Scale padding/radius/font from the 13 px baseline.\n            border_color = TEXT if is_active else BORDER\n            outline = (\n                f\"border: {int(2 * scale)}px solid {border_color};\" if is_active\n                else f\"border: {int(1 * scale)}px solid {border_color};\"\n            )",
    "            border_color = PRIMARY_HOVER if is_active else BORDER\n            outline = (\n                f\"border: {int(2 * scale)}px solid {border_color};\" if is_active\n                else f\"border: {int(1 * scale)}px solid {border_color};\"\n            )",
)
replace(
    "widgets/lanegrid.py",
    "                f\"  font-size: {12.5 * scale:.1f}px;\"\n                f\"  font-weight: 600;\"\n                f\"  border-radius: {int(14 * scale)}px;\"\n                # Horizontal padding must be >= the border-radius, otherwise\n                # the pill's rounded ends bite into the top/bottom of the\n                # first/last character before the flat padding band starts.\n                f\"  padding: {int(5 * scale)}px {int(15 * scale)}px;\"",
    "                f\"  font-size: {FONT_SIZE_SM * scale:.1f}px;\"\n                f\"  font-weight: 600;\"\n                f\"  border-radius: {int(RADIUS_CHIP * scale)}px;\"\n                f\"  padding: {int(SPACING_XS * scale)}px {int(SPACING_MD * scale)}px;\"",
)
replace(
    "widgets/lanegrid.py",
    "            btn.setMinimumHeight(int(30 * scale))\n            add_shadow(btn, blur=int(8 * scale), offset=(0, int(1 * scale)), alpha=45)",
    "            btn.setMinimumHeight(int((SPACING_LG * 2) * scale))\n            add_shadow(\n                btn,\n                blur=int(SHADOW_SM[\"blur_radius\"] * scale),\n                offset=(0, int(SHADOW_SM[\"offset\"][1] * scale)),\n                alpha=SHADOW_SM[\"rgba\"][3],\n            )",
)

# Documentation browser becomes a proper surface card instead of the native square frame.
qss = ROOT / "styles/app.qss"
text = qss.read_text(encoding="utf-8")
anchor = "QLabel#PlaceholderDescription { color: $text_sub; font-size: $font_size_body; }\n"
block = """QLabel#PlaceholderDescription { color: $text_sub; font-size: $font_size_body; }\nQTextBrowser#DocumentationBrowser {\n    background-color: $bg_surface;\n    color: $text_main;\n    border: 1px solid $border;\n    border-radius: $radius_card;\n    padding: $spacing_xs;\n}\n"""
if anchor not in text:
    raise RuntimeError("DocumentationBrowser QSS anchor missing")
qss.write_text(text.replace(anchor, block, 1), encoding="utf-8")

print("BeautifulUI screenshot polish applied")
