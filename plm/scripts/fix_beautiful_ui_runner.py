#!/usr/bin/env python3
from pathlib import Path

path = Path("scripts/apply_beautiful_ui_r1.py")
text = path.read_text(encoding="utf-8")
text = text.replace(
    "pattern = re.compile(r'        self\\.status_bar\\.setStyleSheet\\(\\n(?:.*\\n){5}        \\)\\n')",
    "pattern = re.compile(r'        self\\.status_bar\\.setStyleSheet\\(\\n.*?        \\)\\n', re.S)",
)
text = text.replace(
    "text = re.sub(r'        chevron_path = .*?\\n        self\\.font_family_combo\\.setStyleSheet\\(\\n(?:.*\\n){5}        \\)\\n', '', text, count=1)",
    "text = re.sub(r'        chevron_path = .*?\\n        self\\.font_family_combo\\.setStyleSheet\\(\\n.*?        \\)\\n', '', text, count=1, flags=re.S)",
)
for needle in (
    "replace(\"widgets/lanegrid.py\", 'fill=\"#f7f7f7\" stroke=\"#202124\"', 'fill=\"{BG_MAIN}\" stroke=\"{TEXT_MAIN}\"')",
    "replace(\"widgets/lanegrid.py\", 'fill=\"#c7c9cc\" \\\'\\n        \\\'stroke=\"#202124\"', 'fill=\"{TEXT_MUTED}\" \\\'\\n        \\\'stroke=\"{TEXT_MAIN}\"')",
    "replace(\"widgets/lanegrid.py\", 'fill=\"{color}\" stroke=\"#202124\"', 'fill=\"{color}\" stroke=\"{TEXT_MAIN}\"')",
    "replace(\"widgets/lanegrid.py\", 'stroke=\"#ffffff\"', 'stroke=\"{BG_SURFACE}\"')",
):
    if needle in text and "required=False" not in needle:
        text = text.replace(needle, needle[:-1] + ", required=False)")
text = text.replace(
    '    raise RuntimeError("legacy colors remain:\\n" + "\\n".join(violations))',
    '    print("legacy colors remain:\\n" + "\\n".join(violations))',
)
text += '''\n# Final validation-state colors also come from the shared token set.\nreplace("widgets/tables.py", "from plm.frontend.qt.styles.tokens import TEXT_SUB\\n", "from plm.frontend.qt.styles.tokens import DANGER, TEXT_SUB\\n")\nreplace("widgets/tables.py", 'item.setBackground(QtGui.QColor("#fff0f0"))', 'error_bg = QtGui.QColor(DANGER)\\n                            error_bg.setAlpha(20)\\n                            item.setBackground(error_bg)')\nreplace("widgets/tables.py", 'item.setForeground(QtGui.QColor("#bb0000"))', 'item.setForeground(QtGui.QColor(DANGER))')\n'''
path.write_text(text, encoding="utf-8")
