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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_pipe_flush.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Pipe Flush
// Description: This module is responsible for Flushing the XPLH pipeline in preparation
// for a transition to the Flit Sequence Number Handshake Phase. The transmit pipeline
// will be unhalted until the current Flit is flushed. The next flit will be an explicit
// sequence number flit which is required to be the first flit transmitted durign Flit Sequence Number
// Handshake. A signal is sent back to the transmit sequence number to decrement to account for the
// Flit that was flushed.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_pipe_flush
  import cx_pl_pkg::CMD_RESET;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
  import cx_pl_pkg::CMD_FLUSH_XAIM;
  import cx_pl_pkg::CMD_IDLE;
  import cx_pl_pkg::tx_cmd_struct;
#(
  parameter TP = `TP
) (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                         core_clk,               // Core clock
  input                         core_rst_n,             // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // Flit Interface 
  // -------------------------------------------------------------------------------------
  input                         next_sof,               // SOF from previous stage
  // -------------------------------------------------------------------------------------
  //  Command Interface
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct         xmlh_xplh_cmd,          // Command from XMLH
  input                         idle_in_progress,       // IDLE Flits being transmitted
  // -------------------------------------------------------------------------------------
  // Output Interface
  // -------------------------------------------------------------------------------------
  output  logic                 xplh_pipe_flush_unhalt  // Set to 1 to unhalt the pipeline
);

typedef enum {
  RESET,      // Reset State
  WAIT_IDLE,  // Flush Command Received wait for IDLE Flits
  FLUSH_PIPE, // IDLE Flits being transmitted Flush the pipeline  
  WAIT_DONE   // Wait for the flush to complete
} state_e;

state_e next_state, state_r;
logic int_next_sof;

assign int_next_sof = next_sof;

always_comb begin : next_state_PROC
  next_state = state_r;
  case (state_r)
    // In IDLE state wait until IDLE Flit transmission starts
    WAIT_IDLE : begin
      if(idle_in_progress && (xmlh_xplh_cmd.tx_cmd == CMD_IDLE))
        next_state = FLUSH_PIPE;
    end
    // Flush the pipeline until the flit with replay 00 reaches the head of the pipeline
    FLUSH_PIPE : begin
      if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
        next_state = RESET;
      else if(int_next_sof)
        next_state = WAIT_DONE;
    end
    // Wait for the flush to complete
    WAIT_DONE : begin
      if(!idle_in_progress)
        next_state = RESET;
    end
    default : begin // RESET
      if((xmlh_xplh_cmd.tx_cmd inside {CMD_FLUSH_XTLH, CMD_FLUSH_XAIM}) && xmlh_xplh_cmd.req)
        next_state = WAIT_IDLE;
    end
  endcase
end : next_state_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    state_r <= #TP RESET;
  else
    state_r <= #TP next_state;
end

assign xplh_pipe_flush_unhalt = (state_r == FLUSH_PIPE);

endmodule
