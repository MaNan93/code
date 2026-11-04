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
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ctx.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagMngr_cfg_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ctx
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_DATATYPE = logic
  ,parameter     P_DAMPER_DP = 5
  ,parameter       P_MAXTAGS = 1024
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tagMngr_cfg_if.slave_mp      b_cfg
  ,DWC_pcie_edmapf_aclks_if.slave_mp            b_clk
  ,DWC_pcie_edmapf_genericData_if.slave_mp      b_glbCtx
  ,DWC_pcie_edmapf_ram2p_if.master_mp           b_memAccess
  ,DWC_pcie_edmapf_ctxPop_haltable_if.master_mp b_pop
  ,DWC_pcie_edmapf_ctxPush_if.slave_mp          b_push
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_crPop_if #(
     .P_DATATYPE(P_DATATYPE)
    ,.P_TAGWD   ($clog2(P_MAXTAGS))
                          )          b_DWC_pcie_edmapf_crPop_if_0          ();
  DWC_pcie_edmapf_ctxPop_haltable_if #(
     .P_DATATYPE(P_DATATYPE)
    ,.P_TAGWD   ($clog2(P_MAXTAGS))
                                    )b_DWC_pcie_edmapf_ctxPop_haltable_if_0();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_damper
   #(
   .P_DAMPER_DP(P_DAMPER_DP)
  ,.P_DATATYPE (P_DATATYPE)
  ) u_damper (
   .b_pop         ( b_DWC_pcie_edmapf_crPop_if_0.slave_mp            )
  ,.b_popHaltable ( b_DWC_pcie_edmapf_ctxPop_haltable_if_0.master_mp )
  ,.b_clk         ( b_clk                                            )
  );

  DWC_pcie_edmapf_ctrl_ctx_hub
  
    u_hub (
   .b_clk         ( b_clk                                            )
  ,.b_glbCtx      ( b_glbCtx                                         )
  ,.b_pop         ( b_pop                                            )
  ,.b_push        ( b_DWC_pcie_edmapf_ctxPop_haltable_if_0.slave_mp  )
  );

  DWC_pcie_edmapf_lutMngr
   #(
   .P_MAXTAG(P_MAXTAGS-1)
  ) u_lutMngr (
   .b_cfg         ( b_cfg                                            )
  ,.b_clk         ( b_clk                                            )
  ,.b_memAccess   ( b_memAccess                                      )
  ,.b_pop         ( b_DWC_pcie_edmapf_crPop_if_0.master_mp           )
  ,.b_push        ( b_push                                           )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
