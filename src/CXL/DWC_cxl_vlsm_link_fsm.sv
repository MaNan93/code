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
// ---   $DateTime: 2024/02/19 04:20:14 $
// ---   $Revision: #29 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_vlsm_link_fsm.sv#29 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Link VLSM which handles the interface between CXL.io or CXL.mem/CXL.cache link layers and the VLSM.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

module DWC_cxl_vlsm_link_fsm
  import spif_pkg::*;                                               // Import SPIF package
  import DWC_cxl_pkg::*;
#(
  parameter stream_id_e  STREAM_ID        = SID_RSVD,
  parameter              PM_PHASE1_ENABLE = 1,
  parameter              TP               = `TP
) 
                              (
  // Interfaces
  spif_if.master_mp                   b_vlsm_llctrl,                // vLSM SPIF Interface to the protocol stack Link Layer
  //spif_if.cfgi_slave_mp               b_cfgi_spif                   // CFGI SPIF Interface to propagate to the Link Layer
  spif_if.rplh_slave_mp               b_rplh_spif,                  // RPLH SPIF Interface to propagate to the Link Layer
  spif_if.smlh_sts_slave_mp           b_smlh_spif,                  // SMLH SPIF Interface to propagate to the Link Layer
  input                               core_clk,                     // Core clock
  input                               core_rst_n,                   // Core active low asynchronous reset
  input                               cxl_device_type,              // CXL Device type
  input                               cxl_pcie_flit_mode,           // CXL 256B Flit Mode
  input                               cfg_vlsm_pm_enable,           // Enable Low Power mode Entry handshake
  input                               cfg_vlsm_force_active,        // Force VLSM State to ACTIVE
  // Interface with Physical Layer
  input                               pl_clk_req,                   // Physical Layer requests Link Layer to remove the clock gating from the internal logic
  input                               pl_wake_ack,                  // Physical Layer responds to lp_wake_req after it has removed clock gating
  input                               pl_rx_active_req,             // Physical Layer to Link Layer RX datapath activation request
  input                               pl_block_dl_init,             // Physical Layer to Link Layer block DL initialization
  input                               pl_stall_req,                 // Physical Layer to Link Layer request to flush all packets
  input  state_enc_e                  pl_state_sts,                 // Physical Layer to Link Layer state status
  input                               pl_trdy,                      // Physical Layer is ready to accept data
  input                               pl_skip_trdy,                 // Packet Layer indicates that it is ready to insert Skip Ordered Set
  input                               pl_dllp_trdy,                 // Physical Layer is ready to accept DLLP
  input                               vlsm_bypass_enable,           // Enable Link vLSM bypass on SPIF interface
  // Interface with ALMP Generator
  input                               vlsm_link_enable,             // Enable protocol link
  input                               vlsm_rx_req_done,             // VLSM RX Request-Status Handshake Done
  input                               vlsm_tx_req_done,             // VLSM TX Request-Status Handshake Done
  input                               vlsm_tx_sts_done,             // VLSM TX Status Exchange Handshake Done
  input                               vlsm_tx_sts_error,            // VLSM TX Status Exchange Handshake Error
  input                               vlsm_almp_req_sent,           // VLSM ALMP Request transmitted
  input                               vlsm_almp_req_l1_rcvd,        // ALMP Request(Active) received 
  input                               vlsm_almp_req_l2_rcvd,        // ALMP Request(Active) received
  input                               vlsm_almp_unexp_error,        // VLSM Unexpected ALMP error 
  input  state_enc_e                  vlsm_almp_rslvd_state,        // VLSM Resolved State
  input                               almp_rx_req_active,           // ALMP Request(Active) received 
  input                               almp_pm_req_timeout,          // ALMP Request(L1/L2) 10us response timeout for DSP
  input                               vlsm_tx_sts_pmnak,            // Application request to transmit Status(PMNAK)
  input                               almp_rx_sts_pmnak,            // ALMP Status(Active.PMNAK) is received
  output logic                        almp_tx_request,              // VLSM requests to transmit ALMP Request
  output logic                        almp_tx_status,               // VLSM requests to transmit ALMP Status
  output logic                        almp_tx_sts_ena,              // VLSM enables ALMP Status Response to the received ALMP Request
  output state_enc_e                  almp_tx_sts_state,            // VLSM Link Status State
  output state_enc_e                  almp_tx_req_state,            // VLSM Link Requested State
  output vlsm_link_debug_t            vlsm_link_debug_info,         // Link vLSM Debug Information
  // Interface with ARB/MUX Resolution Table
  output logic                        vlsm_link_active_req,         // Request LTSSM for link active
  output logic                        vlsm_link_retrain_req,        // Request LTSSM for link retrain
  output logic                        vlsm_link_disable_req,        // Request LTSSM for link disable
  output logic                        vlsm_link_reset_req           // Request LTSSM for link reset
);

localparam  LINK_VLSM_STATE_WD = 17;   // VLSM state width 

// Link VLSM FSM encoding
typedef enum logic [(LINK_VLSM_STATE_WD - 1) : 0] {
    LINK_VLSM_RESET         = 17'b00000000000000001,
    LINK_VLSM_PREP_ACTIVE   = 17'b00000000000000010,
    LINK_VLSM_ACTIVE        = 17'b00000000000000100,
    LINK_VLSM_PREP_RETRAIN  = 17'b00000000000001000,
    LINK_VLSM_RETRAIN       = 17'b00000000000010000,
    LINK_VLSM_EXIT_RETRAIN  = 17'b00000000000100000,
    LINK_VLSM_PREP_L1       = 17'b00000000001000000,
    LINK_VLSM_L1            = 17'b00000000010000000,
    LINK_VLSM_PREP_L2       = 17'b00000000100000000,
    LINK_VLSM_L2            = 17'b00000001000000000,
    LINK_VLSM_PREP_RESET    = 17'b00000010000000000,
    LINK_VLSM_WAIT_ACTIVE   = 17'b00000100000000000,
    LINK_VLSM_ABORT_L1      = 17'b00001000000000000,
    LINK_VLSM_LINKRESET     = 17'b00010000000000000,
    LINK_VLSM_DISABLE       = 17'b00100000000000000,
    LINK_VLSM_LINKERROR     = 17'b01000000000000000,
    LINK_VLSM_ACTIVE_PMNAK  = 17'b10000000000000000
} link_vlsm_state_e;

// Local declarations
link_vlsm_state_e vlsm_state_r, vlsm_state_nxt;                    // Link VLSM state machine
state_enc_e       vlsm_snap_state_r, vlsm_snap_state_nxt;          // Snapshot of VLSM state before entering RETRAIN state
state_enc_e       vlsm_link_state_r, vlsm_link_state_nxt;          // VLSM Active state
logic             vlsm_sts_exch_pend_r, vlsm_sts_exch_pend_nxt;    // VLSM STATUS_EXCHANGE_PENDING variable
logic             vlsm_abort_entry_r, vlsm_abort_entry_s;          // Entry to ABORT_L1 cycle
logic             vlsm_link_down_dis_r, vlsm_link_down_dis_nxt;    // Disable Link Down detection on exit from LINKERROR, LINKRESET, and DISABLED states
logic             almp_rx_req_l1_r, almp_rx_req_l1_nxt;            // Latched L1 State Request ALMP
logic             almp_rx_req_l2_r, almp_rx_req_l2_nxt;            // Latched L2 State Request ALMP
logic             almp_rx_req_active_r, almp_rx_req_active_nxt;    // Latched Active State Request ALMP
logic             almp_rx_req_active_s;                            // Received Active State Request ALMP flag
logic             almp_tx_status_r, almp_tx_status_nxt;            // Indicates Status Synchronization phase to ALMP Generator
logic             link_stall_req_r, link_stall_req_nxt;            // Stall Request
logic             link_block_dl_init_r, link_block_dl_init_nxt;    // Block DL Initialization
logic             link_rx_active_req_r, link_rx_active_req_nxt;    // RX Interface Activation Request
logic             link_spif_hs_done_r, link_spif_hs_done_s;        // Stall Request/Acknowledge and RX Active Request/Status handshakes are complete on exit from ABORT_L1
logic             spif_protocol_vld_r;                             // Registered version of Packet Layer Protocol Valid on SPIF interface
logic             vlsm_bypass_enable_r;                            // Enable Link vLSM bypass on SPIF interface for CXL.io in PCIe mode
logic             vlsm_stream_enable;                              // Enable data stream on SPIF interface
logic             vlsm_dllpif_enable;                              // Enable DLLP data on SPIF interface
logic             almp_rx_sts_pmnak_s;                             // ALMP Status(Active.PMNAK) is received validated with cxl_pcie_flit_mode and CX_CXL_UPSTREAM_PORT
logic             pl_stall_req_r, pl_stall_req_nxt;                // Propagated pl_stall_req from the Physical Layer

// Output assignments
assign vlsm_link_active_req             = (b_vlsm_llctrl.s_lp_state_req == ACTIVE);
assign vlsm_link_retrain_req            = cxl_pcie_flit_mode ? (b_vlsm_llctrl.s_lp_state_req == RETRAIN) : (vlsm_state_r == LINK_VLSM_PREP_RETRAIN);
assign vlsm_link_disable_req            = (b_vlsm_llctrl.s_lp_state_req == DISABLED);
assign vlsm_link_reset_req              = (b_vlsm_llctrl.s_lp_state_req == LINKRESET);

// Interface to Link Layer
assign b_vlsm_llctrl.s_pl_state_sts     = vlsm_bypass_enable_r ? pl_state_sts     : vlsm_link_state_r;
assign b_vlsm_llctrl.s_pl_stall_req     = vlsm_bypass_enable_r ? pl_stall_req     : (link_stall_req_r || pl_stall_req_r);
assign b_vlsm_llctrl.s_pl_rx_active_req = vlsm_bypass_enable_r ? pl_rx_active_req : link_rx_active_req_r;
assign b_vlsm_llctrl.s_pl_block_dl_init = vlsm_bypass_enable_r ? pl_block_dl_init : link_block_dl_init_r;
assign b_vlsm_llctrl.s_pl_clk_req       = pl_clk_req;
assign b_vlsm_llctrl.s_pl_wake_ack      = pl_wake_ack;
assign b_vlsm_llctrl.s_pl_trdy          = pl_trdy;
assign b_vlsm_llctrl.s_pl_skip_trdy     = pl_skip_trdy;
assign b_vlsm_llctrl.s_pl_dllp_trdy     = pl_dllp_trdy;

assign b_vlsm_llctrl.s_pl_device_port   = b_smlh_spif.s_pl_device_port  ;
assign b_vlsm_llctrl.s_pl_phyinl1       = b_smlh_spif.s_pl_phyinl1      ;
assign b_vlsm_llctrl.s_pl_phyinl2       = b_smlh_spif.s_pl_phyinl2      ;
assign b_vlsm_llctrl.s_pl_phyinretrain  = b_smlh_spif.s_pl_phyinretrain ;
assign b_vlsm_llctrl.s_pl_phyinrxl0s    = b_smlh_spif.s_pl_phyinrxl0s   ;
assign b_vlsm_llctrl.s_pl_phyrcvdeiosq  = b_smlh_spif.s_pl_phyrcvdeiosq ;
assign b_vlsm_llctrl.s_pl_speedmode     = b_smlh_spif.s_pl_speedmode    ;
assign b_vlsm_llctrl.s_pl_bw_ratio      = b_smlh_spif.s_pl_bw_ratio      ;
assign b_vlsm_llctrl.s_pl_linkmode      = b_smlh_spif.s_pl_linkmode     ;
assign b_vlsm_llctrl.s_pl_protocol_vld  = b_smlh_spif.s_pl_protocol_vld ;
assign b_vlsm_llctrl.s_pl_protocol      = b_smlh_spif.s_pl_protocol     ;
assign b_vlsm_llctrl.s_pl_protocol_fmt  = b_smlh_spif.s_pl_protocol_fmt ;
assign b_vlsm_llctrl.s_pl_inband_pres   = b_smlh_spif.s_pl_inband_pres  ;
assign b_vlsm_llctrl.s_pl_link_up       = b_smlh_spif.s_pl_link_up      ;
assign b_vlsm_llctrl.s_pl_link_down     = b_smlh_spif.s_pl_link_down    ;

// The driver of the pl_stream[7:0] signal must comprehend that the Link Layer is transparent to the value of the forwarded 
// StreamID and therefore must ensure that only the packets intended for the Link Layer are forwarded.
// Therefore we filter the receive interface with pl_stream before forwarding to the Link Layer
assign vlsm_stream_enable               = vlsm_bypass_enable_r ? (b_rplh_spif.s_pl_stream == SID_PCIE) : (b_rplh_spif.s_pl_stream == STREAM_ID);
assign vlsm_dllpif_enable               = vlsm_bypass_enable_r ? 1'b1                                  : (SID_CXL_IO              == STREAM_ID);

assign b_vlsm_llctrl.s_pl_stream        = vlsm_stream_enable ? b_rplh_spif.s_pl_stream       : SID_RSVD ;
assign b_vlsm_llctrl.s_pl_valid         = vlsm_stream_enable ? b_rplh_spif.s_pl_valid        : '0       ;
assign b_vlsm_llctrl.s_pl_data          = vlsm_stream_enable ? b_rplh_spif.s_pl_data         : '0       ;
assign b_vlsm_llctrl.s_pl_data_chk      = vlsm_stream_enable ? b_rplh_spif.s_pl_data_chk     : '0       ;
assign b_vlsm_llctrl.s_pl_crc_valid     = vlsm_stream_enable ? b_rplh_spif.s_pl_crc_valid    : '0       ;
assign b_vlsm_llctrl.s_pl_crc_data      = vlsm_stream_enable ? b_rplh_spif.s_pl_crc_data     : '0       ;
assign b_vlsm_llctrl.s_pl_rx_flush      = b_rplh_spif.s_pl_rx_flush;
assign b_vlsm_llctrl.s_pl_rx_nak        = vlsm_stream_enable ? b_rplh_spif.s_pl_rx_nak       : '0       ;
assign b_vlsm_llctrl.s_pl_dlp_start     = vlsm_stream_enable ? b_rplh_spif.s_pl_dlp_start    : '0       ;
assign b_vlsm_llctrl.s_pl_dlp_end       = vlsm_stream_enable ? b_rplh_spif.s_pl_dlp_end      : '0       ;
assign b_vlsm_llctrl.s_pl_tlp_start     = vlsm_stream_enable ? b_rplh_spif.s_pl_tlp_start    : '0       ;
assign b_vlsm_llctrl.s_pl_tlp_end       = vlsm_stream_enable ? b_rplh_spif.s_pl_tlp_end      : '0       ;
assign b_vlsm_llctrl.s_pl_tlp_edb       = vlsm_stream_enable ? b_rplh_spif.s_pl_tlp_edb      : '0       ;
assign b_vlsm_llctrl.s_pl_error         = vlsm_stream_enable ? b_rplh_spif.s_pl_error        : '0       ;
assign b_vlsm_llctrl.s_pl_nullified     = vlsm_stream_enable ? b_rplh_spif.s_pl_nullified    : '0       ;
assign b_vlsm_llctrl.s_pl_poisoned      = vlsm_stream_enable ? b_rplh_spif.s_pl_poisoned     : '0       ;
assign b_vlsm_llctrl.s_pl_dllp_valid    = vlsm_dllpif_enable ? b_rplh_spif.s_pl_dllp_valid   : '0       ;
assign b_vlsm_llctrl.s_pl_dllp_ofc      = vlsm_dllpif_enable ? b_rplh_spif.s_pl_dllp_ofc     : '0       ;
assign b_vlsm_llctrl.s_pl_dllp_data     = vlsm_dllpif_enable ? b_rplh_spif.s_pl_dllp_data    : '0       ;

// CFGI SPIF Interface Connections
assign b_vlsm_llctrl.s_pl_cfg_vld  = '0; //b_cfgi_spif.s_pl_cfg_vld       ;
assign b_vlsm_llctrl.s_pl_cfg_data = '0; //b_cfgi_spif.s_pl_cfg_data      ;
// assign b_cfgi_spif.s_lp_cfg_vld       = b_vlsm_llctrl.s_lp_cfg_vld       ;
// assign b_cfgi_spif.s_lp_cfg_data      = b_vlsm_llctrl.s_lp_cfg_data      ;

// Internal asignments
assign vlsm_abort_entry_s = (vlsm_state_r == LINK_VLSM_PREP_L1) && (vlsm_state_nxt == LINK_VLSM_ABORT_L1);

// Wait for all handshakes to complete to exit from ABORT_L1 to ACTIVE state
// If stall_req was asserted then wait for stall_ack to be asserted, if rx_active_req was de-asserted wait for rx_active_sts to be de-asserted
assign link_spif_hs_done_s = (vlsm_state_r == LINK_VLSM_ABORT_L1) && (link_stall_req_r ? b_vlsm_llctrl.s_lp_stall_ack : 1'b1) && (b_vlsm_llctrl.s_pl_rx_active_req ? 1'b1 : !b_vlsm_llctrl.s_lp_rx_active_sts);

// Validating almp_rx_sts_pmnak with CX_CXL_256B_FLIT_ENABLE and CX_CXL_UPSTREAM_PORT
assign almp_rx_sts_pmnak_s = 1'b0 || (almp_rx_sts_pmnak && cxl_pcie_flit_mode) ; 

// On transition to RESET state set Link Down detection disable flag and preserve it until core reset or exit from RESET state to
// avoid LINKRESET/DISABLED -> RESET -> LINKERROR false transition on exit LINK_VLSM_LINKRESET or from LINK_VLSM_DISABLE state
always_comb begin
    // Set the flag on transition to RESET state
    if ((vlsm_state_r != LINK_VLSM_RESET) && (vlsm_state_nxt == LINK_VLSM_RESET))
        vlsm_link_down_dis_nxt = 1'b1;
    // Reset the flag on exit from RESET state to PREP_ACTIVE if Link State is RESET. This is required not transition to LINKERROR on
    // exit from L2 state when pl_link_down event occurs
    else if ((vlsm_state_r == LINK_VLSM_RESET) && (vlsm_state_nxt == LINK_VLSM_PREP_ACTIVE) && (b_vlsm_llctrl.s_pl_state_sts == RESET))
        vlsm_link_down_dis_nxt = 1'b0;
    else
        vlsm_link_down_dis_nxt = vlsm_link_down_dis_r;
end

assign almp_rx_req_active_s = almp_rx_req_active || almp_rx_req_active_r;

// Latch received Active State Request ALMP until it is responded if vLSM state is already in Active
always_comb begin
    if (vlsm_rx_req_done)
        almp_rx_req_active_nxt = 1'b0;
    else if (almp_rx_req_active && (vlsm_link_state_r == ACTIVE))
        almp_rx_req_active_nxt = 1'b1;
    else
        almp_rx_req_active_nxt = almp_rx_req_active_r;
end

// Latch received L1/L2 State Request ALMP in the WAIT_ACTIVE state while waiting for the link initialization to complete
always_comb begin
    if (vlsm_state_r != LINK_VLSM_WAIT_ACTIVE) begin
        almp_rx_req_l1_nxt = 1'b0;
        almp_rx_req_l2_nxt = 1'b0;
    end
    else if (vlsm_state_r == LINK_VLSM_WAIT_ACTIVE) begin
        almp_rx_req_l1_nxt = vlsm_almp_req_l1_rcvd ? 1'b1 : almp_rx_req_l1_r;
        almp_rx_req_l2_nxt = vlsm_almp_req_l2_rcvd ? 1'b1 : almp_rx_req_l2_r;
    end
    else begin
        almp_rx_req_l1_nxt = almp_rx_req_l1_r;
        almp_rx_req_l2_nxt = almp_rx_req_l2_r;
    end
end

// Make sure stall_req/ack that handshake is preserved when propagating stall_req from the Physical Layer
always_comb begin
    // Assert pl_stall_req when lp_stall_ack is not asserted or when vLSM already asserted pl_stall_req
    if (pl_stall_req && (!b_vlsm_llctrl.s_lp_stall_ack || link_stall_req_r))
        pl_stall_req_nxt = 1'b1;
    else if (!pl_stall_req && b_vlsm_llctrl.s_lp_stall_ack)
        pl_stall_req_nxt = 1'b0;
    else
        pl_stall_req_nxt = pl_stall_req_r;
end

// -------------------------------------------------------------------------------------
// Link vLSM Debug Information Bus
// -------------------------------------------------------------------------------------
assign vlsm_link_debug_info = '{
    vlsm_state_rslvd        : vlsm_almp_rslvd_state,
    vlsm_state_snap         : vlsm_snap_state_r,
    vlsm_link_stall_req     : b_vlsm_llctrl.s_pl_stall_req,
    vlsm_link_stall_ack     : b_vlsm_llctrl.s_lp_stall_ack,
    vlsm_link_rx_active_req : b_vlsm_llctrl.s_pl_rx_active_req,
    vlsm_link_rx_active_sts : b_vlsm_llctrl.s_lp_rx_active_sts,
    vlsm_link_block_dl_init : b_vlsm_llctrl.s_pl_block_dl_init,
    vlsm_link_dl_active     : b_vlsm_llctrl.s_lp_dl_active,
    vlsm_link_fsm           : {1'b0, vlsm_state_r}
};
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Application PM Interface input/output registers
// -------------------------------------------------------------------------------------
logic  vlsm_tx_sts_pmnak_r; // Input register on the Application request to transmit Status(PMNAK)

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_delay_app_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (vlsm_tx_sts_pmnak),
    .dout  (vlsm_tx_sts_pmnak_r)
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Link vLSM interface to the Link Layer (SPIF) and PM Controller
// -------------------------------------------------------------------------------------
always_comb begin
    if (cfg_vlsm_force_active) begin
        link_stall_req_nxt     = 1'b0;
        link_block_dl_init_nxt = 1'b0;
        link_rx_active_req_nxt = 1'b1;
    end
    else case (vlsm_state_nxt)
        LINK_VLSM_RESET: begin
            // In the Reset state do not allow TX/RX interface initialization
            link_stall_req_nxt     = 1'b1;
            // Asser block_dl_init after link state is updated to RESET on exit from LINKRESET, LINKERROR, DISABLED states
            link_block_dl_init_nxt = link_block_dl_init_r ? 1'b1 : ((b_vlsm_llctrl.s_pl_state_sts == RESET) ? !vlsm_link_down_dis_r : 1'b0);
            link_rx_active_req_nxt = 1'b0;
        end
        LINK_VLSM_PREP_ACTIVE: begin
            link_stall_req_nxt     = 1'b1;
            link_block_dl_init_nxt = link_block_dl_init_r;
            // Assert rx_active_req in this state unless the transition happened from L1 state and the link state hasn't changed to RETRAIN yet
            link_rx_active_req_nxt = (vlsm_link_state_nxt != IDLE_L1_1) && (b_vlsm_llctrl.s_pl_state_sts != IDLE_L1_1);
        end
        LINK_VLSM_WAIT_ACTIVE: begin
            // Request Link Initialization on entry to Active state when 4 ALMP hanshake is completed on transition to ACTIVE state after initial link training
            // For CXS interface wait for CXS RX interface acknowledgement before requesting link initialization to guarantee that any flits following INIT.PARAM
            // can be accepted on the interface. Otherwise all the received traffic will be discarded.
            link_stall_req_nxt     = 1'b0;
            // De-assert block_dl_init if link state is ACTIVE and RX interface is activated
            link_block_dl_init_nxt = ((pl_state_sts == ACTIVE)) ? 1'b0 : link_block_dl_init_r;
            link_rx_active_req_nxt = 1'b1;
        end
        LINK_VLSM_ACTIVE: begin
            // In the Active state allow TX/RX interface initialization
            link_stall_req_nxt     = link_spif_hs_done_r ? link_stall_req_r     : 1'b0; // On transition from ABORT_L1 wait for link_spif_hs_done_r to de-assert
            link_block_dl_init_nxt = link_block_dl_init_r;
            link_rx_active_req_nxt = link_spif_hs_done_r ? link_rx_active_req_r : 1'b1; // On transition from ABORT_L1 wait for link_spif_hs_done_r to de-assert
        end
        LINK_VLSM_PREP_L1: begin
            link_stall_req_nxt     = link_stall_req_r ? 1'b1 : (cxl_device_type ? (vlsm_tx_req_done && !almp_rx_sts_pmnak_s) : (b_vlsm_llctrl.s_lp_state_req == IDLE_L1_1));
            link_block_dl_init_nxt = link_block_dl_init_r;
            // For Upstream Port stall_req must be initiated by the vLSM to de-assert pl_rx_active_req
            link_rx_active_req_nxt = link_rx_active_req_r ? !(cxl_device_type ? (link_stall_req_r && b_vlsm_llctrl.s_lp_stall_ack) : (vlsm_almp_req_l1_rcvd || almp_rx_req_l1_r)) : 1'b0;
        end
        LINK_VLSM_PREP_L2: begin
            link_stall_req_nxt     = link_stall_req_r ? 1'b1 : (cxl_device_type ? (vlsm_tx_req_done && !almp_rx_sts_pmnak_s) : (b_vlsm_llctrl.s_lp_state_req == L2));
            link_block_dl_init_nxt = link_block_dl_init_r;
            // For Upstream Port stall_req must be initiated by the vLSM to de-assert pl_rx_active_req
            link_rx_active_req_nxt = link_rx_active_req_r ? !(cxl_device_type ? (link_stall_req_r && b_vlsm_llctrl.s_lp_stall_ack) : (vlsm_almp_req_l2_rcvd || almp_rx_req_l2_r)) : 1'b0;
        end
        LINK_VLSM_L1, LINK_VLSM_L2: begin
            // Request Link Layer to stall after PM entry hadshake is complete
            link_stall_req_nxt     = 1'b1;
            link_block_dl_init_nxt = link_block_dl_init_r;
            link_rx_active_req_nxt = 1'b0;
        end
        LINK_VLSM_PREP_RESET: begin
            // Entry to Hot-Reset may happen when Physical Layer is in RETRAIN state (LTSSM is in RCVRY_RCVRCFG or RCVRY_IDLE state)
            // and pl_stall_req/lp_stall_ack hanshake is completed.
            // Entry to Link Disable may happen when Physical Layer is in either RETRAIN state (LTSSM is in RCVRY_RCVRCFG or RCVRY_IDLE state) or
            // RESET state (S_CFG_LINKWD_START) and pl_stall_req/lp_stall_ack hanshake is completed.
            // In both scenarios preserve pl_stall_req to be asserted on SPIF interface.
            // On entry to either Hot-Reset or Link Disable state, de-assert pl_rx_active_req on SPIF interface to request
            // the Link Layer to offload messages from the receive buffers and de-activate RX interface as a part of graceful reset flow.
            link_stall_req_nxt     = 1'b1;
            link_block_dl_init_nxt = link_block_dl_init_r;
            link_rx_active_req_nxt = 1'b0;
        end
        LINK_VLSM_RETRAIN: begin
            // On entry to the Physical Recovery state flush the protocol stack Data Link Layer while keeping application interface active
            link_stall_req_nxt     = 1'b1;
            link_block_dl_init_nxt = link_block_dl_init_r;
            link_rx_active_req_nxt = link_rx_active_req_r;
        end
        LINK_VLSM_LINKERROR: begin
            // On Surprise Link Down it is required to communicate the event over CXS interface by inserting INIT.VD.DEACTIVATE flit,
            // therefore vLSM de-asserts pl_rx_active_req on SPIF interface to the Link Layer. Once INIT.VD.DEACTIVATE flit is generated
            // and CXS TX interface is de-activated, Link Layer responds with lp_rx_active_sts=0 to allow reset propagation.
            link_stall_req_nxt     = 1'b1;
            link_block_dl_init_nxt = link_block_dl_init_r;
            // DWC_cxl_cxs_ull_fgen needs the falling edge of s_pl_rx_active_req at the same time of s_pl_state_sts changes to LINKERROR
            link_rx_active_req_nxt = 1'b0;
        end
        default: begin
            link_stall_req_nxt     = link_stall_req_r;
            link_block_dl_init_nxt = link_block_dl_init_r;
            link_rx_active_req_nxt = link_rx_active_req_r;
        end
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Link vLSM FSM
// -------------------------------------------------------------------------------------
always_comb begin : next_state_proc
    // Physical Layer LTSSM in Disabled state. Transition from ANY state to DISABLED except for LINKERROR
    if ((pl_state_sts == DISABLED) && !(vlsm_state_r inside {LINK_VLSM_PREP_RESET, LINK_VLSM_DISABLE, LINK_VLSM_LINKERROR})) begin
        // If vLSM is in RESET or LINKRESET state then transit directly to DISABLED state
        // otherwse transit to DISABLED through PREP_RESET state
        vlsm_state_nxt = (vlsm_state_r inside {LINK_VLSM_RESET, LINK_VLSM_LINKRESET}) ? LINK_VLSM_DISABLE : LINK_VLSM_PREP_RESET;
    end
    // Physical Layer LTSSM in Hot Reset. Transition from ANY state to LINKRESET except for DISABLED and LINKERROR
    else if ((pl_state_sts == LINKRESET) && !(vlsm_state_r inside {LINK_VLSM_PREP_RESET, LINK_VLSM_LINKRESET, LINK_VLSM_DISABLE, LINK_VLSM_LINKERROR})) begin
        // If vLSM is in RESET state then transit directly to DISABLED state
        // otherwse transit to LINKRESET through PREP_RESET state
        vlsm_state_nxt = (vlsm_state_r inside {LINK_VLSM_RESET}) ? LINK_VLSM_LINKRESET : LINK_VLSM_PREP_RESET;
    end
    // Physical Layer LTSSM transitions from L0 to PRE_DETECT_QUIT state. Transition from ANY state to LINKERROR
    else if (pl_state_sts == LINKERROR) begin
        vlsm_state_nxt = LINK_VLSM_LINKERROR;
    end
    // Directed to enter LinkError from Physical Layer on Surprise Link Down. Transition from ANY state to LINKERROR
    else if (b_vlsm_llctrl.s_pl_link_down && !vlsm_link_down_dis_r && !(vlsm_state_r inside {LINK_VLSM_PREP_RESET, LINK_VLSM_L2, LINK_VLSM_LINKRESET, LINK_VLSM_DISABLE, LINK_VLSM_LINKERROR})) begin
        vlsm_state_nxt = LINK_VLSM_LINKERROR;
    end
    // Link Recovery Notification - VLSM enters Retrain from Active state if recovery notification from LTSSM is received (only for CXL1.1/2.0)
    else if ((pl_state_sts == RETRAIN) && pl_stall_req && !(vlsm_state_r inside {LINK_VLSM_RESET, LINK_VLSM_PREP_RESET, LINK_VLSM_RETRAIN}) && !cxl_pcie_flit_mode) begin
        vlsm_state_nxt = LINK_VLSM_RETRAIN;
    end
    // If Status ALMP is received without first sending Request ALMP then request link retrain (only for CXL1.1/2.0 - vlsm_almp_unexp_error is gated in ALMP Generator)
    else if (vlsm_almp_unexp_error && (vlsm_state_r inside {LINK_VLSM_WAIT_ACTIVE, LINK_VLSM_ACTIVE, LINK_VLSM_PREP_L1, LINK_VLSM_L1, LINK_VLSM_PREP_L2})) begin
        vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
    end
    else begin
        unique case (vlsm_state_r)
            // Transitional state to ACTIVE - Performs 4 ALMP exchange handshake on transition to ACTIVE state
            LINK_VLSM_PREP_ACTIVE: begin
                // When an Active Request ALMP has been sent, receipt of any ALMP other than an
                // Active State Status ALMP or an Active Request ALMP is considered an unexpected
                // ALMP and will trigger recovery
                if (vlsm_almp_unexp_error)
                    vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
                // If Recovery is exposed to the ARB/MUX then move to the RETRAIN state when
                // LogPHY goes to the recovery with pl_state_sts == RESET whithout changing the Link State.
                else if (b_smlh_spif.s_pl_phyinretrain && (pl_state_sts == RESET))
                    vlsm_state_nxt = LINK_VLSM_RETRAIN;
                // The ALMP protocol required for the entry to active consists of 4 ALMP exchanges
                // between the local and remote vLSMs. Once all four ALMPs are received, the vLSM 
                // states transition to Active State.
                else if (vlsm_tx_req_done && vlsm_rx_req_done)
                    // If Link Initialization is completed then transit directly to LINK_VLSM_ACTIVE state
                    // otherwise move to LINK_VLSM_WAIT_ACTIVE and wait for Link Initialization completion
                    vlsm_state_nxt = b_vlsm_llctrl.s_lp_dl_active ? LINK_VLSM_ACTIVE : LINK_VLSM_WAIT_ACTIVE;
                else
                    vlsm_state_nxt = LINK_VLSM_PREP_ACTIVE;
            end
            // Transitional state to ACTIVE - Waits for the Link Initialization to complete on transition to ACTIVE state on exit from RESET
            LINK_VLSM_WAIT_ACTIVE: begin
                // If link is active, Link Layer may request link retrain (only for CXL1.1/2.0)
                if ((b_vlsm_llctrl.s_lp_state_req == RETRAIN) && !cxl_pcie_flit_mode)
                    vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
                // Wait for Link Initialization Acknowledge for transition to LINK_VLSM_ACTIVE state
                else if (b_vlsm_llctrl.s_lp_dl_active)
                    vlsm_state_nxt = LINK_VLSM_ACTIVE;
                else
                    vlsm_state_nxt = LINK_VLSM_WAIT_ACTIVE;
            end
            // Normal operational state
            LINK_VLSM_ACTIVE : begin
                // If link is active, Link Layer may request link retrain (only for CXL1.1/2.0)
                if ((b_vlsm_llctrl.s_lp_state_req == RETRAIN) && !cxl_pcie_flit_mode)
                    vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
                // Prepare for L1 Entry when Link Layer requests L1 Entry for USP or Request L1 ALMP is received at DSP
                // cfg_vlsm_pm_enable is only used by DSP to reject Power Request from USP
                // Incase of Flit Mode if cfg_vlsm_pm_enable is disabled the DSP will always reply with PMNAK
                else if ( 
                  cxl_device_type ? ((b_vlsm_llctrl.s_lp_state_req == IDLE_L1_1) && b_vlsm_llctrl.s_lp_rx_active_sts) : 
                                    ((vlsm_almp_req_l1_rcvd || almp_rx_req_l1_r) && cfg_vlsm_pm_enable)
                        )
                    vlsm_state_nxt = LINK_VLSM_PREP_L1;
                // Prepare for L2 Entry when Link Layer requests L2 Entry for USP or Request L2 ALMP is received at DSP
                else if ( 
                  cxl_device_type ? ((b_vlsm_llctrl.s_lp_state_req == L2) && b_vlsm_llctrl.s_lp_rx_active_sts) : 
                                    ((vlsm_almp_req_l2_rcvd || almp_rx_req_l2_r) && cfg_vlsm_pm_enable)
                        )
                    vlsm_state_nxt = LINK_VLSM_PREP_L2;
                else if ( !cxl_device_type &&  !cfg_vlsm_pm_enable && ((vlsm_almp_req_l2_rcvd || almp_rx_req_l2_r)  || (vlsm_almp_req_l1_rcvd || almp_rx_req_l1_r)) && cxl_pcie_flit_mode)
                    vlsm_state_nxt = LINK_VLSM_ACTIVE_PMNAK;
                else
                    vlsm_state_nxt = LINK_VLSM_ACTIVE;
            end
            // Transitional state to L1 - Perform Request/Status ALMP handshake on entry to PM state
            LINK_VLSM_PREP_L1 : begin
                // Downstream Component (USP) - Endpoint device
                if (cxl_device_type) begin
                    // If PM Entry ALMP handshake is complete and DSP rejected PM Entry request then
                    // transition of ACTIVE_PMNAK and wait for the request to enter Active from the Link Layer
                    if (vlsm_tx_req_done && almp_rx_sts_pmnak && cxl_pcie_flit_mode)
                         vlsm_state_nxt = LINK_VLSM_ACTIVE_PMNAK;
                    else
                    // If PM Entry ALMP handshake is done then move to PM state to complete L1 Entry
                    // unless Active Request ALMP is received in the same cycle. In this case transit to PREP_ACTIVE state to exit from L1 state.
                    // This situation may happen only when back-to-back L1 State Status and Active State Request ALMPs are receiced,
                    if (vlsm_tx_req_done) begin
                        // Wait for rx_active_req/sts to complete before changing the state
                        if (!b_vlsm_llctrl.s_lp_rx_active_sts)
                            vlsm_state_nxt = almp_rx_req_active_s ? LINK_VLSM_PREP_ACTIVE : LINK_VLSM_L1;
                        else
                            vlsm_state_nxt = LINK_VLSM_PREP_L1;
                    end
                    // If Link Layer requests ACTIVE state transition before Status(L1) ALMP is received then abort L1 Entry (only for CXL1.1/CXL2.0):
                    // 1) if de-asserted after sending Request(L1) ALMP then transit to ABORT_L1 state
                    // 2) if de-asserted before sending Request(L1) ALMP then transit back to ACTIVE state if PM Phase 1 negotiation is not applicable
                    else if ((b_vlsm_llctrl.s_lp_state_req == ACTIVE) && !cxl_pcie_flit_mode) begin
                        // If PM_PHASE1_ENABLE is set always wait for L1 Request ALMP to be sent before attempting to abort L1 entry.
                        // This is require to notify PM Link FSM about PM exit event, otherwise if we silently abort L1 then the remote
                        // partner's Phase 1 FSM will remain stuck
                        if (PM_PHASE1_ENABLE ? vlsm_almp_req_sent : 1'b1)
                            vlsm_state_nxt = LINK_VLSM_ABORT_L1;
                        else
                            vlsm_state_nxt = LINK_VLSM_PREP_L1;
                    end
                    else
                        vlsm_state_nxt = LINK_VLSM_PREP_L1;
                end
                // Upstream Component (DSP) - Root-Complex device
                else begin
                    // If Transaction Layer is not de-initialized and henc PM Entry request is not accepted within 10us then
                    // transition to ACTIVE_PMNAK state to respond with Status(Active.PMNAK) and complete PM request handshake
                    if ((almp_pm_req_timeout || vlsm_tx_sts_pmnak_r) && (b_vlsm_llctrl.s_lp_state_req != IDLE_L1_1) && cxl_pcie_flit_mode)
                        vlsm_state_nxt = LINK_VLSM_ACTIVE_PMNAK;
                    else
                    // USP may abort L1 Entry request by sending Request(Active) ALMP, following two cases may
                    // occur when DSP in the transitional state to L1 (only for CXL1.1/CXL2.0):
                    // 1) If Request(Active) ALMP is received after sending Status(L1) ALMP then transit to PREP_ACTIVE state via LINK_VLSM_L1 state
                    // 2) If Request(Active) ALMP is received before sending Status(L1) ALMP then transit to ABORT_L1 state
                    if (almp_rx_req_active && !cxl_pcie_flit_mode)
                        vlsm_state_nxt = vlsm_rx_req_done ? LINK_VLSM_PREP_ACTIVE : LINK_VLSM_ABORT_L1;
                    // If PM Entry ALMP handshake is done then transition to PM state to complete L1 Entry
                    else if (vlsm_rx_req_done)
                        vlsm_state_nxt = LINK_VLSM_L1;
                    else
                        vlsm_state_nxt = LINK_VLSM_PREP_L1;
                end
            end
            LINK_VLSM_ACTIVE_PMNAK: begin
                // Downstream Component (USP) - Endpoint device
                if (cxl_device_type) begin
                    // Move to VLSM_ACTIVE after Application requests entry to Active
                    vlsm_state_nxt = (b_vlsm_llctrl.s_lp_state_req == ACTIVE) ? LINK_VLSM_ACTIVE : LINK_VLSM_ACTIVE_PMNAK;
                end
                // Upstream Component (DSP) - Root-Complex device
                else begin
                    // Move to VLSM_ACTIVE after sending Status(Active.PMNAK)
                    vlsm_state_nxt = vlsm_rx_req_done ? LINK_VLSM_ACTIVE : LINK_VLSM_ACTIVE_PMNAK;
                end
            end
            LINK_VLSM_ABORT_L1: begin
                // Downstream Component (USP) - Endpoint device
                if (cxl_device_type) begin
                    // This state implements following L1 Abort scenarios for USP:
                    // 1) PM Abort After Downstream Port PM acceptance, USP transmits Request Active ALMP and 
                    //    receives Status L1 ALMP which triggers an unexpected ALMP Error which must bring 
                    //    the link to the Recovery
                    if (vlsm_almp_unexp_error)
                        vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
                    // 2) PM Abort before Downstream Port PM acceptance, USP transmits Request Active ALMP and 
                    //    receives Status Active ALMP which brings vLSM back to the ACTIVE state
                    // 3) If L1 Request ALMP has not been sent in PREP_L1 state then directly exit to ACTIVE state,
                    //    no ALMP handshake is required (applicable only to protocols that do not have Phase 1 entry)
                    else if ((vlsm_tx_req_done && !vlsm_abort_entry_r) || (!vlsm_almp_req_sent && vlsm_abort_entry_r))
                        vlsm_state_nxt = LINK_VLSM_ACTIVE;
                    // If Status L1 ALMP is received on a cycle we are transitioning to ABORT_L1 state then
                    // go to PREP_ACTIVE state
                    else if (vlsm_tx_req_done && vlsm_abort_entry_r)
                        vlsm_state_nxt = LINK_VLSM_PREP_ACTIVE;
                    else
                        vlsm_state_nxt = LINK_VLSM_ABORT_L1;
                end
                // Upstream Component (DSP) - Root-Complex device
                else begin
                    // This corresponds to USP PM Abort sceanrio (2) PM Abort before Downstream Port PM acceptance
                    // If Downstream Component aborts L1 Entry request by sending Request(Active) ALMP then
                    // respond with Status(Active) ALMP and transit back to ACTIVE state.
                    if (vlsm_rx_req_done)
                        vlsm_state_nxt = LINK_VLSM_ACTIVE;
                    else
                        vlsm_state_nxt = LINK_VLSM_ABORT_L1;
                end
            end
            // Power savings state, from which the link can enter Active via Retrain
            LINK_VLSM_L1 : begin
                // If Request(Active) ALMP is received from the remote partner requesting L1 Exit
                // then change the Link State to RETRAIN and move to PREP_ACTIVE state and respond with
                // Status(Active) ALMP
                if (almp_rx_req_active)
                    vlsm_state_nxt = LINK_VLSM_PREP_ACTIVE;
                // When L1 Exit is requested transit to PREP_ACTIVE state to send Request(Active) ALMP
                else if ((b_vlsm_llctrl.s_lp_state_req == ACTIVE) && (pl_state_sts == ACTIVE))
                    vlsm_state_nxt = LINK_VLSM_PREP_ACTIVE;
                else
                    vlsm_state_nxt = LINK_VLSM_L1;
            end
            // Transitional state to L2 - Perform Request/Status ALMP handshake on entry to PM state
            // Note: Same as LINK_VLSM_PREP_L1 except for ABORT scenarios which are not applicable for L2 state
            LINK_VLSM_PREP_L2 : begin
                // Downstream Component (USP) - Endpoint device
                if (cxl_device_type) begin
                    // If PM Entry ALMP handshake is complete and DSP rejected PM Entry request then
                    // transition of ACTIVE_PMNAK and wait for the request to enter Active from the Link Layer
                    if (vlsm_tx_req_done && almp_rx_sts_pmnak && cxl_pcie_flit_mode)
                         vlsm_state_nxt = LINK_VLSM_ACTIVE_PMNAK;
                    else
                    // If PM Entry ALMP handshake is done then move to PM state to complete PM Entry
                    if (vlsm_tx_req_done && !b_vlsm_llctrl.s_lp_rx_active_sts)
                        vlsm_state_nxt = LINK_VLSM_L2;
                    else
                        vlsm_state_nxt = LINK_VLSM_PREP_L2;
                end
                // Upstream Component (DSP) - Root-Complex device
                else begin
                    // If Transaction Layer is not de-initialized and henc PM Entry request is not accepted within 10us then
                    // transition to ACTIVE_PMNAK state to respond with Status(Active.PMNAK) and complete PM request handshake
                    if ((almp_pm_req_timeout || vlsm_tx_sts_pmnak_r) && (b_vlsm_llctrl.s_lp_state_req != L2) && cxl_pcie_flit_mode)
                        vlsm_state_nxt = LINK_VLSM_ACTIVE_PMNAK;
                    else
                    // If PM Entry ALMP handshake is done then transition to PM state to complete PM Entry
                    if (vlsm_rx_req_done)
                        vlsm_state_nxt = LINK_VLSM_L2;
                    else
                        vlsm_state_nxt = LINK_VLSM_PREP_L2;
                end
            end
            // Power savings state, from which the link must go through Reset to reach Active
            LINK_VLSM_L2 : begin
                if (b_vlsm_llctrl.s_pl_link_down || (b_vlsm_llctrl.s_lp_state_req == ACTIVE))
                    vlsm_state_nxt = LINK_VLSM_RESET;
                else
                    vlsm_state_nxt = LINK_VLSM_L2;
            end
            LINK_VLSM_LINKRESET : begin
                // Exit LINK_VLSM_LINKRESET state when either of following conditions is met:
                // 1) On Physical Layer link down followed Hot-Reset entry
                // 2) When Link Layer requests ACTIVE state and Physical Layer is in RESET state, i.e. no more in LINKRESET state
                if (b_vlsm_llctrl.s_pl_link_down || ((pl_state_sts == RESET) && (b_vlsm_llctrl.s_lp_state_req == ACTIVE)))
                    vlsm_state_nxt = LINK_VLSM_RESET;
                else
                    vlsm_state_nxt = LINK_VLSM_LINKRESET;
            end
            LINK_VLSM_DISABLE : begin
                // Exit LINK_VLSM_DISABLE state when either of following conditions is met:
                // 1) On Physical Layer link down followed Link Disable entry
                // 2) When Link Layer requests ACTIVE state and Physical Layer is in RESET, i.e. no more in DISABLED state
                if (b_vlsm_llctrl.s_pl_link_down || ((pl_state_sts == RESET) && (b_vlsm_llctrl.s_lp_state_req == ACTIVE)))
                    vlsm_state_nxt = LINK_VLSM_RESET;
                else
                    vlsm_state_nxt = LINK_VLSM_DISABLE;
            end
            LINK_VLSM_LINKERROR : begin
                if (b_vlsm_llctrl.s_pl_link_down || ((pl_state_sts == RESET) && (b_vlsm_llctrl.s_lp_state_req == ACTIVE)))
                    vlsm_state_nxt = LINK_VLSM_RESET;
                else
                    vlsm_state_nxt = LINK_VLSM_LINKERROR;
            end
            // Transitory state that transitions to Retrain
            LINK_VLSM_PREP_RETRAIN : begin
                // Wait for LTSSM to accept Recovery before transition to RETRAIN state
                if (b_smlh_spif.s_pl_phyinretrain)
                    vlsm_state_nxt = LINK_VLSM_RETRAIN;
                else
                    vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
            end
            // Transitory state that transitions to Active
            LINK_VLSM_RETRAIN : begin
                // Wait for LTSSM to exit from RETRAIN state before initiating State Status Exchange handshake
                if (!b_smlh_spif.s_pl_phyinretrain)
                    vlsm_state_nxt = LINK_VLSM_EXIT_RETRAIN;
                else
                    vlsm_state_nxt = LINK_VLSM_RETRAIN;
            end
            LINK_VLSM_EXIT_RETRAIN : begin
                // When in the Synchronization portion on exit from Retrain, any ALMP other than a
                // Status ALMP is considered an unexpected ALMP and will trigger recovery.
                if (vlsm_almp_unexp_error)
                    vlsm_state_nxt = LINK_VLSM_PREP_RETRAIN;
                // The Status ALMPs for synchronization may trigger a State
                // Request ALMP if the provided state and the requested state are not the same
                else if (vlsm_tx_sts_done && vlsm_tx_sts_error) begin
                    // New State Request and Status ALMP exchanges when applicable.
                    case (b_vlsm_llctrl.s_lp_state_req)
                        RESET    : vlsm_state_nxt = LINK_VLSM_RESET;
                        //IDLE_L1_1: vlsm_state_nxt = LINK_VLSM_PREP_L1;
                        //L2       : vlsm_state_nxt = LINK_VLSM_PREP_L2;
                        default  : vlsm_state_nxt = LINK_VLSM_PREP_ACTIVE;
                    endcase
                end
                // If the provided states from both vLSMs are the same as the requested state
                // prior to the Recovery, the vLSMs are considered be synchronized and will move
                // to the state it was before the recovery
                else if (vlsm_tx_sts_done && !vlsm_tx_sts_error) begin
                    //vlsm_state_nxt = LINK_VLSM_ACTIVE;
                    case (b_vlsm_llctrl.s_lp_state_req)
                        RESET    : vlsm_state_nxt = LINK_VLSM_RESET;
                        IDLE_L1_1: vlsm_state_nxt = LINK_VLSM_L1;
                        L2       : vlsm_state_nxt = LINK_VLSM_L2;
                        default  : vlsm_state_nxt = !b_vlsm_llctrl.s_lp_dl_active ? LINK_VLSM_WAIT_ACTIVE : LINK_VLSM_ACTIVE;
                    endcase
                end
                else
                    vlsm_state_nxt = LINK_VLSM_EXIT_RETRAIN;
            end
            LINK_VLSM_PREP_RESET : begin
                // Wait for Link Layer to offload messages from the receive buffers and acknowledge RX de-activation
                // before making a transition to either LINKRESET or DISABLED state correspondingly
                if (!b_vlsm_llctrl.s_lp_rx_active_sts)
                    vlsm_state_nxt = (pl_state_sts == LINKRESET) ? LINK_VLSM_LINKRESET : LINK_VLSM_DISABLE;
                else
                    vlsm_state_nxt = LINK_VLSM_PREP_RESET;
            end
            // Power-on default state during which initialization occurs
            default : begin // LINK_VLSM_RESET
                // Link Layer is asking for Active. Initiate entry to Active ALMP
                // exchange protocol.
                if (!vlsm_bypass_enable_r && (b_vlsm_llctrl.s_lp_state_req == ACTIVE) && b_vlsm_llctrl.s_pl_link_up) begin
                    vlsm_state_nxt = LINK_VLSM_PREP_ACTIVE;
                end
                else
                    vlsm_state_nxt = LINK_VLSM_RESET;
            end
        endcase
    end
end : next_state_proc

// vLSM state snapshot before entring to the Recovery
always_comb begin : vlsm_snap_proc
    if ((vlsm_state_nxt == LINK_VLSM_RETRAIN) && !vlsm_sts_exch_pend_r) begin
        // A snapshot of the vLSM is taken before entry to LTSSM Recovery if the
        // STATUS_EXCHANGE_PENDING variable is clear for that vLSM.
        vlsm_snap_state_nxt = vlsm_link_state_nxt;
        //A STATUS_EXCHANGE_PENDING variable is set for a vLSM once a snapshot is taken.
        vlsm_sts_exch_pend_nxt = 1'b1;
    end
    else if ((vlsm_state_nxt != LINK_VLSM_RETRAIN) && (vlsm_state_r == LINK_VLSM_EXIT_RETRAIN) && (vlsm_state_nxt != LINK_VLSM_EXIT_RETRAIN)) begin
        // Keep state snapshot
        vlsm_snap_state_nxt = vlsm_snap_state_r;
        // STATUS_EXCHANGE_PENDING variable is cleared on completion of Status Exchange
        vlsm_sts_exch_pend_nxt = 1'b0;
    end
    else begin
        // Keep state snapshot and STATUS_EXCHANGE_PENDING value 
        vlsm_snap_state_nxt = vlsm_snap_state_r;
        vlsm_sts_exch_pend_nxt = vlsm_sts_exch_pend_r;
    end
end : vlsm_snap_proc

// -------------------------------------------------------------------------------------
// Link VLSM to ALMP Generator requests
// -------------------------------------------------------------------------------------
always_comb begin
    if (vlsm_state_r == LINK_VLSM_RETRAIN)
        almp_tx_status_nxt = (pl_state_sts == RETRAIN) ? 1'b1 : almp_tx_status_r;
    else
        almp_tx_status_nxt = 1'b0;
end

always_comb begin : vlsm_out_proc
    almp_tx_request   = 1'b0;
    almp_tx_req_state = b_vlsm_llctrl.s_lp_state_req;

    almp_tx_status    = 1'b0;
    almp_tx_sts_ena   = 1'b0;
    almp_tx_sts_state = RESET;

    unique case(vlsm_state_r)
        LINK_VLSM_PREP_ACTIVE : begin
            almp_tx_request   = vlsm_link_enable;
            almp_tx_req_state = ACTIVE;

            almp_tx_sts_ena   = vlsm_link_enable && b_vlsm_llctrl.s_lp_rx_active_sts;
            almp_tx_sts_state = ACTIVE;
        end
        LINK_VLSM_WAIT_ACTIVE, LINK_VLSM_ACTIVE : begin
            // In Active state respond with Status Active ALMP to Request Active ALMP
            if (almp_rx_req_active_s) begin
                almp_tx_sts_ena   = 1'b1;
                almp_tx_sts_state = ACTIVE;
            end
        end
        LINK_VLSM_PREP_L1 : begin
            // Downstream Component (USP) - Endpoint device
            if (cxl_device_type) begin
                // If L1 Entry is requested then send Request(L1) ALMP once TX TL is de-initialized
                almp_tx_request   = !(vlsm_tx_req_done && (!b_vlsm_llctrl.s_lp_rx_active_sts || almp_rx_sts_pmnak_s)); 
                almp_tx_req_state = IDLE_L1_1;

                almp_tx_sts_ena   = 1'b0;
                almp_tx_sts_state = ACTIVE;
            end
            // Upstream Component (DSP) - Root-Complex device
            else begin
                // Enable Status(L1) ALMP Response for L1 when de-initialization is acknowledged by Transaction Layer
                // For Downstream Port wait for RX interface de-activation before acknowledging L1 Entry and transmitting L1 State Status ALMP
                almp_tx_sts_ena   = link_stall_req_r && b_vlsm_llctrl.s_lp_stall_ack && !b_vlsm_llctrl.s_lp_rx_active_sts && !almp_rx_req_active;
                almp_tx_sts_state = IDLE_L1_1;
            end
        end
        LINK_VLSM_L1 : begin
            almp_tx_sts_state = IDLE_L1_1;
        end
        LINK_VLSM_ACTIVE_PMNAK: begin
            // For DSP, enable Active.PMNAK Status response to L1 Request ALMP
            if (!cxl_device_type) begin
                almp_tx_sts_ena   = 1'b1;
                almp_tx_sts_state = ACTIVE_L0S_PMNAK;
            end
        end
        LINK_VLSM_ABORT_L1 : begin
            // Downstream Component (USP) - Endpoint device
            if (cxl_device_type) begin
                // Send Request(Active) ALMP to abort L1 Entry after all handshakes on SPIF interface are complete
                // De-assert almp_tx_request on transition from PREP_L1 to ABORT_L1 state to reset ALMP TX FSM
                almp_tx_request   = !vlsm_abort_entry_r && !vlsm_tx_req_done && link_spif_hs_done_s; // De-assert tx_request on transition to ACTIVE state
                almp_tx_req_state = ACTIVE;
            end
            // Upstream Component (DSP) - Root-Complex device
            else begin
                // For DSP, the transition to ABORT_L1 may happen only when vLSM haven't responded with Status(L1) ALMP
                // Respond with Status(Active) ALMP to abort L1 Entry after all handshakes on SPIF interface are complete
                almp_tx_sts_ena   = link_spif_hs_done_s;
                almp_tx_sts_state = ACTIVE;
            end
        end
        LINK_VLSM_PREP_L2 : begin
            // Downstream Component (USP) - Endpoint device
            if(cxl_device_type) begin
                // If L2 Entry is requested then send Request(L1) ALMP once TX TL is de-initialized
                almp_tx_request   = 1'b1;//b_vlsm_llctrl.s_lp_stall_ack;
                almp_tx_req_state = L2;
            end
            // Upstream Component (DSP) - Root-Complex device
            else begin
                // Enable Status(L2) ALMP Response for L2 when de-initialization is acknowledged by Transaction Layer
                almp_tx_sts_ena   = (b_vlsm_llctrl.s_lp_state_req == L2) && b_vlsm_llctrl.s_lp_stall_ack && !b_vlsm_llctrl.s_lp_rx_active_sts;
                almp_tx_sts_state = L2;
            end
        end
        LINK_VLSM_L2 : begin
            almp_tx_sts_state = L2;
        end
        LINK_VLSM_PREP_RETRAIN : begin
            almp_tx_sts_state = vlsm_snap_state_r;
        end
        LINK_VLSM_RETRAIN : begin
            // In RETRAIN state assert almp_tx_status as Status ALMP can be received before transition to EXIT_RETRAIN
            // This is required not to report unexpected ALMP error due to Status ALMP received outside of State Status Synchronization
            // Note: once asserted preserve almp_tx_status state until transition to LINK_VLSM_EXIT_RETRAIN
            almp_tx_status    = almp_tx_status_r;
            almp_tx_sts_state = vlsm_snap_state_r;
        end
        LINK_VLSM_EXIT_RETRAIN : begin
            // On Exit from Recovery, the vLSMs on either side of the channel will send a Status ALMP
            // in order to synchronize the VLSMs. The Status ALMP will provide the state of the vLSM
            // prior to it entering Retrain.
            almp_tx_status    = 1'b1;
            almp_tx_sts_state = vlsm_snap_state_r;
        end
        LINK_VLSM_PREP_RESET : begin
            almp_tx_sts_state = (pl_state_sts == LINKRESET) ? LINKRESET : DISABLED;
        end
        LINK_VLSM_DISABLE : begin
            almp_tx_sts_state = DISABLED;
        end
        LINK_VLSM_LINKRESET : begin
            almp_tx_sts_state = LINKRESET;
        end
        LINK_VLSM_LINKERROR : begin
            almp_tx_sts_state = LINKERROR;
        end
        default : begin
            almp_tx_request   = 1'b0;
            almp_tx_req_state = b_vlsm_llctrl.s_lp_state_req;
            almp_tx_status    = 1'b0;
            almp_tx_sts_ena   = 1'b0;
            almp_tx_sts_state = RESET;
        end
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Implements ARB/MUX state transition table as defined in CXL Specification Table 60
//
// A state transition on pl_state_sts from ACTIVE to any other state must only occur on 
// clocks in which both pl_stall_req and lp_stall_ack are both asserted.
// It is not required to complete stall_req/ack handshake on transition to LINKERROR state
// -------------------------------------------------------------------------------------
always_comb begin
    vlsm_link_state_nxt = vlsm_link_state_r;

    if (cfg_vlsm_force_active) vlsm_link_state_nxt = ACTIVE;
    else unique case(vlsm_state_r)
        LINK_VLSM_PREP_ACTIVE : begin
            // Entry to Active ALMP exchange protocol is complete:
            // Reset-Active  : 1) Link Layer is asking for Active
            // Retrain-Active: 2) Physical Layer transitions from Recovery to L0 and State Status ALMP synchronization for Recovery exit does not resolve to Active.
            // Retrain-Active: 3) Physical Layer has been in L0
            if (vlsm_tx_req_done && vlsm_rx_req_done)
                vlsm_link_state_nxt = ACTIVE;
            // L1-Retrain: Upon receiving an ALMP Active request from remote ARB/MUX
            else if (almp_rx_req_active_s && (vlsm_link_state_r == IDLE_L1_1)) 
                vlsm_link_state_nxt = RETRAIN;
        end
        LINK_VLSM_PREP_L1 : begin
            // Active-Active.PMNAK: Upon receiving a PMNAK ALMP from the Downstream ARB/MUX
            if (cxl_pcie_flit_mode && cxl_device_type && vlsm_tx_req_done && almp_rx_sts_pmnak) begin // CXL3.0
                vlsm_link_state_nxt = ACTIVE_L0S_PMNAK;
            end
            else
            // Active-L1: Upon receiving a Request to enter L1 from Link Layer and L1 Entry ALMP hadshake is complete
            // For Upstream Port wait for RX path de-activation to complete as changing the state immediately after ALMP
            // handshake is done, may result in clocks being gated by PM Controller
            if (cxl_device_type ? (vlsm_tx_req_done && !b_vlsm_llctrl.s_lp_rx_active_sts) : vlsm_rx_req_done) begin
                // If request to enter L1 from the Link Layer is asserted and L1 Entry ALMP handshake is complete
                // then change Link State to IDLE_L1_1
                vlsm_link_state_nxt = IDLE_L1_1;
            end
        end
        LINK_VLSM_PREP_L2 : begin
            // Active-Active.PMNAK: Upon receiving a PMNAK ALMP from the Downstream ARB/MUX
            if (cxl_pcie_flit_mode && cxl_device_type && vlsm_tx_req_done && almp_rx_sts_pmnak) begin // CXL3.0
                vlsm_link_state_nxt = ACTIVE_L0S_PMNAK;
            end
            else
            // Active-L2: Upon receiving a Request to enter L2 from Link Layer and L2 Entry ALMP hadshake is complete
            // For Upstream Port wait for RX path de-activation to complete as changing the state immediately after ALMP
            // handshake is done, may result in clocks being gated by PM Controller
            if (cxl_device_type ? (vlsm_tx_req_done && !b_vlsm_llctrl.s_lp_rx_active_sts) : vlsm_rx_req_done) begin
                vlsm_link_state_nxt = L2;
            end
        end
        LINK_VLSM_ABORT_L1: begin
            // If Upstream Port requests L1 abort in the same cycle as L1 Status is received then
            // change the link state to IDLE_L1_1 before starting 4 ALMP exchange handshake on entry to the ACTIVE state
            if (cxl_device_type && vlsm_tx_req_done && vlsm_abort_entry_r) begin
                vlsm_link_state_nxt = IDLE_L1_1;
            end
        end
        LINK_VLSM_L1 : begin
            // L1-Retrain: Upon receiving an ALMP Active request from remote ARB/MUX
            if (almp_rx_req_active) begin
                // If Request(Active) ALMP is received requesting L1 Exit by remote partner then Status state must be RETRAIN
                vlsm_link_state_nxt = RETRAIN;
            end
        end
        LINK_VLSM_ACTIVE_PMNAK: begin
            // Active.PMNAK-Active: For 256B Flit mode: Upon receiving a request to enter Active from the Link Layer.
            if (cxl_pcie_flit_mode && cxl_device_type && (b_vlsm_llctrl.s_lp_state_req == ACTIVE)) begin // CXL3.0
                vlsm_link_state_nxt = ACTIVE;
            end
        end
        LINK_VLSM_RETRAIN : begin
            // Active-Retrain: 1) Physical Layer LTSSM enters Recovery.
            // Keep link state Active while flushing the datapath on entry to the recovery
            if ((b_vlsm_llctrl.s_pl_state_sts == ACTIVE) && (pl_state_sts == RETRAIN) && b_vlsm_llctrl.s_lp_stall_ack) vlsm_link_state_nxt = RETRAIN;
        end
        LINK_VLSM_EXIT_RETRAIN : begin
            // Active-Retrain: 2) Physical Layer transitions from Recovery to L0 and State Status ALMP synchronization for Recovery exit resolves to Retrain.
            //                 Valid only for Downstream Component (USP) - Endpoint device
            if (cxl_device_type && vlsm_tx_sts_done && (vlsm_almp_rslvd_state == RETRAIN))
                vlsm_link_state_nxt = RETRAIN;
            // Active-Reset: Physical Layer transitions from Recovery to L0 and State Status ALMP synchronization for Recovery exit resolves to Reset.
            //               Valid only for Downstream Component (USP) - Endpoint device
            else if (cxl_device_type && vlsm_tx_sts_done && (vlsm_almp_rslvd_state == RESET))
                vlsm_link_state_nxt = RESET;
            // Retrain-Active: 1) Physical Layer transitions from Recovery to L0 and State Status ALMP synchronization for Recovery exit resolves to Active.
            // Reset-Active  : 2) Physical Layer transitions from Recovery to L0 and State Status ALMP synchronization for Recovery exit resolves to Active.
            else if (vlsm_tx_sts_done && (vlsm_almp_rslvd_state == ACTIVE))
                vlsm_link_state_nxt = ACTIVE;
        end
        LINK_VLSM_PREP_RESET : begin
            // ANY-LinkReset: Physical Layer is on entry to Hot-Reset and RX de-activation is acknowledged
            // ANY-Disable: Physical Layer is on entry to Disable and RX de-activation is acknowledged
            if (!b_vlsm_llctrl.s_lp_rx_active_sts) vlsm_link_state_nxt = (pl_state_sts == LINKRESET) ? LINKRESET : DISABLED;
        end
        LINK_VLSM_DISABLE : begin
            vlsm_link_state_nxt = DISABLED;
        end
        LINK_VLSM_LINKRESET : begin
            vlsm_link_state_nxt = LINKRESET;
        end
        LINK_VLSM_LINKERROR : begin
            vlsm_link_state_nxt = LINKERROR;
        end
        LINK_VLSM_RESET : begin
            // ANY-LinkReset-Reset  : Physical Layer LTSSM in Hot Reset
            // ANY-LinkDisable-Reset: Physical Layer LTSSM in Disabled state
            vlsm_link_state_nxt = RESET;
        end
        default: begin
            vlsm_link_state_nxt = vlsm_link_state_r;
        end
    endcase
end
// -------------------------------------------------------------------------------------


always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        vlsm_state_r           <= # TP LINK_VLSM_RESET;
        vlsm_snap_state_r      <= # TP RESET;
        vlsm_sts_exch_pend_r   <= # TP 1'b0;
        vlsm_link_state_r      <= # TP RESET;
        vlsm_abort_entry_r     <= # TP 1'b0;
        vlsm_link_down_dis_r   <= # TP 1'b0;
        almp_rx_req_l1_r       <= # TP 1'b0;
        almp_rx_req_l2_r       <= # TP 1'b0;
        almp_rx_req_active_r   <= # TP 1'b0;
        almp_tx_status_r       <= # TP 1'b0;
        link_stall_req_r       <= # TP 1'b0;
        link_block_dl_init_r   <= # TP 1'b0;
        link_rx_active_req_r   <= # TP 1'b0;
        link_spif_hs_done_r    <= # TP 1'b0;
        spif_protocol_vld_r    <= # TP 1'b0;
        vlsm_bypass_enable_r   <= # TP 1'b0;
        pl_stall_req_r         <= # TP 1'b0;
    end
    else begin
        vlsm_state_r           <= # TP vlsm_state_nxt;
        vlsm_snap_state_r      <= # TP vlsm_snap_state_nxt;
        vlsm_sts_exch_pend_r   <= # TP vlsm_sts_exch_pend_nxt;
        vlsm_link_state_r      <= # TP vlsm_link_state_nxt;
        vlsm_abort_entry_r     <= # TP vlsm_abort_entry_s;
        vlsm_link_down_dis_r   <= # TP vlsm_link_down_dis_nxt;
        almp_rx_req_l1_r       <= # TP almp_rx_req_l1_nxt;
        almp_rx_req_l2_r       <= # TP almp_rx_req_l2_nxt;
        almp_rx_req_active_r   <= # TP almp_rx_req_active_nxt;
        almp_tx_status_r       <= # TP almp_tx_status_nxt;
        link_stall_req_r       <= # TP link_stall_req_nxt;
        link_block_dl_init_r   <= # TP link_block_dl_init_nxt;
        link_rx_active_req_r   <= # TP link_rx_active_req_nxt;
        link_spif_hs_done_r    <= # TP link_spif_hs_done_s;
        spif_protocol_vld_r    <= # TP b_smlh_spif.s_pl_protocol_vld;
        vlsm_bypass_enable_r   <= # TP spif_protocol_vld_r ? vlsm_bypass_enable : vlsm_bypass_enable_r;
        pl_stall_req_r         <= # TP pl_stall_req_nxt;
    end
end


endmodule
