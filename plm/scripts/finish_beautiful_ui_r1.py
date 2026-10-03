#!/usr/bin/env python3
"""Finish tokenization after the one-shot BeautifulUI patch and audit literals."""
# Trigger the final r1 visual cleanup pass after workflow validation was tightened.
from pathlib import Path
import re

ROOT = Path("src/plm/frontend/qt")


def update(rel, transform):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8")
    new = transform(text)
    if new == text:
        raise RuntimeError(f"cleanup produced no change for {rel}")
    path.write_text(new, encoding="utf-8")


def add_import(text, anchor, import_line):
    if import_line in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor missing: {anchor!r}")
    return text.replace(anchor, anchor + import_line, 1)


def main_window(text):
    text = add_import(
        text,
        "from plm.frontend.qt.styles import APP_QSS\n",
        "from plm.frontend.qt.styles.tokens import PRIMARY\n",
    )
    return text.replace('load_lucide_icon("layout-dashboard", "#1677FF")', 'load_lucide_icon("layout-dashboard", PRIMARY)')


def docs(text):
    text = add_import(
        text,
        "from PyQt5 import QtCore, QtGui, QtWidgets\n",
        "from plm.frontend.qt.styles.tokens import (\n"
        "    BG_SUBTLE, BORDER, FONT_MONO, TEXT_MAIN, TEXT_MUTED, TEXT_SUB,\n"
        ")\n",
    )
    start = text.index("        self.doc_browser.document().setDefaultStyleSheet(\n")
    end = text.index("        )\n", start) + len("        )\n")
    block = '''        doc_css = """\n        h1 {{ color: {text_main}; font-size: 16px; font-weight: 600; margin: 16px 0 8px 0; }}\n        h2, h3 {{ color: {text_main}; font-size: 14px; font-weight: 600; margin: 12px 0 6px 0; }}\n        p {{ color: {text_main}; font-size: 13px; line-height: 160%; margin: 4px 0 10px 0; }}\n        table {{ border-collapse: collapse; border: 1px solid {border}; border-radius: 6px; }}\n        th {{ background-color: {bg_subtle}; color: {text_main}; font-size: 13px; font-weight: 600; padding: 8px 12px; border-bottom: 1px solid {border}; }}\n        td {{ color: {text_main}; font-size: 13px; font-weight: 400; padding: 8px 12px; }}\n        """.format(text_main=TEXT_MAIN, border=BORDER, bg_subtle=BG_SUBTLE)\n        self.doc_browser.document().setDefaultStyleSheet(doc_css)\n'''
    text = text[:start] + block + text[end:]
    replacements = {
        'QtGui.QColor("#1A1A1A")': 'QtGui.QColor(TEXT_MAIN)',
        'QtGui.QColor("#8C92A4")': 'QtGui.QColor(TEXT_MUTED)',
        'QtGui.QColor("#EAEAEA")': 'QtGui.QColor(BORDER)',
        'QtGui.QColor("#F0F2F5")': 'QtGui.QColor(BG_SUBTLE)',
        '["Consolas", "Courier New", "monospace"]': '["JetBrains Mono", "Consolas", "Courier New", "monospace"]',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def hover(text):
    text = add_import(
        text,
        "from PyQt5 import QtCore, QtGui, QtWidgets\n",
        "from plm.frontend.qt.styles.tokens import SHADOW_LG, TEXT_MAIN, TEXT_MUTED, TEXT_SUB\n",
    )
    text = text.replace('apply_drop_shadow(self, offset=(0, 4), blur_radius=12, alpha=30)', 'apply_drop_shadow(self, shadow=SHADOW_LG)')
    text = text.replace('load_lucide_icon("folder", "#666666")', 'load_lucide_icon("folder", TEXT_SUB)')
    text = text.replace('HoverIconButton("pin", "#B0B5C0", "#666666", 16)', 'HoverIconButton("pin", TEXT_MUTED, TEXT_SUB, 18)')
    text = text.replace('load_lucide_icon("folder-open", "#666666")', 'load_lucide_icon("folder-open", TEXT_SUB)')
    text = text.replace('"external-link", "#666666", "#1A1A1A", 16', '"external-link", TEXT_SUB, TEXT_MAIN, 18')
    return text


def sap(text):
    text = add_import(
        text,
        "from plm.frontend.qt.widgets.common import load_lucide_icon\n",
        "from plm.frontend.qt.styles.tokens import TEXT_SUB\n",
    )
    return text.replace('def icon(name, color="#666666", size=20):', 'def icon(name, color=TEXT_SUB, size=18):')


def lane(text):
    text = text.replace('self._bg_color = "#ffffff"', 'self._bg_color = BG_SURFACE')
    text = text.replace('QtGui.QColor("#333333")', 'QtGui.QColor(TEXT_MAIN)')
    text = text.replace('QtGui.QColor("#bb0000")', 'QtGui.QColor(DANGER)')
    text = text.replace('QtGui.QColor(16, 163, 127, 24)', 'QtGui.QColor(SUCCESS + "18")')
    text = text.replace('fill="#f7f7f7" stroke="#202124"', 'fill="{BG_MAIN}" stroke="{TEXT_MAIN}"')
    text = text.replace('fill="#c7c9cc" ', 'fill="{TEXT_MUTED}" ')
    text = text.replace('stroke="#202124"', 'stroke="{TEXT_MAIN}"')
    text = text.replace('stroke="#ffffff"', 'stroke="{BG_SURFACE}"')
    text = text.replace("        'fill=\"{BG_MAIN}\" stroke=\"{TEXT_MAIN}\"", "        f'fill=\"{BG_MAIN}\" stroke=\"{TEXT_MAIN}\"")
    text = text.replace("        'stroke=\"{TEXT_MAIN}\"", "        f'stroke=\"{TEXT_MAIN}\"")
    text = text.replace("        'stroke=\"{BG_SURFACE}\"", "        f'stroke=\"{BG_SURFACE}\"")
    return text


update("main_window.py", main_window)
update("views/documentation_page.py", docs)
update("widgets/hover_card.py", hover)
update("widgets/sap_icons.py", sap)
update("widgets/lanegrid.py", lane)

hex_re = re.compile(r"#[0-9A-Fa-f]{6}\b")
violations = []
for path in ROOT.rglob("*"):
    if path.suffix not in {".py", ".qss"} or path.name == "tokens.py":
        continue
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for value in hex_re.findall(line):
            violations.append(f"{path.relative_to(ROOT)}:{line_no}: {value}")
if violations:
    raise RuntimeError("non-token color literals remain:\n" + "\n".join(violations))

print("BeautifulUI cleanup and color-token audit passed")
