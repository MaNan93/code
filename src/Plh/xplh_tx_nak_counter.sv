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
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_tx_nak_counter.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Consecutive Transmitted NAK Flit Counter 
//
// Description: Counts the number of consecutive NAK Flit transmitted.
// Saturates at 3 cleared to 0 when non NAK Flit is transmitted.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_tx_nak_counter
  import cx_pl_pkg::P_DW;
  import cx_pl_pkg::ACK;
  import cx_pl_pkg::NAK_10;
  import cx_pl_pkg::NAK_11;
  import cx_pl_pkg::REPLAY_00;
  import cx_pl_pkg::replay_cmd_t;
  import cx_pl_pkg::P_REPLAY_CMD_END;
#(
  parameter   P_TX_NAK_CNT_WD = 3,
  parameter   TP              = `TP
) 
                            (
  // Inputs
  input                                   core_clk,
  input                                   core_rst_n,
  input                                   sof,                  // Start of Flit
  input                                   cxl_mode_enable,      // CXL mode enable
  input         replay_cmd_t              tx_replay_cmd,        // Replay Command
  input                                   enable_cnt,           // Enable counter at EOF[0] cycle for PCIe and SOF cycle for CXL
  input                                   halt_in,              // Halt from lower layer
  input                                   clear_cnt,            // Clear the counter
  // Outputs
  output  logic [P_TX_NAK_CNT_WD - 1 : 0] xplh_tx_nak_cnt,      // Consecutive NAK Counter
  output  logic                           xplh_tx_nak_cnt_incr  // Consecutive NAK Counter is going to increment from 0->1
);

replay_cmd_t                    int_tx_replay_cmd;

replay_cmd_t                    int_cxl_replay_cmd;   // register replay cmd at sof
replay_cmd_t                    int_cxl_replay_cmd_r; // registered replay cmd to be used at eof

// register replay_cmd at SOF and use to incr tx_nak_cnt at EOF
assign int_cxl_replay_cmd = sof ? tx_replay_cmd : int_cxl_replay_cmd_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_cxl_replay_cmd_r <= #TP REPLAY_00;
  end else begin
    // register tx_replay_cmd from flit header to be used at EOF
    int_cxl_replay_cmd_r <= #TP int_cxl_replay_cmd;
  end
end

assign int_tx_replay_cmd = cxl_mode_enable ? int_cxl_replay_cmd_r : tx_replay_cmd;

// NAK Flit Counter Increments when a Nak is transmitted
// Saturates at 3'b111
// Cleared when non Nak Flit is transmitted
always_ff @(posedge core_clk or negedge core_rst_n) begin : tx_nak_cnt_PROC
  if(!core_rst_n)
    xplh_tx_nak_cnt <= #TP {P_TX_NAK_CNT_WD{1'b0}};
  else begin
    if(clear_cnt)
      xplh_tx_nak_cnt <= #TP {P_TX_NAK_CNT_WD{1'b0}};
    // Non-Nak Flit transmitted reset the counter
    else if(enable_cnt && !halt_in && (int_tx_replay_cmd inside {ACK, REPLAY_00}))
      xplh_tx_nak_cnt <= #TP {P_TX_NAK_CNT_WD{1'b0}};
    // Hold the counter when it saturates
    else if(&xplh_tx_nak_cnt)
      xplh_tx_nak_cnt <= #TP xplh_tx_nak_cnt;
    // Increment when Nak Flit transmitted
    else if(enable_cnt && !halt_in)
      xplh_tx_nak_cnt <= #TP xplh_tx_nak_cnt + 1'b1;
    // Hold the value
    else
      xplh_tx_nak_cnt <= #TP xplh_tx_nak_cnt;
  end
end : tx_nak_cnt_PROC

// If the counter is going to change from 0->1 need to indicate to retry buffer module to hold off on starting the replay
// This is due to the consecutive explicit rule where a maximum of 3 consecutive explicit flits only is allowed
assign xplh_tx_nak_cnt_incr = (xplh_tx_nak_cnt == 0) && !clear_cnt && enable_cnt && (int_tx_replay_cmd inside {NAK_10, NAK_11});

endmodule
