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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_pm_dllp_decoder.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
 
 module xplh_pm_dllp_decoder
import cx_pl_pkg::dllp_type_e;
import cx_pl_pkg::dllp_struct;
import cx_pl_pkg::PM_ENTER_L1;
import cx_pl_pkg::PM_ENTER_L23;
import cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
import cx_pl_pkg::NOP_DLLP;
import cx_pl_pkg::PM_REQUEST_ACK;
  // Parameters
  #(
    parameter NW = `CX_NW,
    parameter DW = `CX_DW,
    parameter P_DW = (32*NW),
    parameter INST = 0,
    parameter DLLP_WD = 8,
    parameter MATCH_TYPE = 1'b1
  )
  
                            (
//--------------------------------Inputs-----------------------------//
    input    logic                    clk,                // Clock
    input    logic                    rst_n,              // Reset
    input    logic                    cfg_upstream_port,  // Upstream port when it is high
    input    logic                    halt,               // Halt from layer1
    input    logic  [NW - 1 : 0]      sdp,                // Indicates which DWORD is SDP
    input    logic  [DW - 1 : 0]      data,               // Data from the Data Link Layer to transmit  
    input    logic  [NW - 1 : 0]      eot,                // 1 bit per dword, indicates which dword is eot
    input    logic  [2:0]             current_data_rate,  // 00 - gen1, 01 - gen2, 10 - gen3, 11 - gen4
    input                             flit_halt,          // Flit Mode Halt from lower layer
    input           [DW - 1 : 0]      flit_data,          // Flit Mode data
    input                             flit_mode_en,       // Flit Mode Enable
    input    logic  [1 : 0]           eof,                // End of Flit Marker
    input    logic                    sof,                // Start of Flit Marker

//------------------------------Outputs---------------------------//
    output   dllp_struct  xplh_pm_dllp_ack
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------

//----------------------------------------------------------------------------
// Net Declarations
//-------------------------------------------------------------------------
dllp_struct xplh_pm_dllp_ack_l1;
dllp_struct xplh_pm_dllp_ack_l23;
dllp_struct xplh_pm_dllp_ack_acst_l1;
dllp_struct xplh_pm_dllp_ack_req;
dllp_struct xplh_pm_dllp_ack_nop;
//
dllp_type_e int_l23_dllp_type;
dllp_type_e int_l1pm_dllp_type;
dllp_type_e int_l1aspm_dllp_type;
dllp_type_e int_pmack_dllp_type;
dllp_type_e int_nop_dllp_type; 
//----------------------------------------------------------------------------
// Register Declarations
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Instantiation of dllp detect block
// ----------------------------------------------------------------------------
assign int_l23_dllp_type    = PM_ENTER_L23;
assign int_l1pm_dllp_type   = PM_ENTER_L1;
assign int_l1aspm_dllp_type = PM_ACTIVE_STATE_REQUEST_L1;
assign int_pmack_dllp_type  = PM_REQUEST_ACK;
assign int_nop_dllp_type    = NOP_DLLP;

xplh_dllp_decoder

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8)
  ) u_xplh_detect_dllp_a (
    // Inputs
    .clk                  (clk),
    .rst_n                (rst_n),
    .dllp_type          (int_l1pm_dllp_type),
    .sdp                  (sdp),
    .data                 (data),
    .eot                  (eot),
    .current_data_rate    (current_data_rate),
    .halt                 (halt),
    .flit_halt            (flit_halt),
    .flit_data            (flit_data),
    .flit_mode_en         (flit_mode_en),
    .eof                  (eof),
    .sof                  (sof),
    // Outputs
    .xplh_pm_dllp_ack     (xplh_pm_dllp_ack_l1)
);


xplh_dllp_decoder

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8)
  ) u_xplh_detect_dllp_b (
    // Inputs
    .clk                  (clk),
    .rst_n                (rst_n),
    .dllp_type          (int_l23_dllp_type),
    .sdp                  (sdp),
    .data                 (data),
    .eot                  (eot),
    .current_data_rate    (current_data_rate),
    .halt                 (halt),
    .flit_halt            (flit_halt),
    .flit_data            (flit_data),
    .flit_mode_en         (flit_mode_en),
    .eof                  (eof),
    .sof                  (sof),
    // Outputs
    .xplh_pm_dllp_ack     (xplh_pm_dllp_ack_l23)
);

xplh_dllp_decoder

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8)
  ) u_xplh_detect_dllp_c (
    // Inputs
    .clk                  (clk),
    .rst_n                (rst_n),
    .dllp_type          (int_l1aspm_dllp_type),
    .sdp                  (sdp),
    .data                 (data),
    .eot                  (eot),
    .current_data_rate    (current_data_rate),
    .halt                 (halt),
    .flit_halt            (flit_halt),
    .flit_data            (flit_data),
    .flit_mode_en         (flit_mode_en),
    .eof                  (eof),
    .sof                  (sof),
    // Outputs
    .xplh_pm_dllp_ack     (xplh_pm_dllp_ack_acst_l1)
);

xplh_dllp_decoder

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8)
  ) u_xplh_detect_dllp_d  (
    // Inputs
    .clk                  (clk),
    .rst_n                (rst_n),
    .dllp_type          (int_pmack_dllp_type),
    .sdp                  (sdp),
    .data                 (data),
    .eot                  (eot),
    .current_data_rate    (current_data_rate),
    .halt                 (halt),
    .flit_halt            (flit_halt),
    .flit_data            (flit_data),
    .flit_mode_en         (flit_mode_en),
    .eof                  (eof),
    .sof                  (sof),
    // Outputs
    .xplh_pm_dllp_ack     (xplh_pm_dllp_ack_req)
);


xplh_dllp_decoder

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8)
  ) u_xplh_detect_dllp_e (
    // Inputs
    .clk                  (clk),
    .rst_n                (rst_n),
    .dllp_type          (int_nop_dllp_type),
    .sdp                  (sdp),
    .data                 (data),
    .eot                  (eot),
    .current_data_rate    (current_data_rate),
    .halt                 (halt),
    .flit_halt            (flit_halt),
    .flit_data            (flit_data),
    .flit_mode_en         (flit_mode_en),
    .eof                  (eof),
    .sof                  (sof),
    // Outputs
    .xplh_pm_dllp_ack     (xplh_pm_dllp_ack_nop)
);


always_comb begin
    if (xplh_pm_dllp_ack_l1.valid) begin
        xplh_pm_dllp_ack.dllp_type = PM_ENTER_L1;
        xplh_pm_dllp_ack.valid     = 1'b1;
        xplh_pm_dllp_ack.pyld      = 24'b0;
    end
    else if (xplh_pm_dllp_ack_l23.valid) begin
        xplh_pm_dllp_ack.dllp_type= PM_ENTER_L23;
        xplh_pm_dllp_ack.valid     = 1'b1;
        xplh_pm_dllp_ack.pyld      = 24'b0;
    end
    else if (xplh_pm_dllp_ack_acst_l1.valid) begin
        xplh_pm_dllp_ack.dllp_type = PM_ACTIVE_STATE_REQUEST_L1;
        xplh_pm_dllp_ack.valid     = 1'b1;
        xplh_pm_dllp_ack.pyld      = 24'b0;
    end
    else if (xplh_pm_dllp_ack_req.valid) begin
        xplh_pm_dllp_ack.dllp_type = PM_REQUEST_ACK;
        xplh_pm_dllp_ack.valid     = 1'b1;
        xplh_pm_dllp_ack.pyld      = 24'b0;
    end
    else if (xplh_pm_dllp_ack_nop.valid) begin
        xplh_pm_dllp_ack.dllp_type = NOP_DLLP;
        xplh_pm_dllp_ack.valid     = 1'b1;
        xplh_pm_dllp_ack.pyld      = 24'b0;
    end
    else begin
        xplh_pm_dllp_ack.dllp_type = NOP_DLLP;
        xplh_pm_dllp_ack.valid     = 1'b0;
        xplh_pm_dllp_ack.pyld      = 24'b0;
    end
end



endmodule
