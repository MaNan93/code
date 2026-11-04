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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_fec.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module positions the partial flit on the data path in the correct
// location at the input to the FEC. Instantiates pipe line stage after the FEC.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_fec
  import cx_pl_pkg::*;
#(
  parameter   TP        = `TP
) 
                 (
  // Inputs
  input                       core_clk,
  input                       core_rst_n,
  input                       clear,                // Synchronous reset
  input                       halt_in,              // Back pressure
  input   tx_flit_struct      flit_in,              // Input Flit
  input                       cmd_ack,              // Command Acknowledge
  // Outputs
  output  logic               xplh_fec_halt,        // Back-pressure from FEC
  output  tx_flit_struct      xplh_fec_flit,        // FEC Flit
  output  logic               xplh_fec_cmd_ack      // Command Acknowledge
);

// Local Parameters
localparam P_DW_ZERO = {P_DW{1'b0}};
localparam P_FEC_PIPE_WD = $bits(flit_in);

// Logic Declarations
logic [P_FLIT_DW_CNT_WD - 1 : 0]  dw_cnt_r;
logic [P_FLIT_WD - 1 : 0]         fec_data_in_s;
logic [47 : 0]                    fec_enc_out;
logic                             s_en_dw_cnt;
logic                             r_en_dw_cnt;
tx_flit_struct                    int_fec_flit;

always_comb begin : dw_cnt_en_PROC
  if(clear)
    s_en_dw_cnt = 1'b0;
  else if(flit_in.sof && !halt_in)
    s_en_dw_cnt = 1'b1;
  else if(flit_in.eof[1] && !halt_in)
    s_en_dw_cnt = 1'b0;
  else
    s_en_dw_cnt = r_en_dw_cnt;
end : dw_cnt_en_PROC


// Count the number of Data Path Chunks per Flit 
always_ff @(posedge core_clk or negedge core_rst_n) begin : dw_cnt_PROC
  if(!core_rst_n) begin
    dw_cnt_r <= #TP '0;
    r_en_dw_cnt <= #TP 1'b0;
  end else begin
    r_en_dw_cnt <= #TP s_en_dw_cnt;
    if(clear)
      dw_cnt_r  <= #TP '0;
    else if(!halt_in && (s_en_dw_cnt || r_en_dw_cnt)) begin
      if(dw_cnt_r == P_FLIT_DW_CNT - 1)
        dw_cnt_r <= #TP '0;
      else
        dw_cnt_r <= #TP dw_cnt_r + 1'b1;
    end
  end
end : dw_cnt_PROC

// Align the data in the correct position for FEC generation
always_comb begin : data_align_PROC
  fec_data_in_s = {P_FLIT_WD{1'b0}};
  unique case (dw_cnt_r)
    // 512-bit data path
    0 : fec_data_in_s = {P_DW_ZERO, P_DW_ZERO, P_DW_ZERO, flit_in.data};
    1 : fec_data_in_s = {P_DW_ZERO, P_DW_ZERO, flit_in.data, P_DW_ZERO};
    2 : fec_data_in_s = {P_DW_ZERO, flit_in.data, P_DW_ZERO, P_DW_ZERO};
    3 : fec_data_in_s = {flit_in.data, P_DW_ZERO, P_DW_ZERO, P_DW_ZERO};
    default : fec_data_in_s = {P_FLIT_DW_CNT{P_DW_ZERO}};
  endcase
end : data_align_PROC

// FEC Encoder
xplh_fec_enc
 #(
  .P_FLIT_WD  (P_FLIT_WD)
) u_xplh_fec_enc (
  // Inputs
  .core_clk     (core_clk),
  .core_rst_n   (core_rst_n),
  .data_in      (fec_data_in_s),
  .eof          (flit_in.eof[1]),
  .halt_in      (halt_in),
  // Outputs
  .fec_enc_out  (fec_enc_out)
);

assign xplh_fec_halt = halt_in;

// Insert the FEC code into the end of the flit
always_comb begin : fec_ins_PROC
  int_fec_flit = flit_in;
  if(flit_in.eof[1])
    int_fec_flit.data = {fec_enc_out, flit_in.data[P_DW - 48 - 1 : 0]};
end : fec_ins_PROC

delay_n_w_stalling
  #(
  .N          (1),
  .WD         (P_FEC_PIPE_WD),
  .CAN_STALL  (0)
) u_fec_pipe (
  .clk      (core_clk),
  .rst_n    (core_rst_n),
  .clear    (clear),
  .stall    (halt_in),
  .din      (int_fec_flit),
  .dout     (xplh_fec_flit),
  .stallout ()
);

// No halting applied to the command acknowledge
delay_n
  #(
  .N  (1),
  .WD (1)
) u_cmd_ack_pipe (
  .clk      (core_clk),
  .rst_n    (core_rst_n),
  .clear    (1'b0),
  .din      (cmd_ack),
  .dout     (xplh_fec_cmd_ack)
);


endmodule
