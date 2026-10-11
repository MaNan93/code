"""Integration checks for module selection, diagnostics and interface fidelity."""

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from benchmark_pipeline import _read_full_interface_from_file
from run_no_ramgen_scenario import _build_minimal_workspace, _load_pciegen_module

pciegen = _load_pciegen_module(Path(__file__).resolve().parents[2])


class InterfaceReadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pciegen_interfaces_")
        self.addCleanup(self.temp.cleanup)
        self.rtl = _build_minimal_workspace(Path(self.temp.name))

    def compare_reads(self):
        current = (pciegen.analyze_pcie_iip_subsystem_interface(self.rtl),
                   pciegen.extract_pcie_ram_port_from_rams_file(self.rtl))
        with patch.object(pciegen, "read_interface_from_file", new=_read_full_interface_from_file):
            full = (pciegen.analyze_pcie_iip_subsystem_interface(self.rtl),
                    pciegen.extract_pcie_ram_port_from_rams_file(self.rtl))
        self.assertEqual(current, full)
        return current

    def test_ansi_parameters_and_signed_array_ram_ports(self):
        source = ("// 中文注释\nmodule pcie_iip_rams #(parameter W=8)"
                  "(input clk, input logic signed [W-1:0] din [0:3], output [W-1:0] dout); "
                  "sub u0(.a(din)); endmodule")
        (self.rtl / "examples/pcie_iip_rams.sv").write_text(source, encoding="utf-8")
        info, nets = self.compare_reads()
        self.assertEqual(info["param_names"], ["PW"])
        self.assertIn("wire signed [W-1:0] din [0:3];", nets)

    def test_nonansi_subsystem_and_ram_ports(self):
        (self.rtl / "examples/pcie_iip_subsystem.sv").write_text(
            "module sub #(parameter W=4)(a,b); input [W-1:0] a; output b; endmodule",
            encoding="utf-8")
        (self.rtl / "examples/pcie_iip_rams.sv").write_text(
            "module r(clk,a,b); input clk; input [7:0] a; output [7:0] b; endmodule",
            encoding="utf-8")
        info, nets = self.compare_reads()
        self.assertEqual(info["style"], "non-ansi")
        self.assertEqual(nets, "wire [7:0] a;\nwire [7:0] b;")

    def test_multiple_modules_prefer_filename(self):
        for filename, module_name in (("pcie_iip_subsystem.sv", "pcie_iip_subsystem"),
                                      ("pcie_iip_rams.sv", "pcie_iip_rams")):
            (self.rtl / "examples" / filename).write_text(
                f"module helper(input wrong); endmodule module {module_name}(input a); endmodule",
                encoding="utf-8")
        info, nets = self.compare_reads()
        self.assertEqual(info["module_name"], "pcie_iip_subsystem")
        self.assertEqual(nets, "wire a;")

    def test_multiple_modules_fall_back_to_first(self):
        source = "module first(input a); endmodule module other(input wrong); endmodule"
        for filename in ("pcie_iip_subsystem.sv", "pcie_iip_rams.sv"):
            (self.rtl / "examples" / filename).write_text(source, encoding="utf-8")
        info, nets = self.compare_reads()
        self.assertEqual(info["module_name"], "first")
        self.assertEqual(nets, "wire a;")

    def test_subsystem_body_syntax_error_still_warns_and_fails_analysis(self):
        (self.rtl / "examples/pcie_iip_subsystem.sv").write_text(
            "module sub(input a); assign = ; endmodule", encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            info = pciegen.analyze_pcie_iip_subsystem_interface(self.rtl)
        self.assertIsNone(info)
        self.assertIn("failed to analyze subsystem interface", output.getvalue())
        self.assertIn("Invalid Verilog syntax", output.getvalue())

    def test_unselected_ram_module_syntax_error_is_rejected(self):
        (self.rtl / "examples/pcie_iip_rams.sv").write_text(
            "module pcie_iip_rams(input a); endmodule module bad; assign = ; endmodule",
            encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Invalid Verilog syntax"):
            pciegen.extract_pcie_ram_port_from_rams_file(self.rtl)


if __name__ == "__main__":
    unittest.main()
