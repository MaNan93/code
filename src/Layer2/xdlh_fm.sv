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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XDLH_FM
//
// Description: Implement Flit Mode Retry Logic. NOP Flit Generation.
// Flit Mode Transmitter Sequence Number. Flit Mode DLLP Generation.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xdlh_fm
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::fm_dllp_struct;
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::l0p_ack_struct;
  import cx_pl_pkg::P_NVC;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::CMD_IDLE;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
  import cx_pl_pkg::CMD_FLUSH_XAIM;
(
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                         core_clk,                 // Core clock
  input                         core_rst_n,               // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // XTLH Interface
  // -------------------------------------------------------------------------------------
  input tx_flit_struct          xtlh_xdlh_flit,           // XTLH Flit Interface 
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  input                         xplh_xdlh_halt,           // XPLH Halts the XDLH
  input                         xplh_xdlh_dllp_halt,      // Halt for DLLP interface
  output  logic                 xdlh_fm_dllp_valid,       // DLLP Data Valid to PLH
  output  fm_dllp_struct        xdlh_fm_dllp_out,         // DLLP
  input   tx_cmd_struct         xplh_xdlh_cmd,            // Command from lower layer
  // -------------------------------------------------------------------------------------
  // XDLH Interface
  // -------------------------------------------------------------------------------------
  output  tx_flit_struct        xdlh_fm_flit,             // Start of Flit Marker 
  output  logic                 xdlh_fm_halt,             // Back-pressure the XTLH while sending NOP Flits
  // -------------------------------------------------------------------------------------
  // FC DLLP Interface
  // -------------------------------------------------------------------------------------
  input   [P_NVC-1:0]           rtlh_fc_init_status,      // Report VC as ready for traffic
  input   dllp_struct           rtlh_xdlh_dllp,           // Layer3 FC DLLP Interface
  input                         rtlh_xdlh_opt_upd,        // Optimized update DLLP
  output  logic                 xdlh_fm_rtlh_ack,         // Layer3 DLLP Acknowledge
  output  logic [P_NVC-1:0]     xdlh_fm_fc_init_done,     // XDLH indicates that FC init is done
  output  logic                 xdlh_upd_fc_sent,         // Update FC sent FM
  // -------------------------------------------------------------------------------------
  // Power Management Interface
  // -------------------------------------------------------------------------------------
  output  logic                 xdlh_fm_dllp_pending,     // DLLP Pending
  input   dllp_struct           pm_xdlh_dllp,             // Power Management DLLP
  output  logic                 xdlh_fm_pm_ack,           // PM DLLP Ack
  // -------------------------------------------------------------------------------------
  // Vendor Specific DLLP Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct           cdm_xdlh_dllp,            // DLLP from CDM
  output  logic                 xdlh_fm_cdm_dllp_ack,     // CDM DLLP Sent
  // -------------------------------------------------------------------------------------
  // DL Feature DLLP Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct           dl_feature_dllp,          // DL Feature DLLP
  output  logic                 xdlh_fm_feature_dllp_ack, // CDM DLLP Sent
  // -------------------------------------------------------------------------------------
  // L0P Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct           xdlh_l0p_dllp,                // L0P DLLP
  output  l0p_ack_struct        xdlh_dllp_l0p_ack,            // Acknowledge the L0P DLLP has been Transmitted
  output  logic                 xplh_l0p_dllps_count,
  // -------------------------------------------------------------------------------------
  // Rate Information 
  // -------------------------------------------------------------------------------------
  input   [2 : 0]               current_data_rate
);

logic int_in_rcvry;
logic int_enter_low_power;

// Feedthrough signals to/from XTLH
assign xdlh_fm_flit = xtlh_xdlh_flit;
assign xdlh_fm_halt = xplh_xdlh_halt;

// LTSSM state decode
assign int_in_rcvry = (xplh_xdlh_cmd.tx_cmd == CMD_FLUSH_XTLH);
assign int_enter_low_power = (xplh_xdlh_cmd.tx_cmd == CMD_FLUSH_XAIM);

// -------------------------------------------------------------------------------------
// Flit Mode DLLP Generation
// -------------------------------------------------------------------------------------
xdlh_fm_dllp
 u_fm_dllp (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  // -------------------------------------------------------------------------------------
  // FC DLLP Interface
  // -------------------------------------------------------------------------------------
  .rtlh_fc_init_status          (rtlh_fc_init_status),
  .rtlh_xdlh_dllp               (rtlh_xdlh_dllp),
  .rtlh_xdlh_opt_upd            (rtlh_xdlh_opt_upd),
  .xdlh_fm_dllp_rtlh_ack        (xdlh_fm_rtlh_ack),
  .xdlh_fm_dllp_fc_init_done    (xdlh_fm_fc_init_done), 
  .xdlh_upd_fc_sent             (xdlh_upd_fc_sent),
  // -------------------------------------------------------------------------------------
  // Power Management Interface
  // -------------------------------------------------------------------------------------
  .xdlh_fm_dllp_pending         (xdlh_fm_dllp_pending),
  .pm_xdlh_dllp                 (pm_xdlh_dllp),
  .xdlh_fm_dllp_pm_ack          (xdlh_fm_pm_ack),
  // -------------------------------------------------------------------------------------
  // Vendor Specific DLLP Interface
  // -------------------------------------------------------------------------------------
  .cdm_xdlh_dllp                (cdm_xdlh_dllp),
  .xdlh_fm_dllp_cdm_ack         (xdlh_fm_cdm_dllp_ack),
  // -------------------------------------------------------------------------------------
  // DL Feature DLLP Interface
  // -------------------------------------------------------------------------------------
  .dl_feature_dllp              (dl_feature_dllp),
  .xdlh_fm_dllp_feature_ack     (xdlh_fm_feature_dllp_ack),
  // -------------------------------------------------------------------------------------
  // FLIT Interface
  // -------------------------------------------------------------------------------------
  .xdlh_fm_dllp_valid           (xdlh_fm_dllp_valid),
  .xdlh_fm_dllp_out             (xdlh_fm_dllp_out),
  .xplh_xdlh_dllp_halt          (xplh_xdlh_dllp_halt),
  .enter_low_power              (int_enter_low_power),
  .smlh_in_rcvry                (int_in_rcvry),
  // -------------------------------------------------------------------------------------
  // L0P Interface
  // -------------------------------------------------------------------------------------
  .xdlh_l0p_dllp                (xdlh_l0p_dllp),
  .xdlh_dllp_l0p_ack            (xdlh_dllp_l0p_ack),
  .xplh_l0p_dllps_count         (xplh_l0p_dllps_count),
  // -------------------------------------------------------------------------------------
  // Rate Information 
  // -------------------------------------------------------------------------------------
  .current_data_rate            (current_data_rate)
);


endmodule
