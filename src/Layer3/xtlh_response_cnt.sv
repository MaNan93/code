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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_response_cnt.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Generate responses for every SOT accepted on the pkt_in input.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "products/cx_pl_pkg.svh"

module xtlh_response_cnt
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::P_MAX_RSP_MSB;
  import  xtlh_ms_pkg::P_SOT_CNT_MSB;
  import  cx_pl_pkg::P_NW;
#(
  parameter TP        = `TP
) 
                          (
  input                           core_clk,
  input                           core_rst_n,
  input                           halt_in,
  input   xtlh_vc_pkt_struct      pkt_in,               // Merged Packet struct
  input                           intf,                 // Interface indication
  output  logic [P_MAX_RSP_MSB:0] xtlh_response_cnt_val // Response counter
);

localparam  P_ONE = {{P_SOT_CNT_MSB{1'b0}}, 1'b1};
localparam  P_ZERO = {{P_SOT_CNT_MSB{1'b0}}, 1'b0};

logic [P_SOT_CNT_MSB : 0]  int_sot_cnt [P_NW - 1 : 0];

// Sot Counter only count posted TLP's that do not come from msg_gen or dma
always_comb begin : sot_cnt_PROC
  for(int i = 0; i < P_NW; i = i + 1)
    int_sot_cnt[i] = '0;
  for(int i = 0; i < P_NW; i = i + 1) begin
    if(i == 0)
      int_sot_cnt[i] = (!halt_in && pkt_in.sot[0] && !pkt_in.is_from_msg_gen[0] && !pkt_in.is_from_dma[0] && (pkt_in.intf[0] == intf)) ? P_ONE : P_ZERO;
    else
      int_sot_cnt[i] = (!halt_in && pkt_in.sot[i] && !pkt_in.is_from_msg_gen[i] && !pkt_in.is_from_dma[i] && (pkt_in.intf[i] == intf)) ? int_sot_cnt[i-1] + P_ONE : int_sot_cnt[i-1];
  end
end : sot_cnt_PROC

// Register the response counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : rsp_cnt_PROC
  if(!core_rst_n)
    xtlh_response_cnt_val <= #TP '0;
  else begin
    // Offload 1 response per cycle
    if(xtlh_response_cnt_val > 0)
      xtlh_response_cnt_val <= #TP (xtlh_response_cnt_val - 1) + int_sot_cnt[P_NW-1];
    else
      xtlh_response_cnt_val <= #TP {{(P_MAX_RSP_MSB - P_SOT_CNT_MSB){1'b0}}, int_sot_cnt[P_NW-1]};
  end
end : rsp_cnt_PROC

endmodule
