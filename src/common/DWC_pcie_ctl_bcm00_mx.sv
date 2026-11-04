
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
// Description : DWC_pcie_ctl_bcm00_mx.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: a4d0ab1b
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_mx (
    a0,
    a1,
    s,
    z
);


// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  input  a0;    // input a0
  input  a1;    // input a1
  input  s;     // clock select
  output z;     // output clock

`ifdef DWC_MX_SRC
  `DWC_MX_SRC
`else
  assign z = s ? // synopsys infer_mux_override
             a1 : a0;
`endif

// spyglass enable_block W146
endmodule
