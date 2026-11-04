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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_powerdown_hs.sv#10 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains synchronization logic for the Phy powerdown
// handshake.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_powerdown_hs
  // Parameters
  #(
    parameter TP            = `TP,
    parameter NL            = 1,
    parameter PM_SYNC_DEPTH = 2
  ) (
    input                 aux_clk, // aux_clk
    input                 pwr_rst_n, // power on reset
    input [1:0]           aux_sync_phystatus_pulse, // pulse indicating all active lanes phystatus synchronized to aux_clk
    input [(NL - 1) : 0]  phy_mac_phystatus, // Phystatus handshake signal
    input [1:0]           phystatus_pc_busy, // pulse converter busy indication 1 per pulse converter    
    input [1:0]           en_pulse_det, // enables for the pulse detection circuits
    input                 prev_p0, // previous powerdown was P0
    input                 powerdown_p1, // powerdown is P1
    input [(NL - 1) : 0]  pm_lane_active,
    input                 phy_mac_maxpclkack_n, // asynchronous maxpclkack_n from pipe.
    input                 en_async_hs, // enable the asynchronous handshake
    output  logic         pd_hs_phystatus_r, // Combined per-lane phystatus synchronized to aux_clk
    output  logic         pd_hs_phystatus_low,
    output  logic         pd_p1_hs_done,  // A single cycle pulse that indicated Phystatus detected on all active lanes
                                          // after P0->P1/P1.CPM->P1 transition.
    output  logic         pd_p1cpm_hs_done  // A single cycle pulse that indicated Phystatus detected on all active lanes
                                            // after P1.CPM transition.
    ,
    output logic          pd_maxpclkack_n_rise_det,// detect rising edge in pd_maxpclkack_n
    output logic          pd_maxpclkack_n_fall_det // detect falling edge in pd_maxpclkack_n
);

// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------
logic [(NL - 1) : 0]  int_phystatus_sync_r;
logic [(NL - 1) : 0]  int_phystatus_sync_b;
logic                 int_active_phystatus_low;
logic [1:0]           int_phystatus_pulse_b;
logic [1:0]           int_phystatus_pulse_r;
logic [1:0]           int_phystatus_pulse_rr;
logic [1:0]           int_p1_hs_done_b;
logic [1:0]           int_p1_hs_done_r;
logic [(NL - 1) : 0]  int_active_phystatus;
logic                 int_phystatus_b;
logic [1:0]           int_phystatus_pulse;
logic                 int_maxpclkack_n_b;
logic                 int_maxpclkack_n_r;
logic                 int_maxpclkack_n_rr;
logic                 pd_maxpclkack_n;         // maxpclkack_n sync to aux_clk

// ----------------------------------------------------------------------------
// Synchronize Phystatus to aux_clk
// ----------------------------------------------------------------------------
DWC_pcie_ctl_bcm41

#(
  .WIDTH   (NL),
  .RST_VAL (0),
  .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_sync (
  .clk_d    (aux_clk),
  .rst_d_n  (pwr_rst_n),
  .data_s   (phy_mac_phystatus),
  .data_d   (int_phystatus_sync_b)
);

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : phystatus_PROC
  if(!pwr_rst_n) begin
    int_phystatus_sync_r <= #TP {NL{1'b0}};
    int_phystatus_pulse_r <= #TP 2'b00;
    int_phystatus_pulse_rr <= #TP 2'b00;
    int_p1_hs_done_r <= #TP 2'b00;
    pd_hs_phystatus_r <= #TP 1'b0;
  end
  else begin
    int_phystatus_sync_r <= #TP int_phystatus_sync_b;
    int_phystatus_pulse_r <= #TP int_phystatus_pulse_b;
    int_phystatus_pulse_rr <= #TP int_phystatus_pulse_r;
    int_p1_hs_done_r <= #TP int_p1_hs_done_b;
    pd_hs_phystatus_r <= #TP int_phystatus_b;
  end
end : phystatus_PROC

// Mask the Phystatus from all inactive lanes
assign int_active_phystatus = int_phystatus_sync_r & pm_lane_active;
// Only consider active lanes Phystatus, inactiv lane is treated as phystatus == 1
assign int_phystatus_b = &(int_active_phystatus | ~pm_lane_active) && en_async_hs;

// ----------------------------------------------------------------------------
// Generate phystatus handhsake for P1/P1.CPM transitions
// ----------------------------------------------------------------------------
assign int_active_phystatus_low = !(|int_active_phystatus);
assign pd_hs_phystatus_low = int_active_phystatus_low;
always_comb begin : phystatus_comb_PROC
  integer i;
  int_phystatus_pulse_b = 2'b00;
  for (i = 0; i < 2; i = i + 1) begin
    // Phystatus pulse detected
    if(aux_sync_phystatus_pulse[i])
      int_phystatus_pulse_b[i] = 1'b1;
    // Phystatus on all active lanes detected low
    else if(int_active_phystatus_low)
      int_phystatus_pulse_b[i] = 1'b0;
    // Hold the value
    else
      int_phystatus_pulse_b[i] = int_phystatus_pulse_r[i];
  end
end : phystatus_comb_PROC

assign int_phystatus_pulse = (~int_phystatus_pulse_r & int_phystatus_pulse_rr);

// Detect the Phystatus pulse followed by the de-assertion of the pulse
// converter busy signal. This indicates the Phystatus handshake is complete.
always_comb begin : p1_hs_comb_PROC
  integer j;
  int_p1_hs_done_b = 2'b00;
  for (j = 0; j < 2; j = j + 1) begin
    // Phystatus hs
    if(int_phystatus_pulse[j] && powerdown_p1)
      int_p1_hs_done_b[j] = 1'b1;
    // Pulse converter not busy
    else if(!phystatus_pc_busy[j])
      int_p1_hs_done_b[j] = 1'b0;
    else
      int_p1_hs_done_b[j] = int_p1_hs_done_r[j];
  end
end : p1_hs_comb_PROC

assign pd_p1_hs_done = (prev_p0 && !int_p1_hs_done_b[0] && int_p1_hs_done_r[0] & en_pulse_det[0]) || (!int_p1_hs_done_b[1] && int_p1_hs_done_r[1] & en_pulse_det[1]);
assign pd_p1cpm_hs_done = int_phystatus_pulse[0];


// ----------------------------------------------------------------------------
// Synchronize phy_mac_maxpclkack_n to aux_clk
// ----------------------------------------------------------------------------
DWC_pcie_ctl_bcm41

#(
  .WIDTH   (1),
  .RST_VAL (0),
  .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_sync_maxpclkack (
  .clk_d    (aux_clk),
  .rst_d_n  (pwr_rst_n),
  .data_s   (phy_mac_maxpclkack_n),
  .data_d   (int_maxpclkack_n_b)
);

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : maxpclkack_PROC
  if(!pwr_rst_n) begin
    int_maxpclkack_n_r  <= #TP 1'b0;
    int_maxpclkack_n_rr <= #TP 1'b0;
  end
  else begin
    int_maxpclkack_n_r  <= #TP int_maxpclkack_n_b;
    int_maxpclkack_n_rr <= #TP int_maxpclkack_n_r;
  end
end : maxpclkack_PROC

assign pd_maxpclkack_n_rise_det = int_maxpclkack_n_r & !int_maxpclkack_n_rr;
assign pd_maxpclkack_n_fall_det = !int_maxpclkack_n_r & int_maxpclkack_n_rr;


endmodule
