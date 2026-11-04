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
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_eqpa.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module provides the pipe equalization interface
// ----------------------------------------------------------------------------

//
// equalization pipe adapter
//
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module smlh_eqpa
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_LPBK_ENTRY;
 import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
 import DWC_pcie_core_pkg::S_RCVRY_EQ0;
 import DWC_pcie_core_pkg::S_RCVRY_EQ1;
 import DWC_pcie_core_pkg::S_RCVRY_EQ2;
 import DWC_pcie_core_pkg::S_RCVRY_EQ3;
 import DWC_pcie_core_pkg::S_RCVRY_SPEED;
#(
    parameter INST = 0, // The uniquifying parameter for each port logic instance
    parameter TP   = `TP,       // Clock to Q delay (simulator insurance)
    parameter NL = `CX_NL,
    parameter FDBK_MODE_WD = 4, //EQ feedback mode bit width
    // constants
    parameter RX_PSET_WD = 3,
    parameter TX_PSET_WD = 4,
    parameter TX_FS_WD = 6,
    parameter TX_FSLF_WD = 2*TX_FS_WD,
    parameter TX_COEF_WD = 3*TX_FS_WD,
    parameter DIRFEEDBACK_WD = `DIRFEEDBACK_WD,
    parameter FOMFEEDBACK_WD = 8,
    parameter PSET_REQ_VEC_WD = 16,
    parameter MIN_TIME_WD = 5,
    parameter N_EVALS_WD = 5, // the number of bits used to define the consecutive evaluation number to determine optimal coefficients (convergence)
    parameter REGIN = 0,
    parameter EQTS_WD = 32, // Number of bits of Per Lane Equalization Information
    parameter TS_0_WD = 48,
    parameter PSET_ID_WD = `PSET_ID_WD
)
(
    input                           core_clk,
    input                           core_rst_n,
    input                           sticky_rst_n,
    input                           ltssm_eq_exit,
    input  [NL-1:0]                 lpbk_eq_lanes_active,
//CDM i/f
    input                           cfg_fast_link_mode,
    input  [1:0]                    cfg_fast_link_scaling_factor,
    input  [FDBK_MODE_WD-1:0]       cfg_gen3_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input  [PSET_REQ_VEC_WD-1:0]    cfg_gen3_eq_pset_req_vector, // = 16'h0: no preset request, bit[i] = 1: preset = i will be as preset request value for Eq Master
    input                           cfg_gen3_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen3_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen3_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input                           cfg_gen3_eq_p23_eval_2ms_extend, //0 - use default 2ms timeout in evaluation waiting for phystatus back. 1 - use 4ms timeout in evaluation
    input                           cfg_gen3_eq_invreq_eval_diff_disable, //0 - invalid_req assertion -> invalid_req deassertion and rxeqeval assertion. 1 - invalid_req and rxeqeval assert/deassert at same cycle
    input                           cfg_gen34_eq_phase23_rxeq_regardless_rxts, //1 - assert RxEqEval regardless Rx TS detected. 0 - assert RxEqEval after Rx TS detect
    input                           cfg_gen3_eq_p23_exit_mode, // 1- LTSSM moves to eq phase 3 for USP or Recovery.RcvrLock for DSP; 0 - to Recovery.Speed after timeout_24ms
    input                           cfg_gen4_eq_p23_exit_mode, // 1- LTSSM moves to eq phase 3 for USP or Recovery.RcvrLock for DSP; 0 - to Recovery.Speed after timeout_24ms
    input  [FDBK_MODE_WD-1:0]       cfg_gen4_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input  [PSET_REQ_VEC_WD-1:0]    cfg_gen4_eq_pset_req_vector, // = 16'h0: no preset request, bit[i] = 1: preset = i will be as preset request value for Eq Master
    input                           cfg_gen4_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen4_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen4_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input                           cfg_gen4_eq_p23_eval_2ms_extend, //0 - use default 2ms timeout in evaluation waiting for phystatus back. 1 - use 4ms timeout in evaluation
    input                           cfg_gen5_eq_p23_exit_mode, // 1- LTSSM moves to eq phase 3 for USP or Recovery.RcvrLock for DSP; 0 - to Recovery.Speed after timeout_24ms
    input                           cfg_gen6_eq_p23_exit_mode, // 1- LTSSM moves to eq phase 3 for USP or Recovery.RcvrLock for DSP; 0 - to Recovery.Speed after timeout_24ms
    input  [FDBK_MODE_WD-1:0]       cfg_gen6_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input  [PSET_REQ_VEC_WD-1:0]    cfg_gen6_eq_pset_req_vector, // = 16'h0: no preset request, bit[i] = 1: preset = i will be as preset request value for Eq Master
    input                           cfg_gen6_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen6_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen6_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input                           cfg_gen6_eq_p23_eval_2ms_extend, //0 - use default 2ms timeout in evaluation waiting for phystatus back. 1 - use 4ms timeout in evaluation
    input  [FDBK_MODE_WD-1:0]       cfg_gen5_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input  [PSET_REQ_VEC_WD-1:0]    cfg_gen5_eq_pset_req_vector, // = 16'h0: no preset request, bit[i] = 1: preset = i will be as preset request value for Eq Master
    input                           cfg_gen5_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen5_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen5_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input                           cfg_gen5_eq_p23_eval_2ms_extend, //0 - use default 2ms timeout in evaluation waiting for phystatus back. 1 - use 4ms timeout in evaluation
    input    [MIN_TIME_WD-1:0]      cfg_gen3_eq_dcm_t_min_phase23, //min time (ms) for eq master to start check of convergence
    input    [N_EVALS_WD-1:0]       cfg_gen3_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input    [N_EVALS_WD-2:0]       cfg_gen3_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input    [N_EVALS_WD-2:0]       cfg_gen3_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input    [MIN_TIME_WD-1:0]      cfg_gen4_eq_dcm_t_min_phase23, //min time (ms) for eq master to start check of convergence
    input    [N_EVALS_WD-1:0]       cfg_gen4_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input    [N_EVALS_WD-2:0]       cfg_gen4_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input    [N_EVALS_WD-2:0]       cfg_gen4_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input    [MIN_TIME_WD-1:0]      cfg_gen5_eq_dcm_t_min_phase23, //min time (ms) for eq master to start check of convergence
    input    [N_EVALS_WD-1:0]       cfg_gen5_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input    [N_EVALS_WD-2:0]       cfg_gen5_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input    [N_EVALS_WD-2:0]       cfg_gen5_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input    [MIN_TIME_WD-1:0]      cfg_gen6_eq_dcm_t_min_phase23, //min time (ms) for eq master to start check of convergence
    input    [N_EVALS_WD-1:0]       cfg_gen6_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input    [N_EVALS_WD-2:0]       cfg_gen6_eq_dcm_max_precursor2_delta,
    input    [N_EVALS_WD-2:0]       cfg_gen6_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input    [N_EVALS_WD-2:0]       cfg_gen6_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input                           cfg_gen3_eq_map_mode_prog,   // enable programmable table
    input    [TX_FSLF_WD-1:0]       cfg_gen3_eq_fs_lf, // programmable FS, LF for Gen3 equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen3_eq_coef,  // programmable coefficients for Gen3 equalization when EQ Slave
    input    [TX_FSLF_WD-1:0]       cfg_gen4_eq_fs_lf, // programmable FS, LF for Gen4 equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen4_eq_coef,  // programmable coefficients for Gen4 equalization when EQ Slave
    input    [TX_FSLF_WD-1:0]       cfg_gen5_eq_fs_lf, // programmable FS, LF for Gen5 equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen5_eq_coef,  // programmable coefficients for Gen5 equalization when EQ Slave
    input    [TX_FSLF_WD-1:0]       cfg_gen6_eq_fs_lf, // programmable FS, LF for Gen5 equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen6_eq_coef,  // programmable coefficients for Gen5 equalization when EQ Slave

    input                           cfg_gen3_req_rst_eiec_disable, // 1 - reset eieos interval count
    input    [NL*EQTS_WD-1:0]       eqctl_eqts_info,               // TS OS Symbols {9, 8, 7, 6}
    input    [NL*TS_0_WD-1:0]       eqctl_eqts_info_ts0,           // TS0 OS Symbols {6, 5, 4, 3, 2, 1}

//ltssm i/f
    input                           ltssm_timeout24ms,
    input  [NL-1:0]                 ltssm_lanes_active, // variable in spec
    input  ltssm_state_e            smlh_ltssm_state_wire,
    input                           ltssm_lpbk_master,
    input                           lpbk_eq_n_lut_pset,
    input  [MIN_TIME_WD-1:0]        ltssm_timer_24ms_cnt, //number of 1ms reached
    input                           ltssm_noeq_nd, // no eq needed
    input  [2:0]                    current_data_rate,
    input  [2:0]                    mac_phy_rate,
    input                           mac_phy_txswing, // transmitter swing

    output                          eqpa_ftune_rtx_optimal, //all active lanes reach optimal settings
    output                          eqpa_fs_out_of_range, // any active lane has local FS value out of range
    output                          eqpa_use_pset_query_done, // all active lanes have query done back for core transmitting TS1s with coeff in use in Phase 0/1
    output                          eqpa_timeout_1us_after_request, // timeout_1us after eq request
    output                          eqpa_fom_rxeq_redardless_rxts, // doing FOM for redardless_rxts
    output                          eqpa_wait_rei_state, // any active lane is in WAIT_REI state
// eqctl i/f - use_pset - Phase-1/0/1
    input  [NL-1:0]                 mac_phy_use_pset, // indicates to use presets to transmit, used when initial change to Gen3 or when redoing Eq
    input  [NL*TX_PSET_WD-1:0]      mac_phy_pset_ltx, // Local Transmitter Preset
    input  [NL*RX_PSET_WD-1:0]      mac_phy_pset_lrx, // Local Receiver Preset Hint
    input  [NL*TX_FSLF_WD-1:0]      mac_phy_fslf_rtx, // Remote Transmitter Full Swing and Low Frequency, concatenation of {LF, FS}
    input  [NL-1:0]                 mac_phy_fslf_rtx_valid, // Remote Transmitter Full Swing and Low Frequency Valid
    output [NL-1:0]                 phy_mac_fslf_ltx_valid, // Local Transmitter Full Swing and Low Frequency Valid
    output [NL*TX_FSLF_WD-1:0]      phy_mac_fslf_ltx, // Local Transmitter Full Swing and Low Frequency, concatenation of {LF, FS}
    output [NL*TX_COEF_WD-1:0]      phy_mac_coef_ltx, // Local Transmitter Coefficients - always reflects electrical settings in use

//pipe i/f
    input  [NL*TX_FS_WD-1:0]        phy_mac_fs, // Local Transmitter Full Swing
    input  [NL*TX_FS_WD-1:0]        phy_mac_lf, // Local Transmitter Low Frequency
    output [NL*TX_COEF_WD-1:0]      eqpa_txdeemph, // Local Transmitter coefficients {C+1, C0, C-1}
    output [NL*RX_PSET_WD-1:0]      mac_phy_rxpresethint, // Local Receiver Preset Hint
    output [NL*TX_FS_WD-1:0]        mac_phy_fs, // FS value advertised by Link partner
    output [NL*TX_FS_WD-1:0]        mac_phy_lf, // LF value advertised by Link partner

//eqctl i/f - ftune_ltx - Phase2/3 as a Slave
    input                           mac_phy_ftune_ltx, // Local Transmitter Fine Tuning State, correspond to Phase 2 for UC, Phase 3 for DC.
    input  [NL-1:0]                 mac_phy_lpbk_ftune_ltx, // Local Transmitter Fine Tuning State, correspond to Loopback slave for receiving TS1 EC=2'b01 or 2'b11
    input  [NL*TX_COEF_WD-1:0]      mac_phy_coef_ltx, // already used for use_pset i/f
    input  [NL-1:0]                 mac_phy_pset_ltx_upd, // Local Transmitter Preset Update - active until accept/reject flag is asserted
    input  [NL-1:0]                 mac_phy_coef_ltx_upd, // Local Transmitter Coefficients Update - active until accept/reject flag is asserted
    output [NL-1:0]                 phy_mac_accept_ltx, // Local Transmitter Preset/Coefficients Accept Flag
    output [NL-1:0]                 phy_mac_reject_ltx, // Local Transmitter Preset/Coefficients reject Flag

//eqctl i/f - ftune_rtx - Phase2/3 as a Master
    input                           mac_phy_ftune_rtx, // Remote Transmitter Fine Tuning State, correspond to Phase 2 for DC, Phase 3 for UC
    input  [NL-1:0]                 mac_phy_reject_rtx, // Remote Transmitter Coefficients Reject Flag
    input  [NL-1:0]                 mac_phy_accept_rtx, // Remote Transmitter Preset/Coefficients Accept Flag
    input  [NL*TX_COEF_WD-1:0]      mac_phy_coef_rtx, // Remote Transmitter Coefficients, concatenation of {C+1, C0, C-1}
    input  [NL*TX_PSET_WD-1:0]      mac_phy_pset_rtx, // Remote Transmitter Preset
    output [NL*TX_PSET_WD-1:0]      phy_mac_pset_rtx, // Remote Transmitter Request Preset
    output [NL*TX_COEF_WD-1:0]      phy_mac_coef_rtx, // Remote Transmitter requested Coefficients, concatenation of {C+1, C0, C-1}
    output [NL-1:0]                 phy_mac_ftune_rtx_done, // Remote Transmitter Fine Tuning Complete
    output [NL-1:0]                 phy_mac_ftune_rtx_optimal, // Remote Transmitter Fine Tuning reaches Optimal Settings
    output [NL-1:0]                 phy_mac_coef_rtx_upd, // Remote Transmitter Coefficients Update - active until accept/reject/timeout flag is asserted
    output [NL-1:0]                 phy_mac_pset_rtx_upd, // Remote Transmitter Preset Update - active until accept/reject/timeout flag is asserted

// pipe i/f
    input  [NL-1:0]                 phy_mac_phystatus, // 1 - PHY completed remote Transmitter EQ evaluation
    input  [NL*DIRFEEDBACK_WD-1:0]  phy_mac_dirfeedback, // direction feedback
    input  [NL*FOMFEEDBACK_WD-1:0]  phy_mac_fomfeedback, // figure of merit feedback
    input  [NL*TX_COEF_WD-1:0]      phy_mac_local_tx_pset_coef, //mapped coef
    input  [NL-1:0]                 phy_mac_local_tx_coef_valid, //1 - mapped coef valid
    output [NL-1:0]                 mac_phy_getlocal_pset_coef, // 1 - local preset valid
    output [NL*PSET_ID_WD-1:0]      mac_phy_local_pset_index, //local preset
    output [NL-1:0]                 mac_phy_rxeqinprogress, // tell PHY now is in Master request Phase
    output [NL-1:0]                 mac_phy_invalid_req, // 1 - Invalid remote Transmitter EQ request
    output [NL-1:0]                 mac_phy_rxeqeval, // 1 - tell PHY doing remote Transmitter EQ evaluation
    output [NL-1:0]                 mac_phy_dirchange // 1 - tell PHY doing remote Transmitter EQ DIR evaluation
    ,
    input                           ltssm_timeout10ms, // 10ms coefficient evaluation timeout
    input                           cdm_ras_des_eq_fom_target_en, // Figure Of Merit Target enable
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_rtx_en, // Force Remote Transmitter Coefficient enable
    input  [NL-1:0]                 cdm_ras_des_eq_force_pset_lrx_en, // Force Local Receiver Preset Hint enable
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_ltx_en, // Force Local Transmitter Preset enable
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_ltx, // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input  [NL*RX_PSET_WD-1:0]      cdm_ras_des_eq_force_pset_lrx, // Force Local Receiver RxPresetHint
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_rtx, // Remote Transmitter cursor coefficient for Ras D.E.S Silicon Debug EQ Control
    input  [FOMFEEDBACK_WD-1:0]     cdm_ras_des_eq_fom_target, // FOM Target value for Ras D.E.S Silicon Debug EQ Control
    input  [1:0]                    cdm_ras_des_eq_eval_interval, // EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_fs, // monitoring the current EQ status
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_lf,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_ltx,
    output [NL*RX_PSET_WD-1:0]      mac_cdm_ras_des_pset_lrx,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_rtx,
    output [NL-1:0]                 mac_cdm_ras_des_reject_rtx,
    output [NL*FOMFEEDBACK_WD-1:0]  phy_cdm_ras_des_fomfeedback,
    output [NL*3-1:0]               eqpa_violate_rule_123, // Remote transmitter Coefficient rule violation status rule a/b/c
    output [NL*2-1:0]               eq_convergence_sts // EQ sequence status, 0: not finished, 1: finished successfully, 2: finished unsuccessfully
    ,
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_rtx_en_g4,
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_ltx_en_g4,
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_ltx_g4,
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_rtx_g4,
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_fs_g4,
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_lf_g4,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_ltx_g4,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_rtx_g4,
    output [NL-1:0]                 mac_cdm_ras_des_reject_rtx_g4,
    output [NL*FOMFEEDBACK_WD-1:0]  phy_cdm_ras_des_fomfeedback_g4,
    output [NL*3-1:0]               eqpa_violate_rule_123_g4,
    output [NL*2-1:0]               eq_convergence_sts_g4
    ,
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_rtx_en_g5,
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_ltx_en_g5,
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_ltx_g5,
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_rtx_g5,
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_fs_g5,
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_lf_g5,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_ltx_g5,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_rtx_g5,
    output [NL-1:0]                 mac_cdm_ras_des_reject_rtx_g5,
    output [NL*FOMFEEDBACK_WD-1:0]  phy_cdm_ras_des_fomfeedback_g5,
    output [NL*3-1:0]               eqpa_violate_rule_123_g5,
    output [NL*2-1:0]               eq_convergence_sts_g5
    ,
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_rtx_en_g6,
    input  [NL-1:0]                 cdm_ras_des_eq_force_coef_ltx_en_g6,
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_ltx_g6,
    input  [NL*TX_COEF_WD-1:0]      cdm_ras_des_eq_force_coef_rtx_g6,
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_fs_g6,
    output [NL*TX_FS_WD-1:0]        mac_cdm_ras_des_lf_g6,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_ltx_g6,
    output [NL*TX_COEF_WD-1:0]      mac_cdm_ras_des_coef_rtx_g6,
    output [NL-1:0]                 mac_cdm_ras_des_reject_rtx_g6,
    output [NL*FOMFEEDBACK_WD-1:0]  phy_cdm_ras_des_fomfeedback_g6,
    output [NL*3-1:0]               eqpa_violate_rule_123_g6,
    output [NL-1:0]                 eqpa_violate_rule_4_g6,
    output [NL*2-1:0]               eq_convergence_sts_g6
);

parameter  TIMER_2MS_WIDTH=22;
parameter  TIMER_4MS_WIDTH= TIMER_2MS_WIDTH + 1;

ltssm_state_e                       ltssm_state ;
reg  [TIMER_4MS_WIDTH-1:0]          timer_4ms;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen3;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen3_8gt;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen3_16gt;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen4;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen4_20gt;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen4_25gt;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen5;
wire [TIMER_2MS_WIDTH-1:0]          fast_time_2ms_gen6;
reg                  timeout_2ms;
reg                  timeout_4ms;
reg                  timeout_1us;
reg                  timeout_500ns;
reg                  min_phase23_timeout;
wire [NL-1:0]        ts1_detected_bus;
wire [NL-1:0]        fom_rxeq_redardless_rxts_bus;
wire [NL-1:0]        eqpa_clr_phystatus_bus;
wire [NL-1:0]        eqpa_clr_2ms_timer_bus;
wire                 eqpa_clr_2ms_timer;
wire                 eqpa_clr_phystatus;
reg  [NL-1:0]        phystatus_asserted;
wire                 phystatus_asserted_all;
wire                 ltssm_lpbkentry_act_slave;
wire [NL-1:0]        abort_bus;
wire [NL-1:0]        eqpa_slv_set_bus;
wire [NL-1:0]        fs_out_of_range_bus;
wire [NL-1:0]        mac_phy_rxeqeval_i;
wire [NL-1:0]        mac_phy_invalid_req_i;
wire [NL-1:0]        mac_phy_rxeqinprogress_i;
wire [NL-1:0]        mac_phy_getlocal_pset_coef_i;
wire                 rxeqeval_all;
wire [NL-1:0]                 int_phy_mac_phystatus; // 1 - PHY completed remote Transmitter EQ evaluation
wire [NL*DIRFEEDBACK_WD-1:0]  int_phy_mac_dirfeedback; // direction feedback
wire [NL*FOMFEEDBACK_WD-1:0]  int_phy_mac_fomfeedback; // figure of merit feedback
wire [NL*TX_COEF_WD-1:0]      int_phy_mac_local_tx_pset_coef; //mapped coef
wire [NL-1:0]                 int_phy_mac_local_tx_coef_valid; //mapped coef is valid
wire [NL*TX_FS_WD-1:0]        int_phy_mac_fs; // Local Transmitter Full Swing
wire [NL*TX_FS_WD-1:0]        int_phy_mac_lf; // Local Transmitter Low Frequency
wire                 eqctl_rst_eieos;
reg  [NL-1:0]        eqctl_rst_eieos_i; // reset_eieos_interval_count bit in TS OS Symbol 6 bit 2
wire                 ts1_detected_all; // detect TS1s on all lanes || optimal || timeout_2ms
wire [NL-1:0]        wait_rei_state; // in S_WAIT_REI state
wire                 g1_rate = current_data_rate == `GEN1_RATE;
wire                 g2_rate = current_data_rate == `GEN2_RATE;
wire                 g3_rate = current_data_rate == `GEN3_RATE;
wire                 g4_rate = current_data_rate == `GEN4_RATE;
wire                 g5_rate = current_data_rate == `GEN5_RATE;
wire                 g6_rate = current_data_rate == `GEN6_RATE;
wire crnt_rate_gen3 = g3_rate;
wire crnt_rate_gen4 = g4_rate;
wire crnt_rate_gen5 = g5_rate;
wire crnt_rate_gen6 = g6_rate;

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

wire cfg_p23_exit_mode = (g6_rate) ? cfg_gen6_eq_p23_exit_mode : (g5_rate) ? cfg_gen5_eq_p23_exit_mode : (g4_rate) ? cfg_gen4_eq_p23_exit_mode : cfg_gen3_eq_p23_exit_mode;

wire cfg_eq_p23_eval_2ms_extend = (g6_rate) ? cfg_gen6_eq_p23_eval_2ms_extend : 
 (g5_rate) ? cfg_gen5_eq_p23_eval_2ms_extend :  
 (g4_rate) ? cfg_gen4_eq_p23_eval_2ms_extend : cfg_gen3_eq_p23_eval_2ms_extend;
wire timeout_2_4ms = cfg_eq_p23_eval_2ms_extend ? timeout_4ms : timeout_2ms;

always @( * ) begin : eqctl_rst_eieos_i_PROC //extract rst_eieos bit
    integer m;

    eqctl_rst_eieos_i = 0;
    for (m=0; m<NL; m=m+1) begin
        eqctl_rst_eieos_i[m] = eqctl_eqts_info[m*EQTS_WD + 2];
    end
end //eqctl_rst_eieos_i_PROC
assign eqctl_rst_eieos = |(ltssm_lanes_active & eqctl_rst_eieos_i);

assign mac_phy_rxeqeval = ltssm_lanes_active & mac_phy_rxeqeval_i;
assign mac_phy_invalid_req = ltssm_lanes_active & mac_phy_invalid_req_i;
assign mac_phy_rxeqinprogress = ltssm_lanes_active & mac_phy_rxeqinprogress_i;
assign mac_phy_getlocal_pset_coef = ltssm_lanes_active & mac_phy_getlocal_pset_coef_i;

localparam N_DELAY_CYLES = REGIN ? 1 : 0;
localparam DATAPATH_WIDTH = 2*NL + NL*DIRFEEDBACK_WD + NL*FOMFEEDBACK_WD + NL*TX_COEF_WD + 2*NL*TX_FS_WD;
delay_n
 #(N_DELAY_CYLES, DATAPATH_WIDTH) u_delay
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (
                  { phy_mac_phystatus,
                    phy_mac_dirfeedback, phy_mac_fomfeedback,
                    phy_mac_local_tx_pset_coef, phy_mac_local_tx_coef_valid,
                    phy_mac_fs, phy_mac_lf
                  }
                ),
    .dout       (
                  { int_phy_mac_phystatus,
                    int_phy_mac_dirfeedback, int_phy_mac_fomfeedback,
                    int_phy_mac_local_tx_pset_coef, int_phy_mac_local_tx_coef_valid,
                    int_phy_mac_fs, int_phy_mac_lf
                  }
                 )
);

// all active lanes have rxeqeval asserted but optimal lanes
assign rxeqeval_all =                             &(~ltssm_lanes_active | phy_mac_ftune_rtx_optimal | mac_phy_rxeqeval_i | eqpa_slv_set_bus);

// any active lane has local FS value out of range
assign eqpa_fs_out_of_range = |(ltssm_lanes_active & fs_out_of_range_bus);

// all active lanes reach optimal settings
assign eqpa_ftune_rtx_optimal = &(~ltssm_lanes_active | phy_mac_ftune_rtx_optimal);

// all active lanes got query done back
assign eqpa_use_pset_query_done = &(~ltssm_lanes_active | phy_mac_accept_ltx | phy_mac_reject_ltx);

assign ts1_detected_all = &(~ltssm_lanes_active | ts1_detected_bus | phy_mac_ftune_rtx_optimal) | timeout_2_4ms;

assign eqpa_fom_rxeq_redardless_rxts = |(ltssm_lanes_active & fom_rxeq_redardless_rxts_bus);

// if any lane's state is S_INIT or S_REQUEST or abort, do clear timer_2ms and phystatus_asserted.
// if any lane doesn't get accept/reject response from remote partner in 2ms,
// clear timer_2ms and restore previous valid coefficients then do a new request
assign eqpa_clr_phystatus = |(ltssm_lanes_active & eqpa_clr_phystatus_bus);
assign eqpa_clr_2ms_timer = |(ltssm_lanes_active & eqpa_clr_2ms_timer_bus);

// spyglass disable_block W486
// SMD: Reports shift overflow operations
// SJ: Maximum value of CX_FAST_TIME_xxx is 21'h800. Overflow does not occur even if the value is shifted by 6 bits. 
assign fast_time_2ms_gen3 = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_GEN3_2MS :
                            (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_GEN3_2MS << 2) :
                            (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_GEN3_2MS << 4) :
                                                                    (`CX_FAST_TIME_GEN3_2MS << 6) ;
assign fast_time_2ms_gen4 = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_GEN4_2MS :
                            (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_GEN4_2MS << 2) :
                            (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_GEN4_2MS << 4) :
                                                                    (`CX_FAST_TIME_GEN4_2MS << 6) ;
assign fast_time_2ms_gen5 = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_GEN5_2MS :
                            (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_GEN5_2MS << 2) :
                            (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_GEN5_2MS << 4) :
                                                                    (`CX_FAST_TIME_GEN5_2MS << 6) ;
assign fast_time_2ms_gen6 = (cfg_fast_link_scaling_factor==2'b00) ? `CX_FAST_TIME_GEN6_2MS :
                            (cfg_fast_link_scaling_factor==2'b01) ? (`CX_FAST_TIME_GEN6_2MS << 2) :
                            (cfg_fast_link_scaling_factor==2'b10) ? (`CX_FAST_TIME_GEN6_2MS << 4) :
                                                                    (`CX_FAST_TIME_GEN6_2MS << 6) ;

wire [TIMER_4MS_WIDTH-1:0] crnt_rate_2ms_expir_time;
wire [TIMER_4MS_WIDTH-1:0] crnt_rate_4ms_expir_time;
// 2ms timer expire value selection for current rate
assign crnt_rate_2ms_expir_time = {TIMER_4MS_WIDTH{
 crnt_rate_gen6 ? (cfg_fast_link_mode ? fast_time_2ms_gen6 << cdm_ras_des_eq_eval_interval : `CX_TIME_GEN6_2MS) :
 crnt_rate_gen5 ? (cfg_fast_link_mode ? fast_time_2ms_gen5 << cdm_ras_des_eq_eval_interval : `CX_TIME_GEN5_2MS) :
                         crnt_rate_gen4 ? (cfg_fast_link_mode ? fast_time_2ms_gen4 << cdm_ras_des_eq_eval_interval :  `CX_TIME_GEN4_2MS) :
                                           (cfg_fast_link_mode ? fast_time_2ms_gen3 << cdm_ras_des_eq_eval_interval :  `CX_TIME_GEN3_2MS)}} ;

//4ms expire value = x2 of 2ms
assign crnt_rate_4ms_expir_time = crnt_rate_2ms_expir_time << 1;

// spyglass enable_block W486

// 2ms timeout ticks from request for remote partner through evaluation until its complete
// cleared when any lane's state is S_INIT or S_REQUEST
always @(posedge core_clk or negedge core_rst_n) begin : timer_2ms_seq_PROC
    if( !core_rst_n ) begin
        timer_4ms     <= #TP '0;
        timeout_4ms   <= #TP '0;
        timeout_2ms   <= #TP '0;
        timeout_1us   <= #TP '0;
        timeout_500ns <= #TP '0;
    end else begin
        if ( eqpa_clr_2ms_timer ) begin
            timer_4ms     <= #TP '0;
            timeout_4ms   <= #TP '0;
            timeout_2ms   <= #TP '0;
            timeout_1us   <= #TP '0;
            timeout_500ns <= #TP '0;
        end else begin
            timer_4ms <= #TP timer_4ms + 1;

          if ( (crnt_rate_gen3 && timer_4ms >= `CX_TIME_GEN3_500NS << cdm_ras_des_eq_eval_interval ) 
             ||  (crnt_rate_gen4 && timer_4ms >= `CX_TIME_GEN4_500NS << cdm_ras_des_eq_eval_interval ) 
             ||  (crnt_rate_gen5 && timer_4ms >= `CX_TIME_GEN5_500NS << cdm_ras_des_eq_eval_interval ) 
             ||  (crnt_rate_gen6 && timer_4ms >= `CX_TIME_GEN6_500NS << cdm_ras_des_eq_eval_interval ) 
             ) begin
                timeout_500ns <= #TP 1;
            end

            if (   (crnt_rate_gen3 && timer_4ms == `CX_TIME_GEN3_1US) 
                || (crnt_rate_gen4 && timer_4ms == `CX_TIME_GEN4_1US) 
                || (crnt_rate_gen5 && timer_4ms == `CX_TIME_GEN5_1US)
                || (crnt_rate_gen6 && timer_4ms == `CX_TIME_GEN6_1US)
               ) begin
                timeout_1us <= #TP 1;
            end

            if(timer_4ms == crnt_rate_2ms_expir_time) begin
                timeout_2ms <= #TP 1;
            end
            if(timer_4ms == crnt_rate_4ms_expir_time) begin
                timeout_4ms <= #TP 1;
                timer_4ms <= #TP '0;
            end

        end
    end
end






assign eqpa_timeout_1us_after_request   = timeout_1us;

// min_phase23_timeout is triggered when ltssm_timer_24ms_cnt hits cfg_gen3_eq_dcm_t_min_phase23
always @(posedge core_clk or negedge core_rst_n) begin : min_phase23_timeout_PROC
    if ( !core_rst_n ) begin
        min_phase23_timeout <= #TP '0;
    end else if ( !mac_phy_ftune_rtx ) begin
        //if not in fine tune for remote partner (! eq master), clear min_phase23_timeout
        min_phase23_timeout <= #TP '0;
    end else if ( ((g3_rate ) && (ltssm_timer_24ms_cnt == cfg_gen3_eq_dcm_t_min_phase23)) ||
                  ((g6_rate ) && (ltssm_timer_24ms_cnt == cfg_gen6_eq_dcm_t_min_phase23)) ||
                  ((g5_rate ) && (ltssm_timer_24ms_cnt == cfg_gen5_eq_dcm_t_min_phase23)) ||
                  ((g4_rate ) && (ltssm_timer_24ms_cnt == cfg_gen4_eq_dcm_t_min_phase23)) ) begin
        //if ltssm_timer_24ms_cnt hits cfg_gen3_eq_dcm_t_min_phase23, min_phase23_timeout gets set
        min_phase23_timeout <= #TP 1;
    end
end //always @(posedge core_clk

// phystatus_asserted is used to get all active lanes having phystatus coming back but
// lanes achieved optimal, then move to next state
always @(posedge core_clk or negedge core_rst_n) begin : collect_phystatus_assertions_PROC
    integer ln;

    if (!core_rst_n) begin
        phystatus_asserted                <= #TP {NL{1'b1}};
    end else if (eqpa_clr_phystatus) begin
        phystatus_asserted                <= #TP {NL{1'b0}};
    end else begin
        for (ln=0; ln<NL; ln=ln+1) begin
                if (int_phy_mac_phystatus[ln] || eqpa_slv_set_bus[ln])
                    phystatus_asserted[ln]    <= #TP 1'b1;
        end
    end
end

//have to wait all active lanes phystatus back or optimal.
//doing so is for All new preset or coefficient settings must be presented on all configured Lanes simultaneously.
assign phystatus_asserted_all = &(~ltssm_lanes_active | phystatus_asserted | phy_mac_ftune_rtx_optimal);

//S_LPBK_ACTIVE is added here for PHY to map pset-coef back later than S_LPBK_ENTRY exit as LTSSM moves to S_LPBK_ACTIVE
//once receiving 2 TS1s. Its safe as eqctl issues pset/coef_upd only in S_LPBK_ENTRY
assign ltssm_lpbkentry_act_slave = (!ltssm_lpbk_master && (ltssm_state==S_LPBK_ENTRY || ltssm_state==S_LPBK_ACTIVE));

localparam COEFQ_DEPTH = `CX_GEN3_EQ_COEFQ_DEPTH; // coefficient queue depth
wire [N_EVALS_WD-1:0] cfg_gen3_eq_dcm_n_evals_int; // clamp the value to protect from illegal programming
assign cfg_gen3_eq_dcm_n_evals_int = (cfg_gen3_eq_dcm_n_evals > COEFQ_DEPTH) ? COEFQ_DEPTH : cfg_gen3_eq_dcm_n_evals;
wire [N_EVALS_WD-1:0] cfg_gen4_eq_dcm_n_evals_int; // clamp the value to protect from illegal programming
assign cfg_gen4_eq_dcm_n_evals_int = (cfg_gen4_eq_dcm_n_evals > COEFQ_DEPTH) ? COEFQ_DEPTH : cfg_gen4_eq_dcm_n_evals;
wire [N_EVALS_WD-1:0] cfg_gen6_eq_dcm_n_evals_int; // clamp the value to protect from illegal programming
assign cfg_gen6_eq_dcm_n_evals_int = (cfg_gen6_eq_dcm_n_evals > COEFQ_DEPTH) ? COEFQ_DEPTH : cfg_gen6_eq_dcm_n_evals;
wire [N_EVALS_WD-1:0] cfg_gen5_eq_dcm_n_evals_int; // clamp the value to protect from illegal programming
assign cfg_gen5_eq_dcm_n_evals_int = (cfg_gen5_eq_dcm_n_evals > COEFQ_DEPTH) ? COEFQ_DEPTH : cfg_gen5_eq_dcm_n_evals;

assign eqpa_wait_rei_state = |(wait_rei_state & ltssm_lanes_active);


//instance of eqpa single lane version
smlh_eqpa_slv

#(INST) u_smlh_eqpa_slv[NL-1:0]
(
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .sticky_rst_n               (sticky_rst_n),
    .ltssm_eq_exit              (ltssm_eq_exit),
    .lpbk_eq_lanes_active       (lpbk_eq_lanes_active),
//CDM i/f
    .cfg_p23_exit_mode                    (cfg_p23_exit_mode),
    .cfg_gen3_eq_feedback_mode            (cfg_gen3_eq_feedback_mode),
    .cfg_gen3_eq_pset_req_vector          (cfg_gen3_eq_pset_req_vector),
    .cfg_gen3_eq_pset_req_as_coef         (cfg_gen3_eq_pset_req_as_coef),
    .cfg_gen3_eq_fom_include_init_eval    (cfg_gen3_eq_fom_include_init_eval),
    .cfg_gen3_eq_p23_eval_timeout_2ms_disable (cfg_gen3_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen3_eq_invreq_eval_diff_disable (cfg_gen3_eq_invreq_eval_diff_disable),
    .cfg_gen34_eq_phase23_rxeq_regardless_rxts (cfg_gen34_eq_phase23_rxeq_regardless_rxts),
    .cfg_gen4_eq_feedback_mode            (cfg_gen4_eq_feedback_mode),
    .cfg_gen4_eq_pset_req_vector          (cfg_gen4_eq_pset_req_vector),
    .cfg_gen4_eq_pset_req_as_coef         (cfg_gen4_eq_pset_req_as_coef),
    .cfg_gen4_eq_fom_include_init_eval    (cfg_gen4_eq_fom_include_init_eval),
    .cfg_gen4_eq_p23_eval_timeout_2ms_disable (cfg_gen4_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen5_eq_feedback_mode            (cfg_gen5_eq_feedback_mode),
    .cfg_gen5_eq_pset_req_vector          (cfg_gen5_eq_pset_req_vector),
    .cfg_gen5_eq_pset_req_as_coef         (cfg_gen5_eq_pset_req_as_coef),
    .cfg_gen5_eq_fom_include_init_eval    (cfg_gen5_eq_fom_include_init_eval),
    .cfg_gen5_eq_p23_eval_timeout_2ms_disable (cfg_gen5_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen6_eq_feedback_mode            (cfg_gen6_eq_feedback_mode),
    .cfg_gen6_eq_pset_req_vector          (cfg_gen6_eq_pset_req_vector),
    .cfg_gen6_eq_pset_req_as_coef         (cfg_gen6_eq_pset_req_as_coef),
    .cfg_gen6_eq_fom_include_init_eval    (cfg_gen6_eq_fom_include_init_eval),
    .cfg_gen6_eq_p23_eval_timeout_2ms_disable (cfg_gen6_eq_p23_eval_timeout_2ms_disable),
    .cfg_gen3_eq_dcm_n_evals              (cfg_gen3_eq_dcm_n_evals_int),
    .cfg_gen3_eq_dcm_max_precursor_delta  (cfg_gen3_eq_dcm_max_precursor_delta),
    .cfg_gen3_eq_dcm_max_postcursor_delta (cfg_gen3_eq_dcm_max_postcursor_delta),
    .cfg_gen4_eq_dcm_n_evals              (cfg_gen4_eq_dcm_n_evals_int),
    .cfg_gen4_eq_dcm_max_precursor_delta  (cfg_gen4_eq_dcm_max_precursor_delta),
    .cfg_gen4_eq_dcm_max_postcursor_delta (cfg_gen4_eq_dcm_max_postcursor_delta),
    .cfg_gen5_eq_dcm_n_evals              (cfg_gen5_eq_dcm_n_evals_int),
    .cfg_gen5_eq_dcm_max_precursor_delta  (cfg_gen5_eq_dcm_max_precursor_delta),
    .cfg_gen5_eq_dcm_max_postcursor_delta (cfg_gen5_eq_dcm_max_postcursor_delta),
    .cfg_gen6_eq_dcm_n_evals              (cfg_gen6_eq_dcm_n_evals_int),
    .cfg_gen6_eq_dcm_max_precursor2_delta (cfg_gen6_eq_dcm_max_precursor2_delta),
    .cfg_gen6_eq_dcm_max_precursor_delta  (cfg_gen6_eq_dcm_max_precursor_delta),
    .cfg_gen6_eq_dcm_max_postcursor_delta (cfg_gen6_eq_dcm_max_postcursor_delta),

    .cfg_gen3_req_rst_eiec_disable        (cfg_gen3_req_rst_eiec_disable),
    .eqctl_rst_eieos                      (eqctl_rst_eieos),
    // ltssm i/f
    .ltssm_timeout24ms          (ltssm_timeout24ms),
    .ltssm_lanes_active         (ltssm_lanes_active),
    .lpbk_eq_n_lut_pset         (lpbk_eq_n_lut_pset),
    .ltssm_noeq_nd              (ltssm_noeq_nd),
    .current_data_rate          (current_data_rate),
    .ltssm_lpbkentry_act_slave  (ltssm_lpbkentry_act_slave),
    .mac_phy_rate               (mac_phy_rate),
    .mac_phy_txswing            (mac_phy_txswing),
    .fs_out_of_range            (fs_out_of_range_bus),

//coef req for FOM interface

    // eqctl i/f - use_pset - Phase-1/0/1
//input
    .mac_phy_use_pset           (mac_phy_use_pset),
    .mac_phy_pset_ltx           (mac_phy_pset_ltx),
    .mac_phy_pset_lrx           (mac_phy_pset_lrx),
    .mac_phy_fslf_rtx           (mac_phy_fslf_rtx),
    .mac_phy_fslf_rtx_valid     (mac_phy_fslf_rtx_valid),
//output
    .phy_mac_fslf_ltx_valid     (phy_mac_fslf_ltx_valid),
    .phy_mac_fslf_ltx           (phy_mac_fslf_ltx),
    .phy_mac_coef_ltx           (phy_mac_coef_ltx),

    // pipe i/f
//input
    .cfg_gen3_eq_map_mode_prog  (cfg_gen3_eq_map_mode_prog),
    .cfg_gen3_eq_fs_lf          (cfg_gen3_eq_fs_lf),
    .cfg_gen3_eq_coef           (cfg_gen3_eq_coef),
    .cfg_gen4_eq_fs_lf          (cfg_gen4_eq_fs_lf),
    .cfg_gen4_eq_coef           (cfg_gen4_eq_coef),
    .cfg_gen5_eq_fs_lf          (cfg_gen5_eq_fs_lf),
    .cfg_gen5_eq_coef           (cfg_gen5_eq_coef),
    .cfg_gen6_eq_fs_lf          (cfg_gen6_eq_fs_lf),
    .cfg_gen6_eq_coef           (cfg_gen6_eq_coef),
    .phy_mac_fs                 (int_phy_mac_fs),
    .phy_mac_lf                 (int_phy_mac_lf),
//output
    .mac_phy_txdeemph           (eqpa_txdeemph),
    .mac_phy_rxpresethint       (mac_phy_rxpresethint),
    .mac_phy_fs                 (mac_phy_fs),
    .mac_phy_lf                 (mac_phy_lf),

    // eqctl i/f - ftune_ltx - Phase2/3 as a Slave
//input
    .mac_phy_ftune_ltx          (mac_phy_ftune_ltx),
    .mac_phy_lpbk_ftune_ltx     (mac_phy_lpbk_ftune_ltx),
    .mac_phy_coef_ltx           (mac_phy_coef_ltx),
    .mac_phy_pset_ltx_upd       (mac_phy_pset_ltx_upd),
    .mac_phy_coef_ltx_upd       (mac_phy_coef_ltx_upd),
//output
    .phy_mac_accept_ltx         (phy_mac_accept_ltx),
    .phy_mac_reject_ltx         (phy_mac_reject_ltx),

    // eqctl i/f - ftune_rtx - Phase2/3 as a Master
//input
    .mac_phy_ftune_rtx          (mac_phy_ftune_rtx),
    .mac_phy_reject_rtx         (mac_phy_reject_rtx),
    .mac_phy_accept_rtx         (mac_phy_accept_rtx),
    .mac_phy_coef_rtx           (mac_phy_coef_rtx),
    .mac_phy_pset_rtx           (mac_phy_pset_rtx),
//output
    .phy_mac_pset_rtx           (phy_mac_pset_rtx),
    .phy_mac_coef_rtx           (phy_mac_coef_rtx),
    .phy_mac_ftune_rtx_done     (phy_mac_ftune_rtx_done),
    .phy_mac_ftune_rtx_optimal  (phy_mac_ftune_rtx_optimal),
    .phy_mac_coef_rtx_upd       (phy_mac_coef_rtx_upd),
    .phy_mac_pset_rtx_upd       (phy_mac_pset_rtx_upd),

    // pipe i/f
//input
    .phystatus_asserted          (phystatus_asserted),
    .phy_mac_phystatus           (int_phy_mac_phystatus),
    .phy_mac_dirfeedback         (int_phy_mac_dirfeedback),
    .phy_mac_fomfeedback         (int_phy_mac_fomfeedback),
    .phy_mac_local_tx_pset_coef  (int_phy_mac_local_tx_pset_coef),
    .phy_mac_local_tx_coef_valid (int_phy_mac_local_tx_coef_valid),
//output
    .mac_phy_rxeqinprogress     (mac_phy_rxeqinprogress_i),
    .mac_phy_invalid_req        (mac_phy_invalid_req_i),
    .mac_phy_rxeqeval           (mac_phy_rxeqeval_i),
    .mac_phy_dirchange          (mac_phy_dirchange),
    .mac_phy_getlocal_pset_coef (mac_phy_getlocal_pset_coef_i),
    .mac_phy_local_pset_index   (mac_phy_local_pset_index),

    // eqpa i/f
//input
    .phystatus_asserted_all     (phystatus_asserted_all),
    .timeout_2ms                (timeout_2ms),
    .timeout_2_4ms              (timeout_2_4ms),
    .timeout_1us                (timeout_1us),
    .timeout_500ns              (timeout_500ns),
    .min_phase23_timeout        (min_phase23_timeout),
    .rxeqeval_all               (rxeqeval_all),
    .ts1_detected_all           (ts1_detected_all),
//output
    .abort                      (abort_bus),
    .eqpa_slv_set               (eqpa_slv_set_bus),
    .fom_rxeq_redardless_rxts   (fom_rxeq_redardless_rxts_bus),
    .ts1_detected               (ts1_detected_bus),
    .wait_rei_state             (wait_rei_state),
    .eqpa_slv_clr_phystatus     (eqpa_clr_phystatus_bus),
    .eqpa_slv_clr_2ms_timer     (eqpa_clr_2ms_timer_bus)
    ,
// inputs
    .ltssm_timeout10ms          (ltssm_timeout10ms),
    .cdm_ras_des_eq_fom_target_en       (cdm_ras_des_eq_fom_target_en),
    .cdm_ras_des_eq_force_coef_rtx_en (cdm_ras_des_eq_force_coef_rtx_en),
    .cdm_ras_des_eq_force_pset_lrx_en (cdm_ras_des_eq_force_pset_lrx_en),
    .cdm_ras_des_eq_force_coef_ltx_en (cdm_ras_des_eq_force_coef_ltx_en),
    .cdm_ras_des_eq_force_coef_ltx   (cdm_ras_des_eq_force_coef_ltx),
    .cdm_ras_des_eq_force_pset_lrx   (cdm_ras_des_eq_force_pset_lrx),
    .cdm_ras_des_eq_force_coef_rtx   (cdm_ras_des_eq_force_coef_rtx),
    .cdm_ras_des_eq_fom_target       (cdm_ras_des_eq_fom_target),
//output
    .mac_cdm_ras_des_fs         (mac_cdm_ras_des_fs),
    .mac_cdm_ras_des_lf         (mac_cdm_ras_des_lf),
    .mac_cdm_ras_des_coef_ltx   (mac_cdm_ras_des_coef_ltx),
    .mac_cdm_ras_des_pset_lrx   (mac_cdm_ras_des_pset_lrx),
    .mac_cdm_ras_des_coef_rtx   (mac_cdm_ras_des_coef_rtx),
    .mac_cdm_ras_des_reject_rtx (mac_cdm_ras_des_reject_rtx),
    .phy_cdm_ras_des_fomfeedback (phy_cdm_ras_des_fomfeedback),
    .eqpa_violate_rule_123      (eqpa_violate_rule_123),
    .eq_convergence_sts         (eq_convergence_sts)
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g4 (cdm_ras_des_eq_force_coef_rtx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_en_g4 (cdm_ras_des_eq_force_coef_ltx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_g4(cdm_ras_des_eq_force_coef_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_g4(cdm_ras_des_eq_force_coef_rtx_g4),
    .mac_cdm_ras_des_fs_g4      (mac_cdm_ras_des_fs_g4),
    .mac_cdm_ras_des_lf_g4      (mac_cdm_ras_des_lf_g4),
    .mac_cdm_ras_des_coef_ltx_g4 (mac_cdm_ras_des_coef_ltx_g4),
    .mac_cdm_ras_des_coef_rtx_g4 (mac_cdm_ras_des_coef_rtx_g4),
    .mac_cdm_ras_des_reject_rtx_g4 (mac_cdm_ras_des_reject_rtx_g4),
    .phy_cdm_ras_des_fomfeedback_g4 (phy_cdm_ras_des_fomfeedback_g4),
    .eqpa_violate_rule_123_g4   (eqpa_violate_rule_123_g4),
    .eq_convergence_sts_g4      (eq_convergence_sts_g4)
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g5 (cdm_ras_des_eq_force_coef_rtx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_en_g5 (cdm_ras_des_eq_force_coef_ltx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_g5(cdm_ras_des_eq_force_coef_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_g5(cdm_ras_des_eq_force_coef_rtx_g5),
    .mac_cdm_ras_des_fs_g5      (mac_cdm_ras_des_fs_g5),
    .mac_cdm_ras_des_lf_g5      (mac_cdm_ras_des_lf_g5),
    .mac_cdm_ras_des_coef_ltx_g5 (mac_cdm_ras_des_coef_ltx_g5),
    .mac_cdm_ras_des_coef_rtx_g5 (mac_cdm_ras_des_coef_rtx_g5),
    .mac_cdm_ras_des_reject_rtx_g5 (mac_cdm_ras_des_reject_rtx_g5),
    .phy_cdm_ras_des_fomfeedback_g5 (phy_cdm_ras_des_fomfeedback_g5),
    .eqpa_violate_rule_123_g5   (eqpa_violate_rule_123_g5),
    .eq_convergence_sts_g5      (eq_convergence_sts_g5)
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g6 (cdm_ras_des_eq_force_coef_rtx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_en_g6 (cdm_ras_des_eq_force_coef_ltx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_g6(cdm_ras_des_eq_force_coef_ltx_g6),
    .cdm_ras_des_eq_force_coef_rtx_g6(cdm_ras_des_eq_force_coef_rtx_g6),
    .mac_cdm_ras_des_fs_g6      (mac_cdm_ras_des_fs_g6),
    .mac_cdm_ras_des_lf_g6      (mac_cdm_ras_des_lf_g6),
    .mac_cdm_ras_des_coef_ltx_g6 (mac_cdm_ras_des_coef_ltx_g6),
    .mac_cdm_ras_des_coef_rtx_g6 (mac_cdm_ras_des_coef_rtx_g6),
    .mac_cdm_ras_des_reject_rtx_g6 (mac_cdm_ras_des_reject_rtx_g6),
    .phy_cdm_ras_des_fomfeedback_g6 (phy_cdm_ras_des_fomfeedback_g6),
    .eqpa_violate_rule_123_g6   (eqpa_violate_rule_123_g6),
    .eqpa_violate_rule_4_g6   (eqpa_violate_rule_4_g6),
    .eq_convergence_sts_g6      (eq_convergence_sts_g6)
); //smlh_eqpa_slv


endmodule // smlh_eqpa
