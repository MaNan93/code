
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
// Description : DWC_pcie_ctl_bcm95_i.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: cd3c6341
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm95_i (
  clk,
  rst_n,
  init_n,
  d_in,
  d_out
);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer TMR = 0;
parameter integer WIDTH = 1;
parameter [WIDTH-1:0] RSTVAL = {WIDTH{1'b0}};
parameter [WIDTH-1:0] INITVAL = {WIDTH{1'b1}};

localparam WIDTH_DOUT = (TMR == 2) ? WIDTH*3 : WIDTH;

input                   clk;
input                   rst_n;
input                   init_n;
input  [WIDTH-1:0]      d_in;
output [WIDTH_DOUT-1:0] d_out;

localparam [WIDTH-1:0] INIT_VALUE = (&INITVAL==1'b1)? RSTVAL : INITVAL;

generate

  if (TMR == 0) begin : GEN_TMR_EQ_0
    reg [WIDTH-1:0] ff_q;

    always @ (posedge clk or negedge rst_n) begin : NON_TMR_PROC
      if (rst_n == 1'b0) begin
        ff_q <= RSTVAL;
      end else if (init_n == 1'b0) begin
        ff_q <= INIT_VALUE;
      end else begin
// spyglass disable_block Reset_sync04
// SMD: Asynchronous resets that are synchronized more than once in the same clock domain
// SJ: Spyglass recognizes every multi-flop synchronizer as a reset synchronizer, hence any design with a reset that feeds more than one synchronizer gets reported as violating this rule. This rule is waivered temporarily.
        ff_q <= d_in;
// spyglass enable_block Reset_sync04
      end
    end

    assign d_out = ff_q;
  end else begin : GEN_TMR_NE_0

    reg [WIDTH-1:0] dw_so_reg1;
    reg [WIDTH-1:0] dw_so_reg2;
    reg [WIDTH-1:0] dw_so_reg3;

    always @ (posedge clk or negedge rst_n) begin : TMR_PROC
      if (rst_n == 1'b0) begin
        dw_so_reg1 <= RSTVAL;
        dw_so_reg2 <= RSTVAL;
        dw_so_reg3 <= RSTVAL;
      end else if (init_n == 1'b0) begin
        dw_so_reg1 <= INIT_VALUE;
        dw_so_reg2 <= INIT_VALUE;
        dw_so_reg3 <= INIT_VALUE;
      end else begin
        dw_so_reg1 <= d_in;
        dw_so_reg2 <= d_in;
        dw_so_reg3 <= d_in;
      end
    end

    if (TMR == 1) begin : GEN_TMR_EQ_1
      DWC_pcie_ctl_bcm00_maj
       #(WIDTH) U_MAJ_VT (
                                       .a(dw_so_reg1),
                                       .b(dw_so_reg2),
                                       .c(dw_so_reg3),
                                       .z(d_out) );
    end else begin : GEN_TMR_EQ_2

      assign d_out = {dw_so_reg3, dw_so_reg2, dw_so_reg1};
    end

  end

endgenerate

// spyglass enable_block W146
endmodule
