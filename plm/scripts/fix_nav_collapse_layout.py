"""One-shot fix: immediately relayout collapsed navigation contents."""
from pathlib import Path

path = Path("src/plm/frontend/qt/views/nav_panel.py")
text = path.read_text(encoding="utf-8")
old = '''        self.brand_layout.invalidate()\n\n        self.new_chat_btn.setText("新对话" if visible else "")\n'''
new = '''        self.brand_layout.invalidate()\n        # invalidate() only schedules a relayout. On Windows/offscreen the\n        # animation can finish before that pass runs, leaving the collapse\n        # button at its expanded x-position for a frame. Apply the geometry\n        # synchronously so every collapsed icon shares the same center.\n        self.brand_layout.activate()\n        layout = self.layout()\n        if layout is not None:\n            layout.activate()\n\n        self.new_chat_btn.setText("新对话" if visible else "")\n'''
if text.count(old) != 1:
    raise SystemExit(f"nav relayout anchor mismatch: {text.count(old)}")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
