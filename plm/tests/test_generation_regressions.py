"""Stable RTL contracts without reading editable examples or invoking Git."""

import contextlib
import hashlib
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

from plm.core import exporter
from plm.core.gen_flags import GenerationOptions
from plm.core.model import Config
from plm.core.plan import GenerationPlan, MANIFEST_SCHEMA_VERSION
from plm.core.workspace import read_gen_flags
from sample_data import SAMPLES_DIR, sample_config


POSITIVE_SAMPLES = ("bifurcate", "dpr", "finegrain", "maxpclk")
NEGATIVE_SAMPLES = {
    "quad": ("driving sources span multiple lane groups", "working clock comes from different lanes"),
}


def fixture_options(name):
    flags = read_gen_flags(sample_config(name) / "gen_flags.txt")
    return GenerationOptions(
        arch=flags["arch"] or "original_pipe",
        pclk_mode=flags["pclk-mode"] or "pclk_as_phy_output",
        sel_mode=flags["sel-mode"] or "sync",
        dpr=flags["dpr"], quiet=True,
    )


def normalized_hash(path):
    data = path.read_text(encoding="utf-8").encode("utf-8")
    return hashlib.sha256(data).hexdigest()


class GenerationRegressionTests(unittest.TestCase):
    def test_mode_transitions_only_affect_groups_whose_owner_changes(self):
        for name in POSITIVE_SAMPLES:
            config = Config(sample_config(name))
            with self.subTest(sample=name):
                for old in config.modes:
                    for new in config.modes:
                        changed = {
                            lane for lane in range(config.lane_count)
                            if config.mapping[old][lane][0] != config.mapping[new][lane][0]
                        }
                        grouped = {
                            lane for group in config.groups
                            if group.owners[old] != group.owners[new]
                            for lane in group.lanes
                        }
                        self.assertEqual(grouped, changed)

    @mock.patch("plm.core.verible.find_verible", return_value=None)
    def test_fixed_inputs_match_reviewed_output_hashes(self, _formatter):
        for name in POSITIVE_SAMPLES:
            with self.subTest(sample=name), tempfile.TemporaryDirectory() as temporary:
                workspace = Path(temporary)
                shutil.copytree(sample_config(name), workspace / "config")
                config = Config(workspace / "config")
                self.assertEqual(config.validate(), [])
                plan = GenerationPlan.build(config, fixture_options(name))
                with contextlib.redirect_stdout(io.StringIO()):
                    exporter.export_all(plan, workspace / "rtl")
                expected = json.loads((SAMPLES_DIR / name / "expected.json").read_text(encoding="utf-8"))
                self.assertEqual(expected["schema_version"], 1)
                actual = {
                    path.relative_to(workspace).as_posix(): normalized_hash(path)
                    for kind in ("rtl", "tb")
                    for path in (workspace / kind).rglob("*")
                    if path.is_file() and path.name != "manifest.json"
                }
                self.assertEqual(actual, expected["files"], f"RTL/TB contract changed for {name}")
                # Manifest fingerprints describe this build, so validate them
                # against its plan rather than pinning unrelated source hashes.
                manifests = exporter.read_manifests(workspace)
                self.assertEqual(set(manifests), {"rtl", "tb"})
                for kind, manifest in manifests.items():
                    self.assertEqual(manifest["output"], kind)
                    self.assertEqual(manifest["schema_version"], MANIFEST_SCHEMA_VERSION)
                    for field, value in plan.manifest_base().items():
                        self.assertEqual(manifest[field], value, field)
                    for relative, digest in manifest["files"].items():
                        self.assertEqual(digest, hashlib.sha256((workspace / kind / relative).read_bytes()).hexdigest())

    def test_negative_fixture_is_rejected_for_the_expected_reason(self):
        for name, messages in NEGATIVE_SAMPLES.items():
            with self.subTest(sample=name):
                errors = Config(sample_config(name)).validate()
                self.assertTrue(errors)
                for message in messages:
                    self.assertIn(message, "\n".join(errors))

    def test_fixture_options_cover_clock_architectures_and_dpr(self):
        options = [fixture_options(name) for name in POSITIVE_SAMPLES]
        for option in options:
            option.validated()
        self.assertEqual({option.pclk_mode for option in options}, {"pclk_as_phy_input", "pclk_as_phy_output"})
        self.assertTrue(any(option.dpr for option in options))
        self.assertTrue(any(not option.dpr for option in options))

    def test_fixtures_are_complete_and_not_editable_workspaces(self):
        self.assertEqual({path.name for path in SAMPLES_DIR.iterdir() if path.is_dir()}, set(POSITIVE_SAMPLES) | set(NEGATIVE_SAMPLES))
        for name in (*POSITIVE_SAMPLES, *NEGATIVE_SAMPLES):
            for filename in ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv"):
                self.assertTrue((sample_config(name) / filename).is_file())
            self.assertFalse((SAMPLES_DIR / name / ".plm-workspace").exists())


if __name__ == "__main__":
    unittest.main()
