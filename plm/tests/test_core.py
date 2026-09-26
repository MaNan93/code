from pathlib import Path
import json
import shutil
import tempfile
import unittest
from unittest import mock

from plm.core import exporter
from plm.core.gen_flags import GenerationOptions
from plm.core.model import Config
from plm.core.plan import GenerationPlan
from plm.core.service import generate
from plm.core.paths import DOCS_DIR, WORKSPACE_MARKER, is_deletable_workspace
from plm.core.workspace import (
    read_gen_flags,
    load_default_signals,
    read_csv_rows,
    save_workspace_content,
    write_aligned_csv,
)
from plm.core.validation import ValidationError, load_generation_plan
from plm.core import validation


ROOT = Path(__file__).resolve().parents[1]


def valid_payload():
    return {
        "controllers": [{"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "2"}],
        "signals": [{
            "signal_name": "mac_phy_txdata", "signal_type": "perlane",
            "direction": "mac2phy", "width": "8", "safe_state": "0", "tie_off": "0",
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
    def test_generation_is_noop_only_for_a_verified_current_output_set(self):
        config_dir = ROOT / "test" / "bifurcate" / "config"
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
        cfg = Config(ROOT / "test" / "bifurcate" / "config")
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
        cfg = Config(ROOT / "test" / "bifurcate" / "config")
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
            self.assertIn("src/pipe_lane_mapper.sv", rtl["files"])
            self.assertIn("tb_pipe_lane_mapper.sv", tb["files"])

    def test_failed_post_generation_self_check_preserves_previous_outputs(self):
        cfg = Config(ROOT / "test" / "bifurcate" / "config")
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
        config_dir = ROOT / "test" / "bifurcate" / "config"
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
    def test_config_snapshot_drives_both_parsing_and_hash(self):
        source = ROOT / "test" / "bifurcate" / "config"
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
        cfg = Config(ROOT / "test" / "bifurcate" / "config")
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
        cfg = Config(ROOT / "test" / "bifurcate" / "config")
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
        cfg = Config(ROOT / "test" / "bifurcate" / "config")
        with mock.patch(
            "plm.core.plan._generator_fingerprint",
            side_effect=("1" * 64, "2" * 64),
        ):
            first = GenerationPlan.build(cfg, GenerationOptions())
            second = GenerationPlan.build(cfg, GenerationOptions())
        self.assertNotEqual(first.generator_fingerprint, second.generator_fingerprint)
        self.assertNotEqual(first.generation_key, second.generation_key)

    def test_config_hash_is_independent_of_checkout_line_endings(self):
        source = ROOT / "test" / "bifurcate" / "config"
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
                ROOT / "test" / "quad" / "config", GenerationOptions()
            )
        self.assertTrue(
            all(issue.layer == "topology" for issue in caught.exception.issues)
        )

        with self.assertRaises(ValidationError) as caught:
            load_generation_plan(
                ROOT / "test" / "bifurcate" / "config",
                GenerationOptions(dpr=True, sel_mode="comb"),
            )
        self.assertEqual(caught.exception.issues[0].layer, "generation")


# Non-default generation flags each bundled sample is meant to be generated
# with. The CLI takes these as command-line arguments only, so the same fact is
# written down in three places for three different consumers:
#   - here, for this regression
#   - SETFLAGS_<SET> in the top-level Makefile, for `make <SET>`
#   - test/<SET>/config/gen_flags.txt, which only the Qt front end reads
# test_sample_gen_flags_match_the_qt_workspace_files below pins the third
# against this one so they cannot drift; the Makefile copy is checked by eye.
# Add an entry here whenever a new sample needs a non-default flag, or that
# sample silently gets generated with the defaults and stops covering whatever
# it exists to demonstrate.
SAMPLE_GEN_FLAGS = {
    "maxpclk": {"pclk_mode": "pclk_as_phy_input"},
    "dpr": {"dpr": True},
}

# Deliberately invalid configurations used to prove that topology validation
# rejects unsafe mappings.  They are regression fixtures, not generation
# samples, so the positive generation sweep below must not try to export them.
NEGATIVE_SAMPLES = {
    "quad": (
        "driving sources span multiple lane groups",
        "working clock comes from different lanes",
    ),
}


def sample_gen_kwargs(sample_name):
    """export_all kwargs for one bundled sample."""
    return dict(SAMPLE_GEN_FLAGS.get(sample_name, {}))


class SampleRegressionTests(unittest.TestCase):
    def test_mode_transitions_only_affect_groups_whose_owner_changes(self):
        """A global mode update must not widen into a global lane interruption."""
        for source in sorted((ROOT / "test").iterdir()):
            if not (source / "config").is_dir() or source.name in NEGATIVE_SAMPLES:
                continue
            cfg = Config(source / "config")
            with self.subTest(sample=source.name):
                for old_mode in cfg.modes:
                    for new_mode in cfg.modes:
                        if old_mode == new_mode:
                            continue
                        changed_lanes = {
                            lane
                            for lane in range(cfg.lane_count)
                            if cfg.mapping[old_mode][lane][0]
                            != cfg.mapping[new_mode][lane][0]
                        }
                        grouped_changed_lanes = {
                            lane
                            for group in cfg.groups
                            if group.owners[old_mode] != group.owners[new_mode]
                            for lane in group.lanes
                        }
                        self.assertEqual(
                            grouped_changed_lanes,
                            changed_lanes,
                            f"mode {old_mode}->{new_mode} disturbs an unchanged lane",
                        )

    def test_all_bundled_samples_validate_and_generate(self):
        for source in sorted((ROOT / "test").iterdir()):
            if not (source / "config").is_dir():
                continue
            if source.name in NEGATIVE_SAMPLES:
                continue
            with self.subTest(sample=source.name), tempfile.TemporaryDirectory() as td:
                copied = Path(td) / source.name
                shutil.copytree(source / "config", copied / "config")
                cfg = Config(copied / "config")
                self.assertEqual(cfg.validate(), [])
                kwargs = sample_gen_kwargs(source.name)
                pclk_mode = kwargs.get("pclk_mode", "pclk_as_phy_output")
                options = GenerationOptions(
                    arch="serdes" if pclk_mode == "pclk_as_phy_input" else "original_pipe",
                    quiet=True,
                    **kwargs,
                )
                exporter.export_all(
                    GenerationPlan.build(cfg, options),
                    copied / "rtl",
                )
                self.assertTrue((copied / "rtl" / "flist.f").is_file())
                self.assertTrue((copied / "tb" / "tb_pipe_lane_mapper.sv").is_file())
                for output_name in ("rtl", "tb"):
                    expected_root = source / output_name
                    actual_root = copied / output_name
                    expected_files = {
                        path.relative_to(expected_root)
                        for path in expected_root.rglob("*")
                        if path.is_file()
                    }
                    actual_files = {
                        path.relative_to(actual_root)
                        for path in actual_root.rglob("*")
                        if path.is_file()
                    }
                    self.assertEqual(
                        actual_files,
                        expected_files,
                        f"{source.name}/{output_name} generated file list is stale",
                    )
                    for relative in sorted(expected_files):
                        self.assertEqual(
                            (actual_root / relative).read_bytes(),
                            (expected_root / relative).read_bytes(),
                            f"{source.name}/{output_name}/{relative} is stale; regenerate samples",
                        )

    def test_negative_samples_are_rejected_for_the_expected_reason(self):
        for sample_name, expected_messages in NEGATIVE_SAMPLES.items():
            with self.subTest(sample=sample_name):
                errors = Config(ROOT / "test" / sample_name / "config").validate()
                self.assertTrue(errors, f"{sample_name} unexpectedly became valid")
                joined = "\n".join(errors)
                for message in expected_messages:
                    self.assertIn(message, joined)

    def test_sample_gen_flags_match_the_qt_workspace_files(self):
        """A sample's gen_flags.txt is what the Qt front end shows when you
        open it; SAMPLE_GEN_FLAGS is what this regression generates it with.
        They describe the same intent, so they must agree -- otherwise opening
        maxpclk in the GUI and hitting Generate produces different RTL than
        `make maxpclk` does."""
        for source in sorted((ROOT / "test").iterdir()):
            if not (source / "config").is_dir():
                continue
            with self.subTest(sample=source.name):
                on_disk = read_gen_flags(source / "config" / "gen_flags.txt")
                expected = sample_gen_kwargs(source.name)
                self.assertEqual(
                    on_disk["pclk-mode"] or "pclk_as_phy_output",
                    expected.get("pclk_mode", "pclk_as_phy_output"),
                )
                self.assertEqual(on_disk["dpr"], expected.get("dpr", False))

    def test_samples_exercise_both_clock_architectures_and_dpr(self):
        """Guard against the flags silently going unused again: the two most
        intricate generator branches (gen_clk_mux_phy_input and every --dpr
        path) only have coverage while some sample actually selects them."""
        samples = {s.name for s in (ROOT / "test").iterdir() if (s / "config").is_dir()}
        seen = {"pclk_as_phy_output"}  # the default, and no sample opts out of it entirely
        for name in samples:
            kwargs = sample_gen_kwargs(name)
            seen.add(kwargs.get("pclk_mode", "pclk_as_phy_output"))
            if kwargs.get("dpr"):
                seen.add("dpr")
        self.assertIn("pclk_as_phy_input", seen)
        self.assertIn("dpr", seen)
        self.assertLessEqual(
            set(SAMPLE_GEN_FLAGS), samples,
            "SAMPLE_GEN_FLAGS names a sample that no longer exists under test/",
        )


if __name__ == "__main__":
    unittest.main()
