import os
import tempfile
import shutil
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from sample_data import SAMPLES_DIR
from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.styles.tokens import (
    BG_ARTIFACTS, BG_ARTIFACTS_HEADER, BG_FOCUS, BG_SUBTLE, BORDER, BORDER_HOVER, CONTROL_HEIGHT, FONT_CODE_PRIMARY, FONT_MONO, FONT_SCALE, FONT_SIZE_BODY,
    CONTROL_PADDING_X, ICON_GLYPH_SIZE, NAV_COLLAPSED_WIDTH, NAV_ICON_INSET, NAV_ITEM_GAP, SPACING_MD, PRIMARY_SOFT, PRIMARY_PRESSED, TEXT_MAIN, TOOLTIP_BG, SETTINGS_MAX_WIDTH,
)
from plm.frontend.qt.models import ProjectInfo
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.views.config_page import ConfigHeader
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.widgets.common import ICON_SIZE, ICON_TEXT_GAP, LUCIDE_ICON_DIR, button_height, load_lucide_icon
from plm.frontend.qt.widgets.project_item import ProjectItemWidget
from plm.frontend.qt.widgets.project_list import ProjectList


class QtFrontendLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)
        cls.app.setStyle("Fusion")
        cls.app.setFont(QtGui.QFont("Segoe UI", 10))
        cls.app.setStyleSheet(APP_QSS)

        # Under the Windows offscreen Qt platform an unexpected modal
        # QMessageBox can terminate the interpreter before unittest can report
        # a traceback. Turn accidental dialogs into normal assertion failures.
        for name in ("about", "critical", "information", "question", "warning"):
            patcher = patch.object(
                QtWidgets.QMessageBox,
                name,
                side_effect=AssertionError(
                    f"QMessageBox.{name}() reached without being mocked"
                ),
            )
            patcher.start()
            cls.addClassCleanup(patcher.stop)

    def setUp(self):
        isolate_host_formatter(self, self.app)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name)
        for config in SAMPLES_DIR.glob("*/config"):
            shutil.copytree(config, self.root / "test" / config.parent.name / "config")
        self.store = SettingsStore(QtCore.QSettings(
            str(self.root / "settings.ini"), QtCore.QSettings.IniFormat
        ))
        factory = patch("plm.frontend.qt.main_window.AppController",
                        side_effect=lambda: AppController(ProjectService(self.root), self.store))
        factory.start()
        self.addCleanup(factory.stop)
        self.window = MainWindow()
        wait_for_idle(self.app)
        self.window.show()
        wait_for_idle(self.app)

    def test_frameless_window_with_immersive_sidebar_and_log_splitter(self):
        self.assertTrue(self.window.windowFlags() & QtCore.Qt.FramelessWindowHint)
        self.assertEqual(self.window.windowTitle(), "plmConsultant")
        self.assertIsInstance(self.window.nav_panel, NavPanel)
        self.assertEqual(self.window.nav_panel.width(), 260)
        self.assertIs(self.window.centralWidget(), self.window.window_backdrop)
        self.assertIs(self.window.view_stack.widget(0), self.window.main_container)
        shell_layout = self.window.window_shell.layout()
        self.assertIsInstance(shell_layout, QtWidgets.QVBoxLayout)
        self.assertEqual(shell_layout.spacing(), 0)
        self.assertEqual(shell_layout.contentsMargins(), QtCore.QMargins(0, 0, 0, 0))
        self.assertEqual(shell_layout.count(), 2)
        self.assertIs(shell_layout.itemAt(0).widget(), self.window.title_bar)
        self.assertIs(shell_layout.itemAt(1).widget(), self.window.body_container)
        body_layout = self.window.body_container.layout()
        self.assertIsInstance(body_layout, QtWidgets.QHBoxLayout)
        self.assertEqual(body_layout.spacing(), 0)
        self.assertEqual(body_layout.contentsMargins(), QtCore.QMargins(0, 0, 0, 0))
        self.assertIs(body_layout.itemAt(0).widget(), self.window.nav_panel)
        self.assertIs(body_layout.itemAt(1).widget(), self.window.view_stack)
        self.assertEqual(self.window.title_bar.height(), 44)
        self.assertEqual(self.window.title_bar.logo_label.size(), QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.assertEqual(self.window.title_bar.title_label.text(), "plmConsultant")
        self.assertIs(
            self.window.title_bar.collapse_btn.parentWidget(),
            self.window.title_bar,
        )
        self.assertFalse(hasattr(self.window.nav_panel, "collapse_btn"))
        self.assertEqual(self.window.config_page.header.findChildren(QtWidgets.QPushButton), [])
        for widget in (self.window.main_container, self.window.config_page.config_area,
                       self.window.config_page.header):
            self.assertEqual(widget.focusPolicy(), QtCore.Qt.NoFocus)
        scroll = self.window.config_page.tabs.widget(3).scroll
        self.assertEqual(scroll.focusPolicy(), QtCore.Qt.ClickFocus)
        self.assertEqual(scroll.widget().focusPolicy(), QtCore.Qt.ClickFocus)
        self.assertEqual(self.window.config_page.controllers_editor.table.focusPolicy(),
                         QtCore.Qt.StrongFocus)
        backdrop = self.window.window_backdrop
        backdrop.grab()
        cache_key = backdrop._shadow_pixmap.cacheKey()
        backdrop.grab()
        self.assertEqual(backdrop._shadow_pixmap.cacheKey(), cache_key)
        self.window.resize(self.window.width() + 10, self.window.height() + 10)
        wait_for_idle(self.app)
        backdrop.grab()
        self.assertNotEqual(backdrop._shadow_pixmap.cacheKey(), cache_key)
        self.assertEqual(len(self.window._resize_handles), 8)
        self.assertEqual(
            self.window.title_bar.minimize_btn.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE)
        )
        self.assertEqual(
            self.window.title_bar.maximize_btn.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE)
        )
        self.assertEqual(
            self.window.title_bar.close_btn.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE)
        )
        self.assertEqual(
            self.window.log_toggle_button.size(), QtCore.QSize(28, CONTROL_HEIGHT)
        )
        self.assertEqual(
            self.window.artifacts_toggle_button.size(), QtCore.QSize(28, CONTROL_HEIGHT)
        )
        self.assertEqual(self.window.content_splitter.orientation(), QtCore.Qt.Vertical)
        self.assertEqual(self.window.nav_panel.minimumWidth(), 260)
        self.assertEqual(self.window.nav_panel.maximumWidth(), 260)
        self.assertEqual(self.window.content_splitter.handleWidth(), 6)
        self.assertEqual(self.window.content_splitter.contentsMargins(), QtCore.QMargins())
        for panel in (
            self.window.config_page,
            self.window.log_panel,
            self.window.config_page.artifacts_panel,
        ):
            self.assertIsNone(panel.graphicsEffect())
        self.assertIsInstance(self.window.log_panel, LogPanel)
        self.assertEqual(
            self.window.title_bar.collapse_btn.iconSize(),
            QtCore.QSize(ICON_SIZE, ICON_SIZE),
        )

    def test_desktop_text_and_code_use_thirteen_pixels(self):
        self.assertEqual(FONT_SCALE, 1.0)
        self.assertEqual(FONT_SIZE_BODY, 13)
        preview_font = self.window.config_page.artifacts_panel.preview.font()
        self.assertEqual(preview_font.pixelSize(), 13)
        self.assertEqual(CONTROL_HEIGHT, 32)
        self.assertEqual(ICON_SIZE, 16)
        self.assertEqual(self.window.log_panel.output.font().pixelSize(), 13)
        self.assertTrue(self.window.log_panel.output.font().fixedPitch())
        self.assertTrue(preview_font.fixedPitch())
        self.assertNotEqual(FONT_CODE_PRIMARY, self.window.font().family())
        self.assertIn("monospace", FONT_MONO)

    def test_global_button_heights_use_the_shared_token(self):
        from plm.frontend.qt.views.new_project_dialog import NewProjectDialog

        dialog = NewProjectDialog(str(self.root), self.window)
        for page_button in (self.window.nav_panel.settings_btn, self.window.nav_panel.docs_btn):
            page_button.click()
            wait_for_idle(self.app)
            for button in self.window.findChildren(QtWidgets.QPushButton):
                button.ensurePolished()
                with self.subTest(button=button.objectName(), text=button.text()):
                    self.assertEqual(button.height(), button_height(button))
        dialog.close()
        button = QtWidgets.QPushButton("重新载入")
        button.ensurePolished()
        font = QtGui.QFont(button.font())
        font.setPixelSize(22)
        button.setFont(font)
        self.assertEqual(button.height(), CONTROL_HEIGHT)
        button.deleteLater()

    def test_project_menu_capsules_have_four_pixel_spacing(self):
        widget = self.window.nav_panel.project_list.project_widgets[0]
        menu = widget.build_more_menu()
        menu.ensurePolished()
        menu.sizeHint()  # Lay out the actions before measuring their rectangles.
        previous = None
        for action in menu.actions():
            if action.isSeparator():
                self.assertFalse(action.isVisible())
                continue
            rect = menu.actionGeometry(action)
            if previous is not None:
                self.assertEqual(rect.top(), previous.bottom() + 1)
            self.assertEqual(rect.height() - 4, CONTROL_HEIGHT)
            previous = rect
        menu.deleteLater()

    def test_controller_table_fixed_dimensions_and_whole_row_hover(self):
        table = self.window.config_page.controllers_editor.table
        widths = [table.columnWidth(i) for i in range(3)]
        metrics = table.horizontalHeader().fontMetrics()
        for index in (0, 2):
            heading = table.horizontalHeaderItem(index).text()
            self.assertGreaterEqual(
                widths[index], metrics.horizontalAdvance(heading) + 24,
            )
        self.assertEqual(widths[1], table.viewport().width() - widths[0] - widths[2])
        self.assertEqual(table.horizontalHeader().height(), CONTROL_HEIGHT)
        for row in range(table.rowCount()):
            self.assertEqual(table.rowHeight(row), CONTROL_HEIGHT)
        table.clearSelection()
        point = table.visualRect(table.model().index(1, 1)).center()
        QtTest.QTest.mouseMove(table.viewport(), point)
        self.app.processEvents()
        image = table.viewport().grab().toImage()
        for column in range(3):
            rect = table.visualRect(table.model().index(1, column))
            self.assertEqual(image.pixelColor(rect.right() - 4, point.y()).name(), BG_SUBTLE.lower())

    def test_settings_button_groups_have_no_internal_gap(self):
        self.window.nav_panel.settings_btn.click()
        wait_for_idle(self.app)
        page = self.window.view_stack.currentWidget()
        self.assertTrue(all(
            section.parentWidget().objectName() == "SecondaryTabs"
            for section in page.menu_buttons
        ))
        for section in page.menu_buttons:
            section.click()
            wait_for_idle(self.app)
            self.assertEqual(section.height(), CONTROL_HEIGHT)
            for group in page.findChildren(QtWidgets.QFrame, "ButtonGroup"):
                if not group.isVisible():
                    continue
                self.assertEqual(group.height(), CONTROL_HEIGHT)
                buttons = [group.layout().itemAt(i).widget() for i in range(group.layout().count())]
                for left, right in zip(buttons, buttons[1:]):
                    self.assertEqual(left.geometry().right() + 1, right.geometry().left())

    def test_tooltip_has_transparent_rounded_corners_and_preserves_focus(self):
        button = self.window.nav_panel.save_btn
        self.window.activateWindow()
        button.setFocus()
        self.app.processEvents()
        controller = self.app._rounded_tooltips
        point = button.rect().center()
        event = QtGui.QHelpEvent(QtCore.QEvent.ToolTip, point, button.mapToGlobal(point))
        self.app.sendEvent(button, event)
        self.app.processEvents()
        popup = controller.popup
        self.assertTrue(popup.isVisible())
        self.assertEqual(popup.label.text(), "保存")
        self.assertTrue(button.hasFocus())
        image = popup.grab().toImage()
        self.assertEqual(image.pixelColor(0, 0).alpha(), 0)
        self.assertEqual(image.pixelColor(image.width() - 1, image.height() - 1).alpha(), 0)
        self.assertTrue(any(
            0 < image.pixelColor(x, y).alpha() < 255
            for x in range(10) for y in range(10)
        ))
        self.assertEqual(image.pixelColor(image.width() // 2, 2).name(), TOOLTIP_BG.lower())
        self.app.sendEvent(button, QtCore.QEvent(QtCore.QEvent.Leave))
        self.assertFalse(popup.isVisible())

    def test_nav_actions_show_visible_focus_and_pressed_backgrounds(self):
        nav = self.window.nav_panel
        self.window.activateWindow()
        for button in (
            nav.new_chat_btn, nav.open_project_btn, nav.save_btn,
            nav.settings_btn, nav.docs_btn,
        ):
            self.assertEqual(button.focusPolicy(), QtCore.Qt.StrongFocus)
            button.setFocus(QtCore.Qt.TabFocusReason)
            wait_for_idle(self.app)
            self.assertTrue(button.hasFocus())
            point = QtCore.QPoint(button.width() - 12, button.height() // 2)
            self.assertEqual(button.grab().toImage().pixelColor(point).name(), BG_FOCUS.lower())
            button.setDown(True)
            self.assertEqual(button.grab().toImage().pixelColor(point).name(), BORDER_HOVER.lower())
            button.setDown(False)
        for button, page in ((nav.settings_btn, "settings"), (nav.docs_btn, "docs")):
            nav.set_active(page)
            button.setFocus(QtCore.Qt.TabFocusReason)
            wait_for_idle(self.app)
            point = QtCore.QPoint(button.width() - 12, button.height() // 2)
            self.assertEqual(button.grab().toImage().pixelColor(point).name(), PRIMARY_SOFT.lower())
            button.setDown(True)
            self.assertEqual(button.grab().toImage().pixelColor(point).name(), PRIMARY_PRESSED.lower())
            button.setDown(False)
        nav.set_active(None)

    def test_nav_toggle_collapses_and_restores_sidebar(self):
        nav = self.window.nav_panel
        stable_y_positions = {
            "new": nav.new_chat_btn.mapTo(nav, QtCore.QPoint()).y(),
            "save": nav.save_btn.mapTo(nav, QtCore.QPoint()).y(),
            "settings": nav.settings_btn.mapTo(nav, QtCore.QPoint()).y(),
            "docs": nav.docs_btn.mapTo(nav, QtCore.QPoint(0, nav.docs_btn.height())).y(),
        }
        collapse_finished = QtTest.QSignalSpy(nav.animation_group.finished)
        self.window.title_bar.collapse_btn.click()
        self.assertTrue(nav.is_animating)
        self.window.title_bar.collapse_btn.click()
        self.assertTrue(nav._target_collapsed)
        self.assertTrue(collapse_finished.wait(1000))
        self.assertFalse(nav.is_animating)
        self.assertTrue(nav.is_collapsed)
        self.assertEqual(self.window.title_bar.collapse_btn.toolTip(), "展开侧边栏")
        self.assertEqual(nav.width(), 56)
        self.assertFalse(nav.project_list.isVisible())
        self.assertEqual(nav.new_chat_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.save_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.new_chat_btn.height(), CONTROL_HEIGHT)
        self.assertEqual(nav.save_btn.height(), CONTROL_HEIGHT)
        self.assertEqual(
            self.window.content_splitter.mapTo(self.window.body_container, QtCore.QPoint()).x()
            - (nav.geometry().right() + 1),
            4,
        )
        aligned_widgets = [
            nav.new_chat_btn,
            nav.save_btn,
            nav.settings_btn,
            nav.docs_btn,
        ]
        for widget in aligned_widgets:
            self.assertEqual(widget.accessibleName(), widget.toolTip())
            self.assertEqual(widget.mapTo(nav, QtCore.QPoint()).x(), SPACING_MD)
            self.assertEqual(widget.width(), NAV_COLLAPSED_WIDTH - 2 * SPACING_MD)
        self.assertEqual(nav.layout().contentsMargins().right(), SPACING_MD)
        self.assertEqual(
            nav.new_chat_btn.mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["new"],
        )
        self.assertEqual(
            nav.save_btn.mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["save"],
        )
        self.assertEqual(
            nav.docs_btn.mapTo(nav, QtCore.QPoint(0, nav.docs_btn.height())).y(),
            stable_y_positions["docs"],
        )
        self.assertLess(
            nav.settings_btn.mapTo(nav, QtCore.QPoint()).y(),
            nav.docs_btn.mapTo(nav, QtCore.QPoint()).y(),
        )
        self.assertEqual(nav.settings_btn.mapTo(nav, QtCore.QPoint()).y(), stable_y_positions["settings"])
        self.assertTrue(nav.footer.isVisible())
        self.assertEqual(nav.settings_btn.text(), "")
        self.assertEqual(nav.docs_btn.text(), "")

        expand_finished = QtTest.QSignalSpy(nav.animation_group.finished)
        self.window.title_bar.collapse_btn.click()
        self.assertFalse(nav.project_list.isVisible())
        self.assertTrue(expand_finished.wait(1000))
        self.assertTrue(nav.project_list.isVisible())
        self.assertEqual(nav.settings_btn.text(), "设置")
        self.assertEqual(nav.docs_btn.text(), "文档")
        self.assertFalse(nav.is_collapsed)
        self.assertEqual(self.window.title_bar.collapse_btn.toolTip(), "收起侧边栏")
        self.assertEqual(nav.width(), 260)
        self.assertEqual(nav.minimumWidth(), 260)
        self.assertEqual(nav.maximumWidth(), 260)
        self.assertEqual(nav.new_chat_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.save_btn.objectName(), "NavActionButton")

    def test_nav_icons_keep_rendered_position_and_shape_through_animation(self):
        nav = self.window.nav_panel
        buttons = (nav.new_chat_btn, nav.open_project_btn, nav.save_btn,
                   nav.settings_btn, nav.docs_btn)
        for button in buttons:
            button.clearFocus()
        self.window.resize(1400, 900)
        self.app.processEvents()
        toggle_position = self.window.title_bar.collapse_btn.mapTo(self.window, QtCore.QPoint())

        def rendered_icons():
            # Widget grabs and style content rectangles do not prove where the
            # custom painter draws. Scan actual pixels from the whole window.
            image = self.window.grab().toImage()
            if image.size() != self.window.size():
                image = image.scaled(self.window.size())
            shapes = []
            for button in buttons:
                pos = button.mapTo(self.window, QtCore.QPoint())
                pixels = {
                    (x, y)
                    for x in range(min(button.width(), NAV_ICON_INSET + ICON_SIZE))
                    for y in range(6, button.height() - 6)
                    if image.pixelColor(pos.x() + x, pos.y() + y).lightness() < 160
                }
                self.assertTrue(pixels, button.toolTip())
                self.assertEqual(button.mapTo(nav, QtCore.QPoint()).x(), SPACING_MD)
                shapes.append(pixels)
            self.assertEqual(
                self.window.title_bar.collapse_btn.mapTo(self.window, QtCore.QPoint()),
                toggle_position,
            )
            return shapes

        expanded = rendered_icons()
        for shape in expanded:
            self.assertGreaterEqual(min(x for x, _y in shape), NAV_ICON_INSET)
        for target in (True, False):
            finished = QtTest.QSignalSpy(nav.animation_group.finished)
            nav.toggle_collapse()
            nav.animation_group.pause()
            for elapsed in (0, 30, 80, 140, 199):
                nav.animation_group.setCurrentTime(elapsed)
                self.app.processEvents()
                with self.subTest(collapsed=target, elapsed=elapsed):
                    self.assertEqual(rendered_icons(), expanded)
            nav.animation_group.resume()
            self.assertTrue(finished.wait(1000))
            self.assertEqual(nav.is_collapsed, target)
            rendered = rendered_icons()
            self.assertEqual(rendered, expanded)
            if target:
                for button, shape in zip(buttons, rendered):
                    left = min(x for x, _y in shape)
                    right = max(x for x, _y in shape)
                    self.assertLessEqual(abs(left - (button.width() - 1 - right)), 2)

    def test_nav_section_dividers_remain_visible_when_collapsed(self):
        nav = self.window.nav_panel
        for collapsed in (False, True):
            if collapsed:
                finished = QtTest.QSignalSpy(nav.animation_group.finished)
                nav.toggle_collapse()
                self.assertTrue(finished.wait(1000))
            for separator in (nav.project_separator, nav.footer_separator):
                self.assertTrue(separator.isVisible())
                image = separator.grab().toImage()
                self.assertEqual(image.pixelColor(image.width() // 2, 0).name(), BORDER_HOVER.lower())

    def test_nav_width_stays_fixed_when_window_resizes(self):
        nav = self.window.nav_panel
        self.window.resize(1200, 760)
        wait_for_idle(self.app)
        self.assertEqual(nav.width(), 260)

        self.window.resize(1600, 1000)
        wait_for_idle(self.app)
        self.assertEqual(nav.width(), 260)

        self.window.title_bar.collapse_btn.click()
        QtTest.QTest.qWait(250)
        self.window.resize(1200, 760)
        wait_for_idle(self.app)
        self.assertEqual(nav.width(), 56)

    def test_nav_actions_projects_and_drag_configuration(self):
        nav = self.window.nav_panel
        self.assertFalse(hasattr(nav, "actionRequested"))
        self.assertEqual(nav.new_chat_btn.text(), "新建项目")
        self.assertEqual(nav.new_chat_btn.toolTip(), "新建项目")
        self.assertEqual(nav.new_chat_btn.accessibleName(), "新建项目")
        self.assertEqual(nav.save_btn.text(), "保存")
        self.assertEqual(nav.docs_btn.text(), "文档")
        self.assertEqual(nav.settings_btn.text(), "设置")
        self.assertIsInstance(nav.project_list, ProjectList)
        self.assertEqual(
            nav.project_list.dragDropMode(), QtWidgets.QAbstractItemView.InternalMove
        )
        self.assertEqual(nav.project_list.defaultDropAction(), QtCore.Qt.MoveAction)
        self.assertGreater(nav.project_list.count(), 0)
        project_names = {
            widget.project_name for widget in nav.project_list.project_widgets
        }
        first_project = nav.project_list.project_widgets[0]
        self.assertEqual(first_project.folder_icon.size(), QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.assertEqual(
            first_project.header.layout().contentsMargins(),
            QtCore.QMargins(NAV_ICON_INSET, 0, CONTROL_PADDING_X, 0),
        )
        self.assertEqual(
            first_project.header.layout().itemAt(1).spacerItem().sizeHint().width(), 6
        )
        self.assertEqual(first_project.project_name_label.text(), first_project.project_name)
        self.assertEqual(first_project.header.text(), "")
        self.assertFalse(first_project.header.isCheckable())
        self.assertFalse(hasattr(first_project, "session_buttons"))
        self.assertEqual(
            first_project.findChildren(QtWidgets.QPushButton, "SessionButton"), []
        )
        self.assertEqual(first_project.more_btn.size(), QtCore.QSize(28, 28))
        self.assertTrue(first_project.more_btn.isHidden())
        self.assertFalse(hasattr(nav.project_list, "hover_card"))
        self.assertEqual(first_project.findChildren(QtWidgets.QPushButton, "ProjectArchiveBtn"), [])
        self.assertEqual(first_project.findChildren(QtWidgets.QPushButton, "ProjectOpenBtn"), [])
        for icon_name in ("folder", "folder-open", "pin"):
            self.assertTrue((LUCIDE_ICON_DIR / f"{icon_name}.svg").is_file())
        expected_configs = {"bifurcate", "dpr", "finegrain", "maxpclk"}
        self.assertTrue(expected_configs.issubset(project_names))
        self.assertNotIn("__pycache__", project_names)
        self.assertNotIn("ffe", project_names)
        nav.set_active("docs")
        self.assertTrue(nav.docs_btn.property("selected"))
        nav.set_active("settings")
        self.assertTrue(nav.settings_btn.property("selected"))

    def test_nav_panel_uses_supplied_projects_without_discovery(self):
        self.assertEqual(NavPanel.__module__, "plm.frontend.qt.views.nav_panel")
        missing_config_dir = Path(tempfile.gettempdir()) / "plm-fake-project"
        project = ProjectInfo(
            name="demo",
            config_dir=missing_config_dir,
            controllers_csv=missing_config_dir / "controllers.csv",
            lane_mapping_csv=missing_config_dir / "lane_mapping.csv",
            pipe_signals_csv=missing_config_dir / "pipe_signals.csv",
        )
        nav = NavPanel(projects=[project], recent_project="missing")
        try:
            self.assertEqual(nav.project_list.count(), 1)
            self.assertEqual(nav.current_project_name, "demo")
            selected_spy = QtTest.QSignalSpy(nav.project_selected)
            nav.project_list.project_widgets[0].header.click()
            wait_for_idle(self.app)
            self.assertEqual(selected_spy[0][0], "demo")
        finally:
            nav.close()
            nav.deleteLater()

    def test_nav_action_buttons_emit_semantic_signals(self):
        nav = self.window.nav_panel
        new_chat_spy = QtTest.QSignalSpy(nav.new_chat_requested)
        save_spy = QtTest.QSignalSpy(nav.save_requested)
        settings_spy = QtTest.QSignalSpy(nav.settings_requested)
        docs_spy = QtTest.QSignalSpy(nav.docs_requested)

        with patch("plm.frontend.qt.controllers.project_navigation.NewProjectDialog") as dialog:
            dialog.return_value.exec_.return_value = QtWidgets.QDialog.Rejected
            nav.new_chat_btn.click()
        wait_for_idle(self.app)
        nav.save_btn.click()
        wait_for_idle(self.app)
        nav.settings_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(self.window.view_stack.currentWidget().page, "settings")
        self.window._close_secondary_page()
        nav.docs_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(self.window.view_stack.currentWidget().page, "docs")

        self.assertEqual(len(new_chat_spy), 1)
        self.assertEqual(len(save_spy), 1)
        self.assertEqual(len(settings_spy), 1)
        self.assertEqual(len(docs_spy), 1)

    def test_project_focus_feedback_preserves_active_project_highlight(self):
        widget = self.window.nav_panel.project_list.project_widgets[-1]
        self.window.activateWindow()
        widget.set_selected(False)
        widget.header.setFocus(QtCore.Qt.TabFocusReason)
        wait_for_idle(self.app)
        point = QtCore.QPoint(widget.header.width() - 8, widget.header.height() // 2)
        self.assertEqual(widget.header.grab().toImage().pixelColor(point).name(), BG_FOCUS.lower())
        widget.set_selected(True)
        self.assertEqual(widget.header.grab().toImage().pixelColor(point).name(), PRIMARY_SOFT.lower())
        for button in (widget.more_btn,):
            button.show()
            button.setFocus(QtCore.Qt.TabFocusReason)
            self.app.processEvents()
            pixel = QtCore.QPoint(button.width() // 2, 2)
            self.assertEqual(button.grab().toImage().pixelColor(pixel).name(), BG_FOCUS.lower())
            button.setDown(True)
            pressed = button.grab().toImage()
            self.assertEqual(pressed.pixelColor(pixel).name(), BORDER_HOVER.lower())
            self.assertNotEqual(pressed.pixelColor(0, 0), pressed.pixelColor(pixel))
            button.setDown(False)

    def test_project_folder_action_remains_in_more_menu(self):
        project_list = self.window.nav_panel.project_list
        widget = project_list.project_widgets[0]
        self.app.sendEvent(widget.header, QtCore.QEvent(QtCore.QEvent.Enter))
        self.app.processEvents()
        self.assertTrue(widget.more_btn.isVisible())
        self.assertFalse(hasattr(widget, "archive_btn"))
        self.assertFalse(hasattr(widget, "open_folder_btn"))
        selected = QtTest.QSignalSpy(widget.projectSelected)
        with patch("plm.frontend.qt.widgets.project_item.open_in_file_manager") as open_folder:
            menu = widget.build_more_menu()
            next(action for action in menu.actions() if action.text() == "打开所在目录").trigger()
            open_folder.assert_called_once_with(widget.project_path)
            menu.deleteLater()
        self.assertEqual(len(selected), 0)
        self.app.sendEvent(widget.header, QtCore.QEvent(QtCore.QEvent.Leave))
        self.assertTrue(widget.more_btn.isHidden())
        self.assertFalse(hasattr(project_list, "hover_card"))
        self.assertFalse(hasattr(project_list, "_hover_timer"))

    def test_project_list_is_flat_and_project_click_does_not_expand(self):
        project_list = self.window.nav_panel.project_list
        self.assertEqual(
            ProjectList.__module__, "plm.frontend.qt.widgets.project_list"
        )
        self.assertFalse(hasattr(project_list, "hover_card"))
        initial_count = project_list.count()
        self.assertGreater(initial_count, 0)
        for row, widget in enumerate(project_list.project_widgets):
            self.assertEqual(project_list.item(row).sizeHint().height(), CONTROL_HEIGHT + NAV_ITEM_GAP)
            self.assertEqual(widget.header.height(), CONTROL_HEIGHT)
            self.assertEqual(widget.layout().count(), 2)
            self.assertIs(widget.layout().itemAt(0).widget(), widget.header)
            self.assertFalse(widget.header.isCheckable())

        target = project_list.project_widgets[-1]
        target.header.click()
        wait_for_idle(self.app)
        self.assertEqual(project_list.count(), initial_count)
        self.assertEqual(project_list.selected_project_name, target.project_name)
        self.assertTrue(target.header.property("selected"))

    def test_expanded_nav_icons_and_project_names_share_alignment(self):
        nav = self.window.nav_panel
        first_project = nav.project_list.project_widgets[0]
        margins = nav.layout().contentsMargins()
        self.assertEqual(
            (margins.left(), margins.top(), margins.right(), margins.bottom()),
            (12, 12, 12, 8),
        )
        for layout in (
            nav.new_chat_row_layout,
            nav.save_row_layout,
            nav.settings_row_layout,
            nav.docs_row_layout,
        ):
            margins = layout.contentsMargins()
            self.assertEqual(
                (margins.left(), margins.top(), margins.right(), margins.bottom()),
                (0, 0, 0, 0),
            )
        self.assertEqual(
            first_project.header.layout().contentsMargins(),
            QtCore.QMargins(NAV_ICON_INSET, 0, CONTROL_PADDING_X, 0),
        )

        nav_buttons = (
            nav.new_chat_btn,
            nav.save_btn,
            nav.settings_btn,
            nav.docs_btn,
        )
        self.assertEqual(
            {widget.mapTo(nav, QtCore.QPoint()).x() for widget in nav_buttons},
            {12},
        )
        self.assertEqual(
            first_project.folder_icon.mapTo(nav, QtCore.QPoint()).x(),
            SPACING_MD + NAV_ICON_INSET,
        )
        text_left = SPACING_MD + NAV_ICON_INSET + ICON_SIZE + ICON_TEXT_GAP
        for project in nav.project_list.project_widgets:
            self.assertEqual(project.project_name_label.mapTo(nav, QtCore.QPoint()).x(), text_left)

        # Compare the same folder glyph through the navigation painter and the
        # project-row QLabel using actual window pixels, including hover rows.
        nav.new_chat_btn.setIcon(QtGui.QIcon(first_project.folder_icon.pixmap()))
        nav.new_chat_btn.clearFocus()
        for project in nav.project_list.project_widgets:
            project.header.clearFocus()
            self.app.sendEvent(project.header, QtCore.QEvent(QtCore.QEvent.Enter))
        self.app.processEvents()
        image = self.window.grab().toImage().scaled(self.window.size())

        def icon_pixels(button):
            pos = button.mapTo(self.window, QtCore.QPoint())
            return {
                (x, y) for x in range(NAV_ICON_INSET + ICON_SIZE)
                for y in range(6, button.height() - 6)
                if image.pixelColor(pos.x() + x, pos.y() + y).lightness() < 160
            }

        reference = icon_pixels(nav.new_chat_btn)
        self.assertTrue(reference)
        reference_edges = min(x for x, _y in reference), max(x for x, _y in reference)
        for project in nav.project_list.project_widgets:
            pixels = icon_pixels(project.header)
            self.assertTrue(pixels)
            self.assertEqual((min(x for x, _y in pixels), max(x for x, _y in pixels)), reference_edges)
        next_project = nav.project_list.project_widgets[1]
        gap = (
            next_project.header.mapTo(nav, QtCore.QPoint()).y()
            - first_project.header.mapTo(nav, QtCore.QPoint()).y()
            - first_project.header.height()
        )
        self.assertEqual(gap, NAV_ITEM_GAP)
        icon_pixmaps = (
            nav.new_chat_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
            nav.save_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
            first_project.folder_icon.pixmap(),
            nav.settings_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
            nav.docs_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
        )
        for pixmap in icon_pixmaps:
            self.assertEqual(pixmap.size(), QtCore.QSize(16, 16))
            bounds = QtGui.QRegion(pixmap.mask()).boundingRect()
            inset = (ICON_SIZE - ICON_GLYPH_SIZE) // 2
            self.assertGreaterEqual(bounds.left(), inset)
            self.assertLessEqual(bounds.right(), ICON_SIZE - inset - 1)

    def test_nav_panel_layout_contract(self):
        nav = self.window.nav_panel
        root = nav.layout()
        first_project = nav.project_list.project_widgets[0]

        self.assertIsInstance(root, QtWidgets.QVBoxLayout)
        self.assertEqual(root.spacing(), 0)
        self.assertEqual(nav.expanded_width, 260)
        self.assertEqual(nav.collapsed_width, 56)
        self.assertEqual(nav.minimumWidth(), 260)
        self.assertEqual(nav.maximumWidth(), 260)
        self.assertEqual(self.window.title_bar.collapse_btn.size(), QtCore.QSize(28, CONTROL_HEIGHT))

        for row_layout in (
            nav.new_chat_row_layout,
            nav.save_row_layout,
            first_project.header.layout(),
            nav.settings_row_layout,
            nav.docs_row_layout,
        ):
            self.assertEqual(row_layout.spacing(), 0)

        for button in (
            nav.new_chat_btn,
            nav.save_btn,
            nav.settings_btn,
            nav.docs_btn,
        ):
            self.assertEqual(button.height(), CONTROL_HEIGHT)

        project_index = root.indexOf(nav.project_list)
        collapsed_project_index = root.indexOf(nav.collapsed_projects)
        self.assertEqual(root.stretch(project_index), 1)
        self.assertEqual(root.stretch(collapsed_project_index), 1)
        self.assertEqual(first_project.header.height(), CONTROL_HEIGHT)

        footer_layout = nav.footer.layout()
        self.assertIsInstance(footer_layout, QtWidgets.QVBoxLayout)
        self.assertEqual(footer_layout.spacing(), 0)
        self.assertIs(footer_layout.itemAt(0).widget(), nav.settings_row)
        self.assertIs(footer_layout.itemAt(1).widget(), nav.docs_row)
        self.assertEqual(nav.collapsed_projects.layout().spacing(), 0)

        for animation in (nav.animation_min, nav.animation_max):
            self.assertEqual(animation.duration(), 200)
            self.assertEqual(
                animation.easingCurve().type(), QtCore.QEasingCurve.OutCubic
            )

    def test_project_selection_updates_header_and_recent_project(self):
        nav = self.window.nav_panel
        project_list = nav.project_list
        self.assertIsNotNone(nav.current_project_name)
        self.assertEqual(
            self.window.config_page.header.title_label.text(),
            nav.current_project_name,
        )
        self.assertEqual(
            sum(
                bool(widget.header.property("selected"))
                for widget in project_list.project_widgets
            ),
            1,
        )

        target = next(
            widget
            for widget in project_list.project_widgets
            if widget.project_name != nav.current_project_name
        )
        selected_spy = QtTest.QSignalSpy(nav.project_selected)
        target.header.click()
        wait_for_idle(self.app)
        self.assertEqual(nav.current_project_name, target.project_name)
        self.assertEqual(project_list.selected_project_name, target.project_name)
        self.assertEqual(
            self.window.config_page.header.title_label.text(), target.project_name
        )
        self.assertTrue(target.header.property("selected"))
        self.assertEqual(len(selected_spy), 1)
        self.assertEqual(selected_spy[0][0], target.project_name)
        self.assertEqual(
            sum(
                bool(widget.header.property("selected"))
                for widget in project_list.project_widgets
            ),
            1,
        )

    def test_recent_project_is_restored_or_falls_back_to_first(self):
        settings = self.store._settings
        key = "navigation/recent_project"
        original = settings.value(key, None)
        original_path = settings.value("navigation/recent_path", None)
        try:
            settings.remove("navigation/recent_path")
            settings.setValue(key, "dpr")
            restored = MainWindow()
            wait_for_idle(self.app)
            self.assertEqual(restored.nav_panel.current_project_name, "dpr")
            self.assertEqual(restored.config_page.header.title_label.text(), "dpr")
            restored.close()
            restored.deleteLater()

            settings.setValue(key, "missing-project")
            settings.remove("navigation/recent_path")
            fallback = MainWindow()
            wait_for_idle(self.app)
            first_name = fallback.nav_panel.project_list.project_widgets[0].project_name
            self.assertEqual(fallback.nav_panel.current_project_name, first_name)
            self.assertEqual(
                fallback.config_page.header.title_label.text(), first_name
            )
            fallback.close()
            fallback.deleteLater()
        finally:
            if original is None:
                settings.remove(key)
            else:
                settings.setValue(key, original)

            if original_path is None:
                settings.remove("navigation/recent_path")
            else:
                settings.setValue("navigation/recent_path", original_path)

    def test_config_header_inline_rename_save_and_cancel(self):
        # Test the header in isolation so titleChanged cannot rename a bundled
        # sample directory and pollute subsequent frontend tests.
        header = ConfigHeader()
        header.title_label.setText("原始名称")
        header.show()
        wait_for_idle(self.app)
        changed_spy = QtTest.QSignalSpy(header.titleChanged)

        header.enter_edit_mode()
        self.assertTrue(header.title_edit.isVisible())
        header.title_edit.setText("新的会话名称")
        header.title_edit.returnPressed.emit()
        self.assertEqual(header.title_label.text(), "新的会话名称")
        self.assertEqual(len(changed_spy), 1)
        self.assertEqual(changed_spy[0][0], "新的会话名称")

        header.enter_edit_mode()
        header.title_edit.setText("不应保存")
        header.title_edit.escapePressed.emit()
        self.assertEqual(header.title_label.text(), "新的会话名称")
        self.assertEqual(len(changed_spy), 1)

    def test_project_row_actions_and_nav_signals(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            projects = [
                ProjectInfo(name=name, config_dir=root / name / "config",
                            controllers_csv=root / name / "config/controllers.csv",
                            lane_mapping_csv=root / name / "config/lane_mapping.csv",
                            pipe_signals_csv=root / name / "config/pipe_signals.csv")
                for name in ("first", "second")
            ]
            for project in projects:
                project.config_dir.mkdir(parents=True)
            nav = NavPanel(projects)
            nav.show()
            wait_for_idle(self.app)
            try:
                project_list = nav.project_list
                first = project_list.project_widgets[0]
                QtWidgets.QApplication.sendEvent(
                    first.header, QtCore.QEvent(QtCore.QEvent.Enter))
                self.assertTrue(first.more_btn.isVisible())
                QtWidgets.QApplication.sendEvent(
                    first.header, QtCore.QEvent(QtCore.QEvent.Leave))
                self.assertFalse(first.more_btn.isVisible())

                pin_spy = QtTest.QSignalSpy(nav.project_pinned)
                project_list.pin_project(project_list.project_widgets[1])
                self.assertEqual(pin_spy[0][0], "second")
                self.assertIs(project_list.project_widgets[0], first)
                nav.apply_pin("second")
                self.assertEqual(project_list.project_widgets[0].project_name, "second")

                renamed_spy = QtTest.QSignalSpy(nav.project_renamed)
                project_list.rename_project(first)
                wait_for_idle(self.app)
                first.project_name_edit.setText("renamed")
                QtTest.QTest.keyClick(first.project_name_edit, QtCore.Qt.Key_Return)
                self.assertEqual(first.project_name, "first")
                self.assertEqual(renamed_spy[0], ["first", "renamed"])
                nav.apply_rename("first", "renamed", root / "renamed/config")
                self.assertEqual(first.project_name, "renamed")

                archived_spy = QtTest.QSignalSpy(nav.project_archived)
                with patch.object(QtWidgets.QMessageBox, "question",
                                  return_value=QtWidgets.QMessageBox.Yes):
                    project_list.archive_project(first)
                    wait_for_idle(self.app)
                self.assertEqual(archived_spy[0][0], "renamed")
                self.assertEqual(project_list.count(), 2)
                nav.apply_remove("renamed")
                self.assertEqual(project_list.count(), 1)
            finally:
                nav.close()
                nav.deleteLater()

    def test_project_item_is_independent_and_keeps_its_action_menu(self):
        self.assertEqual(
            ProjectItemWidget.__module__,
            "plm.frontend.qt.widgets.project_item",
        )
        with tempfile.TemporaryDirectory() as temporary_directory:
            widget = ProjectItemWidget("demo", temporary_directory)
            pin_spy = QtTest.QSignalSpy(widget.pinRequested)
            rename_spy = QtTest.QSignalSpy(widget.renameRequested)
            archive_spy = QtTest.QSignalSpy(widget.archiveRequested)
            delete_spy = QtTest.QSignalSpy(widget.deleteRequested)
            menu = widget.build_more_menu()
            actions = {action.text(): action for action in menu.actions()}

            self.assertIn("置顶", actions)
            self.assertIn("重命名", actions)
            self.assertIn("打开所在目录", actions)
            self.assertIn("归档", actions)
            self.assertIn("删除", actions)
            menu.ensurePolished()
            longest_text = "打开所在目录"
            text_width = menu.fontMetrics().horizontalAdvance(longest_text)
            icon_width = menu.style().pixelMetric(QtWidgets.QStyle.PM_SmallIconSize)
            self.assertGreaterEqual(menu.sizeHint().width(), text_width + icon_width + 32)
            self.assertEqual(menu.maximumWidth(), QtWidgets.QWIDGETSIZE_MAX)

            actions["置顶"].trigger()
            wait_for_idle(self.app)
            actions["重命名"].trigger()
            wait_for_idle(self.app)
            actions["归档"].trigger()
            wait_for_idle(self.app)
            actions["删除"].trigger()
            wait_for_idle(self.app)

            self.assertEqual(len(pin_spy), 1)
            self.assertEqual(len(rename_spy), 1)
            self.assertEqual(len(archive_spy), 1)
            self.assertEqual(len(delete_spy), 1)

            with patch(
                "plm.frontend.qt.widgets.project_item.open_in_file_manager"
            ) as open_path:
                actions["打开所在目录"].trigger()
                wait_for_idle(self.app)
                open_path.assert_called_once_with(widget.project_path)

            menu.deleteLater()
            widget.deleteLater()

    def test_table_pages_use_internal_scrolling_only(self):
        tabs = self.window.config_page.tabs
        self.assertEqual(tabs.count(), 4)
        self.assertEqual(
            [tabs.tabText(index) for index in range(tabs.count())],
            ["Controller", "LaneMapping", "Signals", "Generation"],
        )
        for index in range(tabs.count()):
            scroll = tabs.widget(index).findChild(QtWidgets.QScrollArea, "ConfigScroll")
            if index in (0, 1, 2):
                self.assertIsNone(scroll)
                continue
            self.assertIsNotNone(scroll)
            self.assertTrue(scroll.widgetResizable())
        tabs.setCurrentIndex(2)
        self.window.resize(960, 640)
        wait_for_idle(self.app)
        table = self.window.config_page.signals_editor.table
        header_top = table.horizontalHeader().mapTo(tabs, QtCore.QPoint()).y()
        table.verticalScrollBar().setValue(table.verticalScrollBar().maximum())
        wait_for_idle(self.app)
        self.assertEqual(table.horizontalHeader().mapTo(tabs, QtCore.QPoint()).y(), header_top)
        last_cell = table.visualRect(table.model().index(table.rowCount() - 1, 0))
        self.assertTrue(table.viewport().rect().intersects(last_cell))
        self.assertLessEqual(last_cell.bottom(), table.viewport().rect().bottom())

    def test_lane_mapping_fills_editor_and_preserves_overflow_access(self):
        page = self.window.config_page
        page.tabs.setCurrentIndex(1)
        editor = page.mapping_editor
        self.assertEqual(editor.table.width(), editor.width())
        editor.lane_count.setValue(32)
        wait_for_idle(self.app)
        self.assertGreater(editor.table.horizontalScrollBar().maximum(), 0)
        editor.table.horizontalScrollBar().setValue(editor.table.horizontalScrollBar().maximum())
        last_lane = editor.table.visualRect(editor.table.model().index(0, 32))
        self.assertTrue(editor.table.viewport().rect().intersects(last_lane))
        editor.lane_count.setValue(2)
        wait_for_idle(self.app)
        self.assertEqual(editor.table.horizontalScrollBarPolicy(), QtCore.Qt.ScrollBarAlwaysOff)
        self.assertEqual(editor.table.rowHeight(0), page.controllers_editor.table.rowHeight(0))
        page.mark_saved()  # Discard this test's lane-count changes before closing.

    def test_log_auto_scroll_clear_and_splitter_toggle(self):
        self.window.show_log()
        log_panel = self.window.log_panel
        for index in range(30):
            log_panel.append_log(f"line {index}")
        wait_for_idle(self.app)
        bar = log_panel.output.verticalScrollBar()
        self.assertEqual(bar.value(), bar.maximum())
        log_panel.clear_btn.click()
        wait_for_idle(self.app)
        self.assertEqual(log_panel.output.toPlainText(), "")

        self.window.toggle_log()
        wait_for_idle(self.app)
        self.assertEqual(self.window.content_splitter.sizes()[1], 0)
        self.window.toggle_log()
        wait_for_idle(self.app)
        self.assertGreater(self.window.content_splitter.sizes()[1], 0)

    def test_artifacts_is_pure_floating_drawer(self):
        page = self.window.config_page
        panel = page.artifacts_panel
        self.assertIsInstance(panel, ArtifactsPanel)
        self.assertIs(panel.parent(), page)
        self.assertFalse(panel.isVisible())
        shown = QtTest.QSignalSpy(page._artifacts_animation.finished)
        page.toggle_artifacts()
        self.assertTrue(shown.wait(1000))
        self.assertEqual(panel.geometry().right(), page.rect().right())
        self.assertEqual(panel.geometry().top(), 0)
        self.assertEqual(panel.height(), page.height())
        self.assertEqual(page.tabs.maximumWidth(), QtWidgets.QWIDGETSIZE_MAX)
        self.assertEqual(len(panel.toolbar_buttons), 9)
        toolbar = panel.findChild(QtWidgets.QWidget, "ArtifactsToolbar")
        toolbar_margins = toolbar.layout().contentsMargins()
        self.assertEqual(
            (
                toolbar_margins.left(),
                toolbar_margins.top(),
                toolbar_margins.right(),
                toolbar_margins.bottom(),
            ),
            (16, 0, 16, 0),
        )
        self.assertEqual(toolbar.layout().spacing(), 0)
        self.assertEqual(
            panel.path_button.mapTo(panel, QtCore.QPoint()).x(),
            panel.toolbar.mapTo(panel, QtCore.QPoint()).x() + 16,
        )
        self.assertEqual(panel.close_button.geometry().right(), toolbar.width() - 17)
        for button in panel.toolbar_buttons:
            self.assertEqual(button.height(), button_height(button))
            if button is not panel.path_button:
                self.assertEqual(button.width(), button.height())
            self.assertEqual(button.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE))

        self.assertEqual(panel.content_layout.spacing(), 12)
        self.assertIsInstance(panel.preview, QtWidgets.QPlainTextEdit)
        self.assertIs(panel.path_button.parent(), toolbar)

    def test_artifact_toolbar_and_gutter_use_github_surfaces(self):
        page = self.window.config_page
        shown = QtTest.QSignalSpy(page._artifacts_animation.finished)
        page.toggle_artifacts()
        self.assertTrue(shown.wait(1000))
        toolbar = page.artifacts_panel.toolbar
        self.assertTrue(toolbar.testAttribute(QtCore.Qt.WA_StyledBackground))
        image = page.artifacts_panel.grab().toImage()
        for y in (2, toolbar.height() - 2):
            point = toolbar.mapTo(page.artifacts_panel, QtCore.QPoint(toolbar.width() // 2, y))
            self.assertEqual(image.pixelColor(point).name(), BG_ARTIFACTS_HEADER.lower())
        gutter = page.artifacts_panel.preview.line_numbers
        gutter_image = gutter.grab().toImage()
        self.assertEqual(gutter_image.pixelColor(2, 2).name(), BG_ARTIFACTS.lower())
        self.assertEqual(gutter_image.pixelColor(gutter.width() - 1, 2).name(), BG_ARTIFACTS.lower())

    def test_config_header_has_twelve_pixel_gap_before_tabs(self):
        page = self.window.config_page
        gap = page.config_area.geometry().top() - (page.header.geometry().bottom() + 1)
        self.assertEqual(gap, 12)

    def test_config_tabs_fit_scaled_labels_including_generation(self):
        tabs = self.window.config_page.tabs
        bar = tabs.tabBar()
        page = self.window.config_page
        self.assertFalse(bar.drawBase())
        self.assertEqual(bar.elideMode(), QtCore.Qt.ElideNone)
        self.assertEqual(
            bar.mapTo(page, QtCore.QPoint()).x(),
            page.header.project_icon.mapTo(page, QtCore.QPoint()).x(),
        )
        for selected in range(tabs.count()):
            tabs.setCurrentIndex(selected)
            wait_for_idle(self.app)
            for index in range(tabs.count()):
                font = QtGui.QFont(bar.font())
                font.setBold(True)
                width = QtGui.QFontMetrics(font).horizontalAdvance(tabs.tabText(index))
                option = QtWidgets.QStyleOptionTab()
                bar.initStyleOption(option, index)
                font_metrics = QtGui.QFontMetrics(font)
                styled_size = bar.style().sizeFromContents(
                    QtWidgets.QStyle.CT_TabBarTab, option,
                    QtCore.QSize(max(width, font_metrics.boundingRect(tabs.tabText(index)).width()),
                                 font_metrics.height()), bar,
                )
                self.assertGreaterEqual(bar.tabRect(index).width(), styled_size.width())
                text_rect = bar.style().subElementRect(
                    QtWidgets.QStyle.SE_TabBarTabText, option, bar,
                )
                self.assertGreaterEqual(text_rect.width(), width)
                self.assertGreaterEqual(
                    text_rect.height(), QtGui.QFontMetrics(font).height() + 4,
                )
            self.assertLessEqual(bar.tabRect(tabs.count() - 1).right(), bar.width() - 1)

    def test_controller_table_alignment_and_context_insertion_undo(self):
        page = self.window.config_page
        editor = page.controllers_editor
        table = editor.table
        original_count = table.rowCount()
        self.assertEqual(table.width(), editor.width())
        widths = [table.columnWidth(index) for index in range(3)]
        self.assertLessEqual(max(widths) - min(widths), 1)
        self.assertTrue(table.showGrid())
        self.assertEqual(table.item(0, 0).textAlignment(), int(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter))
        self.assertEqual(table.horizontalHeaderItem(1).textAlignment(),
                         int(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter))
        original_height = table.height()
        self.assertFalse(hasattr(editor, "add_row_btn"))
        editor.add_row()
        wait_for_idle(self.app)
        self.assertEqual(table.rowCount(), original_count + 1)
        self.assertGreater(table.height(), original_height)
        self.assertTrue(page.dirty)
        self.assertTrue(page.header.status_badge.isVisible())
        self.assertEqual(page.header.status_badge.text(), "未保存")
        self.assertIs(page.header.status_badge, page.header.save_state)
        page.undo()
        wait_for_idle(self.app)
        self.assertEqual(table.rowCount(), original_count)
        self.assertFalse(page.dirty)
        self.assertTrue(page.header.status_badge.isVisible())
        self.assertEqual(page.header.status_badge.text(), "已保存")
        editor.set_rows([
            {"ctrl_id": index, "ctrl_name": f"Ctrl{index}", "max_width": 4}
            for index in range(15)
        ])
        wait_for_idle(self.app)
        self.assertEqual(table.rowCount(), 15)
        self.assertGreater(table.verticalScrollBar().maximum(), 0)

    def test_selected_table_cells_use_dark_text_on_blue_for_both_row_colors(self):
        table = self.window.config_page.signals_editor.table
        table.ensurePolished()

        class RecordingPainter(QtGui.QPainter):
            def drawText(self, *args):
                self.text_color = self.pen().color().name()
                return super().drawText(*args)

        for row in (0, 1):
            option = QtWidgets.QStyleOptionViewItem()
            option.initFrom(table)
            option.widget = table
            option.rect = QtCore.QRect(0, 0, 400, 48)
            option.state |= QtWidgets.QStyle.State_Selected | QtWidgets.QStyle.State_Active
            option.palette.setColor(QtGui.QPalette.HighlightedText, QtCore.Qt.white)
            if row:
                option.features |= QtWidgets.QStyleOptionViewItem.Alternate
            image = QtGui.QImage(400, 48, QtGui.QImage.Format_ARGB32)
            image.fill(QtCore.Qt.transparent)
            painter = RecordingPainter(image)
            try:
                table.itemDelegate().paint(painter, option, table.model().index(row, 0))
                self.assertEqual(painter.text_color, TEXT_MAIN.lower())
            finally:
                painter.end()
            self.assertEqual(image.pixelColor(397, 24).name(), PRIMARY_SOFT.lower())

    def test_table_selection_hover_and_alternate_rows_have_distinct_colors(self):
        table = self.window.config_page.controllers_editor.table
        table.selectRow(0)
        table.clearFocus()
        def hover_row(row):
            point = table.visualRect(table.model().index(row, 1)).center()
            self.app.sendEvent(table.viewport(), QtGui.QMouseEvent(
                QtCore.QEvent.MouseMove, QtCore.QPointF(point),
                QtCore.Qt.NoButton, QtCore.Qt.NoButton, QtCore.Qt.NoModifier,
            ))
            self.assertEqual(table._hovered_row, row)

        hover_row(2)
        self.app.processEvents()
        image = table.viewport().grab().toImage()
        from plm.frontend.qt.styles import tokens
        selected, alternate, hovered = (
            value.lower() for value in (tokens.PRIMARY_SOFT, tokens.BG_ALTERNATE, tokens.BG_SUBTLE)
        )
        self.assertEqual(len({selected, alternate, hovered, tokens.BG_SURFACE.lower()}), 4)
        for row, color in ((0, selected), (1, alternate), (2, hovered)):
            for column in range(table.columnCount()):
                rect = table.visualRect(table.model().index(row, column))
                self.assertEqual(image.pixelColor(rect.right() - 4, rect.center().y()).name(), color)

        # Moving onto the selected row keeps its blue background.
        hover_row(0)
        self.app.processEvents()
        image = table.viewport().grab().toImage()
        rect = table.visualRect(table.model().index(0, 1))
        self.assertEqual(image.pixelColor(rect.right() - 4, rect.center().y()).name(), selected)

    def test_artifacts_drag_visibility_and_maximize(self):
        page = self.window.config_page
        self.assertFalse(page.artifacts_panel.isVisible())
        shown = QtTest.QSignalSpy(page._artifacts_animation.finished)
        page.toggle_artifacts()
        self.assertTrue(page.artifacts_panel.isVisible())
        self.assertTrue(shown.wait(1000))
        original_width = page.artifacts_panel.width()
        page.artifacts_panel.widthRequested.emit(original_width + 60)
        self.assertEqual(page.artifacts_panel.width(), original_width + 60)

        page.toggle_artifacts_maximized()
        self.assertEqual(page.artifacts_panel.width(), page.width())
        self.window.resize(self.window.width() + 60, self.window.height() + 40)
        wait_for_idle(self.app)
        self.assertEqual(page.artifacts_panel.geometry(), page.rect())
        page.toggle_artifacts_maximized()
        self.assertEqual(page.artifacts_panel.width(), original_width + 60)
        hidden = QtTest.QSignalSpy(page._artifacts_animation.finished)
        self.window.artifacts_toggle_button.click()
        self.assertTrue(hidden.wait(1000))
        self.assertFalse(page.artifacts_panel.isVisible())
        self.assertEqual(page._artifacts_animation.duration(), 200)

    def test_header_panel_button_feedback_has_rounded_corners(self):
        button = self.window.artifacts_toggle_button
        self.window.activateWindow()
        button.setFocus(QtCore.Qt.TabFocusReason)
        wait_for_idle(self.app)
        self.assertTrue(button.hasFocus())
        image = button.grab().toImage()
        self.assertEqual(image.pixelColor(2, button.height() // 2).name(), BG_FOCUS.lower())
        self.assertNotEqual(image.pixelColor(0, 0), image.pixelColor(2, button.height() // 2))
        button.setDown(True)
        image = button.grab().toImage()
        self.assertEqual(image.pixelColor(2, button.height() // 2).name(), BORDER.lower())
        self.assertNotEqual(image.pixelColor(0, 0), image.pixelColor(2, button.height() // 2))
        button.setDown(False)

    def test_header_panel_buttons_stay_fixed_and_clickable_above_drawer(self):
        page = self.window.config_page
        buttons = (self.window.title_bar.collapse_btn, self.window.log_toggle_button,
                   self.window.artifacts_toggle_button)
        title_bar = self.window.title_bar
        log_button = self.window.log_toggle_button
        sidebar_button = self.window.title_bar.collapse_btn
        self.assertIs(log_button.parentWidget(), title_bar)
        self.assertGreater(log_button.x(), sidebar_button.geometry().right())
        self.assertEqual(log_button.geometry().center().y(), sidebar_button.geometry().center().y())
        self.assertIs(buttons[2].parentWidget(), title_bar)
        self.assertGreater(buttons[2].x(), log_button.geometry().right())
        self.assertEqual(buttons[2].geometry().center().y(), sidebar_button.geometry().center().y())
        positions = [button.mapTo(title_bar, QtCore.QPoint()) for button in buttons]
        shown = QtTest.QSignalSpy(page._artifacts_animation.finished)
        self.window.artifacts_toggle_button.click()
        self.assertTrue(shown.wait(1000))
        self.assertTrue(page.artifacts_panel.close_button.isVisible())
        for maximized in (False, True):
            if maximized:
                page.toggle_artifacts_maximized()
            page.tabs.setCurrentIndex(2)
            wait_for_idle(self.app)
            for button, position in zip(buttons, positions):
                self.assertEqual(button.mapTo(title_bar, QtCore.QPoint()), position)
                point = button.mapTo(title_bar, button.rect().center())
                self.assertIs(title_bar.childAt(point), button)
            action_y = page.artifacts_panel.maximize_button.mapTo(page, page.artifacts_panel.maximize_button.rect().center()).y()
            for button in page.artifacts_panel.toolbar_buttons:
                if button.isVisible():
                    self.assertEqual(button.mapTo(page, button.rect().center()).y(), action_y)
                    point = button.mapTo(page, button.rect().center())
                    self.assertIs(page.childAt(point), button)
        hidden = QtTest.QSignalSpy(page._artifacts_animation.finished)
        QtTest.QTest.mouseClick(page.artifacts_panel.close_button, QtCore.Qt.LeftButton)
        self.assertTrue(hidden.wait(1000))
        self.assertFalse(page.artifacts_panel.isVisible())

        log_visible = self.window.log_panel.isVisible()
        log_button.click()
        wait_for_idle(self.app)
        self.assertNotEqual(self.window.log_panel.isVisible(), log_visible)
        log_button.click()
        wait_for_idle(self.app)
        self.assertEqual(self.window.log_panel.isVisible(), log_visible)

    def test_artifact_file_selection_and_copy_path(self):
        panel = self.window.config_page.artifacts_panel
        with tempfile.TemporaryDirectory() as directory:
            generated = Path(directory).resolve() / "generated.sv"
            generated.write_text("module generated; endmodule\n", encoding="utf-8")
            panel.set_files([generated], Path(directory).resolve())
            wait_for_idle(self.app)
            self.assertEqual(len(panel.selection.files), 1)
            self.assertEqual(panel.preview.toPlainText(), generated.read_text())
            panel.copy_path()
            self.assertEqual(QtWidgets.QApplication.clipboard().text(), str(generated))

    def test_artifact_open_uses_configured_editor(self):
        settings = self.store._settings
        original = settings.value("tools/editor_path")
        try:
            with tempfile.TemporaryDirectory() as directory:
                editor = Path(directory).resolve() / "custom-editor"
                editor.write_text("editor", encoding="utf-8")
                settings.setValue("tools/editor_path", str(editor))
                generated = Path(directory).resolve() / "generated.sv"
                generated.write_text("module generated; endmodule\n", encoding="utf-8")
                self.window.config_page.artifacts_panel.set_files([generated], Path(directory).resolve())
                wait_for_idle(self.app)
                panel = self.window.config_page.artifacts_panel
                with patch("subprocess.Popen") as popen:
                    panel.open_in_editor()
                    wait_for_idle(self.app)
                popen.assert_called_once_with([str(editor), str(generated)])
        finally:
            if original is None:
                settings.remove("tools/editor_path")
            else:
                settings.setValue("tools/editor_path", original)
            settings.sync()

    def test_settings_and_docs_open_secondary_pages(self):
        nav = self.window.nav_panel
        nav.settings_btn.click()
        wait_for_idle(self.app)
        overlay = self.window.view_stack.currentWidget()
        self.assertIsNotNone(overlay)
        self.assertTrue(overlay.isVisible())
        self.assertEqual(overlay.page, "settings")
        self.assertEqual(overlay.title_label.text(), "设置")
        self.assertEqual(overlay.size(), self.window.view_stack.contentsRect().size())
        self.assertEqual(overlay.back_btn.text(), "设置")
        self.assertEqual(overlay.back_btn.height(), CONTROL_HEIGHT)
        self.assertGreater(overlay.back_btn.width(), 32)
        self.assertEqual(overlay.back_btn.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE))
        panel = overlay.findChild(QtWidgets.QWidget, "SecondaryPagePanel")
        self.assertEqual(panel.width(), min(SETTINGS_MAX_WIDTH, overlay.width() - 56))
        self.assertEqual(panel.mapTo(overlay, QtCore.QPoint()).y(), 29)
        self.assertEqual(
            panel.mapTo(overlay, panel.rect().center()).x(),
            overlay.rect().center().x(),
        )
        divider = overlay.findChild(QtWidgets.QFrame, "SecondaryTabDivider")
        self.assertEqual(divider.height(), 1)
        for row in overlay.setting_rows.values():
            self.assertGreaterEqual(row.height(), 64)

        nav.docs_btn.click()
        wait_for_idle(self.app)
        overlay = self.window.view_stack.currentWidget()
        self.assertIsNotNone(overlay)
        self.assertEqual(overlay.page, "docs")
        self.assertEqual(overlay.title_label.text(), "文档")
        overlay.back_btn.click()
        wait_for_idle(self.app)
        self.assertIs(self.window.view_stack.currentWidget(), self.window.main_container)

        nav.settings_btn.click()
        wait_for_idle(self.app)
        overlay = self.window.view_stack.currentWidget()
        QtTest.QTest.keyClick(overlay, QtCore.Qt.Key_Escape)
        wait_for_idle(self.app)
        self.assertIs(self.window.view_stack.currentWidget(), self.window.main_container)

    def test_settings_are_saved(self):
        settings = self.store._settings
        original = {
            key: settings.value(key)
            for key in (
                "tools/editor_path",
            )
        }
        try:
            self.window.nav_panel.settings_btn.click()
            wait_for_idle(self.app)
            wait_for_idle(self.app)
            overlay = self.window.view_stack.currentWidget()
            overlay.editor_path_edit.setText("custom-editor")
            overlay.save_settings_btn.click()
            wait_for_idle(self.app)
            wait_for_idle(self.app)

            self.assertEqual(
                settings.value("tools/editor_path", type=str), "custom-editor"
            )
            self.assertEqual(overlay.settings_status.text(), "设置已保存")
        finally:
            for key, value in original.items():
                if value is None:
                    settings.remove(key)
                else:
                    settings.setValue(key, value)
            settings.sync()

    def test_docs_menu_loads_real_markdown_sections(self):
        with tempfile.TemporaryDirectory() as directory:
            docs_dir = Path(directory).resolve()
            (docs_dir / "qt_frontend_guide.md").write_text(
                "# Frontend Guide\n\n"
                "| Name | Meaning |\n|---|---|\n| ctrl_id | Controller ID |\n\n"
                "操作：右键菜单增删行。\n\n"
                "```text\nmode=0  lane0=0-0\n        ↓\n       CtrlA[0]\n```\n",
                encoding="utf-8",
            )
            (docs_dir / "tool_usage.md").write_text(
                "# Tool Usage\n\n"
                "## 2. 配置文件格式（`config/` 下三个 CSV）\n\n"
                "Controller configuration content.\n\n"
                "## 3. `plm generate`：生成匹配的 RTL 与 testbench\n\n"
                "Generation command content.\n",
                encoding="utf-8",
            )
            with patch("plm.frontend.qt.views.documentation_page.DOCS_DIR", docs_dir):
                self.window.nav_panel.docs_btn.click()
                wait_for_idle(self.app)
                wait_for_idle(self.app)
                overlay = self.window.view_stack.currentWidget()
                self.assertIn("Frontend Guide", overlay.doc_browser.toPlainText())
                tables = [
                    frame
                    for frame in overlay.doc_browser.document()
                    .rootFrame()
                    .childFrames()
                    if isinstance(frame, QtGui.QTextTable)
                ]
                self.assertTrue(tables)
                self.assertEqual(tables[0].format().width().type(), QtGui.QTextLength.PercentageLength)
                self.assertEqual(tables[0].format().width().rawValue(), 100)
                self.assertEqual(
                    overlay.doc_browser.verticalScrollBarPolicy(),
                    QtCore.Qt.ScrollBarAsNeeded,
                )

                overlay.menu_buttons[1].click()
                wait_for_idle(self.app)
                self.assertIn(
                    "Controller configuration content",
                    overlay.doc_browser.toPlainText(),
                )
                self.assertNotIn("Tool Usage", overlay.doc_browser.toPlainText())

                overlay.menu_buttons[2].click()
                wait_for_idle(self.app)
                self.assertIn(
                    "Generation command content", overlay.doc_browser.toPlainText()
                )
                self.assertNotIn(
                    "Controller configuration content",
                    overlay.doc_browser.toPlainText(),
                )

    def test_required_lucide_assets_exist_and_render(self):
        icon_names = (
            "layout-dashboard",
            "arrow-left",
            "arrow-up",
            "arrow-down",
            "sun",
            "moon",
            "check",
            "panel-left",
            "x",
            "panel-bottom",
            "panel-right",
            "square-pen",
            "save",
            "file-text",
            "settings",
            "trash-2",
            "archive",
            "folder",
            "folder-open",
            "pin",
            "pencil",
            "refresh-cw",
            "git-compare",
            "search",
            "link",
            "file-x",
            "file-code-corner",
            "arrow-right-left",
            "file-braces-corner",
            "more-horizontal",
            "maximize",
            "rocket",
            "minus",
            "square",
            "copy",
            "chevron-down",
            "chevron-right",
            "tree-chevron-down",
        )
        self.assertEqual(len(icon_names), 38)
        self.assertEqual(
            {path.stem for path in LUCIDE_ICON_DIR.glob("*.svg")},
            set(icon_names),
        )
        for name in icon_names:
            self.assertTrue((LUCIDE_ICON_DIR / f"{name}.svg").is_file())
            self.assertFalse(load_lucide_icon(name).isNull())

    def test_global_stylesheet_contains_key_visual_rules(self):
        self.assertIn("background-color: #FFFFFF", APP_QSS)
        self.assertIn("border-radius: 16px", APP_QSS)
        self.assertIn("QSplitter::handle", APP_QSS)
        self.assertIn("QTabWidget#ConfigTabs QTabBar::tab:selected", APP_QSS)
        self.assertIn("QScrollBar::handle:vertical", APP_QSS)
        self.assertIn('QWidget#WindowShell[maximized="true"]', APP_QSS)
        self.assertIn("QFrame#WindowTitleBar", APP_QSS)
        self.assertIn("background-color: #DCFCE7", APP_QSS)
        self.assertIn(f"background-color: {PRIMARY_SOFT}", APP_QSS)
        self.assertEqual(self.window.config_page.CORNER_RADII[0], 16)


if __name__ == "__main__":
    unittest.main()
