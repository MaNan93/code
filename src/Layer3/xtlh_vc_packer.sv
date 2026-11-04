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
// ---    $DateTime: 2023/12/15 12:36:02 $
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_vc_packer.sv#17 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module containts the FC arbitration for a given VC and generates a data vector
// --- containing merged TLP's.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xtlh_vc_packer
  import  xtlh_ms_pkg::fc_phase_e;
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::E_P_PHASE;
  import  xtlh_ms_pkg::E_NP_PHASE;
  import  xtlh_ms_pkg::E_CPL_PHASE;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  xtlh_ms_pkg::P_MERGE_MAX_CNT_WD;
  import  xtlh_ms_pkg::P_XTLH_MAX_TLP_CNT_WD;
  import  DWC_pcie_core_pkg::xtlh_pkt_t;
  import  xtlh_ms_pkg::P_FC_MERGE_LOG_WD;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter   TP                          = `TP,
  parameter   int P_NUM_P_IF_VC           = 1,    // Number of posted interfaces
  parameter   int P_NUM_NP_IF_VC          = 1,    // Number of non-posted interfaces
  parameter   int P_NUM_CPL_IF_VC         = 1,    // Number of completion interfaces
  parameter       RAS_DP_PROT_CHK_ID_BASE = 0     // Checkers Base ID connected to the checkers if the Ras-Dp 
) 
                       (
  input                                       core_clk,
  input                                       core_rst_n,
  input   [6:0]                               cfg_tx_arb_control,
  input                                       lp_req,
  input   xtlh_pkt_t                          p_pkt_in,                   // Posted TLP Interfaces
  input   xtlh_pkt_t                          np_pkt_in,                  // Non Posted TLP Interfaces
  input   xtlh_pkt_t                          cpl_pkt_in,                 // CPL TLP Interfaces
  input                                       p_intf,
  input                                       np_intf,
  input                                       cpl_intf,
  input                                       halt_in,                    // Downstream Halt
  input                                       rstctl_core_flush_req,      // Core Link down reset flush request
  input                                       flit_mode_en,               // Flit Mode Enabled
  input                                       flit_marker_sent,           // Flit Marker Sent for this VC
  input                                       fc_init_done,               // FC init complete for this VC
  input                                       rasdp_error_mode,           // RASDP Error Mode
  output  logic                               xtlh_vc_packer_p_halt,      // Posted Interfaces Halt
  output  logic                               xtlh_vc_packer_np_halt,     // Non Posted Interfaces Halt
  output  logic                               xtlh_vc_packer_cpl_halt,    // CPL Interfaces Halt
  output  xtlh_vc_pkt_struct                  xtlh_vc_packer_pkt,         // VC Packet Interface
  output  logic [P_NW_CNT_WD-1:0]             xtlh_vc_packer_next_sot_cnt,
  output  logic                               xtlh_vc_packer_pending,
  output  logic                               xtlh_vc_packer_lp_ack
  ,
  output  logic         [P_NUM_P_IF_VC-1:0]   xtlh_vc_packer_p_tlp_sent   // Posted TLP sent indication
  ,
  output  ras_dp_err_log_t  [P_FC_MERGE_LOG_WD - 1 : 0]                    ras_dp_err_log              // RASDP Error Log
  ,
  input   ras_dp_err_inj_t                                                 ras_dp_err_inj
  );

logic [P_NW_CNT_WD - 1 : 0]           int_p_packer_sot_cnt;
logic [P_NW_CNT_WD - 1 : 0]           int_np_packer_sot_cnt;
logic [P_NW_CNT_WD - 1 : 0]           int_cpl_packer_sot_cnt;
logic [P_MERGE_MAX_CNT_WD - 1 : 0]    int_p_packer_tlp_cnt;
logic [P_MERGE_MAX_CNT_WD - 1 : 0]    int_np_packer_tlp_cnt;
logic [P_MERGE_MAX_CNT_WD - 1 : 0]    int_cpl_packer_tlp_cnt;
logic                                 int_fm_filter_stall_req;
logic                                 int_np_packer_stall_req;
logic                                 int_p_packer_stall_req;
logic                                 int_cpl_packer_stall_req;
logic                                 int_cpl_packer_sot_last;
logic                                 int_cpl_packer_eot_last;
logic                                 int_np_packer_sot_last;
logic                                 int_np_packer_eot_last;
logic                                 int_p_packer_sot_last;
logic                                 int_p_packer_eot_last;
logic                                 int_block_posted_tlp;
logic         [P_NUM_P_IF_VC-1:0]     int_posted_tlp_sent;
logic                                 int_svc_fc_merge_p_fm_pend;
logic                                 int_svc_fc_merge_np_fm_pend;
logic                                 int_svc_fc_merge_cpl_fm_pend;
logic                                 int_svc_merge_pending;
logic                                 int_fc_packer_p_pend;
logic                                 int_fc_packer_np_pend;
logic                                 int_fc_packer_cpl_pend;
logic                                 int_p_fm_sent;
logic                                 int_np_fm_sent;
logic                                 int_cpl_fm_sent;
logic                                 int_fc_merge_halt_p;
logic                                 int_fc_merge_halt_np;
logic                                 int_fc_merge_halt_cpl;
logic                                 int_fc_arb_halt_cpl;
logic                                 int_fc_arb_halt_p;
logic                                 int_fc_arb_halt_np;
xtlh_vc_pkt_struct                    int_fm_filter_p_pkt;
xtlh_vc_pkt_struct                    int_fm_filter_np_pkt;
xtlh_vc_pkt_struct                    int_fm_filter_cpl_pkt;
xtlh_vc_pkt_struct                    int_fc_merge_p_pkt_out;
xtlh_vc_pkt_struct                    int_fc_merge_np_pkt_out;
xtlh_vc_pkt_struct                    int_fc_merge_cpl_pkt_out;
xtlh_vc_pkt_struct                    int_p_pkt_out;
xtlh_vc_pkt_struct                    int_np_pkt_out;
xtlh_vc_pkt_struct                    int_cpl_pkt_out;
logic                                 int_lp_req_to_packer;

xtlh_pkt_t                            int_p_pkt_in;
logic                                 int_msg_gen_r;
logic                                 int_packer_p_halt;
logic                                 int_packer_np_halt;
logic                                 int_packer_cpl_halt;
logic                                 int_fm_filter_p_halt;
logic                                 int_fm_filter_np_halt;
logic                                 int_fm_filter_cpl_halt;

xtlh_pkt_t                            int_nfm_arb_p_pkt_in;
xtlh_pkt_t                            int_nfm_arb_np_pkt_in;
xtlh_pkt_t                            int_nfm_arb_cpl_pkt_in;

// -----------------------------------------------------------------------------
// Non-Flit Mode Round Robin Arbiter
// -----------------------------------------------------------------------------
xtlh_nfm_rr_arb
 #(
  .P_NUM_P_IF_VC (P_NUM_P_IF_VC)
) u_nfm_rr_arb (
  .core_clk                             (core_clk),
  .core_rst_n                           (core_rst_n),
  .flit_mode_en                         (flit_mode_en),
  .p_pkt_in                             (int_p_pkt_in),
  .p_intf                               (p_intf),
  .np_pkt_in                            (np_pkt_in),
  .cpl_pkt_in                           (cpl_pkt_in),
  .p_halt_in                            (int_packer_p_halt),
  .np_halt_in                           (int_packer_np_halt),
  .cpl_halt_in                          (int_packer_cpl_halt),
  .p_resp_in                            (int_posted_tlp_sent),
  .xtlh_nfm_rr_arb_p_resp               (xtlh_vc_packer_p_tlp_sent),
  .xtlh_nfm_rr_arb_p_halt               (xtlh_vc_packer_p_halt),
  .xtlh_nfm_rr_arb_np_halt              (xtlh_vc_packer_np_halt),
  .xtlh_nfm_rr_arb_cpl_halt             (xtlh_vc_packer_cpl_halt),
  .xtlh_nfm_rr_arb_p_pkt                (int_nfm_arb_p_pkt_in),
  .xtlh_nfm_rr_arb_np_pkt               (int_nfm_arb_np_pkt_in),
  .xtlh_nfm_rr_arb_cpl_pkt              (int_nfm_arb_cpl_pkt_in)
);

// -----------------------------------------------------------------------------
// Per VC Power Management Control Module
// -----------------------------------------------------------------------------
xtlh_vc_pm_control
 u_xtlh_vc_pm_control (
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .p_fc_packer_pending        (int_fc_packer_p_pend),
  .np_fc_packer_pending       (int_fc_packer_np_pend),
  .cpl_fc_packer_pending      (int_fc_packer_cpl_pend),
  .merge_pending              (int_svc_merge_pending),
  .lp_req                     (lp_req),
  .xtlh_vc_pm_control_pending (xtlh_vc_packer_pending),
  .xtlh_vc_pm_control_lp_ack  (xtlh_vc_packer_lp_ack),
  .xtlh_vc_pm_control_lp_req  (int_lp_req_to_packer)
);

// Extend the msg_gen indication for posted interfaces such that it is available at EOT
always_ff @(posedge core_clk or negedge core_rst_n) begin : msg_gen_PROC
  if(!core_rst_n)
    int_msg_gen_r <= #TP '0;
  else begin
    if(int_msg_gen_r && p_pkt_in.eot)
      int_msg_gen_r <= #TP '0;
    else if(p_pkt_in.sot && p_pkt_in.is_from_msg_gen && !p_pkt_in.eot)
      int_msg_gen_r <= #TP '1;
    else
      int_msg_gen_r <= #TP int_msg_gen_r;
  end
end : msg_gen_PROC

// Extending the packet interface is_from_msg_gen to EOT
always_comb begin : msg_gen_ext_PROC
  int_p_pkt_in = p_pkt_in;
  int_p_pkt_in.is_from_msg_gen = p_pkt_in.is_from_msg_gen || int_msg_gen_r;
end : msg_gen_ext_PROC

assign int_p_fm_sent = (flit_marker_sent && int_svc_fc_merge_p_fm_pend) || rstctl_core_flush_req;
assign int_np_fm_sent = (flit_marker_sent && int_svc_fc_merge_np_fm_pend) || rstctl_core_flush_req;
assign int_cpl_fm_sent = (flit_marker_sent && int_svc_fc_merge_cpl_fm_pend) || rstctl_core_flush_req;

assign int_p_packer_stall_req = flit_mode_en && 
                                (( int_fm_filter_np_pkt.dv && int_fc_merge_halt_np) 
                                || ( int_fm_filter_cpl_pkt.dv && int_fc_merge_halt_cpl));

// Instantiate the FC packers per FC Type
// Posted
xtlh_fc_merge
 #(
   .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
) u_p_packer (
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .lp_req                         (int_lp_req_to_packer),
  .fc_init_done                   (fc_init_done),
  .rstctl_core_flush_req          (rstctl_core_flush_req),
  .cons_packet_limit              (cfg_tx_arb_control[5:4]),
  .stall_req_in                   (int_p_packer_stall_req),
  .block_req_in                   (int_block_posted_tlp),
  .halt_in                        (int_fm_filter_p_halt),
  .pkt_in                         (int_nfm_arb_p_pkt_in),
  .intf                           (p_intf),
  .xtlh_fc_merge_pkt_sot_last     (int_p_packer_sot_last),
  .xtlh_fc_merge_pkt_eot_last     (int_p_packer_eot_last),
  .flit_pack_limit                (int_fm_filter_stall_req),
  .xtlh_fc_merge_sot_cnt          (int_p_packer_sot_cnt),
  .xtlh_fc_merge_tlp_count        (int_p_packer_tlp_cnt),
  .flit_mode_en                   (flit_mode_en),
  .flit_marker_sent               (int_p_fm_sent),
  .xtlh_fc_merge_pkt_out          (int_p_pkt_out),
  .xtlh_fc_merge_halt_out         (int_packer_p_halt),
  .xtlh_fc_merge_pending          (int_fc_packer_p_pend)
  ,
  .ras_dp_err_log                 (ras_dp_err_log[0])
  ,
  .ras_dp_err_inj                 (ras_dp_err_inj)
  
);

xtlh_fm_filter
 u_fm_filter (
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .flit_mode_en               (flit_mode_en),
  .rstctl_core_flush_req      (rstctl_core_flush_req),
  .p_pkt_in                   (int_p_pkt_out),
  .np_pkt_in                  (int_np_pkt_out),
  .cpl_pkt_in                 (int_cpl_pkt_out),
  .p_halt                     (int_fc_merge_halt_p),
  .np_halt                    (int_fc_merge_halt_np),
  .cpl_halt                   (int_fc_merge_halt_cpl),
  .halt_in                    (halt_in),
  .p_sot_cnt                  (int_p_packer_sot_cnt),
  .np_sot_cnt                 (int_np_packer_sot_cnt),
  .cpl_sot_cnt                (int_cpl_packer_sot_cnt),
  .p_tlp_cnt                  (int_p_packer_tlp_cnt),
  .np_tlp_cnt                 (int_np_packer_tlp_cnt),
  .cpl_tlp_cnt                (int_cpl_packer_tlp_cnt),
  .xtlh_fm_filter_p_pkt       (int_fm_filter_p_pkt),
  .xtlh_fm_filter_np_pkt      (int_fm_filter_np_pkt),
  .xtlh_fm_filter_cpl_pkt     (int_fm_filter_cpl_pkt),
  .xtlh_fm_filter_p_halt      (int_fm_filter_p_halt),
  .xtlh_fm_filter_np_halt     (int_fm_filter_np_halt),
  .xtlh_fm_filter_cpl_halt    (int_fm_filter_cpl_halt),
  .xtlh_fm_filter_stall_req   (int_fm_filter_stall_req)
);

xtlh_response
 #(
  .P_MAX_IF (P_NUM_P_IF_VC)
) u_p_response (
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .halt_in                  (int_fm_filter_p_halt),
  .flit_mode                (flit_mode_en),
  .xtlh_response_block_tlp  (int_block_posted_tlp),
  .pkt_in                   (int_fc_merge_p_pkt_out),
  .xtlh_response_rsp        (int_posted_tlp_sent)
);

assign int_np_packer_stall_req = flit_mode_en && 
                                ((int_fm_filter_p_pkt.dv && int_fc_merge_halt_p) 
                                || ( int_fm_filter_cpl_pkt.dv && int_fc_merge_halt_cpl));

// Non Posted
xtlh_fc_merge
 #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+1)
) u_np_packer (
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .lp_req                         (int_lp_req_to_packer),
  .fc_init_done                   (fc_init_done),
  .rstctl_core_flush_req          (rstctl_core_flush_req),
  .cons_packet_limit              (cfg_tx_arb_control[3:2]),
  .stall_req_in                   (int_np_packer_stall_req),
  .block_req_in                   (1'b0),
  .halt_in                        (int_fm_filter_np_halt),
  .pkt_in                         (int_nfm_arb_np_pkt_in),
  .intf                           (np_intf),
  .xtlh_fc_merge_pkt_sot_last     (int_np_packer_sot_last),
  .xtlh_fc_merge_pkt_eot_last     (int_np_packer_eot_last),
  .flit_pack_limit                (int_fm_filter_stall_req),
  .xtlh_fc_merge_sot_cnt          (int_np_packer_sot_cnt),
  .xtlh_fc_merge_tlp_count        (int_np_packer_tlp_cnt),
  .flit_mode_en                   (flit_mode_en),
  .flit_marker_sent               (int_np_fm_sent),
  .xtlh_fc_merge_pkt_out          (int_np_pkt_out),
  .xtlh_fc_merge_halt_out         (int_packer_np_halt),
  .xtlh_fc_merge_pending          (int_fc_packer_np_pend)
  ,
  .ras_dp_err_log                 (ras_dp_err_log[1])
  ,
  .ras_dp_err_inj                 (ras_dp_err_inj)
);

assign int_cpl_packer_stall_req = flit_mode_en && 
                                  (( int_fm_filter_np_pkt.dv && int_fc_merge_halt_np)
                                  || (int_fm_filter_p_pkt.dv && int_fc_merge_halt_p));

// CPL
xtlh_fc_merge
 #(
  .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+1+1)
) u_cpl_packer (
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .lp_req                         (int_lp_req_to_packer),
  .fc_init_done                   (fc_init_done),
  .rstctl_core_flush_req          (rstctl_core_flush_req),
  .cons_packet_limit              (cfg_tx_arb_control[1:0]),
  .stall_req_in                   (int_cpl_packer_stall_req),
  .block_req_in                   (1'b0),
  .halt_in                        (int_fm_filter_cpl_halt),
  .pkt_in                         (int_nfm_arb_cpl_pkt_in),
  .intf                           (cpl_intf),
  .xtlh_fc_merge_pkt_sot_last     (int_cpl_packer_sot_last),
  .xtlh_fc_merge_pkt_eot_last     (int_cpl_packer_eot_last),
  .flit_pack_limit                (int_fm_filter_stall_req),
  .xtlh_fc_merge_sot_cnt          (int_cpl_packer_sot_cnt),
  .xtlh_fc_merge_tlp_count        (int_cpl_packer_tlp_cnt),
  .flit_mode_en                   (flit_mode_en),
  .flit_marker_sent               (int_cpl_fm_sent),
  .xtlh_fc_merge_pkt_out          (int_cpl_pkt_out),
  .xtlh_fc_merge_halt_out         (int_packer_cpl_halt),
  .xtlh_fc_merge_pending          (int_fc_packer_cpl_pend)
  ,
  .ras_dp_err_log                 (ras_dp_err_log[2])
  ,
  .ras_dp_err_inj                 (ras_dp_err_inj)
);


assign int_fc_merge_halt_p = int_fc_arb_halt_p;
assign int_fc_merge_halt_np = int_fc_arb_halt_np;
assign int_fc_merge_halt_cpl = int_fc_arb_halt_cpl;
assign int_fc_merge_p_pkt_out = int_fm_filter_p_pkt;
assign int_fc_merge_np_pkt_out = int_fm_filter_np_pkt;
assign int_fc_merge_cpl_pkt_out = int_fm_filter_cpl_pkt;

// Instantiate the single VC FC merge module
xtlh_svc_fc_merge
 u_svc_fc_merge (
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .halt_in                        (halt_in),
  .p_pkt_in                       (int_fc_merge_p_pkt_out),
  .np_pkt_in                      (int_fc_merge_np_pkt_out),
  .cpl_pkt_in                     (int_fc_merge_cpl_pkt_out),
  .rstctl_core_flush_req          (rstctl_core_flush_req),
  .xtlh_svc_fc_merge_pending      (int_svc_merge_pending),
  .p_pkt_sot_last                 (int_p_packer_sot_last),
  .p_pkt_eot_last                 (int_p_packer_eot_last),
  .np_pkt_sot_last                (int_np_packer_sot_last),
  .np_pkt_eot_last                (int_np_packer_eot_last),
  .cpl_pkt_sot_last               (int_cpl_packer_sot_last),
  .cpl_pkt_eot_last               (int_cpl_packer_eot_last),
  .flit_mode_en                   (flit_mode_en),
  .flit_marker_sent               (flit_marker_sent),
  .xtlh_svc_fc_merge_p_fm_pend    (int_svc_fc_merge_p_fm_pend),
  .xtlh_svc_fc_merge_np_fm_pend   (int_svc_fc_merge_np_fm_pend),
  .xtlh_svc_fc_merge_cpl_fm_pend  (int_svc_fc_merge_cpl_fm_pend),
  .xtlh_svc_fc_merge_halt_p       (int_fc_arb_halt_p),
  .xtlh_svc_fc_merge_halt_np      (int_fc_arb_halt_np),
  .xtlh_svc_fc_merge_halt_cpl     (int_fc_arb_halt_cpl),
  .xtlh_svc_fc_merge_pkt_out      (xtlh_vc_packer_pkt),
  .xtlh_svc_fc_merge_next_sot_cnt (xtlh_vc_packer_next_sot_cnt)
);

endmodule
