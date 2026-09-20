"""DPR clock-routing regression, including optional generated-RTL simulation."""
import contextlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from plm.cli.main import validate_dpr
from plm.core import exporter
from plm.core.generator import rtl, tb
from plm.core.model import Config

ROOT = Path(__file__).resolve().parents[1]


class DprClockTests(unittest.TestCase):
    def setUp(self):
        self.cfg = Config(ROOT / "test" / "maxpclk" / "config")

    def test_input_mode_is_accepted_but_comb_stays_rejected(self):
        validate_dpr(True, "pclk_as_phy_input", "sync")
        validate_dpr(True, "pclk_as_phy_input")
        with self.assertRaises(SystemExit):
            validate_dpr(True, "pclk_as_phy_input", "comb")

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
            "phy_mac_rxdata,perlane,phy2mac,8,0,0\n",
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
        ):
            with self.subTest(mode=mode, dpr=dpr), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                config = self._simulation_config(root)
                out = root / "rtl"
                with contextlib.redirect_stdout(io.StringIO()):
                    exporter.export_rtl(config, out, pclk_mode=mode, dpr=dpr, quiet=True)
                    exporter.export_tb(config, out, pclk_mode=mode, dpr=dpr, quiet=True)
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
