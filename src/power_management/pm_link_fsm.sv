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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_link_fsm.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Link FSM and related logic
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module pm_link_fsm
  import DWC_cxl_pkg::CXL_EIDLE_1US_TIMEOUT_WIDTH;
  import spif_pkg::state_enc_e;
  import spif_pkg::protocol_cfg_t;
  import spif_pkg::ACTIVE;
  import spif_pkg::ACTIVE_L0S_PMNAK;
  import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::pm_protocol_to_link_struct;
  import DWC_pcie_pm_pkg::pm_link_to_protocol_struct;
#(
  parameter NL                        = `CX_NL,
  parameter PHY_TXEI_WD               = `CX_PHY_TXEI_WD
) 
                    (
  input                                core_clk,                    // Core clock
  input                                core_rst_n,                  // Core reset
  input                                upstream_port,               // CFG: Indicates upstream port in DM/SW
  input                                cfg_pl_l1_nowait_p1,         // CDM: Port logic bit to control L1 entry mode
  input                                cfg_pm_clk_pm_en,            // PM_CFG: Clock PM feature enabled by software
  input                                smlh_link_up,                // LTSSM is in link up
  input                                smlh_in_l0,                  // LTSSM in L0
  input                                smlh_in_l0s,                 // LTSSM in L0s
  input                                smlh_in_rl0s,                // LTSSM in RX L0s
  input                                smlh_in_l0_l0s,              // LTSSM in L0 or L0s state
  input                                smlh_in_l1,                  // LTSSM in L1
  input                                smlh_in_l1_p1,               // LTSSM in L1 state with current_powerdown set to P1
  input                                smlh_in_l23,                 // LTSSM in L23
  input                                smlh_link_in_training,       // LTSSM in link training
  input                                smlh_cal_req_no_clk_gate,    // LTSSM asks not to gate core_clk
  input                                smlh_l123_eidle_timeout,     // LTSSM 2ms Timer Timed out while waiting for EIDLE
  input                                latched_rcvd_eidle_set,      // LTSSM latched received eidle ordered set indication from RMLH
  input [NL*PHY_TXEI_WD-1:0]           ltssm_txelecidle,            // PHY: Enable Transmitter Electical Idle
  input                                pm_hold_exit_l1,             // PM Active Controller indication that the controller is not ready for L1 exit
  input                                pm_link_exit_l1,             // PM Active Controller requests L1 exit
  input                                pm_link_exit_l23,            // PM Active Controller requests L23 exit
  input   protocol_cfg_t               pl_protocol_cfg,             // SPIF: Protocol Configuration for PLH Layer
  input   state_enc_e                  pl_state_sts,                // SPIF: pl_state_sts on physical layer interface
  input                                splh_pm_req_l0s,             // SPIF: Packet Layer requests PM Link FSM to enter L0S
  input                                splh_pm_req_l1,              // SPIF: Packet Layer requests PM Link FSM to enter L1
  input                                splh_pm_req_l2,              // SPIF: Packet Layer requests PM Link FSM to enter L2
  output logic                         pm_smlh_entry_to_l1,         // PM commands LTSSM enter L1
  output logic                         pm_smlh_l1_exit,             // PM commands LTSSM exit L1
  output logic                         pm_smlh_l23_exit,            // PM commands LTSSM exit L23
  output logic                         pm_smlh_entry_to_l2,         // PM commands LTSSM enter L2
  output logic                         pm_smlh_prepare4_l123,       // PM commands LTSSM to get preparing for entering L123
  output logic                         pm_smlh_entry_to_l0s,        // PM commands LTSSM enter L0s
  output logic                         pm_smlh_l0s_exit,            // PM commands LTSSM exit L0s
  output logic                         pm_smlh_dllp_hs,             // PM commands LTSSM to hold in L0 while pm dllp handshake
  output logic                         pm_linkst_in_l0s,            // Shadowed in PM Controller and connects to CDM and exposed as top-level pin
  output usp_link_fsm_state_e          pm_usp_link_state,           // PM USP Link FSM state interfaces with PM Active Controller and RAS-DES
  output dsp_link_fsm_state_e          pm_dsp_link_state,           // PM DSP Link FSM state interfaces with PM Active Controller and RAS-DES
  input   pm_protocol_to_link_struct   pm_protocol_to_link_signals, // TOBEREMOVED: PM Protocol FSM to Link FSM connections
  output  pm_link_to_protocol_struct   pm_link_to_protocol_signals  // TOBEREMOVED: PM Link FSM to Protocol FSM connections
);

parameter TP                        = `TP;                  // Clock to Q delay (simulator insurance)

//------------------------------------------------------------------------------
// Internal signals declaration
//------------------------------------------------------------------------------
// DSP Link FSM state
logic                  dsp_link_rst;                // DSP Link FSM is in RESET state
logic                  dsp_link_recovery;           // DSP Link FSM is in RECOVERY state
logic                  dsp_link_l0;                 // DSP Link FSM is in L0 state
logic                  dsp_link_ack_wait4idle;      // DSP Link FSM is in ACK_WAIT4IDLE state
logic                  dsp_link_abort;              // DSP Link FSM is in ABORT state
logic                  dsp_link_enter_l23;          // DSP Link FSM is in ENTER_L23 state
logic                  dsp_link_l23rdy;             // DSP Link FSM is in L23RDY state
logic                  dsp_link_l23rdy_wait4alive;  // DSP Link FSM is in L23RDY_WAIT4ALIVE state
logic                  dsp_link_entr_l1;            // DSP Link FSM is in ENTER_L1 state
logic                  dsp_link_l1;                 // DSP Link FSM is in L1 state
logic                  dsp_link_l1_exit;            // DSP Link FSM is in L1_EXIT state
logic                  dsp_link_l1_finish;          // DSP Link FSM is on exit from L1
logic                  dsp_link_l23_finish;         // DSP Link FSM is on exit from L23

// USP Link FSM state
logic                  usp_link_rst;                // USP Link FSM is in RESET state
logic                  usp_link_recovery;           // USP Link FSM is in RECOVERY state
logic                  usp_link_l0;                 // USP Link FSM is in L0 state
logic                  usp_link_prep_4l1;           // USP Link FSM is in PREPARE_4L1 state
logic                  usp_link_l1_link_entr_l1;    // USP Link FSM is in ENTER_L1 state
logic                  usp_link_l1;                 // USP Link FSM is in L1 state
logic                  usp_link_l1_exit;            // USP Link FSM is in L1_EXIT state
logic                  usp_link_prep_4l23;          // USP Link FSM is in PREP_4L23 state
logic                  usp_link_l23_entr_l23;       // USP Link FSM is in ENTER_L23 state
logic                  usp_link_l23rdy;             // USP Link FSM is in L23RDY state
logic                  usp_link_l23rdy_wait4alive;  // USP Link FSM is in L23RDY_WAIT4ALIVE state
logic                  usp_link_wait_dstate_update; // USP Link FSM is in WAIT_DSTATE_UPDATE state
logic                  usp_link_abort;              // USP Link FSM is in L1_ABORT state
logic                  usp_link_l1_finish;          // USP Link FSM is on exit from L1
logic                  usp_link_l23_finish;         // USP Link FSM is on exit from L23

// TOBEREMOVED: Local declarations for Link to Protocol FSM interface signals
logic                  pm_link_l23_flag_clear;      // Link FSM signal to clear L23 entry flag
logic                  pm_link_l23_restart_clear;   // Link FSM signal to clear L23 restart flag
logic                  pm_link_usp_l1_in_progress;  // Link FSM L1 is in progress
logic                  pm_link_dsp_l1_in_progress;  // Link FSM L1 is in progress
logic                  pm_link_block_all_tlp;       // Link FSM signal to block all TLPs
logic                  pm_link_freeze_fc_timer;     // Link FSM signal to freeze FC time
logic                  pm_link_hold_dllp_timer;     // Link FSM signal to hold DLLP timer
logic                  pm_linkst_in_l1;             // Link FSM is in L1
logic                  pm_linkst_in_l2;             // Link FSM is in L2
logic                  link_l1_finish;              // Link FSM is on exit from L1
logic                  link_l23_finish;             // Link FSM is on exit from L1
logic                  prot_to_active;              // Link FSM is in L0

// TOBEREMOVED: Local declarations for Protocol to Link FSM interface signals
logic                  software_entr_l1;            // Ready to start L1 negotiation
logic                  software_entr_l23;           // PM Turnoff handshake done, ready to start L23 negotiation
logic                  lbc_active;                  // The LBC may require a CPL to be sent, stop L1 timer
logic                  pm_timeout;                  // Watchdog timer for USP_LINK_WAIT_DSTATE_UPDATE state of the USP PROT FSM
logic                  pm_link_entr_l1;             // PM Protocol FSM (Link Layer) requests ASPM L1 entry
logic                  pm_link_entr_l23;            // PM Protocol FSM requests L1 entry
logic                  prot_enter_l1;               // PM Protocol FSM requests L1 entry
logic                  prot_enter_l23;              // PM Protocol FSM requests L23 entry

// Internal signals
logic                  int_smlh_in_l1;              // Internal indication of LTSSM in L1
logic                  int_link_up_not_rcvry;
logic                  int_idle_next;
logic                  link_smlh_in_l0;             // LTSSM in L0 or SPIF State Status is ACTIVE in SPIF mode (link_pm_to_active)
logic                  prot_to_link_abort_l1;       // Link Layer (Protocol FSM) requests L1 abort (CXL-only)
logic                  prot_to_link_enter_l1;       // Link Layer (Protocol FSM) requests L1 entry
logic                  prot_to_link_enter_l23;      // Link Layer (Protocol FSM) requests L23 entry
logic                  link_pm_enter_l1;            // Drives prot_to_link_enter_l1 in SPIF mdoe
logic                  link_pm_enter_l23;           // Drives prot_to_link_enter_l23 in SPIF mdoe
logic                  link_pm_to_active;           // Drives link_smlh_in_l0 in SPIF mdoe
logic                  link_pm_l1_abort;            // Drives prot_to_link_abort_l1 in SPIF mode

// ----------------------------------------------------------------------------
// Link FSM 1us timer for CXL USP
// ----------------------------------------------------------------------------
logic        smlh_eidle_enable_r;    // Enable Electrical Idle request to LTSSM
logic        smlh_eidle_enable_nxt;  // Enable Electrical Idle request to LTSSM
logic        smlh_eidle_timer_ena_s; // Enable Electrical Idle 1us timer
logic        smlh_eidle_timer_rst_s; // Reset Electrical Idle 1us timer
logic        smlh_eidle_timeout_s;   // Electrical Idle 1us timer timeout

// ----------------------------------------------------------------------------
// Convert between internal signals and Interface with PM Protocol FSM
// ----------------------------------------------------------------------------
assign pm_link_to_protocol_signals.int_link_up_not_rcvry         = int_link_up_not_rcvry                      ;
assign pm_link_to_protocol_signals.int_idle_next                 = int_idle_next                              ;
assign pm_link_to_protocol_signals.link_l1_finish                = link_l1_finish                             ;
assign pm_link_to_protocol_signals.link_l23_finish               = link_l23_finish                            ;
assign pm_link_to_protocol_signals.prot_to_active                = prot_to_active                             ;
assign pm_link_to_protocol_signals.usp_link_l1                   = usp_link_l1                                ;
assign pm_link_to_protocol_signals.usp_link_l0                   = usp_link_l0                                ;
assign pm_link_to_protocol_signals.usp_link_wait_dstate_update   = usp_link_wait_dstate_update                ;
assign pm_link_to_protocol_signals.pm_linkst_in_l1               = pm_linkst_in_l1                            ;
assign pm_link_to_protocol_signals.pm_linkst_in_l2               = pm_linkst_in_l2                            ;
assign pm_link_to_protocol_signals.pm_link_l23_flag_clear        = pm_link_l23_flag_clear                     ;
assign pm_link_to_protocol_signals.pm_link_l23_restart_clear     = pm_link_l23_restart_clear                  ;
assign pm_link_to_protocol_signals.pm_link_usp_l1_in_progress    = pm_link_usp_l1_in_progress                 ;
assign pm_link_to_protocol_signals.pm_link_dsp_l1_in_progress    = pm_link_dsp_l1_in_progress                 ;
assign pm_link_to_protocol_signals.pm_link_block_all_tlp         = pm_link_block_all_tlp                      ;
assign pm_link_to_protocol_signals.pm_link_freeze_fc_timer       = pm_link_freeze_fc_timer                    ;
assign pm_link_to_protocol_signals.pm_link_hold_dllp_timer       = pm_link_hold_dllp_timer                    ;

assign software_entr_l1       = pm_protocol_to_link_signals.software_entr_l1       ;
assign software_entr_l23      = pm_protocol_to_link_signals.software_entr_l23      ;
assign lbc_active             = pm_protocol_to_link_signals.lbc_active             ;
assign pm_timeout             = pm_protocol_to_link_signals.pm_timeout             ;
assign pm_link_entr_l1        = pm_protocol_to_link_signals.latch_as_entr_l1       ;
assign prot_enter_l1          = pm_protocol_to_link_signals.prot_enter_l1          ;
assign prot_enter_l23         = pm_protocol_to_link_signals.prot_enter_l23         ;
assign pm_link_entr_l23       = pl_protocol_cfg.spif_enable ? splh_pm_req_l2                                                             : pm_protocol_to_link_signals.latched_entr_l23     ;
assign pm_smlh_l0s_exit       = pl_protocol_cfg.spif_enable ? (!splh_pm_req_l0s && pm_linkst_in_l0s)                                     : pm_protocol_to_link_signals.pm_smlh_l0s_exit     ;
assign pm_smlh_entry_to_l0s   = pl_protocol_cfg.spif_enable ? splh_pm_req_l0s                                                            : pm_protocol_to_link_signals.pm_smlh_entry_to_l0s ;
assign pm_linkst_in_l0s       = pl_protocol_cfg.spif_enable ? (pl_protocol_cfg.pcie_mode_enable && (pl_state_sts == ACTIVE_L0S_PMNAK))   : pm_protocol_to_link_signals.pm_linkst_in_l0s     ;
assign pm_smlh_dllp_hs        = pl_protocol_cfg.spif_enable ? (splh_pm_req_l1 || splh_pm_req_l2)                                         : pm_protocol_to_link_signals.pm_smlh_dllp_hs      ;

//------------------------------------------------------------------------------
// Link to Protocol FSM signals
//------------------------------------------------------------------------------
assign pm_link_l23_flag_clear     = usp_link_prep_4l23 || (usp_link_rst || usp_link_recovery);
assign pm_link_l23_restart_clear  = usp_link_l23rdy || !smlh_link_up;
assign pm_link_usp_l1_in_progress = usp_link_prep_4l1 || usp_link_l1_link_entr_l1 || usp_link_l1;
assign pm_link_dsp_l1_in_progress = dsp_link_ack_wait4idle || dsp_link_entr_l1 || dsp_link_l1;

assign pm_link_block_all_tlp      = (    usp_link_l1_link_entr_l1
                                      || usp_link_l23_entr_l23
                                      || usp_link_prep_4l1
                                      || usp_link_prep_4l23
                                      || usp_link_l1
                                      || usp_link_l1_exit
                                      || usp_link_l23rdy
                                      || usp_link_l23rdy_wait4alive
                                      || dsp_link_ack_wait4idle
                                      || dsp_link_entr_l1
                                      || dsp_link_l1
                                      || dsp_link_l1_exit
                                    );


assign pm_link_freeze_fc_timer    = (    usp_link_l1
                                      || usp_link_l1_link_entr_l1
                                      || dsp_link_l1
                                      || dsp_link_entr_l1
                                      || dsp_link_ack_wait4idle
                                      || usp_link_l23_entr_l23
                                      || usp_link_l23rdy
                                      || dsp_link_enter_l23
                                      || dsp_link_l23rdy
                                      || !(smlh_in_l0 || smlh_in_l0s || smlh_in_rl0s)
                                    ) && !smlh_in_l0_l0s;

assign pm_link_hold_dllp_timer    = upstream_port ? (usp_link_rst || usp_link_recovery) : smlh_link_in_training;

//------------------------------------------------------------------------------
// Physical layer signals
//------------------------------------------------------------------------------
// Create an internal signal to indicate PHY link up and LTSSM not in recovery
assign int_link_up_not_rcvry = !smlh_link_in_training && smlh_link_up;

// FSM returns to RST/RECOVERY state if Recovery or link goes down
assign int_idle_next = smlh_link_in_training || !smlh_link_up;

//------------------------------------------------------------------------------
// Link FSM stimulus
//------------------------------------------------------------------------------
// L1 and L2 entry conditions for Link FSM
// For CXL Upstream Port wait for 1 microsecond before asserting a new PM request to LTSSM
assign link_pm_enter_l1    = splh_pm_req_l1 && ((pl_protocol_cfg.cxl_mode_enable && upstream_port) ? smlh_eidle_enable_r : 1'b1);
assign link_pm_enter_l23   = splh_pm_req_l2 && ((pl_protocol_cfg.cxl_mode_enable && upstream_port) ? smlh_eidle_enable_r : 1'b1);

// Physical Layer is in ACTIVE state
assign link_pm_to_active   = (pl_state_sts == ACTIVE);

// Dowstream Port to abort Phase 3 when requested state is changed from IDLE_L1_1 due to a request from
// Upstream Port triggered before transmitting EIOS. Dowstream Port simply exits both Link and Protocol FSM on this event.
// Upstream Port aborts Phase 3 when L1 exit condition is detected while LTSSM started to transmit EIOS. In this case the
// abort scenario is resolved by triggering the recovery in LTSSM if it is still transmitting EIOS. Otherwise this event is
// treated as a regular L1 exit scenarion. This behaviour for Upstream Port is optional and implementation specific.
assign link_pm_l1_abort    = upstream_port ? ((usp_link_prep_4l1 || usp_link_l1_link_entr_l1) && !splh_pm_req_l1) : (dsp_link_ack_wait4idle && !splh_pm_req_l1);

// in PCIe mode, do not abort L1 entry in link FSM.
assign prot_to_link_abort_l1 = pl_protocol_cfg.cxl_mode_enable ? link_pm_l1_abort : 1'b0;

// Conditions for PM Link FSM to enter L1 or L23
assign prot_to_link_enter_l1   = pl_protocol_cfg.spif_enable ? link_pm_enter_l1   : prot_enter_l1;
assign prot_to_link_enter_l23  = pl_protocol_cfg.spif_enable ? link_pm_enter_l23  : prot_enter_l23;
assign link_smlh_in_l0         = pl_protocol_cfg.spif_enable ? link_pm_to_active  : smlh_in_l0;

//------------------------------------------------------------------------------
// LINK FSM and related signals
//------------------------------------------------------------------------------

// Multiplexing between USP and DSP Link FSMs
assign link_l1_finish  = upstream_port ? usp_link_l1_finish  : dsp_link_l1_finish  ;
assign link_l23_finish = upstream_port ? usp_link_l23_finish : dsp_link_l23_finish ;
assign prot_to_active  = upstream_port ? usp_link_l0         : dsp_link_l0         ;

// Downstream Port Protocol Negotiation FSM
pm_active_dsp_link_fsm

    // Parameters
    #(
     ) u_pm_active_dsp_link_fsm (
       // Inputs
       .core_clk                   (core_clk                    ),
       .core_rst_n                 (core_rst_n                  ),
       .upstream_port              (upstream_port               ),
       .smlh_link_up               (smlh_link_up                ),
       .smlh_in_l0                 (link_smlh_in_l0             ),
       .smlh_in_l1                 (int_smlh_in_l1              ),
       .smlh_in_l23                (smlh_in_l23                 ),
       .smlh_l123_eidle_timeout    (smlh_l123_eidle_timeout     ),
       .prot_to_link_abort_l1      (prot_to_link_abort_l1       ),
       .prot_to_link_enter_l1      (prot_to_link_enter_l1       ),
       .prot_to_link_enter_l23     (prot_to_link_enter_l23      ),
       .pm_hold_exit_l1            (pm_hold_exit_l1             ),
       .pm_link_exit_l1            (pm_link_exit_l1             ),
       .pm_link_entr_l23           (pm_link_entr_l23            ),
       .pm_link_exit_l23           (pm_link_exit_l23            ),
       .int_link_up_not_rcvry      (int_link_up_not_rcvry       ),
       .int_idle_next              (int_idle_next               ),
       .latched_rcvd_eidle_set     (latched_rcvd_eidle_set      ),
       // Ouputs
       .dsp_link_rst               (dsp_link_rst                ),
       .dsp_link_recovery          (dsp_link_recovery           ),
       .dsp_link_l0                (dsp_link_l0                 ),
       .dsp_link_ack_wait4idle     (dsp_link_ack_wait4idle      ),
       .dsp_link_abort             (dsp_link_abort              ),
       .dsp_link_enter_l23         (dsp_link_enter_l23          ),
       .dsp_link_l23rdy            (dsp_link_l23rdy             ),
       .dsp_link_l23rdy_wait4alive (dsp_link_l23rdy_wait4alive  ), // TOBEREMOVED
       .dsp_link_entr_l1           (dsp_link_entr_l1            ),
       .dsp_link_l1                (dsp_link_l1                 ),
       .dsp_link_l1_exit           (dsp_link_l1_exit            ),
       .dsp_link_l1_finish         (dsp_link_l1_finish          ),
       .dsp_link_l23_finish        (dsp_link_l23_finish         ),
       .pm_dsp_link_state          (pm_dsp_link_state           )
);

// Upstream Port Link Control Negotiation FSM
pm_active_usp_link_fsm

    // Parameters
    #(
    ) u_pm_active_usp_link_fsm (
      // inputs
      .core_clk                    (core_clk                    ),
      .core_rst_n                  (core_rst_n                  ),
      .upstream_port               (upstream_port               ),
      .spif_enable                 (pl_protocol_cfg.spif_enable ),
      .smlh_link_up                (smlh_link_up                ),
      .smlh_in_l0                  (link_smlh_in_l0             ),
      .smlh_in_l1                  (int_smlh_in_l1              ),
      .smlh_in_l23                 (smlh_in_l23                 ),
      .prot_to_link_abort_l1       (prot_to_link_abort_l1       ),
      .prot_to_link_enter_l1       (prot_to_link_enter_l1       ),
      .prot_to_link_enter_l23      (prot_to_link_enter_l23      ),
      .pm_link_entr_l1             (pm_link_entr_l1             ), // TOBEREMOVED
      .pm_hold_exit_l1             (pm_hold_exit_l1             ),
      .pm_link_exit_l1             (pm_link_exit_l1             ),
      .pm_link_exit_l23            (pm_link_exit_l23            ),
      .software_entr_l1            (software_entr_l1            ), // TOBEREMOVED
      .software_entr_l23           (software_entr_l23           ), // TOBEREMOVED
      .lbc_active                  (lbc_active                  ), // TOBEREMOVED
      .pm_timeout                  (pm_timeout                  ), // TOBEREMOVED
      .int_link_up_not_rcvry       (int_link_up_not_rcvry       ),
      .int_idle_next               (int_idle_next               ),
    // outputs
      .usp_link_rst                (usp_link_rst                ),
      .usp_link_recovery           (usp_link_recovery           ),
      .usp_link_l0                 (usp_link_l0                 ),
      .usp_link_prep_4l1           (usp_link_prep_4l1           ),
      .usp_link_l1_link_entr_l1    (usp_link_l1_link_entr_l1    ),
      .usp_link_l1                 (usp_link_l1                 ),
      .usp_link_l1_exit            (usp_link_l1_exit            ),
      .usp_link_prep_4l23          (usp_link_prep_4l23          ),
      .usp_link_l23_entr_l23       (usp_link_l23_entr_l23       ),
      .usp_link_l23rdy             (usp_link_l23rdy             ),
      .usp_link_l23rdy_wait4alive  (usp_link_l23rdy_wait4alive  ), // TOBEREMOVED
      .usp_link_wait_dstate_update (usp_link_wait_dstate_update ), // TOBEREMOVED
      .usp_link_abort              (usp_link_abort              ),
      .usp_link_l1_finish          (usp_link_l1_finish          ),
      .usp_link_l23_finish         (usp_link_l23_finish         ),
      .pm_usp_link_state           (pm_usp_link_state           )
);

//------------------------------------------------------------------------------
// Outputs sampled.
//------------------------------------------------------------------------------
logic  next_pm_smlh_l1;
logic  next_pm_smlh_l1_entry;
logic  next_pm_smlh_l1_exit;
logic  next_pm_smlh_l2_entry;
logic  next_pm_smlh_l2_exit;
logic  next_pm_smlh_l2;
logic  next_pm_smlh_prep_l123;

// When link fsm acknowledged the xdlh to enter L1, it needs to signal LTSSM that it is ready to enter L1 which prevent LTSSM goes into L0s when eidle order set received.
assign next_pm_smlh_l1_entry  = (usp_link_l1_link_entr_l1 || dsp_link_entr_l1);
assign next_pm_smlh_l1_exit   = (usp_link_l1_exit || dsp_link_l1_exit || usp_link_abort || dsp_link_abort);
assign next_pm_smlh_l1        = (usp_link_l1 || dsp_link_l1);

// When DSP state machine acknowledged the xdlh to enter L2, it needs to signal LTSSM that it is ready to enter L2 which prevent LTSSM goes into L0s when eidle order set received.
assign next_pm_smlh_l2_entry  = (usp_link_l23_entr_l23 || dsp_link_enter_l23);
assign next_pm_smlh_l2        = (usp_link_l23rdy || dsp_link_l23rdy || usp_link_l23rdy_wait4alive || dsp_link_l23rdy_wait4alive);
assign next_pm_smlh_l2_exit   = (usp_link_l23rdy || dsp_link_l23rdy) && pm_link_exit_l23;

// For Downstream Port do not exit LTSSM from L0 state to L123_SEND_EIDLE until EIOS is received.
// While waiting for EIOS, the transmit path must remain active to be able to respond to ALMP handshake.
// Doesn't matter for PCIe mode as there is no ALMP exchange involved in the state transitions.
// Constrained with spif_enable but I would suggest to keep the same logic for PCIe as well. (AI: Henry to review)
//
// When DSP state machine acknowledged the xdlh to enter L1, it needs to signal LTSSM that it is ready to enter L1 and trigger LTSSM to enter EIDLE.
// USP needs to trigger LTSSM to enter EIDLE, which is used to notify the DSP to stop sending PM_Req_Ack.
assign next_pm_smlh_prep_l123 = ( pl_protocol_cfg.spif_enable ? (dsp_link_entr_l1 || dsp_link_enter_l23) : dsp_link_ack_wait4idle) || usp_link_prep_4l1 || usp_link_prep_4l23 || usp_link_l1_link_entr_l1;

// output driven process
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n) begin
    pm_smlh_l1_exit         <= #TP 0;
    pm_smlh_l23_exit        <= #TP 0;
    pm_smlh_entry_to_l1     <= #TP 0;
    pm_smlh_entry_to_l2     <= #TP 0;
    pm_smlh_prepare4_l123   <= #TP 0;
    pm_linkst_in_l1         <= #TP 0;
    pm_linkst_in_l2         <= #TP 0;
end
else begin
    // Beneath are the signal commands the LTSSM state machine to go into the proper low power state
    pm_smlh_l1_exit         <= #TP next_pm_smlh_l1_exit;
    pm_smlh_l23_exit        <= #TP next_pm_smlh_l2_exit;
    pm_smlh_entry_to_l1     <= #TP next_pm_smlh_l1_entry;
    pm_smlh_entry_to_l2     <= #TP next_pm_smlh_l2_entry;
    pm_smlh_prepare4_l123   <= #TP next_pm_smlh_prep_l123;
    pm_linkst_in_l1         <= #TP next_pm_smlh_l1;
    pm_linkst_in_l2         <= #TP next_pm_smlh_l2;
end

//------------------------------------------------------------------------------
// Timer for L0, before retrying electrical Idle again after enteringlink training.
//------------------------------------------------------------------------------
// If the link transitions to recovery during or after entry into electrical idle, the
// Downstream Component must wait for at least 1us after reaching L0 before re-initiating entry into
// electrical idle. This is to allow enough time for an Active State Request ALMP transfer to occur in case
// either side wants to initiate a PM exit (and to give time for the remote ARB/MUX to stop requesting PM
// entry to LogPHY).
assign smlh_eidle_timer_rst_s = upstream_port && !(usp_link_rst || usp_link_l0) && smlh_link_in_training;
assign smlh_eidle_timer_ena_s = !smlh_eidle_enable_r && usp_link_l0;

always_comb begin
    // If recovery is triggered during or after entry to electrical idle then
    // disable EIDLE request to LTSSM until EIDLE timer timeouts
    if (smlh_eidle_timer_rst_s)
        smlh_eidle_enable_nxt = 1'b0;
    // On timeout of EIDLE timer enable EIDLE request to LTSSM
    else if (smlh_eidle_timeout_s)
        smlh_eidle_enable_nxt = 1'b1;
    else
        smlh_eidle_enable_nxt = smlh_eidle_enable_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        smlh_eidle_enable_r <= #TP 1'b1;
    end
    else begin
        smlh_eidle_enable_r <= #TP smlh_eidle_enable_nxt;
    end
end

DWC_cxl_base_timer
 #(
    .TIMER_WIDTH  (CXL_EIDLE_1US_TIMEOUT_WIDTH)
) u_smlh_eidle_timeout (
    // Inputs
    .clk          (core_clk),
    .rst_n        (core_rst_n),
    .clear_timer  (smlh_eidle_timer_rst_s),
    .hold_timer   (1'b0),
    .enable       (smlh_eidle_timer_ena_s),
    .timer_target ('1),
    .incr         ({{(CXL_EIDLE_1US_TIMEOUT_WIDTH-1){1'b0}},1'b1}),
    // Outputs
    .timeout_r    (),
    .timeout      (smlh_eidle_timeout_s),
    .timer_r      ()
);

//------------------------------------------------------------------------------
// L1 Entry for the Link FSMs
//------------------------------------------------------------------------------
logic  int_freq_step_smlh_in_l1;
assign int_freq_step_smlh_in_l1 = cfg_pl_l1_nowait_p1 ? smlh_in_l1 : smlh_in_l1_p1;


// If Pipe 4.3 support is enabled insure that txelecidle is asserted before
// the gasket drives powerdown to P1/P1.CPM
assign int_smlh_in_l1 = int_freq_step_smlh_in_l1 && (&ltssm_txelecidle);




endmodule // pm_link_fsm
