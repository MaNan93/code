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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_f_af_calc.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_counters_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_f_info_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_f_af_calc
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       LP_CTR_W = 5
  ,parameter P_FFLAGS_EARLY = 0
  ,parameter        P_NSEGS = 4
  ,parameter       P_SEG_DP = 16
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp      b_clk
  ,DW_sbc_cdc_counters_if.slave_mp b_counters
  ,DW_sbc_cdc_f_info_if.master_mp  b_finfo
  );


// SNPS_SysML_CODE_START
  // SMD: A signal or variable is set but never read
  // SJ:  signal not required by the logic
  // spyglass disable_block W528
  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] s_pop_ctr_nxt_unc;

  assign s_pop_ctr_nxt_unc = b_counters.w_pop_ctr_nxt;
  // spyglass enable_block W528

  logic [P_NSEGS -1:0]                 s_full            ;
  logic [P_NSEGS -1:0]                 s_full_m1         ;

  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] s_pop_ctr    ;
  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] s_psh_ctr    ;
  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] s_psh_ctr_nxt;

  assign s_pop_ctr     = b_counters.w_pop_ctr     ;
  assign s_psh_ctr     = b_counters.w_push_ctr    ;
  assign s_psh_ctr_nxt = b_counters.w_push_ctr_nxt;

  generate
  if(P_FFLAGS_EARLY == 1) begin : GEN_EARLY_FFLAGS
    assign b_finfo.w_full    = s_full;
    assign b_finfo.w_full_m1 = s_full_m1;
  end else begin : GEN_REGISTERED_FFLAGS
    logic [P_NSEGS -1:0] r_full   ;
    logic [P_NSEGS -1:0] r_full_m1;

    always_ff @(posedge b_clk.w_push_clk, negedge b_clk.w_push_rst_n) begin
      if(!b_clk.w_push_rst_n) begin
        r_full    <= #`TP '0;
        r_full_m1 <= #`TP '0;
      end else begin
        r_full    <= #`TP s_full   ;
        r_full_m1 <= #`TP s_full_m1;
      end
    end

    assign b_finfo.w_full    = r_full;
    assign b_finfo.w_full_m1 = r_full_m1;
  end
  endgenerate

  always_comb begin
    /* The segment if full if the ram space ctr msb is different and the remaining bits are equal */
    foreach(s_full[i]) begin
      s_full[i] =    (s_psh_ctr[i][LP_CTR_W-2:0] == s_pop_ctr[i][LP_CTR_W-2:0])
                  && (s_psh_ctr[i][LP_CTR_W-1]   != s_pop_ctr[i][LP_CTR_W-1]  );
    end

    foreach(s_full_m1[i]) begin
      s_full_m1[i] =     (s_psh_ctr_nxt[i][LP_CTR_W-2:0] == s_pop_ctr[i][LP_CTR_W-2:0])
                      && (s_psh_ctr_nxt[i][LP_CTR_W-1]   != s_pop_ctr[i][LP_CTR_W-1]  );
    end
  end

`ifndef SYNTHESIS
`endif // SYNTHESIS
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_f_af_calc
