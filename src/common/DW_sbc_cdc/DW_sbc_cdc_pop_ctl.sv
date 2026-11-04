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
// ---    $DateTime: 2022/05/05 01:39:57 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_pop_ctl.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/ramRd_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_pop_ctl_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_e_info_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_pop_ctl
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       LP_CTR_W = 5
  ,parameter P_EFLAGS_EARLY = 0
  ,parameter   P_HOLD_RADDR = 1
  ,parameter        P_NSEGS = 4
  ,parameter       P_RAM_AW = 6
  ,parameter  P_RAM_LATENCY = 1
  ,parameter        P_RAM_W = 64
  ,parameter       P_SEG_AW = 5
  ,parameter       P_SEG_DP = 16
  ,parameter    P_RAM_REGIN = 1
  ,parameter bool_e P_SVA_MAY_POP_EMPTY = E_FALSE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp      b_clk
  ,DW_sbc_cdc_e_info_if.master_mp  b_einfo
  ,DW_sbc_cdc_pop_ctl_if.master_mp b_pop_ctl
  ,ramRd_if.slave_mp               b_ramr
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DW_sbc_cdc_counters_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
                        )b_DW_sbc_cdc_counters_if_0();

  ramRd_if    #(.P_RAM_AW(P_RAM_AW),.P_RAM_W(P_RAM_W))            b_ramr_early            ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DW_sbc_cdc_e_ae_calc
   #(
   .LP_CTR_W      (LP_CTR_W)
  ,.P_EFLAGS_EARLY(P_EFLAGS_EARLY)
  ,.P_NSEGS       (P_NSEGS)
  ,.P_SEG_DP      (P_SEG_DP)
  ,.P_SVA_MAY_POP_EMPTY(P_SVA_MAY_POP_EMPTY)
  ) u_e_ae_calc (
   .b_clk      ( b_clk                                )
  ,.b_counters ( b_DW_sbc_cdc_counters_if_0.slave_mp  )
  ,.b_einfo    ( b_einfo                              )
  );

  DW_sbc_cdc_pop_ram_ctl
   #(
   .LP_CTR_W     (LP_CTR_W)
  ,.P_HOLD_RADDR (P_HOLD_RADDR)
  ,.P_NSEGS      (P_NSEGS)
  ,.P_RAM_AW     (P_RAM_AW)
  ,.P_RAM_LATENCY(P_RAM_LATENCY+2)
  ,.P_RAM_W      (P_RAM_W)
  ,.P_SEG_AW     (P_SEG_AW)
  ,.P_SEG_DP     (P_SEG_DP)
  ) u_pop_ram_ctl (
   .b_clk      ( b_clk                                )
  ,.b_counters ( b_DW_sbc_cdc_counters_if_0.master_mp )
  ,.b_pop_ctl  ( b_pop_ctl                            )
  ,.b_ramr     ( b_ramr_early.slave_mp              )
  );

// SNPS_SysML_CODE_START

  /* Pipeline for RAM read interface */
  logic [P_RAM_AW -1:0] r_raddr;
  logic [P_RAM_W  -1:0] r_rdata;
  logic                 r_ren_n;

  /* Register ram_ctl to ram         */
  generate
  if(P_RAM_REGIN) begin : GEN_RAM_REGIN_ENADDR
    always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin
      if(!b_clk.w_pop_rst_n) begin
        r_ren_n <= #`TP                 1'b1;
        r_raddr <= #`TP                   '0;
      end else begin
        r_ren_n <= #`TP b_ramr_early.w_ren_n;
        r_raddr <= #`TP b_ramr_early.w_raddr;
      end
    end
  end else begin : GEN_RAM_NO_REGIN_ENADDR
    assign r_ren_n = b_ramr_early.w_ren_n;
    assign r_raddr = b_ramr_early.w_raddr;
  end
  endgenerate

  /* Register ram to ram_ctl         */
  generate
  if(P_RAM_REGIN) begin : GEN_RAM_REGIN_DATA
    always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin
      if(!b_clk.w_pop_rst_n)
        r_rdata <= #`TP             '0;
      else
        r_rdata <= #`TP b_ramr.w_rdata;
    end
  end else begin : GEN_NO_RAM_REGIN
    assign r_rdata = b_ramr.w_rdata;
  end
  endgenerate

  assign b_ramr.w_raddr       = r_raddr;
  assign b_ramr.w_ren_n       = r_ren_n;
  assign b_ramr_early.w_rdata = r_rdata;
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_pop_ctl
