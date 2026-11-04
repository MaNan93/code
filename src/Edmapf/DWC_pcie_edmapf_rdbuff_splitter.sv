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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #8 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rdbuff_splitter.sv#8 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_rdbuff_splitter
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_TAGWD = 10
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_ctxPush_if.master_mp b_cloakroom
  ,DWC_pcie_edmapf_rvData_if.master_mp  b_core
  ,DWC_pcie_edmapf_ctxPush_if.slave_mp  b_in
  );


// SNPS_SysML_CODE_START

  assign b_cloakroom.w_data = b_in.w_data.tag;
  assign b_cloakroom.w_push = b_in.w_push;

  assign b_in.w_full    = !b_core.w_ready || b_cloakroom.w_full; //Keep full while segmented buffer is not initialized
  assign b_in.w_tag     = (P_TAGWD)'(b_cloakroom.w_tag);
  assign b_in.w_tagBase = (P_TAGWD)'(b_cloakroom.w_tag);

  assign b_core.w_valid = b_in.w_push;
  assign b_core.w_data = '{
     channel: b_in.w_data.channel
    ,pcieTag: b_cloakroom.w_tag
    ,segment: b_cloakroom.w_tagBase
  };

// SNPS_SysML_CODE_END

endmodule
