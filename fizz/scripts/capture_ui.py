"""Capture all workflows using disposable config and sample data."""

import argparse
import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault(
    "QT_QPA_PLATFORM", "windows" if sys.platform == "win32" else "offscreen"
)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from fizz.frontend.qt.main_window import MainWindow
from fizz.frontend.qt.widgets.preferences_dialog import PreferencesDialog
from PyQt5 import QtCore, QtGui, QtWidgets

from fizz import core


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("ui-screenshots"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    app = QtWidgets.QApplication([])
    app.setStyle("Fusion")
    font = QtGui.QFont("Segoe UI")
    font.setPixelSize(16)
    app.setFont(font)
    with tempfile.TemporaryDirectory(prefix="fizz-preview-") as tmp:
        settings = QtCore.QSettings(
            str(Path(tmp) / "layout.ini"), QtCore.QSettings.IniFormat
        )
        window = MainWindow(
            config=core.FizzConfig(str(Path(tmp) / "fizz.ini")),
            settings=settings,
            script_dir=tmp,
        )
        window.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        window.controller.stop_timers()
        merge = window.pages["merge"]
        merge.msg_path_edit.setText("D:/workspace/pcie_ctrl/sim/generalMessage.txt")
        merge.out_path_edit.setText("D:/workspace/pcie_ctrl/release/one.sv")
        merge.dir_filter_edit.setText("*/testbench/*, */verification/*")
        merge.file_filter_edit.setText("*_tb.sv")
        merge.file_listwidget.addItems(
            [
                "rtl/include/pcie_defs.svh",
                "rtl/include/pipe_types.svh",
                "rtl/pcie_ctrl_wrapper.sv",
                "rtl/pcie_link_controller.sv",
                "rtl/pipe_lane_mapper.sv",
            ]
        )
        merge.merge_status_label.setText("解析完成: included=2, source=3")
        rlskit = window.pages["rlskit"]
        rlskit.rlskit_src_edit.setText("D:/workspace/pcie_ctrl/release")
        rlskit.rlskit_ftp_url_edit.setText("ftp://release.example/pcie/")
        rlskit.rlskit_ftp_user_edit.setText("release")
        window.controller._update_rlskit_preview()
        window.controller._on_rlskit_upload_progress(65 * 1048576, 100 * 1048576)
        rlskit.rlskit_log.setPlainText(
            "10:24:01 > 打包完成: pcie_ctrl_V1P0.tar.gz\n10:24:02 > 正在上传到 FTP...\n"
        )
        for key in ("vcs", "obf"):
            page = window.pages[key]
            getattr(page, f"{key}_src_edit").setText(
                "D:/workspace/pcie_ctrl/release/one.sv"
            )
        window.pages["vcs"].vcs_key_edit.setText("D:/tools/vcs/sim2-key.txt")
        window.pages["postsim"].postsim_dir_edit.setText("D:/workspace/pcie_ctrl/sim")
        window.pages["postsim"].postsim_list.addItems(
            ["regression/link_training.log", "regression/pipe_mapping.log"]
        )
        window.pages["postsim"].postsim_stats_label.setText("匹配文件数：2")
        window.controller.stop_timers()
        window.show()
        for key in window.pages:
            window.select_workflow(key)
            app.processEvents()
            window.grab().save(str(args.output / f"{key}.png"))
        window.nav_panel.set_collapsed(True, animate=False)
        app.processEvents()
        window.grab().save(str(args.output / "collapsed.png"))
        window.nav_panel.set_collapsed(False, animate=False)
        window.select_workflow("rlskit")
        rlskit.rn_text.setPlainText(
            "Release V1P0\n\n- 更新 PCIe 控制器接口\n- 修复 PIPE lane mapping\n"
        )
        rlskit.output_tabs.setCurrentIndex(1)
        app.processEvents()
        window.grab().save(str(args.output / "release-note.png"))
        preferences = PreferencesDialog({}, lambda value: tmp, window)
        preferences.setAttribute(QtCore.Qt.WA_DontShowOnScreen)
        preferences.show()
        app.processEvents()
        preferences.grab().save(str(args.output / "settings.png"))
        preferences.close()
        window.resize(900, 640)
        window.select_workflow("obf")
        app.processEvents()
        window.grab().save(str(args.output / "minimum.png"))
        page = window.pages["obf"]
        page.scroll.ensureWidgetVisible(page.obf_run_btn)
        app.processEvents()
        window.grab().save(str(args.output / "minimum-action.png"))
        window.close()
    print(f"Saved 10 screenshots to {args.output.resolve()}")


if __name__ == "__main__":
    main()
