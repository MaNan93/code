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
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_phystatus_sync.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains Phystatus synchronization logic
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module DWC_pcie_phystatus_sync

import DWC_pcie_pm_pkg::NL;
import DWC_pcie_pm_pkg::PWDN_WIDTH;
import DWC_pcie_pm_pkg::P0;
import DWC_pcie_pm_pkg::P0S;
import DWC_pcie_pm_pkg::P1;
import DWC_pcie_pm_pkg::P1CPM;
import DWC_pcie_pm_pkg::P2;
import DWC_pcie_pm_pkg::P2NOBEACON;
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_DETECT_QUIET;
  // Parameters
  #(
    parameter TP = `TP
  ) (
  // Inputs
  input                         aux_clk,
  input                         pipe_clk,
  input                         pwr_rst_n,
  input [(NL - 1) : 0]          phy_mac_phystatus,        // Phystatus per lane
  input [(NL - 1) : 0]          mac_phy_txcompliance,     // Txcompliance used to determine the active lanes
  input [(PWDN_WIDTH - 1) : 0]  mac_phy_powerdown,        // Current powerdown value
  input                         rate_change_active,       // Rate change in progress
  input [5:0]                   pm_link_capable,          // PL LINK_CAPABLE register, indicate used lanes at reset
  input ltssm_state_e           smlh_ltssm_state,         // LTSSM state
  input                         pm_sel_aux_clk,
  input                         pm_perst_powerdown,       // Indicate PIPE or PMA reset request.
  // Outputs
  output logic                  phystatus_high,           // phystatus captured high indication in aux_clk domain
  output logic                  phystatus_low,            // phystatus low indication in aux_clk domain
  output logic                  phystatus_pclk_ready,   // Phystatus sampled low after reset is de-asserted
  output logic                  phystatus_sync_done_pipe,  // Phystatus synchronization done in pipe_clk domain
  output logic [NL-1:0]         pm_lane_active
  ,output logic                 phystatus_done_always_trace
);
// Logic Declarations
logic [1:0]           int_pd_change_detected;
logic [1:0]           int_en_detector;
logic [(NL - 1) : 0]  int_phystatus_sync_b;
logic [(NL - 1) : 0]  int_phystatus_sync_r;
logic                 int_active_phystatus_r;
logic                 int_active_phystatus_b;
logic [1:0]           int_phystatus_high;
logic [1:0]           int_phystatus_low;
logic [1:0]           int_phystatus_sync_done;
logic [NL-1:0]        int_lane_active;
logic [NL-1:0]        int_lane_active_rst;
// The following signals are only used for a always on phstatus detection
logic                 int_sync_phystatus_high;
logic                 int_sync_phystatus_low;
logic                 int_sync_phystatus_sync_done;
logic                 int_pm_perst_powerdown_r;
logic                 int_pm_perst_powerdown_re_s;
logic                 int_pm_phy_rst_s;
logic                 int_pm_phy_rst_r;
logic                 int_phystatus_pclk_ready_r;
logic                 int_phystatus_pclk_ready_re_s;
logic                 int_bypass_phystatus_detect;

// ----------------------------------------------------------------------------
// Synchronize Phystatus Level to aux_clk
// ----------------------------------------------------------------------------
DWC_pcie_ctl_bcm41

#(
  .WIDTH        (NL),
  .RST_VAL      ({NL{1'b1}}),
  .F_SYNC_TYPE  (`CX_PCIE_SYNC_DEPTH)
) u_sync (
  .clk_d    (aux_clk),
  .rst_d_n  (pwr_rst_n),
  .data_s   (phy_mac_phystatus),
  .data_d   (int_phystatus_sync_b)
);

// int_pm_phy_rst_r is used to trace the duration
// start when pos-edge of pm_perst_powerdown is detected
// end when pos-edge of phystatus_pclk_ready is detected
// during PMA/PIPE reset, one of the phystatus detector
// is disabled until the pclk is ready
assign int_pm_perst_powerdown_re_s = !int_pm_perst_powerdown_r && pm_perst_powerdown;
assign int_phystatus_pclk_ready_re_s = !int_phystatus_pclk_ready_r && phystatus_pclk_ready;

always @ *
begin
    if(int_pm_perst_powerdown_re_s)
        int_pm_phy_rst_s = 1'b1;
    // Need to use pm_perst_powerdown to guard from power gating
    else if(int_phystatus_pclk_ready_re_s && !pm_perst_powerdown)
        int_pm_phy_rst_s = 1'b0;
    else
        int_pm_phy_rst_s = int_pm_phy_rst_r;
end

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : phystatus_PROC
  if (!pwr_rst_n) begin
    int_phystatus_sync_r    <= #TP {NL{1'b1}};
    int_active_phystatus_r  <= #TP 1'b1;
    int_pm_perst_powerdown_r <= #TP 1'b1;
    int_pm_phy_rst_r         <= #TP 1'b1;
    int_phystatus_pclk_ready_r<= #TP 1'b0;
  end
  else
  begin
    int_phystatus_sync_r    <= #TP int_phystatus_sync_b;
    int_active_phystatus_r  <= #TP int_active_phystatus_b;
    int_pm_perst_powerdown_r <= #TP pm_perst_powerdown;
    int_pm_phy_rst_r         <= #TP int_pm_phy_rst_s;
    int_phystatus_pclk_ready_r<= #TP phystatus_pclk_ready;
  end
end : phystatus_PROC

// Convert from pm_link_capable to the number of active lanes
assign int_lane_active_rst = 
       pm_link_capable[3] ? 16'h00ff :
       pm_link_capable[2] ? 16'h000f :
       pm_link_capable[1] ? 16'h0003 :
       pm_link_capable[0] ? 16'h0001 : 16'h0000;

assign int_lane_active = (smlh_ltssm_state==S_DETECT_QUIET) ? int_lane_active_rst : ~mac_phy_txcompliance;
assign int_active_phystatus_b = |(int_phystatus_sync_r & int_lane_active);

assign pm_lane_active = int_lane_active;

// The reason for seperate instances is due to synchronization of phystatus on transitions 
// from states where PCLK disabled into states where PCLK is enabled, since PCLK is removed
// before Phystatus is de-asserted the low level of Phystatus cannot flush through the synchronizer
// until PCLK is restarted. To insure Phystatus is captured cleanly in all states seperate detection
// logic is used.
// P0/P0S/P1 - Instance 0 is used for these states in which PCLK is running.
// P1.CPM/P2 - Instance 1 is used for these states in which PCLK is not running.
assign int_pd_change_detected = {((mac_phy_powerdown == P1CPM) || (mac_phy_powerdown == P2)
 || (mac_phy_powerdown == P2NOBEACON) ),
                                 ((mac_phy_powerdown == P0) || (mac_phy_powerdown == P0S) || (mac_phy_powerdown == P1))};
// Enable the phystatus detector when rate change is not active
// phystatus_pclk_ready is used to guard Instance 0. After PMA/PIPE reset, before pclk is back.
assign int_en_detector = int_pd_change_detected & ~{2{rate_change_active}} & {1'b1, !int_pm_phy_rst_r};

DWC_pcie_phystatus_detect
 #(
  .PCLK_RUNNING (1'b1)
) u_phystatus_detect_pclk_on (
  .pipe_clk             (pipe_clk),
  .aux_clk              (aux_clk),
  .pwr_rst_n            (pwr_rst_n),
  .lane_active          (int_lane_active),
  .phy_mac_phystatus    (phy_mac_phystatus),
  .en_detector          (int_en_detector[0]),
  .aux_phystatus        (int_active_phystatus_r),
  .pm_perst_powerdown   (pm_perst_powerdown),
  // Outputs
  .phystatus_high       (int_phystatus_high[0]),
  .phystatus_low        (int_phystatus_low[0]),
  .phystatus_sync_done  (int_phystatus_sync_done[0])
);

DWC_pcie_phystatus_detect
 #(
  .PCLK_RUNNING (1'b0)
) u_phystatus_detect_pclk_off (
  .pipe_clk             (pipe_clk),
  .aux_clk              (aux_clk),
  .pwr_rst_n            (pwr_rst_n),
  .lane_active          (int_lane_active),
  .phy_mac_phystatus    (phy_mac_phystatus),
  .en_detector          (int_en_detector[1]),
  .aux_phystatus        (int_active_phystatus_r),
  .pm_perst_powerdown   (pm_perst_powerdown),
  // Outputs
  .phystatus_high       (int_phystatus_high[1]),
  .phystatus_low        (int_phystatus_low[1]),
  .phystatus_sync_done  (int_phystatus_sync_done[1])
);

assign phystatus_high = |int_phystatus_high;
assign phystatus_low = &int_phystatus_low;
// Pipe domain indication that Phystatus synchronization is finished used for Receiver detection handshake in P1
assign phystatus_sync_done_pipe = int_phystatus_sync_done[0];
// Phystatus low after reset
assign phystatus_pclk_ready = !int_active_phystatus_r;

assign int_bypass_phystatus_detect = 1'b0;

// Synchronizing phystatus from pclk to aux_clk (always trace).
DWC_pcie_phystatus_detect
 #(
  .PCLK_RUNNING (1'b1)
) u_phystatus_detect_always_on (
  .pipe_clk             (pipe_clk),
  .aux_clk              (aux_clk),
  .pwr_rst_n            (pwr_rst_n),
  .lane_active          (int_lane_active),
  .phy_mac_phystatus    (phy_mac_phystatus),
  .en_detector          (!pm_sel_aux_clk & !int_bypass_phystatus_detect), // only detect when pclk is on
  .aux_phystatus        (1'b0), // not used
  .pm_perst_powerdown   (pm_perst_powerdown),
  // Outputs
  .phystatus_high       (int_sync_phystatus_high),
  .phystatus_low        (int_sync_phystatus_low),
  .phystatus_sync_done  (int_sync_phystatus_sync_done)
);

assign phystatus_done_always_trace = int_sync_phystatus_high; // 1 aux clk cycle

endmodule
