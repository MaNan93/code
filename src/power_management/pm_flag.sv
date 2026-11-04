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
// ---  RCS information:
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_flag.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: This module creates a flag
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_flag
  // Parameters
  #(
    parameter TP = `TP,
    parameter INST = 0
  )
  (
    // Inputs
    input       clk,    // clock
    input       rst_n,  // asynchronous reset active low
    input       clear,  // synchronous clear
    input       set,    // synchronous set
    // Outputs
    output reg  flag_r  // flag
);

// -------------------------------------------------------------------------
// Net Declarations
// -------------------------------------------------------------------------
reg int_flag_s;

always @ *
begin
  // clear
  if(clear)
    int_flag_s = 1'b0;
  // set
  else if(set)
    int_flag_s = 1'b1;
  // hold
  else
    int_flag_s = flag_r;
end

always @(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    flag_r  <= #TP 1'b0;
  else
    flag_r  <= #TP int_flag_s;
end

endmodule
