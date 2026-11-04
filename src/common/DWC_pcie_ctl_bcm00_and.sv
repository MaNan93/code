
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
// Description : DWC_pcie_ctl_bcm00_and.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 7e475dc6
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_and (
    a,
    b,
    z
);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  parameter integer WIDTH = 1;   // RANGE 1 to 1024

  input  [WIDTH-1:0] a;          // Input A
  input  [WIDTH-1:0] b;          // Input B
  output [WIDTH-1:0] z;          // Output

`ifdef DWC_AND_SRC
  `DWC_AND_SRC
`else
  assign z = a & b;
`endif

// spyglass enable_block W146
endmodule
