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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_pclkchange_ctrl.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module provides control logic for pclk change, for PCLK as PHY input.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module pm_pclkchange_ctrl #(
    // module parameter port list
    parameter INST              = 0,
    parameter P_R_WD            = `PCLK_RATE_WD,
    parameter PHY_RATE_WD       = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1,
    parameter NL                = `CX_NL
)
(
    input                aux_clk,
    input                pipe_clk,
    input                pwr_rst_n,
    input                perst_n,
// ---- inputs ---------------
    input [NL-1:0]       pm_lane_active,
    input [NL-1:0]       phy_mac_pclkchangeok,
    input [NL-1:0]       phy_mac_phystatus,
    input [P_R_WD-1 : 0] phy_if_cpcie_pclk_rate,
    input [(PHY_RATE_WD - 1) : 0] phy_if_cpcie_rate,
    input                pm_req_phy_rst,
    input                link_req_rst_not,
    input                phystatus_done_auxclk,
    input                pm_pipe_optional_pclkchange_hs,
    input                pclk_hs_rst, 
// ---- outputs ---------------
    output logic [6:0]   pm_div_max_pclk_ratio,
    output logic [NL-1:0] mac_phy_pclkchangeack
);
pm_pclkchange_fsm

  // Parameters
  #(
    .P_R_WD      (P_R_WD),
    .PHY_RATE_WD (PHY_RATE_WD),
    .NL          (NL    )
  ) u_pm_pclkchange_fsm (
    // Inputs
    .aux_clk                        (aux_clk               ),
    .pipe_clk                       (pipe_clk              ),
    .pwr_rst_n                      (pwr_rst_n             ),
    .perst_n                        (perst_n               ),
    .pm_lane_active                 (pm_lane_active        ),
    .phy_mac_pclkchangeok           (phy_mac_pclkchangeok  ),
    .phy_mac_phystatus              (phy_mac_phystatus     ),
    .phy_if_cpcie_pclk_rate         (phy_if_cpcie_pclk_rate),
    .phy_if_cpcie_rate              (phy_if_cpcie_rate     ),
    .pm_req_phy_rst                 (pm_req_phy_rst        ),
    .link_req_rst_not               (link_req_rst_not      ),
    .phystatus_done                 (phystatus_done_auxclk ),
    .pm_pipe_optional_pclkchange_hs (pm_pipe_optional_pclkchange_hs),
    .pclk_hs_rst                    (pclk_hs_rst), 
    // Outputs
    .pm_div_max_pclk_ratio          (pm_div_max_pclk_ratio ),
    .mac_phy_pclkchangeack          (mac_phy_pclkchangeack )
  );
endmodule
