from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative, old, new):
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"anchor not found in {relative}: {old[:180]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# 1) Remove the redundant Clear project action and signal path. Archive already
# provides the same user-visible behavior (hide from list without deleting files).
replace_once(
    "src/plm/frontend/qt/widgets/project_item.py",
    "    clearRequested = QtCore.pyqtSignal(object)\n",
    "",
)
replace_once(
    "src/plm/frontend/qt/widgets/project_item.py",
    '''        clear_action = menu.addAction("清除")\n        menu.addSeparator()\n''',
    '''        menu.addSeparator()\n''',
)
replace_once(
    "src/plm/frontend/qt/widgets/project_item.py",
    '''        clear_action.triggered.connect(lambda: self.clearRequested.emit(self))\n''',
    "",
)

replace_once(
    "src/plm/frontend/qt/widgets/project_list.py",
    "    projectCleared = QtCore.pyqtSignal(str)\n",
    "",
)
replace_once(
    "src/plm/frontend/qt/widgets/project_list.py",
    "            widget.clearRequested.connect(self.clear_project)\n",
    "",
)
replace_once(
    "src/plm/frontend/qt/widgets/project_list.py",
    '''    def clear_project(self, widget):\n        self.projectCleared.emit(widget.project_name)\n\n''',
    "",
)

replace_once(
    "src/plm/frontend/qt/controllers/app_controller.py",
    '''from plm.frontend.qt.widgets.common import PROJECT_ROOT\n''',
    '''from plm.frontend.qt.widgets.common import PROJECT_ROOT, StyledMenu\n''',
)
replace_once(
    "src/plm/frontend/qt/controllers/app_controller.py",
    "        nav.project_list.projectCleared.connect(self.clear_project)\n",
    "",
)
replace_once(
    "src/plm/frontend/qt/controllers/app_controller.py",
    '''    def clear_project(self, name):\n        self.config_page.finish_editing()\n        if self.current_name == name and self.config_page.dirty and not self.save_current():\n            return\n        state = self.settings.get_project_state(name)\n        state.is_cleared = True\n        self.settings.save_project_state(state)\n        self.settings.clear_recent_project(name)\n        if self.current_name == name:\n            self.current_name = None\n            self.current_project = None\n        self.nav.apply_remove(name)\n        self._show_empty_project()\n        self._update_window_title()\n\n''',
    "",
)

# 2) Make shared menus truly translucent around the rounded QSS rectangle.
replace_once(
    "src/plm/frontend/qt/widgets/common.py",
    '''    def __init__(self, *args, **kwargs):\n        super().__init__(*args, **kwargs)\n        apply_drop_shadow(self, offset=(0, 4), blur_radius=12, alpha=40)\n''',
    '''    def __init__(self, *args, **kwargs):\n        super().__init__(*args, **kwargs)\n        self.setAttribute(QtCore.Qt.WA_TranslucentBackground)\n        self.setWindowFlags(\n            self.windowFlags()\n            | QtCore.Qt.FramelessWindowHint\n            | QtCore.Qt.NoDropShadowWindowHint\n        )\n        apply_drop_shadow(self, offset=(0, 4), blur_radius=12, alpha=40)\n''',
)

replace_once(
    "src/plm/frontend/qt/styles/app.qss",
    '''QMenu {\n    min-width: 180px; background-color: #FFFFFF; border: 1px solid #EAEAEA;\n    border-radius: 8px; padding: 6px;\n}\n''',
    '''QMenu {\n    min-width: 180px; background-color: #FFFFFF; border: 1px solid #EAEAEA;\n    border-radius: 8px; padding: 6px; margin: 4px;\n}\n''',
)

replace_once(
    "src/plm/frontend/qt/widgets/tables.py",
    '''from plm.frontend.qt.widgets import sap_icons\nfrom plm.frontend.qt.widgets.theme import ACCENT, RoundedComboBox\n''',
    '''from plm.frontend.qt.widgets import sap_icons\nfrom plm.frontend.qt.widgets.common import StyledMenu\nfrom plm.frontend.qt.widgets.theme import ACCENT, RoundedComboBox\n''',
)
replace_once(
    "src/plm/frontend/qt/widgets/tables.py",
    "        menu = QtWidgets.QMenu(self.table)\n",
    "        menu = StyledMenu(self.table)\n",
)

replace_once(
    "src/plm/frontend/qt/widgets/lanegrid.py",
    '''from plm.frontend.qt.widgets.tables import RowDragTable\nfrom plm.frontend.qt.widgets.theme import BORDER, BORDER_STRONG, TEXT, add_shadow\n''',
    '''from plm.frontend.qt.widgets.common import StyledMenu\nfrom plm.frontend.qt.widgets.tables import RowDragTable\nfrom plm.frontend.qt.widgets.theme import BORDER, BORDER_STRONG, TEXT, add_shadow\n''',
)
text_path = ROOT / "src/plm/frontend/qt/widgets/lanegrid.py"
text = text_path.read_text(encoding="utf-8")
if text.count("menu = QtWidgets.QMenu(") < 2:
    raise SystemExit("expected both LaneGrid menu constructors")
text = text.replace("menu = QtWidgets.QMenu(self)", "menu = StyledMenu(self)")
text = text.replace("menu = QtWidgets.QMenu(self.table)", "menu = StyledMenu(self.table)")
text_path.write_text(text, encoding="utf-8")

replace_once(
    "src/plm/frontend/qt/controllers/app_controller.py",
    "        menu = QtWidgets.QMenu(self.window)\n",
    "        menu = StyledMenu(self.window)\n",
)

# 3) Only Signals should stretch its editor to the bottom of the content area.
replace_once(
    "src/plm/frontend/qt/views/config_page.py",
    '''class ConfigTabPage(QtWidgets.QWidget):\n    def __init__(self, title, description, editor, parent=None):\n''',
    '''class ConfigTabPage(QtWidgets.QWidget):\n    def __init__(self, title, description, editor, fill_editor=False, parent=None):\n''',
)
replace_once(
    "src/plm/frontend/qt/views/config_page.py",
    '''        content_layout.addWidget(editor)\n        content_layout.addStretch(1)\n        scroll.setWidget(content)\n''',
    '''        content_layout.addWidget(editor, 1 if fill_editor else 0)\n        if not fill_editor:\n            content_layout.addStretch(1)\n        scroll.setWidget(content)\n''',
)
replace_once(
    "src/plm/frontend/qt/views/config_page.py",
    '''        for tab_name, title, description, editor in (\n            ("Controller", "Controller Configuration", "配置控制器 ID、名称和最大 Lane 宽度。", self.controllers_editor),\n            ("LaneMapping", "Lane Mapping Configuration", "配置物理 Lane 与控制器 Lane 的映射关系。", self.mapping_editor),\n            ("Signals", "PIPE Signals", "配置 PIPE 信号、方向、位宽与安全值。", self.signals_editor),\n            ("Generation", "Generation Settings", "选择生成参数并生成匹配的 RTL 和 Testbench。", self.generation_editor),\n        ):\n            self.tabs.addTab(ConfigTabPage(title, description, editor), tab_name)\n''',
    '''        for tab_name, title, description, editor, fill_editor in (\n            ("Controller", "Controller Configuration", "配置控制器 ID、名称和最大 Lane 宽度。", self.controllers_editor, False),\n            ("LaneMapping", "Lane Mapping Configuration", "配置物理 Lane 与控制器 Lane 的映射关系。", self.mapping_editor, False),\n            ("Signals", "PIPE Signals", "配置 PIPE 信号、方向、位宽与安全值。", self.signals_editor, True),\n            ("Generation", "Generation Settings", "选择生成参数并生成匹配的 RTL 和 Testbench。", self.generation_editor, False),\n        ):\n            self.tabs.addTab(\n                ConfigTabPage(title, description, editor, fill_editor=fill_editor), tab_name\n            )\n''',
)

# Update fast functional tests: Archive/Delete remain; Clear no longer exists.
replace_once(
    "tests/test_qt_controls.py",
    '''    def test_project_context_menu_routes_pin_and_clear_signals(self):\n        widget = self.window.nav_panel.project_list.project_widgets[0]\n        pin = QtTest.QSignalSpy(widget.pinRequested)\n        clear = QtTest.QSignalSpy(widget.clearRequested)\n\n        menu = widget.build_more_menu()\n        actions = [action for action in menu.actions() if not action.isSeparator()]\n        self.assertEqual(\n            [action.text() for action in actions],\n            ["置顶", "重命名", "在资源管理器中打开", "清除", "归档", "删除"],\n        )\n        next(action for action in actions if action.text() == "置顶").trigger()\n        next(action for action in actions if action.text() == "清除").trigger()\n        self.assertEqual(len(pin), 1)\n        self.assertEqual(len(clear), 1)\n        self.assertIs(pin[0][0], widget)\n        self.assertIs(clear[0][0], widget)\n        menu.close()\n        menu.deleteLater()\n''',
    '''    def test_project_context_menu_has_no_redundant_clear_action(self):\n        widget = self.window.nav_panel.project_list.project_widgets[0]\n        pin = QtTest.QSignalSpy(widget.pinRequested)\n\n        menu = widget.build_more_menu()\n        actions = [action for action in menu.actions() if not action.isSeparator()]\n        self.assertEqual(\n            [action.text() for action in actions],\n            ["置顶", "重命名", "在资源管理器中打开", "归档", "删除"],\n        )\n        next(action for action in actions if action.text() == "置顶").trigger()\n        self.assertEqual(len(pin), 1)\n        self.assertIs(pin[0][0], widget)\n        menu.close()\n        menu.deleteLater()\n''',
)
# Remove the obsolete clear/reopen test; archive coverage already exists elsewhere.
start = '''    def test_clear_project_can_be_explicitly_reopened(self):\n'''
test_path = ROOT / "tests/test_qt_controls.py"
test_text = test_path.read_text(encoding="utf-8")
idx = test_text.find(start)
if idx < 0:
    raise SystemExit("clear-project test not found")
next_idx = test_text.find("    def test_", idx + len(start))
if next_idx < 0:
    raise SystemExit("next test after clear-project test not found")
test_text = test_text[:idx] + test_text[next_idx:]
test_path.write_text(test_text, encoding="utf-8")

# Screenshot assertions for the exact reported issues.
replace_once(
    "scripts/capture_ui.py",
    '''    assert w.config_page.signals_editor.table.rowCount() > 0, "signals did not load"\n''',
    '''    assert w.config_page.signals_editor.table.rowCount() >= 30, "default signal data is incomplete"\n''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    # Project rows keep the three-dot menu but also restore right-click and\n    # double-click rename entry points; Clear is distinct from Archive/Delete.\n''',
    '''    # Project rows keep the three-dot menu and right-click entry point;\n    # the redundant Clear action is intentionally removed (Archive already hides\n    # a project without deleting its files).\n''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    assert "清除" in project_actions and "归档" in project_actions and "删除" in project_actions\n''',
    '''    assert project_actions == ["置顶", "重命名", "在资源管理器中打开", "归档", "删除"]\n''',
)
replace_once(
    "scripts/capture_ui.py",
    '''    for idx,name in enumerate(("controller","lane-mapping","signals","generation")):\n        w.config_page.tabs.setCurrentIndex(idx); shot(w,f"01-{name}")\n''',
    '''    for idx,name in enumerate(("controller","lane-mapping","signals","generation")):\n        w.config_page.tabs.setCurrentIndex(idx); app.processEvents()\n        if name == "signals":\n            assert w.config_page.signals_editor.table.height() > 300, "Signals table did not fill available height"\n        shot(w,f"01-{name}")\n''',
)

print("project menu, rounded menus, and Signals layout fixes applied")
