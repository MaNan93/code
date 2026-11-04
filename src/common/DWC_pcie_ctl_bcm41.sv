
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
// Description : DWC_pcie_ctl_bcm41.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 3e166e35
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm41 (
    clk_d,
    rst_d_n,
    data_s,
    data_d
    );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH        = 1;  // RANGE 1 to 1024
parameter [WIDTH-1:0] RST_VAL = {WIDTH{1'b1}}; // RANGE 0 to (2**WIDTH)-1
parameter integer F_SYNC_TYPE  = 2;  // RANGE 0 to 4
parameter integer VERIF_EN     = 1;  // RANGE 0 to 5
parameter integer SVA_TYPE     = 1;  // RANGE 0 to 2

localparam F_SYNC_TYPE_P8 = F_SYNC_TYPE + 8;

input                   clk_d;      // clock input from destination domain
input                   rst_d_n;    // active low asynchronous reset from destination domain
input  [WIDTH-1:0]      data_s;     // data to be synchronized from source domain
output [WIDTH-1:0]      data_d;     // data synchronized to destination domain

wire   [WIDTH-1:0]      data_s_int;
wire   [WIDTH-1:0]      data_d_int;

  assign data_s_int = data_s ^ RST_VAL;

  DWC_pcie_ctl_bcm21
   #(
    WIDTH,
    F_SYNC_TYPE_P8,
    VERIF_EN,
    SVA_TYPE
  ) U_SYNC (
      .clk_d(clk_d),
      .rst_d_n(rst_d_n),
      .data_s(data_s_int),
      .data_d(data_d_int)
      );

  assign data_d = data_d_int ^ RST_VAL;


// spyglass enable_block W146
endmodule
