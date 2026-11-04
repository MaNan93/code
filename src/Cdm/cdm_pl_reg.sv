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
// ---    $Revision: #59 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pl_reg.sv#59 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the PCIE core local registers.
// --- the PCIE configuration cycles and CPU access will be mapped to the
// --- local bus cycles. The total register space is 64K, first 32K is reserved for
// --- configuration registers and second 32K is reserved for core local registers
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 module cdm_pl_reg
 (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    app_dbi_ro_wr_disable,
    lbc_cdm_addr,
    lbc_cdm_data,
    pl_reg_sel,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    upstream_port,
    phy_cfg_status,
    cxpl_debug_info,
    smlh_autoneg_link_width,
    cfg_max_payload_size,
    cfg_min_payload_size,
    cfg_comm_clk_config,
    xtlh_xadm_ph_cdts,
    xtlh_xadm_pd_cdts,
    xtlh_xadm_nph_cdts,
    xtlh_xadm_npd_cdts,
    xtlh_xadm_cplh_cdts,
    xtlh_xadm_cpld_cdts,
    radm_qoverflow,
    radm_q_not_empty,
    radm_formq_read_err,
    radm_formq_overflow,
    radm_formq_not_empty,
    xdlh_retrybuf_not_empty,
    rtlh_crd_not_rtn,
    smlh_core_rst_n_release_pulse,
    smlh_dir_spd_chg_rising_edge,
    smlh_dir_linkw_chg_started,
    current_data_rate,
   msg_ltr_det,
   msg_ltr_latency,
    cfg_ext_synch,

    or_rasdp_err_uncorr,
    or_rasdp_err_corr,
    app_dev_num,                     // Application driven device number
    app_bus_num,                    // Application driven bus number
    cxl_vlsm_state,
    cxl_cache_mem_vlsm_state,
    cxl_io_vlsm_state,
    cxl_mc_almp_unexp_error,
    cxl_io_almp_unexp_error,
    cxl_lrsm_state,
    cxl_lrsm_fatal_error,
    cxl_fatal_error,
    cxl_viral_status_set,
    cxl_viral_status,
    cm_ll_cache_poison_injection_busy,
    cm_ll_mem_poison_injection_busy,
    cm_ll_io_poison_injection_busy,
    cm_ll_cache_mem_crc_injection_busy,
    io_ll_io_poison_injection_busy,
    io_ll_flow_ctrl_error_injection_busy,
    fb_phy_protid_injection_busy,
    rmlh_prbs_done,
    rmlh_prbs_fail,
    rmlh_prbs_started,
    rmlh_prbs_err_cntr,
    rmlh_prbs_unexp_fail,
// -- outputs --
    cfg_lane_en,
    cfg_gen1_ei_inference_mode,
    cfg_select_deemph_mux_bus,
    cfg_lut_ctrl,
    cfg_rxstandby_control,
    cfg_pl_gen3_control,
    cfg_pl_gen3_eq_control,
    cfg_fdbk_dirchange_control,
    cfg_pl_gen3_zrxdc_noncompl,
    cfg_no_seed_value_change,
    cfg_pl_gen4_control,
    cfg_pl_gen4_eq_control,
    cfg_gen4_fdbk_dirchange_control,
    cfg_pl_gen5_control,
    cfg_pl_gen5_eq_control,
    cfg_gen5_fdbk_dirchange_control,
    cfg_pl_gen6_control,
    cfg_pl_gen6_eq_control,
    cfg_gen6_fdbk_dirchange_control,
    cfg_pl_multilane_control,
    cfg_pl_l1sub_control,
    cfg_pl_l1_exit_mode,
    cfg_pl_l1_nowait_p1,
    cfg_pl_l1_clk_sel,
    cfg_p2nobeacon_enable,
    cfg_utility,
    pm_cfg_utility,
    cfg_pipe_optional_pclkchange_hs,
    cfg_phy_perst_on_warm_reset,
    cfg_phy_rst_timer,
    cfg_pma_phy_rst_delay_timer,
    cfg_dsp_pcipm_l1_enter_delay,
    cfg_pl_aux_clk_freq,
    cfg_gen2_n_fts,
    cfg_directed_speed_change,
    cfg_phy_txswing,
    cfg_tx_compliance_rcv,
    cfg_up_sel_deemph,
    cfg_ack_freq,
    cfg_ack_latency_timer,
    cfg_replay_timer_value,
    cfg_fc_latency_value,
    cfg_other_msg_payload,
    cfg_other_msg_request,
    cfg_corrupt_crc_pattern,
    cfg_scramble_dis,
    cfg_n_fts,
    cfg_link_dis,
    cfg_lpbk_en,
    cfg_elastic_buffer_mode,
    cfg_pipe_loopback,
    cfg_rxstatus_lane,
    cfg_rxstatus_value,
    cfg_lpbk_rxvalid,
    cfg_plreg_reset,
    cfg_link_num,
    cfg_ts2_lid_deskew,
    cfg_support_part_lanes_rxei_exit,
    cfg_forced_link_state,
    cfg_forced_ltssm_cmd,
    cfg_force_en,
    cfg_lane_skew,
    cfg_drift_buffer_deskew_enable,
    cfg_deskew_disable,
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_imp_num_lanes,
    cfg_link_capable,
    cfg_xmt_beacon,
    cfg_tx_reverse_lanes,
    cfg_eidle_timer,
    cfg_skip_interval,
    cfg_link_rate,
    cfg_fast_link_mode,
    cfg_fast_link_scaling_factor,
    cfg_dll_lnk_en,
    pl_reg_data,
    pl_reg_ack,
    cfg_crs_sw_vis_en,
    cfg_err_resp,
    cfg_auto_flush_en,
    cfg_auto_flush_timeout,
    cfg_link_timeout_en_n,
    cfg_link_timeout_period,
    cfg_ax_mstr_ordr_p_event_sel,
    cfg_ax_snp_en,
    cfg_ib_p_id_mng_ctrl,
    cfg_mstr_arcache_mode,
    cfg_mstr_awcache_mode,
    cfg_mstr_arcache_value,
    cfg_mstr_awcache_value,
    cfg_aximstr_msg_addr_low,
    cfg_aximstr_msg_addr_high,
    cfg_mstr_ardomain_mode,
    cfg_mstr_awdomain_mode,
    cfg_mstr_ardomain_value,
    cfg_mstr_awdomain_value,
    cfg_ax_mstr_zeroread_fw,
    cfg_memtype_value,
    cfg_memtype_boundary,

    target_mem_map,
    target_rom_map,
    cfg_phy_control,
    cfg_l0s_entr_latency_timer,
    cfg_upd_aspm_ctrl,
    cfg_l1_entr_latency_timer,
    cfg_l1_entr_wo_rl0s,
    cfg_aspm_l1_timer_enable,
    cfg_filter_rule_mask,
    cfg_fc_wdog_disable,
    cfg_lpvc_wrr_weight,
    cfg_max_func_num,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    cfg_radm_q_mode,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_clock_gating_ctrl,
    cfg_trgt_cpl_lut_delete_entry,
    cfg_radm_strict_vc_prior,
    hdr_scale_p,
    data_scale_p,
    hdr_scale_np,
    data_scale_np,
    hdr_scale_cpl,
    data_scale_cpl,
    app_ltr_latency,
    cdmpl2cfg_ltr_rq,
    cfg_disable_ltr_clr_msg,
    cfg_hq_depths,
    cfg_dq_depths,
    cfg_gen3_eq_fs_lf,
    cfg_gen3_eq_coef,
    cfg_gen4_eq_fs_lf,
    cfg_gen4_eq_coef,
    cfg_gen5_eq_fs_lf,
    cfg_gen5_eq_coef,
    cfg_gen6_eq_fs_lf,
    cfg_gen6_eq_coef,
    cfg_margin_num_timing_steps,
    cfg_margin_max_timing_offset,
    cfg_margin_num_voltage_steps,
    cfg_margin_max_voltage_offset,
    cfg_margin_sample_rate_voltage,
    cfg_margin_sample_rate_timing,
    cfg_margin_maxlanes,
    cfg_margin_voltage_supported,
    cfg_margin_ind_up_down_voltage,
    cfg_margin_ind_left_right_timing,
    cfg_margin_sample_reporting_method,
    cfg_margin_ind_error_sampler,
    cfg_rx_message_bus_write_buffer_depth,
    cfg_pipe_garbage_data_mode,
    cfg_pam4_restricted_levels_requirement,
    dbi_ro_wr_en,
    default_target,
    cfg_cfg_tlp_bypass_en,
    cfg_config_limit,
    cfg_target_above_config_limit,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    cfg_ras_reg_pf0_only,
    cfg_rasdes_reg_pf0_only,
    ur_ca_mask_4_trgt1

    ,
    cfg_nond0_vdm_block,
    cfg_client0_block_new_tlp,
    cfg_client1_block_new_tlp,
    cfg_client2_block_new_tlp
    ,
    pm_powerdown_status,
    cfg_force_powerdown
   ,cxl_vlsm_pm_enable
   ,cxl_apn_bypass_enable
   ,cxl_apn_sw_mode
   ,cxl_vlsm_to_active
   ,cxl_max_num_retry
   ,cxl_max_num_reinit
   ,cxl_lrsm_timeout_threshold
   ,cxl_crc_threshold
   ,cxl_ras_uncorr_err
   ,cxl_fatal_error_reg
   ,cm_ll_cache_poison_injection_start
   ,cm_ll_mem_poison_injection_start
   ,cm_ll_io_poison_injection_start
   ,cm_ll_cache_mem_crc_injection
   ,cm_ll_cache_mem_crc_injection_count

   ,io_ll_io_poison_injection_start
   ,io_ll_flow_ctrl_error_injection

   ,fb_phy_cor_protid_error_injection
   ,fb_phy_uncor_protid_error_injection
   ,fb_phy_unexp_protid_error_injection
   ,cfg_optional_ohc
   ,cfg_tx_throttling
    ,cfg_dbi_func_bank_select
    ,cfg_err_inj_wr_disable
    ,cfg_tx_arb_control
    ,cfg_l0p_priority
    ,cfg_l0p_dynamic_target_link_width      
    ,cfg_direct_l0p_dynamic_link_width_change
    ,cfg_aspm_l0p_dynamic_disable      
    ,cfg_l0p_dynamic_priority 
    ,l0p_dynamic_write
    ,rc_device
    ,cfg_flit_err_inj_latency
    ,cfg_prbs_en
    ,clear_prbs_done
    ,cfg_prbs_lane_sel
);
parameter INST               = 0;                        // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM           = 0;                        // uniquifying parameter per function
parameter NL                 = `CX_NL;
parameter NLM1               = `CX_NL_M_1;               // `CX_NL - 1
parameter TXNL               = `CM_TXNL;                 // Tx Lane Width for M-PCIe
parameter RXNL               = `CM_RXNL;                 // Rx Lane Width for M-PCIe
parameter NB                 = `CX_NB;
parameter NW                 = `CX_NW;
parameter NVC                = `CX_NVC;
parameter NF                 = `CX_NFUNC;                // Number of functions
parameter PF_WD              = `CX_NFUNC_WD;             // Width of physical function number
parameter TP                 = `TP;                      // Clock to Q delay (simulator insurance)
parameter N_FLT_MASK         = `CX_N_FLT_MASK;
parameter RADM_SBUF_HDRQ_PW  = `CX_RADM_SBUF_HDRQ_PW;
parameter RADM_SBUF_DATAQ_PW = `CX_RADM_SBUF_DATAQ_PW;
parameter FREQ               = `CX_FREQ;

localparam ATU_CTRL_REG_ID_WD = 10;

localparam GM_NW             = (`CC_MSTR_BUS_DATA_WIDTH > `CC_CORE_DATA_BUS_WD) ? `CC_MSTR_NW : `CX_NW;
localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;

parameter FS_LF_WD = 12;
parameter COEF_WD = 18;
parameter PSET_COEF_ID_WD = 4;

parameter GEN4MODE = `CX_GEN4_MODE;
localparam SIMPLIFIED_REPLAY_TIMER_GEN4 = (GEN4MODE == 2) ? 1'b0 : 1'b1;
localparam P2P_ENABLE = (`CX_P2P_ENABLE_VALUE == 1) ? 1'b1 : 1'b0;

localparam TAG_SIZE = `CX_TAG_SIZE;




parameter HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
parameter DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;

localparam P2NOBEACON_ENABLE = `CX_P2NOBEACON_ENABLE_VALUE;
localparam PIPE_OPTIONAL_PCLKCHANGE_HS = `CX_PIPE_OPTIONAL_PCLKCHANGE_HS;
localparam DEFAULT_PHY_PERST_ON_WARM_RESET = `DEFAULT_PHY_PERST_ON_WARM_RESET;
parameter PWDN_WIDTH = `CX_PHY_PDOWN_WD;
localparam PHY_RST_TIMER = `CX_PHY_RST_TIMER;
localparam PMA_PIPE_RST_DELAY_TIMER = `CX_PMA_PIPE_RST_DELAY_TIMER;
localparam DSP_PCIPM_L1_ENTER_DELAY = `CX_DSP_PCIPM_L1_ENTER_DELAY;
localparam ASPM_L1_TIMER_ENABLE = `CX_ASPM_L1_TIMER_ENABLE_VALUE;
localparam AUX_CLK_FREQ_RST_VAL = `DEFAULT_AUX_CLK_FREQ;
localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

// ----- Inputs ---------------
input [(2*PWDN_WIDTH) - 1 : 0]      pm_powerdown_status;
output       cm_ll_cache_poison_injection_start;    // CXL.cache/CXL.mem LinkLayerErrorInjection - Cache Poison Injection Start
output       cm_ll_mem_poison_injection_start;      // CXL.cache/CXL.mem LinkLayerErrorInjection - Mem Poison Injection Start
output       cm_ll_io_poison_injection_start;       // CXL.cache/CXL.mem LinkLayerErrorInjection - IO Posion Injection Start
output [1:0] cm_ll_cache_mem_crc_injection;         // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Start
output [1:0] cm_ll_cache_mem_crc_injection_count;   // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Count

output       io_ll_io_poison_injection_start;       // CXL.io LinkLayer Error injection - IO Posion Injection Start
output       io_ll_flow_ctrl_error_injection;       // CXL.io LinkLayer Error injection - Flow Control Error Injection Start

output       fb_phy_cor_protid_error_injection;     // Flex Bus LogPHY Error injection - Correctable Protocol ID Error Injection Start
output       fb_phy_uncor_protid_error_injection;   // Flex Bus LogPHY Error injection - Uncorrectable Protocol ID Error Injection Start
output       fb_phy_unexp_protid_error_injection;   // Flex Bus LogPHY Error injection - Unexpected Protocol ID Error Injection Start
wire                                int_force_powerdown;
wire                                int_vmain_ack_ctrl_en;
output reg                          cfg_force_powerdown;
wire  [(2*PWDN_WIDTH + 4) - 1 : 0]  int_powerdown_status;
reg                                 cfg_vmain_ack_ctrl;

input                   core_clk;
input                   non_sticky_rst_n;
input                   sticky_rst_n;

input                   cdm_clk_g;                  // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc

input                   app_dbi_ro_wr_disable;      // Set dbi_ro_wr_en to 0, disable write to DBI_RO_WR_EN bit
input   [11:0]          lbc_cdm_addr;               // Address of resource being accessed
input   [31:0]          lbc_cdm_data;               // Data for write
input                   pl_reg_sel;                 // bus strobe (indicates an active bus cycle)
input   [3:0]           lbc_cdm_wr;                 // Write select: 1 = write, 0 = read
input                   lbc_cdm_dbi;                // Indicates that the CDM is acccessed from dbi
input                   upstream_port;              // Upstream Port
input   [31:0]          phy_cfg_status;             // status from PHY, mapping differently for different PHY
input   [63:0]          cxpl_debug_info;            // status that should be useful for debug/brinqup activities

input   [5:0]           smlh_autoneg_link_width;    // Operating link width
input   [2:0]           cfg_max_payload_size;       // Largest of Max Payload Size from Device Control register
input   [2:0]           cfg_min_payload_size;       // Smallest of Max Payload Size from Device Control register
input                   cfg_comm_clk_config;        // common clock configuration
input   [HCRD_WD-1:0]   xtlh_xadm_ph_cdts;          // header for P credits
input   [DCRD_WD-1:0]   xtlh_xadm_pd_cdts;          // data for P credits
input   [HCRD_WD-1:0]   xtlh_xadm_nph_cdts;         // header for NPR credits
input   [DCRD_WD-1:0]   xtlh_xadm_npd_cdts;         // data for NPR credits
input   [HCRD_WD-1:0]   xtlh_xadm_cplh_cdts;        // header for cPL credits
input   [DCRD_WD-1:0]   xtlh_xadm_cpld_cdts;        // data for cPL credits
input                   radm_qoverflow;             // RADM Queue overflow flag
input                   radm_q_not_empty;           // RADM Queue not empty
input                   radm_formq_read_err;
input                   radm_formq_overflow;
input                   radm_formq_not_empty;
input                   xdlh_retrybuf_not_empty;    // Retry buffer not empty
input                   rtlh_crd_not_rtn;           // Credit not returned

input                   smlh_core_rst_n_release_pulse; // assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change
input                   smlh_dir_spd_chg_rising_edge;  // clear cfg_directed_speed_change
input                   smlh_dir_linkw_chg_started; // clear cfg_directed_link_width_change
input   [2:0]           current_data_rate;          // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4
input                   msg_ltr_det;                // Transmitted (by upstream port) or Received (by downstream port) LTR message detected
input   [31:0]          msg_ltr_latency;            // Transmitted (by upstream port) or Received (by downstream port) LTR message field
input                  cfg_ext_synch;                     // Extended Synch

input                   or_rasdp_err_uncorr;
input                   or_rasdp_err_corr;
input   [4:0]           app_dev_num; // DEV# from application
input   [7:0]           app_bus_num; // BUS# from application
input       cm_ll_cache_poison_injection_busy;     // CXL.cache/CXL.mem LinkLayerErrorInjection - Cache Poison Injection Busy
input       cm_ll_mem_poison_injection_busy;       // CXL.cache/CXL.mem LinkLayerErrorInjection - Mem Poison Injection Busy
input       cm_ll_io_poison_injection_busy;        // CXL.cache/CXL.mem LinkLayerErrorInjection - IO Posion Injection Busy
input       cm_ll_cache_mem_crc_injection_busy;    // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Busy
input       io_ll_io_poison_injection_busy;        // CXL.io LinkLayer Error injection - IO Posion Injection Busyt
input       io_ll_flow_ctrl_error_injection_busy;  // CXL.io LinkLayer Error injection - Flow Control Error Injection Busy
input       fb_phy_protid_injection_busy;          // Flex Bus LogPHY Error injection - Protocol ID Error Injection Busy
input   [3:0]           cxl_vlsm_state;
input   [3:0]           cxl_cache_mem_vlsm_state;
input   [3:0]           cxl_io_vlsm_state;
input   [2:0]           cxl_mc_almp_unexp_error;
input   [2:0]           cxl_io_almp_unexp_error;
input   [5:0]           cxl_lrsm_state;               //Reflects the current state of the LRSM
input                   cxl_lrsm_fatal_error;         //Asserted when unexpected Retry.Ack is received or LRSM reaches Abort state.
input   [31:0]          cxl_fatal_error;              //Fatal Error Register
input                   cxl_viral_status_set;
output                  cxl_viral_status;


input              rmlh_prbs_done;               // Finished PBRS Loopback
input              rmlh_prbs_fail;               // PRBS Comparison error occurred
input  [NL-1:0]           rmlh_prbs_started;      // PRBS started status
input  [NL-1:0][7:0] rmlh_prbs_err_cntr;     // PRBS comparison error counter for laneX
input  [NL-1:0]           rmlh_prbs_unexp_fail;   // PRBS unexpeced error occurred

// ----- Outputs ---------------
output [`CX_PL_GEN3_CONTROL_WD-1:0]    cfg_pl_gen3_control;    // Port Logic Gen3 Control Register
output [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control; // Port Logic Gen3 EQ Control Register
output [`CX_DIR_CHANGE_CONTROL_WD-1:0] cfg_fdbk_dirchange_control; //Port Logic Gen3 EQ Feedback Direction Change Control Register
output                 cfg_pl_gen3_zrxdc_noncompl;     // Port Logic register bit field indicating non compliance of 2.5 GT/s receiver impedance while in 8GT/s mode.
                                                       // (8 GT/s Receiver Impedance ECN).
output                 cfg_no_seed_value_change;       // 1: no gen3/4/5 scrambler seed value change
output [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen4_control;    // Port Logic Gen4 Control Register
output [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control; // Port Logic Gen4 EQ Control Register
output [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen4_fdbk_dirchange_control; //Port Logic Gen3 EQ Feedback Direction Change Control Register
output [`CX_PL_GEN5_CONTROL_WD-1:0]    cfg_pl_gen5_control;    // Port Logic Gen4 Control Register
output [`CX_PL_GEN5_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control; // Port Logic Gen4 EQ Control Register
output [`CX_GEN5_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen5_fdbk_dirchange_control; //Port Logic Gen3 EQ Feedback Direction Change Control Register
output [`CX_PL_GEN6_CONTROL_WD-1:0]    cfg_pl_gen6_control;    // Port Logic Gen6 Control Register
output [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control; // Port Logic Gen6 EQ Control Register
output [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control; //Port Logic Gen6 EQ Feedback Direction Change Control Register
output [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control; // Multi Lane Control Register
output [`CX_PL_L1SUB_CONTROL_WD-1:0] cfg_pl_l1sub_control; //Port Logic L1 Substates Register
output                               cfg_pl_l1_exit_mode;
output                               cfg_pl_l1_nowait_p1;
output                               cfg_pl_l1_clk_sel; // Port Logic bit to allow to disable core_clk gating in L1
output                               cfg_p2nobeacon_enable; // Enable support to P2.NoBeacon
output                               cfg_pipe_optional_pclkchange_hs; // Enable PIPE Optional PCLK Change Behaviour
output                               cfg_phy_perst_on_warm_reset; // PMC will drive pm_req_phy_perst during warm reset
output [17:0]                        cfg_phy_rst_timer;        // PHY rst timer.
output [5:0]                         cfg_pma_phy_rst_delay_timer;  // Delay between PMA reset and PIPE rst timer.
output [3:0]                         cfg_dsp_pcipm_l1_enter_delay; // PCIPM L1 entry delay
output [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;
output  [8:0]           cfg_lane_en;                // Number of lanes (1-256)
output                  cfg_gen1_ei_inference_mode; // EI inference mode for Gen1. default 0 - using rxelecidle==1; 1 - using rxvalid==0
output  [1:0]           cfg_select_deemph_mux_bus;  // sel deemphasis {bit, var}
output  [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl;           // lane under test + gen5
output  [7:0]           cfg_rxstandby_control;      // Rxstandby Control
output  [7:0]           cfg_gen2_n_fts;             // Advertised NFTS# for Gen2 speed
output                  cfg_directed_speed_change;  // Directed higher speed change
output                  cfg_phy_txswing;            // controls mac_phy_txswing signal to the phy
output                  cfg_tx_compliance_rcv;      // Sets the compliance received bit in the TS1
output                  cfg_up_sel_deemph;          // Selectable de-emphasis (upstream port only)
output  [7:0]           cfg_ack_freq;               // ACK frequency
output  [15:0]          cfg_ack_latency_timer;      // ACK Latency timer
output  [16:0]          cfg_replay_timer_value;     // Replay Timer value
output  [12:0]          cfg_fc_latency_value;       // fc latency Timer value
output  [31:0]          cfg_other_msg_payload;      // Other MSG payload
output                  cfg_other_msg_request;      // Other MSG request
output  [31:0]          cfg_corrupt_crc_pattern;    // CRC Corruption pattern
output  [5:0]           cfg_link_capable;           // Link capable
output                  cfg_scramble_dis;           // Scramble disable
output  [7:0]           cfg_n_fts;                  // NFTS #
output                  cfg_xmt_beacon;             // Transmit beacon
output                  cfg_tx_reverse_lanes;       // Reverse lanes
output                  cfg_link_dis;               // Link disable
output                  cfg_lpbk_en;                // Loopback enable
output                  cfg_elastic_buffer_mode;    // 0 - nominal half full mode, 1 - nominal empty mode
output                  cfg_pipe_loopback;          // Local Loopback Enable
output  [5:0]           cfg_rxstatus_lane;          // Lane to inject rxstatus value(bit6 = all lanes)
output  [2:0]           cfg_rxstatus_value;         // rxstatus value to inject
output  [NL-1:0]        cfg_lpbk_rxvalid;           // rxvalid value to use during loopback
output  [7:0]           cfg_link_num;               // Link number
output                  cfg_ts2_lid_deskew;         // do deskew using ts2->Logic_Idle_Data transition
output                  cfg_support_part_lanes_rxei_exit; // Polling.Active -> Polling.Config based on part of pre lanes rxei exit
output                  cfg_plreg_reset;
output  [5:0]           cfg_forced_link_state;      // a 4 bits register to move the link state to this value indicated
output  [3:0]           cfg_forced_ltssm_cmd;      // a 4 bits register to issue LTSSM cmd

output                  cfg_force_en;               // force enable has to be a pulse signal generated from cfg block. When software writes
                                                    // to this register, a pulse will be generated to force the link
                                                    // synchronization state machine move from its current state to the
                                                    // cfg_forced_link_state
output  [22:0]          cfg_lane_skew;              // (PL) Transmit lane skew control (optional) for test equipment
output                  cfg_drift_buffer_deskew_enable; // Drift Buffer deskew enable
output                  cfg_deskew_disable;         // Disable lane deskew logic on receive
output                  cfg_flow_control_disable;   // this bit disable the automatic flowcontrol built in this core
output                  cfg_acknack_disable;        // this bit disable the automatic acknack built in this core
output  [3:0]           cfg_imp_num_lanes;          // implementation-specific set of lanes
output  [31:0]          pl_reg_data;                // Read data back from core
output                  pl_reg_ack;                 // Acknowledge back from core. Indicates completion, read data is valid
output                  cfg_dll_lnk_en;             // When = 0, keep DLL layer in inactive state
output  [3:0]           cfg_eidle_timer;            // eidle timer
output  [10:0]          cfg_skip_interval;          // skip interval
output  [3:0]           cfg_link_rate;              // link data rate
output                  cfg_fast_link_mode;         // fast link mode
output  [1:0]           cfg_fast_link_scaling_factor; // fast link timer scaling factor
output    [(6*NF)-1:0]  target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #
output    [NF-1:0]      target_rom_map;             // Each bit of this vector indicates which target receives rom    transactions for that bar #
output  [31:0]          cfg_phy_control;            // control signals to PHY, mapping differently for different PHY
output  [2:0]           cfg_l0s_entr_latency_timer; // L0s entrance latency timer
output                  cfg_upd_aspm_ctrl;          // Used to update the shadowed ASPM control register in pm_ctrl
output  [2:0]           cfg_l1_entr_latency_timer;  // L1 entrance latency timer
output                  cfg_l1_entr_wo_rl0s;        // Start L1 timer without rL0s
output                  cfg_aspm_l1_timer_enable;   // Control the behaviour of the controller ASPM L1 Entry Timer
output  [N_FLT_MASK-1:0]cfg_filter_rule_mask;       // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
output                  cfg_fc_wdog_disable;        // Disable watch dog timer in flow control for some debug purpose
output  [63:0]          cfg_lpvc_wrr_weight;        // WRR weighing per VC ID (8 bits per VC)
output  [PF_WD   -1:0]  cfg_max_func_num;           // Highest accepted function number
output  [(NVC*8)-1:0]   cfg_fc_credit_ph;           // Flow Control credits - Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_nph;          // Flow Control credits - Non-Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_cplh;         // Flow Control credits - Completion Header
output  [(NVC*12)-1:0]  cfg_fc_credit_pd;           // Flow Control credits - Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_npd;          // Flow Control credits - Non-Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_cpld;         // Flow Control credits - Completion Data
output  [(NVC*9)-1:0]   cfg_radm_q_mode;            // Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
output  [NVC-1:0]       cfg_radm_order_rule;        // Order Selection: 0 - Strict Priority, 1 - Complies with Ordering Rule
output  [15:0]          cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
output  [2:0]           cfg_clock_gating_ctrl;      // Enable/Disable clock gating feature

output  [31:0]          cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry
output  [(NVC*2)-1:0]   hdr_scale_p;              // The HdrScale field contains the scaling factor for headers of the indicated type
output  [(NVC*2)-1:0]   data_scale_p;             // The DataScale field contains the scaling factor for payload data of the indicated type
output  [(NVC*2)-1:0]   hdr_scale_np;             // The HdrScale field contains the scaling factor for headers of the indicated type
output  [(NVC*2)-1:0]   data_scale_np;            // The DataScale field contains the scaling factor for payload data of the indicated type
output  [(NVC*2)-1:0]   hdr_scale_cpl;            // The HdrScale field contains the scaling factor for headers of the indicated type
output  [(NVC*2)-1:0]   data_scale_cpl;           // The DataScale field contains the scaling factor for payload data of the indicated type
output                  cfg_radm_strict_vc_prior;   // VC Priority: 0 - Round Robin, 1 - Strict Priority
output  [(NVC*3*RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;  // Indicates the depth of the header queues per type per vc
output  [(NVC*3*RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;  // Indicates the depth of the data queues per type per vc
input                                           cfg_crs_sw_vis_en;
output   [15:0]                                 cfg_err_resp;
output                                          cfg_auto_flush_en;
output  [7:0]                                   cfg_auto_flush_timeout;
output                                          cfg_link_timeout_en_n;
output    [`LINK_TIMEOUT_PERIOD_WIDTH-1:0]      cfg_link_timeout_period;
output [1:0]                                    cfg_ax_mstr_ordr_p_event_sel;
output                                          cfg_ax_snp_en;
output  [`CX_NVC-1:0]                           cfg_ib_p_id_mng_ctrl;
output  [3:0]                                   cfg_mstr_arcache_mode;
output  [3:0]                                   cfg_mstr_awcache_mode;
output  [3:0]                                   cfg_mstr_arcache_value;
output  [3:0]                                   cfg_mstr_awcache_value;
output  [31:0]                                  cfg_aximstr_msg_addr_low;
output  [31:0]                                  cfg_aximstr_msg_addr_high;
output  [1:0]                                   cfg_mstr_ardomain_mode;
output  [1:0]                                   cfg_mstr_awdomain_mode;
output  [1:0]                                   cfg_mstr_ardomain_value;
output  [1:0]                                   cfg_mstr_awdomain_value;
output                                          cfg_ax_mstr_zeroread_fw;
output                                          cfg_memtype_value;
output  [`FLT_Q_ADDR_WIDTH-3:0]                 cfg_memtype_boundary;


output [31:0]                                   app_ltr_latency;       // Transmitted upstream port (Received downstream port) latency tolerance values
output                                          cdmpl2cfg_ltr_rq;      // Port logic to PCIe configuration OR'ed LTR message requirement bits
output                                          cfg_disable_ltr_clr_msg;      // Disable automonous generation of LTR clr msg
output  [FS_LF_WD-1:0]                          cfg_gen3_eq_fs_lf;            // programmable FS and LF for equalization
output  [(11*COEF_WD)-1:0]                      cfg_gen3_eq_coef;             // programmable FS and LF for equalization
output  [FS_LF_WD-1:0]                          cfg_gen4_eq_fs_lf;            // programmable FS and LF for equalization
output  [(11*COEF_WD)-1:0]                      cfg_gen4_eq_coef;             // programmable FS and LF for equalization
output  [FS_LF_WD-1:0]                          cfg_gen5_eq_fs_lf;            // programmable FS and LF for equalization
output  [(11*COEF_WD)-1:0]                      cfg_gen5_eq_coef;             // programmable FS and LF for equalization
output  [FS_LF_WD-1:0]                          cfg_gen6_eq_fs_lf;            // programmable FS and LF for equalization
output  [(11*COEF_WD)-1:0]                      cfg_gen6_eq_coef;             // programmable FS and LF for equalization
output [5:0]                                    cfg_margin_num_timing_steps;
output [5:0]                                    cfg_margin_max_timing_offset;
output [6:0]                                    cfg_margin_num_voltage_steps;
output [5:0]                                    cfg_margin_max_voltage_offset;
output [5:0]                                    cfg_margin_sample_rate_voltage;
output [5:0]                                    cfg_margin_sample_rate_timing;
output [4:0]                                    cfg_margin_maxlanes;
output                                          cfg_margin_voltage_supported;
output                                          cfg_margin_ind_up_down_voltage;
output                                          cfg_margin_ind_left_right_timing;
output                                          cfg_margin_sample_reporting_method;
output                                          cfg_margin_ind_error_sampler;
output [3:0]                                    cfg_rx_message_bus_write_buffer_depth;
output                                          cfg_pipe_garbage_data_mode;
output                                          cfg_pam4_restricted_levels_requirement;
output                                          dbi_ro_wr_en;
output                                          default_target;
output                                          ur_ca_mask_4_trgt1;
output                                          cfg_cfg_tlp_bypass_en;
output [9:0]                                    cfg_config_limit;
output [1:0]                                    cfg_target_above_config_limit;
output                                          cfg_p2p_track_cpl_to;
output                                          cfg_p2p_err_rpt_ctrl;
output                                          cfg_ras_reg_pf0_only; // When asserted, it blocks PFs access other than PF0 to RAS Extended Capability.
output                                          cfg_rasdes_reg_pf0_only; // When asserted, it blocks PFs access other than PF0 to RAS DES Extended Capability.



localparam            ARI_DEVICE_NUM = 1'b0;




output                                            cfg_nond0_vdm_block;
output                                            cfg_client0_block_new_tlp;
output                                            cfg_client1_block_new_tlp;
output                                            cfg_client2_block_new_tlp;

output                 cxl_vlsm_to_active;          //Force VLSM to Active State.
output                 cxl_vlsm_pm_enable;           //Enables Low Power mode entry.
output                 cxl_apn_bypass_enable;       // Alternate Protocol Bypass enable
output                 cxl_apn_sw_mode;             // Alternate Protocol Negotiation mode for SW device
output  [4:0]          cxl_max_num_retry;           //Maximum number of retry attempts before transitioning to Recovery.
output  [4:0]          cxl_max_num_reinit;          //Maximum number of transitions to recovery before aborting the retry sequence.
output  [15:0]         cxl_lrsm_timeout_threshold;  //Sets the threshold for the retry timeout. This indicates the number of flits which can be transmitted while waiting for a Retry.Ack before a retry timeout occurs.
output  [9:0]          cxl_crc_threshold;
output                 cxl_ras_uncorr_err;         //Fatal error message generation for CXL_FATAL_ERROR_CR
output reg [31:0]      cxl_fatal_error_reg;
output  [2:0]          cfg_optional_ohc;      // Optional controls to allow the insertion of OHCs in Flit Mode
output reg             cfg_tx_throttling;     // Tx Throttling Control Bit

output wire [31:0]      cfg_utility;                // utility register needs to be shadowed in power management block
input wire [31:0]       pm_cfg_utility;             // register shadowed in pm block is shadowed here so register isn't optimised away in synthesis
output [2:0]   cfg_dbi_func_bank_select;
output wire cfg_err_inj_wr_disable ;                // used to disable write access to error injection enable bits from the wire
output reg [6:0] cfg_tx_arb_control;
output reg       cfg_l0p_priority;                          // used to configure the L0P.Priority bit in the Link Management DLLP
output reg [2:0] cfg_l0p_dynamic_target_link_width;         // used to determine the link width targeted by FW 
output reg       cfg_direct_l0p_dynamic_link_width_change;  // used to indicate a l0p dynamic request
output reg       cfg_aspm_l0p_dynamic_disable;              // l0p dynamic HW autonomous width disable
output reg       cfg_l0p_dynamic_priority;                  // used to configure the L0P.Priority bit in the Link Management DLLP in dynamic l0p mode
output reg       l0p_dynamic_write;                         // indicate a write by FW in dynamic l0p register fields
input            rc_device;                                 // indicate root device
output reg cfg_flit_err_inj_latency;
output logic       cfg_prbs_en;                 // PRBS Loopback Enable. Need to be set before being set cfg_lpbk_en
output logic       clear_prbs_done;             // Clear PRBS Status regisers
output logic [3:0] cfg_prbs_lane_sel;           // PRBS lane select for status registers
// =============================================================================
// Output registers
// =============================================================================

wire                    cfg_pl_l1_exit_mode;
wire                    cfg_pl_l1_nowait_p1;
wire                    cfg_pl_l1_clk_sel;
wire                    cfg_p2nobeacon_enable;
wire                    cfg_pipe_optional_pclkchange_hs;
wire                    cfg_phy_perst_on_warm_reset;
reg                     cfg_upd_aspm_ctrl;
reg     [31:0]          pl_reg_data;
reg                     pl_reg_ack;
wire                    int_upd_aspm_ctrl;
wire    [7:0]           pl_reg_258,pl_reg_257, pl_reg_256, pl_reg_255; 
wire    [7:0]          pl_reg_262, pl_reg_261, pl_reg_260, pl_reg_259;
wire    [7:0]           pl_reg_3,  pl_reg_2,  pl_reg_1,  pl_reg_0;
reg     [7:0]           pl_reg_7,  pl_reg_6,  pl_reg_5,  pl_reg_4;
reg     [7:0]           pl_reg_11, pl_reg_10, pl_reg_9,  pl_reg_8;
reg     [7:0]           pl_reg_15, pl_reg_14, pl_reg_13, pl_reg_12;
reg     [7:0]           pl_reg_19, pl_reg_18, pl_reg_17, pl_reg_16;
reg     [7:0]           pl_reg_23, pl_reg_22, pl_reg_21, pl_reg_20;
reg     [7:0]           pl_reg_27, pl_reg_26, pl_reg_25, pl_reg_24;
reg     [7:0]           pl_reg_31, pl_reg_30, pl_reg_29, pl_reg_28;
reg     [7:0]           pl_reg_35, pl_reg_34, pl_reg_33, pl_reg_32;
wire    [7:0]           pl_reg_39, pl_reg_38, pl_reg_37;
reg     [7:0]           pl_reg_36;
reg     [7:0]           pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40;
reg     [7:0]           pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44;
wire    [7:0]           pl_reg_51, pl_reg_50, pl_reg_49, pl_reg_48;
wire    [7:0]           pl_reg_55, pl_reg_54, pl_reg_53, pl_reg_52;
wire    [7:0]           pl_reg_59, pl_reg_58, pl_reg_57, pl_reg_56;
wire    [7:0]           pl_reg_61, pl_reg_60;
reg     [7:0]           pl_reg_63, pl_reg_62;
reg     [7:0]           pl_reg_67, pl_reg_66, pl_reg_65, pl_reg_64;
reg     [7:0]           pl_reg_71, pl_reg_70, pl_reg_69, pl_reg_68;
reg     [7:0]           pl_reg_75, pl_reg_74, pl_reg_73, pl_reg_72;
reg     [7:0]           pl_reg_79, pl_reg_78, pl_reg_77, pl_reg_76;
reg     [7:0]           pl_reg_83, pl_reg_82, pl_reg_81, pl_reg_80;
reg     [7:0]           pl_reg_84, pl_reg_85, pl_reg_86, pl_reg_87;
reg     [7:0]           pl_reg_88, pl_reg_89, pl_reg_90, pl_reg_91;
reg     [7:0]           pl_reg_92, pl_reg_93, pl_reg_94, pl_reg_95;
reg     [7:0]           pl_reg_99, pl_reg_98, pl_reg_97, pl_reg_96;
reg     [7:0]           pl_reg_103, pl_reg_102, pl_reg_101, pl_reg_100;
reg     [7:0]           pl_reg_107, pl_reg_106, pl_reg_105, pl_reg_104;
reg     [7:0]           pl_reg_111, pl_reg_110, pl_reg_109, pl_reg_108;
reg     [7:0]           pl_reg_115, pl_reg_114, pl_reg_113, pl_reg_112;
reg     [7:0]           pl_reg_119, pl_reg_118, pl_reg_117, pl_reg_116;
reg     [7:0]           pl_reg_123, pl_reg_122, pl_reg_121, pl_reg_120;
reg     [7:0]           pl_reg_127, pl_reg_126, pl_reg_125, pl_reg_124;
reg     [7:0]           pl_reg_131, pl_reg_130, pl_reg_129, pl_reg_128;
reg     [7:0]           pl_reg_135, pl_reg_134, pl_reg_133, pl_reg_132;
reg     [7:0]           pl_reg_139, pl_reg_138, pl_reg_137, pl_reg_136;
reg     [7:0]           pl_reg_143, pl_reg_142, pl_reg_141, pl_reg_140;
reg     [7:0]           pl_reg_147, pl_reg_146, pl_reg_145, pl_reg_144;
reg     [7:0]           pl_reg_151, pl_reg_150, pl_reg_149, pl_reg_148;
reg     [7:0]           pl_reg_155, pl_reg_154, pl_reg_153, pl_reg_152;
reg     [7:0]           pl_reg_159, pl_reg_158, pl_reg_157, pl_reg_156;
reg     [7:0]           pl_reg_163, pl_reg_162, pl_reg_161, pl_reg_160;
reg     [7:0]           pl_reg_167, pl_reg_166, pl_reg_165, pl_reg_164;
reg     [7:0]           pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172;
wire    [7:0]           pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176;
reg     [7:0]           pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180;
wire    [7:0]           pl_reg_184, pl_reg_185, pl_reg_186, pl_reg_187;
reg     [7:0]           pl_reg_192;
logic   [7:0]           pl_reg_195;
wire    [7:0]           pl_reg_193, pl_reg_194;
reg     [7:0]           pl_g3r_193, pl_g3r_194;
reg     [7:0]           pl_g4r_193, pl_g4r_194;
reg     [7:0]           pl_g5r_193, pl_g5r_194;
reg     [7:0]           pl_g6r_193, pl_g6r_194;
wire    [1:0]           rate_shadow_sel;
reg     [7:0]           pl_reg_203, pl_reg_202, pl_reg_201, pl_reg_200;
reg     [7:0]           pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204;
wire    [7:0]           pl_reg_246_bcm36, pl_reg_245_bcm36, pl_reg_205_bcm36, pl_reg_204_bcm36;
// Utility Register
reg     [7:0]           pl_reg_250, pl_reg_249, pl_reg_248, pl_reg_247;
reg     [7:0]           pl_reg_254, pl_reg_253, pl_reg_252, pl_reg_251;
// EQ Control Register
wire    [7:0]           pl_reg_ec3, pl_reg_ec2, pl_reg_ec1, pl_reg_ec0;
reg     [7:0]           pl_g3r_ec3, pl_g3r_ec2, pl_g3r_ec1, pl_g3r_ec0;
reg     [7:0]           pl_g4r_ec3, pl_g4r_ec2, pl_g4r_ec1, pl_g4r_ec0;
reg     [7:0]           pl_g5r_ec3, pl_g5r_ec2, pl_g5r_ec1, pl_g5r_ec0;
reg     [7:0]           pl_g6r_ec3, pl_g6r_ec2, pl_g6r_ec1, pl_g6r_ec0;
// Direction Change Control Register
wire    [7:0]           pl_reg_dc2, pl_reg_dc1, pl_reg_dc0;
reg     [7:0]           pl_g3r_dc2, pl_g3r_dc1, pl_g3r_dc0;
reg     [7:0]           pl_g4r_dc2, pl_g4r_dc1, pl_g4r_dc0;
reg     [7:0]           pl_g5r_dc2, pl_g5r_dc1, pl_g5r_dc0;
reg     [7:0]           pl_g6r_dc2, pl_g6r_dc1, pl_g6r_dc0;
wire    [7:0]           pl_reg_dc3;
reg     [8:0]           pl_reg_mult_0;
reg     [7:0]           pl_reg_phyiop_3, pl_reg_phyiop_2, pl_reg_phyiop_1, pl_reg_phyiop_0;
reg     [7:0]           pl_reg_phyiop_ctrl2_3, pl_reg_phyiop_ctrl2_2, pl_reg_phyiop_ctrl2_1, pl_reg_phyiop_ctrl2_0;

reg     [7:0]          pl_reg_err_rsp_0;
reg     [7:0]          pl_reg_err_rsp_1;
reg     [7:0]          pl_reg_err_rsp_3;
wire    [7:0]           pl_reg_aoc_0;

reg     [7:0]           pl_reg_lflshctl_0;      // Link Reset Request Flush Control
reg     [7:0]           pl_reg_lflshctl_3;
reg     [7:0]           pl_reg_206;
reg     [7:0]           pl_reg_207;
reg     [7:0]           pl_reg_208,pl_reg_209,pl_reg_210,pl_reg_211;
reg     [7:0]           pl_reg_212,pl_reg_213,pl_reg_214,pl_reg_215;
reg     [7:0]           pl_reg_216,pl_reg_217,pl_reg_218,pl_reg_219;

wire      [0:0]         trgt_map_reg_id;        // Target Map address decode
wire      [31:0]        trgt_map_reg_data;      // Target Map read data
wire      [(6*NF)-1:0]  target_mem_map;
wire      [NF-1:0]      target_rom_map;
wire [ATU_CTRL_REG_ID_WD-1:0] atu_ctrl_reg_id;        // ATU address decode

wire      [15:0]                                cfg_err_resp;
wire                                            cfg_crs_sw_vis_en;
wire                                            cfg_auto_flush_en;
wire      [7:0]                                 cfg_auto_flush_timeout;
wire                                            cfg_link_timeout_en_n;
wire      [`LINK_TIMEOUT_PERIOD_WIDTH-1:0]      cfg_link_timeout_period;
wire [1:0]                                      cfg_ax_mstr_ordr_p_event_sel;
wire                                            cfg_ax_snp_en;
wire [`CX_NVC-1:0]                              cfg_ib_p_id_mng_ctrl;
wire      [3:0]                                 cfg_mstr_arcache_mode;
wire      [3:0]                                 cfg_mstr_awcache_mode;
wire      [3:0]                                 cfg_mstr_arcache_value;
wire      [3:0]                                 cfg_mstr_awcache_value;
wire      [1:0]                                 cfg_mstr_ardomain_mode;
wire      [1:0]                                 cfg_mstr_awdomain_mode;
wire      [1:0]                                 cfg_mstr_ardomain_value;
wire      [1:0]                                 cfg_mstr_awdomain_value;
wire                                            cfg_ax_mstr_zeroread_fw;
wire                                            cfg_memtype_value;
wire      [`FLT_Q_ADDR_WIDTH-3:0]               cfg_memtype_boundary;
wire      [61:0]                                int_cfg_memtype_boundary;

wire    [31:0]                                  app_ltr_latency;  // LTR upstream port component latency
wire                                            cdmpl2cfg_ltr_rq; // Port logic to PCIe configuration OR'ed LTR message requirement bits

reg     [15:0]          int_ack_latency_timer;
reg     [15:0]          int2_ack_latency_timer;
reg     [16:0]          int_replay_timer_value;
reg     [16:0]          int2_replay_timer_value;
wire    [5:0]           cfg_forced_link_state;
wire                    cfg_ts2_lid_deskew;
wire                    cfg_support_part_lanes_rxei_exit;
wire    [3:0]           cfg_forced_ltssm_cmd;

reg                     cfg_force_en;
wire                    cfg_other_msg_request;
wire    [22:0]          cfg_lane_skew;              // (PL) Transmit lane skew control (optional) for test equipment
wire                    cfg_drift_buffer_deskew_enable;
wire                    cfg_acknack_disable;
wire    [3:0]           cfg_imp_num_lanes;
wire                    cfg_dll_lnk_en;
wire    [3:0]           cfg_eidle_timer;
wire    [10:0]          cfg_skip_interval;
wire    [3:0]           cfg_link_rate;
wire   [12:0]           fc_timer_override_val;
wire                    fc_timer_override;
wire    [6:0]           int_replay_timer_add;
wire    [4:0]           replay_timer_add;
wire    [4:0]           replay_timer_add_int;
wire    [4:0]           acknak_timer_add;
wire                    cfg_fast_link_mode;
wire    [1:0]           cfg_fast_link_scaling_factor;
wire                    cfg_xmt_corrupt_crc;
reg                     read_pulse;
wire    [4:0]           gen3_replay_timer_add;
wire    [4:0]           gen12_replay_timer_add;
wire                    gen3_data_rate;
wire                    gen3_rate_entry_pulse;
wire                    gen3_rate_exit_pulse;
reg                     gen3_data_rate_d;
wire    [3:0]           ltr_reg_id; // LTR register space decode
reg     [31:0]          ltr_reg_data; // LTR read data
wire                    l1sub_reg_id;   //L1SUB register space decode
reg     [31:0]          l1sub_reg_data; //L1SUB read data
wire                    aux_clk_reg_id;   //L1SUB register space decode
wire    [31:0]          aux_clk_reg_data; //L1SUB read data

wire    [FS_LF_WD-1:0]       cfg_gen3_eq_fs_lf;                   // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]   cfg_gen3_eq_coef;                    // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]       cfg_gen4_eq_fs_lf;                   // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]   cfg_gen4_eq_coef;                    // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]       cfg_gen5_eq_fs_lf;                   // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]   cfg_gen5_eq_coef;                    // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]       cfg_gen6_eq_fs_lf;                   // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]   cfg_gen6_eq_coef;                    // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]       pl_reg_fs_lf;                // programmable FS and LF for equalization
wire    [31:0]               pl_reg_coef;                 // programmable coefficients for equalization for the preset index given in pl_reg_pseti
wire    [3:0]                pl_reg_pseti;                // programmable preset index for equalization coefficients table
wire  [PSET_COEF_ID_WD-1:0]  pl_reg_pset_coef_id;         // ID bits for gen 3 programmable Equalization preset to coefficients registers
wire                         pl_reg_violate_rules_prog_coef;     // asserted when any one of the Gen3 transmit coeffcients rules are violated.


reg  [(NVC*2)-1:0]   hdr_scale_p;              // The HdrScale field contains the scaling factor for headers of the indicated type
reg  [(NVC*2)-1:0]   data_scale_p;             // The DataScale field contains the scaling factor for payload data of the indicated type
reg  [(NVC*2)-1:0]   hdr_scale_np;             // The HdrScale field contains the scaling factor for headers of the indicated type
reg  [(NVC*2)-1:0]   data_scale_np;            // The DataScale field contains the scaling factor for payload data of the indicated type
reg  [(NVC*2)-1:0]   hdr_scale_cpl;            // The HdrScale field contains the scaling factor for headers of the indicated type
reg  [(NVC*2)-1:0]   data_scale_cpl;           // The DataScale field contains the scaling factor for payload data of the indicated type

wire    [31:0]          pl_reg_0x480;      // Gen4 Lane Margining 1 read data 0x480
wire    [31:0]          pl_reg_0x484;      // Gen4 Lane Margining 2 read data 0x484
wire    [31:0]          pl_reg_0x488;      // Gen5 Lane Margining 1 read data 0x488
wire    [31:0]          pl_reg_0x48C;      // Gen5 Lane Margining 2 read data 0x48C
wire    [31:0]          pl_reg_0x498;      // Gen5 Lane Margining 1 read data 0x498
wire    [31:0]          pl_reg_0x49C;      // Gen5 Lane Margining 2 read data 0x49C
wire    [31:0]          pl_reg_0x490;      // PIPE Related Register read data 0x490
wire    [7:0]           pl_reg_0x41C;      // VDM Traffic during non-D0 states
wire    [31:0]          pl_reg_0x548;      // CXL_VLSM_CR
wire    [31:0]          pl_reg_0x54C;      // CXL_LRSM_CSR
wire    [31:0]          pl_reg_0x550;      // CXL_LL_TIMER_CR
wire    [31:0]          pl_reg_0x554;      // CXL_FATAL_ERROR_CR
wire    [31:0]          pl_reg_0x558;      // CXL.cache/CXL.mem LinkLayerErrorInjection
wire    [31:0]          pl_reg_0x55C;      // CXL.io LinkLayer Error injection
wire    [31:0]          pl_reg_0x560;      // Flex Bus LogPHY Error injection
wire    [31:0]          pl_reg_0x564;      // CXL Viral LD-ID Status
wire    [31:0]          pl_reg_0x594;      // AXI Inbound Posted ID Management

logic   [31:0]          pl_reg_0x5AC;      // PRBS Test Control

// Registers declaration for AMBA:
// When a Msg/MsgD TLP is received in the PCIe link and the AXI Bridge is used,
// it is delivered to the application as an AXI write
// The application can program the address to be sent on the AXI bridge
// master aw interface (mstr_awaddr) for the Msg/MsgD tlps received
// in this register(cfg_aximstr_msg_addr_low, cfg_aximstr_msg_addr_high)
reg     [7:0]           pl_reg_234, pl_reg_233, pl_reg_232;
reg     [7:0]           pl_reg_238, pl_reg_237, pl_reg_236, pl_reg_235;
wire    [31:0]          cfg_aximstr_msg_addr_low;
wire    [31:0]          cfg_aximstr_msg_addr_high;

reg     [7:0] pl_reg_240, pl_reg_239;
reg     [7:0]           pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241;
//  cfg_clock_gating_ctrl
reg                     r_radm_clk_gating_en;
reg                     r_axi_clk_gating_en;

reg [15:0]              app_bus_dev_num_status; // Application Bus and Device Number Status
wire                    cfg_pl_wr_disable;


//These assignments will allow the release version numbers to be visible in the waveform received from customer directly.
//This will be used to quickly identify the exact version that the customer is using.
wire [31:0]             DWC_PCIE_IIP_RELEASE_VER_NUMBER;
assign DWC_PCIE_IIP_RELEASE_VER_NUMBER = `DWC_PCIE_IIP_RELEASE_VER_NUMBER;

wire [31:0]             DWC_PCIE_IIP_RELEASE_VER_TYPE; 
assign DWC_PCIE_IIP_RELEASE_VER_TYPE = `DWC_PCIE_IIP_RELEASE_VER_TYPE;


// Quasi-static pl_reg struct used with bcm36_nhs
typedef struct packed {
  logic [7:0] pl_reg_10;
  logic [7:0] pl_reg_16;
  logic [7:0] pl_reg_20;
  logic [7:0] pl_reg_21;
  logic [7:0] pl_reg_22;
  logic [7:0] pl_reg_23;
  logic [7:0] pl_reg_28;
  logic [7:0] pl_reg_29;
  logic [7:0] pl_reg_173;
  logic [7:0] pl_reg_174;
  logic [7:0] pl_reg_175;
  logic [7:0] pl_reg_30;
  logic [7:0] pl_reg_31;
  logic [7:0] pl_reg_32;
  logic [7:0] pl_reg_33;
  logic [7:0] pl_reg_34;
  logic [7:0] pl_reg_35;
  logic [7:0] pl_g3r_193;
} quasi_static_pl_reg;

quasi_static_pl_reg pl_reg_bcm36_nhs_s, pl_reg_bcm36_nhs_d; // Input and output of bcm36_nhs

assign pl_reg_bcm36_nhs_s = '{
  pl_reg_10 : pl_reg_10
  ,pl_reg_16  : pl_reg_16
  ,pl_reg_20  : pl_reg_20
  ,pl_reg_21  : pl_reg_21
  ,pl_reg_22  : pl_reg_22
  ,pl_reg_23  : pl_reg_23
  ,pl_reg_28  : pl_reg_28
  ,pl_reg_29  : pl_reg_29
  ,pl_reg_173 : pl_reg_173
  ,pl_reg_174 : pl_reg_174
  ,pl_reg_175 : pl_reg_175
  ,pl_reg_30  : pl_reg_30
  ,pl_reg_31  : pl_reg_31
  ,pl_reg_32  : pl_reg_32 
  ,pl_reg_33  : pl_reg_33
  ,pl_reg_34  : pl_reg_34
  ,pl_reg_35  : pl_reg_35
  ,pl_g3r_193 : pl_g3r_193
};

// core_clk destination domain: Quasi static registers -> registers configured only when LINK is NOT UP
DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(quasi_static_pl_reg)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_pl_reg (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (sticky_rst_n),
`endif // SYNTHESIS
  .data_s  (pl_reg_bcm36_nhs_s),
  .data_d  (pl_reg_bcm36_nhs_d)
);

// =============================================================================
// Internal IP Core Registers
// =============================================================================
localparam ID_0x480 = 158;
localparam ID_0x484 = 159;
localparam ID_0x500 = 160;
localparam ID_0x470 = 164;
localparam ID_0x474 = 165;
localparam ID_0x490 = 166;
localparam ID_0x260 = 167;
localparam ID_0x264 = 168;
// Number of register locations consumed by the DTIM
localparam DTIM_REG_RANGE = 20;
// DTIM register address offsets
localparam ID_0x3B0 = 169; // DTIM CTRL0
localparam ID_0x3B4 = 170; // DTIM CTRL1
localparam ID_0x3B8 = 171; // DTIM CTRL2
localparam ID_0x3BC = 172; // DTIM CTRL3
localparam ID_0x3C0 = 173; // DTIM CTRL4
localparam ID_0x3C4 = 174; // DTIM CTRL5
localparam ID_0x3C8 = 175; // Reserved
localparam ID_0x3CC = 176; // DTIM INT_STATUS
localparam ID_0x3D0 = 177; // DTIM INT_EN
localparam ID_0x3D4 = 178; // DTIM INT_CLR
localparam ID_0x3D8 = 179; // DTIM INT_MSK
localparam ID_0x3DC = 180; // DTIM MSI_ADDR_UPR
localparam ID_0x3E0 = 181; // DTIM MSI_ADDR_LWR
localparam ID_0x3E4 = 182; // DTIM MSI_DATA
localparam ID_0x3E8 = 183; // DTIM ERR_LOG0
localparam ID_0x3EC = 184; // DTIM ERR_LOG1
localparam ID_0x3F0 = 185; // DTIM ERR_LOG2
localparam ID_0x3F4 = 186; // DTIM RSVD
localparam ID_0x3F8 = 187; // DTIM RSVD
localparam ID_0x3FC = 188; // DTIM DIAG
localparam ID_0x520 = 189; // CCIX VDM VID
localparam ID_0x448 = 190; // POWERDOWN_CTRL_STATUS
localparam ID_0x44C = 114; // PHY_INTEROP_CTRL_2
localparam ID_0x410 = 191; // APP_BUS_DEV_NUM_STATUS
localparam ID_0x41C = 192; // non-D0 VDM
localparam ID_0x524 = 193; // FOM_COEF_LENGTH
localparam ID_0x528 = 194; // FOM_COEF_LANE0_1
localparam ID_0x52C = 195; // FOM_COEF_LANE2_3
localparam ID_0x530 = 196; // FOM_COEF_LANE4_5
localparam ID_0x534 = 197; // FOM_COEF_LANE6_7
localparam ID_0x538 = 198; // FOM_COEF_LANE8_9
localparam ID_0x53C = 199; // FOM_COEF_LANE10_11
localparam ID_0x540 = 200; // FOM_COEF_LANE12_13
localparam ID_0x544 = 201; // FOM_COEF_LANE14_15
localparam ID_0x548 = 202; // CXL : CXL_LL_CREDIT_CR
localparam ID_0x54C = 203; // CXL : CXL_LRSM_CSR
localparam ID_0x550 = 204; // CXL : CXL_LL_TIMER_CR
localparam ID_0x554 = 205; // CXL : CXL_FATAL_ERROR_CR
localparam ID_0x558 = 206; // CXL : CXL_CACHE_MEM_LL_EI
localparam ID_0x55C = 207; // CXL : CXL_IO_LL_EI
localparam ID_0x560 = 208; // CXL : CXL_FB_LOGPHY_EI
localparam ID_0x564 = 209; // CXL : CXL_VIRAL_LDID
localparam ID_0x570 = 210; // ECAM lower base address
localparam ID_0x574 = 211; // ECAM upper base address
localparam ID_0x578 = 212; // ECAM control
localparam ID_0x488 = 213; // GEN5_LANE_MARGINING_1
localparam ID_0x48C = 214; // GEN5_LANE_MARGINING_2
localparam ID_0x580 = 215; // UTILITY
localparam ID_0x588 = 216; // PM_UTILITY
// DBI Function Bank Control register - offset
localparam ID_0x57C = 217; // DBI Function Bank Control
localparam ID_0x584 = 218; // AXI-G control
localparam ID_0x58C = 219; // IDE
localparam ID_0x590 = 220; // CXL_IDE_EINJ
localparam ID_0x498 = 221; // GEN6_LANE_MARGINING_1
localparam ID_0x49C = 222; // GEN6_LANE_MARGINING_2
localparam ID_0x494 = 223; // Port Logic Control 2
localparam ID_0x594 = 224; // AXI Inbound Posted ID Management Control
localparam ID_0x5A8 = 225; //RX RETRY BUFFER PORT LOGIC CONTROl
localparam ID_0x5AC = 226; // PRBS Loopback test Control
localparam ID_0x598 = 227; // CXL_MLD_MAX_FUNC_NUM_0
localparam ID_0x59C = 228; // CXL_MLD_MAX_FUNC_NUM_1
localparam ID_0x5A0 = 229; // CXL_MLD_MAX_FUNC_NUM_2
localparam ID_0x5A4 = 230; // CXL_MLD_MAX_FUNC_NUM_3
localparam ID_0x23C = 231; // AXI MISC Control 1 Reg
localparam MAX_ID   = 231 ; 
localparam POWERDOWN_CTRL_STATUS_OFF    = 12'h448;
localparam [11:0] PHY_INTEROP_CTRL_2_OFF= 12'h44C;
localparam PL_APP_BUS_DEV_NUM_STATUS_OFF= 12'h410;
localparam [11:0] DBI_FUNC_BANK_CTRL_OFF = 12'h57C;
localparam [11:0] UTILITY_OFF       = 12'h580;
localparam [11:0] PM_UTILITY_OFF        = 12'h588;
localparam [11:0] PL_CTRL2_OFF          = 12'h494;
localparam [11:0] IB_P_ID_MNG_CTRL_OFF  = 12'h594;
localparam [11:0] RX_RETRY_BUFFER_PL_CTRL = 12'h5A8;
localparam [11:0] PRBS_LOOPBACK_TEST_REG_OFF = 12'h5AC;


localparam [11:0] CXL_VLSM_CR         = 12'h548; // PL offset for CXL_VLSM_CR
localparam [11:0] CXL_LRSM_CSR        = 12'h54C; // PL offset for CXL_LRSM_CSR
localparam [11:0] CXL_LL_TIMER_CR     = 12'h550; // PL offset for CXL_LL_TIMER_CR
localparam [11:0] CXL_FATAL_ERROR_CR  = 12'h554; // PL offset for CXL_FATAL_ERROR_CR
localparam [11:0] CXL_CACHE_MEM_LL_EI  = 12'h558; // PL offset for CXL.cache/CXL.mem LinkLayerErrorInjection
localparam [11:0] CXL_IO_LL_EI         = 12'h55C; // PL offset for CXL.io LinkLayer Error injection
localparam [11:0] CXL_FB_LOGPHY_EI     = 12'h560; // PL offset for Flex Bus LogPHY Error injection
localparam [11:0] CXL_VIRAL_LDID       = 12'h564; // PL offset for CXL Viral LD-ID
logic [31:0]  dbi_func_bank_control;
logic  [2:0]  cfg_dbi_func_bank_select;

reg     [MAX_ID-1:0]    int_pl_reg_id;
wire    [MAX_ID-1:0]    pl_reg_id;
reg pl_reg_sel_d;
reg pl_reg_sel_dd;

assign pl_reg_id    = int_pl_reg_id;
assign pl_reg_pset_coef_id =  {int_pl_reg_id[105], int_pl_reg_id[103:101]};


assign atu_ctrl_reg_id = {int_pl_reg_id[152], int_pl_reg_id[136:128]};
assign trgt_map_reg_id = {int_pl_reg_id[71]};
assign ltr_reg_id = int_pl_reg_id[140:137]; // LTR register decode
assign l1sub_reg_id = int_pl_reg_id[142]; // L1SUB register decode
assign aux_clk_reg_id = int_pl_reg_id[141]; // L1SUB register decode

// int_pl_reg_id register enable logic
wire  int_pl_reg_id_en;
assign int_pl_reg_id_en = pl_reg_sel | pl_reg_sel_d;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n)
        int_pl_reg_id    <= #TP 0;
    else begin
        int_pl_reg_id[0] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h000) >> 2))) : int_pl_reg_id[0];
        int_pl_reg_id[1] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h004) >> 2))) : int_pl_reg_id[1];
        int_pl_reg_id[2] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h008) >> 2))) : int_pl_reg_id[2];
        int_pl_reg_id[3] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h00C) >> 2))) : int_pl_reg_id[3];
        int_pl_reg_id[4] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h010) >> 2))) : int_pl_reg_id[4];
        int_pl_reg_id[5] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h014) >> 2))) : int_pl_reg_id[5];
        int_pl_reg_id[6] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h018) >> 2))) : int_pl_reg_id[6];
        int_pl_reg_id[7] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h01C) >> 2))) : int_pl_reg_id[7];
        int_pl_reg_id[8] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h020) >> 2))) : int_pl_reg_id[8];
        int_pl_reg_id[9] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h024) >> 2))) : int_pl_reg_id[9];
        int_pl_reg_id[10]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h028) >> 2))) : int_pl_reg_id[10];
        int_pl_reg_id[11]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h02C) >> 2))) : int_pl_reg_id[11];
        int_pl_reg_id[12]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h030) >> 2))) : int_pl_reg_id[12];
        int_pl_reg_id[13]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h034) >> 2))) : int_pl_reg_id[13];
        int_pl_reg_id[14]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h038) >> 2))) : int_pl_reg_id[14];
        int_pl_reg_id[15]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h03C) >> 2))) : int_pl_reg_id[15];
        int_pl_reg_id[16]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h040) >> 2))) : int_pl_reg_id[16];
        int_pl_reg_id[17]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h044) >> 2))) : int_pl_reg_id[17];
        int_pl_reg_id[18]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h048) >> 2))) : int_pl_reg_id[18];
        int_pl_reg_id[19]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h04C) >> 2))) : int_pl_reg_id[19];
        int_pl_reg_id[20]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h050) >> 2))) : int_pl_reg_id[20];
        int_pl_reg_id[23:21]<= #TP 3'd0;
        int_pl_reg_id[26:24]<= #TP 3'd0;
        int_pl_reg_id[29:27]<= #TP 3'd0;
        int_pl_reg_id[32:30]<= #TP 3'd0;
        int_pl_reg_id[35:33]<= #TP 3'd0;
        int_pl_reg_id[38:36]<= #TP 3'd0;
        int_pl_reg_id[41:39]<= #TP 3'd0;
        int_pl_reg_id[42]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h0A8) >> 2))) : int_pl_reg_id[42];
        int_pl_reg_id[43]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h0AC) >> 2))) : int_pl_reg_id[43];
        int_pl_reg_id[44]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h0B0) >> 2))) : int_pl_reg_id[44];
        int_pl_reg_id[47:45]<= #TP 3'd0;
        int_pl_reg_id[50:48]<= #TP 3'd0;
        int_pl_reg_id[53:51]<= #TP 3'd0;
        int_pl_reg_id[56:54]<= #TP 3'd0;
        int_pl_reg_id[59:57]<= #TP 3'd0;
        int_pl_reg_id[62:60]<= #TP 3'd0;
        int_pl_reg_id[65:63]<= #TP 3'd0;
        int_pl_reg_id[66]<= #TP 1'b0;
        int_pl_reg_id[67]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h10C) >> 2))) : int_pl_reg_id[67];
        int_pl_reg_id[68]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h110) >> 2))) : int_pl_reg_id[68];
        int_pl_reg_id[69]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h114) >> 2))) : int_pl_reg_id[69];
        int_pl_reg_id[70]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h118) >> 2))) : int_pl_reg_id[70];
        int_pl_reg_id[71]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h11C) >> 2)) ) : int_pl_reg_id[71];
        int_pl_reg_id[98:72]<= #TP 27'd0;
        int_pl_reg_id[99]<= #TP 0; // unused addresses
        int_pl_reg_id[100]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h190) >> 2))) : int_pl_reg_id[100];
        int_pl_reg_id[101]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h194) >> 2))) : int_pl_reg_id[101];
        int_pl_reg_id[102]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h198) >> 2))) : int_pl_reg_id[102];
        int_pl_reg_id[103]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h19c) >> 2))) : int_pl_reg_id[103];
        int_pl_reg_id[105]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h1a4) >> 2))) : int_pl_reg_id[105];
        int_pl_reg_id[104]<= #TP 1'b0;
        // int_pl_reg_id[105] is assigned above
        int_pl_reg_id[106]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h1a8) >> 2))) : int_pl_reg_id[106];
        int_pl_reg_id[107]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h1ac) >> 2))) : int_pl_reg_id[107];
        int_pl_reg_id[108] <= #TP 0; // unused addresses

    int_pl_reg_id[109] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1b4) >> 2))) : int_pl_reg_id[109];

    int_pl_reg_id[110]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1b8) >> 2))) : int_pl_reg_id[110];
    int_pl_reg_id[111]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1bc) >> 2))) : int_pl_reg_id[111];
    int_pl_reg_id[112]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1c0) >> 2))) : int_pl_reg_id[112];
    int_pl_reg_id[113]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1c4) >> 2))) : int_pl_reg_id[113];
    int_pl_reg_id[ID_0x44C]<= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PHY_INTEROP_CTRL_2_OFF) >> 2))) : int_pl_reg_id[ID_0x44C];
        // Link Reset Request Flush Control
        int_pl_reg_id[115]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1cc) >> 2))) : int_pl_reg_id[115];
        // Link Timeout
        int_pl_reg_id[117]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1d4) >> 2))) : int_pl_reg_id[117];
        // AMBA Error Response
        int_pl_reg_id[116] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1d0) >> 2))) : int_pl_reg_id[116];
        int_pl_reg_id[118] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1d8) >> 2))) : int_pl_reg_id[118];
        int_pl_reg_id[119] <= #TP 0;  // unused address
       int_pl_reg_id[119] <= #TP  int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1dc) >> 2))) : int_pl_reg_id[119];
        int_pl_reg_id[120]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1e0) >> 2))) : int_pl_reg_id[120];
        int_pl_reg_id[121]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1e4) >> 2))) : int_pl_reg_id[121];
        int_pl_reg_id[122]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1e8) >> 2))) : int_pl_reg_id[122];
        int_pl_reg_id[124]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1f0) >> 2))) : int_pl_reg_id[124];
        int_pl_reg_id[125]     <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1f4) >> 2))) : int_pl_reg_id[125];
        int_pl_reg_id[123]     <= #TP 0; // unused addresses
        int_pl_reg_id[126] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1f8) >> 2)) ) : int_pl_reg_id[126];
        int_pl_reg_id[127] <= #TP int_pl_reg_id_en ? (pl_reg_sel &(lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1fc) >> 2)) ) : int_pl_reg_id[127];
        int_pl_reg_id[128]<= #TP pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h200) >> 2));
        int_pl_reg_id[136:129]<= #TP 8'd0;

        int_pl_reg_id[137]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h430) >> 2))) : int_pl_reg_id[137];
        int_pl_reg_id[138]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h434) >> 2))) : int_pl_reg_id[138];
        int_pl_reg_id[139]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h438) >> 2))) : int_pl_reg_id[139];
        int_pl_reg_id[140]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h43C) >> 2))) : int_pl_reg_id[140];
        int_pl_reg_id[141]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h440) >> 2))) : int_pl_reg_id[141];
        int_pl_reg_id[142]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h444) >> 2))) : int_pl_reg_id[142];
        int_pl_reg_id[147:143]<= #TP 5'd0;
        int_pl_reg_id[150:148]<= #TP 3'd0;
        int_pl_reg_id[151] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h1c8) >> 2))) : int_pl_reg_id[151];
        int_pl_reg_id[152] <= #TP 1'd0;

        int_pl_reg_id[153] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 9'h18c) >> 2))) : int_pl_reg_id[153];
        int_pl_reg_id[157:154] <= #TP 4'b0;
        int_pl_reg_id[ID_0x480]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h480) >> 2))) : int_pl_reg_id[ID_0x480];
        int_pl_reg_id[ID_0x484]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h484) >> 2))) : int_pl_reg_id[ID_0x484];
        int_pl_reg_id[ID_0x488]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h488) >> 2))) : int_pl_reg_id[ID_0x488];
        int_pl_reg_id[ID_0x48C]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h48C) >> 2))) : int_pl_reg_id[ID_0x48C];
        int_pl_reg_id[ID_0x498]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h498) >> 2))) : int_pl_reg_id[ID_0x498];
        int_pl_reg_id[ID_0x49C]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h49C) >> 2))) : int_pl_reg_id[ID_0x49C];
        int_pl_reg_id[ID_0x490]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h490) >> 2))) : int_pl_reg_id[ID_0x490];
        int_pl_reg_id[ID_0x500] <= #TP 1'b0;
        int_pl_reg_id[163:161] <= #TP 3'b000;
        int_pl_reg_id[ID_0x474:ID_0x470]<= #TP 2'b00;
        int_pl_reg_id[ID_0x264:ID_0x260] <= #TP 2'b00;
        int_pl_reg_id[ID_0x520]<= #TP 1'b0;
        int_pl_reg_id[ID_0x544:ID_0x524]<= #TP {9{1'b0}};
        int_pl_reg_id[ID_0x41C]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + 12'h41C) >> 2))) : int_pl_reg_id[ID_0x41C];
        int_pl_reg_id[ID_0x3FC:ID_0x3B0] <= #TP {DTIM_REG_RANGE{1'b0}};
        int_pl_reg_id[ID_0x448] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + POWERDOWN_CTRL_STATUS_OFF) >> 2)))
                                                        : int_pl_reg_id[ID_0x448];
        int_pl_reg_id[ID_0x410] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PL_APP_BUS_DEV_NUM_STATUS_OFF) >> 2)))
                                                        : int_pl_reg_id[ID_0x410];
        int_pl_reg_id[ID_0x548]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_VLSM_CR) >> 2))) : int_pl_reg_id[ID_0x548];
        int_pl_reg_id[ID_0x54C]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_LRSM_CSR) >> 2))) : int_pl_reg_id[ID_0x54C];
        int_pl_reg_id[ID_0x550]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_LL_TIMER_CR) >> 2))) : int_pl_reg_id[ID_0x550];
        int_pl_reg_id[ID_0x554]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_FATAL_ERROR_CR) >> 2))) : int_pl_reg_id[ID_0x554];
        int_pl_reg_id[ID_0x558]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_CACHE_MEM_LL_EI) >> 2))) : int_pl_reg_id[ID_0x558];
        int_pl_reg_id[ID_0x55C]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_IO_LL_EI) >> 2))) : int_pl_reg_id[ID_0x55C];
        int_pl_reg_id[ID_0x560]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_FB_LOGPHY_EI) >> 2))) : int_pl_reg_id[ID_0x560];
        int_pl_reg_id[ID_0x564]<= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + CXL_VIRAL_LDID) >> 2))) : int_pl_reg_id[ID_0x564];
        int_pl_reg_id[ID_0x570]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x574]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x578]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x57C]  <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + DBI_FUNC_BANK_CTRL_OFF) >> 2))) : int_pl_reg_id[ID_0x57C];
        int_pl_reg_id[ID_0x580] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + UTILITY_OFF) >> 2))) : int_pl_reg_id[ID_0x580];
        int_pl_reg_id[ID_0x588] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PM_UTILITY_OFF) >> 2))) : int_pl_reg_id[ID_0x588];
        int_pl_reg_id[ID_0x584]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x58C] <= #TP 1'b0;
        int_pl_reg_id[ID_0x590]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x494] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PL_CTRL2_OFF) >> 2))) : int_pl_reg_id[ID_0x494];
        int_pl_reg_id[ID_0x594]  <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + IB_P_ID_MNG_CTRL_OFF) >> 2))) : int_pl_reg_id[ID_0x594];
         int_pl_reg_id[ID_0x5A8] <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + RX_RETRY_BUFFER_PL_CTRL) >> 2))) : int_pl_reg_id[ID_0x5A8];
        int_pl_reg_id[ID_0x5AC]  <= #TP int_pl_reg_id_en ? (pl_reg_sel & (lbc_cdm_addr[11:2] == ((`CFG_PL_REG + PRBS_LOOPBACK_TEST_REG_OFF) >> 2))) : int_pl_reg_id[ID_0x5AC];
        int_pl_reg_id[ID_0x598]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x59C]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x5A0]  <= #TP 1'b0;
        int_pl_reg_id[ID_0x5A4]  <= #TP 1'b0;
    end
end

// =============================================================================
// Core Register Read Operation
// =============================================================================

// Register muxed data back to host
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        pl_reg_data <= #TP 32'b0;
    else
        if (read_pulse) begin


            unique case (1'b1)

                pl_reg_id[0]: pl_reg_data   <= #TP {pl_reg_3,  pl_reg_2,  pl_reg_1,  pl_reg_0};
                pl_reg_id[1]: pl_reg_data   <= #TP {pl_reg_7,  pl_reg_6,  pl_reg_5,  pl_reg_4};
                pl_reg_id[2]: pl_reg_data   <= #TP {pl_reg_11, pl_reg_10, pl_reg_9,  pl_reg_8};
                pl_reg_id[3]: pl_reg_data   <= #TP {pl_reg_15, pl_reg_14, pl_reg_13, pl_reg_12};
                pl_reg_id[4]: pl_reg_data   <= #TP {pl_reg_19, pl_reg_18, pl_reg_17, pl_reg_16};
                pl_reg_id[5]: pl_reg_data   <= #TP {pl_reg_23, pl_reg_22, pl_reg_21, pl_reg_20};
                pl_reg_id[6]: pl_reg_data   <= #TP {pl_reg_27, pl_reg_26, pl_reg_25, pl_reg_24};
                pl_reg_id[7]: pl_reg_data   <= #TP {pl_reg_31, pl_reg_30, pl_reg_29, pl_reg_28};
                pl_reg_id[8]: pl_reg_data   <= #TP {pl_reg_35, pl_reg_34, pl_reg_33, pl_reg_32};
                pl_reg_id[9]: pl_reg_data   <= #TP {pl_reg_39, pl_reg_38, pl_reg_37, pl_reg_36};
//Do not cover the debug registers

                pl_reg_id[10]: pl_reg_data  <= #TP {pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40};
                pl_reg_id[11]: pl_reg_data  <= #TP {pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44};
                pl_reg_id[12]: pl_reg_data  <= #TP {pl_reg_51, pl_reg_50, pl_reg_49, pl_reg_48};
                pl_reg_id[13]: pl_reg_data  <= #TP {pl_reg_55, pl_reg_54, pl_reg_53, pl_reg_52};
                pl_reg_id[14]: pl_reg_data  <= #TP {pl_reg_59, pl_reg_58, pl_reg_57, pl_reg_56};
                pl_reg_id[15]: pl_reg_data  <= #TP {pl_reg_63, pl_reg_62, pl_reg_61, pl_reg_60};
                pl_reg_id[16]: pl_reg_data  <= #TP {pl_reg_67, pl_reg_66, pl_reg_65, pl_reg_64};
                pl_reg_id[17]: pl_reg_data  <= #TP {pl_reg_71, pl_reg_70, pl_reg_69, pl_reg_68};
            // VC_0
                pl_reg_id[18]: pl_reg_data  <= #TP {pl_reg_75, pl_reg_74, pl_reg_73, pl_reg_72};
                pl_reg_id[19]: pl_reg_data  <= #TP {pl_reg_79, pl_reg_78, pl_reg_77, pl_reg_76};
                pl_reg_id[20]: pl_reg_data  <= #TP {pl_reg_83, pl_reg_82, pl_reg_81, pl_reg_80};
            // VC_0
                pl_reg_id[67]: pl_reg_data  <= #TP {pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172};
                pl_reg_id[68]: pl_reg_data  <= #TP {pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176};
                pl_reg_id[69]: pl_reg_data  <= #TP {pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180};
                pl_reg_id[70]: pl_reg_data  <= #TP {pl_reg_187, pl_reg_186, pl_reg_185, pl_reg_184};
                pl_reg_id[100]: pl_reg_data <= #TP {pl_reg_195, pl_reg_194, pl_reg_193, pl_reg_192};
                pl_reg_id[101]: pl_reg_data <= #TP {20'h00000, pl_reg_fs_lf}; // programmed LF and DS
                pl_reg_id[102]: pl_reg_data <= #TP pl_reg_coef;               // programmed coefficients
                pl_reg_id[103]: pl_reg_data <= #TP {28'h0, pl_reg_pseti};               // programmedpreset index
                pl_reg_id[105]: pl_reg_data <= #TP {31'h0, pl_reg_violate_rules_prog_coef};  // Gen3 Equalization programmed transmit coefficients rule violation indication
                pl_reg_id[106]: pl_reg_data <= #TP {pl_reg_ec3, pl_reg_ec2, pl_reg_ec1, pl_reg_ec0};
                pl_reg_id[107]: pl_reg_data <= #TP {pl_reg_dc3, pl_reg_dc2, pl_reg_dc1, pl_reg_dc0};
                pl_reg_id[109]: pl_reg_data <= #TP { 16'h0, pl_reg_240, pl_reg_239};
                pl_reg_id[110]: pl_reg_data <= #TP {pl_reg_203, pl_reg_202, pl_reg_201, pl_reg_200};
                pl_reg_id[111]: pl_reg_data <= #TP {pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204};
                pl_reg_id[112]: pl_reg_data <= #TP {23'h0, pl_reg_mult_0};
                pl_reg_id[113]: pl_reg_data <= #TP {pl_reg_phyiop_3, pl_reg_phyiop_2, pl_reg_phyiop_1, pl_reg_phyiop_0};
                pl_reg_id[ID_0x44C]: pl_reg_data <= #TP {pl_reg_phyiop_ctrl2_3, pl_reg_phyiop_ctrl2_2, pl_reg_phyiop_ctrl2_1, pl_reg_phyiop_ctrl2_0};
                // Link Reset Request Flush Control
                pl_reg_id[115]: pl_reg_data <= #TP {pl_reg_lflshctl_3, 16'h0, pl_reg_lflshctl_0};
                // Link Timeout
                pl_reg_id[117]: pl_reg_data <= #TP {16'h0, pl_reg_207, pl_reg_206};
                // Ordering Control
                pl_reg_id[118]: pl_reg_data <= #TP {24'h0, pl_reg_aoc_0};
                // AMBA Error Response Control
                pl_reg_id[116]: pl_reg_data <= #TP {pl_reg_err_rsp_3, 8'd0, pl_reg_err_rsp_1, pl_reg_err_rsp_0};
               pl_reg_id[120]: pl_reg_data <= #TP {pl_reg_211,pl_reg_210,pl_reg_209, pl_reg_208};
               pl_reg_id[121]: pl_reg_data <= #TP {pl_reg_215,pl_reg_214,pl_reg_213, pl_reg_212};
               pl_reg_id[122]: pl_reg_data <= #TP {pl_reg_219,pl_reg_218,pl_reg_217, pl_reg_216};
               pl_reg_id[124]: pl_reg_data <= #TP {pl_reg_234, pl_reg_233, pl_reg_232, 8'd0};
               pl_reg_id[125]: pl_reg_data <= #TP {pl_reg_238, pl_reg_237, pl_reg_236, pl_reg_235};
               pl_reg_id[126]: pl_reg_data <= #TP `DWC_PCIE_IIP_RELEASE_VER_NUMBER;
               pl_reg_id[127]: pl_reg_data <= #TP `DWC_PCIE_IIP_RELEASE_VER_TYPE;
             |atu_ctrl_reg_id: pl_reg_data  <= #TP 32'hFFFF_FFFF;
             |trgt_map_reg_id: pl_reg_data  <= #TP trgt_map_reg_data;
             |ltr_reg_id: pl_reg_data       <= #TP ltr_reg_data;
             |l1sub_reg_id: pl_reg_data     <= #TP l1sub_reg_data;

             aux_clk_reg_id: pl_reg_data     <= #TP aux_clk_reg_data;
             pl_reg_id[151]: pl_reg_data <= #TP {pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241};
             pl_reg_id[153]: pl_reg_data <= #TP {16'h0, 8'h0, 5'h0, 1'b0 ,r_axi_clk_gating_en, r_radm_clk_gating_en};
             pl_reg_id[ID_0x480]: pl_reg_data <= #TP pl_reg_0x480;
             pl_reg_id[ID_0x484]: pl_reg_data <= #TP pl_reg_0x484;
             pl_reg_id[ID_0x488]: pl_reg_data <= #TP pl_reg_0x488;
             pl_reg_id[ID_0x48C]: pl_reg_data <= #TP pl_reg_0x48C;
             pl_reg_id[ID_0x498]: pl_reg_data <= #TP pl_reg_0x498;
             pl_reg_id[ID_0x49C]: pl_reg_data <= #TP pl_reg_0x49C;
             pl_reg_id[ID_0x490]: pl_reg_data <= #TP pl_reg_0x490;
             pl_reg_id[ID_0x548]: pl_reg_data <= #TP pl_reg_0x548;
             pl_reg_id[ID_0x54C]: pl_reg_data <= #TP pl_reg_0x54C;
             pl_reg_id[ID_0x550]: pl_reg_data <= #TP pl_reg_0x550;
             pl_reg_id[ID_0x554]: pl_reg_data <= #TP pl_reg_0x554;
             pl_reg_id[ID_0x558]: pl_reg_data <= #TP pl_reg_0x558;
             pl_reg_id[ID_0x55C]: pl_reg_data <= #TP pl_reg_0x55C;
             pl_reg_id[ID_0x560]: pl_reg_data <= #TP pl_reg_0x560;
             pl_reg_id[ID_0x564]: pl_reg_data <= #TP pl_reg_0x564;
             pl_reg_id[ID_0x41C]: pl_reg_data <= #TP {24'b0, pl_reg_0x41C};
             pl_reg_id[ID_0x448] : pl_reg_data <= #TP {20'b0, int_powerdown_status};
             pl_reg_id[ID_0x410] : pl_reg_data <= #TP {16'b0, app_bus_dev_num_status};


             pl_reg_id[ID_0x57C] : pl_reg_data <= #TP dbi_func_bank_control; // read back DBI Function Bank Control register
             pl_reg_id[ID_0x580] : pl_reg_data <= #TP  {pl_reg_250, pl_reg_249, pl_reg_248, pl_reg_247};
             pl_reg_id[ID_0x588] : pl_reg_data <= #TP  {pl_reg_254, pl_reg_253, pl_reg_252, pl_reg_251};


             pl_reg_id[ID_0x494] : pl_reg_data <= #TP  {pl_reg_258, pl_reg_257, pl_reg_256, pl_reg_255};
             pl_reg_id[ID_0x594] : pl_reg_data <= #TP pl_reg_0x594;
             pl_reg_id[ID_0x5A8] : pl_reg_data <= #TP  {pl_reg_262, pl_reg_261, pl_reg_260, pl_reg_259};
             pl_reg_id[ID_0x5AC] : pl_reg_data <= #TP pl_reg_0x5AC;
                default:  pl_reg_data   <= #TP `PCIE_UNUSED_RESPONSE;
            endcase
        end
end


// ack one cycle after lbus_strobe is asserted
// it could be delayed more in reality
reg     [3:0]   write_pulse;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        pl_reg_ack      <= #TP 0;
        pl_reg_sel_d    <= #TP 0;
        pl_reg_sel_dd   <= #TP 0;
        write_pulse     <= #TP 0;
        read_pulse      <= #TP 0;
    end else begin
        if (|atu_ctrl_reg_id)
          pl_reg_ack      <= #TP pl_reg_sel & pl_reg_sel_d & pl_reg_sel_dd;
        else 
        pl_reg_ack      <= #TP pl_reg_sel & pl_reg_sel_d;
        pl_reg_sel_d    <= #TP  pl_reg_sel;
        pl_reg_sel_dd   <= #TP  pl_reg_sel_d;
        // generation of write pulse is gated by the cfg_pl_wr_disable signal which defaults to CX_PL_WIRE_WR_DISABLE parameter
        write_pulse     <= #TP (pl_reg_sel & ~pl_reg_sel_d) ? lbc_cdm_wr & {4{~cfg_pl_wr_disable|lbc_cdm_dbi}}: 4'b0;
        if (|atu_ctrl_reg_id)
        read_pulse      <= #TP  pl_reg_sel_d & ~pl_reg_sel_dd & (~|lbc_cdm_wr);
        else
        read_pulse      <= #TP  pl_reg_sel & ~pl_reg_sel_d & (~|lbc_cdm_wr);
    end
end

// =============================================================================
// Core Register Write Operation
// =============================================================================
//----------------------------------------------------------------------------------------
// Port Logic Control 2 Register
// cpl_reg_id       - 223
// Length           - 4 bytes
// Offset           - 'h494
// Default value    - 0
// Core registers   - {pl_reg_258, pl_reg_257, pl_reg_256, pl_reg_255}
// ---------------------------------------------------------------------------------------
assign pl_reg_255 =  { cfg_l0p_dynamic_priority 
                                       ,cfg_aspm_l0p_dynamic_disable
                                       ,cfg_direct_l0p_dynamic_link_width_change
                                       ,cfg_l0p_dynamic_target_link_width
  ,cfg_flit_err_inj_latency
 ,cfg_l0p_priority
                     };
assign pl_reg_256 = {1'b0, cfg_tx_arb_control};
assign pl_reg_257 = 8'b0;
assign pl_reg_258 = 8'b0;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      cfg_flit_err_inj_latency <= #TP 1'b0;
    end
    else begin
      cfg_flit_err_inj_latency <= #TP (write_pulse[0] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[1] : cfg_flit_err_inj_latency;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      // Disable FC Merge, P Limit = 4, NP Limit = 7, CPL Limit = 4, 
      cfg_tx_arb_control                        <= #TP 7'b0101110;
    end
    else begin
      cfg_tx_arb_control                        <= #TP (write_pulse[1] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[14:8] : cfg_tx_arb_control;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      cfg_l0p_priority                          <= #TP 1'b0;
    end
    else begin
      cfg_l0p_priority                          <= #TP (write_pulse[0] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[0] : cfg_l0p_priority;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      cfg_l0p_dynamic_priority                  <= #TP 1'b0;
      cfg_aspm_l0p_dynamic_disable              <= #TP 1'b0;
      cfg_direct_l0p_dynamic_link_width_change  <= #TP 1'b0;
      cfg_l0p_dynamic_target_link_width         <= #TP 3'b0;
    end
    else if (!rc_device & lbc_cdm_dbi) begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_l0p_dynamic_priority                  <= #TP (write_pulse[0] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[7]   : cfg_l0p_dynamic_priority;
      cfg_aspm_l0p_dynamic_disable              <= #TP (write_pulse[0] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[6]   : cfg_aspm_l0p_dynamic_disable;
      cfg_direct_l0p_dynamic_link_width_change  <= #TP (write_pulse[0] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[5]   : cfg_direct_l0p_dynamic_link_width_change;
      cfg_l0p_dynamic_target_link_width         <= #TP (write_pulse[0] & pl_reg_id[ID_0x494]) ? lbc_cdm_data[4:2] : cfg_l0p_dynamic_target_link_width;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      l0p_dynamic_write                         <= #TP 1'b0;
    end
    else begin   
      l0p_dynamic_write                         <= #TP !rc_device & lbc_cdm_dbi & write_pulse[0] & pl_reg_id[ID_0x494];
    end
end


logic int_nak_default_type;

assign int_nak_default_type = 1'b0;
assign {pl_reg_262,pl_reg_261} = '0;
//----------------------------------------------------------------------------------------
// Tx Throttling and Rx Retry Buffer port logic control Register
// cpl_reg_id       - ID_0x5A8
// Length           - 4 bytes
// Offset           - 'h5A8
// Default value    - 0
// Core registers   - {pl_reg_262, pl_reg_261, pl_reg_260, pl_reg_259}
// ---------------------------------------------------------------------------------------
assign pl_reg_259 =  {6'b0 
                       ,int_nak_default_type
                       ,cfg_tx_throttling
                     };
assign pl_reg_260 = 8'b0;

//Read Write Registers
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
         cfg_tx_throttling      <= #TP 1'b0;
    end
    else begin
      cfg_tx_throttling         <= #TP (write_pulse[0] & pl_reg_id[ID_0x5A8]) ? lbc_cdm_data[0]     : cfg_tx_throttling;
      
    end
end



//------------------------------------------------------------------------------
// Bus ack latency timer and replay timer register
// pl_reg_id        - 0
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_0 to pl_reg_3;
//
// These value are taken from table 3-4 and 3-5 of the PCIE 1.0a spec
// Simplified replay timer values added for Gen4-0.7
// -----------------------------------------------------------------------------
reg   [5:0]   smlh_autoneg_link_width_d, smlh_autoneg_link_width_d2;
reg   [2:0]   cfg_max_payload_size_d, cfg_max_payload_size_d2;
reg           ack_timer_update_en;
reg           replay_timer_update_en;
reg           simplified_replay_timer_en, simplified_replay_timer_en_d;
reg           cfg_ext_synch_d;

assign simplified_replay_timer_en = pl_reg_204_bcm36[3];


// No replay adjust if Simplified Replay Timer
assign cfg_replay_timer_value = simplified_replay_timer_en ? {(int2_replay_timer_value[16:6]), int2_replay_timer_value[5:0]}
                                                             : {(int2_replay_timer_value[16:6] + int_replay_timer_add), int2_replay_timer_value[5:0]};
assign cfg_ack_latency_timer  = {(int2_ack_latency_timer[15:6]  + acknak_timer_add), int2_ack_latency_timer[5:0]};

assign {pl_reg_1, pl_reg_0} = int_ack_latency_timer;
assign {pl_reg_3, pl_reg_2} = int_replay_timer_value[15:0];

//Gen3 base spec Table 3-4/5/6 for replay_timer and Table 3-7/8/9 for ack_latency.
//The InternalDelay in AckNak_LATENCY_TIMER formula is 19 for gen1, 70 for gen2 and 115 for gen3. The offset for gen2 from gen1 is 51, gen3 from gen1 is 96.
//Because replay_timer = 3*ack_latency, so the offset for replay_timer = 3*(ack_latency offset).
// Update Gen4-0.7: Simplified REPLAY_TIMER Limits are:
//    A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
//    A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.


always @(current_data_rate or int_replay_timer_value) begin
    casez (current_data_rate)
    3'b000: int2_replay_timer_value     = int_replay_timer_value;                 // GEN1
    3'b001: int2_replay_timer_value     = int_replay_timer_value + (8'd153 / NB); // GEN2
    3'b01?: int2_replay_timer_value     = int_replay_timer_value + (9'd288 / NB); // GEN3/GEN4
    3'b1??: int2_replay_timer_value     = int_replay_timer_value + (9'd288 / NB); // GEN5, gates: must revisit later for Gen5, use gen4 for now
    default:int2_replay_timer_value     = int_replay_timer_value;
    endcase
end

always @(current_data_rate or int_ack_latency_timer) begin
    casez (current_data_rate)
    3'b000: int2_ack_latency_timer  = int_ack_latency_timer;                  // GEN1
    3'b001: int2_ack_latency_timer  = int_ack_latency_timer  + (6'd51  / NB); // GEN2
    3'b01?: int2_ack_latency_timer  = int_ack_latency_timer  + (7'd96  / NB); // GEN3/GEN4
    3'b1??: int2_ack_latency_timer  = int_ack_latency_timer  + (7'd96  / NB); // GEN5, gates: must revisit later for Gen5, use gen4 for now
    default: int2_ack_latency_timer  = int_ack_latency_timer;
    endcase
end


// max_payload size: 000=128, 001=256, 010=512, 011=1024, 100=2048, 101=4096
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        int_ack_latency_timer         <= #TP 16'd4143  / NB;
        int_replay_timer_value        <= #TP 17'd12429 / NB;
        smlh_autoneg_link_width_d     <= #TP 0;
        smlh_autoneg_link_width_d2    <= #TP 0;
        cfg_max_payload_size_d        <= #TP 0;
        cfg_max_payload_size_d2       <= #TP 0;
        simplified_replay_timer_en_d  <= #TP 0;
        cfg_ext_synch_d               <= #TP 0;
        ack_timer_update_en           <= #TP 0;
        replay_timer_update_en        <= #TP 0;
    end
    else begin

        smlh_autoneg_link_width_d     <= #TP smlh_autoneg_link_width;
        smlh_autoneg_link_width_d2    <= #TP smlh_autoneg_link_width_d;
        cfg_max_payload_size_d        <= #TP cfg_max_payload_size;
        cfg_max_payload_size_d2       <= #TP cfg_max_payload_size_d;
        simplified_replay_timer_en_d  <= #TP simplified_replay_timer_en;
        cfg_ext_synch_d               <= #TP cfg_ext_synch;


        // Automatically update the ACK Latency/Replay Timer if the link width/max MTU size values changed
        // Additionally update the Replay Timer if Simplified Replay Timer/Extended Synch values changed
        replay_timer_update_en      <= #TP  (smlh_autoneg_link_width_d != smlh_autoneg_link_width_d2    )
                                        | (cfg_max_payload_size_d      != cfg_max_payload_size_d2       )
                                        | (simplified_replay_timer_en  != simplified_replay_timer_en_d  )
                                        | (cfg_ext_synch               != cfg_ext_synch_d               );

        ack_timer_update_en         <= #TP  (smlh_autoneg_link_width_d != smlh_autoneg_link_width_d2    )
                                        | (cfg_max_payload_size_d      != cfg_max_payload_size_d2       );


        if (ack_timer_update_en) begin              // Ack/Nak Latency Timer
            unique case (1'b1)

                smlh_autoneg_link_width[0]:            // x1, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd237   / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd416   / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd559   / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd1071  / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd2095  / NB;
                        default: int_ack_latency_timer   <= #TP 16'd4143  / NB;     //3'b101
                    endcase
                smlh_autoneg_link_width[1]:                    // x2, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd128  / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd217  / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd289  / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd545  / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd1057 / NB;
                        default: int_ack_latency_timer   <= #TP 16'd2081 / NB;        //3'b101
                    endcase // case(cfg_max_payload_size)
                smlh_autoneg_link_width[2]: // x4, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd73   / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd118  / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd154  / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd282  / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd538  / NB;
                        default: int_ack_latency_timer   <= #TP 16'd1050 / NB;      //3'b101
                    endcase // case(cfg_max_payload_size)
                smlh_autoneg_link_width[3]:             // x8, (128, 256, 1024, 2048, 4096)
                    case (cfg_max_payload_size)
                        3'b000 : int_ack_latency_timer   <= #TP 16'd67    / NB;
                        3'b001 : int_ack_latency_timer   <= #TP 16'd107   / NB;
                        3'b010 : int_ack_latency_timer   <= #TP 16'd86    / NB;
                        3'b011 : int_ack_latency_timer   <= #TP 16'd150   / NB;
                        3'b100 : int_ack_latency_timer   <= #TP 16'd278   / NB;
                        default: int_ack_latency_timer   <= #TP 16'd534   / NB;       //3'b101
                    endcase // case(cfg_max_payload_size)
                default        : int_ack_latency_timer   <= #TP 16'd4143  / NB;
            endcase // case(1'b1)
        end
        else begin
            int_ack_latency_timer[7:0]  <= #TP (write_pulse[0] & pl_reg_id[0]) ? lbc_cdm_data[7:0]   : int_ack_latency_timer[7:0];
            int_ack_latency_timer[15:8] <= #TP (write_pulse[1] & pl_reg_id[0]) ? lbc_cdm_data[15:8]  : int_ack_latency_timer[15:8];
        end

        if (replay_timer_update_en) begin                            // Replay Timer
            unique case (1'b1)

                smlh_autoneg_link_width[0]:             // x1, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size})
                        5'b00000 : int_replay_timer_value  <= #TP 17'd711   / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd1248  / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd1677  / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd3213  / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd6285  / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd12429 / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase
                smlh_autoneg_link_width[1]:                     // x2, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size})
                        5'b00000 : int_replay_timer_value  <= #TP 17'd384  / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd651  / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd867  / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd1635 / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd3171 / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd6243 / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase // case(cfg_max_payload_size)
                smlh_autoneg_link_width[2]:   // x4, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size})
                        5'b00000 : int_replay_timer_value  <= #TP 17'd219  / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd354  / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd462  / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd846  / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd1614 / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd3150 / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase // case(cfg_max_payload_size)
                smlh_autoneg_link_width[3]:             // x8, (128, 256, 1024, 2048, 4096)
                  casez ({simplified_replay_timer_en, cfg_ext_synch, cfg_max_payload_size})
                        5'b00000 : int_replay_timer_value  <= #TP 17'd201   / NB;
                        5'b00001 : int_replay_timer_value  <= #TP 17'd321   / NB;
                        5'b00010 : int_replay_timer_value  <= #TP 17'd258   / NB;
                        5'b00011 : int_replay_timer_value  <= #TP 17'd450   / NB;
                        5'b00100 : int_replay_timer_value  <= #TP 17'd834   / NB;
                        5'b00101 : int_replay_timer_value  <= #TP 17'd1602  / NB;
                        5'b10??? : int_replay_timer_value  <= #TP 17'd27500 / NB; // A value from 24,000 to 31,000 Symbol Times when Extended Synch is 0b.
                        5'b11??? : int_replay_timer_value  <= #TP 17'd90000 / NB; // A value from 80,000 to 100,000 Symbol Times when Extended Synch is 1b.
                        default  : int_replay_timer_value  <= #TP 17'd12429 / NB;
                  endcase // case(cfg_max_payload_size)
                default  :         int_replay_timer_value  <= #TP 17'd12429 / NB;
            endcase // case(1'b1)
        end
        else begin
            int_replay_timer_value[7:0] <= #TP (write_pulse[2] & pl_reg_id[0]) ? lbc_cdm_data[23:16] : int_replay_timer_value[7:0];
            int_replay_timer_value[15:8]<= #TP (write_pulse[3] & pl_reg_id[0]) ? lbc_cdm_data[31:24] : int_replay_timer_value[15:8];
// Simplified Replay Timer enhancement puts the upper bit of the register outside of programmable range in port logic.
// This potentially leads to a future problem for e.g. a 1S gen4 core with extended sync set.
// 2GHz speeds are not yet support by Synopsys so this is unlikely to surface as an issue for some time.
// Current Max value is 100000 = 0x186A0
// For NB > 1 e.g. /2 = 50000 = 0xC350 which fits within 16 bit range.
            if (simplified_replay_timer_en && cfg_ext_synch && NB==1)
                int_replay_timer_value[16] <= #TP 1'b1; // MSB must be '1' for 80,000 to 100,000 range when Extended Synch is 1b and NB is 1
            else
                int_replay_timer_value[16] <= #TP 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Other MSG register / Corruption Pattern
// Other MSG: used to send a specific PCI-E Message. The user writes the payload
//            of the message it wishes to send into this registers, then sets bit
//            0 of the Port Link Control Register
// Corruption Pattern: used to store a corruption pattern for corrupting the LCRC
//                     on all TLP packets. The user places a 32-bit corruption
//                     pattern into this register and enables this function by
//                     setting bit 24 of the Port Link Control Register. When
//                     enabled, the transmit CRC result is XOR'd with this
//                     pattern before inserting it into the packet.
// pl_reg_id        - 1
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_4 to to pl_reg_7
// -----------------------------------------------------------------------------

assign cfg_other_msg_payload    = {pl_reg_7, pl_reg_6, pl_reg_5, pl_reg_4};
assign cfg_corrupt_crc_pattern  = cfg_xmt_corrupt_crc ? {pl_reg_7, pl_reg_6, pl_reg_5, pl_reg_4} : 32'h0;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        {pl_reg_7, pl_reg_6, pl_reg_5, pl_reg_4}    <= #TP `DEFAULT_REQ_OTHER_MSG;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_4    <= #TP (write_pulse[0] & pl_reg_id[1]) ? lbc_cdm_data[7:0]   : pl_reg_4;
        pl_reg_5    <= #TP (write_pulse[1] & pl_reg_id[1]) ? lbc_cdm_data[15:8]  : pl_reg_5;
        pl_reg_6    <= #TP (write_pulse[2] & pl_reg_id[1]) ? lbc_cdm_data[23:16] : pl_reg_6;
        pl_reg_7    <= #TP (write_pulse[3] & pl_reg_id[1]) ? lbc_cdm_data[31:24] : pl_reg_7;
    end
end

//------------------------------------------------------------------------------
// Port Force Link Register
// cpl_reg_id       - 2
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_8 to to pl_reg_11
// -----------------------------------------------------------------------------
assign cfg_link_num          = pl_reg_8;
assign cfg_forced_link_state = {pl_reg_bcm36_nhs_d.pl_reg_10[5:0]};
assign cfg_support_part_lanes_rxei_exit = pl_reg_bcm36_nhs_d.pl_reg_10[6];
assign cfg_ts2_lid_deskew    = pl_reg_bcm36_nhs_d.pl_reg_10[7];
assign cfg_forced_ltssm_cmd  = {pl_reg_9[3:0]};


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n)
        cfg_force_en    <= #TP 0;
    else
    
        cfg_force_en    <= #TP write_pulse[1] & pl_reg_id[2] & lbc_cdm_data[15] & !cfg_force_en;
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_8        <= #TP `DEFAULT_LINK_NUM;       // Link number
        pl_reg_9        <= #TP 0;                       // Forced LTSSM cmd
        pl_reg_10[5:0]  <= #TP 0;                       // Forced link state
        pl_reg_10[6]    <= #TP `DEFAULT_SUPPORT_PART_LANES_RXEI_EXIT_IN_POLL_ACTIVE; // Polling.Active -> Polling.Configuration based on part of predetermined lanes RxEi exit
        pl_reg_10[7]    <= #TP `DEFAULT_DO_DESKEW_FOR_SRIS; // do deskew for sris using ts2 -> logic_idle_data transition
        pl_reg_11[0]    <= #TP 0;                       // Reserved
        pl_reg_11[7:1]  <= #TP 0;                       // Reserved
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_8        <= #TP (write_pulse[0] & pl_reg_id[2]) ? lbc_cdm_data[7:0]   : pl_reg_8;
        pl_reg_9[7:4]   <= #TP 4'b0;
        pl_reg_9[3:0]   <= #TP (write_pulse[1] & pl_reg_id[2]) ? lbc_cdm_data[11:8]  : pl_reg_9[3:0];
        pl_reg_10[5:0]  <= #TP (write_pulse[2] & pl_reg_id[2]) ? lbc_cdm_data[21:16] : pl_reg_10[5:0];
        pl_reg_10[6]    <= #TP (write_pulse[2] & pl_reg_id[2]) ? lbc_cdm_data[22]    : pl_reg_10[6];
        pl_reg_10[7]    <= #TP (write_pulse[2] & pl_reg_id[2]) ? lbc_cdm_data[23]    : pl_reg_10[7];
        pl_reg_11[0]    <= #TP 0;
        pl_reg_11[7:1]  <= #TP 0;
    end
end



//------------------------------------------------------------------------------
// ACK freq register
// cpl_reg_id       - 3
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_12 to to pl_reg_15
// -----------------------------------------------------------------------------


assign cfg_ack_freq                 = pl_reg_12;
assign cfg_n_fts                    = cfg_comm_clk_config ? pl_reg_14 : pl_reg_13;
assign cfg_l0s_entr_latency_timer   = pl_reg_15[2:0];
assign cfg_l1_entr_latency_timer    = pl_reg_15[5:3];
assign cfg_l1_entr_wo_rl0s          = pl_reg_15[6];
assign cfg_aspm_l1_timer_enable     = pl_reg_15[7];
assign int_upd_aspm_ctrl            = (write_pulse[3] & pl_reg_id[3]);


always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_12       <= #TP `DEFAULT_ACK_FREQUENCY;      // ACK frequency
        pl_reg_15[2:0]  <= #TP `DEFAULT_L0S_ENTR_LATENCY;   // L0s entrance latency
        pl_reg_15[5:3]  <= #TP `DEFAULT_L1_ENTR_LATENCY;    // L1 entrance latency
        pl_reg_15[6]    <= #TP 0;                           // Enter L1 without rL0s
        pl_reg_15[7]    <= #TP ASPM_L1_TIMER_ENABLE;        // ASPM L1 Timer Enable
        cfg_upd_aspm_ctrl <= #TP 0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_12       <= #TP (write_pulse[0] & pl_reg_id[3]) ? lbc_cdm_data[7:0]   : pl_reg_12;
        cfg_upd_aspm_ctrl <= #TP int_upd_aspm_ctrl;
        pl_reg_15[2:0]  <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[26:24] : pl_reg_15[2:0];
        pl_reg_15[5:3]  <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[29:27] : pl_reg_15[5:3];
        pl_reg_15[6]    <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[30]    : pl_reg_15[6];
        pl_reg_15[7]    <= #TP (write_pulse[3] & pl_reg_id[3]) ? lbc_cdm_data[31]    : pl_reg_15[7];
    end
end
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin

        pl_reg_13       <= #TP `CX_NFTS;                    // N_FTS
        pl_reg_14       <= #TP `CX_COMM_NFTS;               // Common N_FTS
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
       
        pl_reg_13       <= #TP (write_pulse[1] & pl_reg_id[3]) ? lbc_cdm_data[15:8]  : pl_reg_13;
        pl_reg_14       <= #TP (write_pulse[2] & pl_reg_id[3]) ? lbc_cdm_data[23:16] : pl_reg_14;

    end
end

//------------------------------------------------------------------------------
// Port Link Control register
// pl_reg_id        - 4
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_16
// -----------------------------------------------------------------------------
assign cfg_other_msg_request    = pl_reg_bcm36_nhs_d.pl_reg_16[0];
assign cfg_scramble_dis         = pl_reg_bcm36_nhs_d.pl_reg_16[1];
assign cfg_lpbk_en              = pl_reg_bcm36_nhs_d.pl_reg_16[2];
assign cfg_plreg_reset          = pl_reg_bcm36_nhs_d.pl_reg_16[3];
assign cfg_dll_lnk_en           = pl_reg_bcm36_nhs_d.pl_reg_16[5];

assign cfg_link_dis             = pl_reg_bcm36_nhs_d.pl_reg_16[6];
assign cfg_link_rate            = pl_reg_17[3:0];
//assign cfg_ext_synch            = pl_reg_19[2]; //extended sync is spec defined so this port logic register is incorrect.
assign cfg_xmt_beacon           = pl_reg_19[0];

assign cfg_fast_link_mode       = pl_reg_bcm36_nhs_d.pl_reg_16[7];
assign cfg_link_capable         = pl_reg_18[5:0];
assign cfg_xmt_corrupt_crc      = pl_reg_19[1];
assign cfg_tx_reverse_lanes     = pl_reg_19[3];



always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin

        pl_reg_16[0]    <= #TP 1'b0;                            // Send special message
        pl_reg_16[1]    <= #TP `DEFAULT_SCRAMBLE_DISABLE;       // Scrambler disabled
        pl_reg_16[2]    <= #TP `DEFAULT_LOOPBACK_ENABLE;        // Loopback enabled
        pl_reg_16[3]    <= #TP `DEFAULT_RESET_ASSERT;           // LTSSM goes to Hot Reset state
        pl_reg_16[4]    <= #TP 1'b0;                            // Reserved
        pl_reg_16[5]    <= #TP `DEFAULT_DLL_LINK_ENABLE;        // DLL Link enable - allows L2 link up
        pl_reg_16[6]    <= #TP `DEFAULT_LINK_DISABLE;           // Link disable (only L1/L2 package) - otherwise, use Link control register
        pl_reg_17[3:0]  <= #TP `DEFAULT_LINK_RATE;              // Link data rate (only L1/L2 package) - otherwise, use Link status register
        pl_reg_17[7:4]  <= #TP 4'b0;                            // Reserved
        pl_reg_19[0]    <= #TP `DEFAULT_BEACON_ENABLE;          // Transmit beacon enable
        pl_reg_19[2]    <= #TP 1'b0;                            // Extended Synch (only L1/L2 package) - otherwise, use Link control register
        pl_reg_19[1]    <= #TP 1'b0;                            // Corrupt LCRC enable
        pl_reg_19[3]    <= #TP 1'b0;                            // Transmit lane reversale enable
        pl_reg_19[7:4]  <= #TP 4'b0;                            // Reserved
    end
    else begin

        pl_reg_16[0]    <= #TP (write_pulse[0] & pl_reg_id[4] & lbc_cdm_data[0] & !pl_reg_16[0]);     // 1-cycle pulse
        pl_reg_16[1]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[1]   : pl_reg_16[1];
        pl_reg_16[2]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[2]   : pl_reg_16[2];
        pl_reg_16[3]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[3]   : pl_reg_16[3];
        pl_reg_16[4]    <= #TP 1'b0;
        pl_reg_16[5]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[5]   : pl_reg_16[5];
        pl_reg_16[6]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[6]   : pl_reg_16[6];
        pl_reg_17[3:0]  <= #TP (write_pulse[1] & pl_reg_id[4]) ? lbc_cdm_data[11:8]  : pl_reg_17[3:0];
        pl_reg_17[7:4]  <= #TP 4'b0;
        pl_reg_19[3:0]  <= #TP (write_pulse[3] & pl_reg_id[4]) ? lbc_cdm_data[27:24] : pl_reg_19[3:0];
        pl_reg_19[7:4]  <= #TP 0;
    end
end
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_18[5:0]  <= #TP `DEFAULT_LINK_CAPABLE;           // Supported number of lanes - direct control over ltssm_lanes_active
        pl_reg_18[7:6]  <= #TP 2'b0;                            // Reserved
    end
    else begin
        pl_reg_18[5:0]    <= #TP (write_pulse[2] & pl_reg_id[4]) ? lbc_cdm_data[21:16] : pl_reg_18[5:0];

        pl_reg_18[7:6]  <= #TP 2'b0;                            // Reserved
    end
end

// spyglass disable_block W552
// SMD: Bus 'pl_reg_16' is driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        pl_reg_16[7]    <= #TP `DEFAULT_FAST_LINK_ENABLE;       // Fast Link mode
    else begin
        pl_reg_16[7]    <= #TP (write_pulse[0] & pl_reg_id[4]) ? lbc_cdm_data[7] : pl_reg_16[7];
    end
end
// spyglass enable_block W552

//------------------------------------------------------------------------------
// Lane Skew Register
// cpl_reg_id       - 5
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_20 , 21, 22, 23
// -----------------------------------------------------------------------------
assign cfg_lane_skew            = {pl_reg_bcm36_nhs_d.pl_reg_22[6:0], pl_reg_bcm36_nhs_d.pl_reg_21, pl_reg_bcm36_nhs_d.pl_reg_20};
assign cfg_drift_buffer_deskew_enable = pl_reg_bcm36_nhs_d.pl_reg_22[7];

assign cfg_deskew_disable       = pl_reg_bcm36_nhs_d.pl_reg_23[7];
assign cfg_imp_num_lanes        = pl_reg_bcm36_nhs_d.pl_reg_23[6:3];
assign cfg_elastic_buffer_mode  = pl_reg_bcm36_nhs_d.pl_reg_23[2];
assign cfg_acknack_disable      = pl_reg_bcm36_nhs_d.pl_reg_23[1];
assign cfg_flow_control_disable = pl_reg_bcm36_nhs_d.pl_reg_23[0];

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_20       <= #TP 0;               // Lane deskew
        pl_reg_21       <= #TP 0;               // Lane deskew
        pl_reg_22[6:0]  <= #TP 0;               // Lane deskew
        pl_reg_22[7]    <= #TP 0;               // Drift Buffer deskew enable
        pl_reg_23[0]    <= #TP 0;               // Flow control disable
        pl_reg_23[1]    <= #TP 0;               // ACK/NAK disable
        pl_reg_23[2]    <= #TP `DEFAULT_LANE_SKEW_OFF_26;
        pl_reg_23[6:3]  <= #TP NLM1;            // implementation-specific number of lanes, 0->1, 1->2, 3->4, 7->8, 15->16
        pl_reg_23[7]    <= #TP 0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_20       <= #TP (write_pulse[0] & pl_reg_id[5]) ? lbc_cdm_data[7:0]   : pl_reg_20;
        pl_reg_21       <= #TP (write_pulse[1] & pl_reg_id[5]) ? lbc_cdm_data[15:8]  : pl_reg_21;
        pl_reg_22       <= #TP (write_pulse[2] & pl_reg_id[5]) ? lbc_cdm_data[23:16] : pl_reg_22;
        pl_reg_23[0]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[24]    : pl_reg_23[0];
        pl_reg_23[1]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[25]    : pl_reg_23[1];
        pl_reg_23[2]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[26]    : pl_reg_23[2];
        pl_reg_23[6:3]  <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[30:27] : pl_reg_23[6:3];
        pl_reg_23[7]    <= #TP (write_pulse[3] & pl_reg_id[5]) ? lbc_cdm_data[31]    : pl_reg_23[7];
    end
end

//------------------------------------------------------------------------------
// SYMBOL number register
// cpl_reg_id       - 6
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - pl_reg_24,25,26,27
// -----------------------------------------------------------------------------
assign cfg_max_func_num         = pl_reg_24[PF_WD   -1:0];
assign replay_timer_add         = {pl_reg_26[2:0], pl_reg_25[7:6]};
assign acknak_timer_add         = pl_reg_26[7:3];
assign cfg_fast_link_scaling_factor = pl_reg_27[6:5];

assign gen3_data_rate           = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate >= `GEN6_RATE);
assign gen3_replay_timer_add    = `DEFAULT_GEN3_REPLAY_ADJ;
assign gen12_replay_timer_add   = `DEFAULT_REPLAY_ADJ;
assign gen3_rate_entry_pulse = gen3_data_rate & !gen3_data_rate_d; //run-time to update replay_time_add when entry to Gen3 rate
assign gen3_rate_exit_pulse  = !gen3_data_rate & gen3_data_rate_d; //run-time to update replay_time_add when entry to Gen3 rate

always @(posedge core_clk or negedge sticky_rst_n) begin : gen3_data_rate_d_PROC
    if (!sticky_rst_n)
        gen3_data_rate_d <= #TP 0;
    else
        gen3_data_rate_d <= #TP gen3_data_rate;
end



assign int_replay_timer_add     =
                                  (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate >= `GEN6_RATE) ? {replay_timer_add, 2'b00} : //Each increment of the replay timer by 256
                                  {2'b00, replay_timer_add}; //Each increment of the replay timer by 64

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_24[7:0]  <= #TP `CX_MAX_FUNC_NUM;                // Max number of functions supported
        pl_reg_27[4:0]  <= #TP 0;                               // FC update freq timer modifier
        pl_reg_27[6:5]  <= #TP `DEFAULT_FAST_LINK_SCALING_FACTOR; // Fast Link timer Scaling Factor
        pl_reg_27[7]    <= #TP 0;                               // Reserved
    end
    else begin
        pl_reg_24       <= #TP (write_pulse[0] & pl_reg_id[6]) ? lbc_cdm_data[7:0]   : pl_reg_24;
        pl_reg_27[4:0]  <= #TP (write_pulse[3] & pl_reg_id[6]) ? lbc_cdm_data[28:24] : pl_reg_27[4:0];
        pl_reg_27[6:5]  <= #TP (write_pulse[3] & pl_reg_id[6]) ? lbc_cdm_data[30:29] : pl_reg_27[6:5];
        pl_reg_27[7]    <= #TP 0;                               // Reserved
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_25[2:0]  <= #TP 0;                               // Reserved
        pl_reg_25[5:3]  <= #TP 0;                               // Reserved
        {pl_reg_26[2:0],
        pl_reg_25[7:6]} <= #TP `DEFAULT_REPLAY_ADJ;             // Replay timer modifier
        pl_reg_26[7:3]  <= #TP 0;                               // ACK/NAK latency timer modifier
    end
    else begin
        pl_reg_25[2:0]  <= #TP 0;                               // Reserved
        pl_reg_25[5:3]  <= #TP 0;                               // Reserved
        pl_reg_25[7:6]  <= #TP
                               gen3_rate_entry_pulse ? gen3_replay_timer_add[1:0] : gen3_rate_exit_pulse ? gen12_replay_timer_add[1:0] :
                               (write_pulse[1] & pl_reg_id[6]) ? lbc_cdm_data[15:14] :
                               pl_reg_25[7:6];
        pl_reg_26[2:0]  <= #TP
                               gen3_rate_entry_pulse ? gen3_replay_timer_add[4:2] : gen3_rate_exit_pulse ? gen12_replay_timer_add[4:2] :
                               (write_pulse[2] & pl_reg_id[6]) ? lbc_cdm_data[18:16] :
                               pl_reg_26[2:0];
        pl_reg_26[7:3]  <= #TP (write_pulse[2] & pl_reg_id[6]) ? lbc_cdm_data[23:19] : pl_reg_26[7:3];
    end
end
//------------------------------------------------------------------------------
// SYMBOL timer & Filer Mask register
// cpl_reg_id       - 7
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_28,29, 30, 21
// -----------------------------------------------------------------------------
localparam logic [47:0] DEF_CFG_FILTER_RULE_MASK = {32'(`DEFAULT_FILTER_MASK_2), 16'(`DEFAULT_FILTER_MASK_1)};
wire    [47:0]  pl_filter_rule_reg;
assign pl_filter_rule_reg       = {pl_reg_bcm36_nhs_d.pl_reg_35, pl_reg_bcm36_nhs_d.pl_reg_34, pl_reg_bcm36_nhs_d.pl_reg_33, pl_reg_bcm36_nhs_d.pl_reg_32, pl_reg_bcm36_nhs_d.pl_reg_31, pl_reg_bcm36_nhs_d.pl_reg_30};
assign cfg_skip_interval        = {pl_reg_bcm36_nhs_d.pl_reg_29[2:0], pl_reg_bcm36_nhs_d.pl_reg_28[7:0]};
assign cfg_eidle_timer          = pl_reg_bcm36_nhs_d.pl_reg_29[6:3];
assign cfg_fc_wdog_disable      = pl_reg_bcm36_nhs_d.pl_reg_29[7];
assign cfg_filter_rule_mask     = pl_filter_rule_reg[N_FLT_MASK-1:0];

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        {pl_reg_29[2:0], pl_reg_28} <= #TP `DEFAULT_SKIP_INTERVAL;          // Skip interval
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_28        <= #TP (write_pulse[0] & pl_reg_id[7]) ? lbc_cdm_data[7:0]   : pl_reg_28;
        pl_reg_29[2:0]   <= #TP (write_pulse[1] & pl_reg_id[7]) ? lbc_cdm_data[10:8]  : pl_reg_29[2:0];
    end
end

// spyglass disable_block W552
// SMD: Bus 'pl_reg_29' is driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_29[6:3]              <= #TP `DEFAULT_EIDLE_TIMER;            // Eidle timer
        pl_reg_29[7]                <= #TP `DEFAULT_FC_WATCH_DOG_DISABLE;   // Flow control watchdog timer disable
        pl_reg_31                   <= #TP DEF_CFG_FILTER_RULE_MASK[15:8];  // Filter rule mask
        pl_reg_30                   <= #TP DEF_CFG_FILTER_RULE_MASK[7:0];   // Filter rule mask
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_29[7:3]   <= #TP (write_pulse[1] & pl_reg_id[7]) ? lbc_cdm_data[15:11] : pl_reg_29[7:3];
        pl_reg_30        <= #TP (write_pulse[2] & pl_reg_id[7]) ? lbc_cdm_data[23:16] : pl_reg_30;
        pl_reg_31        <= #TP (write_pulse[3] & pl_reg_id[7]) ? lbc_cdm_data[31:24] : pl_reg_31;
    end
end
// spyglass enable_block W552

//------------------------------------------------------------------------------
// Filer Mask register 2
// cpl_reg_id       - 8
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_32, 33, 34, 35
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_32   <= #TP DEF_CFG_FILTER_RULE_MASK[23:16];                 // Filter rule mask
        pl_reg_33   <= #TP DEF_CFG_FILTER_RULE_MASK[31:24];                 // Filter rule mask
        pl_reg_34   <= #TP DEF_CFG_FILTER_RULE_MASK[39:32];                 // Filter rule mask
        pl_reg_35   <= #TP DEF_CFG_FILTER_RULE_MASK[47:40];                 // Filter rule mask
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_32   <= #TP (write_pulse[0] & pl_reg_id[8]) ? lbc_cdm_data[7:0]   : pl_reg_32;
        pl_reg_33   <= #TP (write_pulse[1] & pl_reg_id[8]) ? lbc_cdm_data[15:8]  : pl_reg_33;
        pl_reg_34   <= #TP (write_pulse[2] & pl_reg_id[8]) ? lbc_cdm_data[23:16] : pl_reg_34;
        pl_reg_35   <= #TP (write_pulse[3] & pl_reg_id[8]) ? lbc_cdm_data[31:24] : pl_reg_35;
    end
end

//------------------------------------------------------------------------------
// Misc control register
// cpl_reg_id       - 9
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_36, 37, 38, 39
// -----------------------------------------------------------------------------
assign {pl_reg_39, pl_reg_38, pl_reg_37} = 0;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_36       <= #TP 8'h1;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_36[0]  <= #TP (write_pulse[0] & pl_reg_id[9]) ? lbc_cdm_data[0] : pl_reg_36[0];
        pl_reg_36[7:1]  <= #TP 0;
    end
end

// Dont need to cover the debug registers

//------------------------------------------------------------------------------
// Debug registers
// pl_reg_id    - 10, 11
// Length       - 8 bytes
// Default value
// Core register- pl_reg_40 to 47
//------------------------------------------------------------------------------

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        {pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40}    <= #TP 0;
        {pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44}    <= #TP 0;
    end
    else begin
        {pl_reg_43, pl_reg_42, pl_reg_41, pl_reg_40}    <= #TP cxpl_debug_info[31:0];
        {pl_reg_47, pl_reg_46, pl_reg_45, pl_reg_44}    <= #TP cxpl_debug_info[63:32];
    end
end

//------------------------------------------------------------------------------
// Debug registers
// pl_reg_id    - 12 - 14
// Length       - 12 bytes
// Default value
// Core register- pl_reg_48 to 59
//------------------------------------------------------------------------------

wire [3:0] all_zeros;
assign all_zeros = 4'b0;

assign {pl_reg_51, pl_reg_50, pl_reg_49, pl_reg_48} = {all_zeros, xtlh_xadm_ph_cdts, xtlh_xadm_pd_cdts};
assign {pl_reg_55, pl_reg_54, pl_reg_53, pl_reg_52} = {all_zeros, xtlh_xadm_nph_cdts, xtlh_xadm_npd_cdts};
assign {pl_reg_59, pl_reg_58, pl_reg_57, pl_reg_56} = {all_zeros, xtlh_xadm_cplh_cdts, xtlh_xadm_cpld_cdts};

//------------------------------------------------------------------------------
// Debug registers
// pl_reg_id    - 15
// Length       - 4 bytes
// Default value
// Core register- pl_reg_60 to 63
//------------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_62       <= #TP 0;
        pl_reg_63       <= #TP 0;
    end
    else begin
        pl_reg_62       <= #TP (write_pulse[2] & pl_reg_id[15]) ? lbc_cdm_data[23:16] : pl_reg_62;
        pl_reg_63[4:0]  <= #TP (write_pulse[3] & pl_reg_id[15]) ? lbc_cdm_data[28:24] : pl_reg_63[4:0];
        pl_reg_63[6:5]  <= #TP 2'b0;
        pl_reg_63[7]    <= #TP (write_pulse[3] & pl_reg_id[15]) ? lbc_cdm_data[31]    : pl_reg_63[7];
    end
end

assign fc_timer_override_val = {pl_reg_63[4:0],pl_reg_62};
assign fc_timer_override     = pl_reg_63[7];

// -- Rx Queue Status
//      - Credit Queue, VC0, P/NP/CPL
//      - Serialisation Queue Status, all TLPs
wire clr_radm_qoverflow, clr_radm_formqram_overflow, clr_radm_formqram_read_err;
wire set_radm_qoverflow, set_radm_formqram_overflow, set_radm_formqram_read_err;
assign clr_radm_qoverflow = (write_pulse[0] & pl_reg_id[15]) ? lbc_cdm_data[3] : 1'b0;
assign set_radm_qoverflow = radm_qoverflow;
assign clr_radm_formqram_read_err = (write_pulse[1] & pl_reg_id[15]) ? lbc_cdm_data[15] : 1'b0;
assign clr_radm_formqram_overflow = (write_pulse[1] & pl_reg_id[15]) ? lbc_cdm_data[14] : 1'b0;
assign set_radm_formqram_read_err = radm_formq_read_err;
assign set_radm_formqram_overflow = radm_formq_overflow;

reg  r_radm_qoverflow, r_radm_formqram_overflow, r_radm_formqram_read_err;
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      r_radm_qoverflow <= #TP 0;
      r_radm_formqram_read_err <= #TP 0;
      r_radm_formqram_overflow <= #TP 0;
    end else begin
      r_radm_qoverflow <= #TP set_radm_qoverflow ? 1'b1 : clr_radm_qoverflow ? 1'b0 : r_radm_qoverflow;
      r_radm_formqram_read_err <= #TP set_radm_formqram_read_err ? 1'b1 : clr_radm_formqram_read_err ? 1'b0 : r_radm_formqram_read_err;
      r_radm_formqram_overflow <= #TP set_radm_formqram_overflow ? 1'b1 : clr_radm_formqram_overflow ? 1'b0 : r_radm_formqram_overflow;
    end
end

assign {pl_reg_61, pl_reg_60} = { r_radm_formqram_read_err,
                                                r_radm_formqram_overflow,
                                                radm_formq_not_empty,
                                                9'b0,

                                 r_radm_qoverflow,
                                 radm_q_not_empty, xdlh_retrybuf_not_empty, rtlh_crd_not_rtn
                                };

//------------------------------------------------------------------------------
// XADM Transmit Arbitration
// pl_reg_id    - 16, 17
// Length       - 8 bytes
// Default value
// Core register- pl_reg_64 to 71
//------------------------------------------------------------------------------
//
assign cfg_lpvc_wrr_weight[7:0]     = pl_reg_64;
assign cfg_lpvc_wrr_weight[15:8]    = pl_reg_65;
assign cfg_lpvc_wrr_weight[23:16]   = pl_reg_66;
assign cfg_lpvc_wrr_weight[31:24]   = pl_reg_67;
assign cfg_lpvc_wrr_weight[39:32]   = pl_reg_68;
assign cfg_lpvc_wrr_weight[47:40]   = pl_reg_69;
assign cfg_lpvc_wrr_weight[55:48]   = pl_reg_70;
assign cfg_lpvc_wrr_weight[63:56]   = pl_reg_71;

always @(posedge core_clk or negedge sticky_rst_n)
begin : lpvc_wrr_weight_PROC
    if (!sticky_rst_n) begin
        pl_reg_64   <= #TP `LPVC_WRR_WEIGHT_VC0;
        pl_reg_65   <= #TP `LPVC_WRR_WEIGHT_VC1;
        pl_reg_66   <= #TP `LPVC_WRR_WEIGHT_VC2;
        pl_reg_67   <= #TP `LPVC_WRR_WEIGHT_VC3;
        pl_reg_68   <= #TP `LPVC_WRR_WEIGHT_VC4;
        pl_reg_69   <= #TP `LPVC_WRR_WEIGHT_VC5;
        pl_reg_70   <= #TP `LPVC_WRR_WEIGHT_VC6;
        pl_reg_71   <= #TP `LPVC_WRR_WEIGHT_VC7;
    end
    else begin
        pl_reg_64   <= #TP `LPVC_WRR_WEIGHT_VC0;
        pl_reg_65   <= #TP `LPVC_WRR_WEIGHT_VC1;
        pl_reg_66   <= #TP `LPVC_WRR_WEIGHT_VC2;
        pl_reg_67   <= #TP `LPVC_WRR_WEIGHT_VC3;
        pl_reg_68   <= #TP `LPVC_WRR_WEIGHT_VC4;
        pl_reg_69   <= #TP `LPVC_WRR_WEIGHT_VC5;
        pl_reg_70   <= #TP `LPVC_WRR_WEIGHT_VC6;
        pl_reg_71   <= #TP `LPVC_WRR_WEIGHT_VC7;
    end
end


wire  [(NVC*9)-1:0]   int_cfg_radm_q_mode;        // Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
//------------------------------------------------------------------------------
// Flow Control Credits & Single RAM (Segmented Buffer) Control Register
// pl_reg_id    - 18 - 41
// Length       -
// Default value
// Core register- pl_reg_72 to pl_reg_167
//------------------------------------------------------------------------------

assign  cfg_fc_credit_pd[11:0]      = {pl_reg_73[3:0], pl_reg_72};
assign  cfg_fc_credit_ph[7:0]       = {pl_reg_74[3:0], pl_reg_73[7:4]};
assign  cfg_fc_credit_npd[11:0]     = {pl_reg_77[3:0], pl_reg_76};
assign  cfg_fc_credit_nph[7:0]      = {pl_reg_78[3:0], pl_reg_77[7:4]};
assign  cfg_fc_credit_cpld[11:0]    = {pl_reg_81[3:0], pl_reg_80};
assign  cfg_fc_credit_cplh[7:0]     = {pl_reg_82[3:0], pl_reg_81[7:4]};

assign  hdr_scale_p[1:0]           = pl_reg_75[1:0];
assign  data_scale_p[1:0]          = pl_reg_75[3:2];
assign  hdr_scale_np[1:0]          = pl_reg_79[1:0];
assign  data_scale_np[1:0]         = pl_reg_79[3:2];
assign  hdr_scale_cpl[1:0]         = pl_reg_83[1:0];
assign  data_scale_cpl[1:0]        = pl_reg_83[3:2];

assign cfg_radm_order_rule[0]       = pl_reg_75[6];
assign cfg_radm_strict_vc_prior     = pl_reg_75[7];
assign int_cfg_radm_q_mode[8:0]     = {pl_reg_82[7:5], pl_reg_78[7:5], pl_reg_74[7:5]};

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : vc0_rcv_q_ctrl_PROC
    if (!sticky_rst_n) begin
        {pl_reg_74[3:0], pl_reg_73, pl_reg_72}  <= #TP {`RADM_PQ_HCRD_VC0, `RADM_PQ_DCRD_VC0};
        pl_reg_74[4]                            <= #TP 0;                                           // Reserved
        pl_reg_74[7:5]                          <= #TP `RADM_P_QMODE_VC0;
        pl_reg_75[1:0]                          <= #TP `RADM_PQ_HSCALE_VC0;
        pl_reg_75[3:2]                          <= #TP `RADM_PQ_DSCALE_VC0;
        pl_reg_75[5:4]                          <= #TP 0;                                           // Reserved

        pl_reg_75[6]                            <= #TP `CX_RADM_ORDERING_RULES_VC0;
        pl_reg_75[7]                            <= #TP `CX_RADM_STRICT_VC_PRIORITY;
        {pl_reg_78[3:0], pl_reg_77, pl_reg_76}  <= #TP {`RADM_NPQ_HCRD_VC0, `RADM_NPQ_DCRD_VC0};
        pl_reg_78[4]                            <= #TP 0;                                           // Reserved
        pl_reg_78[7:5]                          <= #TP `RADM_NP_QMODE_VC0;
        pl_reg_79[1:0]                          <= #TP `RADM_NPQ_HSCALE_VC0;
        pl_reg_79[3:2]                          <= #TP `RADM_NPQ_DSCALE_VC0;
        pl_reg_79[7:4]                          <= #TP 0;                                           // Reserved

        {pl_reg_82[3:0], pl_reg_81, pl_reg_80}  <= #TP {`RADM_CPLQ_HCRD_VC0, `RADM_CPLQ_DCRD_VC0};
        pl_reg_82[4]                            <= #TP 0;                                           // Reserved
        pl_reg_82[7:5]                          <= #TP `RADM_CPL_QMODE_VC0;
        pl_reg_83[1:0]                          <= #TP `RADM_CPLQ_HSCALE_VC0;
        pl_reg_83[3:2]                          <= #TP `RADM_CPLQ_DSCALE_VC0;
        pl_reg_83[7:4]                          <= #TP 0;                                           // Reserved

    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_72                               <= #TP (write_pulse[0] & pl_reg_id[18]) ? lbc_cdm_data[7:0]   : pl_reg_72;
        pl_reg_73                               <= #TP (write_pulse[1] & pl_reg_id[18]) ? lbc_cdm_data[15:8]  : pl_reg_73;
        pl_reg_74                               <= #TP (write_pulse[2] & pl_reg_id[18]) ? lbc_cdm_data[23:16] : pl_reg_74;
        pl_reg_75                               <= #TP (write_pulse[3] & pl_reg_id[18]) ? lbc_cdm_data[31:24] : pl_reg_75;
        pl_reg_76                               <= #TP (write_pulse[0] & pl_reg_id[19]) ? lbc_cdm_data[7:0]   : pl_reg_76;
        pl_reg_77                               <= #TP (write_pulse[1] & pl_reg_id[19]) ? lbc_cdm_data[15:8]  : pl_reg_77;
        pl_reg_78                               <= #TP (write_pulse[2] & pl_reg_id[19]) ? lbc_cdm_data[23:16] : pl_reg_78;
        pl_reg_79                               <= #TP (write_pulse[3] & pl_reg_id[19]) ? lbc_cdm_data[31:24] : pl_reg_79;
        pl_reg_80                               <= #TP (write_pulse[0] & pl_reg_id[20]) ? lbc_cdm_data[7:0]   : pl_reg_80;
        pl_reg_81                               <= #TP (write_pulse[1] & pl_reg_id[20]) ? lbc_cdm_data[15:8]  : pl_reg_81;
        pl_reg_82                               <= #TP (write_pulse[2] & pl_reg_id[20]) ? lbc_cdm_data[23:16] : pl_reg_82;
        pl_reg_83                               <= #TP (write_pulse[3] & pl_reg_id[20]) ? lbc_cdm_data[31:24] : pl_reg_83;
    end
end









assign cfg_radm_q_mode = int_cfg_radm_q_mode;


//------------------------------------------------------------------------------
// Segment Sizes Register
// pl_reg_id    -
// Length       -
// Default value
// Core register-
//------------------------------------------------------------------------------

assign cfg_hq_depths[(RADM_SBUF_HDRQ_PW *(0+(3*0)+1))-1:RADM_SBUF_HDRQ_PW *(0+(3*0))] = `RADM_PQ_HDP_VC0;
assign cfg_hq_depths[(RADM_SBUF_HDRQ_PW *(1+(3*0)+1))-1:RADM_SBUF_HDRQ_PW *(1+(3*0))] = `RADM_NPQ_HDP_VC0;
assign cfg_hq_depths[(RADM_SBUF_HDRQ_PW *(2+(3*0)+1))-1:RADM_SBUF_HDRQ_PW *(2+(3*0))] = `RADM_CPLQ_HDP_VC0;

assign cfg_dq_depths[(RADM_SBUF_DATAQ_PW*(0+(3*0)+1))-1:RADM_SBUF_DATAQ_PW*(0+(3*0))] = `RADM_PQ_DDP_VC0;
assign cfg_dq_depths[(RADM_SBUF_DATAQ_PW*(1+(3*0)+1))-1:RADM_SBUF_DATAQ_PW*(1+(3*0))] = `RADM_NPQ_DDP_VC0;
assign cfg_dq_depths[(RADM_SBUF_DATAQ_PW*(2+(3*0)+1))-1:RADM_SBUF_DATAQ_PW*(2+(3*0))] = `RADM_CPLQ_DDP_VC0;









//------------------------------------------------------------------------------
// PCIe Gen 2 Register
// cpl_reg_id       - 67
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172}
// -----------------------------------------------------------------------------
//assign {pl_reg_175, pl_reg_174, pl_reg_173, pl_reg_172} = {12'b0, cfg_tx_compliance_rcv, cfg_phy_txswing, cfg_directed_speed_change, cfg_lane_en, cfg_gen2_n_fts};
wire cfg_gen1_ei_inference_mode;
wire cfg_do_g5_lpbk_eq, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_mod_ts;
wire cfg_force_lane_flip;
wire [3:0] cfg_lane_under_test;
wire cfg_select_deemph_var_mux, cfg_selectable_deemph_bit_mux; //cfg_select_deemph_var_mux: select_deemphasis variable mux, cfg_selectable_deemph_bit_mux: mux for selectable deemphasis bit in Tx TS2s
wire [1:0] cfg_select_deemph_mux_bus = {cfg_selectable_deemph_bit_mux, cfg_select_deemph_var_mux};
// {force lane flip enable, the lane number of under test, Tx modified compliance pattern, gen5 loopback eq enable, mod ts support}
wire [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl = {cfg_force_lane_flip, cfg_lane_under_test, cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn, cfg_do_g5_lpbk_eq, cfg_mod_ts}; //lut = Lane Under _test

assign cfg_gen2_n_fts           = cfg_comm_clk_config ? pl_reg_14 : pl_reg_172;
assign cfg_lane_en              = {pl_reg_bcm36_nhs_d.pl_reg_174[0], pl_reg_bcm36_nhs_d.pl_reg_173};
assign cfg_phy_txswing          = pl_reg_174[2];
assign cfg_up_sel_deemph        = pl_reg_174[4];
assign cfg_gen1_ei_inference_mode = pl_reg_174[5];
assign cfg_select_deemph_var_mux  = pl_reg_174[6];
assign cfg_selectable_deemph_bit_mux = pl_reg_174[7];
assign cfg_lane_under_test      = pl_reg_bcm36_nhs_d.pl_reg_175[3:0];    
assign cfg_do_g5_lpbk_eq        = pl_reg_175[4];
assign cfg_lpbk_slave_tx_g5_mod_cmpl_ptrn = pl_reg_175[5];
assign cfg_force_lane_flip      = pl_reg_bcm36_nhs_d.pl_reg_175[6];
assign cfg_mod_ts               = pl_reg_175[7];
assign cfg_directed_speed_change= pl_reg_174[1];
assign cfg_tx_compliance_rcv    = pl_reg_174[3];

wire   default_speed_change;
assign default_speed_change = `DEFAULT_GEN2_SPEED_CHANGE;
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_174[0]   <= #TP 1'b1;
        pl_reg_173      <= #TP NL;                         // Number of lanes (1-256)
        pl_reg_174[1]   <= #TP `DEFAULT_GEN2_SPEED_CHANGE;  // Directed speed change
        pl_reg_174[2]   <= #TP `DEFAULT_GEN2_TXSWING;       // Tx Swing
        pl_reg_174[3]   <= #TP 0;                           // TX Compliance Receive
        pl_reg_174[4]   <= #TP `SEL_DE_EMPHASIS;            // Selectable de-emphasis (upstream port only)
        pl_reg_174[5]   <= #TP 1'b0;                        // EI inference mode for Gen1. default = 0 - using rxelecidle == 1; 1 - using rxvalid == 0
        pl_reg_174[6]   <= #TP `DEFAULT_SELECT_DEEMPH_VAR_MUX; // select_deemphasis variable mux
        pl_reg_174[7]   <= #TP `DEFAULT_SELECTABLE_DEEMPH_BIT_MUX;  // selectable deemphasis bit mux
    end
    else begin
        pl_reg_173      <= #TP (write_pulse[1] & pl_reg_id[67]) ? lbc_cdm_data[15:8] : pl_reg_173;
        pl_reg_174[0]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[16]   : pl_reg_174[0];
        pl_reg_174[1]   <= #TP smlh_core_rst_n_release_pulse ? default_speed_change : //assign DEFAULT_GEN2_SPEED_CHANGE when core_rst_n release
                                                               smlh_dir_spd_chg_rising_edge ? 1'b0 :                  //clear if speed change is initiated
                                                               (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[17]   : pl_reg_174[1];
        pl_reg_174[2]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[18]   : pl_reg_174[2];
        pl_reg_174[3]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[19]   : pl_reg_174[3];
        pl_reg_174[4]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[20]   : pl_reg_174[4];

        pl_reg_174[5]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[21]   : pl_reg_174[5];
        pl_reg_174[6]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[22]   : pl_reg_174[6];
        pl_reg_174[7]   <= #TP (write_pulse[2] & pl_reg_id[67]) ? lbc_cdm_data[23]   : pl_reg_174[7];
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_175[4]   <= #TP `CX_DEFAULT_GEN5_EQ_FOR_LOOPBACK;                 // enable Gen5 EQ for loopback
        pl_reg_175[5]   <= #TP `CX_DEFAULT_GEN5_TX_MOD_CMPL_PATTERN_FOR_LOOPBACK;// master tells slave to tx modified compliance pattern
        pl_reg_175[3:0] <= #TP `CX_DEFAULT_LANE_UNDER_TEST; // lane under test
        pl_reg_175[6]   <= #TP 0;                           // Force Lane Flip
        pl_reg_175[7]   <= #TP `CX_MOD_TS_FMT_SUPPORT_VALUE;// mod ts support
    end
    else begin
        pl_reg_175[3:0] <= #TP (write_pulse[3] & pl_reg_id[67] & lbc_cdm_dbi) ? lbc_cdm_data[27:24]: pl_reg_175[3:0];
        pl_reg_175[4]   <= #TP (write_pulse[3] & pl_reg_id[67] & lbc_cdm_dbi) ? lbc_cdm_data[28]   : pl_reg_175[4];
        pl_reg_175[5]   <= #TP (write_pulse[3] & pl_reg_id[67] & lbc_cdm_dbi) ? lbc_cdm_data[29]   : pl_reg_175[5];
        pl_reg_175[3:0] <= #TP (write_pulse[3] & pl_reg_id[67] & lbc_cdm_dbi) ? lbc_cdm_data[27:24]: pl_reg_175[3:0]; // the lane under test for forced_lane_flip and gen5 loopback Eq
        pl_reg_175[6] <= #TP (write_pulse[3] & pl_reg_id[67] & lbc_cdm_dbi) ? lbc_cdm_data[30]: pl_reg_175[6]; //force lane flip
        pl_reg_175[7] <= #TP (write_pulse[3] & pl_reg_id[67] & lbc_cdm_dbi) ? lbc_cdm_data[31]: pl_reg_175[7]; //mod ts support
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        pl_reg_172      <= #TP `DEFAULT_GEN2_N_FTS;         // N_FTS
    end
    else begin
        pl_reg_172      <= #TP (write_pulse[0] & pl_reg_id[67]) ? lbc_cdm_data[7:0]  : pl_reg_172;
    end
end


//------------------------------------------------------------------------------
// PHY status register
// cpl_reg_id       - 68
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176
// -----------------------------------------------------------------------------

assign {pl_reg_179, pl_reg_178, pl_reg_177, pl_reg_176} = phy_cfg_status;

//------------------------------------------------------------------------------
// PHY control register
// cpl_reg_id       - 69
// Length           - 4 bytes
// Default value    -
// Core register    - pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180
// -----------------------------------------------------------------------------

assign cfg_phy_control = {pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180};

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        {pl_reg_183, pl_reg_182, pl_reg_181, pl_reg_180}  <= #TP `DEFAULT_PHY_CONTROL;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        pl_reg_180 <= #TP (write_pulse[0] & pl_reg_id[69]) ? lbc_cdm_data[7:0]   : pl_reg_180;
        pl_reg_181 <= #TP (write_pulse[1] & pl_reg_id[69]) ? lbc_cdm_data[15:8]  : pl_reg_181;
        pl_reg_182 <= #TP (write_pulse[2] & pl_reg_id[69]) ? lbc_cdm_data[23:16] : pl_reg_182;
        pl_reg_183 <= #TP (write_pulse[3] & pl_reg_id[69]) ? lbc_cdm_data[31:24] : pl_reg_183;
    end
end


//------------------------------------------------------------------------------
// Reserved for future use
// pl_reg_id        - 70
// Length           -
// Default value    -
// Core register    - pl_reg_187, pl_reg_186, pl_reg_185, pl_reg_184
// -----------------------------------------------------------------------------
assign pl_reg_184 = 8'b0;
assign pl_reg_185 = 8'b0;
assign pl_reg_186 = 8'b0;
assign pl_reg_187 = 8'b0;

//------------------------------------------------------------------------------
// PCIe Gen 3 Control Register
// cpl_reg_id       - 100
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_195, pl_reg_194, pl_reg_193, pl_reg_192}
// -----------------------------------------------------------------------------

// export these bits as one single bus for ease of maintenance of the interfaces
`define DEFAULT_RATE_SHADOW_SEL                     2'b00

`define DEFAULT_GEN4_AUTO_EQ_DISABLE                1'b0
`define DEFAULT_GEN5_AUTO_EQ_DISABLE                1'b0
`define DEFAULT_GEN6_AUTO_EQ_DISABLE                1'b0
`define DEFAULT_GEN3_EQ_INVREQ_EVAL_DIFF_DISABLE    1'b0
`define DEFAULT_GEN3_DC_BALANCE_DISABLE             1'b0
`define DEFAULT_GEN3_DLLP_XMT_DELAY_DISABLE         1'b0
`define DEFAULT_GEN3_EQUALIZATION_DISABLE           1'b0

`define DEFAULT_GEN4_EQUALIZATION_PHASE23_DISABLE   1'b0
`define DEFAULT_GEN5_EQUALIZATION_PHASE23_DISABLE   1'b0
`define DEFAULT_GEN6_EQUALIZATION_PHASE23_DISABLE   1'b0
`define DEFAULT_GEN3_EQUALIZATION_PHASE23_DISABLE   1'b0
`define DEFAULT_GEN3_SCRAMBLER_DISABLE              1'b0

assign pl_reg_195[7:2] = 6'b0;

// 00b: Gen3, 01b: Gen4, 10b: Gen5, 11b: Gen6
always @(posedge core_clk or negedge sticky_rst_n) begin : gen3_control_reg_seqa_PROC
    if (!sticky_rst_n) begin
        pl_reg_195[1:0] <= #TP `DEFAULT_RATE_SHADOW_SEL;
    end else begin
        pl_reg_195[1:0] <= #TP (write_pulse[3] & pl_reg_id[100]) ? lbc_cdm_data[25:24] : pl_reg_195[1:0];
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin : gen3_control_reg_seq_PROC
    if (!sticky_rst_n) begin
        pl_g4r_194[7]   <= #TP 0; //Reserved
        pl_g4r_194[6]   <= #TP `DEFAULT_GEN4_USP_SEND_8GT_EQ_TS2_DISABLE;
        pl_g4r_194[5]   <= #TP `DEFAULT_GEN4_AUTO_EQ_DISABLE;
        pl_g4r_194[4]   <= #TP 0; //Reserved
        pl_g4r_194[3]   <= #TP 0; //Reserved
        pl_g4r_194[2:0] <= #TP 0; //Reserved
        pl_g5r_194[7]   <= #TP 0; //Reserved
        pl_g5r_194[6]   <= #TP `DEFAULT_GEN5_USP_SEND_16GT_EQ_TS2_DISABLE;
        pl_g5r_194[5]   <= #TP `DEFAULT_GEN5_AUTO_EQ_DISABLE;
        pl_g5r_194[4]   <= #TP 0; //Reserved
        pl_g5r_194[3]   <= #TP 0; //Reserved
        pl_g5r_194[2:0] <= #TP 0; //Reserved
        pl_g6r_194[7]   <= #TP 0; //Reserved
        pl_g6r_194[6]   <= #TP `DEFAULT_GEN6_USP_SEND_16GT_EQ_TS2_DISABLE;
        pl_g6r_194[5]   <= #TP `DEFAULT_GEN6_AUTO_EQ_DISABLE;
        pl_g6r_194[4]   <= #TP 0; //Reserved
        pl_g6r_194[3]   <= #TP 0; //Reserved
        pl_g6r_194[2:0] <= #TP 0; //Reserved
        pl_g3r_194[7]   <= #TP `DEFAULT_GEN3_EQ_INVREQ_EVAL_DIFF_DISABLE;
        pl_g3r_194[6:5] <= #TP 0; //Reserved
        pl_g3r_194[4]   <= #TP 0; //Reserved
        pl_g3r_194[3]   <= #TP 0; //Reserved
        pl_g3r_194[2]   <= #TP `DEFAULT_GEN3_DC_BALANCE_DISABLE;
        pl_g3r_194[1]   <= #TP `DEFAULT_GEN3_DLLP_XMT_DELAY_DISABLE;
        pl_g3r_194[0]   <= #TP `DEFAULT_GEN3_EQUALIZATION_DISABLE;
        pl_g4r_193[7:6] <= #TP 0; //Reserved
        pl_g4r_193[5]   <= #TP `DEFAULT_GEN4_RXEQ_RGRDLESS_RXTS;
        pl_g4r_193[4]   <= #TP `DEFAULT_GEN4_RXEQ_PH01_EN;
        pl_g4r_193[3:2] <= #TP 0; //Reserved
        pl_g4r_193[1]   <= #TP `DEFAULT_GEN4_EQUALIZATION_PHASE23_DISABLE;
        pl_g4r_193[0]   <= #TP 0; //Reserved
        pl_g5r_193[7:6] <= #TP 0; //Reserved
        pl_g5r_193[5]   <= #TP `DEFAULT_GEN5_RXEQ_RGRDLESS_RXTS;
        pl_g5r_193[4]   <= #TP `DEFAULT_GEN5_RXEQ_PH01_EN;
        pl_g5r_193[3:2] <= #TP 0; //Reserved
        pl_g5r_193[1]   <= #TP `DEFAULT_GEN5_EQUALIZATION_PHASE23_DISABLE;
        pl_g5r_193[0]   <= #TP 0; //Reserved
        pl_g6r_193[7:6] <= #TP 0; //Reserved
        pl_g6r_193[5]   <= #TP `DEFAULT_GEN6_RXEQ_RGRDLESS_RXTS;
        pl_g6r_193[4]   <= #TP `DEFAULT_GEN6_RXEQ_PH01_EN;
        pl_g6r_193[3:2] <= #TP 0; //Reserved
        pl_g6r_193[1]   <= #TP `DEFAULT_GEN6_EQUALIZATION_PHASE23_DISABLE;
        pl_g6r_193[0]   <= #TP 0; //Reserved
        pl_g3r_193[7]   <= #TP `DEFAULT_GEN3_EQ_PSET_COEF_MAP_MODE_PROG; //Enable programmable table
        pl_g3r_193[6]   <= #TP 0; //Reserved
        pl_g3r_193[5]   <= #TP `DEFAULT_GEN3_RXEQ_RGRDLESS_RXTS;
        pl_g3r_193[4]   <= #TP `DEFAULT_GEN3_RXEQ_PH01_EN;
        pl_g3r_193[3]   <= #TP `DEFAULT_GEN3_AUTONOMOUS_EQ_REQ_DISABLE;
        pl_g3r_193[2]   <= #TP `DEFAULT_GEN3_REQ_RST_EIEOS_CNT_EQ_DISABLE;
        pl_g3r_193[1]   <= #TP `DEFAULT_GEN3_EQUALIZATION_PHASE23_DISABLE;
        pl_g3r_193[0]   <= #TP `DEFAULT_GEN3_SCRAMBLER_DISABLE;
        pl_reg_192[7:2] <= #TP 0; //Reserved
        pl_reg_192[1]   <= #TP `DEFAULT_NO_SEED_VALUE_CHANGE;      //No Seed Value Change
        pl_reg_192[0]   <= #TP `DEFAULT_GEN3_ZRXDC_NONCOMPL;       // "8 GT/s Receiver Impedance" ECN, default value of Zrxdc non compliance bit
                                                                   // Defined in DWC_pcie_common_cc_constants.v
    end
    else begin
        pl_g4r_194[7]   <= #TP 0; //Reserved
        pl_g4r_194[6:5] <= #TP (write_pulse[2] & pl_reg_id[100] & rate_shadow_sel==2'b01) ? lbc_cdm_data[22:21] : pl_g4r_194[6:5];
        pl_g4r_194[4]   <= #TP 0; //Reserved
        pl_g4r_194[3]   <= #TP 0; //Reserved
        pl_g4r_194[2:0] <= #TP 0; //Reserved
        pl_g5r_194[7]   <= #TP 0; //Reserved
        pl_g5r_194[6:5] <= #TP (write_pulse[2] & pl_reg_id[100] & rate_shadow_sel==2'b10) ? lbc_cdm_data[22:21] : pl_g5r_194[6:5];
        pl_g5r_194[4]   <= #TP 0; //Reserved
        pl_g5r_194[3]   <= #TP 0; //Reserved
        pl_g5r_194[2:0] <= #TP 0; //Reserved
        pl_g6r_194[7]   <= #TP 0; //Reserved
        pl_g6r_194[6:5] <= #TP (write_pulse[2] & pl_reg_id[100] & rate_shadow_sel==2'b11) ? lbc_cdm_data[22:21] : pl_g6r_194[6:5];
        pl_g6r_194[4]   <= #TP 0; //Reserved
        pl_g6r_194[3]   <= #TP 0; //Reserved
        pl_g6r_194[2:0] <= #TP 0; //Reserved
        pl_g3r_194[7]   <= #TP (write_pulse[2] & pl_reg_id[100]) ? lbc_cdm_data[23] : pl_g3r_194[7];
        pl_g3r_194[6:5] <= #TP 0; //Reserved
        pl_g3r_194[4]   <= #TP 0; //Reserved
        pl_g3r_194[3]   <= #TP 0; //Reserved
        pl_g3r_194[2:0] <= #TP (write_pulse[2] & pl_reg_id[100]) ? lbc_cdm_data[18:16] : pl_g3r_194[2:0];
        pl_g4r_193[7:6] <= #TP 0; //Reserved
        pl_g4r_193[5]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b01) ? lbc_cdm_data[13] : pl_g4r_193[5];
        pl_g4r_193[4]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b01) ? lbc_cdm_data[12] : pl_g4r_193[4];
        pl_g4r_193[3:2] <= #TP 0; //Reserved
        pl_g4r_193[1]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b01) ? lbc_cdm_data[9] : pl_g4r_193[1];
        pl_g4r_193[0]   <= #TP 0; //Reserved
        pl_g5r_193[7:6] <= #TP 0; //Reserved
        pl_g5r_193[5]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b10) ? lbc_cdm_data[13] : pl_g5r_193[5];
        pl_g5r_193[4]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b10) ? lbc_cdm_data[12] : pl_g5r_193[4];
        pl_g5r_193[3:2] <= #TP 0; //Reserved
        pl_g5r_193[1]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b10) ? lbc_cdm_data[9] : pl_g5r_193[1];
        pl_g5r_193[0]   <= #TP 0; //Reserved
        pl_g6r_193[7:6] <= #TP 0; //Reserved
        pl_g6r_193[5]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b11) ? lbc_cdm_data[13] : pl_g6r_193[5];
        pl_g6r_193[4]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b11) ? lbc_cdm_data[12] : pl_g6r_193[4];
        pl_g6r_193[3:2] <= #TP 0; //Reserved
        pl_g6r_193[1]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b11) ? lbc_cdm_data[9] : pl_g6r_193[1];
        pl_g6r_193[0]   <= #TP 0; //Reserved
        pl_g3r_193[7]   <= #TP (write_pulse[1] & pl_reg_id[100]) ? lbc_cdm_data[15]  : pl_g3r_193[7];
        pl_g3r_193[6]   <= #TP 0; //Reserved
        pl_g3r_193[5]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b00) ? lbc_cdm_data[13] : pl_g3r_193[5];
        pl_g3r_193[4]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b00) ? lbc_cdm_data[12] : pl_g3r_193[4];
        pl_g3r_193[3:2] <= #TP (write_pulse[1] & pl_reg_id[100]) ? lbc_cdm_data[11:10] : pl_g3r_193[3:2];
        pl_g3r_193[1]   <= #TP (write_pulse[1] & pl_reg_id[100] & rate_shadow_sel==2'b00) ? lbc_cdm_data[9] : pl_g3r_193[1];
        pl_g3r_193[0]   <= #TP (write_pulse[1] & pl_reg_id[100]) ? lbc_cdm_data[8]  : pl_g3r_193[0];
        pl_reg_192[7:2] <= #TP 0; //Reserved
        pl_reg_192[1]   <= #TP (write_pulse[0] & pl_reg_id[100]) ? lbc_cdm_data[1]  : pl_reg_192[1];
        pl_reg_192[0]   <= #TP (write_pulse[0] & pl_reg_id[100]) ? lbc_cdm_data[0]  : pl_reg_192[0];
    end
end

assign pl_reg_193[0]   = pl_g3r_193[0];
assign pl_reg_193[1]   = (rate_shadow_sel==2'b00) ? pl_g3r_193[1] : (rate_shadow_sel==2'b01) ? pl_g4r_193[1] : (rate_shadow_sel==2'b10) ? pl_g5r_193[1] : pl_g6r_193[1];
assign pl_reg_193[3:2] = pl_g3r_193[3:2];
assign pl_reg_193[4]   = (rate_shadow_sel==2'b00) ? pl_g3r_193[4] : (rate_shadow_sel==2'b01) ? pl_g4r_193[4] : (rate_shadow_sel==2'b10) ? pl_g5r_193[4] : pl_g6r_193[4];
assign pl_reg_193[5]   = (rate_shadow_sel==2'b00) ? pl_g3r_193[5] : (rate_shadow_sel==2'b01) ? pl_g4r_193[5] : (rate_shadow_sel==2'b10) ? pl_g5r_193[5] : pl_g6r_193[5];
assign pl_reg_193[7:6] = pl_g3r_193[7:6];
assign pl_reg_194[2:0] = pl_g3r_194[2:0];
assign pl_reg_194[3]   = pl_g3r_194[3];
assign pl_reg_194[4]   = pl_g3r_194[4];
assign pl_reg_194[6:5] = (rate_shadow_sel==2'b00) ? pl_g3r_194[6:5] : (rate_shadow_sel==2'b01) ? pl_g4r_194[6:5] : (rate_shadow_sel==2'b10) ? pl_g5r_194[6:5] : pl_g6r_194[6:5];
assign pl_reg_194[7]   = pl_g3r_194[7];

assign cfg_pl_gen3_control = {pl_g3r_193[7], pl_g3r_193[5], pl_g3r_194[7], pl_g3r_194[2:0], pl_g3r_193[4:1],pl_reg_bcm36_nhs_d.pl_g3r_193[0]};
assign cfg_pl_gen4_control = {pl_g4r_193[5], pl_g4r_194[6:5], pl_g4r_193[4] , pl_g4r_193[1]};
assign cfg_pl_gen5_control = {pl_g5r_193[5], pl_g5r_194[6:5], pl_g5r_193[4] , pl_g5r_193[1]};
assign cfg_pl_gen6_control = {pl_g6r_193[5], pl_g6r_194[6:5], pl_g6r_193[4] , pl_g6r_193[1]};
assign rate_shadow_sel = pl_reg_195[1:0];

// For "8 GT/s Receiver Impedance" ECN, register bit field indicating non compliance of 2.5 GT/s receiver impedance while in 8GT/s mode.
assign cfg_pl_gen3_zrxdc_noncompl = pl_reg_192[0];
assign cfg_no_seed_value_change   = pl_reg_192[1];




//-------------------------------------------------------------------------------------------------------------
//
// Istantiate Gen3 Transmit Equalization Programmable Presets to Coefficients Mapping Table.
//
//-------------------------------------------------------------------------------------------------------------


// instance(s) of preset to coefficient mapping table for Tx equalization
cdm_pl_pset_coefs

u_cdm_pl_pset_coefs (
    //input
    .core_clk            (core_clk),
    .non_sticky_rst_n    (non_sticky_rst_n),
    .sticky_rst_n        (sticky_rst_n),
    .pl_reg_id           (pl_reg_pset_coef_id),
    .lbc_cdm_data        (lbc_cdm_data[21:0]),
    .write_pulse         (write_pulse[2:0]),
    .read_pulse          (read_pulse),
    .rate_shadow_sel     (rate_shadow_sel),

    //output
    .pl_reg_fs_lf        (pl_reg_fs_lf),
    .pl_reg_coef         (pl_reg_coef),
    .pl_reg_pseti        (pl_reg_pseti),
    .pl_reg_violate_rules_prog_coef (pl_reg_violate_rules_prog_coef),
    .cfg_gen3_eq_fs_lf   (cfg_gen3_eq_fs_lf),
    .cfg_gen4_eq_fs_lf   (cfg_gen4_eq_fs_lf),
    .cfg_gen5_eq_fs_lf   (cfg_gen5_eq_fs_lf),
    .cfg_gen6_eq_fs_lf   (cfg_gen6_eq_fs_lf),
    .cfg_gen3_eq_coef    (cfg_gen3_eq_coef)
    , .cfg_gen4_eq_coef    (cfg_gen4_eq_coef)
    , .cfg_gen5_eq_coef    (cfg_gen5_eq_coef)
    , .cfg_gen6_eq_coef    (cfg_gen6_eq_coef)
);



//-------------------------------------------------------------------------------------------------------------
//
// END of Gen3 Transmit Equalization Programmable Presets to Coefficients Mapping Table instantiation
//
//-------------------------------------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// PCIe Gen 3 EQ Control Register
// cpl_reg_id       - 106
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_ec3, pl_reg_ec2, pl_reg_ec1, pl_reg_ec0
// -----------------------------------------------------------------------------

// export these bits as one single bus for ease of maintenance of the interfaces
`define DEFAULT_GEN3_EQ_PSET_REQ_AS_COEF  1'b0

`define DEFAULT_GEN4_EQ_PSET_REQ_AS_COEF  1'b0
`define DEFAULT_GEN5_EQ_PSET_REQ_AS_COEF  1'b0
`define DEFAULT_GEN6_EQ_PSET_REQ_AS_COEF  1'b0

// EQ feedback mode from PHY for remote partner
always @(posedge core_clk or negedge sticky_rst_n) begin : gen3_eq_feedback_mode_PROC
    if (!sticky_rst_n) begin
        pl_g3r_ec0[3:0] <= #TP `DEFAULT_GEN3_EQ_FB_MODE;
        pl_g3r_ec0[4]   <= #TP `DEFAULT_GEN3_EQ_PHASE23_EXIT_MODE;
        pl_g3r_ec0[5]   <= #TP `DEFAULT_GEN3_EQ_EVAL_2MS_DISABLE;
        pl_g3r_ec0[6]   <= #TP `DEFAULT_GEN3_LOWER_RATE_EQ_REDO_ENABLE;  //Gen3 and Gen4 share the bit
        pl_g3r_ec0[7]   <= #TP `DEFAULT_GEN3_EQ_EVAL_2MS_EXTEND;
        {pl_g3r_ec2[7:0],pl_g3r_ec1[7:0]} <= #TP `DEFAULT_GEN3_EQ_PSET_REQ_VEC;
        pl_g3r_ec3[0]   <= #TP `DEFAULT_GEN3_EQ_FOM_INC_INITIAL_EVAL;
        pl_g3r_ec3[1]   <= #TP `DEFAULT_GEN3_EQ_PSET_REQ_AS_COEF;
        pl_g3r_ec3[2]   <= #TP `DEFAULT_GEN3_REQ_SEND_CONSECUTIVE_EIEOS_FOR_PSET_MAP;
        pl_g3r_ec3[5:3] <= #TP `DEFAULT_EQ_REQ_NUM;
        pl_g3r_ec3[6]   <= #TP `DEFAULT_SUPPORT_FINITE_EQ_REQUEST;
        pl_g3r_ec3[7]   <= #TP 0; //Reserved
        pl_g4r_ec0[3:0] <= #TP `DEFAULT_GEN4_EQ_FB_MODE;
        pl_g4r_ec0[4]   <= #TP `DEFAULT_GEN4_EQ_PHASE23_EXIT_MODE;
        pl_g4r_ec0[5]   <= #TP `DEFAULT_GEN4_EQ_EVAL_2MS_DISABLE;
        pl_g4r_ec0[6]   <= #TP 0; //Reserved
        pl_g4r_ec0[7]   <= #TP `DEFAULT_GEN4_EQ_EVAL_2MS_EXTEND;
        {pl_g4r_ec2[7:0],pl_g4r_ec1[7:0]} <= #TP `DEFAULT_GEN4_EQ_PSET_REQ_VEC;
        pl_g4r_ec3[0]   <= #TP `DEFAULT_GEN4_EQ_FOM_INC_INITIAL_EVAL;
        pl_g4r_ec3[1]   <= #TP `DEFAULT_GEN4_EQ_PSET_REQ_AS_COEF;
        pl_g4r_ec3[2]   <= #TP `DEFAULT_GEN4_REQ_SEND_CONSECUTIVE_EIEOS_FOR_PSET_MAP;
        pl_g4r_ec3[7:3] <= #TP 0; //Reserved
        pl_g5r_ec0[3:0] <= #TP `DEFAULT_GEN5_EQ_FB_MODE;
        pl_g5r_ec0[4]   <= #TP `DEFAULT_GEN5_EQ_PHASE23_EXIT_MODE;
        pl_g5r_ec0[5]   <= #TP `DEFAULT_GEN5_EQ_EVAL_2MS_DISABLE;
        pl_g5r_ec0[6]   <= #TP 0; //Reserved
        pl_g5r_ec0[7]   <= #TP `DEFAULT_GEN5_EQ_EVAL_2MS_EXTEND;
        {pl_g5r_ec2[7:0],pl_g5r_ec1[7:0]} <= #TP `DEFAULT_GEN5_EQ_PSET_REQ_VEC;
        pl_g5r_ec3[0]   <= #TP `DEFAULT_GEN5_EQ_FOM_INC_INITIAL_EVAL;
        pl_g5r_ec3[1]   <= #TP `DEFAULT_GEN5_EQ_PSET_REQ_AS_COEF;
        pl_g5r_ec3[2]   <= #TP `DEFAULT_GEN5_REQ_SEND_CONSECUTIVE_EIEOS_FOR_PSET_MAP;
        pl_g5r_ec3[7:3] <= #TP 0; //Reserved
        pl_g6r_ec0[3:0] <= #TP `DEFAULT_GEN6_EQ_FB_MODE;
        pl_g6r_ec0[4]   <= #TP `DEFAULT_GEN6_EQ_PHASE23_EXIT_MODE;
        pl_g6r_ec0[5]   <= #TP `DEFAULT_GEN6_EQ_EVAL_2MS_DISABLE;
        pl_g6r_ec0[6]   <= #TP 0; //Reserved
        pl_g6r_ec0[7]   <= #TP `DEFAULT_GEN6_EQ_EVAL_2MS_EXTEND;
        {pl_g6r_ec2[7:0],pl_g6r_ec1[7:0]} <= #TP `DEFAULT_GEN6_EQ_PSET_REQ_VEC;
        pl_g6r_ec3[0]   <= #TP `DEFAULT_GEN6_EQ_FOM_INC_INITIAL_EVAL;
        pl_g6r_ec3[1]   <= #TP `DEFAULT_GEN6_EQ_PSET_REQ_AS_COEF;
        pl_g6r_ec3[2]   <= #TP `DEFAULT_GEN6_REQ_SEND_CONSECUTIVE_EIEOS_FOR_PSET_MAP;
        pl_g6r_ec3[7:3] <= #TP 0; //Reserved
    end else begin
        pl_g3r_ec0[5:0] <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[5:0]   : pl_g3r_ec0[5:0];
        pl_g3r_ec0[6]   <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[6]     : pl_g3r_ec0[6];
        pl_g3r_ec0[7]   <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[7]     : pl_g3r_ec0[7];
        pl_g3r_ec1[7:0] <= #TP (write_pulse[1] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8]  : pl_g3r_ec1[7:0];
        pl_g3r_ec2[7:0] <= #TP (write_pulse[2] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[23:16] : pl_g3r_ec2[7:0];
        pl_g3r_ec3[2:0] <= #TP (write_pulse[3] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[26:24] : pl_g3r_ec3[2:0];
        pl_g3r_ec3[6:3] <= #TP (write_pulse[3] & pl_reg_id[106] & rate_shadow_sel==2'b00) ? lbc_cdm_data[30:27] : pl_g3r_ec3[6:3];
        pl_g3r_ec3[7]   <= #TP 0; //Reserved
        pl_g4r_ec0[5:0] <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b01) ? lbc_cdm_data[5:0]   : pl_g4r_ec0[5:0];
        pl_g4r_ec0[6]   <= #TP 0; //Reserved
        pl_g4r_ec0[7]   <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b01) ? lbc_cdm_data[7]     : pl_g4r_ec0[7];
        pl_g4r_ec1[7:0] <= #TP (write_pulse[1] & pl_reg_id[106] & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8]  : pl_g4r_ec1[7:0];
        pl_g4r_ec2[7:0] <= #TP (write_pulse[2] & pl_reg_id[106] & rate_shadow_sel==2'b01) ? lbc_cdm_data[23:16] : pl_g4r_ec2[7:0];
        pl_g4r_ec3[2:0] <= #TP (write_pulse[3] & pl_reg_id[106] & rate_shadow_sel==2'b01) ? lbc_cdm_data[26:24] : pl_g4r_ec3[2:0];
        pl_g4r_ec3[7:3] <= #TP 0; //Reserved
        pl_g5r_ec0[5:0] <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b10) ? lbc_cdm_data[5:0]   : pl_g5r_ec0[5:0];
        pl_g5r_ec0[6]   <= #TP 0; //Reserved
        pl_g5r_ec0[7]   <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b10) ? lbc_cdm_data[7]     : pl_g5r_ec0[7];
        pl_g5r_ec1[7:0] <= #TP (write_pulse[1] & pl_reg_id[106] & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8]  : pl_g5r_ec1[7:0];
        pl_g5r_ec2[7:0] <= #TP (write_pulse[2] & pl_reg_id[106] & rate_shadow_sel==2'b10) ? lbc_cdm_data[23:16] : pl_g5r_ec2[7:0];
        pl_g5r_ec3[2:0] <= #TP (write_pulse[3] & pl_reg_id[106] & rate_shadow_sel==2'b10) ? lbc_cdm_data[26:24] : pl_g5r_ec3[2:0];
        pl_g5r_ec3[7:3] <= #TP 0; //Reserved
        pl_g6r_ec0[5:0] <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b11) ? lbc_cdm_data[5:0]   : pl_g6r_ec0[5:0];
        pl_g6r_ec0[6]   <= #TP 0; //Reserved
        pl_g6r_ec0[7]   <= #TP (write_pulse[0] & pl_reg_id[106] & rate_shadow_sel==2'b11) ? lbc_cdm_data[7]     : pl_g6r_ec0[7];
        pl_g6r_ec1[7:0] <= #TP (write_pulse[1] & pl_reg_id[106] & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_g6r_ec1[7:0];
        pl_g6r_ec2[7:0] <= #TP (write_pulse[2] & pl_reg_id[106] & rate_shadow_sel==2'b11) ? lbc_cdm_data[23:16] : pl_g6r_ec2[7:0];
        pl_g6r_ec3[2:0] <= #TP (write_pulse[3] & pl_reg_id[106] & rate_shadow_sel==2'b11) ? lbc_cdm_data[26:24] : pl_g6r_ec3[2:0];
        pl_g6r_ec3[7:3] <= #TP 0; //Reserved
    end
end //always @(posedge

assign pl_reg_ec0 = (rate_shadow_sel==2'b00) ? pl_g3r_ec0 : (rate_shadow_sel==2'b01) ? pl_g4r_ec0 : (rate_shadow_sel==2'b10) ? pl_g5r_ec0 : pl_g6r_ec0;
assign pl_reg_ec1 = (rate_shadow_sel==2'b00) ? pl_g3r_ec1 : (rate_shadow_sel==2'b01) ? pl_g4r_ec1 : (rate_shadow_sel==2'b10) ? pl_g5r_ec1 : pl_g6r_ec1;
assign pl_reg_ec2 = (rate_shadow_sel==2'b00) ? pl_g3r_ec2 : (rate_shadow_sel==2'b01) ? pl_g4r_ec2 : (rate_shadow_sel==2'b10) ? pl_g5r_ec2 : pl_g6r_ec2;
assign pl_reg_ec3 = (rate_shadow_sel==2'b00) ? pl_g3r_ec3 : (rate_shadow_sel==2'b01) ? pl_g4r_ec3 : (rate_shadow_sel==2'b10) ? pl_g5r_ec3 : pl_g6r_ec3;

wire [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control;
assign cfg_pl_gen3_eq_control = {pl_g3r_ec0[7], pl_g3r_ec3[6:3], pl_g3r_ec0[6], pl_g3r_ec3[2:0], pl_g3r_ec2[7:0], pl_g3r_ec1[7:0], pl_g3r_ec0[5:0]};
wire [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control;
assign cfg_pl_gen6_eq_control = {pl_g6r_ec0[7], pl_g6r_ec3[2:0], pl_g6r_ec2[7:0], pl_g6r_ec1[7:0], pl_g6r_ec0[5:0]};
wire [`CX_PL_GEN5_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control;
assign cfg_pl_gen5_eq_control = {pl_g5r_ec0[7], pl_g5r_ec3[2:0], pl_g5r_ec2[7:0], pl_g5r_ec1[7:0], pl_g5r_ec0[5:0]};
wire [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control;
assign cfg_pl_gen4_eq_control = {pl_g4r_ec0[7], pl_g4r_ec3[2:0], pl_g4r_ec2[7:0], pl_g4r_ec1[7:0], pl_g4r_ec0[5:0]};


//------------------------------------------------------------------------------
// PCIe Gen 3 EQ Direction Change Feedback Mode Control Register
// cpl_reg_id       - 107
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_dc3, pl_reg_dc2, pl_reg_dc1, pl_reg_dc0
// -----------------------------------------------------------------------------

// export these bits as one single bus for ease of maintenance of the interfaces

// EQ feedback mode Direction Change Control
always @(posedge core_clk or negedge sticky_rst_n) begin : gen3_eq_feedback_mode_dirchange_PROC
    if (!sticky_rst_n) begin
        pl_g3r_dc0[4:0] <= #TP `DEFAULT_GEN3_EQ_FMDC_T_MIN_PHASE23; // Min time to remain in EQ Mst.
        {pl_g3r_dc1[1:0], pl_g3r_dc0[7:5]} <= #TP  `DEFAULT_GEN3_EQ_FMDC_N_EVALS; // Num of evals
        pl_g3r_dc1[5:2] <= #TP `DEFAULT_GEN3_EQ_FMDC_MAX_PRE_CUSROR_DELTA; //  Convergence Window for C-1
        {pl_g3r_dc2[1:0], pl_g3r_dc1[7:6]} <= #TP `DEFAULT_GEN3_EQ_FMDC_MAX_POST_CUSROR_DELTA; // Convergence Window for C+1
        pl_g3r_dc2[7:2] <= #TP 0;
        pl_g4r_dc0[4:0] <= #TP `DEFAULT_GEN4_EQ_FMDC_T_MIN_PHASE23; // Min time to remain in EQ Mst.
        {pl_g4r_dc1[1:0], pl_g4r_dc0[7:5]} <= #TP  `DEFAULT_GEN4_EQ_FMDC_N_EVALS; // Num of evals
        pl_g4r_dc1[5:2] <= #TP `DEFAULT_GEN4_EQ_FMDC_MAX_PRE_CUSROR_DELTA; //  Convergence Window for C-1
        {pl_g4r_dc2[1:0], pl_g4r_dc1[7:6]} <= #TP `DEFAULT_GEN4_EQ_FMDC_MAX_POST_CUSROR_DELTA; // Convergence Window for C+1
        pl_g4r_dc2[7:2] <= #TP 0;
        pl_g5r_dc0[4:0] <= #TP `DEFAULT_GEN5_EQ_FMDC_T_MIN_PHASE23; // Min time to remain in EQ Mst.
        {pl_g5r_dc1[1:0], pl_g5r_dc0[7:5]} <= #TP  `DEFAULT_GEN5_EQ_FMDC_N_EVALS; // Num of evals
        pl_g5r_dc1[5:2] <= #TP `DEFAULT_GEN5_EQ_FMDC_MAX_PRE_CUSROR_DELTA; //  Convergence Window for C-1
        {pl_g5r_dc2[1:0], pl_g5r_dc1[7:6]} <= #TP `DEFAULT_GEN5_EQ_FMDC_MAX_POST_CUSROR_DELTA; // Convergence Window for C+1
        pl_g5r_dc2[7:2] <= #TP 0;
        pl_g6r_dc0[4:0]                    <= #TP `DEFAULT_GEN6_EQ_FMDC_T_MIN_PHASE23;         // Min time to remain in EQ Mst.
        {pl_g6r_dc1[1:0], pl_g6r_dc0[7:5]} <= #TP `DEFAULT_GEN6_EQ_FMDC_N_EVALS;               // Num of evals
        pl_g6r_dc2[5:2]                    <= #TP `DEFAULT_GEN6_EQ_FMDC_MAX_PRE_CURSOR2_DELTA; // Convergence Window for C-2
        pl_g6r_dc1[5:2]                    <= #TP `DEFAULT_GEN6_EQ_FMDC_MAX_PRE_CUSROR_DELTA;  // Convergence Window for C-1
        {pl_g6r_dc2[1:0], pl_g6r_dc1[7:6]} <= #TP `DEFAULT_GEN6_EQ_FMDC_MAX_POST_CUSROR_DELTA; // Convergence Window for C+1
        pl_g6r_dc2[7:6]                    <= #TP 0;                                           // Reserved
    end else begin
        pl_g3r_dc0[7:0] <= #TP (write_pulse[0] & pl_reg_id[107] & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0]  : pl_g3r_dc0[7:0];
        pl_g3r_dc1[7:0] <= #TP (write_pulse[1] & pl_reg_id[107] & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8]  : pl_g3r_dc1[7:0];
        pl_g3r_dc2[1:0] <= #TP (write_pulse[2] & pl_reg_id[107] & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16]  : pl_g3r_dc2[1:0];
        pl_g3r_dc2[7:2] <= #TP 0; //Reserved
        pl_g4r_dc0[7:0] <= #TP (write_pulse[0] & pl_reg_id[107] & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0]  : pl_g4r_dc0[7:0];
        pl_g4r_dc1[7:0] <= #TP (write_pulse[1] & pl_reg_id[107] & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8]  : pl_g4r_dc1[7:0];
        pl_g4r_dc2[1:0] <= #TP (write_pulse[2] & pl_reg_id[107] & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16]  : pl_g4r_dc2[1:0];
        pl_g4r_dc2[7:2] <= #TP 0; //Reserved
        pl_g5r_dc0[7:0] <= #TP (write_pulse[0] & pl_reg_id[107] & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0]  : pl_g5r_dc0[7:0];
        pl_g5r_dc1[7:0] <= #TP (write_pulse[1] & pl_reg_id[107] & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8]  : pl_g5r_dc1[7:0];
        pl_g5r_dc2[1:0] <= #TP (write_pulse[2] & pl_reg_id[107] & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16]  : pl_g5r_dc2[1:0];
        pl_g5r_dc2[7:2] <= #TP 0; //Reserved
        pl_g6r_dc0[7:0] <= #TP (write_pulse[0] & pl_reg_id[107] & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_g6r_dc0[7:0];
        pl_g6r_dc1[7:0] <= #TP (write_pulse[1] & pl_reg_id[107] & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_g6r_dc1[7:0];
        pl_g6r_dc2[5:0] <= #TP (write_pulse[2] & pl_reg_id[107] & rate_shadow_sel==2'b11) ? lbc_cdm_data[21:16] : pl_g6r_dc2[5:0];
        pl_g6r_dc2[7:6] <= #TP 0; //Reserved
    end
end //always @(posedge

assign pl_reg_dc0 = (rate_shadow_sel==2'b00) ? pl_g3r_dc0 : (rate_shadow_sel==2'b01) ? pl_g4r_dc0 : (rate_shadow_sel==2'b10) ? pl_g5r_dc0 : pl_g6r_dc0;
assign pl_reg_dc1 = (rate_shadow_sel==2'b00) ? pl_g3r_dc1 : (rate_shadow_sel==2'b01) ? pl_g4r_dc1 : (rate_shadow_sel==2'b10) ? pl_g5r_dc1 : pl_g6r_dc1;
assign pl_reg_dc2 = (rate_shadow_sel==2'b00) ? pl_g3r_dc2 : (rate_shadow_sel==2'b01) ? pl_g4r_dc2 : (rate_shadow_sel==2'b10) ? pl_g5r_dc2 : pl_g6r_dc2;

assign pl_reg_dc3 = 0; //Reserved

assign cfg_fdbk_dirchange_control = {pl_g3r_dc2[1:0], pl_g3r_dc1[7:0], pl_g3r_dc0[7:0]};
assign cfg_gen4_fdbk_dirchange_control = {pl_g4r_dc2[1:0], pl_g4r_dc1[7:0], pl_g4r_dc0[7:0]};
assign cfg_gen5_fdbk_dirchange_control = {pl_g5r_dc2[1:0], pl_g5r_dc1[7:0], pl_g5r_dc0[7:0]};
// At smlh: How to interpret cfg_gen6_fdbk_dirchange_control:
// wire [4:0]  cfg_gen6_eq_dcm_t_min_phase23        = cfg_gen6_fdbk_dirchange_control[4:0];   = pl_g6r_dc0[4:0]
// wire [4:0]  cfg_gen6_eq_dcm_n_evals              = cfg_gen6_fdbk_dirchange_control[9:5];   = {pl_g6r_dc1[1:0], pl_g6r_dc0[7:5]}
// wire [3:0]  cfg_gen6_eq_dcm_max_precursor2_delta = cfg_gen6_fdbk_dirchange_control[13:10]; = pl_g6r_dc2[5:2]
// wire [3:0]  cfg_gen6_eq_dcm_max_precursor_delta  = cfg_gen6_fdbk_dirchange_control[17:14]; = pl_g6r_dc1[5:2]
// wire [3:0]  cfg_gen6_eq_dcm_max_postcursor_delta = cfg_gen6_fdbk_dirchange_control[21:18]; = {pl_g6r_dc2[1:0], pl_g6r_dc1[7:6]}
assign cfg_gen6_fdbk_dirchange_control = {pl_g6r_dc2[1:0], pl_g6r_dc1[7:2], pl_g6r_dc2[5:2], pl_g6r_dc1[1:0], pl_g6r_dc0[7:0]};


//------------------------------------------------------------------------------
// Order Rule Ctrl
// cpl_reg_id       - 109 (offset 0x1b4)
// Length           - 2 byte
// Default value    - 0
// Core register    - {16'h0, pl_reg_240, pl_reg_239}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
      pl_reg_239             <= #TP 8'b0;
      pl_reg_240             <= #TP 8'b0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      // ORDER_RULE_CTRL
      pl_reg_239     <= #TP (write_pulse[0] & pl_reg_id[109]) ? lbc_cdm_data[7:0]  : pl_reg_239;
      pl_reg_240     <= #TP (write_pulse[1] & pl_reg_id[109]) ? lbc_cdm_data[15:8] : pl_reg_240;
    end
end

assign cfg_order_rule_ctrl  = {pl_reg_240, pl_reg_239};

//------------------------------------------------------------------------------
// TRGT_CPL_LUT Delete Entry Ctrl
// cpl_reg_id       - 151 (offset 0x1c8)
// Length           - 4 byte
// Default value    - 0
// Core register    - {pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
      pl_reg_241             <= #TP 8'b0;
      pl_reg_242             <= #TP 8'b0;
      pl_reg_243             <= #TP 8'b0;
      pl_reg_244             <= #TP 8'b0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      // TRGT_CPL_LUT Delete Entry Ctrl
      pl_reg_241     <= #TP (write_pulse[0] & pl_reg_id[151]) ? lbc_cdm_data[7:0]   : pl_reg_241;
      pl_reg_242     <= #TP (write_pulse[1] & pl_reg_id[151]) ? lbc_cdm_data[15:8]  : pl_reg_242;
      pl_reg_243     <= #TP (write_pulse[2] & pl_reg_id[151]) ? lbc_cdm_data[23:16] : pl_reg_243;
      pl_reg_244     <= #TP (write_pulse[3] & pl_reg_id[151]) ? lbc_cdm_data[31:24] : {1'b0, pl_reg_244[6:0]};
    end
end

// cfg_trgt_cpl_lut_delete_entry[31]: This is a one shot bit. A '1' write to this bit triggers the deletion of the entry specified in the lookup_id field.
// This is a self-clearing register field. Reading from this register field always returns a "0".
assign cfg_trgt_cpl_lut_delete_entry  = { pl_reg_244, pl_reg_243, pl_reg_242, pl_reg_241};


//------------------------------------------------------------------------------
// Application Bus and  Device number Status for Root port or Downstream switch port
// pl_reg_id        - `CX_PL_REG + ID_0x410
// Length           - 4 bytes
// Default value    - 0x0000
// Core register    - {16'b0,app_bus_num, app_dev_num, 3'b0}
// -----------------------------------------------------------------------------
  assign app_bus_dev_num_status   = {app_bus_num, app_dev_num, 3'b0};

//------------------------------------------------------------------------------
// Order Rule Ctrl
// cpl_reg_id       - 153 (offset 0x18c)
// Length           - 1 bit (4 byte max)
// Default value    - 1
// Core register    - {16'h0, 8'h0, 5'h0, r_cdm_clk_gating_en, r_axi_clk_gating_en, r_radm_clk_gating_en}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    r_radm_clk_gating_en <= #TP 1'b1;
    r_axi_clk_gating_en  <= #TP 1'b1;
  end else begin
    r_radm_clk_gating_en <= #TP (write_pulse[0] & pl_reg_id[153]) ? lbc_cdm_data[0]  : r_radm_clk_gating_en;
    r_axi_clk_gating_en  <= #TP (write_pulse[0] & pl_reg_id[153]) ? lbc_cdm_data[1]  : r_axi_clk_gating_en;
  end
end
assign cfg_clock_gating_ctrl[1:0]  = { r_axi_clk_gating_en, r_radm_clk_gating_en};

assign cfg_clock_gating_ctrl[2] =  1'b0;

//------------------------------------------------------------------------------
// Enable PIPE Loopback
// cpl_reg_id       - 110 (offset 0x1b8)
// Length           - 4 bytes
// Default value    - 0000h
// Core register    - {pl_reg_203, pl_reg_202, pl_reg_201, pl_reg_200}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_203[7]             <= #TP `DEFAULT_PIPE_LOOPBACK;
      pl_reg_203[6:0]           <= #TP 7'b0;
      pl_reg_202                <= #TP 8'b0;
      {pl_reg_201,pl_reg_200}   <= #TP {NL{1'b1}};
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      // PIPE Looback enable
      pl_reg_203[7]     <= #TP (write_pulse[3] & pl_reg_id[110]) ? lbc_cdm_data[31] : pl_reg_203[7];
      pl_reg_203[6:3]   <= #TP 4'b0;
      // RX status value to inject, this is self clearing
      pl_reg_203[2:0]   <= #TP (write_pulse[3] & pl_reg_id[110]) ? lbc_cdm_data[26:24] : 3'b0;
      // which lane to inject rxstatus value, bit6 => all lanes, bit[5:0]
      // allow lanes 0-31 to be selected
      pl_reg_202[7:6]   <= #TP 2'b0;
      pl_reg_202[5:0]   <= #TP (write_pulse[2] & pl_reg_id[110]) ? lbc_cdm_data[21:16] : pl_reg_202[5:0];
      // {pl_reg_201 , pl_reg_200} specify rxvalid value, default all active
      pl_reg_201        <= #TP (write_pulse[1] & pl_reg_id[110]) ? lbc_cdm_data[15:8]  : pl_reg_201;
      pl_reg_200        <= #TP (write_pulse[0] & pl_reg_id[110]) ? lbc_cdm_data[7:0]   : pl_reg_200;
    end
end


wire [15:0] int_cfg_lpbk_rxvalid = {pl_reg_201,pl_reg_200};
assign cfg_pipe_loopback        = pl_reg_203[7];
assign cfg_rxstatus_lane        = pl_reg_202[5:0];
assign cfg_rxstatus_value       = pl_reg_203[2:0];
assign cfg_lpbk_rxvalid         = int_cfg_lpbk_rxvalid[NL-1:0];

//------------------------------------------------------------------------------
// DBI Read Only Write Enable
// Default Target
// UR CA Error Mask for Target 1
// Also simplified replay timer enable
// cpl_reg_id       - 111 (offset 0x1bc)
// Length           - 1 byte
// Default value    - `CX_DBI_RO_WR_EN
// Core register    - {pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204}
// -----------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_204             <= #TP {1'b0, 1'b1, ARI_DEVICE_NUM, 1'b0,  SIMPLIFIED_REPLAY_TIMER_GEN4, `CX_MASK_UR_CA_4_TRGT1, `DEFAULT_TARGET, `CX_DBI_RO_WR_EN};
      {pl_reg_245[1:0], pl_reg_205} <= #TP `CONFIG_LIMIT;
      {pl_reg_245[3:2]}      <= #TP `TARGET_ABOVE_CONFIG_LIMIT;
      {pl_reg_245[7:4]}      <= #TP {1'b0, `CX_PL_WIRE_WR_DISABLE, P2P_ENABLE, 1'b0}; // bit [6] is PORT_LOGIC_WR_DISABLE
      pl_reg_246[0]          <= #TP 1'b0;
      pl_reg_246[1]          <= #TP `CX_ERR_INJ_WIRE_WR_DISABLE;  //ERR_INJ_WR_DISABLE
      pl_reg_246[7:2]        <= #TP 6'b0;
    end
    else begin
      // dbi_ro_wr_en
      pl_reg_204[0]     <= #TP (app_dbi_ro_wr_disable) ? 1'b0 : (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[0] : pl_reg_204[0];
      pl_reg_204[1]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[1] : pl_reg_204[1];
      pl_reg_204[2]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[2] : pl_reg_204[2];
      pl_reg_204[3]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[3] : pl_reg_204[3]; //simplified replay timer enable
      pl_reg_204[4]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[4] : pl_reg_204[4]; //disable autonomous LTR clear msg generation
      pl_reg_204[5]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[5] : pl_reg_204[5]; //ARI Device Number Enable
      pl_reg_204[6]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[6] : pl_reg_204[6]; //cfg_cplq_mng_en
      pl_reg_204[7]     <= #TP (write_pulse[0] & pl_reg_id[111]) ? lbc_cdm_data[7] : pl_reg_204[7]; //CFG_TLP_BYPASS_EN_REG
      pl_reg_205        <= #TP (write_pulse[1] & pl_reg_id[111]) ? lbc_cdm_data[15:8] : pl_reg_205; //CONFIG_LIMIT_REG[7:0]
      pl_reg_245[1:0]   <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[17:16] : pl_reg_245[1:0];//CONFIG_LIMIT_REG[9:8]
      pl_reg_245[3:2]   <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[19:18] : pl_reg_245[3:2];//TARGET_ABOVE_CONFIG_LIMIT_REG
      pl_reg_245[4]     <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[20]    : pl_reg_245[4];  //P2P_TRACK_CPL_TO_REG
      pl_reg_245[5]     <= #TP (write_pulse[2] & pl_reg_id[111]) ? lbc_cdm_data[21]    : pl_reg_245[5];  //P2P_ERR_RPT_CTRL
      pl_reg_245[6]     <= #TP (write_pulse[2] & pl_reg_id[111] & lbc_cdm_dbi) ? lbc_cdm_data[22] : pl_reg_245[6];  //PORT_LOGIC_WR_DISABLE
      pl_reg_245[7]     <= #TP (write_pulse[2] & pl_reg_id[111] & lbc_cdm_dbi) ? lbc_cdm_data[23] : pl_reg_245[7];  //RAS_REG_PF0_ONLY
      pl_reg_246[0]     <= #TP (write_pulse[3] & pl_reg_id[111] & lbc_cdm_dbi) ? lbc_cdm_data[24] : pl_reg_246[0];  //RASDES_REG_PF0_ONLY
      pl_reg_246[1]     <= #TP (write_pulse[3] & pl_reg_id[111] & lbc_cdm_dbi) ? lbc_cdm_data[25] : pl_reg_246[1];  //ERR_INJ_WR_DISABLE
      pl_reg_246[4:2]   <= #TP (write_pulse[3] & pl_reg_id[111] & lbc_cdm_dbi) ? lbc_cdm_data[28:26] : pl_reg_246[4:2];  //OPTIONAL_OHC_CTRL
      pl_reg_246[5]     <= #TP 1'b0;
      pl_reg_246[7:6]   <= #TP 2'b0;
    end
end

DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      (32),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_misc_control_1_off (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (sticky_rst_n),
`endif // SYNTHESIS
  .data_s  ({pl_reg_246, pl_reg_245, pl_reg_205, pl_reg_204}),
  .data_d  ({pl_reg_246_bcm36, pl_reg_245_bcm36, pl_reg_205_bcm36, pl_reg_204_bcm36})
);

//----------------------------------------------------------------------------------------------------------------------------------------------
// UTILITY register
// cpl_reg_id         - 215 offset 0x580 (0xC80)
// Length             - 4 byte
// Default Value      - 0h
// Core register      - {pl_reg_250, pl_reg_249, pl_reg_248, pl_reg_247}
//----------------------------------------------------------------------------------------------------------------------------------------------
assign cfg_utility = {pl_reg_250, pl_reg_249, pl_reg_248, pl_reg_247};
always @(posedge core_clk or negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    pl_reg_247[7:0] <= #TP 8'h0;
    pl_reg_248[7:0] <= #TP 8'h0;
    pl_reg_249[7:0] <= #TP 8'h0;
    pl_reg_250[7:0] <= #TP 8'h0;
  end else begin
    pl_reg_247[7:0] <= #TP (write_pulse[0] & pl_reg_id[ID_0x580]) ? lbc_cdm_data[7:0]   : pl_reg_247[7:0];
    pl_reg_248[7:0] <= #TP (write_pulse[1] & pl_reg_id[ID_0x580]) ? lbc_cdm_data[15:8]  : pl_reg_248[7:0];
    pl_reg_249[7:0] <= #TP (write_pulse[2] & pl_reg_id[ID_0x580]) ? lbc_cdm_data[23:16] : pl_reg_249[7:0];
    pl_reg_250[7:0] <= #TP (write_pulse[3] & pl_reg_id[ID_0x580]) ? lbc_cdm_data[31:24] : pl_reg_250[7:0];
  end
end

//----------------------------------------------------------------------------------------------------------------------------------------------
// PM_UTILITY read only register
// cpl_reg_id         - 216 offset 0x588 (0xC88)
// Length             - 4 byte
// Default Value      - 0h
// Core register      - {pl_reg_254, pl_reg_253, pl_reg_252, pl_reg_251}
//----------------------------------------------------------------------------------------------------------------------------------------------
always @(posedge core_clk or negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    pl_reg_251[7:0] <= #TP 8'h0;
    pl_reg_252[7:0] <= #TP 8'h0;
    pl_reg_253[7:0] <= #TP 8'h0;
    pl_reg_254[7:0] <= #TP 8'h0;
  end else begin
   
    pl_reg_251[7:0] <= #TP pm_cfg_utility[7:0];
    pl_reg_252[7:0] <= #TP pm_cfg_utility[15:8];
    pl_reg_253[7:0] <= #TP pm_cfg_utility[23:16];
    pl_reg_254[7:0] <= #TP pm_cfg_utility[31:24];
  end
end


assign cfg_optional_ohc = pl_reg_246_bcm36[4:2];


assign   cfg_rasdes_reg_pf0_only = pl_reg_246_bcm36[0];

assign   cfg_ras_reg_pf0_only    = pl_reg_245_bcm36[7];

assign cfg_err_inj_wr_disable        = pl_reg_246_bcm36[1];

assign dbi_ro_wr_en = pl_reg_204_bcm36[0];
assign default_target =
                        pl_reg_204_bcm36[1];
assign ur_ca_mask_4_trgt1 =
                            pl_reg_204_bcm36[2];
assign cfg_disable_ltr_clr_msg = pl_reg_204_bcm36[4];
  assign cfg_cfg_tlp_bypass_en = pl_reg_204_bcm36[7];
  assign cfg_config_limit                = {pl_reg_245_bcm36[1:0], pl_reg_205_bcm36};
  assign cfg_target_above_config_limit   = pl_reg_245_bcm36[3:2];
  assign cfg_p2p_track_cpl_to            = pl_reg_245_bcm36[4];
  assign cfg_p2p_err_rpt_ctrl            = pl_reg_245_bcm36[5];
  assign cfg_pl_wr_disable               = pl_reg_245_bcm36[6];



//------------------------------------------------------------------------------
// Multi Lane Control
// cpl_reg_id       - 112 (offset 0x1c0)
// Length           - 4 byte
// Default value    - 0x0000_0080
// Core register    - {23'h0, pl_reg_mult_0}
// -----------------------------------------------------------------------------

`define DEFAULT_TARGET_LINK_WIDTH                     6'h0
`define DEFAULT_DIRECT_LINK_WIDTH_CHANGE              1'b0
`define DEFAULT_RELIABILITY_LINK_WIDTH_CHANGE_ENABLE  1'b0

assign cfg_pl_multilane_control = pl_reg_mult_0[8:0];

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
      pl_reg_mult_0[5:0]            <= #TP `DEFAULT_TARGET_LINK_WIDTH;
      pl_reg_mult_0[6]              <= #TP `DEFAULT_DIRECT_LINK_WIDTH_CHANGE;
      pl_reg_mult_0[8]              <= #TP `DEFAULT_RELIABILITY_LINK_WIDTH_CHANGE_ENABLE;
    end
    else begin
      pl_reg_mult_0[5:0]            <= #TP                                     (write_pulse[0] & pl_reg_id[112]) ? lbc_cdm_data[5:0] : pl_reg_mult_0[5:0];
      pl_reg_mult_0[6]              <= #TP smlh_dir_linkw_chg_started ? 1'b0 : (write_pulse[0] & pl_reg_id[112]) ? lbc_cdm_data[6]   : pl_reg_mult_0[6]  ;
      pl_reg_mult_0[8]              <= #TP                                     (write_pulse[1] & pl_reg_id[112]) ? lbc_cdm_data[8]   : pl_reg_mult_0[8]  ;
    end
end

// spyglass disable_block W552
// SMD: Bus 'pl_reg_mult_0' is driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_mult_0[7]              <= #TP `DEFAULT_UPCONFIGURE_SUPPORT;
    end
    else begin
      pl_reg_mult_0[7]              <= #TP (write_pulse[0] & pl_reg_id[112]) ? lbc_cdm_data[7] : pl_reg_mult_0[7] ;
    end
end
// spyglass enable_block W552


//------------------------------------------------------------------------------
// PHY InterOp Control
// cpl_reg_id       - 113 (offset 0x1c4)
// Length           - 4 byte
// Default value    -
// Core register    - {pl_reg_phyiop_3, pl_reg_phyiop_2, pl_reg_phyiop_1, pl_reg_phyiop_0}
// -----------------------------------------------------------------------------

assign cfg_rxstandby_control = pl_reg_phyiop_0[7:0];

assign cfg_pl_l1_exit_mode = pl_reg_phyiop_1[0];
assign cfg_pl_l1_nowait_p1 = pl_reg_phyiop_1[1];
assign cfg_pl_l1_clk_sel = pl_reg_phyiop_1[2];
assign cfg_p2nobeacon_enable = pl_reg_phyiop_1[3];
assign cfg_phy_rst_timer = {pl_reg_phyiop_3[5:0], pl_reg_phyiop_2[7:0], pl_reg_phyiop_1[7:4]};
assign cfg_pipe_optional_pclkchange_hs = pl_reg_phyiop_3[7];
assign cfg_phy_perst_on_warm_reset = pl_reg_phyiop_3[6];

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_phyiop_1[2:0] <= #TP 0;                      //
      pl_reg_phyiop_1[3]   <= #TP P2NOBEACON_ENABLE;      // P2.NoBeacon supported
     {pl_reg_phyiop_3[5:0], pl_reg_phyiop_2[7:0], pl_reg_phyiop_1[7:4]} <= #TP PHY_RST_TIMER; // Timer for PHY rst
      pl_reg_phyiop_3[6]   <= #TP DEFAULT_PHY_PERST_ON_WARM_RESET;
      pl_reg_phyiop_3[7]   <= #TP PIPE_OPTIONAL_PCLKCHANGE_HS;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_phyiop_1[1]   <= #TP 1; // don't wait P1 for CX_PIPE43_SUPPORT because PIPE43 needs phystatus back anyway for any of P1.CPM/P1

      pl_reg_phyiop_1[0]   <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[8] : pl_reg_phyiop_1[0];
      pl_reg_phyiop_1[2]   <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[10] : pl_reg_phyiop_1[2];
      pl_reg_phyiop_1[3]   <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[11] : pl_reg_phyiop_1[3];
      // writes to cfg_phy_rst_timer registers
      pl_reg_phyiop_1[7:4] <= #TP pl_reg_id[113] & write_pulse[1] ? lbc_cdm_data[15:12] : pl_reg_phyiop_1[7:4];
      pl_reg_phyiop_2[7:0] <= #TP pl_reg_id[113] & write_pulse[2] ? lbc_cdm_data[23:16] : pl_reg_phyiop_2[7:0];
      pl_reg_phyiop_3[5:0] <= #TP pl_reg_id[113] & write_pulse[3] ? lbc_cdm_data[29:24] : pl_reg_phyiop_3[5:0];
      pl_reg_phyiop_3[6]   <= #TP pl_reg_id[113] & write_pulse[3] ? lbc_cdm_data[30] : pl_reg_phyiop_3[6];
      pl_reg_phyiop_3[7]   <= #TP pl_reg_id[113] & write_pulse[3] ? lbc_cdm_data[31] : pl_reg_phyiop_3[7]; //  write to DEFAULT_PHY_PERST_ON_WARM_RESET
    end
end
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_phyiop_0[7:0] <= #TP `CX_RXSTANDBY_CONTROL;  // Rxstandby Control
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_phyiop_0[7:0] <= #TP (write_pulse[0] & pl_reg_id[113]) ? lbc_cdm_data[7:0] : pl_reg_phyiop_0[7:0];
    end
end

//------------------------------------------------------------------------------
// PHY InterOp Control 2
// cpl_reg_id       - 114 (offset 0x44c)
// Length           - 4 byte
// Default value    -
// Core register    - {pl_reg_phyiop_ctrl2_3, pl_reg_phyiop_ctrl2_2, pl_reg_phyiop_ctrl2_1, pl_reg_phyiop_ctrl2_0}
// -----------------------------------------------------------------------------

assign cfg_pma_phy_rst_delay_timer = pl_reg_phyiop_ctrl2_0[5:0];
assign cfg_dsp_pcipm_l1_enter_delay = pl_reg_phyiop_ctrl2_1[3:0];

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_phyiop_ctrl2_0[5:0] <= #TP PMA_PIPE_RST_DELAY_TIMER;  // PMA reset and PIPE reset delay timer
      pl_reg_phyiop_ctrl2_0[7:6] <= #TP 0;                         // Reserved
      pl_reg_phyiop_ctrl2_1[3:0] <= #TP DSP_PCIPM_L1_ENTER_DELAY;  // PCI PM L1 entry delay in aux clk cycles
      pl_reg_phyiop_ctrl2_1[7:4] <= #TP 0;                         // Reserved
      pl_reg_phyiop_ctrl2_2[7:0] <= #TP 0;                         // Reserved
      pl_reg_phyiop_ctrl2_3[7:0] <= #TP 0;                         // Reserved
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_phyiop_ctrl2_0[7:0] <= #TP pl_reg_id[ID_0x44C] & write_pulse[0] ? lbc_cdm_data[7:0] : pl_reg_phyiop_ctrl2_0[7:0];
      pl_reg_phyiop_ctrl2_0[7:6] <= #TP 0;
      pl_reg_phyiop_ctrl2_1[3:0] <= #TP pl_reg_id[ID_0x44C] & write_pulse[1] ? lbc_cdm_data[11:8] : pl_reg_phyiop_ctrl2_1[3:0];
      pl_reg_phyiop_ctrl2_1[7:4] <= #TP 0;
      pl_reg_phyiop_ctrl2_2[7:0] <= #TP 0;
      pl_reg_phyiop_ctrl2_3[7:0] <= #TP 0;
    end
end


//------------------------------------------------------------------------------
// POWERDOWN_CTRL_STATUS
// cpl_reg_id       - 190 (offset 0x448)
// Length           - 4 byte
// Default value    -
// Core register    - {16'h0000, pm_powerdown_status, 3'b000, cfg_force_powerdown}
// -----------------------------------------------------------------------------
// toggle the force powerdown bit
assign int_force_powerdown = write_pulse[0] && pl_reg_id[ID_0x448] ? lbc_cdm_data[0] : 1'b0;
assign int_vmain_ack_ctrl_en = write_pulse[0] && pl_reg_id[ID_0x448];

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : powerdown_reg_PROC
  if (!sticky_rst_n) begin
    cfg_force_powerdown <= #TP 1'b0;
    cfg_vmain_ack_ctrl  <= #TP `CX_VMAIN_ACK_CTRL_RST_VALUE;
  end
  else begin
    cfg_force_powerdown <= #TP int_force_powerdown;
    cfg_vmain_ack_ctrl  <= #TP int_vmain_ack_ctrl_en ? lbc_cdm_data[1] : cfg_vmain_ack_ctrl;
  end
end : powerdown_reg_PROC

assign int_powerdown_status = {pm_powerdown_status, 2'b00, cfg_vmain_ack_ctrl, cfg_force_powerdown};

//------------------------------------------------------------------------------
// Link Reset Request Flush Control Register
// cpl_reg_id       - 115 (offset 0x1cc)
// Length           - 4 byte
// Default value    - 0x32000001
// Core register    - {pl_reg_lflshctl_3, 16'h0, pl_reg_lflshctl_0}
// -----------------------------------------------------------------------------
  reg       r_auto_flush_en; // Auto Flush Enable
  reg [7:0] r_auto_flush_timeout;

  always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
      r_auto_flush_en      <= # TP 1'b1;
      r_auto_flush_timeout <= # TP 8'hFF; // 255msec
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      r_auto_flush_en      <= # TP write_pulse[0] & pl_reg_id[115] ? lbc_cdm_data[0]     : r_auto_flush_en;
      r_auto_flush_timeout <= # TP write_pulse[3] & pl_reg_id[115] ? lbc_cdm_data[31:24] : r_auto_flush_timeout;
    end
  end

  assign pl_reg_lflshctl_0      = {7'b0, r_auto_flush_en};
  assign pl_reg_lflshctl_3      = r_auto_flush_timeout;
  assign cfg_auto_flush_en      = r_auto_flush_en;
  assign cfg_auto_flush_timeout = r_auto_flush_timeout;

//------------------------------------------------------------------------------
// AMBA Error Response
// cpl_reg_id       - 116 (offset 0x1d0)
// Length           - 4 bytes
// Default value    - 0xa400
// Core register    - {pl_reg_err_rsp_3, pl_reg_err_rsp_2, pl_reg_err_rsp_1, pl_reg_err_rsp_0}
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_err_rsp_3 <= #TP 8'd0;
      pl_reg_err_rsp_1 <= #TP 8'b10011100; // {UR,0,0,CA,0,TO,0,0}
      pl_reg_err_rsp_0 <= #TP 8'd0;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_err_rsp_3[5:0] <= #TP 6'd0;
      pl_reg_err_rsp_3[7]  <= #TP 1'd0;
      pl_reg_err_rsp_3[6]  <= #TP 1'd0;
      pl_reg_err_rsp_1[7:2] <= #TP (write_pulse[1] & pl_reg_id[116]) ? lbc_cdm_data[15:10] : pl_reg_err_rsp_1[7:2];
      pl_reg_err_rsp_1[1:0] <= #TP 2'b0;
      pl_reg_err_rsp_0[7:5] <= #TP 3'd0;
      pl_reg_err_rsp_0[4:2] <= #TP (write_pulse[0] & pl_reg_id[116]) ? lbc_cdm_data[4:2] : pl_reg_err_rsp_0[4:2];
      pl_reg_err_rsp_0[1]   <= #TP 1'b0;
      pl_reg_err_rsp_0[0]   <= #TP (write_pulse[0] & pl_reg_id[116]) ? lbc_cdm_data[0] : pl_reg_err_rsp_0[0];
    end
end

// cfg_err_resp[4:3]=AMBA_ERROR_RESPONSE_CRS
// cfg_err_resp[4:3]=2'b10 => OK with FFFF_0001 data for CRS CPL to Vendor ID read requests
//                            OK with FFFF_FFFF data for all other CRS CPL
wire   [15:0] int_cfg_err_resp;
assign int_cfg_err_resp = {pl_reg_err_rsp_1, pl_reg_err_rsp_0};
assign cfg_err_resp = cfg_crs_sw_vis_en ? {int_cfg_err_resp[15:5], 2'b10, int_cfg_err_resp[2:0]} : int_cfg_err_resp;

//------------------------------------------------------------------------------
// Link Timeout Period
// cpl_reg_id       - 117 (offset 0x1d4)
// Length           - 2 bytes
// Default value    - `CC_LINK_TIMEOUT_PERIOD_DEFAULT
// Core register    - {16'h0, pl_reg_207, pl_reg_206}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_206 <= #TP `CC_LINK_TIMEOUT_PERIOD_DEFAULT;
      pl_reg_207 <= #TP {7'b0,`CC_LINK_TIMEOUT_ENABLE_DEFAULT};

    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_206      <= #TP (write_pulse[0] & pl_reg_id[117]) ? lbc_cdm_data[7:0] :
                             pl_reg_206;
      pl_reg_207[0]   <= #TP (write_pulse[1] & pl_reg_id[117]) ? lbc_cdm_data[8]   : pl_reg_207[0];
      pl_reg_207[7:1] <= #TP 7'b0;
    end
end

assign cfg_link_timeout_period = pl_reg_206;
assign cfg_link_timeout_en_n   = pl_reg_207[0];

//------------------------------------------------------------------------------
// AMBA Ordering Control
// pl_reg_id     - 118 (byte offset 0x1d8)
// Length        - 1 byte
// Default value - 0
// Core register - {24'b0, pl_reg_aoc_0}
//------------------------------------------------------------------------------
reg r_ax_snp_en; // AXI Slave Non-Posted Serialsation Enable
reg [1:0] r_ax_mstr_ordr_p_event_sel; //AXI Master Posted ordering event selector
reg       r_ax_mstr_zeroread_fw;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      r_ax_snp_en                <= #TP 0;
      r_ax_mstr_ordr_p_event_sel <= #TP 0;
      r_ax_mstr_zeroread_fw      <= #TP 0;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      r_ax_snp_en                <= #TP (write_pulse[0] & pl_reg_id[118]) ? lbc_cdm_data[1]   : r_ax_snp_en;
      r_ax_mstr_ordr_p_event_sel <= #TP (write_pulse[0] & pl_reg_id[118]) ? lbc_cdm_data[4:3] : r_ax_mstr_ordr_p_event_sel;
      r_ax_mstr_zeroread_fw      <= #TP (write_pulse[0] & pl_reg_id[118]) ? lbc_cdm_data[7]   : r_ax_mstr_zeroread_fw;
    end
end

// AMBA Ordering Contol Byte 0 for Read Mux
assign pl_reg_aoc_0 = {cfg_ax_mstr_zeroread_fw,
                       2'b0,
                       r_ax_mstr_ordr_p_event_sel,
                       1'b0,
                       r_ax_snp_en,
                       1'b0};

assign cfg_ax_mstr_ordr_p_event_sel = r_ax_mstr_ordr_p_event_sel;
assign cfg_ax_snp_en           = r_ax_snp_en;
assign cfg_ax_mstr_zeroread_fw = r_ax_mstr_zeroread_fw;



//------------------------------------------------------------------------------
// Coherency control 1 (Primitive Address Decode Lower)
// cpl_reg_id       - 120 (offset 0x1e0)
// Length           - 4 bytes
// Default value    - 32'h0
// Core register    - {pl_reg_211, pl_reg_210, pl_reg_209, pl_reg_208}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_208 <= #TP 8'h0;
      pl_reg_209 <= #TP 8'h0;
      pl_reg_210 <= #TP 8'h0;
      pl_reg_211 <= #TP 8'h0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_208[7:0] <= #TP (write_pulse[0] & pl_reg_id[120]) ?   {lbc_cdm_data[7:2],1'b0,lbc_cdm_data[0]} : pl_reg_208[7:0];
      pl_reg_209[7:0] <= #TP (write_pulse[1] & pl_reg_id[120]) ?                       {lbc_cdm_data[15:8]} : pl_reg_209[7:0];
      pl_reg_210[7:0] <= #TP (write_pulse[2] & pl_reg_id[120]) ?                      {lbc_cdm_data[23:16]} : pl_reg_210[7:0];
      pl_reg_211[7:0] <= #TP (write_pulse[3] & pl_reg_id[120]) ?                      {lbc_cdm_data[31:24]} : pl_reg_211[7:0];
    end
end

//------------------------------------------------------------------------------
// Coherency control 2 (Primitive Address Decode Upper)
// cpl_reg_id       - 121 (offset 0x1e4)
// Length           - 4 bytes
// Default value    - 32'h0
// Core register    - {pl_reg_215, pl_reg_214, pl_reg_213, pl_reg_212}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_212 <= #TP 8'h0;
      pl_reg_213 <= #TP 8'h0;
      pl_reg_214 <= #TP 8'h0;
      pl_reg_215 <= #TP 8'h0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_212[7:0] <= #TP (write_pulse[0] & pl_reg_id[121]) ?   {lbc_cdm_data[7:0]} : pl_reg_212[7:0];
      pl_reg_213[7:0] <= #TP (write_pulse[1] & pl_reg_id[121]) ?  {lbc_cdm_data[15:8]} : pl_reg_213[7:0];
      pl_reg_214[7:0] <= #TP (write_pulse[2] & pl_reg_id[121]) ? {lbc_cdm_data[23:16]} : pl_reg_214[7:0];
      pl_reg_215[7:0] <= #TP (write_pulse[3] & pl_reg_id[121]) ? {lbc_cdm_data[31:24]} : pl_reg_215[7:0];
    end
end

assign cfg_memtype_value       = pl_reg_208[0];
assign int_cfg_memtype_boundary    = {pl_reg_215,pl_reg_214,pl_reg_213,pl_reg_212,pl_reg_211,pl_reg_210,pl_reg_209,pl_reg_208[7:2]};

assign cfg_memtype_boundary = int_cfg_memtype_boundary[`FLT_Q_ADDR_WIDTH-3:0];



//------------------------------------------------------------------------------
// Coherency control 3 (AMBA Extended Signalling Overrides)
// cpl_reg_id       - 122 (offset 0x1e8)
// Length           - 4 bytes
// Default value    - 32'h0
// Core register    - {pl_reg_219, pl_reg_218, pl_reg_217, pl_reg_216}
// -----------------------------------------------------------------------------

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      pl_reg_216 <= #TP 8'h0;
      pl_reg_217 <= #TP 8'h0;
      pl_reg_218 <= #TP 8'h0;
      pl_reg_219 <= #TP 8'h0;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      pl_reg_216[1:0] <= #TP (write_pulse[0] & pl_reg_id[122]) ?   {lbc_cdm_data[1:0]} : pl_reg_216[1:0];
      pl_reg_217[1:0] <= #TP (write_pulse[1] & pl_reg_id[122]) ?   {lbc_cdm_data[9:8]} : pl_reg_217[1:0];
      pl_reg_218[1:0] <= #TP (write_pulse[2] & pl_reg_id[122]) ? {lbc_cdm_data[17:16]} : pl_reg_218[1:0];
      pl_reg_219[1:0] <= #TP (write_pulse[3] & pl_reg_id[122]) ? {lbc_cdm_data[25:24]} : pl_reg_219[1:0];
      pl_reg_216[2]   <= #TP 1'b0;
      pl_reg_217[2]   <= #TP 1'b0;
      pl_reg_218[2]   <= #TP 1'b0;
      pl_reg_219[2]   <= #TP 1'b0;
      pl_reg_216[6:3] <= #TP (write_pulse[0] & pl_reg_id[122]) ?   {lbc_cdm_data[6:3]} : pl_reg_216[6:3];
      pl_reg_217[6:3] <= #TP (write_pulse[1] & pl_reg_id[122]) ? {lbc_cdm_data[14:11]} : pl_reg_217[6:3];
      pl_reg_218[6:3] <= #TP (write_pulse[2] & pl_reg_id[122]) ? {lbc_cdm_data[22:19]} : pl_reg_218[6:3];
      pl_reg_219[6:3] <= #TP (write_pulse[3] & pl_reg_id[122]) ? {lbc_cdm_data[30:27]} : pl_reg_219[6:3];
      pl_reg_216[7]   <= #TP 1'b0;
      pl_reg_217[7]   <= #TP 1'b0;
      pl_reg_218[7]   <= #TP 1'b0;
      pl_reg_219[7]   <= #TP 1'b0;
    end
end

assign cfg_mstr_arcache_mode   = pl_reg_216[6:3];
assign cfg_mstr_awcache_mode   = pl_reg_217[6:3];
assign cfg_mstr_arcache_value  = pl_reg_218[6:3];
assign cfg_mstr_awcache_value  = pl_reg_219[6:3];
assign cfg_mstr_ardomain_mode  = pl_reg_216[1:0];
assign cfg_mstr_awdomain_mode  = pl_reg_217[1:0];
assign cfg_mstr_ardomain_value = pl_reg_218[1:0];
assign cfg_mstr_awdomain_value = pl_reg_219[1:0];



//------------------------------------------------------------------------------
// AXI Master Message Address LOW
// cpl_reg_id       - 124 (offset 0x1f0)
// Length           - 20 bits, lowest 12 bits is tied to zero
// Default value    - 32'h0
// AMBA register    - {pl_reg_234, pl_reg_233, pl_reg_232,4'd0, 8'd0}
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    pl_reg_232 <= #TP 8'h0;
    pl_reg_233 <= #TP 8'h0;
    pl_reg_234 <= #TP 8'h0;
  end
  else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
    pl_reg_232 <= #TP (write_pulse[1] & pl_reg_id[124]) ? {lbc_cdm_data[15:12], 4'd0} : pl_reg_232[7:0];
    pl_reg_233 <= #TP (write_pulse[2] & pl_reg_id[124]) ? {lbc_cdm_data[23:16]      } : pl_reg_233[7:0];
    pl_reg_234 <= #TP (write_pulse[3] & pl_reg_id[124]) ? {lbc_cdm_data[31:24]      } : pl_reg_234[7:0];
  end
end
assign cfg_aximstr_msg_addr_low = {pl_reg_234, pl_reg_233, pl_reg_232, 8'd0};

// -----------------------------------------------------------------------------
// AXI Master Message Address HIGH
// cpl_reg_id       - 125 (offset 0x1f4)
// Length           - 4 bytes
// Default value    - 32'h0
// AMBA register    - {pl_reg_238, pl_reg_237, pl_reg_236, pl_reg_235}
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    pl_reg_235 <= #TP 8'h0;
    pl_reg_236 <= #TP 8'h0;
    pl_reg_237 <= #TP 8'h0;
    pl_reg_238 <= #TP 8'h0;
  end
  else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
    pl_reg_235 <= #TP (write_pulse[0] & pl_reg_id[125]) ? {lbc_cdm_data[7 : 0]} : pl_reg_235[7:0];
    pl_reg_236 <= #TP (write_pulse[1] & pl_reg_id[125]) ? {lbc_cdm_data[15: 8]} : pl_reg_236[7:0];
    pl_reg_237 <= #TP (write_pulse[2] & pl_reg_id[125]) ? {lbc_cdm_data[23:16]} : pl_reg_237[7:0];
    pl_reg_238 <= #TP (write_pulse[3] & pl_reg_id[125]) ? {lbc_cdm_data[31:24]} : pl_reg_238[7:0];
  end
end
assign cfg_aximstr_msg_addr_high = {pl_reg_238, pl_reg_237, pl_reg_236, pl_reg_235};

// Target Map registers
    cdm_trgt_map
    
        #(
          .INST(INST))
          u_cdm_trgt_map(
// ------------ Inputs ---------------
        .core_clk               (core_clk),
        .cdm_clk_g              (cdm_clk_g),
        .sticky_rst_n           (sticky_rst_n),
        .lbc_cdm_data           (lbc_cdm_data),
        .trgt_map_write_pulse   (write_pulse),
        .trgt_map_reg_id        (trgt_map_reg_id),
// ------------ Outputs --------------
        .trgt_map_reg_data      (trgt_map_reg_data),
        .target_mem_map         (target_mem_map),
        .target_rom_map         (target_rom_map)
    );

//      - ATU UNROLL removes this




// =============================================================================
// LTR registers
// =============================================================================
//------------------------------------------------------------------------------
// LTR Latency Register
// Port Logic Offset - `CFG_PL_REG + 0x430 (0xB30)
// pl_reg_id         - 136
// Length            - 4 bytes
// Default value     - 0000h
//------------------------------------------------------------------------------
reg           ltr_nosnoop_req;  // No Snoop Latency Requirement
reg    [1:0]  ltr_nosnoop_rsvd;
reg    [2:0]  ltr_nosnoop_scale; // No Snoop Latency Scale
reg    [9:0]  ltr_nosnoop_value; // No Snoop Latency Value
reg           ltr_snoop_req;     // Snoop Latency Requirement
reg    [1:0]  ltr_snoop_rsvd;
reg    [2:0]  ltr_snoop_scale;    // Snoop Latency Scale
reg    [9:0]  ltr_snoop_value;    // Snoop Latency Value

always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_seq_ltr_reg
   if (!non_sticky_rst_n) begin
     ltr_nosnoop_req   <= #TP 0;
     ltr_nosnoop_rsvd  <= #TP 0;
     ltr_nosnoop_scale <= #TP 0;
     ltr_nosnoop_value <= #TP 0;
     ltr_snoop_req     <= #TP 0;
     ltr_snoop_rsvd    <= #TP 0;
     ltr_snoop_scale   <= #TP 0;
     ltr_snoop_value   <= #TP 0;
   end else if (msg_ltr_det) begin
   // Capture transmitted upstream port (received downstream port) latency tolerance reported values
   // Note: byte ordering in msg_ltr_latency[31:0] reflects the PCIe Message TLP byte positions.
   // To comply with the app_ltr* and port logic register definitions the byte order
   // is reversed, i.e. msg_ltr_latency bytes 0->3 are mapped to LTR latency reg bytes 3->0.
     {ltr_nosnoop_req, ltr_nosnoop_rsvd[1:0], ltr_nosnoop_scale[2:0], ltr_nosnoop_value[9:0],
        ltr_snoop_req,   ltr_snoop_rsvd[1:0],   ltr_snoop_scale[2:0],   ltr_snoop_value[9:0]} <= #TP {msg_ltr_latency[7:0], msg_ltr_latency[15:8], msg_ltr_latency[23:16], msg_ltr_latency[31:24]};
   end else begin
     // DBI read/write, Cfg read only
     ltr_nosnoop_req        <= #TP ltr_reg_id[0] & write_pulse[3] & lbc_cdm_dbi ? lbc_cdm_data[31]    : ltr_nosnoop_req;
     ltr_nosnoop_scale      <= #TP ltr_reg_id[0] & write_pulse[3] & lbc_cdm_dbi ? lbc_cdm_data[28:26] : ltr_nosnoop_scale;
     ltr_nosnoop_value[9:8] <= #TP ltr_reg_id[0] & write_pulse[3] & lbc_cdm_dbi ? lbc_cdm_data[25:24] : ltr_nosnoop_value[9:8];
     ltr_nosnoop_value[7:0] <= #TP ltr_reg_id[0] & write_pulse[2] & lbc_cdm_dbi ? lbc_cdm_data[23:16] : ltr_nosnoop_value[7:0];
     ltr_snoop_req          <= #TP ltr_reg_id[0] & write_pulse[1] & lbc_cdm_dbi ? lbc_cdm_data[15]    : ltr_snoop_req;
     ltr_snoop_scale        <= #TP ltr_reg_id[0] & write_pulse[1] & lbc_cdm_dbi ? lbc_cdm_data[12:10] : ltr_snoop_scale;
     ltr_snoop_value[9:8]   <= #TP ltr_reg_id[0] & write_pulse[1] & lbc_cdm_dbi ? lbc_cdm_data[9:8]   : ltr_snoop_value[9:8];
     ltr_snoop_value[7:0]   <= #TP ltr_reg_id[0] & write_pulse[0] & lbc_cdm_dbi ? lbc_cdm_data[7:0]   : ltr_snoop_value[7:0];
   end
end

// Build LTR latency register
wire   [31:0] ltr_latency_reg; // LTR Latency Register
assign ltr_latency_reg = {ltr_nosnoop_req,2'b0,ltr_nosnoop_scale,ltr_nosnoop_value,ltr_snoop_req,2'b0,ltr_snoop_scale,ltr_snoop_value};

// Implement LTR read mux
always @(*) begin : proc_comb_ltr_read_mux
   case (1'b1)
     ltr_reg_id[0] : begin
       ltr_reg_data = ltr_latency_reg;
     end
     default       : begin
       ltr_reg_data = 32'b0;
     end
   endcase
end

// Assign LTR outputs
// Output the transmitted upstream port LTR values to the application
assign app_ltr_latency = ltr_latency_reg;
// Output LTR message requirement status to CDM cfg register module, u_cdm_cfg_reg
assign cdmpl2cfg_ltr_rq = (ltr_nosnoop_req || ltr_snoop_req);

// =============================================================================
// Auxiliary Clock register
// =============================================================================
//------------------------------------------------------------------------------
// Auxiliary Clock Frequency Control Register
// Port Logic Offset - `CFG_PL_REG + 0x440 (0xB40)
// pl_reg_id         - 141
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg    [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : cfg_pl_aux_clk_freq_PROC
    if (!sticky_rst_n) begin
        cfg_pl_aux_clk_freq <= #TP AUX_CLK_FREQ_RST_VAL;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_pl_aux_clk_freq[7:0] <= #TP aux_clk_reg_id & write_pulse[0] ? lbc_cdm_data[7:0] : cfg_pl_aux_clk_freq[7:0];
        cfg_pl_aux_clk_freq[9:8] <= #TP aux_clk_reg_id & write_pulse[1] ? lbc_cdm_data[9:8] : cfg_pl_aux_clk_freq[9:8];
   end
end

assign aux_clk_reg_data = {22'h0, cfg_pl_aux_clk_freq};

//------------------------------------------------------------------------------
// L1 Substates Register
// Port Logic Offset - `CFG_PL_REG + 0x444 (0xB44)
// pl_reg_id         - 142
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg    [1:0]  cfg_pl_l1sub_t_power_off;
reg    [3:0]  cfg_pl_l1sub_t_l1_2;
reg    [6:0]  cfg_pl_l1sub_t_pclkack;
reg           cfg_pl_l1sub_clock_switch;

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : l1_sub_PROC
    if (!sticky_rst_n) begin
        cfg_pl_l1sub_t_power_off  <= #TP 2'h2;
        cfg_pl_l1sub_t_l1_2       <= #TP 4'h4;
        cfg_pl_l1sub_t_pclkack    <= #TP 7'h7f;
        cfg_pl_l1sub_clock_switch <= #TP 1'b0;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_pl_l1sub_t_power_off  <= #TP l1sub_reg_id & write_pulse[0] ? lbc_cdm_data[1:0] : cfg_pl_l1sub_t_power_off;
        cfg_pl_l1sub_t_l1_2       <= #TP l1sub_reg_id & write_pulse[0] ? lbc_cdm_data[5:2] : cfg_pl_l1sub_t_l1_2;
        cfg_pl_l1sub_t_pclkack[1:0]<= #TP l1sub_reg_id & write_pulse[0] ? lbc_cdm_data[7:6] : cfg_pl_l1sub_t_pclkack[1:0];
        cfg_pl_l1sub_clock_switch <= #TP l1sub_reg_id & write_pulse[1] ? lbc_cdm_data[8]   : cfg_pl_l1sub_clock_switch;
        cfg_pl_l1sub_t_pclkack[6:2]<= #TP l1sub_reg_id & write_pulse[1] ? lbc_cdm_data[13:9] : cfg_pl_l1sub_t_pclkack[6:2];
   end
end

reg [`CX_PL_L1SUB_CONTROL_WD-1:0] cfg_pl_l1sub_control_reg; //Port Logic L1 Substates Register, 1:1 map to the location of each field.
assign cfg_pl_l1sub_control_reg = {cfg_pl_l1sub_t_pclkack[6:2], cfg_pl_l1sub_clock_switch, cfg_pl_l1sub_t_pclkack[1:0], cfg_pl_l1sub_t_l1_2, cfg_pl_l1sub_t_power_off};

//------------------------------------------------------------------------------
// L1SUB registers read operation
//------------------------------------------------------------------------------
always @( * ) begin : l1sub_reg_data_PROC
    unique case (1'b1)
        l1sub_reg_id : l1sub_reg_data = {18'b0, cfg_pl_l1sub_control_reg};
        default      : l1sub_reg_data = 0;
    endcase
end //always

//export these bits as one single bus for ease of maintenance of the interfaces
//notice the fields in this signal are not 1:1 mapping to register. refer to cfg_pl_l1sub_control_reg
assign cfg_pl_l1sub_control = {cfg_pl_l1sub_clock_switch, cfg_pl_l1sub_t_pclkack, cfg_pl_l1sub_t_l1_2, cfg_pl_l1sub_t_power_off};



//------------------------------------------------------------------------------
// GEN4_LANE_MARGINING_1
// Port Logic Offset - `CFG_PL_REG + 0x480 (0xB80)
// pl_reg_id         - 154
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg     [5:0]         cfg_gen4_margin_num_timing_steps;     // [ 5: 0] Number of timing steps for lane margining at the receiver
reg     [5:0]         cfg_gen4_margin_max_timing_offset;    // [13: 8] Maximum number of timing offset for lane margining at the receiver
reg     [6:0]         cfg_gen4_margin_num_voltage_steps;    // [22:16] Number of voltage steps for lane margining at the receiver
reg     [5:0]         cfg_gen4_margin_max_voltage_offset;   // [29:24] Maximum number of voltage offsets for lane margining at the receiver

assign pl_reg_0x480 = {2'b00, cfg_gen4_margin_max_voltage_offset,
                       1'b0 , cfg_gen4_margin_num_voltage_steps,
                       2'b00, cfg_gen4_margin_max_timing_offset,
                       2'b00, cfg_gen4_margin_num_timing_steps};

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_gen4_margin_num_timing_steps    <= #TP `DEFAULT_GEN4_RXMARGIN_NUM_TIMING_STEPS;
        cfg_gen4_margin_max_timing_offset   <= #TP `DEFAULT_GEN4_RXMARGIN_MAX_TIMING_OFFSET;
        cfg_gen4_margin_num_voltage_steps   <= #TP `DEFAULT_GEN4_RXMARGIN_NUM_VOLTAGE_STEPS;
        cfg_gen4_margin_max_voltage_offset  <= #TP `DEFAULT_GEN4_RXMARGIN_MAX_VOLTAGE_OFFSET;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_gen4_margin_num_timing_steps    <= #TP pl_reg_id[ID_0x480] & write_pulse[0] ? lbc_cdm_data[ 5: 0] : cfg_gen4_margin_num_timing_steps;
        cfg_gen4_margin_max_timing_offset   <= #TP pl_reg_id[ID_0x480] & write_pulse[1] ? lbc_cdm_data[13: 8] : cfg_gen4_margin_max_timing_offset;
        cfg_gen4_margin_num_voltage_steps   <= #TP pl_reg_id[ID_0x480] & write_pulse[2] ? lbc_cdm_data[22:16] : cfg_gen4_margin_num_voltage_steps;
        cfg_gen4_margin_max_voltage_offset  <= #TP pl_reg_id[ID_0x480] & write_pulse[3] ? lbc_cdm_data[29:24] : cfg_gen4_margin_max_voltage_offset;
   end
end

//------------------------------------------------------------------------------
// GEN4_LANE_MARGINING_2
// Port Logic Offset - `CFG_PL_REG + 0x484 (0xB84)
// pl_reg_id         - 155
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg     [5:0]         cfg_gen4_margin_sample_rate_voltage;      // [ 5: 0] Number of sampling rate voltage for lane margining at the receiver
reg     [5:0]         cfg_gen4_margin_sample_rate_timing;       // [13: 8] Number of sampling rate timing for lane margining at the receiver
reg     [4:0]         cfg_gen4_margin_maxlanes;                 // [20:16] Maximum number oflane for lane margining at the receiver
reg                   cfg_gen4_margin_voltage_supported;        // [24]    Support of voltage margining for lane margining at the receiver
reg                   cfg_gen4_margin_ind_up_down_voltage;      // [25]    Support of Independent up and down voltage marging for lane margining at the receiver
reg                   cfg_gen4_margin_ind_left_right_timing;    // [26]    Support of Independent left/right margining lane margining at the receiver
reg                   cfg_gen4_margin_sample_reporting_method;  // [27]    Support of Sample reporting method for lane margining at the receiver
reg                   cfg_gen4_margin_ind_error_sampler;        // [28]    Support of Independent error sampler for lane margining at the receiver
wire                  cfg_margin_rate_mode = 1'b0;         // [31]    Possible rate for lane margining at the receiver (0: only gen4, 1: all rate)

assign pl_reg_0x484 = {cfg_margin_rate_mode, 2'b00, cfg_gen4_margin_ind_error_sampler , cfg_gen4_margin_sample_reporting_method, cfg_gen4_margin_ind_left_right_timing, cfg_gen4_margin_ind_up_down_voltage, cfg_gen4_margin_voltage_supported,
                       3'b000, cfg_gen4_margin_maxlanes,
                       2'b00 , cfg_gen4_margin_sample_rate_timing,
                       2'b00 , cfg_gen4_margin_sample_rate_voltage};

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_gen4_margin_sample_rate_voltage     <= #TP `DEFAULT_GEN4_RXMARGIN_SAMPLE_RATE_VOLTAGE;
        cfg_gen4_margin_sample_rate_timing      <= #TP `DEFAULT_GEN4_RXMARGIN_SAMPLE_RATE_TIMING;
        cfg_gen4_margin_maxlanes                <= #TP `DEFAULT_GEN4_RXMARGIN_MAXLANES;
        cfg_gen4_margin_voltage_supported       <= #TP `DEFAULT_GEN4_RXMARGIN_VOLTAGE_SUPPORTED;
        cfg_gen4_margin_ind_up_down_voltage     <= #TP `DEFAULT_GEN4_RXMARGIN_IND_UP_DOWN_VOLTAGE;
        cfg_gen4_margin_ind_left_right_timing   <= #TP `DEFAULT_GEN4_RXMARGIN_IND_LEFT_RIGHT_TIMING;
        cfg_gen4_margin_sample_reporting_method <= #TP `DEFAULT_GEN4_RXMARGIN_SAMPLE_REPORTING_METHOD;
        cfg_gen4_margin_ind_error_sampler       <= #TP `DEFAULT_GEN4_RXMARGIN_IND_ERROR_SAMPLER;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_gen4_margin_sample_rate_voltage     <= #TP pl_reg_id[ID_0x484] & write_pulse[0] ? lbc_cdm_data[ 5: 0] : cfg_gen4_margin_sample_rate_voltage;
        cfg_gen4_margin_sample_rate_timing      <= #TP pl_reg_id[ID_0x484] & write_pulse[1] ? lbc_cdm_data[13: 8] : cfg_gen4_margin_sample_rate_timing;
        cfg_gen4_margin_maxlanes                <= #TP pl_reg_id[ID_0x484] & write_pulse[2] ? lbc_cdm_data[20:16] : cfg_gen4_margin_maxlanes;
        cfg_gen4_margin_voltage_supported       <= #TP pl_reg_id[ID_0x484] & write_pulse[3] ? lbc_cdm_data[24]    : cfg_gen4_margin_voltage_supported;
        cfg_gen4_margin_ind_up_down_voltage     <= #TP pl_reg_id[ID_0x484] & write_pulse[3] ? lbc_cdm_data[25]    : cfg_gen4_margin_ind_up_down_voltage;
        cfg_gen4_margin_ind_left_right_timing   <= #TP pl_reg_id[ID_0x484] & write_pulse[3] ? lbc_cdm_data[26]    : cfg_gen4_margin_ind_left_right_timing;
        cfg_gen4_margin_sample_reporting_method <= #TP pl_reg_id[ID_0x484] & write_pulse[3] ? lbc_cdm_data[27]    : cfg_gen4_margin_sample_reporting_method;
        cfg_gen4_margin_ind_error_sampler       <= #TP pl_reg_id[ID_0x484] & write_pulse[3] ? lbc_cdm_data[28]    : cfg_gen4_margin_ind_error_sampler;
   end
end

//------------------------------------------------------------------------------
// GEN5_LANE_MARGINING_1
// Port Logic Offset - `CFG_PL_REG + 0x488 (0xB88)
// pl_reg_id         - 213
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg     [5:0]         cfg_gen5_margin_num_timing_steps;     // [ 5: 0] Number of timing steps for lane margining at the receiver
reg     [5:0]         cfg_gen5_margin_max_timing_offset;    // [13: 8] Maximum number of timing offset for lane margining at the receiver
reg     [6:0]         cfg_gen5_margin_num_voltage_steps;    // [22:16] Number of voltage steps for lane margining at the receiver
reg     [5:0]         cfg_gen5_margin_max_voltage_offset;   // [29:24] Maximum number of voltage offsets for lane margining at the receiver

assign pl_reg_0x488 = {2'b00, cfg_gen5_margin_max_voltage_offset,
                       1'b0 , cfg_gen5_margin_num_voltage_steps,
                       2'b00, cfg_gen5_margin_max_timing_offset,
                       2'b00, cfg_gen5_margin_num_timing_steps};

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_gen5_margin_num_timing_steps    <= #TP `DEFAULT_GEN5_RXMARGIN_NUM_TIMING_STEPS;
        cfg_gen5_margin_max_timing_offset   <= #TP `DEFAULT_GEN5_RXMARGIN_MAX_TIMING_OFFSET;
        cfg_gen5_margin_num_voltage_steps   <= #TP `DEFAULT_GEN5_RXMARGIN_NUM_VOLTAGE_STEPS;
        cfg_gen5_margin_max_voltage_offset  <= #TP `DEFAULT_GEN5_RXMARGIN_MAX_VOLTAGE_OFFSET;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_gen5_margin_num_timing_steps    <= #TP pl_reg_id[ID_0x488] & write_pulse[0] ? lbc_cdm_data[ 5: 0] : cfg_gen5_margin_num_timing_steps;
        cfg_gen5_margin_max_timing_offset   <= #TP pl_reg_id[ID_0x488] & write_pulse[1] ? lbc_cdm_data[13: 8] : cfg_gen5_margin_max_timing_offset;
        cfg_gen5_margin_num_voltage_steps   <= #TP pl_reg_id[ID_0x488] & write_pulse[2] ? lbc_cdm_data[22:16] : cfg_gen5_margin_num_voltage_steps;
        cfg_gen5_margin_max_voltage_offset  <= #TP pl_reg_id[ID_0x488] & write_pulse[3] ? lbc_cdm_data[29:24] : cfg_gen5_margin_max_voltage_offset;
   end
end

//------------------------------------------------------------------------------
// GEN5_LANE_MARGINING_2
// Port Logic Offset - `CFG_PL_REG + 0x48C (0xB8C)
// pl_reg_id         - 214
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg     [5:0]         cfg_gen5_margin_sample_rate_voltage;      // [ 5: 0] Number of sampling rate voltage for lane margining at the receiver
reg     [5:0]         cfg_gen5_margin_sample_rate_timing;       // [13: 8] Number of sampling rate timing for lane margining at the receiver
reg     [4:0]         cfg_gen5_margin_maxlanes;                 // [20:16] Maximum number oflane for lane margining at the receiver
reg                   cfg_gen5_margin_voltage_supported;        // [24]    Support of voltage margining for lane margining at the receiver
reg                   cfg_gen5_margin_ind_up_down_voltage;      // [25]    Support of Independent up and down voltage marging for lane margining at the receiver
reg                   cfg_gen5_margin_ind_left_right_timing;    // [26]    Support of Independent left/right margining lane margining at the receiver
reg                   cfg_gen5_margin_sample_reporting_method;  // [27]    Support of Sample reporting method for lane margining at the receiver
reg                   cfg_gen5_margin_ind_error_sampler;        // [28]    Support of Independent error sampler for lane margining at the receiver

assign pl_reg_0x48C = {3'b000, cfg_gen5_margin_ind_error_sampler , cfg_gen5_margin_sample_reporting_method, cfg_gen5_margin_ind_left_right_timing, cfg_gen5_margin_ind_up_down_voltage, cfg_gen5_margin_voltage_supported,
                       3'b000, cfg_gen5_margin_maxlanes,
                       2'b00 , cfg_gen5_margin_sample_rate_timing,
                       2'b00 , cfg_gen5_margin_sample_rate_voltage};

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_gen5_margin_sample_rate_voltage     <= #TP `DEFAULT_GEN5_RXMARGIN_SAMPLE_RATE_VOLTAGE;
        cfg_gen5_margin_sample_rate_timing      <= #TP `DEFAULT_GEN5_RXMARGIN_SAMPLE_RATE_TIMING;
        cfg_gen5_margin_maxlanes                <= #TP `DEFAULT_GEN5_RXMARGIN_MAXLANES;
        cfg_gen5_margin_voltage_supported       <= #TP `DEFAULT_GEN5_RXMARGIN_VOLTAGE_SUPPORTED;
        cfg_gen5_margin_ind_up_down_voltage     <= #TP `DEFAULT_GEN5_RXMARGIN_IND_UP_DOWN_VOLTAGE;
        cfg_gen5_margin_ind_left_right_timing   <= #TP `DEFAULT_GEN5_RXMARGIN_IND_LEFT_RIGHT_TIMING;
        cfg_gen5_margin_sample_reporting_method <= #TP `DEFAULT_GEN5_RXMARGIN_SAMPLE_REPORTING_METHOD;
        cfg_gen5_margin_ind_error_sampler       <= #TP `DEFAULT_GEN5_RXMARGIN_IND_ERROR_SAMPLER;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_gen5_margin_sample_rate_voltage     <= #TP pl_reg_id[ID_0x48C] & write_pulse[0] ? lbc_cdm_data[ 5: 0] : cfg_gen5_margin_sample_rate_voltage;
        cfg_gen5_margin_sample_rate_timing      <= #TP pl_reg_id[ID_0x48C] & write_pulse[1] ? lbc_cdm_data[13: 8] : cfg_gen5_margin_sample_rate_timing;
        cfg_gen5_margin_maxlanes                <= #TP pl_reg_id[ID_0x48C] & write_pulse[2] ? lbc_cdm_data[20:16] : cfg_gen5_margin_maxlanes;
        cfg_gen5_margin_voltage_supported       <= #TP pl_reg_id[ID_0x48C] & write_pulse[3] ? lbc_cdm_data[24]    : cfg_gen5_margin_voltage_supported;
        cfg_gen5_margin_ind_up_down_voltage     <= #TP pl_reg_id[ID_0x48C] & write_pulse[3] ? lbc_cdm_data[25]    : cfg_gen5_margin_ind_up_down_voltage;
        cfg_gen5_margin_ind_left_right_timing   <= #TP pl_reg_id[ID_0x48C] & write_pulse[3] ? lbc_cdm_data[26]    : cfg_gen5_margin_ind_left_right_timing;
        cfg_gen5_margin_sample_reporting_method <= #TP pl_reg_id[ID_0x48C] & write_pulse[3] ? lbc_cdm_data[27]    : cfg_gen5_margin_sample_reporting_method;
        cfg_gen5_margin_ind_error_sampler       <= #TP pl_reg_id[ID_0x48C] & write_pulse[3] ? lbc_cdm_data[28]    : cfg_gen5_margin_ind_error_sampler;
   end
end

//------------------------------------------------------------------------------
// GEN6_LANE_MARGINING_1
// Port Logic Offset - `CFG_PL_REG + 0x498 (0xB98)
// pl_reg_id         - 213
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg     [5:0]         cfg_gen6_margin_num_timing_steps;     // [ 5: 0] Number of timing steps for lane margining at the receiver
reg     [5:0]         cfg_gen6_margin_max_timing_offset;    // [13: 8] Maximum number of timing offset for lane margining at the receiver
reg     [6:0]         cfg_gen6_margin_num_voltage_steps;    // [22:16] Number of voltage steps for lane margining at the receiver
reg     [5:0]         cfg_gen6_margin_max_voltage_offset;   // [29:24] Maximum number of voltage offsets for lane margining at the receiver

assign pl_reg_0x498 = {2'b00, cfg_gen6_margin_max_voltage_offset,
                       1'b0 , cfg_gen6_margin_num_voltage_steps,
                       2'b00, cfg_gen6_margin_max_timing_offset,
                       2'b00, cfg_gen6_margin_num_timing_steps};

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_gen6_margin_num_timing_steps    <= #TP `DEFAULT_GEN6_RXMARGIN_NUM_TIMING_STEPS;
        cfg_gen6_margin_max_timing_offset   <= #TP `DEFAULT_GEN6_RXMARGIN_MAX_TIMING_OFFSET;
        cfg_gen6_margin_num_voltage_steps   <= #TP `DEFAULT_GEN6_RXMARGIN_NUM_VOLTAGE_STEPS;
        cfg_gen6_margin_max_voltage_offset  <= #TP `DEFAULT_GEN6_RXMARGIN_MAX_VOLTAGE_OFFSET;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_gen6_margin_num_timing_steps    <= #TP pl_reg_id[ID_0x498] & write_pulse[0] ? lbc_cdm_data[ 5: 0] : cfg_gen6_margin_num_timing_steps;
        cfg_gen6_margin_max_timing_offset   <= #TP pl_reg_id[ID_0x498] & write_pulse[1] ? lbc_cdm_data[13: 8] : cfg_gen6_margin_max_timing_offset;
        cfg_gen6_margin_num_voltage_steps   <= #TP pl_reg_id[ID_0x498] & write_pulse[2] ? lbc_cdm_data[22:16] : cfg_gen6_margin_num_voltage_steps;
        cfg_gen6_margin_max_voltage_offset  <= #TP pl_reg_id[ID_0x498] & write_pulse[3] ? lbc_cdm_data[29:24] : cfg_gen6_margin_max_voltage_offset;
   end
end

//------------------------------------------------------------------------------
// GEN6_LANE_MARGINING_2
// Port Logic Offset - `CFG_PL_REG + 0x49C (0xB9C)
// pl_reg_id         - 214
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg     [5:0]         cfg_gen6_margin_sample_rate_voltage;      // [ 5: 0] Number of sampling rate voltage for lane margining at the receiver
reg     [5:0]         cfg_gen6_margin_sample_rate_timing;       // [13: 8] Number of sampling rate timing for lane margining at the receiver
reg     [4:0]         cfg_gen6_margin_maxlanes;                 // [20:16] Maximum number oflane for lane margining at the receiver
reg                   cfg_gen6_margin_voltage_supported;        // [24]    Support of voltage margining for lane margining at the receiver
reg                   cfg_gen6_margin_ind_up_down_voltage;      // [25]    Support of Independent up and down voltage marging for lane margining at the receiver
reg                   cfg_gen6_margin_ind_left_right_timing;    // [26]    Support of Independent left/right margining lane margining at the receiver
reg                   cfg_gen6_margin_sample_reporting_method;  // [27]    Support of Sample reporting method for lane margining at the receiver
reg                   cfg_gen6_margin_ind_error_sampler;        // [28]    Support of Independent error sampler for lane margining at the receiver

assign pl_reg_0x49C = {3'b0, cfg_gen6_margin_ind_error_sampler , cfg_gen6_margin_sample_reporting_method, cfg_gen6_margin_ind_left_right_timing, cfg_gen6_margin_ind_up_down_voltage, cfg_gen6_margin_voltage_supported,
                       3'b000, cfg_gen6_margin_maxlanes,
                       2'b00 , cfg_gen6_margin_sample_rate_timing,
                       2'b00 , cfg_gen6_margin_sample_rate_voltage};

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_gen6_margin_sample_rate_voltage     <= #TP `DEFAULT_GEN6_RXMARGIN_SAMPLE_RATE_VOLTAGE;
        cfg_gen6_margin_sample_rate_timing      <= #TP `DEFAULT_GEN6_RXMARGIN_SAMPLE_RATE_TIMING;
        cfg_gen6_margin_maxlanes                <= #TP `DEFAULT_GEN6_RXMARGIN_MAXLANES;
        cfg_gen6_margin_voltage_supported       <= #TP `DEFAULT_GEN6_RXMARGIN_VOLTAGE_SUPPORTED;
        cfg_gen6_margin_ind_up_down_voltage     <= #TP `DEFAULT_GEN6_RXMARGIN_IND_UP_DOWN_VOLTAGE;
        cfg_gen6_margin_ind_left_right_timing   <= #TP `DEFAULT_GEN6_RXMARGIN_IND_LEFT_RIGHT_TIMING;
        cfg_gen6_margin_sample_reporting_method <= #TP `DEFAULT_GEN6_RXMARGIN_SAMPLE_REPORTING_METHOD;
        cfg_gen6_margin_ind_error_sampler       <= #TP `DEFAULT_GEN6_RXMARGIN_IND_ERROR_SAMPLER;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_gen6_margin_sample_rate_voltage     <= #TP pl_reg_id[ID_0x49C] & write_pulse[0] ? lbc_cdm_data[ 5: 0] : cfg_gen6_margin_sample_rate_voltage;
        cfg_gen6_margin_sample_rate_timing      <= #TP pl_reg_id[ID_0x49C] & write_pulse[1] ? lbc_cdm_data[13: 8] : cfg_gen6_margin_sample_rate_timing;
        cfg_gen6_margin_maxlanes                <= #TP pl_reg_id[ID_0x49C] & write_pulse[2] ? lbc_cdm_data[20:16] : cfg_gen6_margin_maxlanes;
        cfg_gen6_margin_voltage_supported       <= #TP pl_reg_id[ID_0x49C] & write_pulse[3] ? lbc_cdm_data[24]    : cfg_gen6_margin_voltage_supported;
        cfg_gen6_margin_ind_up_down_voltage     <= #TP pl_reg_id[ID_0x49C] & write_pulse[3] ? lbc_cdm_data[25]    : cfg_gen6_margin_ind_up_down_voltage;
        cfg_gen6_margin_ind_left_right_timing   <= #TP pl_reg_id[ID_0x49C] & write_pulse[3] ? lbc_cdm_data[26]    : cfg_gen6_margin_ind_left_right_timing;
        cfg_gen6_margin_sample_reporting_method <= #TP pl_reg_id[ID_0x49C] & write_pulse[3] ? lbc_cdm_data[27]    : cfg_gen6_margin_sample_reporting_method;
        cfg_gen6_margin_ind_error_sampler       <= #TP pl_reg_id[ID_0x49C] & write_pulse[3] ? lbc_cdm_data[28]    : cfg_gen6_margin_ind_error_sampler;
   end
end

// Select the lane margining registers according to current data rate
reg  [5:0]                                    cfg_margin_num_timing_steps;
reg  [5:0]                                    cfg_margin_max_timing_offset;
reg  [6:0]                                    cfg_margin_num_voltage_steps;
reg  [5:0]                                    cfg_margin_max_voltage_offset;
reg  [5:0]                                    cfg_margin_sample_rate_voltage;
reg  [5:0]                                    cfg_margin_sample_rate_timing;
reg  [4:0]                                    cfg_margin_maxlanes;
reg                                           cfg_margin_voltage_supported;
reg                                           cfg_margin_ind_up_down_voltage;
reg                                           cfg_margin_ind_left_right_timing;
reg                                           cfg_margin_sample_reporting_method;
reg                                           cfg_margin_ind_error_sampler;

always @(*) begin
    cfg_margin_num_timing_steps            = cfg_gen4_margin_num_timing_steps;
    cfg_margin_max_timing_offset           = cfg_gen4_margin_max_timing_offset;
    cfg_margin_num_voltage_steps           = cfg_gen4_margin_num_voltage_steps;
    cfg_margin_max_voltage_offset          = cfg_gen4_margin_max_voltage_offset;
    cfg_margin_sample_rate_voltage         = cfg_gen4_margin_sample_rate_voltage;
    cfg_margin_sample_rate_timing          = cfg_gen4_margin_sample_rate_timing;
    cfg_margin_maxlanes                    = cfg_gen4_margin_maxlanes;
    cfg_margin_voltage_supported           = cfg_gen4_margin_voltage_supported;
    cfg_margin_ind_up_down_voltage         = cfg_gen4_margin_ind_up_down_voltage;
    cfg_margin_ind_left_right_timing       = cfg_gen4_margin_ind_left_right_timing;
    cfg_margin_sample_reporting_method     = cfg_gen4_margin_sample_reporting_method;
    cfg_margin_ind_error_sampler           = cfg_gen4_margin_ind_error_sampler;
    if(current_data_rate==`GEN5_RATE) begin
        cfg_margin_num_timing_steps            = cfg_gen5_margin_num_timing_steps;
        cfg_margin_max_timing_offset           = cfg_gen5_margin_max_timing_offset;
        cfg_margin_num_voltage_steps           = cfg_gen5_margin_num_voltage_steps;
        cfg_margin_max_voltage_offset          = cfg_gen5_margin_max_voltage_offset;
        cfg_margin_sample_rate_voltage         = cfg_gen5_margin_sample_rate_voltage;
        cfg_margin_sample_rate_timing          = cfg_gen5_margin_sample_rate_timing;
        cfg_margin_maxlanes                    = cfg_gen5_margin_maxlanes;
        cfg_margin_voltage_supported           = cfg_gen5_margin_voltage_supported;
        cfg_margin_ind_up_down_voltage         = cfg_gen5_margin_ind_up_down_voltage;
        cfg_margin_ind_left_right_timing       = cfg_gen5_margin_ind_left_right_timing;
        cfg_margin_sample_reporting_method     = cfg_gen5_margin_sample_reporting_method;
        cfg_margin_ind_error_sampler           = cfg_gen5_margin_ind_error_sampler;
    end
    if(current_data_rate==`GEN6_RATE) begin
        cfg_margin_num_timing_steps            = cfg_gen6_margin_num_timing_steps;
        cfg_margin_max_timing_offset           = cfg_gen6_margin_max_timing_offset;
        cfg_margin_num_voltage_steps           = cfg_gen6_margin_num_voltage_steps;
        cfg_margin_max_voltage_offset          = cfg_gen6_margin_max_voltage_offset;
        cfg_margin_sample_rate_voltage         = cfg_gen6_margin_sample_rate_voltage;
        cfg_margin_sample_rate_timing          = cfg_gen6_margin_sample_rate_timing;
        cfg_margin_maxlanes                    = cfg_gen6_margin_maxlanes;
        cfg_margin_voltage_supported           = cfg_gen6_margin_voltage_supported;
        cfg_margin_ind_up_down_voltage         = cfg_gen6_margin_ind_up_down_voltage;
        cfg_margin_ind_left_right_timing       = cfg_gen6_margin_ind_left_right_timing;
        cfg_margin_sample_reporting_method     = cfg_gen6_margin_sample_reporting_method;
        cfg_margin_ind_error_sampler           = cfg_gen6_margin_ind_error_sampler;
    end
end

//------------------------------------------------------------------------------
// PIPE_RELATED_REG
// Port Logic Offset - `CFG_PL_REG + 0x490 (0xB90)
// pl_reg_id         - 166
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
logic                 cfg_pam4_restricted_levels_requirement; // [ 9]    PAM4 Restricted Levels Requirement
reg                   reg_pipe_garbage_data_mode;             // [ 8]    PIPE Garbage data mode
wire    [3:0]         cfg_tx_message_bus_write_buffer_depth;  // [ 7: 4] Tx Message Bus Write Buffer Depth
logic   [3:0]         cfg_rx_message_bus_write_buffer_depth;  // [ 3: 0] Rx Message Bus Write Buffer Depth


assign pl_reg_0x490 = {{22{1'b0}}, cfg_pam4_restricted_levels_requirement,reg_pipe_garbage_data_mode, cfg_tx_message_bus_write_buffer_depth, cfg_rx_message_bus_write_buffer_depth};

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        reg_pipe_garbage_data_mode <= #TP `DEFAULT_PIPE_GARBAGE_DATA_MODE;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        reg_pipe_garbage_data_mode <= #TP pl_reg_id[ID_0x490] & write_pulse[1] ? lbc_cdm_data[ 8] : reg_pipe_garbage_data_mode;
   end
end

assign cfg_pipe_garbage_data_mode = reg_pipe_garbage_data_mode
                                 || cfg_pipe_loopback
                                   ;

assign cfg_tx_message_bus_write_buffer_depth = `DEFAULT_TX_MESSAGE_BUS_MIN_WRITE_BUFFER_DEPTH;

// --- Register
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_rx_message_bus_write_buffer_depth   <= #TP `DEFAULT_RX_MESSAGE_BUS_WRITE_BUFFER_DEPTH;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_rx_message_bus_write_buffer_depth   <= #TP pl_reg_id[ID_0x490] & write_pulse[0] ? lbc_cdm_data[ 3: 0] : cfg_rx_message_bus_write_buffer_depth;
   end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_pam4_restricted_levels_requirement <= #TP `DEFAULT_PAM4_RESTRICTED_LEVELS_REQUIREMENT;
    end
    else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_pam4_restricted_levels_requirement <= #TP pl_reg_id[ID_0x490] & write_pulse[1] ? lbc_cdm_data[ 9] : cfg_pam4_restricted_levels_requirement;
    end
end



// =============================================================================
// Flow Control Latency Timer
// =============================================================================
reg     [12:0]  cfg_fc_latency_value;
wire    [12:0]  spec_fc_latency_value;
wire    [12:0]  int_fc_latency_value;
wire    [12:0]  total_fc_delay,queue_pop_time,fcgen_dly,l2_dly;

// subtract 19 out of latency value because this is the PCI Express spec fixed internal delay used
// in "Flow Control Update Frequency" calculation.  This latency(internal delay) is accounted for
// by credits advertised
// subtract 1 because fc latency timer expires at 0 not 1
assign total_fc_delay        = 20;
assign spec_fc_latency_value = get_fc_latency_value(
                                   cfg_min_payload_size
                                 , smlh_autoneg_link_width
                                 );
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: Largest value of spec_fc_latency_value is 4143, min is 48, total_fc_delay is
// a constant, 20. No carry/borrow needed
assign int_fc_latency_value  = (spec_fc_latency_value - total_fc_delay);
// spyglass enable_block W164a

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_fc_latency_value    <= #TP 0;
    end else if (fc_timer_override) begin
        cfg_fc_latency_value    <= #TP fc_timer_override_val;
    end else begin
        cfg_fc_latency_value    <= #TP int_fc_latency_value;
    end
end

function automatic [12:0] get_fc_latency_value;
    input   [2:0]   cfg_max_payload_size;
    input   [5:0]   smlh_link_mode;

    reg     [5:0]   link_width;
    reg     [2:0]   max_payload;

begin
    // Make sure we optimize things away based on the actual number of lanes
    link_width[0]   =            & smlh_link_mode[0];
    link_width[1]   = (RXNL > 1) & smlh_link_mode[1];
    link_width[2]   = (RXNL > 2) & smlh_link_mode[2];
    link_width[3]   = (RXNL > 4) & smlh_link_mode[3];
    link_width[4]   = (RXNL > 8) & smlh_link_mode[4];
    link_width[5]   = (RXNL >16) & smlh_link_mode[5];

    max_payload     = cfg_max_payload_size;

    case (link_width)

             6'b000001 : case(max_payload)
                        // x1
                        3'b001  :   get_fc_latency_value  = 416 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 559 ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 1071;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 2095;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 4143;  // 4096 bytes
                        default :   get_fc_latency_value  = 237 ;  // 128 bytes   3'b000
                    endcase

             6'b000010 : case(max_payload)
                        //  x2
                        3'b001  :   get_fc_latency_value  = 217 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 289 ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 545 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 1057;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 2081;  // 4096 bytes
                        default :   get_fc_latency_value  = 128 ;  // 128 bytes   3'b000
                    endcase

             6'b000100 : case(max_payload)
                        //  x4
                        3'b001  :   get_fc_latency_value  = 118 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 154 ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 282 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 538 ;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 1050;  // 4096 bytes
                        default :   get_fc_latency_value  = 73  ;  // 128 bytes   3'b000
                    endcase

             6'b001000 : case(max_payload)
                        //  x8
                        3'b001  :   get_fc_latency_value  = 107 ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 86  ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 150 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 278 ;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 534 ;  // 4096 bytes
                        default :   get_fc_latency_value  = 67  ;  // 128 bytes   3'b000
                    endcase

             default :   case(max_payload)
                        //  Error on the side of more frequent updates
                        3'b000  :   get_fc_latency_value  = 48  ;  // 128 bytes
                        3'b001  :   get_fc_latency_value  = 72  ;  // 256 bytes
                        3'b010  :   get_fc_latency_value  = 86  ;  // 512 bytes
                        3'b011  :   get_fc_latency_value  = 150 ;  // 1024 bytes
                        3'b100  :   get_fc_latency_value  = 278 ;  // 2048 bytes
                        3'b101  :   get_fc_latency_value  = 534 ;  // 4096 bytes
                        default :   get_fc_latency_value  = 48  ;  // 128 bytes
                    endcase
    endcase
end
endfunction




//------------------------------------------------------------------------------
// CXL_VLSM_CR
// Port Logic Offset - `CFG_PL_REG + 0x548 (0xC48)
// pl_reg_id         - ID_0x548
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg cxl_vlsm_to_active;          //Force VLSM to Active state
reg cxl_vlsm_pm_enable;          //Enables Low Power mode entry.
// PhyLogic
reg cxl_apn_bypass_enable;       //Enable Alternate Protocol Bypass. 1: bypass, 0: no bypass
wire cxl_apn_sw_mode;            //Alternate Protocol Negotiation result mode for SW device (0) Based on cXL 2.0 spec (1) Specific negotiation
reg [2:0] cxl_mc_almp_unexp_error_reg, cxl_io_almp_unexp_error_reg;
wire cxl_almp_unexp_error_clr;
assign cxl_almp_unexp_error_clr = (pl_reg_id[ID_0x548] & ~(|write_pulse));
assign cxl_apn_sw_mode = 1'b0;

assign pl_reg_0x548 = {cxl_mc_almp_unexp_error_reg, cxl_io_almp_unexp_error_reg, cxl_apn_sw_mode, cxl_apn_bypass_enable, cxl_vlsm_pm_enable, cxl_vlsm_to_active, 6'h00,          // 0x54B, 0x54A
                       4'h0, cxl_vlsm_state, cxl_cache_mem_vlsm_state, cxl_io_vlsm_state};                                                                                       // 0x549, 0x548

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cxl_vlsm_to_active      <= #TP 1'b0;
        cxl_vlsm_pm_enable      <= #TP 1'b1;
    end else begin
        cxl_vlsm_to_active      <= #TP (write_pulse[2] & pl_reg_id[ID_0x548]) ? lbc_cdm_data[22] : cxl_vlsm_to_active;
        cxl_vlsm_pm_enable      <= #TP (write_pulse[2] & pl_reg_id[ID_0x548]) ? lbc_cdm_data[23] : cxl_vlsm_pm_enable;
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cxl_mc_almp_unexp_error_reg <= #TP '0;
        cxl_io_almp_unexp_error_reg <= #TP '0;
    end else begin
        cxl_mc_almp_unexp_error_reg <= #TP (|cxl_mc_almp_unexp_error) ? cxl_mc_almp_unexp_error : (cxl_almp_unexp_error_clr ? '0 : cxl_mc_almp_unexp_error_reg);
        cxl_io_almp_unexp_error_reg <= #TP (|cxl_io_almp_unexp_error) ? cxl_io_almp_unexp_error : (cxl_almp_unexp_error_clr ? '0 : cxl_io_almp_unexp_error_reg);
    end
end
// PhyLogic
always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_apn_bypass_enable_PROC
    if (!sticky_rst_n) begin
        cxl_apn_bypass_enable   <= #TP 1'b0;
    end else begin
        cxl_apn_bypass_enable   <= #TP (write_pulse[3] & pl_reg_id[ID_0x548]) ? lbc_cdm_data[24] : cxl_apn_bypass_enable;
    end
end // cxl_apn_bypass_enable_PROC

//------------------------------------------------------------------------------
// CXL_LRSM_CSR
// Port Logic Offset - `CFG_PL_REG + 0x54C (0xC4C)
// pl_reg_id         - ID_0x54C
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg [4:0] cxl_max_num_retry;
reg [4:0] cxl_max_num_reinit;

assign pl_reg_0x54C = {
                       9'h0, cxl_lrsm_fatal_error, cxl_lrsm_state,                       // 0x54F, 0x54E
                       3'h0, cxl_max_num_reinit,                                         // 0x54D
                       3'h0, cxl_max_num_retry};                                         // 0x54C

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cxl_max_num_retry      <= #TP 5'hA;
        cxl_max_num_reinit     <= #TP 5'hA;
    end else begin
        cxl_max_num_retry      <= #TP (write_pulse[0] & pl_reg_id[ID_0x54C]) ? lbc_cdm_data[4:0] : cxl_max_num_retry;
        cxl_max_num_reinit     <= #TP (write_pulse[1] & pl_reg_id[ID_0x54C]) ? lbc_cdm_data[12:8] : cxl_max_num_reinit;
    end
end


//------------------------------------------------------------------------------
// CXL_LL_TIMER_CR
// Port Logic Offset - `CFG_PL_REG + 0x550 (0xC50)
// pl_reg_id         - ID_0x550
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
reg [15:0] cxl_lrsm_timeout_threshold;
reg [9:0]  cxl_crc_threshold;

assign pl_reg_0x550 = {
                       6'h0, cxl_crc_threshold, cxl_lrsm_timeout_threshold};                    // 0x550

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cxl_lrsm_timeout_threshold <= #TP 16'd4096;
        cxl_crc_threshold          <= #TP 'h1;
    end else begin
        cxl_lrsm_timeout_threshold[7:0] <= #TP (write_pulse[0] & pl_reg_id[ID_0x550]) ? lbc_cdm_data[7:0] : cxl_lrsm_timeout_threshold[7:0];
        cxl_lrsm_timeout_threshold[15:8]<= #TP (write_pulse[1] & pl_reg_id[ID_0x550]) ? lbc_cdm_data[15:8] : cxl_lrsm_timeout_threshold[15:8];
        cxl_crc_threshold[7:0]          <= #TP (write_pulse[2] & pl_reg_id[ID_0x550]) ? lbc_cdm_data[23:16] : cxl_crc_threshold[7:0];
        cxl_crc_threshold[9:8]          <= #TP (write_pulse[3] & pl_reg_id[ID_0x550]) ? lbc_cdm_data[25:24] : cxl_crc_threshold[9:8];
    end
end
//------------------------------------------------------------------------------
// CXL_FATAL_ERROR_CR
// Port Logic Offset - `CFG_PL_REG + 0x554 (0xC54)
// pl_reg_id         - ID_0x554
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
// Bit    0   (RO) Retry_Ack_Viral: Retry.Ack control flit is received with Viral status. Valid if Viral is enabled.
// Bit    1   (RO) RAS_Error: RAS uncorrectable error detected.
// Bit    2   (RO) LL_Static_Bit_Error: Static bit error is detected in the received LL Control Flit.
// Bit    3   (RO) LRSM_Abort: LRSM FSM reached Abort state.
// Bit    4   (RO) LRSM_Ack_Error: Unexpected Retry.Ack flit is received.
// Bit    5   (RO) RSVD_CRD_ENC_Error: CXL Reserved Credit Encoding Error
// Bit    6   (RO) CXL_CXS_FIFO_Overflow: CXL CXS FIFO Overflow
// Bit    7   (RO) RX_RASDP_Error: RASDP Uncorrectable Error is detected on Rx Path
// Bit    8   (RO) N/A: Resereved
// Bit    9   (RO) N/A: Resereved
// Bit   10   (RO) LL_Init_Param_Error: Non-Retry flits received before LLCTRL-INIT.Param flit.
// Bit   11   (RO) LL_Multi_Init_Param: Receipt of an LLCTRL-INIT.Param flit after an LLCTRL-INIT.Param flit has already been received.
// Bit   12   (RO) Retry_Ack_Overflow: Acknowledge Counter Overflow.
// Bits 18-13 (RO) LL_RX_CreditReturn_Error: CXL Receiver Credit Returm Error:
//                   Bit 0 - Mem BI Credit Return Overflow
//                   Bit 1 - Cache Request Credit Return Overflow
//                   Bit 2 - Cache Response Credit Return Overflow
//                   Bit 3 - Cache Data Credit Return Overflow
//                   Bit 4 - Mem NDR/RequestOnly Credit Return Overflow
//                   Bit 5 - Mem DRC/RwD Credit Return Overflow
// Bit   19   (RO) ULL_CXS_EndError: ULL Transmits CXS Flit with ENDERROR bit set in the Control Bus to trigger Viral Mode.
// Bit   20   (RO) CXS_TX_EndError: If CXS Controller transmits CXS Flit with ENDERROR bit set in the Control Bus then trigger Viral Mode.
// Bit   21   (RO) App_Viral_Request: Set this bit if the Applications requests to trigger Viral Mode in CXL Controller.
// Bit   22   (RO) H2D_Ordering_Violation: H2D Response/Request ordering violation detected.
// Bit   23   (RO) TX_RASDP_Error: RASDP Uncorrectable Error is detected on Tx Path
// Bit   24   (RO) Cache_Data_Valid_Error: H2D/D2H Data Valid Error.
// Bit   25   (RO) Mem_Data_Valid_Error: M2S/S2M Data Valid Error.
// Bit   26   (RO) MDH_Error: Multi-Data Header is received when MDH is disabled.
// Bit   27   (RO) IDE_TX_SecureIF_Error: IDE TX Data Protection Error on Secure IF.
// Bit   28   (RO) IDE_TX_PlainIF_Error: IDE TX Data Protection Error on Plain IF.
// Bit   29   (RO) IDE_RX_SecureIF_Error: IDE RX Data Protection Error on Secure IF.
// Bit   30   (RO) IDE_RX_PlainIF_Error: IDE RX Data Protection Error on Plain IF.

assign cxl_ras_uncorr_err = |cxl_fatal_error_reg[31:1];

assign pl_reg_0x554 = cxl_fatal_error_reg;

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cxl_fatal_error_reg <= #TP '0;
    end
    else begin
        cxl_fatal_error_reg <= #TP (cxl_fatal_error_reg & { (write_pulse[3] & pl_reg_id[ID_0x554]) ? ~lbc_cdm_data[31:24] : 8'hFF ,
                                                            (write_pulse[2] & pl_reg_id[ID_0x554]) ? ~lbc_cdm_data[23:16] : 8'hFF ,
                                                            (write_pulse[1] & pl_reg_id[ID_0x554]) ? ~lbc_cdm_data[15: 8] : 8'hFF ,
                                                            (write_pulse[0] & pl_reg_id[ID_0x554]) ? ~lbc_cdm_data[ 7: 0] : 8'hFF }) | cxl_fatal_error;
    end
end
//------------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Error Injection Registers
// -----------------------------------------------------------------------------

//------------------------------------------------------------------------------
// CXL.cache/CXL.mem LinkLayerErrorInjection
// Port Logic Offset - `CFG_PL_REG + 0x558 (0xC58)
// pl_reg_id         - ID_0x558
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------

reg cm_ll_cache_poison_injection_start;
reg cm_ll_mem_poison_injection_start;
reg cm_ll_io_poison_injection_start;
reg [1:0] cm_ll_cache_mem_crc_injection;
reg [1:0] cm_ll_cache_mem_crc_injection_count;

assign pl_reg_0x558 = { 21'd0, cm_ll_cache_mem_crc_injection_busy, cm_ll_cache_mem_crc_injection_count, cm_ll_cache_mem_crc_injection, cm_ll_io_poison_injection_busy, cm_ll_io_poison_injection_start, cm_ll_mem_poison_injection_busy, cm_ll_mem_poison_injection_start, cm_ll_cache_poison_injection_busy, cm_ll_cache_poison_injection_start };

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cm_ll_cache_poison_injection_start  <= #TP 0;
        cm_ll_mem_poison_injection_start    <= #TP 0;
        cm_ll_io_poison_injection_start     <= #TP 0;
        cm_ll_cache_mem_crc_injection_count <= #TP 0;

    end else begin
        cm_ll_cache_poison_injection_start  <= #TP (write_pulse[0] & pl_reg_id[ID_0x558]) ? lbc_cdm_data[0]   : (cm_ll_cache_poison_injection_busy ? '0 : cm_ll_cache_poison_injection_start);
        cm_ll_mem_poison_injection_start    <= #TP (write_pulse[0] & pl_reg_id[ID_0x558]) ? lbc_cdm_data[2]   : (cm_ll_mem_poison_injection_busy ? '0 : cm_ll_mem_poison_injection_start);
        cm_ll_io_poison_injection_start     <= #TP (write_pulse[0] & pl_reg_id[ID_0x558]) ? lbc_cdm_data[4]   : (cm_ll_io_poison_injection_busy ? '0 : cm_ll_io_poison_injection_start);
        cm_ll_cache_mem_crc_injection_count <= #TP (write_pulse[1] & pl_reg_id[ID_0x558]) ? lbc_cdm_data[9:8] : (cm_ll_cache_mem_crc_injection_busy ? '0 : cm_ll_cache_mem_crc_injection_count);
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cm_ll_cache_mem_crc_injection       <= #TP 0;

    end else begin
      
        cm_ll_cache_mem_crc_injection       <= #TP (write_pulse[0] & pl_reg_id[ID_0x558]) ? lbc_cdm_data[7:6] : cm_ll_cache_mem_crc_injection;
        
    end
end

//------------------------------------------------------------------------------
// CXL.io LinkLayer Error injection
// Port Logic Offset - `CFG_PL_REG + 0x55C (0xC5C)
// pl_reg_id         - ID_0x55C
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------

reg io_ll_io_poison_injection_start;
reg io_ll_flow_ctrl_error_injection;

assign pl_reg_0x55C = { 28'd0, io_ll_flow_ctrl_error_injection_busy, io_ll_flow_ctrl_error_injection, io_ll_io_poison_injection_busy, io_ll_io_poison_injection_start };

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        io_ll_io_poison_injection_start  <= #TP 0;
        io_ll_flow_ctrl_error_injection  <= #TP 0;

    end else begin
        io_ll_io_poison_injection_start  <= #TP (write_pulse[0] & pl_reg_id[ID_0x55C]) ? lbc_cdm_data[0] : (io_ll_io_poison_injection_busy ? '0 : io_ll_io_poison_injection_start);
        io_ll_flow_ctrl_error_injection  <= #TP (write_pulse[0] & pl_reg_id[ID_0x55C]) ? lbc_cdm_data[2] : (io_ll_flow_ctrl_error_injection_busy ? '0 : io_ll_flow_ctrl_error_injection);
    end
end

//------------------------------------------------------------------------------
// Flex Bus LogPHY Error injection
// Port Logic Offset - `CFG_PL_REG + 0x560 (0xC60)
// pl_reg_id         - ID_0x560
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------

reg fb_phy_cor_protid_error_injection;
reg fb_phy_uncor_protid_error_injection;
reg fb_phy_unexp_protid_error_injection;

assign pl_reg_0x560 = { 28'd0, fb_phy_protid_injection_busy, fb_phy_unexp_protid_error_injection, fb_phy_uncor_protid_error_injection, fb_phy_cor_protid_error_injection };

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        fb_phy_cor_protid_error_injection    <= #TP 0;
        fb_phy_uncor_protid_error_injection  <= #TP 0;
        fb_phy_unexp_protid_error_injection  <= #TP 0;

    end else begin
        fb_phy_cor_protid_error_injection   <= #TP (write_pulse[0] & pl_reg_id[ID_0x560]) ? lbc_cdm_data[0] : (fb_phy_protid_injection_busy ? '0 : fb_phy_cor_protid_error_injection);
        fb_phy_uncor_protid_error_injection <= #TP (write_pulse[0] & pl_reg_id[ID_0x560]) ? lbc_cdm_data[1] : (fb_phy_protid_injection_busy ? '0 : fb_phy_uncor_protid_error_injection);
        fb_phy_unexp_protid_error_injection <= #TP (write_pulse[0] & pl_reg_id[ID_0x560]) ? lbc_cdm_data[2] : (fb_phy_protid_injection_busy ? '0 : fb_phy_unexp_protid_error_injection);
    end
end


//------------------------------------------------------------------------------
// CXL Port Logic Viral Status
// Port Logic Offset - `CFG_PL_REG + 0x564 (0xC64)
// pl_reg_id         - ID_0x564
// Length            - 4 bytes
// Default value     -
//------------------------------------------------------------------------------
wire cxl_viral_status_clr;
assign cxl_viral_status_clr = (pl_reg_id[ID_0x564] & write_pulse[0] & lbc_cdm_data[0]);

reg cxl_viral_status;
always @(posedge core_clk or negedge non_sticky_rst_n) begin
    if (!non_sticky_rst_n) begin
        cxl_viral_status    <= #TP 0;
    end else if(cxl_viral_status_set)begin
        cxl_viral_status    <= #TP 1'b1;
    end else begin
        cxl_viral_status    <= #TP cxl_viral_status_clr ? 1'b0 : cxl_viral_status;
    end
end

assign pl_reg_0x564 = {31'h0, cxl_viral_status};


//------------------------------------------------------------------------------
// VDM Traffic during non-D0 states: PCIMPM_TRAFFIC_CTRL
// Port Logic Offset - `CFG_PL_REG + 0x41C
// pl_reg_id         - ID_0x41C
// Length            - 1 byte
// Default value     -
//------------------------------------------------------------------------------
reg    cfg_nond0_vdm_block;
reg    cfg_client0_block_new_tlp;
reg    cfg_client1_block_new_tlp;
reg    cfg_client2_block_new_tlp;

assign pl_reg_0x41C = {4'b0000,
                       cfg_client2_block_new_tlp,cfg_client1_block_new_tlp,cfg_client0_block_new_tlp,cfg_nond0_vdm_block};   // 0x41C

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_nond0_vdm_block        <= #TP `CX_BLOCK_VDM_TLP;
        cfg_client0_block_new_tlp  <= #TP `CX_CLIENT0_BLOCK_NEW_TLP;
        cfg_client1_block_new_tlp  <= #TP `CX_CLIENT1_BLOCK_NEW_TLP;
        cfg_client2_block_new_tlp  <= #TP `CX_CLIENT2_BLOCK_NEW_TLP;
    end else begin
        cfg_nond0_vdm_block        <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[0]   : cfg_nond0_vdm_block;
        cfg_client0_block_new_tlp  <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[1]   : cfg_client0_block_new_tlp;
        cfg_client1_block_new_tlp  <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[2]   : cfg_client1_block_new_tlp;
        cfg_client2_block_new_tlp  <= #TP (write_pulse[0] & pl_reg_id[ID_0x41C]) ? lbc_cdm_data[3]   : cfg_client2_block_new_tlp;
    end
end





//----------------------------------------------------------------------------------------
// DBI Function Bank Control (Offset 57C)
// Port Logic Offset - `CFG_PL_REG + 0x57C
// pl_reg_id         - ID_0x57C
// Length           - 4 bytes
// Default value    - 0
// ---------------------------------------------------------------------------------------
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
      cfg_dbi_func_bank_select[0]   <= #TP 1'b0;
    end
    else begin
      
      // Enable shared DBI function bank select for upstream port only when the number of
      // functions > 32. Effectively, for EP or DM upstream port only, as this signal will not be used in
      // a Switch.
      cfg_dbi_func_bank_select[0]   <= #TP (write_pulse[0] & pl_reg_id[ID_0x57C] & upstream_port) ? lbc_cdm_data[0]   : cfg_dbi_func_bank_select[0];
    end
end
always_comb
begin
      cfg_dbi_func_bank_select[2:1] = 2'b0;
end

assign dbi_func_bank_control = {29'h0, cfg_dbi_func_bank_select};





//------------------------------------------------------------------------------
// CXL IDE Error Injection (Offset 590h)
// Port Logic Offset - `CFG_PL_REG + 0x590
// pl_reg_id     - ID_Ox590
// Length        - 4 byte
// Default value - 0
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// AXI Inbound Posted ID Management Control (Offset 594h)
// Port Logic Offset - `CFG_PL_REG + 0x594
// pl_reg_id     - ID_Ox594
// Length        - 1 byte
// Default value - 0
//------------------------------------------------------------------------------
logic [7:0] r_ib_p_id_mng_vc_ro_remap_en;

always_ff @(posedge core_clk, negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    r_ib_p_id_mng_vc_ro_remap_en <= #TP '1;
  end else begin
    r_ib_p_id_mng_vc_ro_remap_en <= #TP (write_pulse[0] & pl_reg_id[ID_0x594]) ? lbc_cdm_data[7:0] : r_ib_p_id_mng_vc_ro_remap_en;
  end
end

assign cfg_ib_p_id_mng_ctrl = r_ib_p_id_mng_vc_ro_remap_en[`CX_NVC-1:0];

assign pl_reg_0x594 = (32)'(r_ib_p_id_mng_vc_ro_remap_en);

//------------------------------------------------------------------------------
// PRBS loopback Test Control (Offset 5ACh)
// Port Logic Offset - `CFG_PL_REG + 0x5AC
// pl_reg_id     - ID_Ox5AC
// Length        - 4 byte
// Default value - 0
//------------------------------------------------------------------------------

always_ff @(posedge core_clk, negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    cfg_prbs_en       <= #TP 1'b0;
    cfg_prbs_lane_sel <= #TP 4'h0;
    clear_prbs_done   <= #TP 1'b0;
  end else begin
    cfg_prbs_en       <= #TP (write_pulse[0] & pl_reg_id[ID_0x5AC]) ? lbc_cdm_data[0] : cfg_prbs_en;
    cfg_prbs_lane_sel <= #TP (write_pulse[0] & pl_reg_id[ID_0x5AC]) ? lbc_cdm_data[6:3] : cfg_prbs_lane_sel;
    clear_prbs_done   <= #TP (write_pulse[0] & pl_reg_id[ID_0x5AC] & lbc_cdm_data[1]);
  end
end

// To avoid SpyGlass ImproperRangeIndex-ML
logic [2:0] prbs_lane_sel_tmp;
assign prbs_lane_sel_tmp = (cfg_prbs_lane_sel<=(NL-1))? cfg_prbs_lane_sel[2:0] : 3'h0;

logic                     prbs_unexp_fail_lanex;
logic  [7:0]              prbs_err_cntr_lanex;
logic                     prbs_started_lanex;
logic  [NL-1:0]           rmlh_prbs_started_d;
logic  [NL-1:0][7:0]      rmlh_prbs_err_cntr_d;
logic  [NL-1:0]           rmlh_prbs_unexp_fail_d;
logic                     rmlh_prbs_fail_d;
logic                     rmlh_prbs_done_d;
logic                     clear_prbs_reg;

assign clear_prbs_stat = clear_prbs_done;

// Latch PRBS status registers not to clear by core_rst_n
always_ff @(posedge core_clk, negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    rmlh_prbs_started_d    <= #TP '0;
    rmlh_prbs_err_cntr_d   <= #TP '0;
    rmlh_prbs_unexp_fail_d <= #TP '0;
    rmlh_prbs_fail_d       <= #TP '0;
    rmlh_prbs_done_d       <= #TP '0;
  end
  else begin
    if( clear_prbs_stat )begin
      rmlh_prbs_started_d    <= #TP '0;
    end else if( rmlh_prbs_started != '0 )begin
      rmlh_prbs_started_d <= #TP rmlh_prbs_started;
    end
    if( clear_prbs_stat )begin
      rmlh_prbs_err_cntr_d    <= #TP '0;
    end else if( rmlh_prbs_err_cntr != '0 )begin
      rmlh_prbs_err_cntr_d <= #TP rmlh_prbs_err_cntr;
    end
    if( clear_prbs_stat )begin
      rmlh_prbs_unexp_fail_d    <= #TP '0;
    end else if( rmlh_prbs_unexp_fail != '0 )begin
      rmlh_prbs_unexp_fail_d <= #TP rmlh_prbs_unexp_fail;
    end
    if( clear_prbs_stat )begin
      rmlh_prbs_fail_d    <= #TP '0;
    end else if( rmlh_prbs_fail != '0 )begin
      rmlh_prbs_fail_d <= #TP rmlh_prbs_fail;
    end
    if( clear_prbs_stat )begin
      rmlh_prbs_done_d    <= #TP '0;
    end else if( rmlh_prbs_done != '0 )begin
      rmlh_prbs_done_d <= #TP rmlh_prbs_done;
    end
  end
end

always_ff @(posedge core_clk, negedge sticky_rst_n) begin
  if (!sticky_rst_n) begin
    prbs_unexp_fail_lanex   <= #TP 1'b0;
    prbs_err_cntr_lanex     <= #TP 7'h0;
    prbs_started_lanex      <= #TP 1'b0;
  end else begin
    prbs_unexp_fail_lanex   <= #TP rmlh_prbs_unexp_fail_d[prbs_lane_sel_tmp];
    prbs_err_cntr_lanex     <= #TP rmlh_prbs_err_cntr_d[prbs_lane_sel_tmp];
    prbs_started_lanex      <= #TP rmlh_prbs_started_d[prbs_lane_sel_tmp];
  end
end
assign pl_reg_0x5AC = {15'h0,
    prbs_unexp_fail_lanex,     // [16]
    prbs_err_cntr_lanex,       // [15:8]
    prbs_started_lanex,        // [7]
    cfg_prbs_lane_sel,         // [6:3]
    rmlh_prbs_fail_d,          // [2]
    rmlh_prbs_done_d,          // [1]
    cfg_prbs_en};              // [0]







endmodule
