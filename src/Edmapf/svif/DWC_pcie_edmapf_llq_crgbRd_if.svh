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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_llq_crgbRd_if.svh#5 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_LLQ_CRGBRD_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_LLQ_CRGBRD_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_llq_crgbRd_if
  import DWC_pcie_edmapf_pkg::*;
  #(
   parameter      type P_OVRL_TYPE = elemCtxWr_s
  ,parameter CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  );

  logic                                   w_ack   ;
  logic                                   w_en    ;
  glbData_s                               w_glb   ;
  P_OVRL_TYPE                             w_ovrl  ;
  logic       [CC_NUM_DMA_CHAN_WIDTH-1:0] w_reqCh ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_ack
   ,output w_en
   ,input  w_glb
   ,input  w_ovrl
   ,output w_reqCh
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_ack
   ,input  w_en
   ,output w_glb
   ,output w_ovrl
   ,input  w_reqCh
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_LLQ_CRGBRD_IF__SVH__

