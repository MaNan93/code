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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_flit_serializer.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Flit Serializer
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module rplh_flit_serializer
#(
    parameter FLIT_WD         = 2048,                                     // Full Flit width in bits
    parameter FLIT_PROT_WD    = FLIT_WD/32*`CX_RAS_DWORD_PROT_WD,         // Full Flit Protection bits
    parameter NW              = `CX_PL_NW,                                // Number of 32-bit dwords handled by the datapath each clock.
    parameter DW              = 32*NW,                                    // Datapath Width in bits
    parameter DW_PROT_WD      = `CX_RAS_RPL_DATA_PROT_WD,                 // Datapath Protection bits
    parameter TP              = `TP                                       // Clock to Q delay (simulator insurance)
) 
                           (
// ---- inputs ---------------
    input                              core_clk,               // Core Clock
    input                              core_rst_n,             // Core Reset
    input  spif_pkg::stream_id_e       rplh_flitseq_stream,    // RPLH Flit Stream ID
    input                              rplh_flitseq_nullified, // RPLH Flit Nullified TLP Marker
    input                              rplh_flitseq_poisoned,  // RPLH Flit Poisoned TLP Marker
    input                              rplh_flitseq_dv,        // RPLH Flit Data Valid
    input [FLIT_WD-1:0]                rplh_flitseq_data,      // Full received flit
    input [FLIT_PROT_WD-1:0]           rplh_flitseq_data_prot, // Full received flit Protection bits
// ---- outputs ---------------
    output spif_pkg::stream_id_e       rplh_fmser_stream,      // Serialized Flit Stream ID
    output                             rplh_fmser_nullified,   // Serialized Flit Nullified TLP Marker
    output                             rplh_fmser_poisoned,    // Serialized Flit Poisoned TLP Marker
    output                             rplh_fmser_dv,          // Serialized Flit Data Valid
    output [DW-1:0]                    rplh_fmser_data         // Serialized Flit Data
    ,
    output [DW_PROT_WD-1:0]            rplh_fmser_data_prot    // Serialized Flit Data Protection
);

localparam DW_RATIO  = (FLIT_WD/DW) - 1;
localparam REGOUT_EN = 0 + 1;

logic  [DW_RATIO           -1:0] rplh_flitseq_dv_r, rplh_flitseq_dv_nxt;                // Flit Data Valid
logic  [DW_RATIO*DW        -1:0] rplh_flitseq_data_r, rplh_flitseq_data_nxt;            // Flit Data
logic  [DW_RATIO*DW_PROT_WD-1:0] rplh_flitseq_data_prot_r, rplh_flitseq_data_prot_nxt;  // Flit Data Protection
spif_pkg::stream_id_e            rplh_flitseq_stream_r, rplh_flitseq_stream_nxt;       // Flit Stream ID
logic                            rplh_flitseq_nullified_r, rplh_flitseq_nullified_nxt; // Flit Nullified Marker
logic                            rplh_flitseq_poisoned_r, rplh_flitseq_poisoned_nxt;   // Flit Poisoned Marker
logic                            rplh_fmser_dv_s;           // Serialized Flit Data Valid before output register
logic  [DW-1:0]                  rplh_fmser_data_s;         // Serialized Flit Data before output register
logic  [DW_PROT_WD-1:0]          rplh_fmser_data_prot_s;    // Serialized Flit Data Protection before output register
spif_pkg::stream_id_e            rplh_fmser_stream_s;       // Serialized Flit Stream ID before output register
logic                            rplh_fmser_nullified_s;    // Serialized Flit Nullified Marker before output register
logic                            rplh_fmser_poisoned_s;     // Serialized Flit Poisoned Marker before output register
logic                            rplh_link_dv_enable;

// -------------------------------------------------------------------------------------
// Output assignments
// -------------------------------------------------------------------------------------
assign rplh_fmser_dv_s        = rplh_flitseq_dv ? 1'b1 : ((|rplh_flitseq_dv_r) && rplh_link_dv_enable);
assign rplh_fmser_data_s      = rplh_flitseq_dv ? rplh_flitseq_data[DW-1:0] : rplh_flitseq_data_r[DW-1:0];
assign rplh_fmser_data_prot_s = rplh_flitseq_dv ? rplh_flitseq_data_prot[DW_PROT_WD-1:0] : rplh_flitseq_data_prot_r[DW_PROT_WD-1:0];
assign rplh_fmser_stream_s    = rplh_flitseq_dv ? rplh_flitseq_stream    : rplh_flitseq_stream_r;
assign rplh_fmser_nullified_s = rplh_flitseq_dv ? rplh_flitseq_nullified : rplh_flitseq_nullified_r;
assign rplh_fmser_poisoned_s  = rplh_flitseq_dv ? rplh_flitseq_poisoned  : rplh_flitseq_poisoned_r;

delay_n
 #(
    .N     (REGOUT_EN), 
    .WD    (3 + DW + DW_PROT_WD + $bits(spif_pkg::stream_id_e))
) u_delay_output_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({rplh_fmser_nullified_s, rplh_fmser_poisoned_s, rplh_fmser_dv_s, rplh_fmser_data_s , rplh_fmser_data_prot_s 
 , rplh_fmser_stream_s}),
    .dout  ({rplh_fmser_nullified , rplh_fmser_poisoned, rplh_fmser_dv, rplh_fmser_data , rplh_fmser_data_prot 
 , rplh_fmser_stream})
);
// -------------------------------------------------------------------------------------


assign rplh_link_dv_enable = 1'b1;


always_comb begin
    if (rplh_flitseq_dv) begin
        rplh_flitseq_dv_nxt        = {DW_RATIO{1'b1}};
        rplh_flitseq_data_nxt      = rplh_flitseq_data[DW+:(DW_RATIO*DW)];
        rplh_flitseq_data_prot_nxt = rplh_flitseq_data_prot[DW_PROT_WD+:(DW_RATIO*DW_PROT_WD)];
        rplh_flitseq_stream_nxt    = rplh_flitseq_stream;
        rplh_flitseq_nullified_nxt = rplh_flitseq_nullified;
        rplh_flitseq_poisoned_nxt  = rplh_flitseq_poisoned;
    end
    else if ((|rplh_flitseq_dv_r) && rplh_link_dv_enable) begin
        rplh_flitseq_dv_nxt        = rplh_flitseq_dv_r        >> 1;
        rplh_flitseq_data_nxt      = rplh_flitseq_data_r      >> DW;
        rplh_flitseq_data_prot_nxt = rplh_flitseq_data_prot_r >> DW_PROT_WD;
        rplh_flitseq_stream_nxt    = rplh_flitseq_stream_r;
        rplh_flitseq_nullified_nxt = rplh_flitseq_nullified_r;
        rplh_flitseq_poisoned_nxt  = rplh_flitseq_poisoned_r;
    end
    else begin
        rplh_flitseq_dv_nxt        = rplh_flitseq_dv_r;
        rplh_flitseq_data_nxt      = rplh_flitseq_data_r;
        rplh_flitseq_data_prot_nxt = rplh_flitseq_data_prot_r;
        rplh_flitseq_stream_nxt    = rplh_flitseq_stream_r;
        rplh_flitseq_nullified_nxt = rplh_flitseq_nullified_r;
        rplh_flitseq_poisoned_nxt  = rplh_flitseq_poisoned_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        rplh_flitseq_dv_r        <= # TP '0;
        rplh_flitseq_data_r      <= # TP '0;
        rplh_flitseq_data_prot_r <= # TP '0;
        rplh_flitseq_stream_r    <= # TP spif_pkg::SID_RSVD;
        rplh_flitseq_nullified_r <= # TP '0;
        rplh_flitseq_poisoned_r  <= # TP '0;
    end
    else begin
        rplh_flitseq_dv_r        <= # TP rplh_flitseq_dv_nxt;
        rplh_flitseq_data_r      <= # TP rplh_flitseq_data_nxt;
        rplh_flitseq_data_prot_r <= # TP rplh_flitseq_data_prot_nxt;
        rplh_flitseq_stream_r    <= # TP rplh_flitseq_stream_nxt;
        rplh_flitseq_nullified_r <= # TP rplh_flitseq_nullified_nxt;
        rplh_flitseq_poisoned_r  <= # TP rplh_flitseq_poisoned_nxt;
    end
end


endmodule // rplh_flit_serializer

