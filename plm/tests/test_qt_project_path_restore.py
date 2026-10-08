import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import wait_for_idle
from PyQt5 import QtWidgets

from plm.frontend.qt.models import ProjectInfo
from plm.frontend.qt.widgets.project_list import ProjectList


class ProjectPathRestoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def test_project_row_reveals_workspace_root_and_keeps_it_after_rename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve() / "demo"
            config = root / "config"
            config.mkdir(parents=True)
            project = ProjectInfo(
                name="demo",
                config_dir=config,
                controllers_csv=config / "controllers.csv",
                lane_mapping_csv=config / "lane_mapping.csv",
                pipe_signals_csv=config / "pipe_signals.csv",
            )
            project_list = ProjectList([project])
            self.addCleanup(project_list.deleteLater)
            widget = project_list.project_widgets[0]
            self.assertEqual(widget.project_path, root)

            with patch(
                "plm.frontend.qt.widgets.project_item.open_in_file_manager"
            ) as reveal:
                actions = {action.text(): action for action in widget.build_more_menu().actions()}
                actions["打开所在目录"].trigger()
                wait_for_idle(self.app)
                reveal.assert_called_once_with(root)

            renamed_root = Path(directory).resolve() / "renamed"
            project_list.apply_rename("demo", "renamed", renamed_root / "config")
            self.assertEqual(widget.project_path, renamed_root)


if __name__ == "__main__":
    unittest.main()
