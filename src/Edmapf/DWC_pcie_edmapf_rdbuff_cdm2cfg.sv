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
// ---    $DateTime: 2022/04/14 09:36:50 $ 
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rdbuff_cdm2cfg.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagMngr_cfg_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_rdbuff_cdm2cfg
  import DWC_pcie_edmapf_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp      b_cdm
  ,DWC_pcie_edmapf_tagMngr_cfg_if.master_mp b_cfg
  ,DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  );


// SNPS_SysML_CODE_START
  struct packed {
    logic tagExt_en;
    logic tag10bit_en;
  } r, s;

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin 
      r <= #`TP '{tagExt_en: 1'b0, tag10bit_en: 1'b0};
    end else begin
      r <= #`TP s;
    end
  end

  always_comb begin : s_PROC
    s.tagExt_en   = b_cdm.w_cfg_ext_tag_en;
    s.tag10bit_en = b_cdm.w_cfg_10b_tag_en;
  end

  assign b_cfg.w_update_p = |(r ^ s);

  always_comb begin : mode_PROC
    if (!s.tag10bit_en) begin
      if (s.tagExt_en) begin
        b_cfg.w_mode = E_TAGMNGR_LOW;
      end else begin
        b_cfg.w_mode = E_TAGMNGR_VLOW;
      end
    end else begin
      b_cfg.w_mode = E_TAGMNGR_NORMAL;
    end
  end

// SNPS_SysML_CODE_END

endmodule
