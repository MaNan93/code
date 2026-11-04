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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_llFetchNtfy_if.svh#5 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_LLFETCHNTFY_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_LLFETCHNTFY_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_llFetchNtfy_if #(
   parameter       CC_NUM_DMA_CHAN = 8
  ,parameter CC_NUM_DMA_CHAN_WIDTH = 3
  );

  logic       [CC_NUM_DMA_CHAN-1:0] w_chFilter      ;
  logic       [CC_NUM_DMA_CHAN-1:0] w_chstWaterMark ;
  logic       [CC_NUM_DMA_CHAN-1:0] w_db_apperr     ;
  logic       [CC_NUM_DMA_CHAN-1:0] w_db_chsch_mask ;
  logic       [CC_NUM_DMA_CHAN-1:0] w_db_chstRun    ;
  logic       [CC_NUM_DMA_CHAN-1:0] w_db_llerr      ;
  logic                       [6:0] w_elPfetch      ;
  logic [CC_NUM_DMA_CHAN_WIDTH-1:0] w_elPfetchCh    ;
  logic                             w_elPfetchReady ;
  logic                             w_elPfetchValid ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_chFilter
   ,output w_chstWaterMark
   ,input  w_db_apperr
   ,output w_db_chsch_mask
   ,input  w_db_chstRun
   ,input  w_db_llerr
   ,output w_elPfetch
   ,output w_elPfetchCh
   ,input  w_elPfetchReady
   ,output w_elPfetchValid
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_chFilter
   ,input  w_chstWaterMark
   ,output w_db_apperr
   ,input  w_db_chsch_mask
   ,output w_db_chstRun
   ,output w_db_llerr
   ,input  w_elPfetch
   ,input  w_elPfetchCh
   ,output w_elPfetchReady
   ,input  w_elPfetchValid
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_LLFETCHNTFY_IF__SVH__

