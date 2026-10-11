"""Regression tests for mapping, source rewrites and compilation inputs."""

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from run_no_ramgen_scenario import _build_minimal_workspace, _load_pciegen_module

pciegen = _load_pciegen_module(Path(__file__).resolve().parents[2])
from vutils.vparser import VeribleParser


class PciegenRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pciegen_regression_")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.rtl = _build_minimal_workspace(self.root)

    def generate(self, source, rules, report=""):
        (self.rtl / "examples/pcie_iip_subsystem.sv").write_text(source, encoding="utf-8")
        (self.root / "rule.csv").write_text("name,pin,port\n" + rules, encoding="utf-8")
        (self.root / "report/IO.html").write_text(report, encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            path = pciegen.generate_pcie_ctrl_wrapper_file(self.rtl, "my", self.root / "rule.csv")
        self.assertIsNotNone(path)
        text = path.read_text(encoding="utf-8")
        data = VeribleParser().parse_string(text, {"gen_tree": False})
        self.assertFalse(data.errors, text)
        return text, pciegen.vedit.from_file(path)

    def test_input_alias_is_driven_from_exposed_port(self):
        text, editor = self.generate("module sub(input [7:0] a); endmodule", "a,a_bus,a_wrap\n")
        self.assertEqual([p["name"] for p in editor.ports], ["a_wrap"])
        self.assertIn("wire [7:0] a_bus;", text)
        self.assertIn("assign a_bus = a_wrap;", text)
        self.assertRegex(text, r"\.a\s*\(a_bus\s*\)")

    def test_output_alias_drives_exposed_port(self):
        text, _ = self.generate("module sub(output [7:0] a); endmodule", "a,a_bus,a_wrap\n")
        self.assertIn("assign a_wrap = a_bus;", text)

    def test_inout_rename_connects_bidirectional_net(self):
        text, _ = self.generate("module sub(inout [7:0] a); endmodule", "a,a_bus,a_wrap\n")
        self.assertRegex(text, r"\.a\s*\(a_wrap\s*\)")
        self.assertNotIn("assign", text)

    def test_internal_then_external_mapping_has_one_declaration(self):
        for ports, rules in (
            ("input [7:0] a, input [7:0] b", "a,bus,nc\nb,bus,bus\n"),
            ("input [7:0] b, input [7:0] a", "b,bus,bus\na,bus,nc\n"),
        ):
            with self.subTest(ports=ports):
                text, editor = self.generate(f"module sub({ports}); endmodule", rules)
                self.assertEqual([p["name"] for p in editor.ports], ["bus"])
                self.assertNotIn("wire [7:0] bus;", text)
                self.assertNotIn("logic [7:0] bus;", text)

    def test_conflicting_shared_signal_widths_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "conflicting widths"):
            self.generate("module sub(input [7:0] a, input b); endmodule", "a,bus,nc\nb,bus,bus\n")

    def test_conflicting_exposed_directions_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "conflicting directions"):
            self.generate("module sub(input a, output b); endmodule", "a,-,bus\nb,-,bus\n")

    def test_parameter_defaults_and_instance_overrides_are_preserved(self):
        text, editor = self.generate(
            "module sub #(parameter integer PW=4, Q=PW+1)(input [Q-1:0] a); endmodule", "a,-,-\n")
        self.assertEqual(editor.param_names, ["PW", "Q"])
        self.assertIn("parameter integer PW=4, Q=PW+1", text)
        self.assertIn(".PW(PW)", text)
        self.assertIn(".Q(Q)", text)
        self.assertEqual(editor.ports[0]["width"], "[Q-1:0]")

    def test_typed_parameter_name_is_not_its_type_name(self):
        text, editor = self.generate(
            "module sub #(parameter type T=int, parameter T N=4)(input [N-1:0] a); endmodule", "a,-,-\n")
        self.assertEqual(editor.param_names, ["T", "N"])
        self.assertIn(".T(T)", text)
        self.assertIn(".N(N)", text)

    def test_unresolved_macro_width_fails_instead_of_writing_invalid_rtl(self):
        with self.assertRaisesRegex(ValueError, "resolved width"):
            self.generate("module sub(input [`W-1:0] a); endmodule", "a,-,-\n")
        self.assertFalse((self.rtl / "top/pcie_ctrl_wrapper.sv").exists())

    def test_report_resolves_macro_width(self):
        _, editor = self.generate("module sub(input [`W-1:0] a); endmodule", "a,-,-\n", "<p></a>a[3:0]</p>")
        self.assertEqual(editor.ports[0]["width"], "[3:0]")

    def test_signed_array_port_is_preserved(self):
        _, editor = self.generate(
            "module sub #(parameter N=3)(input wire signed [7:0] a [0:N]); endmodule", "a,-,-\n")
        self.assertEqual(editor.ports[0]["name"], "a")
        self.assertEqual(editor.ports[0]["dimension"], "[0:N]")
        self.assertIn("signed", editor.ports[0]["type"])

    def test_invalid_rule_is_an_error(self):
        for rule in ("a,,a\n", "a,-,bad-name\n", "a,a[0],-\n"):
            with self.subTest(rule=rule), self.assertRaises(ValueError):
                self.generate("module sub(input a); endmodule", rule)

    def test_ram_wire_ports_convert_to_valid_internal_nets(self):
        path = self.rtl / "examples/pcie_iip_rams.sv"
        path.write_text("module r(clk, din, dout);\ninput clk;\ninput wire [7:0] din;\noutput wire [7:0] dout;\nendmodule")
        decls = pciegen.extract_pcie_ram_port_from_rams_file(self.rtl)
        self.assertEqual(pciegen.extract_signal_names_from_pcie_ram_port(decls), ["din", "dout"])
        self.assertNotIn("wire wire", decls)
        self.assertNotIn("clk", decls)
        self.assertFalse(VeribleParser().parse_string(f"module m;\n{decls}\nendmodule", {"gen_tree": False}).errors)

    def test_ram_ansi_multiline_and_array_declarations(self):
        path = self.rtl / "examples/pcie_iip_rams.sv"
        path.write_text("module r(\ninput clk,\ninput logic signed [7:0]\n din [0:3],\noutput logic [7:0] dout\n); endmodule")
        decls = pciegen.extract_pcie_ram_port_from_rams_file(self.rtl)
        self.assertIn("wire signed [7:0] din [0:3];", decls)
        self.assertEqual(pciegen.extract_signal_names_from_pcie_ram_port(decls), ["din", "dout"])

    def test_cdm_rhs_replacement_is_real_and_idempotent(self):
        path = self.rtl / "src/Cdm/cdm_pl_reg.sv"
        pciegen.rewrite_cdm_pl_reg_file(self.rtl)
        first = path.read_text()
        self.assertIn("wire x = sys_fast_link_mode;", first)
        self.assertIn("wire y = sys_link_capable;", first)
        self.assertNotIn("write_pulse", first)
        self.assertNotIn("phy_type", first)
        pciegen.rewrite_cdm_pl_reg_file(self.rtl)
        self.assertEqual(path.read_text(), first)

    def test_cdm_multiline_rhs_and_other_register_use(self):
        path = self.rtl / "src/Cdm/cdm_pl_reg.sv"
        path.write_text("module cdm_pl_reg(input clk);\nwire x = (write_pulse &&\n pl_reg_16[7]);\nwire y = (phy_type && pl_reg_18[5:0]);\nwire z = pl_reg_16[7];\nendmodule")
        pciegen.rewrite_cdm_pl_reg_file(self.rtl)
        text = path.read_text()
        self.assertIn("wire x = sys_fast_link_mode;", text)
        self.assertIn("wire z = pl_reg_16[7];", text)

    def test_cdm_does_not_rewrite_comment_examples(self):
        path = self.rtl / "src/Cdm/cdm_pl_reg.sv"
        comment = "// wire z = (write_pulse && pl_reg_16[7]);"
        path.write_text(path.read_text().replace("endmodule", comment + "\nendmodule"))
        pciegen.rewrite_cdm_pl_reg_file(self.rtl)
        self.assertIn(comment, path.read_text())

    def test_scratch_resolves_each_real_file_suffix(self):
        scratch = self.rtl / "scratch"
        scratch.mkdir()
        for name in ("DWC_pcie_ctl_unprefix.svh", "DWC_pcie_ctl_undef.vh", "unrelated.vh"):
            (scratch / name).write_text("")
        text = pciegen.write_rtl_flist(self.rtl, True).read_text()
        self.assertIn("scratch/DWC_pcie_ctl_unprefix.svh", text)
        self.assertIn("scratch/DWC_pcie_ctl_undef.vh", text)
        for line in text.splitlines():
            if line.startswith("scratch/"):
                self.assertTrue((self.rtl / line).is_file())

    def test_missing_scratch_header_is_reported(self):
        with self.assertRaisesRegex(FileNotFoundError, "missing scratch header"):
            pciegen.write_rtl_flist(self.rtl, True)

    def test_failed_edit_does_not_modify_source(self):
        path = self.rtl / "examples/pcie_iip_subsystem.sv"
        original = path.read_text()
        with self.assertRaises(ValueError):
            pciegen._append_to_file(path, pciegen.CDM_SIGNALS, pciegen.CDM_PINS, "missing_instance")
        self.assertEqual(path.read_text(), original)

    def test_port_names_and_rules_are_case_sensitive(self):
        text, editor = self.generate("module sub(input a, output A); endmodule",
                                     "a,-,lower\nA,-,upper\n")
        self.assertEqual([p["name"] for p in editor.ports], ["lower", "upper"])
        self.assertRegex(text, r"\.a\s*\(a\s*\)")
        self.assertRegex(text, r"\.A\s*\(A\s*\)")
        self.assertIn("assign a = lower;", text)
        self.assertIn("assign upper = A;", text)

    def test_case_insensitive_rule_fallback_still_works_when_unique(self):
        _, editor = self.generate("module sub(input DATA); endmodule", "data,-,payload\n")
        self.assertEqual([p["name"] for p in editor.ports], ["payload"])

    def test_empty_port_list_still_forwards_header_parameters(self):
        text, _ = self.generate("module sub #(parameter W=8)(); endmodule", "")
        self.assertIn(".W(W)", text)

    def test_html_widths_keep_case_sensitive_port_identity(self):
        _, editor = self.generate("module sub(input [7:0] a, output [3:0] A); endmodule",
                                  "a,-,lower\nA,-,upper\n",
                                  "<p></a>a[7:0]</p><p></a>A[3:0]</p>")
        self.assertEqual([p["width"] for p in editor.ports], ["[7:0]", "[3:0]"])

    def test_lowercase_rule_does_not_match_a_second_distinct_uppercase_port(self):
        _, editor = self.generate("module sub(input a, output A); endmodule", "a,-,lower\n")
        self.assertEqual([p["name"] for p in editor.ports], ["lower", "A"])

    def test_body_append_selects_filename_module_and_handles_inline_header(self):
        path = self.rtl / "examples/pcie_iip_subsystem.sv"
        helper = "module helper(); sub u0(\n); endmodule\n"
        path.write_text(helper + "module pcie_iip_subsystem(input a); endmodule", encoding="utf-8")
        pciegen.append_text_after_first_port_close(self.rtl, "wire inserted;")
        pciegen.append_pcie_ram_inst_to_subsystem_file(self.rtl, "ram u_ram();")
        text = path.read_text(encoding="utf-8")
        self.assertTrue(text.startswith(helper))
        self.assertIn("wire inserted;", text[len(helper):])
        self.assertIn("ram u_ram();", text[len(helper):])
        self.assertFalse(VeribleParser().parse_string(text, {"gen_tree": False}).errors)

    def test_external_ram_instance_keeps_parameters_and_ignores_comments(self):
        path = self.rtl / "examples/pcie_iip_device.sv"
        path.write_text("module device; /* fake external_rams(); */\n"
                        "orig #(.W(fn(2,3))) external_rams(.a(fn(a,b))); endmodule", encoding="utf-8")
        instance = pciegen.extract_pcie_ram_inst_from_device_file(self.rtl, "my")
        self.assertIn("#(.W(fn(2,3)))", instance)
        self.assertIn("u_pcie_ram(.a(fn(a,b)))", instance)


if __name__ == "__main__":
    unittest.main()
