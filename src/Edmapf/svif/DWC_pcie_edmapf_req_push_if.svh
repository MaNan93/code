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
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_req_push_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_REQ_PUSH_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_REQ_PUSH_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_req_push_if
  import DWC_pcie_edmapf_pkg::*;
  #(
   parameter       type P_CTX_TYPE = fullCtxWr_s
  ,parameter       CC_NUM_DMA_CHAN = 16
  ,parameter CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter           P_LL_STAGES = K_DMA_WR_LL_REQ_STAGES
  );

  logic                                  w_OpErase        ;
  logic      [CC_NUM_DMA_CHAN_WIDTH-1:0] w_OpEraseCh      ;
  logic                                  w_channelToken   ;
  logic            [CC_NUM_DMA_CHAN-1:0] w_channelWorking ;
  P_CTX_TYPE                             w_ctxElem        ;
  logic            [CC_NUM_DMA_CHAN-1:0] w_dropingCtx     ;
  logic            [CC_NUM_DMA_CHAN-1:0] w_flush          ;
  logic                [P_LL_STAGES-1:0] w_flusingLL      ;
  logic                                  w_llFull         ;
  logic                                  w_push           ;
  logic      [CC_NUM_DMA_CHAN_WIDTH-1:0] w_reqCh          ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_OpErase
   ,input  w_OpEraseCh
   ,input  w_channelToken
   ,input  w_channelWorking
   ,output w_ctxElem
   ,input  w_dropingCtx
   ,output w_flush
   ,input  w_flusingLL
   ,input  w_llFull
   ,output w_push
   ,output w_reqCh
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_OpErase
   ,output w_OpEraseCh
   ,output w_channelToken
   ,output w_channelWorking
   ,input  w_ctxElem
   ,output w_dropingCtx
   ,input  w_flush
   ,output w_flusingLL
   ,output w_llFull
   ,input  w_push
   ,input  w_reqCh
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_REQ_PUSH_IF__SVH__

