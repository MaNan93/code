import contextlib
import io
import unittest
from unittest import mock

from plm.cli import main as cli


class CliEntryPointTests(unittest.TestCase):
    def test_help_returns_success(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = cli.main(["--help"])
        self.assertEqual(result, 0)
        self.assertIn("plm -gui", output.getvalue())

    def test_gui_short_flag_launches_qt(self):
        with mock.patch.object(cli, "cmd_gui", return_value=17) as launch:
            self.assertEqual(cli.main(["-gui"]), 17)
        launch.assert_called_once_with([])

    def test_gui_long_flag_launches_qt(self):
        with mock.patch.object(cli, "cmd_gui", return_value=17) as launch:
            self.assertEqual(cli.main(["--gui", "-style", "Fusion"]), 17)
        launch.assert_called_once_with(["-style", "Fusion"])


if __name__ == "__main__":
    unittest.main()
