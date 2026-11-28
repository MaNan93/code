# pcie_pipe_link

Point-to-point PCIe PIPE 5/6 SerDes link interconnect model (`Gen1`–`Gen6`) with per-lane bifurcation support, Dynamic MAXPCLK (`pclk_as_phy_input`), and `always_latch + and` glitch-free clock gating.

## Key Features
- **PCIe 6.0 SerDes Architecture (`MAX_RATE=5`)**: Supports Gen1 (`62.5 MHz`) through Gen6 (`1000 MHz x 8s`, `DATA_WD=80`, `TXEI_WD=4`, `DIRFEEDBACK_WD=12`). Parameterizable down to Gen5 SerDes (`DATA_WD=40`, `DIRFEEDBACK_WD=6`).
- **Integrated Clock Gate (`always_latch + and`)**: `pcie_pipe_clock_gate` uses a 2-FF request synchronizer, negative-level `always_latch`, and `clk & gate_enable` combinational AND gate.
- **`pclk_as_phy_input` Dynamic MAXPCLK**: Per-lane `max_pclk`, `phy_mac_maxpclkack_n`, `mac_phy_maxpclkreq_n`, `pclk` input, and peer-rate-tracked `rx_clk`.
- **Full Per-Lane Bifurcation**: All reset, clock, rate, powerdown, EQ, and data ports are defined independently per lane (`[NL-1:0]`), allowing `x8`, `2x4`, `x4+2x2`, or arbitrary sub-link combinations through a single `pcie_pipe_link` instance.
- **Race-Free Per-Lane CDC**: Each lane direction crosses `tx_pclk -> rx_clk` through an async Gray-code `pcie_pipe_cdc_fifo`.

## Files
- [flist.f](flist.f)
- [rtl/pcie_pipe_clock_gate.sv](rtl/pcie_pipe_clock_gate.sv)
- [rtl/pcie_pipe_pclk_switch.sv](rtl/pcie_pipe_pclk_switch.sv)
- [rtl/pcie_pipe_cdc_fifo.sv](rtl/pcie_pipe_cdc_fifo.sv)
- [rtl/pcie_pipe_eq_lane.sv](rtl/pcie_pipe_eq_lane.sv)
- [rtl/pcie_pipe_status_lane.sv](rtl/pcie_pipe_status_lane.sv)
- [rtl/pcie_pipe_lane.sv](rtl/pcie_pipe_lane.sv)
- [rtl/pcie_pipe_side.sv](rtl/pcie_pipe_side.sv)
- [rtl/pcie_pipe_link.sv](rtl/pcie_pipe_link.sv)
- [tests/tb_pcie_pipe_link_sv.sv](tests/tb_pcie_pipe_link_sv.sv)
- [tests/run_clock_tests.py](tests/run_clock_tests.py)

## Verification
```bash
python3 tests/run_clock_tests.py
```
