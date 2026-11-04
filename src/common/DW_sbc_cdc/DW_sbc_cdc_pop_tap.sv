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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_pop_tap.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_pop_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_pop_ctl_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_sync_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_pop_tap
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
   DW_sbc_cdc_clk_if.slave_mp     b_clk
  ,DW_sbc_cdc_pop_if.master_mp    b_pop
  ,DW_sbc_cdc_pop_ctl_if.slave_mp b_pop_ctl
  ,DW_sbc_cdc_sync_if.master_mp   b_pop_sync_local
  ,DW_sbc_cdc_sync_if.slave_mp    b_push_sync_remote
  );


// SNPS_SysML_CODE_START
  logic s_pop_active_last;
  logic r_pop_active_last;
  logic [P_SEG_AW-1:0] r_seg_active_last;

  // SMD: A signal or variable is set but never read
  // SJ:  local blocks do not read remote active_last data
  // spyglass disable_block W528
  logic                 s_remote_active_last_unc    ;
  logic [P_SEG_AW-1 :0] s_remote_seg_active_last_unc;

  assign s_remote_active_last_unc     = b_push_sync_remote.w_active_last    ;
  assign s_remote_seg_active_last_unc = b_push_sync_remote.w_seg_active_last;
  // spyglass enable_block W528

  assign s_pop_active_last = popActiveMovePtr(b_pop.w_pop);

  always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin
    if(!b_clk.w_pop_rst_n)
      r_pop_active_last <= #`TP 1'b0;
    else
      r_pop_active_last <= #`TP s_pop_active_last;
  end

  always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin
    if(!b_clk.w_pop_rst_n)
      r_seg_active_last <= #`TP '0;
    else
      r_seg_active_last <= #`TP b_pop.w_pop_seg;
  end

  assign b_pop_ctl.w_pop             = b_pop.w_pop;
  assign b_pop_ctl.w_pop_seg         = b_pop.w_pop_seg;
  assign b_pop_ctl.w_push_ctr_remote = b_push_sync_remote.w_counter;

  assign b_pop_sync_local.w_counter         = b_pop_ctl.w_pop_ctr_local;
  assign b_pop_sync_local.w_active_last     = r_pop_active_last;
  assign b_pop_sync_local.w_seg_active_last = r_seg_active_last;

  assign b_pop.w_pop_data_d     = b_pop_ctl.w_pop_data_d;
  assign b_pop.w_pop_data_valid = b_pop_ctl.w_pop_data_valid;
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_pop_tap
