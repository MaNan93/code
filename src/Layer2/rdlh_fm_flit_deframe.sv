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
// ---  $DateTime: 2024/01/12 13:55:57 $
// ---  $Revision: #6 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_fm_flit_deframe.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Data Link Layer Flit Deframing module
//
// This module implements:
//   1) CXL 68B Flit Deframing (TokenFinder 4)
//   2) PCIe/CXL 256B Flit Deframing (FM Packet Finder)
//   3) Multiplexes between RPLH and SPIF interface on RDLH inputs (To be removed)
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module rdlh_fm_flit_deframe 
  import spif_pkg::SPIF_PL_NVLD;
  import spif_pkg::SPIF_NBYTES;
  import spif_pkg::SPIF_NWORDS;
  import spif_pkg::SPIF_NDLLP;
  import spif_pkg::SPIF_NDPBITS;
  import spif_pkg::SID_CXL_IO;
  import spif_pkg::SID_RSVD;
  import spif_pkg::stream_id_e;
  import spif_pkg::protocol_cfg_t;
#(
  parameter  TP            = `TP
) (
// Interfaces --------------------------------------------------------------------------
    spif_if.rplh_slave_mp                     b_rdlh_spif,            // RDLH SPIF interface
// Inputs ------------------------------------------------------------------------------
    input                                     core_clk,                    // Core clock
    input                                     core_rst_n,                  // Core reset
    input        protocol_cfg_t               rdlh_protocol_cfg,           // Protocol Configuration for DLH Layer
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_nak,               // RPLH-2-RDLH IF: NAK indication
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_dllp_start,        // RPLH-2-RDLH IF: Start of Data Link Layer Packet in the word
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_tlp_start,         // RPLH-2-RDLH IF: Start of Transaction Layer Packet in the word
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_pkt_end,           // RPLH-2-RDLH IF: End of Packet in the word
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_pkt_edb,           // RPLH-2-RDLH IF: End of Nullified TLP (EDB) in the word
    input        [SPIF_NBYTES*8-1:0]          rplh_rdlh_pkt_data,          // RPLH-2-RDLH IF: Packet Layer data
    input        [SPIF_NDPBITS-1:0]           rplh_rdlh_pkt_data_chk,      // SPIF-2-RDLH IF: Packet Layer data protection code
    input        [SPIF_PL_NVLD-1:0]           rplh_rdlh_pkt_dv,            // RPLH-2-RDLH IF: Packet Layer indicates data valid on the corresponding pl_data bytes
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_pkt_err,           // RPLH-2-RDLH IF: Packer Error in the word
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_tlp_idl,           // RPLH-2-RDLH IF: Idle
    input        [SPIF_NWORDS-1:0]            rplh_rdlh_tlp_pfx,           // RPLH-2-RDLH IF: Prefix
    input                                     rplh_rdlh_fm_nullified,      // RPLH-2-RDLH IF: Nullified
    input                                     rplh_rdlh_fm_poisoned,       // RPLH-2-RDLH IF: Poisoned
    input                                     rplh_rdlh_fm_dllp_valid,     // RPLH-2-RDLH IF: DLLP Valid
    input                                     rplh_rdlh_fm_dllp_opt_fc_up, // RPLH-2-RDLH IF: DLLP Optimized_Update_FC
    input        [SPIF_NDLLP*8-1:0]           rplh_rdlh_fm_dllp_data,      // RPLH-2-RDLH IF: DLLP Payload
// Outputs -----------------------------------------------------------------------------
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_rx_nak,            // SPIF-2-RDLH IF: NAK indication
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_dlp_start,         // SPIF-2-RDLH IF: Start of Data Link Layer Packet in the word
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_tlp_start,         // SPIF-2-RDLH IF: Start of Transaction Layer Packet in the word
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_pkt_end,           // SPIF-2-RDLH IF: End of Packet in the word
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_pkt_edb,           // SPIF-2-RDLH IF: End of Nullified TLP (EDB) in the word
    output logic [SPIF_NBYTES*8-1:0]          spif_rdlh_pkt_data,          // SPIF-2-RDLH IF: Packet Layer data
    output logic [SPIF_NDPBITS-1:0]           spif_rdlh_pkt_data_chk,      // SPIF-2-RDLH IF: Packet Layer data protection code
    output logic [SPIF_PL_NVLD-1:0]           spif_rdlh_pkt_dv,            // SPIF-2-RDLH IF: Packet Layer indicates data valid on the corresponding pl_data bytes
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_pkt_err            // SPIF-2-RDLH IF: Packer Error in the word
    ,
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_tlp_idl,           // SPIF-2-RDLH IF: Idle
    output logic [SPIF_NWORDS-1:0]            spif_rdlh_tlp_pfx,           // SPIF-2-RDLH IF: Prefix
    output logic                              spif_rdlh_tlp_nul,           // SPIF-2-RDLH IF: Nullified
    output logic                              spif_rdlh_tlp_psn,           // SPIF-2-RDLH IF: Poisoned
    output logic                              spif_rdlh_fm_dllp_valid,     // SPIF-2-RDLH IF: DLLP Valid
    output logic                              spif_rdlh_fm_dllp_ofc,       // SPIF-2-RDLH IF: DLLP Optimized_Update_FC
    output logic [SPIF_NDLLP*8-1:0]           spif_rdlh_fm_dllp_data       // SPIF-2-RDLH IF: DLLP Payload
);

// PCIe Flit Mode Packet Finder Interface
logic [SPIF_PL_NVLD-1:0]   rplh_fmpkt_data_valid;
logic [SPIF_NBYTES*8-1:0]  rplh_fmpkt_data;
logic [SPIF_NDPBITS-1:0]   rplh_fmpkt_data_chk;
logic [SPIF_NWORDS-1:0]    rplh_fmpkt_tlp_soh;
logic [SPIF_NWORDS-1:0]    rplh_fmpkt_tlp_end;
logic [SPIF_NWORDS-1:0]    rplh_fmpkt_tlp_pfx;
logic                      rplh_fmpkt_tlp_nul;
logic                      rplh_fmpkt_tlp_psn;
logic [SPIF_NWORDS-1:0]    rplh_fmpkt_tlp_idl;
logic [SPIF_NWORDS-1:0]    rplh_fmpkt_pkt_err;
// CXL 68B Flit Mode Token Finder Interface
logic [SPIF_PL_NVLD-1:0]   rplh_fmtkn_data_valid;
logic [SPIF_NBYTES*8-1:0]  rplh_fmtkn_data;
logic [SPIF_NWORDS-1:0]    rplh_fmtkn_tlp_start;
logic [SPIF_NWORDS-1:0]    rplh_fmtkn_tlp_end;
logic [SPIF_NWORDS-1:0]    rplh_fmtkn_tlp_edb;
logic [SPIF_NWORDS-1:0]    rplh_fmtkn_dlp_start;
logic [SPIF_NWORDS-1:0]    rplh_fmtkn_pkt_err;
// Packet Finder and Token Finder Mux Interface
logic [SPIF_NWORDS-1:0]    rplh_fmmux_rx_nak;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_dlp_start;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_tlp_start;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_pkt_end;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_pkt_edb;
logic [SPIF_NBYTES*8-1:0]  rplh_fmmux_pkt_data;
logic [SPIF_NDPBITS-1:0]   rplh_fmmux_pkt_data_chk;
logic [SPIF_PL_NVLD-1:0]   rplh_fmmux_pkt_dv;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_pkt_err;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_tlp_idl;
logic [SPIF_NWORDS-1:0]    rplh_fmmux_tlp_pfx;
logic                      rplh_fmmux_tlp_nul;
logic                      rplh_fmmux_tlp_psn;

// -------------------------------------------------------------------------------------
// SPIF and RPLH-2-RDLH Interface Mux
// -------------------------------------------------------------------------------------
always_comb begin
    spif_rdlh_rx_nak        = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_rx_nak           : rplh_rdlh_nak               ;
    spif_rdlh_dlp_start     = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_dlp_start        : rplh_rdlh_dllp_start        ;
    spif_rdlh_tlp_start     = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_tlp_start        : rplh_rdlh_tlp_start         ;
    spif_rdlh_pkt_end       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_pkt_end          : rplh_rdlh_pkt_end           ;
    spif_rdlh_pkt_edb       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_pkt_edb          : rplh_rdlh_pkt_edb           ;
    spif_rdlh_pkt_data      = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_pkt_data         : rplh_rdlh_pkt_data          ;
    spif_rdlh_pkt_data_chk  = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_pkt_data_chk     : rplh_rdlh_pkt_data_chk      ;
    spif_rdlh_pkt_dv        = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_pkt_dv           : rplh_rdlh_pkt_dv            ;
    spif_rdlh_pkt_err       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_pkt_err          : rplh_rdlh_pkt_err           ;
    spif_rdlh_tlp_idl       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_tlp_idl          : rplh_rdlh_tlp_idl           ;
    spif_rdlh_tlp_pfx       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_tlp_pfx          : rplh_rdlh_tlp_pfx           ;
    spif_rdlh_tlp_nul       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_tlp_nul          : rplh_rdlh_fm_nullified      ;
    spif_rdlh_tlp_psn       = rdlh_protocol_cfg.spif_enable ? rplh_fmmux_tlp_psn          : rplh_rdlh_fm_poisoned       ;
    // Flit Mode DLLP Interface
    spif_rdlh_fm_dllp_valid = rdlh_protocol_cfg.spif_enable ? b_rdlh_spif.s_pl_dllp_valid : rplh_rdlh_fm_dllp_valid     ;
    spif_rdlh_fm_dllp_ofc   = rdlh_protocol_cfg.spif_enable ? b_rdlh_spif.s_pl_dllp_ofc   : rplh_rdlh_fm_dllp_opt_fc_up ;
    spif_rdlh_fm_dllp_data  = rdlh_protocol_cfg.spif_enable ? b_rdlh_spif.s_pl_dllp_data  : rplh_rdlh_fm_dllp_data      ;
end

// -------------------------------------------------------------------------------------
// Packet Finder and Token Finder Mux Interface
// -------------------------------------------------------------------------------------
always_comb begin
    // CXL Mode
    rplh_fmmux_rx_nak       = rdlh_protocol_cfg.pcie_flit_mode ? {SPIF_NWORDS{1'b0}}   : (rdlh_protocol_cfg.cxl_mode_enable ? {SPIF_NBYTES{1'b0}}   : b_rdlh_spif.s_pl_rx_nak   );
    rplh_fmmux_dlp_start    = rdlh_protocol_cfg.pcie_flit_mode ? {SPIF_NWORDS{1'b0}}   : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_dlp_start  : b_rdlh_spif.s_pl_dlp_start);
    rplh_fmmux_tlp_start    = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_tlp_soh    : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_tlp_start  : b_rdlh_spif.s_pl_tlp_start);
    rplh_fmmux_pkt_end      = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_tlp_end    : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_tlp_end    : b_rdlh_spif.s_pl_tlp_end  );
    rplh_fmmux_pkt_edb      = rdlh_protocol_cfg.pcie_flit_mode ? {SPIF_NWORDS{1'b0}}   : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_tlp_edb    : b_rdlh_spif.s_pl_tlp_edb  );
    rplh_fmmux_pkt_data     = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_data       : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_data       : b_rdlh_spif.s_pl_data     );
    rplh_fmmux_pkt_data_chk = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_data_chk   : (rdlh_protocol_cfg.cxl_mode_enable ? {SPIF_NDPBITS{1'b0}}  : b_rdlh_spif.s_pl_data_chk );
    rplh_fmmux_pkt_dv       = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_data_valid : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_data_valid : b_rdlh_spif.s_pl_valid    );
    rplh_fmmux_pkt_err      = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_pkt_err    : (rdlh_protocol_cfg.cxl_mode_enable ? rplh_fmtkn_pkt_err    : {SPIF_NWORDS{b_rdlh_spif.s_pl_error}});
    rplh_fmmux_tlp_idl      = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_tlp_idl    : {SPIF_NWORDS{1'b0}};
    rplh_fmmux_tlp_pfx      = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_tlp_pfx    : {SPIF_NWORDS{1'b0}};
    rplh_fmmux_tlp_nul      = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_tlp_nul    : 1'b0;
    rplh_fmmux_tlp_psn      = rdlh_protocol_cfg.pcie_flit_mode ? rplh_fmpkt_tlp_psn    : 1'b0;
end

// -------------------------------------------------------------------------------------
// Packet Finder for PCIe Flit Mode
// -------------------------------------------------------------------------------------
logic                      rplh_fmpkt_rxdata_dv;
logic [SPIF_NBYTES*8-1:0]  rplh_fmpkt_rxdata;
logic [SPIF_NDPBITS-1:0]   rplh_fmpkt_rxdata_chk;
logic                      rplh_fmpkt_nullified;
logic                      rplh_fmpkt_poisoned;

// RDLH Flit Buffer Intantiation
rdlh_fm_flit_buff
 u_rdlh_fm_flit_buff (
    .b_rdlh_spif                ( b_rdlh_spif                       ),
    .core_clk                   ( core_clk                          ),
    .core_rst_n                 ( core_rst_n                        ),
    .rdlh_protocol_cfg          ( rdlh_protocol_cfg                 ),
    .rdlh_fmpkt_valid           ( rplh_fmpkt_rxdata_dv              ),
    .rdlh_fmpkt_data            ( rplh_fmpkt_rxdata                 ),
    .rdlh_fmpkt_data_chk        ( rplh_fmpkt_rxdata_chk             ),
    .rdlh_fmpkt_nullified       ( rplh_fmpkt_nullified              ),
    .rdlh_fmpkt_poisoned        ( rplh_fmpkt_poisoned               ),
    .rdlh_fmpkt_error           ( rplh_fmpkt_pkt_err                )
);

// RPLH Flit Mode Packet Finder Intantiation
rplh_fm_pkt_finder
 #(
     // Configure Packer Finder to SPIF Data Width
    .NW                         ( SPIF_NWORDS                       ),
    .DW                         ( SPIF_NBYTES*8                     ),
    .DW_PROT_WD                 ( SPIF_NDPBITS                      )
) u_rdlh_fm_pkt_finder (
// ---- inputs ---------------
    .core_clk                   ( core_clk                          ),
    .core_rst_n                 ( core_rst_n                        ),
    .rplh_flit_dv               ( rplh_fmpkt_rxdata_dv              ),
    .rplh_flit_data             ( rplh_fmpkt_rxdata                 ),
    .rplh_flit_data_prot        ( rplh_fmpkt_rxdata_chk             ),
    .rplh_flit_nullified        ( rplh_fmpkt_nullified              ),
    .rplh_flit_poisoned         ( rplh_fmpkt_poisoned               ),
// ---- outputs ---------------
    .rplh_fmpkt_data            ( rplh_fmpkt_data                   ),
    .rplh_fmpkt_data_prot       ( rplh_fmpkt_data_chk               ),
    .rplh_fmpkt_data_dv         ( rplh_fmpkt_data_valid             ),
    .rplh_fmpkt_tlp_pfx         ( rplh_fmpkt_tlp_pfx                ),
    .rplh_fmpkt_tlp_soh         ( rplh_fmpkt_tlp_soh                ),
    .rplh_fmpkt_tlp_end         ( rplh_fmpkt_tlp_end                ),
    .rplh_fmpkt_tlp_nul         ( rplh_fmpkt_tlp_nul                ),
    .rplh_fmpkt_tlp_psn         ( rplh_fmpkt_tlp_psn                ),
    .rplh_fmpkt_tlp_idl         ( rplh_fmpkt_tlp_idl                )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// General token finder4 for CXL 68B Flit Mode
// -------------------------------------------------------------------------------------
logic [5:0]                rplh_fmtkn_link_mode;  // Current Link Mode
logic [SPIF_NBYTES*8-1:0]  rplh_fmtkn_rxdata;     // Token Finder Data 
logic                      rplh_fmtkn_rxdata_dv;  // Token Finder Data Valid
logic                      rplh_fmprd_rxdata_dv;  // Pipeline Predictor Data Valid
logic                      rplh_fmtkn_pkt_flush;  // Flush RPLH Token Finder pipeline when no packets in progress

assign rplh_fmtkn_link_mode = `CX_NL;

// Flush Token Finder pipeline and forward the content to RDLH when TLP ends in the flit and it does not start a new one.
assign rplh_fmtkn_rxdata_dv = ((b_rdlh_spif.s_pl_rx_flush || rplh_fmtkn_pkt_flush) ? 1'b1 : b_rdlh_spif.s_pl_valid) && !rdlh_protocol_cfg.cxl_pcie_flit_mode;
assign rplh_fmtkn_rxdata    = ((b_rdlh_spif.s_pl_rx_flush || rplh_fmtkn_pkt_flush) ?   '0 : b_rdlh_spif.s_pl_data );

// rplh_fmprd_rxdata_dv is similar to rplh_fmtkn_rxdata_dv but it does not drop when rplh_fmtkn_pkt_flush is enabled
assign rplh_fmprd_rxdata_dv = (b_rdlh_spif.s_pl_rx_flush ? 1'b1 : b_rdlh_spif.s_pl_valid) && !rdlh_protocol_cfg.cxl_pcie_flit_mode;

rplh_token_finder4
 u_rplh_token_finder4 (
// ---- inputs ---------------
    .core_clk                   ( core_clk                          ),
    .core_rst_n                 ( core_rst_n                        ),
    .cxl_mode_enable            ( rdlh_protocol_cfg.cxl_mode_enable ),
    .smlh_link_mode             ( rplh_fmtkn_link_mode              ),
    .search_for_tokens          ( !b_rdlh_spif.s_pl_rx_flush        ),
    .accept_eds_cycle           ( 1'b0                              ),
    .expect_eds                 ( 1'b0                              ),
    .rxdata3_dv                 ( rplh_fmtkn_rxdata_dv              ),
    .rxdata3                    ( rplh_fmtkn_rxdata                 ),
// ---- outputs ---------------
    .rplh_rdlh_dllp_start       ( rplh_fmtkn_dlp_start              ),
    .rplh_rdlh_tlp_start        ( rplh_fmtkn_tlp_start              ),
    .rplh_rdlh_pkt_end          ( rplh_fmtkn_tlp_end                ),
    .rplh_rdlh_pkt_edb          ( rplh_fmtkn_tlp_edb                ),
    .rplh_rdlh_pkt_data         ( rplh_fmtkn_data                   ),
    .rplh_rdlh_pkt_dv           ( rplh_fmtkn_data_valid             ),
    .rplh_rdlh_pkt_err          ( rplh_fmtkn_pkt_err                ),
    .rplh_rdlh_pkt_err_ptr      ( /* Unconnected                 */ ),
    .no_pkt_in_progress         ( /* Unconnected                 */ ),
    .rplh_rcvd_idle             ( /* Unconnected                 */ )
);

rplh_token_finder4
 #(
    .PREDICTOR(1)
) u_rplh_token_finder4_predictor (
// ---- inputs ---------------
    .core_clk                   ( core_clk                          ),
    .core_rst_n                 ( core_rst_n                        ),
    .cxl_mode_enable            ( rdlh_protocol_cfg.cxl_mode_enable ),
    .smlh_link_mode             ( rplh_fmtkn_link_mode              ),
    .search_for_tokens          ( !b_rdlh_spif.s_pl_rx_flush        ),
    .accept_eds_cycle           ( 1'b0                              ),
    .expect_eds                 ( 1'b0                              ),
    .rxdata3_dv                 ( rplh_fmprd_rxdata_dv              ),
    .rxdata3                    ( rplh_fmtkn_rxdata                 ),
// ---- outputs ---------------
    .rplh_rdlh_dllp_start       ( /* Unconnected                 */ ),
    .rplh_rdlh_tlp_start        ( /* Unconnected                 */ ),
    .rplh_rdlh_pkt_end          ( /* Unconnected                 */ ),
    .rplh_rdlh_pkt_edb          ( /* Unconnected                 */ ),
    .rplh_rdlh_pkt_data         ( /* Unconnected                 */ ),
    .rplh_rdlh_pkt_dv           ( /* Unconnected                 */ ),
    .rplh_rdlh_pkt_err          ( /* Unconnected                 */ ),
    .rplh_rdlh_pkt_err_ptr      ( /* Unconnected                 */ ),
    .no_pkt_in_progress         ( rplh_fmtkn_pkt_flush              ),
    .rplh_rcvd_idle             ( /* Unconnected                 */ )
);
// -------------------------------------------------------------------------------------

endmodule
