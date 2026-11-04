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
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #4 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/sdlh.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Data Link Layer State Management (SDLH) module
//
// Implements Link Layer SPIF and Command Interfaces
// Implements the logic for Protocol Power Management
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
`include "products/cx_pl_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module sdlh
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::tx_cmd_e;
  import cx_pl_pkg::tx_cmd_struct;
  import spif_pkg::protocol_cfg_t;
  import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
  import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
  import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
  import cx_pl_pkg::l0p_ack_struct;
  import cx_pl_pkg::l0p_dllp_struct;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
#(
  parameter  TP            = `TP
) 
             (
  //------------------------------------------------------------------------------
  // SPIF Interface
  //------------------------------------------------------------------------------
  spif_if.xplh_master_mp                 b_xdlh_spif,                     // XDLH SPIF interface
  spif_if.rplh_master_mp                 b_rdlh_spif,                     // RDLH SPIF interface
  spif_if.cfgi_master_mp                 b_cfgi_spif,                     // CFGI SPIF interface
  spif_if.slave_mp                       b_splh_spif,                     // SPLH SPIF interface
  //------------------------------------------------------------------------------
  // Clock&Reset
  //------------------------------------------------------------------------------
  input                                  core_clk,                        // Core clock
  input                                  core_rst_n,                      // Core reset
  //------------------------------------------------------------------------------
  // Configuration Interface
  //------------------------------------------------------------------------------
  input                                  cfg_upstream_port,               // CFG: 1 indicate that it is an upstream port (EP/upstream port of a SW)
  input  [2:0]                           l0s_entr_latency_timer,          // CDM: L0s transmitter L0s exit timer
  input  [2:0]                           l1_entr_latency_timer,           // CDM: L1 transmitter l1 exit timer
  input                                  pm_l1_entr_wo_rl0s,              // CDM: Start L1 timer without rL0s
  input                                  pm_aspm_l1_timer_enable,         // CDM: Control ASPM L1 timer
  input  [3:0]                           cfg_dsp_pcipm_l1_enter_delay,    // CDM: PCIPM L1 entry delay
  input                                  cfg_rasdp_linkdown_en,           // Enable Link Down on RASDP uncorrectable error
  output  usp_prot_fsm_state_e           pm_usp_prot_state,               // CDM: RAS-DES PM USP Protocol FSM state
  output  dsp_prot_fsm_state_e           pm_dsp_prot_state,               // CDM: RAS-DES PM DSP Protocol FSM state
  output  pm_active_l0s_fsm_e            pm_l0s_state,                    // CDM: RAS-DES PM L0S Protocol FSM state
  //------------------------------------------------------------------------------
  // Application Interface
  //------------------------------------------------------------------------------
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
  input  [`CX_NVC-1:0]                   xtlh_had_enough_credit,          // XTLH had enough credit
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
  input                                  rdlh_link_up,                    // RDLH Link Up (DL_Active)
  input  [1:0]                           rdlh_link_state,                 // RDLH DLCMSM State
  input                                  rdlh_retrain_req,                // RDLH Retrain Request
  input                                  rtlh_retrain_req,                // RTLH Retrain Request
  input                                  xdlh_retrain_req,                // XDLH Retrain Request
  output  logic                          pm_freeze_fc_timer,              // RTLH: Command to freeze FC Timer
  output  dllp_struct                    pm_xdlh_dllp_req,                // XDLH DLLP Request
  //------------------------------------------------------------------------------
  // DWC_pcie_core Interface
  //------------------------------------------------------------------------------
  input                                  xaim_tlp_pending,                // XAIM TLP pending flag
  input                                  xadm_tlp_pending,                // XADM TLP pending flag
  input  [`CX_NVC-1:0]                   xadm_no_fc_credit,               // XADM no FC credits are available to transmit anything
  input                                  radm_pm_asnak,                   // RADM received AS_NAK
  input                                  radm_trgt0_pending,              // RADM indicates that TLP is enroute to TRGT0, delay L1 entry
  input                                  msg_gen_asnak_grt,               // MSGGEN: Indication from msg_gen that PM_Active_State_Nak has been granted
  input                                  lbc_active,                      // LBC: LBC may require a CPL to be sent, stop L1 timer
  input                                  pm_rstctl_core_flush_req,        // Reset Controller: flush request
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
  input                                  lp_pcie_l1_exit,                 // PM WakeUp requests Link Layer to exit from L1
  input                                  lp_pcie_clk_ack,                 // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
  input                                  lp_pcie_wake_req,                // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
  input                                  pm_cfg_retrain_req,              // Config Retrain Request (latched in PM Wakeup)
  input                                  pm_app_init_rst,                 // Application Link Reset Request (latched in PM Wakeup)
  output                                 pm_prot_req_l2,                  // PM Protocol FSM L2 Request
  output                                 pm_block_tlp_ack,                // PM Protocol FSM BLOCK_TLP Acknowledge
  input                                  xdlh_sdlh_cmd_ack,               // Command Complete Acknowledge from XDLH to SDLH
  output  tx_cmd_struct                  sdlh_xdlh_cmd,                   // Command from SDLH to XDLH
  output                                 xdlh_xplh_cmd_ack,               // Command Complete Acknowledge from XDLH to XPLH
  input   tx_cmd_struct                  xplh_xdlh_cmd,                   // Command from XPLH to XDLH
  input                                  xdlh_lp_stall_ack,               // XDLH Stall Acknowledge
  output                                 xdlh_pl_stall_req,               // XDLH Stall Request
  output                                 xdlh_pm_state_req,               // XDLH PM Entry Request (allows DLLP propagation when stall_req is asserted)
  output  protocol_cfg_t                 pl_protocol_cfg,                 // Protocol Configuration for DLH Layer
  //------------------------------------------------------------------------------
  // Sideband Interface
  //------------------------------------------------------------------------------
  output  logic                          lp_sdb_l1sub_aspm,               // Sideband signal that indicates ASPM L1 Entry for L1-substates implementation in the LogPHY
  output  logic                          lp_sdb_l1sub_pcipm,              // Sideband signal that indicates PCI-PM L1 Entry for L1-substates implementation in the LogPHY
  input   pm_link_to_protocol_struct     pm_link_to_protocol_signals,     // TOBEREMOVED: PM Link FSM to Protocol FSM connections
  output  pm_protocol_to_link_struct     pm_protocol_to_link_signals      // TOBEREMOVED: PM Protocol FSM to Link FSM connections
  // -------------------------------------------------------------------------------------
  // L0P Interface
  // -------------------------------------------------------------------------------------
  ,
  // CDM Interface
  input                                  cfg_l0p_enable,                  // L0p Enable
  input                                  cfg_l0p_autowidth_dis,           // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
  input                                  cfg_l0p_priority,                // Port Logic register bit to set L0p.Priority bit in DLLP
  input   [2:0]                          cfg_l0p_linkmode,                // Target Link Width in Device Control 3 Register (bit[6:4])
  input                                  cfg_l0p_linkmode_req,            // Link Width change request asserted on the write access to Device Control 3 Register
  input   [5:0]                          cfg_l0p_max_link_width,          // Maximum supported Link Width
  input   [5:0]                          cfg_l0p_neg_link_width,          // Negotiated Link Width
  input                                  cfg_pcie_l0p_disable,            // PCIe/CXL.io: Disable dynamic L0p
  input                                  cfg_pcie_l0p_request,            // PCIe/CXL.io: L0p Request bit
  input                                  cfg_pcie_l0p_priority,           // PCIe/CXL.io: L0p Priority bit
  input   [2:0]                          cfg_pcie_l0p_linkmode,           // PCIe/CXL.io: L0p Target Link Width
  output  logic                          app_dynamic_l0p_enable,          // Application Interface signal indicates that Dynamic L0p is enabled
  output  logic                          app_dynamic_l0p_rejected,        // Application Interface signal indicates that L0p request is NAK-ed
  // LTSSM Interface 
  input                                  smlh_l0p_capable,                // TOBEREMOVED: L0P Capable device
  input   [5:0]                          smlh_l0p_link_mode,              // TOBEREMOVED: Indicate the active lanes and final negotiated link width
  input                                  smlh_xdlh_eios_rcvd,             // TOBEREMOVED: EIOS received
  output                                 xdlh_smlh_link_req,              // TOBEREMOVED: L0P Request to L1
  output  logic                          xdlh_smlh_link_initiated,        // TOBEREMOVED: L0P Request is initiated from the requester FSM
  input                                  smlh_ltssm_l0p_ready,            // TOBEREMOVED: L1 ready for L0P negotiation
  output  [4:0]                          xdlh_smlh_link_width,            // TOBEREMOVED: L0P Requested link width to L1
  output  logic                          xdlh_smlh_enter_recovery,        // TOBEREMOVED: Direct LTSSM to enter recovery
  //Layer2/XPLH Interface
  output                                 xplh_flit_count_en,              // TOBEREMOVED: Enable TX Flit Count
  input   [2:0]                          xplh_flit_count,                 // TOBEREMOVED: TX Flit Count
  input   [5:0]                          smlh_link_mode,                  // TOBEREMOVED: Negotiated link width during Cfg state of LTSSM
  // XDLH L0P Interface
  output  dllp_struct                    xdlh_l0p_dllp,                   // L0P DLLP
  input   l0p_ack_struct                 xdlh_dllp_l0p_ack,               // Acknowledge the L0P DLLP has been Transmitted
  input                                  xplh_l0p_dllps_count,
  // RDLH L0P Interface 
  input   l0p_dllp_struct                rdlh_xdlh_l0p_dllp,              // Received L0P DLLP Structure
  input                                  rdlh_xdlh_fm_dllp_valid,         // Valid DLLP data
  // Rate Information 
  input   [2 : 0]                        current_data_rate                // Data Rate Negotiated with the PHY
);

logic          pm_prot_req_l0s;   // PM Protocol FSM L0S Request
logic          pm_prot_req_l1;    // PM Protocol FSM L1 Request
logic          int_xdlh_retrain_req;
logic          pl_linkmode_rdy;   // LogPHY is ready to accept new Link Mode Request
logic [5:0]    pl_linkmode_cfg;   // LogPHY negotiated Link Mode during Configuration phase
logic [2:0]    pl_l0p_flit_count; // LogPHY flit count
logic          sdlh_cmd_if_ack;   // SDLH Command Interface Acknowledge
tx_cmd_struct  sdlh_cmd_if_cmd;   // SDLH Command Interface Request

// XDLH Command Interface Mux
// For CXL mode, XDLH command interface is driven from SDLH
// For PCIe mode, XDLH command interface is driven from XPLH
// command interface is driven by XPLH
assign sdlh_xdlh_cmd     = pl_protocol_cfg.spif_enable ? sdlh_cmd_if_cmd : xplh_xdlh_cmd;
// For CXL mode, command ack from XDLH is irrelevant, XPLH command is acknowledged internally based on XPLH state
assign xdlh_xplh_cmd_ack = pl_protocol_cfg.spif_enable ? 1'b0 : xdlh_sdlh_cmd_ack;
// For PCIe mode, command ack from XDLH is irrelant, as SDLH to XDLH command interface is not enabled and
// command interface is driven by XPLH
assign sdlh_cmd_if_ack   = pl_protocol_cfg.spif_enable ? xdlh_sdlh_cmd_ack : 1'b0;
assign int_xdlh_retrain_req = xdlh_retrain_req || (pl_protocol_cfg.spif_enable ? xdlh_smlh_enter_recovery : 1'b0);

// -------------------------------------------------------------------------------------
// SDLH SPIF Instantiation
// -------------------------------------------------------------------------------------
sdlh_spif
 u_sdlh_spif (
    // Interfaces
    .b_xdlh_spif           ( b_xdlh_spif                  ),
    .b_rdlh_spif           ( b_rdlh_spif                  ),
    .b_cfgi_spif           ( b_cfgi_spif                  ),
    .b_splh_spif           ( b_splh_spif                  ),
    // Inputs
    .core_clk              ( core_clk                     ),
    .core_rst_n            ( core_rst_n                   ),
    .cfg_rasdp_linkdown_en ( cfg_rasdp_linkdown_en        ),
    .rdlh_link_state       ( rdlh_link_state              ),
    .rdlh_retrain_req      ( rdlh_retrain_req             ),
    .rtlh_retrain_req      ( rtlh_retrain_req             ),
    .xdlh_retrain_req      ( int_xdlh_retrain_req         ),
    .pm_cfg_retrain_req    ( pm_cfg_retrain_req           ),
    .pm_app_init_rst       ( pm_app_init_rst              ),
    .lp_pcie_clk_ack       ( lp_pcie_clk_ack              ),
    .lp_pcie_wake_req      ( lp_pcie_wake_req             ),
    .pm_prot_req_l0s       ( pm_prot_req_l0s              ),
    .pm_prot_req_l1        ( pm_prot_req_l1               ),
    .pm_prot_req_l2        ( pm_prot_req_l2               ),
    .lp_linkmode_req       ( xdlh_smlh_link_req           ),
    .lp_linkmode_rmt       ( !xdlh_smlh_link_initiated    ),
    .lp_linkmode           ( {1'b0, xdlh_smlh_link_width} ),
    .lp_l0p_flit_count_en  ( xplh_flit_count_en           ),
    .xdlh_lp_stall_ack     ( xdlh_lp_stall_ack            ),
    // Outputs
    .xdlh_pl_stall_req     ( xdlh_pl_stall_req            ),
    .xdlh_pm_state_req     ( xdlh_pm_state_req            ),
    .pl_linkmode_rdy       ( pl_linkmode_rdy              ),
    .pl_linkmode_cfg       ( pl_linkmode_cfg              ),
    .pl_l0p_flit_count     ( pl_l0p_flit_count            ),
    .pl_protocol_cfg       ( pl_protocol_cfg              )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// SDLH to XDLH Command Interface Instantiation
// -------------------------------------------------------------------------------------
sdlh_cmd_if
 u_sdlh_cmd_if (
    // Inputs
    .core_clk          ( core_clk                       ),
    .core_rst_n        ( core_rst_n                     ),
    .cmd_if_enable     ( pl_protocol_cfg.spif_enable    ),
    .pcie_flit_mode    ( pl_protocol_cfg.pcie_flit_mode ),
    .pm_block_tlp_req  ( pm_xmlh_lp_req                 ),
    .lp_state_req      ( b_splh_spif.s_lp_state_req     ),
    .lp_stall_ack      ( b_splh_spif.s_lp_stall_ack     ),
    .pl_state_sts      ( b_splh_spif.s_pl_state_sts     ),
    .pl_stall_req      ( b_splh_spif.s_pl_stall_req     ),
    .sdlh_cmd_if_ack   ( sdlh_cmd_if_ack                ),
    // Outputs
    .pm_block_tlp_ack  ( pm_block_tlp_ack               ),
    .sdlh_cmd_if_cmd   ( sdlh_cmd_if_cmd                )
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Protocol PM logic
// -------------------------------------------------------------------------------------
pm_protocol_fsm
 u_pm_protocol_fsm (
    .core_clk                       ( core_clk                         ),
    .core_rst_n                     ( core_rst_n                       ),
    .switch_device                  ( 1'b0                             ),
    .upstream_port                  ( cfg_upstream_port                ),
    .l0s_entr_latency_timer         ( l0s_entr_latency_timer           ),
    .l1_entr_latency_timer          ( l1_entr_latency_timer            ),
    .pm_l1_entr_wo_rl0s             ( pm_l1_entr_wo_rl0s               ),
    .pm_aspm_l1_timer_enable        ( pm_aspm_l1_timer_enable          ),
    .cfg_dsp_pcipm_l1_enter_delay   ( cfg_dsp_pcipm_l1_enter_delay     ),
    .pm_usp_prot_state              ( pm_usp_prot_state                ),
    .pm_dsp_prot_state              ( pm_dsp_prot_state                ),
    .pm_l0s_state                   ( pm_l0s_state                     ),
    .all_dwsp_in_l1                 ( 1'b0                             ),
    .all_dwsp_in_rl0s               ( 1'b0                             ),
    .upsp_in_rl0s                   ( 1'b0                             ),
    .app_req_entr_l1                ( app_req_entr_l1                  ),
    .app_xfer_pending               ( app_xfer_pending                 ),
    .pm_l1_entry_started            ( pm_l1_entry_started              ),
    .pm_aspm_l1_enter_ready         ( pm_aspm_l1_enter_ready           ),
    .pm_wake_req_exit_l0s           ( pm_wake_req_exit_l0s             ),
    .pm_wake_any_if_pending         ( pm_wake_any_if_pending           ),
    .pm_l1_in_progress              ( pm_l1_in_progress                ),
    .latch_as_entr_l1               ( latch_as_entr_l1                 ),
    .software_entr_l1               ( software_entr_l1                 ),
    .software_entr_l23              ( software_entr_l23                ),
    .pm_aspm_l0s_en                 ( pm_aspm_l0s_en                   ),
    .pm_aspm_l1_en                  ( pm_aspm_l1_en                    ),
    .pm_l2_entry_flag               ( pm_l2_entry_flag                 ),
    .pm_xdlh_enter_l23              ( pm_xdlh_enter_l23                ),
    .pm_prot_idle_flag              ( pm_prot_idle_flag                ),
    .xtlh_had_enough_credit         ( xtlh_had_enough_credit           ),
    .xtlh_tlp_pending               ( xtlh_tlp_pending                 ),
    .xdlh_tlp_pending               ( xdlh_tlp_pending                 ),
    .xdlh_retry_pending             ( xdlh_retry_pending               ),
    .xdlh_not_expecting_ack         ( xdlh_not_expecting_ack           ),
    .xdlh_nodllp_pending            ( xdlh_nodllp_pending              ),
    .xdlh_no_acknak_dllp_pending    ( xdlh_no_acknak_dllp_pending      ),
    .xdlh_pm_dllp_ack               ( xdlh_pm_dllp_ack                 ),
    .rdlh_rcvd_as_req_l1            ( rdlh_rcvd_as_req_l1              ),
    .rdlh_rcvd_pm_enter_l1          ( rdlh_rcvd_pm_enter_l1            ),
    .rdlh_rcvd_pm_req_ack           ( rdlh_rcvd_pm_req_ack             ),
    .rdlh_rcvd_pm_enter_l23         ( rdlh_rcvd_pm_enter_l23           ),
    .rdlh_link_up                   ( rdlh_link_up                     ),
    .sdlh_block_tlp_ack             ( pm_block_tlp_ack                 ),
    .pm_freeze_fc_timer             ( pm_freeze_fc_timer               ),
    .pm_xdlh_dllp_req               ( pm_xdlh_dllp_req                 ),
    .xaim_tlp_pending               ( xaim_tlp_pending                 ),
    .xadm_tlp_pending               ( xadm_tlp_pending                 ),
    .xadm_no_fc_credit              ( xadm_no_fc_credit                ),
    .radm_pm_asnak                  ( radm_pm_asnak                    ),
    .radm_trgt0_pending             ( radm_trgt0_pending               ),
    .msg_gen_asnak_grt              ( msg_gen_asnak_grt                ),
    .lbc_active                     ( lbc_active                       ),
    .rstctl_core_flush_req          ( pm_rstctl_core_flush_req         ),
    .pm_block_all_tlp               ( pm_block_all_tlp                 ),
    .pm_xmt_asnak                   ( pm_xmt_asnak                     ),
    .pm_l1_aspm_entr                ( pm_l1_aspm_entr                  ),
    .xplh_pm_dllp_ack               ( xplh_pm_dllp_ack                 ),
    .xplh_pending                   ( xplh_pending                     ),
    .pl_speedmode                   ( pl_speedmode                     ),
    .smlh_link_up                   ( smlh_link_up                     ),
    .smlh_in_l0                     ( smlh_in_l0                       ),
    .smlh_in_l0s                    ( smlh_in_l0s                      ),
    .smlh_in_rl0s                   ( smlh_in_rl0s                     ),
    .smlh_in_l1                     ( smlh_in_l1                       ),
    .smlh_in_l23                    ( smlh_in_l23                      ),
    .smlh_link_in_training          ( smlh_link_in_training            ),
    .smlh_l123_eidle_timeout        ( smlh_l123_eidle_timeout          ),
    .latched_rcvd_eidle_set         ( latched_rcvd_eidle_set           ),
    .xmlh_cmd_if_lp_ack             ( xmlh_cmd_if_lp_ack               ),
    .pm_xmlh_lp_req                 ( pm_xmlh_lp_req                   ),
    .pl_protocol_cfg                ( pl_protocol_cfg                  ),
    .pl_state_sts                   ( b_splh_spif.s_pl_state_sts       ),
    .pl_stall_req                   ( b_splh_spif.s_pl_stall_req       ),
    .pl_rx_active_req               ( b_splh_spif.s_pl_rx_active_req   ),
    .pl_phyinrxl0s                  ( b_splh_spif.s_pl_phyinrxl0s      ),
    .pl_phyinretrain                ( b_splh_spif.s_pl_phyinretrain    ),
    .lp_state_req                   ( b_splh_spif.s_lp_state_req       ),
    .lp_pm_l1_exit                  ( lp_pcie_l1_exit                  ),
    .lp_pm_l1_req                   ( pm_prot_req_l1                   ),
    .lp_pm_l2_req                   ( pm_prot_req_l2                   ),
    .lp_pm_l0s_req                  ( pm_prot_req_l0s                  ),
    .lp_sdb_l1sub_aspm              ( lp_sdb_l1sub_aspm                ),
    .lp_sdb_l1sub_pcipm             ( lp_sdb_l1sub_pcipm               ),
    .pm_link_to_protocol_signals    ( pm_link_to_protocol_signals      ),
    .pm_protocol_to_link_signals    ( pm_protocol_to_link_signals      )
);

// -------------------------------------------------------------------------------------
// L0P Flow Control
// -------------------------------------------------------------------------------------
// L0p Configuration MUX to L0p Controller Connections
logic              cdm_xdlh_link_dis;          // L0p Hardware Autonomous Disable
logic              cdm_xdlh_link_pri;          // L0p Priority Request
logic              cdm_xdlh_link_req;          // L0p Request to resize the link
logic [2:0]        cdm_xdlh_link_width;        // L0p Target Link Width
logic              xdlh_cdm_link_ack;          // L0p Request Acknowledged (ACK)
logic              xdlh_cdm_link_nak;          // L0p Request Rejected (NAK)
// Internal signals
logic              int_l0p_rcvry;              // Recovery indication decoded from the Command Interface
logic              int_cfg_l0p_enable;         // L0p Enable gated when CXL is enabled

// SPIF MUX Signals
logic [5:0]        int_l0p_neg_link_width;     // Negotiated Link Width
logic              int_smlh_l0p_capable;       // L0p Capable bit
logic              int_smlh_xdlh_eios_rcvd;    // LogPHY received EIOSQ Order Set
logic [5:0]        int_smlh_link_mode;         // Link Mode negotiated at Configuration Phase
logic [5:0]        int_smlh_l0p_link_mode;     // Current Link Mode
logic              int_smlh_ltssm_l0p_ready;   // Flow Control signal indicates that LogPHY is ready to accept new request
logic [2:0]        int_xplh_flit_count;        // XPLH/XDLH Flit Count

// -------------------------------------------------------------------------------------
// SPIF Interface MUX (TOBEREMOVED)
// -------------------------------------------------------------------------------------
assign int_l0p_neg_link_width   = pl_protocol_cfg.spif_enable ? b_splh_spif.s_pl_linkmode     : cfg_l0p_neg_link_width;
assign int_smlh_l0p_capable     = pl_protocol_cfg.spif_enable ? int_cfg_l0p_enable            : smlh_l0p_capable;
assign int_smlh_xdlh_eios_rcvd  = pl_protocol_cfg.spif_enable ? b_splh_spif.s_pl_phyrcvdeiosq : smlh_xdlh_eios_rcvd;
assign int_smlh_l0p_link_mode   = pl_protocol_cfg.spif_enable ? b_splh_spif.s_pl_linkmode     : smlh_l0p_link_mode;
assign int_smlh_link_mode       = pl_protocol_cfg.spif_enable ? pl_linkmode_cfg               : smlh_link_mode;
assign int_smlh_ltssm_l0p_ready = pl_protocol_cfg.spif_enable ? pl_linkmode_rdy               : smlh_ltssm_l0p_ready;
assign int_xplh_flit_count      = pl_protocol_cfg.spif_enable ? pl_l0p_flit_count             : xplh_flit_count;
assign int_l0p_rcvry            = (sdlh_xdlh_cmd.tx_cmd == CMD_FLUSH_XTLH);
assign int_cfg_l0p_enable       = cfg_l0p_enable && smlh_link_up && !pl_protocol_cfg.cxl_mode_enable;

// -------------------------------------------------------------------------------------
// L0P Configuration Interface MUX
// -------------------------------------------------------------------------------------
sdlh_fm_l0p_mux
 u_fm_l0p_mux (
    .core_clk                   ( core_clk                  ),
    .core_rst_n                 ( core_rst_n                ),
    .cfg_l0p_enable             ( int_cfg_l0p_enable        ),
    .cfg_l0p_autowidth_dis      ( cfg_l0p_autowidth_dis     ),
    .cfg_l0p_priority           ( cfg_l0p_priority          ),
    .cfg_l0p_linkmode           ( cfg_l0p_linkmode          ),
    .cfg_l0p_linkmode_req       ( cfg_l0p_linkmode_req      ),
    .cfg_l0p_max_link_width     ( cfg_l0p_max_link_width    ),
    .cfg_l0p_neg_link_width     ( int_l0p_neg_link_width    ),
    .cfg_pcie_l0p_disable       ( cfg_pcie_l0p_disable      ),
    .cfg_pcie_l0p_request       ( cfg_pcie_l0p_request      ),
    .cfg_pcie_l0p_priority      ( cfg_pcie_l0p_priority     ),
    .cfg_pcie_l0p_linkmode      ( cfg_pcie_l0p_linkmode     ),
    .smlh_ltssm_l0p_ready       ( int_smlh_ltssm_l0p_ready  ),
    .xdlh_cdm_link_ack          ( xdlh_cdm_link_ack         ),
    .xdlh_cdm_link_nak          ( xdlh_cdm_link_nak         ),
    .cdm_xdlh_link_dis          ( cdm_xdlh_link_dis         ),
    .cdm_xdlh_link_req          ( cdm_xdlh_link_req         ),
    .cdm_xdlh_link_pri          ( cdm_xdlh_link_pri         ),
    .cdm_xdlh_link_width        ( cdm_xdlh_link_width       ),
    .app_dynamic_l0p_enable     ( app_dynamic_l0p_enable    ),
    .app_dynamic_l0p_rejected   ( app_dynamic_l0p_rejected  )
);

// -------------------------------------------------------------------------------------
// L0P Controller
// -------------------------------------------------------------------------------------
xdlh_fm_l0p
 u_fm_l0p (
    // Clock and Reset
    .core_clk                   ( core_clk                  ),
    .core_rst_n                 ( core_rst_n                ),
    // CDM Interface 
    .cdm_xdlh_l0p_enabled       ( int_cfg_l0p_enable        ),
    .cfg_upstream_port          ( cfg_upstream_port         ),
    .cfg_hw_autowidth_dis       ( cdm_xdlh_link_dis         ),
    .cfg_l0p_priority           ( cdm_xdlh_link_pri         ),
    .cdm_xdlh_link_width        ( cdm_xdlh_link_width       ),
    .cdm_xdlh_link_req          ( cdm_xdlh_link_req         ),
    .xdlh_cdm_link_ack          ( xdlh_cdm_link_ack         ), 
    .xdlh_l0p_rejected          ( xdlh_cdm_link_nak         ),
    // LTSSM Interface 
    .smlh_l0p_link_mode         ( int_smlh_l0p_link_mode    ),
    .smlh_in_rcvry              ( int_l0p_rcvry             ),
    .smlh_l0p_capable           ( int_smlh_l0p_capable      ),
    .smlh_xdlh_eios_rcvd        ( int_smlh_xdlh_eios_rcvd   ),
    .xdlh_smlh_link_req         ( xdlh_smlh_link_req        ),
    .xdlh_smlh_link_initiated   ( xdlh_smlh_link_initiated  ),
    .smlh_ltssm_l0p_ready       ( int_smlh_ltssm_l0p_ready  ),
    .xdlh_smlh_link_width       ( xdlh_smlh_link_width      ),
    .xdlh_smlh_enter_recovery   ( xdlh_smlh_enter_recovery  ),
    // XPLH Interface
    .xplh_flit_count            ( int_xplh_flit_count       ),
    .xplh_flit_count_en         ( xplh_flit_count_en        ), 
    .smlh_link_mode             ( int_smlh_link_mode        ),
    // XDLH DLLP Generator Interface
    .xplh_l0p_dllps_count       ( xplh_l0p_dllps_count      ),
    .xdlh_l0p_dllp              ( xdlh_l0p_dllp             ),
    .l0p_dllp_ack               ( xdlh_dllp_l0p_ack         ),
    // RDLH DLLP Receiver Interface
    .rdlh_l0p_dllp              ( rdlh_xdlh_l0p_dllp        ),
    .rdlh_xdlh_fm_dllp_valid    ( rdlh_xdlh_fm_dllp_valid   ),
    // Rate Information
    .current_data_rate          ( current_data_rate         )
);

endmodule
