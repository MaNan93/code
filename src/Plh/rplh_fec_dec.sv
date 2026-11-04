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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fec_dec.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module generates the FEC check and parity bytes for PCIe Gen6 Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module rplh_fec_dec
  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_N_SYMBOLS;
  import cx_pl_pkg::interleave_data_t;
  import cx_pl_pkg::interleave_data;
  import cx_pl_pkg::even_odd_c_errs;
  import cx_pl_pkg::interleave_errors;
#(
  parameter TP = `TP
) 
                     (
  // Inputs
  input                                   core_clk,
  input                                   core_rst_n,
  input [5:0]                             smlh_link_mode,         // Link Width
  input                                   data_valid,             // Received Data is valid
  input [P_FLIT_WD - 1 : 0]               r_flit_in,              // Registered Full Received FLIT
  input [P_FLIT_WD - 1 : 0]               s_flit_in,              // Full Received FLIT
  input                                   en_check,               // Perform the FEC check
  // Outputs
  output  logic                           fec_dec_uc_err,         // Uncorrectable error detected 
  output  logic                           fec_dec_c_err,          // Correctable error detected 
  output  logic [P_FLIT_WD - 48 - 1 : 0]  fec_dec_data_out,       // FEC Decoder Data Out (after correction)
  output  logic [2 : 0][7 : 0]            fec_dec_synd_parity,    // FEC Parity Syndrome
  output  logic [2 : 0][7 : 0]            fec_dec_synd_check,     // FEC Error Syndrome
  output  logic [2 : 0][7 : 0]            fec_dec_err_magnitude,  // FEC Parity Syndrome
  output  logic [2 : 0][6 : 0]            fec_dec_err_byte,       // FEC Error Syndrome
  output  logic [15 : 0][3 : 0]           fec_dec_even_b_err,     // FEC Even corrected bit errors in FEC
  output  logic [15 : 0][3 : 0]           fec_dec_odd_b_err       // FEC Odd corrected bit errors in FEC
);

// Logic Declarations
logic [7 : 0] s_fec0_in [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec1_in [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec2_in [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec0_data_accum [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec1_data_accum [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec2_data_accum [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec2_data_out [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec1_data_out [P_N_SYMBOLS - 1 : 0];
logic [7 : 0] s_fec0_data_out [P_N_SYMBOLS - 1 : 0];
logic         r_en_check;
logic [P_FLIT_WD - 48 - 1 : 0] s_fec_dec_data_out;
logic [7 : 0] s_rec_fec0;
logic [7 : 0] s_rec_fec1;
logic [7 : 0] s_rec_fec2;
logic [7 : 0] s_rec_parity0;
logic [7 : 0] s_rec_parity1;
logic [7 : 0] s_rec_parity2;
logic [2 : 0][7 : 0] s_fec_dec_synd_parity;
logic [2 : 0][7 : 0] s_fec_dec_synd_check;
logic [2 : 0][7 : 0] s_fec_dec_err_magnitude;
logic [2 : 0][6 : 0] s_fec_dec_err_byte;
logic         s_fec0_single_err;
logic         s_fec1_single_err;
logic         s_fec2_single_err;
logic         s_fec0_mult_err;
logic         s_fec1_mult_err;
logic         s_fec2_mult_err;
logic [2 : 0] s_fec0_dec_even_b_err;
logic [2 : 0] s_fec1_dec_even_b_err;
logic [2 : 0] s_fec2_dec_even_b_err;
logic [2 : 0] s_fec0_dec_odd_b_err;
logic [2 : 0] s_fec1_dec_odd_b_err;
logic [2 : 0] s_fec2_dec_odd_b_err;
logic         r_fec0_single_err;
logic         r_fec1_single_err;
logic         r_fec2_single_err;
logic         r_fec0_mult_err;
logic         r_fec1_mult_err;
logic         r_fec2_mult_err;
logic [2 : 0] r_fec0_dec_even_b_err;
logic [2 : 0] r_fec1_dec_even_b_err;
logic [2 : 0] r_fec2_dec_even_b_err;
logic [2 : 0] r_fec0_dec_odd_b_err;
logic [2 : 0] r_fec1_dec_odd_b_err;
logic [2 : 0] r_fec2_dec_odd_b_err;
even_odd_c_errs even_odd_c_errs0;
even_odd_c_errs even_odd_c_errs1;
even_odd_c_errs even_odd_c_errs2;

// Interleave the Data over the three FEC blocks
always_comb begin : interleave_PROC
  s_fec0_in = interleave_data(s_flit_in, 0); // blue
  s_fec1_in = interleave_data(s_flit_in, 1); // orange
  s_fec2_in = interleave_data(s_flit_in, 2); // green
  s_fec0_data_accum = interleave_data(r_flit_in, 0);
  s_fec1_data_accum = interleave_data(r_flit_in, 1);
  s_fec2_data_accum = interleave_data(r_flit_in, 2);
end : interleave_PROC

// Instantiate the FEC 86 to 84 Byte Decoders
rplh_fec_86to84_dec
 u_fec0_dec (
  // Inputs
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .data_in                (s_fec0_in),
  .data_valid             (data_valid),
  .data_accum             (s_fec0_data_accum),
  .check_in               (s_rec_fec0),
  .parity_in              (s_rec_parity0),
  .en_check               (en_check),
  // Outputs
  .fec_dec_data_out       (s_fec0_data_out),
  .fec_dec_synd_parity    (s_fec_dec_synd_parity[0]),
  .fec_dec_synd_check     (s_fec_dec_synd_check[0]),
  .fec_dec_err_magnitude  (s_fec_dec_err_magnitude[0]),
  .fec_dec_err_byte       (s_fec_dec_err_byte[0]),
  .fec_dec_single_err     (s_fec0_single_err),
  .fec_dec_multiple_err   (s_fec0_mult_err),
  .fec_dec_even_b_err     (s_fec0_dec_even_b_err),
  .fec_dec_odd_b_err      (s_fec0_dec_odd_b_err)
);

// Instantiate the FEC 86 to 84 Byte Decoders
rplh_fec_86to84_dec
 u_fec1_dec (
  // Inputs
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .data_in                (s_fec1_in),
  .data_valid             (data_valid),
  .data_accum             (s_fec1_data_accum),
  .check_in               (s_rec_fec1),
  .parity_in              (s_rec_parity1),
  .en_check               (en_check),
  // Outputs
  .fec_dec_data_out       (s_fec1_data_out),
  .fec_dec_synd_parity    (s_fec_dec_synd_parity[1]),
  .fec_dec_synd_check     (s_fec_dec_synd_check[1]),
  .fec_dec_err_magnitude  (s_fec_dec_err_magnitude[1]),
  .fec_dec_err_byte       (s_fec_dec_err_byte[1]),
  .fec_dec_single_err     (s_fec1_single_err),
  .fec_dec_multiple_err   (s_fec1_mult_err),
  .fec_dec_even_b_err     (s_fec1_dec_even_b_err),
  .fec_dec_odd_b_err      (s_fec1_dec_odd_b_err)
);

// Instantiate the FEC 86 to 84 Byte Decoders
rplh_fec_86to84_dec
 u_fec2_dec (
  // Inputs
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .data_in                (s_fec2_in),
  .data_valid             (data_valid),
  .data_accum             (s_fec2_data_accum),
  .check_in               (s_rec_fec2),
  .parity_in              (s_rec_parity2),
  .en_check               (en_check),
  // Outputs
  .fec_dec_data_out       (s_fec2_data_out),
  .fec_dec_synd_parity    (s_fec_dec_synd_parity[2]),
  .fec_dec_synd_check     (s_fec_dec_synd_check[2]),
  .fec_dec_err_magnitude  (s_fec_dec_err_magnitude[2]),
  .fec_dec_err_byte       (s_fec_dec_err_byte[2]),
  .fec_dec_single_err     (s_fec2_single_err),
  .fec_dec_multiple_err   (s_fec2_mult_err),
  .fec_dec_even_b_err     (s_fec2_dec_even_b_err),
  .fec_dec_odd_b_err      (s_fec2_dec_odd_b_err)
);

// Pipeline widths local parameters
localparam P_FEC_DEC_PIPE_WD = $bits(s_fec_dec_synd_parity) + $bits(s_fec_dec_synd_check) + $bits(s_fec_dec_err_magnitude) + $bits(s_fec_dec_err_byte);
localparam P_FEC0_DEC_PIPE_WD = $bits(s_fec0_single_err) + $bits(s_fec0_mult_err) + $bits(s_fec0_dec_even_b_err) + $bits(s_fec0_dec_odd_b_err);
localparam P_FEC1_DEC_PIPE_WD = $bits(s_fec1_single_err) + $bits(s_fec1_mult_err) + $bits(s_fec1_dec_even_b_err) + $bits(s_fec1_dec_odd_b_err);
localparam P_FEC2_DEC_PIPE_WD = $bits(s_fec2_single_err) + $bits(s_fec2_mult_err) + $bits(s_fec2_dec_even_b_err) + $bits(s_fec2_dec_odd_b_err);

// Added an internal pipeline stage to be synthesis friendly
delay_n

#(1, P_FEC_DEC_PIPE_WD) u_fec_dec_pipe_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({s_fec_dec_synd_parity, s_fec_dec_synd_check, s_fec_dec_err_magnitude, s_fec_dec_err_byte}),
    .dout   ({fec_dec_synd_parity, fec_dec_synd_check, fec_dec_err_magnitude, fec_dec_err_byte})
);

delay_n

#(1, P_FEC0_DEC_PIPE_WD) u_fec0_dec_pipe_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({s_fec0_single_err, s_fec0_mult_err, s_fec0_dec_even_b_err, s_fec0_dec_odd_b_err}),
    .dout   ({r_fec0_single_err, r_fec0_mult_err, r_fec0_dec_even_b_err, r_fec0_dec_odd_b_err})
);

delay_n

#(1, P_FEC1_DEC_PIPE_WD) u_fec1_dec_pipe_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({s_fec1_single_err, s_fec1_mult_err, s_fec1_dec_even_b_err, s_fec1_dec_odd_b_err}),
    .dout   ({r_fec1_single_err, r_fec1_mult_err, r_fec1_dec_even_b_err, r_fec1_dec_odd_b_err})
);

delay_n

#(1, P_FEC2_DEC_PIPE_WD) u_fec2_dec_pipe_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    ({s_fec2_single_err, s_fec2_mult_err, s_fec2_dec_even_b_err, s_fec2_dec_odd_b_err}),
    .dout   ({r_fec2_single_err, r_fec2_mult_err, r_fec2_dec_even_b_err, r_fec2_dec_odd_b_err})
);

assign fec_dec_uc_err = r_fec2_mult_err || r_fec1_mult_err || r_fec0_mult_err;
assign fec_dec_c_err  = r_fec2_single_err || r_fec1_single_err || r_fec0_single_err;

// Extract the Parity and Check Bytes from the received flit
assign s_rec_parity0  = r_flit_in[(P_FLIT_WD - 1)        -: 8];
assign s_rec_parity2  = r_flit_in[((P_FLIT_WD - 8) - 1)  -: 8];
assign s_rec_parity1  = r_flit_in[((P_FLIT_WD - 16) - 1) -: 8];
assign s_rec_fec0     = r_flit_in[((P_FLIT_WD - 24) - 1) -: 8];
assign s_rec_fec2     = r_flit_in[((P_FLIT_WD - 32) - 1) -: 8];
assign s_rec_fec1     = r_flit_in[((P_FLIT_WD - 40) - 1) -: 8];

// Interleave errors per lane from the three FEC blocks
always_comb begin : interleave_errors_PROC
  even_odd_c_errs0 = interleave_errors(r_fec0_dec_even_b_err, r_fec0_dec_odd_b_err, smlh_link_mode, fec_dec_err_byte[0][6:0], 2'b00); // blue
  even_odd_c_errs1 = interleave_errors(r_fec1_dec_even_b_err, r_fec1_dec_odd_b_err, smlh_link_mode, fec_dec_err_byte[1][6:0], 2'b01); // orange
  even_odd_c_errs2 = interleave_errors(r_fec2_dec_even_b_err, r_fec2_dec_odd_b_err, smlh_link_mode, fec_dec_err_byte[2][6:0], 2'b10); // green
end : interleave_errors_PROC

genvar j;
// Unpack the interleaved data output from the FEC to generated the data vector
generate
  for(j = 1; j <= P_N_SYMBOLS; j = j + 1)
  begin : gen_data_out_PROC
    if(j == 84) begin
      assign s_fec_dec_data_out[1999 : 1992] = s_fec0_data_out[83];
    end else begin
      assign s_fec_dec_data_out[(24 * j) - 1 : (24 * (j - 1))] = {s_fec2_data_out[j - 1], s_fec1_data_out[j - 1], s_fec0_data_out[j - 1]};
    end
  end
endgenerate

always_ff @(posedge core_clk or negedge core_rst_n) begin : en_check_reg_PROC
  if(!core_rst_n) begin
    r_en_check <= #TP 1'b0;
  end else begin
    r_en_check <= #TP en_check;
  end
end : en_check_reg_PROC

delay_n_w_enable

#(1, $bits(s_fec_dec_data_out)) u_fec_dec_pipe_data_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .en     (r_en_check),
    .din    (s_fec_dec_data_out),
    .dout   (fec_dec_data_out)
);

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: In this code the range of values in the right hand side will not cause an overflow.
genvar i;
generate
for (i=0; i<16 ; i = i+1) begin
assign fec_dec_even_b_err[i] = {1'b0,even_odd_c_errs0.fec_dec_even_b_err[i]} + {1'b0,even_odd_c_errs1.fec_dec_even_b_err[i]} + {1'b0,even_odd_c_errs2.fec_dec_even_b_err[i]};
assign fec_dec_odd_b_err[i]  = {1'b0,even_odd_c_errs0.fec_dec_odd_b_err[i]} + {1'b0,even_odd_c_errs1.fec_dec_odd_b_err[i]} + {1'b0,even_odd_c_errs2.fec_dec_odd_b_err[i]};
end
endgenerate
// spyglass enable_block W164a

endmodule
