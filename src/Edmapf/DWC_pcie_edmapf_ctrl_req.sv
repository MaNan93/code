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
// ---    $Revision: #15 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_req.sv#15 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_req
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter    type P_CTXPIPE_TYPE = dmaWrEngCtx_s
  ,parameter        type P_CTX_TYPE = fullCtxWr_s
  ,parameter       type P_OVRL_TYPE = elemCtxWr_s
  ,parameter       CC_DMA_BA_ENABLE = 0
  ,parameter             CX_DMA_LLQ = `CX_DMA_WR_LLQ
  ,parameter        CX_NUM_DMA_CHAN = 16
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_genericData_if.slave_mp b_channelRunning
  ,DWC_pcie_edmapf_genericData_if.slave_mp b_swStop
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp     cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp       clk
  ,DWC_pcie_edmapf_llq_pop_if.slave_mp     ll_pop
  ,DWC_pcie_edmapf_tlp_if.master_mp        rd_data
  ,DWC_pcie_edmapf_ctxPush_if.master_mp    req_push
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_req_dataSerializer_if #(
     .P_CHAN_WD  ((CX_NUM_DMA_CHAN==1) ? 1 : $clog2(CX_NUM_DMA_CHAN))
    ,.P_DATA_TYPE(P_CTXPIPE_TYPE)
    ,.P_LL_STAGES(P_CHANNEL == E_WRITE ? K_DMA_WR_LL_REQ_STAGES  : K_DMA_RD_LL_REQ_STAGES)
    ,.P_OVRL_TYPE(P_OVRL_TYPE)
    ,.P_SLOT_WD  (P_CHANNEL == E_WRITE ? ((K_DMA_WR_LL_REQ_STAGES==1) ? 1 : $clog2(K_DMA_WR_LL_REQ_STAGES))  : ((K_DMA_RD_LL_REQ_STAGES==1) ? 1 : $clog2(K_DMA_RD_LL_REQ_STAGES)))
                                       )b_DWC_pcie_edmapf_req_dataSerializer_if_0();
  DWC_pcie_edmapf_req_push_if #(
     .CC_NUM_DMA_CHAN      (CX_NUM_DMA_CHAN)
    ,.CC_NUM_DMA_CHAN_WIDTH((CX_NUM_DMA_CHAN==1) ? 1 : $clog2(CX_NUM_DMA_CHAN))
    ,.P_CTX_TYPE           (P_CTX_TYPE)
    ,.P_LL_STAGES          (P_CHANNEL == E_WRITE ? K_DMA_WR_LL_REQ_STAGES  : K_DMA_RD_LL_REQ_STAGES)
                             )          b_DWC_pcie_edmapf_req_push_if_0          ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_ctrl_req_latencyManager
   #(
   .CX_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
  ,.P_CHANNEL      (P_CHANNEL)
  ,.P_CTX_TYPE     (P_CTX_TYPE)
  ,.P_DATA_TYPE    (P_CTXPIPE_TYPE)
  ,.P_OVRL_TYPE    (P_OVRL_TYPE)
  ) u_ctxCache (
   .b_cacheAccess    ( b_DWC_pcie_edmapf_req_dataSerializer_if_0.slave_mp  )
  ,.b_channelRunning ( b_channelRunning                                    )
  ,.b_clk            ( clk                                                 )
  ,.b_push           ( b_DWC_pcie_edmapf_req_push_if_0.slave_mp            )
  ,.b_swStop         ( b_swStop                                            )
  );

  DWC_pcie_edmapf_ctrl_req_ctxPop
   #(
   .CX_DMA_LLQ     (CX_DMA_LLQ)
  ,.CX_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
  ,.P_CHANNEL      (P_CHANNEL)
  ,.P_OVRL_TYPE    (P_OVRL_TYPE)
  ) u_ctxFetcher (
   .b_clk            ( clk                                                 )
  ,.b_pop            ( ll_pop                                              )
  ,.b_push           ( b_DWC_pcie_edmapf_req_push_if_0.master_mp           )
  );

  DWC_pcie_edmapf_ctrl_req_serializer
   #(
   .CX_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
  ,.P_CHANNEL      (P_CHANNEL)
  ,.P_DATA_TYPE    (P_CTXPIPE_TYPE)
  ,.P_OVRL_TYPE    (P_OVRL_TYPE)
  ) u_ctxSerializer (
   .b_cacheAccess    ( b_DWC_pcie_edmapf_req_dataSerializer_if_0.master_mp )
  ,.b_cdm            ( cdm                                                 )
  ,.b_clk            ( clk                                                 )
  ,.b_push           ( req_push                                            )
  ,.b_rdData         ( rd_data                                             )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
