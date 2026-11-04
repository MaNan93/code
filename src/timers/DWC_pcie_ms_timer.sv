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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/timers/DWC_pcie_ms_timer.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// --- This module implements a microsecond timer.
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_ms_timer
  // Parameters
  #(
  parameter TP = `TP,
  parameter TIMER_WIDTH = 1,
  parameter GEN2_DYNAMIC_FREQ_VALUE = 0,
  parameter BASE_TIMER_WIDTH = 9,
  parameter BASE_TIMER_RST_VAL = 1
  )
  
                           (
  // Inputs
  input                                 clk,
  input                                 rst_n,
  input                                 clear_timer,
  input                                 hold_timer,
  input                                 enable,
  input [(TIMER_WIDTH - 1) : 0]         timer_target,
  input [2:0]                           current_data_rate,
  input                                 scale_timer,
  input [(BASE_TIMER_WIDTH - 1) : 0]    base_timer_target,
  input [(BASE_TIMER_WIDTH - 1) : 0]    base_timer_incr,
  input                                 base_timer_clear,

  // Outputs
  output  reg                           ms_timeout_r,
  output  wire                          ms_timeout,
  output  wire  [(TIMER_WIDTH - 1) : 0] ms_timer,
  output  wire                          us_timeout
);

// -------------------------------------------------------------------------
// Localparam declarations
// -------------------------------------------------------------------------
localparam        US_TIMER_WIDTH = 10;
localparam [9:0]  US_TIMER_TARGET = 10'd1000;

// -------------------------------------------------------------------------
// Net declarations
// -------------------------------------------------------------------------
reg   [(US_TIMER_WIDTH - 1) : 0]  int_scaled_target;
wire                              int_set_hold_timer;
wire                              int_wait_final_ms_b;
wire                              int_ms_timeout_b;
wire                              int_enable_ms_timer;
wire                              int_hold_timer;
wire                              int_clear_ms_timer;

// -------------------------------------------------------------------------
// Register declarations
// -------------------------------------------------------------------------
reg int_wait_final_ms_r;
reg int_ms_timeout_r;

// -------------------------------------------------------------------------
// Scaling the timer use for verification purpose to reduce the timer duration
// -------------------------------------------------------------------------
assign int_scaled_target = scale_timer ? 1'b1 : US_TIMER_TARGET;

// -------------------------------------------------------------------------
// Base timer counts 1000us
// -------------------------------------------------------------------------
DWC_pcie_us_timer

  // Parameters
  #(
  .TIMER_WIDTH              (US_TIMER_WIDTH),
  .GEN2_DYNAMIC_FREQ_VALUE  (GEN2_DYNAMIC_FREQ_VALUE),
  .BASE_TIMER_WIDTH         (BASE_TIMER_WIDTH),
  .BASE_TIMER_RST_VAL       (BASE_TIMER_RST_VAL)
  ) u_base_timer (
  // Inputs
  .clk                (clk),
  .rst_n              (rst_n),
  .clear_timer        (clear_timer),
  .hold_timer         (hold_timer),
  .enable             (enable),
  .timer_target       (int_scaled_target),
  .current_data_rate  (current_data_rate),
  .base_timer_target  (base_timer_target),
  .base_timer_incr    (base_timer_incr),
  .base_timer_clear   (base_timer_clear),
  // Outputs
  .us_timeout_r       (),
  .us_timeout         (us_timeout),
  .us_timer           ()
);

// -------------------------------------------------------------------------
// Millisecond timer - counts ms pulses
// -------------------------------------------------------------------------
// Timer holds its value when the target is reached until the final microsecond expires
assign int_set_hold_timer = (ms_timer == (timer_target - 1'b1));
assign int_wait_final_ms_b = (us_timeout ? 1'b0 : 
                          (int_set_hold_timer ? 1'b1 : int_wait_final_ms_r));
assign int_hold_timer = hold_timer || int_wait_final_ms_b;

// Set the timer target
assign int_ms_target = (ms_timer == (timer_target - 1'b1));

// Clear the timer when the final microsecond expires
assign int_ms_timeout_b = us_timeout && int_ms_target;
assign int_clear_ms_timer = int_ms_timeout_b || clear_timer;

assign int_enable_ms_timer = us_timeout && enable;

DWC_pcie_base_timer

  // Parameters
  #(
  .TIMER_WIDTH              (TIMER_WIDTH)
  ) u_ms_timer (
  // Inputs
  .clk          (clk),
  .rst_n        (rst_n),
  .clear_timer  (int_clear_ms_timer),
  .hold_timer   (int_hold_timer),
  .enable       (int_enable_ms_timer),
  .timer_target (timer_target),
  .incr         ({{(TIMER_WIDTH - 1){1'b0}}, 1'b1}),
  // Outputs
  .timeout_r    (),
  .timeout      (),
  .timer_r      (ms_timer)
);

always @(posedge clk or negedge rst_n)
begin : timer_PROC
  if(!rst_n)
  begin
    int_ms_timeout_r    <= #TP 1'b0;
    int_wait_final_ms_r <= #TP 1'b0;
    ms_timeout_r        <= #TP 1'b0;
  end
  else
  begin
    int_ms_timeout_r    <= #TP int_ms_timeout_b;
    int_wait_final_ms_r <= #TP int_wait_final_ms_b;
    ms_timeout_r        <= #TP ms_timeout;
  end
end : timer_PROC

assign ms_timeout = int_ms_timeout_b && !int_ms_timeout_r;

endmodule
