import contextlib
import io
from pathlib import Path
import tempfile
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

    @mock.patch("plm.core.verible.find_verible", return_value=None)
    def test_generate_bus_type_is_explicit_and_defaults_to_legacy_bus(self, _formatter):
        from plm.core.workspace import save_workspace_content
        from test_core import valid_payload

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = valid_payload()
            payload["gen_flags"] = {"bus-type": "flat"}
            save_workspace_content(root, payload)
            args = ["--config", str(root), "--quiet"]
            with contextlib.redirect_stdout(io.StringIO()):
                cli.cmd_generate(args)
            wrapper = root / "rtl/src/pipe_lane_mapper_connection.sv"
            self.assertIn("phy_mac_phy_txdata [0:NL-1]", wrapper.read_text())
            with contextlib.redirect_stdout(io.StringIO()):
                cli.cmd_generate(args + ["--bus-type", "flat"])
            self.assertIn("logic [NL * 8 - 1:0] phy_mac_phy_txdata", wrapper.read_text())
            before = wrapper.read_bytes()
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
                cli.cmd_generate(args + ["--bus-type", "invalid"])
            self.assertEqual(error.exception.code, 2)
            self.assertEqual(wrapper.read_bytes(), before)

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
