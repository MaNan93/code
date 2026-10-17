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

    def test_arch_and_pclk_mode_each_imply_the_other(self):
        captured = {}

        def fake_generate(_csv_dir, _out_rtl, options, **_kwargs):
            captured["options"] = options
            return mock.Mock(generated=True)

        cases = (
            ([], ("original_pipe", "pclk_as_phy_output")),
            (["--arch", "serdes"], ("serdes", "pclk_as_phy_input")),
            (["--pclk-mode", "pclk_as_phy_input"], ("serdes", "pclk_as_phy_input")),
            (["--pclk-mode", "pclk_as_phy_output"], ("original_pipe", "pclk_as_phy_output")),
            # A contradictory pair is passed through for validation to reject.
            (["--arch", "serdes", "--pclk-mode", "pclk_as_phy_output"],
             ("serdes", "pclk_as_phy_output")),
        )
        with mock.patch.object(cli, "resolve_set", return_value=(Path("cfg"), Path("rtl"))), \
                mock.patch.object(cli, "generate", side_effect=fake_generate), \
                contextlib.redirect_stdout(io.StringIO()):
            for flags, expected in cases:
                with self.subTest(flags=flags):
                    cli.cmd_generate(["--config", "demo", *flags])
                    options = captured["options"]
                    self.assertEqual((options.arch, options.pclk_mode), expected)

    def test_quiet_generate_still_reports_warnings(self):
        result = mock.Mock(generated=True)
        result.plan.warnings.return_value = ["Controller count (3) doesn't match"]
        errors = io.StringIO()
        with mock.patch.object(cli, "resolve_set", return_value=(Path("cfg"), Path("rtl"))), \
                mock.patch.object(cli, "generate", return_value=result), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
            cli.cmd_generate(["--config", "demo", "--quiet"])
        self.assertIn("warning: Controller count (3)", errors.getvalue())

    def test_missing_config_never_falls_back_to_packaged_defaults(self):
        from plm.core import paths

        with tempfile.TemporaryDirectory() as temporary:
            packaged = Path(temporary) / "packaged"
            packaged.mkdir()
            for name in paths.CSV_NAMES:
                (packaged / name).write_text("", encoding="utf-8")
            with mock.patch.object(paths, "BUILTIN_CFG", packaged):
                with self.assertRaisesRegex(SystemExit, "not found"):
                    paths.resolve_set(str(Path(temporary) / "typo"))

    def test_named_examples_and_explicit_paths_resolve_to_the_same_workspace(self):
        from plm.core import paths

        with tempfile.TemporaryDirectory() as temporary:
            examples = Path(temporary).resolve() / "examples"
            config = examples / "demo" / "config"
            config.mkdir(parents=True)
            for name in paths.CSV_NAMES:
                (config / name).write_text("", encoding="utf-8")
            with mock.patch.object(paths, "CONFIGS_ROOT", examples):
                self.assertEqual(paths.list_configs(), ["demo"])
                for argument in ("demo", str(config.parent), str(config)):
                    with self.subTest(argument=argument):
                        self.assertEqual(paths.resolve_set(argument), (config, config.parent / "rtl"))

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
