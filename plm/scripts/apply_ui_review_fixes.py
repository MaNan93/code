from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative, old, new):
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"anchor not found in {relative}: {old[:80]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# 1. Controller/Signals row context menu localization.
replace_once(
    "src/plm/frontend/qt/widgets/tables.py",
    '''            insert_above = menu.addAction("Insert row above")\n            insert_below = menu.addAction("Insert row below")\n            menu.addSeparator()\n            delete_current = menu.addAction("Delete current row")''',
    '''            insert_above = menu.addAction("在上方插入行")\n            insert_below = menu.addAction("在下方插入行")\n            menu.addSeparator()\n            delete_current = menu.addAction("删除当前行")''',
)
replace_once(
    "src/plm/frontend/qt/widgets/tables.py",
    '            insert_below = menu.addAction("Insert row")',
    '            insert_below = menu.addAction("插入行")',
)
replace_once(
    "src/plm/frontend/qt/widgets/config_editor.py",
    '''            menu.addAction("Insert row above", insert_above)\n            menu.addAction("Insert row below", insert_below)\n            menu.addSeparator()\n            action = menu.addAction("Delete current row", delete_row)''',
    '''            menu.addAction("在上方插入行", insert_above)\n            menu.addAction("在下方插入行", insert_below)\n            menu.addSeparator()\n            action = menu.addAction("删除当前行", delete_row)''',
)
replace_once(
    "src/plm/frontend/qt/widgets/config_editor.py",
    '            menu.addAction("Insert row", self.add_row)',
    '            menu.addAction("插入行", self.add_row)',
)

# 2 + 3. Recommended fonts and non-overlapping General / Appearance content.
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''CJK_FONT_CHOICES = (\n    "Microsoft YaHei UI",\n    "PingFang SC",\n    "Noto Sans CJK SC",\n    "SimHei",\n    "SimSun",\n    "Source Han Sans SC",\n)''',
    '''RECOMMENDED_FONT_CHOICES = (\n    "Microsoft YaHei UI",\n    "PingFang SC",\n    "Noto Sans CJK SC",\n    "SimHei",\n    "SimSun",\n    "Source Han Sans SC",\n    "DejaVu Sans",\n)\nMORE_FONTS_LABEL = "更多字体..."''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        current_family = preferences["font_family"]\n        installed_families = QtGui.QFontDatabase().families()\n        families = []\n        for family in (*CJK_FONT_CHOICES, *installed_families):\n            if family not in families:\n                families.append(family)\n        if current_family not in families:\n            families.insert(0, current_family)\n        for family in families:\n            self.font_family_combo.addItem(family)\n            self.font_family_combo.setItemData(\n                self.font_family_combo.count() - 1,\n                QtGui.QFont(family),\n                QtCore.Qt.FontRole,\n            )\n        self.font_family_combo.setCurrentText(current_family)''',
    '''        current_family = preferences["font_family"]\n        for family in RECOMMENDED_FONT_CHOICES:\n            self.font_family_combo.addItem(family)\n            self.font_family_combo.setItemData(\n                self.font_family_combo.count() - 1,\n                QtGui.QFont(family),\n                QtCore.Qt.FontRole,\n            )\n        self.font_family_combo.addItem(MORE_FONTS_LABEL)\n        self._last_font_family = DEFAULT_FONT_FAMILY\n        self._select_font_family(current_family)\n        self.font_family_combo.activated.connect(self._font_choice_activated)''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '        visible_rows = ({"font", "size", "editor"}, {"font", "size"}, {"editor"}, set())[index]',
    '        visible_rows = ({"editor"}, {"font", "size"}, {"editor"}, set())[index]',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''    def _build_formatter(self, preferences):''',
    '''    def _select_font_family(self, family):\n        family = str(family or DEFAULT_FONT_FAMILY)\n        index = self.font_family_combo.findText(family)\n        if index < 0:\n            more_index = self.font_family_combo.findText(MORE_FONTS_LABEL)\n            index = more_index if more_index >= 0 else self.font_family_combo.count()\n            self.font_family_combo.insertItem(index, family)\n            self.font_family_combo.setItemData(index, QtGui.QFont(family), QtCore.Qt.FontRole)\n        self.font_family_combo.setCurrentIndex(index)\n        self._last_font_family = family\n\n    def _font_choice_activated(self, index):\n        selected = self.font_family_combo.itemText(index)\n        if selected != MORE_FONTS_LABEL:\n            self._last_font_family = selected\n            return\n        font, accepted = QtWidgets.QFontDialog.getFont(\n            QtGui.QFont(self._last_font_family), self, "选择界面字体"\n        )\n        if accepted:\n            self._select_font_family(font.family())\n        else:\n            self._select_font_family(self._last_font_family)\n\n    def _build_formatter(self, preferences):''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '''        return {\n            "font_family": self.font_family_combo.currentText(),''',
    '''        font_family = self.font_family_combo.currentText()\n        if font_family == MORE_FONTS_LABEL:\n            font_family = self._last_font_family\n        return {\n            "font_family": font_family,''',
)
replace_once(
    "src/plm/frontend/qt/views/settings_page.py",
    '        self.font_family_combo.setCurrentText(DEFAULT_FONT_FAMILY)',
    '        self._select_font_family(DEFAULT_FONT_FAMILY)',
)

# 4. Cross-platform default project path via expanduser.
replace_once(
    "src/plm/frontend/qt/views/new_project_dialog.py",
    '''from pathlib import Path''',
    '''import os\nfrom pathlib import Path''',
)
replace_once(
    "src/plm/frontend/qt/views/new_project_dialog.py",
    '''        default_location = Path(location or Path.home()).expanduser()\n        if default_location == Path.home():\n            default_location = Path.home() / "plm-projects"\n        self.location = QtWidgets.QLineEdit(str(default_location))''',
    '''        home_location = os.path.expanduser("~")\n        default_location = (\n            os.path.expanduser(str(location))\n            if location\n            else os.path.expanduser("~/plm-projects")\n        )\n        if os.path.normpath(default_location) == os.path.normpath(home_location):\n            default_location = os.path.expanduser("~/plm-projects")\n        self.location = QtWidgets.QLineEdit(default_location)''',
)
replace_once(
    "src/plm/frontend/qt/views/new_project_dialog.py",
    '            self, "选择保存位置", self.location.text() or str(Path.home())',
    '            self, "选择保存位置", self.location.text() or os.path.expanduser("~")',
)
replace_once(
    "src/plm/frontend/qt/controllers/app_controller.py",
    '''import hashlib\nfrom pathlib import Path''',
    '''import hashlib\nimport os\nfrom pathlib import Path''',
)
replace_once(
    "src/plm/frontend/qt/controllers/app_controller.py",
    '        default = Path.home() / "plm-projects"',
    '        default = os.path.expanduser("~/plm-projects")',
)

# 5. Artifacts search controls spacing and right padding.
replace_once(
    "src/plm/frontend/qt/views/artifacts_panel.py",
    '''        search_layout.setContentsMargins(0, 0, 0, 0)\n        search_layout.setSpacing(4)''',
    '''        search_layout.setContentsMargins(0, 0, 12, 0)\n        search_layout.setSpacing(8)''',
)

# Keep fast control tests aligned with the localized Controller menu.
replace_once(
    "tests/test_qt_controls.py",
    '''            self._menu_class_selecting("Insert row below"),\n        ):\n            editor._show_row_context_menu(0, QtCore.QPoint())''',
    '''            self._menu_class_selecting("在下方插入行"),\n        ):\n            editor._show_row_context_menu(0, QtCore.QPoint())''',
)
replace_once(
    "tests/test_qt_controls.py",
    '''            self._menu_class_selecting("Delete current row"),\n        ):\n            editor._show_row_context_menu(1, QtCore.QPoint())''',
    '''            self._menu_class_selecting("删除当前行"),\n        ):\n            editor._show_row_context_menu(1, QtCore.QPoint())''',
)

# Update the visual-review assertions/screenshots for this review round.
replace_once(
    "scripts/capture_ui.py",
    '''        "Insert row above", "Insert row below", "Delete current row"''',
    '''        "在上方插入行", "在下方插入行", "删除当前行"''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    dlg=NewProjectDialog(Path.home(),w)''',
    '''    dlg=NewProjectDialog(None,w)''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    assert dlg.location.text() == str(Path.home()/"plm-projects")''',
    '''    assert dlg.location.text() == os.path.expanduser("~/plm-projects")''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    required_fonts=(\n        "Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC",\n        "SimHei", "SimSun", "Source Han Sans SC",\n    )''',
    '''    required_fonts=(\n        "Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC",\n        "SimHei", "SimSun", "Source Han Sans SC", "DejaVu Sans",\n    )''',
)
replace_once(
    "scripts/capture_ui.py",
    '''        w.placeholder_overlay.menu_buttons[idx].click()\n        shot(w,f"04-settings-{name}")\n        if name == "appearance":''',
    '''        w.placeholder_overlay.menu_buttons[idx].click()\n        page=w.placeholder_overlay\n        if name == "general":\n            assert page.setting_rows["editor"].isVisible()\n            assert not page.setting_rows["font"].isVisible()\n            assert not page.setting_rows["size"].isVisible()\n        elif name == "appearance":\n            assert page.setting_rows["font"].isVisible()\n            assert page.setting_rows["size"].isVisible()\n            assert not page.setting_rows["editor"].isVisible()\n        shot(w,f"04-settings-{name}")\n        if name == "appearance":''',
)
replace_once(
    "scripts/capture_ui.py",
    '''            assert all(font_combo.findText(font) >= 0 for font in required_fonts)\n            selected=font_combo.currentIndex()''',
    '''            expected_fonts=list(required_fonts)+["更多字体..."]\n            assert [font_combo.itemText(i) for i in range(font_combo.count())] == expected_fonts\n            selected=font_combo.currentIndex()''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    artifacts.show_search(); shot(w,"06-artifacts-search")''',
    '''    artifacts.show_search()\n    search_layout=artifacts.search_bar.layout()\n    assert search_layout.spacing() == 8\n    assert search_layout.getContentsMargins() == (0,0,12,0)\n    search_buttons=artifacts.search_bar.findChildren(QtWidgets.QPushButton)\n    assert len(search_buttons) == 3\n    assert all(button.size() == QtCore.QSize(24,24) for button in search_buttons)\n    shot(w,"06-artifacts-search")''',
)

print("UI review fixes applied")
