import os
import tempfile
import shutil
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import wait_for_idle
from PyQt5 import QtCore, QtGui, QtTest, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.styles.tokens import scale_content_size
from plm.frontend.qt.models import ProjectInfo
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.styles import APP_QSS
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from plm.frontend.qt.views.config_page import ConfigHeader
from plm.frontend.qt.views.log_panel import LogPanel
from plm.frontend.qt.views.nav_panel import NavPanel
from plm.frontend.qt.widgets.common import ICON_SIZE, LUCIDE_ICON_DIR, PROJECT_ROOT, load_lucide_icon
from plm.frontend.qt.widgets.project_item import ProjectItemWidget
from plm.frontend.qt.widgets.project_list import ProjectList


class QtFrontendLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
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
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for config in (PROJECT_ROOT / "test").glob("*/config"):
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

    def tearDown(self):
        self.window.close()
        # processEvents() does not guarantee DeferredDelete delivery. Destroy
        # every top-level test widget before the next test reuses QApplication;
        # otherwise timers/event filters can accumulate across the full suite.
        for widget in self.app.topLevelWidgets():
            widget.deleteLater()
        QtCore.QCoreApplication.sendPostedEvents(
            None, QtCore.QEvent.DeferredDelete
        )
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
        self.assertEqual(self.window.title_bar.height(), 38)
        self.assertEqual(self.window.title_bar.logo_label.size(), QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.assertEqual(self.window.title_bar.title_label.text(), "plmConsultant")
        self.assertIs(
            self.window.nav_panel.collapse_btn.parentWidget(),
            self.window.title_bar,
        )
        self.assertEqual(len(self.window._resize_handles), 8)
        self.assertEqual(
            self.window.title_bar.minimize_btn.iconSize(), QtCore.QSize(scale_content_size(14), scale_content_size(14))
        )
        self.assertEqual(
            self.window.title_bar.maximize_btn.iconSize(), QtCore.QSize(scale_content_size(12), scale_content_size(12))
        )
        self.assertEqual(
            self.window.title_bar.close_btn.iconSize(), QtCore.QSize(scale_content_size(14), scale_content_size(14))
        )
        self.assertEqual(
            self.window.config_page.header.log_btn.size(), QtCore.QSize(46, 48)
        )
        self.assertEqual(
            self.window.config_page.header.artifacts_btn.size(), QtCore.QSize(46, 48)
        )
        self.assertEqual(self.window.content_splitter.orientation(), QtCore.Qt.Vertical)
        self.assertEqual(self.window.nav_panel.minimumWidth(), 260)
        self.assertEqual(self.window.nav_panel.maximumWidth(), 260)
        self.assertEqual(self.window.content_splitter.handleWidth(), 6)
        self.assertIsInstance(self.window.log_panel, LogPanel)
        self.assertEqual(
            self.window.nav_panel.collapse_btn.iconSize(),
            QtCore.QSize(ICON_SIZE, ICON_SIZE),
        )

    def test_nav_toggle_collapses_and_restores_sidebar(self):
        nav = self.window.nav_panel
        stable_y_positions = {
            "new": nav.new_chat_btn.mapTo(nav, QtCore.QPoint()).y(),
            "save": nav.save_btn.mapTo(nav, QtCore.QPoint()).y(),
            "settings": nav.settings_btn.mapTo(nav, QtCore.QPoint()).y(),
            "docs": nav.docs_btn.mapTo(nav, QtCore.QPoint(0, nav.docs_btn.height())).y(),
        }
        collapse_finished = QtTest.QSignalSpy(nav.animation_group.finished)
        nav.collapse_btn.click()
        self.assertTrue(nav.is_animating)
        nav.collapse_btn.click()
        self.assertTrue(nav._target_collapsed)
        self.assertTrue(collapse_finished.wait(1000))
        self.assertFalse(nav.is_animating)
        self.assertTrue(nav.is_collapsed)
        self.assertEqual(nav.width(), 56)
        self.assertFalse(nav.project_list.isVisible())
        self.assertEqual(nav.new_chat_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.save_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.new_chat_btn.height(), 36)
        self.assertEqual(nav.save_btn.height(), 36)
        self.assertEqual(
            self.window.content_splitter.mapTo(self.window.body_container, QtCore.QPoint()).x()
            - (nav.geometry().right() + 1),
            0,
        )
        aligned_widgets = [
            nav.new_chat_btn,
            nav.save_btn,
            nav.settings_btn,
            nav.docs_btn,
        ]
        center_positions = {
            widget.mapTo(nav, widget.rect().center()).x() for widget in aligned_widgets
        }
        self.assertEqual(len(center_positions), 1)
        self.assertEqual(center_positions, {(nav.width() - 1) // 2})
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
        nav.collapse_btn.click()
        self.assertFalse(nav.project_list.isVisible())
        self.assertTrue(expand_finished.wait(1000))
        self.assertTrue(nav.project_list.isVisible())
        self.assertEqual(nav.settings_btn.text(), "Settings")
        self.assertEqual(nav.docs_btn.text(), "Docs")
        self.assertFalse(nav.is_collapsed)
        self.assertEqual(nav.width(), 260)
        self.assertEqual(nav.minimumWidth(), 260)
        self.assertEqual(nav.maximumWidth(), 260)
        self.assertEqual(nav.new_chat_btn.objectName(), "NavActionButton")
        self.assertEqual(nav.save_btn.objectName(), "NavActionButton")

    def test_nav_width_stays_fixed_when_window_resizes(self):
        nav = self.window.nav_panel
        self.window.resize(1200, 760)
        wait_for_idle(self.app)
        self.assertEqual(nav.width(), 260)

        self.window.resize(1600, 1000)
        wait_for_idle(self.app)
        self.assertEqual(nav.width(), 260)

        nav.collapse_btn.click()
        QtTest.QTest.qWait(250)
        self.window.resize(1200, 760)
        wait_for_idle(self.app)
        self.assertEqual(nav.width(), 56)

    def test_nav_actions_projects_and_drag_configuration(self):
        nav = self.window.nav_panel
        self.assertFalse(hasattr(nav, "actionRequested"))
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
        self.assertEqual(first_project.folder_icon.size(), QtCore.QSize(ICON_SIZE, ICON_SIZE))
        self.assertEqual(
            first_project.header.layout().contentsMargins(),
            QtCore.QMargins(7, 0, 6, 0),
        )
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
        self.assertEqual(first_project.archive_btn.size(), QtCore.QSize(28, 28))
        self.assertEqual(first_project.more_btn.size(), QtCore.QSize(28, 28))
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

    def test_project_list_is_flat_and_project_click_does_not_expand(self):
        project_list = self.window.nav_panel.project_list
        self.assertEqual(
            ProjectList.__module__, "plm.frontend.qt.widgets.project_list"
        )
        self.assertEqual(
            project_list.hover_card.__class__.__module__,
            "plm.frontend.qt.widgets.hover_card",
        )
        initial_count = project_list.count()
        self.assertGreater(initial_count, 0)
        for row, widget in enumerate(project_list.project_widgets):
            self.assertEqual(project_list.item(row).sizeHint().height(), 36)
            self.assertEqual(widget.layout().count(), 1)
            self.assertIs(widget.layout().itemAt(0).widget(), widget.header)
            self.assertFalse(widget.header.isCheckable())

        target = project_list.project_widgets[-1]
        target.header.click()
        wait_for_idle(self.app)
        self.assertEqual(project_list.count(), initial_count)
        self.assertEqual(project_list.selected_project_name, target.project_name)
        self.assertTrue(target.header.property("selected"))

    def test_expanded_nav_icons_share_one_left_edge(self):
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
            QtCore.QMargins(7, 0, 6, 0),
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
            19,
        )
        icon_pixmaps = (
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

    def test_nav_panel_layout_contract(self):
        nav = self.window.nav_panel
        root = nav.layout()
        first_project = nav.project_list.project_widgets[0]

        self.assertIsInstance(root, QtWidgets.QVBoxLayout)
        self.assertEqual(root.spacing(), 8)
        self.assertEqual(nav.expanded_width, 260)
        self.assertEqual(nav.collapsed_width, 56)
        self.assertEqual(nav.minimumWidth(), 260)
        self.assertEqual(nav.maximumWidth(), 260)
        self.assertEqual(nav.collapse_btn.size(), QtCore.QSize(32, 32))

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
            self.assertEqual(button.height(), 36)

        project_index = root.indexOf(nav.project_list)
        collapsed_project_index = root.indexOf(nav.collapsed_projects)
        self.assertEqual(root.stretch(project_index), 1)
        self.assertEqual(root.stretch(collapsed_project_index), 1)
        self.assertEqual(first_project.header.height(), 36)

        footer_layout = nav.footer.layout()
        self.assertIsInstance(footer_layout, QtWidgets.QVBoxLayout)
        self.assertEqual(footer_layout.spacing(), 8)
        self.assertIs(footer_layout.itemAt(0).widget(), nav.settings_row)
        self.assertIs(footer_layout.itemAt(1).widget(), nav.docs_row)
        self.assertEqual(nav.collapsed_projects.layout().spacing(), 8)

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
                self.assertTrue(first.archive_btn.isVisible())
                self.assertTrue(first.more_btn.isVisible())
                QtWidgets.QApplication.sendEvent(
                    first.header, QtCore.QEvent(QtCore.QEvent.Leave))
                self.assertFalse(first.archive_btn.isVisible())

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
            self.assertIn("在资源管理器中打开", actions)
            self.assertIn("归档", actions)
            self.assertIn("删除", actions)

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
                actions["在资源管理器中打开"].trigger()
                wait_for_idle(self.app)
                open_path.assert_called_once_with(widget.project_path)

            menu.deleteLater()
            widget.deleteLater()

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
        self.assertEqual(toolbar.layout().spacing(), 8)
        for button in panel.toolbar_buttons:
            self.assertEqual(button.size(), QtCore.QSize(28, 28))
            self.assertEqual(button.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE))

        self.assertEqual(panel.layout().spacing(), 12)
        self.assertIsInstance(panel.preview, QtWidgets.QPlainTextEdit)
        self.assertFalse(hasattr(panel, "file_selector"))

    def test_config_header_has_twelve_pixel_gap_before_tabs(self):
        page = self.window.config_page
        gap = page.config_area.geometry().top() - (page.header.geometry().bottom() + 1)
        self.assertEqual(gap, 12)

    def test_config_tabs_fit_scaled_labels_including_generation(self):
        tabs = self.window.config_page.tabs
        bar = tabs.tabBar()
        for selected in range(tabs.count()):
            tabs.setCurrentIndex(selected)
            wait_for_idle(self.app)
            for index in range(tabs.count()):
                font = QtGui.QFont(bar.font())
                font.setBold(True)
                width = QtGui.QFontMetrics(font).horizontalAdvance(tabs.tabText(index))
                self.assertGreaterEqual(bar.tabRect(index).width(), width + 32)
            self.assertLessEqual(bar.tabRect(tabs.count() - 1).right(), bar.width() - 1)

    def test_controller_card_alignment_and_context_insertion_undo(self):
        page = self.window.config_page
        editor = page.controllers_editor
        table = editor.table
        original_count = table.rowCount()
        self.assertLess(table.columnWidth(0), table.columnWidth(1))
        self.assertLess(table.columnWidth(2), table.columnWidth(1))
        self.assertEqual(table.item(0, 0).textAlignment(), int(QtCore.Qt.AlignCenter))
        self.assertEqual(table.horizontalHeaderItem(1).textAlignment(),
                         int(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter))
        original_height = table.height()
        self.assertFalse(hasattr(editor, "add_row_btn"))
        editor.add_row()
        wait_for_idle(self.app)
        self.assertEqual(table.rowCount(), original_count + 1)
        self.assertGreater(table.height(), original_height)
        self.assertTrue(page.dirty)
        self.assertEqual(page.header.status_badge.text(), "已修改")
        page.undo()
        wait_for_idle(self.app)
        self.assertEqual(table.rowCount(), original_count)
        self.assertFalse(page.dirty)
        self.assertEqual(page.header.status_badge.text(), "未修改")
        editor.set_rows([
            {"ctrl_id": index, "ctrl_name": f"Ctrl{index}", "max_width": 4}
            for index in range(15)
        ])
        wait_for_idle(self.app)
        self.assertEqual(table.rowCount(), 15)
        self.assertGreater(table.verticalScrollBar().maximum(), 0)

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
        page.artifacts_panel.close_button.click()
        self.assertTrue(hidden.wait(1000))
        self.assertFalse(page.artifacts_panel.isVisible())
        self.assertEqual(page._artifacts_animation.duration(), 200)

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
        self.assertEqual(overlay.title_label.text(), "Settings")
        self.assertEqual(overlay.size(), self.window.view_stack.contentsRect().size())
        self.assertEqual(overlay.back_btn.text(), "")
        self.assertEqual(overlay.back_btn.size(), QtCore.QSize(32, 32))
        self.assertEqual(overlay.back_btn.iconSize(), QtCore.QSize(ICON_SIZE, ICON_SIZE))
        panel = overlay.findChild(QtWidgets.QWidget, "SecondaryPagePanel")
        self.assertEqual(panel.width(), 800)
        self.assertEqual(panel.mapTo(overlay, QtCore.QPoint()).y(), 72)
        self.assertEqual(
            panel.mapTo(overlay, panel.rect().center()).x(),
            overlay.rect().center().x(),
        )
        divider = overlay.findChild(QtWidgets.QFrame, "SecondaryTabDivider")
        self.assertEqual(divider.height(), 1)
        for row in overlay.setting_rows.values():
            self.assertEqual(row.height(), 56)

        nav.docs_btn.click()
        wait_for_idle(self.app)
        overlay = self.window.view_stack.currentWidget()
        self.assertIsNotNone(overlay)
        self.assertEqual(overlay.page, "docs")
        self.assertEqual(overlay.title_label.text(), "Documentation")
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
            "git-compare",
            "search",
            "link",
            "file",
            "file-x",
            "more-horizontal",
            "maximize",
            "rocket",
            "minus",
            "square",
            "copy",
        )
        self.assertEqual(len(icon_names), 30)
        self.assertEqual(
            {path.stem for path in LUCIDE_ICON_DIR.glob("*.svg")},
            set(icon_names),
        )
        for name in icon_names:
            self.assertTrue((LUCIDE_ICON_DIR / f"{name}.svg").is_file())
            self.assertFalse(load_lucide_icon(name).isNull())

    def test_global_stylesheet_contains_key_visual_rules(self):
        self.assertIn("background-color: #FFFFFF", APP_QSS)
        self.assertIn("border-radius: 8px", APP_QSS)
        self.assertIn("QSplitter::handle", APP_QSS)
        self.assertIn("QTabWidget#ConfigTabs QTabBar::tab:selected", APP_QSS)
        self.assertIn("QScrollBar::handle:vertical", APP_QSS)
        self.assertIn('QWidget#WindowShell[maximized="true"]', APP_QSS)
        self.assertIn("QFrame#WindowTitleBar", APP_QSS)
        self.assertIn("background-color: #DCFCE7", APP_QSS)
        self.assertIn("background-color: #F1F5F9", APP_QSS)
        self.assertEqual(self.window.config_page.CORNER_RADII[0], 12)


if __name__ == "__main__":
    unittest.main()
