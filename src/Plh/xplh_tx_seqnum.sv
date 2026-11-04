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
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_tx_seqnum.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH TX Seqnum 
//
// Description: Implements the transmitter sequence number. 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_tx_seqnum 
  import cx_pl_pkg::P_TX_SEQNUM_WD;
  import cx_pl_pkg::P_MAX_SEQNUM;
  import cx_pl_pkg::NAK_10;
  import cx_pl_pkg::NAK_11;
  import xplh_pkg::seqnum_plus_1;
#(
  parameter TP = `TP
) 
                       (
  input                               core_clk,
  input                               core_rst_n,
  input   [1 : 0]                     eof,                // End of Flit Marker
  input                               enf,                // End of NOP Flit
  input                               clear,              // Synchronous clear
  input                               sent_nak_11,        // Sent selective replay
  input                               cxl_mode_enable,
  input                               sof,                // Start of Flit Marker
  input                               retry_flit,         // Flit is from retry buffer
  input                               halt_in,            // Downstream Halt
  input   [P_TX_SEQNUM_WD-1:0]        tx_replay_seqnum,   // Transmitter Sequence Number
  output  logic [P_TX_SEQNUM_WD-1:0]  tx_seqnum,          // Transmitter Sequence Number
  output  logic [P_TX_SEQNUM_WD-1:0]  tx_seqnum_sof,      // Transmitter Sequence Number at SOF
  output  logic [P_TX_SEQNUM_WD-1:0]  nop_expl_seqnum,    // Transmitter Sequence Number
  output  logic [P_TX_SEQNUM_WD-1:0]  next_tx_flit_seqnum // Transmitter Sequence Number
);

localparam [P_TX_SEQNUM_WD - 1 : 0] P_RST_VALUE = {{(P_TX_SEQNUM_WD - 1){1'b0}}, 1'b1};

logic int_wrap_seqnum;
logic [P_TX_SEQNUM_WD-1:0]  int_tx_seqnum_r;
logic int_prev_not_retry_r;
logic int_sel_replay_seqnum;
logic int_sel_replay_seqnum_sof;
logic int_wrap_next_seqnum;

assign int_wrap_seqnum = (int_tx_seqnum_r == P_MAX_SEQNUM);
assign int_wrap_next_seqnum = (next_tx_flit_seqnum == P_MAX_SEQNUM);

// Transmitter Sequence Number
// Reset to 1
// Increment on end of Flit
// Wrap around at 1023
// For standard replay set the sequence number to the tx replay sequence number and increment
// For selective replay the tx replay seqnum is used for the selective Nak only
always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_seqnum_PROC
  if(!core_rst_n)
    int_tx_seqnum_r <= #TP P_RST_VALUE;
  else begin
    if(clear) begin
      int_tx_seqnum_r <= #TP P_RST_VALUE;
    // Update the sequence number when EOF is received and it is not a NOP Flit
    end else if(!halt_in && eof[1] && !enf) begin
      // Selective replay
      if(sent_nak_11)
          int_tx_seqnum_r <= #TP next_tx_flit_seqnum;
      // Standard Replay
      else if(retry_flit && int_prev_not_retry_r)
          int_tx_seqnum_r <= #TP seqnum_plus_1(tx_replay_seqnum);
      else begin
        if(int_wrap_seqnum)
          int_tx_seqnum_r <= #TP P_RST_VALUE;
        else
          int_tx_seqnum_r <= #TP int_tx_seqnum_r + 1'b1;
      end
    end else begin
      int_tx_seqnum_r <= #TP int_tx_seqnum_r;
    end
  end
end : tx_seqnum_PROC

// NEXT_TX_FLIT_SEQNUM
// Do not increment on NOP, IDLE or Replayed Flit
always_ff @(posedge core_clk or negedge core_rst_n) begin : next_tx_seqnum_PROC
  if(!core_rst_n)
    next_tx_flit_seqnum <= #TP P_RST_VALUE;
  else begin
    if(clear) begin
      next_tx_flit_seqnum <= #TP P_RST_VALUE;
    // Update the sequence number when EOF is received and it is not a NOP/IDLE/REPLAY
    end else if(!halt_in && eof[1] && !enf && !retry_flit) begin
      if(int_wrap_next_seqnum)
        next_tx_flit_seqnum <= #TP P_RST_VALUE;
      else
        next_tx_flit_seqnum <= #TP next_tx_flit_seqnum + 1'b1;
    end else begin
      next_tx_flit_seqnum <= #TP next_tx_flit_seqnum;
    end
  end
end : next_tx_seqnum_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_prev_not_retry_r <= #TP '0;
  else begin
    if(clear) begin
      int_prev_not_retry_r    <= #TP '0;
    end else if(!halt_in) begin
      if(eof[1] && !retry_flit)
        int_prev_not_retry_r  <= #TP '1;
      else if(eof[1] && retry_flit && !enf)
        int_prev_not_retry_r  <= #TP '0;
    end
  end
end

// In CXL mode, select TX Replay Sequence Number at SOF cycle as DLP0-DLP1 bytes are in the first two bytes of 256B Flit
assign int_sel_replay_seqnum = int_prev_not_retry_r && ( cxl_mode_enable? sof :  |eof) && retry_flit;

// Explicit NOP Flit Sequence Number
always_comb begin : nop_expl_seqnum_PROC
  if(int_tx_seqnum_r == P_RST_VALUE)
    nop_expl_seqnum = '1;
  else
    nop_expl_seqnum = int_tx_seqnum_r - 1'b1;
end : nop_expl_seqnum_PROC

// The first Flit which is from the retry buffer should use the TX REPLAY SEQNUM
always_comb begin : tx_seqnum_mux_PROC
  if(int_sel_replay_seqnum)
    tx_seqnum = tx_replay_seqnum;
  else
    tx_seqnum = int_tx_seqnum_r;
end : tx_seqnum_mux_PROC

// In GEN6 mode, when Error Injection feature is enabled, TX Sequence Number must be ready early before the EOF
assign int_sel_replay_seqnum_sof = int_prev_not_retry_r && ( cxl_mode_enable? sof :  1'b1) && retry_flit;

always_comb begin : tx_seqnum_mux_sof_PROC
  if(int_sel_replay_seqnum_sof)
    tx_seqnum_sof = tx_replay_seqnum;
  else
    tx_seqnum_sof = int_tx_seqnum_r;
end : tx_seqnum_mux_sof_PROC

endmodule
