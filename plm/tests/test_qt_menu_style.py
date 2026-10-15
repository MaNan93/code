"""Check menu painting and native keyboard/submenu behavior together."""

import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from qt_test_support import dispose_new_widgets, preserve_application_state
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.styles.tokens import BG_SUBTLE, CONTROL_HEIGHT, MENU_GAP, MENU_PADDING
from plm.frontend.qt.widgets.common import StyledComboBox, StyledMenu


class QtMenuStyleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)
        cls.app.setStyle("Fusion")
        cls.app.setStyleSheet(APP_QSS)

    def setUp(self):
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.menu = StyledMenu()
        self.menu.setAttribute(QtCore.Qt.WA_DontShowOnScreen)

    def show_menu(self):
        self.menu.popup(QtCore.QPoint(100, 100))
        self.app.processEvents()

    def test_compact_rows_and_transparent_shadow_corners(self):
        first = self.menu.addAction("打开项目")
        self.menu.addSeparator()
        second = self.menu.addAction("删除当前行")
        self.show_menu()
        self.menu.setActiveAction(first)
        image = self.menu.grab().toImage()
        first_rect = self.menu.actionGeometry(first)
        second_rect = self.menu.actionGeometry(second)
        self.assertEqual(first_rect.height() - MENU_GAP, CONTROL_HEIGHT)
        self.assertEqual(second_rect.top() - first_rect.top(), CONTROL_HEIGHT + MENU_GAP)
        self.assertEqual(first_rect.left() - self.menu.SHADOW_MARGIN, MENU_PADDING)
        self.assertEqual(self.menu.width() - self.menu.SHADOW_MARGIN - first_rect.right() - 1, MENU_PADDING)
        self.assertEqual(image.pixelColor(first_rect.right() - 20, first_rect.top() + 18).name(), BG_SUBTLE.lower())
        self.assertEqual(image.pixelColor(first_rect.right() - 20, first_rect.bottom() - 1).name(), "#ffffff")
        self.assertEqual(image.pixelColor(0, 0).alpha(), 0)
        self.assertGreater(image.pixelColor(self.menu.SHADOW_MARGIN - 2, image.height() // 2).alpha(), 0)
        self.assertFalse(second.icon().isNull())
        icon = second.icon().pixmap(14, 14).toImage()
        self.assertTrue(any(icon.pixelColor(x, y).red() > 200
                            and icon.pixelColor(x, y).green() < 130
                            and icon.pixelColor(x, y).alpha() > 100
                            for x in range(icon.width()) for y in range(icon.height())))

    def test_keyboard_skips_disabled_action_and_triggers_checked_action(self):
        first = self.menu.addAction("打开")
        self.menu.addAction("不可用").setEnabled(False)
        toggle = self.menu.addAction("显示差异")
        toggle.setCheckable(True)
        spy = QtTest.QSignalSpy(toggle.triggered)
        self.show_menu()
        self.menu.setActiveAction(first)
        QtTest.QTest.keyClick(self.menu, QtCore.Qt.Key_Down)
        self.assertIs(self.menu.activeAction(), toggle)
        QtTest.QTest.keyClick(self.menu, QtCore.Qt.Key_Return)
        self.assertEqual(len(spy), 1)
        self.assertTrue(toggle.isChecked())

    def test_submenu_uses_capsules_and_opens_from_keyboard(self):
        submenu = self.menu.addMenu("更多操作")
        submenu.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        submenu.addAction("重命名")
        self.assertIsInstance(submenu, StyledMenu)
        self.show_menu()
        self.menu.setActiveAction(submenu.menuAction())
        QtTest.QTest.keyClick(self.menu, QtCore.Qt.Key_Right)
        self.app.processEvents()
        self.assertTrue(submenu.isVisible())
        rect = submenu.actionGeometry(submenu.actions()[0])
        self.assertEqual(rect.height() - MENU_GAP, CONTROL_HEIGHT)

    def test_long_labels_fit_the_icon_and_text_insets(self):
        if not QtGui.QFontDatabase().families():
            self.skipTest("The offscreen platform has no font database")
        action = self.menu.addAction("打开包含当前项目配置文件的所在目录")
        self.show_menu()
        option = QtWidgets.QStyleOptionMenuItem()
        self.menu.initStyleOption(option, action)
        width = QtGui.QFontMetrics(option.font).horizontalAdvance(action.text())
        self.assertGreaterEqual(self.menu.actionGeometry(action).width(), width + 16 + 10 + 24)

    def test_combo_menu_keyboard_selection_and_escape_preserve_value_signals(self):
        combo = StyledComboBox()
        combo.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        combo.popup_menu.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        combo.addItem("indent (default)", "indent")
        combo.addItem("不可用", "disabled")
        combo.addItem("wrap", "wrap")
        combo.model().item(1).setEnabled(False)
        combo.show()
        self.addCleanup(combo.close)
        self.addCleanup(combo.deleteLater)
        changes = QtTest.QSignalSpy(combo.currentIndexChanged[int])
        activations = QtTest.QSignalSpy(combo.activated[int])
        combo.showPopup()
        self.app.processEvents()
        self.assertIsInstance(combo.popup_menu, StyledMenu)
        self.assertEqual(combo.popup_menu.actionGeometry(combo.popup_menu.actions()[0]).height(), CONTROL_HEIGHT + MENU_GAP)
        QtTest.QTest.keyClick(combo.popup_menu, QtCore.Qt.Key_Down)
        QtTest.QTest.keyClick(combo.popup_menu, QtCore.Qt.Key_Return)
        self.assertEqual(combo.currentData(), "wrap")
        self.assertEqual(list(changes), [[2]])
        self.assertEqual(list(activations), [[2]])
        combo.showPopup()
        QtTest.QTest.keyClick(combo.popup_menu, QtCore.Qt.Key_Up)
        QtTest.QTest.keyClick(combo.popup_menu, QtCore.Qt.Key_Escape)
        self.assertEqual(combo.currentData(), "wrap")
        self.assertEqual(len(activations), 1)


if __name__ == "__main__":
    unittest.main()
