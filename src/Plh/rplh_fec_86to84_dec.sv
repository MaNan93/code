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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fec_86to84_dec.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module generates the FEC check and parity bytes for PCIe Gen6 Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module rplh_fec_86to84_dec
  import cx_pl_pkg::P_N_SYMBOLS;
  import cx_pl_pkg::P_INV_FEC;
#(
  parameter TP = `TP
) 
                            (
  // Inputs
  input                 core_clk,
  input                 core_rst_n,
  input [7 : 0]         data_in [P_N_SYMBOLS - 1 : 0],          // Received data
  input                 data_valid,                             // Received data is valid  
  input [7 : 0]         data_accum [P_N_SYMBOLS - 1 : 0],       // Received data accumulated over full flit
  input [7 : 0]         check_in,                               // Received ECC byte
  input [7 : 0]         parity_in,                              // Received parity byte
  input                 en_check,                               // Enable the FEC check on the end of Flit
  // Outputs
  output logic [7 : 0]  fec_dec_data_out [P_N_SYMBOLS - 1 : 0], // Corrected data
  output logic [7:0]    fec_dec_synd_parity,                    // FEC decoder parity syndrome
  output logic [7:0]    fec_dec_synd_check,                     // FEC decoder check
  output logic [7:0]    fec_dec_err_magnitude,                  // Error magnitude
  output logic [6:0]    fec_dec_err_byte,                       // Error location
  output logic          fec_dec_single_err,                     // FEC decoder detected single byte error
  output logic          fec_dec_multiple_err,                    // FEC decoder detected multiple byte errors
  output logic [2 : 0]   fec_dec_even_b_err,                    // FEC Even corrected bit errors in FEC
  output logic [2 : 0]   fec_dec_odd_b_err                    // FEC Odd corrected bit errors in FEC
  );


// Declarations
logic [7 : 0] s_check_byte;
logic [7 : 0] s_parity_byte;
logic [7 : 0] s_check_synd;
logic [7 : 0] s_parity_synd;
logic [7 : 0] r_check_synd;
logic [7 : 0] r_parity_synd;
logic         r_en_check;
logic         s_parity_synd_eq0;
logic         s_check_synd_eq0;
logic [7 : 0] s_parity_map;
logic [7 : 0] s_check_map;
logic [7 : 0] r_parity_map;
logic [8 : 0] s_err_byte_result;

genvar j;

// Instantiate the FEC 84 to 86 Byte Encoders
xplh_fec_84to86_enc
 u_fec (
  // Inputs
  .data_in    (data_in),
  // Outputs
  .check_out  (s_check_byte),
  .parity_out (s_parity_byte)
);

// Accumulate the parity and check bytes
always_ff @(posedge core_clk or negedge core_rst_n) begin : fec_out_PROC
  if(!core_rst_n) begin
    r_check_synd      <= #TP 8'h00;
    r_parity_synd     <= #TP 8'h00;
    r_en_check        <= #TP 1'b0;
  end else begin
    r_en_check        <= #TP en_check;

    // Update the ECC and parity values for the comparison at the end of the Flit
    if(en_check) begin
      r_check_synd      <= #TP s_check_byte;
      r_parity_synd     <= #TP s_parity_byte;
    end
  end
end : fec_out_PROC

// Check the Parity and Check Bytes
always_comb begin : err_det_PROC
  s_check_synd = 8'h00; 
  s_parity_synd = 8'h00;
  if(r_en_check) begin
    s_check_synd = r_check_synd ^ check_in;
    s_parity_synd = r_parity_synd ^ parity_in;
  end
end : err_det_PROC

// Map the parity and error syndrome to the received byte
assign s_parity_map = P_INV_FEC[(s_parity_synd * 8) +: 8];
assign s_check_map  = P_INV_FEC[(s_check_synd * 8) +: 8];
assign s_parity_synd_eq0 = (s_parity_synd == 8'h00);
assign s_check_synd_eq0 = (s_check_synd == 8'h00);
assign fec_dec_err_byte = s_err_byte_result[6:0];

// Error Detection and Correction
always_comb begin
    fec_dec_single_err = 1'b0;
    fec_dec_multiple_err = 1'b0;
    fec_dec_data_out = data_accum;
    s_err_byte_result = 9'd0;
    fec_dec_err_magnitude = s_parity_synd;
 
    unique casez ({s_check_synd_eq0, s_parity_synd_eq0})
    2'b10: begin
        fec_dec_single_err = 1'b1;
        s_err_byte_result = 9'd85;
    end
    2'b01: begin
        fec_dec_single_err = 1'b1;
        fec_dec_err_magnitude = s_check_synd;
        s_err_byte_result = 9'd84;
    end
    2'b00: begin
        if (s_check_map < s_parity_map) begin
            s_err_byte_result = 9'd84 - (9'd255 + {1'b0, s_check_map} - {1'b0, s_parity_map});
        end else begin
            s_err_byte_result = 9'd84 - ({1'b0, s_check_map} - {1'b0, s_parity_map});
        end
 
        if (s_err_byte_result >= 9'd84) begin
            fec_dec_multiple_err = 1'b1;
        end else begin
            fec_dec_single_err = 1'b1;
            fec_dec_data_out[fec_dec_err_byte] = data_accum[fec_dec_err_byte] ^ s_parity_synd;
        end
    end
    default : begin
      fec_dec_single_err = 1'b0;
      fec_dec_multiple_err = 1'b0;
      fec_dec_data_out = data_accum;
      s_err_byte_result = 9'd0;
      fec_dec_err_magnitude = 8'h00;
    end
    endcase
end

// Parity and Check syndromes
assign fec_dec_synd_parity = s_parity_synd;
assign fec_dec_synd_check = s_check_synd;

// Even and Odd bit errors corrected by FEC
assign fec_dec_odd_b_err = (fec_dec_single_err && r_en_check)? ({2'b00,s_parity_synd[0]} + {2'b00,s_parity_synd[2]} + {2'b00,s_parity_synd[4]} + {2'b00,s_parity_synd[6]}) : 3'b000;
assign fec_dec_even_b_err = (fec_dec_single_err && r_en_check)? ({2'b00,s_parity_synd[1]} + {2'b00,s_parity_synd[3]} + {2'b00,s_parity_synd[5]} + {2'b00,s_parity_synd[7]}) : 3'b000;

endmodule
