"""One-shot patch for deterministic Qt frontend test teardown on Windows."""
from pathlib import Path

path = Path("tests/test_qt_frontend.py")
text = path.read_text(encoding="utf-8")

old = '''        cls.app.setStyleSheet(APP_QSS)\n\n    def setUp(self):\n'''
new = '''        cls.app.setStyleSheet(APP_QSS)\n\n        # Under the Windows offscreen Qt platform an unexpected modal\n        # QMessageBox can terminate the interpreter before unittest can report\n        # a traceback. Turn accidental dialogs into normal assertion failures.\n        for name in ("about", "critical", "information", "question", "warning"):\n            patcher = patch.object(\n                QtWidgets.QMessageBox,\n                name,\n                side_effect=AssertionError(\n                    f"QMessageBox.{name}() reached without being mocked"\n                ),\n            )\n            patcher.start()\n            cls.addClassCleanup(patcher.stop)\n\n    def setUp(self):\n'''
if text.count(old) != 1:
    raise SystemExit(f"setUpClass anchor mismatch: {text.count(old)}")
text = text.replace(old, new, 1)

old = '''    def tearDown(self):\n        self.window.close()\n        self.window.deleteLater()\n        self.app.processEvents()\n'''
new = '''    def tearDown(self):\n        self.window.close()\n        # processEvents() does not guarantee DeferredDelete delivery. Destroy\n        # every top-level test widget before the next test reuses QApplication;\n        # otherwise timers/event filters can accumulate across the full suite.\n        for widget in self.app.topLevelWidgets():\n            widget.deleteLater()\n        QtCore.QCoreApplication.sendPostedEvents(\n            None, QtCore.QEvent.DeferredDelete\n        )\n        self.app.processEvents()\n'''
if text.count(old) != 1:
    raise SystemExit(f"tearDown anchor mismatch: {text.count(old)}")
text = text.replace(old, new, 1)

old = '''        header = ConfigHeader()\n        self.addCleanup(header.deleteLater)\n        header.title_label.setText("原始名称")\n'''
new = '''        header = ConfigHeader()\n        header.title_label.setText("原始名称")\n'''
if text.count(old) != 1:
    raise SystemExit(f"ConfigHeader cleanup anchor mismatch: {text.count(old)}")
text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
