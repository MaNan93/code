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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #8 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_retry.sv#8 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Retry
//
// Description: This module contains the local retry state machine (xplh_lrsm)
// and the remote retry state machine (xplh_rrsm).
// XPLH_LRSM tells xplh_control when to insert an Ack or Nak into a Flit.
// XPLH_RRSM tells xplh_retrybuf when to replay Flits.
// XPLH_RETRYBUF retries Flits from the retry buffer
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xplh_retry
  import  xplh_pkg::P_TX_SEQNUM_WD;
  import  xplh_pkg::P_MAX_UNACKNOWLEDGED_FLITS;
  import  xplh_pkg::payload_cnt_struct;
  import  xplh_pkg::retry_req_struct;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::P_RBUF_WD;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::rbuf_struct;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP = `TP
  ,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0
) 
                   (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                                     core_clk,                       // Core clock
  input                                     core_rst_n,                     // Active low asynchronous reset
  input                                     spif_enable,                    // SPIF Enable
  input                                     xplh_nop_phy_eof,               // Physical Layer NOP flit EOF cycle is accepted by XPLH Control
  input                                     xplh_stall_req,                 // Stall request on SPIF interface
  input                                     xplh_stall_ack,                 // Stall acknowledge on SPIF interface
  input                                     cxl_mode_enable,                // Flit Mode Interface - CXL Link Enabled
  // -------------------------------------------------------------------------------------
  // cxl viral interface
  // -------------------------------------------------------------------------------------
  input                                     cxl_viral_err,                  // Viral request from cxl controller
  output                                    cxl_viral_crc_marker_eof,       // used for crc place holder assertion checks in if_tx_fm
  // -------------------------------------------------------------------------------------
  // RPLH Interface
  // -------------------------------------------------------------------------------------
  input  [P_TX_SEQNUM_WD - 1 : 0]           rplh_req_seqnum,                // RPLH receiver sequence number
  input  replay_cmd_t                       rplh_req_replay_cmd,            // RPLH requests to send an Ack
  input                                     rplh_req_acknak_valid,          // RPLH request is valid
  input  replay_cmd_t                       rplh_rcvd_replay_cmd,           // RPLH received an Ack
  input  [P_TX_SEQNUM_WD - 1 : 0]           rplh_rcvd_seqnum,               // Received ACK/NAK sequence number
  input                                     rplh_rcvd_acknak_valid,         // RPLH request is valid
  // -------------------------------------------------------------------------------------
  // XPLH Control Interface
  // -------------------------------------------------------------------------------------
  output  replay_cmd_t                      xplh_retry_replay_cmd,          // Replay Command for the Ack/Nak
  output  logic [P_TX_SEQNUM_WD - 1 : 0]    xplh_retry_rcvd_seqnum,         // Sequence number to send in the DLP bytes
  input   [2 : 0]                           xplh_tx_nak_cnt,                // Transmitter Nak Counter
  input                                     xplh_tx_nak_cnt_incr,           // Transmitter Nak Counter about to increment
  input   [1 : 0]                           expl_seq_cnt,                   // Explicit Sequence Number Counter
  output  logic                             xplh_retry_req_rcvry,           // Replay number rollover request transition to recovery
  output  logic                             xplh_retry_replay_num_rollover, // FLIT_REPLAY_NUM Rollover for error logging
  output  logic [P_TX_SEQNUM_WD - 1 : 0]    xplh_retry_replay_seqnum,       // Sequence number of the first flit to be retried in event of replay
  output  logic                             xplh_retry_almost_full,         // Retry buffer is close to full - only send NOPs
  output  logic                             xplh_nak_ignore_link_err,       // Data Link protocol error
  input                                     cdm_ras_des_force_linkdown_noack,// Force link down enable signal
  output  logic                             xplh_retrain_req_link_down,      // Request to LTSSM to go to detect

  // -------------------------------------------------------------------------------------
  // Command Bus Interface
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct                     xmlh_xplh_cmd,                  // Commands from XMLH
  input   tx_cmd_struct                     xplh_xdlh_cmd,                  // Commands from XPLH
  input                                     xplh_control_normal,            // XPLH Control in NORMAL State
  input   [5 : 0]                           link_width,
  // -------------------------------------------------------------------------------------
  // Retry Interface
  // -------------------------------------------------------------------------------------
  input   tx_flit_struct                    xdlh_xplh_flit,                 // Input Flit structure
  output  logic                             xplh_retry_halt_out,            // Halt to upstream module
  input                                     halt_in,                        // Halt from downstream module
  output  tx_flit_struct                    xplh_retry_flit,                // Output Flit structure
  input   [P_TX_SEQNUM_WD-1:0]              tx_seqnum,                      // Transmitter Sequence Number
  output  logic                             xplh_retry_idle,                // Retry buffer idle
  output  logic                             xplh_retry_rbuf_empty,          // retry buffer empty
  output  logic                             xplh_retry_rbuf_empty_retry,    // Retry is in empty retry state
  output  logic                             xplh_retry_nak_11,              // Sent selective replay in response to NAK_11
  output  logic                             xplh_retry_replay_timeout       // Replay Timeout
  ,
  output  ras_dp_err_log_t  [1:0]           xplh_retry_ras_dp_err_log       // RASDP Error Logging
  ,
  input   ras_dp_err_inj_t                  ras_dp_err_inj                  // RASDP Error Injection
  // -------------------------------------------------------------------------------------
  // Retry RAM Interface
  // -------------------------------------------------------------------------------------
  ,
  input   [P_RBUF_WD - 1 : 0]               retryram_data,                  // Retry RAM Read Data
  output  rbuf_struct                       xplh_retry_ram_if,              // Retry Buffer Interface Struct
  input   [2 : 0]                           current_data_rate,               // Current Data Rate
  input                                     en_tx_throttling                // Enable TX Throttling
);

// -------------------------------------------------------------------------------------
// Logic & Struct Declarations
// -------------------------------------------------------------------------------------
retry_req_struct                int_rrsm_retry_req;           // Retry request structure
logic                           int_rrsm_pending;
logic                           int_block_replay;
logic                           int_replay_in_progress;       // Replay in progress
replay_cmd_t                    int_nak_ignore_replay_cmd;    // Filtered Replay Command
logic                           int_nak_ignore_valid;         // Replay Command Valid
logic [P_TX_SEQNUM_WD - 1 : 0]  int_nak_ignore_seqnum;        // Nak Ignore Sequence Number
logic [P_TX_SEQNUM_WD - 1 : 0]  int_nak_ignore_retry_seqnum;  // Sequence Number
logic                           int_nak_ignore_req_expl;      // Requet to send explicit sequence number flits
logic                           int_empty_retry;
logic                           int_nak_ignore_clr_rep_num;   // Clear REPLAY_NUM
logic [P_TX_SEQNUM_WD - 1 : 0]  int_nak_ignore_ackd_flits;    // Number of Flits acknowledged by the latest Ack/Nak
logic                           int_retry_sent_pyld_expl;     // Retry buffer sent explicit payload flit
logic [P_TX_SEQNUM_WD - 1 : 0]  int_ackd_seqnum;              // Acknowledged Sequence Number
logic                           int_hold_rrsm;                // This signal is used to hold the RRSM in state until nak ignore window started
replay_cmd_t                    int_retry_replay_cmd_r;       // Received replay command
logic [P_TX_SEQNUM_WD - 1 : 0]  int_retry_rcvd_seqnum_r;      // Received sequence number
logic                           int_replay_timeout_eof;
logic                           int_replay_timout_halt_in;
logic                           int_xplh_retry_almost_full;
logic                           cxl_inband_ctrl_r, cxl_inband_ctrl_nxt;
logic                           cxl_vir_inband_mark_crc;   // viral inband control flit marked for corruption at eof
tx_flit_struct                  int_rbuf_flit_in;
logic                           int_rbuf_halt_out;
tx_flit_struct                  int_xdlh_xplh_flit;
logic                           int_xdlh_xplh_halt;

// In SPIF mode, if Retry Buffer is almost full then halt the link layer and gate the flit interface.
// When stall_req is asserted and Retry Buffer is almost full, allow flits on the interface until 
// the link layer acknowledges stall request after flushing the interface.
assign int_xdlh_xplh_flit     = (spif_enable && int_xplh_retry_almost_full && (xplh_stall_req ? xplh_stall_ack : 1'b1)) ? '0 : xdlh_xplh_flit;
assign xplh_retry_halt_out    = (spif_enable && int_xplh_retry_almost_full && (xplh_stall_req ? xplh_stall_ack : 1'b1)) || int_xdlh_xplh_halt;
// In SPIF, do not propagate Retry Buffer almost full flag on the XPLH interface to the transaction layer.
// This functionality is implemented by de-asserting pl_trdy on SPIF interface when Retry Buffer is almost full.
assign xplh_retry_almost_full = spif_enable ? 1'b0 : int_xplh_retry_almost_full;

// -------------------------------------------------------------------------------------
// Replay Nak Ignore Window
// -------------------------------------------------------------------------------------
xplh_nak_ignore
 u_xplh_nak_ignore(
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  .xdlh_xplh_flit               (int_xdlh_xplh_flit),
  .xmlh_xplh_cmd                (xmlh_xplh_cmd),
  .rplh_rcvd_replay_cmd         (rplh_rcvd_replay_cmd),
  .rplh_rcvd_valid              (rplh_rcvd_acknak_valid),
  .rplh_rcvd_seqnum             (rplh_rcvd_seqnum),
  .replay_timeout               (xplh_retry_replay_timeout),
  .rbuf_empty                   (xplh_retry_rbuf_empty),
  .replay_scheduled             (int_rrsm_retry_req.replay_scheduled),
  .tx_seqnum                    (tx_seqnum),
  .tx_replay_seqnum             (xplh_retry_replay_seqnum),
  .rbuf_sent_pyld_expl          (int_retry_sent_pyld_expl),
  .current_data_rate            (current_data_rate),
  .link_width                   (link_width),
  .replay_pending               (int_rrsm_pending),
  .xplh_nak_ignore_ackd_flits   (int_nak_ignore_ackd_flits),
  .xplh_nak_ignore_replay_cmd   (int_nak_ignore_replay_cmd),
  .xplh_nak_ignore_valid        (int_nak_ignore_valid),
  .xplh_nak_ignore_seqnum       (int_nak_ignore_seqnum),
  .xplh_nak_ignore_retry_seqnum (int_nak_ignore_retry_seqnum),
  .xplh_nak_ignore_ackd_seqnum  (int_ackd_seqnum),
  .xplh_nak_ignore_link_err     (xplh_nak_ignore_link_err),
  .xplh_nak_ignore_req_expl     (int_nak_ignore_req_expl),
  .xplh_nak_ignore_clr_rep_num  (int_nak_ignore_clr_rep_num)
);

// -------------------------------------------------------------------------------------
// Requested ACK/NAK for received Flits
// -------------------------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin : rcvd_seqnum_PROC
  if(!core_rst_n) begin
    int_retry_replay_cmd_r      <= #TP replay_cmd_t'(0);
    int_retry_rcvd_seqnum_r     <= #TP '0;
  end
  else begin
    if(rplh_req_acknak_valid) begin
      if(rplh_req_replay_cmd inside {ACK, NAK_10, NAK_11}) begin
        int_retry_replay_cmd_r  <= #TP rplh_req_replay_cmd;
        int_retry_rcvd_seqnum_r <= #TP rplh_req_seqnum;
      end else begin
        int_retry_replay_cmd_r  <= #TP int_retry_replay_cmd_r;
        int_retry_rcvd_seqnum_r <= #TP int_retry_rcvd_seqnum_r;
      end
    end
  end
end : rcvd_seqnum_PROC

assign xplh_retry_replay_cmd = (rplh_req_replay_cmd inside {ACK, NAK_10, NAK_11}) ? rplh_req_replay_cmd : int_retry_replay_cmd_r;
assign xplh_retry_rcvd_seqnum = (rplh_req_replay_cmd inside {ACK, NAK_10, NAK_11}) ? rplh_req_seqnum : int_retry_rcvd_seqnum_r;

// -------------------------------------------------------------------------------------
// Remote Retry State Machine
// -------------------------------------------------------------------------------------
xplh_rrsm
 u_xplh_rrsm (
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .rbuf_empty_retry       (int_empty_retry),
  .xmlh_xplh_cmd          (xmlh_xplh_cmd),
  .rcvd_replay_cmd        (int_nak_ignore_replay_cmd),
  .rcvd_valid_acknak      (int_nak_ignore_valid),
  .replay_timeout         (xplh_retry_replay_timeout),
  .replay_in_progress     (int_replay_in_progress),
  .xplh_rrsm_retry_req    (int_rrsm_retry_req),
  .xplh_rrsm_pending      (int_rrsm_pending),
  .hold_rrsm              (int_hold_rrsm),
  .rbuf_empty             (xplh_retry_rbuf_empty)
);

// -------------------------------------------------------------------------------------
// FLIT_REPLAY_NUM
// -------------------------------------------------------------------------------------
xplh_replay_num
 u_replay_num(
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .xmlh_xplh_cmd            (xmlh_xplh_cmd),
  .clr_rep_num              (int_nak_ignore_clr_rep_num),
  .replay_scheduled         (int_rrsm_retry_req.replay_scheduled),
  .current_data_rate        (current_data_rate),
  .xplh_replay_num_rcvry    (xplh_retry_req_rcvry),
  .xplh_replay_num_rollover (xplh_retry_replay_num_rollover),
  .xplh_replay_num_block    (int_block_replay)
);

// -------------------------------------------------------------------------------------
// FLIT_RETRAIN
// -------------------------------------------------------------------------------------
  xplh_retrain
   u_retrain(
  .core_clk                         (core_clk),
  .core_rst_n                       (core_rst_n),
  .cdm_ras_des_force_linkdown_noack (cdm_ras_des_force_linkdown_noack),
  .replay_num_rollover              (xplh_retry_replay_num_rollover),
  .xmlh_xplh_cmd                    (xmlh_xplh_cmd),       
  .ack_nak_upd                      (int_nak_ignore_clr_rep_num),
  .xplh_retrain_req_link_down       (xplh_retrain_req_link_down)              
); 

// -------------------------------------------------------------------------------------
// REPLAY_TIMEOUT_FLIT_COUNT
// -------------------------------------------------------------------------------------
// For SPIF, if xplh_nop_generator is active then use its accepted output eof to drive replay_timeout
assign int_replay_timeout_eof    = (spif_enable && xplh_nop_phy_eof) ? 1'b1 : xplh_retry_flit.eof[1];
assign int_replay_timout_halt_in = (spif_enable && xplh_nop_phy_eof) ? 1'b0 : halt_in;

xplh_replay_timeout
 u_replay_timeout(
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .eof                      (int_replay_timeout_eof),
  .halt_in                  (int_replay_timout_halt_in),
  .clr_rep_timeout          (int_nak_ignore_clr_rep_num),
  .rbuf_empty               (xplh_retry_rbuf_empty),
  .replay_scheduled         (int_rrsm_retry_req.replay_scheduled),
  .replay_in_progress       (int_replay_in_progress),
  .xplh_replay_timeout_err  (xplh_retry_replay_timeout)
);

// -------------------------------------------------------------------------------------
// Transmiter Flit Replay Sequence Number
// -------------------------------------------------------------------------------------
xplh_tx_retry_seqnum
 u_tx_retry_seqnum(
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .rcvd_replay_cmd        (int_nak_ignore_replay_cmd),
  .rcvd_valid_acknak      (int_nak_ignore_valid),
  .rcvd_seqnum            (int_nak_ignore_retry_seqnum),
  .ackd_seqnum            (int_ackd_seqnum),
  .replay_timeout         (xplh_retry_replay_timeout),
  .replay_scheduled       (int_rrsm_retry_req.replay_scheduled),
  .replay_in_progress     (int_replay_in_progress),
  .replay_pending         (int_rrsm_pending),
  .nak_ignore_seqnum      (int_nak_ignore_seqnum),
  .xplh_tx_replay_seqnum  (xplh_retry_replay_seqnum)
);


// -------------------------------------------------------------------------------------
// TX Throttling for selective replay 
// -------------------------------------------------------------------------------------
logic int_tx_sel_replay;
assign int_tx_sel_replay = xplh_retry_nak_11 && !halt_in && xplh_retry_flit.eof[1];

xplh_tx_throttle
 u_tx_throttle(
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .cfg_tx_throttling      (en_tx_throttling),
  .flit_in                (int_xdlh_xplh_flit),
  .halt_in                (int_rbuf_halt_out),
  .xplh_tx_throttle_flit  (int_rbuf_flit_in),
  .xplh_tx_throttle_halt  (int_xdlh_xplh_halt),
  .rcvd_replay_cmd        (int_nak_ignore_replay_cmd),
  .rcvd_seqnum            (int_nak_ignore_retry_seqnum),
  .rcvd_valid             (int_nak_ignore_valid),
  .tx_seqnum              (tx_seqnum),
  .tx_sel_replay          (int_tx_sel_replay),
  .replay_in_progress     (int_replay_in_progress)
);

// -------------------------------------------------------------------------------------
// Retry Buffer FSM 
// -------------------------------------------------------------------------------------
assign xplh_retry_rbuf_empty_retry = int_empty_retry;

xplh_retrybuf
 #(
  .RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE)
) u_xplh_retrybuf (
  .core_clk                         (core_clk),
  .core_rst_n                       (core_rst_n),
  .xplh_retrybuf_empty_retry        (int_empty_retry),
  .nak_ignore_req_expl              (int_nak_ignore_req_expl),
  .block_replay                     (int_block_replay),
  .spif_enable                      (spif_enable),
  .xplh_nop_phy_eof                 (xplh_nop_phy_eof),
  .cxl_viral_err                    (cxl_viral_err),
  .cxl_vir_inband_mark_crc          (cxl_vir_inband_mark_crc),
  .flit_in                          (int_rbuf_flit_in),
  .tx_nak_cnt                       (xplh_tx_nak_cnt),
  .tx_nak_cnt_incr                  (xplh_tx_nak_cnt_incr),
  .halt_in                          (halt_in),
  .xplh_retrybuf_flit_out           (xplh_retry_flit),
  .xplh_retrybuf_sent_pyld_expl     (int_retry_sent_pyld_expl),
  .xplh_retrybuf_halt_out           (int_rbuf_halt_out),
  .retry_req                        (int_rrsm_retry_req),
  .ackd_flits                       (int_nak_ignore_ackd_flits),
  .retryram_data                    (retryram_data),
  .xplh_retrybuf_ram_if             (xplh_retry_ram_if),
  .xplh_retrybuf_replay_in_progress (int_replay_in_progress),
  .xplh_retrybuf_empty              (xplh_retry_rbuf_empty),
  .xplh_retrybuf_nak_11             (xplh_retry_nak_11),
  .xplh_retrybuf_af                 (int_xplh_retry_almost_full),
  .xplh_retrybuf_idle               (xplh_retry_idle),
  .xmlh_xplh_cmd                    (xmlh_xplh_cmd),
  .xplh_xdlh_cmd                    (xplh_xdlh_cmd),
  .expl_seq_cnt                     (expl_seq_cnt),
  .xplh_control_normal              (xplh_control_normal),
  .xplh_retrybuf_hold_rrsm          (int_hold_rrsm)
  ,
  .xplh_retrybuf_ras_dp_err_log     (xplh_retry_ras_dp_err_log)
  ,
  .ras_dp_err_inj                   (ras_dp_err_inj)
);

// -------------------------------------------------------------------------------------
// detect cxl_viral inband control flit to clear any crc markers when going into retrybuf and to indicate to checkers to disable checking
// -------------------------------------------------------------------------------------
// If viral inband control flit is marked for CRC corruption: send downstream to disable selective retry, but clear CRC corruption marker when added to retrybuf
assign cxl_vir_inband_mark_crc = cxl_inband_ctrl_r && (  xdlh_xplh_flit.eof[1]);

// input to itf_tx_fm checkers
assign cxl_viral_crc_marker_eof = cxl_viral_err || cxl_vir_inband_mark_crc;

always_comb begin
  // detect cxl viral inband control flit at sof
  if (!xplh_retry_halt_out && xdlh_xplh_flit.eof[1] && xdlh_xplh_flit.data_valid && cxl_viral_err)
    cxl_inband_ctrl_nxt = 1'b1;
  else if (!xplh_retry_halt_out && xdlh_xplh_flit.eof[1] && xdlh_xplh_flit.data_valid)
    cxl_inband_ctrl_nxt = 1'b0;
  else 
    cxl_inband_ctrl_nxt = cxl_inband_ctrl_r;  
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    cxl_inband_ctrl_r <= #TP 1'b0;
  else
    cxl_inband_ctrl_r <= #TP cxl_inband_ctrl_nxt;
end
// -------------------------------------------------------------------------------------



endmodule
