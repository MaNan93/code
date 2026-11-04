"""Regression tests for getaxiinfo macro interpretation."""
import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from getaxiinfo.main import (
    _collect_macro_data,
    _print_cli_output,
    build_analysis,
    parse_defines,
    parse_numeric_value,
)


class NumericExpressionTests(unittest.TestCase):
    def test_verilog_literals_and_arithmetic(self):
        self.assertEqual(parse_numeric_value("16'h01_FF"), 511)
        self.assertEqual(parse_numeric_value("8'b1010 + 2"), 12)
        self.assertEqual(parse_numeric_value("(1 << 5) + 1"), 33)
        self.assertEqual(parse_numeric_value("(-5 / 2)"), -2)

    def test_macro_expansion_and_cycle(self):
        macros = {"A": "8", "B": "(`A << 2)", "C": "`D", "D": "`C"}
        self.assertEqual(parse_numeric_value("`B + 1", macros), 33)
        self.assertIsNone(parse_numeric_value("`C", macros))
        self.assertIsNone(parse_numeric_value("`MISSING + 1", macros))
        self.assertIsNone(parse_numeric_value("8'hxF"))


class ExtractionTests(unittest.TestCase):
    def test_parenthesized_define_and_compat_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sample_cc_constants.svh"
            path.write_text(
                "`define BASE 16\n"
                "`define CC_MAX_MSTR_TAGS_AXI (`BASE * 2)\n"
                "`define CC_WR_CH_P_REQ_QUEUE_DP (4 + 4)\n"
                "`define CX_MAX_PCIE_SPEED 6\n"
                "`define CX_NL 8\n",
                encoding="utf-8",
            )
            defines = parse_defines(path)
            self.assertEqual(defines["CC_MAX_MSTR_TAGS_AXI"][0], "(`BASE * 2)")
            ordered, _, _, _ = _collect_macro_data([str(path)])
            self.assertEqual(ordered["CC_MAX_MSTR_TAGS_AXI"], "32")
            self.assertEqual(ordered["WR_CH_P_REQ_QUEUE_DP"], "8")
            result = build_analysis(ordered)
            self.assertEqual(result["axi_mstr"]["read_outstanding"], 32)
            self.assertIsNone(result["axi_mstr"]["write_outstanding"])
            self.assertEqual(result["axi_mstr"]["posted_request_queue_depth"], 8)
            self.assertEqual(result["pcie"]["total_gbps"], 512.0)

    def test_partial_configuration_still_has_summary(self):
        values = {"CC_MAX_MSTR_TAGS_AXI": "32"}
        analysis = build_analysis(values)
        self.assertEqual(analysis["axi_mstr"]["read_outstanding"], 32)
        self.assertIsNone(analysis["axi_mstr"]["bandwidth_Gbps"])
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            _print_cli_output(
                {"CC_MAX_MSTR_TAGS_AXI": "32", "CX_NL": None},
                {}, {}, {}, False,
            )
        self.assertIn("[INTERFACE_SUMMARY]", output.getvalue())
        self.assertIn("Missing macros:", output.getvalue())


if __name__ == "__main__":
    unittest.main()
