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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_arbmux.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: CXL ARB/MUX
// -----------------------------------------------------------------------------
// --- This module contains CXL ARB/MUX and vLSM
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module cx_arbmux 
    import DWC_cxl_pkg::vlsm_debug_t;
    import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
    import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter   TP            = `TP       // Clock to Q delay (simulator insurance)
) (
// ----------------------------------------------------------------------------
// Interfaces
// ----------------------------------------------------------------------------
    spif_if.master_mp          b_vlsm_llctrl_mc,             // Link Layer to VLSM SPIF Interface for CXL.cachemem
    spif_if.master_mp          b_vlsm_llctrl_io,             // Link Layer to VLSM SPIF Interface for CXL.io
    spif_if.slave_mp           b_vlsm_splh_spif,             // VLSM to SPLH SPIF Interface
// ----------------------------------------------------------------------------
// Clock and Reset
// ----------------------------------------------------------------------------
    input                      core_clk,
    input                      core_rst_n,
// ----------------------------------------------------------------------------
// Configuration Interface
// ----------------------------------------------------------------------------
    input                      cfg_pm_timeout_enable,        // ARB/MUX PM Timeout Control Register - PM Timeout Enable
    input  [1:0]               cfg_pm_timeout_value,         // ARB/MUX PM Timeout Control Register - PM Timeout Value
    output                     cfg_pm_timeout_error,         // ARB/MUX Uncorrectable Error Status Register - PM Timeout Error
    input                      cfg_vlsm_force_active,        // Force VLSM State to ACTIVE
    input                      cfg_vlsm_pm_enable,           // Enable Low Power mode Entry handshake
    input  [3:0]               cfg_cxl_io_arb_weight,        // CXL.io Weighted Round Robin Arbitration Weight
    input  [3:0]               cfg_cxl_mc_arb_weight,        // CXL.cache and CXL.mem Weighted Round Robin Arbitration Weight
// ----------------------------------------------------------------------------
// Power Management Application Interface
// ----------------------------------------------------------------------------
    input                      vlsm_io_tx_pm_nak,            // vLSM.io transmit Status(Active.PMNAK) ALMP
    input                      vlsm_mc_tx_pm_nak,            // vLSM.mc transmit Status(Active.PMNAK) ALMP
    output                     vlsm_io_rx_pm_nak,            // vLSM.io received Status(Active.PMNAK) ALMP
    output                     vlsm_mc_rx_pm_nak,            // vLSM.mc received Status(Active.PMNAK) ALMP
    output                     vlsm_io_rx_pm_req,            // vLSM.io PM Request ALMP received
    output                     vlsm_mc_rx_pm_req,            // vLSM.mc PM Request ALMP received
    output                     vlsm_io_pm_timeout,           // vLSM.io PM Request ALMP timeout
    output                     vlsm_mc_pm_timeout,           // vLSM.mc PM Request ALMP timeout
// ----------------------------------------------------------------------------
// RASDP Interface
// ----------------------------------------------------------------------------
    input  ras_dp_err_inj_t    ras_dp_err_inj,               // Rx ALMP checker RASDP error injection
    output ras_dp_err_log_t    vlsm_rasdp_err_log,           // Rx ALMP checker RASDP error log
// ----------------------------------------------------------------------------
// Interface with Reset module
// ----------------------------------------------------------------------------
    output logic               vlsm_ltssm_enable,            // Enable core_rst_n assertion
// ----------------------------------------------------------------------------
// vLSM Debug Interface
// ----------------------------------------------------------------------------
    output vlsm_debug_t        vlsm_debug_info               // VLSM Debug Information
);

// --------------------------------------------------------------------------------------
// CXL VLSM Instantiation
// --------------------------------------------------------------------------------------
DWC_cxl_vlsm
 u_cxl_vlsm (
    .b_vlsm_llctrl_mc              ( b_vlsm_llctrl_mc            ),
    .b_vlsm_llctrl_io              ( b_vlsm_llctrl_io            ),
    .b_vlsm_splh_spif              ( b_vlsm_splh_spif            ),
    .core_clk                      ( core_clk                    ),
    .core_rst_n                    ( core_rst_n                  ),
    // Configuration Interface
    .cfg_pm_timeout_enable         ( cfg_pm_timeout_enable       ),
    .cfg_pm_timeout_value          ( cfg_pm_timeout_value        ),
    .cfg_pm_timeout_error          ( cfg_pm_timeout_error        ),
    .cfg_vlsm_force_active         ( cfg_vlsm_force_active       ),
    .cfg_vlsm_pm_enable            ( cfg_vlsm_pm_enable          ),
    .cfg_cxl_io_arb_weight         ( cfg_cxl_io_arb_weight       ),
    .cfg_cxl_mc_arb_weight         ( cfg_cxl_mc_arb_weight       ),
    // Power Management Application Interface
    .vlsm_io_tx_pm_nak             ( vlsm_io_tx_pm_nak           ),
    .vlsm_mc_tx_pm_nak             ( vlsm_mc_tx_pm_nak           ),
    .vlsm_io_rx_pm_nak             ( vlsm_io_rx_pm_nak           ),
    .vlsm_mc_rx_pm_nak             ( vlsm_mc_rx_pm_nak           ),
    .ras_dp_err_inj                ( ras_dp_err_inj              ),
    .vlsm_rasdp_err_log            ( vlsm_rasdp_err_log          ),
    .vlsm_io_rx_pm_req             ( vlsm_io_rx_pm_req           ),
    .vlsm_mc_rx_pm_req             ( vlsm_mc_rx_pm_req           ),
    .vlsm_io_pm_timeout            ( vlsm_io_pm_timeout          ),
    .vlsm_mc_pm_timeout            ( vlsm_mc_pm_timeout          ),
    .vlsm_ltssm_enable             ( vlsm_ltssm_enable           ),
    .vlsm_debug_info               ( vlsm_debug_info             )
);

endmodule // cx_arbmux
