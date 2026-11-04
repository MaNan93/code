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

// -------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2021/10/29 02:04:56 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_base_timer.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// --- This module implements a synchronous counter with enable, hold and clear inputs. 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_cxl_base_timer
  // Parameters
  #(
  parameter TP = `TP,
  parameter TIMER_WIDTH = 1,
  parameter RST_VALUE = {(TIMER_WIDTH){1'b0}}
  )
  
                            (
  // Inputs
  input                               clk,
  input                               rst_n,
  input                               clear_timer,
  input                               hold_timer,
  input                               enable,
  input [(TIMER_WIDTH - 1) : 0]       timer_target,
  input [(TIMER_WIDTH - 1) : 0]       incr,

  // Outputs
  output  reg                         timeout_r,
  output  wire                        timeout,
  output  reg [(TIMER_WIDTH - 1) : 0] timer_r
);

// -------------------------------------------------------------------------
// Timer Implementation
// -------------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin : timer_PROC
  if(!rst_n)
  begin
    timeout_r <= #TP 1'b0;
    timer_r   <= #TP RST_VALUE; 
  end
  else
  begin
    timeout_r <= #TP timeout;
    // Hold
    if(hold_timer)
      timer_r <= #TP timer_r;
    // Clear
    else if(clear_timer || timeout)
      timer_r <= #TP RST_VALUE;
    // Count
    else if(enable)
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: By design the timer will be reset before it can overflow.
      // spyglass disable_block W164b
      // SMD: Identifies assignments in which the LHS width is greater than the RHS width
      // SJ: By design the counter is reset before it can reach its maximum value 
      // Therefore the width of the LHS will never exceed the timers width.
      timer_r <= #TP (timer_r + incr);
      // spyglass enable_block W164b
      // spyglass enable_block W164a
  end
end : timer_PROC

assign timeout = enable && (timer_r >= timer_target);


endmodule
