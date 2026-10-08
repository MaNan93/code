from pathlib import Path
import json
import shutil
import tempfile
import unittest
from unittest import mock

from sample_data import sample_config

from plm.core import exporter
from plm.core.gen_flags import GenerationOptions
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
                            f"parameter int {name} = {value}",
                            f"parameter int {name}\t  =\n        {replacement}",
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
                GenerationOptions(sel_mode="comb", quiet=True),
            )
            self.assertTrue(changed_options.generated)
            self.assertNotEqual(
                repaired.plan.generation_key,
                changed_options.plan.generation_key,
            )

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
    def test_connection_wrapper_preserves_the_generated_select_mode(self, _formatter):
        for pclk_mode in ("pclk_as_phy_output", "pclk_as_phy_input"):
            for sel_mode in ("sync", "comb"):
                with self.subTest(pclk_mode=pclk_mode, sel_mode=sel_mode), tempfile.TemporaryDirectory() as td:
                    root = Path(td)
                    options = GenerationOptions(
                        arch="serdes" if pclk_mode == "pclk_as_phy_input" else "original_pipe",
                        pclk_mode=pclk_mode, sel_mode=sel_mode, quiet=True,
                    )
                    generate(sample_config("bifurcate"), root / "rtl", options)
                    default = "1'b1" if sel_mode == "sync" else "1'b0"
                    for module in ("pipe_lane_mapper", "pipe_lane_mapper_connection", "pipe_lane_sel_gen"):
                        text = (root / "rtl/src" / f"{module}.sv").read_text(encoding="utf-8")
                        self.assertIn(f"parameter bit SEL_SYNC = {default}", text)
                    wrapper = (root / "rtl/src/pipe_lane_mapper_connection.sv").read_text(encoding="utf-8")
                    self.assertIn(".SEL_SYNC (SEL_SYNC)", wrapper)

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
                GenerationOptions(dpr=True, sel_mode="comb"),
            )
        self.assertEqual(caught.exception.issues[0].layer, "generation")


if __name__ == "__main__":
    unittest.main()
