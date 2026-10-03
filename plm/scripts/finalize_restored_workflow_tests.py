"""One-shot patch for the current functional-restoration phase."""
from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label} anchor mismatch: {count}")
    return text.replace(old, new, 1)


# 1) New Project should always start from the standard projects directory.
controller = Path("src/plm/frontend/qt/controllers/app_controller.py")
text = controller.read_text(encoding="utf-8")
text = replace_once(
    text,
    '    def new_project(self):\n        default = self.current_project.config_dir.parent.parent if self.current_project else Path.home()\n        dialog = NewProjectDialog(default, self.window)\n',
    '    def new_project(self):\n        default = Path.home() / "plm-projects"\n        dialog = NewProjectDialog(default, self.window)\n',
    "new-project default",
)
controller.write_text(text, encoding="utf-8")

# 2) Artifact tree: blank-area click closes the floating tree just like
# selecting a file or clicking back into the preview.
artifacts = Path("src/plm/frontend/qt/views/artifacts_panel.py")
text = artifacts.read_text(encoding="utf-8")
text = replace_once(
    text,
    '        self.preview.viewport().installEventFilter(self)\n        self.set_files([])\n',
    '        self.preview.viewport().installEventFilter(self)\n        self.file_tree.viewport().installEventFilter(self)\n        self.set_files([])\n',
    "artifact tree event-filter install",
)
old = '''    def eventFilter(self, watched, event):
        if (
            watched is self.preview.viewport()
            and event.type() == QtCore.QEvent.MouseButtonPress
            and self.file_tree.isVisible()
        ):
            self.tree_button.setChecked(False)
        return super().eventFilter(watched, event)
'''
new = '''    def eventFilter(self, watched, event):
        if event.type() == QtCore.QEvent.MouseButtonPress and self.file_tree.isVisible():
            if watched is self.preview.viewport():
                self.tree_button.setChecked(False)
            elif watched is self.file_tree.viewport() and self.file_tree.itemAt(event.pos()) is None:
                self.tree_button.setChecked(False)
        return super().eventFilter(watched, event)
'''
text = replace_once(text, old, new, "artifact blank-click behavior")
artifacts.write_text(text, encoding="utf-8")

# Focused regression for the project-directory default.
workflow_tests = Path("tests/test_qt_workflow.py")
text = workflow_tests.read_text(encoding="utf-8")
anchor = '\n\nif __name__ == "__main__":\n    unittest.main()\n'
method = '''
    def test_new_project_uses_standard_projects_directory(self):
        controller, window = self._editing_window()
        captured = {}

        class FakeDialog:
            def __init__(self, location, parent=None):
                captured["location"] = Path(location)

            def exec_(self):
                return QtWidgets.QDialog.Rejected

        with patch("plm.frontend.qt.controllers.app_controller.NewProjectDialog", FakeDialog):
            controller.new_project()
        self.assertEqual(captured["location"], Path.home() / "plm-projects")
'''
if "def test_new_project_uses_standard_projects_directory" not in text:
    text = replace_once(text, anchor, "\n" + method + anchor, "workflow test insertion")
workflow_tests.write_text(text, encoding="utf-8")

# Focused regression for blank-space dismissal of the floating file tree.
artifact_tests = Path("tests/test_qt_artifacts.py")
text = artifact_tests.read_text(encoding="utf-8")
method = '''
    def test_file_tree_blank_click_closes_overlay(self):
        path = self.file("rtl/one.sv", "module one;\\nendmodule\\n")
        self.panel.set_files([path], self.root)
        self.panel.tree_button.click()
        self.app.processEvents()
        self.assertTrue(self.panel.file_tree.isVisible())

        viewport = self.panel.file_tree.viewport()
        point = QtCore.QPoint(max(1, viewport.width() - 2), max(1, viewport.height() - 2))
        if self.panel.file_tree.itemAt(point) is not None:
            point = QtCore.QPoint(max(1, viewport.width() - 2), 1)
        event = QtGui.QMouseEvent(
            QtCore.QEvent.MouseButtonPress,
            point,
            QtCore.Qt.LeftButton,
            QtCore.Qt.LeftButton,
            QtCore.Qt.NoModifier,
        )
        self.panel.eventFilter(viewport, event)
        self.assertFalse(self.panel.tree_button.isChecked())
        self.assertFalse(self.panel.file_tree.isVisible())
'''
if "def test_file_tree_blank_click_closes_overlay" not in text:
    text = replace_once(text, anchor, "\n" + method + anchor, "artifact test insertion")
artifact_tests.write_text(text, encoding="utf-8")
