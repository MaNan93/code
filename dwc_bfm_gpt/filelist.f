// Full BFM + testbench. Needs a simulator with clocking-block and
// virtual-interface support (VCS / Xcelium / Questa).  Verilator 5.x
// cannot compile this list -- see filelist_unit.f for the part it can.
+incdir+src
src/dwc_pcie_cfg_pkg.sv
src/dwc_pcie_core_pkg.sv
src/dwc_pcie_xali_if.sv
src/dwc_pcie_trgt1_if.sv
src/dwc_trgt1_pkt_halt_tracker.sv
src/dwc_pcie_bfm_pkg.sv
tb/dwc_pcie_ctrl_stub_pkg.sv
tb/tb_dwc_pcie_bfm.sv
