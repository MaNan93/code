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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_mp_arb.sv#1 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//  XTLH Multiport Arbitration and input stage pipeline
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xtlh_mp_arb
import DWC_pcie_core_pkg::xtlh_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter N                       = 2,
    parameter TP                      = `TP
)
(
    input logic                     clk,
    input logic                     rst_n,
    input xtlh_pkt_t        [N-1:0] pkt_in,
    output logic            [N-1:0] out_halt,
    output xtlh_pkt_t               out_pkt,
    output logic                    out_intf,
    input logic                     in_halt
);

logic                 int_pkt_grant;
logic       [N-1: 0]  int_tlp_ongoing;

// Packet arbitration in case of multi-port
generate if (N > 1) begin : g_mp_grant
  always_comb begin : grant_pkt_PROC
    int_pkt_grant = 1'b0;
    out_halt = '0;
    if((pkt_in[0].dv && pkt_in[1].dv) || (pkt_in[0].sot && pkt_in[1].sot)) begin
      if(pkt_in[1].seqnum == (pkt_in[0].seqnum - 1'b1)) begin
        int_pkt_grant = 1'b1;
        out_halt[1] = int_tlp_ongoing[0] || in_halt;
        out_halt[0] = 1'b1;
      end else if(pkt_in[0].seqnum == (pkt_in[1].seqnum - 1'b1)) begin
        int_pkt_grant = 1'b0;
        out_halt[0] = int_tlp_ongoing[1] || in_halt;
        out_halt[1] = 1'b1;
      end else begin
        int_pkt_grant = (pkt_in[1].seqnum > pkt_in[0].seqnum) ? 1'b0 : 1'b1;
        if(int_pkt_grant) begin
          out_halt[1] = int_tlp_ongoing[0] || in_halt;
          out_halt[0] = 1'b1;
        end else begin
          out_halt[0] = int_tlp_ongoing[1] || in_halt;
          out_halt[1] = 1'b1;
        end
      end
    end else if(pkt_in[0].dv || pkt_in[0].sot) begin
      int_pkt_grant = 1'b0;
      out_halt[0] = int_tlp_ongoing[1] || in_halt;
      out_halt[1] = 1'b1;
    end else if(pkt_in[1].dv || pkt_in[1].sot) begin
      int_pkt_grant = 1'b1;
      out_halt[1] = int_tlp_ongoing[0] || in_halt;
      out_halt[0] = 1'b1;
    end else begin
      int_pkt_grant = 1'b0;
      out_halt = '0;
    end
  end : grant_pkt_PROC
  assign out_pkt = int_pkt_grant ? pkt_in[1] : pkt_in[0];
  assign out_intf = int_pkt_grant ? pkt_in[1].sot : 1'b0;
end else begin : g_mp_grant
  assign int_pkt_grant = 1'b0;
  assign out_halt[0] = in_halt;
  assign out_pkt = pkt_in[0];
  assign out_intf = 1'b0;
end
endgenerate

// TLP Ongoing Indication
always_ff @(posedge clk or negedge rst_n) begin : tlp_ongoing_PROC
  if(!rst_n) begin
    int_tlp_ongoing <= #TP '0;
  end else begin
    for(int i = 0; i < N; i++) begin
      if(pkt_in[i].sot && !pkt_in[i].eot && !out_halt[i])
        int_tlp_ongoing[i]  <= #TP 1'b1;
      else if(int_tlp_ongoing[i] && pkt_in[i].eot && !out_halt[i])
        int_tlp_ongoing[i]  <= #TP 1'b0;
    end
  end
end : tlp_ongoing_PROC

endmodule
