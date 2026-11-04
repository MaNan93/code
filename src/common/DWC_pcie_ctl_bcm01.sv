
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
// Description : DWC_pcie_ctl_bcm01.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: d0bb077d
//
////////////////////////////////////////////////////////////////////////////////


  module DWC_pcie_ctl_bcm01 (
      // Inputs
        a,
        tc,
        min_max,
      // Outputs
        value,
        index
);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH =               4;      // element WIDTH
parameter integer NUM_INPUTS =          8;      // number of elements in input array
parameter integer INDEX_WIDTH =         3;      // size of index pointer = ceil(log2(NUM_INPUTS))


input  [NUM_INPUTS*WIDTH-1 : 0]         a;      // Concatenated input vector
input                                   tc;     // 0 = unsigned, 1 = signed
input                                   min_max;// 0 = find min, 1 = find max
output [WIDTH-1:0]                      value;  // mon or max value found
output [INDEX_WIDTH-1:0]                index;  // index to value found

  DW_minmax #(WIDTH,NUM_INPUTS) U1(
        .a(a),
        .tc(tc),
        .min_max(min_max),
        .value(value),
        .index(index) );


// spyglass enable_block W146
endmodule
