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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/ltssm_latency_tracker_fsm.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// Flit latency tracker fsm module 
// Description: Implements Ltssm latency tracking finite state machine. 
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module ltssm_latency_tracker_fsm
  import DWC_pcie_core_pkg::latency_tracking_status_e;
  import DWC_pcie_core_pkg::IDLE;
  import DWC_pcie_core_pkg::STARTED;
  import DWC_pcie_core_pkg::DONE;
  import DWC_pcie_core_pkg::ERROR;
  // Parameters
#(
  parameter PL_AUX_CLK_FREQ_WD = `CX_PL_AUX_CLK_FREQ_WD
)
(
  // Inputs
  input  aux_clk,
  input  pwr_rst_n,
  input  pm_perst_powerdown,
  input  aux_clk_active,
  input  ltssm_track_en,                              // Enable latency tracing
  input  ltssm_start_tracing,                         // Start latency tracing event
  input  ltssm_end_tracing,                           // End latency tracing
  input  [2:0] current_data_rate,                     // Current data rate
  input  [PL_AUX_CLK_FREQ_WD-1:0] pm_pl_aux_clk_freq, // Aux clock frequency
  // Outputs
  output  latency_tracking_status_e ltssm_tracking_state, // Latency tracing status
  output  logic [15:0] ltssm_latency_value                // Latency value (64ns unit)
);

parameter TP = `TP;  // Clock to Q delay (simulator insurance)

/////////////////////////////////////////////////////////////////

// 64 Microsecond timer
latency_tracking_status_e ltssm_next_tracking_state;
logic [16:0] ltssm_latency_timer;
logic [5:0]  ltssm_latency_64us_counter;

wire  [5:0]  int_64us_timeout_value;

logic        int_us_timeout, int_64us_timeout;
logic        aux_clk_en_1us;

// Need to put the mux of core_clk base timer and aux_clk base timer
assign us_timeout = aux_clk_active ? aux_clk_en_1us : int_us_timeout;

always @(posedge aux_clk or negedge pwr_rst_n) begin : ltssm_latency_64us_counter_PROC
  if(!pwr_rst_n) ltssm_latency_64us_counter <= #TP 'b0;
  else if (!ltssm_track_en || int_64us_timeout)  ltssm_latency_64us_counter <= #TP 'b0;
  else if (ltssm_tracking_state == STARTED)
    ltssm_latency_64us_counter <= #TP us_timeout ? (ltssm_latency_64us_counter + 1) : ltssm_latency_64us_counter;
end : ltssm_latency_64us_counter_PROC

// This wire can be forced to a smaller value to speed-up simulation
assign int_64us_timeout_value = 6'd63;
assign int_64us_timeout = (ltssm_latency_64us_counter == int_64us_timeout_value);

always @(posedge aux_clk or negedge pwr_rst_n) begin : ltssm_latency_timer_PROC
  if(!pwr_rst_n) ltssm_latency_timer <= #TP 'b0;
  else if (!ltssm_track_en)  ltssm_latency_timer <= #TP 'b0;
  else if ((ltssm_tracking_state == STARTED) && !ltssm_latency_timer[16])
    ltssm_latency_timer <= #TP int_64us_timeout ? (ltssm_latency_timer + 1) : ltssm_latency_timer;
end : ltssm_latency_timer_PROC

// Microsecond timer
localparam BASE_TIMER_WIDTH = 9;
localparam [BASE_TIMER_WIDTH - 1 : 0] BASE_TIMER_INCR = `CX_FREQ_MULTIPLIER;
localparam BASE_TIMER_TARGET = 9'd256;
localparam BASE_TIMER_RST_VAL = 9'd0;
localparam GEN2_DYNAMIC_FREQ_VALUE = `CX_GEN2_DYNAMIC_FREQ_VALUE;
localparam TIMER_TARGET = 1'd1; // count 1us intervals

logic [BASE_TIMER_WIDTH - 1 : 0]  int_base_timer_target;

assign int_base_timer_target = BASE_TIMER_TARGET;

// 1us timer using core_clk
DWC_pcie_us_timer
 #(
  .TIMER_WIDTH              (1),
  .GEN2_DYNAMIC_FREQ_VALUE  (GEN2_DYNAMIC_FREQ_VALUE),
  .BASE_TIMER_WIDTH         (BASE_TIMER_WIDTH),
  .BASE_TIMER_RST_VAL       (BASE_TIMER_RST_VAL)
) u_us_timer (
  // Inputs
  .clk                (aux_clk),
  .rst_n              (pwr_rst_n),
  .clear_timer        (!ltssm_track_en),
  .hold_timer         (1'b0),
  .enable             ((ltssm_tracking_state == STARTED)),
  .timer_target       (TIMER_TARGET),
  .current_data_rate  (current_data_rate),
  .base_timer_target  (int_base_timer_target),
  .base_timer_incr    (BASE_TIMER_INCR),
  .base_timer_clear   (!ltssm_track_en),
  // Outputs
  .us_timeout_r       (),
  .us_timer           (),
  .us_timeout         (int_us_timeout)
);

// 1us timer using free running aux_clk
pm_active_ctrl_aux_timer
 u_pm_active_ctrl_aux_timer (
// ---- inputs ---------------
    .aux_clk                     (aux_clk),
    .pwr_rst_n                   (pwr_rst_n),
    .aux_clk_freq                (pm_pl_aux_clk_freq),
    // Switch to timer that runs on core_clk_ug to keep 1us duration
    .timer2                      (1'b0),
    .aux_clk_active              (aux_clk_active),

// ---- outputs ---------------
    .en_1us                      (aux_clk_en_1us)
);

assign ltssm_latency_value = (ltssm_tracking_state == DONE)? ltssm_latency_timer[15:0] : 'b0;

// FLIT Latency Tracking State Machine
always_comb begin : ltssm_tracking_state_PROC
  ltssm_next_tracking_state = ltssm_tracking_state;
  case (ltssm_tracking_state)
    IDLE : begin
      if(ltssm_track_en && ltssm_start_tracing)
        ltssm_next_tracking_state = STARTED;
      else
        ltssm_next_tracking_state = IDLE;
    end
    // Performence measurement is enabled
    STARTED : begin
      if(!ltssm_track_en)
        ltssm_next_tracking_state = IDLE;
      else if(ltssm_latency_timer[16])
        ltssm_next_tracking_state = ERROR;
      else if(ltssm_end_tracing)
        ltssm_next_tracking_state = DONE;
      else
        ltssm_next_tracking_state = STARTED;
    end
    DONE : begin
        ltssm_next_tracking_state = IDLE;
    end
    ERROR : begin
      if(!ltssm_track_en)
        ltssm_next_tracking_state = IDLE;
      else
        ltssm_next_tracking_state = ERROR;
    end
    default : begin
        ltssm_next_tracking_state = IDLE;
    end
  endcase
end : ltssm_tracking_state_PROC

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : ltssm_state_PROC
  if(!pwr_rst_n) begin
    ltssm_tracking_state <= #TP IDLE;
  end else begin
    if(pm_perst_powerdown) begin
      ltssm_tracking_state <= #TP IDLE;
    end else begin
      ltssm_tracking_state <= #TP ltssm_next_tracking_state;
    end  
  end  
end : ltssm_state_PROC




endmodule
/////////////////////////////////////////////////////////////////
