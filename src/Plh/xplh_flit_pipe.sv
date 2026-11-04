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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_flit_pipe.sv#4 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH Flit Pipeline 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xplh_flit_pipe
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::P_PROT_TYPE;
  import  cx_pl_pkg::P_PROT_RANGE;
  import  cx_pl_pkg::P_PARITY_MODE;
  import  cx_pl_pkg::P_PROT_CORRECT_EN;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter P_CAN_STALL = 0,
  parameter P_N_STAGES = 0
  ,
  parameter P_BUS_PROTECT_GEN_EN = 0,
  parameter P_BUS_PROTECT_CHK_EN = 0,
  parameter P_RAS_DP_PROT_CHK_ID_BASE = 0
) 
                       (
  input                     core_clk,                 // Core clock
  input                     core_rst_n,               // Core Reset
  input                     halt_in,                  // Halt In
  output  logic             xplh_flit_pipe_halt_out,  // Halt Out
  input                     clear,                    // Synchronous clear
  input   tx_flit_struct    flit_in,                  // Input Flit
  output  tx_flit_struct    xplh_flit_pipe_flit       // Output Flit
  ,
  output  ras_dp_err_log_t  xplh_flit_pipe_err_log    // RASDP Error Log
  ,
  input  ras_dp_err_inj_t   ras_dp_err_inj            // RASDP Error Injection
);

localparam P_FLIT_DATA_WD = $bits(flit_in.data);
localparam P_FLIT_PROT_WD = $bits(flit_in.flit_prot);
localparam P_WD = $bits(flit_in) - P_FLIT_DATA_WD - P_FLIT_PROT_WD - 1;
// RAS DP Generator
ras_dp_pipe
 #(
  .PIPELINE_TYPE           (2),
  .RESETVAL                (0),
  .N_STAGES                (P_N_STAGES),
  .CAN_STALL               (P_CAN_STALL),
  .RESET_STALL             (0),
  .BUS_PROTECT_GEN_EN      (P_BUS_PROTECT_GEN_EN),
  .BUS_PROTECT_CHK_EN      (P_BUS_PROTECT_CHK_EN),
  .PROT_TYPE               (P_PROT_TYPE),
  .PROT_RANGE              (P_PROT_RANGE),
  .PROT_WD                 (P_FLIT_PROT_WD),
  .PARITY_MODE             (P_PARITY_MODE),
  .PROT_CORRECT_EN         (P_PROT_CORRECT_EN),
  .TOTAL_WIDTH             (P_FLIT_DATA_WD),
  .EXCLUDE_PROT_WIDTH      (0),
  .RAS_DP_PROT_CHK_ID_BASE (0)
) u_xplh_data_pipe (
  .clk                        (core_clk),
  .rst_n                      (core_rst_n),
  .en                         (1'b1),
  .bypass                     (1'b0),
  .stall                      (halt_in),
  .stallout                   (xplh_flit_pipe_halt_out),
  .valid_in                   (flit_in.data_valid),
  .din                        (flit_in.data),
  .din_prot                   (flit_in.flit_prot),
  .halt_out                   (),
  
  .valid_out                  (),
  .dout                       (xplh_flit_pipe_flit.data),
  .dout_prot                  (xplh_flit_pipe_flit.flit_prot),
  .halt_in                    (1'b0),
  .ras_dp_err_inband_kbd_in   (flit_in.ras_dp_err_inband_kbd),
  .ras_dp_err_inband_kbd_out  (xplh_flit_pipe_flit.ras_dp_err_inband_kbd),
  .ras_dp_err_log             (xplh_flit_pipe_err_log)
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
);

delay_n_w_stalling
 #(
  .N          (P_N_STAGES),
  .CAN_STALL  (P_CAN_STALL),
  .WD         (P_WD)
) u_xplh_ctrl_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .stall      (halt_in),
  .clear      (clear),
  .din        ({flit_in.sof, flit_in.eof, flit_in.enf, flit_in.data_valid, flit_in.retry_flit, flit_in.expl_flit, flit_in.tlp_dv, flit_in.flit_type_s}),
  .dout       ({xplh_flit_pipe_flit.sof, xplh_flit_pipe_flit.eof, xplh_flit_pipe_flit.enf, xplh_flit_pipe_flit.data_valid,
                xplh_flit_pipe_flit.retry_flit, xplh_flit_pipe_flit.expl_flit, xplh_flit_pipe_flit.tlp_dv, xplh_flit_pipe_flit.flit_type_s}),
  .stallout   ()
);


endmodule
