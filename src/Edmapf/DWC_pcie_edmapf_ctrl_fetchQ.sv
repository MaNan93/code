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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_fetchQ.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_push_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_fslots_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_fetchQ
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter          type P_CTX_TYPE = fullCtxWr_s
  ,parameter        type P_ERROR_TYPE = dmaErrors_e
  ,parameter         type P_OVRL_TYPE = elemCtxWr_s
  ,parameter          CC_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter    CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter               CX_DMA_LLQ = `CX_DMA_WR_LLQ
  ,parameter P_CTX_LLQ_OVERLAY_RAM_DP = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_DP
  ,parameter P_CTX_LLQ_OVERLAY_RAM_PW = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW
  ,parameter P_CTX_LLQ_OVERLAY_RAM_WD = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD
  ,parameter               P_PIPELINE = 1
  ,parameter   dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp       clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp        crgb
  ,DWC_pcie_edmapf_ram2p_if.master_mp      ctx_ovrl_ram
  ,DWC_pcie_edmapf_genericData_if.slave_mp glbCtx
  ,DWC_pcie_edmapf_llq_pop_if.master_mp    pop
  ,DWC_pcie_edmapf_llq_push_if.slave_mp    push
  ,DWC_pcie_edmapf_llq_fslots_if.master_mp slotsReport
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_llq_crgbRd_if #(
     .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.P_OVRL_TYPE          (fetchQ_s)
                               )     b_DWC_pcie_edmapf_llq_crgbRd_if_0     ();
  DWC_pcie_edmapf_llq_crgbWr_if #(
     .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.P_OVRL_TYPE          (fetchQ_s)
                               )     b_DWC_pcie_edmapf_llq_crgbWr_if_0     ();
  DWC_pcie_edmapf_llq_memWr_if #(
     .CC_NUM_DMA_CHAN      (CC_NUM_DMA_CHAN)
    ,.CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.CX_DMA_LLQ           (CX_DMA_LLQ)
    ,.P_OVRL_TYPE          (P_OVRL_TYPE)
                              )      b_DWC_pcie_edmapf_llq_memWr_if_0      ();
  DWC_pcie_edmapf_llq_popInternal_if #(
     .CC_NUM_DMA_CHAN      (CC_NUM_DMA_CHAN)
    ,.CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.CX_DMA_LLQ           (CX_DMA_LLQ)
    ,.P_CTX_TYPE           (P_CTX_TYPE)
                                    )b_DWC_pcie_edmapf_llq_popInternal_if_0();
  DWC_pcie_edmapf_llq_popUpdate_if #(
     .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.P_OVRL_TYPE          (P_OVRL_TYPE)
                                  )  b_DWC_pcie_edmapf_llq_popUpdate_if_0  ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_ctrl_fetchQ_crgb
   #(
   .CC_NUM_DMA_CHAN         (CC_NUM_DMA_CHAN)
  ,.CC_NUM_DMA_CHAN_WIDTH   (CC_NUM_DMA_CHAN_WIDTH)
  ,.P_CHANNEL               (P_CHANNEL)
  ,.P_CTX_LLQ_OVERLAY_RAM_DP(P_CTX_LLQ_OVERLAY_RAM_DP)
  ,.P_CTX_LLQ_OVERLAY_RAM_PW(P_CTX_LLQ_OVERLAY_RAM_PW)
  ,.P_CTX_LLQ_OVERLAY_RAM_WD(P_CTX_LLQ_OVERLAY_RAM_WD)
  ,.P_OVRL_TYPE             (fetchQ_s)
  ) u_crgb (
   .crgb        ( crgb                                             )
  ,.ctrl        ( clk                                              )
  ,.read        ( b_DWC_pcie_edmapf_llq_crgbRd_if_0.master_mp      )
  ,.write       ( b_DWC_pcie_edmapf_llq_crgbWr_if_0.master_mp      )
  );

  DWC_pcie_edmapf_ctrl_fetchQ_pop
   #(
   .CC_NUM_DMA_CHAN(CC_NUM_DMA_CHAN)
  ) u_pop (
   .ctrl        ( clk                                              )
  ,.pop         ( pop                                              )
  ,.popInt      ( b_DWC_pcie_edmapf_llq_popInternal_if_0.slave_mp  )
  ,.popUp       ( b_DWC_pcie_edmapf_llq_popUpdate_if_0.slave_mp    )
  );

  DWC_pcie_edmapf_ctrl_fetchQ_push
   #(
   .CC_NUM_DMA_CHAN(CC_NUM_DMA_CHAN)
  ,.CX_DMA_LLQ     (CX_DMA_LLQ)
  ,.P_OVRL_TYPE    (P_OVRL_TYPE)
  ) u_push (
   .ctrl        ( clk                                              )
  ,.pop         ( b_DWC_pcie_edmapf_llq_popUpdate_if_0.master_mp   )
  ,.push        ( push                                             )
  ,.slotsReport ( slotsReport                                      )
  ,.write       ( b_DWC_pcie_edmapf_llq_memWr_if_0.master_mp       )
  );

  DWC_pcie_edmapf_ctrl_fetchQ_virtualMemCtrl
   #(
   .CC_NUM_DMA_CHAN(CC_NUM_DMA_CHAN)
  ,.CX_DMA_LLQ     (CX_DMA_LLQ)
  ,.P_ERROR_TYPE   (P_ERROR_TYPE)
  ,.P_OVRL_TYPE    (P_OVRL_TYPE)
  ,.P_PIPELINE     (P_PIPELINE)
  ) u_vMemCtrl (
   .b_ovrlRam   ( ctx_ovrl_ram                                     )
  ,.crgbRd      ( b_DWC_pcie_edmapf_llq_crgbRd_if_0.slave_mp       )
  ,.crgbWr      ( b_DWC_pcie_edmapf_llq_crgbWr_if_0.slave_mp       )
  ,.ctrl        ( clk                                              )
  ,.glbCtx      ( glbCtx                                           )
  ,.read        ( b_DWC_pcie_edmapf_llq_popInternal_if_0.master_mp )
  ,.write       ( b_DWC_pcie_edmapf_llq_memWr_if_0.slave_mp        )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
