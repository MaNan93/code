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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_err_inj_ctrl.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// --- This is the error injection control which is 
// --- responsible for determining the tlp_type to be ready with the data 
// --- at the sof if error Injection Extended Capability is Enabled 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"


module xtlh_err_inj_ctrl 
  import  cx_pl_pkg::flit_type_struct;
  import  xtlh_ms_pkg::flit_marker_struct;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  xtlh_ms_pkg::P_NW_PROT;

                          (
  input                                     core_clk,
  input                                     core_rst_n,
  input                                     flit_gen_en,                // FLIT GENERATION Enable
  input                                     spif_enable,                // SPIF Interface Enable
  input                                     cdm_err_inj_en,             // Error Injection Enable
  input                                     cdm_tx_err_inj_en,          // Transmit Path Error Injection Enable
  input   [P_NW - 1 : 0]                    sot,                        // INPUT Start of TLP
  input   [P_NW_CNT_WD-1:0]                 next_sot_cnt,
  input   [P_NW - 1 : 0]                    eot,                        // INPUT End of TLP
  input   [P_DW - 1 : 0]                    data,                       // INPUT DATA
  input   flit_marker_struct  [P_NW-1:0]    flit_marker,                // INPUT Flit Marker
  input                                     dv,                         // INPUT Data Valid
  input                                     halt_in,                    // Downstream halt
  input                                     sof,                        // Start of Flit
  input   [1 : 0]                           eof,                        // End of Flit
  input                                     flit_tlp_dv,                // FLIT Data Valid
  output  logic    [P_NW - 1 : 0]           xtlh_err_inj_sot,           // OUTPUT Start of TLP
  output  logic    [P_NW_CNT_WD - 1 : 0]    xtlh_err_inj_next_sot_cnt,  // OUTPUT Start of TLP
  output  logic    [P_NW - 1 : 0]           xtlh_err_inj_eot,           // OUTPUT End of TLP
  output  logic    [P_DW - 1 : 0]           xtlh_err_inj_data,          // OUTPUT DATA
  output  flit_marker_struct  [P_NW-1:0]    xtlh_err_inj_flit_marker,   // OUTPUT Flit Marker
  output  logic                             xtlh_err_inj_dv,            // OUTPUT Data Vaild
  output  logic                             xtlh_err_inj_halt,          // OUTPUT Halt OUT to the Upstream Module
  output  flit_type_struct                  xtlh_err_inj_flit_type      // OUTPUT Flit Type
  ,
  input                                     ras_dp_err_inband_kbd,              // Input ras_dp_err_inband_kbd
  output logic                              xtlh_err_inj_ras_dp_err_inband_kbd, // Output ras_dp_err_inband_kbd
  input   [P_NW_PROT-1:0]                   prot,                               // Input protection
  output  [P_NW_PROT-1:0]                   xtlh_err_inj_prot                   // Output protection
);

logic             pop_n;          // Active Low Pop Signal
logic             push;           // Active High Push Signal
logic             bypass_pipe;    // Bypass Mux Selection Signal
logic             pipe_dv;        // Pipe Data Valid

//-------------------------------\\
//-----Datapath Instatiation-----\\
//-------------------------------\\
xtlh_err_inj_ctrl_dp
 u_xtlh_err_inj_ctrl_dp (
        .core_clk                           (core_clk),
        .core_rst_n                         (core_rst_n),
        .push                               (push),
        .pop_n                              (pop_n),
        .sot                                (sot),
        .next_sot_cnt                       (next_sot_cnt),
        .eot                                (eot),
        .data                               (data),
        .flit_marker                        (flit_marker),
        .bypass_pipe                        (bypass_pipe),
        .pipe_dv                            (pipe_dv),
        .xtlh_err_inj_next_sot_cnt          (xtlh_err_inj_next_sot_cnt),
        .xtlh_err_inj_sot                   (xtlh_err_inj_sot),
        .xtlh_err_inj_eot                   (xtlh_err_inj_eot),
        .xtlh_err_inj_data                  (xtlh_err_inj_data),
        .xtlh_err_inj_flit_marker           (xtlh_err_inj_flit_marker),
        .xtlh_err_inj_dv                    (xtlh_err_inj_dv)
        ,
        .prot                               (prot),
        .xtlh_err_inj_prot                  (xtlh_err_inj_prot), 
        .ras_dp_err_inband_kbd              (ras_dp_err_inband_kbd),                                                    
        .xtlh_err_inj_ras_dp_err_inband_kbd (xtlh_err_inj_ras_dp_err_inband_kbd)                                                       
);


//-------------------------------\\
//--------FSM Instatiation-------\\
//-------------------------------\\
xtlh_err_inj_ctrl_fsm
 u_xtlh_err_inj_ctrl_fsm (
        .core_clk           (core_clk),
        .core_rst_n         (core_rst_n),
        .flit_gen_en        (flit_gen_en),
        .spif_enable        (spif_enable),
        .cdm_err_inj_en     (cdm_err_inj_en),
        .cdm_tx_err_inj_en  (cdm_tx_err_inj_en),
        .dv                 (dv),
        .sof                (sof),
        .eof                (eof),
        .flit_tlp_dv        (flit_tlp_dv),
        .halt_in            (halt_in),
        .pipe_dv            (pipe_dv),
        .push               (push),
        .pop_n              (pop_n),
        .bypass_pipe        (bypass_pipe),
        .flit_type_str      (xtlh_err_inj_flit_type),
        .xtlh_err_inj_dv    (xtlh_err_inj_dv),
        .xtlh_err_inj_halt  (xtlh_err_inj_halt)
);

endmodule
