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
// ---    $DateTime: 2023/06/30 15:54:26 $ 
// ---    $Revision: #4 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_pop_ram_ctl.sv#4 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/ramRd_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_counters_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_pop_ctl_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_pop_ram_ctl
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter      LP_CTR_W = 5
  ,parameter  P_HOLD_RADDR = 1
  ,parameter       P_NSEGS = 4
  ,parameter      P_RAM_AW = 6
  ,parameter P_RAM_LATENCY = 1
  ,parameter       P_RAM_W = 64
  ,parameter      P_SEG_AW = 5
  ,parameter      P_SEG_DP = 16
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp       b_clk
  ,DW_sbc_cdc_counters_if.master_mp b_counters
  ,DW_sbc_cdc_pop_ctl_if.master_mp  b_pop_ctl
  ,ramRd_if.slave_mp                b_ramr
  );


// SNPS_SysML_CODE_START

  localparam LP_RAM_LATENCY_W = $clog2(P_RAM_LATENCY+1)              ;

  // Strip extraneous MSB 0s on array indexing
  localparam LP_PSWD          = (P_NSEGS == 1) ? 1 : $clog2(P_NSEGS) ;

  /***************************************************************************/

  integer i;
  logic [P_NSEGS-1:0]                     s_seg_move_ctr       ;
  logic [P_NSEGS-1:0] [LP_CTR_W     -1:0] s_next_rdctrs        ;
  logic [P_NSEGS-1:0] [LP_CTR_W     -1:0] s_next_rdctrs_nxt    ;
  logic               [P_RAM_AW     -1:0] s_ram_raddr_early    ;
  logic               [P_RAM_AW   +1-1:0] s_ram_raddr_early_big;
  logic               [P_RAM_AW     -1:0] s_ram_raddr          ;
  logic [P_NSEGS-1:0] [P_RAM_AW     -1:0] s_ram_start          ;

  logic               [P_RAM_LATENCY-1:0] r_datav_shift        ;
  logic [P_NSEGS-1:0] [LP_CTR_W     -1:0] r_rdctrs             ;
  logic               [P_RAM_AW     -1:0] r_ram_raddr_last     ;
  /***************************************************************************/

  assign b_counters.w_pop_ctr        =           s_next_rdctrs                 ;
  assign b_counters.w_pop_ctr_nxt    =           s_next_rdctrs_nxt             ;
  assign b_counters.w_push_ctr       = b_pop_ctl.w_push_ctr_remote             ;
  assign b_counters.w_push_ctr_nxt   =           '0                            ; /* unc */

  assign  b_pop_ctl.w_pop_ctr_local  =           r_rdctrs                      ;
  assign  b_pop_ctl.w_pop_data_d     =    b_ramr.w_rdata                       ;
  assign  b_pop_ctl.w_pop_data_valid =           r_datav_shift[P_RAM_LATENCY-1];

  assign     b_ramr.w_raddr          =           s_ram_raddr                   ;
  assign     b_ramr.w_ren_n          =           ~(popActive(b_pop_ctl.w_pop)) ;
  /***************************************************************************/

  always_comb begin: w_pop_ctr_nxt_PROC
    foreach(s_next_rdctrs_nxt[i])
      s_next_rdctrs_nxt[i] = s_seg_move_ctr[i] ? ctrMove2(r_rdctrs[i]) : ctrMove(r_rdctrs[i]);
  end : w_pop_ctr_nxt_PROC

  always_comb begin: s_seg_move_ctr_PROC
    foreach(s_seg_move_ctr[i]) begin
      s_seg_move_ctr[i] = popActiveMovePtr(b_pop_ctl.w_pop) && (b_pop_ctl.w_pop_seg == i);
    end
  end : s_seg_move_ctr_PROC

  always_comb begin : s_next_rdctrs_PROC
    foreach(s_next_rdctrs[i]) begin
      s_next_rdctrs[i] = s_seg_move_ctr[i] ? ctrMove(r_rdctrs[i]) : r_rdctrs[i];
    end
  end : s_next_rdctrs_PROC

  always_comb begin : s_ram_start_PROC
    foreach(s_ram_start[i]) begin
      s_ram_start[i] = (i * P_SEG_DP);
    end
  end : s_ram_start_PROC

  always_comb begin : s_ram_raddr_early_PROC
// spyglass disable_block W164b
// SMD: Identifies assignments in which the LHS WIDTH is greater than the RHS WIDTH
// SJ: In most cases, the expressions in the code are written such that the LHS result is one bit larger than the RHS operands (or they should be at the very least). This is the most conservative approach in having one more bit on the left-hand side (LHS) than the two operands of an expression on the right-hand side (RHS).
    s_ram_raddr_early_big = s_ram_start[b_pop_ctl.w_pop_seg[LP_PSWD-1:0]] + r_rdctrs[b_pop_ctl.w_pop_seg[LP_PSWD-1:0]][LP_CTR_W-2:0];
// spyglass enable_block W164b
    s_ram_raddr_early     = s_ram_raddr_early_big[P_RAM_AW-1:0];
  end : s_ram_raddr_early_PROC

  generate 
    if(P_HOLD_RADDR == 1) begin : RADDR_HELD_GEN
        assign s_ram_raddr = popActive(b_pop_ctl.w_pop) ? s_ram_raddr_early : r_ram_raddr_last;
    end else begin : RADDR_N_HELD_GEN
        assign s_ram_raddr = s_ram_raddr_early;
    end
  endgenerate
  /***************************************************************************/

  always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin : r_rdctrs_PROC
    if(!b_clk.w_pop_rst_n) begin
        r_rdctrs <= #`TP '0;
    end else begin
      foreach(r_rdctrs[i]) 
        r_rdctrs[i] <= #`TP s_next_rdctrs[i];
    end
  end : r_rdctrs_PROC


  always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin : r_datav_shift_PROC
    if(!b_clk.w_pop_rst_n)
      r_datav_shift <= #`TP '0;
    else begin
      r_datav_shift <= #`TP {r_datav_shift[P_RAM_LATENCY-2:0], popActive(b_pop_ctl.w_pop)};
    end
  end : r_datav_shift_PROC

  generate 
  if(P_HOLD_RADDR == 1) begin : GEN_LAST_RADDR_REG
  always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin : r_ram_raddr_last_PROC
    if(!b_clk.w_pop_rst_n)
      r_ram_raddr_last <= #`TP '0;
    else
      r_ram_raddr_last <= #`TP s_ram_raddr;
    end : r_ram_raddr_last_PROC
  end
  endgenerate
  /***************************************************************************/

  /* ctrMove(): move counter up 1 position
   * clip the wraparoud bit and compare with segment depth. if segment end reached, flip bit and go to seg start, else add 1
   */
  function automatic logic [LP_CTR_W-1:0] ctrMove(input logic [LP_CTR_W-1:0] ctr);
    ctrMove = (ctr[LP_CTR_W-2:0] == (LP_CTR_W-1)'(P_SEG_DP-1)) ? (LP_CTR_W)'({~ctr[LP_CTR_W-1], {LP_CTR_W-1{1'b0}}}) : (LP_CTR_W)'(ctr + 1'b1);
  endfunction

  /* ctrMove2(): move counter up 2 positions
   */
  function automatic logic [LP_CTR_W-1:0] ctrMove2(input logic [LP_CTR_W-1:0] ctr);
    if(ctr[LP_CTR_W-2:0] == (LP_CTR_W-1)'(P_SEG_DP-2))
      ctrMove2 = (LP_CTR_W)'({~ctr[LP_CTR_W-1], {LP_CTR_W-1{1'b0}}});
    else if(ctr[LP_CTR_W-2:0] == (LP_CTR_W-1)'(P_SEG_DP-1))
      ctrMove2 = (LP_CTR_W)'({~ctr[LP_CTR_W-1], {LP_CTR_W-2{1'b0}}, 1'b1});
    else
      ctrMove2 = (LP_CTR_W)'(ctr + 2'b10);
  endfunction
  /***************************************************************************/

  `ifndef SYNTHESIS
  `endif // SYNTHESIS
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_pop_ram_ctl
