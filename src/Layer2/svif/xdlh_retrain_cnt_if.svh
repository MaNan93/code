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
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/svif/xdlh_retrain_cnt_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__XDLH_RETRAIN_CNT_IF__SVH__
`define __GUARD__XDLH_RETRAIN_CNT_IF__SVH__

interface xdlh_retrain_cnt_if ();

  logic       retrain_cnt_incr;   // Increment the retrain counter
  logic       retrain_cnt_reset;  // Reset the retrain counter
  logic [1:0] retrain_cnt;        // Retrain counter

  modport master_mp (
    output  retrain_cnt_incr,
    output  retrain_cnt_reset,
    input   retrain_cnt
  );

  modport slave_mp (
    input   retrain_cnt_incr,
    input   retrain_cnt_reset,
    output  retrain_cnt
  );

endinterface

`endif // __GUARD__XDLH_RETRAIN_CNT_IF__SVH__
