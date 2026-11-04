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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_sd_reg.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains RAS D.E.S Silicon debug registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
 
 module cdm_rasdes_sd_reg
import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter TP            = `TP,                                 // Clock to Q delay (simulator insurance)
    parameter NW            = `CX_NW,                              // Number of 32-bit dwords handled by the datapath each clock.
    parameter RX_TLP        = `CX_RX_TLP,                          // Number of TLPs that can be received in a single cycle
    parameter FX_TLP        = `CX_FX_TLP,                          // Number of TLPs that can be processed in a single cycle after the formation block
    parameter NL            = `CX_NL,                              // Number of Lanes Supported
    parameter NVC           = `CX_NVC,                             // Number of virtual channels
    parameter NF            = `CX_NFUNC,                           // Number of functions
    parameter TX_PSET_WD    = 4,                                   // Width of Transmitter Equalization Presets
    parameter RX_PSET_WD    = 3,                                   // Width of Receiver Equalization Presets
    parameter TX_COEF_WD    = 18,                                  // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
    parameter TX_FS_WD      = 6,                                   // Width of Full Swing or Low Frequency
    parameter FOMFEEDBACK_WD = 8,                                   // Width of Figure of Merit
    parameter  HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8,
    parameter  DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12
)
(
// -------------- Inputs ---------------
    input                              aux_clk,                             // Clock
    input                              sticky_rst_n,                        // Reset sticky registers only
 // --- Register access signals
    input  [31:0]                      cdm_reg_wdata,                       // Write Data 
    input  [3:0]                       cdm_reg_write_pulse,                 // Write Byte Enables
    input  [63:0]                      cdm_reg_id,                          // Register access ID
 // --- Silcon debug signals
    // Group0
    input  [NL-1:0]                    mac_phy_txelec_txburst,              // Level : PIPE: TxElecIdle/TxBurst for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    mac_phy_rxpolarity,                  // Level : PIPE: RxPolarity for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    phy_mac_rxelec_rxh8exit,             // Level : PIPE: RxElecIdle/RxHibern8ExitType1 for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    phy_mac_rxvalid_rxburst,             // Level : PIPE: RxValid/RxBurst
    input  [NL-1:0]                    latched_rxdetected,                  // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
    input  [NL-1:0][7:0]               rmlh_deskew_fifo_ptr,                // Pulse : Rx deskew pointer address
    // Group1
    input usp_link_fsm_state_e         pm_usp_link_state,                // Level : PM Internal usp link fsm state for Ras D.E.S Silicon Debug
    input usp_prot_fsm_state_e         pm_usp_prot_state,                // Level : PM Internal usp prot fsm state for Ras D.E.S Silicon Debug
    input dsp_link_fsm_state_e         pm_dsp_link_state,                // Level : PM Internal dsp link fsm state for Ras D.E.S Silicon Debug
    input dsp_prot_fsm_state_e         pm_dsp_prot_state,                // Level : PM Internal dsp prot fsm state for Ras D.E.S Silicon Debug
    input pm_active_l0s_fsm_e          pm_l0s_state,                     // Level : PM Internal l0s fsm state for Ras D.E.S Silicon Debug
    input  [6:0]                       rmlh_framing_err_ptr,                // Pulse : Rx framing error pointer in gen3 rate
    input                              smlh_lane_reversed,                  // Level : Lane Reversal Operation for Ras D.E.S Silicon Debug
    input                              pm_pme_resend_flag,                  // Level : PME Re-Send flag for Ras D.E.S Silicon Debug 
    input  [15:0]                      smlh_ltssm_variable,                 // Level : Ltssm specific parameters for Ras D.E.S event counter
    input  [1:0]                       ltssm_powerdown,                     // Level: PIPE: Power Down for Ras D.E.S Silicon Debug
    input  [7:0]                       latched_ts_nfts,                     // Level: Latched NFTS for Ras D.E.S Silicon Debug
    // Group2
    input  [1:0]                       rdlh_dlcntrl_state,                  // Level : DLCM state machine signal for Ras D.E.S Silicon Debug
    input                              rdlh_vc0_initfc1_status,             // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
    input                              rdlh_vc0_initfc2_status,             // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug 
    input  [11:0]                      rdlh_xplh_curnt_rx_ack_seqnum,       // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
    input  [11:0]                      xdlh_xplh_curnt_seqnum,              // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      rtlh_fc_rcvd_ph,                     // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      rtlh_fc_rcvd_pd,                     // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      rtlh_fc_rcvd_nph,                    // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      rtlh_fc_rcvd_npd,                    // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      rtlh_fc_rcvd_cplh,                   // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      rtlh_fc_rcvd_cpld,                   // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      rtlh_fc_allctd_ph,                   // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      rtlh_fc_allctd_pd,                   // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      rtlh_fc_allctd_nph,                  // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      rtlh_fc_allctd_npd,                  // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      rtlh_fc_allctd_cplh,                 // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug;
    input  [NVC-1:0][DCRD_WD-1:0]      rtlh_fc_allctd_cpld,                 // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug;
    input  [NVC-1:0][HCRD_WD-1:0]      xadm_fc_cnsmd_ph,                    // Level : Current FC Credit Consumed(Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      xadm_fc_cnsmd_pd,                    // Level : Current FC Credit Consumed(Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      xadm_fc_cnsmd_nph,                   // Level : Current FC Credit Consumed(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      xadm_fc_cnsmd_npd,                   // Level : Current FC Credit Consumed(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      xadm_fc_cnsmd_cplh,                  // Level : Current FC Credit Consumed(Completion Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      xadm_fc_cnsmd_cpld,                  // Level : Current FC Credit Consumed(Completion Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      xadm_fc_limit_ph,                    // Level : Current FC Credit limit(Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      xadm_fc_limit_pd,                    // Level : Current FC Credit limit(Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      xadm_fc_limit_nph,                   // Level : Current FC Credit limit(Non-Posted Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      xadm_fc_limit_npd,                   // Level : Current FC Credit limit(Non-Posted Data) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][HCRD_WD-1:0]      xadm_fc_limit_cplh,                  // Level : Current FC Credit limit(Completion Header) for Ras D.E.S Silicon Debug
    input  [NVC-1:0][DCRD_WD-1:0]      xadm_fc_limit_cpld,                  // Level : Current FC Credit limit(Completion Data) for Ras D.E.S Silicon Debug
    input                              app_malformed_tlp,                   // Pulse : malformed TLP status from application
    input  [(FX_TLP*8)-1:0]            radm_mlf_tlp_err_ptr,                // Pulse : malformed TLP 1st error pointer (enabled by radm_mlf_tlp_err)
    input                              init_eq_pending,                     // Level : Equalization sequence for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_fs,                  // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_lf,                  // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx,            // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]     phy_cdm_ras_des_fomfeedback,         // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                  eqpa_violate_rule_123,               // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                  eq_convergence_sts,                  // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_rtx,            // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*RX_PSET_WD-1:0]         mac_cdm_ras_des_pset_lrx,            // Level : Current Local Receiver Preset for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    mac_cdm_ras_des_reject_rtx,          // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input                              init_eq_pending_g4,                  // Level : Equalization sequence  for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_fs_g4,               // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_lf_g4,               // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx_g4,         // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]     phy_cdm_ras_des_fomfeedback_g4,      // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                  eqpa_violate_rule_123_g4,            // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                  eq_convergence_sts_g4,               // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_rtx_g4,         // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    mac_cdm_ras_des_reject_rtx_g4,       // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input                              init_eq_pending_g5,                  // Level : Equalization sequence  for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_fs_g5,               // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_lf_g5,               // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx_g5,         // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]     phy_cdm_ras_des_fomfeedback_g5,      // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                  eqpa_violate_rule_123_g5,            // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                  eq_convergence_sts_g5,               // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_rtx_g5,         // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    mac_cdm_ras_des_reject_rtx_g5,       // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input                              init_eq_pending_g6,                  // Level : Equalization sequence  for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_fs_g6,               // Level : Remote Device FS for Ras D.E.S Silicon Debug
    input  [NL*TX_FS_WD-1:0]           mac_cdm_ras_des_lf_g6,               // Level : Remote Device LF for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx_g6,         // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL*FOMFEEDBACK_WD-1:0]     phy_cdm_ras_des_fomfeedback_g6,      // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
    input  [NL*3-1:0]                  eqpa_violate_rule_123_g6,            // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    eqpa_violate_rule_4_g6,              // Level : Rule D Violation Event Status for Ras D.E.S Silicon Debug
    input  [NL*2-1:0]                  eq_convergence_sts_g6,               // Level : Equalization convergence information for Ras D.E.S Silicon Debug
    input  [NL*TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_rtx_g6,         // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
    input  [NL-1:0]                    mac_cdm_ras_des_reject_rtx_g6,       // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
    input  [2:0]                       l1sub_state,                         // Level : L1 sub state
    input                              app_ras_des_sd_hold_ltssm,           // Hold LTSSM control signal
// -------------- Outputs ---------------
 // --- Register access signals
    output reg [1:0]                   cdm_sd_ack,                          // Register Response status
    output reg [31:0]                  cdm_sd_rdata,                        // Register Read Data 
 // --- Silcon debug signals
    output [1:0]                       cdm_ras_des_pm_entry_interval,       // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
    output [1:0]                       cdm_ras_des_eidle_cnt_sel,           // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
    output                             cdm_ras_des_ltssm_stop,              // Hold/Release LTSSM
    output                             cdm_ras_des_recovery_req,            // Recovery Request 
    output                             cdm_ras_des_ferr_rec_dis,            // Disable Recovery state transition at Framing Error for Ras D.E.S Silicon Debug
    output                             cdm_ras_des_direct_rcvry_idle_to_cfg,// Direct LTSSM from Recovery.Idle to Configuration for Ras D.E.S Silicon Debug
    output                             cdm_ras_des_direct_poll_cmp_to_det,  // Direct LTSSM from Polling.Compliance to Detect for Ras D.E.S Silicon Debug
    output                             cdm_ras_des_direct_lpbk_slave_to_exit, // Direct LTSSM from Loopback(Slave) to Exit for Ras D.E.S Silicon Debug
    output                             cdm_ras_des_force_rxdetected_en,     // Force Detect Lane Num enable for Ras D.E.S Silicon Debug
    output [15:0]                      cdm_ras_des_force_rxdetected,        // Force Detect Lane Num for Ras D.E.S Silicon Debug
    output                             cdm_ras_des_force_linkdown_noack     // Force Link down when MAC does not receive ACK DLLP for long time
    ,
    output [1:0]                       cdm_ras_des_ext_eq_to_factor,        // Extend the eq 24/32ms timeout x2/x10
    output                             cdm_ras_des_eq_fom_target_en,        // FOM target enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en,    // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_pset_lrx_en,    // Force Local Rx Preset Hint Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en,    // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx,       // Force Local Transmitter Cursor Coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*RX_PSET_WD-1:0]         cdm_ras_des_eq_force_pset_lrx,       // Force Local Receiver Preset Hint for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx,       // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en,    // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx    // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en_g4, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en_g4, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g4,    // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g4,    // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en_g4, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx_g4 // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en_g5, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en_g5, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g5,    // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g5,    // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en_g5, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx_g5 // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en_g6, // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en_g6, // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g6,    // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g6,    // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en_g6, // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx_g6 // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    ,
    output [FOMFEEDBACK_WD-1:0]        cdm_ras_des_eq_fom_target,           // FOM Target value for Ras D.E.S Silicon Debug EQ Control
    output [1:0]                       cdm_ras_des_eq_eval_interval         // EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
) ;

//---------------------------------------------------
//  Common
//---------------------------------------------------
    wire   [7:0]                       int_reg_0xA0, int_reg_0xA1, int_reg_0xA2, int_reg_0xA3 ;  // Read Data Address 0xA0-0xA3
    wire   [7:0]                       int_reg_0xA4, int_reg_0xA5, int_reg_0xA6, int_reg_0xA7 ;  // Read Data Address 0xA4-0xA7
    wire   [7:0]                       int_reg_0xB0, int_reg_0xB1, int_reg_0xB2, int_reg_0xB3 ;  // Read Data Address 0xB0-0xB3
    wire   [7:0]                       int_reg_0xB4, int_reg_0xB5, int_reg_0xB6, int_reg_0xB7 ;  // Read Data Address 0xB4-0xB7
    wire   [7:0]                       int_reg_0xB8, int_reg_0xB9, int_reg_0xBA, int_reg_0xBB ;  // Read Data Address 0xB4-0xBB
    wire   [7:0]                       int_reg_0xBC, int_reg_0xBD, int_reg_0xBE, int_reg_0xBF ;  // Read Data Address 0xBC-0xBF
    wire   [7:0]                       int_reg_0xC0, int_reg_0xC1, int_reg_0xC2, int_reg_0xC3 ;  // Read Data Address 0xC0-0xC3
    wire   [7:0]                       int_reg_0xC4, int_reg_0xC5, int_reg_0xC6, int_reg_0xC7 ;  // Read Data Address 0xC4-0xC7
    wire   [7:0]                       int_reg_0xD0, int_reg_0xD1, int_reg_0xD2, int_reg_0xD3 ;  // Read Data Address 0xD0-0xD3
    wire   [7:0]                       int_reg_0xD4, int_reg_0xD5, int_reg_0xD6, int_reg_0xD7 ;  // Read Data Address 0xD4-0xD7
    wire   [7:0]                       int_reg_0xD8, int_reg_0xD9, int_reg_0xDA, int_reg_0xDB ;  // Read Data Address 0xD8-0xDB
    wire   [7:0]                       int_reg_0xE0, int_reg_0xE1, int_reg_0xE2, int_reg_0xE3 ;  // Read Data Address 0xE0-0xE3
    wire   [7:0]                       int_reg_0xE4, int_reg_0xE5, int_reg_0xE6, int_reg_0xE7 ;  // Read Data Address 0xE4-0xE7
    wire   [7:0]                       int_reg_0xE8, int_reg_0xE9, int_reg_0xEA, int_reg_0xEB ;  // Read Data Address 0xE4-0xEB

    localparam NL_WD  = (NL > 1)  ? $clog2(NL)  : 1;
    localparam NVC_WD = (NVC > 1) ? $clog2(NVC) : 1;

    localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

// -----------------------------------------------------------------------------
// cdm_reg_id       - 40
// PCIE Offset      - `RAS_DES_PTR + A0h
// length           - 4 byte
// Cfig register    - int_reg_0xA3, int_reg_0xA2, int_reg_0xA1, int_reg_0xA0
// register         - LOW_POWER_INTERVAL [23:22] : R/W
//                  - TX_EIOS_NUM [21:20] : R/W
//                  - FORCE_DETECT_LANE_EN [16] : R/W
//                  - FORCE_DETECT_LANE [15:0] : R/W
// -----------------------------------------------------------------------------
    reg    [1:0]                       int_reg_lpwr_intv;              // LOW_POWER_INTERVAL [23:22]
    reg    [1:0]                       int_reg_tx_eios_num ;           // TX_EIOS_NUM [21:20]
    reg                                int_reg_force_detect_lane_en ;  // FORCE_DETECT_LANE_EN [16]
    reg    [15:0]                      int_reg_force_detect_lane ;     // FORCE_DETECT_LANE [15:0]

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_force_detect_lane    <= #TP 16'h0000 ;
            int_reg_force_detect_lane_en <= #TP 1'b0 ;
            int_reg_tx_eios_num          <= #TP 2'b00 ;
            int_reg_lpwr_intv            <= #TP 2'b00 ;
        end
        else begin
            int_reg_force_detect_lane[7:0]  <= #TP (cdm_reg_id[40] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : int_reg_force_detect_lane[7:0] ;
            int_reg_force_detect_lane[15:8] <= #TP (cdm_reg_id[40] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : int_reg_force_detect_lane[15:8] ;
            int_reg_force_detect_lane_en    <= #TP (cdm_reg_id[40] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[16]    : int_reg_force_detect_lane_en ;
            int_reg_tx_eios_num             <= #TP (cdm_reg_id[40] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[21:20] : int_reg_tx_eios_num ;
            int_reg_lpwr_intv               <= #TP (cdm_reg_id[40] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:22] : int_reg_lpwr_intv ;
        end
    end

    assign {int_reg_0xA3,int_reg_0xA2,int_reg_0xA1,int_reg_0xA0} = { 8'd0                          // [31:24]
                                                                   , int_reg_lpwr_intv             // [23:22]
                                                                   , int_reg_tx_eios_num           // [21:20]
                                                                   , 3'd0                          // [19:17]
                                                                   , int_reg_force_detect_lane_en  // [16]
                                                                   , int_reg_force_detect_lane     // [15:0]
                                                                   } ;

    assign  cdm_ras_des_pm_entry_interval   = int_reg_lpwr_intv ;
    assign  cdm_ras_des_eidle_cnt_sel       = int_reg_tx_eios_num ;
    assign  cdm_ras_des_force_rxdetected_en = int_reg_force_detect_lane_en ;
    assign  cdm_ras_des_force_rxdetected    = int_reg_force_detect_lane ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 41
// PCIE Offset      - `RAS_DES_PTR + A4h
// length           - 4 byte
// Cfig register    - int_reg_0xA7, int_reg_0xA6, int_reg_0xA5, int_reg_0xA4
// register         -
//                  - LTSSM_TIMEOUT_POLICY [24] : R/W
//                  - FRAMING_ERR_RECOVERY_DISABLE [16] : R/W
//                  - DETECT_LPBKSLV_TO_EXIT [10] : R/W
//                  - DIRECT_POLCOMP_TO_DETECT [9] : R/W
//                  - DIRECT_RECIDLE_TO_CONFIG [8] : R/W
//                  - NOACK_FORCE_LINKDOWN_REPLAY [2] : R/W
//                  - RECOVERY_REQUEST [1] : WO
//                  - HOLD_LTSSM [0] : R/W
// -----------------------------------------------------------------------------
    reg                                int_reg_frm_err_rcvry_disable ;  // FRAMING_ERR_RECOVERY_DISABLE [16]
    wire                               int_reg_frm_err_rcvry_disable_bcm36;
    reg                                int_reg_dtct_lpbkslv_to_exit ;   // DETECT_LPBKSLV_TO_EXIT [10]
    reg                                int_reg_drct_polcomp_to_detect ; // DIRECT_POLCOMP_TO_DETECT [9]
    reg                                int_reg_drct_recidle_to_config ; // DIRECT_RECIDLE_TO_CONFIG [8]
    reg                                int_reg_force_linkdown_replay ;  // NOACK_FORCE_LINKDOWN_REPLAY [2]
    reg                                int_reg_recovery_req ;           // RECOVERY_REQUEST [1] (1 shot)
    reg                                int_reg_hold_ltssm ;             // HOLD_LTSSM [0]

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_hold_ltssm             <= #TP 1'b0 ;
            int_reg_recovery_req           <= #TP 1'b0 ;
            int_reg_force_linkdown_replay  <= #TP 1'b0 ;
            int_reg_drct_recidle_to_config <= #TP 1'b0 ;
            int_reg_drct_polcomp_to_detect <= #TP 1'b0 ;
            int_reg_dtct_lpbkslv_to_exit   <= #TP 1'b0 ;
            int_reg_frm_err_rcvry_disable  <= #TP 1'b0 ;
        end
        else begin
            int_reg_hold_ltssm             <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[0]  : int_reg_hold_ltssm ;
            int_reg_recovery_req           <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[1]  : 1'b0 ;
            int_reg_force_linkdown_replay  <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[2]  : int_reg_force_linkdown_replay ;
            int_reg_drct_recidle_to_config <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[8]  : int_reg_drct_recidle_to_config ;
            int_reg_drct_polcomp_to_detect <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[9]  : int_reg_drct_polcomp_to_detect ;
            int_reg_dtct_lpbkslv_to_exit   <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[10] : int_reg_dtct_lpbkslv_to_exit ;
            int_reg_frm_err_rcvry_disable  <= #TP (cdm_reg_id[41] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[16] : int_reg_frm_err_rcvry_disable ;
        end
    end

        DWC_pcie_ctl_bcm36_nhs
         #(
        .WIDTH      ($bits(int_reg_frm_err_rcvry_disable)),
        .DATA_DELAY (DATA_DELAY_BCM36_NHS)
        ) u_bcm36_nhs_frm_err_rcvry_disable_reg (
        `ifndef SYNTHESIS
        .clk_d   (aux_clk),
        .rst_d_n (sticky_rst_n),
        `endif // SYNTHESIS
        .data_s  (int_reg_frm_err_rcvry_disable),
        .data_d  (int_reg_frm_err_rcvry_disable_bcm36)
        );
        


    assign  cdm_ras_des_ltssm_stop                = int_reg_hold_ltssm | app_ras_des_sd_hold_ltssm; // app_ras_des_hold_ltssm doesn't affect the value of the register.
    assign  cdm_ras_des_recovery_req              = int_reg_recovery_req;
    assign  cdm_ras_des_force_linkdown_noack      = int_reg_force_linkdown_replay;
    assign  cdm_ras_des_direct_rcvry_idle_to_cfg  = int_reg_drct_recidle_to_config;
    assign  cdm_ras_des_direct_poll_cmp_to_det    = int_reg_drct_polcomp_to_detect;
    assign  cdm_ras_des_direct_lpbk_slave_to_exit = int_reg_dtct_lpbkslv_to_exit;
    assign  cdm_ras_des_ferr_rec_dis              = int_reg_frm_err_rcvry_disable_bcm36 ;

    assign {int_reg_0xA7,int_reg_0xA6,int_reg_0xA5,int_reg_0xA4} = { 7'd0                           // [31:25]
                                                                   , 1'b0                           // [24]
                                                                   , 7'd0                           // [23:17]
                                                                   , int_reg_frm_err_rcvry_disable  // [16]
                                                                   , 5'd0                           // [15:11]
                                                                   , int_reg_dtct_lpbkslv_to_exit   // [10]
                                                                   , int_reg_drct_polcomp_to_detect // [9]
                                                                   , int_reg_drct_recidle_to_config // [8]
                                                                   , 5'd0                           // [7:3]
                                                                   , int_reg_force_linkdown_replay  // [2]
                                                                   , int_reg_recovery_req           // [1]
                                                                   , int_reg_hold_ltssm             // [0]
                                                                   } ;


// -----------------------------------------------------------------------------
// cdm_reg_id       - 44
// PCIE Offset      - `RAS_DES_PTR + B0h
// length           - 4 byte
// Cfig register    - int_reg_0xB0, int_reg_0xB1, int_reg_0xB2, int_reg_0xB3
// register         - DESKEW_POINTER [31:24] : RO
//                  - PIPE_TXELECIDLE [20] : RO
//                  - PIPE_RXELECIDLE [19] : RO
//                  - PIPE_RXVALID [18] : RO
//                  - PIPE_DETECT_LANE [17] : RO
//                  - PIPE_RXPOLARITY [16] : RO
//                  - LANE_SELECT [3:0] : R/W
// -----------------------------------------------------------------------------
    reg    [7:0]                       int_reg_deskew_pointer ;     // DESKEW_POINTER [31:24]
    reg                                int_reg_pipe_txelecidle ;    // PIPE_TXELECIDLE [20]
    reg                                int_reg_pipe_rxelecidle ;    // PIPE_RXELECIDLE [19]
    reg                                int_reg_pipe_rxvalid ;       // PIPE_RXVALID [18]
    reg                                int_reg_pipe_detect_lane ;   // PIPE_DETECT_LANE [17]
    reg                                int_reg_pipe_rxpolarity ;    // PIPE_RXPOLARITY [16]
    reg    [3:0]                       int_reg_lane_select ;        // LANE_SELECT [3:0]

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_44
        if (!sticky_rst_n) begin
            // Selector
            int_reg_lane_select <= #TP 4'd0 ;

            // Status
            int_reg_deskew_pointer   <= #TP 8'd0 ;
            int_reg_pipe_txelecidle  <= #TP 1'd0 ;
            int_reg_pipe_rxelecidle  <= #TP 1'd0 ;
            int_reg_pipe_rxvalid     <= #TP 1'd0 ;
            int_reg_pipe_detect_lane <= #TP 1'd0 ;
            int_reg_pipe_rxpolarity  <= #TP 1'd0 ;
        end
        else begin
            // Selector
            int_reg_lane_select <= #TP (cdm_reg_id[44] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[3:0]   : int_reg_lane_select ;

            if (int_reg_lane_select<NL) begin
                // Status
                int_reg_deskew_pointer   <= #TP rmlh_deskew_fifo_ptr[int_reg_lane_select[NL_WD-1:0]] ;
                int_reg_pipe_txelecidle  <= #TP mac_phy_txelec_txburst[int_reg_lane_select[NL_WD-1:0]] ;
                int_reg_pipe_rxelecidle  <= #TP phy_mac_rxelec_rxh8exit[int_reg_lane_select[NL_WD-1:0]] ;
                int_reg_pipe_rxvalid     <= #TP phy_mac_rxvalid_rxburst[int_reg_lane_select[NL_WD-1:0]] ;
                int_reg_pipe_detect_lane <= #TP latched_rxdetected[int_reg_lane_select[NL_WD-1:0]] ;
                int_reg_pipe_rxpolarity  <= #TP mac_phy_rxpolarity[int_reg_lane_select[NL_WD-1:0]] ;
            end
        end
    end

    assign {int_reg_0xB3,int_reg_0xB2,int_reg_0xB1,int_reg_0xB0} = { int_reg_deskew_pointer        // [31:24]
                                                                   , 3'd0                          // [23:21]
                                                                   , int_reg_pipe_txelecidle       // [20]
                                                                   , int_reg_pipe_rxelecidle       // [19]
                                                                   , int_reg_pipe_rxvalid          // [18]
                                                                   , int_reg_pipe_detect_lane      // [17]
                                                                   , int_reg_pipe_rxpolarity       // [16]
                                                                   , 12'd0                         // [15:4]
                                                                   , int_reg_lane_select           // [3:0]
                                                                   } ;


// -----------------------------------------------------------------------------
// cdm_reg_id       - 45
// PCIE Offset      - `RAS_DES_PTR + B4h
// length           - 4 byte
// Cfig register    - int_reg_0xB4, int_reg_0xB5, int_reg_0xB6, int_reg_0xB7
// register         - LTSSM_VARIABLE [31:16] : RO
//                  - LANE_REVERSAL [15] : RO
//                  - PIPE_POWER_DOWN [10:8] : RO
//                  - FRAMING_ERR [7] : RW1C
//                  - FRAMING_ERR_PTR [6:0] : RO
// -----------------------------------------------------------------------------
    wire   [15:0]                      int_reg_ltssm_variable ;     // LTSSM_VARIABLE [31:16]
    wire                               int_reg_lane_reversal ;      // LANE_REVERSAL [15]
    wire   [2:0]                       int_reg_pipe_power_down ;    // PIPE_POWER_DOWN [10:8]

    assign int_reg_lane_reversal   = smlh_lane_reversed ;
    assign int_reg_ltssm_variable  = smlh_ltssm_variable ;
    assign int_reg_pipe_power_down = {1'b0, ltssm_powerdown} ;

//-------- Framing error register control --------------------------
    reg                                int_reg_framing_err ;        // FRAMING_ERR [7]
    reg    [6:0]                       int_reg_framing_err_ptr ;    // FRAMING_ERR_PTR [6:0]

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_framing_err <= #TP 1'd0 ;
            int_reg_framing_err_ptr <= #TP 7'd0 ;
        end
        else begin
            if ( cdm_reg_id[45] & cdm_reg_write_pulse[0] & cdm_reg_wdata[7] ) begin
                int_reg_framing_err <= #TP 1'b0 ;
                int_reg_framing_err_ptr <= #TP 7'd0 ;
            end
            else if ( |rmlh_framing_err_ptr & (int_reg_framing_err==1'b0) ) begin
                int_reg_framing_err <= #TP 1'b1 ;
                int_reg_framing_err_ptr <= #TP rmlh_framing_err_ptr ;
            end
        end
    end

//-------- Register --------------------------
    assign {int_reg_0xB7,int_reg_0xB6,int_reg_0xB5,int_reg_0xB4} = { int_reg_ltssm_variable          // [31:16]
                                                                   , int_reg_lane_reversal           // [15]
                                                                   , 4'd0                            // [14:11]
                                                                   , int_reg_pipe_power_down         // [10:8]
                                                                   , int_reg_framing_err             // [7]
                                                                   , int_reg_framing_err_ptr         // [6:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 46
// PCIE Offset      - `RAS_DES_PTR + B8h
// length           - 4 byte
// Cfig register    - int_reg_0xB4, int_reg_0xB5, int_reg_0xB6, int_reg_0xB7
// register         - PM_USP_PROT_STATE [30:27] : RO
//                  - PM_L0S_STATE [26:24] : RO
//                  - LATCHED_NFTS [23:16] : RO
//                  - L1SUB_STATE[15:13] : RO
//                  - PME_RESEND_FLAG [12] : RW1C
//                  - PM_USP_LINK_STATE [11:8] : RO
//                  - PM_DSP_PROT_STATE [7:4] : RO
//                  - PM_DSP_LINK_STATE [3:0] : RO
// -----------------------------------------------------------------------------
    wire   [7:0]                       int_reg_latched_nfts ;        // LATCHED_NFTS [23:16]
    reg                                int_pme_resend_flag ;         // PME_RESEND_FLAG [12]

    assign int_reg_latched_nfts       = latched_ts_nfts ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_pme_resend_flag <= #TP 1'd0 ;
        end
        else begin
            int_pme_resend_flag <= #TP (cdm_reg_id[46] & cdm_reg_write_pulse[1] & cdm_reg_wdata[12]) ? 1'b0 : pm_pme_resend_flag ? 1'b1 : int_pme_resend_flag ;
        end
    end
   

    assign {int_reg_0xBB,int_reg_0xBA,int_reg_0xB9,int_reg_0xB8} = { 1'd0                            // [31]
                                                                   , pm_usp_prot_state               // [30:27]
                                                                   , pm_l0s_state                    // [26:24]
                                                                   , int_reg_latched_nfts            // [23:16]
                                                                   , l1sub_state                     // [15:13]
                                                                   , int_pme_resend_flag             // [12]
                                                                   , pm_usp_link_state               // [11:8]
                                                                   , pm_dsp_prot_state               // [7:4]
                                                                   , pm_dsp_link_state               // [3:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 47
// PCIE Offset      - `RAS_DES_PTR + BCh
// length           - 4 byte
// Cfig register    - int_reg_0xBC, int_reg_0xBD, int_reg_0xBE, int_reg_0xBF
// register         - INIT_FC_FLAG2 [27] : RO
//                  - INIT_FC_FLAG1 [26] : RO
//                  - DLCM [25:24] : RO
//                  - TX_ACK_SEQ_NO [23:12] : RO
//                  - TX_TLP_SEQ_NO [11:0] : RO
// -----------------------------------------------------------------------------

    wire                               int_reg_init_fc_flag2 ;       // INIT_FC_FLAG2 [27] 
    wire                               int_reg_init_fc_flag1 ;       // INIT_FC_FLAG1 [26]
    wire   [1:0]                       int_reg_dlcm ;                // DLCM [25:24]
    wire   [11:0]                      int_reg_rx_ack_seq_no ;       // TX_ACK_SEQ_NO [23:12]
    wire   [11:0]                      int_reg_tx_tlp_seq_no ;       // TX_TLP_SEQ_NO [11:0]

    assign int_reg_init_fc_flag1 = rdlh_vc0_initfc1_status ;
    assign int_reg_init_fc_flag2 = rdlh_vc0_initfc2_status ;
    assign int_reg_dlcm          = rdlh_dlcntrl_state ;
    assign int_reg_rx_ack_seq_no = rdlh_xplh_curnt_rx_ack_seqnum ;
    assign int_reg_tx_tlp_seq_no = xdlh_xplh_curnt_seqnum ;

    assign {int_reg_0xBF,int_reg_0xBE,int_reg_0xBD,int_reg_0xBC} = { 4'd0                            // [31:28]
                                                                   , int_reg_init_fc_flag2           // [27]
                                                                   , int_reg_init_fc_flag1           // [26]
                                                                   , int_reg_dlcm                    // [25:24]
                                                                   , int_reg_rx_ack_seq_no           // [23:12]
                                                                   , int_reg_tx_tlp_seq_no           // [11:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 48
// PCIE Offset      - `RAS_DES_PTR + C0h
// length           - 4 byte
// Cfig register    - int_reg_0xC0, int_reg_0xC1, int_reg_0xC2, int_reg_0xC3
// register         - CREDIT_DATA1 [31:20] : RO
//                  - CREDIT_DATA0 [19:8] : RO
//                  - CREDIT_SEL_HD [6] : R/W
//                  - CREDIT_SEL_TLP_TYPE [5:4] : R/W
//                  - CREDIT_SEL_CREDIT_TYPE [3] : R/W
//                  - CREDIT_SEL_VC [2:0] : R/W
// -----------------------------------------------------------------------------
    reg    [11:0]                      int_reg_credit_data1 ;               // CREDIT_DATA [31:20]
    reg    [11:0]                      int_reg_credit_data0 ;               // CREDIT_DATA [19:8]
    reg                                int_reg_credit_sel_hd ;              // CREDIT_SEL_HD [6]
    reg    [1:0]                       int_reg_credit_sel_tlp_type ;        // CREDIT_SEL_TLP_TYPE [5:4]
    reg                                int_reg_credit_sel_credit_type ;     // CREDIT_SEL_CREDIT_TYPE [3]
    reg    [2:0]                       int_reg_credit_sel_vc ;              // CREDIT_SEL_VC [2:0]

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_credit_sel_vc           <= #TP 3'd0 ;
            int_reg_credit_sel_credit_type  <= #TP 1'd0 ;
            int_reg_credit_sel_tlp_type     <= #TP 2'd0 ;
            int_reg_credit_sel_hd           <= #TP 1'b0 ;
        end
        else begin
            int_reg_credit_sel_vc           <= #TP (cdm_reg_id[48] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[2:0] : int_reg_credit_sel_vc ;
            int_reg_credit_sel_credit_type  <= #TP (cdm_reg_id[48] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[3]   : int_reg_credit_sel_credit_type ;
            int_reg_credit_sel_tlp_type     <= #TP (cdm_reg_id[48] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:4] : int_reg_credit_sel_tlp_type ;
            int_reg_credit_sel_hd           <= #TP (cdm_reg_id[48] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[6]   : int_reg_credit_sel_hd ;
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_48
        if (!sticky_rst_n) begin
            {int_reg_credit_data1, int_reg_credit_data0} <= #TP 24'd0 ;
        end
        else begin
            if (int_reg_credit_sel_vc<NVC) begin
                case ( {int_reg_credit_sel_hd, int_reg_credit_sel_tlp_type, int_reg_credit_sel_credit_type} )
                // Tx Header/Data
                    {1'b0, 2'd0, 1'd0} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {4'h0, rtlh_fc_allctd_ph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0], 4'h0, rtlh_fc_rcvd_ph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0]};
                    {1'b0, 2'd1, 1'd0} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {4'h0, rtlh_fc_allctd_nph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0], 4'h0, rtlh_fc_rcvd_nph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0]};
                    {1'b0, 2'd2, 1'd0} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {4'h0, rtlh_fc_allctd_cplh[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0], 4'h0, rtlh_fc_rcvd_cplh[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0]};
                    {1'b1, 2'd0, 1'd0} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {rtlh_fc_allctd_pd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0], rtlh_fc_rcvd_pd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0]};
                    {1'b1, 2'd1, 1'd0} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {rtlh_fc_allctd_npd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0], rtlh_fc_rcvd_npd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0]};
                    {1'b1, 2'd2, 1'd0} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {rtlh_fc_allctd_cpld[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0], rtlh_fc_rcvd_cpld[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0]};
                    // Rx Header/Data
                    {1'b0, 2'd0, 1'd1} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {4'h0, xadm_fc_limit_ph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0], 4'h0, xadm_fc_cnsmd_ph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0]};
                    {1'b0, 2'd1, 1'd1} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {4'h0, xadm_fc_limit_nph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0], 4'h0, xadm_fc_cnsmd_nph[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0]};
                    {1'b0, 2'd2, 1'd1} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {4'h0, xadm_fc_limit_cplh[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0], 4'h0, xadm_fc_cnsmd_cplh[int_reg_credit_sel_vc[NVC_WD-1:0]][7:0]};
                    {1'b1, 2'd0, 1'd1} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {xadm_fc_limit_pd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0], xadm_fc_cnsmd_pd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0]};
                    {1'b1, 2'd1, 1'd1} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {xadm_fc_limit_npd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0], xadm_fc_cnsmd_npd[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0]};
                    {1'b1, 2'd2, 1'd1} : {int_reg_credit_data1, int_reg_credit_data0} <= #TP {xadm_fc_limit_cpld[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0], xadm_fc_cnsmd_cpld[int_reg_credit_sel_vc[NVC_WD-1:0]][11:0]};
                    default            : {int_reg_credit_data1, int_reg_credit_data0} <= #TP 24'd0 ;
                endcase
            end
        end
    end

    assign {int_reg_0xC3,int_reg_0xC2,int_reg_0xC1,int_reg_0xC0} = { int_reg_credit_data1            // [31:20]
                                                                   , int_reg_credit_data0            // [19:8]
                                                                   , 1'b0                            // [7]
                                                                   , int_reg_credit_sel_hd           // [6]
                                                                   , int_reg_credit_sel_tlp_type     // [5:4]
                                                                   , int_reg_credit_sel_credit_type  // [3]
                                                                   , int_reg_credit_sel_vc           // [2:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 49
// PCIE Offset      - `RAS_DES_PTR + C4h
// length           - 4 byte
// Cfig register    - int_reg_0xC4, int_reg_0xC5, int_reg_0xC6, int_reg_0xC7
// register         - MFTLP_STATUS [7] : RW1C
// register         - MFTLP_POINTER [6:0] : RO
// -----------------------------------------------------------------------------
    reg                                int_reg_mftlp_sts ;                  // MFTLP_STATUS [7] : RW1C
    reg    [6:0]                       int_reg_mftlp_pointer ;              // MFTLP_POINTER [6:0] : RO

// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: This signal is the status register. The sequential signal is unnecessary.
    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_mftlp
        if (!sticky_rst_n) begin
            int_reg_mftlp_sts <= #TP 1'd0 ;
            int_reg_mftlp_pointer <= #TP 7'd0 ;
        end
        else begin
            if ( cdm_reg_id[49] & cdm_reg_write_pulse[0] & cdm_reg_wdata[7] ) begin
                int_reg_mftlp_sts <= #TP 1'b0 ;
                int_reg_mftlp_pointer <= #TP 7'd0 ;
            end
            else if ( int_reg_mftlp_sts==1'b0 ) begin
                if ( |(find_1st_mlf_ptr(radm_mlf_tlp_err_ptr)) ) begin
                    int_reg_mftlp_sts <= #TP 1'b1 ;
                    int_reg_mftlp_pointer <= #TP find_1st_mlf_ptr(radm_mlf_tlp_err_ptr) ;
                end
                else if ( app_malformed_tlp ) begin
                    int_reg_mftlp_sts <= #TP 1'b1 ;
                    int_reg_mftlp_pointer <= #TP `MFPTR_APL ;
                end
            end
        end
    end
// spyglass enable_block STARC05-2.11.3.1

    function automatic [6:0] find_1st_mlf_ptr ;
        input   [FX_TLP*8-1:0]   mlf_ptr ;
        reg     [6:0]            int_find_ptr ;
        integer                  tlp_loop ;
        begin
            int_find_ptr = 7'd0 ;
            for (tlp_loop=0 ; tlp_loop<FX_TLP ; tlp_loop=tlp_loop+1 ) begin
                if ( |mlf_ptr[tlp_loop*8 +: 8] && (int_find_ptr==8'd0) ) begin
                    int_find_ptr = mlf_ptr[tlp_loop*8 +: 7] ; // Highest bit is ignored.
                end
            end
            find_1st_mlf_ptr = int_find_ptr ;
        end
    endfunction

    assign {int_reg_0xC7,int_reg_0xC6,int_reg_0xC5,int_reg_0xC4} = { 24'd0                           // [31:8]
                                                                   , int_reg_mftlp_sts               // [7]
                                                                   , int_reg_mftlp_pointer           // [6:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 52
// PCIE Offset      - `RAS_DES_PTR + D0h
// length           - 4 byte
// Cfig register    - int_reg_0xD0, int_reg_0xD1, int_reg_0xD2, int_reg_0xD3
// register         - 
//                  - FOM_TARGET [31:24] : R/W
//                  - FOM_TARGET_ENABLE[23] : R/W
//                  - EVAL_INTERVAL_TIME [17:16] : R/W
//                  - EXT_EQ_TIMEOUT [9:8] : R/W
//                  - EQ_RATE_SEL [4] : R/W
//                  - EQ_LANE_SEL [3:0] : R/W
// -----------------------------------------------------------------------------
    reg    [7:0]                       int_reg_fom_target ;                    // FOM_TARGET [31:24]
    reg                                int_reg_fom_target_en ;                 // FOM_TARGET_ENABLE [23]
    reg    [1:0]                       int_reg_eval_interval_time ;            // EVAL_INTERVAL_TIME [17:16] 
    reg    [9:8]                       int_reg_ext_eq_to_factor ;              // EXT_EQ_TIMEOUT [9:8]
    reg    [1:0]                       int_reg_eq_rate_sel ;                   // EQ_RATE_SEL [5:4] 
    reg    [3:0]                       int_reg_eq_lane_sel ;                   // EQ_LANE_SEL [3:0]

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_eq_lane_sel <= #TP 4'd0 ;
            int_reg_eq_rate_sel <= #TP 2'd0 ;
            int_reg_ext_eq_to_factor <= #TP 2'd0 ;
            int_reg_eval_interval_time <= #TP 2'd0 ;
            int_reg_fom_target_en <= #TP 1'b0 ;
            int_reg_fom_target <= #TP 8'd0 ;
        end
        else begin
            int_reg_eq_lane_sel                 <= #TP (cdm_reg_id[52] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[3:0]    : int_reg_eq_lane_sel ;
            int_reg_eq_rate_sel                 <= #TP (cdm_reg_id[52] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:4]      : int_reg_eq_rate_sel ;
            int_reg_ext_eq_to_factor            <= #TP (cdm_reg_id[52] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[9:8]    : int_reg_ext_eq_to_factor ;
            int_reg_eval_interval_time          <= #TP (cdm_reg_id[52] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16]  : int_reg_eval_interval_time ;
            int_reg_fom_target_en               <= #TP (cdm_reg_id[52] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23]     : int_reg_fom_target_en ;
            int_reg_fom_target                  <= #TP (cdm_reg_id[52] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24]  : int_reg_fom_target ;
        end
    end

    assign cdm_ras_des_eq_fom_target_en = int_reg_fom_target_en ;
    assign cdm_ras_des_eq_eval_interval = int_reg_eval_interval_time ;
    assign cdm_ras_des_eq_fom_target = int_reg_fom_target ;
    assign cdm_ras_des_ext_eq_to_factor = int_reg_ext_eq_to_factor ;

    assign {int_reg_0xD3,int_reg_0xD2,int_reg_0xD1,int_reg_0xD0} = {
                                                                     int_reg_fom_target                     // [31:24]
                                                                   , int_reg_fom_target_en                  // [23]
                                                                   , 5'd0                                   // [22:18]
                                                                   , int_reg_eval_interval_time             // [17:16]
                                                                   , 6'd0                                   // [15:10]
                                                                   , int_reg_ext_eq_to_factor               // [9:8]
                                                                   , 2'd0                                   // [7:6]
                                                                   , int_reg_eq_rate_sel                    // [5:4]
                                                                   , int_reg_eq_lane_sel                    // [3:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 53
// PCIE Offset      - `RAS_DES_PTR + D4h
// length           - 4 byte
// Cfig register    - int_reg_0xD4, int_reg_0xD5, int_reg_0xD6, int_reg_0xD7
// register         - FORCE_LOCAL_TX_PRESET_ENABLE [30] : R/W
//                  - FORCE_LOCAL_RX_HINT_ENABLE [29] : R/W
//                  - FORCE_LOCAL_TX_CURSOR_ENABLE [28] : R/W
//                  - FORCE_LOCAL_TX_PRESET [27:24] : R/W
//                  - FORCE_LOCAL_TX_2ND_PRE_CURSOR_COEF [23:21] : R/W
//                  - FORCE_LOCAL_RX_PRESET [20:18] or FORCE_LOCAL_TX_2ND_PRE_CURSOR_COEF [20:18] : R/W
//                  - FORCE_LOCAL_TX_POST_CURSOR_COEF [17:12] : R/W
//                  - FORCE_LOCAL_TX_CURSOR_COEF [11:6] : R/W
//                  - FORCE_LOCAL_TX_PRE_CURSOR_COEF [5:0] : R/W
// -----------------------------------------------------------------------------
    reg                                int_reg_force_lc_tx_preset_en ;                         // FORCE_LOCAL_TX_PRESET_ENABLE [30]
    reg                                int_reg_force_lc_rx_preset_en ;                         // FORCE_LOCAL_RX_HINT_ENABLE [29]
    reg                                int_reg_force_lc_tx_cursor_coef_en ;                    // FORCE_LOCAL_TX_CURSOR_ENABLE [28]
    reg    [3:0]                       int_reg_force_lc_tx_preset ;                            // FORCE_LOCAL_RX_PRESET [27:24]
    reg    [2:0]                       int_reg_force_lc_tx_2nd_pre_cursor_coef ;               // FORCE_LOCAL_TX_2ND_PRE_CURSOR_COEF [23:21]
    reg    [2:0]                       int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef ;  // FORCE_LOCAL_RX_PRESET [20:18] or FORCE_LOCAL_TX_2ND_PRE_CURSOR_COEF [20:18]
    reg    [5:0]                       int_reg_force_lc_tx_post_cursor_coef ;                  // FORCE_LOCAL_TX_PRE_CURSOR_COEF [17:12]
    reg    [5:0]                       int_reg_force_lc_tx_cursor_coef ;                       // FORCE_LOCAL_TX_CURSOR_COEF [11:6]
    reg    [5:0]                       int_reg_force_lc_tx_pre_cursor_coef ;                   // FORCE_LOCAL_TX_POST_CURSOR_COEF [5:0]
    reg    [NL-1:0]                    int_reg_force_lc_tx_preset_en_g3 ;
    reg    [NL-1:0]                    int_reg_force_lc_rx_preset_en_g3 ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_cursor_coef_en_g3 ;
    reg    [2:0]                       int_reg_force_lc_rx_preset_g3[0:NL-1] ;
    reg    [3:0]                       int_reg_force_lc_tx_preset_g3[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_post_cursor_coef_g3[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_cursor_coef_g3[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_pre_cursor_coef_g3[0:NL-1] ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_preset_en_g4 ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_cursor_coef_en_g4 ;
    reg    [3:0]                       int_reg_force_lc_tx_preset_g4[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_post_cursor_coef_g4[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_cursor_coef_g4[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_pre_cursor_coef_g4[0:NL-1] ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_preset_en_g5 ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_cursor_coef_en_g5 ;
    reg    [3:0]                       int_reg_force_lc_tx_preset_g5[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_post_cursor_coef_g5[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_cursor_coef_g5[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_pre_cursor_coef_g5[0:NL-1] ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_preset_en_g6 ;
    reg    [NL-1:0]                    int_reg_force_lc_tx_cursor_coef_en_g6 ;
    reg    [3:0]                       int_reg_force_lc_tx_preset_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_post_cursor_coef_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_cursor_coef_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_pre_cursor_coef_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[0:NL-1] ;
    genvar                             ln ;

    generate
    for ( ln=0 ; ln<NL ; ln=ln+1 ) begin : gen_int_reg_force_lc
        always @(posedge aux_clk or negedge sticky_rst_n) begin
            if (!sticky_rst_n) begin
                int_reg_force_lc_tx_pre_cursor_coef_g3[ln]  <= #TP 6'd0 ;
                int_reg_force_lc_tx_cursor_coef_g3[ln]      <= #TP 6'd0 ;
                int_reg_force_lc_tx_post_cursor_coef_g3[ln] <= #TP 6'd0 ;
                int_reg_force_lc_rx_preset_g3[ln]           <= #TP 3'd0 ;
                int_reg_force_lc_tx_preset_g3[ln]           <= #TP 4'd0 ;
                int_reg_force_lc_tx_cursor_coef_en_g3[ln]   <= #TP 1'b0 ;
                int_reg_force_lc_rx_preset_en_g3[ln]        <= #TP 1'b0 ;
                int_reg_force_lc_tx_preset_en_g3[ln]        <= #TP 1'b0 ;
                int_reg_force_lc_tx_pre_cursor_coef_g4[ln]  <= #TP 6'd0 ;
                int_reg_force_lc_tx_cursor_coef_g4[ln]      <= #TP 6'd0 ;
                int_reg_force_lc_tx_post_cursor_coef_g4[ln] <= #TP 6'd0 ;
                int_reg_force_lc_tx_preset_g4[ln]           <= #TP 4'd0 ;
                int_reg_force_lc_tx_cursor_coef_en_g4[ln]   <= #TP 1'b0 ;
                int_reg_force_lc_tx_preset_en_g4[ln]        <= #TP 1'b0 ;
                int_reg_force_lc_tx_pre_cursor_coef_g5[ln]  <= #TP 6'd0 ;
                int_reg_force_lc_tx_cursor_coef_g5[ln]      <= #TP 6'd0 ;
                int_reg_force_lc_tx_post_cursor_coef_g5[ln] <= #TP 6'd0 ;
                int_reg_force_lc_tx_preset_g5[ln]           <= #TP 4'd0 ;
                int_reg_force_lc_tx_cursor_coef_en_g5[ln]   <= #TP 1'b0 ;
                int_reg_force_lc_tx_preset_en_g5[ln]        <= #TP 1'b0 ;
                int_reg_force_lc_tx_pre_cursor_coef_g6[ln]     <= #TP 6'd0 ;
                int_reg_force_lc_tx_cursor_coef_g6[ln]         <= #TP 6'd0 ;
                int_reg_force_lc_tx_post_cursor_coef_g6[ln]    <= #TP 6'd0 ;
                int_reg_force_lc_tx_preset_g6[ln]              <= #TP 4'd0 ;
                int_reg_force_lc_tx_cursor_coef_en_g6[ln]      <= #TP 1'b0 ;
                int_reg_force_lc_tx_preset_en_g6[ln]           <= #TP 1'b0 ;
                int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[ln] <= #TP 6'd0 ;
            end
            else begin
                if ( int_reg_eq_lane_sel==ln ) begin
                    if ( int_reg_eq_rate_sel==2'd0 ) begin
                        int_reg_force_lc_tx_pre_cursor_coef_g3[ln]       <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_lc_tx_pre_cursor_coef_g3[ln] ;
                        int_reg_force_lc_tx_cursor_coef_g3[ln][1:0]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_lc_tx_cursor_coef_g3[ln][1:0] ;
                        int_reg_force_lc_tx_cursor_coef_g3[ln][5:2]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_lc_tx_cursor_coef_g3[ln][5:2] ;
                        int_reg_force_lc_tx_post_cursor_coef_g3[ln][3:0] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_lc_tx_post_cursor_coef_g3[ln][3:0] ;
                        int_reg_force_lc_tx_post_cursor_coef_g3[ln][5:4] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_lc_tx_post_cursor_coef_g3[ln][5:4] ;
                        int_reg_force_lc_rx_preset_g3[ln]                <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[20:18] : int_reg_force_lc_rx_preset_g3[ln] ;
                        int_reg_force_lc_tx_preset_g3[ln]                <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[27:24] : int_reg_force_lc_tx_preset_g3[ln] ;
                        int_reg_force_lc_tx_cursor_coef_en_g3[ln]        <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_lc_tx_cursor_coef_en_g3[ln] ;
                        int_reg_force_lc_rx_preset_en_g3[ln]             <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[29]    : int_reg_force_lc_rx_preset_en_g3[ln] ;
                        int_reg_force_lc_tx_preset_en_g3[ln]             <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[30]    : int_reg_force_lc_tx_preset_en_g3[ln] ;
                    end
                    else if ( int_reg_eq_rate_sel==2'd1 ) begin
                        int_reg_force_lc_tx_pre_cursor_coef_g4[ln]       <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_lc_tx_pre_cursor_coef_g4[ln] ;
                        int_reg_force_lc_tx_cursor_coef_g4[ln][1:0]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_lc_tx_cursor_coef_g4[ln][1:0] ;
                        int_reg_force_lc_tx_cursor_coef_g4[ln][5:2]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_lc_tx_cursor_coef_g4[ln][5:2] ;
                        int_reg_force_lc_tx_post_cursor_coef_g4[ln][3:0] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_lc_tx_post_cursor_coef_g4[ln][3:0] ;
                        int_reg_force_lc_tx_post_cursor_coef_g4[ln][5:4] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_lc_tx_post_cursor_coef_g4[ln][5:4] ;
                        int_reg_force_lc_tx_preset_g4[ln]                <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[27:24] : int_reg_force_lc_tx_preset_g4[ln] ;
                        int_reg_force_lc_tx_cursor_coef_en_g4[ln]        <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_lc_tx_cursor_coef_en_g4[ln] ;
                        int_reg_force_lc_tx_preset_en_g4[ln]             <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[30]    : int_reg_force_lc_tx_preset_en_g4[ln] ;
                    end
                    else if (int_reg_eq_rate_sel==2'd2) begin
                        int_reg_force_lc_tx_pre_cursor_coef_g5[ln]       <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_lc_tx_pre_cursor_coef_g5[ln] ;
                        int_reg_force_lc_tx_cursor_coef_g5[ln][1:0]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_lc_tx_cursor_coef_g5[ln][1:0] ;
                        int_reg_force_lc_tx_cursor_coef_g5[ln][5:2]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_lc_tx_cursor_coef_g5[ln][5:2] ;
                        int_reg_force_lc_tx_post_cursor_coef_g5[ln][3:0] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_lc_tx_post_cursor_coef_g5[ln][3:0] ;
                        int_reg_force_lc_tx_post_cursor_coef_g5[ln][5:4] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_lc_tx_post_cursor_coef_g5[ln][5:4] ;
                        int_reg_force_lc_tx_preset_g5[ln]                <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[27:24] : int_reg_force_lc_tx_preset_g5[ln] ;
                        int_reg_force_lc_tx_cursor_coef_en_g5[ln]        <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_lc_tx_cursor_coef_en_g5[ln] ;
                        int_reg_force_lc_tx_preset_en_g5[ln]             <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[30]    : int_reg_force_lc_tx_preset_en_g5[ln] ;
                    end
                    else begin
                        int_reg_force_lc_tx_pre_cursor_coef_g6[ln]       <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_lc_tx_pre_cursor_coef_g6[ln] ;
                        int_reg_force_lc_tx_cursor_coef_g6[ln][1:0]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_lc_tx_cursor_coef_g6[ln][1:0] ;
                        int_reg_force_lc_tx_cursor_coef_g6[ln][5:2]      <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_lc_tx_cursor_coef_g6[ln][5:2] ;
                        int_reg_force_lc_tx_post_cursor_coef_g6[ln][3:0] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_lc_tx_post_cursor_coef_g6[ln][3:0] ;
                        int_reg_force_lc_tx_post_cursor_coef_g6[ln][5:4] <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_lc_tx_post_cursor_coef_g6[ln][5:4] ;
                        int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[ln]   <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:18] : int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[ln] ;
                        int_reg_force_lc_tx_preset_g6[ln]                <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[27:24] : int_reg_force_lc_tx_preset_g6[ln] ;
                        int_reg_force_lc_tx_cursor_coef_en_g6[ln]        <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_lc_tx_cursor_coef_en_g6[ln] ;
                        int_reg_force_lc_tx_preset_en_g6[ln]             <= #TP (cdm_reg_id[53] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[30]    : int_reg_force_lc_tx_preset_en_g6[ln] ;
                    end
                end
            end
        end
    end
    endgenerate

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_53
        if (!sticky_rst_n) begin
            int_reg_force_lc_tx_pre_cursor_coef                  <= #TP 6'd0 ;
            int_reg_force_lc_tx_cursor_coef                      <= #TP 6'd0 ;
            int_reg_force_lc_tx_post_cursor_coef                 <= #TP 6'd0 ;
            int_reg_force_lc_tx_preset                           <= #TP 4'd0 ;
            int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef <= #TP 3'd0 ;
            int_reg_force_lc_tx_cursor_coef_en                   <= #TP 1'b0 ;
            int_reg_force_lc_rx_preset_en                        <= #TP 1'b0 ;
            int_reg_force_lc_tx_preset_en                        <= #TP 1'b0 ;
            int_reg_force_lc_tx_2nd_pre_cursor_coef              <= #TP 3'd0 ;
        end
        else begin
            if ( int_reg_eq_rate_sel==2'd0 ) begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_lc_tx_pre_cursor_coef                  <= #TP int_reg_force_lc_tx_pre_cursor_coef_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_cursor_coef                      <= #TP int_reg_force_lc_tx_cursor_coef_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_post_cursor_coef                 <= #TP int_reg_force_lc_tx_post_cursor_coef_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_preset                           <= #TP int_reg_force_lc_tx_preset_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef <= #TP int_reg_force_lc_rx_preset_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_cursor_coef_en                   <= #TP int_reg_force_lc_tx_cursor_coef_en_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_en                        <= #TP int_reg_force_lc_rx_preset_en_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_preset_en                        <= #TP int_reg_force_lc_tx_preset_en_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_2nd_pre_cursor_coef              <= #TP 3'd0 ;
                end
            end
            else if ( int_reg_eq_rate_sel==2'd1 ) begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_lc_tx_pre_cursor_coef                  <= #TP int_reg_force_lc_tx_pre_cursor_coef_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_cursor_coef                      <= #TP int_reg_force_lc_tx_cursor_coef_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_post_cursor_coef                 <= #TP int_reg_force_lc_tx_post_cursor_coef_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_preset                           <= #TP int_reg_force_lc_tx_preset_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef <= #TP 3'd0;
                    int_reg_force_lc_tx_cursor_coef_en                   <= #TP int_reg_force_lc_tx_cursor_coef_en_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_en                        <= #TP 1'd0;
                    int_reg_force_lc_tx_preset_en                        <= #TP int_reg_force_lc_tx_preset_en_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_2nd_pre_cursor_coef              <= #TP 3'd0 ;
                end
            end
            else if (int_reg_eq_rate_sel==2'd2) begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_lc_tx_pre_cursor_coef                  <= #TP int_reg_force_lc_tx_pre_cursor_coef_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_cursor_coef                      <= #TP int_reg_force_lc_tx_cursor_coef_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_post_cursor_coef                 <= #TP int_reg_force_lc_tx_post_cursor_coef_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_preset                           <= #TP int_reg_force_lc_tx_preset_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef <= #TP 3'd0;
                    int_reg_force_lc_tx_cursor_coef_en                   <= #TP int_reg_force_lc_tx_cursor_coef_en_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_en                        <= #TP 1'd0;
                    int_reg_force_lc_tx_preset_en                        <= #TP int_reg_force_lc_tx_preset_en_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_2nd_pre_cursor_coef              <= #TP 3'd0 ;
                end
            end
            else begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_lc_tx_pre_cursor_coef                  <= #TP int_reg_force_lc_tx_pre_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_cursor_coef                      <= #TP int_reg_force_lc_tx_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_post_cursor_coef                 <= #TP int_reg_force_lc_tx_post_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_preset                           <= #TP int_reg_force_lc_tx_preset_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef <= #TP int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]][2:0]; // FORCE_LOCAL_TX_2ND_PRE_CURSOR_COEF [20:18]
                    int_reg_force_lc_tx_cursor_coef_en                   <= #TP int_reg_force_lc_tx_cursor_coef_en_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_rx_preset_en                        <= #TP 1'd0;
                    int_reg_force_lc_tx_preset_en                        <= #TP int_reg_force_lc_tx_preset_en_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_lc_tx_2nd_pre_cursor_coef              <= #TP int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]][5:3]; // FORCE_LOCAL_TX_2ND_PRE_CURSOR_COEF [23:21]
                end
            end
        end
    end

    assign {int_reg_0xD7,int_reg_0xD6,int_reg_0xD5,int_reg_0xD4} = { 
                                                                     1'd0                                                 // [31]
                                                                   , int_reg_force_lc_tx_preset_en                        // [30]
                                                                   , int_reg_force_lc_rx_preset_en                        // [29]
                                                                   , int_reg_force_lc_tx_cursor_coef_en                   // [28]
                                                                   , int_reg_force_lc_tx_preset                           // [27:24]
                                                                   , int_reg_force_lc_tx_2nd_pre_cursor_coef              // [23:21]
                                                                   , int_reg_force_lc_rx_preset_or_tx_2nd_pre_cursor_coef // [20:18]
                                                                   , int_reg_force_lc_tx_post_cursor_coef                 // [17:12]
                                                                   , int_reg_force_lc_tx_cursor_coef                      // [11:6]
                                                                   , int_reg_force_lc_tx_pre_cursor_coef                  // [5:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 54
// PCIE Offset      - `RAS_DES_PTR + D8h
// length           - 4 byte
// Cfig register    - int_reg_0xD8, int_reg_0xD9, int_reg_0xDA, int_reg_0xDB
// register         - FORCE_REMOTE_TX_CURSOR_ENABLE [28] : R/W
//                  - FORCE_REMOTE_TX_2ND_PRE_CURSOR_COEF [23:18] : R/W
//                  - FORCE_REMOTE_TX_POST_CURSOR_COEF [17:12] : R/W
//                  - FORCE_REMOTE_TX_CURSOR_COEF [11:6] : R/W
//                  - FORCE_REMOTE_TX_PRE_CURSOR_COEF [5:0] : R/W
// -----------------------------------------------------------------------------
    reg                                int_reg_force_rm_tx_cursor_coef_en ;               // FORCE_REMOTE_TX_CURSOR_ENABLE [28]
    reg    [5:0]                       int_reg_force_rm_tx_2nd_pre_cursor_coef ;          // FORCE_REMOTE_TX_2ND_PRE_CURSOR_COEF [23:18]
    reg    [5:0]                       int_reg_force_rm_tx_post_cursor_coef ;             // FORCE_REMOTE_TX_POST_CURSOR_COEF [17:12]
    reg    [5:0]                       int_reg_force_rm_tx_cursor_coef ;                  // FORCE_REMOTE_TX_CURSOR_COEF [11:6]
    reg    [5:0]                       int_reg_force_rm_tx_pre_cursor_coef ;              // FORCE_REMOTE_TX_PRE_CURSOR_COEF [5:0]
    reg    [NL-1:0]                    int_reg_force_rm_tx_cursor_coef_en_g3 ;
    reg    [5:0]                       int_reg_force_rm_tx_post_cursor_coef_g3[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_cursor_coef_g3[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_pre_cursor_coef_g3[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_post_cursor_coef_g4[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_cursor_coef_g4[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_pre_cursor_coef_g4[0:NL-1] ;
    reg    [NL-1:0]                    int_reg_force_rm_tx_cursor_coef_en_g4 ;
    reg    [5:0]                       int_reg_force_rm_tx_post_cursor_coef_g5[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_cursor_coef_g5[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_pre_cursor_coef_g5[0:NL-1] ;
    reg    [NL-1:0]                    int_reg_force_rm_tx_cursor_coef_en_g5 ;
    reg    [5:0]                       int_reg_force_rm_tx_post_cursor_coef_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_cursor_coef_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_pre_cursor_coef_g6[0:NL-1] ;
    reg    [5:0]                       int_reg_force_rm_tx_2nd_pre_cursor_coef_g6[0:NL-1] ;
    reg    [NL-1:0]                    int_reg_force_rm_tx_cursor_coef_en_g6 ;

    generate
    for ( ln=0 ; ln<NL ; ln=ln+1 ) begin : gen_int_reg_force_rm
        always @(posedge aux_clk or negedge sticky_rst_n) begin
            if (!sticky_rst_n) begin
                int_reg_force_rm_tx_pre_cursor_coef_g3[ln]  <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_g3[ln]      <= #TP 6'd0 ;
                int_reg_force_rm_tx_post_cursor_coef_g3[ln] <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_en_g3[ln]   <= #TP 1'b0 ;
                int_reg_force_rm_tx_pre_cursor_coef_g4[ln]  <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_g4[ln]      <= #TP 6'd0 ;
                int_reg_force_rm_tx_post_cursor_coef_g4[ln] <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_en_g4[ln]   <= #TP 1'b0 ;
                int_reg_force_rm_tx_pre_cursor_coef_g5[ln]  <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_g5[ln]      <= #TP 6'd0 ;
                int_reg_force_rm_tx_post_cursor_coef_g5[ln] <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_en_g5[ln]   <= #TP 1'b0 ;
                int_reg_force_rm_tx_2nd_pre_cursor_coef_g6[ln]  <= #TP 6'd0 ;
                int_reg_force_rm_tx_pre_cursor_coef_g6[ln]      <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_g6[ln]          <= #TP 6'd0 ;
                int_reg_force_rm_tx_post_cursor_coef_g6[ln]     <= #TP 6'd0 ;
                int_reg_force_rm_tx_cursor_coef_en_g6[ln]       <= #TP 1'b0 ;
            end
            else begin
                if ( int_reg_eq_lane_sel==ln ) begin
                    if ( int_reg_eq_rate_sel==2'd0 ) begin
                        int_reg_force_rm_tx_pre_cursor_coef_g3[ln]       <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_rm_tx_pre_cursor_coef_g3[ln] ;
                        int_reg_force_rm_tx_cursor_coef_g3[ln][1:0]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_rm_tx_cursor_coef_g3[ln][1:0] ;
                        int_reg_force_rm_tx_cursor_coef_g3[ln][5:2]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_rm_tx_cursor_coef_g3[ln][5:2] ;
                        int_reg_force_rm_tx_post_cursor_coef_g3[ln][3:0] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_rm_tx_post_cursor_coef_g3[ln][3:0] ;
                        int_reg_force_rm_tx_post_cursor_coef_g3[ln][5:4] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_rm_tx_post_cursor_coef_g3[ln][5:4] ;
                        int_reg_force_rm_tx_cursor_coef_en_g3[ln]        <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_rm_tx_cursor_coef_en_g3[ln] ;
                    end
                    else if ( int_reg_eq_rate_sel==2'd1 ) begin
                        int_reg_force_rm_tx_pre_cursor_coef_g4[ln]       <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_rm_tx_pre_cursor_coef_g4[ln] ;
                        int_reg_force_rm_tx_cursor_coef_g4[ln][1:0]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_rm_tx_cursor_coef_g4[ln][1:0] ;
                        int_reg_force_rm_tx_cursor_coef_g4[ln][5:2]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_rm_tx_cursor_coef_g4[ln][5:2] ;
                        int_reg_force_rm_tx_post_cursor_coef_g4[ln][3:0] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_rm_tx_post_cursor_coef_g4[ln][3:0] ;
                        int_reg_force_rm_tx_post_cursor_coef_g4[ln][5:4] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_rm_tx_post_cursor_coef_g4[ln][5:4] ;
                        int_reg_force_rm_tx_cursor_coef_en_g4[ln]        <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_rm_tx_cursor_coef_en_g4[ln] ;
                    end
                    else if ( int_reg_eq_rate_sel==2'd2 ) begin
                        int_reg_force_rm_tx_pre_cursor_coef_g5[ln]       <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_rm_tx_pre_cursor_coef_g5[ln] ;
                        int_reg_force_rm_tx_cursor_coef_g5[ln][1:0]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_rm_tx_cursor_coef_g5[ln][1:0] ;
                        int_reg_force_rm_tx_cursor_coef_g5[ln][5:2]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_rm_tx_cursor_coef_g5[ln][5:2] ;
                        int_reg_force_rm_tx_post_cursor_coef_g5[ln][3:0] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_rm_tx_post_cursor_coef_g5[ln][3:0] ;
                        int_reg_force_rm_tx_post_cursor_coef_g5[ln][5:4] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_rm_tx_post_cursor_coef_g5[ln][5:4] ;
                        int_reg_force_rm_tx_cursor_coef_en_g5[ln]        <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_rm_tx_cursor_coef_en_g5[ln] ;
                    end
                    else begin
                        int_reg_force_rm_tx_pre_cursor_coef_g6[ln]       <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[5:0]   : int_reg_force_rm_tx_pre_cursor_coef_g6[ln] ;
                        int_reg_force_rm_tx_cursor_coef_g6[ln][1:0]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:6]   : int_reg_force_rm_tx_cursor_coef_g6[ln][1:0] ;
                        int_reg_force_rm_tx_cursor_coef_g6[ln][5:2]      <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8]  : int_reg_force_rm_tx_cursor_coef_g6[ln][5:2] ;
                        int_reg_force_rm_tx_post_cursor_coef_g6[ln][3:0] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:12] : int_reg_force_rm_tx_post_cursor_coef_g6[ln][3:0] ;
                        int_reg_force_rm_tx_post_cursor_coef_g6[ln][5:4] <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[17:16] : int_reg_force_rm_tx_post_cursor_coef_g6[ln][5:4] ;
                        int_reg_force_rm_tx_2nd_pre_cursor_coef_g6[ln]   <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:18] : int_reg_force_rm_tx_2nd_pre_cursor_coef_g6[ln] ;
                        int_reg_force_rm_tx_cursor_coef_en_g6[ln]        <= #TP (cdm_reg_id[54] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28]    : int_reg_force_rm_tx_cursor_coef_en_g6[ln] ;
                    end
                end
            end
        end
    end
    endgenerate

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_54
        if (!sticky_rst_n) begin
            int_reg_force_rm_tx_2nd_pre_cursor_coef <= #TP 6'd0 ;
            int_reg_force_rm_tx_pre_cursor_coef     <= #TP 6'd0 ;
            int_reg_force_rm_tx_cursor_coef         <= #TP 6'd0 ;
            int_reg_force_rm_tx_post_cursor_coef    <= #TP 6'd0 ;
            int_reg_force_rm_tx_cursor_coef_en      <= #TP 1'b0 ;
        end
        else begin
            if ( int_reg_eq_rate_sel==2'd0 ) begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_rm_tx_2nd_pre_cursor_coef <= #TP 6'd0 ;
                    int_reg_force_rm_tx_pre_cursor_coef     <= #TP int_reg_force_rm_tx_pre_cursor_coef_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef         <= #TP int_reg_force_rm_tx_cursor_coef_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_post_cursor_coef    <= #TP int_reg_force_rm_tx_post_cursor_coef_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef_en      <= #TP int_reg_force_rm_tx_cursor_coef_en_g3[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                end
            end
            else if ( int_reg_eq_rate_sel==2'd1 ) begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_rm_tx_2nd_pre_cursor_coef <= #TP 6'd0 ;
                    int_reg_force_rm_tx_pre_cursor_coef     <= #TP int_reg_force_rm_tx_pre_cursor_coef_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef         <= #TP int_reg_force_rm_tx_cursor_coef_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_post_cursor_coef    <= #TP int_reg_force_rm_tx_post_cursor_coef_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef_en      <= #TP int_reg_force_rm_tx_cursor_coef_en_g4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                end
            end
            else if ( int_reg_eq_rate_sel==2'd2 ) begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_rm_tx_2nd_pre_cursor_coef <= #TP 6'd0 ;
                    int_reg_force_rm_tx_pre_cursor_coef     <= #TP int_reg_force_rm_tx_pre_cursor_coef_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef         <= #TP int_reg_force_rm_tx_cursor_coef_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_post_cursor_coef    <= #TP int_reg_force_rm_tx_post_cursor_coef_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef_en      <= #TP int_reg_force_rm_tx_cursor_coef_en_g5[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                end
            end
            else begin
                if (int_reg_eq_lane_sel<NL) begin
                    int_reg_force_rm_tx_2nd_pre_cursor_coef <= #TP int_reg_force_rm_tx_2nd_pre_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]];
                    int_reg_force_rm_tx_pre_cursor_coef     <= #TP int_reg_force_rm_tx_pre_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef         <= #TP int_reg_force_rm_tx_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_post_cursor_coef    <= #TP int_reg_force_rm_tx_post_cursor_coef_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                    int_reg_force_rm_tx_cursor_coef_en      <= #TP int_reg_force_rm_tx_cursor_coef_en_g6[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                end
            end
        end
    end

    generate
    for ( ln=0 ; ln<NL ; ln=ln+1 ) begin : gen_cdm_ras_des_eq
        // G3:Local
        assign cdm_ras_des_eq_force_usp_pset_ltx[4*ln +: 4]    = int_reg_force_lc_tx_preset_g3[ln] ;
        assign cdm_ras_des_eq_force_pset_ltx_en[ln]            = int_reg_force_lc_tx_preset_en_g3[ln] ;
        assign cdm_ras_des_eq_force_pset_lrx[3*ln +: 3]        = int_reg_force_lc_rx_preset_g3[ln] ;
        assign cdm_ras_des_eq_force_coef_ltx[18*ln +: 18]      = {int_reg_force_lc_tx_post_cursor_coef_g3[ln], int_reg_force_lc_tx_cursor_coef_g3[ln], int_reg_force_lc_tx_pre_cursor_coef_g3[ln]} ;
        assign cdm_ras_des_eq_force_coef_ltx_en[ln]            = int_reg_force_lc_tx_cursor_coef_en_g3[ln] ;
        assign cdm_ras_des_eq_force_pset_lrx_en[ln]            = int_reg_force_lc_rx_preset_en_g3[ln] ;
        // G3:Remote
        assign cdm_ras_des_eq_force_coef_rtx[18*ln +: 18]      = {int_reg_force_rm_tx_post_cursor_coef_g3[ln], int_reg_force_rm_tx_cursor_coef_g3[ln], int_reg_force_rm_tx_pre_cursor_coef_g3[ln]} ;
        assign cdm_ras_des_eq_force_coef_rtx_en[ln]            = int_reg_force_rm_tx_cursor_coef_en_g3[ln] ;
        // G4:Local
        assign cdm_ras_des_eq_force_usp_pset_ltx_g4[4*ln +: 4] = int_reg_force_lc_tx_preset_g4[ln] ;
        assign cdm_ras_des_eq_force_pset_ltx_en_g4[ln]         = int_reg_force_lc_tx_preset_en_g4[ln] ;
        assign cdm_ras_des_eq_force_coef_ltx_g4[18*ln +: 18]   = {int_reg_force_lc_tx_post_cursor_coef_g4[ln], int_reg_force_lc_tx_cursor_coef_g4[ln], int_reg_force_lc_tx_pre_cursor_coef_g4[ln]} ;
        assign cdm_ras_des_eq_force_coef_ltx_en_g4[ln]         = int_reg_force_lc_tx_cursor_coef_en_g4[ln] ;
        // G4:Remote
        assign cdm_ras_des_eq_force_coef_rtx_g4[18*ln +: 18]   = {int_reg_force_rm_tx_post_cursor_coef_g4[ln], int_reg_force_rm_tx_cursor_coef_g4[ln], int_reg_force_rm_tx_pre_cursor_coef_g4[ln]} ;
        assign cdm_ras_des_eq_force_coef_rtx_en_g4[ln]         = int_reg_force_rm_tx_cursor_coef_en_g4[ln] ;
        // G5:Local
        assign cdm_ras_des_eq_force_usp_pset_ltx_g5[4*ln +: 4] = int_reg_force_lc_tx_preset_g5[ln] ;
        assign cdm_ras_des_eq_force_pset_ltx_en_g5[ln]         = int_reg_force_lc_tx_preset_en_g5[ln] ;
        assign cdm_ras_des_eq_force_coef_ltx_g5[18*ln +: 18]   = {int_reg_force_lc_tx_post_cursor_coef_g5[ln], int_reg_force_lc_tx_cursor_coef_g5[ln], int_reg_force_lc_tx_pre_cursor_coef_g5[ln]} ;
        assign cdm_ras_des_eq_force_coef_ltx_en_g5[ln]         = int_reg_force_lc_tx_cursor_coef_en_g5[ln] ;
        // G5:Remote
        assign cdm_ras_des_eq_force_coef_rtx_g5[18*ln +: 18]   = {int_reg_force_rm_tx_post_cursor_coef_g5[ln], int_reg_force_rm_tx_cursor_coef_g5[ln], int_reg_force_rm_tx_pre_cursor_coef_g5[ln]} ;
        assign cdm_ras_des_eq_force_coef_rtx_en_g5[ln]         = int_reg_force_rm_tx_cursor_coef_en_g5[ln] ;
        // G6:Local
        assign cdm_ras_des_eq_force_usp_pset_ltx_g6[4*ln +: 4] = int_reg_force_lc_tx_preset_g6[ln] ;
        assign cdm_ras_des_eq_force_pset_ltx_en_g6[ln]         = int_reg_force_lc_tx_preset_en_g6[ln] ;
        assign cdm_ras_des_eq_force_coef_ltx_g6[18*ln +: 18]   = {int_reg_force_lc_tx_post_cursor_coef_g6[ln][4:0], int_reg_force_lc_tx_cursor_coef_g6[ln], int_reg_force_lc_tx_pre_cursor_coef_g6[ln][3:0], int_reg_force_lc_tx_2nd_pre_cursor_coef_g6[ln][2:0]} ;
        assign cdm_ras_des_eq_force_coef_ltx_en_g6[ln]         = int_reg_force_lc_tx_cursor_coef_en_g6[ln] ;
        // G6:Remote
        assign cdm_ras_des_eq_force_coef_rtx_g6[18*ln +: 18]   = {int_reg_force_rm_tx_post_cursor_coef_g6[ln][4:0], int_reg_force_rm_tx_cursor_coef_g6[ln], int_reg_force_rm_tx_pre_cursor_coef_g6[ln][3:0], int_reg_force_rm_tx_2nd_pre_cursor_coef_g6[ln][2:0]} ;
        assign cdm_ras_des_eq_force_coef_rtx_en_g6[ln]         = int_reg_force_rm_tx_cursor_coef_en_g6[ln] ;
    end
    endgenerate

    assign {int_reg_0xDB,int_reg_0xDA,int_reg_0xD9,int_reg_0xD8} = { 3'd0                                    // [31:29]
                                                                   , int_reg_force_rm_tx_cursor_coef_en      // [28]
                                                                   , 4'd0                                    // [27:24]
                                                                   , int_reg_force_rm_tx_2nd_pre_cursor_coef // [23:18]
                                                                   , int_reg_force_rm_tx_post_cursor_coef    // [17:12]
                                                                   , int_reg_force_rm_tx_cursor_coef         // [11:6]
                                                                   , int_reg_force_rm_tx_pre_cursor_coef     // [5:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 56
// PCIE Offset      - `RAS_DES_PTR + E0h
// length           - 4 byte
// Cfig register    - int_reg_0xE0, int_reg_0xE1, int_reg_0xE2, int_reg_0xE4
// register         - EQ_REMOTE_2ND_PRE_CURSOR [31:26] : RO
//                  - EQ_REJECT_EVENT [7] : RO
//                  - EQ_RULEC_VAIOLATION [6] : RO
//                  - EQ_RULEB_VAIOLATION [5] : RO
//                  - EQ_RULEA_VAIOLATION [4] : RO
//                  - EQ_RULED_VAIOLATION [3] : RO
//                  - EQ_CONVERGENCE_INFO [2:1] : RO
//                  - EQ_SEQUENCE [0] : RO
// -----------------------------------------------------------------------------
    reg    [5:0]                       int_reg_eq_rm_2nd_pre_cursor ; // EQ_REMOTE_2ND_PRE_CURSOR [5:0]
    reg                                int_reg_eq_reject_event ;      // EQ_REJECT_EVENT [7]
    reg                                int_reg_eq_rulec_vaiolation ;  // EQ_RULEC_VAIOLATION [6]
    reg                                int_reg_eq_ruleb_vaiolation ;  // EQ_RULEB_VAIOLATION [5]
    reg                                int_reg_eq_rulea_vaiolation ;  // EQ_RULEA_VAIOLATION [4]
    reg                                int_reg_eq_ruled_vaiolation ;  // EQ_RULED_VAIOLATION [3]
    reg    [1:0]                       int_reg_eq_convergence_info ;  // EQ_CONVERGENCE_INFO [2:1]
    reg                                int_reg_eq_sequence ;          // EQ_SEQUENCE [0]

    wire                               int_init_eq_pending;
    wire   [NL-1:0][2:0]               int_eqpa_violate_rule_123;
    wire   [NL-1:0]                    int_eqpa_violate_rule_4;
    wire   [NL-1:0][1:0]               int_eq_convergence_sts;
    wire   [NL-1:0]                    int_mac_cdm_ras_des_reject_rtx;
    wire   [NL-1:0][TX_COEF_WD-1:0]    int_mac_cdm_ras_des_coef_rtx;

    assign int_mac_cdm_ras_des_reject_rtx =
                                       (int_reg_eq_rate_sel == 2'd3) ? mac_cdm_ras_des_reject_rtx_g6 :
                                       (int_reg_eq_rate_sel == 2'd2) ? mac_cdm_ras_des_reject_rtx_g5 :
                                       (int_reg_eq_rate_sel == 2'd1) ? mac_cdm_ras_des_reject_rtx_g4 :
                                                                       mac_cdm_ras_des_reject_rtx ;
    assign int_eqpa_violate_rule_123 =
                                       (int_reg_eq_rate_sel == 2'd3) ? eqpa_violate_rule_123_g6 :
                                       (int_reg_eq_rate_sel == 2'd2) ? eqpa_violate_rule_123_g5 :
                                       (int_reg_eq_rate_sel == 2'd1) ? eqpa_violate_rule_123_g4 :
                                                                       eqpa_violate_rule_123 ;

    assign int_eqpa_violate_rule_4  = (int_reg_eq_rate_sel == 2'd3) ? eqpa_violate_rule_4_g6 : {NL{1'b0}};

    assign int_eq_convergence_sts    =
                                       (int_reg_eq_rate_sel == 2'd3) ? eq_convergence_sts_g6 :
                                       (int_reg_eq_rate_sel == 2'd2) ? eq_convergence_sts_g5 :
                                       (int_reg_eq_rate_sel == 2'd1) ? eq_convergence_sts_g4 :
                                                                       eq_convergence_sts ;
    assign int_init_eq_pending       =
                                       (int_reg_eq_rate_sel == 2'd3) ? init_eq_pending_g6 :
                                       (int_reg_eq_rate_sel == 2'd2) ? init_eq_pending_g5 :
                                       (int_reg_eq_rate_sel == 2'd1) ? init_eq_pending_g4 :
                                                                       init_eq_pending ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_56
        if (!sticky_rst_n) begin
            int_reg_eq_rm_2nd_pre_cursor <= #TP 6'd0;
            int_reg_eq_reject_event      <= #TP 1'd0 ;
            int_reg_eq_rulec_vaiolation  <= #TP 1'd0 ;
            int_reg_eq_ruleb_vaiolation  <= #TP 1'd0 ;
            int_reg_eq_rulea_vaiolation  <= #TP 1'd0 ;
            int_reg_eq_ruled_vaiolation  <= #TP 1'd0 ;
            int_reg_eq_convergence_info  <= #TP 2'd0 ;
            int_reg_eq_sequence          <= #TP 1'd0 ;
        end
        else begin
            if (int_reg_eq_lane_sel<NL) begin
                int_reg_eq_rm_2nd_pre_cursor <= #TP (int_reg_eq_rate_sel == 2'd3) ? {3'd0, int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][2:0]} : 6'd0;
                int_reg_eq_reject_event     <= #TP int_mac_cdm_ras_des_reject_rtx[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                int_reg_eq_rulec_vaiolation <= #TP int_eqpa_violate_rule_123[int_reg_eq_lane_sel[NL_WD-1:0]][2] ;
                int_reg_eq_ruleb_vaiolation <= #TP int_eqpa_violate_rule_123[int_reg_eq_lane_sel[NL_WD-1:0]][1] ;
                int_reg_eq_rulea_vaiolation <= #TP int_eqpa_violate_rule_123[int_reg_eq_lane_sel[NL_WD-1:0]][0] ;
                int_reg_eq_ruled_vaiolation <= #TP int_eqpa_violate_rule_4[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                int_reg_eq_convergence_info <= #TP int_eq_convergence_sts[int_reg_eq_lane_sel[NL_WD-1:0]][1:0] ;
                int_reg_eq_sequence         <= #TP int_init_eq_pending ;
            end
        end
    end

    assign {int_reg_0xE3,int_reg_0xE2,int_reg_0xE1,int_reg_0xE0} = { 
                                                                     int_reg_eq_rm_2nd_pre_cursor    // [31:26]
                                                                   , 18'd0                           // [25:8]
                                                                   , int_reg_eq_reject_event         // [7]
                                                                   , int_reg_eq_rulec_vaiolation     // [6]
                                                                   , int_reg_eq_ruleb_vaiolation     // [5]
                                                                   , int_reg_eq_rulea_vaiolation     // [4]
                                                                   , int_reg_eq_ruled_vaiolation     // [3]
                                                                   , int_reg_eq_convergence_info     // [2:1]
                                                                   , int_reg_eq_sequence             // [0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 57
// PCIE Offset      - `RAS_DES_PTR + E4h
// length           - 4 byte
// Cfig register    - int_reg_0xE4, int_reg_0xE5, int_reg_0xE6, int_reg_0xE7
// register         - EQ_LOCAL_FOM_VALUE [31:24] : RO
//                  - EQ_LOCAL_2ND_PRE_CURSOR [23:20] : RO
//                  - EQ_LOCAL_RX_HINT [20:18] or EQ_LOCAL_2ND_PRE_CURSOR [20:18] : RO
//                  - EQ_LOCAL_POST_CURSOR [17:12] : RO
//                  - EQ_LOCAL_CURSOR [11:6] : RO
//                  - EQ_LOCAL_PRE_CURSOR [5:0] : RO
// -----------------------------------------------------------------------------
    reg    [7:0]                        int_reg_eq_lc_fom_value ;                 // EQ_LOCAL_FOM_VALUE [31:24]
    reg    [2:0]                        int_reg_eq_lc_rx_hint_or_2nd_pre_cursor ; // EQ_LOCAL_RX_HINT [20:18] or EQ_LOCAL_2ND_PRE_CURSOR [20:18]
    reg    [5:0]                        int_reg_eq_lc_post_cursor ;               // EQ_LOCAL_POST_CURSOR [17:12]
    reg    [5:0]                        int_reg_eq_lc_cursor ;                    // EQ_LOCAL_CURSOR [11:6]
    reg    [5:0]                        int_reg_eq_lc_pre_cursor ;                // EQ_LOCAL_PRE_CURSOR [5:0]
    wire   [NL-1:0][FOMFEEDBACK_WD-1:0] int_phy_cdm_ras_des_fomfeedback;
    wire   [NL-1:0][RX_PSET_WD-1:0]     int_mac_cdm_ras_des_pset_lrx;
    wire   [NL-1:0][TX_COEF_WD-1:0]     int_mac_cdm_ras_des_coef_ltx;

    assign int_phy_cdm_ras_des_fomfeedback = 
                                        (int_reg_eq_rate_sel == 2'd3) ? phy_cdm_ras_des_fomfeedback_g6 :
                                        (int_reg_eq_rate_sel == 2'd2) ? phy_cdm_ras_des_fomfeedback_g5 :
                                        (int_reg_eq_rate_sel == 2'd1) ? phy_cdm_ras_des_fomfeedback_g4 :
                                                                        phy_cdm_ras_des_fomfeedback ;

    assign int_mac_cdm_ras_des_pset_lrx    = (int_reg_eq_rate_sel == 2'd0) ? mac_cdm_ras_des_pset_lrx :

                                                                             {NL*RX_PSET_WD{1'b0}} ;
    assign int_mac_cdm_ras_des_coef_ltx    = 
                                        (int_reg_eq_rate_sel == 2'd3) ? mac_cdm_ras_des_coef_ltx_g6 :
                                        (int_reg_eq_rate_sel == 2'd2) ? mac_cdm_ras_des_coef_ltx_g5 :
                                        (int_reg_eq_rate_sel == 2'd1) ? mac_cdm_ras_des_coef_ltx_g4 :
                                                                        mac_cdm_ras_des_coef_ltx ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_57
        if (!sticky_rst_n) begin
            int_reg_eq_lc_fom_value                 <= #TP 8'd0 ;
            int_reg_eq_lc_rx_hint_or_2nd_pre_cursor <= #TP 3'd0 ;
            int_reg_eq_lc_post_cursor               <= #TP 6'd0 ;
            int_reg_eq_lc_cursor                    <= #TP 6'd0 ;
            int_reg_eq_lc_pre_cursor                <= #TP 6'd0 ;
        end
        else begin
            if ( int_reg_eq_lane_sel<NL ) begin
                int_reg_eq_lc_fom_value                 <= #TP int_phy_cdm_ras_des_fomfeedback[int_reg_eq_lane_sel[NL_WD-1:0]] ;              
                int_reg_eq_lc_rx_hint_or_2nd_pre_cursor <= #TP (int_reg_eq_rate_sel == 2'd3) ? int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][2:0]           : int_mac_cdm_ras_des_pset_lrx[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                int_reg_eq_lc_post_cursor               <= #TP (int_reg_eq_rate_sel == 2'd3) ? {1'b0, int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][17:13]} : int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][17:12] ;
                int_reg_eq_lc_cursor                    <= #TP (int_reg_eq_rate_sel == 2'd3) ? int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][12:7]          : int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][11:6] ;
                int_reg_eq_lc_pre_cursor                <= #TP (int_reg_eq_rate_sel == 2'd3) ? {2'd0,int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][6:3]}    : int_mac_cdm_ras_des_coef_ltx[int_reg_eq_lane_sel[NL_WD-1:0]][5:0] ;
            end
        end
    end

    assign {int_reg_0xE7,int_reg_0xE6,int_reg_0xE5,int_reg_0xE4} = {
                                                                     int_reg_eq_lc_fom_value   // [31:24]
                                                                   , 3'd0                      // [23:21]
                                                                   , int_reg_eq_lc_rx_hint_or_2nd_pre_cursor     // [20:18]
                                                                   , int_reg_eq_lc_post_cursor // [17:12]
                                                                   , int_reg_eq_lc_cursor      // [11:6]
                                                                   , int_reg_eq_lc_pre_cursor  // [5:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 58
// PCIE Offset      - `RAS_DES_PTR + E8h
// length           - 4 byte
// Cfig register    - int_reg_0xE8, int_reg_0xE9, int_reg_0xEA, int_reg_0xEB
// register         - EQ_REMOTE_FS [29:24] : RO
//                  - EQ_REMOTE_LF [23:18] : RO
//                  - EQ_REMOTE_POST_CURSOR [17:12] : RO
//                  - EQ_REMOTE_CURSOR [11:6] : RO
//                  - EQ_REMOTE_PRE_CURSOR [5:0] : RO
// -----------------------------------------------------------------------------
    reg    [5:0]                       int_reg_eq_rm_fs ;          // EQ_REMOTE_FS [29:24]
    reg    [5:0]                       int_reg_eq_rm_lf ;          // EQ_REMOTE_LF [23:18]
    reg    [5:0]                       int_reg_eq_rm_post_cursor ; // EQ_REMOTE_POST_CURSOR [17:12]
    reg    [5:0]                       int_reg_eq_rm_cursor ;      // EQ_REMOTE_CURSOR [11:6]
    reg    [5:0]                       int_reg_eq_rm_pre_cursor ;  // EQ_REMOTE_PRE_CURSOR [5:0]

    wire   [NL-1:0][TX_FS_WD-1:0]           int_mac_cdm_ras_des_fs;
    wire   [NL-1:0][TX_FS_WD-1:0]           int_mac_cdm_ras_des_lf;

    assign int_mac_cdm_ras_des_fs       = 
                                      (int_reg_eq_rate_sel == 2'd3) ? mac_cdm_ras_des_fs_g6 :
                                      (int_reg_eq_rate_sel == 2'd2) ? mac_cdm_ras_des_fs_g5 :
                                      (int_reg_eq_rate_sel == 2'd1) ? mac_cdm_ras_des_fs_g4 :
                                                                      mac_cdm_ras_des_fs ;
    assign int_mac_cdm_ras_des_lf       = 
                                      (int_reg_eq_rate_sel == 2'd3) ? mac_cdm_ras_des_lf_g6 :
                                      (int_reg_eq_rate_sel == 2'd2) ? mac_cdm_ras_des_lf_g5 :
                                      (int_reg_eq_rate_sel == 2'd1) ? mac_cdm_ras_des_lf_g4 :
                                                                      mac_cdm_ras_des_lf ;
    assign int_mac_cdm_ras_des_coef_rtx = 
                                      (int_reg_eq_rate_sel == 2'd3) ? mac_cdm_ras_des_coef_rtx_g6 :
                                      (int_reg_eq_rate_sel == 2'd2) ? mac_cdm_ras_des_coef_rtx_g5 :
                                      (int_reg_eq_rate_sel == 2'd1) ? mac_cdm_ras_des_coef_rtx_g4 :
                                                                      mac_cdm_ras_des_coef_rtx ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin : gen_int_reg_58
        if (!sticky_rst_n) begin
            int_reg_eq_rm_fs          <= #TP 6'd0 ;
            int_reg_eq_rm_lf          <= #TP 6'd0 ;
            int_reg_eq_rm_post_cursor <= #TP 6'd0 ;
            int_reg_eq_rm_cursor      <= #TP 6'd0 ;
            int_reg_eq_rm_pre_cursor  <= #TP 6'd0 ;
        end
        else begin
            if (int_reg_eq_lane_sel<NL) begin
                int_reg_eq_rm_fs          <= #TP int_mac_cdm_ras_des_fs[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                int_reg_eq_rm_lf          <= #TP int_mac_cdm_ras_des_lf[int_reg_eq_lane_sel[NL_WD-1:0]] ;
                int_reg_eq_rm_post_cursor <= #TP (int_reg_eq_rate_sel == 2'd3) ? {1'b0, int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][17:13]} : int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][17:12] ;
                int_reg_eq_rm_cursor      <= #TP (int_reg_eq_rate_sel == 2'd3) ? int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][12:7]          : int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][11:6] ;
                int_reg_eq_rm_pre_cursor  <= #TP (int_reg_eq_rate_sel == 2'd3) ? {2'd0, int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][6:3]}   : int_mac_cdm_ras_des_coef_rtx[int_reg_eq_lane_sel[NL_WD-1:0]][5:0] ;
            end
        end
    end

    assign {int_reg_0xEB,int_reg_0xEA,int_reg_0xE9,int_reg_0xE8} = { 2'd0                       // [31:30]
                                                                   , int_reg_eq_rm_fs           // [29:24]
                                                                   , int_reg_eq_rm_lf           // [23:18]
                                                                   , int_reg_eq_rm_post_cursor  // [17:12]
                                                                   , int_reg_eq_rm_cursor       // [11:6]
                                                                   , int_reg_eq_rm_pre_cursor   // [5:0]
                                                                   } ;

// =============================================================================
// Register Read Operation
// =============================================================================
    wire                               resp_scheduled ;

// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: This signal is not used inside this module. This is the interface signal of this module. The sequential signal is unnecessary.
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_sd_ack <= #TP 2'b00 ;
        end
        else begin
            case ( cdm_sd_ack )
                2'b00 : begin
                    if ( resp_scheduled ) begin
                        cdm_sd_ack <= #TP 2'b01 ;
                    end
                end
                2'b01 : begin
                    cdm_sd_ack <= #TP 2'b10 ;
                end
                2'b10 : begin
                    cdm_sd_ack <= #TP 2'b00 ;
                end
                default : cdm_sd_ack <= #TP 2'b00 ;
            endcase
        end
    end
// spyglass enable_block STARC05-2.11.3.1

    assign resp_scheduled = |cdm_reg_id[63:40] ;

    always @(*) begin : read_data_PROC
        unique case (1'b1)
            cdm_reg_id[40] : cdm_sd_rdata = {int_reg_0xA3,int_reg_0xA2,int_reg_0xA1,int_reg_0xA0};
            cdm_reg_id[41] : cdm_sd_rdata = {int_reg_0xA7,int_reg_0xA6,int_reg_0xA5,int_reg_0xA4};
            cdm_reg_id[44] : cdm_sd_rdata = {int_reg_0xB3,int_reg_0xB2,int_reg_0xB1,int_reg_0xB0};
            cdm_reg_id[45] : cdm_sd_rdata = {int_reg_0xB7,int_reg_0xB6,int_reg_0xB5,int_reg_0xB4};
            cdm_reg_id[46] : cdm_sd_rdata = {int_reg_0xBB,int_reg_0xBA,int_reg_0xB9,int_reg_0xB8};
            cdm_reg_id[47] : cdm_sd_rdata = {int_reg_0xBF,int_reg_0xBE,int_reg_0xBD,int_reg_0xBC};
            cdm_reg_id[48] : cdm_sd_rdata = {int_reg_0xC3,int_reg_0xC2,int_reg_0xC1,int_reg_0xC0};
            cdm_reg_id[49] : cdm_sd_rdata = {int_reg_0xC7,int_reg_0xC6,int_reg_0xC5,int_reg_0xC4};
            cdm_reg_id[52] : cdm_sd_rdata = {int_reg_0xD3,int_reg_0xD2,int_reg_0xD1,int_reg_0xD0};
            cdm_reg_id[53] : cdm_sd_rdata = {int_reg_0xD7,int_reg_0xD6,int_reg_0xD5,int_reg_0xD4};
            cdm_reg_id[54] : cdm_sd_rdata = {int_reg_0xDB,int_reg_0xDA,int_reg_0xD9,int_reg_0xD8};
            cdm_reg_id[56] : cdm_sd_rdata = {int_reg_0xE3,int_reg_0xE2,int_reg_0xE1,int_reg_0xE0};
            cdm_reg_id[57] : cdm_sd_rdata = {int_reg_0xE7,int_reg_0xE6,int_reg_0xE5,int_reg_0xE4};
            cdm_reg_id[58] : cdm_sd_rdata = {int_reg_0xEB,int_reg_0xEA,int_reg_0xE9,int_reg_0xE8};
            default        : cdm_sd_rdata = `PCIE_UNUSED_RESPONSE;
        endcase
    end

`ifndef SYNTHESIS
//VCS coverage off
    wire  [8*64-1:0]  MFTLP_POINTER ;
    wire  [7:0]       dbg_mftlp_pointer ;
    assign dbg_mftlp_pointer = {1'b0, int_reg_mftlp_pointer} ;
    assign MFTLP_POINTER = dbg_mftlp_pointer==`MFPTR_ATOM_ADR  ? "AtomicOp address alignment" :
                           dbg_mftlp_pointer==`MFPTR_ATOM_OPR  ? "AtomicOp operand size" :
                           dbg_mftlp_pointer==`MFPTR_ATOM_BE   ? "AtomicOp  byte enable" :
                           dbg_mftlp_pointer==`MFPTR_TLP_DLEN  ? "TLP length miss match" :
                           //dbg_mftlp_pointer==`MFPTR_TLP_HLEN  ? "TLP length miss match" : // Merged to MFPTR_TLP_DLEN
                           dbg_mftlp_pointer==`MFPTR_TLP_MXPL  ? "TLP Max payload size" :
                           dbg_mftlp_pointer==`MFPTR_MSG_TC0   ? "Message TLP without TC0" :
                           dbg_mftlp_pointer==`MFPTR_TLP_TC    ? "Invalid TC" :
                           dbg_mftlp_pointer==`MFPTR_MSG_R     ? "Unexpected route bit in Message TLP" :
                           dbg_mftlp_pointer==`MFPTR_CPL_CRS   ? "Unexpected CRS status in Completion TLP" :
                           dbg_mftlp_pointer==`MFPTR_TLP_BE    ? "Byte enable rules" :
                           dbg_mftlp_pointer==`MFPTR_TLP_4KBND ? "Memory Address 4KB boundary" :
                           dbg_mftlp_pointer==`MFPTR_PFX       ? "TLP prefix rules" :
                           //dbg_mftlp_pointer==`MFPTR_TLP_ELEN  ? "TLP length miss match" : // Merged to MFPTR_TLP_DLEN
                           dbg_mftlp_pointer==`MFPTR_ATS       ? "Translation request rules" :
                           dbg_mftlp_pointer==`MFPTR_TLP_TYP   ? "Invalid TLP type" :
                           dbg_mftlp_pointer==`MFPTR_CPL       ? "Completion rules" :
                           dbg_mftlp_pointer[7:0]==`MFPTR_APL  ? "Errors detected in application" :
                           dbg_mftlp_pointer==`MFPTR_NO_ERR    ? "No errors" :
                                                                 "Reserved" ;

//VCS coverage on
`endif // SYNTHESIS

endmodule //cdm_rasdes_sd_reg 
