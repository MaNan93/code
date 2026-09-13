from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

from plm.core import exporter
from plm.core.model import Config
from plm.core.paths import DOCS_DIR, WORKSPACE_MARKER, is_deletable_workspace
from plm.core.workspace import (
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
        "gen_flags": {},
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

    def test_packaged_tool_usage_matches_repo_copy(self):
        """docs/tool_usage.md is the copy humans browse (design_notes.md and
        the Makefile link to it); DOCS_DIR's is the one that ships in the
        wheel and backs the GUI's Doc button. setuptools can only package
        files living inside src/plm, so the two have to coexist -- this
        catches an edit landing in only one of them."""
        # Compared as text, not bytes: the repo is checked out with
        # different line endings on different platforms, and that is not
        # drift worth failing over.
        packaged = (DOCS_DIR / "tool_usage.md").read_text(encoding="utf-8").splitlines()
        repo_copy = (ROOT / "docs" / "tool_usage.md").read_text(encoding="utf-8").splitlines()
        self.assertEqual(
            packaged,
            repo_copy,
            "docs/tool_usage.md and src/plm/docs/tool_usage.md have drifted apart",
        )


class ExporterTests(unittest.TestCase):
    def test_failed_rtl_generation_preserves_previous_output(self):
        cfg = Config(ROOT / "test" / "quad" / "config")
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "rtl"
            out.mkdir()
            sentinel = out / "known-good.txt"
            sentinel.write_text("old output", encoding="utf-8")
            with mock.patch.object(exporter.rtl, "gen_pkg", side_effect=RuntimeError("injected")):
                with self.assertRaises(RuntimeError):
                    exporter.export_rtl(cfg, out, quiet=True)
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "old output")


class SampleRegressionTests(unittest.TestCase):
    def test_all_bundled_samples_validate_and_generate(self):
        for source in sorted((ROOT / "test").iterdir()):
            if not (source / "config").is_dir():
                continue
            with self.subTest(sample=source.name), tempfile.TemporaryDirectory() as td:
                copied = Path(td) / source.name
                shutil.copytree(source / "config", copied / "config")
                cfg = Config(copied / "config")
                self.assertEqual(cfg.validate(), [])
                exporter.export_rtl(cfg, copied / "rtl", quiet=True)
                exporter.export_tb(cfg, copied / "rtl", quiet=True)
                self.assertTrue((copied / "rtl" / "flist.f").is_file())
                self.assertTrue((copied / "tb" / "tb_pipe_lane_mapper.sv").is_file())


if __name__ == "__main__":
    unittest.main()
