"""Check both themes and window sizes in a fresh Qt process for every scale.

Use the native platform for Windows verification, QT_QPA_PLATFORM=offscreen for
headless Linux. Reports identify the actual OS, Qt plugin and device pixel ratio.
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch


def worker(scale, screenshots, font_dir):
    from PyQt5 import QtCore, QtGui, QtWidgets
    from plm.frontend.qt.controllers import AppController
    from plm.frontend.qt.main_window import MainWindow
    from plm.frontend.qt.services import ProjectService, SettingsStore
    from qt_smoke_support import dispose_window, wait_for_idle

    QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_EnableHighDpiScaling, True)
    QtWidgets.QApplication.setAttribute(QtCore.Qt.AA_UseHighDpiPixmaps, True)
    app = QtWidgets.QApplication([])
    app.setStyle("Fusion")
    if not font_dir and os.name == "nt" and not QtGui.QFontDatabase().families():
        font_dir = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"
    if font_dir:
        for name in ("segoeui.ttf", "consola.ttf", "msyh.ttc"):
            path = font_dir / name
            if path.is_file():
                QtGui.QFontDatabase.addApplicationFont(str(path))
    checks = []

    def inside(widget, parent):
        rectangle = QtCore.QRect(widget.mapTo(parent, QtCore.QPoint()), widget.size())
        assert parent.rect().contains(rectangle), (widget.objectName(), rectangle, parent.rect())

    def settle():
        wait_for_idle(app)
        QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
        app.processEvents()

    def capture(window, name):
        settle()
        pixmap = window.grab()
        ratio = window.devicePixelRatioF()
        assert abs(pixmap.width() - round(window.width() * ratio)) <= 1
        assert abs(pixmap.height() - round(window.height() * ratio)) <= 1
        if screenshots:
            screenshots.mkdir(parents=True, exist_ok=True)
            assert pixmap.save(str(screenshots / (name + ".png")))
        checks.append({"page": name, "logical_size": [window.width(), window.height()],
                       "pixel_size": [pixmap.width(), pixmap.height()], "device_pixel_ratio": ratio})

    with tempfile.TemporaryDirectory(prefix="plm-ui-scale-") as directory:
        root = Path(directory)
        fixture = Path(__file__).resolve().parents[1] / "tests/fixtures/samples/dpr/config"
        shutil.copytree(fixture, root / "examples/demo/config")
        controller = AppController(ProjectService(root), SettingsStore(
            QtCore.QSettings(str(root / "settings.ini"), QtCore.QSettings.IniFormat)))
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        window.show()
        settle()
        try:
            for width, height in ((960, 640), (1280, 800)):
                window.resize(width, height)
                for theme in ("light", "dark"):
                    window.apply_theme(theme)
                    settle()
                    prefix = f"{scale:g}-{width}-{theme}"
                    page = window.config_page
                    for index, name in enumerate(("controller", "lanes", "signals", "generation")):
                        page.tabs.setCurrentIndex(index)
                        settle()
                        if name == "generation":
                            inside(page.generation_editor.generate_btn, page.tabs.widget(index))
                            scroll = page.tabs.widget(index).scroll
                            assert scroll.horizontalScrollBar().maximum() == 0
                        bar = page.tabs.tabBar()
                        for tab in range(bar.count()):
                            option = QtWidgets.QStyleOptionTab()
                            bar.initStyleOption(option, tab)
                            text_rect = bar.style().subElementRect(QtWidgets.QStyle.SE_TabBarTabText, option, bar)
                            assert text_rect.width() >= option.fontMetrics.horizontalAdvance(page.tabs.tabText(tab))
                        capture(window, prefix + "-" + name)
                    window.show_log()
                    settle()
                    assert window.log_panel.isVisible()
                    capture(window, prefix + "-log-open")
                    window.hide_log()
                    settle()
                    assert not window.log_panel.isVisible()
                    inside(window.log_toggle_button, window.title_bar)
                    window.on_open_settings()
                    settle()
                    settings = window.view_stack.currentWidget()
                    inside(settings.general_card, settings)
                    inside(settings.save_settings_btn, settings)
                    capture(window, prefix + "-settings")
                    settings.menu_buttons[1].click()
                    capture(window, prefix + "-formatter")
                    settings.formatter_mode.setCurrentIndex(1)
                    settle()
                    inside(settings.formatter_preview, settings)
                    capture(window, prefix + "-preview")
                    window.on_open_docs()
                    for index, name in enumerate(("intro", "config", "generate")):
                        docs = window.view_stack.currentWidget()
                        docs.menu_buttons[index].click()
                        settle()
                        inside(docs.page_panel, docs)
                        assert len(docs.doc_browser.toPlainText()) > 80
                        capture(window, prefix + "-docs-" + name)
                    window._close_secondary_page()
                    settle()
        finally:
            dispose_window(app, window)
    return {"requested_scale": scale, "os": platform.platform(), "python": platform.python_version(),
            "qt": QtCore.QT_VERSION_STR, "platform": app.platformName(),
            "borrowed_font_directory": str(font_dir) if font_dir else None, "checks": checks}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scales", default="1,1.25,1.5,2")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--screenshots", type=Path)
    parser.add_argument("--font-dir", type=Path)
    parser.add_argument("--worker", type=float, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.worker is not None:
        print(json.dumps(worker(args.worker, args.screenshots, args.font_dir)))
        return
    if not args.output:
        parser.error("--output is required")
    reports = []
    for scale in map(float, args.scales.split(",")):
        environment = dict(os.environ, QT_SCALE_FACTOR=str(scale), PYTHONDONTWRITEBYTECODE="1")
        command = [sys.executable, "-B", str(Path(__file__).resolve()), "--worker", str(scale)]
        for flag, value in (("--screenshots", args.screenshots), ("--font-dir", args.font_dir)):
            if value:
                command.extend((flag, str(value.resolve())))
        result = subprocess.run(command, env=environment, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        report = json.loads(result.stdout)
        reports.append(report)
        print(f"scale={scale:g}: {len(report['checks'])} checks passed ({report['os']}, {report['platform']})", flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
