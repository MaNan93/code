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
// ---    $DateTime: 2023/12/08 08:15:20 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_err_inj_ctrl_dp.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// --- This is the error injection control dp which is 
// --- responsible for storing the data until the next sof
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xtlh_err_inj_ctrl_dp
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  xtlh_ms_pkg::flit_marker_struct;
  import  xtlh_ms_pkg::P_DW_LAST;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import xtlh_ms_pkg::P_NW_PROT;
 
                             (
  input                                     core_clk,
  input                                     core_rst_n,
  input   [P_NW_CNT_WD-1:0]                 next_sot_cnt,
  input   [P_NW - 1 : 0]                    sot,                        // Start of TLP
  input   [P_NW - 1 : 0]                    eot,                        // End of TLP
  input   [P_DW - 1 : 0]                    data,                       // Input DATA
  input   flit_marker_struct  [P_NW-1:0]    flit_marker,                // Flit Marker
  input                                     push,                       // Active high Push Signal for the PIPELINE FIFO
  input                                     pop_n,                      // Active low POP Signal for the PIPELINE FIFO
  input                                     bypass_pipe,                // Bypass PIPE 
  input                                     xtlh_err_inj_dv,            // Error injection Data Valid from FSM
  output  logic    [P_NW_CNT_WD - 1 : 0]    xtlh_err_inj_next_sot_cnt,  // Output Start of TLP
  output  logic    [P_NW - 1 : 0]           xtlh_err_inj_sot,           // Output Start of TLP
  output  logic    [P_NW - 1 : 0]           xtlh_err_inj_eot,           // Output End of TLP 
  output  logic    [P_DW - 1 : 0]           xtlh_err_inj_data,          // Output DATA
  output  flit_marker_struct  [P_NW-1:0]    xtlh_err_inj_flit_marker,   // Output Flit Marker
  output  logic                             pipe_dv                     // Output PIPE Data Vaild to the FSM
  ,
  input                                     ras_dp_err_inband_kbd,              // Input ras_dp_err_inband_kbd
  output logic                              xtlh_err_inj_ras_dp_err_inband_kbd, // Output ras_dp_err_inband_kbd
  input   [P_NW_PROT-1:0]                   prot,                               // Input Protection
  output  [P_NW_PROT-1:0]                   xtlh_err_inj_prot                   // Output Protection
);

localparam   FIFO_WIDTH      = P_NW_CNT_WD + 6*P_NW + P_DW + P_NW_PROT + 1;  // FIFO WIDTH
localparam   FIFO_DEPTH      = P_DW_LAST + 1;                                            // FIFO Depth


typedef struct packed {
logic              [P_NW-1:0]          sot;
logic              [P_NW_CNT_WD-1:0]   next_sot_cnt;
logic              [P_NW-1:0]          eot;
logic              [P_NW-1:0][31:0]    data;
flit_marker_struct [P_NW-1:0]          flit_marker;
logic              [P_NW_PROT-1:0]     prot;
logic                                  ras_dp_err_inband_kbd;
} fifo_data_struct;

fifo_data_struct                       int_fifo_in;             // PIPELINE FIFO INPUT
fifo_data_struct                       int_fifo_out;            // PIPELINE FIFO OUTPUT
logic               [P_NW - 1 : 0]     int_sot_pipe;            // SOT OUT FROM THE PIPE 
logic [P_NW_CNT_WD - 1 : 0]            int_next_sot_cnt_pipe;   // SOT OUT FROM THE PIPE 
logic [P_NW_CNT_WD - 1 : 0]            int_next_sot_cnt_bp;   // SOT OUT FROM THE PIPE 
logic               [P_NW - 1 : 0]     int_eot_pipe;            // EOT OUT FROM THE PIPE
logic               [P_DW - 1 : 0]     int_data_pipe;           // DATA OUT FROM THE PIPE
flit_marker_struct  [P_NW - 1 : 0]     int_flit_marker_pipe;    // FLIT_MARKER OUT FROM THE PIPE 
logic               [P_NW - 1 : 0]     int_sot_bp;              // SOT OUT FROM THE BYPASS MUX
logic               [P_NW - 1 : 0]     int_eot_bp;              // EOT OUT FROM THE BYPASS MUX
logic               [P_DW - 1 : 0]     int_data_bp;             // DATA OUT FROM THE BYPASS MUX
flit_marker_struct  [P_NW - 1 : 0]     int_flit_marker_bp;      // FLIT_MARKER OUT FROM THE PIPE 
logic               [P_NW_PROT-1:0]    int_prot_pipe;                 // Output Protection From the PIPE
logic                                  int_ras_dp_err_inband_kbd_pipe;// Output ras_dp_err_inband_kbd From the PIPE
logic               [P_NW_PROT-1:0]    int_prot_bp;                   // Output Protection From the Bypass Multiplexer
logic                                  int_ras_dp_err_inband_kbd_bp;  // Output ras_dp_err_inband_kbd From the Bypass Multiplexer

//************************************************************************\\
//---------------------- DATA PATH Implementation ------------------------\\
//************************************************************************\\
pipe_w_hs
 #(
            .WD             (FIFO_WIDTH),
            .FORWARD_PIPE   (1),
            .BACKWARD_PIPE  (1),
            .FIFO_DEPTH     (FIFO_DEPTH)
            )
u_pipe
            (
            .clk        (core_clk),
            .rst_n      (core_rst_n),
            .valid_in   (push),
            .d_in       (int_fifo_in),
            .halt_out   (halt_out_unused),
            .valid_out  (pipe_dv),
            .d_out      (int_fifo_out),
            .halt_in    (pop_n)
            );


//Data in to the PIPELINE
assign int_fifo_in.sot         = sot;         // Input Start of TLP TO The FIFO 
assign int_fifo_in.next_sot_cnt = next_sot_cnt;         // Input Start of TLP TO The FIFO 
assign int_fifo_in.eot         = eot;         // Input End of TLP TO The FIFO 
assign int_fifo_in.data        = data;        // Input Data To The FIFO      
assign int_fifo_in.flit_marker = flit_marker; // Input Flit Marker To The FIFO 
assign int_fifo_in.prot                  = prot;                  // Input Protection TO The FIFO if ras-dp is configured
assign int_fifo_in.ras_dp_err_inband_kbd = ras_dp_err_inband_kbd; // Input ras_dp_err_inband_kbd TO The FIFO if ras-dp is configured

//Data out from the PIPELINE
assign int_sot_pipe         = int_fifo_out.sot;         // Output Start of TLP From The FIFO    
assign int_next_sot_cnt_pipe = int_fifo_out.next_sot_cnt;
assign int_eot_pipe         = int_fifo_out.eot;         // Output End of TLP From The FIFO    
assign int_data_pipe        = int_fifo_out.data;        // Output Data From The FIFO
assign int_flit_marker_pipe = int_fifo_out.flit_marker; // Output Flit Marker From The FIFO  
assign int_prot_pipe                  = int_fifo_out.prot;                  // Output Protection From The FIFO if ras-dp is configured
assign int_ras_dp_err_inband_kbd_pipe = int_fifo_out.ras_dp_err_inband_kbd; // Output ras_dp_err_inband_kbd From The FIFO if ras-dp is configured

//Bypass PIPELINE Multiplexer
assign int_sot_bp                   = bypass_pipe ? sot         : int_sot_pipe;            // Output sot From The bypass multiplexer
assign int_next_sot_cnt_bp          = bypass_pipe ? next_sot_cnt : int_next_sot_cnt_pipe;            // Output sot From The bypass multiplexer
assign int_eot_bp                   = bypass_pipe ? eot         : int_eot_pipe;            // Output eot From The bypass multiplexer
assign int_data_bp                  = bypass_pipe ? data        : int_data_pipe;           // Output Data From The bypass multiplexer
assign int_flit_marker_bp           = bypass_pipe ? flit_marker : int_flit_marker_pipe;    // Output Flit Marker From The bypass multiplexer
assign int_prot_bp                  = bypass_pipe ? prot                  : int_prot_pipe;                   // Output Protection From The bypass multiplexer if ras-dp is configured
assign int_ras_dp_err_inband_kbd_bp = bypass_pipe ? ras_dp_err_inband_kbd : int_ras_dp_err_inband_kbd_pipe;  // Output ras_dp_err_inband_kbd From The bypass multiplexer if ras-dp is configured

//Stop Sending Data if there is no Data Valid
assign xtlh_err_inj_sot         = xtlh_err_inj_dv ?  int_sot_bp         : '0;    // Masking the sot to the output if no dv 
assign xtlh_err_inj_next_sot_cnt = xtlh_err_inj_dv ?  int_next_sot_cnt_bp : '0;    // Masking the sot to the output if no dv 
assign xtlh_err_inj_eot         = xtlh_err_inj_dv ?  int_eot_bp         : '0;    // Masking the eot to the output if no dv 
assign xtlh_err_inj_data        = xtlh_err_inj_dv ?  int_data_bp        : '0;    // Masking the Data to the output if no dv 
assign xtlh_err_inj_flit_marker = xtlh_err_inj_dv ?  int_flit_marker_bp : '0;    // Masking the flit marker to the output if no dv 
assign xtlh_err_inj_prot                  = xtlh_err_inj_dv ? int_prot_bp                  : '0;   // Masking the protection to the output if no dv 
assign xtlh_err_inj_ras_dp_err_inband_kbd = xtlh_err_inj_dv ? int_ras_dp_err_inband_kbd_bp : '0;   // Masking the ras_dp_err_inband_kbd to the output if no dv 


endmodule
