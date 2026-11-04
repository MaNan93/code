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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_ChNtfyEn_if.svh#4 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_CHNTFYEN_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_CHNTFYEN_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_ChNtfyEn_if #(
   parameter   P_CHAN = 16
  ,parameter P_CHANWD = 4
  );

  logic   [P_CHAN-1:0] w_chEn    ;
  logic [P_CHANWD-1:0] w_channel ;
  logic   [P_CHAN-1:0] w_chstRun ;
  logic                w_valid   ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_chEn
   ,output w_channel
   ,input  w_chstRun
   ,output w_valid
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_chEn
   ,input  w_channel
   ,output w_chstRun
   ,input  w_valid
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_CHNTFYEN_IF__SVH__

