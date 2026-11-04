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
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh.sv#15 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Packet Layer handler
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/cx_pl_pkg.svh"

module rplh
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_DETECT_QUIET;
import cx_pl_pkg::rplh_xplh_fm_retry_t;
import DWC_pcie_core_pkg::rplh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
import spif_pkg::SPIF_NBYTES;
import spif_pkg::SPIF_NDPBITS;
import spif_pkg::SPIF_NCRC;
import spif_pkg::SPIF_NWORDS;
import spif_pkg::SPIF_NDLLP;
import spif_pkg::SPIF_PL_NVLD;
import spif_pkg::protocol_cfg_t;
import spif_pkg::stream_id_e;
import spif_pkg::SID_PCIE;
import spif_pkg::protocol_type_e;
import spif_pkg::PCIE_MODE;
import spif_pkg::CXL_MODE1;
import spif_pkg::protocol_fmt_e;
import spif_pkg::FMT_CXL_68BVH;
import cx_pl_pkg::P_NFM_NW;
import cx_pl_pkg::P_NFM_DW;
#(
parameter INST          = 0,                              // The uniquifying parameter for each port logic instance.
parameter NL            = `CX_NL,                         // Max number of lanes supported
parameter NB            = `CX_NB,                         // Number of symbols (bytes) per clock cycle
parameter AW            = `CX_ANB_WD,                     // Width of the active number of bytes
parameter NW            = `CX_PL_NW,                      // Number of 32-bit dwords handled by the datapath each clock.
parameter DW            = (32*NW),                        // Width of datapath in bits.
parameter DATA_PAR_WD   = `CX_RAS_RPL_DATA_PROT_WD,       // Data protection width
parameter DW_W_PAR      = DW + DATA_PAR_WD,               // Data width with protection bits
parameter CXL_NW        = `CX_CXL_20_NW,                  // CXL Flit width in DWords
parameter CXL_DW        = (32*CXL_NW),                    // CXL Flit width
parameter CXL_WD        = `CX_ARBMUX_FLIT_WIDTH,          // ARB/MUX flit data width
parameter DL_NW         = `CX_NW,                         // Number of 32-bit dwords handled by RDLH.
parameter DL_DW_W_PAR   = (32*DL_NW)+`TRGT_DATA_PROT_WD,  // Width of datapath in bits plus the parity bits passed to RDLH.
parameter TP            = `TP                             // Clock to Q delay (simulator insurance)
)

           (
// ---- interfaces -----------
spif_if.rplh_master_mp       b_rplh_spif,                     // RPLH SPIF interface
// ---- inputs ---------------
input                        core_clk,
input                        core_rst_n,
input   [5:0]                smlh_link_mode,
input   [AW-1:0]             active_nb_wire,
input   [1:0]                rmlh_rplh_rcvd_idle_gen12,
input   [AW-1:0]             active_nb_gen34,
input                        rxdata_dv,                       // data is valid this cycle
input   [(NL*NB*8)-1:0]      rxdata,                          // Incoming data
input   [(NL*NB)-1:0]        rxdatak,                         // Incoming k indication
input   [(NL*NB)-1:0]        rxerror,                         // Errors reported by PHY
input   [2:0]                current_data_rate,
input                        vlsm_pl_link_up,                 // Physical Layer Link Up
input                        cxl_sh_bypass,                   // SyncHeader_Bypass
input                        os_in_datastream,                // OS detected within data stream
input                        search_for_tokens,               // enable token processing while in a data stream
input                        accept_eds_cycle,                // on this cycle the EDS token can be accepted, means we are at the endo of a block
input                        expect_eds,                      // Signal from deskew block to inform token_finder that EDS is expected
input   protocol_cfg_t       rplh_protocol_cfg,               // Protocol Configuration for PLH Layer
input                        smlh_flit_mode_enable,           // Flit mode enabled
input   ltssm_state_e        smlh_ltssm_state_wire,           // Current LTSSM state before FF for high fanout. 
input                        smlh_block_dl_init,              // SPIF: Indication from the LogPHY to block Initialization of DLLPs
input                        cfg_upstream_port,               // Upstream port when it is high
output                       rplh_ptm_sot,                    // indicate to PTM logic a PTM Flit is observed
output                       rplh_ptm_request,                // observed PTM request
output                       rplh_ptm_response,               // observed PTM response
output                       rplh_ptm_duplicate,              // observed PTM message in duplicate flit
input                        cfg_acknack_disable,             // Prevent sending of ack/nak packetsw
input                        cdm_ras_des_einj2_enable,        // Error injection 2 enable
input   [1:0]                cdm_ras_des_einj2_dllp_type,     // Error injection 2 DLLP type
input  flit_err_inj_interface_struct cdm_plh_flit_err_inj_interface,  // Flit Error Injection interface struct
// ---- outputs ---------------
output                       rplh_rdlh_pkt_dv,                // received data is valid this cycle
output  [DL_NW-1:0]          rplh_rdlh_dllp_start,            // indication of the dword location of SDP or STP
output  [DL_NW-1:0]          rplh_rdlh_tlp_start,             //
output  [DL_NW-1:0]          rplh_rdlh_pkt_end,               // indication of the dword location of END or EBD
output  [DL_NW-1:0]          rplh_rdlh_pkt_edb,               //
output  [DL_DW_W_PAR-1:0]    rplh_rdlh_pkt_data,              // received data
output  [DL_NW-1:0]          rplh_rdlh_pkt_err,               // Framing error indication (per dword)
output                       rplh_rmlh_pkt_err,               // Framing error indication (global)
output  [4:0]                rplh_rmlh_pkt_err_ptr,           // error pointer indication
output  [DL_NW-1:0]          rplh_rdlh_nak,                   // NAK indication
output  [DL_NW-1:0]          rplh_rdlh_tlp_idl,               // indicates the dword is empty and can be discarded, due to flit overhead it is possible that there 
                                                              // are 5 empty dws in the middle of a tlp
output  [DL_NW-1:0]          rplh_rdlh_tlp_pfx,               // indicates the dword locations of pfx
output                       rplh_rdlh_fm_nullified,          // The last TLP ending was Nullified by the Flit Marker
output                       rplh_rdlh_fm_poisoned,           // The last TLP ending was Poisoned by the Flit Marker
output                       rplh_flit_dl_prot_err,           // indicates Data link protocol error
output rplh_xplh_fm_retry_t  rplh_xplh_fm_retry,              // RPLH to XPLH Flit Mode Retry Interface
output  [31:0]               rplh_rdlh_fm_dllp_data,          // DLLP data extracted from DL bytes
output                       rplh_rdlh_fm_dllp_valid,         // Valid DLLP data
output                       rplh_rdlh_fm_dllp_opt_fc_up,     // DLLP is an Optimized FC update
output rplh_flit_logging_interface_struct rplh_cdm_flit_logging_interface,  // Flit logging interface struct
output                       rplh_cxl_corr_pid_err,           // Correctable protocol ID error
output                       rplh_cxl_uncorr_pid_err,         // Uncorrectable protocol ID error
output                       rplh_cxl_unexp_pid_err,          // Unexpected protocol ID error
output                       rplh_cxl_eds_err,                // EDS error
output                       rplh_cxl_pl_rcvd_flit,           // Received flit not generated by Physical Layer
output  [1:0]                rplh_cdm_flit_err_inj_status,    // Flit Error Injection Status
output  [1:0]                rplh_rcvd_idle                   // RMLH block keeps track of the number of idle received continously.
                                                              // Bit 0 indicates 8 continous idle symbol received, bit 1 indicates 1 idle received
);

// ============================================================
// Local Parameters
// ============================================================
localparam   GEN3_NB  = `CX_NB_GEN3;
localparam   ANB_LOW  = (GEN3_NB>=16) ? 5 : (GEN3_NB==8) ? 4 : (GEN3_NB==4) ? 3 : (GEN3_NB==2) ? 2 : 1;
localparam   ANB_HIGH = (NB>=16) ? 5 : (NB==8) ? 4 : (NB==4) ? 3 : (NB==2) ? 2 : 1;

// ============================================================
// Quasi-static Signals
// ============================================================
typedef struct packed {
    logic flit_mode_enable;
}
rplh_quasi_static_s;
rplh_quasi_static_s qs_in, qs;

assign qs_in.flit_mode_enable = 1'b0 |smlh_flit_mode_enable ;

delay_n
 
  #( .N (1), .WD ($bits(rplh_quasi_static_s)) )
  u_rplh_qs_pipeline (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (qs_in),
  .dout   (qs)
);

// ============================================================
// internal Signals
// ============================================================
wire [4:0] link_mode;
assign link_mode = (NL==16) ?           smlh_link_mode[4:0]  :
                   (NL==8)  ? {1'b0   , smlh_link_mode[3:0]} :
                   (NL==4)  ? {2'b00  , smlh_link_mode[2:0]} :
                   (NL==2)  ? {3'b000 , smlh_link_mode[1:0]} :
                              {4'b0000, smlh_link_mode[0]  };


wire    [AW-1:0]        active_sym_gen34;
wire    [AW-1:0]        int_active_nb;
// Suppress the less significant bits for higher speeds
assign int_active_nb = {                   active_nb_gen34[ANB_HIGH-1:ANB_LOW-1],{ANB_LOW-1{1'b0}}};

assign active_sym_gen34 = 
                          (int_active_nb==8 ) ? `CX_8S  :
                          (int_active_nb==4 ) ? `CX_4S  :
                          (int_active_nb==2 ) ? `CX_2S  : `CX_1S;

wire    [4:0]           active_nw_gen34;
assign active_nw_gen34  = link_mode[4] ? active_sym_gen34[2] ? 5'h10: active_sym_gen34[1] ? 5'h8 : 5'h4 :                              // 4sx16,2sx16, 1sx16
                          link_mode[3] ? active_sym_gen34[3] ? 5'h10: active_sym_gen34[2] ? 5'h8 : active_sym_gen34[1] ? 5'h4 : 5'h2 : // 8sx8, 4sx8, 2sx8, 1sx8
                          link_mode[2] ? active_sym_gen34[3] ? 5'h8 : active_sym_gen34[2] ? 5'h4 : active_sym_gen34[1] ? 5'h2 : 5'h1 : // 8sx4, 4sx4, 2sx4, 1sx4
                          link_mode[1] ? active_sym_gen34[3] ? 5'h4 : active_sym_gen34[2] ? 5'h2 : 5'h1 :    // 8sx2, 4sx2, 2sx2, 1sx2
                          link_mode[0] ? active_sym_gen34[3] ? 5'h2 : 5'h1 : 5'h1 ;                          // 8sx1, 4sx1, 2sx1, 1sx1

// Pipe-line of smlh_ltssm_state/active_nb for high fanout. 
// The smlh_ltssm_state_wire/active_nb_wire are a combinational signal(before FF). So, no timing change by this pipe-line.
ltssm_state_e            smlh_ltssm_state ;
reg    [AW-1:0]          active_nb ;

always @(posedge core_clk or negedge core_rst_n)
begin : active_nb_proc
    if (!core_rst_n) begin
        smlh_ltssm_state <= #TP S_DETECT_QUIET;
        active_nb        <= #TP `CX_NB;
    end
    else begin
        smlh_ltssm_state <= #TP smlh_ltssm_state_wire;
        active_nb        <= #TP active_nb_wire;
    end
end
// ============================================================
// CXL Configuration
// ============================================================
wire   cxl_mode_enable; // Link is up in CXL protocol mode
wire   cxl_mc_enable;   // CXL.cachemem protocol is enabled

assign cxl_mode_enable  = vlsm_pl_link_up && rplh_protocol_cfg.cxl_mode_enable;
assign cxl_mc_enable    = rplh_protocol_cfg.cxl_mem_enable || rplh_protocol_cfg.cxl_cache_enable;

// ----------------------------------------------------------------------------
// Demux
// ----------------------------------------------------------------------------
wire [5:0]             demux_link_mode;
wire [AW-1:0]          demux_active_nb_gen34;
wire                   demux_search_for_tokens;
wire                   demux_accept_eds_cycle;
wire                   demux_expect_eds;
wire                   demux_rxdata_dv;
wire [DW-1:0]          demux_rxdata;
wire [1:0]             demux_rcvd_idle;
wire [1:0]             rcvd_idle_3;

assign demux_link_mode         = {1'b0, link_mode};
assign demux_active_nb_gen34   = active_sym_gen34;
assign demux_rxdata_dv         = cxl_mode_enable ? '0 : rxdata_dv;
assign demux_rxdata            = cxl_mode_enable ? '0 : {{(DW-(NL*NB*8)){1'b0}}, rxdata};
assign demux_accept_eds_cycle  = cxl_mode_enable ? '0 : accept_eds_cycle;
assign demux_expect_eds        = cxl_mode_enable ? '0 : expect_eds;
assign demux_search_for_tokens = cxl_mode_enable ? '0 : search_for_tokens;
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// CXL Flit Finder (68B Flit Mode) Instantiation
// ----------------------------------------------------------------------------
stream_id_e            rplh_cxl_stream;              // RPLH CXL Flit Finder: Stream ID
wire                   rplh_cxl_valid;               // RPLH CXL Flit Finder: Data Valid
wire [P_NFM_DW-1:0]    rplh_cxl_data;                // RPLH CXL Flit Finder: Data
wire                   rplh_cxl_crc_valid;           // RPLH CXL Flit Finder: CRC Valid
wire [15:0]            rplh_cxl_crc_data;            // RPLH CXL Flit Finder: CRC
wire                   rplh_cxl_rcvd_flit;           // RPLH CXL Flit Finder: Received flit not generated by Physical Layer
wire                   rplh_cxl_rx_flush;

rplh_cxl_flit_finder

#(INST) u_rplh_cxl_flit_finder(
// ---- inputs ---------------
    .core_clk                      (core_clk),
    .core_rst_n                    (core_rst_n),
    .cxl_mode_enable               (cxl_mode_enable),
    .cxl_mode_20                   (rplh_protocol_cfg.cxl_vh_enable),
    .cxl_io_enable                 (rplh_protocol_cfg.cxl_mode_enable),
    .cxl_mc_enable                 (cxl_mc_enable),
    .cxl_sh_bypass                 (cxl_sh_bypass),
    .smlh_link_mode                ({1'b0,link_mode}),
    .active_nw_gen34               (active_nw_gen34),
    .os_in_datastream              ( rplh_protocol_cfg.pcie_flit_mode ? 1'b0 : os_in_datastream),
    .search_for_tokens             (search_for_tokens),
    .accept_eds_cycle              (accept_eds_cycle),
    .rcvd_idle                     (rcvd_idle_3),
    .rxdata_dv                     ( rplh_protocol_cfg.pcie_flit_mode ? 1'b0 : rxdata_dv),
    .rxdata                        (rxdata[P_NFM_DW-1:0]),
    // outputs
    .rplh_cxl_stream               (rplh_cxl_stream),
    .rplh_cxl_valid                (rplh_cxl_valid),
    .rplh_cxl_data                 (rplh_cxl_data),
    .rplh_cxl_crc_valid            (rplh_cxl_crc_valid),
    .rplh_cxl_crc_data             (rplh_cxl_crc_data),
    .rplh_cxl_corr_pid_err         (rplh_cxl_corr_pid_err),
    .rplh_cxl_uncorr_pid_err       (rplh_cxl_uncorr_pid_err),
    .rplh_cxl_unexp_pid_err        (rplh_cxl_unexp_pid_err),
    .rplh_cxl_eds_err              (rplh_cxl_eds_err),
    .rplh_cxl_rx_flush             (rplh_cxl_rx_flush),
    .rplh_cxl_rcvd_flit            (rplh_cxl_rcvd_flit),
    .rplh_cxl_rcvd_null            (demux_rcvd_idle)
);
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// RPLH SPIF Interface Connections
// ----------------------------------------------------------------------------
spif_if b_fstep_spif ();
stream_id_e                 rplh_flit_pl_stream;          // RPLH PCIe Flit Finder: Stream ID
wire                        rplh_flit_pl_nullified;       // RPLH PCIe Flit Finder: Last TLP Nullified Flit Marker
wire                        rplh_flit_pl_poisoned;        // RPLH PCIe Flit Finder: Last TLP Poisoned Flit Marker
wire                        rplh_flit_pl_valid;           // RPLH PCIe Flit Finder: Data Valid
wire [SPIF_NBYTES*8-1:0]    rplh_flit_pl_data;            // RPLH PCIe Flit Finder: Data
wire [SPIF_NDPBITS-1:0]     rplh_flit_pl_data_chk;        // RPLH PCIe Flit Finder: Data Protection
wire                        rplh_flit_pl_dllp_valid;
wire                        rplh_flit_pl_dllp_ofc;
wire [SPIF_NDLLP*8-1:0]     rplh_flit_pl_dllp_data;
wire                        rplh_fm_cxl_rcvd_flit;        // corrupted ALMP detected to allow equalization to clear to transmit Nak request

assign b_fstep_spif.s_pl_stream        = rplh_protocol_cfg.pcie_flit_mode  ? rplh_flit_pl_stream   : 
 rplh_protocol_cfg.cxl_mode_enable ? rplh_cxl_stream       : SID_PCIE ;
assign b_fstep_spif.s_pl_valid         = rplh_protocol_cfg.pcie_flit_mode  ? rplh_flit_pl_valid    : 
 rplh_protocol_cfg.cxl_mode_enable ? rplh_cxl_valid        : rplh_rdlh_pkt_dv;
assign b_fstep_spif.s_pl_data          = rplh_protocol_cfg.pcie_flit_mode  ? rplh_flit_pl_data     : 
 rplh_protocol_cfg.cxl_mode_enable ? {{DW-P_NFM_DW{1'b0}}, rplh_cxl_data} : rplh_rdlh_pkt_data[SPIF_NBYTES*8-1:0];
assign b_fstep_spif.s_pl_data_chk      = rplh_protocol_cfg.pcie_flit_mode  ? rplh_flit_pl_data_chk : {SPIF_NDPBITS{1'b0}};
assign b_fstep_spif.s_pl_crc_valid     = rplh_protocol_cfg.pcie_flit_mode  ? 1'b0                  : 
 rplh_protocol_cfg.cxl_mode_enable ? rplh_cxl_crc_valid    : 1'b0;
assign b_fstep_spif.s_pl_crc_data      = rplh_protocol_cfg.pcie_flit_mode  ? {SPIF_NCRC*8{1'b0}}   : 
 rplh_protocol_cfg.cxl_mode_enable ? rplh_cxl_crc_data     : {SPIF_NCRC*8{1'b0}};
assign b_fstep_spif.s_pl_rx_flush      = rplh_protocol_cfg.pcie_flit_mode  ? 1'b0                  : 
 rplh_protocol_cfg.cxl_mode_enable ? rplh_cxl_rx_flush     : 1'b0;
assign b_fstep_spif.s_pl_rx_nak        =  rplh_rdlh_nak              ;
assign b_fstep_spif.s_pl_dlp_start     =  rplh_rdlh_dllp_start       ;
assign b_fstep_spif.s_pl_dlp_end       =  rplh_rdlh_pkt_end          ;
assign b_fstep_spif.s_pl_tlp_start     =  rplh_rdlh_tlp_start        ;
assign b_fstep_spif.s_pl_tlp_end       =  rplh_rdlh_pkt_end          ;
assign b_fstep_spif.s_pl_tlp_edb       =  rplh_rdlh_pkt_edb          ;
assign b_fstep_spif.s_pl_error         = |rplh_rdlh_pkt_err          ;
assign b_fstep_spif.s_pl_nullified     = rplh_flit_pl_nullified      ;
assign b_fstep_spif.s_pl_poisoned      = rplh_flit_pl_poisoned       ;
assign b_fstep_spif.s_pl_dllp_valid    = rplh_flit_pl_dllp_valid     ; // rplh_rdlh_fm_dllp_valid     ;
assign b_fstep_spif.s_pl_dllp_ofc      = rplh_flit_pl_dllp_ofc       ; // rplh_rdlh_fm_dllp_opt_fc_up ;
assign b_fstep_spif.s_pl_dllp_data     = rplh_flit_pl_dllp_data      ; // rplh_rdlh_fm_dllp_data      ;
// From RPLH to SMLH
assign rplh_cxl_pl_rcvd_flit   = rplh_protocol_cfg.pcie_flit_mode ? (rplh_flit_pl_valid || rplh_fm_cxl_rcvd_flit) : rplh_cxl_rcvd_flit;
// ----------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// SPIF RPLH to RDLH Synchronizers
// -------------------------------------------------------------------------------------
localparam FSTEP_FIFO_WIDTH       = 3 + $bits(stream_id_e) + SPIF_PL_NVLD + SPIF_NWORDS*6 + SPIF_NCRC*8 + SPIF_NBYTES*8
                                      + SPIF_NDPBITS
                                      + 4 + SPIF_NDLLP*8
                                  ;

logic [FSTEP_FIFO_WIDTH-1:0] fstep_push_data;
logic [FSTEP_FIFO_WIDTH-1:0] fstep_pop_data;

// Interface from RPLH
assign fstep_push_data     = {
    b_fstep_spif.s_pl_stream,
    b_fstep_spif.s_pl_valid,
    b_fstep_spif.s_pl_data,
    b_fstep_spif.s_pl_data_chk,
    b_fstep_spif.s_pl_crc_valid,
    b_fstep_spif.s_pl_crc_data,
    b_fstep_spif.s_pl_rx_flush,
    b_fstep_spif.s_pl_rx_nak,
    b_fstep_spif.s_pl_dlp_start,
    b_fstep_spif.s_pl_dlp_end,
    b_fstep_spif.s_pl_tlp_start,
    b_fstep_spif.s_pl_tlp_end,
    b_fstep_spif.s_pl_tlp_edb,
    b_fstep_spif.s_pl_error
    ,
    b_fstep_spif.s_pl_nullified,
    b_fstep_spif.s_pl_poisoned,
    b_fstep_spif.s_pl_dllp_valid,
    b_fstep_spif.s_pl_dllp_ofc,
    b_fstep_spif.s_pl_dllp_data
};

// Interface to RDLH
assign {
    b_rplh_spif.s_pl_stream,
    b_rplh_spif.s_pl_valid,
    b_rplh_spif.s_pl_data,
    b_rplh_spif.s_pl_data_chk,
    b_rplh_spif.s_pl_crc_valid,
    b_rplh_spif.s_pl_crc_data,
    b_rplh_spif.s_pl_rx_flush,
    b_rplh_spif.s_pl_rx_nak,
    b_rplh_spif.s_pl_dlp_start,
    b_rplh_spif.s_pl_dlp_end,
    b_rplh_spif.s_pl_tlp_start,
    b_rplh_spif.s_pl_tlp_end,
    b_rplh_spif.s_pl_tlp_edb,
    b_rplh_spif.s_pl_error
    ,
    b_rplh_spif.s_pl_nullified,
    b_rplh_spif.s_pl_poisoned,
    b_rplh_spif.s_pl_dllp_valid,
    b_rplh_spif.s_pl_dllp_ofc,
    b_rplh_spif.s_pl_dllp_data
} = fstep_push_data;

assign fstep_pop_data = fstep_push_data;
// -------------------------------------------------------------------------------------


// ============================================================
// Active Decoder
// ============================================================

      // Datapath width >= 128  AND  Number of Lanes >= 4
      // RMLH_PKT_FINDER_MODE4: both token_finder4 and token_finder3 (with a reduced datapath) are used
      `define RMLH_PKT_FINDER_MODE4

      // Parameters used to instantiate the reduced token_finder_3
      localparam DW_R = (`CX_NB == 16) ? 256 : (`CX_NB == 8)? 128 : 64;
      localparam NW_R = DW_R/32;
      localparam NL_F4 = (NB==1) ? 4 : 2; //1s : NL>4. Others:NL>2


enum logic [1:0] {
    Gen12_pkt_finder,    // Gen1 & Gen2 decoder
    Gen34_token_finder3, // Gen3 & Gen4 decoder for small data widths
    Gen34_token_finder4, // Gen3 & Gen4 decoder for wide data widths
    FlitM_token_finder6  // Gen1 to Gen6 in Flit Mode
} active_decoder;

always_comb begin : active_decoder_PROC
    if (qs.flit_mode_enable)
        active_decoder = FlitM_token_finder6;
    else
    if ((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) begin
        if ((active_nw_gen34 > 2) && (link_mode > NL_F4))
            active_decoder = Gen34_token_finder4;
        else
            active_decoder = Gen34_token_finder3;
    end else
        active_decoder = Gen12_pkt_finder;
end

// ============================================================
// Gen1 / Gen2 Section
// ============================================================
wire rxdata_dv_gen12;
assign rxdata_dv_gen12 = (active_decoder == Gen12_pkt_finder) ? rxdata_dv : 1'b0;

wire [NW-1:0] dllp_start;
wire [NW-1:0] tlp_start;
wire [NW-1:0] pkt_end;
wire [NW-1:0] pkt_edb;
wire [DW-1:0] pkt_data;
wire          pkt_dv;
wire [NW-1:0] pkt_err;
wire [NW-1:0] nak;

rplh_token_finder1
 u_rplh_token_finder1
(
// ---- inputs ---------------
    .core_clk                 (core_clk),
    .core_rst_n               (core_rst_n),
    .smlh_link_mode           (smlh_link_mode),
    .active_nb                (active_nb[3:0]),
    .rxdata_dv                (rxdata_dv_gen12),
    .rxdata                   (rxdata),
    .rxdatak                  (rxdatak),
    .rxerror                  (rxerror),
// ---- outputs ---------------
    .rplh_rdlh_dllp_start     (dllp_start),
    .rplh_rdlh_tlp_start      (tlp_start),
    .rplh_rdlh_pkt_end        (pkt_end),
    .rplh_rdlh_pkt_edb        (pkt_edb),
    .rplh_rdlh_pkt_data       (pkt_data),
    .rplh_rdlh_pkt_dv         (pkt_dv),
    .rplh_rdlh_pkt_err        (pkt_err),
    .rplh_rdlh_nak            (nak)
);

// ============================================================
// Gen3 Section
// ============================================================
wire     [NW-1:0]       dllp_start_3;
wire     [NW-1:0]       tlp_start_3;
wire     [NW-1:0]       pkt_end_3;
wire     [NW-1:0]       pkt_edb_3;
wire     [DW-1:0]       pkt_data_3;
wire                    pkt_dv_3;
wire     [NW-1:0]       pkt_err_3;
wire     [NW*5-1:0]     pkt_err_ptr_3;
//wire     [1:0]          rcvd_idle_3;

wire [1:0]           valid_bytes_gen34;    // Number of valid bytes when lower than 4
wire [DW-1:0]        rxdata3;              // Gen3 Rx Data (always in DW)
wire                 rxdata3_dv;           // Gen3 Data Valid
reg  [1:0]           sym_cnt3;             // Received Data Symbol Counter
reg  [23:0]          latched_rxdata3;      // Latched Received Data (up to 3 bytes)

// In case of 4 o more bytes (i.e. 1 or more DWs of data) valid_bytes_gen34 value is '0' 
assign valid_bytes_gen34 = 
             link_mode[1] ? active_sym_gen34 [0] ? 2'b10 : 2'b00 :                                         // 1sx2 : higher
             link_mode[0] ? active_sym_gen34 [0] ? 2'b01 : active_sym_gen34 [1] ? 2'b10 : 2'b00 : 2'b00;   // 1sx1 : 2sx1 : higher

always @(posedge core_clk or negedge core_rst_n)
begin : sym_cnt3_proc
    if (!core_rst_n)
        sym_cnt3 <= #TP 2'b00;
    else if ((active_decoder == Gen12_pkt_finder) || (!demux_search_for_tokens))
        sym_cnt3 <= #TP 2'b00;
    else if (demux_rxdata_dv)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        sym_cnt3 <= #TP sym_cnt3 + valid_bytes_gen34[1:0];
// spyglass enable_block W164a
end

always @(posedge core_clk or negedge core_rst_n)
begin : latched_rxdata3_proc
    if (!core_rst_n) begin
        latched_rxdata3 <= #TP 24'h0;
    end
    else if ((active_decoder == Gen12_pkt_finder) || (!demux_search_for_tokens)) begin
        latched_rxdata3 <= #TP 24'h0;
    end
    else if (demux_rxdata_dv) begin
        if(valid_bytes_gen34[0])
            latched_rxdata3 <= #TP { demux_rxdata[7:0], latched_rxdata3[23:8]};
        else if(valid_bytes_gen34[1])
            latched_rxdata3 <= #TP { 8'h0, demux_rxdata[15:0]};
        else
            latched_rxdata3 <= #TP 24'h0;
    end
end

// Build up DWs of Gen3 Data.
// If valid_bytes_gen34[0], then 1 byte of data  received per clock cycle
// If valid_bytes_gen34[1], then 2 bytes of data received per clock cycle
// Otherwise, 1 or more DWs of data received per clock cycle
// If !demux_search_for_tokens, dv = 1, and data = 0, this is equivalent
// to IDL token and is used to flush register stages in token_finder.
wire flush_rxdata3;

assign flush_rxdata3 = !demux_search_for_tokens ;
assign rxdata3_dv       = (flush_rxdata3)        ?  1'b1                              :
                          (valid_bytes_gen34[0]) ? (demux_rxdata_dv && (sym_cnt3 == 2'b11)) :
                          (valid_bytes_gen34[1]) ? (demux_rxdata_dv && (sym_cnt3 == 2'b10)) :
                                                    demux_rxdata_dv;

assign rxdata3[31:0]    = (flush_rxdata3)        ?  32'h0000                                   :
                          (valid_bytes_gen34[0]) ? {demux_rxdata[7:0],  latched_rxdata3[23:0]} :
                          (valid_bytes_gen34[1]) ? {demux_rxdata[15:0], latched_rxdata3[15:0]} :
                                                    demux_rxdata[31:0];
assign rxdata3[DW-1:32] = (flush_rxdata3) ?  {(DW-32){1'b0}} : demux_rxdata[DW-1:32];

wire rxdata3_dv_gen34, rxdata3_dv_gen34_tf3, rxdata3_dv_gen34_tf4;
assign rxdata3_dv_gen34     = (active_decoder == Gen12_pkt_finder) ? 1'b0 : rxdata3_dv;
assign rxdata3_dv_gen34_tf3 = (active_decoder == Gen34_token_finder3) ? rxdata3_dv_gen34 : 1'b0;
assign rxdata3_dv_gen34_tf4 = (active_decoder == Gen34_token_finder4) ? rxdata3_dv_gen34 : 1'b0;
// expect_eds is gated to avoid detecting EDS errors while the decoder is not active.
// Detecting EDS errors while the decoder is not active might contamninate the status and 
// produce a false framing error once the decoder get activated.
wire expect_eds_tf3, expect_eds_tf4;
assign expect_eds_tf3 = (active_decoder == Gen34_token_finder3) ? demux_expect_eds : 1'b0;
assign expect_eds_tf4 = (active_decoder == Gen34_token_finder4) ? demux_expect_eds : 1'b0;

wire     [NW-1:0]       dllp_start_x4;
wire     [NW-1:0]       tlp_start_x4;
wire     [NW-1:0]       pkt_end_x4;
wire     [NW-1:0]       pkt_edb_x4;
wire     [DW-1:0]       pkt_data_x4;
wire                    pkt_dv_x4;
wire     [NW-1:0]       pkt_err_x4;
wire     [NW*5-1:0]     pkt_err_ptr_x4;
wire     [1:0]          rcvd_idle_x4;

// general token finder4
// token finder used if cxl_mode_enable=0 or cxl_mode_enable=1 for 512-bit cores
rplh_token_finder4
 u_rplh_token_finder4 (
// ---- inputs ---------------
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .cxl_mode_enable            (1'b0),
    .smlh_link_mode             (demux_link_mode),
    .search_for_tokens          (demux_search_for_tokens),
    .accept_eds_cycle           (demux_accept_eds_cycle),
    .expect_eds                 (expect_eds_tf4),
    .rxdata3_dv                 (rxdata3_dv_gen34_tf4),
    .rxdata3                    (rxdata3),
// ---- outputs ---------------
    .rplh_rdlh_dllp_start       (dllp_start_x4),
    .rplh_rdlh_tlp_start        (tlp_start_x4),
    .rplh_rdlh_pkt_end          (pkt_end_x4),
    .rplh_rdlh_pkt_edb          (pkt_edb_x4),
    .rplh_rdlh_pkt_data         (pkt_data_x4),
    .rplh_rdlh_pkt_dv           (pkt_dv_x4),
    .rplh_rdlh_pkt_err          (pkt_err_x4),
    .rplh_rdlh_pkt_err_ptr      (pkt_err_ptr_x4),
    .no_pkt_in_progress         (),
    .rplh_rcvd_idle             (rcvd_idle_x4)
);

wire     [NW-1:0]       dllp_start_x3;
wire     [NW-1:0]       tlp_start_x3;
wire     [NW-1:0]       pkt_end_x3;
wire     [NW-1:0]       pkt_edb_x3;
wire     [DW-1:0]       pkt_data_x3;
wire                    pkt_dv_x3;
wire     [NW-1:0]       pkt_err_x3;
wire     [NW*5-1:0]     pkt_err_ptr_x3;
wire     [1:0]          rcvd_idle_x3;

rplh_token_finder3

#(
.NW_R(NW_R)  // Use a Reduced datapath.
) u_rplh_token_finder3 (
// ---- inputs ---------------
    .core_clk            (core_clk),
    .core_rst_n          (core_rst_n),
    .smlh_link_mode      (demux_link_mode),
    .search_for_tokens   (demux_search_for_tokens),
    .accept_eds_cycle    (demux_accept_eds_cycle),
    .expect_eds          (expect_eds_tf3),
    .rxdata3_dv          (rxdata3_dv_gen34_tf3),
    .rxdata3             (rxdata3),
// ---- outputs ---------------
    .rplh_rdlh_dllp_start(dllp_start_x3),
    .rplh_rdlh_tlp_start (tlp_start_x3),
    .rplh_rdlh_pkt_end   (pkt_end_x3),
    .rplh_rdlh_pkt_edb   (pkt_edb_x3),
    .rplh_rdlh_pkt_data  (pkt_data_x3),
    .rplh_rdlh_pkt_dv    (pkt_dv_x3),
    .rplh_rdlh_pkt_err   (pkt_err_x3),
    .rplh_rdlh_pkt_err_ptr (pkt_err_ptr_x3),
    .rplh_rcvd_idle      (rcvd_idle_x3)
);




// ============================================================
// Flit Mode Section
// ============================================================
wire  rxdata_dv_fm;
wire  search_for_tokens_i;
logic cfg_acknack_disable_fm;
logic cdm_ras_des_einj2_enable_fm;
assign rxdata_dv_fm = (active_decoder == FlitM_token_finder6) ? rxdata_dv : 1'b0;
assign search_for_tokens_i = search_for_tokens;
assign cfg_acknack_disable_fm = (active_decoder == FlitM_token_finder6) ?  cfg_acknack_disable : 1'b0;
assign cdm_ras_des_einj2_enable_fm = (active_decoder == FlitM_token_finder6) ?  cdm_ras_des_einj2_enable : 1'b0;
wire     [NW-1:0]        tlp_start_fm;
wire     [NW-1:0]        tlp_idl_fm;
wire     [NW-1:0]        tlp_pfx_fm;
wire     [NW-1:0]        pkt_end_fm;
wire                     tlp_nul_fm;
wire                     tlp_psn_fm;
wire     [DW_W_PAR-1:0]  pkt_data_fm;
wire                     pkt_dv_fm;
wire     [NW-1:0]        pkt_err_fm;
wire     [1:0]           rcvd_idle_fm;
rplh_xplh_fm_retry_t     retry_fm;
wire     [31:0]          dllp_data_fm;
wire                     dllp_valid_fm;
wire                     dllp_opt_fc_up_fm;

assign pkt_err_fm = 0;

assign rplh_flit_pl_dllp_valid = dllp_valid_fm;
assign rplh_flit_pl_dllp_ofc   = dllp_opt_fc_up_fm;
assign rplh_flit_pl_dllp_data  = dllp_data_fm;


rplh_flit_finder
 #(
) u_rplh_flit_finder (
// ---- inputs ---------------
    .core_clk                      (core_clk),
    .core_rst_n                    (core_rst_n),
    .cxl_mode_enable               (cxl_mode_enable),
    .smlh_link_mode                (smlh_link_mode),
    .active_nb                     (active_nb),
    .rxdata_dv                     (rxdata_dv_fm),
    .rxdata                        (rxdata),
    .search_for_tokens             (search_for_tokens_i),
    .smlh_ltssm_state              (smlh_ltssm_state),
    .smlh_block_dl_init            (smlh_block_dl_init),
    .cfg_upstream_port             (cfg_upstream_port),
    .rplh_ptm_sot                  (rplh_ptm_sot),
    .rplh_ptm_request              (rplh_ptm_request),
    .rplh_ptm_response             (rplh_ptm_response),
    .rplh_ptm_duplicate            (rplh_ptm_duplicate),
      .cfg_acknack_disable         (cfg_acknack_disable_fm),
      .cdm_ras_des_einj2_enable    (cdm_ras_des_einj2_enable_fm),
      .cdm_ras_des_einj2_dllp_type (cdm_ras_des_einj2_dllp_type),
    .current_data_rate                (current_data_rate),
    .cdm_plh_flit_err_inj_interface   (cdm_plh_flit_err_inj_interface),
// ---- outputs ---------------
    .rplh_spif_enable              (rplh_protocol_cfg.spif_enable),
    .rplh_flit_pl_stream           (rplh_flit_pl_stream),
    .rplh_flit_pl_nullified        (rplh_flit_pl_nullified),
    .rplh_flit_pl_poisoned         (rplh_flit_pl_poisoned),
    .rplh_flit_pl_valid            (rplh_flit_pl_valid),
    .rplh_flit_pl_data             (rplh_flit_pl_data),
    .rplh_flit_pl_data_chk         (rplh_flit_pl_data_chk),
    .rplh_fm_cxl_rcvd_flit         (rplh_fm_cxl_rcvd_flit),
    .rplh_fmpkt_data               (pkt_data_fm),
    .rplh_fmpkt_data_dv            (pkt_dv_fm),
    .rplh_fmpkt_tlp_pfx            (tlp_pfx_fm),
    .rplh_fmpkt_tlp_soh            (tlp_start_fm),
    .rplh_fmpkt_tlp_end            (pkt_end_fm),
    .rplh_fmpkt_tlp_nul            (tlp_nul_fm),
    .rplh_fmpkt_tlp_psn            (tlp_psn_fm),
    .rplh_fmpkt_tlp_idl            (tlp_idl_fm),
    .rplh_flit_dl_prot_err         (rplh_flit_dl_prot_err),
    .rplh_flit_logging_interface   (rplh_cdm_flit_logging_interface),
    .rplh_flit_rcvd_idle           (rcvd_idle_fm),
    .rplh_xplh_fm_retry            (retry_fm),
    .rplh_rdlh_fm_dllp_data        (dllp_data_fm),
    .rplh_rdlh_fm_dllp_valid       (dllp_valid_fm),
    .rplh_rdlh_fm_dllp_opt_fc_up   (dllp_opt_fc_up_fm)
    ,
    .rplh_cdm_flit_err_inj_status  (rplh_cdm_flit_err_inj_status)
);




// ==================
//   Drive outputs
// ==================

// Output signals passing through the optional frequency step
wire                       fs_rplh_rdlh_pkt_dv;
wire  [NW-1:0]             fs_rplh_rdlh_tlp_start;
wire  [NW-1:0]             fs_rplh_rdlh_dllp_start;
wire  [NW-1:0]             fs_rplh_rdlh_pkt_end;
wire  [NW-1:0]             fs_rplh_rdlh_pkt_edb;
wire  [DW_W_PAR-1:0]       fs_rplh_rdlh_pkt_data;
wire  [NW-1:0]             fs_rplh_rdlh_pkt_err;
wire  [NW-1:0]             fs_rplh_rdlh_nak;
wire  [NW-1:0]             fs_rplh_rdlh_tlp_idl;
wire  [NW-1:0]             fs_rplh_rdlh_tlp_pfx;
wire                       fs_rplh_rdlh_fm_poisoned;
wire                       fs_rplh_rdlh_fm_nullified;
wire  [31:0]               fs_rplh_rdlh_fm_dllp_data;
wire                       fs_rplh_rdlh_fm_dllp_valid;
wire                       fs_rplh_rdlh_fm_dllp_opt_fc_up;
rplh_xplh_fm_retry_t       fs_rplh_xplh_fm_retry;

wire [DW_W_PAR-1:0] pkt_data_w_p;
assign pkt_data_w_p   = {{DATA_PAR_WD{1'b0}},pkt_data};
wire [DW_W_PAR-1:0] pkt_data_3_w_p;
assign pkt_data_3_w_p = {{DATA_PAR_WD{1'b0}},pkt_data_3};

     //normal tokenfinder4
assign dllp_start_3  = (active_decoder == Gen34_token_finder3) ? dllp_start_x3  : dllp_start_x4  ;
assign tlp_start_3   = (active_decoder == Gen34_token_finder3) ? tlp_start_x3   : tlp_start_x4   ;
assign pkt_end_3     = (active_decoder == Gen34_token_finder3) ? pkt_end_x3     : pkt_end_x4     ;
assign pkt_edb_3     = (active_decoder == Gen34_token_finder3) ? pkt_edb_x3     : pkt_edb_x4     ;
assign pkt_data_3    = (active_decoder == Gen34_token_finder3) ? pkt_data_x3    : pkt_data_x4    ;
assign pkt_dv_3      = (active_decoder == Gen34_token_finder3) ? pkt_dv_x3      : pkt_dv_x4      ;
assign pkt_err_3     = (active_decoder == Gen34_token_finder3) ? pkt_err_x3     : pkt_err_x4     ;
assign pkt_err_ptr_3 = (active_decoder == Gen34_token_finder3) ? pkt_err_ptr_x3 : pkt_err_ptr_x4 ;
assign rcvd_idle_3   = (active_decoder == Gen34_token_finder3) ? rcvd_idle_x3   : rcvd_idle_x4   ;
assign  fs_rplh_rdlh_dllp_start  = 
    (active_decoder == FlitM_token_finder6)? {NW{1'b0}}                  :
                                (active_decoder == Gen12_pkt_finder)   ? dllp_start   : dllp_start_3 ;

assign  fs_rplh_rdlh_tlp_start   = 
    (active_decoder == FlitM_token_finder6)? tlp_start_fm                :
                                (active_decoder == Gen12_pkt_finder)   ? tlp_start    : tlp_start_3  ;
localparam NW_NFM = (NW>16)? 16 : NW; // Number of 32-bit dwords handled by the datapath each clock in Non Flit Mode
assign fs_rplh_rdlh_tlp_idl           = (active_decoder == FlitM_token_finder6)? tlp_idl_fm   : {{NW-NW_NFM{1'b1}}, {NW_NFM{1'b0}}};
assign fs_rplh_rdlh_tlp_pfx           = (active_decoder == FlitM_token_finder6)? tlp_pfx_fm   : {NW{1'b0}}   ;
assign fs_rplh_rdlh_fm_poisoned       = (active_decoder == FlitM_token_finder6)? tlp_psn_fm   : {NW{1'b0}}   ;
assign fs_rplh_rdlh_fm_nullified      = (active_decoder == FlitM_token_finder6)? tlp_nul_fm   : {NW{1'b0}}   ;
assign fs_rplh_rdlh_fm_dllp_data      = dllp_data_fm;
assign fs_rplh_rdlh_fm_dllp_valid     = dllp_valid_fm;
assign fs_rplh_rdlh_fm_dllp_opt_fc_up = dllp_opt_fc_up_fm;
assign fs_rplh_xplh_fm_retry          = retry_fm;

assign fs_rplh_rdlh_pkt_end  =
    (active_decoder == FlitM_token_finder6)? pkt_end_fm                  :
                                (active_decoder == Gen12_pkt_finder)   ? pkt_end      : pkt_end_3    ;

assign fs_rplh_rdlh_nak      =
    (active_decoder == FlitM_token_finder6)? {NW{1'b0}}                  :
                                (active_decoder == Gen12_pkt_finder)   ? nak          : {NW{1'b0}}   ;

assign fs_rplh_rdlh_pkt_edb  =
    (active_decoder == FlitM_token_finder6)? {NW{1'b0}}                  :
                                (active_decoder == Gen12_pkt_finder)   ? pkt_edb      : pkt_edb_3    ;

assign fs_rplh_rdlh_pkt_data =
    (active_decoder == FlitM_token_finder6)? pkt_data_fm                 :
                                (active_decoder == Gen12_pkt_finder)   ? pkt_data_w_p :pkt_data_3_w_p;

assign fs_rplh_rdlh_pkt_dv   =
    (active_decoder == FlitM_token_finder6)? pkt_dv_fm                   :
                                (active_decoder == Gen12_pkt_finder)   ? pkt_dv       : pkt_dv_3     ;

assign fs_rplh_rdlh_pkt_err  =
    (active_decoder == FlitM_token_finder6)? pkt_err_fm                  :
                                (active_decoder == Gen12_pkt_finder)   ? pkt_err      : pkt_err_3    ;

assign rplh_rmlh_pkt_err     = |fs_rplh_rdlh_pkt_err;

assign rplh_rmlh_pkt_err_ptr =
    (active_decoder == FlitM_token_finder6)? {NW*5{1'b0}}                :
                               (active_decoder == Gen12_pkt_finder)   ? {NW*5{1'b0}} : first_pkt_error_ptr(pkt_err_3, pkt_err_ptr_3);

assign  rplh_rcvd_idle        = 
    (active_decoder == FlitM_token_finder6)? rcvd_idle_fm              :
                                (active_decoder == Gen12_pkt_finder)   ? rmlh_rplh_rcvd_idle_gen12 : demux_rcvd_idle;


assign rplh_rdlh_pkt_dv            = fs_rplh_rdlh_pkt_dv;
assign rplh_rdlh_tlp_start         = fs_rplh_rdlh_tlp_start;
assign rplh_rdlh_dllp_start        = fs_rplh_rdlh_dllp_start;
assign rplh_rdlh_pkt_end           = fs_rplh_rdlh_pkt_end;
assign rplh_rdlh_pkt_edb           = fs_rplh_rdlh_pkt_edb;
assign rplh_rdlh_pkt_data          = fs_rplh_rdlh_pkt_data;
assign rplh_rdlh_pkt_err           = fs_rplh_rdlh_pkt_err;
assign rplh_rdlh_nak               = fs_rplh_rdlh_nak;
assign rplh_rdlh_tlp_idl           = fs_rplh_rdlh_tlp_idl;
assign rplh_rdlh_tlp_pfx           = fs_rplh_rdlh_tlp_pfx;
assign rplh_rdlh_fm_poisoned       = fs_rplh_rdlh_fm_poisoned;
assign rplh_rdlh_fm_nullified      = fs_rplh_rdlh_fm_nullified;
assign rplh_rdlh_fm_dllp_data      = fs_rplh_rdlh_fm_dllp_data;
assign rplh_rdlh_fm_dllp_valid     = fs_rplh_rdlh_fm_dllp_valid;
assign rplh_rdlh_fm_dllp_opt_fc_up = fs_rplh_rdlh_fm_dllp_opt_fc_up;
assign rplh_xplh_fm_retry          = fs_rplh_xplh_fm_retry;


// ==================
//   Functions
// ==================
function automatic [4:0] first_pkt_error_ptr;
    input   [NW-1:0]    pkt_err;
    input   [NW*5-1:0]  pkt_err_ptr;
begin
    first_pkt_error_ptr = (pkt_err[0]) ? pkt_err_ptr[5*0 +: 5] :
                          (pkt_err[1]) ? pkt_err_ptr[5*1 +: 5] :
                          (pkt_err[2]) ? pkt_err_ptr[5*2 +: 5] :
                          (pkt_err[3]) ? pkt_err_ptr[5*3 +: 5] :
                          (pkt_err[4]) ? pkt_err_ptr[5*4 +: 5] :
                          (pkt_err[5]) ? pkt_err_ptr[5*5 +: 5] :
                          (pkt_err[6]) ? pkt_err_ptr[5*6 +: 5] :
                          (pkt_err[7]) ? pkt_err_ptr[5*7 +: 5] :
                          (pkt_err[ 8]) ? pkt_err_ptr[5* 8 +: 5] :
                          (pkt_err[ 9]) ? pkt_err_ptr[5* 9 +: 5] :
                          (pkt_err[10]) ? pkt_err_ptr[5*10 +: 5] :
                          (pkt_err[11]) ? pkt_err_ptr[5*11 +: 5] :
                          (pkt_err[12]) ? pkt_err_ptr[5*12 +: 5] :
                          (pkt_err[13]) ? pkt_err_ptr[5*13 +: 5] :
                          (pkt_err[14]) ? pkt_err_ptr[5*14 +: 5] :
                          (pkt_err[15]) ? pkt_err_ptr[5*15 +: 5] :
                                                                   5'b00000;

end
endfunction



endmodule
