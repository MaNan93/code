
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
// Description : DWC_pcie_ctl_bcm64_td.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: a475ddfa
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm64_td(
    clk,
    rst_n,
    init_n,
    push_req_n,
    pop_req_n,
    diag_n,
    ae_level,
    af_thresh,
    data_in,
    empty,
    almost_empty,
    half_full,
    almost_full,
    full,
    error,
    data_out
);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  parameter integer WIDTH           = 8;    // RANGE 1 TO 2048
  parameter integer DEPTH           = 4;    // RANGE 2 TO 1024
  parameter integer ERR_MODE        = 0;    // RANGE 0 TO 2
  parameter integer RST_MODE        = 0;    // RANGE 0 TO 1
  parameter integer ADDR_WIDTH      = 2;    // RANGE 1 TO 10
  parameter integer REG_DELAY_TIME  = 1;    // RANGE >= 0
  parameter integer REG_DELAY_DENOM = 1;    // RANGE >  0

  input                     clk;            // clock input
  input                     rst_n;          // active low async. reset
  input                     init_n;         // active low sync. reset (FIFO flush)
  input                     push_req_n;     // active low push request
  input                     pop_req_n;      // active low pop request
  input                     diag_n;         // active low diagnostic input
  input  [ADDR_WIDTH-1:0]   ae_level;       // Almost Empty Flag level
  input  [ADDR_WIDTH-1:0]   af_thresh;      // Almost Full Flag threshold
  input  [WIDTH-1 : 0]      data_in;        // FIFO input data bus
  output                    empty;          // empty status flag
  output                    almost_empty;   // almost empty status flag
  output                    half_full;      // half full status flag
  output                    almost_full;    // almost full status flag
  output                    full;           // full status flag
  output                    error;          // error status flag
  output [WIDTH-1 : 0]      data_out;       // FIFO outptu data bus

  wire                      ram_async_rst_n;
  wire   [ADDR_WIDTH-1 : 0] ram_rd_addr, ram_wr_addr;
  wire                      ram_we_n;


generate
  if (RST_MODE == 0) begin : GEN_MEM_RST_RM0
    assign ram_async_rst_n = rst_n;
  end else begin : GEN_MEM_RST_RM_NE_0
    assign ram_async_rst_n = 1'b1;
  end
endgenerate


  DWC_pcie_ctl_bcm86
   #(DEPTH, ERR_MODE, ADDR_WIDTH, REG_DELAY_TIME, REG_DELAY_DENOM) U_FIFO_CTL(
    .clk(clk),
    .rst_n(rst_n),
    .init_n(init_n),
    .push_req_n(push_req_n),
    .pop_req_n(pop_req_n),
    .diag_n(diag_n),
    .ae_level(ae_level),
    .af_thresh(af_thresh),
    .we_n(ram_we_n),
    .empty(empty),
    .almost_empty(almost_empty),
    .half_full(half_full),
    .almost_full(almost_full),
    .full(full),
    .error(error),
    .wr_addr(ram_wr_addr),
    .rd_addr(ram_rd_addr),
// spyglass disable_block W287b
// SMD: An output port of module or gate instance is not connected
// SJ: The following port(s) of this instance are intentionally unconnected.
// spyglass disable_block UnloadedOutTerm-ML
// SMD: Detected unloaded(unconnected) output terminal
// SJ: The following signal(s) are emanating from instance output port(s) that are intentionally not used. So, disable SpyGlass from reporting this warning. This instance design in which the signal(s) are connected is shared by other module(s) that may use these port(s) and signal(s) emanating from them.
    .wrd_count(),
    .nxt_empty_n(),
    .nxt_full(),
    .nxt_error()
// spyglass enable_block W287b
// spyglass enable_block UnloadedOutTerm-ML
  );

  DWC_pcie_ctl_bcm57
   #(WIDTH, DEPTH, 0, ADDR_WIDTH) U_FIFO_MEM(
    .clk(clk),
    .rst_n(ram_async_rst_n),
    .wr_n(ram_we_n),
    .rd_addr(ram_rd_addr),
    .wr_addr(ram_wr_addr),
    .data_in(data_in),
    .data_out(data_out)
  );

// spyglass enable_block W146
endmodule
