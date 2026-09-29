import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.main_window import (
    ICON_SIZE,
    LUCIDE_ICON_DIR,
    ConfigHeader,
    CustomTitleBar,
    DiffCard,
    DragButton,
    MainWindow,
    load_lucide_icon,
    make_diff_line,
)
from plm.frontend.qt.widgets.theme import build_stylesheet


class QtFrontendLayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setFont(QtGui.QFont("Segoe UI", 13))
        cls.app.setStyleSheet(build_stylesheet())

    def setUp(self):
        self.window = MainWindow()
        self.window.show()
        self.app.processEvents()

    def tearDown(self):
        self.window.close()
        self.window.deleteLater()
        self.app.processEvents()

    def test_shell_has_fixed_navigation_and_three_pages(self):
        self.assertTrue(
            self.window.windowFlags() & QtCore.Qt.FramelessWindowHint
        )
        self.assertIsInstance(self.window.title_bar, CustomTitleBar)
        self.assertEqual(self.window.title_bar.height(), 36)
        self.assertEqual(self.window.title_bar.title_label.text(), "plmConsultant")
        self.assertEqual(self.window.nav_panel.width(), 260)
        self.assertIsInstance(self.window.splitter, QtWidgets.QSplitter)
        self.assertEqual(self.window.splitter.orientation(), QtCore.Qt.Horizontal)
        self.assertEqual(self.window.splitter.handleWidth(), 1)
        self.assertFalse(self.window.splitter.childrenCollapsible())
        self.assertEqual(
            self.window.splitter.handle(1).cursor().shape(),
            QtCore.Qt.SplitHCursor,
        )
        self.assertEqual(self.window.nav_panel.minimumWidth(), 200)
        self.assertEqual(self.window.nav_panel.maximumWidth(), 400)
        self.assertEqual(self.window.stack.count(), 3)
        self.assertIs(self.window.stack.currentWidget(), self.window.config_page)

    def test_custom_title_bar_toggles_maximized_state(self):
        title_bar = self.window.title_bar
        title_bar.toggle_maximized()
        self.app.processEvents()
        self.assertTrue(self.window.isMaximized())
        self.assertEqual(title_bar.maximize_btn.toolTip(), "还原")
        title_bar.toggle_maximized()
        self.app.processEvents()
        self.assertFalse(self.window.isMaximized())
        self.assertEqual(title_bar.maximize_btn.toolTip(), "最大化")

    def test_navigation_width_can_be_dragged_within_limits(self):
        splitter = self.window.splitter
        splitter.setSizes([350, 1000])
        self.app.processEvents()
        self.assertEqual(self.window.nav_panel.width(), 350)
        splitter.setSizes([100, 1250])
        self.app.processEvents()
        self.assertEqual(self.window.nav_panel.width(), 200)
        splitter.setSizes([500, 850])
        self.app.processEvents()
        self.assertEqual(self.window.nav_panel.width(), 400)

    def test_navigation_collapse_leaves_only_toggle_visible(self):
        nav = self.window.nav_panel
        dividers = nav.findChildren(QtWidgets.QFrame, "NavDivider")
        self.assertEqual(len(dividers), 3)
        self.assertTrue(all(divider.height() == 1 for divider in dividers))
        nav.collapse_btn.click()
        self.app.processEvents()
        self.assertEqual(nav.width(), 40)
        self.assertEqual(nav.collapse_btn.text(), "»")
        self.assertFalse(nav.collapse_btn.isHidden())
        self.assertTrue(all(widget.isHidden() for widget in nav.collapsible_widgets))
        nav.collapse_btn.click()
        self.app.processEvents()
        self.assertEqual(nav.width(), 260)
        self.assertEqual(nav.collapse_btn.text(), "«")
        self.assertEqual(nav.minimumWidth(), 200)
        self.assertEqual(nav.maximumWidth(), 400)

    def test_configuration_tabs_match_requested_names(self):
        tabs = self.window.config_page.tabs
        self.assertEqual(tabs.count(), 4)
        self.assertEqual(
            [tabs.tabText(index) for index in range(tabs.count())],
            ["Controller", "LaneMapping", "Signals", "Generation"],
        )
        self.assertIsNone(self.window.config_page.findChild(QtWidgets.QLabel, "PageTitle"))
        self.assertIsNone(self.window.config_page.findChild(QtWidgets.QLabel, "PanelTitle"))
        self.assertIsNone(tabs.cornerWidget())
        header = self.window.config_page.config_header
        self.assertIsInstance(header, ConfigHeader)
        self.assertEqual(header.height(), 48)
        self.assertEqual(header.title_label.text(), "重写 PLM Qt 前端布局")
        self.assertEqual(header.layout().spacing(), 12)
        self.assertFalse(hasattr(header, "more_btn"))
        self.assertFalse(hasattr(header, "conversation_menu"))
        self.assertFalse(hasattr(self.window.config_page, "show_diff_btn"))
        self.assertFalse(hasattr(self.window.config_page, "hide_diff_btn"))
        self.assertLessEqual(tabs.geometry().top(), 12)

        first_page_layout = tabs.widget(0).layout()
        self.assertEqual(first_page_layout.spacing(), 0)
        self.assertEqual(first_page_layout.itemAt(1).spacerItem().sizeHint().height(), 8)
        self.assertEqual(first_page_layout.itemAt(3).spacerItem().sizeHint().height(), 20)

    def test_lucide_assets_exist_and_icons_use_the_shared_size(self):
        icon_names = (
            "file-text",
            "settings",
            "plus",
            "save",
            "more-horizontal",
            "panel-right",
            "folder",
            "refresh-cw",
            "square-pen",
            "trash-2",
            "archive",
            "braces",
            "search",
            "link",
            "file",
            "maximize",
        )
        for name in icon_names:
            self.assertTrue((LUCIDE_ICON_DIR / f"{name}.svg").is_file())
            self.assertFalse(load_lucide_icon(name).isNull())

        expected_size = QtCore.QSize(ICON_SIZE, ICON_SIZE)
        header = self.window.config_page.config_header
        self.assertEqual(header.sidebar_btn.iconSize(), expected_size)
        nav = self.window.nav_panel
        self.assertEqual(nav.new_chat_btn.iconSize(), expected_size)
        self.assertEqual(nav.save_btn.iconSize(), expected_size)
        self.assertEqual(nav.docs_btn.iconSize(), expected_size)
        self.assertEqual(nav.settings_btn.iconSize(), expected_size)
        for button in self.window.config_page.preview_buttons:
            self.assertEqual(button.iconSize(), expected_size)
            self.assertEqual(button.size(), QtCore.QSize(24, 24))
            self.assertFalse(button.icon().isNull())

        toolbar = self.window.config_page.right_panel.findChild(
            QtWidgets.QWidget, "RightPanelToolbar"
        )
        self.assertEqual(toolbar.layout().spacing(), 8)
        diff_content = self.window.config_page.right_panel.findChild(
            QtWidgets.QWidget, "DiffContent"
        )
        bottom_spacing = diff_content.layout().itemAt(
            diff_content.layout().count() - 2
        ).spacerItem()
        self.assertEqual(bottom_spacing.sizeHint().height(), 10)

    def test_diff_panel_is_an_absolute_overlay(self):
        page = self.window.config_page
        tabs_geometry = page.tabs.geometry()
        page.show_diff_panel()
        self.app.processEvents()
        self.assertIs(page.right_panel.parent(), page)
        self.assertIs(page.drag_handle.parent(), page)
        self.assertIsInstance(page.drag_button, DragButton)
        self.assertEqual(page.drag_button.size().width(), 14)
        self.assertEqual(page.drag_button.size().height(), 36)
        self.assertEqual(page.tabs.geometry(), tabs_geometry)
        self.assertEqual(page.right_panel.geometry().right(), page.rect().right())
        self.assertTrue(page.right_panel.isVisible())
        self.assertTrue(page.drag_handle.isVisible())
        shadow = page.right_panel.graphicsEffect()
        self.assertIsInstance(shadow, QtWidgets.QGraphicsDropShadowEffect)
        self.assertEqual(shadow.blurRadius(), 12)
        self.assertEqual((shadow.xOffset(), shadow.yOffset()), (0.0, 2.0))
        self.assertEqual(shadow.color().alpha(), 30)
        self.assertEqual(
            page.drag_button.geometry().left() + page.drag_button.width() // 2,
            page.right_panel.geometry().left(),
        )
        self.assertLessEqual(
            abs(
                page.drag_button.geometry().center().y()
                - page.right_panel.geometry().center().y()
            ),
            1,
        )

    def test_config_header_sidebar_button_toggles_panel(self):
        page = self.window.config_page
        page.config_header.sidebar_btn.click()
        self.app.processEvents()
        self.assertTrue(page.right_panel.isVisible())
        page.config_header.sidebar_btn.click()
        self.app.processEvents()
        self.assertFalse(page.right_panel.isVisible())
        self.assertFalse(page.drag_handle.isVisible())

    def test_preview_maximize_and_restore(self):
        page = self.window.config_page
        page.config_header.sidebar_btn.click()
        self.app.processEvents()
        original_width = page.right_panel.width()
        page.preview_expand_btn.click()
        self.app.processEvents()
        self.assertTrue(page.preview_maximized)
        self.assertEqual(page.right_panel.width(), page.width())
        self.assertFalse(page.drag_button.isVisible())
        self.assertEqual(page.preview_expand_btn.accessibleName(), "恢复预览")
        page.preview_expand_btn.click()
        self.app.processEvents()
        self.assertFalse(page.preview_maximized)
        self.assertEqual(page.right_panel.width(), original_width)
        self.assertTrue(page.drag_button.isVisible())

    def test_dragging_left_grows_panel_and_respects_limits(self):
        page = self.window.config_page
        page.show_diff_panel()
        self.app.processEvents()
        original_width = page.right_panel.width()
        page.handle_drag("start", 700)
        page.handle_drag("move", 620)
        self.assertEqual(page.right_panel.width(), original_width + 80)
        page.handle_drag("move", 5000)
        self.assertEqual(page.right_panel.width(), 300)
        page.handle_drag("move", -5000)
        self.assertLessEqual(page.right_panel.width(), page.width())
        page.handle_release()
        self.assertIsNone(page.drag_start_global_x)
        self.assertIsNone(page.drag_start_width)

    def test_diff_line_colours_and_placeholder_alignment(self):
        self.assertIn("#D8F5DC", make_diff_line(1, 1, "added", "add").styleSheet())
        self.assertIn("#FFE0DC", make_diff_line(1, 1, "removed", "del").styleSheet())
        self.assertIn("#F6F8FA", make_diff_line(1, 1, "context", "ctx").styleSheet())

        placeholder = self.window.config_page.tabs.widget(0).findChild(
            QtWidgets.QFrame, "PlaceholderCard"
        )
        margins = placeholder.layout().contentsMargins()
        self.assertEqual(
            (margins.left(), margins.top(), margins.right(), margins.bottom()),
            (40, 40, 40, 40),
        )
        alignment = placeholder.layout().itemAt(0).alignment()
        self.assertTrue(alignment & QtCore.Qt.AlignTop)
        self.assertTrue(alignment & QtCore.Qt.AlignLeft)

    def test_resize_keeps_overlay_right_aligned(self):
        page = self.window.config_page
        page.show_diff_panel()
        self.window.resize(1120, 700)
        self.app.processEvents()
        self.assertEqual(page.right_panel.geometry().right(), page.rect().right())
        self.assertEqual(page.right_panel.geometry().top(), page.config_header.height())
        self.assertEqual(
            page.right_panel.height(), page.height() - page.config_header.height()
        )

    def test_diff_cards_and_navigation_pages_exist(self):
        page = self.window.config_page
        self.assertGreaterEqual(len(page.right_panel.findChildren(DiffCard)), 2)
        self.assertEqual(len(page.preview_buttons), 9)
        self.assertTrue(page.preview_highlight_btn.isCheckable())
        self.assertTrue(page.preview_highlight_btn.isChecked())
        self.assertTrue(page.preview_diff_btn.isCheckable())
        self.assertEqual(page.preview_search_btn.accessibleName(), "在文件中查找")
        self.window.nav_panel.docs_btn.click()
        self.assertIs(self.window.stack.currentWidget(), self.window.docs_page)
        self.assertEqual(self.window.nav_panel.docs_btn.property("selected"), "true")
        self.window.nav_panel.settings_btn.click()
        self.assertIs(self.window.stack.currentWidget(), self.window.settings_page)
        self.assertEqual(self.window.nav_panel.settings_btn.property("selected"), "true")
        self.window.settings_page.menu.buttons[2].click()
        self.assertEqual(self.window.settings_page.content_stack.currentIndex(), 2)
        self.window.nav_panel.session_btn.click()
        self.assertIs(self.window.stack.currentWidget(), self.window.config_page)
        self.assertEqual(self.window.nav_panel.docs_btn.property("selected"), "false")
        self.assertEqual(self.window.nav_panel.settings_btn.property("selected"), "false")

    def test_navigation_button_labels_and_new_chat_signal(self):
        nav = self.window.nav_panel
        self.assertEqual(nav.new_chat_btn.text(), "新对话")
        self.assertEqual(nav.save_btn.text(), "保存")
        self.assertEqual(nav.action_buttons_widget.layout().spacing(), 8)
        self.assertEqual(nav.docs_btn.text(), "Docs")
        self.assertEqual(nav.settings_btn.text(), "Settings")
        emitted = []
        nav.navChanged.connect(emitted.append)
        nav.new_chat_btn.click()
        self.assertEqual(emitted[-1], "new_chat")
        nav.save_btn.click()
        self.assertEqual(emitted[-1], "save")

    def test_session_menu_edits_and_cancels_inline_name(self):
        nav = self.window.nav_panel
        entry = nav.session_item
        self.assertFalse(hasattr(nav, "session_edit_btn"))
        self.assertTrue(entry.session_label.isVisible())
        self.assertFalse(entry.session_editor.isVisible())
        self.assertEqual(nav.session_more_btn.size(), QtCore.QSize(24, 24))
        self.assertEqual(nav.session_more_btn.iconSize(), QtCore.QSize(16, 16))

        QtWidgets.QApplication.sendEvent(entry, QtCore.QEvent(QtCore.QEvent.Enter))
        self.assertTrue(nav.session_more_btn.isVisible())
        nav.show_session_menu(entry)
        entry.actions_menu.actions()[0].trigger()
        self.assertFalse(entry.session_label.isVisible())
        self.assertTrue(entry.session_editor.isVisible())
        self.assertEqual(entry.session_editor.selectedText(), "PIPE Lane Mapper 配置会话")

        entry.session_editor.setText("新的配置会话")
        entry.session_editor.returnPressed.emit()
        self.assertEqual(entry.session_label.text(), "新的配置会话")
        self.assertTrue(entry.session_label.isVisible())

        entry.enter_edit_mode()
        entry.session_editor.setText("不应保存的名称")
        escape = QtGui.QKeyEvent(
            QtCore.QEvent.KeyPress, QtCore.Qt.Key_Escape, QtCore.Qt.NoModifier
        )
        QtWidgets.QApplication.sendEvent(entry.session_editor, escape)
        self.assertEqual(entry.session_label.text(), "新的配置会话")
        self.assertTrue(entry.session_label.isVisible())

        QtWidgets.QApplication.sendEvent(entry, QtCore.QEvent(QtCore.QEvent.Leave))
        self.assertFalse(nav.session_more_btn.isVisible())

    def test_session_list_drag_configuration_and_order_tracking(self):
        nav = self.window.nav_panel
        session_list = nav.recent_list
        self.assertEqual(
            session_list.dragDropMode(), QtWidgets.QAbstractItemView.InternalMove
        )
        self.assertEqual(
            session_list.selectionMode(), QtWidgets.QAbstractItemView.SingleSelection
        )
        self.assertEqual(session_list.defaultDropAction(), QtCore.Qt.MoveAction)

        nav.add_session("Second session")
        moved = session_list.model().moveRow(
            QtCore.QModelIndex(), 1, QtCore.QModelIndex(), 0
        )
        self.assertTrue(moved)
        self.app.processEvents()
        self.assertEqual(nav.session_order, ["Second session", "PIPE Lane Mapper 配置会话"])

    def test_session_more_menu_archive_and_delete_source_file(self):
        nav = self.window.nav_panel
        nav.show_session_menu(nav.session_item)
        menu = nav.session_item.actions_menu
        self.assertEqual(
            [action.text() for action in menu.actions()], ["编辑", "归档", "删除"]
        )
        delete_option = QtWidgets.QStyleOptionMenuItem()
        menu.initStyleOption(delete_option, menu.actions()[2])
        self.assertEqual(delete_option.palette.color(QtGui.QPalette.Text).name(), "#cf222e")
        menu.hide()

        archived = []
        nav.session_archived.connect(archived.append)
        nav.archive_session(nav.session_item)
        self.assertEqual(nav.recent_list.count(), 0)
        self.assertEqual(nav.archived_list.count(), 1)
        self.assertEqual(archived, ["PIPE Lane Mapper 配置会话"])

        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "session.json"
            source_path.write_text("{}", encoding="utf-8")
            entry = nav.add_session("Deletable session", source_path=source_path)
            deleted = []
            nav.session_deleted.connect(deleted.append)
            with mock.patch.object(
                QtWidgets.QMessageBox,
                "question",
                return_value=QtWidgets.QMessageBox.Yes,
            ):
                nav.delete_session(entry)
            self.assertFalse(source_path.exists())
            self.assertEqual(deleted, ["Deletable session"])


if __name__ == "__main__":
    unittest.main()
