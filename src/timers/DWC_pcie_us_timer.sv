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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/timers/DWC_pcie_us_timer.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// --- This module implements a microsecond timer.
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_us_timer
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
  input                                 clk,                // timer clock
  input                                 rst_n,              // timer reset
  input                                 clear_timer,        // synchronous clear
  input                                 hold_timer,         // freeze the timer
  input                                 enable,             // enable the timer
  input [(TIMER_WIDTH - 1) : 0]         timer_target,       // timer target value
  input [2:0]                           current_data_rate,  // if connected to pcie core clock sets the core clock rate
  input [(BASE_TIMER_WIDTH - 1) : 0]    base_timer_target,  // target value for the base timer
  input [(BASE_TIMER_WIDTH - 1) : 0]    base_timer_incr,    // increment for the base timer
  input                                 base_timer_clear,   // clear the base timer
  // Outputs
  output  reg                           us_timeout_r, // pulse that indicates the timer expired
  output  wire                          us_timeout,   // unregistered version of timeout 
  output  wire [(TIMER_WIDTH - 1) : 0]  us_timer            // timer value
);

// -------------------------------------------------------------------------
// Localparam definitions
// -------------------------------------------------------------------------
localparam [(TIMER_WIDTH - 1) : 0]      TIMER_TARGET_1US = {{(TIMER_WIDTH - 1){1'b0}}, 1'b1};
// -------------------------------------------------------------------------
// Register Declaration
// -------------------------------------------------------------------------
reg       int_wait_final_us_r;
reg [3:0] int_cntr8_r;
wire      int_core_clk_en_r;
reg       int_us_timeout_r;

// -------------------------------------------------------------------------
// Net Declaration
// -------------------------------------------------------------------------
wire      s_incr_base_timer;
wire      int_base_timeout;
wire      int_us_target;
wire      int_set_hold_timer;
wire      int_hold_timer;
wire      int_us_timeout_b;
wire      int_wait_final_us_b;
wire      int_clear_us_timer;
reg       int_core_clk_en_b;
reg [3:0] int_cntr8_b;
wire      int_1us_target;

// -------------------------------------------------------------------------
// Depending on the link data rate enable core clock cycles to give the base clock rate,
// i.e. enabled core clock frequency equal to the base clock frequency .
// -------------------------------------------------------------------------

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_gen_int_core_clk_en_r
(
     .clk               (clk)
    ,.rst_n             (rst_n)
    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (!enable || clear_timer)        // clear cycle counter(not used in this timer)
    
    ,.cnt_up_en         (int_core_clk_en_r)  // timer count-up 
);

    assign s_incr_base_timer = (int_core_clk_en_r && enable);

// -------------------------------------------------------------------------
// Base timer count us intervals based on clk
// -------------------------------------------------------------------------
DWC_pcie_base_timer

  // Parameters
  #(
  .TIMER_WIDTH  (BASE_TIMER_WIDTH),
  .RST_VALUE    (BASE_TIMER_RST_VAL)
  ) u_base_timer (
  // Inputs
  .clk          (clk),
  .rst_n        (rst_n),
  .clear_timer  (base_timer_clear),
  .hold_timer   (hold_timer),
  .enable       (s_incr_base_timer),
  .timer_target (base_timer_target),
  .incr         (base_timer_incr),
  // Outputs
  .timeout_r    (),
  .timeout      (int_base_timeout),
  .timer_r      ()
);

// -------------------------------------------------------------------------
// Microsecond timer - counts us pulses
// -------------------------------------------------------------------------
assign int_1us_target = (timer_target == TIMER_TARGET_1US);

// Timer holds its value when the target is reached until the final microsecond expires
assign int_set_hold_timer = !int_1us_target && (us_timer == (timer_target - 1'b1));
assign int_wait_final_us_b = (int_base_timeout ? 1'b0 : 
                          (int_set_hold_timer ? 1'b1 : int_wait_final_us_r));
assign int_hold_timer = hold_timer || int_wait_final_us_b;

// Set the timer target
assign int_us_target = (us_timer == (timer_target - 1'b1));

// Clear the timer when the final millisecond expires
assign int_us_timeout_b = int_base_timeout && int_us_target;
assign int_clear_us_timer = int_us_timeout_b || clear_timer;

DWC_pcie_base_timer

  // Parameters
  #(
  .TIMER_WIDTH  (TIMER_WIDTH)
  ) u_us_timer (
  // Inputs
  .clk          (clk),
  .rst_n        (rst_n),
  .clear_timer  (int_clear_us_timer),
  .hold_timer   (int_hold_timer),
  .enable       (int_base_timeout),
  .timer_target (timer_target),
  .incr         ({{(TIMER_WIDTH - 1){1'b0}}, 1'b1}),
  // Outputs
  .timeout_r    (),
  .timeout      (),
  .timer_r      (us_timer)
);

always @(posedge clk or negedge rst_n) 
begin : timer_PROC
  if(!rst_n)
  begin
    int_us_timeout_r    <= #TP 1'b0;
    int_wait_final_us_r <= #TP 1'b0;
    us_timeout_r        <= #TP 1'b0;
  end
  else
  begin
    int_us_timeout_r    <= #TP int_us_timeout_b;
    int_wait_final_us_r <= #TP int_wait_final_us_b;
    us_timeout_r        <= #TP us_timeout;
  end
end : timer_PROC

assign us_timeout = int_us_timeout_b && !int_us_timeout_r;


endmodule
