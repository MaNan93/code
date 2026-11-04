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
// ---    $Revision: #71 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_ltssm.sv#71 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC layer Handler Link State Machine
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module smlh_ltssm
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_ACT;
 import DWC_pcie_core_pkg::S_POLL_ACTIVE;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import DWC_pcie_core_pkg::S_POLL_CONFIG;
 import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_DETECT_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_COMPLETE;
 import DWC_pcie_core_pkg::S_CFG_IDLE;
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
 import DWC_pcie_core_pkg::S_LPBK_EXIT;
 import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
 import DWC_pcie_core_pkg::S_HOT_RESET_ENTRY;
 import DWC_pcie_core_pkg::S_HOT_RESET;
 import DWC_pcie_core_pkg::S_RCVRY_EQ0;
 import DWC_pcie_core_pkg::S_RCVRY_EQ1;
 import DWC_pcie_core_pkg::S_RCVRY_EQ2;
 import DWC_pcie_core_pkg::S_RCVRY_EQ3;
 import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
 import DWC_pcie_core_pkg::CFG_CXL_PORT_ENABLE_WD;
#(
    parameter   INST              = 0,                             // The uniquifying parameter for each port logic instance.
    parameter   NB                = `CX_NB,                        // Number of symbols (bytes) per clock cycle
    parameter   NL                = `CX_NL,                        // Number of lanes
    parameter   AW                = `CX_ANB_WD,                    // Width of the active number of bytes
    parameter   TP                = `TP,                           // Clock to Q delay (simulator insurance)
    parameter   L2NL              = NL==1 ? 1 : `CX_LOGBASE2(NL),  // log2 number of NL
    parameter   REGIN             = 1,                             // Optional input registration
    parameter   BAC_WD            = `CX_BAC_WD,                    // Width of the BlockAlignControl signal
    parameter   PHY_TXEI_WD       = `CX_PHY_TXEI_WD,               // PHY TxEelcidle width a lane.
    parameter   OS_WD             = `CX_MAC_SB_WD, // Number of OS width
    parameter   T_WD              = 25 // timer bit width
)

                   (
    // -----------------------------------------------------------------------------
    // Inputs/Outputs declaration
    // -----------------------------------------------------------------------------
    // ------------ Inputs -----------------
    input                core_clk,
    input                core_rst_n,
    input                cfg_comm_clk_config,             // Common Clock(Non-SRIS) mode
    input                xplh_smlh_req_rcvry,
    input                cfg_flit_mode_enable,
    input                cfg_pcie_cap_flit_mode_sup,
    input                cfg_flit_mode_dis,
    input                xplh_xmlh_sof,                 // xplh sent an Idle Flit
    input                cfg_reciver_l0p_supported,
    input                xdlh_smlh_link_req,
    input  [4:0]         xdlh_smlh_link_width,
    input                xdlh_smlh_link_initiated,
    input  [NL-1:0]      rmlh_deskew_datastream_bus,
    input  [4:0]         rmlh_rplh_rxdata_link_width,
    input                spif_smlh_req_retrain,          // Link Laye request to LTSSM to transition to Recovery on SPIF interface
    input                spif_smlh_req_reset,            // Link Laye request to LTSSM to reset the link on SPIF interface
    input                cfg_pcie_slot_clk_config,       // connect to the same ref clock source, HwInit status reg
    input  [CFG_CXL_PORT_ENABLE_WD-1:0] cfg_cxl_port_enable_i, // CXL port enables = cfg_cxl_port_enable = {[128B Latency Optimized Flit Mode capable],[128B Latency Optimized Flit Mode enable],cfg_cxl_port_pbr_flit_enable, cfg_cxl_port_pbr_flit_capable,
                                                               //                                           cfg_cxl_apn_sw_mode, cfg_cxl_port_disable_r1p1_training, cfg_cxl_port_multi_logical_dev_enable, cfg_cxl_port_r20_enable,
                                                               //                                           cfg_cxl_port_multi_logical_dev_capable, cfg_cxl_port_r20_capable,
                                                               //                                           cfg_cxl_apn_bypass_enable, cfg_cxl_port_mem_enable, cfg_cxl_port_io_enable, cfg_cxl_port_cache_enable,
                                                               //                                           cfg_cxl_port_retimer2_present, cfg_cxl_port_retimer1_present, cfg_cxl_port_drift_buffer_enable,
                                                               //                                           cfg_cxl_port_sync_hdr_bypass_enable, cfg_cxl_port_mem_capable, cfg_cxl_port_cache_capable}
    input  [15:0]        cfg_cxl_port_vid,               // cxl dvsec vendor id
    input                cfg_cxl_retimers_pre_mismatched,  // cxl retimers present mismatched
    input  [1:0]         cfg_retimers_pre_detected,      // Retimers present detected {retimer2,retimer1}
    input                vlsm_almp_rx_req,               // VLSM receives io or mem/cache ALMP requests
    input                app_sris_mode,
    input                xmlh_sris_enable,
    input                pipe_regif_all_idle,
    input                cfg_rate_chg_mode,
    input                cfg_pam4_restricted_levels_requirement,
    input  [NL-1:0]      pam4_restricted_levels_wr_ack_pending,
    // Beneath are the interface to CDM where software configures the intended
    // operation condition for link
    input                cfg_ts2_lid_deskew,
    input                cfg_support_part_lanes_rxei_exit,// Polling.Active -> Polling.Configuration based on part of predetermined lanes Rx EI exit
    input                cfg_upstream_port,               // port has been configured as an upstream port
    input                cfg_root_compx,                  // port has been configured as a root complex
    input   [7:0]        cfg_n_fts,                       // number of fast training sequence required by PHY
    input                cfg_scrmb_dis,                   // scrambler disable enable, for RC to turn off the downstream port's scramber
    input                cfg_link_dis,                    // link disable enable, for RC to disable the downstream port's link
    input   [1:0]        cfg_select_deemph_mux_bus,       // sel deempahsis {bit, var}
    input                cfg_lpbk_en,                     // loopback enable, for master device to start a loopback operation of a slave device
    input                cfg_mux_lpbk_lanenum,            // 0b (default): use the latched lane number as the scrambler seed; 1b: use the default lane number as the scrambler seed
    input                cfg_reset_assert,                // Link reset enable, for RC to reset downstream link
    input   [7:0]        cfg_link_num,                    // 8bit link number of upstream device sent over TS seqeunce
    input   [5:0]        cfg_forced_ltssm,                // 6 bits to control manually transaction into each states.
    input   [3:0]        cfg_forced_ltssm_cmd,
    input                cfg_force_en,                    // A debug capability built in to allow software force LTSSM into a specific state
    input                cfg_fast_link_mode,              // simulation speed up mode
    input                cfg_l0s_supported,               // if core implemented L0s, set to 1
    input   [5:0]        cfg_link_capable,                // bit vector to indicate the intended link capabilities, bit0 -- x1, bit1 -- x2, bit2 -- x4, bit3 -- x8,
    input                cfg_ext_synch,                   // software enable extended synch
    input                cfg_gointo_cfg_state,            // a debug capability to allow forcing a LTSSM state to CFG link width start state from recovery idle state
    input                cfg_link_retrain,                // PCI express link control register to start a link retraining when a reset or loopback are intended.  This signal force link to go from L0 to recovery lock
    input                cfg_pl_gen3_zrxdc_noncompl,      // Port Logic register bit field indicating non compliance of 2.5 GT/s receiver impedance while in 8GT/s mode.
                                                          // (8 GT/s Receiver Impedance ECN).
    input                cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map, //send continuous eieos in rcvry.lock for pset-coef mapping
    input                cfg_gen3_lower_rate_eq_redo_enable, //allow lower rate change and eq redo
    input                all_pset_coef_map_done,
    input                smlh_req_linkerror,              // Link down request
    // some misc signals
    input                app_init_rst,                    // Application may want to reset LTSSM through this signal.
    input                app_ltssm_enable,                // application signal to block the LTSSM from link negotion due to application's readyness.
    // PMC interfaces for power management
    input                pm_smlh_entry_to_l0s,            // PM commands LTSSM enter L0s
    input                pm_smlh_l0s_exit,                // PM commands LTSSM exit L0s
    input                pm_smlh_entry_to_l1,             // PM commands LTSSM enter L1
    input                pm_smlh_l1_exit,                 // PM commands LTSSM exit L1
    input                pm_smlh_l23_exit,                // PM Commands LTSSM exit L23
    input                pm_smlh_entry_to_l2,             // PM Commands LTSSM enter L2
    input                pm_smlh_prepare4_l123,           // PM Commands LTSSM to get preparing for entering L123
    input                pm_smlh_dllp_hs,                 // PM Commands LTSSM to hold in L0 while pm dllp handshake
    // RMLH interfaces
    input   [NL-1:0]     link_imp_lanes,
    input   [5:0]        link_next_link_mode,
    input   [NL-1:0]     link_lanes_rcving,
    input                link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd,
    input                link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd,
    input                link_latched_live_all_8_ts2_plinkn_planen_rcvd,
    input                link_latched_live_all_8_ts_plinkn_planen_rcvd,
    input                link_latched_live_any_8_ts_plinkn_planen_rcvd,
    input   [NL-1:0]     link_latched_live_any_8_ts_plinkn_planen_rcvd_bus,
    input                link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd,
    input                link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd,
    input                link_latched_live_any_8_ts2_plinkn_planen_rcvd,
    input                link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd,
    input                link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd,
    input                link_xmlh_16_ts2_sent_after_1_ts2_rcvd,
    input                link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies,
    input                link_xmlh_16_ts1_sent,
    input                link_latched_live_all_2_ts1_dis1_rcvd,
    input                link_latched_live_all_2_ts1_lpbk1_rcvd,
    input   [NL-1:0]     link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd,
    input   [NL-1:0]     link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd,
    input                link_latched_live_any_2_ts1_apn_rcvd, // Rx 2 ts1 with Alternate Protocols Negotiation in cfg.lanewait/.laneaccept/.complete
    input   [55:0]       link_latched_live_any_2_ts1_apn_sym14_8_rcvd, // sym14_8 rcvd for alternate protocols
    input                link_latched_live_any_2_ts2_apn_rcvd, // Rx 2 ts2 with Alternate Protocols Negotiation in Cfg.laneaccept
    input   [NL*56-1:0]  link_latched_live_all_8_ts2_apn_sym14_8_rcvd, // sym14_8 rcvd for alternate protocols
    input                link_latched_live_all_2_ts2_apn_rcvd,         // Rx 2 ts2 with Alternate Protocols Negotiation in Cfg.laneaccept
    input   [NL*56-1:0]  link_latched_live_all_2_ts2_apn_sym14_8_rcvd, // sym14_8 rcvd for alternate protocols
    input                link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd,
    input                link_any_2_ts1_linknmtx_planen_rcvd,
    input                link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd,
    input                link_any_2_ts1_dis1_rcvd,
    input                link_latched_live_all_2_ts1_linkn_planen_rcvd,
    input                link_any_2_ts1_linkn_planen_rcvd,
    input                link_lane0_2_ts1_linkn_planen_rcvd,
    input                link_lane0_2_ts1_linknmtx_rcvd,
    input                link_lane0_2_ts1_linknmtx_lanen_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_lanen_rcvd,
    input                link_latched_live_all_2_ts1_plinkn_planen_rcvd,
    input                link_latched_live_lane0_2_ts1_lanen0_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd,
    input                link_latched_live_any_2_ts1_lanendiff_linkn_rcvd,
    input                link_any_2_ts2_rcvd,
    input                link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd,
    input                link_any_2_ts1_rcvd,
    input                link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd,
    input                link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd,
    input                link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd,
    input                link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd,
    input                link_latched_live_any_8_ts2_spd_chg_0_rcvd,
    input                link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd,
    input                link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd,
    input                link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd,
    input                link_any_exact_2_ts_l0p_rcvd,
    input                link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd,
    input                link_xmlh_l0p_16_ts1_sent,
    input                link_latched_live_all_ts1_spd_chg_0_rcvd,
    input                link_latched_live_any_ts2_rcvd,
    input                link_any_8_ts1_spd_chg_1_rcvd,
    input                link_latched_live_all_ts1_not_ec_00b_rcvd,
    input                link_latched_live_all_ts1_ec_00b_rcvd,
    input                link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd,
    input                link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg,
    input                link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd,
    input                link_any_8_ts_linknmtx_lanenmtx_rcvd,
    input                link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd,
    input                link_ln0_8_ts2_linknmtx_lanenmtx_rcvd,
    input                link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd,
    input                link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd,
    input                link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd,
    input                link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd,
    input                link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd,
    input                link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd,
    input                link_latched_live_any_8_std_ts2_spd_chg_1_rcvd,
    input                link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd,
    input                link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    input                link_any_8_eq_ts2_spd_chg_1_rcvd,
    input                link_any_8_8gteq_ts2_spd_chg_1_rcvd,
    input                link_any_8_16gteq_ts2_spd_chg_1_rcvd,
    input                link_any_8_32gteq_ts2_spd_chg_1_rcvd,
    input                link_pc6_rcvd, //gen6 precode request rcvd
    input                link_pc_rcvd, //precode request rcvd
    input                link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    input                link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    input                link_xmlh_32_ts2_spd_chg_1_sent,
    input                link_xmlh_128_ts2_spd_chg_1_sent,
    input                link_xmlh_16_ts2_sent_after_1_ts1_rcvd,
    input                link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd,
    input                link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd,
    input                link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd,
    input                link_any_2_ts1_hotreset1_rcvd,
    input                link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd,
    input                link_any_2_ts1_planen_rcvd,
    input                link_any_2_ts1_lpbk1_rcvd,
    input                link_imp_2_ts1_lpbk1_rcvd,
    input                link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd,
    input                link_any_2_ts_rcvd,
    input                link_any_exact_4_ts_rcvd,
    input                link_any_exact_5_ts_rcvd,
    input                link_1_ts_rcvd,
    input                link_any_1_ts_rcvd,
    input                link_any_1_ts2_rcvd,
    input                link_any_exact_1_ts_rcvd,
    input                link_any_exact_2_ts_rcvd,
    input                link_latched_live_all_2_ts1_rcvd,
    input   [4:0]        link_latched_ts_data_rate,
    input   [4:0]        link_latched_ts_data_rate_ever,
    input   [4:0]        link_any_8_ts_spd_chg_1_data_rate,
    input                link_latched_ts_spd_chg,
    input   [4:0]        link_ts_data_rate,
    input                link_ts_spd_chg,
    input   [4:0]        link_lpbk_ts_data_rate,
    input   [4:0]        link_latched_lpbk_ts_data_rate,
    input                link_lpbk_ts_deemphasis,
    input   [7:0]        link_ts_nfts,
    input                link_latched_live_all_ts_scrmb_dis,
    input                link_any_8_ts_auto_chg,
    input   [1:0]        link_latched_flitm_support, // {Polling.Config, Polling.Active}
    input                link_usp_sris_mode,
    input                link_latched_modts_support,
    input                link_latched_skipeq_enable,
    input   [7:0]        link_any_2_ts1_link_num,
    input   [NL-1:0]     link_2_ts1_plinkn_planen_rcvd_upconf,
    input                link_latched_ts_retimer_pre,
    input                link_latched_ts_two_retimers_pre,
    input                link_latched_poll_config_ts_retimer_pre,
    input                link_latched_poll_config_ts_two_retimers_pre,

    input                xmtbyte_loe_2_ts1_ec_00b_sent,   // less or equal 2 ts1s sent with EC==00b
    input   [10:0]       xmtbyte_ts_pcnt,                 // ts sent persistency count
    input                xmtbyte_1024_ts_sent,            // 1024 ts sent in a state
    input                xmtbyte_dis_link_sent,           // disable link bit set in Tx TS
    input                smlh_eidle_inferred,             // Electrical Idle has been inferred on at least one lane
    input   [NL-1:0]     smlh_inskip_rcv,
    input   [NL-1:0]     smlh_sds_rcvd,                   // RMLH indicates receiver receives SDS, 0 for gen1/2
    input   [NL-1:0]     smlh_ts_rcvd_pulse_bus,
    input   [NL-1:0]     smlh_lanes_rcving,               // NL bits indicates that the lanes have the proper training sequence found
    input   [1:0]        rplh_rcvd_idle,                  // RMLH block keeps track of the number of idle received continously.  Bit 0 indicates receiver received 8 continous idle symbol, bit1 indicates 1 idle has been received
    input                rmlh_all_sym_locked,             // symbol locked on all active lanes
    input                rmlh_rcvd_eidle_set,             // RMLH indicates receiver received eidle ordered set
    input   [NL-1:0]     act_rmlh_rcvd_eidle_set,         // RMLH indicates receiver received eidle ordered set per lane
    input                rmlh_deskew_alignment_err,       // deskew alignement error from deskew block to have LTSSM go into recovery
    input                rmlh_deskew_complete,            // deskew completion indication
    input   [NL-1:0]     rpipe_rxaligned,                 // RMLH RxValid
    input                rmlh_deskew_datastream,
    input                rmlh_goto_recovery,              // an EIEOS is received on any configured Lane in 128b/130b encoding, move from L0 to Recovery.
    input                rmlh_gen3_rcvd_4eidle_set,       // in Loopback.Active state
    input   [NL-1:0]     act_rmlh_gen3_rcvd_4eidle_set,   // in Loopback.Active state per lane
    input                rdlh_rcvd_dllp,                  // RDLH Received DLLP
    input                xdlh_smlh_goto_detect,           // If replay num rollover occurred 4 times, move the link to detect
    input                xdlh_smlh_start_link_retrain,    // Data link layer requests link retraining due to the number of replay exceed 3
    input                rtlh_req_link_retrain,           // RTLH layer requests link retrain due to the watch dog timeout
    // xmt byte block signals to LTSSM to report status of current
    // transimission
    input   [OS_WD-1:0]  xmtbyte_ts1_sent,                // indicates 1 TS1 ordered set has been sent based on LTSSM's command
    input   [OS_WD-1:0]  xmtbyte_ts2_sent,                // indicates 1 TS2 ordered set has been sent based on LTSSM's command
    input                xmtbyte_idle_sent,               // indicates 1 idle has been sent based on LTSSM's command
    input                xmtbyte_eidle_sent,              // indicates 1 eidle ordered set has been sent based on LTSSM's command
    input                xmtbyte_2_compliance_ts1_sent,   // Indicates 2 Compliance TS1 ordered set has been sent based on LTSSM's command
    input                xmbyte_flit_data_stream,
    input                xmtbyte_l0p_linkwidth_changed,
    input                xmtbyte_l0p_state_in_upsize,
    input                xmtbyte_eies_sent,               // indicates 1 EIEOS Ordered Set has been sent
    input                xmtbyte_fts_sent,                // indicates all fast training sequences have been sent based on LTSSM's command
    input                xmtbyte_skip_sent,               // indicates 1 skip ordered set has been sent based on LTSSM's command
    input                xmtbyte_cmd_is_data,             // indicates xmtbyte is in datastream

    input   [2:0]        current_data_rate,               // 0=running at gen1 speeds, 1=running at gen2 speeds, 2 = 8GT/s
    input   [2:0]        current_data_rate_pre,           // 0=running at gen1 speeds, 1=running at gen2 speeds, 2 = 8GT/s. pre 1cycle
    input   [1:0]        current_powerdown,               // PHY changed powerdown
    input   [NL-1:0]     phy_mac_rxelecidle,              // RMLH reports electrical idle asserted
    input   [NL-1:0]     phy_mac_rxdetected,              // RMLH reports the received detected
    input                phy_mac_rxdetect_done,           // RMLH indicates the cycle to sample phy_mac_rxdetected
    input                xmtbyte_txdetectrx_loopback,     // Indicates detectrx or loopback mode
    input                all_phystatus_deasserted,        // RMLH pipe block reports the PHY status deasserted on all lanes
    input   [NL-1:0]     phy_mac_rxstandbystatus_physic_lane,  // RxStandbyStatus (Physical Lane bit order)
    input   [NL-1:0]     phy_mac_rxelecidle_physic_lane,       // No Lane Flip-ed RxElecilde (Physical Lane bit order)
    input   [NL-1:0]     laneflip_lanes_active_physic_lane,    // Lane Flip-ed smlh_lanes_active (Physical Lane bit order)
    input   [NL-1:0]     laneflip_set_rxstandby_physic_lane,   // Lane Flip-ed smlh_set_rxstandby (Physical Lane bit order)
    input   [NL-1:0]     laneflip_mac_phy_rxstandby,           // Lane Flip-ed mac_phy_rxstandby (Logical Lane bit order)
    input   [8:0]        cfg_lane_en,                     // Indicates the number of lanes to check for exit from electrical idle in Polling.Active and Polling.Compliance. 1 = x1, 2=x2, 4=x4 etc.
    input                rplh_pkt_start,                  // Indicates a STP or SDP was received
    input   [7:0]        cfg_rxstandby_control,           // Rxstandby Control
    input                cfg_rxstandby_handshake_policy,
    input                cfg_por_phystatus_mode,
    input   [3:0]        cfg_p1_entry_policy,

    input   [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl,             // lane under test + gen5 control, {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts}
    input   [3:0]        cfg_compliance_de_emphasis,      // "Enforce Deemphasis" field from the "Link Control Register 2" bit 7
    input                cfg_directed_speed_change,       // software control signal to initiate a speed change
    input                cfg_enter_compliance,            // PCI express "Link Control Register 2" "Enter Compliance" bit(4).  This signal forces the link to go from Polling.Active to Polling.Compliance
    input                cfg_enter_mod_compliance,        // Directed enter modified compliance
    input   [7:0]        cfg_gen2_n_fts,                  // number of fast training sequence required by PHY in Gen II mode
    input                cfg_gen2_support,                // indicates this device supports Gen II speeds
    input   [3:0]        cfg_pcie_max_link_speed,         // Max link speed
    input                cfg_phy_txswing,                 // controls mac_phy_txswing signal to the phy
    input                cfg_sel_de_emphasis,             // "Selectable Deemphasis" field from the "Link Control Register 2" bit 6
    input   [3:0]        cfg_target_link_speed,           // "Target Link Speed" field from the "Link Control Register 2" bits 3:0
    input   [2:0]        cfg_transmit_margin,             // "Transmit Margin" field from the "Link Control Register 2" bits 10:8
    input                cfg_tx_compliance_rcv,           // Sets the compliance received bit in the TS1
    input                sticky_rst_n,                    // Cold reset
    input                eqctl_8eqts1_rcvd,               // 8 EQ TS1 rcvd in gen12 rate
    input                eqctl_8eqts2_rcvd,               // 8 EQ TS2 rcvd in gen12 rate
    input                eqctl_any_8eqts1_rcvd,           // 8 EQ TS1 rcvd @Gen12 rate on any lane
    input                eqctl_any_8eqts2_rcvd,           // 8 EQ TS2 rcvd @Gen12 rate on any lane
    input                eqctl_8g4eqts1_rcvd,             // 8 TS1 w/ eq_redo rcvd in gen3 rate
    input                eqctl_8g4eqts2_rcvd,             // 8 8GT EQ TS2 rcvd in gen3 rate
    input                eqctl_any_8g4eqts1_rcvd,         // 8 TS1 w/ eq_redo rcvd @Gen3 rate on any lane
    input                eqctl_any_8g4eqts2_rcvd,         // 8 8GT EQ TS2 rcvd @Gen3 rate on any lane
    input                eqctl_2ects1_retimer_eq_ext0_rcvd, // 2 TS1 w/ Retimer Equalization Extend @Gen4 rate all lane in eq master
    input                eqctl_8g5eqts1_rcvd,             // 8 TS1 w/ eq_redo rcvd in gen3 rate
    input                eqctl_8g5eqts2_rcvd,             // 8 8GT EQ TS2 rcvd in gen3 rate
    input                eqctl_any_8g5eqts1_rcvd,         // 8 TS1 w/ eq_redo rcvd @Gen3 rate on any lane
    input                eqctl_any_8g5eqts2_rcvd,         // 8 8GT EQ TS2 rcvd @Gen3 rate on any lane
    input                eqctl_precode_request,           // send precode request to the remote. So the local needs to perform de-precoding on
    input                eqctl_precode6_request,          // send precode request to the remote. So the local needs to perform de-precoding on
    input                eqctl_8g6eqts1_rcvd,             // 8 TS1 w/ eq_redo rcvd in gen3 rate
    input                eqctl_8g6eqts2_rcvd,             // 8 8GT EQ TS2 rcvd in gen3 rate
    input                eqctl_any_8g6eqts1_rcvd,         // 8 TS1 w/ eq_redo rcvd @Gen3 rate on any lane
    input                eqctl_any_8g6eqts2_rcvd,         // 8 8GT EQ TS2 rcvd @Gen3 rate on any lane
    input   [3:0]        eqctl_2ects1_rcvd,               // 2xects1 rcvd, one hot, 0001b-ec00, 0010b-ec01, 0100b-ec10, 1000b-ec11
    input   [3:0]        eqctl_8ects1_rcvd,               // 8xects1 rcvd, one hot, 0001b-ec00, 0010b-ec01, 0100b-ec10, 1000b-ec11
    input                eqctl_ftune_rtx_done,            // move Phase 2 to Phase 3 (DC) or Phase 3 to RcvrLock (UC) - indicates that all configured rx lanes are operating in their setting
                                                          // for RAW PIPE - optimal setting, for PIPE - Master request setting done
    input                eqctl_eq_req_ltx,                // Local Request for Redoing Equalization. L0 handled as a "pseudo" L0 where TX transactions are blocked
    input                eqctl_eq_req_rtx,                // Remote Request for Redoing Equalization.L0 handled as a "pseudo" L0 where TX transactions are blocked and L0 is exited for retraining
    input                eqctl_eq_done_wo_err,            // For Downstream Port signal. indicate eq is done without error.
    input                eqctl_eq_done_w_err,            // For Downstream Port signal. indicate eq is done with error.
    input                cfg_gen3_eq_disable,             // Gen3 Equalization Disabled
    input                cfg_gen3_eq_phase01_rxeq_enable, // enable Rx adaptation
    input                cfg_gen3_eq_phase23_disable,     // Don't execute Equalization Phase 2 and Phase 3 (Upstream Component Only)
    input                cfg_gen3_dllp_xmt_delay_disable, // Disable delay transmission of DLLPs prior to Equalization
    input                cfg_perform_eq,                  // Directed control to perform equalization
    input                cfg_gen3_eq_p23_exit_mode,       // after 24ms timeout for EQ master, 0 - Rcvry.Speed, 1 - EQ3 for USP or Rcvry.Lock for DSP
    input                eqpa_ftune_rtx_optimal,          // All active lanes reach optimal settings
    input                eqpa_fs_out_of_range,            // any active lane has local FS value out of range
    input                eqpa_use_pset_coef_map_done,     // all active lanes have query done back and then 500ns timeout for core transmitting TS1s with coeff in use in Phase 0/1
    input                cfg_gen4_eq_phase01_rxeq_enable, // enable Rx adaptation
    input                cfg_gen4_eq_phase23_disable,     // Don't execute Equalization Phase 2 and Phase 3 (Upstream Component Only)
    input                cfg_gen4_auto_eq_disable,        // Gen4 Autonomous Equalization Disable
    input                cfg_gen4_usp_send_8gt_eq_ts2_disable,// USP sends 8GT EQ TS2 OS Disable
    input                cfg_gen4_eq_p23_exit_mode,       // after 24ms timeout for EQ master, 0 - Rcvry.Speed, 1 - EQ3 for USP or Rcvry.Lock for DSP
    input                cfg_gen5_eq_phase01_rxeq_enable, // enable Rx adaptation
    input                cfg_gen5_eq_phase23_disable,     // Don't execute Equalization Phase 2 and Phase 3 (Upstream Component Only)
    input                cfg_gen6_eq_phase01_rxeq_enable, // enable Rx adaptation
    input                cfg_gen6_eq_phase23_disable,     // Don't execute Equalization Phase 2 and Phase 3 (Upstream Component Only)
    input                cfg_gen5_auto_eq_disable,        // Gen4 Autonomous Equalization Disable
    input                cfg_gen6_auto_eq_disable,        // Gen4 Autonomous Equalization Disable
    input                cfg_gen6_usp_send_8gt_eq_ts2_disable,// USP sends 8GT EQ TS2 OS Disable
    input                cfg_gen6_eq_p23_exit_mode,       // after 24ms timeout for EQ master, 0 - Rcvry.Speed, 1 - EQ3 for USP or Rcvry.Lock for DSP
    input                cfg_g6_tx_precode_req,           // gen6 precode request
    input                cfg_gen5_usp_send_8gt_eq_ts2_disable,// USP sends 8GT EQ TS2 OS Disable
    input                cfg_gen5_eq_p23_exit_mode,       // after 24ms timeout for EQ master, 0 - Rcvry.Speed, 1 - EQ3 for USP or Rcvry.Lock for DSP
    input                cfg_bypass_eq_enable,            // enable bypass eq
    input                cfg_no_eq_needed_enable,         // enable No Eq Needed
    input                cfg_tx_precode_req,              // precode request from CDM reg
    input                cfg_alt_protocol_enable,         // enable alternate protocol
    input                cfg_hw_autowidth_dis,            // Hardware auto width disable for upconfigure
    input   [5:0]        cfg_target_link_width,           // Target Link Width
    input                cfg_directed_link_width_change,  // Directed Link Width Change
    input                cfg_upconfigure_support,         // Upconfigure support
    input                cfg_reliability_link_width_change_enable, // Enable downsizing link for reliability reasons through cfg_directed_link_width_change/cfg_target_link_width, irrespective of cfg_hw_autowidth_dis and cfg_upconfigure_support
    input   [(NL*PHY_TXEI_WD)-1:0]  int_mac_phy_txelecidle,        // Enable Transmitter Electical Idle
    input   [NL-1:0]     laneflip_pipe_turnoff_physic_lane,    // Indicates PIPE Turnoff (Physical Lane bit order)
    input                smlh_dl_active,                  // SPIF: Indication from the Link Layer that DLCMSM is in DL_ACTIVE state
    input                pm_smlh_l1_2_latched,            // 1: L1_SUB entered L1_2 substate, cleared when in L0
    input                pm_smlh_l1_n_latched,            // 1: L1_SUB entered L1_N substate, cleared when in L0
    input   [7:0]        cfg_l1sub_t_common_mode,         // common mode time in us
    input   [NL-1:0]     phy_mac_phystatus,               // used to clear latched powerdown change
    input   [1:0]        cdm_ras_des_pm_entry_interval,        // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
    input                cdm_ras_des_direct_poll_cmp_to_det,   // Direct LTSSM from Polling.Compliance to Detect
    input                cdm_ras_des_direct_lpbk_slave_to_exit,// Direct LTSSM from Loopback(Slave) to Exit
    input                cdm_ras_des_ltssm_stop,               // Level : Low Power Entry Interval Time for Ras D.E.S Silicon Debug
    input                cdm_ras_des_recovery_req,             // Level : Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
    input                cdm_ras_des_force_rxdetected_en,      // Enable of forcing the lanes of receiver detection.
    input   [NL-1:0]     cdm_ras_des_force_rxdetected,         // Force the lanes of receiver detection. This signal is enabled when the cdm_ras_des_force_rxdetected_en is 1.
    input   [1:0]        cdm_ras_des_ext_eq_to_factor,         // Extend the eq 24/32ms timeout x2/x10
      
    // LTSSM timer outputs routed to the top-level for verification usage
    input  [T_WD-1:0]    fast_time_1ms,
    input  [T_WD-1:0]    fast_time_2ms,
    input  [T_WD-1:0]    fast_time_3ms,
    input  [T_WD-1:0]    fast_time_10ms,
    input  [T_WD-1:0]    fast_time_12ms,
    input  [T_WD-1:0]    fast_time_24ms,
    input  [T_WD-1:0]    fast_time_32ms,
    input  [T_WD-1:0]    fast_time_48ms,
    input  [T_WD-1:0]    fast_time_64ms,
    input  [T_WD-1:0]    fast_time_100ms,
    input                smlh_margin_pipe_idle,           // PIPE is not in margin operation
    input                xmlh_sent_24_ts0_ec00,           // dsp xmlh has sent 24 ts0s with ec=00b in eq1
    input                pm_current_powerdown_p1,         // Indicate mac phy powerdown is in P1
    input                pm_current_powerdown_p0,         // Indicate mac phy powerdown is in P0
    // ----------- outputs -----------------
    output               ltssm_lpbk_entry_send_ts1,       // loopback is in Loopback.Entry and in sending TS1s command
    output               ltssm_directed_speed_change,     // directed_speed_change variable

    output  reg [3:0]    ltssm_cmd,                       // 4bits encoded command to notify transmitter of the proper action based on LTSSM states
    output  reg          ltssm_cmd_eqts,                  // TS command modifier for sending EQ TSs
    output  reg          ltssm_cmd_8geqts,                // sending 8GT EQ TS2 in Gen3 Speed
    output  reg          ltssm_cmd_16geqts,               // sending 16GT EQ TS2 in Gen4 Speed
    output  reg          ltssm_cmd_32geqts,               // sending 32GT EQ TS2 in Gen5 Speed
    output  reg          ltssm_cmd_eqts0,                 // sending ts0 at gen6 rate
    output  reg          ltssm_precoding6_on_latched,     // precoding_on used in cdm status reg
    output  reg          ltssm_dsp_g6_eq1_send_ec00,      // inform xmlh to send 24 ts0s with ec=00b
    output               ltssm_noeq_nd,                   // no eq needed
    output  reg [1:0]    ltssm_cmd_eqts_gen12,            // eqts command for skip_eq to gen5 from gen12
    output  reg          ltssm_precode_request,           // precode request in TS sent to remote (through smlh_eqctl_slv combined with (8GT) eq ts)
    output  reg          ltssm_precoding_on,              // precoding_on in TS sent to remote AND is used in Tx scrambler to turn on precoding after scrambling
    output  reg          ltssm_deprecoding_on,            // deprecoding_on used in Rx descrambler to turn on de-precoding before de-scrambling
    output  reg          ltssm_precoding_on_latched,      // precoding_on used in cdm status reg
    output  reg          ltssm_mod_ts_rcvd,
    output               smlh_noeq_needed_rcvd,           // No EQ Needed Received
    output  reg          ltssm_cmd_eqredo,                // sending TS1 with Equalization Redo(TS1 Symbol6[7]=1) in Gen3 Speed
    output  [3:0]        ltssm_start_equalization,        // bit i set: start equalization from phase "i", www: i=0 only supported for now
    output               smlh_link_up_falling_edge,
    output  reg          ltssm_ts_cnt_en,                 // enable TS count in byte_xmt for an EIEOS transmitting every 32 or 65536 TSs
    output               ltssm_ts_cnt_rst,                // reset TS counter in xmlh_byte_xmt, active high when first TS2 rcvd in CFG_COMPLETE or RCVRY_RCVRCFG
    output  reg          ltssm_in_pollconfig,
    output  reg          smlh_link_up,                    // LTSSM is in link up
    output  reg          smlh_req_rst_not,                // LTSSM link status is in surprised down so that it requests a reset
    output               smlh_scrambler_disable,          // 1 bit to disable the scrambler
    output  reg          smlh_training_rst_n,             // LTSSM negotiated a training reset
    output               smlh_link_disable,               // LTSSM negotiated a link disable
    output               clear_o,                         // ltssm clear
    output               clear_eqctl,                     // ltssm clear
    output               clear_seq,                       // ltssm clear
    output               clear_link,                      // ltssm clear
    output  reg          ltssm_rcvr_err_rpt_en,           // This signal is designed to notify the rmlh block when to enable receiver error report
    output  reg [7:0]    ltssm_xlinknum,                  // 8bits indicate link number to be inserted in training sequence
    output  reg [NL-1:0] ltssm_xk237_4lannum,             // 1 -- K237, 0 -- send lane number
    output  reg [NL-1:0] ltssm_xk237_4lnknum,             // 1 -- K237, 0 -- send link number
    output  [7:0]        ltssm_ts_cntrl,                  // training sequence control
    output               ltssm_flit_mode_enable_w_lpbk,   // both sides agreed
    output  reg [7:0]    ltssm_flit_mode_enable_modules,  // both sides agreed per modules [0] rmlh [1] rplh [2] rdlh [3] xfsh/rfsh [4] xmlh [5] xdlh [6] xplh [7] xtlh
    output               ltssm_flit_mode_tx,              // for TX
    output  reg          ltssm_idl_hs_done,               // 8 idle flits received in R.Idle or C.Idle
    output  logic        ltssm_cmd_compliance_ts1,        // sending two Compliance TS1 in Polling.Compliance
    output     [7:0]     ltssm_compliance_set_num,        // compliance pattern sequence setting number for compliance_TS1
    output               smlh_l0p_update,
    output [5:0]         smlh_l0p_link_mode,              // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    output [5:0]         smlh_l0p_next_link_mode,         // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    output [NL-1:0]      ltssm_l0p_lanes_active,          // LTSSM latched lanes that are active based on the link negotiation
    output [NL-1:0]      ltssm_l0p_last_lanes_active,     // LTSSM latched lanes that are active based on the link negotiation
    output [3:0]         ltssm_l0p_cmd,                   // encoded command to notify transmitter of the proper action based on LTSSM states
    output               ltssm_l0p_cmd_4_eieos_req,       // 4 eieos request at gen6 rate
    output               smlh_l0p_capable,                // l0p capable
    output               smlh_ltssm_in_l0p,               // LTSSM in L0p state
    output               smlh_ltssm_in_l0p_upsize,        // LTSSM in L0p upsize state
    output               smlh_ltssm_l0p_ready,            // LTSSM in L0p state ready
    output [2:0]         smlh_flit_error_link_widh,       // Flit Error Link Width
    output               smlh_xdlh_eios_rcvd,             // Received eieos in flit mode
    output  reg          smlh_pm_state_trans1_flag,
    output  wire         smlh_pm_state_trans2_flag,
    output  reg          ltssm_mod_ts,                    // TX modified TS OS
    output  reg          ltssm_mod_ts_rx,                 // RX modified TS OS
    output               ltssm_ts_alt_protocol,           // Alternate Protocol
    output               ltssm_no_idle_need_sent,         // No idle need sent
    output  reg [55:0]   ltssm_ts_alt_prot_info,          // sym14-8 for AP
    output  [55:0]       ltssm_mod_ts_data_sent,          // For Transmitted Modified Ts Data Register
    output  ltssm_cxl_enable_t ltssm_cxl_enable,          // CXL enables
    output               cxl_sh_bypass,                   // Sync headers are bypassed
    output               cxl_io_throttle_enable,          // CXL.io Throttle Required at 64GT/s
    output  [23:0]       ltssm_cxl_mod_ts_phase1_rcvd,    // Received Modified TS Data Phase1
    output               ltssm_cxl_retimers_pre_mismatched,   // Set CXL_Retimers_Present_Mismatched bit
    output               ltssm_cxl_flexbus_phase2_mismatched, // Set FlexBusEnableBits_Phase2_Mismatch bit
    output               cxl_mode_enable,                 // Indicates whether the link should operate in CXL or PCIe mode
    output               cxl_link_enable,                 // Indicates that CXL link is enabled after reaching 8GT/s
    output  [1:0]        ltssm_cxl_ll_mod,                // CXL Low Latency Mode
    output  reg          ltssm_ap_success,                // Alternate Protocol negotiation successful
    output  reg [NL-1:0] ltssm_lanes_active,              // LTSSM latched lanes that are active based on the link negotiation
    output  reg [NL-1:0] lpbk_eq_lanes_active,            // LTSSM lanes active for Loopback Eq
    output               lpbk_eq_n_lut_pset,              // lpbk during gen5 rate for EQ
    output               lpbk_eq,                         // in Eq state for loopback
    output  reg [NL-1:0] smlh_no_turnoff_lanes,           // No turnoff lanes
    output  reg          lpbk_master,                     // indicates that the ltssm is the loopback master
    output  reg [NL-1:0] deskew_lanes_active,             // LTSSM latched lanes that are active based on the link negotiation, goes to rmlh_deskew logic
    output  reg          smlh_lnknum_match_dis,           // This signal is designed to notify the rmlh block when to enable link number match checking
    output ltssm_state_e smlh_ltssm_state,                // 6 bits encoded link state
    output ltssm_state_e smlh_ltssm_state_wire,           // 6 bits encoded link state before FF for high fanout
    output ltssm_state_e ltssm_next,
    output ltssm_state_e ltssm_last,                      // last link state
    output  reg [1:0]    ltssm_powerdown,                 // Powerdown command to PIPE phy (P2 is set by PM controller)
    // LTSSM status
    output  reg          smlh_in_l0,                      // LTSSM in L0 state
    output  logic        rx_smlh_in_l0,                   // LTSSM in L0 state on RX
    output  reg          smlh_in_l0s,                     // LTSSM in transmit L0s state
    output  reg          smlh_in_rl0s,                    // LTSSM in receive L0s state
    output  reg          smlh_in_l1,                      // LTSSM in L1 state
    output  wire         smlh_in_l1_p1,                   // LTSSM in L1 state with current_powerdown set to P1
    output  reg          smlh_in_l23,                     // LTSSM in L23 state, it will be L2 or L3 based on aux power detection
    output  reg          smlh_l123_eidle_timeout,         // 2ms Timer Timed out while waiting for EIDLE
    output  reg          smlh_pm_latched_eidle_set,
    output               ltssm_in_lpbk,                   // LTSSM in Loopback.Active state
    output  reg          ltssm_in_training,               // LTSSM in training (includes Recovery.Speed in Gen2/Gen3 and Recovery.Equalization in Gen3)
    output  reg [2:0]    ltssm_eidle_cnt,                 // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
    output  [4:0]        l0s_state,                       // L0s sub states of the LTSSM. This is a status information
    output  logic        smlh_bw_mgt_status,              // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
    output  logic        smlh_link_auto_bw_status,        // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
    output  [5:0]        smlh_link_mode,                  // 6 bits indicate the active lanes and final negotiated link width
    output  reg [5:0]    smlh_link_rxmode,                // 6 bits indicate the active lanes and final negotiated link width for RX SIDE
    output  reg [7:0]    latched_ts_nfts,                 // latched number of fast training sequence number from TS ordered set of receiver
    output  reg          smlh_do_deskew,                  // Indicate to the deskew block when it is valid to deskew
                                                          // without the port transitioning through DL_Down status
                                                          // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
    output  reg [2:0]    mac_phy_rate,                    // Indicate to the Phy what speed to run.  0 = 2.5Gb/s  1 = 5.0Gb/s, 2 = 8.0Gb/s
    output      [NL-1:0] mac_phy_rxstandby,               // Controls whether the PHY RX is active (Physical Lane bit order)
    output  reg [NL-1:0] smlh_set_rxstandby,              // RxStandby condtion
    output  reg [4:0]    ltssm_ts_data_rate,              // Gen2 Data rate to advertise support for in the ts.  bits 4:1 of the data rate identifier field.
    output      [9:0]    ltssm_ts_data_rate_eg6,          // Gen2 Data rate to advertise support for in the ts.  bits 4:1 of the data rate identifier field.
    output      [9:0]    latched_ts_data_rate_eg6,        // latched TS sequence data rate from partner. no longer used in xmlh_byte_xmt.v, use current_data_rate==Gen2 instead
    output               ltssm_g6_not_cfg_hotr,
    output               ltssm_g6_not_cfg_hotr_rcvrcfg,
    output               ltssm_g6_not_rcvridle,
    output               ltssm_core_rst_n_release_pulse,  // to assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change
    output               ltssm_dir_spd_chg_rising_edge,   // to clear cfg_directed_speed_change
    output  reg          ltssm_ts_speed_change,           // speed change bit (bit 7) of training sequence data rate identifier field
    output  [1:0]        mac_phy_txdeemph,                // selects transmitter de-emphasis in the PHY
    output  reg [2:0]    mac_phy_txmargin,                // selects transmitter voltage levels in the PHY
    output  reg          mac_phy_txswing,                 // selects transmitter voltage swing level in the PHY
    output               smlh_clr_enter_compliance,       // Signal the cdm that the "Enter Compliance" bit in the "Link Control" register should be cleared
    output  reg          smlh_tx_margin_rst,              // reset the "Transmit Margin" field in the Link Control 2 Register to 3'b000
    output  reg          smlh_successful_spd_negotiation, // successful_speed_negotiation LTSSM variable
    output  reg          ltssm_ts_spd_chg_rcvd_clr,       // used to clear ts_speed_change in smlh_seq_finder_slv
    output  reg [4:0]    latched_ts_data_rate,            // latched TS sequence data rate from partner. no longer used in xmlh_byte_xmt.v, use current_data_rate==Gen2 instead
    output  reg          mac_phy_pam4_restricted_levels,  // The MAC to inform the PHY that the link partner is transmitting or that it will soon be transmitting TS0’s at 64 GT/s.
    output  reg [NL-1:0] rxeqeval_rcvrlock,               // mac_phy_rxeqeval during rcvry.lock
    output  reg          ltssm_ts_auto_change,            // autonomous change/upconfig capable/select deemphasis bit.  bit 6 of the data rate identifier field.
    output  logic        smlh_dir_linkw_chg_started,      // clear cfg_directed_link_width_change
    output  [7:0]        current_n_fts,                   // our current N_FTS based on the link speed (gen1/gen2)
    output               auto_eq_phase_flag,              // Autonomous Equalization Phase
    output               soft_eq_phase_flag,              // Software Equalization Phase
    output               redo_eq_phase_flag,              // Redo Equalization Phase triggered by SW(Perform EQ register)
    output               smlh_eq_pending,                 // Equalization Pending (Used to delay transmission of DLLPs)
    output               smlh_usp_eq_pending,             // Equalization Pending (Used to delay transmission of DLLPs for CXL USP)
    output               smlh_auto_eq_dllp_blocking,      // DLLP blocking for autonomous EQ
    output               usp_g3_eq_redo_executed_int,     // USP gen3 eq redo executed interrupt
    output               usp_g4_eq_redo_executed_int,     // USP gen4 eq redo executed interrupt
    output               usp_g5_eq_redo_executed_int,     // USP gen5 eq redo executed interrupt
//    output               usp_g6_eq_redo_executed_int,     // USP gen6 eq redo executed interrupt
    output  reg          smlh_in_l0_l0s,                  // LTSSM is in L0 or L0s state
    output  [AW-1:0]     active_nb,                       // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s, bit4=16s , bit5=32s
    output  logic [AW-1:0] active_nb_wire,                // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s, bit4=16s , bit5=32s before FF for high fanout
    output  [AW-1:0]     active_nb_gen34,                 // active number of symbols for gen34. bit0=1s, bit1=2s, bit2=4s, bit3=8s, bit4=16s
    output  [3:0]        ltssm_gen3_compliance_tx_pset,   // local tx preset thru cycle or Enter Compliance bit set to enter Compliance
    output               ltssm_gen3_compliance_tx_pset_v, // local tx preset valid from LTSSM
    output               ltssm_in_lpbkentry,
    output               ltssm_in_compliance,
    output               ltssm_in_rcvrylock,
    output               ltssm_in_detectquiet,
    output  reg          ltssm_cmd_send_eieos_for_pset_map, // send eieos continuously in Rcvry.RcvrLock for pset-coef mapping
    output  reg          ltssm_usp_eq_redo,               // redo eq for usp
    output  reg [BAC_WD-1:0] ltssm_blockaligncontrol,     // don't do block alignment while in L0 or LPBK_ACTIVE for slave
    output               ltssm_timeout24ms,               // timeout for master equalization phase
    output  reg [4:0]    ltssm_timer_24ms_cnt,            // if timer=1ms, ltssm_timer_24ms_cnt=1, if timer=2ms, ltssm_timer_24ms_cnt=2, ...
    output  reg          ltssm_state_rcvry_eq,
    output               ltssm_captured_ts_data_rate_g3,  // rx gen3 rate in R.Cfg state
    output               ltssm_captured_ts_data_rate_g5,  // rx gen5 rate in R.Cfg state
    output               ltssm_captured_ts_data_rate_g6,  // rx gen6 rate in R.Cfg state
    output               ltssm_perform_eq_for_lpbk_g6,    // for lpbk eq for Gen6
    output               ltssm_in_lpbk_wo_l0,             // Ltssm in Loopback state in Gen6 without entering L0 since leaving Detect state
    output  reg          ltssm_cfg_to_lpbk_active_master_g6, // Indicates Loopback.Active state in Gen6 when Ltssm enters Loopback state from Config state
    output               ltssm_perform_eq_for_lpbk,       // for lpbk eq
    output  reg          smlh_retimer_pre_detected,       // Retimer was present during the latest Config.Complete
    output  reg          smlh_two_retimers_pre_detected,  // Two Retimer were present during the latest Config.Complete
    output     [3:0]     ltssm_gen4_compliance_jmp,        // Gen4 compliance setting# for Jitter Measurment Pattern
    output     [3:0]     ltssm_gen6_compliance_tp,        // Gen6 compliance setting# for Toggle Pattern
    output     [1:0]     smlh_crosslink_resolution,       // indicates the state of crosslink resolution (00b:not supported,01b:Upstream port,11b:not completed)
    output  reg          smlh_in_rcvryspeed_predetect,    // LTSSM is in Rcvry.Speed or Pre.Detect.Quiet
    output  reg [NL-1:0] ltssm_lanes_active_d,            // lane under test for lpbk slave
    output  reg          ltssm_in_hotrst_dis_entry,
    output               ltssm_lane_flip_ctrl_chg_pulse,  // lane flip control update pulse
    output logic [NL-1:0] smlh_keep_rcvrylock_lane,       // LTSSM to keep Recovery.RcvrLock
    output  [`CX_INFO_EI_WD-1:0] smlh_debug_info_ei,      // information about EIOS reception and LTSSM state transitions that are relevant for external logic that may be masking the analog rxelecidle
                                                          // Group 1 - single cycle pulse - received Ordered Sets decode:
                                                          // [0]: EIOS detected
                                                          // Group 2 - level - LTSSM is in one of the states that depends on rxelecidle==0:
                                                          // [1]: L1
                                                          // [2]: L2
                                                          // [3]: RxL0s
                                                          // [4]: Disabled
                                                          // [5]: Detect.Quiet
                                                          // [6]: Polling.Active
                                                          // [7]: Polling.Compliance
                                                          // Group 3 - level - LTSSM is in one of the states that depends on rxelecidle==1:
                                                          // [8]: LTSSM is in a transitory state prior to L1 or L2
                                                          // [9]: LTSSM is in a transitory state prior to Disabled
                                                          // [10]: LTSSM is in Loopback.Active as a Slave at Gen1
                                                          // [11]: LTSSM is in Polling.Active
                                                          // Group 4 - single cycle pulse - LTSSM state transitions with EI inferred:
                                                          // [12]: LTSSM enters Recovery from L0 with EI inferred, first row in base spec Table 4-11
                                                          // [13]: LTSSM enters Recovery.Speed from Recovery.RcvrCfg with EI inferred, second row in base spec Table 4-11
                                                          // [14]: EI inferred while LTSSM in Recovery.Speed, third/fourth rows in base spec Table 4-11
                                                          // [15]: EI inferred while LTSSM in Loopback.Active as a slave, fifth row in base spec Table 4-11
    output  [L2NL-1:0]   smlh_lane_flip_ctrl,             // control for flipping the lanes
    output  reg [L2NL-1:0] latched_flip_ctrl,             // control for flipping the lanes
    output  reg [4:0]    lpbk_lane_under_test,            // control for flipping the lanes for lpbk master in lpbk.active
    output  [L2NL-1:0]   ltssm_lane_flip_ctrl             // control for flipping the lanes without latched for enter Gen3/4 Polling.Compliance
    ,
    output               ltssm_timeout10ms,               // timeout for master equalization phase
    output  reg          smlh_rx_rcvry_req,               // Rx Recovery Request
    output  reg          smlh_timeout_nfts,               // N_FTS timeout
    output  reg          smlh_l0_to_recovery,             // L0 to Recovery Entry
    output  reg          smlh_l1_to_recovery,             // L1 to Recovery Entry
    output               smlh_rcv_eios_when_l0s_unsprt,   // Received EIOS when L0s is not supported and not directed L1 or L2
    output               smlh_deskew_uncomplete_err,      // Deskew uncompleted error
    output  reg          smlh_spd_change,                 // Speed Change
    output  reg          smlh_lwd_change,                 // Link Width Change
    output  [15:0]       smlh_ltssm_variable              // Ltssm specific parameters
    ,
    output  reg          init_eq_pending                  // Equalization sequence
    ,
    output  reg          init_eq_pending_g4               // Initial 16GT Equalization Pending
    ,
    output  reg          init_eq_pending_g5               // Initial 32GT Equalization Pending
    ,
    output  reg          init_eq_pending_g6               // Initial 64GT Equalization Pending
);

// Include the assertion package
`ifndef SYNTHESIS
`endif // SYNTHESIS
// -----------------------------------------------------------------------------
// Parameter definition
// -----------------------------------------------------------------------------

parameter    TIME_6US        = `CX_TIME_6US;
parameter    TIME_800NS      = `CX_TIME_800NS; 

localparam   DATA_DELAY_BCM36_NHS       = 3;                       // Simulation Mode for BCM36_NHS

// ----------------------------------------------------------------------------
// signals
// ----------------------------------------------------------------------------
wire                clear;
reg                 timeout_1ms_d;
wire                int_timeout_1ms_rising_edge;
wire                xmtbyte_1024_consecutive_ts1_sent; // minimum 1024 CONSECUTIVE ts1 sent
wire                xmtbyte_16_ts_w_lpbk_sent;
wire                xmtbyte_16_ts_w_dis_link_sent;     // 16 ts with disable link bit set has been sent

logic [(NL*PHY_TXEI_WD)-1:0]  int_mac_phy_txelecidle_r;      // internal use TxElecidle.
logic [(NL*PHY_TXEI_WD)-1:0]  int_mac_phy_txelecidle_rr;     // internal use TxElecidle.


ltssm_state_e  lts_state, lts_state_d, ltssm, next_lts_state, last_lts_state, lts_state_wire;

assign  ltssm = lts_state;
assign  ltssm_last = last_lts_state;
assign  ltssm_next = next_lts_state;


reg     [2:0]       hold_current_data_rate;            // update to current_data_rate when clear = 1b and then hold
wire                poll_config_state;                 // Polling + Cfg.Linkwd.Start + Cfg.Linkwd.Accept
reg     [NL-1:0]    latchd_smlh_lanes_rcving;
wire                g1_rate = current_data_rate == `GEN1_RATE;
wire                g2_rate = current_data_rate == `GEN2_RATE;
wire                g3_rate = current_data_rate == `GEN3_RATE;
wire                g4_rate = current_data_rate == `GEN4_RATE;
wire                g5_rate = current_data_rate == `GEN5_RATE;
wire                gtr_g2  = current_data_rate >  `GEN2_RATE;
wire                soe_g2  = current_data_rate <= `GEN2_RATE;
wire                slr_g3  = current_data_rate <  `GEN3_RATE;
wire                slr_g4  = current_data_rate <  `GEN4_RATE;
wire                soe_g3  = current_data_rate <= `GEN3_RATE;
wire                goe_g3  = current_data_rate >= `GEN3_RATE;
wire                goe_g5  = current_data_rate >= `GEN5_RATE;
wire                soe_g5  = current_data_rate <= `GEN5_RATE;
wire                slr_g5  = current_data_rate <  `GEN5_RATE;
wire                slr_g6  = current_data_rate <  `GEN6_RATE;
wire                goe_g6  = current_data_rate >= `GEN6_RATE;
wire                g6_rate = current_data_rate == `GEN6_RATE;
reg     [L2NL-1:0]  latched_linkup_lane_flip_ctrl;
reg                 latched_xmtbyte_eies_sent;
reg                 ltssm_flit_mode_enable_lpbk, ltssm_flit_mode_enable;

reg     [L2NL-1:0]  latched_linkup_lane_flip_ctrl_lpbk;
reg     [L2NL-1:0]  latched_et_cfg_lane_flip_ctrl_lpbk;
reg                 perform_eq_for_loopback;
reg                 perform_eq_for_lpbk_mstr;
wire                perform_eq_for_loopback_64gt_i;
reg                 perform_eq_for_loopback_64gt;
reg                 perform_eq_for_lpbk_mstr_64gt;
wire                perform_eq_for_loopback_g6   = perform_eq_for_loopback_64gt | perform_eq_for_lpbk_mstr_64gt;
wire                perform_eq_for_loopback_g6_i = perform_eq_for_loopback_64gt_i | perform_eq_for_lpbk_mstr_64gt;
assign              ltssm_perform_eq_for_lpbk_g6 = perform_eq_for_loopback_g6;
assign              ltssm_perform_eq_for_lpbk    = perform_eq_for_loopback | perform_eq_for_lpbk_mstr;
reg                 tx_mod_cmpl_pattern_in_lpbk;
reg                 lpbk_master_eq_exit;
reg                 use_modified_ts_d;
reg                 rx_use_modified_ts_d;
reg                 mod_ts_for_ts2_lid_deskew;
reg                 mod_ts_for_ts2_lid_deskew_d;
reg                 cfgcmpl_all_8_ts2_rcvd;
reg     [2:0]       current_data_rate_d;
// extend ltssm_ts_data_rate equal or greater gen6 until gen10 for future use
assign ltssm_ts_data_rate_eg6 = ltssm_ts_data_rate == 5'b10111 ? 10'b0000111111 : {5'h0, ltssm_ts_data_rate};

wire ltssm_cfg_hotrst_state = (smlh_ltssm_state == S_CFG_LINKWD_START  | smlh_ltssm_state == S_CFG_LINKWD_ACEPT | smlh_ltssm_state == S_CFG_LANENUM_WAIT |
                               smlh_ltssm_state == S_CFG_LANENUM_ACEPT | smlh_ltssm_state == S_CFG_COMPLETE     |
                               smlh_ltssm_state == S_HOT_RESET_ENTRY   | smlh_ltssm_state == S_HOT_RESET
                              );
wire ltssm_rcvrcfg_state  = (smlh_ltssm_state == S_RCVRY_RCVRCFG);
wire ltssm_rcvridle_state = (smlh_ltssm_state == S_RCVRY_IDLE);

assign ltssm_g6_not_cfg_hotr_rcvrcfg  = g6_rate & ~ltssm_cfg_hotrst_state & ~ltssm_rcvrcfg_state; // not in Config, HotReset, Rcvry.RcvrCfg state
assign ltssm_g6_not_cfg_hotr          = g6_rate & ~ltssm_cfg_hotrst_state;                        // not in Config, HotReset states
assign ltssm_g6_not_rcvridle          = g6_rate & ~ltssm_rcvridle_state;                          // not in Rcvry.Idle state

reg          ts1_cxl_io_throtte_64g_enable; // CXL.io throttle required at 64GTs
reg  [1:0]   ts1_cxl_nop_hint_info; // CXL NOP Hint info
reg  [2:0]   ts2_cxl_enable; // cxl.cache/mem/io
reg  [1:0]   ts2_cxl_vh_enable; // Multi-logical Dev, CXL 2.0
reg          ts2_cxl_syncheader_bp_enable; // Sync header bypass 
reg          ts2_cxl_256b_lopt_enable; // CXL 256B Latency Optimized Flit
reg          ts2_cxl_pbr_flit_enable;
wire         cxl_syncheader_bp;
wire         cxl_cache_en, cxl_mem_en, cxl_io_en;
wire         cxl_vh_en, multi_logical_dev_en;
wire         cxl_r20_v09_en;
wire         cxl_256b_lopt_en;
wire         cxl_nop_hint_en;
wire [1:0]   cxl_nop_hint_info_req;
wire         cxl_pbr_flit;
wire         cxl_pbr_flit_en;
wire         smlh_bw_mgt_status_w;              // before FF of smlh_bw_mgt_status
wire         smlh_link_auto_bw_status_w;        // before FF of smlh_link_auto_bw_status

    
        wire [55:0]  ltssm_ts1_sym14_8;
        wire [55:0]  ltssm_ts2_sym14_8;
                                                                                             // for CXL the CXL.io is always required
        wire         cfg_alt_protocol_enable_i = use_modified_ts_d & cfg_alt_protocol_enable & cxl_io_en ; // Alternate Protocols must need MOD TS in both sides
        wire         ltssm_ts_alt_protocol_i   = (~smlh_link_up & cfg_alt_protocol_enable_i & ltssm_ts_data_rate[2]);
        assign       ltssm_mod_ts_data_sent     = (ltssm_ts_alt_protocol_i) ? ltssm_ts2_sym14_8 : 56'h0;
        always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_ts_alt_prot_info_PROC
            if ( ~core_rst_n )
                ltssm_ts_alt_prot_info <= #TP 0;
            else
                ltssm_ts_alt_prot_info <= #TP ltssm_ts_alt_protocol_i ? (lts_state == S_CFG_COMPLETE ? ltssm_ts2_sym14_8 : ltssm_ts1_sym14_8) : 56'h0;
                //ltssm_ts_alt_prot_info <= #TP ltssm_ts_alt_protocol ? (lts_state == S_CFG_COMPLETE ? ltssm_ts2_sym14_8 : ltssm_ts1_sym14_8) : 56'h0;
        end // ltssm_ts_alt_prot_info_PROC
        //assign       ltssm_ts_alt_prot_info    = ltssm_ts_alt_protocol ? (lts_state == S_CFG_COMPLETE ? ltssm_ts2_sym14_8 : ltssm_ts1_sym14_8) : 56'h0;
        wire [15:0]  mod_ts_sym9_8;
        wire [15:0]  mod_ts_sym11_10;
        wire [23:0]  mod_ts_sym14_13_12;
        wire [2:0]   ap;
        wire [15:0]  apv_id;
        wire [2:0]   ap_id;
        wire [1:0]   ap_ns;
        wire         ap_info_id_match;
        wire         cxl_vh;
        reg  [15:0]  ltssm_mod_ts_info_1;
        reg  [23:0]  ltssm_mod_ts_info_2;
        reg  [23:0]  ltssm_mod_ts_info_2_d;
        wire [23:0]  mod_ts_info_2_i;
        wire         mod_ts_info_2_i_bit18_pbr;
        logic [23:0] mod_ts_info_2;
        reg          req_protocol_support;
        reg          req_protocol_support_d;
        reg          req_protocol_respond_d;
        wire [15:0]  mod_ts_sym9_8_rcvd   = link_latched_live_any_2_ts1_apn_sym14_8_rcvd[15:0];
        wire [15:0]  mod_ts_sym11_10_rcvd = link_latched_live_any_2_ts1_apn_sym14_8_rcvd[31:16];
        wire [23:0]  mod_ts_sym14_12_rcvd = link_latched_live_any_2_ts1_apn_sym14_8_rcvd[55:32];
        reg          latched_dsp_cxl_non_aware_retimer_rcvd;
        wire         dsp_cxl_retimer1;
        wire         dsp_cxl_retimer2;
        // The Flex Bus physical layer samples the value in registers only during exit from the Detect LTSSM state and ignores any changes to this register in all other LTSSM states.
        reg [CFG_CXL_PORT_ENABLE_WD-1:0]   cfg_cxl_port_enable;
        wire          update_cxl_port_enable;
        assign update_cxl_port_enable = (smlh_ltssm_state == S_DETECT_QUIET) | (smlh_ltssm_state == S_DETECT_ACT);
        always @( posedge core_clk or negedge core_rst_n ) begin : cfg_cxl_port_enable_PROC
            if ( ~core_rst_n )
               cfg_cxl_port_enable  <= #TP 0;
            else if (update_cxl_port_enable) begin
               cfg_cxl_port_enable  <= #TP cfg_cxl_port_enable_i;
            end
        end // cfg_cxl_port_enable_PROC

        reg  [1:0]    latched_poll_config_ts_retimer_pre;
        always @( posedge core_clk or negedge core_rst_n ) begin : latched_poll_config_ts_retimer_pre_PROC
            if ( ~core_rst_n )
               latched_poll_config_ts_retimer_pre  <= #TP 0;  
            else if (smlh_ltssm_state == S_CFG_LINKWD_ACEPT) begin
               latched_poll_config_ts_retimer_pre  <= #TP {link_latched_poll_config_ts_two_retimers_pre, link_latched_poll_config_ts_retimer_pre};
            end
        end // latched_poll_config_ts_retimer_pre_PROC

        ltssm_cxl_enable_t ltssm_cxl_enable_d;
        reg          cxl_sh_bypass_d;
        reg          cxl_mode_enable_d;
        reg          cxl_link_enable_d;
        reg  [1:0]   ltssm_cxl_ll_mod_d;
        reg          cxl_io_throttle_enable_d;
        wire         cxl_apn_bp;
        wire         common_clk          = cfg_pcie_slot_clk_config; // gate_cxl: connect to the same ref clock source, HwInit status reg
        wire         pcie_enable         = 1'b1; // gate_cxl: pcie mode is always enabled ?
        wire         cxl_io              = cxl_apn_bp ? 1'b1 : cfg_alt_protocol_enable_i ? 1'b1 : 1'b0; // capable
        wire         cxl_mem             = cfg_cxl_port_enable[1]; // capable
        wire         cxl_cache           = cfg_cxl_port_enable[0]; // capable
        wire         cxl_syncheader_bp_dis  = (~cfg_upstream_port && cxl_r20_v09_en && cxl_vh && cfg_cxl_retimers_pre_mismatched); // If CXL_Retimers_Present_Mismatched bit is set to 1, DSP retrains the link with the sync header bypass optimization disabled.
        assign       cxl_syncheader_bp   = app_sris_mode ? 1'b0 : cxl_syncheader_bp_dis ? 1'b0 : cfg_cxl_port_enable[2]; // if SRIS enabled, no SyncHeader Bypass
        wire         cxl_drift_buffer    = cfg_cxl_port_enable[3];
        assign       dsp_cxl_retimer1    = (cxl_vh) ? latched_poll_config_ts_retimer_pre[0] : cfg_cxl_port_enable[4];
        assign       dsp_cxl_retimer2    = (cxl_vh) ? latched_poll_config_ts_retimer_pre[1] : cfg_cxl_port_enable[5];
        assign       cxl_cache_en        = cfg_cxl_port_enable[6];
        assign       cxl_io_en           = cfg_cxl_port_enable[7];
        assign       cxl_mem_en          = cfg_cxl_port_enable[8];
        assign       cxl_apn_bp          = cfg_cxl_port_enable[9]; // Alternate Protocol Negotiation Bypass
        assign       cxl_vh              = cfg_cxl_port_enable[10]; // capable
        wire         multi_logical_dev   = cfg_cxl_port_enable[11]; // capable
        assign       cxl_vh_en           = cfg_cxl_port_enable[12] && cxl_vh;
        assign       multi_logical_dev_en  = cfg_cxl_port_enable[13] && cxl_vh && cxl_mem_en && !cxl_cache_en;
        wire         disable_r1p1_training = cfg_cxl_port_enable[14] && cxl_vh;
        wire         cxl_apn_sw_mode = cfg_cxl_port_enable[15] && cxl_vh; // use with SW
        assign       cxl_pbr_flit        = cfg_cxl_port_enable[16]; // capable
        assign       cxl_pbr_flit_en     = cfg_cxl_port_enable[17];
        wire         cxl_256b_lopt       = cfg_cxl_port_enable[18]; // capable
        assign       cxl_256b_lopt_en    = cfg_cxl_port_enable[19];
        wire         cxl_nop_hint        = cfg_cxl_port_enable[20]; // capable
        assign       cxl_nop_hint_en     = cfg_cxl_port_enable[21];
        wire         cxl_io_throttle_req = 1'b0; // Requested by Usp but not requested by DWC
        wire         fail_cxl_alt_prot_neg; // Fail CXL Alternate Protocol Negotiation
        assign       fail_cxl_alt_prot_neg = !cfg_upstream_port && disable_r1p1_training && (!cxl_vh_en || (link_latched_live_any_2_ts1_apn_rcvd && !link_latched_live_any_2_ts1_apn_sym14_8_rcvd[36])) && !ltssm_flit_mode_enable; // When set, DSP force to fail CXL Alternate Protocol Negotiation.
        assign       cxl_nop_hint_info_req = cxl_nop_hint && cxl_nop_hint_en ? `CX_CXL_TSOS_NOP_HINT : 2'b00; // Request a single NOP into remote device
        // Enable bits Field in Symbols 12-14 are set:
        //  - The downstream port and upstream port advertise their capability in Phase 1 as set in the Flex Bus Port Control register.
        //  - The downstream port communicates the results of the negotiation in Phase 2.
        wire  [9:0]  cxl20_flexbus_phase1;
        reg   [9:0]  cxl20_flexbus_phase2;
        assign cxl_r20_v09_en = 1'b1;
        assign cxl20_flexbus_phase1 = {cxl_nop_hint_info_req, cxl_io_throttle_req, cxl_256b_lopt_en, cxl_pbr_flit_en, multi_logical_dev_en, cxl_vh_en, cxl_cache_en, cxl_mem_en, cxl_io_en}
                                    & {2'b11,                 1'b1,                cxl_256b_lopt,    cxl_pbr_flit,    multi_logical_dev,    cxl_vh,    cxl_cache,    cxl_mem,    cxl_io};

        always @( posedge core_clk or negedge core_rst_n ) begin : cxl20_flexbus_phase2_PROC
            if ( ~core_rst_n )
                cxl20_flexbus_phase2 <= #TP 0;
            else if ( cfg_alt_protocol_enable_i) begin
                if (link_latched_live_any_2_ts1_apn_rcvd) begin
                    cxl20_flexbus_phase2[9:8] <= #TP 2'b00;                                                   // cxl_nop_hint_info (done duging Phase1)
                    cxl20_flexbus_phase2[7] <= #TP 1'b0;                                                      // cxl_io_throttle (done duging Phase1)
                    cxl20_flexbus_phase2[6] <= #TP mod_ts_sym14_12_rcvd[11] & cxl20_flexbus_phase1[6];        // cxl_256b_lopt
                    cxl20_flexbus_phase2[5] <= #TP mod_ts_sym14_12_rcvd[18] & cxl20_flexbus_phase1[5];        // cxl_pbr_flit
                    cxl20_flexbus_phase2[4] <= #TP mod_ts_sym14_12_rcvd[8] & cxl20_flexbus_phase1[4];         // multi_logical_dev
                    cxl20_flexbus_phase2[3] <= #TP mod_ts_sym14_12_rcvd[4] & cxl20_flexbus_phase1[3];         // cxl_vh
                    cxl20_flexbus_phase2[2:0] <= #TP mod_ts_sym14_12_rcvd[3:1] & cxl20_flexbus_phase1[2:0];   // cxl_cache_en, cxl_mem_en, cxl_io_en
                end
            end else begin
                cxl20_flexbus_phase2 <= #TP 0;
            end
        end // cxl20_flexbus_phase2_PROC

        wire [9:0]    cxl_cap_en         = (lts_state == S_CFG_COMPLETE) ?
                                           cxl20_flexbus_phase2 : cxl20_flexbus_phase1 // ts2 ? negotiation result (DSPvsUSP): enable
                                           ;
        ltssm_cxl_enable_t apn_bp_cxl_enable;
        assign       apn_bp_cxl_enable   = 
                                           {cxl_drift_buffer, cxl20_flexbus_phase1[9:3], cxl_syncheader_bp, cxl20_flexbus_phase1[2:0]}
                                           ;
        assign       ap                  = cfg_alt_protocol_enable_i ? 3'b010 : 3'b000; // Mod TS Usage mode = 010b for Alternate Protocol
        assign       apv_id              = cfg_alt_protocol_enable_i ? cfg_cxl_port_vid : 16'h0; // Alternate Protocol Vendor ID = cfg_cxl_port_vid for CXL
        assign       ap_id               = 3'b000; // Flex Bus = 3'b000 for Alternate Protocol ID
        assign       ap_info_id_match    =
                                          (link_latched_live_any_2_ts1_apn_sym14_8_rcvd[33]    == mod_ts_sym14_13_12[1] && mod_ts_sym14_13_12[1] == 1'b1 && // cxl_io must match and must be 1 for CXL
                                           link_latched_live_any_2_ts1_apn_sym14_8_rcvd[31:16] == mod_ts_sym11_10 && mod_ts_sym11_10 == cfg_cxl_port_vid && // AP Vendor ID must match and must be cfg_cxl_port_vid for CXL
                                           link_latched_live_any_2_ts1_apn_sym14_8_rcvd[7:5]  == mod_ts_sym9_8[7:5]);       // info 1 (AP details) must match only for Alternate Protocol ID = Flex Bus = 3'b000. Do not check the Common Clock and Reserved Bits
        assign       ap_ns               = ~cfg_alt_protocol_enable_i ? 2'b00 : ~cfg_upstream_port ? 2'b00 : (link_latched_live_any_2_ts1_apn_rcvd && ap_info_id_match) ? 2'b10 : link_latched_live_any_2_ts1_apn_rcvd ? 2'b01 : 2'b00; // Alternate Protocol Negotiation Status = 2-bit from PCI
        assign       mod_ts_sym9_8[2:0]  = ap;
        assign       mod_ts_sym9_8[4:3]  = ap_ns;
        assign       mod_ts_sym9_8[15:5] = {{7'b0000000, common_clk}, {ap_id}}; // mod ts info 1 (AP details)
        assign       mod_ts_sym11_10     = apv_id; // AP Vendor ID
        // mod ts info 2 (AP details)
        assign       mod_ts_sym14_13_12  = {5'h0,
                                            cxl_cap_en[5],        // PBR Flit Cap
                                            cxl_cap_en[9:8],      // NOP Hint
                                            cxl_cap_en[7],        // CXL.io Throttle
                                            3'h0,
                                            cxl_cap_en[6],        // LOPT Cap
                                            cxl_syncheader_bp,    // Sync Header Bypass
                                            1'b0,                 // 68B Enh Cap (Removed from CXL spec)
                                            cxl_cap_en[4],        // MLD Cap
                                            3'h0,
                                            cxl_cap_en[3:0],      // [3] Cxl68bFlitVh cap / [2:0] CXL.cache/mem/io Cap
                                            pcie_enable};         // PCIe Cap
        assign       ltssm_ts1_sym14_8   = ~cfg_upstream_port ? {mod_ts_sym14_13_12, mod_ts_sym11_10, mod_ts_sym9_8} : // DSP
                                                                ap_ns == 2'b10 ? {mod_ts_sym14_13_12, link_latched_live_any_2_ts1_apn_sym14_8_rcvd[31:5], ap_ns, ap} : // USP supports the requested protocol by DSP
                                                                ap_ns == 2'b01 ? {24'h0, link_latched_live_any_2_ts1_apn_sym14_8_rcvd[31:5], ap_ns, ap} :              // USP does not support the requested protocol by DSP
                                                                                 56'h0;                                                                                // USP has not received 2 mod ts1s
        reg          cxl_enable;
        always @( posedge core_clk or negedge core_rst_n ) begin : cxl_enable_PROC
            if ( ~core_rst_n )
                cxl_enable <= #TP 0;
            else if ( lts_state == S_DETECT_QUIET )
                cxl_enable <= #TP 0;
            else if ( cfg_alt_protocol_enable_i )
                cxl_enable <= #TP mod_ts_sym9_8[2:0] == 3'b010 & mod_ts_sym11_10 == cfg_cxl_port_vid & mod_ts_sym14_13_12[1] == 1'b1; // advertise Gen5 rate in Polling/Config states. CXL.io (mod_ts_sym14_13_12[1]) must be supported
        end // cxl_enable_PROC
        wire         cxl_io_throttle_enable_i = ts1_cxl_io_throtte_64g_enable;
        wire         common_clk_agred    = req_protocol_support_d & cxl_enable & ltssm_mod_ts_info_1[8]; // common clk agreed/negotiated between two sides
        wire         drift_buffer        = req_protocol_support_d & cxl_enable & cxl_drift_buffer & common_clk_agred; // must have common clock
        wire         syncheader_bypss    = req_protocol_support_d & cxl_enable & common_clk_agred & ts2_cxl_syncheader_bp_enable; // all ports support, common clk, no retimers /*, drift buffer*/
        wire         cxl_sh_bypass_i     = cxl_apn_bp ? cxl_io_en & apn_bp_cxl_enable[3] : req_protocol_support_d && cxl_enable && ts2_cxl_enable[0] ? syncheader_bypss : 1'b0; // It is used for internal mode signal for all modules
        ltssm_cxl_enable_t ltssm_cxl_enable_i; 
        assign       ltssm_cxl_enable_i  = ltssm_cxl_enable_d | (cxl_apn_bp ? {$bits(ltssm_cxl_enable_i){cxl_io_en}} & apn_bp_cxl_enable/* & {9{gtr_g2}}*/: req_protocol_support_d && cxl_enable/* && gtr_g2*/ && ts2_cxl_enable[0] ? {drift_buffer,                   // Drift buffer
                                                                                                                                                                                                                                 ts1_cxl_nop_hint_info,          // CXL NOP Hint info
                                                                                                                                                                                                                                 ts1_cxl_io_throtte_64g_enable,  // CXL_io_throttle_64g
                                                                                                                                                                                                                                 ts2_cxl_256b_lopt_enable,       // CXL_256B_LOpt_Flit
                                                                                                                                                                                                                                 ts2_cxl_pbr_flit_enable,        // CXL PBR Flit
                                                                                                                                                                                                                                 ts2_cxl_vh_enable,              // Multi-logical Dev/CXL 2.0
                                                                                                                                                                                                                                 syncheader_bypss,               // SyncHeader
                                                                                                                                                                                                                                 ts2_cxl_enable} : {$bits(ltssm_cxl_enable_i){1'b0}});       // Cache/Mem/IO
        wire         cxl_mode_enable_i   = cxl_mode_enable_d  | (cxl_apn_bp ? cxl_io_en/* & (gtr_g2)*/                         : req_protocol_support_d && cxl_enable/* && gtr_g2*/ && ts2_cxl_enable[0]);
        wire [1:0]   ltssm_cxl_ll_mod_i  = ltssm_cxl_ll_mod_d | (cxl_apn_bp ? {2{cxl_io_en}} & {cxl_drift_buffer, common_clk} & {2{gtr_g2}} : req_protocol_support_d && cxl_enable && gtr_g2 && ts2_cxl_enable[0] ? {drift_buffer, common_clk_agred} : 2'h0); //{driftbuffer, commonclock}

        reg          ltssm_in_cxl_mode; // breaking timing
        always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_in_cxl_mode_PROC
            if ( ~core_rst_n )
                ltssm_in_cxl_mode <= #TP 0;
            else
                ltssm_in_cxl_mode <= #TP (cxl_apn_bp & cxl_io_en) | (req_protocol_support_d & cxl_enable & ts2_cxl_enable[0]); // if reached cxl_mode, go speed change directly from Gen1 rate without waiting for DL_Active;
        end // ltssm_in_cxl_mode_PROC

        // latch ltssm_cxl_enable, cxl_mode_enable, ltssm_cxl_ll_mod until core_rst_n for upper layers to close cxl link gently
        always @( posedge core_clk or negedge core_rst_n ) begin : cxl_mode_d_PROC
            if ( ~core_rst_n ) begin
                ltssm_cxl_enable_d <= #TP '{default: '0};
                cxl_mode_enable_d  <= #TP 0;
                cxl_link_enable_d  <= #TP 0;
                ltssm_cxl_ll_mod_d <= #TP 0;
                cxl_sh_bypass_d    <= #TP 0;
                cxl_io_throttle_enable_d    <= #TP 0;
            end else if ( update_cxl_port_enable ) begin
                ltssm_cxl_enable_d <= #TP '{default: '0};
                cxl_mode_enable_d  <= #TP 0;
                cxl_link_enable_d  <= #TP 0;
                ltssm_cxl_ll_mod_d <= #TP 0;
                cxl_sh_bypass_d    <= #TP 0;
                cxl_io_throttle_enable_d    <= #TP 0;
            end else begin
                // Alternate protocol negotiation result. It will be set once alternate protocol negotiation is completed. It will be used as Enabled registers in Flex Bus Port Status.
                ltssm_cxl_enable_d <= #TP ltssm_cxl_enable_i;
                // CXL mode negotiation is completed before entering L0 at 2.5 GT/s
                cxl_mode_enable_d  <= #TP cxl_mode_enable_i;
                // To operate in CXL mode, the link speed must be at least 8 GT/s
                cxl_link_enable_d  <= #TP ( current_data_rate_d > `GEN2_RATE ) ? cxl_mode_enable_i  : cxl_link_enable_d; 
                // Internal mode signal for {driftbuffer, commonclock}. It will be set the link has transitioned to a speed of 8 GT/s or higher.
                ltssm_cxl_ll_mod_d <= #TP ( current_data_rate_d > `GEN2_RATE ) ? ltssm_cxl_ll_mod_i : ltssm_cxl_ll_mod_d;
                // Internal mode signal for Sync Headers bypass. It will be set the link has transitioned to a speed of 8 GT/s or higher.
                cxl_sh_bypass_d    <= #TP ( current_data_rate_d inside {`GEN3_RATE, `GEN4_RATE, `GEN5_RATE} ) ? cxl_sh_bypass_i : 1'b0;
                cxl_io_throttle_enable_d <= #TP ( g6_rate ) ? cxl_io_throttle_enable_i : 1'b0;
            end
        end // cxl_mode_d_PROC

        // break timing
        assign ltssm_cxl_enable = ltssm_cxl_enable_d;
        assign cxl_sh_bypass    = cxl_sh_bypass_d;
        assign ltssm_cxl_ll_mod = ltssm_cxl_ll_mod_d;
        assign cxl_io_throttle_enable = cxl_io_throttle_enable_d;

        // BCM36_nhs applies false path constraints to all paths in the design through cxl_mode_enable
        // Internal LTSSM logic MUST use cxl_mode_enable_d instead of cxl_mode_enable
        DWC_pcie_ctl_bcm36_nhs
         #(
          .WIDTH(2),
          .DATA_DELAY(DATA_DELAY_BCM36_NHS)
        ) u_bcm36_nhs_cxl_mode_enable (
        `ifndef SYNTHESIS
            .clk_d      (core_clk),
            .rst_d_n    (core_rst_n),
        `endif // SYNTHESIS
            .data_s     ({cxl_mode_enable_d, cxl_link_enable_d}),
            .data_d     ({cxl_mode_enable, cxl_link_enable})
        );

        reg [23:0] ltssm_cxl_mod_ts_phase1_rcvd_r;
        always @( posedge core_clk or negedge core_rst_n ) begin : cxl_cxl_mod_ts_phase1_rcvd_PROC
            if ( ~core_rst_n )
                ltssm_cxl_mod_ts_phase1_rcvd_r <= #TP 0;
            else if ( lts_state == S_DETECT_QUIET )
                ltssm_cxl_mod_ts_phase1_rcvd_r <= #TP 0;
            else if ( cfg_alt_protocol_enable_i && cxl_vh)
           
                ltssm_cxl_mod_ts_phase1_rcvd_r <= #TP (lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT) ? mod_ts_sym14_12_rcvd : ltssm_cxl_mod_ts_phase1_rcvd_r; // latched ts1_sym_14_13_12 during phase1 of CXL AP negotiation
        end // cxl_cxl_mod_ts_phase1_rcvd_PROC
        assign       ltssm_cxl_mod_ts_phase1_rcvd = ltssm_cxl_mod_ts_phase1_rcvd_r; // For CXL 2.0

        // both sides agreed the requested protocol (e.g. CXL) by DSP is supported by both sides
        always @( * ) begin : req_protocol_support_PROC
            req_protocol_support = req_protocol_support_d;

            if ( lts_state == S_DETECT_QUIET )
                req_protocol_support = 1'b0;
            else if ( cfg_upstream_port && ap_ns == 2'b10 )
                req_protocol_support = 1'b1;
            else if ( ~cfg_upstream_port && link_latched_live_any_2_ts1_apn_sym14_8_rcvd[4:3] == 2'b10 && ~fail_cxl_alt_prot_neg )
                req_protocol_support = 1'b1;
        end // req_protocol_support_PROC

        always @( posedge core_clk or negedge core_rst_n ) begin : req_protocol_support_d_PROC
            if ( ~core_rst_n )
                req_protocol_support_d <= #TP 1'b0;
            else
                req_protocol_support_d <= #TP req_protocol_support;
        end // req_protocol_support_d_PROC

        always @( posedge core_clk or negedge core_rst_n ) begin : req_protocol_respond_d_PROC
            if ( ~core_rst_n )
                req_protocol_respond_d <= #TP 1'b0;
            else if ( clear )
                req_protocol_respond_d <= #TP 1'b0;
            else if ( link_latched_live_any_2_ts1_apn_sym14_8_rcvd[4:3] == 2'b10 || link_latched_live_any_2_ts1_apn_sym14_8_rcvd[4:3] == 2'b01 || smlh_link_up == 1'b1 )
                req_protocol_respond_d <= #TP 1'b1;
        end // req_protocol_respond_d_PROC

        always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_mod_ts_info_1_PROC
            if ( ~core_rst_n ) begin
                ltssm_mod_ts_info_1 <= #TP 0;
                latched_dsp_cxl_non_aware_retimer_rcvd <= #TP 0;
            end else if ( lts_state == S_DETECT_QUIET ) begin
                ltssm_mod_ts_info_1 <= #TP 0;
                latched_dsp_cxl_non_aware_retimer_rcvd <= #TP 0;
            end else if ( req_protocol_support && ~req_protocol_support_d ) begin
                ltssm_mod_ts_info_1 <= #TP mod_ts_sym9_8 & mod_ts_sym9_8_rcvd;
                latched_dsp_cxl_non_aware_retimer_rcvd <= #TP ~cfg_upstream_port                               // Downstream Port
                                                            & ( (dsp_cxl_retimer1 & ~mod_ts_sym14_12_rcvd[12]) // (retimer1 present) and (retimer1 not cxl aware)
                                                              | (dsp_cxl_retimer2 & ~mod_ts_sym14_12_rcvd[14]) // (retimer2 present) and (retimer2 not cxl aware)
                                                              );                                               // Tied into 0 on Usp
            end
        end // ltssm_mod_ts_info_1_PROC

        // CXL APN Phase 1 (TS1)
        always @* begin : ltssm_mod_ts_info_2_PROC
            ltssm_mod_ts_info_2 = ltssm_mod_ts_info_2_d;

            if ( lts_state == S_DETECT_QUIET )
                ltssm_mod_ts_info_2 = 0;
            else if ( req_protocol_support && ~req_protocol_support_d ) begin
                ltssm_mod_ts_info_2 = mod_ts_sym14_13_12 & mod_ts_sym14_12_rcvd;
            end
        end // ltssm_mod_ts_info_2_PROC

        always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_mod_ts_info_2_d_PROC
            if ( ~core_rst_n )
                ltssm_mod_ts_info_2_d <= #TP 0;
            else
                ltssm_mod_ts_info_2_d <= #TP ltssm_mod_ts_info_2;
        end // ltssm_mod_ts_info_2_d_PROC

        // PCIe mode and CXL mode are mutually exclusive; when the CPU communicates the results of the negotiation in Phase 2 (TS2)
        // mod_ts_info_2_i[0] = PCIe mode, mod_ts_info_2_i[1] = CXL.io (CXL mode)
        assign mod_ts_info_2_i_bit18_pbr = ltssm_mod_ts_info_2[18] & mod_ts_sym14_13_12[18] & ltssm_flit_mode_enable;
        assign mod_ts_info_2_i   = {(ltssm_mod_ts_info_2[23:19] & mod_ts_sym14_13_12[23:19])
                                   ,(mod_ts_info_2_i_bit18_pbr)                                                                                                                    // PBR Flit
                                   ,(ltssm_mod_ts_info_2[17:12] & mod_ts_sym14_13_12[17:12])
                                   ,(ltssm_mod_ts_info_2[11]    & mod_ts_sym14_13_12[11] & ~mod_ts_info_2_i_bit18_pbr & ltssm_flit_mode_enable)  // Latency Optimized Flit mode (disabled if PBR=1)
                                   ,(ltssm_mod_ts_info_2[10]    & mod_ts_sym14_13_12[10] & ~latched_dsp_cxl_non_aware_retimer_rcvd)                                                // Sync Header Bypass
                                   ,(ltssm_mod_ts_info_2[9:5]   & mod_ts_sym14_13_12[9:5])
                                   ,(ltssm_mod_ts_info_2[4]     & mod_ts_sym14_13_12[4] & ~ltssm_flit_mode_enable)                              // CXL 68B & VH Capable (CXL2.0 Capable)
                                   ,(ltssm_mod_ts_info_2[3:0]   & mod_ts_sym14_13_12[3:0])};

        // usp: acknowledges the same enable bits after Rx TS2. here use lane 0 because the link width is determined and reliable and logical lane 0 must be included in Cfg.Complete state.
        // usp: if use Rx 8 TS2s and then send back the enable bits, it is too late because the remote dsp may be in the next Cfg.Idle state.
        // usp: the logical lane 0 TX and RX must work reliably in Cfg.Complete state. it is safe to use logical lane 0.
        always_comb begin : mod_ts_info_2_PROC
          if (lts_state == S_CFG_COMPLETE) begin
             if (~cfg_upstream_port) begin // Phase2 DSP
               if (mod_ts_info_2_i[1]) begin
                 mod_ts_info_2 = {mod_ts_info_2_i[23:1], 1'b0}; // If CXL.io en=1, PCIe en=0
               end else begin
                 mod_ts_info_2 = {mod_ts_info_2_i[23:1], 1'b1};
               end
             end else begin // Phase2 USP
               mod_ts_info_2[23:19] = mod_ts_info_2_i[23:19];
               mod_ts_info_2[18]    = mod_ts_info_2_i[18]   & link_latched_live_all_2_ts2_apn_sym14_8_rcvd[32+18];        // [18]PBR Flit
               mod_ts_info_2[17:12] = mod_ts_info_2_i[17:12];
               mod_ts_info_2[11:0]  = mod_ts_info_2_i[11:0] & link_latched_live_all_2_ts2_apn_sym14_8_rcvd[43:32];        // [11]LOpt-[0]PCIeCap
             end
           end else begin
             mod_ts_info_2 = mod_ts_info_2_i;
           end
        end // mod_ts_info_2_PROC

        assign ltssm_ts2_sym14_8 = req_protocol_support ? {mod_ts_info_2, mod_ts_sym11_10, mod_ts_sym9_8[15:5], 2'b00, ap} : 56'h0;

//        assign       ltssm_ts2_sym14_8   = req_protocol_support ? {(ltssm_mod_ts_info_2 & mod_ts_sym14_13_12), mod_ts_sym11_10, mod_ts_sym9_8[15:5], 2'b00, ap} : 56'h0;

        reg [NL-1:0] ltssm_ap_success_bus;
        reg [NL-1:0] ltssm_flexbus_matched_bus;
        reg [NL-1:0] ltssm_retimers_pre_matched_bus;
        wire   [1:0] cxl_20_dsp_apn_mismatched;
        reg    [1:0] cxl_20_dsp_apn_mismatched_d;

        always @* begin : ltssm_ap_success_bus_PROC
            integer ln;

            ltssm_ap_success_bus = 0;
            for ( ln=0; ln<NL; ln=ln+1 ) begin
                ltssm_ap_success_bus[ln] = ((link_latched_live_all_8_ts2_apn_sym14_8_rcvd[ln*56 +: 32] & 32'hFFFF00FF) == ({mod_ts_sym11_10, mod_ts_sym9_8[15:5], 2'b00, ap} & 32'hFFFF00FF)) & (ap == 3'b010) & req_protocol_support_d; // no check sym9 including common_clk
                if(latchd_smlh_lanes_rcving[ln] && ltssm_ap_success_bus[ln]) begin
                    ltssm_flexbus_matched_bus[ln]      = ((link_latched_live_all_8_ts2_apn_sym14_8_rcvd[(ln*56)+32 +: 24] & 24'h40D1F) == (ltssm_ts2_sym14_8[32 +: 24] & 24'h40D1F));
                    ltssm_retimers_pre_matched_bus[ln] = ((link_latched_ts_retimer_pre      == latched_poll_config_ts_retimer_pre[0])   // Retimer1 CXL aware
                                                       && (link_latched_ts_two_retimers_pre == latched_poll_config_ts_retimer_pre[1])
                                                         ); // Retimer2 CXL aware
                end else begin // no check
                    ltssm_flexbus_matched_bus[ln]      = 1'b1;
                    ltssm_retimers_pre_matched_bus[ln] = 1'b1;
                end
            end
        end // ltssm_ap_success_bus_PROC

         // DSP LTSSM returns to Detect state
         // Set to 0 when Upstream port, CXL 2.0 disable, CXL r2.0 v0.9 disable, TS alternate protocol disable or alternate protocol not support
        assign cxl_20_dsp_apn_mismatched = (cfg_upstream_port || ~mod_ts_sym14_13_12[4] || ~cxl_r20_v09_en || ~ltssm_ts_alt_protocol_i || ~req_protocol_support_d) ? 2'd0 :
                                           {(cfg_cxl_retimers_pre_mismatched) ? 1'b0 : ~(&ltssm_retimers_pre_matched_bus),
                                            ~(&ltssm_flexbus_matched_bus)};

        // Set errors in the DVSEC Flex Bus Port Status register
        always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_cxl_mismatched_PROC
            if ( ~core_rst_n ) begin
                cxl_20_dsp_apn_mismatched_d <= #TP 0;
            end else begin
                cxl_20_dsp_apn_mismatched_d <= #TP (cfgcmpl_all_8_ts2_rcvd) ? cxl_20_dsp_apn_mismatched : 0;
            end
        end // ltssm_cxl_mismatched_PROC
       assign  ltssm_cxl_flexbus_phase2_mismatched = cxl_20_dsp_apn_mismatched_d[0];
       assign  ltssm_cxl_retimers_pre_mismatched   = cxl_20_dsp_apn_mismatched_d[1];

        always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_ap_success_PROC
            if ( ~core_rst_n ) begin
                ltssm_ap_success <= #TP 0;
                ts1_cxl_io_throtte_64g_enable <= #TP 0;
                ts1_cxl_nop_hint_info <= #TP 0;
                ts2_cxl_enable   <= #TP 0;
                ts2_cxl_vh_enable <= #TP 0;
                ts2_cxl_pbr_flit_enable <= #TP 0;
                ts2_cxl_syncheader_bp_enable <= #TP 0;
                ts2_cxl_256b_lopt_enable <= #TP 0;
            end else if ( lts_state == S_DETECT_QUIET ) begin
                ltssm_ap_success <= #TP 0;
                ts1_cxl_io_throtte_64g_enable <= #TP 0;
                ts1_cxl_nop_hint_info <= #TP 0;
                ts2_cxl_enable   <= #TP 0;
                ts2_cxl_vh_enable <= #TP 0;
                ts2_cxl_pbr_flit_enable <= #TP 0;
                ts2_cxl_syncheader_bp_enable <= #TP 0;
                ts2_cxl_256b_lopt_enable <= #TP 0;
            end else if ( cfgcmpl_all_8_ts2_rcvd && ltssm_ts_alt_protocol_i ) begin
              if(|cxl_20_dsp_apn_mismatched) begin // DSP returns to Detect.
                ltssm_ap_success <= #TP 0;
                ts1_cxl_io_throtte_64g_enable <= #TP 0;
                ts1_cxl_nop_hint_info <= #TP 0;
                ts2_cxl_enable   <= #TP 0;
                ts2_cxl_vh_enable <= #TP 0;
                ts2_cxl_pbr_flit_enable <= #TP 0;
                ts2_cxl_syncheader_bp_enable <= #TP 0;
                ts2_cxl_256b_lopt_enable <= #TP 0;
              end else 
              begin
                ltssm_ap_success <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus);
                ts1_cxl_io_throtte_64g_enable <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? link_latched_live_any_2_ts1_apn_sym14_8_rcvd[32+15] & (~cfg_upstream_port) : ts1_cxl_io_throtte_64g_enable; // Dsp logs the value.
                ts1_cxl_nop_hint_info <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? link_latched_live_any_2_ts1_apn_sym14_8_rcvd[32+16+:2] : ts1_cxl_nop_hint_info;
                ts2_cxl_enable   <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? link_latched_live_all_8_ts2_apn_sym14_8_rcvd[35:33] & {cxl_cache_en, cxl_mem_en, cxl_io_en} : ts2_cxl_enable;
                ts2_cxl_vh_enable <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? {link_latched_live_all_8_ts2_apn_sym14_8_rcvd[32+8],link_latched_live_all_8_ts2_apn_sym14_8_rcvd[32+4]} & {multi_logical_dev_en,cxl_vh_en} : ts2_cxl_vh_enable;
                ts2_cxl_pbr_flit_enable <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? link_latched_live_all_8_ts2_apn_sym14_8_rcvd[32+18] & cxl_pbr_flit_en : ts2_cxl_pbr_flit_enable;
                ts2_cxl_syncheader_bp_enable <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? link_latched_live_all_8_ts2_apn_sym14_8_rcvd[32+10] & cxl_syncheader_bp : ts2_cxl_syncheader_bp_enable;
                ts2_cxl_256b_lopt_enable <= #TP &(~latchd_smlh_lanes_rcving | ltssm_ap_success_bus) ? link_latched_live_all_8_ts2_apn_sym14_8_rcvd[32+11] & cxl_256b_lopt_en : ts2_cxl_256b_lopt_enable;
              end
            end
        end // ltssm_ap_success_PROC



reg     [2:0]       latched_l0_speed;               // The speed on entering Recovery from L0 or L1
reg                 latched_lane_reversed;
reg     [5:0]       int_smlh_link_mode;             // 6 bits indicate the active lanes and final negotiated link width
reg                 link_mode_changed;
reg     [5:0]       linkup_link_mode;               // Latched link_mode of initial linkup
reg     [5:0]       latest_link_mode;               // Latched link_mode of latest config state
reg                 ltssm_lanes_activated_pulse;
wire                ltssm_mid_config_state;
reg                 ltssm_lane_flip_ctrl_chg_pulse_d;
reg                 deskew_lanes_active_change;
wire                update_deskew_lanes_active;
wire    [NL-1:0]    next_deskew_lanes_active;
reg                 r_ltssm_rcvr_err_rpt_en;
reg     [4:0]       ltssm_ts_data_rate_int;
reg                 int_compliance_rcv;

assign              latched_ts_data_rate_eg6 = latched_ts_data_rate == 5'b10111 ? 10'b0000111111 : {5'h0, latched_ts_data_rate};
wire                link_num_match;
integer             j;
reg                 r_rcvd_at_least_1ts;
wire                cfg_force_lane_flip, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts;
wire                cfg_mod_ts_i;
wire [3:0]          cfg_lane_under_test;
wire                lut_en;
wire [4:0]          lut_ctrl;
assign {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts} = cfg_lut_ctrl;
wire   ltssm_master_lpbk_active_after_g5_lpbk_eq = lpbk_lane_under_test[4];
// if cfg_force_lane_flip = 1, force the physical lane cfg_lane_under_test flip to logical lane 0.
// Else if loopback master in Loopback.Active at Gen5 rate following Loopback Eq, flip the physical lane cfg_lane_under_test to logical lane 0.
assign lut_en   = cfg_force_lane_flip ? 1'b1 : ltssm_master_lpbk_active_after_g5_lpbk_eq ? 1'b1 : 1'b0;
assign lut_ctrl = {lut_en, cfg_lane_under_test};

wire   cfg_selectable_deemph_bit_mux, cfg_select_deemph_var_mux; // {mux for selectable deemphasis bit for Tx TS2 in Rcvry.RcvrCfg, mux for select_deemphasis variable}
assign {cfg_selectable_deemph_bit_mux, cfg_select_deemph_var_mux} = cfg_select_deemph_mux_bus;
reg  precoding_on;
wire cfg_precode_request = cfg_tx_precode_req; // from CDM
reg  int_precoding_on;                         // precode is on at Gen5 or higher rate with sticky
reg  int_deprecoding_on;                       // de-precoding is on at Gen5 or higher rate with sticky
reg  precoding6_on;
reg  int_precoding6_on;                         // precode is on at Gen6 or higher rate with sticky
reg  int_deprecoding6_on;                       // de-precoding is on at Gen6 or higher rate with sticky

// ----------------------------------------------------------------------------
// internal Regs
// ----------------------------------------------------------------------------

reg     [2:0]       gen3_speed_cmpl;
reg     [3:0]       gen3_cmpl_tx_preset;
wire    [3:0]       cycle_gen3_compliance_tx_preset;
wire                gen2_deemphasis;
wire   [BAC_WD-1:0] int_ltssm_blockaligncontrol;
reg                 lpbk_active_entered_unaligned;
reg                 rcvd_8_ts2_s6;
reg                 latched_idle_to_rcvrylock;
reg     [1:0]       rlock_ts1_cnt;

reg                 speed_cmpl;
reg                 directed_speed_change_r;
reg                 ltssm_ts_spd_chg_rcvd_clr_int;

reg                 retry_detect; // this is used to allow one time retry receiver detect
wire    [NL-1:0]    int_rxdetected;                 // RMLH reports the received detected
wire                int_rxdetect_done;              // RMLH indicates the cycle to sample phy_mac_rxdetected
reg                 update_lanes_active;
typedef enum logic [1:0] {
  S_L0S_RCV_ENTRY   = 2'b00,
  S_L0S_RCV_IDLE    = 2'b10,
  S_L0S_RCV_FTS     = 2'b11
} l0s_rcv_state_e;
l0s_rcv_state_e    curnt_l0s_rcv_state;    // Current Rx_L0s substate (Entry, Idle or FTS)
l0s_rcv_state_e    r_curnt_l0s_rcv_state;  // registered curnt_l0s_rcv_state

typedef enum logic [2:0] {
  S_L0S_XMT_ENTRY   = 3'b000,
  S_L0S_XMT_WAIT    = 3'b001,
  S_L0S_XMT_IDLE    = 3'b010,
  S_L0S_XMT_FTS     = 3'b011,
  S_L0S_XMT_EIDLE   = 3'b100,
  S_L0S_EXIT_WAIT   = 3'b101
} l0s_xmt_state_e;
l0s_xmt_state_e    curnt_l0s_xmt_state;
l0s_xmt_state_e    next_l0s_xmt_state;

typedef enum logic [2:0] {
  S_COMPL_IDLE               = 3'b000,   // Start here on entering Polling.Compliance
  S_COMPL_ENT_TX_EIDLE       = 3'b001,   // send EIDLE ordered set in preparation for link speed change
  S_COMPL_ENT_SPEED_CHANGE   = 3'b010,   // Change speed to Gen II
  S_COMPL_TX_COMPLIANCE      = 3'b011,   // Transmit compliance pattern
  S_COMPL_EXIT_TX_EIDLE      = 3'b100,   // send EIDLE ordered set in preparation for link speed change
  S_COMPL_EXIT_SPEED_CHANGE  = 3'b101,   // Change speed to Gen I
  S_COMPL_EXIT_IN_EIDLE      = 3'b110,   // Enter EIDLE for 1ms
  S_COMPL_EXIT               = 3'b111    // Exit compliance
} compliance_state_e;
compliance_state_e  curnt_compliance_state, curnt_compliance_state_d1, next_compliance_state; // State machine for polling compliance


typedef enum logic [1:0] {
  S_LPBK_ENTRY_IDLE   = 2'h0,   // Idle
  S_LPBK_ENTRY_ADV    = 2'h1,   // Advertise Loopback
  S_LPBK_ENTRY_EIDLE  = 2'h2,   // Send Electrical Idle and change speed
  S_LPBK_ENTRY_TS     = 2'h3    // Send TS1s
} lpbk_entry_state_e;
lpbk_entry_state_e  curnt_lpbk_entry_state, next_lpbk_entry_state;   // State machine for loopback entry
reg                 lpbk_clear;
reg                 lpbk_clear_wire;

reg     [10:0]      ts_sent_cnt;
reg     [5:0]       idle_sent_cnt;
wire                cfg_flit_mode_enable_i = cfg_pcie_cap_flit_mode_sup & ~cfg_flit_mode_dis;
reg                 ts_sent_in_poll_active;         // indicates that TSs were sent in Polling.Active
reg                 latched_ts1_sent;
reg     [1:0]       all_rcvd_ts1cnt_g3;
reg     [4:0]       rcvd_expect_tscnt;
reg     [4:0]       rcvd_expect_ts1cnt;
reg     [4:0]       r_rcvd_expect_ts1cnt;
reg     [4:0]       rcvd_expect_ts2cnt;
reg     [4:0]       r_rcvd_expect_ts2cnt;
reg     [4*NL-1:0]  rcvd_eidle_cnt;
reg                 rcvd_4eidle;
reg     [4:0]       all_rcvd_expect_tscnt;
reg     [4:0]       all_rcvd_expect_ts2cnt;
reg     [4:0]       rcvd_unexpect_ts1cnt;
reg     [4:0]       rcvd_unexpect_ts2cnt;
reg     [7:0]       idle_to_rlock;
reg                 use_modified_ts;
reg                 latched_tx_flitm_ts;
reg                 latched_tx_modified_ts;
reg                 start_equalization_w_preset;       // start_equalization_w_preset LTSSM variable
reg                 equalization_done_8gt_data_rate;   // equalization_done_8GT_data_rate LTSSM variable
reg                 equalization_done_16gt_data_rate;  // equalization_done_16GT_data_rate LTSSM variable
reg                 equalization_done_32gt_data_rate;  // equalization_done_16GT_data_rate LTSSM variable
reg                 eq_to_rspeed_g5 ;
reg                 eq_to_rspeed_g4 ;
wire                lpbk_eq_done;
reg                 equalization_done_64gt_data_rate;  // equalization_done_64GT_data_rate LTSSM variable
reg                 eq_to_rspeed_g6 ;
reg                 latched_eqos_usp_send_maxspeed ;
wire                cond_eqos_usp_send_maxspeed ;
reg                 latchecd_eqctl_8g4eqts1_rcvd ;
reg                 latchecd_eqctl_8g5eqts1_rcvd ;
reg                 latchecd_eqctl_8g6eqts1_rcvd ;
wire                set_init_eq_pending;               //
reg                 init_usp_eq_pending;               // Initial 8GT Equalization Pending
wire                equalization_req;                  // Equalization Request
wire                set_directed_equalization_g3;
wire                clr_directed_equalization_g3;
reg                 directed_equalization_g3;          // Directed Equalization
wire                set_directed_equalization_g4_skipeq;
wire                clr_directed_equalization_g4_skipeq;
reg                 directed_equalization_g4_skipeq;          // Directed Equalization
wire                set_directed_equalization_g4;
wire                clr_directed_equalization_g4;
reg                 directed_equalization_g4;          // Directed Equalization
wire                set_latched_remote_soft_eq_g4;
wire                clr_latched_remote_soft_eq_g4;
reg                 latched_remote_soft_eq_g4;         // For DSP signal. Latched remote gen4 support while exiting from gen3 soft_eq_phase
reg     [3:0]       gen4_cmpl_jmp;                     // selects Jitter Measurment Pattern
reg     [3:0]       gen6_cmpl_tp;          // selects Toggle Pattern
wire                set_directed_equalization_g5;
wire                clr_directed_equalization_g5;
reg                 directed_equalization_g5;          // Directed Equalization
wire                set_latched_remote_soft_eq_g5;
wire                clr_latched_remote_soft_eq_g5;
reg                 latched_remote_soft_eq_g5;         // For DSP signal. Latched remote gen4 support while exiting from gen3 soft_eq_phase
wire                set_directed_equalization_g5_skipeq;
wire                clr_directed_equalization_g5_skipeq;
reg                 directed_equalization_g5_skipeq;          // Directed Equalization
wire                set_directed_equalization_g6;
wire                clr_directed_equalization_g6;
reg                 directed_equalization_g6;          // Directed Equalization
wire                set_latched_remote_soft_eq_g6;
wire                clr_latched_remote_soft_eq_g6;
reg                 latched_remote_soft_eq_g6;         // For DSP signal. Latched remote gen4 support while exiting from gen3 soft_eq_phase
wire                eq_pending_clear;
wire                set_auto_eq_phase_flag;
wire                clr_auto_eq_phase_flag;
reg                 auto_eq_phase_flag_ff;
wire                soft_eq_phase_flag_nomask;
wire                set_soft_eq_phase_flag;
wire                clr_soft_eq_phase_flag;
reg                 soft_eq_phase_flag_ff;
wire                set_redo_eq_phase_g3;
wire                clr_redo_eq_phase_g3;
reg                 redo_eq_phase_g3_ff;
wire                redo_eq_phase_g3;
wire                set_redo_eq_phase_g4;
wire                clr_redo_eq_phase_g4;
reg                 redo_eq_phase_g4_ff;
wire                redo_eq_phase_g4;
wire                set_redo_eq_phase_step0;
wire                set_redo_eq_phase_step1;
wire                set_redo_eq_phase_g5;
wire                clr_redo_eq_phase_g5;
reg                 redo_eq_phase_g5_ff;
wire                redo_eq_phase_g5;
wire                set_soft_gen4_eq_phase_flag;
wire                clr_soft_gen4_eq_phase_flag;
reg                 soft_gen4_eq_phase_flag_ff;
wire                soft_gen4_eq_phase_flag;
wire                set_redo_eq_phase_g6;
wire                clr_redo_eq_phase_g6;
reg                 redo_eq_phase_g6_ff;
wire                redo_eq_phase_g6;
wire                set_soft_gen5_eq_phase_flag;
wire                clr_soft_gen5_eq_phase_flag;
reg                 soft_gen5_eq_phase_flag_ff;
wire                soft_gen5_eq_phase_flag;
wire                set_redo_eq_phase_flag;
wire                clr_redo_eq_phase_flag;
wire                redo_eq_phase_flag_ff;
wire    [2:0]       redo_eq_target_rate;               // 0-gen1 1-gen2 2-gen3 3-gen4
wire    [2:0]       redo_eq_target_rate_ff;            // 0-gen1 1-gen2 2-gen3 3-gen4
wire    [3:0]       redo_eq_target_link_speed;         // 1-gen1 2-gen2 3-gen3 4-gen4
wire    [1:0]       redo_eq_phase_step;                // [0]step1 : only change speed / [1]step2 : do equalization with or without speed change
                                                       //  gen3 request in gen1/2 : [1]step2 : change speed to gen3 and do equalization
                                                       //  gen3 request in gen3   : [1]step2 : do equalization
                                                       //  gen3 request in gen4   : [0]step1 : change speed to gen3 [1]step2 : do equalization without speed change
                                                       //  gen4 request in gen1/2 : [0]step1 : change speed to gen3 [1]step2 : change speed to gen4 and do equalization
                                                       //  gen4 request in gen3   : [1]step2 : change speed to gen4 and do equalization
                                                       //  gen4 request in gen4   : [1]step2 : do equalization
reg     [1:0]       redo_eq_phase_step_ff;
wire                set_init_eq_pending_g4;            //
wire                set_init_eq_pending_g5;            //
wire                set_init_eq_pending_g6;            //
wire                set_init_eq_pending_g6_skipeq;     // skip eq
reg                 init_eq_pending_g6_skipeq;         // skip eq Initial 32GT Equalization Pending
wire                set_init_eq_pending_g5_skipeq;     // skip eq
reg                 init_eq_pending_g5_skipeq;         // skip eq Initial 32GT Equalization Pending
wire                set_init_eq_pending_g4_skipeq;     //
reg                 init_eq_pending_g4_skipeq;         // Initial 16GT Equalization Pending
wire                set_init_eq_pending_g3_skipeq;     //
reg                 init_eq_pending_g3_skipeq;         // Initial 8GT Equalization Pending
reg                 ts_128_sent;
wire                speed_change_pulse;

reg     [NL-1:0]    latched_rxeidle_exit_detected;
reg     [NL-1:0]    latched_rxeidle;
wire                any_predet_lane_latched_rxeidle;
reg                 l0s_state_clear;
wire                clr_timer_4rl0s;       // indicates when timer should be cleared when transitioning from L0 to Rx_L0s
wire                l0s_rcv_idle, l0s_rcv_entry, l0s_rcv_fts;        // Rx_L0s substates
reg                 r_l0s_rcv_idle, r_l0s_rcv_entry, r_l0s_rcv_fts;  // 1 cycle delayed Rx_L0s substates
wire                clr_l0s_rcv;                                     // clear pulse when changing Rx_L0s substates
reg                 rcvr_l0s_goto_rcvry;
reg     [NL-1:0]    latchd_rxeidle_exit;
reg                 latched_eidle_seen;
reg                 latched_eidle_inferred;
reg     [T_WD-1:0]  timer;
reg     [9:0]       timer_40ns_4rl0s;      // expanded for rasdes
reg                 latched_cdm_ras_des_recovery_req;  // rx recovery request detection
ltssm_state_e       latched_next_lts_state;
reg                 latched_next_lts_flag;
wire    [T_WD-1:0]  polling_timeout_value;
reg     [18:0]      speed_timer;
reg                 timeout_1ms;
reg                 timeout_1us;
reg                 timeout_10us;
reg                 timeout_16us;
reg                 timeout_esm_10us;
reg                 timeout_esm_50us;
reg                 timeout_esm_100us;
reg                 timeout_esm_500us;
reg                 timeout_esm_1ms;
reg                 timeout_esm_5ms;
reg                 timeout_esm_10ms;
reg                 timeout_esm_50ms;
wire                timeout_cali;
wire                esm_quiet_calibration;
wire                esm_quiet_cal_no_clk_gate;
reg                 timeout_2ms;
reg                 timeout_3ms;
reg                 timeout_2ms_d;
wire                int_timeout_2ms_rising_edge;
reg                 ds_timeout_2ms;
reg                 timeout_10ms;
reg                 timeout_12ms;
reg                 timeout_12ms_d;
reg                 int_timeout_12ms_rising_edge;
reg                 timeout_24ms;
reg                 timeout_24ms_d;
reg                 int_timeout_24ms_rising_edge;
wire                ltssm_eq_slave_timeout;
wire                ltssm_eq_master_timeout;
reg     [4:0]       timer_24ms_cnt_i;
reg                 timeout_32ms;
reg                 timeout_48ms;
reg                 timeout_64ms;
reg                 timeout_nfts;
reg                 speed_timeout_800ns;
reg                 speed_timeout_6us;
reg                 speed_timeout_1ms;

reg                 rcvd_8idles;
reg                 rcvd_1idle;
reg                 rcvd_8expect_ts;
reg                 rcvd_8expect_ts2;
reg                 all_rcvd_8expect_ts;
reg                 all_rcvd_8expect_ts2;
reg                 rcvd_atleast1_expect_ts;
reg                 rcvd_8unexpect_ts1;
reg                 ts_2_sent;
reg                 ts_16_sent;
reg                 ts_1024_sent;
reg                 ts_rcvd_1024_sent;
reg                 ts_1024_sent_d;
wire                ts_1024_sent_rising_edge;
reg                 idle_16_sent;
reg                 latched_eidle_sent;
reg     [NL-1:0]    int_latched_smlh_inskip_rcv;
reg                 latched_smlh_inskip_rcv;
reg     [NL-1:0]    latched_smlh_sds_rcvd;
wire                latched_all_smlh_sds_rcvd;
reg     [7:0]       xmt_ts_lnknum;
reg     [7:0]       latched_xmt_ts_lnknum;
wire   [(NL*8)-1:0] xmt_ts_lnknum_bus;
wire                smlh_all_lanes_rcvd;
reg                 latched_any_lane_8expect_ts_rcvd;
wire                smlh_ts_rcvd;
reg     [NL-1:0]    latchd_lanes_rcving_lpbk;


wire                rcvry_idle_consecutive_ts;
wire                rcvd_2rst_i;
reg                 rcvd_2rst;
reg                 rcvd_2dis;
reg                 rcvd_2lpbk;
reg                 rcvd_2lpbk_cmplrcv;

reg                 rcvd_2lannum_pad;
reg                 rcvd_2lnknum_pad;
reg                 rcvd_2lnknum_nonpad;
reg                 rcvd_2lannum_nonpad;
reg                 rcvd_2_lane_num_match;
reg                 rcvd_2lannum_nonpad_ts2;
reg                 latched_ts1_rcv;
reg                 latched_ts1_rcvd;
reg                 latched_cl_ts1_rcv;
reg                 latched_ts2_rcv;
reg                 latched_ts2_rcvd;

//consecutive 8 or 2 TSs
reg     [NL-1:0]    rcvd_8ts_sym6_match;
reg     [NL-1:0]    rcvd_2ts1_sym6_match;
reg     [NL-1:0]    rcvd_8ts1_sym6_match;
reg     [NL-1:0]    rcvd_2ts2_sym6_match;
reg     [NL-1:0]    rcvd_8ts2_sym6_match;
reg     [NL-1:0]    rcvd_2ts1_s6s9_match;
reg     [NL-1:0]    rcvd_8ts1_s6s9_match;
reg     [NL-1:0]    rcvd_2ts2_s6s9_match;
reg     [NL-1:0]    rcvd_8ts2_s6s9_match;
wire                all_rcvd_8ts_sym6_match;
wire                any_rcvd_8ts_sym6_match;

wire                all_rcvd_cnsc_8ts_sym6;
wire                any_rcvd_cnsc_8ts_sym6;

wire                any_rcvd_2ts1_sym6_match;

wire                any_rcvd_8ts1_sym6_match;
wire                all_rcvd_8ts2_sym6_match;
wire                any_rcvd_8ts2_sym6_match;

wire                all_cfg_subset_rcvd_2ts1_sym6_match;
wire                all_cfg_rcvd_2ts1_sym6_match;
wire                any_cfg_rcvd_2ts1_sym6_match;
wire                all_cfg_rcvd_2ts2_sym6_match;
wire                any_cfg_rcvd_2ts2_sym6_match;

wire                all_cfg_rcvd_8ts2_sym6_match;

wire                any_rcvd_2ts1_s6s9_match;

wire                any_rcvd_8ts1_s6s9_match;
wire                all_rcvd_8ts2_s6s9_match;
wire                any_rcvd_8ts2_s6s9_match;

wire                all_cfg_subset_rcvd_2ts1_s6s9_match;
wire                all_cfg_rcvd_2ts1_s6s9_match;
wire                any_cfg_rcvd_2ts1_s6s9_match;
wire                all_cfg_rcvd_2ts2_s6s9_match;
wire                any_cfg_rcvd_2ts2_s6s9_match;

wire                all_cfg_rcvd_8ts2_s6s9_match;

wire                any_rcvd_cnsc_2ts1_s6s9;
wire                any_rcvd_cnsc_8ts1_s6s9;
wire                all_rcvd_cnsc_8ts2_s6s9;
wire                any_rcvd_cnsc_8ts2_s6s9;

wire                all_cfg_subset_rcvd_cnsc_2ts1_s6s9;

wire                all_cfg_rcvd_cnsc_2ts1_s6s9;
wire                any_cfg_rcvd_cnsc_2ts1_s6s9;
wire                all_cfg_rcvd_cnsc_2ts2_s6s9;
wire                any_cfg_rcvd_cnsc_2ts2_s6s9;
wire                all_cfg_rcvd_cnsc_8ts2_s6s9;
//end of consecutive 8 or 2 TSs

reg                 app_ltssm_enable_d;             // application signal to block the LTSSM from link negotion due to application's readyness.
reg                 app_ltssm_enable_dd;
wire                app_ltssm_enable_fall_edge;
reg                 timeout_polling_eidle;

wire                all_phy_mac_rxelecidle;
wire                any_phy_mac_rxeidle_exit;
wire                smlh_all_lanes_rcvd_c;
wire                smlh_any_lane_rcvd_c;

wire                turn_off_do_deskew;
wire                upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes


// Loopback Flags
reg                 rcvry_to_lpbk;
reg                 ridle_to_lpbk;

reg                 latched_direct_rst;
reg                 direct_rst_d;
reg                 gointo_rcovr_state_d;

//reg     [1:0]       mac_phy_rate_d;
//reg     [1:0]       current_data_rate;
reg                 latched_rate_change;
wire                latched_rate_change_or;
reg                 latched_g3_auto_bw_status;
wire                g4_continuous_auto_bw;
reg                 latched_g4_auto_bw_status;
wire                g5_continuous_auto_bw;
wire [NL-1:0]       lpbk_slave_in_entry_from_cfg_ebth1;
wire                lpbk_master_in_entry_from_cfg;
wire                any_2_ts1_lpbk1_ebth1_rcvd;
wire                any_2_ts1_lpbk1_ebth1_rcvd_g5;
reg                 latched_g5_auto_bw_status;
wire                g6_continuous_auto_bw;
wire                any_2_ts1_lpbk1_ebth1_rcvd_g6;
reg     [4:0]       any_rcvd_8expect_ts_w_spdcnt;
reg                 any_rcvd_8expect_ts_w_spd;
wire                go_recovery_speed_change;
wire                rcvd_ts_speed_change_transition;
reg     [4:0]       rcvd_ts_auto_changecnt;
reg                 changed_speed_recovery;
reg                 select_deemphasis;
reg                 directed_speed_change;
reg                 ts_32_sent;
reg                 ts2cnt_zero;
reg                 rcvd_8expect_ts1;
reg                 int_rcvd_8expect_ts1;
reg                 int_rcvd_8_ts2_skip_eq;
reg                 int_rcvd_8_ts2_noeq_nd; // no eq needed
reg                 int_bypass_gen3_eq, int_bypass_gen4_eq;
reg                 bypass_g3_eq, bypass_g4_eq;
reg                 rcvd_ts_auto_change;

// Link Width Change
wire                go_recovery_link_width_change;
reg     [5:0]       int_target_link_width_legal;
reg     [5:0]       int_target_link_width_real;
reg                 directed_link_width_change;
reg     [5:0]       latched_target_link_width;
reg                 latched_auto_width_downsizing;
reg                 hw_autowidth_dis_d;
wire                hw_autowidth_dis_rising_edge;
reg                 hw_autowidth_dis_upconf;
wire    [NL-1:0]    target_link_lanes_active;
wire    [NL-1:0]    remote_lanes_activated;
wire                directed_link_width_change_updown;
wire                directed_link_width_change_up;
wire                directed_link_width_change_down;
wire                directed_link_width_change_nochg;
reg                 latched_valid_reliability_link_width_change;
reg                 cfglwstart_upconf_dsp;
reg     [NL-1:0]    latchd_rxeidle_exit_upconf;
reg                 upconfigure_capable;
wire                link_mode_activated_pulse;

reg                 timeout_40ns;
reg                 timeout_40ns_4rl0s;
reg                 timeout_40ns_4p1p2;
reg                 int_lpbk;
reg                 no_idle_need_sent;
wire                l0p_in_rcvry;
reg                 rcvd_8expect_ts1_notlanematch;
wire                directed_recovery;
reg                 common_gen1_supported;
wire                gen2_supported;
wire                gen3_supported;
wire                gen4_supported;
wire                gen6_supported;
wire                gen5_supported;
reg                 skip_eq;
reg                 noeq_nd;
reg                 skip_eq_d;
reg                 noeq_nd_d;
// PCIe Base Spec (for eq_bypass):
// If the equalization procedure at the highest possible data rate is unsuccessful even after re-equalization attempts and the
// Link needs to equalize at lower data rates, the Downstream Port must stop advertising Equalization Bypass To Highest Rate Support and ...
// The required equalization procedures are then performed as they would have been if the optional mechanism to skip over equalization to the
// highest possible data rate was never supported.
wire                dsp_skip_eq_falling_edge = ~skip_eq & skip_eq_d & ~cfg_upstream_port;
wire    [7:0]       pre_ltssm_ts_cntrl;                  // training sequence control

reg     [1:0]       next_ltssm_powerdown;

wire    [NL-1:0]    rxelecidle_fall;

reg                 latched_rcvd_eidle_set;
reg                 latched_rcvd_eidle_set_4rl0s;

// For "8 GT/s Receiver Impedance" ECN, implement a 100 ms timer.
reg                 timeout_100ms;        // 100 ms timeout signal.
wire                cfg_auto_flip_en;
wire    [3:0]       cfg_auto_flip_predet_lane;
wire                cfg_auto_flip_using_predet_lane;
wire                ltssm_entry_cfgcomplete_rcvrycfg_pulse;
reg    [AW-1:0]     active_nb_d;
wire                deskew_complete_n;
reg                 deskew_complete_n_d;
wire                deskew_complete_i;
wire                smlh_link_up_rising_edge;
reg                 smlh_link_up_d;
reg                 lpbk_master_g5;
logic               ltssm_in_l0_latched;
logic               ltssm_cfg_to_lpbk;
reg                 lpbk_master_g6;

wire last_state_is_eq = last_lts_state == S_RCVRY_EQ0 || last_lts_state == S_RCVRY_EQ1 || last_lts_state == S_RCVRY_EQ2 || last_lts_state == S_RCVRY_EQ3;
wire ltssm_eq2_slave_timeout ;
wire ltssm_eq2_master_timeout;
wire ltssm_eq3_slave_timeout ;
wire ltssm_eq3_master_timeout;


wire timeout_detect_quiet      ;
wire timeout_detect_wait       ;
wire timeout_poll_active       ;
wire timeout_poll_config       ;
wire timeout_cfg_linkwd_start  ;
wire timeout_cfg_linkwd_acept  ;
wire timeout_cfg_lanenum_wait  ;
wire timeout_cfg_lanenum_acept ;
wire timeout_cfg_complete      ;
wire timeout_cfg_idle          ;
wire timeout_rcvry_lock        ;
wire timeout_eq0               ;
wire timeout_dsp_eq1           ;
wire timeout_usp_eq1           ;
wire timeout_usp_eq2_g3        ;
wire timeout_usp_eq3_g3        ;
wire timeout_dsp_eq2_g3        ;
wire timeout_dsp_eq3_g3        ;
wire timeout_usp_eq2_g6        ;
wire timeout_usp_eq3_g6        ;
wire timeout_dsp_eq2_g6        ;
wire timeout_dsp_eq3_g6        ;
wire timeout_rcvry_speed_g6       ;
wire timeout_lpbk_entry_eq     ;
wire timeout_rcvry_speed       ;
wire timeout_rcvry_rcvrcfg     ;
wire timeout_rcvry_idle        ;
wire timeout_l123_send_eidle   ;
wire timeout_hot_reset         ;
wire timeout_usp_disable_idle  ;
wire timeout_lpbk_entry        ;
wire timeout_lpbk_exit         ;

wire next_state_is_eq = next_lts_state == S_RCVRY_EQ0 || next_lts_state == S_RCVRY_EQ1 || next_lts_state == S_RCVRY_EQ2 || next_lts_state == S_RCVRY_EQ3;

// Lane non-flippled info : Bits are flipped by lane reversal negotiation
logic   [NL-1:0]    set_rxstandby;
logic   [NL-1:0]    set_rxstandby_physic_lane;
logic   [NL-1:0]    eiexit_hs_in_progress_physic_lane;
logic   [NL-1:0]    int_laneflip_mac_phy_rxstandby;
logic   [NL-1:0]    int_laneflip_set_rxstandby_physic_lane;
logic   [NL-1:0]    int_laneflip_lanes_active_physic_lane;
logic   [NL-1:0]    int_set_mac_phy_rxstandby_physic_lane;

logic               clr_40ns_timer;
logic               cxl_l1_abort_exit;
logic               pre_cxl_l1_abort_exit;

//`ifdef CX_GEN5_SPEED
// extract control signals from PL Register
//wire       cfg_mod_ts, cfg_do_g5_lpbk_eq, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn;
//wire [3:0] cfg_lane_under_test;
//assign {cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts} = cfg_g5_ctrl;
//`endif // CX_GEN5_SPEED

// if ~rmlh_deskew_complete and cfg_ts2_lid_deskew, when ltssm is in L0, the core cannot get rmlh_deskew_complete again in L0 because
// the core does not use SKP OS to do deskew. The core have to transition to Recovery to gain rmlh_deskew_complete again.
assign              deskew_complete_n = ~rmlh_deskew_complete & cfg_ts2_lid_deskew & (g1_rate || g2_rate) & (lts_state_d == S_RCVRY_IDLE || lts_state_d == S_CFG_IDLE) & (lts_state == S_L0);

always @(posedge core_clk or negedge core_rst_n) begin : deskew_complete_n_d_PROC
    if (!core_rst_n) begin
        deskew_complete_n_d <= #TP 1'b0;
    end else begin
        if ( lts_state_d == S_L0 && lts_state != S_L0 )
            deskew_complete_n_d <= #TP 1'b0;
        else if ( deskew_complete_n )
            deskew_complete_n_d <= #TP 1'b1;
    end
end

// always true for Gen1/2 rate because of new deskew mechanisms for ts2/eieos/skp -> Idle. Need Idle for the deskew. The core must move to Cfg.Idle or Recovery.Idle to send Idle data
assign              deskew_complete_i = ~cfg_ts2_lid_deskew ? rmlh_deskew_complete : (g1_rate || g2_rate) ? 1'b1 : rmlh_deskew_complete;

// rlock -> rcfg when ext_synch bit set to 1 (consecutive ts1 sent)
localparam CNT_16 = 16 
;
localparam CNT_1024 = 1024 
;
assign              xmtbyte_1024_consecutive_ts1_sent = (cfg_fast_link_mode & (xmtbyte_ts_pcnt>=CNT_16)) | (~cfg_fast_link_mode & (xmtbyte_ts_pcnt>=CNT_1024));
assign              xmtbyte_16_ts_w_dis_link_sent     = (xmtbyte_ts_pcnt>=CNT_16) & xmtbyte_dis_link_sent;
assign              xmtbyte_16_ts_w_lpbk_sent         = (xmtbyte_ts_pcnt>=CNT_16) & ( ~lpbk_master ? 1'b1 : int_lpbk);

wire [5:0] int_active_nb;
wire       g1_rate_pre = current_data_rate_pre == `GEN1_RATE;
wire       g2_rate_pre = current_data_rate_pre == `GEN2_RATE;
wire       g3_rate_pre = current_data_rate_pre == `GEN3_RATE;
wire       g4_rate_pre = current_data_rate_pre == `GEN4_RATE;
wire       g5_rate_pre = current_data_rate_pre == `GEN5_RATE;
wire       g6_rate_pre = current_data_rate_pre == `GEN6_RATE;
assign int_active_nb =
                     ((`CX_NB_GEN6==4 ) & (g6_rate_pre)) ? 6'b000100 : //gen6, active symbol number = 4
                     ((`CX_NB_GEN6==8 ) & (g6_rate_pre)) ? 6'b001000 : //gen6, active symbol number = 8
                     ((`CX_NB_GEN5==4 ) & (g5_rate_pre)) ? 6'b000100 : //gen5, active symbol number = 4
                     ((`CX_NB_GEN5==8 ) & (g5_rate_pre)) ? 6'b001000 : //gen5, active symbol number = 8
                     ((`CX_NB_GEN4==4 ) & (g4_rate_pre)) ? 6'b000100 : //gen4, active symbol number = 4
                     ((`CX_NB_GEN4==8 ) & (g4_rate_pre)) ? 6'b001000 : //gen4, active symbol number = 8
                     ((`CX_NB_GEN3==4 ) & (g3_rate_pre)) ? 6'b000100 : //gen3, active symbol number = 4
                     ((`CX_NB_GEN3==8 ) & (g3_rate_pre)) ? 6'b001000 : //gen3, active symbol number = 8
                     ((`CX_NB_GEN2==2 ) & (g2_rate_pre)) ? 6'b000010 : //gen2, active symbol number = 2
                     ((`CX_NB_GEN2==4 ) & (g2_rate_pre)) ? 6'b000100 : //gen2, active symbol number = 4
                     ((`CX_NB_GEN1==2 ) & (g1_rate_pre)) ? 6'b000010 : //gen1, active symbol number = 2
                     ((`CX_NB_GEN1==4 ) & (g1_rate_pre)) ? 6'b000100 : //gen1, active symbol number = 4
                                                                                    `CX_NB;

// for easing timing
wire delay_en = (smlh_ltssm_state != S_DETECT_ACT);
delay_n_w_enable
 #(  1,  AW, `CX_NB) u_delay_active_nb      ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(int_active_nb[AW-1:0]),           .dout(active_nb));

// Output combination signal. Put pipe-line in each received module.
always_comb begin
    active_nb_wire    = int_active_nb[AW-1:0] ;
end

wire [5:0] int_active_nb_gen34;
assign int_active_nb_gen34 =
                     ((`CX_NB_GEN6==4 ) & (g6_rate_pre)) ? 6'b000100 : //gen6, active symbol number = 4
                     ((`CX_NB_GEN6==8 ) & (g6_rate_pre)) ? 6'b001000 : //gen6, active symbol number = 8
                     ((`CX_NB_GEN5==4 ) & (g5_rate_pre)) ? 6'b000100 : //gen5, active symbol number = 4
                     ((`CX_NB_GEN5==8 ) & (g5_rate_pre)) ? 6'b001000 : //gen5, active symbol number = 8
                     ((`CX_NB_GEN4==4 ) & (g4_rate_pre)) ? 6'b000100 : //gen4, active symbol number = 4
                     ((`CX_NB_GEN4==8 ) & (g4_rate_pre)) ? 6'b001000 : //gen4, active symbol number = 8
                     ((`CX_NB_GEN3==4 )                                  ) ? 6'b000100 : //gen3, active symbol number = 4
                     ((`CX_NB_GEN3==8 )                                  ) ? 6'b001000 : //gen3, active symbol number = 8
                                                                                    `CX_NB;

delay_n_w_enable
 #(  1,  AW, `CX_NB) u_delay_active_nb_gen34  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0), .en(delay_en), .din(int_active_nb_gen34[AW-1:0]),           .dout(active_nb_gen34));


always @( posedge core_clk or negedge core_rst_n ) begin : smlh_link_up_d_PROC
    if ( ~core_rst_n )
        smlh_link_up_d <= #TP 1'b0;
    else
        smlh_link_up_d <= #TP smlh_link_up;
end // smlh_link_up_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : hold_current_data_rate_PROC
    if ( ~core_rst_n )
        hold_current_data_rate <= #TP 0;
    else if ( clear )
        hold_current_data_rate <= #TP current_data_rate;
end // hold_current_data_rate_PROC

assign  smlh_link_disable   = (lts_state == S_DISABLED);

wire lpbk_state     = (lts_state == S_LPBK_ENTRY || lts_state == S_LPBK_ACTIVE || lts_state == S_LPBK_EXIT || lts_state == S_LPBK_EXIT_TIMEOUT);

reg                 latched_link_retrain_bit;
reg  [3:0]          latched_target_link_speed;
reg  [4:0]          captured_ts_data_rate;
reg                 latched_perform_eq;

// latch no_eq_needed and skip_eq if RX them true AND TX them true too
always @( * ) begin : mod_ts2_PROC
        skip_eq = skip_eq_d;
        noeq_nd = noeq_nd_d;

    if ( lts_state == S_DETECT_QUIET ) begin
        skip_eq = 0;
        noeq_nd = 0;
    end else begin
        // clear the eq_bypass (skip_eq) at gen1/2 rate when
        // dsp: ~(cfg_bypass_eq_enable | cfg_no_eq_needed_enable) or initiate eq with setting target_link_speed = Gen3. DSP controls the eq redo
        // usp: EQ bypass only runs at Gen1/2/5 rate. if usp receives gen3 rate with EQ TS2 from dsp, dsp decides no eq_bypass
        if ( (soe_g2) &&
             (((~cfg_upstream_port && (~(cfg_bypass_eq_enable || cfg_no_eq_needed_enable) || (latched_link_retrain_bit && latched_target_link_speed == `GEN3_LINK_SP && latched_perform_eq)))) ||                              // dsp
             (cfg_upstream_port  && (ltssm_captured_ts_data_rate_g3 && !cfg_gen3_eq_disable && eqctl_any_8eqts2_rcvd && !clear && next_lts_state == S_RCVRY_SPEED && lts_state == S_RCVRY_RCVRCFG))) )  // usp
            skip_eq = 1'b0; // clear so that software can initiate Eq for Gen3/4 rates
        if ( int_rcvd_8_ts2_skip_eq && (use_modified_ts_d ? ltssm_ts_cntrl[0] : (ltssm_ts_cntrl[7:6] == 2'b10 | ltssm_ts_cntrl[7:6] == 2'b01)) ) //including no eq needed for skip eq in normal TS2s
            skip_eq = 1'b1; // gen5 support checked in smlh_link.sv

        if ( int_rcvd_8_ts2_noeq_nd && (use_modified_ts_d ? ltssm_ts_cntrl[1] : ltssm_ts_cntrl[7:6] == 2'b10) )
            noeq_nd = 1'b1; // gen5 support checked in smlh_link.sv
    end
end // mod_ts2_PROC

// if smlh_link_up = 0, no de-/precoding_on
wire precode_active = smlh_link_up & ~lpbk_state; // smlh_link_up=1 in Loopback is implementation specific, have to exclude

always @( posedge core_clk or negedge core_rst_n ) begin : lpbk_master_g5_PROC
    if ( ~core_rst_n )
        lpbk_master_g5 <= #TP 0;
    else if ( lts_state == S_DETECT_QUIET || lts_state == S_PRE_DETECT_QUIET )
        lpbk_master_g5 <= #TP 0;
    else if ( lpbk_master )
        lpbk_master_g5 <= #TP 1;
end // lpbk_master_g5_PROC

// entered_lpbk_from_cfg signal is needed to enable previous eq's precoding in Loopback as per PCIe 6.0.1 Errata B11: Clarify Retimer Loopback behavior
reg entered_lpbk_from_cfg;

always @(posedge core_clk or negedge core_rst_n) begin: entered_lpbk_from_cfg_PROC
    if (!core_rst_n) begin
        entered_lpbk_from_cfg <= #TP 1'b0;
    end else if (lts_state == S_DETECT_QUIET) begin
        entered_lpbk_from_cfg <= #TP 1'b0;
    end else if (lts_state == S_LPBK_ENTRY && last_lts_state == S_CFG_LINKWD_START) begin
        entered_lpbk_from_cfg <= #TP 1'b1;
    end
end // entered_lpbk_from_cfg_PROC

reg ltssm_precode5_request, ltssm_precoding5_on, ltssm_deprecoding5_on, ltssm_precoding5_on_latched;

always @( posedge core_clk or negedge core_rst_n ) begin : mod_ts2_d_PROC
    if ( ~core_rst_n ) begin
        skip_eq_d <= #TP 0;
        noeq_nd_d <= #TP 0;

        ltssm_precode5_request <= #TP 1'b0;
        ltssm_precoding5_on    <= #TP 1'b0;
        ltssm_deprecoding5_on  <= #TP 1'b0;
        ltssm_precoding5_on_latched <= #TP 1'b0;
    end else begin
        skip_eq_d <= #TP skip_eq;
        noeq_nd_d <= #TP noeq_nd;

        // the 2 signals below are for Tx TS fields
        if ( (skip_eq && slr_g3 && ltssm_ts_data_rate[4]) || ((g4_rate) && ltssm_ts_data_rate[4]) ) // EQ TS or 128b/130b EQ TS combines in smlh_eqctl
            ltssm_precode5_request <= #TP cfg_precode_request;

// gen6 precoding on/off is the same as gen5
//        ltssm_precoding_on    <= #TP (noeq_nd_d ? int_precoding_on   : precoding_on) && (current_data_rate >= `GEN5_RATE) && precode_active; //if no_eq_needed, use sticky precoding_on. Else, use core_rst_n precoding_on
//        ltssm_deprecoding_on  <= #TP (noeq_nd_d ? int_deprecoding_on : eqctl_precode_request) && (current_data_rate >= `GEN5_RATE) && precode_active; //if no_eq_needed, use sticky precoding_on. Else, use core_rst_n precoding_on
// entered_lpbk_from_cfg signal is needed to enable previous eq's precoding in Loopback as per PCIe 6.0.1 Errata B11: Clarify Retimer Loopback behavior
        ltssm_precoding5_on    <= #TP // `ifdef CX_GEN6_SPEED current_data_rate >= `GEN6_RATE ? 1'b1 : `endif // always on for >=Gen6 rate
                                     ((noeq_nd_d || (lts_state == S_POLL_COMPLIANCE) || entered_lpbk_from_cfg) ? int_precoding_on   : precoding_on) && (goe_g5) & slr_g6; //if no_eq_needed, use sticky precoding_on. Else, use core_rst_n precoding_on
        ltssm_deprecoding5_on  <= #TP // `ifdef CX_GEN6_SPEED current_data_rate >= `GEN6_RATE ? 1'b1 : `endif // always on for >=Gen6 rate
                                     (((lpbk_state & lpbk_master_g5) ? ltssm_precoding5_on :        //if lpbk master, use Tx precoding_on for Rx de-precoding_on to avoid precoding AND deprecoding mismatch
                                      (noeq_nd_d || (lts_state == S_POLL_COMPLIANCE) || entered_lpbk_from_cfg) ? int_deprecoding_on : eqctl_precode_request)
                                     ) && (goe_g5) & slr_g6; //if no_eq_needed, use sticky deprecoding_on. Else, use core_rst_n deprecoding_on

        if ( lts_state == S_DETECT_QUIET || smlh_link_up_falling_edge ) // clear when smlh_link_up falling edge
            ltssm_precoding5_on_latched <= #TP 1'b0;
/*
      `ifdef CX_GEN6_SPEED
        else if (current_data_rate >= `GEN6_RATE) // always on for gen6 speed, status reg
            ltssm_precoding_on_latched <= #TP 1'b1;
      `endif // CX_GEN6_SPEED
*/
        else if (lts_state == S_RCVRY_SPEED && smlh_successful_spd_negotiation && gen5_supported && goe_g5 && slr_g6) // Setting on/off 
            ltssm_precoding5_on_latched <= #TP (noeq_nd_d ? int_precoding_on : precoding_on);
        else if ( ((lts_state == S_POLL_COMPLIANCE) || entered_lpbk_from_cfg) && goe_g5 )
            // Use precoding from previous eq, set on/off, 32.0 GT/s Status Register, Transmitter Precode On
            ltssm_precoding5_on_latched <= #TP int_precoding_on;
    end
end // mod_ts2_d_PROC

reg ltssm_precode6_request, ltssm_precoding6_on, ltssm_deprecoding6_on;

wire go_g6_from_g5 = (g5_rate & ltssm_ts_data_rate_eg6[5]) || ltssm_cmd_32geqts;
always @( posedge core_clk or negedge core_rst_n ) begin : g6_precoding_PROC
    if ( ~core_rst_n ) begin
        ltssm_precode6_request <= #TP 1'b0;
        ltssm_precoding6_on    <= #TP 1'b0;
        ltssm_deprecoding6_on  <= #TP 1'b0;
        ltssm_precoding6_on_latched <= #TP 1'b0;
    end else begin
        // the 2 signals below are for Tx TS fields
        if ( go_g6_from_g5 ) // gen5 128b/130b EQ TS combines in smlh_eqctl speed-up for gen6 eq
            ltssm_precode6_request <= #TP cfg_g6_tx_precode_req;

        // entered_lpbk_from_cfg signal is needed to enable previous eq's precoding in Loopback as per PCIe 6.0.1 Errata B11: Clarify Retimer Loopback behavior
        ltssm_precoding6_on   <= #TP ((noeq_nd_d || (lts_state == S_POLL_COMPLIANCE) || entered_lpbk_from_cfg)  ? int_precoding6_on   : precoding6_on) && (g6_rate); //if no_eq_needed, use sticky precoding_on. Else, use core_rst_n precoding_on
        ltssm_deprecoding6_on <= #TP ((lpbk_state & lpbk_master_g5) ? ltssm_precoding6_on :        //if lpbk master, use Tx precoding_on for Rx de-precoding_on to avoid precoding AND deprecoding mismatch
                                      ((noeq_nd_d || (lts_state == S_POLL_COMPLIANCE) || entered_lpbk_from_cfg) ? int_deprecoding6_on : eqctl_precode6_request)
                                     ) && (g6_rate); //if no_eq_needed, use sticky deprecoding_on. Else, use core_rst_n deprecoding_on

        if ( lts_state == S_DETECT_QUIET || smlh_link_up_falling_edge ) // clear when smlh_link_up falling edge
            ltssm_precoding6_on_latched <= #TP 1'b0;
        else if (lts_state == S_RCVRY_SPEED && smlh_successful_spd_negotiation && g6_rate) // Setting on/off 
            ltssm_precoding6_on_latched <= #TP (noeq_nd_d ? int_precoding6_on : precoding6_on);
        else if ( ((lts_state == S_POLL_COMPLIANCE) || entered_lpbk_from_cfg) && g6_rate )
            // Use precoding from previous eq, set on/off, 64.0 GT/s Status Register, Transmitter Precode On
            ltssm_precoding6_on_latched <= #TP int_precoding6_on;
    end
end // g6_precoding_PROC

always @* begin : precoding_PROC
    ltssm_precode_request      = 0;
    ltssm_precoding_on         = 0;
    ltssm_deprecoding_on       = 0;
    ltssm_precoding_on_latched = 0;

    ltssm_precode_request      = go_g6_from_g5 ? ltssm_precode6_request      : ltssm_precode5_request;
    ltssm_precoding_on         = goe_g6        ? ltssm_precoding6_on         : ltssm_precoding5_on;
    ltssm_deprecoding_on       = goe_g6        ? ltssm_deprecoding6_on       : ltssm_deprecoding5_on;
    ltssm_precoding_on_latched = ltssm_precoding5_on_latched;
end // precoding_PROC

assign ltssm_noeq_nd = noeq_nd;
assign smlh_noeq_needed_rcvd = noeq_nd_d; // For 32.0 GT/s Status Register

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_mod_ts_rcvd_PROC
    if ( ~core_rst_n )
        ltssm_mod_ts_rcvd <= #TP 1'b0;
    else if ( lts_state == S_DETECT_QUIET || smlh_link_up_falling_edge ) // clear when smlh_link_up falling edge
        ltssm_mod_ts_rcvd <= #TP 1'b0;
    else if ( ~smlh_link_up && (lts_state == S_CFG_LINKWD_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear) && link_latched_modts_support )
        ltssm_mod_ts_rcvd <= #TP 1'b1;
end // ltssm_mod_ts_rcvd_PROC

reg link_pc_rcvd_d, eqctl_precode_request_d;
always @( posedge core_clk or negedge core_rst_n ) begin : link_pc_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        link_pc_rcvd_d          <= #TP 1'b0;
        eqctl_precode_request_d <= #TP 1'b0;
    end else begin
        link_pc_rcvd_d          <= #TP link_pc_rcvd;
        eqctl_precode_request_d <= #TP eqctl_precode_request;
    end
end // link_pc_rcvd_d_PROC

wire precoding_lat_en_w;
// if no No Eq Needed, may perform eq,  update to link_pc_rcvd which may be 0 or 1
// entered_lpbk_from_cfg signal is needed to enable previous eq's precoding in Loopback as per PCIe 6.0.1 Errata B11: Clarify Retimer Loopback behavior
// If Gen5 EQ was done in the current link-up, then there may have been a new Tx Precoding setting and take from link_pc_rcvd. Otherwise, keep int_precoding_on
assign precoding_lat_en_w = noeq_nd_d || !equalization_done_32gt_data_rate || entered_lpbk_from_cfg;
reg precoding_lat_en;
always @(posedge core_clk or negedge core_rst_n) begin : precoding_lat_en_PROC
    if(~core_rst_n)
        precoding_lat_en <= #TP 1'b0;
    else
        precoding_lat_en <= #TP precoding_lat_en_w;
end
// use sticky_rst_n to latch Rx precoding request
always @( posedge core_clk or negedge sticky_rst_n ) begin : int_precoding_on_PROC
    if ( ~sticky_rst_n ) begin
        int_precoding_on   <= #TP 1'b0;
        int_deprecoding_on <= #TP 1'b0;
//    else if ( lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_SPEED && smlh_successful_spd_negotiation && gen5_supported )
    end else if ( smlh_link_up_falling_edge ) begin // record at the LinkUp falling edge to be used for the next linkup with no_eq_needed
        // if No Eq Needed,    no eq performed, link_pc_rcvd = 0, keep latched int_precoding_on
        int_precoding_on   <= #TP precoding_lat_en ? int_precoding_on   : (link_pc_rcvd | link_pc_rcvd_d);
        int_deprecoding_on <= #TP precoding_lat_en ? int_deprecoding_on : (eqctl_precode_request | eqctl_precode_request_d);
    end
end // int_precoding_on_PROC

reg link_pc6_rcvd_d, eqctl_precode6_request_d;
always @( posedge core_clk or negedge core_rst_n ) begin : link_pc6_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        link_pc6_rcvd_d          <= #TP 1'b0;
        eqctl_precode6_request_d <= #TP 1'b0;
    end else begin
        link_pc6_rcvd_d          <= #TP link_pc6_rcvd;
        eqctl_precode6_request_d <= #TP eqctl_precode6_request;
    end
end // link_pc6_rcvd_d_PROC

wire precoding6_lat_en_w;
// if no No Eq Needed, may perform eq,  update to link_pc_rcvd which may be 0 or 1
// entered_lpbk_from_cfg signal is needed to enable previous eq's precoding in Loopback as per PCIe 6.0.1 Errata B11: Clarify Retimer Loopback behavior
// If Gen6 EQ was done in the current link-up, then there may have been a new Tx Precoding setting and take from link_pc_rcvd. Otherwise, keep int_precoding6_on
assign precoding6_lat_en_w = noeq_nd_d || !equalization_done_64gt_data_rate || entered_lpbk_from_cfg;
reg precoding6_lat_en;
always @(posedge core_clk or negedge core_rst_n) begin : precoding6_lat_en_PROC
    if(~core_rst_n)
        precoding6_lat_en <= #TP 1'b0;
    else
        precoding6_lat_en <= #TP precoding6_lat_en_w;
end

// use sticky_rst_n to latch Rx precoding request
always @( posedge core_clk or negedge sticky_rst_n ) begin : int_precoding6_on_PROC
    if ( ~sticky_rst_n ) begin
        int_precoding6_on   <= #TP 1'b0;
        int_deprecoding6_on <= #TP 1'b0;
//    else if ( lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_SPEED && smlh_successful_spd_negotiation && gen5_supported )
    end else if ( smlh_link_up_falling_edge ) begin // record at the LinkUp falling edge to be used for the next linkup with no_eq_needed
        // if No Eq Needed,    no eq performed, link_pc_rcvd = 0, keep latched int_precoding_on
        int_precoding6_on   <= #TP precoding6_lat_en ? int_precoding6_on   : (link_pc6_rcvd | link_pc6_rcvd_d);
        int_deprecoding6_on <= #TP precoding6_lat_en ? int_deprecoding6_on : (eqctl_precode6_request | eqctl_precode6_request_d);
    end
end // int_precoding6_on_PROC

reg int_flit_mode;
// latch TX flit mode TS, ensure the core sends flit mode when entry to S_POLL_CONFIG
reg  ltssm_flit_mode_enable_d;
wire ltssm_flit_mode_enable_rising_edge;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_tx_flitm_ts_PROC
    if ( ~core_rst_n )
        latched_tx_flitm_ts <= #TP 1'b0;
    else if ( lts_state == S_DETECT_QUIET )
        latched_tx_flitm_ts <= #TP 1'b0;
    else if ( lts_state == S_POLL_CONFIG && ~smlh_link_up && int_flit_mode && ~clear ) begin
        latched_tx_flitm_ts <= #TP 1'b1;
    end
end // latched_tx_flitm_ts_PROC

// the gen6 draft 0.9 for TS1/2 Symbol 4 in Table 4-25 says:
// Data Rate Identifier
// Bit 0  Flit Mode Supported:
//        0b  Flit Mode not Supported
//        1b  Flit Mode Supported
//
// Flit Mode Supported bit:
// Bit 0 of the Data Rate Identifier Symbol of 8b/10b and 128b/130b encoded TS1s and TS2s. This bit is Set
// when the Flit Mode Supported bit in the PCI Express Capabilities Register is Set and the Flit Mode Disable bit in
// the Link Control Register is Clear
always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_flit_mode_enable_PROC
    if ( ~core_rst_n ) begin
        ltssm_flit_mode_enable <= #TP 0;
        ltssm_flit_mode_enable_lpbk <= #TP 0;
        ltssm_flit_mode_enable_modules <= #TP 0;
    end else if ( lts_state == S_DETECT_QUIET ) begin
        ltssm_flit_mode_enable <= #TP 0;
        ltssm_flit_mode_enable_lpbk <= #TP 0;
        ltssm_flit_mode_enable_modules <= #TP 0;
    end else if ( ~smlh_link_up && (lts_state == S_CFG_LINKWD_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear) && latched_tx_flitm_ts && link_latched_flitm_support[1] ) begin
        ltssm_flit_mode_enable <= #TP 1'b1;
        ltssm_flit_mode_enable_modules <= #TP {8{1'b1}};
    end else if ( ~smlh_link_up && (lts_state == S_CFG_LINKWD_START) && latched_tx_flitm_ts && link_latched_flitm_support[1] && (cfg_lpbk_en || link_latched_live_all_2_ts1_lpbk1_rcvd || (any_2_ts1_lpbk1_ebth1_rcvd_g5)) ) begin
        ltssm_flit_mode_enable_lpbk <= #TP 1'b1;
        ltssm_flit_mode_enable_modules <= #TP {8{1'b1}};
    end
end // ltssm_flit_mode_enable_PROC

assign ltssm_flit_mode_enable_w_lpbk = ltssm_flit_mode_enable_lpbk | ltssm_flit_mode_enable;

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_flit_mode_enable_d_PROC
    if ( ~core_rst_n )
        ltssm_flit_mode_enable_d <= #TP 0;
    else
        ltssm_flit_mode_enable_d <= #TP ltssm_flit_mode_enable;
end // ltssm_flit_mode_enable_d_PROC

assign ltssm_flit_mode_enable_rising_edge = ltssm_flit_mode_enable & ~ltssm_flit_mode_enable_d;

assign ltssm_flit_mode_tx = int_flit_mode;

// latch TX modified TS, ensure the core sends mod_ts when entry to S_POLL_CONFIG
always @( posedge core_clk or negedge core_rst_n ) begin : latched_tx_modified_ts_PROC
    if ( ~core_rst_n )
        latched_tx_modified_ts <= #TP 1'b1;
    else if ( lts_state == S_DETECT_QUIET )
        latched_tx_modified_ts <= #TP 1'b0;
    else if ( (next_lts_state == S_POLL_CONFIG && lts_state == S_POLL_ACTIVE & ~clear) && ~smlh_link_up && (ltssm_ts_cntrl[7:6] == 2'b11) ) begin
        latched_tx_modified_ts <= #TP 1'b1;
    end
end // latched_tx_modified_ts_PROC

// use_modified_ts1_ts2_ordered_set generation
always @( * ) begin : use_modified_ts_PROC
    use_modified_ts = use_modified_ts_d;

    if ( lts_state == S_DETECT_QUIET || lts_state == S_L0 || lts_state == S_RCVRY_LOCK )
        use_modified_ts = 1'b0;
    else if ( ~smlh_link_up && (lts_state == S_CFG_LINKWD_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear) && latched_tx_modified_ts && link_latched_modts_support )
        use_modified_ts = 1'b1; // gen5 support checked in smlh_link.sv
end // use_modified_ts_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : use_modified_ts_d_PROC
    if ( ~core_rst_n )
        use_modified_ts_d <= #TP 1'b0;
    else
        use_modified_ts_d <= #TP use_modified_ts;
end // use_modified_ts_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : rx_use_modified_ts_d_PROC
    if ( ~core_rst_n )
        rx_use_modified_ts_d <= #TP 1'b0;
    else if ( lts_state == S_DETECT_QUIET || lts_state == S_L0 || lts_state == S_RCVRY_LOCK )
        rx_use_modified_ts_d <= #TP 1'b0;
    else if ( ~smlh_link_up && (lts_state == S_CFG_LINKWD_ACEPT) && latched_tx_modified_ts && link_latched_modts_support )
        rx_use_modified_ts_d <= #TP 1'b1;
end // rx_use_modified_ts_d_PROC

assign smlh_link_up_falling_edge = smlh_link_up_d & ~smlh_link_up;

assign smlh_link_up_rising_edge = smlh_link_up & ~smlh_link_up_d;

always @( posedge core_clk or negedge core_rst_n ) begin : bypass_eq_PROC
    if ( ~core_rst_n ) begin
        bypass_g3_eq <= #TP 1'b1;
        bypass_g4_eq <= #TP 1'b1;
    end else begin
        bypass_g3_eq <= #TP int_bypass_gen3_eq;
        bypass_g4_eq <= #TP int_bypass_gen4_eq;
    end
end // bypass_eq_PROC

assign upstream_component   = !cfg_upstream_port;
assign downstream_component =  cfg_upstream_port;

//For a downstream component, the `Enter Compliance bit in the `Link Control Register is
//set to 1 and an electrical idle ordered set has been detected on any lane or, optionally, if an
//electrical idle is detected/inferred. The `Enter Compliance bit is reset to 0 when this
//condition is true.
reg eidle_seen_d;
always @(posedge core_clk or negedge core_rst_n) begin : eidle_seen_d_PROC
    if ( ~core_rst_n ) begin
        eidle_seen_d <= #TP 0;
    end else if ( (curnt_compliance_state != S_COMPL_TX_COMPLIANCE) ) begin
        eidle_seen_d <= #TP 0;
    end else if ( rmlh_rcvd_eidle_set ) begin
        eidle_seen_d <= #TP 1;
    end
end // eidle_seen_d_PROC

assign  smlh_clr_enter_compliance = cfg_upstream_port && cfg_enter_compliance && (rmlh_rcvd_eidle_set || eidle_seen_d) && (curnt_compliance_state == S_COMPL_TX_COMPLIANCE);

// clock the input
always @(posedge core_clk or negedge core_rst_n)
begin : app_ltssm_enable_delay_PROC
    if (!core_rst_n) begin
        app_ltssm_enable_d  <= #TP 1'b0;
        app_ltssm_enable_dd <= #TP 1'b0;
    end else begin
        app_ltssm_enable_d  <= #TP app_ltssm_enable;
        app_ltssm_enable_dd <= #TP app_ltssm_enable_d;
    end
end

// a pulse from 1 -> 0 of app_ltssm_enable_d
assign app_ltssm_enable_fall_edge = (app_ltssm_enable_dd && !app_ltssm_enable_d);

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        smlh_training_rst_n <= #TP 1'b1;
    else
          smlh_training_rst_n <= #TP !((next_lts_state != S_HOT_RESET_ENTRY) & (lts_state == S_HOT_RESET_ENTRY) & !clear);
end

// latch the detected lanes for the detect retry
reg     [NL-1:0]    latchd_detected_lanes;
wire    [NL-1:0]    latchd_detected_lanes_for_compare;
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        latchd_detected_lanes <= #TP 0;
    else if (int_rxdetect_done)
        latchd_detected_lanes <= #TP int_rxdetected & ltssm_lanes_active;
end


// This signal is used to filtered out invalid rxdetect_done signals
reg                 rxdetect_started;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rxdetect_started            <= #TP 0;
    else if (clear)
        rxdetect_started            <= #TP 0;
    else if (xmtbyte_txdetectrx_loopback)
        rxdetect_started            <= #TP 1;
    else if (cdm_ras_des_force_rxdetected_en && (lts_state == S_DETECT_ACT))
        rxdetect_started            <= #TP 1; // regarding the receiver detection is finished.

wire                all_phy_mac_rxdetected;
wire                any_phy_mac_rxdetected;
wire                same_detected_lanes;

//`ifdef CX_GEN5_SPEED
//  `ifdef CX_LANE_FLIP_CTRL_EN
// if CX_GEN5_SPEED & CX_NL>1, CX_LANE_FLIP_CTRL_EN is default defined
//lane_flip_mux #( 1, NL,1) u_lane_flip_mux_0 (.flipped_data(latchd_detected_lanes_for_compare), .lut(lpbk_lane_under_test), .flip_ctrl(smlh_lane_flip_ctrl), .data(latchd_detected_lanes)); // after auto-flip in Detect.Wait need to flip the lanes that were detected in Detect.Active
//  `endif // CX_LANE_FLIP_CTRL_EN
//`else // CX_GEN5_SPEED
// can force lane flipping from lut_ctrl. See description of signal lut_ctrl
lane_flip_mux
 #( 1, NL,1) u_lane_flip_mux_0 (.flipped_data(latchd_detected_lanes_for_compare), .lut(lut_ctrl), .flip_ctrl(smlh_lane_flip_ctrl), .data(latchd_detected_lanes)); // after auto-flip in Detect.Wait need to flip the lanes that were detected in Detect.Active
//`endif // CX_GEN5_SPEED

// for place/route/timing purpose
reg                 all_phy_mac_rxdetected_d;
reg                 any_phy_mac_rxdetected_d;
reg                 same_detected_lanes_d;
reg    [NL-1:0]     int_rxdetected_d;             // RMLH reports the received detected
reg                 int_rxdetect_done_d;          // RMLH indicates the cycle to sample phy_mac_rxdetected
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        all_phy_mac_rxdetected_d        <= #TP 0;
        any_phy_mac_rxdetected_d        <= #TP 0;
        same_detected_lanes_d           <= #TP 0;
        int_rxdetected_d                <= #TP 0;
        int_rxdetect_done_d             <= #TP 0;
    end else begin
        all_phy_mac_rxdetected_d        <= #TP ((phy_mac_rxdetected & ltssm_lanes_active) == ltssm_lanes_active);
        any_phy_mac_rxdetected_d        <= #TP |(phy_mac_rxdetected & ltssm_lanes_active);
        same_detected_lanes_d           <= #TP ((phy_mac_rxdetected & ltssm_lanes_active) == latchd_detected_lanes_for_compare);
        int_rxdetected_d                <= #TP phy_mac_rxdetected;
        int_rxdetect_done_d             <= #TP phy_mac_rxdetect_done && rxdetect_started;
    end

assign  all_phy_mac_rxdetected       = all_phy_mac_rxdetected_d ;
assign  any_phy_mac_rxdetected       = any_phy_mac_rxdetected_d;
assign  same_detected_lanes          = same_detected_lanes_d & (lts_state == S_DETECT_ACT);

assign  int_rxdetected               = int_rxdetected_d;
assign  int_rxdetect_done            = int_rxdetect_done_d;

assign  all_phy_mac_rxelecidle       =  ((phy_mac_rxelecidle & ltssm_lanes_active) == ltssm_lanes_active);
assign  any_phy_mac_rxeidle_exit       = |(~phy_mac_rxelecidle);
assign  smlh_all_lanes_rcvd_c        = ((smlh_lanes_rcving & ltssm_lanes_active) == ltssm_lanes_active);
assign  smlh_any_lane_rcvd_c         = |(smlh_lanes_rcving);


reg                 smlh_all_lanes_rcvd_r;
assign  smlh_all_lanes_rcvd = REGIN ? smlh_all_lanes_rcvd_r : smlh_all_lanes_rcvd_c;

// recovery request for L0/TxL0s
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_cdm_ras_des_recovery_req <= #TP 0;
    else if (lts_state_d != S_RCVRY_LOCK && lts_state == S_RCVRY_LOCK)
        latched_cdm_ras_des_recovery_req <= #TP 0;
    else if (cdm_ras_des_recovery_req)
        latched_cdm_ras_des_recovery_req <= #TP 1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_all_lanes_rcvd_r   <= #TP 0;
    end else begin
        smlh_all_lanes_rcvd_r   <= #TP smlh_all_lanes_rcvd_c;
    end

reg    link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d;
wire   link_all_2_ts1_linknmtx_lanen_rcvd_rising_edge;
wire   state_cfg_linkwd_start_wait, state_cfg_linkwd_acept_wait, state_cfg_lanenum_acept_wait, state_in_cfg_lanenum_wait;
wire   state_cfg_linkwd_acept_to_cfg_lanenum_wait, state_cfg_lanenum_acept_to_cfg_lanenum_wait;
assign state_cfg_linkwd_start_wait  = (lts_state == S_CFG_LINKWD_START) & (int_timeout_1ms_rising_edge | int_timeout_2ms_rising_edge | int_timeout_12ms_rising_edge | int_timeout_24ms_rising_edge) & ~clear;
// int_timeout_2ms_rising_edge is used to avoid TSs received on narrow link width with non-PAD lane# sent by the other end in the very late time (the other end moves into cfg_lanenum_wait state late).
assign state_cfg_linkwd_acept_wait  = (lts_state == S_CFG_LINKWD_ACEPT) & (int_timeout_1ms_rising_edge | int_timeout_2ms_rising_edge) & ~clear;
assign state_cfg_lanenum_acept_wait = (lts_state == S_CFG_LANENUM_ACEPT) & (int_timeout_1ms_rising_edge | int_timeout_2ms_rising_edge) & ~clear;
assign state_in_cfg_lanenum_wait    = (lts_state == S_CFG_LANENUM_WAIT) & ((cfg_upstream_port && last_lts_state == S_CFG_LINKWD_ACEPT) | (~cfg_upstream_port && last_lts_state == S_CFG_LANENUM_ACEPT));
assign state_cfg_linkwd_acept_to_cfg_lanenum_wait = (lts_state == S_CFG_LINKWD_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear);
assign state_cfg_lanenum_acept_to_cfg_lanenum_wait = (lts_state == S_CFG_LANENUM_ACEPT && next_lts_state == S_CFG_LANENUM_WAIT && ~clear);

always @(posedge core_clk or negedge core_rst_n) begin : link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d_PROC
    if ( ~core_rst_n )
        link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d <= #TP 0;
    else if ( clear )
        link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d <= #TP 0;
    else if ( link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd )
        link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d <= #TP 1;
end // link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d_PROC

assign link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge = link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd & ~link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_d & ~clear;

localparam L2NLD2 = `CX_LOGBASE2(NL/2);
localparam L2NLD4 = `CX_LOGBASE2(NL/4);
reg [L2NL-1:0] next_smlh_lane_flip_ctrl, int_smlh_lane_flip_ctrl;
reg            ecb_g345_compliance_lane_flip; // if Enter Compliance Bit set and over gen3 rate and in Polling.Compliance state, use latched lane flip at linkup
always @(posedge core_clk or negedge core_rst_n) begin : smlh_lane_flip_ctrl_PROC
    if (!core_rst_n)
        int_smlh_lane_flip_ctrl <= #TP 0;
    else
        int_smlh_lane_flip_ctrl <= #TP next_smlh_lane_flip_ctrl;
end

assign ltssm_lane_flip_ctrl = int_smlh_lane_flip_ctrl;

// only in the below three states the 2 Rx TS with pad/pad link/lane on all lanes causes the ltssm transition to Detect state because of lane reversal with skew between lanes and latched signals
assign ltssm_mid_config_state = (lts_state == S_CFG_LINKWD_ACEPT | lts_state == S_CFG_LANENUM_WAIT | lts_state == S_CFG_LANENUM_ACEPT); // do not clear Rx TS count in the other states
// if pad/pad link#/lane# were latched on some lanes and then a lane reversal occurs, ltssm may detect pad/pad link#/lane# on all active lanes. This would cause ltssm transition to Detect.
// So need to clear all the latched flip/reversal related signals when the lane flip/reversal changes
// after the flip, re-start to count 2 consecutive Rx TSs in the narrow link width formed at the time when (int_smlh_lane_flip_ctrl != next_smlh_lane_flip_ctrl)
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_lane_flip_ctrl_chg_pulse_d_PROC
    if (!core_rst_n)
        ltssm_lane_flip_ctrl_chg_pulse_d <= #TP 0; //reg to break Combinatorial Loop
    else
        ltssm_lane_flip_ctrl_chg_pulse_d <= #TP ltssm_mid_config_state & (int_smlh_lane_flip_ctrl != next_smlh_lane_flip_ctrl);
end // ltssm_lane_flip_ctrl_chg_pulse_d_PROC

assign ltssm_lane_flip_ctrl_chg_pulse = ltssm_lane_flip_ctrl_chg_pulse_d;

wire lpbk_active_master_eq = ( (lts_state == S_LPBK_ACTIVE || lts_state == S_LPBK_EXIT || lts_state == S_LPBK_EXIT_TIMEOUT) && goe_g5 && perform_eq_for_lpbk_mstr );

reg  eq_for_lpbk; //used for lane flip for Loopback EQ
reg  dir_cfg_lpbk_entry_active; //ltssm directly from Configuration.Linkwidth.Start -> Loopback.Entry (change to gen5 rate) -> Loopback.Active (no Loopback Eq)
always @( posedge core_clk or negedge core_rst_n ) begin : eq_for_lpbk_PROC
    if ( ~core_rst_n ) begin
        eq_for_lpbk <= #TP 0;
    end else if ( lts_state == S_LPBK_ENTRY || lts_state == S_LPBK_ACTIVE ) begin //reset when in Loopback from Loopback EQ
        eq_for_lpbk <= #TP 0;
    end else if ( ltssm_state_rcvry_eq && last_lts_state == S_LPBK_ENTRY ) begin // set Loopback.Entry -> EQ
        eq_for_lpbk <= #TP 1'b1;
    end
end // eq_for_lpbk_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : dir_cfg_lpbk_entry_active_PROC
    if ( ~core_rst_n ) begin
        dir_cfg_lpbk_entry_active <= #TP 0;
    end else if ( lts_state == S_DETECT_QUIET ) begin //reset when in Detect
        dir_cfg_lpbk_entry_active <= #TP 0;
    end else if ( next_lts_state == S_LPBK_ACTIVE && lts_state == S_LPBK_ENTRY && last_lts_state == S_CFG_LINKWD_START && ~clear && goe_g5 ) begin
        dir_cfg_lpbk_entry_active <= #TP 1'b1; // set when ltssm from Configuration.Linkwidth.Start -> Loopback.Entry (change to gen5 rate) -> Loopback.Active (no Loopback Eq) to keep previous lane reversal before reset
    end
end // dir_cfg_lpbk_entry_active_PROC

wire g3_lpbk_states = (lts_state == S_LPBK_ENTRY || lts_state == S_LPBK_ACTIVE || lts_state == S_LPBK_EXIT || lts_state == S_LPBK_EXIT_TIMEOUT) & (mac_phy_rate >= `GEN3_RATE);

// if in Loopback.Active from Loopback EQ, the master flips cfg_lane_under_test to logical Lane 0 always. The other lanes keep latched_linkup_lane_flip_ctrl_lpbk
// use mac_phy_rate because phy_mac_fs/lf reversal occurs at phy_mac_phystatus = 1 for speed change, not current_data_rate
// if loopback from Recovery (rcvry_to_lpbk), must use the current linkup lane number as seed
assign smlh_lane_flip_ctrl = ((eq_for_lpbk || (ltssm_state_rcvry_eq && last_lts_state == S_LPBK_ENTRY) || (lts_state == S_LPBK_ENTRY && mac_phy_rate >= `GEN5_RATE)) || lpbk_active_master_eq || ltssm_master_lpbk_active_after_g5_lpbk_eq || dir_cfg_lpbk_entry_active ) ? latched_linkup_lane_flip_ctrl_lpbk :
                               (g3_lpbk_states && ~cfg_mux_lpbk_lanenum && ~rcvry_to_lpbk) ? latched_linkup_lane_flip_ctrl :
                               ecb_g345_compliance_lane_flip ? latched_linkup_lane_flip_ctrl :
                               // exclude link down reset according to 3.0 spec p321, 15
                              int_smlh_lane_flip_ctrl;

always @( posedge core_clk or negedge core_rst_n ) begin : lpbk_lane_under_test_PROC
    if ( ~core_rst_n ) begin
        lpbk_lane_under_test <= #TP 0;
    end else if ( lts_state == S_DETECT_QUIET || ~lpbk_active_master_eq ) begin // always enter Detect.Quiet after Loopback
        lpbk_lane_under_test <= #TP 0;
    end else if ( lpbk_active_master_eq ) begin
        lpbk_lane_under_test <= #TP {cfg_do_g5_lpbk_eq, cfg_lane_under_test};
    end
end // lpbk_lane_under_test_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ecb_g345_compliance_lane_flip_PROC
    if ( ~core_rst_n ) begin
        ecb_g345_compliance_lane_flip <= #TP 0;
    end else if ( mac_phy_rate == `GEN1_RATE ) begin
        // when exiting Polling.Compliance, must change rate to Gen1. So use current_data_rate == `GEN1_RATE to clear so that the core has enough time to TX Compl pattern before latched_linkup_lane_flip_ctrl -> int_smlh_lane_flip_ctrl
        ecb_g345_compliance_lane_flip <= #TP 0;
    end else if ( lts_state == S_POLL_COMPLIANCE && mac_phy_rate >= `GEN3_RATE && cfg_enter_compliance ) begin
        // in Polling.Compliance & >= Gen3 rate & Enter Compliance bit set, use sticky latched latched_linkup_lane_flip_ctrl according to base spec
        ecb_g345_compliance_lane_flip <= #TP 1;
    end
end // ecb_g345_compliance_lane_flip_PROC

assign cfg_auto_flip_en = cfg_lane_en[8];
assign cfg_auto_flip_predet_lane = (4'b0001 << cfg_lane_en[7:5]) - 1; // 0->0, 1->1, 2->3, 3->7, 4->15
assign cfg_auto_flip_using_predet_lane = cfg_lane_en[7:5] != 0;

// derive link_mode from max number of lane which is detected and received (15, 7, 3, 1, 0) to form a x1 link when cfg_support_part_lanes_rxei_exit = 1 and link_next_link_mode = 1
reg [5:0] link_mode_part;
always @* begin
    link_mode_part = smlh_link_mode;
    if ( link_next_link_mode == 6'd1 ) begin
        if ( link_lanes_rcving[0] )
            link_mode_part = 1;
        else if ( link_lanes_rcving[7] )
            link_mode_part = 8;
        else if ( link_lanes_rcving[3] )
            link_mode_part = 4;
        else if ( link_lanes_rcving[1] )
            link_mode_part = 2;
    end
end
wire [5:0] smlh_link_mode_part = cfg_support_part_lanes_rxei_exit ? link_mode_part : smlh_link_mode;

// next_smlh_lane_flip_ctrl[3,2,1,0]: 0 - lane 2; 1 - lane 4; 2 - lane 8; 3 - lane 16
// change for spyglass check pass
always @(*) begin : next_smlh_lane_flip_ctrl_PROC
    next_smlh_lane_flip_ctrl = 0;
    if( cfg_auto_flip_en ) begin
        if( !cfg_auto_flip_using_predet_lane ) begin
            // autoflip based on detected lanes - executed in S_DETECT_WAIT
            case (lts_state)
                S_DETECT_QUIET: begin
                    if ( ltssm_powerdown == `P1 )
                        next_smlh_lane_flip_ctrl = 0;
                end
                S_DETECT_WAIT: begin
                    // priority logic to determine the widest flip possible
                    if( latchd_detected_lanes[0] ) next_smlh_lane_flip_ctrl = 0; // no flip needed
                    else if( latchd_detected_lanes[NL-1] ) next_smlh_lane_flip_ctrl[L2NL-1] = 1'b1; // flip xNL
                    else if( latchd_detected_lanes[NL/2-1] ) next_smlh_lane_flip_ctrl[L2NLD2-1] = 1'b1; // flip xNL/2
                    else if( latchd_detected_lanes[NL/4-1] ) next_smlh_lane_flip_ctrl[L2NLD4-1] = 1'b1; // flip xNL/4
                    // else next_smlh_lane_flip_ctrl = 0; // cannot form a link
                end // S_DETECT_WAIT
                S_CFG_LINKWD_START, S_CFG_LINKWD_ACEPT, S_CFG_LANENUM_ACEPT: begin
                    next_smlh_lane_flip_ctrl = int_smlh_lane_flip_ctrl;

                    if ( (state_cfg_linkwd_start_wait && cfg_upstream_port && ~link_lane0_2_ts1_linkn_planen_rcvd && (link_next_link_mode > 0)) || //usp lane0 doesn't receive non-pad link# in S_CFG_LINKWD_START
                         (state_cfg_linkwd_acept_wait && cfg_upstream_port && ~link_lane0_2_ts1_linknmtx_lanen_rcvd && (link_next_link_mode > 0)) || //usp lane0 doesn't receive link# match TX and non-PAD lane# in S_CFG_LINKWD_ACEPT
                         (state_cfg_linkwd_acept_wait && ~cfg_upstream_port && ~link_lane0_2_ts1_linknmtx_rcvd && (link_next_link_mode > 0)) || //dsp lane0 doesn't receive link# match TX in S_CFG_LINKWD_ACEPT
                         //usp S_CFG_LINKWD_ACEPT -> S_CFG_LANENUM_WAIT or dsp S_CFG_LANENUM_ACEPT -> S_CFG_LANENUM_WAIT, lane0 receives lane# != 0
                         (state_cfg_linkwd_acept_to_cfg_lanenum_wait && cfg_upstream_port && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && (link_next_link_mode > 0)) ||
                         // link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge is link number matching TX and reversed lane number matching TX on all smlh_lanes_active (~link_mode_changed) monitored continuously regardless of 1ms or 2ms timeout
                         ((state_cfg_lanenum_acept_wait || (link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge && lts_state == S_CFG_LANENUM_ACEPT)) && ~cfg_upstream_port && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && link_latched_live_all_2_ts1_linknmtx_lanen_rcvd && ~link_mode_changed) ||
                         (state_cfg_lanenum_acept_to_cfg_lanenum_wait && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && (link_next_link_mode > 0)) ) begin
//                         (state_in_cfg_lanenum_wait && link_all_2_ts1_linknmtx_lanen_rcvd_rising_edge && ~link_latched_live_lane0_2_ts1_lanen0_rcvd && ~clear) ) begin
                        if ( smlh_link_mode_part == 1 ) next_smlh_lane_flip_ctrl = 0; // no reverse needed, only lane 0 works
                        else if ( smlh_link_mode_part == 2 ) next_smlh_lane_flip_ctrl[0] = ~int_smlh_lane_flip_ctrl[0]; // reverse x2
                        else if ( smlh_link_mode_part == 4 ) next_smlh_lane_flip_ctrl[1] = ~int_smlh_lane_flip_ctrl[1]; // reverse x4
                        else if ( smlh_link_mode_part == 8 ) next_smlh_lane_flip_ctrl[2] = ~int_smlh_lane_flip_ctrl[2]; // reverse x8
                    end
                end // S_CFG_LINKWD_START
                default: next_smlh_lane_flip_ctrl = int_smlh_lane_flip_ctrl;
            endcase
        end else begin
            // autoflip based on predetermined lane - executed regardless of LTSSM state
            next_smlh_lane_flip_ctrl = 0; // no flip on illegal programming values or when NL=1
            if( cfg_auto_flip_predet_lane==NL-1 ) next_smlh_lane_flip_ctrl[L2NL-1] = 1'b1; // flip xNL
            else if( cfg_auto_flip_predet_lane==NL/2-1 ) next_smlh_lane_flip_ctrl[L2NLD2-1] = 1'b1; // flip xNL/2
            else if( cfg_auto_flip_predet_lane==NL/4-1 ) next_smlh_lane_flip_ctrl[L2NLD4-1] = 1'b1; // flip xNL/4
        end
    end
end
// end smlh_lane_flip_ctrl logic

//Errata B3
reg [NL-1:0] ltssm_lanes_active_r;
always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n)
    ltssm_lanes_active_r <= #TP 0;
  else begin
    if ( lts_state == S_CFG_COMPLETE && next_lts_state != S_CFG_COMPLETE && !clear )
      ltssm_lanes_active_r <= #TP latchd_smlh_lanes_rcving;
  end
end

always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n)
    ltssm_lanes_active_d <= #TP 0;
  else begin
      if ( lts_state == S_DETECT_QUIET )
          ltssm_lanes_active_d <= #TP 0;
      else if ( |lpbk_slave_in_entry_from_cfg_ebth1 ) // latch the lane under test for lpbk slave used in lpbk.active
          ltssm_lanes_active_d <= #TP ltssm_lanes_active & lpbk_slave_in_entry_from_cfg_ebth1; //used for the lane with mac_phy_txdetectrx_loopback. The other lanes not under test are left with no loopback
      else if ( ltssm_cfg_to_lpbk )
          ltssm_lanes_active_d <= #TP ltssm_lanes_active & {{(NL-1){1'b0}},1'b1};
  end
end

// need to flip get_lut( cfg_lane_under_test ) for Loopback master in Loopback.Entry because cfg_lane_under_test is the physical Lane number which needs to flip to logical lane
// so that the Bypass Eq sent only on the logical lane (then to the physical) called the lane under test. This is because in Detect.Active the lane 0 may not detected and flipped.
wire [NL-1:0] flipped_lut; // the flipped lane under test (one hot)
wire [NL-1:0] flipped_ebth1; // the flipped lane under test (one hot) for loopback slave
lane_flip_mux
 #( 1, NL,1) u_lane_flip_mux_1 ( .flipped_data(flipped_lut),   .lut(5'h0), .flip_ctrl(smlh_lane_flip_ctrl), .data(get_lut(cfg_lane_under_test)) );
// (smlh_lane_flip_ctrl ^ latched_et_cfg_lane_flip_ctrl_lpbk) is to avoid Lane Flip mux again (but need Lane Reversal) for Loopback slave because it's done in Detect state while the Loopback is after Detect state
// (ltssm_lanes_active_d & ltssm_lanes_active) is the LUT after Lane Flip but before Lane Reversal.
lane_flip_mux
 #( 1, NL,1) u_lane_flip_mux_2 ( .flipped_data(flipped_ebth1), .lut(5'h0), .flip_ctrl(smlh_lane_flip_ctrl ^ latched_et_cfg_lane_flip_ctrl_lpbk), .data(ltssm_lanes_active_d & ltssm_lanes_active) );

always @( posedge core_clk or negedge core_rst_n ) begin : lpbk_eq_lanes_active_PROC
    if ( ~core_rst_n ) begin
        lpbk_eq_lanes_active <= #TP 0;
    end else if ( lts_state == S_DETECT_QUIET ) begin
        lpbk_eq_lanes_active <= #TP 0;
    end else if ( lpbk_master_in_entry_from_cfg && cfg_do_g5_lpbk_eq ) begin
        lpbk_eq_lanes_active <= #TP ltssm_lanes_active & flipped_lut; //get the lane under test for lpbk master eq to transmit TS1s with Enhanced Link Behaviour Control = 01b
    end else if ( perform_eq_for_loopback ) begin // get the lane under test for lpbk slave eq to receive TS1s with Enhanced Link Behaviour Control = 01b
        lpbk_eq_lanes_active <= #TP flipped_ebth1;
    end 
end // lpbk_eq_lanes_active_PROC

assign lpbk_eq_n_lut_pset = goe_g5 && |lpbk_eq_lanes_active && (perform_eq_for_loopback || perform_eq_for_lpbk_mstr);
assign lpbk_eq = goe_g5 && |lpbk_eq_lanes_active && ltssm_state_rcvry_eq && (perform_eq_for_loopback || perform_eq_for_lpbk_mstr);

wire load_link_capable ;
assign load_link_capable = cfg_por_phystatus_mode ? 1'b1 : all_phystatus_deasserted ;

// LMD: Truncation of bits in constant. Most significant bits are lost
// LJ: If NL < 16, the most significant bits of ltssm_lanes_active are DO NOT CARE
// leda W163 off
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_lanes_active_PROC
    if (!core_rst_n) begin
        ltssm_lanes_active      <= #TP {NL{1'b1}};  // All lanes start out as active
        ltssm_lanes_activated_pulse   <= #TP 0;
    end else if ( cfg_support_part_lanes_rxei_exit && smlh_link_mode == 6'd1 && ~(lts_state == S_DETECT_QUIET || (lts_state == S_CFG_LINKWD_START && ((clear && directed_link_width_change_up) || (!clear & upconfigure_capable)))) ) begin
        ltssm_lanes_active <= #TP {{(NL-1){1'b0}},1'b1};
    end else if ( lts_state == S_LPBK_ACTIVE && (perform_eq_for_loopback || perform_eq_for_lpbk_mstr || ((current_data_rate == `GEN6_RATE) && !ltssm_in_l0_latched)) ) begin
        // master transmits packtes on Lane0 only in Loopback.Active. Lpbk slave sends Mod Cmpl Pattern for lanes not under test
        // the lane under test in Loopback slave is with mac_phy_txdetectrx_loopback = 1'b1
        ltssm_lanes_active <= #TP lpbk_master ? {{(NL-1){1'b0}},1'b1} : ltssm_lanes_active; //{NL{1'b1}};
    end else if ( lts_state == S_LPBK_ACTIVE && lpbk_master ) // to narrow active lanes in S_LPBK_ACTIVE for lpbk_master so that TX data can be received over the lanes
        ltssm_lanes_active <= #TP ltssm_lanes_active & link_imp_lanes;
    else if ((lts_state == S_DETECT_QUIET) && cfg_auto_flip_en && cfg_auto_flip_using_predet_lane && load_link_capable) ltssm_lanes_active  <= #TP 16'h0001; // same as having cfg_link_capable=4'b00001
    // in DETECT ACTIVE state, we need to detect the active lanes. If
    // we do not receive all of the lanes that we think it is active, then
    // we will give a chance of retry the detect to make sure that the same
    // active lanes are detected.
    // Note: Here we will  update the ltssm_lanes_active when the
    // detected active lanes are not matching what we think from
    // configuration capablity. all_phy_mac_rxdetected determines the
    // matching of active lanes with detected lanes
    else if ((lts_state_d == S_DETECT_ACT) & (lts_state == S_POLL_ACTIVE)) ltssm_lanes_active  <= #TP (ltssm_lanes_active & latchd_detected_lanes);
    else if (cfg_link_capable[3] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h00ff;
    else if (cfg_link_capable[2] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h000f;
    else if (cfg_link_capable[1] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h0003;
    else if (cfg_link_capable[0] & (lts_state == S_DETECT_QUIET) & load_link_capable) ltssm_lanes_active  <= #TP 16'h0001;
    // ltssm_lanes_active gets updated again upon entering CFG_COMPLETE
    else if ( (lts_state_d == S_CFG_COMPLETE) & (lts_state == S_CFG_IDLE) )  ltssm_lanes_active  <= #TP latchd_smlh_lanes_rcving;
    else if ( lts_state == S_CFG_LINKWD_START ) begin
        if(clear && directed_link_width_change_up)
            ltssm_lanes_active <= #TP target_link_lanes_active;
        else if( !clear & upconfigure_capable ) begin
            ltssm_lanes_active <= #TP ltssm_lanes_active | remote_lanes_activated ;
            ltssm_lanes_activated_pulse <= #TP (ltssm_lanes_active != (ltssm_lanes_active | remote_lanes_activated));
        end
    end
    // Errata B3, ltssm_lanes_active gets updated again upon entering cfg.linkwd.start from Recovery
    else if ( (lts_state_d == S_RCVRY_IDLE || lts_state_d == S_RCVRY_LOCK || lts_state_d == S_RCVRY_RCVRCFG) & (lts_state == S_CFG_LINKWD_START) )
      ltssm_lanes_active  <= #TP ltssm_lanes_active_r;
    else                                                      ltssm_lanes_active  <= #TP ltssm_lanes_active;
end
// leda W163 on

// deskew_lanes_active is identical to ltssm_lanes_active,
// except that it is continuously updated in S_CFG_LANENUM_ACEPT
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        deskew_lanes_active      <= #TP {NL{1'b1}};  // All lanes start out as active
    else if ( lts_state == S_LPBK_ACTIVE && lpbk_master ) // to narrow active lanes in S_LPBK_ACTIVE for lpbk_master so that TX data can be received over the lanes after deskew
        deskew_lanes_active      <= #TP next_deskew_lanes_active;
    else if (update_deskew_lanes_active)
        deskew_lanes_active      <= #TP next_deskew_lanes_active;

assign next_deskew_lanes_active =
       (lts_state == S_LPBK_ACTIVE & lpbk_master) ? ( ( perform_eq_for_lpbk_mstr || ((current_data_rate == `GEN6_RATE) && !ltssm_in_l0_latched) )  ? {{(NL-1){1'b0}},1'b1} : (deskew_lanes_active & link_imp_lanes)) :
       (lts_state_d == S_DETECT_ACT) & (lts_state == S_POLL_ACTIVE) ? (deskew_lanes_active & latchd_detected_lanes) :

       cfg_link_capable[3] & (lts_state == S_DETECT_QUIET) ? 16'h00ff :
       cfg_link_capable[2] & (lts_state == S_DETECT_QUIET) ? 16'h000f :
       cfg_link_capable[1] & (lts_state == S_DETECT_QUIET) ? 16'h0003 :
       cfg_link_capable[0] & (lts_state == S_DETECT_QUIET) ? 16'h0001 :
      (  (lts_state == S_CFG_LINKWD_ACEPT )
       | (lts_state == S_CFG_LANENUM_WAIT )
       | (lts_state == S_CFG_LANENUM_ACEPT) ) ? latchd_smlh_lanes_rcving : deskew_lanes_active;

assign update_deskew_lanes_active =
       (lts_state_d == S_DETECT_ACT) & (lts_state == S_POLL_ACTIVE) |
       cfg_link_capable[4] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[3] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[2] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[1] & (lts_state == S_DETECT_QUIET) |
       cfg_link_capable[0] & (lts_state == S_DETECT_QUIET) |
      (  (lts_state == S_CFG_LINKWD_ACEPT )
             | (lts_state == S_CFG_LANENUM_WAIT )
       | (lts_state == S_CFG_LANENUM_ACEPT) );

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        deskew_lanes_active_change  <= #TP 1'b0;
    else if (update_deskew_lanes_active)
        deskew_lanes_active_change  <= #TP (deskew_lanes_active != next_deskew_lanes_active);
    else
        deskew_lanes_active_change  <= #TP 1'b0;

assign ltssm_entry_cfgcomplete_rcvrycfg_pulse = clear & (lts_state == S_CFG_COMPLETE || lts_state == S_RCVRY_RCVRCFG);

always @( posedge core_clk or negedge core_rst_n ) begin : active_nb_d_PROC
    if ( ~core_rst_n ) begin
        active_nb_d <= #TP `CX_NB;
    end else begin
        active_nb_d <= #TP active_nb;
    end
end // active_nb_d_PROC

// smlh_do_deskew is really acting as an active low reset to the deskew logic
// the conditions in OR below determine when to drive this to 0
// for CX_16S_EN, the core needs more RX TSs to delay resetting the deskew block because deskew block may still be processing Rx Data Stream if using link_any_exact_2_ts_rcvd to reset deskew block
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_do_deskew      <= #TP 1;
    else
        smlh_do_deskew      <= #TP ~( ((lts_state == S_RCVRY_LOCK) && (((timeout_24ms && link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd) || (( link_any_exact_2_ts_rcvd) && ~l0p_in_rcvry)) && ~clear)
                                      )
                                    || (lts_state == S_DETECT_ACT)
                                    || (lts_state == S_POLL_COMPLIANCE)
                                    || ((lts_state == S_CFG_LINKWD_ACEPT) && link_any_exact_1_ts_rcvd && ~clear) //reset. this state is only from Cfg.Linkwidth.Start, late lane Rx data already gone through and ts2 has not arrived
                                    || (lts_state == S_LPBK_ENTRY) //reset because speed change or the remote loopback will cause deskew loss
                                    || (lts_state == S_RCVRY_SPEED)
                                    || ((r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE) && (curnt_l0s_rcv_state == S_L0S_RCV_FTS)) //reset. deskew block has time to detect SKP after the reset. late lane Rx data is ok.
                                    || deskew_lanes_active_change
                                    || (next_smlh_lane_flip_ctrl != int_smlh_lane_flip_ctrl) // reset the deskew block to redo deskew if lane reversed
                                    || ltssm_flit_mode_enable_rising_edge
                                    //logic below is used to move out of S_FRAMING_ERR state in deskew_rd_state machine in rmlh_deskew3_rd_slv.
                                    //for gen3/4 rate, the deskew is based on received SDS after TS2 in Cfg.Complete or Rcvry.RcvrCfg. So can reset deskew logic when entry to the two states
                                    || ( (g3_rate || g4_rate || g5_rate || (goe_g6)) && (ltssm_entry_cfgcomplete_rcvrycfg_pulse ||
                                         (lts_state == S_LPBK_ENTRY) ||
                                         (lts_state == S_DISABLED_ENTRY) ||
                                         (lts_state == S_HOT_RESET_ENTRY)
                                                                              )
                                       )
                                    );

assign  smlh_link_mode  = int_smlh_link_mode;

always @(posedge core_clk or negedge core_rst_n) begin : int_smlh_link_mode_PROC
    if ( ~core_rst_n )
        int_smlh_link_mode <= #TP 0;
    else if ( lts_state == S_DETECT_QUIET || lts_state == S_POLL_ACTIVE || link_mode_activated_pulse || (lts_state == S_LPBK_ACTIVE && lpbk_master) || lts_state == S_LPBK_ENTRY || lts_state == S_LPBK_ACTIVE ) begin
        int_smlh_link_mode <= #TP
            (ltssm_lanes_active[7:0]  == 8'hFF ) ? 8 :
            (ltssm_lanes_active[3:0]  == 4'hF ) ? 4 :
            (ltssm_lanes_active[1:0]  == 2'b11 ) ? 2 :
            1'b1;
    end else if ( clear &&
                  ( ( lts_state == S_CFG_LINKWD_START && ( !cfg_upstream_port && directed_link_width_change_up ||
                                                           cfg_upstream_port && directed_link_width_change_updown ) ) ||
                    ( lts_state == S_CFG_LINKWD_ACEPT && !cfg_upstream_port && directed_link_width_change_down ) ) ) begin
        int_smlh_link_mode <= #TP latched_target_link_width;
    end else if ( cfg_upstream_port && state_cfg_linkwd_start_wait ) begin
        int_smlh_link_mode <= #TP link_next_link_mode == 0 ? int_smlh_link_mode : link_next_link_mode; //0 - not ready to form a link at this time, wait for next timeout
    end else if ( state_cfg_linkwd_acept_wait || state_cfg_lanenum_acept_wait ) begin
        int_smlh_link_mode <= #TP link_next_link_mode == 0 ? int_smlh_link_mode : link_next_link_mode; //0 - not ready to form a link at this time, wait for next timeout
    end
end // int_smlh_link_mode_PROC

always @(posedge core_clk or negedge core_rst_n) begin : link_mode_changed_PROC
  if ( ~core_rst_n )
    link_mode_changed <= #TP 1'b0;
  else if ( lts_state == S_CFG_LANENUM_ACEPT ) begin 
    if( state_cfg_lanenum_acept_wait && link_next_link_mode!=0 && link_next_link_mode!=int_smlh_link_mode )
      link_mode_changed <= #TP 1'b1;
  end
  else
    link_mode_changed <= #TP 1'b0;
end

always @(posedge core_clk or negedge core_rst_n) begin : smlh_link_rxmode_PROC
    if ( ~core_rst_n )
        smlh_link_rxmode <= #TP 0;
    else if ( ltssm != S_CFG_LINKWD_START )
        smlh_link_rxmode <= #TP smlh_link_mode;
end

always @(posedge core_clk or negedge core_rst_n) begin : linkup_link_mode_PROC
    if ( ~core_rst_n )
        linkup_link_mode <= #TP 0;
    else if ( !smlh_link_up )
        linkup_link_mode <= #TP smlh_link_mode;
end

always @(posedge core_clk or negedge core_rst_n) begin : smlh_no_turnoff_lanes_PROC
    if ( ~core_rst_n )
        smlh_no_turnoff_lanes <= #TP 0;
    else if ( smlh_link_up )
        smlh_no_turnoff_lanes <= #TP 
                                     linkup_link_mode[3] ? 'h00ff :
                                     linkup_link_mode[2] ? 'h000f :
                                     linkup_link_mode[1] ? 'h0003 :
                                                           'h0001;
end

always @(posedge core_clk or negedge core_rst_n) begin : latest_link_mode_PROC
    if ( ~core_rst_n )
        latest_link_mode <= #TP 0;
    else if ( lts_state != S_L0 && next_lts_state == S_L0 && !clear )
        latest_link_mode <= #TP smlh_link_mode;
end

// L0p State
typedef enum logic [3:0] {
  S_L0P_IDLE,              // IDLE
  S_L0P_WAIT_REQ_DW,       // Wait on L0p request for DW
  S_L0P_DW_REQ,            // Downsize Request
  S_L0P_WAIT_REQ_BOTH,     // Wait on L0p request for UP/DW
  S_L0P_UP_REQ_WAIT,       // Upsize wait for TS1 
  S_L0P_UP_REQ_TS1,        // Upsize Request for TS1
  S_L0P_UP_REQ_TS2,        // Upsize Request for TS2
  S_L0P_UP_REQ_DONE,       // Upsize Request for DONE
  S_L0P_UP_RCVRY          // Upsize Request for Recovery
} state_l0p_e;

// internal wire/reg
state_l0p_e             next_l0p_state, curnt_l0p_state;
reg  [5:0]              r_smlh_l0p_next_link_mode, r_smlh_l0p_next_link_mode_d;  // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
reg  [5:0]              r_smlh_l0p_link_mode, r_smlh_l0p_link_mode_d;            // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
reg  [NL-1:0]           r_ltssm_l0p_lanes_active, r_ltssm_l0p_lanes_active_d;    // LTSSM latched lanes that are active based on the link negotiation
reg  [NL-1:0]           r_ltssm_l0p_last_lanes_active, r_ltssm_l0p_last_lanes_active_d;    // LTSSM latched lanes that are active based on the link negotiation
reg  [3:0]              r_ltssm_l0p_cmd, r_ltssm_l0p_cmd_d;                      // encoded command to notify transmitter of the proper action based on LTSSM states
reg                     r_smlh_l0p_update_d;
wire                    pre_l0p_clear;
wire                    disable_timer_clear_in_l0p;
wire                    l0p_in_progress;
wire                    latched_xdlh_cdm_clear;
reg                     latched_xdlh_smlh_link_req;
reg  [4:0]              latched_xdlh_smlh_link_width;
reg                     latched_xdlh_smlh_link_initiated;
reg                     latched_xmtbyte_l0p_linkwidth_changed;
reg  [NL-1:0]           latched_prior_ltssm_l0p_last_lanes_active;
wire                    mux_xdlh_smlh_link_req;
wire [4:0]              mux_xdlh_smlh_link_width;
wire                    mux_xdlh_smlh_link_initiated;
reg                     r_ltssm_l0p_cmd_4_eieos_req, r_ltssm_l0p_cmd_4_eieos_req_d;
reg                     ltssm_l0p_capable;
wire                    l0p_goto_recovery;
wire                    l0p_tx_rx_linkwidth_done;
wire                    ltssm_in_rcvry_lock;
wire                    ltssm_in_l123_send_eidle;
wire                    ltssm_in_l12_idle;

assign ltssm_in_rcvry_lock = (ltssm==S_RCVRY_LOCK);
assign ltssm_in_l123_send_eidle = (ltssm==S_L123_SEND_EIDLE);
assign ltssm_in_l12_idle = (ltssm==S_L1_IDLE) || (ltssm==S_L2_IDLE);

always @( * ) begin : next_l0p_state_PROC
    next_l0p_state           = curnt_l0p_state;
    r_ltssm_l0p_cmd          = r_ltssm_l0p_cmd_d;
    r_smlh_l0p_next_link_mode = r_smlh_l0p_next_link_mode_d;
    r_smlh_l0p_link_mode = r_smlh_l0p_link_mode_d;
    r_ltssm_l0p_lanes_active = r_ltssm_l0p_lanes_active_d;
    r_ltssm_l0p_last_lanes_active = r_ltssm_l0p_last_lanes_active_d;
    r_ltssm_l0p_cmd_4_eieos_req = r_ltssm_l0p_cmd_4_eieos_req_d;

    case(curnt_l0p_state)
        S_L0P_WAIT_REQ_DW: begin // Wait on L0p request for DW
            if(ltssm!=S_L0) begin
                next_l0p_state           = S_L0P_IDLE;
            end else if(mux_xdlh_smlh_link_req && mux_xdlh_smlh_link_width < smlh_link_mode[4:0]) begin
                next_l0p_state           = S_L0P_DW_REQ;
                r_ltssm_l0p_cmd          = `SEND_EIDLE;
                r_smlh_l0p_next_link_mode = {1'b0, mux_xdlh_smlh_link_width};
                r_ltssm_l0p_lanes_active =
 (mux_xdlh_smlh_link_width[3]) ?      255 :
 (mux_xdlh_smlh_link_width[2]) ?       15 :
                                                              (mux_xdlh_smlh_link_width[1]) ?        3 : 1;
               r_ltssm_l0p_last_lanes_active = r_ltssm_l0p_lanes_active_d;
            end
            r_ltssm_l0p_cmd_4_eieos_req = (g6_rate) ? 1 :
                                                                           0 ;
        end
        S_L0P_DW_REQ: begin          // Downsize Request
            if(ltssm_in_rcvry_lock) begin
                next_l0p_state           = S_L0P_UP_RCVRY; // Move to REQ-TS1 for Recovery
                r_ltssm_l0p_cmd          = `SEND_TS1;
                r_ltssm_l0p_cmd_4_eieos_req = (g6_rate) ? 1 : 0;
                r_ltssm_l0p_last_lanes_active = (latched_xmtbyte_l0p_linkwidth_changed) ? r_ltssm_l0p_lanes_active_d : r_ltssm_l0p_last_lanes_active_d;
            end else if(xmtbyte_l0p_linkwidth_changed) begin
                r_ltssm_l0p_cmd          = `XMT_IN_EIDLE;
                r_smlh_l0p_link_mode     = r_smlh_l0p_next_link_mode;
            end else if(l0p_tx_rx_linkwidth_done) begin
                next_l0p_state           = S_L0P_WAIT_REQ_BOTH;
                r_smlh_l0p_link_mode     = r_smlh_l0p_next_link_mode;
            end
        end
        S_L0P_WAIT_REQ_BOTH: begin // Wait on L0p request for UP/DW
            if(ltssm_in_rcvry_lock) begin
                next_l0p_state           = S_L0P_UP_RCVRY; // Move to REQ-TS1 for Recovery
                r_ltssm_l0p_cmd          = `SEND_TS1;
                r_ltssm_l0p_cmd_4_eieos_req = (g6_rate) ? 1 : 0;
                r_ltssm_l0p_last_lanes_active = r_ltssm_l0p_lanes_active_d;
            // Request for Down link-width
            end else if(mux_xdlh_smlh_link_req && (mux_xdlh_smlh_link_width < smlh_link_mode[4:0]) && (mux_xdlh_smlh_link_width < r_smlh_l0p_next_link_mode_d[4:0])) begin
                next_l0p_state           = S_L0P_DW_REQ;
                r_ltssm_l0p_cmd          = `SEND_EIDLE;
                r_smlh_l0p_next_link_mode = {1'b0, mux_xdlh_smlh_link_width};
                r_ltssm_l0p_lanes_active =
 (mux_xdlh_smlh_link_width[3]) ?      255 :
 (mux_xdlh_smlh_link_width[2]) ?       15 :
                                                              (mux_xdlh_smlh_link_width[1]) ?        3 : 1;
                r_ltssm_l0p_last_lanes_active = r_ltssm_l0p_lanes_active_d;
            // Request for Up link-width
            end else if(mux_xdlh_smlh_link_req && ((mux_xdlh_smlh_link_width == smlh_link_mode[4:0]) || (mux_xdlh_smlh_link_width < smlh_link_mode[4:0])) && (mux_xdlh_smlh_link_width > r_smlh_l0p_next_link_mode_d[4:0])) begin
                if(~mux_xdlh_smlh_link_initiated) begin // non requesting port waits for detection of Eidle exit
                    next_l0p_state           = S_L0P_UP_REQ_WAIT;
                end else begin // Initiater
                    next_l0p_state           = S_L0P_UP_REQ_TS1;
                    r_ltssm_l0p_cmd          = `SEND_TS1;
                end
                    r_smlh_l0p_next_link_mode = {1'b0, mux_xdlh_smlh_link_width};
                    r_ltssm_l0p_lanes_active =
 (mux_xdlh_smlh_link_width[3]) ?      255 :
 (mux_xdlh_smlh_link_width[2]) ?       15 :
                                                                  (mux_xdlh_smlh_link_width[1]) ?        3 : 1;
                    r_ltssm_l0p_last_lanes_active = r_ltssm_l0p_lanes_active_d;
                    r_ltssm_l0p_cmd_4_eieos_req = (g6_rate) ? 1 : 0;
            end
        end
        S_L0P_UP_REQ_WAIT: begin      // Upsize wati Request for TS1 until TS1-rcved
            if(ltssm_in_rcvry_lock) begin
                next_l0p_state           = S_L0P_UP_RCVRY; // Move to REQ-TS1 for Recovery
                r_ltssm_l0p_cmd          = `SEND_TS1;
                r_ltssm_l0p_cmd_4_eieos_req = (g6_rate) ? 1 : 0;
            end if(link_any_2_ts_rcvd) begin
                next_l0p_state           = S_L0P_UP_REQ_TS1;
                r_ltssm_l0p_cmd          = `SEND_TS1;
            end if(timeout_16us && ~clear) begin // Abandoning link-up request
                next_l0p_state           = S_L0P_WAIT_REQ_BOTH;
                r_smlh_l0p_next_link_mode = smlh_l0p_link_mode;
                r_ltssm_l0p_lanes_active =
 (smlh_l0p_link_mode[3]) ?      255 :
 (smlh_l0p_link_mode[2]) ?       15 :
                                                              (smlh_l0p_link_mode[1]) ?        3 : 1;
                r_ltssm_l0p_last_lanes_active = latched_prior_ltssm_l0p_last_lanes_active;
            end
        end
        S_L0P_UP_REQ_TS1: begin      // Upsize Request for TS1
            if(ltssm_in_rcvry_lock) begin
                next_l0p_state           = S_L0P_UP_RCVRY; // Move to REQ-TS1 for Recovery
                r_ltssm_l0p_cmd          = `SEND_TS1;
                r_ltssm_l0p_cmd_4_eieos_req = (g6_rate) ? 1 : 0;
            end if(link_xmlh_l0p_16_ts1_sent && (link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd || link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd)) begin
                next_l0p_state           = S_L0P_UP_REQ_TS2;
                r_ltssm_l0p_cmd          = `SEND_TS2;
            end
            if(g6_rate && link_any_2_ts_rcvd) begin // change number of eieos from 4 to 1
                r_ltssm_l0p_cmd_4_eieos_req = 0;
            end
        end
        S_L0P_UP_REQ_TS2: begin      // Upsize Request for TS2
            if(ltssm_in_rcvry_lock) begin
                next_l0p_state           = S_L0P_UP_RCVRY; // Move to REQ-TS1 for Recovery
                r_ltssm_l0p_cmd          = `SEND_TS1;
            end if(link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd && link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd) begin
                next_l0p_state           = S_L0P_UP_REQ_DONE;
                r_ltssm_l0p_cmd          = `SEND_IDLE;
            end
        end
        S_L0P_UP_REQ_DONE: begin     // Upsize Request for DONE
            if(ltssm_in_rcvry_lock) begin
                next_l0p_state           = S_L0P_UP_RCVRY; // Move to Receovery
                r_ltssm_l0p_cmd          = `SEND_TS1;
            end if(xmtbyte_l0p_linkwidth_changed) begin
                r_smlh_l0p_link_mode     = r_smlh_l0p_next_link_mode;
            end else if(l0p_tx_rx_linkwidth_done) begin
                next_l0p_state           = (smlh_l0p_link_mode==smlh_link_mode) ? S_L0P_WAIT_REQ_DW : S_L0P_WAIT_REQ_BOTH;
                r_smlh_l0p_link_mode     = r_smlh_l0p_next_link_mode;
            end
        end
        S_L0P_UP_RCVRY: begin // Upsize Request recovery
                r_smlh_l0p_next_link_mode = smlh_link_mode;
                r_ltssm_l0p_lanes_active  = ltssm_lanes_active;
            if(l0p_tx_rx_linkwidth_done || ~smlh_do_deskew || (lts_state == S_RCVRY_RCVRCFG)) begin
                next_l0p_state           = S_L0P_IDLE;
            end else begin
                next_l0p_state           = S_L0P_UP_RCVRY;
            end
            if(xmtbyte_eies_sent || latched_xmtbyte_eies_sent) begin
                r_ltssm_l0p_cmd          = `SEND_TS1;
                r_smlh_l0p_link_mode     = r_smlh_l0p_next_link_mode;
            end else begin
                r_ltssm_l0p_cmd          = `NORM;
                r_smlh_l0p_link_mode     = r_smlh_l0p_link_mode_d;
            end
            if(g6_rate && link_any_2_ts_rcvd) begin // change number of eieos from 4 to 1
                r_ltssm_l0p_cmd_4_eieos_req = 0;
            end
        end
        default: begin // IDLE
            if(ltssm==S_L0 && ltssm_flit_mode_enable) begin
                next_l0p_state = S_L0P_WAIT_REQ_DW;
            end
            r_ltssm_l0p_cmd          = `NORM;
            r_smlh_l0p_next_link_mode = smlh_link_mode;
            r_smlh_l0p_link_mode      = smlh_link_mode;
            r_ltssm_l0p_lanes_active  = ltssm_lanes_active;
            r_ltssm_l0p_last_lanes_active = ltssm_lanes_active;
            r_ltssm_l0p_cmd_4_eieos_req = 0;
        end
    endcase
end

always @(posedge core_clk or negedge core_rst_n) begin : l0p_reg_PROC
    if (!core_rst_n) begin
        curnt_l0p_state            <= #TP S_L0P_IDLE;
        r_smlh_l0p_update_d        <= #TP 0;
        r_ltssm_l0p_cmd_d          <= #TP `NORM;
        r_smlh_l0p_next_link_mode_d     <= #TP 1;
        r_smlh_l0p_link_mode_d     <= #TP 1;
        r_ltssm_l0p_lanes_active_d <= #TP 1;
        r_ltssm_l0p_last_lanes_active_d  <= #TP 1;
        r_ltssm_l0p_cmd_4_eieos_req_d    <= #TP 0;
        latched_xdlh_smlh_link_req       <= #TP 0;
        latched_xdlh_smlh_link_width     <= #TP 0;
        latched_xdlh_smlh_link_initiated <= #TP 0;
        latched_xmtbyte_l0p_linkwidth_changed <= #TP 0;
        latched_prior_ltssm_l0p_last_lanes_active <= #TP 0;
    end else begin
        curnt_l0p_state            <= #TP (ltssm_in_l12_idle) ? S_L0P_IDLE : next_l0p_state;
        r_smlh_l0p_update_d        <= #TP (next_l0p_state==S_L0P_DW_REQ && (curnt_l0p_state==S_L0P_WAIT_REQ_DW || curnt_l0p_state==S_L0P_WAIT_REQ_BOTH)) || (next_l0p_state==S_L0P_UP_REQ_TS1 && (curnt_l0p_state==S_L0P_UP_REQ_WAIT || curnt_l0p_state==S_L0P_WAIT_REQ_BOTH));
        r_ltssm_l0p_cmd_d          <= #TP r_ltssm_l0p_cmd;
        r_smlh_l0p_next_link_mode_d     <= #TP r_smlh_l0p_next_link_mode;
        r_smlh_l0p_link_mode_d     <= #TP r_smlh_l0p_link_mode;
        r_ltssm_l0p_lanes_active_d      <= #TP r_ltssm_l0p_lanes_active;
        r_ltssm_l0p_last_lanes_active_d <= #TP r_ltssm_l0p_last_lanes_active;
        r_ltssm_l0p_cmd_4_eieos_req_d    <= #TP r_ltssm_l0p_cmd_4_eieos_req;
        latched_xdlh_smlh_link_req       <= #TP (latched_xdlh_cdm_clear) ? 1'b0: (l0p_in_progress) ? (latched_xdlh_smlh_link_req || xdlh_smlh_link_req) : latched_xdlh_smlh_link_req;
        latched_xdlh_smlh_link_width     <= #TP (l0p_in_progress && xdlh_smlh_link_req) ? xdlh_smlh_link_width : latched_xdlh_smlh_link_width;
        latched_xdlh_smlh_link_initiated <= #TP (l0p_in_progress && xdlh_smlh_link_req) ? xdlh_smlh_link_initiated : latched_xdlh_smlh_link_initiated;
        latched_xmtbyte_l0p_linkwidth_changed <= #TP (next_l0p_state!=curnt_l0p_state) ? 1'b0 : (latched_xmtbyte_l0p_linkwidth_changed || xmtbyte_l0p_linkwidth_changed || xmtbyte_eies_sent);
        latched_prior_ltssm_l0p_last_lanes_active <= #TP (next_l0p_state!=curnt_l0p_state) ? r_ltssm_l0p_lanes_active_d : latched_prior_ltssm_l0p_last_lanes_active;
    end
end

assign latched_xdlh_cdm_clear = (next_l0p_state!=curnt_l0p_state && (next_l0p_state==S_L0P_DW_REQ || next_l0p_state==S_L0P_UP_REQ_TS1 || (next_l0p_state==S_L0P_UP_REQ_WAIT && curnt_l0p_state==S_L0P_WAIT_REQ_BOTH)));
assign l0p_in_progress        = (curnt_l0p_state==S_L0P_DW_REQ) || (curnt_l0p_state==S_L0P_UP_REQ_WAIT) || (curnt_l0p_state==S_L0P_UP_REQ_TS1) || (curnt_l0p_state==S_L0P_UP_REQ_TS2) || (curnt_l0p_state==S_L0P_UP_REQ_DONE) || (curnt_l0p_state==S_L0P_WAIT_REQ_BOTH && next_l0p_state==S_L0P_UP_REQ_WAIT);
assign mux_xdlh_smlh_link_req   = latched_xdlh_smlh_link_req || xdlh_smlh_link_req;
assign mux_xdlh_smlh_link_width = (latched_xdlh_smlh_link_req) ? latched_xdlh_smlh_link_width : xdlh_smlh_link_width;
assign mux_xdlh_smlh_link_initiated = (latched_xdlh_smlh_link_req) ? latched_xdlh_smlh_link_initiated : xdlh_smlh_link_initiated;
assign pre_l0p_clear          = ((next_l0p_state!=curnt_l0p_state) && ((next_l0p_state==S_L0P_DW_REQ) || (next_l0p_state==S_L0P_UP_REQ_WAIT) || (next_l0p_state==S_L0P_UP_REQ_TS1) || (next_l0p_state==S_L0P_UP_REQ_TS2) || (next_l0p_state==S_L0P_WAIT_REQ_BOTH) || (curnt_l0p_state==S_L0P_UP_REQ_DONE)));
assign disable_timer_clear_in_l0p = (curnt_l0p_state==S_L0P_UP_REQ_TS2) && ~ltssm_in_rcvry_lock;
assign l0p_goto_recovery      = timeout_24ms && l0p_in_progress && ~clear && ~pre_l0p_clear;
// assignment for output signals
assign smlh_l0p_update        = r_smlh_l0p_update_d;
assign smlh_l0p_next_link_mode = r_smlh_l0p_next_link_mode_d;
assign smlh_l0p_link_mode     = r_smlh_l0p_link_mode_d;
assign ltssm_l0p_lanes_active = r_ltssm_l0p_lanes_active_d;
assign ltssm_l0p_last_lanes_active = r_ltssm_l0p_last_lanes_active_d;
assign ltssm_l0p_cmd          = r_ltssm_l0p_cmd_d;
assign ltssm_l0p_cmd_4_eieos_req = r_ltssm_l0p_cmd_4_eieos_req_d;
assign smlh_ltssm_in_l0p      = (curnt_l0p_state!=S_L0P_IDLE) && (curnt_l0p_state!=S_L0P_WAIT_REQ_DW);
assign smlh_ltssm_in_l0p_upsize = (curnt_l0p_state==S_L0P_UP_REQ_TS2) || (curnt_l0p_state==S_L0P_UP_REQ_DONE);
assign smlh_ltssm_l0p_ready   = (curnt_l0p_state==S_L0P_WAIT_REQ_DW) || (curnt_l0p_state==S_L0P_WAIT_REQ_BOTH);
assign smlh_flit_error_link_widh = 0;
assign smlh_xdlh_eios_rcvd   = rmlh_rcvd_eidle_set && ltssm==S_L0 && ltssm_flit_mode_enable;
assign l0p_tx_rx_linkwidth_done = (rmlh_rplh_rxdata_link_width==smlh_l0p_next_link_mode[4:0]) && latched_xmtbyte_l0p_linkwidth_changed;
assign l0p_in_rcvry = (curnt_l0p_state==S_L0P_UP_RCVRY);

always @(posedge core_clk or negedge core_rst_n) begin : ltssm_l0p_capable_PROC
    if (!core_rst_n)
        ltssm_l0p_capable <= #TP 0;
    else if(lts_state == S_DETECT_QUIET)
        ltssm_l0p_capable <= #TP 0;
    else if((lts_state == S_CFG_COMPLETE) && ~clear && link_ln0_8_ts2_linknmtx_lanenmtx_rcvd && ~smlh_link_up && ltssm_flit_mode_enable)
        ltssm_l0p_capable <= #TP link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd & ltssm_ts_auto_change; // rx and tx
end

assign smlh_l0p_capable = ltssm_l0p_capable;

  // this is used to allow one time retry receiver detect
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        retry_detect      <= #TP 0;
    else
        retry_detect      <= #TP (ltssm == S_DETECT_QUIET) ? 1'b0 : (ltssm == S_DETECT_WAIT) ? 1'b1 : retry_detect;

reg                 cfg_force_en_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        cfg_force_en_d      <= #TP 0;
    else
        cfg_force_en_d      <= #TP cfg_force_en;

wire                cfg_force_state;
assign  cfg_force_state = !cfg_force_en_d & cfg_force_en;

assign  current_n_fts = |mac_phy_rate ? cfg_gen2_n_fts : cfg_n_fts;

wire   [8:0]  floor_p_nfts;
wire   [8:0]  floor_x2_p_nfts;
wire   [23:0] floor_x2_p_nfts_x_8;
wire   [23:0] floor_p_nfts_x_16;
wire   [23:0] floor_p_nfts_x_32;
wire   [23:0] nfts_x_16;
wire   [23:0] nfts_x_32;
wire   [T_WD-1:0] timeout_nfts_value;
assign floor_p_nfts = {6'b0,current_n_fts[7:5]}+{1'b0,current_n_fts}; //N_FTS + Floor(N_FTS/32)
assign floor_x2_p_nfts = {5'b0,current_n_fts[7:5]<<1}+{1'b0,current_n_fts}; //N_FTS + 2*Floor(N_FTS/32)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The left shift of floor_x2_p_nfts_x_8,floor_p_nfts_x_16,floor_p_nfts_x_32,nfts_x_16,nfts_x_32 insures that the MSB will be 0 in which case the addition cannot overflow and there is space for the carry bit.
assign floor_x2_p_nfts_x_8 = ({15'b0,floor_x2_p_nfts}<<3);
assign floor_p_nfts_x_16 = ({15'b0,floor_p_nfts}<<4);
assign floor_p_nfts_x_32 = ({15'b0,floor_p_nfts}<<5);
assign nfts_x_16 = ({16'b0,current_n_fts}<<4);
assign nfts_x_32 = ({16'b0,current_n_fts}<<5);
// spyglass enable_block W164a

//UI = 400ps for Gen1, 200ps for Gen2, 125ps for Gen3, 62.5ps for Gen4, 31.25ps for Gen5
//each clock takes 4ns for CX_PL_FREQ_VALUE=0, 8ns for CX_PL_FREQ_VALUE=1, 16ns for CX_PL_FREQ_VALUE=2
//calculated timeout value needs to be divided by 4 for CX_PL_FREQ_VALUE=0, by 8 for CX_PL_FREQ_VALUE=1, by 16 for CX_PL_FREQ_VALUE=2, and then match timer number

//Gen1
//When ext_synch=0, Spec required time is 40*(N_FTS+3)*UI*2 (ps) = 96+(32*N_FTS) (ns)
//     timeout_nfts_value = ((96+(32*N_FTS)) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 40*2048*UI*2 (ps) = 65536 (ns)
//     timeout_nfts_value = 16384 >> CX_PL_FREQ_VALUE

//Gen2
//When ext_synch=0, Spec required time is 40*(N_FTS+3)*UI*2 (ps) = 48+(16*N_FTS) (ns)
//     timeout_nfts_value = ((48+(16*N_FTS)) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 40*2048*UI*2 (ps) = 32768 (ns)
//     timeout_nfts_value = 8192 >> CX_PL_FREQ_VALUE

//Gen3
//When ext_synch=0, Spec required time is 130*(N_FTS+5+Floor(N_FTS/32))*UI*2 (ps) = 162+(32*(N_FTS+Floor(N_FTS/32))) (ns)
//     timeout_nfts_value = ((162+(32*(N_FTS+Floor(N_FTS/32)))) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 130*(4096+5+12+(4096/32))*UI*2 (ps) = 137832 (ns)
//     timeout_nfts_value = 34458 >> CX_PL_FREQ_VALUE

//Gen4
//When ext_synch=0, Spec required time is 130*(N_FTS+5+Floor(N_FTS/32))*UI*2 (ps) = 81+(16*(N_FTS+Floor(N_FTS/32))) (ns)
//     timeout_nfts_value = ((81+(16*(N_FTS+Floor(N_FTS/32)))) >> 2) >> CX_PL_FREQ_VALUE
//When ext_synch=1, Spec required time is 130*(4096+5+12+(4096/32))*UI*2 (ps) = 68916 (ns)
//     timeout_nfts_value = 17229 >> CX_PL_FREQ_VALUE

//Gen5
//When ext_synch=0, Spec required time is 130*(N_FTS+10+2*Floor(N_FTS/32))*UI*2 (ps) = 81+(8*(N_FTS+2*Floor(N_FTS/32))) (ns)
//     timeout_nfts_value = ((81+(8*(N_FTS+2*Floor(N_FTS/32)))) >> 2) >> CX_FREQ_VALUE
//When ext_synch=1, Spec required time is 130*(4096+10+12+2*(4096/32))*UI*2 (ps) = 35538 (ns)
//     timeout_nfts_value = 8886 >> CX_FREQ_VALUE

assign timeout_nfts_value = cfg_ext_synch ? (
                                              (g5_rate) ? (8886>>`CX_PL_FREQ_VALUE) :
                                              (g4_rate) ? (17229>>`CX_PL_FREQ_VALUE) :
                                              (g3_rate) ? (34458>>`CX_PL_FREQ_VALUE) :
                                              (g2_rate) ? (8192>>`CX_PL_FREQ_VALUE) :
                                                                                (16384>>`CX_PL_FREQ_VALUE) ) :
                                            (
                                              (g5_rate) ? (((81+floor_x2_p_nfts_x_8)>>2)>>`CX_PL_FREQ_VALUE) :
                                              (g4_rate) ? (((81+floor_p_nfts_x_16)>>2)>>`CX_PL_FREQ_VALUE) :
                                              (g3_rate) ? (((162+floor_p_nfts_x_32)>>2)>>`CX_PL_FREQ_VALUE) :
                                              (g2_rate) ? (((48+nfts_x_16)>>2)>>`CX_PL_FREQ_VALUE) :
                                                                                (((96+nfts_x_32)>>2)>>`CX_PL_FREQ_VALUE)
                                            );

// cannot freeze the timer when mac_phy_rate != current_data_rate because it will cause issue when phystatus never be back.
// when (mac_phy_rate > current_data_rate), use mac_phy_rate to assign timer2; else use current_data_rate.
// this will keep timer running to prevent LTSSM stuck because of no timeout occuring if phystatus never be back.
// the calculated timing might be bigger than expected.
logic   [2:0]  int_data_rate;
logic   [2:0]   gen1_freq;
logic   [2:0]   gen2_freq;
logic   [2:0]   gen3_freq;
logic   [2:0]   gen4_freq;
logic   [2:0]   gen5_freq;
logic   [3:0]   gen6_freq;
logic   [3:0]   current_freq;
logic   [3:0]   next_freq;

always_comb begin
    case(`CX_NB_GEN1)
//        1:gen1_freq = 3'd3;  // 250MHz
        2:gen1_freq = 3'd2;  // 125MHz
        4:gen1_freq = 3'd1;  // 62.5MHz
        default:gen1_freq = 3'd3;  // 250MHz
    endcase
end

always_comb begin
    case(`CX_NB_GEN2)
        1:gen2_freq = 3'd4;  // 500MHz
        2:gen2_freq = 3'd3;  // 250MHz
        4:gen2_freq = 3'd2;  // 125MHz
        default:gen2_freq = 3'd4;  // 500MHz
    endcase
end

always_comb begin
    case(`CX_NB_GEN3)
        1:gen3_freq = 3'd5;  // 1000MHz
        2:gen3_freq = 3'd4;  // 500MHz
        4:gen3_freq = 3'd3;  // 250MHz
        8:gen3_freq = 3'd2;  // 125MHz
        16:gen3_freq = 3'd1;  // 62.5MHz
        default:gen3_freq = 3'd5;  // 1000MHz
    endcase
end

always_comb begin
    case(`CX_NB_GEN4)
        1:gen4_freq = 3'd6;
        2:gen4_freq = 3'd5;  // 1000MHz
        4:gen4_freq = 3'd4;  // 500MHz
        8:gen4_freq = 3'd3;  // 250MHz
        16:gen4_freq = 3'd2;  // 125MHz
        default:gen4_freq = 3'd6;  
    endcase
end

always_comb begin
    case(`CX_NB_GEN5)
        1:gen5_freq = 3'd7;  // 
        2:gen5_freq = 3'd6;  // 2000MHz
        4:gen5_freq = 3'd5;  // 1000MHz
        8:gen5_freq = 3'd4;  // 500MHz
        16:gen5_freq = 3'd3;  // 250MHz
        default:gen5_freq = 3'd7; 
    endcase
end

always_comb begin
    case(`CX_NB_GEN6)
        1:gen6_freq = 4'd8;  // 
        2:gen6_freq = 4'd7;  // 4000MHz
        4:gen6_freq = 4'd6;  // 2000MHz
        8:gen6_freq = 4'd5;  // 1000MHz
        16:gen6_freq = 4'd4;  // 500MHz
        default:gen6_freq = 4'd8;
    endcase
end

always_comb begin
    case(current_data_rate)
//        3'h0: current_freq = gen1_freq;
        3'h1: current_freq = {1'b0,gen2_freq};
        3'h2: current_freq = {1'b0,gen3_freq};
        3'h3: current_freq = {1'b0,gen4_freq};
        3'h4: current_freq = {1'b0,gen5_freq};
        3'h5: current_freq = gen6_freq;
        default: current_freq = {1'b0,gen1_freq};
    endcase
end

always_comb begin
    case(mac_phy_rate)
//        3'h0: next_freq = gen1_freq;
        3'h1: next_freq = {1'b0,gen2_freq};
        3'h2: next_freq = {1'b0,gen3_freq};
        3'h3: next_freq = {1'b0,gen4_freq};
        3'h4: next_freq = {1'b0,gen5_freq};
        3'h5: next_freq = gen6_freq;
        default: next_freq = {1'b0,gen1_freq};
    endcase
end


always_comb begin
    if( current_freq >= next_freq )begin
        int_data_rate = current_data_rate;
    end
    else begin
        int_data_rate = mac_phy_rate;
    end
end

wire       timer2;
wire   timer_freq_multiplier;
assign timer_freq_multiplier = 1'b1;

DWC_pcie_tim_gen
 u_gen_timer2
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)

    ,.current_data_rate (int_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)

    ,.cnt_up_en         (timer2)  // timer count-up 
);


reg  [1:0]  ext_timer; // extend eq timeout to 240msms

reg [T_WD+2-1:0] ext_fast_time_24ms;
reg [T_WD+2-1:0] ext_time_24ms;
reg [T_WD+2-1:0] ext_fast_time_32ms;
reg [T_WD+2-1:0] ext_time_32ms;
reg [T_WD+2-1:0] ext_fast_time_48ms;
reg [T_WD+2-1:0] ext_time_48ms;
reg [T_WD+2-1:0] ext_fast_time_64ms;
reg [T_WD+2-1:0] ext_time_64ms;
always @(*) begin
    case(cdm_ras_des_ext_eq_to_factor)
        2: begin // (x10)
            ext_fast_time_24ms = fast_time_24ms*10;
            ext_fast_time_32ms = fast_time_24ms*9 + fast_time_32ms ; // 248ms (24ms x 10 + 8ms)
            ext_time_24ms      = (`CX_TIME_24MS*10);
            ext_time_32ms      = (`CX_TIME_24MS*9) + `CX_TIME_32MS; // 248ms (24ms x 10 + 8ms)
            ext_fast_time_48ms = fast_time_48ms*10;
            ext_fast_time_64ms = fast_time_48ms*9 + fast_time_64ms ; // 496ms (48ms x 10 + 16ms)
            ext_time_48ms      = (`CX_TIME_48MS*10);
            ext_time_64ms      = (`CX_TIME_48MS*9) + `CX_TIME_64MS; // 496ms (48ms x 10 + 16ms)
        end
        1: begin // (x2)
            ext_fast_time_24ms = fast_time_24ms*2;
            ext_fast_time_32ms = ({2'b00,fast_time_24ms} + {2'b00,fast_time_32ms}) ; // 56ms  (24ms x 2  + 8ms)
            ext_time_24ms      = (`CX_TIME_24MS*2);
            ext_time_32ms      = `CX_TIME_24MS     + `CX_TIME_32MS; // 56ms  (24ms x 2  + 8ms)
            ext_fast_time_48ms = fast_time_48ms*2;
            ext_fast_time_64ms = ({2'b00,fast_time_48ms} + {2'b00,fast_time_64ms}) ; // 112ms  (48ms x 2  + 16ms)
            ext_time_48ms      = (`CX_TIME_48MS*2);
            ext_time_64ms      = `CX_TIME_48MS     + `CX_TIME_64MS; // 112ms  (48ms x 2  + 16ms)
        end
        default: begin
            ext_fast_time_24ms = {2'b00,fast_time_24ms};
            ext_fast_time_32ms = {2'b00,fast_time_32ms};
            ext_time_24ms      = `CX_TIME_24MS;
            ext_time_32ms      = `CX_TIME_32MS;
            ext_fast_time_48ms = {2'b00,fast_time_48ms};
            ext_fast_time_64ms = {2'b00,fast_time_64ms};
            ext_time_48ms      = `CX_TIME_48MS;
            ext_time_64ms      = `CX_TIME_64MS;
        end
    endcase
end

  wire app_ltssm_enable_fall_halt_timer;
  assign app_ltssm_enable_fall_halt_timer = !app_ltssm_enable_dd;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        timer    <= #TP 0;
        // extend timer for eq 24/32 ms timeout
        ext_timer <= #TP 0;
    // clear the timer when in HOT_RESET_ENTRY state and still receiving TS1 with reset
    end else if ((clear && ~disable_timer_clear_in_l0p) || clr_timer_4rl0s
                 || (lts_state==S_HOT_RESET_ENTRY & link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd)
                 || (curnt_lpbk_entry_state==S_LPBK_ENTRY_EIDLE & xmtbyte_eidle_sent)
                 || clr_40ns_timer
                 || app_ltssm_enable_fall_halt_timer) begin
        timer     <= #TP 0;
    // For "8 GT/s Receiver Impedance" ECN, implement 100 ms timer provided cfg_pl_gen3_zrxdc_noncompl is true.
        ext_timer <= #TP 0;
    end else if (   !timeout_48ms || !timeout_64ms 
                || (!timeout_100ms && cfg_pl_gen3_zrxdc_noncompl && (g3_rate || g4_rate || g5_rate || (goe_g6)))
                || (cdm_ras_des_ext_eq_to_factor!=0 && (lts_state == S_RCVRY_EQ2 || lts_state == S_RCVRY_EQ3))
                ) begin
        timer     <= #TP timer + (timer2 ? timer_freq_multiplier : 1'b0);

        if ( compare_t_wd(timer, {25{1'b1}}) )
            ext_timer <= #TP ext_timer + (timer2 ? 1'b1 : 1'b0);
    end

always @(posedge core_clk or negedge core_rst_n) begin : timer_40ns_4rl0s_PROC
    if ( !core_rst_n ) begin
        timer_40ns_4rl0s     <= #TP 0;
    // clear the timer when clr_timer_4rl0s
    end else if ( clr_timer_4rl0s || (rmlh_rcvd_eidle_set && (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE || lts_state == S_L123_SEND_EIDLE || lts_state == S_DISABLED_IDLE || lts_state == S_DISABLED_ENTRY )) ) begin
        timer_40ns_4rl0s     <= #TP 0;
    end else if ( !timeout_40ns_4rl0s || !timeout_40ns_4p1p2 ) begin
        timer_40ns_4rl0s     <= #TP timer_40ns_4rl0s + (timer2 ? timer_freq_multiplier : 1'b0);
    end
end //timer_40ns_4rl0s_PROC

//logic below is to calculate a scaling factor for the 40ns timer used for L0s, L1 and L2 entry. Intent is to scale this timer with n_fts
//to provide more time to the phy to stabilize rxelecidle to 1 and prevent premature exit.
//The min time is 48ns and max time is (4 * 48ns). The multiplier calculation is based on the formula: ((current_n_fts - 2) * (GEN2 ? 8ns : 16ns))/48ns.
//48ns is because `CX_TIME_40NS = 12/`CX_PL_FREQ_MULTIPLIER, (12 * 4ns == 48ns). 8ns for GEN2 is because FTS OS is 4 FTS-Symbols x 2ns.
//16ns for Gen1 and Gen3 is because 4 FTS-Symbols x 4ns for Gen1 and 16 FTS-Symbols x 1ns for Gen3.
wire [1:0] nfts_factor; // scaling factor for low power entry time
assign     nfts_factor = (g2_rate) ? (current_n_fts<14 ? 0 : current_n_fts<26 ? 1 : 2) :
                                                             (current_n_fts<50 ? 0 : current_n_fts<86 ? 1 : 2) ;
// Definition of the Interval Time which is monitoring the RXELECIDLE signal during L0s/L1/L2 Entry.
// cdm_ras_des_pm_entry_interval:
// 00: 40ns     01: 160ns
// 10: 320ns    11: 640ns
wire [2:0] rasdes_interval_factor; 
assign     rasdes_interval_factor = (cdm_ras_des_pm_entry_interval==2'b00)? 0 :
                                (cdm_ras_des_pm_entry_interval==2'b01)? 2 :
                                (cdm_ras_des_pm_entry_interval==2'b10)? 3 : 4 ;


// Timer and logic for inferred electrical idle

reg             speed_clear;        // clear signal for comma timer and timeouts
wire            inf_count_ui;       // indicates that the timer is counting UI's instead of time
reg             latched_eqctl_any_8eqts2_rcvd;
wire int_eqctl_any_8eqts2_rcvd = (((g1_rate || g2_rate) && link_any_8_eq_ts2_spd_chg_1_rcvd & ~clear) || ((g4_rate) && link_any_8_16gteq_ts2_spd_chg_1_rcvd & ~clear)
 || ((g5_rate) && link_any_8_32gteq_ts2_spd_chg_1_rcvd & ~clear)
 || ((g3_rate) && link_any_8_8gteq_ts2_spd_chg_1_rcvd & ~clear)
                                 );

always @(posedge core_clk or negedge core_rst_n) begin : eqctl_any_8eqts2_rcvd_r_PROC
    if ( !core_rst_n ) begin
        latched_eqctl_any_8eqts2_rcvd <= #TP 0;
    end else if ( lts_state != S_RCVRY_RCVRCFG ) begin
        latched_eqctl_any_8eqts2_rcvd <= #TP 0;
    end else if (int_eqctl_any_8eqts2_rcvd && !clear) begin
        latched_eqctl_any_8eqts2_rcvd <= #TP 1;
    end
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_clear         <= #TP 1'b0;
    else
      speed_clear         <= #TP ((next_lts_state != lts_state) & !clear) || app_ltssm_enable_fall_edge ;     // clean flags when the state changes

//latch first ts received in Rcvry.RcvrLock
//latch first ts1 transmitted in Rcvry.RcvrLock
reg  latched_any_rxelecidle_low, latched_ts1_sent_in_rcvrylock;
reg  timeout_common_mode;
wire clear_common_mode;
wire timer_gr_eq_cfg_cmode; //timer is greater than or equal to cfg_l1sub_t_common_mode
wire dsp_timeout_common_mode; //downstream port timeout for common mode

assign clear_common_mode     = (lts_state != S_RCVRY_LOCK || current_powerdown != `P0);
//CX_PL_FREQ_MULTIPLIER    ns/clock   MicroSec     clocks number
//        1                4         1          9'b100000000 = 256 * 4ns  = 1024ns = ~1MicroSec
//        2                8         1          8'b10000000  = 128 * 8ns  = 1024ns = ~1MicroSec
//        4                16        1          7'b1000000   = 64  * 16ns = 1024ns = ~1MicroSec
localparam S_SHIFT_BITS = (`CX_PL_FREQ_MULTIPLIER == 4) ? 2 : (`CX_PL_FREQ_MULTIPLIER == 2) ? 1 : 0;
assign timer_gr_eq_cfg_cmode = ( ((speed_timer >> (8 - S_SHIFT_BITS))) >= {11'h0,cfg_l1sub_t_common_mode} );

always @( posedge core_clk or negedge core_rst_n ) begin : latched_ts1_sent_in_rcvrylock_PROC
    if ( ~core_rst_n ) begin
        latched_ts1_sent_in_rcvrylock <= #TP 0;
    end else if ( clear_common_mode ) begin
        latched_ts1_sent_in_rcvrylock <= #TP 0;
    end else if ( |xmtbyte_ts1_sent ) begin
        latched_ts1_sent_in_rcvrylock <= #TP 1;
    end
end //latched_ts1_sent_in_rcvrylock_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_rxelecidle_low_PROC
    if ( ~core_rst_n ) begin
        latched_any_rxelecidle_low <= #TP 0;
    end else if ( ~(lts_state == S_RCVRY_LOCK || lts_state == S_L1_IDLE) ) begin
        latched_any_rxelecidle_low <= #TP 0;
    end else if ( |(ltssm_lanes_active & ~phy_mac_rxelecidle) ) begin
        latched_any_rxelecidle_low <= #TP 1;
    end
end //latched_any_rxelecidle_low_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : timeout_common_mode_PROC
    if ( ~core_rst_n ) begin
        timeout_common_mode <= #TP 0;
    end else begin
        if ( clear_common_mode || speed_clear ) begin
            timeout_common_mode <= #TP 0;
        end else if ( timer_gr_eq_cfg_cmode ) begin
            timeout_common_mode <= #TP 1;
        end
    end
end //timeout_common_mode_PROC

assign dsp_timeout_common_mode = (cfg_upstream_port ? 1 : (pm_smlh_l1_2_latched ? timeout_common_mode : 1));


reg [18:0] speed_changed_timer;

wire pipe5_speed_changed_clear = (current_data_rate != mac_phy_rate) || (lts_state != S_RCVRY_SPEED && !(ltssm_flit_mode_enable && (lts_state == S_RCVRY_RCVRCFG)));

// link_any_exact_1_ts_rcvd pulses once for first TS1/2 received since ltssm_clear
wire flitmode_speed_changed_clear = ltssm_flit_mode_enable && (lts_state == S_RCVRY_RCVRCFG) && link_any_exact_1_ts_rcvd;

wire speed_changed_clear = pipe5_speed_changed_clear || flitmode_speed_changed_clear;

always @( posedge core_clk or negedge core_rst_n ) begin : speed_changed_timer_PROC
    if ( !core_rst_n ) begin
        speed_changed_timer <= #TP 0;
    end
    else if ( speed_changed_clear ) begin
        speed_changed_timer <= #TP 0;
    end
    else if ( &speed_changed_timer != 1'b1 ) begin
        speed_changed_timer <= #TP speed_changed_timer + (timer2 ? 1'b1 : 1'b0);
    end
end // speed_changed_timer_PROC

reg  speed_changed_timeout_800ns;

always @( posedge core_clk or negedge core_rst_n ) begin : speed_changed_timeout_800ns_PROC
    if ( !core_rst_n ) begin
        speed_changed_timeout_800ns <= #TP 1'b0;
    end
    else if( speed_changed_clear ) begin
        speed_changed_timeout_800ns <= #TP 1'b0;
    end
    else if ( speed_changed_timer == TIME_800NS ) begin
        speed_changed_timeout_800ns <= #TP 1'b1;
    end
end // speed_changed_timeout_800ns_PROC
  
reg  speed_changed_timeout_1ms;

always @( posedge core_clk or negedge core_rst_n ) begin : speed_changed_timeout_1ms_PROC
    if ( !core_rst_n ) begin
        speed_changed_timeout_1ms <= #TP 1'b0;
    end else if( speed_changed_clear ) begin
        speed_changed_timeout_1ms <= #TP 1'b0;
    end else if ((cfg_fast_link_mode && (compare_t_wd(T_WD'(speed_changed_timer), fast_time_1ms))) || (~cfg_fast_link_mode && compare_t_wd(T_WD'(speed_changed_timer), `CX_TIME_1MS))) begin
        speed_changed_timeout_1ms <= #TP 1'b1;
    end
end // speed_changed_timeout_1ms_PROC

  
// This counter counts the cycles since a comma was seen
// we also use it for the timeouts in Recovery.Speed after the receiver detects electrical idle.
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timer         <= #TP 0;
    else if ( speed_clear ||
              // also clean the timer when a comma is received and we haven't already inferred electrical idle.
              ((!latched_eidle_seen || ~(&int_mac_phy_txelecidle_r) || ~smlh_margin_pipe_idle) && (lts_state == S_RCVRY_SPEED))
              || (!latched_eqctl_any_8eqts2_rcvd && (lts_state == S_RCVRY_RCVRCFG)) //clear the timer when 8 consecutive EQ TS2 rcvd on any lane
              || ((~latched_any_rxelecidle_low || ~latched_ts1_sent_in_rcvrylock) && (lts_state == S_RCVRY_LOCK))
            )
        speed_timer         <= #TP 0;
    else if ( ~compare_19(speed_timer, {19{1'b1}}) )  // hold value so we don't wrap
        speed_timer         <= #TP speed_timer + (timer2 ? timer_freq_multiplier : 1'b0);

// used for recovery speed
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timeout_800ns     <= #TP 1'b0;
    else if (speed_clear || !latched_eidle_seen || ~(&int_mac_phy_txelecidle_r))
        speed_timeout_800ns     <= #TP 1'b0;
    else if ( compare_25({6'h0,speed_timer}, `CX_TIME_800NS) && latched_eidle_seen )
        speed_timeout_800ns     <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timeout_6us       <= #TP 1'b0;
    else if (speed_clear || !latched_eidle_seen || ~(&int_mac_phy_txelecidle_r))
        speed_timeout_6us       <= #TP 1'b0;
    else if ( compare_25({6'h0,speed_timer}, `CX_TIME_6US) && latched_eidle_seen)
        speed_timeout_6us       <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        speed_timeout_1ms       <= #TP 1'b0;
    else if (speed_clear || !latched_eqctl_any_8eqts2_rcvd)
        speed_timeout_1ms       <= #TP 1'b0;
    else if ((cfg_fast_link_mode && compare_25({6'h0,speed_timer}, fast_time_1ms[24:0])) || (~cfg_fast_link_mode && compare_25({6'h0,speed_timer}, `CX_TIME_1MS)))
        speed_timeout_1ms       <= #TP 1'b1;

wire    rcvy_speed_eidle_timeout;               // timeout used to time eidle in Recovery.Speed
assign  rcvy_speed_eidle_timeout    = !clear && ((smlh_successful_spd_negotiation) ? speed_timeout_800ns : speed_timeout_6us);

assign  inf_count_ui    = (lts_state == S_RCVRY_RCVRCFG) || (lts_state == S_RCVRY_SPEED);

wire   eidle_inferred_recovery;
assign eidle_inferred_recovery = smlh_eidle_inferred & (lts_state == S_L0);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_eidle_seen       <= #TP 1'b0;
    else if ((smlh_eidle_inferred & !clear) || rmlh_rcvd_eidle_set)
        latched_eidle_seen       <= #TP 1'b1;
    else if ((next_lts_state != lts_state) && ((next_lts_state != S_RCVRY_SPEED) || latched_eidle_inferred) && !clear) // use anticipated clear, needed to avoid races if new state also is sensitive to the flag
        latched_eidle_seen       <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_eidle_inferred   <= #TP 1'b0;
    else if (smlh_eidle_inferred & !clear) // same condition as for the latched_eidle_seen flag, without the EIOS received
        latched_eidle_inferred   <= #TP 1'b1;
    else if (clear) // do not use anticipated clear because this flag is only used after the transition to check that the transition was made with the flag
        latched_eidle_inferred   <= #TP 1'b0;


// timeout value based on link mode
assign  polling_timeout_value   = ( cfg_fast_link_mode ) ?  fast_time_1ms  : `CX_TIME_1MS;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_polling_eidle   <= #TP 0;
    else if ((lts_state == S_POLL_COMPLIANCE) // we are in Polling.Compliance
              && (   ((next_compliance_state == S_COMPL_ENT_TX_EIDLE)  && (curnt_compliance_state != S_COMPL_ENT_TX_EIDLE))            // clear the timeout the state before we'll be checking it
                   || ((next_compliance_state == S_COMPL_EXIT_TX_EIDLE) && (curnt_compliance_state != S_COMPL_EXIT_TX_EIDLE))))
        timeout_polling_eidle   <= #TP 0;
    else if ((lts_state == S_POLL_COMPLIANCE) && (compare_t_wd(timer, polling_timeout_value)))
        timeout_polling_eidle   <= #TP 1'b1;

// End of Eidle Inferred Logic
// -------------------------------------------------------------------------

wire            enter_cfg_linkwidth_start;
assign  enter_cfg_linkwidth_start = (next_lts_state == S_CFG_LINKWD_START) && (lts_state != S_CFG_LINKWD_START) && !clear;

// indicates the state of crosslink resolution
//   00b: Crosslink Resolution is not supported. (The GEN4 is not defined)
//   01b: Crosslink negotiation resolved as an Upstream Port
//   10b: Crosslink negotiation resolved as an Downstream Port
//   11b: Crosslink negotiation is not compleated.
assign smlh_crosslink_resolution =
                                  (cfg_upstream_port)                 ? 2'b01 : 2'b10;


// RxL0s/L1/L2/Disable Entry condition
wire ei_interval_expire;
wire all_rxstandbystatus;
assign all_rxstandbystatus = &( ~int_laneflip_lanes_active_physic_lane | phy_mac_rxstandbystatus_physic_lane ) ;
assign ei_interval_expire  = (cfg_p1_entry_policy[1:0]==2'b00) ? timeout_40ns_4p1p2 : 
                             (cfg_p1_entry_policy[1:0]==2'b01) ? all_phy_mac_rxelecidle :
                             (cfg_p1_entry_policy[1:0]==2'b10) ? all_rxstandbystatus | timeout_40ns_4p1p2 : 1'b1 ;
// L1/L2/Disable Entry Interval Time
// Minimum = 160 ns
// Can be extended to 320ns (640ns if RASDES=1)
reg  [3:0] p1_entry_factor_case;
reg  [2:0] p1_entry_factor;
assign p1_entry_factor_case = { cdm_ras_des_pm_entry_interval, cfg_p1_entry_policy[3:2]};
always @(*) begin
    casez({p1_entry_factor_case})
        4'b11_??: p1_entry_factor = 4 ;  // 640ns
        4'b10_??: p1_entry_factor = 3 ;  // 320ns
        4'b01_??: p1_entry_factor = 2 ;  // 160ns
        4'b00_11: p1_entry_factor = 1 ;  // 80ns
        4'b00_10: p1_entry_factor = 0 ;  // 40ns
        4'b00_01: p1_entry_factor = 3 ;  // 320ns
        default : p1_entry_factor = 2 ;  // Default 160ns
    endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_40ns  <= #TP 0;
    else if (clear || clr_timer_4rl0s || clr_40ns_timer)
        timeout_40ns  <= #TP 0;
    else if (timer >= (`CX_TIME_40NS << nfts_factor << rasdes_interval_factor))
        timeout_40ns  <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_40ns_4rl0s_PROC
    if ( !core_rst_n ) begin
        timeout_40ns_4rl0s  <= #TP 0;
        timeout_40ns_4p1p2  <= #TP 0;
    end
    else if ( clr_timer_4rl0s || (rmlh_rcvd_eidle_set && (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE || lts_state == S_L123_SEND_EIDLE || lts_state == S_DISABLED_IDLE || lts_state == S_DISABLED_ENTRY )) ) begin
        timeout_40ns_4rl0s  <= #TP 0;
        timeout_40ns_4p1p2  <= #TP 0;
    end
    else begin
        if (  timer_40ns_4rl0s >= (`CX_TIME_40NS << p1_entry_factor) )
        timeout_40ns_4p1p2   <= #TP 1'b1;
        if ( timer_40ns_4rl0s >= ((`CX_TIME_40NS << nfts_factor << rasdes_interval_factor )) )
        timeout_40ns_4rl0s  <= #TP 1'b1;
    end
end //timeout_40ns_4rl0s_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_1ms  <= #TP 0;
    else if (clear)
        timeout_1ms  <= #TP 0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_1ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_1MS)))  
        timeout_1ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_1ms_d_PROC
    if ( ~core_rst_n ) begin
        timeout_1ms_d <= #TP 0;
    end else begin
        timeout_1ms_d <= #TP timeout_1ms;
    end
end // timeout_1ms_d_PROC

assign int_timeout_1ms_rising_edge = timeout_1ms & ~timeout_1ms_d;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_1us  <= #TP 0;
    else if (clear)
        timeout_1us  <= #TP 0;
    else if (compare_t_wd(timer, `CX_TIME_1US))
        timeout_1us <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_10us  <= #TP 0;
    else if (clear)
        timeout_10us  <= #TP 0;
    else if (compare_t_wd(timer, `CX_TIME_10US))
        timeout_10us <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_16us  <= #TP 0;
    else if (clear)
        timeout_16us  <= #TP 0;
    else if (compare_t_wd(timer, `CX_TIME_16US))
        timeout_16us <= #TP 1'b1;



always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_2ms  <= #TP 0;
    else if (clear)
        timeout_2ms  <= #TP 0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_2ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_2MS)))  
        timeout_2ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_2ms_d_PROC
    if (!core_rst_n)
        timeout_2ms_d <= #TP 0;
    else
        timeout_2ms_d <= #TP timeout_2ms;
end // timeout_2ms_d_PROC

assign int_timeout_2ms_rising_edge = timeout_2ms & ~timeout_2ms_d;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_12ms_d_PROC
    if (!core_rst_n)
        timeout_12ms_d <= #TP 0;
    else
        timeout_12ms_d <= #TP timeout_12ms;
end // timeout_2ms_d_PROC

assign int_timeout_12ms_rising_edge = timeout_12ms & ~timeout_12ms_d;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_24ms_d_PROC
    if (!core_rst_n)
        timeout_24ms_d <= #TP 0;
    else
        timeout_24ms_d <= #TP timeout_24ms;
end // timeout_2ms_d_PROC

assign int_timeout_24ms_rising_edge = timeout_24ms & ~timeout_24ms_d;

always @(posedge core_clk or negedge core_rst_n) begin : timeout_3ms_PROC
    if (!core_rst_n)
        timeout_3ms  <= #TP 0;
    else if (clear)
        timeout_3ms  <= #TP 0;
    else if ( (cfg_fast_link_mode && (compare_t_wd(timer, fast_time_3ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_3MS)) )  
        timeout_3ms <= #TP 1'b1;
end // timeout_3ms_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_12ms <= #TP 1'b0;
    else if (clear)
        timeout_12ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_12ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_12MS)))  
        timeout_12ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_10ms <= #TP 1'b0;
    else if (clear)
        timeout_10ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && (compare_t_wd(timer, fast_time_10ms))) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_10MS)))  
        timeout_10ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_24ms <= #TP 1'b0;
    else if (clear)
        timeout_24ms <= #TP 1'b0;
    else if (cdm_ras_des_ext_eq_to_factor!=0 && ((cfg_upstream_port && lts_state==S_RCVRY_EQ2) || (!cfg_upstream_port && lts_state==S_RCVRY_EQ3))) begin
        if (cdm_ras_des_ext_eq_to_factor==2'b11)
            timeout_24ms <= #TP 1'b0;
        else if ((cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_fast_time_24ms)) || (~cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_time_24ms))) 
            timeout_24ms <= #TP 1'b1;
    end
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_24ms)) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_24MS))) 
        timeout_24ms <= #TP 1'b1;

    `define ZBITS 7'h0
    localparam ZBW = 3'd7;   // 7 bits

always @(*) begin : timer_24ms_cnt_i_PROC
    integer cnt_i;
    timer_24ms_cnt_i = ltssm_timer_24ms_cnt;

    for ( cnt_i=0; cnt_i<=24; cnt_i=cnt_i+1 ) begin
        if ( cfg_fast_link_mode ) begin
            if ( compare_t_wd_pz({`ZBITS,timer}, (cnt_i * fast_time_1ms)) )
                timer_24ms_cnt_i = cnt_i;
        end else begin
            if ( compare_t_wd_pz({`ZBITS,timer}, (cnt_i * `CX_TIME_1MS)) )
                timer_24ms_cnt_i = cnt_i;
        end //if ( cfg_fast_link_mode
    end //for ( cnt_i
end //always @(*)

always @(posedge core_clk or negedge core_rst_n) begin : ltssm_timer_24ms_cnt_PROC
    if (!core_rst_n) begin
        ltssm_timer_24ms_cnt <= #TP '0;
    end else if ( clear ) begin
        ltssm_timer_24ms_cnt <= #TP '0;
    end else begin
        ltssm_timer_24ms_cnt <= #TP timer_24ms_cnt_i;
    end
end //always @(posedge

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_32ms <= #TP 1'b0;
    else if (clear)
        timeout_32ms <= #TP 1'b0;
    else if (cdm_ras_des_ext_eq_to_factor!=0 && ((!cfg_upstream_port && lts_state==S_RCVRY_EQ2) || (cfg_upstream_port && lts_state==S_RCVRY_EQ3))) begin
        if (cdm_ras_des_ext_eq_to_factor==2'b11)
            timeout_32ms <= #TP 1'b0;
        else if ((cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_fast_time_32ms)) || (~cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_time_32ms))) 
            timeout_32ms <= #TP 1'b1;
    end
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_32ms)) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_32MS))) 
        timeout_32ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_48ms <= #TP 1'b0;
    else if (clear || clr_timer_4rl0s) // clear timeout_48ms to keep the timer running to count 40ns when transitioning L0 -> Rx.L0s
        timeout_48ms <= #TP 1'b0;
    else if (cdm_ras_des_ext_eq_to_factor!=0 && ((cfg_upstream_port && lts_state==S_RCVRY_EQ2) || (!cfg_upstream_port && lts_state==S_RCVRY_EQ3))) begin
        if (cdm_ras_des_ext_eq_to_factor==2'b11)
            timeout_48ms <= #TP 1'b0;
        else if ((cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_fast_time_48ms)) || (~cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_time_48ms))) 
            timeout_48ms <= #TP 1'b1;
    end
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_48ms)) || (~cfg_fast_link_mode && compare_t_wd(timer,`CX_TIME_48MS)))
        timeout_48ms <= #TP 1'b1;

always @( posedge core_clk or negedge core_rst_n ) begin : timeout_64ms_PROC
    if (!core_rst_n)
        timeout_64ms <= #TP 1'b0;
    else if ( clear )
        timeout_64ms <= #TP 1'b0;
    else if (cdm_ras_des_ext_eq_to_factor!=0 && ((!cfg_upstream_port && lts_state==S_RCVRY_EQ2) || (cfg_upstream_port && lts_state==S_RCVRY_EQ3))) begin
        if (cdm_ras_des_ext_eq_to_factor==2'b11)
            timeout_64ms <= #TP 1'b0;
        else if ((cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_fast_time_64ms)) || (~cfg_fast_link_mode && compare_t_wd_p2({ext_timer,timer}, ext_time_64ms))) 
            timeout_64ms <= #TP 1'b1;
    end
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_64ms)) || (~cfg_fast_link_mode && compare_t_wd(timer,`CX_TIME_64MS)))
        timeout_64ms <= #TP 1'b1;
end // timeout_64ms_PROC


// For "8 GT/s Receiver Impedance" ECN, implement a 100 ms timer.
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_100ms <= #TP 1'b0;
    else if (clear || clr_timer_4rl0s) // clear timeout_100ms to keep the timer running to count 40ns when transitioning L0 -> Rx.L0s
        timeout_100ms <= #TP 1'b0;
    else if ((cfg_fast_link_mode && compare_t_wd(timer, fast_time_100ms)) || (~cfg_fast_link_mode && compare_t_wd(timer, `CX_TIME_100MS))) 
        timeout_100ms <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        timeout_nfts <= #TP 0;
    else if (clear | clr_timer_4rl0s)
        timeout_nfts <= #TP 1'b0;
    else if (timer >= timeout_nfts_value)
        timeout_nfts <= #TP 1'b1;


 assign timeout_detect_quiet         = timeout_12ms;       
 assign timeout_detect_wait          = timeout_12ms;          
 assign timeout_poll_active          = timeout_24ms;          
 assign timeout_poll_config          = timeout_48ms;      
 assign timeout_cfg_linkwd_start     = timeout_32ms;          
 assign timeout_cfg_linkwd_acept     = timeout_3ms ;           
 assign timeout_cfg_lanenum_wait     = timeout_3ms ;                       
 assign timeout_cfg_lanenum_acept    = timeout_3ms ;             
 assign timeout_cfg_complete         = timeout_2ms ;             
 assign timeout_cfg_idle             = timeout_2ms ;                
 assign timeout_rcvry_lock           = timeout_24ms;                         
 assign timeout_eq0                  = timeout_12ms ;
 assign timeout_dsp_eq1              = timeout_24ms ;
 assign timeout_usp_eq1              = timeout_12ms ;
 assign timeout_usp_eq2_g3           = timeout_24ms ;
 assign timeout_usp_eq3_g3           = timeout_32ms ;
 assign timeout_dsp_eq2_g3           = timeout_32ms ;
 assign timeout_dsp_eq3_g3           = timeout_24ms ;
 assign timeout_usp_eq2_g6           = timeout_48ms ;
 assign timeout_usp_eq3_g6           = timeout_64ms ;
 assign timeout_dsp_eq2_g6           = timeout_64ms ;
 assign timeout_dsp_eq3_g6           = timeout_48ms ;
 assign timeout_rcvry_speed_g6       = timeout_48ms ;               
 assign timeout_lpbk_entry_eq        =  timeout_48ms ;
 assign timeout_rcvry_speed          = timeout_48ms ;               
 assign timeout_rcvry_rcvrcfg        = timeout_48ms ;                
 assign timeout_rcvry_idle           = timeout_2ms  ;      
 assign timeout_l123_send_eidle      = timeout_2ms  ;      
 assign timeout_hot_reset            = timeout_2ms  ;    
 assign timeout_usp_disable_idle     = timeout_2ms  ;      
 assign timeout_lpbk_entry           = timeout_24ms ;      
 assign timeout_lpbk_exit            = timeout_2ms  ;     


wire                detect_state;
assign  detect_state = (lts_state == S_DETECT_ACT) | (lts_state == S_DETECT_QUIET);

wire    [NL-1:0]    predet_lanes;  // predetermined lanes from cfg_lane_en
assign  predet_lanes = Get_predet_lane_mask({4'b0000, cfg_lane_en[4:0]}); // don't use upper bits because these bits are repurposed to control autoflip

// This function converts a number of lanes (from cfg_lane_en) into a mask with one bit per lane.
// Example: if NL=8 and cfg_lane_en = 9'd4, Get_predet_lane_mask = 8'b00001111
function automatic [NL-1:0]   Get_predet_lane_mask;
input   [8:0]       cfg_lane_en;
// LMD: Use fully assigned variables in function
// LJ: The range of values of the variable i are define by the parameter NL
// leda FM_2_35 off
reg     [NL-1:0]    int_predet_lanes;
integer             i;
    begin
        int_predet_lanes = {NL{1'b0}};
        for (i = 0; i < NL; i= i+1)
            if (i < cfg_lane_en)
                int_predet_lanes[i] = 1'b1;

        Get_predet_lane_mask = int_predet_lanes;
    end
// leda FM_2_35 on
endfunction

// This function picks up a lane which equals to cfg_lane_under_test into a mask with one bit per lane.
// Example: if NL=8 and cfg_lane_under_test = 4'd2, get_lut = 8'b00000100
function automatic [NL-1:0]   get_lut;
input   [3:0]       cfg_lane_under_test;
// LMD: Use fully assigned variables in function
// LJ: The range of values of the variable i are define by the parameter NL
// leda FM_2_35 off
reg     [NL-1:0]    int_lut;
integer             i;
    begin
        int_lut = {NL{1'b0}};
        for (i = 0; i < NL; i= i+1)
            if (i == cfg_lane_under_test)
                int_lut[i] = 1'b1;

        get_lut = int_lut;
    end
// leda FM_2_35 on
endfunction

always @(posedge core_clk or negedge core_rst_n) begin : latchd_rxeidle_exit_PROC
    integer i;
    if (!core_rst_n)
        latchd_rxeidle_exit  <= #TP 0;
    else if (clear)
        latchd_rxeidle_exit  <= #TP 0;
    else
        for (i = 0; i < NL; i= i+1)
           if (!(ltssm_lanes_active[i] & predet_lanes[i]) | (!phy_mac_rxelecidle[i] & ltssm_lanes_active[i] & predet_lanes[i]))
             latchd_rxeidle_exit[i]  <= #TP 1'b1;
end

//cfg_support_part_lanes_rxei_exit = 1: any lanes receives 8 consecutive TS OS, Polling.Active -> Polling.Config (Rx 8 TS means Rx EI exit on that lane from base spec).
//                                      no any lanes receive 8 consecutive TS OS and any predetermined lanes are still on Rx ElecIdle, Polling.Active -> Polling.Compliance.
//cfg_support_part_lanes_rxei_exit = 0: any lanes receives 8 consecutive TS OS and all predetermined lanes have Rx ElecIdle exit, Polling.Active -> Polling.Config (legacy from Base Spec)
//                                      Else, any predetermined lanes are still on Rx ElecIdle, Polling.Active -> Polling.Compliance (legacy from Base Spec).
wire all_predet_lane_latchd_rxeidle_exit;
assign all_predet_lane_latchd_rxeidle_exit = cfg_support_part_lanes_rxei_exit ? 1'b1 : (&latchd_rxeidle_exit);

wire                any_predet_lane_rxeidle_exit;
assign  any_predet_lane_rxeidle_exit    = |(~phy_mac_rxelecidle & predet_lanes);        // for each lane (bit) not in eidle and its a predetermined lane

reg     [NL-1:0]    phy_mac_rxelecidle_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        phy_mac_rxelecidle_d  <= #TP 0;
    else
        phy_mac_rxelecidle_d  <= #TP phy_mac_rxelecidle;

assign  rxelecidle_fall = phy_mac_rxelecidle_d & ~phy_mac_rxelecidle;

always @(posedge core_clk or negedge core_rst_n) begin : latched_rxeidle_exit_PROC
    integer i;
    if (!core_rst_n)
        latched_rxeidle_exit_detected <= #TP 0;
    else if ( lts_state != S_POLL_ACTIVE )
        latched_rxeidle_exit_detected <= #TP 0;
    else begin
        for (i = 0; i < NL; i= i+1) begin
           if ( rxelecidle_fall[i] )
               latched_rxeidle_exit_detected[i] <= #TP 1;
        end
    end
end // latched_rxeidle_exit_PROC

always @(posedge core_clk or negedge core_rst_n) begin : latched_rxeidle_PROC
    integer i;
    if (!core_rst_n)
        latched_rxeidle <= #TP 0;
    else if ( lts_state != S_POLL_ACTIVE )
        latched_rxeidle <= #TP 0;
    else begin
        for (i = 0; i < NL; i= i+1) begin
           if ( latched_rxeidle_exit_detected[i] )
               latched_rxeidle[i] <= #TP 0;
           else if ( phy_mac_rxelecidle[i] )
               latched_rxeidle[i] <= #TP 1;
        end
    end
end // latched_rxeidle_PROC

assign any_predet_lane_latched_rxeidle = |(latched_rxeidle & ltssm_lanes_active & predet_lanes);


// Latch the value of cfg_enter_compliance when we enter Polling.Compliance
reg                 latched_enter_compliance;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_enter_compliance    <= #TP 0;
    else if ((lts_state == S_POLL_ACTIVE) && (next_lts_state == S_POLL_COMPLIANCE) && !clear)
        latched_enter_compliance    <= #TP cfg_enter_compliance;

reg                 latched_ts_disable;
reg                 latched_ts_lpbk;
reg                 latched_ts_slv_cmpl_rcv;
reg                 latched_ts_rst;
reg                 latched_ts_scrmb_dis;
reg                 latched_ts_lannum_rev;
reg     [7:0]       latched_ts_lnknum;
reg                 latched_ts_speed_change;
reg                 latched_ts_deemphasis;
reg                 latched_ts_deemphasis_var;
reg                 latched_link_any_8_ts_linknmtx_lanenmtx_rcvd;
wire                any_8_ts_linknmtx_lanenmtx_rcvd;
reg     [1:0]       latched_cmp_data_rate; // [0]gen2 [1]gen3(not used)
reg                 persist_2scrmb_dis_rcvd;
reg                 latched_rcvd_lnkpad;
reg                 latched_rcvd_lanpad;
reg     [3*NL-1:0]  eidle_continuity_cnt;
reg     [NL-1:0]    rcvd_valid_eidle_set;
reg     [NL-1:0]    eidle_cnt_clear;
wire    [2:0]       eidle_cnt_max;

// ------------------------------------------------------------------------------
// counters designed for ltssm
always@(posedge core_clk or negedge core_rst_n) begin : latchd_smlh_lanes_rcving_PROC
    if (!core_rst_n)
        latchd_smlh_lanes_rcving <= #TP 0;
    else if ( int_rxdetect_done )     // all lanes that detected a receiver during detect are considered active
        latchd_smlh_lanes_rcving <= #TP int_rxdetected & ltssm_lanes_active;
    else
        latchd_smlh_lanes_rcving <= #TP smlh_lanes_rcving;
end // latchd_smlh_lanes_rcving_PROC

// we need to detect 8 consecutive TSs on any lanes that are active. Therefore we will have to count the symbols to identify
// the next smlh_ts1_rcvd or smlh_Rcvd_ts2 pulse arrived at the correct cycle. If we missed one pusle, we have
// to clear the count and start over again.
//
always@(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        rcvd_ts_auto_change   <= #TP 1'b0;
    else if (clear && (lts_state != S_RCVRY_SPEED))
        rcvd_ts_auto_change   <= #TP 1'b0;
    else if ((lts_state == S_RCVRY_RCVRCFG) && link_any_8_ts_auto_chg)
        rcvd_ts_auto_change   <= #TP 1'b1;
    else if ((lts_state == S_CFG_LANENUM_ACEPT) && link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd)
        rcvd_ts_auto_change   <= #TP 1'b1;
end


// used to determine if TSs were sent during Polling.Active
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ts_sent_in_poll_active  <= #TP 1'b0;
    else if ((next_lts_state == S_POLL_ACTIVE) && (lts_state != S_POLL_ACTIVE) && !clear) // clear on entry to Polling.Active
        ts_sent_in_poll_active  <= #TP 1'b0;
    //else if ((lts_state != S_POLL_ACTIVE) && (lts_state_d == S_POLL_ACTIVE)) // set on leaving Polling.Active
    else if (lts_state == S_POLL_ACTIVE)
        ts_sent_in_poll_active  <= #TP |xmtbyte_ts1_sent || |xmtbyte_ts2_sent || ts_sent_in_poll_active;

//for gen3 rate, from Rcvry.Idle to Cfg.Linkwd.Start, we have two extra Blocks EDS and EIEOS to send in some cases.
//sending TS1 may miss. latched_ts1_sent to guaranttee it is sent
always@(posedge core_clk or negedge core_rst_n) begin : latched_ts1_sent_PROC
    if ( !core_rst_n )
        latched_ts1_sent <= #TP 1'b0;
    else begin
        if ( |xmtbyte_ts1_sent && (lts_state == S_CFG_LINKWD_START) ) //latch xmtbyte_ts1_sent
            latched_ts1_sent <= #TP 1'b1;
        else if ( lts_state != S_CFG_LINKWD_START ) //clear latched_ts1_sent if not in S_CFG_LINKWD_START
            latched_ts1_sent <= #TP 1'b0;
    end
end


always@(posedge core_clk or negedge core_rst_n)
begin : LATCH_8IDLE_RCVD
    if (!core_rst_n)
        rcvd_8idles           <= #TP 1'b0;
    else if (clear)
        rcvd_8idles           <= #TP 1'b0;
    else if (rplh_rcvd_idle[0]) // bit 0: 8 (or more) consecutive idle symbol times received
        rcvd_8idles           <= #TP 1'b1;
end

always@(posedge core_clk or negedge core_rst_n)
begin : LATCH_1IDLE_RCVD
    if (!core_rst_n)
        rcvd_1idle            <= #TP 1'b0;
    else if (clear)
        rcvd_1idle            <= #TP 1'b0;
    else if (rplh_rcvd_idle[1])   // bit 1: 1 idle symbol time received, spec requires to start the idle sent count after 1 idle has been received
        rcvd_1idle            <= #TP 1'b1;
end

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        idle_sent_cnt           <= #TP 5'b0;
    end else if (!rcvd_1idle | clear)   // spec required to start the count after 1 idle has been received
        idle_sent_cnt           <= #TP 0;
    else if ( ltssm_flit_mode_enable )
        idle_sent_cnt           <= #TP idle_sent_cnt + (xplh_xmlh_sof ? 1'b1 : 1'b0);
    else if (ltssm_cxl_enable_d.io_enabled)
        idle_sent_cnt           <= #TP idle_sent_cnt + (xmtbyte_idle_sent ? 1'b1 : 1'b0);
    else if (xmtbyte_idle_sent)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        idle_sent_cnt           <= #TP idle_sent_cnt + active_nb ;
// spyglass enable_block W164a

wire                ts_to_poll_cmp;
reg                 ts_to_poll_cmp_d;
wire                ts_to_poll_cmp_pulse;

assign  ts_to_poll_cmp = ((lts_state == S_POLL_ACTIVE) &&
                          (timeout_24ms && link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd && ~clear)
                         );

assign  ts_to_poll_cmp_pulse = ts_to_poll_cmp && !ts_to_poll_cmp_d;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ts_to_poll_cmp_d     <= #TP 1'b0;
    else
        ts_to_poll_cmp_d     <= #TP ts_to_poll_cmp;

// capture condition that indicates modified compliance pattern should be sent
reg                 send_mod_compliance;
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        send_mod_compliance     <= #TP 1'b0;
    else if ((lts_state == S_POLL_ACTIVE) && ((timeout_24ms && link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd && ~clear
                                              )
                                              || (cfg_enter_compliance && cfg_enter_mod_compliance)) )
        send_mod_compliance     <= #TP 1'b1;
    else if ( (lts_state == S_POLL_COMPLIANCE) && (next_lts_state != S_POLL_COMPLIANCE) && !clear ) // clear when leaving the compliance state
        send_mod_compliance     <= #TP 1'b0;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_ts_deemphasis  <= #TP 1'b0;
    else if (lts_state == S_DETECT_QUIET)
        latched_ts_deemphasis  <= #TP 1'b0;
    else if ( (lts_state == S_POLL_ACTIVE) && link_any_8_ts_linknmtx_lanenmtx_rcvd && ~clear )    // capture for any TS during Polling.Active for Polling.Compliance, here _ts_ on lane0
        latched_ts_deemphasis  <= #TP  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
    else if ( ((lts_state == S_RCVRY_LOCK) && link_any_8_ts_linknmtx_lanenmtx_rcvd && !cfg_upstream_port && ~clear) ||  // for dsp capture from TS1s = link_any_8_ts_linknmtx_lanenmtx_rcvd
              ((lts_state == S_RCVRY_RCVRCFG) && link_any_8_ts_linknmtx_lanenmtx_rcvd && cfg_upstream_port && ~clear) ) // for usp capture from TS2s
        latched_ts_deemphasis  <= #TP  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_ts_deemphasis_var  <= #TP 1'b0;
    else if (lts_state == S_DETECT_QUIET || clear)
        latched_ts_deemphasis_var  <= #TP 1'b0;
    else if ( (lts_state == S_POLL_ACTIVE) && link_any_8_ts_linknmtx_lanenmtx_rcvd && ~clear )    // capture for any TS during Polling.Active for Polling.Compliance, here _ts_ on lane0
        latched_ts_deemphasis_var  <= #TP  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
    else if ( ((lts_state == S_RCVRY_LOCK) && link_any_8_ts_linknmtx_lanenmtx_rcvd && !cfg_upstream_port && ~clear) ||  // for dsp capture from TS1s = link_any_8_ts_linknmtx_lanenmtx_rcvd
              ((lts_state == S_RCVRY_RCVRCFG) && link_any_8_ts_linknmtx_lanenmtx_rcvd && cfg_upstream_port && ~clear) ) // for usp capture from TS2s
        latched_ts_deemphasis_var  <= #TP  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;

// link_any_8_ts_linknmtx_lanenmtx_rcvd is combinatorial logic detecting 8 TSs (TS1s or TS2s) in Polling.Active,
// 8 TS1s in Rcvry.RcvrLock, 8 TS2s in Rcvry.RcvrCfg on any lanes
always @( posedge core_clk or negedge core_rst_n ) begin : latched_link_any_8_ts_linknmtx_lanenmtx_rcvd_PROC
    if ( ~core_rst_n )
        latched_link_any_8_ts_linknmtx_lanenmtx_rcvd <= #TP 1'b0;
    else if ( clear )
        latched_link_any_8_ts_linknmtx_lanenmtx_rcvd <= #TP 1'b0;
    else if ( link_any_8_ts_linknmtx_lanenmtx_rcvd )
        latched_link_any_8_ts_linknmtx_lanenmtx_rcvd <= #TP 1'b1;
end // latched_link_any_8_ts_linknmtx_lanenmtx_rcvd_PROC

assign any_8_ts_linknmtx_lanenmtx_rcvd = latched_link_any_8_ts_linknmtx_lanenmtx_rcvd | link_any_8_ts_linknmtx_lanenmtx_rcvd;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_cmp_data_rate   <= #TP 0;
    else if (clear && !(lts_state_d == S_POLL_ACTIVE) )
        latched_cmp_data_rate   <= #TP 0;
    else if (ts_to_poll_cmp_pulse)  // capture the highest data rate advertised by both sides
        latched_cmp_data_rate   <= #TP                                                           (latched_ts_data_rate_eg6[3] & ltssm_ts_data_rate_eg6[3]) ? 2'b11 :
                                                           (latched_ts_data_rate[2]       & ltssm_ts_data_rate[2]) ? 2'b10 : ( (latched_ts_data_rate[1] & ltssm_ts_data_rate[1]) ? 2'b01 : 2'b00 );


always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_ts_nfts         <= #TP 8'b0;
    else if ( link_any_1_ts_rcvd & ((lts_state == S_CFG_COMPLETE) | (lts_state == S_RCVRY_RCVRCFG)))
        // latched the nfts during the cfg completion state for L0s state
        //
        latched_ts_nfts     <= #TP link_ts_nfts ;

always @( * ) begin : latched_ts_data_rate_PROC
    latched_ts_data_rate = link_latched_ts_data_rate;
end // latched_ts_data_rate_PROC

reg [4:0] latched_ts_data_rate_ever;
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_ts_data_rate_ever <= #TP 0;
//  `ifdef CX_CCIX_ESM_SUPPORT
//    else if ( esm_eq_setting_clear )
//        latched_ts_data_rate_ever <= #TP 0;
//  `endif // CX_CCIX_ESM_SUPPORT
    else latched_ts_data_rate_ever <= #TP (latched_ts_data_rate_ever == 5'b10111 || link_latched_ts_data_rate_ever == 5'b10111) ? 5'b10111 : (latched_ts_data_rate_ever | link_latched_ts_data_rate_ever);

wire [9:0] latched_ts_data_rate_ever_eg6 = latched_ts_data_rate_ever == 5'b10111 ? 10'b0000111111 : {5'h0, latched_ts_data_rate_ever};

reg                 captured_ts_speed_change;
reg     [9:0]       captured_ts_data_rate_eg6;
always @( * ) begin : captured_ts_speed_change_data_rate_PROC
    captured_ts_speed_change = link_latched_ts_spd_chg;
    captured_ts_data_rate    = link_latched_ts_data_rate;
    captured_ts_data_rate_eg6= link_latched_ts_data_rate == 5'b10111 ? 10'b0000111111 : {5'h0, link_latched_ts_data_rate};
end // captured_ts_speed_change_data_rate_PROC

assign ltssm_captured_ts_data_rate_g3 = captured_ts_data_rate_eg6[2] & ~captured_ts_data_rate_eg6[3]; //(captured_ts_data_rate[2] && ~captured_ts_data_rate[3]);
assign ltssm_captured_ts_data_rate_g5 = captured_ts_data_rate_eg6[4] & ~captured_ts_data_rate_eg6[5]; //(captured_ts_data_rate[4]);
assign ltssm_captured_ts_data_rate_g6 = captured_ts_data_rate_eg6[5] & ~captured_ts_data_rate_eg6[6];

// Loopback flags
reg     [4:0]       latched_ts_lpbk_data_rate;
reg                 latched_ts_lpbk_deemphasis;
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_ts_lpbk_data_rate       <= #TP 0;
        latched_ts_lpbk_deemphasis      <= #TP 1'b0;
    end else if ( link_any_1_ts_rcvd && (
                (lts_state == S_POLL_CONFIG)
              | (lts_state == S_CFG_LINKWD_START)
              | (lts_state == S_RCVRY_RCVRCFG)
              | ((lts_state == S_LPBK_ENTRY) && (curnt_lpbk_entry_state == S_LPBK_ENTRY_ADV) && !lpbk_master) ) ) begin
        latched_ts_lpbk_data_rate       <= #TP link_lpbk_ts_data_rate;
        latched_ts_lpbk_deemphasis      <= #TP link_lpbk_ts_deemphasis;
    end

reg [9:0]  requested_data_rate_eg6;
always @(*) begin
    case(cfg_target_link_speed)
        `GEN6_LINK_SP: requested_data_rate_eg6 = cfg_flit_mode_enable_i ? 10'b0000111111 : 10'b0000011111;
        `GEN5_LINK_SP: requested_data_rate_eg6 = 10'b0000011111;
        `GEN4_LINK_SP: requested_data_rate_eg6 = 10'b0000001111;
        `GEN3_LINK_SP: requested_data_rate_eg6 = 10'b0000000111;
        `GEN2_LINK_SP: requested_data_rate_eg6 = 10'b0000000011;
        default      : requested_data_rate_eg6 = 10'b0000000001;
    endcase
end

reg [9:0]  mstr_requested_data_rate_eg6;
always @(*) begin
    case(cfg_pcie_max_link_speed)
        `GEN6_LINK_SP: mstr_requested_data_rate_eg6 = cfg_flit_mode_enable_i ? 10'b0000111111 : 10'b0000011111;
        `GEN5_LINK_SP: mstr_requested_data_rate_eg6 = 10'b0000011111;
        `GEN4_LINK_SP: mstr_requested_data_rate_eg6 = 10'b0000001111;
        `GEN3_LINK_SP: mstr_requested_data_rate_eg6 = 10'b0000000111;
        `GEN2_LINK_SP: mstr_requested_data_rate_eg6 = 10'b0000000011;
        default      : mstr_requested_data_rate_eg6 = 10'b0000000001;
    endcase
end

reg     [9:0]       captured_lpbk_ts_data_rate_eg6;
wire    [9:0]       link_lpbk_ts_data_rate_eg6 = link_lpbk_ts_data_rate == 5'b10111 ? 10'b0000111111 : {5'h0, link_lpbk_ts_data_rate};

reg     [4:0]       captured_lpbk_ts_data_rate;
reg                 captured_lpbk_ts_auto_change;
reg [4:0] int_latched_lpbk_ts_data_rate; //for lpbk master
always @( posedge core_clk or negedge core_rst_n ) begin : int_latched_lpbk_ts_data_rate_PROC
    if (!core_rst_n)
        int_latched_lpbk_ts_data_rate <= #TP 0;
    else if ( (lts_state == S_CFG_LINKWD_START && next_lts_state == S_LPBK_ENTRY && ~clear) )
        int_latched_lpbk_ts_data_rate <= #TP link_latched_lpbk_ts_data_rate;
    else if (g5_rate && lts_state == S_RCVRY_EQ1 && ~clear)
        int_latched_lpbk_ts_data_rate <= #TP link_lpbk_ts_data_rate;
end // int_latched_lpbk_ts_data_rate_PROC

wire [9:0] int_latched_lpbk_ts_data_rate_eg6 = int_latched_lpbk_ts_data_rate == 5'b10111 ? 10'b0000111111 : {5'h0, int_latched_lpbk_ts_data_rate};

always @( * ) begin : captured_lpbk_ts_data_rate_PROC
    if ( lts_state == S_CFG_LINKWD_START && (link_latched_live_all_2_ts1_lpbk1_rcvd || any_2_ts1_lpbk1_ebth1_rcvd) && ~clear ) begin // loopback slave
        captured_lpbk_ts_data_rate_eg6 = (link_lpbk_ts_data_rate_eg6[5] && requested_data_rate_eg6[5]) ? 10'b0000111111 : (link_lpbk_ts_data_rate_eg6 & ltssm_ts_data_rate_eg6);   // capture commonly supported data rates
        captured_lpbk_ts_auto_change = link_lpbk_ts_deemphasis;
    end else begin // loopback master
        // gen6 spec: follower does not advertise gen6 rate in Cfg.Linkwd.Start. How the Loopback Lead obtains the prior knowledge of gen6 rate support is outside the scope of the specification
        captured_lpbk_ts_data_rate_eg6 = /*int_latched_lpbk_ts_data_rate_eg6 &*/ mstr_requested_data_rate_eg6;
        if(lts_state == S_LPBK_ENTRY && g5_rate && equalization_done_32gt_data_rate && perform_eq_for_lpbk_mstr_64gt) begin // For loopback eq
          captured_lpbk_ts_data_rate_eg6 = int_latched_lpbk_ts_data_rate_eg6 & mstr_requested_data_rate_eg6;
        end
        captured_lpbk_ts_auto_change = 0;
    end
end // captured_lpbk_ts_data_rate_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rcvry_to_lpbk       <= #TP 1'b0;
    else if (lts_state == S_DETECT_QUIET)
        rcvry_to_lpbk       <= #TP 1'b0;
    else if ( (last_lts_state == S_RCVRY_IDLE || last_state_is_eq) && (lts_state == S_LPBK_ENTRY) )
        rcvry_to_lpbk       <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : ridle_to_lpbk_PROC
    if (!core_rst_n)
        ridle_to_lpbk       <= #TP 1'b0;
    else if (lts_state == S_DETECT_QUIET)
        ridle_to_lpbk       <= #TP 1'b0;
    else if ( (last_lts_state == S_RCVRY_IDLE) && (lts_state == S_LPBK_ENTRY) )
        ridle_to_lpbk       <= #TP 1'b1;
end // ridle_to_lpbk_PROC

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        lts_state_d         <= #TP S_DETECT_QUIET;
    else
        lts_state_d         <= #TP lts_state;

reg latched_smlh_link_up;
always @( posedge core_clk or negedge sticky_rst_n ) begin : latched_smlh_link_up_PROC
    if ( ~sticky_rst_n ) begin
        latched_smlh_link_up <= #TP 0;
    end else if ( smlh_link_up ) begin
        latched_smlh_link_up <= #TP 1'b1;
    end
end // latched_smlh_link_up_PROC

// need to record lane flip/reversal for Gen5 Loopback Eq because both sides send Gen5 TS1s with scrambling which needs lane number as seed
always @( posedge core_clk or negedge sticky_rst_n ) begin : latched_linkup_lane_flip_ctrl_lpbk_PROC
    if ( ~sticky_rst_n ) begin
        latched_linkup_lane_flip_ctrl_lpbk <= #TP 0;
    // for Gen5 loopback eq if lane flip in Detect state and not go through Linkup but strait to Loopback before Linkup
    end else if ( lts_state != S_CFG_LINKWD_START && next_lts_state == S_CFG_LINKWD_START && ~clear && ((cfg_mux_lpbk_lanenum && ~smlh_link_up) || (~cfg_mux_lpbk_lanenum && ~latched_smlh_link_up)) ) begin
        latched_linkup_lane_flip_ctrl_lpbk <= #TP int_smlh_lane_flip_ctrl;
    // lpbk.active master, reset to 0. instead, use the lane under test (one lane) reversed to Lane 0 to transmit TLPs/DLLPs and loopback (by slave) for check
    end else if ( lpbk_active_master_eq ) begin
        latched_linkup_lane_flip_ctrl_lpbk <= #TP 0;
    // record lane flip + reversal
    end else if ( smlh_link_up && ~lpbk_state ) begin // lts_state != S_LPBK_ACTIVE to prevent linkup for Loopback master from Configuration state
        latched_linkup_lane_flip_ctrl_lpbk <= #TP int_smlh_lane_flip_ctrl;
    end
end // latched_linkup_lane_flip_ctrl_lpbk_PROC

// latch the lane flip (occured at Detect state) at the entry to S_CFG_LINKWD_START
always @( posedge core_clk or negedge core_rst_n ) begin : latched_et_cfg_lane_flip_ctrl_lpbk_PROC
    if ( ~core_rst_n )
        latched_et_cfg_lane_flip_ctrl_lpbk <= #TP 0;
    else if ( lts_state_d != S_CFG_LINKWD_START && lts_state == S_CFG_LINKWD_START )
        latched_et_cfg_lane_flip_ctrl_lpbk <= #TP int_smlh_lane_flip_ctrl;
end // latched_et_cfg_lane_flip_ctrl_lpbk_PROC

// in Polling.Compliance & >= Gen3 rate & Enter Compliance bit set, use sticky latched latched_linkup_lane_flip_ctrl
// for lane flip/reversal according to base spec
always @( posedge core_clk or negedge sticky_rst_n ) begin : latched_linkup_lane_flip_ctrl_PROC
    if ( ~sticky_rst_n ) begin
        latched_linkup_lane_flip_ctrl <= #TP 0;
    end else if ( smlh_link_up && ~lpbk_state ) begin // exclude Loopback master which has smlh_link_up = 1 in Loopback state for implementation-specific
        latched_linkup_lane_flip_ctrl <= #TP int_smlh_lane_flip_ctrl;
    end
end // latched_linkup_lane_flip_ctrl_PROC

assign eq_pending_clear = (lts_state == S_RCVRY_RCVRCFG) & clear & ~captured_ts_speed_change & (soe_g2);

always @( posedge core_clk or negedge core_rst_n ) begin : latched_flip_ctrl_PROC
    if ( ~core_rst_n )
        latched_flip_ctrl <= #TP 0;
    else if ( lts_state == S_DETECT_QUIET )
        latched_flip_ctrl <= #TP 0;
    else if ( smlh_link_up_rising_edge && ~lpbk_state ) // except the implementation-specific linkup = 1 in Loopback.Active state for loopback master
        latched_flip_ctrl <= #TP int_smlh_lane_flip_ctrl;
end // latched_flip_ctrl_PROC

always@(posedge core_clk or negedge core_rst_n)
begin : IDLE_TO_RLOCK
    if (!core_rst_n)
        idle_to_rlock           <= #TP 0;
    else if ( (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) && (next_lts_state == S_RCVRY_LOCK) && timeout_2ms && !clear ) begin
        if ( g3_rate || g4_rate || g5_rate || (goe_g6))
            idle_to_rlock           <= #TP idle_to_rlock + 1'b1; //plus 1 if gen3
        else
        if ( g2_rate || (g1_rate && lts_state == S_CFG_IDLE)
 || (cfg_gen2_support && (lts_state == S_RCVRY_IDLE) && (g1_rate)) )
            idle_to_rlock           <= #TP 8'hff; //set to ffh if not gen3
    end else if ( ((g3_rate || g4_rate || g5_rate || (goe_g6)) && (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) && next_lts_state == S_L0 && !clear) || //reset to 0 if gen3
                  (lts_state == S_DETECT_QUIET) || (rplh_pkt_start && (lts_state == S_L0)) )
        idle_to_rlock         <= #TP 0;
end

// Determine when to change link speed
reg [2:0] next_data_rate; //extend to 3 bits, 0-gen1, 1-gen2, 2-gen3, 3-gen4, 4-gen5

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        next_data_rate          <= #TP 0;
        precoding_on            <= #TP 0;
        precoding6_on           <= #TP 0;
    end else begin
      if ( (lts_state == S_DETECT_QUIET) || (lts_state == S_PRE_DETECT_QUIET) )      // Speed set to gen1 whenever we enter Detect
        next_data_rate          <= #TP 0;
      else if ( (lts_state == S_L123_SEND_EIDLE) && pm_smlh_entry_to_l2 && latched_rcvd_eidle_set)      // Speed set to gen1 whenever going to L2 before we enter L2.Idle
        next_data_rate          <= #TP 0;

      // Polling.Compliance
      else if ((lts_state == S_POLL_ACTIVE) & (next_lts_state == S_POLL_COMPLIANCE) & !clear)    // speed change at transition from Polling.Active -> Polling.Compliance
        next_data_rate      <= #TP
                                   (cfg_pcie_max_link_speed == `GEN1_LINK_SP) ? 0 :
                                   (ts_to_poll_cmp_pulse) ? ( (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd && link_ts_data_rate == 5'b10111 && link_latched_flitm_support[0]) ||
                                                              (latched_ts_data_rate_eg6[5] && ltssm_ts_data_rate_eg6[5]) ? 3'b101 : // ts_to_poll_cmp_pulse updates at 24ms while latched_ts_data_rate updated long ago
                                                              (latched_ts_data_rate_eg6[4] && ltssm_ts_data_rate_eg6[4]) ? 3'b100 : // ts_to_poll_cmp_pulse updates at 24ms while latched_ts_data_rate updated long ago
                                                              (latched_ts_data_rate_eg6[3] && ltssm_ts_data_rate_eg6[3]) ? 3'b011 : // ts_to_poll_cmp_pulse updates at 24ms while latched_ts_data_rate updated long ago
                                                              (latched_ts_data_rate_eg6[2] && ltssm_ts_data_rate_eg6[2]) ? 3'b010 :
                                                              (latched_ts_data_rate_eg6[1] && ltssm_ts_data_rate_eg6[1]) ? 3'b001 : 3'b000 ) :
                                   (cfg_enter_compliance) ? ((cfg_target_link_speed == `GEN6_LINK_SP) ? 3'b101 :
                                                             (cfg_target_link_speed == `GEN5_LINK_SP) ? 3'b100 :
                                                             (cfg_target_link_speed == `GEN4_LINK_SP) ? 3'b011 :
                                                             (cfg_target_link_speed == `GEN3_LINK_SP) ? 3'b010 :
                                                             (cfg_target_link_speed == `GEN2_LINK_SP) ? 3'b001 :
                                                              3'b000) :
                                                            gen3_speed_cmpl;

      else if (curnt_compliance_state == S_COMPL_EXIT_TX_EIDLE)                           // change back to gen1 when leaving Polling.Compliance
        next_data_rate      <= #TP 0;

      // Loopback
      else if ( ((lts_state == S_LPBK_ENTRY) && ((lpbk_master && last_lts_state == S_CFG_LINKWD_START && slr_g5) || (g5_rate && last_state_is_eq)))                             // Change speed if needed for loopback
             || ((lts_state == S_CFG_LINKWD_START) && (link_latched_live_all_2_ts1_lpbk1_rcvd || (any_2_ts1_lpbk1_ebth1_rcvd_g5)) && ~clear) )
        next_data_rate          <= #TP
                                       captured_lpbk_ts_data_rate_eg6[5] ? ((g5_rate || ~perform_eq_for_loopback_g6_i) ? 3'b101 : 3'b100) :
                                       captured_lpbk_ts_data_rate_eg6[4] ? 3'b100 :
                                       captured_lpbk_ts_data_rate_eg6[3] ? 3'b011 :
                                       captured_lpbk_ts_data_rate_eg6[2] ? 3'b010 :
                                       captured_lpbk_ts_data_rate_eg6[1] ? 3'b001 : 3'b000;

      // Disabled for cfg_pl_gen3_zrxdc_noncompl
      else if ( (lts_state == S_DISABLED_IDLE) && latched_rcvd_eidle_set && ei_interval_expire && latched_eidle_sent && (current_data_rate_d != `GEN1_RATE) && cfg_pl_gen3_zrxdc_noncompl )
        next_data_rate      <= #TP 0;

      // Recovery
      else if (((lts_state_d == S_RCVRY_RCVRCFG) | (lts_state_d == S_RCVRY_LOCK) | (lts_state_d == S_RCVRY_EQ0) |
                (lts_state_d == S_RCVRY_EQ1)     | (lts_state_d == S_RCVRY_EQ2)  | (lts_state_d == S_RCVRY_EQ3)) & (lts_state == S_RCVRY_SPEED)) begin
        next_data_rate      <= #TP
                                   (smlh_successful_spd_negotiation) ? ( gen6_supported ? 3'b101 :   //both sides support gen6
                                                                         gen5_supported ? 3'b100 :   //both sides support gen5
                                                                         gen4_supported ? 3'b011 :   //both sides support gen4
                                                                         gen3_supported ? 3'b010 :   //both sides support gen3
                                                                         gen2_supported ? 3'b001 : 3'b000 ) : //both sides support gen2
                                   (changed_speed_recovery)          ? latched_l0_speed :  //the link speed on entering Recovery.RcvrLock from L0 or L1
                                   // !changed_speed_recovery
                                   ((lts_state_d == S_RCVRY_RCVRCFG) || (lts_state_d == S_RCVRY_LOCK)) ? (slr_g6 ? 3'b000 : 3'b100) : 0;
        if ( lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_SPEED && smlh_successful_spd_negotiation && gen5_supported )
            precoding_on    <= #TP link_pc_rcvd;
        if ( lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_SPEED && smlh_successful_spd_negotiation && gen6_supported )
            precoding6_on   <= #TP link_pc6_rcvd;
      end

//      if ( smlh_link_up_falling_edge ) precoding_on <= #TP 0; // clear to 0 from smlh_link_up_falling_edge
      if ( lts_state == S_DETECT_QUIET ) precoding_on  <= #TP 0; // clear to 0 in Detect state
      if ( lts_state == S_DETECT_QUIET ) precoding6_on <= #TP 0; // clear to 0 in Detect state
    end

reg [2:0] mac_phy_rate1, mac_phy_rate2, mac_phy_rate3, mac_phy_rate4;

always@(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        int_mac_phy_txelecidle_r    <= #TP '1 ;
        int_mac_phy_txelecidle_rr   <= #TP '1 ;
    end
    else begin
        int_mac_phy_txelecidle_r  <= #TP int_mac_phy_txelecidle;
        int_mac_phy_txelecidle_rr <= #TP int_mac_phy_txelecidle_r;
    end
end

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        mac_phy_rate            <= #TP 0;
        mac_phy_rate1           <= #TP 0;
        mac_phy_rate2           <= #TP 0;
        mac_phy_rate3           <= #TP 0;
        mac_phy_rate4           <= #TP 0;
    end
    else begin
      if (  (ltssm_cmd == `XMT_IN_EIDLE) && (&int_mac_phy_txelecidle_r)   // must be in electrical idle to change rate
 && ((cfg_rate_chg_mode) ? 1'h1 : pipe_regif_all_idle)
                && (   (lts_state == S_PRE_DETECT_QUIET && smlh_margin_pipe_idle)
                    || (lts_state == S_LPBK_ENTRY)
                    || ((lts_state == S_DISABLED_IDLE) && latched_rcvd_eidle_set && ei_interval_expire && latched_eidle_sent && (current_data_rate_d != `GEN1_RATE) && cfg_pl_gen3_zrxdc_noncompl)
                    || (latched_eidle_seen &&   (lts_state == S_RCVRY_SPEED) && smlh_margin_pipe_idle)
                    || (curnt_compliance_state == S_COMPL_ENT_SPEED_CHANGE)
                    || (curnt_compliance_state == S_COMPL_EXIT_SPEED_CHANGE) )) begin
        if ( lts_state == S_PRE_DETECT_QUIET ) // prevent mac_phy_rate1 changes without phystatus back when timeout_48ms in S_RCVRY_SPEED to S_PRE_DETECT_QUIET
          mac_phy_rate1          <= #TP 0; // always change to Gen1 rate when in S_PRE_DETECT_QUIET
        else
          mac_phy_rate1          <= #TP next_data_rate;
      end
      mac_phy_rate2          <= #TP mac_phy_rate1;
      mac_phy_rate3          <= #TP mac_phy_rate2;
      mac_phy_rate4          <= #TP (|eiexit_hs_in_progress_physic_lane) ? mac_phy_rate4 : mac_phy_rate3; //must not be in process of rxstandby handshake for ei exit
      mac_phy_rate           <= #TP mac_phy_rate4;
    end

// latch the link speed on entering detect
reg [2:0] latched_detect_speed;   // The speed on entering Detect
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_detect_speed    <= #TP 0;
    end else if ( app_ltssm_enable_fall_edge || ((next_lts_state == S_PRE_DETECT_QUIET) & (lts_state != S_PRE_DETECT_QUIET) & !clear)
             || (!clear & (next_lts_state == S_DETECT_QUIET) & ((lts_state != S_PRE_DETECT_QUIET) && (lts_state != S_DETECT_QUIET))) ) begin
        latched_detect_speed    <= #TP current_data_rate;
    end


reg rate_change_flag;
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        rate_change_flag <= #TP 0;
    else if ( mac_phy_rate2 != mac_phy_rate3 )
        rate_change_flag <= #TP 1;
    else if ( mac_phy_rate2 == current_data_rate )
        rate_change_flag <= #TP 0;

logic [NL-1:0]  int_set_rxstandby_flip;
logic [NL-1:0]  rcvd_eidle_rxstandby;

always @(*) begin : rcvd_eidle_rxstandby_PROC
    integer n;

    rcvd_eidle_rxstandby = act_rmlh_rcvd_eidle_set;

    for ( n=0; n<NL; n=n+1 ) begin
        if(lts_state==S_LPBK_ACTIVE && !lpbk_master && ~g1_rate) begin
          if(g3_rate || g4_rate || g5_rate || goe_g6)
            rcvd_eidle_rxstandby[n] = act_rmlh_gen3_rcvd_4eidle_set[n];
          else
            rcvd_eidle_rxstandby[n] = !clear && !eidle_cnt_clear[n] && (rcvd_eidle_cnt[n*4+:4]==4'h3) && rcvd_valid_eidle_set[n]; // GEN2
        end
    end

end // rcvd_eidle_rxstandby_PROC

assign smlh_set_rxstandby                     = set_rxstandby; // to lane_flip
assign int_laneflip_mac_phy_rxstandby         = laneflip_mac_phy_rxstandby;
assign int_laneflip_set_rxstandby_physic_lane = laneflip_set_rxstandby_physic_lane;
assign int_laneflip_lanes_active_physic_lane  = laneflip_lanes_active_physic_lane;
assign int_set_mac_phy_rxstandby_physic_lane  = int_laneflip_set_rxstandby_physic_lane | set_rxstandby_physic_lane;

reg     [NL-1:0]    eios_subsequent_flag;
reg     [NL-1:0]    eios_l1_l2_flag;
reg     [5:0]       eios_subsequent_timer[0:NL-1];

parameter SUBSEQ_TIMEOUT = 12 / `CX_PL_FREQ_MULTIPLIER;

always @(posedge core_clk or negedge core_rst_n) begin : eios_subsequent_flag_PROC
    integer n;

    if ( !core_rst_n ) begin
        eios_subsequent_flag <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if( rcvd_eidle_rxstandby[n] ) begin
                eios_subsequent_flag[n] <= #TP 1;
            end else if(eios_subsequent_timer[n] >= SUBSEQ_TIMEOUT) begin
                eios_subsequent_flag[n] <= #TP 0;
            end
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eios_subsequent_timer_PROC
    integer n;

    if ( !core_rst_n ) begin
        for ( n=0; n<NL; n=n+1 ) begin
            eios_subsequent_timer[n] <= #TP 0;
        end
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( rcvd_eidle_rxstandby[n] ) begin
                eios_subsequent_timer[n] <= #TP 0;
            end else if ( eios_subsequent_flag[n] ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
                eios_subsequent_timer[n] <= #TP eios_subsequent_timer[n] + (timer2? timer_freq_multiplier : 1'b0);
// spyglass enable_block W164a
            end else begin
                eios_subsequent_timer[n] <= #TP 0;
            end
        end
    end
end

// Once EIOS is received during L1/L2/Disable entry negotiation, the core keeps asserting rxstandby until Recovery State entry or Detect State when cfg_rxstandby_control[3] and [0]=1
always @(posedge core_clk or negedge core_rst_n) begin : eios_l1_l2_flag_PROC
    integer n;

    if ( !core_rst_n ) begin
        eios_l1_l2_flag <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if( (lts_state != S_L123_SEND_EIDLE) && (lts_state != S_L1_IDLE) && (lts_state != S_L2_IDLE) && 
                (lts_state != S_DISABLED_ENTRY) && (lts_state != S_DISABLED_IDLE) && (lts_state != S_DISABLED) ) begin
                eios_l1_l2_flag[n] <= #TP 0;
            end else if( rcvd_eidle_rxstandby[n] ) begin
                eios_l1_l2_flag[n] <= #TP 1;
            end
        end
    end
end

wire [7:0] rxstandby_assertion_enable = cfg_rxstandby_control[7:0];
wire rxstandby_handshake_enable = cfg_rxstandby_control[6];

logic          mac_phy_pam4_restricted_levels_d;
logic          mac_phy_pam4_restricted_levels_rise;
logic [NL-1:0] pam4_restricted_levels_wr_ack_pending_d;
logic [NL-1:0] pam4_restricted_levels_wr_ack_pending_fall;
logic [NL-1:0] latched_pam4_restricted_levels_wr_ack_pending_fall;
logic          pam4_restricted_levels_wr_ack_pending_fall_all;
logic          pam4_restricted_levels_wr_pending;

assign pam4_restricted_levels_wr_ack_pending_fall = ~pam4_restricted_levels_wr_ack_pending & pam4_restricted_levels_wr_ack_pending_d;

always @(posedge core_clk or negedge core_rst_n) begin : pam4_restricted_levels_wr_ack_pending_d_PROC
  if ( !core_rst_n ) begin
    pam4_restricted_levels_wr_ack_pending_d <= #TP {NL{1'b0}};
  end else begin
    pam4_restricted_levels_wr_ack_pending_d <= #TP pam4_restricted_levels_wr_ack_pending;
  end
end

assign pam4_restricted_levels_wr_ack_pending_fall_all = &(~ltssm_lanes_active | latched_pam4_restricted_levels_wr_ack_pending_fall);

always @(posedge core_clk or negedge core_rst_n) begin : latched_pam4_restricted_levels_wr_ack_pending_fall_PROC
  integer ln;
  if ( !core_rst_n ) begin
    latched_pam4_restricted_levels_wr_ack_pending_fall <= #TP {NL{1'b0}};
  end else begin
    for (ln=0; ln<NL; ln=ln+1) begin
      if (!pam4_restricted_levels_wr_pending) begin
        latched_pam4_restricted_levels_wr_ack_pending_fall[ln] <= #TP 1'b0;
      end else if (pam4_restricted_levels_wr_ack_pending_fall[ln]) begin
        latched_pam4_restricted_levels_wr_ack_pending_fall[ln] <= #TP 1'b1;
      end
    end
  end
end

// To enure PAM4RestrictedLevels field is set prior to RxStandby is deasserted.
always @(posedge core_clk or negedge core_rst_n) begin : pam4_restricted_levels_wr_pending_PROC
  if ( !core_rst_n ) begin
    pam4_restricted_levels_wr_pending <= #TP 1'b0;
  end else if (pam4_restricted_levels_wr_ack_pending_fall_all) begin
    pam4_restricted_levels_wr_pending <= #TP 1'b0;
  end else if (mac_phy_pam4_restricted_levels_rise) begin
    pam4_restricted_levels_wr_pending <= #TP 1'b1;
  end
end

logic               clocking_mode_update;
logic               cfg_comm_clk_config_wait_recovery;
//logic  [NL-1:0]     pipe_turnoff_lane;           // Indicates PIPE Turnoff
logic  [NL-1:0]     int_mac_phy_rxstandby_physic_lane;
logic               xmlh_sris_enable_wait_recovery;
logic  [NL-1:0]     init_rxstandby_rcvrylock_lane;        // Set 1 during Rcrvry.Lock entry -> RxTSOS
logic  [NL-1:0]     set_rxstandby_rcvrylock_lane;         // Set 1 during RxTSOS -> RxStandby=1

always_ff @(posedge core_clk or negedge core_rst_n) begin : smlh_keep_rcvrylock_lane_PROC
    integer n;
    if (!core_rst_n) begin
        smlh_keep_rcvrylock_lane <= #TP '0;
        cfg_comm_clk_config_wait_recovery <= #TP '0;
        xmlh_sris_enable_wait_recovery <= #TP 1'b1; // xmlh_sris_enable is 1 by default
        init_rxstandby_rcvrylock_lane <= #TP '0;
    end else begin
        if (!clear && (next_lts_state==S_RCVRY_LOCK) && (lts_state!=S_RCVRY_LOCK) && clocking_mode_update && rxstandby_assertion_enable[7]) begin
            smlh_keep_rcvrylock_lane <= #TP ltssm_lanes_active; // set 1 for all active lanes
            cfg_comm_clk_config_wait_recovery <= #TP cfg_comm_clk_config;
            xmlh_sris_enable_wait_recovery <= #TP xmlh_sris_enable;
            init_rxstandby_rcvrylock_lane <= #TP ltssm_lanes_active; // set 1 for all active lanes
        end else begin
            for ( n=0; n<NL; n=n+1 ) begin
                if (!init_rxstandby_rcvrylock_lane[n] && !set_rxstandby_rcvrylock_lane[n] && !int_laneflip_mac_phy_rxstandby[n]) begin
                    smlh_keep_rcvrylock_lane[n] <= #TP 1'b0;
                end
                if (set_rxstandby_rcvrylock_lane[n]) begin
                    init_rxstandby_rcvrylock_lane[n] <= #TP '0; // set 0 per lane
                end
            end
        end
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : set_rxstandby_rcvrylock_lane_PROC
    integer n;
    if (!core_rst_n) begin
        set_rxstandby_rcvrylock_lane <= #TP '0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if (init_rxstandby_rcvrylock_lane[n] && smlh_ts_rcvd_pulse_bus[n]) begin
                set_rxstandby_rcvrylock_lane[n] <= #TP 1'b1;
            end else if (int_laneflip_mac_phy_rxstandby[n]) begin
                set_rxstandby_rcvrylock_lane[n] <= #TP 1'b0;
            end
        end
    end
end

assign clocking_mode_update = (cfg_comm_clk_config!=cfg_comm_clk_config_wait_recovery)
                           || (xmlh_sris_enable!=xmlh_sris_enable_wait_recovery)
                            ;

always @(*) begin : set_rxstandby_PROC
    integer n;
    set_rxstandby = '0;
    set_rxstandby_physic_lane = '0;
    for ( n=0; n<NL; n=n+1 ) begin
        //---- Logical Lane bit order -----------------------------------
        // set_rxstandby -> lane_flip -> mac_phy_rxstandby
        if ( rxstandby_assertion_enable[0] && (rcvd_eidle_rxstandby[n] || eios_subsequent_flag[n]) ||
             rxstandby_assertion_enable[0] && rxstandby_assertion_enable[3] && eios_l1_l2_flag[n] ||
             set_rxstandby_rcvrylock_lane[n]  // rxstandby_assertion_enable[7] has been considered
        ) begin
            set_rxstandby[n] = 1'b1;
        end
        //---- Physical Lane bit order -----------------------------------------------
        // set_rxstandby_physic_lane -> mac_phy_rxstandby (low latency rather than set_rxstandby)
        if ( rxstandby_assertion_enable[1] && (rate_change_flag || mac_phy_pam4_restricted_levels_rise || pam4_restricted_levels_wr_pending ) ||
             rxstandby_assertion_enable[2] && laneflip_pipe_turnoff_physic_lane[n] ||
             rxstandby_assertion_enable[2] && ( !clear && lts_state == S_CFG_IDLE && next_lts_state != S_CFG_IDLE && !int_laneflip_lanes_active_physic_lane[n] ) ||
             rxstandby_assertion_enable[3] && ( next_ltssm_powerdown == `P1 || next_ltssm_powerdown == `P2 || current_powerdown == `P1 || current_powerdown == `P2 ) ||
             rxstandby_assertion_enable[4] && ( r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE ) ||
             rxstandby_assertion_enable[5] && ( !clear && lts_state == S_L0 && next_lts_state == S_RCVRY_LOCK && latched_eidle_inferred )
        ) begin
            set_rxstandby_physic_lane[n] = 1'b1;
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eiexit_hs_in_progress_physic_lane_PROC
    integer n;

    if ( !core_rst_n ) begin
        eiexit_hs_in_progress_physic_lane <= #TP {NL{1'b0}};
    end else begin
      for ( n=0; n<NL; n=n+1 ) begin
        if ( !cfg_rxstandby_handshake_policy && cfg_rxstandby_control[6] && phy_mac_rxstandbystatus_physic_lane[n] && (!int_mac_phy_rxstandby_physic_lane[n] || !int_set_mac_phy_rxstandby_physic_lane[n] && !phy_mac_rxelecidle_physic_lane[n] ) ) begin
            eiexit_hs_in_progress_physic_lane[n] <= #TP 1'b1;
        end else begin
            eiexit_hs_in_progress_physic_lane[n] <= #TP 1'b0;
        end
      end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : int_mac_phy_rxstandby_physic_lane_PROC
    integer n;

    if ( !core_rst_n ) begin
        int_mac_phy_rxstandby_physic_lane <= #TP {NL{`CX_RXSTANDBY_DEFAULT}};
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( int_set_mac_phy_rxstandby_physic_lane[n] ) begin
                int_mac_phy_rxstandby_physic_lane[n] <= #TP (rxstandby_handshake_enable && phy_mac_rxstandbystatus_physic_lane[n]) ? int_mac_phy_rxstandby_physic_lane[n] : 1'b1;
            end else if ( ~phy_mac_rxelecidle_physic_lane[n] ) begin
                int_mac_phy_rxstandby_physic_lane[n] <= #TP (rxstandby_handshake_enable && !phy_mac_rxstandbystatus_physic_lane[n]) ? int_mac_phy_rxstandby_physic_lane[n] : 0;
            end else begin
                int_mac_phy_rxstandby_physic_lane[n] <= #TP int_mac_phy_rxstandby_physic_lane[n];
            end
        end
    end
end

assign mac_phy_rxstandby = int_mac_phy_rxstandby_physic_lane;

// Gen3 Compliance signal generation
// Compliance variables used to cycle through speed and deemphasis(gen2)/tx_preset(gen3,gen4)/gen4_cmpl_jmp(gen4) settings
// gates: must revisit for Gen5
reg [6:0]cmpl_setting_nos; //compliance sequence of setting number @Gen3 and above.
wire [6:0] max_cmpl_setting_nos = (cfg_pcie_max_link_speed == `GEN6_LINK_SP && ~cfg_flit_mode_dis) ? 7'd84 :
 (cfg_pcie_max_link_speed ==                                   `GEN5_LINK_SP
 || cfg_pcie_max_link_speed == `GEN6_LINK_SP) ? 7'd54 :
 (cfg_pcie_max_link_speed == `GEN4_LINK_SP) ? 7'd34 :
 (cfg_pcie_max_link_speed == `GEN3_LINK_SP) ? 7'd14 : 7'd3;

always @(posedge core_clk or negedge sticky_rst_n) begin : compliance_setting_nos_PROC
    if (!sticky_rst_n) begin // exclude link down reset according to 3.0 spec p255, 6
        cmpl_setting_nos         <= #TP 7'd1;
    // if the Port's Receivers do not meet the ZRX-DC specification for 2.5 GT/s when they are operating at 8.0 GT/s
    end else if ( (lts_state == S_POLL_CONFIG) && (cfg_pl_gen3_zrxdc_noncompl || ltssm_ts_data_rate_eg6[3]) && !clear ) begin
            cmpl_setting_nos         <= #TP 7'd1;
    end else begin 
          if ( (lts_state == S_POLL_COMPLIANCE) && (next_lts_state != S_POLL_COMPLIANCE) && !clear ) begin
            if(cmpl_setting_nos < max_cmpl_setting_nos)
               cmpl_setting_nos         <= #TP cmpl_setting_nos + 7'd1;
            else
               cmpl_setting_nos <= #TP 7'd1;
          end    
    end
end
                                  
always @(posedge core_clk or negedge sticky_rst_n) begin : compliance_speed_tx_preset_PROC
    if (!sticky_rst_n) begin // exclude link down reset according to 3.0 spec p255, 6
        gen3_speed_cmpl          <= #TP 3'b000;
        gen3_cmpl_tx_preset      <= #TP 4'b0001;
        gen4_cmpl_jmp            <= #TP 4'b0000;
        gen6_cmpl_tp             <= #TP 4'b0000;
    end else begin 
              if(cmpl_setting_nos == 7'd2)begin
                   gen3_speed_cmpl     <= #TP 3'b001;
              end else if(cmpl_setting_nos == 7'd3)begin
                   gen3_speed_cmpl     <= #TP 3'b001;
              end else if(cmpl_setting_nos >= 7'd4 && cmpl_setting_nos <= 7'd14)begin
                   gen3_speed_cmpl     <= #TP 3'b010;
              end else if(cmpl_setting_nos >= 7'd15 && cmpl_setting_nos <= 7'd34)begin
                   gen3_speed_cmpl     <= #TP 3'b011;
              end else if(cmpl_setting_nos >= 7'd35 && cmpl_setting_nos <= 7'd54)begin
                   gen3_speed_cmpl     <= #TP 3'b100;
              end else if(cmpl_setting_nos >= 7'd55 && cmpl_setting_nos <= 7'd84)begin
                   gen3_speed_cmpl     <= #TP 3'b101;
              end else begin // cmpl_setting_nos == 7'd1
                   gen3_speed_cmpl     <= #TP 3'b000; 
              end              

              case(cmpl_setting_nos)
                   7'd1,7'd2: gen3_cmpl_tx_preset <= #TP 4'd1;
                   7'd3,7'd4: gen3_cmpl_tx_preset <= #TP 4'd0;
                   7'd5     : gen3_cmpl_tx_preset <= #TP 4'd1;
                   7'd6     : gen3_cmpl_tx_preset <= #TP 4'd2;
                   7'd7     : gen3_cmpl_tx_preset <= #TP 4'd3;
                   7'd8     : gen3_cmpl_tx_preset <= #TP 4'd4;
                   7'd9     : gen3_cmpl_tx_preset <= #TP 4'd5;
                   7'd10    : gen3_cmpl_tx_preset <= #TP 4'd6;
                   7'd11    : gen3_cmpl_tx_preset <= #TP 4'd7;
                   7'd12    : gen3_cmpl_tx_preset <= #TP 4'd8;
                   7'd13    : gen3_cmpl_tx_preset <= #TP 4'd9;
                   7'd14    : gen3_cmpl_tx_preset <= #TP 4'd10;
                   7'd15    : gen3_cmpl_tx_preset <= #TP 4'd0;
                   7'd16    : gen3_cmpl_tx_preset <= #TP 4'd1;
                   7'd17    : gen3_cmpl_tx_preset <= #TP 4'd2;
                   7'd18    : gen3_cmpl_tx_preset <= #TP 4'd3;
                   7'd19    : gen3_cmpl_tx_preset <= #TP 4'd4;
                   7'd20    : gen3_cmpl_tx_preset <= #TP 4'd5;
                   7'd21    : gen3_cmpl_tx_preset <= #TP 4'd6;
                   7'd22    : gen3_cmpl_tx_preset <= #TP 4'd7;
                   7'd23    : gen3_cmpl_tx_preset <= #TP 4'd8;
                   7'd24    : gen3_cmpl_tx_preset <= #TP 4'd9;
                   7'd25    : gen3_cmpl_tx_preset <= #TP 4'd10;
                   7'd35    : gen3_cmpl_tx_preset <= #TP 4'd0;
                   7'd36    : gen3_cmpl_tx_preset <= #TP 4'd1;
                   7'd37    : gen3_cmpl_tx_preset <= #TP 4'd2;
                   7'd38    : gen3_cmpl_tx_preset <= #TP 4'd3;
                   7'd39    : gen3_cmpl_tx_preset <= #TP 4'd4;
                   7'd40    : gen3_cmpl_tx_preset <= #TP 4'd5;
                   7'd41    : gen3_cmpl_tx_preset <= #TP 4'd6;
                   7'd42    : gen3_cmpl_tx_preset <= #TP 4'd7;
                   7'd43    : gen3_cmpl_tx_preset <= #TP 4'd8;
                   7'd44    : gen3_cmpl_tx_preset <= #TP 4'd9;
                   7'd45    : gen3_cmpl_tx_preset <= #TP 4'd10;
                   7'd55    : gen3_cmpl_tx_preset <= #TP 4'd0;
                   7'd56    : gen3_cmpl_tx_preset <= #TP 4'd1;
                   7'd57    : gen3_cmpl_tx_preset <= #TP 4'd2;
                   7'd58    : gen3_cmpl_tx_preset <= #TP 4'd3;
                   7'd59    : gen3_cmpl_tx_preset <= #TP 4'd4;
                   7'd60    : gen3_cmpl_tx_preset <= #TP 4'd5;
                   7'd61    : gen3_cmpl_tx_preset <= #TP 4'd6;
                   7'd62    : gen3_cmpl_tx_preset <= #TP 4'd7;
                   7'd63    : gen3_cmpl_tx_preset <= #TP 4'd8;
                   7'd64    : gen3_cmpl_tx_preset <= #TP 4'd9;
                   7'd65    : gen3_cmpl_tx_preset <= #TP 4'd10;
                   default  :begin
                             if(cmpl_setting_nos>= 7'd66)
                                  gen3_cmpl_tx_preset <= #TP 4'd0;   //setting #66-84
                             else 
                                  gen3_cmpl_tx_preset <= #TP 4'd4;   //setting #26-34, #46-54 
                            end
              endcase    

              case(cmpl_setting_nos)
                   7'd26    : gen4_cmpl_jmp <= #TP 4'd1;
                   7'd27    : gen4_cmpl_jmp <= #TP 4'd2;
                   7'd28    : gen4_cmpl_jmp <= #TP 4'd3;
                   7'd29    : gen4_cmpl_jmp <= #TP 4'd4;
                   7'd30    : gen4_cmpl_jmp <= #TP 4'd5;
                   7'd31    : gen4_cmpl_jmp <= #TP 4'd6;
                   7'd32    : gen4_cmpl_jmp <= #TP 4'd7;
                   7'd33    : gen4_cmpl_jmp <= #TP 4'd8;
                   7'd34    : gen4_cmpl_jmp <= #TP 4'd9;
                   7'd46    : gen4_cmpl_jmp <= #TP 4'd1;
                   7'd47    : gen4_cmpl_jmp <= #TP 4'd2;
                   7'd48    : gen4_cmpl_jmp <= #TP 4'd3;
                   7'd49    : gen4_cmpl_jmp <= #TP 4'd4;
                   7'd50    : gen4_cmpl_jmp <= #TP 4'd5;
                   7'd51    : gen4_cmpl_jmp <= #TP 4'd6;
                   7'd52    : gen4_cmpl_jmp <= #TP 4'd7;
                   7'd53    : gen4_cmpl_jmp <= #TP 4'd8;
                   7'd54    : gen4_cmpl_jmp <= #TP 4'd9;
                   7'd66    : gen4_cmpl_jmp <= #TP 4'd1;
                   7'd67    : gen4_cmpl_jmp <= #TP 4'd2;
                   7'd68    : gen4_cmpl_jmp <= #TP 4'd3;
                   7'd69    : gen4_cmpl_jmp <= #TP 4'd4;
                   7'd70    : gen4_cmpl_jmp <= #TP 4'd5;
                   7'd71    : gen4_cmpl_jmp <= #TP 4'd6;
                   7'd72    : gen4_cmpl_jmp <= #TP 4'd7;
                   7'd73    : gen4_cmpl_jmp <= #TP 4'd8;
                   7'd74    : gen4_cmpl_jmp <= #TP 4'd9;
                   default : gen4_cmpl_jmp <= #TP 4'd0;    //setting #1-25, #35-45, #55-65
              endcase

              case(cmpl_setting_nos)
                   7'd75    : gen6_cmpl_tp <= #TP 4'd1;
                   7'd76    : gen6_cmpl_tp <= #TP 4'd2;
                   7'd77    : gen6_cmpl_tp <= #TP 4'd3;
                   7'd78    : gen6_cmpl_tp <= #TP 4'd4;
                   7'd79    : gen6_cmpl_tp <= #TP 4'd5;
                   7'd80    : gen6_cmpl_tp <= #TP 4'd6;
                   7'd81    : gen6_cmpl_tp <= #TP 4'd7;
                   7'd82    : gen6_cmpl_tp <= #TP 4'd8;
                   7'd83    : gen6_cmpl_tp <= #TP 4'd9;
                   7'd84    : gen6_cmpl_tp <= #TP 4'd10;
                   default  : gen6_cmpl_tp <= #TP 4'd0;
              endcase
    end
end

assign cycle_gen3_compliance_tx_preset = gen3_cmpl_tx_preset;
assign gen2_deemphasis = gen3_cmpl_tx_preset[0]; //gen2_deemphasis only applied in Gen2 data rate (first 3 cycles of gen3_cmpl_tx_preset)
//use Compliance De-emphasis from Link Control 2 reg if Enter Compliance bit is set in Link Control 2 reg
assign ltssm_gen3_compliance_tx_pset = cfg_enter_compliance ? cfg_compliance_de_emphasis : cycle_gen3_compliance_tx_preset;
assign ltssm_gen4_compliance_jmp = gen4_cmpl_jmp;
assign ltssm_gen6_compliance_tp = gen6_cmpl_tp;
assign ltssm_compliance_set_num = {1'b0, cmpl_setting_nos};

//use tx preset from ltssm if enter Compliance not due to rcvd 8 TS1s
reg latched_enter_compliance_8ts1;
always @(posedge core_clk or negedge core_rst_n) begin : latched_enter_compliance_8ts1_PROC
    if (!core_rst_n) begin
        latched_enter_compliance_8ts1 <= #TP 0;
    end else begin
        if ( int_rcvd_8expect_ts1 && (lts_state == S_POLL_ACTIVE) && (next_lts_state == S_POLL_COMPLIANCE) && !clear )
            latched_enter_compliance_8ts1 <= #TP 1;
        else if ( lts_state != S_POLL_COMPLIANCE )
            latched_enter_compliance_8ts1 <= #TP 0;
    end
end

assign ltssm_gen3_compliance_tx_pset_v = !latched_enter_compliance_8ts1 & (lts_state == S_POLL_COMPLIANCE);

wire                retrain_pulse;
wire                retrain_complete;               // Indicates that the link finished retraining
reg                 latched_link_retrain;
reg                 latched_rec_cfg_to_l0;

wire                perform_link_retrain;

always @(posedge core_clk or negedge core_rst_n) begin : latched_link_retrain_bit_PROC
    if ( ~core_rst_n ) begin
        latched_link_retrain_bit <= #TP 0;
        latched_target_link_speed <= #TP 0;
        latched_perform_eq        <= #TP 0;
    end else if (perform_link_retrain) begin // a pulse to clear latched_link_retrain_bit and latched_perform_eq at the transition from (L0 || L1_IDLE) -> S_RCVRY_LOCK after cfg_link_retrain setting
        latched_link_retrain_bit  <= #TP 1'b0;
        latched_target_link_speed <= #TP latched_target_link_speed;
        latched_perform_eq        <= #TP 1'b0;
    end else if (!latched_link_retrain_bit && retrain_pulse) begin     // capture Retrain Link / Target Link Speed / Perform Equalization at the rising edge of cfg_link_retrain
        latched_link_retrain_bit  <= #TP 1'b1;
        latched_target_link_speed <= #TP cfg_target_link_speed;
        latched_perform_eq        <= #TP cfg_perform_eq;
    end else begin                        // hold current value
        latched_link_retrain_bit  <= #TP latched_link_retrain_bit;
        latched_target_link_speed <= #TP !latched_link_retrain_bit ? cfg_target_link_speed : latched_target_link_speed; // allow to update latched_target_link_speed to cfg_target_link_speed if (~latched_link_retrain_bit || USP)
        latched_perform_eq        <= #TP latched_perform_eq;
    end
end //latched_link_retrain_bit_PROC

// after link_retrain bit has been set and LTSSM moves from (L0 || L1_IDLE) -> S_RCVRY_LOCK, generate a pulse
assign perform_link_retrain = latched_link_retrain_bit && (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)) && !clear && ~cfg_upstream_port; // adding "&& ~cfg_upstream_port" for CC


reg  ltssm_core_rst_n_release;
reg  ltssm_core_rst_n_release_d;
always @(posedge core_clk or negedge core_rst_n) begin : ltssm_core_rst_n_release_PROC
    if ( ~core_rst_n ) begin
        ltssm_core_rst_n_release   <= #TP 0;
        ltssm_core_rst_n_release_d <= #TP 0;
    end else begin
        ltssm_core_rst_n_release   <= #TP 1;
        ltssm_core_rst_n_release_d <= #TP ltssm_core_rst_n_release;
    end
end //ltssm_core_rst_n_release_PROC

//ltssm_core_rst_n_release_pulse is to assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change in core_rst_n.
assign ltssm_core_rst_n_release_pulse = (ltssm_core_rst_n_release & ~ltssm_core_rst_n_release_d);

reg  directed_speed_change_d, clear_d;
always @(posedge core_clk or negedge core_rst_n) begin : directed_speed_change_d_PROC
    if ( ~core_rst_n ) begin
        directed_speed_change_d <= #TP 0;
        clear_d                 <= #TP 0;
    end else begin
        directed_speed_change_d <= #TP directed_speed_change;
        clear_d                 <= #TP clear;
    end
end //directed_speed_change_d_PROC

//ltssm_dir_spd_chg_rising_edge is used to clear cfg_directed_speed_change when a speed change has been initiated.
//if both sides common support rate is only gen1 in current gen1 rate, no speed change, must clear cfg_directed_speed_change when entry to L0.
//Otherwise, cfg_directed_speed_change may cause L1.2 low power waking up immediately after power gating and a DBI reading because of rising edge detection in PM block.
//(~ltssm_ts_data_rate[1] | ~latched_ts_data_rate_ever[1]) means the common support rate is only gen1 when entry to L0 state.
//use clear_d because ltssm_ts_data_rate may update in L0 starting from the 2nd clock even if cfg_target_link_speed set to >Gen1 in the previous state (e.g. from L0S state).
assign ltssm_dir_spd_chg_rising_edge = (directed_speed_change & ~directed_speed_change_d) | ((~ltssm_ts_data_rate[1] || ~latched_ts_data_rate_ever[1]) && g1_rate && lts_state == S_L0 && clear_d);


always@(posedge core_clk or negedge core_rst_n)
begin : SELECT_DEEMPHASIS
    if (!core_rst_n)
        select_deemphasis       <= #TP 1'b1;
    else if (clear) // hold current value during clear
        select_deemphasis       <= #TP select_deemphasis;
    // Detect
    else if (lts_state == S_DETECT_QUIET)
        select_deemphasis       <= #TP cfg_sel_de_emphasis;
    // Compliance
    else if ( (lts_state == S_POLL_ACTIVE) && (next_lts_state == S_POLL_COMPLIANCE) && !clear ) // The next state is Polling.Compliance
      select_deemphasis   <= #TP //CX_7003_DEEMPH_OVERRIDE
                                   (!(cfg_gen2_support | (cfg_pcie_max_link_speed == `GEN3_LINK_SP)))    ? 1'b1 :
                                   (ts_to_poll_cmp_pulse) ? (latched_ts_deemphasis_var | link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd) : // at timeout_24ms in S_POLL_ACTIVE
                                   (cfg_enter_compliance) ? cfg_compliance_de_emphasis[0] : gen2_deemphasis;
      else if ( (lts_state != S_RCVRY_RCVRCFG) && (next_lts_state == S_RCVRY_RCVRCFG) && !clear && !cfg_upstream_port && (cfg_select_deemph_var_mux) )
        select_deemphasis       <= #TP cfg_sel_de_emphasis; // if cfg_select_deemph_var_mux = 1, select_deemphasis variable = the Selectable De-emphasis field in the Link Control 2 register. Else, = value requested by USP on the next line logic
    // Recovery, if ~any_8_ts_linknmtx_lanenmtx_rcvd, keep select_deemphasis
    else if ( ((lts_state != S_RCVRY_RCVRCFG) && (next_lts_state == S_RCVRY_RCVRCFG) && !clear && !cfg_upstream_port && any_8_ts_linknmtx_lanenmtx_rcvd) || // on entry to Recovery.RcvrCfg for DSP
      ((lts_state == S_RCVRY_RCVRCFG) && (next_lts_state == S_RCVRY_SPEED) && !clear && (any_8_ts_linknmtx_lanenmtx_rcvd) && cfg_upstream_port) ) // USP records de-emphasis bit in Recovery.RcvrCfg
      select_deemphasis       <= #TP latched_ts_deemphasis_var | link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd;
    // Loopback
    else if ( (lts_state == S_LPBK_ENTRY) && lpbk_master && (last_lts_state == S_CFG_LINKWD_START) && (~g2_rate) ) // no update if it is Gen2 rate
      select_deemphasis       <= #TP cfg_sel_de_emphasis;
      else if ( (lts_state == S_CFG_LINKWD_START) && (link_latched_live_all_2_ts1_lpbk1_rcvd) && ~clear & !lpbk_master && (~g2_rate) ) //Errata A13, no update if it is Gen2 rate
      select_deemphasis       <= #TP captured_lpbk_ts_auto_change;
    else
        select_deemphasis       <= #TP select_deemphasis;
end

// latch the link speed on entering Recovery.RcvrLock from L0 or L1
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_l0_speed        <= #TP 0;
    else if (((lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)) & (next_lts_state == S_RCVRY_LOCK) & !clear)
        latched_l0_speed        <= #TP mac_phy_rate;

// successful_speed_negotiation LTSSM Variable
always@(posedge core_clk or negedge core_rst_n)
begin : successful_speed_negotiation_PROC
    if (!core_rst_n) begin
        smlh_successful_spd_negotiation         <= #TP 1'b0;
        eq_to_rspeed_g5                         <= #TP 1'b0;
        eq_to_rspeed_g4                         <= #TP 1'b0;
    end else if ((lts_state != S_RCVRY_LOCK) & (next_lts_state == S_RCVRY_LOCK) & !clear) begin    // reset on entry to Recovery.RcvrLock
        smlh_successful_spd_negotiation         <= #TP 1'b0;
        eq_to_rspeed_g5                         <= #TP 1'b0;
        eq_to_rspeed_g4                         <= #TP 1'b0;
    end else if ((lts_state == S_RCVRY_RCVRCFG) & (next_lts_state == S_RCVRY_SPEED) & !clear & link_latched_live_any_ts2_rcvd ) begin       // Switch to Gen2 speed
        smlh_successful_spd_negotiation         <= #TP 1'b1;
        eq_to_rspeed_g5                         <= #TP 1'b0;
        eq_to_rspeed_g4                         <= #TP 1'b0;
    end else if (((lts_state == S_RCVRY_EQ0) || (lts_state == S_RCVRY_EQ1) || (lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_EQ3)) && (next_lts_state == S_RCVRY_SPEED) && !clear) begin
        smlh_successful_spd_negotiation         <= #TP 1'b0; // Reset if any of Recovery.Equalization Phases timeout to Recovery.Speed
// base spec Gen5 r0.71 changed, commented out on 16July2018
//        eq_to_rspeed_g5                         <= #TP (current_data_rate == `GEN5_RATE & skip_eq & bypass_g4_eq); // at gen5 rate but gen4 EQ has not been done, need goto gen4 rate for EQ after failing gen5 eq
        eq_to_rspeed_g5                         <= #TP (goe_g5 & skip_eq); // at gen5 rate but gen4 EQ has not been done, need goto gen4 rate for EQ after failing gen5 eq
//        eq_to_rspeed_g4                         <= #TP (current_data_rate == `GEN4_RATE & skip_eq & bypass_g3_eq); // at gen4 rate but gen3 EQ has not been done, need goto gen3 rate for EQ after failing gen4 eq
    end
    else if ( lts_state == S_RCVRY_SPEED && next_lts_state != S_RCVRY_SPEED && ~clear ) begin
        eq_to_rspeed_g5                         <= #TP 1'b0;
        eq_to_rspeed_g4                         <= #TP 1'b0;
    end
end


wire [3:0]  target_link_speed_real;
//
// auto_eq: the initial reaching gen3/4/5 rate and perform eq autonomously before DLLP/TLP transmission (rdlh_link_up = 0)
//          equalization_done_8/16/32gt_data_rate = 0
// soft_eq: the first time to reach gen3/4/5 rate by setting cfg_perform_eq + cfg_link_retrain after DLLP/TLP transmission (rdlh_link_up = 1)
//          equalization_done_8/16/32gt_data_rate = 0
// redo_eq: the gen3/4/5 eq have been touched but need to re-do eq by setting cfg_perform_eq + cfg_link_retrain. It can be from any data rates to a traget speed
//          equalization_done_8/16/32gt_data_rate = 1
// rqst_eq: the request eq means the eq has been performed at a data rate but the preset/coefficients mismatch in Recovery.RcvrLock state following the EQ phases. This requires DSP to trigger an eq. This feature can be disabled by Port Logic Register bits
//          equalization_done_8/16/32gt_data_rate = 1 at that data rate
// skip_eq: the eq bypass means (~equalization_done_32gt_data_rate & skip_eq & latched_target_link_speed>=`GEN5_LINK_SP) & (soft_gen4_eq_phase_flag || auto_eq_phase_flag)
//          equalization_done_32gt_data_rate = 0 & skip_eq
//
// target_link_speed_real only for auto_eq/soft_eq. The redo_eq is treated in signal redo_eq_phase_flag/redo_eq_target_link_speed. The rqst_eq is keeping the current_data_rate unchange
// soft_eq_phase_flag: no equalization_done_32gt_data_rate condition but including ~equalization_done_16gt_data_rate
// soft_gen4_eq_phase_flag: ~equalization_done_32gt_data_rate
assign  target_link_speed_real = ( cfg_upstream_port || cfg_gen3_eq_disable ) ? latched_target_link_speed :                                                           // USP or ~gen3_eq, use latched_target_link_speed directly
                                 ( ((next_lts_state == S_RCVRY_LOCK) && (lts_state != S_RCVRY_LOCK) && !clear) || ((last_lts_state == S_RCVRY_EQ1 || last_lts_state == S_RCVRY_EQ3) && (lts_state == S_RCVRY_LOCK) && clear) ) ? // for S_RCVRY_LOCK state
                                                                                         // soft_gen5_eq_phase_flag here is because gen6 eq must be from gen5 rate
                                                     ( (skip_eq & (auto_eq_phase_flag || soft_gen5_eq_phase_flag || soft_gen4_eq_phase_flag) & ~equalization_done_32gt_data_rate &               // auto or soft eq bypass &&
                                                        latched_target_link_speed>=`GEN5_LINK_SP                                                                      // to gen5 rate regardless of current data rate. for gen6 eq bypass, first do gen5 eq
                                                       )                                                      ? `GEN5_LINK_SP :                                       // advertise gen5 rate
                                                       (skip_eq & (auto_eq_phase_flag || soft_gen5_eq_phase_flag) & ~equalization_done_64gt_data_rate &               // auto or soft eq bypass &&
                                                        latched_target_link_speed>=`GEN6_LINK_SP                                                                      // to gen6 rate regardless of current data rate
                                                       )                                                      ? `GEN6_LINK_SP :                                       // advertise gen6 rate
                                                       (auto_eq_phase_flag && !equalization_done_8gt_data_rate ||                                                           // auto gen3 eq from gen1/2, advertise gen3 rate
                                                        soft_eq_phase_flag && !equalization_done_8gt_data_rate && (latched_target_link_speed>=`GEN3_LINK_SP) ||             // soft gen3 eq from gen1/2, advertise gen3 rate
                                                        soft_eq_phase_flag &&  equalization_done_8gt_data_rate && (latched_target_link_speed>=`GEN4_LINK_SP) &&             // (gen3 eq done) &&
                                                        ~equalization_done_16gt_data_rate && (current_data_rate <= `GEN2_RATE)                                              // ((soft gen4 eq) && (from gen1/2 rate))
                                                       )                                                      ? `GEN3_LINK_SP :                                             // advertise Gen3 rate. if current_data_rate == Gen3, use latched_target_link_speed which may be ~gen4_rate
                                                       (auto_eq_phase_flag && !equalization_done_16gt_data_rate && (latched_target_link_speed>=`GEN4_LINK_SP) ||      // auto gen4 eq
                                                        soft_eq_phase_flag && !equalization_done_16gt_data_rate && (latched_target_link_speed>=`GEN4_LINK_SP)         // soft gen4 eq
                                                       )                                                      ? `GEN4_LINK_SP :                                       // advertise Gen4 rate. if current_data_rate == Gen4, use latched_target_link_speed which may be ~gen5_rate
                                                       (soft_gen4_eq_phase_flag & equalization_done_16gt_data_rate & (latched_target_link_speed>=`GEN5_LINK_SP) &&          // (gen4 eq done) && to gen5 rate
                                                        ~equalization_done_32gt_data_rate && (current_data_rate <= `GEN3_RATE)                                              // ((soft gen5 eq) && (from gen1/2/3 rate))
                                                       )                                                      ? `GEN4_LINK_SP :                                             // advertise Gen4 rate. if current_data_rate == Gen4, use latched_target_link_speed which may be ~gen5_rate
                                                       (auto_eq_phase_flag && !equalization_done_32gt_data_rate && (latched_target_link_speed>=`GEN5_LINK_SP) ||      // auto gen5 eq
                                                        soft_gen4_eq_phase_flag && !equalization_done_32gt_data_rate && (latched_target_link_speed>=`GEN5_LINK_SP)    // soft gen5 eq
                                                       )                                                      ? `GEN5_LINK_SP :                                       // advertise Gen5 rate. if current_data_rate == Gen5, use latched_target_link_speed which may be ~gen5_rate
                                                       (soft_gen5_eq_phase_flag & equalization_done_32gt_data_rate & (latched_target_link_speed>=`GEN6_LINK_SP) &&          // (gen5 eq done) && to gen6 rate
                                                        ~equalization_done_64gt_data_rate && (current_data_rate <= `GEN4_RATE)                                              // ((soft gen6 eq) && (from gen1/2/3/4 rate))
                                                       )                                                      ? `GEN5_LINK_SP :                                             // advertise Gen5 rate. if current_data_rate == Gen4, use latched_target_link_speed which may be ~gen6_rate
                                                        redo_eq_phase_flag                                    ? redo_eq_target_link_speed : latched_target_link_speed // advertise redo_eq rate, else advertise the target_link_speed
                                                     ) :
                                                        latched_target_link_speed;                                                                                          // advertise data rate not for S_RCVRY_LOCK state

wire [3:0]  current_link_speed ;
assign current_link_speed = (g1_rate) ? `GEN1_LINK_SP :
                            (g2_rate) ? `GEN2_LINK_SP :
                            (g3_rate) ? `GEN3_LINK_SP :
                            (g6_rate) ? `GEN6_LINK_SP :
                            (g4_rate) ? `GEN4_LINK_SP : `GEN5_LINK_SP ;

always@(posedge core_clk or negedge core_rst_n)
begin : DIRECTED_SPEED_CHANGE
    if (!core_rst_n)
        directed_speed_change   <= #TP 1'b0;
    else if ( ((lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)) && (next_lts_state == S_RCVRY_LOCK) && !clear
              && ( ( redo_eq_phase_g3 && redo_eq_phase_step[1] && (g3_rate) ) ||
                   ( redo_eq_phase_g5 && redo_eq_phase_step[1] && (g5_rate) ) ||
                   ( redo_eq_phase_g6 && redo_eq_phase_step[1] && (g6_rate) ) ||
                   ( redo_eq_phase_g4 && redo_eq_phase_step[1] && (g4_rate) ) ) )
        directed_speed_change   <= #TP 1'b0;
    else if (  (  ((lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)) && (next_lts_state == S_RCVRY_LOCK) && !clear
                  && (go_recovery_speed_change //if directed by higher layer
                      || ( latched_ts_data_rate_ever[1]
                           & ( target_link_speed_real != current_link_speed )
                           & latched_link_retrain_bit & !cfg_upstream_port ) //if retrain link
                      || redo_eq_phase_step[0]  // perform eq step1
                      || ( redo_eq_phase_step[1] && (current_data_rate != redo_eq_target_rate) )  // perform eq step2 with speed change
                      || init_eq_pending_g4 && (g3_rate || (slr_g3 && skip_eq && cfg_directed_speed_change)) // Autonomous Eq for gen4 (DSP only)
                      || latched_remote_soft_eq_g4  // hard4d
                      || init_eq_pending_g5 && (g4_rate || (slr_g4 && skip_eq && cfg_directed_speed_change)) // Autonomous Eq for gen5 (DSP only)
                      || latched_remote_soft_eq_g5  // hard5d
                      || init_eq_pending_g6 && (g5_rate || (soe_g5 && skip_eq && cfg_directed_speed_change)) // Autonomous Eq for gen6 (DSP only)
                      || latched_remote_soft_eq_g6  // hard6d
                     )
               )
               ||  ((lts_state == S_RCVRY_LOCK) && link_any_8_ts1_spd_chg_1_rcvd && ~clear))  // if received 8 consecutive ts1 with speed change bit = 1
        directed_speed_change   <= #TP 1'b1;
    else if ( (lts_state == S_RCVRY_SPEED && next_lts_state != S_RCVRY_SPEED && !clear) || (lts_state == S_DETECT_QUIET) ||
              ((lts_state == S_RCVRY_LOCK) && (next_lts_state == S_CFG_LINKWD_START) && !clear) || //Errata A4
              (!clear && (lts_state == S_RCVRY_RCVRCFG) && ((next_lts_state == S_RCVRY_IDLE) || (next_lts_state == S_CFG_LINKWD_START))) ) //Errata A5
        directed_speed_change   <= #TP 1'b0;
    else
        directed_speed_change   <= #TP directed_speed_change;
end

assign ltssm_directed_speed_change = directed_speed_change;

//used to clear ts_speed_change signal in smlh_seq_finder_slv.v
always @( lts_state or next_lts_state or last_lts_state or clear) begin : ts_spd_chg_rcvd_clr_PROC
    ltssm_ts_spd_chg_rcvd_clr_int = 1'b0;

    if ( (lts_state == S_RCVRY_SPEED && next_lts_state != S_RCVRY_SPEED && !clear) || (lts_state == S_DETECT_QUIET) || //clear in the end of RCVRY_SPEED or DETECT_QUIET
         (last_lts_state == S_RCVRY_LOCK && lts_state == S_CFG_LINKWD_START && next_lts_state != S_CFG_LINKWD_START && !clear) || //clear in the end of S_CFG_LINKWD_START
         ((last_lts_state == S_RCVRY_RCVRCFG) && ((lts_state == S_RCVRY_IDLE && next_lts_state != S_RCVRY_IDLE && !clear) ||
         (lts_state == S_CFG_LINKWD_START && next_lts_state != S_CFG_LINKWD_START && !clear))) ) //clear in the end of S_CFG_LINKWD_START or S_RCVRY_IDLE
        ltssm_ts_spd_chg_rcvd_clr_int = 1'b1;
    else
        ltssm_ts_spd_chg_rcvd_clr_int = 1'b0;
end

always@(posedge core_clk or negedge core_rst_n)
begin : latch_ltssm_ts_spd_chg_rcvd_clr
  if (!core_rst_n)
    ltssm_ts_spd_chg_rcvd_clr <= #TP '0;
  else
    ltssm_ts_spd_chg_rcvd_clr <= #TP ltssm_ts_spd_chg_rcvd_clr_int;
end

always@(posedge core_clk or negedge core_rst_n)
begin : DIRECTED_SPEED_CHANGE_R
    if (!core_rst_n)
        directed_speed_change_r   <= #TP 1'b0;
    else if ( lts_state == S_RCVRY_LOCK & ((lts_state_d == S_L0) || (lts_state_d == S_L1_IDLE) || (lts_state_d == S_L0S)) & cfg_directed_speed_change & directed_speed_change )
        directed_speed_change_r   <= #TP 1'b1;
    else if ( (lts_state == S_RCVRY_SPEED && next_lts_state != S_RCVRY_SPEED && !clear) || (lts_state == S_PRE_DETECT_QUIET && next_lts_state != S_PRE_DETECT_QUIET && !clear) ||
              (lts_state == S_CFG_LINKWD_START && next_lts_state != S_CFG_LINKWD_START && !clear) || (lts_state == S_RCVRY_IDLE && next_lts_state != S_RCVRY_IDLE && !clear) )
        directed_speed_change_r   <= #TP 1'b0;
end

// the changed_speed_recovery variable
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        changed_speed_recovery  <= #TP 1'b0;
    else if (clear)
        changed_speed_recovery  <= #TP changed_speed_recovery;
    else if (((lts_state == S_CFG_COMPLETE) & (next_lts_state == S_CFG_IDLE) & !clear)
             |(((lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)) & (next_lts_state == S_RCVRY_LOCK) & !clear)
             |((lts_state == S_RCVRY_RCVRCFG) & ((next_lts_state == S_RCVRY_IDLE) | (next_lts_state == S_CFG_LINKWD_START)) & !clear)
             |((lts_state == S_RCVRY_SPEED) & (next_lts_state == S_RCVRY_LOCK) & changed_speed_recovery & !clear))
        changed_speed_recovery  <= #TP 1'b0;
    else if ((last_lts_state == S_RCVRY_RCVRCFG) & (lts_state == S_RCVRY_SPEED) & (next_lts_state == S_RCVRY_LOCK) & smlh_successful_spd_negotiation & !clear)
        changed_speed_recovery  <= #TP 1'b1;


// logic for the speed change bit of the data rate identifier field for TS ordered sets
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ltssm_ts_speed_change   <= #TP 1'b0;
    else if ( (next_lts_state == S_RCVRY_LOCK) || (next_lts_state == S_RCVRY_RCVRCFG) || (next_lts_state == S_RCVRY_SPEED) )
        ltssm_ts_speed_change   <= #TP directed_speed_change;
    else if (    ((lts_state != S_RCVRY_LOCK) && (lts_state != S_RCVRY_RCVRCFG) && (lts_state != S_RCVRY_SPEED) && (lts_state != S_RCVRY_IDLE))
              || ((lts_state_d == S_RCVRY_SPEED) && (lts_state != S_RCVRY_SPEED)) )     // Clear when exiting Recovery.Speed. For avoiding sending TS1 with this filed=1 in Recovery.Speed -> Recovery.RcvrLock -> Recovery.EQ transition in 16s
        ltssm_ts_speed_change   <= #TP 1'b0;


//Do not clear the ltssm_ts_auto_change in lts_state_d == S_CFG_COMPLETE. delay one cycle to S_CFG_COMPLETE so that the controller sends upconfigure in its last TX TS2 in S_CFG_IDLE.
//it is safe to do so because no TS send command in S_CFG_IDLE which follows S_CFG_COMPLETE.
//Do not clear the ltssm_ts_auto_change in S_RCVRY_IDLE with no_idle_need_sent. it is safe to do so because no_idle_need_sent is inside S_RCVRY_IDLE if ltssm_ts_auto_change needs to be sent.
//do not clear ltssm_ts_auto_change during (lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_IDLE) because TxDataValid may be one cycle 0 at the entry to S_RCVRY_IDLE causing TS2 sent delay 1 cycle
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ltssm_ts_auto_change    <= #TP 1'b0;
    else if ( lts_state == S_POLL_ACTIVE ) // initial deemphasis setting
        ltssm_ts_auto_change    <= #TP cfg_sel_de_emphasis ;
    else if ( lts_state == S_CFG_COMPLETE && clear ) // Link upconfig support
        ltssm_ts_auto_change    <= #TP (ltssm_flit_mode_enable) ? cfg_reciver_l0p_supported : cfg_upconfigure_support;
    else if ( lts_state == S_CFG_LINKWD_START && clear ) // used for auto change
        ltssm_ts_auto_change    <= #TP (cfg_upstream_port && (last_lts_state == S_RCVRY_IDLE)) ? (directed_link_width_change_updown && !latched_valid_reliability_link_width_change) : 1'b0;
//    else if ( !cfg_upstream_port && (next_lts_state == S_RCVRY_LOCK) && !clear )      // used for deemphasis
//        ltssm_ts_auto_change    <= #TP cfg_sel_de_emphasis;
    else if ( (cfg_upstream_port && (lts_state == S_RCVRY_LOCK)) ||       // used for deemphasis
              (!cfg_upstream_port && clear && (lts_state == S_RCVRY_RCVRCFG)) ) // used for deemphasis. if cfg_selectable_deemph_bit_mux = 1, the value requested by USP. Else, the Selectable De-emphasis field in the Link Control 2 register
        ltssm_ts_auto_change    <= #TP cfg_upstream_port ? ( cfg_sel_de_emphasis) : ( (ltssm_ts_data_rate[1] == 1'b1) ? (cfg_selectable_deemph_bit_mux ? latched_ts_deemphasis : cfg_sel_de_emphasis) : 1'b0) ;
//    else if ( !cfg_upstream_port && (lts_state != S_RCVRY_RCVRCFG) && !clear && (next_lts_state == S_RCVRY_RCVRCFG) )  // used for deemphasis
//        ltssm_ts_auto_change    <= #TP `ifdef CX_GEN2_SPEED (ltssm_ts_data_rate[1] == 1'b1) ? cfg_sel_de_emphasis : `endif 1'b0;
    else if ( cfg_upstream_port && clear && (lts_state == S_RCVRY_RCVRCFG) ) // used for auto change
        ltssm_ts_auto_change    <= #TP (directed_speed_change_r & (cfg_pcie_max_link_speed != `GEN1_LINK_SP)) | (directed_link_width_change_updown && !latched_valid_reliability_link_width_change) | 1'b0;
    else if ( cfg_upstream_port && (lts_state == S_LPBK_ENTRY) && cfg_lpbk_en && last_lts_state == S_RCVRY_IDLE )  // used for deemphasis with lpbk master
        ltssm_ts_auto_change    <= #TP (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS) ? cfg_sel_de_emphasis : ltssm_ts_auto_change ;
    else if ( /*cfg_upstream_port &&*/ clear && (lts_state == S_LPBK_ENTRY) && cfg_lpbk_en )  // used for deemphasis with lpbk master
        ltssm_ts_auto_change    <= #TP cfg_sel_de_emphasis ;
    else if ( ~(lts_state == S_POLL_ACTIVE || lts_state == S_CFG_LINKWD_START || lts_state == S_LPBK_ENTRY || lts_state == S_POLL_CONFIG || lts_state == S_CFG_COMPLETE || lts_state_d == S_CFG_COMPLETE || (lts_state == S_RCVRY_IDLE && no_idle_need_sent) ||
                lts_state == S_RCVRY_RCVRCFG || (lts_state_d == S_RCVRY_RCVRCFG && lts_state == S_RCVRY_IDLE) || (cfg_upstream_port && (lts_state == S_CFG_LINKWD_ACEPT || lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_RCVRY_LOCK))) )
        ltssm_ts_auto_change    <= #TP 0;

// generate ltssm_ts_data_rate from next_lts_state = S_RCVRY_RCVRCFG for ltssm_cmd_8geqts os that ltssm_cmd_8geqts is read when entry to S_RCVRY_RCVRCFG state
always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_ts_data_rate_int_PROC
    if ( ~core_rst_n )
        ltssm_ts_data_rate_int <= #TP 5'b00001;
    else if ( lts_state == S_RCVRY_LOCK && next_lts_state == S_RCVRY_RCVRCFG && ~clear && (cond_eqos_usp_send_maxspeed | latched_eqos_usp_send_maxspeed) && downstream_component )
        ltssm_ts_data_rate_int <= #TP (g5_rate && ltssm_flit_mode_enable) ? 5'b10111 : (g4_rate) ? 5'b11111 : (g3_rate) ? 5'b01111 : 5'b00111 ;
    else if ( downstream_component && (lts_state == S_RCVRY_RCVRCFG) && latched_eqos_usp_send_maxspeed )
        ltssm_ts_data_rate_int <= #TP (g5_rate && ltssm_flit_mode_enable) ? 5'b10111 : (g4_rate) ? 5'b11111 : (g3_rate) ? 5'b01111 : 5'b00111 ;
    else
        ltssm_ts_data_rate_int <= #TP ltssm_ts_data_rate;
end // ltssm_ts_data_rate_int_PROC

// cfg_flit_mode_enable_i = cfg_pcie_cap_flit_mode_sup & ~cfg_flit_mode_dis
// link_latched_flitm_support[1:0] = FM received in {Polling.Config, Polling.Active}. not see the r0.9 draft needs the conditions from received flit_mode_support.
wire g6_cfglwstart_data_rate = cfg_flit_mode_enable_i & cfg_lpbk_en & ~smlh_link_up; // flit_mode_support & ~flit_mode_disable for loopback master
wire g6_pollconfig_data_rate = 1'b0; // not advertise gen6 rate in Polling.Configure state

reg  linkup_0_in_cfglinkwdstart;
always @( posedge core_clk or negedge core_rst_n ) begin : linkup_0_in_cfglinkwdstart_PROC
    if ( ~core_rst_n )
        linkup_0_in_cfglinkwdstart <= #TP 0;
    else if ( last_lts_state == S_CFG_LINKWD_START && lts_state == S_LPBK_ENTRY )
        linkup_0_in_cfglinkwdstart <= #TP linkup_0_in_cfglinkwdstart;
    else if ( lts_state == S_CFG_LINKWD_START && smlh_link_up == 1'b0 )
        linkup_0_in_cfglinkwdstart <= #TP 1'b1;
    else
        linkup_0_in_cfglinkwdstart <= #TP 0;
end // linkup_0_in_cfglinkwdstart_PROC

wire gen3_gen4_gen5_device = (cfg_pcie_max_link_speed==`GEN3_LINK_SP) || (cfg_pcie_max_link_speed==`GEN4_LINK_SP) || (cfg_pcie_max_link_speed==`GEN5_LINK_SP);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        ltssm_ts_data_rate      <= #TP 5'b00001;
    else if ( poll_config_state && cfg_alt_protocol_enable && ~smlh_link_up && gen3_gen4_gen5_device)
        ltssm_ts_data_rate <= #TP 5'b11111; // advertise gen5 support in Polling + Cfg.Linkwidth.Start + Cfg.Linkwidth.Accept state
    else if ( cfg_alt_protocol_enable_i && (lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_CFG_COMPLETE) && ~smlh_link_up && gen3_gen4_gen5_device)
        ltssm_ts_data_rate <= #TP 5'b11111; // advertise gen5 support in S_CFG_LANENUM_WAIT && S_CFG_LANENUM_ACEPT
    // in case of core_clk off in L1_IDLE. When the first core_clk is on and ltssm moves from L1_IDLE to Recovery immediately. So ltssm_ts_data_rate does not capture target_link_speed_real
    // generate a pulse when entering Recovery to catch the target_link_speed_real
    else if ( (last_lts_state == S_L1_IDLE || last_lts_state == S_RCVRY_EQ1 || last_lts_state == S_RCVRY_EQ3 ) && (lts_state == S_RCVRY_LOCK) && clear )
        ltssm_ts_data_rate      <= #TP (target_link_speed_real == `GEN6_LINK_SP) ? (ltssm_flit_mode_enable ? 5'b10111 : 5'b11111) : (target_link_speed_real == `GEN5_LINK_SP) ? 5'b11111 : (target_link_speed_real ==  `GEN4_LINK_SP) ? 5'b01111 : (target_link_speed_real ==  `GEN3_LINK_SP) ? 5'b00111 : (target_link_speed_real ==  `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
    // Conditions when the transmitted data rate reflects the target link speed register
    else if ( lts_state == S_CFG_COMPLETE && clear ) // for gen6 target_link_speed in this state if flit_mode ? gen6 : gen5
        ltssm_ts_data_rate      <= #TP (target_link_speed_real == `GEN6_LINK_SP) ? (ltssm_flit_mode_enable ? 5'b10111 : 5'b11111) : (target_link_speed_real == `GEN5_LINK_SP) ? 5'b11111 : (target_link_speed_real ==  `GEN4_LINK_SP) ? 5'b01111 : (target_link_speed_real ==  `GEN3_LINK_SP) ? 5'b00111 : (target_link_speed_real ==  `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
    // Conditions when the transmitted data rate is not allowed to change
    // 4.2.6.4.1 Recovery.RcvrLock: Under other conditions, a device must not change the supported data rate values either in this substate or while in the Recovery.RcvrCfg or Recovery.Equalization substates.
    else if ( (lts_state == S_CFG_COMPLETE) || (lts_state == S_RCVRY_LOCK) || (lts_state == S_RCVRY_RCVRCFG) || ltssm_state_rcvry_eq ) begin
        if( downstream_component && (lts_state == S_RCVRY_RCVRCFG) && latched_eqos_usp_send_maxspeed ) // if ltssm_flit_mode_enable, speed up to gen6 5'b10111 from g5_rate, else keep gen5 5'b11111
            ltssm_ts_data_rate      <= #TP (g5_rate) ? ((/*target_link_speed_real == `GEN6_LINK_SP &&*/ ltssm_flit_mode_enable) ? 5'b10111 : 5'b11111) : (g4_rate) ? 5'b11111 : (g3_rate) ? 5'b01111 : 5'b00111 ;
        else if( upstream_component && (lts_state == S_RCVRY_RCVRCFG) && (soft_eq_phase_flag_ff) &&
                  (!equalization_done_8gt_data_rate || equalization_done_8gt_data_rate && (!equalization_done_16gt_data_rate)) && (g1_rate || g2_rate) )
            ltssm_ts_data_rate      <= #TP 5'b00111;
        else if( upstream_component && (lts_state == S_RCVRY_RCVRCFG) && (soft_gen4_eq_phase_flag_ff || init_eq_pending_g6 || init_eq_pending_g5 || latched_remote_soft_eq_g6 ) && // soft_eq_phase_flag_ff may be 1 but soft_gen4_eq_phase_flag_ff may be 0, which means the core only wants gen3 eq. So no ltssm_ts_data_rate = Gen4 from current gen3 rate
                 ( equalization_done_16gt_data_rate && !equalization_done_32gt_data_rate && (soe_g3) ) )
            ltssm_ts_data_rate      <= #TP skip_eq ? 5'b11111 : 5'b01111;
        else if( upstream_component && (lts_state == S_RCVRY_RCVRCFG) && soft_eq_phase_flag_ff && (target_link_speed_real >= `GEN4_LINK_SP) && // go for gen4 rate. soft_eq_phase_flag_ff would be cleared if both ports do not support common gen4 rate at current gen3 rate
                  (equalization_done_8gt_data_rate && (!equalization_done_16gt_data_rate)) && (g3_rate) ) // ~equalization_done_16gt_data_rate at gen3, advertise gen4 rate
            ltssm_ts_data_rate      <= #TP 5'b01111;
        else if( upstream_component && (lts_state == S_RCVRY_RCVRCFG) && soft_gen5_eq_phase_flag_ff && // current_data_rate = gen1/2 && ~equalization_done_64gt_data_rate && skip_eq, must perform gen5 eq first
                 (!equalization_done_64gt_data_rate && current_data_rate <= `GEN3_RATE && skip_eq && ltssm_flit_mode_enable) )
            ltssm_ts_data_rate      <= #TP 5'b11111;
        else if( upstream_component && (lts_state == S_RCVRY_RCVRCFG) && soft_gen5_eq_phase_flag_ff && // if current_data_rate = gen5 && gen5_eq_done, perform gen6 eq
                 (equalization_done_32gt_data_rate && !equalization_done_64gt_data_rate && current_data_rate == `GEN5_RATE && ltssm_flit_mode_enable) )
            ltssm_ts_data_rate      <= #TP 5'b10111;
        // || soft_gen5_eq_phase_flag_ff because soft_eq_phase_flag_ff does not include eq for gen5 from gen4 rate
        else if( upstream_component && (lts_state == S_RCVRY_RCVRCFG) && (soft_eq_phase_flag_ff || soft_gen5_eq_phase_flag_ff) && (target_link_speed_real >= `GEN5_LINK_SP) && // go for gen4 rate. soft_eq_phase_flag_ff would be cleared if both ports do not support common gen4 rate at current gen3 rate
                  (equalization_done_16gt_data_rate && (!equalization_done_32gt_data_rate)) && (current_data_rate == `GEN4_RATE) ) // ~equalization_done_32gt_data_rate at gen4, advertise gen5 rate
            ltssm_ts_data_rate      <= #TP 5'b11111;
        else if ( perform_eq_for_loopback_g6 && lts_state == S_RCVRY_EQ1 ) // if perform_eq_for_loopback_64gt = 1 in EQ1, advertise gen6 rate
            ltssm_ts_data_rate      <= #TP 5'b10111;
        else
            ltssm_ts_data_rate      <= #TP ltssm_ts_data_rate;
    // Conditions when the transmitted data rate reflects the supported link speeds register
    end else if (   (lts_state == S_DETECT_QUIET) || (lts_state == S_POLL_ACTIVE)
             || (lts_state == S_POLL_CONFIG)  || (lts_state == S_CFG_LINKWD_START) ) begin
        if ( lts_state == S_POLL_CONFIG ) // if (FMSE = 1 && Rx_Sym4[0] = 1 from Polling.Active) && cfg_pcie_max_link_speed == `GEN6_LINK_SP, gen6
            ltssm_ts_data_rate      <= #TP (g6_pollconfig_data_rate && cfg_pcie_max_link_speed == `GEN6_LINK_SP) ? 5'b10111 : (cfg_pcie_max_link_speed >= `GEN5_LINK_SP) ? 5'b11111 : (cfg_pcie_max_link_speed == `GEN4_LINK_SP) ? 5'b01111 : (cfg_pcie_max_link_speed == `GEN3_LINK_SP) ? 5'b00111 : (cfg_pcie_max_link_speed == `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
        else if ( lts_state == S_DETECT_QUIET || lts_state == S_POLL_ACTIVE ) // if flit_mode support & tx_compliance_rcv & ~loopback, gen6. Else ...
            ltssm_ts_data_rate      <= #TP (ltssm_ts_cntrl[4] && ~ltssm_ts_cntrl[2] && cfg_flit_mode_enable_i && cfg_pcie_max_link_speed == `GEN6_LINK_SP) ? 5'b10111 : (cfg_pcie_max_link_speed >= `GEN5_LINK_SP) ? 5'b11111 : (cfg_pcie_max_link_speed == `GEN4_LINK_SP) ? 5'b01111 : (cfg_pcie_max_link_speed == `GEN3_LINK_SP) ? 5'b00111 : (cfg_pcie_max_link_speed == `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
        else // lts_state == S_CFG_LINKWD_START. if ltssm_flit_mode_enable = 1 for loopback master, advertise max gen6 rate if support
            ltssm_ts_data_rate      <= #TP ((ltssm_flit_mode_enable || g6_cfglwstart_data_rate) && cfg_pcie_max_link_speed == `GEN6_LINK_SP) ? 5'b10111 : (cfg_pcie_max_link_speed >= `GEN5_LINK_SP) ? 5'b11111 :
                                                                                                  (cfg_pcie_max_link_speed == `GEN4_LINK_SP) ? 5'b01111 : (cfg_pcie_max_link_speed == `GEN3_LINK_SP) ? 5'b00111 : (cfg_pcie_max_link_speed == `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
    end else if ( lts_state == S_CFG_LINKWD_ACEPT ) begin
        ltssm_ts_data_rate      <= #TP (ltssm_flit_mode_enable && cfg_pcie_max_link_speed == `GEN6_LINK_SP) ? 5'b10111 : (cfg_pcie_max_link_speed >= `GEN5_LINK_SP) ? 5'b11111 : (cfg_pcie_max_link_speed == `GEN4_LINK_SP) ? 5'b01111 : (cfg_pcie_max_link_speed == `GEN3_LINK_SP) ? 5'b00111 : (cfg_pcie_max_link_speed == `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
    end else if ( last_lts_state == S_CFG_LINKWD_START && lts_state == S_LPBK_ENTRY && cfg_flit_mode_enable_i && lpbk_master && cfg_pcie_max_link_speed == `GEN6_LINK_SP && linkup_0_in_cfglinkwdstart ) begin
        ltssm_ts_data_rate      <= #TP 5'b10111; // lpbk.entry from cfg.linkwd.start for lpbk master & LinkUp = 0 in cfg.linkwd.start, advertise gen6
    // Conditions when the transmitted data rate reflects the target link speed register
    end else if ( (lts_state == S_L0) || (lts_state == S_L1_IDLE) || (lts_state == S_L0S)
               || ((lts_state != S_RCVRY_LOCK) && (next_lts_state == S_RCVRY_LOCK) && !clear) )
        ltssm_ts_data_rate      <= #TP (target_link_speed_real == `GEN6_LINK_SP) ? (ltssm_flit_mode_enable ? 5'b10111 : 5'b11111) : (target_link_speed_real == `GEN5_LINK_SP) ? 5'b11111 : (target_link_speed_real ==  `GEN4_LINK_SP) ? 5'b01111 : (target_link_speed_real ==  `GEN3_LINK_SP) ? 5'b00111 : (target_link_speed_real ==  `GEN2_LINK_SP) ? 5'b00011 : 5'b00001;
    else
        ltssm_ts_data_rate      <= #TP ltssm_ts_data_rate;


// -------------------------------------------------------------------------
// Link Width Change Logic
assign go_recovery_link_width_change = (cfg_directed_link_width_change || hw_autowidth_dis_upconf ) && smlh_dl_active;

wire cfg_hw_autowidth_dis_i;
assign cfg_hw_autowidth_dis_i = cfg_hw_autowidth_dis && ~smlh_ltssm_in_l0p; // For l0p state, Layer2 initiates an up-size request to full configured link width using l0p DLLPs.
// cfg_reliability_link_width_change_enable permits downsizing link for reliability reasons through cfg_directed_link_width_change/cfg_target_link_width, irrespective of cf_hw_autowidth_dis and cfg_upconfigure_support
wire valid_reliability_link_width_change = cfg_reliability_link_width_change_enable && (cfg_target_link_width < latest_link_mode);

assign int_target_link_width_legal = ( (cfg_hw_autowidth_dis_i || !upconfigure_capable) && !valid_reliability_link_width_change ) ? 6'b00_0000 : // if latched_target_link_width is 0, just go through config state without initiating width change
                                     ( cfg_target_link_width==6'b10_0000 ||
                                       cfg_target_link_width==6'b01_0000 ||
                                       cfg_target_link_width==6'b00_1000 ||
                                       cfg_target_link_width==6'b00_0100 ||
                                       cfg_target_link_width==6'b00_0010 ||
                                       cfg_target_link_width==6'b00_0001 )  ? cfg_target_link_width :
                                                                              6'b00_0000;

assign int_target_link_width_real = ((int_target_link_width_legal > linkup_link_mode) || hw_autowidth_dis_upconf) ? linkup_link_mode : int_target_link_width_legal;

always@(posedge core_clk or negedge core_rst_n)
begin : directed_link_width_change_PROC
    if (!core_rst_n) begin
        directed_link_width_change                  <= #TP 1'b0;
        latched_valid_reliability_link_width_change <= #TP 1'b0;
        latched_target_link_width                   <= #TP 6'h0;
    end else if ( ((lts_state == S_L0)||(lts_state == S_L1_IDLE)) && (next_lts_state == S_RCVRY_LOCK) && !clear && go_recovery_link_width_change ) begin
        directed_link_width_change                  <= #TP 1'b1;
        latched_valid_reliability_link_width_change <= #TP valid_reliability_link_width_change;
        latched_target_link_width                   <= #TP int_target_link_width_real;
    // No flit mode link width change if we do EQ in same transition to Recovery, or if in Rcvry.RcvrCfg speed_change bit =1. See 6.1 Spec section on Recovery.RcvrCfg
    end else if ( ( ((lts_state == S_CFG_IDLE) && (next_lts_state != S_CFG_IDLE)) || (ltssm_flit_mode_enable && ((lts_state == S_RCVRY_LOCK && next_state_is_eq) )) ) && !clear ) begin
        directed_link_width_change                  <= #TP 1'b0;
        latched_valid_reliability_link_width_change <= #TP 1'b0;
        latched_target_link_width                   <= #TP latched_target_link_width;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : latched_auto_width_downsizing_PROC
    if ( ~core_rst_n )
        latched_auto_width_downsizing <= #TP 0;
    else if ( !smlh_link_up )
        latched_auto_width_downsizing <= #TP 0;
    else
        latched_auto_width_downsizing <= #TP latched_auto_width_downsizing | directed_link_width_change_down;
end

always @(posedge core_clk or negedge core_rst_n) begin : hw_autowidth_dis_d_PROC
    if ( ~core_rst_n )
        hw_autowidth_dis_d <= #TP 0;
    else
        hw_autowidth_dis_d <= #TP cfg_hw_autowidth_dis_i;
end

assign hw_autowidth_dis_rising_edge = cfg_hw_autowidth_dis_i & ~hw_autowidth_dis_d;

always @(posedge core_clk or negedge core_rst_n) begin : hw_autowidth_dis_upconf_PROC
    if ( ~core_rst_n )
        hw_autowidth_dis_upconf <= #TP 0;
    else if ( (lts_state != S_L0) && (next_lts_state == S_L0) && !clear && directed_link_width_change_up && (linkup_link_mode==latched_target_link_width) )
        hw_autowidth_dis_upconf <= #TP 0;
    else if ( latched_auto_width_downsizing && hw_autowidth_dis_rising_edge && (linkup_link_mode > smlh_link_mode) )
        hw_autowidth_dis_upconf <= #TP 1;
end

assign target_link_lanes_active = 
                                  latched_target_link_width[3] ? 'h00ff :
                                  latched_target_link_width[2] ? 'h000f :
                                  latched_target_link_width[1] ? 'h0003 :
                                                                 'h0001;

assign remote_lanes_activated = 
                                linkup_link_mode[3] ? (16'h00ff & latchd_rxeidle_exit_upconf & link_2_ts1_plinkn_planen_rcvd_upconf) :
                                linkup_link_mode[2] ? (16'h000f & latchd_rxeidle_exit_upconf & link_2_ts1_plinkn_planen_rcvd_upconf) :
                                linkup_link_mode[1] ? (16'h0003 & latchd_rxeidle_exit_upconf & link_2_ts1_plinkn_planen_rcvd_upconf) :
                                                      16'h0000;


logic directed_link_width_change_d;
always @(posedge core_clk or negedge core_rst_n) begin : directed_link_width_change_d_PROC
    if ( ~core_rst_n ) begin
        directed_link_width_change_d <= #TP '0;
    end else begin
        directed_link_width_change_d <= #TP directed_link_width_change;
    end
end
assign smlh_dir_linkw_chg_started = directed_link_width_change & ~directed_link_width_change_d ;

assign directed_link_width_change_updown = directed_link_width_change_up | directed_link_width_change_down;
assign directed_link_width_change_up     = directed_link_width_change & (latched_target_link_width != 0) & (latched_target_link_width > latest_link_mode);
assign directed_link_width_change_down   = directed_link_width_change & (latched_target_link_width != 0) & (latched_target_link_width < latest_link_mode);
assign directed_link_width_change_nochg  = directed_link_width_change & !directed_link_width_change_updown;

always@(posedge core_clk or negedge core_rst_n)
begin : cfglwstart_upconf_dsp_PROC
    if (!core_rst_n) begin
        cfglwstart_upconf_dsp <= #TP 1'b0;
    end else if ( (lts_state != S_CFG_LINKWD_START) && (next_lts_state == S_CFG_LINKWD_START) && !clear ) begin
        if(directed_link_width_change_up && !cfg_upstream_port)
            cfglwstart_upconf_dsp <= #TP 1'b1;
        else
            cfglwstart_upconf_dsp <= #TP 1'b0;
    end else if ( (lts_state == S_CFG_LINKWD_START) && (timeout_1ms || link_latched_live_all_2_ts1_plinkn_planen_rcvd && !clear) ) begin
        cfglwstart_upconf_dsp <= #TP 1'b0;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : latchd_rxeidle_exit_upconf_PROC
    integer i;
    if (!core_rst_n)
        latchd_rxeidle_exit_upconf <= #TP 0;
    else if ( (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)) && !clear )
        latchd_rxeidle_exit_upconf <= #TP 0;
    else
        for (i = 0; i < NL; i= i+1)
           if (!phy_mac_rxelecidle[i])
             latchd_rxeidle_exit_upconf[i] <= #TP 1'b1;
end

always @(posedge core_clk or negedge core_rst_n) begin : upconfigure_capable_PROC
    if (!core_rst_n)
        upconfigure_capable <= #TP 0;
    else if(lts_state == S_DETECT_QUIET)
        upconfigure_capable <= #TP 0;
    else if((lts_state == S_CFG_COMPLETE) && ~clear && link_ln0_8_ts2_linknmtx_lanenmtx_rcvd & ~ltssm_flit_mode_enable)
        upconfigure_capable <= #TP link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd & ltssm_ts_auto_change; // rx and tx
end

assign link_mode_activated_pulse = !clear &&
                                   ( lts_state == S_CFG_LINKWD_START && !directed_link_width_change_updown && ltssm_lanes_activated_pulse ) &&
                                   ( 
                                     smlh_link_mode[2] && (&ltssm_lanes_active[7:4]) ||
                                     smlh_link_mode[1] && (&ltssm_lanes_active[3:2]) ||
                                     smlh_link_mode[0] && (ltssm_lanes_active[1]) ||
                                     1'b0);

// End of Link Width Change Logic
// -------------------------------------------------------------------------


always @( posedge core_clk or negedge core_rst_n )
    if ( ~core_rst_n ) begin
        smlh_retimer_pre_detected <= #TP 0;
        smlh_two_retimers_pre_detected <= #TP 0;
    end
    else if ( (lts_state == S_CFG_COMPLETE) && (next_lts_state == S_CFG_IDLE) && (g1_rate) && !clear ) begin
        smlh_retimer_pre_detected <= #TP link_latched_ts_retimer_pre;
        smlh_two_retimers_pre_detected <= #TP link_latched_ts_two_retimers_pre;
    end

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        persist_2scrmb_dis_rcvd <= #TP 1'b0;
    else if ( lts_state == S_DETECT_ACT ) //scrambler enabled for gen3 rate
        persist_2scrmb_dis_rcvd <= #TP 1'b0;
    else if ( ((lts_state == S_CFG_COMPLETE) & ((link_latched_live_all_ts_scrmb_dis) | cfg_scrmb_dis))
        & ( g1_rate || g2_rate ))
        // latched the scrambler disable during the cfg completion state
        // to disable the scrambler of this lane
        persist_2scrmb_dis_rcvd       <= #TP 1'b1;

// This counts the cycles between rmlh_rcvd_eidle_set pulses and clears the count if the eidles weren't contiguous as required by the spec
// Its also used to protect from counting too many Eidles because of lane skew
/*
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        eidle_continuity_cnt    <= #TP 3'b0;
    else if (clear || rcvd_valid_eidle_set || (eidle_continuity_cnt == 3'b0))  // Clear the count when we change states or an EIDLE OS is received
        eidle_continuity_cnt    <= #TP active_nb[0] ? 3'd3 : 3'd1;
    else if (rcvd_eidle_cnt > 3'b0)
        eidle_continuity_cnt    <= #TP eidle_continuity_cnt - 3'b1;
*/
always@(posedge core_clk or negedge core_rst_n) begin : EIDLE_CONTINUITY_CNT
  if (!core_rst_n) begin
    eidle_continuity_cnt <= #TP 0;
  end else begin
      if (clear || rcvd_valid_eidle_set[0] || (eidle_continuity_cnt[2:0] == 3'b0))
        eidle_continuity_cnt[2:0] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[3:0] > 4'b0)
        eidle_continuity_cnt[2:0] <= #TP eidle_continuity_cnt[2:0] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[1] || (eidle_continuity_cnt[5:3] == 3'b0))
        eidle_continuity_cnt[5:3] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[7:4] > 4'b0)
        eidle_continuity_cnt[5:3] <= #TP eidle_continuity_cnt[5:3] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[2] || (eidle_continuity_cnt[8:6] == 3'b0))
        eidle_continuity_cnt[8:6] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[11:8] > 4'b0)
        eidle_continuity_cnt[8:6] <= #TP eidle_continuity_cnt[8:6] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[3] || (eidle_continuity_cnt[11:9] == 3'b0))
        eidle_continuity_cnt[11:9] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[15:12] > 4'b0)
        eidle_continuity_cnt[11:9] <= #TP eidle_continuity_cnt[11:9] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[4] || (eidle_continuity_cnt[14:12] == 3'b0))
        eidle_continuity_cnt[14:12] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[19:16] > 4'b0)
        eidle_continuity_cnt[14:12] <= #TP eidle_continuity_cnt[14:12] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[5] || (eidle_continuity_cnt[17:15] == 3'b0))
        eidle_continuity_cnt[17:15] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[23:20] > 4'b0)
        eidle_continuity_cnt[17:15] <= #TP eidle_continuity_cnt[17:15] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[6] || (eidle_continuity_cnt[20:18] == 3'b0))
        eidle_continuity_cnt[20:18] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[27:24] > 4'b0)
        eidle_continuity_cnt[20:18] <= #TP eidle_continuity_cnt[20:18] - 3'b1;

      //Clear the count when we change states or an EIDLE OS is received
      if (clear || rcvd_valid_eidle_set[7] || (eidle_continuity_cnt[23:21] == 3'b0))
        eidle_continuity_cnt[23:21] <= #TP active_nb[0] ? 3'd3 : 3'd1;
      else if (rcvd_eidle_cnt[31:28] > 4'b0)
        eidle_continuity_cnt[23:21] <= #TP eidle_continuity_cnt[23:21] - 3'b1;

  end
end

//get rcvd_valid_eidle_set based on per lane
always @( act_rmlh_rcvd_eidle_set or rcvd_eidle_cnt or eidle_continuity_cnt or active_nb ) begin : EIDLE_VALID
  rcvd_valid_eidle_set = 0;
    rcvd_valid_eidle_set[0] = act_rmlh_rcvd_eidle_set[0] && ( (rcvd_eidle_cnt[3:0] == 0)
                                 || (eidle_continuity_cnt[2:0] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[1] = act_rmlh_rcvd_eidle_set[1] && ( (rcvd_eidle_cnt[7:4] == 0)
                                 || (eidle_continuity_cnt[5:3] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[2] = act_rmlh_rcvd_eidle_set[2] && ( (rcvd_eidle_cnt[11:8] == 0)
                                 || (eidle_continuity_cnt[8:6] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[3] = act_rmlh_rcvd_eidle_set[3] && ( (rcvd_eidle_cnt[15:12] == 0)
                                 || (eidle_continuity_cnt[11:9] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[4] = act_rmlh_rcvd_eidle_set[4] && ( (rcvd_eidle_cnt[19:16] == 0)
                                 || (eidle_continuity_cnt[14:12] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[5] = act_rmlh_rcvd_eidle_set[5] && ( (rcvd_eidle_cnt[23:20] == 0)
                                 || (eidle_continuity_cnt[17:15] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[6] = act_rmlh_rcvd_eidle_set[6] && ( (rcvd_eidle_cnt[27:24] == 0)
                                 || (eidle_continuity_cnt[20:18] == 0) || active_nb[2] );

    rcvd_valid_eidle_set[7] = act_rmlh_rcvd_eidle_set[7] && ( (rcvd_eidle_cnt[31:28] == 0)
                                 || (eidle_continuity_cnt[23:21] == 0) || active_nb[2] );

end

//assign  rcvd_valid_eidle_set = rmlh_rcvd_eidle_set && ( (rcvd_eidle_cnt == 0)
//                                                        || (eidle_continuity_cnt == 0) || active_nb[2]);

// how many cycles it should take between eidle pulses
assign  eidle_cnt_max = active_nb[0] ? 3'd3 : 3'd1;

//assign  eidle_cnt_clear = active_nb[2] ? (|rcvd_eidle_cnt && !rmlh_rcvd_eidle_set) : // if in 4S mode, clear on any interruption of rmlh_rcvd_eidle_set
//                            (eidle_continuity_cnt == 3'd0) && !rmlh_rcvd_eidle_set;

//lane-base eidle_cnt_clear
always @(active_nb or rcvd_eidle_cnt or act_rmlh_rcvd_eidle_set or eidle_continuity_cnt) begin : EIDLE_CNT_CLEAR
  eidle_cnt_clear = 0;

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[0] = active_nb[2] ? (|rcvd_eidle_cnt[3:0] && !act_rmlh_rcvd_eidle_set[0]) :
                            (eidle_continuity_cnt[2:0] == 3'd0) && !act_rmlh_rcvd_eidle_set[0];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[1] = active_nb[2] ? (|rcvd_eidle_cnt[7:4] && !act_rmlh_rcvd_eidle_set[1]) :
                            (eidle_continuity_cnt[5:3] == 3'd0) && !act_rmlh_rcvd_eidle_set[1];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[2] = active_nb[2] ? (|rcvd_eidle_cnt[11:8] && !act_rmlh_rcvd_eidle_set[2]) :
                            (eidle_continuity_cnt[8:6] == 3'd0) && !act_rmlh_rcvd_eidle_set[2];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[3] = active_nb[2] ? (|rcvd_eidle_cnt[15:12] && !act_rmlh_rcvd_eidle_set[3]) :
                            (eidle_continuity_cnt[11:9] == 3'd0) && !act_rmlh_rcvd_eidle_set[3];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[4] = active_nb[2] ? (|rcvd_eidle_cnt[19:16] && !act_rmlh_rcvd_eidle_set[4]) :
                            (eidle_continuity_cnt[14:12] == 3'd0) && !act_rmlh_rcvd_eidle_set[4];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[5] = active_nb[2] ? (|rcvd_eidle_cnt[23:20] && !act_rmlh_rcvd_eidle_set[5]) :
                            (eidle_continuity_cnt[17:15] == 3'd0) && !act_rmlh_rcvd_eidle_set[5];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[6] = active_nb[2] ? (|rcvd_eidle_cnt[27:24] && !act_rmlh_rcvd_eidle_set[6]) :
                            (eidle_continuity_cnt[20:18] == 3'd0) && !act_rmlh_rcvd_eidle_set[6];

    //if in 4S mode, clear on any interruption of act_rmlh_rcvd_eidle_set
    eidle_cnt_clear[7] = active_nb[2] ? (|rcvd_eidle_cnt[31:28] && !act_rmlh_rcvd_eidle_set[7]) :
                            (eidle_continuity_cnt[23:21] == 3'd0) && !act_rmlh_rcvd_eidle_set[7];

end


// Count the number of electrical idle ordered sets.
// Stop the counter at 8
// changed to 4 (code coverage) because we only need max 4 EIOSs in Rx and move to next state
always@(posedge core_clk or negedge core_rst_n) begin : EIDLE_CNT
  if (!core_rst_n) begin
    rcvd_eidle_cnt <= #TP 0;
  end else begin
      if (clear || eidle_cnt_clear[0])
        rcvd_eidle_cnt[3:0] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[3:0]>=4)
        rcvd_eidle_cnt[3:0] <= #TP rcvd_eidle_cnt[3:0];
      else if (rcvd_valid_eidle_set[0])
        rcvd_eidle_cnt[3:0] <= #TP rcvd_eidle_cnt[3:0] + 1'b1;

      if (clear || eidle_cnt_clear[1])
        rcvd_eidle_cnt[7:4] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[7:4]>=4)
        rcvd_eidle_cnt[7:4] <= #TP rcvd_eidle_cnt[7:4];
      else if (rcvd_valid_eidle_set[1])
        rcvd_eidle_cnt[7:4] <= #TP rcvd_eidle_cnt[7:4] + 1'b1;

      if (clear || eidle_cnt_clear[2])
        rcvd_eidle_cnt[11:8] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[11:8]>=4)
        rcvd_eidle_cnt[11:8] <= #TP rcvd_eidle_cnt[11:8];
      else if (rcvd_valid_eidle_set[2])
        rcvd_eidle_cnt[11:8] <= #TP rcvd_eidle_cnt[11:8] + 1'b1;

      if (clear || eidle_cnt_clear[3])
        rcvd_eidle_cnt[15:12] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[15:12]>=4)
        rcvd_eidle_cnt[15:12] <= #TP rcvd_eidle_cnt[15:12];
      else if (rcvd_valid_eidle_set[3])
        rcvd_eidle_cnt[15:12] <= #TP rcvd_eidle_cnt[15:12] + 1'b1;

      if (clear || eidle_cnt_clear[4])
        rcvd_eidle_cnt[19:16] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[19:16]>=4)
        rcvd_eidle_cnt[19:16] <= #TP rcvd_eidle_cnt[19:16];
      else if (rcvd_valid_eidle_set[4])
        rcvd_eidle_cnt[19:16] <= #TP rcvd_eidle_cnt[19:16] + 1'b1;

      if (clear || eidle_cnt_clear[5])
        rcvd_eidle_cnt[23:20] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[23:20]>=4)
        rcvd_eidle_cnt[23:20] <= #TP rcvd_eidle_cnt[23:20];
      else if (rcvd_valid_eidle_set[5])
        rcvd_eidle_cnt[23:20] <= #TP rcvd_eidle_cnt[23:20] + 1'b1;

      if (clear || eidle_cnt_clear[6])
        rcvd_eidle_cnt[27:24] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[27:24]>=4)
        rcvd_eidle_cnt[27:24] <= #TP rcvd_eidle_cnt[27:24];
      else if (rcvd_valid_eidle_set[6])
        rcvd_eidle_cnt[27:24] <= #TP rcvd_eidle_cnt[27:24] + 1'b1;

      if (clear || eidle_cnt_clear[7])
        rcvd_eidle_cnt[31:28] <= #TP 4'b0;
      else if (rcvd_eidle_cnt[31:28]>=4)
        rcvd_eidle_cnt[31:28] <= #TP rcvd_eidle_cnt[31:28];
      else if (rcvd_valid_eidle_set[7])
        rcvd_eidle_cnt[31:28] <= #TP rcvd_eidle_cnt[31:28] + 1'b1;

  end
end

always@(posedge core_clk or negedge core_rst_n) begin : RCVD_4EIDLE
    if (!core_rst_n)
        rcvd_4eidle <= #TP 1'b0;
    else if (clear)
        rcvd_4eidle <= #TP 1'b0;
    else begin
        if ( rmlh_gen3_rcvd_4eidle_set ) //for gen3 rate
            rcvd_4eidle <= #TP 1'b1;
        else
        begin //for gen1/2 rate
            for (j=0; j<NL; j=j+1) begin
                //Gen3 Spec: EIOS has 4 symbols for 5GT/s as well
                if ( (g2_rate || g1_rate) && rcvd_eidle_cnt[4*j+2] ) begin
                    rcvd_4eidle <= #TP 1'b1;
                end
            end //for
        end //else begin //for gen1/2 rate
    end
end

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_rcvd_eidle_set  <= #TP 1'b0;
    else if (rmlh_rcvd_eidle_set)
        latched_rcvd_eidle_set  <= #TP 1'b1;
    else if (clear & (lts_state != S_DISABLED_IDLE) & (lts_state != S_L123_SEND_EIDLE))
        latched_rcvd_eidle_set  <= #TP 1'b0;

assign  smlh_scrambler_disable = persist_2scrmb_dis_rcvd;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_eidle_sent  <= #TP 1'b0;
    else if (clear | (curnt_compliance_state == S_COMPL_TX_COMPLIANCE))
        latched_eidle_sent  <= #TP 1'b0;
    else if (xmtbyte_eidle_sent)
        latched_eidle_sent  <= #TP 1'b1;

always @(posedge core_clk or negedge core_rst_n) begin : int_latched_smlh_inskip_rcv_PROC
    integer ii;

    if (!core_rst_n)
        int_latched_smlh_inskip_rcv <= #TP 0;
    else if ( clear || ( (goe_g6) || g3_rate || g4_rate || g5_rate) || (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) || (r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE) )
        int_latched_smlh_inskip_rcv <= #TP 0;
    else begin
        for ( ii=0; ii<NL; ii=ii+1 ) begin
            if (smlh_inskip_rcv[ii])
                int_latched_smlh_inskip_rcv[ii]  <= #TP 1'b1;
        end //for
    end
end //int_latched_smlh_inskip_rcv_PROC

always @( * ) begin : latched_smlh_inskip_rcv_PROC
    latched_smlh_inskip_rcv = &(~ltssm_lanes_active | int_latched_smlh_inskip_rcv); //all lanes receive skip os.
end // latched_smlh_inskip_rcv_PROC

always @(posedge core_clk or negedge core_rst_n) begin : latched_smlh_sds_rcvd_PROC
    integer ii;

    if (!core_rst_n)
        latched_smlh_sds_rcvd  <= #TP 0;
    else if ( clear || (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) || (r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE))
        latched_smlh_sds_rcvd  <= #TP 0;
    else begin
        for ( ii=0; ii<NL; ii=ii+1 ) begin
            if (smlh_sds_rcvd[ii])
                latched_smlh_sds_rcvd[ii]  <= #TP 1'b1;
        end //for
    end
end //always

assign latched_all_smlh_sds_rcvd = &(~ltssm_lanes_active | latched_smlh_sds_rcvd);


// number of idle flits sent for moving to L0 state. 4 for gen1 - gen5, 8 for >= gen6 from gen6 draft 02.02.2021
wire idle_flits_sent_mto_l0 = ltssm_flit_mode_enable & ( goe_g6 ? idle_sent_cnt >= 8 : idle_sent_cnt >= 4);

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        idle_16_sent        <= #TP 1'b0;
    else if (clear)
        idle_16_sent        <= #TP 1'b0;
    else if ( ltssm_flit_mode_enable ) begin
        if ( idle_flits_sent_mto_l0 ) idle_16_sent <= #TP 1'b1;
    end
    else if (ltssm_cxl_enable_d.io_enabled && idle_sent_cnt[3] ) // 8 flits sent after receiving 1
        idle_16_sent        <= #TP 1'b1;
    else if (idle_sent_cnt[4])
        idle_16_sent        <= #TP 1'b1;

reg ltssm_idl_hs_done_d;

// use combinatorial logic for rplh not to miss any normal flits detection
always @* begin : ltssm_idl_hs_done_PROC
    ltssm_idl_hs_done = ltssm_idl_hs_done_d;

    // S_CFG_LINKWD_ACEPT || S_RCVRY_RCVRCFG is for the port to re-detect idle flits after S_CFG_LINKWD_START || S_RCVRY_LOCK (confirmed the remote partner sends TS OS)
    if ( ~smlh_do_deskew || (clear && (lts_state == S_CFG_LINKWD_ACEPT || lts_state == S_RCVRY_RCVRCFG || lts_state == S_LPBK_ENTRY)) )        // clear when resetting deskew
        ltssm_idl_hs_done = 1'b0;
    // comment out (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) because wrongly get rplh_rcvd_idle[0] = 1 in the other states cannot make rplh to reset (if ltssm_idl_hs_done = 1) rplh_rcvd_idle detection
    // S_CFG_LINKWD_START || S_RCVRY_LOCK state is to stop Layer2 detecting idle filt (remote is in R.Idle state) and keep it to Cfg.Idle or R.Idle state
    else if ( (rplh_rcvd_idle[0] || lts_state == S_CFG_LINKWD_START || lts_state == S_RCVRY_LOCK) && ltssm_flit_mode_enable /*&& (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE)*/ ) // if received 2 idle flits
        ltssm_idl_hs_done = 1'b1;
    // after receiving 2 idle flits in Loopback.Active, Loopback master starts to detect nop/normal flits
    else if ( lts_state == S_LPBK_ACTIVE && rplh_rcvd_idle[0] )
        ltssm_idl_hs_done = 1'b1;
    else if ( lts_state == S_DETECT_QUIET )
        ltssm_idl_hs_done = 1'b0;
end // ltssm_idl_hs_done_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_idl_hs_done_d_PROC
    if ( ~core_rst_n )
        ltssm_idl_hs_done_d <= #TP 1'b0;
    else
        ltssm_idl_hs_done_d <= #TP ltssm_idl_hs_done;
end // ltssm_idl_hs_done_d_PROC

// -------------------------------------------------------------------------
// For reset, disable and loopback, PCI Express spec. required to receive
// two continous ts1 or ts2 with control bits set in order for both device
// on the link to decide the actions
reg                 clked_cfg_reset_assert;
reg                 clked_cfg_link_dis;
reg                 clked_cfg_lpbk_en;
reg                 clked_app_init_rst;
reg                 clked_spif_smlh_req_reset;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        clked_cfg_reset_assert <= #TP 0;
        lpbk_master            <= #TP 0;
        clked_cfg_link_dis     <= #TP 0;
        clked_cfg_lpbk_en      <= #TP 0;
        clked_app_init_rst     <= #TP 0;
        clked_spif_smlh_req_reset <= #TP 0;
    end else begin
        lpbk_master            <= #TP (cfg_lpbk_en & (lts_state != S_LPBK_ENTRY) & (next_lts_state == S_LPBK_ENTRY) & !clear) ? 1'b1
                                       : (lts_state == S_LPBK_EXIT_TIMEOUT) ? 1'b0 : lpbk_master;
        clked_cfg_reset_assert <= #TP cfg_reset_assert | clked_app_init_rst;
        clked_cfg_link_dis     <= #TP cfg_link_dis;
        clked_cfg_lpbk_en      <= #TP cfg_lpbk_en;
        clked_app_init_rst     <= #TP app_init_rst;
        clked_spif_smlh_req_reset <= #TP spif_smlh_req_reset;
    end

reg latched_cfg_link_dis;
always @* begin : latched_cfg_link_dis_PROC
    latched_cfg_link_dis = 1'b0;

    latched_cfg_link_dis = cfg_link_dis;
end // latched_cfg_link_dis_PROC

wire                direct_rst;
    assign  direct_rst = (clked_app_init_rst | cfg_reset_assert | (!clked_spif_smlh_req_reset & spif_smlh_req_reset) ) & !cfg_upstream_port;

wire up_rst_deassert;
assign up_rst_deassert       = !(cfg_reset_assert | clked_app_init_rst) & clked_cfg_reset_assert;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_direct_rst          <= #TP 0;
        direct_rst_d                <= #TP 0;
        gointo_rcovr_state_d        <= #TP 0;
    end else begin
        direct_rst_d                <= #TP direct_rst;
        if (direct_rst & !direct_rst_d & smlh_link_up)
            latched_direct_rst      <= #TP 1'b1;
        else if (!direct_rst && (lts_state == S_HOT_RESET_ENTRY || lts_state == S_HOT_RESET))
            latched_direct_rst      <= #TP 1'b0;

        gointo_rcovr_state_d        <= #TP cfg_link_retrain;
    end

assign  retrain_pulse               = !gointo_rcovr_state_d & cfg_link_retrain;

assign  retrain_complete            = latched_link_retrain & (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) & (next_lts_state == S_L0) & !clear;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_link_retrain        <= #TP 1'b0;
    else
        if (retrain_complete || ~latched_rec_cfg_to_l0) // clear on retrain complete
            latched_link_retrain    <= #TP 1'b0;
        else if (retrain_pulse)                         // capture the retrain pulse
            latched_link_retrain    <= #TP 1'b1;
        else                                            // hold current value
            latched_link_retrain    <= #TP latched_link_retrain;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_rec_cfg_to_l0 <= #TP 1'b0;
    else
        if ((lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) & (next_lts_state == S_L0) & !clear) // capture the transition to L0 from Recovery or Configuration
            latched_rec_cfg_to_l0 <= #TP 1'b1;
        else if (lts_state==S_DETECT_QUIET) // clear by linkdown
            latched_rec_cfg_to_l0 <= #TP 1'b0;
        else                                // hold current value
            latched_rec_cfg_to_l0 <= #TP latched_rec_cfg_to_l0;

// smlh_eq_pending is used to block the transmission of DLLPs when Equalization is pending
// If L0 is entered when smlh_eq_pending is HIGH then this becomes a pseudo-L0
// by preventing the assertion of smlh_in_l0. This keeps the rest of the core
// unaware that L0 has been entered and prevents the transmission of DLLPs
assign smlh_eq_pending  = init_eq_pending || auto_eq_phase_flag;
assign smlh_usp_eq_pending  = init_usp_eq_pending;

reg latched_rdlh_rcvd_dllp, latched_only_rdlh_rcvd_dllp;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_rdlh_rcvd_dllp_PROC
    if ( ~core_rst_n ) begin
        latched_rdlh_rcvd_dllp <= #TP 0;
        latched_only_rdlh_rcvd_dllp <= #TP 0;
    end else if ( ~smlh_link_up) begin
        latched_rdlh_rcvd_dllp <= #TP 0;
        latched_only_rdlh_rcvd_dllp <= #TP 0;
    end else begin
        if ( rdlh_rcvd_dllp || vlsm_almp_rx_req) begin // for cxl EP device, the first received is io or mem-cache ALMP requests rather than PCIe's DLLP. used to clear the eq pending
            latched_rdlh_rcvd_dllp <= #TP 1;
        end

        if ( rdlh_rcvd_dllp ) begin
            latched_only_rdlh_rcvd_dllp <= #TP 1; // for cxl.io usp to send dllp after rcvd dllp
        end
    end
end //latched_rdlh_rcvd_dllp_PROC

// for gen5 if no_eq_needed, should not set set_init_eq_pending. When entry to S_CFG_IDLE (clear = 1), equalization_done_8gt_data_rate = 1 && smlh_link_up = 0 if necessary for no_eq_needed
// "|| cfg_ccix_esm_enable" : cfg_ccix_esm_enable to drive ESM auto EQ before ESM LinkUp
assign set_init_eq_pending = ( !smlh_link_up) && gen3_supported && !equalization_done_8gt_data_rate && !cfg_gen3_eq_disable && !cfg_gen3_dllp_xmt_delay_disable && ((lts_state == S_CFG_COMPLETE && next_lts_state == S_CFG_IDLE && ~clear && ~noeq_nd));

// set when (auto_eq_flag is still 1 && gen3_eq done && ~gen4_eq && ramote_ads_rate == Gen4 && local_ads_rate == Gen4 && current_rate == Gen3)
assign set_init_eq_pending_g4 = (auto_eq_phase_flag && !init_eq_pending_g4 && latched_ts_data_rate_ever_eg6[3] && equalization_done_8gt_data_rate && !equalization_done_16gt_data_rate &&
                                (current_data_rate == `GEN3_RATE || (current_data_rate < `GEN3_RATE && skip_eq)) && (cfg_target_link_speed == `GEN4_LINK_SP || cfg_target_link_speed == `GEN5_LINK_SP || cfg_target_link_speed == `GEN6_LINK_SP) && !cfg_gen4_auto_eq_disable && ( (skip_eq && current_data_rate < `GEN3_RATE) ? 1'b1 : eqctl_eq_done_wo_err));

// set when (auto_eq_flag is still 1 && gen4_eq done && ~gen5_eq && ramote_ads_rate == Gen5 && local_ads_rate == Gen5 && current_rate == Gen4)
assign set_init_eq_pending_g5 = (auto_eq_phase_flag && !init_eq_pending_g5 && latched_ts_data_rate_ever[4] && equalization_done_16gt_data_rate && !equalization_done_32gt_data_rate &&
                                (g4_rate || (slr_g4 && skip_eq)) && (cfg_target_link_speed == `GEN5_LINK_SP | cfg_target_link_speed == `GEN6_LINK_SP) && !cfg_gen5_auto_eq_disable && ( (skip_eq && slr_g3) ? 1'b1 : eqctl_eq_done_wo_err)) ; // if no eq perform, eqctl_eq_done_wo_err = 0, so using current_data_rate < `GEN3_RATE for skip_eq

// set when (auto_eq_flag is still 1 && gen5_eq done && ~gen6_eq && ramote_ads_rate == Gen6 && local_ads_rate == Gen6 && current_rate == Gen5)
// eq_skip for gen6 must first reach gen5 rate and then speed up to gen6
assign set_init_eq_pending_g6 = auto_eq_phase_flag && !init_eq_pending_g6 && latched_ts_data_rate_ever_eg6[5] && ~equalization_done_64gt_data_rate && (cfg_target_link_speed == `GEN6_LINK_SP) && !cfg_gen6_auto_eq_disable &&
                                ((g5_rate & eqctl_eq_done_wo_err)); // if no eq perform, eqctl_eq_done_wo_err = 0, so using current_data_rate < `GEN3_RATE for skip_eq. for gen6 always from gen5
//                                (((~equalization_done_32gt_data_rate && skip_eq && current_data_rate < `GEN3_RATE) /*|| (equalization_done_32gt_data_rate && current_data_rate == `GEN5_RATE && skip_eq)*/) ? 1'b1 : (g5_rate & eqctl_eq_done_wo_err)); // if no eq perform, eqctl_eq_done_wo_err = 0, so using current_data_rate < `GEN3_RATE for skip_eq
//                                (current_data_rate == `GEN5_RATE || (current_data_rate < `GEN5_RATE && skip_eq)) && (cfg_target_link_speed == `GEN6_LINK_SP) && !cfg_gen6_auto_eq_disable && ((skip_eq && current_data_rate == `GEN5_RATE) ? 1'b1 : eqctl_eq_done_wo_err)) ; // if no eq perform, eqctl_eq_done_wo_err = 0, so using current_data_rate < `GEN3_RATE for skip_eq

assign set_auto_eq_phase_flag = set_init_eq_pending ; // start to set from gen1/2 -> gen3
// no clear to auto_eq_phase_flag if (auto_eq_redo || gen3_eq_pending || gen4_eq_pending || gen5_eq_pending)
assign clr_auto_eq_phase_flag = (lts_state == S_L0) && !clear && ( (!init_eq_pending && !init_eq_pending_g4 && !init_eq_pending_g5 && !init_eq_pending_g6));

assign auto_eq_phase_flag = auto_eq_phase_flag_ff; // start to set from gen1/2 -> gen3, clear after gen5 eq done

always @(posedge core_clk or negedge core_rst_n)
begin : auto_eq_phase_flag_PROC
    if (!core_rst_n)
        auto_eq_phase_flag_ff <= #TP 1'b0;
    else begin
        if ( eq_pending_clear )
            auto_eq_phase_flag_ff <= # TP 1'b0;
        else if (set_auto_eq_phase_flag) // start to set from gen1/2 -> gen3
            auto_eq_phase_flag_ff <= # TP 1'b1;
        else if (clr_auto_eq_phase_flag || (lts_state == S_LPBK_ACTIVE)) // unset after gen5 eq done, or gen4 eq and/or gen5 eq is not supported by any sides
            auto_eq_phase_flag_ff <= # TP 1'b0;
    end
end

// soft_eq if ~auto_eq_flag for DSP
assign soft_eq_phase_flag_nomask = !cfg_upstream_port && !cfg_gen3_eq_disable && !auto_eq_phase_flag ;
// There are two conditions for asserting soft_eq_phase_flag.
// #1 : (S_L0 or S_L1_IDLE)_TO_(S_RCVRY_LOCK) : Initiating Speed Change to Gen3 or Gen4 and this is the first time to become Gen3 or Gen4.
// #2 : (S_RCVRY_LOCK) : The remote port is requesting Speed Change to Gen3 or Gen4 in this state and this is the first time to become Gen3 or Gen4.
// DSP catch the data rate in S_RCVRY_LOCK so that DSP can advertise TS2 with Gen3 rate in S_RCVRY_RCVRCFG. Then both sides can speed up to Gen3.
// spec says: The Downstream Port subsequently initiates the equalization procedure during the initial speed change to the data rate advertised by the Upstream Port when it transitions to Recovery.
// here we need ltssm_ts_data_rate[2]/[3]/[4] to confirm software wants Gen3/4/5 Speed Up, i.e. if ltssm_ts_data_rate[2]/[3]/[4] = 0, set_soft_eq_phase_flag cannot be true.
// if DSP advertises Gen4/5 and if soft_eq_phase_flag_nomask is true, DSP will advertise Gen3 in S_RCVRY_RCVRCFG after receiving Gen3 rate advertised by USP.
//
// If S_L1_DILE -> S_RCVRY_LOCK uses next_lts_state, latched_target_link_speed may not get updated to cfg_target_link_speed because core_clk is off in S_L1_DILE.
// So use last_lts_state and lts_state instead for S_L1_DILE -> S_RCVRY_LOCK.
//
wire [9:0] link_any_8_ts_spd_chg_1_data_rate_eg6 = link_any_8_ts_spd_chg_1_data_rate == 5'b10111 ? 10'b0000111111 : {5'h0, link_any_8_ts_spd_chg_1_data_rate};
assign set_soft_eq_phase_flag = ( (((lts_state == S_L0 || lts_state == S_L0S) && next_lts_state == S_RCVRY_LOCK && !clear) || (last_lts_state == S_L1_IDLE && lts_state == S_RCVRY_LOCK && clear)) &&
                                  ( go_recovery_speed_change || latched_link_retrain_bit && latched_ts_data_rate_ever[1] ) &&
                                  ( ( !equalization_done_8gt_data_rate && (latched_target_link_speed == `GEN3_LINK_SP || latched_target_link_speed == `GEN4_LINK_SP
 || latched_target_link_speed == `GEN5_LINK_SP || latched_target_link_speed == `GEN6_LINK_SP) )
 || ( !equalization_done_16gt_data_rate && (latched_target_link_speed ==                                     `GEN4_LINK_SP
 || latched_target_link_speed == `GEN5_LINK_SP || latched_target_link_speed == `GEN6_LINK_SP) ) ) ) ||  // #1 condition
                                ( (lts_state == S_RCVRY_LOCK) && ~clear &&
                                  (((link_any_8_ts_spd_chg_1_data_rate_eg6[2] && ltssm_ts_data_rate_eg6[2]) && !equalization_done_8gt_data_rate) ||
                                   ((link_any_8_ts_spd_chg_1_data_rate_eg6[3] && ltssm_ts_data_rate_eg6[3]) && !equalization_done_16gt_data_rate))
                                ); // #2 condition
// if local target_link_speed < gen4, need to clear too
assign clr_soft_eq_phase_flag = (!latched_remote_soft_eq_g4 || latched_target_link_speed < `GEN4_LINK_SP) && (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear;
assign soft_eq_phase_flag = (soft_eq_phase_flag_nomask & set_soft_eq_phase_flag) | soft_eq_phase_flag_ff;

always @(posedge core_clk or negedge core_rst_n)
begin : soft_eq_phase_flag_PROC
    if (!core_rst_n)
        soft_eq_phase_flag_ff <= #TP 1'b0;
    else if( soft_eq_phase_flag_nomask ) begin
        if ( set_soft_eq_phase_flag ) // to advertise Gen3 rate from current Gen1/2 rate, advertise Gen4 rate using latched_target_link_speed for GEN4 configs. For Gen5 configs, use set_soft_gen4_eq_phase_flag
            soft_eq_phase_flag_ff <= #TP 1'b1;
        else if( clr_soft_eq_phase_flag ) // clear after gen3 or gen4 eq done
            soft_eq_phase_flag_ff <= #TP 1'b0;
    end
    else begin
        soft_eq_phase_flag_ff <= #TP 1'b0;
    end
end

// build soft_gen4_eq_phase_flag for the core to set ltssm_ts_data_rate == `GEN5_LINK_SP for the first time to be Gen5 rates
// 1. (L0 || L1_IDLE) -> S_RCVRY_LOCK: the core initiates to Recovery and gen5 eq not done and the core advertises gen5 speed
// 2. In S_RCVRY_LOCK: the receives speed_change bit with Gen5 data_rate && gen5 eq not done
assign set_soft_gen4_eq_phase_flag = ( (((lts_state == S_L0 || lts_state == S_L0S)  && next_lts_state == S_RCVRY_LOCK && !clear) || (last_lts_state == S_L1_IDLE && lts_state == S_RCVRY_LOCK && clear)) &&
                                       (go_recovery_speed_change || latched_link_retrain_bit && latched_ts_data_rate_ever[1]) &&
                                       (!equalization_done_32gt_data_rate && (latched_target_link_speed == `GEN5_LINK_SP || latched_target_link_speed == `GEN6_LINK_SP)) ) ||  // #1 condition
                                     ( (lts_state == S_RCVRY_LOCK) && ~clear &&
                                        ((link_any_8_ts_spd_chg_1_data_rate[4] && ltssm_ts_data_rate[4]) && !equalization_done_32gt_data_rate) ) ;  // #2 condition

// clear soft_gen4_eq_phase_flag at current_data_rate == Gen4/5 && entering L0
// 1. if remote does not want gen5, clear it at current gen4 rate
// 2. if remote wants gen5, clear at gen5 current rate
assign clr_soft_gen4_eq_phase_flag = !(latched_remote_soft_eq_g5 | latched_remote_soft_eq_g4) && (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear /*&& (current_data_rate == `GEN4_RATE)*/;
assign soft_gen4_eq_phase_flag = (soft_eq_phase_flag_nomask & set_soft_gen4_eq_phase_flag) | soft_gen4_eq_phase_flag_ff ;

always @(posedge core_clk or negedge core_rst_n) begin : soft_gen4_eq_phase_flag_PROC
    if (!core_rst_n) begin
        soft_gen4_eq_phase_flag_ff <= #TP 1'b0;
    end else if( soft_eq_phase_flag_nomask ) begin
        if ( set_soft_gen4_eq_phase_flag )
            soft_gen4_eq_phase_flag_ff <= #TP 1'b1;
        else if( clr_soft_gen4_eq_phase_flag )
            soft_gen4_eq_phase_flag_ff <= #TP 1'b0;
    end
    else begin
        soft_gen4_eq_phase_flag_ff <= #TP 1'b0;
    end
end // soft_gen4_eq_phase_flag_PROC

// build soft_gen4_eq_phase_flag for the core to set ltssm_ts_data_rate == `GEN6_LINK_SP for the first time to be Gen6 rates
// 1. (L0 || L1_IDLE) -> S_RCVRY_LOCK: the core initiates to Recovery and gen6 eq not done and the core advertises gen6 speed
// 2. In S_RCVRY_LOCK: the receives speed_change bit with Gen6 data_rate && gen6 eq not done
assign set_soft_gen5_eq_phase_flag = ( (((lts_state == S_L0 || lts_state == S_L0S)  && next_lts_state == S_RCVRY_LOCK && !clear) || (last_lts_state == S_L1_IDLE && lts_state == S_RCVRY_LOCK && clear)) &&
                                       (go_recovery_speed_change || latched_link_retrain_bit && latched_ts_data_rate_ever[1]) &&
                                       (!equalization_done_64gt_data_rate && latched_target_link_speed == `GEN6_LINK_SP) ) ||  // #1 condition
                                     ( (lts_state == S_RCVRY_LOCK) && ~clear &&
                                        ((link_any_8_ts_spd_chg_1_data_rate_eg6[5] && ltssm_ts_data_rate_eg6[5]) && !equalization_done_64gt_data_rate) ) ;  // #2 condition

// clear soft_gen5_eq_phase_flag at current_data_rate == Gen4/5/6 && entering L0
// 1. if remote does not want gen6, clear it at current gen5 rate
// 2. if remote wants gen6, clear at gen6 current rate
assign clr_soft_gen5_eq_phase_flag = !(latched_remote_soft_eq_g6 | latched_remote_soft_eq_g5 | latched_remote_soft_eq_g4) && (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear /*&& (current_data_rate == `GEN5_RATE)*/;
assign soft_gen5_eq_phase_flag = (soft_eq_phase_flag_nomask & set_soft_gen5_eq_phase_flag) | soft_gen5_eq_phase_flag_ff ;

always @(posedge core_clk or negedge core_rst_n) begin : soft_gen5_eq_phase_flag_PROC
    if (!core_rst_n) begin
        soft_gen5_eq_phase_flag_ff <= #TP 1'b0;
    end else if( soft_eq_phase_flag_nomask ) begin
        if ( set_soft_gen5_eq_phase_flag )
            soft_gen5_eq_phase_flag_ff <= #TP 1'b1;
        else if( clr_soft_gen5_eq_phase_flag )
            soft_gen5_eq_phase_flag_ff <= #TP 1'b0;
    end
    else begin
        soft_gen5_eq_phase_flag_ff <= #TP 1'b0;
    end
end // soft_gen5_eq_phase_flag_PROC

assign redo_eq_phase_flag = redo_eq_phase_g3 || redo_eq_phase_g4 || redo_eq_phase_g5 || redo_eq_phase_g6;
// Use with the ltssm_cmd_8geqts and ltssm_cmd_16geqts when LTSSM is in only RCVRY_RCVRCFG state.
assign redo_eq_phase_flag_ff = redo_eq_phase_g3_ff || redo_eq_phase_g4_ff || redo_eq_phase_g5_ff || redo_eq_phase_g6_ff;

assign set_redo_eq_phase_g3 = 
                                ~redo_eq_phase_g3_ff && ~redo_eq_phase_g4_ff && ~redo_eq_phase_g5_ff && ~redo_eq_phase_g6_ff &&
                                perform_link_retrain &&
                                ( latched_target_link_speed == `GEN3_LINK_SP ) &&
                                latched_perform_eq && 
                                equalization_done_8gt_data_rate ;

assign clr_redo_eq_phase_g3 = 
                                ( redo_eq_phase_step_ff[0] && (g3_rate | g1_rate) ) ? 0 :
                                (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear ;

always @(posedge core_clk or negedge core_rst_n)
begin : redo_eq_phase_g3_PROC
    if (!core_rst_n)
        redo_eq_phase_g3_ff <= #TP 1'b0;
    else begin
        if ( set_redo_eq_phase_g3 )
            redo_eq_phase_g3_ff <= #TP 1'b1;
        else if( clr_redo_eq_phase_g3 )
            redo_eq_phase_g3_ff <= #TP 1'b0;
    end
end

assign redo_eq_phase_g3 = set_redo_eq_phase_g3 || redo_eq_phase_g3_ff ;

assign set_redo_eq_phase_g4 = 
                                ~redo_eq_phase_g3_ff && ~redo_eq_phase_g4_ff && ~redo_eq_phase_g5_ff && ~redo_eq_phase_g6_ff &&
                                perform_link_retrain &&
                                ( latched_target_link_speed == `GEN4_LINK_SP ) &&
                                latched_perform_eq && 
                                equalization_done_16gt_data_rate ;

assign clr_redo_eq_phase_g4 = 
                                ( redo_eq_phase_step_ff[0] && (g3_rate) ) ? 0 :
                                (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear ;

always @(posedge core_clk or negedge core_rst_n)
begin : redo_eq_phase_g4_PROC
    if (!core_rst_n)
        redo_eq_phase_g4_ff <= #TP 1'b0;
    else begin
        if ( set_redo_eq_phase_g4 )
            redo_eq_phase_g4_ff <= #TP 1'b1;
        else if( clr_redo_eq_phase_g4 )
            redo_eq_phase_g4_ff <= #TP 1'b0;
    end
end

assign redo_eq_phase_g4 = set_redo_eq_phase_g4 || redo_eq_phase_g4_ff ;

assign set_redo_eq_phase_g5 =
                                ~redo_eq_phase_g3_ff && ~redo_eq_phase_g4_ff && ~redo_eq_phase_g5_ff &&
                                perform_link_retrain &&
                                ( latched_target_link_speed == `GEN5_LINK_SP ) &&
                                latched_perform_eq &&
                                equalization_done_32gt_data_rate ;

assign clr_redo_eq_phase_g5 =
                                ( redo_eq_phase_step_ff[0] && (g1_rate || g3_rate || g4_rate) ) ? 0 :
                                (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear ;

always @(posedge core_clk or negedge core_rst_n)
begin : redo_eq_phase_g5_PROC
    if (!core_rst_n)
        redo_eq_phase_g5_ff <= #TP 1'b0;
    else begin
        if ( set_redo_eq_phase_g5 )
            redo_eq_phase_g5_ff <= #TP 1'b1;
        else if( clr_redo_eq_phase_g5 )
            redo_eq_phase_g5_ff <= #TP 1'b0;
    end
end

assign redo_eq_phase_g5 = set_redo_eq_phase_g5 || redo_eq_phase_g5_ff ;

assign set_redo_eq_phase_g6 =
                                ~redo_eq_phase_g3_ff && ~redo_eq_phase_g4_ff && ~redo_eq_phase_g5_ff && ~redo_eq_phase_g6_ff &&
                                perform_link_retrain &&
                                ( latched_target_link_speed == `GEN6_LINK_SP ) &&
                                latched_perform_eq &&
                                equalization_done_64gt_data_rate ;

assign clr_redo_eq_phase_g6 =
                                ( redo_eq_phase_step_ff[0] && (goe_g3 && soe_g5) ) ? 0 :
                                (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear ;

always @(posedge core_clk or negedge core_rst_n)
begin : redo_eq_phase_g6_PROC
    if (!core_rst_n)
        redo_eq_phase_g6_ff <= #TP 1'b0;
    else begin
        if ( set_redo_eq_phase_g6 )
            redo_eq_phase_g6_ff <= #TP 1'b1;
        else if( clr_redo_eq_phase_g6 )
            redo_eq_phase_g6_ff <= #TP 1'b0;
    end
end

assign redo_eq_phase_g6 = set_redo_eq_phase_g6 || redo_eq_phase_g6_ff ;

// g5_2_do : must revisit for Gen5 for logic after the line. re-chg on 12Sep2018
assign set_redo_eq_phase_step0 = 
                                ( set_redo_eq_phase_g3 &&
                                  ( g4_rate || g5_rate || goe_g6) ) || // cfg_perform_eq for g3 from higher rate g4/5, so advertise g3 rate
                                // skip_eq is handled in equalization_done_32gt_data_rate
                                ( set_redo_eq_phase_g5 && 
                                ((~skip_eq && soe_g3) || goe_g6) ) ||          // At current rate==Gen6, if skip_eq==1 then change speed to Gen1 else change speed to Gen4 for redo eq@Gen5                                                                                          // cfg_perform_eq for g5 from g1/2/3, so advertise g4 rate
                                // skip_eq is handled in equalization_done_64gt_data_rate
                                ( set_redo_eq_phase_g6  &&
                                  (current_data_rate != `GEN5_RATE) ) ||                                                                                                    // cfg_perform_eq for g6 from g1/2/3, so advertise g5 rate
                                ( set_redo_eq_phase_g4 &&
                                  ( g1_rate || g2_rate || ( ~skip_eq && (g5_rate || goe_g6 ))) ) ;                                                                // cfg_perform_eq for g4 from g1/2, so advertise g3 rate
assign set_redo_eq_phase_step1 = 
                                ( set_redo_eq_phase_g3 &&
                                  ( ~g4_rate && ~g5_rate && current_data_rate != `GEN6_RATE) ) || // cfg_perform_eq for g3 from g1/2/3, so advertise g3 rate
                                ( set_redo_eq_phase_g4 &&
                                  ( g3_rate || g4_rate || g5_rate || current_data_rate >= `GEN6_RATE) ) || // cfg_perform_eq for g4 from g3/4/5, so advertise g4 rate
                                ( set_redo_eq_phase_g5 &&
                                  ( g4_rate || g5_rate ||(slr_g3 && skip_eq)) ) ||                                                               // cfg_perform_eq for g5 from g4/5, so advertise g5 rate
                                ( set_redo_eq_phase_g6 &&
                                  ( current_data_rate == `GEN5_RATE ) ) ||                                                               // cfg_perform_eq for g5 from g4/5, so advertise g5 rate
                                ( redo_eq_phase_g3 &&
                                  (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear &&
                                  redo_eq_phase_step_ff[0] && (g3_rate | g1_rate) ) ||                                                                        // redo_eq_phase_g3 & redo_eq_phase_step0 from g4/5, then redo_eq_phase_g3 from g3, advertise g3 rate
                                ( redo_eq_phase_g5 &&
                                  (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear &&
                                  redo_eq_phase_step_ff[0] && (g4_rate | g1_rate) ) ||                                                                        // redo_eq_phase_g5 & redo_eq_phase_step0 from g1/2/3, then redo_eq_phase_g5 from g4, advertise g5 rate
                                ( redo_eq_phase_g6 &&
                                  (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear &&
                                  redo_eq_phase_step_ff[0] && (g5_rate) ) ||                                                                        // redo_eq_phase_g5 & redo_eq_phase_step0 from g1/2/3, then redo_eq_phase_g5 from g4, advertise g5 rate
                                ( redo_eq_phase_g4 &&
                                  (next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear &&                                                                      // redo_eq_phase_g4 & redo_eq_phase_step0 from g1/2, then redo_eq_phase_g4 from g3, advertise g4 rate
                                  redo_eq_phase_step_ff[0] && (g3_rate) ) 
                              ;

assign redo_eq_phase_step = 
                            ~redo_eq_phase_flag ? 2'b00 :
                            set_redo_eq_phase_step0 ? 2'b01 :
                            set_redo_eq_phase_step1 ? 2'b10 :
                            ((next_lts_state == S_L0) && (lts_state == S_RCVRY_IDLE) && !clear) ? 2'b00 :
                            redo_eq_phase_step_ff ;

always @(posedge core_clk or negedge core_rst_n)
begin : redo_eq_phase_step_PROC
    if (!core_rst_n)
        redo_eq_phase_step_ff[1:0] <= #TP 0;
    else
        redo_eq_phase_step_ff[1:0] <= #TP redo_eq_phase_step;
end


assign redo_eq_target_rate = (redo_eq_phase_g3 && redo_eq_phase_step[0]) ? `GEN1_RATE :
                             (redo_eq_phase_g3 && redo_eq_phase_step[1]) ? `GEN3_RATE :
                             (redo_eq_phase_g4 && redo_eq_phase_step[0]) ? `GEN3_RATE :
                             (redo_eq_phase_g4 && redo_eq_phase_step[1]) ? `GEN4_RATE :
                             (redo_eq_phase_g5 && redo_eq_phase_step[0]) ? (skip_eq ? `GEN1_RATE: `GEN4_RATE) :
                             (redo_eq_phase_g5 && redo_eq_phase_step[1]) ? `GEN5_RATE :
                             (redo_eq_phase_g6 && redo_eq_phase_step[0]) ? `GEN5_RATE :
                             (redo_eq_phase_g6 && redo_eq_phase_step[1]) ? `GEN6_RATE :
                                                                           `GEN1_RATE ;

assign redo_eq_target_link_speed = (redo_eq_phase_g3 && redo_eq_phase_step[0]) ? `GEN1_LINK_SP :
                                   (redo_eq_phase_g3 && redo_eq_phase_step[1]) ? `GEN3_LINK_SP :
                                   (redo_eq_phase_g4 && redo_eq_phase_step[0]) ? `GEN3_LINK_SP :
                                   (redo_eq_phase_g4 && redo_eq_phase_step[1]) ? `GEN4_LINK_SP :
                                   (redo_eq_phase_g5 && redo_eq_phase_step[0]) ? (skip_eq ? `GEN1_LINK_SP : `GEN4_LINK_SP) :
                                   (redo_eq_phase_g5 && redo_eq_phase_step[1]) ? `GEN5_LINK_SP :
                                   (redo_eq_phase_g6 && redo_eq_phase_step[0]) ? `GEN5_LINK_SP :
                                   (redo_eq_phase_g6 && redo_eq_phase_step[1]) ? `GEN6_LINK_SP :
                                                                                 `GEN1_LINK_SP ;
// Use with the ltssm_cmd_8geqts and ltssm_cmd_16geqts
assign redo_eq_target_rate_ff = (redo_eq_phase_g3_ff && redo_eq_phase_step_ff[0]) ? `GEN1_RATE :
                                (redo_eq_phase_g3_ff && redo_eq_phase_step_ff[1]) ? `GEN3_RATE :
                                (redo_eq_phase_g4_ff && redo_eq_phase_step_ff[0]) ? `GEN3_RATE :
                                (redo_eq_phase_g4_ff && redo_eq_phase_step_ff[1]) ? `GEN4_RATE :
                                (redo_eq_phase_g5_ff && redo_eq_phase_step_ff[0]) ? (skip_eq ? `GEN1_RATE: `GEN4_RATE) :
                                (redo_eq_phase_g5_ff && redo_eq_phase_step_ff[1]) ? `GEN5_RATE :
                                (redo_eq_phase_g6_ff && redo_eq_phase_step_ff[0]) ? `GEN5_RATE :
                                (redo_eq_phase_g6_ff && redo_eq_phase_step_ff[1]) ? `GEN6_RATE :
                                                                                    `GEN1_RATE ;

// g5_2_do: must revisit for Gen5 for logic above the line. re-chg on 12Sep2018


// Initial Equalization Pending. Used prior to initial equalization to delay the
// transmission of DLLPs until after equalization has completed.
always @(posedge core_clk or negedge core_rst_n)
begin : init_eq_PROC
    if (!core_rst_n) begin
        init_eq_pending     <= #TP 1'b0;
        init_usp_eq_pending <= #TP 1'b0;
    end else begin
       //cfg_gen3_eq_disable - software disables EQ;
        if (set_init_eq_pending)
            init_eq_pending <= # TP 1'b1;
        else if (eq_pending_clear || ~gen3_supported || (!cfg_upstream_port && equalization_done_8gt_data_rate) || ((latched_rdlh_rcvd_dllp) && cfg_upstream_port))
            init_eq_pending <= # TP 1'b0;

        if (set_init_eq_pending && cfg_upstream_port)
            init_usp_eq_pending <= # TP 1'b1;
        else if (eq_pending_clear || ~gen3_supported || ((latched_only_rdlh_rcvd_dllp) && cfg_upstream_port))
            init_usp_eq_pending <= # TP 1'b0;
    end
end

assign smlh_auto_eq_dllp_blocking = init_eq_pending | init_eq_pending_g4 | init_eq_pending_g5 | init_eq_pending_g6;

// Initial Equalization Pending for gen4. This signal is only for downstream_port
always @(posedge core_clk or negedge core_rst_n)
begin : init_eq_pending_g4_PROC
    if (!core_rst_n)
        init_eq_pending_g4  <= #TP 1'b0;
    else if ( eq_pending_clear )
        init_eq_pending_g4  <= #TP 1'b0;
    else if(!cfg_upstream_port) begin
        if (set_init_eq_pending_g4)
            init_eq_pending_g4 <= # TP 1'b1;
        else if (equalization_done_16gt_data_rate ||
                 ((last_lts_state == S_RCVRY_IDLE) && (lts_state == S_L0) && clear) ) // for speed change fail condition
            init_eq_pending_g4 <= # TP 1'b0;
    end
    else begin
        init_eq_pending_g4  <= #TP 1'b0;
    end
end

assign set_latched_remote_soft_eq_g4 = soft_eq_phase_flag_ff && (lts_state == S_RCVRY_RCVRCFG) && (next_lts_state == S_RCVRY_IDLE) && !clear &&
                                       (current_data_rate == `GEN3_RATE) && latched_ts_data_rate_eg6[3] && ltssm_ts_data_rate_eg6[3] && // update latched_ts_data_rate at current cycle
                                       equalization_done_8gt_data_rate && !equalization_done_16gt_data_rate;

assign clr_latched_remote_soft_eq_g4 = (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)||(lts_state == S_L0S)) && !clear;

always @(posedge core_clk or negedge core_rst_n)
begin : latched_remote_soft_eq_g4_PROC
    if (!core_rst_n)
        latched_remote_soft_eq_g4      <= #TP 1'b0;
    else begin
        if ( set_latched_remote_soft_eq_g4 )
            latched_remote_soft_eq_g4  <= #TP 1'b1;
        else if (clr_latched_remote_soft_eq_g4)
            latched_remote_soft_eq_g4  <= #TP 1'b0;
        else
            latched_remote_soft_eq_g4  <= #TP latched_remote_soft_eq_g4;
    end
end


// Initial Equalization Pending for gen5. This signal is only for downstream_port
always @(posedge core_clk or negedge core_rst_n)
begin : init_eq_pending_g5_PROC
    if (!core_rst_n)
        init_eq_pending_g5  <= #TP 1'b0;
    else if ( eq_pending_clear )
        init_eq_pending_g5  <= #TP 1'b0;
    else if(!cfg_upstream_port) begin
        if (set_init_eq_pending_g5)
            init_eq_pending_g5 <= # TP 1'b1;
        else if (equalization_done_32gt_data_rate ||
                 ((last_lts_state == S_RCVRY_IDLE) && (lts_state == S_L0) && clear) ) // for speed change fail condition
            init_eq_pending_g5 <= # TP 1'b0;
    end
    else begin
        init_eq_pending_g5  <= #TP 1'b0;
    end
end

// DSP gen5 soft eq and the remote partner agrees (latched_ts_data_rate supported), go ahead for gen5 soft eq from current Gen4 rate.
// this is the logic with "equalization_done_16gt_data_rate && !equalization_done_32gt_data_rate" after gen4 eq done and soft_gen4_eq_phase_flag_ff high
assign set_latched_remote_soft_eq_g5 = soft_gen4_eq_phase_flag_ff && (lts_state == S_RCVRY_RCVRCFG) && (next_lts_state == S_RCVRY_IDLE) && !clear && (
                                       ((g4_rate) && latched_ts_data_rate[4] && ltssm_ts_data_rate[4] && // update latched_ts_data_rate at current cycle to Gen5
                                       equalization_done_16gt_data_rate && !equalization_done_32gt_data_rate)
                                       );

assign clr_latched_remote_soft_eq_g5 = clr_latched_remote_soft_eq_g4; // clear at the (L0 || S_L1_IDLE) -> S_RCVRY_LOCK for current gen4 rate

always @(posedge core_clk or negedge core_rst_n)
begin : latched_remote_soft_eq_g5_PROC
    if (!core_rst_n)
        latched_remote_soft_eq_g5      <= #TP 1'b0;
    else begin
        if ( set_latched_remote_soft_eq_g5 )
            latched_remote_soft_eq_g5  <= #TP 1'b1;
        else if (clr_latched_remote_soft_eq_g5)
            latched_remote_soft_eq_g5  <= #TP 1'b0;
        else
            latched_remote_soft_eq_g5  <= #TP latched_remote_soft_eq_g5;
    end
end


// Initial Equalization Pending for gen6. This signal is only for downstream_port
always @(posedge core_clk or negedge core_rst_n)
begin : init_eq_pending_g6_PROC
    if (!core_rst_n)
        init_eq_pending_g6  <= #TP 1'b0;
    else if ( eq_pending_clear )
        init_eq_pending_g6  <= #TP 1'b0;
    else if(!cfg_upstream_port) begin
        if (set_init_eq_pending_g6)
            init_eq_pending_g6 <= # TP 1'b1;
        else if (equalization_done_64gt_data_rate ||
                 ((last_lts_state == S_RCVRY_IDLE) && (lts_state == S_L0) && clear) ) // for speed change fail condition
            init_eq_pending_g6 <= # TP 1'b0;
    end
    else begin
        init_eq_pending_g6  <= #TP 1'b0;
    end
end

// DSP gen6 soft eq and the remote partner agrees (latched_ts_data_rate supported), go ahead for gen6 soft eq from current Gen5 rate.
// this is the logic with "equalization_done_32gt_data_rate && !equalization_done_64gt_data_rate" after gen4 eq done and soft_gen5_eq_phase_flag_ff high
assign set_latched_remote_soft_eq_g6 = soft_gen5_eq_phase_flag_ff && (lts_state == S_RCVRY_RCVRCFG) && (next_lts_state == S_RCVRY_IDLE) && !clear && (
                                       ((g5_rate) && latched_ts_data_rate_eg6[5] && ltssm_ts_data_rate_eg6[5] && // update latched_ts_data_rate at current cycle to Gen5
                                       equalization_done_32gt_data_rate && !equalization_done_64gt_data_rate)
                                       );

assign clr_latched_remote_soft_eq_g6 = clr_latched_remote_soft_eq_g5; // clear at the (L0 || S_L1_IDLE) -> S_RCVRY_LOCK for current gen5 rate

always @(posedge core_clk or negedge core_rst_n)
begin : latched_remote_soft_eq_g6_PROC
    if (!core_rst_n)
        latched_remote_soft_eq_g6      <= #TP 1'b0;
    else begin
        if ( set_latched_remote_soft_eq_g6 )
            latched_remote_soft_eq_g6  <= #TP 1'b1;
        else if (clr_latched_remote_soft_eq_g6)
            latched_remote_soft_eq_g6  <= #TP 1'b0;
        else
            latched_remote_soft_eq_g6  <= #TP latched_remote_soft_eq_g6;
    end
end

//Cfg.Idle or Rcvry.Idle to Rcvry.Lock
always @(posedge core_clk or negedge core_rst_n) begin : latched_idle_rcvrylock_PROC
    if (!core_rst_n)
        latched_idle_to_rcvrylock <=  #TP 0;
    else begin
        if ( (lts_state == S_RCVRY_IDLE || lts_state == S_CFG_IDLE) && (next_lts_state == S_RCVRY_LOCK) && !clear )
            latched_idle_to_rcvrylock <=  #TP 1;
        else if ( lts_state == S_RCVRY_LOCK && next_lts_state != S_RCVRY_LOCK && !clear)
            latched_idle_to_rcvrylock <=  #TP 0;
    end
end

//ts1_sent count in Rcvry.Lock
always @(posedge core_clk or negedge core_rst_n) begin : rlock_ts1_cnt_PROC
    if (!core_rst_n)
        rlock_ts1_cnt <=  #TP 0;
    else begin
        if ( lts_state == S_RCVRY_LOCK )
            if ( xmtbyte_ts1_sent[0] && (rlock_ts1_cnt < 3) )
                rlock_ts1_cnt <=  #TP rlock_ts1_cnt + 1;
            else
                rlock_ts1_cnt <=  #TP rlock_ts1_cnt;
        else
            rlock_ts1_cnt <=  #TP 0;
    end
end

reg                 latched_rec_to_cfg;  // Indicates that this Configuration State is from Recovery State
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        latched_rec_to_cfg <= #TP 0;
    else if( (lts_state_d == S_RCVRY_IDLE || lts_state_d == S_RCVRY_LOCK || lts_state_d == S_RCVRY_RCVRCFG) & (lts_state == S_CFG_LINKWD_START) )
        latched_rec_to_cfg <= #TP 1'b1;
    else if( lts_state == S_CFG_LINKWD_START || lts_state == S_CFG_LINKWD_ACEPT || lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_CFG_COMPLETE )
        latched_rec_to_cfg <= #TP latched_rec_to_cfg;
    else
        latched_rec_to_cfg <= #TP 0;

always @(posedge core_clk or negedge core_rst_n) begin : current_data_rate_d_PROC
    if ( ~core_rst_n )
        current_data_rate_d <= #TP 0;
    else
        current_data_rate_d <= #TP current_data_rate;
end //always

always @(posedge core_clk or negedge core_rst_n) begin : latched_rate_change_PROC
    if ( ~core_rst_n )
        latched_rate_change <= #TP 0;
    else if(clear)
        latched_rate_change <= #TP 0;
    else if(current_data_rate_d != current_data_rate)
        latched_rate_change <= #TP 1'b1;
end //always

always @(posedge core_clk or negedge core_rst_n) begin : latched_g3_auto_bw_status_PROC
    if ( ~core_rst_n )
        latched_g3_auto_bw_status <= #TP 0;
    else if(auto_eq_phase_flag_ff || soft_eq_phase_flag_ff) begin
        if( smlh_link_auto_bw_status_w && g3_rate)
            latched_g3_auto_bw_status <= #TP 1'b1;
    end
    else
        latched_g3_auto_bw_status <= #TP 0;
end

assign g4_continuous_auto_bw = latched_g3_auto_bw_status && (g4_rate) && smlh_successful_spd_negotiation;

always @(posedge core_clk or negedge core_rst_n) begin : latched_g4_auto_bw_status_PROC
    if ( ~core_rst_n )
        latched_g4_auto_bw_status <= #TP 0;
    else if(auto_eq_phase_flag_ff || soft_gen4_eq_phase_flag_ff) begin
        if( smlh_link_auto_bw_status_w && g4_rate)
            latched_g4_auto_bw_status <= #TP 1'b1;
    end
    else
        latched_g4_auto_bw_status <= #TP 0;
end

assign g5_continuous_auto_bw = latched_g4_auto_bw_status && (g5_rate) && smlh_successful_spd_negotiation;

always @(posedge core_clk or negedge core_rst_n) begin : latched_g5_auto_bw_status_PROC
    if ( ~core_rst_n )
        latched_g5_auto_bw_status <= #TP 0;
    else if(auto_eq_phase_flag_ff || soft_gen4_eq_phase_flag_ff) begin
        if( smlh_link_auto_bw_status_w && g5_rate)
            latched_g5_auto_bw_status <= #TP 1'b1;
    end
    else
        latched_g5_auto_bw_status <= #TP 0;
end

assign g6_continuous_auto_bw = latched_g5_auto_bw_status && (g6_rate) && smlh_successful_spd_negotiation;

// This is to take care of the different change timing of ltssm and data rate.
assign latched_rate_change_or = latched_rate_change || (current_data_rate_d != current_data_rate);

// pulse
assign  smlh_bw_mgt_status_w         = (  (retrain_complete && !cfg_upstream_port)
                                      || ( (lts_state == S_RCVRY_SPEED) && (next_lts_state != S_RCVRY_SPEED) && !clear && latched_rate_change_or && 
                                           !(smlh_successful_spd_negotiation && rcvd_ts_auto_change) && !directed_speed_change_r && !g4_continuous_auto_bw && !g5_continuous_auto_bw && !g6_continuous_auto_bw)
                                      || ( latched_rec_to_cfg && (lts_state_d != S_CFG_COMPLETE) && (lts_state == S_CFG_COMPLETE) && (smlh_link_mode != latest_link_mode) &&
                                           ((!rcvd_ts_auto_change && !directed_link_width_change_updown) || latched_valid_reliability_link_width_change) )
                                    );

assign  smlh_link_auto_bw_status_w   = ( 1'b0
                                      || ( (lts_state == S_RCVRY_SPEED) && (next_lts_state != S_RCVRY_SPEED) && !clear && latched_rate_change_or &&
                                           ( (smlh_successful_spd_negotiation && rcvd_ts_auto_change) || // autonomous speed change by remote port
                                             g4_continuous_auto_bw || // continous speed change g12->g3->g4. At g4, set the same value in g3
                                             g5_continuous_auto_bw || // continous speed change g12->g3->g4. At g4, set the same value in g3
                                             g6_continuous_auto_bw || // continous speed change g12->g3->g4. At g4, set the same value in g3
                                             directed_speed_change_r ) ) // autonomous speed change by my port
                                      || ( latched_rec_to_cfg && (lts_state_d != S_CFG_COMPLETE) && (lts_state == S_CFG_COMPLETE) && (smlh_link_mode != latest_link_mode) &&
                                           ((rcvd_ts_auto_change || directed_link_width_change_updown) && !latched_valid_reliability_link_width_change) )
                                    );

    // PIPE-line for syntheis optimization. Gen6 only currently for customer, but will apply all rate in the future.
    always @( posedge core_clk or negedge core_rst_n ) begin : latched_bw_mgt_aut_bw_status_PROC
        if ( ~core_rst_n ) begin
           smlh_bw_mgt_status         <= #TP '0 ;  
           smlh_link_auto_bw_status   <= #TP '0 ;  
        end
        else begin
           smlh_bw_mgt_status         <= #TP smlh_bw_mgt_status_w ;  
           smlh_link_auto_bw_status   <= #TP smlh_link_auto_bw_status_w ;  
        end
    end

// This signal tells the CDM to reset the Transmit Margin field (bits 10:8) in the "Link Control 2 Register" to 3'b0
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_tx_margin_rst          <= #TP 1'b0;
    else
        smlh_tx_margin_rst          <= #TP ( (lts_state != S_POLL_CONFIG) && (next_lts_state == S_POLL_CONFIG) && !clear );

// sample the "Transmit Margin" field in the Link Control 2 Register and output on package pins
wire   l0_recovery;
wire   l0s_recovery;
wire   l1_recovery;
wire   poll_compliance_entry;
wire   rcvry_lock_entry;
reg    latched_first_entry_rcvry_lock;
assign l0_recovery           = ((lts_state == S_L0)              && (next_lts_state == S_RCVRY_LOCK) && !clear);
assign l0s_recovery          = ((lts_state == S_L0S)             && (next_lts_state == S_RCVRY_LOCK) && !clear);
assign l1_recovery           = ((lts_state == S_L1_IDLE)         && (next_lts_state == S_RCVRY_LOCK) && !clear);
assign poll_compliance_entry = ((lts_state != S_POLL_COMPLIANCE) && (next_lts_state == S_POLL_COMPLIANCE) && !clear);
// for hold ltssm to transmit eieos in Recovery.RcvrLock
assign rcvry_lock_entry      = (lts_state != S_RCVRY_LOCK) && 
                               ((next_lts_state == S_RCVRY_LOCK) || ((latched_next_lts_state == S_RCVRY_LOCK) && latched_next_lts_flag))
                               && !clear && !cdm_ras_des_ltssm_stop  ;

always@(posedge core_clk or negedge core_rst_n) begin : latched_first_entry_rcvry_lock_PROC
    if (!core_rst_n)
        latched_first_entry_rcvry_lock <= #TP 0;
    else if ( rcvry_lock_entry )
        latched_first_entry_rcvry_lock <= #TP 1;
    else if ( lts_state == S_DETECT_QUIET )
        latched_first_entry_rcvry_lock <= #TP 0;
end

always@(posedge core_clk or negedge core_rst_n) begin : mac_phy_txmargin_seq_PROC
    if (!core_rst_n)
        mac_phy_txmargin <= #TP 0;
    //sample cfg_transmit_margin on entry to poll_compliance, L0->Rcvry, L0s->Rcvry, L1->Rcvry, first_enter_rcvry_lock
    else if ( poll_compliance_entry || l0_recovery || l0s_recovery || l1_recovery || (rcvry_lock_entry && !latched_first_entry_rcvry_lock) )
        mac_phy_txmargin <= #TP cfg_transmit_margin;
    //default voltage level of the Transmit Margin field from entry to poll_active
    else if ( next_lts_state == S_POLL_ACTIVE && !clear && !cfg_enter_compliance)
        mac_phy_txmargin <= #TP 0;
end

// mac_phy_txswing=0 and 2.5GT/s         -> -3.5dB
// mac_phy_txswing=0 and 5.0GT/s         -> -3.5dB or -6.0dB (depends on select_deemphasis)
// mac_phy_txswing=1 and (2.5 or 5.0GTs) -> No de-emphasis
assign  mac_phy_txdeemph = (mac_phy_txswing)? 2'b10 : (mac_phy_rate == `GEN1_RATE) ? 2'b01 : {1'b0, select_deemphasis};

always@(posedge core_clk or negedge sticky_rst_n) begin : mac_phy_txswing_PROC
    if (!sticky_rst_n)
        mac_phy_txswing <= #TP `DEFAULT_GEN2_TXSWING;
    // In Detect.Quiet, mac_phy_txswing is not permitted to change.
    else if ( lts_state != S_DETECT_QUIET )
        mac_phy_txswing <= #TP cfg_phy_txswing;
end    



   assign  directed_recovery = latched_direct_rst | latched_link_retrain_bit | cfg_link_dis | (!clked_cfg_lpbk_en & cfg_lpbk_en);

    // latches to control lts_state transition
    // this process decides the link number for port to transmit
    always@(posedge core_clk or negedge core_rst_n)
        if (!core_rst_n)
        xmt_ts_lnknum       <= #TP 8'b0;
        // when ltssm is in link width start state, it supposed to latch the remote site link num
        // only when two consective non pad link number has been received
        else if ((lts_state == S_CFG_LINKWD_START) & cfg_upstream_port & link_any_2_ts1_linkn_planen_rcvd & ~clear)
        xmt_ts_lnknum       <= #TP link_any_2_ts1_link_num;
        else if (!cfg_upstream_port)  // when ltssm supposed to latch its own transmitted link num
        // link number will be latched during the cfg start state
        xmt_ts_lnknum       <= #TP cfg_link_num;

always @( posedge core_clk or negedge sticky_rst_n ) begin : latched_xmt_ts_lnknum_PROC
    if ( ~sticky_rst_n ) begin
        latched_xmt_ts_lnknum <= #TP 0;
    end else if ( ~latched_smlh_link_up ) begin
        latched_xmt_ts_lnknum <= #TP cfg_link_num;
    end else if ( smlh_link_up ) begin
        latched_xmt_ts_lnknum <= #TP xmt_ts_lnknum;
    end
end // latched_xmt_ts_lnknum_PROC

// S_RCVRY_RCVRCFG -> S_RCVRY_IDLE -> S_HOT_RESET_ENTRY/S_LPBK_ENTRY(no spd chg)/S_DISABLED_ENTRY
// TX TS2s            No Idle sent    TX TS1s
//                                    accumulate 32 TSs from S_RCVRY_RCVRCFG, then send an EIEOS
assign rcvry_idle_consecutive_ts =  (((~cfg_upstream_port ) && cfg_link_dis) ||        //Disabled initiator
                                     ((~cfg_upstream_port ) && latched_direct_rst) ||  //HotReset initiator
                                     (cfg_lpbk_en)                                                                                           //Loopback initiator
                                     || ( cfg_upstream_port && ltssm_flit_mode_enable &&
                                          (link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd || link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd || link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd) )
                                    ) && no_idle_need_sent;

reg latched_no_idle_need_sent;
always @(posedge core_clk or negedge core_rst_n) begin : latched_no_idle_need_sent_PROC
    if ( ~core_rst_n )
        latched_no_idle_need_sent <= #TP 0;
//    else if ( (lts_state != S_RCVRY_IDLE) && (next_lts_state == S_RCVRY_IDLE) && !clear && cfg_lpbk_en ) // loopback master
    else if ( (((lts_state != S_RCVRY_IDLE) && (next_lts_state == S_RCVRY_IDLE)) || (last_lts_state == S_RCVRY_IDLE && lts_state == S_CFG_LINKWD_START && next_lts_state == S_LPBK_ENTRY)) && !clear && cfg_lpbk_en ) // loopback master
        latched_no_idle_need_sent <= #TP 1; // prevent sending eieos before sending first ts1 in Loopback.Entry if no Idle Data sent in S_RCVRY_IDLE
    else if ( curnt_lpbk_entry_state != S_LPBK_ENTRY_IDLE || lts_state == S_DETECT_QUIET )
        latched_no_idle_need_sent <= #TP 0;
end // latched_no_idle_need_sent_PROC

always @(posedge core_clk or negedge core_rst_n) begin
  if (!core_rst_n)
    ltssm_ts_cnt_en   <= #TP 1'b0;
  else if ( (enter_cfg_linkwidth_start || rcvry_lock_entry) && (~g1_rate) ) //base spec defines eieos to be sent before TS1s for the two states
    ltssm_ts_cnt_en   <= #TP 1'b0;
  else if ( rcvry_idle_consecutive_ts && (~g1_rate) ) // see comments from rcvry_idle_consecutive_ts signal generation logic
    ltssm_ts_cnt_en   <= #TP 1'b1; // no reset to ltssm_ts_cnt_en following S_RCVRY_RCVRCFG because of S_RCVRY_IDLE where no Idle Data is sent
  else if ( |current_data_rate && // Gen2 and Gen 3
      ((lts_state == S_RCVRY_LOCK) ||
       (lts_state == S_RCVRY_RCVRCFG) ||
       (lts_state == S_POLL_ACTIVE || lts_state == S_POLL_CONFIG) ||
       (lts_state == S_CFG_LINKWD_START)) )
    ltssm_ts_cnt_en   <= #TP 1'b1;
  else if ( ((g3_rate) || (g4_rate) || (g5_rate) || (goe_g6)) && // Gen 3 only
      ((lts_state == S_CFG_LINKWD_ACEPT || lts_state == S_CFG_LANENUM_WAIT ||
        lts_state == S_CFG_LANENUM_ACEPT || (lts_state == S_CFG_COMPLETE)) ||
       (lts_state == S_HOT_RESET_ENTRY) || (lts_state == S_HOT_RESET) ||
       (lts_state == S_RCVRY_EQ0) || (lts_state == S_RCVRY_EQ1) ||
       (lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_EQ3) ||
       (lts_state == S_DISABLED_ENTRY)  || (lts_state == S_LPBK_ENTRY && (curnt_lpbk_entry_state != S_LPBK_ENTRY_IDLE || latched_no_idle_need_sent || last_state_is_eq))) ) // S_LPBK_ENTRY & ~sending_idle, then sending eieos
    ltssm_ts_cnt_en   <= #TP 1'b1;
 // stop the count of ts
  else if ( cdm_ras_des_ltssm_stop ) 
    ltssm_ts_cnt_en   <= #TP ltssm_ts_cnt_en;
  else
    ltssm_ts_cnt_en   <= #TP 1'b0;
end

//have to latch first rcvd TS2 in S_RCVRY_RCVRCFG or S_CFG_COMPLETE for robust reason if TS1 rcvd in between TS2s
reg latched_first_rcvd_ts2;
reg latched_first_sent_ts;
always @(posedge core_clk or negedge core_rst_n) begin : latched_first_rcvd_ts2_PROC
    if ( !core_rst_n ) begin
        latched_first_rcvd_ts2 <= #TP 0;
    end else if ( !(lts_state == S_RCVRY_RCVRCFG || lts_state == S_CFG_COMPLETE) ) begin //reset to 0 if not in S_CFG_COMPLETE or S_RCVRY_RCVRCFG
        latched_first_rcvd_ts2 <= #TP 0;
    end else if ( link_any_1_ts2_rcvd ) begin //latch rcvd ts2 if in S_RCVRY_RCVRCFG or S_CFG_COMPLETE
        latched_first_rcvd_ts2 <= #TP 1;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : latched_first_sent_ts2_PROC
    if ( !core_rst_n ) begin
        latched_first_sent_ts <= #TP 0;
    end else if ( !(lts_state == S_RCVRY_RCVRCFG || lts_state == S_CFG_COMPLETE) ) begin //reset to 0 if not in S_CFG_COMPLETE or S_RCVRY_RCVRCFG
        latched_first_sent_ts <= #TP 0;
    end else if ( latched_first_rcvd_ts2 && (|xmtbyte_ts1_sent || |xmtbyte_ts2_sent) ) begin //latch first sent ts if in S_RCVRY_RCVRCFG or S_CFG_COMPLETE after rcvd a ts2
        latched_first_sent_ts <= #TP 1;
    end
end

assign ltssm_ts_cnt_rst = ( (!(lts_state == S_RCVRY_RCVRCFG || lts_state == S_CFG_COMPLETE)) || //no reset if not in S_RCVRY_RCVRCFG or S_CFG_COMPLETE
                            (lts_state == S_RCVRY_RCVRCFG && g1_rate) || //no reset if in S_RCVRY_RCVRCFG but at gen1 rate
                            //no reset if in S_CFG_COMPLETE but at gen1/2 rate
                            (lts_state == S_CFG_COMPLETE && (g1_rate || g2_rate)) ) ? 0 :
                          //reset if first ts2 rcvd in S_RCVRY_RCVRCFG at gen2/3 rate or in S_CFG_COMPLETE at gen3 rate
                          (|xmtbyte_ts1_sent || |xmtbyte_ts2_sent) & !latched_first_sent_ts & latched_first_rcvd_ts2;

// Directed Equalization initiated either by Software or Hardware
assign equalization_req = redo_eq_phase_step[1];

assign set_directed_equalization_g3 = (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)||(lts_state == S_L0S)) && !clear &&
                                      ( redo_eq_phase_step[1] && redo_eq_phase_g3);
assign clr_directed_equalization_g3 = ( (g3_rate) && ((lts_state == S_RCVRY_EQ0) || (lts_state == S_RCVRY_EQ1) || (lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_EQ3)) ) ||
                                      ( (lts_state == S_RCVRY_SPEED) && !gen3_supported ) ||
                                      ( (lts_state == S_RCVRY_IDLE)  ) ;

always @(posedge core_clk or negedge core_rst_n) 
begin : directed_equalization_g3_PROC
  if (!core_rst_n)
          directed_equalization_g3 <= #TP 1'b0;
  else begin
      if( set_directed_equalization_g3 ) begin
          directed_equalization_g3 <= #TP 1'b1;
      end else if(clr_directed_equalization_g3) begin
          directed_equalization_g3 <= #TP 1'b0;
      end
  end
end

//assign set_directed_equalization_g4_skipeq = (lts_state == S_RCVRY_SPEED && next_lts_state == S_RCVRY_LOCK && eq_to_rspeed_g5 && ~clear); 
assign set_directed_equalization_g4_skipeq = 1'b0;
//assign set_directed_equalization_g5_skipeq = (lts_state == S_RCVRY_SPEED && next_lts_state == S_RCVRY_LOCK && eq_to_rspeed_g6 && ~clear); 
assign set_directed_equalization_g5_skipeq = 1'b0;
assign set_directed_equalization_g4 = (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)||(lts_state == S_L0S)) && !clear &&
                                      ( redo_eq_phase_step[1] && redo_eq_phase_g4);
assign clr_directed_equalization_g4 = ( (g4_rate) && ((lts_state == S_RCVRY_EQ0) || (lts_state == S_RCVRY_EQ1) || (lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_EQ3)) ) ||
                                      ( (lts_state == S_RCVRY_SPEED) && !gen4_supported ) ||
                                      ( (lts_state == S_RCVRY_IDLE)  ) ;

always @(posedge core_clk or negedge core_rst_n) 
begin : directed_equalization_g4_skipeq_PROC
  if (!core_rst_n) begin
      directed_equalization_g4_skipeq <= #TP 1'b0;
  end else begin
      if( set_directed_equalization_g4_skipeq ) begin
          directed_equalization_g4_skipeq <= #TP 1'b1;
      end else if( clr_directed_equalization_g4 ) begin
          directed_equalization_g4_skipeq <= #TP 1'b0;
      end
  end
end // directed_equalization_g4_skipeq_PROC

always @(posedge core_clk or negedge core_rst_n) 
begin : directed_equalization_g5_skipeq_PROC
  if (!core_rst_n) begin
      directed_equalization_g5_skipeq <= #TP 1'b0;
  end else begin
      if( set_directed_equalization_g5_skipeq ) begin
          directed_equalization_g5_skipeq <= #TP 1'b1;
      end else if( clr_directed_equalization_g5 ) begin
          directed_equalization_g5_skipeq <= #TP 1'b0;
      end
  end
end // directed_equalization_g5_skipeq_PROC

always @(posedge core_clk or negedge core_rst_n) 
begin : directed_equalization_g4_PROC
  if (!core_rst_n) begin
          directed_equalization_g4 <= #TP 1'b0;
  end else begin
      if( set_directed_equalization_g4 ) begin
          directed_equalization_g4 <= #TP 1'b1;
      end else if(clr_directed_equalization_g4) begin
          directed_equalization_g4 <= #TP 1'b0;
      end
  end
end

assign set_directed_equalization_g5 = (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)||(lts_state == S_L0S)) && !clear &&
                                      ( redo_eq_phase_step[1] && redo_eq_phase_g5);
assign clr_directed_equalization_g5 = ( (g5_rate) && ((lts_state == S_RCVRY_EQ0) || (lts_state == S_RCVRY_EQ1) || (lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_EQ3)) ) ||
                                      ( (lts_state == S_RCVRY_SPEED) && !gen5_supported ) ||
                                      ( (lts_state == S_RCVRY_IDLE)  ) ;

always @(posedge core_clk or negedge core_rst_n)
begin : directed_equalization_g5_PROC
  if (!core_rst_n)
          directed_equalization_g5 <= #TP 1'b0;
  else begin
      if( set_directed_equalization_g5 ) begin
          directed_equalization_g5 <= #TP 1'b1;
      end else if(clr_directed_equalization_g5) begin
          directed_equalization_g5 <= #TP 1'b0;
      end
  end
end

assign set_directed_equalization_g6 = (next_lts_state == S_RCVRY_LOCK) && ((lts_state == S_L0)||(lts_state == S_L1_IDLE)||(lts_state == S_L0S)) && !clear &&
                                      ( redo_eq_phase_step[1] && redo_eq_phase_g6);
assign clr_directed_equalization_g6 = ( (g6_rate) && ((lts_state == S_RCVRY_EQ0) || (lts_state == S_RCVRY_EQ1) || (lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_EQ3)) ) ||
                                      ( (lts_state == S_RCVRY_SPEED) && !gen6_supported ) ||
                                      ( (lts_state == S_RCVRY_IDLE)  ) ;

always @(posedge core_clk or negedge core_rst_n)
begin : directed_equalization_g6_PROC
  if (!core_rst_n)
          directed_equalization_g6 <= #TP 1'b0;
  else begin
      if( set_directed_equalization_g6 ) begin
          directed_equalization_g6 <= #TP 1'b1;
      end else if(clr_directed_equalization_g6) begin
          directed_equalization_g6 <= #TP 1'b0;
      end
  end
end

assign ltssm_start_equalization[0] = start_equalization_w_preset;
assign ltssm_start_equalization[3:1] = 0; // www:

// start_equalization_w_preset  LTSSM Variable
always @(posedge core_clk or negedge core_rst_n) 
begin : start_equalization_w_preset_PROC
  if (!core_rst_n)
          start_equalization_w_preset <= #TP 1'b0;
  else begin
      // Reset upon entering Recovery.RcvrCfg
      if ((next_lts_state == S_RCVRY_RCVRCFG) && (lts_state != S_RCVRY_RCVRCFG) && !clear)
          start_equalization_w_preset <= #TP 1'b0;
      // Reset upon entering Recovery.Equalization Phase 0 (Upstream Lanes)
      else if (downstream_component && (next_lts_state == S_RCVRY_EQ0) && (lts_state != S_RCVRY_EQ0) && !clear)
          start_equalization_w_preset <= #TP 1'b0;
      // Reset upon entering Recovery.Equalization Phase 1 (Downstream Lanes)
      else if (upstream_component && (next_lts_state == S_RCVRY_EQ1) && (lts_state != S_RCVRY_EQ1) && !clear)
          start_equalization_w_preset <= #TP 1'b0;
      // Set when 8 EQ TS2s are received in Recovery.RcvrCfg by Downstream Component with Speed Change Bit Set.
      // If CX_AP_SUPPORT, advertise gen5 rate in Cfg.Complete even if target_link_speed = Gen3/4. This needs gen5_supported to not set start_equalization_w_preset in S_RCVRY_RCVRCFG state if skip_eq
      else if (downstream_component && !cfg_gen3_eq_disable && eqctl_any_8eqts2_rcvd && !clear && ((captured_ts_data_rate_eg6[2] && ~captured_ts_data_rate_eg6[3]) || (skip_eq && ~noeq_nd && captured_ts_data_rate_eg6[4])) //if skip_eq, go for gen5 eq. E
            && (next_lts_state == S_RCVRY_SPEED) && (lts_state == S_RCVRY_RCVRCFG) && ((skip_eq && ~noeq_nd) ? gen5_supported : 1'b1) ) // only need to check eqctl_any_8eqts2_rcvd and next state == S_RCVRY_SPEED
          start_equalization_w_preset <= #TP 1'b1;
      // An Upstream component must Set variable if the equalization_done_8GT_data_rate variable is 0b or if Directed
      // when in Recovery.RcvrCfg and transitioning to Recovery.Speed
      else if (upstream_component && !cfg_gen3_eq_disable && (!equalization_done_8gt_data_rate || directed_equalization_g3) 
              && (next_lts_state == S_RCVRY_SPEED) && link_latched_live_any_ts2_rcvd && !clear 
              && (lts_state == S_RCVRY_RCVRCFG)) // only need to check any ts2 received and next state == S_RCVRY_SPEED
          start_equalization_w_preset <= #TP 1'b1;
      // Set when 8 8GT EQ TS2s are received in Recovery.RcvrCfg by Downstream Component with Speed Change Bit Set
      else if (downstream_component && !cfg_gen3_eq_disable && eqctl_any_8g4eqts2_rcvd && gen4_supported && !clear && (g3_rate)
            && (next_lts_state == S_RCVRY_SPEED) && (lts_state == S_RCVRY_RCVRCFG))
          start_equalization_w_preset <= #TP 1'b1;
      // An Upstream component must Set variable if the equalization_done_8GT_data_rate variable is 0b or if Directed
      // when in Recovery.RcvrCfg and transitioning to Recovery.Speed
      else if (upstream_component && !cfg_gen3_eq_disable && (!equalization_done_16gt_data_rate || directed_equalization_g4) 
              && (next_lts_state == S_RCVRY_SPEED) && link_latched_live_any_ts2_rcvd && !clear && gen4_supported
              && (lts_state == S_RCVRY_RCVRCFG))
          start_equalization_w_preset <= #TP 1'b1;
      // Set when 8 8GT EQ TS2s are received in Recovery.RcvrCfg by Downstream Component with Speed Change Bit Set
      else if (downstream_component && !cfg_gen3_eq_disable && eqctl_any_8g5eqts2_rcvd && gen5_supported && !clear && (g4_rate)
            && (next_lts_state == S_RCVRY_SPEED) && (lts_state == S_RCVRY_RCVRCFG))
          start_equalization_w_preset <= #TP 1'b1;
      // An Upstream component must Set variable if the equalization_done_8GT_data_rate variable is 0b or if Directed
      // when in Recovery.RcvrCfg and transitioning to Recovery.Speed
      else if (upstream_component && !cfg_gen3_eq_disable && (!equalization_done_32gt_data_rate || directed_equalization_g5) 
              && (next_lts_state == S_RCVRY_SPEED) && link_latched_live_any_ts2_rcvd && !clear && gen5_supported
              && (lts_state == S_RCVRY_RCVRCFG))
          start_equalization_w_preset <= #TP 1'b1;
      // Set when 8 8GT EQ TS2s are received in Recovery.RcvrCfg by Downstream Component with Speed Change Bit Set
      else if (downstream_component && !cfg_gen3_eq_disable && eqctl_any_8g6eqts2_rcvd && gen6_supported && !clear && (g5_rate)
            && (next_lts_state == S_RCVRY_SPEED) && (lts_state == S_RCVRY_RCVRCFG))
          start_equalization_w_preset <= #TP 1'b1;
      // An Upstream component must Set variable if the equalization_done_8GT_data_rate variable is 0b or if Directed
      // when in Recovery.RcvrCfg and transitioning to Recovery.Speed
      else if (upstream_component && !cfg_gen3_eq_disable && (!equalization_done_64gt_data_rate || directed_equalization_g6)
              && (next_lts_state == S_RCVRY_SPEED) && link_latched_live_any_ts2_rcvd && !clear && gen6_supported
              && (lts_state == S_RCVRY_RCVRCFG))
          start_equalization_w_preset <= #TP 1'b1;
  end
end

// equalization_done_8GT_data_rate LTSSM Variable
always @(posedge core_clk or negedge core_rst_n)
begin : equalization_done_8gt_data_rate_PROC
  if (!core_rst_n)
      equalization_done_8gt_data_rate <= #TP 1'b0;
  else begin
      // Set upon entering Recovery.Equalization Phase 0 (Upstream Lanes) in 8.0GT/s
      if ((g3_rate) && downstream_component && (next_lts_state == S_RCVRY_EQ0) && (lts_state != S_RCVRY_EQ0) && !clear)
          equalization_done_8gt_data_rate <= #TP 1'b1;
      // Set upon entering Recovery.Equalization Phase 1 (Downstream Lanes) in 8.0GT/s
      else if ((g3_rate) && upstream_component && (next_lts_state == S_RCVRY_EQ1) && (lts_state != S_RCVRY_EQ1) && !clear)
          equalization_done_8gt_data_rate <= #TP 1'b1;

      if ( noeq_nd || lpbk_master_eq_exit ) // if no_eq_needed = 1, equalization_done_8gt_data_rate set to 1
          equalization_done_8gt_data_rate <= #TP 1'b1;
      else if ( skip_eq ) // Skip eq to highest rate
          equalization_done_8gt_data_rate <= #TP 1'b1;

      // Reset when LTSSM is in Detect.Quiet State
      if (lts_state == S_DETECT_QUIET || dsp_skip_eq_falling_edge)
          equalization_done_8gt_data_rate <= #TP 1'b0;
  end
end

// equalization_done_16GT_data_rate LTSSM Variable
always @(posedge core_clk or negedge core_rst_n)
begin : equalization_done_16gt_data_rate_PROC
  if (!core_rst_n)
      equalization_done_16gt_data_rate <= #TP 1'b0;
  else begin
      // Set upon entering Recovery.Equalization Phase 0 (Upstream Lanes) in 16.0GT/s
      if ((g4_rate) && downstream_component && (next_lts_state == S_RCVRY_EQ0) && (lts_state != S_RCVRY_EQ0) && !clear)
          equalization_done_16gt_data_rate <= #TP 1'b1;
      // Set upon entering Recovery.Equalization Phase 1 (Downstream Lanes) in 16.0GT/s
      else if ((g4_rate) && upstream_component && (next_lts_state == S_RCVRY_EQ1) && (lts_state != S_RCVRY_EQ1) && !clear)
          equalization_done_16gt_data_rate <= #TP 1'b1;

      if ( noeq_nd || lpbk_master_eq_exit ) // if no_eq_needed = 1, equalization_done_16gt_data_rate set to 1
          equalization_done_16gt_data_rate <= #TP 1'b1;
      else if ( skip_eq ) // Skip eq to highest rate
          equalization_done_16gt_data_rate <= #TP 1'b1;

      // Reset when LTSSM is in Detect.Quiet State
      if (lts_state == S_DETECT_QUIET || dsp_skip_eq_falling_edge)
          equalization_done_16gt_data_rate <= #TP 1'b0;
  end
end

// equalization_done_32GT_data_rate LTSSM Variable
always @(posedge core_clk or negedge core_rst_n)
begin : equalization_done_32gt_data_rate_PROC
  if (!core_rst_n)
      equalization_done_32gt_data_rate <= #TP 1'b0;
  else begin
      // Set upon entering Recovery.Equalization Phase 0 (Upstream Lanes) in 16.0GT/s
      if ((g5_rate) && downstream_component && (next_lts_state == S_RCVRY_EQ0) && (lts_state != S_RCVRY_EQ0) && !clear)
          equalization_done_32gt_data_rate <= #TP 1'b1;
      // Set upon entering Recovery.Equalization Phase 1 (Downstream Lanes) in 16.0GT/s
      else if ((g5_rate) && upstream_component && (next_lts_state == S_RCVRY_EQ1) && (lts_state != S_RCVRY_EQ1) && !clear)
          equalization_done_32gt_data_rate <= #TP 1'b1;
      // Reset when LTSSM is in Detect.Quiet State
      // if software eq_redo with eq_bypass supported and advertise Gen5 rate from current Gen1/2 rate, clear equalization_done_32gt_data_rate for the DSP to send EQ TS and change speed to Gen5 and then perform EQ
      else if (lts_state == S_DETECT_QUIET || dsp_skip_eq_falling_edge)
          equalization_done_32gt_data_rate <= #TP 1'b0;

      if ( noeq_nd || lpbk_master_eq_exit ) // if no_eq_needed = 1, equalization_done_32gt_data_rate set to 1
          equalization_done_32gt_data_rate <= #TP 1'b1;
  end
end

// equalization_done_64GT_data_rate LTSSM Variable
always @(posedge core_clk or negedge core_rst_n)
begin : equalization_done_64gt_data_rate_PROC
  if (!core_rst_n)
      equalization_done_64gt_data_rate <= #TP 1'b0;
  else begin
      // Set upon entering Recovery.Equalization Phase 0 (Upstream Lanes) in 16.0GT/s
      if ((g6_rate) && downstream_component && (next_lts_state == S_RCVRY_EQ0) && (lts_state != S_RCVRY_EQ0) && !clear)
          equalization_done_64gt_data_rate <= #TP 1'b1;
      // Set upon entering Recovery.Equalization Phase 1 (Downstream Lanes) in 16.0GT/s
      else if ((g6_rate) && upstream_component && (next_lts_state == S_RCVRY_EQ1) && (lts_state != S_RCVRY_EQ1) && !clear)
          equalization_done_64gt_data_rate <= #TP 1'b1;
      // Reset when LTSSM is in Detect.Quiet State
      // if software eq_redo with eq_bypass supported and advertise Gen5 rate from current Gen1/2 rate, clear equalization_done_64gt_data_rate for the DSP to send EQ TS and change speed to Gen5 and then perform EQ
      else if (lts_state == S_DETECT_QUIET )
          equalization_done_64gt_data_rate <= #TP 1'b0;

      if ( noeq_nd || lpbk_master_eq_exit ) // if no_eq_needed = 1, equalization_done_64gt_data_rate set to 1
          equalization_done_64gt_data_rate <= #TP 1'b1;
  end
end

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_pam4_restricted_levels_PROC
  if (!core_rst_n) begin
    mac_phy_pam4_restricted_levels <= #TP 1'b0;
  end else if (!cfg_pam4_restricted_levels_requirement || (!goe_g6 && mac_phy_rate >= `GEN6_RATE)) begin // clear when rate change to 64 GT/s
    mac_phy_pam4_restricted_levels <= #TP 1'b0;
  end else if (g6_rate && ((!cfg_gen3_eq_disable && start_equalization_w_preset) || (perform_eq_for_loopback_g6 && ~equalization_done_64gt_data_rate))) begin
    mac_phy_pam4_restricted_levels <= #TP 1'b1;
  end else if (g6_rate && ((!cfg_upstream_port && lts_state == S_RCVRY_EQ3) || (cfg_upstream_port && lts_state == S_RCVRY_EQ2) || (lts_state == S_RCVRY_LOCK && last_lts_state == S_RCVRY_EQ1))) begin
    mac_phy_pam4_restricted_levels <= #TP 1'b0;
  end
end

assign mac_phy_pam4_restricted_levels_rise = mac_phy_pam4_restricted_levels & !mac_phy_pam4_restricted_levels_d;

always @(posedge core_clk or negedge core_rst_n) begin : mac_phy_pam4_restricted_levels_d_PROC
  if (!core_rst_n) begin
    mac_phy_pam4_restricted_levels_d <= #TP 1'b0;
  end else begin
    mac_phy_pam4_restricted_levels_d <= #TP mac_phy_pam4_restricted_levels;
  end
end

logic [NL-1:0] latched_phystatus_for_eqeval;
logic          latched_phystatus_for_eqeval_all;

assign latched_phystatus_for_eqeval_all = &(~ltssm_lanes_active | latched_phystatus_for_eqeval);
always @(posedge core_clk or negedge core_rst_n) begin : latched_phystatus_for_eqeval_PROC
  integer ln;
  if (!core_rst_n) begin
    latched_phystatus_for_eqeval <= #TP {NL{1'b0}};
  end else begin
    for (ln=0; ln<NL; ln=ln+1) begin
      if (!rxeqeval_rcvrlock[ln]) begin
        latched_phystatus_for_eqeval[ln] <= #TP 1'b0;
      end else if (phy_mac_phystatus[ln]) begin
        latched_phystatus_for_eqeval[ln] <= #TP 1'b1;
      end
    end
  end
end

// RxEqEval is requested if Phase2 and Phase3 of Equalization is bypassed and mac_phy_pam4_restricted_levels is deasserted in Recovery.RcvrLock.
always @(posedge core_clk or negedge core_rst_n) begin : rxeqeval_rcvrlock_PROC
  integer ln;
  if (!core_rst_n) begin
    rxeqeval_rcvrlock <= #TP {NL{1'b0}};
  end else begin
    for (ln=0; ln<NL; ln=ln+1) begin
      if (!ltssm_lanes_active[ln] || latched_phystatus_for_eqeval_all || timeout_24ms) begin
        rxeqeval_rcvrlock[ln] <= #TP 1'b0;
      end else if (g6_rate && mac_phy_pam4_restricted_levels && lts_state == S_RCVRY_LOCK && last_lts_state == S_RCVRY_EQ1) begin
        rxeqeval_rcvrlock[ln] <= #TP 1'b1;
      end
    end
  end
end

logic rxeqeval_rcvrlock_any_lane_asserted;
always @(posedge core_clk or negedge core_rst_n) begin : rxeqeval_rcvrlock_any_lane_asserted_PROC
  if (!core_rst_n) begin
    rxeqeval_rcvrlock_any_lane_asserted <= #TP 1'b0;
  end else if (g6_rate && mac_phy_pam4_restricted_levels && lts_state == S_RCVRY_LOCK && last_lts_state == S_RCVRY_EQ1) begin
    rxeqeval_rcvrlock_any_lane_asserted <= #TP 1'b1;
  end else if (~|rxeqeval_rcvrlock) begin
    rxeqeval_rcvrlock_any_lane_asserted <= #TP 1'b0;
  end
end

always @(posedge core_clk or negedge core_rst_n) 
begin : eqts_cmd_PROC
  if (!core_rst_n)
      ltssm_cmd_eqts <= #TP 1'b0;
  else if (upstream_component && !cfg_gen3_eq_disable && (ltssm_ts_data_rate[2] & latched_ts_data_rate_ever[2]) && captured_ts_speed_change // entry to S_RCVRY_RCVRCFG, latched_ts_data_rate_ever in Cfg.Comp or Rcvry.RcvrCfg
           && (!equalization_done_8gt_data_rate || directed_equalization_g3) && ((g1_rate) || (g2_rate)) && (lts_state == S_RCVRY_RCVRCFG))
      ltssm_cmd_eqts <= #TP 1'b1;
  // A Downstream Port than intends to redo EQ sends EQ TS1s during Recovery.RcvrLock
  else if (upstream_component && directed_equalization_g3 && equalization_done_8gt_data_rate && ((g1_rate) || (g2_rate)) && (lts_state == S_RCVRY_LOCK))
      ltssm_cmd_eqts <= #TP 1'b1;
  //the entity performing test in Compliance required to send EQ TS1s. link_latched_ts_data_rate[2] is ok to use latched because ltssm stays in S_POLL_ACTIVE for 24ms in this case. link_latched_ts_data_rate updated long ago
  else if (!cfg_gen3_eq_disable && link_latched_ts_data_rate[2] && ~clear && ltssm_ts_data_rate[2] && ltssm_ts_cntrl[4] && !cfg_lpbk_en && (lts_state == S_POLL_ACTIVE))
      ltssm_cmd_eqts <= #TP 1'b1;
  //loopback master transmits EQ TS1s for slave in Loopback.Entry at gen1/2 rate if entry lpbk from Cfg.Linkwidth.Start
  // int_lpbk may be asserted in flit mode R.RcvrCfg (for quick transition through R.Idle) but we don't want to transmit EQ info
  else if (!cfg_gen3_eq_disable && captured_lpbk_ts_data_rate_eg6[2] && int_lpbk && ((g1_rate) || (g2_rate)) && !rcvry_to_lpbk && !(lts_state == S_RCVRY_RCVRCFG))
      ltssm_cmd_eqts <= #TP 1'b1;
  else
      ltssm_cmd_eqts <= #TP 1'b0;
end

wire eq_0_1_2 = lts_state == S_RCVRY_EQ0 | lts_state == S_RCVRY_EQ1 | lts_state == S_RCVRY_EQ2;
wire pre_eq_1 = (next_lts_state == S_RCVRY_EQ1 & ~clear) | lts_state == S_RCVRY_EQ1;
always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_cmd_eqts0_PROC
    if ( ~core_rst_n )
        ltssm_cmd_eqts0 <= #TP 0;
    else
        ltssm_cmd_eqts0 <= #TP goe_g6 & (cfg_upstream_port ? eq_0_1_2 : pre_eq_1);
end // ltssm_cmd_eqts0_PROC

// use combinatorial logic + (lts_state_d == S_RCVRY_RCVRCFG) to avoid Tx eq_ts bit change in the first TS2 and the second TS2 because ltssm_ts_data_rate delays one cycle and load_pat at the 2nd cycle of S_RCVRY_RCVRCFG state.
// this also covers load_pat in the first cycle in the state following S_RCVRY_RCVRCFG state because lts_state_d used.
// commented out upstream_component for precode_request bit sending
reg eqctl_any_8eqts1_rcvd_d;
always @(posedge core_clk or negedge core_rst_n) begin : eqctl_any_8eqts1_rcvd_d_PROC
    if ( ~core_rst_n )
        eqctl_any_8eqts1_rcvd_d <= #TP 0;
    else if ( ~(lts_state == S_RCVRY_LOCK || lts_state == S_RCVRY_RCVRCFG) )
        eqctl_any_8eqts1_rcvd_d <= #TP 0;
    else if ( (lts_state == S_RCVRY_LOCK || lts_state == S_RCVRY_RCVRCFG) && eqctl_any_8eqts1_rcvd )
        eqctl_any_8eqts1_rcvd_d <= #TP 1;
end // eqctl_any_8eqts1_rcvd_d_PROC

wire eqctl_any_8eqts1_rcvd_i = eqctl_any_8eqts1_rcvd_d | eqctl_any_8eqts1_rcvd;

always @( * ) begin : ltssm_cmd_eqts_gen12_PROC
    if ( skip_eq && slr_g3 /*&& upstream_component*/ && !cfg_gen3_eq_disable && (ltssm_ts_data_rate_eg6[5] && latched_ts_data_rate_ever_eg6[5]) && captured_ts_speed_change && // at gen1/2 rate, speedup to Gen5 directly for skip_eq
                  equalization_done_32gt_data_rate && (~equalization_done_64gt_data_rate || ((eqctl_any_8eqts2_rcvd || eqctl_any_8eqts1_rcvd_i) && ~noeq_nd /*&& captured_ts_data_rate[4]*/)) && lts_state_d == S_RCVRY_RCVRCFG ) begin // eqctl_any_8eqts2_rcvd: gen1/2 -> Gen5 with EQ
        ltssm_cmd_eqts_gen12 = 2'b10; // if eq redo AND skip_eq AND captured_ts_speed_change, no need the condition captured_ts_data_rate[4] which will make the other side cannot detect EQ TS and thus cannot catch precoding. skip_eq -> gen12 to gen5
    end else if ( skip_eq && slr_g3 && (upstream_component || (downstream_component && !(lts_state_d == S_RCVRY_LOCK))) && !cfg_gen3_eq_disable && (ltssm_ts_data_rate_eg6[5] && latched_ts_data_rate_ever_eg6[5]) /*&& captured_ts_speed_change*/ && // at gen1/2 rate, speedup to Gen5 directly for skip_eq
                  equalization_done_32gt_data_rate && (~equalization_done_64gt_data_rate || ((eqctl_any_8eqts2_rcvd || eqctl_any_8eqts1_rcvd_i) && !(lts_state_d == S_RCVRY_LOCK) && ~noeq_nd /*&& captured_ts_data_rate[4]*/)) /*&& lts_state_d == S_RCVRY_RCVRCFG*/ ) begin // eqctl_any_8eqts2_rcvd: gen1/2 -> Gen5 wit
        ltssm_cmd_eqts_gen12 = 2'b01; // if eq redo AND skip_eq AND captured_ts_speed_change, no need the condition captured_ts_data_rate[4] which will make the other side cannot detect EQ TS and thus cannot catch precoding. skip_eq -> gen12 to gen5
    end else
    if ( skip_eq && slr_g3 /*&& upstream_component*/ && !cfg_gen3_eq_disable && (ltssm_ts_data_rate[4] && latched_ts_data_rate_ever[4]) && captured_ts_speed_change && // at gen1/2 rate, speedup to Gen5 directly for skip_eq
                  equalization_done_16gt_data_rate && (~equalization_done_32gt_data_rate || ((eqctl_any_8eqts2_rcvd || eqctl_any_8eqts1_rcvd_i) && ~noeq_nd /*&& captured_ts_data_rate[4]*/) || directed_equalization_g5) && lts_state_d == S_RCVRY_RCVRCFG ) begin // eqctl_any_8eqts2_rcvd: gen1/2 -> Gen5 with EQ TS2s, use the Rx EQ preset as initial preset
        ltssm_cmd_eqts_gen12 = 2'b10; // if eq redo AND skip_eq AND captured_ts_speed_change, no need the condition captured_ts_data_rate[4] which will make the other side cannot detect EQ TS and thus cannot catch precoding. skip_eq -> gen12 to gen5
    end else if ( skip_eq && slr_g3 && (upstream_component || (downstream_component && !(lts_state_d == S_RCVRY_LOCK))) && !cfg_gen3_eq_disable && (ltssm_ts_data_rate[4] && latched_ts_data_rate_ever[4]) /*&& captured_ts_speed_change*/ && // at gen1/2 rate, speedup to Gen5 directly for skip_eq
                  equalization_done_16gt_data_rate && (~equalization_done_32gt_data_rate || ((eqctl_any_8eqts2_rcvd || eqctl_any_8eqts1_rcvd_i) && !(lts_state_d == S_RCVRY_LOCK) && ~noeq_nd /*&& captured_ts_data_rate[4]*/)) /*&& lts_state_d == S_RCVRY_RCVRCFG*/ ) begin // eqctl_any_8eqts2_rcvd: gen1/2 -> Gen5 with EQ TS2s, use the Rx EQ preset as initial preset
        ltssm_cmd_eqts_gen12 = 2'b01; // if eq redo AND skip_eq AND captured_ts_speed_change, no need the condition captured_ts_data_rate[4] which will make the other side cannot detect EQ TS and thus cannot catch precoding. skip_eq -> gen12 to gen5
    end else if ( skip_eq && slr_g3 && upstream_component && directed_equalization_g5 && equalization_done_32gt_data_rate && (lts_state == S_RCVRY_LOCK) && ~noeq_nd) begin 
        ltssm_cmd_eqts_gen12 = 2'b01; 
    end else begin
        ltssm_cmd_eqts_gen12 = 2'b00; // [0] for TS1, [1] for TS2
    end
end // ltssm_cmd_eqts_gen12_PROC

assign cond_eqos_usp_send_maxspeed = ( (cfg_pcie_max_link_speed != `GEN1_LINK_SP) && (cfg_pcie_max_link_speed != `GEN2_LINK_SP) && (eqctl_any_8eqts1_rcvd || eqctl_any_8eqts2_rcvd) && !ltssm_ts_data_rate[2] && link_ts_data_rate[2] && link_ts_spd_chg ) // current_data_rate_g12
                                     || ( (cfg_pcie_max_link_speed >= `GEN4_LINK_SP) && (eqctl_any_8g4eqts1_rcvd || eqctl_any_8g4eqts2_rcvd) && !ltssm_ts_data_rate_eg6[3] && link_ts_spd_chg ) // current_data_rate_g3
                                     || ( (cfg_pcie_max_link_speed >= `GEN5_LINK_SP) && (eqctl_any_8g5eqts1_rcvd || eqctl_any_8g5eqts2_rcvd) && !ltssm_ts_data_rate[4] && link_ts_spd_chg ) // current_data_rate_g4
                                     || ( (cfg_pcie_max_link_speed >= `GEN6_LINK_SP) && (eqctl_any_8g6eqts1_rcvd || eqctl_any_8g6eqts2_rcvd) && !ltssm_ts_data_rate_eg6[5] && link_ts_spd_chg ) // current_data_rate_g5
                                     ;

always @(posedge core_clk or negedge core_rst_n)
begin : latched_eqos_usp_send_maxspeed_PROC
  if (!core_rst_n) begin
      latched_eqos_usp_send_maxspeed <= #TP 1'b0;
  end else if ( lts_state == S_RCVRY_LOCK && !clear ) begin
      latched_eqos_usp_send_maxspeed <= #TP (cond_eqos_usp_send_maxspeed | latched_eqos_usp_send_maxspeed);
  end else if ( lts_state == S_RCVRY_RCVRCFG ) begin
      latched_eqos_usp_send_maxspeed <= #TP latched_eqos_usp_send_maxspeed;
  end else begin
      latched_eqos_usp_send_maxspeed <= #TP 1'b0;
  end
end

always @(posedge core_clk or negedge core_rst_n)
begin : latchecd_eqctl_8g4eqts1_rcvd_PROC
  if (!core_rst_n)
      latchecd_eqctl_8g4eqts1_rcvd <= #TP 1'b0;
  else if ( (lts_state == S_RCVRY_LOCK) || (lts_state == S_RCVRY_RCVRCFG) )
      latchecd_eqctl_8g4eqts1_rcvd <= #TP (latchecd_eqctl_8g4eqts1_rcvd | eqctl_8g4eqts1_rcvd);
  else
      latchecd_eqctl_8g4eqts1_rcvd <= #TP 1'b0;
end

// change the logic from sequential to combinatorial because the signal is used in smlh_eqctl.v where the signal caused the first TX ts2 does not have USE_PRESET bit set
// in Recovery.RcvrCfg state if the signal is sequential. The original sequential logic unsets the signal immediately if the two following conditions are not true.
// So it is ok to change it to combinatorial
always @( * ) begin : ltssm_cmd_8geqts_PROC
  ltssm_cmd_8geqts = 1'b0;

  if ( upstream_component && (current_data_rate == `GEN3_RATE) && (lts_state == S_RCVRY_RCVRCFG) && (ltssm_ts_data_rate_eg6[3] && latched_ts_data_rate_ever_eg6[3]) && captured_ts_speed_change &&
            ( init_eq_pending_g4 ||
              soft_eq_phase_flag_ff ||                                                                                   // first time to Gen4
              (redo_eq_phase_flag_ff && (redo_eq_target_rate_ff==3'b011) && (~redo_eq_phase_g5_ff & ~redo_eq_phase_g6_ff))) )  // equalization_done_16gt_data_rate = 1 and cfg_perform_eq & "not gen5 eq redo"
      ltssm_cmd_8geqts = 1'b1;
  else
  if ( downstream_component && (g3_rate) && (lts_state == S_RCVRY_RCVRCFG) &&
            directed_speed_change && (ltssm_ts_data_rate_int == 5'b01111 || ltssm_ts_data_rate_int == 5'b11111 || ltssm_ts_data_rate_int == 5'b10111) && ~cfg_gen4_usp_send_8gt_eq_ts2_disable &&
            ( ~equalization_done_16gt_data_rate ||
              latchecd_eqctl_8g4eqts1_rcvd ) )
      ltssm_cmd_8geqts = 1'b1;
end // ltssm_cmd_8geqts_PROC

always @(posedge core_clk or negedge core_rst_n)
begin : eqredo_cmd_PROC
  if (!core_rst_n)
      ltssm_cmd_eqredo <= #TP 1'b0;
  else if (upstream_component && (((g3_rate) && directed_equalization_g4 && equalization_done_16gt_data_rate)
 || ((g4_rate) && directed_equalization_g5 && equalization_done_32gt_data_rate)
 || ((g5_rate) && directed_equalization_g6 && equalization_done_64gt_data_rate))&& (lts_state == S_RCVRY_LOCK))
      ltssm_cmd_eqredo <= #TP 1'b1;
  else
      ltssm_cmd_eqredo <= #TP 1'b0;
end

always @(posedge core_clk or negedge core_rst_n)
begin : latchecd_eqctl_8g5eqts1_rcvd_PROC
  if (!core_rst_n)
      latchecd_eqctl_8g5eqts1_rcvd <= #TP 1'b0;
  else if ( (lts_state == S_RCVRY_LOCK) || (lts_state == S_RCVRY_RCVRCFG) )
      latchecd_eqctl_8g5eqts1_rcvd <= #TP (latchecd_eqctl_8g5eqts1_rcvd | eqctl_8g5eqts1_rcvd);
  else
      latchecd_eqctl_8g5eqts1_rcvd <= #TP 1'b0;
end

// change the logic from sequential to combinatorial because the signal is used in smlh_eqctl.v where the signal caused the first TX ts2 does not have USE_PRESET bit set
// in Recovery.RcvrCfg state if the signal is sequential. The original sequential logic unsets the signal immediately if the two following conditions are not true.
// So it is ok to change it to combinatorial
always @( * ) begin : ltssm_cmd_16geqts_PROC
  ltssm_cmd_16geqts = 1'b0;

  if ( upstream_component && (g4_rate) && (lts_state == S_RCVRY_RCVRCFG) && (ltssm_ts_data_rate[4] && latched_ts_data_rate_ever[4]) && captured_ts_speed_change &&
            ( init_eq_pending_g5 ||
              soft_gen4_eq_phase_flag_ff ||                             // first time to Gen5
              (redo_eq_phase_flag_ff && (redo_eq_target_rate_ff==3'b100) && ~redo_eq_phase_g6_ff)) )  // equalization_done_32gt_data_rate = 1 & cfg_perform_eq
      ltssm_cmd_16geqts = 1'b1;
  else if ( downstream_component && (g4_rate) && (lts_state == S_RCVRY_RCVRCFG) && latched_ts_data_rate_ever[4] && 
            directed_speed_change && (ltssm_ts_data_rate_int == 5'b11111 || ltssm_ts_data_rate_int == 5'b10111) && ~cfg_gen5_usp_send_8gt_eq_ts2_disable &&
            ( ~equalization_done_32gt_data_rate ||
              latchecd_eqctl_8g5eqts1_rcvd ) )
      ltssm_cmd_16geqts = 1'b1;
end // ltssm_cmd_16geqts_PROC

always @(posedge core_clk or negedge core_rst_n)
begin : latchecd_eqctl_8g6eqts1_rcvd_PROC
  if (!core_rst_n)
      latchecd_eqctl_8g6eqts1_rcvd <= #TP 1'b0;
  else if ( (lts_state == S_RCVRY_LOCK) || (lts_state == S_RCVRY_RCVRCFG) )
      latchecd_eqctl_8g6eqts1_rcvd <= #TP (latchecd_eqctl_8g6eqts1_rcvd | eqctl_8g6eqts1_rcvd);
  else
      latchecd_eqctl_8g6eqts1_rcvd <= #TP 1'b0;
end

// change the logic from sequential to combinatorial because the signal is used in smlh_eqctl.v where the signal caused the first TX ts2 does not have USE_PRESET bit set
// in Recovery.RcvrCfg state if the signal is sequential. The original sequential logic unsets the signal immediately if the two following conditions are not true.
// So it is ok to change it to combinatorial
always @( * ) begin : ltssm_cmd_32geqts_PROC
  ltssm_cmd_32geqts = 1'b0;

  if ( upstream_component && (g5_rate) && (lts_state == S_RCVRY_RCVRCFG) && (ltssm_ts_data_rate_eg6[5] && latched_ts_data_rate_ever_eg6[5]) && captured_ts_speed_change &&
            ( init_eq_pending_g6 ||
              soft_gen5_eq_phase_flag_ff ||                             // first time to Gen6
              (redo_eq_phase_flag_ff && (redo_eq_target_rate_ff==3'b101))) )  // equalization_done_64gt_data_rate = 1 & cfg_perform_eq
      ltssm_cmd_32geqts = 1'b1;
  else if ( downstream_component && (g5_rate) && (lts_state == S_RCVRY_RCVRCFG) && latched_ts_data_rate_ever_eg6[5] &&
            directed_speed_change && (ltssm_ts_data_rate_int == 5'b10111) && ~cfg_gen6_usp_send_8gt_eq_ts2_disable &&
            ( ~equalization_done_64gt_data_rate ||
              latchecd_eqctl_8g6eqts1_rcvd ) )
      ltssm_cmd_32geqts = 1'b1;
end // ltssm_cmd_32geqts_PROC

// -------------------------------------------------------------------------
// Beneath is the ltssm main state machine process
// -------------------------------------------------------------------------
//
//Direct the L0 state to recovery state is based on the following
//conditions:
//1. Receiver received TS ordered set while LTSSM is in l0 state
//2. Software wants to start a reset (directed_recovery)
//3. Test and debug function for force lts_state state
//4. when enter electric idle during L0 state, it means that link has problem, we will start link recovery
//5. When received detected skew alignment error while LTSSM's rcvr is in L0 state
//6. When data link layer inigiated a link retraining due to over role of replay timer
//7. When RTLH request link retain because of watch dog timer expired
//8. When the cfg_directed_speed_change bit is set by a higher layer
//
wire                rcvd_2_unexpect_ts;
reg                 latched_rcvd_2_unexpect_ts;
assign rcvd_2_unexpect_ts = link_any_2_ts_rcvd & ~clear;
reg                 l0s_link_rcvry_en;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        l0s_link_rcvry_en     <= #TP 1'b0;
    else
        l0s_link_rcvry_en     <= #TP (rcvd_2_unexpect_ts | xdlh_smlh_start_link_retrain | directed_recovery
                                      | latched_cdm_ras_des_recovery_req
                                      | spif_smlh_req_retrain
                                      | (rmlh_deskew_alignment_err & (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY)) | rtlh_req_link_retrain
                                      );

// gen2 speed is supported by both sides of the link (gen 1 speed must always be supported)
assign  gen2_supported = (ltssm_ts_data_rate[1] & captured_ts_data_rate[1]);
// gen3 speed is supported by both sides of the link (gen 1 speed must always be supported)
assign  gen3_supported = (ltssm_ts_data_rate[2] & captured_ts_data_rate[2]);
// gen4 speed is supported by both sides of the link (gen 1 speed must always be supported)
// gen6 speed is supported by both sides of the link (gen 1 speed must always be supported)
assign  gen4_supported = (ltssm_ts_data_rate_eg6[3] & captured_ts_data_rate_eg6[3]);
// gen5 speed is supported by both sides of the link (gen 1 speed must always be supported)
assign  gen5_supported = (ltssm_ts_data_rate[4] & captured_ts_data_rate[4]);
// gen6 speed is supported by both sides of the link (gen 1 speed must always be supported)
assign  gen6_supported = (ltssm_ts_data_rate_eg6[5] & captured_ts_data_rate_eg6[5]);

// for Recovery.RcvrLock -> Configuration
always @( posedge core_clk or negedge core_rst_n ) begin : common_gen1_supported_PROC
    if ( ~core_rst_n ) begin
        common_gen1_supported <= #TP 0;
    end else if ( ((lts_state == S_RCVRY_RCVRCFG && next_lts_state != S_RCVRY_RCVRCFG) || (lts_state == S_CFG_COMPLETE && next_lts_state != S_CFG_COMPLETE)) && ~clear ) begin
        common_gen1_supported <= #TP ~gen2_supported; // common rate only from Rcvry.RcvrCfg and Cfg.Complete + gen2_supported updates only when 8 TSs are received
    end
end // common_gen1_supported_PROC

// when core clock off in L1 and software sets cfg_target_link_speed and cfg_directed_speed_change,
// the ltssm_ts_data_rate_i has to refect the software updates so that go_recovery_speed_change asserts before core clock on.
// doing so is for directed_speed_change to be asserted for speed change when core clock is back on in the current Recovery round.
wire [4:0] ltssm_ts_data_rate_i = ((lts_state == S_L1_IDLE || lts_state_d == S_L1_IDLE) && cfg_directed_speed_change) ?
                                   (
                                    (cfg_target_link_speed == `GEN6_LINK_SP && ltssm_flit_mode_enable) ? 5'b10111 : // must be flit_mode
                                    cfg_target_link_speed == `GEN5_LINK_SP ? 5'b11111 :
                                    cfg_target_link_speed == `GEN4_LINK_SP ? 5'b01111 :
                                    cfg_target_link_speed == `GEN3_LINK_SP ? 5'b00111 :
                                    cfg_target_link_speed == `GEN2_LINK_SP ? 5'b00011 :
                                    5'b00001
                                   ) :
                                    ltssm_ts_data_rate;

wire [9:0] ltssm_ts_data_rate_i_eg6 = ltssm_ts_data_rate_i == 5'b10111 ? 10'b0000111111 : {5'h0, ltssm_ts_data_rate_i};

// enter recovery for speed change
assign  go_recovery_speed_change = cfg_directed_speed_change &&
                                    // if reached cxl_mode, go speed change directly from Gen1 rate without waiting for DL_Active
                                    (smlh_dl_active || init_eq_pending || ltssm_in_cxl_mode ) &&

                                   ( (ltssm_ts_data_rate_i[1] && latched_ts_data_rate_ever[1]) |
                                     (ltssm_ts_data_rate_i[2] && latched_ts_data_rate_ever[2]) |
                                     (ltssm_ts_data_rate_i_eg6[3] && latched_ts_data_rate_ever_eg6[3]) |
                                     (ltssm_ts_data_rate_i[4] && latched_ts_data_rate_ever[4]) |
                                     (ltssm_ts_data_rate_i_eg6[5] && latched_ts_data_rate_ever_eg6[5]) |
                                     (g2_rate) |
                                     (g3_rate) |
                                     (g5_rate) |
                                     (g6_rate) |
                                     (g4_rate) );


// Indicate the ltssm is in training
always @( * ) begin : ltssm_in_training_PROC
        ltssm_in_training      = 0;

        ltssm_in_training      = (lts_state == S_CFG_LINKWD_START ) |
                                 (lts_state == S_CFG_LINKWD_ACEPT ) |
                                 (lts_state == S_CFG_LANENUM_WAIT ) |
                                 (lts_state == S_CFG_LANENUM_ACEPT) |
                                 (lts_state == S_CFG_COMPLETE     ) |
                                 (lts_state == S_CFG_IDLE         ) |
                                 (lts_state == S_RCVRY_LOCK       ) |
                                 (lts_state == S_RCVRY_SPEED      ) |
                                 (lts_state == S_RCVRY_EQ0        ) |
                                 (lts_state == S_RCVRY_EQ1        ) |
                                 (lts_state == S_RCVRY_EQ2        ) |
                                 (lts_state == S_RCVRY_EQ3        ) |
                                 (lts_state == S_RCVRY_RCVRCFG    ) |
                                 (lts_state == S_RCVRY_IDLE       );
end // ltssm_in_training_PROC
// Indicate the ltssm is in Rcvry.Equalization states
always @( * ) begin : lts_state_rcvry_eq_PROC
        ltssm_state_rcvry_eq = 0;

        ltssm_state_rcvry_eq = (lts_state == S_RCVRY_EQ0) |
                               (lts_state == S_RCVRY_EQ1) |
                               (lts_state == S_RCVRY_EQ2) |
                               (lts_state == S_RCVRY_EQ3) ;
end // lts_state_rcvry_eq_PROC



always @( posedge core_clk or negedge core_rst_n ) begin : latched_rcvd_2_unexpect_ts_PROC
    if ( ~core_rst_n ) begin
        latched_rcvd_2_unexpect_ts <= #TP 0;
    end else if ( lts_state != S_L0 ) begin
        latched_rcvd_2_unexpect_ts <= #TP 0;
    end else if ( smlh_ltssm_in_l0p) begin // ignored negotiation lanes for l0p
        latched_rcvd_2_unexpect_ts <= #TP (link_any_exact_2_ts_l0p_rcvd && ~clear) ? 1 : latched_rcvd_2_unexpect_ts;
    end else if ( link_any_exact_2_ts_rcvd && ~clear ) begin
        latched_rcvd_2_unexpect_ts <= #TP 1;
    end
end // latched_rcvd_2_unexpect_ts_PROC

reg l0_link_rcvry_en;
//
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        l0_link_rcvry_en      <= #TP 1'b0;
    else
        l0_link_rcvry_en      <= #TP ( latched_rcvd_2_unexpect_ts | xdlh_smlh_start_link_retrain | directed_recovery | rmlh_deskew_alignment_err
                                     // IN flit mode if xplh times out in sequence number handshake it will direct LTSSM to recovery
                                     | xplh_smlh_req_rcvry
                                     | go_recovery_speed_change
                                     //from Gen1 to speed up to Gen3, or to speed up to Gen5 (USP) for skip_eq if both sides advertise >= Gen3 rate before linkup in Configuration state
                                     //if set cfg_ccix_esm_enable and esm data rate 0/1, then the link retrain bit must be set according to CCIX spec. directed_recovery drives ltssm to Recovery state
                                     | (init_eq_pending & (g1_rate))
                                     //Gen3 spec: an EIEOS is received on any configured Lane in 128b/130b encoding, move from L0 to Recovery.
                                     //cannot get all lanes rcvd EIEOS at the end of Block at same time as RxDataValid can be anywhere within a Block.
                                     //if not at same time, framing error, move to receovery anyway
                                     | rmlh_goto_recovery
                                     | equalization_req
                                     | init_eq_pending_g4
                                     | latched_remote_soft_eq_g4
                                     | init_eq_pending_g5
                                     | latched_remote_soft_eq_g5
                                     | init_eq_pending_g6
                                     | latched_remote_soft_eq_g6
                                     | latched_cdm_ras_des_recovery_req
                                     | spif_smlh_req_retrain
                                     | l0p_goto_recovery
                                     | go_recovery_link_width_change
                                     | rtlh_req_link_retrain | eidle_inferred_recovery);



// no need to send Idle data in Rcvry.Idle if directed to HotReset, Lpbk, Cfg, Disabled state
always @(posedge core_clk or negedge core_rst_n) begin : no_idle_need_sent_PROC
    if (!core_rst_n) begin
        no_idle_need_sent <= #TP 0;
    end else begin
        if ( (lts_state != S_RCVRY_IDLE) && (next_lts_state == S_RCVRY_IDLE) && !clear &&
             (
                (latched_direct_rst || cfg_lpbk_en || cfg_gointo_cfg_state
                                                   || directed_link_width_change
                                                   || ((!cfg_upstream_port
                                                    ) && cfg_link_dis))
                // Flit mode, all lanes rcvd 8 ts2 with match link/lane# and on any lane these rcvd 8 ts2 with either hot reset, disable link, or loopback bit set
                || ( ltssm_flit_mode_enable && link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd
                     && ((cfg_upstream_port && (link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd || link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd)) || link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd) )
             )
            )
            no_idle_need_sent <= #TP 1;
        else if (lts_state == S_RCVRY_IDLE && next_lts_state != S_RCVRY_IDLE && !clear)
            no_idle_need_sent <= #TP 0;
    end
end

assign ltssm_no_idle_need_sent = no_idle_need_sent;

always @( posedge core_clk or negedge core_rst_n ) begin : smlh_pm_state_trans1_flag_PROC
    if ( ~core_rst_n ) begin
        smlh_pm_state_trans1_flag <= #TP 0;
    end
    else if(|xmtbyte_ts1_sent) begin
        smlh_pm_state_trans1_flag <= #TP 0;
    end
    else if((smlh_ltssm_state == S_L0) && l0_link_rcvry_en && !clear) begin
        smlh_pm_state_trans1_flag <= #TP 1;
    end
end

reg    r_smlh_pm_state_trans2_flag;
always @( posedge core_clk or negedge core_rst_n ) begin : smlh_pm_state_trans2_flag_PROC
    if ( ~core_rst_n ) begin
        r_smlh_pm_state_trans2_flag <= #TP 0;
    end
    else if(smlh_ltssm_in_l0p && xmtbyte_l0p_state_in_upsize) begin
        r_smlh_pm_state_trans2_flag <= #TP 1;
    end else begin
        r_smlh_pm_state_trans2_flag <= #TP 0;
    end
end
assign smlh_pm_state_trans2_flag = r_smlh_pm_state_trans2_flag;

// outputs from state machine
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        ltssm_cmd                   <= #TP `XMT_IN_EIDLE;
        ltssm_xlinknum              <= #TP 0;
        ltssm_xk237_4lnknum         <= #TP {NL{1'b1}};
        ltssm_xk237_4lannum         <= #TP {NL{1'b1}};
        ltssm_eidle_cnt             <= #TP 3'd0;
    end
    else if (cfg_force_en && cfg_forced_ltssm_cmd!=4'h0)
        ltssm_cmd <= #TP cfg_forced_ltssm_cmd;
    else

             case (lts_state)
        S_DETECT_QUIET:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_PRE_DETECT_QUIET:
            if (xmtbyte_eidle_sent | latched_eidle_sent | (ltssm_cmd == `XMT_IN_EIDLE))
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else
            begin
            ltssm_cmd               <= #TP `SEND_EIDLE;
            ltssm_eidle_cnt         <= #TP (g2_rate) ? 3'h1: 3'h0; //1 for gen1/3, 2 for gen2
            end
        S_DETECT_ACT: begin
            if ((current_powerdown == `P1) && !int_rxdetect_done && !cdm_ras_des_force_rxdetected_en )
                ltssm_cmd           <= #TP `SEND_RCVR_DETECT_SEQ;
            else
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            ltssm_eidle_cnt         <= #TP (g2_rate) ? 3'h1: 3'h0;
        end
        S_DETECT_WAIT:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_POLL_ACTIVE: begin
            ltssm_cmd               <= #TP ((current_powerdown == `P0) && !cfg_enter_compliance) ? `SEND_TS1
                                                : (ltssm_cmd == `SEND_TS1) ? `SEND_TS1
                                                : (!(ts_sent_in_poll_active | xmtbyte_ts1_sent[0] | xmtbyte_ts2_sent[0]) & cfg_enter_compliance) ? `XMT_IN_EIDLE : ltssm_cmd;
            ltssm_xk237_4lnknum     <= #TP {NL{1'b1}};
            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
        end
        S_POLL_COMPLIANCE:
            if (curnt_compliance_state == S_COMPL_IDLE)
                ltssm_cmd           <= #TP ltssm_cmd;
            else if (curnt_compliance_state == S_COMPL_ENT_TX_EIDLE) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP 3'h1;
            end
            else if (curnt_compliance_state == S_COMPL_ENT_SPEED_CHANGE)
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else if (curnt_compliance_state == S_COMPL_TX_COMPLIANCE) begin
                ltssm_cmd           <= #TP send_mod_compliance ? `MOD_COMPL_PATTERN : `COMPLIANCE_PATTERN;
            end else if (curnt_compliance_state == S_COMPL_EXIT_TX_EIDLE) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP ((|current_data_rate)
                                             | latched_enter_compliance
                                           ) ? 3'd7 : 3'd0; //8 for not 2.5GT/s
            end
            else if ((curnt_compliance_state == S_COMPL_EXIT_SPEED_CHANGE) || (curnt_compliance_state == S_COMPL_EXIT_IN_EIDLE))
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
        S_POLL_CONFIG: begin
            ltssm_cmd               <= #TP `SEND_TS2;
            ltssm_xk237_4lnknum     <= #TP {NL{1'b1}};
            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
        end
        S_CFG_LINKWD_START: begin
            ltssm_cmd               <= #TP `SEND_TS1;

            ltssm_xlinknum          <= #TP !smlh_link_up ? xmt_ts_lnknum : ltssm_xlinknum;     //Errata A36

            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
            if (!cfg_upstream_port && ~(cfg_lpbk_en || latched_cfg_link_dis) && !cfglwstart_upconf_dsp )
                ltssm_xk237_4lnknum <= #TP {NL{1'b0}};
            else
                ltssm_xk237_4lnknum <= #TP {NL{1'b1}};
        end
        S_CFG_LINKWD_ACEPT: begin
            ltssm_cmd               <= #TP `SEND_TS1;
            ltssm_xk237_4lannum     <= #TP {NL{1'b1}};
            ltssm_xk237_4lnknum     <= #TP !cfg_upstream_port ? {NL{1'b0}} : ~latchd_smlh_lanes_rcving; // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_LANENUM_WAIT: begin
            ltssm_cmd               <= #TP `SEND_TS1;
            ltssm_xk237_4lannum     <= #TP ~latchd_smlh_lanes_rcving;  // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xk237_4lnknum     <= #TP ~latchd_smlh_lanes_rcving;
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_LANENUM_ACEPT: begin
            ltssm_cmd               <= #TP `SEND_TS1;
            ltssm_xk237_4lannum     <= #TP ~latchd_smlh_lanes_rcving;  // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xk237_4lnknum     <= #TP ~latchd_smlh_lanes_rcving;
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_COMPLETE: begin
            ltssm_cmd               <= #TP `SEND_TS2;
            ltssm_xk237_4lannum     <= #TP ~latchd_smlh_lanes_rcving;  // for the lanes do not receive TS with same link num, we need to put PAD out
            ltssm_xk237_4lnknum     <= #TP ~latchd_smlh_lanes_rcving;
            ltssm_xlinknum          <= #TP xmt_ts_lnknum;
        end
        S_CFG_IDLE:
            ltssm_cmd               <= #TP `SEND_IDLE;
        S_L0 :
            ltssm_cmd               <= #TP `NORM;
        S_L0S:
            if (curnt_l0s_xmt_state == S_L0S_XMT_EIDLE) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (g2_rate) ? 3'd1 : 3'd0;
            end
            else if ((curnt_l0s_xmt_state == S_L0S_XMT_FTS) & !xmtbyte_fts_sent)
                ltssm_cmd           <= #TP `SEND_N_FTS;
            else if ((curnt_l0s_xmt_state == S_L0S_EXIT_WAIT)
                    |(curnt_l0s_xmt_state == S_L0S_XMT_IDLE)
                    |(curnt_l0s_xmt_state == S_L0S_XMT_WAIT))
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else
                ltssm_cmd           <= #TP `NORM;
        S_RCVRY_LOCK:
            if (current_powerdown == `P0) begin
              if ((ltssm_cmd != `NORM) || xmtbyte_cmd_is_data )
                ltssm_cmd           <= #TP `SEND_TS1;
              else
                ltssm_cmd           <= #TP ltssm_cmd;
            end else
                ltssm_cmd           <= #TP ltssm_cmd;
        S_RCVRY_EQ0: begin
                ltssm_cmd           <= #TP `SEND_TS1;
                ltssm_xlinknum      <= #TP perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? latched_xmt_ts_lnknum : ltssm_xlinknum;
                ltssm_xk237_4lannum <= #TP perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? 0 : ltssm_xk237_4lannum;
                ltssm_xk237_4lnknum <= #TP perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? 0 : ltssm_xk237_4lnknum;
        end
        S_RCVRY_EQ1: begin
                ltssm_cmd           <= #TP `SEND_TS1;
                ltssm_xlinknum      <= #TP perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? latched_xmt_ts_lnknum : ltssm_xlinknum;
                ltssm_xk237_4lannum <= #TP perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? 0 : ltssm_xk237_4lannum;
                ltssm_xk237_4lnknum <= #TP perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? 0 : ltssm_xk237_4lnknum;
        end
        S_RCVRY_EQ2:
                ltssm_cmd           <= #TP `SEND_TS1;
        S_RCVRY_EQ3:
                ltssm_cmd           <= #TP `SEND_TS1;
        S_RCVRY_RCVRCFG: begin
                ltssm_cmd           <= #TP `SEND_TS2;
                // if in flit mode and directed_link_width_change for reliability, send PAD for link number on lanes to be removed. Stop sending PAD if we go anywhere else but Cfg.LinkWidth.Start
                for (int n = 0; n < NL; n++) begin
                    ltssm_xk237_4lnknum[n] <= #TP (ltssm_flit_mode_enable && directed_link_width_change && latched_valid_reliability_link_width_change && (n >= latched_target_link_width) && ((next_lts_state == S_RCVRY_RCVRCFG) || (next_lts_state == S_CFG_LINKWD_START))) ? 1'b1 : 1'b0;
                end
        end
        S_RCVRY_IDLE: begin
            if (no_idle_need_sent)
                ltssm_cmd           <= #TP ltssm_cmd; // Keep sending TS2 in this state when directed into config/loopback/disabled/hotreset
            else
                ltssm_cmd           <= #TP `SEND_IDLE;
        end
        S_RCVRY_SPEED:
            if (xmtbyte_eidle_sent | latched_eidle_sent)
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            else begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (g2_rate) ? 3'd1 : 3'd0;
            end

        S_L1_IDLE:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_L123_SEND_EIDLE:
            if (xmtbyte_eidle_sent | latched_eidle_sent)
                ltssm_cmd           <= #TP `XMT_IN_EIDLE;
            // for upstream port, we will send one EIDLE order set at this set
            // for downstream port, we will send one EIDLE order set after
            // we received eidle order set which indicates remote port is
            // in L1 or L23
            else if ((latched_rcvd_eidle_set | smlh_l123_eidle_timeout | cfg_upstream_port) & (pm_smlh_entry_to_l1 | pm_smlh_entry_to_l2) & ~pre_cxl_l1_abort_exit) begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (g2_rate) ? 3'd1 : 3'd0;
            end
        S_L2_IDLE:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_L2_WAKE:
// ccx_line_begin: ; unreachable because PM block doesn't make the condition for LTSSM from S_L2_IDLE to S_L2_WAKE for USP. No S_L2_WAKE state for DSP.
            ltssm_cmd               <= #TP `SEND_BEACON;
// ccx_line_end
        S_HOT_RESET_ENTRY:
            ltssm_cmd               <= #TP `SEND_TS1;
        S_HOT_RESET:
            ltssm_cmd               <= #TP `SEND_TS1;
        S_DISABLED_ENTRY: begin
            ltssm_cmd               <= #TP `SEND_TS1;
        end
        S_DISABLED_IDLE: begin
            if ( cfg_pl_gen3_zrxdc_noncompl && (xmtbyte_eidle_sent || latched_eidle_sent) ) begin
                ltssm_cmd           <= #TP `XMT_IN_EIDLE; //change speed to Gen1
            end else 
            begin
                ltssm_cmd           <= #TP `SEND_EIDLE;
                ltssm_eidle_cnt     <= #TP (g2_rate) ? 3'd1 : 3'd0;
            end
        end
        S_DISABLED:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        S_LPBK_ENTRY:
            if (curnt_lpbk_entry_state == S_LPBK_ENTRY_IDLE) begin
                ltssm_cmd           <= #TP ltssm_cmd;
            end else if (curnt_lpbk_entry_state == S_LPBK_ENTRY_ADV)
                ltssm_cmd           <= #TP `SEND_TS1;
            else if (curnt_lpbk_entry_state == S_LPBK_ENTRY_EIDLE)
                if (xmtbyte_eidle_sent | latched_eidle_sent)
                    ltssm_cmd       <= #TP `XMT_IN_EIDLE;
                else begin
                    ltssm_cmd       <= #TP `SEND_EIDLE;
                    ltssm_eidle_cnt <= #TP (g2_rate) ? 3'd1 : 3'd0;
                end
            else if (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS) begin
                //Slave sends TS1s with Link#/Lane# set to PAD
                //if last state is EQ, it is >= gen5 rate, need keep the previous EQ link#/lane# for scrambling seed
                ltssm_cmd              <= #TP `SEND_TS1;
                ltssm_xk237_4lnknum    <= #TP lpbk_master || (last_state_is_eq && goe_g5) ? ltssm_xk237_4lnknum : {NL{1'b1}};
                ltssm_xk237_4lannum    <= #TP lpbk_master || (last_state_is_eq && goe_g5) ? ltssm_xk237_4lannum : {NL{1'b1}};
            end
        S_LPBK_ACTIVE: begin
            ltssm_cmd               <= #TP (tx_mod_cmpl_pattern_in_lpbk && goe_g5) ? `MOD_COMPL_PATTERN : (((ltssm_cfg_to_lpbk && ~lpbk_master) || perform_eq_for_loopback ) && current_data_rate >= `GEN5_RATE) ? `XMT_IN_EIDLE :  `NORM;
        end
        S_LPBK_EXIT:
            if (lpbk_master) begin
                if ((ltssm_cmd != `NORM) || xmtbyte_cmd_is_data) begin
                    ltssm_cmd       <= #TP `SEND_EIDLE;
                    ltssm_eidle_cnt <= #TP 3'd7;
                end else begin
                    ltssm_cmd       <= #TP ltssm_cmd;
                end
            end
            else
                ltssm_cmd           <= #TP ltssm_cmd;
        S_LPBK_EXIT_TIMEOUT:
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
        default: // S_DETECT_QUIET
// ccx_line_begin: ; Redundant code for case default item.
            ltssm_cmd               <= #TP `XMT_IN_EIDLE;
// ccx_line_end
    endcase

wire   current_powerdown_p0;
reg    current_powerdown_p0_d;
wire   current_powerdown_p0_rising_edge;
assign current_powerdown_p0 = (current_powerdown == `P0);
always @(posedge core_clk or negedge core_rst_n) begin : current_powerdown_p0_d_PROC
    if (~core_rst_n)
        current_powerdown_p0_d <= #TP 0;
    else if (~((next_lts_state == S_POLL_ACTIVE) | (next_lts_state == S_RCVRY_LOCK)) && ~clear)
        current_powerdown_p0_d <= #TP 0;
    else
        current_powerdown_p0_d <= #TP current_powerdown_p0;
end //always
assign current_powerdown_p0_rising_edge = (current_powerdown_p0 & ~current_powerdown_p0_d);

always_comb begin : pre_cxl_l1_abort_exit_PROC
  if ((pm_smlh_l1_exit || rcvd_2_unexpect_ts) && lts_state==S_L123_SEND_EIDLE && cxl_link_enable_d) begin
    pre_cxl_l1_abort_exit = 1'b1;
  end else if (lts_state!=S_L123_SEND_EIDLE) begin
    pre_cxl_l1_abort_exit = 1'b0;
  end else begin
    pre_cxl_l1_abort_exit = cxl_l1_abort_exit;
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : cxl_l1_abort_exit_PROC
  if (!core_rst_n) begin
    cxl_l1_abort_exit <= #TP 1'b0;
  end else begin
    cxl_l1_abort_exit <= #TP pre_cxl_l1_abort_exit;
  end
end

// Clear 40ns timer to satisfy Ttx-idle-min for CXL L1 abort scenario
// timeout_40ns is cleared at a posedge cycle of pre_cxl_l1_abort_exit for a case where int_mac_phy_txelecidle_r is already asserted when cxl_l1_abort_exit is 1.
assign clr_40ns_timer = (pre_cxl_l1_abort_exit && !cxl_l1_abort_exit) || (cxl_l1_abort_exit && |(int_mac_phy_txelecidle_r & ~int_mac_phy_txelecidle_rr));

localparam CLEAR_WD = 1;
reg   [CLEAR_WD-1:0] r_clear;
assign clear       = r_clear[0];
assign clear_o     = r_clear[0];
assign clear_eqctl = r_clear[0];
assign clear_seq   = r_clear[0];
assign clear_link  = r_clear[0];

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        r_clear                 <= #TP 0;
        l0s_state_clear         <= #TP 0;
     end else if (cdm_ras_des_ltssm_stop) begin
        r_clear                 <= #TP 0;
        l0s_state_clear         <= #TP 0;
     end else if (cfg_force_state) begin
        r_clear                 <= #TP {CLEAR_WD{1'b1}};
        l0s_state_clear         <= #TP 0;
     end else begin
        // Register the outputs
       r_clear                 <= #TP {CLEAR_WD{( !clear & ((next_lts_state != lts_state) || app_ltssm_enable_fall_edge)) // Clear counters on a state change
                                       | ((curnt_compliance_state == S_COMPL_ENT_TX_EIDLE)  && (curnt_compliance_state_d1 != S_COMPL_ENT_TX_EIDLE))
                                       | ((curnt_compliance_state == S_COMPL_EXIT_TX_EIDLE) && (curnt_compliance_state_d1 != S_COMPL_EXIT_TX_EIDLE))
                                       | ((lts_state == S_LPBK_ENTRY) & lpbk_clear)
                                       | pre_l0p_clear
                                       | (((lts_state == S_POLL_ACTIVE) | (lts_state == S_RCVRY_LOCK)) & (current_powerdown_p0_rising_edge)) // clear counter on current_powerdown = P0 rising edge during few states that is involved in power state change according PIPE spec.
                                       }};
        l0s_state_clear         <= #TP !l0s_state_clear & (next_l0s_xmt_state != curnt_l0s_xmt_state);
    end

// latch the next state while hold ltssm is on 
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        latched_next_lts_state <= #TP S_DETECT_QUIET;
        latched_next_lts_flag  <= #TP 1'b0;
    end
    else if (cdm_ras_des_ltssm_stop) begin
        if(!latched_next_lts_flag && lts_state != next_lts_state) begin
            latched_next_lts_state <= #TP next_lts_state;
            latched_next_lts_flag  <= #TP 1'b1;
        end
    end
    else begin
        latched_next_lts_state <= #TP latched_next_lts_state;
        latched_next_lts_flag  <= #TP 1'b0;
    end


always @(*) begin
    if (app_ltssm_enable_fall_edge || smlh_req_linkerror) begin
        lts_state_wire    = S_PRE_DETECT_QUIET;                         // send EIOS and change speed back to Gen1 if needed
    end else if (!app_ltssm_enable_dd && (lts_state != S_PRE_DETECT_QUIET)) begin // protect pre-detect-quiet state from forced transitions
        lts_state_wire    = S_DETECT_QUIET;
    end else
       if (cfg_force_state ) begin
        lts_state_wire    = ltssm_state_e'(cfg_forced_ltssm); // static cast for conversion to enum type
    // hold ltssm - stop the state transition 
    end else if (cdm_ras_des_ltssm_stop) begin
        lts_state_wire    = lts_state;
    // release the next state transition
    end else if (latched_next_lts_flag) begin
        lts_state_wire    = latched_next_lts_state;
    end else if (!clear) begin
        lts_state_wire    = next_lts_state;
    end else begin
        lts_state_wire    = lts_state;
    end
end

// replicates ltssm state register to resolve synthesis timing closure issue because of massive fan-outs
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        lts_state                    <= #TP S_DETECT_QUIET;
        smlh_ltssm_state             <= #TP S_DETECT_QUIET;
    end else begin
        lts_state                    <= #TP lts_state_wire;
        smlh_ltssm_state             <= #TP lts_state_wire;
    end
end

// Output combination signal. Put pipe-line in each received module.
always_comb begin
    smlh_ltssm_state_wire   = lts_state_wire ;    
end


// Save the last state
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        last_lts_state         <= #TP S_DETECT_QUIET;
    else if (app_ltssm_enable_fall_edge) // 1->0 transition
        last_lts_state         <= #TP S_PRE_DETECT_QUIET; // send EIOS and change speed back to Gen1 if needed
    else if (!app_ltssm_enable_dd && (lts_state != S_PRE_DETECT_QUIET)) // protect pre-detect-quiet state from forced transitions
        last_lts_state         <= #TP S_DETECT_QUIET;
    else if (clear)
        last_lts_state         <= #TP last_lts_state;
    else if ((lts_state != next_lts_state) && !clear)
        last_lts_state         <= #TP lts_state;

reg error_entr_l1;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        error_entr_l1         <= #TP 0;
    else if ((next_lts_state == S_L1_IDLE) && (lts_state == S_L123_SEND_EIDLE) && timeout_2ms && !clear)
        error_entr_l1         <= #TP 1'b1;
    else if (lts_state != S_L1_IDLE)
        error_entr_l1         <= #TP 0;

always @(posedge core_clk or negedge core_rst_n) begin
  if ( !core_rst_n )
    ds_timeout_2ms <= #TP 1'b0;
  else if ( (lts_state == S_HOT_RESET_ENTRY) & timeout_hot_reset & !cfg_upstream_port && ~clear)
    ds_timeout_2ms <= #TP 1'b1;
  else if ( lts_state == S_PRE_DETECT_QUIET )
    ds_timeout_2ms <= #TP 1'b0;
end

reg latched_to_idle_timeout;
always @(posedge core_clk or negedge core_rst_n) begin : latched_to_idle_timeout_PROC
    if ( !core_rst_n )
        latched_to_idle_timeout <= #TP 1'b0;
    else begin
        if ( (lts_state == S_CFG_COMPLETE && next_lts_state == S_CFG_IDLE && timeout_2ms && !clear) ||
             (lts_state == S_RCVRY_RCVRCFG && next_lts_state == S_RCVRY_IDLE && timeout_48ms && !clear) )
            latched_to_idle_timeout <= #TP 1'b1;
        else if ( !clear && ((lts_state == S_CFG_IDLE && next_lts_state != S_CFG_IDLE) ||
                  (lts_state == S_RCVRY_IDLE && next_lts_state != S_RCVRY_IDLE)) )
            latched_to_idle_timeout <= #TP 1'b0;
    end
end

reg [4:0] pset_map_eieos_cnt;
reg       int_ltssm_cmd_send_eieos_for_pset_map;
reg       int_ltssm_usp_eq_redo;

always @( posedge core_clk or negedge core_rst_n ) begin : pset_map_eieos_cnt_PROC
    if ( ~core_rst_n ) begin
        pset_map_eieos_cnt <= #TP 0;
    end else if ( clear || ~ltssm_cmd_send_eieos_for_pset_map ) begin
        pset_map_eieos_cnt <= #TP 0;
    end else if ( xmtbyte_eies_sent || xmtbyte_ts1_sent[0] || xmtbyte_ts2_sent[0]) begin
        pset_map_eieos_cnt <= #TP pset_map_eieos_cnt + 1;
    end
end // pset_map_eieos_cnt_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_cmd_send_eieos_for_pset_map_PROC
    if ( ~core_rst_n ) begin
        ltssm_cmd_send_eieos_for_pset_map <= #TP 0;
        ltssm_usp_eq_redo                 <= #TP 0;
    end else begin
        ltssm_cmd_send_eieos_for_pset_map <= #TP int_ltssm_cmd_send_eieos_for_pset_map;
        ltssm_usp_eq_redo                 <= #TP int_ltssm_usp_eq_redo;
    end
end // pset_map_eieos_cnt_PROC


always @( posedge core_clk or negedge core_rst_n ) begin : latched_xmtbyte_eies_sent_PROC
    if ( ~core_rst_n ) begin
        latched_xmtbyte_eies_sent <= #TP 0;
    end else if ( clear ) begin
        latched_xmtbyte_eies_sent <= #TP 0;
    end else if ( xmtbyte_eies_sent ) begin
        latched_xmtbyte_eies_sent <= #TP 1;
    end
end // latched_xmtbyte_eies_sent_PROC

reg cfg_complete_condition_d, any_cxl_20_dsp_apn_mismatched_d;

always @( posedge core_clk or negedge core_rst_n ) begin : cfg_complete_d_PROC
    if ( ~core_rst_n ) begin
        cfg_complete_condition_d        <= #TP 0;
        any_cxl_20_dsp_apn_mismatched_d <= #TP 0;
    end else begin
        cfg_complete_condition_d        <= #TP (link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd & link_xmlh_16_ts2_sent_after_1_ts2_rcvd & deskew_complete_i);
        any_cxl_20_dsp_apn_mismatched_d <= #TP (|cxl_20_dsp_apn_mismatched);
    end
end // cfg_complete_d_PROC

// gen6 base spec says:
// Equalization to 64.0 GT/s from 2.5 GT/s or 5.0 GT/s is not supported. All equalization procedures at the 64.0 GT/s data
// rate, including re-equalization, must be initiated from the 32.0 GT/s data rate only.
reg p_g5_c_g6_from_rcvry_speed; // previous gen5 rate and current gen6 rate when entering/exiting to/from Recovery.Speed state -> Recovery.RcvrLock

// When the perform_equalization_for_loopback variable is 1b and the Downstream Port's Flit Mode Supported field of its
// PCI Express Capabilities Register is set to 1b, Phase 2 and Phase 3 must be executed
wire lpbk_eq23_must_do = (perform_eq_for_loopback || perform_eq_for_lpbk_mstr) & cfg_pcie_cap_flit_mode_sup;

always @( * ) begin : next_lts_state_PROC
        ltssm_in_hotrst_dis_entry = 1'b0;
        int_rcvd_8_ts2_skip_eq = 0;
        cfgcmpl_all_8_ts2_rcvd = 0;
        int_rcvd_8_ts2_noeq_nd = 0;
        int_bypass_gen3_eq = bypass_g3_eq;
        int_bypass_gen4_eq = bypass_g4_eq;
        int_rcvd_8expect_ts1 = 0;
        int_ltssm_cmd_send_eieos_for_pset_map = 0;
        int_ltssm_usp_eq_redo                 = 0;
             case (lts_state)
        S_DETECT_QUIET: begin
            if ( app_ltssm_enable_dd
                && (current_powerdown == `P1) // If there was a power state change, wait until phystatus is received
                && ((timeout_detect_quiet || any_phy_mac_rxeidle_exit) && all_phystatus_deasserted) ) begin
                next_lts_state   = S_DETECT_ACT;
            end else
                next_lts_state   = S_DETECT_QUIET;

            cfgcmpl_all_8_ts2_rcvd = 0;
            int_rcvd_8_ts2_noeq_nd = 0;
            int_bypass_gen3_eq = 1'b1;
            int_bypass_gen4_eq = 1'b1;
        end
        S_PRE_DETECT_QUIET: begin
            if (&int_mac_phy_txelecidle_r
               && !(|latched_detect_speed)
               && !app_ltssm_enable_fall_edge && timeout_1us && !clear
               ) begin
                next_lts_state   = S_DETECT_QUIET;
            end else if (|latched_detect_speed && (g1_rate) && timeout_1ms
 && pipe_regif_all_idle) begin //change speed to gen1
                next_lts_state   = S_DETECT_QUIET;
            end else if ( timeout_48ms ) begin // This transition is not possible under normal conditions.
                next_lts_state   = S_DETECT_QUIET;
            end else
                next_lts_state   = S_PRE_DETECT_QUIET;
        end
        S_DETECT_ACT: begin
        // when all lanes detected receiver
        // or when the number of lanes detected receiver matched the
        // last time in this state
            if (int_rxdetect_done & ((all_phy_mac_rxdetected & ~retry_detect) | (any_phy_mac_rxdetected & retry_detect & same_detected_lanes)
                 | (cfg_auto_flip_en & cfg_auto_flip_using_predet_lane & int_rxdetected[0])
                )) begin
                next_lts_state   = S_POLL_ACTIVE;
            end else if ((int_rxdetect_done & !any_phy_mac_rxdetected)
                      | (int_rxdetect_done & any_phy_mac_rxdetected & !same_detected_lanes & retry_detect)
                      | (int_rxdetect_done & cfg_auto_flip_en & cfg_auto_flip_using_predet_lane & !int_rxdetected[0])
                     ) begin
                next_lts_state   = S_DETECT_QUIET;
             end else if (int_rxdetect_done & any_phy_mac_rxdetected & !retry_detect) begin
                next_lts_state   = S_DETECT_WAIT;
             end else
                next_lts_state   = S_DETECT_ACT;
        end
        S_DETECT_WAIT:
            if (timeout_detect_wait) begin
                next_lts_state   = S_DETECT_ACT;
            end else
                next_lts_state   = S_DETECT_WAIT;

        S_POLL_ACTIVE: begin
            if (current_powerdown == `P0) begin
                if (cfg_enter_compliance) begin
                    next_lts_state = S_POLL_COMPLIANCE;
                end else
                if ( link_latched_live_all_8_ts_plinkn_planen_rcvd
                     && (link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd || link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd || link_latched_live_all_8_ts2_plinkn_planen_rcvd)
                     && xmtbyte_1024_ts_sent ) begin
                    // 8 ts are rcvd with pad link/lane# on all lanes
                    next_lts_state = S_POLL_CONFIG;
               end else if ( timeout_poll_active) begin
                    if ( link_latched_live_any_8_ts_plinkn_planen_rcvd && link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd && all_predet_lane_latchd_rxeidle_exit //ts_rcvd_1024_sent: 1024 TSs sent after receiving one TS
                          && (link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd || link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd || link_latched_live_any_8_ts2_plinkn_planen_rcvd) //don't check compl_rcv and lpbk if receiving TS2
                       ) begin
                        next_lts_state = S_POLL_CONFIG;
                    end
                    else if ( link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd && ~clear ) begin
                        next_lts_state = S_POLL_COMPLIANCE;
                        int_rcvd_8expect_ts1 = 1'b1;
                    end
                    else if ( any_predet_lane_latched_rxeidle ) begin
                        // not all predet lanes exit rxelecidle
                        next_lts_state = S_POLL_COMPLIANCE;
                    end
                    else begin
                        next_lts_state = S_PRE_DETECT_QUIET;
                    end
                end else // !timeout_24ms
                    next_lts_state = S_POLL_ACTIVE;
            end else // !current_powerdown == `P0
                next_lts_state = S_POLL_ACTIVE;
        end
        S_POLL_COMPLIANCE: begin
            if (curnt_compliance_state == S_COMPL_EXIT) begin
                next_lts_state = S_POLL_ACTIVE;
            end
            // move the ltssm state from Polling.Compliance to Detect
            else if (cdm_ras_des_direct_poll_cmp_to_det) begin
                next_lts_state = S_PRE_DETECT_QUIET;
            end
            else
                next_lts_state = S_POLL_COMPLIANCE;
        end
        S_POLL_CONFIG: begin
            //use latched signal because the other end may move to Configuration and start to send ts1s
            //while the near end is still sending 16 ts2s.
            if (link_latched_live_any_8_ts2_plinkn_planen_rcvd && link_xmlh_16_ts2_sent_after_1_ts2_rcvd) begin
                next_lts_state = S_CFG_LINKWD_START;
            end else if (timeout_poll_config) begin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else
                next_lts_state = S_POLL_CONFIG;
        end
        S_CFG_LINKWD_START: begin
            if ( ~cfg_upstream_port ) begin // DSP
                if ( latched_cfg_link_dis ) begin
                    next_lts_state = S_DISABLED_ENTRY;
                end else if ( cfg_lpbk_en ) begin
                    next_lts_state   = S_LPBK_ENTRY;
                end else if ( link_latched_live_all_2_ts1_lpbk1_rcvd || (any_2_ts1_lpbk1_ebth1_rcvd_g5) ) begin // any_2_ts1_lpbk1_ebth1_rcvd_g5: Eq Bypass To Highest common gen5 rate
                    next_lts_state = S_LPBK_ENTRY;
                end else if ( link_any_2_ts1_linknmtx_planen_rcvd ) begin
                    next_lts_state = S_CFG_LINKWD_ACEPT;
                end else if (timeout_cfg_linkwd_start) begin //32ms < 24ms + 50% margin
                    next_lts_state = S_PRE_DETECT_QUIET;
                end else begin
                    next_lts_state = S_CFG_LINKWD_START;
                end
            end else begin // USP
                if ( cfg_lpbk_en && link_any_2_ts1_rcvd && ~clear) begin
                    next_lts_state   = S_LPBK_ENTRY;
                end else if ( link_any_2_ts1_dis1_rcvd ) begin
                    next_lts_state = S_DISABLED_ENTRY;
                end else if ( link_latched_live_all_2_ts1_lpbk1_rcvd || (any_2_ts1_lpbk1_ebth1_rcvd_g5) ) begin
                    next_lts_state = S_LPBK_ENTRY;
                end else if ( 
                              (link_latched_live_all_2_ts1_linkn_planen_rcvd && latched_ts1_sent ) ) begin // ensure at least 1 ts1 sent
                    next_lts_state = S_CFG_LINKWD_ACEPT;
                end else if (timeout_cfg_linkwd_start ) begin //32ms < 24ms + 50% margin
                    next_lts_state = S_PRE_DETECT_QUIET;
                end else begin
                    next_lts_state = S_CFG_LINKWD_START;
                end
            end
        end
        S_CFG_LINKWD_ACEPT: begin
            if ( ~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_rcvd ) begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end else if ( cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanen_rcvd ) begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end else if ( link_latched_live_all_2_ts1_plinkn_planen_rcvd || timeout_cfg_linkwd_acept ) begin //3ms = 2ms + 50% margin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_LINKWD_ACEPT;
            end
        end
        S_CFG_LANENUM_WAIT: begin
            if ( (~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd) || (cfg_upstream_port && link_any_2_ts2_rcvd) ) begin
                next_lts_state = S_CFG_LANENUM_ACEPT;
            end else if ( (~cfg_upstream_port || timeout_1ms) && link_latched_live_any_2_ts1_lanendiff_linkn_rcvd ) begin
                // base spec: The Upstream Lanes are permitted delay up to 1 ms before transitioning to Configuration.Lanenum.Accept.
                // comment  : The "delay up to 1 ms" does not apply to DSP
                next_lts_state = S_CFG_LANENUM_ACEPT;
            end else if ( link_latched_live_all_2_ts1_plinkn_planen_rcvd || timeout_cfg_lanenum_wait ) begin //3ms = 2ms + 50% margin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end
        end
        S_CFG_LANENUM_ACEPT: begin
            // PCIe Gen5 errata for CXL:  If the use_modified_TS1_TS2_Ordered_Set variable is set to 1b and an Alternate Protocol Negotiation is being performed (cxl_enable == 1'b1), the transition to
            // Configuration.Complete must be delayed for 10us or until the Upstream Port responds to the protocol request (whichever happens first). This delay allows for a consensus to be reached.
            if ( ((~cfg_upstream_port && link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd && ((cxl_enable && ~smlh_link_up) ? (timeout_10us || req_protocol_respond_d) : 1'b1)) ||
                  (cfg_upstream_port && link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd && ((cxl_enable && ~smlh_link_up && link_latched_live_any_2_ts2_apn_rcvd) ? link_latched_live_all_2_ts2_apn_rcvd : 1'b1))) 
 && ~link_mode_changed ) begin
                next_lts_state = S_CFG_COMPLETE;
            end else if ( ~cfg_upstream_port && ((cxl_enable && ~smlh_link_up) ? ((timeout_10us || req_protocol_respond_d) && link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd) : link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge)
  && ~link_mode_changed ) begin
                // base spec: If two consecutive TS1 Ordered Sets are received with non-PAD Link and non-PAD Lane numbers that match all the non-PAD Link and non-PAD Lane numbers (ORRRRR reversed Lane numbers if Lane reversal
                // is optionally supported) that are being transmitted in Downstream Lane TS1 Ordered Sets, the next state is Configuration.Complete. This must be on all smlh_lanes_active. If not, move to S_CFG_LANENUM_WAIT.
                // The core performs Lane Reversal (see link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd_rising_edge for signal next_smlh_lane_flip_ctrl) and transition to S_CFG_COMPLETE immediately & at the same time as lane reversal
                // This is not for USP according to base spec.
                next_lts_state = S_CFG_COMPLETE;
            end else if ( link_latched_live_all_2_ts1_linknmtx_lanen_rcvd && link_mode_changed ) begin
                next_lts_state = S_CFG_LANENUM_WAIT;
            end else if ( link_latched_live_all_2_ts1_plinkn_planen_rcvd || timeout_cfg_lanenum_acept ) begin //3ms = 2ms + 50% margin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else begin
                next_lts_state = S_CFG_LANENUM_ACEPT;
            end
        end
        S_CFG_COMPLETE: begin
            //if ( link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd && link_xmlh_16_ts2_sent_after_1_ts2_rcvd && deskew_complete_i ) begin
            if ( cfg_complete_condition_d ) begin // delay one clock to break CXL (|cxl_20_dsp_apn_mismatched) timing
             // The physical layer LTSSM for DSP returns to Detect if Flex Bus enable bits are mismatched or "Retimer Present" and "Two Retimers Present" are mismatced.
              //if (|cxl_20_dsp_apn_mismatched) begin
              if ( any_cxl_20_dsp_apn_mismatched_d ) begin // break timing path
                next_lts_state = S_PRE_DETECT_QUIET;
                cfgcmpl_all_8_ts2_rcvd = 1'b1 & ~smlh_link_up;
              end else 
              begin
                next_lts_state = S_CFG_IDLE;
                int_rcvd_8_ts2_skip_eq = link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd & ~smlh_link_up; // skip eq on RX
                int_rcvd_8_ts2_noeq_nd = link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd & ~smlh_link_up; // no eq needed on RX including normal or mod TS2s
                cfgcmpl_all_8_ts2_rcvd = 1'b1 & ~smlh_link_up;
              end
            end else if ( timeout_cfg_complete ) begin
                if ( !(&idle_to_rlock) & ((g3_rate) || (g4_rate) || (g5_rate) || (goe_g6)) ) begin //idle_to_rlock < ffh & gen3 data rate
                  next_lts_state = S_CFG_IDLE;
                end else begin
                  next_lts_state = S_PRE_DETECT_QUIET;
                end
            end else begin
                next_lts_state = S_CFG_COMPLETE;
            end
        end
        S_CFG_IDLE: begin
            //not timeout from S_CFG_COMPLETE to S_CFG_IDLE for Gen3 rate
            if ( ( (((g3_rate) || (g4_rate) || (g5_rate)) && !latched_to_idle_timeout && rcvd_8idles && idle_16_sent) ||
                 (((g1_rate) || (g2_rate)) && rcvd_8idles && idle_16_sent)) && ~ltssm_flit_mode_enable ) begin
                next_lts_state = S_L0;
            end else if ( ltssm_flit_mode_enable && rcvd_8idles && idle_16_sent && !latched_to_idle_timeout ) begin // 32 Idle flits sent
                next_lts_state = S_L0;
            end else if ( timeout_cfg_idle ) begin
                if ( !(&idle_to_rlock) ) begin //idle_to_rlock < ffh
                    next_lts_state = S_RCVRY_LOCK;
                end else begin
                    next_lts_state = S_PRE_DETECT_QUIET;
                end
            end else
                next_lts_state = S_CFG_IDLE;

            int_rcvd_8_ts2_skip_eq = 0;
            int_rcvd_8_ts2_noeq_nd = 0;
            cfgcmpl_all_8_ts2_rcvd = 0;
        end
        S_L0: begin
        // when pm module direct this state machine to go into
        // L0s,l1,l2,l3, it will start the transition
        //
        // According to spec. electric idle set received will trig a entry
        //to power down state. It really means that we have detected
        //remote side with entering into low power state. It is upto PM
        //module to decide whether or not to enter into the low  poweri state
            // Detect transition caused by Replay Num Rollover x 4
            if (xdlh_smlh_goto_detect) begin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else
          if (l0_link_rcvry_en || deskew_complete_n_d) begin // see deskew_complete_n signal explanation, immediately move to Recovery if deskew_complete_n
                next_lts_state = S_RCVRY_LOCK;
            end
            else if (pm_smlh_prepare4_l123) begin
                next_lts_state = S_L123_SEND_EIDLE;
            // in case of EIOS delay by 40ns entrance into Rx L0s to avoid start looking too soon for rxelecidle=0 before rxelecidle has become stable high
            end else if (pm_smlh_entry_to_l0s | (latched_rcvd_eidle_set_4rl0s & timeout_40ns_4rl0s & cfg_l0s_supported & !pm_smlh_dllp_hs) | (r_curnt_l0s_rcv_state != S_L0S_RCV_ENTRY) | (curnt_l0s_xmt_state != S_L0S_XMT_ENTRY)) begin
                next_lts_state = S_L0S;
            end
            else if (latched_rcvd_eidle_set_4rl0s && !cfg_l0s_supported && !pm_smlh_dllp_hs) begin // Controller receives any eios for L0p operation in flit mode
                next_lts_state = S_RCVRY_LOCK;
            end 
            else
                next_lts_state = S_L0;
        end
        S_L0S: begin
            // Detect transition caused by Replay Num Rollover x 4
            if (xdlh_smlh_goto_detect) begin
                next_lts_state = S_PRE_DETECT_QUIET;
            end else
            if ((r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) & (curnt_l0s_xmt_state == S_L0S_XMT_ENTRY) & !(rcvr_l0s_goto_rcvry) & !(pm_smlh_entry_to_l0s | rmlh_rcvd_eidle_set)) begin
                next_lts_state   = S_L0;
            end else if ((curnt_l0s_xmt_state == S_L0S_XMT_ENTRY) & (rcvr_l0s_goto_rcvry) & (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY)) begin
                next_lts_state   = S_RCVRY_LOCK;
            end else
                next_lts_state   = S_L0S;
        end
        S_RCVRY_LOCK: begin
          if (rxeqeval_rcvrlock_any_lane_asserted) begin
            next_lts_state = S_RCVRY_LOCK;
          end else
            if ( (g3_rate || g4_rate || g5_rate || (goe_g6 && p_g5_c_g6_from_rcvry_speed)) && start_equalization_w_preset && !cfg_gen3_eq_disable ) begin // with start_equalization_w_preset
                if ( ~cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ) begin
                    int_ltssm_cmd_send_eieos_for_pset_map = 0;
                    next_lts_state = (downstream_component) ? S_RCVRY_EQ0 : S_RCVRY_EQ1;
                end else begin
                    int_ltssm_cmd_send_eieos_for_pset_map = ~all_pset_coef_map_done;
                    if ( all_pset_coef_map_done || (&pset_map_eieos_cnt == 1) ) begin //all_map_done or eieos_cnt == 31
                        next_lts_state = (downstream_component) ? S_RCVRY_EQ0 : S_RCVRY_EQ1;
                    end else
                        next_lts_state = S_RCVRY_LOCK;
                end
            end else if ( (g3_rate || g4_rate || g5_rate || (goe_g6 && p_g5_c_g6_from_rcvry_speed)) && cfg_upstream_port && link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd && ~clear &&
                          link_latched_live_all_ts1_spd_chg_0_rcvd && link_latched_live_all_ts1_not_ec_00b_rcvd && ~cfg_gen3_eq_disable ) begin
                // USP receives 8 ts1s with link/lane# match, spd_chg==0 and ec != 00b on all lanes
                if ( ~cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ) begin
                    int_ltssm_cmd_send_eieos_for_pset_map = 0;
                    next_lts_state = S_RCVRY_EQ0;
                end else begin
                    int_ltssm_cmd_send_eieos_for_pset_map = ~all_pset_coef_map_done;
                    int_ltssm_usp_eq_redo                 = 1;
                    if ( all_pset_coef_map_done || (&pset_map_eieos_cnt == 1) ) begin
                        next_lts_state = S_RCVRY_EQ0;
                    end else
                        next_lts_state = S_RCVRY_LOCK;
                end
            end else if ( (g3_rate && (directed_equalization_g3) || g4_rate && (directed_equalization_g4 || directed_equalization_g4_skipeq)
 || g5_rate && (directed_equalization_g5 || directed_equalization_g5_skipeq)
 || (g6_rate && p_g5_c_g6_from_rcvry_speed) && (directed_equalization_g6)) && ~cfg_upstream_port &&
                          !latched_idle_to_rcvrylock && xmtbyte_loe_2_ts1_ec_00b_sent && ~clear && ~cfg_gen3_eq_disable ) begin // DSP - if directed
                if ( ~cfg_gen3_eq_req_send_consecutive_eieos_for_pset_map ) begin
                    int_ltssm_cmd_send_eieos_for_pset_map = 0;
                    next_lts_state = S_RCVRY_EQ1;
                end else begin
                    int_ltssm_cmd_send_eieos_for_pset_map = ~all_pset_coef_map_done;
                    if ( all_pset_coef_map_done || (&pset_map_eieos_cnt == 1) ) begin
                        next_lts_state = S_RCVRY_EQ1;
                    end else
                        next_lts_state = S_RCVRY_LOCK;
                end
            end else
            if ( link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd && link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg &&
 ((g3_rate || g4_rate || g5_rate || goe_g6) ? (link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd || link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd) : 1'b1) &&
                 (cfg_ext_synch ? xmtbyte_1024_consecutive_ts1_sent : 1'b1) && (current_powerdown == `P0) && dsp_timeout_common_mode ) begin
                 // receive 8 ts with link/lane# match and spd_chg==directed_speed_change and ec==00b on all lanes, and 1024 CONSECUTIVE TS1s sent if ext_synch==1b.
                 // link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd: the remote partner is in Rcvry.RcvrCfg state already, so we have to move to Rcvry.RcvrCfg.
                 // dsp_timeout_common_mode: for DSP if enter this state from L1.2 exit, have to wait until Tcommonmode has elapsed, then move to S_RCVRY_RCVRCFG to send TS2.
                 // L0p: The timing of entering recovery state differs between the initiater and the remote patner. LTSSM must wait for TS1-OS transmission.
                 next_lts_state = S_RCVRY_RCVRCFG;
            end else if ( timeout_rcvry_lock ) begin
                if ( current_powerdown == `P0 ) begin
                         // 8 TSs rcvd with link/lane# match and spd_chg==1b on any lane, and
                         // current_data_rate > Gen1 or over Gen1 rate are set in transmitted (ltssm_ts_data_rate[1] != 1'b0) and received TSs.
                    if ( ((link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd && (!g1_rate)) ||
                          (link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd && (ltssm_ts_data_rate[1] != 1'b0)) 
                          ) && dsp_timeout_common_mode ) begin
                        next_lts_state = S_RCVRY_RCVRCFG;
                    end else if ( (~changed_speed_recovery && ~g1_rate) || changed_speed_recovery ) begin
                        next_lts_state   = S_RCVRY_SPEED;
                    end else
                    if ( link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd && ~changed_speed_recovery &&
                         ((~directed_speed_change && link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd) ||
                          (g1_rate && common_gen1_supported)) ) begin
                        // rcvd speed_change bit and data_rate value latched from the last rcvd TS in the state Rcvry.RcvrLock.
                        // ltssm_ts_data_rate[1] == 1b: over Gen1 rate is transmitted; ltssm_ts_data_rate[1] == 0b: only Gen1 rate is transmitted. This is in signal common_gen1_supported.
                        next_lts_state   = S_CFG_LINKWD_START;
                    end else begin
                        next_lts_state = S_PRE_DETECT_QUIET;
                    end
                end else begin// current_powerdown == `P0
                    next_lts_state = S_PRE_DETECT_QUIET;
                end
            end else begin
                next_lts_state = S_RCVRY_LOCK;
            end
        end // S_RCVRY_LOCK
        S_RCVRY_EQ0: begin // Upstream Lanes Only
            // g5_2_do: send and catch EQ TS1s in Cfg.Linkwd.Start for gen5 lpbk eq
            if (eqctl_2ects1_rcvd[1]
                && ((g3_rate && cfg_gen3_eq_phase01_rxeq_enable
                  || g4_rate && cfg_gen4_eq_phase01_rxeq_enable
                  || g5_rate && cfg_gen5_eq_phase01_rxeq_enable
                  || g6_rate && cfg_gen6_eq_phase01_rxeq_enable
                    ) ? timeout_10ms : 1'b1)
            //if any active lane has local FS value out of range, don't do equalization and exit to Gen1/2
                && !eqpa_fs_out_of_range
                && eqpa_use_pset_coef_map_done
               ) begin
                next_lts_state   = S_RCVRY_EQ1;
            end else if ( timeout_eq0 ) begin
                next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
            end else
                next_lts_state   = S_RCVRY_EQ0;

            int_bypass_gen3_eq = (g3_rate) ? 1'b0 : bypass_g3_eq;
            int_bypass_gen4_eq = (g4_rate) ? 1'b0 : bypass_g4_eq;
        end // S_RCVRY_EQ0
        S_RCVRY_EQ1: begin
            if( upstream_component ) begin
                if( eqctl_2ects1_rcvd[1]
                    && ( (g3_rate && (cfg_gen3_eq_phase01_rxeq_enable ? timeout_10ms : 1'b1) && cfg_gen3_eq_phase23_disable)
                      || (g4_rate && (cfg_gen4_eq_phase01_rxeq_enable ? timeout_10ms : 1'b1) && cfg_gen4_eq_phase23_disable)
                      || (g5_rate && (cfg_gen5_eq_phase01_rxeq_enable ? timeout_10ms : 1'b1) && (cfg_gen5_eq_phase23_disable))
                      || (g6_rate && (cfg_gen6_eq_phase01_rxeq_enable ? timeout_10ms : 1'b1) && (cfg_gen6_eq_phase23_disable) && xmlh_sent_24_ts0_ec00)
                       ) ) begin
                    next_lts_state = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_LOCK;
                end else if( eqctl_2ects1_rcvd[1]
                  && ((g3_rate && cfg_gen3_eq_phase01_rxeq_enable
                    || g4_rate && cfg_gen4_eq_phase01_rxeq_enable
                    || g5_rate && cfg_gen5_eq_phase01_rxeq_enable
                    || g6_rate && cfg_gen6_eq_phase01_rxeq_enable
                     ) ? timeout_10ms : 1'b1)
                //if any active lane has local FS value out of range, don't do equalization and exit to Gen1/2
                  && !eqpa_fs_out_of_range
                  && eqpa_use_pset_coef_map_done && ~(g6_rate && cfg_gen6_eq_phase23_disable)
                  ) begin
                    next_lts_state   = S_RCVRY_EQ2;
                end else if (timeout_dsp_eq1) begin
                    next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
                end else begin
                    next_lts_state   = S_RCVRY_EQ1;
                end
            end else begin
                if( eqctl_2ects1_rcvd[2]
                //if any active lane has local FS value out of range, don't do equalization and exit to Gen1/2
                    && !eqpa_fs_out_of_range
                  ) begin
                    next_lts_state   = S_RCVRY_EQ2;
                end else if( eqctl_8ects1_rcvd[0] ) begin
                    next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_LOCK;
                end else if (timeout_usp_eq1) begin
                    next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
                end else begin
                    next_lts_state   = S_RCVRY_EQ1;
                end
            end

            int_bypass_gen3_eq = (g3_rate) ? 1'b0 : bypass_g3_eq;
            int_bypass_gen4_eq = (g4_rate) ? 1'b0 : bypass_g4_eq;
        end // S_RCVRY_EQ1
        S_RCVRY_EQ2: begin
            if (downstream_component && eqctl_ftune_rtx_done
                && eqpa_ftune_rtx_optimal
                && ( (g3_rate)
                     || ((g4_rate || g5_rate || goe_g6) && eqctl_2ects1_retimer_eq_ext0_rcvd)
                   )
               ) begin
                next_lts_state   = S_RCVRY_EQ3;
            end else if (upstream_component && eqctl_2ects1_rcvd[3]) begin
                next_lts_state   = S_RCVRY_EQ3;
            end else if ( ltssm_eq2_slave_timeout  && !cfg_upstream_port) begin
                next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
            end else if ( ltssm_eq2_master_timeout && cfg_upstream_port
                     && eqctl_ftune_rtx_done
                    ) begin
                if ( g3_rate && cfg_gen3_eq_p23_exit_mode
                  || g4_rate && cfg_gen4_eq_p23_exit_mode
                  || g5_rate && cfg_gen5_eq_p23_exit_mode
                  || g6_rate && cfg_gen6_eq_p23_exit_mode
                   ) begin
                    next_lts_state = S_RCVRY_EQ3;
                end else begin
                    next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
                end
            end
            else
                next_lts_state   = S_RCVRY_EQ2;
        end // S_RCVRY_EQ2
        S_RCVRY_EQ3: begin
            if (downstream_component && eqctl_2ects1_rcvd[0]) begin
                next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_LOCK;
            end else if (upstream_component && eqctl_ftune_rtx_done
                     && eqpa_ftune_rtx_optimal
                     && ( (g3_rate)
                          || ((g4_rate || g5_rate || goe_g6) && eqctl_2ects1_retimer_eq_ext0_rcvd)
                        )
                    ) begin
                next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_LOCK;
            end else if ( ltssm_eq3_master_timeout && !cfg_upstream_port
                     && eqctl_ftune_rtx_done
                    ) begin
                if ( g3_rate && cfg_gen3_eq_p23_exit_mode
                  || g4_rate && cfg_gen4_eq_p23_exit_mode
                  || g5_rate && cfg_gen5_eq_p23_exit_mode
                  || g6_rate && cfg_gen6_eq_p23_exit_mode
                   ) begin
                    next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_LOCK;
                end else begin
                    next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
                end
            end
            else if ( ltssm_eq3_slave_timeout && cfg_upstream_port) begin
                next_lts_state   = perform_eq_for_loopback || perform_eq_for_lpbk_mstr ? S_LPBK_ENTRY : S_RCVRY_SPEED;
            end else
                next_lts_state   = S_RCVRY_EQ3;
        end // S_RCVRY_EQ3
        S_RCVRY_SPEED: begin
            // Remain in RCVRY_SPEED until the phy is done changing speeds or the 1ms timeout is reached
            if (latched_eidle_seen && rcvy_speed_eidle_timeout && (current_data_rate == mac_phy_rate) && speed_changed_timeout_800ns) begin
                next_lts_state   = S_RCVRY_LOCK;
                // including cxl_apn_bp (APN Bypass)
                if ( ((req_protocol_support_d && cxl_enable) || cxl_link_enable_d) && slr_g3 && hold_current_data_rate >= `GEN3_RATE ) begin // if cxl_enable and speed changed to Gen1/2 from >= Gen3, move to Detect state according to CXL spec. SW needs to reconfigure the CXL for PCIe mode
                    next_lts_state   = S_PRE_DETECT_QUIET;
                end
            // This transition is not possible under normal conditions.
            end else if (timeout_rcvry_speed)
            begin
                next_lts_state   = S_PRE_DETECT_QUIET;
            end else
                next_lts_state   = S_RCVRY_SPEED;
        end // S_RCVRY_SPEED
        S_RCVRY_RCVRCFG: begin
            if (((//8 std ts2 on any lane rcvd or 8 eq/8gteq ts2 on all lane rcvd or 8 eq ts2 on any lane and then timeout_1ms, and current_data_rate > Gen1 (i.e., != Gen1).
                  (link_latched_live_any_8_std_ts2_spd_chg_1_rcvd //8 std ts2 on any lane rcvd with spd_chg==1
                   || link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd //8 eq/8gteq ts2s rcvd on all lanes with spd_chg==1
                   || (latched_eqctl_any_8eqts2_rcvd && speed_timeout_1ms) //8 eq/8gteq ts2s rcvd on any lane with spd_chg==1 and then timeout_1ms
                  ) && (~g1_rate) // current_data_rate > Gen1
                 ) ||
                 (//8 std ts2 on any lane rcvd or 8 eq/8gteq ts2 on all lane rcvd or 8 eq ts2 on any lane and then timeout_1ms, and over Gen1 rate set in the transmitted and Received TS2s
                  (link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd //8 std ts2 on any lane rcvd with spd_chg==1 and data_rate>Gen1
                   || link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd //8 eq/8gteq ts2s rcvd on all lanes with spd_chg==1 and data_rate>Gen1
                   || (link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd && speed_timeout_1ms) //8 eq/8gteq ts2s rcvd on any lane with spd_chg==1 and data_rate>Gen1, and then timeout_1ms
                  ) && (ltssm_ts_data_rate[1] != 1'b0) //transmitted data rate > Gen1
                 )
                ) &&
                (((g1_rate || g2_rate) && link_xmlh_32_ts2_spd_chg_1_sent) || //32 ts2s with spd_chg==1 are sent after rcving 1 ts2 with spd_chg==1
                 ((g3_rate || g4_rate || g5_rate || goe_g6) && link_xmlh_128_ts2_spd_chg_1_sent)   //128 ts2s with spd_chg==1 are sent after rcving 1 ts2 with spd_chg==1
                )
               ) begin
                next_lts_state = S_RCVRY_SPEED;
            end else
            if ( (link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd
                 && (link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd //8 ts2 rcvd with match link/lane# and spd_chg==0
                     || ((link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd //8 ts2 rcvd with match link/lane# and gen1 rate field at Gen1 current speed
                     || ltssm_ts_data_rate[1] == 1'b0) && (g1_rate)) //8 ts2 rcvd and transmitted rate field == gen1 at Gen1 current speed
                    )
                 ) && link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies && deskew_complete_i //16 ts2 sent after rcving 1 ts2, with no intervening eieos
                 // In flit mode, we must remove priority of transition to Recovery.Idle over transition to Configuration.LinkWidth.Start when:
                 //   - We are transmitting PAD on any lane, or in other words, downsizing link for reliability
                 //   - Receiving TS2s with PAD link number on any lane. In this case link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd will deassert.
                 //     At Gen6 rate, we do not match transmitted link number with received, but the signal also has int_ts2_linkn_rcvd_bus behind it
                 //     which does deassert when PAD link number is received.
                 && !(ltssm_flit_mode_enable && (directed_link_width_change && latched_valid_reliability_link_width_change))
               ) begin
                next_lts_state = S_RCVRY_IDLE;
            end else if ((                            !ltssm_flit_mode_enable &&
                            ((  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd                   // this covers cfg_ts2_lid_deskew==1 because lane# mismatching
                                && (link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd     //8 ts1 rcvd with non-match link# or lane# and spd_chg==0 on any lane
                                    || ((link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd  //8 ts1 rcvd with non-match link# or lane# and gen1 rate at Gen1 speed
                                    || ltssm_ts_data_rate[1] == 1'b0) && (g1_rate))                         //8 ts1 rcvd and transmitted rate field == gen1 at Gen1 current speed
                                )
                            ) && link_xmlh_16_ts2_sent_after_1_ts1_rcvd)) //16 ts2 sent after rcving 1 ts1
                            || (ltssm_flit_mode_enable && (
                                    // Conditions for transition to Cfg in Flit Mode
                                    // 1. eight consecutive TS1 or TS2 Ordered Sets are received on any configured Lane satisfying one of the following conditions:
                                    //      a. the eight consecutive TS1 Ordered Sets are received after receiving a TS2 Ordered Set on any configured Lane
                                    //      b. the eight consecutive TS2 Ordered Sets are received with Link number PAD on any configured Lane
                                    //      c. the eight consecutive TS2 Ordered Sets are received and a PAD is being transmitted in the TS2 Ordered Sets in any configured Lane
                                    // 4. the speed_change bit is 0b on the received TS1 or TS2 Ordered Sets
                                    ( link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd ||
                                      link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd         ||
                                      (link_latched_live_any_8_ts2_spd_chg_0_rcvd && directed_link_width_change && latched_valid_reliability_link_width_change) )
                                    // 2. 1 msec has elapsed after receiving one TS1 or TS2 Ordered Set in any configured Lane
                                    //    timer resets to 0 on first TS1/2 received in flit mode RcvrCfg
                                    && speed_changed_timeout_1ms
                                    // 3. at least 16 TS2 Ordered Sets have been transmitted:
                                    //    a. after receiving one TS2 Ordered Set (with speed_change bit =0); or
                                    && ( link_xmlh_16_ts2_sent_after_1_ts2_rcvd )
                            ))
                        ) begin
                next_lts_state = S_CFG_LINKWD_START;
            end else if ( changed_speed_recovery && latched_eidle_seen && !link_latched_live_any_ts2_rcvd ) begin //back to the speed before entering Recovery
                next_lts_state = S_RCVRY_SPEED;
            end else if ( !changed_speed_recovery && latched_eidle_seen && (~g1_rate) && !link_latched_live_any_ts2_rcvd ) begin //back to Gen1 speed
                next_lts_state = S_RCVRY_SPEED;
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_dis1_rcvd ) begin // L1 -> Recovery and hard to get sym/bit/blockalign lock or no deskew_complete for cfg_ts2_lid_deskew
                next_lts_state = S_DISABLED_ENTRY; //L1 -> Recovery -> Disabled, no need rmlh_deskew_complete -> S_RCVRY_IDLE and the remote is in DISABLED state already. It is SAFE. for cfg_ts2_lid_deskew due to no idle data sent from remote
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_hotreset1_rcvd && cfg_ts2_lid_deskew && (g1_rate || g2_rate) ) begin
                next_lts_state = S_HOT_RESET_ENTRY; // no deskew_complete for cfg_ts2_lid_deskew because the remote partner doesn't send Idle Data, only affect Gen1/2 rate
            end else if ( link_any_2_ts1_lpbk1_rcvd && cfg_ts2_lid_deskew && (g1_rate || g2_rate) ) begin
                next_lts_state = S_LPBK_ENTRY; // no deskew_complete for cfg_ts2_lid_deskew because the remote partner doesn't send Idle Data, only affect Gen1/2 rate
            end else if (timeout_rcvry_rcvrcfg ) begin
                if ( g1_rate || g2_rate ) begin //The next state is Detect if the current Data Rate is 2.5 GT/s or 5GT/s
                    next_lts_state = S_PRE_DETECT_QUIET;
                //The next state is Recovery.Idle if idle_to_rlock_transitioned variable is less than ffh and current Data Rate is 8 GT/s.
                end else if ( ((g3_rate) || (g4_rate) || (g5_rate) || (goe_g6)) && (idle_to_rlock < 8'hff) ) begin
                    next_lts_state = S_RCVRY_IDLE;
                end else begin //Else the next state is Detect
                    next_lts_state = S_PRE_DETECT_QUIET;
                end
            end else begin
                next_lts_state = S_RCVRY_RCVRCFG;
            end
        end // S_RCVRY_RCVRCFG
        S_RCVRY_IDLE: begin
            if ( (~cfg_upstream_port ) && cfg_link_dis && no_idle_need_sent ) begin
                next_lts_state = S_DISABLED_ENTRY;
            end else if ( (~cfg_upstream_port ) && latched_direct_rst && no_idle_need_sent ) begin
                next_lts_state = S_HOT_RESET_ENTRY;
            end else if ( cfg_lpbk_en && no_idle_need_sent ) begin
                next_lts_state = S_LPBK_ENTRY;
            // Flit mode, all lanes rcvd 8 ts2 with match link/lane# and on any lane these rcvd 8 ts2 with either hot reset, disable link, or loopback bit set
            end else if (ltssm_flit_mode_enable && cfg_upstream_port && link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd) begin
                next_lts_state = S_DISABLED_ENTRY;
            end else if (ltssm_flit_mode_enable && cfg_upstream_port && link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd) begin
                next_lts_state = S_HOT_RESET_ENTRY;
            end else if (ltssm_flit_mode_enable && link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd) begin
                next_lts_state = S_LPBK_ENTRY;
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_dis1_rcvd && !ltssm_flit_mode_enable ) begin
                next_lts_state = S_DISABLED_ENTRY;
            end else if ( (cfg_upstream_port ) && link_any_2_ts1_hotreset1_rcvd && !ltssm_flit_mode_enable ) begin
                next_lts_state = S_HOT_RESET_ENTRY;
            end else if ( link_any_2_ts1_planen_rcvd || (cfg_gointo_cfg_state & no_idle_need_sent) || directed_link_width_change ) begin //cfg_gointo_cfg_state not supported yet
                next_lts_state = S_CFG_LINKWD_START;
            end else if ( link_any_2_ts1_lpbk1_rcvd && !ltssm_flit_mode_enable ) begin
                next_lts_state = S_LPBK_ENTRY;
            end else if ( ( ((g3_rate || g4_rate || (g5_rate)) && !latched_to_idle_timeout && rcvd_8idles && idle_16_sent) ||
                          ((g1_rate || g2_rate) && rcvd_8idles && idle_16_sent)) && ~ltssm_flit_mode_enable
                        ) begin
                next_lts_state = S_L0;
            end else if ( ltssm_flit_mode_enable && rcvd_8idles && idle_16_sent && !latched_to_idle_timeout ) begin // 32 Idle flits sent
                next_lts_state = S_L0;
            end else if (timeout_rcvry_idle) begin
                if ( !(&idle_to_rlock) ) begin //idle_to_rlock < ffh
                    next_lts_state = S_RCVRY_LOCK;
                end else begin
                    next_lts_state = S_PRE_DETECT_QUIET;
                end
            end else begin
                next_lts_state = S_RCVRY_IDLE;
            end
        end // S_RCVRY_IDLE
        S_L123_SEND_EIDLE: begin
            // CXL L1 Abort Scenario. In case, the physical layer may receives an EIOS or detects Electrical Idle when the ARB/MUX is no
            // longer requesting entry to L1, the physical layer is required to initiate recovery on the link to bring it back to L0.
            if (cxl_l1_abort_exit) begin
                if (ltssm_cmd==`SEND_EIDLE || ltssm_cmd==`XMT_IN_EIDLE) begin
                    if (&int_mac_phy_txelecidle_rr && timeout_40ns) begin // timeout_40ns is cleared at a posedge cycle of int_mac_phy_txelecidle_r or a posedge cycle of pre_cxl_l1_abort_exit.
                        next_lts_state = S_RCVRY_LOCK;
                    end else begin
                        next_lts_state = S_L123_SEND_EIDLE;
                    end
                end else begin
                    // If cxl_l1_abort_exit is asserted before the EIOS request(ltssm_cmd==SEND_EIDLE), Tx Elecidle is not asserted.
                    // In this scenario, 40ns timeout is not necessary. This line can be covered.
                    next_lts_state = S_RCVRY_LOCK;
                end
            end else
            // To finally enter L1 or L23 state, ltssm needs to wait for remote device to enter electric idle. Or under error conditions of electric idle detection, the TS ordered set received will allow core to enter L1 or L23, and then gracefully exit L1 or L23 to recovery lock.
            // Note: another condition is that if an electric ordered set has been received followed with skip or TS, it means that electric idle signal is not properly detected, then core enter L1 or L23 under this error condition to gracefully exit the L1 and L23.
            if (pm_smlh_entry_to_l1 & (&int_mac_phy_txelecidle_r)
                & ((latched_rcvd_eidle_set & ei_interval_expire )
                | (rcvd_2_unexpect_ts)
                | timeout_l123_send_eidle )) begin
                next_lts_state   = S_L1_IDLE;
            // the reason for the !current_data_rate is that the PHY has to be in gen1 rate before
            // transitioning to P2 according to the PIPE spec
            // if rcvd TSs for DSP, move to S_L2_IDLE and have a fundamental reset perst in S_L2_IDLE
            // if rcvd TSs for USP, move to Recovery as RC is in Recovery.
            end else if (pm_smlh_entry_to_l2 & (&int_mac_phy_txelecidle_r)
                & ((latched_rcvd_eidle_set &
                  ei_interval_expire
 & pipe_regif_all_idle)
                | (!cfg_upstream_port && rcvd_2_unexpect_ts)
                | timeout_l123_send_eidle )) begin
                next_lts_state   = S_L2_IDLE;
            end else if (pm_smlh_entry_to_l2 && (&int_mac_phy_txelecidle_r)
                     && rcvd_2_unexpect_ts && cfg_upstream_port) begin
                next_lts_state   = S_RCVRY_LOCK;
            end else
                next_lts_state   = S_L123_SEND_EIDLE;
        end // S_L123_SEND_EIDLE
        S_L1_IDLE: begin
            // When next_lts_state tries to get into L1 state, It must have
            // a mininume of TX_IDLE_MIN timeout (1us) before it can look
            // for exit of l1. This will guarantees that the transmitter
            // has established the electrical idle condition
            // OR
            // for "8 GT/s Receiver Impedance" ECN, timeout after 100 ms
            if ( ( pm_smlh_l1_exit
                    & (timeout_40ns | pm_smlh_l1_n_latched ) )
                    & (current_powerdown == `P1 && all_phystatus_deasserted )) begin
                next_lts_state   = S_RCVRY_LOCK;
            end else
                next_lts_state   = S_L1_IDLE;
        end
        S_L2_IDLE: begin
            // current_powerdown == `P2 from LTSSM. LTSSM does not drive powerdown from P2 to P1 but PM does. PIPE spec requires rate change only in P0 or P1
            if ( any_predet_lane_rxeidle_exit && timeout_40ns && (current_powerdown == `P2) && (pm_current_powerdown_p1 || pm_current_powerdown_p0) ) begin
                next_lts_state   = S_PRE_DETECT_QUIET;
// ccx_line_begin: ; unreachable because PM block doesn't make the condition for LTSSM from S_L2_IDLE to S_L2_WAKE for USP. No S_L2_WAKE state for DSP.
            end else if (pm_smlh_l23_exit & timeout_40ns & cfg_upstream_port & (current_powerdown == `P2))
                next_lts_state   = S_L2_WAKE;
// ccx_line_end
            else
                next_lts_state   = S_L2_IDLE;
        end
// ccx_line_begin: ; unreachable because PM block doesn't make the condition for LTSSM from S_L2_IDLE to S_L2_WAKE for USP. No S_L2_WAKE state for DSP.
        S_L2_WAKE: begin
           // PIPE spec requires rate change only in P0 or P1. PM block drives powerdown from P2 to P1
           if ( !all_phy_mac_rxelecidle && (pm_current_powerdown_p1 || pm_current_powerdown_p0) )
                next_lts_state   = S_PRE_DETECT_QUIET;
            else
                next_lts_state   = S_L2_WAKE;
        end
// ccx_line_end
        S_HOT_RESET_ENTRY: begin
            ltssm_in_hotrst_dis_entry = 1'b1;
            // For downstream ports, stay here until the link partner reaches Hot Reset.
            if ((!cfg_upstream_port
                 ) & link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd) begin
                next_lts_state   = S_HOT_RESET;
            //as long as the EP is contineously receiving TS1 with reset, stay in HOT_RESET_ENTRY state and keep linkup
            //When timeout_2ms happened after rcvd_2rst is deasserted, then
            //we will go into predetect quiet
            // The timeout timer is reset everytime rcvd_2rst signal is assert
            end else if (timeout_hot_reset) begin
                next_lts_state   = S_HOT_RESET;
            end else
                next_lts_state   = S_HOT_RESET_ENTRY;
        end
        S_HOT_RESET: begin
            // Once Reset goes away
            if (!latched_direct_rst | ds_timeout_2ms
                | cfg_upstream_port
               ) begin
                next_lts_state   = S_PRE_DETECT_QUIET;
            end else
                next_lts_state   = S_HOT_RESET;
        end
        S_DISABLED_ENTRY: begin
            ltssm_in_hotrst_dis_entry = 1'b1;
            // after 16 ts1 s with disable bit set, then we need to gointo idle state for s electric idle
            if (xmtbyte_16_ts_w_dis_link_sent) begin
                next_lts_state   = S_DISABLED_IDLE;
            end else
                next_lts_state   = S_DISABLED_ENTRY;
        end
        S_DISABLED_IDLE: begin
            if ( !cfg_link_dis & !cfg_upstream_port ) begin
                next_lts_state   = S_PRE_DETECT_QUIET;
            end else if (latched_rcvd_eidle_set & ei_interval_expire & (&int_mac_phy_txelecidle_r)) begin
                if ( cfg_pl_gen3_zrxdc_noncompl ) begin
                    if ( (g1_rate)
 & pipe_regif_all_idle ) begin
                        next_lts_state   = S_DISABLED;
                    end else
                        next_lts_state   = S_DISABLED_IDLE;
                end else
                  begin
                    next_lts_state   = S_DISABLED;
                  end
            end else if ( timeout_usp_disable_idle & cfg_upstream_port) begin
                next_lts_state   = S_PRE_DETECT_QUIET;
            end else
                next_lts_state   = S_DISABLED_IDLE;
        end
        S_DISABLED: begin
            if ( !cfg_link_dis & !cfg_upstream_port && current_powerdown == `P1) begin
                next_lts_state   = S_PRE_DETECT_QUIET;
            end else if (!all_phy_mac_rxelecidle & cfg_upstream_port && current_powerdown == `P1) begin
                next_lts_state   = S_PRE_DETECT_QUIET;
            end else
                next_lts_state   = S_DISABLED;
        end
        S_LPBK_ENTRY: begin
            if ( ( last_state_is_eq ? timeout_lpbk_entry_eq : timeout_lpbk_entry) & lpbk_master ) begin  // timer less than 100ms for master device
                next_lts_state   = S_LPBK_EXIT;
            end else
            if ( curnt_lpbk_entry_state == S_LPBK_ENTRY_TS && perform_eq_for_loopback_g6 && ~equalization_done_64gt_data_rate && g6_rate ) begin // lpbk master eq after 16 TS1s sent with ELBC = 01b and rate changed to Gen6 (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS)
                next_lts_state   = cfg_upstream_port ? S_RCVRY_EQ0 : S_RCVRY_EQ1;
            end else
            // loopback slave receives TS1s with ELBC = 01b & rate changed to Gen5, ELBC = Enhanced Link Behaviour Control
            if ( curnt_lpbk_entry_state == S_LPBK_ENTRY_TS && (perform_eq_for_loopback || perform_eq_for_lpbk_mstr) && ~equalization_done_32gt_data_rate ) begin // lpbk master eq after 16 TS1s sent with ELBC = 01b and rate changed to Gen5 (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS)
                next_lts_state   = cfg_upstream_port ? S_RCVRY_EQ0 : S_RCVRY_EQ1;
            end else if ( (perform_eq_for_loopback_g6 && captured_lpbk_ts_data_rate_eg6[5]) ? (equalization_done_64gt_data_rate && g6_rate && last_state_is_eq) : (goe_g5 && last_state_is_eq) ) begin
                if ( link_any_2_ts1_lpbk1_rcvd ) begin // the lane under test receives 2 TS1s with lpbk = 1 for master or slave
                    next_lts_state   = S_LPBK_ACTIVE;
                end else
                    next_lts_state   = S_LPBK_ENTRY;
            end else
        // loopback conditions for going into active state:
        // 1. received ts1 with loopback enable bit set after master
        // has s tst1 with loopback bit set
        // 2. slave has to  enter loopback active when it detected two
        // or more consecutive ts1 with lpbk enabled
        // received
            if (  (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS)
               && ( (!lpbk_master && ((link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd || link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd) // slave : Rx Compliance receive bit of TS1s directing to Lpbk.Entry
                    || (rmlh_all_sym_locked && (g1_rate || g2_rate)) // slave : Symbol locked for Gen1/2 rate on all active lanes
                    || (link_latched_live_all_2_ts1_rcvd && latched_xmtbyte_eies_sent && (g3_rate || g4_rate || (g5_rate) || g6_rate)) // slave : 2 consecutive TS1s received at Gen3 rate on all active lanes
                    ))
                  || (lpbk_master && int_compliance_rcv && timeout_2ms)    // master: Tx compliance receive = 1
                  || (lpbk_master && link_imp_2_ts1_lpbk1_rcvd //implementation-specific set of lanes receiving TS1 with loopback bit = 1. it was link_any_2_ts1_lpbk1_rcvd
                      && !int_compliance_rcv
                     )
                 || (lpbk_master && link_any_2_ts1_lpbk1_rcvd && ltssm_cfg_to_lpbk && !int_compliance_rcv)
                     ) ) begin // master: Tx compliance receive = 0 & Rx LPBK = 1
                next_lts_state   = S_LPBK_ACTIVE;
            end else
                next_lts_state   = S_LPBK_ENTRY;
        end
        S_LPBK_ACTIVE: begin
        // exit loopback based on two seperate conditions, one for
        // master of the loopback device and one for slave of the
        // loopback device.
            if (  (lpbk_master & !cfg_lpbk_en)    // directed for loopback master
                  // move the state from Loopback(Slave).Active to Loopback.Exit
                  || (~lpbk_master & cdm_ras_des_direct_lpbk_slave_to_exit) // Direct LTSSM from Loopback(Slave) to Exit
                  || (~lpbk_master & rcvd_4eidle) // 4 EIOSs received or Eidle inferred for loopback slave
                  || (~lpbk_master                // loopback slave
                      & (g1_rate)        // with current link speed 2.5 GT/s
                      & (latched_rcvd_eidle_set   // and an EIOS received
                        | smlh_eidle_inferred                                // or Eidle is inferred from page 183 of 2.0 spec (section 4.2.4.3)
                        )) ) begin
                next_lts_state   = S_LPBK_EXIT;
            end else
                next_lts_state   = S_LPBK_ACTIVE;
        end
        S_LPBK_EXIT: begin
            if (lpbk_master & xmtbyte_eidle_sent) begin
                next_lts_state   = S_LPBK_EXIT_TIMEOUT;
            end else if (!lpbk_master && timeout_1us && ~clear) begin
                next_lts_state   = S_LPBK_EXIT_TIMEOUT;
            end else
                next_lts_state   = S_LPBK_EXIT;
        end
        S_LPBK_EXIT_TIMEOUT: begin
            if ( timeout_lpbk_exit) begin
                next_lts_state   = (|current_data_rate) ? S_PRE_DETECT_QUIET : S_DETECT_QUIET; //if gen2/3, go to S_PRE_DETECT_QUIET for speed change to gen1
            end else
                next_lts_state   = S_LPBK_EXIT_TIMEOUT;
        end
        default: begin
            next_lts_state   = S_DETECT_QUIET;
        end
        endcase
end // next_lts_state_PROC


// dsp eq1 -> R.Lock after tx 24 ts0s with ec = 00b
reg dsp_g6_eq1_send_ec00_i;

always @* begin : dsp_g6_eq1_send_ec00_i_PROC
    dsp_g6_eq1_send_ec00_i = ltssm_dsp_g6_eq1_send_ec00;

    if ( clear || soe_g5 )
        dsp_g6_eq1_send_ec00_i = 0;
    else if ( lts_state == S_RCVRY_EQ1 && upstream_component && eqctl_2ects1_rcvd[1] && (cfg_gen6_eq_phase01_rxeq_enable ? timeout_10ms : 1'b1) &&
              cfg_gen6_eq_phase23_disable && ~(perform_eq_for_loopback || perform_eq_for_lpbk_mstr) )
        dsp_g6_eq1_send_ec00_i = 1'b1;
end // dsp_g6_eq1_send_ec00_i_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : ltssm_dsp_g6_eq1_send_ec00_PROC
    if ( ~core_rst_n )
        ltssm_dsp_g6_eq1_send_ec00 <= #TP 0;
    else
        ltssm_dsp_g6_eq1_send_ec00 <= #TP dsp_g6_eq1_send_ec00_i;
end // ltssm_dsp_g6_eq1_send_ec00_PROC

reg entry_rspeed_w_g5_rate;
always @( posedge core_clk or negedge core_rst_n ) begin : entry_rspeed_w_g5_rate_PROC
    if ( ~core_rst_n )
        entry_rspeed_w_g5_rate <= #TP 0;
    else if ( last_lts_state == S_RCVRY_LOCK && lts_state != S_RCVRY_LOCK && clear ) // clear after exit S_RCVRY_LOCK
        entry_rspeed_w_g5_rate <= #TP 0;
    else if ( lts_state == S_RCVRY_SPEED && g5_rate && clear ) // enter S_RCVRY_SPEED with gen5 rate
        entry_rspeed_w_g5_rate <= #TP 1'b1;
end // entry_rspeed_w_g5_rate_PROC

// enter R_SPEED with g5 rate and exit R_SPEED with g6 rate. p_g5_c_g6_from_rcvry_speed is only used in Rcvry_Lock state
always @( posedge core_clk or negedge core_rst_n ) begin : p_g5_c_g6_from_rcvry_speed_PROC
    if ( ~core_rst_n )
        p_g5_c_g6_from_rcvry_speed <= #TP 0;
    else if ( last_lts_state == S_RCVRY_LOCK && lts_state != S_RCVRY_LOCK && clear ) // clear after exit S_RCVRY_LOCK
        p_g5_c_g6_from_rcvry_speed <= #TP 0;
    else if ( entry_rspeed_w_g5_rate && g6_rate && last_lts_state == S_RCVRY_SPEED && lts_state == S_RCVRY_LOCK ) // g5 -> R_SPEED -> g6 -> R_LOCK
        p_g5_c_g6_from_rcvry_speed <= #TP 1'b1;
end // p_g5_c_g6_from_rcvry_speed_PROC

reg cfg_upstream_port_d; //break combinatorial loop from input directly to output
always @( posedge core_clk or negedge core_rst_n ) begin : cfg_upstream_port_d_PROC
    if ( ~core_rst_n )
        cfg_upstream_port_d <= #TP 0;
    else
        cfg_upstream_port_d <= #TP cfg_upstream_port;
end // cfg_upstream_port_d_PROC

reg equalization_done_8gt_data_rate_d, equalization_done_16gt_data_rate_d, equalization_done_32gt_data_rate_d;
reg equalization_done_64gt_data_rate_d;
always @( posedge core_clk or negedge core_rst_n ) begin : equalization_done_8gt_data_rate_d_PROC
    if ( ~core_rst_n ) begin
        equalization_done_8gt_data_rate_d  <= #TP 0;
        equalization_done_16gt_data_rate_d <= #TP 0;
        equalization_done_32gt_data_rate_d <= #TP 0;
        equalization_done_64gt_data_rate_d <= #TP 0;
    end else begin
        if ( equalization_done_8gt_data_rate == 0 )
            equalization_done_8gt_data_rate_d  <= #TP 0;
        else if ( lts_state == S_RCVRY_EQ0 && next_lts_state != S_RCVRY_EQ0 && ~clear && equalization_done_8gt_data_rate )
            equalization_done_8gt_data_rate_d  <= #TP 1;

        if ( equalization_done_16gt_data_rate == 0 )
            equalization_done_16gt_data_rate_d <= #TP 0;
        else if ( lts_state == S_RCVRY_EQ0 && next_lts_state != S_RCVRY_EQ0 && ~clear && equalization_done_16gt_data_rate )
            equalization_done_16gt_data_rate_d <= #TP 1;

        if ( equalization_done_32gt_data_rate == 0 )
            equalization_done_32gt_data_rate_d <= #TP 0;
        else if ( lts_state == S_RCVRY_EQ0 && next_lts_state != S_RCVRY_EQ0 && ~clear && equalization_done_32gt_data_rate )
            equalization_done_32gt_data_rate_d <= #TP 1;

        if ( equalization_done_64gt_data_rate == 0 )
            equalization_done_64gt_data_rate_d <= #TP 0;
        else if ( lts_state == S_RCVRY_EQ0 && next_lts_state != S_RCVRY_EQ0 && ~clear && equalization_done_64gt_data_rate )
            equalization_done_64gt_data_rate_d <= #TP 1;
    end
end // equalization_done_8gt_data_rate_d_PROC

wire   usp_g6_eq_redo_executed_int;
wire   usp_eq = cfg_upstream_port_d & lts_state == S_RCVRY_EQ0; //level
assign usp_g3_eq_redo_executed_int = equalization_done_8gt_data_rate_d  & usp_eq & g3_rate;
assign usp_g4_eq_redo_executed_int = equalization_done_16gt_data_rate_d & usp_eq & g4_rate;
assign usp_g5_eq_redo_executed_int = (equalization_done_32gt_data_rate_d & usp_eq & g5_rate) | usp_g6_eq_redo_executed_int;
assign usp_g6_eq_redo_executed_int = equalization_done_64gt_data_rate_d & usp_eq & g6_rate;

// output drive process
// Xmlh_link_up is a signal to indicate the LTSSM's linkup status based on specification.
//
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        smlh_link_up            <= #TP 1'b0;
    else if ((lts_state == S_L0S) | (lts_state == S_L0)
             | (lts_state == S_RCVRY_RCVRCFG) | (lts_state == S_RCVRY_LOCK)
             | (lts_state == S_RCVRY_IDLE) | (lts_state == S_CFG_IDLE)
             | (lts_state == S_LPBK_ACTIVE && lpbk_master))
        smlh_link_up            <= #TP 1'b1;
    else if ((lts_state == S_DISABLED_ENTRY) | (lts_state == S_DISABLED_IDLE) | (lts_state == S_DISABLED)   // according to spec intended usage of the disable function
             | (lts_state == S_DETECT_QUIET)
             | (lts_state == S_DETECT_ACT)
             | (lts_state == S_POLL_COMPLIANCE)
             | (lts_state == S_LPBK_ENTRY)
             | ((~cfg_upstream_port) ? (lts_state == S_HOT_RESET) : (lts_state == S_HOT_RESET_ENTRY))
             | (lts_state == S_POLL_CONFIG)
             | (lts_state == S_DETECT_WAIT)
             | (lts_state == S_LPBK_EXIT_TIMEOUT))
        smlh_link_up            <= #TP 1'b0;
end

logic ltssm_cfg_to_lpbk_active_master_g6_i;
assign ltssm_cfg_to_lpbk_active_master_g6_i   = (current_data_rate == `GEN6_RATE) &&  (lts_state == S_LPBK_ACTIVE || lts_state == S_LPBK_EXIT || lts_state == S_LPBK_EXIT_TIMEOUT) &&  !ltssm_in_l0_latched && !ltssm_perform_eq_for_lpbk;
assign ltssm_cfg_to_lpbk   = (current_data_rate == `GEN6_RATE) && ((ltssm_in_lpbk || ltssm_in_lpbkentry) && !ltssm_in_l0_latched) && !ltssm_perform_eq_for_lpbk;
assign ltssm_in_lpbk_wo_l0 = (current_data_rate == `GEN6_RATE) && (ltssm_cfg_to_lpbk || ltssm_perform_eq_for_lpbk);

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        ltssm_cfg_to_lpbk_active_master_g6            <= #TP 1'b0;
    else 
        ltssm_cfg_to_lpbk_active_master_g6            <= #TP ltssm_cfg_to_lpbk_active_master_g6_i;
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        ltssm_in_l0_latched            <= #TP 1'b0;
    else if (lts_state == S_L0)
        ltssm_in_l0_latched            <= #TP 1'b1;
    else if ((lts_state == S_DETECT_QUIET)
           | (lts_state == S_DETECT_ACT)
           | (lts_state == S_DETECT_WAIT))
        ltssm_in_l0_latched            <= #TP 1'b0;
end



// LTSSM in L1 with powerdown P1
assign smlh_in_l1_p1 = smlh_in_l1 && (current_powerdown == `P1);
always @(posedge core_clk or negedge core_rst_n)
begin : LINK_DOWN_REQ_RESET
    if (!core_rst_n)
        smlh_req_rst_not       <= #TP 1'b0;
    else if ((lts_state == S_L0S) | (lts_state == S_L0)
             | (lts_state == S_RCVRY_RCVRCFG) | (lts_state == S_RCVRY_LOCK)
             | (lts_state == S_RCVRY_IDLE) | (lts_state == S_CFG_IDLE)
             | (lts_state == S_LPBK_ACTIVE && lpbk_master))
        smlh_req_rst_not       <= #TP 1'b1;
    else if ((lts_state == S_DETECT_QUIET)
             | (lts_state == S_DETECT_ACT)
             | (lts_state == S_POLL_COMPLIANCE)
             | (lts_state == S_POLL_CONFIG)
             | (lts_state == S_DETECT_WAIT))
        smlh_req_rst_not       <= #TP 1'b0;
end


wire gen12 = g1_rate || g2_rate;
wire config_lanenum_state = (lts_state == S_CFG_LANENUM_WAIT || lts_state == S_CFG_LANENUM_ACEPT || lts_state == S_CFG_COMPLETE) & gen12;
assign poll_config_state = (lts_state == S_POLL_ACTIVE || lts_state == S_POLL_CONFIG || lts_state == S_CFG_LINKWD_START || lts_state == S_CFG_LINKWD_ACEPT) & gen12;
reg  int_disable, int_hot_reset, int_skip_eq, int_alt_protocol, int_mod_ts, int_no_eq_needed, int_lpbk_eq, int_tx_mod_cmpl;
wire lpbk_master_in_entry = (lpbk_master & (lts_state == S_LPBK_ENTRY));
assign        lpbk_master_in_entry_from_cfg = lpbk_master_in_entry & (last_lts_state == S_CFG_LINKWD_START || (last_state_is_eq && g5_rate && ~equalization_done_64gt_data_rate && captured_lpbk_ts_data_rate_eg6[5])) & captured_lpbk_ts_data_rate_eg6[4] & (~equalization_done_32gt_data_rate || ~equalization_done_64gt_data_rate);
assign        any_2_ts1_lpbk1_ebth1_rcvd    = |(link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd & ltssm_lanes_active) && ~clear;
assign        any_2_ts1_lpbk1_ebth1_rcvd_g5 = any_2_ts1_lpbk1_ebth1_rcvd & captured_lpbk_ts_data_rate_eg6[4];
wire          lpbk_slave_in_entry_from_cfg  = lts_state == S_CFG_LINKWD_START && next_lts_state == S_LPBK_ENTRY && any_2_ts1_lpbk1_ebth1_rcvd_g5;
assign        lpbk_slave_in_entry_from_cfg_ebth1 = {NL{lpbk_slave_in_entry_from_cfg}} & link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd;
wire          lpbk_slave_in_entry_from_cfg_tmcp1 = lpbk_slave_in_entry_from_cfg & |(link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd & link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd);

always @( posedge core_clk or negedge core_rst_n ) begin : perform_eq_for_loopback_PROC
    if ( ~core_rst_n ) begin
        perform_eq_for_loopback  <= #TP 1'b0;
        perform_eq_for_lpbk_mstr <= #TP 1'b0;
        perform_eq_for_loopback_64gt  <= #TP 1'b0;
        perform_eq_for_lpbk_mstr_64gt <= #TP 1'b0;
    end else if ( lts_state == S_DETECT_QUIET ) begin // clear because Loopback -> Detect always
        perform_eq_for_loopback  <= #TP 1'b0;
        perform_eq_for_lpbk_mstr <= #TP 1'b0;
        perform_eq_for_loopback_64gt  <= #TP 1'b0;
        perform_eq_for_lpbk_mstr_64gt <= #TP 1'b0;
    end else begin
        if ( lpbk_master_in_entry_from_cfg && cfg_do_g5_lpbk_eq ) begin // master
            perform_eq_for_lpbk_mstr <= #TP 1'b1;
        end

        if ( |lpbk_slave_in_entry_from_cfg_ebth1 ) begin // slave
            perform_eq_for_loopback  <= #TP 1'b1;
        end

        if ( ~smlh_link_up && captured_lpbk_ts_data_rate_eg6[5] && lpbk_master_in_entry_from_cfg && cfg_do_g5_lpbk_eq ) begin // master
            perform_eq_for_lpbk_mstr_64gt <= #TP 1'b1;
        end

        if ( ~smlh_link_up && captured_lpbk_ts_data_rate_eg6[5] && |lpbk_slave_in_entry_from_cfg_ebth1 ) begin // slave
            perform_eq_for_loopback_64gt  <= #TP 1'b1;
        end
    end
end // perform_eq_for_loopback_PROC

assign perform_eq_for_loopback_64gt_i = (~smlh_link_up && captured_lpbk_ts_data_rate_eg6[5] && |lpbk_slave_in_entry_from_cfg_ebth1) | perform_eq_for_loopback_64gt;

// transmit_modified_compliance_pattern_in_loopback variable for lpbk slave
always @( posedge core_clk or negedge core_rst_n ) begin : latched_lpbk_slave_in_entry_from_cfg_tmcp1_PROC
    if ( ~core_rst_n ) begin
        tx_mod_cmpl_pattern_in_lpbk <= #TP 1'b0;
    end else if ( lts_state == S_DETECT_QUIET ) begin // clear because Loopback -> Detect always
        tx_mod_cmpl_pattern_in_lpbk <= #TP 1'b0;
    end else if ( lpbk_slave_in_entry_from_cfg_tmcp1 ) begin // slave
        tx_mod_cmpl_pattern_in_lpbk <= #TP 1'b1;
    end
end // latched_lpbk_slave_in_entry_from_cfg_tmcp1_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : lpbk_master_eq_exit_PROC
    if ( ~core_rst_n ) begin
        lpbk_master_eq_exit <= #TP 1'b0;
    end else if ( clear ) begin // clear when state transitions
        lpbk_master_eq_exit <= #TP 1'b0;
    end else if ( perform_eq_for_lpbk_mstr && link_any_2_ts1_lpbk1_rcvd ) begin // when master receives 2 ts1s with lpbk=1 in Lpbk.Entry, means slave is in lpbk.active
        lpbk_master_eq_exit <= #TP 1'b1;
    end
end // lpbk_master_eq_exit_PROC

// if bypass Alternate Protocol Negotiation, no need to exchange MOD TSs. When the rate reach gen3/4/5 rate, force cxl mode
assign cfg_mod_ts_i = cxl_apn_bp ? 1'b0 : cfg_mod_ts;

// the gen6 draft 0.9 for TS1 Symbol 4 in Table 4-25 says:
// Data Rate Identifier
// Bit 0  Flit Mode Supported:
//        0b  Flit Mode not Supported
//        1b  Flit Mode Supported
//
//                    for TS2 Symbol 4 in Table 4-26 says:
// Data Rate Identifier
// Bit 0  Flit Mode Enabled
//        0b  Either Flit Mode Supported or Flit Mode Enable are Clear
//        1b  Flit Mode Supported and Flit Mode Enable are both Set
wire tx_ts2_state = (lts_state == S_POLL_CONFIG | lts_state == S_CFG_COMPLETE | lts_state == S_RCVRY_RCVRCFG);
// flitmode_rcvrcfg_to_not_rcvryidle is used to de-assert lpbk/hot reset/disable bit in transmitted TSes if LTSSM doesn't transition
// from RcvrCfg to these states through Recovery.Idle, e.g., if directed speed change is set, LTSSM transitions to Recovery.Speed
// See Jira P80001562-186792 for this scenario. lpbk/hot reset/disable bit will be set again on next visit to RcvrCfg
wire flitmode_rcvrcfg_to_not_rcvryidle = ltssm_flit_mode_enable && (last_lts_state == S_RCVRY_RCVRCFG) && (lts_state != S_RCVRY_IDLE);
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        ltssm_in_pollconfig     <= #TP 1'b0;
        int_lpbk                <= #TP 0;
        int_disable             <= #TP 0;
        int_hot_reset           <= #TP 0;
        int_mod_ts              <= #TP 0;
        int_flit_mode           <= #TP 0;
        int_skip_eq             <= #TP 0;
        int_alt_protocol        <= #TP 0;
        int_no_eq_needed        <= #TP 0;
        int_lpbk_eq             <= #TP 0;
        int_tx_mod_cmpl         <= #TP 0;
    end else begin
        ltssm_in_pollconfig     <= #TP (lts_state == S_POLL_CONFIG);
        int_lpbk                <= #TP (lpbk_master_in_entry  //Not send lpbk=1 in Loopback EQ for Loopback master to prevent master in EQ and slave in Loopback.Entry. slave to Lpbk.Active while master is still in Lpbk EQ and cannot exit the EQ
                                        | (ltssm_flit_mode_enable && (lts_state == S_RCVRY_RCVRCFG) && cfg_lpbk_en)
                                        ) ? 1'b1 
                                        : ( ( ltssm_state_rcvry_eq | (lts_state == S_LPBK_ACTIVE) | (lts_state == S_LPBK_EXIT) | (lts_state == S_DETECT_QUIET))
 || flitmode_rcvrcfg_to_not_rcvryidle ) ? 1'b0 : int_lpbk;
        int_disable             <= #TP (lts_state == S_DISABLED_ENTRY
                                        | (ltssm_flit_mode_enable && !cfg_upstream_port && (lts_state == S_RCVRY_RCVRCFG) && cfg_link_dis)
                                        ) ? 1'b1 : ( (lts_state == S_DETECT_QUIET) || flitmode_rcvrcfg_to_not_rcvryidle ) ? 1'b0: int_disable;
        int_hot_reset           <= #TP ((lts_state == S_HOT_RESET_ENTRY) | (lts_state == S_HOT_RESET)
                                        | (ltssm_flit_mode_enable && !cfg_upstream_port && (lts_state == S_RCVRY_RCVRCFG) && latched_direct_rst)
                                        ) ? 1'b1 : ( (lts_state == S_DETECT_QUIET) || flitmode_rcvrcfg_to_not_rcvryidle ) ? 1'b0 : int_hot_reset;
        int_mod_ts              <= #TP smlh_link_up ? 0 : (poll_config_state ? (cfg_mod_ts_i & ltssm_ts_data_rate[4]) : config_lanenum_state ? use_modified_ts_d : 0); // support Mod TS. In Mod TS Format, Sym5[7:6] = 2'b11 always in TS1/2 for gen1/2 rate
        int_flit_mode           <= #TP smlh_link_up ? ltssm_flit_mode_enable_w_lpbk : cfg_flit_mode_enable_i;
        int_skip_eq             <= #TP smlh_link_up ? 0 : ((poll_config_state || config_lanenum_state) ? (cfg_bypass_eq_enable | cfg_no_eq_needed_enable) : 0); // negotiated in config_lanenum_state to initial L0. "negotiated" means TX and RX
        int_alt_protocol        <= #TP smlh_link_up ? 0 : (config_lanenum_state ? cfg_alt_protocol_enable_i : 0); // negotiated in config_lanenum_state to initial L0. "negotiated" means TX and RX
                                       // A component must not advertise this capability (no eq needed) if the 'Equalization bypass to highest rate support Disable' bit is set to 1b
        int_no_eq_needed        <= #TP smlh_link_up ? 0 : ((poll_config_state || config_lanenum_state) ? (cfg_no_eq_needed_enable /* & cfg_bypass_eq_enable */) : 0); // negotiated in config_lanenum_state to initial L0. "negotiated" means TX and RX
        int_lpbk_eq             <= #TP smlh_link_up ? 1'b0 : lpbk_master_in_entry_from_cfg ? cfg_do_g5_lpbk_eq : 1'b0;
        int_tx_mod_cmpl         <= #TP smlh_link_up ? 1'b0 : lpbk_master_in_entry_from_cfg ? cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn : 1'b0;
    end

// for cfg_ts2_lid_deskew = 1 the controller uses ts2/skp/eieos to logical idle to do deskew. the transition from ts2/skp/eieos to logical idle can occur in S_CFG_IDLE state. Have to detect MOD_TS in Cfg.Idle state for cfg_ts2_lid_deskew = 1
// Base Spec says MOD_TS is in Cfg.lanenum.Wait/Accept/Complete
always @* begin : mod_ts_for_ts2_lid_deskew_PROC
    mod_ts_for_ts2_lid_deskew = mod_ts_for_ts2_lid_deskew_d;

    if ( lts_state == S_DETECT_QUIET || lts_state == S_L0 || lts_state == S_RCVRY_LOCK )
        mod_ts_for_ts2_lid_deskew = 0;
    else if ( lts_state == S_CFG_IDLE && next_lts_state != S_CFG_IDLE && smlh_link_up && ~clear )
        mod_ts_for_ts2_lid_deskew = 0;
    else if ( lts_state == S_CFG_IDLE && ~smlh_link_up && cfg_ts2_lid_deskew && ltssm_mod_ts )
        mod_ts_for_ts2_lid_deskew = 1'b1;
end // mod_ts_for_ts2_lid_deskew_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : mod_ts_for_ts2_lid_deskew_d_PROC
    if ( ~core_rst_n )
        mod_ts_for_ts2_lid_deskew_d <= #TP 0;
    else
        mod_ts_for_ts2_lid_deskew_d <= #TP mod_ts_for_ts2_lid_deskew;
end // mod_ts_for_ts2_lid_deskew_d_PROC

always @(posedge core_clk or negedge core_rst_n) begin : mod_ts_PROC
    if ( ~core_rst_n )
        ltssm_mod_ts <= #TP 0;
    else
        ltssm_mod_ts <= #TP (use_modified_ts_d & gen12 & ~smlh_link_up & config_lanenum_state) | mod_ts_for_ts2_lid_deskew;
end // mod_ts_PROC

always @(posedge core_clk or negedge core_rst_n) begin : rx_mod_ts_PROC
    if ( ~core_rst_n )
        ltssm_mod_ts_rx <= #TP 0;
    else
        ltssm_mod_ts_rx <= #TP (rx_use_modified_ts_d & gen12 & ~smlh_link_up & (config_lanenum_state || lts_state == S_CFG_LINKWD_ACEPT)) | mod_ts_for_ts2_lid_deskew; // dsp sends AP support in cfg.lanenum.wait while usp receives in cfg.linkwd.accept
end // mod_ts_PROC

always @( * ) begin
    int_compliance_rcv = 0;

    int_compliance_rcv = (ltssm_cmd == `SEND_TS2) ? 0 : cfg_tx_compliance_rcv;
end

assign  pre_ltssm_ts_cntrl[4]       = g6_rate ? 1'b0 : ltssm_mod_ts ? 1'b0 : int_compliance_rcv; // if mod_ts==1, set to 0. retimer will replace it then

assign  pre_ltssm_ts_cntrl[3:0]     =                                   g6_rate ? {int_compliance_rcv, int_lpbk, int_disable, int_hot_reset} :
                                   // ltssm_mod_ts ture starts from Cfg.Lanenum.Wait to Cfg.Lanenum.Accept until Cfg.Complete
                                   ltssm_mod_ts ? {2'b00, int_no_eq_needed & ltssm_ts_data_rate[4], int_skip_eq & ltssm_ts_data_rate[4]} :
                                   { ((g1_rate || g2_rate) ? ((lts_state_d == S_CFG_COMPLETE) & cfg_scrmb_dis) : 1'b0), int_lpbk, int_disable, int_hot_reset};
// mod_ts and alt_protocol may be for gen3 rate
assign  pre_ltssm_ts_cntrl[5]       = g6_rate ? 1'b0 : int_tx_mod_cmpl & (ltssm_ts_data_rate[4] || ltssm_ts_data_rate_eg6[5]);
assign  pre_ltssm_ts_cntrl[7:6]     = g6_rate ? 2'h0 : int_mod_ts ? 2'b11 : (int_no_eq_needed & ltssm_ts_data_rate[4]) ? 2'b10 : ((int_lpbk_eq | int_skip_eq) & (ltssm_ts_data_rate[4] || ltssm_ts_data_rate_eg6[5])) ? 2'b01 : 2'b00; 
assign  ltssm_ts_alt_protocol   =  int_alt_protocol & ltssm_ts_data_rate[2];

assign ltssm_ts_cntrl = pre_ltssm_ts_cntrl;

// The Transmitter sends two Compliance TS1 Ordered in Polling.Compliance 
// if all of the following conditions are true
// - Compliance pattern date rate is not 2.5 GT/s
// - Any TS1 OS were transmitted in Polling.Active
// - The current date rate is 2.5 GT/s
// - Flit Mode is supported
// - The transmitter is sequencing through one of the compliance pattern setting

logic ltssm_cmd_compliance_ts1_i;
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      ltssm_cmd_compliance_ts1  <= #TP 0;
    end
    else if (lts_state != S_POLL_COMPLIANCE) begin
      ltssm_cmd_compliance_ts1  <= #TP 0;
    end
    else begin
      ltssm_cmd_compliance_ts1  <= #TP ltssm_cmd_compliance_ts1_i;
    end
  end

  always_comb begin: ltssm_cmd_compliance_ts1_i_PROC
    ltssm_cmd_compliance_ts1_i = ltssm_cmd_compliance_ts1;
    if(xmtbyte_2_compliance_ts1_sent) begin
      ltssm_cmd_compliance_ts1_i = 0;
    end
    else if((curnt_compliance_state == S_COMPL_IDLE) && (current_data_rate == `GEN1_RATE) 
    && |next_data_rate && ts_sent_in_poll_active && cfg_pcie_cap_flit_mode_sup && any_predet_lane_latched_rxeidle && !cfg_enter_compliance) begin
      ltssm_cmd_compliance_ts1_i = 1;
    end
  end

// State machine for handling speed changes and electrical idle in Polling.Compliance
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        curnt_compliance_state  <= #TP S_COMPL_IDLE;
    end else if (lts_state != S_POLL_COMPLIANCE) begin                                    // hold in idle unless we are in Polling.Compliance
        curnt_compliance_state  <= #TP S_COMPL_IDLE;
    end else begin
        curnt_compliance_state  <= #TP next_compliance_state;
    end
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_compliance_state_d1  <= #TP S_COMPL_IDLE;
    else
        curnt_compliance_state_d1  <= #TP curnt_compliance_state;

always @(curnt_compliance_state or ts_sent_in_poll_active or latched_eidle_sent
         or cfg_enter_compliance
         or send_mod_compliance
         or latched_enter_compliance or smlh_clr_enter_compliance
         or current_data_rate
         or rxelecidle_fall or next_data_rate or timeout_polling_eidle
         or pipe_regif_all_idle
         or ltssm_cmd_compliance_ts1_i
    )
    begin : COMPLIANCE_STATE
             case (curnt_compliance_state)
            S_COMPL_IDLE:
                if (|next_data_rate) //have to send EIOS for gen2/3, then change speed
                    if (ts_sent_in_poll_active)                                 // if TSs were sent in Polling.Active EIOS must be sent
                        next_compliance_state   = (ltssm_cmd_compliance_ts1_i) ? S_COMPL_IDLE : S_COMPL_ENT_TX_EIDLE;
                    else
                        next_compliance_state   = S_COMPL_ENT_SPEED_CHANGE;
                else
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
            S_COMPL_ENT_TX_EIDLE:                                               // Send an EIDLE ordered set and go to next state
                if (latched_eidle_sent)
                    next_compliance_state   = S_COMPL_ENT_SPEED_CHANGE;
                else
                    next_compliance_state   = S_COMPL_ENT_TX_EIDLE;
            S_COMPL_ENT_SPEED_CHANGE:                                           // Change speed to Gen II and wait for 1ms timeout
                if (timeout_polling_eidle & (current_data_rate != `GEN1_RATE))
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
                else
                    next_compliance_state   = S_COMPL_ENT_SPEED_CHANGE;
            S_COMPL_TX_COMPLIANCE: begin
                if ( send_mod_compliance && !latched_enter_compliance ) begin // ts1 rcvd and enter compliance=0, next state is detect if directed
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
                end else if ( latched_enter_compliance ) begin // entry by enter compliance bit
                  if (!cfg_enter_compliance | smlh_clr_enter_compliance ) begin       // enter compliance has changed from 1 to 0 since entering Polling.Compliance / detected electrical idle@usp
                    next_compliance_state   = (|current_data_rate || latched_enter_compliance) ? S_COMPL_EXIT_TX_EIDLE : S_COMPL_EXIT;
                  end else
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
                end
                else if (|rxelecidle_fall) begin // Elec. Idle exit has been detected at the Receiver of any Lane that detected a Receiver during Detect.
                    next_compliance_state   = (|current_data_rate || latched_enter_compliance) ? S_COMPL_EXIT_TX_EIDLE : S_COMPL_EXIT;
                end
                else
                    next_compliance_state   = S_COMPL_TX_COMPLIANCE;
            end
            S_COMPL_EXIT_TX_EIDLE:                                              // Send an EIDLE ordered set or sets and go to next state
                if (latched_eidle_sent)
                    next_compliance_state   = (|current_data_rate) ? S_COMPL_EXIT_SPEED_CHANGE : S_COMPL_EXIT_IN_EIDLE;
                else
                    next_compliance_state   = S_COMPL_EXIT_TX_EIDLE;
            S_COMPL_EXIT_SPEED_CHANGE:                                          // Change speed to Gen I and wait for 1ms timeout
                if (timeout_polling_eidle & (current_data_rate == `GEN1_RATE)
 & pipe_regif_all_idle)
                    next_compliance_state   = S_COMPL_EXIT;
                else
                    next_compliance_state   = S_COMPL_EXIT_SPEED_CHANGE;
            S_COMPL_EXIT_IN_EIDLE:                                              // wait for 1ms timeout in EIDLE if enter_compliance=1 during entry to Polling.Compliance
                if (timeout_polling_eidle) //no speed change, no need of (current_data_rate == `GEN1_RATE)
                    next_compliance_state   = S_COMPL_EXIT;
                else
                    next_compliance_state   = S_COMPL_EXIT_IN_EIDLE;
            S_COMPL_EXIT:
                    next_compliance_state   = S_COMPL_EXIT;        // When lts_state != S_POLL_COMPLIANCE, next state will be idle
            default:
// ccx_line_begin: ; Redundant code for case default item.
                next_compliance_state   = S_COMPL_IDLE;
// ccx_line_end
        endcase
    end


// State machine for handling speed changes and electrical idle in Loopback.Entry
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_lpbk_entry_state  <= #TP S_LPBK_ENTRY_IDLE;
    else if (lts_state != S_LPBK_ENTRY)                                     // hold in idle unless we are in Loopback.Entry
        curnt_lpbk_entry_state  <= #TP S_LPBK_ENTRY_IDLE;
    else if (!clear)
        curnt_lpbk_entry_state  <= #TP next_lpbk_entry_state;

always @(
         latched_eidle_sent or lpbk_master or current_data_rate or
         next_data_rate or rcvry_to_lpbk or timeout_1ms or
         timeout_2ms or xmtbyte_16_ts_w_lpbk_sent or
         g5_rate or perform_eq_for_loopback_g6 or cfg_upstream_port or
         curnt_lpbk_entry_state)
    begin : LOOPBACK_ENTRY_STATE
        lpbk_clear_wire = 1'b0;

        case (curnt_lpbk_entry_state)
            S_LPBK_ENTRY_IDLE:
                // if current_gen5_rate && perform_eq_for_loopback_g6 && next_data_rate != current_data_rate, go for gen6 rate for gen6 eq
                if ( (current_data_rate!=next_data_rate) && (!rcvry_to_lpbk || (g5_rate && perform_eq_for_loopback_g6)) ) begin    // If a speed change is needed.  Not allowed to change speed if we came to Cfg from Recovery
                    next_lpbk_entry_state   = (lpbk_master || (g5_rate && perform_eq_for_loopback_g6 && ~cfg_upstream_port) ) ? S_LPBK_ENTRY_ADV : S_LPBK_ENTRY_EIDLE; // dsp needs sending 16 TS1s with EC=00b so that usp exits eq3
                    lpbk_clear_wire         = 1'b1;
                end else
                    next_lpbk_entry_state   = S_LPBK_ENTRY_TS;
            S_LPBK_ENTRY_ADV:
                if (xmtbyte_16_ts_w_lpbk_sent) begin
                    next_lpbk_entry_state   = S_LPBK_ENTRY_EIDLE;
                    lpbk_clear_wire         = 1'b1;
                end else
                    next_lpbk_entry_state   = S_LPBK_ENTRY_ADV;
            S_LPBK_ENTRY_EIDLE:                                             // Send an EIDLE ordered set and go to next state
                if (latched_eidle_sent &&
                    (lpbk_master ? timeout_1ms : timeout_2ms) ) begin
                    next_lpbk_entry_state   = S_LPBK_ENTRY_TS;
                    lpbk_clear_wire         = 1'b1;
                end else
                    next_lpbk_entry_state   = S_LPBK_ENTRY_EIDLE;
            S_LPBK_ENTRY_TS:                                                // Change speed to Gen II and wait for 1ms timeout
                    next_lpbk_entry_state   = S_LPBK_ENTRY_TS;
        endcase
    end

assign ltssm_lpbk_entry_send_ts1 = (curnt_lpbk_entry_state == S_LPBK_ENTRY_TS);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        lpbk_clear  <= #TP 1'b0;
    else if (lts_state != S_LPBK_ENTRY)
        lpbk_clear  <= #TP 1'b0;
    else if (!clear)
        lpbk_clear  <= #TP lpbk_clear_wire;

reg [3:0] xmt_timer_20ns;
wire      xmt_timeout_20ns;

always @(posedge core_clk or negedge core_rst_n) begin : xmt_timer_20ns_PROC
    if (!core_rst_n) begin
        xmt_timer_20ns <= #TP 0;
    end else if (curnt_l0s_xmt_state == S_L0S_XMT_EIDLE) begin
        xmt_timer_20ns <= #TP 0;
    end else if (!xmt_timeout_20ns) begin
        xmt_timer_20ns <= #TP xmt_timer_20ns + (timer2 ? timer_freq_multiplier : 1'b0);
    end
end // xmt_timer_20ns_PROC

assign xmt_timeout_20ns = (xmt_timer_20ns >= `CX_TIME_20NS);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        curnt_l0s_xmt_state <= #TP S_L0S_XMT_ENTRY;
    else
        curnt_l0s_xmt_state <= #TP next_l0s_xmt_state;

// if ~rmlh_deskew_complete, transmitter should not enter L0s but Recovery because the RX is not deskew complete when RX is still in L0
always @(pm_smlh_entry_to_l0s or l0_link_rcvry_en or xmtbyte_eidle_sent or pm_smlh_prepare4_l123 or current_powerdown
        or xmt_timeout_20ns or curnt_l0s_xmt_state or lts_state or rcvr_l0s_goto_rcvry or pm_smlh_l0s_exit or xmtbyte_fts_sent)
begin

             case (curnt_l0s_xmt_state)
            S_L0S_XMT_ENTRY:
                if (((lts_state == S_L0) & pm_smlh_entry_to_l0s & !(l0_link_rcvry_en) & !pm_smlh_prepare4_l123) // when xmtr enter L0s first
                     | ((lts_state == S_L0S) & pm_smlh_entry_to_l0s & !rcvr_l0s_goto_rcvry)) // when rcvr in l0s
                    next_l0s_xmt_state =  S_L0S_XMT_EIDLE;
                else
                    next_l0s_xmt_state =  S_L0S_XMT_ENTRY;

            S_L0S_XMT_EIDLE:    // Wait here until eidle sent
                if (xmtbyte_eidle_sent)
                    next_l0s_xmt_state =  S_L0S_XMT_WAIT;
                else
                    next_l0s_xmt_state =  S_L0S_XMT_EIDLE;

            S_L0S_XMT_WAIT:
                if (xmt_timeout_20ns & (current_powerdown == `P0S))  // either time out for 50 ui or phy has acknowledged the power state change before we can get into the l0s state. This is to prevent MAC to exit L0s without acknowledgement of the PHY to the previous power state change command
                    next_l0s_xmt_state = S_L0S_XMT_IDLE ;
                else
                    next_l0s_xmt_state = S_L0S_XMT_WAIT;

            S_L0S_XMT_IDLE:
                // waking remote site up when recovery condition has been
                // detected
                if (rcvr_l0s_goto_rcvry | pm_smlh_l0s_exit)
                    next_l0s_xmt_state = S_L0S_EXIT_WAIT;
                else
                    next_l0s_xmt_state = S_L0S_XMT_IDLE;

            S_L0S_EXIT_WAIT: begin
                if ( current_powerdown == `P0 )
                    next_l0s_xmt_state = S_L0S_XMT_FTS;
                else
                    next_l0s_xmt_state = S_L0S_EXIT_WAIT;
            end

            default: // S_L0S_XMT_FTS, Wait here until all FTSs are sent
                if (xmtbyte_fts_sent)
                    next_l0s_xmt_state = S_L0S_XMT_ENTRY;
                else
                    next_l0s_xmt_state = S_L0S_XMT_FTS;
        endcase
end

// L0s substate is designed as following

// Assign each substate in Rx L0s
assign l0s_rcv_entry = (curnt_l0s_rcv_state == S_L0S_RCV_ENTRY);         // Rx_L0s.Entry
assign l0s_rcv_idle  = (curnt_l0s_rcv_state == S_L0S_RCV_IDLE);         // Rx_L0s.Idle
assign l0s_rcv_fts   = (curnt_l0s_rcv_state == S_L0S_RCV_FTS);         // Rx_L0s.FTS

// 1 cycle delay versions of above substates:
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        r_l0s_rcv_entry          <= #TP 0;
        r_l0s_rcv_idle           <= #TP 0;
        r_l0s_rcv_fts            <= #TP 0;
    end else if (!clear) begin
        r_l0s_rcv_entry          <= #TP l0s_rcv_entry;
        r_l0s_rcv_idle           <= #TP l0s_rcv_idle;
        r_l0s_rcv_fts            <= #TP l0s_rcv_fts;
    end

// Generate clear pulse every time there is an entry to or exit from each Rx_L0s substate.
assign clr_l0s_rcv = (((l0s_rcv_entry ^ r_l0s_rcv_entry) | (l0s_rcv_idle ^ r_l0s_rcv_idle) | (l0s_rcv_fts ^ r_l0s_rcv_fts)));

// Timers are cleared every time Rx_L0s substates are changed OR when
// receive electrical idle is set while in S_L0 or S_L0s:
assign  clr_timer_4rl0s     = clr_l0s_rcv                                     // start nfts timer
                              || (rmlh_rcvd_eidle_set & (lts_state == S_L0)) // start 40ns timer in L0 state
                              || (rmlh_rcvd_eidle_set & (lts_state == S_L0S)); // start 40ns timer When xmtr in L0s state

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_pm_latched_eidle_set  <= #TP 1'b0;
    else if (rmlh_rcvd_eidle_set)
        smlh_pm_latched_eidle_set  <= #TP 1'b1;
    // don't clear on L0->L0s transition otherwise we could miss an eios that happened around the same time L0s is entered because of pm_smlh_entry_to_l0s
    else if ((clear & (lts_state != S_DISABLED_IDLE) & (lts_state != S_L123_SEND_EIDLE) & (lts_state != S_L0S)) || (r_curnt_l0s_rcv_state == S_L0S_RCV_FTS))
    //old:else if ((clear & (lts_state != S_DISABLED_IDLE) & (lts_state != S_L123_SEND_EIDLE)))
        smlh_pm_latched_eidle_set  <= #TP 1'b0;

//latch rcvd eios for Rx L0s when ltssm is in S_L0 or S_L0S (Tx is in L0s)
//clear it when ltssm is in S_RCVRY_LOCK (L0->Rcvry or L0->L1->Rcvry or L0->L0s->Rcvry), in S_DETECT_QUIET (L0->L2->Detect), clr_l0s_rcv (Rx.L0s state transition)
//So Tx.L0s transition doesn't affect the clear
always @( posedge core_clk or negedge core_rst_n ) begin : smlh_pm_latched_eidle_set_PROC
    if ( !core_rst_n )
        latched_rcvd_eidle_set_4rl0s  <= #TP 1'b0;
    else if ( rmlh_rcvd_eidle_set && (lts_state==S_L0S || lts_state==S_L0 || lts_state==S_RCVRY_IDLE || lts_state==S_CFG_IDLE) && ~ltssm_flit_mode_enable)
        latched_rcvd_eidle_set_4rl0s  <= #TP 1'b1;
        // S_RCVRY_IDLE to next HotReset/Disable/Loopback/PreDetectQuiet -> S_DETECT_QUIET, RecoveryLock/CfgLinkwdithStart, can be cleared
        // S_CFG_IDLE to next S_RCVRY_LOCK, PreDetectQuiet->S_DETECT_QUIET, can be cleared
        // S_L0S to next PreDetectQuiet->S_DETECT_QUIET, S_RCVRY_LOCK, can be cleared
        // S_L0S is Tx.L0s, after receiving rmlh_rcvd_eidle_set, move to Rx.L0s -> (l0s_rcv_idle ^ r_l0s_rcv_idle), can be cleared
        // S_L0S is Rx.L0s, any time receiving rmlh_rcvd_eidle_set, and parallel skp -> L0 -> latched_rcvd_eidle_set_4rl0s -> Rx.L0s -> (l0s_rcv_idle ^ r_l0s_rcv_idle), can be cleared
        // S_L0 to next S_L123_SEND_EIDLE -> S_RCVRY_LOCK or S_DETECT_QUIET, S_RCVRY_LOCK, PreDetectQuiet->S_DETECT_QUIET, can be cleared
        // S_L0 to next latched_rcvd_eidle_set_4rl0s -> Rx.L0s -> (l0s_rcv_idle ^ r_l0s_rcv_idle), can be cleared
    else if ( lts_state==S_RCVRY_LOCK || lts_state==S_DETECT_QUIET || lts_state==S_CFG_LINKWD_START || (l0s_rcv_idle ^ r_l0s_rcv_idle) )
        latched_rcvd_eidle_set_4rl0s  <= #TP 1'b0;
end //smlh_pm_latched_eidle_set_PROC

always @(*) begin : current_l0s_receive_state_assignments
             case (r_curnt_l0s_rcv_state)
            S_L0S_RCV_IDLE: begin
                if (  !all_phy_mac_rxelecidle
                   || (timeout_100ms && cfg_pl_gen3_zrxdc_noncompl) // For "8GT/s Receiver Impedance" ECN, timeout after 100 ms.
                   )
                    curnt_l0s_rcv_state = S_L0S_RCV_FTS;
                else if (rcvr_l0s_goto_rcvry)
                    curnt_l0s_rcv_state = S_L0S_RCV_ENTRY;
                else
                    curnt_l0s_rcv_state = S_L0S_RCV_IDLE;
            end
            S_L0S_RCV_FTS: begin
                // According to spec, when phy is not in alignment, then we can not gurantee
                // the correctness of fts receiving.
                // timer here is caled as max skip interval + one NFTS,
                // using our core period = 1528/2 + 2,here we use 50us timer roughly for this.
                //for gen3, need detect sds received on all active lanes
                if (((latched_smlh_inskip_rcv | latched_all_smlh_sds_rcvd ) & rmlh_deskew_complete) | timeout_nfts | rcvr_l0s_goto_rcvry)
                    curnt_l0s_rcv_state = S_L0S_RCV_ENTRY;
                // rcvd skip on all active lanes and the controller receives EIOS immediately (stored latched_rcvd_eidle_set_4rl0s), the rmlh_deskew_complete gets cleared.
                // the controller moves to L0 (S_L0S_RCV_ENTRY in Rx.L0s) regardless of rmlh_deskew_complete. Then LTSSM moves from L0 to L0s again after timeout_40ns_4rl0s
                // because latched_rcvd_eidle_set_4rl0s does not get cleared. 
                else if ( latched_smlh_inskip_rcv && latched_rcvd_eidle_set_4rl0s && (soe_g2) )
                    curnt_l0s_rcv_state = S_L0S_RCV_ENTRY;
                else
                    curnt_l0s_rcv_state = S_L0S_RCV_FTS;
            end

            default /*S_L0S_RCV_ENTRY*/: begin
                if (((lts_state == S_L0) & (latched_rcvd_eidle_set_4rl0s & timeout_40ns_4rl0s) & !l0_link_rcvry_en & !pm_smlh_prepare4_l123 & cfg_l0s_supported & !pm_smlh_dllp_hs) // in l0 state
                     | ((lts_state == S_L0S) & (latched_rcvd_eidle_set_4rl0s & timeout_40ns_4rl0s) & !rcvr_l0s_goto_rcvry & cfg_l0s_supported)) // When xmtr in L0s state
                    curnt_l0s_rcv_state =  S_L0S_RCV_IDLE;
                else
                    curnt_l0s_rcv_state =  S_L0S_RCV_ENTRY;

            end
        endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        r_curnt_l0s_rcv_state <= #TP S_L0S_RCV_ENTRY;
    else
        r_curnt_l0s_rcv_state <= #TP curnt_l0s_rcv_state;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rcvr_l0s_goto_rcvry <= #TP 0;
    end else begin
        rcvr_l0s_goto_rcvry <= #TP (lts_state == S_RCVRY_LOCK) ? 1'b0
                                   : (((r_curnt_l0s_rcv_state == S_L0S_RCV_FTS) & timeout_nfts)               // when nfts timeout at rcv L0s state
                                     | (l0s_link_rcvry_en & ((lts_state == S_L0) | (lts_state == S_L0S)))   // when training sequence received before rcvr at L0s state
                                     | ((r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) & (curnt_l0s_xmt_state != S_L0S_XMT_ENTRY)
                                         & smlh_eidle_inferred))
                                     ? 1'b1
                                    : rcvr_l0s_goto_rcvry;
    end


// ------------------------------------------
// Following code is designed for timing purpose because FPGA has timing
// problem
// PowerDown outputs for PIPE phy
reg     [5:0]       next_lts_state_d;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        next_lts_state_d          <= #TP 0;
    end else if (!clear) begin
        next_lts_state_d          <= #TP next_lts_state;
    end

reg                 smlh_eq_pending_d;
always @(posedge core_clk or negedge core_rst_n) begin : eq_pending_d_PROC
    if (!core_rst_n)
        smlh_eq_pending_d         <= #TP 1'b0;
    else
        smlh_eq_pending_d         <= #TP smlh_eq_pending;
end

always @(next_lts_state_d or curnt_l0s_xmt_state or ltssm_powerdown or eiexit_hs_in_progress_physic_lane)
begin

         case(next_lts_state_d)
        S_L0S :         next_ltssm_powerdown = ((curnt_l0s_xmt_state == S_L0S_XMT_WAIT) | (curnt_l0s_xmt_state == S_L0S_XMT_IDLE)) ? `P0S : `P0;

        S_DISABLED,
        S_DETECT_QUIET,
        S_DETECT_WAIT,
        S_DETECT_ACT,
        S_L1_IDLE:      begin
                          if(!(|eiexit_hs_in_progress_physic_lane)) next_ltssm_powerdown = `P1;
                          else                                      next_ltssm_powerdown = ltssm_powerdown;
                        end

        S_L2_IDLE,
        S_L2_WAKE :     next_ltssm_powerdown = `P2;

        S_PRE_DETECT_QUIET : next_ltssm_powerdown = ltssm_powerdown;

        default :       next_ltssm_powerdown = `P0;
    endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        ltssm_powerdown          <= #TP `P1;
    end else if (!clear) begin
        ltssm_powerdown          <= #TP next_ltssm_powerdown;
    end

// smlh_in_* indicators needs to be delayed too
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_in_l0s     <= #TP 1'b0;
        smlh_in_rl0s    <= #TP 1'b0;
        smlh_in_l0      <= #TP 1'b0;
        smlh_in_l1      <= #TP 1'b0;
        smlh_in_l23     <= #TP 1'b0;
        smlh_in_l0_l0s  <= #TP 1'b0;
        smlh_in_rcvryspeed_predetect <= #TP 1'b0;
    end else begin
        smlh_in_l0s     <= #TP (curnt_l0s_xmt_state != S_L0S_XMT_ENTRY && curnt_l0s_xmt_state != S_L0S_XMT_EIDLE);
        smlh_in_rl0s    <= #TP (r_curnt_l0s_rcv_state != S_L0S_RCV_ENTRY);
        if ( g1_rate || g2_rate )
            smlh_in_l1      <= #TP (lts_state_d == S_L1_IDLE);
        else
            smlh_in_l1      <= #TP (lts_state == S_L1_IDLE);
        if ( g1_rate || g2_rate )
            smlh_in_l0      <= #TP ((lts_state_d == S_L0) || (lts_state_d == S_LPBK_ACTIVE && lpbk_master
 && ( ridle_to_lpbk ? (ltssm_flit_mode_enable ? ltssm_idl_hs_done : 1'b1) : (ltssm_flit_mode_enable_lpbk ? ltssm_idl_hs_done : 1'b1) ))) && !smlh_eq_pending_d;
        else
            smlh_in_l0      <= #TP ((lts_state == S_L0) || (lts_state == S_LPBK_ACTIVE && lpbk_master
 && ( ridle_to_lpbk ? (ltssm_flit_mode_enable ? ltssm_idl_hs_done : 1'b1) : (ltssm_flit_mode_enable_lpbk ? ltssm_idl_hs_done : 1'b1) ))) && !smlh_eq_pending;
        smlh_in_l23     <= #TP (lts_state_d == S_L2_WAKE) | (lts_state_d == S_L2_IDLE);
        smlh_in_l0_l0s  <= #TP ((curnt_l0s_xmt_state != S_L0S_XMT_ENTRY) || (r_curnt_l0s_rcv_state != S_L0S_RCV_ENTRY) ||
                                (lts_state_d == S_L0) || (lts_state_d == S_LPBK_ACTIVE && lpbk_master));
        smlh_in_rcvryspeed_predetect <= #TP (lts_state_d == S_PRE_DETECT_QUIET) || (lts_state_d == S_RCVRY_SPEED);
    end

// after 4 null flits received, the RX may start to receive pkts while the TX is still sending 8 null flits.
always_ff @(posedge core_clk or negedge core_rst_n) begin : rx_smlh_in_l0_PROC
  if (!core_rst_n) begin
    rx_smlh_in_l0 <= #TP 1'b0;
  end else begin
    if ( (lts_state inside {S_CFG_IDLE, S_RCVRY_IDLE}) && ((lts_state == next_lts_state) || (next_lts_state == S_L0))
         // Rx L0 entry condition (Remote device L0 entry)
         // Note: preserve rx_smlh_in_l0 in CFG/RCVRY_IDLE state once it is asserted as rcvd_8idles may toggle de-asserting rx_smlh_in_l0
         && (rcvd_8idles || rx_smlh_in_l0)
         // Timeout from CFG_COMPLETE/RCVRY_RCVRCFG to CFG_IDLE/RCVRY_IDLE is applicable from Gen3 rate in PCIe Non-Flit Mode and at all rates in PCIe Flit Mode
         && (((g1_rate || g2_rate) && !ltssm_flit_mode_enable) ? 1'b1 : !latched_to_idle_timeout)
       ) begin
      rx_smlh_in_l0 <= #TP 1'b1;
    end
    else if (!(lts_state inside {S_L0, S_RCVRY_LOCK, S_RCVRY_EQ0, S_RCVRY_EQ1, S_L0S}) && (cfg_upstream_port ? (lts_state != S_L123_SEND_EIDLE) : 1'b1)) begin // Remote device L0 exit
      rx_smlh_in_l0 <= #TP 1'b0;
    end
  end
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_l123_eidle_timeout <= #TP 1'b0;
    end else begin
        if((lts_state == S_L123_SEND_EIDLE) && (!clear))
          smlh_l123_eidle_timeout <= #TP timeout_2ms;  // Set EIDLE timeout
        else if((lts_state == S_L1_IDLE) || (lts_state == S_L2_IDLE))
          smlh_l123_eidle_timeout <= #TP 1'b0;  // Clear timeout when L1/L2 is entered
        else
          smlh_l123_eidle_timeout <= #TP smlh_l123_eidle_timeout;
    end

//debug signals
assign  l0s_state = {curnt_l0s_xmt_state, r_curnt_l0s_rcv_state};
assign  ltssm_in_lpbk    = (lts_state == S_LPBK_ACTIVE || (~lpbk_master && lts_state == S_LPBK_EXIT));
assign  ltssm_in_lpbkentry = (lts_state == S_LPBK_ENTRY);
assign  ltssm_in_compliance = (lts_state == S_POLL_COMPLIANCE);
assign  ltssm_in_rcvrylock = (lts_state == S_RCVRY_LOCK);
assign  ltssm_in_detectquiet = (lts_state == S_DETECT_QUIET);
always @(posedge core_clk or negedge core_rst_n) begin : lpbk_active_entered_unaligned_PROC
    if ( !core_rst_n ) begin
        lpbk_active_entered_unaligned <= #TP 0;
    end else if ( (lts_state == S_LPBK_ENTRY) && !clear && (next_lts_state == S_LPBK_ACTIVE) && (rmlh_all_sym_locked == 0) ) begin
        lpbk_active_entered_unaligned <= #TP 1;
    end else if ( (rmlh_all_sym_locked == 1) || (lts_state != S_LPBK_ACTIVE) ) begin
        lpbk_active_entered_unaligned <= #TP 0;
    end
end

// Should control per-lanes for l0p operation
assign  int_ltssm_blockaligncontrol = ( (mac_phy_rate == `GEN1_RATE) || (mac_phy_rate == `GEN2_RATE) || (rmlh_deskew_datastream && !ltssm_flit_mode_enable) || ((lts_state == S_LPBK_ACTIVE) && !lpbk_master && !lpbk_active_entered_unaligned) ) ? {NL{1'b0}} :
                                        (rmlh_deskew_datastream &&  ltssm_flit_mode_enable)  ? (deskew_lanes_active & ~rmlh_deskew_datastream_bus) :  {NL{1'b1}};

always @(posedge core_clk or negedge core_rst_n) begin : ltssm_blockaligncontrol_PROC
    if ( ~core_rst_n ) begin
        ltssm_blockaligncontrol <= #TP 0;
    end else begin
        ltssm_blockaligncontrol <= #TP int_ltssm_blockaligncontrol;
    end
end // ltssm_blockaligncontrol_PROC

  assign ltssm_eq2_slave_timeout = (timeout_dsp_eq2_g3 & soe_g5) || (timeout_dsp_eq2_g6 & g6_rate) ;
  assign ltssm_eq3_slave_timeout = (timeout_usp_eq3_g3 & soe_g5) || (timeout_usp_eq3_g6 & g6_rate) ;
  assign ltssm_eq2_master_timeout= (timeout_usp_eq2_g3 & soe_g5) || (timeout_usp_eq2_g6 & g6_rate) ;
  assign ltssm_eq3_master_timeout= (timeout_dsp_eq3_g3 & soe_g5) || (timeout_dsp_eq3_g6 & g6_rate) ;

assign  ltssm_timeout24ms = ltssm_eq2_master_timeout | ltssm_eq3_master_timeout;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        r_ltssm_rcvr_err_rpt_en  <= #TP 0;
    else
        r_ltssm_rcvr_err_rpt_en  <= #TP
                (((ltssm == S_CFG_LINKWD_START) | (ltssm == S_CFG_LINKWD_ACEPT) | (ltssm == S_CFG_LANENUM_WAIT)
                | (ltssm == S_CFG_LANENUM_ACEPT) | (ltssm == S_CFG_COMPLETE) | (ltssm == S_CFG_IDLE & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set)) & smlh_link_up) ? 1'b1:
                ((ltssm == S_L0)              & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                (((ltssm == S_L0) | (ltssm == S_L0S)) & (r_curnt_l0s_rcv_state == S_L0S_RCV_ENTRY) & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set_4rl0s) ? 1'b1:
                ((ltssm == S_L123_SEND_EIDLE)   & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_DISABLED_ENTRY)  & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_DISABLED_IDLE)     & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_HOT_RESET_ENTRY) & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1:
                ((ltssm == S_HOT_RESET)       & !rmlh_rcvd_eidle_set & !latched_rcvd_eidle_set) ? 1'b1
                : 1'b0;

//make sure ltssm_rcvr_err_rpt_en is low during Recovery state
always @( r_ltssm_rcvr_err_rpt_en or ltssm ) begin
  if ( ltssm == S_RCVRY_LOCK )
    ltssm_rcvr_err_rpt_en = 1'b0;
  else
    ltssm_rcvr_err_rpt_en = r_ltssm_rcvr_err_rpt_en;
end

// Link number is expected to be matched when LTSSM is not in LINKWD_START
// state of a upstream port. If upstream port received multiple link number
// on different lanes, it is expected to select one link number. This is
// the reason that we do not need to check whether or not link number
// matched
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_lnknum_match_dis  <= #TP 0;
    else
        smlh_lnknum_match_dis  <= #TP (ltssm == S_CFG_LINKWD_START) && cfg_upstream_port;

//
// START logic for generating the additional outputs for the EI interface
//

// Group1: EIOS received
assign smlh_debug_info_ei[0] = rmlh_rcvd_eidle_set;

// Group2: LTSSM is in a state that depends on rxelecidle==0 to exit
assign smlh_debug_info_ei[1]  = (lts_state == S_L1_IDLE); // LTSSM is in L1, with or without EIOS
assign smlh_debug_info_ei[2]  = (lts_state == S_L2_IDLE) || (lts_state == S_L2_WAKE); // LTSSM is in L2, with or without EIOS
assign smlh_debug_info_ei[3]  = (r_curnt_l0s_rcv_state == S_L0S_RCV_IDLE); // LTSSM is in RxL0s, only possible with EIOS
assign smlh_debug_info_ei[4]  = (lts_state == S_DISABLED); // LTSSM is in Disabled, with or without EIOS
assign smlh_debug_info_ei[5]  = (lts_state == S_DETECT_QUIET); // LTSSM is in Detect.Quiet
assign smlh_debug_info_ei[6]  = (lts_state == S_POLL_ACTIVE); // LTSSM is in Polling.Active
assign smlh_debug_info_ei[7]  = (curnt_compliance_state == S_COMPL_TX_COMPLIANCE); // LTSSM is in Polling.Compliance transmitting compliance pattern

// Group3: LTSSM is in a state that depends on rxelecidle==1 to exit
assign smlh_debug_info_ei[8]  = (lts_state == S_L123_SEND_EIDLE); // LTSSM is transitioning into L1 or L2
assign smlh_debug_info_ei[9]  = (lts_state == S_DISABLED_IDLE); // LTSSM is transitioning into Disabled
assign smlh_debug_info_ei[10] = (lts_state == S_LPBK_ACTIVE) && !lpbk_master && (g1_rate); // LTSSM is in Loopback.Active as a slave and Gen1
assign smlh_debug_info_ei[11] = (lts_state == S_POLL_ACTIVE); // LTSSM is in Polling.Active, note this is identical to bit [6], it is repeated for completeness

// Group4: LTSSM transitions with EI inferred from Table 4-11 in Base Spec.
assign smlh_debug_info_ei[12] = (lts_state_d == S_L0)            && (lts_state == S_RCVRY_LOCK)  && latched_eidle_inferred; // L0 -> Recovery with EI inferred, first row in base spec Table 4-11
assign smlh_debug_info_ei[13] = (lts_state_d == S_RCVRY_RCVRCFG) && (lts_state == S_RCVRY_SPEED) && latched_eidle_inferred; // Recovery.RcvrCfg -> Recovery.Speed with EI inferred, second row in base spec Table 4-11
assign smlh_debug_info_ei[14] = (lts_state == S_RCVRY_SPEED)                                     && smlh_eidle_inferred; // Recovery.Speed with EI inferred, third/fourth rows in base spec Table 4-11
assign smlh_debug_info_ei[15] = (lts_state == S_LPBK_ACTIVE) && !lpbk_master                     && smlh_eidle_inferred; // Loopback.Active as a slave with EI inferred, fifth row in base spec Table 4-11

//
// END logic for generating the additional outputs for the EI interface
//

// Rx Recovery Request
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        smlh_rx_rcvry_req <= #TP 1'b0 ;
    end else if(lts_state==S_L0) begin
        if(latched_rcvd_2_unexpect_ts) begin
            // received TS OS
            smlh_rx_rcvry_req <= #TP 1'b1 ;
        end 
        else if(rmlh_goto_recovery) begin
            // received EIE OS in 128b/130b
            smlh_rx_rcvry_req <= #TP 1'b1 ;
        end
    end else begin
        smlh_rx_rcvry_req <= #TP 1'b0 ;
    end

// N_FTS Timeout
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_timeout_nfts <= #TP 0;
    else if(r_curnt_l0s_rcv_state == S_L0S_RCV_FTS) begin
        if(timeout_nfts) 
            smlh_timeout_nfts <= #TP 1;
    end else
        smlh_timeout_nfts <= #TP 0;

// L0 to Recovery Entry
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_l0_to_recovery <= #TP 0;
    else if (lts_state_d==S_L0 && lts_state==S_RCVRY_LOCK)
        smlh_l0_to_recovery <= #TP 1;
    else
        smlh_l0_to_recovery <= #TP 0;

// L1 to Recovery Entry
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_l1_to_recovery <= #TP 0;
    else if (lts_state_d==S_L1_IDLE && lts_state==S_RCVRY_LOCK)
        smlh_l1_to_recovery <= #TP 1;
    else
        smlh_l1_to_recovery <= #TP 0;

// Received EIOS when L0s is not supported and not directed L1 or L2
assign smlh_rcv_eios_when_l0s_unsprt = latched_rcvd_eidle_set_4rl0s & !cfg_l0s_supported & (lts_state == S_L0) ;

// Deskew uncompleted error
assign smlh_deskew_uncomplete_err = deskew_complete_n_d ;


// Speed Change
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_spd_change <= #TP 0;
    else if (current_data_rate!=current_data_rate_d)
        smlh_spd_change <= #TP 1;
    else
        smlh_spd_change <= #TP 0;


// Link Width Change
reg     [5:0]       int_smlh_link_mode_d;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        int_smlh_link_mode_d <= #TP 0;
    else
        int_smlh_link_mode_d <= #TP smlh_link_mode;

// Link Width Change for L0p
reg     [5:0]       int_smlh_l0p_link_mode_d;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        int_smlh_l0p_link_mode_d <= #TP 0;
    else
        int_smlh_l0p_link_mode_d <= #TP smlh_l0p_link_mode;


always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_lwd_change <= #TP 0;
    else if (((int_smlh_link_mode_d!=smlh_link_mode ) && ltssm_in_training) || int_smlh_l0p_link_mode_d!=smlh_l0p_link_mode)
        smlh_lwd_change <= #TP 1;
    else
        smlh_lwd_change <= #TP 0;

// Specific parameters

assign smlh_ltssm_variable = {
    idle_to_rlock,
    equalization_done_16gt_data_rate,
    equalization_done_8gt_data_rate, start_equalization_w_preset,
        select_deemphasis,
        upconfigure_capable,
        smlh_successful_spd_negotiation, changed_speed_recovery, directed_speed_change };

assign  ltssm_timeout10ms = timeout_10ms;

function automatic compare_t_wd; //bit width = T_WD
    input [T_WD-1:0] timer;
    input [T_WD-1:0] value;

    begin
            compare_t_wd = timer == value;
    end
endfunction // compare_t_wd

function automatic compare_t_wd_p2; //bit width = T_WD plus 2
    input [T_WD+1:0] timer;
    input [T_WD+1:0] value;

    begin
            compare_t_wd_p2 = timer == value;
    end
endfunction // compare_t_wd_p2

function automatic compare_t_wd_pz; //bit width = T_WD plus ZBW
    input [T_WD+ZBW-1:0] timer;
    input [T_WD+ZBW-1:0] value;

    begin
            compare_t_wd_pz = timer == value;
    end
endfunction // compare_t_wd_pz

function automatic compare_19; //bit width = 19
    input   [18:0] timer;
    input   [18:0] value;

    begin
            compare_19 = timer == value;
    end
endfunction // compare_19

function automatic compare_25; //bit width = 25
    input   [24:0] timer;
    input   [24:0] value;

    begin
            compare_25 = timer == value;
    end
endfunction // compare_25


`ifndef SYNTHESIS


`endif // !SYNTHESIS




endmodule
