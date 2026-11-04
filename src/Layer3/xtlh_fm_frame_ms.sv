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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_fm_frame_ms.sv#9 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// XTLH Multistream Architecture
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_fm_frame_ms
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::tx_cmd_struct;
  import  xtlh_ms_pkg::flit_marker_struct;
  import  xtlh_ms_pkg::P_XTLH_MAX_TLP_CNT_WD;
  import  xtlh_ms_pkg::tlp_end_struct;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  cx_pl_pkg::flit_type_struct;
  import  xtlh_ms_pkg::P_NW_PROT;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
      import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter RAS_DP_PROT_CHK_ID_BASE = 0
) 
                         (
  input                                     core_clk,
  input                                     core_rst_n,
  input                                     halt_in,
  input   tx_cmd_struct                     xdlh_xtlh_cmd,      // Command interface
  input                                     flit_mode_en,
  input   [P_NW_CNT_WD - 1 : 0]             next_sot_cnt,
  input                                     spif_enable,
  input                                     cdm_err_inj_en,
  input                                     cdm_tx_err_inj_en,
  input   [P_DW-1:0]                        data_in,
  input                                     data_valid,
  input   [P_NW-1:0]                        sot,
  input   [P_NW-1:0]                        eot,
  input                                     rstctl_core_flush_req,
  input   logic                             ras_dp_err_inband_kbd,
  input                  [P_NW_PROT-1:0]    prot,
  input   flit_marker_struct  [P_NW-1:0]    flit_marker,
  output  tx_flit_struct                    xtlh_fm_frame_flit,
  output  logic                             xtlh_fm_frame_halt,
  output  logic                             xtlh_fm_frame_marker_sent,
  output  logic                             xtlh_fm_frame_tlp_pending,
  output  logic                             xtlh_fm_frame_nop_ack,
  output  logic [P_XTLH_MAX_TLP_CNT_WD-1:0] xtlh_fm_frame_eot_cnt,
  output  logic [P_XTLH_MAX_TLP_CNT_WD-1:0] xtlh_fm_frame_over_cnt,
  output  tlp_end_struct                    xtlh_fm_frame_tlp_end
      ,
      input  ras_dp_err_inj_t               ras_dp_err_inj
    ,  
  output ras_dp_err_log_t     ras_dp_err_log
);

tx_flit_struct                  int_fm_shift_flit;
logic                           int_nop_halt;
logic               [P_NW-1:0]  int_fm_frame_eot;
logic                           xtlh_err_inj_dv;
logic                           sof;
logic               [1:0]       eof;
logic               [P_NW-1:0]  xtlh_err_inj_sot;
logic    [P_NW_CNT_WD - 1 : 0]  xtlh_err_inj_next_sot_cnt;
logic               [P_NW-1:0]  xtlh_err_inj_eot;
flit_marker_struct  [P_NW-1:0]  xtlh_err_inj_flit_marker;
logic               [P_DW-1:0]  xtlh_err_inj_data;
flit_type_struct                xtlh_err_inj_flit_type;
logic                           xtlh_fm_shift_halt;
logic                           flit_tlp_dv;
logic                           xtlh_err_inj_ras_dp_err_inband_kbd; 
logic          [P_NW_PROT-1:0]  xtlh_err_inj_prot;
logic                           stallout_unused;
logic                           halt_out_unused;
logic                           valid_out_unused;
logic          [P_NW_PROT-1:0]  prot_unused;
logic               [P_DW-1:0]  int_rasdp_data;

assign sof         = int_fm_shift_flit.sof;
assign eof         = int_fm_shift_flit.eof;
assign flit_tlp_dv = int_fm_shift_flit.tlp_dv;

xtlh_err_inj_ctrl
 u_xtlh_err_inj_ctrl (
  .core_clk                           (core_clk),
  .core_rst_n                         (core_rst_n),
  .flit_gen_en                        (int_flit_gen_en),
  .spif_enable                        (spif_enable),
  .cdm_err_inj_en                     (cdm_err_inj_en),
  .cdm_tx_err_inj_en                  (cdm_tx_err_inj_en),
  .data                               (data_in),
  .sot                                (sot),
  .next_sot_cnt                       (next_sot_cnt),
  .eot                                (eot),
  .flit_marker                        (flit_marker),
  .dv                                 (data_valid),
  .halt_in                            (xtlh_fm_shift_halt),
  .sof                                (sof),
  .eof                                (eof),
  .flit_tlp_dv                        (flit_tlp_dv),
  .xtlh_err_inj_data                  (xtlh_err_inj_data),
  .xtlh_err_inj_sot                   (xtlh_err_inj_sot),
  .xtlh_err_inj_next_sot_cnt          (xtlh_err_inj_next_sot_cnt),
  .xtlh_err_inj_eot                   (xtlh_err_inj_eot),
  .xtlh_err_inj_flit_marker           (xtlh_err_inj_flit_marker),
  .xtlh_err_inj_dv                    (xtlh_err_inj_dv),
  .xtlh_err_inj_halt                  (xtlh_fm_frame_halt),
  .xtlh_err_inj_flit_type             (xtlh_err_inj_flit_type)
  ,
  .prot                               (prot),
  .xtlh_err_inj_prot                  (xtlh_err_inj_prot), 
  .ras_dp_err_inband_kbd              (ras_dp_err_inband_kbd),                                                    
  .xtlh_err_inj_ras_dp_err_inband_kbd (xtlh_err_inj_ras_dp_err_inband_kbd)
);


localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

ras_dp_pipe
 #(
  .PIPELINE_TYPE           (6),
  .N_STAGES                (0),
  .CAN_STALL               (0),
  .BUS_PROTECT_GEN_EN      (0),
  .BUS_PROTECT_CHK_EN      (1),
  .PROT_TYPE               (PROT_TYPE),
  .PROT_RANGE              (PROT_RANGE),
  .PROT_WD                 (P_NW_PROT),
  .PARITY_MODE             (PARITY_MODE),
  .PROT_CORRECT_EN         (PROT_CORRECT_EN),
  .TOTAL_WIDTH             (P_DW),
  .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
) u_ras_dp_pipe (
  .clk                       (core_clk),
  .rst_n                     (core_rst_n),
  .en                        (1'b1),
  .bypass                    (1'b0),
  .stall                     (1'b0),
  .stallout                  (stallout_unused),
  .din_prot                  (xtlh_err_inj_prot),
  .valid_in                  (xtlh_err_inj_dv),
  .din                       (xtlh_err_inj_data),
  .ras_dp_err_inband_kbd_in  (xtlh_err_inj_ras_dp_err_inband_kbd),
  .halt_out                  (halt_out_unused),
  .valid_out                 (valid_out_unused),
  .dout                      (int_rasdp_data),
  .dout_prot                 (prot_unused),
  .halt_in                   (1'b0)
  ,
  .ras_dp_err_inband_kbd_out (ras_dp_err_inband_kbd_out),
  .ras_dp_err_log            (ras_dp_err_log)
  ,
  .ras_dp_err_inj            (ras_dp_err_inj)
  );


always_comb begin : tlp_end_PROC
  xtlh_fm_frame_tlp_end = '0;
  if(!int_nop_halt)
    xtlh_fm_frame_tlp_end.eot = int_fm_frame_eot;
end : tlp_end_PROC

// FLit Framing Logic
xtlh_fm_shift_ms
 u_xtlh_fm_shift_ms(
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .xdlh_xtlh_cmd              (xdlh_xtlh_cmd),
  .flit_mode_en               (flit_mode_en),
  .spif_enable                (spif_enable),
  .flit_gen_en                (int_flit_gen_en),
  .data                       (int_rasdp_data),
  .flit_type                  (xtlh_err_inj_flit_type),
  .dv                         (xtlh_err_inj_dv),
  .sot                        (xtlh_err_inj_sot),
  .next_sot_cnt               (xtlh_err_inj_next_sot_cnt),
  .eot                        (xtlh_err_inj_eot),
  .flit_marker                (xtlh_err_inj_flit_marker),
  .xtlh_fm_shift_halt         (xtlh_fm_shift_halt),
  .halt_in                    (int_nop_halt),
  .xtlh_fm_shift_tlp_pending  (xtlh_fm_frame_tlp_pending),
  .xtlh_fm_shift_flit         (int_fm_shift_flit),
  .xtlh_fm_shift_marker_sent  (xtlh_fm_frame_marker_sent),
  .xtlh_fm_shift_eot          (int_fm_frame_eot),
  .xtlh_fm_shift_eot_cnt      (xtlh_fm_frame_eot_cnt),
  .xtlh_fm_shift_over_cnt     (xtlh_fm_frame_over_cnt)
    ,
    .ras_dp_err_inband_kbd    (ras_dp_err_inband_kbd_out)
      ,
      .ras_dp_err_inj         (ras_dp_err_inj)
);

// NOP Generator
xtlh_fm_nop_gen
 u_xtlh_fm_nop_gen (
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .xdlh_xtlh_cmd          (xdlh_xtlh_cmd),
  .xtlh_flit_in           (int_fm_shift_flit),
  .flit_mode_en           (flit_mode_en),
  .halt_in                (halt_in),
  .xtlh_fm_nop_flit       (xtlh_fm_frame_flit),
  .xtlh_fm_nop_halt       (int_nop_halt),
  .xtlh_fm_nop_ack        (xtlh_fm_frame_nop_ack),
  .xtlh_fm_nop_pyld_en    (int_flit_gen_en)
  ,
  .rstctl_core_flush_req  (rstctl_core_flush_req),
  .spif_enable            (spif_enable)
);

endmodule
