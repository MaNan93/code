"""One-shot patch: fix duplicate-name refresh and align workflow tests with restored UI."""
from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label} anchor mismatch: {count}")
    return text.replace(old, new, 1)


controller = Path("src/plm/frontend/qt/controllers/app_controller.py")
text = controller.read_text(encoding="utf-8")
old = '''    def _refresh_project_names(self):
        projects = self._available_projects()
        by_path = {p.config_dir: p for p in projects}
        self.nav.blockSignals(True)
        try:
            for widget in self.nav.project_list.project_widgets:
                project = by_path.get(widget.project_path)
                if project and widget.project_name != project.name:
                    self.nav.apply_rename(widget.project_name, project.name, project.config_dir)
        finally:
            self.nav.blockSignals(False)
        if self.current_project and self.current_project.config_dir in by_path:
            self.current_project = by_path[self.current_project.config_dir]
            self.current_name = self.current_project.name
            self.nav.current_project_name = self.current_name
            self.config_page.update_title(self.current_name)
            self.settings.set_recent_project(self.current_name)
            self._update_window_title()
'''
new = '''    def _refresh_project_names(self):
        projects = self._available_projects()
        # Project rows intentionally store the workspace root because Reveal
        # opens the whole project. Match rows by that root, while controller
        # state continues to use config_dir as its stable identity.
        by_root = {p.config_dir.parent.resolve(): p for p in projects}
        by_config = {p.config_dir.resolve(): p for p in projects}
        self.nav.blockSignals(True)
        try:
            for widget in self.nav.project_list.project_widgets:
                project = by_root.get(Path(widget.project_path).resolve())
                if project and widget.project_name != project.name:
                    self.nav.apply_rename(widget.project_name, project.name, project.config_dir)
        finally:
            self.nav.blockSignals(False)
        if self.current_project:
            current = by_config.get(self.current_project.config_dir.resolve())
            if current is not None:
                self.current_project = current
                self.current_name = current.name
                self.nav.current_project_name = self.current_name
                self.config_page.update_title(self.current_name)
                self.settings.set_recent_project(self.current_name)
                self._update_window_title()
'''
text = replace_once(text, old, new, "controller refresh")
controller.write_text(text, encoding="utf-8")

tests = Path("tests/test_qt_workflow.py")
t = tests.read_text(encoding="utf-8")
t = replace_once(
    t,
    '        self.assertIn("生成完成", window.log_panel.output.toPlainText())\n',
    '        self.assertIn("生成完成", window.log_panel.status_label.text())\n',
    "generation status bar",
)
t = replace_once(
    t,
    '        self.assertIn("输出已是最新", window.log_panel.output.toPlainText())\n',
    '        self.assertIn("输出已是最新", window.log_panel.status_label.text())\n',
    "up-to-date status bar",
)

old = '''    def test_lane_selector_tracks_controllers_and_commits_active_editor(self):
        from plm.frontend.qt.widgets.config_editor import LaneSelector
        controller, window = self._editing_window()
        page = window.config_page
        table = page.mapping_editor.table
        page.tabs.setCurrentIndex(1)
        table.setCurrentCell(0, 1)
        table.editItem(table.item(0, 1))
        self.app.processEvents()
        selector = table.findChild(LaneSelector)
        self.assertIsNotNone(selector)
        self.assertEqual(selector.controller.count(), 5)
        selector.controller.setCurrentIndex(2)
        self.assertEqual(selector.lane.count(), 8)
        selector.lane.setCurrentIndex(3)
        page.finish_editing()
        self.app.processEvents()
        self.assertEqual(table.item(0, 1).text(), "1-3")
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(table.item(0, 1).text(), "0-0")
        page.controllers_editor.table.item(1, 2).setText("2")
        delegate = table.itemDelegate()
        index = table.model().index(0, 1)
        chooser = delegate.createEditor(table, QtWidgets.QStyleOptionViewItem(), index)
        delegate.setEditorData(chooser, index)
        chooser.controller.setCurrentIndex(2)
        self.assertEqual(chooser.lane.count(), 2)
        chooser.deleteLater()
'''
new = '''    def test_lane_grid_tracks_controllers_and_paints_ranges(self):
        controller, window = self._editing_window()
        page = window.config_page
        grid = page.mapping_editor.editor
        table = page.mapping_editor.table
        page.tabs.setCurrentIndex(1)
        self.assertEqual(len(grid.controllers), page.controllers_editor.table.rowCount())
        self.assertGreaterEqual(len(grid.controllers), 2)
        target_id = str(grid.controllers[1]["ctrl_id"])
        before = [table.item(0, column).text() for column in range(1, 4)]

        grid._set_active_controller(target_id)
        grid._begin_paint(0, 0)
        grid._continue_paint(0, 2)
        grid._end_paint()
        self.assertEqual(
            [table.item(0, column).text() for column in range(1, 4)],
            [f"{target_id}-0", f"{target_id}-1", f"{target_id}-2"],
        )
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(
            [table.item(0, column).text() for column in range(1, 4)], before
        )
'''
t = replace_once(t, old, new, "lane selector paint test")

old = '''    def test_lane_editor_internal_focus_commit_and_cancel(self):
        from PyQt5 import QtTest
        from plm.frontend.qt.widgets.config_editor import LaneSelector
        controller, window = self._editing_window()
        page = window.config_page
        table = page.mapping_editor.table
        page.tabs.setCurrentIndex(1)
        table.editItem(table.item(0, 1))
        self.app.processEvents()
        selector = table.findChild(LaneSelector)
        selector.controller.setCurrentIndex(2)
        selector.lane.setFocus()
        self.app.processEvents()
        self.assertEqual(table.item(0, 1).text(), "0-0")
        selector.lane.setCurrentIndex(3)
        table.setFocus()
        self.app.processEvents()
        self.assertEqual(table.item(0, 1).text(), "1-3")
        table.editItem(table.item(0, 2))
        self.app.processEvents()
        selector = table.itemDelegate()._lane_editor
        selector.controller.setCurrentIndex(2)
        selector.lane.setCurrentIndex(4)
        QtTest.QTest.keyClick(selector.lane, QtCore.Qt.Key_Escape)
        self.app.processEvents()
        self.assertEqual(table.item(0, 2).text(), "0-1")
'''
new = '''    def test_lane_grid_manual_edit_is_preserved_and_undoable(self):
        controller, window = self._editing_window()
        page = window.config_page
        table = page.mapping_editor.table
        page.tabs.setCurrentIndex(1)
        original = table.item(0, 1).text()
        table.item(0, 1).setText("1-3")
        self.app.processEvents()
        self.assertEqual(page.mapping_editor.rows()[0]["lane0"], "1-3")
        self.assertTrue(page.dirty)
        page.undo()
        self.assertEqual(table.item(0, 1).text(), original)
'''
t = replace_once(t, old, new, "lane editor test")

old = '''    def test_field_delegates_constrain_input_without_rewriting_loaded_values(self):
        from PyQt5 import QtGui
        controller, window = self._editing_window()
        page = window.config_page
        option = QtWidgets.QStyleOptionViewItem()
        table = page.controllers_editor.table
        numeric = table.itemDelegate().createEditor(table, option, table.model().index(0, 2))
        self.assertEqual(numeric.validator().validate("abc", 0)[0], QtGui.QValidator.Invalid)
        self.assertEqual(numeric.validator().validate("16", 0)[0], QtGui.QValidator.Acceptable)
        numeric.deleteLater()
        signals = page.signals_editor.table
        index = signals.model().index(0, 1)
        combo = signals.itemDelegate().createEditor(signals, option, index)
        self.assertEqual([combo.itemText(i) for i in range(combo.count())], ["perlane", "shared"])
        signals.item(0, 1).setText("unknown")
        signals.itemDelegate().setEditorData(combo, index)
        signals.itemDelegate().setModelData(combo, signals.model(), index)
        self.assertEqual(signals.item(0, 1).text(), "unknown")
        combo.deleteLater()
        index = signals.model().index(0, 5)
        literal = signals.itemDelegate().createEditor(signals, option, index)
        for value in ("lane0", "0x50", "0b101"):
            self.assertEqual(literal.validator().validate(value, 0)[0], QtGui.QValidator.Acceptable)
        literal.deleteLater()
'''
new = '''    def test_table_editors_preserve_invalid_values_for_core_validation(self):
        controller, window = self._editing_window()
        page = window.config_page
        table = page.controllers_editor.table
        table.item(0, 2).setText("abc")
        controller.validate_current()
        self.assertEqual(table.item(0, 2).text(), "abc")
        self.assertTrue(table.item(0, 2).toolTip())
        self.assertEqual(controller.generation_state, "invalid")

        rows = page.signals_editor.rows()
        rows[0]["signal_type"] = "unknown"
        page.signals_editor.set_rows(rows)
        combo = page.signals_editor.table.cellWidget(0, 1)
        self.assertIsInstance(combo, QtWidgets.QComboBox)
        self.assertEqual(combo.currentText(), "unknown")
        self.assertEqual(
            [combo.itemText(i) for i in range(combo.count())],
            ["perlane", "shared", "unknown"],
        )
'''
t = replace_once(t, old, new, "table editor validation test")

t = replace_once(
    t,
    '        self.assertTrue(item.data(QtCore.Qt.UserRole))\n',
    '        self.assertIn((0, 1), page.mapping_editor.editor._cell_errors)\n',
    "lane grid error marker",
)

tests.write_text(t, encoding="utf-8")
