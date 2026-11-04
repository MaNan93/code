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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_common.sv#4 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// --- This module contains logic which is used in both Flit Mode and Non-Flit Mode.
// --- Replay Timer
// --- Replay Event Counter
// --- Retrain Event Counter
// --- This module also implements MUX/DEMUX logic to select between Flit Mode
// --- and non-Flit Mode interface signals.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module xdlh_common #(
  parameter NW = `CX_NW,
  parameter DW = 32 * NW
) (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                         core_clk,
  input                         core_rst_n,
  // -------------------------------------------------------------------------------------
  // CDM Interface
  // -------------------------------------------------------------------------------------
  input [16 : 0]                cfg_replay_timer_value,   // Replay timer value
  // -------------------------------------------------------------------------------------
  // Layer1 Interface
  // -------------------------------------------------------------------------------------
  input [2 : 0]                 current_data_rate,        // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
  // -------------------------------------------------------------------------------------
  // Replay Timer Interface
  // -------------------------------------------------------------------------------------
  input                         rdlh_link_up,             // DL_UP indication
  xdlh_replay_timer_if.slave_mp b_xdlh_replay,            // Replay Timer Interface from xdlh
  //xdlh_replay_timer_if.slave_mp b_xdlh_fm_replay        // Replay Timer Interface from xdlh_fm
  xdlh_replay_num_if.slave_mp   b_xdlh_replay_num,        // Replay Timeout Event Counter
  xdlh_retrain_cnt_if.slave_mp  b_xdlh_retrain_cnt,       // XDLH Retrain Event Counter
  output logic                  xdlh_replay_timeout,      // Indicates that the replay timer expired
  output logic  [16 : 0]        xdlh_replay_timer_value   // Replay timer
  // -------------------------------------------------------------------------------------
  // Flit Mode Interface
  // -------------------------------------------------------------------------------------
  ,
  input                         flit_mode_enable          // Indicates Flit Mode is enabled
);

// Replay Timer Interface
xdlh_replay_timer_if b_replay();
xdlh_replay_num_if b_replay_num();
xdlh_retrain_cnt_if b_retrain_cnt();

// XDLH MUX
xdlh_mux_demux
 u_mux_demux(
  .b_xdlh_replay            (b_xdlh_replay),
  .b_mux_replay             (b_replay.master_mp),
  .b_xdlh_replay_num        (b_xdlh_replay_num),
  .b_mux_replay_num         (b_replay_num.master_mp)
  ,
  .b_xdlh_retrain_cnt       (b_xdlh_retrain_cnt),
  .b_mux_retrain_cnt        (b_retrain_cnt.master_mp)
  ,
  .flit_mode_enable         (flit_mode_enable)
);

// Instantiate the replay timer
xdlh_replay_timer
 u_replay_timer(
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .cfg_replay_timer_value     (cfg_replay_timer_value),
  .current_data_rate          (current_data_rate),
  .b_replay                   (b_replay.slave_mp),
  .replay_timeout_re          (xdlh_replay_timeout)
);

assign xdlh_replay_timer_value = b_xdlh_replay.replay_timer;

// Instantiate the replay timeout event counter
xdlh_replay_num
 u_replay_num(
  .core_clk     (core_clk),
  .core_rst_n   (core_rst_n),
  .rdlh_link_up (rdlh_link_up),
  .b_replay_num (b_replay_num.slave_mp)
);

// Instantiate the retrain counter
xdlh_retrain_cnt
 u_retraint_cnt(
  .core_clk       (core_clk),
  .core_rst_n     (core_rst_n),
  .b_retrain_cnt  (b_retrain_cnt.slave_mp)
);

endmodule
