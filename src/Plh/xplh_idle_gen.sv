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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_idle_gen.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH IDLE Generator
//
// Description: This module generates IDLE Flits 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_idle_gen
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::CMD_IDLE;
  import cx_pl_pkg::CMD_RESET;
  import cx_pl_pkg::P_FLIT_DW_CNT;
  import cx_pl_pkg::P_FLIT_DW_CNT_WD;
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
  input   tx_flit_struct        xplh_flit,                // Flit Input
  input                         xplh_crc_sof,             // SOF from CRC
  // -------------------------------------------------------------------------------------
  // Command Interface
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct         xmlh_xplh_cmd,            // Request to transmit IDLE Flits
  input                         halt_in,                  // Downstream Halt
  // -------------------------------------------------------------------------------------
  // Flit Interface
  // -------------------------------------------------------------------------------------
  output  tx_flit_struct        xplh_idle_gen_flit,       // Flit out either NOP or XTLH
  output  logic                 xplh_idle_gen_halt,       // Back-pressure the XTLH while sending NOP Flits
  output  logic                 xplh_idle_gen_ack,        // IDLE Command Acknowledge
  output  logic                 xplh_idle_gen_grant_dllp  // When set to 1 DLLP can be granted
  ,
  output  logic                 xplh_idle_gen_valid       // IDLE Command Valid
);

// Logic Declarations
logic [P_FLIT_DW_CNT_WD-1:0] nop_dw_cnt_r;
logic                       int_idle_sof;
logic                       int_idle_enf;
logic [1:0]                 int_idle_eof;
logic                       int_req_idle;
logic                       int_req_idle_r;
logic                       int_idle_halt;
logic                       int_idle_halt_r;
logic                       int_unhalt_pipe;

// When NOP is requested from the lower layer wait until data is available from the upper layer
always_comb begin : nop_req_PROC
  int_req_idle = 1'b0;
  if(xmlh_xplh_cmd.tx_cmd == CMD_RESET)
    int_req_idle = 1'b0;
  // Switching from Payload Flits to IDLE Flits
  else if(xmlh_xplh_cmd.req && (xmlh_xplh_cmd.tx_cmd == CMD_IDLE)) begin
    int_req_idle = 1'b1;
  // Switching from IDLE to Payload wait for end of current IDLE flit and start of Payload Flit
  end else if((int_idle_eof[1] && int_idle_enf && !halt_in) && xplh_flit.sof && !(xmlh_xplh_cmd.tx_cmd == CMD_IDLE))
    int_req_idle = 1'b0;
  else
    int_req_idle = int_req_idle_r;
end : nop_req_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_cnt_PROC
  if(!core_rst_n) begin
    nop_dw_cnt_r        <= #TP 'h0;
    int_req_idle_r      <= #TP 1'b0;
    int_idle_halt_r     <= #TP 1'b0;
    xplh_idle_gen_ack   <= #TP 1'b0;
  end else begin
    int_idle_halt_r     <= #TP int_idle_halt;
    int_req_idle_r      <= #TP int_req_idle;
    xplh_idle_gen_ack   <= #TP int_req_idle && !int_req_idle_r;
    if(!halt_in) begin
      if(nop_dw_cnt_r == P_FLIT_DW_CNT - 1)
        nop_dw_cnt_r  <= #TP 'h0;
      else if(int_req_idle_r)
        nop_dw_cnt_r  <= #TP nop_dw_cnt_r + 1'b1;
      else
        nop_dw_cnt_r  <= #TP nop_dw_cnt_r;
    end
  end
end : nop_cnt_PROC

// Generate the EOF marker
assign int_idle_eof = (nop_dw_cnt_r == P_FLIT_DW_CNT - 1) ? 2'b11 : 2'b00;
assign int_idle_enf = int_idle_eof[1];

assign int_idle_sof = int_req_idle_r && (nop_dw_cnt_r == 'h0);

// If transmitting IDLE Flits assert the halt when the SOF arrives for PCIe config
// De-assert the Halt when no more IDLE Flits requested and IDLE EOF is sent
always_comb begin : idle_halt_PROC
  if(!int_req_idle_r)
    int_idle_halt = 1'b0;
  else if(int_req_idle_r && xplh_flit.sof)
    int_idle_halt = 1'b1;
  else
    int_idle_halt = int_idle_halt_r;
end : idle_halt_PROC

// Output MUX Select between data from XPLH or IDLE Flit
// If sending an IDLE Flit back-pressure XPLH
always_comb begin : nop_mux_PROC
  if(int_req_idle_r) begin
    xplh_idle_gen_flit.sof                    = int_idle_sof;
    xplh_idle_gen_flit.eof                    = int_idle_eof;
    xplh_idle_gen_flit.enf                    = int_idle_enf;
    xplh_idle_gen_flit.data                   = {DW_W_PAR{1'b0}};
    xplh_idle_gen_flit.data_valid             = 1'b1;
    xplh_idle_gen_flit.retry_flit             = 1'b0;
    xplh_idle_gen_flit.expl_flit              = 1'b0;
    xplh_idle_gen_halt                        = int_idle_halt && !int_unhalt_pipe;
    xplh_idle_gen_flit.tlp_dv                 = 1'b0;
    xplh_idle_gen_flit.flit_type_s            = xplh_flit.flit_type_s;
    xplh_idle_gen_flit.flit_prot              = '0; 
    xplh_idle_gen_flit.ras_dp_err_inband_kbd  = '0;
  end else begin
    xplh_idle_gen_flit            = xplh_flit;
    xplh_idle_gen_halt            = halt_in;
  end
end : nop_mux_PROC

assign xplh_idle_gen_grant_dllp = !int_unhalt_pipe; 
assign xplh_idle_gen_valid = int_req_idle_r;

// -------------------------------------------------------------------------------------
// Pipe Flush FSM
// -------------------------------------------------------------------------------------
xplh_pipe_flush
 u_xplh_pipe_flush (
  .core_clk               (core_clk),
  .core_rst_n             (core_rst_n),
  .next_sof               (xplh_crc_sof),
  .xmlh_xplh_cmd          (xmlh_xplh_cmd),
  .idle_in_progress       (int_idle_halt),
  .xplh_pipe_flush_unhalt (int_unhalt_pipe)
);

endmodule
