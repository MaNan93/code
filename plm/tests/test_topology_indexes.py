from pathlib import Path
import tempfile
import unittest
from unittest import mock

from plm.core import exporter
from plm.core.gen_flags import GenerationOptions
from plm.core.model import Config
from plm.core.plan import GenerationPlan


from sample_data import SAMPLES_DIR, sample_config


class TopologyIndexTests(unittest.TestCase):
    def make_config(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name)
        contents = {
            "controllers.csv": b"ctrl_id,ctrl_name,max_width\n0,CtrlA,1\n1,CtrlB,1\n",
            "pipe_signals.csv": (
                b"signal_name,signal_type,direction,width,safe_state,tie_off\n"
                b"txdata,perlane,mac2phy,8,0,0\n"
                b"rxdata,perlane,phy2mac,8,0,0\n"
            ),
            "lane_mapping.csv": b"mode,lane0,lane1\n0,0-0,1-0\n1,0-0,1-0\n",
        }
        for name, content in contents.items():
            (path / name).write_bytes(content)
        return Config(path)

    def assert_reference_indexes(self, config):
        indexes = config.topology_indexes()
        sources, widths = {}, {}
        for cid in config.controllers:
            sources[cid], widths[cid] = {}, {}
            for mode in config.modes:
                owned = [
                    lane for lane in range(config.lane_count)
                    if config.mapping[mode][lane][0] == cid
                ]
                sources[cid][mode] = min(owned) if owned else None
                widths[cid][mode] = len(owned)
        candidates = {
            cid: sorted({lane for lane in per.values() if lane is not None})
            for cid, per in sources.items()
        }
        minimum = {
            cid: min(width for width in per.values() if width)
            for cid, per in widths.items() if any(per.values())
        }
        self.assertEqual(indexes.pclk_sources, sources)
        self.assertEqual(indexes.pclk_candidates, candidates)
        self.assertEqual(indexes.minimum_widths, minimum)
        self.assertEqual(set(indexes.lane_groups), set(range(config.lane_count)))
        for lane, group in indexes.lane_groups.items():
            self.assertIn(lane, group.lanes)
            self.assertEqual(group.owners, {
                mode: config.mapping[mode][lane][0] for mode in config.modes
            })

    def test_index_facts_match_scan_for_all_bundled_topologies(self):
        for path in sorted(SAMPLES_DIR.glob("*/config")):
            with self.subTest(sample=path.parent.name):
                self.assert_reference_indexes(Config(path))

    def test_undefined_controller_preserves_validation_diagnostics(self):
        config = self.make_config()
        for mode in config.modes:
            config.mapping[mode][1] = (9, 0)
        self.assert_reference_indexes(config)
        self.assertEqual(config.validate(), [
            "[mode 0] lane1: undefined ctrl_id=9",
            "[mode 1] lane1: undefined ctrl_id=9",
            "CtrlB is never assigned a lane in any mode; please remove it from controllers.csv",
        ])

    def test_config_mutations_refresh_clocks_groups_and_reports(self):
        config = self.make_config()
        self.assertEqual(config.validate(), [])
        self.assertEqual(config.ctrl_pclk_cands(), {0: [0], 1: [1]})
        original_report = config.report()
        config.mapping[1] = {0: (1, 0), 1: (0, 0)}
        self.assertEqual(config.group_of_lane(0).owners, {0: 0, 1: 1})
        errors = config.validate()
        self.assertEqual(config.ctrl_pclk_src(), {0: {0: 0, 1: 1}, 1: {0: 1, 1: 0}})
        self.assertEqual(config.ctrl_pclk_cands(), {0: [0, 1], 1: [0, 1]})
        self.assertEqual(config.groups[0].owners, {0: 0, 1: 1})
        self.assertTrue(any("driving sources span multiple lane groups" in error for error in errors))
        self.assertTrue(any("working clock comes from different lanes" in error for error in errors))
        self.assertNotEqual(config.report(), original_report)
        config.mapping[1] = {0: (0, 0), 1: (1, 0)}
        self.assertEqual(config.validate(), [])
        self.assertEqual(config.report(), original_report)

    def test_standalone_results_cannot_poison_later_config_reads(self):
        config = self.make_config()
        config.ctrl_pclk_src()[0][0] = 99
        config.ctrl_pclk_cands()[0].append(99)
        self.assertEqual(config.ctrl_pclk_src()[0], {0: 0, 1: 0})
        self.assertEqual(config.ctrl_pclk_cands()[0], [0])

    def test_plan_detaches_source_and_rebuilds_after_source_edits(self):
        config = self.make_config()
        first = GenerationPlan.build(config, GenerationOptions())
        first_report = first.report()
        for mode in config.modes:
            config.mapping[mode] = {0: (1, 0), 1: (0, 0)}
        config.controllers[0].name = "EditedA"
        config.signals[0].width = 4
        self.assertEqual(config.validate(), [])
        second = GenerationPlan.build(config, GenerationOptions())
        self.assertEqual(first.report(), first_report)
        self.assertEqual(first.ctrl_pclk_cands(), {0: [0], 1: [1]})
        self.assertEqual(second.ctrl_pclk_cands(), {0: [1], 1: [0]})
        self.assertEqual(first.controllers[0].name, "CtrlA")
        self.assertEqual(second.controllers[0].name, "EditedA")
        self.assertEqual(first.signals[0].width, 8)
        self.assertEqual(second.signals[0].width, 4)
        self.assertEqual(second.report(), config.report())
        self.assertIsInstance(first.mapping, dict)
        self.assertIsInstance(first.groups, list)

    @mock.patch("plm.core.verible.find_verible", return_value=None)
    def test_rtl_tb_and_report_reuse_plan_topology(self, _formatter):
        config = Config(sample_config("bifurcate"))
        plan = GenerationPlan.build(config, GenerationOptions(quiet=True))
        expected_report = config.report()
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(
            Config, "topology_indexes", side_effect=AssertionError("topology was rescanned")
        ), mock.patch.object(
            Config, "group_of_lane", side_effect=AssertionError("lane groups were scanned")
        ):
            exporter.export_all(plan, Path(directory) / "rtl")
            self.assertEqual(plan.report(), expected_report)
            self.assertTrue((Path(directory) / "tb" / "tb_pipe_lane_mapper.sv").is_file())
            with self.assertRaises(KeyError):
                plan.group_of_lane(config.lane_count)


if __name__ == "__main__":
    unittest.main()
