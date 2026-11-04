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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_mux_demux.sv#3 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// --- Mux to select inputs from Flit mode or non-flit mode XDLH 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_mux_demux #(
  parameter NW          = `CX_NW,
  parameter DW          = (32*NW)
) (
  xdlh_replay_timer_if.slave_mp   b_xdlh_replay,            // XDLH Replay Timer Interface
  xdlh_replay_timer_if.master_mp  b_mux_replay,             // Muxed Replay Timer Interface
  xdlh_replay_num_if.slave_mp     b_xdlh_replay_num,        // XDLH Replay Timer Interface
  xdlh_replay_num_if.master_mp    b_mux_replay_num          // Muxed Replay Timer Interface
  ,
  xdlh_retrain_cnt_if.slave_mp    b_xdlh_retrain_cnt,       // XDLH Retrain Counter Interface
  xdlh_retrain_cnt_if.master_mp   b_mux_retrain_cnt         // Muxed Retrain Counter Interface
  // Flit Interface
  ,
  input                           flit_mode_enable          // Flit Mode Enabled
);

// MUX between flit mode and non-flit mode signals
always_comb begin : xdlh_mux_proc
  // In flit mode connect to the interface from xdlh_fm
  if (flit_mode_enable) begin
    // REPLAY TIMER INTERFACE
    b_mux_replay.replay_timer_start = 1'b0;
    b_mux_replay.replay_timer_hold = 1'b0;
    b_mux_replay.replay_timer_reset = 1'b0;
    b_mux_replay.replay_ack = 1'b0;
    // REPLAY NUM INTERFACE
    b_mux_replay_num.replay_num_incr = 1'b0;
    b_mux_replay_num.replay_num_reset = 1'b0;
    b_mux_replay_num.replay_num_retrain_ack = 1'b0;
    // RETRAIN COUNTER INTERFACE
    b_mux_retrain_cnt.retrain_cnt_incr = 1'b0;
    b_mux_retrain_cnt.retrain_cnt_reset = 1'b0;
  // In non-flit mode connect to the interface from xdlh
  end else begin
    // REPLAY TIMER INTERFACE
    b_mux_replay.replay_timer_start = b_xdlh_replay.replay_timer_start;
    b_mux_replay.replay_timer_hold = b_xdlh_replay.replay_timer_hold;
    b_mux_replay.replay_timer_reset = b_xdlh_replay.replay_timer_reset;
    b_mux_replay.replay_ack = b_xdlh_replay.replay_ack;
    // REPLAY NUM INTERFACE
    b_mux_replay_num.replay_num_incr = b_xdlh_replay_num.replay_num_incr;
    b_mux_replay_num.replay_num_reset = b_xdlh_replay_num.replay_num_reset;
    b_mux_replay_num.replay_num_retrain_ack = b_xdlh_replay_num.replay_num_retrain_ack;
    // RETRAIN COUNTER INTERFACE
    b_mux_retrain_cnt.retrain_cnt_incr = b_xdlh_retrain_cnt.retrain_cnt_incr;
    b_mux_retrain_cnt.retrain_cnt_reset = b_xdlh_retrain_cnt.retrain_cnt_reset;
  end
end : xdlh_mux_proc

// DEMUX between flit mode and non-flit mode signals
always_comb begin : xdlh_demux_proc
  // In Flit Mode drive xdlh_fm interface
  if (flit_mode_enable) begin
    // REPLAY TIMER INTERFACE
    b_xdlh_replay.replay_req = 1'b0;
    b_xdlh_replay.replay_timer = 'h0;
    // REPLAY NUM INTERFACE
    b_xdlh_replay_num.replay_num_retrain_req = 1'b0;
    b_xdlh_replay_num.replay_num = 'h0;
    // RETRAIN COUNTER INTERFACE
    b_xdlh_retrain_cnt.retrain_cnt = 'h0;
  end
  // In Non-Flit Mode drive xdlh interface
  else begin
    // REPLAY TIMER INTERFACE
    b_xdlh_replay.replay_req = b_mux_replay.replay_req;
    b_xdlh_replay.replay_timer = b_mux_replay.replay_timer;
    // REPLAY NUM INTERFACE
    b_xdlh_replay_num.replay_num_retrain_req = b_mux_replay_num.replay_num_retrain_req;
    b_xdlh_replay_num.replay_num = b_mux_replay_num.replay_num;
    // RETRAIN COUNTER INTERFACE
    b_xdlh_retrain_cnt.retrain_cnt = b_mux_retrain_cnt.retrain_cnt;
  end
end : xdlh_demux_proc

endmodule

