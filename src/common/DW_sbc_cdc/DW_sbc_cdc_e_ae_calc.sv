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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_e_ae_calc.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_counters_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_e_info_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_e_ae_calc
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       LP_CTR_W = 5
  ,parameter P_EFLAGS_EARLY = 0
  ,parameter        P_NSEGS = 4
  ,parameter       P_SEG_DP = 16
  ,parameter bool_e P_SVA_MAY_POP_EMPTY = E_FALSE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp      b_clk
  ,DW_sbc_cdc_counters_if.slave_mp b_counters
  ,DW_sbc_cdc_e_info_if.master_mp  b_einfo
  );


// SNPS_SysML_CODE_START
  // SMD: A signal or variable is set but never read
  // SJ:  signal not required by the logic
  // spyglass disable_block W528
  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] s_push_ctr_nxt_unc;

  assign s_push_ctr_nxt_unc = b_counters.w_push_ctr_nxt;
  // spyglass enable_block W528

  logic [P_NSEGS -1:0] s_empty;
  logic [P_NSEGS -1:0] s_empty_p1;

  generate
  if(P_EFLAGS_EARLY == 1) begin : GEN_EARLY_EFLAGS
    assign b_einfo.w_empty    = s_empty;
    assign b_einfo.w_empty_p1 = s_empty_p1;
  end else begin : GEN_REGISTERED_EFLAGS
    logic [P_NSEGS -1:0] r_empty   ;
    logic [P_NSEGS -1:0] r_empty_p1;

    always_ff @(posedge b_clk.w_pop_clk, negedge b_clk.w_pop_rst_n) begin
      if(!b_clk.w_pop_rst_n) begin
        r_empty    <= #`TP {P_NSEGS{1'b1}};
        r_empty_p1 <= #`TP '0;
      end else begin
        r_empty    <= #`TP s_empty   ;
        r_empty_p1 <= #`TP s_empty_p1;
      end
    end

    assign b_einfo.w_empty    = r_empty;
    assign b_einfo.w_empty_p1 = r_empty_p1;
  end
  endgenerate

  always_comb begin
    foreach(s_empty[i]) begin
      s_empty[i]    = (b_counters.w_pop_ctr[i]     == b_counters.w_push_ctr[i]);
    end

    foreach(s_empty_p1[i]) begin
      s_empty_p1[i] = (b_counters.w_pop_ctr_nxt[i] == b_counters.w_push_ctr[i]);
    end
  end

`ifndef SYNTHESIS
`endif // SYNTHESIS
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_e_ae_calc
