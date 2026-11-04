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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_tx_throttle.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH TX Throttle When Selective Replay is being sent track the number of Payload Flits
// stored in the Remote RX Retry Buffer. After the selective replay completes insert
// NOP Flits to allow the Remote to drain the RX Retry Buffer.
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Plh/xplh_pkg.svh"
`include "products/cx_pl_pkg.svh"

module xplh_tx_throttle
  import  xplh_pkg::P_TX_SEQNUM_WD;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::P_FLIT_DW_CNT;
  import  cx_pl_pkg::P_FLIT_DW_CNT_WD;

#(
  parameter TP = `TP
) 
                         (
  input                             core_clk,
  input                             core_rst_n,
  input                             cfg_tx_throttling,      // Enable TX Throttling
  input   tx_flit_struct            flit_in,                // Input Flit
  input                             halt_in,                // Downstream Halt
  output  tx_flit_struct            xplh_tx_throttle_flit,  // Output Flit
  output  logic                     xplh_tx_throttle_halt,  // Output Halt
  input   replay_cmd_t              rcvd_replay_cmd,        // Received Replay Command
  input   [P_TX_SEQNUM_WD - 1 : 0]  rcvd_seqnum,            // Received Sequence Number
  input   [P_TX_SEQNUM_WD - 1 : 0]  tx_seqnum,              // Received Sequence Number
  input                             rcvd_valid,             // ACK/NAK received
  input                             tx_sel_replay,          // Selective replay has been transmitted 
  input                             replay_in_progress      // Replay is in progress
);

// The actual number of NOP Flits to be sent is reduced by 3 to account for next_tx_seqnum - 1, nak seqnum + 1 and 1 additional NOP that could be sent by retry buffer
localparam [P_TX_SEQNUM_WD - 1 : 0] P_NOP_FLIT_SENT = 'd3;

typedef enum {
  IDLE,
  ACTIVE,
  SEND_NOP
} state_e;

logic [P_TX_SEQNUM_WD - 1 : 0]  int_init_pyld_cnt;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_init_pyld_cnt_r;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_next_nop_flit_cnt;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_calc_nop_flit_cnt;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_nop_flit_cnt_r;
logic                           int_en_nop_gen;
logic                           int_tx_sel_replay_r;
logic                           int_tx_sel_replay_re;
logic [P_FLIT_DW_CNT_WD -1 : 0] int_nop_dw_cnt_r;
logic                           int_std_nak_rcvd;

state_e                         next_state;
state_e                         state_r;

// Selective followed by standard nak for the same sequence number
assign int_std_nak_rcvd = ((state_r == ACTIVE) && rcvd_valid && (rcvd_replay_cmd == NAK_10) && (rcvd_seqnum == int_init_pyld_cnt_r));

always_ff @(posedge core_clk or negedge core_rst_n) begin : sel_replay_PROC
  if(!core_rst_n)
    int_tx_sel_replay_r <= #TP '0;
  else
    int_tx_sel_replay_r <= #TP tx_sel_replay;
end : sel_replay_PROC

assign int_tx_sel_replay_re = tx_sel_replay && !int_tx_sel_replay_r;

// TX Throttling FSM
always_comb begin : throttle_fsm_PROC
  next_state = state_r;
  case(state_r)
    // Wait for an Ack/Nak to be received after the selective replay before sending NOP's
    ACTIVE : begin
      // received standard nak for same sequence number
      if(int_std_nak_rcvd || (tx_sel_replay && (int_calc_nop_flit_cnt <= P_NOP_FLIT_SENT)))
        next_state = IDLE;
      else if(tx_sel_replay && !(int_calc_nop_flit_cnt == '0))
        next_state = SEND_NOP;
      else
        next_state = ACTIVE;
    end
    // Send NOP's until either NOP counter reaches zero or TX Retry Buffer is empty (all Flits have been acknowledged)
    SEND_NOP : begin
      if((int_nop_flit_cnt_r == 1) && !halt_in && xplh_tx_throttle_flit.eof[1])
        next_state = IDLE;
    end
    default : begin
      // Received selective replay request and no replay in progress
      if(cfg_tx_throttling && rcvd_valid && (rcvd_replay_cmd == NAK_11) && !replay_in_progress)
        next_state = ACTIVE;
    end
  endcase
end : throttle_fsm_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : fsm_reg_PROC
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else
    state_r <= #TP next_state;
end : fsm_reg_PROC

always_comb begin : fsm_out_PROC
  int_init_pyld_cnt = int_init_pyld_cnt_r;
  int_calc_nop_flit_cnt = '0;
  xplh_tx_throttle_halt = halt_in;
  xplh_tx_throttle_flit = flit_in;
  int_en_nop_gen = '0;
  case(state_r)
    ACTIVE : begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: The numbers are checked before the subtraction so there cannot be any underflow here.
      if(int_tx_sel_replay_re) begin
        // TX seqnum rolled over
        if(tx_seqnum < int_init_pyld_cnt_r)
          int_calc_nop_flit_cnt = tx_seqnum + ({P_TX_SEQNUM_WD{1'b1}} - int_init_pyld_cnt_r);
        else
          int_calc_nop_flit_cnt = (tx_seqnum - int_init_pyld_cnt_r);
      // spyglass enable_block W164a
      end else begin
          int_calc_nop_flit_cnt = int_nop_flit_cnt_r;
      end
    end
    SEND_NOP : begin
      xplh_tx_throttle_flit = '0;
      xplh_tx_throttle_halt = '1;
      int_en_nop_gen = '1;
      xplh_tx_throttle_flit.sof = (int_nop_dw_cnt_r == '0);
      xplh_tx_throttle_flit.data_valid = 1'b1;
      // Generate the EOF marker
      xplh_tx_throttle_flit.eof = (int_nop_dw_cnt_r == P_FLIT_DW_CNT - 1) ? 2'b11 : 2'b00;
      xplh_tx_throttle_flit.enf = |xplh_tx_throttle_flit.eof;
    end
    default : begin // IDLE
      int_calc_nop_flit_cnt = '0;
      int_en_nop_gen = '0;
      int_init_pyld_cnt = rcvd_seqnum;
      xplh_tx_throttle_halt = halt_in;
      xplh_tx_throttle_flit = flit_in;
    end
  endcase
end : fsm_out_PROC

always_comb begin : next_nop_cnt_PROC
  if(state_r == SEND_NOP)
    int_next_nop_flit_cnt =  ((int_nop_dw_cnt_r == P_FLIT_DW_CNT - 1) && !halt_in) ? int_nop_flit_cnt_r - 1 : int_nop_flit_cnt_r;
  else if(next_state == SEND_NOP)
    int_next_nop_flit_cnt = int_calc_nop_flit_cnt - P_NOP_FLIT_SENT;
  else
    int_next_nop_flit_cnt = '0;
end : next_nop_cnt_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : fsm_out_sync_PROC
  if(!core_rst_n) begin
    int_nop_flit_cnt_r  <= #TP '0;
    int_init_pyld_cnt_r <= #TP '0;
  end else begin
    int_nop_flit_cnt_r  <= #TP int_next_nop_flit_cnt;
    int_init_pyld_cnt_r <= #TP int_init_pyld_cnt;
  end
end : fsm_out_sync_PROC

// NOP Flit Generator
always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_cnt_PROC
  if(!core_rst_n) begin
    int_nop_dw_cnt_r        <= #TP 'h0;
  end else begin
    if(!halt_in) begin
      if(int_nop_dw_cnt_r == P_FLIT_DW_CNT - 1)
        int_nop_dw_cnt_r  <= #TP 'h0;
      else if(int_en_nop_gen)
        int_nop_dw_cnt_r  <= #TP int_nop_dw_cnt_r + 1'b1;
      else
        int_nop_dw_cnt_r  <= #TP int_nop_dw_cnt_r;
    end
  end
end : nop_cnt_PROC

endmodule
