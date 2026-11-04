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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_payload_tracker.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Payload Tracker 
//
// Description: This module tracks the number of payload flits in the retry buffer.
//  Increment when Payload flit is written.
//  Decrement by the number of Acknowledged Flits.
//  Implements overflow protection for the retry buffer.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_payload_tracker
  import  xplh_pkg::P_TX_SEQNUM_WD;
  import  xplh_pkg::P_MAX_SEQNUM;
  import  xplh_pkg::P_RBUF_FLIT_LIMIT;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::CMD_RESET;
#(
  parameter   TP        = `TP
) 
                             (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                               core_clk,                       // Core clock
  input                               core_rst_n,                     // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // Ackd Flits 
  // -------------------------------------------------------------------------------------
  input   [P_TX_SEQNUM_WD-1:0]        ackd_flits,                     // Number of Flit acknowledged by the latest Ack/Nak 
  // -------------------------------------------------------------------------------------
  // Flit Interface
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct               xmlh_xplh_cmd,                  // Commands from XMLH
  input                               eof,                            // End of Flit
  input                               enf,                            // End of NOP Flit
  input                               halt_in,                        // Halt in
  // -------------------------------------------------------------------------------------
  // Payload Tracker Outputs
  // -------------------------------------------------------------------------------------
  output  logic [P_TX_SEQNUM_WD-1:0]  xplh_payload_tracker_flit_cnt,  // Number of payload flits transmitted since the last ACK/NAK
  output  logic                       xplh_payload_tracker_af         // Retry buffer is almost full stop sending payload Flits
);

localparam RBUF_FLIT_ADJUST = 1 + 1;

// Count Payload Flits
always_ff @(posedge core_clk or negedge core_rst_n) begin : pyld_cnt_PROC
  if(!core_rst_n)
    xplh_payload_tracker_flit_cnt   <= #TP '0;
  else begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. The number of flits being acknowledged should never exceed the current payload count. So, disable SpyGlass from reporting this warning.
    if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
      xplh_payload_tracker_flit_cnt   <= #TP '0;
    else if(eof && !enf && !halt_in)
      xplh_payload_tracker_flit_cnt <= #TP xplh_payload_tracker_flit_cnt + 1'b1 - ackd_flits;
    else
      xplh_payload_tracker_flit_cnt <= #TP xplh_payload_tracker_flit_cnt - ackd_flits;
  end
// spyglass enable_block W164a
end : pyld_cnt_PROC

assign xplh_payload_tracker_af = (xplh_payload_tracker_flit_cnt >= (P_RBUF_FLIT_LIMIT - RBUF_FLIT_ADJUST));

endmodule
