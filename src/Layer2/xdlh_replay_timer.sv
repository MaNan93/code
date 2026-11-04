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
// ---    $DateTime: 2022/04/14 09:36:50 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_replay_timer.sv#4 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// --- This module implements the replay timer which is used to initiate link layer retry. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/xdlh_replay_timer_if.svh"

module xdlh_replay_timer #(
  parameter TP = `TP
) (
  input                         core_clk,
  input                         core_rst_n,
  input [16 : 0]                cfg_replay_timer_value, // Replay timer value
  input [2:0]                   current_data_rate,          // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
  xdlh_replay_timer_if.slave_mp b_replay,                   // Replay timer slave modport
  output logic                  replay_timeout_re           // Rising edge of replay timer expired
);

// Logic Declarations
logic [16 : 0]  replay_timer;
logic           replay_timer_expired;
logic           replay_timer_expired_d;
logic           timer2;

DWC_pcie_symbol_timer
 u_gen_timer2
(
     .core_clk          (core_clk)
    ,.core_rst_n        (core_rst_n)
    ,.current_data_rate (current_data_rate)
    ,.cnt_up_en         (timer2)      // timer count-up
);

// The following logic implements the replay timer
// 1. Start at end of TLP or end of Flit 
// 2. restart and reset the timer on each reply. Restart on the end of replayed TLP or flit 
// 3. ack received with forward progress, reset the replay timer
// 4. When replay timer expired or NACK received during non replay state, reset and hold the timer until reply with EOT
// 5. hold replay timer when LTSSM is in training
// 6. resets and hold when there is no outstanding unACKed TLPs
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        replay_timer       <= #TP 17'b0;
    else if (b_replay.replay_timer_start)
        replay_timer       <= #TP 17'b1;
    else if (b_replay.replay_timer_reset)
        replay_timer       <= #TP 17'b0 ;
    else if (b_replay.replay_timer_hold)
        replay_timer       <= #TP replay_timer;
    else if (replay_timer != 17'b0)
        replay_timer       <= #TP replay_timer + (timer2 ? 1 : 0);
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        replay_timer_expired    <= #TP 1'b0;
    end else if (b_replay.replay_ack) begin
        replay_timer_expired    <= #TP  1'b0;
    end else if (replay_timer >= cfg_replay_timer_value) begin
        replay_timer_expired    <= #TP 1'b1;
    end
end

// Request Replay when the timer expires
assign b_replay.replay_req = replay_timer_expired;

// registered version to use for a pulse to CDM for error reporting
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        replay_timer_expired_d  <= #TP 1'b0;
    end else begin
        replay_timer_expired_d  <= #TP replay_timer_expired;
    end
end

assign b_replay.replay_timer = replay_timer;
assign replay_timeout_re = replay_timer_expired & !replay_timer_expired_d;


endmodule
