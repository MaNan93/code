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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pipe_to_aux_sync.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module transfers a single pulse on PHYSTATUS from pipe_clk to
// --- aux_clk domain. It is used with PIPE4.3 support to insure that P1.2
// --- P1 transition has been acknowledged by the PHY before P0
// --- transition on powerdown interface.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pipe_to_aux_sync
#(
    parameter NL            = `CX_NL,
    parameter TP            = `TP,
    parameter PM_SYNC_DEPTH = 2

)
(
  input               pipe_clk,               // pipe_clk
  input               aux_clk,                // aux_clk
  input               rst_n,                  // asynchronous reset
  input [NL - 1 : 0]  phy_mac_phystatus,      // PHYSTATUS
  input [NL - 1 : 0]  mac_phy_txcompliance,   // Lanes active
  input               pm_en_pulse_det,        // Enable pulse detection circuitry
  output  wire        pipe_aux_sync_p1_ack,   // aux_clk domain phystatus pulse
  output  reg         pipe_aux_sync_block     // when low this signal indicates the pulse conversion is done
);


reg [NL-1:0]  int_phystatus_r;
reg [NL-1:0]  int_phystatus;
wire          int_all_phystatus_asserted;
wire          int_block_pipe_pulse;
reg           int_block_pipe_pulse_r;
wire          int_spulse_toggle;
wire          int_pulse_blocker;
wire          int_pipe_sync_block;
wire          int_last_phystatus_asserted;
wire          int_clear_block;
reg           int_pipe_sync_block_r;
wire          int_aux_sync_block;
wire          int_phystatus_held;
reg           int_phystatus_held_r;

// Latch the PHY status
always @(*)
begin
  integer ln;

  int_phystatus = {NL{1'b0}};

  if (int_all_phystatus_asserted || !pm_en_pulse_det) begin
    int_phystatus = {NL{1'b0}};
  end else begin
    for (ln=0; ln<NL; ln=ln+1) begin
      if (mac_phy_txcompliance[ln])
        int_phystatus[ln] = 1'b1;
      else if (phy_mac_phystatus[ln] && pm_en_pulse_det)
        int_phystatus[ln] = 1'b1;
      else
        int_phystatus[ln] = int_phystatus_r[ln];
    end
  end
end

// Detect the assertion and de-assertion of PHYSTATUS on all lanes
assign int_phystatus_held = int_last_phystatus_asserted ? 1'b1 :
  (!(|phy_mac_phystatus) ? 1'b0 : int_phystatus_held_r);

always @(posedge pipe_clk or negedge rst_n)
begin
  if(!rst_n) begin
    int_phystatus_r <= #TP {NL{1'b0}};
    int_phystatus_held_r <= #TP 1'b0;
  end
  else begin
    int_phystatus_r <= #TP int_phystatus;
    int_phystatus_held_r <= #TP int_phystatus_held;
  end
end

// Detect phystatus asserted on all active lanes
assign int_all_phystatus_asserted = &int_phystatus_r;

// Detect when the last phystatus required is being asserted
assign int_last_phystatus_asserted = &int_phystatus && !(&int_phystatus_r); 

// Pulse converter must complete conversion of a single pulse before any subsequent pulses can be converted
assign int_pulse_blocker = int_block_pipe_pulse_r || int_pipe_sync_block;
assign int_spulse_toggle = (int_last_phystatus_asserted && !int_pulse_blocker);

// Pulse converter to transfer PHY status in PIPE_CLK domain to AUX_CLK
// domain for handshake with PIPE4.3 gasket in P1
DWC_pcie_ctl_bcm22
 #(
  .PULSE_MODE (0),
  .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_aux_pulse_sync (
  .clk_s    (pipe_clk),
  .rst_s_n  (rst_n),
  .init_s_n (1'b1),
  .event_s  (int_spulse_toggle),
  .clk_d    (aux_clk),
  .rst_d_n  (rst_n),
  .init_d_n (1'b1),
  .event_d  (pipe_aux_sync_p1_ack)
);

// Synchronize the signal to block pulses back to aux_clk domain
// this is used as an indication that pulse conversion has completed
// and the blocking signal can be cleared
DWC_pcie_ctl_bcm41

#(
    .WIDTH (1),
    .RST_VAL (0),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_aux_unblock_sync (
    .clk_d      (aux_clk),
    .rst_d_n    (rst_n),
    .data_s     (int_block_pipe_pulse_r),
    .data_d     (int_aux_sync_block)
);

// Synchronize the aux clock domain blocking signal back to pipe_clk
// to be used to clear the pulse blocking signal
DWC_pcie_ctl_bcm41

#(
    .WIDTH (1),
    .RST_VAL (0),
    .F_SYNC_TYPE (PM_SYNC_DEPTH)
) u_pipe_unblock_sync (
    .clk_d      (pipe_clk),
    .rst_d_n    (rst_n),
    .data_s     (int_aux_sync_block),
    .data_d     (int_pipe_sync_block)
);

// Block subsequent pipe_clk domain pulses at the input to the pulse
// converter until the aux_clk domain pulse has been detected.
assign int_clear_block = int_pipe_sync_block && !int_pipe_sync_block_r;
assign int_block_pipe_pulse = int_clear_block ? 1'b0 : 
  (int_spulse_toggle ? 1'b1 : int_block_pipe_pulse_r);

always @(posedge pipe_clk or negedge rst_n)
begin
  if (!rst_n) begin
    int_block_pipe_pulse_r <= #TP 1'b0;
    int_pipe_sync_block_r <= #TP 1'b0;
  end else begin
    int_block_pipe_pulse_r <= #TP int_block_pipe_pulse;
    int_pipe_sync_block_r <= #TP int_pipe_sync_block;
  end
end

always @(posedge aux_clk or negedge rst_n)
begin
  if(!rst_n)
    pipe_aux_sync_block <= #TP 1'b0;
  else
    pipe_aux_sync_block <= #TP int_aux_sync_block;
end

endmodule
