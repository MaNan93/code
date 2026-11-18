"""Behavior checks against synthetic controller constants and CLI output."""

import contextlib
import io
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

# Use the installed package when supplied by release validation; otherwise src/.
if os.environ.get("GETAXIINFO_TEST_INSTALLED") != "1":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from getaxiinfo import __version__
from getaxiinfo.main import (
    _collect_macro_data, discover_controller_files, extract_target_macros,
    getaxiinfo, getaxiinfo_cli,
)
from getaxiinfo.macros import NumericResolver, TARGET_MACROS, parse_defines, parse_numeric_value, resolve_target_macro_name
from getaxiinfo.report import build_analysis


FIXTURE = Path(__file__).parent / "fixtures/src/demo_pcie_ctl_cc_constants.svh"


def section(analysis, name):
    return next(item for item in analysis["sections"] if item[0] == name)


class ReportTests(unittest.TestCase):
    def values(self):
        return _collect_macro_data([str(FIXTURE)])[0]

    def cli(self, *args):
        output, error = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            status = getaxiinfo_cli(list(args))
        return status, output.getvalue(), error.getvalue()

    def test_version_and_api(self):
        self.assertEqual(__version__, "0.2.7")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            values = getaxiinfo([str(FIXTURE)], debug=True)
        self.assertEqual(output.getvalue(), "")
        self.assertEqual(values["CX_NL"], "(8)")
        self.assertEqual(values["CX_MAX_VF_1"], "16")

    def test_summary_and_debug_visibility(self):
        status, normal, error = self.cli("--file", str(FIXTURE))
        self.assertEqual((status, error), (0, ""))
        self.assertTrue(normal.startswith("[PCIE]"))
        for heading in ("FUNCTIONS", "AXI", "OUTSTANDING", "EMBEDDED_DMA", "IATU", "REGISTER_MAPPING", "MSIX", "CAPABILITIES"):
            self.assertIn("[{}]".format(heading), normal)
        self.assertNotIn("[SOURCE]", normal)
        self.assertNotIn("[MACRO_DETAILS]", normal)
        self.assertNotIn(str(FIXTURE), normal)
        status, debug, error = self.cli("--file", str(FIXTURE), "--debug")
        self.assertEqual((status, error), (0, ""))
        self.assertTrue(debug.startswith("[SOURCE]"))
        self.assertIn("[MACRO_DETAILS]", debug)
        self.assertIn("raw << 3", debug)
        self.assertIn("DEMO_CX_NL", debug)
        self.assertIn("demo_pcie_ctl_cc_constants.svh:6", debug)

    def test_basic_functions_and_msix_byte_offsets(self):
        analysis = build_analysis(self.values())
        fields = dict(section(analysis, "PCIE")[1])
        self.assertEqual(fields["Controller Type"], "DM")
        self.assertEqual(fields["Max Link Width"], "x8")
        self.assertEqual(fields["Max Link Speed"], "Gen5 (32.0 GT/s)")
        self.assertEqual(fields["VF Count"], "32")
        self.assertEqual(section(analysis, "FUNCTIONS")[3], [("PF0", "16"), ("PF1", "16")])
        rows = section(analysis, "MSIX")[3]
        self.assertEqual(rows[0], ("PF0", "Enabled", "BAR0", "0x00000000", "BAR0", "0x00010000"))
        self.assertEqual(rows[1][0:3], ("VFs under PF0", "Enabled", "BAR4"))
        self.assertEqual(len(rows), 4)

    def test_missing_optional_fields_do_not_suppress_sections(self):
        analysis = build_analysis({"CX_NL": "8", "CX_MAX_PCIE_SPEED": "5"})
        self.assertEqual(dict(section(analysis, "PCIE")[1])["Max Link Width"], "x8")
        self.assertEqual(dict(section(analysis, "EMBEDDED_DMA")[1])["Engine"], "Unknown")
        self.assertTrue(any("CC_DEVICE_TYPE: macro not found" in note for note in analysis["notes"]))
        self.assertEqual(len(analysis["sections"]), 9)

    def test_empirical_dma_outstanding_does_not_depend_on_chunking(self):
        values = dict(self.values())
        for chunk in ("0", "1", None):
            with self.subTest(chunk=chunk):
                values["CX_AXI_RCHUNK_ENABLE"] = chunk
                analysis = build_analysis(values)
                rows = section(analysis, "OUTSTANDING")[3]
                read = next(row for row in rows if row[:2] == ("AXI DMA", "Read"))
                write = next(row for row in rows if row[:2] == ("AXI DMA", "Write"))
                self.assertEqual(read[2:], ("Empirical estimate", "31", "CC_MAX_MSTR_TAGS_AXI - 1"))
                self.assertEqual(write[2:], ("Empirical estimate", "128", "CC_WR_CH_P_REQ_QUEUE_DP"))
                self.assertTrue(any("share" in note for note in analysis["notes"]))

    def test_empirical_slave_outstanding_uses_read_and_write_macros(self):
        rows = section(build_analysis(self.values()), "OUTSTANDING")[3]
        self.assertEqual(next(row for row in rows if row[:2] == ("AXI Slave", "Read"))[2:], ("Empirical estimate", "64", "CC_MAX_SLV_TAG"))
        self.assertEqual(next(row for row in rows if row[:2] == ("AXI Slave", "Write"))[2:], ("Empirical estimate", "8", "CC_SLV_NUM_OUTSTND_WR_REQ"))
        fields = dict(section(build_analysis(self.values()), "OUTSTANDING")[1])
        self.assertEqual(fields["Basis"], "Project empirical formulas")
        self.assertEqual((fields["PCIe Tag Pool"], fields["DMA Reserved Tags"], fields["Non-DMA Tags"]), ("128", "32", "96"))

    def test_dbi_is_single_not_zero_outstanding(self):
        analysis = build_analysis(self.values())
        dbi = next(row for row in section(analysis, "AXI")[3] if row[0] == "AXI CFG")
        self.assertEqual(dbi[6], "Single")
        rows = [row for row in section(analysis, "OUTSTANDING")[3] if row[0] == "AXI CFG"]
        self.assertEqual([row[3] for row in rows], ["Unknown", "Unknown"])
        self.assertEqual(dbi[-2:], ("Unknown", "Unknown"))

    def test_axi_names_and_directional_outstanding_columns(self):
        values = dict(self.values())
        values["RADM_MAX_OUTSTD_P_REQ"] = "777"
        analysis = build_analysis(values)
        _, fields, headers, rows = section(analysis, "AXI")
        self.assertEqual(headers[-2:], ("Read Outstanding", "Write Outstanding"))
        self.assertEqual([row[0] for row in rows], ["AXI DMA", "AXI Slave", "AXI CFG"])
        self.assertEqual(rows[0][-2:], ("31", "128"))
        self.assertEqual(rows[1][-2:], ("64", "8"))
        self.assertIn("AXI CFG Access", dict(fields))
        values["CX_AXI_RCHUNK_ENABLE"] = "1"
        rows = section(build_analysis(values), "AXI")[3]
        self.assertEqual(rows[0][-2:], ("31", "128"))

    def test_empirical_aliases_and_missing_or_invalid_inputs(self):
        values = dict(self.values())
        values.update(CC_WR_CH_P_REQ_QUEUE_DP=None, WR_CH_P_REQ_QUEUE_DP="64",
                      CC_SLV_NUM_OUTSTND_WR_REQ=None, CC_SLV_NUM_OUTSTND_CPU_WR_REQ="9",
                      CC_MAX_MSTR_TAGS_AXI="1")
        rows = section(build_analysis(values), "AXI")[3]
        self.assertEqual(rows[0][-2:], ("0", "64"))
        self.assertEqual(rows[1][-2:], ("64", "Unknown"))
        values.update(CC_WR_CH_P_REQ_QUEUE_DP="8'hxx", CC_MAX_MSTR_TAGS_AXI=None)
        rows = section(build_analysis(values), "AXI")[3]
        self.assertEqual(rows[0][-2:], ("Unknown", "Unknown"))

    def test_axi_dma_label_does_not_depend_on_embedded_dma(self):
        values = dict(self.values())
        values.update(CC_DMA_ENABLE="0", CX_DMA_PF_ENABLE="0", SHARED_DBI_ENABLED="1")
        analysis = build_analysis(values)
        rows = section(analysis, "AXI")[3]
        self.assertEqual(rows[0][:2], ("AXI DMA", "Enabled"))
        self.assertEqual(rows[2][-2:], ("N/A", "N/A"))
        self.assertEqual(dict(section(analysis, "AXI")[1])["AXI CFG Access"], "Shared AXI Slave")

    def test_payload_width_and_synchronous_clock(self):
        values = dict(self.values())
        values["CC_MSTR_BUS_DATA_WIDTH"] = "288"
        analysis = build_analysis(values)
        row = section(analysis, "AXI")[3][0]
        self.assertEqual((row[4], row[7]), ("256", "16.000"))
        values["MSTR_CLK_DIFF_ENABLE"] = "0"
        row = section(build_analysis(values), "AXI")[3][0]
        self.assertEqual((row[2], row[7], row[8]), ("Unknown", "Unknown", "Sync"))

    def test_dma_type_and_legacy_map(self):
        values = dict(self.values())
        for hdma, legacy, engine, map_status in ((1, 1, "HDMA", "Enabled"), (1, 0, "HDMA", "Disabled"), (0, 1, "Legacy DMA", "N/A")):
            values.update(CX_DMA_PF_ENABLE=str(hdma), CC_LEGACY_DMA_MAP=str(legacy))
            fields = dict(section(build_analysis(values), "EMBEDDED_DMA")[1])
            self.assertEqual((fields["Engine"], fields["Legacy DMA Map"]), (engine, map_status))
        values.update(CC_DMA_ENABLE="0", CX_DMA_PF_ENABLE="1")
        self.assertEqual(dict(section(build_analysis(values), "EMBEDDED_DMA")[1])["Status"], "Invalid")

    def test_bar_mapping_and_unroll_report_option(self):
        values = dict(self.values())
        rows = section(build_analysis(values), "REGISTER_MAPPING")[3]
        self.assertEqual(rows[:2], [("DMA", "Enabled", "PF0", "BAR2", "0x00000000"), ("iATU", "Enabled", "PF0", "BAR2", "0x00100000")])
        values["ENABLE_MEM_MAP_UNROLL_DMA_REG"] = "0"
        self.assertEqual(section(build_analysis(values), "REGISTER_MAPPING")[3][0], ("DMA", "Not mapped", "N/A", "N/A", "N/A"))
        values["CC_UNROLL_ENABLE"] = None
        values["CX_UNROLL_VIEW"] = "1"
        self.assertEqual(dict(section(build_analysis(values), "REGISTER_MAPPING")[1])["Unroll Space"], "Unknown")

    def test_disabled_modules_ignore_stale_fields(self):
        values = dict(self.values())
        values.update(AMBA_INTERFACE="0", CX_SRIOV_ENABLE="0", CC_DMA_ENABLE="0", CX_DMA_PF_ENABLE="0", CX_INTERNAL_ATU_ENABLE="0", MSIX_CAP_ENABLE="0")
        analysis = build_analysis(values)
        self.assertEqual(dict(section(analysis, "PCIE")[1])["VF Count"], "0")
        self.assertTrue(all(row[1] == "Disabled" for row in section(analysis, "AXI")[3]))
        self.assertTrue(all(row[-2:] == ("N/A", "N/A") for row in section(analysis, "AXI")[3]))
        self.assertEqual(dict(section(analysis, "EMBEDDED_DMA")[1])["Engine"], "N/A")
        self.assertEqual(section(analysis, "MSIX")[3], [])


class ParserTests(unittest.TestCase):
    def test_numeric_literals_and_expressions(self):
        for raw, expected in (("(8)", 8), ("32'd32", 32), ("8'shff", -1), ("4'h1f", 15), ("(1 << 8)", 256), ("0 ? 2 : 3", 3), ("$clog2(32)", 5), ("1 && !0", 1)):
            with self.subTest(raw=raw):
                self.assertEqual(parse_numeric_value(raw), expected)
        for raw in ("2'b22", "8'hxx", "`UNKNOWN", "__import__('os').getcwd()", "(8", "1 / 0"):
            self.assertIsNone(parse_numeric_value(raw))
        self.assertEqual(NumericResolver({"A": "`B + 1", "B": "31"}).number("A"), 32)
        self.assertIsNone(NumericResolver({"A": "`B", "B": "`A"}).number("A"))

    def test_comments_conditions_parentheses_and_lines(self):
        text = "/*\n`define CX_NL 99\n*/\n`define ACTIVE\n`ifdef ACTIVE\n`define CX_NL (8) /* lanes */\n`else\n`define CX_NL 16\n`endif\n`define FOO(x) x\n`define VALUE \\\n  32\n"
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "constants.svh"
            path.write_text(text, encoding="utf-8")
            values = parse_defines(path)
        self.assertEqual(values["CX_NL"][:2], ("(8)", 6))
        self.assertNotIn("FOO", values)
        self.assertEqual(values["VALUE"][0], "32")

    def test_reject_mixed_prefixes(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "constants.svh"
            path.write_text("`define A_CX_NL 8\n`define B_CC_DEVICE_TYPE 2\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Multiple controller macro prefixes"):
                extract_target_macros([path])

    def test_pf_vf_msi_names_do_not_collide_with_controller_prefix(self):
        text = FIXTURE.read_text(encoding="utf-8").replace("DEMO_", "HUIXI_G4X4_")
        text += ("\n`define HUIXI_G4X4_VF_MSI_CAP_ENABLE 0\n"
                 "`define HUIXI_G4X4_EXT_VF_MSIX_CAP_ENABLE 0\n"
                 "`define HUIXI_G4X4_OTHER_MSI_CAP_ENABLE 0\n"
                 "`define HUIXI_G4X4_OTHER_MSIX_TABLE_OFFSET_0 99\n")
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "constants.svh"
            path.write_text(text, encoding="utf-8")
            values, sources, _, _ = extract_target_macros([path])
            self.assertEqual(values["MSI_CAP_ENABLE"], "1")
            self.assertEqual(values["MSIX_CAP_ENABLE"], "1")
            self.assertEqual(values["VF_MSIX_CAP_ENABLE"], "1")
            self.assertEqual(values["MSIX_TABLE_OFFSET_0"], "29'h0")
            self.assertEqual(values.actual_names["MSI_CAP_ENABLE"], "HUIXI_G4X4_MSI_CAP_ENABLE")
            output, error = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
                self.assertEqual(getaxiinfo_cli(["--file", str(path)]), 0)
            self.assertIn("[MSIX]", output.getvalue())
            self.assertEqual(error.getvalue(), "")

    def test_msi_sibling_macros_without_controller_anchors(self):
        targets = set(TARGET_MACROS)
        for prefix in ("", "HUIXI_G4X4_"):
            self.assertEqual(resolve_target_macro_name(prefix + "MSI_CAP_ENABLE", targets), "MSI_CAP_ENABLE")
            self.assertEqual(resolve_target_macro_name(prefix + "VF_MSIX_CAP_ENABLE", targets), "VF_MSIX_CAP_ENABLE")
            for name in ("VF_MSI_CAP_ENABLE", "EXT_VF_MSI_CAP_ENABLE", "EXT_VF_MSIX_CAP_ENABLE"):
                self.assertIsNone(resolve_target_macro_name(prefix + name, targets))

    def test_real_duplicate_controller_msi_macros_still_fail(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "constants.svh"
            path.write_text("`define A_MSI_CAP_ENABLE 1\n`define B_MSI_CAP_ENABLE 0\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Ambiguous macro MSI_CAP_ENABLE"):
                extract_target_macros([path])

    def test_discovery_depth_and_multiple_candidates(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "arbitrary/deep/src/demo_pcie_ctl_cc_constants.svh.generated"
            target.parent.mkdir(parents=True)
            target.write_text("`define CX_NL 8\n", encoding="utf-8")
            decoy = root / "src/nested/pcie_ctl_cc_constants.svh"
            decoy.parent.mkdir(parents=True)
            decoy.write_text("", encoding="utf-8")
            self.assertEqual(discover_controller_files([root]), [target])
            self.assertEqual(discover_controller_files([target.parent]), [target])
            self.assertEqual(_collect_macro_data([str(root)])[0]["CX_NL"], "8")
            second = root / "another/src/pcie_ctl_cc_constants.svh"
            second.parent.mkdir(parents=True)
            second.write_text("", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Multiple matched files"):
                _collect_macro_data([str(root)])


if __name__ == "__main__":
    unittest.main()
