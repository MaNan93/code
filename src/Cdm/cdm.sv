
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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #97 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm.sv#97 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the following functions (for both type 0 and type 1 device)
// ---   - PCI-Compatible configuration registers
// ---   - PM capability registers
// ---   - PCIE capability registers
// ---   - MSI capability registers
// ---   - Advanced Error capability registers
// ---   - Virtual Channel capability registers
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Cdm/cdm_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Cdm/cdm_ras_pkg.svh"
`include "products/pcie_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

 module cdm
 import DWC_pcie_ctl_pkg::PM_MST_WD;
 import DWC_pcie_ctl_pkg::PM_SLV_WD;
 import DWC_pcie_ctl_pkg::MSG_TLP_WD;
 import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
   import DWC_pcie_ctl_pkg::CRGB_ADDR_WIDTH;
   import DWC_pcie_ctl_pkg::CRGB_DATA_WIDTH;
   import DWC_pcie_ctl_pkg::CRGB_BE_WIDTH;
   import DWC_pcie_ctl_pkg::N_XADM_IF;
   import DWC_pcie_ctl_pkg::N_XADM_P_IF;
   import DWC_pcie_core_pkg::radm_hdr_log_s;
   import DWC_pcie_core_pkg::UNCORR_INT_ERR;
   import DWC_pcie_core_pkg::RECEIVER_OVRFLW;
   import DWC_pcie_core_pkg::MALFORMED_TLP;
   import DWC_pcie_core_pkg::IDE_CHK_FAILED;
   import DWC_pcie_core_pkg::ECRC_CHK_FAILED;
   import DWC_pcie_core_pkg::MISROUTED_IDE_TLP;
   import DWC_pcie_core_pkg::ATOMIC_OP_EGRSS;
   import DWC_pcie_core_pkg::DMWR_REQUEST_EGRSS_BLOCKD;
   import DWC_pcie_core_pkg::TLP_TRANS_EGRSS_BLOCKD;
   import DWC_pcie_core_pkg::TLP_PRFX_BLOCKD;
   import DWC_pcie_core_pkg::ACS_VIOLATION;
   import DWC_pcie_core_pkg::MC_BLOCKD_TLP;
   import DWC_pcie_core_pkg::UNSUPP_REQUEST;
   import DWC_pcie_core_pkg::COMPLETER_ABORT;
   import DWC_pcie_core_pkg::UNEXP_COMPLETION;
   import DWC_pcie_core_pkg::PCRC_CHECK_FAILED;
   import DWC_pcie_core_pkg::POISONED_TLP_RECEIVED;
   import DWC_pcie_core_pkg::POISONED_TLP_EGRSS_BLOCKD;
   import DWC_pcie_core_pkg::xadm_xmt_pci_errors_t;
   import DWC_pcie_ctl_pkg::ANTI_CTRL_PIPE_DELAY;
   import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
   import DWC_pcie_ctl_pkg::N_XADM_CPL_IF;
   import DWC_pcie_ctl_pkg::N_CCIX_IF;
   import DWC_pcie_ctl_pkg::N_XALI_IF;
   import DWC_pcie_ctl_pkg::NVC_WD;
   import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
   import cdm_ras_pkg::ras_err_tracer_ctrl_s;
   import cdm_ras_pkg::ras_err_tracer_rpt_s;
   import cdm_ras_pkg::ras_err_inj_mgr_ctrl_s;
   import cdm_ras_pkg::ras_err_inj_ack_s;
 import DWC_pcie_core_pkg::rplh_flit_logging_interface_struct;
 import DWC_pcie_core_pkg::rmlh_flit_logging_interface_struct;
 import DWC_pcie_core_pkg::smlh_flit_logging_interface_struct;
 import DWC_pcie_core_pkg::xplh_cdm_flit_latency_track_t;
 import DWC_pcie_core_pkg::pm_cdm_state_trans_track_t;
   import DWC_pcie_ctl_pkg::ATU_OUT_NREGIONS;
   import DWC_pcie_ctl_pkg::ATU_IN_NREGIONS;
   import DWC_pcie_ctl_pkg::ATU_BASE_WD;
   import DWC_pcie_ctl_pkg::ATU_REG_WD;
   import DWC_pcie_ctl_pkg::ATU_UPR_LMT_WD;
   import DWC_pcie_ctl_pkg::ATU_REG_LWR_WD;
   import DWC_pcie_ctl_pkg::ATU_OUT_NREGIONS_MIN1;
   import DWC_pcie_ctl_pkg::ATU_IN_NREGIONS_MIN1;
  import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
  import DWC_pcie_core_pkg::flit_err_inj_status_struct;
  import DWC_pcie_core_pkg::os_err_inj_interface_struct;
  import DWC_pcie_core_pkg::os_err_inj_status_struct;
  import DWC_pcie_core_pkg::cfg_os_einj_ctrl_1_t;
  import DWC_pcie_core_pkg::cfg_os_einj_ctrl_2_t;
  import DWC_pcie_core_pkg::cfg_os_einj_status_t;
  import pcie_pkg::E_P;
  import pcie_pkg::E_NP;
  import pcie_pkg::E_CPL;
  import pcie_pkg::fc_type_e;
  import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
  import DWC_pcie_core_pkg::ltssm_state_e;
 (
// ---- inputs ----------------
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    device_type,
    app_dbi_ro_wr_disable,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_cs,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    lbc_cdm_unroll,
    lbc_cdm_rcrb_wire,
    lbc_cdm_rcrb_mbar0_wire,
    lbc_cdm_rcrb_dbi,
    lbc_cdm_rcrb_mbar0_dbi,
    rcrb_base_addr,
    rcrb_base_addr_valid,

    lbc_xmt_cpl_ca,

    sys_int,
    sys_aux_pwr_det,
    sys_pre_det_state,
    sys_mrl_sensor_state,
    sys_atten_button_pressed,
    sys_pwr_fault_det,
    sys_mrl_sensor_chged,
    sys_pre_det_chged,
    sys_cmd_cpled_int,
    sys_eml_interlock_engaged,
    phy_cfg_status,
    cxpl_debug_info,
    smlh_autoneg_link_width,
    rplh_link_rxmode,
    smlh_autoneg_link_sp,
    smlh_link_training_in_prog,
    smlh_bw_mgt_status,
    smlh_link_auto_bw_status,
    smlh_clr_enter_compliance,
    smlh_tx_margin_rst,
    smlh_core_rst_n_release_pulse,
    smlh_dir_spd_chg_rising_edge,
    mac_phy_txdeemph,
    smlh_dir_linkw_chg_started,
    current_data_rate,
    tmp_int_mac_phy_rate,
    cfg_pwr_budget_data_reg,
    cfg_pwr_budget_func_num,
    rmlh_rcvd_err,

    xadm_xmt_pci_errors,
    radm_pm_to_ack,
    pm_xmt_turnoff,
    
    radm_hdrlog,


    xadm_fc_prot_err,

    radm_drs_msg,
    smlh_ltssm_state,
    radm_frs_msg,
    radm_frs_msg_reason,

    pmstate_d3hot_to_d0,



    rtlh_overfl_err,
    rtlh_fc_init_status,

    xal_rcvd_cpl_ca,
    xal_rcvd_cpl_ur,
    xal_xmt_cpl_ca,
    xal_perr,
    xal_serr,
    xal_set_trgt_abort_primary,
    xal_set_mstr_abort_primary,
    xal_pci_addr_perr,

    dl_prot_err,
    rdlh_bad_tlp_err,
    rdlh_bad_dllp_err,
    rdlh_link_up,
    xdlh_replay_num_rlover_err,
    xdlh_replay_timeout_err,
    smlh_link_up,

    radm_cpl_pending,
    radm_cpl_timeout,
    radm_timeout_func_num,

    
    radm_set_slot_pwr_limit,
    radm_slot_pwr_payload,

    radm_pm_pme,
    radm_msg_req_id,

    radm_correctable_err,
    radm_nonfatal_err,
    radm_fatal_err,

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


    pm_status,
    pm_pme_en,
    aux_pm_en,
    flt_cdm_addr,
    flt_cdm_pf,
    pm_radm_block_tlp,
    flt_cdm_addr_valid,
// allow application to return the error bits and hdr log
    app_hdr_valid,
    app_hdr_log,
    app_hdr_flitmode,
    app_hdr_log_size,
    app_err_bus,
    app_err_advisory,
    app_poisoned_tlp_type,
    app_err_func_num,
    rmlh_lane_err,
    smlh_ls2_eq_req,
    smlh_ls2_eq_success,
    smlh_ls2_eq_cmpl,
    smlh_ls2_eq_enter,
    smlh_ltssm_in_detectquiet,
    smlh_lec_pset_ltx,
    smlh_lec_pset_lrx,
    smlh_ls2_g4_eq_req,
    smlh_ls2_g4_eq_success,
    smlh_ls2_g4_eq_cmpl,
    smlh_ls2_g4_eq_enter,
    smlh_lec_g4_pset_ltx,
    smlh_lec_g4_pset_lrx,
    smlh_ls2_g5_eq_req,
    smlh_ls2_g5_eq_success,
    smlh_ls2_g5_eq_cmpl,
    smlh_ls2_g5_eq_enter,
    smlh_lec_g5_pset_ltx,
    smlh_lec_g5_pset_lrx,
    smlh_elbc_rcvd,
    smlh_tx_precoding_on,
    smlh_noeq_needed_rcvd,
    smlh_ls2_g6_eq_req,
    smlh_ls2_g6_eq_success,
    smlh_ls2_g6_eq_cmpl,
    smlh_ls2_g6_eq_enter,
    smlh_lec_g6_pset_ltx,
    smlh_lec_g6_pset_lrx,
    smlh_g6_tx_precoding_on,
    smlh_retimer_pre_detected,
    smlh_two_retimers_pre_detected,
    smlh_crosslink_resolution,
    rmlh_deskew_ctlskp_err,
    smlh_margin_status_valid,
    smlh_margin_status,
    smlh_margin_ready,
    app_margining_ready,
    app_margining_software_ready,
    smlh_mod_ts_rcvd,
    mod_ts_data_rcvd,
    mod_ts_data_sent,
    app_ltr_msg_req,
    msg_ltr_det,
    msg_ltr_latency,
    msgg2cdm_ltr_clr_msg_grant,
    xdlh_retry_req,
    rdlh_dlcntrl_state,

  // --- RAS D.E.S signals
   app_ras_des_tba_ctrl,
    cdm_ras_des_ec_ram_dataout,
    cdm_ras_des_tba_ram_dataout,
    rmlh_ebuf_rxoverflow,
    rmlh_ebuf_rxunderflow,
    rmlh_phy_rxcodeerror,
    rmlh_phy_rxdisperror,
    rmlh_skp_parity_err,
    rmlh_sync_header_err,
    rmlh_rxvalid_deasserted,
    rmlh_framing_err,
    rmlh_framing_err_l0,
    rmlh_deskew_alignment_err,
    rmlh_rxskipadded,
    rmlh_rxskipremoved,
    rmlh_deskew_fifo_ptr,
    rmlh_framing_err_ptr,
    smlh_eidle_inferred_in_l0,
    smlh_rx_rcvry_req,
    smlh_timeout_nfts,
    smlh_l0_to_recovery,
    smlh_l1_to_recovery,
    smlh_in_l0s,
    smlh_in_rl0s,
    smlh_ltssm_in_l0p,
    smlh_link_in_training,
    smlh_rcv_eios_when_l0s_unsprt,
    smlh_deskew_uncomplete_err,
    cxl_almp_rx_repl_error,
    cxl_vlsm_unexp_error,
    cxl_vlsm_lrsm_req_retrain,
    pm_asnak,
    l1sub_state,
    pm_in_l11,
    pm_in_l12,
    pm_in_l1_short,
    pm_in_l1_cpm,
    pm_in_l1_abort,
    smlh_in_l23,
    smlh_spd_change,
    smlh_lwd_change,
    rdlh_bad_tlp_err_pertlp,
    rdlh_lcrc_tlp_err_pertlp,
    rdlh_nulified_tlp_err_pertlp,
    rdlh_duplicate_tlp_err_pertlp,
    rdlh_bad_dllp_err_perdllp,
    rdlh_rcvd_nack_perdllp,
    rdlh_rcvd_ack_perdllp,
    xdlh_nak_sent,
    xdlh_ack_sent,
    xdlh_update_fc_sent,
    xadm_tx_nullify_evt,
    rtlh_req_link_retrain,
    rtlh_rcvd_ufc_perdllp,
    rtlh_rx_memwr_evt,
    rtlh_rx_defmemwr_evt,
    rtlh_rx_memrd_evt,
    rtlh_rx_cfgwr_evt,
    rtlh_rx_cfgrd_evt,
    rtlh_rx_iowr_evt,
    rtlh_rx_iord_evt,
    rtlh_rx_cplwod_evt,
    rtlh_rx_cplwd_evt,
    rtlh_rx_msg_evt,
    rtlh_rx_atmcop_evt,
    rtlh_rx_tlpwprefix_evt,
    rtlh_rx_tlp_dpsize,
    xtlh_tx_memwr_evt,
    xtlh_tx_defmemwr_evt,
    xtlh_tx_memrd_evt,
    xtlh_tx_cfgwr_evt,
    xtlh_tx_cfgrd_evt,
    xtlh_tx_iowr_evt,
    xtlh_tx_iord_evt,
    xtlh_tx_cplwod_evt,
    xtlh_tx_cplwd_evt,
    xtlh_tx_msg_evt,
    xtlh_tx_atmcop_evt,
    xtlh_tx_tlpwprefix_evt,
    xtlh_tx_tlp_dpsize,
    mac_phy_txelec_txburst,
    mac_phy_rxpolarity,
    phy_mac_rxelec_rxh8exit,
    phy_mac_rxvalid_rxburst,
    orig_pipe_rxdata,
    orig_pipe_rxdatak,
    orig_pipe_rxdatavalid,
    orig_pipe_rxstatus,
    orig_pipe_rxstartblock,
    orig_pipe_rxsyncheader,
    orig_pipe_blockaligncontrol,
    latched_rxdetected,
    pm_pme_resend_flag,
    smlh_ltssm_variable,
    ltssm_powerdown,
    latched_ts_nfts,
    pm_usp_link_state,
    pm_usp_prot_state,
    pm_dsp_link_state,
    pm_dsp_prot_state,
    pm_l0s_state,
    smlh_lane_reversed,
    init_eq_pending,
    mac_cdm_ras_des_fs,
    mac_cdm_ras_des_lf,
    mac_cdm_ras_des_coef_ltx,
    phy_cdm_ras_des_fomfeedback,
    eqpa_violate_rule_123,
    eq_convergence_sts,
    mac_cdm_ras_des_coef_rtx,
    mac_cdm_ras_des_pset_lrx,
    mac_cdm_ras_des_reject_rtx,
    init_eq_pending_g4,
    mac_cdm_ras_des_fs_g4,
    mac_cdm_ras_des_lf_g4,
    mac_cdm_ras_des_coef_ltx_g4,
    phy_cdm_ras_des_fomfeedback_g4,
    eqpa_violate_rule_123_g4,
    eq_convergence_sts_g4,
    mac_cdm_ras_des_coef_rtx_g4,
    mac_cdm_ras_des_reject_rtx_g4,
    init_eq_pending_g5,
    mac_cdm_ras_des_fs_g5,
    mac_cdm_ras_des_lf_g5,
    mac_cdm_ras_des_coef_ltx_g5,
    phy_cdm_ras_des_fomfeedback_g5,
    eqpa_violate_rule_123_g5,
    eq_convergence_sts_g5,
    mac_cdm_ras_des_coef_rtx_g5,
    mac_cdm_ras_des_reject_rtx_g5,
    init_eq_pending_g6,
    mac_cdm_ras_des_fs_g6,
    mac_cdm_ras_des_lf_g6,
    mac_cdm_ras_des_coef_ltx_g6,
    phy_cdm_ras_des_fomfeedback_g6,
    eqpa_violate_rule_123_g6,
    eqpa_violate_rule_4_g6,
    eq_convergence_sts_g6,
    mac_cdm_ras_des_coef_rtx_g6,
    mac_cdm_ras_des_reject_rtx_g6,
    rl0s_state,
    mac_cdm_ras_des_txdeemph,
    mac_phy_rate,
    mac_phy_powerdown,
    mac_phy_txdetectrx_loopback,
    mac_phy_rxeqeval,
    phy_mac_phystatus,
    phy_mac_dirfeedback,
    phy_mac_fomfeedback,
    smlh_rxos_type,
    smseq_mcs_sts,
    smseq_ts_debug_info,
    rdlh_vc0_initfc1_status,
    rdlh_vc0_initfc2_status,
    rdlh_xplh_curnt_rx_ack_seqnum,
    xdlh_xplh_curnt_seqnum,
    rtlh_fc_rcvd_ph,
    rtlh_fc_rcvd_pd,
    rtlh_fc_rcvd_nph,
    rtlh_fc_rcvd_npd,
    rtlh_fc_rcvd_cplh,
    rtlh_fc_rcvd_cpld,
    rtlh_fc_allctd_ph,
    rtlh_fc_allctd_pd,
    rtlh_fc_allctd_nph,
    rtlh_fc_allctd_npd,
    rtlh_fc_allctd_cplh,
    rtlh_fc_allctd_cpld,
    xadm_fc_cnsmd_ph,
    xadm_fc_cnsmd_pd,
    xadm_fc_cnsmd_nph,
    xadm_fc_cnsmd_npd,
    xadm_fc_cnsmd_cplh,
    xadm_fc_cnsmd_cpld,
    xadm_fc_limit_ph,
    xadm_fc_limit_pd,
    xadm_fc_limit_nph,
    xadm_fc_limit_npd,
    xadm_fc_limit_cplh,
    xadm_fc_limit_cpld,
    rdlh_einj0_lcrc_evt,
    radm_einj0_ecrc_evt,
    xmlh_einj0_oscrc_evt,
    xdlh_einj0_lcrc_evt,
    xdlh_einj0_fcrc_evt,
    xdlh_einj0_dllpcrc_evt,
    xadm_einj0_ecrc_evt,
    ras_des_einj1_exp_sequm_evt,    
    ras_des_einj1_ack_nak_sequm_evt,
    xdlh_einj2_nak_evt,
    xmlh_einj3_osmsk_evt,
    rtlh_einj4_fc_evt,
    xdlh_einj5_nultlp_evt,
    xdlh_einj5_dup_evt,
    xaim_einj6_tlp_evt,
    radm_mlf_tlp_err_ptr,

    smlh_in_l0,
    smlh_in_l1,

    ptm_auto_update_signal,        //Manual PTM Requester timing update signal from register
    ptm_manual_update_pulse,
    pm_linkst_in_l0,
    pm_linkst_in_l0s,
    ptm_external_master_strobe,
    ptm_external_master_time,
    radm_ptm_req,
    radm_ptm_res_msg,
    radm_ptm_res_d_msg,
    radm_ptm_master_time,
    radm_ptm_prop_delay,
    xdlh_ptm_sot,
    xdlh_ptm_multi_cycle,
    xdlh_ptm_request,
    xdlh_ptm_response,
    xdlh_rbuf_replaying,
    rdlh_ptm_sot,
    rdlh_ptm_multi_cycle,
    rdlh_ptm_request,
    rdlh_ptm_response,
    rdlh_duplicate_tlp,
    pm_sel_aux_clk,
    aux_clk_active,


    radm_snoop_upd,
    radm_snoop_bus_num,
    radm_snoop_dev_num,
    prs_res_failure,
    prs_uprgi,
    prs_stopped,
    rdlh_rcvd_dl_feature,
    rcvd_dl_feature_content,

    app_clk_pm_en,

    app_dev_num,              // DEV# provided by the application
    app_bus_num,              // Bus# provided by the application
    cxl_rcrb_enable,
    cxl_mbar0_enable,
    ltssm_cxl_enable,
    phy_ltssm_cxl_enable,
    cxl_port_rcvd_mod_ts_data_phase1,
    cxl_retimers_present_mismatched,
    flexbusenablebits_phase2_mismatch,
    correctable_protocol_id_frame_err,
    uncorrectable_protocol_id_frame_err,
    unexpected_protocol_id_dropped,
    viral_status,
    pl_reg_viral_status_set,
    cxl_mode_enable,
    cxl_dev_cache_invalid,
    cxl_dev_cache_wr_invld_cmpl,
    cxl_pm_init_cmpl,
    cxl_volatile_hdm_error,
    mbar0_ras_unc_cache_data_parity,
    mbar0_ras_unc_cache_addr_parity,
    mbar0_ras_unc_cache_be_parity,
    mbar0_ras_unc_cache_data_ecc,
    mbar0_ras_unc_mem_data_parity,
    mbar0_ras_unc_mem_addr_parity,
    mbar0_ras_unc_mem_be_parity,
    mbar0_ras_unc_mem_data_ecc,
    mbar0_ras_unc_reinit_threshold,
    mbar0_ras_unc_rsvd_encoding_violation,
    mbar0_ras_unc_poison_received,
    mbar0_ras_unc_receiver_overflow,
    mbar0_ras_unc_internal_error,
    mbar0_ras_unc_cxl_ide_tx_error,
    mbar0_ras_unc_cxl_ide_rx_error,

    mbar0_ras_corr_cache_data_ecc,
    mbar0_ras_corr_mem_data_ecc,
    mbar0_ras_corr_crc_threshold,
    mbar0_ras_corr_retry_threshold,
    mbar0_ras_corr_cache_poison_received,
    mbar0_ras_corr_mem_poison_received,
    mbar0_ras_corr_physical_layer_error,

    mbar0_ras_header_log_reg0,
    mbar0_ras_header_log_reg1,
    mbar0_ras_header_log_reg2,
    mbar0_ras_header_log_reg3,
    mbar0_ras_header_log_reg4,
    mbar0_ras_header_log_reg5,
    mbar0_ras_header_log_reg6,
    mbar0_ras_header_log_reg7,
    mbar0_ras_header_log_reg8,
    mbar0_ras_header_log_reg9,
    mbar0_ras_header_log_reg10,
    mbar0_ras_header_log_reg11,
    mbar0_ras_header_log_reg12,
    mbar0_ras_header_log_reg13,
    mbar0_ras_header_log_reg14,
    mbar0_ras_header_log_reg15,

    cxl_pl_reg_vlsm_state,
    cxl_pl_reg_cache_mem_vlsm_state,
    cxl_pl_reg_io_vlsm_state,
    cxl_pl_reg_mc_almp_unexp_error,
    cxl_pl_reg_io_almp_unexp_error,
    cxl_pl_reg_lrsm_state,
    cxl_pl_reg_lrsm_fatal_error,
    cxl_pl_reg_fatal_error,
    cxl_pl_reg_cm_ll_cache_poison_injection_busy,
    cxl_pl_reg_cm_ll_mem_poison_injection_busy,
    cxl_pl_reg_cm_ll_io_poison_injection_busy,
    cxl_pl_reg_cm_ll_cache_mem_crc_injection_busy,
    cxl_pl_reg_io_ll_io_poison_injection_busy,
    cxl_pl_reg_io_ll_flow_ctrl_error_injection_busy,
    cxl_pl_reg_fb_phy_protid_injection_busy,


    rplh_flit_logging_interface,   
    rmlh_flit_logging_interface,   
    smlh_flit_logging_interface,   

    xplh_cdm_flit_latency_tracking,
    pm_cdm_state_trans_tracking,

    plh_cdm_flit_err_inj_status,
    cdm_plh_flit_err_inj_interface,
    cfg_os_einj_ctrl_1,
    cfg_os_einj_ctrl_2,
    xmlh_tx_os_einj_status,

    pm_pclkack_timeout,
    pm_cfg_utility,

   msggen_cdm_send_f_err,
   msggen_cdm_send_nf_err,

   rmlh_prbs_done,
   rmlh_prbs_fail,
   rmlh_prbs_started,
   rmlh_prbs_err_cntr,
   rmlh_prbs_unexp_fail,
// ---- outputs ---------------
    cfg_flit_log_trg_evnt_msi,   
    cfg_flit_perf_interr_vec,
    cdm_xplh_flit_response_type,
    cdm_xplh_flit_type_measured,
    cdm_xplh_flit_track_mode,
    cfg_flit_latency_msi,
    cdm_pm_state_trans_tracker,
    cfg_sts_1_ltssm_latency_msi,
    cfg_utility,
    cfg_upd_pme_cap,
    cfg_io_match,
    cfg_config_above_match,
    cfg_rom_match,
    cfg_bar_match,
    cfg_bar_is_io,
    cfg_mem_match,
    cfg_prefmem_match,
    rcrb_address_reg,
    rcrb_mbar0_base_addr,
    cfg_rcrb_match,
    cfg_rcrb_mbar0_match,
    cfg_rcrb_mbar0_match_int,
    cfg_cxl_2_0_mbar0_match,
    cxl_2_0_mbar0_access_match,
    cfg_cxl_alt_mem_match,
    cfg_cxl_alt_prefmem_match,
    cfg_l1sub_control,
    cfg_l1sub_en,
    cfg_pl_l1sub_control,
    cfg_pl_l1_exit_mode,
    cfg_pl_l1_nowait_p1,
    cfg_pl_l1_clk_sel,
    cfg_p2nobeacon_enable,
    cfg_pipe_optional_pclkchange_hs,
    cfg_phy_perst_on_warm_reset,
    cfg_phy_rst_timer,
    cfg_pma_phy_rst_delay_timer,
    cfg_dsp_pcipm_l1_enter_delay,
    cfg_pl_aux_clk_freq,
    cfg_filter_rule_mask,
    cfg_fc_wdog_disable,
    cdm_lbc_data,
    cdm_lbc_ack,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    cfg_2ndbus_num,
    cfg_subbus_num,
    cfg_aslk_pmctrl,
    cfg_clk_pm_en,
    cfg_relax_ord_en,
    cfg_ext_tag_en,
    cfg_phantom_fun_en,
    cfg_aux_pm_en,
    cfg_no_snoop_en,
    cfg_max_rd_req_size,
    cfg_bridge_crs_en,
    cfg_rcb,
    cfg_comm_clk_config,
    cfg_hw_autowidth_dis,
    cfg_max_payload_size,
    cfg_max_payload_size_out_rx,
    cfg_highest_max_payload,
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
    cfg_link_retrain,
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
    cfg_imp_num_lanes,
    cfg_flow_control_disable,
    cfg_acknack_disable,
    cfg_link_capable,
    cfg_eidle_timer,
    cfg_skip_interval,
    cfg_link_rate,
    cfg_retimers_pre_detected,
    cfg_l0s_supported,
    cfg_fast_link_mode,
    cfg_fast_link_scaling_factor,
    cfg_dll_lnk_en,
    cfg_soft_rst_n,
    cfg_2nd_reset,
    cfg_ecrc_gen_en,
    cfg_ecrc_chk_en,
    cfg_bar0_start,
    cfg_bar0_limit,
    cfg_bar0_mask,
    cfg_bar1_start,
    cfg_bar1_limit,
    cfg_bar1_mask,
    cfg_bar2_start,
    cfg_bar2_limit,
    cfg_bar2_mask,
    cfg_bar3_start,
    cfg_bar3_limit,
    cfg_bar3_mask,
    cfg_bar4_start,
    cfg_bar4_limit,
    cfg_bar4_mask,
    cfg_bar5_start,
    cfg_bar5_limit,
    cfg_bar5_mask,
    cfg_rom_mask,
    cfg_mem_base,
    cfg_mem_limit,
    cfg_pref_mem_base,
    cfg_pref_mem_limit,
    cfg_exp_rom_start,
    cfg_exp_rom_limit,
    cfg_io_limit_upper16,
    cfg_io_base_upper16,
    cfg_io_base,
    cfg_io_limit,
    cfg_hdr_type,
    cfg_ext_synch,
    cfg_io_space_en,
    cfg_mem_space_en,
    cfg_phy_control,
    upstream_port,
    switch_device,
    end_device,
    rc_device,
    bridge_device,
    cfg_upd_pmcsr,
    cfg_upd_req_id,
    cfg_upd_aux_pm_en,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_bus_master_en,
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
// ATU outbound Region controls
    atu_reg_out_type,
    atu_reg_out_tc,
    atu_reg_out_td,
    atu_reg_out_attr,
    atu_reg_out_at,
    atu_reg_out_func_num,
    atu_reg_out_func_bypass,
    atu_reg_out_snp,
    atu_reg_out_dma_bypass,
    atu_reg_out_inhibit_payload,
    atu_reg_out_hdr_substitute_en,
    atu_reg_out_tag_substitute_en,
    atu_reg_out_tag,
    atu_reg_out_msg_code,
    atu_reg_out_th,
    atu_reg_out_ph,
    atu_reg_out_st,
// Mode Settings
    atu_reg_out_shift,
    atu_reg_out_invert,
// Region Enable
    atu_reg_out_en,
// Base, Limit and Target Registers
    atu_reg_out_base,
    atu_reg_out_upr_base,
    atu_reg_out_limit,
    atu_reg_out_uppr_limit,
    atu_reg_out_lwr_trgt,
    atu_reg_out_upr_trgt,
    atu_reg_out_lwr_trgt_lwr,
    atu_reg_out_incr_rgn_size,
    atu_reg_out_hdr_flds_bypass,

// ATU inbound Region controls
    atu_reg_in_type,
    atu_reg_in_tc,
    atu_reg_in_td,
    atu_reg_in_attr,
    atu_reg_in_at,
    atu_reg_in_func_num,
    atu_reg_in_msg_code,
    atu_reg_in_bar_num,
    atu_reg_in_th,
    atu_reg_in_ph,
    atu_reg_in_st,
// Inbound field match enables
    atu_reg_in_tc_match_en,
    atu_reg_in_td_match_en,
    atu_reg_in_attr_match_en,
    atu_reg_in_at_match_en,
    atu_reg_in_func_match_en,
    atu_reg_in_msgcode_match_en,
    atu_reg_in_th_match_en,
    atu_reg_in_ph_match_en,
    atu_reg_in_st_match_en,
    atu_reg_in_single_addr_loc_en,
    atu_reg_in_msg_type_match_mode,
// Response and mode settings
    atu_reg_in_rsp_code,
    atu_reg_in_fuzzy,
    atu_reg_in_shift,
    atu_reg_in_invert,
    atu_reg_in_bar_match,
// Region Enable
    atu_reg_in_en,
// Base, Limit and Target Registers
    atu_reg_in_base,
    atu_reg_in_upr_base,
    atu_reg_in_limit,
    atu_reg_in_cbuf_incr,
    atu_reg_in_cbuf_restart,
    atu_reg_in_uppr_limit,
    atu_reg_in_lwr_trgt,
    atu_reg_in_upr_trgt,
    atu_reg_in_incr_rgn_size,
    cfg_reg_serren,
    cfg_cor_err_rpt_en,
    cfg_nf_err_rpt_en,
    cfg_f_err_rpt_en,
    cfg_pme_cap,
    cfg_pm_no_soft_rst ,
    cfg_l0s_entr_latency_timer,
    cfg_l1_entr_latency_timer,
    cfg_l1_entr_wo_rl0s,
    cfg_aspm_l1_timer_enable,
    cfg_isa_enable,
    cfg_vga_enable,
    cfg_vga16_decode,
    cfg_send_cor_err,
    cfg_send_nf_err,
    cfg_send_f_err,
    cfg_func_spec_err,
    cfg_sys_err_rc,
    cfg_aer_rc_err_int,
    cfg_aer_rc_err_msi,
    cfg_aer_int_msg_num,
    cfg_pme_int,
    cfg_crs_sw_vis_en,
    cfg_pme_msi,
    cfg_pcie_cap_int_msg_num,
    cfg_ari_fwd_en,
    cfg_cpl_timeout_range,
    cfg_cpl_timeout_disable,
    cfg_lane_en,
    cfg_gen1_ei_inference_mode,
    cfg_select_deemph_mux_bus,
    cfg_lut_ctrl,
    cfg_rxstandby_control,
    cfg_link_auto_bw_int,
    cfg_link_auto_bw_msi,
    cfg_bw_mgt_int,
    cfg_bw_mgt_msi,
    cfg_gen2_n_fts,
    cfg_directed_speed_change,
    cfg_phy_txswing,
    cfg_tx_compliance_rcv,
    cfg_pcie_max_link_speed,
    cfg_target_link_speed,
    cfg_enter_compliance,
    cfg_hw_auto_sp_dis,
    cfg_sel_de_emphasis,
    cfg_transmit_margin,
    cfg_enter_mod_compliance,
    cfg_compliance_sos,
    cfg_compliance_de_emphasis,
    cfg_pwr_ind,
    cfg_atten_ind,
    cfg_pwr_ctrler_ctrl,
    cfg_eml_control,
    cfg_slot_pwr_limit_wr,
    cfg_int_disable,
    cfg_multi_msi_en,
    cfg_msi_ext_data_en,
    cfg_msi_en,
    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_msix_en,
    cfg_msix_func_mask,
    ras_dp_err_log,
    ras_dp_err_inj,
    ras_dp_err_inj_wake_up,
    ras_error_tracer_pending,
    ras_dp_unc_err,
    ras_dp_cor_err,
    ras_ram_unc_err,
    ras_ram_cor_err,
    cfg_pwr_budget_data_sel_reg,
    cfg_pwr_budget_sel,
    set_slot_pwr_limit_val,
    set_slot_pwr_limit_scale,
    cfg_vc_enable,
    cfg_vc_struc_vc_id_map,
    cfg_vc_id_vc_struc_map,
    cfg_tc_enable,
    cfg_tc_vc_map,
    cfg_tc_struc_vc_map,
    cfg_lpvc,
    cfg_vc_arb_sel,
    cfg_lpvc_wrr_weight,
    cfg_max_func_num,
    cfg_upd_aspm_ctrl,
    cfg_upd_aslk_pmctrl,
    cfg_trgt_cpl_lut_delete_entry,
    cfg_clock_gating_ctrl,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    cfg_radm_q_mode,
    cfg_radm_order_rule,
    cfg_order_rule_ctrl,
    cfg_radm_strict_vc_prior,
    cfg_hq_depths,
    cfg_dq_depths,
    dl_feature_en,
    cfg_remote_feature_ack,
    cfg_local_feature_support,
    cfg_dlink_feature_valid,     
    hdr_scale_p,
    data_scale_p,
    hdr_scale_np,
    data_scale_np,
    hdr_scale_cpl,
    data_scale_cpl,
    fc_scaled_en,
    target_mem_map,
    target_rom_map,
    cfg_atomic_req_en,
    cfg_atomic_egress_block,
    cfg_dmwr_req_en,


    cfg_tx_arb_control,
    smlh_l0p_capable,
    cfg_l0p_receiver_support,
    cfg_l0p_enable,
    cfg_l0p_autowidth_dis,
    cfg_l0p_priority,
    cfg_l0p_linkmode,
    cfg_l0p_linkmode_req,
    cfg_l0p_max_link_width,
    cfg_l0p_neg_link_width,
    cfg_pcie_l0p_disable,
    cfg_pcie_l0p_request,
    cfg_pcie_l0p_priority,
    cfg_pcie_l0p_linkmode,
    cfg_cxl_l0p_disable,
    cfg_cxl_l0p_request,
    cfg_cxl_l0p_priority,
    cfg_cxl_l0p_linkmode,
    cfg_flit_err_inj_latency,
    cfg_obff_en,
    cfg_ltr_m_en,
    cfg_ltr_max_latency,
    app_ltr_latency,
    cdm2msgg_ltr_clr_msg_req,
    cfg_disable_ltr_clr_msg,
    inta_wire,
    intb_wire,
    intc_wire,
    intd_wire,
    cfg_pl_multilane_control
    ,
    cfg_link_eq_req_int,
    cfg_pl_gen3_control,
    cfg_pl_gen3_eq_control,
    cfg_fdbk_dirchange_control,
    cfg_pl_gen3_zrxdc_noncompl,
    cfg_no_seed_value_change,
    cfg_perform_eq,
    cfg_lec_pset_ltx,
    cfg_lec_pset_lrx,
    cfg_lec_pset_rtx,
    cfg_lec_pset_rrx,
    cfg_ls2_eq_req
    ,
    cfg_pl_gen4_control,
    cfg_pl_gen4_eq_control,
    cfg_gen4_fdbk_dirchange_control,
    cfg_lec_g4_pset_ltx,
    cfg_lec_g4_pset_lrx,
    cfg_lec_g4_pset_rtx,
    cfg_lec_g4_pset_rrx
    ,
    cfg_pl_gen5_control,
    cfg_pl_gen5_eq_control,
    cfg_gen5_fdbk_dirchange_control,
    cfg_bypass_eq_enable,
    cfg_no_eq_needed_enable,
    cfg_tx_precode_req,
    cfg_lec_g5_pset_ltx,
    cfg_lec_g5_pset_lrx,
    cfg_lec_g5_pset_rtx,
    cfg_lec_g5_pset_rrx
    ,
    cfg_pl_gen6_control,
    cfg_pl_gen6_eq_control,
    cfg_g6_tx_precode_req
    ,
    cfg_gen6_fdbk_dirchange_control
    ,
    cfg_lec_g6_pset_ltx,
    cfg_lec_g6_pset_rtx
    ,
    cfg_margin_control
    ,cfg_alt_protocol_enable
    ,
    cfg_tph_req_en,
    cfg_pf_tph_st_mode

   ,
   crgb_cdm_cs,
   crgb_cdm_ack,
   crgb_cdm_addr,
   crgb_cdm_wdata,
   crgb_cdm_rdata,
   crgb_cdm_wr,
   crgb_cdm_source
   ,
   cfg_gen3_eq_fs_lf,
   cfg_gen3_eq_coef
   ,
   cfg_gen4_eq_fs_lf,
   cfg_gen4_eq_coef
   ,
   cfg_gen5_eq_fs_lf,
   cfg_gen5_eq_coef
   ,
   cfg_gen6_eq_fs_lf,
   cfg_gen6_eq_coef
    ,
    cfg_int_pin                             // Interrupt Pin mapping
    ,
    cfg_end2end_tlp_pfx_blck,
    cfg_max_end2end_tlp_prfxs
    ,
    cfg_pf_pasid_control


    ,default_target,
    cfg_cfg_tlp_bypass_en,
    cfg_config_limit,
    cfg_target_above_config_limit,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    ur_ca_mask_4_trgt1
    ,
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
    cfg_margin_ind_error_sampler
    ,
    cfg_rx_message_bus_write_buffer_depth
    ,
    cfg_pipe_garbage_data_mode
    ,
    cfg_pam4_restricted_levels_requirement
    ,
    frsq_msi,
    frsq_int_msg_num

    ,
    cfg_drs_msi
    ,
    cfg_up_drs_to_frs


    ,
    cfg_ido_req_en,
    cfg_ido_cpl_en
    // --- RAS D.E.S signals
    ,
    cdm_ras_des_ec_info_common,
    cdm_ras_des_ec_info_l0,
    cdm_ras_des_ec_info_l1,
    cdm_ras_des_ec_info_l2,
    cdm_ras_des_ec_info_l3,
    cdm_ras_des_ec_info_l4,
    cdm_ras_des_ec_info_l5,
    cdm_ras_des_ec_info_l6,
    cdm_ras_des_ec_info_l7,
    app_ras_des_sd_hold_ltssm,
    cdm_ras_des_sd_info_common,
    cdm_ras_des_sd_info_l0,
    cdm_ras_des_sd_info_l1,
    cdm_ras_des_sd_info_l2,
    cdm_ras_des_sd_info_l3,
    cdm_ras_des_sd_info_l4,
    cdm_ras_des_sd_info_l5,
    cdm_ras_des_sd_info_l6,
    cdm_ras_des_sd_info_l7,
    cdm_ras_des_sd_info_v0,
    cdm_ras_des_tba_info_common,
    cdm_ras_des_ec_ram_ena,
    cdm_ras_des_ec_ram_wea,
    cdm_ras_des_ec_ram_addra,
    cdm_ras_des_ec_ram_datain,
    cdm_ras_des_ec_ram_enb,
    cdm_ras_des_ec_ram_addrb,
    cdm_ras_des_tba_ram_ena,
    cdm_ras_des_tba_ram_wea,
    cdm_ras_des_tba_ram_addra,
    cdm_ras_des_tba_ram_datain,
    cdm_ras_des_tba_ram_enb,
    cdm_ras_des_tba_ram_addrb,
    cdm_ras_des_pm_entry_interval,
    cdm_ras_des_eidle_cnt_sel,
    cdm_ras_des_ltssm_stop,
    cdm_ras_des_recovery_req,
    cdm_ras_des_ferr_rec_dis,
    cdm_ras_des_direct_rcvry_idle_to_cfg,
    cdm_ras_des_direct_poll_cmp_to_det,
    cdm_ras_des_direct_lpbk_slave_to_exit,
    cdm_ras_des_force_rxdetected_en,
    cdm_ras_des_force_rxdetected,
    cdm_ras_des_force_linkdown_noack
    ,
    cdm_ras_des_ext_eq_to_factor,
    cdm_ras_des_eq_fom_target_en,
    cdm_ras_des_eq_force_coef_rtx_en,
    cdm_ras_des_eq_force_pset_lrx_en,
    cdm_ras_des_eq_force_coef_ltx_en,
    cdm_ras_des_eq_force_coef_ltx,
    cdm_ras_des_eq_force_pset_lrx,
    cdm_ras_des_eq_force_coef_rtx,
    cdm_ras_des_eq_force_pset_ltx_en,
    cdm_ras_des_eq_force_usp_pset_ltx
    ,
    cdm_ras_des_eq_force_coef_rtx_en_g4,
    cdm_ras_des_eq_force_coef_ltx_en_g4,
    cdm_ras_des_eq_force_coef_ltx_g4,
    cdm_ras_des_eq_force_coef_rtx_g4,
    cdm_ras_des_eq_force_pset_ltx_en_g4,
    cdm_ras_des_eq_force_usp_pset_ltx_g4
    ,
    cdm_ras_des_eq_force_coef_rtx_en_g5,
    cdm_ras_des_eq_force_coef_ltx_en_g5,
    cdm_ras_des_eq_force_coef_ltx_g5,
    cdm_ras_des_eq_force_coef_rtx_g5,
    cdm_ras_des_eq_force_pset_ltx_en_g5,
    cdm_ras_des_eq_force_usp_pset_ltx_g5
    ,
    cdm_ras_des_eq_force_coef_rtx_en_g6,
    cdm_ras_des_eq_force_coef_ltx_en_g6,
    cdm_ras_des_eq_force_coef_ltx_g6,
    cdm_ras_des_eq_force_coef_rtx_g6,
    cdm_ras_des_eq_force_pset_ltx_en_g6,
    cdm_ras_des_eq_force_usp_pset_ltx_g6
    ,
    cdm_ras_des_eq_fom_target,
    cdm_ras_des_eq_eval_interval
    ,
    cdm_ras_des_einj0_enable,
    cdm_ras_des_einj0_count,
    cdm_ras_des_einj0_crc_type,
    cdm_ras_des_einj0_ecrc_vc_sel,
    cdm_ras_des_einj0_ecrc_fc_sel,
    cdm_ras_des_einj0_ecrc_intf_sel,
    cdm_ras_des_einj1_enable,
    cdm_ras_des_einj1_seq_type,
    cdm_ras_des_einj1_bad_seq,
    cdm_ras_des_einj1_count,
    cdm_ras_des_einj2_enable,
    cdm_ras_des_einj2_dllp_type,
    cdm_ras_des_einj3_enable,
    cdm_ras_des_einj3_count,
    cdm_ras_des_einj3_smb_type,
    cdm_ras_des_einj4_enable,
    cdm_ras_des_einj4_updfc_type,
    cdm_ras_des_einj4_vcnum,
    cdm_ras_des_einj4_badfc_value,
    cdm_ras_des_einj5_enable,
    cdm_ras_des_einj5_count,
    cdm_ras_des_einj5_tlp_type,
    cdm_ras_des_einj6_enable,
    cdm_ras_des_einj6_cmp_point_h0,
    cdm_ras_des_einj6_cmp_point_h1,
    cdm_ras_des_einj6_cmp_point_h2,
    cdm_ras_des_einj6_cmp_point_h3,
    cdm_ras_des_einj6_cmp_value_h0,
    cdm_ras_des_einj6_cmp_value_h1,
    cdm_ras_des_einj6_cmp_value_h2,
    cdm_ras_des_einj6_cmp_value_h3,
    cdm_ras_des_einj6_chg_point_h0,
    cdm_ras_des_einj6_chg_point_h1,
    cdm_ras_des_einj6_chg_point_h2,
    cdm_ras_des_einj6_chg_point_h3,
    cdm_ras_des_einj6_chg_value_h0,
    cdm_ras_des_einj6_chg_value_h1,
    cdm_ras_des_einj6_chg_value_h2,
    cdm_ras_des_einj6_chg_value_h3,
    cdm_ras_des_einj6_count,
    cdm_ras_des_einj6_invt_cont,
    cdm_ras_des_einj6_pkt_type
    ,
    rasdp_linkdown,
    cfg_rasdp_linkdown_en,
    cfg_rasdp_error_mode_en,
    cfg_rasdp_error_mode
    ,cfg_optional_ohc
    ,
    ptm_request_msg,
    ptm_res_msg,
    ptm_res_d_msg,
    ptm_master_time,
    ptm_prop_delay,
    cfg_ptm_enable,
    ptm_context_valid,            //top level output
    ptm_responder_rdy_to_validate,            //top level output
    ptm_local_clock
    ,
    ptm_clock_updated,
    ptm_clock_correction,
    ptm_trigger_allowed,         //
    ptm_updating,                //PTM Update is in progress
    ptm_req_response_timeout,
    ptm_req_dup_rx,
    ptm_req_replay_tx

    ,
    cfg_ats_stu,
    cfg_ats_cache_en

    ,
    cfg_acs_validation_cap,
    cfg_acs_at_blocking_cap,
    cfg_acs_up_forward_cap,
    cfg_acs_validation_en,
    cfg_acs_at_blocking_en,
    cfg_acs_p2p_req_redirect_en,
    cfg_acs_p2p_compl_redirect_en,
    cfg_acs_up_forward_en,
    cfg_acs_p2p_egress_ctrl_en,
    cfg_acs_p2p_direct_transl_en
    ,
    cfg_acs_egress_ctrl_vec

    ,
    cfg_10b_tag_req_en

    ,
    surprise_down_err

    ,
    cfg_prs_stopped,
    cfg_prs_uprgi,
    cfg_prs_response_failure,
    cfg_prs_enable,
    cfg_prs_reset,
    cfg_prs_outstanding_allocation

    ,
    cdm_hp_pme,
    cdm_hp_int,
    cdm_hp_msi

    ,
    cfg_auto_slot_pwr_lmt_dis,
    cfg_hp_slot_ctrl_access,
    cfg_dll_state_chged_en,
    cfg_cmd_cpled_int_en,
    cfg_pre_det_chged_en,
    cfg_hp_int_en,
    cfg_mrl_sensor_chged_en,
    cfg_pwr_fault_det_en,
    cfg_atten_button_pressed_en

    ,
    cfg_br_ctrl_serren
    ,
    cfg_nond0_vdm_block,
    cfg_client0_block_new_tlp,
    cfg_client1_block_new_tlp,
    cfg_client2_block_new_tlp
    ,
    cdm_core_in_dpc,
    cdm_dpc_triggered,
    cdm_aer_dpc_triggered,
    dpc_fatal_err_gate,
    dpc_nonfatal_err_gate,
    cfg_dpc_int_msg_num,
    cfg_dpc_rp_ext_dpc,
    cfg_dpc_poison_tlp_egr_blk_support,
    cfg_dpc_sw_trig_support,
    cfg_dpc_rp_pio_log_size,
    cfg_dpc_dl_active_err_cor_support,
    cfg_dpc_trig_en,
    cfg_dpc_cpl_cntrl,
    cfg_dpc_int_en,
    dpc_int,
    dpc_msi,
    cfg_dpc_err_cor_en,
    cfg_dpc_poison_tlp_egr_block_en,
    cfg_dpc_sw_trigger,
    cfg_dpc_dl_active_err_cor_en
    ,exp_rom_validation_status_strobe
    ,exp_rom_validation_status
    ,exp_rom_validation_details_strobe
    ,exp_rom_validation_details

      ,app_segment_id
      ,radm_np_segment_id
    ,cfg_segment_id

    ,flit_mode_enable
    ,cfg_tx_throttling

    ,
    pm_powerdown_status,
    cfg_force_powerdown,
    cfg_pcie_slot_clk_config,
    cfg_uncor_internal_err_sts,
    cfg_rcvr_overflow_err_sts,
    cfg_fc_protocol_err_sts,
    cfg_mlf_tlp_err_sts,
    cfg_surprise_down_er_sts,
    cfg_dl_protocol_err_sts,
    cfg_ecrc_err_sts,
    cfg_corrected_internal_err_sts,
    cfg_replay_number_rollover_err_sts,
    cfg_replay_timer_timeout_err_sts,
    cfg_bad_dllp_err_sts,
    cfg_bad_tlp_err_sts,
    cfg_rcvr_err_sts,
    cfg_advisory_nf_sts,
    cfg_hdr_log_overflow_sts      




   ,cfg_cxl_port_cache_capable,
   cfg_cxl_port_mem_capable,
   cfg_cxl_port_vid,
   cfg_cxl_port_68B_flit_vh_capable,
   cfg_cxl_port_mld_capable,
   cfg_cxl_port_68B_flit_vh_enable,
   cfg_cxl_port_mld_enable,
   cfg_cxl_port_lopt_flit_capable,
   cfg_cxl_port_pbr_flit_capable,
   cfg_cxl_port_nop_hint_capable,
   cfg_cxl_port_disable_cxl1p1_training,
   cfg_cxl_port_cache_enable,
   cfg_cxl_port_io_enable,
   cfg_cxl_port_mem_enable,
   cfg_cxl_port_sync_hdr_bypass_enable,
   cfg_cxl_port_drift_buffer_enable,
   cfg_cxl_port_retimer1_present,
   cfg_cxl_port_retimer2_present,
   cfg_cxl_port_retimers_pre_mismatched,
   cfg_cxl_port_lopt_flit_enable,
   cfg_cxl_port_pbr_flit_enable,
   cfg_cxl_port_nop_hint_enable,

   cfg_cxl_pl_reg_viral_status,
   cfg_cxl_viral_enable,
   cfg_cxl_viral_status,

   cfg_cxl_dev_cache_enable,
   cfg_cxl_dev_io_enable,
   cfg_cxl_dev_mem_enable,
   cfg_cxl_dev_cache_sf_coverage,
   cfg_cxl_dev_cache_sf_granularity,
   cfg_cxl_dev_cache_clean_eviction,
   cfg_cxl_dev_viral_enable,
   cfg_cxl_dev_cxl_rst_mem_clr_enable,
   cfg_cxl_dev_post_cold_rst_volatile_hdm_default,
   cfg_cxl_dev_post_warm_rst_volatile_hdm_default,
   cfg_cxl_dev_post_hot_rst_volatile_hdm_default,
   cfg_cxl_dev_post_hot_rst_volatile_hdm_desired,

   cfg_cxl_dev_viral_status,
   cfg_cxl_dev_disable_caching,
   cfg_cxl_dev_initiate_cache_wr_invld,
   cfg_cxl_dev_initiate_cxl_rst,

   cfg_cxl_dev_range1_mem_size_high,
   cfg_cxl_dev_range1_mem_info_valid,
   cfg_cxl_dev_range1_mem_active,
   cfg_cxl_dev_range1_desired_interleave,
   cfg_cxl_dev_range1_mem_active_timeout,
   cfg_cxl_dev_range1_mem_size_low,
   cfg_cxl_dev_range1_mem_base_high,
   cfg_cxl_dev_range1_mem_base_low,

   cfg_cxl_dev_range2_mem_size_high,
   cfg_cxl_dev_range2_mem_info_valid,
   cfg_cxl_dev_range2_mem_active,
   cfg_cxl_dev_range2_desired_interleave,
   cfg_cxl_dev_range2_mem_active_timeout,
   cfg_cxl_dev_range2_mem_size_low,
   cfg_cxl_dev_range2_mem_base_high,
   cfg_cxl_dev_range2_mem_base_low,

   mbar0_ras_uncorr_error_mask,
   mbar0_ras_uncorr_error_severity,
   mbar0_ras_corr_error_mask,
   mbar0_ras_poison_enabled,

   mbar0_security_device_trust_level,

   mbar0_arb_mux_cxl_io,
   mbar0_arb_mux_cxl_cache_mem,
   mbar0_arb_mux_pmtimeout_en,
   mbar0_arb_mux_pmtimeout_val,
   mbar0_arb_mux_pmtimeout_err,
   mbar0_arb_mux_l0ptimeout_err,

   mbar0_cap_header_reg,
   mbar0_ras_cap_header_reg,
   mbar0_security_cap_header_reg,
   mbar0_link_cap_header_reg,
   mbar0_ras_corr_reg,
   mbar0_ras_uncorr_reg,
   cxl_pl_reg_vlsm_pm_enable,
   cxl_pl_reg_apn_bypass_enable,
   cxl_pl_reg_apn_sw_mode,
   cxl_pl_reg_vlsm_to_active,
   cxl_pl_reg_max_num_retry,
   cxl_pl_reg_max_num_reinit,
   cxl_pl_reg_lrsm_timeout_threshold,
   cxl_pl_reg_crc_threshold,
   cxl_fatal_error_reg,

   cxl_pl_reg_cm_ll_cache_poison_injection_start,
   cxl_pl_reg_cm_ll_mem_poison_injection_start,
   cxl_pl_reg_cm_ll_io_poison_injection_start,
   cxl_pl_reg_cm_ll_cache_mem_crc_injection,
   cxl_pl_reg_cm_ll_cache_mem_crc_injection_count,

   cxl_pl_reg_io_ll_io_poison_injection_start,
   cxl_pl_reg_io_ll_flow_ctrl_error_injection,

   cxl_pl_reg_fb_phy_cor_protid_error_injection,
   cxl_pl_reg_fb_phy_uncor_protid_error_injection,
   cxl_pl_reg_fb_phy_unexp_protid_error_injection

// Outputs from CXL 2.0 Extension DVSEC
  ,cfg_cxl_2_0_ext_viral_status
  ,cfg_cxl_2_0_ext_unmask_sbr
  ,cfg_cxl_2_0_ext_unmask_ld
  ,cfg_cxl_2_0_ext_alt_mse
  ,cfg_cxl_2_0_ext_alt_bme
  ,cfg_cxl_2_0_ext_viral_en
  ,cfg_cxl_2_0_ext_alt_bus_base
  ,cfg_cxl_2_0_ext_alt_bus_limit
  ,cfg_cxl_2_0_ext_alt_mem_base
  ,cfg_cxl_2_0_ext_alt_mem_limit
  ,cfg_cxl_2_0_ext_alt_pref_mem_base
  ,cfg_cxl_2_0_ext_alt_pref_mem_limit
  ,cfg_cxl_2_0_ext_alt_pref_mem_base_high
  ,cfg_cxl_2_0_ext_alt_pref_mem_limit_high
  ,cfg_cxl_2_0_ext_rcrb_en
  ,cfg_cxl_2_0_ext_rcrb_base_addr_low
  ,cfg_cxl_2_0_ext_rcrb_base_addr_high
// Outputs from CXL Register Locator DVSEC
  ,cxl_2_0_comp_reg_offset                       // CXL 2.0 Comp Specific Register Offset within Func 0, BAR0
  ,cfg_cxl_reg_locator_reg1_bir
  ,cfg_cxl_reg_locator_reg1_blk_identifier
  ,cfg_cxl_reg_locator_reg1_blk_offset_low
  ,cfg_cxl_reg_locator_reg1_blk_offset_high
  ,cfg_cxl_reg_locator_reg2_bir
  ,cfg_cxl_reg_locator_reg2_blk_identifier
  ,cfg_cxl_reg_locator_reg2_blk_offset_low
  ,cfg_cxl_reg_locator_reg2_blk_offset_high
  ,cfg_cxl_reg_locator_reg3_bir
  ,cfg_cxl_reg_locator_reg3_blk_identifier
  ,cfg_cxl_reg_locator_reg3_blk_offset_low
  ,cfg_cxl_reg_locator_reg3_blk_offset_high
// Outputs from CXL Port GPF DVSEC
  ,cfg_cxl_gpf_port_p1_timeout_base
  ,cfg_cxl_gpf_port_p1_timeout_scale
  ,cfg_cxl_gpf_port_p2_timeout_base
  ,cfg_cxl_gpf_port_p2_timeout_scale
    ,cfg_neg_link_width
    ,cfg_dbi_func_bank_select
    ,dbi_ro_wr_en
    ,
    cfg_pcie_cap_flit_mode_sup,    
    cfg_flit_mode_dis,  
    cfg_flit_sris_clocking,  
    cfg_pcie_cap_flit_mode_stat
    ,cfg_prbs_en
    ,clear_prbs_done
    ,cfg_prbs_lane_sel
);

import cdm_pkg::*;
import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;

parameter PWDN_WIDTH    = `CX_PHY_PDOWN_WD;
parameter INST          = 0;                        // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;
parameter NF            = `CX_NFUNC;                // Number of functions
parameter MSI_NF        = `CX_MSI_NFUNC;            // Number of functions for MSI
parameter VPD_NF        = `CX_VPD_NFUNC;            // Number of functions for VPD Cap
parameter PB_NF         = `CX_PB_NFUNC;             // Number of functions for PB Cap
parameter PF_WD         = `CX_NFUNC_WD;             // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
parameter NL            = `CX_NL;                   // Number of Lanes Supported
parameter TXNL          = `CM_TXNL;                 // Tx Lane Width for M-PCIe
parameter RXNL          = `CM_RXNL;                 // Rx Lane Width for M-PCie
parameter NVC           = `CX_NVC;                  // Number of virtual channels
parameter SRIOV_NF      = `CX_SRIOV_NFUNC;          // Number of Physical Functions Where SRIOV is Enable
parameter BUSNUM_WD     = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter N_FLT_MASK    = `CX_N_FLT_MASK;
parameter NHQ           = `CX_NHQ;                  // Number of Header Queues per VC, corresponds to the Number of TLPs that can be processed in a single cycle
parameter NPRFX      = `CX_NPRFX;
parameter NVF        = `CX_NVFUNC;                  // Number of virtual functions
parameter PHY_NB        = `CX_PHY_NB;               // Number of symbols (bytes) per clock cycle of PHY's PIPE interface
parameter PHY_RXSB_WD   = `CX_PHY_RXSB_WD;          // Width of phy_mac_rxstartblock per lane
parameter PHY_RXSH_WD   = `CX_PHY_RXSH_WD;          // Width of phy_mac_rxsyncheader per lane

localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

localparam TLP_WIDTH = 128;
localparam HDR_PRFX_WD                = (NPRFX > 0) ? (TLP_WIDTH*2) : TLP_WIDTH;
localparam MIN_PYLD_WD = 9






                           ;
localparam NSPCIE       = `SPCIE_SIZE>>2 ; // Number of registers in Secondary PCIe Extended Capability Structure
localparam TX_PSET_WD     = 4;                        // Width of Transmitter Equalization Presets
localparam RX_PSET_WD     = 3;                        // Width of Receiver Equalization Presets
localparam NPL16G       = `PL16G_SIZE>>2 ; // Number of registers in Physical Layer 16.0 GT/s Extended Capability Structure
localparam NMARGIN      = `MARGIN_SIZE>>2 ; // Number of registers in Margining Extended Capability Structure
localparam NPL32G       = `PL32G_SIZE>>2 ; // Number of registers in Physical Layer 32.0 GT/s Extended Capability Structure
localparam NPL64G       = `PL64G_SIZE>>2 ; // Number of registers in Physical Layer 64.0 GT/s Extended Capability Structure
localparam NL1SUB       = 4;                          // Number of registers in L1 Substates Extended Capability Structure
localparam ERR_BUS_WD = `CX_ERR_BUS_WD;
localparam ATTR_WD = `FLT_Q_ATTR_WIDTH;
localparam NW       = `CX_NW;                            // Number of 32-bit dwords handled by the datapath each clock.
localparam FX_TLP   = `CX_FX_TLP;
localparam N_TRGT1_INTF        = `CX_RADM_NFC_TRGT_INTF;
localparam FX_TLP_ADR_DEC = FX_TLP - N_TRGT1_INTF;  // In MS, more than 1 address decodging is required and that is only for P and NP (For CPL TLP addr dec is not required)
localparam FX_TLP_NF      = FX_TLP; // In MS, The multiples PFs arrays between CDM-RADM are deleted.
localparam FX_TLP_ADR_DEC_NF = FX_TLP_ADR_DEC;
localparam HDR_SIZE    = `CX_AER_HDR_WIDTH;


localparam RX_TLP   = `CX_RX_TLP;                        // Number of TLPs received in a single cycle
localparam RX_NDLLP = `CX_RX_NDLLP;                      // Max number of DLLPs received per cycle
localparam TX_NDLLP = `CX_TX_NDLLP;
parameter FS_LF_WD = 12;
parameter COEF_WD = 18;
parameter ERROR_INJ_EN_WD   = `CX_RAS_ERROR_INJ_EN_WD;
parameter ERROR_INJ_MASK_WD = `CX_RAS_ERROR_INJ_MASK_WD;
localparam PASID_CNTRL_WD = `CX_PASID_CONTROL_WD;   // PASID Control width
localparam NF_PASID_CNTRL_WD = NF*PASID_CNTRL_WD; // PASID Control width times Number of Physical Functions
localparam TX_FS_WD   = 6; //Width of Full Swing or Low Frequency
localparam TX_COEF_WD = 18; // Width of concatenated bus for Equalization Coefficients: {C(+1), C(0), C(-1)}
localparam DIRFEEDBACK_WD = `DIRFEEDBACK_WD;
localparam FOMFEEDBACK_WD = 8; // Width of Figure of Merit
localparam RASDES_EC_RAM_DATA_WIDTH = `CX_RAS_DES_EC_RAM_DATA_WIDTH;
localparam RASDES_EC_RAM_ADDR_WIDTH = `CX_RAS_DES_EC_RAM_ADDR_WIDTH;
localparam RASDES_TBA_RAM_DATA_WIDTH = `CX_RAS_DES_TBA_RAM_DATA_WIDTH;
localparam RASDES_TBA_RAM_ADDR_WIDTH = `CX_RAS_DES_TBA_RAM_ADDR_WIDTH;
localparam RASDES_EC_INFO_CM = `CX_RAS_DES_EC_INFO_CMN_BW;
localparam RASDES_EC_INFO_PL = `CX_RAS_DES_EC_INFO_PLN_BW;
localparam RASDES_SD_INFO_CM = `CX_RAS_DES_SD_INFO_CMN_BW;
localparam RASDES_SD_INFO_PL = `CX_RAS_DES_SD_INFO_PLN_BW;
localparam RASDES_SD_INFO_PV = `CX_RAS_DES_SD_INFO_PVC_BW;
localparam RASDES_TBA_INFO_CM = `CX_RAS_DES_TBA_INFO_CMN_BW;
localparam NUM_EOT = `CX_NUM_EOT;

parameter APP_ERROR_WD              = `CX_RAS_APP_ERROR_WD;
parameter APP_ERROR_ADDR_WD         = `CX_RAS_APP_ERROR_ADDR_WD;


parameter RADM_SBUF_HDRQ_ERR_ADDR_WD = `CX_RADM_SBUF_HDRQ_PW + `CX_LOGBASE2(NHQ);

localparam RAS_RADM_COUNTERS = `CX_RAS_RADM_COUNTERS; // only valid for segbuf for now
localparam RAS_XDLH_COUNTERS = `CX_RAS_XDLH_COUNTERS;
localparam RAS_RADM_COUNTERS_MASK_CORR= (`CX_RAS_PROT_TYPE==1 || `CX_RAS_CORRECTION_EN==0) ? 12 : `CX_RAS_RADM_COUNTERS_MASK; //ecc hardcoded counter 2, 3
localparam RAS_XDLH_COUNTERS_MASK_CORR= (`CX_RAS_PROT_TYPE==1 || `CX_RAS_CORRECTION_EN==0) ? 40 : `CX_RAS_XDLH_COUNTERS_MASK; //counter 3 ,5 hard coded

localparam RAS_CXL_COUNTERS  = `CX_RAS_CXL_COUNTERS;
localparam RAS_CXL_COUNTERS_MASK = 8'b11111111;
localparam CXL_RBUF_DP = 255;
localparam CXL_RBUF_ADD_WD = $clog2(CXL_RBUF_DP);

localparam RAS_XADM_COUNTERS = `CX_RAS_XADM_COUNTERS+3;
localparam RAS_RDLH_COUNTERS = `CX_RAS_RDLH_COUNTERS;
localparam RAS_RTLH_COUNTERS = `CX_RAS_RTLH_COUNTERS;
localparam RAS_XADM_COUNTERS_MASK_CORR = (`CX_RAS_PROT_TYPE==1 || `CX_RAS_CORRECTION_EN==0) ? 0 : `CX_RAS_XADM_COUNTERS_MASK;
localparam RAS_RDLH_COUNTERS_MASK_CORR = (`CX_RAS_PROT_TYPE==1 || `CX_RAS_CORRECTION_EN==0) ? 0 : `CX_RAS_RDLH_COUNTERS_MASK;
localparam RAS_RTLH_COUNTERS_MASK_CORR = (`CX_RAS_PROT_TYPE==1 || `CX_RAS_CORRECTION_EN==0) ? 0 : `CX_RAS_RTLH_COUNTERS_MASK;
localparam RAS_XTLH_COUNTERS_MASK_CORR = (`CX_RAS_PROT_TYPE==1 || `CX_RAS_CORRECTION_EN==0) ? 0 : `CX_RAS_XTLH_COUNTERS_MASK;
localparam RAS_XTLH_COUNTERS = `CX_RAS_XTLH_COUNTERS;

localparam CORR_ERROR_WD   = RAS_RADM_COUNTERS + RAS_XDLH_COUNTERS
                           + RAS_CXL_COUNTERS
                            + RAS_XADM_COUNTERS+RAS_RDLH_COUNTERS+RAS_RTLH_COUNTERS
                            +RAS_XTLH_COUNTERS
                             + APP_ERROR_WD
                           ;

localparam UNCORR_ERROR_WD = RAS_RADM_COUNTERS+RAS_XDLH_COUNTERS
                           + RAS_CXL_COUNTERS
                           +RAS_XADM_COUNTERS+RAS_RDLH_COUNTERS+RAS_RTLH_COUNTERS
                            +RAS_XTLH_COUNTERS
                             + APP_ERROR_WD
                           ;

localparam RAS_COUNTER_WIDTH = 8;
localparam RAS_COUNTER_SEL_WD = 8;

// RAM Address WIDTH Paramenter
parameter RBUF_PW           = `RBUF_PW;
parameter SOTBUF_PW         = `SOTBUF_L2DEPTH;
parameter RADM_PQ_H_ADDRBITS = `CX_RADM_PQ_H_ADDRBITS;
parameter RADM_PQ_D_ADDRBITS = `CX_RADM_PQ_D_ADDRBITS;

// parameters needed to size the radm formation queue RAM interface
parameter NQW    = `CX_RADM_FORMQ_NQW;        // Number of RAMs that implement the formation queue.
parameter RAM_PW = `CX_RADM_FORMQ_QDW_RAM_PW; // the RAM address bit width


localparam PTM_REQ_VALUE  = `CX_PTM_REQUESTER_VALUE;
localparam CIO_EN         = `CX_PCIE_MODE == `PCIE_OVER_CIO;
localparam NPTMREQVSEC    =  CIO_EN ? 29 : 26;// Number of PTM Requester VSEC Registers
localparam NPTMRESVSEC    =  CIO_EN ? 31 : 19;// Number of PTM Responder VSEC Registers
localparam NPTMVSEC       = (NPTMREQVSEC>=NPTMRESVSEC) ? NPTMREQVSEC : NPTMRESVSEC;
localparam NPTM           = 3;
localparam MULTI_DEVICE_AND_BUS_PER_FUNC = `MULTI_DEVICE_AND_BUS_PER_FUNC_EN_VALUE;
localparam UPD_WD         = MULTI_DEVICE_AND_BUS_PER_FUNC ? (FX_TLP==2 ? NF*FX_TLP : NF) : 1;
localparam SNOOP_BUS_WD   = MULTI_DEVICE_AND_BUS_PER_FUNC ? (FX_TLP==2 ? 8*FX_TLP : 8) : 8;
localparam SNOOP_DEV_WD   = MULTI_DEVICE_AND_BUS_PER_FUNC ? (FX_TLP==2 ? 5*FX_TLP : 5) : 5;

localparam TAG_SIZE       = `CX_TAG_SIZE;

localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;

parameter ACS_CTRL_VEC_WD = `ACS_CTRL_VEC_WD;        // ACS Control Vector Width
parameter DPC_PRFX_LOG_SIZE = `CX_MAX_DPC_RPPIO_PRFXS_VALUE;       // Prefix log in DWs.
parameter DPC_PRFX_LOG_WD   = 32*DPC_PRFX_LOG_SIZE;                    // Prefix log width in bits.


localparam XADM_IF_WD        = N_XADM_IF;
localparam XADM_P_IF_WD      = N_XADM_P_IF;
localparam XADM_NP_IF_WD     = N_XADM_NP_IF;
localparam XADM_CPL_IF_WD    = N_XADM_CPL_IF;
localparam CCIX_IF_WD        = N_CCIX_IF;
localparam BASE_TOP_FUNC  = 32 
 
 
 
 

 ;

 localparam APP_HDR_LOG_WD       = `CX_APP_HDR_LOG_WIDTH;
 localparam APP_HDR_LOG_SZ_WD    = `CX_APP_HDR_LOG_SZ_WIDTH;
 localparam HDR_LOG_SIZE_WD      = 5; // number of bits needed to indicated the number of Header Size in DWs

localparam NDQ                        = `CX_NDQ;


reg                                   r_xdlh_retryram_addr_err;      // Error detected in RAM
reg                                   r_xdlh_retrysotram_raddr_err;  // Error detected in RAM
reg  [NQW-1:0]                        r_radm_formqram_raddr_err;     // Error detected in RAM
reg                                   r_p_hdrq_addrb_err;            // Error detected in RAM
reg  [NDQ-1:0]                        r_p_dataq_addrb_err;           // Error detected in RAM
reg  [APP_ERROR_WD-1:0]               r_app_error;



parameter N_DEVICES         = `CX_CXL_NLD_PLUS_1;

// ----- Inputs ---------------
input                   core_clk;                   // Core clock
input                   non_sticky_rst_n;           // Reset non-sticky registers only
input                   sticky_rst_n;               // Reset sticky registers only
input   [3:0]           device_type;                // Device type
// Local Bus interface
input                   app_dbi_ro_wr_disable;      // Set dbi_ro_wr_en to 0, disable write to DBI_RO_WR_EN bit
input   [31:0]          lbc_cdm_addr;               // Address of resource being accessed
input   [31:0]          lbc_cdm_data;               // Data for write
input   [NF-1:0]        lbc_cdm_cs;                 // Chip select (indicates an active bus cycle)
input   [3:0]           lbc_cdm_wr;                 // Write byte enables (active high)
input                   lbc_cdm_dbi;                // Indicates that the CDM is acccessed from dbi
input                   lbc_cdm_dbi2;               // Indicates that the CDM is acccessed from dbi2
input                   lbc_cdm_unroll;             // Indicates to CDM to access to UNROLL registers

input   [NF-1:0]        lbc_xmt_cpl_ca;             // Incidates that the LBC sent CPL w/ CA
// INTx - legacy interrupts
input   [NF-1:0]        sys_int;                    // interrupt signal per function from system side
// Power management
input                   sys_aux_pwr_det;            // Aux power is detected
// Slot
input   [NF-1:0]        sys_pre_det_state;          // Indicates the presence of a card in the slot
input   [NF-1:0]        sys_mrl_sensor_state;       // Reports the status of the MRL sensor if it is implemented
input   [NF-1:0]        sys_atten_button_pressed;   // Attention button is pressed or receive a message from end device
input   [NF-1:0]        sys_pwr_fault_det;          // Indicates a fault in the power controller
input   [NF-1:0]        sys_mrl_sensor_chged;       // Indicates the value of the MRL Sensor state had changed
input   [NF-1:0]        sys_pre_det_chged;          // Indicates Presence Detect had changed
input   [NF-1:0]        sys_cmd_cpled_int;          // this bit when set enables the generation of hot plug interrupt when a command is completed by hot plug control logic
input   [NF-1:0]        sys_eml_interlock_engaged;  // Electromechanical Interlock engaged
// Port Logic register specific
input   [31:0]          phy_cfg_status;             // PHY status register
input   [63:0]          cxpl_debug_info;            // debug bus
// Link
input   [5:0]           smlh_autoneg_link_width;    // negotiated link width
input   [5:0]           rplh_link_rxmode;           // negotiated Rx link width
input   [3:0]           smlh_autoneg_link_sp;       // negotiated link speed
input                   smlh_link_training_in_prog; // link training in progress
input                   smlh_bw_mgt_status;         // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                    // without the port transitioning through DL_Down status
input                   smlh_link_auto_bw_status;   // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                    // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
input                   smlh_clr_enter_compliance;  // Signal the cdm that the "Enter Compliance" bit in the "Link Control" register should be cleared
input                   smlh_tx_margin_rst;         // reset tx margin
input                   smlh_core_rst_n_release_pulse; // assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change
input                   smlh_dir_spd_chg_rising_edge;  // clear cfg_directed_speed_change
input                   mac_phy_txdeemph;           // selects transmitter de-emphasis in the PHY
input                   smlh_dir_linkw_chg_started; // clear cfg_directed_link_width_change
input   [2:0]           current_data_rate;          // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4, 4-gen5
input   [2:0]           tmp_int_mac_phy_rate;       // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4, 4-gen5
input   [31:0]          cfg_pwr_budget_data_reg;    // Data Register from application
input   [PF_WD-1:0]     cfg_pwr_budget_func_num;    // Function # of data register above
input                   rmlh_rcvd_err;              // PHY Receiver error

//For a Downstream Port, this bit must be Set if the component supports the optional capability of detecting and reporting a Surprise Down error condition.
input                       radm_pm_to_ack;          // Received PM_TO_ACK.
input                       pm_xmt_turnoff;          // Request this port to send turnoff message





 input  radm_hdr_log_s radm_hdrlog;




input   [(MSG_TLP_WD*NF)-1:0]  radm_pm_pme;         // Received a PME
input   [(MSG_TLP_WD*16)-1:0]  radm_msg_req_id;     // Requester ID of the above PME
input   [NF-1:0]        radm_set_slot_pwr_limit;    // 1 cycle enable pulse
input   [31:0]          radm_slot_pwr_payload;      // specifies the scale/value used for the slot power limit when radm_set_slot_pwr_limit is asserted
input   [NF-1:0]        radm_cpl_pending;           // Completion is pending
input                       radm_cpl_timeout;           // Completion timeout
input   [PF_WD-1:0]         radm_timeout_func_num;       // Function # associated with the above timeout

input                   dl_prot_err;                // data layer protocol error
input                   rdlh_bad_tlp_err;           // data layer receive bad TLP error
input                   rdlh_bad_dllp_err;          // data layer receive bad DLLP error
input                   rdlh_link_up;               // data layer link up
input                   xdlh_replay_num_rlover_err; // data layer transmit replay timeout number rollover
input                   xdlh_replay_timeout_err;    // data layer transmit replay timer timeout
input                   smlh_link_up;               // Link is active

input   [(MSG_TLP_WD*NF)-1:0]  radm_correctable_err;       // Received Correctable Error MSG
input   [(MSG_TLP_WD*NF)-1:0]  radm_nonfatal_err;          // Received Non-Fatal Uncorrectable Error MSG
input   [(MSG_TLP_WD*NF)-1:0]  radm_fatal_err;             // Received Fatal Uncorrectable Error MSG
input   [NF-1:0]        rtlh_overfl_err;            // Receiver overflow error
input   [NVC-1:0]       rtlh_fc_init_status;        // FC init status

//
// the following signal wiring depends on the location of the PCI-E port logic
//
input xadm_xmt_pci_errors_t xadm_xmt_pci_errors;
input   [NF-1:0]        xal_rcvd_cpl_ca;            // internal logic side received completion with ca
input   [NF-1:0]        xal_rcvd_cpl_ur;            // internal logic side received completion with ur
input   [NF-1:0]        xal_xmt_cpl_ca;             // internal logic side transmit completion with ca
input   [NF-1:0]        xal_perr;                   // detect PERR# (PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_serr;                   // detect SERR# (PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_set_trgt_abort_primary;     // Set trgt abort of primary(PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_set_mstr_abort_primary;     // Set mstr abort of primary(PCIe -> PCI/PCI-X bridge)
input   [NF-1:0]        xal_pci_addr_perr;              // Set secondary parity err detected(PCIe -> PCI/PCI-X bridge address/attribute error)


// Flow control credits
input   [HCRD_WD-1:0]   xtlh_xadm_ph_cdts;          // header for P credits
input   [DCRD_WD-1:0]   xtlh_xadm_pd_cdts;          // data for P credits
input   [HCRD_WD-1:0]   xtlh_xadm_nph_cdts;         // header for NP credits
input   [DCRD_WD-1:0]   xtlh_xadm_npd_cdts;         // data for NP credits
input   [HCRD_WD-1:0]   xtlh_xadm_cplh_cdts;        // header for CPL credits
input   [DCRD_WD-1:0]   xtlh_xadm_cpld_cdts;        // data for CPL credits
input                   radm_qoverflow;             // RADM queue has overflowed, for debug purpose
input                   radm_q_not_empty;           // RADM queue is not empty after test is complete, for debug purpose
input                   radm_formq_read_err;
input                   radm_formq_overflow;
input                   radm_formq_not_empty;
input                   xdlh_retrybuf_not_empty;    // XDLH retry buffer is not empty after test is complete, for debug purpose
input                   rtlh_crd_not_rtn;           // RTLH credits are not returned after test is complete, for debug purpose

input                   pm_pclkack_timeout;         // timer t_pclkack timeout, indicate internal error


//--------------------- outputs -------------------------


// for PM handshake
input   [NF-1:0]        pm_status;                  // PM status, indicates if a previously enabled PME event occurred or not - Sticky
input   [NF-1:0]        pm_pme_en;                  // PME enable, device is enabled to generate PME - Sticky
input   [NF-1:0]        aux_pm_en;                  // AUX Power PM enable: enable device to draw AUX power independent of PME AUX Power - Sticky

// for filter address decoding
input [(FX_TLP_ADR_DEC*64)-1:0] flt_cdm_addr;               // 64-bit address to be compared with BAR
input    [(FX_TLP*PF_WD)-1:0]   flt_cdm_pf;
input   [NF-1:0]        pm_radm_block_tlp;          // In D1, D2 or D3 state - block certain error messages
input [FX_TLP_ADR_DEC-1:0]      flt_cdm_addr_valid;

input                   app_hdr_valid;              // application can return error transaction's header log through this interface. When valid, app_hdr_log will be sampled
input   [APP_HDR_LOG_WD-1:0]        app_hdr_log;
input                               app_hdr_flitmode;
input [APP_HDR_LOG_SZ_WD-1:0]       app_hdr_log_size;
input [ERR_BUS_WD-1:0]  app_err_bus;                // application detected errors defined as : {req_ur, req_ca, malformed_tlp, cpl_timeout}
input                   app_err_advisory;           // application return error is an advisory error (see PCIe 1.1 spec)
input                   app_poisoned_tlp_type;      // application determines the type of the received poisoned TLP. if (0), the received poisoned TLP is a write request. if(1), The received poisoned TLP is a completion TLP.
input [PF_WD-1:0]       app_err_func_num;           // function number of the application returned error from

input                   xadm_fc_prot_err;           // Optional check for Received flow control error

input [(MSG_TLP_WD)-1:0]      radm_drs_msg;
wire  [(MSG_TLP_WD)-1:0]      radm_drs_msg;
input ltssm_state_e           smlh_ltssm_state;
input [(MSG_TLP_WD)-1:0]      radm_frs_msg;
input [(MSG_TLP_WD*4)-1:0]    radm_frs_msg_reason;
wire  [(MSG_TLP_WD)-1:0]      radm_frs_msg;
wire  [(MSG_TLP_WD*4)-1:0]    radm_frs_msg_reason;
input [NF-1:0]            pmstate_d3hot_to_d0;



input   [NL-1:0]          rmlh_lane_err;            // Receiver Lane Error
input                     smlh_ls2_eq_req;          // Equalization request
input  [3:1]              smlh_ls2_eq_success;      // Equalization Successful {Phase 3, Phase 2, Phase 1}
input                     smlh_ls2_eq_cmpl;         // Equalization Complete
input                     smlh_ls2_eq_enter;        // Equalization Entered
input [NL*TX_PSET_WD-1:0] smlh_lec_pset_ltx;        // Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input [NL*RX_PSET_WD-1:0] smlh_lec_pset_lrx;        // Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input                     smlh_ltssm_in_detectquiet;
input                     smlh_ls2_g4_eq_req;       // g4 Equalization request
input  [3:1]              smlh_ls2_g4_eq_success;   // g4 Equalization Successful {Phase 3, Phase 2, Phase 1}
input                     smlh_ls2_g4_eq_cmpl;      // g4 Equalization Complete
input                     smlh_ls2_g4_eq_enter;     // g4 Equalization Entered
input [NL*TX_PSET_WD-1:0] smlh_lec_g4_pset_ltx;     // g4 Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input [NL*RX_PSET_WD-1:0] smlh_lec_g4_pset_lrx;     // g4 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input                     smlh_ls2_g5_eq_req;       // g5 Equalization request, no cap reg defined for V5.0 R0.3
input  [3:1]              smlh_ls2_g5_eq_success;   // g5 Equalization Successful {Phase 3, Phase 2, Phase 1}, no cap reg defined for V5.0 R0.3
input                     smlh_ls2_g5_eq_cmpl;      // g5 Equalization Complete, no cap reg defined for V5.0 R0.3
input                     smlh_ls2_g5_eq_enter;     // g5 Equalization Entered
input [NL*TX_PSET_WD-1:0] smlh_lec_g5_pset_ltx;     // g5 Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW), no cap reg defined for V5.0 R0.3
input [NL*RX_PSET_WD-1:0] smlh_lec_g5_pset_lrx;     // g5 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW), no cap reg defined for V5.0 R0.3
input [1:0]               smlh_elbc_rcvd;           // g5 Received Enhanced Link Behavior Control
input                     smlh_tx_precoding_on;     // g5 Transmitter Precoding On
input                     smlh_noeq_needed_rcvd;    // g5 No EQ Needed Received
input                     smlh_ls2_g6_eq_req;       // g6 Equalization request, no cap reg defined for V5.0 R0.3
input  [3:1]              smlh_ls2_g6_eq_success;   // g6 Equalization Successful {Phase 3, Phase 2, Phase 1}, no cap reg defined for V5.0 R0.3
input                     smlh_ls2_g6_eq_cmpl;      // g6 Equalization Complete, no cap reg defined for V5.0 R0.3
input                     smlh_ls2_g6_eq_enter;     // g6 Equalization Entered
input [NL*TX_PSET_WD-1:0] smlh_lec_g6_pset_ltx;     // g6 Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW), no cap reg defined for V5.0 R0.3
input [NL*RX_PSET_WD-1:0] smlh_lec_g6_pset_lrx;     // g6 Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW), no cap reg defined for V5.0 R0.3
input                     smlh_g6_tx_precoding_on;// g6 Transmitter Precoding On
input                     smlh_retimer_pre_detected; // Retimer was present during the latest Config.Complete
input                     smlh_two_retimers_pre_detected; // Two Retimer were present during the latest Config.Complete
input   [1:0]             smlh_crosslink_resolution;      // indicates the state of crosslink resolution
input   [NL*5-1:0]        rmlh_deskew_ctlskp_err;         // CS-SKP-OS error [0]data parity[1]1st retimer[2]2nd retimer[3]margin crc[4]margin parity
input   [NL-1:0]          smlh_margin_status_valid;       // Margining Status Valid
input   [NL*16-1:0]       smlh_margin_status;             // Margining Status [2:0]Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
input                     smlh_margin_ready;              // indicates when the Margining feature is ready to accept margining commads
input                     app_margining_ready;            // indicates the status of Margining Ready in Margining Port Status Register
input                     app_margining_software_ready;   // indicates the status of Margining Software Ready in Margining Port Status Register
input                     smlh_mod_ts_rcvd;         // g5 Modified TS Received
input   [55:0]            mod_ts_data_rcvd;         // mod ts data rcvd
input   [55:0]            mod_ts_data_sent;         // mod ts data txed
input [CRGB_DATA_WIDTH - 1 :0]    crgb_cdm_rdata;
input                             crgb_cdm_ack;
input                   app_ltr_msg_req;                // LTR message request - from Application interface
input                   msg_ltr_det;                // Transmitted (by upstream port) or Received (by downstream port) LTR message detected
input   [31:0]          msg_ltr_latency;            // Transmitted (by upstream port) or Received (by downstream port) LTR message field
input                   msgg2cdm_ltr_clr_msg_grant; // LTR clear message grant

input                   xdlh_retry_req;              // Pulse : Retry Event
input  [1:0]            rdlh_dlcntrl_state;          // Layer 2 control state

input  [1:0]            app_ras_des_tba_ctrl;             // Time base analysis control
input  [RASDES_EC_RAM_DATA_WIDTH-1:0] cdm_ras_des_ec_ram_dataout; // RAS DES event counter register RAM data out
input  [RASDES_TBA_RAM_DATA_WIDTH-1:0] cdm_ras_des_tba_ram_dataout; // RAS DES time based analysis register RAM data out
input  [NL-1:0]         rmlh_ebuf_rxoverflow;           // Pulse : Rx elastic buffer overflow error status if the corresponding lane detected a lane-based error
input  [NL-1:0]         rmlh_ebuf_rxunderflow;          // Pulse : Rx elastic buffer underflow error status if the corresponding lane detected a lane-based error
input  [NL-1:0]         rmlh_phy_rxcodeerror;           // Pulse : Rx symbol error status if the corresponding lane detected a lane-based error
input  [NL-1:0]         rmlh_phy_rxdisperror;           // Pulse : Rx running disparity error if the corresponding lane detected a lane-based error
input  [NL-1:0]         rmlh_skp_parity_err;            // Pulse : Rx skip ordered set parity error
input  [NL-1:0]         rmlh_sync_header_err;           // Pulse : Rx sync header undefined error
input  [NL-1:0]         rmlh_rxvalid_deasserted;        // Pulse : Rx burst de-assertion
input                   rmlh_framing_err;               // Pulse : Rx framing error in gen3 rate
input                   rmlh_framing_err_l0;            // Pulse : Rx framing error in gen3 rate when L0 state
input                   rmlh_deskew_alignment_err;      // Level : Rx deskew alignment error
input  [NL-1:0]         rmlh_rxskipadded;               // Pulse : Rx skip added in elastic buffer
input  [NL-1:0]         rmlh_rxskipremoved;             // Pulse : Rx skip removed in elastic buffer
input  [(NL*8)-1:0]     rmlh_deskew_fifo_ptr;           // Pulse : Rx deskew pointer address
input  [6:0]            rmlh_framing_err_ptr;           // Pulse : Rx framing error pointer in gen3 rate
input                   smlh_eidle_inferred_in_l0;      // Level: Detect EI Infer for Ras D.E.S event counter
input                   smlh_rx_rcvry_req;              // Level: Rx Recovery Request for Ras D.E.S event counter
input                   smlh_timeout_nfts;              // Level: N_FTS Timeout for Ras D.E.S event counter
input                   smlh_l0_to_recovery;            // Pulse : L0 to Recovery for Ras D.E.S event counter
input                   smlh_l1_to_recovery;            // Pulse : L1 to Recovery for Ras D.E.S event counter
input                   smlh_in_l0s;                    // Level: Tx L0s Entry for Ras D.E.S event counter
input                   smlh_in_rl0s;                   // Level: Rx L0s Entry for Ras D.E.S event counter
input                   smlh_ltssm_in_l0p;              // Level: L0p for Ras D.E.S
input                   smlh_link_in_training;          // Level: Config/Recovery for Ras D.E.S
input                   smlh_rcv_eios_when_l0s_unsprt;  // Pulse: Received EIOS when L0s is not supported and not directed L1 or L2 for Ras D.E.S event counter
input                   smlh_deskew_uncomplete_err;     // Pulse: Deskew uncompleted error for Ras D.E.S event counter
input                   cxl_almp_rx_repl_error;         // Pulse: (CXL only) ALMP Replication error
input                   cxl_vlsm_unexp_error;           // Pulse: (CXL only) unexpected ALMP error
input                   cxl_vlsm_lrsm_req_retrain;      // Pulse: (CXL only) NUM_RETRY reached MAX_NUM_RETRY
input                   pm_asnak;                       // Level: ASPM L1 reject for Ras D.E.S event counter
input  [2:0]            l1sub_state;                    // Level: L1 sub state
input                   pm_in_l11;                      // Level: L1.1 Entry for Ras D.E.S event counter
input                   pm_in_l12;                      // Level: L1.2 Entry for Ras D.E.S event counter
input                   pm_in_l1_short;                 // Level: L1 short duration for Ras D.E.S event counter
input                   pm_in_l1_cpm;                   // Level: L1 Clock PM (L1 with REFCLK removal/PLL Off) for Ras D.E.S event counter
input                   pm_in_l1_abort;                 // Level: L1.2 abort for Ras D.E.S event counter
input                   smlh_in_l23;                    // Level: L2 Entry for Ras D.E.S event counter
input                   smlh_spd_change;                // Level: Speed Change for Ras D.E.S event counter
input                   smlh_lwd_change;                // Level: Link Width Change for Ras D.E.S event counter
input  [RX_TLP-1:0]     rdlh_bad_tlp_err_pertlp;        // Pulse : Rx Bad TLP Event per TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]     rdlh_lcrc_tlp_err_pertlp;       // Pulse : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]     rdlh_nulified_tlp_err_pertlp;   // Pulse : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]     rdlh_duplicate_tlp_err_pertlp;  // Pulse : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
input  [RX_NDLLP-1:0]   rdlh_bad_dllp_err_perdllp;      // Pulse : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
input  [RX_NDLLP-1:0]   rdlh_rcvd_nack_perdllp;         // Pulse : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
input  [RX_NDLLP-1:0]   rdlh_rcvd_ack_perdllp;          // Pulse : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
input                   xdlh_nak_sent;                  // Pulse : Tx Nak DLLP Event per TLP for Ras D.E.S event counter
input                   xdlh_ack_sent;                  // Pulse : Tx Ack DLLP Event per TLP for Ras D.E.S event counter
input  [TX_NDLLP-1:0]   xdlh_update_fc_sent;            // Pulse : Tx Update-FC DLLP Event per TLP for Ras D.E.S event counter
input  [XADM_IF_WD-1:0]  xadm_tx_nullify_evt;            // Pulse : Tx Nullified TLP Event for Ras D.E.S event counter
input                   rtlh_req_link_retrain;          // Pulse : FC Timeout Event per TLP for Ras D.E.S event counter
input  [RX_NDLLP -1:0]  rtlh_rcvd_ufc_perdllp;          // Pulse : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_memwr_evt;             // Pulse : Rx Memory Write TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_defmemwr_evt;          // Pulse : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_memrd_evt;             // Pulse : Rx Memory Read TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_cfgwr_evt;             // Pulse : Rx Config Write TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_cfgrd_evt;             // Pulse : Rx Config Read TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_iowr_evt;              // Pulse : Rx I/O Write TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_iord_evt;              // Pulse : Rx I/O Read TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_cplwod_evt;            // Pulse : Rx Completion without Data TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_cplwd_evt;             // Pulse : Rx Completion with Data TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_msg_evt;               // Pulse : Rx Message TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_atmcop_evt;            // Pulse : Rx AtomicOp TLP for Ras D.E.S event counter
input  [RX_TLP-1:0]      rtlh_rx_tlpwprefix_evt;        // Pulse : Rx TLP with Prefix for Ras D.E.S event counter
input  [RX_TLP*11-1:0]  rtlh_rx_tlp_dpsize;             // Receiving TLP's data payload size[DW]
input  [XADM_P_IF_WD-1:0]    xtlh_tx_memwr_evt;              // Pulse : Tx Memory Write TLP Event for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_defmemwr_evt;           // Pulse : Tx Deferrable Memory Write TLP Event for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_memrd_evt;              // Pulse : Tx Memory Read TLP Event TLP for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_cfgwr_evt;              // Pulse : Tx Config Write TLP for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_cfgrd_evt;              // Pulse : Tx Config Read TLP for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_iowr_evt;               // Pulse : Tx I/O Write TLP for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_iord_evt;               // Pulse : Tx I/O Read TLP for Ras D.E.S event counter
input  [XADM_CPL_IF_WD-1:0]    xtlh_tx_cplwod_evt;             // Pulse : Tx Completion with data TLP for Ras D.E.S event counter
input  [XADM_CPL_IF_WD-1:0]    xtlh_tx_cplwd_evt;              // Pulse : Tx Completion without data TLP for Ras D.E.S event counter
input  [XADM_P_IF_WD-1:0]    xtlh_tx_msg_evt;                // Pulse : Tx Message TLP for Ras D.E.S event counter
input  [XADM_NP_IF_WD-1:0]    xtlh_tx_atmcop_evt;             // Pulse : Tx AtomicOP TLP for Ras D.E.S event counter
input  [XADM_IF_WD-1:0]    xtlh_tx_tlpwprefix_evt;         // Pulse : Tx TLP with Prefix for Ras D.E.S event counter
input  [XADM_IF_WD*11-1:0] xtlh_tx_tlp_dpsize;             // Transmitting TLP data payload size[DW]
input  [NL*`CX_PHY_TXEI_WD-1:0] mac_phy_txelec_txburst; // Level : PIPE: TxElecIdle/TxBurst for Ras D.E.S Silicon Debug
input  [NL-1:0]         mac_phy_rxpolarity;             // Level : PIPE: RxPolarity for Ras D.E.S Silicon Debug
input  [NL-1:0]         phy_mac_rxelec_rxh8exit;        // Level : PIPE: RxElecIdle/RxHibern8ExitType1 for Ras D.E.S Silicon Debug
input  [NL-1:0]         phy_mac_rxvalid_rxburst;        // Level : PIPE: RxValid/RxBurst
input  [(NL*PHY_NB*8)-1:0]  orig_pipe_rxdata;           // Level: Origial PIPE RxData
input  [(NL*PHY_NB)-1:0]    orig_pipe_rxdatak;          // Level: Origial PIPE RxDataK
input  [NL-1:0]         orig_pipe_rxdatavalid;          // Level: Origial PIPE RxDataValid
input  [(NL*3)-1:0]     orig_pipe_rxstatus;             // pulse : Origial PIPE RxStatus
input  [(NL*PHY_RXSB_WD)-1:0]  orig_pipe_rxstartblock;  // Level: Origial PIPE RxStartBlock
input  [(NL*PHY_RXSH_WD)-1:0]  orig_pipe_rxsyncheader;  // Level: Origial PIPE RxSyncHeader
input                   orig_pipe_blockaligncontrol;    // Level: Origial PIPE BlockAlignControl
input  [NL-1:0]         latched_rxdetected;             // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
input                   pm_pme_resend_flag;             // Level : PME Re-Send flag for Ras D.E.S Silicon Debug
input  [15:0]           smlh_ltssm_variable;            // Level: Ltssm specific parameters for Ras D.E.S event counter
input  [1:0]            ltssm_powerdown;                // Level: PIPE: Power Down for Ras D.E.S Silicon Debug
input  [7:0]            latched_ts_nfts;                // Level: Latched NFTS for Ras D.E.S Silicon Debug
input usp_link_fsm_state_e pm_usp_link_state;           // Level : PM Internal usp link fsm state for Ras D.E.S Silicon Debug
input usp_prot_fsm_state_e pm_usp_prot_state;           // Level : PM Internal usp prot fsm state for Ras D.E.S Silicon Debug
input dsp_link_fsm_state_e pm_dsp_link_state;           // Level : PM Internal dsp link fsm state for Ras D.E.S Silicon Debug
input dsp_prot_fsm_state_e pm_dsp_prot_state;           // Level : PM Internal dsp prot fsm state for Ras D.E.S Silicon Debug
input pm_active_l0s_fsm_e  pm_l0s_state;                // Level : PM Internal l0s fsm state for Ras D.E.S Silicon Debug
input                   smlh_lane_reversed;             // Level : Lane Reversal Operation for Ras D.E.S Silicon Debug
input                   init_eq_pending;                // Level : Equalization sequence for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_fs;            // Level : Remote Device FS for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_lf;            // Level : Remote Device LF for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_ltx;    // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL*FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback; // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
input  [NL*3-1:0]       eqpa_violate_rule_123;          // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
input  [NL*2-1:0]       eq_convergence_sts;             // Level : Equalization convergence information for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_rtx;    // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL*RX_PSET_WD-1:0] mac_cdm_ras_des_pset_lrx;    // Level : Current Local Receiver Preset for Ras D.E.S Silicon Debug
input  [NL-1:0]         mac_cdm_ras_des_reject_rtx;     // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
input                   init_eq_pending_g4;             // Level : Equalization sequence  for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_fs_g4;         // Level : Remote Device FS for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_lf_g4;         // Level : Remote Device LF for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_ltx_g4; // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL*FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g4; // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
input  [NL*3-1:0]       eqpa_violate_rule_123_g4;       // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
input  [NL*2-1:0]       eq_convergence_sts_g4;          // Level : Equalization convergence information for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_rtx_g4; // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL-1:0]         mac_cdm_ras_des_reject_rtx_g4;  // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
input                   init_eq_pending_g5;             // Level : Equalization sequence  for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_fs_g5;         // Level : Remote Device FS for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_lf_g5;         // Level : Remote Device LF for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_ltx_g5; // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL*FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g5; // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
input  [NL*3-1:0]       eqpa_violate_rule_123_g5;       // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
input  [NL*2-1:0]       eq_convergence_sts_g5;          // Level : Equalization convergence information for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_rtx_g5; // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL-1:0]         mac_cdm_ras_des_reject_rtx_g5;  // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
input                   init_eq_pending_g6;             // Level : Equalization sequence  for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_fs_g6;         // Level : Remote Device FS for Ras D.E.S Silicon Debug
input  [NL*TX_FS_WD-1:0] mac_cdm_ras_des_lf_g6;         // Level : Remote Device LF for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_ltx_g6; // Level : Current Local Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL*FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g6; // Level : Current Figure of Merit for Ras D.E.S Silicon Debug
input  [NL*3-1:0]       eqpa_violate_rule_123_g6;       // Level : Rule A/B/C Violation Event Status for Ras D.E.S Silicon Debug
input  [NL-1:0]         eqpa_violate_rule_4_g6;         // Level : Rule D Violation Event Status for Ras D.E.S Silicon Debug
input  [NL*2-1:0]       eq_convergence_sts_g6;          // Level : Equalization convergence information for Ras D.E.S Silicon Debug
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_coef_rtx_g6; // Level : Current Remote Transmitter coefficient for Ras D.E.S Silicon Debug
input  [NL-1:0]         mac_cdm_ras_des_reject_rtx_g6;  // Level : Receive Reject Coefficient Event status for Ras D.E.S Silicon Debug
input  [1:0]            rl0s_state;
input  [NL*TX_COEF_WD-1:0] mac_cdm_ras_des_txdeemph;
input  [2:0]            mac_phy_rate;
input  [1:0]            mac_phy_powerdown;
input  [NL-1:0]         mac_phy_txdetectrx_loopback;
input  [NL-1:0]         mac_phy_rxeqeval;
input  [NL-1:0]         phy_mac_phystatus;
input  [NL*DIRFEEDBACK_WD-1:0] phy_mac_dirfeedback;
input  [NL*FOMFEEDBACK_WD-1:0] phy_mac_fomfeedback;
input  [NL*16-1:0]      smlh_rxos_type;
input  [NL*8-1:0]       smseq_mcs_sts;
input  [NL*64-1:0]      smseq_ts_debug_info;
input                   rdlh_vc0_initfc1_status;       // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
input                   rdlh_vc0_initfc2_status;       // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug
input  [11:0]           rdlh_xplh_curnt_rx_ack_seqnum; // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
input  [11:0]           xdlh_xplh_curnt_seqnum;        // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] rtlh_fc_rcvd_ph;            // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] rtlh_fc_rcvd_pd;            // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] rtlh_fc_rcvd_nph;           // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] rtlh_fc_rcvd_npd;           // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] rtlh_fc_rcvd_cplh;          // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] rtlh_fc_rcvd_cpld;          // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] rtlh_fc_allctd_ph;          // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] rtlh_fc_allctd_pd;          // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] rtlh_fc_allctd_nph;         // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] rtlh_fc_allctd_npd;         // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] rtlh_fc_allctd_cplh;        // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug;
input  [(NVC*DCRD_WD)-1:0] rtlh_fc_allctd_cpld;        // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug;
input  [(NVC*HCRD_WD)-1:0] xadm_fc_cnsmd_ph;           // Level : Current FC Credit Consumed(Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] xadm_fc_cnsmd_pd;           // Level : Current FC Credit Consumed(Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] xadm_fc_cnsmd_nph;          // Level : Current FC Credit Consumed(Non-Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] xadm_fc_cnsmd_npd;          // Level : Current FC Credit Consumed(Non-Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] xadm_fc_cnsmd_cplh;         // Level : Current FC Credit Consumed(Completion Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] xadm_fc_cnsmd_cpld;         // Level : Current FC Credit Consumed(Completion Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] xadm_fc_limit_ph;           // Level : Current FC Credit limit(Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] xadm_fc_limit_pd;           // Level : Current FC Credit limit(Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] xadm_fc_limit_nph;          // Level : Current FC Credit limit(Non-Posted Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] xadm_fc_limit_npd;          // Level : Current FC Credit limit(Non-Posted Data) for Ras D.E.S Silicon Debug
input  [(NVC*HCRD_WD)-1:0] xadm_fc_limit_cplh;         // Level : Current FC Credit limit(Completion Header) for Ras D.E.S Silicon Debug
input  [(NVC*DCRD_WD)-1:0] xadm_fc_limit_cpld;         // Level : Current FC Credit limit(Completion Data) for Ras D.E.S Silicon Debug
input  [2:0]            rdlh_einj0_lcrc_evt;            // Error injection 0 event flag
input  [2:0]            radm_einj0_ecrc_evt;            // Error injection 0 Rx ECRC TLP event
input                   xmlh_einj0_oscrc_evt;           // Error injection 0 CRC error event
input  [1:0]            xdlh_einj0_lcrc_evt;            // Error injection 0 LCRC event
input                   xdlh_einj0_fcrc_evt;            // Error injection 0 ECRC event
input  [1:0]            xdlh_einj0_dllpcrc_evt;         // Error injection 0 DLLP CRC event
input                            xadm_einj0_ecrc_evt;         // Error injection 0 Tx ECRC TLP event
input  [1:0]            ras_des_einj1_exp_sequm_evt;  
input                   ras_des_einj1_ack_nak_sequm_evt;
input                   xdlh_einj2_nak_evt;             // Error injection 2 NAK event
input  [1:0]            xmlh_einj3_osmsk_evt;           // Error injection 3 8b/10b K-code mask event
input                   rtlh_einj4_fc_evt;              // Error injection 4 FC event
input                   xdlh_einj5_nultlp_evt;          // Error injection 5 nullified TLP event
input                   xdlh_einj5_dup_evt;             // Error injection 5 Duplicate TLP event
input  [$clog2(N_XALI_IF+2)-1:0] xaim_einj6_tlp_evt;    // Error Injection 6 TLP header event flag
input  [(FX_TLP*8)-1:0] radm_mlf_tlp_err_ptr;           // Pulse : malformed TLP 1st error pointer (enabled by radm_mlf_tlp_err)
input ras_dp_err_log_t  ras_dp_err_log;
output ras_dp_err_inj_t ras_dp_err_inj;
output logic            ras_dp_err_inj_wake_up;
output logic            ras_error_tracer_pending;
output logic            ras_dp_unc_err;
output logic            ras_dp_cor_err;
output logic            ras_ram_unc_err;
output logic            ras_ram_cor_err;

input                   smlh_in_l0;                     // Level: L0(idl) for Ras D.E.S
input                   smlh_in_l1;                     // Level: L1 Entry for Ras D.E.S event counter

input                   ptm_auto_update_signal;        //Manual PTM Requester timing update signal from register
input                   ptm_manual_update_pulse;
input                   pm_linkst_in_l0;        //from pm_active_ctrl indicating PM state in L0
input                   pm_linkst_in_l0s;       //from pm_active_ctrl indicating PM state in L0s

input                   ptm_external_master_strobe;
input [63:0]            ptm_external_master_time;
input                   radm_ptm_req;
input                   radm_ptm_res_msg;
input                   radm_ptm_res_d_msg;
input [63:0]            radm_ptm_master_time;
input [31:0]            radm_ptm_prop_delay;
input                   xdlh_ptm_sot;
input                   xdlh_ptm_request;
input                   xdlh_ptm_multi_cycle;
input                   xdlh_ptm_response;
input                   xdlh_rbuf_replaying;
input                   rdlh_ptm_sot;
input                   rdlh_ptm_multi_cycle;
input                   rdlh_ptm_request;
input                   rdlh_ptm_response;
input                   rdlh_duplicate_tlp;
input                   pm_sel_aux_clk;
input                   aux_clk_active;
input [UPD_WD-1:0]        radm_snoop_upd;
input [SNOOP_BUS_WD-1:0]  radm_snoop_bus_num;
input [SNOOP_DEV_WD-1:0]  radm_snoop_dev_num;
input    [NF-1:0]       prs_res_failure;
input    [NF-1:0]       prs_uprgi;
input    [NF-1:0]       prs_stopped;
input                   rdlh_rcvd_dl_feature;
input [31:0]            rcvd_dl_feature_content;

input                   app_clk_pm_en;


input  [4:0]             app_dev_num;                 // Device number driven by the application
input  [7:0]             app_bus_num;                 // Bus Number drive by the application
input                 lbc_cdm_rcrb_wire;               // From LBC ; Indicates RCRB wire access
input                 lbc_cdm_rcrb_mbar0_wire;         // From LBC ; Indicates RCRB MEMBAR wire access
input                 lbc_cdm_rcrb_dbi;                // From LBC ; Indicates RCRB dbi access
input                 lbc_cdm_rcrb_mbar0_dbi;          // From LBC ; Indicates RCRB MEMBAR dbi access
input [51:0]          rcrb_base_addr;               // From RADM ; Indicates the base address for the RCRB region
input                 rcrb_base_addr_valid;               // From RADM ; Indicates the base address for the RCRB region
input                 cxl_rcrb_enable;              // CXL RCRB is enabled
input                 cxl_mbar0_enable;             // CXL MBAR0 is enabled
input ltssm_cxl_enable_t      ltssm_cxl_enable; // LTSSM CXL Enable Bus as seen on SPIF Interface
input ltssm_cxl_enable_t  phy_ltssm_cxl_enable; // LTSSM CXL Enable Bus as negotiated by the LogPHY
input [23:0]          cxl_port_rcvd_mod_ts_data_phase1;
input                 cxl_retimers_present_mismatched;
input                 flexbusenablebits_phase2_mismatch;
input                 mbar0_ras_unc_cache_data_parity;
input                 mbar0_ras_unc_cache_addr_parity;
input                 mbar0_ras_unc_cache_be_parity;
input                 mbar0_ras_unc_cache_data_ecc;
input                 mbar0_ras_unc_mem_data_parity;
input                 mbar0_ras_unc_mem_addr_parity;
input                 mbar0_ras_unc_mem_be_parity;
input                 mbar0_ras_unc_mem_data_ecc;
input                 mbar0_ras_unc_reinit_threshold;
input                 mbar0_ras_unc_rsvd_encoding_violation;
input                 mbar0_ras_unc_poison_received;
input                 mbar0_ras_unc_receiver_overflow;
input                 mbar0_ras_unc_internal_error;
input                 mbar0_ras_unc_cxl_ide_tx_error;
input                 mbar0_ras_unc_cxl_ide_rx_error;

input                 mbar0_ras_corr_cache_data_ecc;
input                 mbar0_ras_corr_mem_data_ecc;
input                 mbar0_ras_corr_crc_threshold;
input                 mbar0_ras_corr_retry_threshold;
input                 mbar0_ras_corr_cache_poison_received;
input                 mbar0_ras_corr_mem_poison_received;
input                 mbar0_ras_corr_physical_layer_error;

input   [31:0]        mbar0_ras_header_log_reg0;
input   [31:0]        mbar0_ras_header_log_reg1;
input   [31:0]        mbar0_ras_header_log_reg2;
input   [31:0]        mbar0_ras_header_log_reg3;
input   [31:0]        mbar0_ras_header_log_reg4;
input   [31:0]        mbar0_ras_header_log_reg5;
input   [31:0]        mbar0_ras_header_log_reg6;
input   [31:0]        mbar0_ras_header_log_reg7;
input   [31:0]        mbar0_ras_header_log_reg8;
input   [31:0]        mbar0_ras_header_log_reg9;
input   [31:0]        mbar0_ras_header_log_reg10;
input   [31:0]        mbar0_ras_header_log_reg11;
input   [31:0]        mbar0_ras_header_log_reg12;
input   [31:0]        mbar0_ras_header_log_reg13;
input   [31:0]        mbar0_ras_header_log_reg14;
input   [31:0]        mbar0_ras_header_log_reg15;

input   [3:0]         cxl_pl_reg_vlsm_state;
input   [3:0]         cxl_pl_reg_cache_mem_vlsm_state;
input   [3:0]         cxl_pl_reg_io_vlsm_state;
input   [2:0]         cxl_pl_reg_mc_almp_unexp_error;
input   [2:0]         cxl_pl_reg_io_almp_unexp_error;
input   [5:0]         cxl_pl_reg_lrsm_state;                                     //Reflects the current state of the LRSM
input                 cxl_pl_reg_lrsm_fatal_error;
input   [31:0]        cxl_pl_reg_fatal_error;
input                 cxl_pl_reg_cm_ll_cache_poison_injection_busy;     // CXL.cache/CXL.mem LinkLayerErrorInjection - Cache Poison Injection Busy
input                 cxl_pl_reg_cm_ll_mem_poison_injection_busy;       // CXL.cache/CXL.mem LinkLayerErrorInjection - Mem Poison Injection Busy
input                 cxl_pl_reg_cm_ll_io_poison_injection_busy;        // CXL.cache/CXL.mem LinkLayerErrorInjection - IO Posion Injection Busy
input                 cxl_pl_reg_cm_ll_cache_mem_crc_injection_busy;    // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Busy
input                 cxl_pl_reg_io_ll_io_poison_injection_busy;        // CXL.io LinkLayer Error injection - IO Posion Injection Busy
input                 cxl_pl_reg_io_ll_flow_ctrl_error_injection_busy;  // CXL.io LinkLayer Error injection - Flow Control Error Injection Busy
input                 cxl_pl_reg_fb_phy_protid_injection_busy;          // Flex Bus LogPHY Error injection - Protocol ID Error Injection Busy



input  rplh_flit_logging_interface_struct rplh_flit_logging_interface;    // flit logging interface signals from RPLH          
input  rmlh_flit_logging_interface_struct rmlh_flit_logging_interface;    // flit logging interface signals from RMLH  
input  smlh_flit_logging_interface_struct smlh_flit_logging_interface;    // flit logging interface signals from SMLH  
input xplh_cdm_flit_latency_track_t  xplh_cdm_flit_latency_tracking;
input pm_cdm_state_trans_track_t     pm_cdm_state_trans_tracking;

input    [NF-1:0]                    msggen_cdm_send_f_err;
input    [NF-1:0]                    msggen_cdm_send_nf_err;
input  flit_err_inj_status_struct    plh_cdm_flit_err_inj_status;  // Flit Error Injection Status
input  cfg_os_einj_status_t          xmlh_tx_os_einj_status;
input              rmlh_prbs_done;               // Finished PBRS Loopback
input              rmlh_prbs_fail;               // PRBS Comparison error occurred
input    [NL-1:0]         rmlh_prbs_started;      // PRBS started status
input    [NL-1:0][7:0] rmlh_prbs_err_cntr;     // PRBS comparison error counter
input    [NL-1:0]         rmlh_prbs_unexp_fail;   // PRBS unexpeced error occurred
// ---------- Outputs --------
output                               cfg_flit_log_trg_evnt_msi;  // Flit Error Counter MSI
output [9:0]                         cfg_flit_perf_interr_vec;    
output [2:0]                         cdm_xplh_flit_response_type;  // Flit Performance response tracking type
output [1:0]                         cdm_xplh_flit_type_measured;  // Flit Performance Flit tracking type
output                               cdm_xplh_flit_track_mode;     // Flit Performance Flit tracking type
output                               cfg_flit_latency_msi;         // Flit Performance flit latency MSI
output [4:0]                         cdm_pm_state_trans_tracker;
output                               cfg_sts_1_ltssm_latency_msi;  // Flit Performance LTSSM MSI
output flit_err_inj_interface_struct cdm_plh_flit_err_inj_interface;  // Flit Error Injection Interface
output cfg_os_einj_ctrl_1_t          cfg_os_einj_ctrl_1;
output cfg_os_einj_ctrl_2_t          cfg_os_einj_ctrl_2;
output  [NF-1:0]        cfg_upd_pme_cap;
output  [(6*NF)-1:0]             cfg_bar_is_io;              // Indicates whether the BAR is set as IO or memory
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_io_match;               // Within IO address range
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_config_above_match;     // configuaration access belongs to the above our customer set address limit so that target1 interface will be the detination of the configuration rd/wr.
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_rom_match;              // Within expansion ROM address range
output  [(6*NF*(FX_TLP-N_TRGT1_INTF))-1:0]      cfg_bar_match;              // Within BAR range
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_mem_match;              // Within Memory range (Type 1 only)
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_prefmem_match;          // Within Prefetchable Memorey range (Type 1 only)
output  logic [NF-1:0][(FX_TLP-N_TRGT1_INTF)-1:0] cfg_cxl_2_0_mbar0_match;    // Within CXL2.0 MBAR0 Memory Range
output  logic         [(FX_TLP-N_TRGT1_INTF)-1:0] cxl_2_0_mbar0_access_match; // Within CXL2.0 MBAR0 Memory Range in CDM
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_cxl_alt_mem_match;      // Within Alternate Memory Range
output  [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]        cfg_cxl_alt_prefmem_match;  // Within Prefetchable Alternate Memory Range
output  [63:12]                                  rcrb_address_reg;           //registering the input RADM Snoop RCRB Base Address in cdm_bar_match
output  [63:0]                                   rcrb_mbar0_base_addr;       // The base address for the RCRB MEMBAR0 region
output  [(FX_TLP-N_TRGT1_INTF)-1:0]              cfg_rcrb_match;             //The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
output  [(FX_TLP-N_TRGT1_INTF)-1:0]              cfg_rcrb_mbar0_match;       //RCRB MEMBAR0 for configuring the CXL subsystem components 
output  [(FX_TLP-N_TRGT1_INTF)-1:0]              cfg_rcrb_mbar0_match_int;       //RCRB MEMBAR0 for configuring the CXL subsystem components in CDM

output [16:0]          mbar0_ras_uncorr_error_mask;           // Uncorrectable Error Status Mask register
output [16:0]          mbar0_ras_uncorr_error_severity;       // Uncorrectable Error Status Severity register
output [6:0]           mbar0_ras_corr_error_mask;             // correctable Error Status Mask register
output                 mbar0_ras_poison_enabled;

output  [1:0]          mbar0_security_device_trust_level;

output  [3:0]          mbar0_arb_mux_cxl_io;
output  [3:0]          mbar0_arb_mux_cxl_cache_mem;
output                 mbar0_arb_mux_pmtimeout_en;
output  [1:0]          mbar0_arb_mux_pmtimeout_val;
input                  mbar0_arb_mux_pmtimeout_err;
input                  mbar0_arb_mux_l0ptimeout_err;

output  [31:0]         mbar0_cap_header_reg;
output  [31:0]         mbar0_ras_cap_header_reg;
output  [31:0]         mbar0_security_cap_header_reg;
output  [31:0]         mbar0_link_cap_header_reg;
output  [6:0]          mbar0_ras_corr_reg;
output  [16:0]         mbar0_ras_uncorr_reg;
output                 cxl_pl_reg_vlsm_to_active;          //Force VLSM to Active State
output                 cxl_pl_reg_vlsm_pm_enable;          //Enables Low Power mode entry.
output                 cxl_pl_reg_apn_bypass_enable;       //Enable APN bypass
output                 cxl_pl_reg_apn_sw_mode;             //Alternate Protocol Negotiation result mode for SW device (0) Based on CXL 2.0 spec (1) Specific negotiation
output  [4:0]          cxl_pl_reg_max_num_retry;           //Maximum number of retry attempts before transitioning to Recovery.
output  [4:0]          cxl_pl_reg_max_num_reinit;          //Maximum number of transitions to recovery before aborting the retry sequence.
output  [15:0]         cxl_pl_reg_lrsm_timeout_threshold;  //Sets the threshold for the retry timeout. This indicates the number of flits which can be transmitted while waiting for a Retry.Ack before a retry timeout occurs
output  [9:0]          cxl_pl_reg_crc_threshold;           //
output  [31:0]         cxl_fatal_error_reg;

output       cxl_pl_reg_cm_ll_cache_poison_injection_start;    // CXL.cache/CXL.mem LinkLayerErrorInjection - Cache Poison Injection Start
output       cxl_pl_reg_cm_ll_mem_poison_injection_start;      // CXL.cache/CXL.mem LinkLayerErrorInjection - Mem Poison Injection Start
output       cxl_pl_reg_cm_ll_io_poison_injection_start;       // CXL.cache/CXL.mem LinkLayerErrorInjection - IO Posion Injection Start
output [1:0] cxl_pl_reg_cm_ll_cache_mem_crc_injection;         // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Start
output [1:0] cxl_pl_reg_cm_ll_cache_mem_crc_injection_count;   // CXL.cache/CXL.mem LinkLayerErrorInjection - CRC Error Injection Count
output       cxl_pl_reg_io_ll_io_poison_injection_start;       // CXL.io LinkLayer Error injection - IO Posion Injection Start
output       cxl_pl_reg_io_ll_flow_ctrl_error_injection;       // CXL.io LinkLayer Error injection - Flow Control Error Injection Start
output       cxl_pl_reg_fb_phy_cor_protid_error_injection;     // Flex Bus LogPHY Error injection - Correctable Protocol ID Error Injection Start
output       cxl_pl_reg_fb_phy_uncor_protid_error_injection;   // Flex Bus LogPHY Error injection - Uncorrectable Protocol ID Error Injection Start
output       cxl_pl_reg_fb_phy_unexp_protid_error_injection;   // Flex Bus LogPHY Error injection - Unexpected Protocol ID Error Injection Start


output  [`CX_L1SUB_CONTROL_WD-1:0] cfg_l1sub_control; // L1 Substates control signal bus
output                  cfg_l1sub_en;               // L1 Substates are enabled, used by app to determine when CLKREQ# can be driven
output  [`CX_PL_L1SUB_CONTROL_WD-1:0] cfg_pl_l1sub_control; //Port Logic L1 Substates Register
output                  cfg_pl_l1_exit_mode;
output                  cfg_pl_l1_nowait_p1;
output                  cfg_pl_l1_clk_sel;
output                  cfg_p2nobeacon_enable;
output                  cfg_pipe_optional_pclkchange_hs;
output                  cfg_phy_perst_on_warm_reset;
output [17:0]           cfg_phy_rst_timer;                                 // PHY rst timer
output [5:0]            cfg_pma_phy_rst_delay_timer;                       // PMA reset to PIPE reset delay timer
output [3:0]            cfg_dsp_pcipm_l1_enter_delay;                      // PCI PM L1 entry delay
output [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;                  // Aux clock frequency
output  [N_FLT_MASK-1:0]cfg_filter_rule_mask;       // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
output                  cfg_fc_wdog_disable;        // disable watch dog timer in FC for some debug purpose

//  To local bus controller
output  [(32*NF)-1:0]   cdm_lbc_data;               // Read data back from core
output  [NF-1:0]        cdm_lbc_ack;                // Acknowledge back from core. Indicates completion, read data is valid


output  [7:0]           cfg_hdr_type;               // CFG space header type
// for type 1 device only
output  [(16*NF)-1:0]   cfg_mem_base;               // device memory base address
output  [(16*NF)-1:0]   cfg_mem_limit;              // memory limit
output  [(64*NF)-1:0]   cfg_pref_mem_base;          // prefetchable memory base address
output  [(64*NF)-1:0]   cfg_pref_mem_limit;         // prefetchable memory limit address
output  [(16*NF)-1:0]   cfg_io_limit_upper16;       // IO Limit Upper 16 Bits
output  [(16*NF)-1:0]   cfg_io_base_upper16;        // IO Base Upper 16 Bits
output  [(8*NF)-1:0]    cfg_io_base;                // IO Base
output  [(8*NF)-1:0]    cfg_io_limit;               // IO Limit

// Power management
output  [(2*NF)-1:0]    cfg_aslk_pmctrl;            // active state PM control
output                  cfg_clk_pm_en;              // Clock PM enable, used to enable the feature that PHY can use to turn off the clock.
// to CX-PL
output  [NF-1:0]        cfg_relax_ord_en;           // relaxed ordering enable
output  [NF-1:0]        cfg_ext_tag_en;             // extended tag field enable
output  [NF-1:0]        cfg_phantom_fun_en;         // Phantom function enable
output  [NF-1:0]        cfg_no_snoop_en;            // No Snoop enable
output  [(3*NF)-1:0]    cfg_max_rd_req_size;        // MAX Read Request Size
output  [NF-1:0]        cfg_bridge_crs_en;          // Bridge Configuration Retry Enable (Bridge only)
output  [NF-1:0]        cfg_rcb;                    // RCB (read completion boundary)
output                  cfg_comm_clk_config;        // common clock configuration
output                  cfg_hw_autowidth_dis;       // HW autonomous width disable
output  [(3*NF)-1:0]    cfg_max_payload_size;       // MTU size
output  [2:0]           cfg_max_payload_size_out_rx;// //In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field .
output  [2:0]           cfg_highest_max_payload;    // highest payload size among all functions
output  [7:0]           cfg_ack_freq;               // (PL) ACK frequency
output  [15:0]          cfg_ack_latency_timer;      // (PL) ACK latency timer
output  [12:0]          cfg_fc_latency_value;       // (PL) FC latency timer
output  [16:0]          cfg_replay_timer_value;     // (PL) Replay timer value
output  [31:0]          cfg_other_msg_payload;      // (PL) Other MSG payload, for test equipment purpose
output                  cfg_other_msg_request;      // (PL) Other MSG request, for test equipment purpose
output  [31:0]          cfg_corrupt_crc_pattern;    // (PL) Corrupted CRC pattern for test purpose
output  [5:0]           cfg_link_capable;           // (PL) Link Capable (x1, x2 ... x32)
output                  cfg_scramble_dis;           // (PL) scrambler disable
output  [7:0]           cfg_n_fts;                  // (PL) Number of Fast training sequence
output                  cfg_link_dis;               // Link disable
output                  cfg_link_retrain;           // Link retrain
output                  cfg_lpbk_en;                // (PL) Loopback enable
output                  cfg_elastic_buffer_mode;    // (PL) elastic buffer mode
output                  cfg_pipe_loopback;          // Local Loopback Enable
output  [5:0]           cfg_rxstatus_lane;          // Lane to inject rxstatus value(bit6 = all lanes)
output  [2:0]           cfg_rxstatus_value;         // rxstatus value to inject
output  [NL-1:0]        cfg_lpbk_rxvalid;           // rxvalid value to use during loopback
output  [7:0]           cfg_link_num;               // (PL) Link number (0 to 255), advertised to link partner
output                  cfg_ts2_lid_deskew;         // do deskew using ts2->Logic_Idle_Data transition
output                  cfg_support_part_lanes_rxei_exit; //Polling.Active -> Polling.Config based on part of pre lanes rxei exit
output                  cfg_plreg_reset;            // (PL) Reset link state machine for test purpose
output  [5:0]           cfg_forced_link_state;      // (PL) a 5-bit register to move the link state to this value indicated
output  [3:0]           cfg_forced_ltssm_cmd;
output                  cfg_force_en;               // (PL) force enable has to be a pulse signal generated from cfg block. When software writes
output  [22:0]          cfg_lane_skew;              // (PL) Transmit lane skew control (optional) for test equipment
output                  cfg_drift_buffer_deskew_enable;// (PL) Drift Buffer deskew enable
output                  cfg_deskew_disable;         // (PL) Deskew disable
output                  cfg_flow_control_disable;   // (PL) disable the automatic flowcontrol
output                  cfg_acknack_disable;        // (PL) disable the automatic ACK/NACK
output  [3:0]           cfg_imp_num_lanes;          // (PL) implementation-specific number of lanes
output                  cfg_dll_lnk_en;             // (PL) DLL Link enable
output                  cfg_soft_rst_n;             // Soft reset (not used)
output  [3:0]           cfg_eidle_timer;            // (PL) eidle timer
output  [10:0]          cfg_skip_interval;          // (PL) skip interval
output  [3:0]           cfg_link_rate;              // link data rate
output  [1:0]           cfg_retimers_pre_detected;  // Retimers present detected {retimer2,retimer1}
output                  cfg_l0s_supported;          // from Link Cap Reg
output                  cfg_fast_link_mode;         // (PL) fast link mode
output  [1:0]           cfg_fast_link_scaling_factor; // (PL) fast link timer scaling factor
output                  cfg_2nd_reset;              // reset the internal side of bus for a bridge device
output  [NF-1:0]        cfg_ecrc_gen_en;            // ECRC Gen enable
output  [NF-1:0]        cfg_ecrc_chk_en;            // ECRC Check enable
output                  cfg_ext_synch;              // Extended synch
output  [31:0]          cfg_phy_control;            // (PL) PHY control register
output  [NF-1:0]        cfg_io_space_en;            // IO address space enable
output  [NF-1:0]        cfg_mem_space_en;           // memory address space enable
output  [(64*NF)-1:0]   cfg_bar0_start;             // BAR0 base address
output  [(64*NF)-1:0]   cfg_bar0_limit;             // BAR0 limit
output  [(64*NF)-1:0]   cfg_bar0_mask;              // BAR0 mask register
output  [(32*NF)-1:0]   cfg_bar1_start;             // BAR1 base address
output  [(32*NF)-1:0]   cfg_bar1_limit;             // BAR1 limit
output  [(32*NF)-1:0]   cfg_bar1_mask;              // BAR1 mask register
output  [(64*NF)-1:0]   cfg_bar2_start;             // BAR2 base address
output  [(64*NF)-1:0]   cfg_bar2_limit;             // BAR2 limit
output  [(64*NF)-1:0]   cfg_bar2_mask;              // BAR2 mask register
output  [(32*NF)-1:0]   cfg_bar3_start;             // BAR3 base address
output  [(32*NF)-1:0]   cfg_bar3_limit;             // BAR3 limit
output  [(32*NF)-1:0]   cfg_bar3_mask;              // BAR3 mask register
output  [(64*NF)-1:0]   cfg_bar4_start;             // BAR4 base address
output  [(64*NF)-1:0]   cfg_bar4_limit;             // BAR4 limit
output  [(64*NF)-1:0]   cfg_bar4_mask;              // BAR4 mask register
output  [(32*NF)-1:0]   cfg_bar5_start;             // BAR5 base address
output  [(32*NF)-1:0]   cfg_bar5_limit;             // BAR5 limit
output  [(32*NF)-1:0]   cfg_bar5_mask;              // BAR5 mask register
output  [(32*NF)-1:0]   cfg_rom_mask;               // ROM BAR mask register
output  [(32*NF)-1:0]   cfg_exp_rom_start;          // Expansion ROM base Address
output  [(32*NF)-1:0]   cfg_exp_rom_limit;          // Expansion ROM limit Address

output  [BUSNUM_WD-1:0] cfg_pbus_num;               // primary Bus number
output  [DEVNUM_WD-1:0] cfg_pbus_dev_num;           // primary device number
output  [7:0]           cfg_2ndbus_num;             // 2nd bus number
output  [7:0]           cfg_subbus_num;             // sub bus number
output                  upstream_port;              // upstream port when set
output                  switch_device;              // switch device when set
output                  end_device;                 // end-point device when set
output                  rc_device;                  // RC device when set
output                  bridge_device;              // bridge device
output  [NF-1:0]        cfg_upd_pmcsr;              // Update PM state (bit 1:0 of PMCSR)
output  [NF-1:0]        cfg_upd_req_id;
output  [NF-1:0]        cfg_aux_pm_en;              // AUX Power PM Enable (Bit 10 of Device control register)
output  [NF-1:0]        cfg_upd_aux_pm_en;          // Update AUX Power PM Enable (Bit 10 of Device control register)
output  [NF-1:0]        cfg_pmstatus_clr;           // Clear PM status (bit 15 of PMCSR)
output  [(3*NF)-1:0]    cfg_pmstate;                // PM state
output  [NF-1:0]        cfg_pme_en;                 // PME enable
output  [(5*NF)-1:0]    cfg_pme_cap;                // PME_support in PM capabilities register
output  [NF-1:0]        cfg_pm_no_soft_rst;         // Indicates no soft reset needed
output  [2:0]           cfg_l0s_entr_latency_timer; // (PL) L0s Entrance Latency
output  [2:0]           cfg_l1_entr_latency_timer;  // (PL) L1 Entrance Latency
output                  cfg_l1_entr_wo_rl0s;        // (PL) Start L1 timer without rL0s
output                  cfg_aspm_l1_timer_enable;   // (PL) Control ASPM L1 Entry Timer
output  [NF-1:0]        cfg_bus_master_en;          // register bus master enable
output  [15:0]          cfg_err_resp;
output                                          cfg_auto_flush_en;
output  [7:0]                                   cfg_auto_flush_timeout;
output                                          cfg_link_timeout_en_n;
output  [`LINK_TIMEOUT_PERIOD_WIDTH-1:0]        cfg_link_timeout_period;
output [1:0]                                    cfg_ax_mstr_ordr_p_event_sel;
output                                          cfg_ax_snp_en;
output [`CX_NVC-1:0]                            cfg_ib_p_id_mng_ctrl;
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
// ATU outbound Region controls
output    [5*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_type;
output    [3*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_tc;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_td;
output    [ATTR_WD*ATU_OUT_NREGIONS_MIN1-1:0]            atu_reg_out_attr;
output    [2*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_at;
output    [PF_WD*ATU_OUT_NREGIONS_MIN1-1:0]              atu_reg_out_func_num;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_func_bypass;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_snp;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_dma_bypass;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_inhibit_payload;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_hdr_substitute_en;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_tag_substitute_en;
output    [TAG_SIZE*ATU_OUT_NREGIONS_MIN1-1:0]           atu_reg_out_tag;
output    [8*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_msg_code;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_th;
output    [2*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_ph;
output    [8*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_st;
// Mode Settings
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_shift;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_invert;
// Region Enable
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_en;
// Base, Limit and Target Registers
output    [ATU_REG_WD*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_base;
output    [ATU_BASE_WD*ATU_OUT_NREGIONS_MIN1-1:0]        atu_reg_out_upr_base;
output    [ATU_REG_WD*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_limit;
output    [ATU_UPR_LMT_WD*ATU_OUT_NREGIONS_MIN1-1:0]     atu_reg_out_uppr_limit;
output    [ATU_REG_WD*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_lwr_trgt;
output    [ATU_BASE_WD*ATU_OUT_NREGIONS_MIN1-1:0]        atu_reg_out_upr_trgt;
output    [ATU_REG_LWR_WD*ATU_OUT_NREGIONS_MIN1-1:0]     atu_reg_out_lwr_trgt_lwr;
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_incr_rgn_size;    // Maximum region size control bit
output    [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_hdr_flds_bypass;  // TLP Header fields bypass control bit

// ATU inbound Region controls
output    [5*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_type;
output    [3*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_tc;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_td;
output    [ATTR_WD*ATU_IN_NREGIONS_MIN1 -1:0]            atu_reg_in_attr;
output    [2*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_at;
output    [PF_WD*ATU_IN_NREGIONS_MIN1 -1:0]              atu_reg_in_func_num;
output    [8*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_msg_code;
output    [3*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_bar_num;
output    [ATU_IN_NREGIONS_MIN1-1:0]                     atu_reg_in_th;
output    [2*ATU_IN_NREGIONS_MIN1-1:0]                   atu_reg_in_ph;
output    [8*ATU_IN_NREGIONS_MIN1-1:0]                   atu_reg_in_st;
// Inbound field match enables
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_tc_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_td_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_attr_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_at_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_func_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_msgcode_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_th_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_ph_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_st_match_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_single_addr_loc_en;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_msg_type_match_mode;
// Response and mode settings
output    [2*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_rsp_code;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_fuzzy;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_shift;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_invert;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_bar_match;
// Region Enable
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_en;
// Base, Limit and Target Registers
output    [ATU_REG_WD*ATU_IN_NREGIONS_MIN1 -1:0]         atu_reg_in_base;
output    [ATU_BASE_WD*ATU_IN_NREGIONS_MIN1 -1:0]        atu_reg_in_upr_base;
output    [ATU_REG_WD*ATU_IN_NREGIONS_MIN1 -1:0]         atu_reg_in_limit;
output    [4*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_cbuf_incr;
output    [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_cbuf_restart;
output    [ATU_UPR_LMT_WD*ATU_IN_NREGIONS_MIN1-1:0]      atu_reg_in_uppr_limit;
output    [ATU_REG_WD*ATU_IN_NREGIONS_MIN1 -1:0]         atu_reg_in_lwr_trgt;
output    [ATU_BASE_WD*ATU_IN_NREGIONS_MIN1 -1:0]        atu_reg_in_upr_trgt;
output    [ATU_IN_NREGIONS_MIN1-1:0]                     atu_reg_in_incr_rgn_size;    // Maximum region size control bit

output  [NF-1:0]        cfg_reg_serren;             // SERR enable bit
output  [NF-1:0]        cfg_cor_err_rpt_en;         // Correctable Error Reporting enable bit
output  [NF-1:0]        cfg_nf_err_rpt_en;          // Non-Fatal Error Reporting enable bit
output  [NF-1:0]        cfg_f_err_rpt_en;           // Fatal Error Reporting enable bit

output  [NF-1:0]        cfg_isa_enable;             // For bridge: ISA enable
output  [NF-1:0]        cfg_vga_enable;             // For bridge: VGA enable (optional)
output  [NF-1:0]        cfg_vga16_decode;           // For bridge: VGA 16-bit decode (optional)
output  [NF-1:0]        cfg_send_cor_err;           // Send a correctable error MSG
output  [NF-1:0]        cfg_send_nf_err;            // Send a non-fatal uncorrectable error MSG
output  [NF-1:0]        cfg_send_f_err;             // Send a fatal uncorrectable error MSG
output  [(3*NF)-1:0]    cfg_func_spec_err;          // Indicate function specific error.  Bit 0 for cor, bit 1 for NF, bit 2 for F
output                  cfg_aer_rc_err_int;         // RC Only: Error interrupt
output                  cfg_aer_rc_err_msi;         // RC Only: Error MSI/MSI-X
output  [4:0]           cfg_aer_int_msg_num;        // RC Only: Advanced Error Interrupt Message Number
output                  cfg_sys_err_rc;             // RC Only: System error
output                  cfg_crs_sw_vis_en;
output                  cfg_pme_int;                // RC Only: Interrupt caused by PME
output                  cfg_pme_msi;                // RC Only: MSI caused by PME
output  [(NF*5)-1:0]    cfg_pcie_cap_int_msg_num;   // Interrupt Message Number
output  [NF-1:0]        cfg_ari_fwd_en;             // ARI Forwarding enable
output  [(NF*4)-1:0]    cfg_cpl_timeout_range;      // Completion timeout range
output  [NF-1:0]        cfg_cpl_timeout_disable;    // Completion timeout disable
output  [8:0]           cfg_lane_en;                // Number of lanes (1-256)
output                  cfg_gen1_ei_inference_mode; // EI inference mode for Gen1. default 0 - using rxelecidle==1; 1 - using rxvalid==0
output  [1:0]           cfg_select_deemph_mux_bus;  // sel deemphasis {bit, var}
output  [`CX_LUT_PL_WD-1:0] cfg_lut_ctrl;           // lane under test + gen5 control
output  [7:0]           cfg_rxstandby_control;      // Rxstandby Control
output                  cfg_link_auto_bw_int;       // Interrupt indicating that Link Bandwidth Management Status bit has been set
output                  cfg_link_auto_bw_msi;       // MSI Interrupt indicating that Link Bandwidth Management Status bit has been set
output                  cfg_bw_mgt_int;             // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
output                  cfg_bw_mgt_msi;             // MSI Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
output  [7:0]           cfg_gen2_n_fts;             // Advertised NFTS# for Gen2 speed
output                  cfg_directed_speed_change;  // Directed higher speed change
output                  cfg_phy_txswing;            // controls mac_phy_txswing signal to the phy
output                  cfg_tx_compliance_rcv;      // Sets the compliance received bit in the TS1
output  [3:0]           cfg_pcie_max_link_speed;    // Max link speed
output  [3:0]           cfg_target_link_speed;      // Target link speed
output                  cfg_enter_compliance;       // Directed enter compliance
output                  cfg_hw_auto_sp_dis;         // HW autonomous speed disable
output                  cfg_sel_de_emphasis;        // level of de emphasis
output  [2:0]           cfg_transmit_margin;        // controls the value of the non-deemphasized voltage level at the Transmitter pins.
output                  cfg_enter_mod_compliance;   // Directed enter modified compliance
output                  cfg_compliance_sos;         // Send skips during compliance
output  [3:0]           cfg_compliance_de_emphasis; // compliance de-emphasis level
output  [(2*NF)-1:0]    cfg_pwr_ind;                // Power indicator command
output  [(2*NF)-1:0]    cfg_atten_ind;              // Attention indicator command
output  [NF-1:0]        cfg_pwr_ctrler_ctrl;        // Power controller control
output  [NF-1:0]        surprise_down_err;
output  [NF-1:0]        cfg_eml_control;            // Electromechanical Interlock Control
output  [NF-1:0]        cfg_slot_pwr_limit_wr;
output  [NF-1:0]        cfg_int_disable;
output  [(3*MSI_NF)-1:0]cfg_multi_msi_en;
output  [MSI_NF-1:0]        cfg_msi_ext_data_en;
output  [MSI_NF-1:0]        cfg_msi_en;
output  [(64*MSI_NF)-1:0]   cfg_msi_addr;
output  [(32*MSI_NF)-1:0]   cfg_msi_data;
output  [MSI_NF-1:0]        cfg_msi_64;
output  [NF-1:0]        cfg_msix_en;
output  [NF-1:0]        cfg_msix_func_mask;


output logic [7:0]       cfg_pwr_budget_data_sel_reg;// Power Budgeting: Data Select register
output       [PB_NF-1:0] cfg_pwr_budget_sel;         // Power Budgeting: Pulse signal indicates new data_sel_reg
output  [7:0]           set_slot_pwr_limit_val;
output  [1:0]           set_slot_pwr_limit_scale;
// VC
output  [(NVC*1)-1:0]   cfg_vc_enable;              // Which VCs are enabled - VC0 is always enabled
output  [(NVC*3)-1:0]   cfg_vc_struc_vc_id_map;     // VC Structure to VC ID mapping
output  [23:0]          cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
output  [7:0]           cfg_tc_enable;              // Which TCs are enabled
output  [23:0]          cfg_tc_vc_map;              // TC to VC ID mapping
output  [23:0]          cfg_tc_struc_vc_map;        // TC to VC Structure mapping
output  [2:0]           cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
output  [2:0]           cfg_vc_arb_sel;             // VC Arbitration Select
output  [63:0]          cfg_lpvc_wrr_weight;        // (PL) WRR weighing per VC ID (8 bits per VC)
output  [PF_WD-1:0]     cfg_max_func_num;           // (PL) Highest accepted function number
output                  cfg_upd_aspm_ctrl;          // ASPM control update
output  [(NF - 1) : 0]  cfg_upd_aslk_pmctrl;        // ASLK pm control
output  [31:0]          cfg_trgt_cpl_lut_delete_entry;  // (PL) trgt_cpl_lut delete one entry
output  [2:0]           cfg_clock_gating_ctrl;      // (PL) Enable/Disable Radm clock gating
output  [(NVC*8)-1:0]   cfg_fc_credit_ph;           // (PL) Flow Control credits - Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_nph;          // (PL) Flow Control credits - Non-Posted Header
output  [(NVC*8)-1:0]   cfg_fc_credit_cplh;         // (PL) Flow Control credits - Completion Header
output  [(NVC*12)-1:0]  cfg_fc_credit_pd;           // (PL) Flow Control credits - Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_npd;          // (PL) Flow Control credits - Non-Posted Data
output  [(NVC*12)-1:0]  cfg_fc_credit_cpld;         // (PL) Flow Control credits - Completion Data
output  [(NVC*9)-1:0]   cfg_radm_q_mode;            // (PL) Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
output  [NVC-1:0]       cfg_radm_order_rule;        // (PL) Order Selection: 0 - Strict Priority, 1 - Complies with Ordering Rule
output  [15:0]          cfg_order_rule_ctrl;        // (PL) cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
output                  cfg_radm_strict_vc_prior;   // (PL) VC Priority: 0 - Round Robin, 1 - Strict Priority
output  [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;  // (PL) Indicates the depth of the header queues per type per vc
output  [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;  // (PL) Indicates the depth of the data queues per type per vc
output                   dl_feature_en;             // Indicates local Data Link Features supported
output                   cfg_remote_feature_ack;    // Indicates remote Data Link Features handshake completed
output  [22:0]           cfg_local_feature_support; // Local Feature (Including local scaled flow control) Support
output                   cfg_dlink_feature_valid;
output  [(NVC*2)-1:0]    hdr_scale_p;               // The HdrScale field contains the scaling factor for headers of the indicated type
output  [(NVC*2)-1:0]    data_scale_p;              // The DataScale field contains the scaling factor for payload data of the indicated type
output  [(NVC*2)-1:0]    hdr_scale_np;              // The HdrScale field contains the scaling factor for headers of the indicated type
output  [(NVC*2)-1:0]    data_scale_np;             // The DataScale field contains the scaling factor for payload data of the indicated type
output  [(NVC*2)-1:0]    hdr_scale_cpl;             // The HdrScale field contains the scaling factor for headers of the indicated type
output  [(NVC*2)-1:0]    data_scale_cpl;            // The DataScale field contains the scaling factor for payload data of the indicated type
output                   fc_scaled_en;
output  [(6*NF)-1:0]    target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #
output  [NF-1:0]        target_rom_map;             // Each bit of this vector indicates which target receives rom    transactions for that bar #
output  [NF-1:0]        cfg_atomic_req_en;          // AtomicOp Requester Enable
output  [NF-1:0]        cfg_atomic_egress_block;    // AtomicOp Egress Blocking enable
output  [NF-1:0]        cfg_dmwr_req_en;            // Deferrable Memory Write (DMWr) Requester Enable
output [6:0]            cfg_tx_arb_control;
input                   smlh_l0p_capable;
output logic            cfg_l0p_receiver_support;   // L0p Receiver Support
output logic            cfg_l0p_enable;             // L0p Enable
output logic            cfg_l0p_autowidth_dis;      // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
output logic            cfg_l0p_priority;           // Port Logic register bit to set L0p.Priority bit in DLLP
output logic  [2:0]     cfg_l0p_linkmode;           // Target Link Width in Device Control 3 Register (bit[6:4])
output logic            cfg_l0p_linkmode_req;       // Link Width change request asserted on the write access to Device Control 3 Register
output logic  [5:0]     cfg_l0p_max_link_width;     // Maximum supported Link Width
output logic  [5:0]     cfg_l0p_neg_link_width;     // Negotiated Link Width
output logic            cfg_pcie_l0p_disable;       // PCIe/CXL.io: Disable dynamic L0p
output logic            cfg_pcie_l0p_request;       // PCIe/CXL.io: L0p Request bit
output logic            cfg_pcie_l0p_priority;      // PCIe/CXL.io: L0p Priority bit
output logic  [2:0]     cfg_pcie_l0p_linkmode;      // PCIe/CXL.io: L0p Target Link Width
output logic            cfg_cxl_l0p_disable;        // CXL.cachemem: Disable dynamic L0p
output logic            cfg_cxl_l0p_request;        // CXL.cachemem: L0p Request bit
output logic            cfg_cxl_l0p_priority;       // CXL.cachemem: L0p Priority bit
output logic  [2:0]     cfg_cxl_l0p_linkmode;       // CXL.cachemem: L0p Target Link Width
output                  cfg_flit_err_inj_latency;
output  [1:0]           cfg_obff_en;                // OBFF method enable. Only applicable for function 0.
output                  cfg_ltr_m_en;               // Function 0 LTR Mechanism Enable bit.
output  [(32*NF)-1:0]   cfg_ltr_max_latency;        // Per function LTR Max Snoop & No-Snoop Latencies
output  [31:0]          app_ltr_latency;            // Transmitted upstream port (Received downstream port) latency tolerance values
output                  cdm2msgg_ltr_clr_msg_req;   // LTR clear message request, any function
output                  cfg_disable_ltr_clr_msg;    // disalbe autonomous LTR clear message generation

output                  inta_wire;                  // virtual legacy wire of interrupt A for message generation purpose
output                  intb_wire;                  // virtual legacy wire of interrupt B for message generation purpose
output                  intc_wire;                  // virtual legacy wire of interrupt C for message generation purpose
output                  intd_wire;                  // virtual legacy wire of interrupt D for message generation purpose

output [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control; // Multi Lane Control Register

output                     cfg_link_eq_req_int;   //interrupt indicating Link EQ Request bit has been set
output [`CX_PL_GEN3_CONTROL_WD-1:0]    cfg_pl_gen3_control;    // Port Logic Gen3 Control Register
output [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control; // Port Logic Gen3 EQ Control Register
output [`CX_DIR_CHANGE_CONTROL_WD-1:0] cfg_fdbk_dirchange_control; //Port Logic EQ Feedback DirectionChange Control Register
output                     cfg_pl_gen3_zrxdc_noncompl;     // Port Logic register bit field indicating non compliance of 2.5 GT/s receiver impedance while in 8GT/s mode.
                                                    // (8 GT/s Receiver Impedance ECN).
output                     cfg_no_seed_value_change;       // No seed value change for Gen3 scrambler after linkup = 1
output                     cfg_perform_eq;        // Directed control to perform equalization
output [NL*TX_PSET_WD-1:0] cfg_lec_pset_ltx;      // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*RX_PSET_WD-1:0] cfg_lec_pset_lrx;      // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output [NL*TX_PSET_WD-1:0] cfg_lec_pset_rtx;      // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*RX_PSET_WD-1:0] cfg_lec_pset_rrx;      // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output                     cfg_ls2_eq_req;        // Link Status2 Request Equalization
output [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen4_control;    // Port Logic Gen3 Control Register
output [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control; // Port Logic Gen3 EQ Control Register
output [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen4_fdbk_dirchange_control; //Port Logic Gen3 EQ Feedback Direction Change Control Register
output [NL*TX_PSET_WD-1:0] cfg_lec_g4_pset_ltx;   // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*RX_PSET_WD-1:0] cfg_lec_g4_pset_lrx;   // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output [NL*TX_PSET_WD-1:0] cfg_lec_g4_pset_rtx;   // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*RX_PSET_WD-1:0] cfg_lec_g4_pset_rrx;   // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output [`CX_PL_GEN5_CONTROL_WD-1:0]    cfg_pl_gen5_control;    // Port Logic Gen3 Control Register
output [`CX_PL_GEN5_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control; // Port Logic Gen3 EQ Control Register
output [`CX_GEN5_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen5_fdbk_dirchange_control; //Port Logic Gen3 EQ Feedback Direction Change Control Register
output                     cfg_bypass_eq_enable;   // Bypass EQ
output                     cfg_no_eq_needed_enable;// no eq needed support
output                     cfg_tx_precode_req;// Transmitted Precode Request
output [NL*TX_PSET_WD-1:0] cfg_lec_g5_pset_ltx;   // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*RX_PSET_WD-1:0] cfg_lec_g5_pset_lrx;   // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output [NL*TX_PSET_WD-1:0] cfg_lec_g5_pset_rtx;   // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*RX_PSET_WD-1:0] cfg_lec_g5_pset_rrx;   // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output [`CX_PL_GEN6_CONTROL_WD-1:0]    cfg_pl_gen6_control;    // Port Logic Gen6 Control Register
output [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control; // Port Logic Gen6 EQ Control Register
output                     cfg_g6_tx_precode_req;// Gen6 Transmitted Precode Request
output [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control; //Port Logic Gen3 EQ Feedback Direction Change Control Register
output [NL*TX_PSET_WD-1:0] cfg_lec_g6_pset_ltx;   // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output [NL*TX_PSET_WD-1:0] cfg_lec_g6_pset_rtx;   // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output  [NL*16-1:0]        cfg_margin_control;    // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
output                     cfg_alt_protocol_enable;// Alternate protocol support
output [(2*NF)-1:0]        cfg_tph_req_en;
output [(3*NF)-1:0]        cfg_pf_tph_st_mode;
output                            crgb_cdm_cs;
output [CRGB_ADDR_WIDTH - 1 : 0 ] crgb_cdm_addr;
output [CRGB_DATA_WIDTH - 1 : 0 ] crgb_cdm_wdata;
output [CRGB_BE_WIDTH   - 1 : 0 ] crgb_cdm_wr;
output                            crgb_cdm_source;
output    [FS_LF_WD-1:0]          cfg_gen3_eq_fs_lf;            // programmable FS and LF for equalization
output    [(11*COEF_WD)-1:0]      cfg_gen3_eq_coef;             // programmable preset to coefficients mapping for equalization
output    [FS_LF_WD-1:0]          cfg_gen4_eq_fs_lf;            // programmable FS and LF for equalization
output    [(11*COEF_WD)-1:0]      cfg_gen4_eq_coef;             // programmable preset to coefficients mapping for equalization
output    [FS_LF_WD-1:0]          cfg_gen5_eq_fs_lf;            // programmable FS and LF for equalization
output    [(11*COEF_WD)-1:0]      cfg_gen5_eq_coef;             // programmable preset to coefficients mapping for equalization
output    [FS_LF_WD-1:0]          cfg_gen6_eq_fs_lf;            // programmable FS and LF for equalization
output    [(11*COEF_WD)-1:0]      cfg_gen6_eq_coef;             // programmable preset to coefficients mapping for equalization
output  [(8*NF)-1:0]    cfg_int_pin;                    // Interrupt Pin mapping
output [NF-1:0]     cfg_end2end_tlp_pfx_blck;    // TLP Prefix of type End-End blocking control bit.
output [(2*NF)-1:0] cfg_max_end2end_tlp_prfxs;   // the maximum number of End-End TLP Prefixes supported; DBI writeable.
output [NF_PASID_CNTRL_WD-1:0] cfg_pf_pasid_control;  // VF PASID control signals bus



output                  default_target;               // Default target if there is any error
output                  ur_ca_mask_4_trgt1;           // Mask the UR CA error is the default target is 1
output                  cfg_cfg_tlp_bypass_en;           //CFG_TLP_BYPASS_EN_REG
output [9:0]            cfg_config_limit;                //CONFIG_LIMIT_REG
output [1:0]            cfg_target_above_config_limit;   //TARGET_ABOVE_CONFIG_LIMIT_REG
output                  cfg_p2p_track_cpl_to;            //P2P_TRACK_CPL_TO_REG
output                  cfg_p2p_err_rpt_ctrl;            //P2P_ERR_RPT_CTRL


output  [5:0]           cfg_margin_num_timing_steps;        // Number of timing steps for lane margining at the receiver
output  [5:0]           cfg_margin_max_timing_offset;       // Maximum number of timing offset for lane margining at the receiver
output  [6:0]           cfg_margin_num_voltage_steps;       // Number of voltage steps for lane margining at the receiver
output  [5:0]           cfg_margin_max_voltage_offset;      // Maximum number of voltage offsets for lane margining at the receiver
output  [5:0]           cfg_margin_sample_rate_voltage;     // Number of sampling rate voltage for lane margining at the receiver
output  [5:0]           cfg_margin_sample_rate_timing;      // Number of sampling rate timing for lane margining at the receiver
output  [4:0]           cfg_margin_maxlanes;                // Maximum number oflane for lane margining at the receiver
output                  cfg_margin_voltage_supported;       // Support of voltage margining for lane margining at the receiver
output                  cfg_margin_ind_up_down_voltage;     // Support of Independent up and down voltage marging for lane margining at the receiver
output                  cfg_margin_ind_left_right_timing;   // Support of Independent left/right margining lane margining at the receiver
output                  cfg_margin_sample_reporting_method; // Support of Sample reporting method for lane margining at the receiver
output                  cfg_margin_ind_error_sampler;       // Support of Independent error sampler for lane margining at the receiver
output  [3:0]           cfg_rx_message_bus_write_buffer_depth; // Rx Message Bus Write Buffer Depth
output                  cfg_pipe_garbage_data_mode;         // PIPE Garbage Data mode
output                  cfg_pam4_restricted_levels_requirement; // PAM4 Restricted Levels Requirement

output [NF-1:0]         cfg_drs_msi;
output [NF-1:0]         cfg_up_drs_to_frs;


output                  frsq_msi;        
output [4:0]            frsq_int_msg_num;
output [RASDES_EC_INFO_CM-1:0]     cdm_ras_des_ec_info_common;         // Event counter common debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l0;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l1;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l2;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l3;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l4;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l5;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l6;             // Event counter lane0 debug info
output [RASDES_EC_INFO_PL-1:0]     cdm_ras_des_ec_info_l7;             // Event counter lane0 debug info
input                              app_ras_des_sd_hold_ltssm;          // Silicon debug hold ltssm signal
output [RASDES_SD_INFO_CM-1:0]     cdm_ras_des_sd_info_common;         // Silicon debug common debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l0;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l1;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l2;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l3;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l4;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l5;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l6;             // Silicon debug lane0 debug info
output [RASDES_SD_INFO_PL-1:0]     cdm_ras_des_sd_info_l7;             // Silicon debug lane0 debug info
output  [RASDES_SD_INFO_PV-1:0]    cdm_ras_des_sd_info_v0;             // Silicon debug vc0 debug info
output  [RASDES_TBA_INFO_CM-1:0]   cdm_ras_des_tba_info_common;        // Time based analysis common debug info
output                                cdm_ras_des_ec_ram_ena;          // RAS DES event counter register RAM enable A
output                                cdm_ras_des_ec_ram_wea;          // RAS DES event counter register RAM write enable B
output [RASDES_EC_RAM_ADDR_WIDTH-1:0] cdm_ras_des_ec_ram_addra;        // RAS DES event counter register RAM address A
output [RASDES_EC_RAM_DATA_WIDTH-1:0] cdm_ras_des_ec_ram_datain;       // RAS DES event counter register RAM data in
output                                cdm_ras_des_ec_ram_enb;          // RAS DES event counter register RAM enable B
output [RASDES_EC_RAM_ADDR_WIDTH-1:0] cdm_ras_des_ec_ram_addrb;        // RAS DES event counter register RAM address B
output                                cdm_ras_des_tba_ram_ena;         // RAS DES time based analysis register RAM enable A
output                                cdm_ras_des_tba_ram_wea;         // RAS DES time based analysis register RAM write enable B
output [RASDES_TBA_RAM_ADDR_WIDTH-1:0] cdm_ras_des_tba_ram_addra;      // RAS DES time based analysis register RAM address A
output [RASDES_TBA_RAM_DATA_WIDTH-1:0] cdm_ras_des_tba_ram_datain;     // RAS DES time based analysis register RAM data in
output                                cdm_ras_des_tba_ram_enb;         // RAS DES time based analysis register RAM enable B
output [RASDES_TBA_RAM_ADDR_WIDTH-1:0] cdm_ras_des_tba_ram_addrb;      // RAS DES time based analysis register RAM address B
output [1:0]                       cdm_ras_des_pm_entry_interval;      // Low Power Entry Interval Time for Ras D.E.S Silicon Debug
output [1:0]                       cdm_ras_des_eidle_cnt_sel;          // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
output                             cdm_ras_des_ltssm_stop;             // Hold/Release LTSSM for Ras D.E.S Silicon Debug
output                             cdm_ras_des_recovery_req;           // Recovery Request for Ras D.E.S Silicon Debug
output                             cdm_ras_des_ferr_rec_dis;           // Disable Recovery state transition at Framing Error for Ras D.E.S Silicon Debug
output                             cdm_ras_des_direct_rcvry_idle_to_cfg; // Direct LTSSM from Recovery.Idle to Configuration for Ras D.E.S Silicon Debug
output                             cdm_ras_des_direct_poll_cmp_to_det; // Direct LTSSM from Polling.Compliance to Detect for Ras D.E.S Silicon Debug
output                             cdm_ras_des_direct_lpbk_slave_to_exit; // Direct LTSSM from Loopback(Slave) to Exit for Ras D.E.S Silicon Debug
output                             cdm_ras_des_force_rxdetected_en;    // Force Detect Lane Num enable for Ras D.E.S Silicon Debug
output [15:0]                      cdm_ras_des_force_rxdetected;       // Force Detect Lane Num for Ras D.E.S Silicon Debug
output                             cdm_ras_des_force_linkdown_noack;   // Force Link down when MAC does not receive ACK DLLP for long time
output [1:0]                       cdm_ras_des_ext_eq_to_factor;       // Extend the eq 24/32ms timeout x2/x10
output                             cdm_ras_des_eq_fom_target_en;       // FOM target enable for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en;   // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_pset_lrx_en;   // Force Local Rx Preset Hint Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en;   // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx;      // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL*RX_PSET_WD-1:0]         cdm_ras_des_eq_force_pset_lrx;      // Force Local Receiver Preset Hint for Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx;      // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en;   // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx;  // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en_g4; // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en_g4; // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g4;   // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g4;   // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en_g4; // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx_g4; // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en_g5; // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en_g5; // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g5;   // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g5;   // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en_g5; // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx_g5; // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_rtx_en_g6; // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_coef_ltx_en_g6; // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_ltx_g6;    // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_COEF_WD-1:0]         cdm_ras_des_eq_force_coef_rtx_g6;    // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
output [NL-1:0]                    cdm_ras_des_eq_force_pset_ltx_en_g6; // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
output [NL*TX_PSET_WD-1:0]         cdm_ras_des_eq_force_usp_pset_ltx_g6; // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
output [FOMFEEDBACK_WD-1:0]        cdm_ras_des_eq_fom_target;          // FOM Target value for Ras D.E.S Silicon Debug EQ Control
output [1:0]                       cdm_ras_des_eq_eval_interval;       // EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
  
output                             cdm_ras_des_einj0_enable;           // Error injection 0 enable
output [7:0]                       cdm_ras_des_einj0_count;            // Error injection 0 count
output [3:0]                       cdm_ras_des_einj0_crc_type;         // Error injection 0 CRC type
output [2:0]                       cdm_ras_des_einj0_ecrc_vc_sel;      // Error injection 0 ECRC Virtual Channel Selection
output fc_type_e                   cdm_ras_des_einj0_ecrc_fc_sel;      // Error injection 0 ECRC Flow Control Selection
output logic                       cdm_ras_des_einj0_ecrc_intf_sel;    // Error injection 0 ECRC Interface Selection
output                             cdm_ras_des_einj1_enable ;          // Error injection 1 enable
output                             cdm_ras_des_einj1_seq_type ;        // Error injection 1 seq# type
output [12:0]                      cdm_ras_des_einj1_bad_seq ;         // Error injection 1 bad seq# value
output [7:0]                       cdm_ras_des_einj1_count ;           // Error injection 1 count
output                             cdm_ras_des_einj2_enable;           // Error injection 2 enable
output [1:0]                       cdm_ras_des_einj2_dllp_type;        // Error injection 2 DLLP type
output                             cdm_ras_des_einj3_enable;           // Error injection 3 8b/10b K-code mask enable
output [7:0]                       cdm_ras_des_einj3_count;            // Error injection 3 8b/10b K-code mask count
output [2:0]                       cdm_ras_des_einj3_smb_type;         // Error injection 3 8b/10b K-code mask type
output                             cdm_ras_des_einj4_enable;           // Error injection 4 enable
output [2:0]                       cdm_ras_des_einj4_updfc_type;       // Error injection 4 UpdateFC type
output [2:0]                       cdm_ras_des_einj4_vcnum;            // Error injection 4 VC number
output [12:0]                      cdm_ras_des_einj4_badfc_value;      // Error injection 4 bad FC value
output                             cdm_ras_des_einj5_enable ;          // Error injection 5 enable
output [7:0]                       cdm_ras_des_einj5_count ;           // Error injection 5 count
output                             cdm_ras_des_einj5_tlp_type ;        // Error injection 5 tlp type (dup/nul)
output                             cdm_ras_des_einj6_enable;           // Error Injection 6 Enable
output [31:0]                      cdm_ras_des_einj6_cmp_point_h0;     // Error Injection 6 header compare point byte0-3
output [31:0]                      cdm_ras_des_einj6_cmp_point_h1;     // Error Injection 6 header compare point byte4-7
output [31:0]                      cdm_ras_des_einj6_cmp_point_h2;     // Error Injection 6 header compare point byte8-11
output [31:0]                      cdm_ras_des_einj6_cmp_point_h3;     // Error Injection 6 header compare point byte12-15
output [31:0]                      cdm_ras_des_einj6_cmp_value_h0;     // Error Injection 6 header compare value byte0-3
output [31:0]                      cdm_ras_des_einj6_cmp_value_h1;     // Error Injection 6 header compare value byte4-7
output [31:0]                      cdm_ras_des_einj6_cmp_value_h2;     // Error Injection 6 header compare value byte8-11
output [31:0]                      cdm_ras_des_einj6_cmp_value_h3;     // Error Injection 6 header compare value byte12-15
output [31:0]                      cdm_ras_des_einj6_chg_point_h0;     // Error Injection 6 header change point byte0-3
output [31:0]                      cdm_ras_des_einj6_chg_point_h1;     // Error Injection 6 header change point byte4-7
output [31:0]                      cdm_ras_des_einj6_chg_point_h2;     // Error Injection 6 header change point byte8-11
output [31:0]                      cdm_ras_des_einj6_chg_point_h3;     // Error Injection 6 header change point byte12-15
output [31:0]                      cdm_ras_des_einj6_chg_value_h0;     // Error Injection 6 header change value byte0-3
output [31:0]                      cdm_ras_des_einj6_chg_value_h1;     // Error Injection 6 header change value byte4-7
output [31:0]                      cdm_ras_des_einj6_chg_value_h2;     // Error Injection 6 header change value byte8-11
output [31:0]                      cdm_ras_des_einj6_chg_value_h3;     // Error Injection 6 header change value byte12-15
output [7:0]                       cdm_ras_des_einj6_count;            // Error Injection 6 count
output                             cdm_ras_des_einj6_invt_cont;        // Error Injection 6 inversion control
output [2:0]                       cdm_ras_des_einj6_pkt_type;         // Error Injection 6 packet type
output                        rasdp_linkdown;              // causes link down upon RASDP uncorrectable error detection - only if enabled
output                        cfg_rasdp_linkdown_en;       // Enable Link Down on RASDP uncorrectable error
output                        cfg_rasdp_error_mode_en;
output                        cfg_rasdp_error_mode;

output [2:0]                  cfg_optional_ohc;

output                  ptm_res_msg;
output                  ptm_res_d_msg;
output [63:0]           ptm_master_time;
output [31:0]           ptm_prop_delay;
output                  ptm_request_msg;
output                  cfg_ptm_enable;
output                  ptm_context_valid;            //top level output
output                  ptm_responder_rdy_to_validate;            //top level output
output [63:0]           ptm_local_clock;
output                  ptm_clock_updated;
output [63:0]           ptm_clock_correction;
output                  ptm_trigger_allowed;       // when system is not in the middle of an update a manual request may be made
output                  ptm_updating;              //PTM Update is in progress
output                  ptm_req_response_timeout;  //Pulse indicating PTM Request sent but no response after 100us
output                  ptm_req_dup_rx;            //Pulse indicating Duplicate TLP received during PTM update process or response received during wait for next update
output                  ptm_req_replay_tx;         //Pulse indicating Replay TLP sent during PTM update process or Request sent during wait for next update

wire   [31:0]           ptm_vsec_reg_data;
wire   [31:0]           ptm_reg_data;
wire   [(NPTMVSEC*NF)-1:0]    ptm_vsec_reg_id;
reg    [NPTMVSEC-1:0]   int_ptm_vsec_reg_id;
reg    [NPTM-1:0]       ptm_reg_id;
reg    [3:0]            int_ptm_vsec_write_pulse;
wire   [3:0]            int_ptm_write_pulse;
wire                    cfg_ptm_responder_capable;
wire                    cfg_ptm_root_select;








wire   [6*NF-1:0]          vsecdma_reg_id;
wire   [NF-1:0]            vsecdma_reg_sel;
wire   [31:0]              vsecdma_reg_data;







localparam                      NDEV3_REGS = `DEV3_SIZE>>2 ; // Number of registers in Device 3 Extended Capability Structure
wire   [NDEV3_REGS*NF-1:0]      dev3_reg_id;                 // DEV3 register ID
wire   [(32*NF)-1:0]            dev3_reg_data;               // DEV3 register read data

output   [(5*NF)-1:0]   cfg_ats_stu;
output   [NF-1:0]       cfg_ats_cache_en;

output                  cfg_acs_validation_cap;
output                  cfg_acs_at_blocking_cap;
output                  cfg_acs_up_forward_cap;
output                  cfg_acs_validation_en;
output                  cfg_acs_at_blocking_en;
output                  cfg_acs_up_forward_en;
output   [NF-1:0]       cfg_acs_p2p_req_redirect_en;
output   [NF-1:0]       cfg_acs_p2p_compl_redirect_en;
output   [NF-1:0]       cfg_acs_p2p_egress_ctrl_en;
output   [NF-1:0]       cfg_acs_p2p_direct_transl_en;
output   [(ACS_CTRL_VEC_WD*NF)-1:0]  cfg_acs_egress_ctrl_vec;

output [NF-1:0]         cfg_10b_tag_req_en;

output   [NF-1:0]       cfg_prs_enable;
output   [NF-1:0]       cfg_prs_reset;
output   [NF-1:0]       cfg_prs_stopped;
output   [NF-1:0]       cfg_prs_uprgi;
output   [NF-1:0]       cfg_prs_response_failure;
output   [(32*NF)-1:0]  cfg_prs_outstanding_allocation;

output                  cfg_nond0_vdm_block;
output                  cfg_client0_block_new_tlp;
output                  cfg_client1_block_new_tlp;
output                  cfg_client2_block_new_tlp;

output [NF-1:0]        cfg_br_ctrl_serren;

output   [NF-1:0]       cdm_hp_pme;
output   [NF-1:0]       cdm_hp_int;
output   [NF-1:0]       cdm_hp_msi;
wire     [NF-1:0]       cdm_hp_pme;
wire     [NF-1:0]       cdm_hp_int;
wire     [NF-1:0]       cdm_hp_msi;

output   [NF-1:0] cfg_auto_slot_pwr_lmt_dis;    // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.
output   [NF-1:0] cfg_hp_slot_ctrl_access;
output   [NF-1:0] cfg_dll_state_chged_en;
output   [NF-1:0] cfg_cmd_cpled_int_en;
output   [NF-1:0] cfg_pre_det_chged_en;
output   [NF-1:0] cfg_mrl_sensor_chged_en;
output   [NF-1:0] cfg_pwr_fault_det_en;
output   [NF-1:0] cfg_atten_button_pressed_en;
output   [NF-1:0] cfg_hp_int_en;



output                  cdm_dpc_triggered;                    // DPC has been triggered indication
output                  cdm_aer_dpc_triggered;                // DPC has been triggered by AER uncorrectable error indication
output                  cdm_core_in_dpc;                      // Core is in Downstream Port Containment mode.
output                  dpc_fatal_err_gate;                   // DPC trigger gating for fatal error message
output                  dpc_nonfatal_err_gate;                // DPC trigger gating for non-fatal error message
// Downstream Port Containment Capability outputs.
output [4:0]            cfg_dpc_int_msg_num;                  // DPC Interrupt Message Number
output                  cfg_dpc_rp_ext_dpc;                   // DPC Root Port Extensions for DPC
output                  cfg_dpc_poison_tlp_egr_blk_support;   // DPC Poisoned TLP Egress Blocking Supported
output                  cfg_dpc_sw_trig_support;              // DPC Software Triggering Supported
output [3:0]            cfg_dpc_rp_pio_log_size;              // DPC RP PIO Log Size
output                  cfg_dpc_dl_active_err_cor_support;    // DPC DL_Active ERR_COR Signaling Supported
output [1:0]            cfg_dpc_trig_en;                      // DPC Trigger Enable
output                  cfg_dpc_cpl_cntrl;                    // DPC Completion Control
output                  cfg_dpc_int_en;                       // DPC Interrupt Enable
output                  dpc_int;                              // DPC Interrupt for INTx
output                  dpc_msi;                              // DPC Interrupt for MSI
output                  cfg_dpc_err_cor_en;                   // DPC ERR_COR Enable
output                  cfg_dpc_poison_tlp_egr_block_en;      // Poisoned TLP Egress Blocking Enable
output                  cfg_dpc_sw_trigger;                   // DPC Software Trigger
output                  cfg_dpc_dl_active_err_cor_en;         // DL_Active ERR_COR Enable


wire     [NF-1:0]       cfg_atten_button_pressed;
wire     [NF-1:0]       cfg_pwr_fault_det;
wire     [NF-1:0]       cfg_mrl_sensor_chged;
wire     [NF-1:0]       cfg_pre_det_chged;
wire     [NF-1:0]       cfg_cmd_cpled_int;
wire     [NF-1:0]       cfg_dll_state_chged;


input [(2 * PWDN_WIDTH) - 1 : 0]             pm_powerdown_status; // powerdown status
output                                       cfg_force_powerdown; // debug bit to force completion of powerdown transition

input [NF-1:0]              exp_rom_validation_status_strobe;
input [NF*3-1:0]            exp_rom_validation_status;
input [NF-1:0]              exp_rom_validation_details_strobe;
input [NF*4-1:0]            exp_rom_validation_details;
input                       flit_mode_enable;
output                      cfg_tx_throttling;            // Tx Throttling Control Bit

input [8:0]                 app_segment_id;
input [8:0]                 radm_np_segment_id;
output logic [8:0]          cfg_segment_id;

output                      cfg_pcie_slot_clk_config;
output                      cfg_uncor_internal_err_sts;
output                      cfg_rcvr_overflow_err_sts;
output                      cfg_fc_protocol_err_sts;
output                      cfg_mlf_tlp_err_sts;
output                      cfg_surprise_down_er_sts;
output                      cfg_dl_protocol_err_sts;
output                      cfg_ecrc_err_sts;
output                      cfg_corrected_internal_err_sts;
output                      cfg_replay_number_rollover_err_sts;
output                      cfg_replay_timer_timeout_err_sts;
output                      cfg_bad_dllp_err_sts;
output                      cfg_bad_tlp_err_sts;
output                      cfg_rcvr_err_sts;
output [NF-1:0]             cfg_advisory_nf_sts;
output [NF-1:0]             cfg_hdr_log_overflow_sts;     // Header Log Overflow Status ,found in Correctable Error Status Register
output wire [31:0]          cfg_utility;
input  wire [31:0]          pm_cfg_utility;
output [2:0]                cfg_dbi_func_bank_select;
output                      cfg_pcie_cap_flit_mode_sup;    
output                      cfg_flit_mode_dis;    
output                      cfg_pcie_cap_flit_mode_stat;    
output                      cfg_flit_sris_clocking;    


output reg [5:0]              cfg_neg_link_width;

output                      dbi_ro_wr_en;
output logic       cfg_prbs_en;                 // PRBS Loopback Enable. Need to be set before being set cfg_lpbk_en
output logic       clear_prbs_done;             // Clear PRBS Status regisers
output logic [3:0] cfg_prbs_lane_sel;           // PRBS lane select for status registers
// -----------------------------------------------------------------------------
// Signal declaration
// -----------------------------------------------------------------------------
wire  [(8*NF)-1:0]    int_cfg_2ndbus_num;             // 2nd bus number
wire  [(8*NF)-1:0]    int_cfg_subbus_num;             // sub bus number

wire                    cfg_err_inj_wr_disable ;
wire [(NF*6) -1 : 0]    cfg_int_link_width;
wire                    cfg_pcie_slot_clk_config_i[NF-1:0];
wire                    cfg_rcrb_pcie_slot_clk_config;
wire                    cfg_pcie_slot_clk_config = cxl_rcrb_enable ? cfg_rcrb_pcie_slot_clk_config : cfg_pcie_slot_clk_config_i[0];

// LBC
//
wire                    dbi_ro_wr_en;
wire                    default_target;
wire                    ur_ca_mask_4_trgt1;
wire                    cfg_cfg_tlp_bypass_en;
wire [9:0]              cfg_config_limit;
wire [1:0]              cfg_target_above_config_limit;
wire                    cfg_p2p_track_cpl_to;
wire                    cfg_p2p_err_rpt_ctrl;
wire                    cfg_ras_reg_pf0_only;
wire                    cfg_rasdes_reg_pf0_only;
wire                    pl_reg_ack;
wire    [NF-1:0]        cfg_reg_ack;
wire    [NF-1:0]        cfg_cap_reg_ack;
wire    [NF-1:0]        ecfg_reg_ack;
wire                    pl_reg_sel;
wire                    atu_reg_sel;
wire    [NF-1:0]        cfg_reg_sel;
wire    [NF-1:0]        cfg_cap_reg_sel;
wire    [NF-1:0]        ecfg_reg_sel;
wire    [31:0]          cdm_pf_ecfg_addr;
wire    [((32*NF)-1):0] err_reg_data;
localparam ERR_REG_ID_WD = 




  1? 19: 18;
wire    [((ERR_REG_ID_WD*NF)-1):0] err_reg_id;
wire    [NF-1:0][3:0]   ecfg_write_pulse;
wire    [31:0]          pl_reg_data;
wire    [((32*NF)-1):0] cfg_reg_data;
wire    [((32*NF)-1):0] cfg_cap_reg_data;
wire    [((32*NF)-1):0] ecfg_reg_data;
// Misc
wire    [NF-1:0]        int_cfg_2nd_reset;
wire    [(8*NF)-1:0]    int_cfg_hdr_type;
wire    [(4*NF)-1:0]    int_cfg_link_rate;
wire    [(2*NF)-1:0]    int_cfg_retimers_pre_detected;
wire    [(2*NF)-1:0]    cfg_pwr_ind;
wire    [(2*NF)-1:0]    cfg_atten_ind;
wire    [(10*NF)-1:0]   cfg_pcie_slot_pwr_limit;
wire    [7:0]           set_slot_pwr_limit_val;
assign set_slot_pwr_limit_val      = cfg_pcie_slot_pwr_limit[7:0];
wire    [1:0]           set_slot_pwr_limit_scale;
assign set_slot_pwr_limit_scale    = cfg_pcie_slot_pwr_limit[9:8];
wire    [NF-1:0]        cfg_slot_pwr_limit_wr;
wire                    cfg_link_retrain;
wire                    cfg_tx_reverse_lanes;
wire    [(8*NF)-1:0]    cfg_int_pin;                    // Interrupt Pin mapping
wire                    cfg_clk_pm_en;
wire    [NF-1:0]        int_cfg_clk_pm_en;
wire    [NF-1:0]        cfg_eml_control;
wire    [NF-1:0]        sys_eml_interlock_engaged;
// Function 0 Only Signals
wire    [NF-1:0]        int_cfg_sys_err_rc;             // RC Only: System error
wire    [NF-1:0]        int_cfg_pme_int;                // RC Only: Interrupt caused by PME
wire    [NF-1:0]        int_cfg_pme_msi;                // RC Only: MSI caused by PME
wire    [NF-1:0]        int_cfg_crs_sw_vis_en;
wire    [NF-1:0]        int_cfg_link_auto_bw_int;       // Interrupt indicating that Link Bandwidth Management Status bit has been set
wire    [NF-1:0]        int_cfg_link_auto_bw_msi;       // MSI Interrupt indicating that Link Bandwidth Management Status bit has been set
wire    [NF-1:0]        int_cfg_bw_mgt_int;             // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
wire    [NF-1:0]        int_cfg_bw_mgt_msi;             // MSI Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
wire    [(NF*4)-1:0]    int_cfg_target_link_speed;      // Target link speed
wire    [NF-1:0]        int_cfg_enter_compliance;       // Directed enter compliance
wire    [NF-1:0]        int_cfg_hw_auto_sp_dis;         // HW autonomous speed disable
wire    [NF-1:0]        int_cfg_sel_de_emphasis;        // level of de emphasis
wire    [(NF*3)-1:0]    int_cfg_transmit_margin;        // controls the value of the non-deemphasized voltage level at the Transmitter pins.
wire    [NF-1:0]        int_cfg_enter_mod_compliance;   // Directed enter modified compliance
wire    [NF-1:0]        int_cfg_compliance_sos;         // Send skips during compliance
wire    [(NF*4)-1:0]    int_cfg_compliance_de_emphasis; // compliance de-emphasis level
wire    [NF-1:0]        int_cfg_ls2_eq_req;             // Link Status2 Request Equalization
wire    [NF-1:0]        int_cfg_pcie_crosslink_supported; // Crosslink Supported
wire                    int_cfg_ls2_g4_eq_req;
wire                    int_cfg_ls2_g5_eq_req;          // Link Status2 Request Equalization
wire                    int_cfg_ls2_g6_eq_req;          // Link Status2 Request Equalization
wire    [(NF*NVC*1)-1:0] int_cfg_vc_enable;             // Which VCs are enabled - VC0 is always enabled
wire    [(NF*NVC*3)-1:0] int_cfg_vc_struc_vc_id_map;    // VC Structure to VC ID mapping
wire    [(NF*24)-1:0]   int_cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
wire    [(NF*8)-1:0]    int_cfg_tc_enable;              // Which TCs are enabled
wire    [(NF*24)-1:0]   int_cfg_tc_vc_map;              // TC to VC ID mapping
wire    [(NF*3)-1:0]    int_cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
wire    [(NF*24)-1:0]   int_cfg_tc_struc_vc_map;        // TC to VC Structure mapping
wire    [(NF*3)-1:0]    int_cfg_vc_arb_sel;             // VC Arbitration Select
wire    [(NF*3)-1:0]    int_cfg_func_spec_err;          // Indicate function specific error.  Bit 0 for cor, bit 1 for NF, bit 2 for F
wire    [NF-1:0]        int_cfg_aer_rc_err_int;         // RC Only: Error interrupt
wire    [NF-1:0]        int_cfg_aer_rc_err_msi;         // RC Only: Error MSI/MSI-X
wire    [(NF*5)-1:0]    int_cfg_aer_int_msg_num;    // Advanced Error Interrupt Message Number
// VC
wire    [(NVC*1)-1:0]   cfg_vc_enable;                    // Which VCs are enabled - VC0 is always enabled
wire    [(NVC*3)-1:0]   cfg_vc_struc_vc_id_map;           // VC Structure to VC ID mapping
wire    [23:0]          cfg_vc_id_vc_struc_map;           // VC ID to VC Structure mapping
wire    [7:0]           cfg_tc_enable;                    // Which TCs are enabled
wire    [23:0]          cfg_tc_vc_map;                    // TC to VC ID mapping
wire    [23:0]          cfg_tc_vc_map_bcm36;              // TC to VC ID mapping
wire    [2:0]           cfg_lpvc;                         // Low Priority Extended VC (LPVC) Count
wire    [23:0]          cfg_tc_struc_vc_map;              // TC to VC Structure mapping
wire    [23:0]          cfg_tc_struc_vc_map_bcm36;        // TC to VC Structure mapping
wire    [2:0]           cfg_vc_arb_sel;                   // VC Arbitration Select
wire    [63:0]          cfg_lpvc_wrr_weight;              // WRR weighing per VC (8 bits per VC)
// MSI: generate Memory write for hotplug INT MSI inside ADM
wire    [(3*MSI_NF)-1:0]    cfg_multi_msi_en;
wire    [MSI_NF-1:0]        cfg_msi_en;                     // system software enabled MSI
wire    [(64*MSI_NF)-1:0]   cfg_msi_addr;
wire    [(32*MSI_NF)-1:0]   cfg_msi_data;
//MSI signal for all PF
wire  [(3*NF)-1:0]    cfg_multi_msi_en_int;
wire  [NF-1:0]        cfg_msi_ext_data_en_int;
wire  [NF-1:0]        cfg_msi_en_int;
wire  [(64*NF)-1:0]   cfg_msi_addr_int;
wire  [(32*NF)-1:0]   cfg_msi_data_int;
wire  [NF-1:0]        cfg_msi_64_int;
generate
if (MSI_NF == 1 && NF>1) begin
  assign cfg_multi_msi_en        = cfg_multi_msi_en_int[2:0];
  assign cfg_msi_ext_data_en     = cfg_msi_ext_data_en_int[0];
  assign cfg_msi_en              = cfg_msi_en_int[0];
  assign cfg_msi_addr            = cfg_msi_addr_int[63:0];
  assign cfg_msi_data            = cfg_msi_data_int[31:0];
  assign cfg_msi_64              = cfg_msi_64_int[0];
end else begin
  assign cfg_multi_msi_en        = cfg_multi_msi_en_int;
  assign cfg_msi_ext_data_en     = cfg_msi_ext_data_en_int;
  assign cfg_msi_en              = cfg_msi_en_int;
  assign cfg_msi_addr            = cfg_msi_addr_int;
  assign cfg_msi_data            = cfg_msi_data_int;
  assign cfg_msi_64              = cfg_msi_64_int;
end
endgenerate



// MSI-X
wire    [NF-1:0]        cfg_msix_en;
wire    [NF-1:0]        cfg_msix_func_mask;
wire    [(11*NF)-1:0]   cfg_msix_table_size;
wire    [(11*NF)-1:0]   cfg_msix_table_size2;
wire    [(3*NF)-1:0]    cfg_msix_table_bir;
wire    [(3*NF)-1:0]    cfg_msix_table_bir2;
wire    [(29*NF)-1:0]   cfg_msix_table_offset;
wire    [(29*NF)-1:0]   cfg_msix_table_offset2;
wire    [(3*NF)-1:0]    cfg_msix_pba_bir;
wire    [(3*NF)-1:0]    cfg_msix_pba_bir2;
wire    [(29*NF)-1:0]   cfg_msix_pba_offset;
wire    [(29*NF)-1:0]   cfg_msix_pba_offset2;
// VPD
wire    [NF-1:0]        int_cfg_vpd_int;



// Power Budgeting
wire    [31:0]          cfg_pwr_budget_data_reg;
wire    [PF_WD-1:0]     cfg_pwr_budget_func_num;
wire    [(8*NF)-1:0]    int_cfg_pwr_budget_data_sel_reg;
wire    [NF-1:0]        int_cfg_pwr_budget_sel;
wire    [NF-1:0]        ras_reg_sel;
localparam NR_RAS_REGS     = 25;                            // Number of registers (4 bytes)

wire    [(NR_RAS_REGS*NF)-1:0]   ras_reg_id;
wire                    ras_reg_ack;
wire    [31:0]          ras_reg_data;
wire                    rasdp_int_uncorr_error;
wire                    rasdp_int_corr_error;

wire                          or_rasdp_err_uncorr;          // OR all bits in rasdp_err_uncorr, for safety interrupt signaling
wire                          or_rasdp_err_corr;            // OR all bits in rasdp_err_corr, for safety interrupt signaling
wire                    ras_error_mode_en;
wire                    cfg_rasdp_linkdown_en;
wire                    ras_error_mode_clear;
wire [NF-1:0][FX_TLP_ADR_DEC-1:0]        cfg_cxl_2_0_mbar0_match_int;          // Within CXL2.0 MBAR0 Memory Range (internal)
wire [NF-1:0][FX_TLP_ADR_DEC-1:0]        cxl_2_0_mbar0_access_int;             // Within CXL2.0 MBAR0 Memory Range in CDM

always_comb begin
  cfg_cxl_2_0_mbar0_match    = '0;
  cfg_cxl_2_0_mbar0_match[0] = cfg_cxl_2_0_mbar0_match_int[0];
  cxl_2_0_mbar0_access_match = cxl_2_0_mbar0_access_int[0];
end
// ------------------------------------------------------------
// Wire declaration for u_cdm_rcrb_ecfg_reg
// ------------------------------------------------------------
// Secondary PCI Express Extended Capability
wire    [NSPCIE-1:0]    rcrb_spcie_reg_id;
wire    [31:0]          rcrb_spcie_reg_data;
// Physical Layer 16 GT/s Extended Capability.
wire    [NPL16G-1:0]    rcrb_pl16g_reg_id;
wire    [31:0]          rcrb_pl16g_reg_data;
// Margining Extended Capability.
wire    [NMARGIN-1:0] rcrb_margin_reg_id;
wire    [31:0]           rcrb_margin_reg_data;
// Physical Layer 32 GT/s Extended Capability.
wire    [NPL32G-1:0] rcrb_pl32g_reg_id;
wire    [31:0]          rcrb_pl32g_reg_data;
// Physical Layer 32 GT/s Extended Capability.
wire    [NPL64G-1:0] rcrb_pl64g_reg_id;
wire    [31:0]          rcrb_pl64g_reg_data;

wire                    rcrb_rasdes_reg_sel;                // RAS DES register select
wire   [63:0]          rcrb_rasdes_reg_id;                 // RAS DES register ID


wire    [1:0]           rcrb_cfg_select_deemph_mux_bus;
// L1 Substates Extended Capability
wire    [NL1SUB-1:0]            rcrb_l1sub_reg_id;
wire    [`CX_L1SUB_CONTROL_WD-1:0] rcrb_cfg_l1sub_control;
wire                               rcrb_cfg_l1sub_en;
wire    [`CX_PL_L1SUB_CONTROL_WD-1:0] rcrb_cfg_pl_l1sub_control;
//wire                               rcrb_cfg_pl_l1_exit_mode;
//wire    [31:0]                     rcrb_l1sub_reg_data;
wire    [1:0]   rcrb_cfg_tph_req_en;
wire    [2:0]   rcrb_cfg_pf_tph_st_mode;

wire    [4:0]   rcrb_cfg_ats_stu;
wire           rcrb_cfg_ats_cache_en;


wire          rcrb_cfg_acs_validation_cap_num;
wire          rcrb_cfg_acs_at_blocking_cap_num;
wire          rcrb_cfg_acs_up_forward_cap_num;
wire          rcrb_cfg_acs_validation_en_num;
wire          rcrb_cfg_acs_at_blocking_en_num;
wire          rcrb_cfg_acs_up_forward_en_num;
wire          rcrb_cfg_acs_p2p_req_redirect_cap;
wire          rcrb_cfg_acs_p2p_compl_redirect_cap;
wire          rcrb_cfg_acs_p2p_egress_ctrl_cap;
wire          rcrb_cfg_acs_p2p_direct_transl_cap;
wire   [7:0]  rcrb_cfg_acs_egress_ctrl_vector_size_cap;
wire          rcrb_cfg_acs_p2p_req_redirect_en;
wire          rcrb_cfg_acs_p2p_compl_redirect_en;
wire          rcrb_cfg_acs_p2p_egress_ctrl_en;
wire          rcrb_cfg_acs_p2p_direct_transl_en;
wire   [ACS_CTRL_VEC_WD-1:0]  rcrb_cfg_acs_egress_ctrl_vec;
wire          rcrb_acs_viol_svrity_mask_wr_en;
wire                  rcrb_rbar_ctrl_update;                // RBAR size update - output only if RBARS exist
wire    [(NVC*1)-1:0] rcrb_int_cfg_vc_enable;             // Which VCs are enabled - VC0 is always enabled
wire    [(NVC*3)-1:0] rcrb_int_cfg_vc_struc_vc_id_map;    // VC Structure to VC ID mapping
wire    [23:0]   rcrb_int_cfg_vc_id_vc_struc_map;     // VC ID to VC Structure mapping
wire    [7:0]    rcrb_int_cfg_tc_enable;              // Which TCs are enabled
wire    [23:0]   rcrb_int_cfg_tc_vc_map;              // TC to VC ID mapping
wire    [2:0]    rcrb_int_cfg_lpvc;                   // Low Priority Extended VC (LPVC) Count
wire    [23:0]   rcrb_int_cfg_tc_struc_vc_map;        // TC to VC Structure mapping
wire    [2:0]    rcrb_int_cfg_vc_arb_sel;             // VC Arbitration Select
wire    [31:0]   rcrb_cfg_ltr_max_latency; // Per function LTR Max Snoop & No-Snoop Latencies
wire    [7:0]    rcrb_int_cfg_pwr_budget_data_sel_reg;
wire             rcrb_cfg_pwr_budget_sel;
wire [PASID_CNTRL_WD-1:0] rcrb_cfg_pf_pasid_control;  // VF PASID control signals bus
wire   [(NPTMVSEC)-1:0] rcrb_ptm_vsec_reg_id;
wire   [5:0]            rcrb_vsecdma_reg_id;
wire                    rcrb_vsecdma_reg_sel;
wire [22:0]   rcrb_int_cfg_local_feature_support;
wire     rcrb_int_cfg_dlink_feature_valid;
wire     rcrb_int_fc_scaled_en;
wire     rcrb_int_dl_feature_en;
wire     rcrb_int_cfg_remote_feature_ack;
// Downstream Port Containment Capability outputs.
wire  [4:0]            rcrb_cfg_dpc_int_msg_num;                  // DPC Interrupt Message Number
wire                   rcrb_cfg_dpc_rp_ext_dpc;                   // DPC Root Port Extensions for DPC
wire                   rcrb_cfg_dpc_poison_tlp_egr_blk_support;   // DPC Poisoned TLP Egress Blocking Supported
wire                   rcrb_cfg_dpc_sw_trig_support;              // DPC Software Triggering Supported
wire  [3:0]            rcrb_cfg_dpc_rp_pio_log_size;              // DPC RP PIO Log Size
wire                   rcrb_cfg_dpc_dl_active_err_cor_support;    // DPC DL_Active ERR_COR Signaling Supported
wire  [1:0]            rcrb_cfg_dpc_trig_en;                      // DPC Trigger Enable
wire                   rcrb_cfg_dpc_trig_status;
wire                   rcrb_cfg_dpc_cpl_cntrl;                    // DPC Completion Control
wire                   rcrb_cfg_dpc_int_en;                       // DPC Interrupt Enable
wire                   rcrb_cfg_dpc_err_cor_en;                   // DPC ERR_COR Enable
wire                   rcrb_cfg_dpc_poison_tlp_egr_block_en;      // Poisoned TLP Egress Blocking Enable
wire                   rcrb_cfg_dpc_sw_trigger;                   // DPC Software Trigger
wire                   rcrb_cfg_dpc_dl_active_err_cor_en;         // DL_Active ERR_COR Enable
wire           rcrb_prs_res_failure;
wire           rcrb_prs_uprgi;
wire           rcrb_prs_stopped;
wire           rcrb_cfg_prs_enable;
wire           rcrb_cfg_prs_reset;
wire           rcrb_cfg_prs_stopped;
wire           rcrb_cfg_prs_uprgi;
wire           rcrb_cfg_prs_response_failure;
wire    [31:0]  rcrb_cfg_prs_outstanding_allocation;

// Secondary PCI Express Extended Capability
wire    [NSPCIE*NF-1:0]    spcie_reg_id;
wire    [NSPCIE*NF-1:0]    cfg_spcie_reg_id;
assign spcie_reg_id[NSPCIE*NF-1:0] = cxl_rcrb_enable ? {NF{rcrb_spcie_reg_id}} : cfg_spcie_reg_id[NSPCIE*NF-1:0];
wire    [31:0]          spcie_reg_data;
wire                    cfg_link_eq_req_int_en;
wire                    cfg_link_eq_req_int;
wire                    cfg_pcie_crosslink_supported;
wire                    cfg_ls2_eq_req;
wire                    cfg_ls2_g4_eq_req;
wire                    cfg_ls2_g5_eq_req;
wire                    cfg_ls2_g6_eq_req;
// Physical Layer 16 GT/s Extended Capability.
wire    [NPL16G*NF-1:0] pl16g_reg_id;
wire    [NPL16G*NF-1:0] cfg_pl16g_reg_id;
assign pl16g_reg_id[NPL16G*NF-1:0] = cxl_rcrb_enable ? {NF{rcrb_pl16g_reg_id}} : cfg_pl16g_reg_id[NPL16G*NF-1:0];
wire    [31:0]          pl16g_reg_data;
// Margining Extended Capability.
wire    [NMARGIN*NF-1:0] margin_reg_id;
wire    [NMARGIN*NF-1:0] cfg_margin_reg_id;
assign margin_reg_id[NMARGIN*NF-1:0] = cxl_rcrb_enable ? {NF{rcrb_margin_reg_id}} : cfg_margin_reg_id[NMARGIN*NF-1:0];
wire    [31:0]           margin_reg_data;
// Physical Layer 32 GT/s Extended Capability.
wire    [NPL32G*NF-1:0] pl32g_reg_id;
wire    [NPL32G*NF-1:0] cfg_pl32g_reg_id;
assign pl32g_reg_id = cxl_rcrb_enable ? {NF{rcrb_pl32g_reg_id}} : cfg_pl32g_reg_id;
wire    [31:0]          pl32g_reg_data;
// Physical Layer 32 GT/s Extended Capability.
wire    [NPL64G*NF-1:0] pl64g_reg_id;
wire    [NPL64G*NF-1:0] cfg_pl64g_reg_id;
assign pl64g_reg_id = cxl_rcrb_enable ? {NF{rcrb_pl64g_reg_id}} : cfg_pl64g_reg_id;
wire    [31:0]          pl64g_reg_data;

wire    [1:0]           cfg_select_deemph_mux_bus;
// L1 Substates Extended Capability
wire    [NL1SUB*NF-1:0]            l1sub_reg_id;
wire    [NL1SUB*NF-1:0]            cfg_l1sub_reg_id;
assign l1sub_reg_id  = cxl_rcrb_enable ? {NF{rcrb_l1sub_reg_id}} : cfg_l1sub_reg_id;
wire    [`CX_L1SUB_CONTROL_WD-1:0] cfg_l1sub_control;
wire                               cfg_l1sub_en;
wire    [`CX_PL_L1SUB_CONTROL_WD-1:0] cfg_pl_l1sub_control;
wire                               cfg_pl_l1_exit_mode;
wire    [31:0]                     l1sub_reg_data;
wire                               cfg_pl_l1_nowait_p1;
wire                               cfg_pl_l1_clk_sel;
wire                               cfg_p2nobeacon_enable;
wire                               cfg_pipe_optional_pclkchange_hs;
wire                               cfg_phy_perst_on_warm_reset;
wire [17:0]                        cfg_phy_rst_timer;
wire [5:0]                         cfg_pma_phy_rst_delay_timer;
wire [3:0]                         cfg_dsp_pcipm_l1_enter_delay;

wire    [`CX_PL_AUX_CLK_FREQ_WD-1:0]  cfg_pl_aux_clk_freq;   // programmable auxiliary clock frequency
wire [(32*NF)-1:0] pf_cfg_aer_uncorr_mask_bus;
wire [(32*NF)-1:0] pf_cfg_aer_uncorr_svrity_bus;
wire [(32*NF)-1:0] pf_cfg_aer_corr_mask_bus;
wire [NF-1:0]      pf_multi_hdr_rec_en_bus;
wire    [(2*NF)-1:0]   cfg_tph_req_en;
wire    [(3*NF)-1:0]   cfg_pf_tph_st_mode;

wire  [63:0]           cfg_flit_log               ;
wire  [2:0]            cfg_link_wd_err_cnt_start  ;
wire  [7:0]            cfg_flit_err_cnt           ;
wire  [31:0]           cfg_flit_cnt               ;
wire  [15:0]           cfg_invalid_flit_cnt       ;
wire                   cfg_interr_trg_evnt_cnt    ;
wire                   cfg_interr_trg_evnt_cnt_clr;
wire  [15:0]           cfg_lane_0_corr_cnt        ;
wire  [15:0]           cfg_lane_1_corr_cnt        ;
wire  [15:0]           cfg_lane_2_corr_cnt        ;
wire  [15:0]           cfg_lane_3_corr_cnt        ;
wire  [15:0]           cfg_lane_4_corr_cnt        ;
wire  [15:0]           cfg_lane_5_corr_cnt        ;
wire  [15:0]           cfg_lane_6_corr_cnt        ;
wire  [15:0]           cfg_lane_7_corr_cnt        ;
wire  [15:0]           cfg_lane_8_corr_cnt        ;
wire  [15:0]           cfg_lane_9_corr_cnt        ;
wire  [15:0]           cfg_lane_10_corr_cnt       ;
wire  [15:0]           cfg_lane_11_corr_cnt       ;
wire  [15:0]           cfg_lane_12_corr_cnt       ;
wire  [15:0]           cfg_lane_13_corr_cnt       ;
wire  [15:0]           cfg_lane_14_corr_cnt       ;
wire  [15:0]           cfg_lane_15_corr_cnt       ;

wire [7:0]                cfg_trg_evnt_cnt                  ; 
wire [1:0]                cfg_evnt_to_cnt                   ; 
wire                      cfg_flit_err_cnt_en               ; 
wire                      cfg_interr_trg_evnt_cnt_ind       ; 
wire                      cfg_fber_measurement_en           ; 
wire                      cfg_clr_fber_cnt                  ; 
wire [1:0]                cfg_gran_per_lane_err_rpt         ; 
wire                      cfg_rpt_longest_burst_vs_1st_burst; 
wire                      cfg_pop_fifo_en                   ;

wire     [(NF*8)-1:0]        int_cfg_trg_evnt_cnt                  ; 
wire     [(NF*2)-1:0]        int_cfg_evnt_to_cnt                   ; 
wire     [NF-1:0]            int_cfg_flit_err_cnt_en               ; 
wire     [NF-1:0]            int_cfg_interr_trg_evnt_cnt_ind       ; 
wire     [NF-1:0]            int_cfg_fber_measurement_en           ; 
wire     [NF-1:0]            int_cfg_clr_fber_cnt                  ; 
wire     [(NF*2)-1:0]        int_cfg_gran_per_lane_err_rpt         ; 
wire     [NF-1:0]            int_cfg_rpt_longest_burst_vs_1st_burst;
wire     [NF-1:0]            int_cfg_flit_log_trg_evnt_msi         ;
wire     [NF-1:0]            int_cfg_pop_fifo_en                   ; 
wire     [7:0]        int_rcrb_trg_evnt_cnt                  ;
wire     [1:0]        int_rcrb_evnt_to_cnt                   ;
wire                  int_rcrb_flit_err_cnt_en               ;
wire                  int_rcrb_interr_trg_evnt_cnt_ind       ;
wire                  int_rcrb_fber_measurement_en           ;
wire                  int_rcrb_clr_fber_cnt                  ;
wire     [1:0]        int_rcrb_gran_per_lane_err_rpt         ;
wire                  int_rcrb_rpt_longest_burst_vs_1st_burst;
wire                  int_rcrb_flit_log_trg_evnt_msi         ;
wire                  int_rcrb_pop_fifo_en                   ;
assign cfg_trg_evnt_cnt                   = cxl_rcrb_enable ? int_rcrb_trg_evnt_cnt                   : int_cfg_trg_evnt_cnt[7:0]                ;
assign cfg_evnt_to_cnt                    = cxl_rcrb_enable ? int_rcrb_evnt_to_cnt                    : int_cfg_evnt_to_cnt[1:0]                 ;
assign cfg_flit_err_cnt_en                = cxl_rcrb_enable ? int_rcrb_flit_err_cnt_en                : int_cfg_flit_err_cnt_en[0]               ;
assign cfg_interr_trg_evnt_cnt_ind        = cxl_rcrb_enable ? int_rcrb_interr_trg_evnt_cnt_ind        : int_cfg_interr_trg_evnt_cnt_ind[0]       ;
assign cfg_fber_measurement_en            = cxl_rcrb_enable ? int_rcrb_fber_measurement_en            : int_cfg_fber_measurement_en[0]           ;
assign cfg_clr_fber_cnt                   = cxl_rcrb_enable ? int_rcrb_clr_fber_cnt                   : int_cfg_clr_fber_cnt[0]                  ;
assign cfg_gran_per_lane_err_rpt          = cxl_rcrb_enable ? int_rcrb_gran_per_lane_err_rpt          : int_cfg_gran_per_lane_err_rpt[1:0]       ;
assign cfg_rpt_longest_burst_vs_1st_burst = cxl_rcrb_enable ? int_rcrb_rpt_longest_burst_vs_1st_burst : int_cfg_rpt_longest_burst_vs_1st_burst[0];
assign cfg_flit_log_trg_evnt_msi          = cxl_rcrb_enable ? int_rcrb_flit_log_trg_evnt_msi          : int_cfg_flit_log_trg_evnt_msi[0]         ;
assign cfg_pop_fifo_en                    = cxl_rcrb_enable ? int_rcrb_pop_fifo_en                    : int_cfg_pop_fifo_en[0]                   ;


wire           cfg_msi_en_pf0                     ;
assign         cfg_msi_en_pf0                       = cfg_msi_en[0] ;
                                                   
wire           cfg_msix_en_pf0                    ;
assign         cfg_msix_en_pf0                      = cfg_msix_en[0] ;

wire [2:0]     cfg_ltssm_trck_reg_cnt             ;
wire           cfg_trg_evnt_interr                ;
wire           cfg_sts_1_ltssm_trg_evnt_interr    ;

wire [NF*10 -1:0]   int_cfg_flit_perf_interr_vec           ;    
wire [NF*3 -1:0]    int_cfg_ltssm_trck_reg_cnt             ;
wire [NF*3 -1:0]    int_cfg_flit_response_type             ;
wire [NF*2 -1:0]    int_cfg_flit_type_measured             ;
wire [NF   -1:0]    int_cfg_xplh_flit_track_mode           ;
wire [NF*5 -1:0]    int_cfg_Ltssm_st_trans_trck            ;
wire [NF   -1:0]    int_cfg_trg_evnt_interr                ;
wire [NF   -1:0]    int_cfg_flit_latency_msi               ;
wire [NF   -1:0]    int_cfg_sts_1_ltssm_trg_evnt_interr    ;
wire [NF   -1:0]    int_cfg_sts_1_ltssm_latency_msi     ;

wire   [NF-1:0]        atmu_cfg_vf_bar0_pref_int;
wire   [NF-1:0]        atmu_cfg_vf_bar1_pref_int;
wire   [NF-1:0]        atmu_cfg_vf_bar2_pref_int;
wire   [NF-1:0]        atmu_cfg_vf_bar3_pref_int;
wire   [NF-1:0]        atmu_cfg_vf_bar4_pref_int;
wire   [NF-1:0]        atmu_cfg_vf_bar5_pref_int;
wire   [(64*NF)-1:0]   atmu_cfg_vf_bar0_mask_int;
wire   [(32*NF)-1:0]   atmu_cfg_vf_bar1_mask_int;
wire   [(64*NF)-1:0]   atmu_cfg_vf_bar2_mask_int;
wire   [(32*NF)-1:0]   atmu_cfg_vf_bar3_mask_int;
wire   [(64*NF)-1:0]   atmu_cfg_vf_bar4_mask_int;
wire   [(32*NF)-1:0]   atmu_cfg_vf_bar5_mask_int;

wire [9:0]             int_rcrb_cfg_flit_perf_interr_vec;
wire [2:0]             int_rcrb_cfg_ltssm_trck_reg_cnt;
wire [2:0]             int_rcrb_cfg_flit_response_type;
wire [1:0]             int_rcrb_cfg_flit_type_measured;
wire                   int_rcrb_cfg_xplh_flit_track_mode;
wire [4:0]             int_rcrb_cfg_Ltssm_st_trans_trck;
wire                   int_rcrb_cfg_trg_evnt_interr;
wire                   int_rcrb_cfg_flit_latency_msi;
wire                   int_rcrb_cfg_sts_1_ltssm_trg_evnt_interr    ;
wire                   int_rcrb_cfg_sts_1_ltssm_latency_msi     ;

assign cfg_flit_perf_interr_vec           = cxl_rcrb_enable ?  int_rcrb_cfg_flit_perf_interr_vec     : int_cfg_flit_perf_interr_vec[9:0];
assign cfg_ltssm_trck_reg_cnt             = cxl_rcrb_enable ?  int_rcrb_cfg_ltssm_trck_reg_cnt      : int_cfg_ltssm_trck_reg_cnt[2:0];
assign cdm_xplh_flit_response_type        = cxl_rcrb_enable ?  int_rcrb_cfg_flit_response_type      : int_cfg_flit_response_type[2:0];
assign cdm_xplh_flit_type_measured        = cxl_rcrb_enable ?  int_rcrb_cfg_flit_type_measured      : int_cfg_flit_type_measured[1:0];
assign cdm_xplh_flit_track_mode           = cxl_rcrb_enable ?  int_rcrb_cfg_xplh_flit_track_mode    : int_cfg_xplh_flit_track_mode[0];
assign cfg_trg_evnt_interr                = cxl_rcrb_enable ?  int_rcrb_cfg_trg_evnt_interr         : int_cfg_trg_evnt_interr[0];
assign cfg_flit_latency_msi               = cxl_rcrb_enable ?  int_rcrb_cfg_flit_latency_msi         : int_cfg_flit_latency_msi[0];
assign cdm_pm_state_trans_tracker         = cxl_rcrb_enable ?  int_rcrb_cfg_Ltssm_st_trans_trck     : int_cfg_Ltssm_st_trans_trck[4:0];

assign cfg_sts_1_ltssm_trg_evnt_interr    = cxl_rcrb_enable ?  int_rcrb_cfg_sts_1_ltssm_trg_evnt_interr  :  int_cfg_sts_1_ltssm_trg_evnt_interr[0];
assign cfg_sts_1_ltssm_latency_msi        = cxl_rcrb_enable ?  int_rcrb_cfg_sts_1_ltssm_latency_msi   :  int_cfg_sts_1_ltssm_latency_msi[0];


logic  cfg_flit_err_inj_latency_pl_reg;

os_err_inj_interface_struct os_err_inj_interface;
os_err_inj_status_struct os_err_tx_st_inj, os_err_rx_st_inj;

// Ordered Set Error Tx Injection Status Register
assign  os_err_tx_st_inj = xmlh_tx_os_einj_status;
// Ordered Set Error Rx Injection Status Register: Not yet supported; Hardwire to 0
assign  os_err_rx_st_inj = '0;





wire  [NF    -1 :0]                 int_cfg_flit_err_inj_en               ;
wire  [NF    -1 :0]                 int_cfg_inj_err_tx_flit_ind           ;
wire  [NF    -1 :0]                 int_cfg_inj_err_rx_flit_ind           ;
wire  [NF*13 -1 :0]                 int_cfg_flit_err_inj_en_data_rate     ;
wire  [NF*5  -1 :0]                 int_cfg_inj_err_num                   ;
wire  [NF*8  -1 :0]                 int_cfg_inj_err_spacing               ;
wire  [NF*3  -1 :0]                 int_cfg_flit_type_inj                 ;
wire  [NF*3  -1 :0]                 int_cfg_consec_err_inj                ;
wire  [NF*2  -1 :0]                 int_cfg_curr_inj_err_type             ;
wire  [NF*7  -1 :0]                 int_cfg_flit_err_off                  ;
wire  [NF*8  -1 :0]                 int_cfg_err_mag            ;
wire  [NF    -1 :0]                 int_cfg_ordr_set_err_inj_en           ;
wire  [NF    -1 :0]                 int_cfg_inj_err_tx_ordr_set_ind       ;
wire  [NF    -1 :0]                 int_cfg_inj_err_rx_ordr_set_ind       ;
wire  [NF*5  -1 :0]                 int_cfg_ordr_set_inj_err_num          ;
wire  [NF*8  -1 :0]                 int_cfg_ordr_set_inj_err_spacing      ;
wire  [NF    -1 :0]                 int_cfg_inj_err_ts0_os                ;
wire  [NF    -1 :0]                 int_cfg_inj_err_ts1_os                ;
wire  [NF    -1 :0]                 int_cfg_inj_err_ts2_os                ;
wire  [NF    -1 :0]                 int_cfg_inj_err_skp_os                ;
wire  [NF    -1 :0]                 int_cfg_inj_err_eieos_os              ;
wire  [NF    -1 :0]                 int_cfg_inj_err_eios_os               ;
wire  [NF    -1 :0]                 int_cfg_inj_err_sds_os                ;
wire  [NF    -1 :0]                 int_cfg_inj_err_poll_st               ;
wire  [NF    -1 :0]                 int_cfg_inj_err_cfg_st                ;
wire  [NF    -1 :0]                 int_cfg_inj_err_l0_st                 ;
wire  [NF    -1 :0]                 int_cfg_inj_err_non_eq_recov_st       ;
wire  [NF    -1 :0]                 int_cfg_inj_err_recov_eq_ph_1_0       ;
wire  [NF    -1 :0]                 int_cfg_inj_err_recov_eq_ph_2         ;
wire  [NF    -1 :0]                 int_cfg_inj_err_recov_eq_ph_3         ;
wire  [NF*16 -1 :0]                 int_cfg_err_inj_bytes                 ;
wire  [NF*16 -1 :0]                 int_cfg_err_inj_lane_num              ;



wire                         int_rcrb_cfg_flit_err_inj_en               ;
wire                         int_rcrb_cfg_inj_err_tx_flit_ind           ;
wire                         int_rcrb_cfg_inj_err_rx_flit_ind           ;
wire  [12:0]                 int_rcrb_cfg_flit_err_inj_en_data_rate     ;
wire  [4:0]                  int_rcrb_cfg_inj_err_num                   ;
wire  [7:0]                  int_rcrb_cfg_inj_err_spacing               ;
wire  [2:0]                  int_rcrb_cfg_flit_type_inj                 ;
wire  [2:0]                  int_rcrb_cfg_consec_err_inj                ;
wire  [1:0]                  int_rcrb_cfg_curr_inj_err_type             ;
wire  [6:0]                  int_rcrb_cfg_flit_err_off                  ;
wire  [7:0]                  int_rcrb_cfg_err_mag            ;
wire                         int_rcrb_cfg_ordr_set_err_inj_en           ;
wire                         int_rcrb_cfg_inj_err_tx_ordr_set_ind       ;
wire                         int_rcrb_cfg_inj_err_rx_ordr_set_ind       ;
wire  [4:0]                  int_rcrb_cfg_ordr_set_inj_err_num          ;
wire  [7:0]                  int_rcrb_cfg_ordr_set_inj_err_spacing      ;
wire                         int_rcrb_cfg_inj_err_ts0_os                ;
wire                         int_rcrb_cfg_inj_err_ts1_os                ;
wire                         int_rcrb_cfg_inj_err_ts2_os                ;
wire                         int_rcrb_cfg_inj_err_skp_os                ;
wire                         int_rcrb_cfg_inj_err_eieos_os              ;
wire                         int_rcrb_cfg_inj_err_eios_os               ;
wire                         int_rcrb_cfg_inj_err_sds_os                ;
wire                         int_rcrb_cfg_inj_err_poll_st               ;
wire                         int_rcrb_cfg_inj_err_cfg_st                ;
wire                         int_rcrb_cfg_inj_err_l0_st                 ;
wire                         int_rcrb_cfg_inj_err_non_eq_recov_st       ;
wire                         int_rcrb_cfg_inj_err_recov_eq_ph_1_0       ;
wire                         int_rcrb_cfg_inj_err_recov_eq_ph_2         ;
wire                         int_rcrb_cfg_inj_err_recov_eq_ph_3         ;
wire  [15:0]                 int_rcrb_cfg_err_inj_bytes                 ;
wire  [15:0]                 int_rcrb_cfg_err_inj_lane_num              ;
                                                                                                                                                                           
                                                                                                                                                                           

assign cfg_flit_err_inj_latency=cfg_flit_err_inj_latency_pl_reg;

assign cdm_plh_flit_err_inj_interface.cfg_err_inj_extnd_cap_en       =   cfg_flit_err_inj_latency_pl_reg;
assign cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en            = cxl_rcrb_enable ?   int_rcrb_cfg_flit_err_inj_en              : int_cfg_flit_err_inj_en[0];
assign cdm_plh_flit_err_inj_interface.cfg_inj_err_tx_flit_ind        = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_tx_flit_ind          : int_cfg_inj_err_tx_flit_ind[0];
assign cdm_plh_flit_err_inj_interface.cfg_inj_err_rx_flit_ind        = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_rx_flit_ind          : int_cfg_inj_err_rx_flit_ind[0];
assign cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en_data_rate  = cxl_rcrb_enable ?   int_rcrb_cfg_flit_err_inj_en_data_rate    : int_cfg_flit_err_inj_en_data_rate[12:0];
assign cdm_plh_flit_err_inj_interface.cfg_inj_err_num                = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_num                  : int_cfg_inj_err_num[4:0];
assign cdm_plh_flit_err_inj_interface.cfg_inj_err_spacing            = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_spacing              : int_cfg_inj_err_spacing[7:0];
assign cdm_plh_flit_err_inj_interface.cfg_flit_type_inj              = cxl_rcrb_enable ?   int_rcrb_cfg_flit_type_inj                : int_cfg_flit_type_inj[2:0];
assign cdm_plh_flit_err_inj_interface.cfg_consec_err_inj             = cxl_rcrb_enable ?   int_rcrb_cfg_consec_err_inj               : int_cfg_consec_err_inj[2:0];
assign cdm_plh_flit_err_inj_interface.cfg_curr_inj_err_type          = cxl_rcrb_enable ?   int_rcrb_cfg_curr_inj_err_type            : int_cfg_curr_inj_err_type[1:0];
assign cdm_plh_flit_err_inj_interface.cfg_flit_err_off               = cxl_rcrb_enable ?   int_rcrb_cfg_flit_err_off                 : int_cfg_flit_err_off[6:0];
assign cdm_plh_flit_err_inj_interface.cfg_err_mag                    = cxl_rcrb_enable ?   int_rcrb_cfg_err_mag                      : int_cfg_err_mag[7:0];

assign os_err_inj_interface.cfg_err_inj_extnd_cap_en        =   cfg_flit_err_inj_latency_pl_reg;
assign os_err_inj_interface.cfg_ordr_set_err_inj_en         = cxl_rcrb_enable ?   int_rcrb_cfg_ordr_set_err_inj_en          : int_cfg_ordr_set_err_inj_en[0]           ;
assign os_err_inj_interface.cfg_inj_err_tx_ordr_set_ind     = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_tx_ordr_set_ind      : int_cfg_inj_err_tx_ordr_set_ind[0]           ;
assign os_err_inj_interface.cfg_inj_err_rx_ordr_set_ind     = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_rx_ordr_set_ind      : int_cfg_inj_err_rx_ordr_set_ind[0]           ;
assign os_err_inj_interface.cfg_ordr_set_inj_err_num        = cxl_rcrb_enable ?   int_rcrb_cfg_ordr_set_inj_err_num         : int_cfg_ordr_set_inj_err_num[4:0]       ;
assign os_err_inj_interface.cfg_ordr_set_inj_err_spacing    = cxl_rcrb_enable ?   int_rcrb_cfg_ordr_set_inj_err_spacing     : int_cfg_ordr_set_inj_err_spacing[7:0]       ;
assign os_err_inj_interface.cfg_inj_err_ts0_os              = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_ts0_os               : int_cfg_inj_err_ts0_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_ts1_os              = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_ts1_os               : int_cfg_inj_err_ts1_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_ts2_os              = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_ts2_os               : int_cfg_inj_err_ts2_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_skp_os              = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_skp_os               : int_cfg_inj_err_skp_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_eieos_os            = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_eieos_os             : int_cfg_inj_err_eieos_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_eios_os             = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_eios_os              : int_cfg_inj_err_eios_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_sds_os              = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_sds_os               : int_cfg_inj_err_sds_os[0]           ;
assign os_err_inj_interface.cfg_inj_err_poll_st             = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_poll_st              : int_cfg_inj_err_poll_st[0]           ;
assign os_err_inj_interface.cfg_inj_err_cfg_st              = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_cfg_st               : int_cfg_inj_err_cfg_st[0]           ;
assign os_err_inj_interface.cfg_inj_err_l0_st               = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_l0_st                : int_cfg_inj_err_l0_st[0]           ;
assign os_err_inj_interface.cfg_inj_err_non_eq_recov_st     = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_non_eq_recov_st      : int_cfg_inj_err_non_eq_recov_st[0]           ;
assign os_err_inj_interface.cfg_inj_err_recov_eq_ph_1_0     = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_recov_eq_ph_1_0      : int_cfg_inj_err_recov_eq_ph_1_0[0]           ;
assign os_err_inj_interface.cfg_inj_err_recov_eq_ph_2       = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_recov_eq_ph_2        : int_cfg_inj_err_recov_eq_ph_2[0]           ;
assign os_err_inj_interface.cfg_inj_err_recov_eq_ph_3       = cxl_rcrb_enable ?   int_rcrb_cfg_inj_err_recov_eq_ph_3        : int_cfg_inj_err_recov_eq_ph_3[0]           ;
assign os_err_inj_interface.cfg_err_inj_bytes               = cxl_rcrb_enable ?   int_rcrb_cfg_err_inj_bytes                : int_cfg_err_inj_bytes[15:0]      ;
assign os_err_inj_interface.cfg_err_inj_lane_num            = cxl_rcrb_enable ?   int_rcrb_cfg_err_inj_lane_num             : int_cfg_err_inj_lane_num[15:0]      ; 
                             

// Ordered Set Error Injection Control 1 Register
// cfg_os_einj_ctrl_1/2 and os_err_inj_interface structs created independently
// Join like this rather than rename structs here and in xmlh_os_einj
always_comb begin: cfg_os_einj_ctrl_1_PROC
  cfg_os_einj_ctrl_1.os_error_injection_en           = os_err_inj_interface.cfg_ordr_set_err_inj_en;
  cfg_os_einj_ctrl_1.tx_os_error_injection_en        = os_err_inj_interface.cfg_inj_err_tx_ordr_set_ind;
  cfg_os_einj_ctrl_1.rx_os_error_injection_en        = os_err_inj_interface.cfg_inj_err_rx_ordr_set_ind;
  cfg_os_einj_ctrl_1.number_of_errors_injected       = os_err_inj_interface.cfg_ordr_set_inj_err_num;
  cfg_os_einj_ctrl_1.spacing_between_errors          = os_err_inj_interface.cfg_ordr_set_inj_err_spacing;
  cfg_os_einj_ctrl_1.inject_error_on_ts0             = os_err_inj_interface.cfg_inj_err_ts0_os;
  cfg_os_einj_ctrl_1.inject_error_on_ts1             = os_err_inj_interface.cfg_inj_err_ts1_os;
  cfg_os_einj_ctrl_1.inject_error_on_ts2             = os_err_inj_interface.cfg_inj_err_ts2_os;
  cfg_os_einj_ctrl_1.inject_error_on_skp             = os_err_inj_interface.cfg_inj_err_skp_os;
  cfg_os_einj_ctrl_1.inject_error_on_eie             = os_err_inj_interface.cfg_inj_err_eieos_os;
  cfg_os_einj_ctrl_1.inject_error_on_eid             = os_err_inj_interface.cfg_inj_err_eios_os;
  cfg_os_einj_ctrl_1.inject_error_on_sds             = os_err_inj_interface.cfg_inj_err_sds_os;
  cfg_os_einj_ctrl_1.inject_error_in_polling         = os_err_inj_interface.cfg_inj_err_poll_st;
  cfg_os_einj_ctrl_1.inject_error_in_cfg             = os_err_inj_interface.cfg_inj_err_cfg_st;
  cfg_os_einj_ctrl_1.inject_error_in_l0              = os_err_inj_interface.cfg_inj_err_l0_st;
  cfg_os_einj_ctrl_1.inject_error_in_rvcry_noneq     = os_err_inj_interface.cfg_inj_err_non_eq_recov_st;
  cfg_os_einj_ctrl_1.inject_error_in_rcvry_eq_ph_0_1 = os_err_inj_interface.cfg_inj_err_recov_eq_ph_1_0;
  cfg_os_einj_ctrl_1.inject_error_in_rcvry_eq_ph_2   = os_err_inj_interface.cfg_inj_err_recov_eq_ph_2;
  cfg_os_einj_ctrl_1.inject_error_in_rcvry_eq_ph_3   = os_err_inj_interface.cfg_inj_err_recov_eq_ph_3;
end // cfg_os_einj_ctrl_1_PROC

// Ordered Set Error Injection Control 2 Register
always_comb begin: cfg_os_einj_ctrl_2_PROC
  cfg_os_einj_ctrl_2.error_injection_bytes           = os_err_inj_interface.cfg_err_inj_bytes;
  cfg_os_einj_ctrl_2.error_injection_lanes           = os_err_inj_interface.cfg_err_inj_lane_num;
end // cfg_os_einj_ctrl_2_PROC

wire [NF-1:0]         cfg_drs_msi;
wire [(3*NF)-1:0]     cfg_downstream_comp_pres;
wire [NF-1:0]         cfg_up_drs_to_frs;
wire [NF-1:0]         cfg_drs_frs_sig_en;      //signal is a top level output only for a Switch
wire                  frsq_msi;
wire [4:0]            frsq_int_msg_num;
wire [NF-1:0]         cfg_frsq_msi;
wire [(NF*5)-1:0]     cfg_frsq_int_msg_num;
wire [NF-1:0]         pmstate_d3hot_to_d0;
wire                  rcrb_frsq_msi;
wire [4:0]            rcrb_frsq_int_msg_num;
assign frsq_msi = cfg_frsq_msi[0];
assign frsq_int_msg_num = cfg_frsq_int_msg_num[4:0];



wire    [(5*NF)-1:0]   cfg_ats_stu;
wire    [NF-1:0]       cfg_ats_cache_en;

wire   [NF-1:0]       cfg_acs_validation_cap_num;
wire   [NF-1:0]       cfg_acs_at_blocking_cap_num;
wire   [NF-1:0]       cfg_acs_up_forward_cap_num;
wire   [NF-1:0]       cfg_acs_validation_en_num;
wire   [NF-1:0]       cfg_acs_at_blocking_en_num;
wire   [NF-1:0]       cfg_acs_up_forward_en_num;
wire   [NF-1:0]       cfg_acs_p2p_req_redirect_cap;
wire   [NF-1:0]       cfg_acs_p2p_compl_redirect_cap;
wire   [NF-1:0]       cfg_acs_p2p_egress_ctrl_cap;
wire   [NF-1:0]       cfg_acs_p2p_direct_transl_cap;
wire   [(8*NF)-1:0]   cfg_acs_egress_ctrl_vector_size_cap;
wire   [NF-1:0]       cfg_acs_p2p_req_redirect_en;
wire   [NF-1:0]       cfg_acs_p2p_compl_redirect_en;
wire   [NF-1:0]       cfg_acs_p2p_egress_ctrl_en;
wire   [NF-1:0]       cfg_acs_p2p_direct_transl_en;
wire   [(ACS_CTRL_VEC_WD*NF)-1:0]  cfg_acs_egress_ctrl_vec;
wire   [NF-1:0]       acs_viol_svrity_mask_wr_en;

wire    [NF-1:0]       prs_res_failure;
wire    [NF-1:0]       prs_uprgi;
wire    [NF-1:0]       prs_stopped;
wire    [NF-1:0]       cfg_prs_enable;
wire    [NF-1:0]       cfg_prs_reset;
wire    [NF-1:0]       cfg_prs_stopped;
wire    [NF-1:0]       cfg_prs_uprgi;
wire    [NF-1:0]       cfg_prs_response_failure;
wire    [(32*NF)-1:0]  cfg_prs_outstanding_allocation;
wire [2*NF-1:0]  pf_cfg_pcie_aspm_cap_bus;
wire             cfg_l0s_supported;
wire [NF-1:0]    pf_cfg_ido_req_en;
wire [NF-1:0]    pf_cfg_ido_cpl_en;
output [NF-1:0]  cfg_ido_req_en;
output [NF-1:0]  cfg_ido_cpl_en;
wire    [NF-1:0]  cfg_ido_req_en;
wire    [NF-1:0]  cfg_ido_cpl_en;
wire [6*NF-1:0]  pf_cfg_pcie_max_link_width_bus;
wire [NF-1:0]    cfg_adv_cor_err_int;
wire [NF-1:0]    cfg_adv_nf_err_int;
wire [NF-1:0]    cfg_adv_f_err_int;
// ATU outbound Region controls
wire      [5*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_type;
wire      [3*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_tc;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_td;
wire      [ATTR_WD*ATU_OUT_NREGIONS_MIN1-1:0]            atu_reg_out_attr;
wire      [2*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_at;
wire      [PF_WD*ATU_OUT_NREGIONS_MIN1-1:0]              atu_reg_out_func_num;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_func_bypass;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_snp;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_dma_bypass;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_inhibit_payload;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_hdr_substitute_en;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_tag_substitute_en;
wire      [TAG_SIZE*ATU_OUT_NREGIONS_MIN1-1:0]           atu_reg_out_tag;
wire      [8*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_msg_code;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_th;
wire      [2*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_ph;
wire      [8*ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_st;
// Mode Settings
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_shift;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_invert;
// Region Enable
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_en;
// Base, Limit and Target Registers
wire      [ATU_REG_WD*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_base;
wire      [ATU_BASE_WD*ATU_OUT_NREGIONS_MIN1-1:0]        atu_reg_out_upr_base;
wire      [ATU_REG_WD*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_limit;
wire      [ATU_UPR_LMT_WD*ATU_OUT_NREGIONS_MIN1-1:0]     atu_reg_out_uppr_limit;
wire      [ATU_REG_WD*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_lwr_trgt;
wire      [ATU_BASE_WD*ATU_OUT_NREGIONS_MIN1-1:0]        atu_reg_out_upr_trgt;
wire      [ATU_REG_LWR_WD*ATU_OUT_NREGIONS_MIN1-1:0]     atu_reg_out_lwr_trgt_lwr;
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_incr_rgn_size;    // Maximum region size control bit
wire      [ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_hdr_flds_bypass;  // TLP Header fields bypass control bit

// ATU inbound Region controls
wire      [5*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_type;
wire      [3*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_tc;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_td;
wire      [ATTR_WD*ATU_IN_NREGIONS_MIN1 -1:0]            atu_reg_in_attr;
wire      [2*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_at;
wire      [PF_WD*ATU_IN_NREGIONS_MIN1 -1:0]              atu_reg_in_func_num;
wire      [8*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_msg_code;
wire      [3*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_bar_num;
wire      [ATU_IN_NREGIONS_MIN1-1:0]                     atu_reg_in_th;
wire      [2*ATU_IN_NREGIONS_MIN1-1:0]                   atu_reg_in_ph;
wire      [8*ATU_IN_NREGIONS_MIN1-1:0]                   atu_reg_in_st;
// Inbound field match enables
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_tc_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_td_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_attr_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_at_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_func_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_msgcode_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_th_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_ph_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_st_match_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_single_addr_loc_en;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_msg_type_match_mode;
// Response and mode settings
wire      [2*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_rsp_code;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_fuzzy;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_shift;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_invert;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_bar_match;
// Region Enable
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_en;
// Base, Limit and Target Registers
wire      [ATU_REG_WD*ATU_IN_NREGIONS_MIN1 -1:0]         atu_reg_in_base;
wire      [ATU_BASE_WD*ATU_IN_NREGIONS_MIN1 -1:0]        atu_reg_in_upr_base;
wire      [ATU_REG_WD*ATU_IN_NREGIONS_MIN1 -1:0]         atu_reg_in_limit;
wire      [4*ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_cbuf_incr;
wire      [ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_cbuf_restart;
wire      [ATU_UPR_LMT_WD*ATU_IN_NREGIONS_MIN1-1:0]      atu_reg_in_uppr_limit;
wire      [ATU_REG_WD*ATU_IN_NREGIONS_MIN1 -1:0]         atu_reg_in_lwr_trgt;
wire      [ATU_BASE_WD*ATU_IN_NREGIONS_MIN1 -1:0]        atu_reg_in_upr_trgt;
wire      [ATU_IN_NREGIONS_MIN1-1:0]                     atu_reg_in_incr_rgn_size;    // Maximum region size control bit
wire      [31:0]                                atu_ctrl_reg_data;
reg                                             atu_ctrl_reg_ack;
wire      [15:0]                                 cfg_err_resp;
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
wire      [31:0]                                cfg_aximstr_msg_addr_low;
wire      [31:0]                                cfg_aximstr_msg_addr_high;
wire      [1:0]                                 cfg_mstr_ardomain_mode;
wire      [1:0]                                 cfg_mstr_awdomain_mode;
wire      [1:0]                                 cfg_mstr_ardomain_value;
wire      [1:0]                                 cfg_mstr_awdomain_value;
wire                                            cfg_ax_mstr_zeroread_fw;
wire                                            cfg_memtype_value;
wire      [`FLT_Q_ADDR_WIDTH-3:0]               cfg_memtype_boundary;
wire                              crgb_reg_sel;
wire  [CRGB_DATA_WIDTH - 1 :0]    crgb_cdm_rdata;
wire                              crgb_cdm_ack;
wire [(2*NF)-1:0]                 int_cfg_obff_en;
wire                              app_ltr_msg_req;                // LTR message request - from Application interface
wire                              msg_ltr_det;              // LTR message grant   - from Message Generation (msg_gen) module
wire [(NF-1):0]                   int_cfg_ltr_m_en;    // Per function LTR mechanism enable bits
wire [(32*NF)-1:0]                cfg_ltr_max_latency; // Per function LTR Max Snoop & No-Snoop Latencies
wire [31:0]                       app_ltr_latency;     // LTR upstream port component latency
wire [(NF-1):0]                   int_cdm2msgg_ltr_clr_msg_req; // Per function LTR clear message request
wire                              cdmpl2cfg_ltr_rq; // Port logic to PCIe configuration OR'ed LTR message requirement bits
wire    [(6*NF)-1:0]             int_cfg_rbar_bar_resizable;      // Resize RBAR[n] when n = 0 to 5
wire    [(64*NF)-1:0]            int_cfg_rbar_bar0_mask;          // RBAR0 mask value
wire    [(32*NF)-1:0]            int_cfg_rbar_bar1_mask;          // RBAR1 mask value
wire    [(64*NF)-1:0]            int_cfg_rbar_bar2_mask;          // RBAR2 mask value
wire    [(32*NF)-1:0]            int_cfg_rbar_bar3_mask;          // RBAR3 mask value
wire    [(64*NF)-1:0]            int_cfg_rbar_bar4_mask;          // RBAR4 mask value
wire    [(32*NF)-1:0]            int_cfg_rbar_bar5_mask;          // RBAR5 mask value
wire    [NF-1:0]                 rbar_ctrl_update;                // RBAR size update - output only if RBARS exist
wire    [NF*(6*6)-1:0]           cfg_rbar_size;                   // RBAR sizes  - output only if RBARS exist
wire    [(6*NF)-1:0]             int_cfg_vf_rbar_bar_resizable;      // Resize VF RBAR[n] when n = 0 to 5
wire    [(64*NF)-1:0]            int_cfg_vf_rbar_bar0_mask;          // VF RBAR0 mask value
wire    [(32*NF)-1:0]            int_cfg_vf_rbar_bar1_mask;          // VF RBAR1 mask value
wire    [(64*NF)-1:0]            int_cfg_vf_rbar_bar2_mask;          // VF RBAR2 mask value
wire    [(32*NF)-1:0]            int_cfg_vf_rbar_bar3_mask;          // VF RBAR3 mask value
wire    [(64*NF)-1:0]            int_cfg_vf_rbar_bar4_mask;          // VF RBAR4 mask value
wire    [(32*NF)-1:0]            int_cfg_vf_rbar_bar5_mask;          // VF RBAR5 mask value
wire    [NF-1:0]                 vf_rbar_ctrl_update;                // VF RBAR size update - output only if VFRBARS exist
wire    [NF*(6*6)-1:0]           cfg_vf_rbar_size;                   // VF RBAR sizes  - output only if VFRBARS exist

wire    [FS_LF_WD-1:0]           cfg_gen3_eq_fs_lf;            // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]       cfg_gen3_eq_coef;             // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]           cfg_gen4_eq_fs_lf;            // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]       cfg_gen4_eq_coef;             // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]           cfg_gen5_eq_fs_lf;            // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]       cfg_gen5_eq_coef;             // programmable FS and LF for equalization
wire    [FS_LF_WD-1:0]           cfg_gen6_eq_fs_lf;            // programmable FS and LF for equalization
wire    [(11*COEF_WD)-1:0]       cfg_gen6_eq_coef;             // programmable FS and LF for equalization


wire                  cxl_rcrb_enable;

wire                  lbc_cdm_rcrb_wire;
wire                  lbc_cdm_rcrb_mbar0_wire;
wire                  lbc_cdm_rcrb_dbi;
wire                  lbc_cdm_rcrb_mbar0_dbi;

wire [51:0]           rcrb_base_addr;
wire                  rcrb_base_addr_valid;

wire [63:12]          rcrb_address_reg;
logic[NF-1:0][63:12]  rcrb_address_reg_int;
assign rcrb_address_reg = rcrb_address_reg_int[0];

wire [63:0]           rcrb_mbar0_base_addr;

wire [(FX_TLP-N_TRGT1_INTF)-1:0]         cfg_rcrb_match;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]         cfg_rcrb_mbar0_match;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]         cfg_rcrb_mbar0_match_int;
wire [(NF*(FX_TLP-N_TRGT1_INTF))-1:0]    cfg_rcrb_match_int;
assign cfg_rcrb_match       = cfg_rcrb_match_int[(FX_TLP-N_TRGT1_INTF)-1:0];


// ------------------------------------------------------------
// Wires for u_cdm_reg_decode
// ------------------------------------------------------------
logic                 rcrb_mbar0_reg_ack;
logic [NF-1:0]        rcrb_mbar0_reg_ack_downstream;

logic                 rcrb_mbar0_reg_ack_mux;
assign rcrb_mbar0_reg_ack_mux = (upstream_port & ~cxl_mbar0_enable) ? rcrb_mbar0_reg_ack : rcrb_mbar0_reg_ack_downstream[0];


logic [31:0]          rcrb_mbar0_reg_data;
logic                 ecfg_rcrb_reg_ack;
logic [31:0]          ecfg_rcrb_reg_data;

logic                 cfg_rcrb_reg_sel;
logic                 cfg_rcrb_cap_reg_sel;
logic                 ecfg_rcrb_reg_sel;
logic                 rcrb_mbar0_reg_sel;
logic                 rcrb_mbar0_reg_sel_downstream;
logic                 rcrb_mbar0_reg_sel_upstream;
assign rcrb_mbar0_reg_sel_upstream   = cxl_mbar0_enable ? 1'b0 : (rcrb_mbar0_reg_sel & upstream_port);
assign rcrb_mbar0_reg_sel_downstream = cxl_mbar0_enable ? rcrb_mbar0_reg_sel : (rcrb_mbar0_reg_sel & ~upstream_port);

// ------------------------------------------------------------
// Wires for u_cdm_rcrb_cfg_reg
// ------------------------------------------------------------

wire [NF-1 : 0]       cfg_rcb_rciep;
wire                  cfg_rcrb_upd_pme_cap;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]     cfg_rcrb_mem_match;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]     cfg_rcrb_prefmem_match;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]     cfg_rcrb_io_match;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]     cfg_rcrb_config_above_match;
wire [(6*(FX_TLP-N_TRGT1_INTF))-1:0] cfg_rcrb_bar_match;
wire [(FX_TLP-N_TRGT1_INTF)-1:0]     cfg_rcrb_rom_match;
wire [5:0]            cfg_rcrb_bar_is_io;
wire                  cfg_rcrb_br_ctrl_serren;
wire                  cfg_rcrb_br_ctrl_perren;
wire                  cfg_rcrb_bus_master_en;
wire                  cfg_rcrb_reg_perren;
wire                  cfg_rcrb_reg_serren;
wire                  int_cfg_rcrb_sys_err_rc;
wire                  int_cfg_rcrb_crs_sw_vis_en;
wire                  int_cfg_rcrb_pme_int;
wire                  int_cfg_rcrb_pme_msi;
wire                  int_cfg_rcrb_2nd_reset;
wire                  cfg_rcrb_slot_pwr_limit_wr;
wire [9:0]            cfg_rcrb_pcie_slot_pwr_limit;
wire [2:0]            cfg_rcrb_multi_msi_en;
wire                  cfg_rcrb_msi_ext_data_en;
wire                  cfg_rcrb_msi_en;
wire [63:0]           cfg_rcrb_msi_addr;
wire [31:0]           cfg_rcrb_msi_data;
wire                  cfg_rcrb_msi_64;
wire                  cfg_rcrb_msix_en;
wire                  cfg_rcrb_msix_func_mask;
wire [10:0]           cfg_rcrb_msix_table_size;
wire [10:0]           cfg_rcrb_msix_table_size2;
wire [2:0]            cfg_rcrb_msix_table_bir;
wire [2:0]            cfg_rcrb_msix_table_bir2;
wire [28:0]           cfg_rcrb_msix_table_offset;
wire [28:0]           cfg_rcrb_msix_table_offset2;
wire [2:0]            cfg_rcrb_msix_pba_bir;
wire [2:0]            cfg_rcrb_msix_pba_bir2;
wire [28:0]           cfg_rcrb_msix_pba_offset;
wire [28:0]           cfg_rcrb_msix_pba_offset2;
wire                  cfg_rcrb_vpd_int;
wire [2:0]            cfg_rcrb_max_payload_size;
// In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field and this only goes to the TLP check logic inside the radm multi-stream.
wire [2:0]           cfg_rcrb_max_payload_size_out_rx;
wire                  cfg_rcrb_relax_ord_en;
wire                  cfg_rcrb_ext_tag_en;
wire                  cfg_rcrb_phantom_fun_en;
wire                  cfg_rcrb_no_snoop_en;
wire [2:0]            cfg_rcrb_max_rd_req_size;
wire                  cfg_rcrb_bridge_crs_en;
wire [1:0]            int_cfg_rcrb_aslk_pmctrl;
wire                  int_cfg_rcrb_upd_aslk_pmctrl;
wire                  int_cfg_rcrb_clk_pm_en;
wire                  cfg_rcrb_rcb;
wire                  int_rcrb_link_dis;
wire                  int_rcrb_link_retrain;
wire                  int_cfg_rcrb_comm_clk_config;
wire                  int_cfg_rcrb_hw_autowidth_dis;
wire [3:0]            int_cfg_rcrb_link_rate;
wire [1:0]            int_cfg_rcrb_retimers_pre_detected;
wire [1:0]            cfg_rcrb_pwr_ind;
wire [1:0]            cfg_rcrb_atten_ind;
wire                  cfg_rcrb_pwr_ctrler_ctrl;
wire                  cfg_rcrb_hp_int_en;
wire                  cfg_rcrb_atten_button_pressed;
wire                  cfg_rcrb_eml_control;
wire                  cfg_rcrb_pwr_fault_det;
wire                  cfg_rcrb_mrl_sensor_chged;
wire                  cfg_rcrb_pre_det_chged;
wire                  cfg_rcrb_cmd_cpled_int;
wire                  cfg_rcrb_dll_state_chged;
wire                  cfg_rcrb_int_disable;
wire                  cfg_rcrb_cor_err_rpt_en;
wire                  cfg_rcrb_nf_err_rpt_en;
wire                  cfg_rcrb_f_err_rpt_en;
wire                  cfg_rcrb_unsupt_req_rpt_en;
wire [7:0]            int_cfg_rcrb_pbus_num;
wire [7:0]            cfg_rcrb_2ndbus_num;
wire [7:0]            cfg_rcrb_subbus_num;
wire [4:0]            int_cfg_rcrb_pbus_dev_num;
wire [63:0]           cfg_rcrb_bar0_start;
wire [63:0]           cfg_rcrb_bar0_limit;
wire [31:0]           cfg_rcrb_rom_mask;
wire [15:0]           cfg_rcrb_mem_base;
wire [15:0]           cfg_rcrb_mem_limit;
wire [63:0]           cfg_rcrb_pref_mem_base;
wire [63:0]           cfg_rcrb_pref_mem_limit;
wire [31:0]           cfg_rcrb_exp_rom_start;
wire [31:0]           cfg_rcrb_exp_rom_limit;
wire [15:0]           cfg_rcrb_io_limit_upper16;
wire [15:0]           cfg_rcrb_io_base_upper16;
wire [7:0]            cfg_rcrb_io_base;
wire [7:0]            cfg_rcrb_io_limit;
wire [7:0]            int_cfg_rcrb_hdr_type;
wire                  int_rcrb_ext_synch;
wire                  cfg_rcrb_io_space_en;
wire                  cfg_rcrb_mem_space_en;

logic                 cfg_rcrb_cap_reg_ack;
logic [31:0]          cfg_rcrb_cap_reg_data;
logic [31:0]          cfg_rcrb_reg_data;
logic                 cfg_rcrb_reg_ack;
wire                  cfg_rcrb_upd_pmcsr;
wire                  cfg_rcrb_upd_aux_pm_en;
wire                  cfg_rcrb_upd_req_id;
wire                  cfg_rcrb_aux_pm_en;
wire                  cfg_rcrb_pmstatus_clr;
wire [2:0]            cfg_rcrb_pmstate;
wire                  cfg_rcrb_pme_en;
wire [4:0]            cfg_rcrb_pme_cap;
wire                  cfg_rcrb_pm_no_soft_rst;
wire                  cfg_rcrb_isa_enable;
wire                  cfg_rcrb_vga_enable;
wire                  cfg_rcrb_vga16_decode;
wire [7:0]            cfg_rcrb_int_pin;
wire                  int_cfg_rcrb_link_auto_bw_int;
wire                  int_cfg_rcrb_link_auto_bw_msi;
wire                  int_cfg_rcrb_bw_mgt_int;
wire                  int_cfg_rcrb_bw_mgt_msi;
wire [3:0]            pf_cfg_rcrb_pcie_max_link_speed_bus;
wire [3:0]            int_cfg_rcrb_target_link_speed;
wire                  int_cfg_rcrb_enter_compliance;
wire                  int_cfg_rcrb_hw_auto_sp_dis;
wire                  int_cfg_rcrb_sel_de_emphasis;
wire [2:0]            int_cfg_rcrb_transmit_margin;
wire                  int_cfg_rcrb_enter_mod_compliance;
wire                  int_cfg_rcrb_compliance_sos;
wire [3:0]            int_cfg_rcrb_compliance_de_emphasis;
wire                  cfg_rcrb_atomic_req_en;
wire                  cfg_rcrb_atomic_egress_block;
wire [1:0]            int_cfg_rcrb_obff_en;
wire                  int_cfg_rcrb_ltr_m_en;
wire                  int_rcrb_cdm2msgg_ltr_clr_msg_req;

wire [1:0]            pf_cfg_rcrb_pcie_aspm_cap_bus;
wire [5:0]            pf_cfg_rcrb_pcie_max_link_width_bus;
wire                  pf_cfg_rcrb_ido_req_en;          //cdm_cfg_reg
wire                  pf_cfg_rcrb_ido_cpl_en;


wire                  cfg_rcrb_drs_msi;
wire [2:0]            cfg_rcrb_downstream_comp_pres;       //cfg
wire                  cfg_rcrb_up_drs_to_frs;
wire                  cfg_rcrb_drs_frs_sig_en;

wire [4:0]            cfg_rcrb_pcie_cap_int_msg_num;
wire                  cfg_rcrb_ari_fwd_en;
wire [3:0]            cfg_rcrb_cpl_timeout_range;
wire                  cfg_rcrb_cpl_timeout_disable;
wire                  int_cfg_rcrb_pcie_crosslink_supported;
wire                  int_cfg_rcrb_ls2_eq_req;
wire                  cfg_rcrb_end2end_tlp_pfx_blck;
wire [1:0]            cfg_rcrb_max_end2end_tlp_prfxs;
wire                  cfg_rcrb_10b_tag_req_en;

wire                  rcrb_surprise_down_err;
wire                  cfg_rcrb_pcie_surp_dn_rpt_cap;


wire                  cfg_rcrb_auto_slot_pwr_lmt_dis;
wire                  cfg_rcrb_hp_slot_ctrl_access;
wire                  cfg_rcrb_dll_state_chged_en;
wire                  cfg_rcrb_cmd_cpled_int_en;
wire                  cfg_rcrb_pre_det_chged_en;
wire                  cfg_rcrb_mrl_sensor_chged_en;
wire                  cfg_rcrb_pwr_fault_det_en;
wire                  cfg_rcrb_atten_button_pressed_en;

wire [NF-1:0]         cfg_drs_msi_rciep;
assign                cfg_drs_msi = cxl_rcrb_enable ? {NF{cfg_rcrb_drs_msi}} : cfg_drs_msi_rciep ;
wire [NF-1:0]         cfg_up_drs_to_frs_rciep;
assign                cfg_up_drs_to_frs = cxl_rcrb_enable ? {NF{cfg_rcrb_up_drs_to_frs}} : cfg_up_drs_to_frs_rciep ;

assign                cfg_rcb = cxl_rcrb_enable ? {NF{cfg_rcrb_rcb}} : cfg_rcb_rciep ;
// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_cxl_port_reg
// ------------------------------------------------------------

input                 correctable_protocol_id_frame_err;
input                 uncorrectable_protocol_id_frame_err;
input                 unexpected_protocol_id_dropped;

output                cfg_cxl_port_cache_capable;
output                cfg_cxl_port_mem_capable;
output [15:0]         cfg_cxl_port_vid;
output                cfg_cxl_port_68B_flit_vh_capable;
output                cfg_cxl_port_mld_capable;
output                cfg_cxl_port_lopt_flit_capable;
output                cfg_cxl_port_pbr_flit_capable;
output                cfg_cxl_port_nop_hint_capable;
output                cfg_cxl_port_68B_flit_vh_enable;
output                cfg_cxl_port_mld_enable;
output                cfg_cxl_port_disable_cxl1p1_training;
output                cfg_cxl_port_cache_enable;
output                cfg_cxl_port_io_enable;
output                cfg_cxl_port_mem_enable;
output                cfg_cxl_port_sync_hdr_bypass_enable;
output                cfg_cxl_port_drift_buffer_enable;
output                cfg_cxl_port_retimer1_present;
output                cfg_cxl_port_retimer2_present;
output                cfg_cxl_port_retimers_pre_mismatched;
output                cfg_cxl_port_lopt_flit_enable;
output                cfg_cxl_port_pbr_flit_enable;
output                cfg_cxl_port_nop_hint_enable;

parameter NCXL_PORT           = `CXL_PORT_DVSEC_SIZE>>2;
wire  [NF-1:0][NCXL_PORT-1:0]   cfg_cxl_port_reg_id;
logic [NCXL_PORT-1:0]           cxl_port_reg_id;
wire  [31:0]                    cxl_port_reg_data;
logic [NCXL_PORT-1:0]           rcrb_cxl_port_reg_id;

    assign cxl_port_reg_id = (upstream_port & cxl_rcrb_enable) ? rcrb_cxl_port_reg_id : (rcrb_cxl_port_reg_id | cfg_cxl_port_reg_id[0]);

wire                  cfg_cxl_port_cache_capable;
wire                  cfg_cxl_port_mem_capable;
wire [15:0]           cfg_cxl_port_vid;
wire                  cfg_cxl_port_68B_flit_vh_capable;
wire                  cfg_cxl_port_mld_capable;
wire                  cfg_cxl_port_lopt_flit_capable;
wire                  cfg_cxl_port_pbr_flit_capable;
wire                  cfg_cxl_port_68B_flit_vh_enable;
wire                  cfg_cxl_port_mld_enable;
wire                  cfg_cxl_port_disable_cxl1p1_training;

wire                  cfg_cxl_port_cache_enable;
wire                  cfg_cxl_port_io_enable;
wire                  cfg_cxl_port_mem_enable;
wire                  cfg_cxl_port_sync_hdr_bypass_enable;
wire                  cfg_cxl_port_drift_buffer_enable;
wire                  cfg_cxl_port_retimer1_present;
wire                  cfg_cxl_port_retimer2_present;
wire                  cfg_cxl_port_retimers_pre_mismatched;

// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_cxl_device_reg
// ------------------------------------------------------------


input                 viral_status;
input                 pl_reg_viral_status_set;
input                 cxl_mode_enable;
input                                    cxl_dev_cache_invalid;
input                                    cxl_dev_cache_wr_invld_cmpl;
input                                    cxl_pm_init_cmpl;
input   [`CX_CXL_NLD_PLUS_1-1:0]         cxl_volatile_hdm_error;

output                cfg_cxl_pl_reg_viral_status;
output                cfg_cxl_viral_enable;
output                cfg_cxl_viral_status;

output                               cfg_cxl_dev_cache_enable;
output  [N_DEVICES-1:0]              cfg_cxl_dev_io_enable;
output  [N_DEVICES-1:0]              cfg_cxl_dev_mem_enable;
output  [4:0]                        cfg_cxl_dev_cache_sf_coverage;
output  [2:0]                        cfg_cxl_dev_cache_sf_granularity;
output                               cfg_cxl_dev_cache_clean_eviction;
output  [N_DEVICES-1:0]              cfg_cxl_dev_viral_enable;
output  [N_DEVICES-1:0]              cfg_cxl_dev_cxl_rst_mem_clr_enable;
output  [N_DEVICES-1:0]              cfg_cxl_dev_post_cold_rst_volatile_hdm_default;
output  [N_DEVICES-1:0]              cfg_cxl_dev_post_warm_rst_volatile_hdm_default;
output  [N_DEVICES-1:0]              cfg_cxl_dev_post_hot_rst_volatile_hdm_default;
output  [N_DEVICES-1:0]              cfg_cxl_dev_post_hot_rst_volatile_hdm_desired;

output  [N_DEVICES-1:0]              cfg_cxl_dev_viral_status;
output                               cfg_cxl_dev_disable_caching;
output                               cfg_cxl_dev_initiate_cache_wr_invld;
output  [N_DEVICES-1:0]              cfg_cxl_dev_initiate_cxl_rst;

output  [N_DEVICES-1:0][31:0]        cfg_cxl_dev_range1_mem_size_high;
output  [N_DEVICES-1:0]              cfg_cxl_dev_range1_mem_info_valid;
output  [N_DEVICES-1:0]              cfg_cxl_dev_range1_mem_active;
output  [N_DEVICES-1:0][4:0]         cfg_cxl_dev_range1_desired_interleave;
output  [N_DEVICES-1:0][2:0]         cfg_cxl_dev_range1_mem_active_timeout;
output  [N_DEVICES-1:0][3:0]         cfg_cxl_dev_range1_mem_size_low;
output  [N_DEVICES-1:0][31:0]        cfg_cxl_dev_range1_mem_base_high;
output  [N_DEVICES-1:0][3:0]         cfg_cxl_dev_range1_mem_base_low;

output  [N_DEVICES-1:0][31:0]        cfg_cxl_dev_range2_mem_size_high;
output  [N_DEVICES-1:0]              cfg_cxl_dev_range2_mem_info_valid;
output  [N_DEVICES-1:0]              cfg_cxl_dev_range2_mem_active;
output  [N_DEVICES-1:0][4:0]         cfg_cxl_dev_range2_desired_interleave;
output  [N_DEVICES-1:0][2:0]         cfg_cxl_dev_range2_mem_active_timeout;
output  [N_DEVICES-1:0][3:0]         cfg_cxl_dev_range2_mem_size_low;
output  [N_DEVICES-1:0][31:0]        cfg_cxl_dev_range2_mem_base_high;
output  [N_DEVICES-1:0][3:0]         cfg_cxl_dev_range2_mem_base_low;


wire [NF-1:0][14:0]   cxl_reg_id;
wire [NF-1:0][31:0]   cxl_reg_data;

wire                  cfg_cxl_viral_enable;
wire                  cfg_cxl_viral_status;
wire                                 cfg_cxl_dev_cache_enable;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_io_enable;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_mem_enable;
wire  [4:0]                          cfg_cxl_dev_cache_sf_coverage;
wire  [2:0]                          cfg_cxl_dev_cache_sf_granularity;
wire                                 cfg_cxl_dev_cache_clean_eviction;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_viral_capable;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_viral_enable;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_cxl_rst_mem_clr_enable;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_post_cold_rst_volatile_hdm_default;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_post_warm_rst_volatile_hdm_default;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_post_hot_rst_volatile_hdm_default;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_post_hot_rst_volatile_hdm_desired;

wire  [N_DEVICES-1:0]                cfg_cxl_dev_viral_status;
wire                                 cfg_cxl_dev_disable_caching;
wire                                 cfg_cxl_dev_initiate_cache_wr_invld;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_initiate_cxl_rst;

wire  [N_DEVICES-1:0][31:0]          cfg_cxl_dev_range1_mem_size_high;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_range1_mem_info_valid;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_range1_mem_active;
wire  [N_DEVICES-1:0][4:0]           cfg_cxl_dev_range1_desired_interleave;
wire  [N_DEVICES-1:0][2:0]           cfg_cxl_dev_range1_mem_active_timeout;
wire  [N_DEVICES-1:0][3:0]           cfg_cxl_dev_range1_mem_size_low;
wire  [N_DEVICES-1:0][31:0]          cfg_cxl_dev_range1_mem_base_high;
wire  [N_DEVICES-1:0][3:0]           cfg_cxl_dev_range1_mem_base_low;

wire  [N_DEVICES-1:0][31:0]          cfg_cxl_dev_range2_mem_size_high;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_range2_mem_info_valid;
wire  [N_DEVICES-1:0]                cfg_cxl_dev_range2_mem_active;
wire  [N_DEVICES-1:0][4:0]           cfg_cxl_dev_range2_desired_interleave;
wire  [N_DEVICES-1:0][2:0]           cfg_cxl_dev_range2_mem_active_timeout;
wire  [N_DEVICES-1:0][3:0]           cfg_cxl_dev_range2_mem_size_low;
wire  [N_DEVICES-1:0][31:0]          cfg_cxl_dev_range2_mem_base_high;
wire  [N_DEVICES-1:0][3:0]           cfg_cxl_dev_range2_mem_base_low;

// ------------------------------------------------------------
// Wire declaration for u_cdm_cxl_membar0
// ------------------------------------------------------------
parameter NCXL_MEMBAR0_CACHE_MEM  = `CXL_RCRB_MEMBAR0_CACHE_MEM_CAP_SIZE + 'd4 ; // Number of registers in CXL RCRB MEMBAR0
parameter NCXL_MEMBAR0_ARB_MUX    = `CXL_RCRB_MEMBAR0_ARB_MUX_SIZE ;       // Number of registers in CXL RCRB MEMBAR0
wire [NCXL_MEMBAR0_CACHE_MEM-1:0] cxl_mbar0_cache_mem_reg_id;// Register select for RCRB MEMBAR0 CACHE MEM
wire   [NCXL_MEMBAR0_ARB_MUX-1:0] cxl_mbar0_arb_mux_reg_id;// Register select for RCRB MEMBAR0 ARB/MUX
wire [3:0]                        cxl_mbar0_write_pulse;    //CXL RCRB MEMBAR0 Write Pulse
wire [31:0]                       cxl_mbar0_reg_data;       // Data read from RCRB MEMBAR0
wire                              rcrb_ras_uncorr_error;
wire                              cxl_pl_reg_ras_uncorr_err;
wire                              rcrb_ras_corr_error_level;
wire                              rcrb_ras_corr_error_pulse;
wire                              cxl_internal_uncorr_error;
wire                              mbar0_arb_mux_uncorr_err;
assign                            cxl_internal_uncorr_error = rcrb_ras_uncorr_error | mbar0_arb_mux_uncorr_err;
wire [(NF*NCXL_MEMBAR0_CACHE_MEM)-1:0] cxl_mbar0_cache_mem_reg_id_downstream;// Register select for RCRB MEMBAR0 CACHE MEM
wire [(NF*NCXL_MEMBAR0_ARB_MUX)-1:0] cxl_mbar0_arb_mux_reg_id_downstream;// Register select for RCRB MEMBAR0 ARB/MUX
wire [(4*NF)-1:0]                 cxl_mbar0_write_pulse_downstream;    //CXL RCRB MEMBAR0 Write Pulse
wire [31:0]                       cxl_mbar0_reg_data_downstream;       // Data read from RCRB MEMBAR0

wire [NCXL_MEMBAR0_CACHE_MEM-1:0] cxl_mbar0_cache_mem_reg_id_mux;// Register select for RCRB MEMBAR0 CACHE MEM
wire   [NCXL_MEMBAR0_ARB_MUX-1:0] cxl_mbar0_arb_mux_reg_id_mux;// Register select for RCRB MEMBAR0 ARB/MUX
wire [3:0]                        cxl_mbar0_write_pulse_mux;    //CXL RCRB MEMBAR0 Write Pulse

assign cxl_mbar0_cache_mem_reg_id_mux = (upstream_port & ~cxl_mbar0_enable) ? cxl_mbar0_cache_mem_reg_id : cxl_mbar0_cache_mem_reg_id_downstream[NCXL_MEMBAR0_CACHE_MEM-1:0];
assign cxl_mbar0_arb_mux_reg_id_mux   = (upstream_port & ~cxl_mbar0_enable) ? cxl_mbar0_arb_mux_reg_id   : cxl_mbar0_arb_mux_reg_id_downstream[NCXL_MEMBAR0_ARB_MUX-1:0];
assign cxl_mbar0_write_pulse_mux      = (upstream_port & ~cxl_mbar0_enable) ? cxl_mbar0_write_pulse      : cxl_mbar0_write_pulse_downstream[3:0];


// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_rcrb_error_reg
// ------------------------------------------------------------
wire [3:0]  ecfg_rcrb_write_pulse;
wire        ecfg_rcrb_read_pulse;
wire [ERR_REG_ID_WD-1:0] rcrb_err_reg_id;
wire        cfg_rcrb_corrected_internal_err_sts_int;

wire [((4*NF)-1):0]  rcrb_err_write_pulse;
wire [(NF-1):0]      rcrb_err_read_pulse;
wire [((ERR_REG_ID_WD*NF)-1):0] rcrb_err_reg_id_mod;

wire [NF-1:0]        internal_err_mod;
wire [NF-1:0]        corr_internal_err_mod;


// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_cxl_2_0_ext_reg
// ------------------------------------------------------------

output                 cfg_cxl_2_0_ext_viral_status;              // Switch has entered Viral
output                 cfg_cxl_2_0_ext_unmask_sbr;                // Unmask SBR
output                 cfg_cxl_2_0_ext_unmask_ld;                 // Unmask Link Disable
output                 cfg_cxl_2_0_ext_alt_mse;                   // Alternate Memory Space Enable
output                 cfg_cxl_2_0_ext_alt_bme;                   // Alternate Bus Master Enable
output                 cfg_cxl_2_0_ext_viral_en;                  // Viral Enable for Switch
output [7:0]           cfg_cxl_2_0_ext_alt_bus_base;              // Alternate Bus Base
output [7:0]           cfg_cxl_2_0_ext_alt_bus_limit;             // Alternate Bus Limit
output [11:0]          cfg_cxl_2_0_ext_alt_mem_base;              // Alternate Memory Base
output [11:0]          cfg_cxl_2_0_ext_alt_mem_limit;             // Alternate Memory Limit
output [11:0]          cfg_cxl_2_0_ext_alt_pref_mem_base;         // Alternate Prefetchable Memory Base
output [11:0]          cfg_cxl_2_0_ext_alt_pref_mem_limit;        // Alternate Memory Limit
output [31:0]          cfg_cxl_2_0_ext_alt_pref_mem_base_high;    // Alternate Prefetchable Memory Base High
output [31:0]          cfg_cxl_2_0_ext_alt_pref_mem_limit_high;   // Alternate Prefetchable Memory Base High
output                 cfg_cxl_2_0_ext_rcrb_en;                   // CXL RCRB Enable
output [18:0]          cfg_cxl_2_0_ext_rcrb_base_addr_low;        // CXL RCRB Base Address Low
output [31:0]          cfg_cxl_2_0_ext_rcrb_base_addr_high;       // RCRB Base Address High

wire [(10*NF)-1:0]     cxl_2_0_ext_reg_id;
wire [31:0]            cxl_2_0_ext_reg_data;

// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_cxl_reg_locator_reg
// ------------------------------------------------------------

output [N_DEVICES-1:0][63:0]       cxl_2_0_comp_reg_offset;                                // CXL 2.0 Comp Specific Register Offset within Func 0, BAR0
output [N_DEVICES-1:0][2:0]        cfg_cxl_reg_locator_reg1_bir;
output [N_DEVICES-1:0][7:0]        cfg_cxl_reg_locator_reg1_blk_identifier;
output [N_DEVICES-1:0][15:0]       cfg_cxl_reg_locator_reg1_blk_offset_low;
output [N_DEVICES-1:0][31:0]       cfg_cxl_reg_locator_reg1_blk_offset_high;
output [N_DEVICES-1:0][2:0]        cfg_cxl_reg_locator_reg2_bir;
output [N_DEVICES-1:0][7:0]        cfg_cxl_reg_locator_reg2_blk_identifier;
output [N_DEVICES-1:0][15:0]       cfg_cxl_reg_locator_reg2_blk_offset_low;
output [N_DEVICES-1:0][31:0]       cfg_cxl_reg_locator_reg2_blk_offset_high;
output [N_DEVICES-1:0][2:0]        cfg_cxl_reg_locator_reg3_bir;
output [N_DEVICES-1:0][7:0]        cfg_cxl_reg_locator_reg3_blk_identifier;
output [N_DEVICES-1:0][15:0]       cfg_cxl_reg_locator_reg3_blk_offset_low;
output [N_DEVICES-1:0][31:0]       cfg_cxl_reg_locator_reg3_blk_offset_high;

wire [NF-1:0][8:0]                 cxl_reg_locator_reg_id;
wire [NF-1:0][31:0]                cxl_reg_locator_reg_data;

wire [NF-1:0][63:0]                cxl_2_0_comp_reg_offset_in;

// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_cxl_gpf_port_reg
// ------------------------------------------------------------
output [3:0]           cfg_cxl_gpf_port_p1_timeout_base;
output [3:0]           cfg_cxl_gpf_port_p1_timeout_scale;
output [3:0]           cfg_cxl_gpf_port_p2_timeout_base;
output [3:0]           cfg_cxl_gpf_port_p2_timeout_scale;

wire [(4*NF)-1:0]      cxl_gpf_port_reg_id;
wire [31:0]            cxl_gpf_port_reg_data;

// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_cxl_gpf_device_reg
// ------------------------------------------------------------

wire [NF-1:0][3:0]     cxl_gpf_device_reg_id;
wire [NF-1:0][31:0]    cxl_gpf_device_reg_data;





// -------------------------------------------------------------------------------------------------
// ------------------------------------------------------------
// Port and Wire declaration for u_cdm_dev3_reg
// ------------------------------------------------------------

wire [NF*3-1:0]          int_cfg_target_link_width;        
wire [NF -1:0]           int_cfg_l0p_en;               //L0p Enable
wire [NF-1:0]            int_remote_l0p_supported;   
wire [NF-1:0]            int_cfg_receiver_l0p_supported;   
wire                     cfg_receiver_l0p_supported;
assign                   cfg_receiver_l0p_supported = int_cfg_receiver_l0p_supported[0];
wire                     cfg_remote_l0p_supported;
assign                   cfg_remote_l0p_supported = int_remote_l0p_supported[0];
wire                     int_cfg_l0p_dynamic_priority;
wire                     int_cfg_aspm_l0p_dynamic_disable;            
wire                     int_cfg_direct_l0p_dynamic_link_width_change;
wire                     l0p_dynamic_write;
wire    [2:0]            int_cfg_l0p_dynamic_target_link_width;   
wire                     int_cfg_l0p_normal_priority;   
// ------------------------------------------------------------

wire   [NF-1:0]                 rasdes_reg_sel;                // RAS DES register select
wire   [(64*NF)-1:0]            rasdes_reg_id;                 // RAS DES register ID
wire   [31:0]                   rasdes_reg_data;               // RAS DES register read data
wire                            rasdes_reg_ack;                // RAS DES register acknowledge
wire   [ERROR_TLP_WD:0]               cfg_poisned_tlp_int ;          // Pulse : Poisoned TLP Event for Ras D.E.S event counter
wire   [ERROR_TLP_WD:0]               cfg_ecrc_tlp_err_int ;         // Pulse : ECRC Error TLP Event for Ras D.E.S event counter
wire   [ERROR_TLP_WD:0]               cfg_ur_tlp_int ;               // Pulse : UR Error TLP Event for Ras D.E.S event counter
wire   [ERROR_TLP_WD:0]               cfg_ca_tlp_int ;               // Pulse : Completer Abort TLP Event for Ras D.E.S event counter
wire   [1:0]                    cfg_cpl_timeout_int ;          // Pulse : Completion Timeout Event for Ras D.E.S event counter
reg    [ERROR_TLP_WD:0]               cfg_poisned_tlp ;              // Pulse : Poisoned TLP Event for Ras D.E.S event counter
reg    [ERROR_TLP_WD:0]               cfg_ecrc_tlp_err ;             // Pulse : ECRC Error TLP Event for Ras D.E.S event counter
reg    [ERROR_TLP_WD:0]               cfg_ur_tlp ;                   // Pulse : UR Error TLP Event for Ras D.E.S event counter
reg    [ERROR_TLP_WD:0]               cfg_ca_tlp ;                   // Pulse : Completer Abort TLP Event for Ras D.E.S event counter
reg    [1:0]                    cfg_cpl_timeout ;              // Pulse : Completion Timeout Event for Ras D.E.S event counter
wire                            app_malformed_tlp;             // Pulse : Malformed TLP status for Ras D.E.S Silicon debug
wire   [`CX_LUT_PL_WD-1:0]      cfg_lut_ctrl;                  //lane under test + gen5 control

// cfg_esm_eq_clear looks like a EQ Entry pulse for ESM and PCIe switching or ESM rate changing
wire smlh_ls2_eq_enter_i = smlh_ls2_eq_enter;
wire smlh_ls2_g4_eq_enter_i = smlh_ls2_g4_eq_enter;

wire    [5:0]                    cfg_pcie_max_link_width;   // Max Link Width (function 0)
assign  cfg_pcie_max_link_width = cxl_rcrb_enable ? pf_cfg_rcrb_pcie_max_link_width_bus[5:0] : pf_cfg_pcie_max_link_width_bus[5:0];    // max link width of function 0

wire   cdm_clk_g_int;

// The following code generates the enable signal for the cdm_clk_g clock.
// The enbale is on when any of the following signals is set: "lbc_cdm_cs" , "flr_in_progress" , "en_cdm_clk_g_temp" and "cdm_clk_g_ext”.
// "en_cdm_clk_g_temp" gets asserted based on the assertion of "lbc_cdm_cs" or "flr_in_progress"
// "en_cdm_clk_g_temp" gets deasserted when detecing the failing edge of "cdm_lbc_ack".
// "en_cdm_clk_g_temp" is extended for a configurable number of cycles for safety, CX_CDM_CLK_GATING_EXTENDED_CYCLES is a parameter used to set the number of extra cycles.
// configurable number of extended cycles are added for safety
// To assert the enable without delay and as soon as the "lbc_cdm_cs" is asserted; "lbc_cdm_cs" is ORed with "en_cdm_clk_g_temp".
// When this feature is not enabled "cdm_clk_g" is assigned the value of "core_clk"

assign cdm_clk_g_int = core_clk;


// PCIe L0p Configuration Interface
assign cfg_l0p_receiver_support = cfg_receiver_l0p_supported && int_cfg_l0p_en[0];
assign cfg_l0p_enable           = cfg_receiver_l0p_supported && cfg_remote_l0p_supported && int_cfg_l0p_en[0];
assign cfg_l0p_autowidth_dis    = cfg_hw_autowidth_dis;
assign cfg_l0p_priority         = int_cfg_l0p_normal_priority;
assign cfg_l0p_linkmode         = int_cfg_target_link_width[2:0];
// Write pulse on Device Capabilities 3 Register
assign cfg_l0p_linkmode_req     = (dev3_reg_id[2] && ecfg_write_pulse[0][0] && lbc_cdm_data[3]);
assign cfg_l0p_max_link_width   = cfg_pcie_max_link_width;
assign cfg_l0p_neg_link_width   = cfg_neg_link_width;

// PCIe/CXL.io Dynamic L0p Configuration Interface
assign cfg_pcie_l0p_disable     = int_cfg_aspm_l0p_dynamic_disable;
assign cfg_pcie_l0p_request     = l0p_dynamic_write && int_cfg_direct_l0p_dynamic_link_width_change;
assign cfg_pcie_l0p_priority    = int_cfg_l0p_dynamic_priority;
assign cfg_pcie_l0p_linkmode    = int_cfg_l0p_dynamic_target_link_width;
// CXL.cachemem Dynamic L0p Configuration Interface (TBD)
assign cfg_cxl_l0p_disable      = '0;
assign cfg_cxl_l0p_request      = '0;
assign cfg_cxl_l0p_priority     = '0;
assign cfg_cxl_l0p_linkmode     = '0;


assign  cfg_ido_req_en[NF-1:0] = pf_cfg_ido_req_en[NF-1:0];
assign  cfg_ido_cpl_en[NF-1:0] = pf_cfg_ido_cpl_en[NF-1:0];

wire [(8*NF)-1:0]    int_cfg_pbus_num;               // intermediate primary Bus number used to transform between different width
wire [(5*NF)-1:0]    int_cfg_pbus_dev_num;           // intermediate device number used to transform between different width

wire [NF-1:0]                      cfg_uncor_internal_err_sts_int        ;
wire [NF-1:0]                      cfg_rcvr_overflow_err_sts_int         ;
wire [NF-1:0]                      cfg_fc_protocol_err_sts_int           ;
wire [NF-1:0]                      cfg_mlf_tlp_err_sts_int               ;
wire [NF-1:0]                      cfg_surprise_down_er_sts_int          ;
wire [NF-1:0]                      cfg_dl_protocol_err_sts_int           ;
wire [NF-1:0]                      cfg_ecrc_err_sts_int                  ;
wire [NF-1:0]                      cfg_corrected_internal_err_sts_int    ;
wire [NF-1:0]                      cfg_replay_number_rollover_err_sts_int;
wire [NF-1:0]                      cfg_replay_timer_timeout_err_sts_int  ;
wire [NF-1:0]                      cfg_bad_dllp_err_sts_int              ;
wire [NF-1:0]                      cfg_bad_tlp_err_sts_int               ;
wire [NF-1:0]                      cfg_rcvr_err_sts_int                  ;

assign cfg_uncor_internal_err_sts         = cfg_uncor_internal_err_sts_int[0]        ;
assign cfg_rcvr_overflow_err_sts          = cfg_rcvr_overflow_err_sts_int[0]         ;
assign cfg_fc_protocol_err_sts            = cfg_fc_protocol_err_sts_int[0]           ;
assign cfg_mlf_tlp_err_sts                = cfg_mlf_tlp_err_sts_int[0]               ;
assign cfg_surprise_down_er_sts           = cfg_surprise_down_er_sts_int[0]          ;
assign cfg_dl_protocol_err_sts            = cfg_dl_protocol_err_sts_int[0]           ;
assign cfg_ecrc_err_sts                   = cfg_ecrc_err_sts_int[0]                  ;
assign cfg_corrected_internal_err_sts     = cfg_corrected_internal_err_sts_int[0]    ;
assign cfg_replay_number_rollover_err_sts = cfg_replay_number_rollover_err_sts_int[0];
assign cfg_replay_timer_timeout_err_sts   = cfg_replay_timer_timeout_err_sts_int[0]  ;
assign cfg_bad_dllp_err_sts               = cfg_bad_dllp_err_sts_int[0]              ;
assign cfg_bad_tlp_err_sts                = cfg_bad_tlp_err_sts_int[0]               ;
assign cfg_rcvr_err_sts                   = cfg_rcvr_err_sts_int[0]                  ;




// Errors
wire    [NF-1:0]        cfg_f_err_det;
wire    [NF-1:0]        cfg_nf_err_det;
wire    [NF-1:0]        cfg_cor_err_det;
wire    [NF-1:0]        cfg_unsupt_req_det;
wire    [NF-1:0]        cfg_cor_err_rpt_en;
wire    [NF-1:0]        cfg_nf_err_rpt_en;
wire    [NF-1:0]        cfg_f_err_rpt_en;
wire    [NF-1:0]        cfg_unsupt_req_rpt_en;
wire    [NF-1:0]        ecfg_read_pulse;
wire    [NF-1:0]        cfg_br_ctrl_serren;
wire    [NF-1:0]        cfg_br_ctrl_perren;
wire    [NF-1:0]        cfg_reg_perren;

wire    [NF-1:0]        int_ext_synch;
wire    [NF-1:0]        int_link_dis;
wire    [NF-1:0]        int_link_retrain;
wire    [NF-1:0]        int_cfg_comm_clk_config;
wire    [NF-1:0]        int_cfg_hw_autowidth_dis;
wire    [(2*NF)-1:0]    int_cfg_aslk_pmctrl;
wire    [NF-1:0]        int_cfg_upd_aslk_pmctrl;
wire    [NF-1:0]        cfg_upd_aslk_pmctrl;
wire    [NF-1:0]        cfg_pcie_surp_dn_rpt_cap;

wire    [(NVC*8)-1:0]   cfg_fc_credit_ph;
wire    [(NVC*8)-1:0]   cfg_fc_credit_nph;
wire    [(NVC*8)-1:0]   cfg_fc_credit_cplh;
wire    [(NVC*12)-1:0]  cfg_fc_credit_pd;
wire    [(NVC*12)-1:0]  cfg_fc_credit_npd;
wire    [(NVC*12)-1:0]  cfg_fc_credit_cpld;
wire    [(NVC*9)-1:0]   cfg_radm_q_mode;
wire    [NVC-1:0]       cfg_radm_order_rule;
wire    [15:0]          cfg_order_rule_ctrl;        // cpl_pass_p_if_phalted[7:0], np_pass_p_if_phalted[7:0] one for each VC
wire    [2:0]           cfg_clock_gating_ctrl;          // Enable/Disable clock gating
wire    [31:0]          cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry
wire                    cfg_radm_strict_vc_prior;
wire    [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]     cfg_hq_depths;
wire    [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]    cfg_dq_depths;

wire    [NF-1:0]        master_data_perr_det;
wire    [NF-1:0]        signaled_target_abort_det;
wire    [NF-1:0]        rcvd_target_abort_det;
wire    [NF-1:0]        rcvd_master_abort_det;
wire    [NF-1:0]        signaled_sys_err_det;
wire    [NF-1:0]        perr_det;
wire    [NF-1:0]        master_data_perr_det2;
wire    [NF-1:0]        signaled_target_abort_det2;
wire    [NF-1:0]        rcvd_target_abort_det2;
wire    [NF-1:0]        rcvd_master_abort_det2;
wire    [NF-1:0]        signaled_sys_err_det2;
wire    [NF-1:0]        perr_det2;


wire    [(NF*5)-1:0]    cfg_pcie_cap_int_msg_num;   // Interrupt Message Number
wire    [NF-1:0]        cfg_ari_fwd_en;
wire    [(NF*4)-1:0]    cfg_cpl_timeout_range;      // Completion timeout range
wire    [NF-1:0]        cfg_rprt_err_cor;           // System Error factor by Correctable Error
wire    [NF-1:0]        cfg_rprt_err_nf;            // System Error factor by Non-Fatal Error
wire    [NF-1:0]        cfg_rprt_err_f;             // System Error factor by Fatal Error

wire    [4*NF-1:0]      pf_cfg_pcie_max_link_speed_bus;
wire    [3:0]           cfg_pcie_max_link_speed;   // Supported link speed
wire    [3:0]           cfg_target_link_speed;      // Target link speed
wire                    cfg_sel_de_emphasis;
wire                    cfg_up_sel_deemph;
wire    [2:0]           cfg_transmit_margin;            // controls the value of the non-deemphasized voltage level at the Transmitter pins.
wire                    cfg_enter_mod_compliance;
wire                    cfg_compliance_sos;
wire    [3:0]           cfg_compliance_de_emphasis;
assign                  cfg_pcie_max_link_speed = cxl_rcrb_enable ? pf_cfg_rcrb_pcie_max_link_speed_bus[4*(1+0)-1:4*0] : pf_cfg_pcie_max_link_speed_bus[4*(1+0)-1:4*0];


reg     [NF-1:0]             rtlh_overfl_err_d;
always @(posedge core_clk or negedge sticky_rst_n)
begin : rtlh_overfl_d_PROC
    if (!sticky_rst_n)
        rtlh_overfl_err_d <= #TP 0;
    else
        rtlh_overfl_err_d <= #TP rtlh_overfl_err;
end

// Device Types
wire    end_device;
wire    rc_device;
wire    pcie_sw_up;
wire    pcie_sw_down;
wire    switch_device;
wire    pcie_br_up;
wire    pcie_br_down;
wire    bridge_device;
wire    upstream_port;
assign end_device       = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_up       = (device_type == `PCIE_SW_UP);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign switch_device    = pcie_sw_up | pcie_sw_down | bridge_device;
assign pcie_br_up       = (device_type == `PCIE_PCIX);
assign pcie_br_down     = (device_type == `PCIX_PCIE);
assign bridge_device    = pcie_br_up | pcie_br_down;
assign upstream_port    = end_device | pcie_br_up | pcie_sw_up;



assign cfg_acs_validation_cap  = cfg_acs_validation_cap_num[0];
assign cfg_acs_at_blocking_cap = cfg_acs_at_blocking_cap_num[0];
assign cfg_acs_up_forward_cap  = cfg_acs_up_forward_cap_num[0];
assign cfg_acs_validation_en   = cfg_acs_validation_en_num[0];
assign cfg_acs_at_blocking_en  = cfg_acs_at_blocking_en_num[0];
assign cfg_acs_up_forward_en   = cfg_acs_up_forward_en_num[0];


assign cfg_sel_de_emphasis = upstream_port ? cfg_up_sel_deemph : cxl_rcrb_enable ? int_cfg_rcrb_sel_de_emphasis : int_cfg_sel_de_emphasis[0];

//Interrupt indicating that the Link Equalization Request bit has been set
assign cfg_link_eq_req_int = (cfg_link_eq_req_int_en & (cfg_ls2_eq_req | cfg_ls2_g4_eq_req | cfg_ls2_g5_eq_req | cfg_ls2_g6_eq_req));


//This is to be used by the RADM to filter incoming TLPs larger than max allowed.
// before the RADM was receiving the highest MPS between all functions,but now as for PCIe6 flit mode it is always equal to MPS_sup.

//In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
wire [3*NF-1:0] cfg_max_payload_size_out_rx_int;
wire [2:0] cfg_max_payload_size_out_rx;
assign cfg_max_payload_size_out_rx = cfg_max_payload_size_out_rx_int[2:0];



reg [2:0] cfg_highest_max_payload;
// For a single function, highest max payload is function 0's max payload.
always @(cfg_max_payload_size)
begin: gen_max_payload_1f
    cfg_highest_max_payload = cfg_max_payload_size[2:0];
end

reg [2:0] cfg_smallest_max_payload;
// For a single function, smallest max payload is function 0's max payload.
always @(cfg_max_payload_size)
begin: gen_min_payload_1f
    cfg_smallest_max_payload = cfg_max_payload_size[2:0];
end

// =============================================================================
// Extract Function 0 Specific Signals
// =============================================================================
assign cfg_2ndbus_num = int_cfg_2ndbus_num[7:0];
assign cfg_subbus_num = int_cfg_subbus_num[7:0];

assign cfg_sys_err_rc               = int_cfg_sys_err_rc[0];                  // RC Only: System error
assign cfg_crs_sw_vis_en            = int_cfg_crs_sw_vis_en[0];               // Root ctrl CRS Software Visibility feature enable
assign cfg_pme_int                  = int_cfg_pme_int[0];                     // RC Only: Interrupt caused by PME
assign cfg_pme_msi                  = int_cfg_pme_msi[0];                     // RC Only: MSI caused by PME
assign cfg_link_auto_bw_int         = cxl_rcrb_enable ? int_cfg_rcrb_link_auto_bw_int : int_cfg_link_auto_bw_int[0];            // Interrupt indicating that Link Bandwidth Management Status bit has been set
assign cfg_link_auto_bw_msi         = cxl_rcrb_enable ? int_cfg_rcrb_link_auto_bw_msi : int_cfg_link_auto_bw_msi[0];            // MSI Interrupt indicating that Link Bandwidth Management Status bit has been set
assign cfg_bw_mgt_int               = cxl_rcrb_enable ? int_cfg_rcrb_bw_mgt_int : int_cfg_bw_mgt_int[0];                  // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
assign cfg_bw_mgt_msi               = cxl_rcrb_enable ? int_cfg_rcrb_bw_mgt_msi : int_cfg_bw_mgt_msi[0];                  // MSI Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
assign cfg_target_link_speed        = cxl_rcrb_enable ? int_cfg_rcrb_target_link_speed : int_cfg_target_link_speed[3:0];         // Target link speed
assign cfg_enter_compliance         = cxl_rcrb_enable ? int_cfg_rcrb_enter_compliance : int_cfg_enter_compliance[0];            // Directed enter compliance
assign cfg_hw_auto_sp_dis           = cxl_rcrb_enable ? int_cfg_rcrb_hw_auto_sp_dis : int_cfg_hw_auto_sp_dis[0];              // HW autonomous speed disable
assign cfg_transmit_margin          = cxl_rcrb_enable ? int_cfg_rcrb_transmit_margin : int_cfg_transmit_margin[2:0];           // controls the value of the non-deemphasized voltage level at the Transmitter pins.
assign cfg_enter_mod_compliance     = cxl_rcrb_enable ? int_cfg_rcrb_enter_mod_compliance : int_cfg_enter_mod_compliance[0];        // Directed enter modified compliance
assign cfg_compliance_sos           = cxl_rcrb_enable ? int_cfg_rcrb_compliance_sos : int_cfg_compliance_sos[0];              // Send skips during compliance
assign cfg_compliance_de_emphasis   = cxl_rcrb_enable ? int_cfg_rcrb_compliance_de_emphasis : int_cfg_compliance_de_emphasis[3:0];    // compliance de-emphasis level
assign cfg_pcie_crosslink_supported = cxl_rcrb_enable ? int_cfg_rcrb_pcie_crosslink_supported : int_cfg_pcie_crosslink_supported[0];    // Crosslink Supported
assign cfg_ls2_eq_req               = cxl_rcrb_enable ? int_cfg_rcrb_ls2_eq_req : int_cfg_ls2_eq_req[0];                  // Link Status2 Request Equalization
assign cfg_ls2_g4_eq_req            = int_cfg_ls2_g4_eq_req;
assign cfg_ls2_g5_eq_req            = int_cfg_ls2_g5_eq_req;               // gen5 Link Status2 Request Equalization
assign cfg_ls2_g6_eq_req            = int_cfg_ls2_g6_eq_req;               // gen5 Link Status2 Request Equalization
assign cfg_vc_enable                = cxl_rcrb_enable ? rcrb_int_cfg_vc_enable[NVC-1:0] :
                                       int_cfg_vc_enable[NVC-1:0] ;             // Which VCs are enabled - VC0 is always enabled
assign cfg_vc_struc_vc_id_map       = cxl_rcrb_enable ? rcrb_int_cfg_vc_struc_vc_id_map[(NVC*3)-1:0] :
                                       int_cfg_vc_struc_vc_id_map[(NVC*3)-1:0] ;// VC Structure to VC ID mapping
assign cfg_vc_id_vc_struc_map       = cxl_rcrb_enable ? rcrb_int_cfg_vc_id_vc_struc_map[23:0] :
                                       int_cfg_vc_id_vc_struc_map[23:0] ;       // VC ID to VC Structure mapping
assign cfg_tc_enable                = cxl_rcrb_enable ? rcrb_int_cfg_tc_enable[7:0] :
                                       int_cfg_tc_enable[7:0] ;                 // Which TCs are enabled

assign cfg_tc_vc_map_bcm36          = cxl_rcrb_enable ? rcrb_int_cfg_tc_vc_map[23:0] :
                                       int_cfg_tc_vc_map[23:0] ;                // TC to VC ID mapping
assign cfg_lpvc                     = cxl_rcrb_enable ? rcrb_int_cfg_lpvc[2:0] :
                                       int_cfg_lpvc[2:0] ;                      // Low Priority Extended VC (LPVC) Count

assign cfg_tc_struc_vc_map_bcm36    = cxl_rcrb_enable ?  rcrb_int_cfg_tc_struc_vc_map[23:0] :

                                       int_cfg_tc_struc_vc_map[23:0] ;          // TC to VC Structure mapping
assign cfg_vc_arb_sel               = cxl_rcrb_enable ? rcrb_int_cfg_vc_arb_sel[2:0] :
                                       int_cfg_vc_arb_sel[2:0] ;                // VC Arbitration Select
assign cfg_aer_rc_err_int           = int_cfg_aer_rc_err_int[0];              // RC Only: Error interrupt
assign cfg_aer_rc_err_msi           = int_cfg_aer_rc_err_msi[0];              // RC Only: Error MSI/MSI-X
assign cfg_aer_int_msg_num          = int_cfg_aer_int_msg_num[4:0];

assign  cfg_obff_en                 = int_cfg_obff_en[1:0];                   // Function 0 defines OBFF support for whole device.
wire ltr_m_en_fn0;                                                            // LTR Enable function 0
assign  ltr_m_en_fn0                = int_cfg_ltr_m_en[0];
wire cfg_ltr_m_en;                                                            // LTR Enable
assign  cfg_ltr_m_en                = ltr_m_en_fn0;                           // Only function 0 controls the component's LTR behaviour
wire cdm2msgg_ltr_clr_msg_req;                                                // Internal LTR clear message request
assign cdm2msgg_ltr_clr_msg_req     = |(int_cdm2msgg_ltr_clr_msg_req);         // Any function can generate a LTR clear message request

DWC_pcie_ctl_bcm36_nhs
 #(
.WIDTH      ($bits({cfg_tc_struc_vc_map,cfg_tc_vc_map})),
.DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_cfg_tc_struc_vc_map (
`ifndef SYNTHESIS
.clk_d   (core_clk),
.rst_d_n (sticky_rst_n),
`endif // SYNTHESIS
.data_s  ({cfg_tc_struc_vc_map_bcm36,cfg_tc_vc_map_bcm36}),
.data_d  ({cfg_tc_struc_vc_map,cfg_tc_vc_map})
);

// =============================================================================
// Assert completion timeout error for the appropriate function
reg     [NF-1:0]    int_radm_cpl_timeout_pf;
wire    [NF-1:0]    radm_cpl_timeout_pf;
always @(*)
begin: get_radm_cpl_timeout_pf
integer j;
    int_radm_cpl_timeout_pf = 0;
    for (j = 0; j<NF; j=j+1) begin
        if ((j == radm_timeout_func_num)
            && radm_cpl_timeout
           ) begin
            int_radm_cpl_timeout_pf[j] = 1'b1;
        end
    end
end
assign radm_cpl_timeout_pf = int_radm_cpl_timeout_pf;



 // Header Log Error Serialize -----------------------------------------------------------
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_hdr_log_valid;      // TLP Header is ready for error logged
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_mlf_tlp_err;        // Received malformed TLP
 reg   [(ERROR_TLP_WD*NF)-1:0] radm_rcvd_acs_err;        // Access Control Services feature: TLP ACS invalid
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_req_ur;        // Received request that was unsupported
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_req_ca;        // Received request that would cause Completer Abort
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_wreq_poisoned; // Received a poisoned write request
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_cpl_poisoned;  // Received a completion marked poisoned
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_cpl_ur;           // Received completion with UR status
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_cpl_ca;           // Received completion with CA status
 reg   [(ERROR_TLP_WD*NF)-1:0]   radm_ecrc_err;           // Received ECRC errors
 reg  [(ERROR_TLP_WD*NF)-1:0]   radm_unexp_cpl_err;         // Received unexpected Completion
 
 

 always @(*)
begin: get_func_spec_cdm_error
integer j;
integer f;
   for (f=0; f<ERROR_TLP_WD; f=f+1) begin
    for (j = 0; j<NF; j=j+1) begin

            radm_hdr_log_valid[NF*f+j]       = (radm_hdrlog.valid_pf == 1'b1 && f==0)? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_mlf_tlp_err[NF*f+j]         = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == MALFORMED_TLP)? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_rcvd_acs_err[NF*f+j]        = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == ACS_VIOLATION)? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;     
            radm_rcvd_req_ur[NF*f+j]         = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == UNSUPP_REQUEST && (radm_hdrlog.fc != E_CPL))? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_rcvd_req_ca[NF*f+j]         = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == COMPLETER_ABORT && (radm_hdrlog.fc != E_CPL))? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_rcvd_cpl_ur[NF*f+j]         = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == UNSUPP_REQUEST && (radm_hdrlog.fc == E_CPL))? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_rcvd_cpl_ca[NF*f+j]         = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == COMPLETER_ABORT && (radm_hdrlog.fc == E_CPL))? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_rcvd_wreq_poisoned[NF*f+j]  = ((radm_hdrlog.valid_pf == 1'b1 && f==0) && (radm_hdrlog.fc == E_P || radm_hdrlog.fc == E_NP)
                                                && (radm_hdrlog.err_idx == POISONED_TLP_RECEIVED))? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_rcvd_cpl_poisoned[NF*f+j]   = ((radm_hdrlog.valid_pf == 1'b1 && f==0) && (radm_hdrlog.fc == E_CPL)
                                                && (radm_hdrlog.err_idx == POISONED_TLP_RECEIVED))? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_ecrc_err[NF*f+j]            = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == ECRC_CHK_FAILED)? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
            radm_unexp_cpl_err[NF*f+j]       = (radm_hdrlog.valid_pf == 1'b1 && f==0 && radm_hdrlog.err_idx == UNEXP_COMPLETION)? ( (j == radm_hdrlog.pf)? 1'b1 : !radm_hdrlog.f_spec_err ):1'b0;
    end // for loop j 
   end // for loop f
end

 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_mlf_tlp_err_int ;        // Received malformed TLP
 wire   [(ERROR_TLP_WD*NF)-1:0] radm_rcvd_acs_err_int;        // Access Control Services feature: TLP ACS invalid
 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_req_ca_int;        // Received request that would cause Completer Abort
 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_cpl_ur_int;
 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_cpl_ca_int;
 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_wreq_poisoned_int; // Received a poisoned write request
 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_rcvd_cpl_poisoned_int;  // Received a completion marked poisoned
 wire   [(ERROR_TLP_WD*NF)-1:0]   radm_ecrc_err_int;           // Received ECRC errors
 wire  [(ERROR_TLP_WD*NF)-1:0]   radm_unexp_cpl_err_int;         // Received unexpected Completion
 assign  radm_mlf_tlp_err_int =  radm_mlf_tlp_err;        // Received malformed TLP
 assign radm_rcvd_acs_err_int = radm_rcvd_acs_err;        // Access Control Services feature: TLP ACS invalid
 assign radm_rcvd_req_ca_int  = radm_rcvd_req_ca;        // Received request that would cause Completer Abort
 assign radm_rcvd_cpl_ca_int  = radm_rcvd_cpl_ca;
 assign radm_rcvd_cpl_ur_int  = radm_rcvd_cpl_ur;
 assign radm_rcvd_wreq_poisoned_int = radm_rcvd_wreq_poisoned; // Received a poisoned write request
 assign radm_rcvd_cpl_poisoned_int = radm_rcvd_cpl_poisoned;  // Received a completion marked poisoned
 assign radm_ecrc_err_int          = radm_ecrc_err;           // Received ECRC errors
 assign radm_unexp_cpl_err_int = radm_unexp_cpl_err;         // Received unexpected Completion

 
 //--------------------------------------------------------------------------------------





// =============================================================================
// Mux error signals between the radm and app
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_hdr_log_valid;
wire    [NF-1:0]    cdm_hdr_log_valid_reg;
wire    [HDR_SIZE-1:0]   cdm_hdr_log;
wire    [HDR_SIZE-1:0]   cdm_hdr_log_reg;

wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_tlp_prfx_blocked_err;
wire    [NF-1:0]    cdm_tlp_prfx_blocked_err_reg;
wire    [NF-1:0]             cdm_psnd_tlp_egrss_blckd_err;    // Poisoned TLP Egress Blocked Error
wire    [NF-1:0]             cdm_psnd_tlp_egrss_blckd_err_reg;    // Poisoned TLP Egress Blocked Error
wire    [NF-1:0]             int_dpc_triggered;
wire    [(2*NF)-1:0]         int_dpc_trig_reason;
wire    [(2*NF)-1:0]         int_dpc_trig_reason_extn;
wire    [NF-1:0]             int_aer_dpc_triggered;
wire    [NF-1:0]             int_core_in_dpc;
wire                         dpc_link_dis = int_core_in_dpc[0];    // DPC directs LTSSM into DISABLE state.
wire                         cdm_core_in_dpc = int_core_in_dpc[0];    // DPC directs LTSSM into DISABLE state.
wire    [(16*NF)-1:0]        dpc_err_src_id;                       // DPC Error Source ID.
wire    [NF-1:0]             cfg_dpc_trig_status;
wire    [NF-1:0]             dpc_triggered_detect;                 // 1 clock cycle pulse when DPC is triggered.
// Downstream Port Containment Capability outputs.
wire    [(5*NF)-1:0]         int_dpc_int_msg_num;                  // DPC Interrupt Message Number
wire    [NF-1:0]             int_dpc_rp_ext_dpc;                   // DPC Root Port Extensions for DPC
wire    [NF-1:0]             int_dpc_poison_tlp_egr_blk_support;   // DPC Poisoned TLP Egress Blocking Supported
wire    [NF-1:0]             int_dpc_sw_trig_support;              // DPC Software Triggering Supported
wire    [(4*NF)-1:0]         int_dpc_rp_pio_log_size;              // DPC RP PIO Log Size
wire    [NF-1:0]             int_dpc_dl_active_err_cor_support;    // DPC DL_Active ERR_COR Signaling Supported
wire    [(2*NF)-1:0]         int_dpc_trig_en;                      // DPC Trigger Enable
wire    [NF-1:0]             int_dpc_cpl_cntrl;                    // DPC Completion Control
wire    [NF-1:0]             int_dpc_int_en;                       // DPC Interrupt Enable
wire    [NF-1:0]             int_dpc_int;                          // DPC Interrupt for INTx
wire    [NF-1:0]             int_dpc_msi;                          // DPC Interrupt for MSI
wire    [NF-1:0]             int_dpc_err_cor_en;                   // DPC ERR_COR Enable
wire    [NF-1:0]             int_dpc_poison_tlp_egr_block_en;      // Poisoned TLP Egress Blocking Enable
wire    [NF-1:0]             int_dpc_sw_trigger;                   // DPC Software Trigger
wire    [NF-1:0]             int_dpc_dl_active_err_cor_en;         // DL_Active ERR_COR Enable
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_mlf_tlp_err;
wire    [NF-1:0]    cdm_mlf_tlp_err_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_acs_violation;
wire    [NF-1:0]    cdm_acs_violation_reg;
wire                         int_rtlh_fc_prot_err;
wire    [NF-1:0]             cdm_rcvr_overflow;
wire    [NF-1:0]             cdm_rcvr_overflow_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_rcvd_req_ur;
wire    [NF-1:0]    cdm_rcvd_req_ur_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_rcvd_req_ca;
wire    [NF-1:0]    cdm_rcvd_req_ca_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_unexp_cpl_err;
wire    [NF-1:0]    cdm_unexp_cpl_err_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_rcvd_wreq_poisoned;
wire    [NF-1:0]    cdm_rcvd_wreq_poisoned_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_rcvd_cpl_poisoned;
wire    [NF-1:0]    cdm_rcvd_cpl_poisoned_reg;
wire    [(ERROR_TLP_WD*NF)-1:0]    cdm_ecrc_err;
wire    [NF-1:0]    cdm_ecrc_err_reg;
wire    [NF-1:0]             cdm_cpl_timeout;
wire    [NF-1:0]             cdm_cpl_timeout_reg;
wire                         cdm_prot_err;
wire                         cdm_prot_err_reg;
wire                         cdm_fc_prot_err;
wire                         cdm_fc_prot_err_reg;
wire                         cdm_rcvd_err;
wire                         cdm_rcvd_err_reg;
wire                         cdm_bad_dllp_err;
wire                         cdm_bad_dllp_err_reg;
wire                         cdm_bad_tlp_err;
wire                         cdm_bad_tlp_err_reg;
wire                         cdm_replay_num_rlover_err;
wire                         cdm_replay_num_rlover_err_reg;
wire                         cdm_replay_timeout_err;
wire                         cdm_replay_timeout_err_reg;
wire    [NF-1:0]             cdm_tlp_trans_egress_blk;
wire    [NF-1:0]             cdm_tlp_trans_egress_blk_reg;
wire    [NF-1:0]             cdm_atomic_egress_blk;
wire    [NF-1:0]             cdm_atomic_egress_blk_reg;
wire    [NF-1:0]             cdm_internal_err;
wire    [NF-1:0]             cdm_corr_internal_err;
wire    [NF-1:0]             cdm_internal_err_reg;
wire    [NF-1:0]             cdm_corr_internal_err_reg;
wire    [FX_TLP-1:0]         int_err_advisory;
wire    [FX_TLP-1:0]         int_err_advisory_reg;
wire                cdm_err_detect;   // 0 - Core Detected Error; 1 - Application Detected Error
wire            cdm_err_detect_reg;

wire [HDR_LOG_SIZE_WD-1:0] radm_hdrlog_hdr_size;
wire                       radm_hdrlog_flit_mode;
wire                       radm_hdrlog_fc_E_NP ;
wire [HDR_LOG_SIZE_WD-1:0] radm_hdrlog_hdr_size_reg;
wire                       radm_hdrlog_flit_mode_reg;
wire                       radm_hdrlog_fc_E_NP_reg ;






wire                   int_app_hdr_valid;
wire  [APP_HDR_LOG_WD-1:0]          int_app_hdr_log;
wire                          int_app_hdr_flitmode;
wire  [APP_HDR_LOG_SZ_WD-1:0] int_app_hdr_log_size;

wire  [ERR_BUS_WD-1:0] int_app_err_bus;
wire                   int_app_err_advisory;
wire                   int_app_poisoned_tlp_type;
wire  [PF_WD-1:0]      int_app_err_func_num;



parameter  APP_ERR_REGIN      = `CX_APP_ERR_REGIN
                                ;

localparam APP_ERR_PIPEWIDTH  = 1 +              // hdr_valid
                                APP_HDR_LOG_WD + 1 + APP_HDR_LOG_SZ_WD + // hdr_log + flitmode + hdr_log_size
                                ERR_BUS_WD +                  // err_bus,
                                1 +                   // err_advisory
                                1 +                   // poisoned_tlp_type
                                PF_WD;                // func_num


delay_n

#(APP_ERR_REGIN, APP_ERR_PIPEWIDTH) u_app_err_pipeline(
    .clk        (core_clk),
    .rst_n      (non_sticky_rst_n),
    .clear      (1'b0),
    .din        ({app_hdr_valid, app_hdr_log,
                  app_hdr_flitmode,
                  app_hdr_log_size, 
                  app_err_bus, app_err_advisory,app_poisoned_tlp_type,
                  app_err_func_num}),
    .dout       ({int_app_hdr_valid, int_app_hdr_log,
                  int_app_hdr_flitmode,
                  int_app_hdr_log_size,
                  int_app_err_bus, int_app_err_advisory,int_app_poisoned_tlp_type,
                  int_app_err_func_num})
);




reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_hdr_valid;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_mlf_err;
reg     [NF-1:0]             tmp_app_rcvr_overflow;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_req_ur;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_req_ca;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_unexp_cpl_err;
reg     [NF-1:0]             tmp_app_cpl_timeout;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_acs_violation;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_poisoned;
reg     [(ERROR_TLP_WD*NF)-1:0]    tmp_app_ecrc_err;
reg     [NF-1:0]             tmp_app_tlp_trans_egress_blk;
reg     [NF-1:0]             tmp_app_atomic_egress_blk;
reg     [(ERROR_TLP_WD*NF)-1:0]    app_tlp_prfx_blocked_err;
reg     [NF-1:0]             app_psnd_tlp_egrss_blckd_err;    // Poisoned TLP Egress Blocked Error
reg                         tmp_app_prot_err;
reg                         tmp_app_fc_prot_err;
reg                         tmp_app_rcvd_err;
reg                         tmp_app_bad_dllp_err;
reg                         tmp_app_bad_tlp_err;
reg                         tmp_app_replay_num_rlover_err;
reg                         tmp_app_replay_timeout_err;
reg     [NF-1:0]            tmp_app_advisory_nf_err;
reg     [NF-1:0]            tmp_app_hdr_log_overflow_det;

always @(*)
begin: get_func_spec_app_error
integer j;
    tmp_app_hdr_valid         = 0;
    tmp_app_mlf_err           = 0;
    tmp_app_rcvr_overflow     = 0;
    tmp_app_req_ur            = 0;
    tmp_app_req_ca            = 0;
    tmp_app_ecrc_err          = 0;
    tmp_app_unexp_cpl_err     = 0;
    tmp_app_poisoned          = 0;
    tmp_app_cpl_timeout       = 0;
    tmp_app_tlp_trans_egress_blk = 0;
    tmp_app_atomic_egress_blk = 0;
    app_tlp_prfx_blocked_err      = 0;
    tmp_app_acs_violation     = 0;
    app_psnd_tlp_egrss_blckd_err = 0;
    tmp_app_advisory_nf_err      = 0;
    tmp_app_hdr_log_overflow_det = 0;
    for (j = 0; j<NF; j=j+1) begin
        if ((j == int_app_err_func_num)
            && int_app_hdr_valid
           ) begin
            tmp_app_hdr_valid[j]        = 1'b1;
            tmp_app_mlf_err[j]          = int_app_err_bus[0];
            tmp_app_rcvr_overflow[j]    = int_app_err_bus[1];
            tmp_app_unexp_cpl_err[j]    = int_app_err_bus[2];
            tmp_app_req_ca[j]           = int_app_err_bus[3];
            tmp_app_cpl_timeout[j]      = int_app_err_bus[4];
            tmp_app_req_ur[j]           = int_app_err_bus[5];
            tmp_app_ecrc_err[j]         = int_app_err_bus[6];
            tmp_app_poisoned[j]         = int_app_err_bus[7];
            tmp_app_atomic_egress_blk[j]= int_app_err_bus[8];
            app_tlp_prfx_blocked_err[j] = int_app_err_bus[11];
            tmp_app_acs_violation [j]   = int_app_err_bus[12];
            app_psnd_tlp_egrss_blckd_err[j] = int_app_err_bus[13];
            tmp_app_advisory_nf_err[j]       = int_app_err_bus[25];
            tmp_app_hdr_log_overflow_det[j]  = int_app_err_bus[26];
            tmp_app_tlp_trans_egress_blk[j]  = int_app_err_bus[27];
        end
        else if (int_app_hdr_valid && int_app_err_bus[6] 
                ) begin // for ECRC_ERROR set all valid signals. It's non-specific function
             tmp_app_hdr_valid[j]        = 1'b1;
        end
    end
end

always_comb begin
    tmp_app_prot_err              = int_app_hdr_valid & int_app_err_bus[18];
    tmp_app_fc_prot_err           = int_app_hdr_valid & int_app_err_bus[19];
    tmp_app_rcvd_err              = int_app_hdr_valid & int_app_err_bus[20];
    tmp_app_bad_tlp_err           = int_app_hdr_valid & int_app_err_bus[21];
    tmp_app_bad_dllp_err          = int_app_hdr_valid & int_app_err_bus[22];
    tmp_app_replay_num_rlover_err = int_app_hdr_valid & int_app_err_bus[23];
    tmp_app_replay_timeout_err    = int_app_hdr_valid & int_app_err_bus[24];
end



assign cdm_err_detect           = int_app_hdr_valid;
assign cdm_hdr_log = int_app_hdr_valid ? int_app_hdr_log : radm_hdrlog.hdr_prfx;  
assign cdm_hdr_log_valid        = tmp_app_hdr_valid      | radm_hdr_log_valid;
assign cdm_mlf_tlp_err          = tmp_app_mlf_err        | radm_mlf_tlp_err_int;
assign cdm_rcvr_overflow        = tmp_app_rcvr_overflow  | rtlh_overfl_err_d;
assign cdm_rcvd_req_ur          = tmp_app_req_ur         | radm_rcvd_req_ur;
assign cdm_rcvd_req_ca          = tmp_app_req_ca         | radm_rcvd_req_ca_int;
assign cdm_unexp_cpl_err        = tmp_app_unexp_cpl_err  | radm_unexp_cpl_err_int;
assign cdm_rcvd_wreq_poisoned   = tmp_app_poisoned & {(ERROR_TLP_WD*NF){!int_app_poisoned_tlp_type}} | radm_rcvd_wreq_poisoned_int;
assign cdm_rcvd_cpl_poisoned    = tmp_app_poisoned & {(ERROR_TLP_WD*NF){int_app_poisoned_tlp_type}}  | radm_rcvd_cpl_poisoned_int;
assign cdm_ecrc_err             = tmp_app_ecrc_err       | radm_ecrc_err_int;
assign cdm_cpl_timeout          = tmp_app_cpl_timeout    | radm_cpl_timeout_pf;

  assign cdm_acs_violation        = tmp_app_acs_violation | radm_rcvd_acs_err_int;


assign cdm_atomic_egress_blk    = tmp_app_atomic_egress_blk;
assign cdm_tlp_prfx_blocked_err = app_tlp_prfx_blocked_err;
assign cdm_tlp_trans_egress_blk = tmp_app_tlp_trans_egress_blk;

assign cdm_prot_err              = tmp_app_prot_err | dl_prot_err;
assign cdm_fc_prot_err           = tmp_app_fc_prot_err | int_rtlh_fc_prot_err;
assign cdm_rcvd_err              = tmp_app_rcvd_err | rmlh_rcvd_err;
assign cdm_bad_dllp_err          = tmp_app_bad_dllp_err | rdlh_bad_dllp_err;
assign cdm_bad_tlp_err           = tmp_app_bad_tlp_err  | rdlh_bad_tlp_err;
assign cdm_replay_num_rlover_err = tmp_app_replay_num_rlover_err | xdlh_replay_num_rlover_err;
assign cdm_replay_timeout_err    = tmp_app_replay_timeout_err | xdlh_replay_timeout_err;

assign cdm_psnd_tlp_egrss_blckd_err = app_psnd_tlp_egrss_blckd_err;    // Poisoned TLP Egress Blocked Error
assign cdm_aer_dpc_triggered = int_aer_dpc_triggered[0];    // Function 0 only applies.


assign cdm_internal_err         = {NF{int_app_hdr_valid && int_app_err_bus[9]}}
                                 | {NF{radm_qoverflow}}
                                 | {NF{rasdp_int_uncorr_error}}
                                 | {NF{radm_formq_overflow | radm_formq_read_err}}
                                 | {NF{pm_pclkack_timeout}}
;
assign cdm_corr_internal_err    = {NF{int_app_hdr_valid && int_app_err_bus[10]}}
                                 | {NF{rasdp_int_corr_error}}
;
        assign int_err_advisory         = int_app_hdr_valid ? {{(FX_TLP-1){1'b0}},int_app_err_advisory} :  '0;


// New Pipeline -----------------------------------------------------------
parameter CDM_PIPE_SIZE = `CX_FX_TLP + 7
                          +1 
                          + HDR_SIZE 
                          + NF * 10
                          + NF
                          + NF
                          + NF
                          + NF
                          + NF
                          + (NF) * 2
                          + HDR_LOG_SIZE_WD + 2 
                          ;

//in case of multistream add pipeline
parameter CDM_ERROR_PIPE_DELAYN = 0 + 1;

delay_n

#(CDM_ERROR_PIPE_DELAYN, CDM_PIPE_SIZE ) u_cdm_error_pipe(
    .clk        (core_clk),
    .rst_n      (non_sticky_rst_n),
    .clear      (1'b0),
    .din        (
       {
       cdm_err_detect,
       cdm_hdr_log,
       cdm_hdr_log_valid[NF-1:0],
       cdm_mlf_tlp_err[NF-1:0],
       cdm_rcvr_overflow,
       cdm_rcvd_req_ur[NF-1:0],
       cdm_rcvd_req_ca[NF-1:0],
       cdm_unexp_cpl_err[NF-1:0],
       cdm_rcvd_wreq_poisoned[NF-1:0],
       cdm_rcvd_cpl_poisoned[NF-1:0],
       cdm_ecrc_err[NF-1:0],
       cdm_cpl_timeout,
       cdm_acs_violation[NF-1:0],
       cdm_tlp_trans_egress_blk[NF-1:0],
       cdm_atomic_egress_blk[NF-1:0],
       cdm_tlp_prfx_blocked_err[NF-1:0],
       cdm_prot_err,
       cdm_fc_prot_err,
       cdm_rcvd_err,
       cdm_bad_dllp_err,
       cdm_bad_tlp_err,
       cdm_replay_num_rlover_err,
       cdm_replay_timeout_err,
       cdm_psnd_tlp_egrss_blckd_err,
       cdm_internal_err,
       cdm_corr_internal_err,
       int_err_advisory
       ,
       radm_hdrlog_hdr_size,
       radm_hdrlog_flit_mode,
       radm_hdrlog_fc_E_NP
       }
                 ),
    .dout       (
       { 
       cdm_err_detect_reg,
       cdm_hdr_log_reg,
       cdm_hdr_log_valid_reg[NF-1:0],
       cdm_mlf_tlp_err_reg[NF-1:0],
       cdm_rcvr_overflow_reg,
       cdm_rcvd_req_ur_reg[NF-1:0],
       cdm_rcvd_req_ca_reg[NF-1:0],
       cdm_unexp_cpl_err_reg[NF-1:0],
       cdm_rcvd_wreq_poisoned_reg[NF-1:0],
       cdm_rcvd_cpl_poisoned_reg[NF-1:0],
       cdm_ecrc_err_reg[NF-1:0],
       cdm_cpl_timeout_reg,
       cdm_acs_violation_reg[NF-1:0],
       cdm_tlp_trans_egress_blk_reg[NF-1:0],
       cdm_atomic_egress_blk_reg[NF-1:0],
       cdm_tlp_prfx_blocked_err_reg[NF-1:0],
       cdm_prot_err_reg,
       cdm_fc_prot_err_reg,
       cdm_rcvd_err_reg,
       cdm_bad_dllp_err_reg,
       cdm_bad_tlp_err_reg,
       cdm_replay_num_rlover_err_reg,
       cdm_replay_timeout_err_reg,
       cdm_psnd_tlp_egrss_blckd_err_reg,
       cdm_internal_err_reg,
       cdm_corr_internal_err_reg,
       int_err_advisory_reg
       ,
       radm_hdrlog_hdr_size_reg,
       radm_hdrlog_flit_mode_reg,
       radm_hdrlog_fc_E_NP_reg
       }  
                )
);


// ------------------------------------------------------------------------



   wire [HDR_LOG_SIZE_WD:0]   radm_hdrlog_hdr_size_int = radm_hdrlog.flit_mode?{1'b0,{(HDR_LOG_SIZE_WD-$clog2(`CX_MAX_HDR_LOG_SZ+1)){1'b0}},radm_hdrlog.hdr_size} 
                                                                              :{(HDR_LOG_SIZE_WD){1'b0}} | (3'd4+`CX_MAX_END2END_TLP_PRFXS_VALUE); //for NFM SIZE = 4+NPRFX

   assign radm_hdrlog_hdr_size = int_app_hdr_valid? int_app_hdr_log_size : radm_hdrlog_hdr_size_int[HDR_LOG_SIZE_WD-1:0];

   assign radm_hdrlog_flit_mode = int_app_hdr_valid? int_app_hdr_flitmode : radm_hdrlog.flit_mode;
   assign radm_hdrlog_fc_E_NP   = (radm_hdrlog.fc == E_NP )? 1'b1: 1'b0;




assign app_malformed_tlp        = int_app_hdr_valid & int_app_err_bus[0] ;
assign cfg_poisned_tlp_int[0]   = int_app_hdr_valid & int_app_err_bus[7] ;
assign cfg_ecrc_tlp_err_int[0]  = int_app_hdr_valid & int_app_err_bus[6] & |cfg_ecrc_chk_en  ;
assign cfg_ur_tlp_int[0]        = int_app_hdr_valid & int_app_err_bus[5] ;
assign cfg_ca_tlp_int[0]        = int_app_hdr_valid & int_app_err_bus[3] ;
assign cfg_cpl_timeout_int[0]   = int_app_hdr_valid & int_app_err_bus[4] ;
assign cfg_cpl_timeout_int[1]   = radm_cpl_timeout ;

generate
  for(genvar ii = 0; ii < ERROR_TLP_WD ; ii = ii + 1) begin : detect_err_pertlp
    assign cfg_poisned_tlp_int[ii+1]   =  (|radm_rcvd_wreq_poisoned_int[(NF*ii) +:NF]) | (|radm_rcvd_cpl_poisoned_int[(NF*ii) +:NF])
                                        ;
    assign cfg_ecrc_tlp_err_int[ii+1]  = |cfg_ecrc_chk_en && |radm_ecrc_err_int[NF*ii +:NF] ;
    assign cfg_ur_tlp_int[ii+1]        =  !cfg_poisned_tlp_int[ii+1]
                                       && ( (|radm_rcvd_req_ur[(NF*ii) +:NF])
                                         ) ;
    assign cfg_ca_tlp_int[ii+1]        = (|radm_rcvd_req_ca_int[(NF*ii) +:NF])
                                       ;
  end
endgenerate

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cfg_poisned_tlp   <= #TP 0;
        cfg_ecrc_tlp_err  <= #TP 0;
        cfg_ur_tlp        <= #TP 0;
        cfg_ca_tlp        <= #TP 0;
        cfg_cpl_timeout   <= #TP 0;
    end else begin
        cfg_poisned_tlp   <= #TP cfg_poisned_tlp_int;
        cfg_ecrc_tlp_err  <= #TP cfg_ecrc_tlp_err_int;
        cfg_ur_tlp        <= #TP cfg_ur_tlp_int;
        cfg_ca_tlp        <= #TP cfg_ca_tlp_int;
        cfg_cpl_timeout   <= #TP cfg_cpl_timeout_int;
    end
end





// =============================================================================
// Error reporting in D1-D3 states
// signal radm_pm_block_tlp indicate that we're in D1-D3 states
wire    [NF-1:0]        blocked_error_in_d13;
reg     [NF-1:0]        cfg_send_cor_err;
reg     [NF-1:0]        cfg_send_nf_err;
reg     [NF-1:0]        cfg_send_f_err;
reg     [(3*NF)-1:0]    cfg_func_spec_err;
reg     [NF-1:0]        send_aft_blk_cor_err;
reg     [NF-1:0]        send_aft_blk_nf_err;
reg     [NF-1:0]        send_aft_blk_f_err;
wire    [NF-1:0]        int_cfg_send_cor_err;
wire    [NF-1:0]        int_cfg_send_nf_err;
wire    [NF-1:0]        int_cfg_send_f_err;

wire                    rtlh_fc_prot_err;
assign rtlh_fc_prot_err = 1'b0;
assign int_rtlh_fc_prot_err = rtlh_fc_prot_err || xadm_fc_prot_err;

wire    [NF-1:0]        int_radm_set_slot_pwr_limit;
assign int_radm_set_slot_pwr_limit = radm_set_slot_pwr_limit;

// Errors that aren't caused by a received TLP:
// 1. Replay Timeout
// 2. REPLAY NUM Rollover
// 3. Completion Timeout
// 4. Flow Control Protocol Error
// 5. Receiver Overflow
// All the other errors are caused by a received TLP
// In D1-D3 states
assign blocked_error_in_d13 =  {NF{1'b0}} 
 | {NF{cdm_replay_timeout_err_reg}}
 | {NF{cdm_replay_num_rlover_err_reg}}
 | {NF{cdm_fc_prot_err_reg}}
 | cdm_cpl_timeout_reg 
 | cdm_rcvr_overflow_reg 
 | cdm_internal_err_reg | cdm_corr_internal_err_reg 
                                   |  {NF{cxl_internal_uncorr_error}} | {NF{rcrb_ras_corr_error_level}}

                               ;

// Latch the error if in D1-D3 states
always @(posedge core_clk or negedge non_sticky_rst_n)
begin: latch_error_proc
integer m;
    if (!non_sticky_rst_n) begin
        cfg_send_cor_err        <= #TP 0;
        cfg_send_nf_err         <= #TP 0;
        cfg_send_f_err          <= #TP 0;
        cfg_func_spec_err       <= #TP 0;
        send_aft_blk_cor_err    <= #TP 0;
        send_aft_blk_nf_err     <= #TP 0;
        send_aft_blk_f_err      <= #TP 0;
    end
    else begin
        // delay to align with error signals
        cfg_func_spec_err       <= #TP int_cfg_func_spec_err;
        for (m=0; m<NF; m=m+1) begin
            if (pm_radm_block_tlp[m])
                // Block the errors if it's not caused by received TLP and save it
                if (blocked_error_in_d13[m]) begin
                    cfg_send_cor_err[m]     <= #TP 0;
                    cfg_send_nf_err[m]      <= #TP 0;
                    cfg_send_f_err[m]       <= #TP 0;

                      send_aft_blk_cor_err[m] <= #TP int_cfg_send_cor_err[m] ? 1'b1 : send_aft_blk_cor_err[m];
                      send_aft_blk_nf_err[m]  <= #TP int_cfg_send_nf_err[m] ? 1'b1 : send_aft_blk_nf_err[m];
                      send_aft_blk_f_err[m]   <= #TP int_cfg_send_f_err[m] ? 1'b1 : send_aft_blk_f_err[m];

                end
                // if it's caused by a received TLP, then send it
                else begin
                    cfg_send_cor_err[m]     <= #TP int_cfg_send_cor_err[m];
                    cfg_send_nf_err[m]      <= #TP int_cfg_send_nf_err[m];
                    cfg_send_f_err[m]       <= #TP int_cfg_send_f_err[m];
                end
            // Not in D1-D3 states, send normally
            else begin
                // Send the error message latched while in D1-D3 states
                if (send_aft_blk_cor_err[m]) begin
                    cfg_send_cor_err[m]     <= #TP send_aft_blk_cor_err[m];
                    send_aft_blk_cor_err[m] <= #TP 0;
                end
                else begin
                    cfg_send_cor_err[m]     <= #TP int_cfg_send_cor_err[m];
                    send_aft_blk_cor_err[m] <= #TP 0;
                end

                if (send_aft_blk_nf_err[m]) begin
                    cfg_send_nf_err[m]      <= #TP send_aft_blk_nf_err[m];
                    send_aft_blk_nf_err[m]  <= #TP 0;
                end
                else begin
                    cfg_send_nf_err[m]      <= #TP int_cfg_send_nf_err[m];
                    send_aft_blk_nf_err[m]  <= #TP 0;
                end

                if (send_aft_blk_f_err[m]) begin
                    cfg_send_f_err[m]       <= #TP send_aft_blk_f_err[m];
                    send_aft_blk_f_err[m]   <= #TP 0;
                end
                else begin

                    cfg_send_f_err[m]       <= #TP int_cfg_send_f_err[m];
                    send_aft_blk_f_err[m]   <= #TP 0;
                end
            end
        end // for loop


    end
end



// =============================================================================
// Legacy interrupt handling
reg [NF-1:0]    inta_wirei;
reg [NF-1:0]    intb_wirei;
reg [NF-1:0]    intc_wirei;
reg [NF-1:0]    intd_wirei;
wire            inta_wire;
wire            intb_wire;
wire            intc_wire;
wire            intd_wire;

assign inta_wire = |inta_wirei;
assign intb_wire = |intb_wirei;
assign intc_wire = |intc_wirei;
assign intd_wire = |intd_wirei;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin: latch_int_proc
integer k;
    if (!non_sticky_rst_n) begin
        inta_wirei  <= #TP 0;
        intb_wirei  <= #TP 0;
        intc_wirei  <= #TP 0;
        intd_wirei  <= #TP 0;
    end
    else begin
        // If there's only one function, only INTA is available
        if (NF == 1) begin
            intb_wirei[0]   <= #TP 0;
            intc_wirei[0]   <= #TP 0;
            intd_wirei[0]   <= #TP 0;
            if (sys_int[0])
                inta_wirei[0]   <= #TP !cfg_int_disable[0];
            else
                inta_wirei[0]   <= #TP 1'b0;
        end
        // Otherwise, it depends on the interrupt pin mapping register
        else begin
            for (k=0; k<NF; k=k+1) begin
                case (Bget(cfg_int_pin,k))
                    8'h01: inta_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    8'h02: intb_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    8'h03: intc_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    8'h04: intd_wirei[k]<= #TP sys_int[k] & !cfg_int_disable[k];
                    default: begin
                        inta_wirei[k]   <= #TP inta_wirei[k];
                        intb_wirei[k]   <= #TP intb_wirei[k];
                        intc_wirei[k]   <= #TP intc_wirei[k];
                        intd_wirei[k]   <= #TP intd_wirei[k];
                    end
                endcase
            end
        end
    end
end

// Function to grab a byte from a bus
function automatic [7:0] Bget;
input [(NF*8)-1:0]      vector;
input integer           index;
reg [PF_WD-1:0]        reg_index;
// LMD: Variable hides a variable in outer scope i
// LJ: This variable is intern to this block
// leda W121 off
integer i;
// leda W121 on
begin
    reg_index = index;
    Bget = 0;
    for (i=0; i<8; i=i+1)
        Bget[i] = vector[(reg_index<<3)+i];
end
endfunction

// =============================================================================
// Power Budgeting signal muxing
  assign cfg_pwr_budget_sel = int_cfg_pwr_budget_sel[0];
  always @(int_cfg_pwr_budget_data_sel_reg)
  begin: get_func_4_pwr_budget_data_sel_reg_1f
      cfg_pwr_budget_data_sel_reg = int_cfg_pwr_budget_data_sel_reg;
  end



// -----------------------------------------------------------------------------
// Assignments
// -----------------------------------------------------------------------------
assign cfg_2nd_reset            = |int_cfg_2nd_reset;
assign cfg_soft_rst_n           = 1'b1;
assign cfg_hdr_type             = int_cfg_hdr_type[7:0];
assign cfg_link_rate            = cxl_rcrb_enable ? int_cfg_rcrb_link_rate[3:0] : int_cfg_link_rate[3:0];
assign cfg_retimers_pre_detected = cxl_rcrb_enable ? int_cfg_rcrb_retimers_pre_detected[1:0] : int_cfg_retimers_pre_detected[1:0];
assign cfg_link_dis             = cxl_rcrb_enable ? |int_rcrb_link_dis | dpc_link_dis : |int_link_dis | dpc_link_dis; // When any function is disabled, core will go into disable
assign cfg_link_retrain         = cxl_rcrb_enable ? |int_rcrb_link_retrain : |int_link_retrain;                                    // When any function is retrain, core will retrain
assign cfg_ext_synch            = cxl_rcrb_enable ? |int_rcrb_ext_synch : |int_ext_synch;                                       // When any function is in extended sync, core in extended sync
assign cfg_l0s_supported        = cxl_rcrb_enable ? pf_cfg_rcrb_pcie_aspm_cap_bus[0] : pf_cfg_pcie_aspm_cap_bus[0] ;      // Only bit 0 because same value for all funcs in multi-funcs
assign cfg_aslk_pmctrl          = cxl_rcrb_enable ? {NF{int_cfg_rcrb_aslk_pmctrl}} : int_cfg_aslk_pmctrl ;
assign cfg_clk_pm_en            = cxl_rcrb_enable ? int_cfg_rcrb_clk_pm_en : &int_cfg_clk_pm_en;
assign cfg_comm_clk_config      = cxl_rcrb_enable ? int_cfg_rcrb_comm_clk_config : &int_cfg_comm_clk_config;         // When all functions use common clock, then we signal this (PCIe 1.1 C15 errata).
assign cfg_hw_autowidth_dis     = cxl_rcrb_enable ? int_cfg_rcrb_hw_autowidth_dis :  int_cfg_hw_autowidth_dis[0];

assign cfg_upd_aslk_pmctrl       = cxl_rcrb_enable ? {NF{int_cfg_rcrb_upd_aslk_pmctrl}} : int_cfg_upd_aslk_pmctrl ;


// Output assignments, required for function 0 (downstream ports) only.
assign cfg_dpc_int_msg_num = int_dpc_int_msg_num[4:0];
assign cfg_dpc_rp_ext_dpc = int_dpc_rp_ext_dpc[0];
assign cfg_dpc_poison_tlp_egr_blk_support = int_dpc_poison_tlp_egr_blk_support[0];
assign cfg_dpc_sw_trig_support = int_dpc_sw_trig_support[0];
assign cfg_dpc_rp_pio_log_size = int_dpc_rp_pio_log_size[3:0];
assign cfg_dpc_dl_active_err_cor_support = int_dpc_dl_active_err_cor_support[0];
assign cfg_dpc_trig_en = int_dpc_trig_en[1:0];
assign cfg_dpc_cpl_cntrl = int_dpc_cpl_cntrl[0];
assign cfg_dpc_int_en = int_dpc_int_en[0];
assign dpc_int = int_dpc_int[0];
assign dpc_msi = int_dpc_msi[0];
assign cfg_dpc_err_cor_en = int_dpc_err_cor_en[0];
assign cfg_dpc_poison_tlp_egr_block_en = int_dpc_poison_tlp_egr_block_en[0];
assign cfg_dpc_sw_trigger = int_dpc_sw_trigger[0];
assign cfg_dpc_dl_active_err_cor_en = int_dpc_dl_active_err_cor_en[0];


wire           cdm_dpc_triggered;              // DPC has been triggered indication
wire           cdm_dpc_trig_status;            // DPC trigger status from DPC Status Register
wire [1:0]     cdm_dpc_trig_en;                // DPC trigger enable from DPC Control Register

assign cdm_dpc_triggered = int_dpc_triggered[0];
assign cdm_dpc_trig_status = cfg_dpc_trig_status[0];
assign cdm_dpc_trig_en = cfg_dpc_trig_en;
assign dpc_fatal_err_gate       = cfg_br_ctrl_serren & (cdm_dpc_trig_en == 2'b01 || cdm_dpc_trig_en == 2'b10);
assign dpc_nonfatal_err_gate    = cfg_br_ctrl_serren & (cdm_dpc_trig_en == 2'b10);


// -----------------------------------------------------------------------------
// Local bus address decoding
// -----------------------------------------------------------------------------
wire [(64*FX_TLP_ADR_DEC)-1:0] flt_cdm_addr_int;
  logic [FX_TLP_ADR_DEC-1:0] flt_cdm_addr_valid_int;

  // FIXME **if updated: If vf_bar_match internal pipeline is enabled again then filter pipeline needs to be adjusted with parameter ANTI_CTRL_PIPE_DELAY
  // Disabling input pipeline here, as flt_cdm_addr in pipelined in filter and sent out
  assign flt_cdm_addr_int       = flt_cdm_addr;
  assign flt_cdm_addr_valid_int = flt_cdm_addr_valid;

cdm_reg_decode

#(
   .INST (INST)
   ,
   .CRGB_ADDR_WIDTH(CRGB_ADDR_WIDTH),
   .CRGB_DATA_WIDTH(CRGB_DATA_WIDTH),
   .CRGB_BE_WIDTH(CRGB_BE_WIDTH)
) u_cdm_reg_decode (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_cs                     (lbc_cdm_cs),
    .lbc_cdm_unroll                 (lbc_cdm_unroll),
    .pl_reg_ack                     (pl_reg_ack),
    .pl_reg_data                    (pl_reg_data),
    .cfg_reg_ack                    (cfg_reg_ack),
    .cfg_reg_data                   (cfg_reg_data),
    .cfg_cap_reg_ack                (cfg_cap_reg_ack),
    .cfg_cap_reg_data               (cfg_cap_reg_data),
    .ecfg_reg_ack                   (ecfg_reg_ack),
    .ecfg_reg_data                  (ecfg_reg_data),
    .rcrb_mbar0_reg_ack             (rcrb_mbar0_reg_ack_mux),
    .rcrb_mbar0_reg_data            (rcrb_mbar0_reg_data),
    .rcrb_cfg_reg_ack               (cfg_rcrb_reg_ack),
    .rcrb_cfg_reg_data              (cfg_rcrb_reg_data),
    .rcrb_cfg_cap_reg_ack           (cfg_rcrb_cap_reg_ack),
    .rcrb_cfg_cap_reg_data          (cfg_rcrb_cap_reg_data),
    .rcrb_ecfg_reg_ack              (ecfg_rcrb_reg_ack),
    .rcrb_ecfg_reg_data             (ecfg_rcrb_reg_data),
    .upstream_port                  (upstream_port),

    .crgb_cdm_ack                   (crgb_cdm_ack),
    .crgb_cdm_rdata                 (crgb_cdm_rdata),
    .atu_ctrl_reg_ack               (atu_ctrl_reg_ack),
    .atu_ctrl_reg_data              (atu_ctrl_reg_data),

    .lbc_cdm_rcrb_wire              (lbc_cdm_rcrb_wire),
    .lbc_cdm_rcrb_mbar0_wire        (lbc_cdm_rcrb_mbar0_wire),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .lbc_cdm_rcrb_mbar0_dbi         (lbc_cdm_rcrb_mbar0_dbi),
// ---------- Outputs --------
    .pl_reg_sel                     (pl_reg_sel),
    .atu_reg_sel                    (atu_reg_sel),
    .cfg_reg_sel                    (cfg_reg_sel),
    .cfg_cap_reg_sel                (cfg_cap_reg_sel),
    .ecfg_reg_sel                   (ecfg_reg_sel),
    .rcrb_cfg_reg_sel               (cfg_rcrb_reg_sel),
    .rcrb_cfg_cap_reg_sel           (cfg_rcrb_cap_reg_sel),
    .rcrb_ecfg_reg_sel              (ecfg_rcrb_reg_sel),
    .rcrb_mbar0_reg_sel           (rcrb_mbar0_reg_sel),
    .cdm_pf_ecfg_addr               (cdm_pf_ecfg_addr),
    .lbc_cdm_dbi2                   ( lbc_cdm_dbi2    ),
    .lbc_cdm_data                   ( lbc_cdm_data    ),
    .lbc_cdm_wr                     ( lbc_cdm_wr      ),
    .lbc_cdm_dbi                    ( lbc_cdm_dbi     ),
    .crgb_cdm_cs                    ( crgb_cdm_cs     ),
    .crgb_cdm_addr                  ( crgb_cdm_addr   ),
    .crgb_cdm_wdata                 ( crgb_cdm_wdata  ),
    .crgb_cdm_wr                    ( crgb_cdm_wr     ),
    .crgb_cdm_source                ( crgb_cdm_source ),

    .cdm_lbc_data                   (cdm_lbc_data),
    .cdm_lbc_ack                    (cdm_lbc_ack)
); // cdm_reg_decode

logic [8:0]        radm_np_segment_id_int;
// Function 0 Only Signal
logic [(9*NF)-1:0] cfg_segment_id_int;
assign cfg_segment_id           = cfg_segment_id_int[8:0];
  assign radm_np_segment_id_int = radm_np_segment_id;

wire [NF-1:0]               int_radm_snoop_upd;
wire [SNOOP_BUS_WD-1:0]     int_radm_snoop_bus_num;
wire [SNOOP_DEV_WD-1:0]     int_radm_snoop_dev_num;

assign cfg_pbus_num     = int_cfg_pbus_num[7:0];
assign cfg_pbus_dev_num = int_cfg_pbus_dev_num[4:0];

generate
  if(MULTI_DEVICE_AND_BUS_PER_FUNC) begin : gen_int_radm_snoop_upd
    assign int_radm_snoop_upd = radm_snoop_upd;
  end
  else begin : gen_int_radm_snoop_upd
    assign int_radm_snoop_upd = {{(NF-1){1'h0}}, radm_snoop_upd};
  end
endgenerate
assign int_radm_snoop_bus_num = radm_snoop_bus_num;
assign int_radm_snoop_dev_num = radm_snoop_dev_num;

wire [NF*23-1:0] int_cfg_local_feature_support;
wire [NF-1:0]    int_cfg_dlink_feature_valid;
wire [NF-1:0]    int_fc_scaled_en;
wire [NF-1:0]    int_dl_feature_en;
wire [NF-1:0]    int_cfg_remote_feature_ack;

assign cfg_dlink_feature_valid = int_cfg_dlink_feature_valid[0];
assign cfg_local_feature_support = int_cfg_local_feature_support[0 +: 23];
assign dl_feature_en = int_dl_feature_en[0];
assign cfg_remote_feature_ack = int_cfg_remote_feature_ack[0];
wire [2:0] cfg_local_l0p_exit_latency;
assign cfg_local_l0p_exit_latency = int_cfg_local_feature_support[7:5];


assign fc_scaled_en = int_fc_scaled_en[0];

// For RCRB Error reporting
assign rcrb_err_write_pulse = {{{NF-1}{4'h0}},ecfg_rcrb_write_pulse};
assign rcrb_err_read_pulse  = {{{NF-1}{1'b0}},ecfg_rcrb_read_pulse};
assign rcrb_err_reg_id_mod  = {{{ERR_REG_ID_WD*(NF-1)}{1'b0}},rcrb_err_reg_id};
assign internal_err_mod   =  {{{NF-1}{1'b0}}, {cxl_internal_uncorr_error}} | cdm_internal_err_reg  ;
assign corr_internal_err_mod = {{{NF-1}{1'b0}}, {rcrb_ras_corr_error_pulse}} | cdm_corr_internal_err_reg ;

always @(posedge core_clk or negedge non_sticky_rst_n) begin
    if (!non_sticky_rst_n ) begin
        cfg_neg_link_width <= 6'b0;
    end else begin
        cfg_neg_link_width <= cfg_int_link_width[5:0];
    end

end

wire [NF-1:0] cfg_int_pcie_cap_flit_mode_sup;
wire [NF-1:0] cfg_int_flit_mode_dis;
wire [NF-1:0] cfg_int_flit_sris_clocking;
wire [NF-1:0] cfg_int_pcie_cap_flit_mode_stat;
assign cfg_pcie_cap_flit_mode_sup  = cfg_int_pcie_cap_flit_mode_sup[0];
assign cfg_flit_mode_dis           = cfg_int_flit_mode_dis[0];
assign cfg_flit_sris_clocking      = cfg_int_flit_sris_clocking[0];
assign cfg_pcie_cap_flit_mode_stat = cfg_int_pcie_cap_flit_mode_stat[0];




genvar func;
generate
for (func=0; func<NF; func = func+1) begin : gen_cdm_reg
// -----------------------------------------------------------------------------
// Base Configuration Register Space
// -----------------------------------------------------------------------------
cdm_cfg_reg

#(.INST(INST), .FUNC_NUM(func)
, .RCRB(0)
)
 u_cdm_cfg_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .device_type                    (device_type),
    // Local Bus access
    .cfg_reg_sel                    (cfg_reg_sel[func]),
    .cfg_cap_reg_sel                (cfg_cap_reg_sel[func]),
    .ecfg_reg_sel                   (ecfg_reg_sel[func]),
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),


    .int_msg_pending                (sys_int[func]),

    .rdlh_link_up                   (rdlh_link_up),
    .smlh_link_up                   (smlh_link_up),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .smlh_clr_enter_compliance      (smlh_clr_enter_compliance),
    .smlh_tx_margin_rst             (smlh_tx_margin_rst),
    .mac_phy_txdeemph               (mac_phy_txdeemph),
    .smlh_ls2_eq_req                (smlh_ls2_eq_req),
    .smlh_ls2_eq_success            (smlh_ls2_eq_success[3:1]),
    .smlh_ls2_eq_cmpl               (smlh_ls2_eq_cmpl),
    .smlh_ls2_eq_enter              (smlh_ls2_eq_enter_i),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_two_retimers_pre_detected (smlh_two_retimers_pre_detected),
    .smlh_crosslink_resolution      (smlh_crosslink_resolution),
    .smlh_retimer_pre_detected      (smlh_retimer_pre_detected),
    .aux_pwr_det                    (sys_aux_pwr_det),
    .radm_cpl_pending               (radm_cpl_pending[func]),

    // Errors
    .cfg_f_err_det                  (cfg_f_err_det[func]),
    .cfg_nf_err_det                 (cfg_nf_err_det[func]),
    .cfg_cor_err_det                (cfg_cor_err_det[func]),
    .cfg_unsupt_req_det             (cfg_unsupt_req_det[func]),
    .cfg_rprt_err_cor               (cfg_rprt_err_cor[func]),                 // Function 0 Only
    .cfg_rprt_err_nf                (cfg_rprt_err_nf[func]),                 // Function 0 Only
    .cfg_rprt_err_f                 (cfg_rprt_err_f[func]),                   // Function 0 Only
    .master_data_perr_det           (master_data_perr_det[func]),
    .signaled_target_abort_det      (signaled_target_abort_det[func]),
    .rcvd_target_abort_det          (rcvd_target_abort_det[func]),
    .rcvd_master_abort_det          (rcvd_master_abort_det[func]),
    .signaled_sys_err_det           (signaled_sys_err_det[func]),
    .perr_det                       (perr_det[func]),
    .master_data_perr_det2          (master_data_perr_det2[func]),
    .signaled_target_abort_det2     (signaled_target_abort_det2[func]),
    .rcvd_target_abort_det2         (rcvd_target_abort_det2[func]),
    .rcvd_master_abort_det2         (rcvd_master_abort_det2[func]),
    .signaled_sys_err_det2          (signaled_sys_err_det2[func]),
    .perr_det2                      (perr_det2[func]),

    // MSG received
    .radm_correctable_err           (|radm_correctable_err[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),
    .radm_nonfatal_err              (|radm_nonfatal_err[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),
    .radm_fatal_err                 (|radm_fatal_err[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),

    .sys_pre_det_state              (sys_pre_det_state[func]),
    .sys_mrl_sensor_state           (sys_mrl_sensor_state[func]),
    .sys_atten_button_pressed       (sys_atten_button_pressed[func]),
    .sys_pwr_fault_det              (sys_pwr_fault_det[func]),
    .sys_mrl_sensor_chged           (sys_mrl_sensor_chged[func]),
    .sys_pre_det_chged              (sys_pre_det_chged[func]),
    .sys_cmd_cpled_int              (sys_cmd_cpled_int[func]),
    .sys_eml_interlock_engaged      (sys_eml_interlock_engaged[func]),
    .radm_set_slot_pwr_limit        (int_radm_set_slot_pwr_limit[func]),
    .radm_slot_pwr_payload          (radm_slot_pwr_payload),
    .pm_status                      (pm_status[func]),
    .pm_pme_en                      (pm_pme_en[func]),
    .aux_pm_en                      (aux_pm_en[func]),
    .radm_pm_pme                    (radm_pm_pme[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),
    .radm_msg_req_id                (radm_msg_req_id),

    .smlh_ltssm_state               (smlh_ltssm_state),
    .radm_drs_msg                   (radm_drs_msg),      //only device received stored in registers, same for all


    .flt_cdm_addr                   (flt_cdm_addr_int),



    .app_ltr_msg_req                (app_ltr_msg_req),
    .msg_ltr_det                    (msg_ltr_det),
    .msgg2cdm_ltr_clr_msg_grant     (msgg2cdm_ltr_clr_msg_grant),
    .cdmpl2cfg_ltr_rq               (cdmpl2cfg_ltr_rq),
    .ltr_m_en_fn0                   (ltr_m_en_fn0),
    .cfg_disable_ltr_clr_msg        (cfg_disable_ltr_clr_msg),
    .rbar_ctrl_update               (rbar_ctrl_update[func]),
    .cfg_rbar_bar_resizable         (int_cfg_rbar_bar_resizable[6*(1+func)-1:6*func]),
    .cfg_rbar_bar0_mask             (int_cfg_rbar_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar1_mask             (int_cfg_rbar_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar2_mask             (int_cfg_rbar_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar3_mask             (int_cfg_rbar_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar4_mask             (int_cfg_rbar_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar5_mask             (int_cfg_rbar_bar5_mask[32*(1+func)-1:32*func]),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),

    .exp_rom_validation_status_strobe (exp_rom_validation_status_strobe[func] ),
    .exp_rom_validation_status        (exp_rom_validation_status[3*(1+func)-1:3*func]),
    .exp_rom_validation_details_strobe(exp_rom_validation_details_strobe[func]),
    .exp_rom_validation_details       (exp_rom_validation_details[4*(1+func)-1:4*func]),

    .radm_snoop_upd                 (int_radm_snoop_upd),
    .radm_snoop_bus_num             (int_radm_snoop_bus_num),
    .radm_snoop_dev_num             (int_radm_snoop_dev_num),
    .radm_pm_to_ack                 (radm_pm_to_ack),
    .pm_xmt_turnoff                 (pm_xmt_turnoff),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),     // input [1:0]
    .app_clk_pm_en                  (app_clk_pm_en),
    .cfg_config_limit               (cfg_config_limit),
    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),

    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .rcrb_base_addr                 (rcrb_base_addr),
    .rcrb_base_addr_valid           (rcrb_base_addr_valid),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .cxl_2_0_mbar0_offset                    (cxl_2_0_comp_reg_offset_in[func]),
    .current_data_rate                       (current_data_rate),
    .cxl_mode_enable                         (cxl_mode_enable),
    .cxl2p0_enabled                          (cxl_mbar0_enable),
    .cfg_cxl_2_0_ext_unmask_sbr              (cfg_cxl_2_0_ext_unmask_sbr),                // Unmask SBR
    .cfg_cxl_2_0_ext_unmask_ld               (cfg_cxl_2_0_ext_unmask_ld),                 // Unmask Link Disable
    .cfg_cxl_2_0_ext_alt_mse                 (cfg_cxl_2_0_ext_alt_mse),                   // Alternate Memory Space Enable
    .cfg_cxl_2_0_ext_alt_bme                 (cfg_cxl_2_0_ext_alt_bme),                   // Alternate Bus Master Enable
    .cfg_cxl_2_0_ext_alt_mem_base            (cfg_cxl_2_0_ext_alt_mem_base),              // Alternate Memory Base
    .cfg_cxl_2_0_ext_alt_mem_limit           (cfg_cxl_2_0_ext_alt_mem_limit),             // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base       (cfg_cxl_2_0_ext_alt_pref_mem_base),         // Alternate Prefetchable Memory Base
    .cfg_cxl_2_0_ext_alt_pref_mem_limit      (cfg_cxl_2_0_ext_alt_pref_mem_limit),        // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base_high  (cfg_cxl_2_0_ext_alt_pref_mem_base_high),    // Alternate Prefetchable Memory Base High
    .cfg_cxl_2_0_ext_alt_pref_mem_limit_high (cfg_cxl_2_0_ext_alt_pref_mem_limit_high),   // Alternate Prefetchable Memory Base High

    .flit_mode_enable                        (flit_mode_enable),
    .app_segment_id                          (app_segment_id),
    .radm_np_segment_id                      (radm_np_segment_id_int),
    .cfg_segment_id_out                      (cfg_segment_id_int[9*(1+func)-1:9*func]), // Function 0 Only 
// ---------- Outputs --------
    .cfg_upd_pme_cap                (cfg_upd_pme_cap[func]),
    .cfg_mem_match                  (cfg_mem_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_prefmem_match              (cfg_prefmem_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_io_match                   (cfg_io_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_config_above_match         (cfg_config_above_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_bar_match                  (cfg_bar_match[6*FX_TLP_ADR_DEC*(1+func)-1:6*FX_TLP_ADR_DEC*func]),
    .cfg_bar_is_io                  (cfg_bar_is_io[6*(1+func)-1:6*func]),
    .cfg_rom_match                  (cfg_rom_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .rcrb_address_reg               (rcrb_address_reg_int[func]),
    .cfg_rcrb_match                 (cfg_rcrb_match_int[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_rcrb_mbar0_match           (),
    .cfg_rcrb_mbar0_match_int       (),
    .rcrb_mbar0_base_addr           (),
    .cfg_cxl_2_0_mbar0_match        (cfg_cxl_2_0_mbar0_match_int[func]),
    .cxl_2_0_mbar0_access_int       (cxl_2_0_mbar0_access_int[func]),
    .cfg_cxl_alt_mem_match          (cfg_cxl_alt_mem_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_cxl_alt_prefmem_match      (cfg_cxl_alt_prefmem_match[FX_TLP_ADR_DEC*(1+func)-1:FX_TLP_ADR_DEC*func]),
    .cfg_br_ctrl_serren             (cfg_br_ctrl_serren[func]),
    .cfg_br_ctrl_perren             (cfg_br_ctrl_perren[func]),
    .cfg_bus_master_en              (cfg_bus_master_en[func]),
    .cfg_reg_perren                 (cfg_reg_perren[func]),
    .cfg_reg_serren                 (cfg_reg_serren[func]),
    .cfg_sys_err_rc                 (int_cfg_sys_err_rc[func]),  // Function 0 Only
    .cfg_crs_sw_vis_en              (int_cfg_crs_sw_vis_en[func]),  // Function 0 Only
    .cfg_pme_int                    (int_cfg_pme_int[func]),     // Function 0 Only
    .cfg_pme_msi                    (int_cfg_pme_msi[func]),     // Function 0 Only
    .cfg_2nd_reset_mod              (int_cfg_2nd_reset[func]),
    .cfg_slot_pwr_limit_wr          (cfg_slot_pwr_limit_wr[func]),
    .cfg_pcie_slot_pwr_limit        (cfg_pcie_slot_pwr_limit[10*(1+func)-1:10*func]),
    .cfg_multi_msi_en               (cfg_multi_msi_en_int[3*(1+func)-1:3*func]),
    .cfg_msi_ext_data_en            (cfg_msi_ext_data_en_int[func]),
    .cfg_msi_en                     (cfg_msi_en_int[func]),
    .cfg_msi_addr                   (cfg_msi_addr_int[64*(1+func)-1:64*func]),
    .cfg_msi_data                   (cfg_msi_data_int[32*(1+func)-1:32*func]),
    .cfg_msi_64                     (cfg_msi_64_int[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),
    .cfg_msix_func_mask             (cfg_msix_func_mask[func]),
    .cfg_msix_table_size            (cfg_msix_table_size[11*(1+func)-1:11*func]),
    .cfg_msix_table_size2           (cfg_msix_table_size2[11*(1+func)-1:11*func]),
    .cfg_msix_table_bir             (cfg_msix_table_bir[3*(1+func)-1:3*func]),
    .cfg_msix_table_bir2            (cfg_msix_table_bir2[3*(1+func)-1:3*func]),
    .cfg_msix_table_offset          (cfg_msix_table_offset[29*(1+func)-1:29*func]),
    .cfg_msix_table_offset2         (cfg_msix_table_offset2[29*(1+func)-1:29*func]),
    .cfg_msix_pba_bir               (cfg_msix_pba_bir[3*(1+func)-1:3*func]),
    .cfg_msix_pba_bir2              (cfg_msix_pba_bir2[3*(1+func)-1:3*func]),
    .cfg_msix_pba_offset            (cfg_msix_pba_offset[29*(1+func)-1:29*func]),
    .cfg_msix_pba_offset2           (cfg_msix_pba_offset2[29*(1+func)-1:29*func]),
    .cfg_vpd_int                    (int_cfg_vpd_int[func]),
    .cfg_max_payload_size_out       (cfg_max_payload_size[3*(1+func)-1:3*func]),
// In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
   .cfg_max_payload_size_out_rx     (cfg_max_payload_size_out_rx_int[3*(func)+:3]),
    .cfg_relax_ord_en               (cfg_relax_ord_en[func]),
    .cfg_ext_tag_en                 (cfg_ext_tag_en[func]),
    .cfg_phantom_fun_en             (cfg_phantom_fun_en[func]),
    .cfg_no_snoop_en                (cfg_no_snoop_en[func]),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size[3*(1+func)-1:3*func]),
    .cfg_bridge_crs_en              (cfg_bridge_crs_en[func]),
    .cfg_aslk_pmctrl                (int_cfg_aslk_pmctrl[2*(1+func)-1:2*func]),
    .cfg_upd_aslk_pmctrl_mux        (int_cfg_upd_aslk_pmctrl[func]),
    .cfg_clk_pm_en_mux              (int_cfg_clk_pm_en[func]),
    .cfg_rcb_mux                    (cfg_rcb_rciep[func]),
    .cfg_link_dis_mux               (int_link_dis[func]),
    .cfg_link_retrain_mux           (int_link_retrain[func]),
    .cfg_comm_clk_config_mux        (int_cfg_comm_clk_config[func]),
    .cfg_hw_autowidth_dis_mux       (int_cfg_hw_autowidth_dis[func]),
    .cfg_link_rate                  (int_cfg_link_rate[4*(1+func)-1:4*func]),
    .cfg_retimers_pre_detected      (int_cfg_retimers_pre_detected[2*(1+func)-1:2*func]),
    .cfg_pwr_ind                    (cfg_pwr_ind[2*(1+func)-1:2*func]),
    .cfg_atten_ind                  (cfg_atten_ind[2*(1+func)-1:2*func]),
    .cfg_pwr_ctrler_ctrl            (cfg_pwr_ctrler_ctrl[func]),
    .cfg_hp_int_en                  (cfg_hp_int_en[func]),
    .cfg_atten_button_pressed       (cfg_atten_button_pressed[func]),
    .cfg_eml_control                (cfg_eml_control[func]),
    .cfg_pwr_fault_det              (cfg_pwr_fault_det[func]),
    .cfg_mrl_sensor_chged           (cfg_mrl_sensor_chged[func]),
    .cfg_pre_det_chged              (cfg_pre_det_chged[func]),
    .cfg_cmd_cpled_int              (cfg_cmd_cpled_int[func]),
    .cfg_dll_state_chged            (cfg_dll_state_chged[func]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cfg_cor_err_rpt_en             (cfg_cor_err_rpt_en[func]),
    .cfg_nf_err_rpt_en              (cfg_nf_err_rpt_en[func]),
    .cfg_f_err_rpt_en               (cfg_f_err_rpt_en[func]),
    .cfg_unsupt_req_rpt_en          (cfg_unsupt_req_rpt_en[func]),
    .cfg_pbus_num                   (int_cfg_pbus_num[8*(1+func)-1:8*func]),
    .cfg_2ndbus_num                 (int_cfg_2ndbus_num[8*(1+func)-1:8*func]),
    .cfg_subbus_num                 (int_cfg_subbus_num[8*(1+func)-1:8*func]),
    .cfg_pbus_dev_num               (int_cfg_pbus_dev_num[5*(1+func)-1:5*func]),
    .cfg_bar0_start                 (cfg_bar0_start[64*(1+func)-1:64*func]),
    .cfg_bar0_limit                 (cfg_bar0_limit[64*(1+func)-1:64*func]),
    .cfg_bar1_start                 (cfg_bar1_start[32*(1+func)-1:32*func]),
    .cfg_bar1_limit                 (cfg_bar1_limit[32*(1+func)-1:32*func]),
    .cfg_bar2_start                 (cfg_bar2_start[64*(1+func)-1:64*func]),
    .cfg_bar2_limit                 (cfg_bar2_limit[64*(1+func)-1:64*func]),
    .cfg_bar3_start                 (cfg_bar3_start[32*(1+func)-1:32*func]),
    .cfg_bar3_limit                 (cfg_bar3_limit[32*(1+func)-1:32*func]),
    .cfg_bar4_start                 (cfg_bar4_start[64*(1+func)-1:64*func]),
    .cfg_bar4_limit                 (cfg_bar4_limit[64*(1+func)-1:64*func]),
    .cfg_bar5_start                 (cfg_bar5_start[32*(1+func)-1:32*func]),
    .cfg_bar5_limit                 (cfg_bar5_limit[32*(1+func)-1:32*func]),
    .cfg_bar0_mask                  (cfg_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_bar1_mask                  (cfg_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_bar2_mask                  (cfg_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_bar3_mask                  (cfg_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_bar4_mask                  (cfg_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_bar5_mask                  (cfg_bar5_mask[32*(1+func)-1:32*func]),
    .cfg_rom_mask                   (cfg_rom_mask[32*(1+func)-1:32*func]),
    .cfg_mem_base                   (cfg_mem_base[16*(1+func)-1:16*func]),
    .cfg_mem_limit                  (cfg_mem_limit[16*(1+func)-1:16*func]),
    .cfg_pref_mem_base              (cfg_pref_mem_base[64*(1+func)-1:64*func]),
    .cfg_pref_mem_limit             (cfg_pref_mem_limit[64*(1+func)-1:64*func]),
    .cfg_exp_rom_start              (cfg_exp_rom_start[32*(1+func)-1:32*func]),
    .cfg_exp_rom_limit              (cfg_exp_rom_limit[32*(1+func)-1:32*func]),
    .cfg_io_limit_upper16           (cfg_io_limit_upper16[16*(1+func)-1:16*func]),
    .cfg_io_base_upper16            (cfg_io_base_upper16[16*(1+func)-1:16*func]),
    .cfg_io_base                    (cfg_io_base[8*(1+func)-1:8*func]),
    .cfg_io_limit                   (cfg_io_limit[8*(1+func)-1:8*func]),
    .cfg_hdr_type                   (int_cfg_hdr_type[8*(1+func)-1:8*func]),
    .cfg_ext_synch                  (int_ext_synch[func]),
    .cfg_io_space_en                (cfg_io_space_en[func]),
    .cfg_mem_space_en               (cfg_mem_space_en[func]),

    .cfg_cap_reg_ack                (cfg_cap_reg_ack[func]),
    .cfg_cap_reg_data               (cfg_cap_reg_data[32*(1+func)-1:32*func]),
    .cfg_reg_data                   (cfg_reg_data[32*(1+func)-1:32*func]),
    .cfg_reg_ack                    (cfg_reg_ack[func]),
    .cfg_upd_pmcsr                  (cfg_upd_pmcsr[func]),
    .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en[func]),
    .cfg_upd_req_id                 (cfg_upd_req_id[func]),
    .cfg_aux_pm_en                  (cfg_aux_pm_en[func]),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr[func]),
    .cfg_pmstate                    (cfg_pmstate[3*(1+func)-1:3*func]),
    .cfg_pme_en                     (cfg_pme_en[func]),
    .cfg_pme_cap                    (cfg_pme_cap[5*(1+func)-1:5*func]),
    .cfg_pm_no_soft_rst             (cfg_pm_no_soft_rst[func]),
    .cfg_isa_enable                 (cfg_isa_enable[func]),
    .cfg_vga_enable                 (cfg_vga_enable[func]),
    .cfg_vga16_decode               (cfg_vga16_decode[func]),
    .cfg_int_pin                    (cfg_int_pin[8*(1+func)-1:8*func]),
    .cfg_link_auto_bw_int_mux       (int_cfg_link_auto_bw_int[func]),                       // Function 0 Only
    .cfg_link_auto_bw_msi_mux       (int_cfg_link_auto_bw_msi[func]),                       // Function 0 Only
    .cfg_bw_mgt_int_mux             (int_cfg_bw_mgt_int[func]),                             // Function 0 Only
    .cfg_bw_mgt_msi_mux             (int_cfg_bw_mgt_msi[func]),                             // Function 0 Only
    .cfg_pcie_max_link_speed        (pf_cfg_pcie_max_link_speed_bus[4*(1+func)-1:4*func]),
    .cfg_target_link_speed          (int_cfg_target_link_speed[4*(1+func)-1:4*func]),       // Function 0 Only
    .cfg_enter_compliance_mux       (int_cfg_enter_compliance[func]),                       // Function 0 Only
    .cfg_hw_auto_sp_dis_mux         (int_cfg_hw_auto_sp_dis[func]),                         // Function 0 Only
    .cfg_sel_de_emphasis_mux        (int_cfg_sel_de_emphasis[func]),                        // Function 0 Only
    .cfg_transmit_margin_mux        (int_cfg_transmit_margin[3*(1+func)-1:3*func]),         // Function 0 Only
    .cfg_enter_mod_compliance_mux   (int_cfg_enter_mod_compliance[func]),                   // Function 0 Only
    .cfg_compliance_sos_mux         (int_cfg_compliance_sos[func]),                         // Function 0 Only
    .cfg_compliance_de_emphasis_mux (int_cfg_compliance_de_emphasis[4*(1+func)-1:4*func]),  // Function 0 Only
//    .target_mem_map                 (target_mem_map[6*(1+func)-1:6*func]),
//    .target_rom_map                 (target_rom_map[func]),
    .cfg_atomic_req_en              (cfg_atomic_req_en[func]),
    .cfg_atomic_egress_block        (cfg_atomic_egress_block[func]),
    .cfg_obff_en                    (int_cfg_obff_en[2*(1+func)-1:2*func]),
    .cfg_ltr_m_en                   (int_cfg_ltr_m_en[func]),
    .cfg_ltr_clr_msg_req            (int_cdm2msgg_ltr_clr_msg_req[func]),

    .cfg_pcie_aspm_cap_mux          (pf_cfg_pcie_aspm_cap_bus[2*(1+func)-1:2*func]),
     .cfg_pcie_max_link_width        (pf_cfg_pcie_max_link_width_bus[6*(1+func)-1:6*func]),
    .cfg_ido_req_en                 (pf_cfg_ido_req_en[func]),          //cdm_cfg_reg
    .cfg_ido_cpl_en                 (pf_cfg_ido_cpl_en[func]),


    .cfg_drs_msi                    (cfg_drs_msi_rciep[func]),
    .cfg_downstream_comp_pres_mux   (cfg_downstream_comp_pres[3*(1+func)-1:3*func]),
    .cfg_up_drs_to_frs              (cfg_up_drs_to_frs_rciep[func]),
    .cfg_drs_frs_sig_en             (cfg_drs_frs_sig_en[func]),

    .cfg_pcie_cap_int_msg_num       (cfg_pcie_cap_int_msg_num[5*(1+func)-1:5*func]),
    .cfg_ari_fwd_en                 (cfg_ari_fwd_en[func]),
    .cfg_cpl_timeout_range_out          (cfg_cpl_timeout_range[4*(1+func)-1:4*func]),
    .cfg_cpl_timeout_disable_out        (cfg_cpl_timeout_disable[func])
    ,
    .cfg_pcie_crosslink_supported   (int_cfg_pcie_crosslink_supported[func])   // Function 0 Only
    ,.cfg_ls2_eq_req_mux             (int_cfg_ls2_eq_req[func])   // Function 0 Only
    ,
    .cfg_end2end_tlp_pfx_blck        (cfg_end2end_tlp_pfx_blck[func]),
    .cfg_max_end2end_tlp_prfxs       (cfg_max_end2end_tlp_prfxs[2*(1+func)-1:2*func])
    ,
    . cfg_10b_tag_req_en             (cfg_10b_tag_req_en[func])

    ,
    .surprise_down_err               (surprise_down_err[func])
    ,
    .cfg_pcie_surp_dn_rpt_cap_mux    (cfg_pcie_surp_dn_rpt_cap[func])

    ,
    .cfg_pcie_slot_clk_config_mux    (cfg_pcie_slot_clk_config_i[func]),
    .cfg_auto_slot_pwr_lmt_dis       (cfg_auto_slot_pwr_lmt_dis[func]),
    .cfg_hp_slot_ctrl_access         (cfg_hp_slot_ctrl_access[func]),
    .cfg_dll_state_chged_en          (cfg_dll_state_chged_en[func]),
    .cfg_cmd_cpled_int_en_r          (cfg_cmd_cpled_int_en[func]),
    .cfg_pre_det_chged_en            (cfg_pre_det_chged_en[func]),
    .cfg_mrl_sensor_chged_en_r       (cfg_mrl_sensor_chged_en[func]),
    .cfg_pwr_fault_det_en_r          (cfg_pwr_fault_det_en[func]),
    .cfg_atten_button_pressed_en_r   (cfg_atten_button_pressed_en[func])

    ,.cfg_pcie_cap_flit_mode_sup      (cfg_int_pcie_cap_flit_mode_sup[func])
    ,.cfg_flit_mode_dis               (cfg_int_flit_mode_dis[func])
    ,.cfg_flit_sris_clocking          (cfg_int_flit_sris_clocking[func])
    ,.cfg_pcie_cap_flit_mode_stat     (cfg_int_pcie_cap_flit_mode_stat[func])

    ,.cfg_neg_link_width             (cfg_int_link_width[6*func +: 6])


); // cdm_cfg_reg

// -----------------------------------------------------------------------------
// Extended PCIE config registers
// -----------------------------------------------------------------------------

cdm_ecfg_reg

#(.INST(INST), .FUNC_NUM(func), .NPTMVSEC(NPTMVSEC)
, .RCRB(0)
)
u_cdm_ecfg_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .device_type                    (device_type),
    .lbc_cdm_addr                   (cdm_pf_ecfg_addr[15:0]),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    .ecfg_reg_sel                   (ecfg_reg_sel[func]),
    .err_reg_data                   (err_reg_data[32*(1+func)-1:32*func]),
    .ras_reg_ack                    (ras_reg_ack),
    .ras_reg_data                   (ras_reg_data),
    .cfg_ras_reg_pf0_only           (cfg_ras_reg_pf0_only),
    .spcie_reg_data                 (spcie_reg_data),
    .pl16g_reg_data                 (pl16g_reg_data),
    .margin_reg_data                (margin_reg_data),
    .pl32g_reg_data                 (pl32g_reg_data),
    .pl64g_reg_data                 (pl64g_reg_data),
    .l1sub_reg_data                 (l1sub_reg_data),
    .dev3_reg_data                  (dev3_reg_data[32*(1+func)-1:32*func]),
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .cfg_pwr_budget_data_reg        (cfg_pwr_budget_data_reg),
    .cfg_pwr_budget_func_num        (cfg_pwr_budget_func_num),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .rasdes_reg_data                (rasdes_reg_data),
    .rasdes_reg_ack                 (rasdes_reg_ack),
    .cfg_rasdes_reg_pf0_only        (cfg_rasdes_reg_pf0_only),

    .cfg_msi_en                     (cfg_msi_en_int[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),
    .radm_drs_msg                   (radm_drs_msg),
    .radm_msg_req_id                (radm_msg_req_id),
    .cfg_downstream_comp_pres       (cfg_downstream_comp_pres[3*(1+func)-1:3*func]),     //ecfg

    .cfg_drs_frs_sig_en             (cfg_drs_frs_sig_en[func]),
    .radm_frs_msg                   (radm_frs_msg),
    .radm_frs_msg_reason            (radm_frs_msg_reason),
    .cfg_pbus_num                   (int_cfg_pbus_num[8*(1+func)-1:8*func]),
    .cfg_pbus_dev_num               (int_cfg_pbus_dev_num[5*(1+func)-1:5*func]),
    .pmstate_d3hot_to_d0            (pmstate_d3hot_to_d0[func]),

    .ptm_vsec_reg_data              (ptm_vsec_reg_data[31:0]),
    .ptm_reg_data                   (ptm_reg_data[31:0]),

    .vsecdma_reg_data              (vsecdma_reg_data[31:0]),


    .upstream_port                  (upstream_port),
    .rdlh_link_up                   (rdlh_link_up),
    .prs_res_failure                (prs_res_failure[func]),
    .prs_uprgi                      (prs_uprgi[func]),
    .prs_stopped                    (prs_stopped[func]),
    .rdlh_rcvd_dl_feature           (rdlh_rcvd_dl_feature),
    .rcvd_dl_feature_content        (rcvd_dl_feature_content),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),     // input [1:0]
    .int_dpc_triggered              (int_dpc_triggered[func]),                      // Function 0 Only
    .int_dpc_trig_reason            (int_dpc_trig_reason[2*(1+func)-1:2*func]),     // Function 0 Only
    .int_dpc_trig_reason_extn       (int_dpc_trig_reason_extn[2*(1+func)-1:2*func]),     // Function 0 Only
    .dpc_err_src_id                 (dpc_err_src_id[16*(1+func)-1:16*func]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .cxl2p0_enabled                 (cxl_mbar0_enable),
    .cxl_mld_enabled                (ltssm_cxl_enable.cxl_mld_enabled),
    .cxl_reg_data                   (cxl_reg_data[func]),
    .cxl_rcrb_reg_data              (cxl_port_reg_data),
    .cxl_mbar0_reg_sel              (rcrb_mbar0_reg_sel_downstream),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .cxl_2_0_ext_reg_data           (cxl_2_0_ext_reg_data),
    .cxl_reg_locator_reg_data       (cxl_reg_locator_reg_data[func]),
    .cxl_gpf_port_reg_data          (cxl_gpf_port_reg_data),
    .cxl_gpf_device_reg_data        (cxl_gpf_device_reg_data[func]),
    .cfg_pcie_cap_flit_mode_sup     ( cfg_pcie_cap_flit_mode_sup ),
    .cfg_flit_log                   ( cfg_flit_log               ),
    .cfg_link_wd_err_cnt_start      ( cfg_link_wd_err_cnt_start  ),
    .cfg_flit_err_cnt               ( cfg_flit_err_cnt           ),
    .cfg_flit_cnt                   ( cfg_flit_cnt               ),
    .cfg_invalid_flit_cnt           ( cfg_invalid_flit_cnt       ),
    .cfg_interr_trg_evnt_cnt        ( cfg_interr_trg_evnt_cnt    ),
    .cfg_interr_trg_evnt_cnt_clr    ( cfg_interr_trg_evnt_cnt_clr),
    .cfg_lane_0_corr_cnt            ( cfg_lane_0_corr_cnt        ),
    .cfg_lane_1_corr_cnt            ( cfg_lane_1_corr_cnt        ),
    .cfg_lane_2_corr_cnt            ( cfg_lane_2_corr_cnt        ),
    .cfg_lane_3_corr_cnt            ( cfg_lane_3_corr_cnt        ),
    .cfg_lane_4_corr_cnt            ( cfg_lane_4_corr_cnt        ),
    .cfg_lane_5_corr_cnt            ( cfg_lane_5_corr_cnt        ),
    .cfg_lane_6_corr_cnt            ( cfg_lane_6_corr_cnt        ),
    .cfg_lane_7_corr_cnt            ( cfg_lane_7_corr_cnt        ),
    .cfg_lane_8_corr_cnt            ( cfg_lane_8_corr_cnt        ),
    .cfg_lane_9_corr_cnt            ( cfg_lane_9_corr_cnt        ),
    .cfg_lane_10_corr_cnt           ( cfg_lane_10_corr_cnt       ),
    .cfg_lane_11_corr_cnt           ( cfg_lane_11_corr_cnt       ),
    .cfg_lane_12_corr_cnt           ( cfg_lane_12_corr_cnt       ),
    .cfg_lane_13_corr_cnt           ( cfg_lane_13_corr_cnt       ),
    .cfg_lane_14_corr_cnt           ( cfg_lane_14_corr_cnt       ),
    .cfg_lane_15_corr_cnt           ( cfg_lane_15_corr_cnt       ),
                                 .cfg_flit_latency_status                  (xplh_cdm_flit_latency_tracking.flit_latency_status) 
                                ,.cfg_flit_latency_value                   (xplh_cdm_flit_latency_tracking.flit_latency_value) 
                                ,.cfg_ltssm_st_trans1_status               (pm_cdm_state_trans_tracking.state_trans1_status) 
                                ,.cfg_ltssm_st_trans2_status               (pm_cdm_state_trans_tracking.state_trans2_status) 
                                ,.cfg_ltssm_st_trans3_status               (pm_cdm_state_trans_tracking.state_trans3_status) 
                                ,.cfg_ltssm_st_trans4_status               (pm_cdm_state_trans_tracking.state_trans4_status) 
                                ,.cfg_ltssm_st_trans5_status               (pm_cdm_state_trans_tracking.state_trans5_status) 
                                ,.cfg_ltssm_st_trans_latency               (pm_cdm_state_trans_tracking.state_trans_latency)                                                                                   
                                ,.cfg_msi_en_pf0                           (     cfg_msi_en_pf0                           )
                                ,.cfg_msix_en_pf0                          (     cfg_msix_en_pf0                          ),
                                 .cfg_flit_err_tx_inj_sts                  (     plh_cdm_flit_err_inj_status.cfg_tx_inj_sts           )
                                ,.cfg_flit_err_rx_inj_sts                  (     plh_cdm_flit_err_inj_status.cfg_rx_inj_sts           )
                                ,.cfg_ordr_set_tx_inj_sts_ts0              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_ts0            )
                                ,.cfg_ordr_set_tx_inj_sts_ts1              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_ts1            )
                                ,.cfg_ordr_set_tx_inj_sts_ts2              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_ts2            )
                                ,.cfg_ordr_set_tx_inj_sts_skp              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_skp            )
                                ,.cfg_ordr_set_tx_inj_sts_eieos            (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_eieos          )
                                ,.cfg_ordr_set_tx_inj_sts_eios             (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_eios           )
                                ,.cfg_ordr_set_tx_inj_sts_sds              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_sds            )
                                ,.cfg_ordr_set_tx_inj_sts_poll             (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_poll           )
                                ,.cfg_ordr_set_tx_inj_sts_cfg              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_cfg            )
                                ,.cfg_ordr_set_tx_inj_sts_l0               (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_l0             )
                                ,.cfg_ordr_set_tx_inj_sts_non_eq_recov     (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_non_eq_recov   )
                                ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0  (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_1_0)
                                ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_2    (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_2  )
                                ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_3    (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_3  )
                                ,.cfg_ordr_set_rx_inj_sts_ts0              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_ts0            )
                                ,.cfg_ordr_set_rx_inj_sts_ts1              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_ts1            )
                                ,.cfg_ordr_set_rx_inj_sts_ts2              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_ts2            )
                                ,.cfg_ordr_set_rx_inj_sts_skp              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_skp            )
                                ,.cfg_ordr_set_rx_inj_sts_eieos            (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_eieos          )
                                ,.cfg_ordr_set_rx_inj_sts_eios             (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_eios           )
                                ,.cfg_ordr_set_rx_inj_sts_sds              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_sds            )
                                ,.cfg_ordr_set_rx_inj_sts_poll             (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_poll           )
                                ,.cfg_ordr_set_rx_inj_sts_cfg              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_cfg            )
                                ,.cfg_ordr_set_rx_inj_sts_l0               (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_l0             )
                                ,.cfg_ordr_set_rx_inj_sts_non_eq_recov     (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_non_eq_recov   )
                                ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0  (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_1_0)
                                ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_2    (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_2  )
                                ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_3    (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_3  ),
// ---------- Outputs --------
    .ecfg_reg_data                  (ecfg_reg_data[32*(1+func)-1:32*func]),
    .ecfg_reg_ack                   (ecfg_reg_ack[func]),
    .ecfg_write_pulse               (ecfg_write_pulse[func]),
    .ecfg_read_pulse                (ecfg_read_pulse[func]),
    .err_reg_id                     (err_reg_id[ERR_REG_ID_WD*(1+func)-1:ERR_REG_ID_WD*func]),
    .ras_reg_sel                    (ras_reg_sel[func]),
    .ras_reg_id                     (ras_reg_id[NR_RAS_REGS*(1+func)-1:NR_RAS_REGS*func]),
    .spcie_reg_id                   (cfg_spcie_reg_id[NSPCIE*(1+func)-1:NSPCIE*func]),
    .pl16g_reg_id                   (cfg_pl16g_reg_id[NPL16G*(1+func)-1:NPL16G*func]),
    .margin_reg_id                  (cfg_margin_reg_id[NMARGIN*(1+func)-1:NMARGIN*func]),
    .pl32g_reg_id                   (cfg_pl32g_reg_id[NPL32G*(1+func)-1:NPL32G*func]),
    .pl64g_reg_id                   (cfg_pl64g_reg_id[NPL64G*(1+func)-1:NPL64G*func]),
    .l1sub_reg_id                   (cfg_l1sub_reg_id[NL1SUB*(1+func)-1:NL1SUB*func]),
    .dev3_reg_id                    (dev3_reg_id[NDEV3_REGS*(1+func)-1:NDEV3_REGS*func]),
    .rasdes_reg_sel                 (rasdes_reg_sel[func]),
    .rasdes_reg_id                  (rasdes_reg_id[64*(1+func)-1:64*func]),
    .cfg_tph_req_en                 (cfg_tph_req_en[2*(1+func)-1:2*func]),
    .cfg_pf_tph_st_mode             (cfg_pf_tph_st_mode[3*(1+func)-1:3*func]),
    .frsq_msi                       (cfg_frsq_msi[func]),           //mutiple outputs in DM with Funtions>1
    .frsq_int_msg_num               (cfg_frsq_int_msg_num[5*(1+func)-1:5*func]),
    .cfg_ats_stu                    (cfg_ats_stu[5*(1+func)-1:5*func]),
    .cfg_ats_cache_en               (cfg_ats_cache_en[func]),

    .cfg_acs_validation_cap                      (cfg_acs_validation_cap_num[func]),
    .cfg_acs_at_blocking_cap                     (cfg_acs_at_blocking_cap_num[func]),
    .cfg_acs_up_forward_cap                      (cfg_acs_up_forward_cap_num[func]),
    .cfg_acs_p2p_req_redirect_cap                (cfg_acs_p2p_req_redirect_cap[func]),
    .cfg_acs_p2p_compl_redirect_cap              (cfg_acs_p2p_compl_redirect_cap[func]),
    .cfg_acs_p2p_egress_ctrl_cap                 (cfg_acs_p2p_egress_ctrl_cap[func]),
    .cfg_acs_p2p_direct_transl_cap               (cfg_acs_p2p_direct_transl_cap[func]),
    .cfg_acs_egress_ctrl_vector_size_cap         (cfg_acs_egress_ctrl_vector_size_cap[8*(1+func)-1:8*func]),
    .cfg_acs_validation_en                       (cfg_acs_validation_en_num[func]),
    .cfg_acs_at_blocking_en                      (cfg_acs_at_blocking_en_num[func]),
    .cfg_acs_p2p_req_redirect_en                 (cfg_acs_p2p_req_redirect_en[func]),
    .cfg_acs_p2p_compl_redirect_en               (cfg_acs_p2p_compl_redirect_en[func]),
    .cfg_acs_up_forward_en                       (cfg_acs_up_forward_en_num[func]),
    .cfg_acs_p2p_egress_ctrl_en                  (cfg_acs_p2p_egress_ctrl_en[func]),
    .cfg_acs_p2p_direct_transl_en                (cfg_acs_p2p_direct_transl_en[func]),
    .cfg_acs_egress_ctrl_vec                     (cfg_acs_egress_ctrl_vec[ACS_CTRL_VEC_WD*(1+func)-1:ACS_CTRL_VEC_WD*func]),
    .acs_viol_svrity_mask_wr_en                  (acs_viol_svrity_mask_wr_en[func]),

    .cfg_prs_enable                 (cfg_prs_enable[func]),
    .cfg_prs_reset                  (cfg_prs_reset[func]),
    .cfg_prs_stopped                (cfg_prs_stopped[func]),
    .cfg_prs_uprgi                  (cfg_prs_uprgi[func]),
    .cfg_prs_response_failure       (cfg_prs_response_failure[func]),
    .cfg_prs_outstanding_allocation (cfg_prs_outstanding_allocation[32*(1+func)-1:32*func]),
    .cfg_ltr_max_latency            (cfg_ltr_max_latency[32*(1+func)-1:32*func]),
    .cfg_vc_enable                  (int_cfg_vc_enable[NVC*(1+func)-1:NVC*func]),               // Function 0 Only
    .cfg_vc_struc_vc_id_map         (int_cfg_vc_struc_vc_id_map[NVC*3*(1+func)-1:NVC*3*func]),  // Function 0 Only
    .cfg_vc_id_vc_struc_map         (int_cfg_vc_id_vc_struc_map[24*(1+func)-1:24*func]),        // Function 0 Only
    .cfg_tc_enable                  (int_cfg_tc_enable[8*(1+func)-1:8*func]),                   // Function 0 Only
    .cfg_tc_vc_map                  (int_cfg_tc_vc_map[24*(1+func)-1:24*func]),                 // Function 0 Only
    .cfg_tc_vc_struc_map            (int_cfg_tc_struc_vc_map[24*(1+func)-1:24*func]),           // Function 0 Only
    .cfg_lpvc                       (int_cfg_lpvc[3*(1+func)-1:3*func]),                        // Function 0 Only
    .cfg_vc_arb_sel                 (int_cfg_vc_arb_sel[3*(1+func)-1:3*func]),                  // Function 0 Only
    .cfg_pwr_budget_data_sel_reg    (int_cfg_pwr_budget_data_sel_reg[8*(1+func)-1:8*func]),
    .cfg_pwr_budget_sel             (int_cfg_pwr_budget_sel[func]),
    .cfg_rbar_bar_resizable         (int_cfg_rbar_bar_resizable[6*(1+func)-1:6*func]),
    .cfg_rbar_bar0_mask             (int_cfg_rbar_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar1_mask             (int_cfg_rbar_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar2_mask             (int_cfg_rbar_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar3_mask             (int_cfg_rbar_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_rbar_bar4_mask             (int_cfg_rbar_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_rbar_bar5_mask             (int_cfg_rbar_bar5_mask[32*(1+func)-1:32*func]),
    .cfg_vf_rbar_bar_resizable      (int_cfg_vf_rbar_bar_resizable[6*(1+func)-1:6*func]),
    .cfg_vf_rbar_bar0_mask          (int_cfg_vf_rbar_bar0_mask[64*(1+func)-1:64*func]),
    .cfg_vf_rbar_bar1_mask          (int_cfg_vf_rbar_bar1_mask[32*(1+func)-1:32*func]),
    .cfg_vf_rbar_bar2_mask          (int_cfg_vf_rbar_bar2_mask[64*(1+func)-1:64*func]),
    .cfg_vf_rbar_bar3_mask          (int_cfg_vf_rbar_bar3_mask[32*(1+func)-1:32*func]),
    .cfg_vf_rbar_bar4_mask          (int_cfg_vf_rbar_bar4_mask[64*(1+func)-1:64*func]),
    .cfg_vf_rbar_bar5_mask          (int_cfg_vf_rbar_bar5_mask[32*(1+func)-1:32*func])
    ,
    .cfg_pf_pasid_control           (cfg_pf_pasid_control[PASID_CNTRL_WD*(1+func)-1:PASID_CNTRL_WD*func])

    ,
    .ptm_vsec_reg_id                (ptm_vsec_reg_id[NPTMVSEC*(1+func)-1:NPTMVSEC*func])

    ,.vsecdma_reg_sel                (vsecdma_reg_sel[func])
    ,.vsecdma_reg_id                 (vsecdma_reg_id[6*(1+func)-1:6*func])

    ,
    .dl_feature_en                  (int_dl_feature_en[func]),
    .cfg_remote_feature_ack         (int_cfg_remote_feature_ack[func]),
    .cfg_local_feature_support      (int_cfg_local_feature_support[23*func +: 23]),
    .cfg_remote_feature_support     (),
    .cfg_dlink_feature_valid        (int_cfg_dlink_feature_valid[func])
    ,
    .fc_scaled_en                   (int_fc_scaled_en[func])
    ,
    .cfg_dpc_int_msg_num                (int_dpc_int_msg_num[5*(1+func)-1:5*func]),
    .cfg_dpc_rp_ext_dpc                 (int_dpc_rp_ext_dpc[func]),
    .cfg_dpc_poison_tlp_egr_blk_support (int_dpc_poison_tlp_egr_blk_support[func]),
    .cfg_dpc_sw_trig_support            (int_dpc_sw_trig_support[func]),
    .cfg_dpc_rp_pio_log_size            (int_dpc_rp_pio_log_size[4*(1+func)-1:4*func]),
    .cfg_dpc_dl_active_err_cor_support  (int_dpc_dl_active_err_cor_support[func]),
    .cfg_dpc_trig_en                    (int_dpc_trig_en[2*(1+func)-1:2*func]),
    .cfg_dpc_trig_status                (cfg_dpc_trig_status[func]),
    .dpc_triggered_detect               (dpc_triggered_detect[func]),
    .dpc_int                            (int_dpc_int[func]),
    .dpc_msi                            (int_dpc_msi[func]),
    .cfg_dpc_cpl_cntrl                  (int_dpc_cpl_cntrl[func]),
    .cfg_dpc_int_en                     (int_dpc_int_en[func]),
    .cfg_dpc_err_cor_en                 (int_dpc_err_cor_en[func]),
    .cfg_dpc_poison_tlp_egr_block_en    (int_dpc_poison_tlp_egr_block_en[func]),
    .cfg_dpc_sw_trigger                 (int_dpc_sw_trigger[func]),
    .cfg_dpc_dl_active_err_cor_en       (int_dpc_dl_active_err_cor_en[func])
    ,
    .rbar_ctrl_update               (rbar_ctrl_update[func]),
    .cfg_rbar_size                  (cfg_rbar_size[func*6*6 +: 6*6]),
    .vf_rbar_ctrl_update            (vf_rbar_ctrl_update[func]),
    .cfg_vf_rbar_size               (cfg_vf_rbar_size[func*6*6 +: 6*6])

   ,.cxl_reg_id                     (cxl_reg_id[func])
   ,.cxl_rcrb_reg_id                (cfg_cxl_port_reg_id[func])
   ,.cxl_mbar0_write_pulse          (cxl_mbar0_write_pulse_downstream[4*(func+1)-1:4*func])
   ,.cxl_mbar0_reg_ack              (rcrb_mbar0_reg_ack_downstream[func])
   ,.cxl_mbar0_cache_mem_reg_id     (cxl_mbar0_cache_mem_reg_id_downstream[NCXL_MEMBAR0_CACHE_MEM*(func+1)-1:NCXL_MEMBAR0_CACHE_MEM*func])
   ,.cxl_mbar0_arb_mux_reg_id       (cxl_mbar0_arb_mux_reg_id_downstream[NCXL_MEMBAR0_ARB_MUX*(func+1)-1:NCXL_MEMBAR0_ARB_MUX*func])
   ,.cxl_2_0_ext_reg_id             (cxl_2_0_ext_reg_id[10*(func+1)-1:10*func])
   ,.cxl_reg_locator_reg_id         (cxl_reg_locator_reg_id[func])
   ,.cxl_gpf_port_reg_id            (cxl_gpf_port_reg_id[4*(func+1)-1:4*func])
   ,.cxl_gpf_device_reg_id          (cxl_gpf_device_reg_id[func])
    ,.cfg_trg_evnt_cnt                   ( int_cfg_trg_evnt_cnt[func*8 +: 8]            )               
    ,.cfg_evnt_to_cnt                    ( int_cfg_evnt_to_cnt[func*2 +: 2]             )               
    ,.cfg_flit_err_cnt_en                ( int_cfg_flit_err_cnt_en[func]                ) 
    ,.cfg_interr_trg_evnt_cnt_ind        ( int_cfg_interr_trg_evnt_cnt_ind[func]        )
    ,.cfg_fber_measurement_en            ( int_cfg_fber_measurement_en[func]            )
    ,.cfg_clr_fber_cnt                   ( int_cfg_clr_fber_cnt[func]                   )
    ,.cfg_gran_per_lane_err_rpt          ( int_cfg_gran_per_lane_err_rpt[func*2 +: 2]   )
    ,.cfg_rpt_longest_burst_vs_1st_burst ( int_cfg_rpt_longest_burst_vs_1st_burst[func] )
    ,.cfg_flit_log_trg_evnt_msi          ( int_cfg_flit_log_trg_evnt_msi[func]          )
    ,.cfg_pop_fifo_en                    ( int_cfg_pop_fifo_en[func]                    )

                                 ,.cfg_flit_perf_interr_vec            (  int_cfg_flit_perf_interr_vec[func*10 +: 10]         )
                                 ,.cfg_ltssm_trck_reg_cnt              (  int_cfg_ltssm_trck_reg_cnt[func*3 +: 3]             )
                                 ,.cfg_flit_response_type              (  int_cfg_flit_response_type[func*3 +: 3]             )
                                 ,.cfg_flit_type_measured              (  int_cfg_flit_type_measured[func*2 +: 2]             )
                                 ,.cfg_track_mode                      (  int_cfg_xplh_flit_track_mode[func]                  )
                                 ,.cfg_Ltssm_st_trans_trck             (  int_cfg_Ltssm_st_trans_trck[func*5 +: 5]            )
                                 ,.cfg_trg_evnt_interr                 (  int_cfg_trg_evnt_interr[func]                       )  
                                 ,.cfg_flit_latency_msi                (  int_cfg_flit_latency_msi[func]                      )  
                                 ,.cfg_sts_1_ltssm_trg_evnt_interr     (  int_cfg_sts_1_ltssm_trg_evnt_interr[func]           )
                                 ,.cfg_sts_1_ltssm_latency_msi      (  int_cfg_sts_1_ltssm_latency_msi[func]            )

               
                                 ,.cfg_flit_err_inj_en                 (    int_cfg_flit_err_inj_en[func]                    )
                                 ,.cfg_inj_err_tx_flit_ind             (    int_cfg_inj_err_tx_flit_ind[func]                )
                                 ,.cfg_inj_err_rx_flit_ind             (    int_cfg_inj_err_rx_flit_ind[func]                )
                                 ,.cfg_flit_err_inj_en_data_rate       (    int_cfg_flit_err_inj_en_data_rate[func*13+:13]   )
                                 ,.cfg_inj_err_num                     (    int_cfg_inj_err_num[func*5 +:5]                  )
                                 ,.cfg_inj_err_spacing                 (    int_cfg_inj_err_spacing[func*8 +:8]              )
                                 ,.cfg_flit_type_inj                   (    int_cfg_flit_type_inj[func*3 +:3]                )
                                 ,.cfg_consec_err_inj                  (    int_cfg_consec_err_inj[func*3 +:3]               )
                                 ,.cfg_curr_inj_err_type               (    int_cfg_curr_inj_err_type[func*2 +:2]            )
                                 ,.cfg_flit_err_off                    (    int_cfg_flit_err_off[func*7 +:7]                 )
                                 ,.cfg_err_mag                         (    int_cfg_err_mag[func*8 +:8]                      )
                                 ,.cfg_ordr_set_err_inj_en             (    int_cfg_ordr_set_err_inj_en[func]                )
                                 ,.cfg_inj_err_tx_ordr_set_ind         (    int_cfg_inj_err_tx_ordr_set_ind[func]            )
                                 ,.cfg_inj_err_rx_ordr_set_ind         (    int_cfg_inj_err_rx_ordr_set_ind[func]            )
                                 ,.cfg_ordr_set_inj_err_num            (    int_cfg_ordr_set_inj_err_num[func*5 +:5]         )
                                 ,.cfg_ordr_set_inj_err_spacing        (    int_cfg_ordr_set_inj_err_spacing[func*8 +:8]     )
                                 ,.cfg_inj_err_ts0_os                  (    int_cfg_inj_err_ts0_os[func]                     )
                                 ,.cfg_inj_err_ts1_os                  (    int_cfg_inj_err_ts1_os[func]                     )
                                 ,.cfg_inj_err_ts2_os                  (    int_cfg_inj_err_ts2_os[func]                     )
                                 ,.cfg_inj_err_skp_os                  (    int_cfg_inj_err_skp_os[func]                     )
                                 ,.cfg_inj_err_eieos_os                (    int_cfg_inj_err_eieos_os[func]                   )
                                 ,.cfg_inj_err_eios_os                 (    int_cfg_inj_err_eios_os[func]                    )
                                 ,.cfg_inj_err_sds_os                  (    int_cfg_inj_err_sds_os[func]                     )
                                 ,.cfg_inj_err_poll_st                 (    int_cfg_inj_err_poll_st[func]                    )
                                 ,.cfg_inj_err_cfg_st                  (    int_cfg_inj_err_cfg_st[func]                     )
                                 ,.cfg_inj_err_l0_st                   (    int_cfg_inj_err_l0_st[func]                      )
                                 ,.cfg_inj_err_non_eq_recov_st         (    int_cfg_inj_err_non_eq_recov_st[func]            )
                                 ,.cfg_inj_err_recov_eq_ph_1_0         (    int_cfg_inj_err_recov_eq_ph_1_0[func]            )
                                 ,.cfg_inj_err_recov_eq_ph_2           (    int_cfg_inj_err_recov_eq_ph_2[func]              )
                                 ,.cfg_inj_err_recov_eq_ph_3           (    int_cfg_inj_err_recov_eq_ph_3[func]              )
                                 ,.cfg_err_inj_bytes                   (    int_cfg_err_inj_bytes[func*16 +:16]              )
                                 ,.cfg_err_inj_lane_num                (    int_cfg_err_inj_lane_num[func*16 +:16]           )

); // cdm_ecfg_reg


// -----------------------------------------------------------------------------
// cdm_error_reg instantiation
// -----------------------------------------------------------------------------

cdm_error_reg

#(.INST(INST), .FUNC_NUM(func))
u_cdm_error_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .device_type                    (device_type),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .err_write_pulse                (ecfg_write_pulse[func]),
    .err_read_pulse                 (ecfg_read_pulse[func]),
    .err_reg_id                     (err_reg_id[ERR_REG_ID_WD*(1+func)-1:ERR_REG_ID_WD*func]),
    .rcrb_err_write_pulse           (rcrb_err_write_pulse[4*(1+func)-1:4*func]),
    .rcrb_err_read_pulse            (rcrb_err_read_pulse[func]),
    .rcrb_err_reg_id_0              (rcrb_err_reg_id_mod[ERR_REG_ID_WD*func]),
    .pm_bus_num                     (int_cfg_pbus_num[7:0]),
    .pm_dev_num                     (int_cfg_pbus_dev_num[4:0]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cfg_msi_en                     (cfg_msi_en_int[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),
    .cfg_br_ctrl_serren             (cfg_br_ctrl_serren[func]),
    .cfg_br_ctrl_perren             (cfg_br_ctrl_perren[func]),
    .cfg_reg_perren                 (cfg_reg_perren[func]),
    .cfg_reg_serren                 (cfg_reg_serren[func]),
    .cfg_cor_err_rpt_en             (cfg_cor_err_rpt_en[func]),
    .cfg_nf_err_rpt_en              (cfg_nf_err_rpt_en[func]),
    .cfg_f_err_rpt_en               (cfg_f_err_rpt_en[func]),
    .cfg_unsupt_req_rpt_en          (cfg_unsupt_req_rpt_en[func]),
    .app_advisory_nf_err            (tmp_app_advisory_nf_err[func]),
    .app_hdr_log_overflow_det       (tmp_app_hdr_log_overflow_det[func]),
   
    .internal_err                   (internal_err_mod[func]),
    .corr_internal_err              (corr_internal_err_mod[func]),


    
    .radm_rcvd_cpl_poisoned         ({cdm_rcvd_cpl_poisoned_reg[func]}), // ms_con
    .radm_rcvd_wreq_poisoned        ({cdm_rcvd_wreq_poisoned_reg[func]}), // ms_con
    .radm_cpl_timeout_err           ({cdm_cpl_timeout_reg[func]}),
    .radm_mlf_tlp_err               ({cdm_mlf_tlp_err_reg[func]}), // ms_con
    .radm_ecrc_err                  ({cdm_ecrc_err_reg}),
    .radm_rcvd_req_ur               ({cdm_rcvd_req_ur_reg[func]}), // ms_con
    .radm_rcvd_req_ca               ({cdm_rcvd_req_ca_reg[func]}),
    .radm_unexp_cpl_err             ({cdm_unexp_cpl_err_reg[func]}), // ms_con
    .radm_rcvd_cpl_ur               ({radm_rcvd_cpl_ur_int[func]}), // ms_con
    .radm_rcvd_cpl_ca               ({radm_rcvd_cpl_ca_int[func]}), // ms_con
    .radm_hdr_log_valid             ({cdm_hdr_log_valid_reg[func]}), // ms_con
    .radm_correctable_err           (radm_correctable_err[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),
    .radm_nonfatal_err              (radm_nonfatal_err[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),
    .radm_fatal_err                 (radm_fatal_err[MSG_TLP_WD*(1+func)-1:MSG_TLP_WD*func]),
    .radm_acs_violation             ({cdm_acs_violation_reg[func]}), // ms_con
    .acs_viol_svrity_mask_wr_en     (acs_viol_svrity_mask_wr_en[func]),
    .tlp_prfx_blocked_err           (cdm_tlp_prfx_blocked_err_reg[func]),
    .cdm_err_detect                 (cdm_err_detect_reg),
    .radm_hdr_log                   (cdm_hdr_log_reg),
    .rtlh_overfl_err                (cdm_rcvr_overflow_reg[func]),
    .tlp_trans_egress_blk           (cdm_tlp_trans_egress_blk_reg[func]),
    .radm_atomic_egress_blk         (cdm_atomic_egress_blk_reg[func]),
    .rmlh_rcvd_err                  (cdm_rcvd_err_reg),
    .dl_prot_err                    (cdm_prot_err_reg),
    .rdlh_bad_tlp_err               (cdm_bad_tlp_err_reg),
    .rdlh_bad_dllp_err              (cdm_bad_dllp_err_reg),
    .xdlh_replay_num_rlover_err     (cdm_replay_num_rlover_err_reg),
    .xdlh_replay_timeout_err        (cdm_replay_timeout_err_reg),
    .rtlh_fc_prot_err               (cdm_fc_prot_err_reg),
    .psnd_tlp_egrss_blckd_err       (cdm_psnd_tlp_egrss_blckd_err_reg[func]),
    .cdm_err_advisory               (int_err_advisory_reg),
    .radm_hdr_log_flitmode          (radm_hdrlog_flit_mode_reg),
    .radm_hdr_log_hdrsize           (radm_hdrlog_hdr_size_reg),
    .radm_hdr_log_np_req            (radm_hdrlog_fc_E_NP_reg),

    
   
    
    .surprise_down_err              (surprise_down_err[func]),
    .lbc_xmt_cpl_ca                 (lbc_xmt_cpl_ca[func]),
    .xal_rcvd_cpl_ca                (xal_rcvd_cpl_ca[func]),
    .xal_rcvd_cpl_ur                (xal_rcvd_cpl_ur[func]),
    .xal_xmt_cpl_ca                 (xal_xmt_cpl_ca[func]),
    .xal_perr                       (xal_perr[func]),
    .xal_serr                       (xal_serr[func]),
    .xal_set_trgt_abort_primary     (xal_set_trgt_abort_primary[func]),
    .xal_set_mstr_abort_primary     (xal_set_mstr_abort_primary[func]),
    .xal_pci_addr_perr              (xal_pci_addr_perr[func]),
    .xadm_xmt_pci_errors            (xadm_xmt_pci_errors),
    
    
    .radm_msg_req_id                (radm_msg_req_id),

    // PF settings used by VFs, unused by PFs so tie to zero
    .pf_cfg_aer_uncorr_mask         (32'b0), // aer && vf
    .pf_cfg_aer_uncorr_svrity       (32'b0), // aer && vf
    .pf_cfg_aer_corr_mask           (32'b0), // aer && vf
    .pf_multi_hdr_rec_en            (1'b0), // aer && vf
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .cfg_pcie_surp_dn_rpt_cap       (cfg_pcie_surp_dn_rpt_cap[func]),
    .cfg_ecrc_chk_en                (cfg_ecrc_chk_en),
    .cdm_dpc_triggered              (cdm_dpc_triggered),
    .cdm_dpc_trig_status            (cdm_dpc_trig_status),
    .cdm_dpc_trig_en                (cdm_dpc_trig_en),
    .int_dpc_sw_trigger             (int_dpc_sw_trigger[func]),
    .dpc_triggered_detect           (dpc_triggered_detect[func]),
    .int_dpc_err_cor_en             (int_dpc_err_cor_en[func]),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),

    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .msggen_cdm_send_f_err          (msggen_cdm_send_f_err[func]),
    .msggen_cdm_send_nf_err         (msggen_cdm_send_nf_err[func]),
// ---------- Outputs --------
    .ecrc_gen_en                    (cfg_ecrc_gen_en[func]),
    .ecrc_chk_en                    (cfg_ecrc_chk_en[func]),
    .err_reg_data                   (err_reg_data[32*(1+func)-1:32*func]),
    .cfg_send_cor_err               (int_cfg_send_cor_err[func]),
    .cfg_send_nf_err                (int_cfg_send_nf_err[func]),
    .cfg_send_f_err                 (int_cfg_send_f_err[func]),
    .cfg_func_spec_err              (int_cfg_func_spec_err[3*(1+func)-1:3*func]),   // Function 0 Only
    .cfg_aer_rc_err_int             (int_cfg_aer_rc_err_int[func]),                 // Function 0 Only
    .cfg_aer_rc_err_msi             (int_cfg_aer_rc_err_msi[func]),                 // Function 0 Only
    .cfg_aer_int_msg_num            (int_cfg_aer_int_msg_num[5*(1+func)-1:5*func]),
    .cfg_rprt_err_cor               (cfg_rprt_err_cor[func]),                 // Function 0 Only
    .cfg_rprt_err_nf                (cfg_rprt_err_nf[func]),                  // Function 0 Only
    .cfg_rprt_err_f                 (cfg_rprt_err_f[func]),                   // Function 0 Only
    .cfg_f_err_det                  (cfg_f_err_det[func]),
    .cfg_nf_err_det                 (cfg_nf_err_det[func]),
    .cfg_cor_err_det                (cfg_cor_err_det[func]),
    .cfg_unsupt_req_det             (cfg_unsupt_req_det[func]),
    .master_data_perr_det           (master_data_perr_det[func]),
    .signaled_target_abort_det      (signaled_target_abort_det[func]),
    .rcvd_target_abort_det          (rcvd_target_abort_det[func]),
    .rcvd_master_abort_det          (rcvd_master_abort_det[func]),
    .signaled_sys_err_det           (signaled_sys_err_det[func]),
    .perr_det                       (perr_det[func]),
    .master_data_perr_det2          (master_data_perr_det2[func]),
    .signaled_target_abort_det2     (signaled_target_abort_det2[func]),
    .rcvd_target_abort_det2         (rcvd_target_abort_det2[func]),
    .rcvd_master_abort_det2         (rcvd_master_abort_det2[func]),
    .signaled_sys_err_det2          (signaled_sys_err_det2[func]),
    .perr_det2                      (perr_det2[func]),

    // PF settings exported to VFs
    .cfg_aer_uncorr_mask            (pf_cfg_aer_uncorr_mask_bus  [32*(1+func)-1:32*func]), // aer && pf
    .cfg_aer_uncorr_svrity          (pf_cfg_aer_uncorr_svrity_bus[32*(1+func)-1:32*func]), // aer && pf
    .cfg_aer_corr_mask              (pf_cfg_aer_corr_mask_bus    [32*(1+func)-1:32*func]), // aer && pf
    .multi_hdr_rec_en               (pf_multi_hdr_rec_en_bus [func]) // aer && pf
    ,
    .int_dpc_triggered              (int_dpc_triggered[func]),                      // Function 0 Only
    .int_dpc_trig_reason            (int_dpc_trig_reason[2*(1+func)-1:2*func]),     // Function 0 Only
    .int_dpc_trig_reason_extn       (int_dpc_trig_reason_extn[2*(1+func)-1:2*func]),     // Function 0 Only
    .cdm_aer_dpc_triggered          (int_aer_dpc_triggered[func]),                      // Function 0 Only
    .cdm_core_in_dpc                (int_core_in_dpc[func]),                        // Function 0 Only
    .dpc_err_src_id                 (dpc_err_src_id[16*(1+func)-1:16*func])
    ,
    .cfg_uncor_internal_err_sts         (cfg_uncor_internal_err_sts_int[func]        ),
    .cfg_rcvr_overflow_err_sts          (cfg_rcvr_overflow_err_sts_int[func]         ),
    .cfg_fc_protocol_err_sts            (cfg_fc_protocol_err_sts_int[func]           ),
    .cfg_mlf_tlp_err_sts                (cfg_mlf_tlp_err_sts_int[func]               ),
    .cfg_surprise_down_er_sts           (cfg_surprise_down_er_sts_int[func]          ),
    .cfg_dl_protocol_err_sts            (cfg_dl_protocol_err_sts_int[func]           ),
    .cfg_ecrc_err_sts                   (cfg_ecrc_err_sts_int[func]                  ),
    .cfg_corrected_internal_err_sts     (cfg_corrected_internal_err_sts_int[func]    ),
    .cfg_replay_number_rollover_err_sts (cfg_replay_number_rollover_err_sts_int[func]),
    .cfg_replay_timer_timeout_err_sts   (cfg_replay_timer_timeout_err_sts_int[func]  ),
    .cfg_bad_dllp_err_sts               (cfg_bad_dllp_err_sts_int[func]              ),
    .cfg_bad_tlp_err_sts                (cfg_bad_tlp_err_sts_int[func]               ),
    .cfg_rcvr_err_sts                   (cfg_rcvr_err_sts_int[func]                  ),
    .advisory_nf_sts                    (cfg_advisory_nf_sts[func]                   ),
    .hdr_log_overflow_sts               (cfg_hdr_log_overflow_sts[func]              )

); // cdm_error_reg







// -----------------------------------------------------------------------------
// Device 3 Extended Capability registers
// -----------------------------------------------------------------------------

cdm_dev3_reg

#(.INST(INST), .FUNC_NUM(func))
u_cdm_dev3_reg (
// -------------- Inputs ---------------
    .core_clk                       (core_clk),
    .sticky_rst_n                   (sticky_rst_n),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .device_type                    (device_type),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .dev3_write_pulse               (ecfg_write_pulse[func]),
    .dev3_reg_id                    (dev3_reg_id[NDEV3_REGS*(1+func)-1:NDEV3_REGS*func]),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .int_link_width                 (cfg_int_link_width[5:0]),
    .flit_mode_enable               (flit_mode_enable),
    .cfg_pcie_cap_flit_mode_sup     (cfg_pcie_cap_flit_mode_sup),
    .segment_captured               (cfg_segment_id_int[8]),
    .smlh_l0p_capable               (smlh_l0p_capable),
// -------------- Outputs --------------
    .cfg_dmwr_req_en                (cfg_dmwr_req_en[func]),
    .cfg_target_link_width           (int_cfg_target_link_width[3*(1+func)-1:3*func]),
    .cfg_l0p_en                      (int_cfg_l0p_en[func]),
    .cfg_receiver_l0p_supported      (int_cfg_receiver_l0p_supported[func]),
    .remote_l0p_supported            (int_remote_l0p_supported[func]),
    .dev3_reg_data                   (dev3_reg_data[32*(1+func)-1:32*func])
);

end // for (func=0; func<NF; func = func+1) begin : gen_cdm_reg
endgenerate



// -----------------------------------------------------------------------------
// Base Configuration Register Space for RCRB
// -----------------------------------------------------------------------------

genvar func_1;
generate
for (func_1=0; func_1<1; func_1 = func_1+1) begin : gen_cdm_rcrb_reg


cdm_cfg_reg

#(.INST(INST), .FUNC_NUM(0), .RCRB(1))
u_cdm_rcrb_cfg_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .device_type                    (device_type),
    // Local Bus access
    .cfg_reg_sel                    (cfg_rcrb_reg_sel),
    .cfg_cap_reg_sel                (cfg_rcrb_cap_reg_sel),
    .ecfg_reg_sel                   (ecfg_rcrb_reg_sel),
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),


    .int_msg_pending                (sys_int[func_1]),

    .rdlh_link_up                   (rdlh_link_up),
    .smlh_link_up                   (smlh_link_up),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .smlh_clr_enter_compliance      (smlh_clr_enter_compliance),
    .smlh_tx_margin_rst             (smlh_tx_margin_rst),
    .mac_phy_txdeemph               (mac_phy_txdeemph),
    .smlh_ls2_eq_req                (smlh_ls2_eq_req),
    .smlh_ls2_eq_success            (smlh_ls2_eq_success[3:1]),
    .smlh_ls2_eq_cmpl               (smlh_ls2_eq_cmpl),
    .smlh_ls2_eq_enter              (smlh_ls2_eq_enter_i),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_two_retimers_pre_detected (smlh_two_retimers_pre_detected),
    .smlh_crosslink_resolution      (smlh_crosslink_resolution),
    .smlh_retimer_pre_detected      (smlh_retimer_pre_detected),
    .aux_pwr_det                    (sys_aux_pwr_det),
    .radm_cpl_pending               (radm_cpl_pending[func_1]),

    // Errors
    .cfg_f_err_det                  (1'b0),
    .cfg_nf_err_det                 (1'b0),
    .cfg_cor_err_det                (1'b0),
    .cfg_unsupt_req_det             (1'b0),
    .cfg_rprt_err_cor               (1'b0),                 // Function 0 Only
    .cfg_rprt_err_nf                (1'b0),                 // Function 0 Only
    .cfg_rprt_err_f                 (1'b0),                   // Function 0 Only
    .master_data_perr_det           (1'b0),
    .signaled_target_abort_det      (1'b0),
    .rcvd_target_abort_det          (1'b0),
    .rcvd_master_abort_det          (1'b0),
    .signaled_sys_err_det           (1'b0),
    .perr_det                       (1'b0),
    .master_data_perr_det2          (1'b0),
    .signaled_target_abort_det2     (1'b0),
    .rcvd_target_abort_det2         (1'b0),
    .rcvd_master_abort_det2         (1'b0),
    .signaled_sys_err_det2          (1'b0),
    .perr_det2                      (1'b0),

    // MSG received
    .radm_correctable_err           (|radm_correctable_err[MSG_TLP_WD*(1+func_1)-1:MSG_TLP_WD*func_1]),
    .radm_nonfatal_err              (|radm_nonfatal_err[MSG_TLP_WD*(1+func_1)-1:MSG_TLP_WD*func_1]),
    .radm_fatal_err                 (|radm_fatal_err[MSG_TLP_WD*(1+func_1)-1:MSG_TLP_WD*func_1]),

    .sys_pre_det_state              (sys_pre_det_state[func_1]),
    .sys_mrl_sensor_state           (sys_mrl_sensor_state[func_1]),
    .sys_atten_button_pressed       (sys_atten_button_pressed[func_1]),
    .sys_pwr_fault_det              (sys_pwr_fault_det[func_1]),
    .sys_mrl_sensor_chged           (sys_mrl_sensor_chged[func_1]),
    .sys_pre_det_chged              (sys_pre_det_chged[func_1]),
    .sys_cmd_cpled_int              (sys_cmd_cpled_int[func_1]),
    .sys_eml_interlock_engaged      (sys_eml_interlock_engaged[func_1]),
    .radm_set_slot_pwr_limit        (int_radm_set_slot_pwr_limit[func_1]),
    .radm_slot_pwr_payload          (radm_slot_pwr_payload),
    .pm_status                      (pm_status[func_1]),
    .pm_pme_en                      (pm_pme_en[func_1]),
    .aux_pm_en                      (aux_pm_en[func_1]),
    .radm_pm_pme                    (radm_pm_pme[MSG_TLP_WD*(1+func_1)-1:MSG_TLP_WD*func_1]),
    .radm_msg_req_id                (radm_msg_req_id),

    .smlh_ltssm_state               (smlh_ltssm_state),
    .radm_drs_msg                   (radm_drs_msg),      //only device received stored in registers, same for all


    .flt_cdm_addr                   (flt_cdm_addr_int),



    .app_ltr_msg_req                (app_ltr_msg_req),
    .msg_ltr_det                    (msg_ltr_det),
    .msgg2cdm_ltr_clr_msg_grant     (msgg2cdm_ltr_clr_msg_grant),
    .cdmpl2cfg_ltr_rq               (cdmpl2cfg_ltr_rq),
    .ltr_m_en_fn0                   (ltr_m_en_fn0),
    .cfg_disable_ltr_clr_msg        (cfg_disable_ltr_clr_msg),
    .rbar_ctrl_update               (rbar_ctrl_update[func_1]),
    .cfg_rbar_bar_resizable         (int_cfg_rbar_bar_resizable[6*(1+func_1)-1:6*func_1]),
    .cfg_rbar_bar0_mask             (int_cfg_rbar_bar0_mask[64*(1+func_1)-1:64*func_1]),
    .cfg_rbar_bar1_mask             (int_cfg_rbar_bar1_mask[32*(1+func_1)-1:32*func_1]),
    .cfg_rbar_bar2_mask             (int_cfg_rbar_bar2_mask[64*(1+func_1)-1:64*func_1]),
    .cfg_rbar_bar3_mask             (int_cfg_rbar_bar3_mask[32*(1+func_1)-1:32*func_1]),
    .cfg_rbar_bar4_mask             (int_cfg_rbar_bar4_mask[64*(1+func_1)-1:64*func_1]),
    .cfg_rbar_bar5_mask             (int_cfg_rbar_bar5_mask[32*(1+func_1)-1:32*func_1]),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),

    .exp_rom_validation_status_strobe (exp_rom_validation_status_strobe[func_1] ),
    .exp_rom_validation_status        (exp_rom_validation_status[3*(1+func_1)-1:3*func_1]),
    .exp_rom_validation_details_strobe(exp_rom_validation_details_strobe[func_1]),
    .exp_rom_validation_details       (exp_rom_validation_details[4*(1+func_1)-1:4*func_1]),

    .radm_snoop_upd                 (int_radm_snoop_upd),
    .radm_snoop_bus_num             (int_radm_snoop_bus_num),
    .radm_snoop_dev_num             (int_radm_snoop_dev_num),
    .radm_pm_to_ack                 (radm_pm_to_ack),
    .pm_xmt_turnoff                 (pm_xmt_turnoff),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),     // input [1:0]
    .app_clk_pm_en                  (app_clk_pm_en),
    .cfg_config_limit               (cfg_config_limit),
    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .rcrb_base_addr                 (rcrb_base_addr),
    .rcrb_base_addr_valid           (rcrb_base_addr_valid),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .current_data_rate                       (current_data_rate),
    .cxl_mode_enable                         (cxl_mode_enable),
    .cxl_2_0_mbar0_offset                    (64'h0),
    .cxl2p0_enabled                          (cxl_mbar0_enable),
    .cfg_cxl_2_0_ext_unmask_sbr              (cfg_cxl_2_0_ext_unmask_sbr),                // Unmask SBR
    .cfg_cxl_2_0_ext_unmask_ld               (cfg_cxl_2_0_ext_unmask_ld),                 // Unmask Link Disable
    .cfg_cxl_2_0_ext_alt_mse                 (cfg_cxl_2_0_ext_alt_mse),                   // Alternate Memory Space Enable
    .cfg_cxl_2_0_ext_alt_bme                 (cfg_cxl_2_0_ext_alt_bme),                   // Alternate Bus Master Enable
    .cfg_cxl_2_0_ext_alt_mem_base            (cfg_cxl_2_0_ext_alt_mem_base),              // Alternate Memory Base
    .cfg_cxl_2_0_ext_alt_mem_limit           (cfg_cxl_2_0_ext_alt_mem_limit),             // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base       (cfg_cxl_2_0_ext_alt_pref_mem_base),         // Alternate Prefetchable Memory Base
    .cfg_cxl_2_0_ext_alt_pref_mem_limit      (cfg_cxl_2_0_ext_alt_pref_mem_limit),        // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base_high  (cfg_cxl_2_0_ext_alt_pref_mem_base_high),    // Alternate Prefetchable Memory Base High
    .cfg_cxl_2_0_ext_alt_pref_mem_limit_high (cfg_cxl_2_0_ext_alt_pref_mem_limit_high),   // Alternate Prefetchable Memory Base High

    .flit_mode_enable                        (flit_mode_enable),
    .app_segment_id                          (app_segment_id),
    .radm_np_segment_id                      (radm_np_segment_id_int),
    .cfg_segment_id_out                      (),

// ---------- Outputs --------
    .cfg_upd_pme_cap                (cfg_rcrb_upd_pme_cap),
    .cfg_mem_match                  (cfg_rcrb_mem_match),
    .cfg_prefmem_match              (cfg_rcrb_prefmem_match),
    .cfg_io_match                   (cfg_rcrb_io_match),
    .cfg_config_above_match         (cfg_rcrb_config_above_match),
    .cfg_bar_match                  (cfg_rcrb_bar_match),
    .cfg_bar_is_io                  (cfg_rcrb_bar_is_io),
    .cfg_rom_match                  (cfg_rcrb_rom_match),
    .cfg_rcrb_match                 (),
    .cfg_rcrb_mbar0_match           (cfg_rcrb_mbar0_match),
    .cfg_rcrb_mbar0_match_int       (cfg_rcrb_mbar0_match_int),
    .rcrb_mbar0_base_addr           (rcrb_mbar0_base_addr),
    .rcrb_address_reg               (),
    .cfg_cxl_2_0_mbar0_match        (),
    .cxl_2_0_mbar0_access_int       (),
    .cfg_cxl_alt_mem_match          (),
    .cfg_cxl_alt_prefmem_match      (),
    .cfg_br_ctrl_serren             (cfg_rcrb_br_ctrl_serren),
    .cfg_br_ctrl_perren             (cfg_rcrb_br_ctrl_perren),
    .cfg_bus_master_en              (cfg_rcrb_bus_master_en),
    .cfg_reg_perren                 (cfg_rcrb_reg_perren),
    .cfg_reg_serren                 (cfg_rcrb_reg_serren),
    .cfg_sys_err_rc                 (int_cfg_rcrb_sys_err_rc),  // Function 0 Only
    .cfg_crs_sw_vis_en              (int_cfg_rcrb_crs_sw_vis_en),  // Function 0 Only
    .cfg_pme_int                    (int_cfg_rcrb_pme_int),     // Function 0 Only
    .cfg_pme_msi                    (int_cfg_rcrb_pme_msi),     // Function 0 Only
    .cfg_2nd_reset_mod              (int_cfg_rcrb_2nd_reset),
    .cfg_slot_pwr_limit_wr          (cfg_rcrb_slot_pwr_limit_wr),
    .cfg_pcie_slot_pwr_limit        (cfg_rcrb_pcie_slot_pwr_limit),
    .cfg_multi_msi_en               (cfg_rcrb_multi_msi_en),
    .cfg_msi_ext_data_en            (cfg_rcrb_msi_ext_data_en),
    .cfg_msi_en                     (cfg_rcrb_msi_en),
    .cfg_msi_addr                   (cfg_rcrb_msi_addr),
    .cfg_msi_data                   (cfg_rcrb_msi_data),
    .cfg_msi_64                     (cfg_rcrb_msi_64),
    .cfg_msix_en                    (cfg_rcrb_msix_en),
    .cfg_msix_func_mask             (cfg_rcrb_msix_func_mask),
    .cfg_msix_table_size            (cfg_rcrb_msix_table_size),
    .cfg_msix_table_size2           (cfg_rcrb_msix_table_size2),
    .cfg_msix_table_bir             (cfg_rcrb_msix_table_bir),
    .cfg_msix_table_bir2            (cfg_rcrb_msix_table_bir2),
    .cfg_msix_table_offset          (cfg_rcrb_msix_table_offset),
    .cfg_msix_table_offset2         (cfg_rcrb_msix_table_offset2),
    .cfg_msix_pba_bir               (cfg_rcrb_msix_pba_bir),
    .cfg_msix_pba_bir2              (cfg_rcrb_msix_pba_bir2),
    .cfg_msix_pba_offset            (cfg_rcrb_msix_pba_offset),
    .cfg_msix_pba_offset2           (cfg_rcrb_msix_pba_offset2),
    .cfg_vpd_int                    (cfg_rcrb_vpd_int),
    .cfg_max_payload_size_out       (cfg_rcrb_max_payload_size),
    .cfg_relax_ord_en               (cfg_rcrb_relax_ord_en),
// In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
    .cfg_max_payload_size_out_rx    (cfg_rcrb_max_payload_size_out_rx),
    .cfg_ext_tag_en                 (cfg_rcrb_ext_tag_en),
    .cfg_phantom_fun_en             (cfg_rcrb_phantom_fun_en),
    .cfg_no_snoop_en                (cfg_rcrb_no_snoop_en),
    .cfg_max_rd_req_size            (cfg_rcrb_max_rd_req_size),
    .cfg_bridge_crs_en              (cfg_rcrb_bridge_crs_en),
    .cfg_aslk_pmctrl                (int_cfg_rcrb_aslk_pmctrl),
    .cfg_upd_aslk_pmctrl_mux        (int_cfg_rcrb_upd_aslk_pmctrl),
    .cfg_clk_pm_en_mux              (int_cfg_rcrb_clk_pm_en),
    .cfg_rcb_mux                    (cfg_rcrb_rcb),
    .cfg_link_dis_mux               (int_rcrb_link_dis),
    .cfg_link_retrain_mux           (int_rcrb_link_retrain),
    .cfg_comm_clk_config_mux        (int_cfg_rcrb_comm_clk_config),
    .cfg_hw_autowidth_dis_mux       (int_cfg_rcrb_hw_autowidth_dis),
    .cfg_link_rate                  (int_cfg_rcrb_link_rate),
    .cfg_retimers_pre_detected      (int_cfg_rcrb_retimers_pre_detected),
    .cfg_pwr_ind                    (cfg_rcrb_pwr_ind),
    .cfg_atten_ind                  (cfg_rcrb_atten_ind),
    .cfg_pwr_ctrler_ctrl            (cfg_rcrb_pwr_ctrler_ctrl),
    .cfg_hp_int_en                  (cfg_rcrb_hp_int_en),
    .cfg_atten_button_pressed       (cfg_rcrb_atten_button_pressed),
    .cfg_eml_control                (cfg_rcrb_eml_control),
    .cfg_pwr_fault_det              (cfg_rcrb_pwr_fault_det),
    .cfg_mrl_sensor_chged           (cfg_rcrb_mrl_sensor_chged),
    .cfg_pre_det_chged              (cfg_rcrb_pre_det_chged),
    .cfg_cmd_cpled_int              (cfg_rcrb_cmd_cpled_int),
    .cfg_dll_state_chged            (cfg_rcrb_dll_state_chged),
    .cfg_int_disable                (cfg_rcrb_int_disable),
    .cfg_cor_err_rpt_en             (cfg_rcrb_cor_err_rpt_en),
    .cfg_nf_err_rpt_en              (cfg_rcrb_nf_err_rpt_en),
    .cfg_f_err_rpt_en               (cfg_rcrb_f_err_rpt_en),
    .cfg_unsupt_req_rpt_en          (cfg_rcrb_unsupt_req_rpt_en),
    .cfg_pbus_num                   (int_cfg_rcrb_pbus_num),
    .cfg_2ndbus_num                 (cfg_rcrb_2ndbus_num),
    .cfg_subbus_num                 (cfg_rcrb_subbus_num),
    .cfg_pbus_dev_num               (int_cfg_rcrb_pbus_dev_num),
    .cfg_bar0_start                 (cfg_rcrb_bar0_start),
    .cfg_bar0_limit                 (cfg_rcrb_bar0_limit),
    .cfg_bar1_start                 ( ),
    .cfg_bar1_limit                 ( ),
    .cfg_bar2_start                 ( ),
    .cfg_bar2_limit                 ( ),
    .cfg_bar3_start                 ( ),
    .cfg_bar3_limit                 ( ),
    .cfg_bar4_start                 ( ),
    .cfg_bar4_limit                 ( ),
    .cfg_bar5_start                 ( ),
    .cfg_bar5_limit                 ( ),
    .cfg_bar0_mask                  ( ),
    .cfg_bar1_mask                  ( ),
    .cfg_bar2_mask                  ( ),
    .cfg_bar3_mask                  ( ),
    .cfg_bar4_mask                  ( ),
    .cfg_bar5_mask                  ( ),
    .cfg_rom_mask                   (cfg_rcrb_rom_mask),
    .cfg_mem_base                   (cfg_rcrb_mem_base),
    .cfg_mem_limit                  (cfg_rcrb_mem_limit),
    .cfg_pref_mem_base              (cfg_rcrb_pref_mem_base),
    .cfg_pref_mem_limit             (cfg_rcrb_pref_mem_limit),
    .cfg_exp_rom_start              (cfg_rcrb_exp_rom_start),
    .cfg_exp_rom_limit              (cfg_rcrb_exp_rom_limit),
    .cfg_io_limit_upper16           (cfg_rcrb_io_limit_upper16),
    .cfg_io_base_upper16            (cfg_rcrb_io_base_upper16),
    .cfg_io_base                    (cfg_rcrb_io_base),
    .cfg_io_limit                   (cfg_rcrb_io_limit),
    .cfg_hdr_type                   (int_cfg_rcrb_hdr_type),
    .cfg_ext_synch                  (int_rcrb_ext_synch),
    .cfg_io_space_en                (cfg_rcrb_io_space_en),
    .cfg_mem_space_en               (cfg_rcrb_mem_space_en),

    .cfg_cap_reg_ack                (cfg_rcrb_cap_reg_ack),
    .cfg_cap_reg_data               (cfg_rcrb_cap_reg_data),
    .cfg_reg_data                   (cfg_rcrb_reg_data),
    .cfg_reg_ack                    (cfg_rcrb_reg_ack),
    .cfg_upd_pmcsr                  (cfg_rcrb_upd_pmcsr),
    .cfg_upd_aux_pm_en              (cfg_rcrb_upd_aux_pm_en),
    .cfg_upd_req_id                 (cfg_rcrb_upd_req_id),
    .cfg_aux_pm_en                  (cfg_rcrb_aux_pm_en),
    .cfg_pmstatus_clr               (cfg_rcrb_pmstatus_clr),
    .cfg_pmstate                    (cfg_rcrb_pmstate),
    .cfg_pme_en                     (cfg_rcrb_pme_en),
    .cfg_pme_cap                    (cfg_rcrb_pme_cap),
    .cfg_pm_no_soft_rst             (cfg_rcrb_pm_no_soft_rst),
    .cfg_isa_enable                 (cfg_rcrb_isa_enable),
    .cfg_vga_enable                 (cfg_rcrb_vga_enable),
    .cfg_vga16_decode               (cfg_rcrb_vga16_decode),
    .cfg_int_pin                    (cfg_rcrb_int_pin),
    .cfg_link_auto_bw_int_mux       (int_cfg_rcrb_link_auto_bw_int),                       // Function 0 Only
    .cfg_link_auto_bw_msi_mux       (int_cfg_rcrb_link_auto_bw_msi),                       // Function 0 Only
    .cfg_bw_mgt_int_mux             (int_cfg_rcrb_bw_mgt_int),                             // Function 0 Only
    .cfg_bw_mgt_msi_mux             (int_cfg_rcrb_bw_mgt_msi),                             // Function 0 Only
    .cfg_pcie_max_link_speed        (pf_cfg_rcrb_pcie_max_link_speed_bus),
    .cfg_target_link_speed          (int_cfg_rcrb_target_link_speed),       // Function 0 Only
    .cfg_enter_compliance_mux       (int_cfg_rcrb_enter_compliance),                       // Function 0 Only
    .cfg_hw_auto_sp_dis_mux         (int_cfg_rcrb_hw_auto_sp_dis),                         // Function 0 Only
    .cfg_sel_de_emphasis_mux        (int_cfg_rcrb_sel_de_emphasis),                        // Function 0 Only
    .cfg_transmit_margin_mux        (int_cfg_rcrb_transmit_margin),         // Function 0 Only
    .cfg_enter_mod_compliance_mux   (int_cfg_rcrb_enter_mod_compliance),                   // Function 0 Only
    .cfg_compliance_sos_mux         (int_cfg_rcrb_compliance_sos),                         // Function 0 Only
    .cfg_compliance_de_emphasis_mux (int_cfg_rcrb_compliance_de_emphasis),  // Function 0 Only
//    .target_mem_map                 (target_mem_map),
//    .target_rom_map                 (target_rom_map),
    .cfg_atomic_req_en              (cfg_rcrb_atomic_req_en),
    .cfg_atomic_egress_block        (cfg_rcrb_atomic_egress_block),
    .cfg_obff_en                    (int_cfg_rcrb_obff_en),
    .cfg_ltr_m_en                   (int_cfg_rcrb_ltr_m_en),
    .cfg_ltr_clr_msg_req            (int_rcrb_cdm2msgg_ltr_clr_msg_req),
    .cfg_pcie_aspm_cap_mux          (pf_cfg_rcrb_pcie_aspm_cap_bus),
     .cfg_pcie_max_link_width       (pf_cfg_rcrb_pcie_max_link_width_bus),    
    .cfg_ido_req_en                 (pf_cfg_rcrb_ido_req_en),          //cdm_cfg_reg
    .cfg_ido_cpl_en                 (pf_cfg_rcrb_ido_cpl_en),


    .cfg_drs_msi                    (cfg_rcrb_drs_msi),
    .cfg_downstream_comp_pres_mux   (cfg_rcrb_downstream_comp_pres),       //cfg
    .cfg_up_drs_to_frs              (cfg_rcrb_up_drs_to_frs),
    .cfg_drs_frs_sig_en             (cfg_rcrb_drs_frs_sig_en),

    .cfg_pcie_cap_int_msg_num       (cfg_rcrb_pcie_cap_int_msg_num),
    .cfg_ari_fwd_en                 (cfg_rcrb_ari_fwd_en),
    .cfg_cpl_timeout_range_out          (cfg_rcrb_cpl_timeout_range),
    .cfg_cpl_timeout_disable_out        (cfg_rcrb_cpl_timeout_disable)
    ,
    .cfg_pcie_crosslink_supported   (int_cfg_rcrb_pcie_crosslink_supported),   // Function 0 Only
    .cfg_ls2_eq_req_mux             (int_cfg_rcrb_ls2_eq_req)   // Function 0 Only
    ,
    .cfg_end2end_tlp_pfx_blck        (cfg_rcrb_end2end_tlp_pfx_blck),
    .cfg_max_end2end_tlp_prfxs       (cfg_rcrb_max_end2end_tlp_prfxs)
    ,
    . cfg_10b_tag_req_en             (cfg_rcrb_10b_tag_req_en)

    ,
    .surprise_down_err               (rcrb_surprise_down_err)
    ,
    .cfg_pcie_surp_dn_rpt_cap_mux    (cfg_rcrb_pcie_surp_dn_rpt_cap)
    ,
    .cfg_pcie_slot_clk_config_mux    (cfg_rcrb_pcie_slot_clk_config),
    .cfg_auto_slot_pwr_lmt_dis       (cfg_rcrb_auto_slot_pwr_lmt_dis),
    .cfg_hp_slot_ctrl_access         (cfg_rcrb_hp_slot_ctrl_access),
    .cfg_dll_state_chged_en          (cfg_rcrb_dll_state_chged_en),
    .cfg_cmd_cpled_int_en_r          (cfg_rcrb_cmd_cpled_int_en),
    .cfg_pre_det_chged_en            (cfg_rcrb_pre_det_chged_en),
    .cfg_mrl_sensor_chged_en_r       (cfg_rcrb_mrl_sensor_chged_en),
    .cfg_pwr_fault_det_en_r          (cfg_rcrb_pwr_fault_det_en),
    .cfg_atten_button_pressed_en_r   (cfg_rcrb_atten_button_pressed_en),
    
    .cfg_neg_link_width             ()

); // cdm_cfg_reg

// -----------------------------------------------------------------------------
// RCRB Extended PCIE config registers
// -----------------------------------------------------------------------------

cdm_ecfg_reg

#(.INST(INST), .FUNC_NUM(0), .NPTMVSEC(NPTMVSEC), .RCRB(1))
u_cdm_rcrb_ecfg_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .device_type                    (device_type),
    .lbc_cdm_addr                   (cdm_pf_ecfg_addr[15:0]),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    .ecfg_reg_sel                   (ecfg_rcrb_reg_sel),
    .err_reg_data                   (err_reg_data[31:0]),
    .ras_reg_ack                    (ras_reg_ack),
    .ras_reg_data                   (ras_reg_data),
    .cfg_ras_reg_pf0_only           (cfg_ras_reg_pf0_only),
    .spcie_reg_data                 (spcie_reg_data),
    .pl16g_reg_data                 (pl16g_reg_data),
    .margin_reg_data                (margin_reg_data),
    .pl32g_reg_data                 (pl32g_reg_data),
    .pl64g_reg_data                 (pl64g_reg_data),
    .l1sub_reg_data                 (l1sub_reg_data),
    .dev3_reg_data                  (dev3_reg_data[32*(1+func_1)-1:32*func_1]),
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .cfg_pwr_budget_data_reg        (cfg_pwr_budget_data_reg),
    .cfg_pwr_budget_func_num        (cfg_pwr_budget_func_num),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .rasdes_reg_data                (rasdes_reg_data),
    .rasdes_reg_ack                 (rasdes_reg_ack),
    .cfg_rasdes_reg_pf0_only        (cfg_rasdes_reg_pf0_only),

    .cfg_msi_en                     (cfg_msi_en_int[func_1]),
    .cfg_msix_en                    (cfg_msix_en[func_1]),
    .radm_drs_msg                   (radm_drs_msg),
    .radm_msg_req_id                (radm_msg_req_id),
    .cfg_downstream_comp_pres       (cfg_downstream_comp_pres[3*(1+func_1)-1:3*func_1]),     //ecfg

    .cfg_drs_frs_sig_en             (cfg_drs_frs_sig_en[func_1]),
    .radm_frs_msg                   (radm_frs_msg),
    .radm_frs_msg_reason            (radm_frs_msg_reason),
    .cfg_pbus_num                   (int_cfg_pbus_num[8*(1+func_1)-1:8*func_1]),
    .cfg_pbus_dev_num               (int_cfg_pbus_dev_num[5*(1+func_1)-1:5*func_1]),
    .pmstate_d3hot_to_d0            (pmstate_d3hot_to_d0[func_1]),

    .ptm_vsec_reg_data              (ptm_vsec_reg_data[31:0]),
    .ptm_reg_data                   (ptm_reg_data[31:0]),

    .vsecdma_reg_data              (vsecdma_reg_data[31:0]),


    .upstream_port                  (upstream_port),
    .rdlh_link_up                   (rdlh_link_up),

    .prs_res_failure                (prs_res_failure[func_1]),
    .prs_uprgi                      (prs_uprgi[func_1]),
    .prs_stopped                    (prs_stopped[func_1]),
    .rdlh_rcvd_dl_feature           (rdlh_rcvd_dl_feature),
    .rcvd_dl_feature_content        (rcvd_dl_feature_content),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),     // input [1:0]
    .int_dpc_triggered              (1'd0),                      // Function 0 Only
    .int_dpc_trig_reason            (2'd0),     // Function 0 Only
    .int_dpc_trig_reason_extn       (2'd0),     // Function 0 Only
    .dpc_err_src_id                 (16'd0),
    .cfg_int_disable                (1'd0),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .cxl2p0_enabled                 (cxl_mbar0_enable),
    .cxl_mld_enabled                (ltssm_cxl_enable.cxl_mld_enabled),
    .cxl_reg_data                   (cxl_reg_data[0]),
    .cxl_rcrb_reg_data              (cxl_port_reg_data),
    .cxl_mbar0_reg_sel              (rcrb_mbar0_reg_sel_upstream),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .cxl_2_0_ext_reg_data           (cxl_2_0_ext_reg_data),
    .cxl_reg_locator_reg_data       (cxl_reg_locator_reg_data[0]),
    .cxl_gpf_port_reg_data          (cxl_gpf_port_reg_data),
    .cxl_gpf_device_reg_data        (cxl_gpf_device_reg_data[0]),
    .cfg_pcie_cap_flit_mode_sup     ( cfg_pcie_cap_flit_mode_sup ),
    .cfg_flit_log                   ( cfg_flit_log               ),
    .cfg_link_wd_err_cnt_start      ( cfg_link_wd_err_cnt_start  ),
    .cfg_flit_err_cnt               ( cfg_flit_err_cnt           ),
    .cfg_flit_cnt                   ( cfg_flit_cnt               ),
    .cfg_invalid_flit_cnt           ( cfg_invalid_flit_cnt       ),
    .cfg_interr_trg_evnt_cnt        ( cfg_interr_trg_evnt_cnt    ),
    .cfg_interr_trg_evnt_cnt_clr    ( cfg_interr_trg_evnt_cnt_clr),
    .cfg_lane_0_corr_cnt            ( cfg_lane_0_corr_cnt        ),
    .cfg_lane_1_corr_cnt            ( cfg_lane_1_corr_cnt        ),
    .cfg_lane_2_corr_cnt            ( cfg_lane_2_corr_cnt        ),
    .cfg_lane_3_corr_cnt            ( cfg_lane_3_corr_cnt        ),
    .cfg_lane_4_corr_cnt            ( cfg_lane_4_corr_cnt        ),
    .cfg_lane_5_corr_cnt            ( cfg_lane_5_corr_cnt        ),
    .cfg_lane_6_corr_cnt            ( cfg_lane_6_corr_cnt        ),
    .cfg_lane_7_corr_cnt            ( cfg_lane_7_corr_cnt        ),
    .cfg_lane_8_corr_cnt            ( cfg_lane_8_corr_cnt        ),
    .cfg_lane_9_corr_cnt            ( cfg_lane_9_corr_cnt        ),
    .cfg_lane_10_corr_cnt           ( cfg_lane_10_corr_cnt       ),
    .cfg_lane_11_corr_cnt           ( cfg_lane_11_corr_cnt       ),
    .cfg_lane_12_corr_cnt           ( cfg_lane_12_corr_cnt       ),
    .cfg_lane_13_corr_cnt           ( cfg_lane_13_corr_cnt       ),
    .cfg_lane_14_corr_cnt           ( cfg_lane_14_corr_cnt       ),
    .cfg_lane_15_corr_cnt           ( cfg_lane_15_corr_cnt       ),
                                 .cfg_flit_latency_status                  (xplh_cdm_flit_latency_tracking.flit_latency_status) 
                                ,.cfg_flit_latency_value                   (xplh_cdm_flit_latency_tracking.flit_latency_value) 
                                ,.cfg_ltssm_st_trans1_status               (pm_cdm_state_trans_tracking.state_trans1_status) 
                                ,.cfg_ltssm_st_trans2_status               (pm_cdm_state_trans_tracking.state_trans2_status) 
                                ,.cfg_ltssm_st_trans3_status               (pm_cdm_state_trans_tracking.state_trans3_status) 
                                ,.cfg_ltssm_st_trans4_status               (pm_cdm_state_trans_tracking.state_trans4_status) 
                                ,.cfg_ltssm_st_trans5_status               (pm_cdm_state_trans_tracking.state_trans5_status) 
                                ,.cfg_ltssm_st_trans_latency               (pm_cdm_state_trans_tracking.state_trans_latency)                                                                                        
                                ,.cfg_msi_en_pf0                           (            cfg_msi_en_pf0                       )
                                ,.cfg_msix_en_pf0                          (            cfg_msix_en_pf0                      ),
                                 .cfg_flit_err_tx_inj_sts                  (     plh_cdm_flit_err_inj_status.cfg_tx_inj_sts           )
                                ,.cfg_flit_err_rx_inj_sts                  (     plh_cdm_flit_err_inj_status.cfg_rx_inj_sts           )
                                ,.cfg_ordr_set_tx_inj_sts_ts0              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_ts0            )
                                ,.cfg_ordr_set_tx_inj_sts_ts1              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_ts1            )
                                ,.cfg_ordr_set_tx_inj_sts_ts2              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_ts2            )
                                ,.cfg_ordr_set_tx_inj_sts_skp              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_skp            )
                                ,.cfg_ordr_set_tx_inj_sts_eieos            (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_eieos          )
                                ,.cfg_ordr_set_tx_inj_sts_eios             (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_eios           )
                                ,.cfg_ordr_set_tx_inj_sts_sds              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_sds            )
                                ,.cfg_ordr_set_tx_inj_sts_poll             (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_poll           )
                                ,.cfg_ordr_set_tx_inj_sts_cfg              (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_cfg            )
                                ,.cfg_ordr_set_tx_inj_sts_l0               (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_l0             )
                                ,.cfg_ordr_set_tx_inj_sts_non_eq_recov     (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_non_eq_recov   )
                                ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0  (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_1_0)
                                ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_2    (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_2  )
                                ,.cfg_ordr_set_tx_inj_sts_recov_eq_ph_3    (     os_err_tx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_3  )
                                ,.cfg_ordr_set_rx_inj_sts_ts0              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_ts0            )
                                ,.cfg_ordr_set_rx_inj_sts_ts1              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_ts1            )
                                ,.cfg_ordr_set_rx_inj_sts_ts2              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_ts2            )
                                ,.cfg_ordr_set_rx_inj_sts_skp              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_skp            )
                                ,.cfg_ordr_set_rx_inj_sts_eieos            (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_eieos          )
                                ,.cfg_ordr_set_rx_inj_sts_eios             (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_eios           )
                                ,.cfg_ordr_set_rx_inj_sts_sds              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_sds            )
                                ,.cfg_ordr_set_rx_inj_sts_poll             (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_poll           )
                                ,.cfg_ordr_set_rx_inj_sts_cfg              (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_cfg            )
                                ,.cfg_ordr_set_rx_inj_sts_l0               (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_l0             )
                                ,.cfg_ordr_set_rx_inj_sts_non_eq_recov     (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_non_eq_recov   )
                                ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0  (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_1_0)
                                ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_2    (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_2  )
                                ,.cfg_ordr_set_rx_inj_sts_recov_eq_ph_3    (     os_err_rx_st_inj.cfg_ordr_set_inj_sts_recov_eq_ph_3  ),
// ---------- Outputs --------
    .ecfg_reg_data                  (ecfg_rcrb_reg_data),
    .ecfg_reg_ack                   (ecfg_rcrb_reg_ack),
    .ecfg_write_pulse               (ecfg_rcrb_write_pulse),
    .ecfg_read_pulse                (ecfg_rcrb_read_pulse),
    .err_reg_id                     (rcrb_err_reg_id),
    .ras_reg_sel                    (),//(ras_reg_sel[func_1]),//taunk..to be checked output
    .ras_reg_id                     (),//(ras_reg_id[NR_RAS_REGS*(1+func_1)-1:NR_RAS_REGS*func_1]), //taunk..to be checked output
    .spcie_reg_id                   (rcrb_spcie_reg_id),
    .pl16g_reg_id                   (rcrb_pl16g_reg_id),
    .margin_reg_id                  (rcrb_margin_reg_id),
    .pl32g_reg_id                   (rcrb_pl32g_reg_id),
    .pl64g_reg_id                   (rcrb_pl64g_reg_id),
    .l1sub_reg_id                   (rcrb_l1sub_reg_id),
    .dev3_reg_id                    (),
    .rasdes_reg_sel                 (rcrb_rasdes_reg_sel),
    .rasdes_reg_id                  (rcrb_rasdes_reg_id[64*(1+func_1)-1:64*func_1]),
    .cfg_tph_req_en                 (rcrb_cfg_tph_req_en[2*(1+func_1)-1:2*func_1]),
    .cfg_pf_tph_st_mode             (rcrb_cfg_pf_tph_st_mode[3*(1+func_1)-1:3*func_1]),
    .frsq_msi                       (rcrb_frsq_msi),           //mutiple outputs in DM with Funtions>1
    .frsq_int_msg_num               (rcrb_frsq_int_msg_num[5*(1+func_1)-1:5*func_1]),
    .cfg_ats_stu                    (rcrb_cfg_ats_stu[5*(1+func_1)-1:5*func_1]),
    .cfg_ats_cache_en               (rcrb_cfg_ats_cache_en),

    .cfg_acs_validation_cap                      (rcrb_cfg_acs_validation_cap_num),
    .cfg_acs_at_blocking_cap                     (rcrb_cfg_acs_at_blocking_cap_num),
    .cfg_acs_up_forward_cap                      (rcrb_cfg_acs_up_forward_cap_num),
    .cfg_acs_p2p_req_redirect_cap                (rcrb_cfg_acs_p2p_req_redirect_cap),
    .cfg_acs_p2p_compl_redirect_cap              (rcrb_cfg_acs_p2p_compl_redirect_cap),
    .cfg_acs_p2p_egress_ctrl_cap                 (rcrb_cfg_acs_p2p_egress_ctrl_cap),
    .cfg_acs_p2p_direct_transl_cap               (rcrb_cfg_acs_p2p_direct_transl_cap),
    .cfg_acs_egress_ctrl_vector_size_cap         (rcrb_cfg_acs_egress_ctrl_vector_size_cap[8*(1+func_1)-1:8*func_1]),
    .cfg_acs_validation_en                       (rcrb_cfg_acs_validation_en_num),
    .cfg_acs_at_blocking_en                      (rcrb_cfg_acs_at_blocking_en_num),
    .cfg_acs_p2p_req_redirect_en                 (rcrb_cfg_acs_p2p_req_redirect_en),
    .cfg_acs_p2p_compl_redirect_en               (rcrb_cfg_acs_p2p_compl_redirect_en),
    .cfg_acs_up_forward_en                       (rcrb_cfg_acs_up_forward_en_num),
    .cfg_acs_p2p_egress_ctrl_en                  (rcrb_cfg_acs_p2p_egress_ctrl_en),
    .cfg_acs_p2p_direct_transl_en                (rcrb_cfg_acs_p2p_direct_transl_en),
    .cfg_acs_egress_ctrl_vec                     (rcrb_cfg_acs_egress_ctrl_vec[ACS_CTRL_VEC_WD*(1+func_1)-1:ACS_CTRL_VEC_WD*func_1]),
    .acs_viol_svrity_mask_wr_en                  (rcrb_acs_viol_svrity_mask_wr_en),

    .cfg_prs_enable                 (rcrb_cfg_prs_enable),
    .cfg_prs_reset                  (rcrb_cfg_prs_reset),
    .cfg_prs_stopped                (rcrb_cfg_prs_stopped),
    .cfg_prs_uprgi                  (rcrb_cfg_prs_uprgi),
    .cfg_prs_response_failure       (rcrb_cfg_prs_response_failure),
    .cfg_prs_outstanding_allocation (rcrb_cfg_prs_outstanding_allocation),
    .cfg_ltr_max_latency            (rcrb_cfg_ltr_max_latency[32*(1+func_1)-1:32*func_1]),
    .cfg_vc_enable                  (rcrb_int_cfg_vc_enable[NVC*(1+func_1)-1:NVC*func_1]),               // Function 0 Only
    .cfg_vc_struc_vc_id_map         (rcrb_int_cfg_vc_struc_vc_id_map[NVC*3*(1+func_1)-1:NVC*3*func_1]),  // Function 0 Only
    .cfg_vc_id_vc_struc_map         (rcrb_int_cfg_vc_id_vc_struc_map[24*(1+func_1)-1:24*func_1]),        // Function 0 Only
    .cfg_tc_enable                  (rcrb_int_cfg_tc_enable[8*(1+func_1)-1:8*func_1]),                   // Function 0 Only
    .cfg_tc_vc_map                  (rcrb_int_cfg_tc_vc_map[24*(1+func_1)-1:24*func_1]),                 // Function 0 Only
    .cfg_tc_vc_struc_map            (rcrb_int_cfg_tc_struc_vc_map[24*(1+func_1)-1:24*func_1]),           // Function 0 Only
    .cfg_lpvc                       (rcrb_int_cfg_lpvc[3*(1+func_1)-1:3*func_1]),                        // Function 0 Only
    .cfg_vc_arb_sel                 (rcrb_int_cfg_vc_arb_sel[3*(1+func_1)-1:3*func_1]),                  // Function 0 Only
    .cfg_pwr_budget_data_sel_reg    (rcrb_int_cfg_pwr_budget_data_sel_reg[8*(1+func_1)-1:8*func_1]),
    .cfg_pwr_budget_sel             (rcrb_cfg_pwr_budget_sel),

    .cfg_rbar_bar_resizable         (),
    .cfg_rbar_bar0_mask             (),
    .cfg_rbar_bar1_mask             (),
    .cfg_rbar_bar2_mask             (),
    .cfg_rbar_bar3_mask             (),
    .cfg_rbar_bar4_mask             (),
    .cfg_rbar_bar5_mask             (),
    .cfg_vf_rbar_bar_resizable      (),
    .cfg_vf_rbar_bar0_mask          (),
    .cfg_vf_rbar_bar1_mask          (),
    .cfg_vf_rbar_bar2_mask          (),
    .cfg_vf_rbar_bar3_mask          (),
    .cfg_vf_rbar_bar4_mask          (),
    .cfg_vf_rbar_bar5_mask          ()

    ,
    .cfg_pf_pasid_control           (rcrb_cfg_pf_pasid_control[PASID_CNTRL_WD*(1+func_1)-1:PASID_CNTRL_WD*func_1])

    ,
    .ptm_vsec_reg_id                (rcrb_ptm_vsec_reg_id[NPTMVSEC*(1+func_1)-1:NPTMVSEC*func_1])

    ,.vsecdma_reg_sel                (rcrb_vsecdma_reg_sel)
    ,.vsecdma_reg_id                 (rcrb_vsecdma_reg_id[6*(1+func_1)-1:6*func_1])

    ,
    .dl_feature_en                  (rcrb_int_dl_feature_en),
    .cfg_remote_feature_ack         (rcrb_int_cfg_remote_feature_ack),
    .cfg_local_feature_support      (rcrb_int_cfg_local_feature_support[23*func_1 +: 23]),
    .cfg_remote_feature_support     (),
    .cfg_dlink_feature_valid        (rcrb_int_cfg_dlink_feature_valid)
    ,
    .fc_scaled_en                   (rcrb_int_fc_scaled_en)
    ,
    .cfg_dpc_int_msg_num                (rcrb_cfg_dpc_int_msg_num),
    .cfg_dpc_rp_ext_dpc                 (rcrb_cfg_dpc_rp_ext_dpc),
    .cfg_dpc_poison_tlp_egr_blk_support (rcrb_cfg_dpc_poison_tlp_egr_blk_support),
    .cfg_dpc_sw_trig_support            (rcrb_cfg_dpc_sw_trig_support),
    .cfg_dpc_rp_pio_log_size            (rcrb_cfg_dpc_rp_pio_log_size),
    .cfg_dpc_dl_active_err_cor_support  (rcrb_cfg_dpc_dl_active_err_cor_support),
    .cfg_dpc_trig_en                    (rcrb_cfg_dpc_trig_en),
    .cfg_dpc_trig_status                (rcrb_cfg_dpc_trig_status),
    .dpc_triggered_detect               (),
    .dpc_int                            (),
    .dpc_msi                            (),
    .cfg_dpc_cpl_cntrl                  (rcrb_cfg_dpc_cpl_cntrl),
    .cfg_dpc_int_en                     (rcrb_cfg_dpc_int_en),
    .cfg_dpc_err_cor_en                 (rcrb_cfg_dpc_err_cor_en),
    .cfg_dpc_poison_tlp_egr_block_en    (rcrb_cfg_dpc_poison_tlp_egr_block_en),
    .cfg_dpc_sw_trigger                 (rcrb_cfg_dpc_sw_trigger),
    .cfg_dpc_dl_active_err_cor_en       (rcrb_cfg_dpc_dl_active_err_cor_en)
    ,
    .rbar_ctrl_update               (),
    .cfg_rbar_size                  (),
    .vf_rbar_ctrl_update            (),
    .cfg_vf_rbar_size               ()
   ,.cxl_reg_id                   ()
   ,.cxl_rcrb_reg_id              (rcrb_cxl_port_reg_id)
   ,.cxl_mbar0_write_pulse        (cxl_mbar0_write_pulse)
   ,.cxl_mbar0_reg_ack            (rcrb_mbar0_reg_ack)
   ,.cxl_mbar0_cache_mem_reg_id   (cxl_mbar0_cache_mem_reg_id)
   ,.cxl_mbar0_arb_mux_reg_id     (cxl_mbar0_arb_mux_reg_id)
   ,.cxl_2_0_ext_reg_id           ()
   ,.cxl_reg_locator_reg_id       ()
   ,.cxl_gpf_port_reg_id          ()
   ,.cxl_gpf_device_reg_id        ()
    ,.cfg_trg_evnt_cnt                   ( int_rcrb_trg_evnt_cnt                   )               
    ,.cfg_evnt_to_cnt                    ( int_rcrb_evnt_to_cnt                    )               
    ,.cfg_flit_err_cnt_en                ( int_rcrb_flit_err_cnt_en                ) 
    ,.cfg_interr_trg_evnt_cnt_ind        ( int_rcrb_interr_trg_evnt_cnt_ind        )
    ,.cfg_fber_measurement_en            ( int_rcrb_fber_measurement_en            )
    ,.cfg_clr_fber_cnt                   ( int_rcrb_clr_fber_cnt                   )
    ,.cfg_gran_per_lane_err_rpt          ( int_rcrb_gran_per_lane_err_rpt          )
    ,.cfg_rpt_longest_burst_vs_1st_burst ( int_rcrb_rpt_longest_burst_vs_1st_burst )
    ,.cfg_flit_log_trg_evnt_msi          ( int_rcrb_flit_log_trg_evnt_msi          )
    ,.cfg_pop_fifo_en                    ( int_rcrb_pop_fifo_en                    )


                                 ,.cfg_flit_perf_interr_vec            (  int_rcrb_cfg_flit_perf_interr_vec           )
                                 ,.cfg_ltssm_trck_reg_cnt              (  int_rcrb_cfg_ltssm_trck_reg_cnt             )
                                 ,.cfg_flit_response_type              (  int_rcrb_cfg_flit_response_type             )
                                 ,.cfg_flit_type_measured              (  int_rcrb_cfg_flit_type_measured             )
                                 ,.cfg_track_mode                      (  int_rcrb_cfg_xplh_flit_track_mode           )
                                 ,.cfg_Ltssm_st_trans_trck             (  int_rcrb_cfg_Ltssm_st_trans_trck            )
                                 ,.cfg_trg_evnt_interr                 (  int_rcrb_cfg_trg_evnt_interr                )
                                 ,.cfg_flit_latency_msi                (  int_rcrb_cfg_flit_latency_msi               )
                                 ,.cfg_sts_1_ltssm_trg_evnt_interr     (  int_rcrb_cfg_sts_1_ltssm_trg_evnt_interr    )
                                 ,.cfg_sts_1_ltssm_latency_msi      (  int_rcrb_cfg_sts_1_ltssm_latency_msi     )
                                 ,.cfg_flit_err_inj_en                 (    int_rcrb_cfg_flit_err_inj_en               )
                                 ,.cfg_inj_err_tx_flit_ind             (    int_rcrb_cfg_inj_err_tx_flit_ind           )
                                 ,.cfg_inj_err_rx_flit_ind             (    int_rcrb_cfg_inj_err_rx_flit_ind           )
                                 ,.cfg_flit_err_inj_en_data_rate       (    int_rcrb_cfg_flit_err_inj_en_data_rate     )
                                 ,.cfg_inj_err_num                     (    int_rcrb_cfg_inj_err_num                   )
                                 ,.cfg_inj_err_spacing                 (    int_rcrb_cfg_inj_err_spacing               )
                                 ,.cfg_flit_type_inj                   (    int_rcrb_cfg_flit_type_inj                 )
                                 ,.cfg_consec_err_inj                  (    int_rcrb_cfg_consec_err_inj                )
                                 ,.cfg_curr_inj_err_type               (    int_rcrb_cfg_curr_inj_err_type             )
                                 ,.cfg_flit_err_off                    (    int_rcrb_cfg_flit_err_off                  )
                                 ,.cfg_err_mag                         (    int_rcrb_cfg_err_mag                       )
                                 ,.cfg_ordr_set_err_inj_en             (    int_rcrb_cfg_ordr_set_err_inj_en           )
                                 ,.cfg_inj_err_tx_ordr_set_ind         (    int_rcrb_cfg_inj_err_tx_ordr_set_ind       )
                                 ,.cfg_inj_err_rx_ordr_set_ind         (    int_rcrb_cfg_inj_err_rx_ordr_set_ind       )
                                 ,.cfg_ordr_set_inj_err_num            (    int_rcrb_cfg_ordr_set_inj_err_num          )
                                 ,.cfg_ordr_set_inj_err_spacing        (    int_rcrb_cfg_ordr_set_inj_err_spacing      )
                                 ,.cfg_inj_err_ts0_os                  (    int_rcrb_cfg_inj_err_ts0_os                )
                                 ,.cfg_inj_err_ts1_os                  (    int_rcrb_cfg_inj_err_ts1_os                )
                                 ,.cfg_inj_err_ts2_os                  (    int_rcrb_cfg_inj_err_ts2_os                )
                                 ,.cfg_inj_err_skp_os                  (    int_rcrb_cfg_inj_err_skp_os                )
                                 ,.cfg_inj_err_eieos_os                (    int_rcrb_cfg_inj_err_eieos_os              )
                                 ,.cfg_inj_err_eios_os                 (    int_rcrb_cfg_inj_err_eios_os               )
                                 ,.cfg_inj_err_sds_os                  (    int_rcrb_cfg_inj_err_sds_os                )
                                 ,.cfg_inj_err_poll_st                 (    int_rcrb_cfg_inj_err_poll_st               )
                                 ,.cfg_inj_err_cfg_st                  (    int_rcrb_cfg_inj_err_cfg_st                )
                                 ,.cfg_inj_err_l0_st                   (    int_rcrb_cfg_inj_err_l0_st                 )
                                 ,.cfg_inj_err_non_eq_recov_st         (    int_rcrb_cfg_inj_err_non_eq_recov_st       )
                                 ,.cfg_inj_err_recov_eq_ph_1_0         (    int_rcrb_cfg_inj_err_recov_eq_ph_1_0       )
                                 ,.cfg_inj_err_recov_eq_ph_2           (    int_rcrb_cfg_inj_err_recov_eq_ph_2         )
                                 ,.cfg_inj_err_recov_eq_ph_3           (    int_rcrb_cfg_inj_err_recov_eq_ph_3         )
                                 ,.cfg_err_inj_bytes                   (    int_rcrb_cfg_err_inj_bytes                 )
                                 ,.cfg_err_inj_lane_num                (    int_rcrb_cfg_err_inj_lane_num              )
                                
); // cdm_rcrb_ecfg_reg
end // for (func_1=0; func_1<1; func_1 = func_1+1) begin : gen_cdm_rcrb_reg
endgenerate




// -----------------------------------------------------------------------------
// Flex Bus Device DVSEC
// -----------------------------------------------------------------------------
//cfg_cxl_viral_enable is a common signal across multiple controller configuration types
assign cfg_cxl_viral_enable = rc_device ? 1'b1 : cfg_cxl_dev_viral_enable[0];
assign cfg_cxl_viral_status = rc_device ? cfg_cxl_pl_reg_viral_status : cfg_cxl_dev_viral_status[0];


assign viral_status_ep = rc_device ? 1'b0 : viral_status ;


wire [31:0]     cxl_reg_data_0;

cdm_cxl_device_reg

u_cdm_cxl_device_reg (

// ----- Inputs -------
    .aux_clk                              (core_clk),                            // Clock
    .non_sticky_rst_n                     (non_sticky_rst_n),                    // Reset non_sticky register only
    .sticky_rst_n                         (sticky_rst_n),                        // Reset sticky register only
    .lbc_cdm_data                         (lbc_cdm_data),
    .lbc_cdm_dbi                          (lbc_cdm_dbi),
    .dbi_ro_wr_en                         (dbi_ro_wr_en),

    .cxl_dev_write_pulse                  (ecfg_write_pulse[0]),
    .cxl_dev_reg_id                       (cxl_reg_id[0]),
    .upstream_port                        (upstream_port),
    .viral_status                         (viral_status_ep),
    .cxl_rcrb_enable                      (cxl_rcrb_enable),
    .cxl_dev_cache_invalid                (cxl_dev_cache_invalid),                 // CXL device indicate cache invalid state
    .cxl_dev_cache_wr_invld_cmpl          (cxl_dev_cache_wr_invld_cmpl),           // CXL device indicate cache writeback and invalidation is complete state
    .cxl_volatile_hdm_error               (cxl_volatile_hdm_error[0]),             // CXL device indicate Volatile HDM Preservation Error
    .cxl_pm_init_cmpl                 (cxl_pm_init_cmpl),                  // CXL PM initialization completion state

//   -- Outputs --

    .cxl_dev_reg_data                     (cxl_reg_data_0),                           // Read data from the Flex Bus Device DVSEC Register

    .cfg_cxl_dev_cache_enable             (cfg_cxl_dev_cache_enable),                 // Enable CXL.cache protocol operation when in Flex Bus.AL mode
    .cfg_cxl_dev_io_enable                (cfg_cxl_dev_io_enable[0]),                 // Enable CXL.io operation when in Flex Bus.AL mode
    .cfg_cxl_dev_mem_enable               (cfg_cxl_dev_mem_enable[0]),                // Enable CXL.mem protocol operation when in Flex Bus.AL mode
    .cfg_cxl_dev_cache_sf_coverage        (cfg_cxl_dev_cache_sf_coverage),            // Performance hint to the device
    .cfg_cxl_dev_cache_sf_granularity     (cfg_cxl_dev_cache_sf_granularity),         // Performance hint to the device
    .cfg_cxl_dev_cache_clean_eviction     (cfg_cxl_dev_cache_clean_eviction),         // Performance hint to the device
    .cfg_cxl_dev_viral_enable             (cfg_cxl_dev_viral_enable[0]),              // Enable Viral Handling
    .cfg_cxl_dev_viral_capable            (cfg_cxl_dev_viral_capable[0]),             // Indicates CXL device supports Viral handling
    .cfg_cxl_dev_cxl_rst_mem_clr_enable   (cfg_cxl_dev_cxl_rst_mem_clr_enable[0]),    // Enable clearing or randomization of Volatile HDM ranges during CXL_Reset
    .cfg_cxl_dev_post_cold_rst_volatile_hdm_default (cfg_cxl_dev_post_cold_rst_volatile_hdm_default[0]),    // Default Volatile HDM State After Cold Reset
    .cfg_cxl_dev_post_warm_rst_volatile_hdm_default (cfg_cxl_dev_post_warm_rst_volatile_hdm_default[0]),    // Default Volatile HDM State After Warm Reset
    .cfg_cxl_dev_post_hot_rst_volatile_hdm_default  (cfg_cxl_dev_post_hot_rst_volatile_hdm_default[0]),     // Default Volatile HDM State After Hot Reset
    .cfg_cxl_dev_post_hot_rst_volatile_hdm_desired  (cfg_cxl_dev_post_hot_rst_volatile_hdm_desired[0]),     // Desired Volatile HDM State After Hot Reset

    .cfg_cxl_dev_viral_status             (cfg_cxl_dev_viral_status[0]),              // Indicates CXL device  Viral Status
    .cfg_cxl_dev_disable_caching          (cfg_cxl_dev_disable_caching),              // Indicates CXL device Disable Caching control
    .cfg_cxl_dev_initiate_cache_wr_invld  (cfg_cxl_dev_initiate_cache_wr_invld),      // Indicates CXL device Initiate Cache Write Back and Invalidation control
    .cfg_cxl_dev_initiate_cxl_rst         (cfg_cxl_dev_initiate_cxl_rst[0]),          // Indicates CXL device Initiate CXL_Reset control

    .cfg_cxl_dev_range1_mem_size_high      (cfg_cxl_dev_range1_mem_size_high[0]),      // Corresponds to bits 63:32 of Flex Bus Range 1 memory size
    .cfg_cxl_dev_range1_mem_info_valid     (cfg_cxl_dev_range1_mem_info_valid[0]),     // Indicates that the Flex Bus Range 1 Size high and Size Low registers are valid
    .cfg_cxl_dev_range1_mem_active         (cfg_cxl_dev_range1_mem_active[0]),         // Indicates that the Flex Bus Range 1 memory is fully initialized and available for software use
    .cfg_cxl_dev_range1_desired_interleave (cfg_cxl_dev_range1_desired_interleave[0]), // Represents the memory interleaving desired by the device
    .cfg_cxl_dev_range1_mem_active_timeout (cfg_cxl_dev_range1_mem_active_timeout[0]), // Indicates maximum time that device is permitted to take to set Memory_active bit in this register after a conventional reset
    .cfg_cxl_dev_range1_mem_size_low       (cfg_cxl_dev_range1_mem_size_low[0]),       // Corresponds to bits 31:28 of Flex Bus Range 1 memory size
    .cfg_cxl_dev_range1_mem_base_high      (cfg_cxl_dev_range1_mem_base_high[0]),      // Corresponds to bits 63:32 of Flex Bus Range 1 base in the host address space
    .cfg_cxl_dev_range1_mem_base_low       (cfg_cxl_dev_range1_mem_base_low[0]),       // Corresponds to bits 31:28 of Flex Bus Range 1 base in the host address space

    .cfg_cxl_dev_range2_mem_size_high      (cfg_cxl_dev_range2_mem_size_high[0]),      // Corresponds to bits 63:32 of Flex Bus Range 2 memory size
    .cfg_cxl_dev_range2_mem_info_valid     (cfg_cxl_dev_range2_mem_info_valid[0]),     // Indicates that the Flex Bus Range 2 Size high and Size Low registersare valid
    .cfg_cxl_dev_range2_mem_active         (cfg_cxl_dev_range2_mem_active[0]),         // Indicates that the Flex Bus Range 2 memory is fully initialized and availablefor software use
    .cfg_cxl_dev_range2_desired_interleave (cfg_cxl_dev_range2_desired_interleave[0]), // Represents the memory interleaving desired by the device
    .cfg_cxl_dev_range2_mem_active_timeout (cfg_cxl_dev_range2_mem_active_timeout[0]), // Indicates maximum time that device is permitted to take to set Memory_active bit in this register after a conventional reset
    .cfg_cxl_dev_range2_mem_size_low       (cfg_cxl_dev_range2_mem_size_low[0]),       // Corresponds to bits 31:28 of Flex Bus Range 2 memory size
    .cfg_cxl_dev_range2_mem_base_high      (cfg_cxl_dev_range2_mem_base_high[0]),      // Corresponds to bits 63:32 of Flex Bus Range 2 base in the host address space
    .cfg_cxl_dev_range2_mem_base_low       (cfg_cxl_dev_range2_mem_base_low[0])        // Corresponds to bits 31:28 of Flex Bus Range 2 base in the host address space


) ;  // cdm_cxl_device_reg


// -----------------------------------------------------------------------------
// Flex Bus PORT DVSEC
// -----------------------------------------------------------------------------
wire [3:0] cxl_port_write_pulse = ecfg_rcrb_write_pulse | ecfg_write_pulse[0];

cdm_cxl_port_reg

u_cdm_cxl_port_reg (

// ----- Inputs -------
    .aux_clk                              (core_clk),                            // Clock
    .non_sticky_rst_n                     (non_sticky_rst_n),                    // Reset non_sticky register only
    .sticky_rst_n                         (sticky_rst_n),                        // Reset sticky register only
    .lbc_cdm_data                         (lbc_cdm_data),
    .lbc_cdm_dbi                          (lbc_cdm_dbi),
    .dbi_ro_wr_en                         (dbi_ro_wr_en),
    .cxl_port_write_pulse                 (cxl_port_write_pulse),               //Only use function 0
    .cxl_port_reg_id                      (cxl_port_reg_id),
    .upstream_port                        (upstream_port),
    .ltssm_cxl_enable                     (phy_ltssm_cxl_enable),
    .correctable_protocol_id_frame_err    (correctable_protocol_id_frame_err),
    .uncorrectable_protocol_id_frame_err  (uncorrectable_protocol_id_frame_err),
    .unexpected_protocol_id_dropped       (unexpected_protocol_id_dropped),
    .retimers_present_mismatched          (cxl_retimers_present_mismatched),
    .fb_enable_bits_phase2_mismatch       (flexbusenablebits_phase2_mismatch),
    .current_data_rate                    (current_data_rate),
    .cfg_pcie_slot_clk_config             (cfg_pcie_slot_clk_config),
    .cxl_rcrb_enable                      (cxl_rcrb_enable),
    .cxl_port_rcvd_mod_ts_data_phase1     (cxl_port_rcvd_mod_ts_data_phase1),

//   -- Outputs --
    .cxl_port_reg_data                    (cxl_port_reg_data),                   // Data read from the register

    .cfg_cxl_port_cache_capable           (cfg_cxl_port_cache_capable),          // Indicates CXL.cache protocol support when operating in Flex Bus.AL mode
    .cfg_cxl_port_mem_capable             (cfg_cxl_port_mem_capable),            // Indicates CXL.mem protocol support when operating in Flex Bus.AL mode
    .cfg_cxl_port_vid                     (cfg_cxl_port_vid),
    .cfg_cxl_port_68B_flit_vh_capable     (cfg_cxl_port_68B_flit_vh_capable),    // Indicates CXL VH functionality support with 68B flits
    .cfg_cxl_port_mld_capable             (cfg_cxl_port_mld_capable),            // Indicates CXL Multi-Logical Device support when operating in Flex Bus.AL mode
    .cfg_cxl_port_lopt_flit_capable       (cfg_cxl_port_lopt_flit_capable),      // Indicates CXL Latency-optimized flit mode capability
    .cfg_cxl_port_pbr_flit_capable        (cfg_cxl_port_pbr_flit_capable),       // Indicates CXL PBR flit mode capability
    .cfg_cxl_port_nop_hint_capable        (cfg_cxl_port_nop_hint_capable),       // Indicates CXL NOP Insertion Hint Performance Optimization capability
    .cfg_cxl_port_68B_flit_vh_enable      (cfg_cxl_port_68B_flit_vh_enable),     // Enable CXL VH operation with 68B Flit mode
    .cfg_cxl_port_mld_enable              (cfg_cxl_port_mld_enable),             // Enable CXL Multi-Logical Device support
    .cfg_cxl_port_disable_cxl1p1_training (cfg_cxl_port_disable_cxl1p1_training),//Disable CXL 1.0 training

    .cfg_cxl_port_cache_enable            (cfg_cxl_port_cache_enable),           // Enable CXL.Cache
    .cfg_cxl_port_io_enable               (cfg_cxl_port_io_enable),              // Enable CXL.io
    .cfg_cxl_port_mem_enable              (cfg_cxl_port_mem_enable),             // Enable CXL.mem
    .cfg_cxl_port_sync_hdr_bypass_enable  (cfg_cxl_port_sync_hdr_bypass_enable), // Enable bypass of the 2-bit sync header by the Flex Bus physical layer when operating in Flex Bus.AL mode
    .cfg_cxl_port_drift_buffer_enable     (cfg_cxl_port_drift_buffer_enable),    // Enable drift buffer (instead of elastic buffer) if there is a common reference clock
    .cfg_cxl_port_retimer1_present        (cfg_cxl_port_retimer1_present),       // Retimer1 is present (only valid for downstream port)
    .cfg_cxl_port_retimer2_present        (cfg_cxl_port_retimer2_present),       // Retimer2 is present (only valid for downstream port)
    .cfg_cxl_port_retimers_pre_mismatched (cfg_cxl_port_retimers_pre_mismatched), // Status bit for CXL Retimers Present Mismatched
    .cfg_cxl_port_lopt_flit_enable        (cfg_cxl_port_lopt_flit_enable),        // Enable bit for Latency-optimized flit mode
    .cfg_cxl_port_pbr_flit_enable         (cfg_cxl_port_pbr_flit_enable),         // Enable bit for PBR flit mode
    .cfg_cxl_port_nop_hint_enable         (cfg_cxl_port_nop_hint_enable)

) ;  // cdm_cxl_port_reg

// -----------------------------------------------------------------------------
// RCRB MEMBAR0
// -----------------------------------------------------------------------------
cdm_cxl_membar0

u_cdm_cxl_membar0 (
    .aux_clk                                (core_clk),                            // Clock
    .non_sticky_rst_n                       (non_sticky_rst_n),                    // Reset non_sticky register only
    .sticky_rst_n                           (sticky_rst_n),                        // Reset sticky register only

    .lbc_cdm_data                           (lbc_cdm_data),
    .lbc_cdm_dbi                            (lbc_cdm_dbi),
    .dbi_ro_wr_en                           (dbi_ro_wr_en),
    .cxl_mbar0_write_pulse                  (cxl_mbar0_write_pulse_mux),
    .cxl_mbar0_cache_mem_reg_id             (cxl_mbar0_cache_mem_reg_id_mux),
    .cxl_mbar0_arb_mux_reg_id               (cxl_mbar0_arb_mux_reg_id_mux),
    .upstream_port                          (upstream_port),
    .cxl2p0_enabled                         (cxl_mbar0_enable),

    .mbar0_ras_unc_cache_data_parity        (mbar0_ras_unc_cache_data_parity),
    .mbar0_ras_unc_cache_addr_parity        (mbar0_ras_unc_cache_addr_parity),
    .mbar0_ras_unc_cache_be_parity          (mbar0_ras_unc_cache_be_parity),
    .mbar0_ras_unc_cache_data_ecc           (mbar0_ras_unc_cache_data_ecc),
    .mbar0_ras_unc_mem_data_parity          (mbar0_ras_unc_mem_data_parity),
    .mbar0_ras_unc_mem_addr_parity          (mbar0_ras_unc_mem_addr_parity),
    .mbar0_ras_unc_mem_be_parity            (mbar0_ras_unc_mem_be_parity),
    .mbar0_ras_unc_mem_data_ecc             (mbar0_ras_unc_mem_data_ecc),
    .mbar0_ras_unc_reinit_threshold         (mbar0_ras_unc_reinit_threshold),
    .mbar0_ras_unc_rsvd_encoding_violation  (mbar0_ras_unc_rsvd_encoding_violation),
    .mbar0_ras_unc_poison_received          (mbar0_ras_unc_poison_received),
    .mbar0_ras_unc_receiver_overflow        (mbar0_ras_unc_receiver_overflow),
    .mbar0_ras_unc_internal_error           (mbar0_ras_unc_internal_error),
    .mbar0_ras_unc_cxl_ide_tx_error         (mbar0_ras_unc_cxl_ide_tx_error),
    .mbar0_ras_unc_cxl_ide_rx_error         (mbar0_ras_unc_cxl_ide_rx_error),

    .mbar0_ras_corr_cache_data_ecc          (mbar0_ras_corr_cache_data_ecc),
    .mbar0_ras_corr_mem_data_ecc            (mbar0_ras_corr_mem_data_ecc),
    .mbar0_ras_corr_crc_threshold           (mbar0_ras_corr_crc_threshold),
    .mbar0_ras_corr_retry_threshold         (mbar0_ras_corr_retry_threshold),
    .mbar0_ras_corr_cache_poison_received   (mbar0_ras_corr_cache_poison_received),
    .mbar0_ras_corr_mem_poison_received     (mbar0_ras_corr_mem_poison_received),
    .mbar0_ras_corr_physical_layer_error    (mbar0_ras_corr_physical_layer_error),

    .mbar0_ras_header_log_reg0              (mbar0_ras_header_log_reg0),
    .mbar0_ras_header_log_reg1              (mbar0_ras_header_log_reg1),
    .mbar0_ras_header_log_reg2              (mbar0_ras_header_log_reg2),
    .mbar0_ras_header_log_reg3              (mbar0_ras_header_log_reg3),
    .mbar0_ras_header_log_reg4              (mbar0_ras_header_log_reg4),
    .mbar0_ras_header_log_reg5              (mbar0_ras_header_log_reg5),
    .mbar0_ras_header_log_reg6              (mbar0_ras_header_log_reg6),
    .mbar0_ras_header_log_reg7              (mbar0_ras_header_log_reg7),
    .mbar0_ras_header_log_reg8              (mbar0_ras_header_log_reg8),
    .mbar0_ras_header_log_reg9              (mbar0_ras_header_log_reg9),
    .mbar0_ras_header_log_reg10             (mbar0_ras_header_log_reg10),
    .mbar0_ras_header_log_reg11             (mbar0_ras_header_log_reg11),
    .mbar0_ras_header_log_reg12             (mbar0_ras_header_log_reg12),
    .mbar0_ras_header_log_reg13             (mbar0_ras_header_log_reg13),
    .mbar0_ras_header_log_reg14             (mbar0_ras_header_log_reg14),
    .mbar0_ras_header_log_reg15             (mbar0_ras_header_log_reg15),

    .mbar0_ras_uncorr_error_mask            (mbar0_ras_uncorr_error_mask),
    .mbar0_ras_uncorr_error_severity        (mbar0_ras_uncorr_error_severity),
    .mbar0_ras_corr_error_mask              (mbar0_ras_corr_error_mask),
    .mbar0_ras_poison_enabled               (mbar0_ras_poison_enabled),

    .mbar0_security_device_trust_level      (mbar0_security_device_trust_level),

    .mbar0_arb_mux_cxl_io                   (mbar0_arb_mux_cxl_io),
    .mbar0_arb_mux_cxl_cache_mem            (mbar0_arb_mux_cxl_cache_mem),
    .mbar0_arb_mux_pmtimeout_en             (mbar0_arb_mux_pmtimeout_en),
    .mbar0_arb_mux_pmtimeout_val            (mbar0_arb_mux_pmtimeout_val),
    .mbar0_arb_mux_pmtimeout_err            (mbar0_arb_mux_pmtimeout_err),
    .mbar0_arb_mux_l0ptimeout_err           (mbar0_arb_mux_l0ptimeout_err),
    .mbar0_arb_mux_uncorr_err               (mbar0_arb_mux_uncorr_err),

    .mbar0_cap_header_reg                   (mbar0_cap_header_reg),
    .mbar0_ras_cap_header_reg               (mbar0_ras_cap_header_reg),
    .mbar0_security_cap_header_reg          (mbar0_security_cap_header_reg),
    .mbar0_link_cap_header_reg              (mbar0_link_cap_header_reg),
    .cxl_mbar0_reg_data                     (rcrb_mbar0_reg_data),
    .rcrb_ras_uncorr_error                  (rcrb_ras_uncorr_error),
    .rcrb_ras_corr_error_level              (rcrb_ras_corr_error_level),
    .rcrb_ras_corr_error_pulse              (rcrb_ras_corr_error_pulse),
    .cxl_mbar0_ras_corr_reg                 (mbar0_ras_corr_reg),
    .cxl_mbar0_ras_uncorr_reg               (mbar0_ras_uncorr_reg)
) ;


// -----------------------------------------------------------------------------
// CXL 2.0 Extension DVSEC
// -----------------------------------------------------------------------------

cdm_cxl_2_0_ext_reg

u_cdm_cxl_2_0_ext_reg (

// ----- Inputs -------
    .aux_clk                                 (core_clk),                                // Clock
    .non_sticky_rst_n                        (non_sticky_rst_n),                        // Reset non_sticky register only
    .sticky_rst_n                            (sticky_rst_n),                            // Reset sticky register only




    .lbc_cdm_data                            (lbc_cdm_data),
    .lbc_cdm_dbi                             (lbc_cdm_dbi),
    .dbi_ro_wr_en                            (dbi_ro_wr_en),
    .cxl_2_0_ext_write_pulse                 (ecfg_write_pulse[0]),                    //Only use function 0
    .cxl_2_0_ext_reg_id                      (cxl_2_0_ext_reg_id[9:0]),
    .upstream_port                           (upstream_port),
    .cxl_pm_init_cmpl                        (cxl_pm_init_cmpl),
    .viral_status                            (viral_status),

//   -- Outputs --
    .cxl_2_0_ext_reg_data                    (cxl_2_0_ext_reg_data),                      // Data read from the register

    .cfg_cxl_2_0_ext_viral_status            (cfg_cxl_2_0_ext_viral_status),              // Switch has entered Viral
    .cfg_cxl_2_0_ext_unmask_sbr              (cfg_cxl_2_0_ext_unmask_sbr),                // Unmask SBR
    .cfg_cxl_2_0_ext_unmask_ld               (cfg_cxl_2_0_ext_unmask_ld),                 // Unmask Link Disable
    .cfg_cxl_2_0_ext_alt_mse                 (cfg_cxl_2_0_ext_alt_mse),                   // Alternate Memory Space Enable
    .cfg_cxl_2_0_ext_alt_bme                 (cfg_cxl_2_0_ext_alt_bme),                   // Alternate Bus Master Enable
    .cfg_cxl_2_0_ext_viral_en                (cfg_cxl_2_0_ext_viral_en),                  // Viral Enable for Switch
    .cfg_cxl_2_0_ext_alt_bus_base            (cfg_cxl_2_0_ext_alt_bus_base),              // Alternate Bus Base
    .cfg_cxl_2_0_ext_alt_bus_limit           (cfg_cxl_2_0_ext_alt_bus_limit),             // Alternate Bus Limit
    .cfg_cxl_2_0_ext_alt_mem_base            (cfg_cxl_2_0_ext_alt_mem_base),              // Alternate Memory Base
    .cfg_cxl_2_0_ext_alt_mem_limit           (cfg_cxl_2_0_ext_alt_mem_limit),             // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base       (cfg_cxl_2_0_ext_alt_pref_mem_base),         // Alternate Prefetchable Memory Base
    .cfg_cxl_2_0_ext_alt_pref_mem_limit      (cfg_cxl_2_0_ext_alt_pref_mem_limit),        // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base_high  (cfg_cxl_2_0_ext_alt_pref_mem_base_high),    // Alternate Prefetchable Memory Base High
    .cfg_cxl_2_0_ext_alt_pref_mem_limit_high (cfg_cxl_2_0_ext_alt_pref_mem_limit_high),   // Alternate Prefetchable Memory Base High
    .cfg_cxl_2_0_ext_rcrb_en                 (cfg_cxl_2_0_ext_rcrb_en),                   // CXL RCRB Enable
    .cfg_cxl_2_0_ext_rcrb_base_addr_low      (cfg_cxl_2_0_ext_rcrb_base_addr_low),        // CXL RCRB Base Address Low
    .cfg_cxl_2_0_ext_rcrb_base_addr_high     (cfg_cxl_2_0_ext_rcrb_base_addr_high)        // RCRB Base Address High

) ;  // cdm_cxl_2_0_ext_reg

// -----------------------------------------------------------------------------
// CXL 2.0 Register Locator DVSEC
// -----------------------------------------------------------------------------
wire [31:0]     cxl_reg_locator_reg_data_0;

cdm_cxl_reg_locator_reg

u_cdm_cxl_reg_locator_reg (

// ----- Inputs -------
    .aux_clk                                 (core_clk),                                // Clock
    .non_sticky_rst_n                        (non_sticky_rst_n),                        // Reset non_sticky register only
    .sticky_rst_n                            (sticky_rst_n),                            // Reset sticky register only


    .lbc_cdm_data                            (lbc_cdm_data),
    .lbc_cdm_dbi                             (lbc_cdm_dbi),
    .dbi_ro_wr_en                            (dbi_ro_wr_en),
    .cxl_reg_locator_write_pulse             (ecfg_write_pulse[0]),                    //Only use function 0
    .cxl_reg_locator_reg_id                  (cxl_reg_locator_reg_id[0]),
    .upstream_port                           (upstream_port),

//   -- Outputs --
    .cxl_reg_locator_reg_data                 (cxl_reg_locator_reg_data_0),                    // Data read from the register
    .cxl_2_0_comp_reg_offset                  (cxl_2_0_comp_reg_offset[0]),                    // CXL 2.0 Comp Specific Register Offset within Func 0, BAR0
    .cfg_cxl_reg_locator_reg1_bir             (cfg_cxl_reg_locator_reg1_bir[0]),
    .cfg_cxl_reg_locator_reg1_blk_identifier  (cfg_cxl_reg_locator_reg1_blk_identifier[0]),
    .cfg_cxl_reg_locator_reg1_blk_offset_low  (cfg_cxl_reg_locator_reg1_blk_offset_low[0]),
    .cfg_cxl_reg_locator_reg1_blk_offset_high (cfg_cxl_reg_locator_reg1_blk_offset_high[0]),
    .cfg_cxl_reg_locator_reg2_bir             (cfg_cxl_reg_locator_reg2_bir[0]),
    .cfg_cxl_reg_locator_reg2_blk_identifier  (cfg_cxl_reg_locator_reg2_blk_identifier[0]),
    .cfg_cxl_reg_locator_reg2_blk_offset_low  (cfg_cxl_reg_locator_reg2_blk_offset_low[0]),
    .cfg_cxl_reg_locator_reg2_blk_offset_high (cfg_cxl_reg_locator_reg2_blk_offset_high[0]),
    .cfg_cxl_reg_locator_reg3_bir             (cfg_cxl_reg_locator_reg3_bir[0]),
    .cfg_cxl_reg_locator_reg3_blk_identifier  (cfg_cxl_reg_locator_reg3_blk_identifier[0]),
    .cfg_cxl_reg_locator_reg3_blk_offset_low  (cfg_cxl_reg_locator_reg3_blk_offset_low[0]),
    .cfg_cxl_reg_locator_reg3_blk_offset_high (cfg_cxl_reg_locator_reg3_blk_offset_high[0])

) ;  // cdm_cxl_reg_locator_reg

// -----------------------------------------------------------------------------
// CXL Port GPF DVSEC
// -----------------------------------------------------------------------------

cdm_cxl_gpf_port_reg

u_cdm_cxl_gpf_port_reg (

// ----- Inputs -------
    .aux_clk                                 (core_clk),                                // Clock
    .non_sticky_rst_n                        (non_sticky_rst_n),                        // Reset non_sticky register only
    .sticky_rst_n                            (sticky_rst_n),                            // Reset sticky register only


    .lbc_cdm_data                            (lbc_cdm_data),
    .lbc_cdm_dbi                             (lbc_cdm_dbi),
    .dbi_ro_wr_en                            (dbi_ro_wr_en),
    .cxl_gpf_port_write_pulse                (ecfg_write_pulse[0]),                    //Only use function 0
    .cxl_gpf_port_reg_id                     (cxl_gpf_port_reg_id[3:0]),
    .upstream_port                           (upstream_port),

//   -- Outputs --
    .cxl_gpf_port_reg_data                   (cxl_gpf_port_reg_data),                     // Data read from the register
    .cfg_cxl_gpf_port_p1_timeout_base        (cfg_cxl_gpf_port_p1_timeout_base),
    .cfg_cxl_gpf_port_p1_timeout_scale       (cfg_cxl_gpf_port_p1_timeout_scale),
    .cfg_cxl_gpf_port_p2_timeout_base        (cfg_cxl_gpf_port_p2_timeout_base),
    .cfg_cxl_gpf_port_p2_timeout_scale       (cfg_cxl_gpf_port_p2_timeout_scale)

) ;  // cdm_cxl_gpf_port_reg



// -----------------------------------------------------------------------------
// CXL Device GPF DVSEC
// -----------------------------------------------------------------------------
wire [31:0]     cxl_gpf_device_reg_data_0;

cdm_cxl_gpf_device_reg

u_cdm_cxl_gpf_device_reg (

// ----- Inputs -------
    .aux_clk                                 (core_clk),                                // Clock
    .non_sticky_rst_n                        (non_sticky_rst_n),                        // Reset non_sticky register only
    .sticky_rst_n                            (sticky_rst_n),                            // Reset sticky register only


    .lbc_cdm_data                            (lbc_cdm_data),
    .lbc_cdm_dbi                             (lbc_cdm_dbi),
    .dbi_ro_wr_en                            (dbi_ro_wr_en),
    .cxl_gpf_device_write_pulse              (ecfg_write_pulse[0]),                    //Only use function 0
    .cxl_gpf_device_reg_id                   (cxl_gpf_device_reg_id[0]),
    .upstream_port                           (upstream_port),

//   -- Outputs --
    .cxl_gpf_device_reg_data                 (cxl_gpf_device_reg_data_0)                // Data read from the register

) ;  // cdm_cxl_gpf_device_reg











          // map any function reading from or writing to PTM VSEC back to function 0, simply 21 OR gates with a FUNC_NUM width
  always @(*) begin : gen_vsec_id
// LMD: Variable hides a variable in outer scope i
// LJ: This variable is intern to this block
// leda W121 off
  integer i;
// leda W121 on
  integer fn;
  int_ptm_vsec_reg_id = 0;
    for(i=0;i<NPTMVSEC;i=i+1) begin
      for(fn=0; fn<NF; fn=fn+1) begin
        int_ptm_vsec_reg_id[i] = int_ptm_vsec_reg_id[i] | ptm_vsec_reg_id[(fn*NPTMVSEC)+i];
      end
    end
  end

          // map any function reading from or writing to PTM VSEC back to function 0, simply 4 OR gates with a FUNC_NUM width
  assign int_ptm_write_pulse[3:0] = ecfg_write_pulse[0];

  always @(*) begin : gen_ptm_vsec_write
// LMD: Variable hides a variable in outer scope i
// LJ: This variable is intern to this block
// leda W121 off
  integer i;
// leda W121 on
  integer fn;
  int_ptm_vsec_write_pulse = 0;
    for(i=0;i<4;i=i+1) begin
      for(fn=0; fn<NF; fn=fn+1) begin
        int_ptm_vsec_write_pulse[i] = int_ptm_vsec_write_pulse[i] | ecfg_write_pulse[fn][i];
      end
    end
  end

// ---------- PTM Capabilities ---------------------------

always @(posedge core_clk or negedge non_sticky_rst_n) begin : ptm_id_proc

integer depth;

  if(!non_sticky_rst_n)
    ptm_reg_id <= #TP 0;
  else
    for (depth = 0; depth < NPTM; depth = depth + 1)
    begin : gen_PTM_ID
      ptm_reg_id[depth] <= #TP (lbc_cdm_addr[11:2] == ((`PTM_PTR + (depth*4)) >> 2)) & ecfg_reg_sel[0];
    end
end // ptm_id_proc



//PTM Extended Capability
cdm_ptm_reg
  #(.INST(INST)
                )
u_cdm_ptm_reg (
               // INPUTS
               .core_clk                  (core_clk),

               .sticky_rst_n              (sticky_rst_n),
               .non_sticky_rst_n          (non_sticky_rst_n),
               .cdm_clk_g                 (cdm_clk_g_int),
               .device_type               (device_type),



               .lbc_cdm_data              (lbc_cdm_data),
               .lbc_cdm_dbi               (lbc_cdm_dbi),
               .ptm_write_pulse           (int_ptm_write_pulse),
               .ptm_reg_id                (ptm_reg_id),
               .dbi_ro_wr_en              (dbi_ro_wr_en),

               // OUTPUTS
               .cfg_ptm_enable            (cfg_ptm_enable),
               .cfg_ptm_responder_capable (cfg_ptm_responder_capable),
               .ptm_reg_data              (ptm_reg_data),
               .cfg_ptm_root_select       (cfg_ptm_root_select)
  );




//PTM Vendor specific Capability
ptm_req_res
 #(.NPTMVSEC(NPTMVSEC), .NPTMREQVSEC(NPTMREQVSEC), .NPTMRESVSEC(NPTMRESVSEC)
              )
u_ptm_req_res (

    .aux_clk                      (core_clk),
    .non_sticky_rst_n             (non_sticky_rst_n),
    .sticky_rst_n                 (sticky_rst_n),

    .lbc_cdm_dbi                  (lbc_cdm_dbi),
    .lbc_cdm_data                 (lbc_cdm_data),
    .dbi_ro_wr_en                 (dbi_ro_wr_en),
    .write_pulse                  (int_ptm_vsec_write_pulse),
    .reg_id                       (int_ptm_vsec_reg_id),

    .ptm_external_master_strobe   (ptm_external_master_strobe),
    .ptm_external_master_time     (ptm_external_master_time),

    .rdlh_link_up                 (rdlh_link_up),
    .cfg_ptm_enabled              (cfg_ptm_enable),
    .cfg_ptm_responder_capable    (cfg_ptm_responder_capable),
    .cfg_ptm_root_select          (cfg_ptm_root_select),
    .pm_sel_aux_clk               (pm_sel_aux_clk),
    .current_data_rate            (current_data_rate),
    .mac_phy_rate                 (tmp_int_mac_phy_rate),
    .cfg_neg_link_width           (cfg_neg_link_width),
    .flit_mode_link               (flit_mode_enable),
    .smlh_autoneg_link_sp         (smlh_autoneg_link_sp),
    .smlh_in_l0                   (smlh_in_l0),

    .upstream_port                (upstream_port),

    .xdlh_retry_req               (xdlh_retry_req),
    .xdlh_ptm_sot                 (xdlh_ptm_sot),
    .xdlh_ptm_multi_cycle         (xdlh_ptm_multi_cycle),
    .xdlh_ptm_request             (xdlh_ptm_request),
    .xdlh_ptm_response            (xdlh_ptm_response),
    .xdlh_rbuf_replaying          (xdlh_rbuf_replaying),
    .rdlh_ptm_sot                 (rdlh_ptm_sot),
    .rdlh_ptm_multi_cycle         (rdlh_ptm_multi_cycle),
    .rdlh_ptm_request             (rdlh_ptm_request),
    .rdlh_ptm_response            (rdlh_ptm_response),
    .rdlh_duplicate_tlp           (rdlh_duplicate_tlp),

    .radm_ptm_req_msg             (upstream_port ? 1'b0 : radm_ptm_req),                    //input from RADM
    .radm_ptm_res_msg             (upstream_port ? radm_ptm_res_msg : 1'b0),                   //input from RADM
    .radm_ptm_res_d_msg           (upstream_port ? radm_ptm_res_d_msg : 1'b0),                         //input from RADM
    .radm_ptm_master_time         (upstream_port ? radm_ptm_master_time : 64'b0),              //input from RADM
    .radm_ptm_prop_delay          (upstream_port ? radm_ptm_prop_delay : 32'b0),               //input from RADM

    .ptm_manual_update_pulse      (upstream_port ? ptm_manual_update_pulse : 1'b0),      //top level input
    .ptm_auto_update_signal       (upstream_port ? ptm_auto_update_signal : 1'b0),       //top level input
    .pm_linkst_in_l0              (pm_linkst_in_l0),                                     //input from pm_ctrl
    .pm_linkst_in_l0s             (pm_linkst_in_l0s),                                    //input from pm_ctrl
   

    .ptm_clock_updated            (ptm_clock_updated),
    .ptm_clock_correction         (ptm_clock_correction),
    .ptm_trigger_allowed          (ptm_trigger_allowed),          // top level output
    .ptm_updating                 (ptm_updating),
    .ptm_req_response_timeout     (ptm_req_response_timeout),     // top level output
    .ptm_req_dup_rx               (ptm_req_dup_rx),               // top level output
    .ptm_req_replay_tx            (ptm_req_replay_tx),            // top level output



     // outputs

    .ptm_request_msg              (ptm_request_msg),               // to msg_gen
    .ptm_res_msg                  (ptm_res_msg),
    .ptm_res_d_msg                (ptm_res_d_msg),
    .ptm_master_time              (ptm_master_time),
    .ptm_prop_delay               (ptm_prop_delay),

    .ptm_context_valid            (ptm_context_valid),            //top level output
    .ptm_responder_rdy_to_validate (ptm_responder_rdy_to_validate),  //top level output
    .ptm_local_clk                (ptm_local_clock),           //top level output

    .ptm_reg_data                 (ptm_vsec_reg_data[31:0])           //output to ecfg

);  //ptm_req_res






assign cfg_rasdp_error_mode_en = ras_error_mode_en;

ras_err_tracer_ctrl_s  ras_err_tracer_ctrl;
ras_err_tracer_rpt_s   ras_err_tracer_rpt;
ras_err_inj_mgr_ctrl_s ras_err_inj_mgr_ctrl;
ras_err_inj_ack_s      ras_err_inj_ack;
logic                  ras_error_tracer_fatal_error;
logic                  ras_error_tracer_pending_correctable;
logic                  ras_error_tracer_pending_err_inj_successful;
logic                  ras_err_inj_mgr_trigger_fatal_error;

ras_err_tracer
 u_ras_err_tracer (
    .core_clk                     (core_clk),
    .core_rst_n                   (non_sticky_rst_n),
    .in_ras_dp_err_log            (ras_dp_err_log),
    .ras_err_inj_ack              (ras_err_inj_ack),
    .pending_correctable          (ras_error_tracer_pending_correctable       ),
    .pending_uncorrectable        (                                           ),
    .pending_err_inj_failure      (                                           ),
    .pending_err_inj_successful   (ras_error_tracer_pending_err_inj_successful),
    .pulse_ras_dp_unc_err         (ras_dp_unc_err),
    .pulse_ras_dp_cor_err         (ras_dp_cor_err),
    .pulse_ras_ram_unc_err        (ras_ram_unc_err),
    .pulse_ras_ram_cor_err        (ras_ram_cor_err),
    .ras_error_tracer_fatal_error (ras_error_tracer_fatal_error),
    .ras_err_tracer_ctrl          (ras_err_tracer_ctrl),
    .ras_err_tracer_rpt           (ras_err_tracer_rpt)
);
assign ras_error_tracer_pending = ras_error_tracer_pending_correctable        |
                                  ras_error_tracer_fatal_error    |
                                  ras_error_tracer_pending_err_inj_successful;

ras_err_inj_mgr
 u_ras_err_inj_mgr (
    .core_clk               (core_clk),
    .core_rst_n             (non_sticky_rst_n),
    .out_ras_dp_err_inj     (ras_dp_err_inj),
    .ras_dp_err_inj_wake_up (ras_dp_err_inj_wake_up),
    .ras_err_inj_ack        (ras_err_inj_ack),
    .ras_err_inj_mgr_ctrl   (ras_err_inj_mgr_ctrl),
    .trigger_fatal_error    (ras_err_inj_mgr_trigger_fatal_error)
);

cdm_ras_reg

#(INST) u_cdm_ras_reg (
  // Inputs
    .core_clk                       (core_clk),
    .sticky_rst_n                   (sticky_rst_n),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .ecfg_write_pulse               (ecfg_write_pulse),
    .ras_reg_sel                    (ras_reg_sel),
    .ras_reg_id                     (ras_reg_id),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .upstream_port                  (upstream_port),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .ras_err_tracer_ctrl            (ras_err_tracer_ctrl),
    .ras_err_inj_mgr_ctrl           (ras_err_inj_mgr_ctrl),
  // Outputs ---------------
    .ras_reg_ack                    (ras_reg_ack),
    .ras_reg_data                   (ras_reg_data),
    .ras_error_mode_en              (ras_error_mode_en),
    .cfg_rasdp_linkdown_en          (cfg_rasdp_linkdown_en),
    .ras_error_mode_clear           (ras_error_mode_clear)
    ,
    .ras_err_tracer_rpt            (ras_err_tracer_rpt)
) ;


rasdp_error_mode_control
 #(
    .CORR_ERROR_WD   (CORR_ERROR_WD),
    .UNCORR_ERROR_WD (UNCORR_ERROR_WD)
    ) u_rasdp_error_mode_control  (
    .core_clk                     (core_clk),
    .non_sticky_rst_n             (non_sticky_rst_n), // Non-sticky Reset, for rasdp_linkdown and cfg_rasdp_error_mode outputs
    .sticky_rst_n                 (sticky_rst_n), // Sticky Reset, for rasdp_int_uncorr_error and rasdp_int_corr_error outputs

    .cfg_rasdp_error_mode_en      (ras_error_mode_en),
    .cfg_rasdp_linkdown_en        (cfg_rasdp_linkdown_en),
    .ras_clear_nullification_flag (ras_error_mode_clear),
    .rasdp_err_uncorr             (ras_error_tracer_fatal_error),
    .trigger_fatal_error          (ras_err_inj_mgr_trigger_fatal_error),
    .rasdp_err_corr               (ras_error_tracer_pending_correctable),
    .cfg_rasdp_error_mode         (cfg_rasdp_error_mode),
    .rasdp_linkdown               (rasdp_linkdown),
    .rasdp_int_uncorr_error       (rasdp_int_uncorr_error),
    .rasdp_int_corr_error         (rasdp_int_corr_error)
    );



assign or_rasdp_err_uncorr = ras_error_tracer_fatal_error;
assign or_rasdp_err_corr   = ras_error_tracer_pending_correctable;





cdm_vsecdma_reg

#(INST) u_cdm_vsecdma_reg (
  // Inputs
    .core_clk                       (core_clk),
    .sticky_rst_n                   (sticky_rst_n),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .vsecdma_write_pulse            (ecfg_write_pulse),
    .vsecdma_reg_id                 (vsecdma_reg_id),
    .vsecdma_reg_sel                (vsecdma_reg_sel),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),

    .upstream_port                  (upstream_port),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
  // Outputs ---------------
    .vsecdma_reg_data               (vsecdma_reg_data)
) ;

// Secondary PCI Extended Capabilities.
// NOTE: A single instantiation is shared across all functions
    // gen6 spec says: 64.0 GT/s equalization from 64.0 GT/s is not supported.
    //speed changed to Gen5 and redo for Gen6 is initiated.
wire smlh_ls2_g4_eq_enter_int = smlh_ls2_g4_eq_enter_i | smlh_ls2_g5_eq_enter | smlh_ls2_g6_eq_enter;

wire [3:0] spcie_write_pulse_rcrb_pcie = cxl_rcrb_enable ? ecfg_rcrb_write_pulse : ecfg_write_pulse[0];

cdm_spcie_reg

#(INST,0) u_cdm_spcie_reg (
    // Inputs
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .spcie_write_pulse              (spcie_write_pulse_rcrb_pcie), //Only use function 0
    .spcie_reg_id                   (spcie_reg_id[NSPCIE-1:0]), //Only use function 0
    .upstream_port                  (upstream_port),
    .rmlh_lane_err                  (rmlh_lane_err),
    .smlh_lec_pset_ltx              (smlh_lec_pset_ltx),
    .smlh_lec_pset_lrx              (smlh_lec_pset_lrx),
    .smlh_ls2_eq_enter              (smlh_ls2_eq_enter_i),
    .smlh_ls2_g4_eq_enter           (smlh_ls2_g4_eq_enter_int),
    .cfg_pcie_crosslink_supported   (cfg_pcie_crosslink_supported),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .device_type                    (device_type),
    .cxl_rcrb_enable                (cxl_rcrb_enable),

    // Outputs --
    .spcie_reg_data                 (spcie_reg_data),
    .cfg_perform_eq                 (cfg_perform_eq),
    .cfg_link_eq_req_int_en         (cfg_link_eq_req_int_en),
    .cfg_lec_pset_ltx               (cfg_lec_pset_ltx),
    .cfg_lec_pset_lrx               (cfg_lec_pset_lrx),
    .cfg_lec_pset_rtx               (cfg_lec_pset_rtx),
    .cfg_lec_pset_rrx               (cfg_lec_pset_rrx)
); // cdm_spcie_reg



assign cxl_reg_data[0]                   = cxl_reg_data_0;
assign cxl_reg_locator_reg_data[0]       = cxl_reg_locator_reg_data_0;
assign cxl_2_0_comp_reg_offset_in[0]     = cxl_2_0_comp_reg_offset[0];
assign cxl_gpf_device_reg_data[0]        = cxl_gpf_device_reg_data_0;

generate
for (genvar f=1; f<NF; f = f+1) begin : gen_cdm_sld_reg_data_proc
    assign cxl_reg_data[f]               = cxl_reg_data[0];
    assign cxl_reg_locator_reg_data[f]   = cxl_reg_locator_reg_data[0];
    assign cxl_2_0_comp_reg_offset_in[f] = cxl_2_0_comp_reg_offset_in[0];
    assign cxl_gpf_device_reg_data[f]    = cxl_gpf_device_reg_data[0];
end // for (f=1; f<NF; f = f+1) begin : gen_cdm_sld_reg_data_proc
endgenerate





// Physical Layer 16.0 GT/s Extended Capabilities.
// NOTE: A single instantiation is shared across all functions
wire [3:0] pl16g_write_pulse_rcrb_pcie = cxl_rcrb_enable ? ecfg_rcrb_write_pulse : ecfg_write_pulse[0];

cdm_pl16g_reg

#(INST,0) u_cdm_pl16g_reg (
    // Inputs
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .pl16g_write_pulse              (pl16g_write_pulse_rcrb_pcie), //Only use function 0
    .pl16g_reg_id                   (pl16g_reg_id[NPL16G-1:0]), //Only use function 0
    .upstream_port                  (upstream_port),
    .cfg_pcie_crosslink_supported   (cfg_pcie_crosslink_supported),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .device_type                    (device_type),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_ls2_g4_eq_req             (smlh_ls2_g4_eq_req),
    .smlh_ls2_g4_eq_success         (smlh_ls2_g4_eq_success[3:1]),
    .smlh_ls2_g4_eq_cmpl            (smlh_ls2_g4_eq_cmpl),
    .smlh_ls2_g4_eq_enter           (smlh_ls2_g4_eq_enter_i),
    .smlh_lec_g4_pset_ltx           (smlh_lec_g4_pset_ltx),
    .rmlh_deskew_ctlskp_err         (rmlh_deskew_ctlskp_err),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    // Outputs --
    .pl16g_reg_data                 (pl16g_reg_data),
    .cfg_ls2_g4_eq_req              (int_cfg_ls2_g4_eq_req),  // Function 0 Only
    .cfg_lec_g4_pset_ltx            (cfg_lec_g4_pset_ltx),
    .cfg_lec_g4_pset_rtx            (cfg_lec_g4_pset_rtx)
); // cdm_pl16g_reg

assign cfg_lec_g4_pset_lrx = {(NL*RX_PSET_WD){1'b0}};
assign cfg_lec_g4_pset_rrx = {(NL*RX_PSET_WD){1'b0}};


// Physical Layer 32.0 GT/s Extended Capabilities.
// NOTE: A single instantiation is shared across all functions

wire cfg_mod_ts_pcie_support;
wire [3:0] pl32g_write_pulse_rcrb_pcie = cxl_rcrb_enable ? ecfg_rcrb_write_pulse : ecfg_write_pulse[0];

cdm_pl32g_reg

#(INST,0) u_cdm_pl32g_reg (
    // Inputs
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .sticky_rst_n                   (sticky_rst_n),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .pl32g_write_pulse              (pl32g_write_pulse_rcrb_pcie),
    .pl32g_reg_id                   (pl32g_reg_id[NPL32G-1:0]),
    .upstream_port                  (upstream_port),
    .cfg_pcie_crosslink_supported   (cfg_pcie_crosslink_supported),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .device_type                    (device_type),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_ls2_g5_eq_req             (smlh_ls2_g5_eq_req),
    .smlh_ls2_g5_eq_success         (smlh_ls2_g5_eq_success[3:1]),
    .smlh_ls2_g5_eq_cmpl            (smlh_ls2_g5_eq_cmpl),
    .smlh_ls2_g5_eq_enter           (smlh_ls2_g5_eq_enter),
    .smlh_lec_g5_pset_ltx           (smlh_lec_g5_pset_ltx),
    .rmlh_deskew_ctlskp_err         (rmlh_deskew_ctlskp_err),
    .smlh_mod_ts_rcvd               (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd               (mod_ts_data_rcvd),
    .mod_ts_data_sent               (mod_ts_data_sent),
    .smlh_elbc_rcvd                 (smlh_elbc_rcvd),
    .smlh_tx_precoding_on           (smlh_tx_precoding_on),
    .smlh_noeq_needed_rcvd          (smlh_noeq_needed_rcvd),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    // Outputs --
    .pl32g_reg_data                 (pl32g_reg_data),
    .cfg_mod_ts_pcie_support        (cfg_mod_ts_pcie_support),
    .cfg_bypass_eq_enable           (cfg_bypass_eq_enable),
    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable),
    .cfg_no_eq_needed_enable        (cfg_no_eq_needed_enable),
    .cfg_tx_precode_req             (cfg_tx_precode_req),
    .cfg_lec_g5_pset_ltx            (cfg_lec_g5_pset_ltx),
    .cfg_lec_g5_pset_rtx            (cfg_lec_g5_pset_rtx),
    .cfg_ls2_g5_eq_req              (int_cfg_ls2_g5_eq_req)  // Function 0 Only

); // cdm_pl32g_reg

wire [NL*RX_PSET_WD-1:0] cfg_lec_g5_pset_lrx;
wire [NL*RX_PSET_WD-1:0] cfg_lec_g5_pset_rrx;
assign cfg_lec_g5_pset_lrx = {(NL*RX_PSET_WD){1'b0}};
assign cfg_lec_g5_pset_rrx = {(NL*RX_PSET_WD){1'b0}};


// Physical Layer 64.0 GT/s Extended Capabilities.
// NOTE: A single instantiation is shared across all functions

wire [3:0] pl64g_write_pulse_rcrb_pcie = cxl_rcrb_enable ? ecfg_rcrb_write_pulse : ecfg_write_pulse[0];

cdm_pl64g_reg

#(INST,0) u_cdm_pl64g_reg (
    // Inputs
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .pl64g_write_pulse              (pl64g_write_pulse_rcrb_pcie),
    .pl64g_reg_id                   (pl64g_reg_id[NPL64G-1:0]),
    .upstream_port                  (upstream_port),
    .cfg_pcie_crosslink_supported   (cfg_pcie_crosslink_supported),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .device_type                    (device_type),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_ls2_g6_eq_req             (smlh_ls2_g6_eq_req),
    .smlh_ls2_g6_eq_success         (smlh_ls2_g6_eq_success[3:1]),
    .smlh_ls2_g6_eq_cmpl            (smlh_ls2_g6_eq_cmpl),
    .smlh_ls2_g6_eq_enter           (smlh_ls2_g6_eq_enter),
    .smlh_g6_tx_precoding_on        (smlh_g6_tx_precoding_on),
    .smlh_noeq_needed_rcvd          (smlh_noeq_needed_rcvd),
    .smlh_lec_g6_pset_ltx           (smlh_lec_g6_pset_ltx),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    // Outputs --
    .pl64g_reg_data                 (pl64g_reg_data),
    .cfg_g6_tx_precode_req          (cfg_g6_tx_precode_req),
    .cfg_lec_g6_pset_ltx            (cfg_lec_g6_pset_ltx),
    .cfg_lec_g6_pset_rtx            (cfg_lec_g6_pset_rtx),
    .cfg_ls2_g6_eq_req              (int_cfg_ls2_g6_eq_req)  // Function 0 Only

); // cdm_pl64g_reg

//wire [NL*RX_PSET_WD-1:0] cfg_lec_g6_pset_lrx;
//wire [NL*RX_PSET_WD-1:0] cfg_lec_g6_pset_rrx;
//assign cfg_lec_g6_pset_lrx = {(NL*RX_PSET_WD){1'b0}};
//assign cfg_lec_g6_pset_rrx = {(NL*RX_PSET_WD){1'b0}};


// Margining Extended Capabilities.
// NOTE: A single instantiation is shared across all functions
wire [3:0] margin_write_pulse_rcrb_pcie = cxl_rcrb_enable ? ecfg_rcrb_write_pulse : ecfg_write_pulse[0];

cdm_margin_reg

#(INST,0) u_cdm_margin_reg (
    // Inputs
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .margin_write_pulse             (margin_write_pulse_rcrb_pcie), //Only use function 0
    .margin_reg_id                  (margin_reg_id[NMARGIN-1:0]), //Only use function 0
    .upstream_port                  (upstream_port),
    .cfg_pcie_crosslink_supported   (cfg_pcie_crosslink_supported),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .device_type                    (device_type),
    .rdlh_link_up                   (rdlh_link_up),
    .smlh_margin_status_valid       (smlh_margin_status_valid),
    .smlh_margin_status             (smlh_margin_status),
    .smlh_margin_ready              (smlh_margin_ready),
    .app_margining_ready            (app_margining_ready),
    .app_margining_software_ready   (app_margining_software_ready),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    // Outputs --
    .margin_reg_data                (margin_reg_data),
    .cfg_margin_control             (cfg_margin_control)
); // cdm_margin_reg

// L1 Substates Extended Capabilities.
// NOTE: A single instantiation is shared across all functions
wire [3:0] l1sub_write_pulse_rcrb_pcie = cxl_rcrb_enable ? ecfg_rcrb_write_pulse : ecfg_write_pulse[0];

cdm_l1sub_reg

#( .INST (INST),
   .FUNC_NUM (0)
 ) u_cdm_l1sub_reg (
    // Inputs
    .core_clk                       (core_clk),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .l1sub_write_pulse              (l1sub_write_pulse_rcrb_pcie), //Only use function 0
    .l1sub_reg_id                   (l1sub_reg_id[NL1SUB-1:0]), //Only use function 0
    .upstream_port                  (upstream_port),
    .cfg_ltr_m_en                   (cfg_ltr_m_en),
    .app_ltr_latency                (app_ltr_latency[31:0]),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .device_type                    (device_type),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    // Outputs --
    .cfg_l1sub_control              (cfg_l1sub_control),
    .cfg_l1sub_en                   (cfg_l1sub_en),
    .l1sub_reg_data                 (l1sub_reg_data)
); // cdm_l1sub_reg




// -----------------------------------------------------------------------------
// PL registers
// Note: some register are only used for L2+L1 package without cfgm_cfg_reg module
// they are duplicated at PCI-E config space
// -----------------------------------------------------------------------------
cdm_pl_reg

#(
  .INST (INST),
  .FUNC_NUM(0)
  ) u_cdm_pl_reg (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .sticky_rst_n                   (sticky_rst_n),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .cdm_clk_g                      (cdm_clk_g_int),
    .app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable),
    .lbc_cdm_addr                   (lbc_cdm_addr[11:0]),
    .pl_reg_sel                     (pl_reg_sel),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .upstream_port                  (upstream_port),
    .phy_cfg_status                 (phy_cfg_status),
    .cxpl_debug_info                (cxpl_debug_info),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .cfg_max_payload_size           (cfg_max_payload_size_out_rx),
    .cfg_min_payload_size           (cfg_max_payload_size_out_rx),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .xtlh_xadm_ph_cdts              (xtlh_xadm_ph_cdts),
    .xtlh_xadm_pd_cdts              (xtlh_xadm_pd_cdts),
    .xtlh_xadm_nph_cdts             (xtlh_xadm_nph_cdts),
    .xtlh_xadm_npd_cdts             (xtlh_xadm_npd_cdts),
    .xtlh_xadm_cplh_cdts            (xtlh_xadm_cplh_cdts),
    .xtlh_xadm_cpld_cdts            (xtlh_xadm_cpld_cdts),
    .radm_qoverflow                 (radm_qoverflow),
    .radm_q_not_empty               (radm_q_not_empty),
    .radm_formq_read_err            (radm_formq_read_err),
    .radm_formq_overflow            (radm_formq_overflow),
    .radm_formq_not_empty           (radm_formq_not_empty),
    .xdlh_retrybuf_not_empty        (xdlh_retrybuf_not_empty),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn),



    .smlh_core_rst_n_release_pulse  (smlh_core_rst_n_release_pulse),
    .smlh_dir_spd_chg_rising_edge   (smlh_dir_spd_chg_rising_edge),
    .smlh_dir_linkw_chg_started     (smlh_dir_linkw_chg_started),

//`ifdef CX_GEN2_SPEED
    .current_data_rate              (current_data_rate),
//`endif
     .msg_ltr_det               (msg_ltr_det),
     .msg_ltr_latency           (msg_ltr_latency),

    .cfg_ext_synch                  (cfg_ext_synch),

    .or_rasdp_err_uncorr            (or_rasdp_err_uncorr),
    .or_rasdp_err_corr              (or_rasdp_err_corr),
    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),
    .cxl_vlsm_state                           (cxl_pl_reg_vlsm_state),
    .cxl_cache_mem_vlsm_state                 (cxl_pl_reg_cache_mem_vlsm_state),
    .cxl_io_vlsm_state                        (cxl_pl_reg_io_vlsm_state),
    .cxl_mc_almp_unexp_error                  (cxl_pl_reg_mc_almp_unexp_error),
    .cxl_io_almp_unexp_error                  (cxl_pl_reg_io_almp_unexp_error),
    .cxl_lrsm_state                           (cxl_pl_reg_lrsm_state  ),
    .cxl_lrsm_fatal_error                     (cxl_pl_reg_lrsm_fatal_error         ),
    .cxl_fatal_error                          (cxl_pl_reg_fatal_error              ),
    .cxl_viral_status_set                     (pl_reg_viral_status_set),
    .cxl_viral_status                         (cfg_cxl_pl_reg_viral_status),
    .cm_ll_cache_poison_injection_busy    (cxl_pl_reg_cm_ll_cache_poison_injection_busy),
    .cm_ll_mem_poison_injection_busy      (cxl_pl_reg_cm_ll_mem_poison_injection_busy),
    .cm_ll_io_poison_injection_busy       (cxl_pl_reg_cm_ll_io_poison_injection_busy),
    .cm_ll_cache_mem_crc_injection_busy   (cxl_pl_reg_cm_ll_cache_mem_crc_injection_busy),
    .io_ll_io_poison_injection_busy       (cxl_pl_reg_io_ll_io_poison_injection_busy),
    .io_ll_flow_ctrl_error_injection_busy (cxl_pl_reg_io_ll_flow_ctrl_error_injection_busy),
    .fb_phy_protid_injection_busy         (cxl_pl_reg_fb_phy_protid_injection_busy),
    .rmlh_prbs_done                        (rmlh_prbs_done),
    .rmlh_prbs_fail                        (rmlh_prbs_fail),
    .rmlh_prbs_started               (rmlh_prbs_started),
    .rmlh_prbs_err_cntr              (rmlh_prbs_err_cntr),
    .rmlh_prbs_unexp_fail            (rmlh_prbs_unexp_fail),
// ---------- Outputs --------

    .cfg_pl_gen3_control            (cfg_pl_gen3_control),
    .cfg_pl_gen3_eq_control         (cfg_pl_gen3_eq_control),
    .cfg_fdbk_dirchange_control     (cfg_fdbk_dirchange_control),
    .cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl),
    .cfg_no_seed_value_change       (cfg_no_seed_value_change),
    .cfg_pl_gen4_control            (cfg_pl_gen4_control),
    .cfg_pl_gen4_eq_control         (cfg_pl_gen4_eq_control),
    .cfg_gen4_fdbk_dirchange_control (cfg_gen4_fdbk_dirchange_control),
    .cfg_pl_gen5_control            (cfg_pl_gen5_control),
    .cfg_pl_gen5_eq_control         (cfg_pl_gen5_eq_control),
    .cfg_gen5_fdbk_dirchange_control (cfg_gen5_fdbk_dirchange_control),
    .cfg_pl_gen6_control            (cfg_pl_gen6_control),
    .cfg_pl_gen6_eq_control         (cfg_pl_gen6_eq_control),
    .cfg_gen6_fdbk_dirchange_control (cfg_gen6_fdbk_dirchange_control),
    .cfg_pl_multilane_control       (cfg_pl_multilane_control),
    .cfg_pl_l1sub_control           (cfg_pl_l1sub_control),
    .cfg_pl_l1_exit_mode            (cfg_pl_l1_exit_mode),
    .cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1),
    .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
    .cfg_p2nobeacon_enable          (cfg_p2nobeacon_enable),
    .cfg_pipe_optional_pclkchange_hs(cfg_pipe_optional_pclkchange_hs),
    .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
    .cfg_phy_rst_timer              (cfg_phy_rst_timer),
    .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
    .cfg_dsp_pcipm_l1_enter_delay   (cfg_dsp_pcipm_l1_enter_delay),
    .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
    .cfg_gen2_n_fts                 (cfg_gen2_n_fts),
    .cfg_directed_speed_change      (cfg_directed_speed_change),
    .cfg_phy_txswing                (cfg_phy_txswing),
    .cfg_tx_compliance_rcv          (cfg_tx_compliance_rcv),
    .cfg_up_sel_deemph              (cfg_up_sel_deemph),
    .cfg_lane_en                    (cfg_lane_en),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_link_dis                   (),
    .cfg_link_rate                  (),
    .cfg_crs_sw_vis_en              (cfg_crs_sw_vis_en), // Input
    .cfg_err_resp                   (cfg_err_resp),
    .cfg_auto_flush_en              (cfg_auto_flush_en),
    .cfg_auto_flush_timeout         (cfg_auto_flush_timeout),
    .cfg_link_timeout_en_n          (cfg_link_timeout_en_n),
    .cfg_link_timeout_period        (cfg_link_timeout_period),
    .cfg_ax_mstr_ordr_p_event_sel   (cfg_ax_mstr_ordr_p_event_sel),
    .cfg_ax_snp_en                  (cfg_ax_snp_en),
    .cfg_ib_p_id_mng_ctrl           (cfg_ib_p_id_mng_ctrl),
    .cfg_mstr_arcache_mode          (cfg_mstr_arcache_mode),
    .cfg_mstr_awcache_mode          (cfg_mstr_awcache_mode),
    .cfg_mstr_arcache_value         (cfg_mstr_arcache_value),
    .cfg_mstr_awcache_value         (cfg_mstr_awcache_value),
    .cfg_aximstr_msg_addr_low       (cfg_aximstr_msg_addr_low),
    .cfg_aximstr_msg_addr_high      (cfg_aximstr_msg_addr_high),
    .cfg_mstr_ardomain_mode         (cfg_mstr_ardomain_mode),
    .cfg_mstr_awdomain_mode         (cfg_mstr_awdomain_mode),
    .cfg_mstr_ardomain_value        (cfg_mstr_ardomain_value),
    .cfg_mstr_awdomain_value        (cfg_mstr_awdomain_value),
    .cfg_ax_mstr_zeroread_fw        (cfg_ax_mstr_zeroread_fw),
    .cfg_memtype_value              (cfg_memtype_value),
    .cfg_memtype_boundary           (cfg_memtype_boundary),
    .cfg_ack_freq                   (cfg_ack_freq),
    .cfg_ack_latency_timer          (cfg_ack_latency_timer),
    .cfg_replay_timer_value         (cfg_replay_timer_value),
    .cfg_fc_latency_value           (cfg_fc_latency_value ),
    .cfg_other_msg_payload          (cfg_other_msg_payload),
    .cfg_other_msg_request          (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern        (cfg_corrupt_crc_pattern),
    .cfg_scramble_dis               (cfg_scramble_dis),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_pipe_loopback              (cfg_pipe_loopback),
    .cfg_rxstatus_lane              (cfg_rxstatus_lane),
    .cfg_rxstatus_value             (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid               (cfg_lpbk_rxvalid),
    .cfg_plreg_reset                (cfg_plreg_reset),
    .cfg_link_num                   (cfg_link_num),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_forced_link_state          (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),

    .cfg_force_en                   (cfg_force_en),
    .cfg_lane_skew                  (cfg_lane_skew),
    .cfg_drift_buffer_deskew_enable (cfg_drift_buffer_deskew_enable),
    .cfg_deskew_disable             (cfg_deskew_disable),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_flow_control_disable       (cfg_flow_control_disable),
    .cfg_acknack_disable            (cfg_acknack_disable),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_xmt_beacon                 (),
    .cfg_tx_reverse_lanes           (cfg_tx_reverse_lanes),
    .cfg_eidle_timer                (cfg_eidle_timer),
    .cfg_skip_interval              (cfg_skip_interval),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor   (cfg_fast_link_scaling_factor),
    .cfg_dll_lnk_en                 (cfg_dll_lnk_en),
    .pl_reg_data                    (pl_reg_data),
    .pl_reg_ack                     (pl_reg_ack),
    .cfg_phy_control                (cfg_phy_control),
    .cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer),
    .cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl),
    .cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer),
    .cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s),
    .cfg_aspm_l1_timer_enable       (cfg_aspm_l1_timer_enable),
    .cfg_filter_rule_mask           (cfg_filter_rule_mask),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_lpvc_wrr_weight            (cfg_lpvc_wrr_weight),
    .cfg_max_func_num               (cfg_max_func_num),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .cfg_radm_q_mode                (cfg_radm_q_mode),
    .cfg_radm_order_rule            (cfg_radm_order_rule),
    .cfg_order_rule_ctrl            (cfg_order_rule_ctrl),
    .cfg_clock_gating_ctrl          (cfg_clock_gating_ctrl),
    .cfg_trgt_cpl_lut_delete_entry  (cfg_trgt_cpl_lut_delete_entry),
    .cfg_radm_strict_vc_prior       (cfg_radm_strict_vc_prior),
    .hdr_scale_p                    (hdr_scale_p),
    .data_scale_p                   (data_scale_p),
    .hdr_scale_np                   (hdr_scale_np),
    .data_scale_np                  (data_scale_np),
    .hdr_scale_cpl                  (hdr_scale_cpl),
    .data_scale_cpl                 (data_scale_cpl),
     .app_ltr_latency               (app_ltr_latency),
     .cdmpl2cfg_ltr_rq              (cdmpl2cfg_ltr_rq),
     .cfg_disable_ltr_clr_msg       (cfg_disable_ltr_clr_msg),
    .cfg_hq_depths                  (cfg_hq_depths),
    .cfg_dq_depths                  (cfg_dq_depths),
    .cfg_gen3_eq_fs_lf              (cfg_gen3_eq_fs_lf),
    .cfg_gen3_eq_coef               (cfg_gen3_eq_coef),
    .cfg_gen4_eq_fs_lf              (cfg_gen4_eq_fs_lf),
    .cfg_gen4_eq_coef               (cfg_gen4_eq_coef),
    .cfg_gen5_eq_fs_lf              (cfg_gen5_eq_fs_lf),
    .cfg_gen5_eq_coef               (cfg_gen5_eq_coef),
    .cfg_gen6_eq_fs_lf              (cfg_gen6_eq_fs_lf),
    .cfg_gen6_eq_coef               (cfg_gen6_eq_coef),
    .target_mem_map                 (target_mem_map),
    .target_rom_map                 (target_rom_map),
    .cfg_margin_num_timing_steps          (cfg_margin_num_timing_steps),
    .cfg_margin_max_timing_offset         (cfg_margin_max_timing_offset),
    .cfg_margin_num_voltage_steps         (cfg_margin_num_voltage_steps),
    .cfg_margin_max_voltage_offset        (cfg_margin_max_voltage_offset),
    .cfg_margin_sample_rate_voltage       (cfg_margin_sample_rate_voltage),
    .cfg_margin_sample_rate_timing        (cfg_margin_sample_rate_timing),
    .cfg_margin_maxlanes                  (cfg_margin_maxlanes),
    .cfg_margin_voltage_supported         (cfg_margin_voltage_supported),
    .cfg_margin_ind_up_down_voltage       (cfg_margin_ind_up_down_voltage),
    .cfg_margin_ind_left_right_timing     (cfg_margin_ind_left_right_timing),
    .cfg_margin_sample_reporting_method   (cfg_margin_sample_reporting_method),
    .cfg_margin_ind_error_sampler         (cfg_margin_ind_error_sampler),
    .cfg_rx_message_bus_write_buffer_depth (cfg_rx_message_bus_write_buffer_depth),
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode),
    .cfg_pam4_restricted_levels_requirement (cfg_pam4_restricted_levels_requirement),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .default_target                 (default_target),
    .cfg_cfg_tlp_bypass_en          (cfg_cfg_tlp_bypass_en),
    .cfg_config_limit               (cfg_config_limit),
    .cfg_target_above_config_limit  (cfg_target_above_config_limit),
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),
    .cfg_ras_reg_pf0_only           (cfg_ras_reg_pf0_only),
    .cfg_rasdes_reg_pf0_only        (cfg_rasdes_reg_pf0_only),
    .ur_ca_mask_4_trgt1             (ur_ca_mask_4_trgt1)

    ,
    .cfg_nond0_vdm_block            (cfg_nond0_vdm_block),
    .cfg_client0_block_new_tlp      (cfg_client0_block_new_tlp),
    .cfg_client1_block_new_tlp      (cfg_client1_block_new_tlp),
    .cfg_client2_block_new_tlp      (cfg_client2_block_new_tlp)
    ,
    .pm_powerdown_status          (pm_powerdown_status),
    .cfg_force_powerdown          (cfg_force_powerdown)
   ,
   .cxl_vlsm_pm_enable                 (cxl_pl_reg_vlsm_pm_enable),
   .cxl_apn_bypass_enable              (cxl_pl_reg_apn_bypass_enable),
   .cxl_apn_sw_mode                    (cxl_pl_reg_apn_sw_mode),
   .cxl_vlsm_to_active                 (cxl_pl_reg_vlsm_to_active),
   .cxl_max_num_retry                  (cxl_pl_reg_max_num_retry),
   .cxl_max_num_reinit                 (cxl_pl_reg_max_num_reinit),
   .cxl_lrsm_timeout_threshold         (cxl_pl_reg_lrsm_timeout_threshold),
   .cxl_crc_threshold                  (cxl_pl_reg_crc_threshold),
   .cxl_ras_uncorr_err                 (cxl_pl_reg_ras_uncorr_err),
   .cxl_fatal_error_reg                (cxl_fatal_error_reg),
   .cm_ll_cache_poison_injection_start   (cxl_pl_reg_cm_ll_cache_poison_injection_start),
   .cm_ll_mem_poison_injection_start     (cxl_pl_reg_cm_ll_mem_poison_injection_start),
   .cm_ll_io_poison_injection_start      (cxl_pl_reg_cm_ll_io_poison_injection_start),
   .cm_ll_cache_mem_crc_injection        (cxl_pl_reg_cm_ll_cache_mem_crc_injection),
   .cm_ll_cache_mem_crc_injection_count  (cxl_pl_reg_cm_ll_cache_mem_crc_injection_count),
   .io_ll_io_poison_injection_start      (cxl_pl_reg_io_ll_io_poison_injection_start),
   .io_ll_flow_ctrl_error_injection      (cxl_pl_reg_io_ll_flow_ctrl_error_injection),
   .fb_phy_cor_protid_error_injection    (cxl_pl_reg_fb_phy_cor_protid_error_injection),
   .fb_phy_uncor_protid_error_injection  (cxl_pl_reg_fb_phy_uncor_protid_error_injection),
   .fb_phy_unexp_protid_error_injection  (cxl_pl_reg_fb_phy_unexp_protid_error_injection)

   ,.cfg_optional_ohc              (cfg_optional_ohc)
    ,.cfg_utility                  (cfg_utility)
    ,.pm_cfg_utility               (pm_cfg_utility)
    ,
    .cfg_dbi_func_bank_select     (cfg_dbi_func_bank_select)
    ,.cfg_err_inj_wr_disable      (cfg_err_inj_wr_disable)
    ,.cfg_l0p_priority                         (int_cfg_l0p_normal_priority)
    ,.cfg_aspm_l0p_dynamic_disable             (int_cfg_aspm_l0p_dynamic_disable)            
    ,.cfg_direct_l0p_dynamic_link_width_change (int_cfg_direct_l0p_dynamic_link_width_change)
    ,.cfg_l0p_dynamic_target_link_width        (int_cfg_l0p_dynamic_target_link_width)
    ,.cfg_l0p_dynamic_priority                 (int_cfg_l0p_dynamic_priority)
    ,.l0p_dynamic_write                        (l0p_dynamic_write)
    ,.rc_device                                (rc_device)
    ,.cfg_prbs_en                  (cfg_prbs_en)
    ,.clear_prbs_done              (clear_prbs_done)
    ,.cfg_prbs_lane_sel            (cfg_prbs_lane_sel)
    ,.cfg_flit_err_inj_latency    (cfg_flit_err_inj_latency_pl_reg)
     ,.cfg_tx_throttling          (cfg_tx_throttling)
    ,.cfg_tx_arb_control          (cfg_tx_arb_control)
);  // u_cdm_pl_reg



// -----------------------------------------------------------------------------
// RAD D.E.S registers
// -----------------------------------------------------------------------------
cdm_rasdes_reg
  #(
    .INST       (INST)
  ) u_cdm_rasdes_reg (
// -------------- Inputs ---------------
    .aux_clk                                 (core_clk) ,                           // input
    .sticky_rst_n                            (sticky_rst_n) ,                      // input
 // --- Register access signals
    .lbc_cdm_data                            (lbc_cdm_data),                       // input  [31:0]
    .lbc_cdm_dbi                             (lbc_cdm_dbi),                        // input
    .ecfg_write_pulse                        (ecfg_write_pulse),                   // input  [4*NF-1:0]
    .rasdes_reg_sel                          (rasdes_reg_sel),                     // input  [NF-1:0]
    .rasdes_reg_id                           (rasdes_reg_id),                      // input  [(64*NF)-1:0]
    .dbi_ro_wr_en                            (dbi_ro_wr_en),                       // input
    .cfg_err_inj_wr_disable                  (cfg_err_inj_wr_disable),             // input
//---- RAM I/F -----------------------
    .cdm_ras_des_ec_ram_dataout              (cdm_ras_des_ec_ram_dataout),         // input  [RASDES_EC_RAM_DATA_WIDTH-1:0]
    .cdm_ras_des_tba_ram_dataout             (cdm_ras_des_tba_ram_dataout),        // input  [RASDES_TBA_RAM_DATA_WIDTH-1:0]
// --- Event counter signals
    .rmlh_ebuf_rxoverflow                    (rmlh_ebuf_rxoverflow),               // input  [NL-1:0]
    .rmlh_ebuf_rxunderflow                   (rmlh_ebuf_rxunderflow),              // input  [NL-1:0]
    .rmlh_phy_rxcodeerror                    (rmlh_phy_rxcodeerror),               // input  [NL-1:0]
    .rmlh_phy_rxdisperror                    (rmlh_phy_rxdisperror),               // input  [NL-1:0]
    .rmlh_skp_parity_err                     (rmlh_skp_parity_err),                // input  [NL-1:0]
    .rmlh_sync_header_err                    (rmlh_sync_header_err),               // input  [NL-1:0]
    .rmlh_rxvalid_deasserted                 (rmlh_rxvalid_deasserted),            // input  [NL-1:0]
    .rmlh_deskew_ctlskp_err                  (rmlh_deskew_ctlskp_err),             // input  [NL*5-1:0]
    .rmlh_rcvd_err                           (rmlh_rcvd_err),                      // input
    .rmlh_framing_err                        (rmlh_framing_err),                   // input
    .rmlh_framing_err_l0                     (rmlh_framing_err_l0),                // input
    .rmlh_deskew_alignment_err               (rmlh_deskew_alignment_err),          // input
    .rmlh_rxskipadded                        (rmlh_rxskipadded),                   // input  [NL-1:0]
    .rmlh_rxskipremoved                      (rmlh_rxskipremoved),                 // input  [NL-1:0]
    .cfg_poisned_tlp                         (cfg_poisned_tlp),                    // input  [ERROR_TLP_WD:0]
    .cfg_ecrc_tlp_err                        (cfg_ecrc_tlp_err),                   // input  [ERROR_TLP_WD:0]
    .cfg_ur_tlp                              (cfg_ur_tlp),                         // input  [ERROR_TLP_WD:0]
    .cfg_ca_tlp                              (cfg_ca_tlp),                         // input  [ERROR_TLP_WD:0]
    .cfg_cpl_timeout                         (cfg_cpl_timeout),                    // input  [1:0]
    .smlh_eidle_inferred_in_l0               (smlh_eidle_inferred_in_l0),          // input
    .smlh_rx_rcvry_req                       (smlh_rx_rcvry_req),                  // input
    .smlh_timeout_nfts                       (smlh_timeout_nfts),                  // input
    .smlh_l0_to_recovery                     (smlh_l0_to_recovery),                // input
    .smlh_l1_to_recovery                     (smlh_l1_to_recovery ),               // input
    .smlh_in_l0s                             (smlh_in_l0s),                        // input
    .smlh_in_rl0s                            (smlh_in_rl0s),                       // input
    .smlh_in_l0                              (smlh_in_l0),
    .smlh_ltssm_in_l0p                       (smlh_ltssm_in_l0p),                  // input
    .smlh_link_in_training                   (smlh_link_in_training),
    .smlh_rcv_eios_when_l0s_unsprt           (smlh_rcv_eios_when_l0s_unsprt),      // input
    .smlh_deskew_uncomplete_err              (smlh_deskew_uncomplete_err),         // input
    .cxl_almp_rx_repl_error                  (cxl_almp_rx_repl_error),             // input
    .cxl_vlsm_unexp_error                    (cxl_vlsm_unexp_error),               // input
    .cxl_vlsm_lrsm_req_retrain               (cxl_vlsm_lrsm_req_retrain),          // input
    .pm_asnak                                (pm_asnak),                           // input
    .smlh_in_l1                              (smlh_in_l1),                         // input
    .l1sub_state                             (l1sub_state),                        // input  [2:0]
    .pm_in_l11                               (pm_in_l11),                          // input
    .pm_in_l12                               (pm_in_l12),                          // input
    .pm_in_l1_short                          (pm_in_l1_short),                     // input
    .pm_in_l1_cpm                            (pm_in_l1_cpm),                       // input
    .pm_in_l1_abort                          (pm_in_l1_abort),                     // input
    .smlh_in_l23                             (smlh_in_l23),                        // input
    .smlh_spd_change                         (smlh_spd_change),                    // input
    .smlh_lwd_change                         (smlh_lwd_change),                    // input
    .rdlh_bad_tlp_err_pertlp                 (rdlh_bad_tlp_err_pertlp),            // input  [RX_TLP-1:0]
    .rdlh_lcrc_tlp_err_pertlp                (rdlh_lcrc_tlp_err_pertlp),           // input  [RX_TLP-1:0]
    .rdlh_nulified_tlp_err_pertlp            (rdlh_nulified_tlp_err_pertlp),       // input  [RX_TLP-1:0]
    .rdlh_duplicate_tlp_err_pertlp           (rdlh_duplicate_tlp_err_pertlp),      // input  [RX_TLP-1:0]
    .rdlh_bad_dllp_err_perdllp               (rdlh_bad_dllp_err_perdllp),          // input  [RX_NDLLP-1:0]
    .rdlh_rcvd_nack_perdllp                  (rdlh_rcvd_nack_perdllp),             // input  [RX_NDLLP-1:0]
    .rdlh_rcvd_ack_perdllp                   (rdlh_rcvd_ack_perdllp),              // input  [RX_NDLLP-1:0]
    .xdlh_replay_num_rlover_err              (xdlh_replay_num_rlover_err),         // input
    .xdlh_replay_timeout_err                 (xdlh_replay_timeout_err),            // input
    .xdlh_retry_req                          (xdlh_retry_req),                     // input
    .xdlh_nak_sent                           (xdlh_nak_sent),                      // input
    .xdlh_ack_sent                           (xdlh_ack_sent),                      // input
    .xdlh_update_fc_sent                     (xdlh_update_fc_sent),                // input  [TX_NDLLP-1:0]
    .xadm_tx_nullify_evt                     (xadm_tx_nullify_evt),                // input  [N_XADM_IF-1:0]
    .rtlh_req_link_retrain                   (rtlh_req_link_retrain),              // input
    .rtlh_rcvd_ufc_perdllp                   (rtlh_rcvd_ufc_perdllp),              // input  [RX_NDLLP -1:0]
    .rtlh_rx_memwr_evt                       (rtlh_rx_memwr_evt),                  // input
    .rtlh_rx_defmemwr_evt                    (rtlh_rx_defmemwr_evt),               // input
    .rtlh_rx_memrd_evt                       (rtlh_rx_memrd_evt),                  // input
    .rtlh_rx_cfgwr_evt                       (rtlh_rx_cfgwr_evt),                  // input
    .rtlh_rx_cfgrd_evt                       (rtlh_rx_cfgrd_evt),                  // input
    .rtlh_rx_iowr_evt                        (rtlh_rx_iowr_evt),                   // input
    .rtlh_rx_iord_evt                        (rtlh_rx_iord_evt),                   // input
    .rtlh_rx_cplwod_evt                      (rtlh_rx_cplwod_evt),                 // input
    .rtlh_rx_cplwd_evt                       (rtlh_rx_cplwd_evt),                  // input
    .rtlh_rx_msg_evt                         (rtlh_rx_msg_evt),                    // input
    .rtlh_rx_atmcop_evt                      (rtlh_rx_atmcop_evt),                 // input
    .rtlh_rx_tlpwprefix_evt                  (rtlh_rx_tlpwprefix_evt),             // input
    .app_malformed_tlp                       (app_malformed_tlp),                  // input
    .rtlh_rx_tlp_dpsize                      (rtlh_rx_tlp_dpsize),                 // input  [NUM_ETO*11-1:0],[RX_TLP*11-1:0]
    .xtlh_tx_memwr_evt                       (xtlh_tx_memwr_evt),                  // input  [NUM_EOT-1:0],[N_XADM_P_IF-1:0]
    .xtlh_tx_defmemwr_evt                    (xtlh_tx_defmemwr_evt),               // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_memrd_evt                       (xtlh_tx_memrd_evt),                  // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_cfgwr_evt                       (xtlh_tx_cfgwr_evt),                  // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_cfgrd_evt                       (xtlh_tx_cfgrd_evt),                  // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_iowr_evt                        (xtlh_tx_iowr_evt),                   // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_iord_evt                        (xtlh_tx_iord_evt),                   // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_cplwod_evt                      (xtlh_tx_cplwod_evt),                 // input  [NUM_EOT-1:0],[N_XADM_CPL_IF-1:0]
    .xtlh_tx_cplwd_evt                       (xtlh_tx_cplwd_evt),                  // input  [NUM_EOT-1:0],[N_XADM_CPL_IF-1:0]
    .xtlh_tx_msg_evt                         (xtlh_tx_msg_evt),                    // input  [NUM_EOT-1:0],[N_XADM_P_IF-1:0]
    .xtlh_tx_atmcop_evt                      (xtlh_tx_atmcop_evt),                 // input  [NUM_EOT-1:0],[N_XADM_NP_IF-1:0]
    .xtlh_tx_tlpwprefix_evt                  (xtlh_tx_tlpwprefix_evt),             // input  [NUM_EOT-1:0],[N_XADM_IF-1:0]
    .xtlh_tx_tlp_dpsize                      (xtlh_tx_tlp_dpsize),                 // input  [NUM_EOT*11-1:0],[N_XADM_IF*11-1:0]
 // --- Time based Analysis signals
 // --- Error Injection signals
    .rdlh_einj0_lcrc_evt                     (rdlh_einj0_lcrc_evt),                // input  [2:0]
    .radm_einj0_ecrc_evt                     (radm_einj0_ecrc_evt),
    .xmlh_einj0_oscrc_evt                    (xmlh_einj0_oscrc_evt),               // input
    .xdlh_einj0_lcrc_evt                     (xdlh_einj0_lcrc_evt),                // input
    .xdlh_einj0_fcrc_evt                     (xdlh_einj0_fcrc_evt),                // input
    .xdlh_einj0_dllpcrc_evt                  (xdlh_einj0_dllpcrc_evt),             // input  [1:0]
    .xadm_einj0_ecrc_evt                     (xadm_einj0_ecrc_evt),                // input
    .ras_des_einj1_exp_sequm_evt             (ras_des_einj1_exp_sequm_evt),  
    .ras_des_einj1_ack_nak_sequm_evt         (ras_des_einj1_ack_nak_sequm_evt),
    .xdlh_einj2_nak_evt                      (xdlh_einj2_nak_evt),                 // input
    .xmlh_einj3_osmsk_evt                    (xmlh_einj3_osmsk_evt),               // input  [1:0]
    .rtlh_einj4_fc_evt                       (rtlh_einj4_fc_evt),                  // input
    .xdlh_einj5_nultlp_evt                   (xdlh_einj5_nultlp_evt),              // input
    .xdlh_einj5_dup_evt                      (xdlh_einj5_dup_evt),                 // input
    .xaim_einj6_tlp_evt                      (xaim_einj6_tlp_evt),                 // input
 // --- Silcon debug signals
    .rmlh_deskew_fifo_ptr                    (rmlh_deskew_fifo_ptr),               // input  [(NL*8)-1:0]
    .rmlh_framing_err_ptr                    (rmlh_framing_err_ptr),               // input  [6:0]
    .mac_phy_txelec_txburst_i                (mac_phy_txelec_txburst),             // input  [NL*`CX_PHY_TXEI_WD-1:0]
    .mac_phy_rxpolarity                      (mac_phy_rxpolarity),                 // input  [NL-1:0]
    .phy_mac_rxelec_rxh8exit                 (phy_mac_rxelec_rxh8exit),            // input  [NL-1:0]
    .phy_mac_rxvalid_rxburst                 (phy_mac_rxvalid_rxburst),            // input  [NL-1:0]
    .orig_pipe_rxdata                        (orig_pipe_rxdata),                   // input  [(NL*PHY_NB*8)-1:0]
    .orig_pipe_rxdatak                       (orig_pipe_rxdatak),                  // input  [(NL*PHY_NB)-1:0]
    .orig_pipe_rxdatavalid                   (orig_pipe_rxdatavalid),              // input  [NL-1:0]
    .orig_pipe_rxstatus                      (orig_pipe_rxstatus),                 // input  [(NL*3)-1:0]
    .orig_pipe_rxstartblock                  (orig_pipe_rxstartblock),             // input  [(NL*PHY_RXSB_WD)-1:0]
    .orig_pipe_rxsyncheader                  (orig_pipe_rxsyncheader),             // input  [(NL*PHY_RXSH_WD)-1:0]
    .orig_pipe_blockaligncontrol             (orig_pipe_blockaligncontrol),        // input
    .latched_rxdetected                      (latched_rxdetected),                 // input  [NL-1:0]
    .pm_pme_resend_flag                      (pm_pme_resend_flag),                 // input
    .smlh_ltssm_variable                     (smlh_ltssm_variable ),               // input  [15:0]
    .ltssm_powerdown                         (ltssm_powerdown),                    // input  [1:0]
    .latched_ts_nfts                         (latched_ts_nfts),                    // input  [7:0]
    .pm_usp_prot_state                       (pm_usp_prot_state),
    .pm_usp_link_state                       (pm_usp_link_state),
    .pm_dsp_prot_state                       (pm_dsp_prot_state),
    .pm_dsp_link_state                       (pm_dsp_link_state),
    .pm_l0s_state                            (pm_l0s_state),
    .smlh_lane_reversed                      (smlh_lane_reversed),                 // input
    .init_eq_pending                         (init_eq_pending),                    // input
    .mac_cdm_ras_des_fs                      (mac_cdm_ras_des_fs),                 // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_lf                      (mac_cdm_ras_des_lf),                 // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_coef_ltx                (mac_cdm_ras_des_coef_ltx),           // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback             (phy_cdm_ras_des_fomfeedback),        // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123                   (eqpa_violate_rule_123),              // input  [NL*3-1:0]
    .eq_convergence_sts                      (eq_convergence_sts),                 // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx                (mac_cdm_ras_des_coef_rtx),           // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_pset_lrx                (mac_cdm_ras_des_pset_lrx),           // input  [NL*RX_PSET_WD-1:0]
    .mac_cdm_ras_des_reject_rtx              (mac_cdm_ras_des_reject_rtx),         // input  [NL-1:0]
    .init_eq_pending_g4                      (init_eq_pending_g4),                 // input
    .mac_cdm_ras_des_fs_g4                   (mac_cdm_ras_des_fs_g4),              // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_lf_g4                   (mac_cdm_ras_des_lf_g4),              // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_coef_ltx_g4             (mac_cdm_ras_des_coef_ltx_g4),        // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback_g4          (phy_cdm_ras_des_fomfeedback_g4),     // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123_g4                (eqpa_violate_rule_123_g4),           // input  [NL*3-1:0]
    .eq_convergence_sts_g4                   (eq_convergence_sts_g4),              // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx_g4             (mac_cdm_ras_des_coef_rtx_g4),        // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_reject_rtx_g4           (mac_cdm_ras_des_reject_rtx_g4),      // input  [NL-1:0]
    .init_eq_pending_g5                      (init_eq_pending_g5),                 // input
    .mac_cdm_ras_des_fs_g5                   (mac_cdm_ras_des_fs_g5),              // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_lf_g5                   (mac_cdm_ras_des_lf_g5),              // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_coef_ltx_g5             (mac_cdm_ras_des_coef_ltx_g5),        // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback_g5          (phy_cdm_ras_des_fomfeedback_g5),     // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123_g5                (eqpa_violate_rule_123_g5),           // input  [NL*3-1:0]
    .eq_convergence_sts_g5                   (eq_convergence_sts_g5),              // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx_g5             (mac_cdm_ras_des_coef_rtx_g5),        // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_reject_rtx_g5           (mac_cdm_ras_des_reject_rtx_g5),      // input  [NL-1:0]
    .init_eq_pending_g6                      (init_eq_pending_g6),                 // input
    .mac_cdm_ras_des_fs_g6                   (mac_cdm_ras_des_fs_g6),              // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_lf_g6                   (mac_cdm_ras_des_lf_g6),              // input  [NL*TX_FS_WD-1:0]
    .mac_cdm_ras_des_coef_ltx_g6             (mac_cdm_ras_des_coef_ltx_g6),        // input  [NL*TX_COEF_WD-1:0]
    .phy_cdm_ras_des_fomfeedback_g6          (phy_cdm_ras_des_fomfeedback_g6),     // input  [NL*FOMFEEDBACK_WD-1:0]
    .eqpa_violate_rule_123_g6                (eqpa_violate_rule_123_g6),           // input  [NL*3-1:0]
    .eqpa_violate_rule_4_g6                  (eqpa_violate_rule_4_g6),             // input  [NL-1:0]
    .eq_convergence_sts_g6                   (eq_convergence_sts_g6),              // input  [NL*2-1:0]
    .mac_cdm_ras_des_coef_rtx_g6             (mac_cdm_ras_des_coef_rtx_g6),        // input  [NL*TX_COEF_WD-1:0]
    .mac_cdm_ras_des_reject_rtx_g6           (mac_cdm_ras_des_reject_rtx_g6),      // input  [NL-1:0]
    .rl0s_state                              (rl0s_state),                        // input  [1:0]
    .mac_phy_rate                            (mac_phy_rate),                      // input
    .mac_phy_powerdown                       (mac_phy_powerdown),                 // input  [1:0]
    .mac_phy_txdetectrx_loopback             (mac_phy_txdetectrx_loopback),       // input  [NL-1:0]
    .mac_phy_rxeqeval                        (mac_phy_rxeqeval),                  // input  [NL-1:0]
    .phy_mac_phystatus                       (phy_mac_phystatus),                 // input  [NL-1:0]
    .phy_mac_dirfeedback                     (phy_mac_dirfeedback),               // input  [NL*DIRFEEDBACK_WD-1:0]
    .phy_mac_fomfeedback                     (phy_mac_fomfeedback),               // input  [NL*FOMFEEDBACK_WD-1:0]
    .mac_phy_txdeemph                        (mac_cdm_ras_des_txdeemph),          // input
    .smlh_rxos_type                          (smlh_rxos_type),                    // input  [NL*16-1:0]
    .smseq_mcs_sts                           (smseq_mcs_sts),                     // input  [NL*8-1:0]
    .smseq_ts_debug_info                     (smseq_ts_debug_info),               // input  [NL*64-1:0]
    .rdlh_dlcntrl_state                      (rdlh_dlcntrl_state),                 // input  [1:0]
    .rdlh_vc0_initfc1_status                 (rdlh_vc0_initfc1_status),            // input
    .rdlh_vc0_initfc2_status                 (rdlh_vc0_initfc2_status),            // input
    .rdlh_xplh_curnt_rx_ack_seqnum           (rdlh_xplh_curnt_rx_ack_seqnum),      // input  [11:0]
    .xdlh_xplh_curnt_seqnum                  (xdlh_xplh_curnt_seqnum),             // input  [11:0]
    .rtlh_fc_rcvd_ph                         (rtlh_fc_rcvd_ph),                    // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_rcvd_pd                         (rtlh_fc_rcvd_pd),                    // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_rcvd_nph                        (rtlh_fc_rcvd_nph),                   // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_rcvd_npd                        (rtlh_fc_rcvd_npd),                   // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_rcvd_cplh                       (rtlh_fc_rcvd_cplh),                  // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_rcvd_cpld                       (rtlh_fc_rcvd_cpld),                  // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_allctd_ph                       (rtlh_fc_allctd_ph),                  // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_allctd_pd                       (rtlh_fc_allctd_pd),                  // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_allctd_nph                      (rtlh_fc_allctd_nph),                 // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_allctd_npd                      (rtlh_fc_allctd_npd),                 // input  [(NVC*DCRD_WD)-1:0]
    .rtlh_fc_allctd_cplh                     (rtlh_fc_allctd_cplh),                // input  [(NVC*HCRD_WD)-1:0]
    .rtlh_fc_allctd_cpld                     (rtlh_fc_allctd_cpld),                // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_cnsmd_ph                        (xadm_fc_cnsmd_ph),                   // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_cnsmd_pd                        (xadm_fc_cnsmd_pd),                   // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_cnsmd_nph                       (xadm_fc_cnsmd_nph),                  // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_cnsmd_npd                       (xadm_fc_cnsmd_npd),                  // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_cnsmd_cplh                      (xadm_fc_cnsmd_cplh),                 // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_cnsmd_cpld                      (xadm_fc_cnsmd_cpld),                 // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_limit_ph                        (xadm_fc_limit_ph),                   // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_limit_pd                        (xadm_fc_limit_pd),                   // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_limit_nph                       (xadm_fc_limit_nph),                  // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_limit_npd                       (xadm_fc_limit_npd),                  // input  [(NVC*DCRD_WD)-1:0]
    .xadm_fc_limit_cplh                      (xadm_fc_limit_cplh),                 // input  [(NVC*HCRD_WD)-1:0]
    .xadm_fc_limit_cpld                      (xadm_fc_limit_cpld),                 // input  [(NVC*DCRD_WD)-1:0]
    .radm_mlf_tlp_err_ptr                    (radm_mlf_tlp_err_ptr),               // input  [(FX_TLP*8)-1:0]
 // --- Others
    .upstream_port                           (upstream_port),                      // input
    .current_data_rate                       (current_data_rate),                  // input  [1:0]
    .app_ras_des_tba_ctrl                    (app_ras_des_tba_ctrl),               // input  [1:0]
    .pm_sel_aux_clk                          (pm_sel_aux_clk),                     // input
    .aux_clk_active                          (aux_clk_active),                     // input
    .cfg_pl_aux_clk_freq                     (cfg_pl_aux_clk_freq),                // input  [PL_AUX_CLK_FREQ_WD-1:0]
    .app_ras_des_sd_hold_ltssm               (app_ras_des_sd_hold_ltssm),          // input
    .cxl_rcrb_enable                         (cxl_rcrb_enable),
 // --- Trace FIFO signals
// -------------- Outputs ---------------
// --- Register access signals
    .rasdes_reg_ack                          (rasdes_reg_ack),                     // output
    .rasdes_reg_data                         (rasdes_reg_data),                    // output [31:0]
 //---- Debug info  -----------------------
    .cdm_ras_des_ec_info_common              (cdm_ras_des_ec_info_common),         // output [RASDES_EC_INFO_CM-1:0]
    .cdm_ras_des_ec_info_l0                  (cdm_ras_des_ec_info_l0),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l1                  (cdm_ras_des_ec_info_l1),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l2                  (cdm_ras_des_ec_info_l2),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l3                  (cdm_ras_des_ec_info_l3),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l4                  (cdm_ras_des_ec_info_l4),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l5                  (cdm_ras_des_ec_info_l5),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l6                  (cdm_ras_des_ec_info_l6),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_ec_info_l7                  (cdm_ras_des_ec_info_l7),             // output [RASDES_EC_INFO_PL-1:0]
    .cdm_ras_des_sd_info_common              (cdm_ras_des_sd_info_common),         // output [RASDES_SD_INFO_CM-1:0]
    .cdm_ras_des_sd_info_l0                  (cdm_ras_des_sd_info_l0),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l1                  (cdm_ras_des_sd_info_l1),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l2                  (cdm_ras_des_sd_info_l2),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l3                  (cdm_ras_des_sd_info_l3),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l4                  (cdm_ras_des_sd_info_l4),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l5                  (cdm_ras_des_sd_info_l5),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l6                  (cdm_ras_des_sd_info_l6),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_l7                  (cdm_ras_des_sd_info_l7),             // output [RASDES_SD_INFO_PL-1:0]
    .cdm_ras_des_sd_info_v0                  (cdm_ras_des_sd_info_v0),             // Silicon debug vc0 debug info
    .cdm_ras_des_tba_info_common             (cdm_ras_des_tba_info_common),        // Time based analysis common debug info

 //---- RAM I/F -----------------------
    .cdm_ras_des_ec_ram_ena                  (cdm_ras_des_ec_ram_ena),             // output
    .cdm_ras_des_ec_ram_wea                  (cdm_ras_des_ec_ram_wea),             // output
    .cdm_ras_des_ec_ram_addra                (cdm_ras_des_ec_ram_addra),           // output [RASDES_EC_RAM_ADDR_WIDTH-1:0]
    .cdm_ras_des_ec_ram_datain               (cdm_ras_des_ec_ram_datain),          // output [RASDES_EC_RAM_DATA_WIDTH-1:0]
    .cdm_ras_des_ec_ram_enb                  (cdm_ras_des_ec_ram_enb),             // output
    .cdm_ras_des_ec_ram_addrb                (cdm_ras_des_ec_ram_addrb),           // output [RASDES_EC_RAM_ADDR_WIDTH-1:0]
    .cdm_ras_des_tba_ram_ena                 (cdm_ras_des_tba_ram_ena),            // output
    .cdm_ras_des_tba_ram_wea                 (cdm_ras_des_tba_ram_wea),            // output
    .cdm_ras_des_tba_ram_addra               (cdm_ras_des_tba_ram_addra),          // output [RASDES_TBA_RAM_ADDR_WIDTH-1:0]
    .cdm_ras_des_tba_ram_datain              (cdm_ras_des_tba_ram_datain),         // output [RASDES_TBA_RAM_DATA_WIDTH-1:0]
    .cdm_ras_des_tba_ram_enb                 (cdm_ras_des_tba_ram_enb),            // output
    .cdm_ras_des_tba_ram_addrb               (cdm_ras_des_tba_ram_addrb),          // output [RASDES_TBA_RAM_ADDR_WIDTH-1:0]
// --- Event counter signals
// --- Time based Analysis signals
// --- Error Injection signals
    .cdm_ras_des_einj0_enable                (cdm_ras_des_einj0_enable),           // output
    .cdm_ras_des_einj0_count                 (cdm_ras_des_einj0_count),            // output [7:0]
    .cdm_ras_des_einj0_crc_type              (cdm_ras_des_einj0_crc_type),         // output [3:0]
    .cdm_ras_des_einj0_ecrc_vc_sel           (cdm_ras_des_einj0_ecrc_vc_sel),      // Error injection 0 ECRC Virtual Channel Selection
    .cdm_ras_des_einj0_ecrc_fc_sel           (cdm_ras_des_einj0_ecrc_fc_sel),      // Error injection 0 ECRC Flow Control Selection
    .cdm_ras_des_einj0_ecrc_intf_sel         (cdm_ras_des_einj0_ecrc_intf_sel),    // Error injection 0 ECRC Interface Selection
    .cdm_ras_des_einj1_enable                (cdm_ras_des_einj1_enable),           // output
    .cdm_ras_des_einj1_seq_type              (cdm_ras_des_einj1_seq_type),         // output
    .cdm_ras_des_einj1_bad_seq               (cdm_ras_des_einj1_bad_seq),          // output [12:0]
    .cdm_ras_des_einj1_count                 (cdm_ras_des_einj1_count),            // output [7:0]
    .cdm_ras_des_einj2_enable                (cdm_ras_des_einj2_enable),           // output
    .cdm_ras_des_einj2_dllp_type             (cdm_ras_des_einj2_dllp_type),        // output [1:0]
    .cdm_ras_des_einj3_enable                (cdm_ras_des_einj3_enable),           // output
    .cdm_ras_des_einj3_count                 (cdm_ras_des_einj3_count),            // output [7:0]
    .cdm_ras_des_einj3_smb_type              (cdm_ras_des_einj3_smb_type),         // output [2:0]
    .cdm_ras_des_einj4_enable                (cdm_ras_des_einj4_enable),           // output
    .cdm_ras_des_einj4_updfc_type            (cdm_ras_des_einj4_updfc_type),       // output [2:0]
    .cdm_ras_des_einj4_vcnum                 (cdm_ras_des_einj4_vcnum),            // output [2:0]
    .cdm_ras_des_einj4_badfc_value           (cdm_ras_des_einj4_badfc_value),      // output [12:0]
    .cdm_ras_des_einj5_enable                (cdm_ras_des_einj5_enable),           // output
    .cdm_ras_des_einj5_count                 (cdm_ras_des_einj5_count),            // output [7:0]
    .cdm_ras_des_einj5_tlp_type              (cdm_ras_des_einj5_tlp_type),         // output
    .cdm_ras_des_einj6_enable                (cdm_ras_des_einj6_enable),           // output
    .cdm_ras_des_einj6_cmp_point_h0          (cdm_ras_des_einj6_cmp_point_h0),     // output [31:0]
    .cdm_ras_des_einj6_cmp_point_h1          (cdm_ras_des_einj6_cmp_point_h1),     // output [31:0]
    .cdm_ras_des_einj6_cmp_point_h2          (cdm_ras_des_einj6_cmp_point_h2),     // output [31:0]
    .cdm_ras_des_einj6_cmp_point_h3          (cdm_ras_des_einj6_cmp_point_h3),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h0          (cdm_ras_des_einj6_cmp_value_h0),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h1          (cdm_ras_des_einj6_cmp_value_h1),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h2          (cdm_ras_des_einj6_cmp_value_h2),     // output [31:0]
    .cdm_ras_des_einj6_cmp_value_h3          (cdm_ras_des_einj6_cmp_value_h3),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h0          (cdm_ras_des_einj6_chg_point_h0),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h1          (cdm_ras_des_einj6_chg_point_h1),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h2          (cdm_ras_des_einj6_chg_point_h2),     // output [31:0]
    .cdm_ras_des_einj6_chg_point_h3          (cdm_ras_des_einj6_chg_point_h3),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h0          (cdm_ras_des_einj6_chg_value_h0),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h1          (cdm_ras_des_einj6_chg_value_h1),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h2          (cdm_ras_des_einj6_chg_value_h2),     // output [31:0]
    .cdm_ras_des_einj6_chg_value_h3          (cdm_ras_des_einj6_chg_value_h3),     // output [31:0]
    .cdm_ras_des_einj6_count                 (cdm_ras_des_einj6_count),            // output [7:0]
    .cdm_ras_des_einj6_invt_cont             (cdm_ras_des_einj6_invt_cont),        // output
    .cdm_ras_des_einj6_pkt_type              (cdm_ras_des_einj6_pkt_type),         // output [2:0]
// --- Silcon debug signals
    .cdm_ras_des_pm_entry_interval           (cdm_ras_des_pm_entry_interval),      // output [1:0]
    .cdm_ras_des_eidle_cnt_sel               (cdm_ras_des_eidle_cnt_sel),          // output [1:0]
    .cdm_ras_des_ltssm_stop                  (cdm_ras_des_ltssm_stop),             // output
    .cdm_ras_des_recovery_req                (cdm_ras_des_recovery_req),           // output
    .cdm_ras_des_ferr_rec_dis                (cdm_ras_des_ferr_rec_dis),           // output
    .cdm_ras_des_direct_rcvry_idle_to_cfg    (cdm_ras_des_direct_rcvry_idle_to_cfg), // output
    .cdm_ras_des_direct_poll_cmp_to_det      (cdm_ras_des_direct_poll_cmp_to_det), // output
    .cdm_ras_des_direct_lpbk_slave_to_exit   (cdm_ras_des_direct_lpbk_slave_to_exit), // output
    .cdm_ras_des_force_rxdetected_en         (cdm_ras_des_force_rxdetected_en),    // output
    .cdm_ras_des_force_rxdetected            (cdm_ras_des_force_rxdetected),       // output [15:0]
    .cdm_ras_des_force_linkdown_noack        (cdm_ras_des_force_linkdown_noack)    // output
    ,
    .cdm_ras_des_ext_eq_to_factor            (cdm_ras_des_ext_eq_to_factor),       // output [1:0]
    .cdm_ras_des_eq_fom_target_en            (cdm_ras_des_eq_fom_target_en),       // output
    .cdm_ras_des_eq_force_coef_rtx_en        (cdm_ras_des_eq_force_coef_rtx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_pset_lrx_en        (cdm_ras_des_eq_force_pset_lrx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en        (cdm_ras_des_eq_force_coef_ltx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx           (cdm_ras_des_eq_force_coef_ltx),      // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_lrx           (cdm_ras_des_eq_force_pset_lrx),      // output [RX_PSET_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx           (cdm_ras_des_eq_force_coef_rtx),      // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en        (cdm_ras_des_eq_force_pset_ltx_en),   // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx       (cdm_ras_des_eq_force_usp_pset_ltx)   // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g4     (cdm_ras_des_eq_force_coef_rtx_en_g4), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en_g4     (cdm_ras_des_eq_force_coef_ltx_en_g4), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_g4        (cdm_ras_des_eq_force_coef_ltx_g4),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx_g4        (cdm_ras_des_eq_force_coef_rtx_g4),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en_g4     (cdm_ras_des_eq_force_pset_ltx_en_g4), // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx_g4    (cdm_ras_des_eq_force_usp_pset_ltx_g4)  // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g5     (cdm_ras_des_eq_force_coef_rtx_en_g5), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en_g5     (cdm_ras_des_eq_force_coef_ltx_en_g5), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_g5        (cdm_ras_des_eq_force_coef_ltx_g5),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx_g5        (cdm_ras_des_eq_force_coef_rtx_g5),   // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en_g5     (cdm_ras_des_eq_force_pset_ltx_en_g5), // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx_g5    (cdm_ras_des_eq_force_usp_pset_ltx_g5)  // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g6     (cdm_ras_des_eq_force_coef_rtx_en_g6), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_en_g6     (cdm_ras_des_eq_force_coef_ltx_en_g6), // output [NL-1:0]
    .cdm_ras_des_eq_force_coef_ltx_g6        (cdm_ras_des_eq_force_coef_ltx_g6),    // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_coef_rtx_g6        (cdm_ras_des_eq_force_coef_rtx_g6),    // output [NL*TX_COEF_WD-1:0]
    .cdm_ras_des_eq_force_pset_ltx_en_g6     (cdm_ras_des_eq_force_pset_ltx_en_g6), // output [NL-1:0]
    .cdm_ras_des_eq_force_usp_pset_ltx_g6    (cdm_ras_des_eq_force_usp_pset_ltx_g6) // output [NL*TX_PSET_WD-1:0]
    ,
    .cdm_ras_des_eq_fom_target               (cdm_ras_des_eq_fom_target),          // output [FOMFEEDBACK_WD-1:0]
    .cdm_ras_des_eq_eval_interval            (cdm_ras_des_eq_eval_interval)        // output
// --- Trace FIFO signals
) ;

// -----------------------------------------------------------------------------
// Hot-plug Logic
// -----------------------------------------------------------------------------
//  Per Function Hot Plug Controller Instantiation.
generate
for (func=0; func<NF; func = func+1) begin : gen_hot_plug_ctrl
hot_plug_ctrl
 #(INST) u_hot_plug_ctrl (
// ---------- Inputs --------
    .core_clk                       (core_clk),
    .core_rst_n                     (non_sticky_rst_n),
    .cfg_atten_button_pressed       (cfg_atten_button_pressed[func]),
    .cfg_pwr_fault_det              (cfg_pwr_fault_det[func]),
    .cfg_mrl_sensor_chged           (cfg_mrl_sensor_chged[func]),
    .cfg_pre_det_chged              (cfg_pre_det_chged[func]),
    .cfg_cmd_cpled_int              (cfg_cmd_cpled_int[func]),
    .cfg_dll_state_chged            (cfg_dll_state_chged[func]),
    .cfg_int_disable                (cfg_int_disable[func]),
    .cfg_hp_int_en                  (cfg_hp_int_en[func]),
    .cfg_pme_en                     (cfg_pme_en[func]),
    .cfg_msi_en                     (cfg_msi_en_int[func]),
    .cfg_msix_en                    (cfg_msix_en[func]),

// ---------- Outputs --------
    .hp_pme                         (cdm_hp_pme[func]),
    .hp_int                         (cdm_hp_int[func]),
    .hp_msi                         (cdm_hp_msi[func])
);
end // for (func=0; func<NF; func = func+1) begin : gen_hot_plug_ctrl
endgenerate
// -----------------------------------------------------------------------------
// ATU Unroll
// -----------------------------------------------------------------------------
wire [31:0] lbc_cdm_addr_delay;
wire        atu_reg_sel_delay;
wire [31:0] lbc_cdm_data_delay;

delay_n

#(1, 32+1+32) u_atu_pipeline(
    .clk        (core_clk),
    .rst_n      (non_sticky_rst_n),
    .clear      (1'b0),
    .din        ({lbc_cdm_data      ,atu_reg_sel      ,lbc_cdm_addr   }),
    .dout       ({lbc_cdm_data_delay,atu_reg_sel_delay,lbc_cdm_addr_delay })
);

reg atu_reg_sel_d;
reg atu_reg_sel_dd;
reg [3:0] atu_write_pulse;
reg [31:0] atu_ctrl_reg_id;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
      atu_reg_sel_d  <= #TP 0;
      atu_reg_sel_dd <= #TP 0;
      atu_ctrl_reg_ack <= #TP 0;
    end else begin
      atu_reg_sel_d  <= #TP atu_reg_sel_delay & |lbc_cdm_cs;
      atu_reg_sel_dd <= #TP atu_reg_sel_d & |lbc_cdm_cs; //the _dd is to create one clock cycle delay. the data on cdm_atu_ctrl is registered
      atu_ctrl_reg_ack <= #TP atu_reg_sel_d & atu_reg_sel_dd & |lbc_cdm_cs;  //FOr now the ATU CTRL will ALWAYS ACK, even for non existing addresses.
    end
  end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
      atu_write_pulse <= #TP 4'b0;
    end else begin
      atu_write_pulse            <= #TP (atu_reg_sel_delay & ~atu_reg_sel_d) ? lbc_cdm_wr : 4'b0;
  end
end

    // ATU registers
    cdm_atu_ctrl
    
        #(
          .INST(INST),
          .ATU_OUT_REGIONS(ATU_OUT_NREGIONS),
          .ATU_IN_REGIONS(ATU_IN_NREGIONS),
          .ATU_BASE_WD(ATU_BASE_WD),
          .ATU_REG_WD(ATU_REG_WD),
          .ATU_CTRL_REG_ID_WD(10))
          u_cdm_atu_ctrl(
// ------------ Inputs ---------------
        .core_clk               (core_clk),
        .sticky_rst_n           (sticky_rst_n),
        .cdm_clk_g              (cdm_clk_g_int),
        .lbc_cdm_data           (lbc_cdm_data_delay),
        .atu_ctrl_write_pulse   (atu_write_pulse),

        .lbc_cdm_addr           (lbc_cdm_addr_delay),
        .atu_reg_sel            (atu_reg_sel_delay | atu_reg_sel_d),
// ------------ Outputs --------------
        .atu_ctrl_reg_data      (atu_ctrl_reg_data),

// ATU outbound Region controls
        .atu_reg_out_type           (atu_reg_out_type),
        .atu_reg_out_tc             (atu_reg_out_tc),
        .atu_reg_out_td             (atu_reg_out_td),
        .atu_reg_out_attr           (atu_reg_out_attr),
        .atu_reg_out_at             (atu_reg_out_at),
        .atu_reg_out_func_num       (atu_reg_out_func_num),
        .atu_reg_out_func_bypass    (atu_reg_out_func_bypass),
        .atu_reg_out_snp            (atu_reg_out_snp),
        .atu_reg_out_dma_bypass     (atu_reg_out_dma_bypass),
        .atu_reg_out_inhibit_payload    (atu_reg_out_inhibit_payload),
        .atu_reg_out_hdr_substitute_en  (atu_reg_out_hdr_substitute_en),
        .atu_reg_out_tag_substitute_en  (atu_reg_out_tag_substitute_en),
        .atu_reg_out_tag                (atu_reg_out_tag),
        .atu_reg_out_msg_code       (atu_reg_out_msg_code),
        .atu_reg_out_th             (atu_reg_out_th),
        .atu_reg_out_ph             (atu_reg_out_ph),
        .atu_reg_out_st             (atu_reg_out_st),
// Mode Settings
        .atu_reg_out_shift          (atu_reg_out_shift),
        .atu_reg_out_invert         (atu_reg_out_invert),
// Region Enable
        .atu_reg_out_en             (atu_reg_out_en),
// Base, Limit and Target Registers
        .atu_reg_out_base           (atu_reg_out_base),
        .atu_reg_out_upr_base       (atu_reg_out_upr_base),
        .atu_reg_out_limit          (atu_reg_out_limit),
        .atu_reg_out_uppr_limit     (atu_reg_out_uppr_limit),
        .atu_reg_out_lwr_trgt       (atu_reg_out_lwr_trgt),
        .atu_reg_out_upr_trgt       (atu_reg_out_upr_trgt),
        .atu_reg_out_lwr_trgt_lwr   (atu_reg_out_lwr_trgt_lwr),
        .atu_reg_out_incr_rgn_size  (atu_reg_out_incr_rgn_size),
        .atu_reg_out_hdr_flds_bypass (atu_reg_out_hdr_flds_bypass),

// ATU inbound Region controls
        .atu_reg_in_type            (atu_reg_in_type),
        .atu_reg_in_tc              (atu_reg_in_tc),
        .atu_reg_in_td              (atu_reg_in_td),
        .atu_reg_in_attr            (atu_reg_in_attr),
        .atu_reg_in_at              (atu_reg_in_at),
        .atu_reg_in_func_num        (atu_reg_in_func_num),
        .atu_reg_in_msg_code        (atu_reg_in_msg_code),
        .atu_reg_in_bar_num         (atu_reg_in_bar_num),
        .atu_reg_in_th              (atu_reg_in_th),
        .atu_reg_in_ph              (atu_reg_in_ph),
        .atu_reg_in_st              (atu_reg_in_st),
// Inbound field match enables
        .atu_reg_in_tc_match_en     (atu_reg_in_tc_match_en),
        .atu_reg_in_td_match_en     (atu_reg_in_td_match_en),
        .atu_reg_in_attr_match_en   (atu_reg_in_attr_match_en),
        .atu_reg_in_at_match_en     (atu_reg_in_at_match_en),
        .atu_reg_in_func_match_en   (atu_reg_in_func_match_en),
        .atu_reg_in_msgcode_match_en(atu_reg_in_msgcode_match_en),
        .atu_reg_in_th_match_en     (atu_reg_in_th_match_en),
        .atu_reg_in_ph_match_en     (atu_reg_in_ph_match_en),
        .atu_reg_in_st_match_en     (atu_reg_in_st_match_en),
        .atu_reg_in_single_addr_loc_en (atu_reg_in_single_addr_loc_en),
        .atu_reg_in_msg_type_match_mode (atu_reg_in_msg_type_match_mode),
// Response and mode settings
        .atu_reg_in_rsp_code        (atu_reg_in_rsp_code),
        .atu_reg_in_fuzzy           (atu_reg_in_fuzzy),
        .atu_reg_in_shift           (atu_reg_in_shift),
        .atu_reg_in_invert          (atu_reg_in_invert),
        .atu_reg_in_bar_match       (atu_reg_in_bar_match),
// Region Enable
        .atu_reg_in_en              (atu_reg_in_en),
// Base, Limit and Target Registers
        .atu_reg_in_base            (atu_reg_in_base),
        .atu_reg_in_upr_base        (atu_reg_in_upr_base),
        .atu_reg_in_limit           (atu_reg_in_limit),
        .atu_reg_in_cbuf_incr       (atu_reg_in_cbuf_incr),
        .atu_reg_in_cbuf_restart    (atu_reg_in_cbuf_restart),
        .atu_reg_in_uppr_limit      (atu_reg_in_uppr_limit),
        .atu_reg_in_lwr_trgt        (atu_reg_in_lwr_trgt),
        .atu_reg_in_upr_trgt        (atu_reg_in_upr_trgt),
        .atu_reg_in_incr_rgn_size   (atu_reg_in_incr_rgn_size)
    );



// --------------------------------------------------------------------------------------
// Assign outputs
// --------------------------------------------------------------------------------------








cdm_flit_logging_capability
 #(
                .INST   (INST),
                .FIFO_DEPTH(16)
                )
u_cdm_flit_logging_capability (
  // Inputs-Top
                .core_clk(core_clk),
                .non_sticky_rst_n(non_sticky_rst_n),
                .sticky_rst_n(sticky_rst_n),
                .rplh_valid_flit(rplh_flit_logging_interface.rplh_valid_flit),
                .rplh_flit_fec_uncorr_err(rplh_flit_logging_interface.rplh_flit_fec_uncorr_error),
                .rplh_flit_crc_uncorr_err(rplh_flit_logging_interface.rplh_flit_crc_uncorr_error),
                .rplh_flit_unrecognized_flit(rplh_flit_logging_interface.rplh_flit_unrecognized_flit),
                .rplh_flit_prot_synd_parity(rplh_flit_logging_interface.rplh_flit_prot_synd_parity),
                .rplh_flit_prot_synd_check(rplh_flit_logging_interface.rplh_flit_prot_synd_check),
                .rplh_flit_fec_corr_error(rplh_flit_logging_interface.rplh_flit_fec_corr_error),
                .rplh_flit_fec_corr_even_bit_error(rplh_flit_logging_interface.rplh_flit_fec_corr_even_bit_error),
                .rplh_flit_fec_corr_odd_bit_error(rplh_flit_logging_interface.rplh_flit_fec_corr_odd_bit_error),
                .rmlh_mismatch_SKP_OS(rmlh_flit_logging_interface.rmlh_mismatch_SKP_OS),
                .rmlh_framing_error(rmlh_flit_logging_interface.rmlh_framing_error),
                .rplh_link_rxmode(rplh_link_rxmode),
                .data_rate(current_data_rate),
                .smlh_invalid_ordered_set(smlh_flit_logging_interface.smlh_invalid_ordered_set),
                .smlh_corr_ordered_set(smlh_flit_logging_interface.smlh_corr_ordered_set),
  // Inputs-Regs
                .cfg_fifo_pop_en(cfg_pop_fifo_en),
                .cfg_flit_err_cnt_en(cfg_flit_err_cnt_en),
                .cfg_evnt_to_cnt(cfg_evnt_to_cnt),
                .cfg_trg_evnt_cnt(cfg_trg_evnt_cnt),
                .cfg_fber_measurement_en(cfg_fber_measurement_en),
                .cfg_clr_fber_cnt(cfg_clr_fber_cnt),
                .cfg_gran_per_lane_err_rpt(cfg_gran_per_lane_err_rpt),
                .cfg_rprt_longest_burst_vs_1st_burst(cfg_rpt_longest_burst_vs_1st_burst),
                .cfg_timer_scaled(1'b0),  //TBD
  // Outputs
                .cfg_flit_log(cfg_flit_log),
                .cfg_link_wd_err_cnt_start(cfg_link_wd_err_cnt_start),
                .cfg_interr_trg_evnt_cnt(cfg_interr_trg_evnt_cnt),
                .cfg_interr_trg_evnt_cnt_clr(cfg_interr_trg_evnt_cnt_clr),
                .cfg_flit_err_cnt(cfg_flit_err_cnt),
                .cfg_flit_cnt(cfg_flit_cnt),
                .cfg_invalid_flit_cnt(cfg_invalid_flit_cnt),  
                .cfg_lane_0_corr_cnt(cfg_lane_0_corr_cnt),
                .cfg_lane_1_corr_cnt(cfg_lane_1_corr_cnt),
                .cfg_lane_2_corr_cnt(cfg_lane_2_corr_cnt),
                .cfg_lane_3_corr_cnt(cfg_lane_3_corr_cnt),
                .cfg_lane_4_corr_cnt(cfg_lane_4_corr_cnt),
                .cfg_lane_5_corr_cnt(cfg_lane_5_corr_cnt),
                .cfg_lane_6_corr_cnt(cfg_lane_6_corr_cnt),
                .cfg_lane_7_corr_cnt(cfg_lane_7_corr_cnt),
                .cfg_lane_8_corr_cnt(cfg_lane_8_corr_cnt),
                .cfg_lane_9_corr_cnt(cfg_lane_9_corr_cnt),
                .cfg_lane_10_corr_cnt(cfg_lane_10_corr_cnt),
                .cfg_lane_11_corr_cnt(cfg_lane_11_corr_cnt),
                .cfg_lane_12_corr_cnt(cfg_lane_12_corr_cnt),
                .cfg_lane_13_corr_cnt(cfg_lane_13_corr_cnt),
                .cfg_lane_14_corr_cnt(cfg_lane_14_corr_cnt),
                .cfg_lane_15_corr_cnt(cfg_lane_15_corr_cnt)
                );

endmodule




