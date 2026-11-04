
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
// Description : DWC_pcie_ctl_bcm00_ck_mx.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 7a6ccfcc
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_ck_mx (
    clk0,
    clk1,
    s,
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
  // set_ungroup [get_modules DWC_pcie_ctl_bcm00_ck_mx] false;#
  // synopsys fc_tcl_script_end
`endif
// spyglass enable_block UnrecSynthDir-ML
);


// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  input  clk0;      // input clock 0
  input  clk1;      // input clock 1
  input  s;         // clock select
  output clk_out;   // output clock

`ifdef DWC_CK_MX_SRC
  `DWC_CK_MX_SRC
`else
  assign clk_out = s ? // synopsys infer_mux
                   clk1 : clk0;
`endif

// spyglass enable_block W146
endmodule
