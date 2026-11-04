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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/19 02:16:44 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_nop_gen.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH NOP Generator
//
// Description: This module generates NOP Flits 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_nop_gen
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::P_FLIT_DW_CNT;
  import cx_pl_pkg::P_FLIT_DW_CNT_WD;
  import  cx_pl_pkg::P_PARITY_MODE;
#(
  parameter TP = `TP,
  parameter NW          = `CX_NW,             // Number of 32-bit Data Words supported by the data path
  parameter DW          = NW * 32,            // Data path width
  parameter DATA_PAR_WD = `TRGT_DATA_PROT_WD, // data bus parity width
  parameter DW_W_PAR    = DW + DATA_PAR_WD    // Width of datapath in bits plus the parity bits.
) 
                     (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                         core_clk,                 // Core clock
  input                         core_rst_n,               // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  input   tx_flit_struct        flit_in,                  // Flit Input
  input                         req_nop,                  // NOP Request
  // -------------------------------------------------------------------------------------
  // Command Interface
  // -------------------------------------------------------------------------------------
  input                         halt_in,                  // Downstream Halt
  // -------------------------------------------------------------------------------------
  // Flit Interface
  // -------------------------------------------------------------------------------------
  output  tx_flit_struct        xplh_nop_gen_flit,       // Flit out either NOP or XTLH
  output  logic                 xplh_nop_gen_halt        // Back-pressure the XTLH while sending NOP Flits
);

// Logic Declarations
logic [P_FLIT_DW_CNT_WD-1:0] nop_dw_cnt_r;
logic                       int_nop_sof;
logic                       int_nop_enf;
logic [1:0]                 int_nop_eof;
logic                       int_nop_gen_halt;

// NOP Generator Halt
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_nop_gen_halt <= #TP 1'b0;
  else begin
    if(int_nop_gen_halt && !req_nop && !halt_in && xplh_nop_gen_flit.eof[1])
      int_nop_gen_halt <= #TP 1'b0;
    else if(req_nop && !halt_in && flit_in.eof[1])
      int_nop_gen_halt <= #TP 1'b1;
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_cnt_PROC
  if(!core_rst_n) begin
    nop_dw_cnt_r        <= #TP 'h0;
  end else begin
    if(!halt_in && int_nop_gen_halt) begin
      if(nop_dw_cnt_r == P_FLIT_DW_CNT - 1)
        nop_dw_cnt_r  <= #TP 'h0;
      else
        nop_dw_cnt_r  <= #TP nop_dw_cnt_r + 1'b1;
    end
  end
end : nop_cnt_PROC

// Generate the EOF marker
assign int_nop_eof = (nop_dw_cnt_r == P_FLIT_DW_CNT - 1) ? 2'b11 : 2'b00;
assign int_nop_enf = int_nop_eof[1];

assign int_nop_sof = int_nop_gen_halt && (nop_dw_cnt_r == 'h0);

// Output MUX Select between data from XPLH or NOP Flit
always_comb begin : nop_mux_PROC
  if(int_nop_gen_halt) begin
    xplh_nop_gen_flit.sof                   = int_nop_sof;
    xplh_nop_gen_flit.eof                   = int_nop_eof;
    xplh_nop_gen_flit.enf                   = int_nop_enf;
    xplh_nop_gen_flit.data                  = {DW_W_PAR{1'b0}};
    xplh_nop_gen_flit.data_valid            = 1'b1;
    xplh_nop_gen_flit.retry_flit            = 1'b0;
    xplh_nop_gen_flit.expl_flit             = 1'b0;
    xplh_nop_gen_flit.tlp_dv                = 1'b0;
    xplh_nop_gen_flit.flit_type_s           = flit_in.flit_type_s;
    xplh_nop_gen_flit.flit_prot             = (P_PARITY_MODE == 1) ? '1 : '0;
    xplh_nop_gen_flit.ras_dp_err_inband_kbd = '0;
    xplh_nop_gen_halt                       = 1'b1;
  end else begin
    xplh_nop_gen_flit                       = flit_in;
    xplh_nop_gen_halt                       = halt_in;
  end
end : nop_mux_PROC

endmodule
