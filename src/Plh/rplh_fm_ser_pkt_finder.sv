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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fm_ser_pkt_finder.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Flit Serializer and Packet Finder in Flit Mode
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module rplh_fm_ser_pkt_finder
    import spif_pkg::stream_id_e;
    import spif_pkg::SID_PCIE;
    import spif_pkg::SPIF_NWORDS;
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::SPIF_NDPBITS;
#(
    parameter FLIT_WD         = 2048,                                     // Full Flit width in bits
    parameter FLIT_PROT_WD    = FLIT_WD/32*`CX_RAS_DWORD_PROT_WD,         // Full Flit Protection bits
    parameter NW              = `CX_PL_NW,                                // Number of 32-bit dwords handled by the datapath each clock.
    parameter DW              = 32*NW,                                    // Datapath Width in bits
    parameter DW_PROT_WD      = `CX_RAS_RPL_DATA_PROT_WD,                 // Datapath Protection bits
    parameter DW_W_PROT       = DW+DW_PROT_WD,                            // Width of datapath and protection bits
    parameter TP              = `TP                                       // Clock to Q delay (simulator insurance)
)
(
// ---- inputs ---------------
    input                       core_clk,
    input                       core_rst_n,
    input stream_id_e           rplh_flitseq_stream,     // Full received flit Stream ID
    input                       rplh_flitseq_dv,         // Valid TLP bytes in this cycle
    input [FLIT_WD-1:0]         rplh_flitseq_data,       // Full received flit
    input [FLIT_PROT_WD-1:0]    rplh_flitseq_data_prot,  // Full received flit Protection bits
    input                       rplh_flitseq_nullified,  // marks whether this flit contains a nullified TLP
    input                       rplh_flitseq_poisoned,   // marks whether this flit contains a poisoned TLP
    // ---- ser outputs -----------
    // ---- spif in/out -----------
    input                        rplh_spif_enable,       // SPIF Interface enable
    output stream_id_e           rplh_fmser_stream,      // Serialized Flit Stream ID
    output                       rplh_fmser_nullified,   // Serialized Flit Nullified TLP Marker
    output                       rplh_fmser_poisoned,    // Serialized Flit Poisoned TLP Marker
    output                       rplh_fmser_dv,          // Serialized Flit Data Valid
    output [SPIF_NBYTES*8-1:0]   rplh_fmser_data,        // Serialized Flit Data
    output [SPIF_NDPBITS-1:0]    rplh_fmser_data_prot,   // Serialized Flit Data Protection
    // ---- pkt outputs -----------
    output [DW_W_PROT-1:0]      rplh_fmpkt_data,         // Packet Data, note this signal only has parity bits if RASDP is enabled
    output                      rplh_fmpkt_data_dv,      // Packed Data Valid
    output [NW-1:0]             rplh_fmpkt_tlp_pfx,      // Indicates DWord location of prefix
    output [NW-1:0]             rplh_fmpkt_tlp_soh,      // Indicates DWord location of the 1st Base Header DW
    output [NW-1:0]             rplh_fmpkt_tlp_end,      // Indicates DWord location of a packet END
    output                      rplh_fmpkt_tlp_nul,      // The last TLP ending was Nullified by the Flit Marker
    output                      rplh_fmpkt_tlp_psn,      // The last TLP ending was Poisoned by the Flit Marker
    output [NW-1:0]             rplh_fmpkt_tlp_idl       // Indicates an empty DWord
);

stream_id_e                int_fmser_stream;      // Serialized Stream ID
wire                       int_fmser_dv;          // Serialized Flit Data Valid
wire [DW-1:0]              int_fmser_data;        // Serialized Flit Data
wire [DW_PROT_WD-1:0]      int_fmser_data_prot;   // Serialized Flit Data Protection
wire                       int_fmser_nullified;   // Serialized Flit Nullified TLP Marker
wire                       int_fmser_poisoned;    // Serialized Flit Poisoned TLP Marker

assign rplh_fmser_stream    = int_fmser_stream;
assign rplh_fmser_dv        = int_fmser_dv;
assign rplh_fmser_data      = int_fmser_data;
assign rplh_fmser_data_prot = int_fmser_data_prot;
assign rplh_fmser_nullified = int_fmser_nullified;
assign rplh_fmser_poisoned  = int_fmser_poisoned;

// Serialize flit on LogPHY Data Width granularity
rplh_flit_serializer
 u_rplh_flit_serializer (
// ---- inputs ---------------
    .core_clk                      (core_clk),
    .core_rst_n                    (core_rst_n),
    .rplh_flitseq_stream           (rplh_flitseq_stream),
    .rplh_flitseq_nullified        (rplh_flitseq_nullified),
    .rplh_flitseq_poisoned         (rplh_flitseq_poisoned),
    .rplh_flitseq_dv               (rplh_flitseq_dv),
    .rplh_flitseq_data             (rplh_flitseq_data),
    .rplh_flitseq_data_prot        (rplh_flitseq_data_prot),
// ---- outputs ---------------
    .rplh_fmser_stream             (int_fmser_stream),
    .rplh_fmser_nullified          (int_fmser_nullified),
    .rplh_fmser_poisoned           (int_fmser_poisoned),
    .rplh_fmser_dv                 (int_fmser_dv),
    .rplh_fmser_data               (int_fmser_data)
    ,.rplh_fmser_data_prot         (int_fmser_data_prot)
);

wire int_fmser_dv_non_spif;
assign int_fmser_dv_non_spif = rplh_fmser_dv && (int_fmser_stream inside {SID_PCIE} && !rplh_spif_enable);

rplh_fm_pkt_finder
 u_rplh_fm_pkt_finder
(
// ---- inputs ---------------
    .core_clk                      (core_clk),
    .core_rst_n                    (core_rst_n),
    .rplh_flit_dv                  (int_fmser_dv_non_spif),
    .rplh_flit_data                (int_fmser_data),
    .rplh_flit_data_prot           (int_fmser_data_prot),
    .rplh_flit_nullified           (int_fmser_nullified),
    .rplh_flit_poisoned            (int_fmser_poisoned),
// ---- outputs ---------------
    .rplh_fmpkt_data               (rplh_fmpkt_data[DW-1:0]),
    .rplh_fmpkt_data_prot          (rplh_fmpkt_data[DW_W_PROT-1:DW]),
    .rplh_fmpkt_data_dv            (rplh_fmpkt_data_dv),
    .rplh_fmpkt_tlp_pfx            (rplh_fmpkt_tlp_pfx),
    .rplh_fmpkt_tlp_soh            (rplh_fmpkt_tlp_soh),
    .rplh_fmpkt_tlp_end            (rplh_fmpkt_tlp_end),
    .rplh_fmpkt_tlp_nul            (rplh_fmpkt_tlp_nul),
    .rplh_fmpkt_tlp_psn            (rplh_fmpkt_tlp_psn),
    .rplh_fmpkt_tlp_idl            (rplh_fmpkt_tlp_idl)
);

endmodule

