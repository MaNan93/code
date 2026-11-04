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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_cmd_if.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH CMD IF
//
// Description: This module implements the XPLH Command Interface Acknowledge Generation.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_cmd_if
  import  cx_pl_pkg::tx_cmd_e;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::CMD_IDLE;
  import  cx_pl_pkg::CMD_PYLD;
  import  cx_pl_pkg::CMD_NOP;
  import  cx_pl_pkg::CMD_RESET;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::CMD_ABANDON_LP;
  import  xplh_pkg::xplh_state_e;
  import  xplh_pkg::FLIT_SEQ_NUM_HS;
  import  xplh_pkg::NORMAL;
  import  xplh_pkg::FLUSH;
  import  xplh_pkg::RESET;
#(
  parameter TP  = `TP
) (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                 core_clk,
  input                 core_rst_n,
  // -------------------------------------------------------------------------------------
  // XMLH Interface 
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct xmlh_xplh_cmd,            // Command from XLMH
  input   xplh_state_e  xplh_control_state,       // Control State
  // -------------------------------------------------------------------------------------
  // XDLH Interface 
  // -------------------------------------------------------------------------------------
  input                 xdlh_xplh_cmd_ack,        // Command Complete Acknowledge from XDLH
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  input                 xplh_pipe_cmd_ack,        // Acknowledge after pipeline
  input   [1 : 0]       xdlh_xplh_eof,            // EOF from XDLH
  output  logic         xplh_cmd_if_xmlh_cmd_ack, // Acknowledge to XMLH
  output  logic         xplh_cmd_if_ack,          // Command Acknowledge
  output  tx_cmd_struct xplh_cmd_if_cmd,          // Command Request
  output  logic         xplh_cmd_if_pending,      // Command request pending
  input                 xplh_idle_gen_ack,        // IDLE Generator Acknowledge
  input                 retrybuf_idle             // Retry Buffer FSM is IDLE
);

typedef enum {
  IDLE,               // IDLE State
  WAIT_EOF,           // Acknowledge received wait for end of next Flit 
  WAIT_PIPE,          // Send Ack to pipeline and wait until it passes through the pipeline 
  WAIT_PIPE_DONE,     // Wait for the Acknowledge to be de-asserted
  WAIT_CMD_NOT_IDLE,  // WAIT for IDLE command to be removed
  SEND_CMD_NOP,       // Send NOP command to XDLH
  SEND_CMD_PYLD,      // Send PYLD command to XDLH
  SEND_CMD_FLUSH,     // Send Flush command to XDLH
  SEND_FLUSH_ACK,     // Acknowledge the flush command to XMLH
  SEND_CMD_ACK,       // Send the acknowledge to XMLH
  WAIT_IDLE_HS_ACK    // Wait idle handshake started 
} state_e;

state_e next_state, state_r, prev_state_r;
tx_cmd_struct int_cmd_if_cmd;
xplh_state_e  int_prev_state_r;
logic         int_seq_hs_state;
logic         int_flush_state;
logic         int_pyld_ackd_r;
logic         int_xtlh_state_is_nop_r;
logic         int_pipe_cmd_ack_r;
logic         int_pipe_cmd_ack_fe;
logic         int_cmd_ack_done_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    xplh_cmd_if_cmd     <= #TP '0;
    int_prev_state_r    <= #TP RESET;
    int_pyld_ackd_r     <= #TP 1'b0;
    int_pipe_cmd_ack_r  <= #TP 1'b0;
  end else begin
    int_pipe_cmd_ack_r  <= #TP xplh_pipe_cmd_ack;
    xplh_cmd_if_cmd     <= #TP int_cmd_if_cmd;
    int_prev_state_r    <= #TP xplh_control_state;
    if((int_flush_state) || (xmlh_xplh_cmd.tx_cmd == CMD_RESET))
      int_pyld_ackd_r   <= #TP 1'b0;
    else if((xplh_cmd_if_cmd.tx_cmd == CMD_PYLD) && xplh_cmd_if_cmd.req && xdlh_xplh_cmd_ack)
      int_pyld_ackd_r   <= #TP 1'b1;
    else
      int_pyld_ackd_r   <= #TP int_pyld_ackd_r;
  end
end

assign int_pipe_cmd_ack_fe = !xplh_pipe_cmd_ack && int_pipe_cmd_ack_r;

// Pipe Command Acknowledge
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_cmd_ack_done_r    <= #TP 1'b0;
  else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      int_cmd_ack_done_r  <= #TP 1'b0;
    else if(state_r == SEND_FLUSH_ACK)
      int_cmd_ack_done_r  <= #TP 1'b0;
    else if(int_pipe_cmd_ack_fe)
      int_cmd_ack_done_r  <= #TP 1'b1;
  end
end

// Track if the XTLH is in the NOP state
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_xtlh_state_is_nop_r  <= #TP 1'b0;
  end else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      int_xtlh_state_is_nop_r  <= #TP 1'b0;
    else if(xplh_cmd_if_cmd.req && xdlh_xplh_cmd_ack && xplh_cmd_if_cmd.tx_cmd == CMD_NOP)
      int_xtlh_state_is_nop_r  <= #TP 1'b1;
    else if(xplh_cmd_if_cmd.req && xdlh_xplh_cmd_ack && xplh_cmd_if_cmd.tx_cmd != CMD_NOP)
      int_xtlh_state_is_nop_r  <= #TP 1'b0;
    else
      int_xtlh_state_is_nop_r  <= #TP int_xtlh_state_is_nop_r;
  end
end

// Detect transition to different state
assign int_seq_hs_state = (int_prev_state_r != FLIT_SEQ_NUM_HS) && (xplh_control_state == FLIT_SEQ_NUM_HS);
assign int_flush_state = (int_prev_state_r != FLUSH) && (xplh_control_state == FLUSH);

// Command Interface FSM
always_comb begin : cmd_state_PROC 
  next_state = state_r;
  case (state_r)
    // Send NOP Command
    SEND_CMD_NOP : begin
      if(xdlh_xplh_cmd_ack)
        next_state = WAIT_CMD_NOT_IDLE;
    end
    // Send Payload Command
    SEND_CMD_PYLD : begin
      // State is Flush issue Flush command if we enter here from IDLE
      // otherwise flush will have already have been issued.
      if(xdlh_xplh_cmd_ack && (xplh_control_state == FLUSH) && (prev_state_r == IDLE))
        next_state = SEND_CMD_FLUSH;
      // Control State is Normal and Payload Command not previously acknowledged 
      else if(xdlh_xplh_cmd_ack && !int_pyld_ackd_r)
        next_state = SEND_CMD_ACK;
      // The XMLH has already received the ACK for the NOP command so dont need to propagate another ACK
      else if(xdlh_xplh_cmd_ack)
        next_state = WAIT_CMD_NOT_IDLE;
    end
    // Send Flush Command
    SEND_CMD_FLUSH : begin
      // Sent Flush Command and Ack received wait next EOF
      if(xdlh_xplh_cmd_ack)
        next_state = WAIT_EOF;
    end
    // Ack received wait for next EOF
    WAIT_EOF : begin
      if(xdlh_xplh_eof[1])
        next_state = WAIT_PIPE;
    end
    // EOF received send the Ack to XMLH and wait for it to pass through the pipeline
    WAIT_PIPE : begin
      if(xplh_pipe_cmd_ack)
        next_state = WAIT_PIPE_DONE;
    end
    // Wait until Ack is de-asserted at output of pipe
    WAIT_PIPE_DONE : begin
      if(int_cmd_ack_done_r && retrybuf_idle)
        next_state = SEND_FLUSH_ACK;
    end
    // Send the flush acknowledge
    SEND_FLUSH_ACK : begin
      next_state = WAIT_IDLE_HS_ACK;
    end
    // Wait for completion of IDLE handshake after recovery
    WAIT_IDLE_HS_ACK : begin
      // Low power entry abandoned
      if((xmlh_xplh_cmd.tx_cmd == CMD_ABANDON_LP) && xmlh_xplh_cmd.req)
        next_state = SEND_CMD_ACK;
      // Payload command previously send payload command to fill pipeline with TLP's
      else if(xplh_idle_gen_ack && int_pyld_ackd_r)
        next_state = SEND_CMD_PYLD;
      // Send NOP command to fill pipeline with NOPs (sequence handshake did not previously complete)
      else if(xplh_idle_gen_ack)
        next_state = SEND_CMD_NOP;
      // Transition to recovery occured during low power entry
      else if((xmlh_xplh_cmd.tx_cmd == CMD_FLUSH_XTLH) && xmlh_xplh_cmd.req)
        next_state = SEND_CMD_FLUSH;
      else
        next_state = WAIT_IDLE_HS_ACK;
    end
    // In sequence number handshake the command has already been sent and acknowledged during the IDLE handshake.
    // Wait until the XMLH requests a command other that IDLE and send an Acknowledge
    WAIT_CMD_NOT_IDLE : begin
      // Already acknowledged NOP command just send ack to XMLH
      if(xmlh_xplh_cmd.req && (xmlh_xplh_cmd.tx_cmd == CMD_NOP) && int_xtlh_state_is_nop_r)
        next_state = SEND_CMD_ACK;
      else if(xmlh_xplh_cmd.req && (xmlh_xplh_cmd.tx_cmd != CMD_IDLE))
        next_state = IDLE;
      else
        next_state = WAIT_CMD_NOT_IDLE;
    end
    // Send the acknowledge directly to XMLH now that the pipeline is fully flushed
    SEND_CMD_ACK : begin
      next_state = IDLE;
    end
    default : begin // IDLE 
      // In Sequence Number Handshake for the first time
      // Do not re-send NOP CMD to XTLH is it is already in the NOP state
      if(int_seq_hs_state && (xmlh_xplh_cmd.tx_cmd != CMD_PYLD) && !int_xtlh_state_is_nop_r)
        next_state = SEND_CMD_NOP;
      // Payload command received and not yet acknowledged
      else if(!int_pyld_ackd_r && (xmlh_xplh_cmd.tx_cmd == CMD_PYLD))
        next_state = SEND_CMD_PYLD;
      // Flushing
      else if(int_flush_state)
        next_state = SEND_CMD_FLUSH;
      else
        next_state = IDLE;
    end
  endcase
end : cmd_state_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : cmd_sync_PROC
  if(!core_rst_n) begin
    state_r           <= #TP IDLE;
    prev_state_r      <= #TP IDLE;
  end else begin
    // Reset if the link goes down
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET) begin
      state_r         <= #TP IDLE;
    end else begin
      state_r         <= #TP next_state;
    end
    if(state_r != next_state) begin
      prev_state_r    <= #TP state_r;
    end else begin
      prev_state_r    <= #TP prev_state_r;
    end
  end
end : cmd_sync_PROC

assign xplh_cmd_if_ack = (state_r == WAIT_PIPE);
assign xplh_cmd_if_xmlh_cmd_ack = (state_r inside {SEND_CMD_ACK, SEND_FLUSH_ACK});
assign xplh_cmd_if_pending = (state_r != IDLE);

// Drive the Command to the XDLH
always_comb begin : cmd_PROC
  int_cmd_if_cmd.flit_mode = xmlh_xplh_cmd.flit_mode;
  int_cmd_if_cmd.tx_cmd = xplh_cmd_if_cmd.tx_cmd;
  int_cmd_if_cmd.req = xplh_cmd_if_cmd.req;
  unique case (state_r)
    SEND_CMD_NOP : begin
      int_cmd_if_cmd.req = 1'b1;
      int_cmd_if_cmd.tx_cmd = CMD_NOP;
    end
    SEND_CMD_PYLD : begin
      int_cmd_if_cmd.req = 1'b1;
      int_cmd_if_cmd.tx_cmd = CMD_PYLD;
    end
    SEND_CMD_FLUSH : begin
      int_cmd_if_cmd.req = 1'b1;
      int_cmd_if_cmd.tx_cmd = xmlh_xplh_cmd.tx_cmd;
    end
    default : begin
      int_cmd_if_cmd.flit_mode = xmlh_xplh_cmd.flit_mode;
      int_cmd_if_cmd.req = 1'b0;
      // Propogate the reset command in cases where the link goes down without resetting flit mode
      int_cmd_if_cmd.tx_cmd = (xmlh_xplh_cmd.tx_cmd == CMD_RESET) ? xmlh_xplh_cmd.tx_cmd : xplh_cmd_if_cmd.tx_cmd;
    end
  endcase
end : cmd_PROC

endmodule
