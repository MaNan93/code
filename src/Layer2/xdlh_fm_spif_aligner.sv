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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_fm_spif_aligner.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description: XDLH to XPLH Interface Aligner
// --- Accounts for PID in 68B Flit Mode
// --- Inserts 2-byte Flit Header with Flit Usage = 2'b01 (CXL.io) in 256B Flit Mode
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module xdlh_fm_spif_aligner
    import spif_pkg::protocol_cfg_t;
    import spif_pkg::SID_PCIE;
    import spif_pkg::SID_CXL_IO;
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::SPIF_NWORDS;
    import spif_pkg::SPIF_NDLLP;
    import spif_pkg::SPIF_NDPBITS;
#(
    parameter   TP          = `TP       // Clock to Q delay (simulator insurance)
) (
// Interfaces --------------------------------------------------------------------------
    tx_lp_if.slave_mp                      b_xdlh_xplh,             // XDLH to XPLH Interface
    tx_lp_if.master_mp                     b_xdlh_xplh_arbmux,      // XDLH to XPLH ARB/MUX Interface
    spif_if.xplh_slave_mp                  b_xdlh_spif,             // XDLH to XPLH SPIF Interface
// Inputs ------------------------------------------------------------------------------
    input                                  core_clk,                // Core clock
    input                                  core_rst_n,              // Core reset
    input  protocol_cfg_t                  xdlh_protocol_cfg,       // Protocol Configuration for DLH Layer
    input  [SPIF_NWORDS-1:0]               xdlh_xplh_dllp_end,      // XDLH to XPLH IF - End of DLLP (is not part of tx_lp_if)
    input                                  xdlh_pm_state_req,       // Link Layer requests PM entry
    input                                  xdlh_xplh_dllp_pending,  // DLLP Pending
    input                                  xdlh_xplh_dllp_valid,    // DLLP Valid
    input                                  xdlh_xplh_dllp_ofc,      // DLLP Optimized_Update_FC
    input  [SPIF_NDLLP*8-1:0]              xdlh_xplh_dllp_data,     // DLLP Payload
    input                                  xplh_xdlh_dllp_halt,     // DLLP Halt on XDLH-XPLH Interface
    input                                  xtlh_xdlh_cmd_done,      // XTLH to XDLH cmd handshake done
    input                                  xdlh_pl_stall_req,       // Physical Layer Stall Request
// Outputs -----------------------------------------------------------------------------
    output  logic                          xplh_xdlh_dllp_halt_out, // DLLP Halt to XDLH
    output  logic                          xdlh_lp_stall_ack        // Link Layer Stall Acknowledge
);

localparam DW        = SPIF_NBYTES*8;
localparam DW_W_PROT = SPIF_NBYTES*8 + SPIF_NDPBITS;

logic                       xplh_xdlh_halt_s;           // XPLH to XDLH Halt
logic                       xplh_xdlh_skip_s;           // XPLH to XDLH Skip Pending
// 256B Flit Mode Input Interface (Flit Marker detection)
logic                       fm_xdlh_xplh_dv_s;          // Flit Marker Buffer - Data Valid
logic                       fm_xdlh_xplh_sof_s;         // Flit Marker Buffer - Start of Flit
logic [1:0]                 fm_xdlh_xplh_eof_s;         // Flit Marker Buffer - End of Flit
logic [DW_W_PROT-1:0]       fm_xdlh_xplh_data_s;        // Flit Marker Buffer - Data
logic                       fm_xdlh_xplh_halt_s;        // Flit Marker Buffer - Halt
logic                       fm_xdlh_flit_in_progress;   // Flit Marker Buffer - Flit in progress on XTLH-2-XDLH interface
// 256B Flit Mode Output Interface (SPIF Datapath)
logic                       xdlh_xplh_hdr_stall_ack_s;  // Stall Acknowledge on 256B Flit Mode interface
logic [DW_W_PROT-1:0]       xdlh_xplh_hdr_data_s;       // XDLH to XPLH Data with insert Flit Header
logic                       xdlh_xplh_hdr_dv_s;         // XDLH to XPLH Data valid for 256B Flit mode
logic                       xdlh_xplh_hdr_sof_s;        // Added to hookup to verification environment
logic [1:0]                 xdlh_xplh_hdr_eof_s;        // Added to hookup to verification environment
logic                       xdlh_xplh_hdr_nop_s;
logic                       xdlh_xplh_hdr_halt_s;       // XDLH to XPLH Halt for 256B Flit mode
logic [SPIF_NBYTES-1:0]     xdlh_xplh_hdr_prot_s;       // XDLH to XPLH Data Prot for 256B Flit mode
logic                       xdlh_xplh_hdr_dllp_valid_s; // XDLH to XPLH DLLP Valid
logic                       xdlh_xplh_hdr_dllp_ofc_s;   // XDLH to XPLH DLLP Optimized_Update_FC
logic [SPIF_NDLLP*8-1:0]    xdlh_xplh_hdr_dllp_data_s;  // XDLH to XPLH DLLP Payload
logic                       xplh_xdlh_hdr_dllp_halt_s;  // XPLH to XDLH DLLP Halts for 256B Flit mode
logic                       xdlh_xplh_pkt_pending_s;    // XDLH Packet Pending
// CXL 68B Flit Mode Interface
logic                       xdlh_xplh_pid_enable_s;     // Enable CXL in 68B Flit Mode
logic                       xdlh_xplh_pid_stall_ack_s;  // Stall Acknowledge on 68B Flit Mode interface
logic [SPIF_NBYTES*8-1:0]   xdlh_xplh_pid_data_s;       // XDLH to XPLH Data with inserted PID
logic                       xdlh_xplh_pid_dv_s;         // XDLH to XPLH Data valid for 68B Flit mode
logic                       xdlh_xplh_pid_halt_s;       // XDLH to XPLH Halt signal for 68B Flit mode
logic [SPIF_NWORDS-1:0]     xdlh_xplh_pid_stp;          // 
logic [SPIF_NWORDS-1:0]     xdlh_xplh_pid_sdp;          // 
logic [SPIF_NWORDS-1:0]     xdlh_xplh_pid_eot;          // 
logic [SPIF_NWORDS-1:0]     xdlh_xplh_pid_eod;          // 
logic                       xdlh_xplh_pid_force_io_gnt; // Force ARB/MUX Arbiter to CXL.io to transmit generated CXL.io flit with IDLE tokens
logic                       xdlh_xplh_nfm_stall_ack;
logic                       xdlh_xplh_nfm_halt_out;
logic                       xdlh_xplh_nfm_dv_out;
logic [DW-1:0]              xdlh_xplh_nfm_data_out;
logic [SPIF_NWORDS-1:0]     xdlh_xplh_nfm_dlp_start;
logic [SPIF_NWORDS-1:0]     xdlh_xplh_nfm_dlp_end;
logic [SPIF_NWORDS-1:0]     xdlh_xplh_nfm_tlp_start;
logic [SPIF_NWORDS-1:0]     xdlh_xplh_nfm_tlp_end;

// -------------------------------------------------------------------------------------
// XDLH-XPLH interface Mux
// -------------------------------------------------------------------------------------
assign b_xdlh_xplh.skip_pending        = xdlh_protocol_cfg.spif_enable ? xplh_xdlh_skip_s : b_xdlh_xplh_arbmux.skip_pending;
assign b_xdlh_xplh.cmd_is_data         = xdlh_protocol_cfg.spif_enable ? 1'b0             : b_xdlh_xplh_arbmux.cmd_is_data;
assign b_xdlh_xplh.rst_flit_alignment  = 1'b0;
assign b_xdlh_xplh.halt_in             = xdlh_protocol_cfg.spif_enable ? xplh_xdlh_halt_s : b_xdlh_xplh_arbmux.halt_in;

// Tie-off XDLH-XPLH Interface to avoid checker failures
assign b_xdlh_xplh_arbmux.pkt_pending  = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.pkt_pending;
assign b_xdlh_xplh_arbmux.data_valid   = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.data_valid;
assign b_xdlh_xplh_arbmux.data_out     = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.data_out;
assign b_xdlh_xplh_arbmux.stp          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.stp;
assign b_xdlh_xplh_arbmux.sdp          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.sdp;
assign b_xdlh_xplh_arbmux.eot          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.eot;
assign b_xdlh_xplh_arbmux.next_stp     = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.next_stp;
assign b_xdlh_xplh_arbmux.next_sdp     = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.next_sdp;
assign b_xdlh_xplh_arbmux.next_eot     = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.next_eot;
assign b_xdlh_xplh_arbmux.pad          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.pad;
assign b_xdlh_xplh_arbmux.pid          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.pid;
assign b_xdlh_xplh_arbmux.sof          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.sof;
assign b_xdlh_xplh_arbmux.eof          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.eof;
assign b_xdlh_xplh_arbmux.enf          = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.enf;
assign b_xdlh_xplh_arbmux.flit_tlp_dv  = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.flit_tlp_dv;
assign b_xdlh_xplh_arbmux.flit_type_s  = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.flit_type_s;
assign b_xdlh_xplh_arbmux.flit_prot    = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.flit_prot;
assign b_xdlh_xplh_arbmux.ras_dp_err_inband_kbd = xdlh_protocol_cfg.spif_enable ? '0 : b_xdlh_xplh.ras_dp_err_inband_kbd;
assign xplh_xdlh_dllp_halt_out         = xdlh_protocol_cfg.spif_enable ? xplh_xdlh_hdr_dllp_halt_s : xplh_xdlh_dllp_halt;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// SPIF interface to XPLH
// -------------------------------------------------------------------------------------
assign b_xdlh_spif.s_lp_stream       = xdlh_protocol_cfg.cxl_mode_enable ? SID_CXL_IO : SID_PCIE;
assign b_xdlh_spif.s_lp_crc_valid    = '0; // Tie-off CRC signals on SPIF interface
assign b_xdlh_spif.s_lp_crc_data     = '0; // Tie-off CRC signals on SPIF interface
assign b_xdlh_spif.s_lp_corrupt_crc  = '0; // Tie-off corrupt CRC on SPIF interface
assign b_xdlh_spif.s_lp_dllp_valid   = xdlh_xplh_hdr_dllp_valid_s;
assign b_xdlh_spif.s_lp_dllp_ofc     = xdlh_xplh_hdr_dllp_ofc_s;
assign b_xdlh_spif.s_lp_dllp_data    = xdlh_xplh_hdr_dllp_data_s;
assign b_xdlh_spif.s_lp_nop_flit     = xdlh_protocol_cfg.pcie_flit_mode ? xdlh_xplh_hdr_nop_s           : 1'b0;
assign b_xdlh_spif.s_lp_irdy         = xdlh_protocol_cfg.pcie_flit_mode  ? xdlh_xplh_hdr_dv_s           :
 xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_dv_s           : xdlh_xplh_nfm_dv_out    ;
assign b_xdlh_spif.s_lp_valid        = xdlh_protocol_cfg.pcie_flit_mode  ? xdlh_xplh_hdr_dv_s           :
 xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_dv_s           : xdlh_xplh_nfm_dv_out    ;
assign b_xdlh_spif.s_lp_data         = xdlh_protocol_cfg.pcie_flit_mode  ? xdlh_xplh_hdr_data_s[DW-1:0] :
 xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_data_s         : xdlh_xplh_nfm_data_out  ;
assign b_xdlh_spif.s_lp_pri          = xdlh_protocol_cfg.cxl_mode_enable ? {1'b0, !xdlh_xplh_pid_force_io_gnt} : 2'b01;
assign b_xdlh_spif.s_lp_dlp_start    = xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_sdp            : xdlh_xplh_nfm_dlp_start ;
assign b_xdlh_spif.s_lp_dlp_end      = xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_eod            : xdlh_xplh_nfm_dlp_end   ;
assign b_xdlh_spif.s_lp_tlp_start    = xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_stp            : xdlh_xplh_nfm_tlp_start ;
assign b_xdlh_spif.s_lp_tlp_end      = xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_eot            : xdlh_xplh_nfm_tlp_end   ;
assign xdlh_lp_stall_ack             = xdlh_protocol_cfg.pcie_flit_mode  ? xdlh_xplh_hdr_stall_ack_s    :
 xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_stall_ack_s    : xdlh_xplh_nfm_stall_ack ;
assign xplh_xdlh_halt_s              = xdlh_protocol_cfg.pcie_flit_mode  ? xdlh_xplh_hdr_halt_s         :
 xdlh_protocol_cfg.cxl_mode_enable ? xdlh_xplh_pid_halt_s         : xdlh_xplh_nfm_halt_out  ;
assign xplh_xdlh_skip_s              = xdlh_protocol_cfg.pcie_flit_mode  ? 1'b0                         :
 xdlh_protocol_cfg.cxl_mode_enable ? 1'b0                         : b_xdlh_spif.s_pl_skip_trdy;

assign b_xdlh_spif.s_lp_data_chk     = xdlh_protocol_cfg.pcie_flit_mode ? xdlh_xplh_hdr_data_s[DW_W_PROT-1:DW] : '0;
assign b_xdlh_spif.s_lp_rasdp_error  = xdlh_protocol_cfg.pcie_flit_mode ? b_xdlh_xplh.ras_dp_err_inband_kbd    : '0;
// -------------------------------------------------------------------------------------

assign xdlh_xplh_pkt_pending_s =  b_xdlh_xplh.pkt_pending;
// -------------------------------------------------------------------------------------
// CXL.io PID Placeholder Insertion Module Instantiation
// -------------------------------------------------------------------------------------
assign xdlh_xplh_pid_enable_s  = xdlh_protocol_cfg.cxl_mode_enable && !xdlh_protocol_cfg.pcie_flit_mode;


xdlh_cxl_io_flit_pid
 u_xdlh_cxl_io_flit_pid (
    // -- inputs --
    .core_clk                      ( core_clk                      ),
    .core_rst_n                    ( core_rst_n                    ),
    .cxl_mode_enable               ( xdlh_xplh_pid_enable_s        ),
    .xdlh_xplh_stall_req           ( xdlh_pl_stall_req             ),
    .xdlh_xplh_pkt_pending         ( xdlh_xplh_pkt_pending_s       ),
    .xdlh_xplh_dv                  ( b_xdlh_xplh.data_valid        ),
    .xdlh_xplh_data                ( b_xdlh_xplh.data_out          ),
    .xdlh_xplh_stp                 ( b_xdlh_xplh.stp               ),
    .xdlh_xplh_sdp                 ( b_xdlh_xplh.sdp               ),
    .xdlh_xplh_eot                 ( b_xdlh_xplh.eot               ),
    .xdlh_xplh_eod                 ( xdlh_xplh_dllp_end            ),
    .xplh_arbmux_xdlh_halt         ( !b_xdlh_spif.s_pl_trdy        ),
    // -- outputs --
    .xdlh_xplh_stall_ack           ( xdlh_xplh_pid_stall_ack_s     ),
    .xdlh_xplh_arbmux_force_io_gnt ( xdlh_xplh_pid_force_io_gnt    ),
    .xdlh_xplh_arbmux_stp          ( xdlh_xplh_pid_stp             ),
    .xdlh_xplh_arbmux_sdp          ( xdlh_xplh_pid_sdp             ),
    .xdlh_xplh_arbmux_eot          ( xdlh_xplh_pid_eot             ),
    .xdlh_xplh_arbmux_eod          ( xdlh_xplh_pid_eod             ),
    .xdlh_xplh_arbmux_dv           ( xdlh_xplh_pid_dv_s            ),
    .xdlh_xplh_arbmux_data         ( xdlh_xplh_pid_data_s          ),
    .xplh_xdlh_halt                ( xdlh_xplh_pid_halt_s          )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Flit Store-and-Forward module instantiation for Flit Marker detection
// -------------------------------------------------------------------------------------
logic [DW_W_PROT-1:0]  int_xdlh_xplh_data_s;

assign int_xdlh_xplh_data_s = { b_xdlh_xplh.flit_prot, b_xdlh_xplh.data_out};

xdlh_cxl_flit_marker
 u_xdlh_cxl_flit_marker (
    // -- inputs --
    .core_clk                  ( core_clk                             ),
    .core_rst_n                ( core_rst_n                           ),
    .cxl_mode_enable           ( xdlh_protocol_cfg.cxl_pcie_flit_mode ),
    .xtlh_xdlh_dv              ( b_xdlh_xplh.data_valid               ),
    .xtlh_xdlh_sof             ( b_xdlh_xplh.sof                      ),
    .xtlh_xdlh_eof             ( b_xdlh_xplh.eof                      ),
    .xtlh_xdlh_data            ( int_xdlh_xplh_data_s                 ),
    .xplh_xdlh_halt            ( fm_xdlh_xplh_halt_s                  ),
    // -- outputs --
    .xdlh_flit_in_progress     ( fm_xdlh_flit_in_progress             ),
    .xdlh_xtlh_halt            ( xdlh_xplh_hdr_halt_s                 ),
    .xdlh_xplh_dv_out          ( fm_xdlh_xplh_dv_s                    ),
    .xdlh_xplh_sof_out         ( fm_xdlh_xplh_sof_s                   ),
    .xdlh_xplh_eof_out         ( fm_xdlh_xplh_eof_s                   ),
    .xdlh_xplh_data_out        ( fm_xdlh_xplh_data_s                  )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Flit Mode SPIF Datapath Module Instantiation
// -------------------------------------------------------------------------------------
xdlh_fm_spif_datapath
 u_xdlh_fm_spif_datapath (
    // -- inputs --
    .core_clk                  ( core_clk                             ),
    .core_rst_n                ( core_rst_n                           ),
    .xdlh_flit_in_progress     ( fm_xdlh_flit_in_progress             ),
    .xdlh_xplh_spif_enable     ( xdlh_protocol_cfg.spif_enable        ),
    .xtlh_xdlh_cmd_done        ( xtlh_xdlh_cmd_done                   ),
    .xdlh_xplh_stall_req       ( xdlh_pl_stall_req                    ),
    .xdlh_pm_state_req         ( xdlh_pm_state_req                    ),
    .xdlh_xplh_sof             ( fm_xdlh_xplh_sof_s                   ),
    .xdlh_xplh_eof             ( fm_xdlh_xplh_eof_s                   ),
    .xdlh_xplh_dv              ( fm_xdlh_xplh_dv_s                    ),
    .xdlh_xplh_data_in         ( fm_xdlh_xplh_data_s                  ),
    .xdlh_xplh_dllp_pending    ( xdlh_xplh_dllp_pending               ), 
    .xdlh_xplh_dllp_valid      ( xdlh_xplh_dllp_valid                 ),
    .xdlh_xplh_dllp_ofc        ( xdlh_xplh_dllp_ofc                   ),
    .xdlh_xplh_dllp_data       ( xdlh_xplh_dllp_data                  ),
    .xplh_xdlh_dllp_halt       ( !b_xdlh_spif.s_pl_dllp_trdy          ),
    .xplh_arbmux_xdlh_halt     ( !b_xdlh_spif.s_pl_trdy               ),
    // -- outputs --
    .xdlh_xplh_stall_ack       ( xdlh_xplh_hdr_stall_ack_s            ),
    .xdlh_xplh_dllp_valid_out  ( xdlh_xplh_hdr_dllp_valid_s           ),
    .xdlh_xplh_dllp_ofc_out    ( xdlh_xplh_hdr_dllp_ofc_s             ),
    .xdlh_xplh_dllp_data_out   ( xdlh_xplh_hdr_dllp_data_s            ),
    .xplh_xdlh_dllp_halt_out   ( xplh_xdlh_hdr_dllp_halt_s            ),
    .xdlh_xplh_halt_out        ( fm_xdlh_xplh_halt_s                  ),
    .xdlh_xplh_dv_out          ( xdlh_xplh_hdr_dv_s                   ),
    .xdlh_xplh_sof_out         ( xdlh_xplh_hdr_sof_s                  ),
    .xdlh_xplh_eof_out         ( xdlh_xplh_hdr_eof_s                  ),
    .xdlh_xplh_enf_out         ( xdlh_xplh_hdr_nop_s                  ),
    .xdlh_xplh_data_out        ( xdlh_xplh_hdr_data_s                 )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// PCIe Non-Flit Mode SPIF Datapath Module Instantiation
// -------------------------------------------------------------------------------------
xdlh_spif_datapath
 u_xdlh_spif_datapath (
// Inputs ------------------------------------------------------------------------------
    .core_clk                 ( core_clk                              ),
    .core_rst_n               ( core_rst_n                            ),
    .xdlh_xplh_spif_enable    ( xdlh_protocol_cfg.spif_enable         ),
    .xdlh_xplh_pcie_enable    ( xdlh_protocol_cfg.pcie_nfm_mode       ),
    .xdlh_xplh_stall_req      ( xdlh_pl_stall_req                     ),
    .xdlh_xplh_dv             ( b_xdlh_xplh.data_valid                ),
    .xdlh_xplh_data_in        ( b_xdlh_xplh.data_out                  ),
    .xdlh_xplh_sdp            ( b_xdlh_xplh.sdp                       ),
    .xdlh_xplh_stp            ( b_xdlh_xplh.stp                       ),
    .xdlh_xplh_eot            ( b_xdlh_xplh.eot                       ),
    .xdlh_xplh_dllp_end       ( xdlh_xplh_dllp_end                    ),
    .xdlh_xplh_pkt_pending    ( xdlh_xplh_pkt_pending_s               ),
    .xplh_xdlh_halt           ( !b_xdlh_spif.s_pl_trdy                ),
// Outputs -----------------------------------------------------------------------------
    .xdlh_xplh_stall_ack      ( xdlh_xplh_nfm_stall_ack               ),
    .xdlh_xplh_halt_out       ( xdlh_xplh_nfm_halt_out                ),
    .xdlh_xplh_dv_out         ( xdlh_xplh_nfm_dv_out                  ),
    .xdlh_xplh_data_out       ( xdlh_xplh_nfm_data_out                ),
    .xdlh_xplh_dlp_start      ( xdlh_xplh_nfm_dlp_start               ),
    .xdlh_xplh_dlp_end        ( xdlh_xplh_nfm_dlp_end                 ),
    .xdlh_xplh_tlp_start      ( xdlh_xplh_nfm_tlp_start               ),
    .xdlh_xplh_tlp_end        ( xdlh_xplh_nfm_tlp_end                 )
);

endmodule

