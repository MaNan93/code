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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/common/pending_tracker.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// Pending tracker.
// This module is general pending tacker that can be used in any layer 
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module pending_tracker

#(
  parameter TP                = `TP,


  parameter CNT_WIDTH         =  2
) 
                      (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input    logic                core_clk,             // Core clock
  input    logic                core_rst_n,           // Active low asynchronous reset
  input    logic                clear,                // Synchronous clear
  input    logic                entry_event,
  input    logic                exit_event,
  input    logic                blk_pending,
  output   logic                pending
);
logic [CNT_WIDTH-1:0] counter;

always_ff @(posedge core_clk or negedge core_rst_n) begin : pending_tracker_PROC
  if(!core_rst_n) begin
    counter <= #TP '0;
  end else if ( clear ) begin
    counter <= #TP '0;
  end else if ( entry_event && exit_event ) begin
    counter  <= #TP counter ;
  end else if ( entry_event && !exit_event ) begin
    counter  <= #TP counter + 1'b1;
  end else if ( !entry_event && exit_event ) begin
    counter  <= #TP counter - 1'b1;
  end else begin
    counter  <= #TP counter ;
  end
end : pending_tracker_PROC

assign pending = (counter!=0 || blk_pending);


endmodule
