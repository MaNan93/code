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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_control.sv#7 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Control
//
// Description: This module manages the link layer transmit protocols in response to the
// physical link state. Exchange IDLE Flits during link up and transitions to L0, perform
// Flit Sequence Number Handshake protocol. Request NOP Flit generation when required.
// Handle Low power state transitions. Insert replay command for Ack/Nak along with the
// sequence number. Back-pressure the upper layer as required.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xplh_control
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::tx_cmd_e;
  import  cx_pl_pkg::CMD_IDLE;
  import  cx_pl_pkg::CMD_NOP;
  import  cx_pl_pkg::CMD_PYLD;
  import  cx_pl_pkg::CMD_ABANDON_LP;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::CMD_FLUSH_XAIM;
  import  cx_pl_pkg::CMD_RESET;
  import  cx_pl_pkg::P_TX_SEQNUM_WD;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::fm_dllp_struct;
  import  cx_pl_pkg::NOP_DLLP;
  import  cx_pl_pkg::NOP2_DLLP;
  import  cx_pl_pkg::PM_ENTER_L1;
  import  cx_pl_pkg::PM_ENTER_L23;
  import  cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
  import  cx_pl_pkg::PM_REQUEST_ACK;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::P_MAX_SEQNUM;
  import  cx_pl_pkg::P_DLP0_END;
  import  cx_pl_pkg::P_DLP1_END;
  import  cx_pl_pkg::P_TYPE_OF_DLP;
  import  cx_pl_pkg::P_DLP2_END;
  import  cx_pl_pkg::P_REPLAY_CMD_END;
  import  xplh_pkg::xplh_state_e;
  import  xplh_pkg::flit_usage_e;
  import  xplh_pkg::dllp_pyld_type_e;  
  import  xplh_pkg::FLIT_SEQ_NUM_HS;
  import  xplh_pkg::NORMAL;
  import  xplh_pkg::FLUSH;
  import  xplh_pkg::RESET;
  import  xplh_pkg::IDLE_OR_NOP;
  import  xplh_pkg::PAYLOAD;
  import  xplh_pkg::DLLP;
  import  xplh_pkg::OPT_UPD_OR_FM;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter   TP          = `TP
  ,
  parameter   RAS_DP_PROT_CHK_ID_BASE = 0
) 
                     (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                               core_clk,                     // Core clock
  input                               core_rst_n,                   // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // Flit Interfaces 
  // -------------------------------------------------------------------------------------
  input   tx_flit_struct              xdlh_xplh_flit,               // Flit Input Interface 
  output  logic                       xplh_control_halt,            // Back-pressure the upper link layer
  output  tx_flit_struct              xplh_control_flit,            // Flit Output Interface
  input                               xmlh_xplh_halt,               // Back-pressure from the physical layer interface 
  // -------------------------------------------------------------------------------------
  // XPLH Interfaces
  // -------------------------------------------------------------------------------------
  input                               clear_pipe,                   // Reset the data path pipeline
  input                               xplh_idle_gen_ack,            // Indicates transition to sending IDLE Flits
  input   [P_TX_SEQNUM_WD-1:0]        tx_seqnum,                    // Transmitter Sequence Number
  input   [P_TX_SEQNUM_WD-1:0]        nop_expl_seqnum,              // Transmitter Sequence Number for explicit NOP Flit
  input                               grant_dllp,                   // When set to 1 DLLP may be granted
  input                               xplh_pipe_cmd_ack,            // Command Acknowledge after XPLH Pipeline
  input                               retrybuf_idle,                // No flit currently being replayed
  input                               retrybuf_empty_retry,         // Retry is in empty retry state
  output  logic [1:0]                 xplh_control_expl_seq_cnt,    // Explicit sequence number counter
  input                               replay_timeout,               // Replay Timeout Occured
  // -------------------------------------------------------------------------------------
  // Layer1 Interface
  // -------------------------------------------------------------------------------------
  output  logic                       xplh_control_req_rcvry,       // XPLH requests the LTSSM to transition to RECOVERY
  output  logic                       xplh_control_xmlh_cmd_ack,    // XPLH command Ack to XMLH
  // -------------------------------------------------------------------------------------
  // Command Interface
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct               xmlh_xplh_cmd,                // XMLH Commands
  output  logic                       xplh_control_cmd_ack,         // XPLH Command Acknowledge
  input                               xdlh_xplh_cmd_ack,            // Command Acknowledge from upper Layer
  output  tx_cmd_struct               xplh_control_cmd,             // Command Acknowledge to upper Layer 
  output  logic                       xplh_control_normal,          // NORMAL State
  // -------------------------------------------------------------------------------------
  // Link Layer Interface
  // -------------------------------------------------------------------------------------
  input   [2:0]                       current_data_rate,            // Data rate for transmission
  input                               rcvd_expl_seq_num,            // Explicit Sequence Number Flit with non-zero sequence number has been received in sequence number handshake phase
  input                               cxl_mode_enable,              // CXL Mode is enabled
  input                               cxl_viral_eof,                // CXL viral indication at eof
  input                               xplh_nop_phy_flit,            // NOP flit on the interface is Physical Layer NOP - do not allow DLLP insertion
  input                               xplh_nop_gen_ack,             // NOP Generator Command Acknowledge
  input                               xplh_spif_enable,             // SPIF Interface Enable
  output                              xplh_spif_dllp_trdy,          // XPLH ready to transmit DLLP
  //--------------------------------------------------------------------------------------
  // RAS-DES Interface
  //--------------------------------------------------------------------------------------
  input                               cdm_ras_des_einj1_enable,
  input                               cdm_ras_des_einj1_seq_type,
  input  [12: 0]                      cdm_ras_des_einj1_bad_seq,
  input  [7 : 0]                      cdm_ras_des_einj1_count,
  output [1 : 0]                      xplh_ras_des_einj1_exp_sequm_evt,     // Pluse to indicate error injection event occurred in explict sequence number
  output                              xplh_ras_des_einj1_ack_nak_sequm_evt, // Pluse to indicate error injection event occurred in ACK/NAK sequence number 
  // -------------------------------------------------------------------------------------
  // LRSM Interface
  // -------------------------------------------------------------------------------------
  input   replay_cmd_t                xplh_lrsm_replay_cmd,         // Replay Command for Ack/Nak
  input   [P_TX_SEQNUM_WD-1:0]        xplh_lrsm_seqnum,             // Sequence number for Ack/Nak
  output  logic                       xplh_control_sent_ack,        // Pulse when an Ack is sent
  output  logic                       xplh_control_sent_nak,        // Pulse when a Nak is sent
  output  logic                       xplh_control_dllp_halt,       // Halt DLLP's
  input   fm_dllp_struct              xdlh_xplh_fm_dllp,            // DLLP Input
  output  logic [2:0]                 xplh_control_tx_nak_cnt,      // Consecutive Nak counter
  output  logic                       xplh_control_tx_nak_cnt_incr  // Consecutive Nak counter
  ,
  input   ras_dp_err_inj_t            ras_dp_err_inj                // RASDP Error Injection
  ,
  output  logic [2:0]                 xplh_control_flit_count,      // Flit Counter saturate at 4 reset when disabled
  input                               xplh_flit_count_en            // Enable flit counter
  ,
  output  logic                       xplh_control_acknak_pend      // Ack/Nak pending to transmit
  ,
  output  logic                       xplh_control_replay_00_valid  // Replay 00 Valid
);

// -------------------------------------------------------------------------------------
// Local Param Declarations 
// -------------------------------------------------------------------------------------
localparam  XPLH_CONTROL_PIPE_WD  = $bits(xdlh_xplh_flit) + 1;

// -------------------------------------------------------------------------------------
// Logic Declarations 
// -------------------------------------------------------------------------------------
logic                       int_control_flit_marker;
logic                       int_idle_cmd_r;
logic                       int_idle_cmd_re;
logic [8:0]                 flit_cnt_r;
logic                       flit_cnt_exp_r;
logic [1:0]                 ack_cnt_r;
logic [1:0]                 ack_cnt;
logic                       ack_cnt_exp_r;
logic                       ack_cnt_exp;
logic [3:0]                 replay_00_cnt;
logic                       replay_00_cnt_exp;
logic [3:0]                 replay_00_cnt_r;
logic                       replay_00_cnt_exp_r;
logic                       int_xplh_cmd_ack;
logic                       int_cmd_if_pending;
logic                       int_pipe_halt;
logic [P_TX_SEQNUM_WD-1:0]  seqnum;
logic                       int_ack_sent;
logic                       replay_00_upd;
logic [P_TX_SEQNUM_WD-1:0]  int_req_seqnum_r;
logic [P_TX_SEQNUM_WD-1:0]  int_ackd_seqnum_r;
logic [7:0]                 dlp0;
logic [7:0]                 dlp1;
flit_usage_e                int_flit_usage;
dllp_pyld_type_e            int_dllp_pyld_type;
logic                       flit_marker_indicator;
logic                       int_flit_marker;
logic                       int_xdlh_xplh_cmd_ack;
logic                       int_prior_payload;
logic                       int_prior_payload_r;
logic                       int_replay_00_valid;
logic                       int_req_rcvry;
logic                       int_seq_hs_pend_r;
logic                       int_send_expl_seqnum_r;
logic                       int_clear_cnt;
logic                       int_hold_dllp;
logic                       int_hold_dllp_r;
replay_cmd_t                int_replay_cmd;
tx_flit_struct              int_flit;
tx_flit_struct              xplh_ras_des_einj1_flit_out;
tx_flit_struct              flit_rasdes_einj;
fm_dllp_struct              int_fm_dllp;
logic                       xplh_cxl_io_nxt;      // Indicates that the transmitting flit is CXL.io - Next State
logic                       xplh_cxl_io_r;        // Indicates that the transmitting flit is CXL.io - Register
logic                       int_cxl_io_flit;
logic                       int_flit_marker_present_s;
logic                       insert_dlp_0_1;
logic                       int_dllp_granted;
logic                       int_dllp_granted_r;

xplh_state_e next_state, state_r, data_state;


assign insert_dlp_0_1 = ( cxl_mode_enable ? int_flit.sof : int_flit.eof[1]) && !int_pipe_halt;

assign flit_marker_indicator = cxl_mode_enable ? xdlh_xplh_flit.data[4] : (xdlh_xplh_flit.data[P_DLP2_END] && xdlh_xplh_flit.data[P_TYPE_OF_DLP]);

assign xplh_control_normal = (state_r == NORMAL) || ((state_r == FLUSH) && !int_seq_hs_pend_r);

assign int_xdlh_xplh_cmd_ack = xplh_spif_enable ? xplh_nop_gen_ack : xdlh_xplh_cmd_ack;

assign xplh_spif_dllp_trdy = !int_flit_marker && !int_pipe_halt && xdlh_xplh_flit.eof[1] && !int_flit_marker_present_s && !xplh_nop_phy_flit && (cxl_mode_enable ? xplh_cxl_io_r : 1'b1);

always_comb begin : xplh_state_PROC
  next_state = state_r;
  case (state_r)
    // Alternate between Flits with Replay Command 00 and ACK/NAK
    // Wait for 3 Acks and 9 Flits with Replay Command 00 to be sent
    // Transition to Recovery if Flit Counter expires or directed by LTSSM
    FLIT_SEQ_NUM_HS : begin
      if(!int_cmd_if_pending) begin
        // 3 unique acks and 9 Replay 00 sent so move to normal state
        if(replay_00_cnt_exp_r && ack_cnt_exp_r)
          next_state = NORMAL;
        // XMLH Requests Flush
        else if(xmlh_xplh_cmd.req && (xmlh_xplh_cmd.tx_cmd inside {CMD_FLUSH_XTLH, CMD_FLUSH_XAIM}))
          next_state = FLUSH;
        else
          next_state = FLIT_SEQ_NUM_HS;
      end
    end
    // Transmitter sends Payload or NOP Flits carrying Ack/Nak or Flits from the
    // retry buffer with Replay Command 00.
    NORMAL : begin
      if(!int_cmd_if_pending) begin
        // XMLH Requests flush
        if(((xmlh_xplh_cmd.tx_cmd == CMD_FLUSH_XTLH) || (xmlh_xplh_cmd.tx_cmd == CMD_FLUSH_XAIM)) && xmlh_xplh_cmd.req)
          next_state = FLUSH;
      end
    end
    // Flush pending TLPs
    FLUSH : begin
      // Hold until the command interface completes
      if(!int_cmd_if_pending) begin
        // XMLH abandonded low power entry
        if(xmlh_xplh_cmd.tx_cmd == CMD_ABANDON_LP)
          next_state = NORMAL;
        // XMLH exited recovery and is requesting payload flits return to sequence number handshake
        else if(xmlh_xplh_cmd.tx_cmd == CMD_PYLD)
          next_state = FLIT_SEQ_NUM_HS;
        else
          next_state = FLUSH;
      end
    end
    default : begin // After Flit mode enable start NOP generation to prepare for Sequence number handshake
      if(xmlh_xplh_cmd.req && (xmlh_xplh_cmd.tx_cmd == CMD_IDLE) && xmlh_xplh_cmd.flit_mode)
        next_state = FLIT_SEQ_NUM_HS;
    end
  endcase
end : xplh_state_PROC

// XPLH State Register
always_ff @(posedge core_clk or negedge core_rst_n) begin : state_PROC
  if(!core_rst_n)
    state_r <= #TP RESET;
  else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      state_r <= #TP RESET;
    else
      state_r <= #TP next_state;
  end
end : state_PROC

// During Pipeline Flushing on Recovery Transition ensure that sequence number handshake Flits are in the pipeline
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_send_expl_seqnum_r  <= #TP '0;
  else
    int_send_expl_seqnum_r  <= #TP !grant_dllp;
end

// Hold off on updating the DLLP for the first flit after re-entering Sequence Number Handshake
// This will allow any DLLP that may have been halted prior to the transition to FLUSH to be transmitted
always_comb begin : hold_dllp_PROC
  if((!int_pipe_halt && xdlh_xplh_flit.eof[1] && (state_r == FLIT_SEQ_NUM_HS)) || (state_r == RESET))
    int_hold_dllp = 1'b0;
  else if(!grant_dllp)
    int_hold_dllp = 1'b1;
  else
    int_hold_dllp = int_hold_dllp_r;
end : hold_dllp_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_hold_dllp_r <= #TP 1'b0;
  else
    int_hold_dllp_r <= #TP int_hold_dllp;
end

always_comb begin : flit_usage_PROC
  if (xdlh_xplh_flit.sof)
    int_flit_usage = flit_usage_e'(xdlh_xplh_flit.data[7:6]);
  else
  if((xdlh_xplh_flit.eof == 2'b11 || xdlh_xplh_flit.eof == 2'b01) &&  xdlh_xplh_flit.enf)
    int_flit_usage = IDLE_OR_NOP;
  else
    int_flit_usage = PAYLOAD;
end : flit_usage_PROC

always_comb begin : dllp_pyld_type_PROC
  if(( cxl_mode_enable ? xdlh_xplh_flit.sof : (xdlh_xplh_flit.eof == 2'b11 || xdlh_xplh_flit.eof == 2'b01)) && (xdlh_xplh_fm_dllp.opt_upd_fc == 1'b0 && flit_marker_indicator == 1'b0))
    int_dllp_pyld_type = DLLP;
  else
    int_dllp_pyld_type = OPT_UPD_OR_FM;
end : dllp_pyld_type_PROC

// If Flit marker was sent in the EOF cycle do not grant a new DLLP on the next SOF
// Previously granted DLLP will be held and inserted on next EOF
always_comb begin : flit_marker_PROC
  if( cxl_mode_enable ? xdlh_xplh_flit.sof : xdlh_xplh_flit.eof[0])
    int_control_flit_marker = flit_marker_indicator;
  else
    int_control_flit_marker = '0;
end : flit_marker_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : fm_sync_PROC
  if(!core_rst_n)
    int_flit_marker <= #TP '0;
  else begin
    if(state_r == RESET)
      int_flit_marker <= #TP '0;
    else if(int_control_flit_marker)
      int_flit_marker <= #TP '1;
    else if(!int_pipe_halt && xdlh_xplh_flit.sof)
      int_flit_marker <= #TP '0;
    else
      int_flit_marker <= #TP int_flit_marker;
  end
end : fm_sync_PROC

assign int_flit_marker_present_s = int_flit_marker || int_control_flit_marker;

// Drive the command acknowledge to the XMLH
// Drive the Halt to the DLLP generator to update the DLLP arbitration
// Drive Ack/Nak indications to LRSM/RRSM
always_comb begin : xplh_out_PROC
  // Halt is driven from the physical layer.
  xplh_control_halt = int_pipe_halt;
  int_req_rcvry = xplh_control_req_rcvry;
  xplh_control_sent_ack = 1'b0;
  xplh_control_sent_nak = 1'b0;
  xplh_control_dllp_halt = 1'b1;
  int_dllp_granted = '0;
  case (state_r)
    FLIT_SEQ_NUM_HS : begin
      int_req_rcvry = flit_cnt_exp_r ? 1'b1 : xplh_control_req_rcvry;
      xplh_control_sent_nak = (xdlh_xplh_flit.eof[1] && !int_pipe_halt) && (xplh_lrsm_replay_cmd inside {NAK_10, NAK_11});
      xplh_control_sent_ack = (xdlh_xplh_flit.eof[1] && !int_pipe_halt) && (xplh_lrsm_replay_cmd == ACK);
      if((next_state == FLUSH) && ((xdlh_xplh_flit.eof[0] && !int_pipe_halt) || (xdlh_xplh_flit.eof[1]) || (xdlh_xplh_flit.sof && int_pipe_halt)))
        xplh_control_dllp_halt = 1'b0;
      else
        xplh_control_dllp_halt = !int_flit_marker && (!int_hold_dllp && grant_dllp) ? !(!int_pipe_halt && xdlh_xplh_flit.sof) : 1'b1;
    end
    NORMAL : begin
      xplh_control_sent_nak = (xdlh_xplh_flit.eof[1] && !int_pipe_halt) && (xplh_lrsm_replay_cmd inside {NAK_10, NAK_11});
      xplh_control_sent_ack = (xdlh_xplh_flit.eof[1] && !int_pipe_halt) && (xplh_lrsm_replay_cmd == ACK);
      xplh_control_dllp_halt = int_flit_marker || !(!int_pipe_halt && xdlh_xplh_flit.sof);
      int_dllp_granted = xplh_control_dllp_halt ? 1'b1 : int_dllp_granted_r;
    end
    FLUSH : begin
      int_req_rcvry = 1'b0; // Flush initiated reset the recovery transition request
      xplh_control_sent_nak = (xdlh_xplh_flit.eof[1] && !int_pipe_halt) && (xplh_lrsm_replay_cmd inside {NAK_10, NAK_11});
      xplh_control_sent_ack = (xdlh_xplh_flit.eof[1] && !int_pipe_halt) && (xplh_lrsm_replay_cmd == ACK);
      if(xmlh_xplh_cmd.tx_cmd == CMD_FLUSH_XAIM)
        xplh_control_dllp_halt = int_flit_marker || !(!int_pipe_halt && xdlh_xplh_flit.sof);
      else
        xplh_control_dllp_halt = int_dllp_granted_r ? (int_flit_marker || !(!int_pipe_halt && xdlh_xplh_flit.sof)) : 1'b1;
      int_dllp_granted = !xplh_control_dllp_halt ? 1'b0 : int_dllp_granted_r;
    end
    default : begin
      xplh_control_halt = int_pipe_halt;
      int_req_rcvry = 1'b0;
      xplh_control_sent_ack = 1'b0;
      xplh_control_sent_nak = 1'b0;
      xplh_control_dllp_halt = 1'b1;
      int_dllp_granted = '0;
    end
  endcase
end : xplh_out_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : dllp_granted_PROC
  if(!core_rst_n)
    int_dllp_granted_r  <= #TP '0;
  else
    int_dllp_granted_r  <= #TP int_dllp_granted;
end : dllp_granted_PROC

// Determine which type of Flit to send based on the XPLH State
always_comb begin : xplh_data_out_PROC
  // Default is to drive the interface from the transaction layer input.
  int_flit = xdlh_xplh_flit;
  int_fm_dllp = '0;
  case (data_state)
    FLIT_SEQ_NUM_HS : begin
        int_fm_dllp = xdlh_xplh_fm_dllp;
      // Before DL_UP Drive NOP command during sequence number handshake afterwards drive Payload
      // Sequence Handshake Flit
      int_flit.data =  ins_seq_hs_dlp_bytes (
                        .cxl_mode_enable      (cxl_mode_enable),
                        .cxl_io_flit          (int_cxl_io_flit),
                        .sof                  (xdlh_xplh_flit.sof),
                        .data_in              (xdlh_xplh_flit.data),
                        .eof                  (xdlh_xplh_flit.eof),
                        .enf                  (xdlh_xplh_flit.enf),
                        .dllp                 (int_fm_dllp),
                        .flit_usage           (int_flit_usage),
                        .flit_marker          (int_flit_marker_present_s),
                        .dllp_pyld_type       (int_dllp_pyld_type),
                        .prior_payload        (int_prior_payload_r),
                        .nop_expl_seqnum      (nop_expl_seqnum),
                        .next_tx_seqnum       (tx_seqnum),
                        .tx_ack_nak_type      (xplh_lrsm_replay_cmd),
                        .tx_ack_nak_seqnum    (xplh_lrsm_seqnum),
                        .cons_tx_expl_seqnum  (xplh_control_expl_seq_cnt));
    end
    // Normal state insert Ack/Nak into the Flit unless we are in the midst of a replay
    NORMAL : begin
        int_fm_dllp = xdlh_xplh_fm_dllp;
      // Normal State Flit
      int_flit.data = ins_normal_dlp_bytes (
                        .cxl_mode_enable    (cxl_mode_enable),
                        .cxl_io_flit        (int_cxl_io_flit),
                        .sof                (xdlh_xplh_flit.sof),
                        .data_in            (xdlh_xplh_flit.data),
                        .eof                (xdlh_xplh_flit.eof),
                        .enf                (xdlh_xplh_flit.enf),
                        .retry_flit         (xdlh_xplh_flit.retry_flit),
                        .expl_flit          (xdlh_xplh_flit.expl_flit),
                        .dllp               (int_fm_dllp),
                        .flit_usage         (int_flit_usage),
                        .flit_marker        (int_flit_marker_present_s),
                        .dllp_pyld_type     (int_dllp_pyld_type),                        
                        .prior_payload      (int_prior_payload_r),
                        .next_tx_seqnum     (tx_seqnum),
                        .nop_expl_seqnum    (nop_expl_seqnum),
                        .expl_seq_cnt       (xplh_control_expl_seq_cnt),
                        .tx_nak_cnt         (xplh_control_tx_nak_cnt),
                        .tx_ack_nak_type    (xplh_lrsm_replay_cmd),
                        .tx_ack_nak_seqnum  (xplh_lrsm_seqnum));
    end
    // Request Flushing of the transaction layer or XAIM depending on command from Layer1
    FLUSH : begin
      // When Flushing for Low Power Entry continue to grant DLLP's otherwise send NOP DLLP's 
      if(xmlh_xplh_cmd.tx_cmd == CMD_FLUSH_XAIM) begin
        if(int_send_expl_seqnum_r)
          int_fm_dllp.dllp_type = NOP2_DLLP;
        else
          int_fm_dllp = xdlh_xplh_fm_dllp;
      end else begin
        if(int_dllp_granted_r)
          int_fm_dllp = xdlh_xplh_fm_dllp;
        else
          int_fm_dllp.dllp_type = NOP2_DLLP;
      end
      // Continue the sequence number handshake while flushing
      // Either the sequence handshake has not completed yet or it completed but we need
      // to ensure that during the pipeline flush we inject explicit sequence number flit (int_send_expl_seqnum_r)
      if(int_seq_hs_pend_r || int_send_expl_seqnum_r) begin
        int_flit.data =  ins_seq_hs_dlp_bytes (
                          .cxl_mode_enable      (cxl_mode_enable),
                          .cxl_io_flit          (int_cxl_io_flit),
                          .sof                  (xdlh_xplh_flit.sof),
                          .data_in              (xdlh_xplh_flit.data),
                          .eof                  (xdlh_xplh_flit.eof),
                          .enf                  (xdlh_xplh_flit.enf),
                          .dllp                 (int_fm_dllp),
                          .flit_usage           (int_flit_usage),
                          .flit_marker          (int_flit_marker_present_s),
                          .dllp_pyld_type       (int_dllp_pyld_type),
                          .prior_payload        (int_prior_payload_r),
                          .next_tx_seqnum       (tx_seqnum),
                          .nop_expl_seqnum      (nop_expl_seqnum),
                          .tx_ack_nak_type      (xplh_lrsm_replay_cmd),
                          .tx_ack_nak_seqnum    (xplh_lrsm_seqnum),
                          .cons_tx_expl_seqnum  (xplh_control_expl_seq_cnt));
      // Continue normal protocol while flushing
      end else begin
        int_flit.data = ins_normal_dlp_bytes (
                          .cxl_mode_enable    (cxl_mode_enable),
                          .cxl_io_flit        (int_cxl_io_flit),
                          .sof                (xdlh_xplh_flit.sof),
                          .data_in            (xdlh_xplh_flit.data),
                          .eof                (xdlh_xplh_flit.eof),
                          .enf                (xdlh_xplh_flit.enf),
                          .next_tx_seqnum     (tx_seqnum),
                          .dllp               (int_fm_dllp),
                          .flit_usage         (int_flit_usage),
                          .flit_marker        (int_flit_marker_present_s),
                          .dllp_pyld_type     (int_dllp_pyld_type),
                          .prior_payload      (int_prior_payload_r),
                          .retry_flit         (xdlh_xplh_flit.retry_flit),
                          .expl_flit          (xdlh_xplh_flit.expl_flit),
                          .nop_expl_seqnum    (nop_expl_seqnum),
                          .expl_seq_cnt       (xplh_control_expl_seq_cnt),
                          .tx_nak_cnt         (xplh_control_tx_nak_cnt),
                          .tx_ack_nak_type    (xplh_lrsm_replay_cmd),
                          .tx_ack_nak_seqnum  (xplh_lrsm_seqnum));
      end
    end
    default : begin
      int_flit = '0;
      int_fm_dllp = '0;
    end
  endcase
end : xplh_data_out_PROC

// Maintain using the same DLLP bytes over the last 2 cycles of the Flit if the data path width is 128-bit
always_comb begin : data_state_PROC
  data_state = state_r;
end : data_state_PROC


// Counting transmitted Flits during FLIT_SEQ_NUM_HS state
// If this counter expired the link must transition to Recovery
always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_cnt_PROC
  if(!core_rst_n) begin
    flit_cnt_r <= #TP 'h0;
    flit_cnt_exp_r <= #TP 'b0;
  end else begin
    if(state_r == RESET) begin
      flit_cnt_r <= #TP '0;
      flit_cnt_exp_r <= #TP '0;
    end else if(state_r == FLIT_SEQ_NUM_HS) begin
      if(xdlh_xplh_flit.eof[1] && !int_pipe_halt) begin
        flit_cnt_r <= #TP flit_cnt_r + 'b1;
        flit_cnt_exp_r <= #TP (current_data_rate == 3'b101) ? (flit_cnt_r == 9'h1FF) : (flit_cnt_r == 9'h0FF);
      end
    end else begin
      flit_cnt_r <= #TP 'h0;
      flit_cnt_exp_r <= #TP 'b0;
    end
  end
end : flit_cnt_PROC

// Extract the replay command from the data path
assign int_replay_cmd = cxl_mode_enable ? replay_cmd_t'(int_flit.data[3:2]) : replay_cmd_t'(int_flit.data[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1]);
assign int_ack_sent = ((xplh_lrsm_replay_cmd == ACK) && ((int_replay_cmd == ACK) && insert_dlp_0_1));
assign replay_00_upd = ((state_r inside {FLUSH, FLIT_SEQ_NUM_HS}) || int_send_expl_seqnum_r) && (seqnum != 0) && (int_replay_cmd == REPLAY_00) && insert_dlp_0_1;

// Register the latest transmitted Ack/Nak Sequence Number generate ack/nak pending indication
always_ff @(posedge core_clk or negedge core_rst_n) begin : ack_nak_pending_PROC
  if(!core_rst_n) begin
    int_req_seqnum_r          <= #TP '0;
    int_ackd_seqnum_r         <= #TP '0;
    xplh_control_acknak_pend  <= #TP '0;
  end else begin
    xplh_control_acknak_pend  <= #TP !(int_ackd_seqnum_r == int_req_seqnum_r);
    // Register the last Ack/Nak sequence number transmitted
    if((int_replay_cmd inside {ACK, NAK_10, NAK_11}) && insert_dlp_0_1) begin
      int_ackd_seqnum_r <= #TP seqnum;
    end
    // Regiser the requested Ack/Nak sequence number
    if(xplh_lrsm_replay_cmd inside {ACK, NAK_10, NAK_11}) begin
      int_req_seqnum_r  <= #TP xplh_lrsm_seqnum;
    end
  end
end : ack_nak_pending_PROC

// Count the number of unique Ack's sent during Flit sequence number handshake
always_ff @(posedge core_clk or negedge core_rst_n) begin : sync_cnt_PROC
  if(!core_rst_n) begin
    ack_cnt_r             <= #TP '0;
    ack_cnt_exp_r         <= #TP '0;
    replay_00_cnt_r       <= #TP '0;
    replay_00_cnt_exp_r   <= #TP '0;
    int_prior_payload_r   <= #TP '0;
  end else begin
    if(state_r == RESET) begin
      ack_cnt_r           <= #TP '0;
      ack_cnt_exp_r       <= #TP '0;
      replay_00_cnt_r     <= #TP '0;
      replay_00_cnt_exp_r <= #TP '0;
      int_prior_payload_r <= #TP '0;
    end else begin
      ack_cnt_r           <= #TP ack_cnt;
      ack_cnt_exp_r       <= #TP ack_cnt_exp;
      replay_00_cnt_r     <= #TP replay_00_cnt;
      replay_00_cnt_exp_r <= #TP replay_00_cnt_exp;
      int_prior_payload_r <= #TP int_prior_payload;
    end
  end
end : sync_cnt_PROC

// Reset the ack/replay counters when idle command is asserted
always_ff @(posedge core_clk or negedge core_rst_n) begin : idle_cmd_re_PROC
  if(!core_rst_n)
    int_idle_cmd_r  <= #TP '0;
  else
    int_idle_cmd_r  <= #TP xmlh_xplh_cmd.req && (xmlh_xplh_cmd.tx_cmd == CMD_IDLE);
end : idle_cmd_re_PROC

assign int_idle_cmd_re = ((xmlh_xplh_cmd.tx_cmd == CMD_IDLE) && xmlh_xplh_cmd.req) && !int_idle_cmd_r;

// Ack counter during sequence number handshake we must transmit 3 unique Acks
always_comb begin : seq_num_hs_cnt_PROC
  ack_cnt = 2'h0;
  ack_cnt_exp = 1'b0;
  replay_00_cnt = 4'h0;
  replay_00_cnt_exp = 1'b0;
  if((xmlh_xplh_cmd.tx_cmd == CMD_RESET) || int_idle_cmd_re) begin
    ack_cnt = 2'h0;
    ack_cnt_exp = 1'b0;
    replay_00_cnt = 4'h0;
    replay_00_cnt_exp = 1'b0;
  end else begin
    if((state_r == FLIT_SEQ_NUM_HS) || ((state_r == FLUSH) && int_seq_hs_pend_r)) begin
      // Unique Ack counter increments when Ack is transmitted and non-zero explicit sequence number flit has been received
      if(int_ack_sent && rcvd_expl_seq_num)
        ack_cnt = ack_cnt_r + 1'b1;
      else
        ack_cnt = ack_cnt_r;
      
      // Ack counter expired
      if(&ack_cnt_r)
        ack_cnt_exp = 1'b1;
      else
        ack_cnt_exp = ack_cnt_exp_r;

      // Replay 00 Counter
      if(replay_00_upd)
        replay_00_cnt = replay_00_cnt_r + 1'b1;
      else
        replay_00_cnt = replay_00_cnt_r;
      
      // Replay 00 counter expired
      if(replay_00_cnt == 4'h9)
        replay_00_cnt_exp = 1'b1;
      else
        replay_00_cnt_exp = replay_00_cnt_exp_r;
    end
  end
end : seq_num_hs_cnt_PROC

// Extract the sequence number from the transmitted Flit
assign dlp0 = cxl_mode_enable ? int_flit.data[ 7:0] : int_flit.data[P_DLP0_END -: 8];
assign dlp1 = cxl_mode_enable ? int_flit.data[15:8] : int_flit.data[P_DLP1_END -: 8];
assign seqnum = {dlp0[1:0], dlp1};

// Prior Flit was Payload Flag
always_comb begin : prior_payload_PROC
  int_prior_payload = int_prior_payload_r;
  if(xmlh_xplh_cmd.tx_cmd == CMD_IDLE)
    int_prior_payload = 1'b0;
  else if(!int_pipe_halt) begin
    if(int_flit.enf && int_flit.eof[1])
      int_prior_payload = 1'b0;
    else if(int_flit.eof[1])
      int_prior_payload = 1'b1;
    else
      int_prior_payload = int_prior_payload_r;
  end
end : prior_payload_PROC

// Replay 00 Valid
always_comb begin : flit_replay_00_valid_PROC
  case (state_r)
    FLIT_SEQ_NUM_HS : begin
      int_replay_00_valid = (xplh_control_expl_seq_cnt < 3);
    end
    NORMAL : begin
      int_replay_00_valid = (((retrybuf_empty_retry || xdlh_xplh_flit.retry_flit) && (xplh_control_expl_seq_cnt < 3))
                            || ((xplh_control_expl_seq_cnt > 0) && (xplh_control_expl_seq_cnt < 3)));
    end
    FLUSH : begin
      if(int_seq_hs_pend_r || int_send_expl_seqnum_r) begin
        int_replay_00_valid = (xplh_control_expl_seq_cnt < 3);
      end else begin
        int_replay_00_valid = (((retrybuf_empty_retry || xdlh_xplh_flit.retry_flit) && (xplh_control_expl_seq_cnt < 3))
                              || ((xplh_control_expl_seq_cnt > 0) && (xplh_control_expl_seq_cnt < 3)));
      end
    end
    default : begin
      int_replay_00_valid = 'b0;
    end
  endcase
end : flit_replay_00_valid_PROC

xplh_rasdes_einj
 u_xplh_rasdes_einj (
  .core_clk                  (core_clk),
  .core_rst_n                (core_rst_n),
  .halt_in                   (xmlh_xplh_halt),
  .cdm_ras_des_einj1_enable  (cdm_ras_des_einj1_enable),
  .cdm_ras_des_einj1_seq_type(cdm_ras_des_einj1_seq_type),
  .cdm_ras_des_einj1_bad_seq (cdm_ras_des_einj1_bad_seq),
  .cdm_ras_des_einj1_count   (cdm_ras_des_einj1_count),
  .xplh_ras_des_einj1_exp_sequm_evt (xplh_ras_des_einj1_exp_sequm_evt),     
  .xplh_ras_des_einj1_ack_nak_sequm_evt (xplh_ras_des_einj1_ack_nak_sequm_evt),
  .flit_in                   (int_flit),
  .xplh_ras_des_einj1_flit_out(xplh_ras_des_einj1_flit_out)
);

assign flit_rasdes_einj= xplh_ras_des_einj1_flit_out;

// Register the outputs
// The halt is propagated from the downstream XMLH
// The halt is registered and propagates upwards
xplh_flit_pipe
 #(
  .P_CAN_STALL  (1),
  .P_N_STAGES   (1)
  ,
  .P_BUS_PROTECT_GEN_EN       (1),
  .P_RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE)
) u_xplh_control_pipe (
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .halt_in                  (xmlh_xplh_halt),
  .xplh_flit_pipe_halt_out  (int_pipe_halt),
  .flit_in                  (flit_rasdes_einj),
  .xplh_flit_pipe_flit      (xplh_control_flit),
  .clear                    (clear_pipe)
  ,
  .xplh_flit_pipe_err_log   ()
  ,
  .ras_dp_err_inj           (ras_dp_err_inj)
);

delay_n_w_stalling
 #(
  .N          (1),
  .CAN_STALL  (0),
  .WD         (1)
) u_xplh_cmd_ack_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .stall      (xmlh_xplh_halt),
  .clear      (1'b0),
  .din        (int_xplh_cmd_ack),
  .stallout   (),
  .dout       (xplh_control_cmd_ack)
);

delay_n
 #(
  .N  (1),
  .WD (1)
) u_xplh_replay_00_valid_pipe (
  .clk      (core_clk),
  .rst_n    (core_rst_n),
  .clear    (1'b0),
  .din      (int_replay_00_valid),
  .dout     (xplh_control_replay_00_valid)
);

always_ff @(posedge core_clk or negedge core_rst_n) begin : l0p_flit_cnt_PROC
  if(!core_rst_n) begin
    xplh_control_flit_count <= #TP '0;
  end else begin
    if(xplh_flit_count_en) begin
      if(xdlh_xplh_flit.eof[1] && !int_pipe_halt && (xplh_control_flit_count < 4))
        xplh_control_flit_count <= #TP xplh_control_flit_count + 1;
    end else begin
      xplh_control_flit_count <= #TP '0;
    end
  end
end : l0p_flit_cnt_PROC


// Extend the reset to account for the EOF
// Clear the counters if a replay timeout occured
assign int_clear_cnt = replay_timeout || ((xmlh_xplh_cmd.tx_cmd inside {CMD_IDLE, CMD_RESET}) && xmlh_xplh_cmd.req) || !grant_dllp;

// Consecutive NAK Counter
xplh_tx_nak_counter
 u_tx_nak_counter(
  // Inputs
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .sof                  (int_flit.sof),
  .cxl_mode_enable      (cxl_mode_enable),
  .tx_replay_cmd        (int_replay_cmd),
  .halt_in              (int_pipe_halt),
  .clear_cnt            (int_clear_cnt),
  .enable_cnt           (int_flit.eof[0]),
  // Outputs
  .xplh_tx_nak_cnt      (xplh_control_tx_nak_cnt),
  .xplh_tx_nak_cnt_incr (xplh_control_tx_nak_cnt_incr)
);

// Consecutive Explicit Sequence Number Counter
xplh_tx_expl_seq_counter
 u_tx_expl_seq(
  // Inputs
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .data                 (int_flit.data),
  .eof                  (int_flit.eof),
  .sof                  (int_flit.sof),
  .cxl_mode_enable      (cxl_mode_enable),
  .tx_seqnum            (seqnum),
  .halt_in              (int_pipe_halt),
  .clear_cnt            (int_clear_cnt),
  // Outputs
  .xplh_tx_expl_seq_cnt (xplh_control_expl_seq_cnt)
);

// Indication that sequence number handshake is in progress
// If this signal is asserted during the FLUSH state continue to perform
// the sequence number handshake
always_ff @(posedge core_clk or negedge core_rst_n) begin : seq_hs_pend_PROC
  if(!core_rst_n)
    int_seq_hs_pend_r <= #TP 1'b0;
  else begin
    // Sequence number handshake completed during FLUSH
    if((state_r == FLUSH) && (replay_00_cnt_exp_r && ack_cnt_exp_r))
      int_seq_hs_pend_r <= #TP 1'b0;
    // Sequence number handshake complete and transition to normal state
    else if(((state_r == FLIT_SEQ_NUM_HS) && (next_state == NORMAL)) || (state_r == RESET))
      int_seq_hs_pend_r <= #TP 1'b0;
    // Started sequence number handshake and moving to FLUSH state or pipeline flush in preparation for sequence handshake
    else if((state_r == FLIT_SEQ_NUM_HS && (next_state == FLUSH)) || !grant_dllp)
      int_seq_hs_pend_r <= #TP 1'b1;
    else
      int_seq_hs_pend_r <= #TP int_seq_hs_pend_r;
  end
end : seq_hs_pend_PROC

// Request to enter Recovery during Sequence Number Handshake Phase
always_ff @(posedge core_clk or negedge core_rst_n) begin : req_rcvry_PROC
  if(!core_rst_n) begin
    xplh_control_req_rcvry  <= #TP 1'b0;
  end else begin
    xplh_control_req_rcvry  <= #TP int_req_rcvry;
  end
end : req_rcvry_PROC

assign int_cxl_io_flit = xplh_cxl_io_nxt || xplh_cxl_io_r;

always_comb begin : xplh_cxl_io_comb_PROC
  // If FlitUsage == CXL.io (2'b01) or FlitUsage == CXL.io NOP (2'b00) and vLSM.io is Active then
  // allow DLLP Payload insertion
  if (cxl_mode_enable && xdlh_xplh_flit.sof && ((xdlh_xplh_flit.data[7:6] == 2'b01) || ((xdlh_xplh_flit.data[7:6] == 2'b00) && !xplh_nop_phy_flit))) begin
    xplh_cxl_io_nxt = 1'b1;
  end else if (xdlh_xplh_flit.eof[1] && !int_pipe_halt) begin
    xplh_cxl_io_nxt = 1'b0;
  end else begin
    xplh_cxl_io_nxt = xplh_cxl_io_r;
  end
end : xplh_cxl_io_comb_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : xplh_cxl_io_seq_PROC
  if(!core_rst_n) begin
    xplh_cxl_io_r  <= #TP 1'b0;
  end else begin
    xplh_cxl_io_r  <= #TP xplh_cxl_io_nxt;
  end
end : xplh_cxl_io_seq_PROC

// -------------------------------------------------------------------------------------
// XPLH Command Interface
// -------------------------------------------------------------------------------------
xplh_cmd_if
 u_xplh_cmd_if(
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .xplh_pipe_cmd_ack          (xplh_pipe_cmd_ack),
  .xmlh_xplh_cmd              (xmlh_xplh_cmd),
  .xplh_control_state         (state_r),
  .xdlh_xplh_cmd_ack          (int_xdlh_xplh_cmd_ack),
  .xplh_cmd_if_xmlh_cmd_ack   (xplh_control_xmlh_cmd_ack),
  .xdlh_xplh_eof              (xdlh_xplh_flit.eof),
  .xplh_cmd_if_ack            (int_xplh_cmd_ack),
  .xplh_cmd_if_cmd            (xplh_control_cmd),
  .xplh_cmd_if_pending        (int_cmd_if_pending),
  .xplh_idle_gen_ack          (xplh_idle_gen_ack),
  .retrybuf_idle              (retrybuf_idle)
);

// Function : Insert DLP Bytes During Normal Phase
function automatic logic [P_DW - 1 : 0] ins_normal_dlp_bytes (
  input                           cxl_mode_enable,      // Link is negotiated in CXL mode
  input                           cxl_io_flit,          // Current flit is CXL.io - insert DLP2-DLP5 bytes at End of Flit cycle
  input                           sof,                  // Start of Flit to insert DLP0-DLP1 bytes in the Flit Header
  input [P_DW - 1 : 0]            data_in,              // Data path
  input [1 : 0]                   eof,                  // End of Flit
  input                           enf,                  // End of NOP Flit
  input fm_dllp_struct            dllp,                 // DLLP
  input                           retry_flit,           // Flit is part of flit replay sequence
  input                           expl_flit,            // Explicit sequence number flit
  input [1 : 0]                   expl_seq_cnt,         // Consecutive explicit seq count
  input [2 : 0]                   tx_nak_cnt,           // Nak Counter
  input [P_TX_SEQNUM_WD - 1 : 0]  next_tx_seqnum,       // Transmitter sequence number
  input [P_TX_SEQNUM_WD - 1 : 0]  nop_expl_seqnum,      // Transmitter Sequence Number for explicit NOP Flit
  input flit_usage_e              flit_usage,           // Flit Usage Flag  
  input dllp_pyld_type_e          dllp_pyld_type,       // DLLP Payload Type Flag
  input                           prior_payload,        // Prior was Payload Flag
  input                           flit_marker,          // Flit is carrying Flit Marker
  input replay_cmd_t              tx_ack_nak_type,      // Replay Command for Ack/Nak
  input [P_TX_SEQNUM_WD - 1 : 0]  tx_ack_nak_seqnum     // Sequence number for Ack/Nak
);
  ins_normal_dlp_bytes = data_in;
  if (cxl_mode_enable) begin
      // Insert DLP0-DLP1 bytes at the Start of Flit cycle of any CXL flit
      if (sof) begin
        // Insert the DLLP Payload Type bit
        ins_normal_dlp_bytes[4] = cxl_io_flit ? dllp_pyld_type : 1'b0;  // If not CXL.io then Reserved
        // Insert the prior Flit was Payload Flag
        ins_normal_dlp_bytes[5] = prior_payload;
        // Insert the Flit Usage bits
        ins_normal_dlp_bytes[7:6] = flit_usage;
        if((tx_nak_cnt > 0) && (tx_nak_cnt < 3)) begin
          ins_normal_dlp_bytes[ 3:2] = tx_ack_nak_type;
          ins_normal_dlp_bytes[ 1:0] = tx_ack_nak_seqnum[9:8];
          ins_normal_dlp_bytes[15:8] = tx_ack_nak_seqnum[7:0];
        // If Flit Replay Sequence is in progress insert explicit sequence number when consecutive Nak counter allows.
        end else if(((expl_flit || retry_flit) && (expl_seq_cnt < 3)) || ((expl_seq_cnt > 0) && (expl_seq_cnt < 3))) begin
          ins_normal_dlp_bytes[ 3:2] = REPLAY_00;
          ins_normal_dlp_bytes[ 1:0] = (flit_usage == IDLE_OR_NOP) ? nop_expl_seqnum[9:8] : next_tx_seqnum[9:8];
          ins_normal_dlp_bytes[15:8] = (flit_usage == IDLE_OR_NOP) ? nop_expl_seqnum[7:0] : next_tx_seqnum[7:0];
        end else begin
          ins_normal_dlp_bytes[ 3:2] = tx_ack_nak_type;
          ins_normal_dlp_bytes[ 1:0] = tx_ack_nak_seqnum[9:8];
          ins_normal_dlp_bytes[15:8] = tx_ack_nak_seqnum[7:0];
        end
      end
      // Insert DLLP Payload and Type (DLP2-DLP5) at CXL.io End of Flit Cycle
      // If the data path width is greater than 128-bit we can accomodate all of the DLLP Bytes in the last cycle of the Flit
      else if ((eof == 2'b11) && cxl_io_flit && !flit_marker) begin
        // Insert the DLLP
        ins_normal_dlp_bytes[(P_DW - (14*8) - 1) -: 32] = {dllp.pyld, dllp.dllp_type};
      end
  end
  else
  // If the data path width is greater than 128-bit we can accomodate all of the DLLP Bytes in the last cycle of the Flit
  if(eof == 2'b11) begin
    if(!flit_marker) begin
      ins_normal_dlp_bytes[(P_DW - (14*8) - 1) -: 32] = {dllp.pyld, dllp.dllp_type};
    end 
    // Insert the Dllp Payload Type bit
    ins_normal_dlp_bytes[P_DLP0_END - 3] = dllp_pyld_type;
    // Insert the prior Flit was Payload Flag
    ins_normal_dlp_bytes[P_DLP0_END - 2] = prior_payload;
    // Insert the Flit Usage bits
    ins_normal_dlp_bytes[P_DLP0_END : P_DLP0_END - 1] = flit_usage;
    if((tx_nak_cnt > 0) && (tx_nak_cnt < 3)) begin
      ins_normal_dlp_bytes[P_DLP0_END - 6 : P_DLP0_END - 7] = tx_ack_nak_seqnum[9:8];
      ins_normal_dlp_bytes[P_DLP1_END : P_DLP1_END - 7] = tx_ack_nak_seqnum[7:0];
      ins_normal_dlp_bytes[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1] = tx_ack_nak_type;
    end else if(((expl_flit || retry_flit) && (expl_seq_cnt < 3)) || ((expl_seq_cnt > 0) && (expl_seq_cnt < 3))) begin
      ins_normal_dlp_bytes[P_DLP0_END - 6 : P_DLP0_END - 7] = enf ? nop_expl_seqnum[9:8] : next_tx_seqnum[9:8];
      ins_normal_dlp_bytes[P_DLP1_END : P_DLP1_END - 7] = enf ? nop_expl_seqnum[7:0] : next_tx_seqnum[7:0];
      ins_normal_dlp_bytes[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1] = REPLAY_00;
    end else begin
      ins_normal_dlp_bytes[P_DLP0_END - 6 : P_DLP0_END - 7] = tx_ack_nak_seqnum[9:8];
      ins_normal_dlp_bytes[P_DLP1_END : P_DLP1_END - 7] = tx_ack_nak_seqnum[7:0];
      ins_normal_dlp_bytes[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1] = tx_ack_nak_type;
    end
  end
  return ins_normal_dlp_bytes;
endfunction

// Function : Insert DLP Bytes During Sequence Number Handshake Phase
function automatic logic [P_DW - 1 : 0] ins_seq_hs_dlp_bytes (
  input                           cxl_mode_enable,      // Link is negotiated in CXL mode
  input                           cxl_io_flit,          // Current flit is CXL.io - insert DLP2-DLP5 bytes at End of Flit cycle
  input                           sof,                  // Start of Flit to insert DLP0-DLP1 bytes in the Flit Header
  input [P_DW - 1 : 0]            data_in,              // Data path
  input [1 : 0]                   eof,                  // End of Flit
  input                           enf,                  // End of NOP Flit
  input fm_dllp_struct            dllp,                 // DLLP
  input flit_usage_e              flit_usage,           // Flit Usage Flag  
  input dllp_pyld_type_e          dllp_pyld_type,       // DLLP Payload Type Flag
  input                           flit_marker,          // Flit is carrying Flit Marker
  input                           prior_payload,        // Prior was Payload Flag
  input [P_TX_SEQNUM_WD - 1 : 0]  next_tx_seqnum,       // Transmitter sequence number
  input [P_TX_SEQNUM_WD - 1 : 0]  nop_expl_seqnum,      // Transmitter Sequence Number for explicit NOP Flit
  input replay_cmd_t              tx_ack_nak_type,      // Replay Command for Ack/Nak
  input [9 : 0]                   tx_ack_nak_seqnum,    // Sequence number for Ack/Nak
  input [1 : 0]                   cons_tx_expl_seqnum   // Consecutive Transmitted Explicit Sequence Number Flits
);
  // Copy the data in
  ins_seq_hs_dlp_bytes = data_in;
  if (cxl_mode_enable) begin
      // Insert DLP0-DLP1 bytes at the Start of Flit cycle of any CXL flit
      if (sof) begin
        // Insert the Dllp Payload Type bit
        ins_seq_hs_dlp_bytes[4] = cxl_io_flit ? dllp_pyld_type : 1'b0;
        // Insert the prior Flit was Payload Flag
        ins_seq_hs_dlp_bytes[5] = prior_payload;
        // Insert the Flit Usage bits
        ins_seq_hs_dlp_bytes[7:6] = flit_usage;
        // Replay Command 00 with tx sequence Number
        if(cons_tx_expl_seqnum < 3) begin
          ins_seq_hs_dlp_bytes[ 3:2] = REPLAY_00;
          ins_seq_hs_dlp_bytes[ 1:0] = (flit_usage == IDLE_OR_NOP) ? nop_expl_seqnum[9:8] : next_tx_seqnum[9:8];
          ins_seq_hs_dlp_bytes[15:8] = (flit_usage == IDLE_OR_NOP) ? nop_expl_seqnum[7:0] : next_tx_seqnum[7:0];
        // Insert the received sequence number for the Ack/Nak
        end else begin
          // No valid ack received
          if(tx_ack_nak_type == REPLAY_00) begin
            ins_seq_hs_dlp_bytes[ 3:2] = ACK;
          end else begin
            ins_seq_hs_dlp_bytes[ 3:2] = tx_ack_nak_type;
          end
          ins_seq_hs_dlp_bytes[ 1:0] = tx_ack_nak_seqnum[9:8];
          ins_seq_hs_dlp_bytes[15:8] = tx_ack_nak_seqnum[7:0];
        end
      end
      // Insert DLLP Payload and Type (DLP2-DLP5) at CXL.io End of Flit Cycle
      // If the data path width is greater than 128-bit we can accomodate all of the DLLP Bytes in the last cycle of the Flit
      else if ((eof == 2'b11) && cxl_io_flit && !flit_marker) begin
        // Insert the DLLP
        ins_seq_hs_dlp_bytes[(P_DW - (14*8) - 1) -: 32] = {dllp.pyld, dllp.dllp_type};
      end
  end
  else
  // If the data path width is greater than 128-bit we can accomodate all of the DLLP Bytes in the last cycle of the Flit
  if(eof == 2'b11) begin
    if(!flit_marker) begin
      // Insert the DLLP only if no Flit Marker is present
      ins_seq_hs_dlp_bytes[(P_DW - (14*8) - 1) -: 32] = {dllp.pyld, dllp.dllp_type};
    end
    // Insert the Dllp Payload Type bit
    ins_seq_hs_dlp_bytes[P_DLP0_END - 3] = dllp_pyld_type;
    // Insert the prior Flit was Payload Flag
    ins_seq_hs_dlp_bytes[P_DLP0_END - 2] = prior_payload;
    // Insert the Flit Usage bits
    ins_seq_hs_dlp_bytes[P_DLP0_END : P_DLP0_END - 1] = flit_usage;
    // Replay Command 00 with tx sequence Number
    if(cons_tx_expl_seqnum < 3) begin
      ins_seq_hs_dlp_bytes[P_DLP0_END - 6 : P_DLP0_END - 7] = enf ? nop_expl_seqnum[9:8] : next_tx_seqnum[9:8];
      ins_seq_hs_dlp_bytes[P_DLP1_END : P_DLP1_END - 7] = enf ? nop_expl_seqnum[7:0] : next_tx_seqnum[7:0];
      ins_seq_hs_dlp_bytes[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1] = REPLAY_00;
    // Insert the received sequence number for the Ack/Nak
    end else begin
      // No valid ack received
      if(tx_ack_nak_type == REPLAY_00) begin
        ins_seq_hs_dlp_bytes[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1] = ACK;
      end else begin
        ins_seq_hs_dlp_bytes[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1] = tx_ack_nak_type;
      end
      ins_seq_hs_dlp_bytes[P_DLP0_END - 6 : P_DLP0_END - 7] = tx_ack_nak_seqnum[9:8];
      ins_seq_hs_dlp_bytes[P_DLP1_END : P_DLP1_END - 7] = tx_ack_nak_seqnum[7:0];
    end
  end
  return ins_seq_hs_dlp_bytes;
endfunction


endmodule
