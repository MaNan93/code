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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_fec_enc.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module generates the FEC check and parity bytes for PCIe Gen6 Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_fec_enc
  import cx_pl_pkg::*;
#(
  parameter TP        = `TP,
  parameter P_FLIT_WD = 2048
) 
                     (
  // Inputs
  input                     core_clk,
  input                     core_rst_n,
  input [P_FLIT_WD - 1 : 0] data_in,    // Data
  input                     eof,        // End of Flit
  input                     halt_in,    // Halt from lower layer
  // Outputs
  output  logic [47 : 0]    fec_enc_out // 6-Bytes FEC
);

// Logic Declarations
logic [7 : 0]       s_fec0_in [P_N_SYMBOLS - 1 : 0];
logic [7 : 0]       s_fec1_in [P_N_SYMBOLS - 1 : 0];
logic [7 : 0]       s_fec2_in [P_N_SYMBOLS - 1 : 0];
logic [7 : 0]       s_fec0_ecc_out;
logic [7 : 0]       s_fec1_ecc_out;
logic [7 : 0]       s_fec2_ecc_out;
logic [7 : 0]       r_fec0_ecc_out;
logic [7 : 0]       r_fec1_ecc_out;
logic [7 : 0]       r_fec2_ecc_out;
logic [7 : 0]       s_fec0_parity_out;
logic [7 : 0]       s_fec1_parity_out;
logic [7 : 0]       s_fec2_parity_out;
logic [7 : 0]       r_fec0_parity_out;
logic [7 : 0]       r_fec1_parity_out;
logic [7 : 0]       r_fec2_parity_out;
logic [7 : 0]       s_fec0_ecc_accum;
logic [7 : 0]       s_fec1_ecc_accum;
logic [7 : 0]       s_fec2_ecc_accum;
logic [7 : 0]       s_fec0_parity_accum;
logic [7 : 0]       s_fec1_parity_accum;
logic [7 : 0]       s_fec2_parity_accum;
logic [23 : 0]      s_parity_out;
logic [23 : 0]      s_ecc_out;

// Interleave the Data over the three FEC blocks
always_comb begin : interleave_PROC
  s_fec0_in = interleave_data(data_in, 0); // blue 
  s_fec1_in = interleave_data(data_in, 1); // orange
  s_fec2_in = interleave_data(data_in, 2); // green
end : interleave_PROC

// Instantiate the FEC 84 to 86 Byte Encoders
xplh_fec_84to86_enc
 u_fec0 (
  // Inputs
  .data_in    (s_fec0_in),
  // Outputs
  .check_out  (s_fec0_ecc_out),
  .parity_out (s_fec0_parity_out)
);

// Instantiate the FEC 84 to 86 Byte Encoders
xplh_fec_84to86_enc
 u_fec1 (
  // Inputs
  .data_in    (s_fec1_in),
  // Outputs
  .check_out  (s_fec1_ecc_out),
  .parity_out (s_fec1_parity_out)
);

// Instantiate the FEC 84 to 86 Byte Encoders
xplh_fec_84to86_enc
 u_fec2 (
  // Inputs
  .data_in    (s_fec2_in),
  // Outputs
  .check_out  (s_fec2_ecc_out),
  .parity_out (s_fec2_parity_out)
);

always_ff @(posedge core_clk or negedge core_rst_n) begin : fec_out_PROC
  if(!core_rst_n) begin
    r_fec0_ecc_out      <= #TP 8'h00;
    r_fec1_ecc_out      <= #TP 8'h00;
    r_fec2_ecc_out      <= #TP 8'h00;
    r_fec0_parity_out   <= #TP 8'h00;
    r_fec1_parity_out   <= #TP 8'h00;
    r_fec2_parity_out   <= #TP 8'h00;
  end else begin
    if(!halt_in) begin
      // Clear the accumulation at the end of Flit
      if(eof) begin
        r_fec0_ecc_out    <= #TP 8'h00;
        r_fec1_ecc_out    <= #TP 8'h00;
        r_fec2_ecc_out    <= #TP 8'h00;
        r_fec0_parity_out <= #TP 8'h00;
        r_fec1_parity_out <= #TP 8'h00;
        r_fec2_parity_out <= #TP 8'h00;
      end else begin
        r_fec0_ecc_out    <= #TP s_fec0_ecc_accum;
        r_fec1_ecc_out    <= #TP s_fec1_ecc_accum;
        r_fec2_ecc_out    <= #TP s_fec2_ecc_accum;
        r_fec0_parity_out <= #TP s_fec0_parity_accum;
        r_fec1_parity_out <= #TP s_fec1_parity_accum;
        r_fec2_parity_out <= #TP s_fec2_parity_accum;
      end
    end
  end
end : fec_out_PROC

assign s_fec0_parity_accum = (s_fec0_parity_out ^ r_fec0_parity_out);
assign s_fec2_parity_accum = (s_fec2_parity_out ^ r_fec2_parity_out);
assign s_fec1_parity_accum = (s_fec1_parity_out ^ r_fec1_parity_out);

assign s_fec0_ecc_accum = (s_fec0_ecc_out ^ r_fec0_ecc_out);
assign s_fec2_ecc_accum = (s_fec2_ecc_out ^ r_fec2_ecc_out);
assign s_fec1_ecc_accum = (s_fec1_ecc_out ^ r_fec1_ecc_out);

assign s_parity_out = {s_fec0_parity_accum, s_fec2_parity_accum, s_fec1_parity_accum};
assign s_ecc_out = {s_fec0_ecc_accum, s_fec2_ecc_accum, s_fec1_ecc_accum};
assign fec_enc_out = {s_parity_out, s_ecc_out};

endmodule
