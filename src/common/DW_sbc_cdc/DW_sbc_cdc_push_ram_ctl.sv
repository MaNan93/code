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
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_push_ram_ctl.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_counters_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_push_ctl_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/ramWr_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_push_ram_ctl
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter LP_CTR_W = 5
  ,parameter  P_NSEGS = 4
  ,parameter P_RAM_AW = 6
  ,parameter  P_RAM_W = 64
  ,parameter P_SEG_DP = 16
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp       b_clk
  ,DW_sbc_cdc_counters_if.master_mp b_counters
  ,DW_sbc_cdc_push_ctl_if.slave_mp  b_push_ctl
  ,ramWr_if.master_mp               b_ramw
  );


// SNPS_SysML_CODE_START
  // Strip extraneous 0 MSBs on array indexing
  localparam LP_PSWD = (P_NSEGS == 1) ? 1 : $clog2(P_NSEGS);

  integer i;
  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] s_next_wrctrs_working;
  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] s_fast_next_wrctrs_working;
  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] s_fast_next_wrctrs_working_nxt;
  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] s_next_wrctrs        ;
  logic                [P_RAM_AW +1-1:0] s_ram_waddr_big      ;
  logic                [P_RAM_AW   -1:0] s_ram_waddr          ;
  logic [P_NSEGS -1:0] [P_RAM_AW   -1:0] s_ram_start          ;

  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] r_wrctrs             ;
  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] r_wrctrs_working     ;
  logic [P_NSEGS -1:0] [LP_CTR_W   -1:0] s_wrctrs_working_eff ;
  /***************************************************************************/

  assign b_push_ctl.w_push_ctr_local = r_wrctrs                   ;

  assign b_counters.w_push_ctr       = s_fast_next_wrctrs_working ;
  assign b_counters.w_push_ctr_nxt   = s_fast_next_wrctrs_working_nxt;
  assign b_counters.w_pop_ctr        = b_push_ctl.w_pop_ctr_remote;
  assign b_counters.w_pop_ctr_nxt    = '0                         ; /* unc */

  assign b_ramw.w_wen_n = ~pushActive(b_push_ctl.w_push)          ;
  assign b_ramw.w_waddr = s_ram_waddr                             ;
  assign b_ramw.w_wdata = b_push_ctl.w_push_data                  ;
  /***************************************************************************/

  always_comb begin : s_fast_next_wrctrs_working_PROC
    foreach(s_fast_next_wrctrs_working[i]) begin
      if(i == b_push_ctl.w_push_seg && b_push_ctl.w_push != E_PUSH_IDLE)
        s_fast_next_wrctrs_working[i] = ctrMove(r_wrctrs_working[i]);
      else
        s_fast_next_wrctrs_working[i] = r_wrctrs_working[i];
    end
  end : s_fast_next_wrctrs_working_PROC

  always_comb begin : s_fast_next_wrctrs_working_nxt_PROC
    foreach(s_fast_next_wrctrs_working_nxt[i]) begin
      if(i == b_push_ctl.w_push_seg && b_push_ctl.w_push != E_PUSH_IDLE)
        s_fast_next_wrctrs_working_nxt[i] = ctrMove2(r_wrctrs_working[i]);
      else
        s_fast_next_wrctrs_working_nxt[i] = ctrMove(r_wrctrs_working[i]);
    end
  end : s_fast_next_wrctrs_working_nxt_PROC

  always_comb begin : s_ram_start_PROC
    foreach(s_ram_start[i]) begin
      s_ram_start[i] = (i * P_SEG_DP);
    end
  end : s_ram_start_PROC

  always_comb begin : s_ram_waddr_PROC
// spyglass disable_block W164b
// SMD: Identifies assignments in which the LHS WIDTH is greater than the RHS WIDTH
// SJ: In most cases, the expressions in the code are written such that the LHS result is one bit larger than the RHS operands (or they should be at the very least). This is the most conservative approach in having one more bit on the left-hand side (LHS) than the two operands of an expression on the right-hand side (RHS).
    s_ram_waddr_big = s_ram_start[b_push_ctl.w_push_seg[LP_PSWD-1:0]] + s_wrctrs_working_eff[b_push_ctl.w_push_seg[LP_PSWD-1:0]][LP_CTR_W-2:0];
// spyglass enable_block W164b
    s_ram_waddr     = s_ram_waddr_big[P_RAM_AW-1:0];
  end : s_ram_waddr_PROC

  always_comb begin : s_wrctrs_working_eff_PROC
    foreach(s_wrctrs_working_eff[i])
      s_wrctrs_working_eff[i] = pushTrashUnkept(b_push_ctl.w_push) ? r_wrctrs[i] : r_wrctrs_working[i];
  end : s_wrctrs_working_eff_PROC

  always_comb begin : s_next_wrctrs_working_PROC
    foreach(s_next_wrctrs_working[i]) begin
      // If drop on target segment, drop on all segments
      if(b_push_ctl.w_push inside {E_DROP, E_START, E_DROPSTART, E_DROPSTARTKEEP}) begin
        s_next_wrctrs_working[i] = r_wrctrs[i];
      end

      // Update working pointer for target segment
      if(i == b_push_ctl.w_push_seg) begin
        case (b_push_ctl.w_push)
          E_KEEP,
          E_PUSH: /* these cases push in front of the working wptr */
            s_next_wrctrs_working[i] = ctrMove(r_wrctrs_working[i]);
          E_DROP: /* this case resets to the nonworking wptr without push */
            s_next_wrctrs_working[i] = r_wrctrs[i];
          E_START        ,
          E_DROPSTART    ,
          E_DROPSTARTKEEP: /* these cases push in front of the nonworking wptr */
            s_next_wrctrs_working[i] = ctrMove(r_wrctrs[i]);
          default:
            s_next_wrctrs_working[i] = r_wrctrs_working[i];
        endcase
      end else begin
        s_next_wrctrs_working[i] = r_wrctrs_working[i];
      end
    end
  end : s_next_wrctrs_working_PROC

  always_comb begin : s_next_wrctrs_PROC
    foreach(s_next_wrctrs[i]) begin
      if(i == b_push_ctl.w_push_seg && pushUpdateCounter(b_push_ctl.w_push)) begin
        s_next_wrctrs[i] = s_next_wrctrs_working[i];
      end else if(b_push_ctl.w_push == E_KEEP) begin
        // If keep on target segment, keep on all segments
        s_next_wrctrs[i] = r_wrctrs_working[i];
      end else begin
        s_next_wrctrs[i] = r_wrctrs[i];
      end
    end
  end : s_next_wrctrs_PROC
  /***************************************************************************/

  always_ff @(posedge b_clk.w_push_clk, negedge b_clk.w_push_rst_n) begin : r_wrctrs_working_PROC
    if(!b_clk.w_push_rst_n) begin
        r_wrctrs_working <= #`TP '0;
    end else begin
      foreach(r_wrctrs_working[i])
        r_wrctrs_working[i] <= #`TP s_next_wrctrs_working[i];
    end
  end : r_wrctrs_working_PROC

  always_ff @(posedge b_clk.w_push_clk, negedge b_clk.w_push_rst_n) begin : r_wrctrs_PROC
    if(!b_clk.w_push_rst_n) begin
      foreach(r_wrctrs[i])
        r_wrctrs[i] <= #`TP '0;
    end else begin
      foreach(r_wrctrs[i])
        r_wrctrs[i] <= #`TP s_next_wrctrs[i];
    end
  end : r_wrctrs_PROC
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

endmodule : DW_sbc_cdc_push_ram_ctl
