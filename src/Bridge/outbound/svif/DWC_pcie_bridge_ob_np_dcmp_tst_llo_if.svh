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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tst_llo_if.svh#3 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_BRIDGE_OB_NP_DCMP_TST_LLO_IF__SVH__
`define __GUARD__DWC_PCIE_BRIDGE_OB_NP_DCMP_TST_LLO_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_bridge_ob_np_dcmp_tst_llo_if #(
   parameter CC_MAX_SLV_TAG_PW = `CC_MAX_SLV_TAG_PW
  ,parameter   MAX_WIRE_TAG_PW = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_TAG_HIGH_WIDTH : `CX_LUT_PTR_WIDTH
  );

  logic [CC_MAX_SLV_TAG_PW-1:0] w_apptag          ;
  logic                         w_pop_wiretag     ;
  logic   [MAX_WIRE_TAG_PW-1:0] w_wiretag         ;
  logic                         w_wiretag_is_last ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_apptag
   ,input  w_pop_wiretag
   ,output w_wiretag
   ,output w_wiretag_is_last
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_apptag
   ,output w_pop_wiretag
   ,input  w_wiretag
   ,input  w_wiretag_is_last
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_BRIDGE_OB_NP_DCMP_TST_LLO_IF__SVH__

