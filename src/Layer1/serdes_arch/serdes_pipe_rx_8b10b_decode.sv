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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_8b10b_decode.sv#11 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side 8b/10b decode module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_8b10b_decode

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic                         clk,
  input logic                         rst_n,
  input logic                         encdec_8b10b,
  input logic [PHY_8B10B_SYM_WD-1:0]  symbol_width,
  input logic                         estore_rdvalid,
  input pipe_data10b_t                estore_rddata,
  input logic                         estore_rddatavalid,
  input logic                         err_estore_overflow,
  input logic                         err_estore_underflow,
  // ------------- output ----------------
  output pipe_data8b_t                decoded_rxdata,
  output logic [PHY_8B10B_NB-1:0]     decoded_rxdatak,
  output logic                        err_code,
  output logic                        err_disp
);

  // This "PTR_WD" is there to avoid the Spyglass ImproperRangeIndex-ML 
  localparam int PTR_WD = (PHY_8B10B_NB > 1) ? $clog2(PHY_8B10B_NB) : 1;

// --------------------------------------------------------------------------------
//  Common internal signal
// --------------------------------------------------------------------------------
  logic  decode_en;
  assign decode_en = encdec_8b10b && estore_rdvalid;

// --------------------------------------------------------------------------------
//  8b/10b decoder
// --------------------------------------------------------------------------------
  pipe_data8b_t             raw_decoded_rxdata;
  logic [PHY_8B10B_NB-1:0]  raw_decoded_rxdatak;
  logic [PHY_8B10B_NB-1:0]  raw_cur_disp_bus_in, raw_cur_disp_bus_out;
  logic [PHY_8B10B_NB-1:0]  raw_err_code_bus;
  logic [PHY_8B10B_NB-1:0]  raw_err_disp_bus;
  logic                     running_disp, cur_disp;
  assign raw_cur_disp_bus_in = PHY_8B10B_NB'({raw_cur_disp_bus_out, running_disp});

  logic [PTR_WD-1:0] l_ptr;
  assign l_ptr = $bits(l_ptr)'(symbol_width -1);
  assign cur_disp = raw_cur_disp_bus_out[l_ptr];

  generate
    for(genvar i = 0; i < PHY_8B10B_NB; i++) begin: gen_serdes_pipe_rx_8b10b_subdecode
      serdes_pipe_rx_8b10b_subdecode
        u_serdes_pipe_rx_8b10b_subdecode (
      // ------------- input -----------------
        .data_in(estore_rddata[i]),
        .disp_in(raw_cur_disp_bus_in[i]),
      // ------------- output ----------------
        .data_out(raw_decoded_rxdata[i]),
        .datak_out(raw_decoded_rxdatak[i]),
        .disp_out(raw_cur_disp_bus_out[i]),
        .err_code(raw_err_code_bus[i]),
        .err_disp(raw_err_disp_bus[i])
      );
    end
  endgenerate

// --------------------------------------------------------------------------------
//  Neutral data detection
// --------------------------------------------------------------------------------
  logic [PHY_8B10B_NB-1:0]  neu_data_found;

  always_comb begin: neu_data_found_PROC
    logic [5:0]  l_abcdei;
    logic [3:0]  l_fghi;
    logic  l_neu_abcdei, l_neu_fghi;
    neu_data_found = '0;
    for(int i = 0; i < PHY_8B10B_NB; i++) begin
      {l_abcdei, l_fghi} = estore_rddata[i];
      l_neu_abcdei = (^l_abcdei == 1'h1) && (l_abcdei[5:3] != '1) && (l_abcdei[2:0] != '1);
      l_neu_fghi = (^l_fghi == 1'h0) && (l_fghi[3:2] != '1) && (l_fghi[1:0] != '1);
      neu_data_found[i] = l_neu_abcdei && l_neu_fghi;
    end
  end

// --------------------------------------------------------------------------------
//  Running disparity preserving
// --------------------------------------------------------------------------------
  logic                   running_disp_valid;
  logic [PHY_8B10B_NB:0]  disp_valid_bus;

  always_comb begin: disp_valid_bus_PROC
    disp_valid_bus = '0;
    if(!err_estore_overflow && !err_estore_underflow) begin
      disp_valid_bus[0] = running_disp_valid;
      for(int i = 0; i < PHY_8B10B_NB; i++) begin
        disp_valid_bus[i+1] = (raw_err_code_bus[i]) ? 1'h0 :
                              (neu_data_found[i])   ? disp_valid_bus[i] : 1'h1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: running_disp_PROC
    if(!rst_n) begin
      running_disp <= #`TP 1'h0;
      running_disp_valid <= #`TP 1'h0;
    end
    else if(!decode_en) begin
      running_disp <= #`TP 1'h0;
      running_disp_valid <= #`TP 1'h0;
    end
    else if(err_estore_overflow || err_estore_underflow) begin
      running_disp <= #`TP 1'h0;
      running_disp_valid <= #`TP 1'h0;
    end
    else if(estore_rddatavalid) begin
      running_disp <= #`TP cur_disp;
      running_disp_valid <= #`TP disp_valid_bus[symbol_width];
    end
  end

// --------------------------------------------------------------------------------
//  Code / disparity error handling
// --------------------------------------------------------------------------------
  always_comb begin: decoded_rxdata_PROC
    decoded_rxdata = '0;
    decoded_rxdatak = '0;
    if(decode_en) begin
      if(estore_rddatavalid) begin
        for(int i = 0; i < PHY_8B10B_NB; i++) begin
          if(symbol_width > i) begin
            decoded_rxdata[i] = raw_decoded_rxdata[i];
            decoded_rxdatak[i] = raw_decoded_rxdatak[i];
            // ccx_cond: ; 0; 01; "Redundant condition due to serdes_pipe_rx_estore implementation."
            if(raw_err_code_bus[i] || err_estore_underflow) begin
              decoded_rxdata[i] = SYM_8B_EDB;
              decoded_rxdatak[i] = 1'h1;
            end
          end
        end
      end
    end
  end

  always_comb begin: err_code_PROC
    err_code = 1'h0;
    err_disp = 1'h0;
    if(decode_en) begin
      if(estore_rddatavalid && !err_estore_underflow) begin
        for(int i = 0; i < PHY_8B10B_NB; i++) begin
          if(symbol_width > i) begin
            err_code |= raw_err_code_bus[i];
            if(disp_valid_bus[i]) begin
              err_disp |= raw_err_disp_bus[i];
            end
          end
        end
      end
    end
  end

endmodule: serdes_pipe_rx_8b10b_decode
