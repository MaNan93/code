#!/usr/bin/env python3
from pathlib import Path

path = Path("tests/test_qt_artifacts.py")
text = path.read_text(encoding="utf-8")
if "from plm.frontend.qt.styles.tokens import PRIMARY, TEXT_MUTED, TEXT_SUB" not in text:
    text = text.replace(
        "from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel\n",
        "from plm.frontend.qt.styles.tokens import PRIMARY, TEXT_MUTED, TEXT_SUB\n"
        "from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel\n",
        1,
    )
text = text.replace('"#6a737d"', 'TEXT_MUTED.lower()')
text = text.replace('"#d73a49"', 'PRIMARY.lower()')
text = text.replace('"#032f62"', 'TEXT_SUB.lower()')
path.write_text(text, encoding="utf-8")
