"""Independent PERST routing and interface/name contracts."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from plm.core.gen_flags import GenerationOptions
from plm.core.generator import rtl, tb
from plm.core.paths import COMMON_DIR
from plm.core.validation import ValidationError, load_generation_plan_from_payload
from test_core import valid_payload


def reset_payload():
    payload = valid_payload()
    payload["controllers"].append({"ctrl_id": "1", "ctrl_name": "CtrlB", "max_width": "1"})
    payload["mapping"]["rows"].append({"mode": "1", "lane0": "0-0", "lane1": "1-0"})
    return payload


class PerstResetTests(unittest.TestCase):
    def setUp(self):
        self.cfg = load_generation_plan_from_payload(reset_payload(), GenerationOptions()).config

    def test_top_and_both_connection_formats_expose_independent_scalar_controller_resets(self):
        for pclk_mode in ("pclk_as_phy_output", "pclk_as_phy_input"):
            for dpr in (False, True):
                for bus_type in ("flat", "bus"):
                    with self.subTest(pclk=pclk_mode, dpr=dpr, bus_type=bus_type):
                        top = rtl.gen_top(self.cfg, pclk_mode, dpr=dpr)
                        wrapper = rtl.gen_connection(self.cfg, pclk_mode, dpr=dpr, bus_type=bus_type)
                        for source in (top, wrapper):
                            self.assertIn("output logic [NL-1:0] phy_perst_n,", source)
                            self.assertIn("input logic ctrla_perst_n,", source)
                            self.assertIn("input logic ctrlb_perst_n,", source)
                            self.assertEqual("input logic dpr_perst_n," in source, dpr)
                        self.assertIn("assign ctrl_perst_n = {ctrlb_perst_n, ctrla_perst_n};", top)
                        resets = top.split(") u_rst_mux (", 1)[1].split(");", 1)[0]
                        self.assertIn(".ctrl_perst_n (ctrl_perst_n)", resets)
                        self.assertIn(".sel_tgt    (dec_tgt)", resets)
                        self.assertIn(".phy_perst_n (phy_perst_n)", resets)
                        self.assertIn(".phy_perst_n  (phy_perst_n)", wrapper)
                        self.assertIn(".ctrla_perst_n (ctrla_perst_n)", wrapper)
                        # PERST routes a reset output; it does not reset clock selection.
                        for instance in ("u_sel_gen", "u_clk_mux"):
                            ports = top.split(f") {instance} (", 1)[1].split(");", 1)[0]
                            self.assertNotIn("perst_n", ports)

    def test_direct_groups_and_mux_groups_use_independent_inputs_and_low_safe_state(self):
        source = rtl.gen_rst_mux(self.cfg)
        self.assertIn("assign phy_perst_n[0] = ctrl_perst_n[0];", source)
        self.assertIn(".din  ({ctrl_perst_n[1], ctrl_perst_n[0]})", source)
        perst = source.split("u_perst_g1 (", 1)[1].split(");", 1)[0]
        self.assertIn(".sel  (sel_tgt.g1)", perst)
        self.assertIn(".safe (1'b0)", perst)
        self.assertNotIn("ctrl_rst_n", perst)
        self.assertIn("assign phy_perst_n[1] = perst_n_g1;", source)

    def test_dpr_is_an_independent_reset_candidate_even_for_direct_groups(self):
        source = rtl.gen_rst_mux(self.cfg, dpr=True)
        self.assertIn(".din  ({dpr_perst_n, ctrl_perst_n[0]})", source)
        self.assertIn(".din  ({dpr_perst_n, ctrl_perst_n[1], ctrl_perst_n[0]})", source)
        for group in self.cfg.groups:
            perst = source.split(f"u_perst_g{group.gid} (", 1)[1].split(");", 1)[0]
            self.assertIn(".safe (1'b0)", perst)
            self.assertNotIn("dpr_rst_n", perst)

    def test_signal_csv_cannot_shadow_new_reset_ports(self):
        for pclk_mode in ("pclk_as_phy_output", "pclk_as_phy_input"):
            for dpr in (False, True):
                with self.subTest(pclk=pclk_mode, dpr=dpr):
                    payload = reset_payload()
                    payload["signals"][0]["signal_name"] = "perst_n"
                    options = GenerationOptions(
                        arch="serdes" if pclk_mode == "pclk_as_phy_input" else "original_pipe",
                        pclk_mode=pclk_mode, dpr=dpr,
                    )
                    with self.assertRaisesRegex(ValidationError, "phy_perst_n"):
                        load_generation_plan_from_payload(payload, options)

    def test_testbench_connects_perst_and_pulses_it_independently_in_every_mode(self):
        for pclk_mode in ("pclk_as_phy_output", "pclk_as_phy_input"):
            for dpr in (False, True):
                with self.subTest(pclk=pclk_mode, dpr=dpr):
                    source = tb.gen_tb(self.cfg, pclk_mode, dpr)
                    self.assertIn(".phy_perst_n    (phy_perst_n)", source)
                    self.assertIn(".ctrlb_perst_n (ctrl_perst_n[1])", source)
                    self.assertIn("ctrl_perst_n[c] = 1'b0; #1;", source)
                    for mode in self.cfg.modes:
                        self.assertIn(f"check_perst({mode});", source)
                    self.assertIn("rst_n must not change perst_n", source)
                    self.assertIn("perst_n must not change rst_n", source)
                    if dpr:
                        self.assertIn(".dpr_perst_n    (dpr_perst_n)", source)
                        self.assertIn("DPR perst_n override routing", source)

    @unittest.skipUnless(os.environ.get("PLM_RUN_RTL_SIM") == "1",
                         "set PLM_RUN_RTL_SIM=1 to run Verilator")
    def test_reset_mux_behavior_with_independent_patterns_dpr_and_zero_selection(self):
        simulator = os.environ.get("PLM_VERILATOR") or shutil.which("verilator")
        self.assertTrue(simulator, "Verilator is required for requested simulation")
        for dpr in (False, True):
            with self.subTest(dpr=dpr), tempfile.TemporaryDirectory(prefix="plm_perst_") as temporary:
                root = Path(temporary)
                (root / "pipe_lane_signal_pkg.sv").write_text(rtl.gen_pkg(self.cfg, dpr), encoding="utf-8")
                shutil.copy2(COMMON_DIR / "pipe_lane_data_mux.sv", root)
                (root / "pipe_lane_rst_mux.sv").write_text(rtl.gen_rst_mux(self.cfg, dpr), encoding="utf-8")
                dpr_ports = ".dpr_rst_n(dpr_rst_n), .dpr_perst_n(dpr_perst_n)," if dpr else ""
                # Expose one-hot selectors without depending on the package's bit layout.
                # This combinational reset mux needs no clock or timed SV process.
                body = f'''
import pipe_lane_signal_pkg::*;
module perst_probe (
  input logic [1:0] ctrl_rst_n, ctrl_perst_n, sel0,
  input logic [2:0] sel1,
  input logic dpr_rst_n, dpr_perst_n,
  output logic [1:0] phy_rst_n, phy_perst_n
);
  lane_sel_t sel_tgt;
  always_comb begin
    sel_tgt = '0;
    {"sel_tgt.g0 = sel0;" if dpr else "// Direct group has no selector without DPR."}
    sel_tgt.g1 = sel1{'' if dpr else '[1:0]'};
  end
  pipe_lane_rst_mux dut (.ctrl_rst_n(ctrl_rst_n), .ctrl_perst_n(ctrl_perst_n),
    {dpr_ports}
    .sel_tgt(sel_tgt), .phy_rst_n(phy_rst_n), .phy_perst_n(phy_perst_n));
endmodule
'''
                (root / "perst_probe.sv").write_text(body, encoding="utf-8")
                driver = '''#include "Vperst_probe.h"
#include "verilated.h"
#include <iostream>
double sc_time_stamp() { return 0.0; }
int main(int argc, char** argv) {
  VerilatedContext context;
  context.threads(1);
  context.commandArgs(argc, argv);
  Vperst_probe dut{&context};
  constexpr bool dpr = DPR_ENABLED;
  for (unsigned bits = 0; bits < 64; ++bits) {
    dut.ctrl_rst_n = bits & 3; dut.ctrl_perst_n = (bits >> 2) & 3;
    dut.dpr_rst_n = (bits >> 4) & 1; dut.dpr_perst_n = (bits >> 5) & 1;
    auto expected = [bits](int owner, int dpr_owner, bool perst) {
      if (owner < 0) return 0U;
      unsigned bit = dpr && owner == dpr_owner ? (perst ? 5 : 4) : owner + (perst ? 2 : 0);
      return (bits >> bit) & 1U;
    };
    for (int owner0 = -1; owner0 < (dpr ? 2 : 1); ++owner0) {
      for (int owner1 = -1; owner1 < (dpr ? 3 : 2); ++owner1) {
        dut.sel0 = owner0 < 0 ? 0 : 1 << owner0;
        dut.sel1 = owner1 < 0 ? 0 : 1 << owner1;
        dut.eval();
        int first = dpr ? owner0 : 0;
        unsigned rst = expected(first, 1, false) | (expected(owner1, 2, false) << 1);
        unsigned perst = expected(first, 1, true) | (expected(owner1, 2, true) << 1);
        if (dut.phy_rst_n != rst || dut.phy_perst_n != perst) {
          std::cerr << "reset routing failed: " << bits << " " << owner0 << " " << owner1 << std::endl;
          return 1;
        }
      }
    }
  }
  dut.final();
  std::cout << "PERST_RESULT: PASS" << std::endl;
}
'''.replace("DPR_ENABLED", "true" if dpr else "false")
                (root / "driver.cpp").write_text(driver, encoding="utf-8")
                build = subprocess.run([
                    simulator, "--cc", "--exe", "--build", "-j", "2", "-Wno-fatal",
                    "--top-module", "perst_probe",
                    "pipe_lane_signal_pkg.sv", "pipe_lane_data_mux.sv",
                    "pipe_lane_rst_mux.sv", "perst_probe.sv", "driver.cpp",
                ], cwd=root, capture_output=True, text=True, timeout=180)
                self.assertEqual(build.returncode, 0, build.stdout[-4000:] + build.stderr[-4000:])
                executable = root / "obj_dir" / ("Vperst_probe.exe" if os.name == "nt" else "Vperst_probe")
                run = subprocess.run([str(executable)], cwd=root, capture_output=True, text=True, timeout=30)
                transcript = run.stdout + run.stderr
                self.assertEqual(run.returncode, 0, transcript[-4000:])
                self.assertIn("PERST_RESULT: PASS", transcript)


if __name__ == "__main__":
    unittest.main()
