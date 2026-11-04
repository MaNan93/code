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
// ---    $DateTime: 2024/01/12 11:11:14 $ 
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_sync_hsk.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_sync_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"

module DW_sbc_cdc_sync_hsk
  #(
  parameter P_NSEGS      = 256
 ,parameter P_SEG_DP     = 17
 ,parameter P_SEG_DP_AW  = $clog2(P_SEG_DP)
 ,parameter P_SEG_AW     = $clog2(P_NSEGS)
 ,parameter P_PUSH2POP   = 0
 ,parameter LP_CTR_W     = 6
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

  logic src_clk  ;
  logic src_rst_n;

  logic dst_clk  ;
  logic dst_rst_n;

  assign b_out_w_active_last     = 1'b0;
  assign b_out_w_seg_active_last = {P_SEG_AW{1'b0}};

  // SMD: A signal or variable is set but never read  
  // SJ:  this synchroniser does not use these signals
  // spyglass disable_block W528
  logic                 s_active_last_unc    ;
  logic [P_SEG_AW-1 :0] s_seg_active_last_unc;

  assign s_active_last_unc     = b_in_w_active_last    ;
  assign s_seg_active_last_unc = b_in_w_seg_active_last;
  // spyglass enable_block W528

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

  localparam LP_DATA_WD = P_NSEGS * (P_SEG_DP_AW + 1);
  localparam LP_ACK_DELAY = 1;
  logic r_sent;
  logic s_send;
  logic w_ack;

  assign s_send = (~r_sent) || w_ack;

  always_ff @(posedge src_clk, negedge src_rst_n) begin
    if(!src_rst_n)
      r_sent <= #`TP 1'b0;
    else
      r_sent <= #`TP (s_send || r_sent);
  end

  DWC_pcie_ctl_bcm25
   
  #(
    .WIDTH      (LP_DATA_WD  )
   ,.PEND_MODE  (1           ) /* buffer pending data                 */
   ,.SEND_MODE  (1           ) /* rising edge to invoke data transfer */
   ,.ACK_DELAY  (LP_ACK_DELAY)
   ,.F_SYNC_TYPE(P_SYNC_DP_FW)
   ,.R_SYNC_TYPE(P_SYNC_DP_BW)
  ) u_hsk_sync (
    .clk_s       (src_clk        )
   ,.rst_s_n     (src_rst_n      )
   ,.init_s_n    (1'b1           )
   ,.send_s      (s_send         )
   ,.data_s      (b_in_w_counter )
   // SMD: Output port to an instance is not connected
   // SJ:  These BCM ports are not used.
   // spyglass disable_block W287b
   ,.empty_s     ( /* NC */      )
   ,.full_s      ( /* NC */      )
   // spyglass enable_block W287b
   ,.done_s      (w_ack          )

   ,.clk_d       (dst_clk        )
   ,.rst_d_n     (dst_rst_n      )
   ,.init_d_n    (1'b1           )
   // SMD: Output port to an instance is not connected
   // SJ:  These BCM ports are not used.
   // spyglass disable_block W287b
   ,.data_avail_d( /* NC */      )
   // spyglass enable_block W287b
   ,.data_d      (b_out_w_counter)
  );

endmodule
