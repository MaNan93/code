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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_flit_seq_num.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Flit Sequence Number
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module rplh_flit_seq_num
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_CFG_IDLE;
import DWC_pcie_core_pkg::S_RCVRY_IDLE;
import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
import cx_pl_pkg::rplh_xplh_fm_retry_t;
import cx_pl_pkg::replay_cmd_t;
import cx_pl_pkg::E_IDLE;
import cx_pl_pkg::E_STORE;
import cx_pl_pkg::E_PROCESS;
import cx_pl_pkg::E_PURGE;
import cx_pl_pkg::REPLAY_00;
import cx_pl_pkg::ACK;
import cx_pl_pkg::NAK_10;
import cx_pl_pkg::NAK_11;
import spif_pkg::stream_id_e;
import spif_pkg::SID_RSVD;
import spif_pkg::SID_PCIE;
import spif_pkg::SID_ALMP;
import spif_pkg::SID_CXL_IO;
import spif_pkg::SID_CXL_CM;
import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
parameter   REGOUT_EN               = `CX_RPLH_FLIT_SEQ_NUM_PIPE,                 // Pipeline enabled

parameter   FLIT_WD                 = 2048,                                       // Full Flit width in bit
parameter   FLIT_PROT_WD            = FLIT_WD/32*`CX_RAS_DWORD_PROT_WD,           // Full Flit Protection bits

parameter   FLIT_DATA_WD            = FLIT_WD - (14*8),                           // Flit Width less FEC and CRC bytes (in bits)
parameter   FLIT_DATA_PROT_WD       = `CX_RAS_FLIT_PROT_WD,                       // Flit Width less FEC and CRC bytes Protection bits
parameter   FLIT_DATA_W_PROT        = FLIT_DATA_WD + FLIT_DATA_PROT_WD,           // Flit Width less FEC and CRC bytes with protection bits

parameter   FLIT_TLP_WD             = FLIT_WD - (20*8),                           // Only TLP bytes (in bits)
parameter   FLIT_TLP_PROT_WD        = FLIT_TLP_WD/32*`CX_RAS_DWORD_PROT_WD,       // Only TLP bytes Protection bits
parameter   FLIT_TLP_W_PROT         = FLIT_TLP_WD + FLIT_TLP_PROT_WD,             // Only TLP bytes with protection bits

parameter   TP                      = `TP                                         // Clock to Q delay (simulator insurance)
)

                        (
// ---- inputs ---------------
input                           core_clk,
input                           core_rst_n,
input  [FLIT_DATA_W_PROT-1:0]   rxflit_data,                  // received data
input                           rxflit_dv,                    // received data is valid this cycle
input                           rxflit_err,                   // received data has uncorrectable errors
input  ltssm_state_e            smlh_ltssm_state,             // Current LTSSM state. 
input                           smlh_block_dl_init,           // SPIF: Indication from the LogPHY to block Initialization of DLLPs
input                           cxl_mode_enable,              // CXL Mode is enabled
input                           cfg_upstream_port,            // Upstream port when it is high
output                          rplh_ptm_sot,                 // indicate to PTM logic a PTM Flit is observed
output                          rplh_ptm_request,             // observed PTM request
output                          rplh_ptm_response,            // observed PTM response
output                          rplh_ptm_duplicate,           // observed PTM message in duplicate flit
input                           cfg_acknack_disable,          // Prevent sending of ack/nak packetsw
input                           cdm_ras_des_einj2_enable,     // Error injection 2 enable
input   [1:0]                   cdm_ras_des_einj2_dllp_type,  // Error injection 2 DLLP type

// ---- outputs ---------------
output stream_id_e              rplh_flit_stream,             // Protocol Stream ID on LPIF Interface
output                          rplh_fm_cxl_rcvd_flit,        // error in first almp detected, enable transmitter to send Nak
output                          rplh_flit_dv,                 // received data is valid this cycle
output logic [FLIT_WD-1:0]      rplh_flit_data,               // Full received flit
output logic [FLIT_PROT_WD-1:0] rplh_flit_data_prot,          // Full received flit Protection bits
output                          rplh_flit_nullified,          // marks whether this flit contains a nullified TLP
output                          rplh_flit_poisoned,           // marks whether this flit contains a poisoned TLP
output [1:0]                    rplh_flit_rcvd_idle,          // RMLH block keeps track of the number of consecutive IDLE flits.
                                                              // Bit 0 indicates 2 continous IDLE flits received, bit 1 indicates 1 IDLE flit received
output reg                      rplh_flit_dl_prot_err,        // Data Link Protocol Error ( Reserved fields or Invalid SeqNum )
output                          rplh_unrecognized_flit,       // Unrecognised flit flag when flit usage field has reserved encoding
output reg [31:0]               rplh_rdlh_fm_dllp_data,       // DLLP data extracted from DL bytes
output reg                      rplh_rdlh_fm_dllp_valid,      // Valid DLLP data
output reg                      rplh_rdlh_fm_dllp_opt_fc_up,  // DLLP is an Optimized FC update
output [9:0]                    rplh_implicit_rx_flit_seq_num,// Implicit Flit Sequence Number of received Flits
output rplh_xplh_fm_retry_t     rplh_xplh_fm_retry            // RPLH to XPLH Flit Mode Retry Interface
);

// ============================================================
// Local Parameters
// ============================================================
localparam REGOUT_WD = FLIT_DATA_WD + FLIT_DATA_PROT_WD;
// Maximum unacknowledged Flits
localparam  MAX_UNACKNOWLEDGED_FLITS  = `CX_MAX_UNACKNOWLEDGED_FLITS;
localparam bit PARITY_MODE = `CX_RAS_PARITY_MODE;


// ============================================================
// Declarations 
// ============================================================
wire [FLIT_DATA_WD-1:0]  rxflit_data_s;
wire [REGOUT_WD-1:0]     rxflit_data_r; // RPLH Flit Data Output Register
// Re-arrange CXL flit fields to match PCIe flit format
// CXL Format : 2B FlitHdr (DLP0-DLP1), 236B Payload, 4B DLLP (DLP2-DLP5)
// PCIe Format: 236B Payload, 6B DLLP (DLP0-DLP5)
assign rxflit_data_s = cxl_mode_enable ? {rxflit_data[238*8+:4*8], rxflit_data[0+:2*8], rxflit_data[2*8+:236*8]} : rxflit_data[FLIT_DATA_WD-1:0];

wire [236*8-1:0] tlp_bytes;
wire [  6*8-1:0] dlp_bytes;
wire [31:0] dllp_data;
wire [7:0] dlp5, dlp4, dlp3, dlp2, dlp1, dlp0;
assign {dlp_bytes, tlp_bytes} = rxflit_data_s;
assign {dlp5, dlp4, dlp3, dlp2, dlp1, dlp0} = dlp_bytes;
assign dllp_data      = {dlp5, dlp4, dlp3, dlp2};

typedef enum {
  IDLE_FLIT_HS,     // IDLE Flit handshake
  FLIT_SEQ_NUM_HS,  // Sequence Number handshake
  NORMAL            // Payload Flits
} rplh_state_t;
rplh_state_t next_state, state_r;

typedef enum logic {
    STANDARD_NAK  = 1'b0,
    SELECTIVE_NAK = 1'b1
} nak_type_t;

typedef enum logic [1:0] {
    IDLE_NOP   = 2'b00, // PCIe mode: IDLE Flit or NOP Flit CXL mode: Physical Layer IDLE or flit
    PAYLOAD    = 2'b01, // PCIe mode: PAYLOAD; CXL mode: CXL.io or CXL.io NOP flit
    CXL_CM     = 2'b10, // CXL.cachemem or CXL.cachemem NOP flit
    CXL_ALMP   = 2'b11  // ALMP
} flit_usage_t;

typedef enum logic {
    PRIOR_IDLE_NOP = 1'b0,
    PRIOR_PAYLOAD  = 1'b1
} prior_flit_payld_t;

typedef enum logic {
    DLLP        = 1'b0,
    FMARK_FCUPD = 1'b1
} type_dllp_payld_t;

typedef struct packed {
    flit_usage_t       flit_usage;
    prior_flit_payld_t prior_flit_payld;
    type_dllp_payld_t  type_dllp_payld;
    replay_cmd_t       replay_cmd;
    logic [9:0]        seqnum; 
} flit_t;

flit_t rcvd_flit;
assign rcvd_flit = {dlp0, dlp1};

wire valid_flit;
wire valid_idle_flit;
wire valid_non_idle_flit;
wire valid_nop_flit;
wire valid_payload_flit;
wire invalid_flit;
wire unrecognized_flit;
wire reserved_encoding;
wire dl_prot_err; // Logged as Data Link Protocol Error
reg  invalid_seqnum_0;
wire valid_io_flit;     // TLP : PCIe mode: PAYLOAD; CXL mode: CXL.io flit
wire valid_nop_io_flit; // DLLP: PCIe mode: NOP or PAYLOAD flit; CXL mode: CXL.io NOP or CXL.io flit


assign valid_flit          = rxflit_dv && !invalid_flit;

assign valid_idle_flit     = valid_flit && rcvd_flit.flit_usage==IDLE_NOP && !(|dlp_bytes);

assign valid_non_idle_flit = valid_flit && !valid_idle_flit; // NOP or PAYLOAD Flit

assign valid_nop_flit      = valid_flit && (rcvd_flit.flit_usage==IDLE_NOP) && (|dlp_bytes);

assign valid_payload_flit  = valid_flit && ( (cxl_mode_enable) ? (rcvd_flit.flit_usage inside {PAYLOAD, CXL_CM, CXL_ALMP}) : (rcvd_flit.flit_usage==PAYLOAD));

assign valid_io_flit       = valid_flit && (rcvd_flit.flit_usage==PAYLOAD);

assign valid_nop_io_flit   = ( (rcvd_flit.flit_usage==IDLE_NOP) && valid_nop_flit) || valid_io_flit;

assign unrecognized_flit = !cxl_mode_enable && rcvd_flit.flit_usage inside {CXL_CM, CXL_ALMP}                                                       || // Reserved Flit Usage
                           ((cxl_mode_enable) ? rcvd_flit.flit_usage==PAYLOAD : 1'b1) && rcvd_flit.type_dllp_payld==FMARK_FCUPD && dlp2[7:5]==3'b111;  // Reserved Flit Status in a Flit_Marker
assign reserved_encoding = unrecognized_flit || rcvd_flit.flit_usage==IDLE_NOP && (|tlp_bytes);

assign invalid_flit = rxflit_dv &&  (rxflit_err || reserved_encoding ); // CRC error after performing the FEC correction or Flit errors 

assign dl_prot_err = reserved_encoding || // Reserved Flit Usage
                     invalid_seqnum_0  ;  // IDLE/NOP Flit with non-NOP TLPs

wire flit_nullified, flit_poisoned;
wire int_flit_nullified, int_flit_poisoned;
assign flit_nullified  = valid_nop_io_flit && rcvd_flit.type_dllp_payld==FMARK_FCUPD && dlp2[7:5]==3'b101;   // flit marker and flit status equals nullified  
assign flit_poisoned   = valid_nop_io_flit && rcvd_flit.type_dllp_payld==FMARK_FCUPD && dlp2[7:5]==3'b110;   // flit marker and flit status equals poisoned

logic         rx_retry_buffer_full; 
logic         rx_retry_buffer_busy;
logic         rx_retry_buffer_empty;
assign rx_retry_buffer_full = 1;
assign rx_retry_buffer_busy = 1'b0;
assign rx_retry_buffer_empty = 1'b1;


// FSM support signals
wire enter_idle_flit_hs;
wire enter_seq_num_hs;
wire enter_normal_phase;


// Retry Mechanism 
logic [9:0] tx_acknak_flit_seq_num,                // stores the Sequence Number to be transmitted in the next Ack Flit or Nak Flit.
            tx_acknak_flit_seq_num_r;
logic [9:0] next_expected_rx_flit_seq_num,         // 10-bit Counter that stores the expected Flit Sequence Number of the next valid non-IDLE non-duplicate Flit to be received.
            next_expected_rx_flit_seq_num_r; 
logic [9:0] implicit_rx_flit_seq_num,              // 10-bit Counter that tracks the implicit Flit Sequence Number of received Flits.
            implicit_rx_flit_seq_num_r;
logic       non_idle_explicit_seq_num_flit_rcvd,   // flag to indicate that a Non-IDLE Explicit Sequence Number Flit has been received since the last entry to IDLE Flit Handshake Phase.
            non_idle_explicit_seq_num_flit_rcvd_r;
logic       nak_scheduled,                         // Flag to indicate that a Nak Flit has been scheduled for transmission.
            nak_scheduled_r;
nak_type_t  nak_scheduled_type,                    // Indicates whether a Standard Nak Flit or a Selective Nak Flit should be sent
            nak_scheduled_type_r;
logic       nak_withdrawal_allowed,                // flag to indicate that a scheduled or outstanding Nak may be withdrawn if the Flit that was Nak'd was a NOP Flit.
            nak_withdrawal_allowed_r;
logic [9:0] next_rx_flit_seq_num_to_store,         // stores the Flit Sequence Number of the next Flit to be stored in the RX Retry Buffer. Cleared when in DL_Inactive state.
            next_rx_flit_seq_num_to_store_r;
logic       rx_retry_buffer_overflow,              // flag to indicate that a Flit was unable to be stored in the RX Retry Buffer due to the buffer becoming full before a Selective Replay was received for an outstanding Selective Nak.
            rx_retry_buffer_overflow_r;
logic [9:0] rx_retry_buffer_last_flit_seq_num,     // stores the Flit Sequence Number of the last Flit stored in the RX Retry Buffer if the RX Retry Buffer overflows
            rx_retry_buffer_last_flit_seq_num_r;

logic       discard_tlp_bytes, discard_tlp_bytes_r;             
logic       discard_dlp_bytes, discard_dlp_bytes_r;             
logic       duplicate_sequence_number; 
logic       bad_sequence_number;
logic       bad_nop_sequence_number;

always_comb begin : implicit_rx_flit_seq_num_PROC
    implicit_rx_flit_seq_num = implicit_rx_flit_seq_num_r;
    if (valid_idle_flit                                                                      || // An IDLE Flit is received.
        rcvd_flit.replay_cmd==REPLAY_00 && rcvd_flit.seqnum==0                               || // An Explicit Sequence Number Flit is received with Flit Sequence Number 0
        !non_idle_explicit_seq_num_flit_rcvd &&                                                 // NON_IDLE_EXPLICIT_SEQ_NUM_FLIT_RCVD is 0b AND
          (invalid_flit ||                                                                      //   An invalid Flit is received OR 
          valid_flit && rcvd_flit.replay_cmd!=REPLAY_00)                                     || //   A valid non-Explicit Sequence Number Flit is received
        valid_nop_flit & rcvd_flit.replay_cmd!=REPLAY_00 &&                                     // A valid NOP Flit is received with a non-explicit Flit Sequence Number AND
          (!nak_withdrawal_allowed_r ||                                                         //   NAK_WITHDRAWAL_ALLOWED is 0b OR
          nak_withdrawal_allowed_r && rcvd_flit.prior_flit_payld==PRIOR_PAYLOAD)             || //   NAK_WITHDRAWAL_ALLOWED is 1b and Prior Flit was Payload is 1b
        valid_payload_flit && !non_idle_explicit_seq_num_flit_rcvd &&                           // A valid Payload Flit with a non-explicit Flit Sequence Number is received AND
          nak_withdrawal_allowed_r && rcvd_flit.prior_flit_payld==PRIOR_IDLE_NOP                //   NAK_WITHDRAWAL_ALLOWED is 1b AND Prior Flit was Payload is 0b
        )
        implicit_rx_flit_seq_num = implicit_rx_flit_seq_num_r;
    else if (
        non_idle_explicit_seq_num_flit_rcvd &&                                                   // NON_IDLE_EXPLICIT_SEQ_NUM_FLIT_RCVD is 1b AND
          (valid_payload_flit && rcvd_flit.replay_cmd!=REPLAY_00 && !nak_withdrawal_allowed_r || //   A valid Payload Flit with a non-explicit Flit Sequence Number is received and NAK_WITHDRAWAL_ALLOWED is 0b OR
           valid_payload_flit && rcvd_flit.replay_cmd!=REPLAY_00 &&                              //   A valid Payload Flit with a non-explicit Flit Sequence Number is received (cont)
             rcvd_flit.prior_flit_payld==PRIOR_PAYLOAD &&  nak_withdrawal_allowed_r ||           //     with Prior Flit was Payload set to 1b and NAK_WITHDRAWAL_ALLOWED is 1b OR
           invalid_flit)                                                                         //   A invalid Flit is received
        )
        implicit_rx_flit_seq_num = seqnum_plus_one(implicit_rx_flit_seq_num_r);    
    else if (valid_non_idle_flit && rcvd_flit.replay_cmd==REPLAY_00 && rcvd_flit.seqnum!=0)    // A valid non-IDLE Explicit Sequence Number Flit is received with Flit Sequence Number N AND N!=0
        implicit_rx_flit_seq_num = rcvd_flit.seqnum;
    else if (
        valid_nop_flit && rcvd_flit.replay_cmd!=REPLAY_00 &&  // A valid NOP Flit with a non-explicit Flit Sequence Number is received AND
        nak_withdrawal_allowed_r                          &&  // NAK_WITHDRAWAL_ALLOWED is 1b AND
        rcvd_flit.prior_flit_payld==PRIOR_IDLE_NOP)           // Prior Flit was Payload is 0b
        implicit_rx_flit_seq_num = seqnum_minus_one(implicit_rx_flit_seq_num_r);    
end : implicit_rx_flit_seq_num_PROC

assign rplh_implicit_rx_flit_seq_num = implicit_rx_flit_seq_num;

// If there is no space in the rx retry buffer the current implementation switches to standard nak, which is 1 of the options
// allowed by the spec. In this case RULE_NAK_SCHEDULE_5 is not required.
typedef enum {
  RULE_NAK_SCHEDULE_0,
  RULE_NAK_SCHEDULE_1,
  RULE_NAK_SCHEDULE_2,
  RULE_NAK_SCHEDULE_3,
  RULE_NAK_SCHEDULE_4,
  RULE_NAK_SCHEDULE_5,
  RULE_NAK_SCHEDULE_6,
  RULE_NAK_SCHEDULE_7,
  RULE_ACK_SCHEDULE_0,
  RULE_ACK_SCHEDULE_1,
  RULE_ACK_SCHEDULE_2,
  RULE_FLIT_DISCARD_0,
  RULE_FLIT_DISCARD_1,
  RULE_FLIT_DISCARD_2,
  RULE_SNPS_WITHDRAW_NAK_1,
  RULE_SNPS_WITHDRAW_NAK_2,
  RULE_SNPS_NAK_SCHEDULE_0,
  RULE_SNPS_ACK_SCHEDULE_0,
  RULE_IDLE_FLIT_HS,
  RULE_INVALID
} seqnum_rules_t;

seqnum_rules_t seqnum_rule;
seqnum_rules_t standard_nak_procedure;
seqnum_rules_t selective_nak_procedure;

always_comb begin : ack_nak_discard_PROC
    seqnum_rule = RULE_INVALID;
    nak_withdrawal_allowed = nak_withdrawal_allowed_r;
    nak_scheduled = nak_scheduled_r;
    tx_acknak_flit_seq_num = tx_acknak_flit_seq_num_r;
    nak_scheduled_type = nak_scheduled_type_r;
    next_expected_rx_flit_seq_num    = next_expected_rx_flit_seq_num_r;
    discard_tlp_bytes = 1'b0;
    discard_dlp_bytes = 1'b0;
    next_rx_flit_seq_num_to_store = next_rx_flit_seq_num_to_store_r;
    rx_retry_buffer_overflow = rx_retry_buffer_overflow_r;
    rx_retry_buffer_last_flit_seq_num = rx_retry_buffer_last_flit_seq_num_r;
    invalid_seqnum_0 = 0;
    if (next_state==IDLE_FLIT_HS || non_idle_explicit_seq_num_flit_rcvd==1'b0) begin
        // in IDLE Flit Handshake Phase all received Flits are discarded.
        discard_tlp_bytes = 1'b1;
        discard_dlp_bytes = 1'b1;
        seqnum_rule = RULE_IDLE_FLIT_HS;
    end else begin
        // Invalid Flit Handling
        if (invalid_flit) begin
            if (nak_scheduled_r == 1) begin
                if (nak_scheduled_type_r == STANDARD_NAK) begin
                    seqnum_rule = RULE_FLIT_DISCARD_1;
                end else begin
                    seqnum_rule = RULE_NAK_SCHEDULE_6;
                end
            end else begin
                if (nak_withdrawal_allowed_r == 1) begin
                    seqnum_rule = RULE_NAK_SCHEDULE_1;
                end else begin
                    seqnum_rule = RULE_NAK_SCHEDULE_0;
                end
            end
        end
        // Valid Flit Handling
        if (valid_flit) begin
            if (rcvd_flit.replay_cmd==REPLAY_00 && rcvd_flit.seqnum==0) begin
                seqnum_rule = RULE_FLIT_DISCARD_2;
            end
            else if (nak_withdrawal_allowed_r == 1) begin
                nak_withdrawal_allowed = 1'b0;
                if (rcvd_flit.prior_flit_payld==PRIOR_PAYLOAD) begin
                    if (valid_nop_flit) begin
                        // Schedule a Standard or Selective Nak
                        nak_scheduled = 1'b1;
                        tx_acknak_flit_seq_num = seqnum_minus_one(next_expected_rx_flit_seq_num_r);
                        nak_scheduled_type = STANDARD_NAK;
                        seqnum_rule = RULE_SNPS_NAK_SCHEDULE_0;
                        // next_expected_rx_flit_seq_num does not change
                        discard_tlp_bytes = 1'b1;
                    end
                    // Current Flit is Payload Flit
                    else begin
                        // Schedule a Standard Nak
                        if (1) begin
                            seqnum_rule = standard_nak_procedure;
                        end
                        // Schedule a Selective Nak
                        else begin
                            next_rx_flit_seq_num_to_store = seqnum_plus_one(next_expected_rx_flit_seq_num_r);
                            seqnum_rule = selective_nak_procedure;
                        end
                    end
                end
                // Prior Flit was NOP
                else begin
                    if (bad_sequence_number || (valid_nop_flit && bad_nop_sequence_number)) begin
                        seqnum_rule = RULE_NAK_SCHEDULE_2;
                    end
                    // Withdraw Nak
                    else begin
                        if ((valid_payload_flit && duplicate_sequence_number) || valid_nop_flit) begin
                            // Schedule Ack for NEXT_EXPECTED_RX_FLIT_SEQ_NUM - 1
                            tx_acknak_flit_seq_num = seqnum_minus_one(next_expected_rx_flit_seq_num_r);
                            discard_tlp_bytes = 1'b1;
                            seqnum_rule = RULE_SNPS_WITHDRAW_NAK_1;
                        end
                        if (valid_payload_flit && (next_expected_rx_flit_seq_num_r == implicit_rx_flit_seq_num)) begin
                            // Schedule Ack for NEXT_EXPECTED_RX_FLIT_SEQ_NUM
                            tx_acknak_flit_seq_num = next_expected_rx_flit_seq_num_r;
                            next_expected_rx_flit_seq_num    = seqnum_plus_one(next_expected_rx_flit_seq_num_r);
                            seqnum_rule = RULE_SNPS_WITHDRAW_NAK_2;
                        end
                    end
                end
            end
            // NAK_WITHDRAWAL_ALLOWED == 0b
            else begin
                if (nak_scheduled_r == 1'b1) begin
                    if (nak_scheduled_type_r == STANDARD_NAK) begin
                        if (valid_nop_flit) begin
                            if (rcvd_flit.replay_cmd==REPLAY_00 && implicit_rx_flit_seq_num==seqnum_minus_one(next_expected_rx_flit_seq_num_r)) begin
                                nak_scheduled = 1'b0;
                                discard_tlp_bytes = 1'b1;
                                seqnum_rule = RULE_SNPS_ACK_SCHEDULE_0;
                            end else begin
                                seqnum_rule = RULE_FLIT_DISCARD_0;
                            end
                        end
                        // Payload Flit
                        else begin
                            seqnum_rule = standard_nak_procedure;
                        end
                    end
                    // Selective Nak
                    else begin
                        if (valid_nop_flit) begin
                            seqnum_rule = RULE_FLIT_DISCARD_0;
                        end
                        // Payload Flit
                        else begin
                            seqnum_rule = selective_nak_procedure;
                        end
                    end
                end
                // NAK_SCHEDULED == 0b
                else begin
                    if (valid_nop_flit) begin
                        if (bad_nop_sequence_number) begin
                            seqnum_rule = RULE_NAK_SCHEDULE_2;
                        end else begin
                            seqnum_rule = RULE_FLIT_DISCARD_0;
                        end
                    end
                    // Payload Flit
                    else begin
                        if (duplicate_sequence_number) begin
                            seqnum_rule = RULE_FLIT_DISCARD_0;
                        end else if (bad_sequence_number)begin
                            seqnum_rule = RULE_NAK_SCHEDULE_2;
                        end else begin
                            // Forward Progress
                            seqnum_rule = RULE_ACK_SCHEDULE_0;
                        end
                    end
                end
            end
        end
    
        unique case (seqnum_rule)
            RULE_NAK_SCHEDULE_0 : begin
                discard_tlp_bytes = 1'b1;
                discard_dlp_bytes = 1'b1;
                nak_withdrawal_allowed = 1'b1;
                // next_expected_rx_flit_seq_num does not change.
            end
            RULE_NAK_SCHEDULE_1 : begin
                discard_tlp_bytes = 1'b1;
                discard_dlp_bytes = 1'b1;
                nak_scheduled = 1'b1;
                tx_acknak_flit_seq_num = seqnum_minus_one(next_expected_rx_flit_seq_num_r);
                nak_scheduled_type = STANDARD_NAK;
                nak_withdrawal_allowed = 1'b0;
                // next_expected_rx_flit_seq_num does not change.
            end
            RULE_NAK_SCHEDULE_2 : begin
                discard_tlp_bytes = 1'b1;
                tx_acknak_flit_seq_num = seqnum_minus_one(next_expected_rx_flit_seq_num_r);
                nak_scheduled = 1'b1;
                nak_scheduled_type = STANDARD_NAK;
                rx_retry_buffer_last_flit_seq_num = 0;
            end
            RULE_NAK_SCHEDULE_3 : begin
                nak_scheduled = 1'b1;
                nak_scheduled_type = (nak_scheduled_r == 1'b0)? SELECTIVE_NAK : nak_scheduled_type;
                tx_acknak_flit_seq_num = (nak_scheduled_r == 1'b0)? seqnum_minus_one(next_expected_rx_flit_seq_num_r) : tx_acknak_flit_seq_num;
                // Store the Received Flit in the RX Retry Buffer
                rx_retry_buffer_last_flit_seq_num = implicit_rx_flit_seq_num;
                next_rx_flit_seq_num_to_store = seqnum_plus_one(next_rx_flit_seq_num_to_store_r);
            end
            RULE_NAK_SCHEDULE_4 : begin
            end
            RULE_NAK_SCHEDULE_5 : begin
                nak_scheduled = 1'b1;
                nak_scheduled_type = STANDARD_NAK;
                tx_acknak_flit_seq_num = rx_retry_buffer_last_flit_seq_num_r;
                rx_retry_buffer_overflow = 1'b0;
                next_expected_rx_flit_seq_num = seqnum_plus_one(rx_retry_buffer_last_flit_seq_num_r);
                rx_retry_buffer_last_flit_seq_num = 0;
            end
            RULE_NAK_SCHEDULE_6 : begin
                discard_tlp_bytes = 1'b1;
                discard_dlp_bytes = 1'b1;
                nak_scheduled = 1'b1;
                nak_scheduled_type = STANDARD_NAK;
                rx_retry_buffer_overflow = 1'b0;
                tx_acknak_flit_seq_num = seqnum_minus_one(next_expected_rx_flit_seq_num_r);
                rx_retry_buffer_last_flit_seq_num = 0;
            end
            RULE_NAK_SCHEDULE_7 : begin
            end
            RULE_ACK_SCHEDULE_0 : begin
                tx_acknak_flit_seq_num = next_expected_rx_flit_seq_num_r;
                next_expected_rx_flit_seq_num    = seqnum_plus_one(next_expected_rx_flit_seq_num_r);
            end
            RULE_ACK_SCHEDULE_1 : begin
                nak_scheduled = 1'b0;
                tx_acknak_flit_seq_num = implicit_rx_flit_seq_num;
                next_expected_rx_flit_seq_num    = seqnum_plus_one(implicit_rx_flit_seq_num);
            end
            RULE_ACK_SCHEDULE_2 : begin
                nak_scheduled = 1'b0;
                tx_acknak_flit_seq_num = implicit_rx_flit_seq_num;
                next_expected_rx_flit_seq_num = seqnum_plus_one(implicit_rx_flit_seq_num);
            end
            RULE_FLIT_DISCARD_0 : begin
                discard_tlp_bytes = 1'b1;
                // next_expected_rx_flit_seq_num does not change.
            end
            RULE_FLIT_DISCARD_1 : begin
                discard_tlp_bytes = 1'b1;
                discard_dlp_bytes = 1'b1;
                // next_expected_rx_flit_seq_num does not change.
            end
            RULE_FLIT_DISCARD_2 : begin
                discard_tlp_bytes = 1'b1;
                discard_dlp_bytes = 1'b1;
                invalid_seqnum_0 = 1'b1; // A Data Link Protocol Error is logged in the receiving Port
                // next_expected_rx_flit_seq_num does not change.
                nak_withdrawal_allowed = 1'b0;
            end
            default : begin
                // RULE_INVALID Unreachable
            end
      endcase
  end
end : ack_nak_discard_PROC

// Bad Sequence Number Check Logic: (next_expected_rx_flit_seq_num_r - implicit_rx_flit_seq_num)% 1023 > 511
assign bad_sequence_number = cx_pl_pkg::x_minus_y_mod_1023(next_expected_rx_flit_seq_num_r, implicit_rx_flit_seq_num) > 511;

// Bad NOP Sequence Number Check Logic
assign bad_nop_sequence_number = bad_sequence_number || (implicit_rx_flit_seq_num == next_expected_rx_flit_seq_num_r);

// Duplicate Sequence Number Check Logic: (tx_acknak_flit_seq_num_r - implicit_rx_flit_seq_num)%1023 < 511
assign duplicate_sequence_number = cx_pl_pkg::x_minus_y_mod_1023(tx_acknak_flit_seq_num_r, implicit_rx_flit_seq_num) < 511;


// Ack/Nak/Discard Logic when scheduling a Standard Nak or when a Standard Nak is outstanding.
always_comb begin : standard_nak_procedure_PROC
    standard_nak_procedure = RULE_INVALID;
    if (duplicate_sequence_number) begin
        if (nak_scheduled_r == 1'b1) begin
            standard_nak_procedure = RULE_FLIT_DISCARD_0;
        end else begin
            standard_nak_procedure = RULE_NAK_SCHEDULE_2;
        end
    end else if (rcvd_flit.replay_cmd==REPLAY_00 && implicit_rx_flit_seq_num==next_expected_rx_flit_seq_num_r) begin // Received Flit is Explicit Sequence Number Flit
        standard_nak_procedure = RULE_ACK_SCHEDULE_1;
    end else begin
        if (nak_scheduled_r == 1'b1) begin
            standard_nak_procedure = RULE_FLIT_DISCARD_0;
        end else begin
            standard_nak_procedure = RULE_NAK_SCHEDULE_2;
        end
    end
end : standard_nak_procedure_PROC

// Ack/Nak/Discard Logic when scheduling a Selective Nak or when a Selective Nak is outstanding.
always_comb begin : selective_nak_procedure_PROC
    selective_nak_procedure = RULE_INVALID;
    if (duplicate_sequence_number) begin
        selective_nak_procedure = RULE_FLIT_DISCARD_0;
    end else if (rcvd_flit.replay_cmd==REPLAY_00 && implicit_rx_flit_seq_num==next_expected_rx_flit_seq_num_r) begin // Received Flit is Explicit Sequence Number Flit
        if (rx_retry_buffer_overflow_r == 1) begin
            selective_nak_procedure = RULE_NAK_SCHEDULE_5;
        end else begin
            selective_nak_procedure = RULE_ACK_SCHEDULE_2;
        end
    end else if (implicit_rx_flit_seq_num == next_rx_flit_seq_num_to_store_r) begin
        // If retry buffer is full before the explicit flit is received
        if (rx_retry_buffer_full && nak_scheduled_r) begin
            selective_nak_procedure = RULE_NAK_SCHEDULE_4;
        end else begin
            if (rx_retry_buffer_busy)
                selective_nak_procedure = RULE_NAK_SCHEDULE_7;
            else
                selective_nak_procedure = RULE_NAK_SCHEDULE_3;
        end
    end
    // Bad Sequence Number
    else begin
        selective_nak_procedure = RULE_NAK_SCHEDULE_2;
    end
end : selective_nak_procedure_PROC

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        tx_acknak_flit_seq_num_r             <= #TP 10'h3FF; // 1023
        next_expected_rx_flit_seq_num_r      <= #TP 1;
        implicit_rx_flit_seq_num_r           <= #TP 0;
        nak_scheduled_r                      <= #TP 0;
        nak_scheduled_type_r                 <= #TP nak_type_t'(0);
        nak_withdrawal_allowed_r             <= #TP 0;
        next_rx_flit_seq_num_to_store_r      <= #TP 0;
        rx_retry_buffer_overflow_r           <= #TP 0;
        rx_retry_buffer_last_flit_seq_num_r  <= #TP 0;
        discard_tlp_bytes_r                  <= #TP 0;
        discard_dlp_bytes_r                  <= #TP 0;
    end else begin
        if ( cxl_mode_enable ? 1'b0 : smlh_block_dl_init) begin
            tx_acknak_flit_seq_num_r             <= #TP 10'h3FF; // 1023
            next_expected_rx_flit_seq_num_r      <= #TP 1;
            implicit_rx_flit_seq_num_r           <= #TP 0;
            nak_scheduled_r                      <= #TP 0;
            nak_scheduled_type_r                 <= #TP nak_type_t'(0);
            nak_withdrawal_allowed_r             <= #TP 0;
            next_rx_flit_seq_num_to_store_r      <= #TP 0;
            rx_retry_buffer_overflow_r           <= #TP 0;
            rx_retry_buffer_last_flit_seq_num_r  <= #TP 0;
        end else if (rxflit_dv) begin
            tx_acknak_flit_seq_num_r             <= #TP tx_acknak_flit_seq_num;
            next_expected_rx_flit_seq_num_r      <= #TP next_expected_rx_flit_seq_num;
            implicit_rx_flit_seq_num_r           <= #TP implicit_rx_flit_seq_num;
            nak_scheduled_r                      <= #TP nak_scheduled;
            nak_scheduled_type_r                 <= #TP nak_scheduled_type;
            nak_withdrawal_allowed_r             <= #TP nak_withdrawal_allowed;
            next_rx_flit_seq_num_to_store_r      <= #TP next_rx_flit_seq_num_to_store;
            rx_retry_buffer_overflow_r           <= #TP rx_retry_buffer_overflow;
            rx_retry_buffer_last_flit_seq_num_r  <= #TP rx_retry_buffer_last_flit_seq_num;
            discard_tlp_bytes_r                  <= #TP discard_tlp_bytes;
            discard_dlp_bytes_r                  <= #TP discard_dlp_bytes;
        end
    end
end


wire non_idle_explicit_seq_num_flit_evt;
assign non_idle_explicit_seq_num_flit_evt = valid_non_idle_flit && rcvd_flit.replay_cmd==REPLAY_00 && 
                                            (state_r!=IDLE_FLIT_HS || enter_seq_num_hs); // Discard flits received in IDLE Flit Handshake Phase  
assign non_idle_explicit_seq_num_flit_rcvd = (non_idle_explicit_seq_num_flit_evt)? 1'b1 : non_idle_explicit_seq_num_flit_rcvd_r;
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        non_idle_explicit_seq_num_flit_rcvd_r    <= #TP 0;
    end else if (enter_idle_flit_hs) begin  // Cleared on entry to IDLE Flit Handshake Phase.
        non_idle_explicit_seq_num_flit_rcvd_r    <= #TP 0;
    end else if (non_idle_explicit_seq_num_flit_evt) begin
        non_idle_explicit_seq_num_flit_rcvd_r    <= #TP 1;
    end
end


  wire [FLIT_DATA_W_PROT-1:0] flit_tlp_w_prot;
  wire [FLIT_DATA_W_PROT-1:0] int_flit_tlp_w_prot;
  wire [FLIT_DATA_W_PROT-1:0] rbuf_tlp_w_prot;
  assign flit_tlp_w_prot       = { rxflit_data[FLIT_DATA_WD+:FLIT_DATA_PROT_WD], rxflit_data[FLIT_DATA_WD-1:0]};
  assign int_flit_tlp_w_prot = flit_tlp_w_prot;


replay_cmd_t req_replay_cmd;
wire [9:0]   req_seqnum;
replay_cmd_t rcvd_replay_cmd;
wire [9:0]   rcvd_seqnum;        // SeqNum from the Flit field
wire         acknack_disable;    // Do not send any ACK or NAK

assign acknack_disable = cfg_acknack_disable | (cdm_ras_des_einj2_enable & (cdm_ras_des_einj2_dllp_type==2'b00)) ;

always_comb begin : replay_cmd_PROC
    if(acknack_disable) begin
        req_replay_cmd      = REPLAY_00;
    // schedule new NAK
    end else if(nak_scheduled && !nak_scheduled_r) begin
            req_replay_cmd  = NAK_10;
    end
    else if(nak_scheduled) begin
        req_replay_cmd      = NAK_10;
    end 
    else if(nak_withdrawal_allowed) begin
        req_replay_cmd      = REPLAY_00;
    end else begin
        req_replay_cmd      = ACK;
    end
end : replay_cmd_PROC

assign req_seqnum          = tx_acknak_flit_seq_num;
assign rcvd_replay_cmd     = (discard_dlp_bytes)? REPLAY_00 : replay_cmd_t'(rcvd_flit.replay_cmd);
assign rcvd_seqnum         = (discard_dlp_bytes)? 0         : rcvd_flit.seqnum;

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        rplh_xplh_fm_retry                       <= #TP rplh_xplh_fm_retry_t'(0);
        rplh_xplh_fm_retry.requested.seqnum      <= #TP 10'h3FF; // 1023
    end else if(next_state==IDLE_FLIT_HS || non_idle_explicit_seq_num_flit_rcvd==1'b0) begin
        rplh_xplh_fm_retry                       <= #TP rplh_xplh_fm_retry_t'(0);
        rplh_xplh_fm_retry.requested.seqnum      <= #TP (req_replay_cmd==REPLAY_00) ? rplh_xplh_fm_retry.requested.seqnum : req_seqnum;
        rplh_xplh_fm_retry.requested.cmd         <= #TP req_replay_cmd;
    end else begin
        rplh_xplh_fm_retry.valid                 <= #TP rxflit_dv || rxflit_err;
        if (rxflit_dv || rxflit_err) begin
            rplh_xplh_fm_retry.requested.cmd     <= #TP req_replay_cmd;
            rplh_xplh_fm_retry.requested.seqnum  <= #TP (req_replay_cmd==REPLAY_00) ? rplh_xplh_fm_retry.requested.seqnum : req_seqnum;
            rplh_xplh_fm_retry.received.cmd      <= #TP rcvd_replay_cmd;
            rplh_xplh_fm_retry.received.seqnum   <= #TP rcvd_seqnum;
            rplh_xplh_fm_retry.rcvd_expl_seq_num <= #TP non_idle_explicit_seq_num_flit_rcvd;
        end
    end
end

// Forward flit for TLP bytes extraction
wire  tlp_byte_dv;
assign tlp_byte_dv = rxflit_dv & ~discard_tlp_bytes;

stream_id_e   int_flit_stream;
logic [7:0]   int_flit_stream_r;
logic [47:0]  int_dlp_bytes;
logic [1:0]   int_flit_usage;

assign int_dlp_bytes  = cxl_mode_enable ? {int_flit_tlp_w_prot[238*8+:4*8], int_flit_tlp_w_prot[0+:2*8]} : int_flit_tlp_w_prot[236*8+:6*8];
assign int_flit_usage = flit_usage_t'(int_dlp_bytes[7:6]);

// PCIe Flit Output
always_comb begin
    case (int_flit_usage)
        PAYLOAD: begin
            int_flit_stream    = cxl_mode_enable ? SID_CXL_IO : SID_PCIE;
        end
        CXL_CM: begin
            int_flit_stream    = SID_CXL_CM;
        end
        CXL_ALMP: begin
            int_flit_stream    = SID_ALMP;
        end
        default: begin
            int_flit_stream    = SID_RSVD;
        end
    endcase
end

assign rplh_flit_stream    = stream_id_e'(int_flit_stream_r);

delay_n

#(REGOUT_EN, $bits(stream_id_e)) u_delay_out_stream (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (int_flit_stream),
    .dout  (int_flit_stream_r)
);

assign rplh_flit_data      = {{(FLIT_WD-FLIT_DATA_WD){1'b0}}, rxflit_data_r[0+:FLIT_DATA_WD]};
assign rplh_flit_data_prot = {{(FLIT_PROT_WD-FLIT_DATA_PROT_WD){PARITY_MODE}}, rxflit_data_r[FLIT_DATA_WD+:FLIT_DATA_PROT_WD]};

delay_n

#(REGOUT_EN, 1) u_delay_out_ctrl (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (tlp_byte_dv),
    .dout  (rplh_flit_dv)
);

assign int_flit_nullified = flit_nullified;
assign int_flit_poisoned= flit_poisoned;
delay_n_w_enable

//the extra 18 bits are 2 bits for flit nullified and poisoned, 16 bits for header
#(REGOUT_EN, REGOUT_WD+2) u_delay_w_enable_out_data (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (tlp_byte_dv),
    .din   ({int_flit_tlp_w_prot,  int_flit_nullified,  int_flit_poisoned}),      
    .dout  ({rxflit_data_r,        rplh_flit_nullified, rplh_flit_poisoned})
);

// Data Link Protocol Errors
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        rplh_flit_dl_prot_err  <= #TP 0;
    end else if(rxflit_dv &&  !rxflit_err) begin
        rplh_flit_dl_prot_err  <= #TP dl_prot_err;
    end else begin
        rplh_flit_dl_prot_err  <= #TP 0;
    end
end

// Unrecognized flit
// Note rplh_unrecognized_flit output is required to be aligned with the Flit Logging interface (i.e. rplh_flit_prot outputs)
assign rplh_unrecognized_flit = rxflit_dv && unrecognized_flit && !rxflit_err;

// DL Bytes extraction 
wire dllp_opt_fc_up;
wire dllp_valid;
assign dllp_opt_fc_up = valid_nop_io_flit && rcvd_flit.type_dllp_payld==FMARK_FCUPD && !dlp2[7];
assign dllp_valid = valid_nop_io_flit && !discard_dlp_bytes && (rcvd_flit.type_dllp_payld==DLLP || dllp_opt_fc_up);

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        rplh_rdlh_fm_dllp_valid     <= #TP '0;
        rplh_rdlh_fm_dllp_opt_fc_up <= #TP '0;
        rplh_rdlh_fm_dllp_data      <= #TP '0;
    end else begin
        rplh_rdlh_fm_dllp_valid     <= #TP dllp_valid;
        rplh_rdlh_fm_dllp_opt_fc_up <= #TP dllp_opt_fc_up;
        if (dllp_valid)
            rplh_rdlh_fm_dllp_data  <= #TP dllp_data;
        else
            rplh_rdlh_fm_dllp_data  <= #TP '0;
    end
end

// detect if first rxed ALMP is errored to clear equaliation flag in smlh in order to enable transmitter for sending the NAK
// the first payload flit must be the ALMP flit after we have received valid_non_idle flits
assign rplh_fm_cxl_rcvd_flit = rxflit_dv && (rcvd_flit.flit_usage != IDLE_NOP) && (state_r inside {FLIT_SEQ_NUM_HS, NORMAL});

// Detect LTSSM entering Configuration.Idle or Recovery.Idle in order to move to IDLE_FLIT_HS
logic smlh_ltssm_in_idle;
assign smlh_ltssm_in_idle = smlh_ltssm_state==S_CFG_IDLE   || 
                            smlh_ltssm_state==S_RCVRY_IDLE || 
                            smlh_ltssm_state==S_LPBK_ACTIVE ; // Loopback is implementation specific (and IDLE not used)

logic smlh_ltssm_in_idle_r;
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        smlh_ltssm_in_idle_r    <= #TP 0;
    end else begin
        smlh_ltssm_in_idle_r    <= #TP smlh_ltssm_in_idle;
    end
end

// IDLE Flits count logic
reg [1:0] rcvd_null_cnt;
always @(posedge core_clk or negedge core_rst_n) begin : rcvd_idle_cnt_seq_PROC
    if( !core_rst_n ) begin
        rcvd_null_cnt <= #TP 0;
    end else if (rxflit_err || ~smlh_ltssm_in_idle) begin
        rcvd_null_cnt <= #TP 0;
    end else if (rxflit_dv) begin
        rcvd_null_cnt <= #TP {rcvd_null_cnt[0], valid_idle_flit};
    end
end
assign rplh_flit_rcvd_idle[1] = rcvd_null_cnt[0];
assign rplh_flit_rcvd_idle[0] = &rcvd_null_cnt;

// A Port enters IDLE Flit Handshake phase when the LTSSM enters Configuration.Idle or Recovery.Idle states.
assign enter_idle_flit_hs = ~smlh_ltssm_in_idle_r & smlh_ltssm_in_idle;

// The Receiver moves to the Sequence Number Handshake Phase when two consecutive valid IDLE Flits have been received.
assign enter_seq_num_hs = rcvd_null_cnt[0] & valid_idle_flit & smlh_ltssm_in_idle;

// Note the receiver is just waiting for explicit Sequence Number regardless of the following tx requirements:
// - The Port has transmitted 3 or more Ack Flits with non-zero Flit Sequence Numbers (after having received one or more Explicit Sequence Number Flits with a non-zero Flit Sequence Number).
// - The Port has transmitted 9 or more Explicit Sequence Number Flits with a non-zero Flit Sequence Number.
// As confirmed by PCISIG: The Receiver Rules for Sequence Number Handshake Phase and Normal Flit Exchange Phase are the same, 
//                         so I dont think it matters if the receiver transitions to the next phase ahead of the transmitter.
assign enter_normal_phase = non_idle_explicit_seq_num_flit_rcvd;

// State FSM
always_comb begin : rplh_state_PROC 
    next_state = state_r;
    case (state_r)
        // All received Flits are discarded
        IDLE_FLIT_HS : begin
            if(enter_seq_num_hs)
                next_state = FLIT_SEQ_NUM_HS;
        end
        // Wait for any valid non-IDLE Flit with Replay Command = 00b
        FLIT_SEQ_NUM_HS : begin
            if(enter_idle_flit_hs)
                next_state = IDLE_FLIT_HS;
            else if (enter_normal_phase)
                next_state = NORMAL;
        end
        // Normal Mode
        NORMAL : begin
            if(enter_idle_flit_hs)
                next_state = IDLE_FLIT_HS;
        end
  endcase
end : rplh_state_PROC

// RPLH State Register
always_ff @(posedge core_clk or negedge core_rst_n) begin : state_PROC
  if(!core_rst_n)
    state_r <= #TP IDLE_FLIT_HS;
  else
    state_r <= #TP next_state;
end : state_PROC


  wire valid_tlp_bytes;
  wire flit_is_duplicate;
  assign valid_tlp_bytes = valid_io_flit && !discard_tlp_bytes;
  assign flit_is_duplicate = valid_io_flit && duplicate_sequence_number;
  // Add PTM Monitor to check for PTM bit in Flit Marker
  rplh_ptm_fm_mon
   u_rplh_ptm_fm_mon (
     .core_clk           (core_clk)
    ,.core_rst_n         (core_rst_n)
    ,.cfg_upstream_port  (cfg_upstream_port)
    ,.sample_flit        (valid_tlp_bytes)
    ,.flit_is_duplicate  (flit_is_duplicate)
    ,.dlp0               (dlp0)
    ,.dlp2               (dlp2)
    // Outputs
    ,.ptm_sot            (rplh_ptm_sot)
    ,.ptm_request        (rplh_ptm_request)
    ,.ptm_response       (rplh_ptm_response)
    ,.ptm_duplicate      (rplh_ptm_duplicate)
  );


//==============================================================================
// Functions
//==============================================================================
function automatic [9:0] seqnum_plus_one(input [9:0] seqnum);
    return (seqnum==10'b11_1111_1111)? 10'd1 : seqnum + 1;
endfunction
function automatic [9:0] seqnum_minus_one(input [9:0] seqnum);
    return (seqnum==10'b00_0000_0001)? 10'b11_1111_1111 : seqnum - 1;
endfunction

//==============================================================================
// Formal verification
//==============================================================================

endmodule

