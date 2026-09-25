from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

from plm.core import exporter
from plm.core.model import Config
from plm.core.paths import DOCS_DIR, WORKSPACE_MARKER, is_deletable_workspace
from plm.core.workspace import (
    read_gen_flags,
    load_default_signals,
    read_csv_rows,
    save_workspace_content,
    write_aligned_csv,
)


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
    def test_failed_generation_preserves_previous_output_set(self):
        cfg = Config(ROOT / "test" / "quad" / "config")
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
                    exporter.export_all(cfg, workspace / "rtl", quiet=True)
            self.assertEqual(rtl_sentinel.read_text(encoding="utf-8"), "old rtl")
            self.assertEqual(tb_sentinel.read_text(encoding="utf-8"), "old tb")


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
                exporter.export_all(cfg, copied / "rtl", quiet=True, **kwargs)
                self.assertTrue((copied / "rtl" / "flist.f").is_file())
                self.assertTrue((copied / "tb" / "tb_pipe_lane_mapper.sv").is_file())

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
