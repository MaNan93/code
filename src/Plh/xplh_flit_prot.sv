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
// --- RCS information:
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_flit_prot.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module generates the CRC and FEC for the Flit.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xplh_flit_prot
  import cx_pl_pkg::tx_flit_struct;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP        = `TP
  ,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0
) 
                       (
  // Inputs
  input                       core_clk,
  input                       core_rst_n,
  input                       clear,                        // Synchronous reset
  input                       cxl_mode_enable,
  input                       halt_in,                    // Back pressure
  input   tx_flit_struct      flit_in,                    // Flit input
  input                       cmd_ack,                    // Command Acknowledge from upper layer
  // Outputs
  output  logic               xplh_flit_prot_crc_sof,       // SOF from CRC
  output  tx_flit_struct      xplh_flit_prot_flit,          // Flit Output
  output  logic               xplh_flit_prot_halt,          // Back-pressure
  output  logic               xplh_flit_prot_cmd_ack        // Command Acknowledge
  ,
  output                      xplh_rasdp_error              // XPLH RASDP Error driven from the last checker
  ,
  output  ras_dp_err_log_t    xplh_flit_prot_ras_dp_err_log // RASDP Error Logging
  ,
  input   ras_dp_err_inj_t    ras_dp_err_inj                // RASDP Error Injection
);

// Logic Declarations
tx_flit_struct      xplh_crc_flit;
logic               xplh_crc_cmd_ack;
logic               xplh_fec_halt;

assign xplh_flit_prot_crc_sof = xplh_crc_flit.sof;

// CRC Generation
xplh_crc
 #(
  .RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE)
) u_xplh_crc (
  // Inputs
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .clear                (clear),
  .cxl_mode_enable      (cxl_mode_enable),
  .halt_in              (xplh_fec_halt),
  .flit_in              (flit_in),
  .cmd_ack              (cmd_ack),
  // Outputs
  .xplh_crc_flit            (xplh_crc_flit),
  .xplh_crc_halt            (xplh_flit_prot_halt),
  .xplh_crc_cmd_ack         (xplh_crc_cmd_ack)
  ,
  .xplh_rasdp_error         (xplh_rasdp_error)
  ,
  .xplh_crc_ras_dp_err_log  (xplh_flit_prot_ras_dp_err_log)
  ,
  .ras_dp_err_inj           (ras_dp_err_inj)
);

// FEC Generation
xplh_fec
 u_xplh_fec (
  // Inputs
  .core_clk             (core_clk),
  .core_rst_n           (core_rst_n),
  .clear                (clear),
  .halt_in              (halt_in),
  .flit_in              (xplh_crc_flit),
  .cmd_ack              (xplh_crc_cmd_ack),
  // Outputs
  .xplh_fec_flit        (xplh_flit_prot_flit),
  .xplh_fec_halt        (xplh_fec_halt),
  .xplh_fec_cmd_ack     (xplh_flit_prot_cmd_ack)
);

endmodule
