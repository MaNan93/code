"""Capture the current Qt UI pages for visual review."""
import os
import html
import json
import shutil
import tempfile
from pathlib import Path
from unittest.mock import patch
from PyQt5 import QtCore, QtGui, QtTest, QtWidgets
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import SettingsStore
from plm.frontend.qt.views.new_project_dialog import NewProjectDialog
from plm.frontend.qt.widgets.common import StyledMenu
from plm.frontend.qt.widgets.lanegrid import LaneGrid
from plm.frontend.qt.styles.tokens import FONT_FAMILY, ICON_BUTTON_SIZE, ICON_SIZE
from qt_smoke_support import wait_for_idle

OUT=Path(os.environ.get("PLM_SCREENSHOT_DIR","ui-screenshots")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
app.setStyle("Fusion")


def shot(widget,name):
    QtTest.QTest.qWait(200)
    wait_for_idle(app)
    QtTest.QTest.qWait(300)
    wait_for_idle(app)
    app.processEvents()
    if "docs-" in name:
        assert len(widget.view_stack.currentWidget().doc_browser.toPlainText().strip()) > 80
    assert widget.grab().save(str(OUT/f"{name}.png")), name
    print(f"Captured: {name}", flush=True)


def screen_shot(name):
    app.processEvents()
    app.primaryScreen().grabWindow(0).save(str(OUT/f"{name}.png"))


def prepare_capture(widget):
    if os.environ.get("PLM_CAPTURE_HEADLESS") == "1":
        widget.setAttribute(QtCore.Qt.WA_DontShowOnScreen)


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
    # Use a real multi-controller/multi-mode fixture instead of nearly empty defaults.
    sample_config = Path(__file__).resolve().parents[1] / "tests/fixtures/samples/dpr/config"
    for name in ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv", "gen_flags.txt"):
        shutil.copyfile(sample_config / name, project / "config" / name)
    store=SettingsStore(QtCore.QSettings(str(root/"settings.ini"),QtCore.QSettings.IniFormat))
    controller=AppController(settings_store=store)
    with patch("plm.frontend.qt.main_window.AppController",return_value=controller):
        w=MainWindow()
    prepare_capture(w)
    w.show(); wait_for_idle(app)

    # Visual review uses the fixed font baseline and CJK fallback stack.
    stylesheet=app.styleSheet()
    assert f'font-family: {FONT_FAMILY};' in stylesheet

    with patch.object(QtWidgets.QFileDialog,"getExistingDirectory",return_value=str(project)):
        controller.open_project()
    wait_for_idle(app)
    assert w.config_page.controllers_editor.table.rowCount() > 0, "controllers did not load"
    assert w.config_page.controllers_editor.table.item(0, 1).text() == "CtrlA", "controller text did not load"
    table = w.config_page.controllers_editor.table
    header_metrics = table.horizontalHeader().fontMetrics()
    for index in (0, 2):
        heading = table.horizontalHeaderItem(index).text()
        assert table.columnWidth(index) >= header_metrics.horizontalAdvance(heading) + 24, heading
    assert not w.config_page.controllers_editor.table.verticalHeader().isVisible(), "Controller row header is visible"
    assert w.config_page.mapping_editor.table.rowCount() > 0, "lane mapping did not load"
    assert w.config_page.signals_editor.table.rowCount() >= 30, "default signal data is incomplete"

    # Main-branch table behavior: row drag/reorder and context menus.
    assert hasattr(w.config_page.controllers_editor.table, "rowMoveRequested")
    assert hasattr(w.config_page.signals_editor.table, "rowMoveRequested")
    assert not w.config_page.findChildren(QtWidgets.QPushButton, "ConfigRowButton")
    controller_editor=w.config_page.controllers_editor
    row_menu=StyledMenu(controller_editor.table)
    prepare_capture(row_menu)
    row_menu.addAction("在上方插入行")
    row_menu.addAction("在下方插入行")
    row_menu.addSeparator()
    row_menu.addAction("删除当前行")
    first_item=controller_editor.table.item(0,0)
    menu_pos=controller_editor.table.visualItemRect(first_item).center()
    row_menu.popup(controller_editor.table.viewport().mapToGlobal(menu_pos))
    row_menu.setActiveAction(row_menu.actions()[0])
    shot(row_menu,"01-controller-context-menu")
    row_menu.close(); row_menu.deleteLater()

    # Main-branch LaneGrid behavior and product-mode lane picker.
    mapping=w.config_page.mapping_editor
    assert isinstance(mapping.editor, LaneGrid)
    assert [mapping.lane_count.itemText(i) for i in range(5)] == ["x2","x4","x8","x16","x32"]
    assert mapping.editor.controllers and mapping.editor.active_ctrl_id is not None

    # Project rows keep the three-dot menu and right-click entry point;
    # the redundant Clear action is intentionally removed (Archive already hides
    # a project without deleting its files).
    project_widget=w.nav_panel.project_list.project_widgets[0]
    assert project_widget.header.contextMenuPolicy() == QtCore.Qt.CustomContextMenu
    project_menu=project_widget.build_more_menu()
    prepare_capture(project_menu)
    project_actions=[action.text() for action in project_menu.actions() if not action.isSeparator()]
    assert project_actions == ["置顶", "重命名", "打开所在目录", "重新载入", "归档", "删除"]
    project_menu.popup(project_widget.header.mapToGlobal(QtCore.QPoint(12,project_widget.header.height())))
    project_menu.setActiveAction(project_menu.actions()[0])
    shot(project_menu,"00-project-context-menu")
    project_menu.close(); project_menu.deleteLater()
    project_widget._set_menu_open(True)
    shot(project_widget, "00-project-more-active")
    project_widget._set_menu_open(False)
    collapsed = QtTest.QSignalSpy(w.nav_panel.animation_group.finished)
    w.nav_panel.toggle_collapse()
    assert collapsed.wait(1000)
    shot(w.nav_panel, "00-sidebar-collapsed")
    expanded = QtTest.QSignalSpy(w.nav_panel.animation_group.finished)
    w.nav_panel.toggle_collapse()
    assert expanded.wait(1000)

    # Dirty state is visible in the custom window title, then undo restores it.
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
    controller.generate_current()
    wait_for_idle(app)
    assert controller.generation_state == "up_to_date", controller.generation_state
    artifacts=w.config_page.artifacts_panel
    assert artifacts.selection.files, "artifacts did not load"
    assert artifacts.preview.font().fixedPitch(), "RTL preview font is not fixed pitch"
    assert artifacts.file_tree.topLevelItemCount() > 0, "artifact tree did not load"
    assert any(text.endswith(("New","Modified","Unchanged")) for text in tree_texts(artifacts.file_tree))
    assert w.log_panel.status_bar.isVisible(), "generation status bar is hidden"
    assert w.log_panel.status_label.text().startswith(("生成完成：", "输出已是最新："))
    assert "生成完成：" not in w.log_panel.output.toPlainText()
    w.hide_log()

    for idx,name in enumerate(("controller","lane-mapping","signals","generation")):
        w.config_page.tabs.setCurrentIndex(idx); app.processEvents()
        if name == "signals":
            assert w.config_page.signals_editor.table.height() > 300, "Signals table did not fill available height"
        shot(w,f"01-{name}")
        if name == "signals":
            w.config_page.signals_editor.editor.search_input.setText("txdata")
            shot(w, "01-signals-search")
            w.config_page.signals_editor.editor.search_input.clear()
    w.toggle_log(); shot(w,"02-main-with-log")

    # New projects without an active workspace use a stable user directory,
    # not the temporary screenshot workspace.
    dlg=NewProjectDialog(None,w)
    dlg.name.setText("new-project")
    button_box=dlg.findChild(QtWidgets.QDialogButtonBox)
    create_button=button_box.button(QtWidgets.QDialogButtonBox.Ok)
    cancel_button=button_box.button(QtWidgets.QDialogButtonBox.Cancel)
    assert dlg.location.text() == os.path.expanduser("~/plm-projects")
    assert create_button.text() == "创建项目" and cancel_button.text() == "取消"
    assert create_button.iconSize() == QtCore.QSize(ICON_SIZE,ICON_SIZE)
    assert cancel_button.iconSize() == QtCore.QSize(ICON_SIZE,ICON_SIZE)
    assert not create_button.icon().isNull() and not cancel_button.icon().isNull()
    prepare_capture(dlg)
    dlg.show(); shot(dlg,"03-new-project"); dlg.close()
    for title, description, name in (
        ("删除项目", "此操作会同时删除源文件，且不可恢复。", "delete"),
        ("归档项目", "归档后，项目会从当前列表移除，但源文件不会删除。", "archive"),
    ):
        box = QtWidgets.QMessageBox(QtWidgets.QMessageBox.Question, title,
                                   f"确定要{title} [bifurcate] 吗？\n\n{description}",
                                   QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No, w)
        prepare_capture(box)
        box.show(); app.processEvents()
        dialog_image = box.grab().toImage()
        assert dialog_image.pixelColor(2, box.height() // 2).name() == "#ffffff"
        assert dialog_image.pixelColor(2, box.height() // 2).alpha() == 255
        shot(box, f"03-confirm-{name}")
        box.close(); box.deleteLater()

    w.on_open_settings(); app.processEvents()
    for idx,name in enumerate(("general","formatter")):
        page=w.view_stack.currentWidget()
        page.menu_buttons[idx].click()
        if name == "formatter":
            assert page.settings_content_layout.getContentsMargins() == (0,0,0,24)
            assert page.settings_content_layout.stretch(page._formatter_layout_index) == 1
            assert page.settings_content_layout.stretch(page._bottom_stretch_index) == 0
            align_control=page._flag_controls["assignment_statement_alignment"]
            assert align_control.itemText(0) == "align (default)"
            assert align_control.itemData(0) == "align"
            assert [align_control.itemText(i) for i in range(1, align_control.count())] == [
                "flush-left", "preserve", "infer"
            ]
            indent_control=page._flag_controls["formal_parameters_indentation"]
            assert indent_control.itemText(0) == "indent (default)"
            assert page._flag_controls["column_limit"].text() == "120"
            assert page.flag_table.horizontalHeaderItem(1).text() == "值"
            assert page.flag_table.horizontalHeader().isHidden()
            button_texts=[button.text() for button in page.formatter_panel.findChildren(QtWidgets.QPushButton)]
            assert "项目默认参数" not in button_texts
            assert "使用 Verible 默认参数" not in button_texts
            assert "自动检测" not in button_texts
            assert page.flag_table.verticalScrollMode() == QtWidgets.QAbstractItemView.ScrollPerPixel
        if name == "general":
            assert page.setting_rows["editor"].isVisible()
            shot(page.setting_rows["editor"], "04-settings-editor-row")
        shot(w,f"04-settings-{name}")
        if name == "formatter":
            align_control=page._flag_controls["assignment_statement_alignment"]
            prepare_capture(align_control.popup_menu)
            align_control.showPopup()
            shot(align_control.popup_menu,"04-settings-formatter-defaults")
            align_control.hidePopup()
            page.formatter_group.setCurrentIndex(1)
            shot(w, "04-settings-indentation")
            page.formatter_group.setCurrentIndex(2)
            shot(w, "04-settings-other")
            numeric = page._flag_controls["line_break_penalty"]
            row = list(page._flag_controls).index("line_break_penalty")
            page.flag_table.scrollToItem(page.flag_table.item(row, 0))
            page.flag_table.selectRow(row)
            numeric.setFocus(QtCore.Qt.OtherFocusReason)
            app.processEvents()
            rect = page.flag_table.visualItemRect(page.flag_table.item(row, 0))
            value_rect = page.flag_table.visualItemRect(page.flag_table.item(row, 1))
            table_image = page.flag_table.viewport().grab().toImage()
            assert table_image.pixelColor(2, rect.top() + 1) == table_image.pixelColor(value_rect.left() + 2, rect.top() + 1)
            shot(w, "04-tools-numeric")
    w._close_secondary_page()
    w.on_open_docs(); app.processEvents()
    for idx,name in enumerate(("getting-started","configuration","generation")):
        w.view_stack.currentWidget().menu_buttons[idx].click(); shot(w,f"05-docs-{name}")
    w._close_secondary_page()

    w.config_page.toggle_artifacts()
    QtTest.QTest.qWait(w.config_page._artifacts_animation.duration() + 20)
    assert artifacts.isVisible()
    artifacts.show_search()
    search_layout=artifacts.search_bar.layout()
    assert search_layout.spacing() == 8
    assert search_layout.getContentsMargins() == (0,0,12,0)
    search_buttons=artifacts.search_bar.findChildren(QtWidgets.QPushButton)
    assert len(search_buttons) == 3
    assert all(button.size() == QtCore.QSize(ICON_BUTTON_SIZE,ICON_BUTTON_SIZE) for button in search_buttons)
    shot(w,"06-artifacts-search")
    w.config_page.toggle_artifacts_maximized(); shot(w,"07-artifacts-maximized")

    # Force one preview-only content change to prove unified diff rendering.
    selected_path=artifacts.current_path
    selected_path.write_text(selected_path.read_text(encoding="utf-8")+"\n// visual diff check\n",encoding="utf-8")
    files=list(artifacts.selection.files)
    relative=selected_path.relative_to(project).as_posix()
    artifacts.set_files(files,project,statuses={relative:"Modified"})
    wait_for_idle(app)
    artifacts.diff_button.setChecked(True)
    wait_for_idle(app)
    assert artifacts.diff_button.isEnabled()
    assert artifacts.preview.toPlainText().startswith("--- previous/")
    shot(w,"08-artifacts-diff")
    w.config_page.toggle_artifacts_maximized()
    w.config_page.hide_artifacts()
    w.hide_log()
    from plm.frontend.qt.services.themes import apply_application_theme
    apply_application_theme("dark")
    for idx, name in enumerate(("controller", "lane-mapping", "signals", "generation")):
        w.config_page.tabs.setCurrentIndex(idx)
        shot(w, f"dark-{name}")
    w.on_open_settings()
    wait_for_idle(app)
    for idx, name in enumerate(("general", "formatter")):
        page = w.view_stack.currentWidget()
        page.menu_buttons[idx].click()
        shot(w, f"dark-settings-{name}")
    for idx, name in ((1, "indentation"), (2, "other")):
        page.formatter_group.setCurrentIndex(idx)
        shot(w, f"dark-settings-{name}")
    w.on_open_docs()
    for idx, name in enumerate(("getting-started", "configuration", "generation")):
        w.view_stack.currentWidget().menu_buttons[idx].click()
        shot(w, f"dark-docs-{name}")
    w._close_secondary_page()
    w.config_page.toggle_artifacts()
    shot(w, "dark-artifacts")
    w.config_page.hide_artifacts()
    w.resize(960, 640)
    w.config_page.tabs.setCurrentIndex(3)
    shot(w, "09-compact-generation-dark")
    w.on_open_settings()
    shot(w, "09-compact-settings-dark")
    w.on_open_docs()
    shot(w, "09-compact-docs-dark")
    w._close_secondary_page()
    w.config_page.mark_saved()
    w.close()

manifest = []
cards = []
for path in sorted(OUT.glob("*.png")):
    picture = QtGui.QImage(str(path))
    assert not picture.isNull(), path
    manifest.append({"file": path.name, "width": picture.width(), "height": picture.height()})
    filename = html.escape(path.name)
    cards.append(f'<figure><a href="{filename}"><img loading="lazy" src="{filename}" alt="{filename}"></a>'
                 f'<figcaption>{filename} · {picture.width()} × {picture.height()}</figcaption></figure>')
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
(OUT / "index.html").write_text(
    '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>PLM Qt 界面截图</title>'
    '<style>body{font:14px system-ui;background:#edf1f7;margin:24px;color:#172033}'
    'main{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:20px}'
    'figure{margin:0;padding:12px;background:white;border-radius:10px}img{width:100%;height:280px;object-fit:contain}'
    'figcaption{padding-top:10px}a{color:inherit}</style>'
    f'<h1>PLM Qt 界面截图</h1><p>{len(manifest)} 张截图，包含深浅主题与窄窗口。点击查看原图。</p>'
    '<main>' + ''.join(cards) + '</main></html>', encoding="utf-8")
print(f"Gallery: {OUT / 'index.html'} ({len(manifest)} screenshots)")
