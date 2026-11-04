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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/gasket_ctrl.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains PIPE 4.3 gasket. 
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module gasket_ctrl
#(
  parameter PDWN_WIDTH  = 4,       // powerdown bit width
  parameter P0          = {PDWN_WIDTH{1'b0}},
  parameter P1          = (P0 + 2'b10),
  parameter P2          = (P1 + 1'b1),
  parameter P1CPM       = (P2 + 1'b1),
  parameter P1_1        = (P2 + 2'b10),
  parameter P1_2        = (P2 + 2'b11),
  parameter NL          = `CX_NL,  // max lane number supported
  parameter TP          = `TP      // Clock to Q delay (simulator insurance)
)

                   (
//--------------------- Inputs -----------------------
input                             aux_clk,
input                             pwr_rst_n,
input      [(PDWN_WIDTH - 1) : 0] pm_powerdown,
input      [NL-1:0]               phystatus,
input                             l1sub_exit,
input      [NL-1:0]               pm_lane_active,
input                             l1sub_l11_next,
input                             l1sub_l12_next,
input                             l1sub_l1_u_next,
input                             l1sub_abort_next,
input                             pm_l1sub_clk_req_n,
input      [1:0]                  cfg_trgt_l1sub,
input                             cfg_trgt_l1cpm,
input      [1:0]                  aux_sync_p1_ack,
input      [1:0]                  phystatus_pc_busy,
input                             pm_linkst_l23rdy,
input                             pm_req_exit_l1,
input                             pm_linkst_in_l1,
input                             smlh_in_l1,
input                             pm_req_exit_p2,
input [(PDWN_WIDTH - 1) : 0]      pm_cfg_phy_powerdown_p2_options,
input                             perst_n,
input                             cfg_pl_l1sub_fast_exit,
input                             l1sub_req_p1cpm,
input                             phy_mac_maxpclkack_n,
input                             phystatus_done_auxclk,
input                             aux_clk_active,
input                             pm_perst_powerdown,
//--------------------- Outputs -----------------------
output wire                       pclkack_n, //goto PM
output wire                       pclkreq_n, //goto clk_rst
output wire                       asyncpowerchangeack, //goto top level
output wire                       gasket_pg_ack,
output wire                       gasket_rxelecidle_disable,
output wire                       gasket_txcommonmode_disable,
output wire [(PDWN_WIDTH - 1) : 0] powerdown,
output wire                       gasket_drive_pd,
output wire                       gasket_drive_pd_no_clk, // powerdown is P1CPM, P1_1 or P1_2, in which ref clk will be removed
output wire                       gasket_block_phystatus, // block the detection of phystatus in rmlh_pipe block
                                                         // this is necessary to prevent update of current_powerdown
output wire [1:0]                 gasket_en_pulse_det, // Enable the PHYSTATUS pulse detection circuit
output wire                       gasket_sel_aux_clk // Allow switching of aux_clk when P1.CPM, P1.1, P1.2
,
output wire                       mac_phy_maxpclkreq_n,
output wire                       gasket_maxpclk_removed,
output wire                       gasket_maxpclk_back_on
);

localparam SYNC_DEPTH  = `CX_PCIE_SYNC_DEPTH;

assign int_trgt_l1sub = !(cfg_trgt_l1sub == 0);
assign int_trgt_l1cpm = !(cfg_trgt_l1cpm == 0);

DWC_pcie_powerdown_fsm

  // Parameters
  #(
    .PDWN_WIDTH  (PDWN_WIDTH),
    .P0          (P0),
    .P1          (P1),
    .P2          (P2),
    .P1CPM       (P1CPM),
    .P1_1        (P1_1),
    .P1_2        (P1_2)
  ) u_powerdown_fsm (
    // Inputs
    .aux_clk                        (aux_clk),
    .pwr_rst_n                      (pwr_rst_n),
    .p1cpm_hs_done                  (pd_p1cpm_hs_done),
    .l1sub_exit_next                (l1sub_exit),
    .trgt_l1sub                     (int_trgt_l1sub),
    .trgt_l1cpm                     (int_trgt_l1cpm),
    .pm_linkst_in_l1                (pm_linkst_in_l1),
    .pm_linkst_l23rdy               (pm_linkst_l23rdy),
    .pm_req_exit_l1                 (pm_req_exit_l1),
    .smlh_in_l1                     (smlh_in_l1),
    .pm_req_exit_p2                 (pm_req_exit_p2),
    .p1_hs_done                     (pd_p1_hs_done),
    .cfg_pl_l1sub_fast_exit         (cfg_pl_l1sub_fast_exit),
    .l1sub_req_p1cpm                (l1sub_req_p1cpm),
    .p2_hs_done                     (phystatus_done_auxclk),
    .aux_clk_active                 (aux_clk_active),
    .pd_maxpclkack_n_rise_det       (pd_maxpclkack_n_rise_det),
    .pd_maxpclkack_n_fall_det       (pd_maxpclkack_n_fall_det),
    .pm_perst_powerdown             (pm_perst_powerdown),
    .pm_cfg_phy_powerdown_p2_options (pm_cfg_phy_powerdown_p2_options),
    .l1sub_l1_u_next                (l1sub_l1_u_next),
    .l1sub_l11_next                 (l1sub_l11_next),
    .l1sub_l12_next                 (l1sub_l12_next),
    .l1sub_abort_next               (l1sub_abort_next),
    .pm_l1sub_clk_req_n             (pm_l1sub_clk_req_n),
    .aux_sync_phystatus             (pd_hs_phystatus),
    .aux_sync_phystatus_low         (pd_hs_phystatus_low),
    .pm_powerdown                   (pm_powerdown),
    .perst_n                        (perst_n),
    // Outputs
    .pd_fsm_prev_p0_r               (pd_fsm_prev_p0),
    .pd_fsm_pclkack_n_r             (pclkack_n),
    .pd_fsm_pclkreq_n_r             (pclkreq_n),
    .pd_fsm_powerdown_r             (powerdown),
    .pd_fsm_drive_pd_r              (gasket_drive_pd),
    .pd_fsm_block_phystatus_r       (gasket_block_phystatus),
    .pd_fsm_en_pulse_det_r          (gasket_en_pulse_det),
    .pd_fsm_powerdown_p1            (pd_fsm_powerdown_p1),
    .pd_fsm_powerdown_no_clk        (gasket_drive_pd_no_clk)
    ,
    .pd_fsm_pg_ack_r                (gasket_pg_ack),
    .pd_fsm_rxelecidle_disable_r    (gasket_rxelecidle_disable),
    .pd_fsm_txcommonmode_disable_r  (gasket_txcommonmode_disable)
    ,
    .pd_fsm_asyncpowerchange_ack_r  (asyncpowerchangeack),
    .pd_fsm_en_async_hs_r           (pd_fsm_en_async_hs)
    ,
    .pd_fsm_sel_aux_clk_r           (gasket_sel_aux_clk)
    ,
    .mac_phy_maxpclkreq_n           (mac_phy_maxpclkreq_n),
    .pd_fsm_maxpclk_removed         (gasket_maxpclk_removed),
    .pd_fsm_maxpclk_back_on         (gasket_maxpclk_back_on)
);

DWC_pcie_powerdown_hs

  // Parameters
  #(
    .PM_SYNC_DEPTH (SYNC_DEPTH),
    .NL (NL)
  ) u_powerdown_hs (
    .aux_clk                  (aux_clk),
    .pwr_rst_n                (pwr_rst_n),
    .aux_sync_phystatus_pulse (aux_sync_p1_ack),
    .phy_mac_phystatus        (phystatus),
    .phystatus_pc_busy        (phystatus_pc_busy),
    .en_pulse_det             (gasket_en_pulse_det),
    .prev_p0                  (pd_fsm_prev_p0),
    .powerdown_p1             (pd_fsm_powerdown_p1),
    .pm_lane_active           (pm_lane_active),
    .phy_mac_maxpclkack_n     (phy_mac_maxpclkack_n),
    .en_async_hs              (pd_fsm_en_async_hs),
    // Outputs
    .pd_hs_phystatus_r        (pd_hs_phystatus),
    .pd_hs_phystatus_low      (pd_hs_phystatus_low),
    .pd_p1cpm_hs_done         (pd_p1cpm_hs_done),
    .pd_p1_hs_done            (pd_p1_hs_done)
    ,
    .pd_maxpclkack_n_rise_det (pd_maxpclkack_n_rise_det),
    .pd_maxpclkack_n_fall_det (pd_maxpclkack_n_fall_det)
);


endmodule
