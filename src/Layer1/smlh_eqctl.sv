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
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_eqctl.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description: Equalization Controller for Gen3
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"


 module smlh_eqctl
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_ACT;
 import DWC_pcie_core_pkg::S_POLL_ACTIVE;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import DWC_pcie_core_pkg::S_DETECT_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_RCVRY_LOCK;
 import DWC_pcie_core_pkg::S_RCVRY_SPEED;
 import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
 import DWC_pcie_core_pkg::S_RCVRY_IDLE;
 import DWC_pcie_core_pkg::S_L0;
 import DWC_pcie_core_pkg::S_L0S;
 import DWC_pcie_core_pkg::S_L123_SEND_EIDLE;
 import DWC_pcie_core_pkg::S_L1_IDLE;
 import DWC_pcie_core_pkg::S_L2_IDLE;
 import DWC_pcie_core_pkg::S_L2_WAKE;
 import DWC_pcie_core_pkg::S_DISABLED_ENTRY;
 import DWC_pcie_core_pkg::S_DISABLED_IDLE;
 import DWC_pcie_core_pkg::S_DISABLED;
 import DWC_pcie_core_pkg::S_LPBK_ENTRY;
 import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
 import DWC_pcie_core_pkg::S_HOT_RESET_ENTRY;
 import DWC_pcie_core_pkg::S_HOT_RESET;
 import DWC_pcie_core_pkg::S_RCVRY_EQ0;
 import DWC_pcie_core_pkg::S_RCVRY_EQ1;
 import DWC_pcie_core_pkg::S_RCVRY_EQ2;
import DWC_pcie_core_pkg::S_RCVRY_EQ3;
#(
    parameter INST = 0, // The uniquifying parameter for each port logic instance
    parameter TP   = `TP,     // Clock to Q delay (simulator insurance)
    parameter NL = `CX_NL,
    // constants 
    parameter LTS_CMD_WD = 4, // total number of bits in ltssm command
    parameter EQTS_WD = 32, // total number of bits in ts carrying eq info, symbol 6-9 = 32 bits
    parameter TSFD_WD = `CX_TS_FIELD_CONTROL_WD, // Sym7,6,5,4,3,2,1
    parameter RX_PSET_WD = 3, 
    parameter TX_PSET_WD = 4, 
    parameter TX_FSLF_WD = 12,
    parameter TX_COEF_WD = 18,
    parameter TS_0_WD = 48,
    parameter SB_WD      = `CX_MAC_SB_WD, // Width of the start block
    parameter PCNT_WD = 4 // number of bits in the persistency count
)

                   (
    input                                core_clk,
    input                                core_rst_n,
    input                                cfg_upstream_port, // 1: DC - downstream component, 0: UC - upstream component
    input                                cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map, // send eieos continuously in Rcvry.RcvrLock for pset-coef mapping
    input                                cfg_gen3_lower_rate_eq_redo_enable, // allow lower rate change and eq redo
    input                                cfg_gen34_eq_phase23_rxeq_regardless_rxts, // 1 - eq master do adaptation/evaluation regardless of RX TS1s detected or not, 0 - legacy
    input                                cfg_block_local_detect_eq_problem,
    input [2:0]                          cfg_gen3_eq_req_num,
    input                                cfg_gen3_support_finite_eq_req,
    // smlh_seq_finder i/f
    input          [NL-1:0]              rxdata_dv, // rxdata valid, rpipe_aligned signal
    input          [(NL*SB_WD)-1:0]      rmlh_descrambled_eie_det, // a pulse of EIEOS detected
    input          [NL*EQTS_WD-1:0]      smlh_eqts_info,
    input          [NL-1:0]              smlh_ts0_rcvd_bus,
    input                                ltssm_dsp_g6_eq1_send_ec00,
    input          [NL-1:0]              smlh_ts1_rcvd_bus,
    input          [NL-1:0]              smlh_ts2_rcvd_bus,
    input          [NL*PCNT_WD-1:0]      smlh_ts_rcvd_s6s9_pcnt,
    input          [NL*TSFD_WD-1:0]      smlh_ts_info,
    // smlh_ltssm i/f
    input          ltssm_state_e         smlh_ltssm_state_wire, // ltssm state before FF for high fanout
    input                                ltssm_lpbk_master, //1 - loopback master, 0 - loopback slave during loopback
    input          ltssm_state_e         ltssm_state_last, // previous ltssm state
    input          [LTS_CMD_WD-1:0]      ltssm_cmd, // ltssm command
    input                                ltssm_cmd_send_eieos_for_pset_map, // ltssm cmd to send eieos continuously in Rcvry.RcvrLock for pset-coef mapping
    input                                ltssm_cmd_eqts, // ltssm command specifier, for eqTS1 and eqTS2 ordered sets @g12 rate
    input                                ltssm_cmd_8geqts, // sending 8GT EQ TS2 in Gen3 Speed
    input                                ltssm_cmd_eqredo, // sending TS1 with Equalization Redo(TS1 Symbol6[7]=1) in Gen3 Speed
    input                                smlh_link_up_falling_edge,
    input                                ltssm_cmd_16geqts, // sending 16GT EQ TS2 in Gen4 Speed
    input                                ltssm_noeq_nd,     // no eq needed
    input          [1:0]                 ltssm_cmd_eqts_gen12, // ltssm command specifier, for eqTS2 ordered sets @g12 rate to gen5 because of skip eq
    input                                ltssm_precode_request, // send the bit in EQ TS
    input                                ltssm_precoding_on,    // send the bit in TS for gen5 or higher rates
    input                                ltssm_cmd_32geqts, // sending 32GT EQ TS2 in Gen5 Speed
    input                                ltssm_captured_ts_data_rate_g6,
    input                                ltssm_perform_eq_for_lpbk,
    input          [2:0]                 ltssm_current_data_rate,
    input                                ltssm_captured_ts_data_rate_g3,
    input                                ltssm_captured_ts_data_rate_g5,
    input                                mac_phy_txswing, // transmitter swing
    input          [3:0]                 ltssm_start_equalization, // bit 0: start_equalization_w_preset variable in spec, bit 1-3 to direct equalization to a non-0 phase from RcvrLock
    input          [NL-1:0]              ltssm_lanes_active, // variable in spec
    input                                ltssm_quie_gua, // quiesce guarantee from upper layers, it means there are no transactions in flight
    input          [3:0]                 ltssm_gen3_compliance_tx_pset, //Compliance Tx preset due to EnterCompliance bit set or cycle
    input                                ltssm_gen3_compliance_tx_pset_v, //Tx preset from ltssm is valid
    input                                ltssm_clear, // active on the first cycle following ltssm state change
    input                                auto_eq_phase_flag, // Autonomous Equalization Phase
    input                                soft_eq_phase_flag, // Software Equalization Phase
    input                                redo_eq_phase_flag, // Redo Equalization Phase triggered by SW(Perform EQ register)
    input          [4:0]                 ltssm_ts_data_rate,
    // cdm i/f
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    input          [3:0]                 cfg_target_link_speed, // "Target Link Speed" field from the "Link Control Register 2" bits 3:0
    input          [9:0]                 ltssm_ts_data_rate_eg6,
    input          [9:0]                 latched_ts_data_rate_eg6,
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_pset_ltx, // UC only - Local Transmitter Preset
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_g4_pset_ltx, // UC only - Local Transmitter Preset
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_g4_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_g4_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_g4_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_g5_pset_ltx, // UC only - Local Transmitter Preset
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_g5_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_g5_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_g5_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_g6_pset_ltx, // UC only - Local Transmitter Preset
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_g6_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [NL*TX_PSET_WD-1:0]   cfg_lec_g6_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [NL*RX_PSET_WD-1:0]   cfg_lec_g6_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input                                cfg_gen3_eq_disable, // disable EQ - when disabled eqts_info is set to match normal TS1/TS2 Gen1/2 format
    input                                cfg_gen3_eq_req_disable, // disable autonomous request for redoing equalization
    input                                cfg_gen3_req_rst_eiec_disable, // disable requesting reset of EIEOS count during equalization
    input                                cfg_ls2_eq_req, // www: unused 
    input                                cfg_gen3_eq_p23_exit_mode, //after 24ms timeout for EQ master, 0-Rcvry.Speed, 1-EQ3 for USP or Rcvry.Lock for DSP
    input                                cfg_gen4_eq_p23_exit_mode, //after 24ms timeout for EQ master, 0-Rcvry.Speed, 1-EQ3 for USP or Rcvry.Lock for DSP
    input                                cfg_gen5_eq_p23_exit_mode, //after 24ms timeout for EQ master, 0-Rcvry.Speed, 1-EQ3 for USP or Rcvry.Lock for DSP
    input                                cfg_gen6_eq_p23_exit_mode, //after 24ms timeout for EQ master, 0-Rcvry.Speed, 1-EQ3 for USP or Rcvry.Lock for DSP
    input          [NL-1:0]              cdm_ras_des_eq_force_pset_ltx_en,  // force upstream port's tx preset enable
    input          [NL*TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input          [NL-1:0]              cdm_ras_des_eq_force_pset_ltx_en_g4,  // force upstream port's tx preset enable (gen4)
    input          [NL*TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx_g4, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control (gen4)
    input          [NL-1:0]              cdm_ras_des_eq_force_pset_ltx_en_g5,  // force upstream port's tx preset enable (gen5)
    input          [NL*TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx_g5, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control (gen5)
    input          [NL-1:0]              cdm_ras_des_eq_force_pset_ltx_en_g6,  // force upstream port's tx preset enable (gen5)
    input          [NL*TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx_g6, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control (gen5)
    // ltssm i/f
    output                               eqctl_8eqts1_rcvd,  // all active lanes received 8 consecutive eqTS1 @G12 rate
    output                               eqctl_8eqts2_rcvd,  // all active lanes received 8 consecutive eqTS2 @G12 rate
    output                               eqctl_any_8eqts1_rcvd, // any active lane received 8 consecutive eqTS1 @G12 rate
    output                               eqctl_any_8eqts2_rcvd, // any active lane received 8 consecutive eqTS2 @G12 rate
    output                               ltssm_state_equalization_any_exit, // ltssm exits EQ
    output                               eqctl_8g4eqts1_rcvd, // all active lanes received 8 consecutive TS1 with eq_redo @G3 rate
    output                               eqctl_8g4eqts2_rcvd, // all active lanes received 8 consecutive 8GT eqTS2 @G3 rate
    output                               eqctl_any_8g4eqts1_rcvd, // any active lane received 8 consecutive TS1 with eq_redo @G3 rate
    output                               eqctl_any_8g4eqts2_rcvd, // any active lane received 8 consecutive 8GT eqTS2 @G3 rate
    output                               eqctl_2ects1_retimer_eq_ext0_rcvd, // all active lane received 2 consecutive TS1 with Retimer EQ Extend=1
    output                               eqctl_8g5eqts1_rcvd, // all active lanes received 8 consecutive TS1 with eq_redo @G4 rate
    output                               eqctl_8g5eqts2_rcvd, // all active lanes received 8 consecutive 8GT eqTS2 @G4 rate
    output                               eqctl_any_8g5eqts1_rcvd, // any active lane received 8 consecutive TS1 with eq_redo @G4 rate
    output                               eqctl_any_8g5eqts2_rcvd, // any active lane received 8 consecutive 8GT eqTS2 @G4 rate
    output                               eqctl_8g6eqts1_rcvd, // all active lanes received 8 consecutive TS1 with eq_redo @G4 rate
    output                               eqctl_8g6eqts2_rcvd, // all active lanes received 8 consecutive 8GT eqTS2 @G4 rate
    output                               eqctl_any_8g6eqts1_rcvd, // any active lane received 8 consecutive TS1 with eq_redo @G4 rate
    output                               eqctl_any_8g6eqts2_rcvd, // any active lane received 8 consecutive 32GT eqTS2 @G4 rate
    output                               eqctl_precode6_request, // de-precode on in Rx
    output reg                           eqctl_g6_tx_ts0,        // send ts0s
    output                               eqctl_precode_request, // de-precode on in Rx
    output         [3:0]                 eqctl_2ects1_rcvd,  // bit i = 1: all active lanes received 2 consecutive ecTS1 @G3 rate with EC=i
    output         [3:0]                 eqctl_8ects1_rcvd,  // bit i = 1: all active lanes received 8 consecutive ecTS1 @G3 rate with EC=i
    output                               eqctl_ftune_rtx_done, // asserted to ltssm to move Phase 2 to Phase 3  (DC) or Phase 3 to RcvrLock (UC)
    output                               eqctl_eq_req_ltx, // instruct the ltssm that there is a pending (local) request for redoing equalization, 
                                                           // when L0 is entered with this flag set ltssm will handle it as a "pseudo" L0 where TX transactions are blocked
    output                               eqctl_eq_req_rtx, // instruct the ltssm that there is a pending (remote) request for redoing equalization, 
                                                           // when L0 is entered with this flag set ltssm will handle it as a "pseudo" L0 where TX transactions are blocked and L0 is exited for retraining
    output                               eqctl_eq_done_wo_err, //  For Downstream Port signal. indicate eq is done without error.
    output                               eqctl_eq_done_w_err, //  For Downstream Port signal. indicate eq is done with error.
    output reg                           eqctl_link_retrain, // instruct the ltssm to do link retrain as a result of equalization problems detected during normal operation
    output reg                           eqctl_link_retrain_g4, // instruct the ltssm to do link retrain as a result of equalization problems detected during normal operation
    output reg                           eqctl_link_retrain_g5, // instruct the ltssm to do link retrain as a result of equalization problems detected during normal operation
    output reg                           eqctl_link_retrain_g6, // instruct the ltssm to do link retrain as a result of equalization problems detected during normal operation
    // xmlh_byte_xmt i/f
    output         [NL*EQTS_WD-1:0]      eqctl_eqts_info, // concatenation of {s9, s8, s7, s6} for tx TS
    output         [NL*TS_0_WD-1:0]      eqctl_eqts_info_ts0, // concatenation of {s6, s5, s4, s3, s2, s1} for tx TS0
    output         [NL-1:0]              eqctl_mask_eieos, // indication to mask EIEOS as a result of receiving TS1s with a request to reset EIEOS count
    output         [NL-1:0]              eqctl_2mask_eieos_pulse, // 2 consecutive EC TS1 rcvd pulse with a request to reset EIEOS count
    // cdm i/f
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output         [NL*TX_PSET_WD-1:0]   sta_lec_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output         [NL*RX_PSET_WD-1:0]   sta_lec_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // ls2: Link Status 2 Register (PCIe cap.)
    output                               set_ls2_eq_req,
    output reg     [3:1]                 sta_ls2_eq_success,
    output reg                           sta_ls2_eq_cmpl,
    output                               sta_ls2_eq_enter, // enter Recovery.Equalization state
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output         [NL*TX_PSET_WD-1:0]   sta_lec_g4_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output         [NL*RX_PSET_WD-1:0]   sta_lec_g4_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // ls2: Link Status 2 Register (PCIe cap.)
    output                               set_ls2_g4_eq_req,
    output reg     [3:1]                 sta_ls2_g4_eq_success,
    output reg                           sta_ls2_g4_eq_cmpl,
    output                               sta_ls2_g4_eq_enter, // enter Recovery.Equalization state
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output         [NL*TX_PSET_WD-1:0]   sta_lec_g5_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output         [NL*RX_PSET_WD-1:0]   sta_lec_g5_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // ls2: Link Status 2 Register (PCIe cap.)
    output                               set_ls2_g5_eq_req,
    output reg     [3:1]                 sta_ls2_g5_eq_success,
    output reg                           sta_ls2_g5_eq_cmpl,
    output                               sta_ls2_g5_eq_enter, // enter Recovery.Equalization state
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output         [NL*TX_PSET_WD-1:0]   sta_lec_g6_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output         [NL*RX_PSET_WD-1:0]   sta_lec_g6_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // ls2: Link Status 2 Register (PCIe cap.)
    output                               set_ls2_g6_eq_req,
    output reg     [3:1]                 sta_ls2_g6_eq_success,
    output reg                           sta_ls2_g6_eq_cmpl,
    output                               sta_ls2_g6_eq_enter, // enter Recovery.Equalization state

    input                                eqpa_ftune_rtx_optimal, //reach optimal settings for EQ master
    input                                eqpa_timeout_1us_after_request, //timeout_1us after eq request from master
    input                                eqpa_fom_rxeq_redardless_rxts, //doing FOM for regardless Rx TS1s
    input                                eqpa_wait_rei_state, // any active lane in eqpa is in S_WAIT_REI state
    input          [NL-1:0]              mac_phy_rxeqeval, // tell PHY to do evaluation
    input          [NL-1:0]              phy_mac_eq_req,
    input          [NL*TX_FSLF_WD-1:0]   phy_mac_fslf_ltx,
    input          [NL*TX_COEF_WD-1:0]   phy_mac_coef_ltx,
    input          [NL-1:0]              phy_mac_reject_ltx,
    input          [NL-1:0]              phy_mac_accept_ltx,
    input          [NL*TX_PSET_WD-1:0]   phy_mac_pset_rtx,
    input          [NL*TX_COEF_WD-1:0]   phy_mac_coef_rtx,
    input          [NL-1:0]              phy_mac_ftune_rtx_done,
    input          [NL-1:0]              phy_mac_fslf_ltx_valid,
    input          [NL-1:0]              phy_mac_pset_rtx_upd,
    input          [NL-1:0]              phy_mac_coef_rtx_upd,
    input          [NL-1:0]              phy_mac_ftune_rtx_optimal,
    output         [NL*TX_PSET_WD-1:0]   mac_phy_pset_ltx,
    output         [NL*RX_PSET_WD-1:0]   mac_phy_pset_lrx,
    output         [NL*TX_COEF_WD-1:0]   mac_phy_coef_ltx,
    output         [NL*TX_FSLF_WD-1:0]   mac_phy_fslf_rtx,
    output         [NL*TX_PSET_WD-1:0]   mac_phy_pset_rtx,
    output         [NL*TX_COEF_WD-1:0]   mac_phy_coef_rtx,
    output         [NL-1:0]              mac_phy_reject_rtx,
    output         [NL-1:0]              mac_phy_accept_rtx,
    output         [NL-1:0]              mac_phy_timeout_rtx,
    output                               mac_phy_ftune_rtx,
    output                               mac_phy_ftune_ltx,
    output         [NL-1:0]              mac_phy_lpbk_ftune_ltx,
    output         [NL-1:0]              mac_phy_use_pset,
    output         [NL-1:0]              mac_phy_fslf_rtx_valid,
    output         [NL-1:0]              mac_phy_pset_ltx_upd,
    output         [NL-1:0]              mac_phy_coef_ltx_upd
);

ltssm_state_e   ltssm_state ;
wire            upstream_component;
wire            ltssm_current_data_rate_g12;
reg  [2:0]      ltssm_current_data_rate_d;
wire            ltssm_current_data_rate_g12_pulse;
reg             ltssm_current_data_rate_g12_d;
wire            ltssm_current_data_rate_g3;
wire            ltssm_current_data_rate_g3_pulse;
reg             ltssm_current_data_rate_g3_d;
wire            ltssm_current_data_rate_g4;
wire            ltssm_current_data_rate_g4_pulse;
reg             ltssm_current_data_rate_g4_d;
wire            ltssm_current_data_rate_g5;
wire            ltssm_current_data_rate_g5_pulse;
reg             ltssm_current_data_rate_g5_d;
wire            ltssm_current_data_rate_g6;
wire            ltssm_current_data_rate_g6_pulse;
reg             ltssm_current_data_rate_g6_d;
wire [3:0]      ltssm_state_equalization;
wire [3:0]      ltssm_state_equalization_enter;
wire [3:0]      ltssm_state_equalization_exit;
reg  [3:0]      ltssm_state_equalization_d;
wire            ltssm_state_equalization_any;
reg             ltssm_state_equalization_any_d;
wire            ltssm_state_equalization_any_enter;
reg             txts_eq_req_d;
reg  [2:0]      eq_req_num;
wire            eq_req_num_is_cdm_settings;
//wire            ltssm_state_equalization_any_exit;
wire            ltssm_state_rcvrlock;
wire            ltssm_state_rcvrcfg;
wire            ltssm_state_rcvridle;
wire            ltssm_state_rcvrspd;
wire            ltssm_state_compliance;
wire            ltssm_state_pollactive;
wire            ltssm_state_lpbkentry;
wire            ltssm_state_lpbkact;
wire            ltssm_state_cfglwstart;
wire [3:0]      ltssm_state_last_equalization;
wire            ltssm_state_last_equalization_any;
wire            ltssm_state_detect;
wire            ltssm_state_disable;
wire            ltssm_state_hotreset;
wire            ltssm_state_l0;
wire            ltssm_state_l0s;
wire            ltssm_state_l123;
wire            ltssm_state_l1;
wire            ltssm_state_l2;
wire            ltssm_cmd_ts1;
wire            ltssm_cmd_ts2;
wire [NL-1:0]   eqctl_8eqts1_rcvd_bus;
wire [NL-1:0]   eqctl_8eqts2_rcvd_bus;
wire [NL-1:0]   eqctl_8g4eqts1_rcvd_bus;
wire [NL-1:0]   eqctl_8g4eqts2_rcvd_bus;
wire [NL-1:0]   eqctl_8g5eqts1_rcvd_bus;
wire [NL-1:0]   eqctl_8g5eqts2_rcvd_bus;
wire [NL-1:0]   eqctl_precode_request_bus;
wire [NL-1:0]   eqctl_8g6eqts1_rcvd_bus;
wire [NL-1:0]   eqctl_8g6eqts2_rcvd_bus;
wire [NL-1:0]   eqctl_precode6_request_bus;
wire [NL*4-1:0] eqctl_2ects1_rcvd_bus;
wire [NL*4-1:0] eqctl_8ects1_rcvd_bus;
wire [NL-1:0]   eqctl_8eqrts2_rcvd_g3_bus;
wire [NL-1:0]   eqctl_8eqrgts2_rcvd_g3_bus;
wire [NL-1:0]   eqctl_8eqrts2_rcvd_g4_bus;
wire [NL-1:0]   eqctl_8eqrgts2_rcvd_g4_bus;
wire [NL-1:0]   eqctl_2ects1_retimer_eq_ext0_rcvd_bus;
wire [NL-1:0]   eqctl_8eqrts2_rcvd_g5_bus;
wire [NL-1:0]   eqctl_8eqrgts2_rcvd_g5_bus;
wire [NL-1:0]   eqctl_8eqrts2_rcvd_g6_bus;
wire [NL-1:0]   eqctl_8eqrgts2_rcvd_g6_bus;
wire            eqctl_8eqrts2_rcvd_g3;  // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=0 @G3 or G4 rate
wire            eqctl_8eqrgts2_rcvd_g3; // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=0 @G3 or G4 rate
wire            eqctl_8eqrts2_rcvd_g4;  // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=1 @G3 or G4 rate
wire            eqctl_8eqrgts2_rcvd_g4; // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=1 @G3 or G4 rate
wire            eqctl_8eqrts2_rcvd_g5;  // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=1 @G3 or G4 rate
wire            eqctl_8eqrgts2_rcvd_g5; // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=1 @G3 or G4 rate
wire            eqctl_8eqrts2_rcvd_g6;  // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=1 @G3 or G4 rate
wire            eqctl_8eqrgts2_rcvd_g6; // Any active lanes received 8 consecutive Eq.Request TS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=1 @G3 or G4 rate
reg  [NL-1:0]   current_eqctl_2ec0ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_2ec0ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_2ec0ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_2ec1ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_2ec1ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_2ec1ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_2ec2ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_2ec2ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_2ec2ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_2ec3ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_2ec3ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_2ec3ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_8ec0ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_8ec0ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_8ec0ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_8ec1ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_8ec1ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_8ec1ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_8ec2ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_8ec2ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_8ec2ts1_rcvd_bus;
reg  [NL-1:0]   current_eqctl_8ec3ts1_rcvd_bus;
reg  [NL-1:0]   latched_eqctl_8ec3ts1_rcvd_bus;
reg  [NL-1:0]   eqctl_8ec3ts1_rcvd_bus;
wire [NL-1:0]   mac_phy_ftune_rtx_bus;
wire [NL-1:0]   mac_phy_ftune_ltx_bus;
wire [NL-1:0]   eqctl_ftune_rtx_done_bus;
reg  [21:0]     timer_131us;
wire            tick_131us;
wire            txts_eq_req;
wire            txts_eq_req_i;
wire            txts_quie_gua;
wire            txts_eq_req_data_rate;
wire [NL-1:0]   rxts_eq_mismatch;
wire            sta_ls2_eq_phase23_success;
wire            req_rst_eiec_enable;
wire            fom_gen34_eq_phase23_rxeq_regardless_rxts;
reg  [NL-1:0]   g34_rxvalid_follow_eieos_d;
wire [NL-1:0]   g34_rxvalid_follow_eieos;

// Pipe-line of ltssm_state for high fanout. 
// The smlh_ltssm_state_wire is a combinational signal(before FF). So, no timing change by this pipe-line.
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_state_proc
    if (!core_rst_n) begin
        ltssm_state <= #TP S_DETECT_QUIET;
    end
    else begin
        ltssm_state <= #TP smlh_ltssm_state_wire;
    end
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// generic decodes
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign fom_gen34_eq_phase23_rxeq_regardless_rxts = cfg_gen34_eq_phase23_rxeq_regardless_rxts & eqpa_fom_rxeq_redardless_rxts;
assign upstream_component = ~cfg_upstream_port;

// align with data width
reg [NL-1:0] int_rmlh_descrambled_eie_det;
always @* begin : eie_align_data_width_PROC
    integer i;
    int_rmlh_descrambled_eie_det = 0;

    for (i=0; i<NL; i=i+1) begin
      int_rmlh_descrambled_eie_det[i] = |rmlh_descrambled_eie_det[i*SB_WD +: SB_WD];
    end // for
end // eie_align_data_width_PROC

always @(posedge core_clk or negedge core_rst_n) begin : g34_rxvalid_follow_eieos_d_PROC
    integer i;
    
    if (~core_rst_n) begin
        g34_rxvalid_follow_eieos_d <= #TP '0;
    end else begin
        for (i=0; i<NL; i=i+1) begin
            if ( rxdata_dv[i] == 0 )
                g34_rxvalid_follow_eieos_d[i] <= #TP '0;
            else if ( int_rmlh_descrambled_eie_det[i] )
                g34_rxvalid_follow_eieos_d[i] <= #TP 1;
        end // for
    end
end // g34_rxvalid_follow_eieos_d_PROC
    
assign g34_rxvalid_follow_eieos = rxdata_dv & (g34_rxvalid_follow_eieos_d | int_rmlh_descrambled_eie_det);

assign req_rst_eiec_enable = ~cfg_gen3_req_rst_eiec_disable & (
 fom_gen34_eq_phase23_rxeq_regardless_rxts ? |(mac_phy_rxeqeval & ltssm_lanes_active) : // if any RxEqEval, set REI for regardless_rxts
                              (&(g34_rxvalid_follow_eieos | ~ltssm_lanes_active)) ); // all (RxValid & RX EIEOS in the core), set REI for legacy (~regardless_rxts)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ltssm decodes
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_current_data_rate_d_PROC
    if ( ~core_rst_n )
        ltssm_current_data_rate_d <= #TP '0;
    else
        ltssm_current_data_rate_d <= #TP ltssm_current_data_rate;
end // ltssm_current_data_rate_d_PROC
wire   ltssm_current_data_rate_diff_pulse = ltssm_current_data_rate != ltssm_current_data_rate_d;
assign ltssm_current_data_rate_g12 = ( ltssm_current_data_rate == `GEN1_RATE || ltssm_current_data_rate == `GEN2_RATE );
assign ltssm_current_data_rate_g3 = ( ltssm_current_data_rate == `GEN3_RATE );
assign ltssm_current_data_rate_g4 = ( ltssm_current_data_rate == `GEN4_RATE );
assign ltssm_current_data_rate_g5 = ( ltssm_current_data_rate == `GEN5_RATE );
assign ltssm_current_data_rate_g6 = ( ltssm_current_data_rate == `GEN6_RATE );
assign ltssm_state_equalization[3:0] = {(ltssm_state==S_RCVRY_EQ3), (ltssm_state==S_RCVRY_EQ2), (ltssm_state==S_RCVRY_EQ1), (ltssm_state==S_RCVRY_EQ0)};
assign ltssm_state_equalization_any = |ltssm_state_equalization;
assign ltssm_state_last_equalization[3:0] = {(ltssm_state_last==S_RCVRY_EQ3), (ltssm_state_last==S_RCVRY_EQ2), (ltssm_state_last==S_RCVRY_EQ1), (ltssm_state_last==S_RCVRY_EQ0)};
assign ltssm_state_last_equalization_any = |ltssm_state_last_equalization;

assign ltssm_state_rcvrlock = (ltssm_state==S_RCVRY_LOCK);
assign ltssm_state_rcvrcfg = (ltssm_state==S_RCVRY_RCVRCFG);
assign ltssm_state_rcvridle = (ltssm_state==S_RCVRY_IDLE);
assign ltssm_state_rcvrspd = (ltssm_state==S_RCVRY_SPEED);
assign ltssm_state_compliance = (ltssm_state==S_POLL_COMPLIANCE);
assign ltssm_state_pollactive = (ltssm_state==S_POLL_ACTIVE);
assign ltssm_state_lpbkentry = (ltssm_state==S_LPBK_ENTRY);
assign ltssm_state_lpbkact = (ltssm_state==S_LPBK_ACTIVE);
assign ltssm_state_cfglwstart = (ltssm_state==S_CFG_LINKWD_START);

assign ltssm_state_detect = (ltssm_state==S_DETECT_QUIET) || (ltssm_state == S_DETECT_ACT) || (ltssm_state == S_DETECT_WAIT);
assign ltssm_state_disable = (ltssm_state == S_DISABLED_ENTRY) || (ltssm_state == S_DISABLED_IDLE) || (ltssm_state == S_DISABLED);
assign ltssm_state_hotreset = (ltssm_state == S_HOT_RESET_ENTRY) || (ltssm_state == S_HOT_RESET);
assign ltssm_state_l0 =    (ltssm_state== S_L0);
assign ltssm_state_l0s = (ltssm_state==S_L0S);
assign ltssm_state_l123 = (ltssm_state==S_L123_SEND_EIDLE);
assign ltssm_state_l1 = (ltssm_state==S_L1_IDLE) ;
assign ltssm_state_l2 =(ltssm_state==S_L2_IDLE) || (ltssm_state== S_L2_WAKE) ;

always @(posedge core_clk or negedge core_rst_n) begin : ltssm_state_equalization_any_seq_PROC
    if( !core_rst_n ) begin
        ltssm_state_equalization_d     <= #TP '0;
        ltssm_state_equalization_any_d <= #TP '0;
    end else begin
        ltssm_state_equalization_d     <= #TP ltssm_state_equalization;
        ltssm_state_equalization_any_d <= #TP ltssm_state_equalization_any;
    end
end

assign ltssm_state_equalization_any_enter = ltssm_state_equalization_any & ~ltssm_state_equalization_any_d;
assign ltssm_state_equalization_any_exit = ltssm_state_equalization_any_d & ~ltssm_state_equalization_any;
assign ltssm_state_equalization_exit = ltssm_state_equalization_d & ~ltssm_state_equalization;
assign ltssm_state_equalization_enter = ~ltssm_state_equalization_d & ltssm_state_equalization;

// base spec says: The number of back-to-back equalization redos at a given data rate is implementation specific but must be finite.
//                 if not the given data rate, must clear the number
always @(posedge core_clk or negedge core_rst_n) begin : txts_eq_req_d_PROC
    if ( ~core_rst_n )
        txts_eq_req_d <= #TP '0;
    else
        txts_eq_req_d <= #TP txts_eq_req_i;
end // txts_eq_req_d_PROC

always @(posedge core_clk or negedge core_rst_n) begin : eq_req_num_PROC
    if ( ~core_rst_n )
        eq_req_num <= #TP '0;
    else if ( ltssm_state_rcvrspd && ltssm_current_data_rate_diff_pulse ) // if change speed, the eq_req is not in the same rate or not back-to-back, have to clear it
        eq_req_num <= #TP '0;
    else if ( eq_req_num >= cfg_gen3_eq_req_num )
        eq_req_num <= #TP eq_req_num;
    else if ( ~txts_eq_req_i && txts_eq_req_d ) // falling edge pulse
        eq_req_num <= #TP eq_req_num + 1'b1;
end // eq_req_num_PROC

assign eq_req_num_is_cdm_settings = (eq_req_num >= cfg_gen3_eq_req_num);

// detect a data rate change to G12
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_current_data_rate_g12_d_seq_PROC
    if( !core_rst_n ) begin
        ltssm_current_data_rate_g12_d <= #TP '0;
    end else begin
        ltssm_current_data_rate_g12_d <= #TP ltssm_current_data_rate_g12;
    end
end

assign ltssm_current_data_rate_g12_pulse = (ltssm_current_data_rate_g12 && !ltssm_current_data_rate_g12_d);

// detect a data rate change to G3
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_current_data_rate_g3_d_seq_PROC
    if( !core_rst_n ) begin
        ltssm_current_data_rate_g3_d <= #TP '0;
    end else begin
        ltssm_current_data_rate_g3_d <= #TP ltssm_current_data_rate_g3;
    end
end

assign ltssm_current_data_rate_g3_pulse = (ltssm_current_data_rate_g3 && !ltssm_current_data_rate_g3_d);

// detect a data rate change to G4
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_current_data_rate_g4_d_seq_PROC
    if( !core_rst_n ) begin
        ltssm_current_data_rate_g4_d <= #TP '0;
    end else begin
        ltssm_current_data_rate_g4_d <= #TP ltssm_current_data_rate_g4;
    end
end

assign ltssm_current_data_rate_g4_pulse = (ltssm_current_data_rate_g4 && !ltssm_current_data_rate_g4_d);
// detect a data rate change to G4
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_current_data_rate_g5_d_seq_PROC
    if( !core_rst_n ) begin
        ltssm_current_data_rate_g5_d <= #TP '0;
    end else begin
        ltssm_current_data_rate_g5_d <= #TP ltssm_current_data_rate_g5;
    end
end

assign ltssm_current_data_rate_g5_pulse = (ltssm_current_data_rate_g5 && !ltssm_current_data_rate_g5_d);
// detect a data rate change to G6
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_current_data_rate_g6_d_seq_PROC
    if( !core_rst_n ) begin
        ltssm_current_data_rate_g6_d <= #TP '0;
    end else begin
        ltssm_current_data_rate_g6_d <= #TP ltssm_current_data_rate_g6;
    end
end

assign ltssm_current_data_rate_g6_pulse = (ltssm_current_data_rate_g6 && !ltssm_current_data_rate_g6_d);

assign ltssm_cmd_ts1 = (ltssm_cmd == `SEND_TS1);
assign ltssm_cmd_ts2 = (ltssm_cmd == `SEND_TS2);
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// eqctl_*_rcvd bus
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(*) begin : current_eqctl_ects1_rcvd_bus_PROC
    integer i;
    for(i=0; i<NL; i=i+1) begin
        current_eqctl_2ec0ts1_rcvd_bus[i] = eqctl_2ects1_rcvd_bus[4*i+0];
        current_eqctl_2ec1ts1_rcvd_bus[i] = eqctl_2ects1_rcvd_bus[4*i+1];
        current_eqctl_2ec2ts1_rcvd_bus[i] = eqctl_2ects1_rcvd_bus[4*i+2];
        current_eqctl_2ec3ts1_rcvd_bus[i] = eqctl_2ects1_rcvd_bus[4*i+3];
        current_eqctl_8ec0ts1_rcvd_bus[i] = eqctl_8ects1_rcvd_bus[4*i+0] & (ltssm_state != S_RCVRY_EQ0);
        current_eqctl_8ec1ts1_rcvd_bus[i] = eqctl_8ects1_rcvd_bus[4*i+1];
        current_eqctl_8ec2ts1_rcvd_bus[i] = eqctl_8ects1_rcvd_bus[4*i+2];
        current_eqctl_8ec3ts1_rcvd_bus[i] = eqctl_8ects1_rcvd_bus[4*i+3];
    end
end // current_eqctl_ects1_rcvd_bus_PROC

always @(posedge core_clk or negedge core_rst_n) begin : latched_eqctl_2ects1_rcvd_bus_PROC
    integer i;
    if ( ~core_rst_n ) begin
        latched_eqctl_2ec0ts1_rcvd_bus <= #TP '0;
        latched_eqctl_2ec1ts1_rcvd_bus <= #TP '0;
        latched_eqctl_2ec2ts1_rcvd_bus <= #TP '0;
        latched_eqctl_2ec3ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec0ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec1ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec2ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec3ts1_rcvd_bus <= #TP '0;
    end else if ( ltssm_clear ) begin
        latched_eqctl_2ec0ts1_rcvd_bus <= #TP '0;
        latched_eqctl_2ec1ts1_rcvd_bus <= #TP '0;
        latched_eqctl_2ec2ts1_rcvd_bus <= #TP '0;
        latched_eqctl_2ec3ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec0ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec1ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec2ts1_rcvd_bus <= #TP '0;
        latched_eqctl_8ec3ts1_rcvd_bus <= #TP '0;
    end else begin
        for (i=0; i<NL; i=i+1) begin
            if ( current_eqctl_2ec0ts1_rcvd_bus[i] )
                latched_eqctl_2ec0ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_2ec1ts1_rcvd_bus[i] )
                latched_eqctl_2ec1ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_2ec2ts1_rcvd_bus[i] )
                latched_eqctl_2ec2ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_2ec3ts1_rcvd_bus[i] )
                latched_eqctl_2ec3ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_8ec0ts1_rcvd_bus[i] )
                latched_eqctl_8ec0ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_8ec1ts1_rcvd_bus[i] )
                latched_eqctl_8ec1ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_8ec2ts1_rcvd_bus[i] )
                latched_eqctl_8ec2ts1_rcvd_bus[i] <= #TP 1;
            if ( current_eqctl_8ec3ts1_rcvd_bus[i] )
                latched_eqctl_8ec3ts1_rcvd_bus[i] <= #TP 1;
        end
    end
end // latched_eqctl_2ects1_rcvd_bus_PROC

always @( * ) begin : eqctl_2_8ects1_rcvd_bus_PROC
    eqctl_2ec0ts1_rcvd_bus = current_eqctl_2ec0ts1_rcvd_bus | latched_eqctl_2ec0ts1_rcvd_bus;
    eqctl_2ec1ts1_rcvd_bus = current_eqctl_2ec1ts1_rcvd_bus | latched_eqctl_2ec1ts1_rcvd_bus;
    eqctl_2ec2ts1_rcvd_bus = current_eqctl_2ec2ts1_rcvd_bus | latched_eqctl_2ec2ts1_rcvd_bus;
    eqctl_2ec3ts1_rcvd_bus = current_eqctl_2ec3ts1_rcvd_bus | latched_eqctl_2ec3ts1_rcvd_bus;
    eqctl_8ec0ts1_rcvd_bus = current_eqctl_8ec0ts1_rcvd_bus | latched_eqctl_8ec0ts1_rcvd_bus;
    eqctl_8ec1ts1_rcvd_bus = current_eqctl_8ec1ts1_rcvd_bus | latched_eqctl_8ec1ts1_rcvd_bus;
    eqctl_8ec2ts1_rcvd_bus = current_eqctl_8ec2ts1_rcvd_bus | latched_eqctl_8ec2ts1_rcvd_bus;
    eqctl_8ec3ts1_rcvd_bus = current_eqctl_8ec3ts1_rcvd_bus | latched_eqctl_8ec3ts1_rcvd_bus;
end // eqctl_2_8ects1_rcvd_bus_PROC

assign eqctl_8eqts1_rcvd    = &(~ltssm_lanes_active | eqctl_8eqts1_rcvd_bus);
assign eqctl_8eqts2_rcvd    = &(~ltssm_lanes_active | eqctl_8eqts2_rcvd_bus);
assign eqctl_any_8eqts1_rcvd= |(ltssm_lanes_active & eqctl_8eqts1_rcvd_bus);
assign eqctl_any_8eqts2_rcvd= |(ltssm_lanes_active & eqctl_8eqts2_rcvd_bus);
assign eqctl_8g4eqts1_rcvd    = &(~ltssm_lanes_active | eqctl_8g4eqts1_rcvd_bus);
assign eqctl_8g4eqts2_rcvd    = &(~ltssm_lanes_active | eqctl_8g4eqts2_rcvd_bus);
assign eqctl_any_8g4eqts1_rcvd= |(ltssm_lanes_active & eqctl_8g4eqts1_rcvd_bus);
assign eqctl_any_8g4eqts2_rcvd= |(ltssm_lanes_active & eqctl_8g4eqts2_rcvd_bus);
assign eqctl_2ects1_retimer_eq_ext0_rcvd = &(~ltssm_lanes_active | eqctl_2ects1_retimer_eq_ext0_rcvd_bus);
assign eqctl_8g5eqts1_rcvd    = &(~ltssm_lanes_active | eqctl_8g5eqts1_rcvd_bus);
assign eqctl_8g5eqts2_rcvd    = &(~ltssm_lanes_active | eqctl_8g5eqts2_rcvd_bus);
assign eqctl_any_8g5eqts1_rcvd= |(ltssm_lanes_active & eqctl_8g5eqts1_rcvd_bus);
assign eqctl_any_8g5eqts2_rcvd= |(ltssm_lanes_active & eqctl_8g5eqts2_rcvd_bus);
assign eqctl_8g6eqts1_rcvd    = &(~ltssm_lanes_active | eqctl_8g6eqts1_rcvd_bus);
assign eqctl_8g6eqts2_rcvd    = &(~ltssm_lanes_active | eqctl_8g6eqts2_rcvd_bus);
assign eqctl_any_8g6eqts1_rcvd= |(ltssm_lanes_active & eqctl_8g6eqts1_rcvd_bus);
assign eqctl_any_8g6eqts2_rcvd= |(ltssm_lanes_active & eqctl_8g6eqts2_rcvd_bus);
assign eqctl_precode6_request = |(ltssm_lanes_active & eqctl_precode6_request_bus);
assign eqctl_precode_request  = |(ltssm_lanes_active & eqctl_precode_request_bus);
assign eqctl_2ects1_rcvd[0] = &(~ltssm_lanes_active | eqctl_2ec0ts1_rcvd_bus);
assign eqctl_2ects1_rcvd[1] = &(~ltssm_lanes_active | eqctl_2ec1ts1_rcvd_bus);
assign eqctl_2ects1_rcvd[2] = &(~ltssm_lanes_active | eqctl_2ec2ts1_rcvd_bus);
assign eqctl_2ects1_rcvd[3] = &(~ltssm_lanes_active | eqctl_2ec3ts1_rcvd_bus);
assign eqctl_8ects1_rcvd[0] = &(~ltssm_lanes_active | eqctl_8ec0ts1_rcvd_bus);
assign eqctl_8ects1_rcvd[1] = &(~ltssm_lanes_active | eqctl_8ec1ts1_rcvd_bus);
assign eqctl_8ects1_rcvd[2] = &(~ltssm_lanes_active | eqctl_8ec2ts1_rcvd_bus);
assign eqctl_8ects1_rcvd[3] = &(~ltssm_lanes_active | eqctl_8ec3ts1_rcvd_bus);

always @(posedge core_clk or negedge core_rst_n) begin : eqctl_g6_tx_ts0_PROC
    if ( ~core_rst_n )
        eqctl_g6_tx_ts0 <= #TP '0;
    else if ( ltssm_current_data_rate < `GEN6_RATE || ltssm_state_rcvrlock || ltssm_state_rcvrspd )
        eqctl_g6_tx_ts0 <= #TP '0;
    // after dsp rx 2 ts0s with 10b in eq2, usp rx 2 ts1s with 11b in eq3, tx ts1s
    else if ( ~ltssm_clear && ((eqctl_2ects1_rcvd[2] && ~cfg_upstream_port && ltssm_state_equalization[2]) || (eqctl_2ects1_rcvd[3] && cfg_upstream_port && ltssm_state_equalization[3])) )
        eqctl_g6_tx_ts0 <= #TP '0;
    else if ( (~cfg_upstream_port && ltssm_state_equalization[1]) || (cfg_upstream_port && ltssm_state_equalization[0]) )
        eqctl_g6_tx_ts0 <= #TP 1; // start to send ts0 from dsp eq1 or usp eq0
end // eqctl_g6_tx_ts0_PROC

reg tx_ts0_dsp_eq2_usp_eq3;
always @(posedge core_clk or negedge core_rst_n) begin : tx_ts0_dsp_eq2_usp_eq3_PROC
    if ( ~core_rst_n )
        tx_ts0_dsp_eq2_usp_eq3 <= #TP '0;
    else if ( ltssm_current_data_rate < `GEN6_RATE || ltssm_state_rcvrlock || ltssm_state_rcvrspd )
        tx_ts0_dsp_eq2_usp_eq3 <= #TP '0;
    // after dsp rx 2 ts0s with 10b in eq2, usp rx 2 ts1s with 11b in eq3, tx ts1s
    else if ( ~ltssm_clear && ((eqctl_2ects1_rcvd[2] && ~cfg_upstream_port && ltssm_state_equalization[2]) || (eqctl_2ects1_rcvd[3] && cfg_upstream_port && ltssm_state_equalization[3])) )
        tx_ts0_dsp_eq2_usp_eq3 <= #TP '0;
    else if ( (~cfg_upstream_port && ltssm_state_equalization[2] && ltssm_clear) || (cfg_upstream_port && ltssm_state_equalization[3] && ltssm_clear) )
        tx_ts0_dsp_eq2_usp_eq3 <= #TP 1; // start to send ts0 from dsp eq2 or usp eq3
end // tx_ts0_dsp_eq2_usp_eq3_PROC

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 131us timer
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// time tick distributed to all the "slv" modules to implement the 2ms timeout on rtx requests
assign tick_131us = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Phase 2 (DC) or Phase 3 (UC) done on all configured lanes
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign eqctl_ftune_rtx_done = &(~ltssm_lanes_active | eqctl_ftune_rtx_done_bus);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Link Status 2 Register
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_eq_cmpl_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_eq_cmpl <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_eq_cmpl <= #TP '0;
    end else if( ~ltssm_current_data_rate_g3 ) begin
        sta_ls2_eq_cmpl <= #TP sta_ls2_eq_cmpl;
    end else if( ltssm_state_equalization_any_exit ) begin
        sta_ls2_eq_cmpl <= #TP 1'b1;
    end else if( ltssm_state_equalization_any_enter ) begin
        sta_ls2_eq_cmpl <= #TP 1'b0;
    end
end

assign sta_ls2_eq_enter = ltssm_current_data_rate_g3 & ltssm_state_equalization_any_enter;

always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_g4_eq_cmpl_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_g4_eq_cmpl <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_g4_eq_cmpl <= #TP '0;
    end else if( ~ltssm_current_data_rate_g4 ) begin
        sta_ls2_g4_eq_cmpl <= #TP sta_ls2_g4_eq_cmpl;
    end else if( ltssm_state_equalization_any_exit ) begin
        sta_ls2_g4_eq_cmpl <= #TP 1'b1;
    end else if( ltssm_state_equalization_any_enter ) begin
        sta_ls2_g4_eq_cmpl <= #TP 1'b0;
    end
end

assign sta_ls2_g4_eq_enter = ltssm_current_data_rate_g4 & ltssm_state_equalization_any_enter;

always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_g5_eq_cmpl_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_g5_eq_cmpl <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_g5_eq_cmpl <= #TP '0;
    end else if( ~ltssm_current_data_rate_g5 ) begin
        sta_ls2_g5_eq_cmpl <= #TP sta_ls2_g5_eq_cmpl;
    end else if( ltssm_state_equalization_any_exit ) begin
        sta_ls2_g5_eq_cmpl <= #TP 1'b1;
    end else if( ltssm_state_equalization_any_enter ) begin
        sta_ls2_g5_eq_cmpl <= #TP 1'b0;
    end
end

assign sta_ls2_g5_eq_enter = ltssm_current_data_rate_g5 & ltssm_state_equalization_any_enter;
always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_g6_eq_cmpl_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_g6_eq_cmpl <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_g6_eq_cmpl <= #TP '0;
    end else if( ~ltssm_current_data_rate_g6 ) begin
        sta_ls2_g6_eq_cmpl <= #TP sta_ls2_g6_eq_cmpl;
    end else if( ltssm_state_equalization_any_exit && ~ltssm_perform_eq_for_lpbk ) begin
        sta_ls2_g6_eq_cmpl <= #TP 1'b1;
    end else if( ltssm_state_equalization_any_enter ) begin
        sta_ls2_g6_eq_cmpl <= #TP 1'b0;
    end
end

assign sta_ls2_g6_eq_enter = ltssm_current_data_rate_g6 & ltssm_state_equalization_any_enter;

always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_eq_success_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_eq_success[3:1] <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_eq_success[3:1] <= #TP '0;
    end else if( ~ltssm_current_data_rate_g3 ) begin
        sta_ls2_eq_success[3:1] <= #TP sta_ls2_eq_success[3:1];
    end else if( (upstream_component && ltssm_state_equalization_enter[1]) || 
                 (!upstream_component && ltssm_state_equalization_enter[0]) ) begin
        sta_ls2_eq_success[3:1] <= #TP 3'b000;
    end else if( ltssm_state_equalization_exit[1] && ltssm_state_rcvrlock ) begin // UC does not want to do Phase 2 and 3
        sta_ls2_eq_success[3:1] <= #TP upstream_component ? 3'b111 : 3'b001; // 0.7 requires all success flags set in UC - only Phase 1 success flags set in DC
    end else if( ltssm_state_equalization_enter[2] ) begin
        sta_ls2_eq_success[1] <= #TP 1'b1;
    //If USP enters Phase 3 with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[2] = 1.
    end else if( ltssm_state_equalization_enter[3] && (upstream_component || (!upstream_component && (eqpa_ftune_rtx_optimal || cfg_gen3_eq_p23_exit_mode))) ) begin
        sta_ls2_eq_success[2] <= #TP 1'b1;
    //if DSP enters Rcvry.Lock with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[3] = 1.
    end else if( ltssm_state_equalization_exit[3] && ltssm_state_rcvrlock && (!upstream_component || (upstream_component && (eqpa_ftune_rtx_optimal || cfg_gen3_eq_p23_exit_mode))) ) begin
        sta_ls2_eq_success[3] <= #TP 1'b1;
    end
end

assign sta_ls2_eq_phase23_success = ltssm_current_data_rate_g6 ? (sta_ls2_g6_eq_success[3:2] == 2'b11) :
 ltssm_current_data_rate_g5 ? (sta_ls2_g5_eq_success[3:2] == 2'b11) : ltssm_current_data_rate_g4 ? (sta_ls2_g4_eq_success[3:2] == 2'b11) : (sta_ls2_eq_success[3:2] == 2'b11);

always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_g4_eq_success_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_g4_eq_success[3:1] <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_g4_eq_success[3:1] <= #TP '0;
    end else if( ~ltssm_current_data_rate_g4 ) begin
        sta_ls2_g4_eq_success[3:1] <= #TP sta_ls2_g4_eq_success[3:1];
    end else if( (upstream_component && ltssm_state_equalization_enter[1]) || 
                 (!upstream_component && ltssm_state_equalization_enter[0]) ) begin
        sta_ls2_g4_eq_success[3:1] <= #TP 3'b000;
    end else if( ltssm_state_equalization_exit[1] && ltssm_state_rcvrlock ) begin // UC does not want to do Phase 2 and 3
        sta_ls2_g4_eq_success[3:1] <= #TP upstream_component ? 3'b111 : 3'b001; // 0.7 requires all success flags set in UC - only Phase 1 success flags set in DC
    end else if( ltssm_state_equalization_enter[2] ) begin
        sta_ls2_g4_eq_success[1] <= #TP 1'b1;
    //If USP enters Phase 3 with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[2] = 1.
    end else if( ltssm_state_equalization_enter[3] && (upstream_component || (!upstream_component && (cfg_gen4_eq_p23_exit_mode || eqpa_ftune_rtx_optimal))) ) begin
        sta_ls2_g4_eq_success[2] <= #TP 1'b1;
    //if DSP enters Rcvry.Lock with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[3] = 1.
    end else if( ltssm_state_equalization_exit[3] && ltssm_state_rcvrlock && (!upstream_component || (upstream_component && (cfg_gen4_eq_p23_exit_mode || eqpa_ftune_rtx_optimal))) ) begin
        sta_ls2_g4_eq_success[3] <= #TP 1'b1;
    end
end


always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_g5_eq_success_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_g5_eq_success[3:1] <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_g5_eq_success[3:1] <= #TP '0;
    end else if( ~ltssm_current_data_rate_g5 ) begin
        sta_ls2_g5_eq_success[3:1] <= #TP sta_ls2_g5_eq_success[3:1];
    end else if( (upstream_component && ltssm_state_equalization_enter[1]) || 
                 (!upstream_component && ltssm_state_equalization_enter[0]) ) begin
        sta_ls2_g5_eq_success[3:1] <= #TP 3'b000;
    end else if( ltssm_state_equalization_exit[1] && ltssm_state_rcvrlock ) begin // UC does not want to do Phase 2 and 3
        sta_ls2_g5_eq_success[3:1] <= #TP upstream_component ? 3'b111 : 3'b001; // 0.7 requires all success flags set in UC - only Phase 1 success flags set in DC
    end else if( ltssm_state_equalization_enter[2] ) begin
        sta_ls2_g5_eq_success[1] <= #TP 1'b1;
    //If USP enters Phase 3 with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[2] = 1.
    end else if( ltssm_state_equalization_enter[3] && (upstream_component || (!upstream_component && (cfg_gen5_eq_p23_exit_mode || eqpa_ftune_rtx_optimal))) ) begin
        sta_ls2_g5_eq_success[2] <= #TP 1'b1;
    //if DSP enters Rcvry.Lock with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[3] = 1.
    end else if( ltssm_state_equalization_exit[3] && ltssm_state_rcvrlock && (!upstream_component || (upstream_component && (cfg_gen5_eq_p23_exit_mode || eqpa_ftune_rtx_optimal))) ) begin
        sta_ls2_g5_eq_success[3] <= #TP 1'b1;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : sta_ls2_g6_eq_success_seq_PROC
    if( !core_rst_n ) begin
        sta_ls2_g6_eq_success[3:1] <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        sta_ls2_g6_eq_success[3:1] <= #TP '0;
    end else if ( ltssm_perform_eq_for_lpbk ) begin
        sta_ls2_g6_eq_success[3:1] <= #TP sta_ls2_g6_eq_success[3:1];
    end else if( ~ltssm_current_data_rate_g6 ) begin
        sta_ls2_g6_eq_success[3:1] <= #TP sta_ls2_g6_eq_success[3:1];
    end else if( (upstream_component && ltssm_state_equalization_enter[1]) || 
                 (!upstream_component && ltssm_state_equalization_enter[0]) ) begin
        sta_ls2_g6_eq_success[3:1] <= #TP 3'b000;
    end else if( ltssm_state_equalization_exit[1] && ltssm_state_rcvrlock ) begin // UC does not want to do Phase 2 and 3
        sta_ls2_g6_eq_success[3:1] <= #TP upstream_component ? 3'b111 : 3'b001; // 0.7 requires all success flags set in UC - only Phase 1 success flags set in DC
    end else if( ltssm_state_equalization_enter[2] ) begin
        sta_ls2_g6_eq_success[1] <= #TP 1'b1;
    //If USP enters Phase 3 with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[2] = 1.
    end else if( ltssm_state_equalization_enter[3] && (upstream_component || (!upstream_component && (cfg_gen6_eq_p23_exit_mode || eqpa_ftune_rtx_optimal))) ) begin
        sta_ls2_g6_eq_success[2] <= #TP 1'b1;
    //if DSP enters Rcvry.Lock with exit_mode=1 + timeout_24ms (though eqpa_ftune_rtx_optimal=0), sta_ls2_eq_success[3] = 1.
    end else if( ltssm_state_equalization_exit[3] && ltssm_state_rcvrlock && (!upstream_component || (upstream_component && (cfg_gen6_eq_p23_exit_mode || eqpa_ftune_rtx_optimal))) ) begin
        sta_ls2_g6_eq_success[3] <= #TP 1'b1;
    end
end

smlh_eqctl_slv
 
#(INST) u_smlh_eqctl_slv[NL-1:0]
(
// ---- input --------------
    .core_clk                            (core_clk),
    .core_rst_n                          (core_rst_n),
    .upstream_component                  (upstream_component),
    .cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map),
    .fom_gen34_eq_phase23_rxeq_regardless_rxts (fom_gen34_eq_phase23_rxeq_regardless_rxts),
    .req_rst_eiec_enable                 (req_rst_eiec_enable),
    .smlh_eqts_info                      (smlh_eqts_info),
    .tx_ts0_dsp_eq2_usp_eq3              (tx_ts0_dsp_eq2_usp_eq3),
    .smlh_ts0_rcvd                       (smlh_ts0_rcvd_bus),
    .ltssm_dsp_g6_eq1_send_ec00          (ltssm_dsp_g6_eq1_send_ec00),
    .ltssm_state_last_equalization_any   (ltssm_state_last_equalization_any),
    .ltssm_perform_eq_for_lpbk           (ltssm_perform_eq_for_lpbk),
    .smlh_ts1_rcvd                       (smlh_ts1_rcvd_bus),
    .smlh_ts2_rcvd                       (smlh_ts2_rcvd_bus),
    .smlh_ts_rcvd_s6s9_pcnt              (smlh_ts_rcvd_s6s9_pcnt),
    .smlh_ts_info                        (smlh_ts_info),
    .ltssm_active_lane                   (ltssm_lanes_active),
    .ltssm_lpbk_master                   (ltssm_lpbk_master),
    .ltssm_current_data_rate_g12         (ltssm_current_data_rate_g12),
    .ltssm_current_data_rate_g12_pulse   (ltssm_current_data_rate_g12_pulse),
    .ltssm_current_data_rate_g3          (ltssm_current_data_rate_g3),
    .ltssm_current_data_rate_g3_pulse    (ltssm_current_data_rate_g3_pulse),
    .ltssm_captured_ts_data_rate_g3      (ltssm_captured_ts_data_rate_g3),
    .ltssm_captured_ts_data_rate_g5      (ltssm_captured_ts_data_rate_g5),
    .ltssm_current_data_rate_g4          (ltssm_current_data_rate_g4),
    .ltssm_current_data_rate_g4_pulse    (ltssm_current_data_rate_g4_pulse),
    .smlh_link_up_falling_edge           (smlh_link_up_falling_edge),
    .ltssm_current_data_rate_g5          (ltssm_current_data_rate_g5),
    .ltssm_current_data_rate_g5_pulse    (ltssm_current_data_rate_g5_pulse),
    .ltssm_current_data_rate_g6          (ltssm_current_data_rate_g6),
    .ltssm_current_data_rate_g6_pulse    (ltssm_current_data_rate_g6_pulse),
    .ltssm_captured_ts_data_rate_g6      (ltssm_captured_ts_data_rate_g6),
    .mac_phy_txswing                     (mac_phy_txswing),
    .ltssm_state_equalization            (ltssm_state_equalization[3:0]),
    .ltssm_state_equalization_enter      (ltssm_state_equalization_enter[3:0]),
    .ltssm_state_equalization_exit       (ltssm_state_equalization_exit[3:0]),
    .ltssm_state_equalization_any        (ltssm_state_equalization_any),
    .ltssm_state_equalization_any_exit   (ltssm_state_equalization_any_exit),
    .ltssm_state_rcvrlock                (ltssm_state_rcvrlock),
    .ltssm_state_rcvrcfg                 (ltssm_state_rcvrcfg),
    .ltssm_state_rcvrspd                 (ltssm_state_rcvrspd),
    .ltssm_state_rcvridle                (ltssm_state_rcvridle),
    .ltssm_cmd_ts1                       (ltssm_cmd_ts1),
    .ltssm_cmd_ts2                       (ltssm_cmd_ts2),
    .ltssm_cmd_eqts                      (ltssm_cmd_eqts),
    .ltssm_cmd_send_eieos_for_pset_map   (ltssm_cmd_send_eieos_for_pset_map),
    .ltssm_cmd_8geqts                    (ltssm_cmd_8geqts),
    .ltssm_cmd_eqredo                    (ltssm_cmd_eqredo),
    .ltssm_cmd_16geqts                   (ltssm_cmd_16geqts),
    .ltssm_noeq_nd                       (ltssm_noeq_nd),
    .ltssm_cmd_eqts_gen12                (ltssm_cmd_eqts_gen12),
    .ltssm_precode_request               (ltssm_precode_request),
    .ltssm_precoding_on                  (ltssm_precoding_on),
    .ltssm_cmd_32geqts                   (ltssm_cmd_32geqts),
    .ltssm_start_equalization            (ltssm_start_equalization),
    .ltssm_gen3_compliance_tx_pset       (ltssm_gen3_compliance_tx_pset),
    .ltssm_gen3_compliance_tx_pset_v     (ltssm_gen3_compliance_tx_pset_v),
    .ltssm_state_compliance              (ltssm_state_compliance),
    .ltssm_state_pollactive              (ltssm_state_pollactive),
    .ltssm_state_lpbkentry               (ltssm_state_lpbkentry),
    .ltssm_state_lpbkact                 (ltssm_state_lpbkact),
    .ltssm_state_cfglwstart              (ltssm_state_cfglwstart),
    .ltssm_clear                         (ltssm_clear),
    .ltssm_state_detect                  (ltssm_state_detect),
    .ltssm_state_disable                 (ltssm_state_disable),
    .ltssm_state_hotreset                (ltssm_state_hotreset),
    .ltssm_state_l0                      (ltssm_state_l0),
    .ltssm_state_l0s                     (ltssm_state_l0s),
    .ltssm_state_l123                    (ltssm_state_l123),
    .ltssm_state_l1                      (ltssm_state_l1),
    .ltssm_state_l2                      (ltssm_state_l2),
    .ltssm_ts_data_rate                  (ltssm_ts_data_rate),
    .cfg_target_link_speed               (cfg_target_link_speed),
    .ltssm_ts_data_rate_eg6              (ltssm_ts_data_rate_eg6),
    .latched_ts_data_rate_eg6            (latched_ts_data_rate_eg6),
    .cfg_lec_pset_ltx                    (cfg_lec_pset_ltx),
    .cfg_lec_pset_lrx                    (cfg_lec_pset_lrx),
    .cfg_lec_pset_rtx                    (cfg_lec_pset_rtx),
    .cfg_lec_pset_rrx                    (cfg_lec_pset_rrx),
    .cfg_lec_g4_pset_ltx                 (cfg_lec_g4_pset_ltx),
    .cfg_lec_g4_pset_lrx                 (cfg_lec_g4_pset_lrx),
    .cfg_lec_g4_pset_rtx                 (cfg_lec_g4_pset_rtx),
    .cfg_lec_g4_pset_rrx                 (cfg_lec_g4_pset_rrx),
    .cfg_lec_g5_pset_ltx                 (cfg_lec_g5_pset_ltx),
    .cfg_lec_g5_pset_lrx                 (cfg_lec_g5_pset_lrx),
    .cfg_lec_g5_pset_rtx                 (cfg_lec_g5_pset_rtx),
    .cfg_lec_g5_pset_rrx                 (cfg_lec_g5_pset_rrx),
    .cfg_lec_g6_pset_ltx                 (cfg_lec_g6_pset_ltx),
    .cfg_lec_g6_pset_lrx                 (cfg_lec_g6_pset_lrx),
    .cfg_lec_g6_pset_rtx                 (cfg_lec_g6_pset_rtx),
    .cfg_lec_g6_pset_rrx                 (cfg_lec_g6_pset_rrx),
    .cfg_gen3_eq_disable                 (cfg_gen3_eq_disable),
    .phy_mac_fslf_ltx                    (phy_mac_fslf_ltx),
    .phy_mac_coef_ltx                    (phy_mac_coef_ltx),
    .phy_mac_reject_ltx                  (phy_mac_reject_ltx),
    .phy_mac_accept_ltx                  (phy_mac_accept_ltx),
    .phy_mac_pset_rtx                    (phy_mac_pset_rtx),
    .phy_mac_coef_rtx                    (phy_mac_coef_rtx),
    .phy_mac_ftune_rtx_done              (phy_mac_ftune_rtx_done),
    .phy_mac_fslf_ltx_valid              (phy_mac_fslf_ltx_valid),
    .phy_mac_pset_rtx_upd                (phy_mac_pset_rtx_upd),
    .phy_mac_coef_rtx_upd                (phy_mac_coef_rtx_upd),
    .phy_mac_ftune_rtx_optimal           (phy_mac_ftune_rtx_optimal),
    .tick_131us                          (tick_131us),
    .txts_eq_req                         (txts_eq_req),
    .txts_quie_gua                       (txts_quie_gua),
    .txts_eq_req_data_rate               (txts_eq_req_data_rate),
    .sta_ls2_eq_phase23_success          (sta_ls2_eq_phase23_success),
    .eqpa_timeout_1us_after_request      (eqpa_timeout_1us_after_request),
    .eqpa_wait_rei_state                 (eqpa_wait_rei_state),
    .cdm_ras_des_eq_force_pset_ltx_en    (cdm_ras_des_eq_force_pset_ltx_en),
    .cdm_ras_des_eq_force_usp_pset_ltx   (cdm_ras_des_eq_force_usp_pset_ltx),
    .cdm_ras_des_eq_force_pset_ltx_en_g4 (cdm_ras_des_eq_force_pset_ltx_en_g4),
    .cdm_ras_des_eq_force_usp_pset_ltx_g4 (cdm_ras_des_eq_force_usp_pset_ltx_g4),
    .cdm_ras_des_eq_force_pset_ltx_en_g5 (cdm_ras_des_eq_force_pset_ltx_en_g5),
    .cdm_ras_des_eq_force_usp_pset_ltx_g5 (cdm_ras_des_eq_force_usp_pset_ltx_g5),
    .cdm_ras_des_eq_force_pset_ltx_en_g6 (cdm_ras_des_eq_force_pset_ltx_en_g6),
    .cdm_ras_des_eq_force_usp_pset_ltx_g6 (cdm_ras_des_eq_force_usp_pset_ltx_g6),
// ---- outputs -------------
    .eqctl_8eqts1_rcvd                   (eqctl_8eqts1_rcvd_bus),
    .eqctl_8eqts2_rcvd                   (eqctl_8eqts2_rcvd_bus),
    .eqctl_8g4eqts1_rcvd                 (eqctl_8g4eqts1_rcvd_bus),
    .eqctl_8g4eqts2_rcvd                 (eqctl_8g4eqts2_rcvd_bus),
    .eqctl_8g5eqts1_rcvd                 (eqctl_8g5eqts1_rcvd_bus),
    .eqctl_8g5eqts2_rcvd                 (eqctl_8g5eqts2_rcvd_bus),
    .eqctl_precode_request               (eqctl_precode_request_bus),
    .eqctl_precode6_request              (eqctl_precode6_request_bus),
    .eqctl_8g6eqts1_rcvd                 (eqctl_8g6eqts1_rcvd_bus),
    .eqctl_8g6eqts2_rcvd                 (eqctl_8g6eqts2_rcvd_bus),
    .eqctl_2ects1_rcvd                   (eqctl_2ects1_rcvd_bus),
    .eqctl_8ects1_rcvd                   (eqctl_8ects1_rcvd_bus),
    .eqctl_8eqrts2_rcvd_g3               (eqctl_8eqrts2_rcvd_g3_bus),
    .eqctl_8eqrgts2_rcvd_g3              (eqctl_8eqrgts2_rcvd_g3_bus),
    .eqctl_8eqrts2_rcvd_g4               (eqctl_8eqrts2_rcvd_g4_bus),
    .eqctl_8eqrgts2_rcvd_g4              (eqctl_8eqrgts2_rcvd_g4_bus),
    .eqctl_2ects1_retimer_eq_ext0_rcvd   (eqctl_2ects1_retimer_eq_ext0_rcvd_bus),
    .eqctl_8eqrts2_rcvd_g5               (eqctl_8eqrts2_rcvd_g5_bus),
    .eqctl_8eqrgts2_rcvd_g5              (eqctl_8eqrgts2_rcvd_g5_bus),
    .eqctl_8eqrts2_rcvd_g6               (eqctl_8eqrts2_rcvd_g6_bus),
    .eqctl_8eqrgts2_rcvd_g6              (eqctl_8eqrgts2_rcvd_g6_bus),
    .eqctl_eqts_info_ts0                 (eqctl_eqts_info_ts0),
    .eqctl_ftune_rtx_done                (eqctl_ftune_rtx_done_bus),
    .eqctl_eqts_info                     (eqctl_eqts_info),
    .eqctl_mask_eieos                    (eqctl_mask_eieos),
    .eqctl_2mask_eieos_pulse             (eqctl_2mask_eieos_pulse),
    .sta_lec_pset_ltx                    (sta_lec_pset_ltx),
    .sta_lec_pset_lrx                    (sta_lec_pset_lrx),
    .sta_lec_g4_pset_ltx                 (sta_lec_g4_pset_ltx),
    .sta_lec_g4_pset_lrx                 (sta_lec_g4_pset_lrx),
    .sta_lec_g5_pset_ltx                 (sta_lec_g5_pset_ltx),
    .sta_lec_g5_pset_lrx                 (sta_lec_g5_pset_lrx),
    .sta_lec_g6_pset_ltx                 (sta_lec_g6_pset_ltx),
    .sta_lec_g6_pset_lrx                 (sta_lec_g6_pset_lrx),
    .mac_phy_pset_ltx                    (mac_phy_pset_ltx),
    .mac_phy_pset_lrx                    (mac_phy_pset_lrx),
    .mac_phy_coef_ltx                    (mac_phy_coef_ltx),
    .mac_phy_fslf_rtx                    (mac_phy_fslf_rtx),
    .mac_phy_pset_rtx                    (mac_phy_pset_rtx),
    .mac_phy_coef_rtx                    (mac_phy_coef_rtx),
    .mac_phy_reject_rtx                  (mac_phy_reject_rtx),
    .mac_phy_accept_rtx                  (mac_phy_accept_rtx),
    .mac_phy_timeout_rtx                 (mac_phy_timeout_rtx),
    .mac_phy_ftune_rtx                   (mac_phy_ftune_rtx_bus),
    .mac_phy_ftune_ltx                   (mac_phy_ftune_ltx_bus),
    .mac_phy_lpbk_ftune_ltx              (mac_phy_lpbk_ftune_ltx),
    .mac_phy_use_pset                    (mac_phy_use_pset),
    .mac_phy_fslf_rtx_valid              (mac_phy_fslf_rtx_valid),
    .mac_phy_pset_ltx_upd                (mac_phy_pset_ltx_upd),
    .mac_phy_coef_ltx_upd                (mac_phy_coef_ltx_upd),
    .rxts_eq_mismatch                    (rxts_eq_mismatch)
);

assign mac_phy_ftune_rtx = mac_phy_ftune_rtx_bus[0];
assign mac_phy_ftune_ltx = mac_phy_ftune_ltx_bus[0];

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// redoing equalization
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////
// eqctl_link_retrain
////////////////////////////////////////////////////
/*html_start
<p><b>eqctl_link_retrain</b><br>
Asserted in L0 at Gen3 rate when a problem is detected with current equalization settings.
De-asserted on exit from RcvrLock
html_end*/
wire phy_mac_eq_req_any = |(ltssm_lanes_active[NL-1] & phy_mac_eq_req[NL-1]);
wire set_link_retrain = phy_mac_eq_req_any && (ltssm_state == S_L0) && ltssm_current_data_rate_g3; // autonomous retraining from Gen1/2 rate is not supported
wire rst_link_retrain = (ltssm_state_last == S_RCVRY_LOCK) && (ltssm_state != S_RCVRY_LOCK) && ltssm_current_data_rate_g3;
wire set_link_retrain_g4 = phy_mac_eq_req_any && (ltssm_state == S_L0) && ltssm_current_data_rate_g4; // autonomous retraining from Gen1/2 rate is not supported
wire rst_link_retrain_g4 = (ltssm_state_last == S_RCVRY_LOCK) && (ltssm_state != S_RCVRY_LOCK) && ltssm_current_data_rate_g4;
wire set_link_retrain_g5 = phy_mac_eq_req_any && (ltssm_state == S_L0) && ltssm_current_data_rate_g5; // autonomous retraining from Gen1/2 rate is not supported
wire rst_link_retrain_g5 = (ltssm_state_last == S_RCVRY_LOCK) && (ltssm_state != S_RCVRY_LOCK) && ltssm_current_data_rate_g5;
wire set_link_retrain_g6 = phy_mac_eq_req_any && (ltssm_state == S_L0) && ltssm_current_data_rate_g6; // autonomous retraining from Gen1/2 rate is not supported
wire rst_link_retrain_g6 = (ltssm_state_last == S_RCVRY_LOCK) && (ltssm_state != S_RCVRY_LOCK) && ltssm_current_data_rate_g6;

always @(posedge core_clk or negedge core_rst_n) begin : eqctl_link_retrain_seq_PROC
    if( !core_rst_n ) begin
        eqctl_link_retrain <= #TP 1'b0;
    end else begin
        if( set_link_retrain ) 
            eqctl_link_retrain <= #TP 1'b1;
        else if( rst_link_retrain )
            eqctl_link_retrain <= #TP 1'b0;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eqctl_link_retrain_g4_seq_PROC
    if( !core_rst_n ) begin
        eqctl_link_retrain_g4 <= #TP 1'b0;
    end else begin
        if( set_link_retrain_g4 ) 
            eqctl_link_retrain_g4 <= #TP 1'b1;
        else if( rst_link_retrain_g4 )
            eqctl_link_retrain_g4 <= #TP 1'b0;
    end
end


always @(posedge core_clk or negedge core_rst_n) begin : eqctl_link_retrain_g5_seq_PROC
    if( !core_rst_n ) begin
        eqctl_link_retrain_g5 <= #TP 1'b0;
    end else begin
        if( set_link_retrain_g5 )
            eqctl_link_retrain_g5 <= #TP 1'b1;
        else if( rst_link_retrain_g5 )
            eqctl_link_retrain_g5 <= #TP 1'b0;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eqctl_link_retrain_g6_seq_PROC
    if( !core_rst_n ) begin
        eqctl_link_retrain_g6 <= #TP 1'b0;
    end else begin
        if( set_link_retrain_g6 )
            eqctl_link_retrain_g6 <= #TP 1'b1;
        else if( rst_link_retrain_g6 )
            eqctl_link_retrain_g6 <= #TP 1'b0;
    end
end
////////////////////////////////////////////////////
// eqctl_eq_req_ltx
////////////////////////////////////////////////////
/*html_start
<p><b>eqctl_eq_req_ltx</b><br>
Equalization Request because of a problem detected locally.
Asserted in RcvrLock if a problem is detected with current equalization settings. This could be because of a mismatch in the coefficients 
in received TS1s has been detected following Equalization -> RcvrLock transition, or because RcvrLock was entered with the link_retrain flag 
asserted. Asserted also in RcvrCfg if RcvrCfg was entered with the eqctl_eq_req_rtx flag asserted (DC only) and quiesce guarantee is given by higher layer.
This last case happens if the UC has sent Eq.Request TS2 in the previous trip through RcvrCfg to instruct the DC to request equalization. 
When RcvrCfg is reached again with this flag asserted, the DC will send Eq.Request TS2. The LTSSM captures the eqctl_eq_req_ltx flag in RcvrCfg and uses this
information to block TX transactions once in L0 (pseudo L0 behavior).
The flag is de-asserted on L0 -> Recovery transition.
html_end*/
wire local_detetct_eq_problem;
wire usp_re_tx_eq_req_from_rx;

wire rxts_eq_mismatch_any = ( cfg_block_local_detect_eq_problem ) ? 1'b0 : |(ltssm_lanes_active[NL-1:0] & rxts_eq_mismatch[NL-1:0]);

assign local_detetct_eq_problem = (rxts_eq_mismatch_any && ltssm_state_rcvrlock && ltssm_state_last_equalization[3]) ||   // RcvrLock entered from Equalization and eq settings mismatch detected (i.e. rxts settings don't match what was requested during fine tuning)
                                  (eqctl_link_retrain && ltssm_state_rcvrlock && ltssm_clear) ;                           // RcvrLock entered with retrain flag set
assign usp_re_tx_eq_req_from_rx = (!upstream_component && eqctl_eq_req_rtx && ltssm_state_rcvrcfg && ltssm_clear) ;       // RcvrCfg entered with eq_req_rtx flag set and quiesce guarantee from higher layers - DC only

wire set_eq_req_ltx = ( local_detetct_eq_problem || usp_re_tx_eq_req_from_rx ) && !cfg_gen3_eq_req_disable;               // always 0 when disabled for cfg_gen3_eq_req_disable = 1

// reset the flag on L0 -> Recovery transition
wire rst_eq_req_ltx_rtx = (ltssm_state_last == S_RCVRY_IDLE) && (ltssm_state == S_L0) && ltssm_clear;
wire rst_eq_req_ltx = ltssm_state_rcvrlock && (ltssm_state_last == S_L0) && ltssm_clear;

reg int_eq_req_ltx;
always @(posedge core_clk or negedge core_rst_n) begin : int_eq_req_ltx_seq_PROC
    if( !core_rst_n ) begin
        int_eq_req_ltx <= #TP 1'b0;
    end else begin
        if( set_eq_req_ltx ) 
            int_eq_req_ltx <= #TP 1'b1;
        else if( rst_eq_req_ltx )
            int_eq_req_ltx <= #TP 1'b0;
    end
end

wire   usp_support_finite_eq_req = cfg_gen3_support_finite_eq_req & cfg_upstream_port;
// force transmission of TS2 with the Eq.Request bit set and Quiesce guarantee depending on higher layer
// if in auto_eq time, DSP does not send EQ request to USP when cfg_gen3_lower_rate_eq_redo_enable is set to 1
assign txts_eq_req_i = int_eq_req_ltx && ltssm_state_rcvrcfg && !cfg_gen3_eq_req_disable && (cfg_gen3_lower_rate_eq_redo_enable ? ~(auto_eq_phase_flag & ~cfg_upstream_port) : 1'b1);
// dsp || ~cfg_gen3_support_finite_eq_req: keep legacy, usp && cfg_gen3_support_finite_eq_req: (eq_req_num >= cfg_gen3_eq_req_num: no more eq request, else: keep request if it occurs)
assign txts_eq_req   = usp_support_finite_eq_req ? (eq_req_num_is_cdm_settings ? 1'b0 : txts_eq_req_i) : txts_eq_req_i;
assign txts_eq_req_data_rate = !txts_eq_req ? 1'b0 : ltssm_current_data_rate_g4 | ltssm_current_data_rate_g5 | ltssm_current_data_rate_g6;

// Need to register quiesce bit in case xmlh_byte_xmt's load_pat coincides with clear signal on transition out of Recovery.RcvrCfg
// In this case, the TS2 still belongs to Recovery.RcvrCfg
wire txts_quie_gua_i = ltssm_state_rcvrcfg && ltssm_quie_gua && txts_eq_req;
reg  txts_quie_gua_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin: txts_quie_gua_r_PROC
  if(!core_rst_n) begin
    txts_quie_gua_r <= #TP 1'b0;
  end else begin
    txts_quie_gua_r <= #TP txts_quie_gua_i;
  end
end

// Need to OR with txts_quie_gua_i in case xmlh_byte_xmt's load_pat coincides with second cycle on entry to Recovery.RcvrCfg
assign txts_quie_gua = txts_quie_gua_i | txts_quie_gua_r;

////////////////////////////////////////////////////
// eqctl_eq_req_rtx
////////////////////////////////////////////////////
/*html_start
<p><b>eqctl_eq_req_rtx</b><br>
Equalization Request because of a problem detected remotely.
Asserted in RcvrCfg->Idle transition after receiving Eq.Request TS2.
The flag is de-asserted on L0 -> Recovery transition (UC) or the next time RcvrCfg is reached (DC).
html_end*/

assign eqctl_8eqrts2_rcvd_g3   = &(~ltssm_lanes_active | eqctl_8eqrts2_rcvd_g3_bus);
assign eqctl_8eqrgts2_rcvd_g3  = &(~ltssm_lanes_active | eqctl_8eqrgts2_rcvd_g3_bus);
assign eqctl_8eqrts2_rcvd_g6   = &(~ltssm_lanes_active | eqctl_8eqrts2_rcvd_g6_bus);
assign eqctl_8eqrgts2_rcvd_g6  = &(~ltssm_lanes_active | eqctl_8eqrgts2_rcvd_g6_bus);
assign eqctl_8eqrts2_rcvd_g5   = &(~ltssm_lanes_active | eqctl_8eqrts2_rcvd_g5_bus);
assign eqctl_8eqrgts2_rcvd_g5  = &(~ltssm_lanes_active | eqctl_8eqrgts2_rcvd_g5_bus);
assign eqctl_8eqrts2_rcvd_g4   = &(~ltssm_lanes_active | eqctl_8eqrts2_rcvd_g4_bus);
assign eqctl_8eqrgts2_rcvd_g4  = &(~ltssm_lanes_active | eqctl_8eqrgts2_rcvd_g4_bus);
//
// 3.0 - 0.7 draft:
// Recovery.RcvrCfg state, in the transition to Recovery.Idle, "if the Request Equalization bit is set to 1b in the eight consecutive TS2 Ordered Sets, the device must note ..."
// Use ltssm_clear to make it a pulse

wire g3_8_eq_req_ts2_rcvd;
wire g3_8_eq_req_ts2_rcvd_rcvrspd;
assign g3_8_eq_req_ts2_rcvd_rcvrspd = eqctl_8eqrts2_rcvd_g3 && ltssm_state_rcvrspd && ltssm_clear;
assign g3_8_eq_req_ts2_rcvd = eqctl_8eqrts2_rcvd_g3 && ltssm_state_rcvridle && ltssm_clear;
wire set_eq_req_rtx_g3 = g3_8_eq_req_ts2_rcvd && !cfg_gen3_eq_req_disable;
wire g4_8_eq_req_ts2_rcvd;
wire g4_8_eq_req_ts2_rcvd_rcvrspd;
assign g4_8_eq_req_ts2_rcvd_rcvrspd = eqctl_8eqrts2_rcvd_g4 && ltssm_state_rcvrspd && ltssm_clear;
assign g4_8_eq_req_ts2_rcvd = eqctl_8eqrts2_rcvd_g4 && ltssm_state_rcvridle && ltssm_clear;
wire set_eq_req_rtx_g4 = g4_8_eq_req_ts2_rcvd && !cfg_gen3_eq_req_disable;
wire g5_8_eq_req_ts2_rcvd;
wire g5_8_eq_req_ts2_rcvd_rcvrspd;
assign g5_8_eq_req_ts2_rcvd_rcvrspd = eqctl_8eqrts2_rcvd_g5 && ltssm_state_rcvrspd && ltssm_clear;
assign g5_8_eq_req_ts2_rcvd = eqctl_8eqrts2_rcvd_g5 && ltssm_state_rcvridle && ltssm_clear;
wire set_eq_req_rtx_g5 = g5_8_eq_req_ts2_rcvd && !cfg_gen3_eq_req_disable;
wire g6_8_eq_req_ts2_rcvd;
wire g6_8_eq_req_ts2_rcvd_rcvrspd;
assign g6_8_eq_req_ts2_rcvd_rcvrspd = eqctl_8eqrts2_rcvd_g6 && ltssm_state_rcvrspd && ltssm_clear;
assign g6_8_eq_req_ts2_rcvd = eqctl_8eqrts2_rcvd_g6 && ltssm_state_rcvridle && ltssm_clear;
wire set_eq_req_rtx_g6 = g6_8_eq_req_ts2_rcvd && !cfg_gen3_eq_req_disable;
wire rst_eq_req_rtx = upstream_component ? (ltssm_state_rcvrlock && (ltssm_state_last == S_L0) && ltssm_clear) : (ltssm_state_rcvrcfg && (ltssm_state_last == S_RCVRY_LOCK) && ltssm_clear);

reg int_eq_req_rtx_g3;
always @(posedge core_clk or negedge core_rst_n) begin : int_eq_req_rtx_g3_seq_PROC
    if( !core_rst_n ) begin
        int_eq_req_rtx_g3 <= #TP 1'b0;
    end else begin
        if( set_eq_req_rtx_g3 ) begin
            int_eq_req_rtx_g3 <= #TP eqctl_8eqrgts2_rcvd_g3;
        end else if( rst_eq_req_rtx ) begin
            int_eq_req_rtx_g3 <= #TP 1'b0;
        end
    end
end

reg int_eq_req_rtx_g4;
always @(posedge core_clk or negedge core_rst_n) begin : int_eq_req_rtx_g4_seq_PROC
    if( !core_rst_n ) begin
        int_eq_req_rtx_g4 <= #TP 1'b0;
    end else begin
        if( set_eq_req_rtx_g4 ) begin
            int_eq_req_rtx_g4 <= #TP eqctl_8eqrgts2_rcvd_g4;
        end else if( rst_eq_req_rtx ) begin
            int_eq_req_rtx_g4 <= #TP 1'b0;
        end
    end
end
reg int_eq_req_rtx_g5;
always @(posedge core_clk or negedge core_rst_n) begin : int_eq_req_rtx_g5_seq_PROC
    if( !core_rst_n ) begin
        int_eq_req_rtx_g5 <= #TP 1'b0;
    end else begin
        if( set_eq_req_rtx_g5 ) begin
            int_eq_req_rtx_g5 <= #TP eqctl_8eqrgts2_rcvd_g5;
        end else if( rst_eq_req_rtx ) begin
            int_eq_req_rtx_g5 <= #TP 1'b0;
        end
    end
end

reg int_eq_req_rtx_g6;
always @(posedge core_clk or negedge core_rst_n) begin : int_eq_req_rtx_g6_seq_PROC
    if( !core_rst_n ) begin
        int_eq_req_rtx_g6 <= #TP 1'b0;
    end else begin
        if( set_eq_req_rtx_g6 ) begin
            int_eq_req_rtx_g6 <= #TP eqctl_8eqrgts2_rcvd_g6;
        end else if( rst_eq_req_rtx ) begin
            int_eq_req_rtx_g6 <= #TP 1'b0;
        end
    end
end

////////////////////////////////////////////////////
// ls2 interface
////////////////////////////////////////////////////
// 3.0 - 0.7 draft:
// Link Equalization Request  This bit is Set by hardware to request the Link equalization process to be performed on the Link
// Note: As the DC (differently from UC) is expected to convert "remote" eq req into "local" eq req ("local" eq req condition 
//       is required to send eqrTS2s, which is how DC responds to UC after UC sends eqrTS2s), there is no need to make the LS2 bit
//       sensitive to "remote" requests for DC. For UC it needs to be sensitive as a "remote" request will not be converted into "local".

assign set_ls2_eq_req = cfg_gen3_lower_rate_eq_redo_enable ?
                        ( cfg_gen3_eq_req_disable ? ((local_detetct_eq_problem & ltssm_current_data_rate_g3) | (g3_8_eq_req_ts2_rcvd && upstream_component)) : //if cfg_gen3_eq_req_disable = 1, any port detects eq problem or DSP receives eq req
                                                    ((upstream_component && local_detetct_eq_problem && ~auto_eq_phase_flag && ltssm_current_data_rate_g3) || //if cfg_gen3_eq_req_disable = 0, DSP detects eq problem in ~autonomous eq mechanism time
                                                     (upstream_component && g3_8_eq_req_ts2_rcvd_rcvrspd) || //if cfg_gen3_eq_req_disable = 0, DSP receives eq req and speed change is ongoing
                                                     (~upstream_component && local_detetct_eq_problem && ltssm_current_data_rate_g3) //if cfg_gen3_eq_req_disable = 0, USP detects eq problem in software or autonomous eq time
                                                    )
                        ) : // ~cfg_gen3_lower_rate_eq_redo_enable
                        ( (set_eq_req_ltx & ltssm_current_data_rate_g3) | 
                          (set_eq_req_rtx_g3 && upstream_component) );
assign set_ls2_g4_eq_req = cfg_gen3_lower_rate_eq_redo_enable ?
                           ( cfg_gen3_eq_req_disable ? ((local_detetct_eq_problem & ltssm_current_data_rate_g4) | (g4_8_eq_req_ts2_rcvd && upstream_component)) : //if cfg_gen3_eq_req_disable = 1, any port detects eq problem or DSP receives eq req
                                                       ((upstream_component && local_detetct_eq_problem && ~auto_eq_phase_flag && ltssm_current_data_rate_g4) || //if cfg_gen3_eq_req_disable = 0, DSP detects eq problem in ~autonomous eq mechanism time
                                                        (upstream_component && g4_8_eq_req_ts2_rcvd_rcvrspd) || //if cfg_gen3_eq_req_disable = 0, DSP receives eq req and speed change is ongoing
                                                        (~upstream_component && local_detetct_eq_problem && ltssm_current_data_rate_g4) //if cfg_gen3_eq_req_disable = 0, USP detects eq problem in software or autonomous eq time
                                                       )
                           ) : // ~cfg_gen3_lower_rate_eq_redo_enable
                           ( (set_eq_req_ltx & ltssm_current_data_rate_g4) | 
                             (set_eq_req_rtx_g4 && upstream_component) );
assign set_ls2_g5_eq_req = cfg_gen3_lower_rate_eq_redo_enable ?
                           ( cfg_gen3_eq_req_disable ? ((local_detetct_eq_problem & ltssm_current_data_rate_g5) | (g5_8_eq_req_ts2_rcvd && upstream_component)) : //if cfg_gen3_eq_req_disable = 1, any port detects eq problem or DSP receives eq req
                                                       ((upstream_component && local_detetct_eq_problem && ~auto_eq_phase_flag && ltssm_current_data_rate_g5) || //if cfg_gen3_eq_req_disable = 0, DSP detects eq problem in ~autonomous eq mechanism time
                                                        (upstream_component && g5_8_eq_req_ts2_rcvd_rcvrspd) || //if cfg_gen3_eq_req_disable = 0, DSP receives eq req and speed change is ongoing
                                                        (~upstream_component && local_detetct_eq_problem && ltssm_current_data_rate_g5) //if cfg_gen3_eq_req_disable = 0, USP detects eq problem in software or autonomous eq time
                                                       )
                           ) : // ~cfg_gen3_lower_rate_eq_redo_enable
                           ( (set_eq_req_ltx & ltssm_current_data_rate_g5) | 
                             (set_eq_req_rtx_g5 && upstream_component) );
assign set_ls2_g6_eq_req = cfg_gen3_lower_rate_eq_redo_enable ?
                           ( cfg_gen3_eq_req_disable ? ((local_detetct_eq_problem & ltssm_current_data_rate_g6) | (g6_8_eq_req_ts2_rcvd && upstream_component)) : //if cfg_gen3_eq_req_disable = 1, any port detects eq problem or DSP receives eq req
                                                       ((upstream_component && local_detetct_eq_problem && ~auto_eq_phase_flag && ltssm_current_data_rate_g6) || //if cfg_gen3_eq_req_disable = 0, DSP detects eq problem in ~autonomous eq mechanism time
                                                        (upstream_component && g6_8_eq_req_ts2_rcvd_rcvrspd) || //if cfg_gen3_eq_req_disable = 0, DSP receives eq req and speed change is ongoing
                                                        (~upstream_component && local_detetct_eq_problem && ltssm_current_data_rate_g6) //if cfg_gen3_eq_req_disable = 0, USP detects eq problem in software or autonomous eq time
                                                       )
                           ) : // ~cfg_gen3_lower_rate_eq_redo_enable
                           ( (set_eq_req_ltx & ltssm_current_data_rate_g6) | 
                             (set_eq_req_rtx_g6 && upstream_component) );

////////////////////////////////////////////////////
// ltssm interface
////////////////////////////////////////////////////
assign eqctl_eq_req_ltx = int_eq_req_ltx & ltssm_quie_gua; // mask the request to the ltssm if there is no quiesce guarantee, needed to go to L0 as normal 
assign eqctl_eq_req_rtx = (int_eq_req_rtx_g3 & ltssm_current_data_rate_g3) | (int_eq_req_rtx_g4 & ltssm_current_data_rate_g4) | (int_eq_req_rtx_g5 & ltssm_current_data_rate_g5)
 | (int_eq_req_rtx_g6 & ltssm_current_data_rate_g6); // mask the request to the ltssm if there is no quiesce guarantee, needed to go to L0 as normal 

assign eqctl_eq_req_redo = eqctl_eq_req_ltx | eqctl_eq_req_rtx;
assign eqctl_eq_done_wo_err = auto_eq_phase_flag && rst_eq_req_ltx_rtx && !int_eq_req_ltx && !int_eq_req_rtx_g3 && !int_eq_req_rtx_g4 && !int_eq_req_rtx_g5
 && !int_eq_req_rtx_g6;
assign eqctl_eq_done_w_err  = auto_eq_phase_flag && rst_eq_req_ltx_rtx && !eqctl_eq_req_redo && !eqctl_eq_done_wo_err; // this signal means 1) detecting local/remote error but suspended by cfg_gen3_eq_req_disable OR 2) speed change fail


endmodule // smlh_eqctl
