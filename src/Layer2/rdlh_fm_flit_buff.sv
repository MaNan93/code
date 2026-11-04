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
// ---  $DateTime: 2024/01/19 09:25:58 $
// ---  $Revision: #2 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_fm_flit_buff.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Data Link Layer Flit Buffer module
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module rdlh_fm_flit_buff
    import spif_pkg::SPIF_PL_NVLD;
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::SPIF_NWORDS;
    import spif_pkg::SID_PCIE;
    import spif_pkg::protocol_cfg_t;
#(
    parameter  TP            = `TP
) (
// Interfaces --------------------------------------------------------------------------
    spif_if.rplh_slave_mp                     b_rdlh_spif,                 // RPLH SPIF interface
// Inputs ------------------------------------------------------------------------------
    input                                     core_clk,                    // Core clock
    input                                     core_rst_n,                  // Core reset
    input        protocol_cfg_t               rdlh_protocol_cfg,           // Protocol Configuration for DLH Layer
// Outputs -----------------------------------------------------------------------------
    output logic                              rdlh_fmpkt_valid,            // SPIF-2-RDLH IF: Packet Layer indicates data valid on the corresponding pl_data bytes
    output logic   [SPIF_NBYTES*8-1:0]        rdlh_fmpkt_data,             // SPIF-2-RDLH IF: Packet Layer data
    output logic   [SPIF_NBYTES-1:0]          rdlh_fmpkt_data_chk,         // SPIF-2-RDLH IF: Packet Layer data protection code
    output logic                              rdlh_fmpkt_nullified,        // SPIF-2-RDLH IF: Last Nullified TLP flit marker
    output logic                              rdlh_fmpkt_poisoned,         // SPIF-2-RDLH IF: Last Posioned TLP flit marker
    output logic   [SPIF_NWORDS-1:0]          rdlh_fmpkt_error             // SPIF-2-RDLH IF: Packer Error in the word
);



// -------------------------------------------------------------------------------------
// Flit Stream Datapath (post-FEC)
// -------------------------------------------------------------------------------------
localparam REGIN_EN = 0 + 1;

// Input pipeline register signals (PCIe flit mode)
logic                        rplh_pipe_nullified;
logic                        rplh_pipe_poisoned;
logic                        rplh_pipe_error;
logic                        rplh_pipe_valid;
logic [SPIF_NBYTES*8-1:0]    rplh_pipe_data;
logic [SPIF_NBYTES-1:0]      rplh_pipe_data_chk;
logic                        rdlh_pl_valid_gated_s;

assign rdlh_pl_valid_gated_s = rdlh_protocol_cfg.pcie_flit_mode  ? (b_rdlh_spif.s_pl_valid) : 1'b0;

// Input pipeline register on SPIF interface (PCIe flit mode signals only)
// Implemented to strip off 2-byte Flit Header from a data stream before the packet finder when CXL is enabled
delay_n
 #(
    .N     (REGIN_EN), 
    .WD    (4 + SPIF_NBYTES*8 + SPIF_NBYTES)
) u_delay_input_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({b_rdlh_spif.s_pl_nullified, b_rdlh_spif.s_pl_poisoned, b_rdlh_spif.s_pl_error,
             rdlh_pl_valid_gated_s, b_rdlh_spif.s_pl_data , b_rdlh_spif.s_pl_data_chk}),
    .dout  ({rplh_pipe_nullified, rplh_pipe_poisoned, rplh_pipe_error,
             rplh_pipe_valid, rplh_pipe_data , rplh_pipe_data_chk})
);

// Post-FEC datapath signals
logic                        rdlh_post_fec_valid;
logic [SPIF_NBYTES*8-1:0]    rdlh_post_fec_data;
logic [SPIF_NBYTES-1:0]      rdlh_post_fec_data_chk;
logic                        rdlh_post_fec_nullified;
logic                        rdlh_post_fec_poisoned;
logic                        rdlh_post_fec_error;


always_comb begin
    rdlh_post_fec_valid      = rplh_pipe_valid;
    rdlh_post_fec_data       = rplh_pipe_data;
    rdlh_post_fec_data_chk   = rplh_pipe_data_chk;
    rdlh_post_fec_nullified  = rplh_pipe_nullified;
    rdlh_post_fec_poisoned   = rplh_pipe_poisoned;
    rdlh_post_fec_error      = rplh_pipe_error;
    if (rdlh_protocol_cfg.cxl_mode_enable) begin
        // Remove 2B Flit Header from the flit stream
        rdlh_post_fec_data       = {b_rdlh_spif.s_pl_data[15:0], rplh_pipe_data[SPIF_NBYTES*8-1:16]};
        rdlh_post_fec_data_chk   = {b_rdlh_spif.s_pl_data_chk[1:0], rplh_pipe_data_chk[SPIF_NBYTES-1:2]};

    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Mux between Post-FEC and Pre-FEC datapath
// -------------------------------------------------------------------------------------
always_comb begin
     begin
        rdlh_fmpkt_nullified = rdlh_post_fec_nullified;
        rdlh_fmpkt_poisoned  = rdlh_post_fec_poisoned;
        rdlh_fmpkt_error     = {SPIF_NWORDS{rdlh_post_fec_error}};
        rdlh_fmpkt_valid     = rdlh_post_fec_valid;
        rdlh_fmpkt_data      = rdlh_post_fec_data;
        rdlh_fmpkt_data_chk  = rdlh_post_fec_data_chk;
     end
end
// -------------------------------------------------------------------------------------

endmodule
