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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_timer.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// --- This module implements a synchronous counter with scaler
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_timer
  // Parameters
  #(
  parameter TP = `TP,
  parameter SCALE_WD = 2,
  parameter TARGET_WD = 8
  )
  
                  (
  // Inputs
  input                     aux_clk,    // Counter clock
  input                     pwr_rst_n,  // Reset
  input [SCALE_WD - 1 : 0]  scale,      // scale timer will count scale * target
  input [TARGET_WD - 1 : 0] target,     // timer target value
  input                     enable,     // timer enable should be a level signal the timer
                                        // increments when enable is 1 and
                                        // resets when enable is 0
  input                     hold_timer, // Timer holds its value
  // Outputs
  output  reg               pm_timer_timeout  // Indicates timer has expired
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
localparam [TARGET_WD - 1 : 0]  BASE_RST_VALUE = {TARGET_WD{1'b0}};
localparam [SCALE_WD - 1 : 0]   SCALER_RST_VALUE = {SCALE_WD{1'b0}};

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire                      int_scaler_enable;
wire  [SCALE_WD - 1 : 0]  int_timer;
wire  [TARGET_WD - 1 : 0] int_base_timer;
wire                      int_base_timer_exp;
wire                      int_base_timer_clear;
wire                      int_timer_exp;
wire                      int_timer_clear;
wire                      int_timer_timeout;

// ----------------------------------------------------------------------------
// Register Declarations
// ----------------------------------------------------------------------------
reg [SCALE_WD - 1 : 0]  int_timer_r;
reg [TARGET_WD - 1 : 0] int_base_timer_r;

// Base timer counts up to target value
assign int_base_timer_exp = (int_base_timer_r == target - 1);
assign int_base_timer_clear = !enable || int_base_timer_exp;
// If base timer is disabled or reaches its target it is reset otherwise it increments
assign int_base_timer = hold_timer ? int_base_timer_r :
                        (int_base_timer_clear ? BASE_RST_VALUE : int_base_timer_r + 1'b1);

// Scaler increments each time the base timer expires and is reset when it expires or if the timer is disabled
assign int_scaler_enable = enable && |scale && int_base_timer_exp;
assign int_timer_exp = int_scaler_enable && (int_timer_r == scale);
assign int_timer_clear =  int_timer_exp || !enable;
assign int_timer = int_timer_clear ? SCALER_RST_VALUE : (int_scaler_enable ? (int_timer_r + 1'b1) : int_timer_r);

assign int_timer_timeout = int_scaler_enable ? int_timer_exp : int_base_timer_exp;

always @(posedge aux_clk or negedge pwr_rst_n)
begin
  if(!pwr_rst_n)
  begin
    int_timer_r <= #TP {SCALE_WD{1'b0}};
    int_base_timer_r <= #TP {TARGET_WD{1'b0}};
    pm_timer_timeout <= #TP 1'b0;
  end
  else
  begin
    int_timer_r <= #TP int_timer;
    int_base_timer_r <= #TP int_base_timer;
    pm_timer_timeout <= #TP int_timer_timeout;
  end
end

endmodule
