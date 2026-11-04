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
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_l0p_timer.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// L0P Control 
//
// Description: This module implements the L0P Timers 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_fm_l0p_timer#(
  parameter TP = `TP
)(
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                 core_clk,                 // Core clock
  input                 core_rst_n,               // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // L0P Timer Interface 
  // -------------------------------------------------------------------------------------
  input                 l0p_en_timer,             // Enable the L0P timer
  output  logic         xdlh_l0p_timeout_1us,     // 1us Timeout
  output  logic         xdlh_l0p_timeout_4us,     // 4us Timeout
  output  logic         xdlh_l0p_timeout_8us,     // 8us Timeout
  output  logic         xdlh_l0p_timeout_16us,    // 16us Timeout
  // -------------------------------------------------------------------------------------
  // Rate Information 
  // -------------------------------------------------------------------------------------
  input   [2 : 0]       current_data_rate        // Data Rate Negotiated with the PHY
);

logic [9:0]  counter;
logic [9:0]  counter_g1;
logic [15:0] current_clk_period;
logic [2:0]  current_freq;
logic [3:0]  int_us_level;  
logic        int_xdlh_l0p_timeout_1us;
logic        xdlh_l0p_timeout_4us_g1;
logic        xdlh_l0p_timeout_8us_g1;
logic        xdlh_l0p_timeout_16us_g1;
logic        xdlh_l0p_timeout_1us_g;
logic        int_xdlh_l0p_timeout_4us_g1;
logic        int_xdlh_l0p_timeout_8us_g1;
logic        int_xdlh_l0p_timeout_16us_g1;

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

always @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) 
    counter <= #TP 'b0;
  else if (!l0p_en_timer || int_xdlh_l0p_timeout_1us)  
    counter <= #TP 'b0;
  else if (l0p_en_timer)
    counter <= #TP counter + 1'b1;
end 

always @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) 
    counter_g1 <= #TP 'b0;
  else if (!l0p_en_timer)  
    counter_g1 <= #TP 'b0;
  else if (l0p_en_timer)
    counter_g1 <= #TP counter_g1 + 1'b1;
end 

// Converting counter value into 1us time unit
always @ (*) begin
    case(current_freq)
      3'b010 : int_xdlh_l0p_timeout_1us  = (counter==14'd124);          //  125  MHZ
      3'b011 : int_xdlh_l0p_timeout_1us  = (counter==14'd249);          //  250  MHZ
      3'b100 : int_xdlh_l0p_timeout_1us  = (counter==14'd499);          //  500  MHZ
      3'b101 : int_xdlh_l0p_timeout_1us  = (counter==14'd999);          //  1000 MHZ
      default : int_xdlh_l0p_timeout_1us = (counter==14'd61);           //  62.5 MHZ
    endcase 
end

// Generate multiple values of 1us
always_ff @(posedge core_clk or negedge core_rst_n) begin : timeout_PROC
  if(!core_rst_n) begin
    int_us_level <= #TP '0;
  end else begin
    // US Timeout
    if(l0p_en_timer && int_xdlh_l0p_timeout_1us)
      int_us_level <= #TP int_us_level + 1'b1;
    else if (!l0p_en_timer)
      int_us_level <= #TP '0;
  end
end : timeout_PROC


// Handle the half cycle in the case of 62.5 MHz
always @ (*) begin          
      int_xdlh_l0p_timeout_4us_g1  = (counter_g1==14'd249);         
      int_xdlh_l0p_timeout_8us_g1  = (counter_g1==14'd499);        
      int_xdlh_l0p_timeout_16us_g1 = (counter_g1==14'd999);         
end

always_ff @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    xdlh_l0p_timeout_1us_g   <= #TP '0;
    xdlh_l0p_timeout_4us_g1  <= #TP '0;
    xdlh_l0p_timeout_8us_g1  <= #TP '0;
    xdlh_l0p_timeout_16us_g1 <= #TP '0;
  end else begin
    // US Timeout
    xdlh_l0p_timeout_1us_g   <= #TP int_xdlh_l0p_timeout_1us;
    xdlh_l0p_timeout_4us_g1  <= #TP int_xdlh_l0p_timeout_4us_g1;
    xdlh_l0p_timeout_8us_g1  <= #TP int_xdlh_l0p_timeout_8us_g1;
    xdlh_l0p_timeout_16us_g1 <= #TP int_xdlh_l0p_timeout_16us_g1;
  end
end


// Generate the timeout indications for the L0P FSM's
assign xdlh_l0p_timeout_1us  = xdlh_l0p_timeout_1us_g;                                                   //1us
assign xdlh_l0p_timeout_4us  = (current_freq ==1)? xdlh_l0p_timeout_4us_g1  :(int_us_level==5'b00100 );  //4us
assign xdlh_l0p_timeout_8us  = (current_freq ==1)? xdlh_l0p_timeout_8us_g1  :(int_us_level==5'b01000 );  //8us
assign xdlh_l0p_timeout_16us = (current_freq ==1)? xdlh_l0p_timeout_16us_g1 :(int_us_level==5'b10000 );  //16us

endmodule
