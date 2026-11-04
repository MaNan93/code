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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_push_ctl.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_f_info_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_push_ctl_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/ramWr_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_push_ctl
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       LP_CTR_W = 5
  ,parameter P_FFLAGS_EARLY = 0
  ,parameter        P_NSEGS = 4
  ,parameter       P_RAM_AW = 6
  ,parameter        P_RAM_W = 64
  ,parameter       P_SEG_DP = 16
  ,parameter   P_RAM_REGOUT = 1
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp      b_clk
  ,DW_sbc_cdc_f_info_if.master_mp  b_finfo
  ,DW_sbc_cdc_push_ctl_if.slave_mp b_push_ctl
  ,ramWr_if.master_mp              b_ramw
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DW_sbc_cdc_counters_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
                        )b_DW_sbc_cdc_counters_if_0();

  ramWr_if     #(.P_RAM_AW(P_RAM_AW),.P_RAM_W(P_RAM_W))           b_ramw_early            ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DW_sbc_cdc_f_af_calc
   #(
   .LP_CTR_W      (LP_CTR_W)
  ,.P_FFLAGS_EARLY(P_FFLAGS_EARLY)
  ,.P_NSEGS       (P_NSEGS)
  ,.P_SEG_DP      (P_SEG_DP)
  ) u_f_af_calc (
   .b_clk      ( b_clk                                )
  ,.b_counters ( b_DW_sbc_cdc_counters_if_0.slave_mp  )
  ,.b_finfo    ( b_finfo                              )
  );

  DW_sbc_cdc_push_ram_ctl
   #(
   .LP_CTR_W(LP_CTR_W)
  ,.P_NSEGS (P_NSEGS)
  ,.P_RAM_AW(P_RAM_AW)
  ,.P_RAM_W (P_RAM_W)
  ,.P_SEG_DP(P_SEG_DP)
  ) u_push_ram_ctl (
   .b_clk      ( b_clk                                )
  ,.b_counters ( b_DW_sbc_cdc_counters_if_0.master_mp )
  ,.b_push_ctl ( b_push_ctl                           )
  ,.b_ramw     ( b_ramw_early.master_mp             )
  );

// SNPS_SysML_CODE_START
  /* Pipeline for RAM interface */
  generate
  if(P_RAM_REGOUT == 1) begin : GEN_RAM_REGOUT
    logic [P_RAM_AW -1:0] r_waddr;
    logic [P_RAM_W  -1:0] r_wdata;
    logic                 r_wen_n;

    always_ff @(posedge b_clk.w_push_clk, negedge b_clk.w_push_rst_n) begin
      if(!b_clk.w_push_rst_n) begin
        r_waddr <= #`TP                   '0;
        r_wdata <= #`TP                   '0;
        r_wen_n <= #`TP                 1'b1;
      end else begin
        r_waddr <= #`TP b_ramw_early.w_waddr;
        r_wdata <= #`TP b_ramw_early.w_wdata;
        r_wen_n <= #`TP b_ramw_early.w_wen_n;
      end
    end

    assign b_ramw.w_waddr = r_waddr;
    assign b_ramw.w_wdata = r_wdata;
    assign b_ramw.w_wen_n = r_wen_n;
  end else begin : GEN_NO_RAM_REGOUT
    assign b_ramw.w_waddr = b_ramw_early.w_waddr;
    assign b_ramw.w_wdata = b_ramw_early.w_wdata;
    assign b_ramw.w_wen_n = b_ramw_early.w_wen_n;
  end
  endgenerate
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_push_ctl
