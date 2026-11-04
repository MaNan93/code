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

// ------------------------------------------------------------------------- 
// ---  RCS information: 
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_sync_fifo.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_sync_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"

module DW_sbc_cdc_sync_fifo
  #(
  parameter P_NSEGS = 256
 ,parameter P_SEG_DP = 18
 ,parameter P_RAM_AW = 13
 ,parameter P_FIFO_DP = 8
 ,parameter P_PUSH2POP = 0
 ,parameter LP_CTR_W = 6
 ,parameter P_SEG_AW = 5
 ,parameter P_SYNC_DP_FW = 2
 ,parameter P_SYNC_DP_BW = 2
  ) (
    input logic                                b_in_w_active_last
  , input logic [P_NSEGS -1:0] [LP_CTR_W -1:0] b_in_w_counter
  , input logic                [P_SEG_AW -1:0] b_in_w_seg_active_last
  ,output logic                                b_out_w_active_last
  ,output logic [P_NSEGS -1:0] [LP_CTR_W -1:0] b_out_w_counter
  ,output logic                [P_SEG_AW -1:0] b_out_w_seg_active_last
  ,DW_sbc_cdc_clk_if.slave_mp                  b_clk
  );

  logic src_clk;
  logic src_rst_n;

  logic dst_clk;
  logic dst_rst_n;

  generate
    if(P_PUSH2POP == 1) begin : GEN_PUSH2POP_CLKS
      assign src_clk   = b_clk.w_push_clk  ;
      assign src_rst_n = b_clk.w_push_rst_n;

      assign dst_clk   = b_clk.w_pop_clk   ;
      assign dst_rst_n = b_clk.w_pop_rst_n ;
    end else begin : GEN_POP2PUSH_CLKS
      assign src_clk   = b_clk.w_pop_clk   ;
      assign src_rst_n = b_clk.w_pop_rst_n ;

      assign dst_clk   = b_clk.w_push_clk  ;
      assign dst_rst_n = b_clk.w_push_rst_n;
    end
  endgenerate

  localparam LP_RAM_DP  = P_NSEGS * P_SEG_DP;  // external RAM depth
  localparam LP_FIFO_AW = $clog2(P_FIFO_DP);   // synchronisation FIFO address width
  localparam LP_DATA_WD = (LP_CTR_W + P_SEG_AW);
  localparam LP_FIFO_CTR_W = LP_FIFO_AW + 1;

  // Dst side final counter register
  logic [P_NSEGS-1:0] [LP_CTR_W -1: 0] r_counter;
  logic [P_NSEGS-1:0] [LP_CTR_W -1: 0] s_counter;

  // Interconnect synchroniser to FIFO data path
  logic [ LP_DATA_WD-1:0] s_data_to_fifo;
  logic [ LP_DATA_WD-1:0] s_data_from_fifo;
  logic [   LP_CTR_W-1:0] s_pop_seg_counter;
  logic [   P_SEG_AW-1:0] s_pop_seg_id;

  // Interconnect synchroniser to FIFO control path
  logic s_push_n;
  logic s_pop_n;
  logic s_full;
  logic s_empty;

  // Interconnect controller to FF memory
  logic w_mem_wen_n;
  logic [LP_FIFO_AW-1:0] w_mem_waddr;
  logic [LP_FIFO_AW-1:0] w_mem_raddr;

  // Pack and unpack FIFO data
  assign s_data_to_fifo = {b_in_w_seg_active_last, b_in_w_counter[b_in_w_seg_active_last]};
  assign {s_pop_seg_id, s_pop_seg_counter} = s_data_from_fifo;

  // Auto push and auto pop
  assign s_pop_n  = s_empty;

  always_comb begin
    if(s_full)
      s_push_n = 1'b1;
    else
      s_push_n = ~b_in_w_active_last;
  end

  // Auto-pop side storage
  assign b_out_w_counter = r_counter;

// SMD: Checks unsynchronized crossing for vector signals
// SJ: A CDC FIFO is synchronising this data path
// spyglass disable_block Ac_unsync02
  always_ff @(posedge dst_clk, negedge dst_rst_n) begin : r_counter_PROC
    if(!dst_rst_n) begin
      foreach(r_counter[i])
        r_counter[i] <= #`TP '0;
    end else begin
      r_counter <= #`TP s_counter;
    end
  end : r_counter_PROC
// spyglass enable_block Ac_unsync02

  always_comb begin : s_counter_PROC
    foreach(s_counter[i]) begin
      if(~s_pop_n && i == s_pop_seg_id)
        s_counter[i] = s_pop_seg_counter;
      else
        s_counter[i] = r_counter[i];
    end
  end : s_counter_PROC

  DWC_pcie_ctl_bcm87
  
  #(
    .DEPTH           (P_FIFO_DP    )
   ,.ADDR_WIDTH      (LP_FIFO_AW   )
   ,.PUSH_SYNC       (P_SYNC_DP_BW )
   ,.POP_SYNC        (P_SYNC_DP_FW )
   ,.COUNT_WIDTH     (LP_FIFO_CTR_W)
   //,.EARLY_PUSH_STAT (2          )
   //,.EARLY_POP_STAT  (1          )
  ) u_sync (
    .clk_push        (src_clk    )
   ,.rst_push_n      (src_rst_n  )
   ,.init_push_n     (1'b1       )
   ,.push_req_n      (s_push_n   )
   // SMD: Output port to an instance is not connected
   // SJ:  These BCM ports are not used.
   // spyglass disable_block W287b
   ,.push_empty      ( /* NC */  )
   ,.push_ae         ( /* NC */  )
   ,.push_hf         ( /* NC */  )
   ,.push_af         ( /* NC */  )
   // spyglass enable_block W287b
   ,.push_full       (s_full     )
   // SMD: Output port to an instance is not connected
   // SJ:  These BCM ports are not used.
   // spyglass disable_block W287b
   ,.push_error      ( /* NC */  )
   ,.push_word_count ( /* NC */  )
   // spyglass enable_block W287b
   ,.we_n            (w_mem_wen_n)
   ,.wr_addr         (w_mem_waddr)

   ,.clk_pop         (dst_clk    )
   ,.rst_pop_n       (dst_rst_n  )
   ,.init_pop_n      (1'b1       )
   ,.pop_req_n       (s_pop_n    )
   ,.pop_empty       (s_empty    )
   // SMD: Output port to an instance is not connected
   // SJ:  These BCM ports are not used.
   // spyglass disable_block W287b
   ,.pop_ae          ( /* NC */  )
   ,.pop_hf          ( /* NC */  )
   ,.pop_af          ( /* NC */  )
   ,.pop_full        ( /* NC */  )
   ,.pop_error       ( /* NC */  )
   ,.pop_word_count  ( /* NC */  )
   // spyglass enable_block W287b
   ,.rd_addr         (w_mem_raddr)
  );

  DWC_pcie_mem_dff
  
  #(
    .WIDTH      (LP_DATA_WD)
   ,.DEPTH      (P_FIFO_DP )
   ,.ADDR_WIDTH (LP_FIFO_AW)
  ) u_dff_mem (
    .clk     (src_clk         )
   ,.rst_n   (src_rst_n       )
   ,.wr_n    (w_mem_wen_n     )
   ,.wr_data (s_data_to_fifo  )
   ,.rd_addr (w_mem_raddr     )
   ,.wr_addr (w_mem_waddr     )
   ,.rd_data (s_data_from_fifo)
  );

`ifndef SYNTHESIS
`endif // SYNTHESIS
endmodule : DW_sbc_cdc_sync_fifo
