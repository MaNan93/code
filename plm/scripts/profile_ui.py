"""Measure Qt rendering with real widgets, isolated data and hidden windows.

Run with the native Qt platform for font rendering; offscreen is also supported.
Timing results are machine dependent and are deliberately not test thresholds.
"""

import argparse
import cProfile
import json
import platform
import statistics
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.controllers import AppController
from plm.frontend.qt.main_window import MainWindow
from plm.frontend.qt.services import ProjectService, SettingsStore
from plm.frontend.qt.widgets.common import StyledMenu
from plm.frontend.qt.widgets.option_switch import OptionSwitch
from qt_smoke_support import dispose_window, wait_for_idle


def measure(callback, iterations):
    for _ in range(3):
        callback()
    samples = []
    for _ in range(iterations):
        start = time.perf_counter_ns()
        callback()
        samples.append((time.perf_counter_ns() - start) / 1_000_000)
    ordered = sorted(samples)
    return {
        "median_ms": round(statistics.median(samples), 3),
        "p95_ms": round(ordered[max(0, int(len(ordered) * .95) - 1)], 3),
        "samples": len(samples),
    }


def renderer(widget):
    ratio = widget.devicePixelRatioF()
    pixmap = QtGui.QPixmap(round(widget.width() * ratio), round(widget.height() * ratio))
    pixmap.setDevicePixelRatio(ratio)

    def render():
        pixmap.fill(QtCore.Qt.transparent)
        widget.render(pixmap)

    return render


def run(iterations, screenshot_dir=None):
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    app.setStyle("Fusion")
    results = {}
    widget_counts = {}
    with tempfile.TemporaryDirectory(prefix="plm-profile-") as directory:
        root = Path(directory)
        settings = SettingsStore(QtCore.QSettings(str(root / "settings.ini"), QtCore.QSettings.IniFormat))
        controller = AppController(ProjectService(root), settings)
        with patch("plm.frontend.qt.main_window.AppController", return_value=controller):
            window = MainWindow()
        window.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        window.show()
        wait_for_idle(app)
        window_size = f"{window.width()} x {window.height()}"
        page = window.config_page
        payload = {
            "controllers": [
                {"ctrl_id": str(i), "ctrl_name": f"Ctrl{chr(65 + i)}", "max_width": "8"}
                for i in range(4)
            ],
            "mapping": {"lane_count": 32, "rows": [
                {"mode": str(mode), **{f"lane{i}": f"{i // 8}-{i % 8}" for i in range(32)}}
                for mode in range(10)
            ]},
            "signals": [
                {"signal_name": f"signal_{i}", "signal_type": "perlane", "direction": "mac2phy",
                 "width": "32", "safe_state": "0", "tie_off": "0"}
                for i in range(100)
            ],
        }
        page.set_content(payload)
        wait_for_idle(app)
        if screenshot_dir:
            screenshot_dir.mkdir(parents=True, exist_ok=True)
        try:
            for index, name in enumerate(("controller", "lanes_32", "signals_100")):
                page.tabs.setCurrentIndex(index)
                wait_for_idle(app)
                results[f"render_{name}"] = measure(renderer(window), iterations)
                if name == "signals_100":
                    widget_counts["comboboxes"] = len(window.findChildren(QtWidgets.QComboBox))
                    widget_counts["option_switches"] = len(window.findChildren(OptionSwitch))
                    widget_counts["menus"] = len(window.findChildren(QtWidgets.QMenu))
                if screenshot_dir:
                    window.grab().save(str(screenshot_dir / f"{name}.png"))

            signals = page.signals_editor

            def reload_signals():
                signals.set_rows(payload["signals"])
                wait_for_idle(app)

            results["reload_signals_100"] = measure(reload_signals, max(5, iterations // 4))
            changed = False

            def update_signals():
                nonlocal changed
                changed = not changed
                rows = [{**row, "width": "64" if changed else "32"} for row in payload["signals"]]
                signals.set_rows(rows)
                wait_for_idle(app)

            results["update_signals_100"] = measure(update_signals, max(5, iterations // 4))
            paths = []
            for i in range(100):
                path = root / "rtl" / ("common" if i < 50 else "src") / f"source_{i:03d}.sv"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("// Generated source\nmodule example;\ninput logic data;\n"
                                + "assign data = 32'hCAFE;\n" * 1000 + "endmodule\n", encoding="utf-8")
                paths.append(path)
            panel = page.artifacts_panel
            panel.file_popup.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
            panel.set_files(paths, root)
            wait_for_idle(app)
            page.toggle_artifacts()
            wait_for_idle(app)
            page.toggle_artifacts_maximized()
            wait_for_idle(app)
            results["render_artifacts_1004_lines"] = measure(renderer(window), iterations)
            results["highlight_1004_lines"] = measure(panel.preview.highlighter.rehighlight,
                                                      max(5, iterations // 4))
            if screenshot_dir:
                window.grab().save(str(screenshot_dir / "artifacts.png"))
            panel.path_button.click()
            wait_for_idle(app)
            results["render_tree_100_files"] = measure(renderer(panel.file_popup), iterations)
            if screenshot_dir:
                panel.file_popup.grab().save(str(screenshot_dir / "file_tree.png"))
            panel.file_popup.hide()
            menu = StyledMenu(window)
            menu.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
            for label, button in (("刷新文件", panel.refresh_button),
                                  ("在编辑器中打开", panel.open_editor_button),
                                  ("搜索当前文件", panel.search_button),
                                  ("复制文件路径", panel.copy_path_button)):
                menu.addAction(button.icon(), label)
            menu.popup(QtCore.QPoint(0, 0))
            wait_for_idle(app)
            results["render_menu"] = measure(renderer(menu), iterations)
            menu.close()
            menu.deleteLater()
            page.hide_artifacts()
            wait_for_idle(app)

            def switch_tabs():
                for index in (0, 1, 2):
                    page.tabs.setCurrentIndex(index)
                    wait_for_idle(app)

            results["switch_three_tabs"] = measure(switch_tabs, max(5, iterations // 4))
        finally:
            dispose_window(app, window)
    return {
        "environment": {"os": platform.platform(), "python": platform.python_version(),
                        "qt": QtCore.QT_VERSION_STR, "platform": app.platformName(),
                        "window": window_size, "device_pixel_ratio": app.devicePixelRatio()},
        "metrics": results,
        "widgets_after_signals": widget_counts,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iterations", type=int, default=40)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("--screenshots", type=Path)
    args = parser.parse_args()
    if args.iterations < 5:
        parser.error("--iterations must be at least 5")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.profile:
        args.profile.parent.mkdir(parents=True, exist_ok=True)
    profiler = cProfile.Profile() if args.profile else None
    if profiler:
        profiler.enable()
    report = run(args.iterations, args.screenshots)
    if profiler:
        profiler.disable()
        profiler.dump_stats(str(args.profile))
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
