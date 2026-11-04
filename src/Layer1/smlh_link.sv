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
// ---    $DateTime: 2023/12/27 07:30:53 $
// ---    $Revision: #30 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_link.sv#30 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer handler
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"


 module smlh_link
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_DETECT_QUIET;
 import DWC_pcie_core_pkg::S_POLL_ACTIVE;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import DWC_pcie_core_pkg::S_POLL_CONFIG;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
 import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
 import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
 import DWC_pcie_core_pkg::S_CFG_COMPLETE;
 import DWC_pcie_core_pkg::S_RCVRY_LOCK;
 import DWC_pcie_core_pkg::S_RCVRY_SPEED;
 import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
 import DWC_pcie_core_pkg::S_RCVRY_IDLE;
 import DWC_pcie_core_pkg::S_L0;
 import DWC_pcie_core_pkg::S_LPBK_ENTRY;
 import DWC_pcie_core_pkg::S_RCVRY_EQ0;
 import DWC_pcie_core_pkg::S_RCVRY_EQ1;
 import DWC_pcie_core_pkg::S_RCVRY_EQ2;
 import DWC_pcie_core_pkg::S_RCVRY_EQ3;
#(
    parameter   INST              = 0,                       // The uniquifying parameter for each port logic instance.
    parameter   NL                = `CX_NL,                  // Max number of lanes supported
    parameter   NB                = `CX_NB,                  // Number of symbols (bytes) per clock cycle
    parameter   AW                = `CX_ANB_WD,              // Width of the active number of bytes
    parameter   TSFD_WD           = `CX_TS_FIELD_CONTROL_WD, // number of bits for TS field {ln-pad, lk-pad, sym9 - sym1}, 74 bits
    parameter   OS_WD             = `CX_MAC_SB_WD, // Number of OS width
    parameter   TP                = `TP                      // Clock to Q delay (simulator insurance)
)

                  (
    // inputs
    input                   core_clk,
    input                   core_rst_n,
    input                   sticky_rst_n,
    input                   cfg_support_part_lanes_rxei_exit,
    input                   cfg_fast_link_mode,
    input                   cfg_upstream_port,
    input   [3:0]           cfg_imp_num_lanes,
    input                   cfg_rx_8_ts1s,
    input   [2:0]           current_data_rate,
    input   ltssm_state_e   smlh_ltssm_state_wire,                //
    input                   ltssm_lane_flip_ctrl_chg_pulse,  // lane flip control update pulse
    input                   smlh_link_up_falling_edge,
    input                   smlh_link_up,
    input   [7:0]           ltssm_xlinknum,                  // transmit link#
    input   [NL-1:0]        ltssm_xk237_4lnknum,             // transmit PAD link#
    input   [NL-1:0]        ltssm_xk237_4lannum,             // transmit PAD lane#
    input                   ltssm_lpbk_entry_send_ts1,       // loopback master in Loopback.Entry to send TS1s
    input                   ltssm_lpbk_master,
    input                   ltssm_directed_speed_change,     // directed_speed_change variable
    input                   xmtbyte_eies_sent,
    input   [NL*TSFD_WD-1:0]smseq_ts_info_bus,               // {Sym7,6,5,4,3,2,1}
    input   [NL*64-1:0]     smseq_mt_info_bus,               // {Sym15,14,13,12,11,10,8}
    input   [NL*2-1:0]      smseq_ts_lanen_linkn_pad_bus,    // lane num /link num are PAD
    input   [NL*4-1:0]      smseq_ts_rcvd_pcnt_bus,          // 4 bits per lane, special persistency count with speed_change
    input   [NL*2-1:0]      smseq_ts_rcvd_cond_pcnt_bus,     // 2 bits per lane, persistency count with conditions
    input   [NL*4-1:0]      smseq_ts_rcvd_mtx_pcnt_bus,      // 4 bits per lane, persistency count matching Tx
    input   [10:0]          xmtbyte_ts_pcnt,
    input                   xmtbyte_ts_data_diff,            // current ts data different from previous
    input                   xmtbyte_spd_chg_sent,
    input   [OS_WD-1:0]     xmtbyte_ts1_sent,
    input   [OS_WD-1:0]     xmtbyte_ts2_sent,
    input   [OS_WD-1:0]     xmtbyte_l0p_ts1_sent,
    input   [OS_WD-1:0]     xmtbyte_l0p_ts2_sent,
    input   [NL-1:0]        smlh_l0p_lanes_active,
    input   [NL-1:0]        smlh_l0p_last_lanes_active,
    input   [NL-1:0]        lpbk_eq_lanes_active,
    input   [NL-1:0]        smlh_lanes_active_i,
    input   [5:0]           smlh_link_mode_i,                // trained link width
    input                   ltssm_clear,                     // LTSSM clear signal
    input                   ltssm_mod_ts,
    input   [4:0]           ltssm_ts_data_rate,              // gen5,4,3,2,1
    input   [9:0]           ltssm_ts_data_rate_eg6,
    input   [9:0]           latched_ts_data_rate_eg6,
    input                   ltssm_g6_not_cfg_hotr,
    input                   ltssm_g6_not_cfg_hotr_rcvrcfg,
    input                   ltssm_g6_not_rcvridle,
    // From the sequence finders
    input   [NL-1:0]        smseq_ts_error_bus,
    input   [NL-1:0]        smseq_inskip_rcv_bus,
    input   [NL-1:0]        smseq_sds_rcvd_bus,
    input   [NL-1:0]        smseq_ts0_rcvd_bus,
    input   [NL-1:0]        smseq_ts0_rcvd_pulse_bus,
    input   [NL-1:0]        smseq_ts1_rcvd_bus,
    input   [NL-1:0]        smseq_ts2_rcvd_bus,
    input   [NL-1:0]        smseq_ts1_rcvd_pulse_bus,
    input   [NL-1:0]        smseq_ts2_rcvd_pulse_bus,
    input   [NL-1:0]        smseq_mod_ts1_rcvd_pulse_bus,
    input   [NL-1:0]        smseq_mod_ts2_rcvd_pulse_bus,
    input   [AW-1:0]        active_nb,

    // to SMLH_LTSSM
    output reg [NL-1:0]     link_imp_lanes,
    output     [5:0]        link_next_link_mode,             // intermediate active lane number
    output     [NL-1:0]     link_lanes_rcving,
    output                  link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd,
    output                  link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd,
    output                  link_latched_live_all_8_ts2_plinkn_planen_rcvd,
    output                  link_latched_live_all_8_ts_plinkn_planen_rcvd,
    output reg              link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd,
    output reg              link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd,
    output reg              link_latched_live_any_8_ts2_plinkn_planen_rcvd,
    output reg              link_latched_live_any_8_ts_plinkn_planen_rcvd,
    output [NL-1:0]         link_latched_live_any_8_ts_plinkn_planen_rcvd_bus,
    output reg              link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd,
    output                  link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd,
    output                  link_xmlh_16_ts2_sent_after_1_ts2_rcvd,
    output                  link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies,
    output                  link_xmlh_16_ts1_sent,
    output                  link_latched_live_all_2_ts1_dis1_rcvd,
    output                  link_latched_live_all_2_ts1_lpbk1_rcvd,
    output [NL-1:0]         link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd,
    output [NL-1:0]         link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd,
    output reg              link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd,
    output reg              link_latched_live_any_2_ts1_apn_rcvd,
    output reg [55:0]       link_latched_live_any_2_ts1_apn_sym14_8_rcvd,
    output                  link_latched_live_any_2_ts2_apn_rcvd,
    output reg [NL*56-1:0]  link_latched_live_all_8_ts2_apn_sym14_8_rcvd,
    output                  link_latched_live_all_2_ts2_apn_rcvd,
    output reg [NL*56-1:0]  link_latched_live_all_2_ts2_apn_sym14_8_rcvd,
    output                  link_any_2_ts1_linknmtx_planen_rcvd,
    output                  link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd,
    output                  link_any_2_ts1_dis1_rcvd,
    output                  link_latched_live_all_2_ts1_linkn_planen_rcvd,
    output                  link_any_2_ts1_linkn_planen_rcvd,
    output                  link_lane0_2_ts1_linkn_planen_rcvd,
    output                  link_lane0_2_ts1_linknmtx_rcvd,
    output                  link_lane0_2_ts1_linknmtx_lanen_rcvd,
    output                  link_latched_live_all_2_ts1_linknmtx_rcvd,
    output                  link_latched_live_all_2_ts1_linknmtx_lanen_rcvd,
    output                  link_latched_live_all_2_ts1_plinkn_planen_rcvd,
    output                  link_latched_live_lane0_2_ts1_lanen0_rcvd,
    output                  link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd,
    output                  link_latched_live_any_2_ts1_lanendiff_linkn_rcvd,
    output                  link_any_2_ts2_rcvd,
    output                  link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd, // no eq needed
    output                  link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd,
    output                  link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd,
    output                  link_any_2_ts1_rcvd,
    output                  link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd,
    output                  link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd,
    output                  link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd,
    output                  link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd,
    output                  link_latched_live_any_8_ts2_spd_chg_0_rcvd,
    output                  link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd,
    output                  link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd,
    output                  link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd,
    output                  link_any_exact_2_ts_l0p_rcvd,
    output                  link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd,
    output                  link_xmlh_l0p_16_ts1_sent,
    output                  link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_all_ts1_spd_chg_0_rcvd,
    output                  link_latched_live_any_ts2_rcvd,
    output                  link_any_8_ts1_spd_chg_1_rcvd,
    output                  link_latched_live_all_ts1_not_ec_00b_rcvd,
    output                  link_latched_live_all_ts1_ec_00b_rcvd,
    output                  link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd,
    output                  link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg,
    output                  link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd,
    output                  link_any_8_ts_linknmtx_lanenmtx_rcvd,
    output                  link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd,
    output                  link_ln0_8_ts2_linknmtx_lanenmtx_rcvd,
    output                  link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd,
    output                  link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd,
    output                  link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd,
    output                  link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd,
    output                  link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd,
    output                  link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd,
    output                  link_latched_live_any_8_std_ts2_spd_chg_1_rcvd,
    output                  link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd,
    output                  link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    output                  link_any_8_eq_ts2_spd_chg_1_rcvd,
    output                  link_any_8_8gteq_ts2_spd_chg_1_rcvd,
    output                  link_any_8_16gteq_ts2_spd_chg_1_rcvd,
    output                  link_any_8_32gteq_ts2_spd_chg_1_rcvd,
    output                  link_rx_ts0_to_ts1_pulse,
    output                  link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    output                  link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd,
    output                  link_xmlh_32_ts2_spd_chg_1_sent,
    output                  link_xmlh_128_ts2_spd_chg_1_sent,
    output                  link_xmlh_16_ts2_sent_after_1_ts1_rcvd,
    output                  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd,
    output                  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd,
    output                  link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd,
    output                  link_any_2_ts1_hotreset1_rcvd,
    output                  link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd,
    output                  link_any_2_ts1_planen_rcvd,
    output                  link_any_2_ts1_lpbk1_rcvd,
    output                  link_imp_2_ts1_lpbk1_rcvd, //implementation-specific set of lanes receiving TS1 with loopback bit = 1
    output reg              link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd,
    output                  link_any_2_ts_rcvd,
    output                  link_1_ts_rcvd,
    output reg              link_any_1_ts_rcvd,
    output                  link_any_1_ts2_rcvd,
    output                  link_any_exact_1_ts_rcvd,
    output                  link_any_exact_2_ts_rcvd,
    output                  link_any_exact_4_ts_rcvd,
    output                  link_any_exact_5_ts_rcvd,
    output                  link_latched_live_all_2_ts1_rcvd,
    output reg [4:0]        link_latched_ts_data_rate,
    output reg [4:0]        link_latched_ts_data_rate_ever,
    output reg [4:0]        link_any_8_ts_spd_chg_1_data_rate,
    output reg              link_latched_ts_spd_chg,
    output reg [4:0]        link_ts_data_rate,
    output reg              link_ts_spd_chg,
    output reg [4:0]        link_lpbk_ts_data_rate,
    output reg [4:0]        link_latched_lpbk_ts_data_rate,
    output reg              link_lpbk_ts_deemphasis,
    output reg [7:0]        link_ts_nfts,
    output                  link_latched_live_all_ts_scrmb_dis,
    output                  link_any_8_ts_auto_chg,
    output reg              link_latched_modts_support,
    output reg [1:0]        link_latched_flitm_support, // flit mode {Polling.Config, Polling.Active}
    output reg              link_usp_sris_mode,         // usp sris mode
    output reg              link_latched_mdfts_support,
    output reg [1:0]        link_elbc_rcvd,
    output reg              link_pc_rcvd,    // precode request rcvd
    output reg              link_pc6_rcvd,   // gen6 precode request rcvd
    output reg              link_latched_skipeq_enable,
    output reg [7:0]        link_any_2_ts1_link_num,
    output reg [NL-1:0]     link_mode_lanes_active,                // no use in the other modules
    output     [NL-1:0]     link_2_ts1_plinkn_planen_rcvd_upconf,
    output                  link_any_ts2_rcvd,
    output reg              link_latched_ts_retimer_pre,
    output reg              link_latched_ts_two_retimers_pre,
    output reg              link_latched_poll_config_ts_retimer_pre,
    output reg              link_latched_poll_config_ts_two_retimers_pre,
//--------below for debug purpose
    output reg [4:0]        smlh_ts_link_ctrl,               // link control information within a TS
    output reg              smlh_rcvd_lane_rev,
    output reg [7:0]        smlh_ts_link_num,                // 8-bit link number
    output reg              smlh_ts_link_num_is_k237,        // Indicates K237 found in place of link number
    output reg              smlh_ts_rcv_err,                 // When asserted, it indicates that the TS has violation in hear beat.
    output reg              smlh_ts1_rcvd,                   // when asserted, RPLH rcvd TS1
    output reg              smlh_ts2_rcvd,                   // when asserted, RPLH rcvd TS2
    output reg              smlh_ts_lane_num_is_k237,
//--------above for debug purpose

    output     [NL-1:0]     smlh_lanes_rcving,               //8bits to report the proper ordered-set received from the lanes
    output reg [NL-1:0]     smlh_inskip_rcv,
    output     [NL-1:0]     smlh_ts_rcvd_pulse_bus,          // Asserted when TS1 or TS2 is received
    output reg [NL-1:0]     smlh_sds_rcvd                    // when asserted, SDS received
);

// signals declaration
reg     [NL-1:0]            latched_2_ts1_lpbk1_rcvd_bus_post_spd;
wire    [NL-1:0]            int_2_ts1_lpbk1_rcvd_bus_post_spd;
reg     [10:0]              condition_ts_sent_cnt;
reg     [4:0]               condition1_ts_sent_cnt;
reg     [4:0]               condition2_ts_sent_cnt;
reg     [4:0]               condition3_ts_sent_cnt;
reg     [7:0]               sym1_lane[0:NL-1];
reg     [7:0]               sym2_lane[0:NL-1];
reg     [7:0]               sym3_lane[0:NL-1];
reg     [7:0]               sym4_lane[0:NL-1];
reg     [7:0]               sym5_lane[0:NL-1];
reg     [7:0]               sym6_lane[0:NL-1];
reg     [7:0]               sym7_lane[0:NL-1];
reg     [7:0]               sym8_lane[0:NL-1];
reg     [7:0]               sym9_lane[0:NL-1];
reg     [7:0]               sym10_lane[0:NL-1];
reg     [7:0]               sym11_lane[0:NL-1];
reg     [7:0]               sym12_lane[0:NL-1];
reg     [7:0]               sym13_lane[0:NL-1];
reg     [7:0]               sym14_lane[0:NL-1];
reg     [7:0]               sym15_lane[0:NL-1];
reg     [7:0]               link_num_s1_lane[0:NL-1];
reg     [NL-1:0]            link_num_s1_mtch;              // link# match
reg     [7:0]               lane_num_s2_lane[0:NL-1];
reg     [NL-1:0]            lane_num_s2_mtch;              // lane# match
reg     [NL-1:0]            link_num_g6_chck;              // link# match
reg     [NL-1:0]            lane_num_g6_chck;              // link# match
logic   [NL-1:0]            link_num_g6_pad_search_en;          // to mask sym1 comparison to PAD in states where sym1 is not link#
logic   [NL-1:0]            lane_num_g6_pad_search_en;          // to mask sym2 comparison to PAD in states where sym2 is not lane#
wire                        g6_rate;                       // current gen6 rate
wire                        ts0_detect_window;             // need to detect TS0s
reg     [8:0]               lane_num_lane[0:NL-1];         //[8]: pad-lane#, [7:0]: lane#
reg     [8:0]               lane_num_lane_d[0:NL-1];       //[8]: pad-lane#, [7:0]: lane#
reg     [8:0]               latched_lane_num_lane[0:NL-1]; //[8]: pad-lane#, [7:0]: lane#
reg     [7:0]               n_fts_s3_lane[0:NL-1];
reg     [NL-1:0]            link_num_pad_lane;
reg     [NL-1:0]            lane_num_pad_lane;
reg     [4:0]               data_rate_s4_lane[0:NL-1];
reg     [NL-1:0]            data_rate_gtr_g1_bus;
reg     [NL-1:0]            data_rate_is_g1_bus;
reg     [NL-1:0]            auto_chg_s4_lane;
reg     [NL-1:0]            speed_chg_s4_lane;
reg     [NL-1:0]            hot_reset_s5_lane;
wire    [NL-1:0]            no_eq_needed_s5_lane;
reg     [NL-1:0]            dis_link_s5_lane;
reg     [NL-1:0]            loopback_s5_lane;
reg     [NL-1:0]            dis_scramble_s5_lane;
reg     [NL-1:0]            modts_supt_s5_lane;
reg     [NL-1:0]            flitm_supt_s4_lane;
wire    [NL-1:0]            skip_eq_enbl_s5_lane;
reg     [NL-1:0]            compl_rcv_ts1_s5_lane;
reg     [NL-1:0]            tmcp_ls_s5_lane;                 //lpbk slave required to tx mod cmpl pattern
reg     [NL-1:0]            full_eq_s5_lane;                 //full eq required
reg     [NL-1:0]            ebth_eq_s5_lane;                 //bypass to highest rate eq
reg     [NL-1:0]            nend_eq_s5_lane;                 //no eq needed
reg     [NL-1:0]            retimer_pre_ts2_s5_lane;
reg     [NL-1:0]            data_rate_g5_s4_lane;
reg     [NL-1:0]            data_rate_g6_s4_lane;
reg     [NL-1:0]            data_rate_g3_s4_lane;
reg     [NL-1:0]            two_retimers_pre_ts2_s5_lane;
reg     [NL-1:0]            eqts_s6_lane;
reg     [NL-1:0]            pcts_s6_lane; //precode request
reg     [1:0]               ects_s6_lane[0:NL-1];
reg     [NL-1:0]            eq8gtts_s7_lane;
reg     [NL-1:0]            apn_s8_lane; // Alternate Protocols Negotiation
reg     [NL-1:0]            ts2_apn_s8_lane; // Alternate Protocols Negotiation
reg     [NL-1:0]            pcts_g4_s7_lane;
reg     [NL-1:0]            current_8_ts1_ects_not_00b_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_ects_not_00b_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_ects_not_00b_rcvd_bus;
reg     [NL-1:0]            current_8_ts_ects_00b_rcvd_bus;
reg     [NL-1:0]            latched_8_ts_ects_00b_rcvd_bus;
wire    [NL-1:0]            int_8_ts_ects_00b_rcvd_bus;
wire    [NL-1:0]            current_tx_spd_chg_same_as_8_ts_rx_ects_00b_bus;
wire    [NL-1:0]            current_tx_spd_chg_1_same_as_8_ts_rx_ects_00b_bus;
reg     [NL-1:0]            latched_tx_spd_chg_same_as_8_ts_rx_ects_00_bus;
reg     [NL-1:0]            latched_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus;
wire    [NL-1:0]            int_tx_spd_chg_same_as_8_ts_rx_ects_00_bus;
wire    [NL-1:0]            int_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus;
wire    [NL-1:0]            current_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus;
reg     [NL-1:0]            int_1_ts_rcvd_bus;
reg     [NL-1:0]            int_2_ts_rcvd_bus;
reg     [NL-1:0]            int_1_ts_rcvd_mtx_bus;
reg     [NL-1:0]            int_2_ts_rcvd_mtx_bus;
reg     [NL-1:0]            int_8_ts_rcvd_mtx_bus;
reg     [NL-1:0]            int_8_ts0_rcvd_mtx_bus;
reg     [NL-1:0]            int_exact_1_ts_cond_rcvd_bus;
reg     [NL*3-1:0]          int_ts_rcvd_cnt;
reg                         int_any_exact_1_ts_rcvd;
reg                         int_any_exact_2_ts_rcvd;
reg                         int_any_exact_4_ts_rcvd;
reg                         int_any_exact_5_ts_rcvd;
reg                         int_any_exact_1_ts_rcvd_d;
reg                         int_any_exact_2_ts_rcvd_d;
reg                         int_any_exact_4_ts_rcvd_d;
reg                         int_any_exact_5_ts_rcvd_d;
reg     [NL-1:0]            int_exact_2_ts_cond_rcvd_bus;
reg     [NL-1:0]            int_2_ts_cond_rcvd_bus;
reg     [NL-1:0]            int_8_ts_rcvd_bus;
wire    [NL-1:0]            current_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus;
wire    [NL-1:0]            current_8_ts2_spd_chg_0_rcvd_bus_i;
wire                        current_any_8_ts2_spd_chg_0_rcvd;
reg                         latched_any_8_ts2_spd_chg_0_rcvd;
wire    [NL-1:0]            current_8_ts2_spd_chg_0_plinkn_rcvd_bus;
reg     [NL-1:0]            latched_8_ts2_spd_chg_0_plinkn_rcvd_bus;
reg                         latched_any_1_ts1_rcvd;
reg                         latched_any_1_ts2_rcvd;
wire                        latched_any_1_ts_rcvd;
reg     [NL-1:0]            latched_1_ts1_plinkn_planen_rcvd_bus;
wire    [NL-1:0]            int_link_mode_linkn_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_link_mode_linkn_planen_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_link_mode_linkn_planen_reversed_bus;
wire    [NL-1:0]            int_link_mode_linkn_rcvd_reversed_bus;
wire    [NL-1:0]            int_ts1_plinkn_planen_rcvd_bus;
wire    [NL-1:0]            int_ts0_linkn_rcvd_bus;
wire    [NL-1:0]            int_ts0_lanen_rcvd_bus;
wire    [NL-1:0]            int_ts1_linkn_rcvd_bus;
wire    [NL-1:0]            int_ts1_lanen_rcvd_bus;
wire    [NL-1:0]            int_ts2_linkn_rcvd_bus;
wire    [NL-1:0]            int_ts2_lanen_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_rcvd_bus;
wire    [NL-1:0]            current_8_ts1_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_rcvd_bus;
wire    [NL-1:0]            int_2_ts2_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linkn_rcvd_bus;
wire    [NL-1:0]            current_2_ts2_dis_scramble_rcvd_bus;
reg     [NL-1:0]            latched_2_ts2_dis_scramble_rcvd_bus;
wire    [NL-1:0]            int_2_ts2_dis_scramble_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_linkn_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_linkn_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_linkn_planen_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_linkn_planen_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linkn_planen_rcvd_bus;
wire    [NL-1:0]            current_8_ts_plinkn_planen_rcvd_bus;
reg     [NL-1:0]            latched_8_ts_plinkn_planen_rcvd_bus;
wire    [NL-1:0]            int_8_ts_plinkn_planen_rcvd_bus;
wire    [NL-1:0]            current_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus;
wire    [NL-1:0]            current_8_ts1_plinkn_planen_lpbk1_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_plinkn_planen_lpbk1_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_plinkn_planen_lpbk1_rcvd_bus;
wire    [NL-1:0]            current_8_ts2_plinkn_planen_rcvd_bus;
reg     [NL-1:0]            latched_8_ts2_plinkn_planen_rcvd_bus;
wire                        current_8_ts2_plinkn_planen_modts_supt_rcvd;
wire                        current_8_ts2_plinkn_planen_modts_supt_rcvd_clear;
wire                        current_8_ts2_plinkn_planen_flitm_supt_rcvd;
wire                        current_8_ts2_plinkn_planen_flitm_supt_rcvd_clear;
wire                        current_8_ts1_plinkn_planen_flitm_supt_rcvd;
reg                         link_latched_modts_support_d;
reg                         link_latched_mdfts_support_d;
wire                        current_2_ts1_linknmtx_lanenmtx_skipeq_enbl_rcvd;
wire                        current_2_ts2_skipeq_enbl_rcvd;
wire                        current_2_ts2_linknmtx_lanenmtx_skipeq_enbl_rcvd;
wire                        current_8_ts2_linknmtx_lanenmtx_skipeq_enbl_rcvd;
wire    [NL-1:0]            int_8_ts2_plinkn_planen_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_dis1_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_dis1_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_apn_rcvd_bus;
wire    [NL-1:0]            current_8_ts2_apn_rcvd_bus;
wire    [NL-1:0]            current_2_ts2_apn_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_apn_rcvd_bus;
reg     [NL-1:0]            latched_2_ts2_apn_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_apn_rcvd_bus;
wire    [NL-1:0]            int_2_ts2_apn_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_dis1_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_lpbk1_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_lpbk1_ebth1_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_lpbk1_tmcp1_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_lpbk1_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_lpbk1_ebth1_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_lpbk1_tmcp1_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_lpbk1_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_lpbk1_ebth1_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_lpbk1_tmcp1_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_lpbk1_compl_rcv_1_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_lpbk1_compl_rcv_1_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_lpbk1_compl_rcv_1_rcvd_bus;
wire    [NL-1:0]            current_active_1_ts_linknmtx_lanenmtx_rcvd_bus;
wire                        current_any_1_ts_linknmtx_lanenmtx_rcvd;
wire                        current_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
wire                        current_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd;
reg                         latched_any_1_ts_linknmtx_lanenmtx_rcvd;
reg                         latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
reg                         latched_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd;
reg     [NL-1:0]            int_1_ts_linknmtx_rcvd_bus;
reg     [NL-1:0]            int_2_ts_linknmtx_rcvd_bus;
reg     [NL-1:0]            int_8_ts_linknmtx_rcvd_bus;
reg     [NL-1:0]            in_8_ts0_linknmtx_rcvd_bus;
reg     [NL-1:0]            int_8_ts0_linknmtx_rcvd_bus;
reg     [NL-1:0]            int_8_ts_linknmtx_spd_chg_rcvd_bus;
reg     [NL-1:0]            int_1_ts_lanenmtx_rcvd_bus;
reg     [NL-1:0]            int_2_ts_lanenmtx_rcvd_bus;
reg     [NL-1:0]            int_8_ts_lanenmtx_rcvd_bus;
reg     [NL-1:0]            in_8_ts0_lanenmtx_rcvd_bus;
reg     [NL-1:0]            int_8_ts0_lanenmtx_rcvd_bus;
reg     [NL-1:0]            int_8_ts_lanenmtx_spd_chg_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_linknmtx_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_linknmtx_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linknmtx_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linknmtx_rcvd_reversed_bus;
wire    [NL-1:0]            int_2_ts1_linknmtx_lanenmtx_reversed_bus;
wire    [NL-1:0]            current_2_ts1_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_2_ts2_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_2_ts2_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_2_ts2_linknmtx_lanenmtx_rcvd_bus;
wire                        current_lane0_2_ts1_lanen0_rcvd;
reg                         latched_lane0_2_ts1_lanen0_rcvd;
wire                        int_lane0_2_ts1_lanen0_rcvd;
wire    [NL-1:0]            int_2_ts1_linknmtx_planen_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linknmtx_lanen_rcvd_bus;
reg     [NL*8-1:0]          int_2_ts1_linknmtx_lanenum_rcvd_bus;
wire    [NL-1:0]            current_2_ts1_linknmtx_lanen_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_linknmtx_lanen_rcvd_bus;
reg     [NL*8-1:0]          latched_2_ts1_linknmtx_lanenum_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_linknmtx_lanen_rcvd_reversed_bus;
wire    [NL-1:0]            current_2_ts1_plinkn_planen_rcvd_bus;
reg     [NL-1:0]            latched_2_ts1_plinkn_planen_rcvd_bus;
wire    [NL-1:0]            int_2_ts1_plinkn_planen_rcvd_bus;
wire                        int_lane0_2_ts1_linknmtx_lanen_rcvd;
wire    [NL-1:0]            int_2_ts1_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_2_ts2_linknmtx_rcvd_bus;
wire    [NL-1:0]            int_2_ts2_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_linknmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts2_linknmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts2_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_1_ts2_linknmtx_rcvd_bus;
wire    [NL-1:0]            int_1_ts2_lanenmtx_rcvd_bus;
reg     [NL-1:0]            int_2_ts1_lanendiff_rcvd_bus;
wire                        current_any_2_ts1_lanendiff_rcvd;
reg                         latched_any_2_ts1_lanendiff_rcvd;
wire    [NL-1:0]            current_8_ts_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus;
reg     [NL-1:0]            latched_8_ts_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus;
wire    [NL-1:0]            int_8_ts_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_ts0_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_ts1_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_8_ts0_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts0_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_ts1_spd_chg_0_rcvd_rcvd_bus;
reg     [NL-1:0]            latched_8_ts1_spd_chg_0_rcvd_rcvd_bus;
wire    [NL-1:0]            int_8_ts1_spd_chg_0_rcvd_rcvd_bus;
wire    [NL-1:0]            current_8_ts2_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_1_ts2_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_8_ts2_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus;
reg     [NL-1:0]            latched_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_ts2_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            int_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus;
wire    [NL-1:0]            current_8_ts2_spd_chg_0_rcvd_bus;
reg     [NL-1:0]            latched_8_ts2_spd_chg_0_rcvd_bus;
wire    [NL-1:0]            int_8_ts2_spd_chg_0_rcvd_bus;
wire    [NL-1:0]            current_8_ts2_g1_rate_rcvd_bus;
reg     [NL-1:0]            latched_8_ts2_g1_rate_rcvd_bus;
wire    [NL-1:0]            int_8_ts2_g1_rate_rcvd_bus;
reg     [NL-1:0]            latched_1_ts2_rcvd_bus;
reg     [NL-1:0]            latched_1_ts1_rcvd_bus;
wire                        link_any_ts_rcvd;
reg                         latched_any_ts1_rcvd;
reg                         latched_any_ts2_spd_chg_rcvd_sent;
wire    [NL-1:0]            int_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_bus;
wire                        current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;
reg                         latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;
wire                        current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;
reg                         latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;
reg     [NL-1:0]            current_tx_spd_chg_same_as_8_ts_rx_bus;
reg     [NL-1:0]            current_tx_spd_chg_1_same_as_8_ts_rx_bus;
reg     [NL-1:0]            latched_tx_spd_chg_same_as_8_ts_rx_bus;
reg     [NL-1:0]            latched_tx_spd_chg_1_same_as_8_ts_rx_bus;
wire    [NL-1:0]            int_tx_spd_chg_same_as_8_ts_rx_bus;
wire    [NL-1:0]            int_tx_spd_chg_1_same_as_8_ts_rx_bus;
//reg     [NL-1:0]            int_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd_bus; // not used
wire    [NL-1:0]            int_8_std_ts2_spd_chg_1_rcvd_bus;
wire    [NL-1:0]            int_8_std_g3_ts2_spd_chg_1_rcvd_bus;
wire                        current_any_8_std_ts2_spd_chg_1_rcvd;
wire                        current_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;
reg                         latched_any_8_std_ts2_spd_chg_1_rcvd;
reg                         latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire    [NL-1:0]            int_8_eq_ts2_rcvd_bus;
wire    [NL-1:0]            int_8_eq_ts2_spd_chg_1_rcvd_bus;
wire    [NL-1:0]            int_8_8gteq_ts2_rcvd_bus;
wire    [NL-1:0]            int_8_8gteq_ts2_spd_chg_1_rcvd_bus;
wire    [NL-1:0]            int_8_16gteq_ts2_rcvd_bus;
wire    [NL-1:0]            int_8_16gteq_ts2_spd_chg_1_rcvd_bus;
wire    [NL-1:0]            int_8_32gteq_ts2_rcvd_bus;
wire    [NL-1:0]            int_8_32gteq_ts2_spd_chg_1_rcvd_bus; // = {NL{1'b0}}; // jd6
wire    [NL-1:0]            current_8_g123_eq_ts2_spd_chg_1_rcvd_bus;
reg     [NL-1:0]            latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus;
wire    [NL-1:0]            int_8_g123_eq_ts2_spd_chg_1_rcvd_bus;
wire    [NL-1:0]            current_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus;
reg     [NL-1:0]            latched_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus;
wire    [NL-1:0]            int_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus;
wire                        int_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire    [NL-1:0]            int_8_ts2_spd_chg_1_rcvd_bus;
wire                        int_all_8_ts2_spd_chg_1_rcvd;
wire                        int_any_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                        int_any_8_16gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                        int_any_8_32gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire                        current_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
reg                         latched_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
wire    [NL-1:0]            int_8_ts1_linknnomtx_or_lanennomtx_rcvd_bus;
wire                        current_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
wire                        current_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
wire                        current_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;
reg                         latched_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
reg                         latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
reg                         latched_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;
reg                         latched_any_ts2_rcvd;
wire                        current_any_ts2_rcvd;
wire    [NL-1:0]            int_ts_rcvd_pulse_bus;
wire                        int_all_8_eq_ts2_rcvd;
wire                        int_all_8_8gteq_ts2_rcvd;
wire                        int_all_8_16gteq_ts2_rcvd;
wire                        int_all_8_32gteq_ts2_rcvd;
wire                        int_all_spd_chg_0_rcvd;
//wire    [NL-1:0]            current_spd_chg_0_rcvd_bus; // not used
//reg     [NL-1:0]            latched_spd_chg_0_rcvd_bus; // not used
//wire    [NL-1:0]            int_spd_chg_0_rcvd_bus; // not used
wire                        int_all_g1_rate_rcvd;
wire                        int_any_2_ts1_linkn_planen_rcvd;
reg                         int_any_2_ts1_linkn_planen_rcvd_d;
reg                         latched_any_ts2_rcvd_and_sent;
reg     [4:0]               latched_ts_data_rate;
reg           int_link_usp_sris_mode;

reg  [NL-1:0] latched_8_ts2_dis_link_rcvd_bus;
wire [NL-1:0] current_8_ts2_dis_link_rcvd_bus;
wire [NL-1:0] int_8_ts2_dis_link_rcvd_bus;
reg           latched_any_dis_link_rcvd;
wire          int_any_dis_link_rcvd;

reg  [NL-1:0] latched_8_ts2_hot_reset_rcvd_bus;
wire [NL-1:0] current_8_ts2_hot_reset_rcvd_bus;
wire [NL-1:0] int_8_ts2_hot_reset_rcvd_bus;
reg           latched_any_hot_reset_rcvd;
wire          int_any_hot_reset_rcvd;

reg  [NL-1:0] latched_8_ts2_loopback_rcvd_bus;
wire [NL-1:0] current_8_ts2_loopback_rcvd_bus;
wire [NL-1:0] int_8_ts2_loopback_rcvd_bus;
reg           latched_any_loopback_rcvd;
wire          int_any_loopback_rcvd;

reg  [NL-1:0] latched_1_ts2_spd_chg_0_rcvd_bus;
ltssm_state_e smlh_ltssm_state ;

// Pipe-line of smlh_ltssm_state for high fanout. 
// The smlh_ltssm_state_wire is a combinational signal(before FF). So, no timing change by this pipe-line.
always @(posedge core_clk or negedge core_rst_n) begin : smlh_ltssm_state_proc
    if (!core_rst_n) begin
        smlh_ltssm_state <= #TP S_DETECT_QUIET;
    end
    else begin
        smlh_ltssm_state <= #TP smlh_ltssm_state_wire;
    end
end

wire ltssm_state_is_detectquiet     = (smlh_ltssm_state == S_DETECT_QUIET);
wire ltssm_state_is_pollactive      = (smlh_ltssm_state == S_POLL_ACTIVE);
wire ltssm_state_is_pollconfig      = (smlh_ltssm_state == S_POLL_CONFIG);
wire ltssm_state_is_rcvrylock       = (smlh_ltssm_state == S_RCVRY_LOCK);
wire ltssm_state_is_rcvryeq0        = (smlh_ltssm_state == S_RCVRY_EQ0);
wire ltssm_state_is_rcvryeq1        = (smlh_ltssm_state == S_RCVRY_EQ1);
wire ltssm_state_is_rcvryeq2        = (smlh_ltssm_state == S_RCVRY_EQ2);
wire ltssm_state_is_rcvryeq3        = (smlh_ltssm_state == S_RCVRY_EQ3);
wire ltssm_state_is_cfglinkwdstart  = (smlh_ltssm_state == S_CFG_LINKWD_START);
wire ltssm_state_is_cfglinkwdacept  = (smlh_ltssm_state == S_CFG_LINKWD_ACEPT);
wire ltssm_state_is_cfglanenumwait  = (smlh_ltssm_state == S_CFG_LANENUM_WAIT);
wire ltssm_state_is_cfglanenumacept = (smlh_ltssm_state == S_CFG_LANENUM_ACEPT);
wire ltssm_state_is_cfgcomplete     = (smlh_ltssm_state == S_CFG_COMPLETE);
wire ltssm_state_is_rcvryrcvrcfg    = (smlh_ltssm_state == S_RCVRY_RCVRCFG);
wire ltssm_state_is_rcvryspeed      = (smlh_ltssm_state == S_RCVRY_SPEED);
wire ltssm_state_is_rcvryidle       = (smlh_ltssm_state == S_RCVRY_IDLE);
wire ltssm_state_is_lpbkentry       = (smlh_ltssm_state == S_LPBK_ENTRY);
wire ltssm_state_poll_cfg           = smlh_ltssm_state == S_POLL_ACTIVE | smlh_ltssm_state == S_POLL_CONFIG | smlh_ltssm_state == S_CFG_LINKWD_START |
                                      smlh_ltssm_state == S_CFG_LINKWD_ACEPT | smlh_ltssm_state == S_CFG_LANENUM_WAIT | smlh_ltssm_state == S_CFG_LANENUM_ACEPT | smlh_ltssm_state == S_CFG_COMPLETE;

//
// active lanes decoded from smlh_link_mode
//
wire [NL-1:0] smlh_lanes_active = smlh_lanes_active_i;
wire [5:0]    smlh_link_mode    = smlh_link_mode_i;

always @( * ) begin : link_mode_lanes_active_PROC
    link_mode_lanes_active =
        (smlh_link_mode == 8 ) ? 8'hFF :
        (smlh_link_mode == 4 ) ? 4'hF :
        (smlh_link_mode == 2 ) ? 2'b11 :
        (smlh_link_mode == 1 ) ? 1'b1 :

        smlh_lanes_active; //keep smlh_lanes_active if smlh_link_mode == 0
end // link_mode_lanes_active_PROC

//
//extract pcnt and ts_info per lane
//
always @( * ) begin : extract_pcnt_ts_info_PROC
    integer n;

    for (n=0; n<NL; n=n+1) begin
        {sym7_lane[n],sym6_lane[n],sym5_lane[n],sym4_lane[n],
         sym3_lane[n],sym2_lane[n],sym1_lane[n]} = smseq_ts_info_bus[n*TSFD_WD +: TSFD_WD];

// In 1b/1b encoding, we should look for PAD
// - in sym1(link#) of Rx TS OSs only in Config, HotReset, Recovery.RcvrCfg and Rcvry.Idle states
// - in sym2(lane#) of Rx TS OSs only in Rcvry.Idle, Config, HotReset states;
// in the other states, sym1/sym2 are either EQ byte 0/1 or reserved, so any F7h value should not be interpreted as PAD (ref Table 4-28 and section 4.2.7 of PCIe base spec 6.0.1)
        link_num_g6_pad_search_en[n] = (ltssm_g6_not_cfg_hotr_rcvrcfg & ltssm_g6_not_rcvridle) ? 1'b0 : 1'b1; // at Gen6, sym1(link#) comparison to PAD is masked when not in Rcvry.Idle, Rcvry.RcvrCfg, Config, HotReset (B310: Rcvry.RcvrLock) states
        lane_num_g6_pad_search_en[n] = ( ltssm_g6_not_cfg_hotr & ltssm_g6_not_rcvridle) ? 1'b0 : 1'b1; // at Gen6, sym2(lane#) comparison to PAD is masked when not in Rcvry.Idle, Config, HotReset (B310: Rcvry.RcvrCfg) states
        {lane_num_pad_lane[n],link_num_pad_lane[n]} = {lane_num_g6_pad_search_en[n], link_num_g6_pad_search_en[n]} & smseq_ts_lanen_linkn_pad_bus[n*2 +: 2];

        {sym15_lane[n],sym14_lane[n],sym13_lane[n],sym12_lane[n],sym11_lane[n],sym10_lane[n],sym9_lane[n],sym8_lane[n]} = smseq_mt_info_bus[n*64 +: 64];
    end
end // extract_pcnt_ts_info_PROC

//
// extract link number (symbol 1), lane number (symbol 2), n_fts number (symbol 3),
// data_rate/auto_change/speed_change (symbol 4), hot_reset/disable_link/loopback/compliance_receive bits (symbol 5),
// gen1/2 eqts (symbol 6 bit 7) and gen3/4 ects (symbol 6 bit[1:0]), and
// gen3 eqts (8gt eqts) (symbol 7 bit[7])
// per lane
//
assign g6_rate = current_data_rate == `GEN6_RATE;
assign ts0_detect_window = g6_rate & (cfg_upstream_port ? (ltssm_state_is_rcvrylock | ltssm_state_is_rcvryeq0 | ltssm_state_is_rcvryeq1) : (ltssm_state_is_rcvryeq1 | ltssm_state_is_rcvryeq2));
always @( * ) begin: extract_s1_s2_s3_s4_s5_s6_s7_PROC
    integer n;
    for (n=0; n<NL; n=n+1) begin
        //extract link number (symbol 1) per lane
        link_num_s1_lane[n]      = sym1_lane[n];
        //extract lane number (symbol 2) per lane
        lane_num_s2_lane[n]      = sym2_lane[n];
        //extract data_rate/auto_change/speed_change (symbol 4) per lane
        flitm_supt_s4_lane[n]    = g6_rate ? 1'b0                 : sym4_lane[n][0]; // flit mode support
        data_rate_s4_lane[n]     = g6_rate ? sym5_lane[n][1 +: 5] : sym4_lane[n][1 +: 5];
        data_rate_g5_s4_lane[n]  = g6_rate ? &sym5_lane[n][5:4]   : sym4_lane[n][5];
        data_rate_g6_s4_lane[n]  = g6_rate ? (sym4_lane[n][5:1] == 5'b10111) : (sym4_lane[n][5:1] == 5'b10111 & flitm_supt_s4_lane[n]); // for gen6 support, need to check flit mode support
        data_rate_g3_s4_lane[n]  = g6_rate ? sym5_lane[n][3]      : sym4_lane[n][3];
        auto_chg_s4_lane[n]      = g6_rate ? sym5_lane[n][6]      : sym4_lane[n][6];
        //extract hot_reset/disable_link/loopback/compliance_receive bits (symbol 5) per lane
        hot_reset_s5_lane[n]     = g6_rate ? sym6_lane[n][0]      : sym5_lane[n][0];
        dis_link_s5_lane[n]      = g6_rate ? sym6_lane[n][1]      : sym5_lane[n][1];
        retimer_pre_ts2_s5_lane[n]      = g6_rate ? 1'b0          : sym5_lane[n][4] & smseq_ts2_rcvd_bus[n]; //retimer present bit only from TS2
        two_retimers_pre_ts2_s5_lane[n] = g6_rate ? 1'b0          : sym5_lane[n][5] & smseq_ts2_rcvd_bus[n]; //two retimers present bit only from TS2
        tmcp_ls_s5_lane[n]       = g6_rate ? 1'b0                 : sym5_lane[n][5] & smseq_ts1_rcvd_bus[n]; //tx mod cmpl pattern only from TS1 for Loopback Slave
        modts_supt_s5_lane[n]    = g6_rate ? 1'b0                 : sym5_lane[n][7:6] == 2'b11; // mod ts support
        full_eq_s5_lane[n]       = g6_rate ? 1'b0                 : sym5_lane[n][7:6] == 2'b00; // full eq required
        ebth_eq_s5_lane[n]       = g6_rate ? 1'b0                 : sym5_lane[n][7:6] == 2'b01; // eq bypass to highest rate
        nend_eq_s5_lane[n]       = g6_rate ? 1'b0                 : sym5_lane[n][7:6] == 2'b10; // no eq needed
        //extract gen1/2 eqts (symbol 6 bit 7) and gen3/4 ects (symbol 6 bit[1:0]) per lane
        pcts_s6_lane[n]          = sym6_lane[n][0]   & (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE);
        eqts_s6_lane[n]          = sym6_lane[n][7]   & (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE);
        // gen6 ts1/2: Sym1[1:0] = EC, Sym1[7] = EQ Request/EQ Redo/Use Preset, Sym2[6] = Tx PPrecoding On
        ects_s6_lane[n]          = g6_rate ? sym1_lane[n][1:0]    : sym6_lane[n][1:0] & {2{(current_data_rate== `GEN3_RATE || current_data_rate== `GEN4_RATE || current_data_rate== `GEN5_RATE)}};
        //extract gen3 eqts (8gt eqts) (symbol 6 bit[7]) per lane
        pcts_g4_s7_lane[n]       = g6_rate ? sym2_lane[n][6]      : sym7_lane[n][0] & (current_data_rate == `GEN4_RATE | current_data_rate == `GEN5_RATE);
        eq8gtts_s7_lane[n]       = g6_rate ? sym1_lane[n][7]      : sym7_lane[n][7] & (current_data_rate==`GEN3_RATE | current_data_rate > `GEN3_RATE);

        //extract n_fts number (symbol 3) per lane
        n_fts_s3_lane[n]         = sym3_lane[n];
        speed_chg_s4_lane[n]     = g6_rate ? sym5_lane[n][7] : sym4_lane[n][7];
        loopback_s5_lane[n]      = g6_rate ? sym6_lane[n][2] : sym5_lane[n][2];
        dis_scramble_s5_lane[n]  = g6_rate ? 1'b0            : sym5_lane[n][3];
        compl_rcv_ts1_s5_lane[n] = g6_rate ? sym6_lane[n][3] & smseq_ts1_rcvd_bus[n] : sym5_lane[n][4] & smseq_ts1_rcvd_bus[n]; //compliance receive bit only from TS1

        apn_s8_lane[n]           = (~smlh_link_up && ltssm_mod_ts) ? (sym8_lane[n][2:0] == 3'b010 & smseq_mt_info_bus[n*64 +: 64] != {8{8'h4A}}) : 1'b0; // Alternate Protocols Negotiation in Mod TS Usage Symbol8[2:0]
        ts2_apn_s8_lane[n]       = (~smlh_link_up && ltssm_mod_ts && smseq_ts2_rcvd_bus[n]) ? (sym8_lane[n][2:0] == 3'b010) : 1'b0; // Alternate Protocols Negotiation in Mod TS Usage Symbol8[2:0]
    end
end // extract_s1_s2_s3_s4_s5_s6_s7_PROC

assign skip_eq_enbl_s5_lane = hot_reset_s5_lane;
assign no_eq_needed_s5_lane = dis_link_s5_lane;

// Enhanced Link Behaviour Control
always @( posedge core_clk or negedge core_rst_n ) begin : link_elbc_rcvd_PROC
    if ( ~core_rst_n )
        link_elbc_rcvd <= #TP 2'b00;
    // smlh_link_up falling edge to clear elbc by gen5 spec 0.71
    else if ( ltssm_state_is_detectquiet || smlh_link_up_falling_edge )
        link_elbc_rcvd <= #TP 2'b00;
    else if ( |(int_8_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts2_rcvd_pulse_bus & ~smseq_mod_ts2_rcvd_pulse_bus & nend_eq_s5_lane & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg ) //elbc only for normal TS2, not mod TS2
        link_elbc_rcvd <= #TP 2'b10;
    else if ( |(int_2_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts1_rcvd_pulse_bus & ~smseq_mod_ts1_rcvd_pulse_bus & nend_eq_s5_lane & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg ) //elbc only for normal TS2, not mod TS2
        link_elbc_rcvd <= #TP 2'b10;
    else if ( |(int_8_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts2_rcvd_pulse_bus & ~smseq_mod_ts2_rcvd_pulse_bus & ebth_eq_s5_lane & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg )
        link_elbc_rcvd <= #TP 2'b01;
    else if ( |(int_2_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts1_rcvd_pulse_bus & ~smseq_mod_ts1_rcvd_pulse_bus & ebth_eq_s5_lane & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg )
        link_elbc_rcvd <= #TP 2'b01;
    else if ( |(int_8_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts2_rcvd_pulse_bus & ~smseq_mod_ts2_rcvd_pulse_bus & modts_supt_s5_lane & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg )
        link_elbc_rcvd <= #TP 2'b11;
    else if ( |(int_2_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts1_rcvd_pulse_bus & ~smseq_mod_ts1_rcvd_pulse_bus & modts_supt_s5_lane & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg )
        link_elbc_rcvd <= #TP 2'b11;
    else if ( |(int_8_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts2_rcvd_pulse_bus & ~smseq_mod_ts2_rcvd_pulse_bus & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg )
        link_elbc_rcvd <= #TP 2'b00;
    else if ( |(int_2_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_ts1_rcvd_pulse_bus & ~smseq_mod_ts1_rcvd_pulse_bus & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) & ltssm_state_poll_cfg )
        link_elbc_rcvd <= #TP 2'b00;
end // link_elbc_rcvd_PROC
/*
always @( posedge core_clk or negedge core_rst_n ) begin : link_elbc_rcvd_PROC
    if ( ~core_rst_n )
        link_elbc_rcvd <= #TP 2'b00;
    // smlh_link_up falling edge to clear elbc by gen5 spec 0.71
    else if ( ltssm_state_is_detectquiet || smlh_link_up_falling_edge )
        link_elbc_rcvd <= #TP 2'b00;
    else if ( link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd && ~|(link_mode_lanes_active & smseq_mod_ts2_rcvd_pulse_bus) && ~ltssm_clear ) //elbc only for normal TS2, not mod TS2
        link_elbc_rcvd <= #TP 2'b10;
    else if ( link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd && ~|(link_mode_lanes_active & smseq_mod_ts2_rcvd_pulse_bus) && ~ltssm_clear )
        link_elbc_rcvd <= #TP 2'b01;
    else if ( link_latched_modts_support )
        link_elbc_rcvd <= #TP 2'b11;
end // link_elbc_rcvd_PROC
*/

// precode request rcvd when eq ts2 & gen5 supported
always @( posedge core_clk or negedge core_rst_n ) begin : link_pc_rcvd_PROC
    integer i;

    if ( ~core_rst_n ) begin
        link_pc_rcvd <= #TP 1'b0;
//    end else if ( smlh_link_up_falling_edge ) begin
    end else if ( ltssm_state_is_detectquiet ) begin
        link_pc_rcvd <= #TP 1'b0;
    end else if ( ltssm_state_is_rcvryrcvrcfg ) begin
        for (i=0; i<NL; i=i+1) begin
            if ( int_8_eq_ts2_rcvd_bus[i] && current_data_rate <= `GEN2_RATE && smlh_lanes_active[i] && data_rate_g5_s4_lane[i] )
                link_pc_rcvd <= #TP pcts_s6_lane[i];
            else if ( int_8_16gteq_ts2_rcvd_bus[i] && current_data_rate == `GEN4_RATE && smlh_lanes_active[i] && data_rate_g5_s4_lane[i] )
                link_pc_rcvd <= #TP pcts_g4_s7_lane[i];
        end
    end
end // link_pc_rcvd_PROC

// precode request rcvd when eq ts2 & gen6 supported
always @( posedge core_clk or negedge core_rst_n ) begin : link_pc6_rcvd_PROC
    integer i;

    if ( ~core_rst_n ) begin
        link_pc6_rcvd <= #TP 1'b0;
    end else if ( ltssm_state_is_detectquiet ) begin
        link_pc6_rcvd <= #TP 1'b0;
    end else if ( ltssm_state_is_rcvryrcvrcfg ) begin
        for (i=0; i<NL; i=i+1) begin
            if ( int_8_32gteq_ts2_rcvd_bus[i] && current_data_rate == `GEN5_RATE && smlh_lanes_active[i] && data_rate_g6_s4_lane[i] ) // support g6 rate at gen5 rate in Rx TS2
                link_pc6_rcvd <= #TP pcts_g4_s7_lane[i];
        end
    end
end // link_pc6_rcvd_PROC

//
//conditional TS1/2 sent count condition_ts_sent_cnt
//
assign latched_any_1_ts_rcvd = latched_any_1_ts2_rcvd | latched_any_1_ts1_rcvd;

always @( posedge core_clk or negedge core_rst_n ) begin : cond_ts_sent_cnt_PROC
    if ( ~core_rst_n ) begin
        condition_ts_sent_cnt <= #TP 0;
    end else if ( ltssm_clear || (current_data_rate == `GEN2_RATE && xmtbyte_eies_sent && condition_ts_sent_cnt<32 && ltssm_state_is_rcvryrcvrcfg) ) begin
        condition_ts_sent_cnt <= #TP 0;
    end else if ( &condition_ts_sent_cnt != 1'b1 ) begin //!saturation
        if ( ltssm_state_is_pollactive && latched_any_1_ts_rcvd ) begin
            // in Polling.Active for 24ms timeout condition, start ts sent count after receiving 1 TS on any lane.
            if ( xmtbyte_ts1_sent[0])
                condition_ts_sent_cnt <= #TP condition_ts_sent_cnt + 1;
        end else if ( ltssm_state_is_rcvryrcvrcfg && latched_any_ts2_spd_chg_rcvd_sent ) begin
        // for Rcvry.RcvrCfg -> Rcvry.Speed
        // ts2 sent count with transmit speed_change bit set to 1 after receiving 1 ts2 with speed_change bit set to 1
            if ( xmtbyte_ts2_sent[0] )
                condition_ts_sent_cnt <= #TP condition_ts_sent_cnt + 1;
        end
    end // end else if ( &condition_ts_sent_cnt
end // cond_ts_sent_cnt_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_ts2_rcvd_and_sent_PROC
    if ( ~core_rst_n )
        latched_any_ts2_rcvd_and_sent <= #TP 0;
    else if ( ltssm_clear )
        latched_any_ts2_rcvd_and_sent <= #TP 0;
    else if ( link_any_ts2_rcvd & |xmtbyte_ts2_sent )
        latched_any_ts2_rcvd_and_sent <= #TP 1;
end // latched_any_ts2_rcvd_and_sent_PROC

// ts2 sent count after receiving 1 ts2, with no intervening eieos (for Rcvry.RcvrCfg -> Rcvry.Idle)
always @( posedge core_clk or negedge core_rst_n ) begin : condition1_ts_sent_cnt_PROC
    if ( ~core_rst_n ) begin
        condition1_ts_sent_cnt <= #TP 0;
    end else if ( ltssm_clear || (xmtbyte_eies_sent && condition1_ts_sent_cnt<16 && ltssm_state_is_rcvryrcvrcfg) ) begin // any intervening Tx EIEOS resets counter of consecutive TS2 sent
        condition1_ts_sent_cnt <= #TP 0;
    end else if ( &condition1_ts_sent_cnt == 1'b1 ) begin //saturation
        condition1_ts_sent_cnt <= #TP condition1_ts_sent_cnt;
    end else if ( ltssm_state_is_rcvryrcvrcfg && link_any_ts2_rcvd ) begin
        if ( xmtbyte_ts2_sent[0])
            condition1_ts_sent_cnt <= #TP condition1_ts_sent_cnt + 1;
    end
end // condition1_ts_sent_cnt_PROC

// ts2 sent count after receiving 1 ts2
always @( posedge core_clk or negedge core_rst_n ) begin : condition2_ts_sent_cnt_PROC
    if ( ~core_rst_n ) begin
        condition2_ts_sent_cnt <= #TP 0;
    end else if ( ltssm_clear ) begin
        condition2_ts_sent_cnt <= #TP 0;
    end else if ( &condition2_ts_sent_cnt == 1'b1 ) begin //saturation
        condition2_ts_sent_cnt <= #TP condition2_ts_sent_cnt;
    end else if ( latched_any_1_ts2_rcvd && ltssm_state_is_pollconfig ) begin
        if ( xmtbyte_ts2_sent[0] )
            condition2_ts_sent_cnt <= #TP condition2_ts_sent_cnt + 1;
    end else if ( ltssm_mod_ts && ~smlh_link_up && ltssm_state_is_cfgcomplete && xmtbyte_ts_data_diff && link_any_ts2_rcvd && |link_latched_live_all_2_ts2_apn_sym14_8_rcvd[35:32] == 1'b1 ) begin
    // for ltssm_mod_ts in Cfg.Complete state the Tx may send different cxl.mem/cache/io/pcie enable bits. need to consider the 16 consecutive TS2s on Tx
        if ( |xmtbyte_ts2_sent )
            condition2_ts_sent_cnt <= #TP 2;
        else
            condition2_ts_sent_cnt <= #TP 1;
    end else if ( (ltssm_state_is_cfgcomplete || ltssm_state_is_rcvryrcvrcfg) && link_any_ts2_rcvd ) begin
        if ( xmtbyte_ts2_sent[0])
            condition2_ts_sent_cnt <= #TP condition2_ts_sent_cnt + 1;
    end
end // condition2_ts_sent_cnt_PROC

//
//generate signals for LTSSM state transitions
//
//
//in Polling.Active
//
// determine 1/2/8 ts received per lane
//int_*_ts_cond_rcvd_bus - consecutive ts received with condition such as 16/32 ts sent and then receive * ts
//int_*_ts_rcvd_bus      - consecutive ts received from begining of the state
//int_*_ts_rcvd_mtx_bus  - consecutive ts received from begining of the state with matching some fields of Tx
always @( * ) begin : int_8_ts1_plinkn_planen_rcvd_bus_PROC
    integer n;

    for (n=0; n<NL; n=n+1) begin
        int_exact_1_ts_cond_rcvd_bus[n] = (smseq_ts_rcvd_cond_pcnt_bus[n*2 +: 2] == 1) & ~ltssm_clear;
        int_exact_2_ts_cond_rcvd_bus[n] = (smseq_ts_rcvd_cond_pcnt_bus[n*2 +: 2] == 2) & ~ltssm_clear;
        int_2_ts_cond_rcvd_bus[n]       = (smseq_ts_rcvd_cond_pcnt_bus[n*2 +: 2] >= 2) & ~ltssm_clear;
        int_1_ts_rcvd_bus[n]            = (smseq_ts_rcvd_pcnt_bus[n*4 +: 4] >= 1) & ~ltssm_clear; //with speed_change set
        int_2_ts_rcvd_bus[n]            = (smseq_ts_rcvd_pcnt_bus[n*4 +: 4] >= 2) & ~ltssm_clear; //with speed_change set
        int_8_ts_rcvd_bus[n]            = (smseq_ts_rcvd_pcnt_bus[n*4 +: 4] >= 8) & ~ltssm_clear; //with speed_change set
        int_1_ts_rcvd_mtx_bus[n]        = (smseq_ts_rcvd_mtx_pcnt_bus[n*4 +: 4] >= 1) & ~ltssm_clear & ~smseq_ts0_rcvd_bus[n];
        int_2_ts_rcvd_mtx_bus[n]        = (smseq_ts_rcvd_mtx_pcnt_bus[n*4 +: 4] >= 2) & ~ltssm_clear & ~smseq_ts0_rcvd_bus[n];
        int_8_ts_rcvd_mtx_bus[n]        = (smseq_ts_rcvd_mtx_pcnt_bus[n*4 +: 4] >= 8) & ~ltssm_clear & ~smseq_ts0_rcvd_bus[n];
        int_8_ts0_rcvd_mtx_bus[n]       = (smseq_ts_rcvd_mtx_pcnt_bus[n*4 +: 4] >= 8) & ~ltssm_clear & smseq_ts0_rcvd_bus[n];
    end
end // int_8_ts1_plinkn_planen_rcvd_bus_PROC

always @( * ) begin : int_1_2_8_ts_linknmtx_rcvd_bus_PROC
    integer n;

    for (n=0; n<NL; n=n+1) begin
        link_num_s1_mtch[n]                   = (  (ltssm_xlinknum == link_num_s1_lane[n])
                                                 | (g6_rate & ltssm_state_is_rcvryrcvrcfg & link_num_s1_lane[n][7] & ~link_num_s1_lane[n][0])      // No Link# in TS2 if Symbol1[7](Request EQ)=1 and Symbol1[0]=0 when Gen6 Recovery.RcvfCfg.
                                                )
                                              & (~ltssm_xk237_4lnknum[n]) 
                                              & (~link_num_pad_lane[n]);
// In 1b/1b encoding, we should check matching between Rx and Tx TS OSs link# in Config, HotReset and Recovery.RcvrCfg states; in the other states, we should assume the match to be true (ref Table 4-28 and section 4.2.7 of PCIe base spec 6.0.1)
        link_num_g6_chck[n]                   = ltssm_g6_not_cfg_hotr_rcvrcfg ? 1'b1 : link_num_s1_mtch[n]; // link# check for gen6 only in Rcvry.RcvrCfg, Config, HotReset states
        int_1_ts_linknmtx_rcvd_bus[n]         = int_1_ts_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=1) & link_num_g6_chck[n]
;
        int_2_ts_linknmtx_rcvd_bus[n]         = int_2_ts_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=2) & link_num_g6_chck[n]
;
        int_8_ts_linknmtx_rcvd_bus[n]         = int_8_ts_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=8) & link_num_g6_chck[n]
;
        in_8_ts0_linknmtx_rcvd_bus[n]         = int_8_ts0_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=8) & link_num_g6_chck[n];
        int_8_ts_linknmtx_spd_chg_rcvd_bus[n] = int_8_ts_rcvd_bus[n]     & (xmtbyte_ts_pcnt>=8) & link_num_g6_chck[n]
;
    end
end // int_1_2_8_ts_linknmtx_rcvd_bus_PROC

always @( * ) begin : int_1_2_8_ts_lanenmtx_rcvd_bus_PROC
    integer n;

    for (n=0; n<NL; n=n+1) begin
        lane_num_s2_mtch[n]                   = (n == lane_num_s2_lane[n]) & (~ltssm_xk237_4lannum[n]);
// In 1b/1b encoding, we should check matching between Rx and Tx TS OSs lane# in Config and HotReset states; in the other states, we should assume the match to be true (ref Table 4-28 and section 4.2.7 of PCIe base spec 6.0.1)
        lane_num_g6_chck[n]                   = ltssm_g6_not_cfg_hotr ? 1'b1 : lane_num_s2_mtch[n];  // lane# check for gen6 only in Config, HotReset states
        int_1_ts_lanenmtx_rcvd_bus[n]         = int_1_ts_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=1) & lane_num_g6_chck[n];
        int_2_ts_lanenmtx_rcvd_bus[n]         = int_2_ts_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=2) & lane_num_g6_chck[n];
        int_8_ts_lanenmtx_rcvd_bus[n]         = int_8_ts_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=8) & lane_num_g6_chck[n];
        in_8_ts0_lanenmtx_rcvd_bus[n]         = int_8_ts0_rcvd_mtx_bus[n] & (xmtbyte_ts_pcnt>=8) & lane_num_g6_chck[n];
        int_8_ts_lanenmtx_spd_chg_rcvd_bus[n] = int_8_ts_rcvd_bus[n]     & (xmtbyte_ts_pcnt>=8) & lane_num_g6_chck[n];
    end
end // int_1_2_8_ts1_lanenmtx_rcvd_bus_PROC

assign int_ts1_plinkn_planen_rcvd_bus      = smseq_ts1_rcvd_pulse_bus & link_num_pad_lane & lane_num_pad_lane;
assign int_ts0_linkn_rcvd_bus              = smseq_ts0_rcvd_bus;
assign int_ts0_lanen_rcvd_bus              = smseq_ts0_rcvd_bus;

reg [NL-1:0] latched_rx_ts0;
wire ts0_clear_state = (ltssm_state_is_detectquiet | ltssm_state_is_rcvrylock | ltssm_state_is_rcvryspeed | ltssm_state_is_lpbkentry);
always @( posedge core_clk or negedge core_rst_n ) begin : latched_rx_ts0_PROC
    integer n;

    if ( ~core_rst_n )
        latched_rx_ts0 <= #TP 0;
    else if ( ts0_clear_state )
        latched_rx_ts0 <= #TP 0;
    else if ( ts0_detect_window ) begin
        for (n=0; n<NL; n=n+1) begin
            if ( smseq_ts0_rcvd_bus[n] )
                latched_rx_ts0[n] <= #TP 1'b1;
        end
    end
end // latched_rx_ts0_PROC

wire rx_ts0_to_ts1 = |(latched_rx_ts0 & smseq_ts1_rcvd_pulse_bus & smlh_lanes_active); // multi pulse because of skew

reg  rx_ts0_to_ts1_d, rx_ts0_to_ts1_dd;
always @( posedge core_clk or negedge core_rst_n ) begin : rx_ts0_to_ts1_d_PROC
    if ( ~core_rst_n )
        rx_ts0_to_ts1_d <= #TP 0;
    else if ( ts0_clear_state )
        rx_ts0_to_ts1_d <= #TP 0;
    else if ( rx_ts0_to_ts1 )
        rx_ts0_to_ts1_d <= #TP 1'b1;
end // rx_ts0_to_ts1_d_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : rx_ts0_to_ts1_dd_PROC
    if ( ~core_rst_n )
        rx_ts0_to_ts1_dd <= #TP 0;
    else
        rx_ts0_to_ts1_dd <= #TP rx_ts0_to_ts1_d;
end // rx_ts0_to_ts1_dd_PROC

assign link_rx_ts0_to_ts1_pulse = rx_ts0_to_ts1_d & ~rx_ts0_to_ts1_dd; // single pulse since the first ts1 rcvd on all lanes
assign int_ts1_linkn_rcvd_bus              = smseq_ts1_rcvd_bus & (~link_num_pad_lane);
assign int_ts1_lanen_rcvd_bus              = smseq_ts1_rcvd_bus & (~lane_num_pad_lane);
assign int_ts2_linkn_rcvd_bus              = smseq_ts2_rcvd_bus & (~link_num_pad_lane);
assign int_ts2_lanen_rcvd_bus              = smseq_ts2_rcvd_bus & (~lane_num_pad_lane);
assign current_2_ts1_rcvd_bus              = int_2_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus;
assign current_8_ts1_rcvd_bus              = int_8_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus;
assign int_2_ts2_rcvd_bus                  = int_2_ts_rcvd_mtx_bus & smseq_ts2_rcvd_bus;
assign current_2_ts1_linkn_rcvd_bus        = current_2_ts1_rcvd_bus & (~link_num_pad_lane);
assign current_2_ts1_linkn_planen_rcvd_bus = current_2_ts1_rcvd_bus & (~link_num_pad_lane) & lane_num_pad_lane;
assign current_8_ts_plinkn_planen_rcvd_bus              = int_8_ts_rcvd_mtx_bus & link_num_pad_lane & lane_num_pad_lane;
assign current_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus = smseq_ts1_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & (~compl_rcv_ts1_s5_lane);
assign current_8_ts1_plinkn_planen_lpbk1_rcvd_bus       = smseq_ts1_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & loopback_s5_lane;
assign current_8_ts2_plinkn_planen_rcvd_bus             = smseq_ts2_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus;
// Mod TS Supported & (~retimer | gen5_support)
assign current_8_ts2_plinkn_planen_modts_supt_rcvd      = (|(smlh_lanes_active & smseq_ts2_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & {NL{ltssm_ts_data_rate[4]}} & modts_supt_s5_lane & data_rate_g5_s4_lane)) & ltssm_state_is_pollconfig;
assign current_8_ts2_plinkn_planen_modts_supt_rcvd_clear= (|(smlh_lanes_active & smseq_ts2_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & {NL{ltssm_ts_data_rate[4]}} & ~(modts_supt_s5_lane & data_rate_g5_s4_lane))) & ltssm_state_is_pollconfig;
assign current_8_ts1_plinkn_planen_flitm_supt_rcvd      = (|(smlh_lanes_active & smseq_ts1_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & flitm_supt_s4_lane)) & ltssm_state_is_pollactive;
assign current_8_ts2_plinkn_planen_flitm_supt_rcvd      = (|(smlh_lanes_active & smseq_ts2_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & flitm_supt_s4_lane)) & ltssm_state_is_pollconfig;
assign current_8_ts2_plinkn_planen_flitm_supt_rcvd_clear= (|(smlh_lanes_active & smseq_ts2_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & ~(flitm_supt_s4_lane))) & ltssm_state_is_pollconfig;
assign current_2_ts1_linknmtx_lanenmtx_skipeq_enbl_rcvd = (|(link_mode_lanes_active & current_2_ts1_linknmtx_lanenmtx_rcvd_bus & skip_eq_enbl_s5_lane)) & ~cfg_upstream_port & (ltssm_state_is_cfglanenumwait | ltssm_state_is_cfglanenumacept);
assign current_2_ts2_skipeq_enbl_rcvd                   = (|(link_mode_lanes_active & int_2_ts2_rcvd_bus & skip_eq_enbl_s5_lane)) & cfg_upstream_port & ltssm_state_is_cfglanenumwait;
assign current_2_ts2_linknmtx_lanenmtx_skipeq_enbl_rcvd = (|(link_mode_lanes_active & current_2_ts2_linknmtx_lanenmtx_rcvd_bus & skip_eq_enbl_s5_lane)) & cfg_upstream_port & ltssm_state_is_cfglanenumacept;
assign current_8_ts2_linknmtx_lanenmtx_skipeq_enbl_rcvd = (|(link_mode_lanes_active & current_8_ts2_linknmtx_lanenmtx_rcvd_bus & skip_eq_enbl_s5_lane)) & ltssm_state_is_cfgcomplete;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts1_linkn_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts1_linkn_rcvd_bus                     <= #TP 0;
        latched_8_ts_plinkn_planen_rcvd_bus              <= #TP 0;
        latched_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus <= #TP 0;
        latched_8_ts1_plinkn_planen_lpbk1_rcvd_bus           <= #TP 0;
        latched_8_ts2_plinkn_planen_rcvd_bus             <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_2_ts1_linkn_rcvd_bus                     <= #TP 0;
        latched_8_ts_plinkn_planen_rcvd_bus              <= #TP 0;
        latched_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus <= #TP 0;
        latched_8_ts1_plinkn_planen_lpbk1_rcvd_bus           <= #TP 0;
        latched_8_ts2_plinkn_planen_rcvd_bus             <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_2_ts1_linkn_rcvd_bus[n] )
                latched_2_ts1_linkn_rcvd_bus[n]                     <= #TP 1;

            if ( current_8_ts_plinkn_planen_rcvd_bus[n] )
                latched_8_ts_plinkn_planen_rcvd_bus[n]              <= #TP 1;

            if ( current_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus[n] )
                latched_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts1_plinkn_planen_lpbk1_rcvd_bus[n] )
                latched_8_ts1_plinkn_planen_lpbk1_rcvd_bus[n]           <= #TP 1;

            if ( current_8_ts2_plinkn_planen_rcvd_bus[n] )
                latched_8_ts2_plinkn_planen_rcvd_bus[n]             <= #TP 1;
        end
    end
end // latched_2_ts1_linkn_rcvd_bus_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_flitm_support_PROC
    if ( ~core_rst_n )
        link_latched_flitm_support <= #TP 0;
    else begin
        if ( ltssm_clear && ltssm_state_is_pollactive )
            link_latched_flitm_support[0] <= #TP 1'b0;
        else if ( current_8_ts1_plinkn_planen_flitm_supt_rcvd ) // [0]: Polling.Active
            link_latched_flitm_support[0] <= #TP 1'b1;

        if ( (ltssm_clear && ltssm_state_is_pollconfig) || current_8_ts2_plinkn_planen_flitm_supt_rcvd_clear ) // clear if some lanes receive 8 TS2 in Polling.Config but they have flitm_supt=0
            link_latched_flitm_support[1] <= #TP 1'b0;
        else if ( current_8_ts2_plinkn_planen_flitm_supt_rcvd ) // [1]: Polling.Config
            link_latched_flitm_support[1] <= #TP 1'b1;
    end
end // link_latched_flitm_support_PROC

always @( * ) begin : link_latched_modts_support_PROC
    link_latched_modts_support = link_latched_modts_support_d;
    link_latched_mdfts_support = link_latched_mdfts_support_d;

    if ( ltssm_state_is_detectquiet ) begin
        link_latched_modts_support = 0;
        link_latched_mdfts_support = 0;
    end else begin
        if ( current_8_ts2_plinkn_planen_modts_supt_rcvd_clear ) // clear if some lanes receive 8 TS2 in Polling.Config but they have modts_supt=0 or gen5_supt=0
            link_latched_modts_support = 0;
        else if ( current_8_ts2_plinkn_planen_modts_supt_rcvd )
            link_latched_modts_support = 1;

        if ( smlh_link_up_falling_edge )
            link_latched_mdfts_support = 0;
        else if ( |(int_2_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_mod_ts2_rcvd_pulse_bus & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) )
            link_latched_mdfts_support = 1;
        else if ( |(int_2_ts_rcvd_mtx_bus & link_mode_lanes_active & smseq_mod_ts1_rcvd_pulse_bus & data_rate_g5_s4_lane & {NL{~ltssm_clear & ~smlh_link_up}}) )
            link_latched_mdfts_support = 1;
    end
end // link_latched_modts_support_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_modts_support_d_PROC
    if ( ~core_rst_n ) begin
        link_latched_modts_support_d <= #TP 0;
        link_latched_mdfts_support_d <= #TP 0;
    end else begin
        link_latched_modts_support_d <= #TP link_latched_modts_support;
        link_latched_mdfts_support_d <= #TP link_latched_mdfts_support;
    end
end // link_latched_modts_support_d_PROC

// catch skip eq enable from sym5[6] in Cfg.Lanenum.Wait/.Lanenum.Acept/.Complete
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_skipeq_enable_PROC
    if ( ~core_rst_n ) begin
        link_latched_skipeq_enable <= #TP 0;
    end else if ( ltssm_state_is_detectquiet ) begin
        link_latched_skipeq_enable <= #TP 0;
    end else if ( current_2_ts1_linknmtx_lanenmtx_skipeq_enbl_rcvd | current_2_ts2_skipeq_enbl_rcvd | current_2_ts2_linknmtx_lanenmtx_skipeq_enbl_rcvd | current_8_ts2_linknmtx_lanenmtx_skipeq_enbl_rcvd ) begin
        link_latched_skipeq_enable <= #TP 1;
    end
end // link_latched_skipeq_enable_PROC

assign int_2_ts1_linkn_rcvd_bus                     = current_2_ts1_linkn_rcvd_bus | latched_2_ts1_linkn_rcvd_bus;
assign int_8_ts_plinkn_planen_rcvd_bus              = current_8_ts_plinkn_planen_rcvd_bus | latched_8_ts_plinkn_planen_rcvd_bus;
assign int_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus = current_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus | latched_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus;
assign int_8_ts1_plinkn_planen_lpbk1_rcvd_bus       = current_8_ts1_plinkn_planen_lpbk1_rcvd_bus | latched_8_ts1_plinkn_planen_lpbk1_rcvd_bus;
assign int_8_ts2_plinkn_planen_rcvd_bus             = current_8_ts2_plinkn_planen_rcvd_bus | latched_8_ts2_plinkn_planen_rcvd_bus;

// 1024 ts1 sent (from xmlh) and all lanes receive 8 ts below
assign link_latched_live_all_8_ts_plinkn_planen_rcvd              = &( ~smlh_lanes_active | int_8_ts_plinkn_planen_rcvd_bus );
assign link_latched_live_all_8_ts1_plinkn_planen_compl_rcv_0_rcvd = &( ~smlh_lanes_active | int_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus );
assign link_latched_live_all_8_ts1_plinkn_planen_lpbk1_rcvd       = &( ~smlh_lanes_active | int_8_ts1_plinkn_planen_lpbk1_rcvd_bus );
assign link_latched_live_all_8_ts2_plinkn_planen_rcvd             = &( ~smlh_lanes_active | int_8_ts2_plinkn_planen_rcvd_bus );

// after 24ms timeout, any lane (lane 0 here) RECEIVED 8 ts below and 1024 ts1 sent after receiving 1 ts1/2
assign current_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus = smseq_ts1_rcvd_bus & current_8_ts_plinkn_planen_rcvd_bus & compl_rcv_ts1_s5_lane & (~loopback_s5_lane);

always @( * ) begin : latched_live_any_plinkn_planen_rcvd_PROC
    link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_0_rcvd = |(smlh_lanes_active & int_8_ts1_plinkn_planen_compl_rcv_0_rcvd_bus);
    link_latched_live_any_8_ts1_plinkn_planen_lpbk1_rcvd       = |(smlh_lanes_active & int_8_ts1_plinkn_planen_lpbk1_rcvd_bus);
    link_latched_live_any_8_ts2_plinkn_planen_rcvd             = |(smlh_lanes_active & int_8_ts2_plinkn_planen_rcvd_bus);
    link_latched_live_any_8_ts_plinkn_planen_rcvd              = |(smlh_lanes_active & int_8_ts_plinkn_planen_rcvd_bus);
end // latched_live_any_plinkn_planen_rcvd_PROC

assign link_latched_live_any_8_ts_plinkn_planen_rcvd_bus       = int_8_ts_plinkn_planen_rcvd_bus;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_plinkn_planen_rcvd_d_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus <= #TP 0;

        latched_any_1_ts1_rcvd                                      <= #TP 0;
        latched_any_1_ts2_rcvd                                      <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus <= #TP 0;

        latched_any_1_ts1_rcvd                                      <= #TP 0;
        latched_any_1_ts2_rcvd                                      <= #TP 0;
    end else begin
        for (n=0; n<NL; n=n+1) begin
            if ( current_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus[n] )
                latched_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus[n] <= #TP 1; //lane RECEIVED 8 ts1 with compl_rcv==1 and lpbk==0
        end

        // receiving 1 ts is used to trigger ts sent count condition_ts_sent_cnt
        if ( |(smseq_ts1_rcvd_pulse_bus & smlh_lanes_active) )
            latched_any_1_ts1_rcvd                                      <= #TP 1;
        if ( |(smseq_ts2_rcvd_pulse_bus & smlh_lanes_active) )
            latched_any_1_ts2_rcvd                                      <= #TP 1;
    end
end // latched_any_plinkn_planen_rcvd_PROC

always @(posedge core_clk or negedge core_rst_n) begin: latched_ts2_spd_chg_0_rcvd_PROC
    if (!core_rst_n) begin
        latched_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus <= #TP '0;
        latched_8_ts2_spd_chg_0_plinkn_rcvd_bus         <= #TP '0;
        latched_any_8_ts2_spd_chg_0_rcvd                <= #TP 1'b0;
    end else if (ltssm_clear) begin
        latched_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus <= #TP '0;
        latched_8_ts2_spd_chg_0_plinkn_rcvd_bus         <= #TP '0;
        latched_any_8_ts2_spd_chg_0_rcvd                <= #TP 1'b0;
    end else begin
        for (int n = 0; n < NL; n++) begin
            if (current_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus[n]) begin
                latched_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus[n] <= #TP 1'b1;
            end

            if (current_8_ts2_spd_chg_0_plinkn_rcvd_bus[n]) begin
                latched_8_ts2_spd_chg_0_plinkn_rcvd_bus[n] <= #TP 1'b1;
            end
        end

        if (current_any_8_ts2_spd_chg_0_rcvd) begin
            latched_any_8_ts2_spd_chg_0_rcvd <= #TP 1'b1;
        end
    end
end // latched_ts2_spd_chg_0_rcvd_PROC


// eight consecutive TS1 Ordered Sets are received after receiving a TS2 Ordered Set on any configured Lane
// the speed_change bit is 0b on the received TS1/2 Ordered Sets
assign current_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus           = latched_1_ts2_spd_chg_0_rcvd_bus & (int_8_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus & ~speed_chg_s4_lane);
assign link_latched_live_any_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd = |(smlh_lanes_active & (current_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus | latched_8_ts1_spd_chg_0_rcvd_after_ts2_rcvd_bus)); // module output

// eight consecutive TS2 Ordered Sets are received on any configured Lane
// the speed_change bit is 0b on the received TS2 Ordered Sets
// signal name current_8_ts2_spd_chg_0_rcvd_bus is used already for link/lane num matching tx
assign current_8_ts2_spd_chg_0_rcvd_bus_i         = (int_8_ts_rcvd_mtx_bus & smseq_ts2_rcvd_bus) & ~speed_chg_s4_lane;
assign current_any_8_ts2_spd_chg_0_rcvd           = |(smlh_lanes_active & current_8_ts2_spd_chg_0_rcvd_bus_i);
assign link_latched_live_any_8_ts2_spd_chg_0_rcvd = current_any_8_ts2_spd_chg_0_rcvd | latched_any_8_ts2_spd_chg_0_rcvd; // module output

// Received 8 TS2s w/ linkn PAD
// the speed_change bit is 0b on the received TS2 Ordered Sets
assign current_8_ts2_spd_chg_0_plinkn_rcvd_bus           = current_8_ts2_spd_chg_0_rcvd_bus_i & link_num_pad_lane;
assign link_latched_live_any_8_ts2_spd_chg_0_plinkn_rcvd = |(smlh_lanes_active & (current_8_ts2_spd_chg_0_plinkn_rcvd_bus | latched_8_ts2_spd_chg_0_plinkn_rcvd_bus)); // module output

assign link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd = |(smlh_lanes_active & (current_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus | latched_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus));

always @* begin : link_latched_ts_data_rate_PROC
    integer n;

    link_latched_ts_data_rate = latched_ts_data_rate;

    for ( n=0; n<NL; n=n+1 ) begin
        if ( ltssm_state_is_pollactive && ~ltssm_clear ) begin //any active lane receives 8 ts1
            if ( current_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd_bus[n] && smlh_lanes_active[n] ) begin
                link_latched_ts_data_rate = (data_rate_s4_lane[n] != latched_ts_data_rate) ? data_rate_s4_lane[n] : latched_ts_data_rate;
            end
//        end else if ( ltssm_state_is_pollconfig && ~ltssm_clear ) begin // any active lane receives 8 ts2
//            if ( current_8_ts2_plinkn_planen_rcvd_bus[n] && smlh_lanes_active[n] ) begin
//                link_latched_ts_data_rate = (data_rate_s4_lane[n] != latched_ts_data_rate) ? data_rate_s4_lane[n] : latched_ts_data_rate;
//            end
        end else if ( ltssm_state_is_rcvryrcvrcfg && ~ltssm_clear ) begin
            // any active lane receives 8 TS2s without link#/lane# match check if speed_change=1
            if ( (int_8_ts2_spd_chg_1_rcvd_bus[n] || current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n]) && link_mode_lanes_active[n] ) begin
                link_latched_ts_data_rate = (data_rate_s4_lane[n] != latched_ts_data_rate) ? data_rate_s4_lane[n] : latched_ts_data_rate;
            end
        end else if ( ltssm_state_is_cfgcomplete && ~ltssm_clear ) begin
            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] && link_mode_lanes_active[n] ) begin //any active lane receives 8 ts2s
                link_latched_ts_data_rate = (data_rate_s4_lane[n] != latched_ts_data_rate) ? data_rate_s4_lane[n] : latched_ts_data_rate;
            end
        /* end else if ( ltssm_state_is_rcvrylock && ~ltssm_clear ) begin
            if ( int_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_bus[n] && smlh_lanes_active[n] ) begin //any active lane receive 8 ts
                link_latched_ts_data_rate = (data_rate_s4_lane[n] != latched_ts_data_rate) ? data_rate_s4_lane[n] : latched_ts_data_rate;
            end */
        end
    end // for ( n=0; n<NL; n=n+1 )
end // link_latched_ts_data_rate_PROC


// Errata B87: Condition for USP to latch data rate advertised by DSP in Recovery.RcvrLock state (8 TS1 or TS2 received, with matching link#/lane#)
logic [NL-1:0] int_8_ts_linknmtx_lanenmtx_rcvd_notxcnt_bus;
assign int_8_ts_linknmtx_lanenmtx_rcvd_notxcnt_bus = int_8_ts_rcvd_mtx_bus & link_num_g6_chck & lane_num_g6_chck & (smseq_ts1_rcvd_bus | smseq_ts2_rcvd_bus) & (~link_num_pad_lane) & (~lane_num_pad_lane);


// link_latched_ts_spd_chg is used for ltssm_cmd_eqts2/8geqts2 in Recovery.RcvrCfg state. So latch it in Recovery.RcvrLock state
// link_latched_ts_data_rate_ever is used for DSP to send EQ TS2 in Recovery.RcvrCfg state. Latching in R.Lock (B87; USP only), R.Cfg and Cfg.Complete since exiting Detect
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_ts_data_rate_spd_chg_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_ts_data_rate           <= #TP 0;
        link_latched_ts_data_rate_ever <= #TP 0;
        link_latched_ts_spd_chg        <= #TP 0;
    end else begin
        latched_ts_data_rate <= #TP link_latched_ts_data_rate;

        if ( ~(ltssm_state_is_rcvrylock || ltssm_state_is_rcvryrcvrcfg) ) begin // reset if not in Rcvry.RcvrLock || Rcvry.RcvrCfg
            link_latched_ts_spd_chg <= #TP 0;
        end

        for ( n=0; n<NL; n=n+1 ) begin
            if ( (ltssm_state_is_cfgcomplete || ltssm_state_is_rcvryrcvrcfg) && ~ltssm_clear ) begin
                if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] && link_mode_lanes_active[n] ) begin //any active lane receives 8 ts2s
                    link_latched_ts_data_rate_ever <= #TP data_rate_s4_lane[n];
                end
            end

            if ( ltssm_state_is_rcvrylock && ~ltssm_clear ) begin
                if ( int_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_bus[n] && smlh_lanes_active[n] ) begin //any active lane receive 8 ts
                    link_latched_ts_spd_chg   <= #TP speed_chg_s4_lane[n];
                end
            end

            if ( ltssm_state_is_rcvrylock && cfg_upstream_port && ~ltssm_clear ) begin
                if ( int_8_ts_linknmtx_lanenmtx_rcvd_notxcnt_bus[n] && smlh_lanes_active[n] ) begin //any active lane receives 8 ts1s/ts2s
                    link_latched_ts_data_rate_ever <= #TP data_rate_s4_lane[n];
                end
            end
        end // for ( n=0; n<NL; n=n+1
    end
end // link_latched_ts_data_rate_spd_chg_PROC

// get data rate with speed_change==1
always @* begin : link_any_8_ts_spd_chg_1_data_rate_PROC
    integer n;

    link_any_8_ts_spd_chg_1_data_rate = 0;
    for ( n=0; n<NL; n=n+1 ) begin
        if ( smlh_lanes_active[n] && int_8_ts_rcvd_mtx_bus[n] && speed_chg_s4_lane[n] ) begin //the lane n is active
            link_any_8_ts_spd_chg_1_data_rate = data_rate_s4_lane[n];
        end
    end
end // link_any_8_ts_spd_chg_1_data_rate_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : link_ts_data_rate_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_ts_data_rate <= #TP 0;
        link_ts_spd_chg   <= #TP 0;
    end else begin
        if ( ltssm_clear ) begin
            link_ts_data_rate <= #TP 0;
            link_ts_spd_chg   <= #TP 0;
        end else begin
            for ( n=0; n<NL; n=n+1 ) begin
                if ( smlh_lanes_active[n] && (smseq_ts1_rcvd_pulse_bus[n] || smseq_ts2_rcvd_pulse_bus[n]) ) begin
                    link_ts_data_rate <= #TP data_rate_s4_lane[n];
                    link_ts_spd_chg   <= #TP speed_chg_s4_lane[n];
                end
            end // for ( n=0
        end // end else begin
    end
end // link_ts_data_rate_PROC

//determine loopback data rate and deemphasis for slave
always @( * ) begin : link_lpbk_ts_data_rate_PROC
    integer n;

    link_lpbk_ts_data_rate  = 0;
    link_lpbk_ts_deemphasis = 0;
    for ( n=0; n<NL; n=n+1 ) begin
        // for gen6 at gen5 rate, need to get gen6 rate support in EQ1 for Loopback gen6 eq
        if ( smlh_lanes_active[n] && (current_2_ts1_lpbk1_rcvd_bus[n] || (current_2_ts1_rcvd_bus[n] && current_data_rate == `GEN5_RATE && ltssm_state_is_rcvryeq1)) ) begin //any active lane receives 2 ts1s
            link_lpbk_ts_data_rate  = data_rate_g6_s4_lane[n] ? 5'b10111 : data_rate_s4_lane[n];
            link_lpbk_ts_deemphasis = auto_chg_s4_lane[n];
        end
    end
end // link_lpbk_ts_data_rate_PROC

//determine loopback data rate for master
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_lpbk_ts_data_rate_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_latched_lpbk_ts_data_rate <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
//            if ( int_2_ts_rcvd_bus[n] && smlh_lanes_active[n] ) begin //any active lane receives 2 TSs
            if ( int_2_ts_rcvd_mtx_bus[n] && smlh_lanes_active[n] ) begin //any active lane receives 2 TSs
                link_latched_lpbk_ts_data_rate <= #TP data_rate_g6_s4_lane[n] ? 5'b10111 : data_rate_s4_lane[n];
            end
        end
    end
end // link_latched_lpbk_ts_data_rate_PROC
        

// 1024 ts1 sent after receiving 1 ts
assign link_xmlh_1024_ts1_sent_after_any_1_ts_rcvd = (cfg_fast_link_mode && (condition_ts_sent_cnt >= 16)) || (~cfg_fast_link_mode && (condition_ts_sent_cnt >= 1024));


//
//in Polling.Compliance
//ltssm latches link_latched_live_any_8_ts1_plinkn_planen_compl_rcv_1_lpbk0_rcvd + timeout_24ms in Polling.Active and clear it when exit Polling.Compliance.
//This is used to send modified compliance pattern and state transition.
//


//
//in Polling.Configuration
//ltssm uses link_latched_live_any_8_ts2_plinkn_planen_rcvd for state transition from Polling.Configuration to Cfg.Linkwidth.Start
//
// 16 ts2 sent after receiving 1 ts2
assign link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies = ( condition1_ts_sent_cnt >= 16 );
assign link_xmlh_16_ts2_sent_after_1_ts2_rcvd        = ( condition2_ts_sent_cnt >= 16 );
assign link_xmlh_16_ts1_sent                         = ( condition2_ts_sent_cnt >= 16 ) & ltssm_state_is_rcvrylock & ~ltssm_clear;



//
//in Cfg.Linkwidth.Start for DSP
//
//all lanes receive 2 ts1 with disable_link==1
assign current_2_ts1_dis1_rcvd_bus              = current_2_ts1_rcvd_bus & dis_link_s5_lane;
assign current_2_ts1_lpbk1_rcvd_bus             = current_2_ts1_rcvd_bus & loopback_s5_lane;
assign current_2_ts1_lpbk1_ebth1_rcvd_bus       = current_2_ts1_lpbk1_rcvd_bus & ebth_eq_s5_lane;
assign current_2_ts1_lpbk1_tmcp1_rcvd_bus       = current_2_ts1_lpbk1_rcvd_bus & tmcp_ls_s5_lane;
assign current_2_ts1_lpbk1_compl_rcv_1_rcvd_bus = current_2_ts1_lpbk1_rcvd_bus & compl_rcv_ts1_s5_lane;
// ltssm_state_is_cfglinkwdacept is for usp may receive AP negotiation from dsp which is in ltssm_state_is_cfglanenumwait
assign current_2_ts1_apn_rcvd_bus               = current_2_ts1_rcvd_bus & apn_s8_lane & {NL{(ltssm_state_is_cfglinkwdacept | ltssm_state_is_cfglanenumwait | ltssm_state_is_cfglanenumacept | ltssm_state_is_cfgcomplete) & ~ltssm_clear}};
assign current_8_ts2_apn_rcvd_bus               = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & ts2_apn_s8_lane & {NL{ltssm_state_is_cfgcomplete & ~ltssm_clear}};
assign current_2_ts2_apn_rcvd_bus               = current_2_ts2_linknmtx_lanenmtx_rcvd_bus & ts2_apn_s8_lane & {NL{ltssm_state_is_cfglanenumacept & ~ltssm_clear}};

always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts1_dis_lpbk_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts1_dis1_rcvd_bus                      <= #TP 0;
        latched_2_ts1_lpbk1_rcvd_bus                     <= #TP 0;
        latched_2_ts1_lpbk1_compl_rcv_1_rcvd_bus         <= #TP 0;
        latched_2_ts1_lpbk1_ebth1_rcvd_bus               <= #TP 0;
        latched_2_ts1_lpbk1_tmcp1_rcvd_bus               <= #TP 0;
        latched_2_ts1_apn_rcvd_bus                       <= #TP 0;
        latched_2_ts2_apn_rcvd_bus                       <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_2_ts1_dis1_rcvd_bus                      <= #TP 0;
        latched_2_ts1_lpbk1_rcvd_bus                     <= #TP 0;
        latched_2_ts1_lpbk1_compl_rcv_1_rcvd_bus         <= #TP 0;
        latched_2_ts1_lpbk1_ebth1_rcvd_bus               <= #TP 0;
        latched_2_ts1_lpbk1_tmcp1_rcvd_bus               <= #TP 0;
        latched_2_ts2_apn_rcvd_bus                       <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_2_ts1_dis1_rcvd_bus[n] )
                latched_2_ts1_dis1_rcvd_bus[n]           <= #TP 1;

            if ( current_2_ts1_lpbk1_rcvd_bus[n] )
                latched_2_ts1_lpbk1_rcvd_bus[n]          <= #TP 1;

            if ( current_2_ts1_lpbk1_compl_rcv_1_rcvd_bus[n] )
                latched_2_ts1_lpbk1_compl_rcv_1_rcvd_bus[n] <= #TP 1;

            if ( current_2_ts1_lpbk1_ebth1_rcvd_bus[n] )
                latched_2_ts1_lpbk1_ebth1_rcvd_bus[n] <= #TP 1;

            if ( current_2_ts1_lpbk1_tmcp1_rcvd_bus[n] )
                latched_2_ts1_lpbk1_tmcp1_rcvd_bus[n] <= #TP 1;

            if ( ~(ltssm_state_is_cfglinkwdacept | ltssm_state_is_cfglanenumwait | ltssm_state_is_cfglanenumacept | ltssm_state_is_cfgcomplete) )
                latched_2_ts1_apn_rcvd_bus[n] <= #TP 1'b0;
            else if ( current_2_ts1_apn_rcvd_bus[n] )
                latched_2_ts1_apn_rcvd_bus[n] <= #TP 1'b1;

            if ( ~(ltssm_state_is_cfglanenumacept) )
                latched_2_ts2_apn_rcvd_bus[n] <= #TP 1'b0;
            else if ( current_2_ts2_apn_rcvd_bus[n] )
                latched_2_ts2_apn_rcvd_bus[n] <= #TP 1'b1;

        end
    end
end // latched_2_ts1_dis_lpbk_PROC

// rcvd TS1s with lpbk=1 in Loopback.Entry and in sending TS1s command and after speed change
always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts1_lpbk1_rcvd_bus_post_spd_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts1_lpbk1_rcvd_bus_post_spd                     <= #TP 0;
    end else if ( ltssm_clear || ~ltssm_lpbk_entry_send_ts1 ) begin
        latched_2_ts1_lpbk1_rcvd_bus_post_spd                     <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_2_ts1_lpbk1_rcvd_bus[n] )
                latched_2_ts1_lpbk1_rcvd_bus_post_spd[n]          <= #TP 1;
        end
    end 
end // latched_2_ts1_lpbk1_rcvd_bus_post_spd_PROC

assign int_2_ts1_lpbk1_rcvd_bus_post_spd      = current_2_ts1_lpbk1_rcvd_bus | latched_2_ts1_lpbk1_rcvd_bus_post_spd;

assign int_2_ts1_dis1_rcvd_bus                = current_2_ts1_dis1_rcvd_bus | latched_2_ts1_dis1_rcvd_bus;
assign int_2_ts1_lpbk1_rcvd_bus               = current_2_ts1_lpbk1_rcvd_bus | latched_2_ts1_lpbk1_rcvd_bus;
assign int_2_ts1_lpbk1_ebth1_rcvd_bus         = current_2_ts1_lpbk1_ebth1_rcvd_bus | latched_2_ts1_lpbk1_ebth1_rcvd_bus;
assign int_2_ts1_lpbk1_tmcp1_rcvd_bus         = current_2_ts1_lpbk1_tmcp1_rcvd_bus | latched_2_ts1_lpbk1_tmcp1_rcvd_bus;
assign int_2_ts1_lpbk1_compl_rcv_1_rcvd_bus   = current_2_ts1_lpbk1_compl_rcv_1_rcvd_bus | latched_2_ts1_lpbk1_compl_rcv_1_rcvd_bus;
assign int_2_ts1_apn_rcvd_bus                 = current_2_ts1_apn_rcvd_bus | latched_2_ts1_apn_rcvd_bus;
assign int_2_ts2_apn_rcvd_bus                 = current_2_ts2_apn_rcvd_bus | latched_2_ts2_apn_rcvd_bus;

assign link_latched_live_all_2_ts1_dis1_rcvd  = &( ~smlh_lanes_active | int_2_ts1_dis1_rcvd_bus );

//all lanes receive 2 ts1 with loopback==1
assign link_latched_live_all_2_ts1_lpbk1_rcvd = &( ~smlh_lanes_active | int_2_ts1_lpbk1_rcvd_bus );
assign link_latched_live_all_2_ts1_lpbk1_ebth1_rcvd = ( smlh_lanes_active & int_2_ts1_lpbk1_rcvd_bus & int_2_ts1_lpbk1_ebth1_rcvd_bus );
assign link_latched_live_all_2_ts1_lpbk1_tmcp1_rcvd = ( smlh_lanes_active & int_2_ts1_lpbk1_rcvd_bus & int_2_ts1_lpbk1_tmcp1_rcvd_bus );
//assign link_latched_live_any_2_ts1_apn_rcvd = |( link_mode_lanes_active & int_2_ts1_apn_rcvd_bus ) & (ltssm_state_is_cfglanenumwait | ltssm_state_is_cfglanenumacept | ltssm_state_is_cfgcomplete);

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_live_any_2_ts1_apn_sym14_8_rcvd_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_latched_live_any_2_ts1_apn_sym14_8_rcvd <= #TP 0;
        link_latched_live_any_2_ts1_apn_rcvd <= #TP 0;
    end else begin
        if ( ~(ltssm_state_is_cfglinkwdacept | ltssm_state_is_cfglanenumwait | ltssm_state_is_cfglanenumacept | ltssm_state_is_cfgcomplete) ) begin
            link_latched_live_any_2_ts1_apn_sym14_8_rcvd <= #TP 0;
            link_latched_live_any_2_ts1_apn_rcvd <= #TP 0;
        end else begin
            for ( n=0; n<NL; n=n+1 ) begin
                if ( link_mode_lanes_active[n] && current_2_ts1_apn_rcvd_bus[n] && (cfg_upstream_port ? link_latched_live_any_2_ts1_apn_sym14_8_rcvd == 56'h0 : (sym8_lane[n][4:3] == 2'b01 || sym8_lane[n][4:3] == 2'b10)) )
                    link_latched_live_any_2_ts1_apn_sym14_8_rcvd <= #TP {sym14_lane[n],sym13_lane[n],sym12_lane[n],sym11_lane[n],sym10_lane[n],sym9_lane[n],sym8_lane[n]};
            end

            link_latched_live_any_2_ts1_apn_rcvd <= #TP |( link_mode_lanes_active & int_2_ts1_apn_rcvd_bus ) & (ltssm_state_is_cfglinkwdacept | ltssm_state_is_cfglanenumwait | ltssm_state_is_cfglanenumacept | ltssm_state_is_cfgcomplete);
        end
    end
end // link_latched_live_any_2_ts1_apn_sym14_8_rcvd_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_live_all_8_ts2_apn_sym11_8_rcvd_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_latched_live_all_8_ts2_apn_sym14_8_rcvd <= #TP 0;
    end else begin
        if ( ltssm_state_is_detectquiet ) begin
            link_latched_live_all_8_ts2_apn_sym14_8_rcvd <= #TP 0;
        end else begin
            for ( n=0; n<NL; n=n+1 ) begin
                if ( link_mode_lanes_active[n] && current_8_ts2_apn_rcvd_bus[n] && link_latched_live_all_8_ts2_apn_sym14_8_rcvd[n*56 +: 56] == 56'h0 && ltssm_state_is_cfgcomplete && ~smlh_link_up && ~ltssm_clear )
                    link_latched_live_all_8_ts2_apn_sym14_8_rcvd[n*56 +: 56] <= #TP {sym14_lane[n],sym13_lane[n],sym12_lane[n],sym11_lane[n],sym10_lane[n],sym9_lane[n],sym8_lane[n]};
            end
        end
    end
end // link_latched_live_all_8_ts2_apn_sym11_8_rcvd_PROC

reg [NL-1:0] link_latched_live_all_2_ts2_apn_rcvd_bus;
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_live_all_2_ts2_apn_sym11_8_rcvd_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_latched_live_all_2_ts2_apn_rcvd_bus     <= #TP 0;
        link_latched_live_all_2_ts2_apn_sym14_8_rcvd <= #TP 0;
    end else begin
        if ( ltssm_state_is_detectquiet ) begin
            link_latched_live_all_2_ts2_apn_rcvd_bus     <= #TP 0;
            link_latched_live_all_2_ts2_apn_sym14_8_rcvd <= #TP 0;
        end else begin
            for ( n=0; n<NL; n=n+1 ) begin
                if ( link_mode_lanes_active[n] && current_2_ts2_apn_rcvd_bus[n] && smseq_mod_ts2_rcvd_pulse_bus[n] && ltssm_state_is_cfglanenumacept && ~smlh_link_up && ~ltssm_clear ) begin
                    link_latched_live_all_2_ts2_apn_rcvd_bus[n]              <= #TP 1;
                    link_latched_live_all_2_ts2_apn_sym14_8_rcvd[n*56 +: 56] <= #TP {sym14_lane[n],sym13_lane[n],sym12_lane[n],sym11_lane[n],sym10_lane[n],sym9_lane[n],sym8_lane[n]};
                end else if(~link_mode_lanes_active[n]) begin
                    link_latched_live_all_2_ts2_apn_rcvd_bus[n]              <= #TP 1;
                end
            end
        end
    end
end // link_latched_live_all_2_ts2_apn_sym11_8_rcvd_PROC
assign link_latched_live_all_2_ts2_apn_rcvd = &link_latched_live_all_2_ts2_apn_rcvd_bus;

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd_PROC
    if ( ~core_rst_n ) begin
        link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd <= #TP 0;
    end else if ( ~(ltssm_state_is_lpbkentry || ltssm_state_is_cfglinkwdstart) ) begin
        link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd <= #TP 0;
    end else if ( &( ~smlh_lanes_active | int_2_ts1_lpbk1_compl_rcv_1_rcvd_bus ) && ltssm_state_is_cfglinkwdstart && ~ltssm_clear ) begin
        link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd <= #TP 1;
    end
end // link_latched_all_2_ts1_lpbk1_compl_rcv_1_rcvd_PROC

//any lanes receive 2 ts1 with non-pad link num matching Tx and pad lane num
assign int_2_ts1_linknmtx_planen_rcvd_bus = current_2_ts1_linknmtx_rcvd_bus & lane_num_pad_lane;
assign link_any_2_ts1_linknmtx_planen_rcvd = |(link_mode_lanes_active & int_2_ts1_linknmtx_planen_rcvd_bus);

always @( posedge core_clk or negedge core_rst_n ) begin : latched_1_ts1_plinkn_planen_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_1_ts1_plinkn_planen_rcvd_bus <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_1_ts1_plinkn_planen_rcvd_bus <= #TP 0;
    end else begin
        for (n=0; n<NL; n=n+1) begin
            if ( int_ts1_plinkn_planen_rcvd_bus[n] )
                latched_1_ts1_plinkn_planen_rcvd_bus[n] <= #TP 1;
        end
    end
end // latched_1_ts1_plinkn_planen_rcvd_bus_PROC

//any lanes first RECEIVED 1 ts1 with pad/pad link/lane#, then the same lane receives 2 ts1 with non-pad link# matching Tx and pad lane#
assign link_any_1_ts1_plinkn_planen_first_rcvd_2_ts1_linknmtx_planen_same_lane_rcvd = |(link_mode_lanes_active & latched_1_ts1_plinkn_planen_rcvd_bus & int_2_ts1_linknmtx_planen_rcvd_bus);

//first transmit 16-32 ts1s, then any lanes receive 2 ts1s with non-PAD link# and pad lane#


//
//in Cfg.Linkwidth.Start for USP
//
// any lanes receive 2 ts1 with disable_link bit set
// any lanes receive 8 ts1 with disable_link bit set for cfg_rx_8_ts1s && (ltssm_state_is_rcvryidle || ltssm_state_is_rcvryrcvrcfg)
assign link_any_2_ts1_dis1_rcvd = (cfg_rx_8_ts1s && (ltssm_state_is_rcvryidle || ltssm_state_is_rcvryrcvrcfg)) ? |(smlh_lanes_active & current_8_ts1_rcvd_bus & dis_link_s5_lane) : |(smlh_lanes_active & current_2_ts1_rcvd_bus & dis_link_s5_lane);

// any lanes receive 2 ts1. It is used for receiving SRIS clocking bit when USP loopback lead
assign link_any_2_ts1_rcvd = |(smlh_lanes_active & current_2_ts1_rcvd_bus);

// all link_mode active lanes receive 2 ts1s with non-pad link# and pad lane#
always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts1_linkn_planen_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts1_linkn_planen_rcvd_bus <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_2_ts1_linkn_planen_rcvd_bus <= #TP 0;
    end else begin
        for (n=0; n<NL; n=n+1) begin
            if ( current_2_ts1_linkn_planen_rcvd_bus[n] )
                latched_2_ts1_linkn_planen_rcvd_bus[n] <= #TP 1;
        end
    end
end // latched_2_ts1_linkn_planen_rcvd_bus_PROC

assign int_2_ts1_linkn_planen_rcvd_bus  = current_2_ts1_linkn_planen_rcvd_bus | latched_2_ts1_linkn_planen_rcvd_bus;

assign link_latched_live_all_2_ts1_linkn_planen_rcvd = &( ~link_mode_lanes_active | int_2_ts1_linkn_planen_rcvd_bus );


// lane 0 receives 2 ts1 with non-PAD link# and PAD lane#
assign int_any_2_ts1_linkn_planen_rcvd = |(int_2_ts1_linkn_planen_rcvd_bus & link_mode_lanes_active);

always @( posedge core_clk or negedge core_rst_n ) begin : int_any_2_ts1_linkn_planen_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        int_any_2_ts1_linkn_planen_rcvd_d <= #TP 0;
    end else begin
        int_any_2_ts1_linkn_planen_rcvd_d <= #TP int_any_2_ts1_linkn_planen_rcvd;
    end
end // int_any_2_ts1_linkn_planen_rcvd_d_PROC

assign link_any_2_ts1_linkn_planen_rcvd = int_any_2_ts1_linkn_planen_rcvd & ~int_any_2_ts1_linkn_planen_rcvd_d & ~ltssm_clear; //used to detect link num
assign link_lane0_2_ts1_linkn_planen_rcvd = int_2_ts1_linkn_planen_rcvd_bus[0];
assign link_lane0_2_ts1_linknmtx_rcvd = int_2_ts1_linknmtx_rcvd_bus[0];

always @( * ) begin : link_num_PROC
    integer n;

    link_any_2_ts1_link_num = 0;
    for (n=0; n<NL; n=n+1 ) begin
        if ( int_2_ts1_linkn_planen_rcvd_bus[n] && link_mode_lanes_active[n] )
            link_any_2_ts1_link_num = link_num_s1_lane[n];
    end
end // link_num_PROC

assign int_link_mode_linkn_rcvd_bus = int_2_ts1_linkn_rcvd_bus & link_mode_lanes_active; //non-pad link# received within link_mode lanes
assign int_2_ts1_link_mode_linkn_planen_rcvd_bus = int_2_ts1_linkn_planen_rcvd_bus & link_mode_lanes_active; //non-PAD link# and PAD lane# received on link_mode lanes

assign int_link_mode_linkn_rcvd_reversed_bus = bit_flip( int_2_ts1_linkn_rcvd_bus, smlh_link_mode ); //reverse non-PAD link# lanes within link_mode
assign int_2_ts1_link_mode_linkn_planen_reversed_bus = bit_flip ( int_2_ts1_link_mode_linkn_planen_rcvd_bus, smlh_link_mode ); //reverse non-PAD link# lanes within link_mode
assign int_2_ts1_linknmtx_rcvd_reversed_bus = bit_flip( int_2_ts1_linknmtx_rcvd_bus, smlh_link_mode );

// determine active lanes within link_mode from lane0 or from lane(link_mode-1) if lane0 doesn't have non-pad link# for ltssm_state_is_cfglinkwdstart and ltssm_state_is_cfglinkwdacept.
// determine active lanes within link_mode from lane0 or from lane(link_mode-1) if lane0 doesn't have matching link# or non-pad lane#.
// ltssm_state_is_cfglinkwdstart for USP, ltssm_state_is_cfglinkwdacept for DSP, ltssm_state_is_cfglanenumacept for DSP/USP.
// the lane flip and active lanes are determined at the timeout_1ms pulse in each state specified above.
//assign link_next_link_mode = (ltssm_state_is_cfglinkwdstart | ltssm_state_is_cfglinkwdacept) ? next_link_mode(link_lane0_2_ts1_linkn_rcvd, int_link_mode_linkn_rcvd_bus, int_link_mode_linkn_rcvd_reversed_bus) :
//                             (ltssm_state_is_cfglanenumacept) ? next_link_mode(int_lane0_2_ts1_linknmtx_lanen_rcvd, int_2_ts1_linknmtx_lanen_rcvd_bus, int_2_ts1_linknmtx_lanen_rcvd_reversed_bus) : 0;
assign link_next_link_mode = (ltssm_state_is_cfglinkwdstart & cfg_upstream_port) ? next_link_mode(int_2_ts1_link_mode_linkn_planen_rcvd_bus[0], int_2_ts1_link_mode_linkn_planen_rcvd_bus, int_2_ts1_link_mode_linkn_planen_reversed_bus, cfg_support_part_lanes_rxei_exit) :
                             ((ltssm_state_is_cfglinkwdacept & cfg_upstream_port) | ltssm_state_is_cfglanenumacept) ? next_link_mode(int_2_ts1_linknmtx_lanen_rcvd_bus[0], int_2_ts1_linknmtx_lanen_rcvd_bus, int_2_ts1_linknmtx_lanen_rcvd_reversed_bus, cfg_support_part_lanes_rxei_exit) :
                             (ltssm_state_is_cfglinkwdacept & ~cfg_upstream_port) ? next_link_mode(int_2_ts1_linknmtx_rcvd_bus[0], int_2_ts1_linknmtx_rcvd_bus, int_2_ts1_linknmtx_rcvd_reversed_bus, cfg_support_part_lanes_rxei_exit) : 0;
wire [NL-1:0] lanes_rcving = (ltssm_state_is_cfglinkwdstart & cfg_upstream_port)  ? int_2_ts1_link_mode_linkn_planen_rcvd_bus : ((ltssm_state_is_cfglinkwdacept & cfg_upstream_port) | ltssm_state_is_cfglanenumacept) ? int_2_ts1_linknmtx_lanen_rcvd_bus :
                             (ltssm_state_is_cfglinkwdacept & ~cfg_upstream_port) ? int_2_ts1_linknmtx_rcvd_bus : 0;
assign link_lanes_rcving   = lanes_rcving & link_mode_lanes_active;

//
//in Cfg.Linkwidth.Accept for DSP
//
assign current_2_ts1_linknmtx_rcvd_bus = int_2_ts_linknmtx_rcvd_bus & int_ts1_linkn_rcvd_bus;
assign current_2_ts1_linknmtx_lanenmtx_rcvd_bus = int_2_ts_linknmtx_rcvd_bus & int_2_ts_lanenmtx_rcvd_bus & int_ts1_linkn_rcvd_bus;
assign current_2_ts2_linknmtx_lanenmtx_rcvd_bus = int_2_ts_linknmtx_rcvd_bus & int_2_ts_lanenmtx_rcvd_bus & int_ts2_linkn_rcvd_bus;
assign current_lane0_2_ts1_lanen0_rcvd = current_2_ts1_linknmtx_rcvd_bus[0] & (~lane_num_pad_lane[0]) & (lane_num_s2_lane[0] == 0);
assign int_2_ts1_lanenmtx_rcvd_bus = int_2_ts_lanenmtx_rcvd_bus & int_ts1_lanen_rcvd_bus;
assign int_2_ts2_linknmtx_rcvd_bus = int_2_ts_linknmtx_rcvd_bus & int_ts2_linkn_rcvd_bus;
assign int_2_ts2_lanenmtx_rcvd_bus = int_2_ts_lanenmtx_rcvd_bus & int_ts2_lanen_rcvd_bus;
assign int_8_ts0_linknmtx_rcvd_bus = in_8_ts0_linknmtx_rcvd_bus & int_ts0_linkn_rcvd_bus;
assign int_8_ts0_lanenmtx_rcvd_bus = in_8_ts0_lanenmtx_rcvd_bus & int_ts0_lanen_rcvd_bus;
assign int_8_ts1_linknmtx_rcvd_bus = int_8_ts_linknmtx_rcvd_bus & int_ts1_linkn_rcvd_bus;
assign int_8_ts1_lanenmtx_rcvd_bus = int_8_ts_lanenmtx_rcvd_bus & int_ts1_lanen_rcvd_bus;
assign int_8_ts2_linknmtx_rcvd_bus = int_8_ts_linknmtx_rcvd_bus & int_ts2_linkn_rcvd_bus;
assign int_8_ts2_lanenmtx_rcvd_bus = int_8_ts_lanenmtx_rcvd_bus & int_ts2_lanen_rcvd_bus;
assign int_1_ts2_linknmtx_rcvd_bus = int_1_ts_linknmtx_rcvd_bus & int_ts2_linkn_rcvd_bus;
assign int_1_ts2_lanenmtx_rcvd_bus = int_1_ts_lanenmtx_rcvd_bus & int_ts2_lanen_rcvd_bus;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts1_linknmtx_lanen_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts1_linknmtx_lanen_rcvd_bus <= #TP 0;
        latched_2_ts1_linknmtx_rcvd_bus       <= #TP 0;
        latched_2_ts1_linknmtx_lanenmtx_rcvd_bus       <= #TP 0;
        latched_2_ts2_linknmtx_lanenmtx_rcvd_bus       <= #TP 0;
        latched_lane0_2_ts1_lanen0_rcvd       <= #TP 0;
        latched_2_ts1_plinkn_planen_rcvd_bus  <= #TP 0;
        latched_2_ts1_linknmtx_lanenum_rcvd_bus <= #TP 0; // lane number value per lane
    end else if ( ltssm_clear ) begin
        latched_2_ts1_linknmtx_lanen_rcvd_bus <= #TP 0;
        latched_2_ts1_linknmtx_rcvd_bus       <= #TP 0;
        latched_2_ts1_linknmtx_lanenmtx_rcvd_bus       <= #TP 0;
        latched_2_ts2_linknmtx_lanenmtx_rcvd_bus       <= #TP 0;
        latched_lane0_2_ts1_lanen0_rcvd       <= #TP 0;
        latched_2_ts1_plinkn_planen_rcvd_bus  <= #TP 0;
        latched_2_ts1_linknmtx_lanenum_rcvd_bus <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_2_ts1_linknmtx_lanen_rcvd_bus[n] ) begin
                latched_2_ts1_linknmtx_lanen_rcvd_bus[n] <= #TP 1;
                latched_2_ts1_linknmtx_lanenum_rcvd_bus[n*8 +: 8] <= #TP lane_num_s2_lane[n]; // ~PAD lane number & the lane number value
            end

            if ( current_2_ts1_linknmtx_rcvd_bus[n] )
                latched_2_ts1_linknmtx_rcvd_bus[n]       <= #TP 1;

            if ( current_2_ts1_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_2_ts1_linknmtx_lanenmtx_rcvd_bus[n]       <= #TP 1;

            if ( current_2_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_2_ts2_linknmtx_lanenmtx_rcvd_bus[n]       <= #TP 1;

            if ( current_lane0_2_ts1_lanen0_rcvd )
                latched_lane0_2_ts1_lanen0_rcvd          <= #TP 1;

            if ( current_2_ts1_plinkn_planen_rcvd_bus[n] )
                latched_2_ts1_plinkn_planen_rcvd_bus[n]  <= #TP 1;
        end

        // if lane reversal changes, clear the latched siganl to avoid pad/pad link#/lane# on some lanes after reversal
        // + the latched pad/pad link#/lane# to form pad/pad link#/lane# on all lanes to drive ltssm to Detect state
        // clear not in Cfg.Linkwidth.Start where upconfigure may use current_2_ts1_plinkn_planen_rcvd_bus from the remote partner
        if ( ltssm_lane_flip_ctrl_chg_pulse )
            latched_2_ts1_plinkn_planen_rcvd_bus  <= #TP 0;
    end
end // latched_2_ts1_linknmtx_lanen_rcvd_bus_PROC

assign int_2_ts1_linknmtx_rcvd_bus                = latched_2_ts1_linknmtx_rcvd_bus | current_2_ts1_linknmtx_rcvd_bus;
assign int_2_ts1_linknmtx_lanenmtx_rcvd_bus       = latched_2_ts1_linknmtx_lanenmtx_rcvd_bus | current_2_ts1_linknmtx_lanenmtx_rcvd_bus;
assign int_2_ts2_linknmtx_lanenmtx_rcvd_bus       = latched_2_ts2_linknmtx_lanenmtx_rcvd_bus | current_2_ts2_linknmtx_lanenmtx_rcvd_bus;

assign current_2_ts1_linknmtx_lanen_rcvd_bus      = int_2_ts_linknmtx_rcvd_bus & int_ts1_linkn_rcvd_bus & (~lane_num_pad_lane) & link_mode_lanes_active;
assign int_2_ts1_linknmtx_lanen_rcvd_bus          = current_2_ts1_linknmtx_lanen_rcvd_bus | latched_2_ts1_linknmtx_lanen_rcvd_bus;
assign int_2_ts1_linknmtx_lanen_rcvd_reversed_bus = bit_flip( int_2_ts1_linknmtx_lanen_rcvd_bus, smlh_link_mode ); // link number matching & non-PAD lane number within smlh_link_mode
assign int_2_ts1_linknmtx_lanenmtx_reversed_bus   = byte_flip( int_2_ts1_linknmtx_lanenum_rcvd_bus, smlh_link_mode ); // reversed lane number matching within smlh_link_mode & linknmtx

always @* begin : int_2_ts1_linknmtx_lanenum_rcvd_bus_PROC
    integer n;
    int_2_ts1_linknmtx_lanenum_rcvd_bus = {NL{8'hFF}}; // lane number cannot be 8'hFF per lane, max = 16

    for (n=0; n<NL; n=n+1) begin
        if ( current_2_ts1_linknmtx_lanen_rcvd_bus[n] ) // ~PAD lane number on current clock
            int_2_ts1_linknmtx_lanenum_rcvd_bus[n*8 +: 8] = lane_num_s2_lane[n]; // update to current clock lane number value
        else if ( int_2_ts1_linknmtx_lanen_rcvd_bus[n] ) // ~PAD lane number on latched
            int_2_ts1_linknmtx_lanenum_rcvd_bus[n*8 +: 8] = latched_2_ts1_linknmtx_lanenum_rcvd_bus[n*8 +: 8]; // update to legacy clock lane number value if existing
    end
end // int_2_ts1_linknmtx_lanenum_rcvd_bus_PROC

// all lanes receive 2 TS1 with non-PAD link# matching Tx
assign link_latched_live_all_2_ts1_linknmtx_rcvd = &(~link_mode_lanes_active | int_2_ts1_linknmtx_rcvd_bus);


//
//in Cfg.Linkwidth.Accept for USP
//
// all lanes receive 2 ts1 with non-apd link# matching Tx and non-pad lane#
assign link_latched_live_all_2_ts1_linknmtx_lanen_rcvd = &(~link_mode_lanes_active | int_2_ts1_linknmtx_lanen_rcvd_bus);
assign link_lane0_2_ts1_linknmtx_lanen_rcvd            = int_2_ts1_linknmtx_lanen_rcvd_bus[0]; //Lane 0 received 2 TS1s with non-PAD link# matching TX and non-PAD lane#

// all lanes receve 2 ts1 with pad-link# and pad-lane#
// ltssm_lane_flip_ctrl_chg_pulse asserts not in Cfg.Linkwidth.Start where upconfigure may use current_2_ts1_plinkn_planen_rcvd_bus from the remote partner
assign current_2_ts1_plinkn_planen_rcvd_bus           = current_2_ts1_rcvd_bus & link_num_pad_lane & lane_num_pad_lane & ~{NL{ltssm_lane_flip_ctrl_chg_pulse}};
assign int_2_ts1_plinkn_planen_rcvd_bus               = current_2_ts1_plinkn_planen_rcvd_bus | latched_2_ts1_plinkn_planen_rcvd_bus;
assign link_latched_live_all_2_ts1_plinkn_planen_rcvd = &(~smlh_lanes_active | int_2_ts1_plinkn_planen_rcvd_bus);
assign link_2_ts1_plinkn_planen_rcvd_upconf           = int_2_ts1_plinkn_planen_rcvd_bus;

//
//in Cfg.Lanenum.Wait for DSP
//
assign link_latched_live_lane0_2_ts1_lanen0_rcvd = current_lane0_2_ts1_lanen0_rcvd | latched_lane0_2_ts1_lanen0_rcvd;
//ltssm uses link_latched_live_all_2_ts1_linknmtx_lanen_rcvd and (~link_latched_live_lane0_2_ts1_lanen0_rcvd) to do auto_reverse within link_mode

//2 ts1s with link#/lane# matching Tx are received on all lanes
assign link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd = &(~link_mode_lanes_active | int_2_ts1_linknmtx_lanenmtx_rcvd_bus);
assign link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd = &(~link_mode_lanes_active | int_2_ts1_linknmtx_lanenmtx_reversed_bus);

// concatenate {pad-lane#, lane#}
always @( posedge core_clk or negedge core_rst_n ) begin : lane_num_lane_d_PROC
    integer n;

    if ( ~core_rst_n ) begin
        for (n=0; n<NL; n=n+1)
            lane_num_lane_d[n] <= #TP 0;
    end else begin
        for (n=0; n<NL; n=n+1)
            lane_num_lane_d[n] <= #TP lane_num_lane[n];
    end
end // lane_num_lane_d_PROC

always @( * ) begin : lane_num_lane_PROC
    integer n;

    lane_num_lane = lane_num_lane_d;

    for (n=0; n<NL; n=n+1) begin
        if ( smseq_ts1_rcvd_pulse_bus[n] )
            lane_num_lane[n] = {lane_num_pad_lane[n],lane_num_s2_lane[n]}; //{pad-lane#, lane#} per lane
    end
end // lane_num_lane_PROC

//latch lane num when ltssm first entered a state
always @( posedge core_clk or negedge core_rst_n ) begin : latched_lane_num_lane_PROC
    integer n;

    if ( ~core_rst_n ) begin
        for (n=0; n<NL; n=n+1) begin
            latched_lane_num_lane[n] <= #TP 0;
        end
    end else if ( ltssm_clear ) begin
        for (n=0; n<NL; n=n+1) begin
            latched_lane_num_lane[n] <= #TP lane_num_lane[n];
        end
    end
end // latched_lane_num_lane_PROC

always @( * ) begin : int_2_ts1_lanendiff_rcvd_bus_PROC
    integer n;

    for (n=0; n<NL; n=n+1) begin
        int_2_ts1_lanendiff_rcvd_bus[n] = current_2_ts1_rcvd_bus[n] & (lane_num_lane[n] != latched_lane_num_lane[n]);
    end
end // int_2_ts1_lanendiff_rcvd_bus_PROC

// any lane receives 2 ts1 with different lane# when the lane first entered the state
assign current_any_2_ts1_lanendiff_rcvd = |(link_mode_lanes_active & int_2_ts1_lanendiff_rcvd_bus);

always @( posedge core_clk or negedge core_rst_n ) begin : int_latched_any_2_ts1_lanendiff_linkn_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_2_ts1_lanendiff_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_2_ts1_lanendiff_rcvd <= #TP 0;
    end else begin
        if ( current_any_2_ts1_lanendiff_rcvd )
            latched_any_2_ts1_lanendiff_rcvd <= #TP 1;
    end
end // int_latched_any_2_ts1_lanendiff_linkn_rcvd_PROC

assign link_latched_live_any_2_ts1_lanendiff_linkn_rcvd = (latched_any_2_ts1_lanendiff_rcvd | current_any_2_ts1_lanendiff_rcvd) & (|int_link_mode_linkn_rcvd_bus);

//
//in Cfg.Lanenum.Wait for USP
//
//any lanes receive 2 ts2s
assign link_any_2_ts2_rcvd = |(link_mode_lanes_active & int_2_ts2_rcvd_bus);


//
//in Cfg.Lanenum.Accept for DSP
//
//ltssm uses link_latched_live_all_2_ts1_linknmtx_lanenmtx_rcvd or link_latched_live_all_2_ts1_linknmtx_lanenmtx_reversed_rcvd (DSP) signal for state transition to Cfg.Complete

//ltssm uses link_latched_live_all_2_ts1_linknmtx_lanen_rcvd for state transition to Cfg.Lanenum.Wait

//at timeout_1ms, link does next_link_mode and ltssm does auto lane reversal. this is for DSP as well as USP in Cfg.Lanenum.Accept
assign int_lane0_2_ts1_linknmtx_lanen_rcvd = int_2_ts1_linknmtx_lanen_rcvd_bus[0]; // for link width forming after reversed lanes within link_mode

//
//in Cfg.Lanenum.Accept for USP
//
// all lanes receive 2 ts2s with link#/lane# matching Tx
assign link_latched_live_all_2_ts2_linknmtx_lanenmtx_rcvd = &(~link_mode_lanes_active | int_2_ts2_linknmtx_lanenmtx_rcvd_bus);
assign link_latched_live_any_2_ts2_apn_rcvd               = |( link_mode_lanes_active & int_2_ts2_apn_rcvd_bus) & (ltssm_state_is_cfglanenumacept);

//ltssm uses link_latched_live_all_2_ts1_linknmtx_lanen_rcvd for state transition to Cfg.Lanenum.Wait


//
//in Cfg.Complete
//
always @( posedge core_clk or negedge core_rst_n ) begin : latched_1_ts2_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_1_ts2_rcvd_bus <= #TP 0;
        latched_1_ts1_rcvd_bus <= #TP 0;
        latched_8_ts2_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus <= #TP 0;

        latched_1_ts2_spd_chg_0_rcvd_bus <= #TP '0;
    end else if ( ltssm_clear ) begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( smseq_ts2_rcvd_pulse_bus[n] )
                latched_1_ts2_rcvd_bus[n] <= #TP 1;
            else
                latched_1_ts2_rcvd_bus[n] <= #TP 0;
        end
        for ( n=0; n<NL; n=n+1 ) begin
            if ( smseq_ts1_rcvd_pulse_bus[n] )
                latched_1_ts1_rcvd_bus[n] <= #TP 1;
            else
                latched_1_ts1_rcvd_bus[n] <= #TP 0;
        end

        latched_8_ts2_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus <= #TP 0;

        for ( n=0; n<NL; n=n+1 ) begin
            if ( smseq_ts2_rcvd_pulse_bus[n] && ~speed_chg_s4_lane[n] )
                latched_1_ts2_spd_chg_0_rcvd_bus[n] <= #TP 1'b1;
            else
                latched_1_ts2_spd_chg_0_rcvd_bus[n] <= #TP 1'b0;
        end
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( smseq_ts2_rcvd_pulse_bus[n] )
                latched_1_ts2_rcvd_bus[n] <= #TP 1;
            if ( smseq_ts1_rcvd_pulse_bus[n] )
                latched_1_ts1_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] <= #TP 1;

            if ( current_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus[n] <= #TP 1;

            if ( current_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus[n] <= #TP 1;

            if ( smseq_ts2_rcvd_pulse_bus[n] && ~speed_chg_s4_lane[n] )
                latched_1_ts2_spd_chg_0_rcvd_bus[n] <= #TP 1'b1;
        end
    end
end // latched_1_ts2_rcvd_bus_PROC

assign link_any_ts2_rcvd = |(link_mode_lanes_active & latched_1_ts2_rcvd_bus);
assign link_any_ts_rcvd  = |(link_mode_lanes_active & (latched_1_ts1_rcvd_bus | latched_1_ts2_rcvd_bus));

assign current_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus    = (int_8_ts_linknmtx_spd_chg_rcvd_bus & int_8_ts_lanenmtx_spd_chg_rcvd_bus);
assign current_8_ts_linknmtx_lanenmtx_rcvd_bus            = (int_8_ts_linknmtx_rcvd_bus & int_8_ts_lanenmtx_rcvd_bus);
assign current_8_ts0_linknmtx_lanenmtx_rcvd_bus           = (int_8_ts0_linknmtx_rcvd_bus & int_8_ts0_lanenmtx_rcvd_bus);
assign current_8_ts1_linknmtx_lanenmtx_rcvd_bus           = (int_8_ts1_linknmtx_rcvd_bus & int_8_ts1_lanenmtx_rcvd_bus);
assign current_8_ts2_linknmtx_lanenmtx_rcvd_bus           = (int_8_ts2_linknmtx_rcvd_bus & int_8_ts2_lanenmtx_rcvd_bus);
assign current_1_ts2_linknmtx_lanenmtx_rcvd_bus           = (int_1_ts2_linknmtx_rcvd_bus & int_1_ts2_lanenmtx_rcvd_bus);
assign current_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & ((smseq_mod_ts2_rcvd_pulse_bus & skip_eq_enbl_s5_lane) | (smseq_ts2_rcvd_pulse_bus & (ebth_eq_s5_lane | nend_eq_s5_lane))) & //including no eq needed
                                                              data_rate_g5_s4_lane & {NL{ltssm_ts_data_rate[4]}}; //including normal Rx TS2s
assign current_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & ((smseq_mod_ts2_rcvd_pulse_bus & no_eq_needed_s5_lane) | (smseq_ts2_rcvd_pulse_bus & nend_eq_s5_lane)) &
                                                              data_rate_g5_s4_lane & {NL{ltssm_ts_data_rate[4]}}; //including normal Rx TS2s
assign link_all_8_ts2_linknmtx_lanenmtx_rcvd              = &(~link_mode_lanes_active | int_8_ts2_linknmtx_lanenmtx_rcvd_bus);
assign int_8_ts2_linknmtx_lanenmtx_rcvd_bus               = current_8_ts2_linknmtx_lanenmtx_rcvd_bus | latched_8_ts2_linknmtx_lanenmtx_rcvd_bus;
assign int_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus   = current_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus | latched_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus;
assign int_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus   = current_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus | latched_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus;
assign link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd = &(~link_mode_lanes_active | int_8_ts2_linknmtx_lanenmtx_rcvd_bus);
assign link_latched_live_all_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd = &(~link_mode_lanes_active | int_8_mod_ts2_skip_eq_linknmtx_lanenmtx_rcvd_bus);
assign link_latched_live_all_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd = &(~link_mode_lanes_active | int_8_mod_ts2_noeq_nd_linknmtx_lanenmtx_rcvd_bus);

assign link_latched_live_all_8_ts2_linknmtx_lanenmtx_spd_chg_0_rcvd = int_all_spd_chg_0_rcvd;
assign link_latched_live_all_8_ts2_linknmtx_lanenmtx_g1_rate_rcvd   = int_all_g1_rate_rcvd;

assign current_2_ts2_dis_scramble_rcvd_bus = int_2_ts2_rcvd_bus & smseq_ts2_rcvd_pulse_bus & ~smseq_mod_ts2_rcvd_pulse_bus & dis_scramble_s5_lane;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts2_dis_scramble_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts2_dis_scramble_rcvd_bus <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_2_ts2_dis_scramble_rcvd_bus <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_2_ts2_dis_scramble_rcvd_bus[n] )
                latched_2_ts2_dis_scramble_rcvd_bus[n] <= #TP 1;
        end
    end
end // latched_2_ts2_dis_scramble_rcvd_bus_PROC

assign int_2_ts2_dis_scramble_rcvd_bus = current_2_ts2_dis_scramble_rcvd_bus | latched_2_ts2_dis_scramble_rcvd_bus;

assign link_latched_live_all_ts_scrmb_dis = ltssm_state_is_cfgcomplete & (&(~link_mode_lanes_active | int_2_ts2_dis_scramble_rcvd_bus));
//assign link_any_8_ts_auto_chg = |(link_mode_lanes_active & int_8_ts_rcvd_bus & auto_chg_s4_lane);
assign link_any_8_ts_auto_chg = |(link_mode_lanes_active & int_8_ts_rcvd_mtx_bus & smseq_ts2_rcvd_bus & auto_chg_s4_lane); // 8 continous TS2 with autonomous change bit -> used for condition of Link Autonomous Bandwidth Status

//ltssm uses link_xmlh_16_ts2_sent_after_1_ts2_rcvd + link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd for state transition to Cfg.Idle



//
//in Recovery.RcvrLock
//
// any lanes receive 8 ts1s with speed change set to 1
assign link_any_8_ts1_spd_chg_1_rcvd = |(smlh_lanes_active & int_8_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus & speed_chg_s4_lane); //used for ltssm to assign directed_speed_change variable
//assign link_any_8_ts1_spd_chg_1_rcvd = |(smlh_lanes_active & current_8_ts_linknmtx_lanenmtx_rcvd_bus & smseq_ts1_rcvd_bus & speed_chg_s4_lane); //used for ltssm to assign directed_speed_change variable

//detect sris bit for USP in Configuration state when ~smlh_link_up
always @( posedge core_clk or negedge core_rst_n ) begin : int_link_usp_sris_mode_PROC
    if ( ~core_rst_n )
        int_link_usp_sris_mode <= #TP 0;
    else if ( ltssm_state_is_detectquiet )
        int_link_usp_sris_mode <= #TP 1'b0;
    // no Cfg.Linkwidth.Start because of crosslink. no TS2s from gen6 spec
    else if ( ~smlh_link_up && cfg_upstream_port && |(link_mode_lanes_active & int_2_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus & speed_chg_s4_lane) && (ltssm_state_is_cfglinkwdacept || ltssm_state_is_cfglanenumwait || ltssm_state_is_cfglanenumacept) )
        int_link_usp_sris_mode <= #TP 1'b1;
end // int_link_usp_sris_mode_PROC

//use sticky_rst_n because the email (Useful Emails Saved -> RE SRIS Clocking Bit.msg) from PCI-SIG says:
//  For longest time, common clock vs SRIS/SRNS was known – the introduction of this bit came much later (probably starting with PCIe 5.0).
//  Software programs the modified compliance bit in L0 following which the link is reset. So the upstream lanes would know based on prior entry to L0. 
//  May be add a statement saying the upstream lanes should store it for use in Polling.Compliance. 
logic latched_link_usp_sris_mode_for_poll_comp;
always @( posedge core_clk or negedge sticky_rst_n ) begin : latched_link_usp_sris_mode_for_poll_comp_PROC
    if ( ~sticky_rst_n )
        latched_link_usp_sris_mode_for_poll_comp <= #TP 0;
    else if ( ltssm_state_is_cfglanenumacept )
        latched_link_usp_sris_mode_for_poll_comp <= #TP int_link_usp_sris_mode;
end // latched_link_usp_sris_mode_for_poll_comp_PROC

// PCIe6 spec draft 0.9: USP sets SRIS_Mode_Enabled bit in Cfg.LaneNum.Accept (previously was Cfg.LinkWidth.Accept)
logic link_usp_sris_enable_lpbk;

always @( posedge core_clk or negedge core_rst_n ) begin : link_usp_sris_mode_PROC
    if (~core_rst_n) begin
        link_usp_sris_mode <= #TP 1'b0;
    end else if ( ltssm_state_is_detectquiet ) begin
        link_usp_sris_mode <= #TP 1'b0;
    end else if (ltssm_state_is_cfglanenumacept) begin
        link_usp_sris_mode <= #TP int_link_usp_sris_mode;
    end else if (ltssm_state_is_lpbkentry) begin
        link_usp_sris_mode <= #TP link_usp_sris_enable_lpbk;
    end else if (smlh_ltssm_state == S_POLL_COMPLIANCE) begin
        link_usp_sris_mode <= #TP latched_link_usp_sris_mode_for_poll_comp;
    end 
end // link_usp_sris_mode_PROC

// PCIe spec errata:
// Loopback follower ...:
// For Upstream Lanes, the SRIS mode is determined from the TS1 Ordered Set (Symbol 4, Bit 7) received in Configuration State ...
// Following is not the PCIe spec statement but it is needed:
// When Upstream port is Loopback Lead, TS1 received in Loopback.entry state (Link partner sends TS1 in Configuration state) is used for decision.
always @( posedge core_clk or negedge core_rst_n ) begin : link_usp_sris_enable_lpbk_PROC
    if ( ~core_rst_n ) begin
        link_usp_sris_enable_lpbk <= #TP 0;
    end else if ( ltssm_state_is_detectquiet ) begin
        link_usp_sris_enable_lpbk <= #TP 1'b0;
    end else if ( ~smlh_link_up && cfg_upstream_port && |(link_mode_lanes_active & int_2_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus & speed_chg_s4_lane) && ltssm_state_is_cfglinkwdstart ) begin
        link_usp_sris_enable_lpbk <= #TP 1'b1;
    end
end // link_usp_sris_enable_lpbk_PROC

// all laned receive 8 ts with link#/lane# matching Tx
always @( posedge core_clk or negedge core_rst_n ) begin : latched_8_ts_linknmtx_lanenmtx_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus <= #TP 0;
        latched_8_ts_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_ts1_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_ts0_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_ts1_spd_chg_0_rcvd_rcvd_bus <= #TP 0;
        latched_8_ts1_ects_not_00b_rcvd_bus <= #TP 0;
        latched_8_ts_ects_00b_rcvd_bus <= #TP 0;
        latched_tx_spd_chg_same_as_8_ts_rx_ects_00_bus   <= #TP '0;
        latched_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus <= #TP '0;
        latched_tx_spd_chg_same_as_8_ts_rx_bus <= #TP 0;
        latched_tx_spd_chg_1_same_as_8_ts_rx_bus <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus <= #TP 0;
        latched_8_ts_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_ts0_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_ts1_linknmtx_lanenmtx_rcvd_bus <= #TP 0;
        latched_8_ts1_spd_chg_0_rcvd_rcvd_bus <= #TP 0;
        latched_8_ts1_ects_not_00b_rcvd_bus <= #TP 0;
        latched_8_ts_ects_00b_rcvd_bus <= #TP 0;
        latched_tx_spd_chg_same_as_8_ts_rx_ects_00_bus   <= #TP '0;
        latched_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus <= #TP '0;
        latched_tx_spd_chg_same_as_8_ts_rx_bus <= #TP 0;
        latched_tx_spd_chg_1_same_as_8_ts_rx_bus <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus[n] )
                latched_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts_linknmtx_lanenmtx_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts0_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts0_linknmtx_lanenmtx_rcvd_bus[n] <= #TP 1;
            if ( current_8_ts1_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts1_linknmtx_lanenmtx_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts1_spd_chg_0_rcvd_rcvd_bus[n] )
                latched_8_ts1_spd_chg_0_rcvd_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts1_ects_not_00b_rcvd_bus[n] )
                latched_8_ts1_ects_not_00b_rcvd_bus[n] <= #TP 1;

            if ( current_8_ts_ects_00b_rcvd_bus[n] )
                latched_8_ts_ects_00b_rcvd_bus[n] <= #TP 1;

            if ( current_tx_spd_chg_same_as_8_ts_rx_ects_00b_bus[n] )
                latched_tx_spd_chg_same_as_8_ts_rx_ects_00_bus[n] <= #TP 1'b1;

            if ( current_tx_spd_chg_1_same_as_8_ts_rx_ects_00b_bus[n] )
                latched_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus[n] <= #TP 1'b1;

            if ( current_tx_spd_chg_same_as_8_ts_rx_bus[n] )
                latched_tx_spd_chg_same_as_8_ts_rx_bus[n] <= #TP 1;

            if ( current_tx_spd_chg_1_same_as_8_ts_rx_bus[n] )
                latched_tx_spd_chg_1_same_as_8_ts_rx_bus[n] <= #TP 1;
        end
    end
end // latched_8_ts_linknmtx_lanenmtx_rcvd_bus_PROC

assign int_8_ts_linknmtx_lanenmtx_rcvd_bus = current_8_ts_linknmtx_lanenmtx_rcvd_bus | latched_8_ts_linknmtx_lanenmtx_rcvd_bus;

assign link_latched_live_all_8_ts_linknmtx_lanenmtx_rcvd  = &(~smlh_lanes_active | int_8_ts_linknmtx_lanenmtx_rcvd_bus);

// all lanes receive 8 ts1s with link#/lane# matching Tx
assign int_8_ts1_linknmtx_lanenmtx_rcvd_bus = current_8_ts1_linknmtx_lanenmtx_rcvd_bus | latched_8_ts1_linknmtx_lanenmtx_rcvd_bus;
assign int_8_ts0_linknmtx_lanenmtx_rcvd_bus = current_8_ts0_linknmtx_lanenmtx_rcvd_bus | latched_8_ts0_linknmtx_lanenmtx_rcvd_bus;
assign link_latched_live_all_8_ts1_linknmtx_lanenmtx_rcvd =                                                            ts0_detect_window ? &(~smlh_lanes_active | int_8_ts0_linknmtx_lanenmtx_rcvd_bus) :
                                                            &(~smlh_lanes_active | int_8_ts1_linknmtx_lanenmtx_rcvd_bus);

// all lanes receive TS1s with speed_change == 0
assign current_8_ts1_spd_chg_0_rcvd_rcvd_bus =                                                 ts0_detect_window ? int_8_ts0_linknmtx_lanenmtx_rcvd_bus : // no spd_chg defined in ts0
                                               current_8_ts1_linknmtx_lanenmtx_rcvd_bus & ~speed_chg_s4_lane;
assign int_8_ts1_spd_chg_0_rcvd_rcvd_bus = current_8_ts1_spd_chg_0_rcvd_rcvd_bus | latched_8_ts1_spd_chg_0_rcvd_rcvd_bus;
assign link_latched_live_all_ts1_spd_chg_0_rcvd = &(~smlh_lanes_active | int_8_ts1_spd_chg_0_rcvd_rcvd_bus);

always @( * ) begin : not_ects_00b_rcvd_bus_PROC
    integer n;

    for (n=0; n<NL; n=n+1) begin
        current_8_ts1_ects_not_00b_rcvd_bus[n] = ts0_detect_window ? current_8_ts0_linknmtx_lanenmtx_rcvd_bus[n] : (current_8_ts1_linknmtx_lanenmtx_rcvd_bus[n] & (ects_s6_lane[n] != 2'b00));
        current_8_ts_ects_00b_rcvd_bus[n]      = current_8_ts_linknmtx_lanenmtx_rcvd_bus[n] & (ects_s6_lane[n] == 2'b00);
    end
end //not_ects_00b_rcvd_bus_PROC

assign int_8_ts1_ects_not_00b_rcvd_bus = current_8_ts1_ects_not_00b_rcvd_bus | latched_8_ts1_ects_not_00b_rcvd_bus;
assign int_8_ts_ects_00b_rcvd_bus      = current_8_ts_ects_00b_rcvd_bus | latched_8_ts_ects_00b_rcvd_bus;

// all lanes receive ts1 with EC != 00b for USP to Rcvry.Eq
assign link_latched_live_all_ts1_not_ec_00b_rcvd = &(~smlh_lanes_active | int_8_ts1_ects_not_00b_rcvd_bus);

// all lanes receive ts1 with EC == 00b
assign link_latched_live_all_ts1_ec_00b_rcvd     = &(~smlh_lanes_active | int_8_ts_ects_00b_rcvd_bus);
assign current_tx_spd_chg_same_as_8_ts_rx_ects_00b_bus   = (current_tx_spd_chg_same_as_8_ts_rx_bus   & current_8_ts_ects_00b_rcvd_bus);
assign current_tx_spd_chg_1_same_as_8_ts_rx_ects_00b_bus = (current_tx_spd_chg_1_same_as_8_ts_rx_bus & current_8_ts_ects_00b_rcvd_bus);
assign int_tx_spd_chg_same_as_8_ts_rx_ects_00_bus   = current_tx_spd_chg_same_as_8_ts_rx_ects_00b_bus   | latched_tx_spd_chg_same_as_8_ts_rx_ects_00_bus;
assign int_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus = current_tx_spd_chg_1_same_as_8_ts_rx_ects_00b_bus | latched_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus;
 
// All lanes receive ts1 with EC==00b and speed change bit same as directed speed change
assign link_latched_live_all_ts1_ec_00b_spd_chg_same_as_dir_spd_chg_rcvd = xmtbyte_spd_chg_sent ? &(~smlh_lanes_active | int_tx_spd_chg_1_same_as_8_ts_rx_ects_00_bus) : &(~smlh_lanes_active | int_tx_spd_chg_same_as_8_ts_rx_ects_00_bus);

// all lanes receive TS with speed_change == directed_speed_change
always @( * ) begin : int_tx_spd_chg_same_as_rx_bus_PROC
    integer n;

    for ( n=0; n<NL; n=n+1 ) begin
        current_tx_spd_chg_same_as_8_ts_rx_bus[n]   = (speed_chg_s4_lane[n] == xmtbyte_spd_chg_sent) & current_8_ts_linknmtx_lanenmtx_rcvd_bus[n] & (xmtbyte_ts_pcnt>=8);
        current_tx_spd_chg_1_same_as_8_ts_rx_bus[n] = (speed_chg_s4_lane[n] == xmtbyte_spd_chg_sent) & current_8_ts_linknmtx_lanenmtx_spd_chg_rcvd_bus[n] & (xmtbyte_ts_pcnt>=8);
    end
end // int_tx_spd_chg_same_as_rx_bus_PROC

assign int_tx_spd_chg_same_as_8_ts_rx_bus   = current_tx_spd_chg_same_as_8_ts_rx_bus | latched_tx_spd_chg_same_as_8_ts_rx_bus;
assign int_tx_spd_chg_1_same_as_8_ts_rx_bus = current_tx_spd_chg_1_same_as_8_ts_rx_bus | latched_tx_spd_chg_1_same_as_8_ts_rx_bus;

assign link_latched_live_all_spd_chg_rcvd_same_as_dir_spd_chg = xmtbyte_spd_chg_sent ? &(~smlh_lanes_active | int_tx_spd_chg_1_same_as_8_ts_rx_bus) :
                                                                                       &(~smlh_lanes_active | int_tx_spd_chg_same_as_8_ts_rx_bus);

//after 24ms timeout

assign int_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_bus   = current_8_ts_linknmtx_lanenmtx_rcvd_bus & speed_chg_s4_lane;

// any lanes receive 8 ts with link#/lane# matching Tx and speed_change==1
assign current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd  = |(smlh_lanes_active & int_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_bus);

always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd <= #TP 0;
        latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd <= #TP 0;
        latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd <= #TP 0;
    end else begin
        if ( current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd )
            latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd <= #TP 1;

        if ( current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd )
            latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd <= #TP 1;
    end
end // latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_PROC

assign link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd = current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd | latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd;

// catch auto_change bit
assign link_any_8_ts_linknmtx_lanenmtx_rcvd           = ltssm_state_is_pollactive   ? |(smlh_lanes_active & current_8_ts_plinkn_planen_rcvd_bus) :
                                                        ltssm_state_is_rcvrylock    ? |(smlh_lanes_active & current_8_ts_linknmtx_lanenmtx_rcvd_bus & smseq_ts1_rcvd_bus) :
                                                        ltssm_state_is_rcvryrcvrcfg ? |(smlh_lanes_active & (int_8_std_ts2_spd_chg_1_rcvd_bus | int_8_eq_ts2_spd_chg_1_rcvd_bus
 | int_8_8gteq_ts2_spd_chg_1_rcvd_bus | int_8_16gteq_ts2_spd_chg_1_rcvd_bus | int_8_32gteq_ts2_spd_chg_1_rcvd_bus)) : 0;
assign link_any_8_ts_linknmtx_lanenmtx_auto_chg_rcvd  = ltssm_state_is_pollactive   ? |(smlh_lanes_active & current_8_ts_plinkn_planen_rcvd_bus & auto_chg_s4_lane) :
                                                        ltssm_state_is_rcvrylock    ? |(smlh_lanes_active & current_8_ts_linknmtx_lanenmtx_rcvd_bus & smseq_ts1_rcvd_bus & auto_chg_s4_lane) :
                                                        ltssm_state_is_rcvryrcvrcfg ? |(smlh_lanes_active & auto_chg_s4_lane & (int_8_std_ts2_spd_chg_1_rcvd_bus | int_8_eq_ts2_spd_chg_1_rcvd_bus
 | int_8_8gteq_ts2_spd_chg_1_rcvd_bus | int_8_16gteq_ts2_spd_chg_1_rcvd_bus | int_8_32gteq_ts2_spd_chg_1_rcvd_bus)) : 0;

assign link_ln0_8_ts2_linknmtx_lanenmtx_rcvd          = current_8_ts2_linknmtx_lanenmtx_rcvd_bus[0];
assign link_ln0_8_ts2_linknmtx_lanenmtx_auto_chg_rcvd = current_8_ts2_linknmtx_lanenmtx_rcvd_bus[0] & auto_chg_s4_lane[0]; // only for upconfigure

assign link_ln0_2_ts1_linknmtx_lanenmtx_auto_chg_rcvd = current_2_ts1_linknmtx_lanenmtx_rcvd_bus[0] & auto_chg_s4_lane[0];

always @( * ) begin : data_rate_gtr_g1_bus_PROC
    integer n;
    for (n=0; n<NL; n=n+1) begin
        data_rate_gtr_g1_bus[n] = (data_rate_s4_lane[n][1:0] > 2'b01); //for gen2, bit[3:2] are reserved, undefined in receive. if gen2/3/4 support, bit[1] must be set
        data_rate_is_g1_bus[n]  = (data_rate_s4_lane[n][1:0] == 2'b01); //for gen2, bit[3:2] are reserved, undefined in receive. if gen2/3/4 support, bit[1] must be set
    end
end // data_rate_gtr_g1_bus_PROC

// any lanes receive 8 ts with link#/lane# matching Tx and speed_change==1 + data_rate > Gen1 for Rcvry.Lock -> Rcvry.RcvrCfg
assign current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd  = |(smlh_lanes_active & int_8_ts_linknmtx_lanenmtx_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus);
assign link_latched_live_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd  = current_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd | latched_any_8_ts_linknmtx_lanenmtx_spd_chg_1_gtr_g1_rate_rcvd;

// latched any lanes HAVE RECEIVED at least one ts with link#/lane# matching Tx and speed_change==0 for Rcvry.Lock -> Cfg.Linkwidth.Start
assign current_active_1_ts_linknmtx_lanenmtx_rcvd_bus    = smlh_lanes_active & int_1_ts_linknmtx_rcvd_bus & int_1_ts_lanenmtx_rcvd_bus;
assign current_any_1_ts_linknmtx_lanenmtx_rcvd           = |current_active_1_ts_linknmtx_lanenmtx_rcvd_bus;
assign current_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd = |(current_active_1_ts_linknmtx_lanenmtx_rcvd_bus & (~speed_chg_s4_lane));
assign current_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd   = |current_active_1_ts_linknmtx_lanenmtx_rcvd_bus && ~link_latched_ts_data_rate[1];

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd <= #TP 0;
        latched_any_1_ts_linknmtx_lanenmtx_rcvd           <= #TP 0;
        latched_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd   <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd <= #TP 0;
        latched_any_1_ts_linknmtx_lanenmtx_rcvd           <= #TP 0;
        latched_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd   <= #TP 0;
    end else begin
        if ( current_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd ) begin
            latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd <= #TP 1;
        end
        if ( current_any_1_ts_linknmtx_lanenmtx_rcvd ) begin
            latched_any_1_ts_linknmtx_lanenmtx_rcvd           <= #TP 1;
        end
        if ( current_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd ) begin //link_latched_ts_data_rate[1]==1'b0 -> gen1 rate for word commonly in base spec for Rcvry.RcvrLock -> Configuration
            latched_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd   <= #TP 1;
        end
    end
end // link_latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd_PROC

assign link_latched_live_any_1_ts_linknmtx_lanenmtx_rcvd           = current_any_1_ts_linknmtx_lanenmtx_rcvd | latched_any_1_ts_linknmtx_lanenmtx_rcvd;
assign link_latched_live_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd = current_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd | latched_any_1_ts_linknmtx_lanenmtx_spd_chg_0_rcvd;
assign link_latched_live_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd   = current_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd | latched_any_1_ts_linknmtx_lanenmtx_g1_rate_rcvd; //unused



//
//in Recovery.RcvrCfg
//
// Recovery.RcvrCfg -> Recovery.Speed
// |
// > below is "either the current data rate is greater than gen1"
// any lanes receive 8 standard ts2s with speed_change==1 at gen1/2 rate
assign int_8_std_ts2_spd_chg_1_rcvd_bus    = int_8_ts2_spd_chg_1_rcvd_bus & (~eqts_s6_lane);
assign int_8_std_g3_ts2_spd_chg_1_rcvd_bus = int_8_ts2_spd_chg_1_rcvd_bus & (~eq8gtts_s7_lane);

//latch any_8_std_ts2_spd_chg_1_rcvd
assign current_any_8_std_ts2_spd_chg_1_rcvd =  (|(smlh_lanes_active & int_8_std_ts2_spd_chg_1_rcvd_bus) && (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE))
                                               || (|(smlh_lanes_active & int_8_std_g3_ts2_spd_chg_1_rcvd_bus) && (current_data_rate==`GEN3_RATE))
                                               || (|(smlh_lanes_active & int_8_ts2_spd_chg_1_rcvd_bus) && (current_data_rate==`GEN4_RATE || current_data_rate==`GEN5_RATE || current_data_rate==`GEN6_RATE))
                                               ;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_8_std_ts2_spd_chg_1_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_8_std_ts2_spd_chg_1_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_8_std_ts2_spd_chg_1_rcvd <= #TP 0;
    end else if ( current_any_8_std_ts2_spd_chg_1_rcvd ) begin
        latched_any_8_std_ts2_spd_chg_1_rcvd <= #TP 1;
    end
end //latched_any_8_std_ts2_spd_chg_1_rcvd_PROC

assign link_latched_live_any_8_std_ts2_spd_chg_1_rcvd = current_any_8_std_ts2_spd_chg_1_rcvd | latched_any_8_std_ts2_spd_chg_1_rcvd;

// all lanes receive 8 eq ts2s
//assign int_8_eq_ts2_rcvd_bus  = int_8_ts_rcvd_bus & eqts_s6_lane & smseq_ts2_rcvd_bus;
assign int_8_eq_ts2_rcvd_bus  = int_8_ts_rcvd_mtx_bus & eqts_s6_lane & smseq_ts2_rcvd_bus;
assign int_8_eq_ts2_spd_chg_1_rcvd_bus  = int_8_eq_ts2_rcvd_bus & speed_chg_s4_lane;
assign int_all_8_eq_ts2_rcvd = &(~smlh_lanes_active | int_8_eq_ts2_rcvd_bus);

// all lanes receive 8 8gt eqts2
//assign int_8_8gteq_ts2_rcvd_bus  = int_8_ts_rcvd_bus & eq8gtts_s7_lane & smseq_ts2_rcvd_bus;
assign int_8_8gteq_ts2_rcvd_bus  = int_8_ts_rcvd_mtx_bus & eq8gtts_s7_lane & smseq_ts2_rcvd_bus & {NL{(current_data_rate==`GEN3_RATE)}} ;
assign int_8_8gteq_ts2_spd_chg_1_rcvd_bus  = int_8_8gteq_ts2_rcvd_bus & speed_chg_s4_lane;
assign int_all_8_8gteq_ts2_rcvd = &(~smlh_lanes_active | int_8_8gteq_ts2_rcvd_bus);
// all lanes receive 8 8gt eqts2
//assign int_8_8gteq_ts2_rcvd_bus  = int_8_ts_rcvd_bus & eq8gtts_s7_lane & smseq_ts2_rcvd_bus;
assign int_8_16gteq_ts2_rcvd_bus  = int_8_ts_rcvd_mtx_bus & eq8gtts_s7_lane & smseq_ts2_rcvd_bus & {NL{(current_data_rate>=`GEN4_RATE)}} & {NL{(current_data_rate<=`GEN5_RATE)}};
assign int_8_16gteq_ts2_spd_chg_1_rcvd_bus  = int_8_16gteq_ts2_rcvd_bus & speed_chg_s4_lane;
assign int_all_8_16gteq_ts2_rcvd = &(~smlh_lanes_active | int_8_16gteq_ts2_rcvd_bus);
// all lanes receive 8 8gt eqts2
//assign int_8_8gteq_ts2_rcvd_bus  = int_8_ts_rcvd_bus & eq8gtts_s7_lane & smseq_ts2_rcvd_bus;
assign int_8_32gteq_ts2_rcvd_bus  = int_8_ts_rcvd_mtx_bus & eq8gtts_s7_lane & smseq_ts2_rcvd_bus & {NL{(current_data_rate>=`GEN5_RATE)}};
assign int_8_32gteq_ts2_spd_chg_1_rcvd_bus  = int_8_32gteq_ts2_rcvd_bus & speed_chg_s4_lane;
assign int_all_8_32gteq_ts2_rcvd = &(~smlh_lanes_active | int_8_32gteq_ts2_rcvd_bus);


assign current_8_g123_eq_ts2_spd_chg_1_rcvd_bus             = int_8_eq_ts2_spd_chg_1_rcvd_bus | int_8_8gteq_ts2_spd_chg_1_rcvd_bus
 | int_8_16gteq_ts2_spd_chg_1_rcvd_bus | int_8_32gteq_ts2_spd_chg_1_rcvd_bus;
assign current_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus = current_8_g123_eq_ts2_spd_chg_1_rcvd_bus & ~data_rate_is_g1_bus;
always @( posedge core_clk or negedge core_rst_n ) begin : latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus <= #TP 0;
        latched_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus <= #TP 0;
        latched_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_8_g123_eq_ts2_spd_chg_1_rcvd_bus[n] )
                latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus[n]          <= #TP 1;

            if ( current_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus[n] )
                latched_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus[n] <= #TP 1;
        end
    end
end // latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus_PROC

assign int_8_g123_eq_ts2_spd_chg_1_rcvd_bus             = current_8_g123_eq_ts2_spd_chg_1_rcvd_bus | latched_8_g123_eq_ts2_spd_chg_1_rcvd_bus;
assign int_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus = current_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus | latched_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus;

assign link_latched_live_all_8_eq_ts2_spd_chg_1_rcvd             = &(~smlh_lanes_active | int_8_g123_eq_ts2_spd_chg_1_rcvd_bus);
assign link_latched_live_all_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd = &(~smlh_lanes_active | int_8_g123_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_bus);

// all lanes receive 8 ts2s with speed_change==1
//assign int_8_ts2_spd_chg_1_rcvd_bus = int_8_ts_rcvd_bus & smseq_ts2_rcvd_bus & speed_chg_s4_lane;
assign int_8_ts2_spd_chg_1_rcvd_bus = int_8_ts_rcvd_mtx_bus & smseq_ts2_rcvd_bus & speed_chg_s4_lane;

//latch all_8_eq_ts2_spd_chg_1_rcvd
assign int_all_8_ts2_spd_chg_1_rcvd = &(~smlh_lanes_active | int_8_ts2_spd_chg_1_rcvd_bus);

// any lanes receive 8 eq ts2s with speed_change==1
assign link_any_8_eq_ts2_spd_chg_1_rcvd = |(smlh_lanes_active & int_8_eq_ts2_spd_chg_1_rcvd_bus);

// any lanes receive 8 8gt eq ts2 with speed_change==1
assign link_any_8_8gteq_ts2_spd_chg_1_rcvd = |(smlh_lanes_active & int_8_8gteq_ts2_spd_chg_1_rcvd_bus);
// any lanes receive 8 8gt eq ts2 with speed_change==1
assign link_any_8_16gteq_ts2_spd_chg_1_rcvd = |(smlh_lanes_active & int_8_16gteq_ts2_spd_chg_1_rcvd_bus);
// any lanes receive 8 8gt eq ts2 with speed_change==1
assign link_any_8_32gteq_ts2_spd_chg_1_rcvd = |(smlh_lanes_active & int_8_32gteq_ts2_spd_chg_1_rcvd_bus);
// <
// |
// above is "either the current data rate is greater than gen1"

// |
// > below is "greater than gen1 rate is set in the received ts2"
// any lanes receive 8 standard ts2s with speed_change==1 and data_rate > Gen1
assign current_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd = (|(smlh_lanes_active & int_8_std_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus) & (current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE))
                                                          || (|(smlh_lanes_active & int_8_std_g3_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus) && (current_data_rate==`GEN3_RATE))
                                                          || (|(smlh_lanes_active & int_8_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus) && (current_data_rate==`GEN4_RATE
 || current_data_rate==`GEN5_RATE || current_data_rate==`GEN6_RATE))
                                                           ;

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd <= #TP 0;
    end else if ( current_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd ) begin
        latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd <= #TP 1;
    end
end //link_latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd_PROC

assign link_latched_live_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd = current_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd | latched_any_8_std_ts2_spd_chg_1_gtr_g1_rate_rcvd;

// any lanes receive 8 eq ts2 with speed_change==1 and data_rate > gen1
assign int_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd = |(smlh_lanes_active & int_8_eq_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus);

// any lanes receive 8 8gt eq ts2s with speed_change==1 and data_rate > gen1
assign int_any_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd = |(smlh_lanes_active & int_8_8gteq_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus);

// any lanes receive 8 8gt eq ts2s with speed_change==1 and data_rate > gen1
assign int_any_8_16gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd = |(smlh_lanes_active & int_8_16gteq_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus);

// any lanes receive 8 8gt eq ts2s with speed_change==1 and data_rate > gen1
assign int_any_8_32gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd = |(smlh_lanes_active & int_8_32gteq_ts2_spd_chg_1_rcvd_bus & data_rate_gtr_g1_bus);

assign current_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd = int_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd || int_any_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd
 || int_any_8_16gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd || int_any_8_32gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd <= #TP 0;
    end else if ( current_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd ) begin
        latched_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd <= #TP 1;
    end
end // link_latched_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd_PROC

assign link_latched_live_any_8_eq_ts2_spd_chg_1_gtr_g1_rate_rcvd = latched_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd | current_any_g123_8_8gteq_ts2_spd_chg_1_gtr_g1_rate_rcvd;
// <
// |
// above is "greater than gen1 rate is set in the received ts2"

//conditional TS2 sent count for Rcvry.RcvrCfg -> Rcvry.Speed
always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_ts2_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_ts2_spd_chg_rcvd_sent <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_ts2_spd_chg_rcvd_sent <= #TP 0;
    end else if ( |(smlh_lanes_active & smseq_ts2_rcvd_pulse_bus & speed_chg_s4_lane) & xmtbyte_spd_chg_sent ) begin
        latched_any_ts2_spd_chg_rcvd_sent <= #TP 1;
    end
end // latched_any_ts2_rcvd_PROC

// 32 (gen2) or 128 (gen3/4) ts2 sent with speed_change set to 1 for Rcvry.RcvrCfg -> Rcvry.Speed
assign link_xmlh_32_ts2_spd_chg_1_sent  = (condition_ts_sent_cnt >= 32);
assign link_xmlh_128_ts2_spd_chg_1_sent = (condition_ts_sent_cnt >= 128);

// now for Rcvry.RcvrCfg -> Rcvry.Idle
// |
// ltssm uses link_latched_live_all_8_ts2_linknmtx_lanenmtx_rcvd for the state transition

// all lanes speed_change==0
assign current_8_ts2_spd_chg_0_rcvd_bus = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & ~speed_chg_s4_lane;
assign current_8_ts2_g1_rate_rcvd_bus   = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & data_rate_is_g1_bus;

always @( posedge core_clk or negedge core_rst_n ) begin : latched_8_ts2_spd_chg_0_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_8_ts2_spd_chg_0_rcvd_bus <= #TP 0;
        latched_8_ts2_g1_rate_rcvd_bus   <= #TP 0;
        latched_8_ts2_dis_link_rcvd_bus  <= #TP 0;
        latched_8_ts2_hot_reset_rcvd_bus <= #TP 0;
        latched_8_ts2_loopback_rcvd_bus  <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_8_ts2_spd_chg_0_rcvd_bus <= #TP 0;
        latched_8_ts2_g1_rate_rcvd_bus   <= #TP 0;
        latched_8_ts2_dis_link_rcvd_bus  <= #TP 0;
        latched_8_ts2_hot_reset_rcvd_bus <= #TP 0;
        latched_8_ts2_loopback_rcvd_bus  <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts2_spd_chg_0_rcvd_bus[n] <= #TP ~speed_chg_s4_lane[n];

            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts2_g1_rate_rcvd_bus[n]   <= #TP data_rate_is_g1_bus[n];

            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts2_dis_link_rcvd_bus[n]  <= #TP dis_link_s5_lane[n];

            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts2_hot_reset_rcvd_bus[n] <= #TP hot_reset_s5_lane[n];

            if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] )
                latched_8_ts2_loopback_rcvd_bus[n]  <= #TP loopback_s5_lane[n];
        end
    end
end // latched_8_ts2_spd_chg_0_rcvd_bus_PROC

assign int_8_ts2_spd_chg_0_rcvd_bus = current_8_ts2_spd_chg_0_rcvd_bus | latched_8_ts2_spd_chg_0_rcvd_bus;
assign int_8_ts2_g1_rate_rcvd_bus   = current_8_ts2_g1_rate_rcvd_bus | latched_8_ts2_g1_rate_rcvd_bus;

assign int_all_spd_chg_0_rcvd = &(~smlh_lanes_active | int_8_ts2_spd_chg_0_rcvd_bus);

// all lanes receive gen1 rate
assign int_all_g1_rate_rcvd = &(~smlh_lanes_active | int_8_ts2_g1_rate_rcvd_bus);

// Any lane receives Disable Link Bit: dis_link_s5_lane
assign current_8_ts2_dis_link_rcvd_bus                             = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & dis_link_s5_lane;
assign int_8_ts2_dis_link_rcvd_bus                                 = current_8_ts2_dis_link_rcvd_bus | latched_8_ts2_dis_link_rcvd_bus;
assign int_any_dis_link_rcvd                                       = |(link_mode_lanes_active & int_8_ts2_dis_link_rcvd_bus);
assign link_latched_live_any_8_ts2_linknmtx_lanenmtx_dis_link_rcvd = int_any_dis_link_rcvd | latched_any_dis_link_rcvd; // module output

// Any lane receives Hot Reset Bit: hot_reset_s5_lane
assign current_8_ts2_hot_reset_rcvd_bus                             = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & hot_reset_s5_lane;
assign int_8_ts2_hot_reset_rcvd_bus                                 = current_8_ts2_hot_reset_rcvd_bus | latched_8_ts2_hot_reset_rcvd_bus;
assign int_any_hot_reset_rcvd                                       = |(link_mode_lanes_active & int_8_ts2_hot_reset_rcvd_bus);
assign link_latched_live_any_8_ts2_linknmtx_lanenmtx_hot_reset_rcvd = int_any_hot_reset_rcvd | latched_any_hot_reset_rcvd; // module output

// Any lane receives Loopback Bit: loopback_s5_lane
assign current_8_ts2_loopback_rcvd_bus                             = current_8_ts2_linknmtx_lanenmtx_rcvd_bus & loopback_s5_lane;
assign int_8_ts2_loopback_rcvd_bus                                 = current_8_ts2_loopback_rcvd_bus | latched_8_ts2_loopback_rcvd_bus;
assign int_any_loopback_rcvd                                       = |(link_mode_lanes_active & int_8_ts2_loopback_rcvd_bus);
assign link_latched_live_any_8_ts2_linknmtx_lanenmtx_loopback_rcvd = int_any_loopback_rcvd | latched_any_loopback_rcvd; // module output

always_ff @(posedge core_clk or negedge core_rst_n) begin: latched_any_disablelink_hotreset_lpbk_rcvd_PROC
    if (~core_rst_n) begin
        latched_any_dis_link_rcvd  <= #TP 0;
        latched_any_hot_reset_rcvd <= #TP 0;
        latched_any_loopback_rcvd  <= #TP 0;
    end else if ( (ltssm_state_is_rcvryidle && !ltssm_clear) || ~(ltssm_state_is_rcvryrcvrcfg || ltssm_state_is_rcvryidle) ) begin
        // Reset latched signals when ltssm_clear deasserts after entry to Recovery.Idle
        // Or when LTSSM is neither Recovery.RcvrCfg nor Recovery.Idle, in case LTSSM does not transition RcvrCfg -> Recovery.Idle
        latched_any_dis_link_rcvd  <= #TP 0;
        latched_any_hot_reset_rcvd <= #TP 0;
        latched_any_loopback_rcvd  <= #TP 0;
    end else if (ltssm_state_is_rcvryrcvrcfg) begin
        latched_any_dis_link_rcvd  <= #TP int_any_dis_link_rcvd;
        latched_any_hot_reset_rcvd <= #TP int_any_hot_reset_rcvd;
        latched_any_loopback_rcvd  <= #TP int_any_loopback_rcvd;
    end
end // latched_any_disablelink_hotreset_lpbk_rcvd_PROC

// 16 ts2 sent after receiving 1 ts2, with intervening eieos, for Rcvry.RcvrCfg -> Rcvry.Idle
// ltssm uses link_xmlh_16_ts2_sent_after_1_ts2_rcvd_noeies for state transition from Rcvry.RcvrCfg -> Rcvry.Idle

// now for Rcvry.RcvrCfg -> Configuration.Linkwidth.Start
// |
// 16 ts2 sent after receiving 1 ts1 on any lane for Rcvry.RcvrCfg -> Configuration.Linkwidth.Start
//conditional TS2 sent count after receiving one ts1
always @( posedge core_clk or negedge core_rst_n ) begin : latched_any_ts1_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_ts1_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_ts1_rcvd <= #TP 0;
    end else if ( |(smlh_lanes_active & smseq_ts1_rcvd_pulse_bus) ) begin
        latched_any_ts1_rcvd <= #TP 1;
    end
end // latched_all_ts2_rcvd_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : condition3_ts_sent_cnt_PROC
    if ( ~core_rst_n ) begin
        condition3_ts_sent_cnt <= #TP 0;
    end else if ( ltssm_clear ) begin
        condition3_ts_sent_cnt <= #TP 0;
    end else if ( &condition3_ts_sent_cnt == 1'b1 ) begin //saturation
        condition3_ts_sent_cnt <= #TP condition3_ts_sent_cnt;
    end else if ( ltssm_state_is_rcvryrcvrcfg && latched_any_ts1_rcvd ) begin
        if ( xmtbyte_ts2_sent[0] )
            condition3_ts_sent_cnt <= #TP condition3_ts_sent_cnt + 1;
    end
end // condition3_ts_sent_cnt_PROC

assign link_xmlh_16_ts2_sent_after_1_ts1_rcvd = (condition3_ts_sent_cnt >= 16);

wire                        ltssm_state_is_l0;
reg     [4:0]               condition_l0p_ts1_sent_cnt;
reg     [4:0]               condition_l0p_ts2_sent_cnt;
reg                         int_any_exact_2_ts_l0p_rcvd;
reg                         int_any_exact_2_ts_l0p_rcvd_d;

assign ltssm_state_is_l0 = (smlh_ltssm_state == S_L0);

// ts1/ts2 received in l0p state
assign link_latched_live_all_8_ts1_linknmtx_lanenmtx_l0p_rcvd = &(~link_mode_lanes_active | smlh_l0p_last_lanes_active | int_8_ts1_linknmtx_lanenmtx_rcvd_bus | ~smlh_l0p_lanes_active);
assign link_latched_live_all_8_ts2_linknmtx_lanenmtx_l0p_rcvd = &(~link_mode_lanes_active | smlh_l0p_last_lanes_active | int_8_ts2_linknmtx_lanenmtx_rcvd_bus | ~smlh_l0p_lanes_active);

// ts1 sent count after receiving 1 ts1
always @( posedge core_clk or negedge core_rst_n ) begin : condition_l0p_ts1_sent_cnt_PROC
    if ( ~core_rst_n ) begin
        condition_l0p_ts1_sent_cnt <= #TP 0;
    end else if ( ltssm_clear ) begin
        condition_l0p_ts1_sent_cnt <= #TP 0;
    end else if ( &condition_l0p_ts1_sent_cnt == 1'b1 ) begin //saturation
        condition_l0p_ts1_sent_cnt <= #TP condition_l0p_ts1_sent_cnt;
    end else if ( latched_any_1_ts_rcvd && (ltssm_state_is_l0 || ltssm_state_is_rcvrylock)) begin
        if ( xmtbyte_l0p_ts1_sent[0])
            condition_l0p_ts1_sent_cnt <= #TP condition_l0p_ts1_sent_cnt + 1;
    end
end // condition_l0p_ts1_sent_cnt_PROC

assign link_xmlh_l0p_16_ts1_sent = (condition_l0p_ts1_sent_cnt >= 16);

// ts2 sent count after receiving 1 ts2
always @( posedge core_clk or negedge core_rst_n ) begin : condition_l0p_ts2_sent_cnt_PROC
    if ( ~core_rst_n ) begin
        condition_l0p_ts2_sent_cnt <= #TP 0;
    end else if ( ltssm_clear ) begin
        condition_l0p_ts2_sent_cnt <= #TP 0;
    end else if ( &condition_l0p_ts2_sent_cnt == 1'b1 ) begin //saturation
        condition_l0p_ts2_sent_cnt <= #TP condition_l0p_ts2_sent_cnt;
    end else if ( latched_any_1_ts2_rcvd && (ltssm_state_is_l0 || ltssm_state_is_rcvrylock) ) begin
        if ( xmtbyte_l0p_ts2_sent[0])
            condition_l0p_ts2_sent_cnt <= #TP condition_l0p_ts2_sent_cnt + 1;
    end
end // condition_l0p_ts2_sent_cnt_PROC

assign link_xmlh_l0p_16_ts2_sent_after_1_ts2_rcvd = (condition_l0p_ts2_sent_cnt >= 16);

assign int_8_ts1_linknnomtx_or_lanennomtx_rcvd_bus = ~current_8_ts1_linknmtx_lanenmtx_rcvd_bus & int_8_ts_rcvd_mtx_bus & smseq_ts1_rcvd_bus & {NL{(xmtbyte_ts_pcnt>=8)}};
// any lanes received 8 TS1s with link# or lane# not matching Tx and speed_change==0
// any lanes received 8 TS1s with link# or lane# not matching Tx and data_rate==gen1
assign current_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           = |(smlh_lanes_active & int_8_ts1_linknnomtx_or_lanennomtx_rcvd_bus);
assign current_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd = |(smlh_lanes_active & int_8_ts1_linknnomtx_or_lanennomtx_rcvd_bus & ~speed_chg_s4_lane);
assign current_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   = |(smlh_lanes_active & int_8_ts1_linknnomtx_or_lanennomtx_rcvd_bus & data_rate_is_g1_bus);
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           <= #TP 0;
        latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd <= #TP 0;
        latched_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           <= #TP 0;
        latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd <= #TP 0;
        latched_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   <= #TP 0;
    end else begin
        if ( current_any_8_ts1_linknnomtx_or_lanennomtx_rcvd )
            latched_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           <= #TP 1;

        if ( current_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd )
            latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd <= #TP 1;

        if ( current_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd )
            latched_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   <= #TP 1;
    end
end // link_latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd_PROC

// any lanes receive 8 TS1s with link# or lane# not matching Tx
assign link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_rcvd           = current_any_8_ts1_linknnomtx_or_lanennomtx_rcvd | latched_any_8_ts1_linknnomtx_or_lanennomtx_rcvd;
assign link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd = current_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd | latched_any_8_ts1_linknnomtx_or_lanennomtx_spd_chg_0_rcvd;
assign link_latched_live_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd   = current_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd | latched_any_8_ts1_linknnomtx_or_lanennomtx_g1_rate_rcvd;

//latched any ts2 rcvd
assign current_any_ts2_rcvd = |(smlh_lanes_active & smseq_ts2_rcvd_pulse_bus);
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_any_ts2_rcvd_PROC
    if ( ~core_rst_n ) begin
        latched_any_ts2_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        latched_any_ts2_rcvd <= #TP 0;
    end else if ( current_any_ts2_rcvd ) begin
        latched_any_ts2_rcvd <= #TP 1;
    end
end // link_latched_any_ts2_rcvd_PROC

assign link_latched_live_any_ts2_rcvd = current_any_ts2_rcvd | latched_any_ts2_rcvd;


//
//Recovery.Idle
//
// any lanes receive 2 ts1s with Hot Reset bit set to 1
// any lanes receive 8 ts1s with Hot Reset bit set to 1 for cfg_rx_8_ts1s && (ltssm_state_is_rcvryidle || ltssm_state_is_rcvryrcvrcfg)
assign link_any_2_ts1_hotreset1_rcvd = (cfg_rx_8_ts1s && (ltssm_state_is_rcvryidle || ltssm_state_is_rcvryrcvrcfg)) ? |(smlh_lanes_active & current_8_ts1_rcvd_bus & hot_reset_s5_lane) : |(smlh_lanes_active & current_2_ts1_rcvd_bus & hot_reset_s5_lane);

// any lanes receive 2 ts1s with pad-lane#
// any lanes receive 8 ts1s with pad-lane# for cfg_rx_8_ts1s && ltssm_state_is_rcvryidle
assign link_any_2_ts1_planen_rcvd = (cfg_rx_8_ts1s && ltssm_state_is_rcvryidle) ? |(smlh_lanes_active & current_8_ts1_rcvd_bus & lane_num_pad_lane) : |(smlh_lanes_active & current_2_ts1_rcvd_bus & lane_num_pad_lane);

// any lanes receive 2 ts1s with loopback==1
// link_any_2_ts1_lpbk1_rcvd used in Loopback.Entry after Loopback EQ to detect 2 TS1s with lpbk=1 on the lane under test (lpbk_eq_lanes_active) for master and slave
// any lanes receive 8 ts1s with Loopback bit set to 1 for cfg_rx_8_ts1s && (ltssm_state_is_rcvryidle || ltssm_state_is_rcvryrcvrcfg)
assign link_any_2_ts1_lpbk1_rcvd = (cfg_rx_8_ts1s && (ltssm_state_is_rcvryidle || ltssm_state_is_rcvryrcvrcfg)) ? |(smlh_lanes_active & current_8_ts1_rcvd_bus & loopback_s5_lane) :
 (|lpbk_eq_lanes_active && ltssm_state_is_lpbkentry) ? |(lpbk_eq_lanes_active & current_2_ts1_rcvd_bus & loopback_s5_lane) : |(smlh_lanes_active & current_2_ts1_rcvd_bus & loopback_s5_lane);

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd_PROC
    if ( ~core_rst_n ) begin
        link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd <= #TP 0;
    end else if ( ~(ltssm_state_is_lpbkentry || ltssm_state_is_rcvryidle) ) begin
        link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd <= #TP 0;
    end else if ( |(smlh_lanes_active & current_2_ts1_rcvd_bus & loopback_s5_lane & compl_rcv_ts1_s5_lane) && ltssm_state_is_rcvryidle && ~ltssm_clear ) begin
        link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd <= #TP 1;
    end
end // link_latched_any_2_ts1_lpbk1_compl_rcv_1_rcvd_PROC

//
//Loopback.Entry for master
//
//an implementation-specific set of Lanes receive two consecutive TS1 Ordered Sets with the Loopback bit asserted
always @* begin : imp_lanes_COM
    integer n;

    link_imp_lanes = 0;
    for ( n=0; n<NL; n=n+1 ) begin
        if ( n <= cfg_imp_num_lanes )
            link_imp_lanes[n] = 1'b1;
    end
end // imp_lanes_COM

//assign link_imp_2_ts1_lpbk1_rcvd = &(~(smlh_lanes_active & link_imp_lanes) | int_2_ts1_lpbk1_rcvd_bus);
assign link_imp_2_ts1_lpbk1_rcvd = &(~(smlh_lanes_active & link_imp_lanes) | int_2_ts1_lpbk1_rcvd_bus_post_spd); // rcvd TS1s with lpbk=1 only in Loopback.Entry and in sending TS1s command

//
//L0
//
// any lanes receive 2 TSs (not consecutive) and then move from L0 to Recovery
assign link_any_2_ts_rcvd       = |(smlh_lanes_active & int_2_ts_cond_rcvd_bus);
//assign link_1_ts_rcvd           = ltssm_state_is_detectquiet ? |(smlh_lanes_active & int_1_ts_rcvd_bus) : ltssm_state_is_cfgcomplete ? &(~link_mode_lanes_active | (int_1_ts_rcvd_bus & smseq_ts2_rcvd_bus)) : 0;
assign link_1_ts_rcvd           = ltssm_state_is_detectquiet ? |(smlh_lanes_active & int_1_ts_rcvd_mtx_bus) : ltssm_state_is_cfgcomplete ? &(~link_mode_lanes_active | (int_1_ts_rcvd_mtx_bus & smseq_ts2_rcvd_bus)) : 0;

assign int_ts_rcvd_pulse_bus = ltssm_state_is_cfgcomplete ? (smseq_ts1_rcvd_pulse_bus | smseq_ts2_rcvd_pulse_bus) : ltssm_state_is_rcvryrcvrcfg ? smseq_ts2_rcvd_pulse_bus : 0;
always @( * ) begin : link_any_1_ts_rcvd_PROC
    integer n;

    link_any_1_ts_rcvd = 0;
    link_ts_nfts       = 0;
    for ( n=0; n<NL; n=n+1 ) begin
        if ( smlh_lanes_active[n] && int_ts_rcvd_pulse_bus[n] ) begin //the lane n is active
            link_any_1_ts_rcvd = 1;
            link_ts_nfts = n_fts_s3_lane[n];
        end
    end
end // link_any_1_ts_rcvd_PROC

assign link_any_1_ts2_rcvd = |(smlh_lanes_active & smseq_ts2_rcvd_pulse_bus);


//assign link_lane0_ts_link_num = link_num_s1_lane[0];
always @( posedge core_clk or negedge core_rst_n ) begin : int_any_exact_1_2_ts_rcvd_PROC
    integer n;

    if ( ~core_rst_n ) begin
        int_any_exact_1_ts_rcvd <= #TP 0;
        int_any_exact_2_ts_rcvd <= #TP 0;
        int_any_exact_4_ts_rcvd <= #TP 0;
        int_any_exact_5_ts_rcvd <= #TP 0;
        int_any_exact_2_ts_l0p_rcvd <= #TP 0;
    end else if ( ltssm_clear ) begin
        int_any_exact_1_ts_rcvd <= #TP 0;
        int_any_exact_2_ts_rcvd <= #TP 0;
        int_any_exact_4_ts_rcvd <= #TP 0;
        int_any_exact_5_ts_rcvd <= #TP 0;
        int_any_exact_2_ts_l0p_rcvd <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( int_ts_rcvd_cnt[n*3 +: 3] >= 1 && link_mode_lanes_active[n] ) // only use for deskew reset in Cfg.Linkwidth.Accept
                int_any_exact_1_ts_rcvd <= #TP 1;

            if ( int_ts_rcvd_cnt[n*3 +: 3] >= 2 && smlh_lanes_active[n] )
                int_any_exact_2_ts_rcvd <= #TP 1;

            if ( int_ts_rcvd_cnt[n*3 +: 3] >= 4 && smlh_lanes_active[n] )
                int_any_exact_4_ts_rcvd <= #TP 1;

            if ( int_ts_rcvd_cnt[n*3 +: 3] >= 5 && smlh_lanes_active[n] )
                int_any_exact_5_ts_rcvd <= #TP 1;
            if ( (n==0 && int_ts_rcvd_cnt[n*3 +: 3] >= 2 && link_mode_lanes_active[n] && ~g6_rate)
              || (n!=0 && int_ts_rcvd_cnt[n*3 +: 3] >= 2 && link_mode_lanes_active[n] && ~smlh_l0p_lanes_active[n]))
                int_any_exact_2_ts_l0p_rcvd <= #TP 1;
        end
    end
end // int_any_exact_1_2_ts_rcvd_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : int_any_exact_1_2_ts_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        int_any_exact_1_ts_rcvd_d <= #TP 0;
        int_any_exact_2_ts_rcvd_d <= #TP 0;
        int_any_exact_4_ts_rcvd_d <= #TP 0;
        int_any_exact_5_ts_rcvd_d <= #TP 0;
        int_any_exact_2_ts_l0p_rcvd_d <= #TP 0;
    end else begin
        int_any_exact_1_ts_rcvd_d <= #TP int_any_exact_1_ts_rcvd;
        int_any_exact_2_ts_rcvd_d <= #TP int_any_exact_2_ts_rcvd;
        int_any_exact_4_ts_rcvd_d <= #TP int_any_exact_4_ts_rcvd;
        int_any_exact_5_ts_rcvd_d <= #TP int_any_exact_5_ts_rcvd;
        int_any_exact_2_ts_l0p_rcvd_d <= #TP int_any_exact_2_ts_l0p_rcvd;

    end
end // int_any_exact_1_2_ts_rcvd_d_PROC

assign link_any_exact_1_ts_rcvd = ~ltssm_clear & int_any_exact_1_ts_rcvd & ~int_any_exact_1_ts_rcvd_d;
assign link_any_exact_2_ts_rcvd = ~ltssm_clear & int_any_exact_2_ts_rcvd & ~int_any_exact_2_ts_rcvd_d;
assign link_any_exact_4_ts_rcvd = ~ltssm_clear & int_any_exact_4_ts_rcvd & ~int_any_exact_4_ts_rcvd_d;
assign link_any_exact_5_ts_rcvd = ~ltssm_clear & int_any_exact_5_ts_rcvd & ~int_any_exact_5_ts_rcvd_d;
assign link_any_exact_2_ts_l0p_rcvd = ~ltssm_clear & int_any_exact_2_ts_l0p_rcvd & ~int_any_exact_2_ts_l0p_rcvd_d;

always @( posedge core_clk or negedge core_rst_n ) begin : int_ts_rcvd_cnt_PROC
    integer n;

    if ( ~core_rst_n ) begin
        int_ts_rcvd_cnt <= #TP 0;
    end else if ( ltssm_clear ) begin
        int_ts_rcvd_cnt <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( (smseq_ts2_rcvd_pulse_bus[n] || smseq_ts1_rcvd_pulse_bus[n]) && (int_ts_rcvd_cnt[n*3 +: 3] < 7) ) begin
                int_ts_rcvd_cnt[n*3 +: 3] <= #TP int_ts_rcvd_cnt[n*3 +: 3] + 1;
            end
        end
    end
end // int_ts_rcvd_cnt_PROC

//
//Hot Reset Entry
//
assign link_any_2_ts1_linknmtx_lanenmtx_hotreset1_rcvd = |(smlh_lanes_active & current_2_ts1_linknmtx_lanenmtx_rcvd_bus & hot_reset_s5_lane);

//
//Loopback Entry
//
logic ltssm_state_is_lpbkentry_d;
wire  ltssm_state_is_lpbkentry_rising_edge = ltssm_state_is_lpbkentry && !ltssm_state_is_lpbkentry_d;

always_ff @(posedge core_clk or negedge core_rst_n) begin : ltssm_state_is_lpbkentry_d_PROC
    if (!core_rst_n) begin
        ltssm_state_is_lpbkentry_d <= #TP 1'b0;
    end else begin
        ltssm_state_is_lpbkentry_d <= #TP ltssm_state_is_lpbkentry;

    end
end // ltssm_state_is_lpbkentry_d_PROC
always @( posedge core_clk or negedge core_rst_n ) begin : latched_2_ts1_rcvd_bus_PROC
    integer n;

    if ( ~core_rst_n ) begin
        latched_2_ts1_rcvd_bus <= #TP 0;
    end else if ( ltssm_state_is_lpbkentry_rising_edge || current_data_rate==`GEN1_RATE || current_data_rate==`GEN2_RATE ) begin
        latched_2_ts1_rcvd_bus <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( current_2_ts1_rcvd_bus[n] )
                latched_2_ts1_rcvd_bus[n] <= #TP 1;
        end
    end
end // latched_2_ts1_rcvd_bus_PROC

assign int_2_ts1_rcvd_bus = (current_2_ts1_rcvd_bus & {NL{current_data_rate==`GEN3_RATE || current_data_rate==`GEN4_RATE || current_data_rate==`GEN5_RATE || current_data_rate==`GEN6_RATE}}) | latched_2_ts1_rcvd_bus;
assign link_latched_live_all_2_ts1_rcvd = &(~smlh_lanes_active | int_2_ts1_rcvd_bus);

always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_ts_retimer_pre_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_latched_ts_retimer_pre <= #TP 0;
        link_latched_ts_two_retimers_pre <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( ltssm_state_is_cfgcomplete && ~ltssm_clear ) begin
                if ( current_8_ts2_linknmtx_lanenmtx_rcvd_bus[n] && link_mode_lanes_active[n] ) begin //any active lane receives 8 ts2s
                    link_latched_ts_retimer_pre <= #TP retimer_pre_ts2_s5_lane[n] | link_latched_ts_retimer_pre;
                    link_latched_ts_two_retimers_pre <= #TP two_retimers_pre_ts2_s5_lane[n] | link_latched_ts_two_retimers_pre;
                end
            end
            else begin
                link_latched_ts_retimer_pre <= #TP 0;
                link_latched_ts_two_retimers_pre <= #TP 0;
            end
        end
    end
end // link_latched_ts_retimer_pre_PROC

// During Polling.Configuration LTSSM state, the Downstream Port samples the Retimer Present bit and the Two Retimers Present bit for use during CXL alternate protocol nego
always @( posedge core_clk or negedge core_rst_n ) begin : link_latched_poll_config_ts_retimer_pre_PROC
    integer n;

    if ( ~core_rst_n ) begin
        link_latched_poll_config_ts_retimer_pre <= #TP 0;
        link_latched_poll_config_ts_two_retimers_pre <= #TP 0;
    end else begin
        for ( n=0; n<NL; n=n+1 ) begin
            if ( ltssm_state_is_pollconfig && ~ltssm_clear ) begin
                if ( current_8_ts2_plinkn_planen_modts_supt_rcvd && link_mode_lanes_active[n] ) begin //any active lane receives 8 ts2s
                    link_latched_poll_config_ts_retimer_pre <= #TP retimer_pre_ts2_s5_lane[n] | link_latched_poll_config_ts_retimer_pre;
                    link_latched_poll_config_ts_two_retimers_pre <= #TP two_retimers_pre_ts2_s5_lane[n] | link_latched_poll_config_ts_two_retimers_pre;
                end
            end
            else if(ltssm_state_is_cfglanenumwait || ltssm_state_is_pollactive) begin
                link_latched_poll_config_ts_retimer_pre <= #TP 0;
                link_latched_poll_config_ts_two_retimers_pre <= #TP 0;
            end
        end
    end
end // link_latched_poll_config_ts_retimer_pre_PROC

always @( * ) begin : smlh_inskip_rcv_PROC
    smlh_inskip_rcv = smseq_inskip_rcv_bus;
end // smlh_inskip_rcv_PROC

//
// active lanes based on correct TS rcvd
//
assign smlh_lanes_rcving = link_mode_lanes_active;

//begin of following signals for debug purposes
always @( * ) begin : smlh_ts_link_ctrl_PROC
smlh_ts_link_ctrl        = sym5_lane[0][4:0];
smlh_rcvd_lane_rev       = link_latched_live_all_2_ts1_linknmtx_lanen_rcvd && ~link_latched_live_lane0_2_ts1_lanen0_rcvd;
smlh_ts_link_num         = sym1_lane[0];
smlh_ts_link_num_is_k237 = link_num_pad_lane[0];
smlh_ts_rcv_err          = smseq_ts_error_bus[0];
smlh_ts1_rcvd            = smseq_ts1_rcvd_bus[0];
smlh_ts2_rcvd            = smseq_ts2_rcvd_bus[0];
smlh_ts_lane_num_is_k237 = lane_num_pad_lane[0];
end // smlh_ts_link_ctrl_PROC
//end of debug purposes signals

// function for next_link_mode is used to update link_mode in smlh_ltssm.v (link_mode = next_link_mode after timeout_1ms)
function automatic [5:0] next_link_mode;
    input          lane0_valid;
    input [NL-1:0] data_i;
    input [NL-1:0] data_reversed_i;
    input          rxei_exit;

    reg int_one_lane;
    begin
        int_one_lane = | data_i[7] | data_i[3] | data_i[1] | 1'b0;

        if ( lane0_valid ) begin
            next_link_mode =
                (data_i[7:0]  == 8'hFF ) ? 8 :
                (data_i[3:0]  == 4'hF ) ? 4 :
                (data_i[1:0]  == 2'b11 ) ? 2 :
                1;
        end else begin
            next_link_mode =
                (data_reversed_i[7:0]  == 8'hFF ) ? 8 :
                (data_reversed_i[3:0]  == 4'hF ) ? 4 :
                (data_reversed_i[1:0]  == 2'b11 ) ? 2 :
                (data_reversed_i[0]    == 1'b1 ) ? 1 :
                 rxei_exit ? (int_one_lane ? 1 : 0) :   // if rxei_exit = 1, form a x1 link
                0; //cannot form a link
        end
    end
endfunction //next_link_mode

//function to reverse data_i within link_mode
function automatic [NL-1:0] bit_flip;
    input [NL-1:0]  data_i;
    input [5:0]     link_mode;

    integer n;

    begin
        for ( n=0; n<NL; n=n+1 )
            bit_flip[n] = 0;

        if ( link_mode == 8 ) begin
            for ( n=0; n<8; n=n+1 )
                bit_flip[7-n] = data_i[n];
        end else
        if ( link_mode == 4 ) begin
            for ( n=0; n<4; n=n+1 )
                bit_flip[3-n] = data_i[n];
        end else
        if ( link_mode == 2 ) begin
            for ( n=0; n<2; n=n+1 )
                bit_flip[1-n] = data_i[n];
        end else
        bit_flip[0] = data_i[0];
    end
endfunction // bit_flip

//function to reverse data_i on byte within link_mode
function automatic [NL-1:0] byte_flip;
    input [NL*8-1:0]  data_i;
    input [5:0]     link_mode;

    integer n;

    begin
        for ( n=0; n<NL; n=n+1 )
            byte_flip[n] = 0;

        if ( link_mode == 8 ) begin
            for ( n=0; n<8; n=n+1 )
                byte_flip[7-n] = data_i[n*8 +: 8] == 7 - n;
        end else
        if ( link_mode == 4 ) begin
            for ( n=0; n<4; n=n+1 )
                byte_flip[3-n] = data_i[n*8 +: 8] == 3 - n;
        end else
        if ( link_mode == 2 ) begin
            for ( n=0; n<2; n=n+1 )
                byte_flip[1-n] = data_i[n*8 +: 8] == 1 - n;
        end else
        byte_flip[0] = data_i[0 +: 8] == 0;
    end
endfunction // byte_flip

assign smlh_ts_rcvd_pulse_bus = ( smseq_ts0_rcvd_pulse_bus | smseq_ts1_rcvd_pulse_bus | smseq_ts2_rcvd_pulse_bus) & smlh_lanes_active;

always @( * ) begin : smlh_sds_rcvd_PROC
    smlh_sds_rcvd = smseq_sds_rcvd_bus;
end //always


endmodule
