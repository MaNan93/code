"""Naming contracts across source declarations, simulator inputs and persistence."""

import contextlib
import io
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

from plm.cli import main as cli
from plm.core.gen_flags import GenerationOptions
from plm.core.naming import GenerationNames
from plm.core.service import generate
from plm.core.validation import ValidationError
from plm.core.workspace import read_gen_flags, save_workspace_content, write_gen_flags
from test_core import valid_payload


class GenerationPrefixTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="plm prefix ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        save_workspace_content(self.root, valid_payload())
        formatter = patch("plm.core.verible.find_verible", return_value=None)
        formatter.start()
        self.addCleanup(formatter.stop)

    def generate(self, **prefixes):
        with contextlib.redirect_stdout(io.StringIO()):
            return generate(self.root / "config", self.root / "rtl",
                            GenerationOptions(quiet=True, **prefixes))

    def outputs(self):
        return {path.relative_to(self.root).as_posix(): path.read_bytes()
                for kind in ("rtl", "tb") for path in (self.root / kind).rglob("*")
                if path.is_file()}

    def test_all_prefixes_keep_declarations_references_and_simulator_inputs_aligned(self):
        result = self.generate(module_prefix="soc", file_prefix="rtl", macro_prefix="SOC")
        self.assertTrue(result.generated)
        sources = list((self.root / "rtl").rglob("*.sv"))
        self.assertEqual(len(sources), 14)
        self.assertTrue(all(path.name.startswith("rtl_") for path in sources))
        texts = {path.name: path.read_text() for path in sources}
        declared = set()
        for source in texts.values():
            declared.update(re.findall(r"\b(?:module|package)\s+(\w+)", source))
        self.assertEqual(len(declared), 14)
        self.assertTrue(all(name.startswith("soc_") for name in declared))
        for source in texts.values():
            # Independent of the renaming helper: check actual instance types/imports.
            for reference in re.findall(r"\b(\w+)\s*#\s*\(", source):
                self.assertIn(reference, declared)
            for package in re.findall(r"\bimport\s+(\w+)::", source):
                self.assertIn(package, declared)
        self.assertIn("soc_pipe_lane_signal_pkg", declared)
        flist = (self.root / "rtl/flist.f").read_text().splitlines()
        listed = {line for line in flist if line.endswith(".sv")}
        self.assertEqual(listed, {path.relative_to(self.root / "rtl").as_posix() for path in sources})
        tb = (self.root / "tb/rtl_tb_pipe_lane_mapper.sv").read_text()
        self.assertIn("module soc_tb_pipe_lane_mapper;", tb)
        self.assertIn("soc_pipe_lane_mapper #(", tb)
        self.assertIn("$dumpvars(0, soc_tb_pipe_lane_mapper)", tb)
        self.assertIn('$fsdbDumpvars(0, soc_tb_pipe_lane_mapper, "+all")', tb)
        self.assertIn("`ifdef SOC_DUMP_FSDB", tb)
        self.assertIn("`ifdef SOC_PIPE_USE_ICG_CELL", texts["rtl_pipe_lane_clk_gate.sv"])
        self.assertIn("`SOC_PIPE_ICG_CELL u_icg", texts["rtl_pipe_lane_clk_gate.sv"])
        self.assertIn("`ifdef SOC_PIPE_USE_CLKOR_CELL", texts["rtl_pipe_lane_clk_or.sv"])
        self.assertIn("`SOC_PIPE_CLKOR_CELL u_clkor", texts["rtl_pipe_lane_clk_or.sv"])
        makefile = (self.root / "tb/makefile").read_text()
        self.assertIn("TB_FILES  = ../tb/rtl_tb_pipe_lane_mapper.sv", makefile)
        self.assertIn("+define+SOC_DUMP_FSDB", makefile)
        for manifest in result.manifests.values():
            for name, value in {"module_prefix": "soc", "file_prefix": "rtl", "macro_prefix": "SOC"}.items():
                self.assertEqual(manifest["options"][name], value)

    def test_each_prefix_is_independent_and_changes_generation_identity(self):
        original = self.generate()
        baseline = self.outputs()
        for name, value in (("module_prefix", "soc_"), ("file_prefix", "out-"), ("macro_prefix", "SOC_")):
            with self.subTest(prefix=name):
                result = self.generate(**{name: value})
                self.assertNotEqual(result.plan.generation_key, original.plan.generation_key)
                self.assertFalse(self.generate(**{name: value}).generated)
                if name == "file_prefix":
                    for relative, contents in baseline.items():
                        path = Path(relative)
                        if path.suffix == ".sv":
                            renamed = path.with_name("out-_" + path.name).as_posix()
                            self.assertEqual(self.outputs()[renamed], contents)
                else:
                    self.assertEqual(set(self.outputs()), set(baseline))
                    top = (self.root / "rtl/src/pipe_lane_mapper.sv").read_text()
                    expected = "soc_" if name == "module_prefix" else ""
                    self.assertIn(f"module {expected}pipe_lane_mapper #(", top)

    def test_prefix_switch_removes_old_names_and_clearing_restores_source_bytes(self):
        self.generate()
        baseline = {name: data for name, data in self.outputs().items() if not name.endswith("manifest.json")}
        self.generate(module_prefix="a_", file_prefix="a_", macro_prefix="A_")
        self.generate(module_prefix="b_", file_prefix="b_", macro_prefix="B_")
        self.assertFalse(any(Path(name).name.startswith("a_") for name in self.outputs()))
        self.assertFalse((self.root / "rtl/src/pipe_lane_mapper.sv").exists())
        self.generate()
        self.assertEqual({name: data for name, data in self.outputs().items()
                          if not name.endswith("manifest.json")}, baseline)

    def test_existing_trailing_underscore_is_not_added_twice(self):
        self.generate(module_prefix="soc", file_prefix="rtl", macro_prefix="SOC")
        first = {name: data for name, data in self.outputs().items() if not name.endswith("manifest.json")}
        self.generate(module_prefix="soc_", file_prefix="rtl_", macro_prefix="SOC_")
        self.assertEqual({name: data for name, data in self.outputs().items()
                          if not name.endswith("manifest.json")}, first)

    def test_invalid_prefixes_preserve_installed_outputs_and_flags(self):
        self.generate()
        baseline = self.outputs()
        flags = self.root / "config/gen_flags.txt"
        write_gen_flags(flags, {"module_prefix": "valid_"})
        original_flags = flags.read_bytes()
        for name, value in (
            ("module_prefix", "1bad_"), ("module_prefix", "bad-name"),
            ("macro_prefix", "bad name"), ("macro_prefix", "x\n`define BAD"),
            ("file_prefix", "../"), ("file_prefix", "C:\\escape\\"),
            ("file_prefix", "bad#"), ("file_prefix", "bad space"),
            ("file_prefix", None),
        ):
            with self.subTest(name=name, value=value):
                with self.assertRaisesRegex(ValidationError, name):
                    self.generate(**{name: value})
                self.assertEqual(self.outputs(), baseline)
                with self.assertRaisesRegex(ValueError, name):
                    write_gen_flags(flags, {name: value})
                self.assertEqual(flags.read_bytes(), original_flags)

    def test_flags_round_trip_preserves_crlf_and_clearing_drops_prefixes(self):
        flags = self.root / "config/gen_flags.txt"
        flags.write_bytes(b"arch = original_pipe\r\n")
        values = {"module_prefix": "soc_", "file_prefix": "v2.-_", "macro_prefix": "SOC_"}
        write_gen_flags(flags, values)
        for name, value in values.items():
            self.assertEqual(read_gen_flags(flags)[name], value)
        self.assertNotIn(b"\n", flags.read_bytes().replace(b"\r\n", b""))
        write_gen_flags(flags, {"bus-type": "bus"})
        self.assertFalse(set(values) & set(read_gen_flags(flags)))

    def test_matching_user_field_and_instance_names_are_preserved(self):
        payload = valid_payload()
        payload["signals"][0]["signal_name"] = "pipe_lane_mapper"
        save_workspace_content(self.root, payload)
        self.generate(module_prefix="soc_")
        package = (self.root / "rtl/src/pipe_lane_signal_pkg.sv").read_text()
        self.assertRegex(package, r"logic\s+\[7:0\]\s+pipe_lane_mapper\s*;")
        self.assertNotRegex(package, r"logic\s+\[7:0\]\s+soc_pipe_lane_mapper\s*;")
        tb = (self.root / "tb/tb_pipe_lane_mapper.sv").read_text()
        self.assertIn("soc_pipe_lane_mapper #(", tb)
        self.assertRegex(tb, r"\)\s+dut\s*\(")

    def test_lexical_context_preserves_comments_strings_fields_and_directives(self):
        source = '''// module pipe_lane_mapper; `PIPE_ICG_CELL
module pipe_lane_mapper;
import pipe_lane_signal_pkg::*;
pipe_lane_signal_pkg::mac2phy_t data;
logic pipe_lane_mapper;
assign data.pipe_lane_mapper = pipe_lane_mapper;
pipe_lane_mapper pipe_lane_mapper (.pipe_lane_mapper(pipe_lane_mapper));
initial $display("pipe_lane_mapper `PIPE_ICG_CELL");
`ifdef PIPE_USE_ICG_CELL
`PIPE_ICG_CELL u_icg ();
`else
`endif
endmodule
'''
        renamed = GenerationNames(module_prefix="soc_", macro_prefix="SOC_").sv_source(source)
        self.assertIn("// module pipe_lane_mapper; `PIPE_ICG_CELL", renamed)
        self.assertIn("module soc_pipe_lane_mapper;", renamed)
        self.assertIn("soc_pipe_lane_signal_pkg::mac2phy_t data;", renamed)
        self.assertIn("logic pipe_lane_mapper;", renamed)
        self.assertIn("assign data.pipe_lane_mapper = pipe_lane_mapper;", renamed)
        self.assertIn("soc_pipe_lane_mapper pipe_lane_mapper (.pipe_lane_mapper(pipe_lane_mapper));", renamed)
        self.assertIn('$display("pipe_lane_mapper `PIPE_ICG_CELL")', renamed)
        self.assertIn("`ifdef SOC_PIPE_USE_ICG_CELL", renamed)
        self.assertIn("`SOC_PIPE_ICG_CELL u_icg ();", renamed)
        self.assertIn("`else\n`endif", renamed)

    def test_cli_prefix_flags_apply_explicitly_and_do_not_read_ui_flags(self):
        write_gen_flags(self.root / "config/gen_flags.txt", {"module_prefix": "ignored_"})
        args = ["--config", str(self.root), "--quiet"]
        with contextlib.redirect_stdout(io.StringIO()):
            cli.cmd_generate(args)
            self.assertIn("module pipe_lane_mapper #(", (self.root / "rtl/src/pipe_lane_mapper.sv").read_text())
            cli.cmd_generate(args + ["--module-prefix", "soc_", "--file-prefix", "out_", "--macro-prefix", "SOC_"])
        self.assertIn("module soc_pipe_lane_mapper #(", (self.root / "rtl/src/out_pipe_lane_mapper.sv").read_text())
        self.assertIn("+define+SOC_DUMP_FSDB", (self.root / "tb/makefile").read_text())


if __name__ == "__main__":
    unittest.main()
