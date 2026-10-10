"""Table refresh must preserve callbacks and replace stale in-progress edits."""

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets
from qt_test_support import wait_for_idle
from plm.frontend.qt.widgets.tables import EditableTable


class TableRefreshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.editor = EditableTable([
            {"key": "name"}, {"key": "type", "options": ["perlane", "shared"]},
        ])
        self.rows = [{"name": name, "type": "perlane"} for name in ("A", "B", "C")]
        self.editor.set_rows(self.rows)
        self.editor.show()
        wait_for_idle(self.app)

    def tearDown(self):
        self.editor.close()
        self.editor.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)

    def test_refresh_reuses_controls_and_does_not_emit_user_edits(self):
        combo = self.editor.table.cellWidget(0, 1)
        self.assertIsNone(combo._popup_menu)
        spy = QtTest.QSignalSpy(self.editor.changed)
        updated = [{"name": "Updated", "type": "invalid"}, *self.rows[1:]]
        self.editor.set_rows(updated)
        self.assertIs(self.editor.table.cellWidget(0, 1), combo)
        self.assertEqual(self.editor.get_rows(), updated)
        self.assertEqual(len(spy), 0)
        self.editor.set_rows(self.rows)
        self.assertEqual([combo.itemText(i) for i in range(combo.count())], ["perlane", "shared"])
        self.assertIsNone(combo._popup_menu)

    def test_reorder_and_delete_keep_combo_callbacks_on_current_rows(self):
        self.editor._on_row_drop(2, 0)
        self.editor.delete_row(1)
        self.assertEqual([row["name"] for row in self.editor.get_rows()], ["C", "B"])
        spy = QtTest.QSignalSpy(self.editor.changed)
        self.editor.table.cellWidget(1, 1).setCurrentText("shared")
        self.assertEqual(self.editor.get_rows(), [
            {"name": "C", "type": "perlane"}, {"name": "B", "type": "shared"},
        ])
        self.assertEqual(len(spy), 1)

    def test_refresh_closes_stale_text_editor(self):
        table = self.editor.table
        table.setFocus()
        table.editItem(table.item(0, 0))
        wait_for_idle(self.app)
        active = self.app.focusWidget()
        self.assertIsInstance(active, QtWidgets.QLineEdit)
        active.setText("unfinished edit")
        self.editor.set_rows(self.rows)
        wait_for_idle(self.app)
        self.assertNotEqual(table.state(), QtWidgets.QAbstractItemView.EditingState)
        self.assertEqual(self.editor.get_rows(), self.rows)


if __name__ == "__main__":
    unittest.main()
