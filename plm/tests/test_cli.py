import contextlib
import io
import unittest
from unittest import mock

import plm
from plm.cli import main as cli


class CliEntryPointTests(unittest.TestCase):
    def test_help_returns_success(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = cli.main(["--help"])
        self.assertEqual(result, 0)
        self.assertIn("plm -gui", output.getvalue())
        self.assertIn("plm --version", output.getvalue())

    def test_version_returns_package_version(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = cli.main(["--version"])
        self.assertEqual(result, 0)
        self.assertEqual(output.getvalue(), f"plm {plm.__version__}\n")

    def test_generate_is_one_command(self):
        with mock.patch.object(cli, "cmd_generate", return_value=23) as generate:
            self.assertEqual(cli.main(["generate", "--config", "demo"]), 23)
        generate.assert_called_once_with(["--config", "demo"])

    def test_gui_short_flag_launches_qt(self):
        with mock.patch.object(cli, "cmd_gui", return_value=17) as launch:
            self.assertEqual(cli.main(["-gui"]), 17)
        launch.assert_called_once_with([])

    def test_gui_long_flag_launches_qt(self):
        with mock.patch.object(cli, "cmd_gui", return_value=17) as launch:
            self.assertEqual(cli.main(["--gui", "-style", "Fusion"]), 17)
        launch.assert_called_once_with(["-style", "Fusion"])

    def test_gui_entry_point_imports_and_forwards_arguments(self):
        from plm.frontend.qt import main as qt

        self.assertTrue(qt.APP_ICON_PATH.is_file())
        with mock.patch.object(qt, "main", return_value=17) as launch:
            self.assertEqual(cli.cmd_gui(["-style", "Fusion"]), 17)
        launch.assert_called_once_with(["-style", "Fusion"])


if __name__ == "__main__":
    unittest.main()
