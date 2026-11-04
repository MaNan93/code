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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_flit_prot.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module performs the CRC and FEC checks for the Flit.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module rplh_flit_prot
  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_FLIT_PROT_WD;
#(
  parameter TP               = `TP,
  parameter NL               = `CX_NL,                           // Max number of lanes supported
  parameter NB               = `CX_NB,                           // Number of symbols (bytes) per clock cycle
  parameter P_DOUT_WD        = P_FLIT_WD - (14*8),               // Flit less FEC and CRC bytes
  parameter P_DOUT_WD_W_PROT = P_DOUT_WD + P_FLIT_PROT_WD       // Flit less FEC and CRC with protection bits
) (
  // Inputs
  input                                 core_clk,
  input                                 core_rst_n,
  input   [5:0]                         smlh_link_mode,       // Link Width
  input                                 rxdata_vld,           // Data valid
  input                                 rplh_flit_in_nxt_vld, // Combinational version of accumulated flit is valid  
  input  [P_FLIT_WD-1:0]                rplh_flit_in_nxt,     // Combinational version of accumulated flit
  input  [P_FLIT_WD-1:0]                rplh_flit_in,         // Registered version of accumulated flit
  input                                 search_for_tokens, // Enable flit processing
  // Outputs
  output  logic [2:0][7:0]              rplh_flit_prot_synd_parity,       // FEC Parity Syndrome
  output  logic [2:0][7:0]              rplh_flit_prot_synd_check,        // FEC Error Syndrome
  output  logic [P_DOUT_WD_W_PROT-1:0]  rplh_flit_prot_data_out,          // Flit bytes after FEC & CRC
  output  logic                         rplh_flit_prot_data_valid,        // Data valid
  output  logic [15:0][3:0]             rplh_flit_prot_even_b_err,        // Even corrected bit errors in FEC
  output  logic [15:0][3:0]             rplh_flit_prot_odd_b_err,         // Odd corrected bit errors in FEC 
  output  logic                         rplh_flit_prot_fec_c_err,         // FEC Correctable flit error
  output  logic                         rplh_flit_prot_fec_data_invalid,  // FEC Uncorrectable Error
  output  logic                         rplh_flit_prot_crc_data_invalid   // CRC Uncorrectable Error
);

// Logic Declarations
logic [P_FLIT_WD - 48 - 1 : 0]  s_rplh_fec_data_out;
logic                           s_rplh_fec_data_valid;
logic                           s_rplh_fec_data_invalid;
logic                           s_rplh_fec_c_err;
logic [2 : 0][7 : 0]              s_rplh_synd_parity ;
logic [2 : 0][7 : 0]              s_rplh_synd_check ;
logic [15 : 0][3 : 0]              s_rplh_even_b_err ;
logic [15 : 0][3 : 0]              s_rplh_odd_b_err ;

// Instantiate the FEC
rplh_fec
 u_rplh_fec (
  // Inputs
  .core_clk                         (core_clk),
  .core_rst_n                       (core_rst_n),
  .smlh_link_mode                   (smlh_link_mode),
  .rxdata_vld                       (rxdata_vld),
  .rplh_flit_in_nxt                 (rplh_flit_in_nxt),
  .rplh_flit_in                     (rplh_flit_in),
  .rplh_flit_in_nxt_vld             (rplh_flit_in_nxt_vld),
  // Outputs
  .rplh_fec_data_out                (s_rplh_fec_data_out),
  .rplh_fec_data_valid              (s_rplh_fec_data_valid),
  .rplh_fec_data_invalid            (s_rplh_fec_data_invalid),
  .rplh_fec_corr_err                (s_rplh_fec_c_err),
  .rplh_fec_synd_parity             (s_rplh_synd_parity),
  .rplh_fec_synd_check              (s_rplh_synd_check),
  .rplh_fec_even_b_err              (s_rplh_even_b_err),
  .rplh_fec_odd_b_err               (s_rplh_odd_b_err)
);

// Instantiate the CRC
rplh_crc
 u_rplh_crc (
  // Inputs
  .core_clk                   (core_clk),
  .core_rst_n                 (core_rst_n),
  .data_in                    (s_rplh_fec_data_out),
  .data_valid                 (s_rplh_fec_data_valid),
  .data_invalid               (s_rplh_fec_data_invalid),
  // Outputs
  .rplh_crc_data_out          (rplh_flit_prot_data_out),
  .rplh_crc_data_valid        (rplh_flit_prot_data_valid),
  .rplh_crc_data_invalid      (rplh_flit_prot_crc_data_invalid),
  .rplh_fec_data_invalid      (rplh_flit_prot_fec_data_invalid)
);

// Register the error indication and status for the configuration space
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_det_PROC
  if(!core_rst_n) begin
    rplh_flit_prot_fec_c_err <= #TP 1'b0;
    for(int i = 0; i < 3; i++) begin
      rplh_flit_prot_synd_parity[i] <= #TP 8'h00;
      rplh_flit_prot_synd_check[i] <= #TP 7'h00;
    end
    for(int i = 0; i < 16; i++) begin
      rplh_flit_prot_even_b_err[i] <= #TP 4'b0000;
      rplh_flit_prot_odd_b_err[i] <= #TP 4'b0000;
    end
  end else begin
    rplh_flit_prot_fec_c_err <= #TP s_rplh_fec_c_err;
    rplh_flit_prot_synd_parity <= #TP s_rplh_synd_parity;
    rplh_flit_prot_synd_check <= #TP s_rplh_synd_check;
    rplh_flit_prot_even_b_err <= #TP s_rplh_even_b_err;
    rplh_flit_prot_odd_b_err <= #TP s_rplh_odd_b_err;
  end
end : err_det_PROC


endmodule
