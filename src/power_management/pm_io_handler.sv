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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_io_handler.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module handles the power management between top level input/output pin.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


module pm_io_handler
    // Parameters
    #(
        parameter TP = `TP
    )
    (
    // Inputs
    input                aux_clk,
    input                pwr_rst_n,
    input                app_sris_mode,              // Application signal to enable the SRIS mode
    input                xmlh_sris_enable,           // Internal SRIS setting which is decided by TS OS negotiation
    input                pm_perst_powerdown,         // Indicate to drive specific powerdown for perst rst
    // Outputs
    output logic         pm_io_handler_app_sris_mode, // Registered app_sris_mode
    output logic         pm_io_handler_sris_enable    // Used to tell the PHY to configure itself to support SRIS mode.
);

logic            pre_pm_io_handler_sris_enable;
assign pre_pm_io_handler_sris_enable = pm_io_handler_app_sris_mode | xmlh_sris_enable ;

// Reset value is 1b because PIPE output mac_phy_sris_enable default value will be 1b
delay_n

#(.N(1),.RESETVAL('1)) u_delay_app_sris_mode (
    .clk   (aux_clk),
    .rst_n (pwr_rst_n),
    .clear (pm_perst_powerdown),
    .din   (app_sris_mode),
    .dout  (pm_io_handler_app_sris_mode)
);

// Reset value is 1b because PIPE output mac_phy_sris_enable default value will be 1b
delay_n

#(.N(1),.RESETVAL('1)) u_delay_pm_io_handler_sris_enable (
    .clk   (aux_clk),
    .rst_n (pwr_rst_n),
    .clear (1'b0),
    .din   (pre_pm_io_handler_sris_enable),
    .dout  (pm_io_handler_sris_enable)
);

endmodule
