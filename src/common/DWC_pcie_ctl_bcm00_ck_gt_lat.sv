
// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2024 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
//            Inclusivity and Diversity" (Refer to article 000036315 at
//                        https://solvnetplus.synopsys.com)
// 
// Component Name   : DWC_pcie_ctl_cxl
// Component Version: 6.14a-lca02
// Release Type     : LCA
// Build ID         : 69.19.33.11.PCIeParseConfig_1.PCIeSimulate_24.PCIeTbCommon_85.SNPSPHYSetup_21
// ------------------------------------------------------------------------------

//
// Description : DWC_pcie_ctl_bcm00_ck_gt_lat.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: cb5a90a6
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_ck_gt_lat (
    clk_in,
    en,
    test,
    clk_out

// spyglass disable_block UnrecSynthDir-ML
// SMD: Synthesis directive is not recognized
// SJ: These are specific Synopsys Design Compiler directives that are seen as Verilog comments to other synthesis tools.  So no Verilog coding rules are violated.
`ifndef DWC_EMB_SCR_IS_FOR_FC
  // synopsys dc_tcl_script_begin
  // set_ungroup [current_design] false;#
  // synopsys dc_tcl_script_end
`else
  // synopsys fc_tcl_script_begin
  // set_ungroup [get_modules DWC_pcie_ctl_bcm00_ck_gt_lat] false;#
  // synopsys fc_tcl_script_end
`endif
// spyglass enable_block UnrecSynthDir-ML
);


// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  input  clk_in;    // input clock
  input  en;        // enable
  input  test;      // test enable
  output clk_out;   // output clock

`ifdef DWC_CK_GT_LAT_SRC
  `DWC_CK_GT_LAT_SRC
`else
  reg latched_en;
  always @(clk_in or en or test) begin : gen_lat_PROC
// spyglass disable_block STARC-2.7.1.3a
// SMD: if statement does not have a corresponding else statement in combinational block
// SJ: This module is designed as a latch
    if (clk_in == 1'b0) begin
// spyglass disable_block InferLatch
// SMD: Latch inferred
// SJ: This module was intentionally implemenented with latches within it.
      latched_en = en | test;
// spyglass enable_block InferLatch
    end
// spyglass enable_block STARC-2.7.1.3a
  end

// spyglass disable_block W401
// SMD: Clock signal is not an input to the design unit
// SJ: The signal is designed to be an output as a gated clock
  assign clk_out = latched_en & clk_in;
// spyglass enable_block W401
`endif

// spyglass enable_block W146
endmodule
