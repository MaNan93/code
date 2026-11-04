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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_flit_tracker_fsm.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// Flit latency tracker fsm module 
// Description: Implements Flit tracking finite state machine. 
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xplh_flit_tracker_fsm
  import DWC_pcie_core_pkg::latency_tracking_status_e;
  import DWC_pcie_core_pkg::IDLE;
  import DWC_pcie_core_pkg::STARTED;
  import DWC_pcie_core_pkg::DONE;
  import DWC_pcie_core_pkg::ERROR;
(
  // Inputs
  input  core_clk,
  input  core_rst_n,
  input  flit_track_en,                                  // Enable latency tracing
  input  flit_start_tracing,                             // Start latency tracing event
  input  received_req_response,                          // Received required type response
  input  received_other_response,                        // Received different type of response
  input  [2:0] current_data_rate,                        // Current data rate
  input  [2:0] mac_phy_rate,                             // Advanced data rate that the controller would operate with
  // Outputs
  output  latency_tracking_status_e flit_tracking_state, // Latency tracing status
  output  logic [15:0] flit_latency_value                // Latency value (8ns unit)
);
parameter TP = `TP;  // Clock to Q delay (simulator insurance)

/////////////////////////////////////////////////////////////////
latency_tracking_status_e flit_next_state;
logic [19:0] flit_latency_counter;
logic [16:0] flit_latency_timer;
logic [15:0] current_clk_period;
logic [2:0]  current_freq;
logic        int_diff_rates;

// Detect the transition request to different data rates at the ltssm to drop any Flit in between
assign int_diff_rates = (current_data_rate != mac_phy_rate) ? 1'b1 : 1'b0;

//Detecting Current Operating Frequency according to the data_rate.
always_comb begin
    case(current_data_rate)
        3'h1   : current_clk_period = `CX_MAC_GEN2_CLK_PERIOD_PS;
        3'h2   : current_clk_period = `CX_MAC_GEN3_CLK_PERIOD_PS;
        3'h3   : current_clk_period = `CX_MAC_GEN4_CLK_PERIOD_PS;
        3'h4   : current_clk_period = `CX_MAC_GEN5_CLK_PERIOD_PS;
        3'h5   : current_clk_period = `CX_MAC_GEN6_CLK_PERIOD_PS;
        default: current_clk_period = `CX_MAC_GEN1_CLK_PERIOD_PS;  
    endcase
end

always_comb begin
    case(current_clk_period)
        16'd8_000: current_freq = 3'h2;       //  8ns /  125 MHz
        16'd4_000: current_freq = 3'h3;       //  4ns /  250 MHz
        16'd2_000: current_freq = 3'h4;       //  2ns /  500 MHz
        16'd1_000: current_freq = 3'h5;       //  1ns / 1000 MHz
        default  : current_freq = 3'h1;       // 16ns /   62.5MHz
    endcase
end

// FLIT Latency Counter
always @(posedge core_clk or negedge core_rst_n) begin : flit_latency_measurement
  if(!core_rst_n) flit_latency_counter <= #TP 'b0;
  else if (flit_tracking_state == IDLE)  flit_latency_counter <= #TP 'b0;
  else if ((flit_tracking_state == STARTED) && (flit_next_state != DONE) && !flit_latency_timer[16])  flit_latency_counter <= #TP flit_latency_counter + 1'b1;
end : flit_latency_measurement

// Converting counter value into 8ns time unit
always @ (*) begin
    case(current_freq)
      3'b010 : flit_latency_timer = flit_latency_counter[16:0];         //  125 MHZ
      3'b011 : flit_latency_timer = flit_latency_counter[17:1];         //  250 MHZ
      3'b100 : flit_latency_timer = flit_latency_counter[18:2];         //  500 MHZ
      3'b101 : flit_latency_timer = flit_latency_counter[19:3];         //  1000 MHZ
      default : flit_latency_timer = {flit_latency_counter[15:0],1'b0}; //  62.5 MHZ 
    endcase 
end

assign flit_latency_value = (flit_tracking_state == DONE)? flit_latency_timer[15:0] : 'b0;

// FLIT Latency Tracking State Machine
always_comb begin : flit_tracking_state_PROC
  flit_next_state = flit_tracking_state;
  case (flit_tracking_state)
    // Performence measurement is enabled
    STARTED : begin
      if((!flit_track_en) || int_diff_rates)
        flit_next_state = IDLE;
      else if(flit_latency_timer[16])
        flit_next_state = ERROR;
      else if(received_req_response)
        flit_next_state = DONE;
      else if(received_other_response)
        flit_next_state = IDLE;
      else
        flit_next_state = STARTED;
    end
    // RPLH received required flit
    DONE : begin
        flit_next_state = IDLE;
    end
    // RPLH received required flit
    ERROR : begin
      if(!flit_track_en)
        flit_next_state = IDLE;
      else
        flit_next_state = ERROR;
    end
    default : begin // IDLE
      if(flit_track_en) begin
        if(flit_start_tracing)
          flit_next_state = STARTED;
        else
          flit_next_state = IDLE;
      end else
        flit_next_state = IDLE;
    end
  endcase
end : flit_tracking_state_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_state_PROC
  if(!core_rst_n)
    flit_tracking_state <= #TP IDLE;
  else
    flit_tracking_state <= #TP flit_next_state;
end : flit_state_PROC

//------------------------------------------\\
//----------- Design Assertions ------------\\
//------------------------------------------\\

endmodule
/////////////////////////////////////////////////////////////////
