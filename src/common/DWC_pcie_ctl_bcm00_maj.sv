
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
// Description : DWC_pcie_ctl_bcm00_maj.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 5c9d8090
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_maj (
    a,
    b,
    c,
    z
    );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH        = 1;  // RANGE 1 to 8192


input  [WIDTH-1:0]      a;    // 1st voter data input bus
input  [WIDTH-1:0]      b;    // 2nd voter data input bus
input  [WIDTH-1:0]      c;    // 3rd voter data input bus
output [WIDTH-1:0]      z;    // majority voted data output bus

// spyglass disable_block Ac_conv01
// SMD: Synchronized sequential element(s) converge on combinational logic
// SJ: The single-bit signals converging into sequential elements are triplicated from the same signal at the source and run through parallel paths of synchronizers with the identical number of stages.  This synchronized convergence is intentional and directly supplies combinational logic that produces a majority vote result which is immune to non-gray code transitions.
// spyglass disable_block Ac_conv02
// SMD: Synchronizers converge on combinational logic
// SJ: The single-bit signals converging into the combinational logic are triplicated from the same signal at the source and run through parallel paths of synchronizers with the identical number of stages.  This synchronized convergence is intentional as the combinational logic produces a majority vote result which is immune to non-gray code transitions.
`ifdef DWC_MAJORITY_VOTE_CELL_SRC
  `DWC_MAJORITY_VOTE_CELL_SRC
`else
  assign z = (a & b) | (a & c) | (b & c);
`endif
// spyglass enable_block Ac_conv01
// spyglass enable_block Ac_conv02

// spyglass enable_block W146
endmodule
