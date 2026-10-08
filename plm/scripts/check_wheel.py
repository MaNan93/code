"""Check release contents and exercise an installed wheel outside the checkout.

The base CLI is tested without Qt, then the Qt extra is installed for the GUI
checks. All environments and generated workspaces live in a temporary folder.
"""

import argparse
import configparser
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
from zipfile import ZipFile


PACKAGE_DATA = (
    "plm/docs/*.md",
    "plm/core/common/*.sv",
    "plm/core/config/*.csv",
    "plm/core/tb_makefile.mk",
    "plm/frontend/qt/assets/*.png",
    "plm/frontend/qt/assets/*.svg",
    "plm/frontend/qt/assets/icons/*.svg",
    "plm/frontend/qt/styles/*.qss",
)


def installed_smoke_environment(scripts, installation_env):
    """Exercise the wheel without inheriting checkout tools from PATH."""
    env = dict(installation_env)
    paths = [str(scripts)]
    if os.name == "nt":
        # Keep Windows system commands available without retaining unrelated
        # developer tools, including an optional external SV formatter.
        system_root = env.get("SystemRoot") or env.get("SYSTEMROOT")
        if system_root:
            paths.append(str(Path(system_root) / "System32"))
    env["PATH"] = os.pathsep.join(paths)
    return env


def package_files(root):
    """Return the release's Python modules and explicitly declared resources."""
    source = Path(root) / "src"
    paths = set((source / "plm").rglob("*.py"))
    for pattern in PACKAGE_DATA:
        paths.update(source.glob(pattern))
    return {path.relative_to(source).as_posix(): path for path in paths if path.is_file()}


def check_wheel_contents(wheel, root):
    expected = package_files(root)
    if not expected:
        raise AssertionError("No package source files found")
    with ZipFile(wheel) as archive:
        names = {name for name in archive.namelist() if not name.endswith("/")}
        actual = {name for name in names if name.startswith("plm/")}
        metadata_dirs = {name.split("/", 1)[0] for name in names
                         if name.split("/", 1)[0].endswith(".dist-info")}
        if len(metadata_dirs) != 1:
            raise AssertionError("Wheel must contain one top-level metadata directory")
        metadata_prefix = next(iter(metadata_dirs)) + "/"
        unexpected = {name for name in names if not name.startswith("plm/")
                      and not name.startswith(metadata_prefix)}
        if actual != set(expected) or unexpected:
            raise AssertionError(
                f"Wheel files differ from source: missing={sorted(set(expected) - actual)}, "
                f"extra={sorted(actual - set(expected) | unexpected)}"
            )
        stale = [name for name, path in expected.items() if archive.read(name) != path.read_bytes()]
        if stale:
            raise AssertionError(f"Wheel contains stale source/resource bytes: {sorted(stale)}")
        entries = [name for name in names if name.endswith(".dist-info/entry_points.txt")]
        if len(entries) != 1:
            raise AssertionError("Wheel must contain one console entry-point definition")
        parser = configparser.ConfigParser()
        parser.read_string(archive.read(entries[0]).decode("utf-8"))
        if dict(parser["console_scripts"]) != {
            "plm": "plm.cli.main:main",
            "plm-gui": "plm.frontend.qt.main:main",
        }:
            raise AssertionError("Wheel console entry points differ from the release contract")
    return len(expected)


def check_sdist_contents(sdist, root):
    root = Path(root)
    expected = {"README.md", "CLAUDE.md", "MANIFEST.in", "pyproject.toml", "run.py", "uv.lock"}
    expected.update("src/" + name for name in package_files(root))
    for folder, suffixes in (("scripts", {".py"}), ("tests", {".py", ".md"}),
                             ("tests/fixtures", {".csv", ".txt", ".json"})):
        expected.update(path.relative_to(root).as_posix() for path in (root / folder).rglob("*")
                        if path.is_file() and path.suffix in suffixes)
    with tarfile.open(sdist) as archive:
        members = [member for member in archive.getmembers() if member.isfile()]
        prefixes = {member.name.split("/", 1)[0] for member in members}
        if len(prefixes) != 1:
            raise AssertionError("Source distribution must have one top-level directory")
        actual = {member.name.split("/", 1)[1] for member in members}
        unwanted = {name for name in actual if name.split("/", 1)[0] in {
            "test", "build", "dist", ".venv", ".git", ".workbuddy"
        } or "__pycache__" in Path(name).parts or name.endswith((".pyc", ".pyo", ".log"))}
        if expected - actual or unwanted:
            raise AssertionError(
                f"Source distribution contents differ: missing={sorted(expected - actual)}, "
                f"unwanted={sorted(unwanted)}"
            )
        by_name = {member.name.split("/", 1)[1]: member for member in members}
        stale = []
        for name in expected:
            with archive.extractfile(by_name[name]) as source:
                if source.read() != (root / name).read_bytes():
                    stale.append(name)
        if stale:
            raise AssertionError(f"Source distribution contains stale bytes: {sorted(stale)}")
    return len(actual)


CLI_CHECK = r'''
from importlib.util import find_spec
from pathlib import Path
import subprocess
import sys
import tempfile
import plm
from plm.core.paths import COMMON_DIR, TB_MAKEFILE
from plm.core.workspace import scaffold_default_content
from plm.core.verible import find_verible

assert Path(plm.__file__).resolve().is_relative_to(Path(sys.argv[1]).resolve())
assert plm.__version__ == '2.0.4'
assert find_spec('PyQt5') is None, 'The base CLI check must run without Qt'
assert len(list(COMMON_DIR.glob('*.sv'))) == 5
assert TB_MAKEFILE.is_file()
assert find_verible() is None, 'The wheel smoke must not inherit a host Formatter'
def run_cli(command):
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        raise AssertionError(result.stdout)

with tempfile.TemporaryDirectory(prefix='plm CLI wheel ') as temporary:
    root = Path(temporary) / 'workspace with spaces'
    scaffold_default_content(root)
    version = subprocess.run([sys.argv[2], '--version'], stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, check=True)
    assert version.stdout.strip() == 'plm 2.0.4'
    run_cli([sys.argv[2], 'validate', '--config', str(root)])
    for arch, pclk in (('original_pipe', 'pclk_as_phy_output'), ('serdes', 'pclk_as_phy_input')):
        for sel, dpr in (('sync', False), ('comb', False), ('sync', True)):
            command = [sys.argv[2], 'generate', '--config', str(root), '--arch', arch,
                       '--pclk-mode', pclk, '--sel-mode', sel, '--quiet']
            if dpr:
                command.append('--dpr')
            run_cli(command)
            assert (root/'rtl/src/pipe_lane_mapper.sv').is_file()
            assert (root/'tb/tb_pipe_lane_mapper.sv').is_file()
for name, module in list(sys.modules.items()):
    if name == 'plm' or name.startswith('plm.'):
        assert Path(module.__file__).resolve().is_relative_to(Path(sys.argv[1]).resolve()), name
print('Installed base wheel: console CLI, resources and 6 generation combinations passed without Qt.')
'''


CHECK = r'''
from importlib.metadata import distribution
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch
sys.path.insert(0, sys.argv[2])
from qt_smoke_support import dispose_window, wait_for_idle
import plm
from PyQt5 import QtCore, QtWidgets
from plm.core.paths import DOCS_DIR, PLM_ROOT
from plm.core.workspace import scaffold_default_content
from plm.core.verible import find_verible
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
assert find_verible() is None, 'The wheel smoke must not inherit a host Formatter'
app = QtWidgets.QApplication([])
app.setStyle('Fusion')
for name in ('critical', 'information', 'question', 'warning'):
    patcher = patch.object(QtWidgets.QMessageBox, name,
                           side_effect=AssertionError(f'Unexpected QMessageBox.{name}'))
    patcher.start()
with tempfile.TemporaryDirectory(prefix='plm wheel smoke ') as temporary:
    root = Path(temporary).resolve()
    config = root / 'project with spaces'
    scaffold_default_content(config)
    store = SettingsStore(QtCore.QSettings(str(root/'settings.ini'), QtCore.QSettings.IniFormat))
    controller = AppController(settings_store=store)
    with patch('plm.frontend.qt.main_window.AppController', return_value=controller):
        window = MainWindow()
    # CLI smoke assertions must retain Python's traceback instead of the GUI
    # application's interactive error handler.
    sys.excepthook = sys.__excepthook__
    window.show()
    wait_for_idle(app)
    print('Qt smoke: window ready.', flush=True)
    assert controller.current_project is None
    with patch.object(QtWidgets.QFileDialog, 'getExistingDirectory', return_value=str(config)):
        controller.open_project()
    wait_for_idle(app)
    assert controller.current_project.config_dir == config/'config'
    print('Qt smoke: project loaded.', flush=True)
    for arch in ('original_pipe', 'serdes'):
        for dpr in (False, True):
            page = window.config_page
            page.generation_editor.arch.setCurrentText(arch)
            page.generation_editor.dpr.setChecked(dpr)
            controller.generate_current()
            wait_for_idle(app)
            assert controller.generation_state == 'up_to_date', controller.generation_state
            top = (config/'rtl/src/pipe_lane_mapper.sv').read_text(encoding='utf-8')
            assert 'endmodule' in top
            assert 'dft_mode' not in top
            assert (config/'tb/tb_pipe_lane_mapper.sv').is_file()
    print('Qt smoke: 4 generation combinations passed.', flush=True)
    window.on_open_settings()
    window.view_stack.currentWidget().menu_buttons[1].click()
    app.processEvents()
    assert window.view_stack.currentWidget().formatter_panel.isVisible()
    window._close_secondary_page()
    window.on_open_docs()
    wait_for_idle(app)
    assert 'PLM Qt' in window.view_stack.currentWidget().doc_browser.toPlainText()
    print('Qt smoke: settings and documents ready.', flush=True)
    entry = {entry.name: entry for entry in distribution('plm').entry_points}['plm-gui']
    with patch('plm.frontend.qt.main.QtWidgets.QApplication', return_value=app), \
         patch('plm.frontend.qt.main.MainWindow', return_value=window), \
         patch.object(app, 'exec_', return_value=0):
        assert entry.load()([]) == 0
    print('Qt smoke: GUI entry point passed.', flush=True)
    dispose_window(app, window)
    print('Qt smoke: native resources released.', flush=True)
for name, module in list(sys.modules.items()):
    if name == 'plm' or name.startswith('plm.'):
        assert Path(module.__file__).resolve().is_relative_to(Path(sys.argv[1]).resolve()), name
print('Installed Qt wheel: GUI entry point, resources, Formatter, docs and 4 clock/DPR combinations passed.')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wheel", type=Path, nargs="?")
    parser.add_argument("--sdist", type=Path, help="Also validate source distribution contents")
    args = parser.parse_args()
    if args.wheel is None:
        wheels = list(Path("dist").glob("plm-*.whl"))
        if len(wheels) != 1:
            parser.error("pass one wheel path, or keep exactly one PLM wheel in dist/")
        args.wheel = wheels[0]
    wheel = args.wheel.resolve()
    if not wheel.is_file():
        parser.error(f"wheel not found: {wheel}")
    source_root = Path(__file__).resolve().parents[1]
    uv = shutil.which("uv")
    if uv is None:
        parser.error("uv was not found on PATH")
    print(f"Wheel: {check_wheel_contents(wheel, source_root)} package files match source.", flush=True)
    if args.sdist:
        print(f"Source distribution: {check_sdist_contents(args.sdist, source_root)} files checked.", flush=True)
    with tempfile.TemporaryDirectory(prefix="plm wheel check ") as temporary:
        root = Path(temporary)
        target = root / "environment"
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", PYTHONNOUSERSITE="1")
        for name in ("PYTHONPATH", "PYTHONHOME", "VIRTUAL_ENV", "UV_PROJECT_ENVIRONMENT", "UV_PROJECT"):
            env.pop(name, None)
        subprocess.run([uv, "venv", "--python", sys.executable, str(target)], cwd=root, env=env, check=True)
        scripts = target / ("Scripts" if os.name == "nt" else "bin")
        interpreter = scripts / ("python.exe" if os.name == "nt" else "python")
        cli = scripts / ("plm.exe" if os.name == "nt" else "plm")
        gui = scripts / ("plm-gui.exe" if os.name == "nt" else "plm-gui")
        subprocess.run([uv, "pip", "install", "--python", str(interpreter), str(wheel)],
                       cwd=root, env=env, check=True)
        assert cli.is_file() and gui.is_file(), "Installed console scripts are missing"
        smoke_env = installed_smoke_environment(scripts, env)
        subprocess.run([str(cli), "--help"], cwd=root, env=smoke_env, check=True)
        runner = [uv, "run", "--no-project", "--python", str(interpreter),
                  "python", "-X", "faulthandler", "-c"]
        subprocess.run([*runner, CLI_CHECK, str(target), str(cli)], cwd=root, env=smoke_env, check=True)
        subprocess.run([uv, "pip", "install", "--python", str(interpreter), f"{wheel}[qt]"],
                       cwd=root, env=env, check=True)
        subprocess.run([*runner, CHECK, str(target), str(Path(__file__).resolve().parent)],
                       cwd=root, env=smoke_env, check=True)


if __name__ == "__main__":
    main()
