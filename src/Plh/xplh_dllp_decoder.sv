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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_dllp_decoder.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: .
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
 
 module xplh_dllp_decoder
import cx_pl_pkg::dllp_struct;
import cx_pl_pkg::dllp_type_e;
  // Parameters
  #(
    parameter NW = `CX_NW,
    parameter DW = `CX_DW,
    parameter P_DW = (32*NW),
    parameter INST = 0,
    parameter DLLP_WD = 8,
    parameter MATCH_TYPE = 1'b1,
    parameter TP = `TP
  )
  
                         (
//--------------------------------Inputs-----------------------------//
    input    logic                    clk,                // Clock
    input    logic                    rst_n,              // Reset
    input    logic                    halt,               // Halt from layer1
    input    dllp_type_e              dllp_type,
    input    logic  [NW - 1 : 0]      sdp,                // Indicates which DWORD is SDP
    input    logic  [DW - 1 : 0]      data,           // Data from the Data Link Layer to transmit  
    input    logic  [NW - 1 : 0]      eot,                // 1 bit per dword, indicates which dword is eot
    input    logic  [2:0]             current_data_rate,  // 00 - gen1, 01 - gen2, 10 - gen3, 11 - gen4
    input                             flit_halt,          // Flit halt
    input           [DW - 1 : 0]      flit_data,          // Flit data
    input                             flit_mode_en,       // Flit Mode Enable
    input    logic  [1 : 0]           eof,                // End of Flit Marker
    input    logic                    sof,                // Start of Flit Marker

//------------------------------Outputs---------------------------//
    output   dllp_struct  xplh_pm_dllp_ack
);

dllp_struct  int_pm_dllp_ack;

logic int_flit_mode_en_r;

always_ff @(posedge clk or negedge rst_n) begin : flit_mode_en_PROC
  if(!rst_n)
    int_flit_mode_en_r  <= #TP '0;
  else
    int_flit_mode_en_r  <= #TP flit_mode_en;
end : flit_mode_en_PROC

logic [5:0][7:0]  int_dlp_bytes;
dllp_struct       int_fm_pm_dllp_ack, int_fm_pm_dllp_ack_r; 

// Accumulate DLP bytes in Flit Mode
always_ff @(posedge clk or negedge rst_n) begin : dlp_byte_PROC
  if(!rst_n)
    int_dlp_bytes <= #TP '0;
  else begin
    if(!flit_halt) begin
      int_dlp_bytes         <= #TP int_dlp_bytes;
      if(&eof)
        int_dlp_bytes       <= #TP flit_data[DW-(14*8)-1 -:48];
      else if(sof)
        int_dlp_bytes       <= #TP '0;
    end else 
      int_dlp_bytes         <= #TP int_dlp_bytes;
  end
end : dlp_byte_PROC

always_comb begin : dllp_ack_enc_PROC
  int_fm_pm_dllp_ack = '0;
  if(!int_dlp_bytes[0][4] && (dllp_type_e'(int_dlp_bytes[2]) == dllp_type)) begin
    int_fm_pm_dllp_ack.valid = 1'b1;
    int_fm_pm_dllp_ack.dllp_type = dllp_type;
    int_fm_pm_dllp_ack.pyld = 24'b0;
  end
end : dllp_ack_enc_PROC

always_ff @(posedge clk or negedge rst_n) begin : dlp_ack_r_PROC
  if(!rst_n)
    int_fm_pm_dllp_ack_r  <= #TP '0;
  else begin
    if(int_fm_pm_dllp_ack.valid)
      int_fm_pm_dllp_ack_r  <= #TP int_fm_pm_dllp_ack;
    else
      int_fm_pm_dllp_ack_r  <= #TP '0;
  end
end : dlp_ack_r_PROC

// ----------------------------------------------------------------------------
// Instantiation of dllp detect block 
// ----------------------------------------------------------------------------
xplh_detect_dllp

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8)
  ) u_xplh_detect_dllp (
    // Inputs
    .clk                  (clk),
    .rst_n                (rst_n),
    .dllp_type            (dllp_type),
    .sdp                  (sdp),
    .data                 (data),
    .eot                  (eot),
    .current_data_rate    (current_data_rate),
    .halt                 (halt),
    // Outputs
    .xplh_pm_dllp_ack     (int_pm_dllp_ack)
);

assign xplh_pm_dllp_ack = int_flit_mode_en_r ? int_fm_pm_dllp_ack_r : int_pm_dllp_ack;

endmodule
