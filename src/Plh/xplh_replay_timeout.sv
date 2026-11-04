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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_replay_timeout.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH_REPLAY_TIMEOUT_FLIT_COUNT
//
// Description: This module implements the replay timeout flit counter 
//
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Plh/xplh_pkg.svh"

module xplh_replay_timeout 
  import  xplh_pkg::P_REPLAY_TIMER_WD;
  import  xplh_pkg::P_REPLAY_TIMER_VAL;
#(
  parameter TP = `TP
) 
                            (
  input         core_clk,
  input         core_rst_n,
  input         eof,                    // End of Flit Marker
  input         halt_in,                // Halt
  input         clr_rep_timeout,        // Valid Ack/Nak received
  input         rbuf_empty,             // Retry Buffer Empty
  input         replay_scheduled,       // Replay Scheduled Flag
  input         replay_in_progress,     // Replay in Progress
  output  logic xplh_replay_timeout_err // Replay timer expired
);

logic [P_REPLAY_TIMER_WD - 1 : 0] int_replay_timeout;

// Replay Timeout
always_ff @(posedge core_clk or negedge core_rst_n) begin : replay_timeout_PROC
  if(!core_rst_n)
    int_replay_timeout  <= #TP '0;
  else begin
    if(replay_scheduled && xplh_replay_timeout_err)
      int_replay_timeout  <= #TP '0;
    else if(clr_rep_timeout)
      int_replay_timeout  <= #TP '0;
    else if(int_replay_timeout == P_REPLAY_TIMER_VAL)
      int_replay_timeout  <= #TP int_replay_timeout;
    else if(!rbuf_empty && eof && !halt_in)
      int_replay_timeout  <= #TP int_replay_timeout + 1'b1;
    else
      int_replay_timeout  <= #TP int_replay_timeout;
  end
end : replay_timeout_PROC

// Replay Timeout Expired Flag
always_ff @(posedge core_clk or negedge core_rst_n) begin : replay_timeout_err_PROC
  if(!core_rst_n)
    xplh_replay_timeout_err <= #TP '0;
  else begin
    if(replay_scheduled && xplh_replay_timeout_err)
      xplh_replay_timeout_err <= #TP '0;
    else if(!(replay_scheduled || replay_in_progress) && (int_replay_timeout == P_REPLAY_TIMER_VAL))
      xplh_replay_timeout_err <= #TP '1;
    else
      xplh_replay_timeout_err <= #TP xplh_replay_timeout_err;
  end
end : replay_timeout_err_PROC

endmodule
