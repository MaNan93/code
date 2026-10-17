"""Rendered contracts for the third UI consistency pass."""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.styles.tokens import (
    CONTROL_HEIGHT, FONT_SIZE_SMALL, FONT_SIZE_TITLE, LANE_SWATCH_MAX_WIDTH,
    STATUS_DOT_INSET, TAB_INDICATOR_HEIGHT, get_theme_color,
)
from plm.frontend.qt.widgets.common import StyledMenu, icon_descriptor
from plm.frontend.qt.widgets.controller_swatch import ControllerSwatch


class Phase3VisualTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)
        cls.app.setStyle("Fusion")

    def setUp(self):
        isolate_host_formatter(self, self.app)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name).resolve()
        scaffold_default_content(self.root / "examples/demo")
        store = SettingsStore(QtCore.QSettings(str(self.root / "settings.ini"), QtCore.QSettings.IniFormat))
        controller = AppController(ProjectService(self.root), store)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            self.window = MainWindow()
        self.window.show()
        wait_for_idle(self.app)

    def capture(self, name, widget=None):
        directory = os.environ.get("PLM_PHASE3_SCREENSHOT_DIR")
        if directory:
            output = Path(directory)
            output.mkdir(parents=True, exist_ok=True)
            self.assertTrue((widget or self.window).grab().save(str(output / f"{name}.png")))

    def test_project_header_badge_and_path_hierarchy(self):
        page = self.window.config_page
        header = page.header
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            for dirty in (False, True):
                with self.subTest(theme=theme, dirty=dirty):
                    header.set_dirty(dirty)
                    wait_for_idle(self.app)
                    badge = header.save_state
                    self.assertTrue(badge.isVisible())
                    self.assertEqual(badge.text(), "未保存" if dirty else "已保存")
                    self.assertEqual(badge.accessibleName(), badge.text())
                    picture = badge.grab().toImage()
                    ratio = badge.devicePixelRatioF()
                    sample_y = round(badge.height() / 2 * ratio)
                    role = "warning" if dirty else "success"
                    self.assertEqual(picture.pixelColor(round(2 * ratio), sample_y).name(),
                                     get_theme_color(role + "_bg").lower())
                    self.assertEqual(picture.pixelColor(round(STATUS_DOT_INSET * ratio), sample_y).name(),
                                     get_theme_color(role + "_text").lower())
                    self.assertEqual(header.title_label.font().pixelSize(), FONT_SIZE_TITLE)
                    self.assertEqual(header.path_label.font().pixelSize(), FONT_SIZE_SMALL)
                    self.assertGreater(header.title_label.font().weight(), header.path_label.font().weight())
                    self.assertEqual(header.path_label.text(), header.path_label.toolTip())
                    self.assertEqual(header.path_label.palette().color(QtGui.QPalette.WindowText).name(),
                                     get_theme_color("text_muted").lower())
                    self.capture(f"{theme}-header-{'dirty' if dirty else 'saved'}", header)
            page.tabs.setCurrentIndex(3)
            self.capture(f"{theme}-generation")
            page.tabs.setCurrentIndex(0)
        header.set_dirty(False)

    def test_settings_and_configuration_tabs_share_rendered_underline(self):
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            tabbar = self.window.config_page.tabs.tabBar()
            self.window.config_page.tabs.setCurrentIndex(0)
            self.window.on_open_settings()
            wait_for_idle(self.app)
            settings = self.window.view_stack.currentWidget()
            self.capture(f"{theme}-settings")
            for index, button in enumerate(settings.menu_buttons):
                QtTest.QTest.mouseClick(button, QtCore.Qt.LeftButton)
                wait_for_idle(self.app)
                self.assertTrue(button.property("selected"))
                self.assertEqual(button.height(), CONTROL_HEIGHT)
                self.assertEqual(button.font().pixelSize(), tabbar.font().pixelSize())
                self.assertEqual(button.font().pixelSize(), 13)
                image = button.grab().toImage()
                ratio = button.devicePixelRatioF()
                self.assertEqual(image.pixelColor(image.width() // 2, image.height() - 1).name(),
                                 get_theme_color("primary").lower())
                self.assertEqual(image.pixelColor(round(2 * ratio), round(4 * ratio)).alpha(), 0)
                point = button.mapTo(self.window, QtCore.QPoint(2, 4))
                window_image = self.window.grab().toImage()
                self.assertEqual(window_image.pixelColor(round(point.x() * ratio), round(point.y() * ratio)).name(),
                                 get_theme_color("bg_main").lower())
                other = settings.menu_buttons[1 - index].grab().toImage()
                self.assertNotEqual(other.pixelColor(other.width() // 2, other.height() - 1).name(),
                                    get_theme_color("primary").lower())
            self.window._close_secondary_page()
            self.app.processEvents()
            image = tabbar.grab().toImage()
            rect = tabbar.tabRect(0)
            ratio = tabbar.devicePixelRatioF()
            self.assertEqual(image.pixelColor(round(rect.center().x() * ratio),
                                             round((rect.bottom() - TAB_INDICATOR_HEIGHT / 2) * ratio)).name(),
                             get_theme_color("primary").lower())

    def test_controller_swatches_preserve_ids_and_elide_only_long_names(self):
        wrapper = self.window.config_page.mapping_editor
        self.window.config_page.tabs.setCurrentIndex(1)
        grid = wrapper.editor
        name = "ControllerWithAVeryLongHardwareName" * 6
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            grid.set_controllers([
                {"ctrl_id": "12", "ctrl_name": name, "max_width": "4"},
                {"ctrl_id": "27", "ctrl_name": "CtrlB", "max_width": "4"},
            ])
            grid.palette_bar.setFixedWidth(240)
            wait_for_idle(self.app)
            buttons = grid.palette_bar.findChildren(ControllerSwatch)
            self.assertEqual([button.text() for button in buttons], [f"12: {name}", "27: CtrlB"])
            long_button = buttons[0]
            self.assertLessEqual(long_button.width(), LANE_SWATCH_MAX_WIDTH)
            self.assertTrue(long_button.display_text().startswith("12: "))
            self.assertTrue(long_button.display_text().endswith("…"))
            self.assertIn(name, long_button.toolTip())
            self.assertEqual(long_button.accessibleName(), f"12: {name}")
            self.assertEqual(buttons[1].display_text(), "27: CtrlB")
            QtTest.QTest.mouseClick(buttons[1], QtCore.Qt.LeftButton)
            wait_for_idle(self.app)
            self.assertEqual(grid.active_ctrl_id, "27")
            self.capture(f"{theme}-swatches", grid.palette_bar)

    def test_table_row_menu_has_themed_icons_for_every_action(self):
        table_editor = self.window.config_page.controllers_editor.editor
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            for row in (0, -1):
                def inspect(menu, position):
                    actions = [action for action in menu.actions() if not action.isSeparator()]
                    expected = [("arrow-up", "text_sub"), ("arrow-down", "text_sub"),
                                ("trash-2", "danger")] if row >= 0 else [("arrow-down", "text_sub")]
                    self.assertEqual([icon_descriptor(action.icon())[:2] for action in actions], expected)
                    for action, (_, role) in zip(actions, expected):
                        image = action.icon().pixmap(16, 16).toImage()
                        self.assertTrue(any(image.pixelColor(x, y).alpha() > 0
                                            and image.pixelColor(x, y).name() == get_theme_color(role).lower()
                                            for x in range(image.width()) for y in range(image.height())))
                    menu.popup(position)
                    self.app.processEvents()
                    self.capture(f"{theme}-row-menu-{row}", menu)
                    menu.close()
                    menu.deleteLater()
                    return None
                with patch.object(StyledMenu, "exec_", inspect):
                    table_editor._show_row_context_menu(row, QtCore.QPoint(100, 100))

    def test_panel_toggle_icons_describe_the_panel_directions(self):
        for theme in ("light", "dark"):
            self.window.apply_theme(theme)
            self.assertEqual(icon_descriptor(self.window.log_toggle_button.icon())[0], "panel-bottom")
            self.assertEqual(icon_descriptor(self.window.artifacts_toggle_button.icon())[0], "panel-right")
            self.assertEqual(self.window.artifacts_toggle_button.toolTip(), "显示/隐藏 Artifacts")
            self.capture(f"{theme}-titlebar", self.window.title_bar)


if __name__ == "__main__":
    unittest.main()
