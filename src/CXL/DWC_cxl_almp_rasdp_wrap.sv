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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_almp_rasdp_wrap.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL TX ALMP RASDP Wrapper (for almp tx generator)
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_almp_rasdp_wrap
  import DWC_cxl_pkg::*;
#(
  parameter TP              = `TP
) (
  input                            core_clk,
  input                            core_rst_n,
  input                            almp_io_valid_i,
  input [127:0]                    almp_io_data_i,
  input                            almp_mc_valid_i,
  input [127:0]                    almp_mc_data_i,
  //outputs
  output logic                     almp_io_valid_o,
  output logic [127:0]             almp_io_data_o,
  output logic [ALMP_PROT_W-1:0]   almp_io_data_chk_o,
  output logic                     almp_mc_valid_o,
  output logic [127:0]             almp_mc_data_o,
  output logic [ALMP_PROT_W-1:0]   almp_mc_data_chk_o
);

// -------------------------------------------------------------------------------------
// RASDP Generator for TX IO ALMP
// -------------------------------------------------------------------------------------
DWC_cxl_almp_tx_rasdp
 u_DWC_cxl_almp_tx_rasdp_io (
  .core_clk          ( core_clk           ),
  .core_rst_n        ( core_rst_n         ),
  .almp_valid_i      ( almp_io_valid_i    ),
  .almp_data_i       ( almp_io_data_i     ),
  .almp_valid_o      ( almp_io_valid_o    ),
  .almp_data_o       ( almp_io_data_o     ),
  .almp_data_chk     ( almp_io_data_chk_o ),
  .almp_rasdp_err    (                    ) //open
);

// -------------------------------------------------------------------------------------
// RASDP Generator for TX MC ALMP
// -------------------------------------------------------------------------------------
DWC_cxl_almp_tx_rasdp
 u_DWC_cxl_almp_tx_rasdp_cm (
  .core_clk          ( core_clk           ),
  .core_rst_n        ( core_rst_n         ),
  .almp_valid_i      ( almp_mc_valid_i    ),
  .almp_data_i       ( almp_mc_data_i     ),
  .almp_valid_o      ( almp_mc_valid_o    ),
  .almp_data_o       ( almp_mc_data_o     ),
  .almp_data_chk     ( almp_mc_data_chk_o ),
  .almp_rasdp_err    (                    ) //open
);


endmodule
