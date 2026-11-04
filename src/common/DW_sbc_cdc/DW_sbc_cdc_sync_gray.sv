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
// ---    $Revision: #4 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_sync_gray.sv#4 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_sync_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"

module DW_sbc_cdc_sync_gray
  import DW_sbc_cdc_pkg::*;
  #(
  parameter P_NSEGS = 256
 ,parameter P_SEG_DP = 17
 ,parameter P_SEG_DP_AW = $clog2(P_SEG_DP)
 ,parameter P_SEG_AW = $clog2(P_NSEGS)
 ,parameter P_PUSH2POP = 0
 ,parameter LP_CTR_W = 6
 ,parameter P_SYNC_DP = 2
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

  localparam LP_DATA_WD = (P_SEG_DP_AW + 1);

  logic [P_NSEGS-1:0] [P_SEG_DP_AW:0] s_local_ctr_at_local_g; // Local counter, gray coded
  logic [P_NSEGS-1:0] [P_SEG_DP_AW:0] r_local_ctr_at_local_g; // Local counter, gray coded, registered
  logic [P_NSEGS-1:0] [P_SEG_DP_AW:0] s_local_ctr_at_rmote_g; // Remote counter, gray coded
  logic [P_NSEGS-1:0] [P_SEG_DP_AW:0] s_local_ctr_at_rmote  ; // Remote counter, binary

  always_ff @(posedge src_clk, negedge src_rst_n) begin
    if(!src_rst_n)
      r_local_ctr_at_local_g <= #`TP '0;
    else
      r_local_ctr_at_local_g <= #`TP s_local_ctr_at_local_g;
  end

  generate genvar i;
  for (i = 0; i < P_NSEGS; i++) begin : GEN_GRAY_CDC_FUNDAMENTAL_SYNCS
    DWC_pcie_ctl_bcm21
     
    #(
      .WIDTH      (LP_DATA_WD)
     ,.F_SYNC_TYPE(P_SYNC_DP )
     ,.SVA_TYPE   (2         ) /* gray code sva */
    ) u_gray_sync (
      .clk_d   (dst_clk                  )
     ,.rst_d_n (dst_rst_n                )
     ,.data_s  (r_local_ctr_at_local_g[i])
     ,.data_d  (s_local_ctr_at_rmote_g[i])
    );
  end
  endgenerate

  function automatic [LP_DATA_WD-1:0] func_bin2gray ;
    input [LP_DATA_WD-1:0]             f_b;    // input
    begin 
      func_bin2gray  = f_b ^ ( f_b >> 1 ); 
    end
  endfunction

  generate
  for(i = 0; i < P_NSEGS; i++) begin : GEN_GRAY_ENCODERS
    assign s_local_ctr_at_local_g[i] = func_bin2gray ( b_in_w_counter[i] );
  end
  endgenerate

// spyglass disable_block Ac_conv01
// SMD: Checks sequential convergence of same-domain signals synchronized in the same destination domain
// SJ: The bus being synchronized and then decoded (i.e. other_addr_decoded), is a Gray transition coded bus and is therefore safe to be followed by converging logic.
// spyglass disable_block Ac_conv02
// SMD: Checks combinational convergence of same-domain signals synchronized in the same destination domain
// SJ: The bus being synchronized and then decoded (i.e. other_addr_decoded), is a Gray transition coded bus and is therefore safe to be followed by converging logic.
  // Gray Code decoder
  function automatic [LP_DATA_WD-1:0] func_gray2bin ;
    input [LP_DATA_WD-1:0]             f_g;    // input
    reg   [LP_DATA_WD-1:0]             f_b;
    integer                     f_i;
    begin 
      f_b = {LP_DATA_WD{1'b0}};
      for (f_i=LP_DATA_WD-1 ; f_i >= 0 ; f_i=f_i-1) begin
        if (f_i < LP_DATA_WD-1)
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
          f_b[f_i] = f_g[f_i] ^ f_b[f_i+1];
// spyglass enable_block SelfDeterminedExpr-ML
        else
          f_b[f_i] = f_g[f_i];
      end 
      func_gray2bin  = f_b; 
    end
  endfunction
// spyglass enable_block Ac_conv01
// spyglass enable_block Ac_conv02
  
  generate
  for(i = 0; i < P_NSEGS; i++) begin : GEN_GRAY_DECODERS
    assign s_local_ctr_at_rmote[i] = func_gray2bin(s_local_ctr_at_rmote_g[i]);
  end
  endgenerate

  assign b_out_w_counter = s_local_ctr_at_rmote;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DW_sbc_cdc_sync_gray
