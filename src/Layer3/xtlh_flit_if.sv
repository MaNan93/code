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
// ---    $DateTime: 2023/12/15 05:40:39 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_flit_if.sv#9 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// XTLH Multistream Architecture
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_flit_if
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::CMD_NOP;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::DW_W_PAR;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::flit_type_struct;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  xtlh_ms_pkg::flit_marker_struct;
  import  xtlh_ms_pkg::flit_status_e;
  import  xtlh_ms_pkg::E_POISON;
  import  xtlh_ms_pkg::E_NULLIFIED;
  import  xtlh_ms_pkg::P_XTLH_MAX_TLP_CNT_WD;
  import  xtlh_ms_pkg::P_N_TLP_LEN;
  import  xtlh_ms_pkg::P_NW_PROT;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
      import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import  xtlh_ms_pkg::tlp_end_struct;
#(
  parameter TP = `TP
  ,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0
) 
                     (
  input                         core_clk,
  input                         core_rst_n,
  input                         halt_in,
  input                         flit_mode_en,
  input   [P_NW_CNT_WD - 1 : 0] next_sot_cnt,
  input                         spif_enable,
  input                         cdm_err_inj_en,
  input                         cdm_tx_err_inj_en,
  output  tx_flit_struct        xtlh_flit_if_flit,
  input   tx_cmd_struct         xdlh_xtlh_cmd,      // Command interface
  input                         rstctl_core_flush_req,
  input   [P_N_TLP_LEN-1:0][10:0]                pkt_if_tlp_len,
  input   [P_DW-1:0]            pkt_if_data,
  input   [P_NW_PROT-1:0]       pkt_if_tlp_prot,
  input                         pkt_if_dv,
  input   [P_NW-1:0]            pkt_if_sot,
  input   [P_NW-1:0]            pkt_if_eot,
  input   [P_NW-1:0]            pkt_if_badeot,
  input   [P_NW-1:0]            pkt_if_ep,
  input   tlp_end_struct        pkt_if_tlp_end,
  input   [P_NW-1:0]            pkt_if_ptm,
  input   logic                 pkt_if_ras_dp_err_inband_kbd,
  input                         pkt_if_sot_is_first,
  input                         pkt_if_badeot_or,
  input                         pkt_if_first_badeot,
  input                         pkt_if_eot_sot,
  input                         pkt_if_eot_sot_eot,
  output  logic [P_N_TLP_LEN-1:0][10:0]   xtlh_flit_if_tlp_len,         // TLP Length aligned to SOT
  output  logic [DW_W_PAR-1:0]  xtlh_flit_if_data,            // TLP Data
  output  logic                 xtlh_flit_if_dv,              // TLP Data Valid
  output  logic [P_NW-1:0]      xtlh_flit_if_sot,             // Start of TLP indication
  output  logic [P_NW-1:0]      xtlh_flit_if_eot,             // End of TLP indication
  output  logic [P_NW-1:0]      xtlh_flit_if_badeot,          // Bad End of TLP indication
  output  logic                 xtlh_flit_if_sot_is_first,    // SOT is first in the data path
  output  logic                 xtlh_flit_if_badeot_or,       // BADEOT
  output  logic                 xtlh_flit_if_first_badeot,    // BADEOT is first in the data path
  output  logic                 xtlh_flit_if_eot_sot,         // End followed by Start
  output  logic                 xtlh_flit_if_eot_sot_eot,     // End Start End
  output  logic                 xtlh_flit_if_halt_out,        // Halt
  output  logic                 xtlh_flit_if_nop_ack,         // NOP Flit Acknowledge
  output  logic [P_XTLH_MAX_TLP_CNT_WD-1:0] xtlh_flit_if_eot_cnt,
  output  logic [P_XTLH_MAX_TLP_CNT_WD-1:0] xtlh_flit_if_over_cnt,
  output  logic                 xtlh_flit_if_marker_sent,     // Indicates that Flit MArker was sent
  output  logic                 xtlh_flit_if_tlp_pending,     // TLP Pending in flit framer
  output  tlp_end_struct        xtlh_flit_if_tlp_end          // End of TLP indication within the Flit
      ,
      input  ras_dp_err_inj_t                   ras_dp_err_inj
    ,
  output ras_dp_err_log_t     ras_dp_err_log
);

flit_marker_struct  [P_NW-1:0]  int_flit_marker;
logic                           int_fm_frame_halt;
tx_flit_struct                  int_fm_frame_flit;
logic               [P_DW-1:0]  int_fm_mux_data;
logic                           int_fm_mux_dv;
logic               [P_NW-1:0]  int_fm_mux_sot;
logic               [P_NW-1:0]  int_fm_mux_eot;
tlp_end_struct                  int_fm_frame_tlp_end;
logic                           int_fm_mux_halt;
logic                           int_fm_mux_ras_dp_err_inband_kbd;
logic          [P_NW_PROT-1:0]  int_fm_mux_prot;

// Encode the flit marker based on the input packet
always_comb begin : flit_marker_enc_PROC
  for(int i = 0; i < P_NW; i = i + 1) begin
    int_flit_marker[i] = '0;
    // PTM TLP ending in this DW
    if(pkt_if_ptm[i])
      int_flit_marker[i].ptm_in_flit = '1;
    if( pkt_if_ptm[i] || pkt_if_badeot[i] || pkt_if_ep[i])
      int_flit_marker[i].flit_marker_indication = '1;
    // Nullified
    if(pkt_if_badeot[i])
      int_flit_marker[i].flit_status = E_NULLIFIED;
    // Poisoned
    else if(pkt_if_ep[i])
      int_flit_marker[i].flit_status = E_POISON;
  end
end : flit_marker_enc_PROC

assign int_fm_mux_data                  = flit_mode_en ? pkt_if_data                  : '0;
assign int_fm_mux_dv                    = flit_mode_en ? pkt_if_dv                    : '0;
assign int_fm_mux_sot                   = flit_mode_en ? pkt_if_sot                   : '0;
assign int_fm_mux_eot                   = flit_mode_en ? pkt_if_eot                   : '0;
assign int_fm_mux_ras_dp_err_inband_kbd = flit_mode_en ? pkt_if_ras_dp_err_inband_kbd : '0;
assign int_fm_mux_prot                  = flit_mode_en ? pkt_if_tlp_prot              : '0;
assign int_fm_mux_halt                  = flit_mode_en ? halt_in                      : 1'b1;


xtlh_fm_frame_ms
 # (
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
) 
u_xtlh_fm_frame (
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .halt_in                    (int_fm_mux_halt),
  .flit_mode_en               (flit_mode_en),
  .next_sot_cnt               (next_sot_cnt),
  .spif_enable                (spif_enable),
  .cdm_err_inj_en             (cdm_err_inj_en),
  .cdm_tx_err_inj_en          (cdm_tx_err_inj_en),
  .xdlh_xtlh_cmd              (xdlh_xtlh_cmd),
  .xtlh_fm_frame_nop_ack      (xtlh_flit_if_nop_ack),
  .data_in                    (int_fm_mux_data),
  .data_valid                 (int_fm_mux_dv),
  .sot                        (int_fm_mux_sot),
  .eot                        (int_fm_mux_eot),
  .rstctl_core_flush_req      (rstctl_core_flush_req),
  .ras_dp_err_inband_kbd      (int_fm_mux_ras_dp_err_inband_kbd),
  .prot                       (int_fm_mux_prot),
  .xtlh_fm_frame_tlp_pending  (xtlh_flit_if_tlp_pending),
  .flit_marker                (int_flit_marker),
  .xtlh_fm_frame_flit         (int_fm_frame_flit),
  .xtlh_fm_frame_halt         (int_fm_frame_halt),
  .xtlh_fm_frame_marker_sent  (xtlh_flit_if_marker_sent),
  .xtlh_fm_frame_eot_cnt      (xtlh_flit_if_eot_cnt),
  .xtlh_fm_frame_over_cnt     (xtlh_flit_if_over_cnt),
  .xtlh_fm_frame_tlp_end      (int_fm_frame_tlp_end)
      ,
      .ras_dp_err_inj         (ras_dp_err_inj)
    ,
    .ras_dp_err_log           (ras_dp_err_log)
);

// Wire the output interfaces
always_comb begin : if_PROC
  if(flit_mode_en) begin
    // XTLH Packet Interface
    xtlh_flit_if_tlp_len = '0;
    xtlh_flit_if_data = '0;
    xtlh_flit_if_dv = '0;
    xtlh_flit_if_sot = '0;
    xtlh_flit_if_eot = '0;
    xtlh_flit_if_badeot = '0;
    xtlh_flit_if_sot_is_first = '0;
    xtlh_flit_if_badeot_or = '0;
    xtlh_flit_if_first_badeot = '0;
    xtlh_flit_if_eot_sot = '0;
    xtlh_flit_if_eot_sot_eot = '0;
    xtlh_flit_if_tlp_end = int_fm_frame_tlp_end;
    xtlh_flit_if_flit = int_fm_frame_flit;
    xtlh_flit_if_halt_out = int_fm_frame_halt;
  end else begin
    // XTLH Packet Interface
    xtlh_flit_if_tlp_len = pkt_if_tlp_len;
    xtlh_flit_if_data = { pkt_if_tlp_prot, pkt_if_data};
    xtlh_flit_if_dv = pkt_if_dv;
    xtlh_flit_if_sot = pkt_if_sot;
    xtlh_flit_if_eot = pkt_if_eot;
    xtlh_flit_if_badeot = pkt_if_badeot;
    xtlh_flit_if_sot_is_first = pkt_if_sot_is_first;
    xtlh_flit_if_badeot_or = pkt_if_badeot_or;
    xtlh_flit_if_first_badeot = pkt_if_first_badeot;
    xtlh_flit_if_eot_sot = pkt_if_eot_sot;
    xtlh_flit_if_eot_sot_eot = pkt_if_eot_sot_eot;
    xtlh_flit_if_tlp_end = pkt_if_tlp_end;
    xtlh_flit_if_flit = '0;
    xtlh_flit_if_halt_out = halt_in;
  end
end : if_PROC


endmodule
