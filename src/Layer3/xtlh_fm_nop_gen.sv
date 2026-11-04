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
// ---   $DateTime: 2024/01/25 10:42:16 $
// ---   $Revision: #10 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_fm_nop_gen.sv#10 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XTLP NOP Generator
//
// Description: This module generates NOP TLP's over the entire Flit. 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xtlh_fm_nop_gen
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::CMD_PYLD;
  import cx_pl_pkg::CMD_RESET;
  import cx_pl_pkg::CMD_NOP;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
  import cx_pl_pkg::NOP;
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
  input                         core_clk,         // Core clock
  input                         core_rst_n,       // Active low asynchronous reset
  // -------------------------------------------------------------------------------------
  // XTLH Interface
  // -------------------------------------------------------------------------------------
  input   tx_flit_struct        xtlh_flit_in,     // Flit Interface
  // -------------------------------------------------------------------------------------
  // Command Interface
  // -------------------------------------------------------------------------------------
  input   tx_cmd_struct         xdlh_xtlh_cmd,    // Command interface
  input                         halt_in,          // Downstream Halt
  // -------------------------------------------------------------------------------------
  // Flit Interface
  // -------------------------------------------------------------------------------------
  input                         flit_mode_en,     // Flit Mode Enable
  output  tx_flit_struct        xtlh_fm_nop_flit, // Flit Output
  output  logic                 xtlh_fm_nop_halt, // Back-pressure the XTLH while sending NOP Flits
  output  logic                 xtlh_fm_nop_ack,  // NOP Transmission Acknowledge
  output  logic                 xtlh_fm_nop_pyld_en // Enable Payload transmission
  // -------------------------------------------------------------------------------------
  // SPIF Interface
  // -------------------------------------------------------------------------------------
  ,
  input                         rstctl_core_flush_req,  // Flush Request
  input                         spif_enable
);
// Local Parameters
localparam P_NOP_DW_CNT = 4;

localparam P_NOP_DW_CNT_WD = $clog2(P_NOP_DW_CNT);

// Logic Declarations
logic [P_NOP_DW_CNT_WD-1:0] nop_dw_cnt_r;
logic                       int_nop_sof;
logic                       int_nop_enf;
logic [1:0]                 int_nop_eof;
logic                       int_req_nop;
logic                       int_req_nop_r;
logic                       int_stop_nop_r;
logic                       int_start_nop_r;
logic                       int_nop_ack_r;
logic                       int_nop_ack;
logic                       int_datastream_r;
logic                       int_cmd_req_nop_r;
logic                       int_cmd_req_nop;
logic                       int_flit_ongoing_nxt;
logic                       int_flit_ongoing_r;
logic                       int_prev_cmd_pyld_r;
logic                       int_prev_cmd_flush_r;
logic                       int_pyld_flush_ack_r;
logic                       int_flush_nop_ack_r;
logic                       int_spif_flush_ack_r;
logic                       int_spif_stall_req_r;

// Generate an acknowledge for flush command and block XTLH interface
always_ff @(posedge core_clk or negedge core_rst_n) begin : spif_flush_PROC
  if(!core_rst_n) begin
    int_spif_flush_ack_r  <= #TP 1'b0;
    int_spif_stall_req_r  <= #TP 1'b0;
  end else if (xdlh_xtlh_cmd.tx_cmd == CMD_FLUSH_XTLH) begin
    if(int_spif_flush_ack_r && !xdlh_xtlh_cmd.req) begin
      int_spif_flush_ack_r  <= #TP 1'b0;
      int_spif_stall_req_r  <= #TP 1'b1;
    // If there is a flit in progress or flit is already presented on XTLH-2-XDLH interface then 
    // wait for it to be flushed before acknowledging the flush command and gating the XTLH interface.
    end else if(xdlh_xtlh_cmd.req && !(int_flit_ongoing_nxt || (xtlh_flit_in.sof && !rstctl_core_flush_req))) begin
      int_spif_flush_ack_r  <= #TP 1'b1;
      int_spif_stall_req_r  <= #TP 1'b1;
    end
  end else begin
    int_spif_flush_ack_r  <= #TP 1'b0;
    int_spif_stall_req_r  <= #TP 1'b0;
  end
end

always_comb begin
  if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET)
    int_flit_ongoing_nxt = 1'b0;
  else if(int_flit_ongoing_r && !xtlh_fm_nop_halt && xtlh_flit_in.eof[1])
    int_flit_ongoing_nxt = 1'b0;
  else if(!xtlh_fm_nop_halt && xtlh_flit_in.sof)
    int_flit_ongoing_nxt = 1'b1;
  else
    int_flit_ongoing_nxt = int_flit_ongoing_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_ongoing_PROC
  if(!core_rst_n)
    int_flit_ongoing_r    <= #TP 1'b0;
  else begin
    int_flit_ongoing_r    <= #TP int_flit_ongoing_nxt;
  end
end : flit_ongoing_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : pyld_en_PROC
  if(!core_rst_n)
    xtlh_fm_nop_pyld_en <= #TP 1'b0;
  else begin
    if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET)
      xtlh_fm_nop_pyld_en <= #TP 1'b0;
    else if(flit_mode_en && (xdlh_xtlh_cmd.tx_cmd == CMD_PYLD) && xdlh_xtlh_cmd.req)
      xtlh_fm_nop_pyld_en <= #TP 1'b1;
  end
end

// Generate an acknowledge for flush command during payload while halted (retry buffer full scenario)
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_pyld_flush_ack_r  <= #TP 1'b0;
  else begin
    if(int_pyld_flush_ack_r && !xdlh_xtlh_cmd.req)
      int_pyld_flush_ack_r  <= #TP 1'b0;
    else if(int_prev_cmd_pyld_r && !int_flit_ongoing_r && (xdlh_xtlh_cmd.tx_cmd == CMD_FLUSH_XTLH) && xdlh_xtlh_cmd.req)
      int_pyld_flush_ack_r  <= #TP 1'b1;
  end
end

// Generate an acknowledge for nop command during flush 
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_flush_nop_ack_r  <= #TP 1'b0;
  else begin
    if(int_flush_nop_ack_r && !xdlh_xtlh_cmd.req)
      int_flush_nop_ack_r  <= #TP 1'b0;
    else if(int_prev_cmd_flush_r && !int_flit_ongoing_r && (xdlh_xtlh_cmd.tx_cmd == CMD_NOP) && xdlh_xtlh_cmd.req)
      int_flush_nop_ack_r  <= #TP 1'b1;
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_en_PROC
  if(!core_rst_n) begin
    int_cmd_req_nop_r     <= #TP 1'b0;
    int_prev_cmd_pyld_r   <= #TP 1'b0;
    int_prev_cmd_flush_r  <= #TP 1'b0;
  end else begin
    int_prev_cmd_pyld_r <= #TP (xdlh_xtlh_cmd.tx_cmd == CMD_PYLD);
    int_prev_cmd_flush_r <= #TP (xdlh_xtlh_cmd.tx_cmd == CMD_FLUSH_XTLH);
    if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET)
      int_cmd_req_nop_r <= #TP 1'b0;
    else if((xdlh_xtlh_cmd.tx_cmd == CMD_PYLD) && xdlh_xtlh_cmd.req)
      int_cmd_req_nop_r <= #TP 1'b0;
    else if((xdlh_xtlh_cmd.tx_cmd inside {CMD_FLUSH_XTLH, CMD_NOP}) && xdlh_xtlh_cmd.req && !spif_enable)
      int_cmd_req_nop_r <= #TP 1'b1;
  end
end : nop_en_PROC

// Datastream started
always_ff @(posedge core_clk or negedge core_rst_n) begin : datastream_PROC
  if(!core_rst_n)
    int_datastream_r <= #TP 1'b0;
  else begin
    if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET)
      int_datastream_r  <= #TP 1'b0;
    else if(!halt_in) begin
      // EOF and not requesting NOP
      if(xtlh_fm_nop_flit.eof[1] && xtlh_flit_in.data_valid && !int_cmd_req_nop)
        int_datastream_r <= #TP 1'b1;
      else if(xtlh_flit_in.enf && xtlh_flit_in.eof[1])
        int_datastream_r <= #TP 1'b0;
      else
        int_datastream_r <= #TP int_datastream_r;
    end else if((xdlh_xtlh_cmd.tx_cmd == CMD_FLUSH_XTLH) && xdlh_xtlh_cmd.req && !int_flit_ongoing_r)
        int_datastream_r <= #TP 1'b0;
  end
end : datastream_PROC

assign int_cmd_req_nop = int_cmd_req_nop_r;

// When NOP is requested from the lower layer wait until data is available from the upper layer
always_comb begin : nop_req_PROC
  int_req_nop = 1'b0;
  if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET)
    int_req_nop = 1'b0;
  // Switching to NOP Flits and previous was payload Flit
  // Wait for EOF before switching to NOP's
  else if(int_cmd_req_nop && int_datastream_r && int_start_nop_r)
    int_req_nop = 1'b1;
  // Request to send NOP Flits and not previously in data stream
  else if(int_cmd_req_nop && !int_datastream_r)
    int_req_nop = 1'b1;
  // Request to stop sending NOP Flits wait for the end of the current NOP Flit
  else if(int_stop_nop_r)
    int_req_nop = 1'b0;
  else
    int_req_nop = int_req_nop_r;
end : nop_req_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_cnt_PROC
  if(!core_rst_n) begin
    nop_dw_cnt_r        <= #TP 'h0;
    int_req_nop_r       <= #TP 1'b0;
    int_stop_nop_r      <= #TP 1'b0;
    int_start_nop_r     <= #TP 1'b0;
    int_nop_ack_r       <= #TP 1'b0;
  end else begin
    int_nop_ack_r       <= #TP int_nop_ack;
    if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET) begin
      nop_dw_cnt_r      <= #TP 'h0;
      int_req_nop_r     <= #TP 1'b0;
      int_stop_nop_r    <= #TP 1'b0;
      int_start_nop_r   <= #TP 1'b0;
    end else if(!halt_in) begin
      int_stop_nop_r    <= #TP (int_req_nop_r && !int_cmd_req_nop && int_nop_enf && int_nop_eof[1] && xtlh_flit_in.sof);
      int_start_nop_r   <= #TP int_cmd_req_nop && xtlh_flit_in.eof[1];
      int_req_nop_r     <= #TP int_req_nop;
      if(nop_dw_cnt_r == P_NOP_DW_CNT - 1)
        nop_dw_cnt_r    <= #TP 'h0;
      else if(int_req_nop)
        nop_dw_cnt_r    <= #TP nop_dw_cnt_r + 1'b1;
      else
        nop_dw_cnt_r    <= #TP nop_dw_cnt_r;
    end
  end
end : nop_cnt_PROC

// Generate the EOF marker
assign int_nop_eof = (nop_dw_cnt_r == P_NOP_DW_CNT - 1) ? 2'b11 : 2'b00;
assign int_nop_enf = int_nop_eof[1];
assign int_nop_sof = int_req_nop && (nop_dw_cnt_r == 'h0);

// Command Acknowledge Generation
always_comb begin : cmd_ack_PROC
  if(!int_cmd_req_nop)
    int_nop_ack = 1'b0;
  else if(int_nop_sof && !halt_in)
    int_nop_ack = 1'b1;
  else
    int_nop_ack = int_nop_ack_r;
end : cmd_ack_PROC

// dummy instance of ras_dp_pipe just to generate flit protection signal depending on RAS DP configuration
logic [DATA_PAR_WD-1:0] flit_prot; 
ras_dp_pipe
 #(
  .PIPELINE_TYPE           (6                                ),
  .N_STAGES                (0                                ),
  .CAN_STALL               (0                                ),
  .BUS_PROTECT_GEN_EN      (1                                ),
  .BUS_PROTECT_CHK_EN      (0                                ),
  .PROT_TYPE               (`CX_RAS_PROT_TYPE                ),
  .PROT_RANGE              (`CX_RAS_PROT_RANGE               ),
  .PROT_WD                 ($bits(xtlh_fm_nop_flit.flit_prot)),
  .PARITY_MODE             (`CX_RAS_PARITY_MODE              ),
  .TOTAL_WIDTH             ($bits(xtlh_fm_nop_flit.data)     ),
  .EXCLUDE_PROT_WIDTH      (0                                )
) u_calc_zero_flit_prot (
  .clk                      ('0       ),
  .rst_n                    ('0       ),
  .en                       ('0       ),
  .din                      ('0       ),
  .din_prot                 ('0       ),
  .dout                     (         ),
  .dout_prot                (flit_prot),
  .bypass                   ('0       ),
  .stall                    ('0       ),
  .stallout                 (         ),
  .valid_in                 ('0       ),
  .halt_in                  ('0       ),
  .valid_out                (         ),
  .halt_out                 (         ),
  .ras_dp_err_inband_kbd_in ('0       ),
  .ras_dp_err_inband_kbd_out(         ),
  .ras_dp_err_log           (         ),
  .ras_dp_err_inj           ('0       )
);

// Output MUX Select between data from XTLH or NOP Flit
// If sending a NOP Flit back-pressure XTLH
always_comb begin : nop_mux_PROC
  if(int_req_nop) begin
    xtlh_fm_nop_flit.sof        = int_nop_sof;
    xtlh_fm_nop_flit.eof        = int_nop_eof;
    xtlh_fm_nop_flit.enf        = int_nop_enf;
    xtlh_fm_nop_flit.data       = {DW{1'b0}};
    xtlh_fm_nop_flit.data_valid = 1'b1;
    xtlh_fm_nop_flit.tlp_dv     = '0;
    xtlh_fm_nop_flit.retry_flit = 1'b0;
    xtlh_fm_nop_flit.expl_flit  = 1'b0;
    xtlh_fm_nop_flit.flit_type_s.err_inj_en = xtlh_flit_in.flit_type_s.err_inj_en;
    xtlh_fm_nop_flit.flit_type_s.flit_type  = NOP;
    xtlh_fm_nop_flit.flit_prot              = flit_prot; 
    xtlh_fm_nop_flit.ras_dp_err_inband_kbd  = '0;
    xtlh_fm_nop_halt            = xtlh_flit_in.data_valid;
    xtlh_fm_nop_ack             = int_nop_ack_r || int_pyld_flush_ack_r || int_flush_nop_ack_r;
  end else begin
    xtlh_fm_nop_halt            = halt_in;
    if(flit_mode_en && !int_spif_stall_req_r) begin
      xtlh_fm_nop_flit            = xtlh_flit_in;
      xtlh_fm_nop_ack             = '0;
    end else begin
      xtlh_fm_nop_flit            = '0;
      xtlh_fm_nop_halt            = int_spif_stall_req_r ? 1'b1 : '0;
      xtlh_fm_nop_ack             = int_spif_stall_req_r ? int_spif_flush_ack_r : '0;
    end
  end
end : nop_mux_PROC

endmodule
