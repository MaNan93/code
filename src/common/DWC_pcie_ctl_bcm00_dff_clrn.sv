
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
// Description : DWC_pcie_ctl_bcm00_dff_clrn.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: f63e941c
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_dff_clrn (
    clk,
    rst_n,
    d,
    q
);


// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  input  clk;       // clock
  input  rst_n;     // reset
  input  d;         // data in
  output q;         // data out

`ifdef DWC_DFF_CLRN_SRC
  `DWC_DFF_CLRN_SRC
`else
  reg q;
  always @ (posedge clk or negedge rst_n) begin : dff_q_PROC
    if (rst_n == 1'b0) begin
      q <= 1'b0;
    end else begin
      q <= d;
    end
  end
`endif

// spyglass enable_block W146
endmodule
