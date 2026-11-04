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
// ---    $DateTime: 2023/12/08 08:15:20 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_vc_merge.sv#2 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// XTLH VC Merge
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_vc_merge
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  DWC_pcie_ctl_pkg::NVC;
#(
  parameter TP = `TP
) 
                      (
  input                           core_clk,
  input                           core_rst_n,
  input                           halt_in,
  input   xtlh_vc_pkt_struct      vc_pkt_in [NVC-1:0],
  input   [P_NW_CNT_WD-1:0]       vc_next_sot_cnt [NVC-1:0],
  output  logic [P_NW_CNT_WD-1:0] xtlh_vc_merge_next_sot_cnt,
  output  logic                   xtlh_vc_merge_halt_out [NVC-1:0],
  output  xtlh_vc_pkt_struct      xtlh_vc_merge_pkt_out
);

assign xtlh_vc_merge_halt_out[0] = halt_in;
assign xtlh_vc_merge_pkt_out = vc_pkt_in[0];
assign xtlh_vc_merge_next_sot_cnt = vc_next_sot_cnt[0];

endmodule
