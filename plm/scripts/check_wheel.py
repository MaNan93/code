"""Install a wheel into a temporary target and smoke-test CLI, Qt and generation.

Run with a Python environment that already has the Qt extra installed.
The same script runs on Linux and Windows without assuming a venv bin path.
"""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile


CHECK = r'''
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch
import plm
from PyQt5 import QtCore, QtWidgets
from plm.core.paths import DOCS_DIR, PLM_ROOT
from plm.core.workspace import scaffold_default_content
from plm.frontend.qt.widgets.common import APP_ICON_PATH, PROJECT_ROOT
from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import SettingsStore

assert Path(plm.__file__).resolve().is_relative_to(Path(sys.argv[1]).resolve())
assert PROJECT_ROOT == PLM_ROOT
assert (DOCS_DIR / 'tool_usage.md').is_file()
assert (DOCS_DIR / 'qt_frontend_guide.md').is_file()
assert APP_ICON_PATH.is_file()
assert (PLM_ROOT / 'frontend/qt/widgets/lanegrid.py').is_file()
assert (PLM_ROOT / 'frontend/qt/widgets/tables.py').is_file()
app = QtWidgets.QApplication([])
app.setStyle('Fusion')
with tempfile.TemporaryDirectory(prefix='plm wheel smoke ') as temporary:
    root = Path(temporary).resolve()
    config = root / 'project with spaces'
    scaffold_default_content(config)
    store = SettingsStore(QtCore.QSettings(str(root/'settings.ini'), QtCore.QSettings.IniFormat))
    controller = AppController(settings_store=store)
    with patch('plm.frontend.qt.main_window.AppController', return_value=controller):
        window = MainWindow()
    window.show()
    app.processEvents()
    assert controller.current_project is None
    with patch.object(QtWidgets.QFileDialog, 'getExistingDirectory', return_value=str(config)):
        controller.open_project()
    assert controller.current_project.config_dir == config/'config'
    for arch in ('original_pipe', 'serdes'):
        for dpr in (False, True):
            page = window.config_page
            page.generation_editor.arch.setCurrentText(arch)
            page.generation_editor.dpr.setChecked(dpr)
            controller.generate_current()
            assert controller.generation_state == 'up_to_date', controller.generation_state
            top = (config/'rtl/src/pipe_lane_mapper.sv').read_text(encoding='utf-8')
            assert 'endmodule' in top
            assert 'dft_mode' not in top
            assert (config/'tb/tb_pipe_lane_mapper.sv').is_file()
    window.on_open_settings()
    window.secondary_overlay.menu_buttons[2].click()
    app.processEvents()
    assert window.secondary_overlay.formatter_panel.isVisible()
    window._close_secondary_page()
    window.on_open_docs()
    app.processEvents()
    assert 'PLM Qt' in window.secondary_overlay.doc_browser.toPlainText()
    window.close()
print('Installed wheel: CLI, Qt resources, Formatter, docs and all 4 clock/DPR combinations passed.')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wheel", type=Path, nargs="?")
    args = parser.parse_args()
    if args.wheel is None:
        wheels = list(Path("dist").glob("plm-*.whl"))
        if len(wheels) != 1:
            parser.error("pass one wheel path, or keep exactly one PLM wheel in dist/")
        args.wheel = wheels[0]
    wheel = args.wheel.resolve()
    if not wheel.is_file():
        parser.error(f"wheel not found: {wheel}")
    with tempfile.TemporaryDirectory(prefix="plm wheel check ") as temporary:
        root = Path(temporary)
        target = root / "installed"
        subprocess.run(["uv", "pip", "install", "--no-deps", "--target", str(target), str(wheel)], check=True)
        env = dict(os.environ, PYTHONPATH=str(target), QT_QPA_PLATFORM="offscreen")
        subprocess.run([sys.executable, "-m", "plm.cli.main", "--help"], cwd=root, env=env, check=True)
        subprocess.run([sys.executable, "-c", CHECK, str(target)], cwd=root, env=env, check=True)


if __name__ == "__main__":
    main()
