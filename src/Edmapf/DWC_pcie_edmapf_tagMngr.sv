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
// ---    $Revision: #12 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tagMngr.sv#12 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagMngr_cfg_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagPop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagPush_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_tagMngr
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter           P_MAXTAG = 1023
  ,parameter       P_MAXTAG_LOW = P_MAXTAG/2
  ,parameter      P_MAXTAG_VLOW = P_MAXTAG_LOW/2
  ,parameter           P_MINTAG = 0
  ,parameter       P_MINTAG_LOW = P_MINTAG
  ,parameter      P_MINTAG_VLOW = P_MINTAG_LOW
  ,parameter            P_TAGWD = 10
  ,parameter bool_e P_MULTIMODE = E_FALSE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tagMngr_cfg_if.slave_mp b_cfg
  ,DWC_pcie_edmapf_aclks_if.slave_mp       b_clk
  ,DWC_pcie_edmapf_tagPop_if.master_mp     b_pop
  ,DWC_pcie_edmapf_tagPush_if.slave_mp     b_push
  );


// SNPS_SysML_CODE_START

  localparam L_MAXTAG_LOW  = (P_MULTIMODE == E_FALSE) ? P_MAXTAG : P_MAXTAG_LOW;
  localparam L_MAXTAG_VLOW = (P_MULTIMODE == E_FALSE) ? P_MAXTAG : P_MAXTAG_VLOW;
  localparam L_MINTAG_LOW  = (P_MULTIMODE == E_FALSE) ? P_MINTAG : P_MINTAG_LOW;
  localparam L_MINTAG_VLOW = (P_MULTIMODE == E_FALSE) ? P_MINTAG : P_MINTAG_VLOW;

  DWC_pcie_tagMngr
   #(
   .P_MAXTAG      ( P_MAXTAG      )
  ,.P_MAXTAG_LOW  ( L_MAXTAG_LOW  )
  ,.P_MAXTAG_VLOW ( L_MAXTAG_VLOW )
  ,.P_MINTAG      ( P_MINTAG      )
  ,.P_MINTAG_LOW  ( L_MINTAG_LOW  )
  ,.P_MINTAG_VLOW ( L_MINTAG_VLOW )
  ,.P_TAGWD       ( P_TAGWD       )
  ) u_mgr (
   .clk           ( b_clk.w_main_clk )
  ,.rst_n         ( b_clk.w_reset_n  )

  ,.mode          ( b_cfg.w_mode     )
  ,.update_p      ( b_cfg.w_update_p )

  ,.pop_en        ( b_pop.w_pop      )
  ,.pop_tag       ( b_pop.w_tag      )
  ,.pop_tag_info  ( /* NC */         )
  ,.pop_empty     ( b_pop.w_empty    )

  ,.push_en       ( b_push.w_push    )
  ,.push_tag      ( b_push.w_tag     )
  ,.push_tag_info ( '0               )
  );

  assign b_pop.w_tagBase = (b_cfg.w_mode == E_TAGMNGR_NORMAL) ? b_pop.w_tag - P_MINTAG      :
                           (b_cfg.w_mode == E_TAGMNGR_VLOW  ) ? b_pop.w_tag - P_MINTAG_VLOW :
                                                                b_pop.w_tag - P_MINTAG_LOW   ;

// SNPS_SysML_CODE_END

endmodule
