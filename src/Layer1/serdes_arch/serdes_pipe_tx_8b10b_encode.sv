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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_tx_8b10b_encode.sv#6 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture transmitter side 8b/10b encode module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_tx_8b10b_encode

  import serdes_pipe_pkg::*;
(
  // ------------ inputs ----------------
  input logic                      clk,
  input logic                      rst_n,
  input logic                      encdec_8b10b,
  input logic [PHY_SYM_WD-1:0]     symbol_width,
  input logic                      loopback_en,
  input logic [ORIG_DATA_WD-1:0]   txdata,
  input logic [PHY_NB-1:0]         txdatak,
  input logic                      txelecidle,
  input logic                      txcompliance,
  // ------------ outputs ----------------
  output logic [SERDES_DATA_WD-1:0] enc_data
);

  // This "PTR_WD" is there to avoid the Spyglass ImproperRangeIndex-ML 
  localparam int PTR_WD = (PHY_8B10B_NB > 1) ? $clog2(PHY_8B10B_NB) : 1;

// --------------------------------------------------------------------------------
//  Create encode enable flag
// --------------------------------------------------------------------------------

  logic enc_en;

  always_comb begin: enc_en_PROC
    enc_en = encdec_8b10b && (!loopback_en && !txelecidle);
  end: enc_en_PROC
// --------------------------------------------------------------------------------
//  Encode 8b character to 10b symbol
// --------------------------------------------------------------------------------

  logic [(SYM_10B_WD*PHY_8B10B_NB)-1:0] enc_data_int;
  logic [PHY_8B10B_NB-1:0]              disp_in;
  logic [PHY_8B10B_NB-1:0]              disp_out;
  logic                                 cur_disp;

  assign disp_in = PHY_8B10B_NB'({disp_out, cur_disp});

  generate
    for(genvar i = 0; i < PHY_8B10B_NB; i++) begin: gen_serdes_pipe_tx_8b10b_subencode
      serdes_pipe_tx_8b10b_subencode
       u_serdes_pipe_tx_8b10b_subencode(
        .data_in(txdata[i*SYM_WD+:SYM_WD]),
        .datak_in(txdatak[i]),
        .disp_in(disp_in[i]),
        .data_out(enc_data_int[i*SYM_10B_WD+:SYM_10B_WD]),
        .disp_out(disp_out[i]),
        .err()
      );
    end: gen_serdes_pipe_tx_8b10b_subencode
  endgenerate

// --------------------------------------------------------------------------------
// LSB first
// --------------------------------------------------------------------------------

  always_comb begin: enc_data_PROC
    enc_data = '0;
    if(!enc_en) begin
      enc_data = '0;
    end
    else begin
      for(int i = 0; i < PHY_8B10B_NB; i++) begin
        if(i < symbol_width) begin
          enc_data[i*SYM_10B_WD +:SYM_10B_WD] = {<< {enc_data_int[i*SYM_10B_WD +:SYM_10B_WD]}};
        end
      end
    end
  end: enc_data_PROC

// --------------------------------------------------------------------------------
//  Create current runninng disparity
// --------------------------------------------------------------------------------

  logic              prev_disp;
  logic [PTR_WD-1:0] l_ptr;
  assign l_ptr = $bits(l_ptr)'(symbol_width -1);

  always_ff @(posedge clk or negedge rst_n) begin: prev_disp_PROC
    if (!rst_n)
      prev_disp <= #`TP '0;
    else if (enc_en) begin
      prev_disp <= #`TP disp_out[l_ptr];
    end
  end: prev_disp_PROC

  assign cur_disp = !txcompliance && prev_disp;

endmodule
