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
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_push_tap.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_push_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_push_ctl_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_sync_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_push_tap
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_SEG_AW = 6
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp       b_clk
  ,DW_sbc_cdc_sync_if.slave_mp      b_pop_sync_remote
  ,DW_sbc_cdc_push_if.slave_mp      b_push
  ,DW_sbc_cdc_push_ctl_if.master_mp b_push_ctl
  ,DW_sbc_cdc_sync_if.master_mp     b_push_sync_local
  );


// SNPS_SysML_CODE_START
  logic s_push_active_last;
  logic r_push_active_last;
  logic [P_SEG_AW-1:0] r_seg_active_last;

  // SMD: A signal or variable is set but never read
  // SJ:  local blocks do not read remote active_last data
  // spyglass disable_block W528
  logic                 s_remote_active_last_unc    ;
  logic [P_SEG_AW-1 :0] s_remote_seg_active_last_unc;

  assign s_remote_active_last_unc     = b_pop_sync_remote.w_active_last    ;
  assign s_remote_seg_active_last_unc = b_pop_sync_remote.w_seg_active_last;
  // spyglass enable_block W528

  assign s_push_active_last = pushUpdateCounter(b_push.w_push);

  always_ff @(posedge b_clk.w_push_clk, negedge b_clk.w_push_rst_n) begin
    if(!b_clk.w_push_rst_n)
      r_push_active_last <= #`TP 1'b0;
    else
      r_push_active_last <= #`TP s_push_active_last;
  end

  always_ff @(posedge b_clk.w_push_clk, negedge b_clk.w_push_rst_n) begin
    if(!b_clk.w_push_rst_n)
      r_seg_active_last <= #`TP '0;
    else
      r_seg_active_last <= #`TP b_push.w_push_seg;
  end

  assign b_push_ctl.w_push            = b_push.w_push;
  assign b_push_ctl.w_push_seg        = b_push.w_push_seg;
  assign b_push_ctl.w_push_data       = b_push.w_push_data;
  assign b_push_ctl.w_pop_ctr_remote  = b_pop_sync_remote.w_counter;

  assign b_push_sync_local.w_counter         = b_push_ctl.w_push_ctr_local;
  assign b_push_sync_local.w_active_last     = r_push_active_last;
  assign b_push_sync_local.w_seg_active_last = r_seg_active_last;
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_push_tap
