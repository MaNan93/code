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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_almp_tx_rasdp.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL ALMP TX RASDP Generator
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_almp_tx_rasdp
  import  DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) (

  input                           core_clk,
  input                           core_rst_n,
  input                           almp_valid_i,
  input  [127:0]                  almp_data_i,
  output                          almp_valid_o,
  output logic [127:0]            almp_data_o,
  output logic [ALMP_PROT_W-1:0]  almp_data_chk,
  output logic                    almp_rasdp_err
);

// -------------------------------------------------------------------------------------
// RAS DP Generator to ARB/MUX, only supported for 256B flit
// -------------------------------------------------------------------------------------
localparam P_BUS_PROTECT_GEN_EN          = 1;

ras_dp_pipe
 #(
  .PIPELINE_TYPE           (6), //new pipe for ras
  .RESETVAL                (0),
  .N_STAGES                (0),
  .CAN_STALL               (0),
  .RESET_STALL             (0),
  .BUS_PROTECT_GEN_EN      (P_BUS_PROTECT_GEN_EN),
  .BUS_PROTECT_CHK_EN      (0),
  .PROT_TYPE               (CX_CXL_PROT_TYPE),
  .PROT_RANGE              (CX_CXL_PROT_RANGE),
  .PROT_WD                 (ALMP_PROT_W),
  .PARITY_MODE             (CX_CXL_PARITY_MODE),
  .PROT_CORRECT_EN         (0),
  .TOTAL_WIDTH             (128),
  .EXCLUDE_PROT_WIDTH      (0),
  .RAS_DP_PROT_CHK_ID_BASE (0)
) u_vlsm_rasdp_gen (
  .clk                        ( core_clk       ),
  .rst_n                      ( core_rst_n     ),
  .en                         ( 1'b1           ),
  .bypass                     ( 1'b0           ),
  .stall                      ( 1'b0           ),
  .stallout                   (                ),
  .valid_in                   ( almp_valid_i   ),
  .din                        ( almp_data_i    ),
  .din_prot                   ('0              ),
  .halt_out                   (),
  
  .valid_out                  ( almp_valid_o   ),
  .dout                       ( almp_data_o    ),
  .dout_prot                  ( almp_data_chk  ),
  .halt_in                    ( 1'b0           ),
  .ras_dp_err_inband_kbd_in   ( 1'b0           ),
  .ras_dp_err_inband_kbd_out  ( almp_rasdp_err ),
  .ras_dp_err_log             (                ) //open
  ,
  .ras_dp_err_inj             ('0)
);

endmodule
