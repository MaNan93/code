"""Capture the current Qt UI pages for visual review."""
import os
import tempfile
from pathlib import Path
from unittest.mock import patch
from PyQt5 import QtCore, QtWidgets
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import SettingsStore
from plm.frontend.qt.views.new_project_dialog import NewProjectDialog
from plm.frontend.qt.widgets.lanegrid import LaneGrid

OUT=Path(os.environ.get("PLM_SCREENSHOT_DIR","ui-screenshots")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
app.setStyle("Fusion")


def shot(widget,name):
    app.processEvents()
    widget.grab().save(str(OUT/f"{name}.png"))


def screen_shot(name):
    app.processEvents()
    app.primaryScreen().grabWindow(0).save(str(OUT/f"{name}.png"))


def tree_texts(tree):
    values=[]
    iterator=QtWidgets.QTreeWidgetItemIterator(tree)
    while iterator.value() is not None:
        values.append(iterator.value().text(0))
        iterator += 1
    return values


with tempfile.TemporaryDirectory(prefix="plm-ui-") as td:
    root=Path(td)
    project=root/"demo-project"
    scaffold_default_content(project)
    store=SettingsStore(QtCore.QSettings(str(root/"settings.ini"),QtCore.QSettings.IniFormat))
    controller=AppController(settings_store=store)
    with patch("plm.frontend.qt.main_window.AppController",return_value=controller):
        w=MainWindow()
    w.resize(1400,900); w.show(); app.processEvents()

    # Exercise the reported failure mode: keep DejaVu Sans as the user's
    # preferred Latin font and rely on the stylesheet's CJK fallback stack.
    preferences=controller.settings.preferences()
    preferences["font_family"]="DejaVu Sans"
    controller.save_preferences(preferences)
    stylesheet=app.styleSheet()
    assert 'font-family: "DejaVu Sans", "Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC", "SimHei", "SimSun", sans-serif;' in stylesheet

    with patch.object(QtWidgets.QFileDialog,"getExistingDirectory",return_value=str(project)):
        controller.open_project()
    app.processEvents()
    assert w.config_page.controllers_editor.table.rowCount() > 0, "controllers did not load"
    assert w.config_page.controllers_editor.table.item(0, 1).text() == "CtrlA", "controller text did not load"
    assert not w.config_page.controllers_editor.table.verticalHeader().isVisible(), "Controller row header is visible"
    assert w.config_page.mapping_editor.table.rowCount() > 0, "lane mapping did not load"
    assert w.config_page.signals_editor.table.rowCount() > 0, "signals did not load"

    # Main-branch table behavior: row drag/reorder and context menus.
    assert hasattr(w.config_page.controllers_editor.table, "rowMoveRequested")
    assert hasattr(w.config_page.signals_editor.table, "rowMoveRequested")
    assert not w.config_page.findChildren(QtWidgets.QPushButton, "ConfigRowButton")
    controller_editor=w.config_page.controllers_editor
    row_menu=controller_editor._build_row_context_menu(0)
    assert [action.text() for action in row_menu.actions() if not action.isSeparator()] == [
        "Insert row above", "Insert row below", "Delete current row"
    ]
    first_item=controller_editor.table.item(0,0)
    menu_pos=controller_editor.table.visualItemRect(first_item).center()
    row_menu.popup(controller_editor.table.viewport().mapToGlobal(menu_pos))
    screen_shot("01-controller-context-menu")
    row_menu.close(); row_menu.deleteLater()

    # Main-branch LaneGrid behavior and product-mode lane picker.
    mapping=w.config_page.mapping_editor
    assert isinstance(mapping.editor, LaneGrid)
    assert [mapping.lane_count.itemText(i) for i in range(5)] == ["x2","x4","x8","x16","x32"]
    assert mapping.editor.controllers and mapping.editor.active_ctrl_id is not None

    # Project rows keep the three-dot menu but also restore right-click and
    # double-click rename entry points; Clear is distinct from Archive/Delete.
    project_widget=w.nav_panel.project_list.project_widgets[0]
    assert project_widget.header.contextMenuPolicy() == QtCore.Qt.CustomContextMenu
    project_menu=project_widget.build_more_menu()
    project_actions=[action.text() for action in project_menu.actions() if not action.isSeparator()]
    assert "清除" in project_actions and "归档" in project_actions and "删除" in project_actions
    project_menu.popup(project_widget.header.mapToGlobal(QtCore.QPoint(12,project_widget.header.height())))
    screen_shot("00-project-context-menu")
    project_menu.close(); project_menu.deleteLater()

    # Dirty state is visible in the native window title, then undo restores it.
    name_item=w.config_page.controllers_editor.table.item(0,1)
    original_name=name_item.text()
    name_item.setText(original_name+"Tmp")
    app.processEvents()
    assert w.windowTitle().endswith("*")
    w.config_page.undo(); app.processEvents()
    assert not w.windowTitle().endswith("*")

    # Make the business state concrete before visual review: choose a valid
    # generation configuration and generate real RTL/TB artifacts.
    w.config_page.generation_editor.arch.setCurrentText("original_pipe")
    w.config_page.generation_editor.sel_mode.setCurrentText("sync")
    controller.generate_current()
    assert controller.generation_state == "up_to_date", controller.generation_state
    artifacts=w.config_page.artifacts_panel
    assert artifacts.file_selector.count() > 0, "artifacts did not load"
    assert artifacts.file_tree.topLevelItemCount() > 0, "artifact tree did not load"
    assert any(text.endswith(("New","Modified","Unchanged")) for text in tree_texts(artifacts.file_tree))
    assert w.log_panel.status_bar.isVisible(), "generation status bar is hidden"
    assert w.log_panel.status_label.text().startswith(("生成完成：", "输出已是最新："))
    assert "生成完成：" not in w.log_panel.output.toPlainText()

    for idx,name in enumerate(("controller","lane-mapping","signals","generation")):
        w.config_page.tabs.setCurrentIndex(idx); shot(w,f"01-{name}")
    w.toggle_log(); shot(w,"02-main-with-log")

    # New projects without an active workspace use a stable user directory,
    # not the temporary screenshot workspace.
    dlg=NewProjectDialog(Path.home(),w)
    dlg.name.setText("new-project")
    button_box=dlg.findChild(QtWidgets.QDialogButtonBox)
    create_button=button_box.button(QtWidgets.QDialogButtonBox.Ok)
    cancel_button=button_box.button(QtWidgets.QDialogButtonBox.Cancel)
    assert dlg.location.text() == str(Path.home()/"plm-projects")
    assert create_button.text() == "创建项目" and cancel_button.text() == "取消"
    assert create_button.iconSize() == QtCore.QSize(20,20)
    assert cancel_button.iconSize() == QtCore.QSize(20,20)
    assert not create_button.icon().isNull() and not cancel_button.icon().isNull()
    dlg.show(); shot(dlg,"03-new-project"); dlg.close()

    w.on_open_settings(); app.processEvents()
    required_fonts=(
        "Microsoft YaHei UI", "PingFang SC", "Noto Sans CJK SC",
        "SimHei", "SimSun", "Source Han Sans SC",
    )
    for idx,name in enumerate(("general","appearance","tools","formatter")):
        w.placeholder_overlay.menu_buttons[idx].click()
        shot(w,f"04-settings-{name}")
        if name == "appearance":
            font_combo=w.findChild(QtWidgets.QComboBox,"SettingsFontFamily")
            assert font_combo is not None
            assert all(font_combo.findText(font) >= 0 for font in required_fonts)
            selected=font_combo.currentIndex()
            font_combo.setCurrentIndex(0)
            font_combo.showPopup()
            font_combo.view().scrollToTop()
            screen_shot("04-settings-appearance-fonts")
            font_combo.hidePopup()
            font_combo.setCurrentIndex(selected)
    w._close_placeholder()
    w.on_open_docs(); app.processEvents()
    for idx,name in enumerate(("getting-started","configuration","generation")):
        w.placeholder_overlay.menu_buttons[idx].click(); shot(w,f"05-docs-{name}")
    w._close_placeholder()

    artifacts.show_search(); shot(w,"06-artifacts-search")
    w.config_page.toggle_artifacts_maximized(); shot(w,"07-artifacts-maximized")

    # Force one preview-only content change to prove unified diff rendering.
    selected_path=Path(artifacts.file_selector.currentData())
    selected_path.write_text(selected_path.read_text(encoding="utf-8")+"\n// visual diff check\n",encoding="utf-8")
    files=[Path(artifacts.file_selector.itemData(i)) for i in range(artifacts.file_selector.count())]
    relative=selected_path.relative_to(project).as_posix()
    artifacts.set_files(files,project,statuses={relative:"Modified"})
    artifacts.diff_button.setChecked(True)
    app.processEvents()
    assert artifacts.diff_button.isEnabled()
    assert artifacts.preview.toPlainText().startswith("--- previous/")
    shot(w,"08-artifacts-diff")
    w.close()
