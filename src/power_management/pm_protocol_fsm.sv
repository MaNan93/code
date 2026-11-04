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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_protocol_fsm.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Protocol FSM and related logic
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module pm_protocol_fsm
  import cx_pl_pkg::PM_ENTER_L1;
  import cx_pl_pkg::PM_ENTER_L23;
  import cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::NOP_DLLP;
  import spif_pkg::state_enc_e;
  import spif_pkg::RESET;
  import spif_pkg::RETRAIN;
  import spif_pkg::ACTIVE;
  import spif_pkg::ACTIVE_L0S_PMNAK;
  import spif_pkg::IDLE_L1_1;
  import spif_pkg::L2;
  import spif_pkg::DISABLED;
  import spif_pkg::LINKRESET;
  import spif_pkg::LINKERROR;
  import spif_pkg::protocol_cfg_t;
// ----------------------------------------------------------------------------
// Import pkg for FSM State Declarations
// ----------------------------------------------------------------------------
  import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
  import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
  import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
// -----------------------------------------------------------------------------
// --- Parameters
// -----------------------------------------------------------------------------
#(
  parameter NVC                       = `CX_NVC,                      // number of VCs
  parameter FREQ_MULTIPLIER           = `CX_FREQ_MULTIPLIER,
  parameter TP                        = `TP,                          // Clock to Q delay (simulator insurance)
  parameter ASPM_TIMEOUT_ENTR_L1_EN   = `CX_ASPM_TIMEOUT_ENTR_L1_EN,
  parameter FREQ_VALUE                = `CX_FREQ_VALUE
) 
                        (
  //------------------------------------------------------------------------------
  // Clock&Reset
  //------------------------------------------------------------------------------
  input                                  core_clk,
  input                                  core_rst_n,
  //------------------------------------------------------------------------------
  // Configuration Interface
  //------------------------------------------------------------------------------
  input                                  switch_device,                   // CFG: 1 indicate that it is a switch device; 0 indicate that it is a EP/RC/bridge device
  input                                  upstream_port,                   // CFG: 1 indicate that it is an upstream port (EP/upstream port of a SW)
  input  [2:0]                           l0s_entr_latency_timer,          // CDM: L0s transmitter L0s exit timer
  input  [2:0]                           l1_entr_latency_timer,           // CDM: L1 transmitter l1 exit timer
  input                                  pm_l1_entr_wo_rl0s,              // CDM: Start L1 timer without rL0s
  input                                  pm_aspm_l1_timer_enable,         // CDM: Control ASPM L1 timer
  input  [3:0]                           cfg_dsp_pcipm_l1_enter_delay,    // CDM: PCIPM L1 entry delay
  output  usp_prot_fsm_state_e           pm_usp_prot_state,               // CDM: RAS-DES PM USP Protocol FSM state
  output  dsp_prot_fsm_state_e           pm_dsp_prot_state,               // CDM: RAS-DES PM DSP Protocol FSM state
  output  pm_active_l0s_fsm_e            pm_l0s_state,                    // CDM: RAS-DES PM L0S Protocol FSM state
  //------------------------------------------------------------------------------
  // Application Interface
  //------------------------------------------------------------------------------
  input                                  all_dwsp_in_l1,                  // Application (Switch): All downstream ports are in L1
  input                                  all_dwsp_in_rl0s,                // Application (Switch): All downstream ports are in rl0s
  input                                  upsp_in_rl0s,                    // Application (Switch): upstream port is in rl0s
  input                                  app_req_entr_l1,                 // Application: Requests PM state to enter L1. This is only effective when ASPM of L1 is enabled.
  input                                  app_xfer_pending,                // Application: Indicates that application has transfers pending
  output  logic                          pm_l1_entry_started,             // Application: L1 entry process is in progress (shadowed in PM Controller)
  output  logic                          pm_aspm_l1_enter_ready,          // Application: Indicates the controller is idle in L0 or L0s, and it is ready to enter ASPM L1 (shadowed in PM Controller)
  //------------------------------------------------------------------------------
  // PM WakeUp Interface
  //------------------------------------------------------------------------------
  input                                  pm_wake_req_exit_l0s,            // PM WakeUp: TLP pending on XADM interface so exit L0S
  input                                  pm_wake_any_if_pending,          // PM WakeUp: xfer pendig wakeup from L1 from any internal app
  output  logic                          pm_l1_in_progress,               // PM WakeUp: L1 entry negotiation in progress
  output  logic                          latch_as_entr_l1,                // PM WakeUp: PM Protocol FSM indication of ASPM enter L1
  //------------------------------------------------------------------------------
  // PME Controller Interface
  //------------------------------------------------------------------------------
  input                                  software_entr_l1,                // PME Controller instructs PM Protocol FSM to start L1
  input                                  software_entr_l23,               // PME Controller instructs PM Protocol FSM to start L23
  input                                  pm_aspm_l0s_en,                  // PME Controller indicates to the PM Protocol FSM that L0s ASPM is enabled
  input                                  pm_aspm_l1_en,                   // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
  input                                  pm_l2_entry_flag,                // PME Controller: PM_Turnoff message has been received so L2 negotiation should start
  output  logic                          pm_xdlh_enter_l23,               // PME Controller: Indicates that the Protocol FSM has requested to enter L23
  output  logic                          pm_prot_idle_flag,               // PME Controller: Indicates that the Protocol FSM is in idle state - RST/RECOVERY/ACTIVE
  //------------------------------------------------------------------------------
  // CX_LP: Link Layer Interface
  //------------------------------------------------------------------------------
  input  [NVC-1:0]                       xtlh_had_enough_credit,          // XTLH had enough credit
  input                                  xtlh_tlp_pending,                // XDLH TLP pending flag
  input                                  xdlh_tlp_pending,                // XDLH TLP pending flag
  input                                  xdlh_retry_pending,              // XDLH TLP pending for replay in Layer2 transmit path
  input                                  xdlh_not_expecting_ack,          // XDLH is not expecting ACK
  input                                  xdlh_nodllp_pending,             // XDLH no DLLP pending to transmit
  input                                  xdlh_no_acknak_dllp_pending,     // XDLH no ACK/NAK DLLP pending to transmit
  input  dllp_struct                     xdlh_pm_dllp_ack,                // XDLH PM DLLP Acknowledge
  input                                  rdlh_rcvd_as_req_l1,             // RDLH received PM_AS_REQ_L1
  input                                  rdlh_rcvd_pm_enter_l1,           // RDLH received PM_ENTER_L1
  input                                  rdlh_rcvd_pm_req_ack,            // RDLH received PM_REQ_ACK
  input                                  rdlh_rcvd_pm_enter_l23,          // RDLH received PM_ENTER_L23
  input                                  rdlh_link_up,                    // RDLH link up
  input                                  sdlh_block_tlp_ack,              // SDLH: BLOCK_TLP Acknowledge from SDLH Command Interface in response to pm_xmlh_lp_req
  output  logic                          pm_freeze_fc_timer,              // RTLH: Command to freeze FC Timer
  output  dllp_struct                    pm_xdlh_dllp_req,                // XDLH DLLP Request
  //------------------------------------------------------------------------------
  // DWC_pcie_core Interface
  //------------------------------------------------------------------------------
  input                                  xaim_tlp_pending,                // XAIM TLP pending flag
  input                                  xadm_tlp_pending,                // XADM TLP pending flag
  input  [NVC-1:0]                       xadm_no_fc_credit,               // XADM no FC credits are available to transmit anything
  input                                  radm_pm_asnak,                   // RADM received AS_NAK
  input                                  radm_trgt0_pending,              // RADM indicates that TLP is enroute to TRGT0, delay L1 entry
  input                                  msg_gen_asnak_grt,               // MSGGEN: Indication from msg_gen that PM_Active_State_Nak has been granted
  input                                  lbc_active,                      // LBC: LBC may require a CPL to be sent, stop L1 timer
  input                                  rstctl_core_flush_req,           // Reset Controller: flush request
  output  logic                          pm_block_all_tlp,                // XADM/XAIM: BLOCK_TLP request (connects to the Application Layer as well)
  output  logic                          pm_xmt_asnak,                    // MSGGEN: PM_Active_State_Nak request
  output  logic                          pm_l1_aspm_entr,                 // LBC/RADM: L1 ASPM entry
  //------------------------------------------------------------------------------
  // CX_LOG_PHY: Physical Layer Interface
  //------------------------------------------------------------------------------
  input dllp_struct                      xplh_pm_dllp_ack,                // TOBEREMOVED: XPLH DLLP Acknowledge
  input                                  xplh_pending,                    // TOBEREMOVED: XPLH pending flag (used only when SPIF is not enabled)
  input  [2:0]                           pl_speedmode,                    // Current Speed Mode
  // Handshake to Link state machine
  input                                  smlh_link_up,                    // LTSSM in link up
  input                                  smlh_in_l0,                      // LTSSM in L0
  input                                  smlh_in_l0s,                     // LTSSM in L0s
  input                                  smlh_in_rl0s,                    // LTSSM in rL0s
  input                                  smlh_in_l1,                      // LTSSM in L1
  input                                  smlh_in_l23,                     // LTSSM in L23
  input                                  smlh_link_in_training,           // LTSSM in link training
  input                                  smlh_l123_eidle_timeout,         // TOBEREMOVED: LTSSM 2ms Timer timeout waiting for EIDLE
  input                                  latched_rcvd_eidle_set,          // TOBEREMOVED: LTSSM latched received eidle ordered set indication from RMLH
  input                                  xmlh_cmd_if_lp_ack,              // TOBEREMOVED: XMLH: LP command acknowledge from XMLH (non-SPIF) Command Interface
  output  logic                          pm_xmlh_lp_req,                  // SDLH/XMLH: LP command request to SDLH (SPIF) / XMLH (non-SPIF) Command Interface (TOBEREMOVED)
  //------------------------------------------------------------------------------
  // SPIF Interface
  //------------------------------------------------------------------------------
  input   protocol_cfg_t                 pl_protocol_cfg,                 // Protocol Configuration for DLH Layer
  input   state_enc_e                    pl_state_sts,                    // SPIF: pl_state_sts on PCIe/CXL.io link layer interface
  input                                  pl_stall_req,                    // SPIF: pl_stall_req on PCIe/CXL.io link layer interface
  input                                  pl_rx_active_req,                // SPIF: pl_rx_active_req on PCIe/CXL.io link layer interface - used in NOP DLLP flow only
  input                                  pl_phyinrxl0s,                   // SPIF: Physical Layer RX is in L0s
  input                                  pl_phyinretrain,                 // SPIF: Physical Layer RX is in Recovery
  input   state_enc_e                    lp_state_req,                    // SPIF: lp_state_req on PCIe/CXL.io link layer interface
  input                                  lp_pm_l1_exit,                   // PM WakeUp requests Link Layer to exit from L1
  output  logic                          lp_pm_l1_req,                    // PM Protocol FSM request to Link Layer to change requested state to L1
  output  logic                          lp_pm_l2_req,                    // PM Protocol FSM request to Link Layer to change requested state to L2
  output  logic                          lp_pm_l0s_req,                   // PM Protocol FSM request to Link Layer to change requested state to L0S
  //------------------------------------------------------------------------------
  // Sideband Interface
  //------------------------------------------------------------------------------
//    `ifndef CX_MULTISTREAM_ARCH
//  input                                  pl_sdb_l1sub_cpl_timer,          // Sideband signal that indicates L1-substates Completion Timeout timer started in the LogPHY (for implementations where L1-substates logic implements Completion Timeout timer)
//    `endif //!CX_MULTISTREAM_ARCH
  output  logic                          lp_sdb_l1sub_aspm,               // Sideband signal that indicates ASPM L1 Entry for L1-substates implementation in the LogPHY
  output  logic                          lp_sdb_l1sub_pcipm,              // Sideband signal that indicates PCI-PM L1 Entry for L1-substates implementation in the LogPHY
  //------------------------------------------------------------------------------
  // PM Protocol-2-Link FSM Interface (TOBEREMOVED)
  //------------------------------------------------------------------------------
  input   pm_link_to_protocol_struct     pm_link_to_protocol_signals,     // TOBEREMOVED: PM Link FSM to Protocol FSM connections
  output  pm_protocol_to_link_struct     pm_protocol_to_link_signals      // TOBEREMOVED: PM Protocol FSM to Link FSM connections
);

//------------------------------------------------------------------------------
// Internal signals declaration
//------------------------------------------------------------------------------
dllp_struct            int_pm_xdlh_dllp_req;         // XDLH DLLP Request
dllp_struct            int_pm_dllp_ack;              // XDLH DLLP Acknowledge
logic                  int_cxl_rcd_enabled;          // Indicates that a Device is operating in RCD mode (formerly known as CXL 1.1 Device)
logic                  int_software_entr_l1;         // PCI-PM-directed L1 entry
logic                  int_software_entr_l23;        // PCI-PM-directed L2 entry
logic                  int_start_l1_aspm;            // Start ASPM L1 entry
logic                  int_start_l1_pcipm;           // Start PCI-PM L1 entry
logic                  int_start_l1_nego;            // Instructs Protocol FSM to start L1 negotiation
logic                  int_l1_aspm_ready;            // Protocol FSM is ready to start ASPM L1 entry
logic                  int_l1_aspm_enter_ready;      // Indicates that the controller is ready to enter ASPM L1
logic                  int_l1_aspm_radm_race;        // Race condition between L1 ASPM entry initiation and RADM TRGT0 pending
logic                  int_l1_aspm_radm_race_r;      // Registered version of int_l1_aspm_radm_race
logic                  int_l1_aspm_disable;          // Disable ASPM L1 Entry
logic                  int_l1_aspm_timeour_clear;    // Clear timeout request for ASPM L1
logic                  int_en_sw_usp_aspm_l1;        // Switch Upstream Port ASPM L1 enable
logic                  int_en_ep_usp_aspm_l1;        // Device Upstream Port ASPM L1 enable (L1 ASPM timer has expired)
logic                  int_block_tlp_ack;            // Block TLP acknowledge
logic                  int_tx_pending;
logic                  int_trgt0_pending;
logic                  int_pending_clear_timeout;
logic                  int_last_dllp_ack;             // DSP Protocol FSM: Last PM DLLP acknowledge
logic                  int_dsp_enter_l0s;             // DSP Protocol FSM: Conditions for DSP to enter L0S
logic                  int_usp_enter_l0s;             // USP Protocol FSM: Conditions for USP to enter L0S
logic                  int_csr_cpl_sent;              // USP Protocol FSM: CSR Completion sent
logic                  int_l23_entry_flag_clear;      // ActiveFlags: Clear L23 entry flag
logic                  int_l23_restart_clear;         // ActiveFlags: Clear L23 restart flag
logic                  int_l23_entry_abort;           // ActiveFlags: Abort L23 entry in WAIT_PMDLLP_ACK state when recovery or link down
logic                  int_wait_dstate_update;        // ActiveFlags: USP Protocol or Link FSM is in WAIT_DSTATE_UPDATE state
logic                  int_l0s_idle_timeout_s;        // L0s idle timeout - next state
logic                  int_l0s_idle_timeout_r;        // L0s idle timeout - register
logic                  int_link_up_not_rcvry;
logic                  int_idle_next;
logic                  int_phyinretrain;
logic                  int_clear_l0s_timeout;
logic                  int_l0s_l1_timeout_s;
logic                  int_l1_idle_timeout_s;
logic                  int_no_l0s_bef_l1;
logic                  int_l1_timeout_s;
logic                  int_l0s_before_l1_entry;
logic                  int_l1_entry_no_l0s;
logic                  int_next_resp_nak;            // Conditions for transmitting PM_Active_State_Nak when PM_Active_State_Request_L1 received
logic                  int_pm_xmt_asnak;             // PM_Active_State_Nak request to MsgGen
logic                  int_nak_timer_expire;         // NAK timer expired. For CIO wait for a number of L1 request DLLPs to be dropped.
logic                  pm_linkst_in_l1;
logic                  int_l1_entry_started;     // L1 entry process is in progress
logic                  pm_linkst_in_l0s;
logic                  pm_linkst_in_l2;
logic      [13:0]      l0s_idle_timer;
logic      [13:0]      l1_idle_timer;
logic      [11:0]      timer;
// switch_device and upstream_port signals should be set as following to
// form different devices:
// 1. switch device -- switch_device = 1'b1,
// 2. upstream port of a switch -- switch_device = 1'b1 and upstream_port = 1'b1
// 3. downstream port of a switch -- switch_device = 1'b1 and upstream_port = 1'b0
// 4. end device -- switch_device = 1'b0 and upstream_port = 1'b1;
// 5. root complex -- rc_device = 1'b1 and switch_device = 1'b0 and upstream_port = 1'b0;
// 6. bridge (similiar to end device) -- switch_device = 1'b0 and upstream_port = 1'b1;
//
logic      [10:0]      l0s_idle_timer_value;
logic      [13:0]      l1_idle_timer_value;
logic                  timer_95us_expired;
logic                  timeout_95us_reg;
logic                  timer_10us_expired;
logic                  timer_10us_expired_reg;
logic                  pm_smlh_entry_to_l0s;       // entry to L0s
logic                  pm_smlh_l0s_exit;           // exit xmtr L0s
logic                  pm_l1_aspm_flag;
logic                  pm_l23_entry_flag;
logic                  pm_l23_hs_done;
logic                  pm_l1_pcipm_hs_done;
logic                  pm_l1_aspm_hs_done;
logic                  pm_smlh_dllp_hs;
logic                  l0s_entr_cond4timeout_met;
logic                  int_l0s_det_idle;
logic                  l1_entr_cond4timeout_met;


logic                  int_rdlh_rcvd_pm_enter_l1;  // internal
logic [3:0]            enter_l1_timer;             // PCI PM timer
logic [3:0]            enter_l1_timer_r;
logic                  enter_l1_timer_en;          // PCI PM timer enable
logic                  enter_l1_timer_en_r;
logic                  enter_l1_timer_timeout;     // PCI PM timer timeouts
logic                  latched_entr_l23;           // Latched L23 entry condition
logic                  prot_enter_l0s;                   // drive l0s_fsm enter l0s
logic                  int_l0s_exit;                     // trigger l0s_fsm exit
logic                  l0s_l0s_idle;
logic                  l0s_l0s_block_tlp;
logic                  l0s_l0s_enter_l0s;
logic                  l0s_l0s_exit;
logic                  l0s_l0s_finish;                   // L0s FSM exit from L0s
logic                  dsp_prot_entering_block_tlp;      // The condition for starting block tlp in dsp prot fsm
logic                  dsp_prot_rst;
logic                  dsp_prot_recovery;
logic                  dsp_prot_active;
logic                  dsp_prot_respond_nak;
logic                  dsp_prot_nak_block_tlp;
logic                  dsp_prot_wait_nak_tlp_ack;
logic                  dsp_prot_wait_nak_timer;
logic                  dsp_prot_block_tlp;
logic                  dsp_prot_wait_last_tlp_ack;
logic                  dsp_prot_wait_last_pmdllp;
logic                  dsp_prot_enter_l1;
logic                  dsp_prot_enter_l23;
logic                  dsp_prot_enter_l0s;
logic                  usp_prot_rst;
logic                  usp_prot_recovery;
logic                  usp_prot_active;
logic                  usp_prot_enter_l0s;
logic                  usp_prot_l1_block_tlp;
logic                  usp_prot_l1_wait_last_tlp_ack;
logic                  usp_prot_l1_wait_pmdllp_ack;
logic                  usp_prot_enter_l1;
logic                  usp_prot_l23_block_tlp;
logic                  usp_prot_l23_wait_last_tlp_ack;
logic                  usp_prot_l23_wait_pmdllp_ack;
logic                  usp_prot_enter_l23;
logic                  usp_prot_wait_pmcsr_cpl_sent;
logic                  usp_prot_wait_last_pmdllp;
logic                  usp_prot_wait_dstate_update;
logic                  dsp_link_l1_exit;
logic                  dsp_link_l23rdy_wait4alive;
logic                  usp_link_l23rdy_wait4alive;
logic                  usp_link_l1_exit;
logic                  usp_link_l1_in_progress;          // TOBEREMOVED: Indicates that USP Link FSM L1 entry is in progress but it has not yet reached L1 state
logic                  prot_enter_l1;
logic                  prot_enter_l23;
logic                  link_l1_finish;
logic                  link_l23_finish;
logic                  prot_to_active;
logic                  link_to_prot_l1_finish;           // Link FSM notify Protocol FSM L1 exit
logic                  link_to_prot_l23_finish;          // Link FSM notify Protocol FSM L23 exit
logic                  link_to_prot_to_active;           // Link FSM is back to L0, Protocol FSM should go back to active

logic                  int_pm_req_ack_ena;     // Enable PM Request Acknowledge DLLP
logic                  prot_pm_l1_exit;        // Link Layer indicates to Protocol FSM to exit L1
logic                  prot_pm_l23_exit;       // Link Layer indicates to Protocol FSM to exit L23
logic                  prot_pm_to_active;      // Link Layer is in ACTIVE state
logic                  latch_prot_l1_exit;     // Latched Protocol FSM L1 exit conditions
logic                  prot_pm_l1_exit_req;    // Protocol FSM L1 exit request
logic                  prot_pm_l1_finish;      // Internal signal
logic                  prot_pm_l23_finish;     // Internal signal
logic                  prot_idle_next;         // Internal signal
logic                  prot_link_up_not_rcvry; // Internal signal
logic                  usp_entr_dstate_update; // USP Protocol FSM to enter into WAIT_DSTATE_UPDATE state
logic                  usp_exit_dstate_update; // USP Protocol FSM to exit from WAIT_DSTATE_UPDATE state
logic                  pm_l23_entry_restart;
logic                  usp_link_l1;
logic                  usp_link_l0;
logic                  usp_link_wait_dstate_update;     // TOBEREMOVED: USP Link FSM is in WAIT_DSTATE_UPDATE state

logic                  l1_entr_cond4app_met;
logic                  l1_idle_timeout;
logic                  pm_timeout;

// Local declarations for Link to Protocol FSM interface signals
logic                  pm_link_l23_flag_clear;           // Link FSM signal to clear L23 entry flag
logic                  pm_link_l23_restart_clear;        // Link FSM signal to clear L23 restart flag
logic                  pm_link_usp_l1_in_progress;       // Link FSM L1 is in progress
logic                  pm_link_dsp_l1_in_progress;       // Link FSM L1 is in progress
logic                  pm_link_block_all_tlp;            // Link FSM signal to block all TLPs
logic                  pm_link_freeze_fc_timer;          // Link FSM signal to freeze FC time
logic                  pm_link_hold_dllp_timer;          // Link FSM signal to hold DLLP timer
logic                  int_pm_block_all_tlp;
logic                  pm_wake_tlp_pending;              // TLP pending in transmit data path
logic                  xadm_block_tlp_ack;               // XADM blocked all TLP's and has nothing pending to transmit
logic [2:0]            int_block_tlp_r;                  // Delayed int_pm_block_all_tlp
logic                  int_sdlh_block_tlp_ack;           // Block TLP acknowledge from SDLH Command Interface (SPIF) or XMLH Command Interface (non-SPIF)
logic                  int_cmd_if_lp_ack_r;              // Command Interface LP acknowledge
logic                  int_xmlh_lp_req_rst;              // Clear LP request command on SDLH (SPIF) / XMLH (non-SPIF) Command Interface
logic                  l0s_l0s;                          // PM L0S Protocol FSM is in L0S state
logic                  latch_app_entr_l1;                // Latch Application request to enter ASPM L1
logic                  timer2;
logic                  pm_dllp_enable;                   // Enable DLLP exchange for PM negotiation

assign pm_dllp_enable = pl_protocol_cfg.cxl_pcie_flit_mode ? 1'b0 : 1'b1;

// ----------------------------------------------------------------------------
// Convert between internal signals and Interface with PM Link FSM
// ----------------------------------------------------------------------------
assign int_link_up_not_rcvry                  = pl_protocol_cfg.spif_enable ? prot_link_up_not_rcvry : pm_link_to_protocol_signals.int_link_up_not_rcvry ;
assign int_idle_next                          = pl_protocol_cfg.spif_enable ? prot_idle_next         : pm_link_to_protocol_signals.int_idle_next         ;
assign link_l1_finish                         = pm_link_to_protocol_signals.link_l1_finish                 ;
assign link_l23_finish                        = pm_link_to_protocol_signals.link_l23_finish                ;
assign prot_to_active                         = pm_link_to_protocol_signals.prot_to_active                 ;

assign pm_link_l23_flag_clear                 = pm_link_to_protocol_signals.pm_link_l23_flag_clear         ;
assign pm_link_l23_restart_clear              = pm_link_to_protocol_signals.pm_link_l23_restart_clear      ;
assign pm_link_usp_l1_in_progress             = pm_link_to_protocol_signals.pm_link_usp_l1_in_progress     ;
assign pm_link_dsp_l1_in_progress             = pm_link_to_protocol_signals.pm_link_dsp_l1_in_progress     ;
assign pm_link_block_all_tlp                  = pm_link_to_protocol_signals.pm_link_block_all_tlp          ;
assign pm_link_freeze_fc_timer                = pm_link_to_protocol_signals.pm_link_freeze_fc_timer        ;
assign pm_link_hold_dllp_timer                = pm_link_to_protocol_signals.pm_link_hold_dllp_timer        ;
// In SPIF mode, map L0/L1 link states to ACTIVE/IDLE_L1_1 states on pl_state_sts
assign usp_link_l1                            = pl_protocol_cfg.spif_enable ? (pl_state_sts == IDLE_L1_1) : pm_link_to_protocol_signals.usp_link_l1 ;
assign usp_link_l0                            = pl_protocol_cfg.spif_enable ? (pl_state_sts == ACTIVE   ) : pm_link_to_protocol_signals.usp_link_l0 ;
assign usp_link_wait_dstate_update            = pm_link_to_protocol_signals.usp_link_wait_dstate_update    ;
assign pm_linkst_in_l1                        = pm_link_to_protocol_signals.pm_linkst_in_l1                ;
assign pm_linkst_in_l2                        = pm_link_to_protocol_signals.pm_linkst_in_l2                ;

//------------------------------------------------------------------------------
// Protocol to Link FSM signals
//------------------------------------------------------------------------------
assign pm_protocol_to_link_signals.software_entr_l1     = int_software_entr_l1                             ;
assign pm_protocol_to_link_signals.software_entr_l23    = int_software_entr_l23                            ;
assign pm_protocol_to_link_signals.lbc_active           = lbc_active                                       ;
assign pm_protocol_to_link_signals.latch_as_entr_l1     = latch_as_entr_l1                                 ;
assign pm_protocol_to_link_signals.latched_entr_l23     = latched_entr_l23                                 ;
assign pm_protocol_to_link_signals.prot_enter_l1        = prot_enter_l1                                    ;
assign pm_protocol_to_link_signals.prot_enter_l23       = prot_enter_l23                                   ;
assign pm_protocol_to_link_signals.pm_timeout           = pm_timeout                                       ;
assign pm_protocol_to_link_signals.pm_smlh_entry_to_l0s = pm_smlh_entry_to_l0s                             ;
assign pm_protocol_to_link_signals.pm_smlh_l0s_exit     = pm_smlh_l0s_exit                                 ;
assign pm_protocol_to_link_signals.pm_linkst_in_l0s     = pm_linkst_in_l0s                                 ;
assign pm_protocol_to_link_signals.pm_smlh_dllp_hs      = pm_smlh_dllp_hs                                  ;

assign int_smlh_link_in_training     = (pl_protocol_cfg.spif_enable ? int_phyinretrain : 1'b0 ) || smlh_link_in_training;


assign pm_prot_idle_flag = upstream_port ? (usp_prot_rst || usp_prot_recovery || usp_prot_active) : (dsp_prot_rst || dsp_prot_recovery || dsp_prot_active);


// ----------------------------------------------------------------------------
// DLLP Request to XDLH
// ----------------------------------------------------------------------------
logic  pm_xdlh_enter_l1;
logic  pm_xdlh_actst_req_l1;

assign pm_xdlh_enter_l1           = ((int_pm_xdlh_dllp_req.dllp_type==PM_ENTER_L1) && (int_pm_xdlh_dllp_req.valid==1'b1)) ? 1'b1 : 1'b0;
assign pm_xdlh_actst_req_l1       = ((int_pm_xdlh_dllp_req.dllp_type==PM_ACTIVE_STATE_REQUEST_L1) && (int_pm_xdlh_dllp_req.valid==1'b1)) ? 1'b1 : 1'b0;
assign pm_xdlh_enter_l23          = ((int_pm_xdlh_dllp_req.dllp_type==PM_ENTER_L23)&& (int_pm_xdlh_dllp_req.valid==1'b1)) ? 1'b1 : 1'b0;

assign pm_xdlh_dllp_req.valid     = int_pm_xdlh_dllp_req.valid && (pl_protocol_cfg.spif_enable ? !pl_stall_req : 1'b1);
assign pm_xdlh_dllp_req.dllp_type = int_pm_xdlh_dllp_req.dllp_type;
assign pm_xdlh_dllp_req.pyld      = 24'b0;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// PCI-PM Entry Conditions
// ----------------------------------------------------------------------------
// Indicates that a Device is operating in RCD mode (formerly known as CXL 1.1 Device)
assign int_cxl_rcd_enabled = pl_protocol_cfg.cxl_mode_enable && !pl_protocol_cfg.cxl_vh_enable && !pl_protocol_cfg.cxl_pcie_flit_mode;

// RCD links support ASPM-directed L1 entry but do not support PCI-PM-directed L1
// entry. An eRCD is not required to initiate entry into L1 state when software
// transitions the device into D3Hot or D1 device state.
assign int_software_entr_l1  = int_cxl_rcd_enabled ? 1'b0 : software_entr_l1;
assign int_software_entr_l23 = pm_l23_entry_restart || software_entr_l23;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// PCI-PM L1 Entry Timer
// ----------------------------------------------------------------------------
assign int_rdlh_rcvd_pm_enter_l1 = (cfg_dsp_pcipm_l1_enter_delay > 0) ? enter_l1_timer_timeout : rdlh_rcvd_pm_enter_l1;

//timeout signal
assign enter_l1_timer_timeout = (cfg_dsp_pcipm_l1_enter_delay!=0) ? (enter_l1_timer_r == cfg_dsp_pcipm_l1_enter_delay) : 4'h0;

//timer logic
assign enter_l1_timer = enter_l1_timer_en ? enter_l1_timer_r + 1'b1 : 4'h0;

//logic that enables timer
always_comb begin
    if(enter_l1_timer_timeout)
        enter_l1_timer_en = 1'b0;
    else if(rdlh_rcvd_pm_enter_l1 && (cfg_dsp_pcipm_l1_enter_delay!=0) && dsp_prot_active)
        enter_l1_timer_en = 1'b1;
    else
        enter_l1_timer_en = enter_l1_timer_en_r;
end

always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        enter_l1_timer_en_r     <= #TP '0;
        enter_l1_timer_r        <= #TP '0;
    end else begin
        enter_l1_timer_en_r     <= #TP enter_l1_timer_en;
        enter_l1_timer_r        <= #TP enter_l1_timer;
    end
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Storing the reason of going into L1 (ASPM vs PCIPM). Used by L1 substates
// ----------------------------------------------------------------------------
// latch the type of DLLP that was used by the upstream port to request L1, this information
// is needed in the downstream port to distinguish between ASPM L1 and PCI-PM L1
logic   pm_rcvd_as_req_l1;
logic   pm_rcvd_pm_enter_l1;

assign lp_sdb_l1sub_aspm  = upstream_port ?  latch_as_entr_l1 : pm_rcvd_as_req_l1;
assign lp_sdb_l1sub_pcipm = upstream_port ? !latch_as_entr_l1 : pm_rcvd_pm_enter_l1;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        pm_rcvd_as_req_l1   <=  #TP 1'b0;
        pm_rcvd_pm_enter_l1 <=  #TP 1'b0;
    end else if (dsp_prot_active) begin
        pm_rcvd_as_req_l1   <=  #TP rdlh_rcvd_as_req_l1;
        pm_rcvd_pm_enter_l1 <=  #TP int_rdlh_rcvd_pm_enter_l1;
    end

end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// ASPM L1 Entry Conditions
// ----------------------------------------------------------------------------
// Both transmit and receive must be in L0S before L1 ASPM entry
assign int_l0s_before_l1_entry = smlh_in_rl0s && l0s_l0s && !pm_l1_entr_wo_rl0s;
// L1 entry need not be preceeded by L0S
assign int_no_l0s_bef_l1 = !pm_aspm_l0s_en || pm_l1_entr_wo_rl0s;
assign int_l1_entry_no_l0s = int_no_l0s_bef_l1 && ((usp_prot_active && usp_link_l0) || l0s_l0s || l0s_l0s_block_tlp || l0s_l0s_enter_l0s || l0s_l0s_exit);

assign int_l1_aspm_enter_ready = (pm_aspm_l1_en && upstream_port && !pm_wake_tlp_pending && xdlh_nodllp_pending
                                   && (&xtlh_had_enough_credit) && (int_l0s_before_l1_entry || int_l1_entry_no_l0s))
                                   && !radm_trgt0_pending
                                   && !pm_wake_any_if_pending
                                   ;

always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
       pm_aspm_l1_enter_ready <= #TP 1'b0;
    end else begin
       pm_aspm_l1_enter_ready <= #TP int_l1_aspm_enter_ready;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)
        latch_app_entr_l1    <=  #TP 1'b0;
    else if ((usp_prot_active || l0s_l0s || l0s_l0s_enter_l0s || l0s_l0s_exit) && app_req_entr_l1)
        // we will latch the reason of state transition from L0 or L0s
        // to L1 so that we could generate proper pm dllp handshake
        latch_app_entr_l1    <=  #TP 1'b1;
    else if (usp_link_l1)
        latch_app_entr_l1    <=  #TP 1'b0;
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// L1 Idle timeout detection (ASPM L1)
// ----------------------------------------------------------------------------
// This is introduced for entering L1 after L1 timeout or application request enter L1
// latched the status of this core wants to initiate an enter of l1 when it
// has been in L0s for certain amount of time.
assign l1_idle_timeout  = pm_aspm_l1_en & (l1_idle_timer >= (l1_idle_timer_value - FREQ_MULTIPLIER)) & (l1_entr_cond4timeout_met | l1_entr_cond4app_met);

// If L1 entry must be preceeded by L0S
assign int_l0s_l1_timeout_s = !pm_l1_entr_wo_rl0s && (l0s_l0s || l0s_l0s_exit) && l1_idle_timeout;
// L1 entry without L0S first
assign int_l1_idle_timeout_s = int_no_l0s_bef_l1 && l1_idle_timeout;
assign int_l1_timeout_s = int_l0s_l1_timeout_s || int_l1_idle_timeout_s;

//The mechanism for the ASPM enters L1 is application specific. Here we
//choose a time out mechanism where the timer value is the half of the l1
//exit latency timer. The L1 time out only apply to ASPM control is enabled
//with L1 and the quiet condition met in L0s for the duration of time out time.

always @(l1_entr_latency_timer )
    case (l1_entr_latency_timer)
        3'b000:  l1_idle_timer_value = 14'b00000100000000 ;  // 1us
        3'b001:  l1_idle_timer_value = 14'b00001000000000 ;  // 2us
        3'b010:  l1_idle_timer_value = 14'b00010000000000 ;  // 4us
        3'b011:  l1_idle_timer_value = 14'b00100000000000 ;  // 8us
        3'b100:  l1_idle_timer_value = 14'b01000000000000 ;  // 16us
        3'b101:  l1_idle_timer_value = 14'b10000000000000 ;  // 32us
        3'b110:  l1_idle_timer_value = 14'b11111111111110 ;  // 64us, note for 2s design, we need to set this value to 3FFE
        default: l1_idle_timer_value = 14'b11111111111110 ;  // 64us
    endcase

// there are 2 ways to control the L1 ASPM entry. Only one of them must be selected
// 1. if ASPM_TIMEOUT_ENTR_L1_EN is defined  latch_app_entr_l1  == 1
// 2. if pm_aspm_l1_timer_enable == 1 the deassertion of app_xfer_pending will trigger L1 entry
assign l1_entr_cond4app_met   = pm_aspm_l1_enter_ready & !app_xfer_pending & (latch_app_entr_l1 || !pm_aspm_l1_timer_enable);
// The conditions for enabling the L1 idle timer
// FC credit DLLP's will not reset the timer but outstanding Ack/Nak TLP's will reset the timer
// this is necessary to insure that the retry buffer is empty.
assign l1_entr_cond4timeout_met =  pm_aspm_l1_en & ASPM_TIMEOUT_ENTR_L1_EN & !latch_app_entr_l1 & upstream_port
                                   & !pm_wake_tlp_pending & xdlh_no_acknak_dllp_pending & (&xtlh_had_enough_credit)
                                   & (int_l0s_before_l1_entry || int_l1_entry_no_l0s)
                                   && !radm_trgt0_pending
                                   && !pm_wake_any_if_pending
                                   && !app_xfer_pending
                                   && pm_aspm_l1_timer_enable
                                   ;

// l1 timer increments on:
// 1. Both tx and rx in l0s state for a duration of half of the L1 exit
// latency timer of an upstream component
// 2. and current port of all function's ASMP L1 entry is enabled
// 3. The rule for entering L1 is applicaiton specific. It is
// controlable by set the parameter in app*.vh
always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        l1_idle_timer  <= #TP 0;
    end else begin
        if (l1_entr_cond4timeout_met) begin
            l1_idle_timer  <= #TP l1_idle_timer + (timer2 ? FREQ_MULTIPLIER : 1'b0);
        end else if (l1_entr_cond4app_met) begin
            l1_idle_timer  <= #TP {14{1'b1}};
        end else begin
            l1_idle_timer  <= #TP {14{1'b0}};
        end
    end
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// L1 negotiation start
// ----------------------------------------------------------------------------
// Switch upstream port is allowed to enter ASPM L1 if all switch DSP's are in L1 and there are no TLP's or DLLP's pending
// and the L1 ASPM timer has expired.
assign int_en_sw_usp_aspm_l1 = ((all_dwsp_in_l1 && switch_device && upstream_port && xdlh_nodllp_pending && !pm_wake_tlp_pending) && int_l1_timeout_s);
// Non switch upstream port is allowed to enter APSM L1 if the L1 ASPM timer has expired
assign int_en_ep_usp_aspm_l1 = ((!switch_device && upstream_port) && int_l1_timeout_s);
// If the L1 ASPM entry conditions are no longer satisfied while we are waiting for the 10us timer to expire
// ASPM L1 entry will not be permitted
assign int_l1_aspm_disable = !(l1_entr_cond4timeout_met || l1_entr_cond4app_met) && !timer_10us_expired_reg;
// Clear the L1 ASPM entry request when negotiation started or if during L0S_EXIT a transfer becomes pending
assign int_tx_pending = pm_wake_tlp_pending || !xdlh_no_acknak_dllp_pending || pm_wake_any_if_pending || app_xfer_pending ;
assign int_trgt0_pending = l0s_l0s_exit && radm_trgt0_pending;
assign int_pending_clear_timeout = pm_aspm_l1_en && ( int_tx_pending || int_trgt0_pending );
assign int_l1_aspm_timeour_clear = (usp_prot_l1_wait_last_tlp_ack || !pm_aspm_l1_en || int_pending_clear_timeout);

reg l1_timeout_req_enter_l1;
always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)
        l1_timeout_req_enter_l1 <= #TP 1'b0;
    else if (int_l1_aspm_disable)
        l1_timeout_req_enter_l1 <= #TP 1'b0;
    else if (int_l1_aspm_timeour_clear)
        l1_timeout_req_enter_l1 <= #TP 1'b0;
    else if (int_en_sw_usp_aspm_l1 || int_en_ep_usp_aspm_l1)
        l1_timeout_req_enter_l1 <= #TP 1'b1;
end
// ----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// ENTER L1 Conditions and Status
// -----------------------------------------------------------------------------
// There are many conditions that cause pm link enter l1
// 1. software program Dstate to request entering of L1
// 2. ASPM L1 is enabled and L1 enter conditions are met
// 3. Other external reason
// Note: As a swtich component, it is software's responsibility to
// program downstream ports entering L1 before upstream port is programmed.
// This PM design will not guard for this condition. If all ports of switch
// are enabled with ASPM L1, then upstream port L1 entering will only be
// possible when all downstream ports are in L1 and upstream ASPM L1
// entering conditions are met.

// ASPM L1 entry ready to start
assign int_start_l1_aspm = (!pm_l2_entry_flag && ((l1_timeout_req_enter_l1 && timer_10us_expired_reg) || pm_l1_aspm_flag)
 );

// PCI-PM L1 entry ready to start
assign int_start_l1_pcipm = (!pm_l2_entry_flag && int_software_entr_l1);

// L1 negotiation request either due to ASPM or PCI-PM the distinction will be in the type of DLLP sent but otherwise
// the state transitions in the USP PROT FSM are the same.
assign int_start_l1_nego = int_start_l1_pcipm || int_start_l1_aspm;

// L1 ASPM entry is about to be initiated by the USP Protocol FSM
assign int_l1_aspm_ready = int_start_l1_aspm && usp_prot_active;

// L1 entry process started and it is in progress
assign int_l1_entry_started = pm_l1_in_progress || pm_l1_aspm_entr || int_start_l1_aspm;

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        pm_l1_entry_started <= #TP 1'b0;
    end else begin
        pm_l1_entry_started <= #TP int_l1_entry_started;
    end
end

// L1 entry negotiation is in progress at a point where the LTSSM has exited L0
// usp_prot_enter_l1 and dsp_prot_enter_l1 indicates the phase 1 L1
// negotiation is finished and it is in phase 2/3 negotiation
assign pm_l1_in_progress = pl_protocol_cfg.spif_enable ? (lp_pm_l1_req || (lp_state_req == IDLE_L1_1) || (pl_state_sts == IDLE_L1_1)) :
                           ((usp_prot_wait_last_pmdllp || usp_prot_enter_l1 || pm_link_usp_l1_in_progress) ||
                            (dsp_prot_wait_last_pmdllp || dsp_prot_enter_l1 || pm_link_dsp_l1_in_progress)
                           );

// L1 deadlock avoidance
always_comb begin
   pm_l1_aspm_entr = latch_as_entr_l1 && ((usp_link_l0 && int_l1_aspm_ready) ||
                                          usp_prot_wait_pmcsr_cpl_sent ||
                                          usp_prot_l1_block_tlp ||
                                          usp_prot_l1_wait_last_tlp_ack ||
                                          usp_prot_l1_wait_pmdllp_ack ||
                                          usp_prot_wait_last_pmdllp);
end

always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n)
    latch_as_entr_l1 <=  #TP 0;
  // we will latch the reason of state transition from L0 or L0s
  // to L1 so that we could generate proper pm dllp handshake
  // When PROT FSM is in Active, LINK FSM must be in L0.
  else if (usp_prot_active || l0s_l0s)
    latch_as_entr_l1 <=  #TP !int_software_entr_l1;
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// Detect potential race condition between L1 ASPM entry initiation and RADM TRGT0 pending
// The L1 ASPM negotiation should not begin until the RADM TRGT0 non posted requests are halted
// and there are no transfers pending to TRGT0
// -----------------------------------------------------------------------------
assign int_l1_aspm_radm_race = (int_l1_aspm_ready && radm_trgt0_pending) ? 1'b1 : (!radm_trgt0_pending ? 1'b0 : int_l1_aspm_radm_race_r);

always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n) begin
    int_l1_aspm_radm_race_r <= #TP 1'b0;
  end else begin
    int_l1_aspm_radm_race_r <= #TP int_l1_aspm_radm_race;
  end
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// PM Protocol FSM to Link Layer State Request interface
// -----------------------------------------------------------------------------
// Stop requesting L1 entry to XDLH when L1 exit condition is detected
assign lp_pm_l1_req = (prot_enter_l1  || (pl_protocol_cfg.spif_enable && dsp_prot_wait_last_pmdllp && !latched_entr_l23)) && !latch_prot_l1_exit;
assign lp_pm_l2_req = (prot_enter_l23 || (pl_protocol_cfg.spif_enable && dsp_prot_wait_last_pmdllp &&  latched_entr_l23));
// -----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Auxiliary logic
// ----------------------------------------------------------------------------
// clear the flag if either L2 entry is complete or state status is changed from ACTIVE for any reason
assign int_l23_entry_flag_clear = pl_protocol_cfg.spif_enable ? !(pl_state_sts inside {L2, ACTIVE}) : pm_link_l23_flag_clear;

// clear the flag if either L2 entry is complete or link was reset
assign int_l23_restart_clear    = pl_protocol_cfg.spif_enable ? (pl_state_sts inside {L2, LINKERROR, LINKRESET, DISABLED, RESET}) : pm_link_l23_restart_clear;

// Used as a condition to set ASPM L1 flag : pm_l1_aspm_flag
assign usp_link_l1_in_progress = pm_link_usp_l1_in_progress && !usp_link_l1;

// L23READY negotiation is aborted
assign int_l23_entry_abort = usp_prot_l23_wait_pmdllp_ack && int_idle_next;

// In SPIF mode, enable PM timer when pl_state_sts is in ACTIVE state to allow for D-state update
assign int_wait_dstate_update = pl_protocol_cfg.spif_enable ? (usp_prot_wait_dstate_update && (pl_state_sts == ACTIVE)) : usp_link_wait_dstate_update;

// For CXL DSP, enable PM Acknowledge DLLP in DSP_PROT_WAIT_LAST_PMDLLP state until the point
// pl_rx_active_req is de-asserted, in other words until PM Request ALMP is received
assign int_pm_req_ack_ena = pl_protocol_cfg.spif_enable ? pl_rx_active_req : !(latched_rcvd_eidle_set || smlh_l123_eidle_timeout);

assign prot_pm_l1_exit_req = pl_protocol_cfg.cxl_mode_enable ? (prot_enter_l1  && latch_prot_l1_exit) : 1'b0;

// L2 exit condition for Protocol FSM:
// 1) XDLH State Status changed to RESET on exit from L2 state or a recovery is triggered before transition to L2 (applies to PCIe)
assign prot_pm_l23_exit    = prot_enter_l23 && (pl_state_sts == RESET);

// L1 exit conditions for Protocol FSM:
// 1) XDLH State Status changed to RETRAIN on exit from IDLE_L1_1 state or a recovery is triggered before transition to IDLE_L1_1 (applies to PCIe)
// 2) XDLH State Status is ACTIVE, i.e. Phase 2 is in progress (abort scenario, not applicable in 256B flit mode and in PCIe mode):
//    USP: If CXL.io exit condition is detected then exit PM Protocol FSM after pl_stall_ack is asserted and L1 Request ALMP is sent
//    DSP: If pl_rx_active_req is asserted when Active Request ALMP is received then exit PM Protocol FSM
always_comb begin
    if (pl_protocol_cfg.cxl_pcie_flit_mode)
        prot_pm_l1_exit    = prot_enter_l1  && ((pl_state_sts == RETRAIN) ||  ((pl_state_sts == ACTIVE) && (upstream_port ? 1'b0 : (prot_pm_l1_exit_req && pl_rx_active_req))) || (pl_state_sts == ACTIVE_L0S_PMNAK));
    else
        prot_pm_l1_exit    = prot_enter_l1  && ((pl_state_sts == RETRAIN) || (pl_protocol_cfg.cxl_mode_enable && (pl_state_sts == ACTIVE) && (upstream_port ? prot_pm_l1_exit_req : pl_rx_active_req)));
end

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)
        latch_prot_l1_exit    <=  #TP 1'b0;
    else if (prot_enter_l1 && lp_pm_l1_exit)
        latch_prot_l1_exit    <=  #TP 1'b1;
    else if (!prot_enter_l1)
        latch_prot_l1_exit    <=  #TP 1'b0;
end

assign int_pm_dllp_ack = pl_protocol_cfg.spif_enable ? xdlh_pm_dllp_ack : xplh_pm_dllp_ack;

// Generation of flags
pm_active_flags
 u_active_flags (
    // Inputs
    .core_clk                       (core_clk                           ),
    .core_rst_n                     (core_rst_n                         ),
     .cxl_pcie_flit_mode            (pl_protocol_cfg.cxl_pcie_flit_mode ),
    .smlh_link_up                   (smlh_link_up                       ),
    .smlh_in_l1                     (usp_link_l1                        ),
    .smlh_in_rl0s                   (smlh_in_rl0s                       ),
    .smlh_in_l0                     (smlh_in_l0                         ),
    .smlh_link_in_training          (int_smlh_link_in_training          ),
    .usp_link_l1_in_progress        (usp_link_l1_in_progress            ), // TOBEREMOVED
    .usp_prot_wait_dstate_update    (int_wait_dstate_update             ),
    .usp_prot_l1_block_tlp          (usp_prot_l1_block_tlp              ),
    .usp_prot_l1_wait_last_tlp_ack  (usp_prot_l1_wait_last_tlp_ack      ),
    .usp_prot_l1_wait_pmdllp_ack    (usp_prot_l1_wait_pmdllp_ack        ),
    .usp_prot_l23_block_tlp         (usp_prot_l23_block_tlp             ),
    .usp_prot_l23_wait_pmdllp_ack   (usp_prot_l23_wait_pmdllp_ack       ),
    .usp_prot_wait_last_pmdllp      (usp_prot_wait_last_pmdllp          ),
    .dsp_prot_wait_last_pmdllp      (dsp_prot_wait_last_pmdllp          ),
    .latch_as_entr_l1               (latch_as_entr_l1                   ),
    .radm_pm_asnak                  (radm_pm_asnak                      ),
    .pm_aspm_l1_en                  (pm_aspm_l1_en                      ),
    .pm_l23_entry_flag_clear        (int_l23_entry_flag_clear           ),
    .pm_l23_restart_clear           (int_l23_restart_clear              ),
    .pm_l23_entry_abort             (int_l23_entry_abort                ),
    .pm_req_ack_ena                 (int_pm_req_ack_ena                 ),
    .pm_dllp_ack                    (int_pm_dllp_ack                    ),
    .spif_enable                    (pl_protocol_cfg.spif_enable        ),
    .pl_state_sts                   (pl_state_sts                       ),
    .pm_prot_enter_l1               (lp_pm_l1_req                       ),
    .pm_prot_enter_l2               (lp_pm_l2_req                       ),
    .prot_pm_l1_exit                (prot_pm_l1_exit                    ),
    .prot_pm_l23_exit               (prot_pm_l23_exit                   ),
    // Outputs
    .prot_pm_l1_finish              (prot_pm_l1_finish                  ),
    .prot_pm_l23_finish             (prot_pm_l23_finish                 ),
    .pm_l1_aspm_flag                (pm_l1_aspm_flag                    ),
    .pm_l23_entry_flag              (pm_l23_entry_flag                  ),
    .pm_xdlh_dllp_req               (int_pm_xdlh_dllp_req               ),
    .pm_timeout                     (pm_timeout                         ),
    .pm_l23_entry_restart           (pm_l23_entry_restart               ),
    .pm_l23_hs_done                 (pm_l23_hs_done                     ),
    .pm_l1_pcipm_hs_done            (pm_l1_pcipm_hs_done                ),
    .pm_l1_aspm_hs_done             (pm_l1_aspm_hs_done                 )
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// PROT FSM related stimulus
// ----------------------------------------------------------------------------
// Take into account pending TLP's in XADM/XTLH/XDLH and insure XADM itself is IDLE
assign int_block_tlp_ack = !pm_wake_tlp_pending && xadm_block_tlp_ack && int_sdlh_block_tlp_ack ;

// dsp_prot_entering_block_tlp: asserted whenever the condition to enter
// DSP_PROT_BLOCK_TLP is met. This signal is used to block the other FSM
// from entering other states when DSP_PROT_FSM's next state is DSP_PROT_BLOCK_TLP.
assign dsp_prot_entering_block_tlp = int_link_up_not_rcvry && !upstream_port && ( (!pm_dllp_enable) ? (!lp_pm_l1_exit && !pl_rx_active_req) : (rdlh_rcvd_as_req_l1 || int_rdlh_rcvd_pm_enter_l1 || rdlh_rcvd_pm_enter_l23));  // entring the L1 or L23

// In CXL 256B flit mode, when vLSM does not expose the recovery to the link layer on pl_state_sts and we need to 
// restart Protocol FSM when Logical PHY goes through the recovery, if Protocol FSM has not reached PROT_ENTER_L1 or PROT_ENTER_L23 state.
assign int_phyinretrain = 1'b0 || (pl_protocol_cfg.cxl_pcie_flit_mode && !(prot_enter_l1 || prot_enter_l23) && pl_phyinretrain);

// IDLE indication for Protocol FSM must depend on the interface state and not on the recovery indication or smlh_link_up indication from LTSSM as
// Protocol FSM may go into RETRAIN on exit from L1 while Physical Layer is in L0 state.
assign prot_idle_next = !smlh_link_up || int_smlh_link_in_training;

assign prot_link_up_not_rcvry = smlh_link_up && !int_smlh_link_in_training;

// Link Layer is in ACTIVE state
assign prot_pm_to_active   = (pl_state_sts == ACTIVE) && !pl_stall_req;

// Protocol FSM - WAIT_DSTATE_UPDATE enter and exit controls
assign usp_entr_dstate_update = pl_protocol_cfg.spif_enable && !latch_as_entr_l1;
assign usp_exit_dstate_update = int_software_entr_l23 || (!int_software_entr_l1 && !lbc_active) || pm_timeout;

// Conditions to exit PM Protocol FSM from L1 and L23 to ACTIVE state
assign link_to_prot_l1_finish  = pl_protocol_cfg.spif_enable ? (prot_pm_l1_finish  && ((pl_state_sts == ACTIVE) || (pl_protocol_cfg.cxl_pcie_flit_mode && (pl_state_sts == ACTIVE_L0S_PMNAK)) )) : link_l1_finish;
assign link_to_prot_l23_finish = pl_protocol_cfg.spif_enable ? (prot_pm_l23_finish && ((pl_state_sts == ACTIVE) || (pl_protocol_cfg.cxl_pcie_flit_mode && (pl_state_sts == ACTIVE_L0S_PMNAK)) )) : link_l23_finish;

// Conditions to exit PM Protocol FSM from RST or RECOVERY to ACTIVE state
assign link_to_prot_to_active  = pl_protocol_cfg.spif_enable ? prot_pm_to_active  : prot_to_active;

assign int_nak_timer_expire = timeout_95us_reg
                              ;

// Conditions for transmitting Pm_Active_State_Nak when Pm_Active_State_Request_L1 received
// If recovery from L0 is enabled or ASPM is not enabled or there is a TLP pending or there
// is an ACK/NAK DLLP scheduled
assign int_next_resp_nak = (int_link_up_not_rcvry & !upstream_port & rdlh_rcvd_as_req_l1 & (~pm_aspm_l1_en | pm_wake_tlp_pending | !xdlh_no_acknak_dllp_pending));
assign int_pm_xmt_asnak = dsp_prot_active && int_next_resp_nak;

assign int_last_dllp_ack = pl_protocol_cfg.spif_enable ? pl_stall_req : (xplh_pm_dllp_ack.dllp_type==NOP_DLLP && int_pm_xdlh_dllp_req.dllp_type==NOP_DLLP);

assign int_csr_cpl_sent = !(lbc_active || int_l1_aspm_radm_race_r);

// The condition to enter L0s
assign int_dsp_enter_l0s = !pm_l2_entry_flag && int_l0s_idle_timeout_r;
assign int_usp_enter_l0s = int_l0s_idle_timeout_r;

// ----------------------------------------------------------------------------
// PROT FSM
// ----------------------------------------------------------------------------
// Multiplexing between USP and DSP Protocol FSMs
assign prot_enter_l1  = upstream_port ? usp_prot_enter_l1  : dsp_prot_enter_l1  ;
assign prot_enter_l23 = upstream_port ? usp_prot_enter_l23 : dsp_prot_enter_l23 ;
assign prot_enter_l0s = upstream_port ? usp_prot_enter_l0s : dsp_prot_enter_l0s ;

// Downstream Port Protocol Negotiation FSM
pm_active_dsp_prot_fsm
 u_pm_active_dsp_prot_fsm (
    // Inputs
    .core_clk                       (core_clk                           ),
    .core_rst_n                     (core_rst_n                         ),
    .upstream_port                  (upstream_port                      ),
    .spif_enable                    (pl_protocol_cfg.spif_enable        ),
    .pm_dllp_enable                 (pm_dllp_enable                     ),
    .smlh_link_up                   (smlh_link_up                       ),
    .latched_entr_l23               (latched_entr_l23                   ),
    .link_to_prot_to_active         (link_to_prot_to_active             ),
    .link_to_prot_l1_finish         (link_to_prot_l1_finish             ),
    .link_to_prot_l23_finish        (link_to_prot_l23_finish            ),
    .l0s_l0s_finish                 (l0s_l0s_finish                     ),
    .pm_enter_recovery              (int_idle_next                      ),
    .pm_enter_l0s                   (int_dsp_enter_l0s                  ),
    .pm_next_resp_nak               (int_next_resp_nak                  ),
    .pm_enter_block_tlp             (dsp_prot_entering_block_tlp        ),
    .pm_block_tlp_ack               (int_block_tlp_ack                  ),
    .pm_last_dllp_ack               (int_last_dllp_ack                  ),
    .pm_nak_timer_expire            (int_nak_timer_expire               ),
    .msg_gen_asnak_grt              (msg_gen_asnak_grt                  ),
    .xdlh_retry_pending             (xdlh_retry_pending                 ),
    // Ouputs
    .dsp_prot_rst                   (dsp_prot_rst                       ),
    .dsp_prot_recovery              (dsp_prot_recovery                  ),
    .dsp_prot_active                (dsp_prot_active                    ),
    .dsp_prot_respond_nak           (dsp_prot_respond_nak               ),
    .dsp_prot_nak_block_tlp         (dsp_prot_nak_block_tlp             ),
    .dsp_prot_wait_nak_tlp_ack      (dsp_prot_wait_nak_tlp_ack          ),
    .dsp_prot_wait_nak_timer        (dsp_prot_wait_nak_timer            ),
    .dsp_prot_block_tlp             (dsp_prot_block_tlp                 ),
    .dsp_prot_wait_last_tlp_ack     (dsp_prot_wait_last_tlp_ack         ),
    .dsp_prot_wait_last_pmdllp      (dsp_prot_wait_last_pmdllp          ),
    .dsp_prot_enter_l1              (dsp_prot_enter_l1                  ),
    .dsp_prot_enter_l23             (dsp_prot_enter_l23                 ),
    .dsp_prot_enter_l0s             (dsp_prot_enter_l0s                 )
    ,.pm_dsp_prot_state             (pm_dsp_prot_state                  )
);

// Upstream Port Protocol Negotiation FSM
pm_active_usp_prot_fsm
 #(
    .NVC      (NVC)
) u_pm_active_usp_prot_fsm (
    // inputs
    .core_clk                       (core_clk                           ),
    .core_rst_n                     (core_rst_n                         ),
    .upstream_port                  (upstream_port                      ),
    .pm_dllp_enable                 (pm_dllp_enable                     ),
    .smlh_link_up                   (smlh_link_up                       ),
    .link_to_prot_to_active         (link_to_prot_to_active             ),
    .link_to_prot_l1_finish         (link_to_prot_l1_finish             ),
    .link_to_prot_l23_finish        (link_to_prot_l23_finish            ),
    .l0s_l0s_finish                 (l0s_l0s_finish                     ),
    .software_entr_l23              (int_software_entr_l23              ),
    .int_start_l1_nego              (int_start_l1_nego                  ),
    .pm_enter_recovery              (int_idle_next                      ),
    .pm_enter_l0s                   (int_usp_enter_l0s                  ),
    .pm_block_tlp_ack               (int_block_tlp_ack                  ),
    .pm_l2_entry_flag               (pm_l2_entry_flag                   ),
    .pm_l23_entry_flag              (pm_l23_entry_flag                  ),
    .pm_l1_pcipm_hs_done            (pm_l1_pcipm_hs_done                ),
    .pm_l1_aspm_hs_done             (pm_l1_aspm_hs_done                 ),
    .pm_l23_hs_done                 (pm_l23_hs_done                     ),
    .pm_csr_cpl_sent                (int_csr_cpl_sent                   ),
    .pm_dllp_ack                    (int_pm_dllp_ack                    ),
    .pm_link_wait_dstate_update     (usp_link_wait_dstate_update        ), // TOBEREMOVED
    .pm_entr_dstate_update          (usp_entr_dstate_update             ),
    .pm_exit_dstate_update          (usp_exit_dstate_update             ),
    .latch_as_entr_l1               (latch_as_entr_l1                   ),
    .radm_pm_asnak                  (radm_pm_asnak                      ),
    .xdlh_retry_pending             (xdlh_retry_pending                 ),
    .xtlh_had_enough_credit         (xtlh_had_enough_credit             ),
    .rdlh_rcvd_pm_req_ack           (rdlh_rcvd_pm_req_ack               ),
    // outputs
    .usp_prot_rst                   (usp_prot_rst                       ),
    .usp_prot_recovery              (usp_prot_recovery                  ),
    .usp_prot_active                (usp_prot_active                    ),
    .usp_prot_enter_l0s             (usp_prot_enter_l0s                 ),
    .usp_prot_l1_block_tlp          (usp_prot_l1_block_tlp              ),
    .usp_prot_l1_wait_last_tlp_ack  (usp_prot_l1_wait_last_tlp_ack      ),
    .usp_prot_l1_wait_pmdllp_ack    (usp_prot_l1_wait_pmdllp_ack        ),
    .usp_prot_enter_l1              (usp_prot_enter_l1                  ),
    .usp_prot_l23_block_tlp         (usp_prot_l23_block_tlp             ),
    .usp_prot_l23_wait_last_tlp_ack (usp_prot_l23_wait_last_tlp_ack     ),
    .usp_prot_l23_wait_pmdllp_ack   (usp_prot_l23_wait_pmdllp_ack       ),
    .usp_prot_enter_l23             (usp_prot_enter_l23                 ),
    .usp_prot_wait_pmcsr_cpl_sent   (usp_prot_wait_pmcsr_cpl_sent       ),
    .usp_prot_wait_last_pmdllp      (usp_prot_wait_last_pmdllp          )
    ,.usp_prot_wait_dstate_update   (usp_prot_wait_dstate_update        )
    ,.pm_usp_prot_state             (pm_usp_prot_state                  )
);

// ----------------------------------------------------------------------------
// Latch L23 entry (to be used in the different FSMs):
// ----------------------------------------------------------------------------
// we need to latch the condition that make the DSP_LINK_FSM transition from
// idle to acknowledgment since it is different for DSP_LINK_FSM to go into
// L1 verse L23
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        latched_entr_l23    <= #TP 1'b0;
    end else begin
      if (!upstream_port) begin
        latched_entr_l23    <= #TP (dsp_prot_active && rdlh_rcvd_pm_enter_l23) ? 1'b1 : dsp_prot_active ? 1'b0 : latched_entr_l23;
      end else begin
        latched_entr_l23    <= #TP 1'b0;
      end
    end
end

// ----------------------------------------------------------------------------
// LP command request/acknowledge handshake on SDLH / XMLH Command Interface
// ----------------------------------------------------------------------------
assign int_sdlh_block_tlp_ack  = pl_protocol_cfg.spif_enable ? sdlh_block_tlp_ack : xmlh_cmd_if_lp_ack;

assign int_xmlh_lp_req_rst = int_cmd_if_lp_ack_r && ((
                                 // In SPIF arch, pm_xmlh_lp_req will be de-asserted when lp_pm_l1_req and lp_pm_l2_req
                                 // are asserted indicating protocol negotiation is finished.
                                 // TBD: Revisit how this condition is contrained
                                 pl_protocol_cfg.spif_enable ? (lp_pm_l1_req || lp_pm_l2_req || lp_pm_l0s_req) :
                                 (pm_linkst_in_l1 || pm_linkst_in_l2)) || dsp_prot_wait_nak_timer)
                                 // pm_xmlh_lp_req should be de-asserted when protocal FSM goes to recovery/active without condition
                                 || (upstream_port ? (usp_prot_active || usp_prot_recovery) : (dsp_prot_active || dsp_prot_recovery));

always_ff @(posedge core_clk or negedge core_rst_n) begin : lp_ack_PROC
  if(!core_rst_n)
    int_cmd_if_lp_ack_r <= #TP '0;
  else begin
    if(!pm_xmlh_lp_req)
      int_cmd_if_lp_ack_r <= #TP '0;
    else if(int_sdlh_block_tlp_ack)
      int_cmd_if_lp_ack_r <= #TP '1;
  end
end : lp_ack_PROC

// Request XMLH LP entry (flush of XTLH) if TLP blocking and XADM/XAIM has no more TLP Pending
// PM should request XMLH LP Entry during Phase 3 negotiation based on Link FSM and not Protocol FSM therefore
// this request is disabed in CXL mode, it is handles with stall_req/ack handshake on the Physical Layer SPIF interface
always_ff @(posedge core_clk or negedge core_rst_n) begin : lp_req_PROC
  if(!core_rst_n)
    pm_xmlh_lp_req    <= #TP 1'b0;
  else begin
    if(int_xmlh_lp_req_rst)
      pm_xmlh_lp_req  <= #TP 1'b0;
    // Block TLP state entered and XADM is blocking TLP's
    else if((usp_prot_l1_block_tlp || usp_prot_l23_block_tlp || dsp_prot_nak_block_tlp || dsp_prot_block_tlp || (pl_protocol_cfg.spif_enable && l0s_l0s_block_tlp)) && xadm_block_tlp_ack)
      pm_xmlh_lp_req  <= #TP 1'b1;
    else
      pm_xmlh_lp_req  <= #TP pm_xmlh_lp_req;
  end
end : lp_req_PROC

// ----------------------------------------------------------------------------
// L0s Idle detection, and resulting L0s entry signal
// ----------------------------------------------------------------------------
// requirements for idleness in L0S
assign int_l0s_det_idle = ((!pm_wake_tlp_pending || (&xadm_no_fc_credit)) && xdlh_not_expecting_ack && xdlh_nodllp_pending && pm_aspm_l0s_en
                            && !smlh_in_l1 && !smlh_in_l23
                            && (!switch_device || (all_dwsp_in_rl0s && upstream_port && switch_device)
                            || (upsp_in_rl0s && !upstream_port & switch_device)));

// increment the L0S idle timer when we are IDLE and in L0
// Note: use usp_prot_active to indicate idle and L0
// For USP, L0s idle timer only active when both USP PROT FSM
// and USP LINK FSM are in idle
// For DSP, L0s idle timer only active when both DSP PROT FSM
// and DSP LINK FSM are in idle
// L0S is not supported in CXL mode. Do not increment L0S idle timer.
assign l0s_entr_cond4timeout_met = ((usp_prot_active && dsp_prot_active) && int_l0s_det_idle && !pl_protocol_cfg.cxl_mode_enable);

// Choosing of the idle timer value is application specific. We have
// a l0s_entr_latency_timer programmable from port logic register to allow
// application to choose an algorithm and program the value
always @(l0s_entr_latency_timer )
    case (l0s_entr_latency_timer)
        3'b000:  l0s_idle_timer_value = 11'b00100000000 ;  // 1 us
        3'b001:  l0s_idle_timer_value = 11'b01000000000 ;  // 2 us
        3'b010:  l0s_idle_timer_value = 11'b01100000000 ;  // 3 us
        3'b011:  l0s_idle_timer_value = 11'b10000000000 ;  // 4 us
        3'b100:  l0s_idle_timer_value = 11'b10100000000 ;  // 5 us
        3'b101:  l0s_idle_timer_value = 11'b11000000000 ;  // 6 us
        3'b110:  l0s_idle_timer_value = 11'b11100000000 ;  // 7 us
        default: l0s_idle_timer_value = 11'b11100000000 ;  // 7 us
    endcase

// L0s timer increments on:
// 1. no tlp pendings or dllp pending or no flow control
// credits
// 2. (when it is end device or root complex or bridge) or
// a switch device with upstream port in received lanes are all
// in l0s state, or a switch device with all downstream ports
// receive lanes in l0s state
// 3. software configured this port to enable l0s transition
// 4. idle timer expired
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        l0s_idle_timer  <= #TP 0;
    end else begin
        // Enable L0S timer
        if (l0s_entr_cond4timeout_met) begin
            l0s_idle_timer  <= #TP l0s_idle_timer + (timer2 ? FREQ_MULTIPLIER : 1'b0);
        end else begin
            l0s_idle_timer  <= #TP {14{1'b0}};
        end
    end
end

wire        l0s_idle_timeout;
assign l0s_idle_timeout = pm_aspm_l0s_en & (l0s_idle_timer[10:0] >= (l0s_idle_timer_value - FREQ_MULTIPLIER));

// set flag to indicate L0S idle timeout
assign int_clear_l0s_timeout = usp_prot_wait_pmcsr_cpl_sent || usp_prot_l1_block_tlp || usp_prot_l23_block_tlp || l0s_l0s_block_tlp || !smlh_link_up;
always @ *
begin
  if(int_clear_l0s_timeout)
    int_l0s_idle_timeout_s = 1'b0;
  else if(l0s_idle_timeout)
    int_l0s_idle_timeout_s = 1'b1;
  else
    int_l0s_idle_timeout_s = int_l0s_idle_timeout_r;
end

always @(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n) begin
    int_l0s_idle_timeout_r <= #TP 1'b0;
  end else begin
    int_l0s_idle_timeout_r <= #TP int_l0s_idle_timeout_s;
  end
end

// ----------------------------------------------------------------------------
// L0s FSM and related logic
// ----------------------------------------------------------------------------
logic  int_pm_l0s_req; // L0S request from the Link Layer to change lp_state_req on SPIF Interface

assign int_pm_l0s_req = l0s_l0s_enter_l0s || (l0s_l0s && !int_l0s_exit);

always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n) begin
    lp_pm_l0s_req <= #TP 1'b0;
  end else begin
    lp_pm_l0s_req <= #TP int_pm_l0s_req;
  end
end

assign int_l0s_exit = (pm_wake_req_exit_l0s || !xdlh_nodllp_pending || !smlh_in_l0s              // smlh_in_l0 is an error condition that gets ltssm exited the xmt l0s exit
 || dsp_prot_entering_block_tlp                                  // For DSP, if there is req to enter l1, exit l0s
                       || (!upsp_in_rl0s && !upstream_port && switch_device) || (!all_dwsp_in_rl0s && upstream_port && switch_device)  // exit of l0s for switch device
                       || (l1_idle_timeout && ((upstream_port && !switch_device) || (all_dwsp_in_l1 && switch_device && upstream_port))));

pm_active_l0s_fsm

    // Parameters
    #(
     ) u_pm_active_l0s_fsm (
       // Inputs
       .core_clk               (core_clk         ),
       .core_rst_n             (core_rst_n       ),
       .prot_enter_l0s         (prot_enter_l0s   ),
       .int_block_tlp_ack      (int_block_tlp_ack),
       .int_l0s_det_idle       (int_l0s_det_idle ),
       .int_idle_next          (int_idle_next    ),
       .smlh_in_l0s            (smlh_in_l0s      ),
       .int_l0s_exit           (int_l0s_exit     ),

       // Ouputs
       .l0s_l0s_idle           (l0s_l0s_idle     ),
       .l0s_l0s_block_tlp      (l0s_l0s_block_tlp),
       .l0s_l0s_enter_l0s      (l0s_l0s_enter_l0s),
       .l0s_l0s                (l0s_l0s          ),
       .l0s_l0s_exit           (l0s_l0s_exit     ),
       .l0s_l0s_finish         (l0s_l0s_finish   )
       ,.pm_l0s_state          (pm_l0s_state     )
);

// -----------------------------------------------------------------------------
// Time Tick generator
// -----------------------------------------------------------------------------
DWC_pcie_tim_gen
 #(
     .CLEAR_CNTR_TO_1       (0                  )
) u_gen_timer2 (
     .clk                   (core_clk           )
    ,.rst_n                 (core_rst_n         )

    ,.current_data_rate     (pl_speedmode       )
    ,.clr_cntr              (1'b0               ) // clear cycle counter(not used in this timer)
    ,.cnt_up_en             (timer2             ) // timer count-up
);

// ----------------------------------------------------------------------------
// PM DLLP Timer
// ----------------------------------------------------------------------------
logic  pm_hold_dllp_timer;
// In SPIF mode, hold the timer when in ACTIVE state or sub-states and datapath is not stalled, or when in RETRAIN state.
assign pm_hold_dllp_timer = pl_protocol_cfg.spif_enable ? (((pl_state_sts inside {ACTIVE, ACTIVE_L0S_PMNAK}) && pl_stall_req) || (pl_state_sts == RETRAIN)) : pm_link_hold_dllp_timer;

// For an Upstream port this timer implements the 10us timer requirement between
// transmission of PM_Active_State_Request_L1 DLLP's after a PM_Active_State_Nak message
// is received. For a Downstream port this timer implements the 9.5us timer requirement
// after the transmission of a PM_Active_State_Nak message during which the Downstream port
// does not receive any PM_Active_State_Enter_L1 DLLP's.
always @(posedge core_clk or negedge core_rst_n)
begin : timer_PROC
  if(!core_rst_n) begin
    timer <= #TP 0;
  // Reset the timer if the link goes down
  end else if(!smlh_link_up) begin
    timer <= #TP 0;
  // The timer holds in RECOVERY
  end else if(pm_hold_dllp_timer) begin
    timer <= #TP timer;
  // For USP the timer counts in L0, DSP the timer counts in the DSP_PROT_WAIT_NAK_TIMER state
  end else if((upstream_port && (usp_prot_active || l0s_l0s_block_tlp || l0s_l0s_enter_l0s || l0s_l0s || l0s_l0s_exit) && !timer_10us_expired_reg) ||
              (!upstream_port && dsp_prot_wait_nak_timer && !timeout_95us_reg)) begin
    timer  <= #TP timer + (timer2 ? 1'b1 : 1'b0);
  // Otherwise reset the timer
  end else begin
    timer <= #TP 0;
  end
end : timer_PROC

// 9.728 us timeout for errata C7 9.5 us
assign timer_95us_expired   = (FREQ_VALUE==0) ?  (timer[11] & timer[8] & timer[7]) :
                              (FREQ_VALUE==1) ?  (timer[10] & timer[7] & timer[6]) :
                                                 (timer[ 9] & timer[6] & timer[5]);

always @(posedge core_clk or negedge core_rst_n)
begin : timer_95_PROC
    if(!core_rst_n) begin
      timeout_95us_reg <= #TP 1'b1;
    // Set when the timer expires, Receiver goes to L0S, or link goes down
    // If a PM_Enter_L1 or PM_Enter_L23 DLLP is received for the timer to expire.
    end else if (timer_95us_expired || smlh_in_rl0s || !smlh_link_up || rdlh_rcvd_pm_enter_l1 || rdlh_rcvd_pm_enter_l23) begin
      timeout_95us_reg <= #TP 1'b1;
    // Reset to 0 before the timer is started
    end else if (dsp_prot_wait_nak_tlp_ack) begin
      timeout_95us_reg <= #TP 1'b0;
    // Hold the value
    end else begin
      timeout_95us_reg <= #TP timeout_95us_reg;
    end
end : timer_95_PROC

// 10.24 us timeout for errata C7 10 us
assign timer_10us_expired       = (FREQ_VALUE==0) ?  (timer[11] & timer[9]) :
                                  (FREQ_VALUE==1) ?  (timer[10] & timer[8]) :
                                                     (timer[ 9] & timer[7]);

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
        timer_10us_expired_reg  <= #TP 1'b1;
    // clear the flag if a Nak is received in response to L1 ASPM request
    else if (radm_pm_asnak)
        timer_10us_expired_reg  <= #TP 1'b0;
    // If the link goes down or the Trasmitter enters L0S the flag is set.
    // If the timer expires or PM_Enter_L1/PM_Enter_L23 DLLP's are being transmitted.
    else if ((!smlh_link_up) || l0s_l0s_exit || timer_10us_expired || pm_xdlh_enter_l1 || pm_xdlh_enter_l23)
        timer_10us_expired_reg  <= #TP 1'b1;
end



// ----------------------------------------------------------------------------
// Outputs generation
// ----------------------------------------------------------------------------
logic  pm_prot_block_all_tlp;
assign pm_prot_block_all_tlp = (    l0s_l0s_block_tlp
                                 || l0s_l0s_enter_l0s
                                 || usp_prot_l1_block_tlp
                                 || usp_prot_l23_block_tlp
                                 || usp_prot_l1_wait_last_tlp_ack
                                 || usp_prot_l23_wait_last_tlp_ack
                                 || usp_prot_l1_wait_pmdllp_ack
                                 || usp_prot_l23_wait_pmdllp_ack
                                 || (usp_prot_enter_l1 && ( pl_protocol_cfg.spif_enable ? 1'b1 : !usp_link_wait_dstate_update))
                                 || usp_prot_enter_l23
                                 || usp_prot_wait_last_pmdllp
                                 || dsp_prot_block_tlp
                                 || dsp_prot_wait_last_tlp_ack
                                 || dsp_prot_enter_l1
                                 || dsp_prot_enter_l23
                                 || dsp_prot_wait_last_pmdllp
                                 || dsp_prot_nak_block_tlp
                                 || dsp_prot_wait_nak_tlp_ack
                               );


// If flush enabled on link down then overide the block on the XADM transmit interfaces.
assign pm_block_all_tlp = rstctl_core_flush_req ? 1'b0 : int_pm_block_all_tlp;

assign pm_wake_tlp_pending = xadm_tlp_pending || xtlh_tlp_pending || xdlh_tlp_pending
                             || xaim_tlp_pending 
                             || xplh_pending && !pl_protocol_cfg.pcie_flit_mode
;

// output driven process
always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n) begin
    pm_smlh_l0s_exit        <= #TP 1'b0;
    pm_smlh_entry_to_l0s    <= #TP 1'b0;
    pm_linkst_in_l0s        <= #TP 1'b0;
    pm_smlh_dllp_hs         <= #TP 1'b0;
    pm_freeze_fc_timer      <= #TP 1'b0;
   pm_xmt_asnak             <= #TP 1'b0;
  end else begin
    // Beneath are the signal commands the LTSSM state machine to go into the proper low power state
    pm_smlh_l0s_exit        <= #TP l0s_l0s_exit;
    pm_smlh_entry_to_l0s    <= #TP l0s_l0s_enter_l0s;
    pm_linkst_in_l0s        <= #TP l0s_l0s;
    // During DLLP handshake, DSP waits for eidle to terminate its PM_Req_Ack
    // before it goes to eidle. This signal askes LTSSM to stay in L0 when it
    // receives eidle (don't go to L0s or recovery).
    pm_smlh_dllp_hs         <= #TP dsp_prot_wait_last_pmdllp | dsp_prot_enter_l1 | dsp_prot_enter_l23;
    pm_xmt_asnak            <= #TP int_pm_xmt_asnak;
    // this signal is designed to notify the xdlh that the fc timer
    // should be blocked since we will not send fc dllp based on timer expiration
    // during L1 or L23 state
    pm_freeze_fc_timer      <= #TP pl_protocol_cfg.spif_enable ? ((lp_state_req inside {IDLE_L1_1, L2}) || (pl_state_sts inside {IDLE_L1_1, L2})) : pm_link_freeze_fc_timer;
  end
end


// ----------------------------------------------------------------------------
// Block TLP conditions
// ----------------------------------------------------------------------------
logic  link_up;

assign link_up = rdlh_link_up; // TBD: lp_dl_active for SPIF

always_ff @(posedge core_clk or negedge core_rst_n) begin : block_all_tlp_PROC
  if(!core_rst_n)
    int_pm_block_all_tlp <= #TP '0;
  else begin
    // Beneath are the signals designed to notify the xdlh for transmiting PM DLLP
    // This signal is designed to notify the xtlh or xadm to block any tlp transmit
    // request other than pm message
    // Only in certain states which we need to block off the TLP
    int_pm_block_all_tlp <= #TP !link_up || pm_prot_block_all_tlp || ( pl_protocol_cfg.spif_enable ? 1'b0 : pm_link_block_all_tlp);
  end
end : block_all_tlp_PROC

// For multistream, collect pending signals and form the block all tlp ack
assign xadm_block_tlp_ack = int_block_tlp_r[2] && !(xadm_tlp_pending || xaim_tlp_pending);

// Delay pm_block_all_tlp to gate with the pending signals from XAIM/XADM
// First cycle XAIM may receive TLP at the same time as pm_block_all_tlp
// Second cycle XAIM pending may go high
// Third cycle XAIM pending should be stable and halt asserted to the client.
always_ff @(posedge core_clk or negedge core_rst_n) begin : block_tlp_PROC
  if(!core_rst_n)
    int_block_tlp_r <= #TP '0;
  else begin
    if(!int_pm_block_all_tlp)
      int_block_tlp_r <= #TP '0;
    else
      int_block_tlp_r <= #TP {int_block_tlp_r[1:0], int_pm_block_all_tlp};
  end
end : block_tlp_PROC
// ----------------------------------------------------------------------------




endmodule // pm_protocol_fsm
