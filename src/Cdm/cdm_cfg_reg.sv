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
// ---    $DateTime: 2024/02/23 10:50:10 $
// ---    $Revision: #29 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cfg_reg.sv#29 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the PCIE core configure space registers.
// --- the PCIE configuration cycles and host access will be mapped to the
// --- local bus cycles.
//
// Note: this module can be configured to support
//      -- upstream port
//      -- downstream port
//      -- Bridge
//      -- End point
//      -- Root complex
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module cdm_cfg_reg
import DWC_pcie_ctl_pkg::MSG_TLP_WD;
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_DETECT_QUIET;
import DWC_pcie_core_pkg::S_DETECT_ACT;
   (
// ---- inputs -----
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    device_type,
    cfg_reg_sel,
    cfg_cap_reg_sel,
    ecfg_reg_sel,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    int_msg_pending,
    rdlh_link_up,
    smlh_link_up,
    smlh_autoneg_link_width,
    smlh_autoneg_link_sp,
    smlh_link_training_in_prog,
    smlh_bw_mgt_status,
    smlh_link_auto_bw_status,
    smlh_clr_enter_compliance,
    smlh_tx_margin_rst,
    mac_phy_txdeemph,
    smlh_ls2_eq_req,
    smlh_ls2_eq_success,
    smlh_ls2_eq_cmpl,
    smlh_ls2_eq_enter,
    smlh_ltssm_in_detectquiet,
    smlh_two_retimers_pre_detected,
    smlh_crosslink_resolution,
    smlh_retimer_pre_detected,
    aux_pwr_det,
    radm_cpl_pending,
    cfg_cor_err_det,
    cfg_nf_err_det,
    cfg_f_err_det,
    cfg_rprt_err_cor,
    cfg_rprt_err_nf,
    cfg_rprt_err_f,
    cfg_unsupt_req_det,

    master_data_perr_det,
    signaled_target_abort_det,
    rcvd_target_abort_det,
    rcvd_master_abort_det,
    signaled_sys_err_det,
    perr_det,
    master_data_perr_det2,
    signaled_target_abort_det2,
    rcvd_target_abort_det2,
    rcvd_master_abort_det2,
    signaled_sys_err_det2,
    perr_det2,

    sys_pre_det_state,
    sys_mrl_sensor_state,
    sys_atten_button_pressed,
    sys_pwr_fault_det,
    sys_mrl_sensor_chged,
    sys_pre_det_chged,
    sys_cmd_cpled_int,
    sys_eml_interlock_engaged,
    radm_set_slot_pwr_limit,
    radm_slot_pwr_payload,
    pm_status,
    pm_pme_en,
    aux_pm_en,

    radm_correctable_err,
    radm_nonfatal_err,
    radm_fatal_err,

    radm_pm_pme,
    radm_msg_req_id,

    flt_cdm_addr,

    app_ltr_msg_req,
    msg_ltr_det,
    msgg2cdm_ltr_clr_msg_grant,
    cdmpl2cfg_ltr_rq,
    ltr_m_en_fn0,
    cfg_disable_ltr_clr_msg,
    rbar_ctrl_update,
    cfg_rbar_bar0_mask,
    cfg_rbar_bar1_mask,
    cfg_rbar_bar2_mask,
    cfg_rbar_bar3_mask,
    cfg_rbar_bar4_mask,
    cfg_rbar_bar5_mask,
    cfg_rbar_bar_resizable,
    dbi_ro_wr_en,

    exp_rom_validation_status_strobe,
    exp_rom_validation_status,
    exp_rom_validation_details_strobe,
    exp_rom_validation_details,


    radm_drs_msg,
    smlh_ltssm_state,
    radm_snoop_upd,
    radm_snoop_bus_num,
    radm_snoop_dev_num,
    radm_pm_to_ack,
    pm_xmt_turnoff,
    rdlh_dlcntrl_state,
    app_clk_pm_en,
    cfg_config_limit,
    app_dev_num,                 // DEV# driven by application
    app_bus_num,

    cxl_rcrb_enable,  // CXL RCRB is enabled
    rcrb_base_addr, 
    rcrb_base_addr_valid,
    lbc_cdm_rcrb_dbi,
    current_data_rate,
    cxl_mode_enable,
    cxl_2_0_mbar0_offset,
    cxl2p0_enabled,
    cfg_cxl_2_0_ext_unmask_sbr,                // Unmask SBR
    cfg_cxl_2_0_ext_unmask_ld,                 // Unmask Link Disable
    cfg_cxl_2_0_ext_alt_mse,                   // Alternate Memory Space Enable 
    cfg_cxl_2_0_ext_alt_bme,                   // Alternate Bus Master Enable
    cfg_cxl_2_0_ext_alt_mem_base,              // Alternate Memory Base
    cfg_cxl_2_0_ext_alt_mem_limit,             // Alternate Memory Limit
    cfg_cxl_2_0_ext_alt_pref_mem_base,         // Alternate Prefetchable Memory Base
    cfg_cxl_2_0_ext_alt_pref_mem_limit,        // Alternate Memory Limit
    cfg_cxl_2_0_ext_alt_pref_mem_base_high,    // Alternate Prefetchable Memory Base High
    cfg_cxl_2_0_ext_alt_pref_mem_limit_high,   // Alternate Prefetchable Memory Base High

    flit_mode_enable,

    app_segment_id,
    radm_np_segment_id,
    cfg_segment_id_out,
// ------------ outputs --------------
    cfg_upd_pme_cap,
    cfg_io_match,
    cfg_config_above_match,
    cfg_rom_match,
    cfg_bar_match,
    cfg_bar_is_io,
    cfg_mem_match,
    cfg_prefmem_match,
    rcrb_address_reg,
    cfg_rcrb_match,
    cfg_rcrb_mbar0_match,
    rcrb_mbar0_base_addr,
    cfg_rcrb_mbar0_match_int,
    cfg_cxl_2_0_mbar0_match,
    cxl_2_0_mbar0_access_int,
    cfg_cxl_alt_mem_match,
    cfg_cxl_alt_prefmem_match,
    cfg_br_ctrl_serren,
    cfg_br_ctrl_perren,
    cfg_bus_master_en,
    cfg_reg_perren,
    cfg_reg_serren,
    cfg_sys_err_rc,
    cfg_2nd_reset_mod,
    cfg_slot_pwr_limit_wr,
    cfg_pcie_slot_pwr_limit,
    cfg_multi_msi_en,
    cfg_msi_ext_data_en,
    cfg_msi_en,
    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_msix_en,
    cfg_msix_func_mask,
    cfg_msix_table_size,
    cfg_msix_table_size2,
    cfg_msix_table_bir,
    cfg_msix_table_bir2,
    cfg_msix_table_offset,
    cfg_msix_table_offset2,
    cfg_msix_pba_bir,
    cfg_msix_pba_bir2,
    cfg_msix_pba_offset,
    cfg_msix_pba_offset2,
    cfg_vpd_int,
    cfg_max_payload_size_out,
    cfg_max_payload_size_out_rx,
    cfg_relax_ord_en,
    cfg_ext_tag_en,
    cfg_phantom_fun_en,
    cfg_aux_pm_en,
    cfg_no_snoop_en,
    cfg_max_rd_req_size,
    cfg_bridge_crs_en,
    cfg_aslk_pmctrl,
    cfg_upd_aslk_pmctrl_mux,
    cfg_clk_pm_en_mux,
    cfg_rcb_mux,
    cfg_link_dis_mux,
    cfg_link_retrain_mux,
    cfg_comm_clk_config_mux,
    cfg_hw_autowidth_dis_mux,
    cfg_link_rate,
    cfg_retimers_pre_detected,
    cfg_pwr_ind,
    cfg_atten_ind,
    cfg_pwr_ctrler_ctrl,
    cfg_hp_int_en,
    cfg_atten_button_pressed,
    cfg_eml_control,
    cfg_pwr_fault_det,
    cfg_mrl_sensor_chged,
    cfg_pre_det_chged,
    cfg_cmd_cpled_int,
    cfg_dll_state_chged,
    cfg_int_disable,
    cfg_cor_err_rpt_en,
    cfg_nf_err_rpt_en,
    cfg_f_err_rpt_en,
    cfg_unsupt_req_rpt_en,
    cfg_pbus_dev_num,
    cfg_pbus_num,
    cfg_2ndbus_num,
    cfg_subbus_num,
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
    cfg_cap_reg_data,
    cfg_cap_reg_ack,
    cfg_reg_data,
    cfg_reg_ack,
    cfg_upd_pmcsr,
    cfg_upd_aux_pm_en,
    cfg_upd_req_id,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_pme_cap,
    cfg_isa_enable,
    cfg_vga_enable,
    cfg_vga16_decode,
    cfg_int_pin,
    cfg_pme_int,
    cfg_crs_sw_vis_en,
    cfg_pme_msi,
    cfg_pm_no_soft_rst,
    cfg_link_auto_bw_int_mux,
    cfg_link_auto_bw_msi_mux,
    cfg_bw_mgt_int_mux,
    cfg_bw_mgt_msi_mux,
    cfg_pcie_max_link_speed,
    cfg_target_link_speed,
    cfg_enter_compliance_mux,
    cfg_hw_auto_sp_dis_mux,
    cfg_sel_de_emphasis_mux,
    cfg_transmit_margin_mux,
    cfg_enter_mod_compliance_mux,
    cfg_compliance_sos_mux,
    cfg_compliance_de_emphasis_mux,    
//    target_mem_map,
//    target_rom_map,
    cfg_atomic_req_en,
    cfg_atomic_egress_block,
    cfg_obff_en,
    cfg_ltr_m_en,
    cfg_ltr_clr_msg_req,
    cfg_pcie_aspm_cap_mux,
    cfg_pcie_max_link_width,
    cfg_pcie_cap_int_msg_num,
    cfg_ari_fwd_en,
    cfg_cpl_timeout_range_out,
    cfg_cpl_timeout_disable_out

    ,
    cfg_downstream_comp_pres_mux,
    cfg_drs_msi                  // interrupt generated by reception of DRS message
    ,
    cfg_up_drs_to_frs,            // pulse generated to top level when DRS message received and DRS to FRS enabled
    cfg_drs_frs_sig_en           // signal to show that DRS to FRS is enabled

    ,
    cfg_pcie_crosslink_supported
    , cfg_ls2_eq_req_mux
    ,
    cfg_end2end_tlp_pfx_blck,
    cfg_max_end2end_tlp_prfxs
    ,
    cfg_ido_req_en,
    cfg_ido_cpl_en
    ,
    cfg_10b_tag_req_en
    ,
    surprise_down_err
    ,
    cfg_pcie_surp_dn_rpt_cap_mux

    , 
    cfg_pcie_slot_clk_config_mux,
    cfg_auto_slot_pwr_lmt_dis,
    cfg_dll_state_chged_en, 
    cfg_hp_slot_ctrl_access, 
    cfg_cmd_cpled_int_en_r, 
    cfg_pre_det_chged_en, 
    cfg_mrl_sensor_chged_en_r, 
    cfg_pwr_fault_det_en_r, 
    cfg_atten_button_pressed_en_r
    ,cfg_neg_link_width
    ,cfg_pcie_cap_flit_mode_sup
    ,cfg_flit_mode_dis
    ,cfg_pcie_cap_flit_mode_stat
    ,cfg_flit_sris_clocking
);

parameter RCRB  = 0;                                              // This parameter is used to distinguish between the RCIEP cfg space and the RCRB cfg space
parameter INST  = 0;                                              // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM  = 0;                                          // uniquifying parameter per function
parameter NL    = (`CM_TXNL < `CM_RXNL) ? `CM_TXNL : `CM_RXNL ;   // Number of nallower lanes
parameter NF    = `CX_NFUNC;                                      // Number of functions
parameter MSI_NF = `CX_MSI_NFUNC; // Number of functions for MSI Cap
parameter VPD_NF = `CX_VPD_NFUNC;                                 // Number of functions for VPD Cap
parameter TP    = `TP;                          // Clock to Q delay (simulator insurance)

localparam FX_TLP = `CX_FX_TLP;                 // Number of TLPs received in a single cycle after formation block
localparam N_TRGT1_INTF        = `CX_RADM_NFC_TRGT_INTF;
localparam FX_TLP_ADR_DEC = FX_TLP - N_TRGT1_INTF;  // In MS, more than 1 address decodging is required and that is only for P and NP (For CPL TLP addr dec is not required) 

localparam MULTI_DEVICE_AND_BUS_PER_FUNC = `MULTI_DEVICE_AND_BUS_PER_FUNC_EN_VALUE;
localparam SNOOP_REG = `MULTI_DEVICE_AND_BUS_PER_FUNC_EN_VALUE ? 1 : (FUNC_NUM==0) ? 1 :  0;
localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs
// ----- Inputs ---------------
input           core_clk;                       // Core clock
input           non_sticky_rst_n;               // Reset for non-sticky registers
input           sticky_rst_n;                   // Reset for sticky registers
input           cdm_clk_g;                      // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [3:0]   device_type;                    // Device Type (EP/RC/etc)
// Local Bus
input           cfg_reg_sel;                    // cfg space register selected (0x0 - 0x3F)
input           cfg_cap_reg_sel;                // cfg capability space register selected (0x40 - 0xFF)
input           ecfg_reg_sel;                   // extended cfg capability space register selected (0x100-0x1FF)
input   [31:0]  lbc_cdm_addr;                   // Address of resource being accessed
input   [31:0]  lbc_cdm_data;                   // Data for write
input   [3:0]   lbc_cdm_wr;                     // Write byte enables: 4'b0000 = read
input           lbc_cdm_dbi;                    // DBI access to CDM
input           lbc_cdm_dbi2;                   // DBI2 access to CDM

// INT
input           int_msg_pending;                // internal INTx interrupt message is pending
// From Layer 2
input           rdlh_link_up;                   // Data Link Layer = DL_Active
// From Layer 1
input           smlh_link_up;                   // Layer 1 link is up
input   [5:0]   smlh_autoneg_link_width;        // negotiated link width
input   [3:0]   smlh_autoneg_link_sp;           // autonegotiation link speed
input           smlh_bw_mgt_status;             // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                // without the port transitioning through DL_Down status
input           smlh_link_auto_bw_status;       // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
input           smlh_link_training_in_prog;     // link trainging in progress
input           smlh_clr_enter_compliance;      // Signal the cdm that the "Enter Compliance" bit in the "Link Control" register should be cleared
input           smlh_tx_margin_rst;             // clear the transmit margin field
input           mac_phy_txdeemph;               // selects transmitter de-emphasis in the PHY.  0= -6dB, 1= -3.5dB
input           smlh_ls2_eq_req;                // Equalization Request
input  [3:1]    smlh_ls2_eq_success;            // Equalization Successful {Phase 3, Phase 2, Phase 1}
input           smlh_ls2_eq_cmpl;               // Equalization Complete
input           smlh_ls2_eq_enter;              // Equalization Entered
input           smlh_ltssm_in_detectquiet;
input           smlh_two_retimers_pre_detected; // Two Retimer were present during the latest Config.Complete
input  [1:0]    smlh_crosslink_resolution;      // indicates the state of crosslink resolution (00b:not supported,01b:Upstream port,11b:not completed)
input           smlh_retimer_pre_detected;      // Retimer was present during the latest Config.Complete

input           aux_pwr_det;                    // Aux Power is detected by the device
input           radm_cpl_pending;               // device has issued Non-posted requests which have not been completed

// ERRORS
input           cfg_cor_err_det;                // Correctable error detected
input           cfg_nf_err_det;                 // Non-fatal error detected
input           cfg_f_err_det;                  // Fatal error detected
input           cfg_rprt_err_cor;               // System Error factor by Correctable Error
input           cfg_rprt_err_nf;                // System Error factor by Non-Fatal Error
input           cfg_rprt_err_f;                 // System Error factor by Fatal Error
input           cfg_unsupt_req_det;             // Non-advisory unsupported request error detected
input           master_data_perr_det;
input           signaled_target_abort_det;
input           rcvd_target_abort_det;
input           rcvd_master_abort_det;
input           signaled_sys_err_det;
input           perr_det;
input           master_data_perr_det2;
input           signaled_target_abort_det2;
input           rcvd_target_abort_det2;
input           rcvd_master_abort_det2;
input           signaled_sys_err_det2;
input           perr_det2;

// Slot
input           sys_pre_det_state;              // Indicates the presence of a card in the slot
input           sys_mrl_sensor_state;           // Reports the status of the MRL sensor if it is implemented
input           sys_atten_button_pressed;       // Attention button is pressed or receive a message from end device
input           sys_pwr_fault_det;              // Indicates a fault in the power controller
input           sys_mrl_sensor_chged;           // Indicates the value of the MRL Sensor state had changed
input           sys_pre_det_chged;              // Indicates Presence Detect had changed
input           sys_cmd_cpled_int;              // this bit when set enables the generation of hot plug interrupt when a command is completed by hot plug control logic
input           sys_eml_interlock_engaged;      // Electromechanical Interlock engaged

input           radm_set_slot_pwr_limit;        // Capture Slot Power Value/Scale from payload below
input   [31:0]  radm_slot_pwr_payload;          // Extracted MSG payload

input           pm_status;                      // sticky bit, preserved in PMC during Aux power
input           pm_pme_en;                      // sticky bit, preserved in PMC during Aux power
input           aux_pm_en;                      // sticky bit, preserved in PMC during Aux power

// for Root Status register
// Received error messages
input           radm_correctable_err;           // Received Correctable Error MSG
input           radm_nonfatal_err;              // Received Non-Fatal Uncorrectable Error MSG
input           radm_fatal_err;                 // Received Fatal Uncorrectable Error MSG
input   [MSG_TLP_WD-1:0]            radm_pm_pme;                    // Received a PME
input   [(MSG_TLP_WD*16)-1:0]       radm_msg_req_id;                // Requester ID of the above PME

// for filter address decoding
input    [((FX_TLP-N_TRGT1_INTF)*64)-1:0]           flt_cdm_addr;



input           app_ltr_msg_req;                // LTR message request - from Application interface
input           msg_ltr_det;              // LTR message grant   - from Message Generation (msg_gen) module
input           msgg2cdm_ltr_clr_msg_grant;     // LTR clear message grant
input           cdmpl2cfg_ltr_rq;               // Port logic to PCIe configuration OR'ed LTR message requirement bits
input           ltr_m_en_fn0;                   // LTR mechanism enable, function 0.
input           cfg_disable_ltr_clr_msg;        // Disable LTR clear messaage.
input          rbar_ctrl_update;               // indicates that RBAR control register has been updated
input   [63:0] cfg_rbar_bar0_mask;             // Resizable BAR0 mask
input   [31:0] cfg_rbar_bar1_mask;             // Resizable BAR1 mask
input   [63:0] cfg_rbar_bar2_mask;             // Resizable BAR2 mask
input   [31:0] cfg_rbar_bar3_mask;             // Resizable BAR3 mask
input   [63:0] cfg_rbar_bar4_mask;             // Resizable BAR4 mask
input   [31:0] cfg_rbar_bar5_mask;             // Resizable BAR5 mask
input   [5:0]  cfg_rbar_bar_resizable;         // Resize BAR[N] mask where N = 0 to 5
input          dbi_ro_wr_en;
input          exp_rom_validation_status_strobe;
input [2:0]    exp_rom_validation_status;
input          exp_rom_validation_details_strobe;
input [3:0]    exp_rom_validation_details;

input [MSG_TLP_WD-1:0] radm_drs_msg;
input ltssm_state_e    smlh_ltssm_state;
//For a Downstream Port, this bit must be Set if the component supports the optional capability of detecting and reporting a Surprise Down error condition.
input                       radm_pm_to_ack;          // Received PM_TO_ACK.
input                       pm_xmt_turnoff;          // Request this port to send turnoff message
wire upstream_surprise_down;
assign upstream_surprise_down = 1'b0;        // No Upstrem Surprise Down
input [1:0]                 rdlh_dlcntrl_state;      // DLCM state machine signal
input                       app_clk_pm_en; // enable the clock power management capability
input [9:0]                 cfg_config_limit; // CONFIG_LIMIT_REG
input [4:0]                 app_dev_num; // DEV# from application
input [7:0]                 app_bus_num; // BUS# from application
input                       cxl_rcrb_enable;
input   [63:12]             rcrb_base_addr;
input                       rcrb_base_addr_valid;
input                       lbc_cdm_rcrb_dbi;
input   [2:0]               current_data_rate;
input                       cxl_mode_enable;
input  [63:0]               cxl_2_0_mbar0_offset;                      // Offset of CXL 2.0 MEMBAR0 in Func0, BAR0
input                       cxl2p0_enabled;                            // Indicates link is up in CXL 2.0 mode
input                       cfg_cxl_2_0_ext_unmask_sbr;                // Unmask SBR
input                       cfg_cxl_2_0_ext_unmask_ld;                 // Unmask Link Disable
input                       cfg_cxl_2_0_ext_alt_mse;                   // Alternate Memory Space Enable 
input                       cfg_cxl_2_0_ext_alt_bme;                   // Alternate Bus Master Enable
input  [11:0]               cfg_cxl_2_0_ext_alt_mem_base;              // Alternate Memory Base
input  [11:0]               cfg_cxl_2_0_ext_alt_mem_limit;             // Alternate Memory Limit
input  [11:0]               cfg_cxl_2_0_ext_alt_pref_mem_base;         // Alternate Prefetchable Memory Base
input  [11:0]               cfg_cxl_2_0_ext_alt_pref_mem_limit;        // Alternate Memory Limit
input  [31:0]               cfg_cxl_2_0_ext_alt_pref_mem_base_high;    // Alternate Prefetchable Memory Base High
input  [31:0]               cfg_cxl_2_0_ext_alt_pref_mem_limit_high;   // Alternate Prefetchable Memory Base High

input                       flit_mode_enable;

input [8:0]                 app_segment_id;
input [8:0]                 radm_np_segment_id;
output logic [8:0]          cfg_segment_id_out;

// ---------- Outputs --------
output                          cfg_upd_pme_cap;                // Update cfg_pme_cap in pm_ctrl
output  [5:0]                   cfg_bar_is_io;                  // Indicates whether the BAR is set as IO or memory
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_io_match;                   // Within IO address range
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_config_above_match;         // Adress is above certain user configuration limit
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_rom_match;                  // Within expansion ROM address range
output  [((FX_TLP-N_TRGT1_INTF)*6)-1:0]        cfg_bar_match;                  // Within BAR range
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_mem_match;                  // Within Memory range (Type 1 only)
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_prefmem_match;              // Within Prefetchable Memorey range (Type 1 only)
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_cxl_2_0_mbar0_match;        // Within CXL2.0 MBAR0 Memory Range
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cxl_2_0_mbar0_access_int;        // Within CXL2.0 MBAR0 Memory Range
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_cxl_alt_mem_match;          // Within Alternate Memory Range
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_cxl_alt_prefmem_match;      // Within Prefetchable Alternate Memory Range

output  [63:0]                                 rcrb_mbar0_base_addr;   
output  [63:12]                                rcrb_address_reg;               //registering the input RADM Snoop RCRB Base Address in cdm_bar_match
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_rcrb_match;                 //The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_rcrb_mbar0_match;           //RCRB MEMBAR0 for configuring the CXL subsystem components 
output  [(FX_TLP-N_TRGT1_INTF)-1:0]            cfg_rcrb_mbar0_match_int;           //RCRB MEMBAR0 for configuring the CXL subsystem components in CDM





output                          cfg_slot_pwr_limit_wr;              // configuration write to slot capability register trigging set_slot_pwr_limit message.
output  [9:0]                   cfg_pcie_slot_pwr_limit;            // Current setting of slot power limit value[7:0] & scale[9:8]
output  [31:0]                  cfg_reg_data;                       // Read data back from core
output  [31:0]                  cfg_cap_reg_data;                   // Read data back from core
output                          cfg_reg_ack;                        // Acknowledge back from core. Indicates completion, read data is valid
output                          cfg_cap_reg_ack;                    // Acknowledge back from core. Indicates completion, read data is valid
output                          cfg_relax_ord_en;                   // Relax Ordering enable
output  [2:0]                   cfg_max_payload_size_out;           // Max payload size configured
output  [2:0]                   cfg_max_payload_size_out_rx;        // In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field and this only goes to the TLP check logic inside the radm multi-stream.
output                          cfg_ext_tag_en;                     // Extended tag field enable (optional feature - always 0)
output                          cfg_phantom_fun_en;                 // Phantom Function enable
output                          cfg_no_snoop_en;                    // No snoop enable
output  [2:0]                   cfg_max_rd_req_size;                // Max read request size
output                          cfg_bridge_crs_en;                  // Bridge Configuration Retry Enable (Bridge only)
output  [1:0]                   cfg_aslk_pmctrl;                    // active state PM control
output                          cfg_upd_aslk_pmctrl_mux;            // Register the aslk_pmctrl in pm_ctrl
output                          cfg_clk_pm_en_mux;                  // Clock PM enable
output                          cfg_rcb_mux;                        // RO for root complex
output                          cfg_link_dis_mux;                   // link disable, not applied to endpoint device and Upstream port of a switch
output                          cfg_link_retrain_mux;               // link retrain, not applied to endpoint device and Upstream port of a switch
output                          cfg_comm_clk_config_mux;            // common clock configuration
output                          cfg_hw_autowidth_dis_mux;           // HW autonomous width disable
output                          cfg_ext_synch;                      // Extended Synch
output                          cfg_io_space_en;                    // IO Space enable
output                          cfg_mem_space_en;                   // Memory space enable
// LINK
output  [3:0]   cfg_link_rate;                  // Maximum link speed
output  [1:0]   cfg_retimers_pre_detected;      // Retimers present detected {retimer2,retimer1}
// Slot
output  [1:0]   cfg_pwr_ind;                    // trigger power indicator message
output  [1:0]   cfg_atten_ind;                  // trigger attention indicator message
output          cfg_pwr_ctrler_ctrl;            // Power controller control - 0: Power on, 1: Power off.
output          cfg_hp_int_en;                  // Hot Plug interrupt enable
output          cfg_atten_button_pressed;       // Attention button pressed
output          cfg_eml_control;                // Electromechanical Interlock Control (pulse)
output          cfg_pwr_fault_det;              // Power fault detected
output          cfg_mrl_sensor_chged;           // MRL sensor changed
output          cfg_pre_det_chged;              // Presence detect changed
output          cfg_cmd_cpled_int;              // Command completed interrupt
output          cfg_dll_state_chged;            // Data Link Layer State Changed

// PME
output          cfg_aux_pm_en;                  // AUX power PM enable
output          cfg_upd_req_id;                 // Update requester ID field
output          cfg_upd_aux_pm_en;              // Update aux_pm_en signal in PMC
output          cfg_upd_pmcsr;                  // Update PMCSR in PMC
output          cfg_pmstatus_clr;               // Clear PM status in PMC
output  [2:0]   cfg_pmstate;                    // Power state
output          cfg_pme_en;                     // PME enable bit
output  [4:0]   cfg_pme_cap;                    // PME Capability

// MSI
output          cfg_int_disable;                // Interrupt disable
output  [2:0]   cfg_multi_msi_en;               // Multiple MSI enable
output          cfg_msi_ext_data_en;            // Extended message data for MSI enable        
output          cfg_msi_en;                     // MSI enable
output  [63:0]  cfg_msi_addr;                   // MSI address
output  [31:0]  cfg_msi_data;                   // MSI data field
output          cfg_msi_64;                     // 64 bits MSI addressing enable
// MSI-X
input   [NF-1:0] radm_snoop_upd;
input   [7:0]    radm_snoop_bus_num;
input   [4:0]    radm_snoop_dev_num;
output          cfg_msix_en;                    // MSI-X enable
output          cfg_msix_func_mask;             // MSI-X Function Mask
output  [10:0]  cfg_msix_table_size;            // MSI-X Table Size
output  [10:0]  cfg_msix_table_size2;           // MSI-X Table Size - second independent value exported to VFs
output  [2:0]   cfg_msix_table_bir;             // MSI-X Table BIR
output  [2:0]   cfg_msix_table_bir2;            // MSI-X Table BIR  - second independent value exported to VFs
output  [28:0]  cfg_msix_table_offset;          // MSI-X Table Offset
output  [28:0]  cfg_msix_table_offset2;         // MSI-X Table Offset - second independent value exported to VFs
output  [2:0]   cfg_msix_pba_bir;               // MSI-X PBA BIR
output  [2:0]   cfg_msix_pba_bir2;              // MSI-X PBA BIR - second independent value exported to VFs
output  [28:0]  cfg_msix_pba_offset;            // MSI-X PBA Offset
output  [28:0]  cfg_msix_pba_offset2;           // MSI-X PBA Offset - second independent value exported to VFs

// VPD
output logic    cfg_vpd_int;                    // VPD Interrupt to application

// to ERR GEN
output          cfg_cor_err_rpt_en;             // Correctable error reporting enable
output          cfg_nf_err_rpt_en;              // Non-fatal error reporting enable
output          cfg_f_err_rpt_en;               // Fatal error reporting enable
// to ERR REG
output          cfg_unsupt_req_rpt_en;          // Unsupported error reporting enable

// Only for Type 1
output  [4:0]   cfg_pbus_dev_num;                    // Device number
output  [7:0]   cfg_pbus_num;                   // Bus number
output  [7:0]   cfg_2ndbus_num;                 // Secondary bus number
output  [7:0]   cfg_subbus_num;                 // Subordinary bus number

output          cfg_2nd_reset_mod;              // Secondary reset

output  [63:0]  cfg_bar0_start;                 // BAR0 start address
output  [63:0]  cfg_bar0_limit;                 // BAR0 limit address
output  [63:0]  cfg_bar0_mask;                  // BAR0 mask register
output  [31:0]  cfg_bar1_start;                 // BAR1 start address
output  [31:0]  cfg_bar1_limit;                 // BAR1 limit address
output  [31:0]  cfg_bar1_mask;                  // BAR1 mask register
output  [63:0]  cfg_bar2_start;                 // BAR2 start address
output  [63:0]  cfg_bar2_limit;                 // BAR2 limit address
output  [63:0]  cfg_bar2_mask;                  // BAR2 mask register
output  [31:0]  cfg_bar3_start;                 // BAR3 start address
output  [31:0]  cfg_bar3_limit;                 // BAR3 limit address
output  [31:0]  cfg_bar3_mask;                  // BAR3 mask register
output  [63:0]  cfg_bar4_start;                 // BAR4 start address
output  [63:0]  cfg_bar4_limit;                 // BAR4 limit address
output  [63:0]  cfg_bar4_mask;                  // BAR4 mask register
output  [31:0]  cfg_bar5_start;                 // BAR5 start address
output  [31:0]  cfg_bar5_limit;                 // BAR5 limit address
output  [31:0]  cfg_bar5_mask;                  // BAR5 mask register
output  [31:0]  cfg_rom_mask;                   // ROM BAR mask register
output  [15:0]  cfg_mem_base;                   // Memory start address
output  [15:0]  cfg_mem_limit;                  // Memory limit address
output  [63:0]  cfg_pref_mem_base;              // Prefetchable memory start address
output  [63:0]  cfg_pref_mem_limit;             // Prefetchable memory limit address
output  [31:0]  cfg_exp_rom_start;              // Expansion ROM start address
output  [31:0]  cfg_exp_rom_limit;              // Expansion ROM limit address
output  [15:0]  cfg_io_base_upper16;            // Upper 16 bit IO base address
output  [15:0]  cfg_io_limit_upper16;           // Upper 16 bit IO limit address
output  [7:0]   cfg_io_base;                    // IO base address
output  [7:0]   cfg_io_limit;                   // IO limit address
output  [7:0]   cfg_hdr_type;                   // Header type
output          cfg_br_ctrl_serren;             // Bridge Control: SERR Enable
output          cfg_br_ctrl_perren;             // Bridge Control: Parity Error Response Enable
output          cfg_bus_master_en;              // Bus master enable
output          cfg_reg_perren;                 // Parity error response enable
output          cfg_reg_serren;                 // SERR# enable
output          cfg_sys_err_rc;                 // System Error (RC Only)
output          cfg_isa_enable;                 // For bridge: ISA enable
output          cfg_vga_enable;                 // For bridge: VGA enable (optional)
output          cfg_vga16_decode;               // For bridge: VGA 16-bit decode (optional)
output  [7:0]   cfg_int_pin;                    // Interrupt Pin mapping
output          cfg_crs_sw_vis_en;              // Root ctrl CRS Software Visibility feature enable
output          cfg_pme_int;                    // Interrupt caused by PME (RC Only)
output          cfg_pme_msi;                    // MSI caused by PME (RC Only)
output  [4:0]   cfg_pcie_cap_int_msg_num;       // MSI Message Data if multiple MSI is supported
output  [3:0]   cfg_cpl_timeout_range_out;          // Completion Timeout range programmed
output          cfg_cpl_timeout_disable_out;        // Completion Timeout disable
output          cfg_ari_fwd_en;                 // ARI forwarding enable
output          cfg_link_auto_bw_int_mux;           // Interrupt indicating that Link Bandwidth Management Status bit has been set
output          cfg_link_auto_bw_msi_mux;           // MSI indicating that Link Bandwidth Management Status bit has been set
output          cfg_bw_mgt_int_mux;             // Interrupt indicating that Link Autonomous Bandwidth Status bit has been set
output          cfg_bw_mgt_msi_mux;                 // MSI indicating that Link Autonomous Bandwidth Status bit has been set
output  [3:0]   cfg_pcie_max_link_speed;        // Max link speed
output  [3:0]   cfg_target_link_speed;          // Target link speed
output          cfg_enter_compliance_mux;           // Directed enter compliance
output          cfg_hw_auto_sp_dis_mux;             // HW autonomous speed disable
output          cfg_sel_de_emphasis_mux;            // level of de emphasis
output  [2:0]   cfg_transmit_margin_mux;            // controls the value of the non-deemphasized voltage level at the Transmitter pins.
output          cfg_enter_mod_compliance_mux;       // Directed enter modified compliance
output          cfg_compliance_sos_mux;             // Send skips during compliance
output  [3:0]   cfg_compliance_de_emphasis_mux;     // Compliance Preset/de-emphasis level
output          cfg_pm_no_soft_rst;             // no soft reset control
//output  [5:0]   target_mem_map;                 // Each bit of this vector indicates which target receives memory transactions for that bar #
//output          target_rom_map;                 // Each bit of this vector indicates which target receives rom    transactions for that bar #
output          cfg_atomic_req_en;              // Atomic Op Requester Enable
output          cfg_atomic_egress_block;        // Atomic Egress Block Enable
output  [1:0]   cfg_obff_en;                    // OBFF support enable, indicates support by message or WAKE.
output          cfg_ltr_m_en;                   // LTR Mechanism enable, enables the Upstream Ports to send LTR messages
                                                // and Downstream Ports to process LTR messages.
output          cfg_ltr_clr_msg_req;            // LTR clear message request
output [1:0]    cfg_pcie_aspm_cap_mux;
output [5:0]    cfg_pcie_max_link_width;



output cfg_drs_msi;
output [2:0] cfg_downstream_comp_pres_mux;
output cfg_up_drs_to_frs;
output cfg_drs_frs_sig_en;   

output cfg_pcie_crosslink_supported;
output cfg_ls2_eq_req_mux;
output          cfg_end2end_tlp_pfx_blck;    // TLP Prefix of type End-End blocking control bit.
output  [1:0]   cfg_max_end2end_tlp_prfxs;   // the maximum number of End-End TLP Prefixes supported; DBI writeable.
output          cfg_ido_req_en;                 // IDO requester enabled
output          cfg_ido_cpl_en;                 // IDO completer enabled
output          cfg_10b_tag_req_en;         // 10 bits TAG requester enable
output surprise_down_err;
output cfg_pcie_surp_dn_rpt_cap_mux;

output    cfg_pcie_slot_clk_config_mux;
output    cfg_auto_slot_pwr_lmt_dis;    // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.
output    cfg_dll_state_chged_en;
output    cfg_hp_slot_ctrl_access; 
output    cfg_cmd_cpled_int_en_r; 
output    cfg_pre_det_chged_en; 
output    cfg_mrl_sensor_chged_en_r; 
output    cfg_pwr_fault_det_en_r; 
output    cfg_atten_button_pressed_en_r;

output [5:0]   cfg_neg_link_width;
output         cfg_pcie_cap_flit_mode_sup;    
output         cfg_flit_mode_dis;    
output         cfg_pcie_cap_flit_mode_stat;    
output         cfg_flit_sris_clocking;    
// Output registers
//
reg             cfg_cor_err_rpt_en;
reg             cfg_nf_err_rpt_en;
reg             cfg_f_err_rpt_en;
reg             cfg_unsupt_req_rpt_en;
reg     [7:0]   cfg_pbus_num_reg;
reg     [4:0]   r_dev_num_snooped;
reg     [7:0]   cfg_2ndbus_num;
reg             cfg_2nd_reset;
reg             cfg_2nd_reset_mod;

reg             cfg_slot_pwr_limit_wr;
reg     [31:0]  cfg_cap_reg_data;
reg             cfg_cap_reg_ack;
reg     [31:0]  cfg_reg_data;
reg             cfg_reg_ack;
reg             cfg_relax_ord_en;
reg             cfg_ext_tag_en;
reg             cfg_phantom_fun_en;
reg             cfg_no_snoop_en;
reg     [2:0]   cfg_max_rd_req_size;
reg             cfg_bridge_crs_en;
reg             cfg_ext_synch_int;
wire            cfg_ext_synch;
reg             cfg_hw_autowidth_dis;
wire            cfg_hw_autowidth_dis_mux;
assign          cfg_hw_autowidth_dis_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_hw_autowidth_dis;
reg     [31:0]  cfg_pref_base_upper32;
reg     [31:0]  cfg_pref_limit_upper32;
reg     [15:0]  cfg_io_limit_upper16;
reg     [15:0]  cfg_io_base_upper16;
wire    [3:0]   cfg_link_rate;
wire    [15:0]  cfg_mem_base;
wire    [15:0]  cfg_mem_limit;
wire    [63:0]  cfg_pref_mem_base;
wire    [63:0]  cfg_pref_mem_limit;
reg     [31:0]  cfg_exp_rom_start;
reg     [31:0]  cfg_exp_rom_limit;
reg     [4:0]   cfg_pcie_cap_int_msg_num;
reg             cfg_cpl_timeout_disable;
reg     [3:0]   cfg_cpl_timeout_range;
reg             cfg_ari_fwd_en;
reg             cfg_ido_req_en;
reg             cfg_ido_cpl_en;
reg             cfg_atomic_req_en;
reg             cfg_atomic_egress_block;
reg     [1:0]   cfg_obff_en;
reg             ltr_m_en_r;                     // Device Control / Status 2 "LTR Mechanism Enable" bit
wire    [3:0]   cfg_pcie_max_link_speed;
reg     [3:0]   cfg_pcie_max_link_speed_int;
reg             cfg_link_auto_bw_int;
reg             cfg_bw_mgt_int;
wire            cfg_link_auto_bw_int_mux;
wire            cfg_bw_mgt_int_mux;
assign          cfg_link_auto_bw_int_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_link_auto_bw_int;
assign          cfg_bw_mgt_int_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_bw_mgt_int;
reg     [3:0]   int_target_link_speed;
reg             cfg_enter_compliance;           // Directed enter compliance
reg             cfg_hw_auto_sp_dis;             // HW autonomous speed disable
reg             cfg_sel_de_emphasis;
reg     [2:0]   cfg_transmit_margin;            // controls the value of the non-deemphasized voltage level at the Transmitter pins.
reg             cfg_enter_mod_compliance;
reg             cfg_compliance_sos;
reg     [3:0]   cfg_compliance_de_emphasis;
wire            cfg_enter_compliance_mux;
wire            cfg_hw_auto_sp_dis_mux;
wire            cfg_sel_de_emphasis_mux;
wire [2:0]      cfg_transmit_margin_mux;            // controls the value of the non-deemphasized voltage level at the Transmitter pins.
wire            cfg_enter_mod_compliance_mux;
wire            cfg_compliance_sos_mux;
wire    [3:0]   cfg_compliance_de_emphasis_mux;

assign          cfg_hw_auto_sp_dis_mux   = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_hw_auto_sp_dis;
assign          cfg_enter_compliance_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_enter_compliance;
assign          cfg_sel_de_emphasis_mux  = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_sel_de_emphasis;
assign          cfg_transmit_margin_mux  = (cxl_rcrb_enable & ~(|RCRB)) ? 3'd0 : cfg_transmit_margin;
assign          cfg_enter_mod_compliance_mux   = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_enter_mod_compliance;
assign          cfg_compliance_sos_mux         = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_compliance_sos;
assign          cfg_compliance_de_emphasis_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 4'd0 : cfg_compliance_de_emphasis;

wire  [FX_TLP-1:0][63:12]                  rcrb_address_reg_int;             //registering the input RADM Snoop RCRB Base Address in cdm_bar_match
assign          rcrb_address_reg = rcrb_address_reg_int[0];

//wire    [5:0]   target_mem_map;                 // Each bit of this vector indicates which target receives memory transactions for that bar #
//wire            target_rom_map;                 // Each bit of this vector indicates which target receives rom    transactions for that bar #
//`ifdef CX_SRIOV_ENABLE
//wire   [5:0]    vf_target_mem_map;             // Each bit of this vector indicates which target receives memory transactions for that bar #
//`endif // CX_SRIOV_ENABLE

wire app_ltr_msg_req;                // LTR message request - from Application interface
wire msg_ltr_det;              // LTR message grant   - from Message Generation (msg_gen) module
wire cfg_ltr_clr_msg_req;
wire cfg_ltr_m_en;

reg             cfg_drs_support;//DRS supported
reg             cfg_drs_msg_rec_reg;
reg [2:0]       cfg_downstream_comp_pres;
wire [2:0]       cfg_downstream_comp_pres_mux;
assign           cfg_downstream_comp_pres_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 3'd0 : cfg_downstream_comp_pres;
reg [1:0]       cfg_drs_sig_control;
reg             cfg_frs_support;

// Internal Signal Declarations
reg     [15:0]  cfg_reg_id;
reg     [29:0]  cfg_cap_reg_id;
reg     [7:0]   int_line_reg;
reg             cfg_br_ctrl_perren;
reg             cfg_br_ctrl_serren;
reg             cfg_aux_pm_en;
reg             cfg_cor_err_det_reg;
reg             cfg_nf_err_det_reg;
reg             cfg_f_err_det_reg;
reg             cfg_unsupt_req_det_reg;
reg             cfg_link_retrain;               // retrain link
wire            cfg_link_retrain_mux;
assign          cfg_link_retrain_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_link_retrain;
wire    [1:0]   pm_reg_id;                      // PM cap. structure addr. decode
wire    [31:0]  pm_reg_data;                    // PM cap. structure read-back data
wire    [5:0]   msi_reg_id;                     // MSI cap. structure addr. decode
wire    [31:0]  msi_reg_data;                   // MSI cap. structure read-back data
reg     [7:0]   rcvd_slot_pwr_limit_val;        // specifies that upper limit on power supplied by slot
reg     [1:0]   rcvd_slot_pwr_limit_scale;      // specifies the scale used for the slot power limit value

wire    [7:0]   cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0;
wire    [7:0]   cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4;
wire    [7:0]   cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8;
wire    [7:0]   cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12;
wire    [7:0]   cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16;
wire    [7:0]   cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20;
wire    [7:0]   cfg_reg_27, cfg_reg_26, cfg_reg_25, cfg_reg_24;
wire    [7:0]   cfg_reg_30, cfg_reg_31, cfg_reg_29, cfg_reg_28;
wire    [7:0]   cfg_reg_35, cfg_reg_34, cfg_reg_33, cfg_reg_32;
wire    [7:0]   cfg_reg_39, cfg_reg_38, cfg_reg_37, cfg_reg_36;
wire    [7:0]   cfg_reg_43, cfg_reg_42, cfg_reg_41, cfg_reg_40;
wire    [7:0]   cfg_reg_47, cfg_reg_46, cfg_reg_45, cfg_reg_44;
wire    [7:0]   cfg_reg_51, cfg_reg_50, cfg_reg_49, cfg_reg_48;
wire    [7:0]   cfg_reg_55, cfg_reg_54, cfg_reg_53, cfg_reg_52;
wire    [7:0]   cfg_reg_59, cfg_reg_58, cfg_reg_57, cfg_reg_56;
wire    [7:0]   cfg_reg_63, cfg_reg_61, cfg_reg_62, cfg_reg_60;
wire    [7:0]   cfg_reg_67, cfg_reg_66, cfg_reg_65, cfg_reg_64;
wire    [7:0]   cfg_reg_71, cfg_reg_70, cfg_reg_69, cfg_reg_68;
//wire    [7:0]   cfg_reg_75, cfg_reg_74, cfg_reg_73, cfg_reg_72;
//wire    [7:0]   cfg_reg_79, cfg_reg_78, cfg_reg_77, cfg_reg_76;
//reg     [7:0]   cfg_reg_83, cfg_reg_82, cfg_reg_81, cfg_reg_80;
//reg     [7:0]   cfg_reg_85, cfg_reg_84, cfg_reg_87, cfg_reg_86;
wire    [7:0]   cfg_reg_91, cfg_reg_90, cfg_reg_89, cfg_reg_88;
wire    [7:0]   cfg_reg_95, cfg_reg_94, cfg_reg_93, cfg_reg_92;
wire    [7:0]   cfg_reg_96, cfg_reg_97, cfg_reg_98, cfg_reg_99;
wire    [7:0]   cfg_reg_100, cfg_reg_101, cfg_reg_102, cfg_reg_103;
wire    [7:0]   cfg_reg_107, cfg_reg_106, cfg_reg_105, cfg_reg_104;
wire    [7:0]   cfg_reg_111, cfg_reg_110, cfg_reg_109, cfg_reg_108;
wire    [7:0]   cfg_reg_115, cfg_reg_114, cfg_reg_113, cfg_reg_112;
wire    [7:0]   cfg_reg_119, cfg_reg_118, cfg_reg_117, cfg_reg_116;
wire    [7:0]   cfg_reg_123, cfg_reg_122, cfg_reg_121, cfg_reg_120;
wire    [7:0]   cfg_reg_127, cfg_reg_126, cfg_reg_125, cfg_reg_124;
wire    [7:0]   cfg_reg_131, cfg_reg_130, cfg_reg_129, cfg_reg_128;
wire    [7:0]   cfg_reg_135, cfg_reg_134, cfg_reg_133, cfg_reg_132;
wire    [7:0]   cfg_reg_139, cfg_reg_138, cfg_reg_137, cfg_reg_136;
wire    [7:0]   cfg_reg_143, cfg_reg_142, cfg_reg_141, cfg_reg_140;   // Device Cap 2
wire    [7:0]   cfg_reg_147, cfg_reg_146, cfg_reg_145, cfg_reg_144;   // Device Control & Status 2
wire    [7:0]   cfg_reg_151, cfg_reg_150, cfg_reg_149, cfg_reg_148;   // Link Capabilities 2
wire    [7:0]   cfg_reg_155, cfg_reg_154, cfg_reg_153, cfg_reg_152;     // Link Control & Status 2
//wire    [7:0]   cfg_reg_159, cfg_reg_158, cfg_reg_157, cfg_reg_156;   // Slot Capabilities 2
//wire    [7:0]   cfg_reg_163, cfg_reg_162, cfg_reg_161, cfg_reg_160;   // Slot Control & Status 2
wire    [7:0]   cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164;
wire    [7:0]   cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168;
//reg     [7:0]   cfg_reg_175, cfg_reg_174, cfg_reg_173, cfg_reg_172;
//wire    [7:0]   cfg_reg_179, cfg_reg_178, cfg_reg_177, cfg_reg_176;
wire    [7:0]   cfg_reg_175, cfg_reg_174, cfg_reg_173, cfg_reg_172;
wire    [7:0]   cfg_reg_179, cfg_reg_178, cfg_reg_177, cfg_reg_176;
wire    [7:0]   cfg_reg_183, cfg_reg_182, cfg_reg_181, cfg_reg_180;

reg             reg_read_pulse;
reg             cap_reg_read_pulse;
reg     [7:0]   cfg_subbus_num;
reg     [1:0]   cfg_aslk_pmctrl_int;
wire            int_upd_aslk_pmctrl;
reg             cfg_upd_aslk_pmctrl;
reg             cfg_clk_pm_en;
reg             cfg_comm_clk_config;
reg             cfg_rcb;
reg             cfg_link_dis_reg;
wire            cfg_link_dis;
wire            cfg_upd_aslk_pmctrl_mux;
wire            cfg_clk_pm_en_mux;
wire            cfg_comm_clk_config_mux;
wire            cfg_rcb_mux;
wire            cfg_link_dis_mux;
assign          cfg_comm_clk_config_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_comm_clk_config;
assign          cfg_clk_pm_en_mux       = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_clk_pm_en;
assign          cfg_rcb_mux             = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_rcb;
assign          cfg_upd_aslk_pmctrl_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_upd_aslk_pmctrl;
assign          cfg_link_dis_mux        = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_link_dis;
reg             cfg_pwr_ctrler_ctrl;
reg     [1:0]   cfg_pwr_ind;
reg     [1:0]   cfg_atten_ind;
reg             cfg_hp_int_en;
reg             cfg_eml_control;
reg             cfg_dll_state_chged_en;
reg             cfg_auto_slot_pwr_lmt_dis; // Auto Slot Power Limit Disable field of Slot Control Register
wire    [31:0]  cfg_msi_mask;

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
assign switch_device    = pcie_sw_up | pcie_sw_down;
assign pcie_br_up       = (device_type == `PCIE_PCIX);
assign pcie_br_down     = (device_type == `PCIX_PCIE);
assign bridge_device    = pcie_br_up | pcie_br_down;
assign upstream_port    = end_device | pcie_br_up | pcie_sw_up;

// Config space type
wire    type0;                      // Type 0 configuration space
assign  type0 = end_device;         // Only endpoint devices is a Type 0


wire msix_cap_enable;
assign msix_cap_enable      = `MSIX_CAP_ENABLE;
wire msi_cap_enable;
assign msi_cap_enable       = `MSI_CAP_ENABLE;
wire vpd_cap_enable;
assign vpd_cap_enable       = `VPD_CAP_ENABLE;
wire slot_cap_enable;
assign slot_cap_enable      = `SLOT_CAP_ENABLE;
wire sata_cap_enable;
assign sata_cap_enable      = `SATA_CAP_ENABLE;

wire dbi_ro_wr_en;
wire int_lbc_cdm_dbi_only   = lbc_cdm_dbi & ~lbc_cdm_dbi2;
wire int_lbc_cdm_dbi        = int_lbc_cdm_dbi_only & dbi_ro_wr_en;
wire int_lbc_cdm_dbi2       = lbc_cdm_dbi2 & dbi_ro_wr_en;

wire [5:0] cfg_bar_enabled;
wire has_mem_bar;
wire has_io_bar;
wire [5:0] cfg_bar_is_io_int;

// =============================================================================
// Adding BCM36 for falsepath
// =============================================================================

// =============================================================================
// Capture Set Slot Power messages
// =============================================================================

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        rcvd_slot_pwr_limit_val     <= #TP 0;
        rcvd_slot_pwr_limit_scale   <= #TP 0;
    end else begin
        rcvd_slot_pwr_limit_val     <= #TP radm_set_slot_pwr_limit ? radm_slot_pwr_payload[7:0] : rcvd_slot_pwr_limit_val;
        rcvd_slot_pwr_limit_scale   <= #TP radm_set_slot_pwr_limit ? radm_slot_pwr_payload[9:8] : rcvd_slot_pwr_limit_scale;
    end
end

// =============================================================================
// PCI-E Configuration Space Registers (TYPE 1/0)
// =============================================================================
reg cfg_reg_sel_d;
wire cfg_reg_id_en;
assign cfg_reg_id_en = cfg_reg_sel | cfg_reg_sel_d; 
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
  if(!non_sticky_rst_n)
        cfg_reg_id      <= #TP 0;
     else begin
        cfg_reg_id[0]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h000 >> 2)) & cfg_reg_sel) : cfg_reg_id[0];
        cfg_reg_id[1]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h004 >> 2)) & cfg_reg_sel) : cfg_reg_id[1];
        cfg_reg_id[2]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h008 >> 2)) & cfg_reg_sel) : cfg_reg_id[2];
        cfg_reg_id[3]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h00c >> 2)) & cfg_reg_sel) : cfg_reg_id[3];
        cfg_reg_id[4]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h010 >> 2)) & cfg_reg_sel) : cfg_reg_id[4];
        cfg_reg_id[5]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h014 >> 2)) & cfg_reg_sel) : cfg_reg_id[5];
        cfg_reg_id[6]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h018 >> 2)) & cfg_reg_sel) : cfg_reg_id[6];
        cfg_reg_id[7]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h01c >> 2)) & cfg_reg_sel) : cfg_reg_id[7];
        cfg_reg_id[8]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h020 >> 2)) & cfg_reg_sel) : cfg_reg_id[8];
        cfg_reg_id[9]   <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h024 >> 2)) & cfg_reg_sel) : cfg_reg_id[9];
        cfg_reg_id[10]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h028 >> 2)) & cfg_reg_sel) : cfg_reg_id[10];
        cfg_reg_id[11]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h02c >> 2)) & cfg_reg_sel) : cfg_reg_id[11];
        cfg_reg_id[12]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h030 >> 2)) & cfg_reg_sel) : cfg_reg_id[12];
        cfg_reg_id[13]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h034 >> 2)) & cfg_reg_sel) : cfg_reg_id[13];
        cfg_reg_id[14]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h038 >> 2)) & cfg_reg_sel) : cfg_reg_id[14];
        cfg_reg_id[15]  <= #TP cfg_reg_id_en ? ((lbc_cdm_addr[11:2] == (12'h03c >> 2)) & cfg_reg_sel) : cfg_reg_id[15];
     end
end

//L_UNCOVERED_330_3: allow toggling of all bits in cfg_cap_reg_id[], regardless of config
//L_UNCOVERED_330_3: Fix: rewrite address decoder process to do:
//L_UNCOVERED_330_3: Fix: 1. first part: full unconditional decode of all registers, regardless of config
//L_UNCOVERED_330_3: Fix: 2. second part: only if !max_coverage, override to 0 depending on config
//L_UNCOVERED_330_3: Fix: 3. instrument tests to force max_coverage=1 and exercise address regardless of configs
reg cfg_cap_reg_sel_d;
wire cfg_cap_reg_id_en;
assign cfg_cap_reg_id_en = cfg_cap_reg_sel | cfg_cap_reg_sel_d;
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
  if(!non_sticky_rst_n)
        cfg_cap_reg_id      <= #TP 0;
     else begin
        cfg_cap_reg_id[0]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PM_CAP + 4'h0) >> 2))     & cfg_cap_reg_sel) : cfg_cap_reg_id[0];
        cfg_cap_reg_id[1]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PM_CAP + 4'h4) >> 2))     & cfg_cap_reg_sel) : cfg_cap_reg_id[1];
        if (msi_cap_enable) begin
            cfg_cap_reg_id[2]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'h0) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[2];
            cfg_cap_reg_id[3]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'h4) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[3];
            cfg_cap_reg_id[4]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'h8) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[4];
            cfg_cap_reg_id[5]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSI_CAP + 4'hC) >> 2))    & cfg_cap_reg_sel) : cfg_cap_reg_id[5];
            cfg_cap_reg_id[24]  <= #TP 0;
            cfg_cap_reg_id[25]  <= #TP 0;
        end
        else begin
            cfg_cap_reg_id[2]  <= #TP 0;
            cfg_cap_reg_id[3]  <= #TP 0;
            cfg_cap_reg_id[4]  <= #TP 0;
            cfg_cap_reg_id[5]  <= #TP 0;
            cfg_cap_reg_id[24]  <= #TP 0;
            cfg_cap_reg_id[25]  <= #TP 0;
        end
        cfg_cap_reg_id[6]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 4'h0)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[6];
        cfg_cap_reg_id[7]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h4)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[7];
        cfg_cap_reg_id[8]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h8)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[8];
        cfg_cap_reg_id[9]   <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'hc)  >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[9];
        cfg_cap_reg_id[10]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h10) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[10];
        // Slot Capability/Control/Status registers only apply to Downstream ports
        if (!upstream_port) begin
            cfg_cap_reg_id[11]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h14) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[11];
            cfg_cap_reg_id[12]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h18) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[12];
        end
        else begin
            cfg_cap_reg_id[11]  <= #TP 0;
            cfg_cap_reg_id[12]  <= #TP 0;
        end
        // Root Capability/Control/Status registers only apply to RC
        if (rc_device) begin
//L_UNCOVERED_330_4: sw => rc_device is dynamic for sw ( it is static for rc,ep, lines below are automatically excluded by the tool for ep,rc), solve by using max_coverage approach
            cfg_cap_reg_id[13]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h1C) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[13];
            cfg_cap_reg_id[14]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h20) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[14];
        end
        else begin
            cfg_cap_reg_id[13]  <= #TP 0;
            cfg_cap_reg_id[14]  <= #TP 0;
        end
        cfg_cap_reg_id[22]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h24) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[22];
        cfg_cap_reg_id[23]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h28) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[23];
        cfg_cap_reg_id[29]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h2C) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[29];

    cfg_cap_reg_id[19]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h30) >> 2))  & cfg_cap_reg_sel) : cfg_cap_reg_id[19];

    //`ifdef CX_2ND_SPEED
    //`ifdef CX_GEN2_SPEED        //as of Readiness Notifications this register MUST be readable

     //   cfg_cap_reg_id[19]  <= #TP (lbc_cdm_addr[11:2] == ((`CFG_PCIE_CAP + 8'h30) >> 2))  & cfg_cap_reg_sel;
    //`else
    //    cfg_cap_reg_id[19]  <= #TP 0;
    //`endif
    //`endif
        if (slot_cap_enable) begin
            cfg_cap_reg_id[15]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_SLOT_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[15];
        end 
        else begin
            cfg_cap_reg_id[15]  <= #TP 0;
        end    
        if (msix_cap_enable) begin
            cfg_cap_reg_id[16]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSIX_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[16];
            cfg_cap_reg_id[17]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSIX_CAP + 4'h4) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[17];
            cfg_cap_reg_id[18]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_MSIX_CAP + 4'h8) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[18];
        end
        else begin
            cfg_cap_reg_id[16]  <= #TP 0;
            cfg_cap_reg_id[17]  <= #TP 0;
            cfg_cap_reg_id[18]  <= #TP 0;
        end
        if (vpd_cap_enable) begin
            cfg_cap_reg_id[20]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_VPD_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[20];
            cfg_cap_reg_id[21]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] == ((`CFG_VPD_CAP + 4'h4) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[21];
        end
        else begin
            cfg_cap_reg_id[20]  <= #TP 0;
            cfg_cap_reg_id[21]  <= #TP 0;
        end
        if (sata_cap_enable) begin
            cfg_cap_reg_id[26]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] ==
                ((`CFG_SATA_CAP + 4'h0) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[26];
            cfg_cap_reg_id[27]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] ==
                ((`CFG_SATA_CAP + 4'h4) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[27];
            cfg_cap_reg_id[28]  <= #TP cfg_cap_reg_id_en ? ((lbc_cdm_addr[11:2] ==
                ((`CFG_SATA_CAP + 4'h8) >> 2))   & cfg_cap_reg_sel) : cfg_cap_reg_id[28];
        end else begin
            cfg_cap_reg_id[26]  <= #TP 0;
            cfg_cap_reg_id[27]  <= #TP 0;
            cfg_cap_reg_id[28]  <= #TP 0;
        end
    end
end

assign pm_reg_id =  {cfg_cap_reg_id[1],     cfg_cap_reg_id[0]};   // map the cap_id into pm_id
assign msi_reg_id = {cfg_cap_reg_id[25:24], cfg_cap_reg_id[5:2]}; // map the cap_id into msi_id

// =============================================================================
// CFG Register Read Operation
// =============================================================================

// read PCI cfg space registers
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        cfg_reg_data    <= #TP 0;
    else
      if (reg_read_pulse) begin

            unique case (1'b1)

            cfg_reg_id[0] : cfg_reg_data  <= #TP {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};
            cfg_reg_id[1] : cfg_reg_data  <= #TP {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
            cfg_reg_id[2] : cfg_reg_data  <= #TP {cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8};
            cfg_reg_id[3] : cfg_reg_data  <= #TP {cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12};
            cfg_reg_id[4] : cfg_reg_data  <= #TP {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16};
            cfg_reg_id[5] : cfg_reg_data  <= #TP {cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20};
            cfg_reg_id[6] : cfg_reg_data  <= #TP {cfg_reg_27, cfg_reg_26, cfg_reg_25, cfg_reg_24};
            cfg_reg_id[7] : cfg_reg_data  <= #TP {cfg_reg_31, cfg_reg_30, cfg_reg_29, cfg_reg_28};
            cfg_reg_id[8] : cfg_reg_data  <= #TP {cfg_reg_35, cfg_reg_34, cfg_reg_33, cfg_reg_32};
            cfg_reg_id[9] : cfg_reg_data  <= #TP {cfg_reg_39, cfg_reg_38, cfg_reg_37, cfg_reg_36};
            cfg_reg_id[10]: cfg_reg_data  <= #TP {cfg_reg_43, cfg_reg_42, cfg_reg_41, cfg_reg_40};
            cfg_reg_id[11]: cfg_reg_data  <= #TP {cfg_reg_47, cfg_reg_46, cfg_reg_45, cfg_reg_44};
            cfg_reg_id[12]: cfg_reg_data  <= #TP {cfg_reg_51, cfg_reg_50, cfg_reg_49, cfg_reg_48};
            cfg_reg_id[13]: cfg_reg_data  <= #TP {cfg_reg_55, cfg_reg_54, cfg_reg_53, cfg_reg_52};
            cfg_reg_id[14]: cfg_reg_data  <= #TP {cfg_reg_59, cfg_reg_58, cfg_reg_57, cfg_reg_56};
            cfg_reg_id[15]: cfg_reg_data  <= #TP {cfg_reg_63, cfg_reg_62, cfg_reg_61, cfg_reg_60};
//L_UNCOVERED_330_1: reg_read_pulse==1 => |cfg_reg_id==1, remove line
            default:              cfg_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;

            endcase
        end
        else
            cfg_reg_data    <= #TP cfg_reg_data;
end

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n)
        cfg_cap_reg_data    <= #TP 0;
    else
        if (cap_reg_read_pulse) begin

          unique case (1'b1)

            |pm_reg_id[1:0]   : cfg_cap_reg_data  <= #TP pm_reg_data;
            |msi_reg_id[5:0]  : cfg_cap_reg_data  <= #TP msi_reg_data;
            cfg_cap_reg_id[6] : cfg_cap_reg_data  <= #TP {cfg_reg_91,  cfg_reg_90,  cfg_reg_89,  cfg_reg_88};
            cfg_cap_reg_id[7] : cfg_cap_reg_data  <= #TP {cfg_reg_95,  cfg_reg_94,  cfg_reg_93,  cfg_reg_92};
            cfg_cap_reg_id[8] : cfg_cap_reg_data  <= #TP {cfg_reg_99,  cfg_reg_98,  cfg_reg_97,  cfg_reg_96};
            cfg_cap_reg_id[9] : cfg_cap_reg_data  <= #TP {cfg_reg_103, cfg_reg_102, cfg_reg_101, cfg_reg_100};
            cfg_cap_reg_id[10]: cfg_cap_reg_data  <= #TP {cfg_reg_107, cfg_reg_106, cfg_reg_105, cfg_reg_104};
//L_UNCOVERED_330_2: ep => cfg_cap_reg_id[11:15]==0, rewrite address decoder process to allow toggle all bits of cfg_cap_reg_id, see next note
            cfg_cap_reg_id[11]: cfg_cap_reg_data  <= #TP {cfg_reg_111, cfg_reg_110, cfg_reg_109, cfg_reg_108};
            cfg_cap_reg_id[12]: cfg_cap_reg_data  <= #TP {cfg_reg_115, cfg_reg_114, cfg_reg_113, cfg_reg_112};
            cfg_cap_reg_id[13]: cfg_cap_reg_data  <= #TP {cfg_reg_119, cfg_reg_118, cfg_reg_117, cfg_reg_116};
            cfg_cap_reg_id[14]: cfg_cap_reg_data  <= #TP {cfg_reg_123, cfg_reg_122, cfg_reg_121, cfg_reg_120};
            cfg_cap_reg_id[15]: cfg_cap_reg_data  <= #TP {cfg_reg_127, cfg_reg_126, cfg_reg_125, cfg_reg_124};
            cfg_cap_reg_id[16]: cfg_cap_reg_data  <= #TP {cfg_reg_131, cfg_reg_130, cfg_reg_129, cfg_reg_128};
            cfg_cap_reg_id[17]: cfg_cap_reg_data  <= #TP {cfg_reg_135, cfg_reg_134, cfg_reg_133, cfg_reg_132};
            cfg_cap_reg_id[18]: cfg_cap_reg_data  <= #TP {cfg_reg_139, cfg_reg_138, cfg_reg_137, cfg_reg_136};
            cfg_cap_reg_id[22]: cfg_cap_reg_data  <= #TP {cfg_reg_143, cfg_reg_142, cfg_reg_141, cfg_reg_140};
            cfg_cap_reg_id[23]: cfg_cap_reg_data  <= #TP {cfg_reg_147, cfg_reg_146, cfg_reg_145, cfg_reg_144};
            cfg_cap_reg_id[29]: cfg_cap_reg_data  <= #TP {cfg_reg_151, cfg_reg_150, cfg_reg_149, cfg_reg_148};
            cfg_cap_reg_id[19]: cfg_cap_reg_data  <= #TP {cfg_reg_155, cfg_reg_154, cfg_reg_153, cfg_reg_152};
            cfg_cap_reg_id[20]: cfg_cap_reg_data  <= #TP {cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164};
            cfg_cap_reg_id[21]: cfg_cap_reg_data  <= #TP {cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168};
            cfg_cap_reg_id[26]: cfg_cap_reg_data  <= #TP 32'b0;
            cfg_cap_reg_id[27]: cfg_cap_reg_data  <= #TP 32'b0;
            cfg_cap_reg_id[28]: cfg_cap_reg_data  <= #TP 32'b0;
            default:            cfg_cap_reg_data  <= #TP `PCIE_UNUSED_RESPONSE;

            endcase
        end
        else
            cfg_cap_reg_data    <= #TP cfg_cap_reg_data;
end

// ack one cycle after lbc_cdm_cs is asserted
reg         ecfg_reg_sel_d;
reg [3:0]   write_pulse;

// =============================================================================
// MSI-X Table related logic
// =============================================================================

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_reg_ack         <= #TP 0;
        cfg_cap_reg_ack     <= #TP 0;
        cfg_reg_sel_d       <= #TP 0;
        cfg_cap_reg_sel_d   <= #TP 0;
        write_pulse         <= #TP 0;
        reg_read_pulse      <= #TP 0;
        cap_reg_read_pulse  <= #TP 0;
        ecfg_reg_sel_d      <= #TP 0;
    end else begin
        cfg_reg_sel_d       <= #TP (cfg_reg_sel);
        cfg_cap_reg_sel_d   <= #TP (cfg_cap_reg_sel);
        ecfg_reg_sel_d      <= #TP (ecfg_reg_sel);
        cfg_reg_ack         <= #TP cfg_reg_sel_d & cfg_reg_sel;
        cfg_cap_reg_ack     <= #TP cfg_cap_reg_sel_d & cfg_cap_reg_sel;
        write_pulse         <= #TP ((cfg_reg_sel & ~cfg_reg_sel_d) | (cfg_cap_reg_sel & !cfg_cap_reg_sel_d)) ? lbc_cdm_wr : 4'h0;
        reg_read_pulse      <= #TP cfg_reg_sel & ~cfg_reg_sel_d & (~|lbc_cdm_wr);
        cap_reg_read_pulse  <= #TP cfg_cap_reg_sel & ~cfg_cap_reg_sel_d & (~|lbc_cdm_wr);
    end
end

// =============================================================================
// PCIE Configuration Registers
// =============================================================================

//------------------------------------------------------------------------------
// Vendor ID / Device ID Register
// cfig_reg_id      - 0
// PCIE Offset      - 00h-03h
// Length           - 4 bytes
// Default value    - {`DEFAULT_DEVICE_ID, `DEFAULT_VENDOR_ID}
// Cfig register    - cfg_reg_0 - cfg_reg_3
//
// Read-Only register, but writable through DBI
//------------------------------------------------------------------------------
reg [15:0]      vendor_id;
reg [15:0]      device_id;
reg [15:0]      null_extended_cap_id;
reg  [3:0]      cxl_version;
reg [11:0]      next_cap_offset;

assign {cfg_reg_1, cfg_reg_0}   = ((|RCRB) || (~upstream_port & lbc_cdm_rcrb_dbi)) ? null_extended_cap_id : vendor_id;
assign {cfg_reg_3, cfg_reg_2}   = ((|RCRB) || (~upstream_port & lbc_cdm_rcrb_dbi)) ? {next_cap_offset, cxl_version} : device_id;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        vendor_id       <= #TP `DEFAULT_VENDOR_ID;
    end else begin
        vendor_id[7:0]  <= #TP (int_lbc_cdm_dbi & (upstream_port | (~lbc_cdm_rcrb_dbi)) & write_pulse[0] & cfg_reg_id[0]) ? lbc_cdm_data[7:0]   : vendor_id[7:0];
        vendor_id[15:8] <= #TP (int_lbc_cdm_dbi & (upstream_port | (~lbc_cdm_rcrb_dbi)) & write_pulse[1] & cfg_reg_id[0]) ? lbc_cdm_data[15:8]  : vendor_id[15:8];
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        device_id       <= #TP `DEFAULT_DEVICE_ID;
    end else begin
        device_id[7:0]  <= #TP (int_lbc_cdm_dbi & (upstream_port | (~lbc_cdm_rcrb_dbi)) & write_pulse[2] & cfg_reg_id[0]) ? lbc_cdm_data[23:16] : device_id[7:0];
        device_id[15:8] <= #TP (int_lbc_cdm_dbi & (upstream_port | (~lbc_cdm_rcrb_dbi)) & write_pulse[3] & cfg_reg_id[0]) ? lbc_cdm_data[31:24] : device_id[15:8];
    end
end
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        null_extended_cap_id <= #TP `CXL_RCRB_PORT_NULL_EXT_CAP_ID;
        cxl_version          <= #TP `CXL_RCRB_PORT_VER;
        next_cap_offset      <= #TP `CXL_RCRB_PORT_NXT_CAP_OFFSET;
    end else begin
        null_extended_cap_id[7:0]  <= #TP (int_lbc_cdm_dbi & (upstream_port | lbc_cdm_rcrb_dbi) & write_pulse[0] & cfg_reg_id[0]) ? lbc_cdm_data[7:0]   : null_extended_cap_id[7:0];
        null_extended_cap_id[15:8] <= #TP (int_lbc_cdm_dbi & (upstream_port | lbc_cdm_rcrb_dbi) & write_pulse[1] & cfg_reg_id[0]) ? lbc_cdm_data[15:8]  : null_extended_cap_id[15:8];
        cxl_version                <= #TP (int_lbc_cdm_dbi & (upstream_port | lbc_cdm_rcrb_dbi) & write_pulse[2] & cfg_reg_id[0]) ? lbc_cdm_data[19:16] : cxl_version[3:0];
        next_cap_offset[3:0]       <= #TP (int_lbc_cdm_dbi & (upstream_port | lbc_cdm_rcrb_dbi) & write_pulse[2] & cfg_reg_id[0]) ? lbc_cdm_data[23:20] : next_cap_offset[3:0];
        next_cap_offset[11:4]      <= #TP (int_lbc_cdm_dbi & (upstream_port | lbc_cdm_rcrb_dbi) & write_pulse[3] & cfg_reg_id[0]) ? lbc_cdm_data[31:24] : next_cap_offset[11:4];
    end
end

//------------------------------------------------------------------------------
// Command Register - Control register
// cfig_reg_id      - 1
// PCIE Offset      - 04h-05h
// Length           - 2 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_5, cfg_reg_4
//------------------------------------------------------------------------------

reg cfg_io_space_en;
reg cfg_mem_space_en;
reg cfg_bus_master_en;
reg cfg_reg_perren;
reg cfg_reg_serren;
reg cfg_int_disable;
assign cfg_reg_4 = {1'b0, cfg_reg_perren, 3'b0, cfg_bus_master_en, cfg_mem_space_en, cfg_io_space_en};
assign cfg_reg_5 = {5'b0, cfg_int_disable, 1'b0, cfg_reg_serren};

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_io_space_en  <= #TP 0;
        cfg_mem_space_en <= #TP 0;
    end else begin
        cfg_io_space_en  <= #TP !has_io_bar ? 0 :  write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[0] : cfg_io_space_en;
        cfg_mem_space_en <= #TP !has_mem_bar ? 0 :  write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[1] : cfg_mem_space_en;
    end
end

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_bus_master_en<= #TP 0;
        cfg_reg_perren   <= #TP 0;
        cfg_reg_serren   <= #TP 0;
        cfg_int_disable  <= #TP 0;
    end else begin
        cfg_bus_master_en<= #TP write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[2] : cfg_bus_master_en;
        cfg_reg_perren   <= #TP write_pulse[0] & cfg_reg_id[1] ? lbc_cdm_data[6] : cfg_reg_perren;
        cfg_reg_serren   <= #TP write_pulse[1] & cfg_reg_id[1] ? lbc_cdm_data[8] : cfg_reg_serren;
        cfg_int_disable  <= #TP write_pulse[1] & cfg_reg_id[1] ? lbc_cdm_data[10]: cfg_int_disable;
    end
end

// Detect a write of 1 to any of cfg_bus_master_en, cfg_mem_space_en or cfg_io_space_en
wire d0_active_detect;
assign d0_active_detect = write_pulse[0] && cfg_reg_id[1] && |lbc_cdm_data[2:0];
//------------------------------------------------------------------------------
// Status Register  - Status register
// cfig_reg_id      - 1
// PCIE Offset      - 06h-07h
// Length           - 2 bytes
// Default value    - 0010h
// Cfig register    - cfg_reg_7, cfg_reg_6
//------------------------------------------------------------------------------
//RO
reg cfg_imm_readi;     //instance is created  of this module per function
reg detected_perr;
reg rcvd_serr;
reg rcvd_master_abt;
reg rcvd_target_abt;
reg signaled_target_abt;
reg master_data_perr;

assign cfg_reg_6 = {3'b0, 1'b1, int_msg_pending, 2'b0, cfg_imm_readi};    // immediate readiness

assign cfg_reg_7 = {detected_perr, rcvd_serr, rcvd_master_abt, rcvd_target_abt,
                    signaled_target_abt, 2'b0, master_data_perr};

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
      cfg_imm_readi <= #TP `CX_RN_IMM_VALUE;
    end else begin
      cfg_imm_readi <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[1]) ? lbc_cdm_data[16] : cfg_imm_readi;
    end
end

  
                 
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        detected_perr       <= #TP 0;
        rcvd_serr           <= #TP 0;
        rcvd_master_abt     <= #TP 0;
        rcvd_target_abt     <= #TP 0;
        signaled_target_abt <= #TP 0;
        master_data_perr    <= #TP 0;
    end else begin
        detected_perr       <= #TP perr_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[31]) ? 1'b0
                                 : detected_perr;
        rcvd_serr           <= #TP signaled_sys_err_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[30]) ? 1'b0
                                 : rcvd_serr;
        rcvd_master_abt     <= #TP rcvd_master_abort_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[29]) ? 1'b0
                                 : rcvd_master_abt;

        rcvd_target_abt     <= #TP rcvd_target_abort_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[28]) ? 1'b0
                                 : rcvd_target_abt;

        signaled_target_abt <= #TP signaled_target_abort_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[27]) ? 1'b0
                                 : signaled_target_abt;

        master_data_perr    <= #TP master_data_perr_det ? 1'b1
                                 : (write_pulse[3] & cfg_reg_id[1] & lbc_cdm_data[24]) ? 1'b0
                                 : master_data_perr;
    end
end


//------------------------------------------------------------------------------
// Revision ID Register
// cfig_reg_id      - 2
// PCIE Offset      - 08h
// Length           - 1 bytes
// Default value    - `DEFAULT_REV_ID
// Cfig register    - cfg_reg_8
//
// Read-Only register, but writable through DBI
//------------------------------------------------------------------------------
reg [7:0]   revision_id;
assign cfg_reg_8    = revision_id;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        revision_id <= #TP `DEFAULT_REV_ID;
    end else begin
        revision_id <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[2]) ? lbc_cdm_data[7:0] : revision_id;
    end
end

//------------------------------------------------------------------------------
// Class Code Register  - PCI class_code
// cfig_reg_id      - 2
// PCIE Offset      - 09h - 0Bh
// Length           - 3 bytes
// Default value    - {`BASE_CLASS_CODE, `SUB_CLASS_CODE, `IF_CODE}
// Cfig register    - cfg_reg_9, cfg_reg_10, cfg_reg_11
//------------------------------------------------------------------------------
reg [7:0]   cfg_prog_interface;
reg [7:0]   cfg_sub_class;
reg [7:0]   cfg_base_class;
assign cfg_reg_9    = cfg_prog_interface;
assign cfg_reg_10   = cfg_sub_class;
assign cfg_reg_11   = cfg_base_class;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_prog_interface  <= #TP `IF_CODE;
        cfg_sub_class       <= #TP `SUB_CLASS_CODE;
        cfg_base_class      <= #TP `BASE_CLASS_CODE;

    end else begin
        cfg_prog_interface  <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[2]) ? lbc_cdm_data[15:8]  : cfg_prog_interface;
        cfg_sub_class       <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[2]) ? lbc_cdm_data[23:16] : cfg_sub_class;
        cfg_base_class      <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[2]) ? lbc_cdm_data[31:24] : cfg_base_class;
    end
end

//------------------------------------------------------------------------------
// Cache line size  - set by system firmware and OS to system cache line size, no impact to PCIE
// cfig_reg_id      - 3
// PCIE Offset      - 0Ch
// Length           - 1 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_12
//
// No impact to PCIE, but should be implemented as a R/W register
//------------------------------------------------------------------------------
reg [7:0]   cache_line_size;

assign cfg_reg_12   = cache_line_size;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n)
        cache_line_size <= #TP 0;
    else
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cache_line_size <= #TP write_pulse[0] & cfg_reg_id[3] ? lbc_cdm_data[7:0] : cache_line_size;
end

//------------------------------------------------------------------------------
// PCI Master Latency Timer Register
// cfig_reg_id      - 3
// PCIE Offset      - 0Dh
// Length           - 1 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_13
//
// Hardwire to 0
//------------------------------------------------------------------------------

assign cfg_reg_13   = 8'b0;     // N/A for PCI-E

//------------------------------------------------------------------------------
// Header Type register - Configuration space type
// cfig_reg_id      - 3
// PCIE Offset      - 0Eh
// Length           - 1 bytes
// Default value    - {(NF != 1), 6'b0, bridge_device}
// Cfig register    - cfg_reg_14
//------------------------------------------------------------------------------
reg         multi_function;
wire[7:0]   cfg_hdr_type;
assign cfg_hdr_type    = {multi_function, 6'b0, ~type0};
assign      cfg_reg_14      = cfg_hdr_type;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        multi_function  <= #TP (NF != 1);
    end else if(!end_device) begin
        multi_function  <= #TP 1'b0;        //set to zero in the case of a DM product set to RC mode with NFUNC>1
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        multi_function  <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[3]) ? lbc_cdm_data[23] : multi_function;
    end
end

//------------------------------------------------------------------------------
// BIST register    - Configuration space type
// cfig_reg_id      - 3
// PCIE Offset      - 0Fh
// Length           - 1 bytes
// Default value    - 0h
// Cfig register    - cfg_reg_15
//
// BIST is not supported.
// Customer need to modify by creating an input from BIST block to this register
// to support BIST.
//------------------------------------------------------------------------------
assign      cfg_reg_15 = 0;                        // BIST not supported.

//------------------------------------------------------------------------------
// There are a maximum of 6 32-bit BARs.
// Limitations:
// Only BAR0, BAR2 or BAR4 can be 64-bit.
// If BAR0 is 64-bit, BAR1 has to be disabled.
// If BAR2 is 64-bit, BAR3 has to be disabled.
// If BAR4 is 64-bit, BAR5 has to be disabled.
// BAR1, BAR3 and BAR5 can only be 32-bit BARs.
// -----------------------------------------------------------------------------
// Common signals for BAR Start and BAR Mask update indication, for BAR limit
// register clock gating inference.

reg         rbar_ctrl_update_d;              // Delayed RBAR resize update
reg         cfg_bar_start_mask_write_d;      // Delayed write BAR start or mask
wire        cfg_bar_start_mask_write;        // write to BAR start or mask registers

assign      cfg_bar_start_mask_write = |write_pulse & |cfg_reg_id[9:4]; // write to BAR start or mask registers

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        rbar_ctrl_update_d <= #TP 1'b0; 
        cfg_bar_start_mask_write_d <= #TP 1'b0; 
    end else begin
        rbar_ctrl_update_d <= #TP rbar_ctrl_update;
        cfg_bar_start_mask_write_d <= #TP cfg_bar_start_mask_write;
    end
end
// -----------------------------------------------------------------------------
// Memory Base Address Register 0
// If this is a 64-bit address decoder, it will take the first two BARs (10h and 14h) to implement.
// cfig_reg_id      - 4
// PCIE Offset      - 10h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_16 - cfg_reg_19
//
//     A write of 0xFFFF_FFFFF_FFFF_FFFF and a read of this register shall return at least a value of
//     0xFFFF_FFFF_FFF0_0000 to indicate that there is 1M of memory behind this BAR. Actual size of this should
//     be no less than 2Kbytes and data is expected to repeat until the memory limit is met.
// -----------------------------------------------------------------------------
reg         bar0_enabled;
reg         bar0_enabled_d;
wire        bar0_enabled_chg; // BAR0 mask enable changed state, affecting BAR0 limit register next state
wire        bar0_mask_writable;
wire        bar0_is_64bit;
reg         bar0_is_64bit_d;
wire        bar0_is_64bit_chg; // BAR0 is 64bit status changed, affecting BAR0 limit register next state
reg [63:0]  bar0_mask_i;
reg [63:0]  bar0_mask;
reg [31:0]  bar0_low;
reg [31:0]  bar0_high;
wire[63:0]  cfg_bar0_start;
reg [63:0]  cfg_bar0_limit;
wire        cfg_bar0_limit_en; // Indicates BAR0 limit register must be enabled
reg         cfg_bar0_io;
reg [1:0]   cfg_bar0_type;
reg         cfg_bar0_pref;

//L_UNCOVERED_330_5: bar0_mask_writable==0 => bar0_enabled==`DEFAULT_BAR0_ENABLED (0|1 for EP,SW, depending on config, always 0 for RC)
//L_UNCOVERED_330_5: Explaination: when bar0_enabled is fixed to one value and cannot be toggled 0|1 the associated if/else branches in the BAR process below cannot be both covered in same config.
//L_UNCOVERED_330_5: Fix: expensive/risky: rewrite the BAR process, first assign as if bar0_mask_writable==1 and then override at the end if bar0_mask_writable==0 (or max_coverage)
//L_UNCOVERED_330_5: Fix: cheaper: keep the BAR process as it is and use bar0_mask_writable = (`BAR0_MASK_WRITABLE | max_coverage)
//L_UNCOVERED_330_5: Fix: in both cases use a test to force max_coverage=1 and exercise bar0_enabled=0|1, 4ar0_is_64bit=0|1
//L_UNCOVERED_330_5: Fix: repeat teh above for all BARs
assign bar0_mask_writable   = `BAR0_MASK_WRITABLE;
assign bar0_is_64bit        = (cfg_bar0_type == 2'b10);
assign cfg_bar0_start       = {bar0_high, bar0_low};                            // actual valid BAR
assign cfg_bar0_mask        = bar0_mask;

assign bar0_enabled_chg = bar0_enabled ^ bar0_enabled_d; // BAR0 enabled changed state, affecting BAR0 limit next state
assign bar0_is_64bit_chg = bar0_is_64bit ^ bar0_is_64bit_d; // BAR0 is_64bit changed state, affecting BAR0 limit next state
assign cfg_bar0_limit_en = bar0_enabled_chg | bar0_is_64bit_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR0 limit register enable


// BAR0 enable, R/W via DBI
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_enabled <= #TP `DEFAULT_BAR0_ENABLED;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar0_enabled <= #TP (write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[0] : bar0_enabled;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_enabled_d <= #TP `DEFAULT_BAR0_ENABLED;
        bar0_is_64bit_d <= #TP `DEFAULT_BAR0_ENABLED;
    end else begin
        bar0_enabled_d <= #TP bar0_enabled;
        bar0_is_64bit_d <= #TP bar0_is_64bit;
    end
end

// Fixed/Programable BAR0 mask
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_mask_i       <= #TP `BAR0_MASK;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Lower 32-bit of BAR0 mask
        bar0_mask_i[7:0]  <= #TP 8'hFF;
        bar0_mask_i[15:8] <= #TP (bar0_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[15:8] : bar0_mask_i[15:8];
        bar0_mask_i[23:16]<= #TP (bar0_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[23:16]: bar0_mask_i[23:16];
        bar0_mask_i[31:24]<= #TP (bar0_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[4]) ? lbc_cdm_data[31:24]: bar0_mask_i[31:24];

        // Upper 32-bit of BAR0 mask
        if (bar0_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar0_mask_i[39:32]<= #TP (bar0_mask_writable & write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[7:0]  : bar0_mask_i[39:32];
            bar0_mask_i[47:40]<= #TP (bar0_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[15:8] : bar0_mask_i[47:40];
            bar0_mask_i[55:48]<= #TP (bar0_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[23:16]: bar0_mask_i[55:48];
            bar0_mask_i[63:56]<= #TP (bar0_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[31:24]: bar0_mask_i[63:56];
        end else begin
            bar0_mask_i[63:32]<= #TP 32'h0;
        end
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar0_enabled) begin
     bar0_mask = 64'h00000000FFFFFFFF;
   end else if (cfg_rbar_bar_resizable[0]) begin
     bar0_mask = cfg_rbar_bar0_mask;
   end else begin
     bar0_mask = bar0_mask_i;
   end
end

// Cfg header base address register located at offset 10h

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_low        <= #TP 32'h0;
        cfg_bar0_limit  <= #TP 64'h0;
        cfg_bar0_io     <= #TP `MEM0_SPACE_DECODER;
        cfg_bar0_type   <= #TP `BAR0_TYPE;
        cfg_bar0_pref   <= #TP `PREFETCHABLE0;
    end
    else begin
        if (cxl_rcrb_enable && |RCRB) begin
           bar0_low            <= #TP 32'h0;
        end
        else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM   
        bar0_low[7:0]       <= #TP ~bar0_enabled ? 8'h1 : (write_pulse[0] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar0_mask[7:0]  ): bar0_low[7:0];
        bar0_low[15:8]      <= #TP ~bar0_enabled ? 8'h0 : (write_pulse[1] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar0_mask[15:8] ): bar0_low[15:8];
        bar0_low[23:16]     <= #TP ~bar0_enabled ? 8'h0 : (write_pulse[2] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar0_mask[23:16]): bar0_low[23:16];
        bar0_low[31:24]     <= #TP ~bar0_enabled ? 8'h0 : (write_pulse[3] & cfg_reg_id[4] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar0_mask[31:24]): bar0_low[31:24];
        end
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_bar0_limit[31:0]  <= #TP cfg_bar0_limit_en ? (~bar0_enabled ? 32'h0 : (cfg_bar0_start[31:0] | bar0_mask[31:0])) : cfg_bar0_limit[31:0];
        cfg_bar0_limit[63:32] <= #TP cfg_bar0_limit_en ? ((~bar0_enabled | ~bar0_is_64bit) ? 32'h0 : (cfg_bar0_start[63:32] | bar0_mask[63:32])) : cfg_bar0_limit[63:32];

        if (bar0_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_bar0_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? lbc_cdm_data[0]  : cfg_bar0_io;
            cfg_bar0_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? lbc_cdm_data[2:1]: cfg_bar0_type;
            cfg_bar0_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? lbc_cdm_data[3]  : cfg_bar0_pref;
        end
        else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar0_io     <= #TP 0;
            cfg_bar0_type   <= #TP 0;
            cfg_bar0_pref   <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Memory Base Address Register 1
// cfig_reg_id      - 4
// PCIE Offset      - 14h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_20 - cfg_reg_23
// -----------------------------------------------------------------------------
reg         bar1_enabled;
reg         bar1_enabled_d;
wire        bar1_enabled_chg;
wire        bar1_mask_writable;
reg [31:0]  bar1_mask;
reg [31:0]  bar1_mask_i;
reg [31:0]  bar1_low;
wire[31:0]  cfg_bar1_start;
reg [31:0]  cfg_bar1_limit;
wire        cfg_bar1_limit_en; // Indicates BAR1 limit register must be enabled
reg         cfg_bar1_io;
reg [1:0]   cfg_bar1_type;
reg         cfg_bar1_pref;

assign bar1_mask_writable   = `BAR1_MASK_WRITABLE;
assign cfg_bar1_start       = bar1_low;
assign cfg_bar1_mask        = bar1_mask;

assign bar1_enabled_chg = bar1_enabled ^ bar1_enabled_d; // BAR1 enabled changed state, affecting BAR1 limit next state
assign cfg_bar1_limit_en = bar1_enabled_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR1 limit register enable


// BAR1 enable, R/W via DBI
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar1_enabled <= #TP `DEFAULT_BAR1_ENABLED;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar1_enabled <= #TP (write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[5] & ~bar0_is_64bit) ? lbc_cdm_data[0] : bar1_enabled;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar1_enabled_d <= #TP `DEFAULT_BAR1_ENABLED;
    end else begin
        bar1_enabled_d <= #TP bar1_enabled;
    end
end

// Fixed/Programmable BAR1 mask
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar1_mask_i       <= #TP `BAR1_MASK;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // BAR1 mask
        bar1_mask_i[7:0]  <= #TP 8'hFF;
        bar1_mask_i[15:8] <= #TP (bar1_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[15:8] : bar1_mask_i[15:8];
        bar1_mask_i[23:16]<= #TP (bar1_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[23:16]: bar1_mask_i[23:16];
        bar1_mask_i[31:24]<= #TP (bar1_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[5]) ? lbc_cdm_data[31:24]: bar1_mask_i[31:24];
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar1_enabled) begin
     bar1_mask = 0;
   end else if (cfg_rbar_bar_resizable[1]) begin
     bar1_mask = cfg_rbar_bar1_mask;
   end else begin
     bar1_mask = bar1_mask_i;
   end
end

// Cfg header base address register located at offset 14h

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar0_high       <= #TP 32'h0;
        bar1_low        <= #TP 32'h0;
        cfg_bar1_limit  <= #TP 32'h0;
        cfg_bar1_io     <= #TP `MEM1_SPACE_DECODER;
        cfg_bar1_type   <= #TP `BAR1_TYPE;
        cfg_bar1_pref   <= #TP `PREFETCHABLE1;
    end
    else begin
      if (cxl_rcrb_enable && |RCRB) begin
         bar0_high       <= #TP 32'h0;
         bar1_low        <= #TP 32'h0;
      end
      else begin
        // Upper 32-bit of BAR0
        if (bar0_enabled & bar0_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar0_high[7:0]  <= #TP (write_pulse[0] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar0_mask[39:32]): bar0_high[7:0];
            bar0_high[15:8] <= #TP (write_pulse[1] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar0_mask[47:40]): bar0_high[15:8];
            bar0_high[23:16]<= #TP (write_pulse[2] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar0_mask[55:48]): bar0_high[23:16];
            bar0_high[31:24]<= #TP (write_pulse[3] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar0_mask[63:56]): bar0_high[31:24];
        end
        else begin
            bar0_high       <= #TP 0;
        end

        // 32-bit of BAR1
        if (bar1_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar1_low[7:0]   <= #TP (write_pulse[0] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar1_mask[7:0]  ): bar1_low[7:0];
            bar1_low[15:8]  <= #TP (write_pulse[1] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar1_mask[15:8] ): bar1_low[15:8];
            bar1_low[23:16] <= #TP (write_pulse[2] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar1_mask[23:16]): bar1_low[23:16];
            bar1_low[31:24] <= #TP (write_pulse[3] & cfg_reg_id[5] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar1_mask[31:24]): bar1_low[31:24];
        end
        else begin
            bar1_low        <= #TP 32'h1;
        end
      end
       // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_bar1_limit[31:0]<= #TP cfg_bar1_limit_en ? (~bar1_enabled ? 32'h0 : (cfg_bar1_start[31:0] | bar1_mask[31:0])) : cfg_bar1_limit[31:0];
        if (bar1_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_bar1_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[5]) ? lbc_cdm_data[0]  : cfg_bar1_io;
            cfg_bar1_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[5]) ? lbc_cdm_data[2:1]: cfg_bar1_type;
            cfg_bar1_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[5]) ? lbc_cdm_data[3]  : cfg_bar1_pref;
        end else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar1_io     <= #TP 0;
            cfg_bar1_type   <= #TP 0;
            cfg_bar1_pref   <= #TP 0;
        end
    end
end
wire         cfg_mbar0_io = 1'b0;
wire  [1:0]  cfg_mbar0_type = 2'b10;
reg          cfg_mbar0_pref;
wire [15:0]  mbar0_low;
reg  [47:0]  mbar0_high;
assign mbar0_low = 16'h0;
assign rcrb_mbar0_base_addr = {mbar0_high, mbar0_low};
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_mbar0_pref     <= #TP `CX_CXL_MBAR0_PREFETCHABLE;
        mbar0_high         <= #TP 48'h0;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_mbar0_pref        <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[4]) ? (lbc_cdm_data[3]): cfg_mbar0_pref;
        mbar0_high[7:0]       <= #TP (write_pulse[2] & cfg_reg_id[4]) ? (lbc_cdm_data[23:16]): mbar0_high[7:0];
        mbar0_high[15:8]      <= #TP (write_pulse[3] & cfg_reg_id[4]) ? (lbc_cdm_data[31:24]): mbar0_high[15:8];
        mbar0_high[23:16]     <= #TP (write_pulse[0] & cfg_reg_id[5]) ? (lbc_cdm_data[7:0]  ): mbar0_high[23:16];
        mbar0_high[31:24]     <= #TP (write_pulse[1] & cfg_reg_id[5]) ? (lbc_cdm_data[15:8] ): mbar0_high[31:24];
        mbar0_high[39:32]     <= #TP (write_pulse[2] & cfg_reg_id[5]) ? (lbc_cdm_data[23:16]): mbar0_high[39:32];
        mbar0_high[47:40]     <= #TP (write_pulse[3] & cfg_reg_id[5]) ? (lbc_cdm_data[31:24]): mbar0_high[47:40];
    end
end


assign {cfg_reg_23, cfg_reg_22, cfg_reg_21, cfg_reg_20} = ((|RCRB) || (~upstream_port & lbc_cdm_rcrb_dbi)) ? rcrb_mbar0_base_addr[63:32] : bar1_enabled ? {cfg_bar1_start[31:4], cfg_bar1_pref, cfg_bar1_type, cfg_bar1_io}
                                                                       : cfg_bar0_start[63:32];
assign {cfg_reg_19, cfg_reg_18, cfg_reg_17, cfg_reg_16} = ((|RCRB) || (~upstream_port & lbc_cdm_rcrb_dbi)) ? {rcrb_mbar0_base_addr[31:4], cfg_mbar0_pref, cfg_mbar0_type, cfg_mbar0_io} : {cfg_bar0_start[31:4], cfg_bar0_pref, cfg_bar0_type, cfg_bar0_io};

// Segment ID capture 

// Only FUNC 0 register is created and used for destination segment id update
generate
if(FUNC_NUM==0) begin : gen_segment_id
  logic [8:0] cfg_segment_id;
  logic [8:0] int_segment_id;
  // Get segment id from application when not in EP mode
    // Default value for segment id is set by the application*
    assign int_segment_id = app_segment_id;
  
  // destination id updated based on DSV bit
  always @(posedge core_clk or negedge non_sticky_rst_n) begin
    if (!non_sticky_rst_n) begin
      cfg_segment_id <= #TP 0;
    end else begin
      // If RC/switch downstream port, or PCIE_PCIX , get the int_segment_id, else get NP Filter's segment_id
      // radm_snoop_upd will be asserted for a valid CfgWr request and DSV bit is 8th bit of segment id 
      cfg_segment_id <= #TP (rc_device | pcie_sw_down | pcie_br_up) ? int_segment_id : (radm_snoop_upd[0]) ? radm_np_segment_id : cfg_segment_id;
    end
  end

DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(cfg_segment_id)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_segment_id (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (non_sticky_rst_n),
`endif // SYNTHESIS
  .data_s  (cfg_segment_id),
  .data_d  (cfg_segment_id_out)
);

  
end else begin : gen_segment_id

  assign cfg_segment_id_out = 0;

end // gen_segment_id

endgenerate

// -----------------------------------------------------------------------------
// THE FOLLOWING REGISTERS ARE HEADER TYPE SPECIFIC
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Type 0: Memory Base Address Register 2
// If this is a 64-bit address decoder, it will take the next two BARs (18h and 1Ch) to implement.
// Type 1: 2nd Latency Timer, Subordinate Bus Number, 2nd Bus Number and Primary Bus Number
// cfig_reg_id      - 6
// PCIE Offset      - 18h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_24 - cfg_reg_27
// -----------------------------------------------------------------------------
reg         bar2_enabled;
reg         bar2_enabled_d;
wire        bar2_enabled_chg; // BAR2 mask enable changed state, affecting BAR2 limit register next state
wire        bar2_mask_writable;
wire        bar2_is_64bit;
reg         bar2_is_64bit_d;
wire        bar2_is_64bit_chg; // BAR2 is 64bit status changed, affecting BAR2 limit register next state
reg [63:0]  bar2_mask;
reg [63:0]  bar2_mask_i;
reg [31:0]  bar2_low;
reg [31:0]  bar2_high;
wire[63:0]  cfg_bar2_start;
reg [63:0]  cfg_bar2_limit;
wire        cfg_bar2_limit_en; // Indicates BAR2 limit register must be enabled
reg         cfg_bar2_io;
reg [1:0]   cfg_bar2_type;
reg         cfg_bar2_pref;
wire [4:0]  int_dev_num;
wire [7:0]  int_bus_num;

// Get Bus or device input from application when not in EP mode
// Default value for device and bus number is set by the application*
assign int_dev_num = app_dev_num;
// for RC/SW_DW get the application bus num, and for bridge devices the cfg_pbus_num_reg Type 1 reg
assign int_bus_num = (bridge_device) ? cfg_pbus_num_reg : app_bus_num;


assign bar2_mask_writable   = `BAR2_MASK_WRITABLE;
assign bar2_is_64bit        = (cfg_bar2_type == 2'b10);
assign cfg_bar2_start       = {bar2_high, bar2_low};                            // actual valid BAR
assign cfg_bar2_mask        = bar2_mask;

assign bar2_enabled_chg = bar2_enabled ^ bar2_enabled_d; // BAR2 enabled changed state, affecting BAR2 limit next state
assign bar2_is_64bit_chg = bar2_is_64bit ^ bar2_is_64bit_d; // BAR2 is_64bit changed state, affecting BAR2 limit next state
assign cfg_bar2_limit_en = bar2_enabled_chg | bar2_is_64bit_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR2 limit register enable

   assign {cfg_reg_27, cfg_reg_26, cfg_reg_25, cfg_reg_24} = type0 ? |RCRB ? 32'h0 : {cfg_bar2_start[31:4], cfg_bar2_pref, cfg_bar2_type, cfg_bar2_io} : {8'b0, cfg_subbus_num, cfg_2ndbus_num, cfg_pbus_num_reg};

// Type 1
reg [4:0]   cfg_pbus_dev_num;
reg         cfg_upd_req_id;     // update the shadow register in PMC
reg [7:0]   cfg_pbus_num;

generate
if(FUNC_NUM==0) begin : gen_bus_num

// bus number and dev number need to be updated constantly
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pbus_num_reg            <= #TP 0;
        cfg_2ndbus_num              <= #TP 0;
        cfg_subbus_num              <= #TP 0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // RW register, only used to be compatible with PCI.
        cfg_pbus_num_reg    <= #TP write_pulse[0] & cfg_reg_id[6] ? lbc_cdm_data[7:0]      // direct write
                                    : cfg_pbus_num_reg;
        cfg_2ndbus_num      <= #TP ~type0 & write_pulse[1] & cfg_reg_id[6] ? lbc_cdm_data[15:8] : cfg_2ndbus_num;
        cfg_subbus_num      <= #TP ~type0 & write_pulse[2] & cfg_reg_id[6] ? lbc_cdm_data[23:16] : cfg_subbus_num;
    end
end

end else begin : gen_bus_num
always_comb begin
    cfg_pbus_num_reg            = 0;
    cfg_2ndbus_num              = 0;
    cfg_subbus_num              = 0;
end

end // gen_bus_num
endgenerate

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pbus_dev_num            <= #TP 0;
        cfg_pbus_num                <= #TP 0;
        cfg_upd_req_id              <= #TP 0;
    end else begin
        // If it's an in-band write or a write to pribus # and it's a RC/SW_dn, update it
        if (SNOOP_REG) begin
          cfg_upd_req_id      <= #TP (radm_snoop_upd[FUNC_NUM] & !bridge_device) | ((rc_device | pcie_sw_down | bridge_device) & write_pulse[0] & cfg_reg_id[6]);
        end else begin
          cfg_upd_req_id      <= #TP ((rc_device | pcie_sw_down | bridge_device) & write_pulse[0] & cfg_reg_id[6]);
        end

        // Snooped bus number when non RC/SW_DW.
        if (SNOOP_REG) begin
            // If upstream device and not a bridge device, get the snooped bus number, else get the internally generated bus number 
           cfg_pbus_num                <= #TP (upstream_port & (!bridge_device) ) ? (radm_snoop_upd[FUNC_NUM] ? radm_snoop_bus_num : cfg_pbus_num) : int_bus_num;
        end else begin
          cfg_pbus_num                 <= #TP 0;
        end
        if (SNOOP_REG) begin
            // If RC/switch downstream port, or PCIE_PCIX , get the int_dev_num , else get snooped device number
           cfg_pbus_dev_num    <= #TP (rc_device | pcie_sw_down | pcie_br_up) ? int_dev_num : (radm_snoop_upd[FUNC_NUM] ) ? radm_snoop_dev_num : cfg_pbus_dev_num;   // snooping
        end else begin
          cfg_pbus_dev_num    <= #TP 0;
        end
    end
end


// BAR2 enable, R/W via DBI
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_enabled    <= #TP `DEFAULT_BAR2_ENABLED;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar2_enabled    <= #TP !type0 ? 0 : (type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[0] : bar2_enabled;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_enabled_d <= #TP `DEFAULT_BAR2_ENABLED;
        bar2_is_64bit_d <= #TP `DEFAULT_BAR2_ENABLED;
    end else begin
        bar2_enabled_d <= #TP bar2_enabled;
        bar2_is_64bit_d <= #TP bar2_is_64bit;
    end
end

// Fixed/Programmable BAR2 mask, type 0 only.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_mask_i       <= #TP `BAR2_MASK;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Lower 32-bit of BAR2 mask
        bar2_mask_i[7:0]  <= #TP 8'hFF;
        bar2_mask_i[15:8] <= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[6]) ? lbc_cdm_data[15:8] : bar2_mask_i[15:8];
        bar2_mask_i[23:16]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[6]) ? lbc_cdm_data[23:16]: bar2_mask_i[23:16];
        bar2_mask_i[31:24]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[6]) ? lbc_cdm_data[31:24]: bar2_mask_i[31:24];

        // Upper 32-bit of BAR2 mask
        if (bar2_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar2_mask_i[39:32]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[7:0]  : bar2_mask_i[39:32];
            bar2_mask_i[47:40]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[7]) ? lbc_cdm_data[15:8] : bar2_mask_i[47:40];
            bar2_mask_i[55:48]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[7]) ? lbc_cdm_data[23:16]: bar2_mask_i[55:48];
            bar2_mask_i[63:56]<= #TP (bar2_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[7]) ? lbc_cdm_data[31:24]: bar2_mask_i[63:56];
        end else begin
            bar2_mask_i[63:32]<= #TP 32'h0;
        end
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar2_enabled) begin
     bar2_mask = 64'h00000000FFFFFFFF;
   end else if (cfg_rbar_bar_resizable[2]) begin
     bar2_mask = cfg_rbar_bar2_mask;
   end else begin
    bar2_mask = bar2_mask_i;
   end
end

// Cfg header base address register 2, located at offset 18h, type 0 only.

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_low        <= #TP 32'b0;
        cfg_bar2_limit  <= #TP 64'h0;
        cfg_bar2_io     <= #TP `MEM2_SPACE_DECODER;
        cfg_bar2_type   <= #TP `BAR2_TYPE;
        cfg_bar2_pref   <= #TP `PREFETCHABLE2;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar2_low[7:0]       <= #TP ~bar2_enabled ? 8'h1 : (type0 & write_pulse[0] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar2_mask[7:0]  ): bar2_low[7:0];
        bar2_low[15:8]      <= #TP ~bar2_enabled ? 8'h0 : (type0 & write_pulse[1] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar2_mask[15:8] ): bar2_low[15:8];
        bar2_low[23:16]     <= #TP ~bar2_enabled ? 8'h0 : (type0 & write_pulse[2] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar2_mask[23:16]): bar2_low[23:16];
        bar2_low[31:24]     <= #TP ~bar2_enabled ? 8'h0 : (type0 & write_pulse[3] & cfg_reg_id[6] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar2_mask[31:24]): bar2_low[31:24];

        cfg_bar2_limit[31:0]<= #TP cfg_bar2_limit_en ? (~bar2_enabled ? 32'h0 : (cfg_bar2_start[31:0] | bar2_mask[31:0])) : cfg_bar2_limit[31:0];
        cfg_bar2_limit[63:32]<= #TP cfg_bar2_limit_en ? ((~bar2_enabled | ~bar2_is_64bit) ? 32'h0 : (cfg_bar2_start[63:32] | bar2_mask[63:32])) : cfg_bar2_limit[63:32];

        if (bar2_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_bar2_io     <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[0]  : cfg_bar2_io;
            cfg_bar2_type   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[2:1]: cfg_bar2_type;
            cfg_bar2_pref   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[6]) ? lbc_cdm_data[3]  : cfg_bar2_pref;
        end
        else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar2_io     <= #TP 0;
            cfg_bar2_type   <= #TP 0;
            cfg_bar2_pref   <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Type 1: 2nd Status register, I/O limit, I/O Base
// Type 0: Memory Reg Base Address register 3
// cfig_reg_id      - 7
// PCIE Offset      - 1Ch
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_28 - cfg_reg_31
// -----------------------------------------------------------------------------
// Type 0
reg         bar3_enabled;
reg         bar3_enabled_d;
wire        bar3_enabled_chg;
wire        bar3_mask_writable;
reg [31:0]  bar3_mask;
reg [31:0]  bar3_mask_i;
reg [31:0]  bar3_low;
wire[31:0]  cfg_bar3_start;
reg [31:0]  cfg_bar3_limit;
wire        cfg_bar3_limit_en; // Indicates BAR3 limit register must be enabled
reg         cfg_bar3_io;
reg [1:0]   cfg_bar3_type;
reg         cfg_bar3_pref;
assign bar3_mask_writable   = `BAR3_MASK_WRITABLE;
assign cfg_bar3_start       = bar3_low;
assign cfg_bar3_mask        = bar3_mask;

assign bar3_enabled_chg = bar3_enabled ^ bar3_enabled_d; // BAR3 enabled changed state, affecting BAR3 limit next state
assign cfg_bar3_limit_en = bar3_enabled_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR3 limit register enable

// Type 1
reg         detected_perr2;
reg         rcvd_serr2;
reg         rcvd_master_abt2;
reg         rcvd_target_abt2;
reg         signaled_target_abt2;
reg         master_data_perr2;
reg         io_is_32bit;
reg [3:0]   io_base;
reg [3:0]   io_limit;
wire[7:0]   cfg_io_base;
wire[7:0]   cfg_io_limit;

assign cfg_io_base  = {io_base,  3'b0, io_is_32bit};
assign cfg_io_limit = {io_limit, 3'b0, io_is_32bit};

assign cfg_reg_31 =  type0 ? |RCRB ? 8'h0 : (bar3_enabled ? cfg_bar3_start[31:24] : cfg_bar2_start[63:56])
                            : {detected_perr2, rcvd_serr2, rcvd_master_abt2, rcvd_target_abt2,
                               signaled_target_abt2, 2'b00, master_data_perr2}; 

assign cfg_reg_30 = type0 ? |RCRB ? 8'h0 : (bar3_enabled ? cfg_bar3_start[23:16] : cfg_bar2_start[55:48]) : 8'b0;

assign cfg_reg_29 =type0 ? |RCRB ? 8'h0 : (bar3_enabled ? cfg_bar3_start[15:8]  : cfg_bar2_start[47:40]) : cfg_io_limit; 

assign cfg_reg_28 = type0 ? |RCRB ? 8'h0 : (bar3_enabled ? {cfg_bar3_start[7:4], cfg_bar3_pref, cfg_bar3_type, cfg_bar3_io}: cfg_bar2_start[39:32]) : cfg_io_base; 


//// for master data parity error of secondary bus
//wire rcvd_cpl_poisoned_secondary    = !upstream_port & radm_rcvd_cpl_poisoned;
//wire xmt_wreq_poisoned_secondary    = !upstream_port & xtlh_xmt_wreq_poisoned;
//
//// for signaled target abort of secondary bus
//wire xmt_cpl_ca_secondary           = !upstream_port & xal_xmt_cpl_ca;
//
//// for received target abort of secondary bus
//wire rcvd_cpl_ca_secondary          = !upstream_port & radm_rcvd_cpl_ca;
//
//// for received master abort of second bus
//wire rcvd_cpl_ur_secondary          = !upstream_port & radm_rcvd_cpl_ur;
//

//// for signaled system error of second bus
//wire rcvd_serr_secondary            = (send_nf_err | send_f_err);

//
//// for detected parity error
//wire rcvd_wreq_poisoned_secondary   = !upstream_port & radm_rcvd_wreq_poisoned;


generate
if(FUNC_NUM==0) begin : gen_io_base_limit

// Type 1
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        detected_perr2          <= #TP 0;
        rcvd_serr2              <= #TP 0;
        rcvd_master_abt2        <= #TP 0;
        rcvd_target_abt2        <= #TP 0;
        signaled_target_abt2    <= #TP 0;
        master_data_perr2       <= #TP 0;
    end else begin
        if (~type0) begin
            detected_perr2          <= #TP perr_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[31]) ? 1'b0 :  detected_perr2;

            rcvd_serr2              <= #TP signaled_sys_err_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[30]) ? 1'b0 : rcvd_serr2;

            rcvd_master_abt2        <= #TP rcvd_master_abort_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[29]) ? 1'b0 : rcvd_master_abt2;

            rcvd_target_abt2        <= #TP rcvd_target_abort_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[28]) ? 1'b0 : rcvd_target_abt2;

            signaled_target_abt2    <= #TP signaled_target_abort_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[27]) ? 1'b0 : signaled_target_abt2;

            master_data_perr2       <= #TP master_data_perr_det2 ? 1'b1
                                       : (write_pulse[3] & cfg_reg_id[7] & lbc_cdm_data[24]) ? 1'b0 : master_data_perr2;
        end else begin
            detected_perr2          <= #TP 0;
            rcvd_serr2              <= #TP 0;
            rcvd_master_abt2        <= #TP 0;
            rcvd_target_abt2        <= #TP 0;
            signaled_target_abt2    <= #TP 0;
            master_data_perr2       <= #TP 0;
        end
    end // else: !if(!non_sticky_rst_n)
end // always @ (posedge core_clk or negedge non_sticky_rst_n)
end else begin : gen_io_base_limit
always_comb begin
    detected_perr2          = 0;
    rcvd_serr2              = 0;
    rcvd_master_abt2        = 0;
    rcvd_target_abt2        = 0;
    signaled_target_abt2    = 0;
    master_data_perr2       = 0;
end

end // gen_io_base_limit

if(FUNC_NUM==0) begin : _gen_io_base_limit

// Type 1
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        io_is_32bit             <= #TP `IO_DECODE_32;
        io_base                 <= #TP 0;
        io_limit                <= #TP 0;
    end else begin
        if (~type0) begin
            io_is_32bit             <= #TP write_pulse[0] & cfg_reg_id[7] & int_lbc_cdm_dbi ? lbc_cdm_data[0] : io_is_32bit;
            io_base                 <= #TP write_pulse[0] & cfg_reg_id[7] ? lbc_cdm_data[7:4]   : io_base;
            io_limit                <= #TP write_pulse[1] & cfg_reg_id[7] ? lbc_cdm_data[15:12] : io_limit;
        end else begin
            io_is_32bit             <= #TP `IO_DECODE_32;
            io_base                 <= #TP 0;
            io_limit                <= #TP 0;
        end
    end // else: !if(!non_sticky_rst_n)
end // always @ (posedge core_clk or negedge non_sticky_rst_n)
end else begin : _gen_io_base_limit
always_comb begin
    io_is_32bit             = 0;
    io_base                 = 0;
    io_limit                = 0;
end

end // _gen_io_base_limit
endgenerate



// BAR3 enable
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar3_enabled <= #TP `DEFAULT_BAR3_ENABLED;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar3_enabled <= #TP !type0 ? 0 : (type0 & write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[7] & ~bar2_is_64bit) ? lbc_cdm_data[0] : bar3_enabled;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar3_enabled_d <= #TP `DEFAULT_BAR3_ENABLED;
    end else begin
        bar3_enabled_d <= #TP bar3_enabled;
    end
end

// Fixed/Programmable BAR3 mask, type 0 only.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar3_mask_i       <= #TP `BAR3_MASK;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // BAR3 mask
        bar3_mask_i[7:0]  <= #TP 8'hFF;
        bar3_mask_i[15:8] <= #TP (bar3_mask_writable & type0 & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[7]) ? lbc_cdm_data[15:8] : bar3_mask_i[15:8];
        bar3_mask_i[23:16]<= #TP (bar3_mask_writable & type0 & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[7]) ? lbc_cdm_data[23:16]: bar3_mask_i[23:16];
        bar3_mask_i[31:24]<= #TP (bar3_mask_writable & type0 & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[7]) ? lbc_cdm_data[31:24]: bar3_mask_i[31:24];
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar3_enabled) begin
     bar3_mask = 0;
   end else if (cfg_rbar_bar_resizable[3]) begin
     bar3_mask = cfg_rbar_bar3_mask;
   end else begin
     bar3_mask = bar3_mask_i;
   end
end

// Cfg header base address register 3, located at offset 1Ch, type 0 only.

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar2_high       <= #TP 32'h0;
        bar3_low        <= #TP 32'h0;
        cfg_bar3_limit  <= #TP 32'h0;
        cfg_bar3_io     <= #TP `MEM3_SPACE_DECODER;
        cfg_bar3_type   <= #TP `BAR3_TYPE;
        cfg_bar3_pref   <= #TP `PREFETCHABLE3;
    end else begin
        // Upper 32-bit of BAR2
        if (bar2_enabled & bar2_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar2_high[7:0]  <= #TP (type0 & write_pulse[0] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar2_mask[39:32]) : bar2_high[7:0];
            bar2_high[15:8] <= #TP (type0 & write_pulse[1] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar2_mask[47:40]) : bar2_high[15:8];
            bar2_high[23:16]<= #TP (type0 & write_pulse[2] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar2_mask[55:48]) : bar2_high[23:16];
            bar2_high[31:24]<= #TP (type0 & write_pulse[3] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar2_mask[63:56]) : bar2_high[31:24];
        end
        else begin
            bar2_high       <= #TP 0;
        end

        // 32-bit of BAR3
        if (bar3_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar3_low[7:0]   <= #TP (write_pulse[0] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar3_mask[7:0]  ): bar3_low[7:0];
            bar3_low[15:8]  <= #TP (write_pulse[1] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar3_mask[15:8] ): bar3_low[15:8];
            bar3_low[23:16] <= #TP (write_pulse[2] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar3_mask[23:16]): bar3_low[23:16];
            bar3_low[31:24] <= #TP (write_pulse[3] & cfg_reg_id[7] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar3_mask[31:24]): bar3_low[31:24];
        end
        else begin
            bar3_low        <= #TP 32'h1;
        end

        cfg_bar3_limit[31:0]<= #TP cfg_bar3_limit_en ? (~bar3_enabled ? 32'h0 : (cfg_bar3_start[31:0] | bar3_mask[31:0])) : cfg_bar3_limit[31:0];

        if (bar3_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_bar3_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[0]  : cfg_bar3_io;
            cfg_bar3_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[2:1]: cfg_bar3_type;
            cfg_bar3_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[7]) ? lbc_cdm_data[3]  : cfg_bar3_pref;
        end else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar3_io     <= #TP 0;
            cfg_bar3_type   <= #TP 0;
            cfg_bar3_pref   <= #TP 0;
        end
    end
end

// -----------------------------------------------------------------------------
// Note: 24h is not implemented for Type 0 header as PCI Base Address Registers at default
// Implemented at vendors discretion
// -----------------------------------------------------------------------------
// Type 1: Memory Limit, Memory Base, Prefetchable Memory Limit, Prefetchable memory Base
// Type 0: Memory Reg Base Address register 4, Memory Reg Base Address register 5
// cfig_reg_id      - 8,9
// PCIE Offset      - 20h - 27h
// Length           - 8 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_32 - cfg_reg_39
// -----------------------------------------------------------------------------
// Type 0
reg         bar4_enabled;
reg         bar4_enabled_d;
wire        bar4_enabled_chg; // BAR4 mask enable changed state, affecting BAR4 limit register next state
wire        bar4_mask_writable;
wire        bar4_is_64bit;
reg         bar4_is_64bit_d;
wire        bar4_is_64bit_chg; // BAR4 is 64bit status changed, affecting BAR4 limit register next state
reg [63:0]  bar4_mask;
reg [63:0]  bar4_mask_i;
reg [31:0]  bar4_low;
reg [31:0]  bar4_high;
wire[63:0]  cfg_bar4_start;
reg [63:0]  cfg_bar4_limit;
wire        cfg_bar4_limit_en; // Indicates BAR4 limit register must be enabled
reg         cfg_bar4_io;
reg [1:0]   cfg_bar4_type;
reg         cfg_bar4_pref;

assign bar4_mask_writable   = `BAR4_MASK_WRITABLE;
assign bar4_is_64bit        = (cfg_bar4_type == 2'b10);
assign cfg_bar4_start       = {bar4_high, bar4_low};                            // actual valid BAR
assign cfg_bar4_mask        = bar4_mask;

assign bar4_enabled_chg = bar4_enabled ^ bar4_enabled_d; // BAR4 enabled changed state, affecting BAR4 limit next state
assign bar4_is_64bit_chg = bar4_is_64bit ^ bar4_is_64bit_d; // BAR4 is_64bit changed state, affecting BAR4 limit next state
assign cfg_bar4_limit_en = bar4_enabled_chg | bar4_is_64bit_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR4 limit register enable

// BAR4 enable
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_enabled <= #TP `DEFAULT_BAR4_ENABLED;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar4_enabled <= #TP !type0 ? 0 : (type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[0] : bar4_enabled;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_enabled_d <= #TP `DEFAULT_BAR4_ENABLED;
        bar4_is_64bit_d <= #TP `DEFAULT_BAR4_ENABLED;
    end else begin
        bar4_enabled_d <= #TP bar4_enabled;
        bar4_is_64bit_d <= #TP bar4_is_64bit;
    end
end

// BAR4 mask
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_mask_i       <= #TP `BAR4_MASK;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Lower 32-bit of BAR4 mask
        bar4_mask_i[7:0]  <= #TP 8'hFF;
        bar4_mask_i[15:8] <= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[8]) ? lbc_cdm_data[15:8] : bar4_mask_i[15:8];
        bar4_mask_i[23:16]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[8]) ? lbc_cdm_data[23:16]: bar4_mask_i[23:16];
        bar4_mask_i[31:24]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[8]) ? lbc_cdm_data[31:24]: bar4_mask_i[31:24];

        // Upper 32-bit of BAR4 mask
        if (bar4_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar4_mask_i[39:32]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[7:0]  : bar4_mask_i[39:32];
            bar4_mask_i[47:40]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[1] & cfg_reg_id[9]) ? lbc_cdm_data[15:8] : bar4_mask_i[47:40];
            bar4_mask_i[55:48]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[2] & cfg_reg_id[9]) ? lbc_cdm_data[23:16]: bar4_mask_i[55:48];
            bar4_mask_i[63:56]<= #TP (bar4_mask_writable & type0 & lbc_cdm_dbi2 & write_pulse[3] & cfg_reg_id[9]) ? lbc_cdm_data[31:24]: bar4_mask_i[63:56];
        end else begin
            bar4_mask_i[63:32]<= #TP 32'h0;
        end
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar4_enabled) begin
     bar4_mask = 64'h00000000FFFFFFFF;
   end else if (cfg_rbar_bar_resizable[4]) begin
     bar4_mask = cfg_rbar_bar4_mask;
   end else begin
     bar4_mask = bar4_mask_i;
   end
end

// Cfg header base address register 4, located at offset 20h, type 0 only.

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_low        <= #TP 32'h0;
        cfg_bar4_limit  <= #TP 64'h0;
        cfg_bar4_io     <= #TP `MEM4_SPACE_DECODER;
        cfg_bar4_type   <= #TP `BAR4_TYPE;
        cfg_bar4_pref   <= #TP `PREFETCHABLE4;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar4_low[7:0]       <= #TP ~bar4_enabled ? 8'h1 : (type0 & write_pulse[0] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]  & ~bar4_mask[7:0]  ): bar4_low[7:0];
        bar4_low[15:8]      <= #TP ~bar4_enabled ? 8'h0 : (type0 & write_pulse[1] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8] & ~bar4_mask[15:8] ): bar4_low[15:8];
        bar4_low[23:16]     <= #TP ~bar4_enabled ? 8'h0 : (type0 & write_pulse[2] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16]& ~bar4_mask[23:16]): bar4_low[23:16];
        bar4_low[31:24]     <= #TP ~bar4_enabled ? 8'h0 : (type0 & write_pulse[3] & cfg_reg_id[8] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24]& ~bar4_mask[31:24]): bar4_low[31:24];

        cfg_bar4_limit[31:0]<= #TP cfg_bar4_limit_en ? (~bar4_enabled ? 32'h0 : (cfg_bar4_start[31:0] | bar4_mask[31:0])) : cfg_bar4_limit[31:0];
        cfg_bar4_limit[63:32]<= #TP cfg_bar4_limit_en ? ((~bar4_enabled | (bar4_enabled & ~bar4_is_64bit)) ? 32'h0 : (cfg_bar4_start[63:32] | bar4_mask[63:32])) : cfg_bar4_limit[63:32];

        if (bar4_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_bar4_io     <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[0]  : cfg_bar4_io;
            cfg_bar4_type   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[2:1]: cfg_bar4_type;
            cfg_bar4_pref   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[3]  : cfg_bar4_pref;
        end
        else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar4_io     <= #TP 0;
            cfg_bar4_type   <= #TP 0;
            cfg_bar4_pref   <= #TP 0;
        end
    end
end

reg         bar5_enabled;
reg         bar5_enabled_d;
wire        bar5_enabled_chg;
wire        bar5_mask_writable;
reg [31:0]  bar5_mask;
reg [31:0]  bar5_mask_i;
reg [31:0]  bar5_low;
wire[31:0]  cfg_bar5_start;
reg [31:0]  cfg_bar5_limit;
wire        cfg_bar5_limit_en; // Indicates BAR5 limit register must be enabled
reg         cfg_bar5_io;
reg [1:0]   cfg_bar5_type;
reg         cfg_bar5_pref;

assign bar5_mask_writable   = `BAR5_MASK_WRITABLE;
assign cfg_bar5_start       = bar5_low;
assign cfg_bar5_mask        = bar5_mask;

assign bar5_enabled_chg = bar5_enabled ^ bar5_enabled_d; // BAR5 enabled changed state, affecting BAR5 limit next state
assign cfg_bar5_limit_en = bar5_enabled_chg | cfg_bar_start_mask_write_d | rbar_ctrl_update_d; //Condition for BAR5 limit register enable


// BAR5 enable
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar5_enabled <= #TP `DEFAULT_BAR5_ENABLED;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        bar5_enabled <= #TP !type0 ? 0 : (write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[9] & ~bar4_is_64bit) ? lbc_cdm_data[0] : bar5_enabled;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar5_enabled_d <= #TP `DEFAULT_BAR5_ENABLED;
    end else begin
        bar5_enabled_d <= #TP bar5_enabled;
    end
end

// BAR5 mask
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar5_mask_i       <= #TP `BAR5_MASK;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // BAR5 mask
        bar5_mask_i[7:0]  <= #TP 8'hFF;
        bar5_mask_i[15:8] <= #TP (bar5_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & cfg_reg_id[9]) ? lbc_cdm_data[15:8] : bar5_mask_i[15:8];
        bar5_mask_i[23:16]<= #TP (bar5_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & cfg_reg_id[9]) ? lbc_cdm_data[23:16]: bar5_mask_i[23:16];
        bar5_mask_i[31:24]<= #TP (bar5_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & cfg_reg_id[9]) ? lbc_cdm_data[31:24]: bar5_mask_i[31:24];
    end
end

// If BAR resizable then resize the BAR mask when the BAR size value is updated.
always @(*) begin
   if (!bar5_enabled) begin
     bar5_mask = 0;
   end else if (cfg_rbar_bar_resizable[5]) begin
     bar5_mask = cfg_rbar_bar5_mask;
   end else begin
     bar5_mask = bar5_mask_i;
   end
end

// Cfg header base address register 5, located at offset 24h, type 0 only.

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        bar4_high       <= #TP 32'h0;
        bar5_low        <= #TP 32'h0;
        cfg_bar5_limit  <= #TP 32'h0;
        cfg_bar5_io     <= #TP `MEM5_SPACE_DECODER;
        cfg_bar5_type   <= #TP `BAR5_TYPE;
        cfg_bar5_pref   <= #TP `PREFETCHABLE5;
    end
    else begin
        // Upper 32-bit of BAR4
        if (bar4_enabled & bar4_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar4_high[7:0]  <= #TP (write_pulse[0] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar4_mask[39:32]): bar4_high[7:0];
            bar4_high[15:8] <= #TP (write_pulse[1] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar4_mask[47:40]): bar4_high[15:8];
            bar4_high[23:16]<= #TP (write_pulse[2] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar4_mask[55:48]): bar4_high[23:16];
            bar4_high[31:24]<= #TP (write_pulse[3] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar4_mask[63:56]): bar4_high[31:24];
        end
        else begin
            bar4_high       <= #TP 0;
        end

        // 32-bit of BAR5
        if (bar5_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            bar5_low[7:0]   <= #TP (write_pulse[0] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[7:0]   & ~bar5_mask[7:0]  ): bar5_low[7:0];
            bar5_low[15:8]  <= #TP (write_pulse[1] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[15:8]  & ~bar5_mask[15:8] ): bar5_low[15:8];
            bar5_low[23:16] <= #TP (write_pulse[2] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[23:16] & ~bar5_mask[23:16]): bar5_low[23:16];
            bar5_low[31:24] <= #TP (write_pulse[3] & cfg_reg_id[9] & ~lbc_cdm_dbi2) ? (lbc_cdm_data[31:24] & ~bar5_mask[31:24]): bar5_low[31:24];
        end
        else begin
            bar5_low        <= #TP 32'h1;
        end

        cfg_bar5_limit[31:0]<= #TP cfg_bar5_limit_en ? (~bar5_enabled ? 32'h0 : (cfg_bar5_start[31:0] | bar5_mask[31:0])) : cfg_bar5_limit[31:0];

        if (bar5_enabled) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_bar5_io     <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[0]  : cfg_bar5_io;
            cfg_bar5_type   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[2:1]: cfg_bar5_type;
            cfg_bar5_pref   <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[3]  : cfg_bar5_pref;
        end else begin
          // From PCI-SIG PCI Local Bus Specification Revision 3.0, section 6.1: "Read accesses to reserved or unimplemented registers must
          // be completed normally and a data value of 0 returned."
            cfg_bar5_io     <= #TP 0;
            cfg_bar5_type   <= #TP 0;
            cfg_bar5_pref   <= #TP 0;
        end
    end
end


// Type 1
reg [11:0]  mem_base;
reg [11:0]  mem_limit;
reg         mem_is_64bit;
reg [11:0]  pref_mem_base;
reg [11:0]  pref_mem_limit;
assign  cfg_mem_base            = {mem_base,  4'b0};
assign  cfg_mem_limit           = {mem_limit, 4'hf};
assign  cfg_pref_mem_base       = {cfg_pref_base_upper32,  pref_mem_base,  20'h0};
assign  cfg_pref_mem_limit      = {cfg_pref_limit_upper32, pref_mem_limit, 20'hFFFFF};

assign {cfg_reg_35, cfg_reg_34, cfg_reg_33, cfg_reg_32} = type0 ? |RCRB ? 8'h0 : {cfg_bar4_start[31:4], cfg_bar4_pref, cfg_bar4_type, cfg_bar4_io}
                                                                : {mem_limit, 4'h0, mem_base,  4'b0}; 

assign {cfg_reg_37, cfg_reg_36} = type0 ? |RCRB ? 8'h0 : (bar5_enabled ? {cfg_bar5_start[15:4], cfg_bar5_pref, cfg_bar5_type, cfg_bar5_io} : cfg_bar4_start[47:32])
                                        : {pref_mem_base,  3'h0, mem_is_64bit}; 

assign {cfg_reg_39, cfg_reg_38} =  type0 ? |RCRB ? 8'h0 : (bar5_enabled ? cfg_bar5_start[31:16] : cfg_bar4_start[63:48])
                                        : {pref_mem_limit, 3'h0, mem_is_64bit}; 

generate
if(FUNC_NUM==0) begin : gen_mem_base_limit

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        mem_base                <= #TP 0;
        mem_limit               <= #TP 0;
        pref_mem_base           <= #TP 0;
        pref_mem_limit          <= #TP 0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        mem_base[3:0]           <= #TP (~type0 & write_pulse[0] & cfg_reg_id[8]) ? lbc_cdm_data[7:4]   : mem_base[3:0];
        mem_base[11:4]          <= #TP (~type0 & write_pulse[1] & cfg_reg_id[8]) ? lbc_cdm_data[15:8]  : mem_base[11:4];
        mem_limit[3:0]          <= #TP (~type0 & write_pulse[2] & cfg_reg_id[8]) ? lbc_cdm_data[23:20] : mem_limit[3:0];
        mem_limit[11:4]         <= #TP (~type0 & write_pulse[3] & cfg_reg_id[8]) ? lbc_cdm_data[31:24] : mem_limit[11:4];

//L_UNCOVERED_330_6: type0==1 => mem_is_64bit==0
        pref_mem_base[3:0]      <= #TP (~type0 & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[7:4]   : pref_mem_base[3:0];
        pref_mem_base[11:4]     <= #TP (~type0 & write_pulse[1] & cfg_reg_id[9]) ? lbc_cdm_data[15:8]  : pref_mem_base[11:4];
        pref_mem_limit[3:0]     <= #TP (~type0 & write_pulse[2] & cfg_reg_id[9]) ? lbc_cdm_data[23:20] : pref_mem_limit[3:0];
        pref_mem_limit[11:4]    <= #TP (~type0 & write_pulse[3] & cfg_reg_id[9]) ? lbc_cdm_data[31:24] : pref_mem_limit[11:4];
    end
end

end else begin : gen_mem_base_limit
always_comb begin
    mem_base                = 0;
    mem_limit               = 0;
    pref_mem_base           = 0;
    pref_mem_limit          = 0;
end

end // gen_mem_base_limit
endgenerate

 
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        mem_is_64bit            <= #TP `MEM_DECODE_64;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        mem_is_64bit            <= #TP (int_lbc_cdm_dbi & ~type0 & write_pulse[0] & cfg_reg_id[9]) ? lbc_cdm_data[0]     : mem_is_64bit;
    end
end

// -----------------------------------------------------------------------------
// Type 1: Prefetchable Base Upper 32 Bits, Prefetchable limit Upper 32 Bits
// Type 0: 28h is cardbus cis pointer(hardwired to 0)
//         2Ch is subsystem_device_id, subsystem_vendor_id (hardwired to 0 for now)
// cfig_reg_id      - 10, 11
// PCIE Offset      - 28h - 2Ch
// Length           - 8 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_40 - cfg_reg_47
// -----------------------------------------------------------------------------
reg [15:0]  subsystem_device_id;
reg [15:0]  subsystem_vendor_id;
reg [31:0]  cfg_cardbus_cis_ptr;
assign {cfg_reg_43, cfg_reg_42, cfg_reg_41, cfg_reg_40} = type0 ? |RCRB ? 8'h0 : cfg_cardbus_cis_ptr : cfg_pref_base_upper32; 

assign {cfg_reg_47, cfg_reg_46, cfg_reg_45, cfg_reg_44} = type0 ? {subsystem_device_id, subsystem_vendor_id} : cfg_pref_limit_upper32;

// Type 0
// Read-Only registers, but writable through DBI access
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_cardbus_cis_ptr         <= #TP `CARDBUS_CIS_PTR;
        subsystem_vendor_id         <= #TP `SUBSYS_VENDOR_ID;
        subsystem_device_id         <= #TP `SUBSYS_DEV_ID;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_cardbus_cis_ptr[7:0]    <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[10]) ? lbc_cdm_data[7:0]   : cfg_cardbus_cis_ptr[7:0];
        cfg_cardbus_cis_ptr[15:8]   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[10]) ? lbc_cdm_data[15:8]  : cfg_cardbus_cis_ptr[15:8];
        cfg_cardbus_cis_ptr[23:16]  <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[10]) ? lbc_cdm_data[23:16] : cfg_cardbus_cis_ptr[23:16];
        cfg_cardbus_cis_ptr[31:24]  <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[10]) ? lbc_cdm_data[31:24] : cfg_cardbus_cis_ptr[31:24];
        subsystem_vendor_id[7:0]    <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[11]) ? lbc_cdm_data[7:0]   : subsystem_vendor_id[7:0];
        subsystem_vendor_id[15:8]   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[11]) ? lbc_cdm_data[15:8]  : subsystem_vendor_id[15:8];
        subsystem_device_id[7:0]    <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[2] & cfg_reg_id[11]) ? lbc_cdm_data[23:16] : subsystem_device_id[7:0];
        subsystem_device_id[15:8]   <= #TP (type0 & int_lbc_cdm_dbi & write_pulse[3] & cfg_reg_id[11]) ? lbc_cdm_data[31:24] : subsystem_device_id[15:8];
    end
end

generate
if(FUNC_NUM==0) begin : gen_mem_base_limit_upper32

// Type 1
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_pref_base_upper32               <= #TP 0;
        cfg_pref_limit_upper32              <= #TP 0;
    end
    else begin

        if (mem_is_64bit) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_pref_base_upper32[7:0]      <= #TP write_pulse[0] & cfg_reg_id[10]? lbc_cdm_data[7:0]   :cfg_pref_base_upper32[7:0];
            cfg_pref_base_upper32[15:8]     <= #TP write_pulse[1] & cfg_reg_id[10]? lbc_cdm_data[15:8]  :cfg_pref_base_upper32[15:8];
            cfg_pref_base_upper32[23:16]    <= #TP write_pulse[2] & cfg_reg_id[10]? lbc_cdm_data[23:16] :cfg_pref_base_upper32[23:16];
            cfg_pref_base_upper32[31:24]    <= #TP write_pulse[3] & cfg_reg_id[10]? lbc_cdm_data[31:24] :cfg_pref_base_upper32[31:24];

            cfg_pref_limit_upper32[7:0]     <= #TP write_pulse[0] & cfg_reg_id[11]? lbc_cdm_data[7:0]   :cfg_pref_limit_upper32[7:0];
            cfg_pref_limit_upper32[15:8]    <= #TP write_pulse[1] & cfg_reg_id[11]? lbc_cdm_data[15:8]  :cfg_pref_limit_upper32[15:8];
            cfg_pref_limit_upper32[23:16]   <= #TP write_pulse[2] & cfg_reg_id[11]? lbc_cdm_data[23:16] :cfg_pref_limit_upper32[23:16];
            cfg_pref_limit_upper32[31:24]   <= #TP write_pulse[3] & cfg_reg_id[11]? lbc_cdm_data[31:24] :cfg_pref_limit_upper32[31:24];

        end
        else begin
            cfg_pref_base_upper32           <= #TP 0;
            cfg_pref_limit_upper32          <= #TP 0;
        end

    end
end

end else begin : gen_mem_base_limit_upper32
always_comb begin
    cfg_pref_base_upper32               = 0;
    cfg_pref_limit_upper32              = 0;
end

end // gen_mem_base_limit_upper32
endgenerate

// -----------------------------------------------------------------------------
// Type 1: I/O Limit Upper 16 bits, I/O Base Upper 16 Bits
// Type 0: Expansion ROM address
// cfig_reg_id      - 12
// PCIE Offset      - 30h
// Length           - 4 bytes
// Default value    - user defined
// Cfig register    - cfg_reg_48 - cfg_reg_51
// -----------------------------------------------------------------------------

reg [31:0]  exp_rom_mask;
reg         rom_bar_enabled;

assign cfg_rom_mask = exp_rom_mask;
// Type 0
reg [31:0]  exp_rom_addr_type0;
reg [20:0]  exp_rom_addr_0;
reg [3:0]   exp_rom_validation_details_0;
reg [2:0]   exp_rom_validation_status_0;
reg         exp_rom_en_0;
reg [20:0]  exp_rom_addr_1;
reg [3:0]   exp_rom_validation_details_1;
reg [2:0]   exp_rom_validation_status_1;
reg         exp_rom_en_1;
wire[31:0]  cfg_exp_rom_type0;
wire[31:0]  exp_rom_start_type0;
wire[31:0]  exp_rom_limit_type0;
wire        rom_enable_type0;
assign cfg_exp_rom_type0    = (exp_rom_addr_type0 & ~exp_rom_mask);

// Need to disable if cfg_mem_space_en or rom_enable is 0 - by setting the limit to 0
assign rom_enable_type0     = exp_rom_addr_type0[0] & cfg_mem_space_en & rom_bar_enabled;
assign exp_rom_start_type0  = ~rom_enable_type0 ? 32'h1
                             : cfg_exp_rom_type0;
assign exp_rom_limit_type0  = ~rom_enable_type0 ? 0
                             : (cfg_exp_rom_type0 | exp_rom_mask);

wire rom_mask_writable;
//L_UNCOVERED_330_7: rom_mask_writable==0 => rom_bar_enabled==0
assign rom_mask_writable = `ROM_MASK_WRITABLE;



always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    rom_bar_enabled       <= #TP `DEFAULT_ROM_BAR_ENABLED;
  end else begin
    rom_bar_enabled       <= #TP (rom_mask_writable & write_pulse[0] & lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[0]     : rom_bar_enabled;
  end
end

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        exp_rom_addr_0              <= #TP 0;
        exp_rom_en_0                <= #TP 0;
    end else begin

        if (~rom_bar_enabled) begin
            exp_rom_addr_0          <= #TP 0;
            exp_rom_en_0            <= #TP 0;
        end
        else begin
            exp_rom_en_0            <= #TP (type0 & write_pulse[0] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[0]     : exp_rom_en_0;
            exp_rom_addr_0[4:0]     <= #TP (type0 & write_pulse[1] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[15:11] : exp_rom_addr_0[4:0];
            exp_rom_addr_0[12:5]    <= #TP (type0 & write_pulse[2] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[23:16] : exp_rom_addr_0[12:5];
            exp_rom_addr_0[20:13]   <= #TP (type0 & write_pulse[3] & ~lbc_cdm_dbi2 & cfg_reg_id[12]) ? lbc_cdm_data[31:24] : exp_rom_addr_0[20:13];
        end
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        exp_rom_validation_status_0    <= #TP 3'b000;
        exp_rom_validation_details_0   <= #TP 4'b0000;
    end else begin
      if (!rom_bar_enabled) begin
        exp_rom_validation_status_0    <= #TP 3'b000;
        exp_rom_validation_details_0   <= #TP 4'b0000;
      end else if (exp_rom_validation_status_strobe | exp_rom_validation_details_strobe) begin   
        if (exp_rom_validation_status_strobe) begin                               
          exp_rom_validation_status_0  <= #TP exp_rom_validation_status;     //Set the Expansion ROM Validation Status bits
      end
        if (exp_rom_validation_details_strobe) begin                               
          exp_rom_validation_details_0 <= #TP exp_rom_validation_details;    //Set the Expansion ROM Validation Details bits
        end
      end else begin
       exp_rom_validation_status_0  <= #TP(type0 & write_pulse[0] & ~lbc_cdm_dbi2 & cfg_reg_id[12] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:1] : exp_rom_validation_status_0;
       exp_rom_validation_details_0 <= #TP(type0 & write_pulse[0] & ~lbc_cdm_dbi2 & cfg_reg_id[12] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:4] : exp_rom_validation_details_0;
      end
    end
end

assign exp_rom_addr_type0 = {exp_rom_addr_0, 3'b0, exp_rom_validation_details_0, exp_rom_validation_status_0, exp_rom_en_0};

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        exp_rom_mask                    <= #TP `ROM_MASK;
    end else begin
        if (rom_bar_enabled) begin
            exp_rom_mask[10:0]          <= #TP 11'h7FF;
            exp_rom_mask[15:11]         <= #TP (rom_mask_writable & write_pulse[1] & lbc_cdm_dbi2 & ((type0 && cfg_reg_id[12]) || (~type0 && cfg_reg_id[14]))) ? lbc_cdm_data[15:11] : exp_rom_mask[15:11];
            exp_rom_mask[23:16]         <= #TP (rom_mask_writable & write_pulse[2] & lbc_cdm_dbi2 & ((type0 && cfg_reg_id[12]) || (~type0 && cfg_reg_id[14]))) ? lbc_cdm_data[23:16] : exp_rom_mask[23:16];
            exp_rom_mask[31:24]         <= #TP (rom_mask_writable & write_pulse[3] & lbc_cdm_dbi2 & ((type0 && cfg_reg_id[12]) || (~type0 && cfg_reg_id[14]))) ? lbc_cdm_data[31:24] : exp_rom_mask[31:24];
        end
        else begin
            exp_rom_mask                <= #TP 32'hFFFFFFFF;
        end
    end
end

//assertions for exp_rom_addr_type0 added near end of file


generate
if(FUNC_NUM==0) begin : gen_io_base_limit_upper32

// Type 1
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_io_limit_upper16        <= #TP 0;
        cfg_io_base_upper16         <= #TP 0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_io_base_upper16[7:0]    <= #TP ~type0 & write_pulse[0] & cfg_reg_id[12] ? lbc_cdm_data[7:0]   : cfg_io_base_upper16[7:0];
        cfg_io_base_upper16[15:8]   <= #TP ~type0 & write_pulse[1] & cfg_reg_id[12] ? lbc_cdm_data[15:8]  : cfg_io_base_upper16[15:8];
        cfg_io_limit_upper16[7:0]   <= #TP ~type0 & write_pulse[2] & cfg_reg_id[12] ? lbc_cdm_data[23:16] : cfg_io_limit_upper16[7:0];
        cfg_io_limit_upper16[15:8]  <= #TP ~type0 & write_pulse[3] & cfg_reg_id[12] ? lbc_cdm_data[31:24] : cfg_io_limit_upper16[15:8];

    end
end
end else begin : gen_io_base_limit_upper32
always_comb begin
    cfg_io_limit_upper16        = 0;
    cfg_io_base_upper16         = 0;
end

end // gen_io_base_limit_upper32
endgenerate

assign {cfg_reg_51, cfg_reg_50, cfg_reg_49, cfg_reg_48} = type0 ? |RCRB ? 8'h0 : {cfg_exp_rom_type0[31:8], exp_rom_validation_details_0, exp_rom_validation_status_0, exp_rom_addr_type0[0]}
                                                                : (io_is_32bit ? {cfg_io_limit_upper16, cfg_io_base_upper16} : 0); 


// -----------------------------------------------------------------------------
// Capabilities Pointer
// -----------------------------------------------------------------------------
// Capabilities Pointer - Point to the first location of capability structure
// cfig_reg_id      - 13
// PCIE Offset      - 34h
// Length           - 4 bytes
// Default value    - `CFG_NEXT_PTR
// Cfig register    - cfg_reg_52 - cfg_reg_55
//
// Same for Type0 or Type1
// -----------------------------------------------------------------------------
reg [7:0]   cfg_cap_ptr;
assign cfg_reg_52 = cfg_cap_ptr;    // Points to first capability structure
assign cfg_reg_53 = 8'h00;          // RESV
assign cfg_reg_54 = 8'h00;          // RESV
assign cfg_reg_55 = 8'h00;          // RESV

reg cfg_next_ptr_wr_updated;
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
      cfg_cap_ptr             <= #TP  `CFG_NEXT_PTR ;   // Next capability pointer
        cfg_next_ptr_wr_updated <= #TP 1'b0;
    end else begin
        if (int_lbc_cdm_dbi & write_pulse[0] & cfg_reg_id[13]) begin
           cfg_cap_ptr             <= #TP lbc_cdm_data[7:0];
           cfg_next_ptr_wr_updated <= #TP 1'b1;
        end
        else if (!cfg_next_ptr_wr_updated) begin
          cfg_cap_ptr <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_CFG_NEXT_PTR : `CXL_CFG_NEXT_PTR : `CFG_NEXT_PTR ;
        end
    end
end



// -----------------------------------------------------------------------------
// Type 1: Expansion ROM Base Address
// Type 0: Reserved
// cfig_reg_id      - 14
// PCIE Offset      - 38h
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_56 - cfg_reg_59
// -----------------------------------------------------------------------------
reg [31:0]  exp_rom_addr_type1;
wire[31:0]  cfg_exp_rom_type1;
wire[31:0]  exp_rom_start_type1;
wire[31:0]  exp_rom_limit_type1;
wire        rom_enable_type1;
wire        exp_rom_enable;
assign {cfg_reg_59, cfg_reg_58, cfg_reg_57, cfg_reg_56} = type0 ? 32'b0 : {cfg_exp_rom_type1[31:8], exp_rom_validation_details_1, exp_rom_validation_status_1, exp_rom_addr_type1[0]};

assign cfg_exp_rom_type1    = (exp_rom_addr_type1 & ~exp_rom_mask);
// Need to disable if cfg_mem_space_en or rom_enable is 0 - by setting the limit to 0
assign rom_enable_type1     = exp_rom_addr_type1[0] & (cfg_mem_space_en | ~upstream_port) & rom_bar_enabled;
assign exp_rom_start_type1  = ~rom_enable_type1 ? 32'h1
                             : cfg_exp_rom_type1;
assign exp_rom_limit_type1  = ~rom_enable_type1 ? 0
                             : cfg_exp_rom_type1 | exp_rom_mask;

assign exp_rom_enable       =  type0 ? rom_enable_type0 : rom_enable_type1;

// cfg_exp_rom_limit and cfg_exp_rom_start register enables
reg cfg_exp_rom_limit_updt_d;
wire cfg_exp_rom_limit_en;
assign cfg_exp_rom_limit_updt = |write_pulse; 
assign cfg_exp_rom_limit_en = cfg_exp_rom_limit_updt | cfg_exp_rom_limit_updt_d;
reg cfg_exp_rom_start_updt_d;
wire cfg_exp_rom_start_en;
assign cfg_exp_rom_start_updt = |write_pulse;
assign cfg_exp_rom_start_en = cfg_exp_rom_start_updt | cfg_exp_rom_start_updt_d;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_exp_rom_limit_updt_d        <= #TP 0;
        cfg_exp_rom_start_updt_d        <= #TP 0;
      end else begin
        cfg_exp_rom_limit_updt_d        <= #TP cfg_exp_rom_limit_updt;
        cfg_exp_rom_start_updt_d        <= #TP cfg_exp_rom_start_updt;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_exp_rom_start               <= #TP 0;
        cfg_exp_rom_limit               <= #TP 0;
    end else begin
        cfg_exp_rom_start               <= #TP cfg_exp_rom_start_en ? (type0 ? exp_rom_start_type0 : exp_rom_start_type1) : cfg_exp_rom_start;
        cfg_exp_rom_limit               <= #TP cfg_exp_rom_limit_en ? (type0 ? exp_rom_limit_type0 : exp_rom_limit_type1) : cfg_exp_rom_limit;
    end
end

generate
if(FUNC_NUM==0) begin : gen_exp_rom_type1
// Type 1 Configuration Space Header register is only implemented for function 0.

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        exp_rom_addr_1              <= #TP 0;
        exp_rom_en_1                <= #TP 0;
    end else begin

        if (~rom_bar_enabled) begin
            exp_rom_addr_1          <= #TP 0;
            exp_rom_en_1            <= #TP 0;
        end
        else begin
            exp_rom_en_1            <= #TP (write_pulse[0] & cfg_reg_id[14]) ? lbc_cdm_data[0]     : exp_rom_en_1;
            exp_rom_addr_1[4:0  ]   <= #TP (write_pulse[1] & cfg_reg_id[14]) ? lbc_cdm_data[15:11] : exp_rom_addr_1[4:0];
            exp_rom_addr_1[12:5]    <= #TP (write_pulse[2] & cfg_reg_id[14]) ? lbc_cdm_data[23:16] : exp_rom_addr_1[12:5];
            exp_rom_addr_1[20:13]   <= #TP (write_pulse[3] & cfg_reg_id[14]) ? lbc_cdm_data[31:24] : exp_rom_addr_1[20:13];
        end
    end
end
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        exp_rom_validation_status_1    <= #TP 3'b000;
        exp_rom_validation_details_1   <= #TP 4'b0000;
    end else begin
      if (!rom_bar_enabled) begin
        exp_rom_validation_status_1    <= #TP 3'b000;
        exp_rom_validation_details_1   <= #TP 4'b0000;
      end else if (exp_rom_validation_status_strobe | exp_rom_validation_details_strobe) begin   
        if (exp_rom_validation_status_strobe) begin                               
          exp_rom_validation_status_1  <= #TP exp_rom_validation_status;     //Set the Expansion ROM Validation Status bits
        end
        if (exp_rom_validation_details_strobe) begin                               
          exp_rom_validation_details_1 <= #TP exp_rom_validation_details;    //Set the Expansion ROM Validation Details bits
        end
      end else begin
       exp_rom_validation_status_1  <= #TP(write_pulse[0] & cfg_reg_id[14] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:1] : exp_rom_validation_status_1;
       exp_rom_validation_details_1 <= #TP(write_pulse[0] & cfg_reg_id[14] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:4] : exp_rom_validation_details_1;
      end
    end
end
end else begin : gen_exp_rom_type1
always_comb begin
    exp_rom_addr_1              = 0;
    exp_rom_en_1                = 0;
    exp_rom_validation_status_1    = 3'b000;
    exp_rom_validation_details_1   = 4'b0000;
end

end // gen_exp_rom_type1
endgenerate


assign exp_rom_addr_type1 = {exp_rom_addr_1, 3'b0, exp_rom_validation_details_1, exp_rom_validation_status_1, exp_rom_en_1};

// -----------------------------------------------------------------------------
// Type 1: Bridge Control, INT Pin, INT Line
// Type 0: Max_Lat, Min_Gnt, INT Pin, INT Line
// cfig_reg_id      - 15
// PCIE Offset      - 3Ch
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_60 - cfg_reg_63
// -----------------------------------------------------------------------------

reg         cfg_vga_enable;
reg         cfg_vga16_decode;
reg         cfg_isa_enable;
reg [7:0]   cfg_int_pin;
reg         cfg_mstr_abort_mode;
assign cfg_reg_60 = int_line_reg;
assign cfg_reg_61 = cfg_int_pin;
assign cfg_reg_62 = type0 ? 8'h0 : {1'b0, cfg_2nd_reset, cfg_mstr_abort_mode, cfg_vga16_decode, cfg_vga_enable, cfg_isa_enable, cfg_br_ctrl_serren, cfg_br_ctrl_perren};
assign cfg_reg_63 = 8'b0;

logic       pcie_mode_enabled;
logic       cxl1p1_mode_enabled;
logic       pcie_or_cxl1p1_mode_enabled;
assign pcie_mode_enabled   = !cxl_mode_enable || (current_data_rate < `GEN3_RATE);
assign cxl1p1_mode_enabled = cxl_mode_enable && !cxl2p0_enabled && (current_data_rate >= `GEN3_RATE)
                          && !flit_mode_enable
                           ;
assign pcie_or_cxl1p1_mode_enabled = pcie_mode_enabled || cxl1p1_mode_enabled;

assign cfg_2nd_reset_mod = pcie_or_cxl1p1_mode_enabled ? cfg_2nd_reset : (cfg_2nd_reset & cfg_cxl_2_0_ext_unmask_sbr);

generate
if(FUNC_NUM==0) begin : gen_bridge_control

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_br_ctrl_perren  <= #TP 0;
        cfg_br_ctrl_serren  <= #TP 0;
        cfg_vga_enable      <= #TP 0;
        cfg_vga16_decode    <= #TP 0;
        cfg_mstr_abort_mode <= #TP 0;
        cfg_2nd_reset       <= #TP 0;
    end else begin

        cfg_br_ctrl_perren  <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[16] : cfg_br_ctrl_perren;
        cfg_br_ctrl_serren  <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[17] : cfg_br_ctrl_serren;
        cfg_vga_enable      <= #TP 0;
        cfg_vga16_decode    <= #TP 0;
        cfg_mstr_abort_mode <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15] & bridge_device) ? lbc_cdm_data[21] : cfg_mstr_abort_mode;
        cfg_2nd_reset       <= #TP (~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[22] : cfg_2nd_reset;

    end
end
end else begin : gen_bridge_control
always_comb begin
    cfg_br_ctrl_perren  = 0;
    cfg_br_ctrl_serren  = 0;
    cfg_vga_enable      = 0;
    cfg_vga16_decode    = 0;
    cfg_mstr_abort_mode = 0;
    cfg_2nd_reset       = 0;
end

end // gen_bridge_control
endgenerate

generate
if(FUNC_NUM==0) begin : _gen_bridge_control

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_isa_enable      <= #TP 0;
    end else begin
        cfg_isa_enable      <= #TP(~type0 & write_pulse[2] & cfg_reg_id[15]) ? lbc_cdm_data[18] : cfg_isa_enable;
    end
end
end else begin : _gen_bridge_control
always_comb begin
    cfg_isa_enable      = 0;
end

end // _gen_bridge_control
endgenerate

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        int_line_reg        <= #TP 8'hFF;
    end else begin
        int_line_reg        <= #TP (write_pulse[0] & cfg_reg_id[15]) ? lbc_cdm_data[7:0] : int_line_reg;
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_int_pin         <= #TP `INT_PIN_MAPPING;
    end else begin
        // DBI writable register
        cfg_int_pin         <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_reg_id[15]) ? lbc_cdm_data[15:8] : cfg_int_pin;
    end
end

// Group BAR enables
assign cfg_bar_enabled = { bar5_enabled, bar4_enabled, bar3_enabled, bar2_enabled, bar1_enabled, bar0_enabled};
// The following is used to determine if the function has any active Memory or
// IO BARs. Determines if Memory and IO space enables are Read Only or
// Read/Write as per section 6.2.2 of PCI Local bus specification.
// Only applies to endpoint devices. Switches and root ports always
// support IO and Memory ranges
assign has_mem_bar =
    ~type0 || |(cfg_bar_enabled & ~cfg_bar_is_io) || rom_bar_enabled;
assign has_io_bar = ~type0 || |(cfg_bar_enabled & cfg_bar_is_io);

//==============================================================================
//
// PCI Capability List Structure -- pointed to by capabilities pointer register
//
//==============================================================================

// =============================================================================
// Power Management Capability Structure
// =============================================================================

  cdm_pm_reg
   #(.INST(INST), .FUNC_NUM(FUNC_NUM),  .VF_IMPL(0)
, .RCRB(RCRB)
  ) u_cdm_pm_reg
  (
// ---------- Inputs --------
    .core_clk            (core_clk),
    .non_sticky_rst_n    (non_sticky_rst_n),
    .sticky_rst_n    (sticky_rst_n),
    .cdm_clk_g           (cdm_clk_g),
    .flr_rst_n           (1'b1),
    .lbc_cdm_data        (lbc_cdm_data),
    .lbc_cdm_dbi         (int_lbc_cdm_dbi),
    .pm_write_pulse      (write_pulse),
    .pm_reg_id           (pm_reg_id),
    .aux_pwr_det         (aux_pwr_det),
    .pm_status           (pm_status),
    .pm_pme_en           (pm_pme_en),
    .d0_active_detect    (d0_active_detect),
    .pme_support         (5'b00000), // Not Required for PFs
    .pm_d2_support       (1'b0),     // Not Required for PFs
    .pm_d1_support       (1'b0),     // Not Required for PFs
    .pm_no_soft_rst      (1'b0),     // Not Required for PFs
    .app_ltr_msg_req            (app_ltr_msg_req),
    .msg_ltr_det                (msg_ltr_det),
    .ltr_m_en_fn0               (ltr_m_en_fn0),
    .msgg2cdm_ltr_clr_msg_grant (msgg2cdm_ltr_clr_msg_grant),
    .cdmpl2cfg_ltr_rq           (cdmpl2cfg_ltr_rq),
    .upstream_port              (upstream_port),
    .rdlh_link_up               (rdlh_link_up),
    .cfg_disable_ltr_clr_msg    (cfg_disable_ltr_clr_msg),
    .cxl_rcrb_enable     (cxl_rcrb_enable),

// ---------- Outputs --------
    .cfg_upd_pmcsr       (cfg_upd_pmcsr),
    .cfg_pmstatus_clr    (cfg_pmstatus_clr),
    .cfg_pmstate         (cfg_pmstate),
    .cfg_pme_en          (cfg_pme_en),
    .cfg_pme_cap         (cfg_pme_cap),
    .cfg_pm_no_soft_rst  (cfg_pm_no_soft_rst),
    .pm_ltr_clr_msg_req  (cfg_ltr_clr_msg_req),
    .pm_reg_data         (pm_reg_data),
    .cfg_upd_pme_cap     (cfg_upd_pme_cap)

  );  //cdm_pm_reg
// =============================================================================
// MSI Capability Structure
// =============================================================================
generate

if(FUNC_NUM < MSI_NF ) begin : gen_msi
  cdm_msi_reg
   #(.INST(INST), .VF_IMPL(0), .FUNC_NUM(FUNC_NUM)
, .RCRB(RCRB)
  ) u_cdm_msi_reg
  (
// ---------- Inputs --------
    .core_clk            (core_clk),
    .non_sticky_rst_n    (non_sticky_rst_n),
    .sticky_rst_n        (sticky_rst_n),
    .cdm_clk_g           (cdm_clk_g),
    .flr_rst_n           (1'b1),
    .lbc_cdm_data        (lbc_cdm_data),
    .lbc_cdm_dbi         (int_lbc_cdm_dbi),
    .msi_write_pulse     (write_pulse),
    .msi_read_pulse      (cap_reg_read_pulse),
    .msi_reg_id          (msi_reg_id[5:0]),
    .cfg_msi_pending     (32'b0),
    .cxl_rcrb_enable     (cxl_rcrb_enable),
// ---------- Outputs --------
    .cfg_multi_msi_en    (cfg_multi_msi_en),
    .cfg_msi_ext_data_en (cfg_msi_ext_data_en),
    .cfg_msi_en          (cfg_msi_en),
    .cfg_msi_addr        (cfg_msi_addr),
    .cfg_msi_data        (cfg_msi_data),
    .cfg_msi_64          (cfg_msi_64),
    .cfg_msi_mask        (cfg_msi_mask),
    .msi_reg_data        (msi_reg_data)
  );
end 
else //FUNC_NUM >= MSI_NF
begin : gen_unc_msi

   assign cfg_multi_msi_en    = 3'b000;
   assign cfg_msi_ext_data_en = 1'b0;
   assign cfg_msi_en          = 1'b0;
   assign cfg_msi_addr        = {64{1'b0}};
   assign cfg_msi_data        = {32{1'b0}};
   assign cfg_msi_64          = 1'b0;
   assign cfg_msi_mask        = {32{1'b0}};
   assign msi_reg_data        = {32{1'b0}};
end
endgenerate
// =============================================================================
// PCI-Express Capability Structure
// =============================================================================

// -----------------------------------------------------------------------------
// PCI-E cap list register
// -----------------------------------------------------------------------------
// Capability ID    - PCI-E capability and ID
// cfg_cap_reg_id   - 6
// PCIE Offset      - `CFG_PCIE_CAP
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_88, cfg_reg_89, cfg_reg_90, cfg_reg_91
// -----------------------------------------------------------------------------
reg [7:0]   cfg_pcie_cap_next_ptr;
reg         cfg_pcie_cap_slot_impl;
//bit 15 of PCI Express Capabilities Register (Offset 02h) 
reg         cfg_pcie_cap_flit_mode_sup;
reg         cfg_flit_mode_dis;//Link Control (10h)
assign cfg_reg_88 = 8'h10;                  // PCI-E capability ID
assign cfg_reg_89 = cfg_pcie_cap_next_ptr;
assign cfg_reg_90 = (|RCRB) ? ({4'h0, 4'h2}) : cxl_rcrb_enable ? ({`RCIEP, 4'h2}) : ({device_type, 4'h2}); // device/port type and Cap version
assign cfg_reg_91 = { cfg_pcie_cap_flit_mode_sup, 1'b0, cfg_pcie_cap_int_msg_num, cfg_pcie_cap_slot_impl};

reg pcie_next_ptr_wr_updated;
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
      cfg_pcie_cap_next_ptr    <= #TP `PCIE_NEXT_PTR;
        pcie_next_ptr_wr_updated <= #TP 1'b0;
    end
    else begin
        if (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[6]) begin
           cfg_pcie_cap_next_ptr    <= #TP lbc_cdm_data[15:8];
           pcie_next_ptr_wr_updated <= #TP 1'b1;
        end
        else if (!pcie_next_ptr_wr_updated) begin 
           cfg_pcie_cap_next_ptr   <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_PCIE_NEXT_PTR : `CXL_PCIE_NEXT_PTR : `PCIE_NEXT_PTR ;
        end
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_cap_slot_impl    <= #TP `SLOT_IMPLEMENTED;
        cfg_pcie_cap_int_msg_num  <= #TP `PCIE_CAP_INT_MSG_NUM;
        cfg_pcie_cap_flit_mode_sup <= #TP `CX_FLIT_MODE_SUPPORTED; 

    end
    else begin
        cfg_pcie_cap_slot_impl    <= #TP (|RCRB) ? 1'b0 : (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[6]) ? lbc_cdm_data[24]   : cfg_pcie_cap_slot_impl;
        cfg_pcie_cap_int_msg_num  <= #TP (|RCRB) ? 5'd0 : (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[6]) ? lbc_cdm_data[29:25]: cfg_pcie_cap_int_msg_num;
         cfg_pcie_cap_flit_mode_sup <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[6]) ? lbc_cdm_data[31] : cfg_pcie_cap_flit_mode_sup;
    end
end

// -----------------------------------------------------------------------------
// Device Capabilities Register
// cfg_cap_reg_id   - 7
// PCIE Offset      - `CFG_PCIE_CAP + 04h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_92, cfg_reg_93, cfg_reg_94, cfg_reg_95
// -----------------------------------------------------------------------------
reg [2:0]   cfg_pcie_max_pyld_size_cap;
reg [1:0]   cfg_pcie_phantom_func_cap;
reg         cfg_pcie_ext_tag_field_cap;
reg [2:0]   cfg_pcie_ep_l0s_latency_cap;
reg [2:0]   cfg_pcie_ep_l1_latency_cap;
reg         cfg_pcie_rolebased_err_rpt;
reg         cfg_pcie_flr_cap;
wire        cfg_rx_mps_fixed;
wire        cfg_mixed_mps_sup;
assign  cfg_rx_mps_fixed  = `CX_RX_MPS_FIXED;
assign  cfg_mixed_mps_sup = `CX_MIXED_MPS_SUPPORTED;

assign {cfg_reg_93, cfg_reg_92} = { cfg_pcie_rolebased_err_rpt,
                                    3'b0,
                                    cfg_pcie_ep_l1_latency_cap,
                                    cfg_pcie_ep_l0s_latency_cap,
                                    cfg_pcie_ext_tag_field_cap,
                                    cfg_pcie_phantom_func_cap,
                                    cfg_pcie_max_pyld_size_cap};

// cap_slot_pwr_limit_val and capt_slot_pwr_limit_scale are only applied to upstrm port, otherwise is wired to 0

assign {cfg_reg_95, cfg_reg_94} = upstream_port ? {1'b0, 1'b0, cfg_mixed_mps_sup, cfg_pcie_flr_cap, rcvd_slot_pwr_limit_scale, rcvd_slot_pwr_limit_val, cfg_rx_mps_fixed, 1'b0} : {1'b0, 1'b0, cfg_mixed_mps_sup, 11'b0 , cfg_rx_mps_fixed, 1'b0};

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_max_pyld_size_cap      <= #TP `DEFAULT_MAX_PAYLOAD_SIZE_SUPPORTED;
        cfg_pcie_phantom_func_cap       <= #TP `DEFAULT_PHANTOM_FUNC_SUPPORTED;
        cfg_pcie_ext_tag_field_cap      <= #TP `DEFAULT_EXT_TAG_FIELD_SUPPORTED;
        cfg_pcie_rolebased_err_rpt      <= #TP 1'b1;                                    // 1.1 support
        cfg_pcie_flr_cap                <= #TP `CX_FLR_ENABLE_VALUE;
    end
    else if (|RCRB) begin
        cfg_pcie_max_pyld_size_cap      <= #TP 0; 
        cfg_pcie_phantom_func_cap       <= #TP 0;
        cfg_pcie_ext_tag_field_cap      <= #TP 0;
        cfg_pcie_rolebased_err_rpt      <= #TP 0;                                  
        cfg_pcie_flr_cap                <= #TP 0;
    end
    else begin
        cfg_pcie_max_pyld_size_cap      <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[2:0] : cfg_pcie_max_pyld_size_cap;
        cfg_pcie_phantom_func_cap       <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[4:3] : cfg_pcie_phantom_func_cap;
        cfg_pcie_ext_tag_field_cap      <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[5]   : cfg_pcie_ext_tag_field_cap;
        cfg_pcie_rolebased_err_rpt      <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[7]) ? lbc_cdm_data[15]  : cfg_pcie_rolebased_err_rpt;
        cfg_pcie_flr_cap                <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[7] & ~|RCRB) ? lbc_cdm_data[28]  : cfg_pcie_flr_cap;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_ep_l0s_latency_cap     <= #TP `DEFAULT_EP_L0S_ACCPT_LATENCY;
        cfg_pcie_ep_l1_latency_cap      <= #TP `DEFAULT_EP_L1_ACCPT_LATENCY;
    end
    else if (|RCRB) begin
        cfg_pcie_ep_l0s_latency_cap     <= #TP 0;
        cfg_pcie_ep_l1_latency_cap      <= #TP 0;
    end
    else begin
       
        cfg_pcie_ep_l0s_latency_cap[1:0]<= #TP (!end_device) ? 2'b0 : ((int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[7]) ? lbc_cdm_data[7:6] : cfg_pcie_ep_l0s_latency_cap[1:0]);
        cfg_pcie_ep_l0s_latency_cap[2]  <= #TP (!end_device) ? 1'b0 : ((int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[7]) ? lbc_cdm_data[8]   : cfg_pcie_ep_l0s_latency_cap[2]);
        cfg_pcie_ep_l1_latency_cap      <= #TP !end_device                                             ? 3'b0
                                              : (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[7]) ? lbc_cdm_data[11:9]
                                              : cfg_pcie_ep_l1_latency_cap;
    end
end

// -----------------------------------------------------------------------------
// Device Control & Status Register
// cfg_cap_reg_id   - 8
// PCIE Offset      - `CFG_PCIE_CAP + 08h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_96, cfg_reg_97, cfg_reg_98, cfg_reg_99
// -----------------------------------------------------------------------------

//
// Device Control register (08h)
//
reg  [2:0] cfg_max_payload_size_int;
wire [2:0] cfg_max_payload_size_bcm36;
assign {cfg_reg_97, cfg_reg_96} = {1'b0, cfg_max_rd_req_size, cfg_no_snoop_en, aux_pm_en, cfg_phantom_fun_en,
                                   cfg_ext_tag_en,
                                   cfg_max_payload_size_int, cfg_relax_ord_en, cfg_unsupt_req_rpt_en,
                                   cfg_f_err_rpt_en, cfg_nf_err_rpt_en, cfg_cor_err_rpt_en};

reg cfg_upd_aux_pm_en;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_aux_pm_en          <= #TP 0;
        cfg_upd_aux_pm_en      <= #TP 0;
    end else if (|RCRB) begin
        cfg_aux_pm_en          <= #TP 0;
        cfg_upd_aux_pm_en      <= #TP 0;
    end else begin
        // cfg_aux_pm_en is hardwired to 0 when aux_pwr_det = 0
        cfg_aux_pm_en          <= #TP write_pulse[1] & cfg_cap_reg_id[8] & aux_pwr_det ? lbc_cdm_data[10]: cfg_aux_pm_en;
        cfg_upd_aux_pm_en      <= #TP write_pulse[1] & cfg_cap_reg_id[8];
    end
end


wire [2:0] cfg_pcie_max_pyld_size_cap_bcm36; 
DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits({cfg_max_payload_size_int ,cfg_pcie_max_pyld_size_cap})),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_max_payload_size (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (non_sticky_rst_n),
`endif // SYNTHESIS
  .data_s  ({cfg_max_payload_size_int , cfg_pcie_max_pyld_size_cap }),
  .data_d  ({cfg_max_payload_size_bcm36 ,cfg_pcie_max_pyld_size_cap_bcm36 })
);

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_cor_err_rpt_en      <= #TP 0;
        cfg_nf_err_rpt_en       <= #TP 0;
        cfg_f_err_rpt_en        <= #TP 0;
        cfg_unsupt_req_rpt_en   <= #TP 0;
        cfg_ext_tag_en          <= #TP `DEFAULT_EXT_TAG_FIELD_SUPPORTED;
        cfg_phantom_fun_en      <= #TP 0;
        cfg_no_snoop_en         <= #TP `DEFAULT_NO_SNOOP_SUPPORTED;
        cfg_max_rd_req_size     <= #TP 3'b010;
        cfg_bridge_crs_en       <= #TP 0;
    end else if (|RCRB) begin
        cfg_cor_err_rpt_en      <= #TP 0;
        cfg_nf_err_rpt_en       <= #TP 0;
        cfg_f_err_rpt_en        <= #TP 0;
        cfg_unsupt_req_rpt_en   <= #TP 0;
        cfg_ext_tag_en          <= #TP 0;
        cfg_phantom_fun_en      <= #TP 0;
        cfg_no_snoop_en         <= #TP 0;
        cfg_max_rd_req_size     <= #TP 0;
        cfg_bridge_crs_en       <= #TP 0;
    end else begin
        cfg_cor_err_rpt_en      <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[0] : cfg_cor_err_rpt_en;
        cfg_nf_err_rpt_en       <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[1] : cfg_nf_err_rpt_en;
        cfg_f_err_rpt_en        <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[2] : cfg_f_err_rpt_en;
        cfg_unsupt_req_rpt_en   <= #TP write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[3] : cfg_unsupt_req_rpt_en;
        cfg_ext_tag_en          <= #TP cfg_pcie_ext_tag_field_cap ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[8] : cfg_ext_tag_en) : 0;
        cfg_phantom_fun_en      <= #TP (cfg_pcie_phantom_func_cap != 2'h0) ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[9] : cfg_phantom_fun_en) : 0;
        cfg_no_snoop_en         <= #TP `DEFAULT_NO_SNOOP_SUPPORTED ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[11] : cfg_no_snoop_en) : 0;
        cfg_max_rd_req_size     <= #TP (write_pulse[1] & cfg_cap_reg_id[8]) ? lbc_cdm_data[14:12] : cfg_max_rd_req_size;
        cfg_bridge_crs_en       <= #TP bridge_device ? (write_pulse[1] & cfg_cap_reg_id[8] ? lbc_cdm_data[15] : cfg_bridge_crs_en) : 0;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_relax_ord_en        <= #TP 1'b1;
    end else if (|RCRB) begin
        cfg_relax_ord_en        <= #TP 0;
    end else begin
        cfg_relax_ord_en        <= #TP bridge_device ? 1'b0 : write_pulse[0] & cfg_cap_reg_id[8] ? lbc_cdm_data[4] : cfg_relax_ord_en;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_max_payload_size_int    <= #TP 0;
    end else if (|RCRB) begin
        cfg_max_payload_size_int    <= #TP 0;
    end else begin
        cfg_max_payload_size_int    <= #TP (write_pulse[0] & cfg_cap_reg_id[8]) ? lbc_cdm_data[7:5] : cfg_max_payload_size_int;

    end
end


// RX_MPS_LIMIT is the computed data payload size limit for a Function receiving a TLP, which is determined by the Rx_MPS_Fixed bit value and Max_Payload_Size setting in one or more Functions.
// section 7.5.3.3, If the Rx_MPS_Fixed bit is Set, the Function's Rx_MPS_Limit is fixed with the value indicated by this (Max_Payload_Size Supported) field. 
// Otherwise, the Rx_MPS_Limit is determined by the Max_Payload_Size field (the "MPS setting") in one or more Functions


//In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field and this only goes to the TLP check logic inside the radm multi-stream.
assign cfg_max_payload_size_out_rx = (cfg_rx_mps_fixed)? cfg_pcie_max_pyld_size_cap_bcm36 : cfg_max_payload_size_bcm36;
assign cfg_max_payload_size_out = cfg_max_payload_size_bcm36;



//
// Status register (0Ah)
//

// For RC and Switch devices that don't issue Non-posted transaction, hardwire to 0
wire transaction_pending;
assign transaction_pending = (|RCRB) ? 1'b0 : (rc_device | switch_device) ? 0 : radm_cpl_pending;


// RW1C registers.  Write 1 to clear.
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_cor_err_det_reg     <= #TP 0;
        cfg_nf_err_det_reg      <= #TP 0;
        cfg_f_err_det_reg       <= #TP 0;
        cfg_unsupt_req_det_reg  <= #TP 0;
    end else if (|RCRB) begin
        cfg_cor_err_det_reg     <= #TP 0;
        cfg_nf_err_det_reg      <= #TP 0;
        cfg_f_err_det_reg       <= #TP 0;
        cfg_unsupt_req_det_reg  <= #TP 0;
    end else begin
        cfg_cor_err_det_reg     <= #TP cfg_cor_err_det    ? 1'b1 : 
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[16]) ? 1'b0 : 
                                       cfg_cor_err_det_reg;

        cfg_nf_err_det_reg      <= #TP cfg_nf_err_det     ? 1'b1 :
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[17]) ? 1'b0 :  
                                       cfg_nf_err_det_reg;

        cfg_f_err_det_reg       <= #TP cfg_f_err_det      ? 1'b1 :
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[18]) ? 1'b0 :  
                                       cfg_f_err_det_reg;

        cfg_unsupt_req_det_reg  <= #TP cfg_unsupt_req_det ? 1'b1 :
                                       (write_pulse[2] & cfg_cap_reg_id[8] & lbc_cdm_data[19]) ? 1'b0 :  
                                       cfg_unsupt_req_det_reg;
    end
end



assign cfg_reg_98 = {1'b0,                              1'b0,
 transaction_pending, aux_pwr_det, cfg_unsupt_req_det_reg, cfg_f_err_det_reg, cfg_nf_err_det_reg, cfg_cor_err_det_reg};
assign cfg_reg_99 = 8'b0;


// -----------------------------------------------------------------------------
// Link Capabilities Register
// cfg_cap_reg_id   - 9
// PCIE Offset      - `CFG_PCIE_CAP + 0Ch
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_100, cfg_reg_101, cfg_reg_102, cfg_reg_103
// -----------------------------------------------------------------------------
wire[5:0]   cfg_pcie_max_link_width;
reg [5:0]   cfg_pcie_max_link_width_int;
reg [1:0]   cfg_pcie_aspm_cap;
wire [1:0]  cfg_pcie_aspm_cap_mux;
assign      cfg_pcie_aspm_cap_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 2'd0 : cfg_pcie_aspm_cap;
reg [2:0]   int_pcie_l0s_exit_latency;
reg [2:0]   int_pcie_l1_exit_latency;
wire[2:0]   cfg_pcie_l0s_exit_latency;
wire[2:0]   cfg_pcie_l1_exit_latency;

reg [2:0]   cfg_pcie_comm_l0s_exit_latency;
reg [2:0]   cfg_pcie_comm_l1_exit_latency;

assign cfg_pcie_l0s_exit_latency= (cxl_rcrb_enable & ~(|RCRB)) ? 3'd0 : cfg_comm_clk_config ? cfg_pcie_comm_l0s_exit_latency : int_pcie_l0s_exit_latency;
assign cfg_pcie_l1_exit_latency = (cxl_rcrb_enable & ~(|RCRB)) ? 3'd0 : cfg_comm_clk_config ? cfg_pcie_comm_l1_exit_latency : int_pcie_l1_exit_latency;

reg         cfg_clk_pm_cap;
wire        cfg_clk_pm_cap_mux;
assign      cfg_clk_pm_cap_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_clk_pm_cap;
reg         cfg_pcie_slot_hp_cap;
reg         cfg_pcie_surp_dn_rpt_cap;
wire        cfg_pcie_surp_dn_rpt_cap_mux;
assign      cfg_pcie_surp_dn_rpt_cap_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_pcie_surp_dn_rpt_cap;
reg         cfg_bw_notification_cap;
wire        cfg_bw_notification_cap_mux;
assign      cfg_bw_notification_cap_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_bw_notification_cap;
reg [7:0]   cfg_pcie_port_num;
reg         cfg_aspm_optionality_compliance;
wire        cfg_aspm_optionality_compliance_mux;
assign      cfg_aspm_optionality_compliance_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_aspm_optionality_compliance;
wire        cfg_dll_link_rpt_en;

assign      cfg_pcie_max_link_speed     = (cxl_rcrb_enable & ~(|RCRB)) ? 4'd0 : cfg_pcie_max_link_speed_int ;
assign      cfg_pcie_max_link_width     = (cxl_rcrb_enable & ~(|RCRB)) ? 6'd0 : cfg_pcie_max_link_width_int ;

assign cfg_link_rate      = cfg_reg_100[3:0];

assign {cfg_reg_102, cfg_reg_101, cfg_reg_100} = {1'b0,
                                                  cfg_aspm_optionality_compliance_mux, 
                                                  cfg_bw_notification_cap_mux,
                                                  cfg_dll_link_rpt_en,
                                                  cfg_pcie_surp_dn_rpt_cap_mux,
                                                  cfg_clk_pm_cap_mux,
                                                  cfg_pcie_l1_exit_latency,
                                                  cfg_pcie_l0s_exit_latency,
                                                  cfg_pcie_aspm_cap_mux,
                                                  cfg_pcie_max_link_width,
                                                  cfg_pcie_max_link_speed};
assign cfg_reg_103 = (cxl_rcrb_enable & ~(|RCRB)) ? 8'd0 : cfg_pcie_port_num;

// DLL link active reporting capable - always enabled when downstream port
assign cfg_dll_link_rpt_en = ~upstream_port;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        int_pcie_l1_exit_latency        <= #TP `DEFAULT_L1_EXIT_LATENCY;
        cfg_pcie_comm_l1_exit_latency   <= #TP `DEFAULT_COMM_L1_EXIT_LATENCY;
        cfg_aspm_optionality_compliance <= #TP `ASPM_OPTIONALITY_COMPLIANCE;
        cfg_pcie_port_num               <= #TP `PORT_NUM;
    end else begin                                       
        
        int_pcie_l1_exit_latency[0]     <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[15]
                                              : int_pcie_l1_exit_latency[0];
        int_pcie_l1_exit_latency[2:1]   <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[17:16]
                                                  : int_pcie_l1_exit_latency[2:1];
        cfg_pcie_comm_l1_exit_latency[0]    <= #TP (lbc_cdm_dbi2 & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[15]
                                                  : cfg_pcie_comm_l1_exit_latency[0];
        cfg_pcie_comm_l1_exit_latency[2:1]  <= #TP (lbc_cdm_dbi2 & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[17:16]
                                                  : cfg_pcie_comm_l1_exit_latency[2:1];
        cfg_aspm_optionality_compliance     <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[22] : cfg_aspm_optionality_compliance;
        cfg_pcie_port_num                   <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[9]) ? lbc_cdm_data[31:24] : cfg_pcie_port_num;
    end
end


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        int_pcie_l0s_exit_latency       <= #TP `DEFAULT_L0S_EXIT_LATENCY;
        cfg_pcie_comm_l0s_exit_latency  <= #TP `DEFAULT_COMM_L0S_EXIT_LATENCY;
        cfg_pcie_surp_dn_rpt_cap        <= #TP `DEFAULT_SURPRISE_DOWN_RPT_CAP;
        cfg_pcie_aspm_cap               <= #TP `AS_LINK_PM_SUPT;
        cfg_bw_notification_cap         <= #TP 1'b1;
    end else begin                                       
        int_pcie_l0s_exit_latency       <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[14:12] : cfg_pcie_l0s_exit_latency;
        cfg_pcie_comm_l0s_exit_latency  <= #TP (lbc_cdm_dbi2 & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[14:12]   : cfg_pcie_comm_l0s_exit_latency;
        cfg_pcie_surp_dn_rpt_cap        <= #TP upstream_port ? 1'b0 : (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[19] : cfg_pcie_surp_dn_rpt_cap;  
        cfg_pcie_aspm_cap[0]            <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[10]    : cfg_pcie_aspm_cap[0];
        cfg_pcie_aspm_cap[1]            <= #TP                                           (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[11]    : cfg_pcie_aspm_cap[1];
        cfg_bw_notification_cap         <= #TP upstream_port ? 1'b0 : (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[21] : cfg_bw_notification_cap;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_pcie_max_link_speed_int     <= #TP `MAX_LINK_SP;
        cfg_pcie_max_link_width_int     <= #TP `MAX_LINK_WIDTH;
    end else begin
        cfg_pcie_max_link_speed_int         <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[9]) ? lbc_cdm_data[3:0]   : cfg_pcie_max_link_speed_int;
        cfg_pcie_max_link_width_int[3:0]    <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[9]) ? lbc_cdm_data[7:4]   : cfg_pcie_max_link_width_int[3:0];
        cfg_pcie_max_link_width_int[5:4]    <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[9]) ? lbc_cdm_data[9:8]   : cfg_pcie_max_link_width_int[5:4];
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_clk_pm_cap                  <= #TP `DEFAULT_CLK_PM_CAP;
  end else begin
    cfg_clk_pm_cap                  <= #TP !(app_clk_pm_en && upstream_port) ? 0 : ((int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[9]) ? lbc_cdm_data[18]    : cfg_clk_pm_cap); 
  end
end



//

// -----------------------------------------------------------------------------
// Link Control & Status Register
// cfg_cap_reg_id   - 10
// PCIE Offset      - `CFG_PCIE_CAP + 10h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_104, cfg_reg_105, cfg_reg_106, cfg_reg_107
// -----------------------------------------------------------------------------

// Link Control (10h)
reg     cfg_pcie_root_rcb;
reg     cfg_link_auto_bw_int_en;
reg     cfg_bw_mgt_int_en;
reg     cfg_flit_sris_clocking;
wire    cfg_flit_sris_clocking_mux;
assign cfg_flit_sris_clocking_mux = upstream_port ? 1'b0 : cfg_flit_sris_clocking;
// RCB: if Switch, hardwire to 0.  If root port, RO.  If endpoints, RW.
reg  other_rcb;

assign cfg_reg_104 = (cxl_rcrb_enable & ~(|RCRB)) ? 8'd0 : 
                      {
                        cfg_ext_synch_int
                       ,cfg_comm_clk_config
                       , 1'b0
                       , cfg_link_dis
                       , cfg_rcb
                       ,1'b0 
                       ,cfg_aslk_pmctrl_int
                      };
assign cfg_reg_105 = (cxl_rcrb_enable & ~(|RCRB)) ? 8'd0 : {
                      cfg_drs_sig_control,
                      cfg_flit_mode_dis, 
                      cfg_flit_sris_clocking_mux,  //SRIS Clocking
                      cfg_link_auto_bw_int_en,  // Link Autonomous BW Interrupt Enable
                      cfg_bw_mgt_int_en,        // Link BW Management Interrupt Enable
                      cfg_hw_autowidth_dis,
                      cfg_clk_pm_en};


  localparam DRS_NOT_REPORTED     = 2'b00;
  localparam DRS_INT_ENABLED      = 2'b01;
  localparam DRS_FRS_SIG_ENABLED  = 2'b10;

  localparam DRS_MSI_RESET  = 2'b00;       //Reset
  localparam WAIT_DRS       = 2'b01;       //Waiting for a DRS message
  localparam DRS_RECEIVED   = 2'b11;       //DRS Message receieved
  localparam WAIT_DRS_CLEAR = 2'b10;       //wait for clearing of bit

  wire cfg_drs_frs_sig_en;

  assign cfg_drs_frs_sig_en = ((FUNC_NUM == 0) && (cfg_drs_sig_control == DRS_FRS_SIG_ENABLED));

  reg [1:0] drs_msi_state;


generate

if(FUNC_NUM==0) begin : gen_drs_msi_state

  always @(posedge core_clk or negedge non_sticky_rst_n)
    if(!non_sticky_rst_n) begin
      drs_msi_state <= #TP DRS_MSI_RESET;    
    end else begin
      // spyglass disable_block STARC05-2.11.3.1
      // SMD: Combinational and sequential parts of an FSM described in same always block 
      // SJ: Legacy code
      case (drs_msi_state[1:0])
        
        DRS_MSI_RESET:
          drs_msi_state <= #TP WAIT_DRS;

        WAIT_DRS:
          if(cfg_drs_msg_rec_reg)
            drs_msi_state <= #TP DRS_RECEIVED;
          else
            drs_msi_state <= #TP WAIT_DRS;

        DRS_RECEIVED:                                //one pulse only
          drs_msi_state <= #TP WAIT_DRS_CLEAR;

        WAIT_DRS_CLEAR:
          if(!cfg_drs_msg_rec_reg)
            drs_msi_state <= #TP WAIT_DRS;
          else
            drs_msi_state <= #TP WAIT_DRS_CLEAR;

        default:
          drs_msi_state <= #TP DRS_MSI_RESET;
      endcase
      // spyglass enable_block STARC05-2.11.3.1
    end


  assign cfg_drs_msi        = ((cfg_drs_sig_control == DRS_INT_ENABLED) && (drs_msi_state==DRS_RECEIVED) && (cfg_msi_en || cfg_msix_en));

end else begin : gen_drs_msi_state

  assign cfg_drs_msi    = 0;
  assign drs_msi_state  = 2'b00;

end // gen_drs_msi_state

endgenerate

  assign cfg_up_drs_to_frs  = ((cfg_drs_sig_control == DRS_FRS_SIG_ENABLED) && (drs_msi_state==DRS_RECEIVED) && cfg_frs_support);
//`else
//  assign cfg_up_drs_to_frs  = 1'b0;



assign int_upd_aslk_pmctrl = (write_pulse[0] & cfg_cap_reg_id[10]);
assign cfg_link_dis = pcie_or_cxl1p1_mode_enabled ? cfg_link_dis_reg : (cfg_link_dis_reg & cfg_cxl_2_0_ext_unmask_ld);

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_aslk_pmctrl_int     <= #TP 0;
        other_rcb               <= #TP 0;  // default to 64 bytes (for non-RC)
        cfg_link_dis_reg        <= #TP 0;
        cfg_link_retrain        <= #TP 0;
        cfg_comm_clk_config     <= #TP 0;
        cfg_ext_synch_int       <= #TP 0;
        cfg_upd_aslk_pmctrl     <= #TP 0;
        cfg_hw_autowidth_dis    <= #TP 0;
        cfg_flit_mode_dis       <= #TP 0;
        cfg_flit_sris_clocking  <= #TP 0;
        cfg_drs_sig_control     <= #TP DRS_NOT_REPORTED;
        cfg_pcie_root_rcb       <= #TP `ROOT_RCB;
    end else begin
        cfg_aslk_pmctrl_int     <= #TP int_upd_aslk_pmctrl ? lbc_cdm_data[1:0] : cfg_aslk_pmctrl_int;
        cfg_upd_aslk_pmctrl     <= #TP int_upd_aslk_pmctrl;
        other_rcb               <= #TP (`CX_RCB_SUPPORT & !switch_device & !rc_device & write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[3] : other_rcb;
        cfg_link_dis_reg        <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[4] & !(end_device | pcie_sw_up | bridge_device) : cfg_link_dis_reg;
        cfg_link_retrain        <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) & lbc_cdm_data[5] & !(end_device | pcie_sw_up | bridge_device);
        cfg_comm_clk_config     <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[6] : cfg_comm_clk_config;
        cfg_ext_synch_int       <= #TP (write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[7] : cfg_ext_synch_int;
        cfg_hw_autowidth_dis    <= #TP (write_pulse[1] & cfg_cap_reg_id[10] & (FUNC_NUM == 0)) ? lbc_cdm_data[9]  : cfg_hw_autowidth_dis;
        // the cxl condition is added as the flit mode disable bit is not implemented in RCiEPs.
        cfg_flit_mode_dis       <= #TP (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : (write_pulse[1] & cfg_cap_reg_id[10] &  (FUNC_NUM == 0)) ? lbc_cdm_data[13] : cfg_flit_mode_dis;
        cfg_flit_sris_clocking  <= #TP (write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[12] : cfg_flit_sris_clocking;
        if (!upstream_port && cfg_drs_support && (FUNC_NUM == 0)) begin
          cfg_drs_sig_control   <= #TP (write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[15:14] : cfg_drs_sig_control;   //RW over DBI and wire
        end else begin
          cfg_drs_sig_control   <= #TP DRS_NOT_REPORTED;     //if not functions 0, set value to 0
        end
        // Read-only if root port, but writable through DBI
        cfg_pcie_root_rcb       <= #TP (rc_device & int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[10]) ? lbc_cdm_data[3] : cfg_pcie_root_rcb;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_bw_mgt_int_en       <= #TP 1'b0;
        cfg_link_auto_bw_int_en <= #TP 1'b0;
        cfg_rcb                 <= #TP 0;
    end else begin
        cfg_bw_mgt_int_en       <= #TP cfg_bw_notification_cap ? ((write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[10] : cfg_bw_mgt_int_en) : 1'b0;
        cfg_link_auto_bw_int_en <= #TP cfg_bw_notification_cap ? ((write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[11] : cfg_link_auto_bw_int_en) : 1'b0;
        cfg_rcb                 <= #TP switch_device ? 1'b0 : rc_device ? cfg_pcie_root_rcb : other_rcb;
    end
end


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_clk_pm_en           <= #TP 0;
    end else begin
        cfg_clk_pm_en           <= #TP cfg_clk_pm_cap ? ((write_pulse[1] & cfg_cap_reg_id[10]) ? lbc_cdm_data[8]  : cfg_clk_pm_en) : 0;
    end
end

assign cfg_aslk_pmctrl = (cxl_rcrb_enable & ~(|RCRB)) ? 2'd0 : cfg_aslk_pmctrl_int;
assign cfg_ext_synch = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_ext_synch_int ;

// Link Status (12h)
reg     cfg_pcie_slot_clk_config;
wire    cfg_pcie_slot_clk_config_mux;
assign  cfg_pcie_slot_clk_config_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_pcie_slot_clk_config;
reg     cfg_bw_mgt_status;
reg     cfg_link_auto_bw_status;

wire[5:0]   int_link_width;
wire[5:0]   cfg_neg_link_width;
wire[5:0]   smlh_autoneg_link_width_set;

assign smlh_autoneg_link_width_set   = smlh_autoneg_link_width ;

assign int_link_width                = smlh_link_up ? smlh_autoneg_link_width_set : 6'b000001;

assign cfg_neg_link_width = int_link_width;

reg  cfg_dll_active_d;
wire cfg_dll_active;
assign cfg_dll_active = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : (rdlh_dlcntrl_state ==  `S_DL_ACTIVE);
wire dll_active_chnged;
assign dll_active_chnged = (cfg_dll_active != cfg_dll_active_d);


always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_dll_active_d    <= #TP 1'b0;
    end
    else begin
        cfg_dll_active_d    <= #TP cfg_dll_active;
    end
end

assign {cfg_reg_107, cfg_reg_106} = (cxl_rcrb_enable & ~(|RCRB)) ? 16'd0 : upstream_port ? 
                                                         {3'b0, cfg_pcie_slot_clk_config, 2'b0, int_link_width, smlh_autoneg_link_sp} :
                                                         {cfg_link_auto_bw_status, cfg_bw_mgt_status, cfg_dll_active, cfg_pcie_slot_clk_config, smlh_link_training_in_prog, 1'b0, int_link_width, smlh_autoneg_link_sp};


reg cfg_link_auto_bw_msi;
wire    cfg_link_auto_bw_msi_mux;
assign  cfg_link_auto_bw_msi_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_link_auto_bw_msi;
reg link_auto_bw_msi_src_d;
wire link_auto_bw_msi_src;
reg cfg_bw_mgt_msi;
wire   cfg_bw_mgt_msi_mux;
assign  cfg_bw_mgt_msi_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_bw_mgt_msi;
reg bw_mgt_msi_src_d;
wire bw_mgt_msi_src;

assign link_auto_bw_msi_src = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_link_auto_bw_int_en & cfg_link_auto_bw_status & (cfg_msi_en | cfg_msix_en);
assign bw_mgt_msi_src = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_bw_mgt_int_en & cfg_bw_mgt_status & (cfg_msi_en | cfg_msix_en);

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_pcie_slot_clk_config    <= #TP `SLOT_CLK_CONFIG;
    end else begin
        cfg_pcie_slot_clk_config    <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[10]) ? lbc_cdm_data[28] : cfg_pcie_slot_clk_config;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_bw_mgt_status           <= #TP 1'b0;
        cfg_link_auto_bw_status     <= #TP 1'b0;
        cfg_bw_mgt_int              <= #TP 1'b0;
        cfg_link_auto_bw_int        <= #TP 1'b0;
        cfg_link_auto_bw_msi        <= #TP 1'b0;
        link_auto_bw_msi_src_d      <= #TP 1'b0;
        bw_mgt_msi_src_d            <= #TP 1'b0;
        cfg_bw_mgt_msi              <= #TP 1'b0;
    end else begin
        link_auto_bw_msi_src_d      <= #TP link_auto_bw_msi_src;
        cfg_link_auto_bw_msi        <= #TP link_auto_bw_msi_src & ~link_auto_bw_msi_src_d;
        bw_mgt_msi_src_d            <= #TP bw_mgt_msi_src;
        cfg_bw_mgt_msi              <= #TP bw_mgt_msi_src & ~bw_mgt_msi_src_d;
        // Interrupt generation for Link BW Notification & link autonomous BW
        cfg_bw_mgt_int              <= #TP cfg_bw_mgt_int_en       &  cfg_bw_mgt_status & !cfg_int_disable  & ~(cfg_msi_en | cfg_msix_en) ;
        cfg_link_auto_bw_int        <= #TP cfg_link_auto_bw_int_en &  cfg_link_auto_bw_status & !cfg_int_disable  & ~(cfg_msi_en | cfg_msix_en);
        cfg_bw_mgt_status           <= #TP cfg_bw_notification_cap ? (smlh_bw_mgt_status ? 1'b1 : (write_pulse[3] & cfg_cap_reg_id[10] & lbc_cdm_data[30]) ? 1'b0 : cfg_bw_mgt_status) : 1'b0;
        cfg_link_auto_bw_status     <= #TP cfg_bw_notification_cap ? (smlh_link_auto_bw_status ? 1'b1 : (write_pulse[3] & cfg_cap_reg_id[10] & lbc_cdm_data[31]) ? 1'b0 : cfg_link_auto_bw_status) : 1'b0;
    end
end


// Slot cap is only applied to Downstream port

// -----------------------------------------------------------------------------
// Slot Capabilities Register
// cfg_cap_reg_id   - 11
// PCIE Offset      - `CFG_PCIE_CAP + 14h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_108, cfg_reg_109, cfg_reg_110, cfg_reg_111
// -----------------------------------------------------------------------------
reg [12:0]  cfg_pcie_phy_slot_num;
reg         cfg_pcie_slot_no_cc_support;
reg         cfg_pcie_slot_eml_present;
wire[9:0]   cfg_pcie_slot_pwr_limit;
reg [1:0]   cfg_pcie_slot_pwr_limit_scale;
reg [7:0]   cfg_pcie_slot_pwr_limit_value;
reg         cfg_pcie_slot_hp_surprise;
reg         cfg_pcie_slot_pwr_indc_present;
reg         cfg_pcie_slot_attn_indc_present;
reg         cfg_pcie_slot_mrl_sensor_present;
reg         cfg_pcie_slot_pwr_ctrl_present;
reg         cfg_pcie_slot_attn_butt_present;
assign      cfg_pcie_slot_pwr_limit = {cfg_pcie_slot_pwr_limit_scale, cfg_pcie_slot_pwr_limit_value};

assign  {cfg_reg_111, cfg_reg_110, cfg_reg_109, cfg_reg_108} = !upstream_port ? {cfg_pcie_phy_slot_num, cfg_pcie_slot_no_cc_support,
                                                                cfg_pcie_slot_eml_present, cfg_pcie_slot_pwr_limit_scale,
                                                                cfg_pcie_slot_pwr_limit_value, cfg_pcie_slot_hp_cap,
                                                                cfg_pcie_slot_hp_surprise, cfg_pcie_slot_pwr_indc_present,
                                                                cfg_pcie_slot_attn_indc_present, cfg_pcie_slot_mrl_sensor_present,
                                                                cfg_pcie_slot_pwr_ctrl_present, cfg_pcie_slot_attn_butt_present}
                                                                              : 32'h0;



// Detect a write to this register because it'll cause set_slot_pwr_limit message to be sent.
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_slot_pwr_limit_wr   <= #TP 0;
    end else begin
        cfg_slot_pwr_limit_wr   <= #TP |write_pulse[2:0] & cfg_cap_reg_id[11];
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n) begin
        cfg_pcie_phy_slot_num           <= #TP `SLOT_PHY_SLOT_NUM;
        cfg_pcie_slot_no_cc_support     <= #TP `SLOT_NO_CC_SUPPORT;
        cfg_pcie_slot_eml_present       <= #TP `SLOT_EML_PRESENT;
        cfg_pcie_slot_pwr_limit_scale   <= #TP `SET_SLOT_PWR_LIMIT_SCALE;
        cfg_pcie_slot_pwr_limit_value   <= #TP `SET_SLOT_PWR_LIMIT_VAL;
        cfg_pcie_slot_hp_cap            <= #TP `SLOT_HP_CAPABLE;
        cfg_pcie_slot_hp_surprise       <= #TP `SLOT_HP_SURPRISE;
        cfg_pcie_slot_pwr_indc_present  <= #TP `SLOT_PWR_IND_PRESENT;
        cfg_pcie_slot_attn_indc_present <= #TP `SLOT_ATTEN_IND_PRESENT;
        cfg_pcie_slot_mrl_sensor_present<= #TP `SLOT_MRL_SENSOR_PRESENT;
        cfg_pcie_slot_pwr_ctrl_present  <= #TP `SLOT_PWR_CTRL_PRESENT;
        cfg_pcie_slot_attn_butt_present <= #TP `SLOT_ATTEN_BUTTON_PRESENT;
    end else begin
        if (!upstream_port) begin
            cfg_pcie_phy_slot_num[12:5]     <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[11]) ? lbc_cdm_data[31:24] : cfg_pcie_phy_slot_num[12:5];
            cfg_pcie_phy_slot_num[4:0]      <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[23:19] : cfg_pcie_phy_slot_num[4:0];
            cfg_pcie_slot_no_cc_support     <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[18] : cfg_pcie_slot_no_cc_support;
            cfg_pcie_slot_eml_present       <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[17] : cfg_pcie_slot_eml_present;
            cfg_pcie_slot_pwr_limit_scale[1]<= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[11]) ? lbc_cdm_data[16] : cfg_pcie_slot_pwr_limit_scale[1];
            cfg_pcie_slot_pwr_limit_scale[0]<= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[11]) ? lbc_cdm_data[15] : cfg_pcie_slot_pwr_limit_scale[0];
            cfg_pcie_slot_pwr_limit_value[7:1]<= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[11]) ? lbc_cdm_data[14:8] : cfg_pcie_slot_pwr_limit_value[7:1];
            cfg_pcie_slot_pwr_limit_value[0]<= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[7] : cfg_pcie_slot_pwr_limit_value[0];
            cfg_pcie_slot_hp_cap            <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[6] : cfg_pcie_slot_hp_cap;
            cfg_pcie_slot_hp_surprise       <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[5] : cfg_pcie_slot_hp_surprise;
            cfg_pcie_slot_pwr_indc_present  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[4] : cfg_pcie_slot_pwr_indc_present;
            cfg_pcie_slot_attn_indc_present <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[3] : cfg_pcie_slot_attn_indc_present;
            cfg_pcie_slot_mrl_sensor_present<= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[2] : cfg_pcie_slot_mrl_sensor_present;
            cfg_pcie_slot_pwr_ctrl_present  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[1] : cfg_pcie_slot_pwr_ctrl_present;
            cfg_pcie_slot_attn_butt_present <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[11]) ? lbc_cdm_data[0] : cfg_pcie_slot_attn_butt_present;
        end
        else begin
            cfg_pcie_phy_slot_num           <= #TP `SLOT_PHY_SLOT_NUM;
            cfg_pcie_slot_no_cc_support     <= #TP `SLOT_NO_CC_SUPPORT;
            cfg_pcie_slot_eml_present       <= #TP `SLOT_EML_PRESENT;
            cfg_pcie_slot_pwr_limit_scale   <= #TP `SET_SLOT_PWR_LIMIT_SCALE;
            cfg_pcie_slot_pwr_limit_value   <= #TP `SET_SLOT_PWR_LIMIT_VAL;
            cfg_pcie_slot_hp_cap            <= #TP `SLOT_HP_CAPABLE;
            cfg_pcie_slot_hp_surprise       <= #TP `SLOT_HP_SURPRISE;
            cfg_pcie_slot_pwr_indc_present  <= #TP `SLOT_PWR_IND_PRESENT;
            cfg_pcie_slot_attn_indc_present <= #TP `SLOT_ATTEN_IND_PRESENT;
            cfg_pcie_slot_mrl_sensor_present<= #TP `SLOT_MRL_SENSOR_PRESENT;
            cfg_pcie_slot_pwr_ctrl_present  <= #TP `SLOT_PWR_CTRL_PRESENT;
            cfg_pcie_slot_attn_butt_present <= #TP `SLOT_ATTEN_BUTTON_PRESENT;
        end
    end
end

// -----------------------------------------------------------------------------
// Slot Control/Status Register
// cfg_cap_reg_id   - 12
// PCIE Offset      - `CFG_PCIE_CAP + 18h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_112, cfg_reg_113, cfg_reg_114, cfg_reg_115
// -----------------------------------------------------------------------------
reg cfg_dll_state_chged_reg;
reg cfg_atten_button_pressed_reg;
reg cfg_pwr_fault_det_reg;
reg cfg_mrl_sensor_chged_reg;
reg cfg_pre_det_chged_reg;
reg cfg_cmd_cpled_int_reg;
reg cfg_pre_det_chged_en;
reg cfg_mrl_sensor_chged_en_r;
reg cfg_pwr_fault_det_en_r;
reg cfg_atten_button_pressed_en_r;
reg cfg_cmd_cpled_int_en_r;
reg cfg_hp_slot_ctrl_access;
reg r_auto_slot_pwr_lmt_dis;


// Output to Hot-plug controller
assign cfg_atten_button_pressed = cfg_atten_button_pressed_reg & cfg_atten_button_pressed_en_r;
assign cfg_pwr_fault_det        = cfg_pwr_fault_det_reg        & cfg_pwr_fault_det_en_r;
assign cfg_mrl_sensor_chged     = cfg_mrl_sensor_chged_reg     & cfg_mrl_sensor_chged_en_r;
assign cfg_pre_det_chged        = cfg_pre_det_chged_reg        & cfg_pre_det_chged_en;
assign cfg_cmd_cpled_int        = cfg_cmd_cpled_int_reg        & cfg_cmd_cpled_int_en_r;
assign cfg_dll_state_chged      = cfg_dll_state_chged_reg      & cfg_dll_state_chged_en;

// Slot Control
assign cfg_reg_112  = !upstream_port ? {cfg_atten_ind, cfg_hp_int_en, cfg_cmd_cpled_int_en_r, cfg_pre_det_chged_en,
                       cfg_mrl_sensor_chged_en_r, cfg_pwr_fault_det_en_r, cfg_atten_button_pressed_en_r}
                                     : 8'h0;
assign cfg_reg_113  = !upstream_port ? {2'b0, cfg_auto_slot_pwr_lmt_dis, cfg_dll_state_chged_en , 1'b0, cfg_pwr_ctrler_ctrl, cfg_pwr_ind}
                                     : 8'h0;
// Slot Status

assign cfg_reg_115  = !upstream_port ? {7'b0, cfg_dll_state_chged_reg} : 8'h0;
assign cfg_reg_114  = !upstream_port ? {sys_eml_interlock_engaged,
                                       (upstream_port ? 1'b0 : (cfg_pcie_cap_slot_impl ? sys_pre_det_state : 1'b1)),
                                       sys_mrl_sensor_state,
                                       cfg_cmd_cpled_int_reg,
                                       cfg_pre_det_chged_reg,
                                       cfg_mrl_sensor_chged_reg,
                                       cfg_pwr_fault_det_reg,
                                       cfg_atten_button_pressed_reg}
                                     : 8'h0;

  always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
  begin
    if (!non_sticky_rst_n) begin
      cfg_hp_slot_ctrl_access <= #TP 0;
    end else begin
      cfg_hp_slot_ctrl_access <= #TP (write_pulse[0] || write_pulse[1]) && cfg_cap_reg_id[12];
    end
  end

// Slot Control (18h)
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_atten_button_pressed_en_r <= #TP 0;
        cfg_pwr_fault_det_en_r        <= #TP 0;
        cfg_mrl_sensor_chged_en_r     <= #TP 0;
        cfg_pre_det_chged_en          <= #TP 0;
        cfg_cmd_cpled_int_en_r        <= #TP 0;
        cfg_hp_int_en                 <= #TP 0;
        cfg_atten_ind                 <= #TP 2'b11;       // Off
        cfg_pwr_ind                   <= #TP 2'b11;       // Off
        cfg_pwr_ctrler_ctrl           <= #TP 0;
        cfg_eml_control               <= #TP 0;
        cfg_dll_state_chged_en        <= #TP 0;
        r_auto_slot_pwr_lmt_dis       <= #TP 0;
    end else begin
        cfg_atten_button_pressed_en_r <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[0]  : cfg_atten_button_pressed_en_r;
        cfg_pwr_fault_det_en_r      <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[1]  : cfg_pwr_fault_det_en_r;
        cfg_mrl_sensor_chged_en_r   <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[2]  : cfg_mrl_sensor_chged_en_r;
        cfg_pre_det_chged_en        <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[3]  : cfg_pre_det_chged_en;
        cfg_cmd_cpled_int_en_r      <= #TP cfg_pcie_slot_no_cc_support ? 1'b0
                                           : (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[4]: cfg_cmd_cpled_int_en_r;
        cfg_hp_int_en               <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[5]  : cfg_hp_int_en;
        cfg_atten_ind               <= #TP (write_pulse[0] & cfg_cap_reg_id[12]) ? lbc_cdm_data[7:6]: cfg_atten_ind;
        cfg_pwr_ind                 <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[9:8]: cfg_pwr_ind;
        cfg_pwr_ctrler_ctrl         <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[10] : cfg_pwr_ctrler_ctrl;
        // EML control is a pulse, directing EML to toggle
        cfg_eml_control             <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[11] : 1'b0;
        cfg_dll_state_chged_en      <= #TP (write_pulse[1] & cfg_cap_reg_id[12] & cfg_dll_link_rpt_en) ? lbc_cdm_data[12] : cfg_dll_state_chged_en;
        r_auto_slot_pwr_lmt_dis     <= #TP (write_pulse[1] & cfg_cap_reg_id[12]) ? lbc_cdm_data[13] : r_auto_slot_pwr_lmt_dis;
    end
end

assign cfg_auto_slot_pwr_lmt_dis = r_auto_slot_pwr_lmt_dis;

// Slot Status (1Ah)
// RW1C registers:
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        cfg_atten_button_pressed_reg<= #TP 0;
        cfg_pwr_fault_det_reg       <= #TP 0;
        cfg_mrl_sensor_chged_reg    <= #TP 0;
        cfg_pre_det_chged_reg       <= #TP 0;
        cfg_cmd_cpled_int_reg       <= #TP 0;
        cfg_dll_state_chged_reg     <= #TP 0;
    end else begin
        cfg_atten_button_pressed_reg<= #TP ~cfg_pcie_slot_attn_butt_present ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[16]) ? 1'b0
                                          : sys_atten_button_pressed ? 1'b1 : cfg_atten_button_pressed_reg;
        cfg_pwr_fault_det_reg       <= #TP ~cfg_pcie_slot_pwr_ctrl_present ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[17]) ? 1'b0
                                          : sys_pwr_fault_det ? 1'b1 : cfg_pwr_fault_det_reg;
        cfg_mrl_sensor_chged_reg    <= #TP ~cfg_pcie_slot_mrl_sensor_present ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[18]) ? 1'b0
                                          : sys_mrl_sensor_chged ? 1'b1 : cfg_mrl_sensor_chged_reg;
        cfg_pre_det_chged_reg       <= #TP (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[19]) ? 1'b0
                                          : sys_pre_det_chged ? 1'b1 : cfg_pre_det_chged_reg;
        cfg_cmd_cpled_int_reg       <= #TP cfg_pcie_slot_no_cc_support ? 1'b0
                                          : (write_pulse[2] & cfg_cap_reg_id[12] & lbc_cdm_data[20]) ? 1'b0
                                          : sys_cmd_cpled_int ? 1'b1 : cfg_cmd_cpled_int_reg;
        cfg_dll_state_chged_reg     <= #TP (~cfg_dll_state_chged_en | (write_pulse[3] & cfg_cap_reg_id[12] & lbc_cdm_data[24])) ? 1'b0
                                          : dll_active_chnged ? 1'b1 : cfg_dll_state_chged_reg;
    end
end

// -----------------------------------------------------------------------------
// Root Control Register (Only for Root Complex)
// cfg_cap_reg_id   - 13
// PCIE Offset      - `CFG_PCIE_CAP + 1Ch
// length           - 2 byte
// default value    -
// Cfig register    - cfg_reg_117, cfg_reg_116
// -----------------------------------------------------------------------------
reg root_cap_crs_visibility;
reg root_ctrl_crs_visibility_en;
reg pme_int_en;
reg sys_err_f_err_en;
reg sys_err_nf_err_en;
reg sys_err_cor_err_en;
reg cfg_sys_err_rc;
wire int_sys_err_rc_cor ;
wire int_sys_err_rc_nf ;
wire int_sys_err_rc_f ;
reg  cfg_sys_err_rc_cor ;
reg  cfg_sys_err_rc_nf ;
reg  cfg_sys_err_rc_f ;
reg  cfg_no_nfm_subtree_below_rp;

assign cfg_reg_116  = rc_device ? {2'b0, cfg_no_nfm_subtree_below_rp, root_ctrl_crs_visibility_en, pme_int_en, sys_err_f_err_en, sys_err_nf_err_en, sys_err_cor_err_en} : 0;
assign cfg_reg_117  = 8'b0;

assign int_sys_err_rc_cor = sys_err_cor_err_en & cfg_rprt_err_cor ;
assign int_sys_err_rc_nf  = sys_err_nf_err_en  & cfg_rprt_err_nf ;
assign int_sys_err_rc_f   = sys_err_f_err_en   & cfg_rprt_err_f ;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        sys_err_cor_err_en  <= #TP 0;
        sys_err_nf_err_en   <= #TP 0;
        sys_err_f_err_en    <= #TP 0;
        pme_int_en          <= #TP 0;
        root_ctrl_crs_visibility_en   <= #TP 0;
        cfg_no_nfm_subtree_below_rp <= #TP 1'b0;
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        sys_err_cor_err_en  <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[0] : sys_err_cor_err_en;
        sys_err_nf_err_en   <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[1] : sys_err_nf_err_en;
        sys_err_f_err_en    <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[2] : sys_err_f_err_en;
        pme_int_en          <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[3] : pme_int_en;
        root_ctrl_crs_visibility_en   <= #TP root_cap_crs_visibility ? ((write_pulse[0] & cfg_cap_reg_id[13]) ? lbc_cdm_data[4] : root_ctrl_crs_visibility_en) : 0; 
        cfg_no_nfm_subtree_below_rp   <= #TP write_pulse[0] & cfg_cap_reg_id[13] ? lbc_cdm_data[5] : cfg_no_nfm_subtree_below_rp;
    end
end
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        cfg_sys_err_rc      <= #TP 0;
        cfg_sys_err_rc_cor  <= #TP 0;
        cfg_sys_err_rc_nf   <= #TP 0;
        cfg_sys_err_rc_f    <= #TP 0;
     
    end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        
        // System Error signal to the system
        cfg_sys_err_rc      <= #TP int_sys_err_rc_cor | int_sys_err_rc_nf | int_sys_err_rc_f ;
        // System Error signal per kind of errors to the diag_status_bus
        cfg_sys_err_rc_cor  <= #TP int_sys_err_rc_cor ;
        cfg_sys_err_rc_nf   <= #TP int_sys_err_rc_nf ;
        cfg_sys_err_rc_f    <= #TP int_sys_err_rc_f ;
    end
end

assign cfg_crs_sw_vis_en = root_ctrl_crs_visibility_en;

// -----------------------------------------------------------------------------
// Root Capabilities Register (Only for Root Complex)
// cfg_cap_reg_id   - 13
// PCIE Offset      - `CFG_PCIE_CAP + 1Eh
// length           - 2 byte
// default value    - 0
// Cfig register    - cfg_reg_119, cfg_reg_118
// -----------------------------------------------------------------------------

assign cfg_reg_118  = {7'b0, root_cap_crs_visibility};
assign cfg_reg_119  = 8'b0;

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        root_cap_crs_visibility   <= #TP `DEFAULT_CRS_SW_VISIBILITY_CAP; 
     end
    else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        root_cap_crs_visibility   <= #TP rc_device ? (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[13] ? lbc_cdm_data[16] : root_cap_crs_visibility) : 0;  
    end
end

// -----------------------------------------------------------------------------
// Root Status Register (Only for Root Complex)
// cfg_cap_reg_id   - 14
// PCIE Offset      - `CFG_PCIE_CAP + 20h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_123, cfg_reg_122, cfg_reg_121, cfg_reg_120
//
// This register stores the req ID of a received PME.
// If there's another PME before software clears the current one, we have to
// latch it and assert pme_pending.
// -----------------------------------------------------------------------------

wire[MSG_TLP_WD*16-1:0]  pme_req_id;
wire[MSG_TLP_WD-1:0] pme_status;

assign  pme_status = radm_pm_pme;
assign  pme_req_id = radm_msg_req_id;

reg [15:0]  latched_pme_req_id;
reg [15:0]  pending_pme_req_id;
reg         latched_pme_status;
reg         pme_pending;

assign {cfg_reg_121, cfg_reg_120} = rc_device ? latched_pme_req_id : 0;
assign cfg_reg_122 = rc_device ? {6'h0, pme_pending, latched_pme_status} : 0;
assign cfg_reg_123 = 0;

reg latched_pme_pending;
wire clear_pme;
assign clear_pme = (write_pulse[2] & cfg_cap_reg_id[14] & lbc_cdm_data[16]);



//
//always @(posedge core_clk or negedge non_sticky_rst_n)
//begin
//    if (~non_sticky_rst_n) begin
//        latched_pme_req_id  <= #TP 0;
//        latched_pme_status  <= #TP 0;
//        latched_pme_pending <= #TP 0;
//        pme_pending         <= #TP 0;
//        pending_pme_req_id  <= #TP 0;
//    end
//    else begin
//        latched_pme_req_id  <= #TP (pme_status[0] & !latched_pme_status) ? pme_req_id[15:0] :
//            `ifdef ARC_256_P2
//            (pme_status[1] & !latched_pme_status) ? pme_req_id[31:16] :
//            `endif // ARC_256_P2
//            (clear_pme & pme_pending) ? pending_pme_req_id : latched_pme_req_id;
//         latched_pme_status  <= #TP (clear_pme) ? 1'b0 : ((latched_pme_pending || (|pme_status)) ? 1'b1 : latched_pme_status);
//         latched_pme_pending <= #TP (clear_pme) ? pme_pending : latched_pme_pending ;
//         pme_pending         <= #TP (clear_pme) ? 1'b0 : ((latched_pme_status & pme_status[0]) ? 1'b1 :
//            `ifdef ARC_256_P2
//            (latched_pme_status & pme_status[1] || &pme_status) ? 1'b1 :
//            `endif // ARC_256_P2
//            pme_pending);
//        pending_pme_req_id  <= #TP (pme_status[0] & latched_pme_status) ? pme_req_id[15:0] :
//            `ifdef ARC_256_P2
//            (pme_status[1] & latched_pme_status || &pme_status) ? pme_req_id[31:16] :
//           `endif // ARC_256_P2
//            pending_pme_req_id;
//    end
//end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        latched_pme_req_id  <= #TP 0;
        latched_pme_status  <= #TP 0;
        latched_pme_pending <= #TP 0;
        pme_pending         <= #TP 0;
        pending_pme_req_id  <= #TP 0;
    end
    else begin
         latched_pme_req_id  <= #TP (|pme_status & !latched_pme_status) ? obtain_pme_req_id (pme_req_id, pme_status, latched_pme_status) :
            (clear_pme & pme_pending) ? pending_pme_req_id : latched_pme_req_id;

         latched_pme_status  <= #TP (clear_pme) ? 1'b0 : ((latched_pme_pending || (|pme_status)) ? 1'b1 : latched_pme_status);
         latched_pme_pending <= #TP (clear_pme) ? pme_pending : latched_pme_pending ;

         pme_pending         <= #TP (clear_pme) ? 1'b0 : obtain_pme_pending (latched_pme_status, pme_status, pme_pending ) ;   
        
         pending_pme_req_id  <= #TP obtain_pending_pme_req_id (pme_req_id, pme_status, latched_pme_status, pending_pme_req_id);

    end
end


function automatic[15:0]obtain_pme_req_id;
    input [(MSG_TLP_WD*16)-1:0] pme_req_id;
    input [MSG_TLP_WD-1:0] pme_status;
    input latched_pme_status;

    integer k; 
    begin
      obtain_pme_req_id = 16'd0; 

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if( pme_status[k] & !latched_pme_status)
            obtain_pme_req_id = pme_req_id[16*k +: 16]; 
       end
    end
endfunction


function automatic obtain_pme_pending;
    input latched_pme_status;
    input [MSG_TLP_WD-1:0] pme_status;
    input pme_pending;

    integer k; 
    begin
      obtain_pme_pending = pme_pending; 

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if(k== 0 & pme_status[k] & latched_pme_status)
            obtain_pme_pending = 1;
          if(k> 0 &( pme_status[k] & latched_pme_status || &pme_status) )
             obtain_pme_pending = 1;
       end
    end
endfunction



function automatic[15:0]obtain_pending_pme_req_id;
    input [(MSG_TLP_WD*16)-1:0] pme_req_id;
    input [MSG_TLP_WD-1:0] pme_status;
    input latched_pme_status;
    input [15:0]pending_pme_req_id;

    integer k; 
    begin
      obtain_pending_pme_req_id = pending_pme_req_id; 

       for(k = MSG_TLP_WD-1; k >= 0; k = k - 1) begin
          if(k== 0 & pme_status[k] & latched_pme_status)
            obtain_pending_pme_req_id = pme_req_id[16*k +: 16];
          if(k> 0 &( pme_status[k] & latched_pme_status || &pme_status) )
             obtain_pending_pme_req_id = pme_req_id[16*k +: 16];
       end
    end
endfunction
//------------------------------------------------------------------------------------------------------------------



// PME Interrupt & MSI generation
reg cfg_pme_int;
reg cfg_pme_msi;
reg pme_msi_src_d;
wire pme_msi_src;

assign pme_msi_src = pme_int_en & latched_pme_status & (cfg_msi_en | cfg_msix_en);

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        cfg_pme_int         <= #TP 0;
        cfg_pme_msi         <= #TP 0;
        pme_msi_src_d       <= #TP 0;
    end
    else begin
        // PME Interrupt - level signal
        cfg_pme_int     <= #TP pme_int_en & !cfg_int_disable & latched_pme_status & ~(cfg_msi_en | cfg_msix_en);

        // PME MSI/MSI-X - pulse signal
        cfg_pme_msi     <= #TP pme_msi_src & ~pme_msi_src_d;
        pme_msi_src_d   <= #TP pme_msi_src;
    end
end

// -----------------------------------------------------------------------------
// Device Capabilities 2 Register
// cfg_cap_reg_id   - 22
// PCIE Offset      - `CFG_PCIE_CAP + 24h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_143, cfg_reg_142, cfg_reg_141, cfg_reg_140
// -----------------------------------------------------------------------------
wire    [3:0]   cfg_cpl_timeout_supt_range;
wire            cfg_cpl_timeout_supt_disable;
wire            cfg_ari_fwd_supt;
wire    [1:0]   cfg_tph_cpl_sup;
wire            cfg_ro_en_no_pr_pr_passing;
wire            cfg_atomic_routing_sup;
reg             cfg_atomic_32_cpl_sup;
reg             cfg_atomic_64_cpl_sup;
reg             cfg_atomic_128_cas_sup;
wire            cfg_10bits_tag_req_support;
wire            cfg_10bits_tag_comp_support;
wire            cfg_dmwr_cpl_sup;
wire    [1:0]   cfg_dmwr_len_sup;

assign cfg_10bits_tag_comp_support = (|RCRB) ? 1'b0 : ( `CX_10BITS_TAG_VALUE == 1)? 1'b1: 1'b0;
assign cfg_10bits_tag_req_support  = (|RCRB) ? 1'b0 : ( `CX_10BITS_TAG_VALUE == 1 &&  `CX_10BITS_TAG_REQ_VALUE == 1)? 1'b1: 1'b0;

assign cfg_cpl_timeout_supt_range   = (|RCRB) ? 4'h0 : 4'b1111;  // A, B, C & D ranges supported
assign cfg_ari_fwd_supt           = (|RCRB) ? 1'b0 : (pcie_sw_down | rc_device) ?
                                    `CX_ARI_FWD_ENABLE : 1'b0;
assign cfg_ro_en_no_pr_pr_passing = (|RCRB) ? 1'b0 : (rc_device || switch_device) ? 1'b1 : 1'b0;

assign cfg_atomic_routing_sup     = (|RCRB) ? 1'b0 : (rc_device || switch_device) ?  `CX_ATOMIC_ROUTING_EN : 1'b0;

always @(posedge cdm_clk_g or negedge sticky_rst_n)begin
  if (!sticky_rst_n)begin
    cfg_atomic_32_cpl_sup      <= #TP `CX_ATOMIC_32_CPL_EN;
    cfg_atomic_64_cpl_sup      <= #TP `CX_ATOMIC_64_CPL_EN;
    cfg_atomic_128_cas_sup     <= #TP `CX_ATOMIC_128_CAS_EN;
  end
   else if (|RCRB) begin
    cfg_atomic_32_cpl_sup      <= #TP 1'b0;
    cfg_atomic_64_cpl_sup      <= #TP 1'b0;
    cfg_atomic_128_cas_sup     <= #TP 1'b0;
   end           
    else begin
      cfg_atomic_32_cpl_sup    <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[22]) ? lbc_cdm_data[7] : cfg_atomic_32_cpl_sup;
      cfg_atomic_64_cpl_sup    <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[22]) ? lbc_cdm_data[8] : cfg_atomic_64_cpl_sup;
      cfg_atomic_128_cas_sup   <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[22]) ? lbc_cdm_data[9] : cfg_atomic_128_cas_sup;
    end
end

assign cfg_cpl_timeout_supt_disable = (|RCRB) ? 1'b0 : (end_device | rc_device) ? 1'b1 : 1'b0;



// OBFF Supported is writable via DBI iff CX_OBFF_SUPPORT is set
reg     [1:0]   cfg_obff_support;       // OBFF Supported
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        begin
            cfg_obff_support    <= #TP `CX_OBFF_SUPPORT;
        end
   else if (|RCRB) begin
            cfg_obff_support    <= #TP 0;
   end           
    else
        begin
            cfg_obff_support    <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[22]) ? lbc_cdm_data[19:18] : cfg_obff_support;
        end
end


// LTR Mechanism Supported is writable via DBI iff CX_LTR_M_ENABLE is set
reg        cfg_ltr_m_suprtd;       // LTR Mechanism Supported
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        begin
            cfg_ltr_m_suprtd    <= #TP `CX_LTR_M_ENABLE_VALUE;
        end
   else if (|RCRB) begin
            cfg_ltr_m_suprtd    <= #TP 0;
   end           
    else
        begin
            cfg_ltr_m_suprtd    <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[22]) ? lbc_cdm_data[11] : cfg_ltr_m_suprtd;
        end
end

// TPH Completer Supported [12] is writable via DBI iff CX_TPH_ENABLE is set
reg        cfg_tph_cpl_sup_0;       // TPH Completer Supported [12]
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        begin
            cfg_tph_cpl_sup_0    <= #TP `CX_TPH_ENABLE_VALUE;
        end
   else if (|RCRB) begin
            cfg_tph_cpl_sup_0    <= #TP 0;
   end           
    else
        begin
            cfg_tph_cpl_sup_0    <= #TP  ~(end_device || rc_device) ? 1'b0 : (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[22]) ? lbc_cdm_data[12] : cfg_tph_cpl_sup_0;
        end
end

// TPH Completer Supported [13] is writable via DBI iff CX_EXT_TPH_ENABLE is set
wire      cfg_tph_cpl_sup_1;       // TPH Completer Supported [13]
assign    cfg_tph_cpl_sup_1    = 1'b0;

// Max End-End TLP Prefixes and End-End TLP Prefixes Supported are writeable via DBI iff TLP Prefixes are
// enabled
reg     [1:0]   cfg_max_end2end_tlp_prfxs;       // the maximum number of End-End TLP Prefixes supported; DBI writeable.
reg             cfg_extnd_fmt_support;           // TLP Prefix - FMT(2) support
reg             cfg_end2end_tlp_prfx_support;    // TLP Prefix of type End-End support; DBI writeable.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (!sticky_rst_n)
        begin
            cfg_max_end2end_tlp_prfxs    <= #TP `CX_MAX_END2END_TLP_PRFXS;
            cfg_end2end_tlp_prfx_support <= #TP `CX_TLP_PREFIX_ENABLE_VALUE;
            cfg_extnd_fmt_support        <= #TP `CX_TLP_PREFIX_ENABLE_VALUE;         // defined in DWC_pcie_common_cc_constants.v
        end
    else if (|RCRB) begin
            cfg_max_end2end_tlp_prfxs    <= #TP 0;
            cfg_end2end_tlp_prfx_support <= #TP 0;
            cfg_extnd_fmt_support        <= #TP 0; 
    end
    else
        begin
            cfg_max_end2end_tlp_prfxs    <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[22]) ? lbc_cdm_data[23:22] : cfg_max_end2end_tlp_prfxs;
            cfg_end2end_tlp_prfx_support <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[22]) ? lbc_cdm_data[21] : cfg_end2end_tlp_prfx_support;
            cfg_extnd_fmt_support        <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[22]) ? lbc_cdm_data[20] : cfg_extnd_fmt_support;
        end
end


  wire [1:0]  cfg_ln_system_cls;
  assign      cfg_ln_system_cls = 2'b00;

assign cfg_tph_cpl_sup            = (|RCRB) ? 2'b00 : (end_device || rc_device) ?
                                    {cfg_tph_cpl_sup_1,cfg_tph_cpl_sup_0} : 2'b00;

assign cfg_reg_140 = {cfg_atomic_32_cpl_sup,cfg_atomic_routing_sup, cfg_ari_fwd_supt,
                      cfg_cpl_timeout_supt_disable, cfg_cpl_timeout_supt_range};
assign cfg_reg_141 = {cfg_ln_system_cls, cfg_tph_cpl_sup_1, cfg_tph_cpl_sup_0,cfg_ltr_m_suprtd,cfg_ro_en_no_pr_pr_passing,
                      cfg_atomic_128_cas_sup,cfg_atomic_64_cpl_sup};
assign cfg_reg_142 = {cfg_max_end2end_tlp_prfxs, cfg_end2end_tlp_prfx_support, cfg_extnd_fmt_support, cfg_obff_support, cfg_10bits_tag_req_support, cfg_10bits_tag_comp_support};


//reg  cfg_frs_support;//FRS supported


always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
      cfg_frs_support <= #TP `CX_RN_FRS_VALUE;
    end else if (|RCRB) begin
      cfg_frs_support <= #TP 0;      
    end else begin
      cfg_frs_support <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[22] & dbi_ro_wr_en) ? lbc_cdm_data[31] : cfg_frs_support;
    end
end

assign cfg_dmwr_cpl_sup     = (|RCRB) ? 0 :  `CX_DEF_MEM_WR_CPL_EN;
assign cfg_dmwr_len_sup     = (|RCRB) ? 0 :  ( `CX_DEF_MEM_WR_ROUTING_EN ||  `CX_DEF_MEM_WR_CPL_EN)? `CX_DEF_MEM_WR_LEN_SUPP : 2'b00;


assign cfg_reg_143 = {                        cfg_frs_support,
                        cfg_dmwr_len_sup,
                        cfg_dmwr_cpl_sup,
                        1'b0,
                        3'b0
                     };

// -----------------------------------------------------------------------------
// Device Control 2 Register
// cfg_cap_reg_id   - 23
// PCIE Offset      - `CFG_PCIE_CAP + 28h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_147, cfg_reg_146, cfg_reg_145, cfg_reg_144
// -----------------------------------------------------------------------------

reg             cfg_end2end_tlp_pfx_blck;    // TLP Prefix of type End-End blocking control bit.

reg             cfg_10b_tag_req_en;          // 10 bits Tag Requester Enable


assign cfg_reg_144 = {cfg_atomic_egress_block,cfg_atomic_req_en, cfg_ari_fwd_en,
                      cfg_cpl_timeout_disable,
                      cfg_cpl_timeout_range};
assign cfg_reg_145 = {                      cfg_end2end_tlp_pfx_blck,
                      cfg_obff_en,
                      cfg_10b_tag_req_en,
                      1'b0,
                      ltr_m_en_r,
                      cfg_ido_cpl_en,
                      cfg_ido_req_en
                      };

assign cfg_reg_146 = 0;
assign cfg_reg_147 = 0;


always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        cfg_cpl_timeout_range   <= #TP 4'b0000; // Default range: 50us to 50ms
        cfg_cpl_timeout_disable <= #TP 0;
        cfg_ari_fwd_en          <= #TP 0;
        cfg_ido_req_en          <= #TP 0;
        cfg_ido_cpl_en          <= #TP 0;
        cfg_atomic_req_en       <= #TP 0;
        cfg_atomic_egress_block <= #TP 0;
        cfg_obff_en             <= #TP 0;
        cfg_end2end_tlp_pfx_blck <= #TP 0;
        cfg_10b_tag_req_en       <= #TP 0;
    end
    else if (|RCRB) begin
        cfg_cpl_timeout_range   <= #TP 4'b0000; // Default range: 50us to 50ms
        cfg_cpl_timeout_disable <= #TP 0;
        cfg_ari_fwd_en          <= #TP 0;
        cfg_ido_req_en          <= #TP 0;
        cfg_ido_cpl_en          <= #TP 0;
        cfg_atomic_req_en       <= #TP 0;
        cfg_atomic_egress_block <= #TP 0;
        cfg_obff_en             <= #TP 0;
        cfg_end2end_tlp_pfx_blck <= #TP 0;
        cfg_10b_tag_req_en       <= #TP 0;
    end
    else begin
        cfg_cpl_timeout_range   <= #TP write_pulse[0] & cfg_cap_reg_id[23] & (end_device | rc_device) ? lbc_cdm_data[3:0] : cfg_cpl_timeout_range;
        cfg_cpl_timeout_disable <= #TP write_pulse[0] & cfg_cap_reg_id[23] & cfg_cpl_timeout_supt_disable ? lbc_cdm_data[4] : cfg_cpl_timeout_disable;

        cfg_ari_fwd_en          <= #TP write_pulse[0] & cfg_cap_reg_id[23] & cfg_ari_fwd_supt ? lbc_cdm_data[5] : cfg_ari_fwd_en;
        cfg_atomic_req_en       <= #TP write_pulse[0] & cfg_cap_reg_id[23] & (end_device | rc_device) ? lbc_cdm_data[6] : cfg_atomic_req_en;
        cfg_atomic_egress_block <= #TP write_pulse[0] & cfg_cap_reg_id[23] & cfg_atomic_routing_sup   ? lbc_cdm_data[7] : cfg_atomic_egress_block;
        cfg_ido_req_en          <= #TP write_pulse[1] & cfg_cap_reg_id[23] ? lbc_cdm_data[8] : cfg_ido_req_en;
        cfg_ido_cpl_en          <= #TP write_pulse[1] & cfg_cap_reg_id[23] ? lbc_cdm_data[9] : cfg_ido_cpl_en;
        if (FUNC_NUM == 0)
          cfg_obff_en           <= #TP write_pulse[1] & cfg_cap_reg_id[23] & (|cfg_obff_support) ? lbc_cdm_data[14:13] : cfg_obff_en;
        else
          cfg_obff_en           <= #TP 2'b00;
        if (rc_device || switch_device)        // writeble only for RCs and Switches
          cfg_end2end_tlp_pfx_blck <= #TP write_pulse[1] & cfg_cap_reg_id[23] & cfg_end2end_tlp_prfx_support ? lbc_cdm_data[15] : cfg_end2end_tlp_pfx_blck;
        else
          cfg_end2end_tlp_pfx_blck <= #TP 0;
        cfg_10b_tag_req_en  <= #TP  write_pulse[1] & cfg_cap_reg_id[23] ? lbc_cdm_data[12] : cfg_10b_tag_req_en;
    end
end

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
       
        
        ltr_m_en_r              <= #TP 0;
   
    end
    else if (|RCRB) begin

     
        ltr_m_en_r              <= #TP 0;
  
    end
    else begin
        // Clear enable if downstream port reports DL_Down
        if ((rc_device || pcie_sw_down) && !rdlh_link_up)
          ltr_m_en_r            <= #TP 1'b0;
        // Bit LTR_M_EN is RW for function 0, RsvdP for all other functions
        else if (FUNC_NUM==0)
          ltr_m_en_r            <= #TP write_pulse[1] & cfg_cap_reg_id[23] & cfg_ltr_m_suprtd ? lbc_cdm_data[10] : ltr_m_en_r;
        else
          // Set to 0 for all other functions
          ltr_m_en_r            <= #TP 1'b0;
    end
end



// -----------------------------------------------------------------------------
// Adding bcm for falsepath
// -----------------------------------------------------------------------------
DWC_pcie_ctl_bcm36_nhs
 #(
.WIDTH      ($bits({cfg_cpl_timeout_disable ,cfg_cpl_timeout_range })),
.DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_cfg_cpl_timeout_disable_range (
`ifndef SYNTHESIS
.clk_d   (core_clk),
.rst_d_n (non_sticky_rst_n),
`endif // SYNTHESIS
.data_s  ({cfg_cpl_timeout_disable ,cfg_cpl_timeout_range }),
.data_d  ({cfg_cpl_timeout_disable_out ,cfg_cpl_timeout_range_out })
);


// -----------------------------------------------------------------------------
// Link Capabilities 2 Register
// cfg_cap_reg_id   - 29
// PCIE Offset      - `CFG_PCIE_CAP + 2Ch
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_151, cfg_reg_150, cfg_reg_149, cfg_reg_148
// -----------------------------------------------------------------------------
wire    [5:0]   cfg_pcie_supp_link_speed_vector;        // Supported Link Speeds Vector
wire    [5:0]   cfg_pcie_supp_link_speed_vector_int;    // Supported Link Speeds Vector for Conventional PCIe
wire            cfg_pcie_crosslink_supported;
reg             cfg_pcie_retimer_pre_det_supported;
reg             cfg_pcie_two_retimers_pre_det_supported;

assign cfg_pcie_supp_link_speed_vector_int   = (cfg_pcie_max_link_speed == `GEN6_LINK_SP)  ? 6'h3F :
 (cfg_pcie_max_link_speed == `GEN5_LINK_SP)  ? 6'h1F :
 (cfg_pcie_max_link_speed == `GEN4_LINK_SP)  ? 6'hF  :
 (cfg_pcie_max_link_speed == `GEN3_LINK_SP)  ? 6'h7  :
 (cfg_pcie_max_link_speed == `GEN2_LINK_SP)  ? 6'h3  :
                                                                                                                  6'h1  ;
assign cfg_pcie_supp_link_speed_vector       = (cxl_rcrb_enable & ~(|RCRB)) ? 6'h0 : cfg_pcie_supp_link_speed_vector_int ;

assign cfg_pcie_crosslink_supported = 1'b0;

assign cfg_reg_148 = {1'b0, cfg_pcie_supp_link_speed_vector, 1'b0};
assign cfg_reg_149 = {7'h0, cfg_pcie_crosslink_supported};
assign cfg_reg_150 = (cxl_rcrb_enable & ~(|RCRB)) ? 8'd0 : {cfg_pcie_retimer_pre_det_supported, 7'h0};


always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_pcie_retimer_pre_det_supported      <= #TP 1'b1;
    cfg_pcie_two_retimers_pre_det_supported <= #TP 1'b1;
  end else begin
    cfg_pcie_retimer_pre_det_supported      <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[29] & dbi_ro_wr_en ) ? lbc_cdm_data[23] : cfg_pcie_retimer_pre_det_supported;
    // Two Retimer Presence Detect Supported
    // Downstream Port and 16GT/s support -> must be set to 1b.
    // Downstream Port (not support 16GT/s) or Upstream Port -> petmitted to set 1b if the Retimer Presence Detect Supported is 1b.
    if(!cfg_pcie_retimer_pre_det_supported && (upstream_port || !cfg_pcie_supp_link_speed_vector_int[3]))
        cfg_pcie_two_retimers_pre_det_supported <= #TP 1'b0;
    else
        cfg_pcie_two_retimers_pre_det_supported <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[29] & dbi_ro_wr_en ) ? lbc_cdm_data[24] : cfg_pcie_two_retimers_pre_det_supported;
  end
end


always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
  if(!sticky_rst_n) begin 
    cfg_drs_support <= #TP (FUNC_NUM==0) ? 1'b1 : 1'b0;
  end else begin                                       
      cfg_drs_support <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[29] & (FUNC_NUM==0) &dbi_ro_wr_en) ? lbc_cdm_data[31] : cfg_drs_support;
  end 
end 

assign cfg_reg_151[7:1] = (cxl_rcrb_enable & ~(|RCRB)) ? 7'd0 : {cfg_drs_support, //DRS supported
                      6'b0};
assign cfg_reg_151[0] = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_pcie_two_retimers_pre_det_supported;





// PCIe Gen 2 registers
// -----------------------------------------------------------------------------
// Link Control 2 & Link Status 2 Register (Only for Gen 2)
// cfg_cap_reg_id   - 19
// PCIE Offset      - `CFG_PCIE_CAP + 30h
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_155, cfg_reg_154, cfg_reg_153, cfg_reg_152
// -----------------------------------------------------------------------------

// Link Control 2 (30h)
assign cfg_reg_152 = (cxl_rcrb_enable & ~(|RCRB)) ? 8'd0 : {cfg_transmit_margin[0], cfg_sel_de_emphasis, cfg_hw_auto_sp_dis, cfg_enter_compliance, int_target_link_speed[3:0]};
assign cfg_reg_153 = (cxl_rcrb_enable & ~(|RCRB)) ? 8'd0 : {cfg_compliance_de_emphasis, cfg_compliance_sos, cfg_enter_mod_compliance, cfg_transmit_margin[2:1]};

//wire it to output
always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin
  if ( ~sticky_rst_n )
    cfg_hw_auto_sp_dis <= #TP 1'b0;
  else begin
    if ( FUNC_NUM == 0 )
      cfg_hw_auto_sp_dis <= #TP ( write_pulse[0] & cfg_cap_reg_id[19] ) ? lbc_cdm_data[5] : cfg_hw_auto_sp_dis;
    else
      cfg_hw_auto_sp_dis <= #TP 1'b0; //RsvdP if the other functions
  end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        int_target_link_speed       <= #TP `MAX_LINK_SP;
        cfg_compliance_sos          <= #TP 0;
        cfg_compliance_de_emphasis  <= #TP 0;
    end
    else begin
        if (FUNC_NUM == 0) begin
            int_target_link_speed       <= #TP (write_pulse[0] & cfg_cap_reg_id[19]) ? lbc_cdm_data[3:0]
                                              : int_target_link_speed;
            cfg_compliance_sos          <= #TP (write_pulse[1] & cfg_cap_reg_id[19])                     ? lbc_cdm_data[11] : cfg_compliance_sos;
            cfg_compliance_de_emphasis  <= #TP (write_pulse[1] & cfg_cap_reg_id[19]) ? lbc_cdm_data[15:12] : cfg_compliance_de_emphasis;
        end
        else begin
            int_target_link_speed       <= #TP 0;
            cfg_compliance_sos          <= #TP 0;
            cfg_compliance_de_emphasis  <= #TP 0;
        end
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        cfg_sel_de_emphasis         <= #TP `SEL_DE_EMPHASIS;
    end
    else begin
        if (FUNC_NUM == 0) begin

            cfg_sel_de_emphasis         <= #TP upstream_port                                             ? 1'b0             :
                                               (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[19])   ? lbc_cdm_data[6]  : cfg_sel_de_emphasis;
            
        end
        else begin
            cfg_sel_de_emphasis         <= #TP 0;
        end
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        cfg_enter_compliance        <= #TP 0;
    end
    else begin
        if (FUNC_NUM == 0) begin
            cfg_enter_compliance        <= #TP  smlh_clr_enter_compliance                                ? 1'b0             :
                                               (write_pulse[0] & cfg_cap_reg_id[19])                     ? lbc_cdm_data[4]  : cfg_enter_compliance;
        end
        else begin
            cfg_enter_compliance        <= #TP 0;

        end
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        cfg_transmit_margin         <= #TP 0;
        cfg_enter_mod_compliance    <= #TP 0;
    end
    else begin
        if (FUNC_NUM == 0) begin
            
            cfg_transmit_margin[0]      <= #TP smlh_tx_margin_rst                                        ? 1'b0             :
                                               (write_pulse[0] & cfg_cap_reg_id[19])                     ? lbc_cdm_data[7]  : cfg_transmit_margin[0];
            cfg_transmit_margin[2:1]    <= #TP smlh_tx_margin_rst                                        ? 2'b00            :
                                               (write_pulse[1] & cfg_cap_reg_id[19])                     ? lbc_cdm_data[9:8]: cfg_transmit_margin[2:1];
            cfg_enter_mod_compliance    <= #TP (write_pulse[1] & cfg_cap_reg_id[19])                     ? lbc_cdm_data[10] : cfg_enter_mod_compliance;
            
        end
        else begin
            
            cfg_transmit_margin         <= #TP 0;
            cfg_enter_mod_compliance    <= #TP 0;
    
        end
    end
end

// protect the value passed to the ltssm from illegal programming of the register
wire    [3:0]   cfg_target_link_speed;          // Target link speed
wire    [3:0]   cfg_target_link_speed_int;      // Target link speed for Conventional PCIe



assign cfg_target_link_speed_int = (  (int_target_link_speed==`GEN1_LINK_SP) |
                                     ((int_target_link_speed==`GEN2_LINK_SP) & (cfg_pcie_max_link_speed == `GEN2_LINK_SP || cfg_pcie_max_link_speed == `GEN3_LINK_SP || cfg_pcie_max_link_speed == `GEN4_LINK_SP || cfg_pcie_max_link_speed == `GEN5_LINK_SP || cfg_pcie_max_link_speed == `GEN6_LINK_SP)) |
                                     ((int_target_link_speed==`GEN3_LINK_SP) & (cfg_pcie_max_link_speed == `GEN3_LINK_SP || cfg_pcie_max_link_speed == `GEN4_LINK_SP || cfg_pcie_max_link_speed == `GEN5_LINK_SP || cfg_pcie_max_link_speed == `GEN6_LINK_SP)) |
                                     ((int_target_link_speed==`GEN4_LINK_SP) & (cfg_pcie_max_link_speed == `GEN4_LINK_SP || cfg_pcie_max_link_speed == `GEN5_LINK_SP || cfg_pcie_max_link_speed == `GEN6_LINK_SP)) |
                                     ((int_target_link_speed==`GEN5_LINK_SP) & (cfg_pcie_max_link_speed == `GEN5_LINK_SP || cfg_pcie_max_link_speed == `GEN6_LINK_SP)) |
                                     ((int_target_link_speed==`GEN6_LINK_SP) & (cfg_pcie_max_link_speed == `GEN6_LINK_SP))  ) ? int_target_link_speed : `GEN1_LINK_SP;

assign cfg_target_link_speed = (cxl_rcrb_enable & ~(|RCRB)) ? 4'h0 : cfg_target_link_speed_int ;

// Link Status 2 (32h)
reg             cfg_mac_phy_txdeemph;
wire      cfg_mac_phy_txdeemph_mux;
assign    cfg_mac_phy_txdeemph_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_mac_phy_txdeemph; 
reg       cfg_ls2_eq_req;
wire      cfg_ls2_eq_req_mux;
assign    cfg_ls2_eq_req_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_ls2_eq_req;
reg [3:1] cfg_ls2_eq_success;
reg       cfg_ls2_eq_cmpl;

wire [3:1]  cfg_ls2_eq_success_mux;
wire        cfg_ls2_eq_cmpl_mux;
assign      cfg_ls2_eq_success_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 3'd0 : cfg_ls2_eq_success;
assign      cfg_ls2_eq_cmpl_mux = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_ls2_eq_cmpl;

// RW1C registers.  Write 1 to clear.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_ls2_eq_req        <= #TP 0;
        cfg_ls2_eq_success    <= #TP 0;
        cfg_ls2_eq_cmpl       <= #TP 0;
    end else if (upstream_port) begin
        if (FUNC_NUM == 0) begin
            cfg_ls2_eq_cmpl       <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_cmpl       ? 1'b1 : cfg_ls2_eq_cmpl;
            cfg_ls2_eq_success[1] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_success[1] ? 1'b1 : cfg_ls2_eq_success[1];
            cfg_ls2_eq_success[2] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_success[2] ? 1'b1 : cfg_ls2_eq_success[2];
            cfg_ls2_eq_success[3] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_success[3] ? 1'b1 : cfg_ls2_eq_success[3];
            cfg_ls2_eq_req        <= #TP (smlh_ls2_eq_enter | (write_pulse[2] & cfg_cap_reg_id[19] & lbc_cdm_data[16 + 5])) ? 1'b0 : smlh_ls2_eq_req ? 1'b1 : cfg_ls2_eq_req;
        end else begin
            cfg_ls2_eq_cmpl       <= #TP 0;
            cfg_ls2_eq_success[1] <= #TP 0;
            cfg_ls2_eq_success[2] <= #TP 0;
            cfg_ls2_eq_success[3] <= #TP 0;
            cfg_ls2_eq_req        <= #TP 0;
        end
    end else begin
        cfg_ls2_eq_cmpl       <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_cmpl       ? 1'b1 : cfg_ls2_eq_cmpl;
        cfg_ls2_eq_success[1] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_success[1] ? 1'b1 : cfg_ls2_eq_success[1];
        cfg_ls2_eq_success[2] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_success[2] ? 1'b1 : cfg_ls2_eq_success[2];
        cfg_ls2_eq_success[3] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_eq_enter) ? 1'b0 : smlh_ls2_eq_success[3] ? 1'b1 : cfg_ls2_eq_success[3];
        cfg_ls2_eq_req        <= #TP (smlh_ls2_eq_enter | (write_pulse[2] & cfg_cap_reg_id[19] & lbc_cdm_data[16 + 5])) ? 1'b0 : smlh_ls2_eq_req ? 1'b1 : cfg_ls2_eq_req;
    end
end
wire   cfg_retimer_pre_detected ;
assign cfg_retimer_pre_detected = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_pcie_retimer_pre_det_supported & smlh_retimer_pre_detected;
   // Move to Physical Layer 16 GT/s Extended Capability
wire   cfg_two_retimers_pre_detected ;
assign cfg_two_retimers_pre_detected = (cxl_rcrb_enable & ~(|RCRB)) ? 1'b0 : cfg_pcie_two_retimers_pre_det_supported & smlh_two_retimers_pre_detected;
  // 00b:Crosslink Resolution is not supported              , 01b:Crosslink negotiation resolved as Upstream port
  // 10b:Crosslink negotiation resolved as Downstream port  , 11b:Crosslink negotiation is not completed
assign cfg_reg_154[7:0] = {
                            cfg_two_retimers_pre_detected, // [7]   Two Retimers Presence Detected
                            cfg_retimer_pre_detected      // [6]   Retimer Presence Detected
                            ,cfg_ls2_eq_req_mux
                            ,cfg_ls2_eq_success_mux[3]     // [4]   Equalization Phase 3 Successful
                            ,cfg_ls2_eq_success_mux[2]     // [3]   Equalization Phase 2 Successful
                            ,cfg_ls2_eq_success_mux[1]     // [2]   Equalization Phase 1 Successful
                            ,cfg_ls2_eq_cmpl_mux           // [1]   Equalization Complete 
                            ,cfg_mac_phy_txdeemph_mux      // [0]   Current De-Emphasis Level 
                            };         

assign cfg_retimers_pre_detected = {
                                   cfg_two_retimers_pre_detected,
                                   cfg_retimer_pre_detected};


always @(posedge core_clk or negedge sticky_rst_n)
begin
    if (~sticky_rst_n) begin
        cfg_mac_phy_txdeemph    <= #TP 1;
    end
    else begin
        cfg_mac_phy_txdeemph    <= #TP mac_phy_txdeemph;
    end
end




  localparam DCP_LD_PRES_NOT_DET  = 3'b000;         //downstream component presence, link down - presence not determined
  localparam DCP_LD_COMP_NOT_PRES = 3'b001;         //downstream component presence, link down - component not present
  localparam DCP_LD_COMP_PRES     = 3'b010;         //downstream component presence, link down - component present
  localparam DCP_LD_FLIT_MODE_NEG = 3'b011;         //downstream component presence, link down - Flit Mode Negotiation Completed
  localparam DCP_LU_COMP_PRES     = 3'b100;         //downstream component presence, link up - component present
  localparam DCP_LU_COMP_PRES_DRS = 3'b101;         //downstream component presence, link up - component present and DRS message received


wire detectquiet;
wire detectactive;

generate 
if(FUNC_NUM==0) begin : gen_dcp_state
reg [2:0] dcp_next_state;
assign detectquiet = smlh_ltssm_state == S_DETECT_QUIET;
assign detectactive = smlh_ltssm_state == S_DETECT_ACT;

always @(posedge core_clk or negedge non_sticky_rst_n)        //downstream component presence
begin
  if(!non_sticky_rst_n) begin
    cfg_downstream_comp_pres  <= #TP DCP_LD_PRES_NOT_DET;
 
  end else if (upstream_port || !cfg_drs_support || FUNC_NUM!=0) begin
    cfg_downstream_comp_pres  <= #TP DCP_LD_PRES_NOT_DET;

  end else begin  
    cfg_downstream_comp_pres[2:0]  <= #TP dcp_next_state;
  
  end
end

  always@(*)
  begin 
      case (cfg_downstream_comp_pres[2:0])    
        DCP_LD_PRES_NOT_DET:              
          if(detectactive)
            dcp_next_state  = DCP_LD_COMP_NOT_PRES; 
          else 
            dcp_next_state  = DCP_LD_PRES_NOT_DET;
     
        DCP_LD_COMP_NOT_PRES:                         //cannot move back into this state
          if(detectquiet)
            dcp_next_state  = DCP_LD_PRES_NOT_DET;
          else if(!detectactive)
            dcp_next_state  = DCP_LD_COMP_PRES; 
          else 
            dcp_next_state  = DCP_LD_COMP_NOT_PRES;   //stay in this state
    
        DCP_LD_COMP_PRES:
          if(flit_mode_enable)
            dcp_next_state  = DCP_LD_FLIT_MODE_NEG;
          else
          if(rdlh_link_up)
            dcp_next_state  = DCP_LU_COMP_PRES;
          else if(detectquiet)
            dcp_next_state  = DCP_LD_PRES_NOT_DET;
          else 
            dcp_next_state  = DCP_LD_COMP_PRES;      //stay in this state

        DCP_LD_FLIT_MODE_NEG:
          if(!flit_mode_enable)
            dcp_next_state  = DCP_LD_COMP_PRES;
          else if(rdlh_link_up)
            dcp_next_state  = DCP_LU_COMP_PRES;
          else if(detectquiet)
            dcp_next_state  = DCP_LD_PRES_NOT_DET;
          else
            dcp_next_state  = DCP_LD_FLIT_MODE_NEG;      //stay in this state
    
        DCP_LU_COMP_PRES:
          if(!rdlh_link_up) 
            dcp_next_state  = DCP_LD_COMP_PRES;
          else if(radm_drs_msg[MSG_TLP_WD-1:0]>0)                       //DRS message received
            dcp_next_state  = DCP_LU_COMP_PRES_DRS;
          else if(detectquiet)
            dcp_next_state  = DCP_LD_PRES_NOT_DET;
          else 
            dcp_next_state  = DCP_LU_COMP_PRES;      //stay in this state
    
        DCP_LU_COMP_PRES_DRS:
          if(!rdlh_link_up)
            dcp_next_state  = DCP_LD_COMP_PRES;
          else if(detectquiet)
            dcp_next_state  = DCP_LD_PRES_NOT_DET;
          else
            dcp_next_state  = DCP_LU_COMP_PRES_DRS;      //stay in this state
    
        default:    
          dcp_next_state  = DCP_LD_COMP_NOT_PRES;

  endcase
end

end else begin : gen_dcp_state
    assign cfg_downstream_comp_pres[2:0] = 3'b000;

end // gen_dcp_state

endgenerate



// non sticky
always @(posedge core_clk or negedge non_sticky_rst_n)    //DRS message received register
begin
    if(!non_sticky_rst_n) begin
        cfg_drs_msg_rec_reg <= #TP 1'b0;

    end else if (!upstream_port && !rdlh_link_up) begin
        cfg_drs_msg_rec_reg <= #TP 1'b0;
       
    end else if (!upstream_port && cfg_drs_support && FUNC_NUM==0) begin
        cfg_drs_msg_rec_reg <= #TP (!cfg_drs_msg_rec_reg && (radm_drs_msg[MSG_TLP_WD-1:0]>0)) ? 1'b1 : 
                                   ((cfg_drs_msg_rec_reg && !rdlh_link_up) || (write_pulse[3] & cfg_cap_reg_id[19] & lbc_cdm_data[31])) ? 1'b0 : 
                                   cfg_drs_msg_rec_reg;
    end else begin      // upstream or !cfg_drs_support
      cfg_drs_msg_rec_reg   <= #TP 1'b0;
    end
end


assign cfg_reg_155[7:4] = (cxl_rcrb_enable & ~(|RCRB)) ? 4'd0 : { cfg_drs_msg_rec_reg,        // [7]   Readiness Notification DRS Message Received
                            cfg_downstream_comp_pres }; // [4:6] Readiness Notification Downstream Component Presence
logic [1:0] smlh_crosslink_resolution_int;
assign smlh_crosslink_resolution_int = smlh_crosslink_resolution;
reg cfg_pcie_cap_flit_mode_stat; 
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
      cfg_pcie_cap_flit_mode_stat <= #TP 1'b0;
    end
    else  begin
      cfg_pcie_cap_flit_mode_stat <= #TP (!cfg_pcie_cap_flit_mode_sup)? 1'b0 : upstream_port ? flit_mode_enable : flit_mode_enable && (cfg_downstream_comp_pres == DCP_LD_FLIT_MODE_NEG || cfg_downstream_comp_pres == DCP_LU_COMP_PRES || cfg_downstream_comp_pres == DCP_LU_COMP_PRES_DRS);
    end
end    
assign cfg_reg_155[3:0] = (cxl_rcrb_enable & ~(|RCRB)) ? 4'b0 : {1'b0, cfg_pcie_cap_flit_mode_stat, smlh_crosslink_resolution_int };
// =============================================================================
// MSI-X Capability Structure
// =============================================================================
// MSI-X CAP register
// cfg_cap_reg_id   - 16
// PCIE Offset      - `CFG_MSIX_CAP
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_131, cfg_reg_130, cfg_reg_129, cfg_reg_128
// -----------------------------------------------------------------------------
reg           cfg_msix_en;
reg   [7:0]   cfg_msix_next_ptr;
reg           cfg_msix_func_mask;
reg   [10:0]  cfg_msix_table_size;
reg   [10:0]  cfg_msix_table_size2;
logic [10:0]  rdata_msix_table_size;
   
assign cfg_reg_128 = 8'h11;                                         // MSI-X Cap ID
assign cfg_reg_129 = cfg_msix_next_ptr;
assign {cfg_reg_131, cfg_reg_130} = {cfg_msix_en, cfg_msix_func_mask, 3'b0,
                                     rdata_msix_table_size};

assign rdata_msix_table_size = cfg_msix_table_size ;
                        
always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_msix_func_mask          <= #TP 0;
        cfg_msix_en                 <= #TP 0;        
    end else begin
        if (msix_cap_enable) begin
            // RW - protected on dbi2 access
            cfg_msix_func_mask          <= #TP (write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[30] : cfg_msix_func_mask;
            cfg_msix_en                 <= #TP (write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[31] : cfg_msix_en;
        end
        else begin
            cfg_msix_func_mask          <= #TP 0;
            cfg_msix_en                 <= #TP 0;     
        end
    end
end


reg msix_next_ptr_wr_updated;
 always @(posedge core_clk or negedge sticky_rst_n)
begin : cap_cxl_next_ptr_PROC
    if(!sticky_rst_n) begin
      cfg_msix_next_ptr           <= #TP `MSIX_NEXT_PTR;

        msix_next_ptr_wr_updated    <= #TP 1'b0;

    end else begin
        if (msix_cap_enable) begin
            // Read-Only register, but writable through DBI
            if (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[16]) begin 
               cfg_msix_next_ptr           <= #TP lbc_cdm_data[15:8];
               msix_next_ptr_wr_updated    <= #TP 1'b1;
            end
            else if (!msix_next_ptr_wr_updated) begin
               cfg_msix_next_ptr           <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_MSIX_NEXT_PTR : `CXL_MSIX_NEXT_PTR : `MSIX_NEXT_PTR ;
            end
         end else begin
            cfg_msix_next_ptr           <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_MSIX_NEXT_PTR : `CXL_MSIX_NEXT_PTR : `MSIX_NEXT_PTR ;
        end
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msix_table_size         <= #TP `MSIX_TABLE_SIZE;
        cfg_msix_table_size2        <= #TP `MSIX_TABLE_SIZE;
    end else begin
        if (msix_cap_enable) begin
            // Read-Only register, but writable through DBI
            cfg_msix_table_size[10:8]   <= #TP (int_lbc_cdm_dbi   & write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[26:24] : cfg_msix_table_size[10:8];
            cfg_msix_table_size[7:0]    <= #TP (int_lbc_cdm_dbi   & write_pulse[2] & cfg_cap_reg_id[16]) ? lbc_cdm_data[23:16] : cfg_msix_table_size[7:0];
            cfg_msix_table_size2[10:8]  <= #TP (int_lbc_cdm_dbi2  & write_pulse[3] & cfg_cap_reg_id[16]) ? lbc_cdm_data[26:24] : cfg_msix_table_size2[10:8];
            cfg_msix_table_size2[7:0]   <= #TP (int_lbc_cdm_dbi2  & write_pulse[2] & cfg_cap_reg_id[16]) ? lbc_cdm_data[23:16] : cfg_msix_table_size2[7:0];
        end
        else begin
            cfg_msix_table_size         <= #TP `MSIX_TABLE_SIZE;
            cfg_msix_table_size2        <= #TP `MSIX_TABLE_SIZE;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI-X Table Offset/Table BIR
// cfg_cap_reg_id   - 17
// PCIE Offset      - `CFG_MSIX_CAP + 04h
// Length           - 4 bytes
// Default value    - {`MSIX_TABLE_OFFSET, `MSIX_TABLE_BIR}
// Cfig register    - cfg_reg_135, cfg_reg_134, cfg_reg_133, cfg_reg_132
// -----------------------------------------------------------------------------
reg [2:0]   cfg_msix_table_bir, cfg_msix_table_bir2;
reg [28:0]  cfg_msix_table_offset, cfg_msix_table_offset2;
wire [2:0]  rdata_msix_table_bir;
wire [28:0] rdata_msix_table_offset;

assign cfg_reg_132 = {rdata_msix_table_offset[4:0], rdata_msix_table_bir};
assign {cfg_reg_135, cfg_reg_134, cfg_reg_133} = rdata_msix_table_offset[28:5]; 

assign rdata_msix_table_bir    = cfg_msix_table_bir ;
assign rdata_msix_table_offset = cfg_msix_table_offset ;
 
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msix_table_bir          <= #TP `MSIX_TABLE_BIR;
        cfg_msix_table_offset       <= #TP `MSIX_TABLE_OFFSET;
        cfg_msix_table_bir2         <= #TP `VF_MSIX_TABLE_BIR;
        cfg_msix_table_offset2      <= #TP `VF_MSIX_TABLE_OFFSET;

    end else begin 
        if (msix_cap_enable) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            // Read-Only register, but writable through DBI
            cfg_msix_table_bir          <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[2:0]   : cfg_msix_table_bir;
            cfg_msix_table_offset[4:0]  <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[7:3]   : cfg_msix_table_offset[4:0];
            cfg_msix_table_offset[12:5] <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[17]) ? lbc_cdm_data[15:8]  : cfg_msix_table_offset[12:5];
            cfg_msix_table_offset[20:13]<= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[17]) ? lbc_cdm_data[23:16] : cfg_msix_table_offset[20:13];
            cfg_msix_table_offset[28:21]<= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[17]) ? lbc_cdm_data[31:24] : cfg_msix_table_offset[28:21];
            // Read-Only register, but writable through DBI2
            cfg_msix_table_bir2          <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[2:0]   : cfg_msix_table_bir2;
            cfg_msix_table_offset2[4:0]  <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[17]) ? lbc_cdm_data[7:3]   : cfg_msix_table_offset2[4:0];
            cfg_msix_table_offset2[12:5] <= #TP (int_lbc_cdm_dbi2 & write_pulse[1] & cfg_cap_reg_id[17]) ? lbc_cdm_data[15:8]  : cfg_msix_table_offset2[12:5];
            cfg_msix_table_offset2[20:13]<= #TP (int_lbc_cdm_dbi2 & write_pulse[2] & cfg_cap_reg_id[17]) ? lbc_cdm_data[23:16] : cfg_msix_table_offset2[20:13];
            cfg_msix_table_offset2[28:21]<= #TP (int_lbc_cdm_dbi2 & write_pulse[3] & cfg_cap_reg_id[17]) ? lbc_cdm_data[31:24] : cfg_msix_table_offset2[28:21];
        end
        else begin
            cfg_msix_table_bir          <= #TP `MSIX_TABLE_BIR;
            cfg_msix_table_offset       <= #TP `MSIX_TABLE_OFFSET;
            cfg_msix_table_bir2         <= #TP `VF_MSIX_TABLE_BIR;
            cfg_msix_table_offset2      <= #TP `VF_MSIX_TABLE_OFFSET;
        end
    end
end

// -----------------------------------------------------------------------------
// MSI-X PBA Offset/PBA BIR
// cfg_cap_reg_id   - 18
// PCIE Offset      - `CFG_MSIX_CAP + 08h
// Length           - 4 bytes
// Default value    - {`MSIX_PBA_OFFSET, `MSIX_PBA_BIR}
// Cfig register    - cfg_reg_139, cfg_reg_138, cfg_reg_137, cfg_reg_136
// -----------------------------------------------------------------------------
reg [2:0]   cfg_msix_pba_bir, cfg_msix_pba_bir2;
reg [28:0]  cfg_msix_pba_offset, cfg_msix_pba_offset2;
wire [2:0]  rdata_msix_pba_bir;
wire [28:0] rdata_msix_pba_offset;

assign cfg_reg_136 = {rdata_msix_pba_offset[4:0], rdata_msix_pba_bir};
assign {cfg_reg_139, cfg_reg_138, cfg_reg_137} = rdata_msix_pba_offset[28:5];

assign rdata_msix_pba_bir    = cfg_msix_pba_bir ;
assign rdata_msix_pba_offset = cfg_msix_pba_offset ;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_msix_pba_bir            <= #TP `MSIX_PBA_BIR;
        cfg_msix_pba_offset         <= #TP `MSIX_PBA_OFFSET;
        cfg_msix_pba_bir2           <= #TP `VF_MSIX_PBA_BIR;
        cfg_msix_pba_offset2        <= #TP `VF_MSIX_PBA_OFFSET;
    end else begin
        if (msix_cap_enable) begin 
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            // Read-Only register, but writable through DBI
            cfg_msix_pba_bir            <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[2:0]   : cfg_msix_pba_bir;
            cfg_msix_pba_offset[4:0]    <= #TP (int_lbc_cdm_dbi & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[7:3]   : cfg_msix_pba_offset[4:0];
            cfg_msix_pba_offset[12:5]   <= #TP (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[18]) ? lbc_cdm_data[15:8]  : cfg_msix_pba_offset[12:5];
            cfg_msix_pba_offset[20:13]  <= #TP (int_lbc_cdm_dbi & write_pulse[2] & cfg_cap_reg_id[18]) ? lbc_cdm_data[23:16] : cfg_msix_pba_offset[20:13];
            cfg_msix_pba_offset[28:21]  <= #TP (int_lbc_cdm_dbi & write_pulse[3] & cfg_cap_reg_id[18]) ? lbc_cdm_data[31:24] : cfg_msix_pba_offset[28:21];
            // Read-Only register, but writable through DBI
            cfg_msix_pba_bir2            <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[2:0]   : cfg_msix_pba_bir2;
            cfg_msix_pba_offset2[4:0]    <= #TP (int_lbc_cdm_dbi2 & write_pulse[0] & cfg_cap_reg_id[18]) ? lbc_cdm_data[7:3]   : cfg_msix_pba_offset2[4:0];
            cfg_msix_pba_offset2[12:5]   <= #TP (int_lbc_cdm_dbi2 & write_pulse[1] & cfg_cap_reg_id[18]) ? lbc_cdm_data[15:8]  : cfg_msix_pba_offset2[12:5];
            cfg_msix_pba_offset2[20:13]  <= #TP (int_lbc_cdm_dbi2 & write_pulse[2] & cfg_cap_reg_id[18]) ? lbc_cdm_data[23:16] : cfg_msix_pba_offset2[20:13];
            cfg_msix_pba_offset2[28:21]  <= #TP (int_lbc_cdm_dbi2 & write_pulse[3] & cfg_cap_reg_id[18]) ? lbc_cdm_data[31:24] : cfg_msix_pba_offset2[28:21];
        end
        else begin
            cfg_msix_pba_bir            <= #TP `MSIX_PBA_BIR;
            cfg_msix_pba_offset         <= #TP `MSIX_PBA_OFFSET;
            cfg_msix_pba_bir2           <= #TP `VF_MSIX_PBA_BIR;
            cfg_msix_pba_offset2        <= #TP `VF_MSIX_PBA_OFFSET;
        end
    end
end

// =============================================================================
// PCI SLOT Indentification capability structure
// does not apply to EP
// cfg_cap_reg_id   - 15
// PCIE Offset      - `CFG_SLOT_CAP
// length           - 4 byte
// default value    -
// Cfig register    - cfg_reg_127, cfg_reg_126, cfg_reg_125, cfg_reg_124
// =============================================================================

reg [7:0] chassis_num;

assign cfg_reg_124 = slot_cap_enable ? 8'h04 : 8'h0;                                     // Slot capability ID
assign cfg_reg_125 = slot_cap_enable ? (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_SLOT_NEXT_PTR : `CXL_SLOT_NEXT_PTR : 
 (1)? `SLOT_NEXT_PTR : 8'h0 
                                     : 8'h0;
assign cfg_reg_126 = slot_cap_enable ? {2'b0, `FIRST_IN_CHASSIS, `SLOT_NUM} : 8'h0;
assign cfg_reg_127 = slot_cap_enable ? chassis_num : 8'h0;

always @(posedge core_clk or negedge non_sticky_rst_n)
    if (!non_sticky_rst_n) begin
        chassis_num <= #TP 0;
    end else begin
        chassis_num <= #TP slot_cap_enable & write_pulse[3] & cfg_cap_reg_id[15] ? lbc_cdm_data[31:24] : chassis_num;
    end

generate
if(FUNC_NUM < VPD_NF ) begin : gen_vpd_reg
// =============================================================================
// Vital Product Data (VPD) Capability Structure
// =============================================================================
// VPD CAP register
// cfg_cap_reg_id   - 20
// PCIE Offset      - `CFG_VPD_CAP
// Length           - 4 bytes
// Default value    - {0, 0, `VPD_NEXT_PTR, 0x03}
// Cfig register    - cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164
// -----------------------------------------------------------------------------
reg         cfg_vpd_flag;
reg [7:0]   cfg_vpd_next_ptr;
reg [14:0]  cfg_vpd_addr;
assign cfg_reg_164 = 8'h03;                                         // VPD Cap ID
assign cfg_reg_165 = cfg_vpd_next_ptr;
assign {cfg_reg_167, cfg_reg_166} = {cfg_vpd_flag, cfg_vpd_addr};

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_vpd_int             <= #TP 0;
        cfg_vpd_addr            <= #TP 0;
        cfg_vpd_flag            <= #TP 0;
    end else begin
        if (vpd_cap_enable) begin
            // If there's a write to this register over the wire, notify the application (pulse).
            cfg_vpd_int         <= #TP (!lbc_cdm_dbi & (write_pulse[2] | write_pulse[3]) & cfg_cap_reg_id[20]);
            // RW
            cfg_vpd_addr[7:0]   <= #TP (write_pulse[2] & cfg_cap_reg_id[20]) ? lbc_cdm_data[23:16] : cfg_vpd_addr[7:0];
            cfg_vpd_addr[14:8]  <= #TP (write_pulse[3] & cfg_cap_reg_id[20]) ? lbc_cdm_data[30:24] : cfg_vpd_addr[14:8];
            cfg_vpd_flag        <= #TP (write_pulse[3] & cfg_cap_reg_id[20]) ? lbc_cdm_data[31] : cfg_vpd_flag;
        end
        else begin
            cfg_vpd_int         <= #TP 0;
            cfg_vpd_addr        <= #TP 0;
            cfg_vpd_flag        <= #TP 0;
        end
    end
end

reg vpd_next_ptr_wr_updated;
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_vpd_next_ptr        <= #TP ((FUNC_NUM==0) ? `VPD_NEXT_PTR_0 : `VPD_NEXT_PTR_N) ;
        vpd_next_ptr_wr_updated <= #TP 1'b0;
    end else begin
        if (vpd_cap_enable) begin
            if (int_lbc_cdm_dbi & write_pulse[1] & cfg_cap_reg_id[20]) begin
               // Read-Only register, but writable through DBI
               cfg_vpd_next_ptr        <= #TP lbc_cdm_data[15:8];
               vpd_next_ptr_wr_updated <= #TP 1'b1;
            end
            else if (!vpd_next_ptr_wr_updated) begin
               cfg_vpd_next_ptr    <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? 'b0 : `CXL_VPD_NEXT_PTR :((FUNC_NUM==0) ? `VPD_NEXT_PTR_0 : `VPD_NEXT_PTR_N);
            end
        end
        else begin
            cfg_vpd_next_ptr    <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? 'b0 : `CXL_VPD_NEXT_PTR :((FUNC_NUM==0) ? `VPD_NEXT_PTR_0 : `VPD_NEXT_PTR_N);
        end
    end
end


// -----------------------------------------------------------------------------
// VPD Data
// cfg_cap_reg_id   - 21
// PCIE Offset      - `CFG_VPD_CAP + 04h
// Length           - 4 bytes
// Default value    - 0
// Cfig register    - cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168
// -----------------------------------------------------------------------------
reg [31:0]  cfg_vpd_data;

assign {cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168} = cfg_vpd_data;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
        cfg_vpd_data        <= #TP 0;
    end else begin
        if (vpd_cap_enable) begin
            // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
            cfg_vpd_data[7:0]   <= #TP (write_pulse[0] & cfg_cap_reg_id[21]) ? lbc_cdm_data[7:0]   : cfg_vpd_data[7:0];
            cfg_vpd_data[15:8]  <= #TP (write_pulse[1] & cfg_cap_reg_id[21]) ? lbc_cdm_data[15:8]  : cfg_vpd_data[15:8];
            cfg_vpd_data[23:16] <= #TP (write_pulse[2] & cfg_cap_reg_id[21]) ? lbc_cdm_data[23:16] : cfg_vpd_data[23:16];
            cfg_vpd_data[31:24] <= #TP (write_pulse[3] & cfg_cap_reg_id[21]) ? lbc_cdm_data[31:24] : cfg_vpd_data[31:24];
        end
        else begin
            cfg_vpd_data        <= #TP 0;
        end
    end
end

end else begin : gen_vpd_reg 
  assign cfg_vpd_int = 1'b0; 
  assign {cfg_reg_167, cfg_reg_166, cfg_reg_165, cfg_reg_164} = 32'b0;
  assign {cfg_reg_171, cfg_reg_170, cfg_reg_169, cfg_reg_168} = 32'b0;    
end // gen_vpd_reg
endgenerate 

assign cfg_reg_172 = 8'b0;
assign cfg_reg_173 = 8'b0;
assign cfg_reg_174 = 8'b0;
assign cfg_reg_175 = 8'b0;
assign cfg_reg_176 = 8'b0;
assign cfg_reg_177 = 8'b0;
assign cfg_reg_178 = 8'b0;
assign cfg_reg_179 = 8'b0;
assign cfg_reg_180 = 8'b0;
assign cfg_reg_181 = 8'b0;
assign cfg_reg_182 = 8'b0;
assign cfg_reg_183 = 8'b0;

genvar num_tlp;
generate
for (num_tlp=0; num_tlp< FX_TLP_ADR_DEC; num_tlp = num_tlp+1) begin : u_cdm_bar_match_gen

    cdm_bar_match
     #(.INST(INST), .FUNC_NUM(FUNC_NUM) , .RCRB(RCRB)) u_cdm_bar_match
  (
    // -- inputs --
    .core_clk                   (core_clk),
    .non_sticky_rst_n           (non_sticky_rst_n),
    .flt_cdm_addr               (flt_cdm_addr[64*(num_tlp+1)-1:64*num_tlp]),
    .upstream_port              (upstream_port),
    .type0                      (type0),
    .cfg_io_limit_upper16       (cfg_io_limit_upper16),
    .cfg_io_base_upper16        (cfg_io_base_upper16),
    .cfg_io_base                (cfg_io_base),
    .cfg_io_limit               (cfg_io_limit),
    .io_is_32bit                (io_is_32bit),
    .cfg_io_space_en            (cfg_io_space_en),
    .cfg_mem_space_en           (cfg_mem_space_en),
    .cfg_bus_master_en          (cfg_bus_master_en),
    .cfg_isa_enable             (cfg_isa_enable),
    .cfg_vga_enable             (cfg_vga_enable),
    .cfg_vga16_decode           (cfg_vga16_decode),
    .cfg_bar_is_io              (cfg_bar_is_io),
    .cfg_bar_enabled            (cfg_bar_enabled),
    .cfg_bar0_start             (cfg_bar0_start),
    .cfg_bar0_limit             (cfg_bar0_limit),
    .cfg_bar0_mask              (cfg_bar0_mask),
    .cfg_bar1_start             (cfg_bar1_start),
    .cfg_bar1_limit             (cfg_bar1_limit),
    .cfg_bar1_mask              (cfg_bar1_mask),
    .cfg_bar2_start             (cfg_bar2_start),
    .cfg_bar2_limit             (cfg_bar2_limit),
    .cfg_bar2_mask              (cfg_bar2_mask),
    .cfg_bar3_start             (cfg_bar3_start),
    .cfg_bar3_limit             (cfg_bar3_limit),
    .cfg_bar3_mask              (cfg_bar3_mask),
    .cfg_bar4_start             (cfg_bar4_start),
    .cfg_bar4_limit             (cfg_bar4_limit),
    .cfg_bar4_mask              (cfg_bar4_mask),
    .cfg_bar5_start             (cfg_bar5_start),
    .cfg_bar5_limit             (cfg_bar5_limit),
    .cfg_bar5_mask              (cfg_bar5_mask),
    .cfg_exp_rom_enable         (exp_rom_enable),
    .cfg_exp_rom_start          (cfg_exp_rom_start),
    .cfg_exp_rom_mask           (cfg_rom_mask),
    .cfg_mem_base               (cfg_mem_base),
    .cfg_mem_limit              (cfg_mem_limit),
    .cfg_pref_mem_base          (cfg_pref_mem_base),
    .cfg_pref_mem_limit         (cfg_pref_mem_limit),
    .cfg_config_limit           (cfg_config_limit),
    .cxl_rcrb_enable            (cxl_rcrb_enable),
    .rcrb_base_addr             (rcrb_base_addr),
    .rcrb_base_addr_valid       (rcrb_base_addr_valid),
    .rcrb_mbar0_addr            (rcrb_mbar0_base_addr[63:16]),
    .cxl_2_0_mbar0_offset                    (cxl_2_0_mbar0_offset),
    .cxl2p0_enabled                          (cxl2p0_enabled),
    .cfg_cxl_2_0_ext_alt_mse                 (cfg_cxl_2_0_ext_alt_mse),                   // Alternate Memory Space Enable 
    .cfg_cxl_2_0_ext_alt_bme                 (cfg_cxl_2_0_ext_alt_bme),                   // Alternate Bus Master Enable
    .cfg_cxl_2_0_ext_alt_mem_base            (cfg_cxl_2_0_ext_alt_mem_base),              // Alternate Memory Base
    .cfg_cxl_2_0_ext_alt_mem_limit           (cfg_cxl_2_0_ext_alt_mem_limit),             // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base       (cfg_cxl_2_0_ext_alt_pref_mem_base),         // Alternate Prefetchable Memory Base
    .cfg_cxl_2_0_ext_alt_pref_mem_limit      (cfg_cxl_2_0_ext_alt_pref_mem_limit),        // Alternate Memory Limit
    .cfg_cxl_2_0_ext_alt_pref_mem_base_high  (cfg_cxl_2_0_ext_alt_pref_mem_base_high),    // Alternate Prefetchable Memory Base High
    .cfg_cxl_2_0_ext_alt_pref_mem_limit_high (cfg_cxl_2_0_ext_alt_pref_mem_limit_high),   // Alternate Prefetchable Memory Base High    

    // -- outputs --
    .cfg_io_match               (cfg_io_match[num_tlp]),
    .cfg_config_above_match     (cfg_config_above_match[num_tlp]),
    .cfg_rom_match              (cfg_rom_match[num_tlp]),
    .cfg_bar_match              (cfg_bar_match[6*(num_tlp+1)-1:6*num_tlp]),
    .cfg_mem_match              (cfg_mem_match[num_tlp]),
    .cfg_prefmem_match          (cfg_prefmem_match[num_tlp])
     ,    
    .cfg_rcrb_match              (cfg_rcrb_match[num_tlp]),
    .cfg_rcrb_mbar0_match        (cfg_rcrb_mbar0_match[num_tlp]),
    .rcrb_address_reg            (rcrb_address_reg_int[num_tlp]),
    .cfg_rcrb_mbar0_match_int    (cfg_rcrb_mbar0_match_int[num_tlp])
    ,.cfg_cxl_2_0_mbar0_match   (cfg_cxl_2_0_mbar0_match[num_tlp])
    ,.cxl_2_0_mbar0_access_int  (cxl_2_0_mbar0_access_int[num_tlp])
    ,.cfg_cxl_alt_mem_match     (cfg_cxl_alt_mem_match[num_tlp])
    ,.cfg_cxl_alt_prefmem_match (cfg_cxl_alt_prefmem_match[num_tlp])
   );
end
endgenerate

DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(cfg_bar_is_io)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_cfg_bar_is_io (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (sticky_rst_n),
`endif // SYNTHESIS
  .data_s  (cfg_bar_is_io_int),
  .data_d  (cfg_bar_is_io)
);

assign cfg_bar_is_io_int = {cfg_bar5_io, cfg_bar4_io, cfg_bar3_io, cfg_bar2_io, cfg_bar1_io, cfg_bar0_io};

// Map Function's BARs to Target0/Target1
//assign   target_mem_map    = {`MEM_FUNC_BAR5_TARGET_MAP, `MEM_FUNC_BAR4_TARGET_MAP, `MEM_FUNC_BAR3_TARGET_MAP,
//                              `MEM_FUNC_BAR2_TARGET_MAP, `MEM_FUNC_BAR1_TARGET_MAP, `MEM_FUNC_BAR0_TARGET_MAP};
//assign   target_rom_map    = `ROM_FUNC_TARGET_MAP;
//`ifdef CX_SRIOV_ENABLE
//assign   vf_target_mem_map = {`VF_MEM_FUNC_BAR5_TARGET_MAP, `VF_MEM_FUNC_BAR4_TARGET_MAP, `VF_MEM_FUNC_BAR3_TARGET_MAP,
//                              `VF_MEM_FUNC_BAR2_TARGET_MAP, `VF_MEM_FUNC_BAR1_TARGET_MAP, `VF_MEM_FUNC_BAR0_TARGET_MAP};
//`endif // CX_SRIOV_ENABLE


reg surprise_down_gate;
reg surprise_down_err;

//----------------------------------------
// surprise link down -- Transition from DL_Active to DL_Inactive as a Surprise Down error, except in the following cases:
//----------------------------------------
// Error blocking cases:
// upstream_surprise_down   - if a Switch Downstream Port transitions to DL_Inactive due to an event above that Port
// cfg_2nd_reset            - if set to 1b then the subsequent transition to DL_Inactive must not be considered an error
// cfg_link_dis             - if set to 1b then the subsequent transition to DL_Inactive must not be considered an error
// If the Port is associated with a hot-pluggable slot -- Hot-Plug Capable bit in the Slot Capabilities register set to 1b
// cfg_pcie_slot_hp_surprise- the Hot-Plug Surprise bit in the Slot Capabilities register is set to 1b
// cfg_pwr_ctrler_ctrl      -  Power Controller Control bit in Slot Control register is 1b(Off)

//----------------------------------------
// If a PME_Turn_Off Message has been sent through this Port, then the subsequent transition to DL_Inactive must not be considered an error.
// The DL_Inactive transition for this condition will not occur until a power off, a reset, or a request to restore the Link is sent to the Physical layer
// However in the case where the PME_Turn_Off/PME_TO_Ack handshake fails to complete successfully, a Surprise Down error may be detected.
// Capturing all this by latching the above handshake completion
//
reg radm_pm_to_ack_d; //delayed version
reg pme_turn_off_handshake_complete;

always @(posedge core_clk or negedge sticky_rst_n) 
    if (!sticky_rst_n) begin
        radm_pm_to_ack_d  <= #TP 0; 
    end else begin
        radm_pm_to_ack_d  <= #TP radm_pm_to_ack; 
    end

assign pme_turn_off_handshake_complete = (!radm_pm_to_ack & radm_pm_to_ack_d) || pm_xmt_turnoff;

//Check for state change from Active to Inactive
reg [1:0] dl_state_check;
reg [1:0] dl_state_check_d; //delayed version

assign dl_state_check = rdlh_dlcntrl_state;
always @(posedge core_clk or negedge sticky_rst_n)
    if (!sticky_rst_n)  begin
        dl_state_check_d            <= #TP 0;
    end else begin
        dl_state_check_d            <= #TP dl_state_check;
    end 
 

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        surprise_down_gate      <= #TP 0;
//For a Downstream Port, this bit must be Set if the component supports the optional capability of detecting and reporting a Surprise Down error condition.
        end else if (upstream_surprise_down || cfg_2nd_reset_mod || cfg_link_dis || pme_turn_off_handshake_complete ||
                    (cfg_pcie_slot_hp_cap && (cfg_pcie_slot_hp_surprise || cfg_pwr_ctrler_ctrl))) begin
        surprise_down_gate      <= #TP 1;
        end else if (dl_state_check_d != `S_DL_ACTIVE && dl_state_check == `S_DL_ACTIVE) begin // latch until link comes back up
        surprise_down_gate      <= #TP 0;
    end
end

always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        surprise_down_err      <= #TP 0;
//For a Downstream Port, this bit must be Set if the component supports the optional capability of detecting and reporting a Surprise Down error condition.
        end else if (cfg_dll_link_rpt_en && FUNC_NUM==0) begin // DLL link active reporting capable - always enabled when downstream port
                    surprise_down_err  <= #TP !(surprise_down_gate) && (dl_state_check_d == `S_DL_ACTIVE && dl_state_check == `S_DL_INACTIVE) && cfg_pcie_surp_dn_rpt_cap;  // trigger on link going down
        end else begin
//For Upstream Ports and components that do not support this optional capability, this bit must be hardwired to 0b.
            surprise_down_err  <= #TP 0;
    end
end


// ----------------------------------------------------------------------------
// Assign outputs
// ----------------------------------------------------------------------------
assign cfg_ltr_m_en = ltr_m_en_r;


//##############################################################################

`ifndef SYNTHESIS
`endif // SYNTHESIS
//##############################################################################



endmodule
