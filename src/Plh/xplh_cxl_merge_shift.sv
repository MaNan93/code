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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_cxl_merge_shift.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Hander
// --- This module handles 128b, 256b and 512b datapath widths. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xplh_cxl_merge_shift
import cx_pl_pkg::P_NFM_NW;
import cx_pl_pkg::P_NFM_DW;

#(
    parameter   INST        = 0,             // The uniquifying parameter for each port logic instance.
    parameter   NW          = P_NFM_NW,      // Number of 32-bit dwords handled by the datapath each clock. This module supports 4, 8 and 16 
    parameter   DW          = P_NFM_DW,      // Width of datapath in bits.
    parameter   CXL_NW      = `CX_CXL_20_NW, // CXL Flit width in DWords
    parameter   CXL_DW      = (32*CXL_NW),   // CXL Flit width
    parameter   TP          = `TP            // Clock to Q delay (simulator insurance)
)

                           (
    // ---- inputs ---------------
    input                  core_clk,
    input                  core_rst_n,
    input                  cxl_mode_enable,              // Set to 1 when both sides enable/support/exchange CXL mode and current speed of the link is Gen3 or above
    input                  cxl_arb_pkt_pending,          // Indicates that the CXL.io Link Layer has accepted packets. It prevents the physical layer from sending EIOS
    input  [DW+32-1:0]     cxl_arb_data,                 // CXL flit for transmission.
    input  [NW-1:0]        cxl_arb_pad,                  // 1-4  for 4dword, indicates which DW is pad
    input  [NW:0]          cxl_arb_stp,                  // 1-4  for 4dword, indicates which DW is stp
    input  [NW:0]          cxl_arb_sdp,                  // 1-4  for 4dword, indicates which DW is sdp
    input  [NW:0]          cxl_arb_eot,                  // 1-4  for 4dword, indicates which DW is eot
    input                  xmlh_xdlh_halt,               // When set to 0 indicates that the physical layer has accepted the flit for transmission. When set to 1 halts the Arb/Mux.
    input                  xmlh_xdlh_rst_flit_alignment, // When set to 1 indicates that the LTSSM is moving to Recovery state after completing the current packet. The arbiter must place the new flit PID from byte 0.
    // ---- outputs ---------------
    output                 shifted_halt,
    output                 shifted_pkt_pending,
    output [DW-1:0]        shifted_data,
    output [NW-1:0]        shifted_pid,
    output [NW-1:0]        shifted_pad,
    output [NW-1:0]        shifted_stp,
    output [NW-1:0]        shifted_sdp,
    output [NW-1:0]        shifted_eot,
    output [NW-1:0]        shifted_next_stp,
    output [NW-1:0]        shifted_next_sdp,
    output [NW-1:0]        shifted_next_eot
);

// Registered output stage empty
reg empty_reg_out;
always @(posedge core_clk or negedge core_rst_n) 
    if ( !core_rst_n )
        empty_reg_out <= #TP 1;
    else if (xmlh_xdlh_rst_flit_alignment) 
        empty_reg_out <= #TP 1;
    else
        empty_reg_out <= #TP 0;

reg  [4:0] dw_acc;
wire [4:0] next_dw_acc;
wire shift_en;
wire load_en;

assign shift_en = ~xmlh_xdlh_halt || (empty_reg_out && cxl_mode_enable);
assign shifted_halt = dw_acc == CXL_NW || !shift_en;
assign load_en = !shifted_halt;

assign next_dw_acc = (load_en)? dw_acc + 1 : (shift_en)? 0 : dw_acc;

wire shifted_nxt_pending;   // Packet pending pipeline register
reg  shifted_pkt_pending_d; // Extends packet pending for one additional cycle in CXL mode

assign shifted_pkt_pending = cxl_arb_pkt_pending || shifted_nxt_pending || shifted_pkt_pending_d;

always @(posedge core_clk or negedge core_rst_n) begin
    if ( !core_rst_n )
        shifted_pkt_pending_d <= #TP '0;
    else if (shift_en && cxl_mode_enable)
        shifted_pkt_pending_d <= #TP shifted_nxt_pending;
end

localparam MERGE_NW = 2 * NW;
localparam MERGE_DW = 32 * MERGE_NW;

wire [MERGE_NW-1:0] merged_pid;
reg  [MERGE_NW-1:0] merged_stp;
reg  [MERGE_NW-1:0] merged_sdp;
reg  [MERGE_NW-1:0] merged_eot;
reg  [MERGE_DW-1:0] merged_data;
reg  [NW-1:0] acc_pid;
reg  [NW-1:0] acc_stp;
reg  [NW-1:0] acc_sdp;
reg  [NW-1:0] acc_eot;
reg  [DW-1:0] acc_data;

assign merged_pid = 1 << dw_acc;

always_comb begin : merged_datapath_PROC
//  ----------------------------------------------------------------------------------
//  | ARB/MUX Output                                                                 |
//  |--------------------------------------------------------------------------------|
//  | 1st cycle : PID D0  D0  D0  D0 D0  D0  D0  D0  D0  D0  D0  D0  D0  D0  D0  D0  |
//  ----------------------------------------------------------------------------------
//  ------------------------------------------------------------------------------------------------------------------------------------------
//  | Accumulation Register for x8 configs                                                                                                   |
//  ------------------------------------------------------------------------------------------------------------------------------------------
//  |  0 | PID  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |  0   -   -   -   -   -   -   -   -   -   -   -   -   -   -   -  |
//  |  1 |  0  PID  0   0   0   0   0   0   0   0   0   0   0   0   0   0  |  0   0   -   -   -   -   -   -   -   -   -   -   -   -   -   -  |
//  |  2 |  0   0  PID  0   0   0   0   0   0   0   0   0   0   0   0   0  |  0   0   0   -   -   -   -   -   -   -   -   -   -   -   -   -  |
//  |  3 |  0   0   0  PID  0   0   0   0   0   0   0   0   0   0   0   0  |  0   0   0   0   -   -   -   -   -   -   -   -   -   -   -   -  |
//  |  4 |  0   0   0   0  PID  0   0   0   0   0   0   0   0   0   0   0  |  0   0   0   0   0   -   -   -   -   -   -   -   -   -   -   -  |
//  |  5 |  0   0   0   0   0  PID  0   0   0   0   0   0   0   0   0   0  |  0   0   0   0   0   0   -   -   -   -   -   -   -   -   -   -  |
//  |  6 |  0   0   0   0   0   0  PID  0   0   0   0   0   0   0   0   0  |  0   0   0   0   0   0   0   -   -   -   -   -   -   -   -   -  |
//  |  7 |  0   0   0   0   0   0   0  PID  0   0   0   0   0   0   0   0  |  0   0   0   0   0   0   0   0   -   -   -   -   -   -   -   -  |
//  |  8 |  0   0   0   0   0   0   0   0  PID  0   0   0   0   0   0   0  |  0   0   0   0   0   0   0   0   0   -   -   -   -   -   -   -  |
//  |  9 |  0   0   0   0   0   0   0   0   0  PID  0   0   0   0   0   0  |  0   0   0   0   0   0   0   0   0   0   -   -   -   -   -   -  |
//  | 10 |  0   0   0   0   0   0   0   0   0   0  PID  0   0   0   0   0  |  0   0   0   0   0   0   0   0   0   0   0   -   -   -   -   -  |
//  | 10 |  0   0   0   0   0   0   0   0   0   0   0  PID  0   0   0   0  |  0   0   0   0   0   0   0   0   0   0   0   0   -   -   -   -  |
//  | 12 |  0   0   0   0   0   0   0   0   0   0   0   0  PID  0   0   0  |  0   0   0   0   0   0   0   0   0   0   0   0   0   -   -   -  |
//  | 13 |  0   0   0   0   0   0   0   0   0   0   0   0   0  PID  0   0  |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   -   -  |
//  | 14 |  0   0   0   0   0   0   0   0   0   0   0   0   0   0  PID  0  |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   -  |
//  | 15 |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  PID |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  |
//  | 16 |  0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0  | HALT CYCLE                                                      |
//  ------------------------------------------------------------------------------------------------------------------------------------------
    unique case(dw_acc)
        1 : begin merged_data = {{14{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  1*32]} ; end
        2 : begin merged_data = {{13{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  2*32]} ; end
        3 : begin merged_data = {{12{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  3*32]} ; end
        4 : begin merged_data = {{11{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  4*32]} ; end
        5 : begin merged_data = {{10{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  5*32]} ; end
        6 : begin merged_data = {{ 9{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  6*32]} ; end
        7 : begin merged_data = {{ 8{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  7*32]} ; end
        8 : begin merged_data = {{ 7{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  8*32]} ; end
        9 : begin merged_data = {{ 6{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +:  9*32]} ; end
        10: begin merged_data = {{ 5{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +: 10*32]} ; end
        11: begin merged_data = {{ 4{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +: 11*32]} ; end
        12: begin merged_data = {{ 3{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +: 12*32]} ; end
        13: begin merged_data = {{ 2{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +: 13*32]} ; end
        14: begin merged_data = {{ 1{32'h0}}, cxl_arb_data[0 +: DW+32], acc_data[0 +: 14*32]} ; end
        15: begin merged_data = {             cxl_arb_data[0 +: DW+32], acc_data[0 +: 15*32]} ; end
        16: begin merged_data = {{16{32'h0}},                           acc_data[0 +: 16*32]} ; end
        default : begin merged_data = {{15{32'h0}}, cxl_arb_data[0 +: DW+32]                      } ; end
    endcase
end

always_comb begin : merged_ctrl_bits_PROC
    merged_eot       = merged_ctrl_bits(dw_acc, cxl_arb_eot, acc_eot);
    merged_stp       = merged_ctrl_bits(dw_acc, cxl_arb_stp, acc_stp);
    merged_sdp       = merged_ctrl_bits(dw_acc, cxl_arb_sdp, acc_sdp);
end

function automatic [MERGE_NW-1:0] merged_ctrl_bits(input [4:0] dw_acc, input [NW:0] xtd_ctrl, input [NW-1:0] acc_ctrl);
    begin
    unique case(dw_acc)
            1 : begin merged_ctrl_bits = {14'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  1]} ; end
            2 : begin merged_ctrl_bits = {13'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  2]} ; end
            3 : begin merged_ctrl_bits = {12'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  3]} ; end
            4 : begin merged_ctrl_bits = {11'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  4]} ; end
            5 : begin merged_ctrl_bits = {10'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  5]} ; end
            6 : begin merged_ctrl_bits = { 9'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  6]} ; end
            7 : begin merged_ctrl_bits = { 8'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  7]} ; end
            8 : begin merged_ctrl_bits = { 7'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  8]} ; end
            9 : begin merged_ctrl_bits = { 6'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +:  9]} ; end
            10: begin merged_ctrl_bits = { 5'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +: 10]} ; end
            11: begin merged_ctrl_bits = { 4'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +: 11]} ; end
            12: begin merged_ctrl_bits = { 3'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +: 12]} ; end
            13: begin merged_ctrl_bits = { 2'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +: 13]} ; end
            14: begin merged_ctrl_bits = { 1'b0, xtd_ctrl[0 +: NW+1], acc_ctrl[0 +: 14]} ; end
            15: begin merged_ctrl_bits = {       xtd_ctrl[0 +: NW+1], acc_ctrl[0 +: 15]} ; end
            16: begin merged_ctrl_bits = {16'b0,                      acc_ctrl[0 +: 16]} ; end
      default : begin merged_ctrl_bits = {15'b0, xtd_ctrl[0 +: NW+1]                   } ; end
    endcase
    end
endfunction

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        dw_acc        <= #TP 0;
        acc_pid       <= #TP 0;
        acc_stp       <= #TP 0;
        acc_sdp       <= #TP 0;
        acc_eot       <= #TP 0;
        acc_data      <= #TP 0;
    end else if (xmlh_xdlh_rst_flit_alignment) begin
        dw_acc        <= #TP 0;
        acc_pid       <= #TP 0;
        acc_stp       <= #TP 0;
        acc_sdp       <= #TP 0;
        acc_eot       <= #TP 0;
        acc_data      <= #TP 0;
    end else if (shift_en && cxl_mode_enable) begin
        dw_acc        <= #TP next_dw_acc;
        acc_pid       <= #TP merged_pid[NW +: NW];
        acc_stp       <= #TP merged_stp[NW +: NW];
        acc_sdp       <= #TP merged_sdp[NW +: NW];
        acc_eot       <= #TP merged_eot[NW +: NW];
        acc_data      <= #TP merged_data[DW +: DW];
    end
end

// Next signals when propagating signals in PCIe mode
assign shifted_next_stp = (shifted_nxt_pending && !shift_en) ? shifted_stp : merged_stp[0 +: NW];
assign shifted_next_sdp = (shifted_nxt_pending && !shift_en) ? shifted_sdp : merged_sdp[0 +: NW];
assign shifted_next_eot = (shifted_nxt_pending && !shift_en) ? shifted_eot : merged_eot[0 +: NW];

localparam OUTPUT_REG_WD = 4*NW + DW + (NW + 1);

delay_n_w_enable
 // Registered outputs
#(.N(1), .WD(OUTPUT_REG_WD)) u_out_delay_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (shift_en),
    .din        ({ cxl_arb_pkt_pending, cxl_arb_pad, merged_pid[0 +: NW], merged_stp[0 +: NW],  merged_sdp[0 +: NW],  merged_eot[0 +: NW], merged_data[0 +: DW]}),
    .dout       ({ shifted_nxt_pending, shifted_pad, shifted_pid,         shifted_stp,          shifted_sdp,          shifted_eot,         shifted_data})
);

endmodule

