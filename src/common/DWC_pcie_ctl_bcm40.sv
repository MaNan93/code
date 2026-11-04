
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
// Description : DWC_pcie_ctl_bcm40.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 782369bd
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm40 (
  clk_d,          // destination clk
  rst_s_n,        // input reset from source domain (to be synched to desitination)
  test,           // test==1 for scan testing
  test_rst_n,     // reset to be used during test==1
  rst_d_n         // reset output synchronized to destination clock
);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer F_SYNC_TYPE    = 2;  // RANGE 0 to 4
parameter integer TST_RST_EN     = 0;  // RANGE 0 to 1
parameter integer CLK_MUX_EN     = 0;  // RANGE 0 to 1
parameter integer ATPG_FF_IN_EN  = 0;  // RANGE 0 to 1
parameter integer ATPG_FF_OUT_EN = 0;  // RANGE 0 to 1

localparam F_SYNC_TYPE_P8 = F_SYNC_TYPE + 8;

input  clk_d;          // destination clock
input  rst_s_n;        // input reset from source domain (to be synched to dest)
input  test;           // test==1 for scan testing
input  test_rst_n;     // reset to be used during test==1
output rst_d_n;        // reset output synchronized to destination clock

wire   rst_n_synced;   // intermediate internal reset signal
wire   rst_s_n_int;    // intermediate internal source reset
wire   data_s_int;     // intermediate internal source data

generate
  if(TST_RST_EN==1) begin : GEN_TST_RST_EQ_1
    DWC_pcie_ctl_bcm00_atpg_mx
     #(CLK_MUX_EN, ATPG_FF_IN_EN) U_MUX_IN(
      .clk(clk_d),
      .scan_rst_n(test_rst_n),
      .rst_n(rst_s_n),
      .test(test),
      .test_rst_n(test_rst_n),
      .mx_rst_n(rst_s_n_int)
    );
  end else begin : GEN_TST_RST_NEQ_1
    assign rst_s_n_int = rst_s_n;
  end
endgenerate

generate
  if((F_SYNC_TYPE & 7) == 0) begin : GEN_FST_EQ_0
    assign data_s_int = rst_s_n_int;
  end else begin : GEN_FST_NEQ_0
    assign data_s_int = 1'b1;
  end
endgenerate

DWC_pcie_ctl_bcm00_atpg_mx
 #(CLK_MUX_EN, ATPG_FF_OUT_EN) U_MUX_OUT(
  .clk(clk_d),
  .scan_rst_n(test_rst_n),
  .rst_n(rst_n_synced),
  .test(test),
  .test_rst_n(test_rst_n),
  .mx_rst_n(rst_d_n)
);

DWC_pcie_ctl_bcm21
 #(1, F_SYNC_TYPE_P8, 0, 20) U_SYNC(
  .clk_d(clk_d),
  .rst_d_n(rst_s_n_int),
  .data_s(data_s_int),
  .data_d(rst_n_synced)
);

// spyglass enable_block W146
endmodule
