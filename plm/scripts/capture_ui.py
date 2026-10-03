"""Capture the current Qt UI pages for visual review."""
import os
import tempfile
from pathlib import Path
from unittest.mock import patch
from PyQt5 import QtCore, QtGui, QtWidgets
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import SettingsStore
from plm.frontend.qt.views.new_project_dialog import NewProjectDialog

OUT=Path(os.environ.get("PLM_SCREENSHOT_DIR","ui-screenshots")).resolve()
OUT.mkdir(parents=True,exist_ok=True)
app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
app.setStyle("Fusion")
font=QtGui.QFont("Microsoft YaHei UI"); app.setFont(font)

def shot(widget,name):
    app.processEvents()
    widget.grab().save(str(OUT/f"{name}.png"))

with tempfile.TemporaryDirectory(prefix="plm ui ") as td:
    root=Path(td)
    project=root/"demo-project"
    scaffold_default_content(project)
    store=SettingsStore(QtCore.QSettings(str(root/"settings.ini"),QtCore.QSettings.IniFormat))
    controller=AppController(settings_store=store)
    with patch("plm.frontend.qt.main_window.AppController",return_value=controller):
        w=MainWindow()
    w.resize(1400,900); w.show(); app.processEvents()
    with patch.object(QtWidgets.QFileDialog,"getExistingDirectory",return_value=str(project)):
        controller.open_project()
    app.processEvents()
    assert w.config_page.controllers_editor.table.rowCount() > 0, "controllers did not load"
    assert w.config_page.controllers_editor.table.item(0, 1).text() == "CtrlA", "controller text did not load"
    assert w.config_page.mapping_editor.table.rowCount() > 0, "lane mapping did not load"
    assert w.config_page.signals_editor.table.rowCount() > 0, "signals did not load"
    # Make the business state concrete before visual review: choose a valid
    # generation configuration and generate real RTL/TB artifacts.
    w.config_page.generation_editor.arch.setCurrentText("original_pipe")
    w.config_page.generation_editor.sel_mode.setCurrentText("sync")
    controller.generate_current()
    assert controller.generation_state == "up_to_date", controller.generation_state
    assert w.config_page.artifacts_panel.file_selector.count() > 0, "artifacts did not load"
    for idx,name in enumerate(("controller","lane-mapping","signals","generation")):
        w.config_page.tabs.setCurrentIndex(idx); shot(w,f"01-{name}")
    w.toggle_log(); shot(w,"02-main-with-log")
    dlg=NewProjectDialog(root,w); dlg.name.setText("new-project"); dlg.show(); shot(dlg,"03-new-project"); dlg.close()
    w.on_open_settings(); app.processEvents()
    for idx,name in enumerate(("general","appearance","tools","formatter")):
        w.placeholder_overlay.menu_buttons[idx].click(); shot(w,f"04-settings-{name}")
    w._close_placeholder()
    w.on_open_docs(); app.processEvents()
    for idx,name in enumerate(("getting-started","configuration","generation")):
        w.placeholder_overlay.menu_buttons[idx].click(); shot(w,f"05-docs-{name}")
    w._close_placeholder()
    w.config_page.artifacts_panel.show_search(); shot(w,"06-artifacts-search")
    w.config_page.toggle_artifacts_maximized(); shot(w,"07-artifacts-maximized")
    w.close()
