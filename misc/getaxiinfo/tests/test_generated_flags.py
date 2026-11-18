"""Generated boolean encodings, disabled settings and source provenance."""

import contextlib
import io
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

if os.environ.get("GETAXIINFO_TEST_INSTALLED") != "1":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from getaxiinfo.main import _collect_macro_data, getaxiinfo_cli
from getaxiinfo.macros import parse_defines
from getaxiinfo.report import build_analysis


def fields(analysis, name):
    return dict(next(item[1] for item in analysis["sections"] if item[0] == name))


class GeneratedFlagTests(unittest.TestCase):
    def collect(self, text):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "constants.svh"
            path.write_text(text, encoding="utf-8")
            return _collect_macro_data([str(path)])[0]

    def test_value_fallbacks_support_prefixes_and_preserve_source(self):
        for prefix in ("", "DEMO_"):
            with self.subTest(prefix=prefix):
                text = ("`define {p}CC_DEVICE_TYPE 2\n"
                        "// `define {p}CX_SRIOV_ENABLE\n"
                        "`define {p}CX_SRIOV_ENABLE_VALUE 0\n"
                        "`define {p}CC_DMA_ENABLE\n"
                        "`define {p}CX_DMA_PF_ENABLE\n"
                        "// `define {p}CC_LEGACY_DMA_MAP\n"
                        "`define {p}CC_LEGACY_DMA_MAP_VALUE 0\n"
                        "// `define {p}ENABLE_MEM_MAP_UNROLL_DMA_REG\n").format(p=prefix)
                values = self.collect(text)
                self.assertEqual(values["CC_DMA_ENABLE"], "1")
                self.assertEqual(values["CX_SRIOV_ENABLE"], "0")
                self.assertEqual(values["ENABLE_MEM_MAP_UNROLL_DMA_REG"], "0")
                self.assertEqual(values.actual_names["CC_LEGACY_DMA_MAP"], prefix + "CC_LEGACY_DMA_MAP_VALUE")
                analysis = build_analysis(values)
                self.assertEqual(fields(analysis, "PCIE")["SR-IOV"], "Disabled")
                self.assertEqual(fields(analysis, "EMBEDDED_DMA")["Engine"], "HDMA")
                self.assertEqual(fields(analysis, "EMBEDDED_DMA")["Legacy DMA Map"], "Disabled")

    def test_disabled_placeholders_do_not_define_preprocessor_symbols(self):
        text = ("// `define CC_DMA_ENABLE\n"
                "`ifdef CC_DMA_ENABLE\n`define CX_NL 99\n"
                "`else\n`define CX_NL 8\n`endif\n")
        values = self.collect(text)
        self.assertEqual(values["CC_DMA_ENABLE"], "0")
        self.assertEqual(values["CX_NL"], "8")

    def test_inactive_and_block_comments_do_not_disable_flags(self):
        text = ("/*\n// `define CC_DMA_ENABLE\n*/\n"
                "`ifdef MISSING\n// `define CX_SRIOV_ENABLE\n`endif\n"
                "// `define CX_NL\n")
        values = self.collect(text)
        self.assertIsNone(values["CC_DMA_ENABLE"])
        self.assertIsNone(values["CX_SRIOV_ENABLE"])
        self.assertIsNone(values["CX_NL"])

    def test_real_definition_wins_and_missing_flags_stay_unknown(self):
        values = self.collect("// `define CC_DMA_ENABLE\n`define CC_DMA_ENABLE 1\n")
        self.assertEqual(values["CC_DMA_ENABLE"], "1")
        self.assertIsNone(values["CC_LEGACY_DMA_MAP"])
        values = self.collect("`define CC_DMA_ENABLE\n`undef CC_DMA_ENABLE\n")
        self.assertIsNone(values["CC_DMA_ENABLE"])

    def test_value_fallback_beats_placeholder_and_invalid_value_stays_unknown(self):
        values = self.collect("// `define CX_SRIOV_ENABLE\n`define CX_SRIOV_ENABLE_VALUE 1\n")
        self.assertEqual(values["CX_SRIOV_ENABLE"], "1")
        values = self.collect("// `define CX_SRIOV_ENABLE\n`define CX_SRIOV_ENABLE_VALUE 1'bx\n")
        self.assertEqual(fields(build_analysis(values), "PCIE")["SR-IOV"], "Unknown")

    def test_disabled_features_ignore_residual_counts_and_mapping_defaults(self):
        values = self.collect(
            "`define CC_DEVICE_TYPE 2\n`define CX_NFUNC 1\n"
            "`define CX_NVFUNC 2\n`define CX_MAX_VF_0 2\n"
            "`define CX_SRIOV_ENABLE_VALUE 0\n"
            "`define CC_DMA_ENABLE\n`define CX_DMA_PF_ENABLE\n"
            "`define CC_LEGACY_DMA_MAP_VALUE 0\n"
            "`define CX_INTERNAL_ATU_ENABLE 1\n`define CC_UNROLL_ENABLE\n"
            "// `define ENABLE_MEM_MAP_UNROLL_DMA_REG\n"
            "// `define ENABLE_MEM_MAP_UNROLL_ATU_REG\n"
            "`define UNROLL_FUNC_NUM 0\n`define UNROLL_BAR_NUM 0\n"
            "`define UNROLL_DMA_OFFSET_BAR 0\n`define UNROLL_ATU_OFFSET_BAR 0\n"
            "`define MSIX_CAP_ENABLE 0\n`define VF_MSIX_CAP_ENABLE 0\n"
            "`define MSIX_TABLE_BIR_0 0\n`define MSIX_PBA_OFFSET_0 2\n")
        analysis = build_analysis(values)
        self.assertEqual(values["CX_NVFUNC"], "2")
        self.assertEqual(fields(analysis, "PCIE")["VF Count"], "0")
        mapping = next(item[3] for item in analysis["sections"] if item[0] == "REGISTER_MAPPING")
        self.assertEqual(mapping[:2], [("DMA", "Not mapped", "N/A", "N/A", "N/A"),
                                      ("iATU", "Not mapped", "N/A", "N/A", "N/A")])
        self.assertEqual(next(item[3] for item in analysis["sections"] if item[0] == "MSIX"), [])

    def test_debug_explains_flag_source(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "constants.svh"
            path.write_text("`define CC_DEVICE_TYPE 2\n// `define CX_SRIOV_ENABLE\n"
                            "`define CX_SRIOV_ENABLE_VALUE 0\n", encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(getaxiinfo_cli(["--file", str(path), "--debug"]), 0)
            self.assertIn("CX_SRIOV_ENABLE (CX_SRIOV_ENABLE_VALUE)", output.getvalue())
            self.assertIn("Numeric *_VALUE configuration flag", output.getvalue())
            self.assertIn(str(path.resolve()) + ":3", output.getvalue())
