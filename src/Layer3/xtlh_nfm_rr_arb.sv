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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_nfm_rr_arb.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Round Robin Arbiter for non-flit mode 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_nfm_rr_arb
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
#(
  parameter TP = `TP
  ,
  parameter P_NUM_P_IF_VC = 1
) 
                        (
  input                             core_clk,
  input                             core_rst_n,
  input                             flit_mode_en,
  input   xtlh_pkt_t                p_pkt_in,
  input                             p_intf,
  input   xtlh_pkt_t                np_pkt_in,
  input   xtlh_pkt_t                cpl_pkt_in,
  input                             p_halt_in,
  input                             np_halt_in,
  input                             cpl_halt_in,
  input   [P_NUM_P_IF_VC-1:0]       p_resp_in,
  output  logic [P_NUM_P_IF_VC-1:0] xtlh_nfm_rr_arb_p_resp,
  output  logic                     xtlh_nfm_rr_arb_p_halt,
  output  logic                     xtlh_nfm_rr_arb_np_halt,
  output  logic                     xtlh_nfm_rr_arb_cpl_halt,
  output  xtlh_pkt_t                xtlh_nfm_rr_arb_p_pkt,
  output  xtlh_pkt_t                xtlh_nfm_rr_arb_np_pkt,
  output  xtlh_pkt_t                xtlh_nfm_rr_arb_cpl_pkt
);

logic [2:0]     int_arb_grant;
logic [2:0]     int_arb_grant_r;
logic [2:0]     int_mux_arb_grant;
logic           int_p_ongoing_r;
logic           int_np_ongoing_r;
logic           int_cpl_ongoing_r;
logic           int_en_arb;
xtlh_pkt_t      int_mask_np_pkt;
xtlh_pkt_t      int_mask_cpl_pkt;

assign int_mask_np_pkt = np_pkt_in;
assign int_mask_cpl_pkt = cpl_pkt_in;

// Round Robin FC Arbiter
DWC_pcie_ctl_bcm55_c
 #(
  .N            (3),
  .OUTPUT_MODE  (0)
) u_rr_arb (
  .clk          (core_clk),
  .rst_n        (core_rst_n),
  .init_n       ('1),
  .enable       (int_en_arb),
  .request      ({int_mask_cpl_pkt.sot, int_mask_np_pkt.sot, p_pkt_in.sot}),
  .mask         ('0),
  .granted      (),
  .grant        (int_arb_grant),
  .grant_index  ()
);

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_arb_grant_r <= #TP '0;
  else begin
    if(int_en_arb)
      int_arb_grant_r <= #TP int_arb_grant;
  end
end

assign int_mux_arb_grant = (int_p_ongoing_r || int_np_ongoing_r || int_cpl_ongoing_r) ? int_arb_grant_r : int_arb_grant;

// Arbitration MUX
always_comb begin : if_mux_PROC
  if(flit_mode_en) begin
    xtlh_nfm_rr_arb_p_pkt = p_pkt_in;
    xtlh_nfm_rr_arb_np_pkt = np_pkt_in;
    xtlh_nfm_rr_arb_cpl_pkt = cpl_pkt_in;
    xtlh_nfm_rr_arb_p_halt = p_halt_in;
    xtlh_nfm_rr_arb_np_halt = np_halt_in;
    xtlh_nfm_rr_arb_cpl_halt = cpl_halt_in;
  end else begin
    xtlh_nfm_rr_arb_np_pkt = '0;
    xtlh_nfm_rr_arb_cpl_pkt = '0;
    if(int_mux_arb_grant == 1) begin
      xtlh_nfm_rr_arb_p_pkt = p_pkt_in;
      xtlh_nfm_rr_arb_p_halt = p_halt_in;
      xtlh_nfm_rr_arb_np_halt = np_pkt_in.dv;
      xtlh_nfm_rr_arb_cpl_halt = cpl_pkt_in.dv;
    end else if(int_mux_arb_grant == 2) begin
      xtlh_nfm_rr_arb_p_pkt = np_pkt_in;
      xtlh_nfm_rr_arb_p_halt = p_pkt_in.dv;
      xtlh_nfm_rr_arb_np_halt = p_halt_in;
      xtlh_nfm_rr_arb_cpl_halt = cpl_pkt_in.dv;
    end else if(int_mux_arb_grant == 4) begin
      xtlh_nfm_rr_arb_p_pkt = cpl_pkt_in;
      xtlh_nfm_rr_arb_p_halt = p_pkt_in.dv;
      xtlh_nfm_rr_arb_np_halt = np_pkt_in.dv;
      xtlh_nfm_rr_arb_cpl_halt = p_halt_in;
    end else begin
      xtlh_nfm_rr_arb_p_pkt = '0;
      xtlh_nfm_rr_arb_p_halt = p_pkt_in.dv;
      xtlh_nfm_rr_arb_np_halt = np_pkt_in.dv;
      xtlh_nfm_rr_arb_cpl_halt = cpl_pkt_in.dv;
    end
  end
end : if_mux_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : p_ongoing_PROC
  if(!core_rst_n)
    int_p_ongoing_r <= #TP '0;
  else begin
    if(!xtlh_nfm_rr_arb_p_halt && p_pkt_in.eot && int_p_ongoing_r)
      int_p_ongoing_r <= #TP 1'b0;
    else if(!xtlh_nfm_rr_arb_p_halt && p_pkt_in.sot && !p_pkt_in.eot && !flit_mode_en)
      int_p_ongoing_r <= #TP 1'b1;
  end
end : p_ongoing_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : np_ongoing_PROC
  if(!core_rst_n)
    int_np_ongoing_r <= #TP '0;
  else begin
    if(!xtlh_nfm_rr_arb_np_halt && np_pkt_in.eot && int_np_ongoing_r)
      int_np_ongoing_r <= #TP 1'b0;
    else if(!xtlh_nfm_rr_arb_np_halt && np_pkt_in.sot && !np_pkt_in.eot && !flit_mode_en)
      int_np_ongoing_r <= #TP 1'b1;
  end
end : np_ongoing_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : cpl_ongoing_PROC
  if(!core_rst_n)
    int_cpl_ongoing_r <= #TP '0;
  else begin
    if(!xtlh_nfm_rr_arb_cpl_halt && cpl_pkt_in.eot && int_cpl_ongoing_r)
      int_cpl_ongoing_r <= #TP 1'b0;
    else if(!xtlh_nfm_rr_arb_cpl_halt && cpl_pkt_in.sot && !cpl_pkt_in.eot && !flit_mode_en)
      int_cpl_ongoing_r <= #TP 1'b1;
  end
end : cpl_ongoing_PROC

assign int_en_arb = !flit_mode_en && !(int_p_ongoing_r || int_np_ongoing_r || int_cpl_ongoing_r);


generate if (P_NUM_P_IF_VC > 1) begin : g_mp_resp
  // NFM/FM Posted Response interface
  always_comb begin : p_resp_if_MUX
    xtlh_nfm_rr_arb_p_resp = '0;
    if(flit_mode_en) begin
      for(int i = 0; i < P_NUM_P_IF_VC; i++)
        xtlh_nfm_rr_arb_p_resp[i] = p_resp_in[i];
    end else begin
      if(p_intf)
        xtlh_nfm_rr_arb_p_resp[1] = p_pkt_in.sot && !p_pkt_in.is_from_dma && !p_pkt_in.is_from_msg_gen && !xtlh_nfm_rr_arb_p_halt;
      else
        xtlh_nfm_rr_arb_p_resp[0] = p_pkt_in.sot && !p_pkt_in.is_from_dma && !p_pkt_in.is_from_msg_gen && !xtlh_nfm_rr_arb_p_halt;
    end
  end
end else begin : g_mp_resp
  // NFM/FM Posted Response interface
  always_comb begin : p_resp_if_MUX
    xtlh_nfm_rr_arb_p_resp = '0;
    if(flit_mode_en)
        xtlh_nfm_rr_arb_p_resp[0] = p_resp_in[0];
    else
        xtlh_nfm_rr_arb_p_resp[0] = p_pkt_in.sot && !p_pkt_in.is_from_dma && !p_pkt_in.is_from_msg_gen && !xtlh_nfm_rr_arb_p_halt;
  end
end
endgenerate

endmodule
