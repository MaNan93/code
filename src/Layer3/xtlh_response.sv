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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_response.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Generate responses for every EOT accepted on the pkt_in input.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "products/cx_pl_pkg.svh"

module xtlh_response
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::P_MAX_RSP_MSB;
  import  xtlh_ms_pkg::P_MAX_RSP;
  import  cx_pl_pkg::P_NW;
#(
  parameter TP        = `TP,
  parameter P_MAX_IF  = 1
) 
                      (
  input                         core_clk,
  input                         core_rst_n,
  input                         halt_in,
  input                         flit_mode,
  output                        xtlh_response_block_tlp,  // Stop accepting new TLPs
  input   xtlh_vc_pkt_struct    pkt_in,                   // Merged Packet struct
  output  logic [P_MAX_IF-1:0]  xtlh_response_rsp         // Response Outputs 1 per FC interface
);

// EOT Counter
logic [P_MAX_RSP_MSB : 0] int_pending_rsp [P_MAX_IF-1:0];
logic                     int_intf_vector [P_MAX_IF-1:0];
logic [P_MAX_IF-1:0]      int_response_block_tlp;
xtlh_vc_pkt_struct        int_mask_pkt_in;

assign int_mask_pkt_in = flit_mode ? pkt_in : '0;

xtlh_response_cnt
 u_xtlh_response_cnt [P_MAX_IF-1 : 0] (
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .halt_in                (halt_in),
  .pkt_in                 (int_mask_pkt_in),
  .intf                   (int_intf_vector),
  .xtlh_response_cnt_val  (int_pending_rsp)
);

always_comb begin : intf_PROC
  for(int i = 0; i < P_MAX_IF; i = i + 1)
    int_intf_vector[i] = (i == 1) ? 1'b1 : 1'b0;
end : intf_PROC

always_comb begin : rsp_PROC
  for(int i = 0; i < P_MAX_IF; i = i + 1)
    xtlh_response_rsp[i] = (int_pending_rsp[i] > 0);
end : rsp_PROC

logic [P_MAX_IF-1:0]  int_block_tlp_r;

always_comb begin : block_tlp_PROC
  for(int i = 0; i < P_MAX_IF; i = i + 1) begin
    if(int_pending_rsp[i] == P_MAX_RSP)
      int_response_block_tlp[i] = '1;
    else if(!xtlh_response_rsp[i])
      int_response_block_tlp[i] = '0;
    else
      int_response_block_tlp[i] = int_block_tlp_r[i];
  end
end : block_tlp_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_block_tlp_r <= #TP '0;
  else
    int_block_tlp_r <= #TP int_response_block_tlp;
end

assign xtlh_response_block_tlp = flit_mode && (|int_response_block_tlp);
endmodule
