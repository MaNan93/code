"""Regression tests for getaxiinfo macro interpretation."""
import contextlib
import io
import tempfile
import unittest
from pathlib import Path
import os
import sys

if os.environ.get("GETAXIINFO_TEST_INSTALLED") != "1":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from getaxiinfo.main import (
    _collect_macro_data,
    _print_cli_output,
    build_analysis,
    parse_defines,
    parse_numeric_value,
)


def section(analysis, name):
    return next(item for item in analysis["sections"] if item[0] == name)


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
                "`define AMBA_INTERFACE 4\n"
                "`define MASTER_POPULATED 1\n"
                "`define CC_MAX_MSTR_TAGS_AXI (`BASE * 2)\n"
                "`define CC_WR_CH_P_REQ_QUEUE_DP (4 + 4)\n"
                "`define CX_MAX_PCIE_SPEED 6\n"
                "`define CX_NL 8\n",
                encoding="utf-8",
            )
            defines = parse_defines(path)
            self.assertEqual(defines["CC_MAX_MSTR_TAGS_AXI"][0], "(`BASE * 2)")
            ordered, _, _, _ = _collect_macro_data([str(path)])
            self.assertEqual(ordered["CC_MAX_MSTR_TAGS_AXI"], "(`BASE * 2)")
            self.assertEqual(ordered["CC_WR_CH_P_REQ_QUEUE_DP"], "(4 + 4)")
            result = build_analysis(ordered)
            rows = section(result, "OUTSTANDING")[3]
            self.assertEqual(next(row[3] for row in rows if row[:2] == ("AXI DMA", "Read")), "31")
            self.assertEqual(next(row[3] for row in rows if row[:2] == ("AXI DMA", "Write")), "8")
            self.assertEqual(dict(section(result, "PCIE")[1])["Max Link Speed"], "Gen6 (64.0 GT/s)")

    def test_partial_configuration_still_has_summary(self):
        values = {"CC_MAX_MSTR_TAGS_AXI": "32", "AMBA_INTERFACE": "4", "MASTER_POPULATED": "1"}
        analysis = build_analysis(values)
        self.assertEqual(next(row[3] for row in section(analysis, "OUTSTANDING")[3] if row[:2] == ("AXI DMA", "Read")), "31")
        self.assertEqual(section(analysis, "AXI")[3][0][7], "Unknown")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            _print_cli_output(
                {"CC_MAX_MSTR_TAGS_AXI": "32", "CX_NL": None},
                {}, {}, {}, False,
            )
        self.assertIn("[AXI]", output.getvalue())
        self.assertIn("macro not found", output.getvalue())


if __name__ == "__main__":
    unittest.main()
