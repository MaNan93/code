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
// ---    $Revision: #7 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_lutMngr.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagMngr_cfg_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crPop_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_lutMngr
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
  ,parameter bool_e P_MULTIMODE = E_FALSE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tagMngr_cfg_if.slave_mp b_cfg
  ,DWC_pcie_edmapf_aclks_if.slave_mp       b_clk
  ,DWC_pcie_edmapf_ram2p_if.master_mp      b_memAccess
  ,DWC_pcie_edmapf_crPop_if.master_mp      b_pop
  ,DWC_pcie_edmapf_ctxPush_if.slave_mp     b_push
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_TAGWD = $clog2(P_MAXTAG+1)                                   ;
  localparam L_TAGPW = $clog2(P_MAXTAG-P_MINTAG+1)                          ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_tagPop_if #(
     .P_TAGWD(L_TAGWD)
                           ) b_DWC_pcie_edmapf_tagPop_if_0 ();
  DWC_pcie_edmapf_tagPush_if #(
     .P_TAGWD(L_TAGWD)
                            )b_DWC_pcie_edmapf_tagPush_if_0();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_lutMngr_hub
   #(
   .P_ADDRESS_WD (L_TAGPW)
  ,.P_MINTAG     (P_MINTAG)
  ,.P_MINTAG_LOW (P_MINTAG_LOW)
  ,.P_MINTAG_VLOW(P_MINTAG_VLOW)
  ,.P_MULTIMODE  (P_MULTIMODE)
  ) u_hub (
   .b_cfg        ( b_cfg                                    )
  ,.b_memAccess  ( b_memAccess                              )
  ,.b_pop        ( b_pop                                    )
  ,.b_push       ( b_push                                   )
  ,.b_ticketPop  ( b_DWC_pcie_edmapf_tagPop_if_0.slave_mp   )
  ,.b_ticketPush ( b_DWC_pcie_edmapf_tagPush_if_0.master_mp )
  );

  DWC_pcie_edmapf_tagMngr
   #(
   .P_MAXTAG     (P_MAXTAG)
  ,.P_MAXTAG_LOW (P_MAXTAG_LOW)
  ,.P_MAXTAG_VLOW(P_MAXTAG_VLOW)
  ,.P_MINTAG     (P_MINTAG)
  ,.P_MINTAG_LOW (P_MINTAG_LOW)
  ,.P_MINTAG_VLOW(P_MINTAG_VLOW)
  ,.P_MULTIMODE  (P_MULTIMODE)
  ,.P_TAGWD      (L_TAGWD)
  ) u_tagMngr (
   .b_cfg        ( b_cfg                                    )
  ,.b_clk        ( b_clk                                    )
  ,.b_pop        ( b_DWC_pcie_edmapf_tagPop_if_0.master_mp  )
  ,.b_push       ( b_DWC_pcie_edmapf_tagPush_if_0.slave_mp  )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
