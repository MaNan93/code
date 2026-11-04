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
// ---    $Revision: #7 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_HubDbOp_if.svh#7 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_HUBDBOP_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_HUBDBOP_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_HubDbOp_if #(
   parameter  type P_ELPFETCH_TYPE = logic
  ,parameter       CC_NUM_DMA_CHAN = `CX_NUM_DMA_WR_CHAN
  ,parameter CC_NUM_DMA_CHAN_WIDTH = 3
  ,parameter            CX_DMA_LLQ = `CX_DMA_WR_LLQ
  );

  localparam LP_LLQ_RAM_DP_WD = $clog2(CC_NUM_DMA_CHAN*CX_DMA_LLQ+1);

  logic                           [CC_NUM_DMA_CHAN_WIDTH-1:0] w_LLNtfyChannel   ;
  logic                                                       w_LLNtfyLst       ;
  logic                                                       w_LLNtfyNonLL     ;
  logic                                                       w_LLNtfyValid     ;
  logic                           [CC_NUM_DMA_CHAN_WIDTH-1:0] w_PushNtfyChannel ;
  logic                                                       w_PushNtfyValid   ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_chStop          ;
  P_ELPFETCH_TYPE                                             w_dbElPfetch      ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_db_chsch_mask   ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_db_err          ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_db_stop         ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_llDescFlush     ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_llDescFlushClr  ;
  logic           [CC_NUM_DMA_CHAN-1:0][LP_LLQ_RAM_DP_WD-1:0] w_slotsAvailable  ;
  logic                                 [CC_NUM_DMA_CHAN-1:0] w_slotsEmpty      ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_LLNtfyChannel
   ,output w_LLNtfyLst
   ,output w_LLNtfyNonLL
   ,output w_LLNtfyValid
   ,output w_PushNtfyChannel
   ,output w_PushNtfyValid
   ,output w_chStop
   ,input  w_dbElPfetch
   ,output w_db_chsch_mask
   ,input  w_db_err
   ,input  w_db_stop
   ,output w_llDescFlush
   ,input  w_llDescFlushClr
   ,output w_slotsAvailable
   ,output w_slotsEmpty
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_LLNtfyChannel
   ,input  w_LLNtfyLst
   ,input  w_LLNtfyNonLL
   ,input  w_LLNtfyValid
   ,input  w_PushNtfyChannel
   ,input  w_PushNtfyValid
   ,input  w_chStop
   ,output w_dbElPfetch
   ,input  w_db_chsch_mask
   ,output w_db_err
   ,output w_db_stop
   ,input  w_llDescFlush
   ,output w_llDescFlushClr
   ,input  w_slotsAvailable
   ,input  w_slotsEmpty
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_HUBDBOP_IF__SVH__

