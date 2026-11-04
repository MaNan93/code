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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/phy_if_cpcie.sv#13 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description: This module contains MUX logic on PHY interface
// outputs as well as the shadowing logic for state retention.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


 module phy_if_cpcie #(
    // Parameters
    parameter INST = 0,
    parameter PDWN_WIDTH = 2,
    parameter NL = 1,
    parameter PHY_NB = 1,
    parameter TX_COEF_WD = 18,
    parameter RX_PSET_WD = 3,
    parameter TX_FS_WD = 6,
    parameter TX_PSET_WD = 4,
    parameter TX_CRSR_WD = 6,
    parameter RX_PRESET_WD = NL * RX_PSET_WD,
    parameter FS_WD = NL * TX_FS_WD,
    parameter LF_WD = NL * TX_FS_WD,
    parameter PSET_INDEX_WD = NL * TX_PSET_WD,
    parameter V7_DEEMPH_WD = NL * TX_CRSR_WD,
    parameter PHY_RATE_WD = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 12 : 1,
    parameter PHY_WIDTH_WD = `CX_PHY_WIDTH_WD,
    parameter [(PDWN_WIDTH - 1) : 0] P1 = {PDWN_WIDTH{1'b0}},
    parameter ORIG_DATA_WD = PHY_NB * 8,
    parameter SERDES_DATA_WD = PHY_NB * 10,
    parameter PIPE_DATA_WD = (`CX_PIPE_SERDES_ARCH_VALUE) ? (NL * SERDES_DATA_WD) : (NL * ORIG_DATA_WD),
    parameter TX_DATAK_WD = NL * PHY_NB,
    parameter TX_DEEMPH_WD = 2,
    parameter PHY_TXEI_WD = `CX_PHY_TXEI_WD,
    parameter NL_X2 = NL * 2,
    parameter L2NL = 1,
    parameter P_R_WD = `PCLK_RATE_WD
    ,
    parameter PSET_ID_WD = `PSET_ID_WD * NL
) (
    // Inputs
    input                           clk,
    input                           rst_n,
    input                           hold_data,
    input                           update,
    input                           hold_perst,
    input                           update_perst,
    input [31:0]                    cfg_phy_control
    ,input                          cfg_comm_clk_config
    ,
    input                           mac_phy_rxelecidle_disable,
    input                           mac_phy_txcommonmode_disable
    ,
    input [(PDWN_WIDTH - 1) : 0]      mac_phy_powerdown,
    input [(NL*PHY_TXEI_WD - 1) : 0]  mac_phy_txelecidle
    ,
    input                           xmlh_sris_enable,
    input [(PIPE_DATA_WD - 1) : 0]    mac_phy_txdata,
    input [(NL - 1) : 0]            mac_phy_txdetectrx_loopback,
    input [(NL - 1) : 0]            mac_phy_txcompliance,
    input [(NL - 1) : 0]            mac_phy_rxpolarity,
    input [(PHY_WIDTH_WD - 1) : 0]  mac_phy_width,
    input                           mac_phy_serdes_arch,
    input [(PHY_WIDTH_WD - 1) : 0]  mac_phy_rxwidth,
    input [(NL - 1) : 0]            serdes_pipe_rxready,
    input [(NL - 1) : 0]            serdes_pipe_turnoff_lanes,
    input [P_R_WD-1 : 0]            mac_phy_pclk_rate,
    input [(NL - 1) : 0]            mac_phy_rxstandby,
    input [(NL - 1) : 0]            ltssm_rxpolarity
    ,
    input [(PHY_RATE_WD - 1) : 0]   mac_phy_rate,
    input [(TX_DEEMPH_WD - 1) : 0]  mac_phy_txdeemph
    ,
    input [(NL - 1) : 0]            mac_phy_txdatavalid
    ,
    input [(NL - 1) : 0]            mac_phy_rxeqeval,
    input [(NL - 1) : 0]            mac_phy_dirchange,
    input [(NL*TX_COEF_WD - 1) : 0] mac_phy_smlh_coef_rtx
    ,
    input [NL*8-1:0]                mac_phy_mbus
    ,
    input                           rx_lane_flip_en,
    input                           tx_lane_flip_en,
    input [L2NL-1:0]                smlh_lane_flip_ctrl
    // Outputs
    ,
    output wire [31:0]                      phy_if_cfg_phy_control
    ,
    output wire                             phy_if_cpcie_rxelecidle_disable,
    output wire                             phy_if_cpcie_txcommonmode_disable
    ,
    output wire [(PDWN_WIDTH - 1) : 0]      phy_if_cpcie_powerdown,
    output wire [(NL*PHY_TXEI_WD - 1) : 0]  phy_if_cpcie_txelecidle
    ,
    output wire                             phy_if_cpcie_xmlh_sris_enable,
    output wire [(PIPE_DATA_WD - 1) : 0]      phy_if_cpcie_txdata,
    output wire [(NL - 1) : 0]              phy_if_cpcie_txdetectrx_loopback,
    output wire [(NL - 1) : 0]              phy_if_cpcie_txcompliance,
    output wire [(NL - 1) : 0]              phy_if_cpcie_rxpolarity,
    output wire [(PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_width,
    output wire                             phy_if_cpcie_serdes_arch,
    output wire [(PHY_WIDTH_WD -1) : 0]     phy_if_cpcie_rxwidth,
    output wire [(NL - 1) : 0]              pm_serdes_pipe_rxready,
    output wire [(NL - 1) : 0]              pm_serdes_pipe_turnoff_lanes,
    output wire [P_R_WD-1 : 0]              phy_if_cpcie_pclk_rate,
    output wire [(NL - 1) : 0]              phy_if_cpcie_rxstandby
    ,
    output wire [(PHY_RATE_WD - 1) : 0]     phy_if_cpcie_rate,
    output wire [(TX_DEEMPH_WD - 1) : 0]    phy_if_cpcie_txdeemph
    ,
    output wire [(NL - 1) : 0]              phy_if_cpcie_txdatavalid
    ,
    output wire [(NL - 1) : 0]              phy_if_cpcie_rxeqeval,
    output wire [(NL - 1) : 0]              phy_if_cpcie_dirchange,
    output wire [(NL*TX_COEF_WD - 1) : 0]   phy_if_cpcie_smlh_coef_rtx
    ,
    output wire [NL*8-1:0]                  phy_if_cpcie_mbus
    ,
    output wire [L2NL - 1 : 0]              pm_rx_lane_flip_ctrl,
    output wire [L2NL - 1 : 0]              pm_tx_lane_flip_ctrl,
    output wire [L2NL - 1 : 0]              pm_rx_pol_lane_flip_ctrl
    ,output logic                           phy_if_cfg_comm_clk_config
);

// ----------------------------------------------------------------------------
// I/O assignments 
// ----------------------------------------------------------------------------
    assign phy_if_cpcie_rxelecidle_disable = mac_phy_rxelecidle_disable;
    assign phy_if_cpcie_txcommonmode_disable = mac_phy_txcommonmode_disable;
    assign phy_if_cpcie_powerdown = mac_phy_powerdown;
    assign phy_if_cpcie_txelecidle = mac_phy_txelecidle;
    assign phy_if_cpcie_txdata = mac_phy_txdata;
    assign phy_if_cpcie_dirchange = mac_phy_dirchange;
    assign phy_if_cpcie_rxeqeval = mac_phy_rxeqeval;
// ----------------------------------------------------------------------------
// PHY interface Shadowing
// ----------------------------------------------------------------------------
phy_if_cpcie_shadow
 #(
    // Parameters
    .INST           (INST),
    .NL             (NL),
    .TX_COEF_WD     (TX_COEF_WD),
    .RX_PSET_WD     (RX_PSET_WD),
    .TX_FS_WD       (TX_FS_WD),
    .TX_PSET_WD     (TX_PSET_WD),
    .TX_CRSR_WD     (TX_CRSR_WD),
    .RX_PRESET_WD   (RX_PRESET_WD),
    .FS_WD          (FS_WD),
    .LF_WD          (LF_WD),
    .PSET_INDEX_WD  (PSET_INDEX_WD),
    .V7_DEEMPH_WD   (V7_DEEMPH_WD),
    .PSET_ID_WD     (PSET_ID_WD),
    .TX_DEEMPH_WD   (TX_DEEMPH_WD),
    .PHY_RATE_WD    (PHY_RATE_WD),
    .PHY_WIDTH_WD   (PHY_WIDTH_WD),
    .NL_X2          (NL_X2)
) u_phy_if_cpcie_shadow (
    // Inputs
    .clk                                    (clk),
    .rst_n                                  (rst_n),
    .hold_data                              (hold_data),
    .update                                 (update),
    .hold_perst                             (hold_perst),
    .update_perst                           (update_perst)
    ,
    .cfg_phy_control                        (cfg_phy_control)
    ,.cfg_comm_clk_config                   (cfg_comm_clk_config)
    ,
    .xmlh_sris_enable                       (xmlh_sris_enable),
    .mac_phy_txdetectrx_loopback            (mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance                   (mac_phy_txcompliance),
    .mac_phy_rxpolarity                     (mac_phy_rxpolarity),
    .mac_phy_width                          (mac_phy_width),
    .mac_phy_serdes_arch                    (mac_phy_serdes_arch),
    .mac_phy_rxwidth                        (mac_phy_rxwidth),
    .serdes_pipe_rxready                    (serdes_pipe_rxready),
    .serdes_pipe_turnoff_lanes              (serdes_pipe_turnoff_lanes),
    .mac_phy_pclk_rate                      (mac_phy_pclk_rate),
    .mac_phy_rxstandby                      (mac_phy_rxstandby)
    ,
    .mac_phy_rate                           (mac_phy_rate),
    .mac_phy_txdeemph                       (mac_phy_txdeemph)
    ,
    .mac_phy_txdatavalid                    (mac_phy_txdatavalid)
    ,
    .mac_phy_smlh_coef_rtx                  (mac_phy_smlh_coef_rtx)
    ,
    .mac_phy_mbus                            (mac_phy_mbus)
    // Outputs
    ,
    .phy_if_cfg_phy_control                    (phy_if_cfg_phy_control)
    ,
    .phy_if_cpcie_xmlh_sris_enable             (phy_if_cpcie_xmlh_sris_enable),
    .phy_if_cpcie_shadow_txdetectrx_loopback   (phy_if_cpcie_txdetectrx_loopback),
    .phy_if_cpcie_shadow_txcompliance          (phy_if_cpcie_txcompliance),
    .phy_if_cpcie_shadow_rxpolarity            (phy_if_cpcie_rxpolarity),
    .phy_if_cpcie_shadow_width                 (phy_if_cpcie_width),
    .phy_if_cpcie_shadow_serdes_arch           (phy_if_cpcie_serdes_arch),
    .phy_if_cpcie_shadow_rxwidth               (phy_if_cpcie_rxwidth),
    .pm_shadow_serdes_pipe_rxready             (pm_serdes_pipe_rxready),
    .pm_shadow_serdes_pipe_turnoff_lanes       (pm_serdes_pipe_turnoff_lanes),
    .phy_if_cpcie_shadow_pclk_rate             (phy_if_cpcie_pclk_rate),
    .phy_if_cpcie_shadow_rxstandby             (phy_if_cpcie_rxstandby)
    ,
    .phy_if_cpcie_shadow_rate                  (phy_if_cpcie_rate),
    .phy_if_cpcie_shadow_txdeemph              (phy_if_cpcie_txdeemph)
    ,
    .phy_if_cpcie_shadow_txdatavalid           (phy_if_cpcie_txdatavalid)
    ,
    .phy_if_cpcie_shadow_smlh_coef_rtx         (phy_if_cpcie_smlh_coef_rtx)
    ,
    .phy_if_cpcie_shadow_mbus                  (phy_if_cpcie_mbus)
    ,.phy_if_cfg_comm_clk_config               (phy_if_cfg_comm_clk_config)
);

pm_lane_flip_ctrl
 #(
  .NL   (NL),
  .L2NL (L2NL)
) u_lane_flip_ctrl (
  // Inputs
  .aux_clk                    (clk),
  .pwr_rst_n                  (rst_n),
  .rx_lane_flip_en            (rx_lane_flip_en), 
  .tx_lane_flip_en            (tx_lane_flip_en),
  .smlh_lane_flip_ctrl        (smlh_lane_flip_ctrl),
  .mac_phy_rxpolarity         (ltssm_rxpolarity),
  .pm_update                  (update),
  .pm_hold                    (hold_data),
  // Outputs
  .pm_rx_lane_flip_ctrl       (pm_rx_lane_flip_ctrl),
  .pm_tx_lane_flip_ctrl       (pm_tx_lane_flip_ctrl),
  .pm_rx_pol_lane_flip_ctrl   (pm_rx_pol_lane_flip_ctrl)
);

endmodule
