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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_eqpa_slv.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- equalization pipe adapter - single lane version
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module smlh_eqpa_slv
 import DWC_pcie_core_pkg::violate_rules_tx_coef;
 import DWC_pcie_core_pkg::violate_rules_tx_coef_g6;
 import DWC_pcie_core_pkg::fs_d3;
#(
    parameter INST            = 0, // The uniquifying parameter for each port logic instance
    parameter TP              = `TP,
    parameter FDBK_MODE_WD    = 4,
    // constants
    parameter RX_PSET_WD      = 3,
    parameter TX_PSET_WD      = 4,
    parameter TX_FS_WD        = 6,
    parameter TX_FSLF_WD      = 2*TX_FS_WD,
    parameter TX_COEF_WD      = 3*TX_FS_WD,
    parameter PSET_REQ_VEC_WD = 16,
    parameter DIRFEEDBACK_WD  = `DIRFEEDBACK_WD,
    parameter FOMFEEDBACK_WD  = 8,
    parameter N_EVALS_WD      = 5,
    parameter PSET_ID_WD      = `PSET_ID_WD
)

                      (
    input                           core_clk,
    input                           core_rst_n,
    input                           sticky_rst_n,
    input                           ltssm_eq_exit,
    input                           lpbk_eq_lanes_active,
    // CDM i/f
    input        [FDBK_MODE_WD-1:0] cfg_gen3_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input     [PSET_REQ_VEC_WD-1:0] cfg_gen3_eq_pset_req_vector, //if bit[i]=1, do preset request with preset value=i
    input                           cfg_gen3_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen3_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen3_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input                           cfg_gen3_eq_invreq_eval_diff_disable, //0 - invalid_req assert -> invalid_req deassert and rxeqeval assert, 1 - invalid_req and rxeqeval assert/deassert at same cycle
    input                           cfg_gen34_eq_phase23_rxeq_regardless_rxts, //1 - assert RxEqEval regardless Rx TS detected. 0 - assert RxEqEval after Rx TS detect
    input                           cfg_p23_exit_mode, //1 - LTSSM moves to eq phase 3 for USP or Recovery.RcvrLock for DSP after timeout_24ms; 0 - to Recovery.Speed
    input        [FDBK_MODE_WD-1:0] cfg_gen4_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input     [PSET_REQ_VEC_WD-1:0] cfg_gen4_eq_pset_req_vector, //if bit[i]=1, do preset request with preset value=i
    input                           cfg_gen4_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen4_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen4_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input        [FDBK_MODE_WD-1:0] cfg_gen5_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input     [PSET_REQ_VEC_WD-1:0] cfg_gen5_eq_pset_req_vector, //if bit[i]=1, do preset request with preset value=i
    input                           cfg_gen5_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen5_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen5_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input        [FDBK_MODE_WD-1:0] cfg_gen6_eq_feedback_mode, // 0 - Direction Change, 1 - Figure Merit, 2~15: reserved
    input     [PSET_REQ_VEC_WD-1:0] cfg_gen6_eq_pset_req_vector, //if bit[i]=1, do preset request with preset value=i
    input                           cfg_gen6_eq_pset_req_as_coef, // 0 - make Preset Request, 1 - convert Preset Requests into Coefficient requests
    input                           cfg_gen6_eq_fom_include_init_eval, //0 - initial evaluation "figure of merit" feedback is excluded for finding the highest "figure of merit", 1 - included
    input                           cfg_gen6_eq_p23_eval_timeout_2ms_disable, //0 - Abort if 2ms timeout in evaluation waiting for phystatus back. 1 - Abort if 24ms timeout in evaluation
    input          [N_EVALS_WD-1:0] cfg_gen3_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input          [N_EVALS_WD-2:0] cfg_gen3_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input          [N_EVALS_WD-2:0] cfg_gen3_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input          [N_EVALS_WD-1:0] cfg_gen4_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input          [N_EVALS_WD-2:0] cfg_gen4_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input          [N_EVALS_WD-2:0] cfg_gen4_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input          [N_EVALS_WD-1:0] cfg_gen5_eq_dcm_n_evals, //consecutive evaluation number to determine optimal coefficients (convergence)
    input          [N_EVALS_WD-2:0] cfg_gen5_eq_dcm_max_precursor_delta, //max delta for pre-cursor convengence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input          [N_EVALS_WD-2:0] cfg_gen5_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence
    input          [N_EVALS_WD-1:0] cfg_gen6_eq_dcm_n_evals,              //consecutive evaluation number to determine optimal coefficients (convergence)
    input          [N_EVALS_WD-2:0] cfg_gen6_eq_dcm_max_precursor2_delta, //max delta for pre-cursor2 convergence
    input          [N_EVALS_WD-2:0] cfg_gen6_eq_dcm_max_precursor_delta,  //max delta for pre-cursor  convergence, one less bit assuming max_delta=n_eval-1, with n_eval=16,8,4,2,1 etc
    input          [N_EVALS_WD-2:0] cfg_gen6_eq_dcm_max_postcursor_delta, //max delta for post-cursor convergence


    input                           cfg_gen3_req_rst_eiec_disable, // 1 - feature RESET_EIEOS_INTERVAL_COUNT is disabled
    input                           eqctl_rst_eieos,               // 1 - RESET_EIEOS_INTERVAL_COUNT bit is set to 1 in transmit TS1s
    // ltssm i/f
    input                           ltssm_timeout24ms,
    input                           ltssm_lanes_active,
    input                           lpbk_eq_n_lut_pset,
    input                           ltssm_noeq_nd,                 // no eq needed
    input  [2:0]                    current_data_rate,
    input                           ltssm_lpbkentry_act_slave,
    input                     [2:0] mac_phy_rate,
    input                           mac_phy_txswing,
    output                          fs_out_of_range,
    // eqctl i/f - use_pset - Phase-1/0/1
    input                           mac_phy_use_pset, // indicates to use presets to transmit, used when initial change to Gen3 or when redoing Eq
    input          [TX_PSET_WD-1:0] mac_phy_pset_ltx, // Local Transmitter Preset
    input          [RX_PSET_WD-1:0] mac_phy_pset_lrx, // Local Receiver Preset Hint
    input          [TX_FSLF_WD-1:0] mac_phy_fslf_rtx, // Remote Transmitter Full Swing and Low Frequency, concatenation of {LF, FS}
    input                           mac_phy_fslf_rtx_valid, // Remote Transmitter Full Swing and Low Frequency Valid
    output reg                      phy_mac_fslf_ltx_valid, // Local Transmitter Full Swing and Low Frequency Valid
    output reg     [TX_FSLF_WD-1:0] phy_mac_fslf_ltx, // Local Transmitter Full Swing and Low Frequency, concatenation of {LF, FS}
    output         [TX_COEF_WD-1:0] phy_mac_coef_ltx, // Local Transmitter Coefficients - always reflects electrical settings in use

    // pipe i/f
    input                           cfg_gen3_eq_map_mode_prog,    // enable programmable table
    input    [TX_FSLF_WD-1:0]       cfg_gen3_eq_fs_lf,            // programmable FS and LF for equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen3_eq_coef,             // programmable FS and LF for equalization
    input    [TX_FSLF_WD-1:0]       cfg_gen4_eq_fs_lf,            // programmable FS and LF for equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen4_eq_coef,             // programmable FS and LF for equalization
    input    [TX_FSLF_WD-1:0]       cfg_gen5_eq_fs_lf,            // programmable FS and LF for equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen5_eq_coef,             // programmable FS and LF for equalization
    input    [TX_FSLF_WD-1:0]       cfg_gen6_eq_fs_lf,            // programmable FS and LF for equalization
    input    [(11*TX_COEF_WD)-1:0]  cfg_gen6_eq_coef,             // programmable FS and LF for equalization
    input            [TX_FS_WD-1:0] phy_mac_fs, // Local Transmitter Full Swing
    input            [TX_FS_WD-1:0] phy_mac_lf, // Local Transmitter Low Frequency
    output reg     [TX_COEF_WD-1:0] mac_phy_txdeemph, // Local Transmitter coefficients {C+1, C0, C-1}
    output reg     [RX_PSET_WD-1:0] mac_phy_rxpresethint, // Local Receiver Preset Hint
    output reg       [TX_FS_WD-1:0] mac_phy_fs, // FS value advertised by Link partner
    output reg       [TX_FS_WD-1:0] mac_phy_lf, // LF value advertised by Link partner

    // eqctl i/f - ftune_ltx - Phase2/3 as a Slave
    input                           mac_phy_ftune_ltx, // Local Transmitter Fine Tuning State, correspond to Phase 2 for UC, Phase 3 for DC
    input                           mac_phy_lpbk_ftune_ltx, // Local Transmitter Fine Tuning State, correspond to Loopback slave for receiving TS1 EC=2'b10 or 2'b11
    input          [TX_COEF_WD-1:0] mac_phy_coef_ltx, // already used for use_pset i/f
    input                           mac_phy_pset_ltx_upd, // Local Transmitter Preset Update - active until accept/reject flag is asserted
    input                           mac_phy_coef_ltx_upd, // Local Transmitter Coefficients Update - active until accept/reject flag is asserted
    output reg                      phy_mac_accept_ltx, // Local Transmitter Preset/Coefficients Accept Flag
    output reg                      phy_mac_reject_ltx, // Local Transmitter Coefficients Reject Flag

    // eqctl i/f - ftune_rtx - Phase2/3 as a Master
    input                           mac_phy_ftune_rtx, // Remote Transmitter Fine Tuning State, correspond to Phase 2 for DC, Phase 3 for UC
    input                           mac_phy_reject_rtx, // Remote Transmitter Coefficients Reject Flag
    input                           mac_phy_accept_rtx, // Remote Transmitter Preset/Coefficients Accept Flag
    input          [TX_COEF_WD-1:0] mac_phy_coef_rtx, // Remote Transmitter Coefficients, concatenation of {C+1, C0, C-1}
    input          [TX_PSET_WD-1:0] mac_phy_pset_rtx, // Remote Transmitter Preset
    output reg     [TX_COEF_WD-1:0] phy_mac_coef_rtx, // Remote Transmitter requested Coefficients, concatenation of {C+1, C0, C-1}
    output reg     [TX_PSET_WD-1:0] phy_mac_pset_rtx, // Remote Transmitter requested Preset
    output reg                      phy_mac_ftune_rtx_done, // Remote Transmitter Fine Tuning Complete
    output reg                      phy_mac_ftune_rtx_optimal, // Remote Transmitter Fine Tuning reaches Optimal Settings
    output reg                      phy_mac_coef_rtx_upd, // Remote Transmitter Coefficients Update - active until accept/reject/timeout flag is asserted
    output reg                      phy_mac_pset_rtx_upd, // Remote Transmitter Preset Update - active until accept/reject/timeout flag is asserted

    // pipe i/f
    input                           phy_mac_phystatus, // 1 - PHY completed remote Transmitter EQ evaluation
    input                           phystatus_asserted, // 1 - PHY completed remote Transmitter EQ evaluation, latched
    input      [DIRFEEDBACK_WD-1:0] phy_mac_dirfeedback, // direction feedback
    input      [FOMFEEDBACK_WD-1:0] phy_mac_fomfeedback, // figure of merit feedback
    input      [TX_COEF_WD-1:0]     phy_mac_local_tx_pset_coef, //mapped coef
    input                           phy_mac_local_tx_coef_valid, //1 - mapped coef valid
    output reg                      mac_phy_rxeqinprogress, // tell PHY it is in Master Phase now
    output reg                      mac_phy_invalid_req, // 1 - Invalid remote Transmitter EQ request
    output reg                      mac_phy_rxeqeval, // 1 - tell PHY doing remote Transmitter EQ evaluation
    output reg                      mac_phy_dirchange, //0 - FOM with mac_phy_rxeqeval = 1, 1 - DIR with mac_phy_rxeqeval = 1
    output                          mac_phy_getlocal_pset_coef, // one cycle if local preset valid
    output     [PSET_ID_WD-1:0]     mac_phy_local_pset_index, // local preset

    // eqpa i/f
    input                           phystatus_asserted_all, //all active lanes have phystatus asserted or optimal
    input                           timeout_2ms, //timeout since starting request
    input                           timeout_2_4ms, //timeout since starting request
    input                           timeout_1us, //timeout since starting request
    input                           timeout_500ns, //timeout since starting request
    input                           min_phase23_timeout, //cfg_gen3_eq_dcm_t_min_phase23 has been met since entering EQ master
    input                           rxeqeval_all, //all active lanes have rxeqeval asserted but optimal lanes
    input                           ts1_detected_all,
    output reg                      abort, //master evaluation aborted
    output                          eqpa_slv_set, //requested preset is rejected or timeout by remote partner
    output                          fom_rxeq_redardless_rxts, // FOM for redardless_rxts
    output                          ts1_detected,
    output                          wait_rei_state,
    output                          eqpa_slv_clr_phystatus, //clear phystatus_asserted
    output                          eqpa_slv_clr_2ms_timer //clear timeout_2ms
    ,
    input                           ltssm_timeout10ms,
    input                           cdm_ras_des_eq_fom_target_en,
    input                           cdm_ras_des_eq_force_coef_rtx_en,
    input                           cdm_ras_des_eq_force_pset_lrx_en,
    input                           cdm_ras_des_eq_force_coef_ltx_en,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx, // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
    input  [RX_PSET_WD-1:0]         cdm_ras_des_eq_force_pset_lrx, // Force Local Receiver RxPresetHint
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx, // Force Remote Transmitter cursor coefficient for Ras D.E.S Silicon Debug EQ COntrol
    input  [FOMFEEDBACK_WD-1:0]     cdm_ras_des_eq_fom_target, // FOM Target value for Ras D.E.S Silicon Debug EQ Control
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_fs,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_lf,
    output [TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx,
    output reg [RX_PSET_WD-1:0]     mac_cdm_ras_des_pset_lrx,
    output reg [TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx,
    output reg                      mac_cdm_ras_des_reject_rtx,
    output reg [FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback,
    output reg [2:0]                eqpa_violate_rule_123,
    output reg [1:0]                eq_convergence_sts
    ,
    input                           cdm_ras_des_eq_force_coef_rtx_en_g4,
    input                           cdm_ras_des_eq_force_coef_ltx_en_g4,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g4,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g4,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_fs_g4,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_lf_g4,
    output [TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx_g4,
    output reg [TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx_g4,
    output reg                      mac_cdm_ras_des_reject_rtx_g4,
    output reg [FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g4,
    output reg [2:0]                eqpa_violate_rule_123_g4,
    output reg [1:0]                eq_convergence_sts_g4
    ,
    input                           cdm_ras_des_eq_force_coef_rtx_en_g5,
    input                           cdm_ras_des_eq_force_coef_ltx_en_g5,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g5,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g5,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_fs_g5,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_lf_g5,
    output [TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx_g5,
    output reg [TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx_g5,
    output reg                      mac_cdm_ras_des_reject_rtx_g5,
    output reg [FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g5,
    output reg [2:0]                eqpa_violate_rule_123_g5,
    output reg [1:0]                eq_convergence_sts_g5
    ,
    input                           cdm_ras_des_eq_force_coef_rtx_en_g6,
    input                           cdm_ras_des_eq_force_coef_ltx_en_g6,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g6,
    input  [TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g6,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_fs_g6,
    output reg [TX_FS_WD-1:0]       mac_cdm_ras_des_lf_g6,
    output [TX_COEF_WD-1:0]         mac_cdm_ras_des_coef_ltx_g6,
    output reg [TX_COEF_WD-1:0]     mac_cdm_ras_des_coef_rtx_g6,
    output reg                      mac_cdm_ras_des_reject_rtx_g6,
    output reg [FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g6,
    output reg [2:0]                eqpa_violate_rule_123_g6,
    output reg                      eqpa_violate_rule_4_g6,
    output reg [1:0]                eq_convergence_sts_g6
);

localparam TX_FS_WD_P1 = TX_FS_WD + 1;
localparam TX_COEF_WD_P3 = TX_COEF_WD + 3;
localparam FS_MIN_FULL_SWING = 24;
localparam FS_MIN_REDUCE_SWING = 12;
localparam MAX_VALID_PSET_NUM = 10;

wire g1_rate = current_data_rate == `GEN1_RATE;
wire g2_rate = current_data_rate == `GEN2_RATE;
wire g3_rate = current_data_rate == `GEN3_RATE;
wire g4_rate = current_data_rate == `GEN4_RATE;
wire g5_rate = current_data_rate == `GEN5_RATE;
wire g6_rate = current_data_rate == `GEN6_RATE;

wire [3:0]                cfg_eq_feedback_mode = (g6_rate) ? cfg_gen6_eq_feedback_mode : (g5_rate) ? cfg_gen5_eq_feedback_mode : (~g4_rate) ? cfg_gen3_eq_feedback_mode : cfg_gen4_eq_feedback_mode;
wire                      cfg_eq_p23_eval_timeout_2ms_disable = (g6_rate) ? cfg_gen6_eq_p23_eval_timeout_2ms_disable : (g5_rate) ? cfg_gen5_eq_p23_eval_timeout_2ms_disable : (~g4_rate) ? cfg_gen3_eq_p23_eval_timeout_2ms_disable : cfg_gen4_eq_p23_eval_timeout_2ms_disable;
wire [15:0]               cfg_eq_pset_req_vector = (g6_rate) ? cfg_gen6_eq_pset_req_vector : (g5_rate) ? cfg_gen5_eq_pset_req_vector : (~g4_rate) ? cfg_gen3_eq_pset_req_vector : cfg_gen4_eq_pset_req_vector;
wire                      cfg_eq_fom_include_init_eval = (g6_rate) ? cfg_gen6_eq_fom_include_init_eval : (g5_rate) ? cfg_gen5_eq_fom_include_init_eval : (~g4_rate) ? cfg_gen3_eq_fom_include_init_eval : cfg_gen4_eq_fom_include_init_eval;
wire                      cfg_eq_pset_req_as_coef = (g6_rate) ? cfg_gen6_eq_pset_req_as_coef : (g5_rate) ? cfg_gen5_eq_pset_req_as_coef : (~g4_rate) ? cfg_gen3_eq_pset_req_as_coef : cfg_gen4_eq_pset_req_as_coef;
wire [TX_FS_WD-1:0]       fs, lf;
wire [TX_PSET_WD-1:0]     preset;
wire                      use_pset_or_ftune_ltx;
wire [TX_COEF_WD-1:0]     mux_mapped_coef;
wire                      use_pset;
reg                       mac_phy_use_pset_d;
wire                      use_pset_rising_edge;
reg                       fslf_rtx_valid_d;
wire                      fslf_rtx_valid_rising_edge;
wire                      pset_coef_ltx_upd;
wire                      use_pset_violate_tx_rules;
wire                      ftune_ltx_violate_tx_rules;
wire                      c_eval_violate_tx_rules;
wire                      c_eval_violate_tx_rules_g6;
wire [TX_COEF_WD-1:0]     mux_coef_ltx;
reg                       pset_ltx_upd_r;
wire                      pset_ltx_upd;
reg                       latch_ftune_ltx_phy_mac_local_tx_coef_valid;
wire [TX_FS_WD_P1-1:0]    c_eval_dirfeedback_pre_cursor2; //direction Change, C-2
wire [TX_FS_WD_P1-1:0]    c_eval_dirfeedback_pre_cursor; //direction Change, C-1
wire [TX_FS_WD_P1-1:0]    c_eval_dirfeedback_cursor; //direction Change, C0
wire [TX_FS_WD_P1-1:0]    c_eval_dirfeedback_post_cursor; //direction Change, C0
wire [TX_COEF_WD_P3:0]    c_eval_dirfeedback; //direction Change
wire [TX_COEF_WD_P3:0]    c_eval_new;         //new coef with +1 bit for violation check
reg  [TX_COEF_WD_P3:0]    c_eval_new_r;       //new coef with +1 bit for violation check
wire [TX_FS_WD-1:0]       c_eval_pre_cursor, c_eval_post_cursor, c_eval_pre_cursor2;
wire [TX_COEF_WD-1:0]     int_c_eval_new;     //normal 18 bit
wire [TX_FS_WD-1:0]       int_phy_mac_fs;
reg  [DIRFEEDBACK_WD-1:0] int_phy_mac_dirfeedback;
reg  [FOMFEEDBACK_WD-1:0] int_phy_mac_fomfeedback;
reg  [FOMFEEDBACK_WD-1:0] max_fomfeedback;
reg  [TX_COEF_WD-1:0]     latch_phy_mac_local_tx_pset_coef;
reg  [TX_PSET_WD-1:0]     mac_phy_pset_ltx_d;
wire [TX_PSET_WD-1:0]     mac_phy_pset_ltx_i;
reg                       latch_use_pset_phy_mac_local_tx_coef_valid;
reg  [4:0]                fcoef_req_num; // coef for fom request number from 0 to (cfg_max_vec_length - 1)
wire [4:0]                fcoef_req_num_i;
reg [PSET_REQ_VEC_WD-1:0] pset_req_vector;
reg                 [3:0] pset_loop_num;

wire    [TX_FS_WD-1:0]         phy_mac_fs_i; // Local Transmitter Full Swing
wire    [TX_FS_WD-1:0]         phy_mac_lf_i; // Local Transmitter Low Frequency
wire    [TX_COEF_WD-1:0]       cfg_eq_sel_pset_coef;           // Selected programmable coefficients for equalization for a given preset number
reg     [TX_COEF_WD-1:0]       cfg_gen3_eq_sel_pset_coef;      // Selected programmable coefficients for equalization for a given preset number
reg     [TX_COEF_WD-1:0]       cfg_gen4_eq_sel_pset_coef;      // Selected programmable coefficients for equalization for a given preset number
reg     [TX_COEF_WD-1:0]       cfg_gen5_eq_sel_pset_coef;      // Selected programmable coefficients for equalization for a given preset number
reg     [TX_COEF_WD-1:0]       cfg_gen6_eq_sel_pset_coef;      // Selected programmable coefficients for equalization for a given preset number

// register cfg_gen3_eq_map_mode_prog to avoid critical path
reg cfg_gen3_eq_map_mode_prog_d;
always @(posedge core_clk or negedge core_rst_n) begin : cfg_gen3_eq_map_mode_prog_d_PROC
    if( !core_rst_n ) begin
        cfg_gen3_eq_map_mode_prog_d <= #TP `DEFAULT_GEN3_EQ_PSET_COEF_MAP_MODE_PROG;
    end else begin
        cfg_gen3_eq_map_mode_prog_d <= #TP cfg_gen3_eq_map_mode_prog;
    end
end //always @(posedge

assign {phy_mac_fs_i, phy_mac_lf_i} = cfg_gen3_eq_map_mode_prog_d ? ( (g6_rate) ? cfg_gen6_eq_fs_lf : (g5_rate) ? cfg_gen5_eq_fs_lf : (g4_rate) ? cfg_gen4_eq_fs_lf : cfg_gen3_eq_fs_lf) : {phy_mac_fs, phy_mac_lf};


wire [4:0]                   cfg_max_fcoef_length;
wire [17:0]                  cfg_fcoefs;
assign cfg_max_fcoef_length = 0;
assign cfg_fcoefs           = 0;

//====================================================
// logic below for mac_phy_use_pset = 1 (Phase -1/0/1)
//====================================================

//reg phy_mac_local_tx_pset_coef and phy_mac_local_tx_coef_valid
always @(posedge core_clk or negedge core_rst_n) begin : phy_mac_local_tx_pset_PROC
    if( !core_rst_n ) begin
        latch_phy_mac_local_tx_pset_coef <= #TP '0;
    end else begin
        latch_phy_mac_local_tx_pset_coef <= #TP phy_mac_local_tx_coef_valid ? phy_mac_local_tx_pset_coef : latch_phy_mac_local_tx_pset_coef;
    end
end //always @(posedge


reg  phystatus_firstgen3_done ;
wire phystatus_firstgen3 ;
reg  phystatus_firstgen4_done ;
wire phystatus_firstgen4 ;
reg  phystatus_firstgen5_done ;
wire phystatus_firstgen5 ;
reg  phystatus_firstgen6_done ;
wire phystatus_firstgen6 ;

always @(posedge core_clk or negedge core_rst_n) begin : phystatus_firstgen3_done_PROC
    if( !core_rst_n ) begin
        phystatus_firstgen3_done <= #TP '0;
    end else if(mac_phy_rate == `GEN3_RATE) begin
        if( phy_mac_phystatus )
            phystatus_firstgen3_done <= #TP 1'b1;
    end else begin
        phystatus_firstgen3_done <= #TP '0;
    end
end

assign phystatus_firstgen3 = phy_mac_phystatus && (mac_phy_rate == `GEN3_RATE) && ~phystatus_firstgen3_done ;

always @(posedge core_clk or negedge core_rst_n) begin : phystatus_firstgen4_done_PROC
    if( !core_rst_n ) begin
        phystatus_firstgen4_done <= #TP '0;
    end else if(mac_phy_rate == `GEN4_RATE) begin
        if( phy_mac_phystatus )
            phystatus_firstgen4_done <= #TP 1'b1;
    end else begin
        phystatus_firstgen4_done <= #TP '0;
    end
end

assign phystatus_firstgen4 = phy_mac_phystatus && (mac_phy_rate == `GEN4_RATE) && ~phystatus_firstgen4_done ;

always @(posedge core_clk or negedge core_rst_n) begin : phystatus_firstgen5_done_PROC
    if( !core_rst_n ) begin
        phystatus_firstgen5_done <= #TP '0;
    end else if(mac_phy_rate == `GEN5_RATE) begin
        if( phy_mac_phystatus )
            phystatus_firstgen5_done <= #TP 1'b1;
    end else begin
        phystatus_firstgen5_done <= #TP '0;
    end
end // phystatus_firstgen5_done_PROC

assign phystatus_firstgen5 = phy_mac_phystatus && (mac_phy_rate == `GEN5_RATE) && ~phystatus_firstgen5_done ;

always @(posedge core_clk or negedge core_rst_n) begin : phystatus_firstgen6_done_PROC
    if( !core_rst_n ) begin
        phystatus_firstgen6_done <= #TP '0;
    end else if(mac_phy_rate == `GEN6_RATE) begin
        if( phy_mac_phystatus )
            phystatus_firstgen6_done <= #TP 1'b1;
    end else begin
        phystatus_firstgen6_done <= #TP '0;
    end
end // phystatus_firstgen6_done_PROC

assign phystatus_firstgen6 = phy_mac_phystatus && (mac_phy_rate == `GEN6_RATE) && ~phystatus_firstgen6_done ;


//gates: after mac_phy_use_pset=1 during gen3 data rate,
//assume {phy_mac_lf, phy_mac_fs} value won't change
always @(posedge core_clk or negedge core_rst_n) begin : phy_mac_fslf_ltx_PROC
    if( !core_rst_n ) begin
        phy_mac_fslf_ltx <= #TP '0;
    end else begin
        phy_mac_fslf_ltx <= #TP {phy_mac_lf_i, phy_mac_fs_i};
    end
end

//if local FS value phy_mac_fs is not in the correct range, exit equalization and gen3 to Gen1/2
//base spec: FS = {24...63} for full swing, FS = {12...63} for reduced swing
//mac_phy_txswing=0, full swing; =1, reduced swing
assign int_phy_mac_fs = phy_mac_fslf_ltx[TX_FS_WD-1:0];
assign fs_out_of_range = ( mac_phy_txswing ? (int_phy_mac_fs < FS_MIN_REDUCE_SWING) : (int_phy_mac_fs < FS_MIN_FULL_SWING) );

//mac_phy_use_pset=1 when changing data rate from gen1/2 to gen3
//or enter phase 0 or 1.
//gates: {phy_mac_lf, phy_mac_fs} should be valid before mac_phy_use_pset=1
always @(posedge core_clk or negedge core_rst_n) begin : latch_phy_mac_local_tx_coef_valid_PROC
    if( !core_rst_n ) begin
        latch_use_pset_phy_mac_local_tx_coef_valid <= #TP '0;
    end else begin
        if ( mac_phy_use_pset == 0 )
            latch_use_pset_phy_mac_local_tx_coef_valid <= #TP '0;
        else if ( phy_mac_local_tx_coef_valid )
            latch_use_pset_phy_mac_local_tx_coef_valid <= #TP 1;
    end
end

//if map from PHY, latch_use_pset_phy_mac_local_tx_coef_valid deasserted one cycle delay to mac_phy_use_pset. This will overlap mac_phy_coef_ltx_upd
// Programmable coefficients do not use this delay.
assign use_pset = cfg_gen3_eq_map_mode_prog_d ? mac_phy_use_pset : (latch_use_pset_phy_mac_local_tx_coef_valid & mac_phy_use_pset);

always @(posedge core_clk or negedge core_rst_n) begin : phy_mac_fslf_ltx_valid_PROC
    if( !core_rst_n ) begin
        phy_mac_fslf_ltx_valid <= #TP '0;
    end else begin
        phy_mac_fslf_ltx_valid <= #TP use_pset;
    end
end //always

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_use_pset_d_PROC
    if( !core_rst_n ) begin
        mac_phy_use_pset_d <= #TP '0;
    end else begin
        mac_phy_use_pset_d <= #TP mac_phy_use_pset;
    end
end //always @(posedge

//generate a rising edge for getlocalpresetcoefficients (one cycle pulse)
assign use_pset_rising_edge = mac_phy_use_pset & !mac_phy_use_pset_d;
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_stored_gen3;
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_stored_gen4;
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_stored_gen5;
wire ltssm_noeq_nd_txdeemph_restored_gen3 = (ltssm_noeq_nd && g3_rate && mac_phy_txdeemph_stored_gen3 != 0);
wire ltssm_noeq_nd_txdeemph_restored_gen4 = (ltssm_noeq_nd && g4_rate && mac_phy_txdeemph_stored_gen4 != 0);
wire ltssm_noeq_nd_txdeemph_restored_gen5 = (ltssm_noeq_nd && g5_rate && mac_phy_txdeemph_stored_gen5 != 0);
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_stored_gen6;
wire ltssm_noeq_nd_txdeemph_restored_gen6 = (ltssm_noeq_nd && g6_rate && mac_phy_txdeemph_stored_gen6 != 0);
  //use default initial preset when noeq_nd is negotiated at initial linkup
wire ltssm_noeq_nd_txdeemph_restore_fail = ltssm_noeq_nd && ((g3_rate && mac_phy_txdeemph_stored_gen3 == 0) || (g4_rate && mac_phy_txdeemph_stored_gen4 == 0) || (g5_rate && mac_phy_txdeemph_stored_gen5 == 0) || (g6_rate && mac_phy_txdeemph_stored_gen6 == 0) ) ;
// drive mac_phy_getlocal_pset_coef only when PHY map mode is enabled (cfg_gen3_eq_map_mode_prog_d=0)
assign mac_phy_getlocal_pset_coef = cfg_gen3_eq_map_mode_prog_d ? 1'b0 : ((use_pset_rising_edge & ~ltssm_noeq_nd_txdeemph_restored_gen5 & ~ltssm_noeq_nd_txdeemph_restored_gen6) | (mac_phy_pset_ltx_upd & !pset_ltx_upd_r));

// drive mac_phy_local_pset_index only when PHY map mode is enabled (cfg_gen3_eq_map_mode_prog_d=0)
// if mac_phy_pset_ltx > 10, use default P4 for PHY to do pset-coef mapping
// if mac_phy_pset_ltx > 10, use default Q0 for PHY to do pset-coef mapping for >=gen6
assign mac_phy_local_pset_index = cfg_gen3_eq_map_mode_prog_d ? 1'b0 : 
 g6_rate ? (mac_phy_pset_ltx > 4'b1010 || mac_phy_pset_ltx == 4'b0000) ? 6'b100001 : (mac_phy_pset_ltx + 34) : // pipe6 spec maps Q1 (0001b) and ... to 100011b ... instead of 100010b ...
                                  (g5_rate) ? ((mac_phy_pset_ltx > 4'b1010) ? 6'b011010 : (mac_phy_pset_ltx + 22)) :
                                  (g4_rate) ? ((mac_phy_pset_ltx > 4'b1010) ? 6'b001111 : (mac_phy_pset_ltx + 11)) :
                                  ((mac_phy_pset_ltx > 4'b1010) ? 6'b000100 : {2'b0, mac_phy_pset_ltx});

//Latch mac_phy_pset_ltx for violation check if mac_phy_pset_ltx > MAX_VALID_PSET_NUM
always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_pset_ltx_d_PROC
    if( !core_rst_n ) begin
        mac_phy_pset_ltx_d <= #TP '0;
    end else if ( use_pset_rising_edge || (mac_phy_pset_ltx_upd & !pset_ltx_upd_r) ) begin
        mac_phy_pset_ltx_d <= #TP mac_phy_pset_ltx;
    end
end

assign mac_phy_pset_ltx_i = cfg_gen3_eq_map_mode_prog_d ? mac_phy_pset_ltx : mac_phy_pset_ltx_d;

//loading remote {lf, fs}. mac_phy_fslf_rtx_valid=1 occurs
//in the end of phase0 (USP) or phase1 (DSP)
always @(posedge core_clk or negedge core_rst_n) begin : fslf_rtx_valid_d_PROC
    if( !core_rst_n ) begin
        fslf_rtx_valid_d <= #TP '0;
    end else begin
        fslf_rtx_valid_d <= #TP mac_phy_fslf_rtx_valid;
    end
end

assign fslf_rtx_valid_rising_edge = (mac_phy_fslf_rtx_valid & !fslf_rtx_valid_d);

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_fslf_PROC
    if( !core_rst_n ) begin
        mac_phy_fs <= #TP '0;
        mac_phy_lf <= #TP '0;
    end else begin
        if ( fslf_rtx_valid_rising_edge ) begin
            mac_phy_fs <= #TP mac_phy_fslf_rtx[TX_FS_WD-1:0];
            mac_phy_lf <= #TP mac_phy_fslf_rtx[2*TX_FS_WD-1:TX_FS_WD];
        end
    end
end

//local receiver preset hint
always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_rxpresethint_PROC
    if( !core_rst_n ) begin
        mac_phy_rxpresethint <= #TP '0;
//  `ifdef CX_GEN5_SPEED
//    end else if ( ltssm_noeq_nd && current_data_rate == `GEN3_RATE ) begin // reload preset hint if ltssm_noeq_nd
//        mac_phy_rxpresethint <= #TP mac_phy_pset_lrx;
//  `endif // CX_GEN5_SPEED
    end else if ( mac_phy_use_pset ) begin
        if(cdm_ras_des_eq_force_pset_lrx_en && g3_rate )
            mac_phy_rxpresethint <= #TP cdm_ras_des_eq_force_pset_lrx;
        else
            mac_phy_rxpresethint <= #TP mac_phy_pset_lrx;
    end
end

// Current Local Receiver RxPresetHint
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        mac_cdm_ras_des_pset_lrx <= #TP '0;
    end else begin
        if(mac_phy_use_pset_d) begin
            mac_cdm_ras_des_pset_lrx <= #TP mac_phy_rxpresethint;
        end
    end
end


//==================================================================================
// logic below for mac_phy_ftune_ltx = 1 (Slave in Phase 2/3)
// or mac_phy_lpbk_ftune_ltx for Loopback slave with receiving TS1 EC=2'b01 or 2'b11
//==================================================================================

always @(posedge core_clk or negedge core_rst_n) begin : pset_ltx_upd_r_PROC
    if( !core_rst_n ) begin
        pset_ltx_upd_r <= #TP '0;
    end else begin
        pset_ltx_upd_r <= #TP mac_phy_pset_ltx_upd;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : latch_ftune_ltx_phy_mac_local_tx_coef_valid_PROC
    if( !core_rst_n ) begin
        latch_ftune_ltx_phy_mac_local_tx_coef_valid <= #TP '0;
    end else if ( (!ltssm_lpbkentry_act_slave && !mac_phy_ftune_ltx) || (ltssm_lpbkentry_act_slave && !mac_phy_lpbk_ftune_ltx) ||
                  phy_mac_accept_ltx || phy_mac_reject_ltx ) begin
        latch_ftune_ltx_phy_mac_local_tx_coef_valid <= #TP '0;
    end else if ( phy_mac_local_tx_coef_valid ) begin
        latch_ftune_ltx_phy_mac_local_tx_coef_valid <= #TP 1;
    end
end //always @(posedge

assign pset_ltx_upd   = cfg_gen3_eq_map_mode_prog_d ? mac_phy_pset_ltx_upd : latch_ftune_ltx_phy_mac_local_tx_coef_valid;

assign pset_coef_ltx_upd = (pset_ltx_upd | mac_phy_coef_ltx_upd);

//mux mapped coef from PHY or from MAC
//if mac_phy_pset_ltx > MAX_VALID_PSET_NUM, assign mux_mapped_coef = 0 which can make violation of Tx rules


assign cfg_eq_sel_pset_coef = (g6_rate ) ? cfg_gen6_eq_sel_pset_coef : (g5_rate ) ? cfg_gen5_eq_sel_pset_coef : (~g4_rate ) ? cfg_gen3_eq_sel_pset_coef : cfg_gen4_eq_sel_pset_coef;

always @(cfg_gen3_eq_coef or preset)
begin
  case (preset)
    4'd0: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[17:0];   // Preset number 0
    4'd1: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[35:18];  // Preset number 1
    4'd2: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[53:36];
    4'd3: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[71:54];
    4'd4: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[89:72];
    4'd5: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[107:90];
    4'd6: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[125:108];
    4'd7: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[143:126];
    4'd8: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[161:144];
    4'd9: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[179:162];
    4'd10: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[197:180]; // Preset number 10
    default: cfg_gen3_eq_sel_pset_coef = cfg_gen3_eq_coef[89:72]; // Preset number 4
  endcase
end

always @(cfg_gen4_eq_coef or preset)
begin
  case (preset)
    4'd0: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[17:0];   // Preset number 0
    4'd1: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[35:18];  // Preset number 1
    4'd2: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[53:36];
    4'd3: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[71:54];
    4'd4: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[89:72];
    4'd5: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[107:90];
    4'd6: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[125:108];
    4'd7: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[143:126];
    4'd8: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[161:144];
    4'd9: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[179:162];
    4'd10: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[197:180]; // Preset number 10
    default: cfg_gen4_eq_sel_pset_coef = cfg_gen4_eq_coef[89:72]; // Preset number 4
  endcase
end

always @(cfg_gen5_eq_coef or preset)
begin
  case (preset)
    4'd0: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[17:0];   // Preset number 0
    4'd1: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[35:18];  // Preset number 1
    4'd2: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[53:36];
    4'd3: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[71:54];
    4'd4: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[89:72];
    4'd5: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[107:90];
    4'd6: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[125:108];
    4'd7: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[143:126];
    4'd8: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[161:144];
    4'd9: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[179:162];
    4'd10: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[197:180]; // Preset number 10
    default: cfg_gen5_eq_sel_pset_coef = cfg_gen5_eq_coef[89:72]; // Preset number 4
  endcase
end

always @(cfg_gen6_eq_coef or preset)
begin
  case (preset)
    4'd0: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[17:0];   // Preset number 0
    4'd1: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[35:18];  // Preset number 1
    4'd2: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[53:36];
    4'd3: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[71:54];
    4'd4: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[89:72];
    4'd5: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[107:90];
    4'd6: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[125:108];
    4'd7: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[143:126];
    4'd8: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[161:144];
    4'd9: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[179:162];
    4'd10: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[197:180]; // Preset number 10
    default: cfg_gen6_eq_sel_pset_coef = cfg_gen6_eq_coef[17:0]; // Preset number 0
  endcase
end

assign mux_mapped_coef = (mac_phy_pset_ltx_i > MAX_VALID_PSET_NUM) ? 0 : (cfg_gen3_eq_map_mode_prog_d ? cfg_eq_sel_pset_coef : latch_phy_mac_local_tx_pset_coef);


//mux coefficients between mac_phy_coef_ltx and coefficients mapped on mac_phy_pset_ltx
assign mux_coef_ltx = pset_ltx_upd ? mux_mapped_coef : (mac_phy_coef_ltx_upd ? mac_phy_coef_ltx : {TX_COEF_WD{1'b0}});

//legal/illegal coef flag back for MAC to send them to remote partner thru TS1s
//phy_mac_accept_ltx and phy_mac_reject_ltx during use_pset are used for phy_mac_pset_ltx in smlh_eqctl.v for initial preset accepted/rejected
always @(posedge core_clk or negedge core_rst_n) begin : phy_mac_accept_ltx_PROC
    if( !core_rst_n ) begin
        phy_mac_accept_ltx <= #TP '0;
        phy_mac_reject_ltx <= #TP '0;
    end else begin
        phy_mac_accept_ltx <= #TP (pset_coef_ltx_upd & !ftune_ltx_violate_tx_rules) | (use_pset & !use_pset_violate_tx_rules);
        phy_mac_reject_ltx <= #TP (pset_coef_ltx_upd & ftune_ltx_violate_tx_rules) | (use_pset & use_pset_violate_tx_rules);
    end
end

//local transmitter coefficients
//1. during mac_phy_use_pset=1, if no violation with mac_phy_pset_ltx, TxDeemph[17:0] (to PIPE) is mapped coefficients on mac_phy_pset_ltx.
//2. during mac_phy_use_pset=1, else default value is preset P4 = coef {C+1=0, FS, C-1=0}
//3. during mac_phy_ftune_ltx=1, if no violation with mux_coef_ltx when pset_coef_ltx_upd=1, TxDeemph[17:0] (to PIPE) is mux_coef_ltx.
assign use_pset_violate_tx_rules  = g6_rate ? violate_rules_tx_coef_g6(mux_mapped_coef, fs, lf) : violate_rules_tx_coef(mux_mapped_coef, fs, lf);
assign ftune_ltx_violate_tx_rules = g6_rate ? violate_rules_tx_coef_g6(mux_coef_ltx, fs, lf) : violate_rules_tx_coef(mux_coef_ltx, fs, lf);

reg [TX_COEF_WD-1:0] mac_phy_txdeemph_gen3 ;
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_gen4 ;
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_gen5 ;
reg [TX_COEF_WD-1:0] mac_phy_txdeemph_gen6 ;
always @(*) begin : mac_phy_txdeemph_PROC
    mac_phy_txdeemph = (mac_phy_rate == `GEN6_RATE) ? (                     ltssm_noeq_nd_txdeemph_restored_gen6 ? mac_phy_txdeemph_stored_gen6 :        mac_phy_txdeemph_gen6) :
 (mac_phy_rate == `GEN5_RATE) ? (                     ltssm_noeq_nd_txdeemph_restored_gen5 ? mac_phy_txdeemph_stored_gen5 :        mac_phy_txdeemph_gen5) :
                                            (mac_phy_rate != `GEN4_RATE) ? ( ltssm_noeq_nd_txdeemph_restored_gen3 ? mac_phy_txdeemph_stored_gen3 : mac_phy_txdeemph_gen3) :
                                                                           ( ltssm_noeq_nd_txdeemph_restored_gen4 ? mac_phy_txdeemph_stored_gen4 : mac_phy_txdeemph_gen4);
end
always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_txdeemph_gen34_PROC
    if( !core_rst_n ) begin
        mac_phy_txdeemph_gen3 <= #TP '0;
        mac_phy_txdeemph_gen4 <= #TP '0;
        mac_phy_txdeemph_gen5 <= #TP '0;
        mac_phy_txdeemph_gen6 <= #TP '0;
    end else if ( ~lpbk_eq_lanes_active && lpbk_eq_n_lut_pset ) begin // the lane not under test uses P4 preset, mapping to {6'd0, int_phy_mac_fs, 6'd0} coefficients
        mac_phy_txdeemph_gen5 <= #TP (g5_rate) ? {6'd0, int_phy_mac_fs, 6'd0} : mac_phy_txdeemph_gen5; // use P4;
        // for gen6, pick up Q0 = {C+1, FS, C-1, C-2} = {5'h0, FS, 4'h0, 3'h0}
        mac_phy_txdeemph_gen6 <= #TP (g6_rate) ? {5'd0, int_phy_mac_fs, 7'd0} : mac_phy_txdeemph_gen6; // use Q0;
    // if No Eq Needed and EQ has been done in the past, reload the previous EQ settings for the corresponding rate after Hot Reset or any other mechanisms to not do eq again
    // software has to handle the "No Eq Needed" bit set in both sides before the Hot Reset
    end else if ( ltssm_noeq_nd_txdeemph_restored_gen3 ) begin // mac_phy_txdeemph_stored_gen3 != 0 means the core has touched gen3 eq
        mac_phy_txdeemph_gen3 <= #TP mac_phy_txdeemph_stored_gen3;
    end else if ( ltssm_noeq_nd_txdeemph_restored_gen4 ) begin // mac_phy_txdeemph_stored_gen4 != 0 means the core has touched gen4 eq
        mac_phy_txdeemph_gen4 <= #TP mac_phy_txdeemph_stored_gen4;
    end else if ( ltssm_noeq_nd_txdeemph_restored_gen5 ) begin // mac_phy_txdeemph_stored_gen5 != 0 means the core has touched gen5 eq
        mac_phy_txdeemph_gen5 <= #TP mac_phy_txdeemph_stored_gen5;
    end else if ( ltssm_noeq_nd_txdeemph_restored_gen6 ) begin // mac_phy_txdeemph_stored_gen5 != 0 means the core has touched gen5 eq
        mac_phy_txdeemph_gen6 <= #TP mac_phy_txdeemph_stored_gen6;
    end else if (cdm_ras_des_eq_force_coef_ltx_en_g6 && g6_rate) begin
        mac_phy_txdeemph_gen3 <= #TP mac_phy_txdeemph_gen3;
        mac_phy_txdeemph_gen4 <= #TP mac_phy_txdeemph_gen4;
        mac_phy_txdeemph_gen5 <= #TP mac_phy_txdeemph_gen5;
        mac_phy_txdeemph_gen6 <= #TP cdm_ras_des_eq_force_coef_ltx_g6;
    end else if (cdm_ras_des_eq_force_coef_ltx_en_g5 && g5_rate) begin
        mac_phy_txdeemph_gen3 <= #TP mac_phy_txdeemph_gen3;
        mac_phy_txdeemph_gen4 <= #TP mac_phy_txdeemph_gen4;
        mac_phy_txdeemph_gen5 <= #TP cdm_ras_des_eq_force_coef_ltx_g5;
        mac_phy_txdeemph_gen6 <= #TP mac_phy_txdeemph_gen6;
    end else if (cdm_ras_des_eq_force_coef_ltx_en_g4 && g4_rate) begin
        mac_phy_txdeemph_gen3 <= #TP mac_phy_txdeemph_gen3;
        mac_phy_txdeemph_gen4 <= #TP cdm_ras_des_eq_force_coef_ltx_g4;
        mac_phy_txdeemph_gen5 <= #TP mac_phy_txdeemph_gen5;
        mac_phy_txdeemph_gen6 <= #TP mac_phy_txdeemph_gen6;
    end else if (cdm_ras_des_eq_force_coef_ltx_en && g3_rate) begin
        mac_phy_txdeemph_gen3 <= #TP cdm_ras_des_eq_force_coef_ltx;
        mac_phy_txdeemph_gen4 <= #TP mac_phy_txdeemph_gen4;
        mac_phy_txdeemph_gen5 <= #TP mac_phy_txdeemph_gen5;
        mac_phy_txdeemph_gen6 <= #TP mac_phy_txdeemph_gen6;
    end else if ( use_pset && !use_pset_violate_tx_rules ) begin
        mac_phy_txdeemph_gen3 <= #TP (~g4_rate && ~g5_rate && ~g6_rate) ? mux_mapped_coef : mac_phy_txdeemph_gen3;
        mac_phy_txdeemph_gen4 <= #TP (g4_rate) ? mux_mapped_coef : mac_phy_txdeemph_gen4;
        mac_phy_txdeemph_gen5 <= #TP (g5_rate) ? mux_mapped_coef : mac_phy_txdeemph_gen5;
        mac_phy_txdeemph_gen6 <= #TP (g6_rate) ? mux_mapped_coef : mac_phy_txdeemph_gen6;
    end else if ( use_pset_rising_edge || ltssm_noeq_nd_txdeemph_restore_fail  ) begin
        //pick up preset P4 = 4'b0100 as default value if use_pset_violate_tx_rules = 1.
        //This reflects phy_mac_pset_ltx <= #TP `DEFAULT_EQ_PSET in smlh_eqctl.v.
        //P4 mapped to coefficients = {6'd0, FS, 6'd0} = {C+1, C0, C-1}.
        // for gen6, pick up Q0 = {C+1, FS, C-1, C-2} = {5'h0, FS, 4'h0, 3'h0}
        mac_phy_txdeemph_gen3 <= #TP (~g4_rate && ~g5_rate && ~g6_rate) ? {6'd0, int_phy_mac_fs, 6'd0} : mac_phy_txdeemph_gen3;
        mac_phy_txdeemph_gen4 <= #TP (g4_rate) ? {6'd0, int_phy_mac_fs, 6'd0} : mac_phy_txdeemph_gen4;
        mac_phy_txdeemph_gen5 <= #TP (g5_rate) ? {6'd0, int_phy_mac_fs, 6'd0} : mac_phy_txdeemph_gen5;
        mac_phy_txdeemph_gen6 <= #TP (g6_rate) ? {5'd0, int_phy_mac_fs, 7'd0} : mac_phy_txdeemph_gen6;
    end else if ( (mac_phy_ftune_ltx || mac_phy_lpbk_ftune_ltx) && pset_coef_ltx_upd && !ftune_ltx_violate_tx_rules ) begin
        mac_phy_txdeemph_gen3 <= #TP (~g4_rate && ~g5_rate && ~g6_rate) ? mux_coef_ltx : mac_phy_txdeemph_gen3;
        mac_phy_txdeemph_gen4 <= #TP (g4_rate) ? mux_coef_ltx : mac_phy_txdeemph_gen4;
        mac_phy_txdeemph_gen5 <= #TP (g5_rate) ? mux_coef_ltx : mac_phy_txdeemph_gen5;
        mac_phy_txdeemph_gen6 <= #TP (g6_rate) ? mux_coef_ltx : mac_phy_txdeemph_gen6;
    end
end


always @(posedge core_clk or negedge sticky_rst_n) begin : mac_phy_txdeemph_stored_g5_config_PROC
    if ( ~sticky_rst_n ) begin
        mac_phy_txdeemph_stored_gen3 <= #TP '0;
        mac_phy_txdeemph_stored_gen4 <= #TP '0;
        mac_phy_txdeemph_stored_gen5 <= #TP '0;
    end else if ( ltssm_eq_exit ) begin
        mac_phy_txdeemph_stored_gen3 <= #TP (g3_rate) ? mac_phy_txdeemph_gen3 : mac_phy_txdeemph_stored_gen3;
        mac_phy_txdeemph_stored_gen4 <= #TP (g4_rate) ? mac_phy_txdeemph_gen4 : mac_phy_txdeemph_stored_gen4;
        mac_phy_txdeemph_stored_gen5 <= #TP (g5_rate) ? mac_phy_txdeemph_gen5 : mac_phy_txdeemph_stored_gen5;
    end
end // mac_phy_txdeemph_stored_g5_config_PROC

always @(posedge core_clk or negedge sticky_rst_n) begin : mac_phy_txdeemph_stored_g6_config_PROC
    if ( ~sticky_rst_n ) begin
        mac_phy_txdeemph_stored_gen6 <= #TP '0;
    end else if ( ltssm_eq_exit ) begin
        mac_phy_txdeemph_stored_gen6 <= #TP (g6_rate) ? mac_phy_txdeemph_gen6 : mac_phy_txdeemph_stored_gen6;
    end
end // mac_phy_txdeemph_stored_g6_config_PROC


//local transmitter coefficients in use for MAC to transmit TS1s with coefficient fields
assign phy_mac_coef_ltx = mac_phy_txdeemph;


//============================================================
// logic below for mac_phy_ftune_rtx = 1 (Master in Phase 2/3)
//============================================================
localparam S_RST             = 4'd0;
localparam S_INIT            = 4'd1;
localparam S_EVAL            = 4'd2;
localparam S_UNSUCCESS_EXIT  = 4'd3;
localparam S_SUCCESS_EXIT    = 4'd4;
localparam S_FEEDBACK        = 4'd5;
localparam S_NEW_COEFF       = 4'd6;
localparam S_REQUEST         = 4'd7;
localparam S_WAIT_RESPONSE   = 4'd8;
localparam S_ABORT           = 4'd9;
localparam S_INVALID_REQ     = 4'd10;
localparam S_TIMEOUT_REQ     = 4'd11;
localparam S_SKIP_EVAL       = 4'd12;
localparam S_WAIT_REI        = 4'd13; //wait Reset EIEOS Interval bit to transmit in Tx TS1s and then do evaluation

reg [3:0]            eq_master_state;
wire                 req_accepted;
reg                  ftune_rtx_d;
wire                 ftune_rtx_rising_edge;
reg [TX_COEF_WD-1:0] c_eval;      //coef on evaluation
reg [TX_COEF_WD-1:0] c_eval_prev; //coef on evaluation
reg [TX_COEF_WD-1:0] c_eval_temp; //coef on evaluation
reg [TX_PSET_WD-1:0] p_eval;      //pset on evaluation
reg [TX_PSET_WD-1:0] p_eval_temp; //pset on evaluation
reg [TX_PSET_WD-1:0] p_eval_prev; //pset on evaluation
reg                  fdbk_to_newcoef_transition;
reg                  last_pset_req; //last pset request within cfg_eq_pset_req_vector
reg                  last_fcoef_req; //last coef for fom request within cfg_max_fcoef_length
wire                 last_fcoef_req_i; //last coef for fom request within cfg_max_fcoef_length
reg                  final_max_fom_pset_req; //final pset request for the max figure of merit
reg                  final_max_fom_fcoef_req; //final fom coef request for the max figure of merit
wire                 final_max_fom_fcoef_req_i; //final fom coef request for the max figure of merit
reg                  first_pset_req;
reg                  first_fcoef_req;
wire                 first_fcoef_req_i;
reg                  pset_req_rejected;
reg                  pset_req_accepted;
reg                  pset_accept;
reg                  fcoef_req_rejected;
wire                 fcoef_req_rejected_i;
reg                  fcoef_req_accepted;
wire                 fcoef_req_accepted_i;
reg                  fcoef_accept;
wire                 fcoef_accept_i;
reg                  fcoef_fom_ge_pset_fom; // coef-fom >= pset-fom
reg                  already_timeout_500ns;
wire                 eq_setting_optimal;
wire                 eqpa_slv_clr;
wire                 pset_req;
wire                 fcoef_req;
wire                 in_pset_req;
wire                 in_pset_req_i;
wire                 in_fcoef_req;
wire                 last_bit;
wire                 fcoef_last_bit;
wire                 bit_0_is_1;
wire                 fcoef_gtr_0;
wire                 fcoef_req_n = (cfg_max_fcoef_length == 0); // no fom-coef feature at all
wire                 optimal_pre_cursor, optimal_pre_cursor_upd_pulse;
wire                 optimal_post_cursor, optimal_post_cursor_upd_pulse;
wire                 optimal_pre_cursor2, optimal_pre_cursor2_upd_pulse;

//latch phy_mac_dirfeedback
always @(posedge core_clk or negedge core_rst_n) begin : int_phy_mac_dirfeedback_PROC
    if ( !core_rst_n ) begin
        int_phy_mac_dirfeedback <= #TP '0;
        int_phy_mac_fomfeedback <= #TP '0;
    end else if (phy_mac_phystatus) begin
        int_phy_mac_dirfeedback <= #TP phy_mac_dirfeedback;
        int_phy_mac_fomfeedback <= #TP phy_mac_fomfeedback;
    end
end //always @(posedge

// for readability, split bus components into separate signals for pre and post, main cursor feedback is ignored
wire [1:0] int_phy_mac_dirfeedback_pre_cursor  = int_phy_mac_dirfeedback[1:0];
wire [1:0] int_phy_mac_dirfeedback_pre_cursor2 = g6_rate ? int_phy_mac_dirfeedback[3:2] : 2'b00; // use the 2-bit for pre_cursor2 for gen6 rate as the cursor is inferred from the controller
wire [1:0] int_phy_mac_dirfeedback_post_cursor = int_phy_mac_dirfeedback[5:4];

wire int_phy_mac_dirfeedback_all_zero = (int_phy_mac_dirfeedback_pre_cursor == 2'b00) && (int_phy_mac_dirfeedback_post_cursor == 2'b00) & (int_phy_mac_dirfeedback_pre_cursor2 == 2'b00);

//mac_phy_ftune_rtx rising edge, used to kick off Master state transition
//and load remote partner Transmitter coef (in use) into phy_mac_coef_rtx as
//start point for future requests
always @(posedge core_clk or negedge core_rst_n) begin : ftune_rtx_d_PROC
    if ( !core_rst_n ) begin
        ftune_rtx_d <= #TP '0;
    end else begin
        ftune_rtx_d <= #TP mac_phy_ftune_rtx;
    end
end //always @(posedge

assign ftune_rtx_rising_edge = (mac_phy_ftune_rtx & !ftune_rtx_d);

wire int_cdm_ras_des_eq_force_coef_rtx_en_g5;
assign int_cdm_ras_des_eq_force_coef_rtx_en_g5 = (g5_rate) ? cdm_ras_des_eq_force_coef_rtx_en_g5 : 1'b0;
wire int_cdm_ras_des_eq_force_coef_rtx_en_g6;
assign int_cdm_ras_des_eq_force_coef_rtx_en_g6 = (g6_rate) ? cdm_ras_des_eq_force_coef_rtx_en_g6 : 1'b0;
wire int_cdm_ras_des_eq_force_coef_rtx_en_g4;
assign int_cdm_ras_des_eq_force_coef_rtx_en_g4 = (g4_rate) ? cdm_ras_des_eq_force_coef_rtx_en_g4 : 1'b0;
wire int_cdm_ras_des_eq_force_coef_rtx_en;
assign int_cdm_ras_des_eq_force_coef_rtx_en = (g3_rate) ? cdm_ras_des_eq_force_coef_rtx_en : 1'b0;

wire   t_min_phase23_expired;
assign t_min_phase23_expired = min_phase23_timeout;
assign eq_setting_optimal =                             ( int_cdm_ras_des_eq_force_coef_rtx_en_g6 || int_cdm_ras_des_eq_force_coef_rtx_en_g5 || int_cdm_ras_des_eq_force_coef_rtx_en_g4 || int_cdm_ras_des_eq_force_coef_rtx_en) ? (c_eval == int_c_eval_new):
                              optimal_pre_cursor && optimal_post_cursor && (g6_rate ? optimal_pre_cursor2 : 1'b1) && t_min_phase23_expired;

//check whether remote partner Transmitter request is legal or not
//1 - illegal
assign c_eval_violate_tx_rules = g6_rate ? violate_rules_rtx_coef_g6(c_eval_new_r, mac_phy_fs, mac_phy_lf) : violate_rules_rtx_coef(c_eval_new_r[TX_COEF_WD_P3-1:0], mac_phy_fs, mac_phy_lf);

//need clear 2ms_timer and phystatus_asserted when enter S_INIT or NEW_COEFF or S_UNSUCCESS_EXIT states.
assign eqpa_slv_clr           = (eq_master_state == S_INIT || eq_master_state == S_NEW_COEFF || abort);
assign eqpa_slv_clr_phystatus = (eqpa_slv_clr || (eq_master_state == S_UNSUCCESS_EXIT));
assign eqpa_slv_clr_2ms_timer = (eqpa_slv_clr || (eq_master_state == S_TIMEOUT_REQ));

//do preset request
assign pset_req = |pset_req_vector; //pset_req_vector != 16'h0
assign fcoef_req = |fcoef_req_num_i;  //fcoef_req_num != 0
assign last_bit = (pset_req_vector[0] && (pset_req_vector[15:1] == 15'h0) ); //last bit set to 1 and in pset_req_vector[0]
assign fcoef_last_bit = fcoef_req_num_i == 5'd1; //last req for coef for fom
assign bit_0_is_1 = pset_req_vector[0];
assign fcoef_gtr_0 = fcoef_req_num_i > 5'd0; // fom-coef req number > 0
assign eqpa_slv_set = (eq_master_state == S_SKIP_EVAL);

assign in_pset_req_i = pset_req | last_pset_req | final_max_fom_pset_req;
assign fom_rxeq_redardless_rxts = cfg_gen34_eq_phase23_rxeq_regardless_rxts && (in_pset_req_i || in_fcoef_req); //(pset_req || last_pset_req || final_max_fom_pset_req || fcoef_req || last_fcoef_req || final_max_fom_fcoef_req);
assign in_fcoef_req = (fcoef_req | last_fcoef_req_i | final_max_fom_fcoef_req_i);

assign wait_rei_state = (eq_master_state == S_WAIT_REI);


assign in_pset_req               = 1'b1;
assign fcoef_req_num_i           = 0;
assign last_fcoef_req_i          = 0;
assign final_max_fom_fcoef_req_i = 0;
assign first_fcoef_req_i         = 0;
assign fcoef_req_rejected_i      = 0;
assign fcoef_req_accepted_i      = 0;
assign fcoef_accept_i            = 0;


//Master state machine
// LMD: Inferred a shift register
// LJ: pset_req_vector is needed to shift right by one bit every clock if its pset_req_vector[0] != 1 to determine request preset value
// leda W565 off
// ccx_fsm: ; eq_master_state; S_SKIP_EVAL->S_ABORT; "hard to hit because the state's previous state S_WAIT_RESPONSE already has the ltssm_timeout24ms or some lanes in S_SKIP_EVAL while the other lanes in S_EVAL and ltssm_timeout24ms."
always @(posedge core_clk or negedge core_rst_n) begin : eq_master_state_seq_PROC
    if ( !core_rst_n ) begin
        eq_master_state            <= #TP S_RST;
        mac_phy_rxeqeval           <= #TP '0;
        mac_phy_dirchange          <= #TP '0;
        phy_mac_ftune_rtx_done     <= #TP '0;
        phy_mac_ftune_rtx_optimal  <= #TP '0;
        mac_phy_invalid_req        <= #TP '0;
        mac_phy_rxeqinprogress     <= #TP '0;
        phy_mac_coef_rtx_upd       <= #TP '0;
        phy_mac_pset_rtx_upd       <= #TP '0;
        phy_mac_coef_rtx           <= #TP '0;
        phy_mac_pset_rtx           <= #TP '0;
        c_eval                     <= #TP '0;
        c_eval_prev                <= #TP '0;
        c_eval_temp                <= #TP '0;
        p_eval                     <= #TP '0;
        p_eval_temp                <= #TP '0;
        p_eval_prev                <= #TP '0;
        abort                      <= #TP '0;
        pset_req_vector            <= #TP '0;
        pset_loop_num              <= #TP '0;
        fcoef_req_num              <= #TP '0;
        fdbk_to_newcoef_transition <= #TP '0;
        last_pset_req              <= #TP '0;
        last_fcoef_req             <= #TP '0;
        final_max_fom_pset_req     <= #TP '0;
        final_max_fom_fcoef_req    <= #TP '0;
        first_pset_req             <= #TP '0;
        first_fcoef_req            <= #TP '0;
        max_fomfeedback            <= #TP '0;
        pset_req_rejected          <= #TP '0;
        pset_req_accepted          <= #TP '0;
        pset_accept                <= #TP '0;
        fcoef_req_rejected         <= #TP '0;
        fcoef_req_accepted         <= #TP '0;
        fcoef_accept               <= #TP '0;
        fcoef_fom_ge_pset_fom      <= #TP '0;
        already_timeout_500ns      <= #TP '0;
// ccx_line_begin: ; unreachable for Lane0 because Lane0 is always active.
    end else if ( ~ltssm_lanes_active ) begin
        eq_master_state <= #TP S_RST;
// ccx_line_end
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Using the sequential part (flip-flop description) and combinational part(case construct) of an FSM in the same always block increases complexity of the design thereby reducing the readability. This code is a simple. So, disable SpyGlass from reporting this error.
        case ( eq_master_state )
// spyglass enable_block STARC05-2.11.3.1

            S_INIT: begin
                //when enter mac_phy_ftune_rtx, mac_phy_coef_rtx/mac_phy_pset_rtx is remote partner Transmitter Coef/pset
                c_eval      <= #TP mac_phy_coef_rtx;
                c_eval_prev <= #TP mac_phy_coef_rtx;
                c_eval_temp <= #TP mac_phy_coef_rtx;
                if( cfg_eq_pset_req_as_coef ) begin
                    // Initialize to an out of range value, instead of the initial preset requested, to ensure that we can
                    // request as coefficient any pset in the req vector, including a preset that matches the initial preset.
                    // This is required because we have logic in the NEW_COEF state to cancel a preset request if the preset
                    // is the same as the initial preset.
                    // Opened IT#2729 to review if this logic in the NEW_COEF state can be removed.
                    p_eval      <= #TP {TX_PSET_WD{1'b1}};
                    p_eval_temp <= #TP {TX_PSET_WD{1'b1}};
                    p_eval_prev <= #TP {TX_PSET_WD{1'b1}};
                end else begin
                    p_eval      <= #TP mac_phy_pset_rtx;
                    p_eval_temp <= #TP mac_phy_pset_rtx;
                    p_eval_prev <= #TP mac_phy_pset_rtx;
                end
                phy_mac_coef_rtx           <= #TP mac_phy_coef_rtx;
                phy_mac_pset_rtx           <= #TP mac_phy_pset_rtx;
                phy_mac_ftune_rtx_done     <= #TP '0;
                phy_mac_ftune_rtx_optimal  <= #TP '0;
                phy_mac_coef_rtx_upd       <= #TP '0;
                phy_mac_pset_rtx_upd       <= #TP ((|cfg_eq_pset_req_vector || ~fcoef_req_n) && cfg_gen34_eq_phase23_rxeq_regardless_rxts) ? 1 : 0; // detect TS1s for initial pset request with regardless_rxts
                mac_phy_rxeqeval           <= #TP '0;
                mac_phy_dirchange          <= #TP (cfg_eq_feedback_mode == 1) ? 1'b0 : ~((|cfg_eq_pset_req_vector) | (|cfg_max_fcoef_length));
                mac_phy_invalid_req        <= #TP '0;
                mac_phy_rxeqinprogress     <= #TP '0;
                eq_master_state            <= #TP cfg_gen3_req_rst_eiec_disable ? S_EVAL : S_WAIT_REI;
                abort                      <= #TP '0;
                pset_req_vector            <= #TP cfg_eq_pset_req_vector;
                pset_loop_num              <= #TP '0;
                fcoef_req_num              <= #TP cfg_max_fcoef_length;
                fdbk_to_newcoef_transition <= #TP '0;
                last_pset_req              <= #TP '0;
                last_fcoef_req             <= #TP '0;
                final_max_fom_pset_req     <= #TP '0;
                final_max_fom_fcoef_req    <= #TP '0;
                first_pset_req             <= #TP |cfg_eq_pset_req_vector;
                first_fcoef_req            <= #TP |cfg_max_fcoef_length & ~(|cfg_eq_pset_req_vector); // have fom-coef req but no pset req
                max_fomfeedback            <= #TP '0;
                pset_req_rejected          <= #TP '0;
                pset_req_accepted          <= #TP '0;
                pset_accept                <= #TP '0;
                fcoef_req_rejected         <= #TP '0;
                fcoef_req_accepted         <= #TP '0;
                fcoef_accept               <= #TP '0;
                fcoef_fom_ge_pset_fom      <= #TP '0;
                already_timeout_500ns      <= #TP 1;
            end //S_INIT

            S_WAIT_REI: begin
                if ( fom_rxeq_redardless_rxts )
                // if fom_rxeq_redardless_rxts = 1, no wait REI because do evaluation without detecting Rx TS1s
                    eq_master_state <= #TP S_EVAL;
                else if ( eqctl_rst_eieos || timeout_2ms ) // if timeout_2ms, move to S_EVAL to prevent state machine deadlock. S_EVAL can handle the timeout
                    eq_master_state <= #TP S_EVAL;
            end // S_WAIT_REI

            S_EVAL: begin
                //start evaluation in 2ms when mac_phy_ftune_rtx is high
                //PIPE issues 1 cycle phystatus back after its evaluation

                //have to wait all active lanes phystatus back or optimal.
                //doing so is for All new preset or coefficient settings must be presented
                //on all configured Lanes simultaneously.
                //continue request for at least 1us.
                if ( timeout_500ns == 1 || already_timeout_500ns == 1 ) begin
                    mac_phy_rxeqeval       <= #TP 1; //wait for 500ns to ensure that remote port is transmitting using the requested settings. Then do evaluation in local port
                    mac_phy_rxeqinprogress <= #TP 1;
                    mac_phy_invalid_req    <= #TP (cfg_gen3_eq_invreq_eval_diff_disable == 0) ? 0 : mac_phy_invalid_req; //PIPE_4_2_final and higher requires mac_phy_invalid_req
                                                                                                                  //set to 0 at same cycle mac_phy_rxeqeval set to 1
                end

                // if FOM mode only, mac_phy_dirchange = 0 (do FOM evaluation)
                // if preset requests including the last one, mac_phy_dirchange = 0. This is based on the requirement of phy_mac_dirfeedback = 0 when mac_phy_dirchange = 0 for the last preset request.
                // if final preset request (preset with the highest FOM), mac_phy_dirchange = 1 (Direction Change evaluation) because the core needs phy_mac_dirfeedback to calculate the first coefficients for request
                // after FOM, the core sets mac_phy_dirchange = 1 for DIR evaluation including the final preset request explained above.
                mac_phy_dirchange <= #TP ( (cfg_eq_feedback_mode == 1) || (pset_req || last_pset_req || fcoef_req || last_fcoef_req_i) ) ? 1'b0 : 1'b1;

                if ( fom_rxeq_redardless_rxts ) begin
                // mac_phy_accept_rtx/mac_phy_reject_rtx is pulse only after timeout_1us since new pset request
                    if ( mac_phy_accept_rtx ) begin
                      if ( in_pset_req ) begin // fom-pset req
                        pset_req_accepted <= #TP 1;
                        pset_accept       <= #TP first_pset_req ? 0 : 1;
                        p_eval_prev       <= #TP p_eval_temp; //store valid preset
                      end else begin // fom-coef req
                        fcoef_req_accepted <= #TP 1;
                        fcoef_accept       <= #TP first_fcoef_req_i ? 0 : 1;
                        //c_eval_prev        <= #TP c_eval_temp; //store valid coef
                      end // if ( in_pset_req
                    end // if ( mac_phy_accept_rtx

                    if ( mac_phy_reject_rtx ) begin
                      if ( in_pset_req ) begin // fom-pset req
                        pset_req_rejected <= #TP 1;
                      end else begin // fom-coef req
                        fcoef_req_rejected <= #TP 1;
                      end
                    end // if ( mac_phy_reject_rtx
                end // if ( fom_rxeq_redardless_rxts

                if ( fom_rxeq_redardless_rxts ) begin
                    if ( mac_phy_accept_rtx ) begin // mac_phy_accept_rtx is a pulse indicating remote partner accept the new pset request after timeout_1us
                    // this is used to keep valid coeffs for transition from pset request to coef request.
                      if ( ~in_fcoef_req ) begin // no or after fom-coef
                        c_eval <= #TP mac_phy_coef_rtx; // mac_phy_coef_rtx is coef in use by remote partner
                      end // if ( fcoef_req_n
                        c_eval_prev <= #TP mac_phy_coef_rtx;
                      if ( final_max_fom_fcoef_req_i && ~fcoef_fom_ge_pset_fom ) begin // if final fcoef req but ~max_fcoef_fom, load coef from Rx coef by remote Txed
                        c_eval <= #TP mac_phy_coef_rtx; // mac_phy_coef_rtx is coef in use by remote partner
                      end // if ( final_max_fom_fcoef_req_i
                    end
                end else
                //if ~mac_phy_invalid_req, latch c_eval as mac_phy_coef_rtx is coef in use by remote partner.
                //this is used to keep valid coeffs for transition from pset request to coef request.
                if ( cfg_gen3_eq_invreq_eval_diff_disable ? !mac_phy_invalid_req : (!mac_phy_invalid_req && !mac_phy_rxeqeval) ) begin
                  if ( ~in_fcoef_req ) begin // no or after fom-coef
                    c_eval <= #TP mac_phy_coef_rtx;
                  end // if ( fcoef_req_n
                    c_eval_prev <= #TP mac_phy_coef_rtx;
                  if ( final_max_fom_fcoef_req_i && ~fcoef_fom_ge_pset_fom ) begin // if final fcoef req but ~max_fcoef_fom, load coef from Rx coef by remote Txed
                    c_eval <= #TP mac_phy_coef_rtx; // mac_phy_coef_rtx is coef in use by remote partner
                  end // if ( final_max_fom_fcoef_req_i
                end //if( !mac_phy_invalid_req

                if ( phystatus_asserted_all && timeout_1us && ~ltssm_timeout24ms ) begin
                    if ( fom_rxeq_redardless_rxts ) begin
                        mac_phy_rxeqeval <= #TP '0; // deassert evaluation but still waiting for Rx TS1s

                        if ( ts1_detected_all ) begin
                          if ( in_pset_req ) begin
                            if ( pset_req_accepted || pset_req_rejected ) // if Rx TS1s detected, move to request next pset
                                eq_master_state <= #TP S_FEEDBACK;
                            else if ( timeout_2_4ms ) begin // if timeout_2ms/4ms waiting for Rx TS1s, reject flag and move to request next pset
                                pset_req_rejected <= #TP 1;
                                eq_master_state   <= #TP S_FEEDBACK;
                            end
                          end else begin
                            if ( fcoef_req_accepted_i || fcoef_req_rejected_i ) // if Rx TS1s detected, move to request next pset
                                eq_master_state <= #TP S_FEEDBACK;
                            else if ( timeout_2_4ms ) begin // if timeout_2ms/4ms waiting for Rx TS1s, reject flag and move to request next pset
                                fcoef_req_rejected <= #TP 1;
                                eq_master_state <= #TP S_FEEDBACK;
                            end
                          end // if ( in_pset_req
                        end // if ( ts1_detected_all
                    end else begin
                        eq_master_state <= #TP S_FEEDBACK;
                    end
                //abort 24ms phase or 2ms iteration.
                //if some lanes are waiting for accept/reject back from remote in 2ms/4ms & timeout_2_4ms,
                //don't go ABORT. go for re-evaluation.
                //rxeqeval_all is asserted when all active lanes eighter optimum or mac_phy_rxeqeval==1 or eqpa_slv_set==1.
                //rxeqeval_all is used here for that if any active lane is in WAIT_RESPONSE and timeout_2_4ms, don't move to ABORT, we may retry evaluation.
                end else if ( ltssm_timeout24ms == 1 || (timeout_2_4ms == 1 && rxeqeval_all && !cfg_eq_p23_eval_timeout_2ms_disable) ) begin
                    mac_phy_rxeqeval <= #TP cfg_p23_exit_mode & ltssm_timeout24ms;
                    mac_phy_invalid_req <= #TP (cfg_gen3_eq_invreq_eval_diff_disable == 0) ? 0 : mac_phy_invalid_req;
                    abort <= #TP 1;
                    eq_master_state <= #TP S_ABORT;
                end
            end //S_EVAL

            S_SKIP_EVAL: begin
                phy_mac_coef_rtx_upd <= #TP '0;
                phy_mac_pset_rtx_upd <= #TP '0;

                if ( phystatus_asserted_all && timeout_1us ) begin
                    eq_master_state <= #TP S_FEEDBACK;
                //abort 24ms phase or 2ms iteration.
                //if some lanes are waiting for accept/reject back from remote in 2ms & timeout_2ms,
                //don't go ABORT. go for re-evaluation.
                //rxeqeval_all is asserted when all active lanes eighter optimum or mac_phy_rxeqeval==1 or eqpa_slv_set==1.
                //rxeqeval_all is used here for that if any active lane is in WAIT_RESPONSE and timeout_2ms, don't move to ABORT, we may retry evaluation.
                //end else if ( ltssm_timeout24ms == 1 || (timeout_2ms == 1 && rxeqeval_all && !cfg_eq_p23_eval_timeout_2ms_disable) ) begin
// ccx_line_begin: ; hard to hit because the state's previous state S_WAIT_RESPONSE already has the ltssm_timeout24ms or some lanes in S_SKIP_EVAL while the other lanes in S_EVAL and ltssm_timeout24ms
                end else if ( ltssm_timeout24ms == 1 ) begin
                    abort <= #TP 1;
                    eq_master_state <= #TP S_ABORT;
                end
// ccx_line_end
            end //S_SKIP_EVAL

            S_FEEDBACK: begin
                pset_req_accepted     <= #TP '0;
                fcoef_req_accepted    <= #TP '0;
                already_timeout_500ns <= #TP '0;

                // reset to 0 after detecting RX TS1s in eqctl
                phy_mac_coef_rtx_upd  <= #TP '0;
                phy_mac_pset_rtx_upd  <= #TP '0;

                //check whether the feedback is optimal or go ahead for the next request
                mac_phy_rxeqeval      <= #TP '0;
                mac_phy_invalid_req   <= #TP '0;
                if ( pset_req ) begin //do preset
                    //make a new preset request
                    eq_master_state <= #TP S_NEW_COEFF;
                    fdbk_to_newcoef_transition <= #TP 1; //one cycle flag to latch c_eval/p_eval in S_NEW_COEFF state
                end else begin
                    if ( last_pset_req ) begin
                        //last pset request within cfg_eq_pset_req_vector
                        last_pset_req <= #TP '0;
                        if ( !pset_accept && (~cfg_gen34_eq_phase23_rxeq_regardless_rxts || cfg_eq_feedback_mode != 0) ) begin //if all pset requests rejected or timeout
                        // for cfg_gen34_eq_phase23_rxeq_regardless_rxts, always do final_max_fom_pset_req so that all lanes move to coef request at the same time.
                        // doing so is to avoid some lanes in final_max_fom_pset_req, the other lanes in coef request. It is for REI bit set and S_WAIT_REI state synchronise across all lanes
                        // if FOM only, move into the process anyway
                            if ( cfg_eq_feedback_mode == 0 || ~fcoef_req_n ) begin //direction change mode or fom-coef req
                                eq_master_state <= #TP S_NEW_COEFF; //move to do coef request
                                fdbk_to_newcoef_transition <= #TP                                                                          0;
                            end else begin //figure of morit or reserved
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                            end
                        end else if ( (int_phy_mac_fomfeedback >= max_fomfeedback) && !pset_req_rejected && (~cfg_gen34_eq_phase23_rxeq_regardless_rxts || cfg_eq_feedback_mode != 0) ) begin
                        // for cfg_gen34_eq_phase23_rxeq_regardless_rxts, always do final_max_fom_pset_req so that all lanes move to coef request at the same time.
                        // doing so is to avoid some lanes in final_max_fom_pset_req, the other lanes in coef request. It is for REI bit set and S_WAIT_REI state synchronise across all lanes
                        // if FOM only, move into the process anyway
                            //the last pset req is max figure of merit and accepted by remote partner, no pset request
                            if ( cfg_eq_feedback_mode == 0 || ~fcoef_req_n ) begin //direction change mode or fom-coef req
                                eq_master_state <= #TP S_NEW_COEFF; //move to do coef request
                                fdbk_to_newcoef_transition <= #TP 1; // used to load coef for last pset only, so pset_req_rejected set to 0
                            end else if ( cfg_eq_feedback_mode == 1 ) begin //figure of merit
                              if( cdm_ras_des_eq_fom_target_en && int_phy_mac_fomfeedback < cdm_ras_des_eq_fom_target )
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                              else
                                eq_master_state <= #TP S_SUCCESS_EXIT; //complete with preset request only
                            end else begin //reserved
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                            end
                        end else begin
                            //do final pset req with max_fomfeedback
                            //if final request rejected, keep previous c_eval. if accepted, means remote partner is using the last pset, so need update c_eval even if its int_phy_mac_fomfeedback < max_fomfeedback
                            fdbk_to_newcoef_transition <= #TP (pset_req_rejected ? 0 : 1);
                            final_max_fom_pset_req     <= #TP fcoef_req_n ? 1 : 0;
                            eq_master_state            <= #TP S_NEW_COEFF; //do final pset request with max figure of merit
                        end //if ( (int_phy_mac_fomfeedback >
                    end else if ( final_max_fom_pset_req ) begin
                        //final pset req with max_fomfeedback
                        final_max_fom_pset_req <= #TP '0;
                        if ( cfg_eq_feedback_mode == 0 ) begin //direction change mode
                            eq_master_state <= #TP S_NEW_COEFF; //move to do coef request
                            fdbk_to_newcoef_transition <= #TP                                                                      (pset_req_rejected ? 0 : 1);
                            if ( eq_setting_optimal ) eq_master_state <= #TP S_SUCCESS_EXIT; // if DirChange feedback = optimal, exit eq master phase successfully
                        end else if ( cfg_eq_feedback_mode == 1 ) begin //figure of merit
                            if ( pset_req_rejected )
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                            else
                              if ( cdm_ras_des_eq_fom_target_en && int_phy_mac_fomfeedback < cdm_ras_des_eq_fom_target )
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                              else
                                eq_master_state <= #TP S_SUCCESS_EXIT; //complete with preset request only
                        end else begin //reserved
// ccx_line_begin: ; Redundant code because cfg_eq_feedback_mode only = 0: DirectionChange and = 1: FigureOfMerit. Set cfg_eq_feedback_mode > 1 (meaningless) is not needed to test it.
                            eq_master_state <= #TP S_UNSUCCESS_EXIT; //complete with preset request only
// ccx_line_end
                        end
                    end else if ( fcoef_req ) begin //do fom-coef
                    //make a new fom-coef request
                        eq_master_state <= #TP S_NEW_COEFF;
                        fdbk_to_newcoef_transition <= #TP 1; //one cycle flag to latch c_eval/p_eval in S_NEW_COEFF state
                    end else if ( last_fcoef_req_i ) begin
                        //last fom-coef request within cfg_max_fcoef_length
                        last_fcoef_req <= #TP '0;
                        if ( !(fcoef_accept_i || pset_accept) && (~cfg_gen34_eq_phase23_rxeq_regardless_rxts || cfg_eq_feedback_mode != 0) ) begin //if all fom-coef requests rejected or timeout
                        // for cfg_gen34_eq_phase23_rxeq_regardless_rxts, always do final_max_fom_pset_req so that all lanes move to coef request at the same time.
                        // doing so is to avoid some lanes in final_max_fom_pset_req, the other lanes in coef request. It is for REI bit set and S_WAIT_REI state synchronise across all lanes
                        // if FOM only, move into the process anyway
                            if ( cfg_eq_feedback_mode == 0 ) begin //direction change mode
                                eq_master_state <= #TP S_NEW_COEFF; //move to do coef request
                                fdbk_to_newcoef_transition <= #TP                                                                          0;
                            end else begin //figure of morit or reserved
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                            end
                        end else if ( (int_phy_mac_fomfeedback >= max_fomfeedback) && !fcoef_req_rejected_i && (~cfg_gen34_eq_phase23_rxeq_regardless_rxts || cfg_eq_feedback_mode != 0) ) begin
                        // for cfg_gen34_eq_phase23_rxeq_regardless_rxts, always do final_max_fom_pset_req so that all lanes move to coef request at the same time.
                        // doing so is to avoid some lanes in final_max_fom_pset_req, the other lanes in coef request. It is for REI bit set and S_WAIT_REI state synchronise across all lanes
                        // if FOM only, move into the process anyway
                            //the last pset req is max figure of merit and accepted by remote partner, no pset request
                            if ( cfg_eq_feedback_mode == 0 ) begin //direction change mode
                                eq_master_state <= #TP S_NEW_COEFF; //move to do coef request
                                fdbk_to_newcoef_transition <= #TP 1; // used to load coef for last pset only, so pset_req_rejected set to 0
                                last_fcoef_req <= #TP 1; // to load c_eval = c_eval_prev
                            end else if ( cfg_eq_feedback_mode == 1 ) begin //figure of merit
                              if( cdm_ras_des_eq_fom_target_en && int_phy_mac_fomfeedback < cdm_ras_des_eq_fom_target )
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                              else
                                eq_master_state <= #TP S_SUCCESS_EXIT; //complete with preset request only
                            end else begin //reserved
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                            end

                            fcoef_fom_ge_pset_fom <= #TP 1'b1;
                        end else begin
                            //do final fom-coef req with max_fomfeedback. it could be pset which has max fom than fom-coef. so final_max_fom_fcoef_req has two: final max-fom-pset req or final max-fom-coef req
                            //if final request rejected, keep previous c_eval. if accepted, means remote partner is using the last coef, so need update c_eval even if its int_phy_mac_fomfeedback < max_fomfeedback
                            fdbk_to_newcoef_transition <= #TP (fcoef_req_rejected_i ? 0 : 1);
                            final_max_fom_fcoef_req <= #TP 1;
                            eq_master_state <= #TP S_NEW_COEFF; //do final fom-coef request with max figure of merit
                        end //if ( (int_phy_mac_fomfeedback >
                    end else if ( final_max_fom_fcoef_req_i ) begin
                        //final pset req with max_fomfeedback
                        final_max_fom_fcoef_req <= #TP '0;
                        if ( cfg_eq_feedback_mode == 0 ) begin //direction change mode
                            eq_master_state <= #TP S_NEW_COEFF; //move to do coef request
                            fdbk_to_newcoef_transition <= #TP                                                                      (fcoef_req_rejected_i ? 0 : 1);
                            if ( eq_setting_optimal ) eq_master_state <= #TP S_SUCCESS_EXIT; // if DirChange feedback = optimal, exit eq master phase successfully
                        end else if ( cfg_eq_feedback_mode == 1 ) begin //figure of merit
                            if ( fcoef_req_rejected_i )
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                            else
                              if ( cdm_ras_des_eq_fom_target_en && int_phy_mac_fomfeedback < cdm_ras_des_eq_fom_target )
                                eq_master_state <= #TP S_UNSUCCESS_EXIT;
                              else
                                eq_master_state <= #TP S_SUCCESS_EXIT; //complete with preset request only
                        end else begin //reserved
// ccx_line_begin: ; Redundant code because cfg_eq_feedback_mode only = 0: DirectionChange and = 1: FigureOfMerit. Set cfg_eq_feedback_mode > 1 (meaningless) is not needed to test it.
                            eq_master_state <= #TP S_UNSUCCESS_EXIT; //complete with preset request only
// ccx_line_end
                        end
                    end else if ( eq_setting_optimal ) begin //coef eval feedback
                        //achieve optimal
                        eq_master_state <= #TP S_SUCCESS_EXIT;
                    end else if ( (cfg_eq_feedback_mode==1) && (cfg_eq_pset_req_vector==0 && fcoef_req_n) ) begin // fom with no preset and no fom-coef requests, used to don't change the remote transmitter settings when we are in master phase
                        eq_master_state <= #TP S_SUCCESS_EXIT;
                    end else begin
                        //make new coef request
                        eq_master_state <= #TP S_NEW_COEFF;
                        fdbk_to_newcoef_transition <= #TP 1;
                    end
                end //if ( pset_req
            end //S_FEEDBACK

            S_NEW_COEFF: begin
                //based on feedback, using search algorithms to generate new coef.
                //for pset request, right shifting pset_req_vector until pset_req_vector[0]=1.
                //Meanwhile, increment right shift bit number which is preset value to be requested.
                fdbk_to_newcoef_transition <= #TP '0;
                pset_req_rejected          <= #TP '0;
                fcoef_req_rejected         <= #TP '0;
                if ( fdbk_to_newcoef_transition ) begin //latch c_eval/p_eval
                  if ( in_pset_req ) begin
                    if ( !pset_req_rejected ) begin //don't latch the pset rejected by remote partner
                        if ( int_phy_mac_fomfeedback >= max_fomfeedback ) begin //keep max figure of merit and its corresponding preset p_eval
                            if ( first_pset_req ) begin //just after initial evaluation here
                                if ( cfg_eq_fom_include_init_eval ) begin
                                    max_fomfeedback <= #TP int_phy_mac_fomfeedback; //find max fom including initial evaluation fom
                                end
                            end else begin
                                max_fomfeedback <= #TP int_phy_mac_fomfeedback;
                            end

                            p_eval <= #TP p_eval_prev; //p_eval is the preset with max fom
                        end
                    end //if ( !first_pset_req
                  end else begin // if ( in_pset_req
                    if ( !fcoef_req_rejected_i ) begin //don't latch the fcoef rejected by remote partner
                        if ( int_phy_mac_fomfeedback >= max_fomfeedback ) begin //keep max figure of merit and its corresponding preset p_eval
                            if ( first_fcoef_req_i ) begin //just after initial evaluation here
                                if ( cfg_eq_fom_include_init_eval ) begin
                                    max_fomfeedback <= #TP int_phy_mac_fomfeedback; //find max fom including initial evaluation fom
                                end
                            end else begin
                                max_fomfeedback <= #TP int_phy_mac_fomfeedback;
                            end

                            c_eval <= #TP c_eval_prev; //c_eval is the coef with max fom
                            fcoef_fom_ge_pset_fom <= #TP 1'b1;
                        end
                    end //if ( !first_pset_req
                    last_fcoef_req <= #TP '0;
                  end // if ( in_pset_req

                  //if preset/fom-coef request, don't load c_eval as it was lacthed in S_EVAL
                  if ( ~(pset_req || in_fcoef_req) ) begin
                      c_eval_prev <= #TP c_eval; //c_eval_prev is used to restore previous valid coefficients.
                      c_eval <= #TP int_c_eval_new;
                  end //if ( ~pset_req
                end //fdbk_to_newcoef_transition

                if ( in_pset_req ) begin
                    if ( !bit_0_is_1 ) begin //looking for bit[i]=1 on pset_req_vector right shifting
                        pset_loop_num <= #TP pset_loop_num + 1; //preset = pset_loop_num
                        pset_req_vector <= #TP (pset_req_vector >> 1);
                    end //if ( !bit_0_is_1

                    if ( last_bit ) begin //last preset request from cfg_eq_pset_req_vector
                        last_pset_req <= #TP 1;
                    end //if ( last_bit
                end else begin // fcoef req if it exists
                    if ( fcoef_last_bit ) begin //last fom-coef request from cfg_max_fcoef_length
                        last_fcoef_req <= #TP 1;
                    end //if ( last_bit
                end // if ( in_pset_req

                if ( pset_req ) begin //do pset request
                    if ( bit_0_is_1 ) begin //if bit[0] == 1 during pset_req_vector right shifting
                        first_pset_req  <= #TP '0;
                        eq_master_state <= #TP S_REQUEST; //do pset request
                    end //end else if ( bit_0_is_1
                end else if ( final_max_fom_pset_req ) begin
                    eq_master_state <= #TP S_REQUEST; //do final pset request with max figure of merit
                end else if ( fcoef_req ) begin // do fom-coef req
                    first_fcoef_req <= #TP '0;
                    eq_master_state <= #TP S_REQUEST; //do fom-coef request
                end else if ( final_max_fom_fcoef_req_i ) begin
                    eq_master_state <= #TP S_REQUEST; //do final fom-coef request with max figure of merit
                end else if ( c_eval_violate_tx_rules == 1 ) begin //illegal coef request after local check
                    //illegal coef request
                    eq_master_state <= #TP S_INVALID_REQ;
                end else begin
                    //legal coef request
                    eq_master_state <= #TP S_REQUEST;
                end
            end //S_NEW_COEFF

            S_REQUEST: begin //trigger new request
                if ( bit_0_is_1 || final_max_fom_pset_req ) begin //do preset request
                    if( !cfg_eq_pset_req_as_coef ) begin
                        phy_mac_pset_rtx_upd <= #TP 1;
                    end else begin
                        phy_mac_coef_rtx_upd <= #TP 1;
                    end

                    if ( final_max_fom_pset_req ) begin
                        //for final pset request, back to the preset with max figure of merit
                        phy_mac_pset_rtx <= #TP p_eval;
                    end else begin
                        phy_mac_pset_rtx <= #TP pset_loop_num;
                    end

                    pset_req_vector <= #TP (pset_req_vector >> 1);
                    pset_loop_num   <= #TP pset_loop_num + 1;
                    p_eval_temp     <= #TP pset_loop_num; //store preset value, must stay one cycle at this state

                    eq_master_state <= #TP S_WAIT_RESPONSE;
                end else if ( in_fcoef_req ) begin //do fom-coef request
                    if ( ~fcoef_fom_ge_pset_fom && final_max_fom_fcoef_req_i ) // max coef-fom < max pset-fom
                        phy_mac_pset_rtx_upd <= #TP 1; // final pset req
                    else
                        phy_mac_coef_rtx_upd <= #TP 1;

                    if ( final_max_fom_fcoef_req_i ) begin
                        if ( ~fcoef_fom_ge_pset_fom ) // max coef-fom < max pset-fom
                            phy_mac_pset_rtx <= #TP p_eval; // final pset req
                        else
                            phy_mac_coef_rtx <= #TP c_eval; //for final fcoef request, back to the coef with max figure of merit
                    end else begin
                        phy_mac_coef_rtx <= #TP cfg_fcoefs;
                    end

                    fcoef_req_num <= #TP fcoef_req ? (fcoef_req_num_i - 1) : fcoef_req_num_i;
                    c_eval_temp   <= #TP final_max_fom_fcoef_req_i ? c_eval : cfg_fcoefs; //store fom-coef value from programmed CDM based on fcoef_req_num (coef_vec_index), must stay one cycle at this state

                    eq_master_state <= #TP S_WAIT_RESPONSE;
                end else begin //do coef request
                    phy_mac_coef_rtx_upd <= #TP 1;
                    phy_mac_coef_rtx     <= #TP c_eval;
                    eq_master_state      <= #TP S_WAIT_RESPONSE;
                end //end else begin
            end //S_REQUEST

            S_WAIT_RESPONSE: begin
                if ( fom_rxeq_redardless_rxts ) begin
                // do Rx evaluation regardless after timeout_500ns after new pset request (timeout_500ns is in S_EVAL state)
                // This is only for FOM, i.e. pset_req_vector != 0 + final_max_fom_pset_req
                    eq_master_state <= #TP S_EVAL;
                end else if ( mac_phy_accept_rtx == 1 ) begin
                //wait for response from remote partner
                  if ( in_pset_req ) begin
                    //request accepted
                    pset_accept <= #TP 1;

                    p_eval_prev <= #TP p_eval_temp; //store valid preset
                  end else if ( in_fcoef_req ) begin // fom-coef requests
                    fcoef_accept <= #TP 1;

                    c_eval_prev <= #TP c_eval_temp; //store valid preset
                  end // if ( in_pset_req

                  eq_master_state <= #TP cfg_gen3_req_rst_eiec_disable ? S_EVAL : S_WAIT_REI;
                end else if ( mac_phy_reject_rtx == 1 ) begin
                    //request rejected
                  if ( in_pset_req ) begin
                    if ( pset_req || last_pset_req || final_max_fom_pset_req ) begin //in pset req
                        pset_req_rejected <= #TP 1;
                        eq_master_state   <= #TP S_SKIP_EVAL;
                    end else begin
                        eq_master_state   <= #TP S_INVALID_REQ;
                    end
                  end else begin
                    if ( in_fcoef_req ) begin //in fom-coef req
                        fcoef_req_rejected <= #TP 1;
                        eq_master_state    <= #TP S_SKIP_EVAL;
                    end else begin
                        eq_master_state    <= #TP S_INVALID_REQ;
                    end
                  end // if ( in_pset_req
                end else if ( timeout_2_4ms == 1 ) begin
                    //no response in 2ms
                  if ( in_pset_req ) begin
                    if ( pset_req || last_pset_req || final_max_fom_pset_req ) begin //in pset req
                        pset_req_rejected <= #TP 1;
                        eq_master_state <= #TP S_SKIP_EVAL;
                    end else begin
                        eq_master_state <= #TP S_TIMEOUT_REQ;
                    end
                  end else begin
                    if ( in_fcoef_req ) begin //in fom-coef req
                        fcoef_req_rejected <= #TP 1;
                        eq_master_state <= #TP S_SKIP_EVAL;
                    end else begin
                        eq_master_state <= #TP S_TIMEOUT_REQ;
                    end
                  end // if ( in_pset_req

                    if ( cfg_p23_exit_mode && ltssm_timeout24ms )
                        eq_master_state <= #TP S_EVAL; // this is only for DirChange. FOM must complete before timeout_24ms
                end else if ( ltssm_timeout24ms == 1 ) begin
                    //exit in 24ms master phase
                    eq_master_state <= #TP S_UNSUCCESS_EXIT;
                    if ( cfg_p23_exit_mode ) begin
                        //this is only for DirChange. FOM must complete before timeout_24ms. Stay in this state until accept/reject/timeout_2ms
                        //to prevent timeout_24ms before the new request coef has not received and cause the remote partner to have diff coef in the coming Recovery.RcvrLock state
                        //and so will have re-do eq.
                        eq_master_state <= #TP S_WAIT_RESPONSE;
                    end
                end
            end //S_WAIT_RESPONSE

            S_ABORT: begin
                pset_req_accepted     <= #TP '0;
                fcoef_req_accepted    <= #TP '0;
                already_timeout_500ns <= #TP '0;
                abort                 <= #TP '0;
                mac_phy_rxeqeval      <= #TP cfg_p23_exit_mode ? mac_phy_rxeqeval : '0;
                mac_phy_invalid_req   <= #TP (cfg_gen3_eq_invreq_eval_diff_disable == 0) ? '0 : mac_phy_invalid_req;
                phy_mac_coef_rtx_upd  <= #TP '0;
                phy_mac_pset_rtx_upd  <= #TP '0;
                //after mac_phy_rxeqeval=0 in abort case, PHY must issue phy_mac_phystatus back to MAC
                //put 2ms to prevent deadlock, i.e., if phy_mac_phystatus never back
                if ( phystatus_asserted || phy_mac_phystatus || (timeout_2_4ms && !abort) ) begin
                    eq_master_state <= #TP S_UNSUCCESS_EXIT;
                end
            end //S_ABORT

            S_INVALID_REQ: begin
                //restore previous valid coefficients
                // if FOM mode only, mac_phy_dirchange = 0 (do FOM evaluation)
                // if preset requests including the last one, mac_phy_dirchange = 0. This is based on the requirement of phy_mac_dirfeedback = 0 when mac_phy_dirchange = 0 for the last preset request.
                // if final preset request (preset with the highest FOM), mac_phy_dirchange = 1 (Direction Change evaluation) because the core needs phy_mac_dirfeedback to calculate the first coefficients for request
                // after FOM, the core sets mac_phy_dirchange = 1 for DIR evaluation including the final preset request explained above.
                mac_phy_dirchange     <= #TP ( (cfg_eq_feedback_mode == 1) || (pset_req || last_pset_req || fcoef_req || last_fcoef_req_i) ) ? 1'b0 : 1'b1;
                c_eval                <= #TP c_eval_prev;
                already_timeout_500ns <= #TP 1;
                mac_phy_rxeqeval      <= #TP (cfg_gen3_eq_invreq_eval_diff_disable == 0) ? 0 : 1; //PIPE_4_2_final requires mac_phy_invalid_req set to 1 but mac_phy_rxeqeval set to 0
                mac_phy_invalid_req   <= #TP 1;
                eq_master_state       <= #TP cfg_gen3_req_rst_eiec_disable ? S_EVAL : S_WAIT_REI;
            end //S_INVALID_REQ

            S_TIMEOUT_REQ: begin
                //if timeout_2ms in S_WAIT_RESPONSE, restore previous valid coefficients
                c_eval               <= #TP c_eval_prev;
                phy_mac_coef_rtx_upd <= #TP '0;
                phy_mac_pset_rtx_upd <= #TP '0;
                eq_master_state      <= #TP S_REQUEST;
            end //S_TIMEOUT_REQ

            S_UNSUCCESS_EXIT: begin
                //didn't achieve optimal settings
                phy_mac_coef_rtx_upd      <= #TP '0;
                already_timeout_500ns     <= #TP '0;
                phy_mac_pset_rtx_upd      <= #TP '0;
                phy_mac_ftune_rtx_done    <= #TP 1;
                phy_mac_ftune_rtx_optimal <= #TP '0;
                mac_phy_rxeqinprogress    <= #TP '0;
                pset_accept               <= #TP '0;
                first_pset_req            <= #TP '0;
                last_pset_req             <= #TP '0;
                final_max_fom_pset_req    <= #TP '0;
                pset_req_rejected         <= #TP '0;
                pset_req_accepted         <= #TP '0;
                fcoef_accept              <= #TP '0;
                first_fcoef_req           <= #TP '0;
                last_fcoef_req            <= #TP '0;
                final_max_fom_fcoef_req   <= #TP '0;
                fcoef_req_rejected        <= #TP '0;
                fcoef_req_accepted        <= #TP '0;
                fcoef_fom_ge_pset_fom     <= #TP 1'b0;
                mac_phy_rxeqeval          <= #TP '0;
                mac_phy_dirchange         <= #TP '0;
                mac_phy_invalid_req       <= #TP '0;
                eq_master_state           <= #TP S_RST;
            end //S_UNSUCCESS_EXIT

            S_SUCCESS_EXIT: begin
                //achieve optimal
                phy_mac_coef_rtx_upd      <= #TP '0;
                phy_mac_pset_rtx_upd      <= #TP '0;
                phy_mac_ftune_rtx_done    <= #TP 1;
                already_timeout_500ns     <= #TP '0;
                phy_mac_ftune_rtx_optimal <= #TP 1;
                mac_phy_rxeqinprogress    <= #TP '0;
                mac_phy_rxeqeval          <= #TP '0;
                mac_phy_dirchange         <= #TP '0;
                mac_phy_invalid_req       <= #TP '0;
                pset_accept               <= #TP '0;
                first_pset_req            <= #TP '0;
                last_pset_req             <= #TP '0;
                final_max_fom_pset_req    <= #TP '0;
                pset_req_rejected         <= #TP '0;
                pset_req_accepted         <= #TP '0;
                fcoef_accept              <= #TP '0;
                first_fcoef_req           <= #TP '0;
                last_fcoef_req            <= #TP '0;
                final_max_fom_fcoef_req   <= #TP '0;
                fcoef_req_rejected        <= #TP '0;
                fcoef_req_accepted        <= #TP '0;
                fcoef_fom_ge_pset_fom     <= #TP 1'b0;
                eq_master_state           <= #TP S_RST;
            end //S_SUCCESS_EXIT

            default: begin //S_RST
                //start fine tuning remote partner Transmitter
                if ( ftune_rtx_rising_edge ) begin
                    eq_master_state <= #TP S_INIT;
                end

                //if !ftune_rtx, the following signals must be reset
                if ( !mac_phy_ftune_rtx ) begin
                    phy_mac_ftune_rtx_done    <= #TP '0;
                    already_timeout_500ns     <= #TP '0;
                    phy_mac_ftune_rtx_optimal <= #TP '0;
                    mac_phy_rxeqeval          <= #TP '0;
                    mac_phy_dirchange         <= #TP '0;
                    mac_phy_invalid_req       <= #TP '0;
                    mac_phy_rxeqinprogress    <= #TP '0;
                end //if ( mac_phy_ftune_rtx
            end //S_RST
        endcase
    end
end //Master state machine
// leda W565 on

assign ts1_detected = pset_req_accepted | pset_req_rejected || fcoef_req_accepted_i || fcoef_req_rejected_i;
assign eqpa_fom_rxeq_redardless_rxts = |fom_rxeq_redardless_rxts;

assign c_eval_pre_cursor2 = g6_rate ? {3'h0,c_eval[0 +: 3] } : 6'h0;
assign c_eval_pre_cursor  = g6_rate ? {2'h0,c_eval[3 +: 4] } : c_eval[0 +: TX_FS_WD];
assign c_eval_post_cursor = g6_rate ? {1'h0,c_eval[13 +: 5]} : c_eval[12 +: TX_FS_WD];

//Wait for the required time (500 ns plus the roundtrip delay including the logic delays through
//the Port) to ensure that, if accepted, the remote Port is transmitting using
//the requested settings.

//if mac_phy_accept_rtx = 1 in S_WAIT_RESPONSE, next state must be S_EVAL.
//this triggers the clock count from 0 when enter S_EVAL.
assign req_accepted = (eq_master_state == S_WAIT_RESPONSE && mac_phy_accept_rtx == 1);

reg [2:0] current_data_rate_d;
wire ps_current_data_rate_g3;
wire ps_current_data_rate_g4;
wire ps_current_data_rate_g5;
wire ps_current_data_rate_g6;

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        current_data_rate_d <= #TP 2'b00;
    end else begin
        current_data_rate_d <= #TP current_data_rate;
    end
end
assign ps_current_data_rate_g3 = (current_data_rate != current_data_rate_d) && (g3_rate );
assign ps_current_data_rate_g4 = (current_data_rate != current_data_rate_d) && (g4_rate );
assign ps_current_data_rate_g5 = (current_data_rate != current_data_rate_d) && (g5_rate );
assign ps_current_data_rate_g6 = (current_data_rate != current_data_rate_d) && (g6_rate );

/* // removed locally generated timeout_500ns in smlh_eqpa_slv, instead from smlh_eqpa, 03June2015, Req->1us->RxTS1->RxEqEval.
   // For new feature REGARDLESS_RXTS, Req->500ns->RxEqEval->1us->RxTS1
`ifdef CX_GEN4_SPEED
assign timeout_500ns = (current_data_rate != `GEN4_RATE ) ? (timer_500ns == gen3_500ns_cmp) : (timer_500ns == gen4_500ns_cmp);
`else // CX_GEN4_SPEED
assign timeout_500ns = (timer_500ns == gen3_500ns_cmp);
`endif // CX_GEN4_SPEED
*/

//mux preset, fs, lf for preset to coefficients mapping
//1. use_pset=1, map local pset to coef
//2. mac_phy_ftune_ltx=1, map local pset to coef
//3. else (mac_phy_ftune_rtx=1), map remote pset to coef
assign use_pset_or_ftune_ltx = (use_pset || mac_phy_ftune_ltx || mac_phy_lpbk_ftune_ltx);
assign preset   = use_pset_or_ftune_ltx ? mac_phy_pset_ltx : phy_mac_pset_rtx;
assign {lf, fs} = use_pset_or_ftune_ltx ? phy_mac_fslf_ltx : {mac_phy_lf, mac_phy_fs};

//=========================================================================================
// logic below for convergence algorithm using queue of values for precursor and postcursor
//=========================================================================================
localparam COEFQ_DEPTH = `CX_GEN3_EQ_COEFQ_DEPTH; // coefficient queue depth

reg                 rxeqeval_d;
wire                c_eval_push;
reg                 c_eval_push_valid;

always @(posedge core_clk or negedge core_rst_n) begin : rxeqeval_d_seq_PROC
    if ( !core_rst_n ) begin
        rxeqeval_d <= #TP '0;
    end else begin
        rxeqeval_d <= #TP mac_phy_rxeqeval;
    end
end

//c_eval_push should be starting from the first coefficients request.
//Doing so is to exclude preset evaluations.
always @(posedge core_clk or negedge core_rst_n) begin : c_eval_push_valid_PROC
    if (!core_rst_n) begin
        c_eval_push_valid <= #TP '0;
    end else if (!mac_phy_ftune_rtx) begin
        c_eval_push_valid <= #TP '0;
    end else if (phy_mac_coef_rtx_upd) begin
        c_eval_push_valid <= #TP 1;
    end
end

// use rxeqeval rising edge to push coefficients into the queue
assign c_eval_push = (mac_phy_rxeqeval & ~rxeqeval_d & c_eval_push_valid);

wire  [N_EVALS_WD-1:0] cfg_eq_dcm_n_evals = (g6_rate ) ? cfg_gen6_eq_dcm_n_evals : (g5_rate ) ? cfg_gen5_eq_dcm_n_evals : (~g4_rate ) ? cfg_gen3_eq_dcm_n_evals : cfg_gen4_eq_dcm_n_evals;
wire  [N_EVALS_WD-2:0] cfg_eq_dcm_max_precursor_delta = (g6_rate ) ? cfg_gen6_eq_dcm_max_precursor_delta :
 (g5_rate ) ? cfg_gen5_eq_dcm_max_precursor_delta : (~g4_rate ) ? cfg_gen3_eq_dcm_max_precursor_delta : cfg_gen4_eq_dcm_max_precursor_delta;
wire  [N_EVALS_WD-2:0] cfg_eq_dcm_max_postcursor_delta = (g6_rate ) ? cfg_gen6_eq_dcm_max_postcursor_delta :
 (g5_rate ) ? cfg_gen5_eq_dcm_max_postcursor_delta : (~g4_rate ) ? cfg_gen3_eq_dcm_max_postcursor_delta : cfg_gen4_eq_dcm_max_postcursor_delta;
wire [N_EVALS_WD-2:0] cfg_eq_dcm_max_precursor2_delta = cfg_gen6_eq_dcm_max_precursor2_delta;

min_max_coef
 #(.CW(TX_FS_WD), .QD(COEFQ_DEPTH), .N_EVALS_WD(N_EVALS_WD)) u_min_max_coef_prec2 (
    //inputs
    .core_clk           (core_clk),
    .core_rst_n         (core_rst_n),
    .coef_in            (c_eval_pre_cursor2),
    .coef_in_push       (c_eval_push),
    .max_delta          (cfg_eq_dcm_max_precursor2_delta[N_EVALS_WD-2:0]),
    .n_evals            (cfg_eq_dcm_n_evals[N_EVALS_WD-1:0]),
    .ftune_rtx          (mac_phy_ftune_rtx),
    //outputs
    .optimal            (optimal_pre_cursor2),
    .optimal_upd_pulse  (optimal_pre_cursor2_upd_pulse)
);

min_max_coef
 #(.CW(TX_FS_WD), .QD(COEFQ_DEPTH), .N_EVALS_WD(N_EVALS_WD)) u_min_max_coef_prec (
    //inputs
    .core_clk           (core_clk),
    .core_rst_n         (core_rst_n),
    .coef_in            (c_eval_pre_cursor),
    .coef_in_push       (c_eval_push),
    .max_delta          (cfg_eq_dcm_max_precursor_delta[N_EVALS_WD-2:0]),
    .n_evals            (cfg_eq_dcm_n_evals[N_EVALS_WD-1:0]),
    .ftune_rtx          (mac_phy_ftune_rtx),
    //outputs
    .optimal            (optimal_pre_cursor),
    .optimal_upd_pulse  (optimal_pre_cursor_upd_pulse)
);

min_max_coef
 #(.CW(TX_FS_WD), .QD(COEFQ_DEPTH), .N_EVALS_WD(N_EVALS_WD)) u_min_max_coef_postc (
    //inputs
    .core_clk           (core_clk),
    .core_rst_n         (core_rst_n),
    .coef_in            (c_eval_post_cursor),
    .coef_in_push       (c_eval_push),
    .max_delta          (cfg_eq_dcm_max_postcursor_delta[N_EVALS_WD-2:0]),
    .n_evals            (cfg_eq_dcm_n_evals[N_EVALS_WD-1:0]),
    .ftune_rtx          (mac_phy_ftune_rtx),
    //outputs
    .optimal            (optimal_post_cursor),
    .optimal_upd_pulse  (optimal_post_cursor_upd_pulse)
);


// Rules for remote transmitter coefficients at gen6 rate.
// If violate any of the three Rules, violate_rules_rtx_coef_g6 = 1
function automatic violate_rules_rtx_coef_g6 (input [TX_COEF_WD_P3:0] coef, input [TX_FS_WD-1:0] fs, input [TX_FS_WD-1:0] lf);

//pre_cursor, cursor and post_cursor range is from 0 to 63

    reg [3:0] pre_cursor2;
    reg [4:0] pre_cursor;
    reg [6:0] cursor;
    reg [5:0] post_cursor;
    reg [TX_FS_WD_P1+1:0] sum_4_cursors;
    reg [TX_FS_WD_P1:0]   sum_pre_post_cursors;
    reg [TX_FS_WD_P1:0]   sum_cusr_pre2_cursors;
    reg       violate_rule_1; // |C-1| <= Floor (FS/4)
    reg       violate_rule_2; // |C-2| + |C-1| + C0 + |C+1| = FS
    reg       violate_rule_3; // C0 + |C-2| - |C-1| - |C+1| >= LF
    reg       violate_rule_4; // |C-2| <= Floor (FS/8)
    reg [TX_FS_WD_P1-1:0] tmp_cursor;
    reg [TX_FS_WD_P1-1:0] fs_div_3;

    begin
        violate_rules_rtx_coef_g6 = 1;

        pre_cursor2           = coef[3:0];
        pre_cursor            = coef[8:4];
        cursor                = coef[15:9];
        post_cursor           = coef[21:16];
        fs_div_3              = {2'b0, fs_d3(fs)};
        sum_4_cursors         = ({5'b0,pre_cursor2} + {4'b0,pre_cursor} + {2'b00,cursor} + {3'b00,post_cursor});
        sum_pre_post_cursors  = ({3'b0,pre_cursor} + {2'b0,post_cursor});
        sum_cusr_pre2_cursors = ({1'b0,cursor} + {4'b0,pre_cursor2});

        violate_rule_1 = ( {2'b0, pre_cursor} > ({1'b0,fs} >> 2) );
        violate_rule_2 = ( sum_4_cursors != {3'b0,fs} );
        //if cursor < (pre_pre_cursor + post_cursor), violate_rule_3 is true
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, 
        tmp_cursor = (pre_cursor2 + cursor - pre_cursor - post_cursor); // to avoid spyglass warning
// spyglass enable_block W164a
        violate_rule_3 = ( (sum_cusr_pre2_cursors < sum_pre_post_cursors) ? 1 : (tmp_cursor < {1'b0,lf}) );
        violate_rule_4 = ( {3'b0, pre_cursor2} > ({1'b0,fs} >> 3) );

        violate_rules_rtx_coef_g6 = ( pre_cursor2[3] | pre_cursor[4] | cursor[6] | post_cursor[5] | violate_rule_1 | violate_rule_2 | violate_rule_3 | violate_rule_4 );
    end
endfunction //violate_rules_rtx_coef_g6


// Rules for remote transmitter coefficients.
// If violate any of the three Rules, violate_rules_rtx_coef = 1
function automatic violate_rules_rtx_coef (input [TX_COEF_WD_P3-1:0] coef, input [TX_FS_WD-1:0] fs, input [TX_FS_WD-1:0] lf);

//pre_cursor, cursor and post_cursor range is from 0 to 63

    reg [TX_FS_WD_P1-1:0] pre_cursor;
    reg [TX_FS_WD_P1-1:0] cursor;
    reg [TX_FS_WD_P1-1:0] post_cursor;
    reg [TX_FS_WD_P1+1:0] sum_3_cursors;
    reg [TX_FS_WD_P1:0]   sum_pre_post_cursors;
    reg       violate_rule_1; // |C-1| <= Floor (FS/4)
    reg       violate_rule_2; // |C-1|+C0+|C+1| = FS
    reg       violate_rule_3; // C0 -|C-1|-|C+1| >= LF
    reg [TX_FS_WD_P1-1:0] tmp_cursor;

    begin
        violate_rules_rtx_coef = 1;

        pre_cursor           = coef[TX_FS_WD_P1-1:0];
        cursor               = coef[2*TX_FS_WD_P1-1:TX_FS_WD_P1];
        post_cursor          = coef[3*TX_FS_WD_P1-1:2*TX_FS_WD_P1];
        sum_3_cursors        = ({2'b00,pre_cursor} + {2'b00,cursor} + {2'b00,post_cursor});
        sum_pre_post_cursors = ({1'b0,pre_cursor} + {1'b0,post_cursor});

        violate_rule_1 = ( pre_cursor > ({1'b0,fs} >> 2) );
        violate_rule_2 = ( sum_3_cursors != {3'b0,fs} );
        //if cursor < (pre_pre_cursor + post_cursor), violate_rule_3 is true
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        tmp_cursor = (cursor - pre_cursor - post_cursor); // to avoid spyglass warning
// spyglass enable_block W164a
        violate_rule_3 = ( ({1'b0,cursor} < sum_pre_post_cursors) ? 1 : (tmp_cursor < {1'b0,lf}) );

        violate_rules_rtx_coef = ( pre_cursor[TX_FS_WD] || cursor[TX_FS_WD] || post_cursor[TX_FS_WD] || violate_rule_1 || violate_rule_2 || violate_rule_3 );
    end
endfunction //violate_rules_rtx_coef

// -------------------------------------------------------------------------
// Logic below is search algorithms for remote partner Transmitter EQ
// -------------------------------------------------------------------------
// START

// cfg_eq_feedback_mode: 0 - Direction Change
// coefficient width is augmented by 1 bit to get 6'b0 - 1 = 7'b1111111 or 6'h3f + 1 = 7'b1000000
function automatic [TX_FS_WD_P1-1:0] direction_change_coef (input [TX_FS_WD-1:0] coef, input [1:0] dirfeedback);
    begin
        if ( dirfeedback[1:0] == 2'b01 )      direction_change_coef = {1'b0, coef} + 1;
        else if ( dirfeedback[1:0] == 2'b10 ) direction_change_coef = {1'b0, coef} - 1;
        else                                  direction_change_coef = {1'b0, coef};
    end
endfunction //direction_change_coef

// |C-2| after dir change feedback
assign c_eval_dirfeedback_pre_cursor2 = g6_rate ? direction_change_coef(c_eval_pre_cursor2, int_phy_mac_dirfeedback_pre_cursor2) : {TX_FS_WD_P1{1'b0}};

// |C-1| after dir change feedback
assign c_eval_dirfeedback_pre_cursor  = direction_change_coef(c_eval_pre_cursor,  int_phy_mac_dirfeedback_pre_cursor);

// |C+1| after dir change feedback
assign c_eval_dirfeedback_post_cursor = direction_change_coef(c_eval_post_cursor, int_phy_mac_dirfeedback_post_cursor);

//C0 = FS - |C-1| - |C+1|
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
assign c_eval_dirfeedback_cursor = {1'b0, mac_phy_fs} - c_eval_dirfeedback_pre_cursor - c_eval_dirfeedback_post_cursor - c_eval_dirfeedback_pre_cursor2;
// spyglass enable_block W164a

// concatenation
// for gen6 rate, the 18+3 = 21 bits assigned to pre_2 = 4 bits, pre = 5 bits, cursor = 6 bits, post = 6 bits
assign c_eval_dirfeedback = g6_rate ? {c_eval_dirfeedback_post_cursor[0 +: 6], c_eval_dirfeedback_cursor[0 +: 7], c_eval_dirfeedback_pre_cursor[0 +: 5], c_eval_dirfeedback_pre_cursor2[0 +: 4]} :
                                                           { 1'b0, c_eval_dirfeedback_post_cursor, c_eval_dirfeedback_cursor, c_eval_dirfeedback_pre_cursor};

  wire [3:0] cdm_ras_des_eq_force_coef_rtx_g6_2nd_pre_cursor  = {1'b0, cdm_ras_des_eq_force_coef_rtx_g6[2:0]};
  wire [4:0] cdm_ras_des_eq_force_coef_rtx_g6_pre_cursor      = {1'b0, cdm_ras_des_eq_force_coef_rtx_g6[6:3]};
  wire [6:0] cdm_ras_des_eq_force_coef_rtx_g6_cursor          = {1'b0, cdm_ras_des_eq_force_coef_rtx_g6[12:7]};
  wire [5:0] cdm_ras_des_eq_force_coef_rtx_g6_post_cursor     = {1'b0, cdm_ras_des_eq_force_coef_rtx_g6[17:13]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_g5_pre_cursor  = {1'b0, cdm_ras_des_eq_force_coef_rtx_g5[TX_FS_WD-1:0]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_g5_cursor      = {1'b0, cdm_ras_des_eq_force_coef_rtx_g5[TX_FS_WD*2-1:TX_FS_WD]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_g5_post_cursor = {1'b0, cdm_ras_des_eq_force_coef_rtx_g5[TX_FS_WD*3-1:TX_FS_WD*2]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_g4_pre_cursor  = {1'b0, cdm_ras_des_eq_force_coef_rtx_g4[TX_FS_WD-1:0]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_g4_cursor      = {1'b0, cdm_ras_des_eq_force_coef_rtx_g4[TX_FS_WD*2-1:TX_FS_WD]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_g4_post_cursor = {1'b0, cdm_ras_des_eq_force_coef_rtx_g4[TX_FS_WD*3-1:TX_FS_WD*2]};  
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_pre_cursor  = {1'b0, cdm_ras_des_eq_force_coef_rtx[TX_FS_WD-1:0]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_cursor      = {1'b0, cdm_ras_des_eq_force_coef_rtx[TX_FS_WD*2-1:TX_FS_WD]};
  wire [TX_FS_WD_P1-1:0] cdm_ras_des_eq_force_coef_rtx_post_cursor = {1'b0, cdm_ras_des_eq_force_coef_rtx[TX_FS_WD*3-1:TX_FS_WD*2]};  
                    
// cfg_eq_feedback_mode: 0 - Direction Change, 1 - Figure Merit, 2~15: Reserved
// c_eval_new is used for violation check.
assign c_eval_new =                        ( int_cdm_ras_des_eq_force_coef_rtx_en_g6 ) ? {cdm_ras_des_eq_force_coef_rtx_g6_post_cursor, cdm_ras_des_eq_force_coef_rtx_g6_cursor, cdm_ras_des_eq_force_coef_rtx_g6_pre_cursor, cdm_ras_des_eq_force_coef_rtx_g6_2nd_pre_cursor}:
                        ( int_cdm_ras_des_eq_force_coef_rtx_en_g5 ) ? { 1'b0, cdm_ras_des_eq_force_coef_rtx_g5_post_cursor, cdm_ras_des_eq_force_coef_rtx_g5_cursor, cdm_ras_des_eq_force_coef_rtx_g5_pre_cursor}:
                        ( int_cdm_ras_des_eq_force_coef_rtx_en_g4 ) ? { 1'b0, cdm_ras_des_eq_force_coef_rtx_g4_post_cursor, cdm_ras_des_eq_force_coef_rtx_g4_cursor, cdm_ras_des_eq_force_coef_rtx_g4_pre_cursor}:
                        ( int_cdm_ras_des_eq_force_coef_rtx_en)     ? { 1'b0, cdm_ras_des_eq_force_coef_rtx_post_cursor,    cdm_ras_des_eq_force_coef_rtx_cursor,    cdm_ras_des_eq_force_coef_rtx_pre_cursor}:
                        c_eval_dirfeedback;

// remove bit [6] of C+1, C0, C-1 from c_eval_new. If no violations, c_eval <= int_c_eval_new. If violations, restore previous valid one.
assign int_c_eval_new = g6_rate ? { c_eval_new[20:16], c_eval_new[14:9], c_eval_new[7:4], c_eval_new[2:0] } : // gen6 -> C-2 = pre_2 = c_eval_new[2:0]
                                                       { c_eval_new[3*TX_FS_WD+1:2*TX_FS_WD+2], c_eval_new[2*TX_FS_WD:1*TX_FS_WD+1], c_eval_new[1*TX_FS_WD-1:0*TX_FS_WD] };


always @(posedge core_clk or negedge core_rst_n) begin : c_eval_new_r_PROC
    if (!core_rst_n) begin
        c_eval_new_r <= #TP '0;
    end else  begin
        c_eval_new_r <= #TP c_eval_new;
    end 
end



// END
// -------------------------------------------------------------------------
// Logic above is search algorithms for remote partner Transmitter EQ
// -------------------------------------------------------------------------

`ifndef SYNTHESIS
`ifndef SYNTHESIS
wire [16*8-1:0] EQ_MASTER_STATE;
assign  EQ_MASTER_STATE = ( eq_master_state == S_RST            ) ? "RST"            :
                          ( eq_master_state == S_INIT           ) ? "INIT"           :
                          ( eq_master_state == S_WAIT_REI       ) ? "WAIT_REI"       :
                          ( eq_master_state == S_EVAL           ) ? "EVAL"           :
                          ( eq_master_state == S_SKIP_EVAL      ) ? "SKIP_EVAL"      :
                          ( eq_master_state == S_UNSUCCESS_EXIT ) ? "UNSUCCESS_EXIT" :
                          ( eq_master_state == S_SUCCESS_EXIT   ) ? "SUCCESS_EXIT"   :
                          ( eq_master_state == S_FEEDBACK       ) ? "FEEDBACK"       :
                          ( eq_master_state == S_NEW_COEFF      ) ? "NEW_COEFF"      :
                          ( eq_master_state == S_REQUEST        ) ? "REQUEST"        :
                          ( eq_master_state == S_ABORT          ) ? "ABORT"          :
                          ( eq_master_state == S_INVALID_REQ    ) ? "INVALID_REQ"    :
                          ( eq_master_state == S_TIMEOUT_REQ    ) ? "TIMEOUT_REQ"    :
                          ( eq_master_state == S_WAIT_RESPONSE  ) ? "WAIT_RESPONSE"  :  "BOGUS" ;
`endif // SYNTHESIS
`endif  // SYNTHESIS


// Remote Device FS
// Remote Device LF
always @(posedge core_clk or negedge core_rst_n)
    if( !core_rst_n ) begin
        mac_cdm_ras_des_fs    <= #TP '0;
        mac_cdm_ras_des_lf    <= #TP '0;
        mac_cdm_ras_des_fs_g4 <= #TP '0;
        mac_cdm_ras_des_lf_g4 <= #TP '0;
        mac_cdm_ras_des_fs_g5 <= #TP '0;
        mac_cdm_ras_des_lf_g5 <= #TP '0;
        mac_cdm_ras_des_fs_g6 <= #TP '0;
        mac_cdm_ras_des_lf_g6 <= #TP '0;
    end else begin
        if ( fslf_rtx_valid_rising_edge ) begin
            if(g6_rate ) begin
                mac_cdm_ras_des_fs_g6 <= #TP mac_phy_fslf_rtx[TX_FS_WD-1:0];
                mac_cdm_ras_des_lf_g6 <= #TP mac_phy_fslf_rtx[2*TX_FS_WD-1:TX_FS_WD];
            end else
            if(g5_rate ) begin
                mac_cdm_ras_des_fs_g5 <= #TP mac_phy_fslf_rtx[TX_FS_WD-1:0];
                mac_cdm_ras_des_lf_g5 <= #TP mac_phy_fslf_rtx[2*TX_FS_WD-1:TX_FS_WD];
            end else
            if(g4_rate ) begin
                mac_cdm_ras_des_fs_g4 <= #TP mac_phy_fslf_rtx[TX_FS_WD-1:0];
                mac_cdm_ras_des_lf_g4 <= #TP mac_phy_fslf_rtx[2*TX_FS_WD-1:TX_FS_WD];
            end else begin
                mac_cdm_ras_des_fs <= #TP mac_phy_fslf_rtx[TX_FS_WD-1:0];
                mac_cdm_ras_des_lf <= #TP mac_phy_fslf_rtx[2*TX_FS_WD-1:TX_FS_WD];
            end
        end
    end

// Current Local Transmitter Coefficient
assign mac_cdm_ras_des_coef_ltx = mac_phy_txdeemph_gen3;
assign mac_cdm_ras_des_coef_ltx_g4 = mac_phy_txdeemph_gen4;
assign mac_cdm_ras_des_coef_ltx_g5 = mac_phy_txdeemph_gen5;
assign mac_cdm_ras_des_coef_ltx_g6 = mac_phy_txdeemph_gen6;

// Current Figure of Merit Feedback
always @(posedge core_clk or negedge core_rst_n)
    if ( !core_rst_n ) begin
        phy_cdm_ras_des_fomfeedback    <= #TP '0;
        phy_cdm_ras_des_fomfeedback_g4 <= #TP '0;
        phy_cdm_ras_des_fomfeedback_g5 <= #TP '0;
        phy_cdm_ras_des_fomfeedback_g6 <= #TP '0;
    end else if (phy_mac_phystatus && mac_phy_rxeqeval) begin
        if ( g6_rate )
            phy_cdm_ras_des_fomfeedback_g6 <= #TP phy_mac_fomfeedback;
        else
        if ( g5_rate )
            phy_cdm_ras_des_fomfeedback_g5 <= #TP phy_mac_fomfeedback;
        else
        if ( g4_rate )
            phy_cdm_ras_des_fomfeedback_g4 <= #TP phy_mac_fomfeedback;
        else
        if ( g3_rate )
            phy_cdm_ras_des_fomfeedback    <= #TP phy_mac_fomfeedback;
    end

wire [2:0]                int_eqpa_violate_rule_123;

assign int_eqpa_violate_rule_123 = violate_rules_123_rtx_coef(c_eval_new_r[TX_COEF_WD_P3-1:0], mac_phy_fs, mac_phy_lf);

always @(posedge core_clk or negedge core_rst_n)
    if( !core_rst_n ) begin
        eqpa_violate_rule_123    <= #TP '0;
        eqpa_violate_rule_123_g4 <= #TP '0;
        eqpa_violate_rule_123_g5 <= #TP '0;
    end
    else if ( eq_master_state == S_INIT ) begin
    // Clear when the EQ master state starts.
        if ( g5_rate )
            eqpa_violate_rule_123_g5 <= #TP '0;
        else
        if ( g4_rate )
            eqpa_violate_rule_123_g4 <= #TP '0;
        else
        eqpa_violate_rule_123 <= #TP '0;
    end else if ( eq_master_state == S_NEW_COEFF ) begin
        if ( g5_rate )
            eqpa_violate_rule_123_g5 <= #TP int_eqpa_violate_rule_123;
        else
        if ( g4_rate )
            eqpa_violate_rule_123_g4 <= #TP int_eqpa_violate_rule_123;
        else
        eqpa_violate_rule_123 <= #TP int_eqpa_violate_rule_123;
    end

wire [3:0]                int_eqpa_violate_rule_1234;
 
assign int_eqpa_violate_rule_1234 = violate_rules_1234_rtx_coef_g6(c_eval_new_r, mac_phy_fs, mac_phy_lf);
 
always @(posedge core_clk or negedge core_rst_n)
    if( !core_rst_n ) begin
      eqpa_violate_rule_123_g6 <= #TP '0;
      eqpa_violate_rule_4_g6   <= #TP '0;
    end
    else if ( eq_master_state == S_INIT ) begin
    // Clear when the EQ master state starts.
        if ( g6_rate ) begin
            eqpa_violate_rule_123_g6 <= #TP '0;
            eqpa_violate_rule_4_g6   <= #TP '0;
        end
    end else if ( eq_master_state == S_NEW_COEFF ) begin
        if ( g6_rate ) begin
            eqpa_violate_rule_123_g6 <= #TP int_eqpa_violate_rule_1234[2:0];
            eqpa_violate_rule_4_g6   <= #TP int_eqpa_violate_rule_1234[3];
        end
    end

// Equalization Convergence Status
// 00: eq sequnce is not started
// 01: success exit
// 10: unsuccess exit
// 11: reserved
always @(posedge core_clk or negedge core_rst_n)
    if( !core_rst_n ) begin
        eq_convergence_sts    <= #TP '0;
        eq_convergence_sts_g4 <= #TP '0;
        eq_convergence_sts_g5 <= #TP '0;
        eq_convergence_sts_g6 <= #TP '0;
    end else begin
        case ( eq_master_state )
            S_INIT: begin
            // cleared when starting eq master state
                if ( g6_rate )
                    eq_convergence_sts_g6 <= #TP 2'b00;
                else
                if ( g5_rate )
                    eq_convergence_sts_g5 <= #TP 2'b00;
                else
                if ( g4_rate )
                    eq_convergence_sts_g4 <= #TP 2'b00;
                else
                    eq_convergence_sts    <= #TP 2'b00;
            end
            S_SUCCESS_EXIT  : begin
                if ( g6_rate )
                    eq_convergence_sts_g6 <= #TP 2'b01;
                else
                if ( g5_rate )
                    eq_convergence_sts_g5 <= #TP 2'b01;
                else
                if ( g4_rate )
                    eq_convergence_sts_g4 <= #TP 2'b01;
                else
                    eq_convergence_sts    <= #TP 2'b01;
            end
            S_UNSUCCESS_EXIT: begin
                if ( g6_rate )
                    eq_convergence_sts_g6 <= #TP 2'b10;
                else
                if ( g5_rate )
                    eq_convergence_sts_g5 <= #TP 2'b10;
                else
                if ( g4_rate )
                    eq_convergence_sts_g4 <= #TP 2'b10;
                else
                    eq_convergence_sts    <= #TP 2'b10;
            end
            default         : begin
                    eq_convergence_sts_g6 <= #TP eq_convergence_sts_g6;
                    eq_convergence_sts_g5 <= #TP eq_convergence_sts_g5;
                    eq_convergence_sts_g4 <= #TP eq_convergence_sts_g4;
                    eq_convergence_sts    <= #TP eq_convergence_sts;
            end
        endcase
    end

// Receive Reject Coefficient Event status
always @(posedge core_clk or negedge core_rst_n)
    if( !core_rst_n ) begin
        mac_cdm_ras_des_reject_rtx    <= #TP '0;
        mac_cdm_ras_des_reject_rtx_g4 <= #TP '0;
        mac_cdm_ras_des_reject_rtx_g5 <= #TP '0;
        mac_cdm_ras_des_reject_rtx_g6 <= #TP '0;
    end else begin
        case(eq_master_state)
            S_INIT: begin
                if( g6_rate )
                    mac_cdm_ras_des_reject_rtx_g6 <= #TP 1'b0;
                else
                if( g5_rate )
                    mac_cdm_ras_des_reject_rtx_g5 <= #TP 1'b0;
                else
                if( g4_rate )
                    mac_cdm_ras_des_reject_rtx_g4 <= #TP 1'b0;
                else
                    mac_cdm_ras_des_reject_rtx    <= #TP 1'b0;
            end
            S_WAIT_RESPONSE: begin
                if( mac_phy_reject_rtx ) begin
                    if( g6_rate )
                        mac_cdm_ras_des_reject_rtx_g6 <= #TP 1'b1;
                    else
                    if( g5_rate )
                        mac_cdm_ras_des_reject_rtx_g5 <= #TP 1'b1;
                    else
                    if( g4_rate )
                        mac_cdm_ras_des_reject_rtx_g4 <= #TP 1'b1;
                    else
                        mac_cdm_ras_des_reject_rtx    <= #TP 1'b1;
                end
            end
            default: begin
                mac_cdm_ras_des_reject_rtx    <= #TP mac_cdm_ras_des_reject_rtx;
                mac_cdm_ras_des_reject_rtx_g4 <= #TP mac_cdm_ras_des_reject_rtx_g4;
                mac_cdm_ras_des_reject_rtx_g5 <= #TP mac_cdm_ras_des_reject_rtx_g5;
                mac_cdm_ras_des_reject_rtx_g6 <= #TP mac_cdm_ras_des_reject_rtx_g6;
            end
        endcase
    end

// Remote Transmitter coefficient
always @(posedge core_clk or negedge core_rst_n)
    if( !core_rst_n ) begin
        mac_cdm_ras_des_coef_rtx    <= #TP '0;
        mac_cdm_ras_des_coef_rtx_g4 <= #TP '0;
        mac_cdm_ras_des_coef_rtx_g5 <= #TP '0;
        mac_cdm_ras_des_coef_rtx_g6 <= #TP '0;
    end else begin
        if ( eq_master_state==S_FEEDBACK ) begin
            if( g6_rate )
                mac_cdm_ras_des_coef_rtx_g6 <= #TP in_fcoef_req ? mac_phy_coef_rtx : c_eval;
            else
            if( g5_rate )
                mac_cdm_ras_des_coef_rtx_g5 <= #TP in_fcoef_req ? mac_phy_coef_rtx : c_eval;
            else
            if( g4_rate )
                mac_cdm_ras_des_coef_rtx_g4 <= #TP in_fcoef_req ? mac_phy_coef_rtx : c_eval;
            else
                mac_cdm_ras_des_coef_rtx    <= #TP in_fcoef_req ? mac_phy_coef_rtx : c_eval;
        end
    end


// Rules for remote transmitter coefficients.
// If violate any of the three Rules, violate_rules_123_rtx_coef = 1
function automatic [2:0] violate_rules_123_rtx_coef (input [TX_COEF_WD_P3-1:0] coef, input [TX_FS_WD-1:0] fs, input [TX_FS_WD-1:0] lf);

    reg [TX_FS_WD_P1-1:0] pre_cursor;
    reg [TX_FS_WD_P1-1:0] cursor;
    reg [TX_FS_WD_P1-1:0] post_cursor;
    reg [TX_FS_WD_P1+1:0] sum_3_cursors;
    reg [TX_FS_WD_P1:0]   sum_pre_post_cursors;
    reg [TX_FS_WD_P1-1:0] sub_cursor_pre_post;
    reg       violate_rule_1; // |C-1| <= Floor (FS/4)
    reg       violate_rule_2; // |C-1|+C0+|C+1| = FS
    reg       violate_rule_3; // C0 -|C-1|-|C+1| >= LF

    begin
        violate_rules_123_rtx_coef = 3'b111;

        pre_cursor           = coef[TX_FS_WD_P1-1:0];
        cursor               = coef[2*TX_FS_WD_P1-1:TX_FS_WD_P1];
        post_cursor          = coef[3*TX_FS_WD_P1-1:2*TX_FS_WD_P1];
        sum_3_cursors        = ({2'b00,pre_cursor} + {2'b00,cursor} + {2'b00,post_cursor});
        sum_pre_post_cursors = ({1'b0,pre_cursor} + {1'b0,post_cursor});
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        sub_cursor_pre_post  = (cursor - pre_cursor - post_cursor);
// spyglass enable_block W164a

        violate_rule_1 = ( pre_cursor > ({1'b0,fs} >> 2) );
        violate_rule_2 = ( sum_3_cursors != {3'h0,fs} );
        //if cursor < (pre_pre_cursor + post_cursor), violate_rule_3 is true
        violate_rule_3 = ( ({1'b0,cursor} < sum_pre_post_cursors) ? 1 : (sub_cursor_pre_post < {1'b0,lf}) );

        violate_rules_123_rtx_coef = { violate_rule_3, violate_rule_2, violate_rule_1 };
    end
endfunction //violate_rules_123_rtx_coef

// Rules for remote transmitter coefficients.
// If violate any of the three Rules, violate_rules_1234_rtx_coef_g6 = 1
function automatic [3:0] violate_rules_1234_rtx_coef_g6 (input [TX_COEF_WD_P3:0] coef, input [TX_FS_WD-1:0] fs, input [TX_FS_WD-1:0] lf);

    reg [3:0] pre_cursor2;
    reg [4:0] pre_cursor;
    reg [6:0] cursor;
    reg [5:0] post_cursor;
    reg [TX_FS_WD_P1+1:0] sum_4_cursors;
    reg [TX_FS_WD_P1:0]   sum_pre_post_cursors;
    reg [TX_FS_WD_P1:0]   sum_cusr_pre2_cursors;
    reg       violate_rule_1; // |C-1| <= Floor (FS/4)
    reg       violate_rule_2; // |C-1|+C0+|C+1| = FS
    reg       violate_rule_3; // C0 -|C-1|-|C+1| >= LF
    reg       violate_rule_4; // |C-2| <= Floor (FS/8)
    reg [TX_FS_WD_P1-1:0] tmp_cursor;
    reg [TX_FS_WD_P1-1:0] fs_div_3;

    begin
        violate_rules_1234_rtx_coef_g6 = 4'b1111;

        pre_cursor2          = coef[3:0];
        pre_cursor           = coef[8:4];
        cursor               = coef[15:9];
        post_cursor          = coef[21:16];
        fs_div_3              = {2'b0, fs_d3(fs)};
        sum_4_cursors         = ({5'b0,pre_cursor2} + {4'b0,pre_cursor} + {2'b00,cursor} + {3'b00,post_cursor});
        sum_pre_post_cursors  = ({3'b0,pre_cursor} + {2'b0,post_cursor});
        sum_cusr_pre2_cursors = ({1'b0,cursor} + {4'b0,pre_cursor2});
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        tmp_cursor = (pre_cursor2 + cursor - pre_cursor - post_cursor); // to avoid spyglass warning
// spyglass enable_block W164a


        violate_rule_1 = ( {2'b0, pre_cursor} > ({1'b0,fs} >> 2) );
        violate_rule_2 = ( sum_4_cursors != {3'b0,fs} );
        //if cursor < (pre_pre_cursor + post_cursor), violate_rule_3 is true
        violate_rule_3 = ( (sum_cusr_pre2_cursors < sum_pre_post_cursors) ? 1 : (tmp_cursor < {1'b0,lf}) );
        violate_rule_4 = ( {3'b0, pre_cursor2} > ({1'b0,fs} >> 3) );

        violate_rules_1234_rtx_coef_g6 = {violate_rule_4, violate_rule_3, violate_rule_2, violate_rule_1 };
    end
endfunction //violate_rules_1234_rtx_coef_g6

endmodule // smlh_eqpa_slv
