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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_req_dataSerializer_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_REQ_DATASERIALIZER_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_REQ_DATASERIALIZER_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_req_dataSerializer_if
  import DWC_pcie_edmapf_pkg::*;
  #(
   parameter type P_DATA_TYPE = dmaWrEngCtx_s
  ,parameter type P_OVRL_TYPE = elemCtxWr_s
  ,parameter        P_CHAN_WD = 4
  ,parameter      P_LL_STAGES = K_DMA_WR_LL_REQ_STAGES
  ,parameter        P_SLOT_WD = $clog2(K_DMA_WR_LL_REQ_STAGES)
  );

  logic       [P_LL_STAGES-1:0] w_accepted ;
  logic         [P_CHAN_WD-1:0] w_channel  ;
  P_DATA_TYPE [P_LL_STAGES-1:0] w_data     ;
  logic       [P_LL_STAGES-1:0] w_dropReq  ;
  logic       [P_LL_STAGES-1:0] w_flush    ;
  logic         [P_SLOT_WD-1:0] w_llErased ;
  logic       [P_LL_STAGES-1:0] w_locked   ;
  logic                         w_sent     ;
  logic                         w_sentFlag ;
  logic       [P_LL_STAGES-1:0] w_stop     ;
  logic                         w_token    ;
  logic       [P_LL_STAGES-1:0] w_valid    ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_accepted
   ,output w_channel
   ,input  w_data
   ,input  w_dropReq
   ,input  w_flush
   ,output w_llErased
   ,output w_locked
   ,output w_sent
   ,output w_sentFlag
   ,input  w_stop
   ,output w_token
   ,input  w_valid
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_accepted
   ,input  w_channel
   ,output w_data
   ,output w_dropReq
   ,output w_flush
   ,input  w_llErased
   ,input  w_locked
   ,input  w_sent
   ,input  w_sentFlag
   ,output w_stop
   ,input  w_token
   ,output w_valid
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_REQ_DATASERIALIZER_IF__SVH__

