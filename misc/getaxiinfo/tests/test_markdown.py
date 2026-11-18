"""Markdown reports retain specification values and opt-in source details."""

import contextlib
import io
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

if os.environ.get("GETAXIINFO_TEST_INSTALLED") != "1":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from getaxiinfo.main import getaxiinfo_cli
from getaxiinfo.markdown import render_markdown

FIXTURE = Path(__file__).parent / "fixtures/src/demo_pcie_ctl_cc_constants.svh"


class MarkdownTests(unittest.TestCase):
    def cli(self, *args):
        output, error = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            status = getaxiinfo_cli(list(args))
        return status, output.getvalue(), error.getvalue()

    def test_export_tables_and_keep_terminal_output(self):
        baseline = self.cli("--file", str(FIXTURE))
        with TemporaryDirectory() as tmp:
            target = Path(tmp) / "规格" / "控制器.md"
            result = self.cli("--file", str(FIXTURE), "-o", str(target))
            self.assertEqual(result, baseline)
            report = target.read_text(encoding="utf-8")
        self.assertTrue(report.startswith("# PCIe Controller Specifications\n"))
        for name in ("PCIE", "FUNCTIONS", "AXI", "OUTSTANDING", "EMBEDDED_DMA", "IATU", "REGISTER_MAPPING", "MSIX", "CAPABILITIES"):
            self.assertIn("## " + name + "\n", report)
        self.assertIn("| Max Link Width | x8 |", report)
        self.assertIn("| PF0 | 16 |", report)
        self.assertIn("0x00010000", report)
        self.assertIn("| Read Outstanding | Write Outstanding |", report)
        self.assertIn("| AXI DMA | Enabled |", report)
        self.assertIn("| AXI Slave | Enabled |", report)
        self.assertIn("| AXI CFG | Enabled |", report)
        self.assertIn("| AXI DMA | Read | Empirical estimate | 31 |", report)
        self.assertIn("| AXI DMA | Write | Empirical estimate | 128 |", report)
        self.assertIn("| AXI Slave | Read | Empirical estimate | 64 |", report)
        self.assertIn("| AXI Slave | Write | Empirical estimate | 8 |", report)
        self.assertIn("| Basis | Project empirical formulas |", report)
        self.assertNotIn("Manager", report)
        self.assertNotIn("Subordinate", report)
        self.assertNotIn("DBI", report)
        self.assertNotIn("## SOURCE", report)
        self.assertNotIn("## MACRO_DETAILS", report)
        self.assertNotIn(str(FIXTURE), report)

    def test_debug_export_includes_sources_values_and_derivations(self):
        with TemporaryDirectory() as tmp:
            target = Path(tmp) / "debug.md"
            status, output, error = self.cli("--file", str(FIXTURE), "--debug", "--output", str(target))
            self.assertEqual((status, error), (0, ""))
            self.assertTrue(output.startswith("[SOURCE]"))
            report = target.read_text(encoding="utf-8")
        self.assertIn("## SOURCE\n", report)
        self.assertIn("## MACRO_DETAILS\n", report)
        self.assertIn("DEMO\\_CX\\_NL", report)
        self.assertIn("| Macro | Raw | Resolved | Rule | Source | Source Line |", report)
        self.assertIn("### Derived Values", report)
        self.assertIn("raw &lt;&lt; 3", report)

    def test_escape_table_cells_and_notes(self):
        analysis = {"sections": [("EXAMPLE", [("Field", "A|B\n<script>")], (), [])],
                    "notes": ["a_b * c`d"], "trace": []}
        report = render_markdown(analysis)
        self.assertIn("| Field | A&#124;B<br>&lt;script&gt; |", report)
        self.assertIn("- a\\_b \\* c\\`d", report)
        self.assertNotIn("<script>", report)

    def test_report_cannot_overwrite_constants(self):
        with TemporaryDirectory() as tmp:
            source = Path(tmp) / "constants.svh"
            original = "`define CX_NL 8\n"
            source.write_text(original, encoding="utf-8")
            status, output, error = self.cli("--file", str(source), "-o", str(source))
            self.assertEqual(status, 1)
            self.assertEqual(output, "")
            self.assertIn("must not overwrite", error)
            self.assertEqual(source.read_text(encoding="utf-8"), original)

    def test_output_error_is_reported(self):
        with TemporaryDirectory() as tmp:
            status, output, error = self.cli("--file", str(FIXTURE), "-o", tmp)
        self.assertEqual(status, 1)
        self.assertEqual(output, "")
        self.assertTrue(error)
