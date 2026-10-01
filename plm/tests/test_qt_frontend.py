import os
import unittest
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.main_window import (
    APP_QSS,
    ICON_SIZE,
    LUCIDE_ICON_DIR,
    ArtifactsPanel,
    ConfigHeader,
    DragHandle,
    FileDiffCard,
    LogPanel,
    MainWindow,
    NavPanel,
    ProjectList,
    load_lucide_icon,
)


class QtFrontendLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setFont(QtGui.QFont("Segoe UI", 10))
        cls.app.setStyleSheet(APP_QSS)

    def setUp(self):
        self.window = MainWindow()
        self.window.show()
        self.app.processEvents()

    def tearDown(self):
        self.window.close()
        self.window.deleteLater()
        self.app.processEvents()

    def test_native_window_and_nested_splitters(self):
        self.assertFalse(self.window.windowFlags() & QtCore.Qt.FramelessWindowHint)
        self.assertEqual(self.window.windowTitle(), "plmConsultant")
        self.assertIsInstance(self.window.nav_panel, NavPanel)
        self.assertEqual(self.window.nav_panel.width(), 260)
        self.assertIs(self.window.centralWidget(), self.window.main_splitter)
        self.assertEqual(self.window.main_splitter.orientation(), QtCore.Qt.Horizontal)
        self.assertEqual(self.window.content_splitter.orientation(), QtCore.Qt.Vertical)
        self.assertEqual(self.window.main_splitter.handleWidth(), 4)
        self.assertFalse(self.window.main_splitter.childrenCollapsible())
        self.assertEqual(self.window.main_splitter.count(), 2)
        self.assertEqual(self.window.nav_panel.minimumWidth(), 200)
        self.assertEqual(self.window.nav_panel.maximumWidth(), 400)
        self.assertEqual(
            self.window.main_splitter.handle(1).cursor().shape(),
            QtCore.Qt.SplitHCursor,
        )
        self.assertEqual(self.window.content_splitter.handleWidth(), 1)
        self.assertIsInstance(self.window.log_panel, LogPanel)
        self.assertEqual(
            self.window.nav_panel.collapse_btn.iconSize(),
            QtCore.QSize(ICON_SIZE, ICON_SIZE),
        )

    def test_nav_toggle_collapses_and_restores_sidebar(self):
        nav = self.window.nav_panel
        stable_y_positions = {
            "toggle": nav.collapse_btn.mapTo(nav, QtCore.QPoint()).y(),
            "new": nav.new_chat_btn.mapTo(nav, QtCore.QPoint()).y(),
            "save": nav.save_btn.mapTo(nav, QtCore.QPoint()).y(),
            "project": nav.project_list.project_widgets[0].header.mapTo(
                nav, QtCore.QPoint()
            ).y(),
            "docs": nav.docs_btn.mapTo(nav, QtCore.QPoint()).y(),
        }
        nav.collapse_btn.click()
        self.assertTrue(nav.is_animating)
        nav.collapse_btn.click()
        self.assertTrue(nav._target_collapsed)
        QtTest.QTest.qWait(100)
        self.assertGreater(nav.width(), 56)
        self.assertLess(nav.width(), 260)
        self.assertEqual(
            self.window.content_splitter.geometry().left()
            - (nav.geometry().right() + 1),
            4,
        )
        QtTest.QTest.qWait(250)
        self.assertFalse(nav.is_animating)
        self.assertTrue(nav.is_collapsed)
        self.assertEqual(nav.width(), 56)
        self.assertFalse(self.window.main_splitter.handle(1).isEnabled())
        self.assertFalse(nav.project_list.isVisible())
        self.assertFalse(nav.logo_label.isVisible())
        self.assertEqual(nav.new_chat_btn.objectName(), "NavIconBtn")
        self.assertEqual(nav.save_btn.objectName(), "NavIconBtn")
        self.assertEqual(
            self.window.content_splitter.geometry().left()
            - (nav.geometry().right() + 1),
            4,
        )
        aligned_widgets = [
            nav.collapse_btn,
            nav.new_chat_btn,
            nav.save_btn,
            *nav.collapsed_project_buttons,
            nav.collapsed_settings_btn,
            nav.collapsed_docs_btn,
        ]
        center_positions = {
            widget.mapTo(nav, widget.rect().center()).x() for widget in aligned_widgets
        }
        self.assertEqual(center_positions, {(nav.width() - 1) // 2})
        self.assertEqual(
            nav.collapse_btn.mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["toggle"],
        )
        self.assertEqual(
            nav.new_chat_btn.mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["new"],
        )
        self.assertEqual(
            nav.save_btn.mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["save"],
        )
        self.assertEqual(
            nav.collapsed_project_buttons[0].mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["project"],
        )
        self.assertEqual(
            nav.collapsed_docs_btn.mapTo(nav, QtCore.QPoint()).y(),
            stable_y_positions["docs"],
        )
        self.assertLess(
            nav.collapsed_settings_btn.mapTo(nav, QtCore.QPoint()).y(),
            nav.collapsed_docs_btn.mapTo(nav, QtCore.QPoint()).y(),
        )

        nav.collapse_btn.click()
        self.assertTrue(nav.project_list.isVisible())
        QtTest.QTest.qWait(350)
        self.assertFalse(nav.is_collapsed)
        self.assertEqual(nav.width(), 260)
        self.assertEqual(nav.minimumWidth(), 200)
        self.assertEqual(nav.maximumWidth(), 400)
        self.assertTrue(self.window.main_splitter.handle(1).isEnabled())
        self.assertEqual(nav.new_chat_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.save_btn.objectName(), "NavActionButton")

    def test_nav_splitter_resizes_only_while_expanded(self):
        nav = self.window.nav_panel
        self.window.main_splitter.moveSplitter(100, 1)
        self.app.processEvents()
        self.assertEqual(nav.width(), 200)

        self.window.main_splitter.moveSplitter(500, 1)
        self.app.processEvents()
        self.assertEqual(nav.width(), 400)

        self.window.main_splitter.moveSplitter(320, 1)
        self.app.processEvents()
        self.assertEqual(nav.width(), 320)

        nav.collapse_btn.click()
        QtTest.QTest.qWait(250)
        self.window.main_splitter.moveSplitter(300, 1)
        self.app.processEvents()
        self.assertEqual(nav.width(), 56)

    def test_nav_actions_projects_and_drag_configuration(self):
        nav = self.window.nav_panel
        self.assertEqual(nav.new_chat_btn.text(), "新对话")
        self.assertEqual(nav.save_btn.text(), "保存")
        self.assertEqual(nav.docs_btn.text(), "Docs")
        self.assertEqual(nav.settings_btn.text(), "Settings")
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
        self.assertEqual(first_project.folder_icon.size(), QtCore.QSize(20, 20))
        self.assertEqual(first_project.header.layout().contentsMargins().left(), 0)
        self.assertEqual(
            first_project.header.layout().itemAt(1).spacerItem().sizeHint().width(), 8
        )
        self.assertEqual(
            first_project.header.layout().itemAt(5).spacerItem().sizeHint().width(), 4
        )
        self.assertEqual(first_project.project_name_label.text(), first_project.project_name)
        self.assertEqual(first_project.header.text(), "")
        self.assertFalse(first_project.header.isCheckable())
        self.assertFalse(hasattr(first_project, "session_buttons"))
        self.assertEqual(
            first_project.findChildren(QtWidgets.QPushButton, "SessionButton"), []
        )
        self.assertEqual(first_project.archive_btn.size(), QtCore.QSize(24, 24))
        self.assertEqual(first_project.more_btn.size(), QtCore.QSize(24, 24))
        self.assertTrue(first_project.archive_btn.isHidden())
        self.assertTrue(first_project.more_btn.isHidden())
        hover_card = nav.project_list.hover_card
        self.assertEqual(hover_card.width(), 260)
        self.assertEqual(nav.project_list._hover_timer.interval(), 400)
        hover_card.set_project(first_project.project_name, first_project.project_path)
        self.assertEqual(hover_card.name_label.text(), first_project.project_name)
        self.assertEqual(hover_card.project_path, first_project.project_path)
        for icon_name in ("folder", "folder-open", "pin", "external-link"):
            self.assertTrue((LUCIDE_ICON_DIR / f"{icon_name}.svg").is_file())
        expected_configs = {"bifurcate", "dpr", "finegrain", "maxpclk", "quad"}
        self.assertTrue(expected_configs.issubset(project_names))
        self.assertNotIn("__pycache__", project_names)
        self.assertNotIn("ffe", project_names)
        nav.set_active("docs")
        self.assertTrue(nav.docs_btn.property("selected"))
        nav.set_active("settings")
        self.assertTrue(nav.settings_btn.property("selected"))

    def test_project_list_is_flat_and_project_click_does_not_expand(self):
        project_list = self.window.nav_panel.project_list
        initial_count = project_list.count()
        self.assertGreater(initial_count, 0)
        for row, widget in enumerate(project_list.project_widgets):
            self.assertEqual(project_list.item(row).sizeHint().height(), 32)
            self.assertEqual(widget.layout().count(), 1)
            self.assertIs(widget.layout().itemAt(0).widget(), widget.header)
            self.assertFalse(widget.header.isCheckable())

        target = project_list.project_widgets[-1]
        target.header.click()
        self.assertEqual(project_list.count(), initial_count)
        self.assertEqual(project_list.selected_project_name, target.project_name)
        self.assertTrue(target.header.property("selected"))

    def test_expanded_nav_icons_share_one_left_edge(self):
        nav = self.window.nav_panel
        first_project = nav.project_list.project_widgets[0]
        margins = nav.layout().contentsMargins()
        self.assertEqual(
            (margins.left(), margins.top(), margins.right(), margins.bottom()),
            (12, 8, 12, 8),
        )
        for layout in (
            nav.brand_layout,
            nav.new_chat_row_layout,
            nav.save_row_layout,
            first_project.header.layout(),
            nav.settings_row_layout,
            nav.docs_row_layout,
        ):
            margins = layout.contentsMargins()
            self.assertEqual(
                (margins.left(), margins.top(), margins.right(), margins.bottom()),
                (0, 0, 0, 0),
            )

        aligned_widgets = (
            nav.logo_label,
            nav.new_chat_btn,
            nav.save_btn,
            first_project.folder_icon,
            nav.settings_btn,
            nav.docs_btn,
        )
        self.assertEqual(
            {widget.mapTo(nav, QtCore.QPoint()).x() for widget in aligned_widgets},
            {12},
        )
        icon_pixmaps = (
            nav.logo_label.pixmap(),
            nav.new_chat_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
            nav.save_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
            first_project.folder_icon.pixmap(),
            nav.settings_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
            nav.docs_btn.icon().pixmap(ICON_SIZE, ICON_SIZE),
        )
        self.assertEqual(
            {
                QtGui.QRegion(pixmap.mask()).boundingRect().left()
                for pixmap in icon_pixmaps
            },
            {0},
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
        settings = QtCore.QSettings("plm", "plmConsultant")
        key = "navigation/recent_project"
        original = settings.value(key, None)
        try:
            settings.setValue(key, "dpr")
            restored = MainWindow()
            self.assertEqual(restored.nav_panel.current_project_name, "dpr")
            self.assertEqual(restored.config_page.header.title_label.text(), "dpr")
            restored.close()
            restored.deleteLater()

            settings.setValue(key, "missing-project")
            fallback = MainWindow()
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

    def test_config_header_inline_rename_save_and_cancel(self):
        header = self.window.config_page.header
        self.assertIsInstance(header, ConfigHeader)
        self.assertEqual(header.height(), 56)
        header.enter_edit_mode()
        self.assertTrue(header.title_edit.isVisible())
        header.title_edit.setText("新的会话名称")
        header.title_edit.returnPressed.emit()
        self.assertEqual(header.title_label.text(), "新的会话名称")
        self.assertEqual(self.window.windowTitle(), "plmConsultant")

        header.enter_edit_mode()
        header.title_edit.setText("不应保存")
        header.title_edit.escapePressed.emit()
        self.assertEqual(header.title_label.text(), "新的会话名称")

    def test_project_row_actions_and_nav_signals(self):
        nav = self.window.nav_panel
        project_list = nav.project_list
        first_project = project_list.project_widgets[0]

        QtWidgets.QApplication.sendEvent(
            first_project.header, QtCore.QEvent(QtCore.QEvent.Enter)
        )
        self.assertTrue(first_project.archive_btn.isVisible())
        self.assertTrue(first_project.more_btn.isVisible())
        QtWidgets.QApplication.sendEvent(
            first_project.header, QtCore.QEvent(QtCore.QEvent.Leave)
        )
        self.assertFalse(first_project.archive_btn.isVisible())
        self.assertFalse(first_project.more_btn.isVisible())

        if len(project_list.project_widgets) > 1:
            second_project = project_list.project_widgets[1]
            project_list.pin_project(second_project)
            self.assertIs(project_list.project_widgets[0], second_project)

        renamed_spy = QtTest.QSignalSpy(nav.project_renamed)
        old_name = first_project.project_name
        with patch.object(
            QtWidgets.QInputDialog,
            "getText",
            return_value=(f"{old_name}-renamed", True),
        ):
            project_list.rename_project(first_project)
        self.assertEqual(first_project.project_name, f"{old_name}-renamed")
        self.assertEqual(len(renamed_spy), 1)

        archive_target = project_list.project_widgets[-1]
        archived_name = archive_target.project_name
        archived_path = archive_target.project_path
        archived_spy = QtTest.QSignalSpy(nav.project_archived)
        with patch.object(
            QtWidgets.QMessageBox,
            "question",
            return_value=QtWidgets.QMessageBox.Yes,
        ):
            project_list.archive_project(archive_target)
        self.assertEqual(len(archived_spy), 1)
        self.assertEqual(archived_spy[0][0], archived_name)
        self.assertTrue(archived_path.exists())

    def test_tabs_and_scrollable_configuration_pages(self):
        tabs = self.window.config_page.tabs
        self.assertEqual(tabs.count(), 4)
        self.assertEqual(
            [tabs.tabText(index) for index in range(tabs.count())],
            ["Controller", "LaneMapping", "Signals", "Generation"],
        )
        for index in range(tabs.count()):
            scroll = tabs.widget(index).findChild(QtWidgets.QScrollArea, "ConfigScroll")
            self.assertIsNotNone(scroll)
            self.assertTrue(scroll.widgetResizable())

    def test_log_auto_scroll_clear_and_splitter_toggle(self):
        log_panel = self.window.log_panel
        for index in range(30):
            log_panel.append_log(f"line {index}")
        self.app.processEvents()
        bar = log_panel.output.verticalScrollBar()
        self.assertEqual(bar.value(), bar.maximum())
        log_panel.clear_btn.click()
        self.assertEqual(log_panel.output.toPlainText(), "")

        self.window.toggle_log()
        self.app.processEvents()
        self.assertEqual(self.window.content_splitter.sizes()[1], 0)
        self.window.toggle_log()
        self.app.processEvents()
        self.assertGreater(self.window.content_splitter.sizes()[1], 0)

    def test_artifacts_is_absolute_overlay_with_drag_handle(self):
        page = self.window.config_page
        panel = page.artifacts_panel
        handle = page.drag_handle
        self.assertIsInstance(panel, ArtifactsPanel)
        self.assertIsInstance(handle, DragHandle)
        self.assertIs(panel.parent(), page.config_area)
        self.assertIs(handle.parent(), page.config_area)
        self.assertEqual(handle.size(), QtCore.QSize(14, 36))
        self.assertEqual(panel.geometry().right(), page.config_area.rect().right())
        self.assertEqual(
            handle.geometry().left() + handle.width() // 2,
            panel.geometry().left(),
        )
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
        self.assertEqual(toolbar.layout().spacing(), 8)
        for button in panel.toolbar_buttons:
            self.assertEqual(button.size(), QtCore.QSize(24, 24))
            self.assertEqual(button.iconSize(), QtCore.QSize(20, 20))

        content = panel.findChild(QtWidgets.QWidget, "ArtifactsContent")
        self.assertEqual(content.layout().spacing(), 12)

    def test_config_header_has_twelve_pixel_gap_before_tabs(self):
        page = self.window.config_page
        gap = page.config_area.geometry().top() - (page.header.geometry().bottom() + 1)
        self.assertEqual(gap, 12)

    def test_artifacts_drag_visibility_and_maximize(self):
        page = self.window.config_page
        original_width = page.artifacts_panel.width()
        page.handle_artifacts_drag("start", 800)
        page.handle_artifacts_drag("move", 740)
        self.assertEqual(page.artifacts_panel.width(), original_width + 60)
        page.finish_artifacts_drag()
        self.assertIsNone(page.drag_start_global_x)

        page.toggle_artifacts_maximized()
        self.assertEqual(page.artifacts_panel.width(), page.config_area.width())
        self.assertFalse(page.drag_handle.isVisible())
        page.toggle_artifacts_maximized()
        self.assertTrue(page.drag_handle.isVisible())
        page.toggle_artifacts()
        self.assertFalse(page.artifacts_panel.isVisible())
        page.toggle_artifacts()
        self.assertTrue(page.artifacts_panel.isVisible())

    def test_artifact_cards_and_copy_path(self):
        panel = self.window.config_page.artifacts_panel
        cards = panel.findChildren(FileDiffCard)
        self.assertGreaterEqual(len(cards), 3)
        cards[0].copy_path()
        self.assertEqual(
            QtWidgets.QApplication.clipboard().text(), str(cards[0].file_path)
        )

    def test_required_lucide_assets_exist_and_render(self):
        icon_names = (
            "layout-dashboard",
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
            "external-link",
            "refresh-cw",
            "braces",
            "search",
            "link",
            "file",
            "more-horizontal",
            "maximize",
        )
        self.assertEqual(len(icon_names), 23)
        self.assertEqual(
            {path.stem for path in LUCIDE_ICON_DIR.glob("*.svg")},
            set(icon_names),
        )
        for name in icon_names:
            self.assertTrue((LUCIDE_ICON_DIR / f"{name}.svg").is_file())
            self.assertFalse(load_lucide_icon(name).isNull())

    def test_global_stylesheet_contains_key_visual_rules(self):
        self.assertIn("background-color: #F1F1F5", APP_QSS)
        self.assertIn("border-top-left-radius: 8px", APP_QSS)
        self.assertIn("QSplitter::handle", APP_QSS)
        self.assertIn("QTabWidget#ConfigTabs QTabBar::tab:selected", APP_QSS)
        self.assertIn("QScrollBar::handle:vertical", APP_QSS)


if __name__ == "__main__":
    unittest.main()
