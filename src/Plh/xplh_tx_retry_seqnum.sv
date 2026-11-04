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
// ---   $DateTime: 2024/01/12 11:11:14 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_tx_retry_seqnum.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Transmitter Flit Replay Sequnece Number
//
// Description: This module tracks the transmitter replay sequence number. 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_tx_retry_seqnum
  import  xplh_pkg::P_TX_SEQNUM_WD;
  import  xplh_pkg::P_MAX_UNACKNOWLEDGED_FLITS;
  import  xplh_pkg::seqnum_plus_1;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::x_minus_y_mod_1023;
#(
  parameter TP = `TP
) 
                             (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                                   core_clk,
  input                                   core_rst_n,
  // -------------------------------------------------------------------------------------
  // Received ACK/NAK 
  // -------------------------------------------------------------------------------------
  input [P_TX_SEQNUM_WD - 1 : 0]          nak_ignore_seqnum,    // Nak Ignore Sequence Number
  input replay_cmd_t                      rcvd_replay_cmd,      // Filtered Replay Command
  input                                   rcvd_valid_acknak,    // Replay Command Valid
  input [P_TX_SEQNUM_WD - 1 : 0]          rcvd_seqnum,          // Sequence Number
  input [P_TX_SEQNUM_WD - 1 : 0]          ackd_seqnum,          // Acknowledged Sequence Number
  // -------------------------------------------------------------------------------------
  // Replay Timeout due to max unacknowledged flits
  // -------------------------------------------------------------------------------------
  input                                   replay_timeout,       // Maximum unacknowledged Flits expired
  // -------------------------------------------------------------------------------------
  // Replay Flags
  // -------------------------------------------------------------------------------------
  input                                   replay_scheduled,     // Replay scheduled flag
  input                                   replay_in_progress,   // Replay in progress
  input                                   replay_pending,       // NAK processed and replay will be scheduled hold off updates to retry sequence number
  // -------------------------------------------------------------------------------------
  // Transmitter Flit Replay Sequence Number
  // -------------------------------------------------------------------------------------
  output  logic [P_TX_SEQNUM_WD - 1 : 0]  xplh_tx_replay_seqnum // Transmitter Replay Sequence Number
);

localparam P_SEQNUM_RST_VAL = {P_TX_SEQNUM_WD{1'b0}};

logic [P_TX_SEQNUM_WD - 1 : 0]  int_tx_replay_seqnum_s;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_modulo_val_s;
logic                           int_replay_in_progress_r;
logic                           int_replay_in_progress_fe;
logic                           int_block_seqnum_upd;
replay_cmd_t                    int_replay_cmd_r;

// Latch the Replay Command 
always_ff @(posedge core_clk or negedge core_rst_n) begin : nak_seqnum_PROC
  if(!core_rst_n)
    int_replay_cmd_r    <= #TP REPLAY_00;
  else begin
    if(rcvd_valid_acknak)
      int_replay_cmd_r  <= #TP rcvd_replay_cmd;
  end
end : nak_seqnum_PROC

// Replay pending when updated NAK is received prevent update of TX REPLAY SEQNUM
assign int_block_seqnum_upd = (int_replay_cmd_r inside {NAK_10, NAK_11}) && replay_pending && !(rcvd_seqnum == ackd_seqnum);

// Transmitter Replay Flit Sequence Number
always_comb begin : tx_replay_seq_PROC
  int_tx_replay_seqnum_s = xplh_tx_replay_seqnum;
  // Replay Schedule Rule 0
  // MAX_UNACKNOWLEDGED Flits transmitter replay sequence number is Ack'd sequence number + 1
  if(replay_timeout) begin
    if(!(replay_scheduled || replay_in_progress))
      int_tx_replay_seqnum_s = seqnum_plus_1(ackd_seqnum);
  end
  // Replay Schedule Rule 2
  // Capture the value of the nak ignore sequence number when replay in progress goes low
  else if(int_replay_in_progress_fe && !rcvd_valid_acknak)
    int_tx_replay_seqnum_s = seqnum_plus_1(nak_ignore_seqnum);
  // If previous nak was 11 and we change to 10 dont change the tx replay sequence number if replay is scheduled or in progress
  else if((int_replay_cmd_r == NAK_11) && (rcvd_replay_cmd == NAK_10) && rcvd_valid_acknak && (rcvd_seqnum == xplh_tx_replay_seqnum) && (replay_scheduled || replay_in_progress))
    int_tx_replay_seqnum_s = xplh_tx_replay_seqnum;
  // Replay Schedule Rule 1
  // Received NAK for Payload Flit update the transmitter replay sequence number with the Nak'd sequence number
  else if(rcvd_replay_cmd inside {NAK_10, NAK_11} && rcvd_valid_acknak && !int_block_seqnum_upd) begin
    if(!(replay_scheduled || replay_in_progress))
      int_tx_replay_seqnum_s = seqnum_plus_1(rcvd_seqnum);
  end
  // If Transmitter Flit Replay Sequence Number is greater than 0 and Ack - Replay Seqnum % 1023 < MAX_UNACKNOWLEDGED_FLITS
  else if(rcvd_valid_acknak && (rcvd_replay_cmd == ACK) && !replay_pending) begin
    int_modulo_val_s = x_minus_y_mod_1023(rcvd_seqnum, xplh_tx_replay_seqnum);
    if(int_modulo_val_s < P_MAX_UNACKNOWLEDGED_FLITS)
      int_tx_replay_seqnum_s = P_SEQNUM_RST_VAL;
  end
  else 
    int_tx_replay_seqnum_s = xplh_tx_replay_seqnum;
end : tx_replay_seq_PROC

assign int_replay_in_progress_fe = !replay_in_progress && int_replay_in_progress_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_replay_seq_sync_PROC
  if(!core_rst_n) begin
    xplh_tx_replay_seqnum     <= #TP {P_TX_SEQNUM_WD{1'b0}};
    int_replay_in_progress_r  <= #TP '0;
  end else begin
    int_replay_in_progress_r  <= #TP replay_in_progress;
    if(!(replay_scheduled || replay_in_progress))
      xplh_tx_replay_seqnum   <= #TP int_tx_replay_seqnum_s;
  end
end : tx_replay_seq_sync_PROC


endmodule
