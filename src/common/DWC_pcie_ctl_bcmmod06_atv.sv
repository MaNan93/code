
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
// Filename    : DWC_pcie_ctl_bcmmod06_atv.v
// Revision    : $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_ctl_bcmmod06_atv.sv#3 $
// Author      : Rick Kelly          4/14/17
// Description : DWC_pcie_ctl_bcmmod06_atv.v Verilog module for DWC_cxl
//               Delta from DWC_pcie_ctl_bcm06_atv.v to Optimize on we_n timing path
//
// DesignWare IP ID: c7007aca
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcmmod06_atv (
    clk,
    rst_n,
    init_n,
    push_req_n,
    pop_req_n,
    diag_n,
    ae_level,
    af_thresh,
    we_n,
    empty,
    almost_empty,
    half_full,
    almost_full,
    full,
    error,
    wr_addr,
    rd_addr,
    wrd_count,
    nxt_empty_n,
    nxt_full,
    nxt_error
    );

parameter DEPTH  = 4;           // RANGE 2 to 16777216
parameter ERR_MODE  =  0 ;      // RANGE 0 to 2
parameter ADDR_WIDTH = 2;       // RANGE 1 to 24
parameter TMR         = 0 ;     // RANGE 0 to 1

input                   clk;            // Input Clock (pos edge)
input                   rst_n;          // Async reset (active low)
input                   init_n;         // Sync reset (active low) (FIFO clear/flush)
input                   push_req_n;     // Push request (active low)
input                   pop_req_n;      // Pop Request (active low)
input                   diag_n;         // Diagnostic sync. reset rd_addr (active low)
input  [ADDR_WIDTH-1:0] ae_level;       // Almost empty level input bus
input  [ADDR_WIDTH-1:0] af_thresh;      // Almost full threshold input bus
output                  we_n;           // RAM Write Enable output (active low)
output                  empty;          // FIFO Empty flag output (active high)
output                  almost_empty;   // FIFO Almost Empty flag output (active high)
output                  half_full;      // FIFO Half Full flag output (active high)
output                  almost_full;    // FIFO almost Full flag output (active high)
output                  full;           // FIFO full flag output (active high)
output                  error;          // FIFO Error flag output (active high)
output [ADDR_WIDTH-1:0] wr_addr;        // RAM Write Address output bus
output [ADDR_WIDTH-1:0] rd_addr;        // RAM Read Address output bus
output [ADDR_WIDTH-1:0] wrd_count;      // Words in FIFO (not always accurate at full)
output                  nxt_empty_n;    // Look ahead empty flag (active low)
output                  nxt_full;       // Look ahead full flag
output                  nxt_error;      // Look ahead empty flag


wire                    next_empty_n;
wire                    empty_n;
wire                    next_almost_empty_n;
wire                    almost_empty_n;
wire                    next_half_full;
wire                    half_full_int;
wire                    next_almost_full;
wire                    almost_full_int;
wire                    next_full;
wire                    full_int;
wire                    next_error;
wire                    error_int;
wire [ADDR_WIDTH-1:0]   next_wr_addr;
wire  [ADDR_WIDTH-1:0]  wr_addr_int;
wire                    next_wr_addr_at_max;
wire                    wr_addr_at_max;
wire [ADDR_WIDTH-1:0]   next_rd_addr;
wire  [ADDR_WIDTH-1:0]  rd_addr_int;
wire                    next_rd_addr_at_max;
wire                    rd_addr_at_max;
wire [ADDR_WIDTH-1:0]   next_word_count;
wire  [ADDR_WIDTH-1:0]  word_count;
reg  [ADDR_WIDTH  :0]   advanced_word_count;

wire                    advance_wr_addr;
wire [ADDR_WIDTH+1:0]   advanced_wr_addr;
wire                    advance_rd_addr;
wire [ADDR_WIDTH+1:0]   advanced_rd_addr;
wire                    inc_word_count;
wire                    dec_word_count;

localparam [ADDR_WIDTH-1 : 0] LASTADDRESS   =  DEPTH - 1;
localparam [ADDR_WIDTH-1 : 0] HF_THRESH_VAL = (DEPTH + 1)/2;
localparam [ADDR_WIDTH   : 0] ADDRP1_SIZED_ONE = 1;
localparam [ADDR_WIDTH-1 : 0] ADDR_SIZED_ONE   = 1;

  //assign we_n = push_req_n | (full_int & pop_req_n);
  assign we_n = push_req_n;


  //assign advance_wr_addr = ~(push_req_n | (full_int & pop_req_n));
  assign advance_wr_addr = ~push_req_n ;

  assign advance_rd_addr = ~pop_req_n  & empty_n;


  assign advanced_wr_addr = {wr_addr_int,advance_wr_addr} + ADDRP1_SIZED_ONE;
  assign next_wr_addr = (wr_addr_at_max  &advance_wr_addr)?
                                {ADDR_WIDTH{1'b0}} :
                                advanced_wr_addr[ADDR_WIDTH:1];

  assign advanced_rd_addr = {rd_addr_int,advance_rd_addr} + ADDRP1_SIZED_ONE;

  assign next_rd_addr_at_max = ((next_rd_addr & LASTADDRESS) == LASTADDRESS)? 1'b1 : 1'b0;

  assign next_wr_addr_at_max = ((next_wr_addr & LASTADDRESS) == LASTADDRESS)? 1'b1 : 1'b0;

  assign inc_word_count = ~push_req_n & pop_req_n & (~full_int) |
                          (~push_req_n) & (~empty_n);

  assign dec_word_count = push_req_n & (~pop_req_n) & empty_n;

  always @ (word_count or dec_word_count) begin : infer_incdec_PROC
    if (dec_word_count)
      advanced_word_count = word_count - ADDR_SIZED_ONE;
    else
      advanced_word_count = word_count + ADDR_SIZED_ONE;
  end

  assign next_word_count = ((inc_word_count | dec_word_count) == 1'b0)?
                                word_count : advanced_word_count[ADDR_WIDTH-1:0];

  assign next_full =    ((word_count == LASTADDRESS)? ~push_req_n & pop_req_n : 1'b0) |
                        (full_int & push_req_n & pop_req_n) |
                        (full_int & (~push_req_n));

  assign next_empty_n = (next_word_count == {ADDR_WIDTH{1'b0}})? next_full : 1'b1;


  assign next_half_full = (next_word_count >= HF_THRESH_VAL)? 1'b1 : next_full;


generate
  if ((1<<ADDR_WIDTH) == DEPTH) begin : GEN_PWR2
    assign next_almost_empty_n = ~(((next_word_count <= ae_level)? 1'b1 : 1'b0) &
                                 (~next_full));
  end else begin : GEN_NOT_PWR2
    assign next_almost_empty_n = ~((next_word_count <= ae_level)? 1'b1 : 1'b0);
  end
endgenerate


  assign next_almost_full = (next_word_count >= af_thresh)? 1'b1 :
                                next_full;


generate
  if (ERR_MODE == 0) begin : GEN_EM_EQ0
    assign next_rd_addr = ((rd_addr_at_max & advance_rd_addr) || (diag_n==1'b0))?
                            {ADDR_WIDTH{1'b0}} : advanced_rd_addr[ADDR_WIDTH:1];
    assign next_error =  (~pop_req_n & (~empty_n)) | (~push_req_n & pop_req_n & full_int) |
                         (( |(wr_addr_int ^ rd_addr_int)) ^ (empty_n & (~full_int))) | error_int;
  end
  
  if (ERR_MODE == 1) begin : GEN_EM_EQ1
    assign next_rd_addr =  (rd_addr_at_max & advance_rd_addr)?
                            {ADDR_WIDTH{1'b0}} : advanced_rd_addr[ADDR_WIDTH:1];
    assign next_error = (~pop_req_n & (~empty_n)) | (~push_req_n & pop_req_n & full_int) | error_int;
  end
  
  if (ERR_MODE == 2) begin : GEN_EM_EQ2
    assign next_rd_addr =  (rd_addr_at_max & advance_rd_addr)?
                            {ADDR_WIDTH{1'b0}} : advanced_rd_addr[ADDR_WIDTH:1];
    assign next_error = (~pop_req_n & (~empty_n)) | (~push_req_n & pop_req_n & full_int);
  end
endgenerate



  localparam ALL_REG_COUNT = 8+ADDR_WIDTH+ADDR_WIDTH+ADDR_WIDTH;

  DWC_pcie_ctl_bcm95_i
   #(TMR, ALL_REG_COUNT, 0, 0) U_REGS(
                 .clk(clk),
                 .rst_n(rst_n),
                 .init_n(init_n),
                 .d_in({ next_empty_n, next_almost_empty_n, next_half_full,
                         next_almost_full, next_full, next_error, next_rd_addr_at_max,
                         next_wr_addr_at_max, next_wr_addr, next_rd_addr, next_word_count }),
                 .d_out({empty_n, almost_empty_n, half_full_int, almost_full_int,
                          full_int, error_int, rd_addr_at_max, wr_addr_at_max,
                          wr_addr_int, rd_addr_int, word_count })
                 );

  assign empty = ~empty_n;
  assign almost_empty = ~almost_empty_n;
  assign half_full = half_full_int;
  assign almost_full = almost_full_int;
  assign full = full_int;
  assign error = error_int;
  assign wr_addr = wr_addr_int;
  assign rd_addr = rd_addr_int;
  assign wrd_count = word_count;
  assign nxt_empty_n = next_empty_n | (~init_n);
  assign nxt_full    = next_full    &  init_n;
  assign nxt_error   = next_error   &  init_n;

endmodule
