"""Measure live theme changes, including event delivery and a rendered frame.

Run with the native Qt platform for representative timing. Windows remain hidden,
and projects/settings live in a temporary directory. Timings are informational;
StyleChange counts expose repeated widget-tree traversal without time thresholds.
"""

import argparse
import json
import platform
import shutil
import statistics
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from qt_smoke_support import dispose_window, wait_for_idle


class StyleChangeCounter(QtCore.QObject):
    def __init__(self):
        super().__init__()
        self.count = 0

    def eventFilter(self, watched, event):
        if event.type() == QtCore.QEvent.StyleChange:
            self.count += 1
        return False


def settle(app):
    wait_for_idle(app)
    QtCore.QCoreApplication.sendPostedEvents(None, QtCore.QEvent.DeferredDelete)
    app.processEvents()


def measure(app, window, iterations):
    # Warm up both directions before measuring; include settings persistence.
    for theme in ("dark", "light"):
        window.apply_theme(theme)
        settle(app)
        window.grab()
    synchronous, rendered = [], []
    for index in range(iterations):
        start = time.perf_counter()
        window.apply_theme("dark" if index % 2 == 0 else "light")
        synchronous.append((time.perf_counter() - start) * 1000)
        app.processEvents()
        window.grab()
        rendered.append((time.perf_counter() - start) * 1000)
        settle(app)
    counter = StyleChangeCounter()
    app.installEventFilter(counter)
    try:
        window.apply_theme("light" if index % 2 == 0 else "dark")
        settle(app)
    finally:
        app.removeEventFilter(counter)
    return {
        "widgets": len(app.allWidgets()),
        "style_change_events": counter.count,
        "samples": iterations,
        "synchronous_median_ms": round(statistics.median(synchronous), 3),
        "rendered_median_ms": round(statistics.median(rendered), 3),
        "rendered_max_ms": round(max(rendered), 3),
    }


def run(iterations, screenshots=None):
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    app.setStyle("Fusion")
    metrics = {}
    with tempfile.TemporaryDirectory(prefix="plm-theme-profile-") as directory:
        root = Path(directory)
        fixture = Path(__file__).resolve().parents[1] / "tests/fixtures/samples/dpr/config"
        shutil.copytree(fixture, root / "test/demo/config")
        store = SettingsStore(QtCore.QSettings(str(root / "settings.ini"), QtCore.QSettings.IniFormat))
        controller = AppController(ProjectService(root), store)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        window.show()
        settle(app)
        if screenshots:
            screenshots.mkdir(parents=True, exist_ok=True)
        try:
            for scenario in ("main", "settings_general", "settings_tools", "formatter_preview", "general_after_tools", "docs"):
                if scenario == "settings_general":
                    window.on_open_settings()
                elif scenario == "settings_tools":
                    window.view_stack.currentWidget().menu_buttons[1].click()
                elif scenario == "formatter_preview":
                    window.view_stack.currentWidget().formatter_mode.setCurrentIndex(1)
                elif scenario == "general_after_tools":
                    window.view_stack.currentWidget().menu_buttons[0].click()
                elif scenario == "docs":
                    window.on_open_docs()
                settle(app)
                metrics[scenario] = measure(app, window, iterations)
                print(scenario, json.dumps(metrics[scenario]), flush=True)
                if screenshots:
                    for theme in ("dark", "light"):
                        window.apply_theme(theme)
                        settle(app)
                        assert window.grab().save(str(screenshots / f"{scenario}-{theme}.png"))
        finally:
            dispose_window(app, window)
    return {
        "environment": {
            "os": platform.platform(), "python": platform.python_version(),
            "qt": QtCore.QT_VERSION_STR, "platform": app.platformName(),
            "window": "1280 x 800", "device_pixel_ratio": app.devicePixelRatio(),
        },
        "metrics": metrics,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iterations", type=int, default=6)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--screenshots", type=Path)
    args = parser.parse_args()
    if args.iterations < 2:
        parser.error("--iterations must be at least 2")
    report = run(args.iterations, args.screenshots)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
