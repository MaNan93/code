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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_retrain_cnt.sv#2 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// This module implements the replay event counter which is used to trigger a link retrain.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_retrain_cnt #(
  parameter TP = `TP
) (
  input                         core_clk,
  input                         core_rst_n,
  xdlh_retrain_cnt_if.slave_mp  b_retrain_cnt // Retrain counter interface 
);

logic [1 : 0] retrain_cnt;

// Retrain Counter
always @ (posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        retrain_cnt <= #TP 2'b00 ;
    else if( b_retrain_cnt.retrain_cnt_reset ) // clear the count on ack/nak received or rep num roll over x 3
        retrain_cnt <= #TP 2'b00 ;
    else if( b_retrain_cnt.retrain_cnt_incr ) begin
        retrain_cnt <= #TP retrain_cnt + 2'b01;
    end

assign b_retrain_cnt.retrain_cnt = retrain_cnt;

endmodule
