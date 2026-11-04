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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_nak_ignore.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH NAK IGNORE
//
// Description: This module implements the nak ignore window. It generates a level signal
// which will be used to mask received Naks and prevent triggering a retry.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_nak_ignore
  import  xplh_pkg::P_GEN6_X8_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN5_X8_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN4_X8_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN3_X8_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN2_X8_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN1_X8_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN6_X4_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN5_X4_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN4_X4_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN3_X4_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN2_X4_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN1_X4_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN6_X2_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN5_X2_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN4_X2_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN3_X2_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN2_X2_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN1_X2_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN6_X1_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN5_X1_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN4_X1_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN3_X1_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN2_X1_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_GEN1_X1_NAK_IGNORE_VALUE;
  import  xplh_pkg::P_NAK_IGNORE_WD;
  import  xplh_pkg::P_TX_SEQNUM_WD;
  import  xplh_pkg::P_MAX_SEQNUM;
  import  xplh_pkg::P_MAX_UNACKNOWLEDGED_FLITS;
  import  xplh_pkg::retry_req_struct;
  import  xplh_pkg::check_ackd_seqnum;
  import  xplh_pkg::seqnum_plus_1;
  import  xplh_pkg::seqnum_minus_1;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::NOP2_DLLP;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::CMD_RESET;
  import  cx_pl_pkg::CMD_PYLD;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::x_minus_y_mod_1023;
#(
  parameter TP  = `TP
) 
                        (
  input                                   core_clk,
  input                                   core_rst_n,
  input   tx_flit_struct                  xdlh_xplh_flit,               // Input Flit structure
  input   replay_cmd_t                    rplh_rcvd_replay_cmd,         // Replay Command
  input                                   rplh_rcvd_valid,              // Replay Command Valid
  input   [P_TX_SEQNUM_WD - 1 : 0]        rplh_rcvd_seqnum,             // RPLH receiver sequence number
  input   [P_TX_SEQNUM_WD - 1 : 0]        tx_seqnum,                    // Next Transmitter Sequence Number 
  input   [P_TX_SEQNUM_WD - 1 : 0]        tx_replay_seqnum,             // Transmitter Replay Sequence Number 
  input                                   replay_scheduled,             // Replay scheduled
  input                                   replay_timeout,               // Replay timeout
  input   tx_cmd_struct                   xmlh_xplh_cmd,                // Command from Layer1
  input                                   rbuf_sent_pyld_expl,          // Retry buffer sent payload explicit in response to xplh_nak_ignore_req_expl
  input   [2 : 0]                         current_data_rate,            // Current Data Rate
  input   [5 : 0]                         link_width,                   // link width for nak ignore window calculation
  input                                   replay_pending,               // RRSM has pending replay request
  input                                   rbuf_empty,                   // Retry Buffer Empty
  output  logic [P_TX_SEQNUM_WD - 1 : 0]  xplh_nak_ignore_ackd_flits,   // Number of Flits Acknowledged
  output  replay_cmd_t                    xplh_nak_ignore_replay_cmd,   // Filtered Replay Command
  output  logic                           xplh_nak_ignore_valid,        // Replay Command Valid
  output  logic [P_TX_SEQNUM_WD - 1 : 0]  xplh_nak_ignore_retry_seqnum, // Sequence Number to retry
  output  logic [P_TX_SEQNUM_WD - 1 : 0]  xplh_nak_ignore_seqnum,       // NAK Ignore Sequence Number
  output  logic [P_TX_SEQNUM_WD - 1 : 0]  xplh_nak_ignore_ackd_seqnum,  // Sequence Number
  output  logic                           xplh_nak_ignore_link_err,     // Data link protocol error
  output  logic                           xplh_nak_ignore_req_expl,     // Request to send explicit flits
  output  logic                           xplh_nak_ignore_clr_rep_num   // Clear the REPLAY_NUM counter
);

logic [P_TX_SEQNUM_WD - 1 : 0]  int_nak_ignore_seqnum_r;
logic                           int_filt_valid;
logic [P_NAK_IGNORE_WD - 1 : 0] int_nak_ignore_cnt_r;
logic [P_NAK_IGNORE_WD - 1 : 0] int_min_nak_ignore_r;
logic                           int_nak_ignore_exp;
logic                           int_nak_ignore_window;
replay_cmd_t                    int_rcvd_replay_cmd_r;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_rcvd_seqnum_r;
logic                           int_rcvd_valid_r;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_first_rule;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_second_rule;
logic                           int_selective_replay_r;
logic                           timer2;

typedef enum {
  IDLE,       // IDLE state
  START_TIMER // Nak ignore window
} state_e;

state_e next_state, state_r;

// Update the NAK Ignore expiration value dont allow them to update while timer is running.
always_ff @(posedge core_clk or negedge core_rst_n) begin : min_nak_ignore_PROC
  if(!core_rst_n)
    int_min_nak_ignore_r  <= #TP '0;
  else begin
    if(state_r == IDLE) begin
      unique case(link_width)
        6'b001000 : begin
          if(current_data_rate == `GEN1_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN1_X8_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN2_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN2_X8_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN3_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN3_X8_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN4_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN4_X8_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN5_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN5_X8_NAK_IGNORE_VALUE;
          else
            int_min_nak_ignore_r  <= #TP P_GEN6_X8_NAK_IGNORE_VALUE;
        end
        6'b000100 : begin
          if(current_data_rate == `GEN1_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN1_X4_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN2_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN2_X4_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN3_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN3_X4_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN4_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN4_X4_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN5_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN5_X4_NAK_IGNORE_VALUE;
          else
            int_min_nak_ignore_r  <= #TP P_GEN6_X4_NAK_IGNORE_VALUE;
        end
        6'b000010 : begin
          if(current_data_rate == `GEN1_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN1_X2_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN2_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN2_X2_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN3_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN3_X2_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN4_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN4_X2_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN5_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN5_X2_NAK_IGNORE_VALUE;
          else
            int_min_nak_ignore_r  <= #TP P_GEN6_X2_NAK_IGNORE_VALUE;
        end
        default : begin
          if(current_data_rate == `GEN1_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN1_X1_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN2_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN2_X1_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN3_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN3_X1_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN4_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN4_X1_NAK_IGNORE_VALUE;
          else if(current_data_rate == `GEN5_RATE)
            int_min_nak_ignore_r  <= #TP P_GEN5_X1_NAK_IGNORE_VALUE;
          else
            int_min_nak_ignore_r  <= #TP P_GEN6_X1_NAK_IGNORE_VALUE;
        end
      endcase
    end
  end
end : min_nak_ignore_PROC

// Filtering Received Ack/Nak
always_comb begin : ack_nak_rule_PROC
  int_filt_valid = '0;
  xplh_nak_ignore_link_err = '0;
  int_first_rule = '0;
  int_second_rule = '0;
  xplh_nak_ignore_clr_rep_num = rbuf_empty;
  if(rplh_rcvd_valid && (rplh_rcvd_replay_cmd inside {ACK, NAK_10, NAK_11}) && (rplh_rcvd_seqnum > 0) && !(xmlh_xplh_cmd.tx_cmd == CMD_RESET)) begin
    //  ((NEXT_TX_FLIT_SEQ_NUM - 1) - N) mod 1023 <= MAX_UNACKNOWLEDGED_FLITS
    int_first_rule = x_minus_y_mod_1023((tx_seqnum - 1), rplh_rcvd_seqnum);
    //  (N - ACKD_FLIT_SEQ_NUM) mod 1023 <= MAX_UNACKNOWLEDGED_FLITS
    int_second_rule = x_minus_y_mod_1023(rplh_rcvd_seqnum, xplh_nak_ignore_ackd_seqnum);
    if((int_first_rule <= P_MAX_UNACKNOWLEDGED_FLITS) && (int_second_rule <= P_MAX_UNACKNOWLEDGED_FLITS)) begin
      if(int_second_rule > 0) begin
        xplh_nak_ignore_clr_rep_num = '1;
      end
      int_filt_valid = 1'b1;
    end else begin
      int_filt_valid = '0;
      xplh_nak_ignore_link_err = 1'b1;
    end
  end
end : ack_nak_rule_PROC

// Calculate the number of acknowledged Flits
always_ff @(posedge core_clk or negedge core_rst_n) begin : ackd_flits_PROC
  if(!core_rst_n)
    xplh_nak_ignore_ackd_flits  <= #TP '0;
  else begin
    xplh_nak_ignore_ackd_flits  <= #TP '0;
    if(int_filt_valid) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. The
// numbers are checked before the subtraction so there cannot be any underflow here.
      // Check if there are flits to be purged in the retry buffer
      if(check_ackd_seqnum(rplh_rcvd_seqnum, xplh_nak_ignore_ackd_seqnum) && !(replay_pending || replay_scheduled)) begin
        // Due to tx sequence number rollover ackd sequence number is greater than received sequence number
        if(xplh_nak_ignore_ackd_seqnum > rplh_rcvd_seqnum)
          xplh_nak_ignore_ackd_flits <= #TP (P_MAX_SEQNUM - xplh_nak_ignore_ackd_seqnum) + rplh_rcvd_seqnum;
        else
          xplh_nak_ignore_ackd_flits <= #TP (rplh_rcvd_seqnum - xplh_nak_ignore_ackd_seqnum);
      end
// spyglass enable_block W164a
    end
  end
end : ackd_flits_PROC

// Updating Ackd Sequence Number
always_ff @(posedge core_clk or negedge core_rst_n) begin : ackd_seqnum_PROC
  if(!core_rst_n)
    xplh_nak_ignore_ackd_seqnum <= #TP '0;
  else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      xplh_nak_ignore_ackd_seqnum <= #TP '0;
    else if(!(replay_pending || replay_scheduled) && int_filt_valid && (check_ackd_seqnum(rplh_rcvd_seqnum, xplh_nak_ignore_ackd_seqnum)))
      xplh_nak_ignore_ackd_seqnum <= #TP rplh_rcvd_seqnum;
  end
end : ackd_seqnum_PROC

// Selective Replay in progress
always_ff @(posedge core_clk or negedge core_rst_n) begin : sel_replay_PROC
  if(!core_rst_n)
    int_selective_replay_r    <= #TP '0;
  else begin
    // Replay timeout or link down
    if(replay_timeout || (xmlh_xplh_cmd.tx_cmd == CMD_RESET))
      int_selective_replay_r  <= #TP 1'b0;
    else if(int_selective_replay_r && (rplh_rcvd_replay_cmd == NAK_10))
      int_selective_replay_r  <= #TP 1'b0;
    else if((xplh_nak_ignore_replay_cmd == NAK_11) && replay_scheduled)
      int_selective_replay_r  <= #TP 1'b1;
  end
end : sel_replay_PROC

// Nak Ignore Sequence Number
always_ff @(posedge core_clk or negedge core_rst_n) begin : nak_ignore_seqnum_PROC
  if(!core_rst_n) begin
    int_nak_ignore_seqnum_r <= #TP '0;
  end else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET) begin
      int_nak_ignore_seqnum_r <= #TP '0;
    end else if(int_filt_valid) begin
      // Ack received clear the nak ignore sequence number
      if(rplh_rcvd_replay_cmd == ACK)
        int_nak_ignore_seqnum_r <= #TP '0;
      // Nak received
      else if(rplh_rcvd_replay_cmd inside {NAK_10, NAK_11}) begin
        // Selective Replay Scheduled but standard Nak received
        if((rplh_rcvd_replay_cmd == NAK_10) && int_selective_replay_r && (rplh_rcvd_seqnum == int_nak_ignore_seqnum_r) && (tx_replay_seqnum == seqnum_plus_1(rplh_rcvd_seqnum))) begin
          int_nak_ignore_seqnum_r <= #TP '0;
        // Nak received for sequence number other than nak ignore sequence number
        end else if((rplh_rcvd_seqnum != int_nak_ignore_seqnum_r) && !(int_nak_ignore_seqnum_r == '0)) begin
          int_nak_ignore_seqnum_r <= #TP '0;
        // Update the nak ignore sequence number with the received Nak sequence number if Nak Seqnum = Next TX - 1
        end else if(rplh_rcvd_seqnum == seqnum_minus_1(tx_seqnum)) begin
          int_nak_ignore_seqnum_r <= #TP rplh_rcvd_seqnum;
        // Update the nak ignore sequence number in case of replay scheduled rule 1
        end else if(!rbuf_empty) begin
          int_nak_ignore_seqnum_r <= #TP rplh_rcvd_seqnum;
        end else begin
          int_nak_ignore_seqnum_r <= #TP int_nak_ignore_seqnum_r;
        end
      end
    end
  end
end : nak_ignore_seqnum_PROC

assign xplh_nak_ignore_seqnum = int_nak_ignore_window ? '0 : int_nak_ignore_seqnum_r;

// When Nak Ignore Seqnum > 0 and Replay Scheduled is 0 request to send explicit flits
always_ff @(posedge core_clk or negedge core_rst_n) begin : req_expl_PROC
  if(!core_rst_n)
    xplh_nak_ignore_req_expl  <= #TP '0;
  else begin
    // clean if nak ignore sequence number is reset to 0 or replay scheduled or payload explicit flit sent or valid Nak received and retry buffer is no longer empty
    if((int_nak_ignore_seqnum_r == '0) || replay_scheduled || rbuf_sent_pyld_expl || ((int_rcvd_replay_cmd_r inside {NAK_10, NAK_11}) && int_rcvd_valid_r && !rbuf_empty))
      xplh_nak_ignore_req_expl  <= #TP '0;
    else if((int_nak_ignore_seqnum_r != '0) && !replay_scheduled && (xmlh_xplh_cmd.tx_cmd inside {CMD_PYLD, CMD_FLUSH_XTLH}) && rbuf_empty)
      xplh_nak_ignore_req_expl  <= #TP 1'b1;
    else
      xplh_nak_ignore_req_expl  <= #TP xplh_nak_ignore_req_expl;
  end
end : req_expl_PROC

// Nak Ignore FSM
always_comb begin : nak_ignore_fsm
  next_state = state_r;
  case(state_r)
    START_TIMER : begin
      // Nak Ignore Window Expired or Nak for a new Sequence Number or Ack received
      if((int_nak_ignore_seqnum_r == '0) || int_nak_ignore_exp)
        next_state = IDLE;
    end
    default : begin // IDLE
      // Payload flit sent after receiving Nak
      if(rbuf_sent_pyld_expl)
        next_state = START_TIMER;
    end
  endcase
end : nak_ignore_fsm

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      state_r <= #TP IDLE;
    else
      state_r <= #TP next_state;
  end
end

assign int_nak_ignore_window = (state_r == START_TIMER) || ((state_r == IDLE) && (next_state == START_TIMER));
assign int_nak_ignore_exp = (int_nak_ignore_cnt_r >= int_min_nak_ignore_r);

// NAK Ignore Window Timer
DWC_pcie_symbol_timer
 u_gen_timer2
(
  .core_clk           (core_clk)
  ,.core_rst_n        (core_rst_n)
  ,.current_data_rate (current_data_rate)
  ,.cnt_up_en         (timer2)      // timer count-up
);

always_ff @(posedge core_clk or negedge core_rst_n) begin : nak_ignore_cnt_PROC
  if(!core_rst_n)
    int_nak_ignore_cnt_r  <= #TP '0;
  else begin
    if(int_nak_ignore_window)
      int_nak_ignore_cnt_r  <= #TP int_nak_ignore_cnt_r + (timer2 ? 1 : 0);
    else
      int_nak_ignore_cnt_r  <= #TP '0;
  end
end : nak_ignore_cnt_PROC

localparam P_RPLH_PIPE_WD = $bits(rplh_rcvd_replay_cmd) + $bits(rplh_rcvd_seqnum);

delay_n_w_enable

#(1, P_RPLH_PIPE_WD) u_rplh_rcvd_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  ((xmlh_xplh_cmd.tx_cmd == CMD_RESET)),
  .en     (int_filt_valid),
  .din    ({rplh_rcvd_replay_cmd, rplh_rcvd_seqnum}),
  .dout   ({int_rcvd_replay_cmd_r, int_rcvd_seqnum_r})
);

delay_n

#(1, 1) u_rplh_rcvd_valid_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (int_filt_valid),
  .dout   (int_rcvd_valid_r)
);

// Filter out the Naks received during the Ignore Nak Window
always_comb begin : nak_ignore_filt_PROC
  xplh_nak_ignore_replay_cmd = REPLAY_00;
  xplh_nak_ignore_valid = '0;
  xplh_nak_ignore_retry_seqnum = '0;
  // Pass ACK's received
  if((int_rcvd_replay_cmd_r == ACK) && int_rcvd_valid_r) begin
    xplh_nak_ignore_replay_cmd = int_rcvd_replay_cmd_r;
    xplh_nak_ignore_valid = int_rcvd_valid_r;
    xplh_nak_ignore_retry_seqnum = int_rcvd_seqnum_r;
  end
  // Pass NAK's received outside the Nak Ignore Window
  if(!int_nak_ignore_window && ((int_rcvd_replay_cmd_r inside {NAK_10, NAK_11}) && int_rcvd_valid_r)) begin
    xplh_nak_ignore_replay_cmd = int_rcvd_replay_cmd_r;
    xplh_nak_ignore_valid = (int_rcvd_replay_cmd_r == REPLAY_00) ? '0 : int_rcvd_valid_r;
    xplh_nak_ignore_retry_seqnum = int_rcvd_seqnum_r;
  end
end : nak_ignore_filt_PROC


endmodule
