"""DPR clock-routing regression, including optional generated-RTL simulation."""
import contextlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from plm.core import exporter
from plm.core.gen_flags import GenerationOptions
from plm.core.generator import rtl, tb
from plm.core.model import Config
from plm.core.plan import GenerationPlan

from sample_data import sample_config


class DprClockTests(unittest.TestCase):
    def setUp(self):
        self.cfg = Config(sample_config("maxpclk"))

    def test_select_mode_is_derived_from_dpr_and_cannot_be_chosen(self):
        self.assertEqual(GenerationOptions(dpr=True).validated().sel_mode, "sync")
        self.assertEqual(GenerationOptions(dpr=False).validated().sel_mode, "comb")
        with self.assertRaises(TypeError):
            GenerationOptions(dpr=True, sel_mode="comb")

    def test_clock_ports_and_no_derived_input_clock(self):
        for generator in (rtl.gen_top, rtl.gen_connection):
            source = generator(self.cfg, pclk_mode="pclk_as_phy_input", dpr=True)
            self.assertIn("input logic dpr_pclk,", source)
            self.assertIn("output logic [NL-1:0] dpr_rx_clk,", source)
            source = generator(self.cfg, dpr=True)
            self.assertIn("output logic dpr_pclk,", source)
            self.assertNotIn("dpr_rx_clk", source)
        clocks = rtl.gen_clk_mux(self.cfg, "pclk_as_phy_input", True)
        self.assertNotIn("real_pclk", clocks)
        self.assertNotIn("dpr_pclk_tgt", clocks)
        for g in self.cfg.groups:
            for lane in g.lanes:
                self.assertIn(f".clk_out(dpr_rx_clk[{lane}])", clocks)
                self.assertIn(f".en(rxclk_en_g{g.gid}_l{lane}[{g.n}])", clocks)

    def test_rx_data_and_clock_share_rx_domain_ownership(self):
        source = rtl.gen_top(self.cfg, "pclk_as_phy_input", dpr=True)
        receive = source.split(") u_data_p2m (", 1)[1]
        for g in self.cfg.groups:
            for lane in g.lanes:
                self.assertIn(
                    f".seltgt_g{g.gid}_l{lane} (rxclk_en_g{g.gid}_l{lane})",
                    receive,
                )

    def test_phy_output_generation_is_unchanged(self):
        self.assertNotIn("input logic dpr_pclk,", rtl.gen_top(self.cfg, dpr=True))
        self.assertIn("phy_pclk_out", rtl.gen_clk_mux(self.cfg, dpr=True))

    def test_testbench_clocks_have_one_scalar_driver_each(self):
        source = tb.gen_tb(self.cfg, pclk_mode="pclk_as_phy_input", dpr=True)
        self.assertIn("logic ctrl_ref_clk_src_0 = 1'b0;", source)
        self.assertIn("assign ctrl_ref_clk[0] = ctrl_ref_clk_src_0;", source)
        self.assertIn("logic rx_clk_src_0 = 1'b0;", source)
        self.assertNotIn("ctrl_ref_clk[c] = ~ctrl_ref_clk[c]", source)
        self.assertNotIn("rx_clk[l] = ~rx_clk[l]", source)

        source = tb.gen_tb(self.cfg, pclk_mode="pclk_as_phy_output", dpr=True)
        self.assertIn("logic phy_pclk_out_src_0 = 1'b0;", source)
        self.assertIn("assign phy_pclk_out[0] = phy_pclk_out_src_0;", source)
        self.assertNotIn("phy_pclk_out[l] = ~phy_pclk_out[l]", source)

    @staticmethod
    def _simulation_config(root: Path) -> Config:
        """Keep the compiled regression small while exercising both data directions."""
        config_dir = root / "config"
        config_dir.mkdir()
        (config_dir / "controllers.csv").write_text(
            "ctrl_id,ctrl_name,max_width\n0,CtrlA,2\n1,CtrlB,1\n",
            encoding="utf-8",
        )
        (config_dir / "lane_mapping.csv").write_text(
            "mode,lane0,lane1\n0,0-0,0-1\n1,0-0,1-0\n",
            encoding="utf-8",
        )
        (config_dir / "pipe_signals.csv").write_text(
            "signal_name,signal_type,direction,width,safe_state,tie_off\n"
            "mac_phy_txdata,perlane,mac2phy,8,0,0\n"
            "phy_mac_rxdata,perlane,phy2mac,8,0,lane0\n"
            "custom_rx,perlane,phy2mac,8,0,lane0\n"
            "custom_tx,perlane,mac2phy,8,0,0\n",
            encoding="utf-8",
        )
        config = Config(config_dir)
        if errors := config.validate():
            raise AssertionError("invalid simulation fixture: " + "; ".join(errors))
        return config

    @unittest.skipUnless(os.environ.get("PLM_RUN_RTL_SIM") == "1",
                         "set PLM_RUN_RTL_SIM=1 to run Verilator")
    def test_generated_rtl_verilator_simulation(self):
        simulator = os.environ.get("PLM_VERILATOR") or shutil.which("verilator")
        self.assertTrue(simulator, "Verilator is required for requested simulation")
        for mode, dpr in (
            ("pclk_as_phy_input", True),
            ("pclk_as_phy_input", False),
            ("pclk_as_phy_output", True),
            ("pclk_as_phy_output", False),
        ):
            with self.subTest(mode=mode, dpr=dpr), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                config = self._simulation_config(root)
                out = root / "rtl"
                options = GenerationOptions(
                    arch="serdes" if mode == "pclk_as_phy_input" else "original_pipe",
                    pclk_mode=mode,
                    dpr=dpr,
                    quiet=True,
                )
                plan = GenerationPlan.build(config, options)
                with contextlib.redirect_stdout(io.StringIO()):
                    exporter.export_all(plan, out)
                build = subprocess.run(
                    [simulator, "--binary", "--timing", "-j", "0", "-Wno-fatal",
                     "-CFLAGS", "-std=c++20",
                     "--top-module", "tb_pipe_lane_mapper", "-f", "flist.f",
                     "../tb/tb_pipe_lane_mapper.sv"],
                    cwd=out, capture_output=True, text=True, timeout=180,
                )
                self.assertEqual(
                    build.returncode,
                    0,
                    build.stdout[-4000:] + build.stderr[-4000:],
                )
                executable = out / "obj_dir" / (
                    "Vtb_pipe_lane_mapper.exe" if os.name == "nt" else "Vtb_pipe_lane_mapper"
                )
                run = subprocess.run(
                    [str(executable)],
                    cwd=out,
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                transcript = run.stdout + run.stderr
                self.assertEqual(run.returncode, 0, transcript[-4000:])
                self.assertIn("TB_RESULT: PASS", transcript, transcript[-4000:])


if __name__ == "__main__":
    unittest.main()
