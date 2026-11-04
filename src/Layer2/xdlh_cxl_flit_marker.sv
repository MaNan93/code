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
// ---    $DateTime: 2024/02/09 08:06:12 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_cxl_flit_marker.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: XDLH Flit Marker detection for CXL
// --- 1) Offloads the entire flit from XTLH to identify Flit Marker before
// ---    forwarding it to XPLH. Required for CXL as DLP0 byte is moved from EOF
// ---    to SOF position in CXL 256B flit format.
// --- 2) Re-arranges flit to align to CXL256B Flit format
// --- 3) Inserts FlitType in the Flit Header
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module xdlh_cxl_flit_marker
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::SPIF_NDLLP;
#(
    parameter   TP        = `TP,            // Clock to Q delay (simulator insurance)
    parameter   DW        = SPIF_NBYTES*8,  // Width of datapath in bits.
    parameter   DW_PROT   = 0 + SPIF_NBYTES ,
    parameter   DW_W_PROT = DW + DW_PROT    // Width of datapath with protection code in bits.
) 
                               (
// Inputs ------------------------------------------------------------------------------
    input                             core_clk,                   // Core Clock
    input                             core_rst_n,                 // Core Reset
    input                             cxl_mode_enable,            // CXL Mode Enable
    input                             xtlh_xdlh_dv,               // XTLH to XDLH Interface - Data Valid
    input                             xtlh_xdlh_sof,              // XTLH to XDLH Interface - Start of Flit marker
    input          [1:0]              xtlh_xdlh_eof,              // XTLH to XDLH Interface - End of Flit marker
    input          [DW_W_PROT-1:0]    xtlh_xdlh_data,             // XTLH to XDLH Interface - CXL.io flit for transmission.
    input                             xplh_xdlh_halt,             // XPLH to XDLH Interface - Halt
// Outputs -----------------------------------------------------------------------------
    output  logic                     xdlh_flit_in_progress,      // XTLH to XDLH Interface - Flit in progress
    output  logic                     xdlh_xtlh_halt,             // XDLH to XTLH Interface - Halt
    output  logic                     xdlh_xplh_dv_out,           // XDLH to XPLH Interface - Data Valid
    output  logic                     xdlh_xplh_sof_out,          // XDLH to XPLH Interface - Start of Flit marker
    output  logic  [1:0]              xdlh_xplh_eof_out,          // XDLH to XPLH Interface - End of Flit marker
    output  logic  [DW_W_PROT-1:0]    xdlh_xplh_data_out          // XDLH to XPLH Interface - CXL.io flit for transmission after Flit Header insertion
);

// Local parameters
localparam FLIT_DW          = 2048;                                // Flit width in bits
localparam FLIT_DW_PROT     = 2048 / 8;                            // Flit data protection bits
localparam FLIT_DW_RATIO    = FLIT_DW / DW;                        // Number of cycles required to complete 256B flit on the interface to ARB/MUX
localparam FLIT_DLP0_POS    = FLIT_DW - 20*8;                      // DLP0 byte position in the flit buffer. DLP0 byte starts counting 20 bytes from EOF.
localparam FLIT_DLP2_POS    = FLIT_DW - 18*8;                      // DLP2 byte position in the flit buffer. DLP2 byte starts counting 18 bytes from EOF.

// Internal declarations
logic [FLIT_DW_RATIO  -1:0]  xdlh_flit_dv_r;
logic [FLIT_DW_RATIO  -1:0]  xdlh_flit_dv_nxt;
logic [FLIT_DW_RATIO  -1:0]  xdlh_flit_sof_r;
logic [FLIT_DW_RATIO  -1:0]  xdlh_flit_sof_nxt;
logic [FLIT_DW_RATIO*2-1:0]  xdlh_flit_eof_r;
logic [FLIT_DW_RATIO*2-1:0]  xdlh_flit_eof_nxt;
logic [FLIT_DW        -1:0]  xdlh_flit_data_r;
logic [FLIT_DW        -1:0]  xdlh_flit_data_nxt;
logic [FLIT_DW_PROT   -1:0]  xdlh_flit_data_chk_r;
logic [FLIT_DW_PROT   -1:0]  xdlh_flit_data_chk_nxt;

// Output assignments
assign xdlh_flit_in_progress = xdlh_flit_dv_r[FLIT_DW_RATIO-1] || xtlh_xdlh_dv;

// -------------------------------------------------------------------------------------
// CXL/PCIe flit mode output mux
// -------------------------------------------------------------------------------------
always_comb begin
    if (cxl_mode_enable) begin
        xdlh_xplh_dv_out   = xdlh_flit_dv_r[0];
        xdlh_xplh_sof_out  = xdlh_flit_sof_r[0];
        xdlh_xplh_eof_out  = xdlh_flit_eof_r[1:0];
        xdlh_xplh_data_out = { xdlh_flit_data_chk_r[DW_PROT-1:0], xdlh_flit_data_r[DW-1:0]};
        xdlh_xtlh_halt     = (xdlh_xplh_dv_out  ? xplh_xdlh_halt : 1'b0);
    end else begin
        xdlh_xplh_dv_out   = xtlh_xdlh_dv;
        xdlh_xplh_sof_out  = xtlh_xdlh_sof;
        xdlh_xplh_eof_out  = xtlh_xdlh_eof;
        xdlh_xplh_data_out = xtlh_xdlh_data;
        xdlh_xtlh_halt     = xplh_xdlh_halt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Flit Buffer
// -------------------------------------------------------------------------------------
always_comb begin
    // Capture the flit on XTLH interface into the buffer
    if (cxl_mode_enable && !xdlh_xtlh_halt) begin
        xdlh_flit_dv_nxt       = {xtlh_xdlh_dv                  , xdlh_flit_dv_r[FLIT_DW_RATIO-1:1]};
        xdlh_flit_sof_nxt      = {xtlh_xdlh_sof                 , xdlh_flit_sof_r[FLIT_DW_RATIO-1:1]};
        xdlh_flit_eof_nxt      = {xtlh_xdlh_eof                 , xdlh_flit_eof_r[FLIT_DW_RATIO*2-1:2]};
        xdlh_flit_data_nxt     = {xtlh_xdlh_data[DW-1:0]        , xdlh_flit_data_r[FLIT_DW-1:DW]};
        xdlh_flit_data_chk_nxt = {xtlh_xdlh_data[DW_W_PROT-1:DW], xdlh_flit_data_chk_r[FLIT_DW_PROT-1:DW_PROT]};
        if (xtlh_xdlh_eof[1]) begin
            // Align PCIe flit format on XTLH-2-XDLH interface to CXL256B Flit Format on XDLH-2XPLH interface
            // Shift DLP2-DLP5 bytes into DLP0-DLP3 position, move DLP0-1 bytes to the flit header
            // Insert CXL.io Flit Type in DLP0
            xdlh_flit_data_nxt[0+:(FLIT_DLP0_POS+6*8)]     = {xdlh_flit_data_nxt[FLIT_DLP2_POS+:4*8], xdlh_flit_data_nxt[0+:FLIT_DLP0_POS], xdlh_flit_data_nxt[FLIT_DLP0_POS+:2*8] | 16'h0040};
            xdlh_flit_data_chk_nxt[0+:(FLIT_DLP0_POS/8+6)] = {xdlh_flit_data_chk_nxt[(FLIT_DLP2_POS/8)+:4], xdlh_flit_data_chk_nxt[0+:(FLIT_DLP0_POS/8)], xdlh_flit_data_chk_nxt[(FLIT_DLP0_POS/8)+:2] ^ 2'b01};
        end
    end
    // Flush the flit from the buffer
    else if (xdlh_flit_dv_r[0] && !xplh_xdlh_halt) begin
        xdlh_flit_dv_nxt       = {1'b0           , xdlh_flit_dv_r[FLIT_DW_RATIO-1:1]};
        xdlh_flit_sof_nxt      = {1'b0           , xdlh_flit_sof_r[FLIT_DW_RATIO-1:1]};
        xdlh_flit_eof_nxt      = {2'd0           , xdlh_flit_eof_r[FLIT_DW_RATIO*2-1:2]};
        xdlh_flit_data_nxt     = {{DW{1'b0}}     , xdlh_flit_data_r[FLIT_DW-1:DW]};
        xdlh_flit_data_chk_nxt = {{DW_PROT{1'b0}}, xdlh_flit_data_chk_r[FLIT_DW_PROT-1:DW_PROT]};
    end
    else begin
        xdlh_flit_dv_nxt       = xdlh_flit_dv_r;
        xdlh_flit_sof_nxt      = xdlh_flit_sof_r;
        xdlh_flit_eof_nxt      = xdlh_flit_eof_r;
        xdlh_flit_data_nxt     = xdlh_flit_data_r;
        xdlh_flit_data_chk_nxt = xdlh_flit_data_chk_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        xdlh_flit_dv_r       <= # TP '0;
        xdlh_flit_sof_r      <= # TP '0;
        xdlh_flit_eof_r      <= # TP '0;
        xdlh_flit_data_r     <= # TP '0;
        xdlh_flit_data_chk_r <= # TP '0;
    end
    else begin
        xdlh_flit_dv_r       <= # TP xdlh_flit_dv_nxt;
        xdlh_flit_sof_r      <= # TP xdlh_flit_sof_nxt;
        xdlh_flit_eof_r      <= # TP xdlh_flit_eof_nxt;
        xdlh_flit_data_r     <= # TP xdlh_flit_data_nxt;
        xdlh_flit_data_chk_r <= # TP xdlh_flit_data_chk_nxt;
    end
end

endmodule // xdlh_cxl_flit_marker

