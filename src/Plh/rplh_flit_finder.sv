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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_flit_finder.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Flit Finder
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module rplh_flit_finder
import DWC_pcie_core_pkg::ltssm_state_e;
import cx_pl_pkg::rplh_xplh_fm_retry_t;
import DWC_pcie_core_pkg::rplh_flit_logging_interface_struct;
import cx_pl_pkg::P_TX_SEQNUM_WD;
import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
import spif_pkg::stream_id_e;
import spif_pkg::SPIF_NBYTES;
import spif_pkg::SPIF_NDPBITS;
import cx_pl_pkg::P_FLIT_WD;
#(
parameter   NL           = `CX_NL,                             // Max number of lanes supported
parameter   NB           = `CX_NB,                             // Number of symbols (bytes) per clock cycle
parameter   AW           = `CX_ANB_WD,                         // Width of the active number of bytes
parameter   NW           = `CX_PL_NW,                          // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW           = (32*NW),                            // Width of datapath in bits.
parameter   DATA_PAR_WD  = `CX_RAS_RPL_DATA_PROT_WD,           // Number of protection bits in the datapath
parameter   DW_W_PAR     = DW + DATA_PAR_WD,                   // datapath width with protection bits
parameter   TP           = `TP                                 // Clock to Q delay (simulator insurance)
)

                       (
// ---- inputs ---------------
input                        core_clk,
input                        core_rst_n,
input                        cxl_mode_enable,              // CXL Mode is enabled
input   [5:0]                smlh_link_mode,
input   [AW-1:0]             active_nb,
input                        rxdata_dv,                    // data is valid this cycle
input   [(NL*NB*8)-1:0]      rxdata,                       // Incoming data
input                        search_for_tokens,            // enable token processing while in a data stream
input   ltssm_state_e        smlh_ltssm_state,             // Current LTSSM state. 
input                        smlh_block_dl_init,           // SPIF: Indication from the LogPHY to block Initialization of DLLPs
input                        cfg_upstream_port,            // Upstream port when it is high
output                       rplh_ptm_sot,                 // indicate to PTM logic a PTM Flit is observed
output                       rplh_ptm_request,             // observed PTM request
output                       rplh_ptm_response,            // observed PTM response
output                       rplh_ptm_duplicate,           // observed PTM message in duplicate flit
input                        cfg_acknack_disable,          // Prevent sending of ack/nak packetsw
input                        cdm_ras_des_einj2_enable,     // Error injection 2 enable
input   [1:0]                cdm_ras_des_einj2_dllp_type,  // Error injection 2 DLLP type
input   [2:0]                         current_data_rate,               // Current Data Rate
input   flit_err_inj_interface_struct cdm_plh_flit_err_inj_interface,  // Flit Error Injection interface struct
// ---- outputs ---------------
output  [DW_W_PAR-1:0]       rplh_fmpkt_data,              // Packet Data
output                       rplh_fmpkt_data_dv,           // Packed Data Valid
output  [NW-1:0]             rplh_fmpkt_tlp_pfx,           // Indicates DWord location of prefix
output  [NW-1:0]             rplh_fmpkt_tlp_soh,           // Indicates DWord location of the 1st Base Header DW
output  [NW-1:0]             rplh_fmpkt_tlp_end,           // Indicates DWord location of a packet END
output                       rplh_fmpkt_tlp_nul,           // The last TLP ending was Nullified by the Flit Marker
output                       rplh_fmpkt_tlp_psn,           // The last TLP ending was Poisoned by the Flit Marker
output  [NW-1:0]             rplh_fmpkt_tlp_idl,           // Indicates an empty DWord
output  [1:0]                rplh_flit_rcvd_idle,          // RMLH block keeps track of the number of consecutive IDLE flits.
                                                           // Bit 0 indicates 8 continous IDLE flits received, bit 1 indicates 1 IDLE flit received
output  rplh_flit_dl_prot_err,                             // Indicates Data link protocol error
output  rplh_flit_logging_interface_struct rplh_flit_logging_interface,           // RPLH Flit Logging Interface

output  [31:0]               rplh_rdlh_fm_dllp_data,       // DLLP data extracted from DL bytes
output                       rplh_rdlh_fm_dllp_valid,      // Valid DLLP data
output                       rplh_rdlh_fm_dllp_opt_fc_up,  // DLLP is an Optimized FC update
input                        rplh_spif_enable,             // SPIF Interface enable
output stream_id_e           rplh_flit_pl_stream,          // SPIF Interface: Packet Layer to Link Layer Stream ID
output                       rplh_flit_pl_nullified,       // SPIF Interface: Packet Layer to Link Layer Last TLP Nullified Flit Marker
output                       rplh_flit_pl_poisoned,        // SPIF Interface: Packet Layer to Link Layer Last TLP Poisoned Flit Marker
output                       rplh_flit_pl_valid,           // SPIF Interface: Packet Layer to Link Layer Data Valid
output [SPIF_NBYTES*8-1:0]   rplh_flit_pl_data,            // SPIF Interface: Packet Layer to Link Layer Data
output [SPIF_NDPBITS-1:0]    rplh_flit_pl_data_chk,        // SPIF Interface: Packet Layer to Link Layer Data Protection
output                       rplh_fm_cxl_rcvd_flit,        // error in first almp detected, enable transmitter to send Nak 
output [1 : 0]               rplh_cdm_flit_err_inj_status, // Flit Error Injection Status
output  rplh_xplh_fm_retry_t rplh_xplh_fm_retry            // RPLH to XPLH Flit Mode Retry Interface
);

// Local Parameters
localparam FLIT_PROT_WD = P_FLIT_WD/32*`CX_RAS_DWORD_PROT_WD;   // Full Flit Protection in bits
localparam FDW          = P_FLIT_WD - (14*8);                   // Flit Data Width in bits (without FEC and CRC bytes)
localparam FDW_W_PROT   = FDW + `CX_RAS_FLIT_PROT_WD;         // Flit Data Width in bits with protection bits

logic                       rxdata_vld;
logic  [P_FLIT_WD-1:0]      rplh_acc_full_flit_s;
logic  [P_FLIT_WD-1:0]      rplh_acc_full_flit_r;
logic                       rplh_acc_full_flit_vld;
wire [FDW_W_PROT - 1 : 0]  rplh_flit_prot_data;
wire                       rplh_flit_prot_data_dv;
wire                       rplh_flit_prot_data_dinv;
wire                       rplh_flit_prot_fec_data_dinv;
wire                       rplh_flit_prot_crc_data_dinv;
logic [P_TX_SEQNUM_WD-1:0] rplh_implicit_rx_flit_seq_num;

rplh_flit_acc
 u_rplh_flit_acc(
// ---- inputs ---------------
  .core_clk                           (core_clk),
  .core_rst_n                         (core_rst_n),
  .smlh_link_mode                     (smlh_link_mode),
  .active_nb                          (active_nb),
  .search_for_tokens                  (search_for_tokens),
  .rxdata_dv                          (rxdata_dv),  
  .rxdata                             (rxdata),
  .current_data_rate                  (current_data_rate),
  .implicit_rx_flit_seq_num           (rplh_implicit_rx_flit_seq_num),
  .implicit_rx_flit_seq_num_valid     (rplh_flit_prot_data_dv),
  .cxl_mode_enable                    (cxl_mode_enable),
  .cdm_plh_flit_err_inj_interface     (cdm_plh_flit_err_inj_interface),
// ---- outputs ---------------
  .rxdata_o_vld                       (rxdata_vld),
  .rplh_acc_flit_nxt_vld              (rplh_acc_full_flit_vld),  
  .rplh_acc_flit_nxt                  (rplh_acc_full_flit_s),
  .rplh_acc_flit                      (rplh_acc_full_flit_r)
    ,
    .rplh_cdm_flit_err_inj_status     (rplh_cdm_flit_err_inj_status)
);

rplh_flit_prot
 u_rplh_flit_prot
(
// ---- inputs ---------------
    .core_clk                         (core_clk),
    .core_rst_n                       (core_rst_n),
    .smlh_link_mode                   (smlh_link_mode),
    .rxdata_vld                       (rxdata_vld),
    .rplh_flit_in_nxt_vld             (rplh_acc_full_flit_vld),
    .rplh_flit_in_nxt                 (rplh_acc_full_flit_s),
    .rplh_flit_in                     (rplh_acc_full_flit_r),
    .search_for_tokens                (search_for_tokens),
// ---- outputs ---------------
    .rplh_flit_prot_synd_parity       (rplh_flit_logging_interface.rplh_flit_prot_synd_parity),
    .rplh_flit_prot_synd_check        (rplh_flit_logging_interface.rplh_flit_prot_synd_check),
    .rplh_flit_prot_data_out          (rplh_flit_prot_data),
    .rplh_flit_prot_data_valid        (rplh_flit_prot_data_dv),
    .rplh_flit_prot_fec_data_invalid  (rplh_flit_prot_fec_data_dinv),
    .rplh_flit_prot_crc_data_invalid  (rplh_flit_prot_crc_data_dinv),
    .rplh_flit_prot_fec_c_err         (rplh_flit_logging_interface.rplh_flit_fec_corr_error),
    .rplh_flit_prot_even_b_err        (rplh_flit_logging_interface.rplh_flit_fec_corr_even_bit_error),
    .rplh_flit_prot_odd_b_err         (rplh_flit_logging_interface.rplh_flit_fec_corr_odd_bit_error)

);

// Flit Logging interface
assign rplh_flit_logging_interface.rplh_valid_flit = rplh_flit_prot_data_dv;
assign rplh_flit_logging_interface.rplh_flit_fec_uncorr_error = rplh_flit_prot_fec_data_dinv;
assign rplh_flit_logging_interface.rplh_flit_crc_uncorr_error = rplh_flit_prot_crc_data_dinv;
assign rplh_flit_prot_data_dinv = rplh_flit_prot_fec_data_dinv | rplh_flit_prot_crc_data_dinv;
//

stream_id_e             rplh_flitseq_stream;    // RPLH Flit Stream ID
wire                    rplh_flitseq_dv;
wire [P_FLIT_WD-1:0]    rplh_flitseq_data;
wire [FLIT_PROT_WD-1:0] rplh_flitseq_data_prot;

rplh_flit_seq_num
 u_rplh_flit_seq_num (
// ---- inputs ---------------
    .core_clk                      (core_clk),
    .core_rst_n                    (core_rst_n),
    .rxflit_data                   (rplh_flit_prot_data),
    .rxflit_dv                     (rplh_flit_prot_data_dv),
    .rxflit_err                    (rplh_flit_prot_data_dinv),
    .smlh_ltssm_state              (smlh_ltssm_state),
    .smlh_block_dl_init            (smlh_block_dl_init),
    .cxl_mode_enable               (cxl_mode_enable),
    .cfg_upstream_port             (cfg_upstream_port),
    .rplh_ptm_sot                  (rplh_ptm_sot),
    .rplh_ptm_request              (rplh_ptm_request),
    .rplh_ptm_response             (rplh_ptm_response),
    .rplh_ptm_duplicate            (rplh_ptm_duplicate),
      .cfg_acknack_disable         (cfg_acknack_disable),
      .cdm_ras_des_einj2_enable    (cdm_ras_des_einj2_enable),
      .cdm_ras_des_einj2_dllp_type (cdm_ras_des_einj2_dllp_type),
// ---- outputs ---------------
    .rplh_flit_stream              (rplh_flitseq_stream),
    .rplh_fm_cxl_rcvd_flit         (rplh_fm_cxl_rcvd_flit),
    .rplh_flit_dv                  (rplh_flitseq_dv),
    .rplh_flit_data                (rplh_flitseq_data),
    .rplh_flit_data_prot           (rplh_flitseq_data_prot),
    .rplh_flit_nullified           (rplh_flitseq_nullified),
    .rplh_flit_poisoned            (rplh_flitseq_poisoned),
    .rplh_flit_dl_prot_err         (rplh_flit_dl_prot_err),
    .rplh_unrecognized_flit        (rplh_flit_logging_interface.rplh_flit_unrecognized_flit),
    .rplh_flit_rcvd_idle           (rplh_flit_rcvd_idle),
    .rplh_xplh_fm_retry            (rplh_xplh_fm_retry),
    .rplh_rdlh_fm_dllp_data        (rplh_rdlh_fm_dllp_data),
    .rplh_rdlh_fm_dllp_valid       (rplh_rdlh_fm_dllp_valid),
    .rplh_rdlh_fm_dllp_opt_fc_up   (rplh_rdlh_fm_dllp_opt_fc_up)
    ,
    .rplh_implicit_rx_flit_seq_num  (rplh_implicit_rx_flit_seq_num)
);

rplh_fm_ser_pkt_finder
 u_rplh_fm_ser_pkt_finder
(
// ---- inputs ---------------
    .core_clk                      (core_clk),
    .core_rst_n                    (core_rst_n),
    .rplh_flitseq_stream           (rplh_flitseq_stream),
    .rplh_flitseq_dv               (rplh_flitseq_dv),
    .rplh_flitseq_data             (rplh_flitseq_data),
    .rplh_flitseq_data_prot        (rplh_flitseq_data_prot),
    .rplh_flitseq_nullified        (rplh_flitseq_nullified),
    .rplh_flitseq_poisoned         (rplh_flitseq_poisoned),
// ---- spif in/out -----------
    .rplh_spif_enable              (rplh_spif_enable),
    .rplh_fmser_stream             (rplh_flit_pl_stream),
    .rplh_fmser_nullified          (rplh_flit_pl_nullified),
    .rplh_fmser_poisoned           (rplh_flit_pl_poisoned),
    .rplh_fmser_dv                 (rplh_flit_pl_valid),
    .rplh_fmser_data               (rplh_flit_pl_data),
    .rplh_fmser_data_prot          (rplh_flit_pl_data_chk),
// ---- outputs ---------------
    .rplh_fmpkt_data               (rplh_fmpkt_data),
    .rplh_fmpkt_data_dv            (rplh_fmpkt_data_dv),
    .rplh_fmpkt_tlp_pfx            (rplh_fmpkt_tlp_pfx),
    .rplh_fmpkt_tlp_soh            (rplh_fmpkt_tlp_soh),
    .rplh_fmpkt_tlp_end            (rplh_fmpkt_tlp_end),
    .rplh_fmpkt_tlp_nul            (rplh_fmpkt_tlp_nul),
    .rplh_fmpkt_tlp_psn            (rplh_fmpkt_tlp_psn),
    .rplh_fmpkt_tlp_idl            (rplh_fmpkt_tlp_idl)
);

endmodule

