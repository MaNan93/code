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
// ---    $Revision: #22 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_128b.sv#22 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Hander
// --- This module handles 128b, 256b and 512b datapath widths. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "Layer2/svif/xdlh_replay_timer_if.svh"
`include "Layer2/svif/xdlh_replay_num_if.svh"
`include "Layer2/svif/xdlh_retrain_cnt_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
 module xdlh_128b
 import cx_pl_pkg::dllp_struct;
 import cx_pl_pkg::PM_REQUEST_ACK;
 import cx_pl_pkg::PM_ENTER_L1;
 import cx_pl_pkg::PM_ENTER_L23;
 import cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
 import cx_pl_pkg::NOP_DLLP;
 import cx_pl_pkg::NOP2_DLLP;
 import cx_pl_pkg::rbuf_struct;
 import cx_pl_pkg::P_NW;
 import cx_pl_pkg::P_NFM_NW;
 import cx_pl_pkg::P_NFM_RBUF_WD;
 import cx_pl_pkg::NFM_DATA_PAR_WD;
 import cx_pl_pkg::NFM_DW_W_PAR;
 import cx_pl_pkg::tx_cmd_struct;
 import cx_pl_pkg::CMD_RESET;
 import cx_pl_pkg::CMD_FLUSH_XAIM;
 import cx_pl_pkg::NOP;
 import cx_pl_pkg::P_NVC;
 import cx_pl_pkg::dllp_type_e;

 import cx_pl_pkg::tx_flit_struct;
 import cx_pl_pkg::l0p_ack_struct;
 import cx_pl_pkg::fm_dllp_struct;
 import cx_pl_pkg::CMD_FLUSH_XTLH;
 
 import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_XDLH;
 import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
 import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 import spif_pkg::protocol_cfg_t;
 (
//  Interface Ports
    b_xdlh_xplh_mp,
    b_xdlh_spif,
// ---- inputs ---------------
    core_clk,
    core_rst_n,
//----------------------------
//L0P Support
    xdlh_l0p_dllp,
    xdlh_dllp_l0p_ack,
    xplh_l0p_dllps_count,
//----------------------------
    cfg_upstream_port,
    cfg_replay_timer_value,
    cfg_ack_freq,
    cfg_ack_latency_timer,
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_other_msg_payload,
    cfg_other_msg_request,
    cfg_corrupt_crc_pattern,
    smlh_in_l0,
    smlh_in_l0s,
    smlh_in_l1,
    smlh_eq_pending,

    current_data_rate,
    xtlh_xdlh_tlp_len,
    xtlh_xdlh_data,
 //   xtlh_xdlh_dwen,
    xtlh_xdlh_dv,
    xtlh_xdlh_sot,
    cfg_rasdp_error_mode_en,
    cfg_rasdp_error_mode,
    xdlh_rasdp_error_mode,
    ras_dp_err_log,
    ras_dp_err_inj,
    xtlh_xdlh_eot,
    xtlh_xdlh_badeot,
    rdlh_link_up,
    rdlh_xdlh_rcvd_nack,
    rdlh_xdlh_rcvd_ack,
    rdlh_xdlh_rcvd_acknack_seqnum,
    rdlh_xdlh_req2send_ack,
    rdlh_xdlh_req2send_ack_due2dup,
    rdlh_xdlh_req2send_nack,
    rdlh_xdlh_req_acknack_seqnum,
    rtlh_xdlh_fc_req,
    rtlh_xdlh_fc_req_hi,
    rtlh_xdlh_fc_req_low,
    rtlh_xdlh_fc_data,
    xmlh_xplh_halt,
    xplh_xmlh_eot,
    xdlh_block_dl_init,
    xdlh_dl_active,
    xdlh_protocol_cfg,
    xdlh_pm_state_req,
    xdlh_pl_stall_req,
    xdlh_lp_stall_ack,
    xdlh_pm_dllp_ack,
    xmlh_stp_start,
    smlh_link_mode,
    pm_xdlh_dllp_req,
    pm_freeze_ack_timer,
    smlh_link_in_training,
    lcrc_err_en,
    xtlh_sot_is_first,      
    xtlh_badeot,
    xtlh_first_badeot,
    xtlh_eot_sot,
    xtlh_eot_sot_eot,
    cdm_ras_des_force_linkdown_noack,
    cdm_ras_des_einj0_enable,
    cdm_ras_des_einj0_count,
    cdm_ras_des_einj0_crc_type,
    cdm_ras_des_einj1_enable,
    cdm_ras_des_einj1_seq_type,
    cdm_ras_des_einj1_bad_seq,
    cdm_ras_des_einj1_count,
    cdm_ras_des_einj2_enable,
    cdm_ras_des_einj2_dllp_type,
    cdm_ras_des_einj5_enable,
    cdm_ras_des_einj5_count,
    cdm_ras_des_einj5_tlp_type,
    smlh_in_rcvry,
    send_feature_dllp,
    cfg_local_feature_support,
    cfg_dlink_feature_valid,
    xdlh_rdlh_feature_ack,
// ---- outputs ---------------
    lcrc_err_asserted,
    xdlh_xtlh_halt,
    xdlh_rdlh_last_xmt_seqnum,
    xdlh_rtlh_fc_ack,
    xdlh_smlh_start_link_retrain,
    xdlh_curnt_seqnum,
    xdlh_retrybuf_not_empty,
    xdlh_not_expecting_ack,
    xdlh_xmt_pme_ack,
    xdlh_nodllp_pending,
    xdlh_no_acknak_dllp_pending,
    xdlh_tlp_pending,
    xdlh_retry_pending,


// Retry buffer external RAM interface
    xdlh_retryram_par_chk_val,
    xdlh_retryram_halt,
    retryram_xdlh_data,
    retryram_xdlh_depth,
    retryram_xdlh_parerr,
    xdlh_ptm_sot,
    xdlh_ptm_multi_cycle,
    xdlh_ptm_request,
    xdlh_ptm_response,
    xdlh_rbuf_replaying,

// Performance changes - 2p RAM I/F
 //   xdlh_retrysotram_addr,
    xdlh_retrysotram_waddr,
    xdlh_retrysotram_raddr,
    xdlh_retrysotram_data,
    xdlh_retrysotram_we,
    xdlh_retrysotram_en,
    xdlh_retrysotram_par_chk_val,
    retrysotram_xdlh_data,
    retrysotram_xdlh_parerr,
    retrysotram_xdlh_depth,
    nak_scheduled,
    xdlh_retry_req
    ,
    xdlh_nak_sent,
    xdlh_ack_sent,
    xdlh_update_fc_sent,
    xdlh_smlh_goto_detect
    ,
    xdlh_einj0_lcrc_evt,
    xdlh_einj0_fcrc_evt,
    xdlh_einj0_dllpcrc_evt,
    xdlh_einj1_tx_tlp_snum_evt,
    xdlh_einj1_tx_dllp_snum_evt,
    xdlh_einj2_nak_evt,
    xdlh_einj5_nultlp_evt,
    xdlh_einj5_dup_evt
    ,
    rbuf_pkt_cnt,
    xdlh_replay_timeout,
    xdlh_replay_timer_value,
    xdlh_retryram_if
    ,
    xplh_xdlh_cmd,
    xdlh_xplh_cmd_ack,
    xdlh_xtlh_cmd,
    xtlh_xdlh_cmd_ack
    ,
    xtlh_xdlh_flit,
    xplh_xdlh_dllp_halt,
    xdlh_xplh_dllp_out,
    rtlh_fc_init_status,
    xdlh_upd_fc_sent,
    xdlh_xtlh_fc_init_done
);

// =============================================================================
// ---- Parameters ----
// =============================================================================
parameter   INST        = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW          = (P_NW>16) ? P_NFM_NW : P_NW;   // Number of 32-bit dwords handled by the datapath each clock. This module supports 4, 8 and 16 
parameter   DW          = (32*NW);  // Width of datapath in bits.
parameter   NB          = `CX_NB;   // Width of datapath in bits.
parameter   NL          = `CX_NL;   // Max number of lanes supported
parameter   TP          = `TP;      // Clock to Q delay (simulator insurance)
parameter   TX_NDLLP    = `CX_TX_NDLLP;
parameter   RBUF_WD     = (P_NW>16) ? P_NFM_RBUF_WD : `RBUF_WIDTH ;  // 1 parity error bit per dword
parameter   RBUF_PW     = `RBUF_PW;         // True pointer width is calculated from the depth of the memory
parameter   SOTBUF_WD   = `SOTBUF_WIDTH;
parameter   SOTBUF_DP   = `SOTBUF_DEPTH;                    // Indexed by sequence number (or some bits of it)
parameter   SOTBUF_PW   = `SOTBUF_L2DEPTH;               // Indexed by sequence number (or some bits of it)

parameter DATA_PAR_WD   = NFM_DATA_PAR_WD;      // data bus parity width
parameter DW_W_PAR      = NFM_DW_W_PAR;  // Width of datapath in bits plus the parity bits.


// =============================================================================
// ---- inputs ---------------
// =============================================================================
tx_lp_if     b_xdlh_xplh_mp;  // Link Layer to Physical Layer master modport
tx_lp_if     b_xdlh_xplh_mux(); // Mux between Flit mode and non-Flit mode on LP interface
xdlh_replay_timer_if  b_xdlh_replay();
xdlh_replay_num_if    b_xdlh_replay_num();
xdlh_retrain_cnt_if   b_xdlh_retrain_cnt();
spif_if.xplh_slave_mp       b_xdlh_spif;              // Link vLSM to CXL.io Data Link Layer Interface
input                   core_clk;
input                   core_rst_n;

//L0p Support
input   dllp_struct     xdlh_l0p_dllp;                  // L0P DLLP
output  l0p_ack_struct  xdlh_dllp_l0p_ack;              // Acknowledge the L0P DLLP has been Transmitted
output  logic           xplh_l0p_dllps_count;

input                   cfg_upstream_port;
input   [16:0]          cfg_replay_timer_value;         // Replay Timer value.  Default value is expected to be chosen from table 3-4
input   [7:0]           cfg_ack_freq;                   // 8bits programmable value to allow up to 256 ack accumulated before send
input   [15:0]          cfg_ack_latency_timer;          // 16bits Spec called for array. We recommend to set array in cfg register block so that it is easier to control. We may want programmable value set by software.
input   [31:0]          cfg_other_msg_payload;          // special DLLP message register to allow user insert special DLLP message with this 32 bits data content.
input                   cfg_other_msg_request;          // special DLLP message register to allow user insert special DLLP message with this 32 bits data content.
input   [31:0]          cfg_corrupt_crc_pattern;        // How to corrupt CRC data -- normally just invert CRC. This value allows per-bit inversion.
input                   cfg_flow_control_disable;
input                   cfg_acknack_disable;
input                   smlh_in_l0;                     // XMLH layer report bakc that LTSSM is in L0 state so that we allow transmission from RTLH. This is to prevent TLPs enter into pipe too early
input                   smlh_in_l0s;                    // XMLH reports that LTSSM is in L0s
input                   smlh_in_l1;                     // XMLH reports that LTSSM is in L1
input                   smlh_eq_pending;
input   [2:0]           current_data_rate;              // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
input   [DW_W_PAR-1:0]        xtlh_xdlh_data;                 // XTLH outputs header/data bus to XDLH
input   [NW-1:0]           xtlh_xdlh_sot;
input   [NW-1:0]           xtlh_xdlh_eot;
input                           xtlh_xdlh_dv;
input   [NW-1:0]           xtlh_xdlh_badeot;
input                   cfg_rasdp_error_mode_en;
input                   cfg_rasdp_error_mode;
output                  xdlh_rasdp_error_mode;
output ras_dp_err_log_t ras_dp_err_log;
input  ras_dp_err_inj_t         ras_dp_err_inj;
input                   rdlh_link_up;                   // when asserted, it indicates that link control FSM is in link active state.

input                   rdlh_xdlh_rcvd_nack;            // when asserted, this pulse signal indicates that there was a NACK PKT received, and its nack sequence number driven to RDLH_RCVD_ACKNACK_SEQ_NUM
input                   rdlh_xdlh_rcvd_ack;             // when asserted, this pulse signal indicates that there was a ACK PKT received, and its ACK sequence number driven to RDLH_RCVD_ACKNACK_SEQ_NUM
input   [11:0]          rdlh_xdlh_rcvd_acknack_seqnum;  // 12 bits indicated the sequence number of received ACK/NACK DLLP Packet
input                   rdlh_xdlh_req2send_ack;         // RDLH received a good packet and has been asked to send an ACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
input                   rdlh_xdlh_req2send_ack_due2dup; // RDLH received a packet that is a duplicated PKT . RDLH_REQ2SEND_ACK signal will be asserted while RDLH_RCVD_DUP is asserted.
input                   rdlh_xdlh_req2send_nack;        // RDLH received a good packet and has been asked to send an NACK back. This signal is mutually exclusive with NACK signal. Its received transaction sequence number droved at  RDLH_RCVD_PKT_SEQ_NUM
input   [11:0]          rdlh_xdlh_req_acknack_seqnum;   // RDLH received a packet with this sequence number
input   [TX_NDLLP-1:0]  rtlh_xdlh_fc_req;               // When asserted, RTLH has requested to send a FC packet, it is de-asserted when xdlh_rtlh_fc_ack is asserted to RTLH
input                   rtlh_xdlh_fc_req_hi;            // When asserted, RTLH has requested to send a high-priority FC packet that has higher priority than ACK/NACK
input                   rtlh_xdlh_fc_req_low;           // When asserted, RTLH has requested to send a low-priority FC packet that has lower priority than TLP
input   [(32*TX_NDLLP)-1:0]  rtlh_xdlh_fc_data;              // Content data for FC update, which has be to be valid when RTLH_FC_REQ is asserted

input                   xmlh_xplh_halt;
input   [NW-1:0]        xplh_xmlh_eot;
input                   xmlh_stp_start;

input   [5:0]           smlh_link_mode;

// pm module signals
input     dllp_struct   pm_xdlh_dllp_req;               // PM module requests to send pm dllps
input                   smlh_link_in_training;
input                   pm_freeze_ack_timer;            // PM module request to block acknack timer
input                      lcrc_err_en;                  // For debug and diagnose feature, this signal enables LSB bit flip of LCRC field to a TLP that is in progress

input [10:0]    xtlh_xdlh_tlp_len;

input                  xdlh_block_dl_init;             // SPIF: Indication from the LogPHY to block Initialization of DLLPs
input                  xdlh_dl_active;                 // SPIF: Indication from the Link Layer that DLCMSM is in DL_ACTIVE state
input  protocol_cfg_t  xdlh_protocol_cfg;      // Protocol Configuration for DLH Layer
input                  xdlh_pm_state_req;      // XDLH PM Entry Request (allows DLLP propagation when stall_req is asserted)
input                  xdlh_pl_stall_req;      // SPIF XDLH Stall Request
output                 xdlh_lp_stall_ack;      // SPIF XDLH Stall Acknowledge
output dllp_struct     xdlh_pm_dllp_ack;       // XDLH PM DLLP Acknowledge
input xtlh_sot_is_first;
input xtlh_eot_sot_eot;
input xtlh_badeot;
input xtlh_first_badeot; 
input xtlh_eot_sot;

input                   cdm_ras_des_force_linkdown_noack; // Silicond Debug: Force Link down when MAC does not receive ACK DLLP for long time
input                   cdm_ras_des_einj0_enable ;       // Error injection 0 enable
input   [7:0]           cdm_ras_des_einj0_count;         // Error injection 0 count
input   [3:0]           cdm_ras_des_einj0_crc_type ;     // Error injection 0 CRC type
input                   cdm_ras_des_einj1_enable ;       // Error injection 1 enable
input                   cdm_ras_des_einj1_seq_type;      // Error injection 1 seq# type
input   [12:0]          cdm_ras_des_einj1_bad_seq ;      // Error injection 1 bad seq# value
input   [7:0]           cdm_ras_des_einj1_count ;        // Error injection 1 count
input                   cdm_ras_des_einj2_enable;        // Error injection 2 enable
input   [1:0]           cdm_ras_des_einj2_dllp_type;     // Error injection 2 DLLP type
input                   cdm_ras_des_einj5_enable ;       // Error injection 5 enable
input   [7:0]           cdm_ras_des_einj5_count ;        // Error injection 5 count
input                   cdm_ras_des_einj5_tlp_type ;     // Error injection 5 tlp type (dup/nul)
input                   smlh_in_rcvry;                   // LTSSM enters recovery
input                       send_feature_dllp;           // Transmit Feature DLLP
input  [22:0]               cfg_local_feature_support;   // Local Feature (Including local scaled flow control) Support
input                       cfg_dlink_feature_valid;     // Has received a Data Link Feature DLLP after the Link entered L0
output  logic           xdlh_rdlh_feature_ack;           // Acknowledge that DL_FEATURE DLLP has been transmitted
logic                   int_fm_pm_ack;

// =============================================================================
// ---- outputs ---------------
// =============================================================================
output                  lcrc_err_asserted;                // For debug and diagnose feature, this signal is a status to indicate that a TLP has been transmitted with LCRC error
output  logic           xdlh_xtlh_halt;             // when asserted, it indicates to RTLH arbitor to stop scheduling the next transaction.

output  [11:0]          xdlh_rdlh_last_xmt_seqnum;      // the last transmitted highest sequence number of TLP's DLLP. Receiver needs this signal to identify out of order TLP
output                  xdlh_rtlh_fc_ack;               // when asserted, it indicates that the FC packet data has been used and RTLH_FC_REQ signal will be de-asserted in next clock cycle.
output  [11:0]          xdlh_curnt_seqnum;              // inserted here for external monitor
output                  xdlh_smlh_start_link_retrain;


output                  xdlh_retrybuf_not_empty;
output                  xdlh_not_expecting_ack;
output                  xdlh_xmt_pme_ack;
output                  xdlh_nodllp_pending;            // No DLLP pending
output                  xdlh_no_acknak_dllp_pending;    // No Ack or Nak DLLP pending
output                  xdlh_tlp_pending;               // TLP pending in the datapath
output                  xdlh_retry_pending;             // TLP pending or retry FSM in reply state

// Retry buffer external RAM interface inputs/outpus declaration
input  [SOTBUF_WD -1:0]  retrysotram_xdlh_data;     // Data coming back from Retry buffer RAM
input  [SOTBUF_PW -1:0]  retrysotram_xdlh_depth;
input                    retrysotram_xdlh_parerr;
input  [RBUF_WD -1:0]    retryram_xdlh_data;           // Data coming back from Retry buffer RAM
input  [RBUF_PW -1:0]    retryram_xdlh_depth;          // How big is the external retry buffer
input                    retryram_xdlh_parerr;         // retry buffer ram parity error detected
output  rbuf_struct      xdlh_retryram_if;             // Retry buffer interface
output                   xdlh_retryram_par_chk_val;    // parity check enable to retry buffer RAM
output                   xdlh_retryram_halt;
output                   xdlh_retrysotram_par_chk_val; // parity check enable to retry buffer RAM
output                   xdlh_ptm_sot;
output                   xdlh_ptm_multi_cycle;
output                   xdlh_ptm_request;
output                   xdlh_ptm_response;
output                   xdlh_rbuf_replaying;

// Performance changes - 2p RAM I/F
// output  [SOTBUF_PW -1:0]    xdlh_retrysotram_addr;          // Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]    xdlh_retrysotram_waddr;          // Write Adrress to retry buffer RAM
output  [SOTBUF_PW -1:0]    xdlh_retrysotram_raddr;          // Read Adrress to retry buffer RAM
output  [SOTBUF_WD -1:0] xdlh_retrysotram_data;        // Write data to retry buffer RAM
output                   xdlh_retrysotram_we;          // Write enable to retry buffer RAM
output                   xdlh_retrysotram_en;          // Read enable to retry buffer RAM
output                   nak_scheduled;                // dllp generation block requests nak is scheduled to be transmitted

output                   xdlh_retry_req;               // Pulse: Retry Event 
output                   xdlh_nak_sent;                // Pulse: Tx Nak DLLP Event per TLP for Ras D.E.S event counter
output                   xdlh_ack_sent;                // Pulse: Tx Ack DLLP Event per TLP for Ras D.E.S event counter
output  [TX_NDLLP-1:0]   xdlh_update_fc_sent;          // Pulse: Tx Update-FC DLLP Event per TLP for Ras D.E.S event counter
output                   xdlh_smlh_goto_detect;        // Force ltssm to go to detect state
output  [1:0]            xdlh_einj0_lcrc_evt;          // Error injection 0 LCRC event
output                   xdlh_einj0_fcrc_evt;          // Error injection 0 ECRC event
output  [1:0]            xdlh_einj0_dllpcrc_evt;       // Error injection 0 DLLP CRC event
output  [1:0]            xdlh_einj1_tx_tlp_snum_evt;   // Error injection 1 Tx TLP Seq# event
output                   xdlh_einj1_tx_dllp_snum_evt;  // Error injection 1 Tx DLLP Seq# event
output                   xdlh_einj2_nak_evt;           // Error injection 2 NAK event
output                   xdlh_einj5_nultlp_evt;        // Error injection 5 nullified TLP event
output                   xdlh_einj5_dup_evt;           // Error injection 5 Duplicate TLP event
output  [11:0]              rbuf_pkt_cnt;               // packet in flight counter
output                  xdlh_replay_timeout;
output  [16:0]          xdlh_replay_timer_value;
input   tx_cmd_struct   xplh_xdlh_cmd;          // Command from lower layer
output  logic           xdlh_xplh_cmd_ack;      // Command acknowledge
output  tx_cmd_struct   xdlh_xtlh_cmd;          // Command to xdlh
input                   xtlh_xdlh_cmd_ack;      // Command acknowledge from upper layer
input   [P_NVC-1:0]       rtlh_fc_init_status;    // Report VC as ready for traffic
input   tx_flit_struct    xtlh_xdlh_flit;         // XTLH Flit Interface 
input                     xplh_xdlh_dllp_halt;    // Halt to DLLP interface
output  fm_dllp_struct    xdlh_xplh_dllp_out;     // DLLP
output logic              xdlh_upd_fc_sent;       // Update FC sent FM
tx_flit_struct            xdlh_fm_flit;
output  logic [P_NVC-1:0] xdlh_xtlh_fc_init_done; // XDLH indicates that FC init is done

// =============================================================================
// ---- internal signals ------
// =============================================================================
wire    [RBUF_PW -1:0]  xdlh_retryram_addr;           // Adrress to retry buffer RAM
wire    [RBUF_WD -1:0]  xdlh_retryram_data;           // Write data to retry buffer RAM
wire                    xdlh_retryram_we;             // Write enable to retry buffer RAM
wire                    xdlh_retryram_en;             // Read enable to retry buffer RAM
assign  xdlh_retryram_if.retryram_raddr = xdlh_retryram_addr;
assign  xdlh_retryram_if.retryram_waddr = xdlh_retryram_addr;
assign  xdlh_retryram_if.retryram_we = xdlh_retryram_we;
// zero pad to account for flit mode retry buffer Width this only applies in case of CX_NW > 16 where
// xdlh remains 512-bit while flit mode data path is 1024-bit
assign  xdlh_retryram_if.retryram_data = {{(`RBUF_WIDTH - RBUF_WD){1'b0}}, xdlh_retryram_data};
assign  xdlh_retryram_if.retryram_en = xdlh_retryram_en && !xdlh_retryram_we;
logic                   int_req2send_ack;
logic                   int_req2send_nack;
logic                   int_req2send_ack_due2dup;
logic   [11:0]          int_req_acknack_seqnum;
logic                   int_cfg_other_msg_req;
logic   [31:0]          int_cfg_other_msg_payload;
logic                   int_fc_req;
logic   [31:0]          int_fc_req_data;
logic                   int_fc_req_low;
dllp_struct             int_pm_dllp_req;

logic                   int_send_feature_dllp;
logic   [22:0]          int_cfg_local_feature_support;
logic                   int_cfg_dlink_feature_valid;
wire                    xdlh_in_reply;
wire    [DW-1:0]        tlp_data;               // tlp_data
wire    [NW-1:0]        tlp_dwen;               // tlp_data
wire    [NW-1:0]        tlp_sot;                // Start of TLP at DW location
wire    [NW-1:0]        tlp_eot;                // end of tlp, when asserted, indicates the end of tlp at DW location
wire    [NW-1:0]        dllp_sdp;               // DLLP Start at DW location
wire                    tlp_dllp_dv;
wire                    rbuf_replaying;
wire                    rbuf_halt;
wire                    rbuf_reply_req;         // a tlp will be replied
wire    [NW-1:0]        rbuf_xmt_sot;           // sot
wire                    rbuf_xmt_dv;
wire                    rbuf_xmt_done;
wire    [NW-1:0]        rbuf_xmt_eot;           // eot
wire    [NW-1:0]        rbuf_xmt_badeot;        // sot
wire    [DW_W_PAR-1:0]  rbuf_xmt_data;          // data
wire    [NW-1:0]        rbuf_xmt_dwen;          // dwen
wire    [11:0]          rbuf_xmt_seqnum;        // seqnum from retry buffer.

wire    [NW-1:0]        tlpgen_rbuf_sot;        // sot
wire                    tlpgen_rbuf_dv;
wire    [NW-1:0]        tlpgen_rbuf_eot;        // eot
wire    [NW-1:0]        tlpgen_rbuf_badeot;     // eot
wire                    tlpgen_reply_grant;
wire    [DW_W_PAR-1:0]  tlpgen_rbuf_data;       // data
wire    [NW-1:0]        tlpgen_rbuf_dwen;       // dword enable
wire    [11:0]          tlpgen_rbuf_seqnum;     // seqnum from retry buffer.
wire                    tlpgen_pkt_pending;
wire                    nak_scheduled;          // dllp generation block requests nak is scheduled to be transmitted
wire    [TX_NDLLP-1:0]  dllp_xmt_req;
wire                    dllp_req_low_prior;     // request to transmit a DLLP with low priority

wire    [(64*TX_NDLLP)-1:0] dllp_xmt_pkt_10b;
wire                        xdlh_rbuf_replaying; 
 
wire    [(64*TX_NDLLP)-1:0] dllp_xmt_pkt_130b;

wire                    xdctrl_dllp_halt1;

wire    [RBUF_PW : 0]   rbuf_entry_cnt;
wire    [11:0]          rbuf_pkt_cnt;
wire                    rbuf_block_new_tlp;
wire                    xdctrl_dllp_halt;
wire                    xdctrl_tlp_halt;
wire    [P_NW-1:0]      xdlh_dllp_sent;
wire    [P_NW-1:0]        xdlh_dllp_end;

wire                    smlh_in_l0_l0s_l1; 

wire [10:0]   rbuf_xdlh_tlp_len;
wire [10:0]   tlpgen_rbuf_len;
wire  xdlh_tlp_gen_halt;



// DLLP pending signal is generated in xdlh for power management purpose.
// According to spec, when there is no tlp and dllp to be transmitted, then
// nodllp_pending signal can be asserted.
// There are two conditions that we need to watch: 1. when tlp and dllp is
// not requesting at xdlh control block
// 2. when the ack is scheduled in dllp generation block, but it is not
// timeout to be transmitted yet. This is considered as a dllp pending
// condition
wire                    xdctrl_nodllp_pending;
wire                    xdlh_no_acknak_dllp_pending;
wire                    xdlh_nodllp_pending;
wire                    int_nodllp_pending;
// If SPIF is enabled then fill the pipeline only if the transmit path is enabled (reflected as smlh_in_l0 on XDLH interface)
assign smlh_in_l0_l0s_l1 = xdlh_protocol_cfg.spif_enable ? smlh_in_l0 : (smlh_in_l0 || smlh_in_l0s || smlh_in_l1);

wire   int_replay_timer_hold;
assign int_replay_timer_hold = xdlh_protocol_cfg.spif_enable ? xdlh_pl_stall_req : smlh_link_in_training;

dllp_struct     int_ven_msg_str;
dllp_struct     int_non_fm_ven_msg_str;
dllp_struct     int_fm_ven_msg_str;
dllp_struct     int_non_fm_fc_str;
dllp_struct     int_fm_fc_str;
dllp_struct     int_pm_dllp_str;
dllp_struct     int_non_fm_pm_dllp_str;
dllp_struct     int_fm_pm_dllp_str;
dllp_struct     int_fm_feature_dllp_str;
logic           int_fm_dllp_pending;
logic           int_fm_cdm_dllp_ack;
logic           int_fm_feature_dllp_ack;
logic           int_dllp_if_fc_ack;
logic           int_fm_dllp_gen_fc_ack;
logic           int_non_fm_dllp_gen_fc_ack;
logic           int_fm_opt_upd;
logic           xdlh_fm_halt;             // Back-pressure the upper layers
logic           xdlh_xplh_dllp_valid;
logic           int_flit_mode_enable;
logic           int_xplh_xdlh_dllp_halt;

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_mode_r_PROC
  if(!core_rst_n)
    int_flit_mode_enable  <= #TP 1'b0;
  else
    int_flit_mode_enable  <= #TP xplh_xdlh_cmd.flit_mode;
end : flit_mode_r_PROC


assign xdlh_nodllp_pending = int_flit_mode_enable ? !int_fm_dllp_pending : (xdctrl_nodllp_pending && xdlh_no_acknak_dllp_pending && int_nodllp_pending);

logic           xdlh_control_data_valid;  // Data valid indication
logic [DW-1:0]  xdlh_control_data;        // Merged TLP/DLLP Data
logic [NW-1:0]  xdlh_control_pad;         // Insert PAD symbols
logic [NW-1:0]  xdlh_control_sdp;         // Start DLP packet
logic [NW-1:0]  xdlh_control_stp;         // Start TLP packet
logic [NW-1:0]  xdlh_control_eot;         // End DLP or TLP packet
logic [NW-1:0]  xdlh_control_next_eot;    // End DLP or TLP packet
logic [NW-1:0]  xdlh_control_next_stp;    // Start  TLP on next packet
logic [NW-1:0]  xdlh_control_next_sdp;    // Start DLLP on next packet
logic           xdlh_control_pkt_pending; // TLP Pending to transmit

// XDLH Common Instantiates Logic which is shared between Flit Mode and Non Flit Mode
xdlh_common
 u_xdlh_common(
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .cfg_replay_timer_value   (cfg_replay_timer_value),
  .current_data_rate        (current_data_rate),
  .rdlh_link_up             (rdlh_link_up),
  .b_xdlh_replay            (b_xdlh_replay.slave_mp),
  .b_xdlh_replay_num        (b_xdlh_replay_num.slave_mp),
  .b_xdlh_retrain_cnt       (b_xdlh_retrain_cnt.slave_mp),
  .xdlh_replay_timeout      (xdlh_replay_timeout),
  .xdlh_replay_timer_value  (xdlh_replay_timer_value)
  ,
  .flit_mode_enable         (int_flit_mode_enable)
);

localparam RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN   = RAS_DP_PROT_CHK_ID_BASE_XDLH;
localparam RAS_DP_PROT_CHK_ID_BASE_XDLH_RETRY_BUF = RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN + 2;

localparam BLOCK_RAS_DP_PROT_CHK_N = 4;
ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0] ras_dp_err_log_from_checkers;

// RAS DP ERROR LOGGING ARRAY MAPPING
ras_dp_err_log_t [1:0] ras_dp_err_log_from_xdlh_tlp_gen;
ras_dp_err_log_t [1:0] ras_dp_err_log_from_xdlh_retry_buf;

assign ras_dp_err_log_from_checkers[1:0] = ras_dp_err_log_from_xdlh_tlp_gen;
assign ras_dp_err_log_from_checkers[3:2] = ras_dp_err_log_from_xdlh_retry_buf;

ras_dp_err_inj_t ras_dp_err_inj_to_checkers;

logic unused_out_ras_dp_wake_up;
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (BLOCK_RAS_DP_PROT_CHK_N),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr ( 
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (unused_out_ras_dp_wake_up),
    .in_ras_dp_err_inj  (ras_dp_err_inj),
    .out_ras_dp_err_inj (ras_dp_err_inj_to_checkers),
    .in_ras_dp_err_log  (ras_dp_err_log_from_checkers),
    .out_ras_dp_err_log (ras_dp_err_log)
);

xdlh_retrybuf
 #(
    .INST (INST)
    ,
    .RAS_DP_PROT_CHK_ID_BASE_XDLH_RETRY_BUF (RAS_DP_PROT_CHK_ID_BASE_XDLH_RETRY_BUF)
) u_xdlh_retrybuf(
    // -- inputs --
    .b_xdlh_replay              (b_xdlh_replay.master_mp),
    .b_xdlh_replay_num          (b_xdlh_replay_num.master_mp),
    .b_xdlh_retrain_cnt         (b_xdlh_retrain_cnt.master_mp),
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .smlh_link_in_training      (smlh_link_in_training),
    .rdlh_link_up               (rdlh_link_up),
    .replay_timer_hold          (int_replay_timer_hold),
    .tlpgen_rbuf_data           (tlpgen_rbuf_data),
//    .tlpgen_rbuf_dwen           (tlpgen_rbuf_dwen),
    .tlpgen_rbuf_seqnum         (tlpgen_rbuf_seqnum),
    .tlpgen_rbuf_dv             (tlpgen_rbuf_dv),
    .tlpgen_rbuf_sot_128        (tlpgen_rbuf_sot),
    .tlpgen_rbuf_eot_128        (tlpgen_rbuf_eot),
    .tlpgen_rbuf_badeot_128     (tlpgen_rbuf_badeot),
    .tlpgen_reply_grant         (tlpgen_reply_grant),

    .rbuf_halt                  (rbuf_halt     ),
    .rdlh_xdlh_rcvd_nack_org    (rdlh_xdlh_rcvd_nack),
    .rdlh_xdlh_rcvd_ack_org     (rdlh_xdlh_rcvd_ack),
    .rdlh_xdlh_rcvd_acknack_seqnum (rdlh_xdlh_rcvd_acknack_seqnum),
//    .external_retry_req         (1'b0),
//    .external_retry_addr        ({`RBUF_PW{1'b0}}),
    .rbuf_xdlh_tlp_len          (rbuf_xdlh_tlp_len),
    .tlpgen_rbuf_len            (tlpgen_rbuf_len),
    .cfg_rasdp_error_mode          (cfg_rasdp_error_mode),
    .ras_dp_err_log                (ras_dp_err_log_from_xdlh_retry_buf),
    .ras_dp_err_inj                (ras_dp_err_inj_to_checkers),
    .cdm_ras_des_force_linkdown_noack (cdm_ras_des_force_linkdown_noack),
    .cdm_ras_des_einj5_enable   (cdm_ras_des_einj5_enable),
    .cdm_ras_des_einj5_tlp_type (cdm_ras_des_einj5_tlp_type),
    // -- outputs --
    .rbuf_reply_req             (rbuf_reply_req),
    .rbuf_xmt_data              (rbuf_xmt_data),
 //   .rbuf_xmt_dwen              (rbuf_xmt_dwen),
    .rbuf_xmt_sot_128           (rbuf_xmt_sot),
    .rbuf_xmt_dv                (rbuf_xmt_dv),
    .rbuf_xmt_done              (rbuf_xmt_done),
    .rbuf_xmt_eot_128           (rbuf_xmt_eot),
    .rbuf_xmt_badeot_128        (rbuf_xmt_badeot),
    .rbuf_xmt_seqnum            (rbuf_xmt_seqnum),
    .rbuf_entry_cnt             (rbuf_entry_cnt),
    .rbuf_pkt_cnt               (rbuf_pkt_cnt),
    .rbuf_block_new_tlp         (rbuf_block_new_tlp),
    .xdlh_smlh_start_link_retrain (xdlh_smlh_start_link_retrain),
    .xdlh_rbuf_not_empty        (xdlh_retrybuf_not_empty),
    .xdlh_not_expecting_ack     (xdlh_not_expecting_ack),
    .xdlh_rdlh_last_xmt_seqnum  (xdlh_rdlh_last_xmt_seqnum),

    //.rbuf_waddr                 (),
    // Retry buffer external RAM interface
    .xdlh_retryram_addr            (xdlh_retryram_addr ), 
    .xdlh_retryram_data            (xdlh_retryram_data   ),
    .xdlh_retryram_we              (xdlh_retryram_we     ),
    .xdlh_retryram_en              (xdlh_retryram_en     ),
    .xdlh_retryram_halt            (xdlh_retryram_halt),
    .xdlh_retryram_par_chk_val     (xdlh_retryram_par_chk_val),
    .retryram_xdlh_data            (retryram_xdlh_data   ),
    .retryram_xdlh_depth           (retryram_xdlh_depth  ),
    .retryram_xdlh_parerr          (retryram_xdlh_parerr),

//   Performance change - 2p RAM I/F
//    .xdlh_retrysotram_addr              (xdlh_retrysotram_addr),
    .xdlh_retrysotram_waddr              (xdlh_retrysotram_waddr),
    .xdlh_retrysotram_raddr              (xdlh_retrysotram_raddr),    
    .xdlh_retrysotram_data         (xdlh_retrysotram_data),
    .xdlh_retrysotram_we           (xdlh_retrysotram_we),
    .xdlh_retrysotram_en           (xdlh_retrysotram_en),
    .xdlh_retrysotram_par_chk_val  (xdlh_retrysotram_par_chk_val),
    .retrysotram_xdlh_data         (retrysotram_xdlh_data),
    .retrysotram_xdlh_parerr       (retrysotram_xdlh_parerr),
    .retrysotram_xdlh_depth        (retrysotram_xdlh_depth),
    .xdlh_retry_req                (xdlh_retry_req)
    ,
    .xdlh_smlh_goto_detect         (xdlh_smlh_goto_detect)
    ,
    .xdlh_einj5_dup_evt            (xdlh_einj5_dup_evt)
    ,
    .xdlh_in_reply                 (xdlh_in_reply)
);


xdlh_control_128b

#(INST) u_xdlh_control(
    // -- inputs --
    .core_clk                          (core_clk),
    .core_rst_n                        (core_rst_n),
    .rdlh_link_up                      (rdlh_link_up),
    .current_data_rate                 (current_data_rate),
    .smlh_link_mode                    (smlh_link_mode),
//    .dllp_xmt_req                      (dllp_xmt_req),
//    .dllp_req_low_prior                (dllp_req_low_prior),
//    .dllp_xmt_pkt                      (dllp_xmt_pkt),

    .xmlh_xdlh_halt                    (b_xdlh_xplh_mux.halt_in),
    .tlpgen_pkt_pending                (tlpgen_pkt_pending),
    .smlh_in_l0_l0s_l1                 (smlh_in_l0_l0s_l1),
    .xmlh_cmd_is_data                  (b_xdlh_xplh_mux.cmd_is_data),
    .tlp_data                          (tlp_data),
    .tlp_dwen                          (tlp_dwen),
    .tlp_sot                           (tlp_sot),
    .tlp_eot                           (tlp_eot),
    .dllp_sdp                          (dllp_sdp),
    .tlp_dllp_dv                       (tlp_dllp_dv),
    .rbuf_replaying                    (rbuf_replaying),
    // -- outputs --
    .xdlh_control_dv                   (xdlh_control_data_valid),
    .xdlh_control_data                 (xdlh_control_data),
    .xdlh_control_stp                  (xdlh_control_stp),
    .xdlh_control_sdp                  (xdlh_control_sdp),
    .xdlh_control_eot                  (xdlh_control_eot),
    .xdlh_rbuf_replaying               (xdlh_rbuf_replaying),
    .xdlh_control_next_eot             (xdlh_control_next_eot),
    .xdlh_control_next_stp             (xdlh_control_next_stp),
    .xdlh_control_next_sdp             (xdlh_control_next_sdp),
    .xdlh_control_pad                  (xdlh_control_pad),
    .xdctrl_dllp_halt1                 (xdctrl_dllp_halt1),
    .xdctrl_tlp_halt                   (xdctrl_tlp_halt),
    .xdctrl_nodllp_pending             (xdctrl_nodllp_pending),
    .xdlh_control_pkt_pending          (xdlh_control_pkt_pending),
    .xdlh_xmt_pme_ack                  (xdlh_xmt_pme_ack),
    .xdlh_dllp_sent                    (xdlh_dllp_sent[NW-1:0])
    ,.xdlh_dllp_end                    (xdlh_dllp_end[NW-1:0])
);

// Protocol ID not driven at this level
assign b_xdlh_xplh_mux.pid = {P_NW{1'b0}};

xdlh_dllp_gen

#(INST) u_xdlh_dllp_gen(
    // -- inputs --
    .core_clk                           (core_clk),
    .core_rst_n                         (core_rst_n),
    .cfg_ack_freq                       (cfg_ack_freq),
    .cfg_ack_latency_timer              (cfg_ack_latency_timer),
    .cfg_acknack_disable                (cfg_acknack_disable),
    .cfg_flow_control_disable           (cfg_flow_control_disable),
    
    .rdlh_link_up                       (rdlh_link_up),
    .xdlh_block_dl_init                 (xdlh_block_dl_init),
    .xdlh_dl_active                     (xdlh_dl_active),

    .cfg_other_msg_request              (int_cfg_other_msg_req),
    .cfg_other_msg_payload              (int_cfg_other_msg_payload),

    .rtlh_xdlh_fc_req                   (int_fc_req),
    .rtlh_xdlh_fc_req_hi                (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low               (int_fc_req_low),
    .rtlh_xdlh_fc_data                  (int_fc_req_data),

    .rdlh_xdlh_req2send_ack             (int_req2send_ack),
    .rdlh_xdlh_req2send_ack_due2dup     (int_req2send_ack_due2dup),
    .rdlh_xdlh_req2send_nack            (int_req2send_nack),
    .rdlh_xdlh_req_acknack_seqnum       (int_req_acknack_seqnum),

    .pm_xdlh_dllp_req                   (int_pm_dllp_req),
    .pm_freeze_ack_timer                (pm_freeze_ack_timer),
    .current_data_rate                  (current_data_rate),

    .xdctrl_dllp_halt                   (xdctrl_dllp_halt),
    .xmlh_xdlh_halt                     (b_xdlh_xplh_mux.halt_in),
    .smlh_in_l0                         (smlh_in_l0),
    .smlh_in_l0s                        (smlh_in_l0s),
    .smlh_eq_pending                    (smlh_eq_pending),
    .cdm_ras_des_einj0_enable           (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_count            (cdm_ras_des_einj0_count),
    .cdm_ras_des_einj0_crc_type         (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj1_enable           (cdm_ras_des_einj1_enable),
    .cdm_ras_des_einj1_seq_type         (cdm_ras_des_einj1_seq_type),
    .cdm_ras_des_einj1_bad_seq          (cdm_ras_des_einj1_bad_seq),
    .cdm_ras_des_einj1_count            (cdm_ras_des_einj1_count),
    .cdm_ras_des_einj2_enable           (cdm_ras_des_einj2_enable),
    .cdm_ras_des_einj2_dllp_type        (cdm_ras_des_einj2_dllp_type),
    .smlh_in_rcvry                      (smlh_in_rcvry),
    .send_feature_dllp                  (int_send_feature_dllp),
    .cfg_local_feature_support          (int_cfg_local_feature_support),
    .cfg_dlink_feature_valid            (int_cfg_dlink_feature_valid),

    // -- outputs --
    .nak_scheduled                      (nak_scheduled),
    .dllp_xmt_req                       (dllp_xmt_req),
    .dllp_req_low_prior                 (dllp_req_low_prior),

    .dllp_xmt_pkt_130b                  (dllp_xmt_pkt_130b), 
    .dllp_xmt_pkt_10b                   (dllp_xmt_pkt_10b),

    .xdlh_rtlh_fc_ack                   (int_non_fm_dllp_gen_fc_ack),
    .xdlh_nodllp_pending                (int_nodllp_pending),
    .nodllp_pending                     (xdlh_no_acknak_dllp_pending)
    ,
    .xdlh_nak_sent                      (xdlh_nak_sent),
    .xdlh_ack_sent                      (xdlh_ack_sent),
    .xdlh_update_fc_sent                (xdlh_update_fc_sent)
    ,
    .xdlh_einj0_dllpcrc_evt             (xdlh_einj0_dllpcrc_evt),
    .xdlh_einj1_tx_dllp_snum_evt        (xdlh_einj1_tx_dllp_snum_evt),
    .xdlh_einj2_nak_evt                 (xdlh_einj2_nak_evt)
);

xdlh_tlp_gen_128b
 #(
    .INST (INST)
    ,
    .RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN (RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN)
) u_xdlh_tlp_gen (
    // -- inputs --
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .cfg_corrupt_crc_pattern    (cfg_corrupt_crc_pattern),
    .rdlh_link_up               (rdlh_link_up),
    .smlh_in_l0                 (smlh_in_l0),

    .current_data_rate          (current_data_rate),
    .cfg_rasdp_error_mode_en    (cfg_rasdp_error_mode_en),
    .cfg_rasdp_error_mode       (cfg_rasdp_error_mode),
    .xdlh_rasdp_error_mode      (xdlh_rasdp_error_mode),
    .ras_dp_err_log             (ras_dp_err_log_from_xdlh_tlp_gen),
    .ras_dp_err_inj             (ras_dp_err_inj_to_checkers),

    .xdctrl_tlp_halt            (xdctrl_tlp_halt),
    .xmlh_skip_pending          (b_xdlh_xplh_mux.skip_pending),
    .xdctrl_dllp_halt1          (xdctrl_dllp_halt1),
    .rbuf_reply_req             (rbuf_reply_req),
    .rbuf_xmt_dv                (rbuf_xmt_dv),
    .rbuf_xmt_done              (rbuf_xmt_done),
    .rbuf_xmt_sot               (rbuf_xmt_sot),
    .rbuf_xmt_eot               (rbuf_xmt_eot),
    .rbuf_xmt_badeot            (rbuf_xmt_badeot),

    .rbuf_xmt_data              (rbuf_xmt_data),
    .rbuf_xmt_seqnum            (rbuf_xmt_seqnum),
    .rbuf_entry_cnt             (rbuf_entry_cnt),
    .rbuf_pkt_cnt               (rbuf_pkt_cnt),
    .rbuf_block_new_tlp         (rbuf_block_new_tlp),

//    .rbuf_xmt_dwen              (rbuf_xmt_dwen),

//    .xtlh_xdlh_dwen             (xtlh_xdlh_dwen),

    .xtlh_xdlh_data             (xtlh_xdlh_data),
    .xtlh_xdlh_sot              (xtlh_xdlh_sot),
    .xtlh_xdlh_eot              (xtlh_xdlh_eot),
    .xtlh_xdlh_dv               (xtlh_xdlh_dv ),
    .xtlh_xdlh_badeot           (xtlh_xdlh_badeot),

    .xtlh_xdlh_tlp_len          (xtlh_xdlh_tlp_len),
    .rbuf_xdlh_tlp_len          (rbuf_xdlh_tlp_len),
    .lcrc_err_en                (lcrc_err_en),

    .dllp_xmt_pkt_130b          (dllp_xmt_pkt_130b),

    .dllp_xmt_pkt_10b           (dllp_xmt_pkt_10b),
    .dllp_xmt_req               (dllp_xmt_req),
    .dllp_req_low_prior         (dllp_req_low_prior),
    .xtlh_sot_is_first          (xtlh_sot_is_first),
    .xtlh_badeot                (xtlh_badeot),
    .xtlh_first_badeot          (xtlh_first_badeot), 
    .xtlh_eot_sot               (xtlh_eot_sot),
    .xtlh_eot_sot_eot           (xtlh_eot_sot_eot),
    .cdm_ras_des_einj0_enable   (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_count    (cdm_ras_des_einj0_count),
    .cdm_ras_des_einj0_crc_type (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj1_enable   (cdm_ras_des_einj1_enable),
    .cdm_ras_des_einj1_seq_type (cdm_ras_des_einj1_seq_type),
    .cdm_ras_des_einj1_bad_seq  (cdm_ras_des_einj1_bad_seq),
    .cdm_ras_des_einj1_count    (cdm_ras_des_einj1_count),
    .cdm_ras_des_einj5_enable   (cdm_ras_des_einj5_enable),
    .cdm_ras_des_einj5_count    (cdm_ras_des_einj5_count),
    .cdm_ras_des_einj5_tlp_type (cdm_ras_des_einj5_tlp_type),

    .lcrc_err_asserted                (lcrc_err_asserted),
    .xdlh_xtlh_halt             (xdlh_tlp_gen_halt),
    .rbuf_halt                  (rbuf_halt),
    .xdctrl_dllp_halt           (xdctrl_dllp_halt),
    .tlpgen_rbuf_data           (tlpgen_rbuf_data),
   // .tlpgen_rbuf_dwen           (tlpgen_rbuf_dwen),
    .tlpgen_rbuf_seqnum         (tlpgen_rbuf_seqnum),
    .tlpgen_rbuf_dv             (tlpgen_rbuf_dv),
    .tlpgen_rbuf_sot            (tlpgen_rbuf_sot),
    .tlpgen_rbuf_eot            (tlpgen_rbuf_eot),
    .tlpgen_rbuf_badeot         (tlpgen_rbuf_badeot),
    .tlpgen_reply_grant         (tlpgen_reply_grant),

    .tlpgen_rbuf_len            (tlpgen_rbuf_len),

    .tlp_data                   (tlp_data),
    .tlp_dwen                   (tlp_dwen),
    .tlp_sot                    (tlp_sot),
    .tlp_eot                    (tlp_eot),
    .dllp_sdp                   (dllp_sdp),
    .tlp_dllp_dv                (tlp_dllp_dv),
    .rbuf_replaying_out         (rbuf_replaying),
    .tlpgen_pkt_pending         (tlpgen_pkt_pending),

    .xdlh_curnt_seqnum          (xdlh_curnt_seqnum)
    ,
    .xdlh_einj0_lcrc_evt        (xdlh_einj0_lcrc_evt),
    .xdlh_einj0_fcrc_evt        (xdlh_einj0_fcrc_evt),
    .xdlh_einj1_tx_tlp_snum_evt (xdlh_einj1_tx_tlp_snum_evt),
    .xdlh_einj5_nultlp_evt      (xdlh_einj5_nultlp_evt)
);

wire          xdlh_ptm_sot;
wire          xdlh_ptm_multi_cycle;
wire          xdlh_ptm_request;
wire          xdlh_ptm_response;
wire [NW-1:0] xdlh_ptm_stp;
wire [DW-1:0] xdlh_ptm_data;

// -----------------------------------------------------------------
// Temporary fix for PTM to imitate register stage in XPLH for SPIF
// TBD: PTM to be revised in the context of SPIF Interface 
// -----------------------------------------------------------------
wire [NW-1:0] xplh_ptm_stp;
wire [DW-1:0] xplh_ptm_data;
wire          xdlh_ptm_halt;

assign xdlh_ptm_halt = !b_xdlh_spif.s_pl_trdy && xmlh_xplh_halt;

delay_n_w_enable
  #(
    .N          (1), 
    .WD         (NW+DW)
) u_xdlh_ptm_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (!xdlh_ptm_halt),
    .din        (b_xdlh_spif.s_pl_trdy ? {b_xdlh_spif.s_lp_tlp_start[NW-1:0], b_xdlh_spif.s_lp_data[DW-1:0]} : '0),
    .dout       ({xplh_ptm_stp, xplh_ptm_data})
);
// -----------------------------------------------------------------

assign xdlh_ptm_stp  = xdlh_protocol_cfg.spif_enable ? xplh_ptm_stp  : b_xdlh_xplh_mux.stp[NW-1:0];
assign xdlh_ptm_data = xdlh_protocol_cfg.spif_enable ? xplh_ptm_data : b_xdlh_xplh_mux.data_out[DW-1:0];

ptm_msg_decode
 u_ptm_msg_decode (
    // inputs
    .core_clk           (core_clk),
    .core_rst_n         (core_rst_n),
    .current_data_rate  (current_data_rate),
    .tlp_sot            (xdlh_ptm_stp),
    .tlp_data           (xdlh_ptm_data),
    .tlp_dv             (1'b1),
    .tlp_eot            (xplh_xmlh_eot),
    .tlp_error          (1'b0),
    .tlp_halt           (xmlh_xplh_halt),
    .xmlh_stp_start     (xmlh_stp_start),
    // outputs
    .ptm_sot            (xdlh_ptm_sot),
    .ptm_multi_cycle    (xdlh_ptm_multi_cycle),
    .ptm_request        (xdlh_ptm_request),
    .ptm_response       (xdlh_ptm_response)
);

// -----------------------------------------------------------------
// Track TLP's through the XDLH
// -----------------------------------------------------------------
wire int_clear_pending;
// pipelines are cleared when link goes down so reset the tracker
// If RASDP error mode is enabled clear the tracker
assign int_clear_pending = !rdlh_link_up || cfg_rasdp_error_mode;

// Tracker which includes SPIF/NON-SPIF TLP tracking.
// When legacy interface is deprecated this can be simplified to just use the SPIF tracker
xdlh_spif_tracker

  #(
    .NW     (NW),
    .SOT_WD (NW)
  ) u_xdlh_spif_tracker (
    // Inputs
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .xtlh_xdlh_sot          (xtlh_xdlh_sot),
    .xdlh_xtlh_halt         (xdlh_xtlh_halt),
    .xplh_xmlh_eot          (xplh_xmlh_eot),
    .xmlh_xplh_halt         (xmlh_xplh_halt),
    .xdlh_xmlh_dllp         (xdlh_dllp_sent[NW-1:0]),
    .rbuf_xmt_sot           (rbuf_xmt_sot),
    .rbuf_halt              (rbuf_halt),
    .clear_pending          (int_clear_pending),
    .xdlh_in_reply          (xdlh_in_reply),
    .xdlh_not_expecting_ack (xdlh_not_expecting_ack),
    .lp_valid               (b_xdlh_spif.s_lp_valid),
    .lp_irdy                (b_xdlh_spif.s_lp_irdy),
    .lp_tlp_end             (b_xdlh_spif.s_lp_tlp_end),
    .pl_trdy                (b_xdlh_spif.s_pl_trdy),
    .spif_enable            (xdlh_protocol_cfg.spif_enable),
    .xdlh_tlp_pending       (xdlh_tlp_pending),
    .xdlh_retry_pending     (xdlh_retry_pending)
);

logic int_xtlh_xdlh_cmd_ack_r;
logic int_xtlh_xdlh_cmd_ack;
logic int_xtlh_xdlh_cmd_done;

// Latch the acknowledge and forward to XPLH only when pending signals are low
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_xtlh_xdlh_cmd_ack_r <= #TP '0;
  else begin
    if(int_xtlh_xdlh_cmd_ack_r && !(xdlh_tlp_pending || xdlh_retry_pending))
      int_xtlh_xdlh_cmd_ack_r <= #TP '0;
    else if(xtlh_xdlh_cmd_ack)
      int_xtlh_xdlh_cmd_ack_r <= #TP '1;
  end
end
always_comb begin
  int_xtlh_xdlh_cmd_ack = '0;
  if(int_flit_mode_enable)
    int_xtlh_xdlh_cmd_ack = xtlh_xdlh_cmd_ack;
  else
    int_xtlh_xdlh_cmd_ack = (int_xtlh_xdlh_cmd_ack_r && !(xdlh_tlp_pending || xdlh_retry_pending));
end
// Propagate commands and acknowledge
assign xdlh_xtlh_cmd = xplh_xdlh_cmd;
assign xdlh_xplh_cmd_ack = int_xtlh_xdlh_cmd_ack;
// xtlh has acknowledged the cmd, pass to xdlh_fm_spif_datapath to signal that the stall_request can be acked if no pending signals
assign int_xtlh_xdlh_cmd_done = (xdlh_xtlh_cmd.tx_cmd == CMD_RESET) || (xdlh_xtlh_cmd.tx_cmd inside {CMD_FLUSH_XTLH, CMD_FLUSH_XAIM} && int_xtlh_xdlh_cmd_ack);

// Vendor and FC DLP Interfaces
always_comb begin : vend_fc_dllp_PROC
  // Non-flit mode vendor message interface
  int_cfg_other_msg_req = int_non_fm_ven_msg_str.valid;
  int_cfg_other_msg_payload = {int_non_fm_ven_msg_str.pyld, int_non_fm_ven_msg_str.dllp_type};
  int_ven_msg_str.pyld = cfg_other_msg_payload[31:8];
  int_ven_msg_str.dllp_type = dllp_type_e'(cfg_other_msg_payload[7:0]);
  int_ven_msg_str.valid = cfg_other_msg_request;
  // FC DLLP Interface
  int_fc_req = int_non_fm_fc_str.valid;
  int_fc_req_data = {int_non_fm_fc_str.pyld, int_non_fm_fc_str.dllp_type};
end : vend_fc_dllp_PROC

// PM DLLP Interface
assign int_pm_dllp_str.valid     = pm_xdlh_dllp_req.valid;
assign int_pm_dllp_str.dllp_type = cx_pl_pkg::dllp_type_e'(pm_xdlh_dllp_req.dllp_type);
assign int_pm_dllp_str.pyld      = 0;

assign int_pm_dllp_req.valid     = int_non_fm_pm_dllp_str.valid;
assign int_pm_dllp_req.dllp_type = cx_pl_pkg::dllp_type_e'(int_non_fm_pm_dllp_str.dllp_type);
assign int_pm_dllp_req.pyld = 24'b0;

// Vendor and FC DLP Interfaces
always_comb begin : feature_dllp_PROC
  if(int_flit_mode_enable) begin
    int_send_feature_dllp = 1'b0;
    int_cfg_local_feature_support = {23{1'b0}};
    int_cfg_dlink_feature_valid = 1'b0;
  end else begin
    int_send_feature_dllp = send_feature_dllp;
    int_cfg_local_feature_support = cfg_local_feature_support;
    int_cfg_dlink_feature_valid = cfg_dlink_feature_valid;
  end
end : feature_dllp_PROC

// -----------------------------------------------------------------
// DLLP Interface
// -----------------------------------------------------------------
xdlh_dllp_if
 u_xdlh_dllp_if (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk         (core_clk),
  .core_rst_n       (core_rst_n),
  // -------------------------------------------------------------------------------------
  // Flit Mode Interface
  // -------------------------------------------------------------------------------------
  .flit_mode        (int_flit_mode_enable),
  // -------------------------------------------------------------------------------------
  // Link Status Interface
  // -------------------------------------------------------------------------------------
  .xdlh_block_dl_init                 (xdlh_block_dl_init),
  .xdlh_dl_active                     (xdlh_dl_active),
  .smlh_eq_pending                    (smlh_eq_pending),
  // -------------------------------------------------------------------------------------
  // Ack/Nak DLLP Interface
  // -------------------------------------------------------------------------------------
  .rdlh_xdlh_req2send_ack             (rdlh_xdlh_req2send_ack),
  .rdlh_xdlh_req2send_nack            (rdlh_xdlh_req2send_nack),
  .rdlh_xdlh_req2send_ack_due2dup     (rdlh_xdlh_req2send_ack_due2dup),
  .rdlh_xdlh_req_acknack_seqnum       (rdlh_xdlh_req_acknack_seqnum),
  .xdlh_dllp_if_req2send_ack          (int_req2send_ack),
  .xdlh_dllp_if_req2send_nack         (int_req2send_nack),
  .xdlh_dllp_if_req2send_ack_due2dup  (int_req2send_ack_due2dup),
  .xdlh_dllp_if_req_acknack_seqnum    (int_req_acknack_seqnum),
  // -------------------------------------------------------------------------------------
  // Vendor Specific DLLP Interface 
  // -------------------------------------------------------------------------------------
  .cfg_other_msg_request              (int_ven_msg_str),
  .xdlh_fm_dllp_gen_other_msg_ack     (int_fm_cdm_dllp_ack),
  .xdlh_dllp_if_other_msg_request     (int_non_fm_ven_msg_str),
  .xdlh_dllp_if_fm_other_msg_request  (int_fm_ven_msg_str),
  // -------------------------------------------------------------------------------------
  // FC DLLP Interface
  // -------------------------------------------------------------------------------------
  .rtlh_xdlh_fc_req                   (rtlh_xdlh_fc_req),
  .rtlh_xdlh_fc_data                  (rtlh_xdlh_fc_data),
  .rtlh_xdlh_fc_req_low               (rtlh_xdlh_fc_req_low),
  .rtlh_xdlh_opt_upd                  (1'b0), // tie off to 0 optimized update DLLP interface for now
  .xdlh_dllp_gen_fc_ack               (int_non_fm_dllp_gen_fc_ack),
  .xdlh_fm_dllp_gen_fc_ack            (int_fm_dllp_gen_fc_ack),
  .xdlh_dllp_if_fc_req                (int_non_fm_fc_str),
  .xdlh_dllp_if_fm_fc_req             (int_fm_fc_str),
  .xdlh_dllp_if_fc_req_low            (int_fc_req_low),
  .xdlh_dllp_if_fm_opt_upd            (int_fm_opt_upd),
  .xdlh_dllp_if_fc_ack                (int_dllp_if_fc_ack),
  // -------------------------------------------------------------------------------------
  // PM DLLP Interface
  // -------------------------------------------------------------------------------------
  .pm_xdlh_dllp                       (int_pm_dllp_str),
  .xdlh_dllp_if_pm_dllp               (int_non_fm_pm_dllp_str),
  .xdlh_dllp_if_fm_pm_dllp            (int_fm_pm_dllp_str),
  .xdlh_dllp_if_pm_ack                (),
  .xdlh_dllp_gen_pm_ack               (1'b0),
  .xdlh_fm_dllp_gen_pm_ack            (1'b0),
  // -------------------------------------------------------------------------------------
  // DL FEATURE DLLP Interface
  // -------------------------------------------------------------------------------------
  .xdlh_fm_dllp_gen_feature_ack       (int_fm_feature_dllp_ack),
  .xdlh_dllp_if_feature_ack           (xdlh_rdlh_feature_ack),
  .send_feature_dllp                  (send_feature_dllp),
  .cfg_local_feature_support          (cfg_local_feature_support),
  .cfg_dlink_feature_valid            (cfg_dlink_feature_valid),
  .xdlh_dllp_if_fm_feature_dllp       (int_fm_feature_dllp_str)
);

// -----------------------------------------------------------------
// Flit Mode
// -----------------------------------------------------------------
xdlh_fm
 u_xdlh_fm (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  .core_clk                     (core_clk),
  .core_rst_n                   (core_rst_n),
  // -------------------------------------------------------------------------------------
  // XTLH Interface
  // -------------------------------------------------------------------------------------
  .xtlh_xdlh_flit               (xtlh_xdlh_flit),
  // -------------------------------------------------------------------------------------
  // XPLH Interface
  // -------------------------------------------------------------------------------------
  .xplh_xdlh_halt               (b_xdlh_xplh_mux.halt_in),
  .xplh_xdlh_dllp_halt          (int_xplh_xdlh_dllp_halt),
  .xdlh_fm_dllp_valid           (xdlh_xplh_dllp_valid),
  .xdlh_fm_dllp_out             (xdlh_xplh_dllp_out),
  .xplh_xdlh_cmd                (xplh_xdlh_cmd),
  // -------------------------------------------------------------------------------------
  // XDLH Interface
  // -------------------------------------------------------------------------------------
  .xdlh_fm_flit                 (xdlh_fm_flit),
  .xdlh_fm_halt                 (xdlh_fm_halt),
  // -------------------------------------------------------------------------------------
  // FC DLLP Interface
  // -------------------------------------------------------------------------------------
  .rtlh_fc_init_status          (rtlh_fc_init_status),
  .rtlh_xdlh_dllp               (int_fm_fc_str),
  .rtlh_xdlh_opt_upd            (int_fm_opt_upd),
  .xdlh_fm_rtlh_ack             (int_fm_dllp_gen_fc_ack),
  .xdlh_fm_fc_init_done         (xdlh_xtlh_fc_init_done), 
  .xdlh_upd_fc_sent             (xdlh_upd_fc_sent),
  // -------------------------------------------------------------------------------------
  // Power Management Interface
  // -------------------------------------------------------------------------------------
  .xdlh_fm_dllp_pending         (int_fm_dllp_pending), // DLLP Pending to be connected
  .pm_xdlh_dllp                 (int_fm_pm_dllp_str),
  .xdlh_fm_pm_ack               (int_fm_pm_ack),
  // -------------------------------------------------------------------------------------
  // Vendor Specific DLLP Interface
  // -------------------------------------------------------------------------------------
  .cdm_xdlh_dllp                (int_fm_ven_msg_str),
  .xdlh_fm_cdm_dllp_ack         (int_fm_cdm_dllp_ack),
  // -------------------------------------------------------------------------------------
  // DL Feature DLLP Interface
  // -------------------------------------------------------------------------------------
  .dl_feature_dllp              (int_fm_feature_dllp_str),
  .xdlh_fm_feature_dllp_ack     (int_fm_feature_dllp_ack),
  // -------------------------------------------------------------------------------------
  // L0P Interface
  // -------------------------------------------------------------------------------------
  .xdlh_l0p_dllp                (xdlh_l0p_dllp),
  .xdlh_dllp_l0p_ack            (xdlh_dllp_l0p_ack),
  .xplh_l0p_dllps_count         (xplh_l0p_dllps_count),
  // -------------------------------------------------------------------------------------
  // Rate Information 
  // -------------------------------------------------------------------------------------
  .current_data_rate            (current_data_rate)
);

// -------------------------------------------------------------------------------------
// XDLH Mux
// -------------------------------------------------------------------------------------
// MUX between flit mode and non-flit mode signals
always_comb begin : xdlh_mux_proc
  // In flit mode connect to the interface from xdlh_fm
  if (int_flit_mode_enable) begin
    b_xdlh_xplh_mux.data_valid = xdlh_fm_flit.data_valid;
    b_xdlh_xplh_mux.data_out = xdlh_fm_flit.data;
    b_xdlh_xplh_mux.sof = xdlh_fm_flit.sof;
    b_xdlh_xplh_mux.enf = xdlh_fm_flit.enf;
    b_xdlh_xplh_mux.eof = xdlh_fm_flit.eof;
    b_xdlh_xplh_mux.flit_tlp_dv = xdlh_fm_flit.tlp_dv;
    b_xdlh_xplh_mux.flit_type_s = xdlh_fm_flit.flit_type_s;
    b_xdlh_xplh_mux.pad = {NW{1'b0}};
    b_xdlh_xplh_mux.sdp = {NW{1'b0}};
    b_xdlh_xplh_mux.stp = {NW{1'b0}};
    b_xdlh_xplh_mux.eot = {NW{1'b0}};
    b_xdlh_xplh_mux.next_eot = {NW{1'b0}};
    b_xdlh_xplh_mux.next_stp = {NW{1'b0}};
    b_xdlh_xplh_mux.next_sdp = {NW{1'b0}};
    b_xdlh_xplh_mux.pkt_pending = '0;
    xdlh_xtlh_halt = xdlh_fm_halt;
    b_xdlh_xplh_mux.flit_prot = xdlh_fm_flit.flit_prot;
    b_xdlh_xplh_mux.ras_dp_err_inband_kbd = (cfg_rasdp_error_mode_en && xdlh_fm_flit.ras_dp_err_inband_kbd) || cfg_rasdp_error_mode;
  // In non-flit mode connect to the interface from xdlh
  end else begin
    b_xdlh_xplh_mux.sof = 1'b0;
    b_xdlh_xplh_mux.enf = 1'b0;
    b_xdlh_xplh_mux.eof = 2'b00;
    b_xdlh_xplh_mux.flit_tlp_dv = '0;
    b_xdlh_xplh_mux.data_valid = xdlh_control_data_valid;
    b_xdlh_xplh_mux.flit_type_s.err_inj_en = '0;
    b_xdlh_xplh_mux.flit_type_s.flit_type  = NOP;
    b_xdlh_xplh_mux.flit_prot = '0;
    b_xdlh_xplh_mux.ras_dp_err_inband_kbd = '0;
    b_xdlh_xplh_mux.data_out = xdlh_control_data;
    b_xdlh_xplh_mux.pad = xdlh_control_pad;
    b_xdlh_xplh_mux.sdp = xdlh_control_sdp;
    b_xdlh_xplh_mux.stp = xdlh_control_stp;
    b_xdlh_xplh_mux.eot = xdlh_control_eot;
    b_xdlh_xplh_mux.next_eot = xdlh_control_next_eot;
    b_xdlh_xplh_mux.next_stp = xdlh_control_next_stp;
    b_xdlh_xplh_mux.next_sdp = xdlh_control_next_sdp;
    b_xdlh_xplh_mux.pkt_pending = xdlh_control_pkt_pending;
    xdlh_xtlh_halt = xdlh_tlp_gen_halt;
  end
end : xdlh_mux_proc

assign xdlh_rtlh_fc_ack = int_dllp_if_fc_ack;



// -------------------------------------------------------------------------------------
// XDLH to XPLH SPIF Interface 
// -------------------------------------------------------------------------------------
xdlh_fm_spif_aligner
 u_xdlh_fm_spif_aligner (
    // -- interfaces --
    .b_xdlh_xplh             ( b_xdlh_xplh_mux.slave_mp      ),
    .b_xdlh_xplh_arbmux      ( b_xdlh_xplh_mp                ),
    .b_xdlh_spif             ( b_xdlh_spif                   ),
    // -- inputs --
    .core_clk                ( core_clk                      ),
    .core_rst_n              ( core_rst_n                    ),
    .xdlh_protocol_cfg       ( xdlh_protocol_cfg             ),
    .xdlh_xplh_dllp_end      ( xdlh_dllp_end                 ),
    .xdlh_pm_state_req       ( xdlh_pm_state_req             ),
    .xdlh_xplh_dllp_pending  ( int_fm_dllp_pending           ),
    .xdlh_xplh_dllp_valid    ( xdlh_xplh_dllp_valid          ),
    .xdlh_xplh_dllp_ofc      ( xdlh_xplh_dllp_out.opt_upd_fc ),
    .xdlh_xplh_dllp_data     ( {xdlh_xplh_dllp_out.pyld, xdlh_xplh_dllp_out.dllp_type} ),
    .xplh_xdlh_dllp_halt     ( xplh_xdlh_dllp_halt           ),
    .xtlh_xdlh_cmd_done      ( int_xtlh_xdlh_cmd_done        ),
    .xdlh_pl_stall_req       ( xdlh_pl_stall_req             ),
    // -- outputs --
    .xplh_xdlh_dllp_halt_out ( int_xplh_xdlh_dllp_halt       ),
    .xdlh_lp_stall_ack       ( xdlh_lp_stall_ack             )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// DLLP Acknowledge for PM Protocol FSM
// -------------------------------------------------------------------------------------
dllp_struct                 int_nfm_pm_dllp_ack;
dllp_struct                 int_det_pm_dllp_ack;
dllp_struct                 int_pm_dllp_ack;

// Instantiate DLLP Decoder for PCIe non-Flit Mode
xplh_pm_dllp_decoder
 u_det_pm_dllp (
    //Inputs
    .clk                (core_clk                         ),
    .rst_n              (core_rst_n                       ),
    .cfg_upstream_port  (cfg_upstream_port                ),
    .halt               (!b_xdlh_spif.s_pl_trdy           ),
    .data               (b_xdlh_spif.s_lp_data            ),
    .sdp                (b_xdlh_spif.s_lp_dlp_start       ),
    .eot                (b_xdlh_spif.s_lp_dlp_end         ),
    .current_data_rate  (current_data_rate                ),
    // Disable Flit Mode interface to DLLP decoder
    .flit_halt          ('1                               ),
    .flit_data          ('0                               ),
    .flit_mode_en       (xdlh_protocol_cfg.pcie_flit_mode ),
    .eof                ('0                               ),
    .sof                ('0                               ),
    //Outputs
    .xplh_pm_dllp_ack   (int_nfm_pm_dllp_ack              )
);

always_comb begin
  int_det_pm_dllp_ack = int_nfm_pm_dllp_ack;
  if (xdlh_protocol_cfg.pcie_flit_mode) begin
    if (b_xdlh_spif.s_pl_dllp_trdy) begin
      int_det_pm_dllp_ack.valid     = b_xdlh_spif.s_lp_dllp_valid;
      int_det_pm_dllp_ack.dllp_type = dllp_type_e'(b_xdlh_spif.s_lp_dllp_data[7:0]);
      int_det_pm_dllp_ack.pyld      = b_xdlh_spif.s_lp_dllp_data[31:8];
    end else begin
      int_det_pm_dllp_ack = '0;
    end
  end
end

// DLLP Acknowledges to the PM Block are gated by their corresponding requests
always_comb begin : pm_dllp_ack_PROC
  int_pm_dllp_ack = '0;
  if(pm_xdlh_dllp_req.valid) begin
    if(!cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_REQUEST_ACK)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_REQUEST_ACK));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_REQUEST_ACK : NOP2_DLLP;
    end else if(cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_ENTER_L1)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_ENTER_L1));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_ENTER_L1 : NOP2_DLLP;
    end else if(cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_ENTER_L23)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_ENTER_L23));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_ENTER_L23 : NOP2_DLLP;
    end else if(cfg_upstream_port && (pm_xdlh_dllp_req.dllp_type == PM_ACTIVE_STATE_REQUEST_L1)) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == PM_ACTIVE_STATE_REQUEST_L1));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? PM_ACTIVE_STATE_REQUEST_L1 : NOP2_DLLP; 
    end else if(pm_xdlh_dllp_req.dllp_type == NOP_DLLP) begin
      int_pm_dllp_ack.valid = (int_det_pm_dllp_ack.valid && (int_det_pm_dllp_ack.dllp_type == NOP_DLLP));
      int_pm_dllp_ack.dllp_type = int_pm_dllp_ack.valid ? NOP_DLLP: NOP2_DLLP;
    end else
      int_pm_dllp_ack = '0;
  end
end : pm_dllp_ack_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    xdlh_pm_dllp_ack  <= #TP '0;
  else
    xdlh_pm_dllp_ack  <= #TP int_pm_dllp_ack;
end
// -------------------------------------------------------------------------------------



endmodule

