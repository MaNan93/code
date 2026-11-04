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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fec.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module generates the FEC check and parity bytes for PCIe Gen6 Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"



module rplh_fec
  import cx_pl_pkg::P_FLIT_WD;

#(
  parameter   TP                = `TP,
  parameter   NL                = `CX_NL,                                  // Max number of lanes supported
  parameter   NB                = `CX_NB,                                  // Number of symbols (bytes) per clock cycle
  parameter   QDW               = (`CX_PL_NW<4)? 1 : `CX_PL_NW/4           // Number of 128-bit q-dwords handled by the datapath each clock.
) (
  // Inputs
  input                                   core_clk,
  input                                   core_rst_n,
  input [5:0]                             smlh_link_mode,                  // Link Width
  input                                   rxdata_vld,                      // rxdata_qdw_dv & search_for_tokens 
  input                                   rplh_flit_in_nxt_vld,            // Combinational version of accumulated flit is valid
  input  [P_FLIT_WD-1:0]                  rplh_flit_in_nxt,                // Combinational version of accumulated flit
  input  [P_FLIT_WD-1:0]                  rplh_flit_in,                    // Registered version of accumulated flit

  // Outputs
  output  logic [P_FLIT_WD - 48 - 1 : 0]  rplh_fec_data_out,               // FEC Decoder Data Out (after correction)
  output  logic                           rplh_fec_data_valid,             // FEC Data Valid
  output  logic                           rplh_fec_data_invalid,           // FEC Uncorrectable Error
  output  logic                           rplh_fec_corr_err,               // FEC correctable Error
  output  logic [2 : 0][7 : 0]            rplh_fec_synd_parity,            // FEC Parity Syndrome
  output  logic [2 : 0][7 : 0]            rplh_fec_synd_check,             // FEC Error Syndrome
  output  logic [15 : 0][3 : 0]           rplh_fec_even_b_err,             // Even corrected bit errors in FEC
  output  logic [15 : 0][3 : 0]           rplh_fec_odd_b_err               // Odd corrected bit errors in FEC

);

// Local Parameters
localparam P_DW_CNT = 16;
localparam P_DW_CNT_WD = $clog2(P_DW_CNT);
localparam P_FEC_PIPE_STAGES = 1;  // Additional register stage for FPGA configs

// Logic Declarations

logic [P_FLIT_WD - 1 : 0]       flit_r;

logic                           int_fec_check_r;
logic                           r_fec_check;
logic [P_FLIT_WD - 1 : 0]       int_flit_s;
logic [P_FLIT_WD - 1 : 0]       int_flit_r;
logic [P_FLIT_WD - 1 : 0]       r_flit;
logic                           int_en_fec_check_s;
logic                           int_data_valid_s;
logic                           int_fec_data_valid;
logic                           int_fec_data_invalid;
logic                           int_fec_corr_err;
logic  [2 : 0][7 : 0]           int_fec_synd_parity;
logic  [2 : 0][7 : 0]           int_fec_synd_check;
logic  [2 : 0][7 : 0]           int_fec_err_magnitude;
logic  [2 : 0][6 : 0]           int_fec_err_byte;
logic  [15 : 0][3 : 0]          int_fec_even_b_err;
logic  [15 : 0][3 : 0]          int_fec_odd_b_err;
logic                           int_en_fec_pipe;
logic [P_FLIT_WD - 48 - 1 : 0]  int_fec_data_out;

// Pipeline widths local parameter
localparam P_INT_FEC_VALID_PIPE_WD = $bits(rxdata_vld) + $bits(rplh_flit_in_nxt_vld);

// Added a pipeline stage before the decoder module to be synthesis friendly
delay_n

#(1, P_INT_FEC_VALID_PIPE_WD) u_int_fec_valid_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({rxdata_vld, rplh_flit_in_nxt_vld}),
    .dout   ({int_data_valid_s, int_en_fec_check_s})
);

delay_n_w_enable

#(1, $bits(rplh_flit_in_nxt)) u_int_fec_data_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .en     (rplh_flit_in_nxt_vld),
    .din    (rplh_flit_in_nxt),
    .dout   (int_flit_s)
);

delay_n_w_enable

#(1, $bits(rplh_flit_in)) u_int_fec_data_r_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .en     (int_en_fec_check_s),
    .din    (rplh_flit_in),
    .dout   (int_flit_r)
);

rplh_fec_dec
 u_rplh_fec_dec (
  // Inputs
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .smlh_link_mode         (smlh_link_mode),
  .data_valid             (int_data_valid_s),
  .r_flit_in              (int_flit_r),
  .s_flit_in              (int_flit_s),
  .en_check               (int_en_fec_check_s),
  // Outputs
  .fec_dec_uc_err         (rplh_fec_uc_err),
  .fec_dec_c_err          (rplh_fec_c_err),
  .fec_dec_synd_parity    (int_fec_synd_parity),
  .fec_dec_synd_check     (int_fec_synd_check),
  .fec_dec_err_magnitude  (int_fec_err_magnitude),
  .fec_dec_err_byte       (int_fec_err_byte),
  .fec_dec_even_b_err     (int_fec_even_b_err),
  .fec_dec_odd_b_err      (int_fec_odd_b_err),
  .fec_dec_data_out       (int_fec_data_out)
);

// Pipeline widths local parameter
localparam P_INT_FEC_PIPE_WD = $bits(int_en_fec_check_s) + $bits(int_fec_check_r);

// Added a pipeline stage after the decoder module to align the outputs with the added internal pipeline stage inside the decoder module
delay_n

#(1, P_INT_FEC_PIPE_WD) u_int_fec_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({int_en_fec_check_s, int_fec_check_r}),
    .dout   ({int_fec_check_r, r_fec_check})
);

delay_n_w_enable

#(1, $bits(int_flit_r)) u_int_fec_r_data_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .en     (int_fec_check_r),
    .din    (int_flit_r),
    .dout   (r_flit)
);

assign int_fec_data_valid = r_fec_check;
assign int_fec_data_invalid = r_fec_check && rplh_fec_uc_err;
assign int_fec_corr_err = r_fec_check && rplh_fec_c_err;

assign int_en_fec_pipe = int_fec_data_valid;

assign int_en_fec_pipe_out = int_en_fec_pipe;

// Pipeline widths local parameter
localparam P_FEC_PIPE_WD = $bits(int_fec_data_valid) + $bits(int_fec_data_invalid) + $bits(int_fec_corr_err) + $bits(int_fec_synd_parity) + $bits(int_fec_synd_check) + $bits(int_fec_even_b_err) + $bits(int_fec_odd_b_err);

// Added a pipeline stage at the output of the module
delay_n

#(P_FEC_PIPE_STAGES, P_FEC_PIPE_WD) u_fec_pipe_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({int_fec_data_valid, int_fec_data_invalid, int_fec_corr_err, int_fec_synd_parity, int_fec_synd_check, int_fec_even_b_err, int_fec_odd_b_err}),
    .dout   ({rplh_fec_data_valid, rplh_fec_data_invalid, rplh_fec_corr_err, rplh_fec_synd_parity, rplh_fec_synd_check, rplh_fec_even_b_err, rplh_fec_odd_b_err})
);

delay_n_w_enable

#(P_FEC_PIPE_STAGES, $bits(int_fec_data_out)) u_fec_pipe_data_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .en     (int_en_fec_pipe_out),
    .din    (int_fec_data_out),
    .dout   (rplh_fec_data_out)
);



endmodule
