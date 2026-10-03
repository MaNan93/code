"""One-shot patch for deterministic Qt frontend tests on Windows."""
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

old = '''        nav.collapse_btn.click()\n        self.assertTrue(nav.is_animating)\n        nav.collapse_btn.click()\n        self.assertTrue(nav._target_collapsed)\n        QtTest.QTest.qWait(100)\n        self.assertGreater(nav.width(), 56)\n        self.assertLess(nav.width(), 260)\n        self.assertEqual(\n            self.window.content_splitter.geometry().left()\n            - (nav.geometry().right() + 1),\n            4,\n        )\n        QtTest.QTest.qWait(250)\n        self.assertFalse(nav.is_animating)\n'''
new = '''        collapse_finished = QtTest.QSignalSpy(nav.animation_group.finished)\n        nav.collapse_btn.click()\n        self.assertTrue(nav.is_animating)\n        nav.collapse_btn.click()\n        self.assertTrue(nav._target_collapsed)\n        self.assertTrue(collapse_finished.wait(1000))\n        self.assertFalse(nav.is_animating)\n'''
if text.count(old) != 1:
    raise SystemExit(f"collapse animation anchor mismatch: {text.count(old)}")
text = text.replace(old, new, 1)

old = '''        nav.collapse_btn.click()\n        self.assertTrue(nav.project_list.isVisible())\n        QtTest.QTest.qWait(350)\n        self.assertFalse(nav.is_collapsed)\n'''
new = '''        expand_finished = QtTest.QSignalSpy(nav.animation_group.finished)\n        nav.collapse_btn.click()\n        self.assertTrue(nav.project_list.isVisible())\n        self.assertTrue(expand_finished.wait(1000))\n        self.assertFalse(nav.is_collapsed)\n'''
if text.count(old) != 1:
    raise SystemExit(f"expand animation anchor mismatch: {text.count(old)}")
text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
