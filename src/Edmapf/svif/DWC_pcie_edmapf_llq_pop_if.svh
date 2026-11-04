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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_llq_pop_if.svh#7 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_LLQ_POP_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_LLQ_POP_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_llq_pop_if
  import DWC_pcie_edmapf_pkg::*;
  #(
   parameter       type P_CTX_TYPE = fullCtxWr_s
  ,parameter      type P_OVRL_TYPE = elemCtxWr_s
  ,parameter       CC_NUM_DMA_CHAN = `CX_NUM_DMA_WR_CHAN
  ,parameter CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter            CX_DMA_LLQ = `CX_DMA_WR_LLQ
  );

  localparam LP_LLQ_RAM_DP_WD = (CC_NUM_DMA_CHAN*CX_DMA_LLQ == 1) ? 1 : $clog2(CC_NUM_DMA_CHAN*CX_DMA_LLQ);

  P_CTX_TYPE                                            w_FetchCtxElem  ;
  logic                                                 w_OpErase       ;
  logic                     [CC_NUM_DMA_CHAN_WIDTH-1:0] w_OpEraseCh     ;
  logic                                                 w_OpFetch       ;
  logic                     [CC_NUM_DMA_CHAN_WIDTH-1:0] w_OpFetchCh     ;
  logic                           [CC_NUM_DMA_CHAN-1:0] w_OpFetchReady  ;
  logic                                                 w_OpUpdate      ;
  logic                     [CC_NUM_DMA_CHAN_WIDTH-1:0] w_OpUpdateCh    ;
  P_OVRL_TYPE                                           w_UpdateCtxElem ;
  logic                                                 w_UpdateRdy     ;
  logic                           [CC_NUM_DMA_CHAN-1:0] w_error         ;
  logic                                                 w_fetchDone     ;
  logic                     [CC_NUM_DMA_CHAN_WIDTH-1:0] w_fetchDoneCh   ;
  logic                                                 w_fetchPoisoned ;
  logic                                                 w_rollback      ;
  logic                     [CC_NUM_DMA_CHAN_WIDTH-1:0] w_rollbackCh    ;
  logic       [CC_NUM_DMA_CHAN-1:0][LP_LLQ_RAM_DP_WD:0] w_slotsWithData ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_FetchCtxElem
   ,input  w_OpErase
   ,input  w_OpEraseCh
   ,input  w_OpFetch
   ,input  w_OpFetchCh
   ,output w_OpFetchReady
   ,input  w_OpUpdate
   ,input  w_OpUpdateCh
   ,input  w_UpdateCtxElem
   ,output w_UpdateRdy
   ,output w_error
   ,output w_fetchDone
   ,output w_fetchDoneCh
   ,output w_fetchPoisoned
   ,input  w_rollback
   ,input  w_rollbackCh
   ,output w_slotsWithData
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_FetchCtxElem
   ,output w_OpErase
   ,output w_OpEraseCh
   ,output w_OpFetch
   ,output w_OpFetchCh
   ,input  w_OpFetchReady
   ,output w_OpUpdate
   ,output w_OpUpdateCh
   ,output w_UpdateCtxElem
   ,input  w_UpdateRdy
   ,input  w_error
   ,input  w_fetchDone
   ,input  w_fetchDoneCh
   ,input  w_fetchPoisoned
   ,output w_rollback
   ,output w_rollbackCh
   ,input  w_slotsWithData
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_LLQ_POP_IF__SVH__

