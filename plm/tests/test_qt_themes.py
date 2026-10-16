"""Theme switches preserve live editing state and recolor existing surfaces."""

import copy
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtCore, QtGui, QtTest, QtWidgets
from qt_test_support import (
    dispose_new_widgets, isolate_host_formatter, preserve_application_state, wait_for_idle,
)
from sample_data import sample_config
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore, WorkspaceService
from plm.frontend.qt.styles import get_app_qss
from plm.frontend.qt.styles.tokens import (
    DARK_COLORS, LIGHT_COLORS, SPACING_MD, SPLITTER_HANDLE_SIZE,
    LANE_GRID_PALETTE, get_active_theme, get_qss_tokens,
)
from plm.frontend.qt.widgets.lanegrid import _contrast_text_color
from plm.frontend.qt.widgets.common import draw_icon_text_label, make_icon_button
from test_qt_colors import luminance


def contrast(first, second):
    low, high = sorted((luminance(first), luminance(second)))
    return (high + .05) / (low + .05)


class ThemePaletteTests(unittest.TestCase):
    def test_lane_swatch_labels_meet_aa_on_each_controller_color(self):
        for color in LANE_GRID_PALETTE:
            with self.subTest(color=color):
                self.assertGreaterEqual(contrast(_contrast_text_color(color), color), 4.5)

    def test_both_themes_cover_all_color_roles_and_resolve_qss(self):
        self.assertEqual(LIGHT_COLORS.keys(), DARK_COLORS.keys())
        for name, colors in (("light", LIGHT_COLORS), ("dark", DARK_COLORS)):
            tokens = get_qss_tokens(name)
            self.assertTrue(colors.items() <= tokens.items())
            self.assertNotIn("$", get_app_qss(name))
            for role in ("chevron_right_icon", "chevron_down_icon"):
                self.assertIn(f'stroke="{colors["text_sub"]}"', Path(tokens[role]).read_text(encoding="utf-8"))

    def test_text_contrast_on_all_neutral_interaction_surfaces(self):
        surfaces = ("bg_main", "bg_surface", "bg_sidebar", "bg_sidebar_hover", "bg_card",
                    "bg_subtle", "bg_alternate", "bg_hover", "bg_focus", "bg_switch_hover",
                    "primary_soft", "primary_pressed")
        for theme in (LIGHT_COLORS, DARK_COLORS):
            for role in ("text_main", "text_sub", "text_muted", "text_header"):
                for surface in surfaces:
                    with self.subTest(role=role, surface=surface, dark=theme is DARK_COLORS):
                        self.assertGreaterEqual(contrast(theme[role], theme[surface]), 4.5)

    def test_primary_semantic_tooltip_and_preview_contrast(self):
        for theme in (LIGHT_COLORS, DARK_COLORS):
            pairs = [("text_on_primary", "primary"), ("text_on_primary", "primary_hover"),
                     ("text_on_primary", "primary_active"),
                     ("text_primary", "primary_soft"), ("tooltip_text", "tooltip_bg"),
                     ("text_document_code", "bg_document_code")]
            pairs += [(f"{role}_text", f"{role}_bg")
                      for role in ("info", "success", "warning", "danger")]
            pairs += [(role, surface) for role in ("text_artifacts", "text_artifacts_muted")
                      for surface in ("bg_artifacts", "bg_artifacts_header", "diff_added_bg",
                                      "diff_removed_bg", "diff_added_gutter", "diff_removed_gutter",
                                      "diff_hunk_bg")]
            for foreground, background in pairs:
                with self.subTest(foreground=foreground, background=background, dark=theme is DARK_COLORS):
                    self.assertGreaterEqual(contrast(theme[foreground], theme[background]), 4.5)


class LiveThemeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
        preserve_application_state(cls, cls.app)

    def setUp(self):
        preserve_application_state(self, self.app)
        isolate_host_formatter(self, self.app)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(temporary.name).resolve()
        shutil.copytree(sample_config("bifurcate"), self.root / "test/demo/config")
        self.ini = self.root / "settings.ini"
        self.store = SettingsStore(QtCore.QSettings(str(self.ini), QtCore.QSettings.IniFormat))
        self.controller = AppController(ProjectService(self.root), self.store, WorkspaceService())
        with patch("plm.frontend.qt.main_window.AppController", return_value=self.controller):
            self.window = MainWindow()
        self.window.resize(1400, 900)
        self.window.show()
        wait_for_idle(self.app)

    def test_roundtrip_preserves_project_content_history_tabs_logs_and_artifacts_scroll(self):
        window = self.window
        page = window.config_page
        page.controllers_editor.table.item(0, 1).setText("unsaved_theme_edit")
        page.tabs.setCurrentIndex(3)
        path = self.root / "preview.sv"
        path.write_text("\n".join(f"assign signal_{i} = {i};" for i in range(250)), encoding="utf-8")
        panel = page.artifacts_panel
        panel.set_files([path], self.root)
        window.artifacts_toggle_button.click()
        QtTest.QTest.qWait(250)
        wait_for_idle(self.app)
        panel.preview.verticalScrollBar().setValue(70)
        window.log_panel.append_log("preserved log")
        project = self.controller.current_project
        content = copy.deepcopy(page.content())
        history = copy.deepcopy(page._history)
        history_index = page._history_index
        tab = page.tabs.currentIndex()
        scroll = panel.preview.verticalScrollBar().value()
        for theme in ("dark", "light"):
            window.apply_theme(theme)
            self.app.processEvents()
            self.assertIs(window.config_page, page)
            self.assertIs(self.controller.current_project, project)
            self.assertEqual(page.content(), content)
            self.assertTrue(page.dirty)
            self.assertEqual(page._history, history)
            self.assertEqual(page._history_index, history_index)
            self.assertEqual(page.tabs.currentIndex(), tab)
            self.assertTrue(panel.isVisible())
            self.assertEqual(panel.preview.verticalScrollBar().value(), scroll)
            self.assertIn("preserved log", window.log_panel.output.toPlainText())
        page.undo()
        self.assertNotEqual(page.content(), content)
        page.redo()
        self.assertEqual(page.content(), content)

    def test_theme_selection_persists_only_theme_and_reloads_before_construction(self):
        self.window.on_open_settings()
        wait_for_idle(self.app)
        settings = self.window.view_stack.currentWidget()
        original = self.store.preferences()
        settings.editor_path_edit.setText("unsaved-editor")
        settings.verible_path_edit.setText("unsaved-formatter")
        settings.theme_combo.setCurrentIndex(settings.theme_combo.findData("dark"))
        self.app.processEvents()
        reloaded = SettingsStore(QtCore.QSettings(str(self.ini), QtCore.QSettings.IniFormat))
        self.assertEqual(reloaded.theme(), "dark")
        self.assertEqual(reloaded.editor_path(), original["editor_path"])
        self.assertEqual(reloaded.formatter_preferences(), self.store.formatter_preferences())
        self.assertEqual(settings.editor_path_edit.text(), "unsaved-editor")
        self.assertIsNone(settings.flag_table)
        self.assertEqual(get_active_theme(), "dark")
        self.assertEqual(self.app.palette().color(QtGui.QPalette.Base).name().upper(), DARK_COLORS["bg_main"])
        controller = AppController(ProjectService(self.root), reloaded, WorkspaceService())
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            second = MainWindow()
        self.assertEqual(get_active_theme(), "dark")
        self.assertIn(DARK_COLORS["bg_main"], self.app.styleSheet())
        wait_for_idle(self.app)
        second.close()

    def test_invalid_saved_theme_falls_back_to_light(self):
        raw = QtCore.QSettings(str(self.ini), QtCore.QSettings.IniFormat)
        raw.setValue("appearance/theme", "unknown-theme")
        raw.sync()
        self.assertEqual(SettingsStore(raw).theme(), "light")

    def test_theme_switch_does_not_repeat_style_changes_for_every_ancestor(self):
        self.window.on_open_settings()
        wait_for_idle(self.app)
        settings = self.window.view_stack.currentWidget()
        settings.menu_buttons[1].click()
        wait_for_idle(self.app)
        numeric = settings._flag_controls["column_limit"]
        numeric.setText("137")
        numeric.selectAll()

        class StyleChanges(QtCore.QObject):
            count = 0

            def eventFilter(self, watched, event):
                if event.type() == QtCore.QEvent.StyleChange:
                    self.count += 1
                return False

        counter = StyleChanges()
        self.app.installEventFilter(counter)
        try:
            for theme in ("dark", "light"):
                counter.count = 0
                widget_count = len(self.app.allWidgets())
                self.window.apply_theme(theme)
                self.app.processEvents()
                # Bound the real work, rather than asserting machine-specific
                # milliseconds. A stylesheet replacement needs two style passes.
                self.assertLess(counter.count, 4 * widget_count)
                self.assertIs(settings._flag_controls["column_limit"], numeric)
                self.assertEqual(numeric.text(), "137")
                self.assertEqual(numeric.selectedText(), "137")
        finally:
            self.app.removeEventFilter(counter)

    def test_theme_switch_preserves_disabled_updates(self):
        self.window.setUpdatesEnabled(False)
        try:
            self.window.apply_theme("dark")
            self.assertFalse(self.window.updatesEnabled())
        finally:
            self.window.setUpdatesEnabled(True)

    def test_artifact_files_without_workspace_root_survive_theme_switch(self):
        path = self.root / "outside.sv"
        path.write_text("module outside; endmodule", encoding="utf-8")
        panel = self.window.config_page.artifacts_panel
        panel.set_files([path], statuses={path.name: "Modified"})
        wait_for_idle(self.app)
        self.window.apply_theme("dark")
        self.app.processEvents()
        self.assertEqual(panel.current_path, path)
        self.assertEqual(panel.file_tree.currentItem().foreground(0).color().name().upper(),
                         DARK_COLORS["text_primary"])

    def test_theme_switch_preserves_in_progress_cell_editor_and_selection(self):
        table = self.window.config_page.controllers_editor.table
        item = table.item(0, 1)
        table.setCurrentItem(item)
        table.editItem(item)
        self.app.processEvents()
        editor = table.findChild(QtWidgets.QLineEdit)
        self.assertIsNotNone(editor)
        editor.setText("uncommitted_draft")
        editor.selectAll()
        for theme in ("dark", "light"):
            self.window.apply_theme(theme)
            self.app.processEvents()
            self.assertIs(table.findChild(QtWidgets.QLineEdit), editor)
            self.assertEqual(editor.text(), "uncommitted_draft")
            self.assertEqual(editor.selectedText(), "uncommitted_draft")
            self.assertEqual(table.currentRow(), 0)
            self.assertEqual(table.currentColumn(), 1)

    def test_error_cells_and_focused_primary_icon_button_use_readable_foregrounds(self):
        editor = self.window.config_page.controllers_editor.editor
        item = editor.table.item(0, 1)
        errors = {(0, editor.columns[1]["key"]): "invalid value"}
        editor.set_cell_errors(errors)
        for theme, colors in (("dark", DARK_COLORS), ("light", LIGHT_COLORS)):
            self.window.apply_theme(theme)
            self.app.processEvents()
            self.assertEqual(item.foreground().color().name().upper(), colors["danger_text"])
            self.assertEqual(item.background().color().name().upper(), colors["danger_bg"])
            self.assertGreaterEqual(contrast(item.foreground().color().name(), item.background().color().name()), 4.5)
        button = make_icon_button("rocket", "create", "PrimaryBtn", color="text_on_primary")
        button.setText("Create")
        button.setParent(self.window)
        button.resize(120, 32)
        button.show()
        button.setFocus()
        self.app.processEvents()
        with patch("plm.frontend.qt.widgets.common.draw_icon_text_label",
                   wraps=draw_icon_text_label) as draw:
            # Grab triggers the real focus-aware label painter.
            button.grab()
            self.assertTrue(draw.called)
            self.assertEqual(draw.call_args.args[1].palette.color(QtGui.QPalette.ButtonText).name(), "#ffffff")
        button.deleteLater()

    def test_existing_icons_highlighting_diff_and_documentation_recolor(self):
        window = self.window
        panel = window.config_page.artifacts_panel
        preview = panel.preview
        preview.setPlainText("@@ -1 +1 @@\n-logic old;\n+logic fresh;")
        preview.set_diff_mode(True)
        old_icon = window.nav_panel.new_chat_btn.icon().pixmap(16, 16).toImage()
        old_format = preview.highlighter.formats["keyword"].foreground().color().name()
        window.on_open_docs()
        wait_for_idle(self.app)
        docs = window.view_stack.currentWidget()
        browser = docs.doc_browser
        browser.verticalScrollBar().setValue(40)
        old_text = browser.toPlainText()
        old_scroll = browser.verticalScrollBar().value()
        window.apply_theme("dark")
        self.app.processEvents()
        self.assertNotEqual(old_icon, window.nav_panel.new_chat_btn.icon().pixmap(16, 16).toImage())
        self.assertNotEqual(old_format, preview.highlighter.formats["keyword"].foreground().color().name())
        self.assertEqual(preview.extraSelections()[0].format.background().color().name().upper(), DARK_COLORS["diff_hunk_bg"])
        self.assertEqual(browser.toPlainText(), old_text)
        self.assertEqual(browser.verticalScrollBar().value(), old_scroll)
        self.assertIn(DARK_COLORS["text_main"], browser.document().defaultStyleSheet())
        self.assertEqual(window.nav_panel.new_chat_btn.palette().color(QtGui.QPalette.ButtonText).name().upper(), DARK_COLORS["text_main"])

    def test_rendered_dark_table_log_primary_button_and_restored_icons_use_theme_roles(self):
        window = self.window
        page = window.config_page
        panel = page.artifacts_panel
        old_artifact = panel.refresh_button.icon().pixmap(16, 16).toImage()
        old_folder = window.nav_panel.project_list.findChildren(QtWidgets.QLabel, "ProjectFolderIcon")[0].pixmap().toImage()
        window.apply_theme("dark")
        self.app.processEvents()
        image = window.grab().toImage()
        ratio = image.devicePixelRatio()
        table = page.controllers_editor.table
        position = table.viewport().mapTo(window, QtCore.QPoint(10, table.viewport().height() - 10))
        color = image.pixelColor(round(position.x() * ratio), round(position.y() * ratio)).name().upper()
        self.assertIn(color, (DARK_COLORS["bg_surface"], DARK_COLORS["bg_alternate"]))
        self.assertEqual(window.log_panel.output.palette().color(QtGui.QPalette.Base).name().upper(), DARK_COLORS["bg_surface"])
        page.tabs.setCurrentIndex(3)
        self.app.processEvents()
        button = page.generation_editor.generate_btn
        self.assertEqual(button.palette().color(QtGui.QPalette.Button).name().upper(), DARK_COLORS["primary"])
        self.assertEqual(button.palette().color(QtGui.QPalette.ButtonText).name().upper(), DARK_COLORS["text_on_primary"])
        window.apply_theme("light")
        self.app.processEvents()
        self.assertEqual(panel.refresh_button.icon().pixmap(16, 16).toImage(), old_artifact)
        folder = window.nav_panel.project_list.findChildren(QtWidgets.QLabel, "ProjectFolderIcon")[0]
        self.assertEqual(folder.pixmap().toImage(), old_folder)

    def test_right_titlebar_gap_and_positions_survive_panel_animations_and_resize(self):
        window = self.window
        for width in (960, 1400, 1600):
            window.resize(width, 900)
            self.app.processEvents()
            title = window.title_bar
            artifact = window.artifacts_toggle_button
            theme = window.theme_toggle_button
            minimum = title.minimize_btn
            gap = minimum.mapTo(title, QtCore.QPoint()).x() - (theme.mapTo(title, QtCore.QPoint()).x() + theme.width())
            self.assertEqual(gap, SPACING_MD)
            self.assertEqual(title.close_btn.geometry().right(), title.width() - 1)
            buttons = (window.log_toggle_button, artifact, theme)
            positions = [b.mapTo(title, QtCore.QPoint()) for b in buttons]
            window.nav_panel.toggle_collapse()
            artifact.click()
            QtTest.QTest.qWait(250)
            for button, position in zip(buttons, positions):
                self.assertEqual(button.mapTo(title, QtCore.QPoint()), position)
        for change_state in (window.showMaximized, window.showNormal):
            change_state()
            self.app.processEvents()
            self.assertEqual(window.title_bar.minimize_btn.x() - window.theme_toggle_button.geometry().right() - 1,
                             SPACING_MD)

    def test_splitter_hover_changes_pixels_without_changing_geometry(self):
        window = self.window
        window.show_log()
        wait_for_idle(self.app)
        handle = window.content_splitter.handle(1)
        self.assertEqual(handle.height(), SPLITTER_HANDLE_SIZE)
        before = handle.geometry()
        QtTest.QTest.mouseMove(handle, handle.rect().center())
        # The offscreen screen can be smaller than the scaled window; deliver
        # the real enter event explicitly rather than relying on global hit testing.
        self.app.sendEvent(handle, QtCore.QEvent(QtCore.QEvent.Enter))
        self.app.processEvents()
        self.assertEqual(handle.geometry(), before)
        image = window.grab().toImage()
        top = handle.mapTo(window, QtCore.QPoint(handle.width() // 2, 0))
        ratio = image.devicePixelRatio()
        point = QtCore.QPoint(round(top.x() * ratio), round(top.y() * ratio))
        self.assertEqual(image.pixelColor(point).name().upper(), LIGHT_COLORS["primary"])
        self.assertNotEqual(image.pixelColor(point + QtCore.QPoint(0, round(3 * ratio))).name().upper(), LIGHT_COLORS["primary"])
        self.app.sendEvent(handle, QtCore.QEvent(QtCore.QEvent.Leave))
        self.assertEqual(handle.geometry(), before)


if __name__ == "__main__":
    unittest.main()
