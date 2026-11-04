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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_fetchQ_crgb.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_crgbRd_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_crgbWr_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_fetchQ_crgb
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter         type P_OVRL_TYPE = elemCtxWr_s
  ,parameter          CC_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter    CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter P_CTX_LLQ_OVERLAY_RAM_DP = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_DP
  ,parameter P_CTX_LLQ_OVERLAY_RAM_PW = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW
  ,parameter P_CTX_LLQ_OVERLAY_RAM_WD = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD
  ,parameter   dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_crgb_if.slave_mp        crgb
  ,DWC_pcie_edmapf_aclks_if.slave_mp       ctrl
  ,DWC_pcie_edmapf_llq_crgbRd_if.master_mp read
  ,DWC_pcie_edmapf_llq_crgbWr_if.master_mp write
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_ram1p_if #(
     .DP(P_CTX_LLQ_OVERLAY_RAM_DP)
    ,.PW(CC_NUM_DMA_CHAN_WIDTH)
    ,.WD($bits(P_OVRL_TYPE))
                          )b_DWC_pcie_edmapf_ram1p_if_0();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_crgb
   #(
   .P_CHANNEL                        (P_CHANNEL)
  ,.P_RAM /* E_HDMAREGZONE_OVERLAY */(E_HDMAREGZONE_OVERLAY)
  ,.P_RAM_ADDR_WD /* OVRL_PW */      (CC_NUM_DMA_CHAN_WIDTH)
  ,.P_RAM_DATA_WD /* OVRL _WD */     ($bits(P_OVRL_TYPE))
  ) u_crgbOverlayCtx (
   .b_clk    ( ctrl                                   )
  ,.b_crgb   ( crgb                                   )
  ,.b_ram    ( b_DWC_pcie_edmapf_ram1p_if_0.master_mp )
  );

  DWC_pcie_edmapf_ctrl_fetchQ_crgb_ramInterconnector
  
    u_fetchQ_interconnector (
   .crgbOvrl ( b_DWC_pcie_edmapf_ram1p_if_0.slave_mp  )
  ,.crgbRd   ( read                                   )
  ,.crgbWr   ( write                                  )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
