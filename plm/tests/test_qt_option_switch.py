"""Exercise direct option edits, keyboard navigation and table refresh reuse."""

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtTest, QtWidgets
from qt_test_support import wait_for_idle
from plm.frontend.qt.widgets.config_editor import CsvTableEditor
from plm.frontend.qt.widgets.option_switch import OptionSwitch


class OptionSwitchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.editor = CsvTableEditor(["signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"])
        self.rows = [dict(signal_name=f"signal_{i}", signal_type="perlane", direction="mac2phy",
                          width="32", safe_state="0", tie_off="0") for i in range(3)]
        self.editor.set_rows(self.rows)
        self.editor.resize(860, 400)
        self.editor.show()
        wait_for_idle(self.app)

    def tearDown(self):
        self.editor.close()
        self.editor.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)

    def test_click_and_keyboard_edit_once_with_repeated_selection_noop(self):
        control = self.editor.table.cellWidget(0, 1)
        self.assertIsInstance(control, OptionSwitch)
        spy = QtTest.QSignalSpy(self.editor.changed)
        QtTest.QTest.mouseClick(control, QtCore.Qt.LeftButton,
                               pos=QtCore.QPoint(control.width() * 3 // 4, control.height() // 2))
        self.assertEqual(self.editor.rows()[0]["signal_type"], "shared")
        self.assertEqual(len(spy), 1)
        QtTest.QTest.keyClick(control, QtCore.Qt.Key_End)
        self.assertEqual(len(spy), 1)
        QtTest.QTest.keyClick(control, QtCore.Qt.Key_Left)
        self.assertEqual(self.editor.rows()[0]["signal_type"], "perlane")
        direction = self.editor.table.cellWidget(0, 2)
        QtTest.QTest.keyClick(direction, QtCore.Qt.Key_Space)
        self.assertEqual(self.editor.rows()[0]["direction"], "phy2mac")
        self.assertEqual(len(spy), 3)

    def test_refresh_preserves_invalid_values_and_row_callbacks(self):
        control = self.editor.table.cellWidget(0, 1)
        spy = QtTest.QSignalSpy(self.editor.changed)
        self.editor.set_rows([{**self.rows[0], "signal_type": "unknown"}, *self.rows[1:]])
        self.assertIs(self.editor.table.cellWidget(0, 1), control)
        self.assertEqual(control.currentText(), "unknown")
        self.assertIn("unknown", control.options())
        self.assertEqual(len(spy), 0)
        self.editor.set_cell_errors({(0, "signal_type"): "invalid signal type"})
        self.assertTrue(control.property("validationError"))
        self.assertEqual(control.toolTip(), "invalid signal type")
        for expected in ("perlane", "shared", "perlane"):
            control.click()
            self.assertEqual(control.currentText(), expected)
        self.editor.set_rows(self.rows)
        self.assertEqual(control.options(), ("perlane", "shared"))
        self.assertFalse(control.property("validationError"))
        self.editor.editor._on_row_drop(2, 0)
        self.editor.editor.delete_row(1)
        self.editor.table.cellWidget(1, 2).setCurrentText("phy2mac")
        self.assertEqual([(r["signal_name"], r["direction"]) for r in self.editor.rows()],
                         [("signal_2", "mac2phy"), ("signal_1", "phy2mac")])


if __name__ == "__main__":
    unittest.main()
