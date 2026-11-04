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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_8b10b_osfind.sv#6 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side 8b/10b Ordered Set finder module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_8b10b_osfind

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic                         rx_clk,
  input logic                         rx_rst_n,
  input logic                         rx_sync_rst,
  input logic [PHY_8B10B_SYM_WD-1:0]  symbol_width,
  input logic                         symbol_locked,
  input pipe_data10b_t                locked_rxdata,
  // ------------- output ----------------
  output logic                        eios_found
);

// --------------------------------------------------------------------------------
//  Common internal parameter / type / function
// --------------------------------------------------------------------------------
  localparam int  EIOS_SYM_NUM  = 4;

  typedef struct packed {
    logic  com;
    logic  idl;
  }  symbol_t;

  function automatic logic  find_eios (
    symbol_t [EIOS_SYM_NUM-1:0]  symbol
  );
    logic                     ret;
    logic [EIOS_SYM_NUM-2:0]  idl;
    ret = 1'h0;
    for(int i = 0; i < (EIOS_SYM_NUM - 1); i++) begin
      idl[i] = symbol[i+1].idl;
    end
    if(symbol[0].com) begin
      ret = (idl inside {'b011, 'b101, 'b110, 'b111});
    end
    return ret;
  endfunction

// --------------------------------------------------------------------------------
//  Symbol decode
// --------------------------------------------------------------------------------
  symbol_t [PHY_8B10B_NB-1:0]  cur_symbol;

  always_comb begin: cur_symbol_PROC
    cur_symbol = '0;
    for(int i = 0; i < PHY_8B10B_NB; i++) begin
      cur_symbol[i].com = (locked_rxdata[i] inside {SYM_10B_COM, ~SYM_10B_COM});
      cur_symbol[i].idl = (locked_rxdata[i] inside {SYM_10B_IDL, ~SYM_10B_IDL});
    end
  end

// --------------------------------------------------------------------------------
//  Decoded symbol buffer
// --------------------------------------------------------------------------------
  symbol_t [EIOS_SYM_NUM-2:0]               buf_symbol;
  symbol_t [PHY_8B10B_NB+EIOS_SYM_NUM-2:0]  concat_symbol;
  assign concat_symbol = {cur_symbol, buf_symbol};

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: buf_symbol_PROC
    if(!rx_rst_n) begin
      buf_symbol <= #`TP '0;
    end
    else if(rx_sync_rst || !symbol_locked) begin
      buf_symbol <= #`TP '0;
    end
    else begin
      for(int i = 0; i < (EIOS_SYM_NUM - 1); i++) begin
        buf_symbol[i] <= #`TP concat_symbol[symbol_width+i];
      end
    end
  end

// --------------------------------------------------------------------------------
//  EIOS finding
// --------------------------------------------------------------------------------
  always_comb begin: eios_found_PROC
    eios_found = 1'h0;
    for(int i = 0; i < PHY_8B10B_NB; i++) begin
      if(symbol_width > i) begin
        eios_found |= find_eios(concat_symbol[i+:EIOS_SYM_NUM]);
      end
    end
  end

endmodule: serdes_pipe_rx_8b10b_osfind
