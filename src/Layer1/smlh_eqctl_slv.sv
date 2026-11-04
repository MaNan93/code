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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_eqctl_slv.sv#20 $
// -------------------------------------------------------------------------
// --- Module Description: Equalization Controller for Gen3 - single lane version
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module smlh_eqctl_slv
#(
    parameter INST       = 0, // The uniquifying parameter for each port logic instance
    parameter TP         = `TP,
    //parameter REGIN    = `CX_XMLH_EQCTL_REGIN, // register all phy inputs
    parameter REGIN      = 1, // register all phy inputs
    // constants 
    parameter EQTS_WD    = 32, // total number of bits in ts carrying eq info, symbol 6-9 = 32 bits
    parameter TSFD_WD    = `CX_TS_FIELD_CONTROL_WD, // Sym7,6,5,4,3,2,1
    parameter RX_PSET_WD = 3,
    parameter TX_PSET_WD = 4,
    parameter TX_FSLF_WD = 12,
    parameter TX_COEF_WD = 18,
    parameter TS_0_WD    = 48,
    parameter PCNT_WD    = 4 // number of bits in the persistency count
)
(
    input                           core_clk,
    input                           core_rst_n,
    input                           upstream_component,
    input                           cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map,
    input                           fom_gen34_eq_phase23_rxeq_regardless_rxts,
    input                           req_rst_eiec_enable,
    // smlh_seq_finder i/f
    input          [EQTS_WD-1:0]    smlh_eqts_info, // concatenation of {s9, s8, s7, s6} from rx TS
    input                           tx_ts0_dsp_eq2_usp_eq3, // TX TS0 in dsp eq2 or usp eq3 so that the transmitter used coef sent from eq slave for master initial fine tuning eq settings
    input                           smlh_ts0_rcvd, // level, asserted following rx TS1, maintained on SKP and EIE
    input                           ltssm_dsp_g6_eq1_send_ec00, // dsp sends ec=00b in gen6 eq1 when it wants to move to R.Lock from eq1
    input                           ltssm_state_last_equalization_any, // last ltssm state is any eq state
    input                           ltssm_perform_eq_for_lpbk, // Equalization for Loopback is performed
    input                           smlh_ts1_rcvd, // level, asserted following rx TS1, maintained on SKP and EIE
    input                           smlh_ts2_rcvd, // level, asserted following rx TS2, maintained on SKP and EIE
    input          [PCNT_WD-1:0]    smlh_ts_rcvd_s6s9_pcnt, // persistency count on equalization fields in rx TS
    input          [TSFD_WD-1:0]    smlh_ts_info,
    input                           ltssm_active_lane,
    // smlh_ltssm i/f
    input                           ltssm_lpbk_master,
    input                           ltssm_current_data_rate_g12,
    input                           ltssm_current_data_rate_g12_pulse,
    input                           ltssm_current_data_rate_g3,
    input                           ltssm_current_data_rate_g3_pulse,
    input                           ltssm_captured_ts_data_rate_g3,
    input                           ltssm_captured_ts_data_rate_g5,
    input                           ltssm_current_data_rate_g4,
    input                           ltssm_current_data_rate_g4_pulse,
    input                           smlh_link_up_falling_edge,
    input                           ltssm_current_data_rate_g5,
    input                           ltssm_current_data_rate_g5_pulse,
    input                           ltssm_current_data_rate_g6,
    input                           ltssm_current_data_rate_g6_pulse,
    input                           ltssm_captured_ts_data_rate_g6,
    input                           mac_phy_txswing, // transmitter swing
    input          [3:0]            ltssm_state_equalization,
    input          [3:0]            ltssm_state_equalization_enter,
    input          [3:0]            ltssm_state_equalization_exit,
    input                           ltssm_state_equalization_any,
    input                           ltssm_state_equalization_any_exit,
    input                           ltssm_state_rcvrlock,
    input                           ltssm_state_rcvrcfg,
    input                           ltssm_state_rcvrspd,
    input                           ltssm_state_rcvridle,
    input                           ltssm_cmd_ts1,
    input                           ltssm_cmd_ts2,
    input                           ltssm_cmd_eqts, // ltssm command specifier, for eqTS1 and eqTS2 ordered sets @g12 rate
    input                           ltssm_cmd_send_eieos_for_pset_map, // send eieos continuously in Rcvry.RcvrLock for pset mapping
    input                           ltssm_cmd_8geqts, // sending 8GT EQ TS2 in Gen3 Speed
    input                           ltssm_cmd_eqredo, // sending TS1 with Equalization Redo(TS1 Symbol6[7]=1) in Gen3 Speed
    input                           ltssm_cmd_16geqts, // sending 16GT EQ TS2 in Gen4 Speed
    input                           ltssm_noeq_nd,     // no eq needed
    input          [1:0]            ltssm_cmd_eqts_gen12, // ltssm command specifier, for eqTS2 ordered sets @g12 rate to gen5 because of skip eq, [0] gen5 TS1, [1] gen5 TS2
    input                           ltssm_precode_request, // precode request thru TS to remote
    input                           ltssm_precoding_on,    // precode request thru TS to remote
    input                           ltssm_cmd_32geqts, // sending 32GT EQ TS2 in Gen4 Speed
    input          [3:0]            ltssm_start_equalization, // bit 0: start_equalization_w_preset variable in spec, bit 1-3 to direct equalization to a non-0 phase from RcvrLock
    input          [3:0]            ltssm_gen3_compliance_tx_pset, //Compliance Tx preset due to EnterCompliance bit set or cycle
    input                           ltssm_gen3_compliance_tx_pset_v, //Tx preset from ltssm is valid
    input                           ltssm_state_compliance,
    input                           ltssm_state_pollactive,
    input                           ltssm_state_lpbkentry,
    input                           ltssm_state_lpbkact,
    input                           ltssm_state_cfglwstart, //Cfg.Linkwidth.Start state
    input                           ltssm_clear,
    input          [4:0]            ltssm_ts_data_rate,
    input                           ltssm_state_detect,
    input                           ltssm_state_disable,
    input                           ltssm_state_hotreset,
    input                           ltssm_state_l0,
    input                           ltssm_state_l0s,
    input                           ltssm_state_l123,
    input                           ltssm_state_l1,
    input                           ltssm_state_l2,
    // cdm i/f
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    input          [3:0]            cfg_target_link_speed, // "Target Link Speed" field from the "Link Control Register 2" bits 3:0
    input          [9:0]            ltssm_ts_data_rate_eg6,
    input          [9:0]            latched_ts_data_rate_eg6,
    input          [TX_PSET_WD-1:0] cfg_lec_pset_ltx, // UC only - Local Transmitter Preset
    input          [RX_PSET_WD-1:0] cfg_lec_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [TX_PSET_WD-1:0] cfg_lec_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [RX_PSET_WD-1:0] cfg_lec_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input          [TX_PSET_WD-1:0] cfg_lec_g4_pset_ltx, // UC only - Local Transmitter Preset
    input          [RX_PSET_WD-1:0] cfg_lec_g4_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [TX_PSET_WD-1:0] cfg_lec_g4_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [RX_PSET_WD-1:0] cfg_lec_g4_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input          [TX_PSET_WD-1:0] cfg_lec_g5_pset_ltx, // UC only - Local Transmitter Preset
    input          [RX_PSET_WD-1:0] cfg_lec_g5_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [TX_PSET_WD-1:0] cfg_lec_g5_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [RX_PSET_WD-1:0] cfg_lec_g5_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input          [TX_PSET_WD-1:0] cfg_lec_g6_pset_ltx, // UC only - Local Transmitter Preset
    input          [RX_PSET_WD-1:0] cfg_lec_g6_pset_lrx, // UC only - Local Receiver Preset Hint
    input          [TX_PSET_WD-1:0] cfg_lec_g6_pset_rtx, // UC only - Remote Transmitter Preset, to be requested over the wire
    input          [RX_PSET_WD-1:0] cfg_lec_g6_pset_rrx, // UC only - Remote Transmitter Preset Hint, to be requested over the wire
    input                           cfg_gen3_eq_disable, // disable EQ - when disabled eqts_info is set to match normal TS1/TS2 Gen1/2 format
    // pipe i/f - data
    input          [TX_FSLF_WD-1:0] phy_mac_fslf_ltx, // Local Transmitter Full Swing and Low Frequency, concatenation of {LF, FS}
    input          [TX_COEF_WD-1:0] phy_mac_coef_ltx, // Local Transmitter Coefficients - always reflects electrical settings in use
    input                           phy_mac_reject_ltx, // Local Transmitter Coefficients Reject Flag
    input                           phy_mac_accept_ltx, // Local Transmitter Preset/Coefficients Accept Flag
    input          [TX_PSET_WD-1:0] phy_mac_pset_rtx, // Remote Transmitter requested Preset
    input          [TX_COEF_WD-1:0] phy_mac_coef_rtx, // Remote Transmitter requested Coefficients, concatenation of {C+1, C0, C-1}
    // pipe i/f - status
    input                           phy_mac_ftune_rtx_done, // Remote Transmitter Fine Tuning Complete
    // pipe i/f - control
    input                           phy_mac_fslf_ltx_valid, // Local Transmitter Full Swing and Low Frequency Valid, 
                                                            // The rising edge of this signals is used to load Phy driven fs,lf,coef values into corresponding 
                                                            // mac_phy_fslf_ltx and mac_phy_coef_ltx registers in eqctl, also reflected as outputs. The content  
                                                            // of these registers is used in transmitted TS1s to advertise FS, LF, C(+1) values in use by the 
                                                            // Phy during Phase0/1, and C(-1),C(0),C(+1) values in use by the Phy on entrance into a fine tuning  
                                                            // Phase as a Slave. The Master is guaranteed by the protocol that it will be receiving these values  
                                                            // from the Slave (who always initiates the Phase transition) on entrance into a fine tuning Phase,  
                                                            // and it will reflect the values found on the received TS1s onto mac_phy_coef_rtx. These values will 
                                                            // be the ones that will be used to initialize the coefficients used by the fine tuning algorithm of 
                                                            // the Master to request the adjustment with incremental changes.
    input                           phy_mac_pset_rtx_upd, // Remote Transmitter Preset Update - active until accept/reject/timeout flag is asserted
    input                           phy_mac_coef_rtx_upd, // Remote Transmitter Coefficients Update - active until accept/reject/timeout flag is asserted
    input                           phy_mac_ftune_rtx_optimal, // Remote Transmitter Fine Tuning reaches Optimal Settings
    // eqctl i/f
    input                           tick_131us, // used to implement the 2ms timeout on rtx requests
    input                           txts_eq_req,  // request equalization bit in TS2 symbol 6 at Gen34 rate
    input                           txts_quie_gua,  // quiesce guarantee bit in TS2 symbol 6 at Gen34 rate
    input                           txts_eq_req_data_rate,  // equalization request data rate bit in TS2 symbol 6 at Gen34 rate
    input                           sta_ls2_eq_phase23_success, // Phase 2 and 3 both are successful
    input                           eqpa_timeout_1us_after_request, //timeout_1us after eq request from master
    input                           eqpa_wait_rei_state, // any active lane in eqpa is in S_WAIT_REI state
    input                           cdm_ras_des_eq_force_pset_ltx_en,  // force upstream port's tx preset enable
    input          [TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input                           cdm_ras_des_eq_force_pset_ltx_en_g4,  // force upstream port's tx preset enable
    input          [TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx_g4, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input                           cdm_ras_des_eq_force_pset_ltx_en_g5,  // force upstream port's tx preset enable
    input          [TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx_g5, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
    input                           cdm_ras_des_eq_force_pset_ltx_en_g6,  // force upstream port's tx preset enable
    input          [TX_PSET_WD-1:0] cdm_ras_des_eq_force_usp_pset_ltx_g6, // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
// ---- outputs -------------
    // ltssm i/f
    output                          eqctl_8eqts1_rcvd, // received 8xeqTS1 @G12
    output                          eqctl_8eqts2_rcvd, // received 8xeqTS2 @G12
    output                          eqctl_8g4eqts1_rcvd, // received 8 x TS1 with eq_redo @G3
    output                          eqctl_8g4eqts2_rcvd, // received 8 x 8GT eqTS2 @G3
    output                          eqctl_8g5eqts1_rcvd, // received 8 x TS1 with eq_redo @G4
    output                          eqctl_8g5eqts2_rcvd, // received 8 x 16GT eqTS2 @G4
    output                          eqctl_precode_request, // de-precode on
    output                          eqctl_precode6_request, // de-precode on
    output                          eqctl_8g6eqts1_rcvd, // received 8 x TS1 with eq_redo @G4
    output                          eqctl_8g6eqts2_rcvd, // received 8 x 16GT eqTS2 @G4
    output         [3:0]            eqctl_2ects1_rcvd, // bit <i> set means received 2xec<i>TS1 @G3 
    output         [3:0]            eqctl_8ects1_rcvd, // bit <i> set means received 8xec<i>TS1 @G3 
    output                          eqctl_ftune_rtx_done, // asserted to ltssm to move Phase 2 to Phase 3  (DC) or Phase 3 to RcvrLock (UC)
    output                          eqctl_8eqrts2_rcvd_g3,  // received 8xeq-requestTS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=0 @G3 or G4 rate
    output                          eqctl_8eqrgts2_rcvd_g3, // received 8xeq-requestTS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=0 @G3 or G4 rate
    output                          eqctl_8eqrts2_rcvd_g4,  // received 8xeq-requestTS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=1 @G3 or G4 rate
    output                          eqctl_8eqrgts2_rcvd_g4, // received 8xeq-requestTS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=1 @G3 or G4 rate
    output                          eqctl_2ects1_retimer_eq_ext0_rcvd, // received 2xeq-requestTS1 with Retimer EQ Extend=0 @G4 rate 
    output                          eqctl_8eqrts2_rcvd_g5,  // received 8xeq-requestTS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=1 G4 or G5 rate
    output                          eqctl_8eqrgts2_rcvd_g5, // received 8xeq-requestTS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=1 G4 or G5 rate
    output                          eqctl_8eqrts2_rcvd_g6,  // received 8xeq-requestTS2 with Quiesce Guarantee=0/1 and Equalization Request Data Rate=1 G4 or G5 rate
    output                          eqctl_8eqrgts2_rcvd_g6, // received 8xeq-requestTS2 with Quiesce Guarantee=1 and Equalization Request Data Rate=1 G4 or G5 rate
    // smlh_byte_xmt i/f
    output         [EQTS_WD-1:0]    eqctl_eqts_info, // concatenation of {s9, s8, s7, s6} for tx TS
    output         [TS_0_WD-1:0]    eqctl_eqts_info_ts0, // concatenation of {s6, s5, s4, s3, s2, s1} for tx TS at g6 rate
    output                          eqctl_mask_eieos, // indication to mask EIEOS as a result of receiving TS1s with a request to reset EIEOS count
    output                          eqctl_2mask_eieos_pulse, // 2 consecutive ec ts1 rcvd pulse with a request to reset EIEOS count
    // cdm i/f
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output reg     [TX_PSET_WD-1:0] sta_lec_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output reg     [RX_PSET_WD-1:0] sta_lec_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output reg     [TX_PSET_WD-1:0] sta_lec_g4_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output reg     [RX_PSET_WD-1:0] sta_lec_g4_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output reg     [TX_PSET_WD-1:0] sta_lec_g5_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output reg     [RX_PSET_WD-1:0] sta_lec_g5_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // lec: Lane Eq. Control Register (Sec. PCIe cap.)
    output reg     [TX_PSET_WD-1:0] sta_lec_g6_pset_ltx, // DC only - Latest Local Transmitter Preset, received on the wire
    output reg     [RX_PSET_WD-1:0] sta_lec_g6_pset_lrx, // DC only - Latest Local Receiver Preset, received on the wire
    // pipe i/f - data
    output reg     [TX_PSET_WD-1:0] mac_phy_pset_ltx, // Local Transmitter Preset
    output reg     [RX_PSET_WD-1:0] mac_phy_pset_lrx, // Local Receiver Preset Hint
    output reg     [TX_COEF_WD-1:0] mac_phy_coef_ltx, // Local Transmitter Coefficients, concatenation of {C+1, C0, C-1}
    output reg     [TX_FSLF_WD-1:0] mac_phy_fslf_rtx, // Remote Transmitter Full Swing and Low Frequency, concatenation of {LF, FS}
    output reg     [TX_PSET_WD-1:0] mac_phy_pset_rtx, // Remote Transmitter Preset 
    output reg     [TX_COEF_WD-1:0] mac_phy_coef_rtx, // Remote Transmitter Coefficients, concatenation of {C+1, C0, C-1}
    output reg                      mac_phy_reject_rtx, // Remote Transmitter Coefficients Reject Flag
    output reg                      mac_phy_accept_rtx, // Remote Transmitter Preset/Coefficients Accept Flag
    output reg                      mac_phy_timeout_rtx, // Timeout for Remote Transmitter Preset/Coefficients Request - Level
    // pipe i/f - status
    output reg                      mac_phy_ftune_rtx, // Remote Transmitter Fine Tuning State, correspond to Phase 2 for DC, Phase 3 for UC
    output reg                      mac_phy_ftune_ltx, // Local Transmitter Fine Tuning State, correspond to Phase 2 for UC, Phase 3 for DC
    output reg                      mac_phy_lpbk_ftune_ltx, // Local Transmitter Fine Tuning State, correspond to Loopback Slave receiving TS1 EC = 2'b01 or 2'b11 at Gen3 rate
    // pipe i/f - control
    output reg                      mac_phy_use_pset, // 1/0: Local Transmitter must use Presets/Coefficients to transmit
    output reg                      mac_phy_fslf_rtx_valid, // Remote Transmitter Full Swing and Low Frequency Valid
    output reg                      mac_phy_pset_ltx_upd, // Local Transmitter Preset Update - active until accept/reject flag is asserted
    output reg                      mac_phy_coef_ltx_upd, // Local Transmitter Coefficients Update - active until accept/reject flag is asserted
    // eqctl i/f
    output                          rxts_eq_mismatch // indicates a possible problem with current eq settings: coefficients/presets on received TS1s don't match the coefficients/presets requested during ftune_rtx
);

reg           [TX_PSET_WD-1:0] mac_phy_pset_g3_stored_rtx;
reg           [TX_PSET_WD-1:0] mac_phy_pset_g4_stored_rtx;
reg           [TX_PSET_WD-1:0] mac_phy_pset_g5_stored_rtx;
reg           [TX_PSET_WD-1:0] mac_phy_pset_g6_stored_rtx;
reg           [TX_COEF_WD-1:0] mac_phy_coef_g3_stored_rtx;
reg           [TX_COEF_WD-1:0] mac_phy_coef_g4_stored_rtx;
reg           [TX_COEF_WD-1:0] mac_phy_coef_g5_stored_rtx;
reg           [TX_COEF_WD-1:0] mac_phy_coef_g6_stored_rtx;
reg                            mac_phy_pset_rtx_was_last_g3, mac_phy_pset_rtx_was_last_g4, mac_phy_pset_rtx_was_last_g5, mac_phy_pset_rtx_was_last_g6;
wire          [TX_PSET_WD-1:0] mac_phy_pset_stored_rtx;
wire          [TX_COEF_WD-1:0] mac_phy_coef_stored_rtx;
reg           [2:0]            previous_rate; // [2] gen5, [1] gen4, [0] gen3. Only one bit can be set
wire          [TX_FSLF_WD-1:0] int_phy_mac_fslf_ltx;
wire          [TX_COEF_WD-1:0] int_phy_mac_coef_ltx;
wire                           int_phy_mac_reject_ltx;
wire                           int_phy_mac_accept_ltx;
wire          [TX_PSET_WD-1:0] int_phy_mac_pset_rtx;
wire          [TX_COEF_WD-1:0] int_phy_mac_coef_rtx;
wire                           int_phy_mac_ftune_rtx_done;
wire                           int_phy_mac_fslf_ltx_valid;
wire                           int_phy_mac_pset_rtx_upd;
wire                           int_phy_mac_coef_rtx_upd;
wire                           int_eqpa_timeout_1us_after_request;
wire                           int_eqpa_wait_rei_state;
wire                           int_eqpa_v7_timeout_1us_after_request;
reg           [TX_PSET_WD-1:0] phy_mac_pset_ltx;
reg           [TX_PSET_WD-1:0] phy_mac_pset_ltx_r;
reg           [TX_PSET_WD-1:0] phy_mac_pset_ltx_stored_20g;
reg           [TX_PSET_WD-1:0] phy_mac_pset_ltx_stored_25g;
wire             [EQTS_WD-1:0] rxts;// internal aliases
wire                           rxts_parity;
wire                           rxts_reject;
wire        [TX_COEF_WD/3-1:0] rxts_coef_0, rxts_coef_1, rxts_coef_2;
wire          [TX_COEF_WD-1:0] rxts_coef;
wire                           rxts_use_pset;
wire          [TX_PSET_WD-1:0] rxts_pset;
wire                           rxts_rst_eiec;
wire                     [1:0] rxts_ec;
wire                     [3:0] rxts_ec_oneh; // one hot encoded
wire                           rxts_eq_req;
wire                           rxts_quie_gua;
wire                           rxts_retimer_eq_ext;
wire             [EQTS_WD-1:0] txts;
reg              [EQTS_WD-2:0] txts_g3;
wire             [EQTS_WD-2:0] txts_g3_real;
reg              [EQTS_WD-1:0] txts_g2;
wire             [EQTS_WD-1:0] txts2_g3;
reg              [EQTS_WD-1:0] txts2_g3_d;
wire             [EQTS_WD-1:0] txts_g3_w_parity;
reg                      [3:0] eqctl_2ects1_rcvd_d;
reg                            eqctl_8eqts2_rcvd_d;
reg                            eqctl_8eqts1_rcvd_d;
wire                           eqctl_2eqts1_rcvd;
reg                            eqctl_2eqts1_rcvd_d;
reg                            eqctl_8g4eqts1_rcvd_d;
reg                            eqctl_8g4eqts2_rcvd_d;
reg                            eqctl_8g5eqts1_rcvd_d;
reg                            eqctl_8g5eqts2_rcvd_d;
reg                            smlh_send_pc_req_d;
reg                            smlh_send_pc6_req_d;
reg                            eqctl_8g6eqts1_rcvd_d;
reg                            eqctl_8g6eqts2_rcvd_d;
wire                           eqctl_2eqts1_rcvd_pulse;
wire                     [3:0] eqctl_2ects1_rcvd_pulse;
wire                           eqctl_2ects1_rcvd_pulse_ftune_ltx;
wire                           eqctl_2ects1_rcvd_pulse_lpbk_slave;
wire                           eqctl_2ects1_rcvd_pulse_lpbk_slave_pset;
wire                           eqctl_2ects1_rcvd_pulse_lpbk_slave_coef;
wire                           eqctl_8eqts2_rcvd_pulse;
wire                           eqctl_8eqts1_rcvd_pulse;
reg                            eqctl_8g4eqts1_rcvd_pulse;
reg                            eqctl_8g4eqts2_rcvd_pulse;
reg                            eqctl_8g5eqts1_rcvd_pulse;
reg                            eqctl_8g5eqts2_rcvd_pulse;
reg                            eqctl_8g6eqts1_rcvd_pulse;
reg                            eqctl_8g6eqts2_rcvd_pulse;
wire                           g6_rate = ltssm_current_data_rate_g6;
wire                           g6_pulse = ltssm_current_data_rate_g6_pulse;
// ts0 tx:
//        dsp: eq 1, eq 2 until rxed 2 ts0s with ec = 10b on all lanes
//        usp: eq 0, eq 1, eq 2, eq 3 until rxed 2 ts1s with ec = 11b on all lanes
// ts0 rx:
//        dsp: eq phase 1, eq phase 2
//        usp: R.Lock, eq phase 0, eq phase 1
//
// if in R.Lock from EQ state, must not detect TS0s
wire                           ts0_apply_window = g6_rate & (upstream_component ? (ltssm_state_equalization[1] | ltssm_state_equalization[2]) : ((~ltssm_state_last_equalization_any & ltssm_state_rcvrlock) | ltssm_state_equalization[0] | ltssm_state_equalization[1]));
//wire                           ts0_1_app_window = g6_rate & upstream_component & ltssm_state_equalization[2];
wire                           eqctl_2ects1_rcvd_ftune_rtx;
wire load_mac_phy_fslf_rtx;
wire load_mac_phy_pset_rtx;
wire load_mac_phy_coef_rtx;
wire load_mac_phy_pset_coef_rtx_init;
reg mac_phy_pset_rtx_was_last;
reg mac_phy_pset_ltx_was_last;
reg int_phy_mac_fslf_ltx_valid_d;
reg int_phy_mac_pset_rtx_upd_d;
reg int_phy_mac_coef_rtx_upd_d;
reg int_mac_phy_ftune_ltx_d;
wire int_mac_phy_reject_rtx;
wire int_mac_phy_accept_rtx;
wire int_mac_phy_ftune_rtx;
wire int_mac_phy_ftune_ltx;
wire load_int_phy_mac_fslf_ltx;
wire load_int_phy_mac_pset_rtx;
wire load_int_phy_mac_coef_rtx;
wire load_txts_ec2_ec3;

wire load_sta_lec_pset_g12;
wire load_sta_lec_g4_pset_g12;
wire load_sta_lec_g4_pset_g3;
wire load_sta_lec_g5_pset_g12;
wire load_sta_lec_g5_pset_g12_rcfg;
//wire load_sta_lec_g5_pset_g3;
wire load_sta_lec_g5_pset_g4;
wire load_sta_lec_g6_pset_g12;
wire load_sta_lec_g6_pset_g12_rcfg;
//wire load_sta_lec_g5_pset_g3;
wire load_sta_lec_g6_pset_g5;
wire load_mac_phy_pset_ltx_init_g3;
wire load_mac_phy_pset_ltx_init_g4;
wire load_mac_phy_pset_ltx_init_g5;
wire load_mac_phy_pset_ltx_init_g6;
wire load_mac_phy_pset_ltx_new;
wire load_mac_phy_coef_ltx_init;
wire load_mac_phy_coef_ltx_new;

wire load_txts_pset_coef_ltx;
wire load_txts_pset_fslf_ltx;

wire load_txts_default;
reg load_txts_pset_coef_rtx_init;
wire load_txts_pset_rtx;
wire load_txts_coef_rtx;
wire load_txts_rst_eiec_rtx;
wire load_txts_pset_accept_ltx;
wire load_txts_pset_reject_ltx;
wire load_txts_coef_accept_ltx;
wire load_txts_coef_reject_ltx;

reg rxts_txts_match_accept_d;
reg rxts_txts_match_reject_d;
wire rxts_pset_match;
wire rxts_coef_match;
wire rxts_txts_pset_match_accept;
wire rxts_txts_pset_match_reject;
wire rxts_txts_coef_match_accept;
wire rxts_txts_coef_match_reject;
wire rxts_txts_match_accept;
wire rxts_txts_match_reject;
reg [3:0] timer_2ms;

wire int_eqts_enable;
wire int_slave_in_lpbkentry;
wire int_slave_in_lpbkentry_act;
wire load_txts_pset_coef_rtx_lpbk_master;

wire       current_eqctl_8eqts1_rcvd;
wire       current_eqctl_8eqts2_rcvd;
wire       current_eqctl_8eqrts2_rcvd_g3;
wire       current_eqctl_8eqrgts2_rcvd_g3;
reg  [3:0] latched_eqctl_8ects1_rcvd;
reg        latched_eqctl_8eqts1_rcvd;
reg        latched_eqctl_8eqts2_rcvd;
reg        latched_eqctl_8eqrts2_rcvd_g3;
reg        latched_eqctl_8eqrgts2_rcvd_g3;
wire       current_eqctl_8g4eqts1_rcvd;
wire       current_eqctl_8g4eqts2_rcvd;
wire       current_eqctl_8eqrts2_rcvd_g4;
wire       current_eqctl_8eqrgts2_rcvd_g4;
reg        latched_eqctl_8g4eqts1_rcvd;
reg        latched_eqctl_8g4eqts2_rcvd;
reg        latched_eqctl_8eqrts2_rcvd_g4;
reg        latched_eqctl_8eqrgts2_rcvd_g4;
wire       current_eqctl_8g5eqts1_rcvd;
wire       current_eqctl_8g5eqts2_rcvd;
wire       current_eqctl_8eqrts2_rcvd_g5;
wire       current_eqctl_8eqrgts2_rcvd_g5;
reg        latched_eqctl_8g5eqts1_rcvd;
reg        latched_eqctl_8g5eqts2_rcvd;
reg        latched_eqctl_8eqrts2_rcvd_g5;
reg        latched_eqctl_8eqrgts2_rcvd_g5;
reg        eqctl_2g6eqts0_rcvd, latched_eqctl_2g6eqts0_rcvd;
wire       current_eqctl_8g6eqts1_rcvd;
wire       current_eqctl_8g6eqts2_rcvd;
wire       current_eqctl_8eqrts2_rcvd_g6;
wire       current_eqctl_8eqrgts2_rcvd_g6;
reg        latched_eqctl_8g6eqts1_rcvd;
reg        latched_eqctl_8g6eqts2_rcvd;
reg        latched_eqctl_8eqrts2_rcvd_g6;
reg        latched_eqctl_8eqrgts2_rcvd_g6;

reg sta_lec_pset_ltx_valid; // only for upstream port
reg sta_lec_g4_pset_ltx_valid;
reg sta_lec_g5_pset_ltx_valid;
reg sta_lec_g6_pset_ltx_valid;
wire sta_lec_pset_ltx_valid_cmn;

wire timeout_rtx;

wire [TX_PSET_WD-1:0] int_sta_lec_pset_ltx ;
wire [TX_PSET_WD-1:0] int_sta_lec_g4_pset_ltx ;
wire [TX_PSET_WD-1:0] int_sta_lec_g5_pset_ltx ;
wire [TX_PSET_WD-1:0] int_sta_lec_g6_pset_ltx ;

reg [TX_PSET_WD-1:0] mac_phy_pset_rtx_init;
reg [TX_COEF_WD-1:0] mac_phy_coef_rtx_init;


///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// optional input registers on PHY inputs
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Replace delay cell with "with enable" cell.(clock gating and to reduce power consumption)
localparam N_DELAY_CYLES = REGIN ? 1 : 0;
localparam DATAPATH_WIDTH = TX_FSLF_WD+TX_COEF_WD+2+TX_PSET_WD+TX_COEF_WD+4 +2 ;
wire        enable4delay;
assign enable4delay = !(ltssm_state_detect || ltssm_state_disable || ltssm_state_hotreset || ltssm_state_l0
                               || ltssm_state_l0s || ltssm_state_l123 || ltssm_state_l1 ||  ltssm_state_l2);
delay_n_w_enable
 #(N_DELAY_CYLES, DATAPATH_WIDTH) u_delay
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (enable4delay),
    .din        (
                  { phy_mac_fslf_ltx, phy_mac_coef_ltx, phy_mac_reject_ltx,
                    phy_mac_accept_ltx, phy_mac_pset_rtx, phy_mac_coef_rtx,
                    phy_mac_ftune_rtx_done,
                    phy_mac_fslf_ltx_valid, phy_mac_pset_rtx_upd,
                    phy_mac_coef_rtx_upd , eqpa_timeout_1us_after_request, eqpa_wait_rei_state }
                ),
    .dout       (
                  { int_phy_mac_fslf_ltx, int_phy_mac_coef_ltx, int_phy_mac_reject_ltx,
                    int_phy_mac_accept_ltx, int_phy_mac_pset_rtx, int_phy_mac_coef_rtx,
                    int_phy_mac_ftune_rtx_done,
                    int_phy_mac_fslf_ltx_valid, int_phy_mac_pset_rtx_upd,
                    int_phy_mac_coef_rtx_upd , int_eqpa_timeout_1us_after_request, int_eqpa_wait_rei_state }
                 )
);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// rxts
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign rxts = smlh_eqts_info;

// TS1 at Gen3 rate
assign rxts_parity = rxts[31]; // unused
assign rxts_reject = g6_rate ? rxts[23] : rxts[30];
assign rxts_coef_2 = rxts[24 +: 6]; // unused
assign rxts_coef_1 = rxts[16 +: 6]; // unused
assign rxts_coef_0 = rxts[8 +: 6]; // unused
assign rxts_coef = {rxts_coef_2, rxts_coef_1, rxts_coef_0}; // unused
assign rxts_use_pset = rxts[7]; // unused
assign rxts_pset = rxts[6:3]; // unused
assign rxts_rst_eiec = rxts[2]; // gen6 has the same as gen3/4/5
assign rxts_ec[1:0] = rxts[1:0]; // unused
// for gen6 rate and usp in eq0, moving to eq1 needs 2 ts0s with ec=01b && retimer eq extend bit = 0b
assign rxts_ec_oneh[3:0] = {rxts[1:0]==2'b11, rxts[1:0]==2'b10, ( (~upstream_component && ltssm_state_equalization[0] && g6_rate) ? (~rxts_retimer_eq_ext & rxts[1:0]==2'b01) : rxts[1:0]==2'b01), rxts[1:0]==2'b00};
assign rxts_retimer_eq_ext = rxts[15]; // gen6 has the same as gen3/4/5
// TS2 at Gen3 rate
assign rxts_eq_req = rxts[7] && smlh_ts2_rcvd; // gen6 has the same as gen3/4/5
assign rxts_quie_gua = rxts[6] && smlh_ts2_rcvd; // gen6 has the same as gen3/4/5

assign eqctl_mask_eieos = rxts_rst_eiec && int_mac_phy_ftune_ltx; // when fine tuning as a slave and received a request to reset EIEOS count
assign eqctl_2mask_eieos_pulse = |eqctl_2ects1_rcvd_pulse & eqctl_mask_eieos; // 2 consecutive EC ts1 rcvd pulse with a request to reset EIEOS count

// EC TS1 at Gen34 rate
assign current_eqctl_8eqts1_rcvd      = ltssm_current_data_rate_g12 && smlh_ts1_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7];
assign current_eqctl_8eqts2_rcvd      = ltssm_current_data_rate_g12 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7];
assign current_eqctl_8eqrts2_rcvd_g3  = !ltssm_current_data_rate_g12 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7]
 && ( g6_rate ? (rxts[5:3] == 3'b000) : (rxts[5:4] == 2'b00));
assign current_eqctl_8eqrgts2_rcvd_g3 = eqctl_8eqrts2_rcvd_g3 && rxts[6]; // with quiesce guarantee bit set
assign current_eqctl_8g4eqts1_rcvd    = ltssm_current_data_rate_g3 && smlh_ts1_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7];
assign current_eqctl_8g4eqts2_rcvd    = ltssm_current_data_rate_g3 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[15];
assign current_eqctl_8eqrts2_rcvd_g4  = !ltssm_current_data_rate_g12 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7]
 && ( g6_rate ? (rxts[5:3] == 3'b001) : (rxts[5:4] == 2'b10));
assign current_eqctl_8eqrgts2_rcvd_g4 = eqctl_8eqrts2_rcvd_g4 && rxts[6]; // with quiesce guarantee bit set
assign current_eqctl_8g5eqts1_rcvd    = ltssm_current_data_rate_g4 && smlh_ts1_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7];
assign current_eqctl_8g5eqts2_rcvd    = ltssm_current_data_rate_g4 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[15];
assign current_eqctl_8eqrts2_rcvd_g5  = !ltssm_current_data_rate_g12 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7] && ( g6_rate ? (rxts[5:3] == 3'b010) : (rxts[5:4] == 2'b01));
assign current_eqctl_8eqrgts2_rcvd_g5 = eqctl_8eqrts2_rcvd_g5 && rxts[6]; // with quiesce guarantee bit set
assign current_eqctl_8g6eqts1_rcvd    = ltssm_current_data_rate_g5 && smlh_ts1_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7];
assign current_eqctl_8g6eqts2_rcvd    = ltssm_current_data_rate_g5 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[15];
assign current_eqctl_8eqrts2_rcvd_g6  = !ltssm_current_data_rate_g12 && smlh_ts2_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=8) && rxts[7] && (g6_rate ? (rxts[5:3] == 3'b011) : (rxts[5:4] == 2'b11));
assign current_eqctl_8eqrgts2_rcvd_g6 = eqctl_8eqrts2_rcvd_g6 && rxts[6]; // with quiesce guarantee bit set

// eqctl_2g6eqts0_rcvd: detect 2 ts0s with retimer_eq_ectend = 0b received in eq1 for dsp
always @* begin : eqctl_2g6eqts0_rcvd_PROC
    eqctl_2g6eqts0_rcvd = latched_eqctl_2g6eqts0_rcvd;

    if ( ~ltssm_state_equalization[1] )
        eqctl_2g6eqts0_rcvd = 0;
    else if ( upstream_component && ltssm_state_equalization[1] && g6_rate && ltssm_clear )
        eqctl_2g6eqts0_rcvd = 1'b1;
    else if ( g6_rate && smlh_ts_rcvd_s6s9_pcnt>=2 && smlh_ts0_rcvd && upstream_component && ltssm_state_equalization[1] && ~rxts_retimer_eq_ext )
        eqctl_2g6eqts0_rcvd = 0;
end // eqctl_2g6eqts0_rcvd_PROC

// latched_eqctl_2g6eqts0_rcvd: detect 2 ts0s with retimer_eq_ectend = 0b received in eq1 for dsp
always @( posedge core_clk or negedge core_rst_n ) begin : latched_eqctl_2g6eqts0_rcvd_PROC
    if ( ~core_rst_n )
        latched_eqctl_2g6eqts0_rcvd <= #TP  '0;
    else
        latched_eqctl_2g6eqts0_rcvd <= #TP eqctl_2g6eqts0_rcvd;
end // latched_eqctl_2g6eqts0_rcvd_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : eq_ec_2_8_ts_rcvd_PROC
    integer i;

    if ( ~core_rst_n ) begin
        latched_eqctl_8eqts1_rcvd      <= #TP '0;
        latched_eqctl_8eqts2_rcvd      <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g3  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g3 <= #TP '0;
        latched_eqctl_8g4eqts1_rcvd    <= #TP '0;
        latched_eqctl_8g4eqts2_rcvd    <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g4  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g4 <= #TP '0;
        latched_eqctl_8g5eqts1_rcvd    <= #TP '0;
        latched_eqctl_8g5eqts2_rcvd    <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g5  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g5 <= #TP '0;
        latched_eqctl_8g6eqts1_rcvd    <= #TP '0;
        latched_eqctl_8g6eqts2_rcvd    <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g6  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g6 <= #TP '0;
    end else if ( ltssm_clear ) begin
        latched_eqctl_8eqts1_rcvd      <= #TP '0;
        latched_eqctl_8eqts2_rcvd      <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g3  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g3 <= #TP '0;
        latched_eqctl_8g4eqts1_rcvd    <= #TP '0;
        latched_eqctl_8g4eqts2_rcvd    <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g4  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g4 <= #TP '0;
        latched_eqctl_8g5eqts1_rcvd    <= #TP '0;
        latched_eqctl_8g5eqts2_rcvd    <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g5  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g5 <= #TP '0;
        latched_eqctl_8g6eqts1_rcvd    <= #TP '0;
        latched_eqctl_8g6eqts2_rcvd    <= #TP '0;
        latched_eqctl_8eqrts2_rcvd_g6  <= #TP '0;
        latched_eqctl_8eqrgts2_rcvd_g6 <= #TP '0;
    end else begin
        if ( current_eqctl_8eqts1_rcvd )
            latched_eqctl_8eqts1_rcvd      <= #TP 1;
        if ( current_eqctl_8eqts2_rcvd )
            latched_eqctl_8eqts2_rcvd      <= #TP 1;
        if ( current_eqctl_8eqrts2_rcvd_g3 )
            latched_eqctl_8eqrts2_rcvd_g3  <= #TP 1;
        if ( current_eqctl_8eqrgts2_rcvd_g3 )
            latched_eqctl_8eqrgts2_rcvd_g3 <= #TP 1;

        if ( current_eqctl_8g4eqts1_rcvd )
            latched_eqctl_8g4eqts1_rcvd    <= #TP 1;
        if ( current_eqctl_8g4eqts2_rcvd )
            latched_eqctl_8g4eqts2_rcvd    <= #TP 1;
        if ( current_eqctl_8eqrts2_rcvd_g4 )
            latched_eqctl_8eqrts2_rcvd_g4  <= #TP 1;
        if ( current_eqctl_8eqrgts2_rcvd_g4 )
            latched_eqctl_8eqrgts2_rcvd_g4 <= #TP 1;
        if ( current_eqctl_8g5eqts1_rcvd )
            latched_eqctl_8g5eqts1_rcvd    <= #TP 1;
        if ( current_eqctl_8g5eqts2_rcvd )
            latched_eqctl_8g5eqts2_rcvd    <= #TP 1;
        if ( current_eqctl_8eqrts2_rcvd_g5 )
            latched_eqctl_8eqrts2_rcvd_g5  <= #TP 1;
        if ( current_eqctl_8eqrgts2_rcvd_g5 )
            latched_eqctl_8eqrgts2_rcvd_g5 <= #TP 1;
        if ( current_eqctl_8g6eqts1_rcvd )
            latched_eqctl_8g6eqts1_rcvd    <= #TP 1;
        if ( current_eqctl_8g6eqts2_rcvd )
            latched_eqctl_8g6eqts2_rcvd    <= #TP 1;
        if ( current_eqctl_8eqrts2_rcvd_g6 )
            latched_eqctl_8eqrts2_rcvd_g6  <= #TP 1;
        if ( current_eqctl_8eqrgts2_rcvd_g6 )
            latched_eqctl_8eqrgts2_rcvd_g6 <= #TP 1;
    end
end // eq_ec_2_8_ts_rcvd_PROC

assign eqctl_8eqts1_rcvd      = current_eqctl_8eqts1_rcvd | latched_eqctl_8eqts1_rcvd;
assign eqctl_8eqts2_rcvd      = current_eqctl_8eqts2_rcvd | latched_eqctl_8eqts2_rcvd;
assign eqctl_8eqrts2_rcvd_g3  = current_eqctl_8eqrts2_rcvd_g3 | latched_eqctl_8eqrts2_rcvd_g3;
assign eqctl_8eqrgts2_rcvd_g3 = current_eqctl_8eqrgts2_rcvd_g3 | latched_eqctl_8eqrgts2_rcvd_g3;
assign eqctl_8g4eqts1_rcvd    = current_eqctl_8g4eqts1_rcvd | latched_eqctl_8g4eqts1_rcvd;
assign eqctl_8g4eqts2_rcvd    = current_eqctl_8g4eqts2_rcvd | latched_eqctl_8g4eqts2_rcvd;
assign eqctl_8eqrts2_rcvd_g4  = current_eqctl_8eqrts2_rcvd_g4 | latched_eqctl_8eqrts2_rcvd_g4;
assign eqctl_8eqrgts2_rcvd_g4 = current_eqctl_8eqrgts2_rcvd_g4 | latched_eqctl_8eqrgts2_rcvd_g4;
assign eqctl_8g5eqts1_rcvd    = current_eqctl_8g5eqts1_rcvd | latched_eqctl_8g5eqts1_rcvd;
assign eqctl_8g5eqts2_rcvd    = current_eqctl_8g5eqts2_rcvd | latched_eqctl_8g5eqts2_rcvd;
assign eqctl_8eqrts2_rcvd_g5  = current_eqctl_8eqrts2_rcvd_g5 | latched_eqctl_8eqrts2_rcvd_g5;
assign eqctl_8eqrgts2_rcvd_g5 = current_eqctl_8eqrgts2_rcvd_g5 | latched_eqctl_8eqrgts2_rcvd_g5;
assign eqctl_8g6eqts1_rcvd    = current_eqctl_8g6eqts1_rcvd | latched_eqctl_8g6eqts1_rcvd;
assign eqctl_8g6eqts2_rcvd    = current_eqctl_8g6eqts2_rcvd | latched_eqctl_8g6eqts2_rcvd;
assign eqctl_8eqrts2_rcvd_g6  = current_eqctl_8eqrts2_rcvd_g6 | latched_eqctl_8eqrts2_rcvd_g6;
assign eqctl_8eqrgts2_rcvd_g6 = current_eqctl_8eqrgts2_rcvd_g6 | latched_eqctl_8eqrgts2_rcvd_g6;

assign eqctl_2ects1_rcvd[3:0] = (!ltssm_current_data_rate_g12 && ( ts0_apply_window ? smlh_ts0_rcvd : /* ts0_1_app_window ? (smlh_ts0_rcvd | smlh_ts1_rcvd) : */ (smlh_ts1_rcvd)) && (smlh_ts_rcvd_s6s9_pcnt>=2)) ? rxts_ec_oneh[3:0] : 4'b0;
assign eqctl_8ects1_rcvd[3:0] = (!ltssm_current_data_rate_g12 && ( ts0_apply_window ? smlh_ts0_rcvd : /* ts0_1_app_window ? (smlh_ts0_rcvd | smlh_ts1_rcvd) : */ (smlh_ts1_rcvd)) && (smlh_ts_rcvd_s6s9_pcnt>=8)) ? rxts_ec_oneh[3:0] : 4'b0;
assign eqctl_2eqts1_rcvd      = ltssm_current_data_rate_g12 && smlh_ts1_rcvd && (smlh_ts_rcvd_s6s9_pcnt>=2) && rxts[7];

// detect a change in received ecTS1
always @(posedge core_clk or negedge core_rst_n) begin : eqctl_2ects1_rcvd_d_seq_PROC
    if( !core_rst_n ) begin
        eqctl_2ects1_rcvd_d <= #TP '0;
        eqctl_8eqts2_rcvd_d <= #TP '0;
        eqctl_8eqts1_rcvd_d <= #TP '0;
        eqctl_2eqts1_rcvd_d <= #TP '0;
        eqctl_8g4eqts1_rcvd_d <= #TP '0;
        eqctl_8g4eqts2_rcvd_d <= #TP '0;
        eqctl_8g5eqts1_rcvd_d <= #TP '0;
        eqctl_8g5eqts2_rcvd_d <= #TP '0;
        eqctl_8g6eqts1_rcvd_d <= #TP '0;
        eqctl_8g6eqts2_rcvd_d <= #TP '0;
    end else begin
        eqctl_2ects1_rcvd_d <= #TP eqctl_2ects1_rcvd;
        eqctl_8eqts2_rcvd_d <= #TP eqctl_8eqts2_rcvd;
        eqctl_8eqts1_rcvd_d <= #TP eqctl_8eqts1_rcvd;
        eqctl_2eqts1_rcvd_d <= #TP eqctl_2eqts1_rcvd;
        eqctl_8g4eqts1_rcvd_d <= #TP eqctl_8g4eqts1_rcvd;
        eqctl_8g4eqts2_rcvd_d <= #TP eqctl_8g4eqts2_rcvd;
        eqctl_8g5eqts1_rcvd_d <= #TP eqctl_8g5eqts1_rcvd;
        eqctl_8g5eqts2_rcvd_d <= #TP eqctl_8g5eqts2_rcvd;
        eqctl_8g6eqts1_rcvd_d <= #TP eqctl_8g6eqts1_rcvd;
        eqctl_8g6eqts2_rcvd_d <= #TP eqctl_8g6eqts2_rcvd;
    end
end

wire lpbk_after_lpbkeq_i = ltssm_state_equalization_any_exit & ltssm_state_lpbkentry;
reg  lpbk_after_lpbkeq;
always @(posedge core_clk or negedge core_rst_n) begin : lpbk_after_lpbkeq_PROC
    if ( ~core_rst_n )
        lpbk_after_lpbkeq <= #TP '0;
    else if ( ltssm_state_detect )
        lpbk_after_lpbkeq <= #TP '0;
    else if ( lpbk_after_lpbkeq_i )
        lpbk_after_lpbkeq <= #TP 1;
end // lpbk_after_lpbkeq_PROC


assign eqctl_2ects1_rcvd_pulse = eqctl_2ects1_rcvd & ~eqctl_2ects1_rcvd_d;
//For Loopback at Gen3 rate, if EC field of TS1s is appropriate, apply EQ settings to Slave transmitter. Exclude the loopback.entry after Loopback Eq
assign int_slave_in_lpbkentry = (!ltssm_lpbk_master && ltssm_state_lpbkentry) & ~(lpbk_after_lpbkeq_i || lpbk_after_lpbkeq);
assign int_slave_in_lpbkentry_act = (!ltssm_lpbk_master && (ltssm_state_lpbkentry | ltssm_state_lpbkact));
assign eqctl_2ects1_rcvd_pulse_ftune_ltx = ltssm_active_lane & (upstream_component ? (eqctl_2ects1_rcvd_pulse[2] & ltssm_state_equalization[2]) :
                                                                                     (eqctl_2ects1_rcvd_pulse[3] & ltssm_state_equalization[3]));
//eqctl_2ects1_rcvd_pulse_lpbk_slave is generated only in LPBK_ENTRY state
assign eqctl_2ects1_rcvd_pulse_lpbk_slave_pset = ((eqctl_2ects1_rcvd_pulse[2] | eqctl_2ects1_rcvd_pulse[3]) & int_slave_in_lpbkentry) & rxts[7]; //pset request
assign eqctl_2ects1_rcvd_pulse_lpbk_slave_coef = ((eqctl_2ects1_rcvd_pulse[2] | eqctl_2ects1_rcvd_pulse[3]) & int_slave_in_lpbkentry) & !rxts[7]; //coef request
assign eqctl_2ects1_rcvd_pulse_lpbk_slave = eqctl_2ects1_rcvd_pulse_lpbk_slave_pset | eqctl_2ects1_rcvd_pulse_lpbk_slave_coef;

//mac_phy_lpbk_ftune_ltx is for loopback slave to fine-tune local transmitter when receiving TS1 EC=2'b10 or 2'b11 from loopback master.
//mac_phy_lpbk_ftune_ltx functionality is the same as mac_phy_ftune_ltx in normal equalization.
always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_lpbk_ftune_ltx_PROC
    if ( !core_rst_n ) begin
        mac_phy_lpbk_ftune_ltx <= #TP '0;
    end else if ( !int_slave_in_lpbkentry_act ) begin
        mac_phy_lpbk_ftune_ltx <= #TP '0;
    end else if ( eqctl_2ects1_rcvd_pulse_lpbk_slave ) begin
        mac_phy_lpbk_ftune_ltx <= #TP 1;
    end
end //always


assign eqctl_2ects1_rcvd_ftune_rtx = upstream_component ? (eqctl_2ects1_rcvd[3] & ltssm_state_equalization[3]) : (eqctl_2ects1_rcvd[2] & ltssm_state_equalization[2]);
wire rxts_txts_match, rxts_txts_match_rising_edge;
reg  rxts_txts_match_d, retimer_eq_ext0_rcvd;

// detect 2 RX ects1s with requested EQ settings matching after 1us
assign rxts_txts_match = ((rxts_pset_match && int_phy_mac_pset_rtx_upd) || (rxts_coef_match && int_phy_mac_coef_rtx_upd) || phy_mac_ftune_rtx_optimal) &&
    eqctl_2ects1_rcvd_ftune_rtx && int_eqpa_timeout_1us_after_request ;

always @(posedge core_clk or negedge core_rst_n) begin : rxts_txts_match_d_PROC
  if(!core_rst_n) begin
    rxts_txts_match_d <= #TP '0;
  end else begin
    rxts_txts_match_d <= #TP rxts_txts_match;
  end
end //rxts_txts_match_d_PROC

assign rxts_txts_match_rising_edge = rxts_txts_match & ~rxts_txts_match_d;

//latch/load rxts[15] the retimer eq extend bit, retimer_eq_ext0_rcvd = 1 indicates retimer eq extend bit = 0 received 
always @(posedge core_clk or negedge core_rst_n) begin : retimer_eq_ext0_rcvd_PROC
  if(!core_rst_n) begin
    retimer_eq_ext0_rcvd <= #TP '0;
  end else if( ~((ltssm_current_data_rate_g4 || ltssm_current_data_rate_g5 || ltssm_current_data_rate_g6) && ((upstream_component && ltssm_state_equalization[3]) || (~upstream_component && ltssm_state_equalization[2]))) ) begin
    // not gen4 eq master
    retimer_eq_ext0_rcvd <= #TP '0;
  end else if( rxts_txts_match_rising_edge ) begin
    retimer_eq_ext0_rcvd <= #TP ~rxts_retimer_eq_ext;
  end
end //retimer_eq_ext0_rcvd_PROC

assign eqctl_2ects1_retimer_eq_ext0_rcvd = retimer_eq_ext0_rcvd; // retimer equalization extend Gen4 rate

assign eqctl_8eqts2_rcvd_pulse = eqctl_8eqts2_rcvd & ~eqctl_8eqts2_rcvd_d;
assign eqctl_8eqts1_rcvd_pulse = eqctl_8eqts1_rcvd & ~eqctl_8eqts1_rcvd_d;
assign eqctl_2eqts1_rcvd_pulse = eqctl_2eqts1_rcvd & ~eqctl_2eqts1_rcvd_d;

assign eqctl_8g4eqts1_rcvd_pulse = eqctl_8g4eqts1_rcvd & ~eqctl_8g4eqts1_rcvd_d;
assign eqctl_8g4eqts2_rcvd_pulse = eqctl_8g4eqts2_rcvd & ~eqctl_8g4eqts2_rcvd_d;
assign eqctl_8g5eqts1_rcvd_pulse = eqctl_8g5eqts1_rcvd & ~eqctl_8g5eqts1_rcvd_d;
assign eqctl_8g5eqts2_rcvd_pulse = eqctl_8g5eqts2_rcvd & ~eqctl_8g5eqts2_rcvd_d;
assign eqctl_8g6eqts1_rcvd_pulse = eqctl_8g6eqts1_rcvd & ~eqctl_8g6eqts1_rcvd_d;
assign eqctl_8g6eqts2_rcvd_pulse = eqctl_8g6eqts2_rcvd & ~eqctl_8g6eqts2_rcvd_d;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Data/Control/Status Registers for pipe signals
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*html_start
<p><b>sta_lec_pset_ltx/lrx</b><br>
Data register used to latch tx and rx presets in eqTS2 received by DC @G12 rate in Recovery.RcvCfg.
To latch tx and rx presets in eqTS1 received by DUT @G12 rate in Polling.Active, used in Polling.Compliance.
To latch tx and rx presets in eqTS1 received by Loopback Slave @G12 rate in Cfg.Linkwidth.Start, used in Loopback.Entry.
These values are presented to the PHY following a data rate change to G3, the PHY calculates corresponding
coefficients and FS LF values.
html_end*/
wire eqctl_8eqts2_rcvd_pulse_i;
assign eqctl_8eqts2_rcvd_pulse_i = eqctl_8eqts2_rcvd_pulse;
assign load_sta_lec_pset_g12 = (ltssm_current_data_rate_g12 && (!upstream_component && eqctl_8eqts2_rcvd_pulse_i && ltssm_state_rcvrcfg & ltssm_captured_ts_data_rate_g3)) ||
                               (ltssm_current_data_rate_g12 && (((ltssm_state_pollactive && eqctl_8eqts1_rcvd_pulse) ||
                                                                 (ltssm_state_cfglwstart && eqctl_2eqts1_rcvd_pulse)) & ~ltssm_cmd_eqts_gen12[1])); //if ~bypass_eq to gen5

always @(posedge core_clk or negedge core_rst_n) begin : sta_lec_pset_ltx_lrx_seq_PROC
    if( !core_rst_n ) begin
        sta_lec_pset_ltx <= #TP `DEFAULT_LOCAL_G3_TX_PRESET;
        sta_lec_pset_lrx <= #TP {RX_PSET_WD{1'b1}};
    end else begin
        if ( ~ltssm_clear && load_sta_lec_pset_g12 ) begin
            sta_lec_pset_ltx <= #TP rxts[6:3];
            sta_lec_pset_lrx <= #TP rxts[2:0];
        end
    end
end

// ## Selecting Tx Preset Value in Gen3 for Upstream Component (from Rev4 spec) ##
// IF (Tx Preset in Config Register is supported)
//  -> Use cfg_lec_g4_pset_ltx(Tx Preset in Config Register) for both LTX and TXTS1(reject=0)
// ELSE
//  -> Use 0x4 for both LTX and TXTS1(reject=0)
//
// ## Selecting Tx Preset Value in Gen3 for Downstream Component (from Rev4 spec) ##
// IF (Received EQ TS2)
//  -> Use sta_lec_pset_ltx
//     IF (PHY respond is legal : phy_mac_reject_ltx=0)
//       -> Use the value / Tx TS1 with txpreset=sta_lec_pset_ltx and reject=0
//     ELSE IF (PHY respond is illegal :  : phy_mac_reject_ltx=1)
//       -> Use txpreset=0x4 / Tx TS1 with txpreset=sta_lec_pset_ltx and reject=1
// ELSE
//  -> Use txpreset=0x4 / Tx TS1 with txpreset=0x4 and reject=0

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        sta_lec_pset_ltx_valid <= #TP 1'b0;
    end else begin
        if( !upstream_component && eqctl_8eqts2_rcvd_pulse && ltssm_state_rcvrcfg )
            sta_lec_pset_ltx_valid <= #TP 1'b1;
        else if( ltssm_current_data_rate_g12_pulse )
            sta_lec_pset_ltx_valid <= #TP 1'b0;
    end
end

assign load_sta_lec_g4_pset_g12 = ltssm_current_data_rate_g12 && ((ltssm_state_pollactive && eqctl_8eqts1_rcvd_pulse) || (ltssm_state_cfglwstart && eqctl_2eqts1_rcvd_pulse));
wire [4:0] smlh_ts_data_rate = smlh_ts_info[29:25]; // [7:0]symbol1 [15:8]symbol2 [23:16]symbol3 [31:24]symbol4->[4:1]data_rate
// in gen6 rate the [7:0]symbol1 [15:8]symbol2 [23:16]symbol3 [31:24]symbol4 [39:32]symbol5->[4:1]data_rate
// in ~gen6 rate the [7:0]symbol1 [15:8]symbol2 [23:16]symbol3 [31:24]symbol4->[4:1]data_rate
wire [9:0] smlh_ts_data_rate_eg6 = ltssm_current_data_rate_g6 ? (smlh_ts_info[37:33] == 5'b10111 ? 10'b0000111111 : {5'h0,smlh_ts_info[37:33]}) : (smlh_ts_info[29:25] == 5'b10111 ? 10'b0000111111 : {5'h0,smlh_ts_info[29:25]}); // [7:0]symbol1 [15:8]symbol2 [23:16]symbol3 [31:24]symbol4->[4:1]data_rate
assign load_sta_lec_g4_pset_g3 = ltssm_current_data_rate_g3 && eqctl_8g4eqts2_rcvd_pulse && ltssm_state_rcvrcfg && ltssm_ts_data_rate_eg6[3] && smlh_ts_data_rate_eg6[3];

always @(posedge core_clk or negedge core_rst_n) begin : sta_lec_g4_pset_ltx_lrx_seq_PROC
    if( !core_rst_n ) begin
        sta_lec_g4_pset_ltx <= #TP `DEFAULT_LOCAL_G4_TX_PRESET;
        sta_lec_g4_pset_lrx <= #TP {RX_PSET_WD{1'b1}};
    end else begin
        if ( load_sta_lec_g4_pset_g12 ) begin
            sta_lec_g4_pset_ltx <= #TP rxts[6:3];
            sta_lec_g4_pset_lrx <= #TP rxts[2:0];
        end else if ( load_sta_lec_g4_pset_g3 ) begin
            sta_lec_g4_pset_ltx <= #TP rxts[14:11]; // symbol7[6:3]
            sta_lec_g4_pset_lrx <= #TP rxts[10:8]; // symbol7[2:0]
        end
    end
end

    assign load_sta_lec_g5_pset_g12      = ltssm_current_data_rate_g12 && ((ltssm_state_pollactive && eqctl_8eqts1_rcvd_pulse) || (ltssm_state_cfglwstart && eqctl_2eqts1_rcvd_pulse) || (eqctl_8eqts2_rcvd_pulse_i && ltssm_state_rcvrcfg & ltssm_cmd_eqts_gen12[1] & (ltssm_captured_ts_data_rate_g5 || ltssm_captured_ts_data_rate_g6)));
// rx eq ts2s at gen1/2 rate for gen5 eq preset because of bypass_eq used for dsp
assign load_sta_lec_g5_pset_g12_rcfg = ltssm_current_data_rate_g12 && (eqctl_8eqts2_rcvd_pulse && ltssm_state_rcvrcfg & ltssm_cmd_eqts_gen12[1]);
//assign load_sta_lec_g5_pset_g3 = ltssm_current_data_rate_g3 && eqctl_8g4eqts2_rcvd_pulse && ltssm_state_rcvrcfg && ltssm_ts_data_rate[3] && smlh_ts_data_rate[3];
assign load_sta_lec_g5_pset_g4 = ltssm_current_data_rate_g4 && eqctl_8g5eqts2_rcvd_pulse && ltssm_state_rcvrcfg && ltssm_ts_data_rate[4] && smlh_ts_data_rate[4]; // gates: must revisit later, using Sym7[6:3] for now

always @(posedge core_clk or negedge core_rst_n) begin : sta_lec_g5_pset_ltx_lrx_seq_PROC
    if( !core_rst_n ) begin
        sta_lec_g5_pset_ltx <= #TP `DEFAULT_LOCAL_G5_TX_PRESET;
        sta_lec_g5_pset_lrx <= #TP {RX_PSET_WD{1'b1}};
    end else begin
//        if ( ltssm_clear && ltssm_state_rcvrcfg ) begin // when entry to Rcvry.RcvrCfg
//            sta_lec_g5_pset_ltx <= #TP `DEFAULT_LOCAL_G5_TX_PRESET;
//            sta_lec_g5_pset_lrx <= #TP {RX_PSET_WD{1'b1}};
//        end else
        if ( load_sta_lec_g5_pset_g12 ) begin
            sta_lec_g5_pset_ltx <= #TP rxts[6:3];
            sta_lec_g5_pset_lrx <= #TP rxts[2:0];
//        end else if ( load_sta_lec_g5_pset_g3 ) begin
//            sta_lec_g5_pset_ltx <= #TP rxts[14:11]; // symbol7[6:3]
//            sta_lec_g5_pset_lrx <= #TP rxts[10:8]; // symbol7[2:0]
        end else if ( load_sta_lec_g5_pset_g4 ) begin // gates: must revisit later, using Sym7[6:3] for now
            sta_lec_g5_pset_ltx <= #TP rxts[14:11]; // symbol7[6:3]
            sta_lec_g5_pset_lrx <= #TP rxts[10:8]; // symbol7[2:0]
        end
    end
end
assign load_sta_lec_g6_pset_g12      = ltssm_current_data_rate_g12 && ((ltssm_state_pollactive && eqctl_8eqts1_rcvd_pulse) || (ltssm_state_cfglwstart && eqctl_2eqts1_rcvd_pulse) || (eqctl_8eqts2_rcvd_pulse_i && ltssm_state_rcvrcfg & ltssm_cmd_eqts_gen12[1] & ltssm_captured_ts_data_rate_g6));
// rx eq ts2s at gen1/2 rate for gen5 eq preset because of bypass_eq used for dsp
assign load_sta_lec_g6_pset_g12_rcfg = ltssm_current_data_rate_g12 && (eqctl_8eqts2_rcvd_pulse && ltssm_state_rcvrcfg & ltssm_cmd_eqts_gen12[1]);
//assign load_sta_lec_g5_pset_g3 = ltssm_current_data_rate_g3 && eqctl_8g4eqts2_rcvd_pulse && ltssm_state_rcvrcfg && ltssm_ts_data_rate[3] && smlh_ts_data_rate[3];
assign load_sta_lec_g6_pset_g5 = ltssm_current_data_rate_g5 && eqctl_8g6eqts2_rcvd_pulse && ltssm_state_rcvrcfg && ltssm_ts_data_rate_eg6[5] && smlh_ts_data_rate_eg6[5]; // gates: must revisit later, using Sym7[6:3] for now

always @(posedge core_clk or negedge core_rst_n) begin : sta_lec_g6_pset_ltx_lrx_seq_PROC
    if( !core_rst_n ) begin
        sta_lec_g6_pset_ltx <= #TP `DEFAULT_LOCAL_G6_TX_PRESET;
        sta_lec_g6_pset_lrx <= #TP {RX_PSET_WD{1'b1}};
    end else begin
//        if ( ltssm_clear && ltssm_state_rcvrcfg ) begin // when entry to Rcvry.RcvrCfg
//            sta_lec_g5_pset_ltx <= #TP `DEFAULT_LOCAL_G5_TX_PRESET;
//            sta_lec_g5_pset_lrx <= #TP {RX_PSET_WD{1'b1}};
//        end else
        if ( load_sta_lec_g6_pset_g12 ) begin
            sta_lec_g6_pset_ltx <= #TP rxts[6:3];
            sta_lec_g6_pset_lrx <= #TP rxts[2:0];
//        end else if ( load_sta_lec_g5_pset_g3 ) begin
//            sta_lec_g5_pset_ltx <= #TP rxts[14:11]; // symbol7[6:3]
//            sta_lec_g5_pset_lrx <= #TP rxts[10:8]; // symbol7[2:0]
        end else if ( load_sta_lec_g6_pset_g5 ) begin // gates: must revisit later, using Sym7[6:3] for now
            sta_lec_g6_pset_ltx <= #TP rxts[14:11]; // symbol7[6:3]
            sta_lec_g6_pset_lrx <= #TP rxts[10:8]; // symbol7[2:0]
        end
    end
end

// ## Selecting Tx Preset Value in Gen4 for Upstream Component ##
// IF (Received 8GT EQ TS2 and Supported)
//  -> Use sta_lec_g4_pset_ltx(received Tx Preset) for both LTX and TXTS1(reject=0)
// ELSE IF (Tx Preset in Config Register is supported)
//  -> Use cfg_lec_g4_pset_ltx(Tx Preset in Config Register) for both LTX and TXTS1(reject=0)
// ELSE
//  -> Use 0x4 for both LTX and TXTS1(reject=0)
//
// ## Selecting Tx Preset Value in Gen4 for Downstream Component ##
// IF (Received 8GT EQ TS2)
//  -> Use sta_lec_g4_pset_ltx
//     IF (PHY respond is legal : phy_mac_reject_ltx=0)
//       -> Use the value / Tx TS1 with txpreset=sta_lec_g4_pset_ltx and reject=0
//     ELSE IF (PHY respond is illegal :  : phy_mac_reject_ltx=1)
//       -> Use txpreset=0x4 / Tx TS1 with txpreset=sta_lec_g4_pset_ltx and reject=1
// ELSE
//  -> Use txpreset=0x4 / Tx TS1 with txpreset=0x4 and reject=0

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        sta_lec_g4_pset_ltx_valid <= #TP 1'b0;
    end else if( upstream_component ) begin
      if( ltssm_clear && ltssm_state_rcvrcfg )
          sta_lec_g4_pset_ltx_valid <= #TP 1'b0;
      else if( load_sta_lec_g4_pset_g3 &&
               ( ( ~mac_phy_txswing && (rxts[14:11] <= 4'hA) ) || // Full Swing
                 ( mac_phy_txswing && (rxts[14:11] == 4'h1) ) || // Low Swing
                 ( mac_phy_txswing && (rxts[14:11] == 4'h3) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h4) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h5) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h6) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h9) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'hA) ) ) )
          sta_lec_g4_pset_ltx_valid <= #TP 1'b1;
    end else begin // !upstream_component
      if( ltssm_current_data_rate_g3_pulse )
          sta_lec_g4_pset_ltx_valid <= #TP 1'b0;
      else if( load_sta_lec_g4_pset_g3 )
          sta_lec_g4_pset_ltx_valid <= #TP 1'b1;
    end
end

// gates: must revisit later
// load_sta_lec_g5_pset_g12_rcfg for dsp, the usp is covered by sta_lec_pset_ltx_valid for gen12 rate eq ts2s received
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        sta_lec_g5_pset_ltx_valid <= #TP 1'b0;
    end else if( upstream_component ) begin
      if( ltssm_clear && ltssm_state_rcvrcfg )
          sta_lec_g5_pset_ltx_valid <= #TP 1'b0;
      else if( load_sta_lec_g5_pset_g4 &&
               ( ( ~mac_phy_txswing && (rxts[14:11] <= 4'hA) ) || // Full Swing
                 ( mac_phy_txswing && (rxts[14:11] == 4'h1) ) || // Low Swing
                 ( mac_phy_txswing && (rxts[14:11] == 4'h3) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h4) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h5) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h6) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'h9) ) ||
                 ( mac_phy_txswing && (rxts[14:11] == 4'hA) ) ) )
          sta_lec_g5_pset_ltx_valid <= #TP 1'b1;
      else if ( load_sta_lec_g5_pset_g12_rcfg &&
               ( ( ~mac_phy_txswing && (rxts[6:3] <= 4'hA) ) || // Full Swing
                 ( mac_phy_txswing && (rxts[6:3] == 4'h1) ) || // Low Swing
                 ( mac_phy_txswing && (rxts[6:3] == 4'h3) ) ||
                 ( mac_phy_txswing && (rxts[6:3] == 4'h4) ) ||
                 ( mac_phy_txswing && (rxts[6:3] == 4'h5) ) ||
                 ( mac_phy_txswing && (rxts[6:3] == 4'h6) ) ||
                 ( mac_phy_txswing && (rxts[6:3] == 4'h9) ) ||
                 ( mac_phy_txswing && (rxts[6:3] == 4'hA) ) ) )
          sta_lec_g5_pset_ltx_valid <= #TP 1'b1;
    end else begin // !upstream_component
      if( ltssm_current_data_rate_g4_pulse )
          sta_lec_g5_pset_ltx_valid <= #TP 1'b0;
      else if( load_sta_lec_g5_pset_g4 )
          sta_lec_g5_pset_ltx_valid <= #TP 1'b1;
    end
end

// jd6 gates: must revisit later
// load_sta_lec_g6_pset_g12_rcfg for dsp, the usp is covered by sta_lec_pset_ltx_valid for gen12 rate eq ts2s received
// gen6 eq is always from gen5 rate, not from gen1/2/3/4
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        sta_lec_g6_pset_ltx_valid <= #TP 1'b0;
    end else if( upstream_component ) begin
      if( ltssm_clear && ltssm_state_rcvrcfg )
          sta_lec_g6_pset_ltx_valid <= #TP 1'b0;
      else if( load_sta_lec_g6_pset_g5 &&
               ( ( ~mac_phy_txswing && (rxts[14:11] <= 4'hA) ) || // Full Swing
                 ( mac_phy_txswing && (rxts[14:11] <= 4'h4) ) /*|| // Low Swing, v0.71, July2021
                 ( mac_phy_txswing && (rxts[14:11] == 4'hA) )*/ ) ) // Q10 is not in the reduced swing list on 22Sep2021. 178084
          sta_lec_g6_pset_ltx_valid <= #TP 1'b1;
/*
  `ifdef CX_DSP_RXEQ_FOR_GEN5
      else if ( load_sta_lec_g6_pset_g12_rcfg &&
               ( ( ~mac_phy_txswing && (rxts[6:3] <= 4'hA) ) || // Full Swing
                 ( mac_phy_txswing && (rxts[6:3] <= 4'h4) ) || // Low Swing, v0.71, July2021
                 ( mac_phy_txswing && (rxts[6:3] == 4'hA) ) ) )
          sta_lec_g6_pset_ltx_valid <= #TP 1'b1;
  `endif // CX_DSP_RXEQ_FOR_GEN5
*/
    end else begin // !upstream_component
      if( ltssm_current_data_rate_g5_pulse )
          sta_lec_g6_pset_ltx_valid <= #TP 1'b0;
      else if( load_sta_lec_g6_pset_g5 )
          sta_lec_g6_pset_ltx_valid <= #TP 1'b1;
    end
end


assign sta_lec_pset_ltx_valid_cmn = sta_lec_pset_ltx_valid || sta_lec_g4_pset_ltx_valid || sta_lec_g5_pset_ltx_valid || sta_lec_g6_pset_ltx_valid;

/*html_start
<p><b>load_int_phy_mac_fslf_ltx</b><br>
Positive edge detection on int_phy_mac_fslf_ltx_valid. 
The initial {coefficients + FS LF} calculated by the PHY are advertized in txTS transmitted during Phase 0 (DC) and Phase 1.
html_end*/
always @(posedge core_clk or negedge core_rst_n) begin : int_phy_mac_fslf_ltx_valid_d_seq_PROC
    if( !core_rst_n ) begin
        int_phy_mac_fslf_ltx_valid_d <= #TP '0;
    end else begin
        int_phy_mac_fslf_ltx_valid_d <= #TP int_phy_mac_fslf_ltx_valid;
    end
end

assign load_int_phy_mac_fslf_ltx = (int_phy_mac_fslf_ltx_valid & ~int_phy_mac_fslf_ltx_valid_d);

/*html_start
<p><b>mac_phy_use_pset</b><br>
Status register used to tell the PHY to use mac_phy_pset_ltx preset (instead of mac_phy_coef_ltx coefficients) to transmit.
Asserted when first entering G3 data rate. Deasserted outside phase 0|1.
html_end*/
/*html_start
<p><b>mac_phy_pset_ltx/mac_phy_coef_ltx</b><br>
Data register used to present to the PHY preset and coefficients to be use to transmit at G3 rate.
Presets are loaded initially when first entering G3 data rate using cfg bits (UC) or values captured from received eqTS2 @G12 (DC).
Presets/coefficients are loaded subsequently in phase 2|3 with values captured from received ecTS1 @G3 during fine tuning as a slave.
html_end*/

assign load_mac_phy_pset_ltx_init_g3 = ( (ltssm_current_data_rate_g3_pulse && (ltssm_start_equalization[0] || ltssm_state_compliance || ltssm_state_lpbkentry)) || // initial change to G3 with equalization not performed or in Compliance or in Loopback.Entry
                                         (ltssm_current_data_rate_g3 && (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ?
                                          ltssm_cmd_send_eieos_for_pset_map : (|ltssm_state_equalization_enter[1:0]))) ) && // any time equalization Phase 0 or 1 are re-entered.
                                       !(load_mac_phy_pset_ltx_new && ltssm_state_lpbkentry); // Exclusive of load_mac_phy_pset_ltx_new in Loopback.Entry

assign load_mac_phy_pset_ltx_init_g4 = ( (ltssm_current_data_rate_g4_pulse && (ltssm_start_equalization[0] || ltssm_state_compliance || ltssm_state_lpbkentry)) || // initial change to G4 with equalization not performed or in Compliance or in Loopback.Entry
                                         (ltssm_current_data_rate_g4 && (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ?
                                          ltssm_cmd_send_eieos_for_pset_map : (|ltssm_state_equalization_enter[1:0]))) ) && // any time equalization Phase 0 or 1 are re-entered.
                                       !(load_mac_phy_pset_ltx_new && ltssm_state_lpbkentry); // Exclusive of load_mac_phy_pset_ltx_new in Loopback.Entry

assign load_mac_phy_pset_ltx_init_g5 = ( (ltssm_current_data_rate_g5_pulse && (ltssm_start_equalization[0] || ltssm_state_compliance || ltssm_state_lpbkentry)) || // initial change to G5 with equalization not performed or in Compliance or in Loopback.Entry
                                         (ltssm_current_data_rate_g5 && (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ?
                                          ltssm_cmd_send_eieos_for_pset_map : (|ltssm_state_equalization_enter[1:0] && !ltssm_perform_eq_for_lpbk))) ) && // any time equalization Phase 0 or 1 are re-entered.
                                       !(load_mac_phy_pset_ltx_new && ltssm_state_lpbkentry); // Exclusive of load_mac_phy_pset_ltx_new in Loopback.Entry
assign load_mac_phy_pset_ltx_init_g6 = ( (ltssm_current_data_rate_g6_pulse && (ltssm_start_equalization[0] || ltssm_state_compliance || ltssm_state_lpbkentry)) || // initial change to G5 with equalization not performed or in Compliance or in Loopback.Entry
                                         (ltssm_current_data_rate_g6 && (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ?
                                          ltssm_cmd_send_eieos_for_pset_map : (|ltssm_state_equalization_enter[1:0] && !ltssm_perform_eq_for_lpbk))) ) && // any time equalization Phase 0 or 1 are re-entered.
                                       !(load_mac_phy_pset_ltx_new && ltssm_state_lpbkentry); // Exclusive of load_mac_phy_pset_ltx_new in Loopback.Entry

assign load_mac_phy_pset_ltx_new = eqctl_2ects1_rcvd_pulse_ftune_ltx &&                               // a change in rxts detected by slave
                                   rxts[7] &&                                                         // this is a preset request
                                   ((rxts[6:3] != mac_phy_pset_ltx) || !mac_phy_pset_ltx_was_last);   // requested value is different from previous request 
                                                                                                      // Note: the check on the value is needed to prevent creating a false update when the rst_eiec field is 
                                                                                                      //       the only field changed in rxts  (caused by the master intending to performing evaluation)
                                                                                                      // Note: the check on mac_phy_pset_ltx_was_last is needed to ensure an update is created when same presets
                                                                                                      //       are requested again following a coefficient request

assign load_mac_phy_coef_ltx_init = load_int_phy_mac_fslf_ltx && !(load_mac_phy_coef_ltx_new && ltssm_state_lpbkentry); // initial coefficients calculated together with FS LF. Exclusive of load_mac_phy_coef_ltx_new in Loopback.Entry

assign load_mac_phy_coef_ltx_new = eqctl_2ects1_rcvd_pulse_ftune_ltx &&                               // a change in rxts detected by slave
                                   !rxts[7] &&                                                        // this is a coefficient request
                                   ((( g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} != mac_phy_coef_ltx[0 +: 6]  : rxts[8 +: 6]  != mac_phy_coef_ltx[0 +: 6]) || // {C-1[2:0], C-2[2:0]} for gen6
                                     ( g6_rate ? {rxts[ 8 +: 5], rxts[19]}      != mac_phy_coef_ltx[6 +: 6]  : rxts[16 +: 6] != mac_phy_coef_ltx[6 +: 6]) || // {C0[4:0], C-1[3]} for gen6
                                     ( g6_rate ? {rxts[24 +: 5], rxts[13]}      != mac_phy_coef_ltx[12 +: 6] : rxts[24 +: 6] != mac_phy_coef_ltx[12 +: 6])) || mac_phy_pset_ltx_was_last); // requested value is different from previous request - same considerations as above on why we need this check
                                                        // for gen6  {C+1[4:0], C0[5]}
// force the upstream port's initial tx preset value for gen3
assign int_sta_lec_pset_ltx    = (cdm_ras_des_eq_force_pset_ltx_en)? cdm_ras_des_eq_force_usp_pset_ltx    : sta_lec_pset_ltx ;
// force the upstream port's initial tx preset value for gen4
assign int_sta_lec_g4_pset_ltx = (cdm_ras_des_eq_force_pset_ltx_en_g4)? cdm_ras_des_eq_force_usp_pset_ltx_g4 : sta_lec_g4_pset_ltx ;
// force the upstream port's initial tx preset value for gen5
assign int_sta_lec_g5_pset_ltx = (cdm_ras_des_eq_force_pset_ltx_en_g5)? cdm_ras_des_eq_force_usp_pset_ltx_g5 : sta_lec_g5_pset_ltx ; // gates: must revisit later
// force the upstream port's initial tx preset value for gen6
assign int_sta_lec_g6_pset_ltx = (cdm_ras_des_eq_force_pset_ltx_en_g6)? cdm_ras_des_eq_force_usp_pset_ltx_g6 : sta_lec_g6_pset_ltx ;

always @( posedge core_clk or negedge core_rst_n ) begin : previous_rate_PROC
    if ( ~core_rst_n )
        previous_rate <= #TP 3'b000;
    else if ( ltssm_current_data_rate_g3_pulse )
        previous_rate <= #TP 3'b001;
    else if ( ltssm_current_data_rate_g4_pulse )
        previous_rate <= #TP 3'b010;
    else if ( ltssm_current_data_rate_g5_pulse )
        previous_rate <= #TP 3'b100;
    else if ( ltssm_current_data_rate_g6_pulse )
        previous_rate <= #TP 3'b101;
    else if ( ltssm_current_data_rate_g12 ) // clear at gen1/2 rate because the eq redo is not from equal or higher rate if redoing eq
        previous_rate <= #TP 3'b000;
end // previous_rate_PROC

// for gen6 TS1 Sym2[5:0] = C0  = rxts[ 8 +: 6] = coef[12:7]  = coef[7 +: 6]
//              Sym3[3:0] = C-1 = rxts[16 +: 4] = coef[ 6:3]  = coef[3 +: 4]
//              Sym3[6:4] = C-2 = rxts[20 +: 3] = coef[ 2:0]  = coef[0 +: 3]
//              Sym4[4:0] = C+1 = rxts[24 +: 5] = coef[17:13] = coef[13 +: 5]
//
//     so       Sym3[6:0] = {C-2, C-1}      = rxts[16 +: 7] = {coef[ 2:0], coef[ 6:3]}
//              Sym3[5:0] = {C-2[1:0], C-1} = rxts[16 +: 6] = {coef[ 1:0], coef[ 6:3]}
//              Sym3[6]   = C-2[2]          = rxts[22]      = coef[2]
always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_pset_coef_ltx_seq_PROC
    if( !core_rst_n ) begin
        mac_phy_pset_ltx          <= #TP '0;
        mac_phy_pset_lrx          <= #TP '0;
        mac_phy_coef_ltx          <= #TP '0;
        mac_phy_use_pset          <= #TP '0;
        mac_phy_pset_ltx_upd      <= #TP '0;
        mac_phy_coef_ltx_upd      <= #TP '0;
        mac_phy_pset_ltx_was_last <= #TP 1'b0;
    end else begin
        // no eq needed (ltssm_noeq_nd) is handled by software to set the bit after Hot Reset or any other mechnisms to not do eq again at the corresponding rates
        // if previous_rate[2:0] is equal or higher than the current eq rate for eq redo to the rate, restore the previous preset
        if( load_mac_phy_pset_ltx_init_g3 ) begin
            mac_phy_pset_ltx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? ltssm_gen3_compliance_tx_pset : int_sta_lec_pset_ltx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_pset_ltx : int_sta_lec_pset_ltx) :
                                upstream_component ? cfg_lec_pset_ltx : int_sta_lec_pset_ltx;
            //gates: use LaneEqControl register as Rx preset cfg_lec_pset_lrx when entering Compliance due to EnterCompliance bit set or thru Cycle
            //gates: use LaneEqControl register as Rx preset cfg_lec_pset_lrx when entering Loopback from Cfg.LinkWidth.Start
            mac_phy_pset_lrx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? cfg_lec_pset_lrx : sta_lec_pset_lrx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_pset_lrx : sta_lec_pset_lrx) :
                                upstream_component ? cfg_lec_pset_lrx : sta_lec_pset_lrx;
            mac_phy_use_pset <= #TP 1'b1;
        end
        if( load_mac_phy_pset_ltx_init_g4 ) begin
            mac_phy_pset_ltx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? ltssm_gen3_compliance_tx_pset : int_sta_lec_g4_pset_ltx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_g4_pset_ltx : int_sta_lec_g4_pset_ltx) :
                                upstream_component ? ( sta_lec_g4_pset_ltx_valid ? int_sta_lec_g4_pset_ltx : cfg_lec_g4_pset_ltx ) : int_sta_lec_g4_pset_ltx;
            //gates: use LaneEqControl register as Rx preset cfg_lec_g4_pset_lrx when entering Compliance due to EnterCompliance bit set or thru Cycle
            //gates: use LaneEqControl register as Rx preset cfg_lec_g4_pset_lrx when entering Loopback from Cfg.LinkWidth.Start
            mac_phy_pset_lrx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? cfg_lec_g4_pset_lrx : sta_lec_g4_pset_lrx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_g4_pset_lrx : sta_lec_g4_pset_lrx) :
                                upstream_component ? cfg_lec_g4_pset_lrx : sta_lec_g4_pset_lrx;
            mac_phy_use_pset <= #TP 1'b1;
        end
        if( load_mac_phy_pset_ltx_init_g5 ) begin
            mac_phy_pset_ltx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? ltssm_gen3_compliance_tx_pset : int_sta_lec_g5_pset_ltx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_g5_pset_ltx : int_sta_lec_g5_pset_ltx) :
                                upstream_component ? ( sta_lec_g5_pset_ltx_valid ? int_sta_lec_g5_pset_ltx : cfg_lec_g5_pset_ltx ) : int_sta_lec_g5_pset_ltx;
            //gates: use LaneEqControl register as Rx preset cfg_lec_g4_pset_lrx when entering Compliance due to EnterCompliance bit set or thru Cycle
            //gates: use LaneEqControl register as Rx preset cfg_lec_g4_pset_lrx when entering Loopback from Cfg.LinkWidth.Start
            mac_phy_pset_lrx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? cfg_lec_g5_pset_lrx : sta_lec_g5_pset_lrx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_g5_pset_lrx : sta_lec_g5_pset_lrx) :
                                upstream_component ? cfg_lec_g5_pset_lrx : sta_lec_g5_pset_lrx;
            mac_phy_use_pset <= #TP 1'b1;
        end
        if( load_mac_phy_pset_ltx_init_g6 ) begin
            mac_phy_pset_ltx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? ltssm_gen3_compliance_tx_pset : int_sta_lec_g6_pset_ltx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_g6_pset_ltx : int_sta_lec_g6_pset_ltx) :
                                upstream_component ? ( sta_lec_g6_pset_ltx_valid ? int_sta_lec_g6_pset_ltx : cfg_lec_g6_pset_ltx ) : int_sta_lec_g6_pset_ltx;
            //gates: use LaneEqControl register as Rx preset cfg_lec_g4_pset_lrx when entering Compliance due to EnterCompliance bit set or thru Cycle
            //gates: use LaneEqControl register as Rx preset cfg_lec_g4_pset_lrx when entering Loopback from Cfg.LinkWidth.Start
            mac_phy_pset_lrx <= #TP ltssm_state_compliance ? (ltssm_gen3_compliance_tx_pset_v ? cfg_lec_g6_pset_lrx : sta_lec_g6_pset_lrx) :
                                ltssm_state_lpbkentry ? (ltssm_lpbk_master ? cfg_lec_g6_pset_lrx : sta_lec_g6_pset_lrx) :
                                upstream_component ? cfg_lec_g6_pset_lrx : sta_lec_g6_pset_lrx;
            mac_phy_use_pset <= #TP 1'b1;
        end
        if( load_mac_phy_coef_ltx_init ) begin
            mac_phy_coef_ltx[17:0] <= #TP int_phy_mac_coef_ltx[17:0];
        end
        //ltssm_current_data_rate_g12 for compliance as poll_compliance won't be through EQ phases.
        //eqctl_2ects1_rcvd_pulse_lpbk_slave for loopback slave as loopback won't be through EQ phases.
        //mac_phy_use_pset get reset to 0 so that it has a rising edge whenever enter Gen3 rate in poll_compliance.
        //mac_phy_use_pset is deasserted for loopback slave so that mac_phy_pset_ltx_upd or mac_phy_coef_ltx_upd cannot be masked by mac_phy_use_pset in smlh_eqpa.v.
        //for mac_phy_getlocal_pset_coef to create a pulse in smlh_eqpa.v.
        //Then map preset to coefficients by PHY and feed the coefficients back to MAC.
        if(ltssm_state_equalization_exit[1] || ltssm_current_data_rate_g12 || eqctl_2ects1_rcvd_pulse_lpbk_slave || (ltssm_state_equalization_exit[0] && ltssm_state_rcvrspd) || (ltssm_clear & ltssm_state_rcvrspd)) begin
            mac_phy_use_pset <= #TP 1'b0;
        end
        if( load_mac_phy_pset_ltx_new || eqctl_2ects1_rcvd_pulse_lpbk_slave_pset ) begin
            mac_phy_pset_ltx <= #TP rxts[6:3];
            mac_phy_pset_ltx_upd <= #TP 1'b1;
            mac_phy_pset_ltx_was_last <= #TP 1'b1;
        end
// for gen6 TS1 Sym2[5:0] = C0  = rxts[ 8 +: 6] = coef[12:7]  = coef[7 +: 6]
//              Sym3[3:0] = C-1 = rxts[16 +: 4] = coef[ 6:3]  = coef[3 +: 4]
//              Sym3[6:4] = C-2 = rxts[20 +: 3] = coef[ 2:0]  = coef[0 +: 3]
//              Sym4[4:0] = C+1 = rxts[24 +: 5] = coef[17:13] = coef[13 +: 5]
//
//     so       Sym3[6:0] = {C-2, C-1}      = rxts[16 +: 7] = {coef[ 2:0], coef[ 6:3]}
//              Sym3[5:0] = {C-2[1:0], C-1} = rxts[16 +: 6] = {coef[ 1:0], coef[ 6:3]}
//              Sym3[6]   = C-2[2]          = rxts[22]      = coef[2]
        if( load_mac_phy_coef_ltx_new || eqctl_2ects1_rcvd_pulse_lpbk_slave_coef ) begin
            mac_phy_coef_ltx[17:12]   <= #TP g6_rate ? {rxts[24 +: 5], rxts[13]}      : rxts[24 +: 6];  // Sym9
            mac_phy_coef_ltx[11:6]    <= #TP g6_rate ? {rxts[ 8 +: 5], rxts[19]}      : rxts[16 +: 6];   // Sym8
            mac_phy_coef_ltx[5:0]     <= #TP g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} : rxts[8 +: 6];     // Sym7
            mac_phy_coef_ltx_upd      <= #TP 1'b1;
            mac_phy_pset_ltx_was_last <= #TP 1'b0;
        end
        //int_phy_mac_accept_ltx or int_phy_mac_reject_ltx high may be at the same cycle of eqctl_2ects1_rcvd_pulse_lpbk_slave high.
        //don't de-assert mac_phy_pset_ltx_upd/mac_phy_coef_ltx_upd if eqctl_2ects1_rcvd_pulse_lpbk_slave high
        if ((int_phy_mac_accept_ltx || int_phy_mac_reject_ltx) && !eqctl_2ects1_rcvd_pulse_lpbk_slave) begin
            mac_phy_pset_ltx_upd <= #TP 1'b0;
            mac_phy_coef_ltx_upd <= #TP 1'b0;
        end
    end
end


/*html_start
<p><b>mac_phy_fslf/pset/coef_rtx/mac_phy_fslf_rtx_valid/mac_phy_pset_rtx_was_last</b><br>
Data register used to latch FSLF, presets from received ec1TS1 in Phase 0 (DC) or Phase 1 (UC). 
Used to latch presets, coefficients from received ec2|3TS1 in Phase 2 (DC) or Phase 3 (UC) when a request is accepted.
FSLF are passed to the PHY and are used by the PHY as constraints for issuing valid new requests when fine tuning the remote transmitter as a master. 
Presets latched on Phase 0 (DC) or Phase 1 (UC) are used as default values to be requested when initially entering Phase 2 (DC) or Phase 3 (UC).  
Presets/Coefficients latched on Phase 2 (DC) or Phase 3 (UC) are used to store the last settings agreed upon on equalization and to 
check in RcvrLock that the remote transmitter is using them after equalization is finshed.
The mac_phy_pset_rtx_was_last flag is used to record whether the last setting agreed upon was a preset or a coefficient setting. 
Valid FSLF flag is reset outside of equalization states.
html_end*/

//assign load_mac_phy_fslf_rtx = eqctl_2ects1_rcvd_pulse[1] && (upstream_component ? ltssm_state_equalization[1] : ltssm_state_equalization[0]);
assign load_mac_phy_fslf_rtx = eqctl_2ects1_rcvd[1] && (upstream_component ? ltssm_state_equalization[1] : ltssm_state_equalization[0]);

// upstream_component: DSP receives 2 TS1s with EC=11b, record the preset/coefficients for using as initial pset/coef when entering EQ3 as eq master
// ~upstream_component: USP receives 2 TS1s with EC=10b, record the preset/coefficients for using as initial pset/coef when entering EQ2 as eq master
// load_mac_phy_pset_coef_rtx_init is a pulse when entering EQ master phase (DSP eq3 and USP eq2)
always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_pset_rtx_init_PROC
    if ( ~core_rst_n ) begin
        mac_phy_pset_rtx_init <= #TP 0;
        mac_phy_coef_rtx_init <= #TP 0;
    end else if ( upstream_component && eqctl_2ects1_rcvd_pulse[3] ) begin
        mac_phy_pset_rtx_init <= #TP g6_rate ? mac_phy_pset_rtx_init : rxts[6:3];
        mac_phy_coef_rtx_init[17:12] <= #TP g6_rate ? {rxts[24 +: 5], rxts[13]}      : rxts[24 +: 6];
        mac_phy_coef_rtx_init[11:6]  <= #TP g6_rate ? {rxts[ 8 +: 5], rxts[19]}      : rxts[16 +: 6];
        mac_phy_coef_rtx_init[5:0]   <= #TP g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} : rxts[8 +: 6];
    end else if ( ~upstream_component && eqctl_2ects1_rcvd_pulse[2] ) begin
        mac_phy_pset_rtx_init <= #TP g6_rate ? mac_phy_pset_rtx_init : rxts[6:3];
        mac_phy_coef_rtx_init[17:12] <= #TP g6_rate ? {rxts[24 +: 5], rxts[13]}      : rxts[24 +: 6];
        mac_phy_coef_rtx_init[11:6]  <= #TP g6_rate ? {rxts[ 8 +: 5], rxts[19]}      : rxts[16 +: 6];
        mac_phy_coef_rtx_init[5:0]   <= #TP g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} : rxts[8 +: 6];
    end
//    else if ( ((upstream_component && eqctl_2ects1_rcvd_pulse[0]) || (~upstream_component && eqctl_2ects1_rcvd_pulse[1])) && g6_rate ) begin
    else if ( load_mac_phy_fslf_rtx && g6_rate ) begin
        mac_phy_pset_rtx_init <= #TP rxts[6:3];
    end
end // mac_phy_pset_rtx_init_PROC

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_fslf_pset_coef_rtx_seq_PROC
    if( !core_rst_n ) begin
        mac_phy_fslf_rtx          <= #TP '0;
        mac_phy_fslf_rtx_valid    <= #TP 1'b0;
        mac_phy_pset_rtx          <= #TP '0;
        mac_phy_coef_rtx          <= #TP '0;
        mac_phy_pset_rtx_was_last <= #TP 1'b1;
    end else begin
        if( !ltssm_state_equalization_any ) begin
            mac_phy_fslf_rtx_valid    <= #TP 1'b0;
        end else if( load_mac_phy_fslf_rtx ) begin //rcvd 2 EC1 TS1 including FS, LF and Post Cursor (no Pre and Main Cursor)
            mac_phy_fslf_rtx[11:6]    <= #TP rxts[16+:6];
            mac_phy_fslf_rtx[5:0]     <= #TP rxts[8+:6];
            mac_phy_fslf_rtx_valid    <= #TP 1'b1;
            mac_phy_pset_rtx          <= #TP rxts[6:3];
            mac_phy_pset_rtx_was_last <= #TP 1'b1;
        end else if( load_mac_phy_coef_rtx ) begin
            mac_phy_coef_rtx[17:12]   <= #TP g6_rate ? {rxts[24 +: 5], rxts[13]}      : rxts[24 +: 6];
            mac_phy_coef_rtx[11:6]    <= #TP g6_rate ? {rxts[ 8 +: 5], rxts[19]}      : rxts[16 +: 6];
            mac_phy_coef_rtx[5:0]     <= #TP g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} : rxts[8 +: 6];
            mac_phy_pset_rtx_was_last <= #TP 1'b0;
        end else if( load_mac_phy_pset_rtx ) begin
            mac_phy_pset_rtx          <= #TP rxts[6:3];
            mac_phy_pset_rtx_was_last <= #TP 1'b1;
            mac_phy_coef_rtx[17:12]   <= #TP g6_rate ? {rxts[24 +: 5], rxts[13]}      : rxts[24 +: 6];
            mac_phy_coef_rtx[11:6]    <= #TP g6_rate ? {rxts[ 8 +: 5], rxts[19]}      : rxts[16 +: 6];
            mac_phy_coef_rtx[5:0]     <= #TP g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} : rxts[8 +: 6];
        // initialize mac_phy_pset/coef_rtx regs with the values used by the slave on entering fine tuning as a master.
        // if preset request match, latch preset as well as coefficoents because the remote partner (slave) reflects the preset and coefficient fields of the TS1
        // Ordered Set that the Link partner transmits.
        end else if( load_mac_phy_pset_coef_rtx_init ) begin
            // use mac_phy_pset_rtx_init/mac_phy_coef_rtx_init (not rxts) because at load_mac_phy_pset_coef_rtx_init = 1 pulse, rxts may be cleared to 0 if the pulse clock cycle TS has error symbols
            mac_phy_pset_rtx          <= #TP mac_phy_pset_rtx_init;
            mac_phy_pset_rtx_was_last <= #TP 1'b1;
            mac_phy_coef_rtx[17:12]   <= #TP mac_phy_coef_rtx_init[17:12];
            mac_phy_coef_rtx[11:6]    <= #TP mac_phy_coef_rtx_init[11:6];
            mac_phy_coef_rtx[5:0]     <= #TP mac_phy_coef_rtx_init[5:0];
        end
    end
end

always @( posedge core_clk or negedge core_rst_n ) begin: mac_phy_pset_coef_stored_rtx_PROC
    if ( ~core_rst_n ) begin
        mac_phy_pset_g3_stored_rtx   <= #TP '0;
        mac_phy_coef_g3_stored_rtx   <= #TP '0;
        mac_phy_pset_rtx_was_last_g3 <= #TP '0;
        mac_phy_pset_g4_stored_rtx   <= #TP '0;
        mac_phy_coef_g4_stored_rtx   <= #TP '0;
        mac_phy_pset_rtx_was_last_g4 <= #TP '0;
        mac_phy_pset_g5_stored_rtx   <= #TP '0;
        mac_phy_coef_g5_stored_rtx   <= #TP '0;
        mac_phy_pset_rtx_was_last_g5 <= #TP '0;
        mac_phy_pset_g6_stored_rtx   <= #TP '0;
        mac_phy_coef_g6_stored_rtx   <= #TP '0;
        mac_phy_pset_rtx_was_last_g6 <= #TP '0;
    end else begin
        if ( ltssm_current_data_rate_g3 ) begin
            mac_phy_pset_g3_stored_rtx   <= #TP mac_phy_pset_rtx;
            mac_phy_coef_g3_stored_rtx   <= #TP mac_phy_coef_rtx;
            mac_phy_pset_rtx_was_last_g3 <= #TP mac_phy_pset_rtx_was_last;
        end // gen3 rate
        if ( ltssm_current_data_rate_g4 ) begin
            mac_phy_pset_g4_stored_rtx   <= #TP mac_phy_pset_rtx;
            mac_phy_coef_g4_stored_rtx   <= #TP mac_phy_coef_rtx;
            mac_phy_pset_rtx_was_last_g4 <= #TP mac_phy_pset_rtx_was_last;
        end // gen4 rate
        if ( ltssm_current_data_rate_g5 ) begin
            mac_phy_pset_g5_stored_rtx   <= #TP mac_phy_pset_rtx;
            mac_phy_coef_g5_stored_rtx   <= #TP mac_phy_coef_rtx;
            mac_phy_pset_rtx_was_last_g5 <= #TP mac_phy_pset_rtx_was_last;
        end // gen5 rate
        if ( ltssm_current_data_rate_g6 ) begin
            mac_phy_pset_g6_stored_rtx   <= #TP mac_phy_pset_rtx;
            mac_phy_coef_g6_stored_rtx   <= #TP mac_phy_coef_rtx;
            mac_phy_pset_rtx_was_last_g6 <= #TP mac_phy_pset_rtx_was_last;
        end // gen5 rate
    end
end // mac_phy_pset_coef_stored_rtx_PROC

assign mac_phy_pset_stored_rtx          = ltssm_current_data_rate_g6 ? mac_phy_pset_g6_stored_rtx   :
 ltssm_current_data_rate_g5 ? mac_phy_pset_g5_stored_rtx   : ltssm_current_data_rate_g4 ? mac_phy_pset_g4_stored_rtx   : mac_phy_pset_g3_stored_rtx;
assign mac_phy_coef_stored_rtx          = ltssm_current_data_rate_g6 ? mac_phy_coef_g6_stored_rtx   :
 ltssm_current_data_rate_g5 ? mac_phy_coef_g5_stored_rtx   : ltssm_current_data_rate_g4 ? mac_phy_coef_g4_stored_rtx   : mac_phy_coef_g3_stored_rtx;
assign mac_phy_pset_stored_rtx_was_last = ltssm_current_data_rate_g6 ? mac_phy_pset_rtx_was_last_g6 :
 ltssm_current_data_rate_g5 ? mac_phy_pset_rtx_was_last_g5 : ltssm_current_data_rate_g4 ? mac_phy_pset_rtx_was_last_g4 : mac_phy_pset_rtx_was_last_g3;

/*html_start
<p><b>load_int_phy_mac_pset/coef_rtx</b><br>
Positive edge detection on int_phy_mac_pset/coef_rtx_upd. 
The requested preset/coefficients are inserted in txTS transmitted during Phase 2 (DC) and Phase 3 (UC).
html_end*/
always @(posedge core_clk or negedge core_rst_n) begin : int_phy_mac_pset_coef_rtx_upd_d_seq_PROC
    if( !core_rst_n ) begin
        int_phy_mac_pset_rtx_upd_d <= #TP '0;
        int_phy_mac_coef_rtx_upd_d <= #TP '0;
    end else begin
        int_phy_mac_pset_rtx_upd_d <= #TP int_phy_mac_pset_rtx_upd;
        int_phy_mac_coef_rtx_upd_d <= #TP int_phy_mac_coef_rtx_upd;
    end
end

assign load_int_phy_mac_pset_rtx = (int_phy_mac_pset_rtx_upd & ~int_phy_mac_pset_rtx_upd_d);
assign load_int_phy_mac_coef_rtx = (int_phy_mac_coef_rtx_upd & ~int_phy_mac_coef_rtx_upd_d);


/*html_start
<p><b>mac_phy_ftune_rtx</b><br>
Fine tuning as a master of remote transmitter. Phase 2 (DC) or Phase 3 (UC).
html_end*/
assign int_mac_phy_ftune_rtx = upstream_component ? ltssm_state_equalization[3] : ltssm_state_equalization[2];

/*html_start
<p><b>mac_phy_ftune_ltx</b><br>
Fine tuning as a slave of local transmitter. Phase 2 (UC) or Phase 3 (DC).
html_end*/
assign int_mac_phy_ftune_ltx = upstream_component ? ltssm_state_equalization[2] : ltssm_state_equalization[3];

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_ftune_ltx_rtx_seq_PROC
    if( !core_rst_n ) begin
        mac_phy_ftune_ltx <= #TP '0;
        mac_phy_ftune_rtx <= #TP '0;
    end else begin
        mac_phy_ftune_ltx <= #TP int_mac_phy_ftune_ltx;
        mac_phy_ftune_rtx <= #TP int_mac_phy_ftune_rtx;
    end
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// txts
// If EQ done before and regain Gen3 rate at Loopback, should send EC2/3 to Slave from Master. No EC0/1 sent out
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// For Gen6, almost Equalization Byte in TS0 is Reserved in Loopback state.
// Therefore, TS content should be loaded at the timing that LTSSM enters EQ phase0 when EQ for loopback is performed.
assign load_txts_pset_coef_ltx = !(sta_ls2_eq_phase23_success && ltssm_lpbk_master) && (upstream_component ? 1'b0 : load_int_phy_mac_fslf_ltx || (g6_rate && ltssm_perform_eq_for_lpbk && ltssm_state_equalization_enter[0]) ); // load TS content for Phase 0
assign load_txts_pset_fslf_ltx = !(sta_ls2_eq_phase23_success && ltssm_lpbk_master) && (upstream_component ? (cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ?
                                           ltssm_state_equalization_enter[1] : load_int_phy_mac_fslf_ltx) : ltssm_state_equalization_enter[1]); // load TS content for Phase 1

reg  eqctl_2g6eqts0_rcvd_w_fslf, eqctl_2g6eqts0_rcvd_w_fslf_r;
wire eqctl_2g6eqts0_rcvd_fe;
always @( posedge core_clk or negedge core_rst_n ) begin : eqctl_2g6eqts0_rcvd_w_fslf_PROC
    if ( ~core_rst_n )
        eqctl_2g6eqts0_rcvd_w_fslf <= #TP '0;
    else if ( ~ltssm_state_equalization[1] || (~eqctl_2g6eqts0_rcvd) )
        eqctl_2g6eqts0_rcvd_w_fslf <= #TP '0;
    // if eqctl_2g6eqts0_rcvd = 1 meets int_phy_mac_fslf_ltx_valid
    else if ( eqctl_2g6eqts0_rcvd && int_phy_mac_fslf_ltx_valid )
        eqctl_2g6eqts0_rcvd_w_fslf <= #TP 1'b1;
end // eqctl_2g6eqts0_rcvd_w_fslf_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : eqctl_2g6eqts0_rcvd_w_fslf_r_PROC
    if ( ~core_rst_n )
        eqctl_2g6eqts0_rcvd_w_fslf_r <= #TP '0;
    else
        eqctl_2g6eqts0_rcvd_w_fslf_r <= #TP eqctl_2g6eqts0_rcvd_w_fslf;
end // eqctl_2g6eqts0_rcvd_w_fslf_r_PROC

assign eqctl_2g6eqts0_rcvd_fe = ~eqctl_2g6eqts0_rcvd_w_fslf & eqctl_2g6eqts0_rcvd_w_fslf_r;

// ensure mac_phy_pset/coef_rtx registers are updated before being used for loading txts
always @(posedge core_clk or negedge core_rst_n) begin : load_txts_pset_coef_rtx_init_seq_PROC
    if( !core_rst_n ) begin
        load_txts_pset_coef_rtx_init <= #TP '0;
    end else begin
        load_txts_pset_coef_rtx_init <= #TP load_mac_phy_pset_coef_rtx_init;
    end
end
assign load_txts_pset_rtx           = load_int_phy_mac_pset_rtx;
assign load_txts_coef_rtx           = load_int_phy_mac_coef_rtx;

assign load_txts_ec2_ec3 = int_mac_phy_ftune_ltx & ~mac_phy_ftune_ltx; // for updating EC bits when moving to Phase 2 (UC) and Phase 3 (DC)

/*html_start
<p><b>mac_phy_accept/reject_rtx</b><br>
Matching logic to check that rxTS responses match txTS requests. When there is a match assert the match_accept/reject flag, depending on rxTS content.
Positive edge detection on match_accept/reject, used to drive the one cycle pulse to the PHY and terminate the update request.
html_end*/

assign rxts_pset_match =
                         (txts_g3[7] == 1'b1) &&
                         (txts_g3[6:3] == rxts[6:3]) &&
                         (txts_g3[6:3] == int_phy_mac_pset_rtx) &&
                         (upstream_component ? (txts_g3[1:0] == 2'b11) : (txts_g3[1:0] == 2'b10)) && int_mac_phy_ftune_rtx;
// C-2: 3 bits, C-1: 4 bits, C0: 6 bits, C+1: 5 bits
// for gen6 the 1b Sym1 -> 130b Sym6 -> txts_g3[ 7:0]
//                 Sym2 ->      Sym7 -> txts_g3[15:8]
//                 Sym3 ->      Sym8 -> txts_g3[23:16]
//                 Sym4 ->      Sym9 -> txts_g3[31:24]
// for gen6 the coef[17:0] = {C+1, C0, C-1, C-2} = {coef[17:13], coef[12:7], coef[6:3], coef[2:0]}.
//
// for gen6 TS1 Sym2[5:0] = C0  = txts_g3[ 8 +: 6] = coef[12:7]  = coef[7 +: 6]
//              Sym3[3:0] = C-1 = txts_g3[16 +: 4] = coef[ 6:3]  = coef[3 +: 4]
//              Sym3[6:4] = C-2 = txts_g3[20 +: 3] = coef[ 2:0]  = coef[0 +: 3]
//              Sym4[4:0] = C+1 = txts_g3[24 +: 5] = coef[17:13] = coef[13 +: 5]
//
//     so       Sym3[6:0] = {C-2, C-1}      = txts_g3[16 +: 7] = {coef[ 2:0], coef[ 6:3]}
//              Sym3[5:0] = {C-2[1:0], C-1} = txts_g3[16 +: 6] = {coef[ 1:0], coef[ 6:3]}
//              Sym3[6]   = C-2[2]          = txts_g3[22]      = coef[2]

assign rxts_coef_match = 
                         (txts_g3[7] == 1'b0) && (
                        g6_rate ?
                        (
                         (txts_g3[8 +: 6] == rxts[8 +: 6]) && (txts_g3[16 +: 6]  == rxts[16 +: 6]) && (txts_g3[24 +: 6] == rxts[24 +: 6]) &&
                         (txts_g3[ 8 +: 6] == int_phy_mac_coef_rtx[ 7 +: 6]) && (txts_g3[16 +: 6] == {int_phy_mac_coef_rtx[0 +: 2], int_phy_mac_coef_rtx[3 +: 4]}) &&
                         (txts_g3[24 +: 5] == int_phy_mac_coef_rtx[13 +: 5]) && (txts_g3[22]      == int_phy_mac_coef_rtx[2])
                        ) :
                        (
                         (txts_g3[8 +: 6] == rxts[8 +: 6]) && (txts_g3[16 +: 6] == rxts[16 +: 6]) && (txts_g3[24 +: 6] == rxts[24 +: 6]) &&
                         (txts_g3[8 +: 6] == int_phy_mac_coef_rtx[0 +: 6]) && (txts_g3[16 +: 6] == int_phy_mac_coef_rtx[6 +: 6]) && (txts_g3[24 +: 6] == int_phy_mac_coef_rtx[12 +: 6])
                        )
                                                 ) &&
                         (upstream_component ? (txts_g3[1:0] == 2'b11) : (txts_g3[1:0] == 2'b10)) && int_mac_phy_ftune_rtx;
assign rxts_txts_pset_match_accept = rxts_pset_match && !rxts_reject && eqctl_2ects1_rcvd_ftune_rtx && int_phy_mac_pset_rtx_upd && int_eqpa_timeout_1us_after_request ;
assign rxts_txts_pset_match_reject = rxts_pset_match && rxts_reject && eqctl_2ects1_rcvd_ftune_rtx && int_phy_mac_pset_rtx_upd && int_eqpa_timeout_1us_after_request ;
assign rxts_txts_coef_match_accept = rxts_coef_match && !rxts_reject && eqctl_2ects1_rcvd_ftune_rtx && int_phy_mac_coef_rtx_upd && int_eqpa_timeout_1us_after_request ;
assign rxts_txts_coef_match_reject = rxts_coef_match && rxts_reject && eqctl_2ects1_rcvd_ftune_rtx && int_phy_mac_coef_rtx_upd && int_eqpa_timeout_1us_after_request ;
assign rxts_txts_match_accept = rxts_txts_pset_match_accept | rxts_txts_coef_match_accept;
assign rxts_txts_match_reject = rxts_txts_pset_match_reject | rxts_txts_coef_match_reject;

always @(posedge core_clk or negedge core_rst_n) begin : rxts_txts_match_d_seq_PROC
    if( !core_rst_n ) begin
        rxts_txts_match_accept_d <= #TP '0;
        rxts_txts_match_reject_d <= #TP '0;
    end else begin
        rxts_txts_match_accept_d <= #TP rxts_txts_match_accept;
        rxts_txts_match_reject_d <= #TP rxts_txts_match_reject;
    end
end

assign int_mac_phy_accept_rtx = mac_phy_timeout_rtx ? 1'b0 : (rxts_txts_match_accept & ~rxts_txts_match_accept_d);
assign int_mac_phy_reject_rtx = mac_phy_timeout_rtx ? 1'b0 : (rxts_txts_match_reject & ~rxts_txts_match_reject_d);

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_accept_reject_rtx_seq_PROC
    if( !core_rst_n ) begin
        mac_phy_accept_rtx <= #TP '0;
        mac_phy_reject_rtx <= #TP '0;
    end else begin
        mac_phy_accept_rtx <= #TP int_mac_phy_accept_rtx;
        mac_phy_reject_rtx <= #TP int_mac_phy_reject_rtx;
    end
end

assign load_mac_phy_pset_coef_rtx_init = upstream_component ? ltssm_state_equalization_enter[3] : ltssm_state_equalization_enter[2];
assign load_mac_phy_pset_rtx = int_mac_phy_accept_rtx & rxts_pset_match; // Store accepted pset as Master, spec v0.9_0706
assign load_mac_phy_coef_rtx = int_mac_phy_accept_rtx & rxts_coef_match; // Store accepted coef as Master, spec v0.9_0706

assign load_txts_rst_eiec_rtx   = int_mac_phy_accept_rtx | int_mac_phy_reject_rtx; // If reject by remote, re-evaluation, need reset_eieos too

assign load_txts_pset_accept_ltx  = int_phy_mac_accept_ltx & mac_phy_pset_ltx_upd & int_mac_phy_ftune_ltx;
assign load_txts_pset_reject_ltx  = int_phy_mac_reject_ltx & mac_phy_pset_ltx_upd & int_mac_phy_ftune_ltx;
assign load_txts_coef_accept_ltx  = int_phy_mac_accept_ltx & mac_phy_coef_ltx_upd & int_mac_phy_ftune_ltx;
assign load_txts_coef_reject_ltx  = int_phy_mac_reject_ltx & mac_phy_coef_ltx_upd & int_mac_phy_ftune_ltx;

wire g345_rate_change_pulse_d;
wire g345_rate_change_pulse = ltssm_state_rcvrspd && ( ltssm_current_data_rate_g3_pulse || ltssm_current_data_rate_g4_pulse || ltssm_current_data_rate_g5_pulse || ltssm_current_data_rate_g6_pulse); // entering gen3/gen4

delay_n_w_enable
 #(N_DELAY_CYLES, 1) u_delay_1
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (enable4delay),
    .din        (g345_rate_change_pulse),
    .dout       (g345_rate_change_pulse_d)
);

assign load_txts_default = ltssm_state_equalization_any_exit && (ltssm_current_data_rate_g3 || ltssm_current_data_rate_g4 || ltssm_current_data_rate_g5 || ltssm_current_data_rate_g6) // exit from equalization states at G3
                        || g345_rate_change_pulse_d // entering gen3/gen4
                           ;

// Generate a load pulse for txts_g3 for Loopback_Master at Gen3 rate rising edge, Send it at Gen3 rate.
// If move to Loopback with Gen3 rate, no touch.
// If before Loopback the EQ has done successfully for Phase 2/3 and then the Link goes down to Gen1/2 rate, when the Link moves to Loopback,
// both sides go to Gen3 rate again, in this case the Loopback_Master has to send EC2/3 TS1s to Slave at Gen3 rate.
// at ltssm_current_data_rate_g3/4/5_pulse the sta_ls2_eq_phase23_success updates
assign load_txts_pset_coef_rtx_lpbk_master = (ltssm_current_data_rate_g3_pulse || ltssm_current_data_rate_g4_pulse || ltssm_current_data_rate_g5_pulse
 || ltssm_current_data_rate_g6_pulse) && sta_ls2_eq_phase23_success && ltssm_lpbk_master;

// phy_mac_pset_ltx: store last accepted preset requested to the PHY.
// It is updated during phase_2 for DSP and phase_3 for USP.
// It is used when entry to Recovery.RcvrLock following Equalization
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen3 ;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen4 ;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen3_r;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen4_r;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen5 ;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen5_r;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen6 ;
reg [TX_PSET_WD-1:0] phy_mac_pset_ltx_gen6_r;

always @(*) begin : phy_mac_pset_ltx_seq_PROC
    phy_mac_pset_ltx = ltssm_current_data_rate_g6 ? phy_mac_pset_ltx_gen6 :
 ltssm_current_data_rate_g5 ? phy_mac_pset_ltx_gen5 : !ltssm_current_data_rate_g4 ? phy_mac_pset_ltx_gen3 : phy_mac_pset_ltx_gen4;
end

always @* begin : phy_mac_pset_ltx_com_gen34_PROC
    phy_mac_pset_ltx_gen3 = phy_mac_pset_ltx_gen3_r;
    phy_mac_pset_ltx_gen4 = phy_mac_pset_ltx_gen4_r;
    phy_mac_pset_ltx_gen5 = phy_mac_pset_ltx_gen5_r;
    phy_mac_pset_ltx_gen6 = phy_mac_pset_ltx_gen6_r;

    //default equalization preset, DEFAULT_EQ_PSET = 4'b0100 = P4 if initial preset is invalid. gen6 = Q0
    //This reflects mapped coefficients mac_phy_txdeemph <= #TP {6'd0, phy_mac_fs, 6'd0} in smlh_eqpa.v.
    if ( mac_phy_use_pset && int_phy_mac_reject_ltx ) begin
        phy_mac_pset_ltx_gen3 =  !ltssm_current_data_rate_g4 && !ltssm_current_data_rate_g5 && !ltssm_current_data_rate_g6 ?  `DEFAULT_EQ_PSET : phy_mac_pset_ltx_gen3_r ;
        phy_mac_pset_ltx_gen4 =  ltssm_current_data_rate_g4 ? `DEFAULT_EQ_PSET : phy_mac_pset_ltx_gen4_r ;
        phy_mac_pset_ltx_gen5 =  ltssm_current_data_rate_g5 ? `DEFAULT_EQ_PSET : phy_mac_pset_ltx_gen5_r ;
        phy_mac_pset_ltx_gen6 =  ltssm_current_data_rate_g6 ? `DEFAULT_G6_EQ_PSET : phy_mac_pset_ltx_gen6_r ;
    end else if ( load_txts_pset_accept_ltx || (mac_phy_use_pset && int_phy_mac_accept_ltx) ) begin
        phy_mac_pset_ltx_gen3 =  !ltssm_current_data_rate_g4 && !ltssm_current_data_rate_g5 && !ltssm_current_data_rate_g6 ? mac_phy_pset_ltx : phy_mac_pset_ltx_gen3_r ;
        phy_mac_pset_ltx_gen4 =  ltssm_current_data_rate_g4 ? mac_phy_pset_ltx : phy_mac_pset_ltx_gen4_r ;
        phy_mac_pset_ltx_gen5 =  ltssm_current_data_rate_g5 ? mac_phy_pset_ltx : phy_mac_pset_ltx_gen5_r ;
        phy_mac_pset_ltx_gen6 =  ltssm_current_data_rate_g6 ? mac_phy_pset_ltx : phy_mac_pset_ltx_gen6_r ;
    end
end // phy_mac_pset_ltx_com_gen34_PROC

always @(posedge core_clk or negedge core_rst_n) begin : phy_mac_pset_ltx_seq_gen34_PROC
    if( !core_rst_n ) begin
        phy_mac_pset_ltx_gen3_r <= #TP '0;
        phy_mac_pset_ltx_gen4_r <= #TP '0;
        phy_mac_pset_ltx_gen5_r <= #TP '0;
        phy_mac_pset_ltx_gen6_r <= #TP '0;
    end else begin
        phy_mac_pset_ltx_gen3_r <= #TP phy_mac_pset_ltx_gen3;
        phy_mac_pset_ltx_gen4_r <= #TP phy_mac_pset_ltx_gen4;
        phy_mac_pset_ltx_gen5_r <= #TP phy_mac_pset_ltx_gen5;
        phy_mac_pset_ltx_gen6_r <= #TP phy_mac_pset_ltx_gen6;
    end
end



// Prepare the content of symbols 6-9 in transmitted TS Ordered Sets @G3. Does not include the parity bit which is inserted later
// txts_g3[31:24] - symbol 9
// txts_g3[23:16] - symbol 8
// txts_g3[15:8] - symbol 7
// txts_g3[7:0] - symbol 6
// C-2: 3 bits, C-1: 4 bits, C0: 6 bits, C+1: 5 bits
// for gen6 the 1b Sym1 -> 130b Sym6 -> txts_g3[ 7:0]
//                 Sym2 ->      Sym7 -> txts_g3[15:8]
//                 Sym3 ->      Sym8 -> txts_g3[23:16]
//                 Sym4 ->      Sym9 -> txts_g3[31:24]
// for gen6 the coef[17:0] = {C+1, C0, C-1, C-2} = {coef[17:13], coef[12:7], coef[6:3], coef[2:0]}.
//
// for gen6 TS1 Sym2[5:0] = C0  = txts_g3[ 8 +: 6] = coef[12:7]  = coef[7 +: 6]
//              Sym3[3:0] = C-1 = txts_g3[16 +: 4] = coef[ 6:3]  = coef[3 +: 4]
//              Sym3[6:4] = C-2 = txts_g3[20 +: 3] = coef[ 2:0]  = coef[0 +: 3]
//              Sym4[4:0] = C+1 = txts_g3[24 +: 5] = coef[17:13] = coef[13 +: 5]
//
//     so       Sym3[6:0] = {C-2, C-1}      = txts_g3[16 +: 7] = {coef[ 2:0], coef[ 6:3]}
//              Sym3[5:0] = {C-2[1:0], C-1} = txts_g3[16 +: 6] = {coef[ 1:0], coef[ 6:3]}
//              Sym3[6]   = C-2[2]          = txts_g3[22]      = coef[2]
always @(posedge core_clk or negedge core_rst_n) begin : txts_g3_seq_PROC
    if( !core_rst_n ) begin
        txts_g3 <= #TP '0;
    end else begin
        if( load_txts_pset_coef_rtx_lpbk_master ) begin // fine tuning as a Loopback Master - request the coefficients or presets from last equalization procedure
            txts_g3[30]      <= #TP '0; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, mac_phy_coef_stored_rtx[13 +: 5]} : mac_phy_coef_stored_rtx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? mac_phy_coef_stored_rtx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP g6_rate ? {mac_phy_coef_stored_rtx[0 +: 2], mac_phy_coef_stored_rtx[3 +: 4]} : mac_phy_coef_stored_rtx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? mac_phy_coef_stored_rtx[7 +: 6] : mac_phy_coef_stored_rtx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP mac_phy_pset_stored_rtx_was_last; // USE_PSET Note: when master enters fine tuning it can request pset or coefficients
            txts_g3[6:3]     <= #TP mac_phy_pset_stored_rtx; // PSET_TX
            txts_g3[2]       <= #TP 0; // RST_EIEC
            txts_g3[1:0]     <= #TP upstream_component ? 2'b11 : 2'b10; // EC
        end else if( load_txts_pset_coef_ltx ) begin // Phase 0 (DC) or Phase 1 (DC) when re-entering / or Loopback Slave or Polling.Compliance
            txts_g3[30]      <= #TP !ltssm_state_equalization[1] && !ltssm_state_compliance && !ltssm_state_lpbkentry && ( sta_lec_pset_ltx_valid_cmn && phy_mac_reject_ltx ) ? 1'b1 : 1'b0; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, int_phy_mac_coef_ltx[13 +: 5]} : int_phy_mac_coef_ltx[12 +: 6]; // C(+1), C+1 for g6
            txts_g3[22]      <= #TP g6_rate ? int_phy_mac_coef_ltx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP ltssm_state_equalization[1] || g6_rate ? int_phy_mac_fslf_ltx[6 +: 6] : int_phy_mac_coef_ltx[6 +: 6]; // LF or C(0),  {C-2, C-1} for g6
            txts_g3[8 +: 6]  <= #TP ltssm_state_equalization[1] || g6_rate ? int_phy_mac_fslf_ltx[0 +: 6] :  int_phy_mac_coef_ltx[0 +: 6]; // FS or C(-1), C0 for gen6
            txts_g3[7]       <= #TP '0; // USE_PSET
            txts_g3[6:3]     <= #TP !ltssm_state_equalization[1] && !ltssm_state_compliance && !ltssm_state_lpbkentry && !sta_lec_pset_ltx_valid_cmn ? phy_mac_pset_ltx : mac_phy_pset_ltx; // PSET_TX
            txts_g3[2]       <= #TP '0; // RST_EIEC
            txts_g3[1:0]     <= #TP ltssm_state_equalization[1] ? 2'b01 : 2'b00; // EC
        // if load_txts_pset_fslf_ltx pulse is within eqctl_2g6eqts0_rcvd level signal, use eqctl_2g6eqts0_rcvd_fe falling edge pulse. Else (load_txts_pset_fslf_ltx outside eqctl_2g6eqts0_rcvd), use load_txts_pset_fslf_ltx pulse
        end else if( load_txts_pset_fslf_ltx || eqctl_2g6eqts0_rcvd_fe ) begin // Phase 1. eqctl_2g6eqts0_rcvd_fe is (eqctl_2g6eqts0_rcvd & load_txts_pset_fslf_ltx) falling edge
            txts_g3[30]      <= #TP '0; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, int_phy_mac_coef_ltx[13 +: 5]} : int_phy_mac_coef_ltx[12 +: 6]; // C(+1)
            txts_g3[16 +: 6] <= #TP int_phy_mac_fslf_ltx[6 +: 6]; // LF
            txts_g3[8 +: 6]  <= #TP  int_phy_mac_fslf_ltx[0 +: 6]; // FS
            txts_g3[7]       <= #TP '0; // USE_PSET
            txts_g3[6:3]     <= #TP upstream_component ? ((sta_lec_pset_ltx_valid_cmn || !phy_mac_reject_ltx) ? mac_phy_pset_ltx : ( ltssm_current_data_rate_g6 ? `DEFAULT_G6_EQ_PSET :  `DEFAULT_EQ_PSET)) : txts_g3[6:3]; // PSET_TX
            txts_g3[2]       <= #TP '0; // RST_EIEC
            txts_g3[1:0]     <= #TP 2'b01; // EC
        end else if( load_txts_pset_coef_rtx_init ) begin // fine tuning as a master - default preset request, beginning of Phase 2 (DC) or Phase 3 (UC), ahead of any adjustment request, by default request the presets latched in Phase 1
            txts_g3[30]      <= #TP '0; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, mac_phy_coef_rtx[13 +: 5]} : mac_phy_coef_rtx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? mac_phy_coef_rtx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP g6_rate ? {mac_phy_coef_rtx[0 +: 2], mac_phy_coef_rtx[3 +: 4]} : mac_phy_coef_rtx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? mac_phy_coef_rtx[7 +: 6] : mac_phy_coef_rtx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP 1; // USE_PSET Note: when master enters fine tuning it can request pset or coefficients, we always request pset
            txts_g3[6:3]     <= #TP mac_phy_pset_rtx; // PSET_TX
            txts_g3[2]       <= #TP req_rst_eiec_enable; // RST_EIEC
            txts_g3[1:0]     <= #TP upstream_component ? 2'b11 : 2'b10; // EC
        end else if( load_txts_pset_rtx ) begin // fine tuning as a master - preset request, Phase 2 (DC) or Phase 3 (UC)
            txts_g3[7]       <= #TP 1; // USE_PSET
            txts_g3[6:3]     <= #TP int_phy_mac_pset_rtx; // PSET_TX
//            if ( load_txts_rst_eiec_rtx ) begin // when the request is immediately accepted because received TS1s already match, need to configure the RST EIEC bit
//                txts_g3[2] <= #TP req_rst_eiec_enable; // RST_EIEC
//            end else begin
                txts_g3[2]   <= #TP '0; // RST_EIEC
//            end
        end else if( load_txts_coef_rtx ) begin // fine tuning as a master - coefficient request, Phase 2 (DC) or Phase 3 (UC)
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, int_phy_mac_coef_rtx[13 +: 5]} : int_phy_mac_coef_rtx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? int_phy_mac_coef_rtx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP g6_rate ? {int_phy_mac_coef_rtx[0 +: 2], int_phy_mac_coef_rtx[3 +: 4]} : int_phy_mac_coef_rtx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? int_phy_mac_coef_rtx[7 +: 6] : int_phy_mac_coef_rtx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP '0; // USE_PSET
//            if ( load_txts_rst_eiec_rtx ) begin // when the request is immediately accepted because received TS1s already match, need to configure the RST EIEC bit
//                txts_g3[2] <= #TP req_rst_eiec_enable; // RST_EIEC
//            end else begin
                txts_g3[2]   <= #TP '0; // RST_EIEC
//            end
        end else if( load_txts_rst_eiec_rtx ) begin // fine tuning as a master - request to reset EIE count - perform evaluation without EIEOS, Phase 2 (DC) or Phase 3 (UC)
            txts_g3[2]       <= #TP req_rst_eiec_enable; // RST_EIEC
        end else if( load_txts_ec2_ec3 ) begin // fine tuning as a slave - update EC bits when UC enters Phase 2 (needed to direct DC to Phase 2) or when DC enters Phase 3 (needed to direct UC to Phase 3)
            txts_g3[30]      <= #TP '0; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, mac_phy_coef_ltx[13 +: 5]} : mac_phy_coef_ltx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? mac_phy_coef_ltx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP g6_rate ? {mac_phy_coef_ltx[0 +: 2], mac_phy_coef_ltx[3 +: 4]} : mac_phy_coef_ltx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? mac_phy_coef_ltx[7 +: 6] : mac_phy_coef_ltx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP 1; // USE_PSET Note: when slave enters fine tuning it can only indicates that pset are in use because fine tuning has not happened yet
            txts_g3[6:3]     <= #TP phy_mac_pset_ltx; // PSET_TX
            txts_g3[2]       <= #TP '0; // RST_EIEC
            txts_g3[1:0]     <= #TP upstream_component ? 2'b10 : 2'b11; // EC
        end else if( load_txts_pset_accept_ltx || load_txts_pset_reject_ltx) begin // fine tuning as a slave - respond to a pset request, Phase 3 (DC) or Phase 2 (UC)
            txts_g3[30]      <= #TP g6_rate ? 1'b0 : load_txts_pset_reject_ltx; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, int_phy_mac_coef_ltx[13 +: 5]} : int_phy_mac_coef_ltx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? int_phy_mac_coef_ltx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[23]      <= #TP g6_rate ? load_txts_pset_reject_ltx : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP g6_rate ? {int_phy_mac_coef_ltx[0 +: 2], int_phy_mac_coef_ltx[3 +: 4]} : int_phy_mac_coef_ltx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? int_phy_mac_coef_ltx[7 +: 6] : int_phy_mac_coef_ltx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP 1; // USE_PSET
            txts_g3[6:3]     <= #TP mac_phy_pset_ltx; // PSET_TX
            txts_g3[2]       <= #TP '0; // RST_EIEC
            txts_g3[1:0]     <= #TP upstream_component ? 2'b10 : 2'b11; // EC
        end else if( load_txts_coef_accept_ltx || load_txts_coef_reject_ltx) begin // fine tuning as a slave - respond to a coef request, Phase 3 (DC) or Phase 2 (UC)
            txts_g3[30]      <= #TP g6_rate ? 1'b0 : load_txts_coef_reject_ltx; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, mac_phy_coef_ltx[13 +: 5]} : mac_phy_coef_ltx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? mac_phy_coef_ltx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[23]      <= #TP g6_rate ? load_txts_coef_reject_ltx : 1'b0; // bit22 is C-2[2]
            txts_g3[16 +: 6] <= #TP g6_rate ? {mac_phy_coef_ltx[0 +: 2], mac_phy_coef_ltx[3 +: 4]} : mac_phy_coef_ltx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? mac_phy_coef_ltx[7 +: 6] : mac_phy_coef_ltx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP '0; // USE_PSET
            txts_g3[6:3]     <= #TP phy_mac_pset_ltx; // PSET_TX
            txts_g3[2]       <= #TP '0; // RST_EIEC
            txts_g3[1:0]     <= #TP upstream_component ? 2'b10 : 2'b11; // EC
        end else if( load_txts_default ) begin // exiting equalization phases
            txts_g3[30]      <= #TP '0; // REJ
            txts_g3[24 +: 6] <= #TP g6_rate ? {1'b0, int_phy_mac_coef_ltx[13 +: 5]} : int_phy_mac_coef_ltx[12 +: 6]; // C(+1)
            txts_g3[22]      <= #TP g6_rate ? int_phy_mac_coef_ltx[2] : 1'b0; // bit22 is C-2[2]
            txts_g3[23]      <= #TP 1'b0; // reset to 0 after exiting EQ
            txts_g3[16 +: 6] <= #TP g6_rate ? {int_phy_mac_coef_ltx[0 +: 2], int_phy_mac_coef_ltx[3 +: 4]} : int_phy_mac_coef_ltx[6 +: 6]; // C(0)
            txts_g3[8 +: 6]  <= #TP g6_rate ? int_phy_mac_coef_ltx[7 +: 6] : int_phy_mac_coef_ltx[0 +: 6]; // C(-1)
            txts_g3[7]       <= #TP '0; // USE_PSET
            txts_g3[6:3]     <= #TP phy_mac_pset_ltx; // PSET_TX
            txts_g3[2]       <= #TP '0; // RST_EIEC
            txts_g3[1:0]     <= #TP 2'b00; // EC
        end else begin
           txts_g3           <= #TP txts_g3;
        end

        if ( int_eqpa_wait_rei_state ) // to prevent stuck in S_WAIT_REI state if local invalid coefficients and need re-evaluation and new coefficients from PHY
            txts_g3[2] <= #TP req_rst_eiec_enable; // S_WAIT_REI -> S_EVAL. if all lanes RX EIEOS = 1, move from S_WAIT_REI -> S_EVAL
        else
        if ( ~req_rst_eiec_enable && int_mac_phy_ftune_rtx ) begin // don't set RST_EIEC bit if the lane's rxvalid is 0 (no block alignment gained)
            txts_g3[2] <= #TP 0; // RST_EIEC
        end // if ( ~req_rst_eiec_enable

        if ( fom_gen34_eq_phase23_rxeq_regardless_rxts ) begin // if do evaluation/adaptation regardless of Rx TS1s only for FOM
            if ( req_rst_eiec_enable )
                txts_g3[2] <= #TP 1; // if any lanes have RxEqEval=1, set REI bit dynamically
            else
                txts_g3[2] <= #TP '0; // dynamically reset to 0
        end // if ( fom_gen34_eq_phase23_rxeq_regardless_rxts

        // eqctl_2g6eqts0_rcvd: dsp in eq1 initially sends ec=00b until receiving 2 ts0s with retimer_eq_extend bit = 0b, then sends ec=01b.
        // ltssm_dsp_g6_eq1_send_ec00:  when gen6 dsp wants to move from eq1 to R.Lock, send 24 ts0s with EC=00b after receiving 2 ts0s with ec=01b.
        if ( eqctl_2g6eqts0_rcvd || ltssm_dsp_g6_eq1_send_ec00 ) txts_g3[1:0] <= #TP 2'b00;

        if ( ltssm_state_lpbkentry && g6_rate ) begin // the following bits are reserved in Loopback.Entry state for 1b/1b encoding
            txts_g3[7:2]     <= #TP 6'h0;
            txts_g3[8  +: 8] <= #TP 8'h0;
            txts_g3[16 +: 8] <= #TP 8'h0;
            txts_g3[24 +: 7] <= #TP 7'h0;
        end // if ( ltssm_state_lpbkentry

        if ( ~int_mac_phy_ftune_rtx ) // if not in eq master phase, must reset REI bit to 0
            txts_g3[2] <= #TP '0; // RST_EIEC
    end
end

assign eqctl_ftune_rtx_done = int_phy_mac_ftune_rtx_done & int_mac_phy_ftune_rtx;

wire [1:0] int_txts_eq_req_data_rate; //gen5: 01b, gen4: 10b, gen3: 00b in TS2 Sym6[5:4]. eq request data rate
assign int_txts_eq_req_data_rate = ltssm_current_data_rate_g6 ? {txts_eq_req_data_rate, txts_eq_req_data_rate} :
                                   ltssm_current_data_rate_g5 ? {1'b0, txts_eq_req_data_rate} : ltssm_current_data_rate_g4 ? {txts_eq_req_data_rate, 1'b0} : 2'b00;

// special work on symbol 6 for TS2 sent in RcvrCfg
wire ltssm_in_recovery = |ltssm_state_equalization | ltssm_state_rcvrlock | ltssm_state_rcvrcfg | ltssm_state_rcvrspd | ltssm_state_rcvridle;
wire int_ltssm_precoding_on = ltssm_precoding_on & ltssm_in_recovery;
assign txts2_g3 =                 (ltssm_cmd_32geqts && !cfg_gen3_eq_disable) ? {{2{`TS2_8B}}, {1'b1, cfg_lec_g6_pset_rtx, 2'b00, ltssm_precode_request}, {txts_eq_req, txts_quie_gua, int_txts_eq_req_data_rate, 4'b0}} :
                 (ltssm_cmd_16geqts && !cfg_gen3_eq_disable) ? {{2{`TS2_8B}}, {1'b1, cfg_lec_g5_pset_rtx, 2'b00, ltssm_precode_request}, {txts_eq_req, txts_quie_gua, int_txts_eq_req_data_rate, 4'b0}} :
                  (ltssm_cmd_8geqts && !cfg_gen3_eq_disable) ? {{2{`TS2_8B}}, {1'b1, cfg_lec_g4_pset_rtx, cfg_lec_g4_pset_rrx}, {txts_eq_req, txts_quie_gua, int_txts_eq_req_data_rate, 4'b0}} :
                  // remove int_ltssm_precoding_on for gen6 ts2 because the spec says: For data rates of 32.0 GT/s or higher, a Transmitter must set the Transmitter Precoding On bit to 1b in the TS1 Ordered Sets that
                  // it transmits in Recovery if precoding is on for the current data rate; else the bit must be set to 0b
                  (ltssm_current_data_rate_g6)               ? {{2{8'h0}}, {1'b0, 1'b0, int_phy_mac_coef_ltx[7 +: 6]}, {txts_eq_req, txts_quie_gua, 1'b0, int_txts_eq_req_data_rate, 3'b0}} :   // gen6 draft 0.71
                                                               {{3{`TS2_8B}}, {txts_eq_req, txts_quie_gua, int_txts_eq_req_data_rate, 4'b0}};

// delay txts2_g3 one cycle to match txts_g3 (for TS1) for ltssm_cmd as txts_g3 is reg
always @(posedge core_clk or negedge core_rst_n) begin : txts2_g3_d_PROC
    if ( !core_rst_n ) begin
        txts2_g3_d <= #TP '0;
    end else begin
        txts2_g3_d <= #TP txts2_g3;
    end
end

assign txts_g3_real = txts_g3 | { 15'h0, {1'b0, int_ltssm_precoding_on, 6'h0} , {ltssm_cmd_eqredo , 7'h0} };

// for 1b/1b encoding, ts1 sym4/12 (eq byte 3) bit 7 = reserved
assign txts_g3_w_parity = (ltssm_cmd_ts1) ? {(g6_rate ? 1'b0 : parity(txts_g3_real)), txts_g3_real} : txts2_g3_d;


// Prepare the content of symbols 6-9 in transmitted TS1 and TS2 Ordered Sets @G12 (or at any rate when equalization is disabled).
// Handle special format of symbol 6 in EQ TS1 and EQ TS2 @G12 rate.
// When equalization is disabled the content is set to normal TS1 and TS2
assign int_eqts_enable = ltssm_cmd_eqts && !cfg_gen3_eq_disable;
always @(*) begin : txts_g2_comb_PROC
    if ( ltssm_cmd_ts2 ) begin
// no need the logic because for skip_eq the first is gen5 and then gen6
//          if ( ltssm_cmd_eqts_gen12[1] ) // send gen5 pset+precode_request in ts2 at gen1/2 rate for skip eq
//            txts_g2[EQTS_WD-1:0] = {{3{`TS2_8B}}, {1'b1, cfg_lec_g6_pset_rtx, 2'b00, ltssm_precode_request}};
//        else
          if ( ltssm_cmd_eqts_gen12[1] ) // send gen5 pset+precode_request in ts2 at gen1/2 rate for skip eq
            txts_g2[EQTS_WD-1:0] = {{3{`TS2_8B}}, {1'b1, cfg_lec_g5_pset_rtx, 2'b00, ltssm_precode_request}};
        else
            txts_g2[EQTS_WD-1:0] = (int_eqts_enable && upstream_component) ? {{3{`TS2_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} : {{4{`TS2_8B}}};
    end else begin
        //gates: use LaneEqControl register (cfg_lec_pset_rtx, cfg_lec_pset_rrx) to be inserted into transmitted TS1s for Compliance and Loopback.Entry
        txts_g2[EQTS_WD-1:0] = (int_eqts_enable && ltssm_state_pollactive) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} :
                               (int_eqts_enable && ltssm_state_lpbkentry) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} :
                               (int_eqts_enable && upstream_component) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} : {{4{`TS1_8B}}};
// no need the logic because for skip_eq the first is gen5 and then gen6
//        if ( ltssm_cmd_eqts_gen12[0] ) begin // send gen5 pset+precode_request in ts1 at gen1/2 rate for skip eq
//            txts_g2[EQTS_WD-1:0] = {{3{`TS1_8B}}, {1'b1, cfg_lec_g6_pset_rtx, 2'b00, ltssm_precode_request}};
//        end else if( cfg_target_link_speed == `GEN6_LINK_SP ) begin
//        txts_g2[EQTS_WD-1:0] = (int_eqts_enable && ltssm_state_pollactive) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g6_pset_rtx, cfg_lec_g6_pset_rrx}} :
//                               (int_eqts_enable && ltssm_state_lpbkentry) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g6_pset_rtx, cfg_lec_g6_pset_rrx}} :
//                               (int_eqts_enable && upstream_component) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} : {{4{`TS1_8B}}};
//        end else
        if ( ltssm_cmd_eqts_gen12[0] ) begin // send gen5 pset+precode_request in ts1 at gen1/2 rate for skip eq
            txts_g2[EQTS_WD-1:0] = {{3{`TS1_8B}}, {1'b1, cfg_lec_g5_pset_rtx, 2'b00, ltssm_precode_request}};
        end else 
        if( cfg_target_link_speed == `GEN6_LINK_SP ) begin
            txts_g2[EQTS_WD-1:0] = (int_eqts_enable && ltssm_state_pollactive) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g6_pset_rtx, cfg_lec_g6_pset_rrx}} :
                                   (int_eqts_enable && ltssm_state_lpbkentry) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g6_pset_rtx, cfg_lec_g6_pset_rrx}} :
                                   (int_eqts_enable && upstream_component) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} : {{4{`TS1_8B}}};
        end else
        if( cfg_target_link_speed == `GEN5_LINK_SP ) begin
            txts_g2[EQTS_WD-1:0] = (int_eqts_enable && ltssm_state_pollactive) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g5_pset_rtx, cfg_lec_g5_pset_rrx}} :
                                   (int_eqts_enable && ltssm_state_lpbkentry) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g5_pset_rtx, cfg_lec_g5_pset_rrx}} :
                                   (int_eqts_enable && upstream_component) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} : {{4{`TS1_8B}}};
        end else
        if( cfg_target_link_speed == `GEN4_LINK_SP ) begin
        txts_g2[EQTS_WD-1:0] = (int_eqts_enable && ltssm_state_pollactive) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g4_pset_rtx, cfg_lec_g4_pset_rrx}} :
                               (int_eqts_enable && ltssm_state_lpbkentry) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_g4_pset_rtx, cfg_lec_g4_pset_rrx}} :
                               (int_eqts_enable && upstream_component) ? {{3{`TS1_8B}}, {1'b1, cfg_lec_pset_rtx, cfg_lec_pset_rrx}} : {{4{`TS1_8B}}};
        end
    end
end

// precode request sent to the remote partner at Gen1/2 rate in EQ TS or Gen4 rate 8GT eq ts
// smlh_send_pc_req_d is de-precoding used in the Rx
always @(posedge core_clk or negedge core_rst_n) begin : smlh_send_pc_req_d_PROC
    if ( ~core_rst_n ) begin
        smlh_send_pc_req_d <= #TP '0;
//    end else if ( smlh_link_up_falling_edge ) begin
    end else if ( ltssm_state_detect ) begin
        smlh_send_pc_req_d <= #TP '0;
    end else if ( ltssm_cmd_ts2 && ltssm_cmd_eqts_gen12[1] && txts_g2[7] && ltssm_state_rcvrcfg ) begin
        smlh_send_pc_req_d <= #TP txts_g2[0];
//    end else if ( ltssm_cmd_eqts_gen12[0] && txts_g2[7] ) begin
//        smlh_send_pc_req_d <= #TP txts_g2[0];
    end else if ( ltssm_cmd_16geqts && !cfg_gen3_eq_disable && txts2_g3[15] && ltssm_state_rcvrcfg ) begin
        smlh_send_pc_req_d <= #TP txts2_g3[8];
    end
end // smlh_send_pc_req_d_PROC

assign eqctl_precode_request = smlh_send_pc_req_d; // de-precode on on Rx

// precode request sent to the remote partner with Gen5 rate 8GT eq ts
// smlh_send_pc6_req_d is de-precoding used in the Rx
always @(posedge core_clk or negedge core_rst_n) begin : smlh_send_pc6_req_d_PROC
    if ( ~core_rst_n ) begin
        smlh_send_pc6_req_d <= #TP '0;
    end else if ( ltssm_state_detect ) begin
        smlh_send_pc6_req_d <= #TP '0;
    end else if ( ltssm_cmd_32geqts && !cfg_gen3_eq_disable && txts2_g3[15] && ltssm_state_rcvrcfg ) begin
        smlh_send_pc6_req_d <= #TP txts2_g3[8];
    end
end // smlh_send_pc_req_d_PROC

assign eqctl_precode6_request = smlh_send_pc6_req_d; // de-precode on on Rx

// muxing depending on the current data rate
assign txts = (ltssm_current_data_rate_g12) ? txts_g2 : txts_g3_w_parity;

assign eqctl_eqts_info = txts;
wire ec_01b = txts[1:0] == 2'b01 | txts[1:0] == 2'b00; // ec=00b | 01b
// send transmitter used coef in TX TS0 when dsp entry to eq2 and usp entry to eq3. doing so for the remote eq master uses the coef as initial fine tuning eq settings
wire ec_10b_not_pset = (txts[1:0] == 2'b10 & txts[7] == 1'b0) |  tx_ts0_dsp_eq2_usp_eq3;    // ec=10b & use_pset = 0b
wire ec_10b_yes_pset = (txts[1:0] == 2'b10 & txts[7] == 1'b1) & ~tx_ts0_dsp_eq2_usp_eq3;    // ec=10b & use_pset = 1b
// the gen6 spec says: on a TS0 Ordered set the valid half has each even bit position j is identical to the odd bit position j+1 PRIOR TO gray code and descrambling
// So on the TX after scrambling and gray code a TS0 Ordered set the valid half has each even bit position j is identical to the odd bit position j+1.
// the TX even bit for TS0 before scrambling and gray code is set to 0b
// ltssm_state_equalization[3:0] = {EQ3, 2, 1, 0}
// txts[7] is use_pset defined for EQ2 only in TS0, but usp sends ts0 in beginning of EQ3 too
// Note: Use Preset is 0b for Phase 2, 3 of Downstream Lanes and Phase 3 for Upstream Lanes, received email on 24April2022
wire txts0_p = (|ltssm_state_equalization[3:2] && ~tx_ts0_dsp_eq2_usp_eq3) ? txts[7] : 1'b0;
// txts[31:0] = {sym3, sym2, sym1, sym0} of ts1
//
// ts0 sym1 bit[7,5,3,1] = {use_pset, reset_eieos, ec[1:0]}
// ts0 sym1 bit[1] = ts1 sym1 bit[0]
//              3                 1
//              5                 2
//              7                 7
//wire [7:0] ts0_s1 = {txts[7], txts[7], txts[2], txts[2], txts[1], txts[1], txts[0], txts[0]};
wire [7:0] ts0_s1 = {txts0_p, 1'b0, txts[2], 1'b0, txts[1], 1'b0, txts[0], 1'b0};
// ts0 sym2 bit[7,5,3,1] = (ec=00b | ec=01b) ? FS[3:0] : (ec_10b_not_pset) ? C-1[3:0] : 4'b0
// when ec = 00b or 01b :
// ts0 sym2 bit[1] = ts1 sym2 bit[0]
//              3                 1
//              5                 2
//              7                 3
// when ec = 10b & not_pset:
// ts0 sym2 bit[1] = ts1 sym3 bit[0]
//              3                 1
//              5                 2
//              7                 3
//wire [7:0] ts0_s2 = ec_01b ? {txts[11], txts[11], txts[10], txts[10], txts[9],  txts[9], txts[8],  txts[8]} : ec_10b_not_pset ? {txts[19], txts[19], txts[18], txts[18], txts[17], txts[17], txts[16], txts[16]} : 8'h0;
wire [7:0] ts0_s2 = ec_01b ? {txts[11], 1'b0, txts[10], 1'b0, txts[9],  1'b0, txts[8],  1'b0} : ec_10b_not_pset ? {txts[19], 1'b0, txts[18], 1'b0, txts[17], 1'b0, txts[16], 1'b0} : 8'h0;
// ts0 sym3 bit[7,5,3,1] = (ec=00b | ec=01b) ? {LF[1:0], FS[5:4]} : (ec_10b_not_pset) ? C+1[3:0] : 4'b0
// when ec = 00b or 01b :
// ts0 sym3 bit[1] = ts1 sym2 bit[4]
//              3                 5
//              5  = ts1 sym3 bit[0]
//              7                 1
// when ec = 10b & not_pset:
// ts0 sym3 bit[1] = ts1 sym4 bit[0]
//              3                 1
//              5                 2
//              7                 3
//wire [7:0] ts0_s3 = ec_01b ? {txts[17], txts[17], txts[16], txts[16], txts[13], txts[13], txts[12], txts[12]} : ec_10b_not_pset ? {txts[27], txts[27], txts[26], txts[26], txts[25], txts[25], txts[24], txts[24]} : 8'h0;
wire [7:0] ts0_s3 = ec_01b ? {txts[17], 1'b0, txts[16], 1'b0, txts[13], 1'b0, txts[12], 1'b0} : ec_10b_not_pset ? {txts[27], 1'b0, txts[26], 1'b0, txts[25], 1'b0, txts[24], 1'b0} : 8'h0;
// ts0 sym4 bit[7,5,3,1] = (ec=00b | ec=01b) ? LF[5:2] : (ec_10b_not_pset) ? {C-2[2:0], C+1[4]} : 4'b0
// when ec = 00b or 01b :
// ts0 sym4 bit[1] = ts1 sym3 bit[2]
//              3                 3
//              5                 4
//              7                 5
// when ec = 10b & not_pset:
// ts0 sym4 bit[1] = ts1 sym4 bit[4]
//              3    ts1 sym3 bit[4]
//              5                 5
//              7                 6
//wire [7:0] ts0_s4 = ec_01b ? {txts[21], txts[21], txts[20], txts[20], txts[19], txts[19], txts[18], txts[18]} : ec_10b_not_pset ? {txts[22], txts[22], txts[21], txts[21], txts[20], txts[20], txts[28], txts[28]} : 8'h0;
wire [7:0] ts0_s4 = ec_01b ? {txts[21], 1'b0, txts[20], 1'b0, txts[19], 1'b0, txts[18], 1'b0} : ec_10b_not_pset ? {txts[22], 1'b0, txts[21], 1'b0, txts[20], 1'b0, txts[28], 1'b0} : 8'h0;
// ts0 sym5 bit[7,5,3,1] = (ec=00b | ec=01b | ec_10b_yes_pset) ? TX_PSET : (ec_10b_not_pset) ? C0[3:0] : 4'b0
// when ec = 00b or 01b or ec_10b_yes_pset:
// ts0 sym5 bit[1] = ts1 sym1 bit[3]
//              3                 4
//              5                 5
//              7                 6
// when ec = 10b & not_pset:
// ts0 sym4 bit[1] = ts1 sym2 bit[0]
//              3    ts1 sym2 bit[1]
//              5                 2
//              7                 3
//wire [7:0] ts0_s5 = ec_01b || ec_10b_yes_pset ? {txts[6], txts[6], txts[5], txts[5], txts[4], txts[4], txts[3], txts[3]} : ec_10b_not_pset ? {txts[11], txts[11], txts[10], txts[10], txts[9], txts[9], txts[8], txts[8]} : 8'h0;
wire [7:0] ts0_s5 = ec_01b || ec_10b_yes_pset ? {txts[6], 1'b0, txts[5], 1'b0, txts[4], 1'b0, txts[3], 1'b0} : ec_10b_not_pset ? {txts[11], 1'b0, txts[10], 1'b0, txts[9], 1'b0, txts[8], 1'b0} : 8'h0;
// ts0 sym6 bit[7,5,3,1] = (ec_10b_not_pset) ? {1'b0, retimer_extend, C0[5:4]} : 4'b0
// when ec = ec_10b_not_pset:
// ts0 sym6 bit[1] = ts1 sym2 bit[4]
//              3                 5
//              5                 7
//              7                 0
//wire [7:0] ts0_s6 = ec_10b_not_pset ? {1'b0, 1'b0, txts[15], txts[15], txts[13], txts[13], txts[12], txts[12]} : 8'h0;
wire [7:0] ts0_s6 = ec_10b_not_pset ? {1'b0, 1'b0, txts[15], 1'b0, txts[13], 1'b0, txts[12], 1'b0} : 8'h0;
assign eqctl_eqts_info_ts0 = {ts0_s6, ts0_s5, ts0_s4, ts0_s3, ts0_s2, ts0_s1};

// 2ms timeout on the rtx update requests issued by the PHY.
// Timeout occurs after counting 16 131us ticks on an active update request,
assign timeout_rtx = 0;

always @( * ) begin
    mac_phy_timeout_rtx = 0;

    mac_phy_timeout_rtx = timeout_rtx;
end //always

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// redoing equalization
///////////////////////////////////////////////////////////////////////////////////////////////////////////////


/*html_start
<p><b>rxts_eq_mismatch</b><br>
Asserted when the coefficients/presets on received TS1s don't match the coefficients/presets requested during ftune_rtx.
This variable is sampled for all the lanes at top level when transitioning Equalization->RcvrLock and it is used to initiate
the process of redoing equalization.
html_end*/
reg [EQTS_WD-1:0] rxts_i;// internal aliases
always @* begin : rxts_i_PROC
    rxts_i = rxts;

    if ( g6_rate ) begin
        rxts_i[24 +: 6] = {rxts[24 +: 5], rxts[13]};
        rxts_i[16 +: 6] = {rxts[ 8 +: 5], rxts[19]};
        rxts_i[8 +: 6]  = {rxts[16 +: 3], rxts[20 +: 3]};
    end // if ( g6_rate
end // rxts_i_PROC

//assign rxts_i[24 +: 6] = `ifdef CX_GEN6_SPEED g6_rate ? {rxts[24 +: 5], rxts[13]}      : `endif rxts[24 +: 6];
//assign rxts_i[16 +: 6] = `ifdef CX_GEN6_SPEED g6_rate ? {rxts[ 8 +: 5], rxts[19]}      : `endif rxts[16 +: 6];
//assign rxts_i[8 +: 6]  = `ifdef CX_GEN6_SPEED g6_rate ? {rxts[16 +: 3], rxts[20 +: 3]} : `endif rxts[8 +: 6];
wire rxts_eq_pset_mismatch = eqctl_8ects1_rcvd[0] && !(rxts[6:3] == mac_phy_pset_rtx);
wire rxts_eq_coef_mismatch = eqctl_8ects1_rcvd[0] && !((rxts_i[8 +: 6] == mac_phy_coef_rtx[0 +: 6]) && (rxts_i[16 +: 6] == mac_phy_coef_rtx[6 +: 6]) && (rxts_i[24 +: 6] == mac_phy_coef_rtx[12 +: 6]));
assign rxts_eq_mismatch = mac_phy_pset_rtx_was_last ? rxts_eq_pset_mismatch : rxts_eq_coef_mismatch;

///////////////////////////////////////////////
// functions
///////////////////////////////////////////////
function automatic parity(input [EQTS_WD-2:0] vector_31b);
    begin
        parity = ^vector_31b;
    end
endfunction

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// debug signals
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
`ifndef SYNTHESIS
// TS1 fields at Gen3 rate
wire txts_parity                    = txts[31];
wire txts_reject                    = txts[30];
wire [TX_COEF_WD/3-1:0] txts_coef_2 = txts[24 +: 6];
wire [TX_COEF_WD/3-1:0] txts_coef_1 = txts[16 +: 6];
wire [TX_COEF_WD/3-1:0] txts_coef_0 = txts[8 +: 6];
wire [TX_COEF_WD-1:0]   txts_coef   = {txts_coef_2, txts_coef_1, txts_coef_0};
wire txts_use_pset                  = txts[7];
wire [TX_PSET_WD-1:0]   txts_pset   = txts[6:3];
wire txts_rst_eiec                  = txts[2];
wire [1:0] txts_ec                  = txts[1:0];
wire [3:0] txts_ec_oneh             = {txts[1:0]==2'b11, txts[1:0]==2'b10, txts[1:0]==2'b01, txts[1:0]==2'b00};

wire [TX_COEF_WD/3-1:0] phy_rtx_coef_2 = mac_phy_coef_rtx[12 +: 6];
wire [TX_COEF_WD/3-1:0] phy_rtx_coef_1 = mac_phy_coef_rtx[6 +: 6];
wire [TX_COEF_WD/3-1:0] phy_rtx_coef_0 = mac_phy_coef_rtx[0 +: 6];
wire [TX_COEF_WD-1:0]   phy_rtx_coef   = {phy_rtx_coef_2, phy_rtx_coef_1, phy_rtx_coef_0};

`endif // SYNTHESIS

endmodule // smlh_eqctl_slv
// ASSERTIONS
//
// accept/reject/timeout flags: last for one cycle only, can only happen if one of the "rtx_upd" flags is high, on the following cycle all the "rtx_upd" flags must be low
//

//
// COVERAGE
//
// want to see empty Phase2|3, i.e. the PHY does not issue any request
//
//
//
