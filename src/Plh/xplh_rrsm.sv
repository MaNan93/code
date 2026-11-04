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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_rrsm.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH RRSM
//
// Description: This module implements the remote retry state machine.
// Generate retry request based on received Nak's.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_rrsm
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::CMD_RESET;
  import  xplh_pkg::retry_req_struct;
  import  xplh_pkg::P_TX_SEQNUM_WD;
#(
  parameter TP = `TP
) (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                           core_clk,
  input                           core_rst_n,
  // -------------------------------------------------------------------------------------
  // Command Interface 
  // -------------------------------------------------------------------------------------
  input tx_cmd_struct             xmlh_xplh_cmd,
  // -------------------------------------------------------------------------------------
  // Replay Interface 
  // -------------------------------------------------------------------------------------
  input replay_cmd_t              rcvd_replay_cmd,      // Filtered Replay Command
  input                           rcvd_valid_acknak,    // Replay Command Valid
  // -------------------------------------------------------------------------------------
  // Replay Timeout Occured
  // -------------------------------------------------------------------------------------
  input                           replay_timeout,       // Replay Timeout
  // -------------------------------------------------------------------------------------
  // Retry Buffer Interface
  // -------------------------------------------------------------------------------------
  input                           hold_rrsm,            // Hold in wait done
  input                           rbuf_empty_retry,     // Retry in empty retry state
  input                           rbuf_empty,           // Retry Buffer Empty
  output  retry_req_struct        xplh_rrsm_retry_req,  // Retry Request
  output  logic                   xplh_rrsm_pending,    // Retry Request pending
  input                           replay_in_progress    // Indicates that all Flits from the retry buffer have been replayed
);

// Logic Declarations
retry_req_struct  int_rrsm_retry_req;
logic             int_rcvd_valid_acknak_r;
logic             int_rbuf_empty_r;
logic             int_rbuf_empty_fe;
replay_cmd_t      int_rcvd_replay_cmd_r;

// RRSM State
typedef enum {
  IDLE,
  REQ_RETRY,
  WAIT_DONE
} rrsm_state_e;

rrsm_state_e next_state, state_r;

// Delay the nak indication to align to retry buffer payload counter update
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_rcvd_valid_acknak_r <= #TP '0;
    int_rcvd_replay_cmd_r   <= #TP REPLAY_00;
    int_rbuf_empty_r        <= #TP '0;
  end else begin
    int_rcvd_valid_acknak_r <= #TP rcvd_valid_acknak;
    int_rcvd_replay_cmd_r   <= #TP rcvd_valid_acknak ? rcvd_replay_cmd : int_rcvd_replay_cmd_r;
    int_rbuf_empty_r        <= #TP rbuf_empty;
  end
end

assign int_rbuf_empty_fe = !rbuf_empty && int_rbuf_empty_r;

assign xplh_rrsm_pending = (next_state == REQ_RETRY);

// State Machine
always_comb begin : rrsm_state_PROC
  next_state = state_r;
  case (state_r)
    // Request retry and move to WAIT_DONE if replay is in progress
    REQ_RETRY : begin
      if(rbuf_empty_retry)
        next_state = IDLE;
      else if(replay_in_progress)
        next_state = WAIT_DONE;
      else
        next_state = REQ_RETRY;
    end
    // Wait for the retry to be completed
    WAIT_DONE : begin
      if(!(replay_in_progress || hold_rrsm))
        next_state = IDLE;
      else
        next_state = WAIT_DONE;
    end
    default : begin // IDLE
      // Explicit sequence sent is response to NAK for empty retry buffer hold off on retry request until nak ignore window starts.
      // If receiver has received an ACK hold off on scheduling replay until the next Nak
      if(hold_rrsm)
        next_state = IDLE;
      // Nak Received or Replay Timeout and there are entries in the retry buffer
      // The rbuf_empty updates when payload flit is written so need to register the status to avoid race condition
      // between received Nak and transmitted payload
      else if(replay_timeout || ((int_rcvd_replay_cmd_r inside {NAK_10, NAK_11}) && int_rcvd_valid_acknak_r && !rbuf_empty_retry && !(rbuf_empty || int_rbuf_empty_fe)))
        next_state = REQ_RETRY;
      else
        next_state = IDLE;
    end
  endcase
end : rrsm_state_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : state_PROC
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      state_r <= #TP IDLE;
    else
      state_r <= #TP next_state;
  end
end : state_PROC

// Request retry of Flits to the retry buffer
always_comb begin : retry_req_PROC
  // Update the retry request
  if(state_r == REQ_RETRY) begin
    int_rrsm_retry_req.replay_scheduled = 1'b1;
    if(replay_timeout)
      int_rrsm_retry_req.replay_cmd = NAK_10;
    else
      int_rrsm_retry_req.replay_cmd = int_rcvd_replay_cmd_r;
  end else
    int_rrsm_retry_req = '0;
end : retry_req_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : retry_req_sync_PROC
  if(!core_rst_n)
    xplh_rrsm_retry_req <= #TP '0;
  else begin
    xplh_rrsm_retry_req.replay_scheduled <= #TP int_rrsm_retry_req.replay_scheduled;
    // Hold replay scheduled type if there is a replay in progress
    if(replay_in_progress)
      xplh_rrsm_retry_req.replay_cmd <= #TP xplh_rrsm_retry_req.replay_cmd;
    else
      xplh_rrsm_retry_req.replay_cmd <= #TP int_rrsm_retry_req.replay_cmd;
  end
end : retry_req_sync_PROC

endmodule
