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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_replay_num.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH REPLAY NUM
//
// Description: This module implements the FLIT_REPLAY_NUM Counter. 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_replay_num
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::CMD_FLUSH_XTLH;
  import  cx_pl_pkg::CMD_RESET;
#(
  parameter   TP        = `TP
) 
                        (
  input                   core_clk,
  input                   core_rst_n,
  input   tx_cmd_struct   xmlh_xplh_cmd,            // XMLH Commands
  input                   clr_rep_num,              // Received a valid Ack/Nak
  input                   replay_scheduled,         // Replay Scheduled Flag
  input   [2:0]           current_data_rate,        // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
  output  logic           xplh_replay_num_rcvry,    // Request transition to recovery due to replay num rollover
  output  logic           xplh_replay_num_rollover, // FLIT_REPLAY_NUM Rollover
  output  logic           xplh_replay_num_block     // block a replay in case replay rollover until transition through recovery completes
);

logic [2:0] int_replay_num_r;
logic       int_replay_scheduled_r;
logic       int_replay_scheduled_re;
logic       int_replay_num_rollover;
logic       int_block_replay_r;

// Replay Scheduled Rising Edge Detect
always_ff @(posedge core_clk or negedge core_rst_n) begin : replay_sched_re_PROC
  if(!core_rst_n)
    int_replay_scheduled_r  <= #TP '0;
  else
    int_replay_scheduled_r  <= #TP replay_scheduled;
end : replay_sched_re_PROC

assign int_replay_scheduled_re = replay_scheduled && !int_replay_scheduled_r;

// Replay Num Counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : replay_num_PROC
  if(!core_rst_n) begin
    int_replay_num_r          <= #TP '0;
    xplh_replay_num_rollover  <= #TP '0;
  end else begin
    xplh_replay_num_rollover  <= #TP int_replay_num_rollover;
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      int_replay_num_r      <= #TP '0;
    else if(clr_rep_num)
      int_replay_num_r      <= #TP '0;
    else if(int_replay_scheduled_re || xplh_replay_num_rollover)
      // Increment if replay scheduled or rollover occurs, rollover results in another replay after recovery
      int_replay_num_r      <= #TP int_replay_num_r + ((current_data_rate == 3'd5) ? 3'd1 : 3'd2);
    else
      int_replay_num_r      <= #TP int_replay_num_r;
  end
end : replay_num_PROC

// Block replay when replay rollover occured until recovery transition completed
always_ff @(posedge core_clk or negedge core_rst_n) begin : block_replay_PROC
  if(!core_rst_n)
    int_block_replay_r  <= #TP '0;
  else begin
    if(int_replay_num_rollover)
      int_block_replay_r  <= #TP 1'b1;
    else if(!xplh_replay_num_rcvry)
      int_block_replay_r  <= #TP 1'b0;
  end
end : block_replay_PROC

assign xplh_replay_num_block = int_block_replay_r || int_replay_num_rollover;


// Replay NUM Rollover
always_comb begin : replay_num_rollover_PROC
  int_replay_num_rollover = '0;
  if(current_data_rate == 3'd5)
    int_replay_num_rollover = int_replay_scheduled_re && (int_replay_num_r == 3'b111);
  else
    int_replay_num_rollover = int_replay_scheduled_re && (int_replay_num_r == 3'b110);
end : replay_num_rollover_PROC

// Replay Rollover Occurred Request Transition to Recovery
always_ff @(posedge core_clk or negedge core_rst_n) begin : req_rcvry_PROC
  if(!core_rst_n)
    xplh_replay_num_rcvry   <= #TP '0;
  else begin
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      xplh_replay_num_rcvry <= #TP '0;
    else if(xplh_replay_num_rcvry && (xmlh_xplh_cmd.tx_cmd == CMD_FLUSH_XTLH) && xmlh_xplh_cmd.req)
      xplh_replay_num_rcvry <= #TP '0;
    else if(int_replay_num_rollover)
      xplh_replay_num_rcvry <= #TP 1'b1;
  end
end : req_rcvry_PROC

endmodule
