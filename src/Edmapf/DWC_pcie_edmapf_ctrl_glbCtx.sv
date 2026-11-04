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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_glbCtx.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_glbCtx
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter        type P_GLB_TYPE = glbData_s
  ,parameter        CX_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp         b_crgb
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxC2W
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxDbm
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxFetchQ
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxLLCtrl
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxStsh
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_ram1p_if #(
     .DP(CX_NUM_DMA_CHAN)
    ,.PW((CX_NUM_DMA_CHAN == 1) ? 1 : $clog2(CX_NUM_DMA_CHAN))
    ,.WD($bits(P_GLB_TYPE))
                          )b_DWC_pcie_edmapf_ram1p_if_0();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_crgb
   #(
   .P_CHANNEL                       (P_CHANNEL)
  ,.P_RAM /* E_HDMAREGZONE_GLOBAL */(E_HDMAREGZONE_GLOBAL)
  ,.P_RAM_ADDR_WD /* GLB_PW */      ((CX_NUM_DMA_CHAN == 1) ? 1 : $clog2(CX_NUM_DMA_CHAN))
  ,.P_RAM_DATA_WD /* GLB_WD */      ($bits(P_GLB_TYPE))
  ) u_crgbGlobalCtx (
   .b_clk          ( b_clk                                  )
  ,.b_crgb         ( b_crgb                                 )
  ,.b_ram          ( b_DWC_pcie_edmapf_ram1p_if_0.master_mp )
  );

  DWC_pcie_edmapf_ctrl_glbCtx_registers
   #(
   .CX_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
  ,.P_CHANNEL      (P_CHANNEL)
  ,.P_GLB_TYPE     (P_GLB_TYPE)
  ) u_glbCtxReg (
   .b_clk          ( b_clk                                  )
  ,.b_crgb         ( b_DWC_pcie_edmapf_ram1p_if_0.slave_mp  )
  ,.b_glbCtxC2W    ( b_glbCtxC2W                            )
  ,.b_glbCtxDbm    ( b_glbCtxDbm                            )
  ,.b_glbCtxFetchQ ( b_glbCtxFetchQ                         )
  ,.b_glbCtxLLCtrl ( b_glbCtxLLCtrl                         )
  ,.b_glbCtxStsh   ( b_glbCtxStsh                           )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
