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
// ---    $Revision: #4 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_nullInjection_if.svh#4 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_NULLINJECTION_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_NULLINJECTION_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_nullInjection_if #(
   parameter   P_MAXTAGS = 1024
  ,parameter    P_NUM_CH = 8
  ,parameter P_NUM_CH_WD = 3
  );

  localparam LP_MAXTAGS_WD = $clog2(P_MAXTAGS);

  logic                     w_ackInj    ;
  logic   [P_NUM_CH_WD-1:0] w_chInj     ;
  logic   [P_NUM_CH_WD-1:0] w_chRcvd    ;
  logic [LP_MAXTAGS_WD-1:0] w_tagInj    ;
  logic [LP_MAXTAGS_WD-1:0] w_tagRcvd   ;
  logic                     w_validInj  ;
  logic                     w_validRcvd ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_ackInj
   ,output w_chInj
   ,input  w_chRcvd
   ,output w_tagInj
   ,input  w_tagRcvd
   ,output w_validInj
   ,input  w_validRcvd
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_ackInj
   ,input  w_chInj
   ,output w_chRcvd
   ,input  w_tagInj
   ,output w_tagRcvd
   ,input  w_validInj
   ,output w_validRcvd
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_NULLINJECTION_IF__SVH__

