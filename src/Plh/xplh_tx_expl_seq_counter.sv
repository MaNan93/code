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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_tx_expl_seq_counter.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Consecutive Transmitted Flits with Explicit Sequence Number 
//
// Description: Counts the number of consecutive Flits transmitted with Replay Command 0x0.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_tx_expl_seq_counter
  import  cx_pl_pkg::P_TX_SEQNUM_WD;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::ACK;
  import  cx_pl_pkg::NAK_10;
  import  cx_pl_pkg::NAK_11;
  import  cx_pl_pkg::REPLAY_00;
  import  cx_pl_pkg::replay_cmd_t;
  import  cx_pl_pkg::P_REPLAY_CMD_END;
  import  xplh_pkg::P_EXPL_CNT_WD;
#(
  parameter   TP              = `TP
) 
                                 (
  // Inputs
  input                                   core_clk,
  input                                   core_rst_n,
  input         [P_DW - 1 : 0]            data,             // Data
  input         [1 : 0]                   eof,              // End of Flit
  input                                   sof,              // Start of Flit
  input                                   cxl_mode_enable,  // CXL mode enable
  input                                   clear_cnt,        // Prevent update of the counter during flushing
  input                                   halt_in,          // Halt from lower layer
  input         [P_TX_SEQNUM_WD - 1 : 0]  tx_seqnum,        // transmitter sequence number
  // Outputs
  output  logic [P_EXPL_CNT_WD - 1 : 0]   xplh_tx_expl_seq_cnt  // Explicit Sequence Number consecutive counter 
);

replay_cmd_t                    int_tx_replay_cmd;
logic                           int_incr_event;
logic                           int_clear_event;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_tx_seqnum;

replay_cmd_t                    int_cxl_tx_replay_cmd;
replay_cmd_t                    int_cxl_tx_replay_cmd_r;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_cxl_tx_seqnum;
logic [P_TX_SEQNUM_WD - 1 : 0]  int_cxl_tx_seqnum_r;

// For CXL latch tx_seqnum and tx_replay_cmd at SOF when flit hdr is valid
assign int_cxl_tx_replay_cmd = sof ? replay_cmd_t'(data[3:2]) : int_cxl_tx_replay_cmd_r;
assign int_cxl_tx_seqnum     = sof ? tx_seqnum                : int_cxl_tx_seqnum_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_cxl_tx_replay_cmd_r <= #TP REPLAY_00;
    int_cxl_tx_seqnum_r     <= #TP '0;
  end else begin
    // store tx_replay_cmd and tx_seqnum from flit header to be used at EOF
    int_cxl_tx_replay_cmd_r <= #TP int_cxl_tx_replay_cmd;
    int_cxl_tx_seqnum_r     <= #TP int_cxl_tx_seqnum;
  end
end

assign int_clear_event = eof[1] && !halt_in && (int_tx_replay_cmd inside {ACK, NAK_10, NAK_11});
assign int_incr_event  = eof[1] && !halt_in && (int_tx_seqnum > 0);

// Extract the replay command from the data path
assign int_tx_replay_cmd = cxl_mode_enable ? int_cxl_tx_replay_cmd_r : replay_cmd_t'(data[P_REPLAY_CMD_END : P_REPLAY_CMD_END - 1]);
assign int_tx_seqnum     = cxl_mode_enable ? int_cxl_tx_seqnum_r     : tx_seqnum;

// Explicit Flit Counter Increments when a Flit with Replay 00 is transmitted
// Cleared when Ack/Nak is transmitted 
always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_expl_seq_cnt_PROC
  if(!core_rst_n)
    xplh_tx_expl_seq_cnt      <= #TP {P_EXPL_CNT_WD{1'b0}};
  else begin
    if(clear_cnt)
      xplh_tx_expl_seq_cnt    <= #TP {P_EXPL_CNT_WD{1'b0}};
    else if(eof[1] && !halt_in) begin
      // Ack or Nak Flit transmitted reset the counter
      if(int_clear_event)
        xplh_tx_expl_seq_cnt  <= #TP {P_EXPL_CNT_WD{1'b0}};
      // Explicit Flit transmitted increment the counter
      else if(int_incr_event)
        xplh_tx_expl_seq_cnt  <= #TP xplh_tx_expl_seq_cnt + 1'b1;
      else
        xplh_tx_expl_seq_cnt  <= #TP xplh_tx_expl_seq_cnt;
    // Hold the value
    end else
      xplh_tx_expl_seq_cnt    <= #TP xplh_tx_expl_seq_cnt;
  end
end : tx_expl_seq_cnt_PROC

endmodule
