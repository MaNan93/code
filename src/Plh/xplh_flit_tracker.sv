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
// ---   $Revision: #7 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_flit_tracker.sv#7 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// Flit latency tracking module 
// Description: Implements Flit Laltency tracking function that controls the tracking FSMs based on the configurations. 
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_flit_tracker
  import DWC_pcie_core_pkg::xplh_cdm_flit_latency_track_t;
  import DWC_pcie_core_pkg::latency_tracking_status_e;
  import DWC_pcie_core_pkg::IDLE;
  import DWC_pcie_core_pkg::STARTED;
  import DWC_pcie_core_pkg::DONE;
  import DWC_pcie_core_pkg::ERROR;
  import cx_pl_pkg::P_TX_SEQNUM_WD;
  import cx_pl_pkg::replay_cmd_t;
  import cx_pl_pkg::rplh_xplh_fm_retry_t;
  import cx_pl_pkg::ACK;
  import cx_pl_pkg::NAK_10;
  import cx_pl_pkg::NAK_11;
  import cx_pl_pkg::REPLAY_00;
  import cx_pl_pkg::P_REPLAY_CMD_END;
  import cx_pl_pkg::P_DLP0_END;
  import cx_pl_pkg::P_DLP1_END;
  import xplh_pkg::flit_usage_e;
  import xplh_pkg::IDLE_OR_NOP;
  import xplh_pkg::PAYLOAD;
  import xplh_pkg::seqnum_minus_1;
  import xplh_pkg::seqnum_plus_1;
  import  xplh_pkg::P_MAX_UNACKNOWLEDGED_FLITS;
  // Parameters
#(
  parameter DW = `CX_DW
) 
                          (
  // Inputs
  input  core_clk,
  input  core_rst_n,
  input  [2:0] cdm_xplh_flit_response_type,                    // Response type need to be tracked
  input  [1:0] cdm_xplh_flit_type_measured,                    // Flit type need to be tracked
  input  cdm_xplh_flit_track_mode,                             // Tracking mode from the cdm
  input  [P_TX_SEQNUM_WD-1:0] xplh_flit_seq_number,            // Tx flit sequence number
  input  cxl_mode_enable,                                      // CXL mode is enabled
  input  xplh_flit_sof,                                        // XPLH flit sof
  input  [1:0] xplh_flit_eof,                                  // XPLH flit eof
  input  [DW - 1 : 0] xplh_flit_data,                          // XPLH flit data
  input  halt_in,                                              // Downstream Halt
  input  rplh_xplh_fm_retry_t rplh_xplh_fm_retry,              // RPLH retry
  input  [2:0] current_data_rate,                              // Data rate
  input  [2:0] mac_phy_rate,                                   // Mac_Phy Data rate
  // Outputs
  output  xplh_cdm_flit_latency_track_t flit_latency_tracking  //Flit tracking status and latency
);

parameter TP = `TP;  // Clock to Q delay (simulator insurance)

/////////////////////////////////////////////////////////////////
// States definition, measurement enables
latency_tracking_status_e flit_ack_nak_state;
latency_tracking_status_e flit_retry_state;
logic [15:0]  ack_nak_latency_value;
logic [15:0]  retry_latency_value;
logic [15:0]  target_latency_value;
logic        xplh_send_flit_r;
logic  [1:0] xplh_flit_type;
logic  [1:0] xplh_flit_type_r;
replay_cmd_t xplh_replay_cmd;
replay_cmd_t xplh_replay_cmd_r;
logic  [P_TX_SEQNUM_WD-1:0] xplh_nak_seq_number;
logic  [P_TX_SEQNUM_WD-1:0] xplh_nak_seq_number_r;
logic        xplh_send_valid_flit;
logic        xplh_send_valid_flit_r;
logic        xplh_send_flit;
logic  [7:0] int_dlp0;
logic  [7:0] int_dlp1;
logic rplh_received_flit;
logic  [P_TX_SEQNUM_WD-1:0] rplh_flit_rec_seq_number;
logic  [1:0] rplh_flit_rec_replay_cmd;
logic  [P_TX_SEQNUM_WD-1:0] rplh_flit_req_seq_number;
replay_cmd_t rplh_flit_req_replay_cmd;

always_comb begin : dlp_bytes_PROC
  int_dlp0 = 1'b0;
  int_dlp1 = 1'b0;
  xplh_flit_type = xplh_flit_type_r;
  xplh_replay_cmd = xplh_replay_cmd_r;
  xplh_nak_seq_number = xplh_nak_seq_number_r;
  xplh_send_valid_flit = xplh_send_valid_flit_r;
  xplh_send_flit = 1'b0;
  if(cxl_mode_enable) begin
    if(xplh_flit_sof) begin
      int_dlp0 = xplh_flit_data[7:0];
      int_dlp1 = xplh_flit_data[15:8];
      xplh_flit_type = int_dlp0[7:6];
      xplh_replay_cmd = replay_cmd_t'(int_dlp0[3:2]);
      xplh_nak_seq_number = {int_dlp0[1:0], int_dlp1};
      xplh_send_valid_flit = ((xplh_flit_type != IDLE_OR_NOP) && !halt_in);
    end
    if(xplh_flit_eof[0]) begin
      xplh_send_flit = (xplh_send_valid_flit_r && !halt_in);
    end
  end
  else
  if(xplh_flit_eof[0]) begin
    int_dlp0 = xplh_flit_data[P_DLP0_END -: 8];
    int_dlp1 = xplh_flit_data[P_DLP1_END -: 8];
    xplh_flit_type = int_dlp0[7:6];
    xplh_replay_cmd = replay_cmd_t'(xplh_flit_data[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1]);
    xplh_nak_seq_number = {int_dlp0[1:0], int_dlp1};
    xplh_send_valid_flit = ((xplh_flit_type == PAYLOAD) && !halt_in);
    xplh_send_flit = xplh_send_valid_flit;
  end
end : dlp_bytes_PROC

// Register DLP bytes signals
always @(posedge core_clk or negedge core_rst_n) begin : dlp_bytes_regs_PROC
  if(!core_rst_n) begin
    xplh_flit_type_r       <= #TP 'b0;
    xplh_replay_cmd_r      <= #TP replay_cmd_t'('b0);
    xplh_nak_seq_number_r  <= #TP 'b0;
    xplh_send_valid_flit_r <= #TP 'b0;
  end else begin
    xplh_flit_type_r       <= #TP xplh_flit_type;
    xplh_replay_cmd_r      <= #TP xplh_replay_cmd;
    xplh_nak_seq_number_r  <= #TP xplh_nak_seq_number;
    xplh_send_valid_flit_r <= #TP xplh_send_valid_flit;
  end
end : dlp_bytes_regs_PROC

assign rplh_received_flit = rplh_xplh_fm_retry.valid;
assign rplh_flit_rec_seq_number = rplh_xplh_fm_retry.received.seqnum;
assign rplh_flit_rec_replay_cmd = rplh_xplh_fm_retry.received.cmd;
assign rplh_flit_req_seq_number = rplh_xplh_fm_retry.requested.seqnum;
assign rplh_flit_req_replay_cmd = rplh_xplh_fm_retry.requested.cmd;
/////////////////////////////////////////////////////////////////
logic flit_to_ack_en, flit_to_nak_en, nak_to_reply_en, flit_to_ack_nak_en;

assign flit_to_ack_en = cdm_xplh_flit_response_type[0] && (cdm_xplh_flit_type_measured == 2'b01 || cdm_xplh_flit_type_measured == 2'b10);
assign flit_to_nak_en = cdm_xplh_flit_response_type[1] && (cdm_xplh_flit_type_measured == 2'b01 || cdm_xplh_flit_type_measured == 2'b10);
assign nak_to_reply_en = cdm_xplh_flit_response_type[2] && (cdm_xplh_flit_type_measured == 2'b01 || cdm_xplh_flit_type_measured == 2'b10);
assign flit_to_ack_nak_en = flit_to_ack_en || flit_to_nak_en ;
/////////////////////////////////////////////////////////////////
// Flit latency tracking control
logic flit_to_ack_nak_start, flit_to_ack_nak_start_r, flit_ack_nak_start_track, received_seq_ack, rplh_rec_ack, rplh_rec_nak, ack_nak_req_response, ack_nak_other_response;
logic [P_TX_SEQNUM_WD-1:0] flit_seq_number;
logic [P_TX_SEQNUM_WD-1:0] flit_nak_seq_number;

assign flit_to_ack_nak_start = (flit_to_ack_nak_en && (flit_ack_nak_state == IDLE) && xplh_send_flit)? 1'b1 : 1'b0;

always @(posedge core_clk or negedge core_rst_n) begin : flit_to_ack_nak_start_reg
  if(!core_rst_n) flit_to_ack_nak_start_r <= #TP 'b0;
  else         flit_to_ack_nak_start_r <= #TP flit_to_ack_nak_start;
end : flit_to_ack_nak_start_reg

assign flit_ack_nak_start_track = (DW == 128)? flit_to_ack_nak_start_r : flit_to_ack_nak_start;

always @(posedge core_clk or negedge core_rst_n) begin : latch_flit_seq_num
  if(!core_rst_n) flit_seq_number <= #TP 'b0;
  else if (flit_to_ack_nak_start)  flit_seq_number <= #TP xplh_flit_seq_number;
  else if ((flit_ack_nak_state == IDLE) && ~flit_to_ack_nak_start_r)   flit_seq_number <= #TP 'b0;
end : latch_flit_seq_num

assign flit_nak_seq_number = seqnum_minus_1(flit_seq_number);

assign received_seq_ack = ((rplh_flit_rec_seq_number >= flit_seq_number) && ((rplh_flit_rec_seq_number - flit_seq_number) <= P_MAX_UNACKNOWLEDGED_FLITS)) || 
((rplh_flit_rec_seq_number < flit_seq_number) && ((flit_seq_number - rplh_flit_rec_seq_number) > P_MAX_UNACKNOWLEDGED_FLITS)) ? 1'b1 : 1'b0;

assign rplh_rec_ack = (rplh_received_flit && received_seq_ack && (rplh_flit_rec_replay_cmd != REPLAY_00))? 1'b1 : 1'b0;
assign rplh_rec_nak = (rplh_received_flit && ((rplh_flit_rec_replay_cmd == NAK_10) || (rplh_flit_rec_replay_cmd == NAK_11)) && (rplh_flit_rec_seq_number == flit_nak_seq_number)) ? 1'b1 : 1'b0;

assign ack_nak_req_response = ((rplh_rec_ack && flit_to_ack_en) || (rplh_rec_nak && flit_to_nak_en)) ? 1'b1 : 1'b0;
assign ack_nak_other_response = ((rplh_rec_ack && !flit_to_ack_en) || (rplh_rec_nak && !flit_to_nak_en)) ? 1'b1 : 1'b0;
/////////////////////////////////////////////////////////////////
// FLIT ACK/NAK State Machine
xplh_flit_tracker_fsm
 u_xplh_flit_tracker_ack_nak
(
  // Inputs
  .core_clk(core_clk),
  .core_rst_n(core_rst_n),
  .flit_track_en(flit_to_ack_nak_en),
  .flit_start_tracing(flit_ack_nak_start_track),
  .received_req_response(ack_nak_req_response),
  .received_other_response(ack_nak_other_response),
  .current_data_rate(current_data_rate),
  .mac_phy_rate(mac_phy_rate),
  // Outputs
  .flit_tracking_state(flit_ack_nak_state),
  .flit_latency_value(ack_nak_latency_value)
);
/////////////////////////////////////////////////////////////////
// Retry latency tracking control
logic nak_to_reply_start, nak_to_reply_start_r, nak_to_reply_en_r, nak_reply_start_track, nak_reply_received, retrack_flit_flag;
logic [P_TX_SEQNUM_WD-1:0] retry_seq_number;
logic [P_TX_SEQNUM_WD-1:0] prev_retry_seq_number;
logic [P_TX_SEQNUM_WD-1:0] retry_ack_seq_number;

assign retrack_flit_flag = ((xplh_nak_seq_number == prev_retry_seq_number) && (prev_retry_seq_number != 'b0)) ? 1'b1 : 1'b0;

assign nak_to_reply_start = (nak_to_reply_en && (flit_retry_state == IDLE) && xplh_send_flit && ((xplh_replay_cmd == NAK_10) || (xplh_replay_cmd == NAK_11)) && ~retrack_flit_flag)? 1'b1 : 1'b0;

always @(posedge core_clk or negedge core_rst_n) begin : nak_to_reply_en_reg
  if(!core_rst_n) nak_to_reply_en_r <= #TP 'b0;
  else         nak_to_reply_en_r <= #TP nak_to_reply_en;
end : nak_to_reply_en_reg

always @(posedge core_clk or negedge core_rst_n) begin : nak_to_reply_start_reg
  if(!core_rst_n) nak_to_reply_start_r <= #TP 'b0;
  else         nak_to_reply_start_r <= #TP nak_to_reply_start;
end : nak_to_reply_start_reg

assign nak_reply_start_track = (DW == 128)? nak_to_reply_start_r : nak_to_reply_start;

always @(posedge core_clk or negedge core_rst_n) begin : latch_retry_seq_num
  if(!core_rst_n) retry_seq_number <= #TP 'b0;
  else if (nak_to_reply_start)  retry_seq_number <= #TP xplh_nak_seq_number;
  else if ((flit_retry_state == IDLE) && ~nak_to_reply_start_r)   retry_seq_number <= #TP 'b0;
end : latch_retry_seq_num

always @(posedge core_clk or negedge core_rst_n) begin : prev_trck_seq_num
  if(!core_rst_n) prev_retry_seq_number <= #TP 'b0;
  else if (flit_retry_state == STARTED)  prev_retry_seq_number <= #TP retry_seq_number;
  else if (~(nak_to_reply_en || nak_to_reply_en_r))  prev_retry_seq_number <= #TP 'b0;
end : prev_trck_seq_num

assign retry_ack_seq_number = seqnum_plus_1(retry_seq_number);

assign nak_reply_received = (rplh_received_flit && (rplh_flit_req_seq_number == retry_ack_seq_number) && (rplh_flit_req_replay_cmd == ACK)) ? 1'b1 : 1'b0;
/////////////////////////////////////////////////////////////////
// Retry NAK State Machine
xplh_flit_tracker_fsm
 u_xplh_flit_tracker_nak_reply
(
  // Inputs
  .core_clk(core_clk),
  .core_rst_n(core_rst_n),
  .flit_track_en(nak_to_reply_en),
  .flit_start_tracing(nak_reply_start_track),
  .received_req_response(nak_reply_received),
  .received_other_response(1'b0),
  .current_data_rate(current_data_rate),
  .mac_phy_rate(mac_phy_rate),
  // Outputs
  .flit_tracking_state(flit_retry_state),
  .flit_latency_value(retry_latency_value)
);
/////////////////////////////////////////////////////////////////
// Report Latency
latency_tracking_status_e flit_ack_nak_state_r;
latency_tracking_status_e flit_retry_state_r;
logic [16:0] accumilated_counter;

// Calculate the target latency value that will be added to the accumelated counter, if the two latencies are ready together 
// the maximum will be the target latency, and if there is only one latency ready the other one will be '0 and the ready 
// one will be the target latency
assign target_latency_value = (ack_nak_latency_value > retry_latency_value) ? ack_nak_latency_value : retry_latency_value;

always @(posedge core_clk or negedge core_rst_n) begin : latency_counter
  if(!core_rst_n) begin
     accumilated_counter  <= 'b0;
  end else if (cdm_xplh_flit_response_type == 'b0) begin
     accumilated_counter  <= 'b0;
  end else if (~accumilated_counter[16]) begin
      if ((flit_ack_nak_state == DONE) || (flit_retry_state == DONE)) begin
        if(cdm_xplh_flit_track_mode)
          begin
            accumilated_counter <= {1'b0,target_latency_value};
          end
        else
          begin
            accumilated_counter <= {1'b0,accumilated_counter[15:0]} + {1'b0,target_latency_value};
          end
      end
  end
end : latency_counter

always @(posedge core_clk or negedge core_rst_n) begin : state_reg
  if(!core_rst_n) begin
     flit_ack_nak_state_r  <= IDLE;
     flit_retry_state_r  <= IDLE;
  end else begin
     flit_ack_nak_state_r  <= flit_ack_nak_state;
     flit_retry_state_r  <= flit_retry_state;
  end 
end : state_reg

always @(posedge core_clk or negedge core_rst_n) begin : latency_report
  if(!core_rst_n) begin
     flit_latency_tracking.flit_latency_status <= IDLE;
     flit_latency_tracking.flit_latency_value  <= 'b0;
  end else if (flit_ack_nak_state_r == ERROR || flit_retry_state_r == ERROR || accumilated_counter[16]) begin
     flit_latency_tracking.flit_latency_status <= ERROR;
     flit_latency_tracking.flit_latency_value  <= 16'hffff;
  end else if (flit_ack_nak_state_r == DONE || flit_retry_state_r == DONE) begin
     flit_latency_tracking.flit_latency_status <= DONE;
     flit_latency_tracking.flit_latency_value  <= accumilated_counter[15:0];
  end else if (flit_ack_nak_state_r == STARTED || flit_retry_state_r == STARTED) begin
     flit_latency_tracking.flit_latency_status <= STARTED;
     flit_latency_tracking.flit_latency_value  <= 'b0;
  end else begin
     flit_latency_tracking.flit_latency_status <= IDLE;
     flit_latency_tracking.flit_latency_value  <= 'b0;
  end
end : latency_report
/////////////////////////////////////////////////////////////////

//------------------------------------------\\
//----------- Design Assertions ------------\\
//------------------------------------------\\

endmodule
