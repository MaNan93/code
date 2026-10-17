from pathlib import Path
import json
import shutil
import tempfile
import unittest
from unittest import mock

from sample_data import sample_config

from plm.core import exporter
from plm.core.gen_flags import GenerationOptions
from plm.core.locking import LOCK_FILENAME
from plm.core.model import Config
from plm.core.plan import GenerationPlan, MANIFEST_SCHEMA_VERSION
from plm.core.service import generate
from plm.core.paths import DOCS_DIR, WORKSPACE_MARKER, is_deletable_workspace
from plm.core.workspace import (
    load_default_signals,
    read_csv_rows,
    save_workspace_content,
    write_aligned_csv,
)
from plm.core.validation import (
    ValidationError,
    load_generation_plan,
    load_generation_plan_from_payload,
)
from plm.core import validation


ROOT = Path(__file__).resolve().parents[1]


def valid_payload():
    return {
        "controllers": [{"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "2"}],
        "signals": [{
            "signal_name": "mac_phy_txdata", "signal_type": "perlane",
            "direction": "mac2phy", "width": "8", "safe_state": "0", "tie_off": "0",
        }, {
            "signal_name": "phy_mac_rxdata", "signal_type": "perlane",
            "direction": "phy2mac", "width": "8", "safe_state": "0", "tie_off": "0",
        }],
        "mapping": {"lane_count": 2, "rows": [{"mode": "0", "lane0": "0-0", "lane1": "0-1"}]},
    }


class ConfigValidationTests(unittest.TestCase):
    def make_config(self, controllers=None, signals=None, mapping=None):
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        payload = valid_payload()
        if controllers is not None:
            payload["controllers"] = controllers
        if signals is not None:
            payload["signals"] = signals
        if mapping is not None:
            payload["mapping"] = mapping
        save_workspace_content(root, payload)
        self.addCleanup(temp.cleanup)
        return root / "config"

    def assert_config_error(self, **changes):
        cfg_dir = self.make_config(**changes)
        with self.assertRaises(SystemExit):
            Config(cfg_dir)

    def test_rejects_duplicate_normalized_controller_names(self):
        self.assert_config_error(controllers=[
            {"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "1"},
            {"ctrl_id": "1", "ctrl_name": "ctrla", "max_width": "1"},
        ])

    def test_rejects_invalid_identifiers(self):
        self.assert_config_error(controllers=[
            {"ctrl_id": "0", "ctrl_name": "bad-name", "max_width": "2"},
        ])

    def test_rejects_gapped_controller_ids(self):
        self.assert_config_error(controllers=[
            {"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "1"},
            {"ctrl_id": "2", "ctrl_name": "CtrlB", "max_width": "1"},
        ])

    def test_rejects_negative_safe_state(self):
        signal = valid_payload()["signals"][0]
        signal["safe_state"] = "-1"
        self.assert_config_error(signals=[signal])

    def test_rejects_shared_phy2mac_signal(self):
        signal = valid_payload()["signals"][0]
        signal.update({
            "signal_name": "phy_mac_status",
            "signal_type": "shared",
            "direction": "phy2mac",
        })
        cfg_dir = self.make_config(signals=[signal])
        with self.assertRaisesRegex(
            SystemExit,
            "phy2mac signals must use signal_type=perlane",
        ):
            Config(cfg_dir)

    def test_rejects_lane_whose_ctrl_lane_index_moves_between_modes(self):
        """A phy lane must keep one ctrl lane index per owner across modes.

        The generators resolve that index once, from the first mode the owner
        appears in, and wire it for every mode -- so a lane that swaps port
        index between two modes silently produces a mux wired to the wrong
        port. Two lanes in one group can swap indices while still leaving every
        port's drivers inside that single group, so the cross-group rule does
        not catch this on its own.
        """
        cfg_dir = self.make_config(
            controllers=[
                {"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "4"},
                {"ctrl_id": "1", "ctrl_name": "CtrlB", "max_width": "2"},
            ],
            mapping={"lane_count": 4, "rows": [
                {"mode": "0", "lane0": "0-0", "lane1": "0-1", "lane2": "0-2", "lane3": "0-3"},
                {"mode": "1", "lane0": "0-0", "lane1": "0-1", "lane2": "1-0", "lane3": "1-1"},
                {"mode": "2", "lane0": "0-0", "lane1": "0-1", "lane2": "1-1", "lane3": "1-0"},
            ]},
        )
        errors = Config(cfg_dir).validate()
        self.assertTrue(
            any("maps to more than one CtrlB lane across modes" in e for e in errors),
            f"expected the moving-port-index error, got: {errors}",
        )

    def test_accepts_lane_keeping_one_ctrl_lane_index_per_owner(self):
        """The same shape without the swap must stay valid -- the new rule has
        to reject a moving index, not a controller changing width."""
        cfg_dir = self.make_config(
            controllers=[
                {"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "4"},
                {"ctrl_id": "1", "ctrl_name": "CtrlB", "max_width": "2"},
            ],
            mapping={"lane_count": 4, "rows": [
                {"mode": "0", "lane0": "0-0", "lane1": "0-1", "lane2": "0-2", "lane3": "0-3"},
                {"mode": "1", "lane0": "0-0", "lane1": "0-1", "lane2": "1-0", "lane3": "1-1"},
            ]},
        )
        self.assertEqual(Config(cfg_dir).validate(), [])

    def test_accepts_excel_utf8_bom(self):
        config_dir = self.make_config()
        for name in ("controllers.csv", "pipe_signals.csv", "lane_mapping.csv"):
            path = config_dir / name
            path.write_bytes(b"\xef\xbb\xbf" + path.read_bytes())
        validation.load_validated_config(config_dir)
        self.assertEqual(
            list(read_csv_rows(config_dir / "controllers.csv")[0]),
            ["ctrl_id", "ctrl_name", "max_width"],
        )

    def test_rejects_integers_that_are_not_plain_decimal(self):
        for controllers, mapping in (
            ([{"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "0_2"}], None),
            ([{"ctrl_id": "+0", "ctrl_name": "CtrlA", "max_width": "2"}], None),
            (None, {"lane_count": 2, "rows": [{"mode": "0", "lane0": "0-0", "lane1": "+0-1"}]}),
            (None, {"lane_count": 2, "rows": [{"mode": "0_0", "lane0": "0-0", "lane1": "0-1"}]}),
        ):
            with self.subTest(controllers=controllers, mapping=mapping):
                with self.assertRaises(SystemExit):
                    Config(self.make_config(controllers=controllers, mapping=mapping))

    def test_signal_literals_accept_prefixes_but_not_python_extras(self):
        def signals(safe_state, tie_off):
            rows = valid_payload()["signals"]
            rows[1].update(safe_state=safe_state, tie_off=tie_off)
            return rows

        config = Config(self.make_config(signals=signals("0x50", "0B101")))
        self.assertEqual((config.signals[1].safe_state, config.signals[1].tie_value), (0x50, 5))
        for safe_state, tie_off in (("1_0", "0"), ("+1", "0"), ("0", "0x_5"), ("0", "+1")):
            with self.subTest(safe_state=safe_state, tie_off=tie_off):
                with self.assertRaises(SystemExit):
                    Config(self.make_config(signals=signals(safe_state, tie_off)))

    def bifurcated_x8_x4_x4(self):
        lanes = [f"lane{index}" for index in range(16)]
        wide = [f"0-{index}" for index in range(16)]
        split = wide[:8] + [f"1-{index}" for index in range(4)] + [f"2-{index}" for index in range(4)]
        return self.make_config(
            controllers=[
                {"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "16"},
                {"ctrl_id": "1", "ctrl_name": "CtrlB", "max_width": "4"},
                {"ctrl_id": "2", "ctrl_name": "CtrlC", "max_width": "4"},
            ],
            mapping={"lane_count": 16, "rows": [
                dict(zip(["mode"] + lanes, ["0"] + wide)),
                dict(zip(["mode"] + lanes, ["1"] + split)),
            ]},
        )

    def test_controller_count_mismatch_is_a_warning_not_an_error(self):
        config = validation.load_validated_config(self.bifurcated_x8_x4_x4())
        warnings = config.warnings()
        self.assertEqual(len(warnings), 1)
        self.assertIn("Controller count (3)", warnings[0])
        self.assertIn("Warnings", config.report())
        self.assertEqual(Config(sample_config("bifurcate")).warnings(), [])
        self.assertNotIn("Warnings", Config(sample_config("bifurcate")).report())

    def test_topology_issue_points_at_the_named_controller_row(self):
        config_dir = self.make_config(controllers=[
            {"ctrl_id": "1", "ctrl_name": "Ctrl1", "max_width": "1"},
            {"ctrl_id": "0", "ctrl_name": "Ctrl10", "max_width": "9"},
        ], mapping={"lane_count": 2, "rows": [{"mode": "0", "lane0": "0-0", "lane1": "1-0"}]})
        with self.assertRaises(ValidationError) as caught:
            validation.load_validated_config(config_dir)
        issue = next(issue for issue in caught.exception.issues if "max_width=9" in issue.message)
        self.assertEqual((issue.table, issue.row, issue.column), ("controllers", 1, "max_width"))

    def test_rejects_non_sequential_lane_headers(self):
        cfg_dir = self.make_config()
        mapping = cfg_dir / "lane_mapping.csv"
        mapping.write_text("mode,foo,bar\n0,0-0,0-1\n", encoding="utf-8")
        with self.assertRaises(SystemExit):
            Config(cfg_dir)


class WorkspaceTests(unittest.TestCase):
    def test_failed_save_keeps_all_original_files(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            save_workspace_content(root, valid_payload())
            before = {p.name: p.read_bytes() for p in (root / "config").iterdir()}
            broken = valid_payload()
            broken["controllers"][0]["ctrl_name"] = "Changed"
            broken["mapping"]["lane_count"] = "not-an-int"
            with self.assertRaises(ValueError):
                save_workspace_content(root, broken)
            after = {p.name: p.read_bytes() for p in (root / "config").iterdir()}
            self.assertEqual(before, after)

    def test_csv_writer_round_trips_quoted_values(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "x.csv"
            write_aligned_csv(path, ["a", "b"], [["comma,value", 'a "quote"']], "\n")
            self.assertEqual(read_csv_rows(path), [{"a": "comma,value", "b": 'a "quote"'}])

    def test_new_save_marks_workspace_for_safe_deletion(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "workspace"
            save_workspace_content(root, valid_payload())
            self.assertTrue((root / WORKSPACE_MARKER).is_file())
            self.assertTrue(is_deletable_workspace(root))

    def test_packaged_defaults_and_docs_exist(self):
        self.assertGreater(len(load_default_signals()), 20)
        self.assertTrue((DOCS_DIR / "tool_usage.md").is_file())

    def test_user_docs_live_only_under_the_packaged_docs_dir(self):
        """The docs a user reads ship in the wheel, so src/plm/docs is their
        only home -- setuptools can only package files inside src/plm, and a
        second copy at the repo root just drifts. Repo-root docs/ keeps the
        ones that are not shipped (design notes, tool architecture, images).

        This replaces an older byte-for-byte drift test between the two copies
        of tool_usage.md: with one copy there is nothing to drift.
        """
        packaged = {p.name for p in DOCS_DIR.glob("*.md")}
        self.assertIn("tool_usage.md", packaged)
        self.assertIn("qt_frontend_guide.md", packaged)
        stale = packaged & {p.name for p in (ROOT / "docs").glob("*.md")}
        self.assertEqual(
            stale, set(),
            f"these docs exist in both docs/ and src/plm/docs/ and will drift: {sorted(stale)}",
        )

    def test_every_packaged_doc_is_declared_as_package_data(self):
        """`"plm" = ["docs/*.md"]` in pyproject.toml is what puts these in the
        wheel; guard the glob against someone narrowing it to one filename."""
        pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
        self.assertIn('"plm" = ["docs/*.md"]', pyproject)


class ExporterTests(unittest.TestCase):
    def setUp(self):
        # Exporter contracts should not depend on a Formatter found on this host.
        formatter = mock.patch("plm.core.verible.find_verible", return_value=None)
        formatter.start()
        self.addCleanup(formatter.stop)

    def test_parameter_check_accepts_alignment_and_rejects_wrong_widths(self):
        cfg = Config(sample_config("bifurcate"))
        plan = GenerationPlan.build(cfg, GenerationOptions(quiet=True))
        for wrong_parameter in (None, "NL", "NC"):
            with self.subTest(wrong_parameter=wrong_parameter), tempfile.TemporaryDirectory() as td:
                def format_parameters(text, *_args, **_kwargs):
                    for name, value in (("NL", plan.lane_count), ("NC", plan.num_ctrl)):
                        replacement = value * 10 if name == wrong_parameter else value
                        text = text.replace(
                            f"localparam int {name} = {value}",
                            f"localparam int {name}\t  =\n        {replacement}",
                        )
                    return text

                with mock.patch.object(exporter, "format_sv", side_effect=format_parameters):
                    if wrong_parameter is None:
                        exporter.export_all(plan, Path(td) / "rtl")
                    else:
                        with self.assertRaisesRegex(ValidationError, "top-level port/width check failed"):
                            exporter.export_all(plan, Path(td) / "rtl")

    def test_generated_outputs_have_no_dft_clock_bypass(self):
        config_dir = sample_config("bifurcate")
        with tempfile.TemporaryDirectory() as td:
            workspace = Path(td)
            generate(
                config_dir,
                workspace / "rtl",
                GenerationOptions(quiet=True),
            )
            generated_text = "\n".join(
                path.read_text(encoding="utf-8")
                for output in ("rtl", "tb")
                for path in (workspace / output).rglob("*.sv")
            )
            self.assertNotIn("test_en", generated_text)
            self.assertNotIn("DFT", generated_text)

    def test_generation_is_noop_only_for_a_verified_current_output_set(self):
        config_dir = sample_config("bifurcate")
        options = GenerationOptions(quiet=True)
        with tempfile.TemporaryDirectory() as td:
            workspace = Path(td)
            first = generate(config_dir, workspace / "rtl", options)
            before = {
                path.relative_to(workspace): (path.stat().st_mtime_ns, path.read_bytes())
                for path in workspace.rglob("*") if path.is_file()
            }
            phases = []
            second = generate(
                config_dir, workspace / "rtl", options, progress=phases.append
            )
            after = {
                path.relative_to(workspace): (path.stat().st_mtime_ns, path.read_bytes())
                for path in workspace.rglob("*") if path.is_file()
            }

            self.assertTrue(first.generated)
            self.assertFalse(second.generated)
            self.assertEqual(phases, ["VALIDATING", "UP_TO_DATE"])
            self.assertEqual(before, after)

            generated = workspace / "rtl" / "src" / "pipe_lane_mapper.sv"
            generated.write_text(generated.read_text() + "// changed\n")
            repaired = generate(config_dir, workspace / "rtl", options)
            self.assertTrue(repaired.generated)

            changed_options = generate(
                config_dir,
                workspace / "rtl",
                GenerationOptions(dpr=True, quiet=True),
            )
            self.assertTrue(changed_options.generated)
            self.assertNotEqual(
                repaired.plan.generation_key,
                changed_options.plan.generation_key,
            )

    @mock.patch("plm.core.verible.find_verible", return_value=None)
    def test_generation_stages_inside_the_workspace(self, _formatter):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            root = parent / "workspace"
            save_workspace_content(root, valid_payload())
            staged = []
            real_commit = exporter._commit_output_set

            def spy(staging, workspace):
                staged.append(Path(staging))
                return real_commit(staging, workspace)

            with mock.patch.object(exporter, "_commit_output_set", side_effect=spy), \
                    mock.patch("builtins.print"):
                generate(root / "config", root / "rtl", GenerationOptions(quiet=True))
            self.assertEqual(staged[0].parent, root)
            self.assertEqual([path.name for path in parent.iterdir()], ["workspace"])
            self.assertEqual(
                sorted(path.name for path in root.iterdir()),
                sorted([LOCK_FILENAME, WORKSPACE_MARKER, "config", "rtl", "tb"]),
            )

    @mock.patch("plm.core.verible.find_verible", return_value=None)
    def test_all_direct_topology_drives_the_synchronized_select(self, _formatter):
        from plm.core.generator import rtl
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            save_workspace_content(root, valid_payload())
            plan = load_generation_plan(root / "config", GenerationOptions())
        self.assertIn("assign sel_tgt = '0;", rtl.gen_sel_gen(plan))
        self.assertNotIn("assign sel_tgt", rtl.gen_sel_gen(plan, dpr=True))
        muxed = load_generation_plan(sample_config("bifurcate"), GenerationOptions())
        self.assertNotIn("assign sel_tgt", rtl.gen_sel_gen(muxed))

    def test_mode_switch_contract_is_checked_in_the_testbench_not_the_rtl(self):
        from plm.core.generator import rtl, tb
        config = Config(sample_config("bifurcate"))
        for source in (rtl.gen_top(config, sel_mode="comb"), rtl.gen_sel_gen(config, "comb")):
            for simulation_only in ("$error", "assert", "`ifndef SYNTHESIS", "initial "):
                self.assertNotIn(simulation_only, source)

        live = tb.gen_tb(config, dpr=True)
        held = tb.gen_tb(config)
        self.assertIn("        mode = 1; #SETTLE;", live)
        self.assertNotIn("in reset across the switch", live)
        self.assertNotIn("mode_prev", live)
        self.assertIn("between controllers that are not both in reset", held)
        # G2 (lane8~11) goes CtrlX16 -> CtrlX8 between mode 0 and mode 1.
        self.assertIn("// mode 0 -> 1: hold CtrlX16, ", held)
        switch = held[held.index("// mode 0 -> 1: hold"):].splitlines()[1:4]
        self.assertEqual([line.strip() for line in switch], [
            "ctrl_rst_n = ~4'b0011; #SETTLE;",
            "mode = 1; #SETTLE;",
            "ctrl_rst_n = '1; #SETTLE;",
        ])

    def test_failed_generation_preserves_previous_output_set(self):
        cfg = Config(sample_config("bifurcate"))
        plan = GenerationPlan.build(cfg, GenerationOptions(quiet=True))
        with tempfile.TemporaryDirectory() as td:
            workspace = Path(td)
            rtl_sentinel = workspace / "rtl" / "known-good.txt"
            tb_sentinel = workspace / "tb" / "known-good.txt"
            rtl_sentinel.parent.mkdir()
            tb_sentinel.parent.mkdir()
            rtl_sentinel.write_text("old rtl", encoding="utf-8")
            tb_sentinel.write_text("old tb", encoding="utf-8")
            with mock.patch.object(
                exporter.tb, "gen_tb", side_effect=RuntimeError("injected")
            ):
                with self.assertRaises(RuntimeError):
                    exporter.export_all(plan, workspace / "rtl")
            self.assertEqual(rtl_sentinel.read_text(encoding="utf-8"), "old rtl")
            self.assertEqual(tb_sentinel.read_text(encoding="utf-8"), "old tb")

    def test_manifests_prove_rtl_and_tb_are_one_generation(self):
        cfg = Config(sample_config("bifurcate"))
        options = GenerationOptions(quiet=True)
        plan = GenerationPlan.build(cfg, options)
        with tempfile.TemporaryDirectory() as td:
            workspace = Path(td)
            exporter.export_all(plan, workspace / "rtl")
            rtl = json.loads((workspace / "rtl" / "manifest.json").read_text())
            tb = json.loads((workspace / "tb" / "manifest.json").read_text())
            for field in (
                "generation_key",
                "config_hash",
                "generator_fingerprint",
                "options",
                "design",
            ):
                self.assertEqual(rtl[field], tb[field])
            self.assertEqual(rtl["generation_key"], plan.generation_key)
            self.assertEqual(rtl["schema_version"], MANIFEST_SCHEMA_VERSION)
            self.assertIn("src/pipe_lane_mapper.sv", rtl["files"])
            self.assertIn("tb_pipe_lane_mapper.sv", tb["files"])

    def test_failed_post_generation_self_check_preserves_previous_outputs(self):
        cfg = Config(sample_config("bifurcate"))
        plan = GenerationPlan.build(cfg, GenerationOptions(quiet=True))
        with tempfile.TemporaryDirectory() as td:
            workspace = Path(td)
            old_rtl = workspace / "rtl" / "old.txt"
            old_tb = workspace / "tb" / "old.txt"
            old_rtl.parent.mkdir()
            old_tb.parent.mkdir()
            old_rtl.write_text("rtl", encoding="utf-8")
            old_tb.write_text("tb", encoding="utf-8")
            with mock.patch.object(
                exporter,
                "_self_check_output_set",
                side_effect=ValidationError([]),
            ):
                with self.assertRaises(ValidationError):
                    exporter.export_all(plan, workspace / "rtl")
            self.assertEqual(old_rtl.read_text(encoding="utf-8"), "rtl")
            self.assertEqual(old_tb.read_text(encoding="utf-8"), "tb")

    def test_corrupt_manifests_are_stale_and_repaired(self):
        config_dir = sample_config("bifurcate")
        options = GenerationOptions(quiet=True)
        corruptions = (
            [],
            {"schema_version": 2, "files": []},
            None,
        )
        with tempfile.TemporaryDirectory() as td:
            workspace = Path(td)
            result = generate(config_dir, workspace / "rtl", options)
            for index, corruption in enumerate(corruptions):
                manifest_path = workspace / "rtl" / "manifest.json"
                if corruption is None:
                    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                    manifest["files"]["../outside.sv"] = "0" * 64
                    corruption = manifest
                manifest_path.write_text(json.dumps(corruption), encoding="utf-8")

                self.assertFalse(
                    exporter.output_set_matches_plan(
                        result.plan, workspace, verify_files=True
                    ),
                    f"corruption {index} was accepted",
                )
                repaired = generate(config_dir, workspace / "rtl", options)
                self.assertTrue(repaired.generated)
                self.assertTrue(
                    exporter.output_set_matches_plan(
                        repaired.plan, workspace, verify_files=True
                    )
                )


class GenerationPlanTests(unittest.TestCase):
    def test_each_signal_direction_is_required_before_outputs_are_replaced(self):
        for direction in ("mac2phy", "phy2mac"):
            with self.subTest(direction=direction), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                payload = valid_payload()
                payload["signals"] = [s for s in payload["signals"] if s["direction"] == direction]
                save_workspace_content(root, payload)
                for folder in ("rtl", "tb"):
                    (root / folder).mkdir()
                    (root / folder / "previous.txt").write_text(folder, encoding="utf-8")
                missing = "phy2mac" if direction == "mac2phy" else "mac2phy"
                with self.assertRaisesRegex(ValidationError, f"direction {missing} requires at least one signal"):
                    generate(root / "config", root / "rtl", GenerationOptions())
                for folder in ("rtl", "tb"):
                    self.assertEqual((root / folder / "previous.txt").read_text(), folder)

    def test_systemverilog_keywords_are_rejected_with_signal_coordinates(self):
        for name in ("byte", "shortint", "longint", "rand", "sequence", "modport", "checker", "nettype"):
            with self.subTest(name=name):
                payload = valid_payload()
                payload["signals"][0]["signal_name"] = name
                with self.assertRaises(ValidationError) as caught:
                    load_generation_plan_from_payload(payload, GenerationOptions())
                issue = caught.exception.issues[0]
                self.assertIn("not a legal SystemVerilog identifier", issue.message)
                self.assertEqual((issue.table, issue.row, issue.column), ("signals", 0, "signal_name"))
        payload = valid_payload()
        payload["signals"][0]["signal_name"] = "Byte"
        self.assertEqual(load_generation_plan_from_payload(payload, GenerationOptions()).signals[0].name, "Byte")

    def test_generated_port_and_net_collisions_are_rejected(self):
        for pclk_mode in ("pclk_as_phy_output", "pclk_as_phy_input"):
            for dpr in (False, True):
                options = GenerationOptions(
                    arch="serdes" if pclk_mode == "pclk_as_phy_input" else "original_pipe",
                    pclk_mode=pclk_mode, dpr=dpr,
                )
                cases = [("controllers", "ctrl_name", name) for name in ("PHY", "CTRL")]
                cases += [("signals", "signal_name", name) for name in ("pclk", "rst_n")]
                if dpr:
                    cases.append(("controllers", "ctrl_name", "DPR"))
                if pclk_mode == "pclk_as_phy_input":
                    cases.append(("signals", "signal_name", "rx_clk"))
                else:
                    cases.append(("signals", "signal_name", "pclk_out"))
                for table, column, name in cases:
                    with self.subTest(pclk_mode=pclk_mode, dpr=dpr, name=name):
                        payload = valid_payload()
                        payload[table][0][column] = name
                        with self.assertRaises(ValidationError) as caught:
                            load_generation_plan_from_payload(payload, options)
                        self.assertTrue(any(
                            "collides" in issue.message and (issue.table, issue.row, issue.column) == (table, 0, column)
                            for issue in caught.exception.issues
                        ))
                        with tempfile.TemporaryDirectory() as td:
                            save_workspace_content(td, payload)
                            config = Config(Path(td) / "config")
                            with self.assertRaisesRegex(ValueError, "collides"):
                                GenerationPlan.build(config, options)

    def test_flattened_names_are_checked_across_controller_prefixes(self):
        payload = valid_payload()
        payload["controllers"] = [
            {"ctrl_id": "0", "ctrl_name": "A", "max_width": "1"},
            {"ctrl_id": "1", "ctrl_name": "A_B", "max_width": "1"},
        ]
        payload["mapping"]["rows"][0]["lane1"] = "1-0"
        payload["signals"][0]["signal_name"] = "b_c"
        payload["signals"][1]["signal_name"] = "c"
        with self.assertRaisesRegex(ValidationError, "generated identifier 'a_b_c'"):
            load_generation_plan_from_payload(payload, GenerationOptions())

    def test_names_are_checked_for_the_selected_architecture_and_dpr(self):
        payload = valid_payload()
        payload["controllers"][0]["ctrl_name"] = "DPR"
        load_generation_plan_from_payload(payload, GenerationOptions(dpr=False))
        payload = valid_payload()
        payload["signals"][0]["signal_name"] = "pclk_out"
        load_generation_plan_from_payload(payload, GenerationOptions(
            arch="serdes", pclk_mode="pclk_as_phy_input",
        ))
        with tempfile.TemporaryDirectory() as td:
            save_workspace_content(td, payload)
            validation.load_validated_config(Path(td) / "config")
            payload["signals"][0]["signal_name"] = "pclk"
            save_workspace_content(td, payload)
            with self.assertRaisesRegex(ValidationError, "collides"):
                validation.load_validated_config(Path(td) / "config")

    @mock.patch("plm.core.verible.find_verible", return_value=None)
    def test_select_mode_follows_dpr_through_every_module(self, _formatter):
        for pclk_mode in ("pclk_as_phy_output", "pclk_as_phy_input"):
            for dpr in (False, True):
                with self.subTest(pclk_mode=pclk_mode, dpr=dpr), tempfile.TemporaryDirectory() as td:
                    root = Path(td)
                    options = GenerationOptions(
                        arch="serdes" if pclk_mode == "pclk_as_phy_input" else "original_pipe",
                        pclk_mode=pclk_mode, dpr=dpr, quiet=True,
                    )
                    self.assertEqual(options.sel_mode, "sync" if dpr else "comb")
                    generate(sample_config("bifurcate"), root / "rtl", options)
                    default = "1'b1" if dpr else "1'b0"
                    # Fixed at the two instantiable levels, passed down below them.
                    for module, kind in (
                        ("pipe_lane_mapper", "localparam"),
                        ("pipe_lane_mapper_connection", "localparam"),
                        ("pipe_lane_sel_gen", "parameter"),
                    ):
                        text = (root / "rtl/src" / f"{module}.sv").read_text(encoding="utf-8")
                        self.assertIn(f"{kind} bit SEL_SYNC = {default}", text)
                    for module in ("pipe_lane_mapper", "pipe_lane_mapper_connection"):
                        text = (root / "rtl/src" / f"{module}.sv").read_text(encoding="utf-8")
                        header = text[text.index(f"module {module} #("):]
                        header = header[:header.index(") (")]
                        self.assertNotRegex(header, r"\bparameter\b")
                    wrapper = (root / "rtl/src/pipe_lane_mapper_connection.sv").read_text(encoding="utf-8")
                    self.assertIn("pipe_lane_mapper u_pipe_lane_mapper (", wrapper)
                    bench = (root / "tb/tb_pipe_lane_mapper.sv").read_text(encoding="utf-8")
                    self.assertIn("pipe_lane_mapper dut (", bench)

    def test_editor_payload_validation_matches_saved_config(self):
        payload = valid_payload()
        memory_plan = load_generation_plan_from_payload(payload, GenerationOptions())
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            save_workspace_content(root, payload)
            disk_plan = load_generation_plan(root / "config", GenerationOptions())

        self.assertEqual(memory_plan.config_hash, disk_plan.config_hash)
        self.assertEqual(memory_plan.generation_key, disk_plan.generation_key)

    def test_editor_payload_duplicate_errors_keep_both_row_coordinates(self):
        payload = valid_payload()
        payload["controllers"].append({
            "ctrl_id": "0", "ctrl_name": "CtrlB", "max_width": "2",
        })
        with self.assertRaises(ValidationError) as caught:
            load_generation_plan_from_payload(payload, GenerationOptions())
        self.assertEqual(
            [(issue.table, issue.row, issue.column) for issue in caught.exception.issues],
            [("controllers", 0, "ctrl_id"), ("controllers", 1, "ctrl_id")],
        )

    def test_config_snapshot_drives_both_parsing_and_hash(self):
        source = sample_config("bifurcate")
        with tempfile.TemporaryDirectory() as td:
            config_dir = Path(td)
            for path in source.iterdir():
                if path.is_file():
                    shutil.copy2(path, config_dir / path.name)
            baseline = load_generation_plan(config_dir, GenerationOptions())
            original_loader = validation._load_validated_config

            def mutate_after_parse(directory, files):
                config = original_loader(directory, files)
                (Path(directory) / "controllers.csv").write_text(
                    "ctrl_id,ctrl_name,max_width\n0,Changed,1\n",
                    encoding="utf-8",
                )
                return config

            with mock.patch.object(
                validation,
                "_load_validated_config",
                side_effect=mutate_after_parse,
            ):
                snapshotted = load_generation_plan(config_dir, GenerationOptions())

        self.assertEqual(snapshotted.config_hash, baseline.config_hash)
        self.assertEqual(snapshotted.controllers[0].name, baseline.controllers[0].name)

    def test_formatter_binary_and_flags_change_generation_key(self):
        cfg = Config(sample_config("bifurcate"))
        with tempfile.TemporaryDirectory() as td:
            formatter = Path(td) / "verible-verilog-format"
            formatter.write_bytes(b"formatter-v1")
            first = GenerationPlan.build(
                cfg,
                GenerationOptions(
                    verible_path=str(formatter),
                    verible_flags={"column_limit": "100"},
                ),
            )
            changed_flags = GenerationPlan.build(
                cfg,
                GenerationOptions(
                    verible_path=str(formatter),
                    verible_flags={"column_limit": "120"},
                ),
            )
            formatter.write_bytes(b"formatter-v2")
            changed_binary = GenerationPlan.build(
                cfg,
                GenerationOptions(
                    verible_path=str(formatter),
                    verible_flags={"column_limit": "100"},
                ),
            )

        self.assertNotEqual(first.generation_key, changed_flags.generation_key)
        self.assertNotEqual(first.generation_key, changed_binary.generation_key)
        self.assertRegex(first.formatter["binary_sha256"], r"^[0-9a-f]{64}$")

    def test_format_issues_include_editor_coordinates(self):
        payload = valid_payload()
        payload["controllers"].append({
            "ctrl_id": "0", "ctrl_name": "CtrlB", "max_width": "2",
        })
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            save_workspace_content(root, payload)
            with self.assertRaises(ValidationError) as caught:
                load_generation_plan(root / "config", GenerationOptions())

        issues = caught.exception.issues
        self.assertEqual(
            [(issue.table, issue.row, issue.column) for issue in issues],
            [("controllers", 0, "ctrl_id"), ("controllers", 1, "ctrl_id")],
        )

    def test_related_signal_cells_share_one_validation_diagnostic(self):
        payload = valid_payload()
        payload["signals"][0].update({
            "signal_type": "shared", "direction": "phy2mac",
        })
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            save_workspace_content(root, payload)
            with self.assertRaises(ValidationError) as caught:
                load_generation_plan(root / "config", GenerationOptions())

        issues = caught.exception.issues
        self.assertEqual(
            {(issue.table, issue.row, issue.column) for issue in issues},
            {
                ("signals", 0, "signal_type"),
                ("signals", 0, "direction"),
            },
        )

    def test_plan_caches_topology_and_changes_key_with_options(self):
        cfg = Config(sample_config("bifurcate"))
        first = GenerationPlan.build(cfg, GenerationOptions())
        second = GenerationPlan.build(
            cfg,
            GenerationOptions(arch="serdes", pclk_mode="pclk_as_phy_input"),
        )
        self.assertIs(first.ctrl_pclk_src(), first.pclk_sources)
        self.assertIs(first.ctrl_pclk_cands(), first.pclk_candidates)
        self.assertNotEqual(first.generation_key, second.generation_key)
        self.assertRegex(first.generator_fingerprint, r"^[0-9a-f]{64}$")

    def test_generator_fingerprint_changes_the_generation_key(self):
        cfg = Config(sample_config("bifurcate"))
        with mock.patch(
            "plm.core.plan._generator_fingerprint",
            side_effect=("1" * 64, "2" * 64),
        ):
            first = GenerationPlan.build(cfg, GenerationOptions())
            second = GenerationPlan.build(cfg, GenerationOptions())
        self.assertNotEqual(first.generator_fingerprint, second.generator_fingerprint)
        self.assertNotEqual(first.generation_key, second.generation_key)

    def test_config_hash_is_independent_of_checkout_line_endings(self):
        source = sample_config("bifurcate")
        baseline = GenerationPlan.build(Config(source), GenerationOptions())
        with tempfile.TemporaryDirectory() as td:
            config_dir = Path(td)
            for name in ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv"):
                content = (source / name).read_bytes().replace(b"\r\n", b"\n")
                (config_dir / name).write_bytes(content.replace(b"\n", b"\r\n"))
            windows_style = GenerationPlan.build(
                Config(config_dir), GenerationOptions()
            )
        self.assertEqual(baseline.config_hash, windows_style.config_hash)
        self.assertEqual(baseline.generation_key, windows_style.generation_key)

    def test_validation_layers_distinguish_format_topology_and_options(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaises(ValidationError) as caught:
                load_generation_plan(Path(td), GenerationOptions())
            self.assertEqual(caught.exception.issues[0].layer, "format")

        with self.assertRaises(ValidationError) as caught:
            load_generation_plan(
                sample_config("quad"), GenerationOptions()
            )
        self.assertTrue(
            all(issue.layer == "topology" for issue in caught.exception.issues)
        )

        with self.assertRaises(ValidationError) as caught:
            load_generation_plan(
                sample_config("bifurcate"),
                GenerationOptions(arch="serdes"),
            )
        self.assertEqual(caught.exception.issues[0].layer, "generation")


if __name__ == "__main__":
    unittest.main()
