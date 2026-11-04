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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh.sv#13 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer Handler
// --- 1. Remove the LCRC and sequence number
// --- 2. Generate requests for ACK/NACK/DupACK transmission
// --- 3. Data link layer control state machine
// --- 4. Extraction of DLLP (received ACK/NACK, FC and PM DLLP, etc
// --- 5. Extraction of TLP
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/cx_pl_pkg.svh"
 
module rdlh
import cx_pl_pkg::l0p_dllp_struct;
import spif_pkg::protocol_cfg_t;
(
    b_rdlh_spif,
    rdlh_protocol_cfg,
    core_clk,
    core_rst_n,
    smlh_link_mode,
    smlh_link_up,
    cfg_dll_lnk_en,
    rtlh_fci_done,
    rtlh_fci1_fci2,
    dl_feature_en,
    cfg_remote_feature_ack,
    init_fc1_rcvd,
    rplh_rdlh_dllp_start,
    rplh_rdlh_tlp_start,
    rplh_rdlh_pkt_end,
    rplh_rdlh_pkt_edb,
    rplh_rdlh_pkt_data,
    rplh_rdlh_pkt_dv,
    rplh_rdlh_pkt_err,
    rplh_rdlh_nak,
    xdlh_rdlh_last_xmt_seqnum,
    nak_scheduled,
    ras_prot_r_disable,
    ras_err_inj_en_array,
    ras_err_inj_mask,
    cdm_ras_des_einj0_enable,
    cdm_ras_des_einj0_crc_type,
    cdm_ras_des_einj0_count,
    rplh_rdlh_tlp_idl,
    rplh_rdlh_tlp_pfx,
    rplh_rdlh_fm_nullified,
    rplh_rdlh_fm_poisoned,
    smlh_flit_mode_enable,
    rplh_rdlh_fm_dllp_data,
    rplh_rdlh_fm_dllp_valid,
    rplh_rdlh_fm_dllp_opt_fc_up,

    // ------------- outputs --------------------
    rdlh_ptm_sot,
    rdlh_ptm_multi_cycle,
    rdlh_ptm_request,
    rdlh_ptm_response,
    rdlh_duplicate_tlp,
    rdlh_retrain_req,
    rdlh_xdlh_rcvd_nack,
    rdlh_xdlh_rcvd_ack,
    rdlh_xdlh_rcvd_acknack_seqnum,
    rdlh_rtlh_rcvd_dllp,
    rdlh_rtlh_rcvd_dllp_fm_opt_fc_up,
    ras_stat_rdlh_corr,
    ras_stat_rdlh_uncorr,
    rdlh_rtlh_dllp_content,
    rdlh_rtlh_tlp_soh,
    rdlh_rtlh_tlp_idl,
    rdlh_rtlh_tlp_pfx,
    rdlh_rtlh_fm_nullified,
    rdlh_rtlh_fm_poisoned,
    rdlh_rtlh_tlp_dv,
    rdlh_rtlh_tlp_eot,
    rdlh_rtlh_tlp_data,
    rdlh_rtlh_tlp_abort,
    rdlh_xdlh_req2send_ack,
    rdlh_xdlh_req2send_ack_due2dup,
    rdlh_xdlh_req2send_nack,
    rdlh_xdlh_req_acknack_seqnum,
`ifndef SYNTHESIS
`endif // SYNTHESIS
    rdlh_link_up,
    rdlh_link_down,
    rdlh_rtlh_link_state,
    rdlh_bad_dllp_err,
    send_feature_dllp,
    rdlh_rcvd_dl_feature,
    rcvd_dl_feature_content, 
    xdlh_rdlh_feature_ack,
    ras_err_inj_done,
    rdlh_bad_tlp_err,
    rdlh_prot_err,
    rdlh_rcvd_as_req_l1,
    rdlh_rcvd_pm_enter_l1,
    rdlh_rcvd_pm_enter_l23,
    rdlh_rcvd_pm_req_ack
    ,
    rdlh_bad_tlp_err_pertlp,
    rdlh_lcrc_tlp_err_pertlp,
    rdlh_nulified_tlp_err_pertlp,
    rdlh_duplicate_tlp_err_pertlp,
    rdlh_bad_dllp_err_perdllp,
    rdlh_rcvd_nack_perdllp,
    rdlh_rcvd_ack_perdllp,
    rdlh_vc0_initfc1_status,
    rdlh_vc0_initfc2_status,
    rdlh_curnt_rx_ack_seqnum
    ,
    rdlh_einj0_lcrc_evt
    ,
    rdlh_xdlh_fm_dllp_valid,
    rdlh_xdlh_l0p_dllp
);
parameter  INST              = 0;                                    // The uniquifying parameter for each port logic instance.
parameter  NW                = `CX_NW;                               // Number of dwords handled by the datapath each clock.
parameter  NB                = `CX_NB;                               // Number of bytes per cycle per lane
parameter  DW                = (32*NW);                              // Width of datapath in bits.
parameter  TP                = `TP;                                  // Clock to Q delay (simulator insurance)
parameter  DATA_PAR_WD       = `TRGT_DATA_PROT_WD;
parameter  DW_W_PAR          = DW + DATA_PAR_WD;
parameter  RX_NDLLP          = `CX_RX_NDLLP;                         // Max number of DLLPs received per cycle
localparam RX_TLP            = `CX_RX_TLP;                           // Number of TLPs that can be processed in this block in a single cycle
localparam RX_TLP_NFM        = `CX_RX_TLP_NFM;                       // Number of TLPs that can be processed in this block in a single cycle in NFM
parameter RAS_RDLH_COUNTERS  = `CX_RAS_RDLH_COUNTERS ;
parameter ERROR_INJ_EN_WD    = `CX_RAS_ERROR_INJ_EN_WD;
parameter ERROR_INJ_MASK_WD  = `CX_RAS_ERROR_INJ_MASK_WD;

//------------------------------------------------------------------------------
// Inputs
//------------------------------------------------------------------------------
spif_if.rplh_slave_mp   b_rdlh_spif;                            // RDLH SPIF interface
input   protocol_cfg_t  rdlh_protocol_cfg;                      // Protocol Configuration for DLH Layer

input                   core_clk;                               // core clock
input                   core_rst_n;                             // core reset
    // from XPLH
input   [5:0]           smlh_link_mode;                         // MAC layer indicated link mode (x1,x2,x4,x8,x16)
input                   smlh_link_up;                           // when asserted XPLH link up.
input                   cfg_dll_lnk_en;                         // DLL link enable to allow link up
    // from RTLH
input                   rtlh_fci_done;                          // RTLH flow control init done.
input                   rtlh_fci1_fci2;                         // RTLH flow control init 1 and init 2.
input                   dl_feature_en;                          // Indicates Data Link Features supported
input                   cfg_remote_feature_ack;                 // Indicates remote Data Link Features handshake completed
input                   init_fc1_rcvd;                          // Any INITFC1 has been received
    // from RPLH
input   [NW-1:0]        rplh_rdlh_dllp_start;                   // 1-4  for 4dword, indicates which DW is start of DLP
input   [NW-1:0]        rplh_rdlh_tlp_start;                    // 1-4  for 4dword, indicates which DW is start of TLP
input   [NW-1:0]        rplh_rdlh_pkt_end;                      // 1-4  for 4dword, indicates which DW is pkt good end
input   [NW-1:0]        rplh_rdlh_pkt_edb;                      // 1-4  for 4dword, indicates which DW is pkt bad end
input   [DW_W_PAR-1:0]  rplh_rdlh_pkt_data;                     // packet data bus.
input                   rplh_rdlh_pkt_dv;                       // when asserted, packet data is valid.
input   [NW-1:0]        rplh_rdlh_pkt_err;                       // when asserted, framing error or phy_error
input   [NW-1:0]        rplh_rdlh_nak;                          // NAK indication
    // from XDLH
input   [11:0]          xdlh_rdlh_last_xmt_seqnum;              // the last transmitted highest sequence number of TLP's DLLP. Receiver needs this signal to identify out of order TLP
input                   nak_scheduled;                          // dllp generation block requests nak is scheduled to be transmitted
input   [6:0]           ras_prot_r_disable;
input  [ERROR_INJ_EN_WD  -1:0]  ras_err_inj_en_array;
input  [ERROR_INJ_MASK_WD-1:0]  ras_err_inj_mask;
input                   cdm_ras_des_einj0_enable;               // Error injection 0 enable
input   [3:0]           cdm_ras_des_einj0_crc_type;             // Error injection 0 CRC type selector
input   [7:0]           cdm_ras_des_einj0_count;                // Error injection 0 count
input                   smlh_flit_mode_enable;                  // Flit Mode Enabled
input   [NW-1:0]        rplh_rdlh_tlp_idl;
input   [NW-1:0]        rplh_rdlh_tlp_pfx;
input                   rplh_rdlh_fm_nullified;                 // The last TLP ending was Nullified by the Flit Marker
input                   rplh_rdlh_fm_poisoned;                  // The last TLP ending was Poisoned by the Flit Marker
input   [31:0]          rplh_rdlh_fm_dllp_data;                 // DLLP data extracted from DL bytes
input                   rplh_rdlh_fm_dllp_valid;                // Valid DLLP data
input                   rplh_rdlh_fm_dllp_opt_fc_up;            // DLLP is an Optimized FC update

//------------------------------------------------------------------------------
// Outputs
//------------------------------------------------------------------------------

output                  rdlh_ptm_sot;
output                  rdlh_ptm_multi_cycle;
output                  rdlh_ptm_request;
output                  rdlh_ptm_response;
output                  rdlh_duplicate_tlp;
output                  rdlh_retrain_req;                       // RDLH Retrain Request

    // to XDLH
output                  rdlh_xdlh_rcvd_nack;                    // RDLH pulse signal to indicate that there was a NACK PKT received, and its nack sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
output                  rdlh_xdlh_rcvd_ack;                     // RDLH pulse signal to indicate that there was a ACK PKT received, and its ACK sequence number drove to RDLH_RCVD_ACKNACK_SEQ_NUM
output  [11:0]          rdlh_xdlh_rcvd_acknack_seqnum;          // 12 bits indicated the sequence number of received ACK/NACK DLLP Packet
    // to RTLH
output  [RX_NDLLP-1:0]     rdlh_rtlh_rcvd_dllp;                 // When asserted, it indicates it is DLLP1 packet (Each words could carry two DLLP packets)
output                  rdlh_rtlh_rcvd_dllp_fm_opt_fc_up;       // When asserted, it indicates that we have received a FM Optimized FC update dllp packet

output  [32*RX_NDLLP-1:0]  rdlh_rtlh_dllp_content;              // The received DLLP packet
output                  rdlh_rtlh_tlp_dv;                       // TLP packet data valid
output  [NW-1:0]        rdlh_rtlh_tlp_abort;                    // TLP packet abort due to DLLP layer error detected
output  [NW-1:0]        rdlh_rtlh_tlp_soh;
output  [NW-1:0]        rdlh_rtlh_tlp_idl;
output  [NW-1:0]        rdlh_rtlh_tlp_pfx;
output                  rdlh_rtlh_fm_nullified;                 // The last TLP ending was Nullified by the Flit Marker
output                  rdlh_rtlh_fm_poisoned;                  // The last TLP ending was Poisoned by the Flit Marker 
output  [NW-1:0]        rdlh_rtlh_tlp_eot;                      // When asserted, it indicates the end of a good TLP pkt
output  [DW_W_PAR-1:0]  rdlh_rtlh_tlp_data;                     // Current TLP header and data
    // to CDM
output                  rdlh_rcvd_dl_feature;                   // Feature DLLP Received
output [31:0]           rcvd_dl_feature_content;                // Feature DLLP content  
    // to XDLH
output                  send_feature_dllp;                      // Transmit Feature DLLP
input                   xdlh_rdlh_feature_ack;                  // DL Feature DLLP has been sent in Flit
    // to XDLH
output                  rdlh_xdlh_req2send_ack;                 // RDLH received a good packet and has been asked to send an ACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
output                  rdlh_xdlh_req2send_ack_due2dup;         // RDLH received a packet that is a duplicated PKT . RDLH_REQ2SEND_ACK signal will be asserted while RDLH_RCVD_DUP is asserted.
output                  rdlh_xdlh_req2send_nack;                // RDLH received a good packet and has been asked to send an NACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
output  [11:0]          rdlh_xdlh_req_acknack_seqnum;           // RDLH received a packet with this sequence number
`ifndef SYNTHESIS
`endif // SYNTHESIS
output                  rdlh_link_up;                           // RDLH link is up.
output                  rdlh_link_down;                         // RDLH link is down.
    // to RTLH
output  [1:0]           rdlh_rtlh_link_state;                   // RDLH link up FSM current state.
output                  rdlh_prot_err;                          // protocol err of DLLP layer
output                  rdlh_bad_dllp_err;                      // bad dllp error detected in DLLP layer
output                  ras_err_inj_done;                       // Error injection was performed
output                  rdlh_bad_tlp_err;                       // Bad TLP error detected in DLLP layer
output                  rdlh_rcvd_as_req_l1;                    // Received PM DLLP (as request L1)
output                  rdlh_rcvd_pm_enter_l1;                  // Received PM DLLP (PM enter L1)
output                  rdlh_rcvd_pm_enter_l23;                 // Received PM DLLP (PM enter L23)
output                  rdlh_rcvd_pm_req_ack;                   // Received PM DLLP (pm request ack)
    // to Cdm
output  [RX_TLP-1:0]    rdlh_bad_tlp_err_pertlp;        // Puls : Rx Bad TLP Event per TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]    rdlh_lcrc_tlp_err_pertlp;       // Puls : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]    rdlh_nulified_tlp_err_pertlp;   // Puls : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]    rdlh_duplicate_tlp_err_pertlp;  // Puls : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
output  [RX_NDLLP-1:0]  rdlh_bad_dllp_err_perdllp;      // Puls : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
output  [RX_NDLLP-1:0]  rdlh_rcvd_nack_perdllp;         // Puls : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
output  [RX_NDLLP-1:0]  rdlh_rcvd_ack_perdllp;          // Puls : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
output                  rdlh_vc0_initfc1_status;        // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
output                  rdlh_vc0_initfc2_status;        // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug 
output  [11:0]          rdlh_curnt_rx_ack_seqnum;       // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
output  [2:0]           rdlh_einj0_lcrc_evt;                    // Error injection 0 event flag
output l0p_dllp_struct  rdlh_xdlh_l0p_dllp;                     // Received L0P DLLP Structure
output                  rdlh_xdlh_fm_dllp_valid;                // Valid DLLP data

output  [RAS_RDLH_COUNTERS-1:0]    ras_stat_rdlh_corr;                          //error indications for RAS statistic counters
output  [RAS_RDLH_COUNTERS-1:0]    ras_stat_rdlh_uncorr;                          //error indications for RAS statistic counters

// ============================================================
// Quasi-static Signals
// ============================================================
typedef struct packed {
    logic flit_mode_enable;
}
rdlh_quasi_static_s;
rdlh_quasi_static_s qs_in, qs;

assign qs_in.flit_mode_enable = 1'b0 |smlh_flit_mode_enable ;

delay_n
 
  #( .N (1), .WD ($bits(rdlh_quasi_static_s)) )
  u_rdlh_qs_pipeline (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (qs_in),
  .dout   (qs)
);

// -----------------------------------------------------------------------------
// Internal Wires
// -----------------------------------------------------------------------------


wire [6:0] ras_prot_r_disable;
wire ras_rdlh_prot_disable;

assign ras_rdlh_prot_disable = ras_prot_r_disable[4] || ras_prot_r_disable[0];

wire  [RAS_RDLH_COUNTERS-1:0]    ras_stat_rdlh_corr;                          //error indications for RAS statistic counters
wire  [RAS_RDLH_COUNTERS-1:0]    ras_stat_rdlh_uncorr;                          //error indications for RAS statistic counters


wire                    rdlh_ptm_sot;
wire                    rdlh_ptm_multi_cycle;
wire                    rdlh_ptm_request;
wire                    rdlh_ptm_response;
wire                    rdlh_duplicate_tlp;

wire                    rdlh_link_up;
wire                    rdlh_link_down;
wire                    tlp_crc_match;

wire    [31:0]          tlp_crc;
wire    [NW-1:0]        tlp_aligned_sot, tlp_aligned_eot, tlp_aligned_edb;
wire                    tlp_aligned_dv;
wire    [11:0]          tlp_seqnum;
wire    [11:0]          tlp_seqnum_early;
wire                    rcvd_reserved_dllp_type;
wire                    rcvd_dllp_outseq;

wire rdlh_prot_err;
assign rdlh_prot_err      = rcvd_dllp_outseq;

wire    [1:0]           rdlh_rtlh_link_state;                   // RDLH link up FSM current state.

wire                    rdlh_rcvd_dl_feature;
wire [31:0]             rcvd_dl_feature_content;
wire [32*RX_NDLLP-1:0]  rdlh_rtlh_dllp_content;
wire                    dl_feature_abort;

localparam NW_NFM           = (NW>16)? 16 : NW;
localparam DW_NFM           = 32*NW_NFM;
localparam DATA_PAR_WD_NFM  = `NFM_TRGT_DATA_PROT_WD;
localparam DW_W_PAR_NFM     = DW_NFM + DATA_PAR_WD_NFM;

wire                      nfm_rdlh_rtlh_tlp_dv;       
wire [RX_TLP_NFM-1:0]     nfm_rdlh_rtlh_tlp_abort;    
wire [NW_NFM-1:0]         nfm_rdlh_rtlh_tlp_sot;      
wire [NW_NFM-1:0]         nfm_rdlh_rtlh_tlp_eot;      
wire [DW_W_PAR_NFM-1:0]   nfm_rdlh_rtlh_tlp_data;
wire [RX_TLP_NFM-1:0]     nfm_rdlh_nulified_tlp_err_pertlp;

// SPIF and RPLH-2-RPLH Mux Signals
wire   [NW-1:0]        spif_rdlh_rx_nak            ;
wire   [NW-1:0]        spif_rdlh_dllp_start        ;
wire   [NW-1:0]        spif_rdlh_tlp_start         ;
wire   [NW-1:0]        spif_rdlh_pkt_end           ;
wire   [NW-1:0]        spif_rdlh_pkt_edb           ;
wire   [DW_W_PAR-1:0]  spif_rdlh_pkt_data          ;
wire                   spif_rdlh_pkt_dv            ;
wire   [NW-1:0]        spif_rdlh_pkt_err           ;
wire   [NW-1:0]        spif_rdlh_tlp_idl           ;
wire   [NW-1:0]        spif_rdlh_tlp_pfx           ;
wire                   spif_rdlh_fm_nullified      ;
wire                   spif_rdlh_fm_poisoned       ;
wire   [31:0]          spif_rdlh_fm_dllp_data      ;
wire                   spif_rdlh_fm_dllp_valid     ;
wire                   spif_rdlh_fm_dllp_opt_fc_up ;

assign rdlh_xdlh_fm_dllp_valid= rplh_rdlh_fm_dllp_valid;              

// RDLH requests link retrain when framing error is detected by the Flit Deframing module
assign rdlh_retrain_req            = rdlh_protocol_cfg.spif_enable && (|spif_rdlh_pkt_err);

// RDLH Flit Deframing Module Instantiation
rdlh_fm_flit_deframe
 u_rdlh_fm_flit_deframe (
    .b_rdlh_spif                  ( b_rdlh_spif                 ),
    .core_clk                     ( core_clk                    ),
    .core_rst_n                   ( core_rst_n                  ),
    .rdlh_protocol_cfg            ( rdlh_protocol_cfg           ),
    .rplh_rdlh_nak                ( rplh_rdlh_nak               ),
    .rplh_rdlh_dllp_start         ( rplh_rdlh_dllp_start        ),
    .rplh_rdlh_tlp_start          ( rplh_rdlh_tlp_start         ),
    .rplh_rdlh_pkt_end            ( rplh_rdlh_pkt_end           ),
    .rplh_rdlh_pkt_edb            ( rplh_rdlh_pkt_edb           ),
    .rplh_rdlh_pkt_data           ( rplh_rdlh_pkt_data[DW-1:0]  ),
    .rplh_rdlh_pkt_data_chk       ( rplh_rdlh_pkt_data[DW+:DATA_PAR_WD] ),
    .rplh_rdlh_pkt_dv             ( rplh_rdlh_pkt_dv            ),
    .rplh_rdlh_pkt_err            ( rplh_rdlh_pkt_err           ),
    .rplh_rdlh_tlp_idl            ( rplh_rdlh_tlp_idl           ),
    .rplh_rdlh_tlp_pfx            ( rplh_rdlh_tlp_pfx           ),
    .rplh_rdlh_fm_nullified       ( rplh_rdlh_fm_nullified      ),
    .rplh_rdlh_fm_poisoned        ( rplh_rdlh_fm_poisoned       ),
    .rplh_rdlh_fm_dllp_valid      ( rplh_rdlh_fm_dllp_valid     ),
    .rplh_rdlh_fm_dllp_opt_fc_up  ( rplh_rdlh_fm_dllp_opt_fc_up ),
    .rplh_rdlh_fm_dllp_data       ( rplh_rdlh_fm_dllp_data      ),
    .spif_rdlh_rx_nak             ( spif_rdlh_rx_nak            ),
    .spif_rdlh_dlp_start          ( spif_rdlh_dllp_start        ),
    .spif_rdlh_tlp_start          ( spif_rdlh_tlp_start         ),
    .spif_rdlh_pkt_end            ( spif_rdlh_pkt_end           ),
    .spif_rdlh_pkt_edb            ( spif_rdlh_pkt_edb           ),
    .spif_rdlh_pkt_dv             ( spif_rdlh_pkt_dv            ),
    .spif_rdlh_pkt_data           ( spif_rdlh_pkt_data[DW-1:0]  ),
    .spif_rdlh_pkt_data_chk       ( spif_rdlh_pkt_data[DW+:DATA_PAR_WD] ),
    .spif_rdlh_pkt_err            ( spif_rdlh_pkt_err           )
    ,
    .spif_rdlh_tlp_idl            ( spif_rdlh_tlp_idl           ),
    .spif_rdlh_tlp_pfx            ( spif_rdlh_tlp_pfx           ),
    .spif_rdlh_tlp_nul            ( spif_rdlh_fm_nullified      ),
    .spif_rdlh_tlp_psn            ( spif_rdlh_fm_poisoned       ),
    .spif_rdlh_fm_dllp_valid      ( spif_rdlh_fm_dllp_valid     ),
    .spif_rdlh_fm_dllp_ofc        ( spif_rdlh_fm_dllp_opt_fc_up ),
    .spif_rdlh_fm_dllp_data       ( spif_rdlh_fm_dllp_data      )
);


rdlh_tlp_ms_adapt
 u_rdlh_tlp_ms_adapt(
 .core_clk                         (core_clk                        ),
 .core_rst_n                       (core_rst_n                      ),
 .rplh_rdlh_pkt_data               (spif_rdlh_pkt_data              ), 
 .rplh_rdlh_pkt_dv                 (spif_rdlh_pkt_dv                ), 
 .rplh_rdlh_tlp_start              (spif_rdlh_tlp_start             ),   
 .rplh_rdlh_pkt_end                (spif_rdlh_pkt_end               ),   
 .rplh_rdlh_tlp_pfx                (spif_rdlh_tlp_pfx               ),
 .rplh_rdlh_fm_nullified           (spif_rdlh_fm_nullified          ),
 .rplh_rdlh_fm_poisoned            (spif_rdlh_fm_poisoned           ),
 .rplh_rdlh_tlp_idl                (spif_rdlh_tlp_idl               ),   
 .nfm_rdlh_rtlh_tlp_data           (nfm_rdlh_rtlh_tlp_data          ),     
 .nfm_rdlh_rtlh_tlp_dv             (nfm_rdlh_rtlh_tlp_dv            ),     
 .nfm_rdlh_rtlh_tlp_sot            (nfm_rdlh_rtlh_tlp_sot           ),     
 .nfm_rdlh_rtlh_tlp_eot            (nfm_rdlh_rtlh_tlp_eot           ),     
 .nfm_rdlh_rtlh_tlp_abort          (nfm_rdlh_rtlh_tlp_abort         ),
 .nfm_rdlh_nulified_tlp_err_pertlp (nfm_rdlh_nulified_tlp_err_pertlp),
 .smlh_flit_mode_enable            (qs.flit_mode_enable             ),       
 .rdlh_rtlh_tlp_data               (rdlh_rtlh_tlp_data              ),   
 .rdlh_rtlh_tlp_dv                 (rdlh_rtlh_tlp_dv                ),
 .rdlh_rtlh_tlp_soh                (rdlh_rtlh_tlp_soh               ),   
 .rdlh_rtlh_tlp_eot                (rdlh_rtlh_tlp_eot               ),     
 .rdlh_rtlh_tlp_abort              (rdlh_rtlh_tlp_abort             )  
 ,
 .rdlh_rtlh_fm_nullified           (rdlh_rtlh_fm_nullified          ),
 .rdlh_rtlh_fm_poisoned            (rdlh_rtlh_fm_poisoned           ),
 .rdlh_rtlh_tlp_pfx                (rdlh_rtlh_tlp_pfx               ),   
 .rdlh_rtlh_tlp_idl                (rdlh_rtlh_tlp_idl               )
 ,
 .rdlh_nulified_tlp_err_pertlp     (rdlh_nulified_tlp_err_pertlp    )
);

// drive link up state of dllp to the upper layer

// link control block does a small taks of monitoring the phy layer and generated the link control state machine for DL layer.
rdlh_link_cntrl

#(INST) u_rdlh_link_cntrl(
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .smlh_link_up           (smlh_link_up),
    .cfg_dll_lnk_en         (cfg_dll_lnk_en),
    .rtlh_fci_done          (rtlh_fci_done),
    .rtlh_fci1_fci2         (rtlh_fci1_fci2),
    .dl_feature_en          (dl_feature_en),
    .cfg_remote_feature_ack (cfg_remote_feature_ack),
    .init_fc1_rcvd          (init_fc1_rcvd),
    .dl_feature_abort       (dl_feature_abort),

// ---- outputs ---------------
    .rdlh_link_up           (rdlh_link_up),
    .rdlh_link_down         (rdlh_link_down),
    .rdlh_dlcntrl_state     (rdlh_rtlh_link_state)
    ,
    .send_feature_dllp      (send_feature_dllp)
    ,
    .xdlh_rdlh_feature_ack  (xdlh_rdlh_feature_ack)
    ,
    .rdlh_vc0_initfc1_status (rdlh_vc0_initfc1_status),
    .rdlh_vc0_initfc2_status (rdlh_vc0_initfc2_status)
);

// -----------------------------------------------------------------------------
// tlp extract block does the alignment of tlp data that comes from PHY layer
// at PHY layer, the pkt is sent to DL layer at its arrival order. It was simply
// pasted into a bus with start and end indication of a packet.
// therefore, we need to align the data from PHY layer and to extract the tlp out of
// mixed DLPs.
// this block does two thing:
// 1. identify TLPs and align it to a tlp bus. The possible two location of
//    TLP starts at 1st dword or the last dword since there is minimum of 8bytes cut from a pkt received from PHY to a TLP extract.
// 2. generated the start and end of TLP location indications. Due to the back2back TLP rcvd, we currently designed 4bits to indicate Start of TLP within bus.
//    The allowable location is 0001, or 1000 (1st or last dword start)
//    The allowable location for the end of a tlp could be 0001,0010, 0100, 1000, (1st, 2nd, 3rd and last dword).

// rdlh_tlp_extract is used only in Non Flit Mode
wire nfm_rplh_rdlh_pkt_dv;
assign nfm_rplh_rdlh_pkt_dv = spif_rdlh_pkt_dv & ~qs.flit_mode_enable; 

wire [RX_TLP_NFM-1:0] nfm_rdlh_bad_tlp_err_pertlp;
wire [RX_TLP_NFM-1:0] nfm_rdlh_lcrc_tlp_err_pertlp;
wire [RX_TLP_NFM-1:0] nfm_rdlh_duplicate_tlp_err_pertlp;

rdlh_tlp_extract

#(.INST(INST)) u_rdlh_tlp_extract(
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .rdlh_link_up               (rdlh_link_up),
    .rplh_rdlh_pkt_dv           (nfm_rplh_rdlh_pkt_dv),
    .rplh_rdlh_pkt_data         (spif_rdlh_pkt_data [DW_NFM-1:0]),
    .rplh_rdlh_tlp_start        (spif_rdlh_tlp_start[NW_NFM-1:0]),
    .rplh_rdlh_pkt_end          (spif_rdlh_pkt_end  [NW_NFM-1:0]),
    .rplh_rdlh_pkt_edb          (spif_rdlh_pkt_edb  [NW_NFM-1:0]),
    .rplh_rdlh_pkt_err          (spif_rdlh_pkt_err  [NW_NFM-1:0]),
    .rplh_rdlh_nak              (spif_rdlh_rx_nak   [NW_NFM-1:0]),
    .nak_scheduled              (nak_scheduled),
    .ras_rdlh_prot_disable      (ras_rdlh_prot_disable),
    .ras_err_inj_en_array       (ras_err_inj_en_array),
    .ras_err_inj_mask           (ras_err_inj_mask),
    .cdm_ras_des_einj0_enable   (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_crc_type (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj0_count    (cdm_ras_des_einj0_count),

// ---- outputs ---------------

    .ras_stat_rdlh_tlp_extract_corr    (ras_stat_rdlh_corr),
    .ras_stat_rdlh_tlp_extract_uncorr  (ras_stat_rdlh_uncorr),
    
    .rdlh_ptm_sot               (rdlh_ptm_sot),
    .rdlh_ptm_multi_cycle       (rdlh_ptm_multi_cycle),
    .rdlh_ptm_request           (rdlh_ptm_request),
    .rdlh_ptm_response          (rdlh_ptm_response),
    .rdlh_duplicate_tlp         (rdlh_duplicate_tlp),

    .rdlh_req2send_ack          (rdlh_xdlh_req2send_ack),
    .rdlh_req2send_ack_due2dup  (rdlh_xdlh_req2send_ack_due2dup),
    .rdlh_req2send_nack         (rdlh_xdlh_req2send_nack),
`ifndef SYNTHESIS
`endif // SYNTHESIS
    .rdlh_req_acknack_seqnum    (rdlh_xdlh_req_acknack_seqnum),
    .rdlh_rtlh_tlp_data         (nfm_rdlh_rtlh_tlp_data),
    .rdlh_rtlh_tlp_dv           (nfm_rdlh_rtlh_tlp_dv),
    .rdlh_rtlh_tlp_sot          (nfm_rdlh_rtlh_tlp_sot),
    .rdlh_rtlh_tlp_eot          (nfm_rdlh_rtlh_tlp_eot),
    .rdlh_rtlh_tlp_abort        (nfm_rdlh_rtlh_tlp_abort),
    .ras_err_inj_done           (ras_err_inj_done),
    .rdlh_bad_tlp_err           (rdlh_bad_tlp_err)
    ,
    .rdlh_bad_tlp_err_pertlp       (nfm_rdlh_bad_tlp_err_pertlp),
    .rdlh_lcrc_tlp_err_pertlp      (nfm_rdlh_lcrc_tlp_err_pertlp),
    .rdlh_nulified_tlp_err_pertlp  (nfm_rdlh_nulified_tlp_err_pertlp),
    .rdlh_duplicate_tlp_err_pertlp (nfm_rdlh_duplicate_tlp_err_pertlp)
    ,
    .rdlh_einj0_lcrc_evt        (rdlh_einj0_lcrc_evt)
);

assign rdlh_bad_tlp_err_pertlp       = { {RX_TLP-RX_TLP_NFM{1'b0}}, nfm_rdlh_bad_tlp_err_pertlp      };
assign rdlh_lcrc_tlp_err_pertlp      = { {RX_TLP-RX_TLP_NFM{1'b0}}, nfm_rdlh_lcrc_tlp_err_pertlp     };
assign rdlh_duplicate_tlp_err_pertlp = { {RX_TLP-RX_TLP_NFM{1'b0}}, nfm_rdlh_duplicate_tlp_err_pertlp};

// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// The DLP extract block does all the DL layer DLP packet extraction from the data coming from the PHY layer.
// 1.The block identify the DLPs and does the checksum for every DLP
// 2.All violation of DLPs and DL protocol errors are checked in this block
// 3. ACK/NACK monitoring and signaling to XDLH to release the retry buffer resources in XDLH.

rdlh_dlp_extract

#(INST) u_rdlh_dlp_extract(
    .core_clk                    (core_clk),
    .core_rst_n                  (core_rst_n),
    .rdlh_dlcntrl_state          (rdlh_rtlh_link_state),
    .rplh_rdlh_dllp_start        (spif_rdlh_dllp_start[NW_NFM-1:0]),
    .rplh_rdlh_pkt_end           (spif_rdlh_pkt_end   [NW_NFM-1:0]),
    .rplh_rdlh_pkt_edb           (spif_rdlh_pkt_edb   [NW_NFM-1:0]),
    .rplh_rdlh_pkt_err           (spif_rdlh_pkt_err   [NW_NFM-1:0]),
    .rplh_rdlh_pkt_data          (spif_rdlh_pkt_data  [DW_NFM-1:0]),
    .rplh_rdlh_pkt_dv            (spif_rdlh_pkt_dv),
    .xdlh_rdlh_last_xmt_seqnum   (xdlh_rdlh_last_xmt_seqnum),
    .smlh_flit_mode_enable       (qs.flit_mode_enable),
    .rplh_rdlh_fm_dllp_data      (spif_rdlh_fm_dllp_data),
    .rplh_rdlh_fm_dllp_valid     (spif_rdlh_fm_dllp_valid),
    .rplh_rdlh_fm_dllp_opt_fc_up (spif_rdlh_fm_dllp_opt_fc_up),

// ---- outputs ---------------
    .rdlh_rcvd_nack              (rdlh_xdlh_rcvd_nack),
    .rdlh_rcvd_ack               (rdlh_xdlh_rcvd_ack),
    .rdlh_rcvd_acknack_seqnum    (rdlh_xdlh_rcvd_acknack_seqnum),
    .rdlh_rcvd_dllp              (rdlh_rtlh_rcvd_dllp),
    .rdlh_rcvd_dllp_content      (rdlh_rtlh_dllp_content),
    .rcvd_dllp_outseq            (rcvd_dllp_outseq),
    .rdlh_bad_dllp_err           (rdlh_bad_dllp_err),
    .rdlh_rcvd_as_req_l1         (rdlh_rcvd_as_req_l1),
    .rdlh_rcvd_pm_enter_l1       (rdlh_rcvd_pm_enter_l1),
    .rdlh_rcvd_pm_enter_l23      (rdlh_rcvd_pm_enter_l23),
    .rdlh_rcvd_pm_req_ack        (rdlh_rcvd_pm_req_ack)
    ,
    .rcvd_dl_feature_content     (rcvd_dl_feature_content),
    .rdlh_rcvd_dl_feature        (rdlh_rcvd_dl_feature),
    .dl_feature_abort            (dl_feature_abort)
    ,
    .rdlh_bad_dllp_err_perdllp   (rdlh_bad_dllp_err_perdllp),
    .rdlh_rcvd_nack_perdllp      (rdlh_rcvd_nack_perdllp),
    .rdlh_rcvd_ack_perdllp       (rdlh_rcvd_ack_perdllp),
    .rdlh_curnt_rx_ack_seqnum    (rdlh_curnt_rx_ack_seqnum)
    ,
    .rdlh_rcvd_dllp_fm_opt_fc_up (rdlh_rtlh_rcvd_dllp_fm_opt_fc_up)
    ,
    .rdlh_xdlh_l0p_dllp          (rdlh_xdlh_l0p_dllp)

);





endmodule
