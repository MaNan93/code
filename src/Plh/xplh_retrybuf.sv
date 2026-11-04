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
// ---   $Revision: #10 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_retrybuf.sv#10 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH RETRYBUF Contains Retry Buffer RAM control and read/write pointers
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xplh_retrybuf
  import  xplh_pkg::retry_req_struct;
  import  xplh_pkg::P_TX_SEQNUM_WD;
  import  xplh_pkg::inject_crc_error;
  import  cx_pl_pkg::P_FLIT_WD;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_RBUF_WD;
  import  cx_pl_pkg::P_RBUF_PW;
  import  cx_pl_pkg::P_RBUF_DEPTH;
  import  cx_pl_pkg::P_RBUF_READ_LATENCY;
  import  cx_pl_pkg::P_FLIT_DW_CNT_WD;
  import  cx_pl_pkg::P_FLIT_DW_CNT;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::CMD_IDLE;
  import  cx_pl_pkg::CMD_NOP;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::CMD_RESET;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::rbuf_struct;
  import  cx_pl_pkg::NOP;
  import  cx_pl_pkg::PYLD;
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
  input                           core_clk,
  input                           core_rst_n,
  // -------------------------------------------------------------------------------------
  // Flit Interfaces
  // -------------------------------------------------------------------------------------
  input   tx_flit_struct          flit_in,                          // Input Flit
  input                           halt_in,                          // Downstream Halt
  output  tx_flit_struct          xplh_retrybuf_flit_out,           // Output Flit
  output  logic                   xplh_retrybuf_sent_pyld_expl,     // Send Payload explicit flit after nak to empty retry buffer
  output  logic                   xplh_retrybuf_halt_out,           // Upstream Halt
  output  logic                   xplh_retrybuf_idle,               // FSM is IDLE no retry in progress
  input   tx_cmd_struct           xmlh_xplh_cmd,                    // Commands from XMLH
  input   tx_cmd_struct           xplh_xdlh_cmd,                    // Commands from XPLH
  input                           xplh_control_normal,              // Normal State
  input                           nak_ignore_req_expl,              // Request to send explicit sequence number flits
  input                           block_replay,                     // Hold off on the replay when replay num rollover occured
  input                           spif_enable,                      // SPIF Enable
  input                           xplh_nop_phy_eof,                 // Physical Layer NOP flit EOF cycle is accepted by XPLH Control
  // -------------------------------------------------------------------------------------
  // CXL Viral Request from CXL CTRL
  // -------------------------------------------------------------------------------------
  input                           cxl_viral_err,                    // viral error, rewind wrptr for flit0 only (and not for viral inband)
  input                           cxl_vir_inband_mark_crc,           // inband control flit with crc marker. clear marked before writing to retrybuf
  // -------------------------------------------------------------------------------------
  // Retry Request from RRSM
  // -------------------------------------------------------------------------------------
  input   retry_req_struct        retry_req,                        // Retry Request
  // -------------------------------------------------------------------------------------
  //  Ackd Flit Counter
  // -------------------------------------------------------------------------------------
  input   [P_TX_SEQNUM_WD-1:0]    ackd_flits,                       // Number of Flit acknowledged by the latest Ack/Nak 
  // -------------------------------------------------------------------------------------
  // Consecutive Nak Counter
  // -------------------------------------------------------------------------------------
  input   [2:0]                   tx_nak_cnt,                       // Tracks the number of consecutive Naks transmitted
  input                           tx_nak_cnt_incr,                  // Nak Counter about to increment
  input   [1:0]                   expl_seq_cnt,                     // Explicit Sequence Number Counter
  // -------------------------------------------------------------------------------------
  // Retry RAM Interface
  // -------------------------------------------------------------------------------------
  input   [P_RBUF_WD-1:0]         retryram_data,                    // Retry Buffer Read Data
  output  rbuf_struct             xplh_retrybuf_ram_if,             // Retry Buffer Interface Struct
  output  logic                   xplh_retrybuf_replay_in_progress, // Actively replaying Flits from the retry buffer
  output  logic                   xplh_retrybuf_af,                 // Retry bufffer is close to full
  output  logic                   xplh_retrybuf_empty,              // retry scheduled but rbuf was empty
  output  logic                   xplh_retrybuf_empty_retry,        // Retry is in empty retry state
  output  logic                   xplh_retrybuf_hold_rrsm,          // Hold RRSM in WAIT_DONE if payload explicit is sent until the NAK_IGNORE_TIMER starts
  output  logic                   xplh_retrybuf_nak_11              // Sent selective replay after NAK_11 received
  ,
  output  ras_dp_err_log_t  [1:0] xplh_retrybuf_ras_dp_err_log      // RASDP Error Logging
  ,
  input   ras_dp_err_inj_t        ras_dp_err_inj                    // RASDP Error Injection
);

// -------------------------------------------------------------------------------------
// Parameters
// -------------------------------------------------------------------------------------
localparam  P_PTR_RST_VAL     = {P_RBUF_PW{1'b0}};
localparam  P_RD_PTR_MULT     = P_FLIT_WD / P_DW; // Number of retry RAM addresses to store full flit
// FIFO Depth is a full flit plus the RAM read latency
localparam  P_FIFO_DEPTH      = P_RD_PTR_MULT + P_RBUF_READ_LATENCY;
// Number of Flits to read prior to starting the replay
localparam  P_MIN_FLIT_RD_CNT = (P_RBUF_READ_LATENCY >= P_RD_PTR_MULT) ? 2 : 1;
localparam  P_FIFO_ADD_WD     = $clog2(P_FIFO_DEPTH);
localparam  P_RBUF_RD_CNT_WD  = $clog2(P_RD_PTR_MULT);

// -------------------------------------------------------------------------------------
//  Logic Declarations
// -------------------------------------------------------------------------------------
// FSM
typedef enum {
  IDLE,
  RBUF_READ,
  REPLAY,
  WAIT_REPLAY_DONE,
  RBUF_EMPTY_RETRY
} state_e;

state_e next_state, state_r;

// Retry RAM Write Data
logic [P_RBUF_WD - 1 : 0]         int_rbuf_wdata;
// Retry RAM Write Enable
logic                             int_rbuf_we;
// Retry RAM Read Enable
logic                             int_rbuf_re;
logic                             int_rbuf_re_r;
logic                             int_rbuf_en_re;
// Retry RAM Write Address
logic [P_RBUF_PW - 1 : 0]         int_rbuf_waddr;
// Retry RAM Read Address
logic [P_RBUF_PW - 1 : 0]         int_rbuf_raddr;
// Retry Write Pointer
logic [P_RBUF_PW - 1 : 0]         int_rbuf_wr_ptr;
logic [P_RBUF_PW - 1 : 0]         int_rbuf_wr_ptr_r;
// Retry Read Pointer
logic [P_RBUF_PW - 1 : 0]         int_rbuf_rd_ptr;
logic [P_RBUF_PW - 1 : 0]         int_rbuf_rd_ptr_r;
logic [P_RBUF_PW - 1 : 0]         int_num_ackd_flits;
// Read of retry buffer done
logic                             int_rbuf_rd_done;
logic                             int_rbuf_rd_done_r;
// Selective Replay
logic                             int_selective_replay;
logic                             int_selective_replay_r;
logic                             int_selective_replay_fe;
logic                             int_rbuf_rd_flag_r;
// Retry FIFO Signals
logic                             int_rbuf_fifo_empty;
logic                             int_rbuf_fifo_ae; // adding this signal back in to avoid NOP flits at WAIT_REPLAY_DONE, VIP complaining
logic                             int_rbuf_fifo_almost_full;
logic                             int_rbuf_fifo_pop;
logic                             int_rbuf_fifo_pop_n;
logic                             int_rbuf_fifo_push_n;
logic [P_RBUF_WD - 1 : 0]         int_rbuf_fifo_dout;
logic [P_DW - 1 : 0]              int_rbuf_rdata;
logic                             int_en_dw_cnt;
logic                             int_en_nop_cnt;
logic [P_FLIT_DW_CNT_WD - 1 : 0]  int_dw_cnt_r;
logic [P_FLIT_DW_CNT_WD - 1 : 0]  int_nop_cnt_r;
logic [P_TX_SEQNUM_WD - 1 : 0]    int_min_rd_cnt;
logic                             int_sel_min_rd_done;
logic                             int_sel_min_rd_done_r;
logic                             int_std_min_rd_done;
logic                             int_std_min_rd_done_r;
logic                             int_pre_replay_min_rd_done;
logic [P_TX_SEQNUM_WD - 1: 0]     int_rbuf_pyld_flit_cnt_r;
logic [P_RBUF_RD_CNT_WD-1:0]      int_rbuf_read_cnt_r;
logic [P_TX_SEQNUM_WD-1:0]        int_rbuf_flit_cnt_r;
rbuf_struct                       int_retrybuf_ram_in;
tx_flit_struct                    int_flit_in;
tx_flit_struct                    int_retryram_if_flit_out;
logic                             int_pyld_ongoing;
logic                             int_pyld_ongoing_r;
logic                             int_flit_ongoing_r;
logic                             int_pyld_sent_r;
logic                             int_sent_pyld_expl;
logic                             int_xmlh_sent_pyld_expl;
logic                             int_xmlh_sent_pyld_expl_r;
logic                             int_sent_pyld_expl_re;
logic                             int_sent_pyld_expl_r;
logic                             int_nak_11;
logic                             int_nak_11_r;
logic                             int_xplh_retrybuf_halt;
logic                             int_rbuf_read_halt;
logic                             int_rbuf_read_halt_r;
logic [P_TX_SEQNUM_WD - 1: 0]     int_pyld_flit_cnt;

logic                             xplh_retrybuf_rdata_err;          // Uncorrectable error occured in retry ram read path
logic                             rbuf_rvalid_to_checker;

// Output Assignments
assign xplh_retrybuf_halt_out = int_xplh_retrybuf_halt;

// -------------------------------------------------------------------------------------
// Payload Flit Tracker
// -------------------------------------------------------------------------------------
xplh_payload_tracker
 u_payload_tracker (
  .core_clk                       (core_clk),
  .core_rst_n                     (core_rst_n),
  .xmlh_xplh_cmd                  (xmlh_xplh_cmd),
  .ackd_flits                     (ackd_flits),
  .eof                            (int_flit_in.eof[1]),
  .enf                            (int_flit_in.enf || cxl_viral_err), //viral flit0 rewinded, dont add to tracker
  .halt_in                        (int_xplh_retrybuf_halt),
  .xplh_payload_tracker_flit_cnt  (int_pyld_flit_cnt),
  .xplh_payload_tracker_af        (xplh_retrybuf_af)
);

// -------------------------------------------------------------------------------------
// Retry Buffer Read Tracker
// -------------------------------------------------------------------------------------
// Ensure that the number of flits read matches the flit replay counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : rbuf_read_cnt_PROC
  if(!core_rst_n) begin
    int_rbuf_read_cnt_r <= #TP '0;
    int_rbuf_flit_cnt_r <= #TP '0;
  end else begin
    // Reset if the replay completes
    if(state_r == IDLE) begin
      int_rbuf_read_cnt_r <= #TP '0; 
      int_rbuf_flit_cnt_r <= #TP '0; 
    // Count flits read from the retry buffer
    end else if(int_rbuf_re) begin
      int_rbuf_read_cnt_r <= #TP int_rbuf_read_cnt_r + 1'b1;
      int_rbuf_flit_cnt_r <= #TP (&int_rbuf_read_cnt_r) ? int_rbuf_flit_cnt_r + 1'b1 : int_rbuf_flit_cnt_r;
    end
  end
end : rbuf_read_cnt_PROC

// -------------------------------------------------------------------------------------
// Retry Buffer Pointers
// -------------------------------------------------------------------------------------
// Retry Buffer Write Pointer
always_comb begin : wr_ptr_PROC
  int_rbuf_wr_ptr = int_rbuf_wr_ptr_r;
  if(xmlh_xplh_cmd.tx_cmd == CMD_RESET) begin
    int_rbuf_wr_ptr = '0;
  end else if(!xplh_retrybuf_replay_in_progress) begin
    // Decrement the Write pointer to overwrite NOP Flits or cxl viral detected on current flit
    if(!xplh_retrybuf_halt_out && ( cxl_viral_err || int_flit_in.enf) && int_flit_in.eof[1])
      int_rbuf_wr_ptr = int_rbuf_wr_ptr_r - (P_FLIT_DW_CNT - 1'b1);
    // Increment the Write pointer
    else if(!xplh_retrybuf_halt_out && int_flit_in.data_valid && !int_en_nop_cnt) begin
      // Wrap around
      if(int_rbuf_wr_ptr_r == (P_RBUF_DEPTH - 1))
        int_rbuf_wr_ptr = P_PTR_RST_VAL;
      else
        int_rbuf_wr_ptr = int_rbuf_wr_ptr_r + 1'b1;
    end else
      int_rbuf_wr_ptr = int_rbuf_wr_ptr_r;
  end
end : wr_ptr_PROC

// Retry Buffer Write Access
always_comb begin : wr_rbuf_PROC
  int_rbuf_we = 1'b0;
  int_rbuf_wdata = '0; 
  int_rbuf_waddr = '0;
  // No replay in progress write new flits to the retry-buffer
  if(!xplh_retrybuf_replay_in_progress) begin
    if (!xplh_retrybuf_halt_out && int_flit_in.data_valid) begin
      int_rbuf_we = 1'b1;
      int_rbuf_wdata = {{(P_RBUF_WD - $bits(int_flit_in.data)){1'b0}}, int_flit_in.data};
      int_rbuf_waddr = int_rbuf_wr_ptr_r;
    end
  end
end : wr_rbuf_PROC

// Retry Buffer Read Pointer update with the number of acknowledged flits 
assign int_num_ackd_flits = ackd_flits[P_RBUF_PW - 1 : 0];

always_comb begin : rd_ptr_PROC
  int_rbuf_rd_ptr = int_rbuf_rd_ptr_r;
  if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
    int_rbuf_rd_ptr = '0;
  else if(((P_RBUF_DEPTH - 1) - int_rbuf_rd_ptr_r) < (P_RD_PTR_MULT * int_num_ackd_flits))
    int_rbuf_rd_ptr = ((P_RD_PTR_MULT * int_num_ackd_flits) - ((P_RBUF_DEPTH - 1) - int_rbuf_rd_ptr_r)) - 1'b1;
  else
    int_rbuf_rd_ptr = int_rbuf_rd_ptr_r + (P_RD_PTR_MULT * int_num_ackd_flits);
end

// Register the read and write pointers
always_ff @(posedge core_clk or negedge core_rst_n) begin : ptr_sync_PROC
  if(!core_rst_n) begin
    int_rbuf_wr_ptr_r     <= #TP P_PTR_RST_VAL;
    int_rbuf_rd_ptr_r     <= #TP P_PTR_RST_VAL;
  end else begin
    int_rbuf_wr_ptr_r     <= #TP int_rbuf_wr_ptr;
    int_rbuf_rd_ptr_r     <= #TP int_rbuf_rd_ptr;
  end
end : ptr_sync_PROC

// Replayed flit counter is equal to the number of flits read from the buffer
// For a selective replay only 1 Flit is being replayed.
// Latch the number of flits to be retried when replay_in_progress is asserted
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_rbuf_pyld_flit_cnt_r  <= #TP '0;
  end else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      int_rbuf_pyld_flit_cnt_r  <= #TP '0;
    else if((next_state == REPLAY) && (state_r != REPLAY)) begin
      // For SPIF, account for the XPLH Payload Tracker increment in the next clock cycle when payload flit is transmitted
      // For CXL, if cxl_viral_err is asserted then the last flit is being dropped from the Retry Buffer and XPLH Payload Tracker
      // is not incremented. Therefore do not account for XPLH Payload Tracker increment when cxl_viral_err is asserted.
      if(spif_enable && int_flit_in.eof[1] && !int_flit_in.enf && !xplh_retrybuf_halt_out && !cxl_viral_err)
        int_rbuf_pyld_flit_cnt_r  <= #TP int_pyld_flit_cnt + 1;
      else
        int_rbuf_pyld_flit_cnt_r  <= #TP int_pyld_flit_cnt;
    end
  end
end

always_comb begin : sel_replay_PROC
  if(state_r inside {WAIT_REPLAY_DONE, REPLAY})
    int_selective_replay = int_selective_replay_r;
  else
    int_selective_replay = retry_req.replay_scheduled && (retry_req.replay_cmd == NAK_11);
end : sel_replay_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_selective_replay_r  <= #TP '0;
  else
    int_selective_replay_r  <= #TP int_selective_replay;
end

// Retry Buffer Empty Status
assign xplh_retrybuf_empty = (int_pyld_flit_cnt==0);

// Detect if a payload Flit is ongoing this will be used in the case of a Nak received when the retry buffer is empty.
// If the retry buffer is empty but a payload flit is ongoing hold off on the explicit sequence number flits until the payload
// flit has completed.
always_ff @(posedge core_clk or negedge core_rst_n) begin : pyld_ongoing_PROC
  if(!core_rst_n)
    int_pyld_ongoing_r  <= #TP '0;
  else begin
    if(!xplh_retrybuf_empty)
      int_pyld_ongoing_r  <= #TP '0;
    else if(int_flit_in.tlp_dv)
      int_pyld_ongoing_r  <= #TP '1;
    else
      int_pyld_ongoing_r  <= #TP int_pyld_ongoing_r;
  end
end : pyld_ongoing_PROC

assign int_pyld_ongoing = int_flit_in.tlp_dv || int_pyld_ongoing_r;

// Detect if there is a flit ongoing
always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_ongoing_PROC
  if(!core_rst_n) begin
    int_flit_ongoing_r    <= #TP '0;
  end else begin
    if( spif_enable ? 1'b1 : !xplh_retrybuf_halt_out) begin
      if(int_flit_in.sof)
        int_flit_ongoing_r  <= #TP '1;
      else if(int_flit_in.eof[1] && !xplh_retrybuf_halt_out)
        int_flit_ongoing_r  <= #TP '0;
      else
        int_flit_ongoing_r  <= #TP int_flit_ongoing_r;
    end
  end
end : flit_ongoing_PROC

// Payload Flit sent before entry to RBUF_EMPTY_RETRY
// In this case we should not enable the nak ignore window
// Clear this flag upon exiting RBUF_EMPTY_RETRY or entering RBUF_READ
// Otherwise if the conditions for sending Explicit Flits is removed before entering RBUF_EMPTY_RETRY
always_ff @(posedge core_clk or negedge core_rst_n) begin : pyld_sent_PROC
  if(!core_rst_n)
    int_pyld_sent_r <= #TP '0;
  else begin
    if((state_r == IDLE) && (nak_ignore_req_expl || (retry_req.replay_scheduled && xplh_retrybuf_empty)) && int_flit_in.eof[1] && !int_flit_in.enf)
      int_pyld_sent_r <= #TP '1;
    else if(int_pyld_sent_r && (state_r == RBUF_EMPTY_RETRY) && !(next_state == RBUF_EMPTY_RETRY))
      int_pyld_sent_r <= #TP '0;
    else if(state_r == RBUF_READ)
      int_pyld_sent_r <= #TP '0;
    else if((next_state == IDLE) && !(nak_ignore_req_expl || (retry_req.replay_scheduled && xplh_retrybuf_empty)))
      int_pyld_sent_r <= #TP '0;
  end
end : pyld_sent_PROC

// Minimum number of flits to read before starting the replay
// Nead to take into account read latency so that sufficient data is buffered to 
// have a continuous replay.
always_comb begin : min_rd_cnt_PROC
  if(int_selective_replay)
    int_min_rd_cnt = 'd1;
  else
    int_min_rd_cnt = (int_pyld_flit_cnt > 1) ? P_MIN_FLIT_RD_CNT : 'd1;
end : min_rd_cnt_PROC

assign int_min_rd_done = (int_rbuf_flit_cnt_r == int_min_rd_cnt);
// selective replay minimum read done
assign int_sel_min_rd_done = int_min_rd_done && int_selective_replay;

delay_n
 #(
  .N  (P_RBUF_READ_LATENCY),
  .WD (1)
) u_sel_min_rd_pipe (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear ((state_r != RBUF_READ)),
  .din   (int_sel_min_rd_done),
  .dout  (int_sel_min_rd_done_r) 
);

// standard replay minimum read done
assign int_std_min_rd_done = int_min_rd_done && !int_selective_replay;

delay_n
 #(
  .N  (P_RBUF_READ_LATENCY),
  .WD (1)
) u_std_min_rd_pipe (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear ((state_r != RBUF_READ)),
  .din   (int_std_min_rd_done),
  .dout  (int_std_min_rd_done_r) 
);

assign int_pre_replay_min_rd_done = (int_selective_replay && int_sel_min_rd_done_r) || (!int_selective_replay && int_std_min_rd_done_r);
// -------------------------------------------------------------------------------------
// Retry Buffer FSM
// -------------------------------------------------------------------------------------
always_comb begin : rbuf_fsm_PROC
  next_state = state_r;
  case(state_r)
    // Start reading from the retry-buffer
    // In normal state start the retry when explicit sequence count is 0.
    // In sequence handshake state we need to wait until explicit sequence count is 3.
    RBUF_READ : begin
      if(int_pre_replay_min_rd_done && ((xplh_retrybuf_flit_out.eof[1] && !halt_in || xplh_nop_phy_eof) && !tx_nak_cnt_incr) && ((tx_nak_cnt == 0) || (tx_nak_cnt > 2)) && ((xplh_control_normal && (expl_seq_cnt == 0)) || (expl_seq_cnt == 3)))
        next_state = REPLAY;
    end
    // Start replaying flits from the retry-buffer
    REPLAY : begin
      // Retry Buffer Read Complete.
      if(int_rbuf_rd_done_r)
        next_state = WAIT_REPLAY_DONE;
    end
    // Wait for all retryable Flits to be replayed when the last entry is being popped unhalt the XTLH, avoid NOP flit in SPIF mode
    WAIT_REPLAY_DONE : begin
      if(xplh_retrybuf_flit_out.eof[1] && !halt_in && ( spif_enable ? int_rbuf_fifo_ae : int_rbuf_fifo_empty))
        next_state = IDLE;
    end
    // Wait to complete the sequence of 3 explicit sequence number flits with Payload or 3 explicit NOP's
    RBUF_EMPTY_RETRY : begin
      // Allow to exit if the explicit sequence hasn't started yet and nak ignore sequence number cleared
      if((expl_seq_cnt == 0) && !(nak_ignore_req_expl || retry_req.replay_scheduled))
        next_state = IDLE;
      // Nak Ignore Sequence Number > 0 send 3 explicit sequence number Flits
      else if(expl_seq_cnt == 3)
        next_state = IDLE;
      else
          next_state = RBUF_EMPTY_RETRY;
    end
    default : begin // IDLE
      // If no payload ongoing and conditions allow at the next EOF send explicit flits
      if((nak_ignore_req_expl || (retry_req.replay_scheduled && xplh_retrybuf_empty)) && ((xplh_retrybuf_flit_out.eof[1] && !halt_in || !int_flit_in.data_valid && xplh_nop_phy_eof) && !tx_nak_cnt_incr) && ((tx_nak_cnt == 0) || (tx_nak_cnt > 2)) && (expl_seq_cnt < 3) && !int_pyld_ongoing)
        next_state = RBUF_EMPTY_RETRY;
      // Hold off on starting a replay if a transition to recovery has been initiated
      else if((xmlh_xplh_cmd.tx_cmd inside {CMD_FLUSH_XTLH, CMD_IDLE}) || ( spif_enable ? 1'b0 : (xplh_xdlh_cmd.tx_cmd == CMD_NOP)))
        next_state = IDLE;
      // Replay Flits from Retry Buffer
      else if(retry_req.replay_scheduled && !block_replay)
        next_state = RBUF_READ;
    end
  endcase
end : rbuf_fsm_PROC

// Retry buffer is idle when a retry is not in progress or when were waiting to send payload flit with explicit sequence number
assign xplh_retrybuf_idle = (state_r inside {IDLE, RBUF_EMPTY_RETRY});

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

// Detect that a payload explicit flit has been sent
always_ff @(posedge core_clk or negedge core_rst_n) begin : pyld_expl_PROC
  if(!core_rst_n)
    int_sent_pyld_expl_r    <= #TP '0;
  else begin
    if(!(state_r inside {RBUF_EMPTY_RETRY, REPLAY, WAIT_REPLAY_DONE}))
      int_sent_pyld_expl_r  <= #TP '0;
    else if(int_sent_pyld_expl)
      int_sent_pyld_expl_r  <= #TP '1;
  end
end : pyld_expl_PROC

assign int_sent_pyld_expl_re = int_sent_pyld_expl && !int_sent_pyld_expl_r && !int_pyld_sent_r;

assign xplh_retrybuf_empty_retry = (state_r == RBUF_EMPTY_RETRY);

always_ff @(posedge core_clk or negedge core_rst_n) begin : hold_rrsm_PROC
  if(!core_rst_n)
    xplh_retrybuf_hold_rrsm <= #TP '0;
  else begin
    if(int_xmlh_sent_pyld_expl)
      xplh_retrybuf_hold_rrsm <= #TP '0;
    else if(int_sent_pyld_expl_re)
      xplh_retrybuf_hold_rrsm <= #TP '1;
  end
end : hold_rrsm_PROC

// Pipeline to model delay through to XMLH
delay_n_w_stalling
 #(
  .N          (3),
  .CAN_STALL  (0),
  .WD         (1)
) u_xplh_xmlh_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .stall      (halt_in),
  .clear      (1'b0),
  .din        (xplh_retrybuf_hold_rrsm),
  .stallout   (),
  .dout       (int_xmlh_sent_pyld_expl)
);

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_xmlh_sent_pyld_expl_r <= #TP '0;
    int_rbuf_read_halt_r      <= #TP '0;
  end else begin
    int_xmlh_sent_pyld_expl_r <= #TP int_xmlh_sent_pyld_expl;
    int_rbuf_read_halt_r      <= #TP int_rbuf_read_halt;
  end
end

assign xplh_retrybuf_sent_pyld_expl = int_xmlh_sent_pyld_expl && !int_xmlh_sent_pyld_expl_r;

always_comb begin : rbuf_fsm_out_PROC
  int_xplh_retrybuf_halt = halt_in;
  xplh_retrybuf_flit_out = '0;
  int_sent_pyld_expl = 1'b0;
  xplh_retrybuf_replay_in_progress = 1'b0;
  int_rbuf_re = 1'b0;
  int_rbuf_fifo_pop = 1'b0;
  int_nak_11 = 1'b0;
  rbuf_rvalid_to_checker = 1'b0;
  int_rbuf_read_halt = 1'b0;
  int_en_nop_cnt = 1'b0;
  int_rbuf_rd_done = int_rbuf_rd_done_r;
  case(state_r)
    // RBUF_READ State replay in progress is set to 1
    // Read from the retry buffer and push data to the FIFO
    RBUF_READ : begin
      int_rbuf_rd_done =  (int_selective_replay ? (int_rbuf_flit_cnt_r == 1) : (int_pyld_flit_cnt == int_rbuf_flit_cnt_r));
      // Read Enable for retry RAM
      if(int_rbuf_flit_cnt_r == int_min_rd_cnt) begin
        int_rbuf_re = 1'b0;
      end else if(int_rbuf_read_halt_r) begin
        int_rbuf_re = 1'b1;
      end else begin
        int_rbuf_re = int_rbuf_re_r;
      end
      // prevent nop flits in SPIF mode
      if(int_rbuf_read_halt_r) begin
        int_rbuf_read_halt = 1'b1;
        int_xplh_retrybuf_halt = 1'b1;
        int_en_nop_cnt = spif_enable ? 1'b0 : 1'b1;
      end else if(!int_flit_ongoing_r) begin
        int_rbuf_read_halt = 1'b1;
        int_xplh_retrybuf_halt = 1'b1;
        int_en_nop_cnt = spif_enable ? 1'b0 : 1'b1;
      end else begin
        int_rbuf_read_halt = 1'b0;
        int_xplh_retrybuf_halt = halt_in;
        int_en_nop_cnt = 1'b0;
      end
      if(int_en_nop_cnt) begin
        xplh_retrybuf_flit_out.sof = (int_nop_cnt_r == '0);
        xplh_retrybuf_flit_out.data = '0;
        xplh_retrybuf_flit_out.eof = (int_nop_cnt_r == P_FLIT_DW_CNT - 1) ? 2'b11 : 2'b00;
        xplh_retrybuf_flit_out.enf = |xplh_retrybuf_flit_out.eof;
        xplh_retrybuf_flit_out.flit_type_s.err_inj_en = int_flit_in.flit_type_s.err_inj_en;
        xplh_retrybuf_flit_out.flit_type_s.flit_type  = NOP;
        xplh_retrybuf_flit_out.ras_dp_err_inband_kbd = xplh_retrybuf_rdata_err;
        xplh_retrybuf_flit_out.data_valid = 1'b1;
        xplh_retrybuf_flit_out.retry_flit = 1'b0;
        xplh_retrybuf_flit_out.tlp_dv = 1'b0;
      end else if (spif_enable && (int_rbuf_read_halt || int_rbuf_read_halt_r)) begin
        // xplh_phy_nop_generator will generate physical NOP flits when pending sof is de-asserted
        xplh_retrybuf_flit_out = '0;
      end else begin
        xplh_retrybuf_flit_out = int_flit_in;
        xplh_retrybuf_flit_out.data = inject_crc_error((cxl_viral_err || cxl_vir_inband_mark_crc), xplh_retrybuf_flit_out.data, ( 1'b0), xplh_retrybuf_flit_out.eof[1]);
      end
    end
    // REPLAY State begin replaying Flits from the retry buffer read FIFO
    REPLAY : begin
      xplh_retrybuf_flit_out.data = int_rbuf_rdata;
      int_rbuf_rd_done = int_rbuf_rd_done_r || (int_selective_replay ? (int_rbuf_flit_cnt_r == 1) : (int_rbuf_pyld_flit_cnt_r == int_rbuf_flit_cnt_r));
      xplh_retrybuf_flit_out.flit_type_s.err_inj_en = int_flit_in.flit_type_s.err_inj_en;
      xplh_retrybuf_flit_out.flit_type_s.flit_type  = int_flit_in.flit_type_s.err_inj_en ? PYLD : NOP;
      xplh_retrybuf_flit_out.ras_dp_err_inband_kbd = xplh_retrybuf_rdata_err;
      xplh_retrybuf_flit_out.data_valid = 1'b1;
      xplh_retrybuf_flit_out.sof = (int_dw_cnt_r == '0);
      xplh_retrybuf_flit_out.eof = (int_dw_cnt_r == P_FLIT_DW_CNT - 1) ? 2'b11 : 2'b00;
      xplh_retrybuf_flit_out.enf = 1'b0;
      xplh_retrybuf_flit_out.retry_flit = 1'b1;
      xplh_retrybuf_flit_out.tlp_dv = 1'b1;
      int_xplh_retrybuf_halt = 1'b1;
      xplh_retrybuf_replay_in_progress = 1'b1;
      int_rbuf_fifo_pop = !halt_in && !int_rbuf_fifo_empty;
      int_nak_11 = int_nak_11_r ? 1'b1 : int_selective_replay;
      rbuf_rvalid_to_checker = !int_rbuf_fifo_empty;
      // Payload explicit flit sent start the nak ignore window
      int_sent_pyld_expl = xplh_retrybuf_flit_out.eof[1] && xplh_retrybuf_flit_out.retry_flit;
      // Read Enable for retry RAM
      if(int_rbuf_rd_done) begin
        int_rbuf_re = 1'b0;
      end else if(int_rbuf_fifo_almost_full && !int_rbuf_fifo_pop) begin
        int_rbuf_re = 1'b0;
      end else begin
        int_rbuf_re = 1'b1;
      end
    end
    // READ_LATENCY state reading from the retry buffer complete
    // Wait for RAM latency to complete the last read
    WAIT_REPLAY_DONE : begin
      int_rbuf_rd_done = 1'b0;
      int_en_nop_cnt = int_rbuf_fifo_empty;
      xplh_retrybuf_flit_out.data = int_rbuf_fifo_empty ? '0 : int_rbuf_rdata;
      xplh_retrybuf_flit_out.flit_type_s.err_inj_en = int_flit_in.flit_type_s.err_inj_en;
      xplh_retrybuf_flit_out.flit_type_s.flit_type  = (!int_rbuf_fifo_empty && int_flit_in.flit_type_s.err_inj_en) ? PYLD : NOP;
      xplh_retrybuf_flit_out.ras_dp_err_inband_kbd = xplh_retrybuf_rdata_err;
      xplh_retrybuf_flit_out.data_valid = 1'b1;
      xplh_retrybuf_flit_out.sof = (int_dw_cnt_r == '0);
      xplh_retrybuf_flit_out.eof = (int_dw_cnt_r == P_FLIT_DW_CNT - 1) ? 2'b11 : 2'b00;
      xplh_retrybuf_flit_out.enf = (int_nop_cnt_r == P_FLIT_DW_CNT - 1); 
      xplh_retrybuf_flit_out.retry_flit = int_rbuf_fifo_empty ? 1'b0 : 1'b1;
      xplh_retrybuf_flit_out.tlp_dv = int_rbuf_fifo_empty ? 1'b0 : 1'b1;
      int_xplh_retrybuf_halt = 1'b1;
      xplh_retrybuf_replay_in_progress = 1'b1;
      int_rbuf_re = 1'b0;
      int_rbuf_fifo_pop = !halt_in && !int_rbuf_fifo_empty;
      int_sent_pyld_expl = xplh_retrybuf_flit_out.eof[1] && xplh_retrybuf_flit_out.retry_flit;
      int_nak_11 = int_nak_11_r ? 1'b1 : int_selective_replay;
      rbuf_rvalid_to_checker = !int_rbuf_fifo_empty;
    end
    // Retry Buffer is empty but a Nak of TX_SEQNUM - 1 is received so we will transmit explicit sequence number Flits
    // We dont read the retry buffer in this state we just set the expl_flit so that xplh_control will send explicit sequence number flits
    RBUF_EMPTY_RETRY : begin
      xplh_retrybuf_flit_out = int_flit_in;
      int_xplh_retrybuf_halt = halt_in;
      xplh_retrybuf_flit_out.expl_flit = spif_enable ? 1'b1 : (|xplh_retrybuf_flit_out.eof);
      // Payload explicit flit sent start the nak ignore window
      int_sent_pyld_expl = xplh_retrybuf_flit_out.eof[1] && !xplh_retrybuf_flit_out.enf;
    end
    // IDLE State propogate downstream halt send Flit from Transaction Layer
    default : begin
      int_rbuf_rd_done = 1'b0;
      xplh_retrybuf_replay_in_progress = 1'b0;
      int_rbuf_re = 1'b0;
      int_xplh_retrybuf_halt = halt_in;
      int_nak_11 = 1'b0;
      int_rbuf_read_halt = 1'b0;
      int_en_nop_cnt = 1'b0;
      xplh_retrybuf_flit_out = int_flit_in;
      xplh_retrybuf_flit_out.data = inject_crc_error((cxl_viral_err || cxl_vir_inband_mark_crc), xplh_retrybuf_flit_out.data, ( 1'b0), xplh_retrybuf_flit_out.eof[1]);
      int_rbuf_fifo_pop = 1'b0;
      int_sent_pyld_expl = '0;
      rbuf_rvalid_to_checker = 1'b0;
    end
  endcase
end : rbuf_fsm_out_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_nak_11_r  <= #TP 1'b0;
  else
    int_nak_11_r  <= #TP int_nak_11;
end

assign xplh_retrybuf_nak_11 = int_nak_11 && xplh_retrybuf_flit_out.retry_flit;

// -------------------------------------------------------------------------------------
// Retry Buffer Interface Signals
// -------------------------------------------------------------------------------------
assign int_retrybuf_ram_in.retryram_raddr = int_rbuf_raddr;
assign int_retrybuf_ram_in.retryram_waddr = int_rbuf_waddr;
assign int_retrybuf_ram_in.retryram_data  = int_rbuf_wdata;
assign int_retrybuf_ram_in.retryram_we    = int_rbuf_we;
assign int_retrybuf_ram_in.retryram_en    = int_rbuf_re;

logic [P_RBUF_PW-1:0] int_rbuf_raddr_r, rbuf_raddr_to_checker;

// Retry RAM Interfaces
xplh_retryram_if
 #(
  .RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE)
) u_xplh_retryram_if (
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .flit_in                    (flit_in),
  .retryram_if_in             (int_retrybuf_ram_in),
  .retrybuf_rdata             (int_rbuf_fifo_dout),
  .rbuf_raddr_to_checker      (rbuf_raddr_to_checker),
  .xplh_retryram_if_rdata     (int_rbuf_rdata),
  .xplh_retryram_if_out       (xplh_retrybuf_ram_if),
  .xplh_retryram_if_flit_out  (int_retryram_if_flit_out)
  ,
  .retrybuf_rdata_valid       (rbuf_rvalid_to_checker),
  .xplh_retryram_if_err_log   (xplh_retrybuf_ras_dp_err_log),
  .xplh_retryram_if_rdata_err (xplh_retrybuf_rdata_err)
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
);

assign int_flit_in = int_retryram_if_flit_out;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_rbuf_rd_flag_r  <= #TP 1'b0;
  else begin
    if(state_r != RBUF_READ)
      int_rbuf_rd_flag_r  <= #TP 1'b0;
    else if((state_r == RBUF_READ) && int_rbuf_en_re)
      int_rbuf_rd_flag_r  <= #TP 1'b1;
  end
end

// If NAK11->NAK10 transition occurs during RBUF_READ dont reload the read pointer
assign int_selective_replay_fe = !int_selective_replay && int_selective_replay_r && int_rbuf_rd_flag_r;

// Retry Buffer Read Address
always_comb begin : rd_addr_PROC
  // Load with the read pointer before starting to read the RAM
  // In SPIF mode and state=RBUF_READ pyld flits can still be added to retrybuf.
  if((state_r == RBUF_READ) && int_rbuf_en_re && !int_selective_replay_fe)
    int_rbuf_raddr = int_rbuf_rd_ptr_r;
  // Increment when replay is in progress until retry buffer is empty
  else if(int_rbuf_re) begin
    if(xplh_retrybuf_ram_if.retryram_raddr == (P_RBUF_DEPTH - 1))
      int_rbuf_raddr = P_PTR_RST_VAL;
    else
      int_rbuf_raddr = xplh_retrybuf_ram_if.retryram_raddr + 1'b1;
  end else
    int_rbuf_raddr = xplh_retrybuf_ram_if.retryram_raddr;
end : rd_addr_PROC

assign int_rbuf_en_re = int_rbuf_re && !xplh_retrybuf_ram_if.retryram_en;

// -------------------------------------------------------------------------------------
// Flit DW Counter 
// -------------------------------------------------------------------------------------
assign int_en_dw_cnt = !(state_r inside {IDLE, RBUF_READ, RBUF_EMPTY_RETRY});

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_PROC
  if(!core_rst_n)
    int_dw_cnt_r  <= #TP '0;
  else begin
    if(!halt_in && int_en_dw_cnt)
      int_dw_cnt_r  <= #TP int_dw_cnt_r + 1'b1;
  end
end : flit_PROC

// -------------------------------------------------------------------------------------
// NOP DW Counter 
// -------------------------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_flit_PROC
  if(!core_rst_n)
    int_nop_cnt_r  <= #TP '0;
  else begin
    if(!halt_in) begin
      if(int_en_nop_cnt)
        int_nop_cnt_r <= #TP int_nop_cnt_r + 1'b1;
      else
        int_nop_cnt_r <= #TP '0;
    end
  end
end : nop_flit_PROC

// -------------------------------------------------------------------------------------
// Instantiate FIFO controller
// -------------------------------------------------------------------------------------
// FIFO Push 1 cycle extra delay due to registering of the read enable

// delay read enable and address (address will be used by the RAS checker)
delay_n_w_enable
 #(
  .N  (P_RBUF_READ_LATENCY+1),
  .WD (P_RBUF_PW)
) delay_n_w_enable_read_en_addr (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear (1'b0),
  .en    (int_rbuf_re),
  .din   (int_rbuf_raddr),
  .dout  (int_rbuf_raddr_r) 
);
// just delay the read enable
delay_n

#(P_RBUF_READ_LATENCY+1, 1) u_rbuf_re_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (int_rbuf_re),
  .dout   (int_rbuf_re_r)
);

// Retry buffer read done
always_ff @(posedge core_clk or negedge core_rst_n) begin : rd_done_PROC
  if(!core_rst_n)
    int_rbuf_rd_done_r  <= #TP 1'b0;
  else
    int_rbuf_rd_done_r  <= #TP int_rbuf_rd_done;
end : rd_done_PROC

assign int_rbuf_fifo_push_n = !int_rbuf_re_r; 
assign int_rbuf_fifo_pop_n = !int_rbuf_fifo_pop;

// Retry Buffer Read FIFO
// Push the data read back from the RAM
// Pop from the FIFO at the Flit boundary and transmit the data
DWC_pcie_ctl_bcm65_td
 #(
    .WIDTH            (P_RBUF_WD + P_RBUF_PW),
    .DEPTH            (P_FIFO_DEPTH),
    .ADDR_WIDTH       (P_FIFO_ADD_WD),
    .AE_LEVEL         (1),
    .AF_LEVEL         (P_RBUF_READ_LATENCY + 1),
    .ERR_MODE         (0),
    .RST_MODE         (0),
    .REG_DELAY_TIME   (1),
    .REG_DELAY_DENOM  (10)
) u_rbuf_fifo (
    .clk              (core_clk),
    .rst_n            (core_rst_n),
    .init_n           (1'b1),
    .push_req_n       (int_rbuf_fifo_push_n),
    .pop_req_n        (int_rbuf_fifo_pop_n),
    .diag_n           (1'b1),
    .data_in          ({int_rbuf_raddr_r ,retryram_data}),
    .empty            (int_rbuf_fifo_empty),
    .almost_empty     ( int_rbuf_fifo_ae),
    .half_full        (),
    .almost_full      (int_rbuf_fifo_almost_full),
    .full             (),
    .error            ()
    ,
    .data_out         ({rbuf_raddr_to_checker, int_rbuf_fifo_dout})
);


endmodule
