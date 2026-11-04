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
// ---  RCS information: ARCT generated file. Do not manually edit. (generator -> process_rtl.sh)
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/DWC_pcie_native_core.sv#14 $
// -------------------------------------------------------------------------

//==============================================================================
// Start License Usage
//==============================================================================
// Key Used   : DWC-PCIE                      (IP access)
// Key NotUsed: DWC-PCIE-G6-PREM-A-SRC        (Add-on feature access: DWC PCIe 6.0 Premium AMBA License)
// Key NotUsed: DWC-CCIX-G25-PREM-A-V2-SRC    (Add-on feature access: DWC CCIX Premium 25G AMBA II License)
// Key NotUsed: DWC-USB4-PCIE-PREM-A-SRC      (Add-on feature access: DWC USB4 PCIe Premium AMBA License)
// Key NotUsed: DWC-PCIE-G6-PREM-A-HPC-SRC    (Add-on feature access: DWC PCIe 6.0 Premium AMBA HPC License)
// Key Used   : DWC-CXL-30-PREM-A-SRC         (Add-on feature access: DWC CXL 3.0 Premium AMBA License)
// Key NotUsed: DWC-CXL-30-PREM-A-HPC-SRC     (Add-on feature access: DWC CXL 3.0 Premium AMBA HPC License)
// Key NotUsed: DWC-PCIE-G6-PREM-A-HPC-V2-SRC (Add-on feature access: DWC PCIe 6.0 Premium AMBA HPC II License)
// Key NotUsed: DWC-CXL-30-PREM-A-HPC-V2-SRC  (Add-on feature access: DWC CXL 3.0 Premium AMBA HPC II License)
// Key NotUsed: DWC-PCIE-G6-SECURITY          (Add-on feature access: DWC PCIE 6.0 Security Interface Add-On License)
// Key NotUsed: DWC-CXL-30-SECURITY           (Add-on feature access: DWC CXL 3.0 Security Interface Add-On License)
// Key NotUsed: DWC-PCIE-SW-FLOWTHROUGH       (Add-on feature access: DWC Encrypted Packet Flowthough Add-On License)
// Key NotUsed: DWC_UCIe_CXL3                 (Add-on feature access: DWC UCIe CTRL CXL3 Add-On License)
// Key NotUsed: DWC-UCIe-CXL3-HPC-SRC         (Add-on feature access: DWC UCIe CTRL CXL3 HPC Add-On License)
//==============================================================================
// End License Usage
//==============================================================================

//==============================================================================
// Start Prime Profile Usage
//==============================================================================
// Tag        : DWC_PCIE_PP_GEN6_05
// Label      : EA Release - Not for Tapeout
// Description: Gen6 RC/DM 
// EarlyAccess: No
//==============================================================================
// End Prime Profile Usage
//==============================================================================
// -----------------------------------------------------------------------------
// --- Module description:  This module is the PCIe native core
// --- It contains:
// --- * DWC_pcie_core
// --- * xali_harness_ms
// --- * cxs_top
// --- * cxs_ccix_aligner
// --- * cxs_prot_mux
// --- * cxl_mem_cache_core
// --- * cxl_vlsm
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_app_ch_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_init_if.svh"
`include "Cdm/cdm_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module DWC_pcie_native_core
import DWC_pcie_core_pkg::ltssm_state_e;
import cdm_pkg::*;
import radm_ms_pkg::*;
import pcie_pkg::*;
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_core_pkg::xplh_cdm_flit_latency_track_t;
import DWC_pcie_core_pkg::pm_cdm_state_trans_track_t;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
import spif_pkg::link_adm_if_t;
import spif_pkg::protocol_cfg_t;
import spif_pkg::state_enc_e;
import spif_pkg::RETRAIN;
import spif_pkg::stream_id_e;
import spif_pkg::protocol_type_e;
import spif_pkg::protocol_fmt_e;
import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
import DWC_pcie_ctl_pkg::DCA_WD;
import DWC_pcie_core_pkg::rtlh_rfc_t;
import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
import DWC_cxl_pkg::vlsm_debug_t;
import DWC_pcie_core_pkg::CFG_CXL_PORT_ENABLE_WD;
import DWC_pcie_core_pkg::xtlh_pkt_t;
import DWC_pcie_core_pkg::rplh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::rmlh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::smlh_flit_logging_interface_struct;
import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
import DWC_pcie_core_pkg::flit_err_inj_status_struct;
import DWC_pcie_core_pkg::cfg_os_einj_ctrl_1_t;
import DWC_pcie_core_pkg::cfg_os_einj_ctrl_2_t;
import DWC_pcie_core_pkg::cfg_os_einj_status_t;
#(
    parameter INST              = 0                                    // The uniquifying parameter for each port logic instance.
)

                           (
     input                      core_clk


    ,output logic[`N_XALI_IF-1:0]             xaim_xali_halt
    ,input xali_pkt_t[`N_XALI_IF-1:0]         xali_xaim_pkt
    ,input [8:0]              app_segment_id

    ,output [8:0]             cfg_segment_id
    ,output logic [`N_XADM_P_IF-1:0]      xali_posted_tlp_sent








    ,output                              radm_cpl_timeout
    ,output  [`CX_NFUNC_WD-1:0]          radm_timeout_func_num
    ,output  [2:0]                       radm_timeout_cpl_tc
    ,output  [1:0]                       radm_timeout_cpl_attr
    ,output  [11:0]                      radm_timeout_cpl_len
    ,output  [`CX_TAG_SIZE-1:0]          radm_timeout_cpl_tag

    // RTRGT1 interface
    ,output [`CX_NFUNC-1:0]         cfg_10b_tag_req_en

    ,input                               app_dbi_ro_wr_disable
    ,input                                   ext_lbc_override_en


    ,input   [`CX_NFUNC-1:0]                 ext_lbc_ack
    ,input   [(`CX_LBC_NW*32*`CX_NFUNC)-1:0] ext_lbc_din
    ,output  [`CX_LBC_EXT_AW-1:0]            lbc_ext_addr
    ,output  [`CX_LBC_NW*32-1:0]             lbc_ext_dout
    ,output  [`CX_NFUNC-1:0]                 lbc_ext_valid
    ,output  [`CX_NFUNC-1:0]                 lbc_ext_cs
    ,output  [(4*`CX_LBC_NW)-1:0]            lbc_ext_wr
    ,output  [(4*`CX_LBC_NW)-1:0]            lbc_ext_rd
    ,output                                  lbc_ext_dbi_access
    ,output                                  lbc_ext_cxl_mbar0_access
    ,output                                  lbc_ext_rom_access
    ,output                                  lbc_ext_io_access
    ,output  [2:0]                           lbc_ext_bar_num
    ,input                               ven_msi_req
    ,input   [`CX_NFUNC_WD-1:0]          ven_msi_func_num
    ,input   [2:0]                       ven_msi_tc
    ,input   [4:0]                       ven_msi_vector
    ,output                              ven_msi_grant
    ,output  [`CX_MSI_NFUNC-1:0]         cfg_msi_en
    ,output  [(64*`CX_MSI_NFUNC)-1:0]        cfg_msi_addr
    ,output  [(32*`CX_MSI_NFUNC)-1:0]        cfg_msi_data
    ,output  [`CX_MSI_NFUNC-1:0]             cfg_msi_64
    ,output  [(3*`CX_MSI_NFUNC)-1:0]         cfg_multi_msi_en
    ,output  [`CX_MSI_NFUNC-1:0]             cfg_msi_ext_data_en
    // MSI-X interface
    // VPD interface
    // FLR interface
    ,output [(2*`CX_NFUNC)-1:0]          cfg_tph_req_en
    ,output [(3*`CX_NFUNC)-1:0]          cfg_pf_tph_st_mode
    ,output [`CX_NFUNC-1:0]              cfg_pf_pasid_en
    ,output [`CX_NFUNC-1:0]              cfg_pf_pasid_execute_perm_en
    ,output [`CX_NFUNC-1:0]              cfg_pf_pasid_priv_mode_en
    ,output [`CX_NFUNC-1:0]                 cfg_atomic_req_en
    ,output [`CX_NFUNC-1:0]                 cfg_atomic_egress_block
    ,output [`CX_NFUNC-1:0]                 cfg_dmwr_req_en
    ,output  [1:0]                          cfg_obff_en
    ,output                                 app_obff_msg_grant
    ,output                              cfg_ltr_m_en
    ,output [(32*`CX_NFUNC)-1:0]         cfg_ltr_max_latency
    ,output                              cfg_disable_ltr_clr_msg
    // Power Budgeting Capabilities interface
    ,input   [31:0]                      cfg_pwr_budget_data_reg
    ,input   [`CX_NFUNC_WD-1:0]          cfg_pwr_budget_func_num
    ,output  [7:0]                       cfg_pwr_budget_data_sel_reg
    ,output  [`CX_PB_NFUNC-1:0]          cfg_pwr_budget_sel
    // ARI
    ,output  [`CX_NFUNC-1:0]             cfg_ari_fwd_en
    // VMI interface
    ,input   [1:0]                       ven_msg_fmt
    ,input   [4:0]                       ven_msg_type
    ,input   [2:0]                       ven_msg_tc
    ,input                               ven_msg_td
    ,input                               ven_msg_ep
    ,input   [`FLT_Q_ATTR_WIDTH-1:0]     ven_msg_attr
    ,input   [9:0]                       ven_msg_len
    ,input   [`CX_NFUNC_WD-1:0]          ven_msg_func_num
    ,input   [`CX_TAG_SIZE-1:0]          ven_msg_tag
    ,input   [7:0]                       ven_msg_code
    ,input   [63:0]                      ven_msg_data
    ,input                               ven_msg_req
    ,output                              ven_msg_grant
    // SII interface
    ,input                               tx_lane_flip_en
    ,input                               cfg_pm_clk_pm_en               // PM Link connections with PM CTRL
    ,input                               software_entr_l1               // PM Link connections with PM CTRL
    ,input                               software_entr_l23              // PM Link connections with PM CTRL
    ,input                               pm_aspm_l0s_en                 // PME Controller indicates to the PM Protocol FSM that L0s ASPM is enabled
    ,input                               pm_aspm_l1_en                  // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
    ,input                               pm_xtlh_block_tlp              // Instructs XTLH to block any new TLPs
    ,input  [`CX_NFUNC-1:0]              pm_radm_block_tlp              // Instructs RADM receive filter to reject TLPs other than CFG/MSG
    ,output                              pm_linkst_in_l0s_o             // PM Link connections with PM CTRL
    ,input                               pm_linkst_in_l0s               // Shadowed signal from PM CTRL
    ,input                               pm_linkst_in_l0                // Shadowed signal from PM CTRL
    ,input                               pm_hold_exit_l1                // PM Link connections with PM CTRL
    ,input                               pm_link_exit_l1                // PM Link connections with PM CTRL
    ,input                               pm_link_exit_l23               // Signals PM Link FSM to exit from L23RDY state
    ,input                               pm_pl_wake_ack                 // PM Controller Wakeup Acknowledge
    ,input                               pm_pl_clk_req                  // PM Controller Clock Request
    ,input                               pm_pl_phyinl1                  // PM Controller PHY in L1
    ,input                               pm_pl_phyinl2                  // PM Controller PHY in L2
    ,output  usp_link_fsm_state_e        pm_usp_link_state              // PM Link connections with PM CTRL
    ,output  dsp_link_fsm_state_e        pm_dsp_link_state              // PM Link connections with PM CTRL
    ,input   usp_link_fsm_state_e        shadow_pm_usp_link_state       // PM CTRL connections with CDM
    ,input   dsp_link_fsm_state_e        shadow_pm_dsp_link_state       // PM CTRL connections with CDM
    ,input                               pm_wake_req_exit_l0s           // PM Protocol connections
    ,input                               pm_l2_entry_flag               // PM Protocol connections
    ,input                               app_req_entr_l1                // PM Protocol connections
    ,input                               pm_wake_any_if_pending         // PM Protocol connections
    ,input                               app_xfer_pending               // PM Protocol connections
    ,input                               lp_pcie_l1_exit                // SPIF: Request to PCIe/CXL.io Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    ,input                               lp_pcie_clk_ack                // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
    ,input                               lp_pcie_wake_req               // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
    ,output                              pl_pcie_wake_ack               // SPIF: LogPHY acknowledges lp_wake_req to PCIe/CXL.io Link Layer
    ,output                              pl_pcie_clk_req                // SPIF: LogPHY requests PCIe/CXL.io Link Layer to remove the clock gating
    ,output                              pl_pcie_phyinl1                // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L1 state
    ,output                              pl_pcie_phyinl2                // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L2 state
    ,output                              pl_pcie_state_l1               // SPIF: pl_state_sts is in IDLE_L1_1 on PCIe/CXL.io SPIF interface
    ,output                              pl_pcie_state_l2               // SPIF: pl_state_sts is in L2 on PCIe/CXL.io SPIF interface
    ,output                              pl_pcie_state_active           // SPIF: pl_state_sts is in ACTIVE or ACTIVE_L0S_PMNAK on PCIe/CXL.io SPIF interface
    ,output                              pl_pcie_link_up                // SPIF: pl_link_up on PCIe/CXL.io SPIF interface
    ,input                               lp_cxl_l1_exit                 // SPIF: Request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
    ,input                               lp_cxl_clk_ack                 // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
    ,input                               lp_cxl_wake_req                // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
    ,output                              pl_cxl_wake_ack                // SPIF: LogPHY acknowledges lp_wake_req to CXL.cachemem Link Layer
    ,output                              pl_cxl_clk_req                 // SPIF: LogPHY requests CXL.cachemem Link Layer to remove the clock gating
    ,output                              pl_cxl_phyinl1                 // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L1 state
    ,output                              pl_cxl_phyinl2                 // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L2 state
    ,output                              pl_cxl_state_l1                // SPIF: pl_state_sts is in IDLE_L1_1 on CXL.cachemem SPIF interface
    ,output                              pl_cxl_state_l2                // SPIF: pl_state_sts is in L2 on CXL.cachemem SPIF interface
    ,output                              pl_cxl_mode_enable             // SPIF: SPLH Configuration - CXL Mode Enable bit
    ,output  logic                       pm_xdlh_enter_l23              // PM Protocol connections
    ,output  logic                       pm_l1_entry_started            // PM Protocol connections
    ,output  logic                       pm_l1_in_progress              // PM Protocol connections
    ,output  logic                       pm_aspm_l1_enter_ready         // PM Protocol connections
    ,output  logic                       latch_as_entr_l1               // PM Protocol connections
    ,output  logic                       pm_prot_idle_flag              // PM Protocol connections
    ,output  logic                       lp_sdb_l1sub_aspm              // PM Protocol connections
    ,output  logic                       lp_sdb_l1sub_pcipm             // PM Protocol connections
    ,input   [`CX_NFUNC-1:0]             sys_int
    ,input                               sys_aux_pwr_det
    ,input   [`CX_NFUNC-1:0]             sys_atten_button_pressed
    ,input   [`CX_NFUNC-1:0]             sys_pre_det_state
    ,input   [`CX_NFUNC-1:0]             sys_mrl_sensor_state
    ,input   [`CX_NFUNC-1:0]             sys_pwr_fault_det
    ,input   [`CX_NFUNC-1:0]             sys_mrl_sensor_chged
    ,input   [`CX_NFUNC-1:0]             sys_pre_det_chged
    ,input   [`CX_NFUNC-1:0]             sys_cmd_cpled_int
    ,input   [`CX_NFUNC-1:0]             sys_eml_interlock_engaged
    ,output  [(2*`CX_NFUNC)-1:0]         cfg_pwr_ind
    ,output  [(2*`CX_NFUNC)-1:0]         cfg_atten_ind
    ,output  [`CX_NFUNC-1:0]             cfg_pwr_ctrler_ctrl
    ,input                               app_unlock_msg
    ,input                               app_obff_idle_msg_req
    ,input                               app_obff_obff_msg_req
    ,input                               app_obff_cpu_active_msg_req
    ,output wire                         pm_block_all_tlp     // PMC directs transmit modules to block all tlps
    ,output  [(64*`CX_NFUNC)-1:0]        cfg_bar0_start
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_bar1_start
    ,output  [(64*`CX_NFUNC)-1:0]        cfg_bar0_limit
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_bar1_limit
    ,output  [(64*`CX_NFUNC)-1:0]        cfg_bar2_start
    ,output  [(64*`CX_NFUNC)-1:0]        cfg_bar2_limit
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_bar3_start
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_bar3_limit
    ,output  [(64*`CX_NFUNC)-1:0]        cfg_bar4_start
    ,output  [(64*`CX_NFUNC)-1:0]        cfg_bar4_limit
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_bar5_start
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_bar5_limit
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_exp_rom_start
    ,output  [(32*`CX_NFUNC)-1:0]        cfg_exp_rom_limit
    ,output  [`CX_NFUNC-1:0]             cfg_bus_master_en
    ,output  [`CX_NFUNC-1:0]             cfg_mem_space_en
    ,output  [(3*`CX_NFUNC)-1:0]         cfg_max_rd_req_size
    ,output  [(3*`CX_NFUNC)-1:0]         cfg_max_payload_size
    ,output                              cfg_memtype_value
    ,output      [`FLT_Q_ADDR_WIDTH-3:0] cfg_memtype_boundary
    ,output  [`CX_NFUNC-1:0]             cfg_ext_tag_en
    ,output  [`CX_NFUNC-1:0]             cfg_rcb
    ,output  [`CX_NFUNC -1 :0]           cfg_pm_no_soft_rst
    ,output                              cfg_aer_rc_err_int
    ,output                              cfg_aer_rc_err_msi
    ,output  [4:0]                       cfg_aer_int_msg_num
    ,output                              cfg_sys_err_rc
    ,output                              cfg_pme_int
    ,output                              cfg_pme_msi
    ,output                              cfg_crs_sw_vis_en
    ,output  [(`CX_NFUNC*5)-1:0]         cfg_pcie_cap_int_msg_num
    ,output                              rdlh_link_up

    ,output ltssm_state_e                smlh_ltssm_state
    ,output                      cfg_flit_log_trg_evnt_msi

    ,output                      cfg_pcie_cap_flit_mode_stat

    ,output wire  [4:0]                        cdm_pm_state_trans_tracker
    ,input wire  pm_cdm_state_trans_track_t    pm_cdm_state_trans_tracking
    ,output wire                               smlh_pm_state_trans1_flag
    ,output wire                               smlh_pm_state_trans2_flag
    ,output                      cfg_flit_latency_msi
    ,output wire [9:0]           cfg_flit_perf_interr_vec
    ,output                      cfg_sts_1_ltssm_latency_msi
    ,output                              smlh_ltssm_state_rcvry_eq
    ,output                              smlh_link_up
    ,output                              smlh_req_rst_not
    ,output                              link_req_rst_not
    ,input                               brdg_slv_xfer_pending
    ,input                               brdg_dbi_xfer_pending
    ,input                               brdg_mstr_xfer_pending
    ,output  [`CX_RADM_NFC_TRGT_INTF-1:0]radm_vendor_msg
    ,output  [`CX_RADM_NFC_TRGT_INTF-1:0]radm_vendor_msg_type
    ,output                              radm_msg_ltr
    ,output  [(`CX_RADM_NFC_TRGT_INTF*64)-1:0]radm_msg_payload
    ,output                              radm_msg_unlock
    ,output                              radm_msg_idle
    ,output                              radm_msg_obff
    ,output                              radm_msg_cpu_active
    ,output  [(`CX_RADM_NFC_TRGT_INTF*16)-1:0]radm_msg_req_id
    ,output                              radm_inta_asserted
    ,output                              radm_intb_asserted
    ,output                              radm_intc_asserted
    ,output                              radm_intd_asserted
    ,output                              radm_inta_deasserted
    ,output                              radm_intb_deasserted
    ,output                              radm_intc_deasserted
    ,output                              radm_intd_deasserted
    ,output                              radm_correctable_err
    ,output                              radm_nonfatal_err
    ,output                              radm_fatal_err
    ,output                              radm_pm_pme
    ,output                              radm_pm_to_ack
    ,output                              radm_pm_turnoff
    ,output  [`CX_RX_NDLLP-1:0]          rtlh_rfc_upd
    ,output  [(32*`CX_RX_NDLLP)-1:0]     rtlh_rfc_data
    ,output  [`CX_NFUNC-1:0]             cfg_eml_control
    ,output  [`CX_NFUNC-1:0]             hp_pme
    ,output  [`CX_NFUNC-1:0]             hp_int
    ,output  [`CX_NFUNC-1:0]             hp_msi
    ,input                               pm_io_handler_app_sris_mode
    ,output logic                        cfg_comm_clk_config
    ,input                               app_ltssm_enable
    ,output  [`CX_BUSNUM_WD-1:0]         cfg_pbus_num
    ,output  [`CX_DEVNUM_WD-1:0]         cfg_pbus_dev_num

    ,input   [(3*`CX_NFUNC)-1:0]        pm_dstate
    ,input   [`CX_NFUNC-1:0]            pm_status
    ,output                             cfg_link_dis
    ,output                             cfg_link_auto_bw_int
    ,output                             cfg_link_auto_bw_msi
    ,output                             cfg_bw_mgt_int
    ,output                             cfg_bw_mgt_msi
    ,output                             cfg_link_eq_req_int
    ,output                             usp_eq_redo_executed_int
    ,input                              app_ltr_msg_req
    ,output                             app_ltr_msg_grant
    ,input   [31:0]                     app_ltr_msg_latency
    ,input   [`CX_NFUNC_WD-1:0]         app_ltr_msg_func_num
    ,output  [31:0]                     app_ltr_latency
    ,output  [`CX_NVC-1:0]              radm_q_not_empty
    ,output  [`CX_NVC-1:0]              radm_qoverflow
    ,output                             rtlh_fc_overflow_err
    ,output                             trgt_cpl_timeout
    ,output  [`CX_NFUNC_WD-1:0]         trgt_timeout_cpl_func_num
    ,output  [2:0]                      trgt_timeout_cpl_tc
    ,output  [1:0]                      trgt_timeout_cpl_attr
    ,output  [11:0]                     trgt_timeout_cpl_len
    ,output  [`CX_REMOTE_LOOKUPID_WD-1:0] trgt_timeout_lookup_id
    ,output  [`CX_REMOTE_LOOKUPID_WD-1:0] trgt_lookup_id
    ,output                             trgt_lookup_empty
    ,input                                  app_hdr_valid
    ,input   [`CX_APP_HDR_LOG_WIDTH-1:0]    app_hdr_log
    ,input                                  app_hdr_flitmode
    ,input   [`CX_APP_HDR_LOG_SZ_WIDTH-1:0] app_hdr_log_size
    ,input   [`CX_ERR_BUS_WD-1:0]           app_err_bus
    ,input                                  app_err_advisory
    ,input                                  app_poisoned_tlp_type
    ,input   [`CX_NFUNC_WD-1:0]             app_err_func_num
    ,output  [2:0]                       pm_current_data_rate
    ,input wire  [(`CX_PHY_PDOWN_WD - 1) : 0] mac_phy_powerdown
    ,input wire  [`CX_NL*`CX_PHY_TXEI_WD-1:0] mac_phy_txelecidle
    ,input   [`CX_NL-1:0]                    phy_mac_phystatus
    ,input  [(`CX_NL - 1):0]             pipe_rx_clk
    ,input  [(`CX_NL - 1):0]             pipe_rx_rst_n
    ,input   [(`CX_PIPE_DATA_WD - 1):0]  phy_mac_rxdata
    ,input   [`CX_NL-1:0]                phy_mac_rxvalid
    ,input   [(`CX_NL*3)-1:0]            phy_mac_rxstatus
    ,input   [`CX_NL-1:0]                phy_mac_rxstandbystatus
    ,input   [31:0]                      phy_cfg_status
    ,input wire  [`CX_NL-1:0]              mac_phy_txdetectrx_loopback
    ,input wire  [`CX_NL-1:0]              mac_phy_txcompliance
    ,input wire  [`CX_NL-1:0]              mac_phy_rxpolarity
    ,input wire  [`CX_PHY_WIDTH_WD-1:0]    mac_phy_width
    ,input wire  [`CX_PHY_RATE_WD-1:0]     mac_phy_rate
    ,input wire  [`CX_PHY_TXDEEMPH_WD-1:0] mac_phy_txdeemph
    ,output                                cfg_hw_auto_sp_dis
    ,input   [`CX_NL*8-1:0]                  phy_mac_messagebus
    ,input                               pipe_msgbus_rst_n
    ,input                               app_margining_ready
    ,input                               app_margining_software_ready
    ,output wire [31:0]                  pre_cfg_phy_control
    ,input                               core_clk_ug
    ,input                               aux_clk_g
    ,input                               radm_clk_g
    ,output                              en_radm_clk_g
    ,output                              radm_idle
    ,input                               pwr_rst_n
    ,input                               sticky_rst_n
    ,input                               non_sticky_rst_n
    ,input                               core_rst_n
    ,input                               pm_sel_aux_clk
    ,input   [3:0]                       device_type
    ,input                               app_req_retry_en
    ,input  [`CX_NFUNC-1:0]              app_pf_req_retry_en
    ,input                               app_drs_ready
    ,output [`CX_NFUNC-1:0]              cfg_drs_msi
    ,output [`CX_NFUNC-1:0]              cfg_up_drs_to_frs
    ,input  [`CX_NFUNC-1:0]              app_pf_frs_ready
    ,output [`CX_NFUNC-1:0]              pf_frs_grant
    ,output                              frsq_msi
    ,output [4:0]                        frsq_int_msg_num
    ,output                              training_rst_n
    ,output  [`RBUF_PW -1:0]             xdlh_retryram_raddr
    ,output  [`RBUF_PW -1:0]             xdlh_retryram_waddr
    ,output  [`RBUF_WIDTH-1:0]           xdlh_retryram_data
    ,output                              xdlh_retryram_we
    ,output                              xdlh_retryram_en
    ,input   [`RBUF_WIDTH-1:0]           retryram_xdlh_data
    // Retry SOT buffer
    ,output  [`SOTBUF_L2DEPTH -1:0]      xdlh_retrysotram_waddr
    ,output  [`SOTBUF_L2DEPTH -1:0]      xdlh_retrysotram_raddr
    ,output  [`SOTBUF_WIDTH -1:0]        xdlh_retrysotram_data
    ,output                              xdlh_retrysotram_we
    ,output                              xdlh_retrysotram_en
    ,input   [`SOTBUF_WIDTH -1:0]        retrysotram_xdlh_data

    ,output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_P-1:0]     radm_formqram_addra_vc0_p
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_ena_vc0_p
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_wea_vc0_p
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_P-1:0]     radm_formqram_dina_vc0_p
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_P-1:0]     radm_formqram_addrb_vc0_p
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_enb_vc0_p
    // ---- ,inputs from formation queue ram ---------------
    ,input   [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_P-1:0]     formqram_radm_doutb_vc0_p
    // VC0 NP Radm Formation Queue external RAM interface
    // ---- ,outputs to formation queue ram ---------------
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_NP-1:0]    radm_formqram_addra_vc0_np
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_ena_vc0_np
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_wea_vc0_np
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_NP-1:0]    radm_formqram_dina_vc0_np
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_NP-1:0]    radm_formqram_addrb_vc0_np
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_enb_vc0_np
    // ---- ,inputs from formation queue ram ---------------
    ,input   [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_NP-1:0]    formqram_radm_doutb_vc0_np
    // VC0 CPL Radm Formation Queue external RAM interface
    // ---- ,outputs to formation queue ram ---------------
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_CPL-1:0]   radm_formqram_addra_vc0_cpl
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_ena_vc0_cpl
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_wea_vc0_cpl
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_CPL-1:0]   radm_formqram_dina_vc0_cpl
    ,output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_CPL-1:0]   radm_formqram_addrb_vc0_cpl
    ,output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_enb_vc0_cpl
    // ---- ,inputs from formation queue ram ---------------
    ,input   [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_CPL-1:0]   formqram_radm_doutb_vc0_cpl

    ,input  logic                             trgt1_radm_intf_p_0_halt
    ,input  logic                             trgt1_radm_intf_np_0_halt
    ,input logic                              trgt1_radm_intf_cpl_0_halt
    ,output    [`CX_RADM_RAS_DES_ERR_INFO_WD-1:0] radm_ras_des_err_info_0
    ,output [`CX_RAS_DES_EC_RAM_ADDR_WIDTH-1:0]  cdm_ras_des_ec_ram_addra
    ,output [`CX_RAS_DES_EC_RAM_ADDR_WIDTH-1:0]  cdm_ras_des_ec_ram_addrb
    ,output [`CX_RAS_DES_EC_RAM_DATA_WIDTH-1:0]  cdm_ras_des_ec_ram_datain
    ,output                                      cdm_ras_des_ec_ram_wea
    ,output                                      cdm_ras_des_ec_ram_ena
    ,output                                      cdm_ras_des_ec_ram_enb
    ,input  [`CX_RAS_DES_EC_RAM_DATA_WIDTH-1:0]  cdm_ras_des_ec_ram_dataout
    ,output [`CX_RAS_DES_TBA_RAM_ADDR_WIDTH-1:0] cdm_ras_des_tba_ram_addra
    ,output [`CX_RAS_DES_TBA_RAM_ADDR_WIDTH-1:0] cdm_ras_des_tba_ram_addrb
    ,output [`CX_RAS_DES_TBA_RAM_DATA_WIDTH-1:0] cdm_ras_des_tba_ram_datain
    ,output                                      cdm_ras_des_tba_ram_wea
    ,output                                      cdm_ras_des_tba_ram_ena
    ,output                                      cdm_ras_des_tba_ram_enb
    ,input  [`CX_RAS_DES_TBA_RAM_DATA_WIDTH-1:0] cdm_ras_des_tba_ram_dataout
    ,output  [`CX_NFUNC-1:0]                 cfg_reg_serren
    ,output  [`CX_NFUNC-1:0]                 cfg_cor_err_rpt_en
    ,output  [`CX_NFUNC-1:0]                 cfg_nf_err_rpt_en
    ,output  [`CX_NFUNC-1:0]                 cfg_f_err_rpt_en
    ,input   [1:0]  cdm_ras_des_einj0_req
    ,output  [1:0]  cdm_ras_des_einj0_ack
    ,output  [`CX_RAS_DES_EC_INFO_CMN_BW-1:0]     cdm_ras_des_ec_info_common
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l0
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l1
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l2
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l3
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l4
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l5
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l6
    ,output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l7
    ,input                                        app_ras_des_sd_hold_ltssm
    ,output  [`CX_RAS_DES_SD_INFO_CMN_BW-1:0]     cdm_ras_des_sd_info_common
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l0
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l1
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l2
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l3
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l4
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l5
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l6
    ,output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l7
    ,output   [`CX_RAS_DES_SD_INFO_PVC_BW-1:0]    cdm_ras_des_sd_info_v0
    ,output   [`CX_RAS_DES_TBA_INFO_CMN_BW-1:0]   cdm_ras_des_tba_info_common
    ,input    [1:0]                               app_ras_des_tba_ctrl
    ,input [`CX_NFUNC-1:0]               exp_rom_validation_status_strobe
    ,input [`CX_NFUNC*3-1:0]             exp_rom_validation_status
    ,input [`CX_NFUNC-1:0]               exp_rom_validation_details_strobe
    ,input [`CX_NFUNC*4-1:0]             exp_rom_validation_details
    ,output  [63:0]                      cxpl_debug_info
    ,output  [`CX_INFO_EI_WD-1:0]        cxpl_debug_info_ei
    ,input wire     [`CX_NL-1:0]                 mac_phy_rxeqeval
    ,output                        assert_inta_grt
    ,output                        assert_intb_grt
    ,output                        assert_intc_grt
    ,output                        assert_intd_grt
    ,output                        deassert_inta_grt
    ,output                        deassert_intb_grt
    ,output                        deassert_intc_grt
    ,output                        deassert_intd_grt
    ,output  [(8*`CX_NFUNC)-1:0]   cfg_int_pin

    ,output  [7:0]   cfg_2ndbus_num
    ,output  [7:0]   cfg_subbus_num
    ,output                        cfg_2nd_reset
    ,output                  cfg_l1sub_en
    ,input                   app_clk_pm_en
    ,output [`CX_NFUNC-1:0]  cfg_end2end_tlp_pfx_blck
    ,input               aux_clk_active
    ,output [`CX_NFUNC-1:0]          cfg_ido_req_en
    ,output [`CX_NFUNC-1:0]          cfg_ido_cpl_en
    ,output  [`CX_NFUNC-1:0]         cfg_send_cor_err
    ,output  [`CX_NFUNC-1:0]         cfg_send_nf_err
    ,output  [`CX_NFUNC-1:0]         cfg_send_f_err
    ,output  [`CX_NFUNC-1:0]         cfg_int_disable
    ,output  [`CX_NFUNC-1:0]         cfg_no_snoop_en
    ,output  [`CX_NFUNC-1:0]         cfg_relax_order_en
    ,output                          ptm_context_valid
    ,output                          ptm_responder_rdy_to_validate
    ,output [63:0]                   ptm_local_clock
    ,input                           ptm_external_master_strobe
    ,input [63:0]                    ptm_external_master_time
    ,input                           ptm_auto_update_signal
    ,input                           ptm_manual_update_pulse
    ,output                          ptm_trigger_allowed
    ,output                          ptm_updating
    ,output                          ptm_clock_updated
    ,output [63:0]                   ptm_clock_correction
    ,output                          ptm_req_response_timeout
    ,output                          ptm_req_dup_rx
    ,output                          ptm_req_replay_tx
    ,output   [(5*`CX_NFUNC)-1:0]   cfg_ats_stu
    ,output   [`CX_NFUNC-1:0]       cfg_ats_cache_en
    ,output   [`CX_NFUNC-1:0]   surprise_down_err
    ,input    [`CX_NFUNC-1:0]       prs_res_failure
    ,input    [`CX_NFUNC-1:0]       prs_uprgi
    ,input    [`CX_NFUNC-1:0]       prs_stopped
    ,output   [`CX_NFUNC-1:0]       cfg_prs_enable
    ,output   [`CX_NFUNC-1:0]       cfg_prs_reset
    ,output   [`CX_NFUNC-1:0]       cfg_prs_stopped
    ,output   [`CX_NFUNC-1:0]       cfg_prs_uprgi
    ,output   [`CX_NFUNC-1:0]       cfg_prs_response_failure
    ,output   [(32*`CX_NFUNC)-1:0]  cfg_prs_outstanding_allocation

    ,output   [`CX_NFUNC-1:0]       cfg_br_ctrl_serren
    ,input    [31:0]                  slv_dbi_addr                   // address in DBI interface
    ,input    [31:0]                  slv_dbi_din                    // wire  data in DBI interface
    ,input                            slv_dbi_cs                     // Chip select to program configuration space registers
    ,input                            slv_dbi_cs2                    // Chip select2 wire  for DBI bus.  Used for changing
    ,input    [3:0]                   slv_dbi_wr                     // Byte write enable
    ,input    [`CX_NFUNC_WD-1:0]      slv_dbi_func_num               // Function number of the DBI access
    ,input    [2:0]                   slv_dbi_bar_num                // BAR number of the DBI access
    ,input                            slv_dbi_rom_access             // ROM BAR of the DBI access
    ,input                            slv_dbi_io_access              // IO BAR of the DBI access
    ,output                           slv_lbc_dbi_ack                // When asserted indicates that the read/write operation is completed.
    ,output   [31:0]                  slv_lbc_dbi_dout               // Register read back data bus
    ,output   [8:0]                          ras_prot_r_disable
    ,output   [6:0]                          ras_prot_t_disable
    ,input wire                              pm_aux_clk// Aux clock fed through pm_ctrl  
    ,input wire                              pm_aux_clk_active// aux_clk_active fed through pm_ctrl
    ,output  [`CX_REMOTE_LOOKUPID_WD-1:0] trgt_lookup_id_i

    // RASDP error mode indication from cdm registers
    ,output                           cfg_rasdp_error_mode_i
    ,output                           ras_error_tracer_pending
    ,output                           ras_dp_unc_err
    ,output                           ras_dp_cor_err
    ,output                           ras_ram_unc_err
    ,output                           ras_ram_cor_err
    ,input  ras_dp_err_log_t          axi_bridge_ras_dp_err_log
    ,output ras_dp_err_inj_t          out_ras_dp_err_inj
    ,output logic                     axi_bridge_in_ras_dp_err_inj_wake_up
    ,input  ras_dp_err_log_t          hdma_ras_dp_err_log
    ,output ras_dp_err_inj_t          hdma_ras_dp_err_inj
    ,output                           cfg_rasdp_error_mode_en

    ,output [15:0]                    cfg_err_resp
    ,output [15:0]                    cfg_order_rule_ctrl
    ,output [1:0]                     cfg_ax_mstr_ordr_p_event_sel
    ,output                           cfg_ax_snp_en
    ,output [`CX_NVC-1:0]             cfg_ib_p_id_mng_ctrl
    ,output [3:0]                     cfg_mstr_arcache_mode
    ,output [3:0]                     cfg_mstr_awcache_mode
    ,output [3:0]                     cfg_mstr_arcache_value
    ,output [3:0]                     cfg_mstr_awcache_value
    ,output [31:0]                    cfg_aximstr_msg_addr_high
    ,output [31:0]                    cfg_aximstr_msg_addr_low
    ,output [1:0]                     cfg_mstr_ardomain_mode
    ,output [1:0]                     cfg_mstr_awdomain_mode
    ,output [1:0]                     cfg_mstr_ardomain_value
    ,output [1:0]                     cfg_mstr_awdomain_value
    ,output                           cfg_ax_mstr_zeroread_fw
    ,output                           cfg_axi_clk_gating_en
    ,output                           int_radm_trgt1_mem_type
    ,output [5*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                   atu_reg_out_type
    ,output [`CX_NFUNC_WD*`CX_ATU_OUT_NREGIONS_MIN1-1:0]        atu_reg_out_func_num
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     atu_reg_out_func_bypass
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     atu_reg_out_snp
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     atu_reg_out_en
    ,output [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]atu_reg_out_base
    ,output [`CX_ATU_BASE_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_upr_base
    ,output [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]atu_reg_out_limit
    ,output [`CX_ATU_MAX_REGION_SIZE*`CX_ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_uppr_limit
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     atu_reg_out_incr_rgn_size
    ,output                                  crgb_cdm_cs
    ,input                                   crgb_cdm_ack
    ,output  [`CC_CRGB_ADDR_WIDTH - 1:0]     crgb_cdm_addr
    ,output  [`CC_CRGB_DATA_WIDTH - 1:0]     crgb_cdm_wdata
    ,input [`CC_CRGB_DATA_WIDTH - 1:0]       crgb_cdm_rdata
    ,output  [`CC_CRGB_BE_WIDTH   - 1:0]     crgb_cdm_wr
    ,output                                  crgb_cdm_source
    ,output [`CX_NVC-1:0]                   radm_trgt1_cpl_lookup_id_rlsd // Indicates to the received completion is the last one
    ,output                                 radm_trgt1_lookup_id_consmd
    ,input                              brdg_slv_flush_ack
    ,output                             rstctl_slv_flush_req
    ,output                             rstctl_mstr_flush_req
    ,output                             rstctl_flush_done
    ,output [2:0]                       pm_current_data_rate_others    // core ,output; reg pm_current_data_rate using core_clk to resolve massive fan-out issues
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_invert
    ,output [`CX_NFUNC-1:0] cfg_hp_slot_ctrl_access
    ,output [`CX_NFUNC-1:0] cfg_dll_state_chged_en
    ,output [`CX_NFUNC-1:0] cfg_cmd_cpled_int_en
    ,output [`CX_NFUNC-1:0] cfg_hp_int_en
    ,output [`CX_NFUNC-1:0] cfg_pre_det_chged_en
    ,output [`CX_NFUNC-1:0] cfg_mrl_sensor_chged_en
    ,output [`CX_NFUNC-1:0] cfg_pwr_fault_det_en
    ,output [`CX_NFUNC-1:0] cfg_atten_button_pressed_en
    ,output                  cfg_acs_validation_en
    ,output                  cfg_acs_at_blocking_en
    ,output   [`CX_NFUNC-1:0]cfg_acs_p2p_req_redirect_en
    ,output   [`CX_NFUNC-1:0]cfg_acs_p2p_compl_redirect_en
    ,output                  cfg_acs_up_forward_en
    ,output   [`CX_NFUNC-1:0]cfg_acs_p2p_egress_ctrl_en
    ,output   [`CX_NFUNC-1:0]cfg_acs_p2p_direct_transl_en
    ,output   [(`ACS_CTRL_VEC_WD*`CX_NFUNC)-1:0]  cfg_acs_egress_ctrl_vec
    ,output wire                          cfg_aspm_l1_timer_enable// CDM Control ASPM L1 Entry Timer
    ,output wire    [(`CX_NFUNC - 1) : 0] cfg_upd_aslk_pmctrl// CDM update of Active state link pmctrl
    ,output wire    [`CX_NFUNC-1:0]       cfg_upd_pme_cap// Update PME Capability field
    ,output                             rstctl_ltssm_enable
    ,output                             rstctl_core_flush_req
    ,output wire                                upstream_port
    ,output wire                                xdlh_xmt_pme_ack // Txmt ACK PME
    ,output wire                                xdlh_not_expecting_ack // Transmiter has received all its ACKs for all transmitted TLPs
    ,output wire                                smlh_in_l0
    ,output wire                                smlh_in_l1
    ,output wire                                smlh_in_l23
    ,output wire                                smlh_link_in_training // LTSSM is entering Recovery or Cfg 
    ,output ltssm_state_e                       smlh_ltssm_state_int
    ,output wire [(2*`CX_NFUNC)-1:0]            cfg_aslk_pmctrl// Active Link PM enable
    ,output wire [`CX_NFUNC-1:0]                cfg_upd_aux_pm_en// AUX Power PM enable
    ,output wire [`CX_NFUNC-1:0]                cfg_upd_pmcsr // PMCSR is written
    ,output wire [`CX_NFUNC-1:0]                cfg_pmstatus_clr// PM status bits are cleared
    ,output wire [(3*`CX_NFUNC)-1:0]            cfg_pmstate // PM state
    ,output wire [`CX_NFUNC-1:0]                cfg_pme_en// PME_Enable
    ,output wire [`CX_NFUNC-1:0]                cfg_aux_pm_en// aux power pm enable
    ,output wire                                cfg_clk_pm_en // enables the clock request# signal to be deasserted at L1 and L23 state
    ,output wire                                int_radm_pm_to_ack// Received PM TO ACK message (received by RC or downstream port)
    ,output wire [(5*`CX_NFUNC)-1:0]            cfg_pme_cap// PME Capability
    ,output wire [`CX_NL-1:0]                   rmlh_descrambled_even_parity // Current tx skip even data parity from RMLH
    ,output wire [`CX_NL-1:0]                   xmlh_scramble_even_parity // Current tx skip even data parity from XMLH
    ,output wire [1:0]                          pipe_aux_sync_p1_ack
    ,output wire [1:0]                          pipe_aux_sync_block
    ,output wire [`CX_L1SUB_CONTROL_WD-1:0]     cfg_l1sub_control //L1 substates control signal bus
    ,output wire [`CX_PL_L1SUB_CONTROL_WD-1:0]  cfg_pl_l1sub_control//Port Logic L1 Substates control signal bus
    ,output wire                                cfg_pl_l1_exit_mode// Port logic bit to control L1 exit mode
    ,output wire                                cfg_pl_l1_clk_sel// Port logic bit to select aux_clk source in L1
    ,output wire                                cfg_p2nobeacon_enable// Port logic bit to enable the support to P2.NoBeacon
    ,output wire [31:0]                         cfg_utility // Port Logic regsiter which is shadowed in pm_cfg block
    ,input wire [31:0]                          pm_cfg_utility// The utility shadow register is in turn shadowed in the port logic block
    ,output wire                                cfg_pipe_optional_pclkchange_hs // PIPE PCLK Change Optional Behaviour
    ,output wire                                cfg_phy_perst_on_warm_reset// PMC drive pm_req_phy_perst when warm reset
    ,output wire [17:0]                         cfg_phy_rst_timer// PHY RST timer
    ,output wire [5:0]                          cfg_pma_phy_rst_delay_timer// PMA reset to PIPE reset delay timer
    ,output wire [`CX_PL_AUX_CLK_FREQ_WD-1:0]          cfg_pl_aux_clk_freq// programmable auxiliary clock frequency
    ,output wire                                cfg_pl_gen3_zrxdc_noncompl// Gen3 Zrx-dc noncompliance bit (8 GT/s Rx Impedance ECN)
    ,output wire                                pme_to_ack_grt// PME Turnoff Ack request has been granted
    ,output wire                                lbc_active // The LBC may require a CPL to be sent stop L1 timer
    ,output wire [`CX_NFUNC-1:0]                pm_pme_grant // PM PME grant
    ,output wire                                pme_turn_off_grt // PM Turn Off grant
    ,output  wire                                xmlh_sris_enable
    ,output wire [`CX_NL-1:0]                  pre_serdes_pipe_turnoff_lanes
    ,output wire [(`CX_PHY_PDOWN_WD - 1) :0]   pre_mac_phy_powerdown
    ,output wire [`CX_NL*`CX_PHY_TXEI_WD-1:0]  int_mac_phy_txelecidle
    ,output wire [(`CX_PIPE_DATA_WD - 1):0]    pre_mac_phy_txdata
    ,output wire [`CX_NL-1:0]                  pre_mac_phy_txdetectrx_loopback
    ,output wire [`CX_NL-1:0]                  glue_mac_phy_txcompliance
    ,output wire [`CX_NL-1:0]                  pre_mac_phy_rxpolarity
    ,output wire [`CX_NL-1:0]                  tmp_mac_phy_rxpolarity
    ,output wire [(`CX_PHY_WIDTH_WD -1):0]     pre_mac_phy_width
    ,output wire                               pre_mac_phy_serdes_arch
    ,output wire [(`CX_PHY_WIDTH_WD -1):0]     pre_mac_phy_rxwidth
    ,output wire [`CX_NL-1:0]                  pre_serdes_pipe_rxready
    ,output wire [`PCLK_RATE_WD-1:0]           pre_mac_phy_pclk_rate
    ,output wire [`CX_NL-1:0]                  pre_mac_phy_rxstandby
    ,output wire [`CX_PHY_RATE_WD-1:0]         pre_mac_phy_rate
    ,output wire [`CX_PHY_TXDEEMPH_WD-1:0]     pre_mac_phy_txdeemph
    ,output wire [`CX_NL-1:0]                  pre_mac_phy_txdatavalid
    ,output wire [`CX_NL-1:0]                  pre_mac_phy_rxeqeval
    ,output wire [`CX_NL-1:0]                  pre_mac_phy_dirchange
    ,output wire [`CX_NL*`CX_TX_COEF_WD-1:0]   pre_mac_phy_smlh_coef_rtx
    ,output wire [`CX_NL*8-1:0]                pre_mac_phy_mbus
    ,input wire [`CX_NL-1:0]                   sqlchd_rxelecidle
    ,output wire    [7:0]                      int_cfg_pbus_num// Configured Primary bus number used to store for AUX power 
    ,output wire    [4:0]                      int_cfg_pbus_dev_num// Configured Device number used to store for AUX power
    ,output wire [`CX_L2NL-1:0]                smlh_lane_flip_ctrl
    ,output wire                               cfg_link_retrain // link retrain request
    ,output wire                               cfg_lpbk_en// loopback enable request
    ,output wire                               cfg_plreg_reset // port logic secondary reset
    ,output wire                               cfg_directed_speed_change      // config bit to start speed change
    ,output wire [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control // directed width change  (cfg_directed_width_change=cfg_pl_multilane_control[6])
    ,output wire                               msg_gen_unlock_grant// msg_gen grants unlock message
    ,input                                    edma_xfer_pending
    ,input  wire                              pm_ltssm_enable// The application enable for the LTSSM shadowed in the always on domain
    ,input  wire    [2:0]                     int_pm_current_data_rate// Current data rate shadowed in the always on domain 
    ,input wire [`CX_NL-1:0]                  pm_rmlh_descrambled_even_parity// Current rx skip even data parity shadowed in always on domain
    ,input wire [`CX_NL-1:0]                  pm_xmlh_scramble_even_parity// Current tx skip even data parity shadowed in always on domain
    ,output wire                              pm_smlh_l23_exit
    ,input  wire                              pm_xmt_turnoff// to send TURNOFF MSG TLP (only for downstream)
    ,input  wire [`CX_NFUNC-1:0]              pm_xmt_to_ack// to send PM_TO_ACK TLP (only for upstream port)
    ,input  wire [`CX_NFUNC-1:0]              pm_xmt_pme// to send PM_PME TLP
    ,input  wire                              pm_turnoff_timeout // Indicates to application of RC or downstream port of a swtich that PM turnoff timeout has occurred
    ,input wire [`CX_BUSNUM_WD -1:0]          pm_bus_num
    ,input wire [`CX_DEVNUM_WD -1:0]          pm_dev_num
    ,input wire [(`CX_PHY_PDOWN_WD - 1) : 0]  pm_int_phy_powerdown // PM PHY powerdown 2 LSB's for freq_step and pipe_loopback 
    ,input wire                               pm_current_powerdown_p1
    ,input wire                               pm_current_powerdown_p0
    ,input wire                               pm_smlh_l1_2_latched // 1: L1_SUB entered L1_2 substate
    ,input wire                               pm_smlh_l1_n_latched // 1: L1_SUB entered L1_n substate
    ,input   [2:0]                            pm_l1sub_state
    ,input wire                               pm_in_l11      // Level: L1.1 Entry for Ras D.E.S event counter
    ,input wire                               pm_in_l12      // Level: L1.2 Entry for Ras D.E.S event counter
    ,input wire                               pm_in_l1_short // Level: L1 short duration for Ras D.E.S event counter
    ,input wire                               pm_in_l1_cpm   // Level: L1 Clock PM (L1 with REFCLK removal/PLL Off) for Ras D.E.S event counter
    ,input wire                               pm_in_l1_abort // Level: L1.2 abort for Ras D.E.S event counter
    ,input wire                               pm_pme_resend_flag  // Level : PME Re-Send flag
    ,input wire                               pm_block_phystatus
    ,input wire [1:0]                         pm_en_pulse_det
    ,input wire                               pm_sys_aux_pwr_det// sys_aux_pwr_det fed through pm_ctrl
    ,input wire [`CX_NFUNC-1:0]               pm_pme_en_split// PM PME_EN register to be fed back internally in the core
    ,input wire [`CX_NFUNC-1:0]               pm_aux_pm_en_split// AUX PM EN split port
    ,input wire                               pm_init_rst // pm hot reset request
    ,input wire                               pm_unlock_msg_req// pm unlock message request
    ,input wire [`CX_L2NL - 1 : 0]            pm_rx_lane_flip_en
    ,input wire [`CX_L2NL - 1 : 0]            pm_tx_lane_flip_en
    ,input wire [`CX_L2NL - 1 : 0]            pm_rx_pol_lane_flip_ctrl
    ,input wire                               pm_smlh_link_retrain
    ,output wire                              trgt_cpl_lut_empty // TX PATH CPL LUT not empty
    ,output                            core_in_dpc
    ,output      [4:0]                 cfg_dpc_int_msg_num // DPC Interrupt Message Number
    ,output      [1:0]                 cfg_dpc_trig_en
    ,output                            cfg_dpc_cpl_cntrl
    ,output                            cfg_dpc_int_en
    ,output                            dpc_int
    ,output                            dpc_msi
    ,output                            cfg_dpc_err_cor_en
    ,output                            cfg_dpc_sw_trigger
    ,output                            cfg_dpc_poison_tlp_egr_block_en
    ,output                            cfg_dpc_dl_active_err_cor_en
    ,input      [4:0]                  app_dev_num
    ,input      [7:0]                  app_bus_num
    ,output wire                       msg_gen_hv
    ,output wire                       lbc_cpl_hv
    ,input wire  [`CX_NL-1:0]                 pm_latched_rxdetected
    ,output wire [`CX_NL-1:0]                 latched_rxdetected        // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
    ,input wire [(2*`CX_PHY_PDOWN_WD) - 1 : 0]pm_powerdown_status
    ,output wire                              cfg_force_powerdown
    ,output                                   cfg_uncor_internal_err_sts
    ,output                                   cfg_rcvr_overflow_err_sts
    ,output                                   cfg_fc_protocol_err_sts
    ,output                                   cfg_mlf_tlp_err_sts
    ,output                                   cfg_surprise_down_er_sts
    ,output                                   cfg_dl_protocol_err_sts
    ,output                                   cfg_ecrc_err_sts
    ,output                                   cfg_corrected_internal_err_sts
    ,output                                   cfg_replay_number_rollover_err_sts
    ,output                                   cfg_replay_timer_timeout_err_sts
    ,output                                   cfg_bad_dllp_err_sts
    ,output                                   cfg_bad_tlp_err_sts
    ,output                                   cfg_rcvr_err_sts
    ,output wire [5:0]                        cfg_link_capable// PL LINK_CAPABLE register indicate used lanes at reset
    ,output [`CX_NFUNC-1:0]                   cfg_advisory_nf_sts
    ,output [`CX_NFUNC-1:0]                   cfg_hdr_log_overflow_sts



    ,output                              rplh_flit_unrecognized_flit
    ,output                              rplh_flit_ecc_corr_err
    ,output                              rplh_flit_ecc_uncorr_err
    ,output                              rplh_flit_crc_uncorr_err
    ,output [5:0]                        cfg_neg_link_width
    ,output                              l0p_dynamic_rejected
    ,output                              cfg_l0p_dynamic_en
    ,output                              radm_slot_pwr_limit
    ,output  [31:0]                      radm_slot_pwr_payload
    ,output                              cxl_ltssm_enable
    ,output  [8 : 0]                     smlh_cxl_enabled
    ,output  [3:0]                       vlsm_mc_state
    ,output  [3:0]                       vlsm_io_state
    ,output                              cxl_s2m_data_pis
    ,output                              cxl_m2s_data_pis
    ,output                              cxl_h2d_data_pis
    ,output                              cxl_d2h_data_pis
    ,input                              vlsm_io_tx_pm_nak            // vLSM.io transmit Status(Active.PMNAK) ALMP
    ,input                              vlsm_mc_tx_pm_nak            // vLSM.mc transmit Status(Active.PMNAK) ALMP
    ,output                             vlsm_io_rx_pm_nak            // vLSM.io received Status(Active.PMNAK) ALMP
    ,output                             vlsm_mc_rx_pm_nak            // vLSM.mc received Status(Active.PMNAK) ALMP
    ,output                             vlsm_io_rx_pm_req            // vLSM.io PM Request ALMP received
    ,output                             vlsm_mc_rx_pm_req            // vLSM.mc PM Request ALMP received
    ,output                             vlsm_io_pm_timeout           // vLSM.io PM Request ALMP timeout
    ,output                             vlsm_mc_pm_timeout           // vLSM.mc PM Request ALMP timeout
    ,input                              cxl_viral_request
    ,output                             cxl_viral_status
    ,output                             cxl_viral_enable

    ///////////////////////////////////////////////////////
    // trgt1 p interfaces
    ,output                             radm_trgt1_p_0_pending
    ,output                             radm_trgt1_p_0_rom_in_range
    ,output                             radm_trgt1_p_0_io_req_in_range
    ,output   [2:0]                     radm_trgt1_p_0_in_membar_range
    ,output    [2:0]                    radm_trgt1_p_0_cpl_status
    ,output   [`TRGT_DATA_WD-1:0]       radm_trgt1_p_0_data
    ,output   [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0] radm_trgt1_p_0_hdr_prot
    ,output   [`CX_PRFX_W_PAR-1:0]      radm_trgt1_p_0_prfx
    ,output   [`CX_NW-1:0]              radm_trgt1_p_0_dwen
    ,output                             radm_trgt1_p_0_dv
    ,output                             radm_trgt1_p_0_hv
    ,output                             radm_trgt1_p_0_eot
    ,output                             radm_trgt1_p_0_tlp_abort
    ,output                             radm_trgt1_p_0_dllp_abort
    ,output                             radm_trgt1_p_0_ecrc_err
    ,output  [1:0]                      radm_trgt1_p_0_fmt
    ,output  [4:0]                      radm_trgt1_p_0_type
    ,output  [2:0]                      radm_trgt1_p_0_tc
    ,output  [`FLT_Q_ATTR_WIDTH-1:0]    radm_trgt1_p_0_attr
    ,output   [15:0]                    radm_trgt1_p_0_reqid
    ,output   [`CX_TAG_SIZE-1:0]        radm_trgt1_p_0_tag
    ,output   [`CX_NFUNC_WD-1:0]        radm_trgt1_p_0_func_num
    ,output                             radm_trgt1_p_0_td
    ,output                             radm_trgt1_p_0_poisoned
    ,output   [9:0]                     radm_trgt1_p_0_dw_len
    ,output   [3:0]                     radm_trgt1_p_0_first_be
    ,output    [`CX_NVC_LOG2-1:0]       radm_trgt1_p_0_vc_num
    ,output   [`FLT_Q_ADDR_WIDTH-1:0]   radm_trgt1_p_0_addr
    ,output   [`FLT_Q_ADDR_WIDTH-1:0]   radm_trgt1_p_0_hdr_uppr_bytes
    ,output   [3:0]                     radm_trgt1_p_0_last_be
    ,output   [1:0]                     radm_trgt1_p_0_ats
    ,output                             radm_trgt1_p_0_nw
    ,output                             radm_trgt1_p_0_th
    ,output   [1:0]                     radm_trgt1_p_0_ph
    ,output   [7:0]                     radm_trgt1_p_0_st
    ,output                             radm_trgt1_p_0_hdr_uppr_bytes_valid
    ,output  [8:0]                      radm_trgt1_p_0_dest_sgmt
    ,output  [8:0]                      radm_trgt1_p_0_reqtr_sgmt
    ,output  [`CX_RADM_PKT_ORD_WD-1:0]  radm_trgt1_p_0_pkt_order_no
    ,output [`CX_ATU_IN_NREGIONS_MIN1-1:0]radm_trgt1_p_0_atu_sloc_match
    ,output [`CX_ATU_IN_NREGIONS_MIN1-1:0]radm_trgt1_p_0_atu_cbuf_err
    ////////////////////////////////////////////
    // trgt1 np interfaces
    ,output    [2:0]                     radm_trgt1_np_0_cpl_status
    ,output                              radm_trgt1_np_0_rom_in_range
    ,output                              radm_trgt1_np_0_io_req_in_range
    ,output    [2:0]                     radm_trgt1_np_0_in_membar_range
    ,output   [`TRGT_DATA_WD-1:0]        radm_trgt1_np_0_data
    ,output    [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0] radm_trgt1_np_0_hdr_prot
    ,output    [`CX_PRFX_W_PAR-1:0]      radm_trgt1_np_0_prfx
    ,output    [`CX_NW-1:0]              radm_trgt1_np_0_dwen
    ,output                              radm_trgt1_np_0_dv
    ,output                              radm_trgt1_np_0_hv
    ,output                              radm_trgt1_np_0_eot
    ,output                              radm_trgt1_np_0_dllp_abort
    ,output                              radm_trgt1_np_0_tlp_abort
    ,output                              radm_trgt1_np_0_ecrc_err
    ,output   [1:0]                      radm_trgt1_np_0_fmt
    ,output   [4:0]                      radm_trgt1_np_0_type
    ,output   [2:0]                      radm_trgt1_np_0_tc
    ,output   [`FLT_Q_ATTR_WIDTH-1:0]    radm_trgt1_np_0_attr
    ,output    [15:0]                    radm_trgt1_np_0_reqid
    ,output    [`CX_TAG_SIZE-1:0]        radm_trgt1_np_0_tag
    ,output    [`CX_NFUNC_WD-1:0]        radm_trgt1_np_0_func_num
    ,output                              radm_trgt1_np_0_td
    ,output                              radm_trgt1_np_0_poisoned
    ,output    [9:0]                     radm_trgt1_np_0_dw_len
    ,output    [3:0]                     radm_trgt1_np_0_first_be
    ,output   [`CX_NVC_LOG2-1:0]         radm_trgt1_np_0_vc_num
    ,output    [`FLT_Q_ADDR_WIDTH-1:0]   radm_trgt1_np_0_addr
    ,output    [`FLT_Q_ADDR_WIDTH-1:0]   radm_trgt1_np_0_hdr_uppr_bytes
    ,output    [3:0]                     radm_trgt1_np_0_last_be
    ,output    [1:0]                     radm_trgt1_np_0_ats
    ,output                              radm_trgt1_np_0_nw
    ,output                              radm_trgt1_np_0_cxlsrc
    ,output                              radm_trgt1_np_0_th
    ,output    [1:0]                     radm_trgt1_np_0_ph
    ,output    [7:0]                     radm_trgt1_np_0_st
    ,output                              radm_trgt1_np_0_hdr_uppr_bytes_valid
    ,output   [8:0]                      radm_trgt1_np_0_reqtr_sgmt
    ,output   [8:0]                      radm_trgt1_np_0_dest_sgmt
    ,output   [`CX_RADM_PKT_ORD_WD-1:0]  radm_trgt1_np_0_pkt_order_no
    ,output   [`CX_ATU_IN_NREGIONS_MIN1-1:0] radm_trgt1_np_0_atu_sloc_match
    ,output [`CX_ATU_IN_NREGIONS_MIN1-1:0]   radm_trgt1_np_0_atu_cbuf_err

    //////////////////////////////////////////
    // trgt1 CPL interface
    //
    ,output    [2:0]                     radm_trgt1_cpl_0_status
    ,output    [`TRGT_DATA_WD-1:0]       radm_trgt1_cpl_0_data
    ,output    [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0] radm_trgt1_cpl_0_hdr_prot
    ,output    [`CX_PRFX_W_PAR-1:0]      radm_trgt1_cpl_0_prfx
    ,output    [`CX_NW-1:0]              radm_trgt1_cpl_0_dwen
    ,output                              radm_trgt1_cpl_0_dv
    ,output                              radm_trgt1_cpl_0_hv
    ,output                              radm_trgt1_cpl_0_eot
    ,output                              radm_trgt1_cpl_0_dllp_abort
    ,output                              radm_trgt1_cpl_0_tlp_abort
    ,output                              radm_trgt1_cpl_0_ecrc_err
    ,output   [1:0]                      radm_trgt1_cpl_0_fmt
    ,output   [4:0]                      radm_trgt1_cpl_0_type
    ,output   [2:0]                      radm_trgt1_cpl_0_tc
    ,output   [`FLT_Q_ATTR_WIDTH-1:0]    radm_trgt1_cpl_0_attr
    ,output    [15:0]                    radm_trgt1_cpl_0_reqid
    ,output    [`CX_TAG_SIZE-1:0]        radm_trgt1_cpl_0_tag
    ,output    [`CX_NFUNC_WD-1:0]        radm_trgt1_cpl_0_func_num
    ,output                              radm_trgt1_cpl_0_td
    ,output                              radm_trgt1_cpl_0_poisoned
    ,output    [9:0]                     radm_trgt1_cpl_0_dw_len
    ,output                              radm_trgt1_cpl_0_bcm
    ,output    [11:0]                    radm_trgt1_cpl_0_byte_cnt
    ,output    [15:0]                    radm_trgt1_cpl_0_cmpltr_id
    ,output                              radm_trgt1_cpl_0_last
    ,output    [`CX_NVC_LOG2-1:0]        radm_trgt1_cpl_0_vc_num
    ,output [`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0]   radm_trgt1_cpl_0_addr
    ,output   [8:0]                      radm_trgt1_cpl_0_dest_sgmt
    ,output   [7:0]                      radm_trgt1_cpl_0_cpl_sgmt
    ,output    [`CX_RADM_PKT_ORD_WD -1 :0] radm_trgt1_cpl_0_p_pkt_order_no
    // -------------------------------------------------------------------------------------
    // CXL Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,input                               cxl_clk
    ,input                               cxl_rst_n
// spyglass disable_block Topology_02
// SMD: Direct connection from ,input port to ,output port
// SJ: RAM-based FIFO is implemented to buffer data on Data Message Channels which propagates data to RAM data inputs
    // -------------------------------------------------------------------------------------
    // CXL Protocol Master RX Cache Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,output                                                  cxl_cache_mst_req
    ,input                                                   cxl_cache_mst_ack
    // -------------------------------------------------------------------------------------
    // CXL Protocol Slave TX Cache Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,input                                                   cxl_cache_slv_req
    ,output                                                  cxl_cache_slv_ack
    ,input                                                   cxl_cache_app_pending
    // -------------------------------------------------------------------------------------
    // CXL.Cache Host Master (Root Complex RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,input  [`CX_CXL_CACHE_H2D_REQ_IFNUM-1:0]                                    cxl_mst_h2d_req_crd
    ,input  [`CX_CXL_CACHE_H2D_RESP_IFNUM-1:0]                                   cxl_mst_h2d_rsp_crd
    ,input  [`CX_CXL_CACHE_H2D_DATA_IFNUM-1:0]                                   cxl_mst_h2d_data_crd
    ,output [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_SIZE)-1:0]       cxl_mst_h2d_req
    ,output [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_SIZE)-1:0]     cxl_mst_h2d_rsp
    ,output [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_SIZE)-1:0]     cxl_mst_h2d_data
    ,output [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_CHK_SIZE)-1:0]   cxl_mst_h2d_req_chk
    ,output [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_CHK_SIZE)-1:0] cxl_mst_h2d_rsp_chk
    ,output [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_CHK_SIZE)-1:0] cxl_mst_h2d_data_chk
    // -------------------------------------------------------------------------------------
    // CXL.Cache Device Slave (Endpoint TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,output [`CX_CXL_CACHE_D2H_REQ_IFNUM-1:0]                                    cxl_slv_d2h_req_crd
    ,output [`CX_CXL_CACHE_D2H_RESP_IFNUM-1:0]                                   cxl_slv_d2h_rsp_crd
    ,output [`CX_CXL_CACHE_D2H_DATA_IFNUM-1:0]                                   cxl_slv_d2h_data_crd
    ,input  [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_SIZE)-1:0]       cxl_slv_d2h_req
    ,input  [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_SIZE)-1:0]     cxl_slv_d2h_rsp
    ,input  [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_SIZE)-1:0]     cxl_slv_d2h_data
    ,input [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_CHK_SIZE)-1:0]    cxl_slv_d2h_req_chk
    ,input [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_CHK_SIZE)-1:0]  cxl_slv_d2h_rsp_chk
    ,input [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_CHK_SIZE)-1:0]  cxl_slv_d2h_data_chk
    // -------------------------------------------------------------------------------------
    // CXL.Cache Host Slave (Root Complex TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,output [`CX_CXL_CACHE_H2D_REQ_IFNUM-1:0]                                    cxl_slv_h2d_req_crd
    ,output [`CX_CXL_CACHE_H2D_RESP_IFNUM-1:0]                                   cxl_slv_h2d_rsp_crd
    ,output [`CX_CXL_CACHE_H2D_DATA_IFNUM-1:0]                                   cxl_slv_h2d_data_crd
    ,input  [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_SIZE)-1:0]       cxl_slv_h2d_req
    ,input  [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_SIZE)-1:0]     cxl_slv_h2d_rsp
    ,input  [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_SIZE)-1:0]     cxl_slv_h2d_data
    ,input  [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_CHK_SIZE)-1:0]   cxl_slv_h2d_req_chk
    ,input  [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_CHK_SIZE)-1:0] cxl_slv_h2d_rsp_chk
    ,input  [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_CHK_SIZE)-1:0] cxl_slv_h2d_data_chk
    // -------------------------------------------------------------------------------------
    // CXL.Cache Device Master (Endpoint RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,input [`CX_CXL_CACHE_D2H_REQ_IFNUM-1:0]                                     cxl_mst_d2h_req_crd
    ,input [`CX_CXL_CACHE_D2H_RESP_IFNUM-1:0]                                    cxl_mst_d2h_rsp_crd
    ,input [`CX_CXL_CACHE_D2H_DATA_IFNUM-1:0]                                    cxl_mst_d2h_data_crd
    ,output [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_SIZE)-1:0]       cxl_mst_d2h_req
    ,output [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_SIZE)-1:0]     cxl_mst_d2h_rsp
    ,output [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_SIZE)-1:0]     cxl_mst_d2h_data
    ,output [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_CHK_SIZE)-1:0]   cxl_mst_d2h_req_chk
    ,output [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_CHK_SIZE)-1:0] cxl_mst_d2h_rsp_chk
    ,output [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_CHK_SIZE)-1:0] cxl_mst_d2h_data_chk
    // -------------------------------------------------------------------------------------
    // CXL Protocol Master RX Mem Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,output                                                  cxl_mem_mst_req
    ,input                                                   cxl_mem_mst_ack
    // -------------------------------------------------------------------------------------
    // CXL Protocol Slave TX Mem Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,input                                                   cxl_mem_slv_req
    ,output                                                  cxl_mem_slv_ack
    ,input                                                   cxl_mem_app_pending
    // -------------------------------------------------------------------------------------
    // CXL.Mem Host Master (Root Complex RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,input  [`CX_CXL_MEM_M2S_NDR_IFNUM-1:0]                                      cxl_mst_m2s_req_crd
    ,input  [`CX_CXL_MEM_M2S_DATA_IFNUM-1:0]                                     cxl_mst_m2s_rwd_crd
    ,output [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_SIZE)-1:0]           cxl_mst_m2s_req
    ,output [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_SIZE)-1:0]         cxl_mst_m2s_rwd
    ,output [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_CHK_SIZE)-1:0]       cxl_mst_m2s_req_chk
    ,output [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_CHK_SIZE)-1:0]     cxl_mst_m2s_rwd_chk
    // -------------------------------------------------------------------------------------
    // CXL.Mem Device Slave (Endpoint TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,output [`CX_CXL_MEM_S2M_NDR_IFNUM-1:0]                                      cxl_slv_s2m_ndr_crd
    ,output [`CX_CXL_MEM_S2M_DATA_IFNUM-1:0]                                     cxl_slv_s2m_drc_crd
    ,input  [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_SIZE)-1:0]           cxl_slv_s2m_ndr
    ,input  [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_SIZE)-1:0]         cxl_slv_s2m_drc
    ,input  [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_CHK_SIZE)-1:0]       cxl_slv_s2m_ndr_chk
    ,input  [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_CHK_SIZE)-1:0]     cxl_slv_s2m_drc_chk
    // -------------------------------------------------------------------------------------
    // CXL.Mem Host Slave (Root Complex TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,output [`CX_CXL_MEM_M2S_NDR_IFNUM-1:0]                                      cxl_slv_m2s_req_crd
    ,output [`CX_CXL_MEM_M2S_DATA_IFNUM-1:0]                                     cxl_slv_m2s_rwd_crd
    ,input  [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_SIZE)-1:0]           cxl_slv_m2s_req
    ,input  [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_SIZE)-1:0]         cxl_slv_m2s_rwd
    ,input  [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_CHK_SIZE)-1:0]       cxl_slv_m2s_req_chk
    ,input  [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_CHK_SIZE)-1:0]     cxl_slv_m2s_rwd_chk
    // -------------------------------------------------------------------------------------
    // CXL.Mem Device Master (Endpoint RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,input  [`CX_CXL_MEM_S2M_NDR_IFNUM-1:0]                                      cxl_mst_s2m_ndr_crd
    ,input  [`CX_CXL_MEM_S2M_DATA_IFNUM-1:0]                                     cxl_mst_s2m_drc_crd
    ,output [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_SIZE)-1:0]           cxl_mst_s2m_ndr
    ,output [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_SIZE)-1:0]         cxl_mst_s2m_drc
    ,output [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_CHK_SIZE)-1:0]       cxl_mst_s2m_ndr_chk
    ,output [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_CHK_SIZE)-1:0]     cxl_mst_s2m_drc_chk
// spyglass enable_block Topology_02
    ,output [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_SIZE)-1:0]     cxl_mst_m2s_bi_rsp
    ,input  [`CX_CXL_MEM_M2S_BI_RSP_IFNUM-1:0]                                   cxl_mst_m2s_bi_rsp_crd
    ,output [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE)-1:0] cxl_mst_m2s_bi_rsp_chk
    ,input  [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_SIZE)-1:0]     cxl_slv_s2m_bi_snp
    ,output [`CX_CXL_MEM_S2M_BI_SNP_IFNUM-1:0]                                   cxl_slv_s2m_bi_snp_crd
    ,input [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE)-1:0]  cxl_slv_s2m_bi_snp_chk
    ,input [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_SIZE)-1:0]      cxl_slv_m2s_bi_rsp
    ,output [`CX_CXL_MEM_M2S_BI_RSP_IFNUM-1:0]                                   cxl_slv_m2s_bi_rsp_crd
    ,input [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE)-1:0]  cxl_slv_m2s_bi_rsp_chk
    ,output [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_SIZE)-1:0]     cxl_mst_s2m_bi_snp
    ,input [`CX_CXL_MEM_S2M_BI_SNP_IFNUM-1:0]                                    cxl_mst_s2m_bi_snp_crd
    ,output [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE)-1:0] cxl_mst_s2m_bi_snp_chk
    // -------------------------------------------------------------------------------------
    // CXL Controller RAS Statistics Interface Signals
    // -------------------------------------------------------------------------------------
    ,input [1:0]                                             cxl_ras_stat_rx_corr
    ,input [7:0]                                             cxl_ras_stat_rx_uncorr
    ,input [`CX_CXL_RAS_HDR_LOG_SIZE-1:0]                    cxl_ras_stat_rx_hdr_log
    // -------------------------------------------------------------------------------------
    // Control Signals from the CXL Flex Bus Device DVSEC
    // -------------------------------------------------------------------------------------
    ,output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_mem_enable
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range1_mem_size_high
    ,output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range1_mem_info_valid
    ,output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range1_mem_active
    ,output [(`CX_CXL_NLD_PLUS_1*5)-1:0]                                 cfg_cxl_dev_range1_desired_interleave
    ,output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range1_mem_size_low
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range1_mem_base_high
    ,output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range1_mem_base_low
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range2_mem_size_high
    ,output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range2_mem_info_valid
    ,output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range2_mem_active
    ,output [(`CX_CXL_NLD_PLUS_1*5)-1:0]                                 cfg_cxl_dev_range2_desired_interleave
    ,output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range2_mem_size_low
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range2_mem_base_high
    ,output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range2_mem_base_low
    ,output                                                              cfg_cxl_dev_cache_enable
    ,output [4:0]                                                        cfg_cxl_dev_cache_sf_coverage
    ,output [2:0]                                                        cfg_cxl_dev_cache_sf_granularity
    ,output                                                              cfg_cxl_dev_cache_clean_eviction
    // -------------------------------------------------------------------------------------
    // CXL 2.0 Device DVSEC control signals
    // -------------------------------------------------------------------------------------
    ,output                              cfg_cxl_dev_disable_caching
    ,output                              cfg_cxl_dev_initiate_cache_wr_invld
    ,input                               cxl_dev_cache_invalid
    ,input                               cxl_dev_cache_wr_invld_cmpl
    ,output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_cold_rst_volatile_hdm_default
    ,output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_warm_rst_volatile_hdm_default
    ,output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_hot_rst_volatile_hdm_default
    ,output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_hot_rst_volatile_hdm_desired
    ,input  [`CX_CXL_NLD_PLUS_1-1:0]     cxl_volatile_hdm_error
    ,input                               cxl_pm_init_cmpl
    // -------------------------------------------------------------------------------------
    // CXL Error Status Signals
    // -------------------------------------------------------------------------------------
    ,output [6:0]                                                        cfg_cxl_mbar0_corr_err
    ,output [16:0]                                                       cfg_cxl_mbar0_uncorr_err
    ,output [31:0]                                                       cfg_cxl_pl_reg_fatal_err
    // -------------------------------------------------------------------------------------
    // Signals from the CXL 2.0 Extension DVSEC Register
    // -------------------------------------------------------------------------------------
    ,output [3:0]                                                         cfg_cxl_2_0_ext_port_ctl_ovr
    ,output [7:0]                                                         cfg_cxl_2_0_ext_alt_bus_base
    ,output [7:0]                                                         cfg_cxl_2_0_ext_alt_bus_limit
    ,output [11:0]                                                        cfg_cxl_2_0_ext_alt_mem_base
    ,output [11:0]                                                        cfg_cxl_2_0_ext_alt_mem_limit
    ,output [11:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_base
    ,output [11:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_limit
    ,output [31:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_base_high
    ,output [31:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_limit_high
    ,output                                                               cfg_cxl_2_0_ext_rcrb_en
    ,output [18:0]                                                        cfg_cxl_2_0_ext_rcrb_base_addr_low
    ,output [31:0]                                                        cfg_cxl_2_0_ext_rcrb_base_addr_high
    // -------------------------------------------------------------------------------------
    // Signals from the CXL 2.0 Register Locator DVSEC Register
    // -------------------------------------------------------------------------------------
    ,output [(`CX_CXL_NLD_PLUS_1*3)-1:0]                                  cfg_cxl_reg_locator_reg1_bir
    ,output [(`CX_CXL_NLD_PLUS_1*8)-1:0]                                  cfg_cxl_reg_locator_reg1_blk_identifier
    ,output [(`CX_CXL_NLD_PLUS_1*16)-1:0]                                 cfg_cxl_reg_locator_reg1_blk_offset_low
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                 cfg_cxl_reg_locator_reg1_blk_offset_high
    ,output [(`CX_CXL_NLD_PLUS_1*3)-1:0]                                  cfg_cxl_reg_locator_reg2_bir
    ,output [(`CX_CXL_NLD_PLUS_1*8)-1:0]                                  cfg_cxl_reg_locator_reg2_blk_identifier
    ,output [(`CX_CXL_NLD_PLUS_1*16)-1:0]                                 cfg_cxl_reg_locator_reg2_blk_offset_low
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                 cfg_cxl_reg_locator_reg2_blk_offset_high
    ,output [(`CX_CXL_NLD_PLUS_1*3)-1:0]                                  cfg_cxl_reg_locator_reg3_bir
    ,output [(`CX_CXL_NLD_PLUS_1*8)-1:0]                                  cfg_cxl_reg_locator_reg3_blk_identifier
    ,output [(`CX_CXL_NLD_PLUS_1*16)-1:0]                                 cfg_cxl_reg_locator_reg3_blk_offset_low
    ,output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                 cfg_cxl_reg_locator_reg3_blk_offset_high
    // -------------------------------------------------------------------------------------
    // Signals from the CXL Port GPF DVSEC Register
    // -------------------------------------------------------------------------------------
    ,output [3:0]                                                          cfg_cxl_gpf_port_p1_timeout_base
    ,output [3:0]                                                          cfg_cxl_gpf_port_p1_timeout_scale
    ,output [3:0]                                                          cfg_cxl_gpf_port_p2_timeout_base
    ,output [3:0]                                                          cfg_cxl_gpf_port_p2_timeout_scale
    // -------------------------------------------------------------------------------------
    // CXL Retry Buffer RAM Interface
    // -------------------------------------------------------------------------------------
    ,output [(`CX_CXL_RBUF_RAM_ADDRW - 1) : 0]   cxl_rbuf_ram_addr
    ,output                                      cxl_rbuf_ram_addr_par
    ,output                                      cxl_rbuf_ram_en
    ,output                                      cxl_rbuf_ram_we
    ,output [(`CX_CXL_RBUF_RAM_DATAW - 1) : 0]   cxl_rbuf_ram_wdata
    ,input  [(`CX_CXL_RBUF_RAM_DATAW - 1) : 0]   cxl_rbuf_ram_rdata
    ,output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]                                      cxl_mst_hreq_drsp_ram_we
    ,output [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW)-1 : 0] cxl_mst_hreq_drsp_ram_wr_addr
    ,output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]                                      cxl_mst_hreq_drsp_ram_wr_addr_par
    ,output [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_DATAW)-1 : 0] cxl_mst_hreq_drsp_ram_wdata
    ,output [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW)-1 : 0] cxl_mst_hreq_drsp_ram_rd_addr
    ,output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]                                      cxl_mst_hreq_drsp_ram_rd_addr_par
    ,output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]                                      cxl_mst_hreq_drsp_ram_rd
    ,input  [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_DATAW)-1 : 0] cxl_mst_hreq_drsp_ram_rdata
    ,output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                                      cxl_mst_hrsp_dreq_ram_we
    ,output [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW)-1 : 0] cxl_mst_hrsp_dreq_ram_wr_addr
    ,output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                                      cxl_mst_hrsp_dreq_ram_wr_addr_par
    ,output [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_DATAW)-1 : 0] cxl_mst_hrsp_dreq_ram_wdata
    ,output [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW)-1 : 0] cxl_mst_hrsp_dreq_ram_rd_addr
    ,output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                                      cxl_mst_hrsp_dreq_ram_rd_addr_par
    ,output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                                      cxl_mst_hrsp_dreq_ram_rd 
    ,input  [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_DATAW)-1 : 0] cxl_mst_hrsp_dreq_ram_rdata
    ,output [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                         cxl_mst_hd_data_ram_we
    ,output [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_ADDRW-1) : 0]       cxl_mst_hd_data_ram_wr_addr
    ,output  [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                        cxl_mst_hd_data_ram_wr_addr_par
    ,output [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_DATAW-1) : 0]       cxl_mst_hd_data_ram_wdata
    ,output [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_ADDRW-1) : 0]       cxl_mst_hd_data_ram_rd_addr
    ,output [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                         cxl_mst_hd_data_ram_rd_addr_par
    ,output [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                         cxl_mst_hd_data_ram_rd
    ,input  [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_DATAW-1) : 0]       cxl_mst_hd_data_ram_rdata
    ,output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                           cxl_mst_ms_ndr_ram_we
    ,output [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_ADDRW)-1 : 0]          cxl_mst_ms_ndr_ram_wr_addr
    ,output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                           cxl_mst_ms_ndr_ram_wr_addr_par
    ,output [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_DATAW)-1 : 0]          cxl_mst_ms_ndr_ram_wdata
    ,output [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_ADDRW)-1 : 0]          cxl_mst_ms_ndr_ram_rd_addr
    ,output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                           cxl_mst_ms_ndr_ram_rd_addr_par
    ,output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                           cxl_mst_ms_ndr_ram_rd
    ,input  [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_DATAW)-1 : 0]          cxl_mst_ms_ndr_ram_rdata
    ,output [`CX_CXL_MST_MS_DDATA_RAM_NUM-1:0]                                         cxl_mst_ms_data_ram_we
    ,output [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_ADDRW-1) : 0]       cxl_mst_ms_data_ram_wr_addr
    ,output  [`CX_CXL_MST_MS_DDATA_RAM_NUM-1 :0]                                       cxl_mst_ms_data_ram_wr_addr_par
    ,output [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_DATAW-1) : 0]       cxl_mst_ms_data_ram_wdata
    ,output [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_ADDRW-1) : 0]       cxl_mst_ms_data_ram_rd_addr
    ,output [`CX_CXL_MST_MS_DDATA_RAM_NUM-1:0]                                         cxl_mst_ms_data_ram_rd_addr_par
    ,output [`CX_CXL_MST_MS_DDATA_RAM_NUM-1:0]                                         cxl_mst_ms_data_ram_rd
    ,input  [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_DATAW-1) : 0]       cxl_mst_ms_data_ram_rdata
// spyglass disable_block Topology_02
// SMD: Direct connection from input port to output port
// SJ: RAM-based FIFO is implemented to buffer data on Data Message Channels which propagates data to RAM data inputs
    ,output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                            cxl_mst_ms_bi_ram_we
    ,output [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_ADDRW)-1 : 0]          cxl_mst_ms_bi_ram_wr_addr
    ,output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                            cxl_mst_ms_bi_ram_wr_addr_par
    ,output [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_DATAW)-1 : 0]          cxl_mst_ms_bi_ram_wdata
    ,output [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_ADDRW)-1 : 0]          cxl_mst_ms_bi_ram_rd_addr
    ,output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                            cxl_mst_ms_bi_ram_rd_addr_par
    ,output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                            cxl_mst_ms_bi_ram_rd
    ,input [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_DATAW)-1 : 0]           cxl_mst_ms_bi_ram_rdata
// spyglass enable_block Topology_02

    ,output wire                               int_cfg_upd_req_id
    ,output wire    [2:0]                      current_data_rate          // 0=running at gen1 speeds 1=running at gen2 speed 2-gen3 3-gen4...

    ,input wire                               pm_pclkack_timeout
 ////SPIF interface for CXL.cachemem/CXL_ARBMUX //////////
 ////SPIF interface for CXL.IO/PCIE//////////
);

// ------------------------------------------------------------------------------------------
// Internal Signals 
// ------------------------------------------------------------------------------------------

wire                 xadm_tlp_pending;   // XADM has no TLP pending in its datapath 
wire                 xaim_tlp_pending;   // XAIM has TLP Pending
wire                 xdlh_nodllp_pending; // XDLH has no dllp pending
wire                 smlh_in_l0s;
wire                 smlh_in_rl0s;
wire                 cfg_pl_l1_nowait_p1;// Port logic bit to control L1 entry mode
wire [2:0]           cfg_l0s_entr_latency_timer; // L0s enter latency
wire [2:0]           cfg_l1_entr_latency_timer;// L1 enter latency
wire                 cfg_l1_entr_wo_rl0s;// Start L1 timer without rL0s
wire [`CX_NVC-1:0]   xadm_had_enough_credit; // XTLH had enough credit
wire [`CX_NVC-1:0]   xadm_no_fc_credit;// XTLH has no FC credits available
wire                 radm_pm_asnak;// Received PM AS NAK  (only upstream port)
wire                 radm_trgt0_pending;// A TLP is enroute to TRGT0 delay L1 entry
wire [3:0]           cfg_dsp_pcipm_l1_enter_delay; // PCIPM L1 entry delay
wire                 msg_gen_asnak_grt;
wire                 pm_l1_aspm_entr;
wire                 pm_xmt_asnak;// to send AS_NAK MSG TLP  (only for upstream port)
wire                 pm_smlh_l1_exit;
wire                 pm_prot_req_l2;  // PM Protocol FSM requests Link Layer to enter L2
usp_prot_fsm_state_e pm_usp_prot_state;
dsp_prot_fsm_state_e pm_dsp_prot_state;
pm_active_l0s_fsm_e  pm_l0s_state;

ltssm_cxl_enable_t            ltssm_cxl_enable;

//wire declaration
link_adm_if_t        pcie_link_adm_if;   // SPIF: PCIe Link Layer to ADM Interface

   spif_if      b_cfgi_lbc_pcie();
   spif_if      b_cfgi_lbc_cxl();

protocol_cfg_t                     cxl_protocol_cfg;       // Protocol Configuration for CXL Controller
DWC_cxl_cdmregs_if                 b_cxl_cdm ();
wire                               mac_phy_ltssm_link_synchdr_bypass_enabled;
wire                               mac_phy_cfg_cxl_port_drift_buffer_enabled;
wire                               cxl_link_enable;
assign                             smlh_cxl_enabled = {ltssm_cxl_enable.cxl_throttle_required,
                                                       ltssm_cxl_enable.cxl_lopt_flit_enabled,
                                                       ltssm_cxl_enable.cxl_pbr_flit_enabled,
                                                       ltssm_cxl_enable.cxl_mld_enabled,
                                                       ltssm_cxl_enable.cxl_68B_flit_vh_enabled,
                                                       ltssm_cxl_enable.cache_enabled,
                                                       ltssm_cxl_enable.mem_enabled,
                                                       ltssm_cxl_enable.io_enabled, 
                                                       cxl_link_enable};




assign   cfg_cxl_dev_cache_enable         = b_cxl_cdm.s_cfg_cxl_dev_cache_enable;
assign   cfg_cxl_dev_cache_sf_coverage    = b_cxl_cdm.s_cfg_cxl_dev_cache_sf_coverage;
assign   cfg_cxl_dev_cache_sf_granularity = b_cxl_cdm.s_cfg_cxl_dev_cache_sf_granularity;
assign   cfg_cxl_dev_cache_clean_eviction = b_cxl_cdm.s_cfg_cxl_dev_cache_clean_eviction;

assign   cfg_cxl_dev_mem_enable                = b_cxl_cdm.s_cfg_cxl_dev_mem_enable;
assign   cfg_cxl_dev_range1_mem_size_high      = b_cxl_cdm.s_cfg_cxl_dev_range1_mem_size_high;
assign   cfg_cxl_dev_range1_mem_info_valid     = b_cxl_cdm.s_cfg_cxl_dev_range1_mem_info_valid;
assign   cfg_cxl_dev_range1_mem_active         = b_cxl_cdm.s_cfg_cxl_dev_range1_mem_active;
assign   cfg_cxl_dev_range1_desired_interleave = b_cxl_cdm.s_cfg_cxl_dev_range1_desired_interleave;
assign   cfg_cxl_dev_range1_mem_size_low       = b_cxl_cdm.s_cfg_cxl_dev_range1_mem_size_low;
assign   cfg_cxl_dev_range1_mem_base_high      = b_cxl_cdm.s_cfg_cxl_dev_range1_mem_base_high;
assign   cfg_cxl_dev_range1_mem_base_low       = b_cxl_cdm.s_cfg_cxl_dev_range1_mem_base_low;
assign   cfg_cxl_dev_range2_mem_size_high      = b_cxl_cdm.s_cfg_cxl_dev_range2_mem_size_high;
assign   cfg_cxl_dev_range2_mem_info_valid     = b_cxl_cdm.s_cfg_cxl_dev_range2_mem_info_valid;
assign   cfg_cxl_dev_range2_mem_active         = b_cxl_cdm.s_cfg_cxl_dev_range2_mem_active;
assign   cfg_cxl_dev_range2_desired_interleave = b_cxl_cdm.s_cfg_cxl_dev_range2_desired_interleave;
assign   cfg_cxl_dev_range2_mem_size_low       = b_cxl_cdm.s_cfg_cxl_dev_range2_mem_size_low;
assign   cfg_cxl_dev_range2_mem_base_high      = b_cxl_cdm.s_cfg_cxl_dev_range2_mem_base_high;
assign   cfg_cxl_dev_range2_mem_base_low       = b_cxl_cdm.s_cfg_cxl_dev_range2_mem_base_low;


assign   cfg_cxl_mbar0_corr_err   = b_cxl_cdm.s_mbar0_ras_corr_reg;
assign   cfg_cxl_mbar0_uncorr_err = b_cxl_cdm.s_mbar0_ras_uncorr_reg;
assign   cfg_cxl_pl_reg_fatal_err = b_cxl_cdm.s_cxl_fatal_error_reg;

assign   cfg_cxl_2_0_ext_port_ctl_ovr            = {b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bme, b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mse, b_cxl_cdm.s_cfg_cxl_2_0_ext_unmask_ld, b_cxl_cdm.s_cfg_cxl_2_0_ext_unmask_sbr};
assign   cfg_cxl_2_0_ext_alt_bus_base            = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bus_base;
assign   cfg_cxl_2_0_ext_alt_bus_limit           = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bus_limit;
assign   cfg_cxl_2_0_ext_alt_mem_base            = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mem_base;
assign   cfg_cxl_2_0_ext_alt_mem_limit           = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mem_limit;
assign   cfg_cxl_2_0_ext_alt_pref_mem_base       = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_base;
assign   cfg_cxl_2_0_ext_alt_pref_mem_limit      = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_limit;
assign   cfg_cxl_2_0_ext_alt_pref_mem_base_high  = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_base_high;
assign   cfg_cxl_2_0_ext_alt_pref_mem_limit_high = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_limit_high;
assign   cfg_cxl_2_0_ext_rcrb_en                 = b_cxl_cdm.s_cfg_cxl_2_0_ext_rcrb_en;
assign   cfg_cxl_2_0_ext_rcrb_base_addr_low      = b_cxl_cdm.s_cfg_cxl_2_0_ext_rcrb_base_addr_low;
assign   cfg_cxl_2_0_ext_rcrb_base_addr_high     = b_cxl_cdm.s_cfg_cxl_2_0_ext_rcrb_base_addr_high;


assign cfg_cxl_dev_disable_caching         = b_cxl_cdm.s_cfg_cxl_dev_disable_caching        ;
assign cfg_cxl_dev_initiate_cache_wr_invld = b_cxl_cdm.s_cfg_cxl_dev_initiate_cache_wr_invld;
assign cfg_cxl_dev_post_cold_rst_volatile_hdm_default = b_cxl_cdm.s_cfg_cxl_dev_post_cold_rst_volatile_hdm_default;
assign cfg_cxl_dev_post_warm_rst_volatile_hdm_default = b_cxl_cdm.s_cfg_cxl_dev_post_warm_rst_volatile_hdm_default;
assign cfg_cxl_dev_post_hot_rst_volatile_hdm_default  = b_cxl_cdm.s_cfg_cxl_dev_post_hot_rst_volatile_hdm_default;
assign cfg_cxl_dev_post_hot_rst_volatile_hdm_desired  = b_cxl_cdm.s_cfg_cxl_dev_post_hot_rst_volatile_hdm_desired;





wire [(`CX_NVC*3)-1:0]                  trgt1_radm_pkt_halt;
assign trgt1_radm_pkt_halt = {(`CX_NVC*3){1'b0}}; // if AMBA_POPULATED && RADM_SEG_BUF && TRGT1_POPULATE there is NO trgt1_radm_pkt_halt input

assign pm_current_data_rate = pm_current_data_rate_others;

wire [`CX_NL-1:0]   phy_mac_rxdatavalid_int;
wire [`CX_NL-1:0]   phy_mac_rxvalid_int;
assign phy_mac_rxvalid_int     = phy_mac_rxvalid;

wire          cfg_pcie_slot_clk_config;
wire [3:0]    smlh_autoneg_link_sp;


    wire                               app_hdr_valid_int;
    wire   [`CX_APP_HDR_LOG_WIDTH-1:0] app_hdr_log_int;
    wire                               app_hdr_flitmode_int;
    wire   [`CX_APP_HDR_LOG_SZ_WIDTH-1:0]     app_hdr_log_size_int;
    wire   [`CX_ERR_BUS_WD-1:0]        app_err_bus_int;
    wire                               app_err_advisory_int;
    wire                               app_poisoned_tlp_type_int;
    wire   [`CX_NFUNC_WD-1:0]          app_err_func_num_int;

    assign                               app_hdr_valid_int         =   app_hdr_valid;
    assign                               app_hdr_log_int           =   app_hdr_log;
    assign                               app_hdr_flitmode_int      =   app_hdr_flitmode;
    assign                               app_hdr_log_size_int      =   app_hdr_log_size;
    assign                               app_err_bus_int           =   app_err_bus;
    assign                               app_err_advisory_int      =   app_err_advisory;
    assign                               app_poisoned_tlp_type_int =   app_poisoned_tlp_type;
    assign                               app_err_func_num_int      =   app_err_func_num;

  logic [6:0]                                         cfg_tx_arb_control;
  logic                                               radm_trgt1_p_pending;
  trgt1_p_out_s    [`CX_RADM_NFC_TRGT_INTF-1:0]       radm_trgt1_out_p;
  trgt1_np_out_s   [`CX_RADM_NFC_TRGT_INTF-1:0]       radm_trgt1_out_np;
  trgt1_cpl_out_s  [`CX_RADM_NFC_TRGT_INTF-1:0]       radm_trgt1_out_cpl;

  ras_des_dbg_ntrgt_ntlp_s   s_radm_ras_des_err_info_0;

  // RADM TRGT1 P/NP/CPL Debug Signals Interface 0
  assign radm_ras_des_err_info_0  = { s_radm_ras_des_err_info_0.radm_req_ca,    // Completer Aborted Request
                                      s_radm_ras_des_err_info_0.radm_cpl_ur,    // Completion With Unsupported Request Status
                                      s_radm_ras_des_err_info_0.radm_cpl_uc,    // Unexpected Completion
                                      s_radm_ras_des_err_info_0.radm_cpl_pois,  // Poisoned Completion
                                      s_radm_ras_des_err_info_0.radm_cpl_ca,    // Completion With Completer Abort Status
                                      s_radm_ras_des_err_info_0.radm_wreq_pois, // Poisoned Write Request
                                      s_radm_ras_des_err_info_0.radm_req_ur,    // Unsupported Request
                                      s_radm_ras_des_err_info_0.radm_mlf_err,   // Malformed Error
                                      s_radm_ras_des_err_info_0.radm_ecrc_err,  // ECRC Error
                                      s_radm_ras_des_err_info_0.radm_pf         // Posted/Non-Posted/Completion Physical Function Numbers
                                      };


assign radm_trgt1_p_0_pending                             =  radm_trgt1_p_pending;
assign radm_trgt1_p_0_cpl_status                        =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_cpl_status;
assign radm_trgt1_p_0_rom_in_range                       =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_rom_req_in_range;
assign radm_trgt1_p_0_io_req_in_range                    =  'd0;
assign radm_trgt1_p_0_in_membar_range                    =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_in_membar_range;
assign radm_trgt1_np_0_rom_in_range                      =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_rom_req_in_range;
assign radm_trgt1_np_0_io_req_in_range                   =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_io_req_in_range;
assign radm_trgt1_np_0_in_membar_range                   =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_in_membar_range;
assign radm_trgt1_np_0_cpl_status                       =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_cpl_status;
assign radm_trgt1_cpl_0_status                           =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_cpl_status;


//
// posted
assign  radm_trgt1_p_0_data                               =  radm_trgt1_out_p[0].flt_q_data;
assign radm_trgt1_p_0_hdr_prot                            =   radm_trgt1_out_p[0].flt_hdr_prot;
assign  radm_trgt1_p_0_prfx                               =  radm_trgt1_out_p[0].flt_q_prfx;
assign   radm_trgt1_p_0_dwen                              =  radm_trgt1_out_p[0].flt_q_dwen;
assign   radm_trgt1_p_0_dv                                =  radm_trgt1_out_p[0].flt_q_dv;
assign   radm_trgt1_p_0_hv                                =  radm_trgt1_out_p[0].flt_q_hv;
assign   radm_trgt1_p_0_eot                               =  radm_trgt1_out_p[0].flt_q_eot;
assign   radm_trgt1_p_0_dllp_abort                        =  radm_trgt1_out_p[0].flt_q_dllp_abort;
assign   radm_trgt1_p_0_tlp_abort                         =  radm_trgt1_out_p[0].flt_q_tlp_abort;
assign   radm_trgt1_p_0_ecrc_err                          =  radm_trgt1_out_p[0].flt_q_ecrc_err;
assign   radm_trgt1_p_0_fmt                               =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_fmt;
assign   radm_trgt1_p_0_type                              =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_type;
assign   radm_trgt1_p_0_tc                                =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_tc;
assign   radm_trgt1_p_0_attr                              =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_attr;
assign  radm_trgt1_p_0_reqid                              =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_REQID;
assign  radm_trgt1_p_0_tag                                =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_TAG;
assign  radm_trgt1_p_0_func_num                           =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_func_nmbr;
assign   radm_trgt1_p_0_td                                =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_td;
assign   radm_trgt1_p_0_poisoned                          =  radm_trgt1_out_p[0].flt_q_poisoned;
assign   radm_trgt1_p_0_dw_len                            =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_dw_len;
assign   radm_trgt1_p_0_first_be                          =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_first_be;
assign   radm_trgt1_p_0_vc_num                            =  'd0;
assign   radm_trgt1_p_0_addr                              =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_addr;
assign   radm_trgt1_p_0_hdr_uppr_bytes                    =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_hdr_uppr_bytes;
assign  radm_trgt1_p_0_last_be                            =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_last_be;
assign  radm_trgt1_p_0_ats                                =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_ats;
assign  radm_trgt1_p_0_nw                                 =  1'b0;
assign  radm_trgt1_p_0_th                                 =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_th;
assign  radm_trgt1_p_0_ph                                 =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_ph;
assign  radm_trgt1_p_0_st                                 =  radm_trgt1_out_p[0].flt_q_hdr.flt_q_st;
assign  radm_trgt1_p_0_hdr_uppr_bytes_valid               =  radm_trgt1_out_p[0].flt_q_hdr.radm_atu_uppr_bytes_valid;
assign   radm_trgt1_p_0_reqtr_sgmt                        =  radm_trgt1_out_p[0].flt_q_hdr.hdr_dec_flt_reqtr_seg;
assign   radm_trgt1_p_0_dest_sgmt                         =  radm_trgt1_out_p[0].flt_q_hdr.hdr_dec_flt_dest_seg;
assign   radm_trgt1_p_0_pkt_order_no                      =  radm_trgt1_out_p[0].flt_q_hdr.flt_pkt_num;
assign radm_trgt1_p_0_atu_sloc_match                      =  radm_trgt1_out_p[0].radm_atu_sloc_match;
assign radm_trgt1_p_0_atu_cbuf_err                        =  radm_trgt1_out_p[0].radm_atu_cbuf_err;
// non-posted
assign  radm_trgt1_np_0_data                              =  radm_trgt1_out_np[0].flt_q_data;
assign radm_trgt1_np_0_hdr_prot                           =  radm_trgt1_out_np[0].flt_hdr_prot;
assign  radm_trgt1_np_0_prfx                              =  radm_trgt1_out_np[0].flt_q_prfx;
assign   radm_trgt1_np_0_dwen                             =  radm_trgt1_out_np[0].flt_q_dwen;
assign   radm_trgt1_np_0_dv                               =  radm_trgt1_out_np[0].flt_q_dv;
assign   radm_trgt1_np_0_hv                               =  radm_trgt1_out_np[0].flt_q_hv;
assign   radm_trgt1_np_0_eot                              =  radm_trgt1_out_np[0].flt_q_eot;
assign   radm_trgt1_np_0_dllp_abort                       =  radm_trgt1_out_np[0].flt_q_dllp_abort;
assign   radm_trgt1_np_0_tlp_abort                        =  radm_trgt1_out_np[0].flt_q_tlp_abort;
assign   radm_trgt1_np_0_ecrc_err                         =  radm_trgt1_out_np[0].flt_q_ecrc_err;
assign   radm_trgt1_np_0_fmt                              =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_fmt;
assign   radm_trgt1_np_0_type                             =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_type;
assign   radm_trgt1_np_0_tc                               =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_tc;
assign   radm_trgt1_np_0_attr                             =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_attr;
assign  radm_trgt1_np_0_reqid                             =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_REQID;
assign  radm_trgt1_np_0_tag                               =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_TAG;
assign  radm_trgt1_np_0_func_num                          =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_func_nmbr;
assign   radm_trgt1_np_0_td                               =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_td;
assign   radm_trgt1_np_0_poisoned                         =  radm_trgt1_out_np[0].flt_q_poisoned;
assign   radm_trgt1_np_0_dw_len                           =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_dw_len;
assign   radm_trgt1_np_0_first_be                         =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_first_be;
assign   radm_trgt1_np_0_vc_num                           =  'd0;

assign   radm_trgt1_np_0_addr                             =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_addr;
assign   radm_trgt1_np_0_hdr_uppr_bytes                   =  'd0;
assign  radm_trgt1_np_0_last_be                           =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_last_be;
assign  radm_trgt1_np_0_ats                               =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_ats;
assign  radm_trgt1_np_0_nw                                =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_nw;
assign  radm_trgt1_np_0_cxlsrc                            =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_cxlsrc;
assign  radm_trgt1_np_0_th                                =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_th;
assign  radm_trgt1_np_0_ph                                =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_ph;
assign  radm_trgt1_np_0_st                                =  radm_trgt1_out_np[0].flt_q_hdr.flt_q_st;
assign  radm_trgt1_np_0_hdr_uppr_bytes_valid              =  1'b0;

assign   radm_trgt1_np_0_reqtr_sgmt                       =  radm_trgt1_out_np[0].flt_q_hdr.hdr_dec_flt_reqtr_seg;
assign   radm_trgt1_np_0_dest_sgmt                        =  radm_trgt1_out_np[0].flt_q_hdr.hdr_dec_flt_dest_seg;
assign   radm_trgt1_np_0_pkt_order_no                     =  radm_trgt1_out_np[0].flt_q_hdr.flt_pkt_num;
assign radm_trgt1_np_0_atu_sloc_match                     =  radm_trgt1_out_np[0].radm_atu_sloc_match;
assign radm_trgt1_np_0_atu_cbuf_err                       =  radm_trgt1_out_np[0].radm_atu_cbuf_err;

// Completion
assign  radm_trgt1_cpl_0_data                             =  radm_trgt1_out_cpl[0].flt_q_data;
assign  radm_trgt1_cpl_0_hdr_prot                         =  radm_trgt1_out_cpl[0].flt_hdr_prot;
assign  radm_trgt1_cpl_0_prfx                             =  radm_trgt1_out_cpl[0].flt_q_prfx;
assign  radm_trgt1_cpl_0_dwen                             =  radm_trgt1_out_cpl[0].flt_q_dwen;
assign  radm_trgt1_cpl_0_dv                               =  radm_trgt1_out_cpl[0].flt_q_dv;
assign  radm_trgt1_cpl_0_hv                               =  radm_trgt1_out_cpl[0].flt_q_hv;
assign  radm_trgt1_cpl_0_eot                              =  radm_trgt1_out_cpl[0].flt_q_eot;
assign  radm_trgt1_cpl_0_dllp_abort                       =  radm_trgt1_out_cpl[0].flt_q_dllp_abort;
assign  radm_trgt1_cpl_0_tlp_abort                        =  radm_trgt1_out_cpl[0].flt_q_tlp_abort;
assign  radm_trgt1_cpl_0_ecrc_err                         =  radm_trgt1_out_cpl[0].flt_q_ecrc_err;
assign  radm_trgt1_cpl_0_fmt                              =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_fmt;
assign  radm_trgt1_cpl_0_type                             =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_type;
assign  radm_trgt1_cpl_0_tc                               =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_tc;
assign  radm_trgt1_cpl_0_attr                             =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_attr;
assign  radm_trgt1_cpl_0_reqid                            =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_REQID;
assign  radm_trgt1_cpl_0_tag                              =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_TAG;
assign  radm_trgt1_cpl_0_func_num                         =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_func_nmbr;
assign  radm_trgt1_cpl_0_td                               =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_td;
assign  radm_trgt1_cpl_0_poisoned                         =  radm_trgt1_out_cpl[0].flt_q_poisoned;
assign  radm_trgt1_cpl_0_dw_len                           =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_dw_len;
assign  radm_trgt1_cpl_0_bcm                              =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_cpl_bcm;
assign  radm_trgt1_cpl_0_byte_cnt                         =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_byte_cnt;
assign  radm_trgt1_cpl_0_cmpltr_id                        =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_cplid;
assign  radm_trgt1_cpl_0_last                             =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_cpl_last;
assign  radm_trgt1_cpl_0_vc_num                           =  'd0;
assign  radm_trgt1_cpl_0_addr                             =  {{(`FLT_Q_ADDR_WIDTH -`FLT_Q_CPL_LOWER_ADDR_WIDTH){1'b0}},radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_cpl_lower_addr};

assign  radm_trgt1_cpl_0_dest_sgmt                        =  radm_trgt1_out_cpl[0].flt_q_hdr.hdr_dec_flt_dest_seg;
assign  radm_trgt1_cpl_0_cpl_sgmt                         =  radm_trgt1_out_cpl[0].flt_q_hdr.hdr_dec_flt_cpltr_seg;
assign  radm_trgt1_cpl_0_p_pkt_order_no                   =  radm_trgt1_out_cpl[0].flt_q_hdr.flt_pkt_num;




wire   txsyncheader_bypass  = ltssm_cxl_enable.sync_hdr_bypass_enabled;

wire [`CX_NL-1:0]                      core_pre_mac_phy_txdetectrx_loopback;
assign pre_mac_phy_txdetectrx_loopback = core_pre_mac_phy_txdetectrx_loopback;


wire usp_g3_eq_redo_executed_int;
wire usp_g4_eq_redo_executed_int;
wire usp_g5_eq_redo_executed_int;

wire [`CX_NFUNC-1:0]              cfg_upd_req_id;
 assign int_cfg_upd_req_id      = cfg_upd_req_id[0];

spif_if           b_vlsm_llctrl_mc();      // Link Layer to VLSM SPIF Interface for CXL.cachemem
wire              cxl_link_tx_deinit_req;  //  Tx Link deinit for app interface 
wire        cxl_vlsm_lrsm_req_retrain;





logic                cfg_p2p_track_cpl_to;
ras_dp_err_log_t      ras_dp_err_log_from_xtlh;
ras_dp_err_log_t      ras_dp_err_log_from_xdlh;
ras_dp_err_log_t      ras_dp_err_log_from_xplh;
ras_dp_err_log_t      vlsm_ras_dp_err_log;
ras_dp_err_inj_t    ras_dp_err_inj;


logic xdlh_retrybuf_not_empty;
logic cfg_elastic_buffer_mode;
logic [`CX_NL*`DIRFEEDBACK_WD-1:0]     phy_mac_dirfeedback;
logic [`CX_NL*`CX_FOMFEEDBACK_WD-1:0]  phy_mac_fomfeedback;
logic                smlh_l0p_capable;
logic [2:0]          cfg_local_l0p_exit_latency;
logic                cfg_l0p_receiver_support;   // L0p Receiver Support
logic                cfg_l0p_enable;             // L0p Enable
logic                cfg_l0p_autowidth_dis;      // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
logic                cfg_l0p_priority;           // Port Logic register bit to set L0p.Priority bit in DLLP
logic  [2:0]         cfg_l0p_linkmode;           // Target Link Width in Device Control 3 Register (bit[6:4])
logic                cfg_l0p_linkmode_req;       // Link Width change request asserted on the write access to Device Control 3 Register
logic  [5:0]         cfg_l0p_max_link_width;     // Maximum supported Link Width
logic  [5:0]         cfg_l0p_neg_link_width;     // Negotiated Link Width
logic                cfg_pcie_l0p_disable;       // PCIe/CXL.io: Disable dynamic L0p
logic                cfg_pcie_l0p_request;       // PCIe/CXL.io: L0p Request bit
logic                cfg_pcie_l0p_priority;      // PCIe/CXL.io: L0p Priority bit
logic  [2:0]         cfg_pcie_l0p_linkmode;      // PCIe/CXL.io: L0p Target Link Width
logic                cfg_cxl_l0p_disable;        // CXL.cachemem: Disable dynamic L0p
logic                cfg_cxl_l0p_request;        // CXL.cachemem: L0p Request bit
logic                cfg_cxl_l0p_priority;       // CXL.cachemem: L0p Priority bit
logic  [2:0]         cfg_cxl_l0p_linkmode;       // CXL.cachemem: L0p Target Link Width
logic                cfg_flit_mode_enable;
logic                cfg_pcie_cap_flit_mode_sup;
logic                cfg_flit_mode_dis;
logic                cfg_flit_sris_clocking;
logic  [CFG_CXL_PORT_ENABLE_WD-1:0]  cfg_cxl_port_enable;
logic  [15:0]                        cfg_cxl_port_vid;
logic                                cfg_cxl_retimers_pre_mismatched;
logic    [1:0]                       cfg_retimers_pre_detected;
logic                      cfg_pm_timeout_enable;
logic [1:0]                cfg_pm_timeout_value;
logic                             cfg_pm_timeout_error;
vlsm_debug_t                vlsm_debug_info;
logic [(`CX_NVC)-1:0]             cfg_vc_enable;
logic [(`CX_NVC*3)-1:0]           cfg_vc_struc_vc_id_map;
logic [23:0]                      cfg_vc_id_vc_struc_map;
logic [7:0]                       cfg_tc_enable;
logic [23:0]                      cfg_tc_struc_vc_map;

logic                      end_device;
logic                      rc_device;
logic                      cfg_dll_lnk_en;
logic  [7:0]               cfg_ack_freq;
logic  [15:0]              cfg_ack_latency_timer;
logic  [16:0]              cfg_replay_timer_value;
logic  [12:0]              cfg_fc_latency_value;
logic  [31:0]              cfg_other_msg_payload;
logic                      cfg_other_msg_request;
logic  [31:0]              cfg_corrupt_crc_pattern;
logic                      cfg_flow_control_disable;
logic                      cfg_acknack_disable;
logic                      cfg_scramble_dis;
logic  [7:0]               cfg_n_fts;
logic                      cfg_reset_assert;
logic  [7:0]               cfg_link_num;
logic                      cfg_ts2_lid_deskew_i;
logic                      cfg_support_part_lanes_rxei_exit;
logic  [5:0]               cfg_forced_link_state;
logic  [3:0]               cfg_forced_ltssm_cmd;
logic                      cfg_force_en;
logic                      cfg_fast_link_mode;
logic  [1:0]               cfg_fast_link_scaling_factor;
logic                      cfg_l0s_supported;
logic  [22:0]              cfg_lane_skew;
logic                      cfg_deskew_disable;
logic  [3:0]               cfg_imp_num_lanes;
logic  [10:0]              cfg_skip_interval;
logic                      cfg_ext_synch;
logic                      cfg_hw_autowidth_dis;
logic  [2:0]               cfg_highest_max_payload;
logic  [2:0]               cfg_max_payload_size_out_rx;
logic                      cfg_fc_wdog_disable;
logic  [(`CX_NVC*8)-1:0]   cfg_fc_credit_ph;
logic  [(`CX_NVC*8)-1:0]   cfg_fc_credit_nph;
logic  [(`CX_NVC*8)-1:0]   cfg_fc_credit_cplh;
logic  [(`CX_NVC*12)-1:0]  cfg_fc_credit_pd;
logic  [(`CX_NVC*12)-1:0]  cfg_fc_credit_npd;
logic  [(`CX_NVC*12)-1:0]  cfg_fc_credit_cpld;
logic                      dl_feature_en;
logic                      cfg_remote_feature_ack;
logic  [22:0]              cfg_local_feature_support;
logic                      cfg_dlink_feature_valid;
logic  [(`CX_NVC*2)-1:0]   hdr_scale_p;
logic  [(`CX_NVC*2)-1:0]   data_scale_p;
logic  [(`CX_NVC*2)-1:0]   hdr_scale_np;
logic  [(`CX_NVC*2)-1:0]   data_scale_np;
logic  [(`CX_NVC*2)-1:0]   hdr_scale_cpl;
logic  [(`CX_NVC*2)-1:0]   data_scale_cpl;
logic                      fc_scaled_en;
logic  [5:0]               cfg_margin_num_timing_steps;
logic  [5:0]               cfg_margin_max_timing_offset;
logic  [6:0]               cfg_margin_num_voltage_steps;
logic  [5:0]               cfg_margin_max_voltage_offset;
logic  [5:0]               cfg_margin_sample_rate_voltage;
logic  [5:0]               cfg_margin_sample_rate_timing;
logic  [4:0]               cfg_margin_maxlanes;
logic                      cfg_margin_voltage_supported;
logic                      cfg_margin_ind_up_down_voltage;
logic                      cfg_margin_ind_left_right_timing;
logic                      cfg_margin_sample_reporting_method;
logic                      cfg_margin_ind_error_sampler;
logic  [3:0]               cfg_rx_message_bus_write_buffer_depth;
logic                      cfg_pipe_garbage_data_mode;
logic                      cfg_pam4_restricted_levels_requirement;
logic  [`CX_NFUNC_WD-1:0]     cfg_max_func_num;
logic  [3:0]                  device_type_o;
logic    [8:0]                       cfg_lane_en;
logic                                cfg_gen1_ei_inference_mode;
logic    [1:0]                       cfg_select_deemph_mux_bus;
logic    [`CX_LUT_PL_WD-1:0]         cfg_lut_ctrl;
logic    [7:0]                       cfg_rxstandby_control;
logic    [`CX_PL_GEN3_CONTROL_WD-1:0]    cfg_pl_gen3_control;
logic    [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control;
logic                                    cfg_no_seed_value_change;
logic    [`CX_DIR_CHANGE_CONTROL_WD-1:0] cfg_fdbk_dirchange_control;
logic                                    cfg_perform_eq;
logic                                    cfg_ls2_eq_req;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_pset_ltx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         int_cfg_lec_pset_lrx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_pset_rtx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         int_cfg_lec_pset_rrx;
logic    [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen4_control;
logic    [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control;
logic    [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen4_fdbk_dirchange_control;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         cfg_lec_g4_pset_lrx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         cfg_lec_g4_pset_rrx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_g4_pset_ltx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_g4_pset_rtx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]                int_smlh_lec_g4_pset_ltx;
logic    [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen5_control;
logic    [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control;
logic    [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen5_fdbk_dirchange_control;
logic                                cfg_bypass_eq_enable;
logic                                cfg_no_eq_needed_enable;
logic                                cfg_tx_precode_req;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g5_pset_lrx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g5_pset_rrx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g5_pset_ltx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g5_pset_rtx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]            int_smlh_lec_g5_pset_ltx;
logic    [`CX_PL_GEN6_CONTROL_WD-1:0]    cfg_pl_gen6_control;
logic    [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control;
logic    [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control;
logic                                    cfg_g6_tx_precode_req;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g6_pset_ltx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g6_pset_rtx;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]            int_smlh_lec_g6_pset_ltx;
logic                                cfg_alt_protocol_enable;
logic                                cfg_gen2_support;
logic    [7:0]                       cfg_gen2_n_fts;
logic                                cfg_enter_compliance;
logic                                cfg_sel_de_emphasis;
logic    [2:0]                       cfg_transmit_margin;
logic                                cfg_enter_mod_compliance;
logic                                cfg_compliance_sos;
logic    [3:0]                       cfg_compliance_de_emphasis;
logic    [3:0]                       cfg_pcie_max_link_speed;
logic    [3:0]                       cfg_target_link_speed;
logic                                cfg_phy_txswing;
logic                                cfg_tx_compliance_rcv;
logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_ph_ca;
logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_pd_ca;
logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_nph_ca;
logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_npd_ca;
logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_cplh_ca;
logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_cpld_ca;
logic                                  cfg_rasdp_linkdown_en;
logic                                  rasdp_linkdown;
logic                                xtlh_tlp_pending; // XTLH has no TLP pending in its datapath
xtlh_pkt_t [`N_XADM_IF-1:0]                    xadm_xtlh_pkt;
logic             [`N_XADM_IF-1:0]             xtlh_xadm_pkt_halt;
logic             [`N_XADM_P_IF-1:0]           xtlh_xadm_posted_tlp_sent;
logic                                xadm_all_type_infinite;
logic  [6:0]                       esm_current_rate;
logic                                cfg_drift_buffer_deskew_enable;
logic          correctable_protocol_id_frame_err;
logic          uncorrectable_protocol_id_frame_err;
logic          unexpected_protocol_id_dropped;
logic [23:0]   ltssm_cxl_mod_ts_phase1_rcvd;
logic          ltssm_cxl_retimers_pre_mismatched;
logic          ltssm_cxl_flexbus_phase2_mismatched;
rplh_flit_logging_interface_struct rplh_flit_logging_interface;
rmlh_flit_logging_interface_struct rmlh_flit_logging_interface;
smlh_flit_logging_interface_struct smlh_flit_logging_interface;
logic                              cfg_tx_throttling;
logic                          cfg_flit_err_inj_latency;
flit_err_inj_interface_struct  cdm_plh_flit_err_inj_interface;
flit_err_inj_status_struct     plh_cdm_flit_err_inj_status;
cfg_os_einj_ctrl_1_t           cfg_os_einj_ctrl_1;
cfg_os_einj_ctrl_2_t           cfg_os_einj_ctrl_2;
cfg_os_einj_status_t           xmlh_tx_os_einj_status;
logic  [2:0]         cdm_xplh_flit_response_type;
logic  [1:0]         cdm_xplh_flit_type_measured;
logic                cdm_xplh_flit_track_mode;
xplh_cdm_flit_latency_track_t        xplh_cdm_flit_latency_tracking;
logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen3_eq_fs_lf;
logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen3_eq_coef;
logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen4_eq_fs_lf;
logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen4_eq_coef;
logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen5_eq_fs_lf;
logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen5_eq_coef;
logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen6_eq_fs_lf;
logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen6_eq_coef;
logic    [7:0]                     cfg_l1sub_t_common_mode;
logic    [(2*`CX_NFUNC)-1:0]       cfg_max_end2end_tlp_prfxs;
logic    [1:0]                     cdm_ras_des_pm_entry_interval;
logic    [1:0]                     cdm_ras_des_eidle_cnt_sel;
logic                              cdm_ras_des_ltssm_stop;
logic                              cdm_ras_des_recovery_req;
logic                              cdm_ras_des_ferr_rec_dis;
logic                              cdm_ras_des_direct_rcvry_idle_to_cfg;
logic                              cdm_ras_des_direct_poll_cmp_to_det;
logic                              cdm_ras_des_direct_lpbk_slave_to_exit;
logic                              cdm_ras_des_force_rxdetected_en;
logic                              cdm_ras_des_force_linkdown_noack;
logic    [1:0]                     cdm_ras_des_ext_eq_to_factor;
logic                              cdm_ras_des_eq_fom_target_en;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_lrx_en;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_ltx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]       cdm_ras_des_eq_force_pset_lrx;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_rtx;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]       cdm_ras_des_eq_force_usp_pset_ltx;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en_g4;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en_g4;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_ltx_g4;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_rtx_g4;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en_g4;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]       cdm_ras_des_eq_force_usp_pset_ltx_g4;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en_g5;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en_g5;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_ltx_g5;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_rtx_g5;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en_g5;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]       cdm_ras_des_eq_force_usp_pset_ltx_g5;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en_g6;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en_g6;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_ltx_g6;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]       cdm_ras_des_eq_force_coef_rtx_g6;
logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en_g6;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]       cdm_ras_des_eq_force_usp_pset_ltx_g6;
logic    [`CX_FOMFEEDBACK_WD-1:0]      cdm_ras_des_eq_fom_target;
logic    [1:0]                     cdm_ras_des_eq_eval_interval;
    
logic                              cdm_ras_des_einj0_enable;
logic    [7:0]                     cdm_ras_des_einj0_count;
logic    [3:0]                     cdm_ras_des_einj0_crc_type;
logic                              cdm_ras_des_einj1_enable;
logic                              cdm_ras_des_einj1_seq_type;
logic    [12:0]                    cdm_ras_des_einj1_bad_seq;
logic    [7:0]                     cdm_ras_des_einj1_count;
logic                              cdm_ras_des_einj2_enable;
logic    [1:0]                     cdm_ras_des_einj2_dllp_type;
logic                              cdm_ras_des_einj3_enable;
logic    [7:0]                     cdm_ras_des_einj3_count;
logic    [2:0]                     cdm_ras_des_einj3_smb_type;
logic                              cdm_ras_des_einj4_enable;
logic    [2:0]                     cdm_ras_des_einj4_updfc_type;
logic    [2:0]                     cdm_ras_des_einj4_vcnum;
logic    [12:0]                    cdm_ras_des_einj4_badfc_value;
logic                              cdm_ras_des_einj5_enable;
logic    [7:0]                     cdm_ras_des_einj5_count;
logic                              cdm_ras_des_einj5_tlp_type;
logic    [5:0]                       smlh_autoneg_link_width;
logic    [5:0]                       rplh_link_rxmode;
logic                                smlh_link_training_in_prog;
logic                                 latched_flit_mode_enable;
logic                                 smlh_flit_mode_enable;
logic                               smlh_bw_mgt_status;
                                                                    // without the port transitioning through DL_Down status
logic                               smlh_link_auto_bw_status;
                                                                    // DL_Down status;
logic                                smlh_clr_enter_compliance;
logic                                smlh_tx_margin_rst;
logic                                smlh_core_rst_n_release_pulse;
logic                                smlh_dir_spd_chg_rising_edge;
logic                                smlh_dir_linkw_chg_started;
logic                                smlh_ltssm_in_hotrst_dis_entry;
logic                                smlh_ls2_eq_req;
logic    [3:1]                       smlh_ls2_eq_success;
logic                                smlh_ls2_eq_cmpl;
logic                                smlh_ls2_eq_enter;
logic                                smlh_ltssm_in_detectquiet;
logic                                smlh_ls2_g4_eq_req;
logic    [3:1]                       smlh_ls2_g4_eq_success;
logic                                smlh_ls2_g4_eq_cmpl;
logic                                smlh_ls2_g4_eq_enter;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     smlh_lec_g4_pset_lrx;
logic                                smlh_retimer_pre_detected;
logic                                smlh_ls2_g5_eq_req;
logic    [3:1]                       smlh_ls2_g5_eq_success;
logic                                smlh_ls2_g5_eq_cmpl;
logic                                smlh_ls2_g5_eq_enter;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     smlh_lec_g5_pset_lrx;
logic    [1:0]                       smlh_elbc_rcvd;
logic                                smlh_tx_precoding_on;
logic                                smlh_noeq_needed_rcvd;
logic                                smlh_ls2_g6_eq_req;
logic    [3:1]                       smlh_ls2_g6_eq_success;
logic                                smlh_ls2_g6_eq_cmpl;
logic                                smlh_ls2_g6_eq_enter;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     smlh_lec_g6_pset_lrx;
logic                                smlh_g6_tx_precoding_on;
logic                                smlh_two_retimers_pre_detected;
logic  [1:0]                         smlh_crosslink_resolution;
logic                                smlh_margin_ready;
logic                                smlh_mod_ts_rcvd;
logic  [55:0]                        mod_ts_data_rcvd;
logic  [55:0]                        mod_ts_data_sent_i;
logic                                rmlh_rcvd_err;
logic                                dl_prot_err;
logic                                rdlh_bad_tlp_err;
logic                                rdlh_bad_dllp_err;
logic    [1:0]                       rdlh_dlcntrl_state;
logic                                rdlh_link_down;
logic                                rdlh_rcvd_dl_feature;
logic [31:0]                         rcvd_dl_feature_content;
logic                              replay_num_rlover_err;
logic                              replay_timeout_err;
rtlh_radm_datapath_t               rtlh_radm;
logic [`CX_RAS_ERROR_INJ_EN_WD-1:0]  ras_err_inj_en_array;
logic [`CX_RAS_ERROR_INJ_MASK_WD-1:0]ras_err_inj_mask;
logic                                       ras_err_inj_done_cx_pl;
logic    [`CX_NVC-1:0]               rtlh_fc_init_status;
logic    [`CX_NVC-1:0]               rtlh_crd_not_rtn;
rtlh_rfc_t                           rtlh_rcvd_fc;
logic    [`RBUF_PW -1:0]             retryram_xdlh_depth;
logic    [`SOTBUF_L2DEPTH -1:0]      retrysotram_xdlh_depth;
logic [ `CX_RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_corr;
logic [ `CX_RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_corr;
logic [ `CX_RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_uncorr;
logic [ `CX_RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_uncorr;
logic   [1:0]                                cxpl_cdm_ras_des_einj0_ack;
logic    [7:0]                       rtfcgen_ph_diff;
logic                                rtlh_overfl_err;
logic                                xdlh_retry_req;
logic    [`CX_NL-1:0]                  rpipe_rxelecidle;
logic    [`CX_NL-1:0]                  rmlh_rpipe_rxoverflow;
logic    [`CX_NL-1:0]                  rmlh_rpipe_rxunderflow;
logic    [`CX_NL-1:0]                  rmlh_rpipe_rxcodeerror;
logic    [`CX_NL-1:0]                  rmlh_rpipe_rxdisperror;
logic    [`CX_NL-1:0]                  rmlh_rpipe_rxskipadded;
logic    [`CX_NL-1:0]                  rmlh_rpipe_rxskipremoved;
logic    [`CX_NL-1:0]                  rmlh_skp_parity_err;
logic    [`CX_NL-1:0]                  rmlh_sync_header_err;
logic                                  rmlh_framing_err;
logic    [6:0]                         rmlh_framing_err_ptr;
logic                                  rmlh_framing_err_l0;
logic                                  rmlh_deskew_alignment_err;
logic    [(`CX_NL*8)-1:0]              rmlh_deskew_fifo_ptr;
logic    [`CX_NL-1:0]                  rmlh_rxvalid_deasserted;
logic                              smlh_eidle_inferred_in_l0;
logic                              smlh_rx_rcvry_req;
logic                              smlh_timeout_nfts;
logic                              smlh_l0_to_recovery;
logic                              smlh_l1_to_recovery;
logic                              smlh_rcv_eios_when_l0s_unsprt;
logic                              smlh_deskew_uncomplete_err;
logic                              smlh_spd_change;
logic    [`CX_NL*8-1:0]            smseq_mcs_sts;
logic                              smlh_lwd_change;
logic    [15:0]                    smlh_ltssm_variable;
logic    [`CX_NL*16-1:0]           smlh_rxos_type;
logic    [`CX_NL*64-1:0]           smseq_ts_debug_info;
logic    [1:0]                     int_ltssm_powerdown;
logic    [7:0]                     latched_ts_nfts;
logic                          init_eq_pending;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx;
logic    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback;
logic    [`CX_NL*3-1:0]            eqpa_violate_rule_123;
logic    [`CX_NL*2-1:0]            eq_convergence_sts;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]   mac_cdm_ras_des_pset_lrx;
logic    [`CX_NL-1:0]              mac_cdm_ras_des_reject_rtx;
logic                          init_eq_pending_g4;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs_g4;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf_g4;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx_g4;
logic    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g4;
logic    [`CX_NL*3-1:0]            eqpa_violate_rule_123_g4;
logic    [`CX_NL*2-1:0]            eq_convergence_sts_g4;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx_g4;
logic    [`CX_NL-1:0]              mac_cdm_ras_des_reject_rtx_g4;
logic                          init_eq_pending_g5;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs_g5;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf_g5;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx_g5;
logic    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g5;
logic    [`CX_NL*3-1:0]            eqpa_violate_rule_123_g5;
logic    [`CX_NL*2-1:0]            eq_convergence_sts_g5;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx_g5;
logic    [`CX_NL-1:0]              mac_cdm_ras_des_reject_rtx_g5;
logic                          init_eq_pending_g6;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs_g6;
logic    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf_g6;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx_g6;
logic    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g6;
logic    [`CX_NL*3-1:0]            eqpa_violate_rule_123_g6;
logic    [`CX_NL-1:0]              eqpa_violate_rule_4_g6;
logic    [`CX_NL*2-1:0]            eq_convergence_sts_g6;
logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx_g6;
logic    [`CX_NL-1:0]              mac_cdm_ras_des_reject_rtx_g6;
logic    [1:0]                         rl0s_state;
logic    [`CX_RX_TLP-1:0]              rdlh_bad_tlp_err_pertlp;
logic    [`CX_RX_TLP-1:0]              rdlh_lcrc_tlp_err_pertlp;
logic    [`CX_RX_TLP-1:0]              rdlh_nulified_tlp_err_pertlp;
logic    [`CX_RX_TLP-1:0]              rdlh_duplicate_tlp_err_pertlp;
logic    [`CX_RX_NDLLP-1:0]            rdlh_bad_dllp_err_perdllp;
logic    [`CX_RX_NDLLP-1:0]            rdlh_rcvd_nack_perdllp;
logic    [`CX_RX_NDLLP-1:0]            rdlh_rcvd_ack_perdllp;
logic                                  xdlh_nak_sent;
logic                                  xdlh_ack_sent;
logic    [`CX_TX_NDLLP-1:0]            xdlh_update_fc_sent;
logic                                  rtlh_req_link_retrain;
logic    [`CX_RX_NDLLP -1:0]           rtlh_rcvd_ufc_perdllp;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_memwr_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_defmemwr_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_memrd_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_cfgwr_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_cfgrd_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_iowr_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_iord_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_cplwod_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_cplwd_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_msg_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_atmcop_evt;
logic    [`CX_RX_TLP-1:0]              rtlh_rx_tlpwprefix_evt;
logic    [`CX_RX_TLP*11-1:0]           rtlh_rx_tlp_dpsize;
logic                              rdlh_vc0_initfc1_status;
logic                              rdlh_vc0_initfc2_status;
logic    [11:0]                    rdlh_xplh_curnt_rx_ack_seqnum;
logic    [11:0]                    xdlh_xplh_curnt_seqnum;
logic    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_rcvd_ph;
logic    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_rcvd_pd;
logic    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_rcvd_nph;
logic    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_rcvd_npd;
logic    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_rcvd_cplh;
logic    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_rcvd_cpld;
logic    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_allctd_ph;
logic    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_allctd_pd;
logic    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_allctd_nph;
logic    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_allctd_npd;
logic    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_allctd_cplh;
logic    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_allctd_cpld;
logic    [2:0]                     rdlh_einj0_lcrc_evt;
logic                              xmlh_einj0_oscrc_evt;
logic    [1:0]                     xdlh_einj0_lcrc_evt;
logic                              xdlh_einj0_fcrc_evt;
logic    [1:0]                     xdlh_einj0_dllpcrc_evt;
logic    [1:0]                     ras_des_einj1_exp_sequm_evt;
logic                              ras_des_einj1_ack_nak_sequm_evt;
logic                              xdlh_einj2_nak_evt;
logic    [1:0]                     xmlh_einj3_osmsk_evt;
logic                              rtlh_einj4_fc_evt;
logic                              xdlh_einj5_nultlp_evt;
logic                              xdlh_einj5_dup_evt;
logic                                xdlh_ptm_sot;
logic                                xdlh_ptm_multi_cycle;
logic                                xdlh_ptm_request;
logic                                xdlh_ptm_response;
logic                                xdlh_rbuf_replaying;
logic                                rdlh_ptm_sot;
logic                                rdlh_ptm_multi_cycle;
logic                                rdlh_ptm_request;
logic                                rdlh_ptm_response;
logic                                rdlh_duplicate_tlp;
logic                          smlh_ltssm_in_l0p;
logic [2:0]                           tmp_int_mac_phy_rate;
logic                                 tmp_mac_phy_txdeemph_0;
logic [`CX_BAC_WD-1:0]                pre_mac_phy_blockaligncontrol_o;
logic                                cfg_pipe_loopback;
logic    [5:0]                       cfg_rxstatus_lane;
logic    [2:0]                       cfg_rxstatus_value;
logic    [`CX_NL-1:0]                cfg_lpbk_rxvalid;
logic  [`CX_NL*16-1:0]               int_cfg_margin_control;
logic  [`CX_NL-1:0]                         int_smlh_margin_status_valid;
logic  [`CX_NL*16-1:0]                      int_smlh_margin_status;
logic  [`CX_NL*5-1:0]                       int_rmlh_deskew_ctlskp_err;
logic    [`CX_NL-1:0]              int_cdm_ras_des_force_rxdetected;
logic    [`CX_NL-1:0]                    int_rmlh_lane_err;
logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_smlh_lec_pset_ltx;
logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         int_smlh_lec_pset_lrx;
logic    [(`CX_NL*`CX_PHY_NB*8)-1:0]     orig_pipe_rxdata;
logic    [(`CX_NL*`CX_PHY_NB)-1:0]       orig_pipe_rxdatak;
logic    [`CX_NL-1:0]                    orig_pipe_rxvalid;
logic    [`CX_NL-1:0]                    orig_pipe_rxdatavalid;
logic    [(`CX_NL*3)-1:0]                orig_pipe_rxstatus;
logic    [(`CX_NL*`CX_PHY_RXSB_WD)-1:0]  orig_pipe_rxstartblock;
logic    [(`CX_NL*`CX_PHY_RXSH_WD)-1:0]  orig_pipe_rxsyncheader;
logic [`CX_NL-1:0]                       phy_mac_phystatus_int;
logic                              rmlh_prbs_done;
logic                              rmlh_prbs_fail;
logic   [`CX_NL-1:0]               rmlh_prbs_started;
logic   [`CX_NL-1:0][7:0]          rmlh_prbs_err_cntr;
logic   [`CX_NL-1:0]               rmlh_prbs_unexp_fail;
logic                              cfg_prbs_en;
logic                              clear_prbs_done;
logic   [3:0]                      cfg_prbs_lane_sel;

logic                            dpc_fatal_err_gate;
logic                            dpc_nonfatal_err_gate;
assign rtlh_fc_overflow_err = rtlh_overfl_err;


DWC_pcie_core

#(
    .INST (INST)
 )
 u_DWC_pcie_core (
    .xali_xaim_pkt  (xali_xaim_pkt),
    .xaim_xali_halt (xaim_xali_halt),
    .app_segment_id (app_segment_id),
    .cfg_segment_id (cfg_segment_id),
    .xali_posted_tlp_sent (xali_posted_tlp_sent),









    .radm_cpl_timeout       (radm_cpl_timeout     ),
    .radm_timeout_func_num  (radm_timeout_func_num),
    .radm_timeout_cpl_tc    (radm_timeout_cpl_tc  ),
    .radm_timeout_cpl_attr  (radm_timeout_cpl_attr),
    .radm_timeout_cpl_len   (radm_timeout_cpl_len),
    .radm_timeout_cpl_tag   (radm_timeout_cpl_tag),




    .cfg_10b_tag_req_en    (cfg_10b_tag_req_en  ),


    .app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable),


    .ext_lbc_override_en      (ext_lbc_override_en     ),

    .ext_lbc_ack              (ext_lbc_ack             ),
    .ext_lbc_din              (ext_lbc_din             ),
    .lbc_ext_addr             (lbc_ext_addr            ),
    .lbc_ext_dout             (lbc_ext_dout            ),
    .lbc_ext_valid            (lbc_ext_valid           ),
    .lbc_ext_cs               (lbc_ext_cs              ),
    .lbc_ext_wr               (lbc_ext_wr              ),
    .lbc_ext_rd               (lbc_ext_rd              ),
    .lbc_ext_dbi_access       (lbc_ext_dbi_access      ),
    .lbc_ext_cxl_mbar0_access (lbc_ext_cxl_mbar0_access),
    .lbc_ext_rom_access       (lbc_ext_rom_access      ),
    .lbc_ext_io_access        (lbc_ext_io_access       ),
    .lbc_ext_bar_num          (lbc_ext_bar_num         ),
    .ven_msi_req       (ven_msi_req     ),
    .ven_msi_func_num  (ven_msi_func_num),
    .ven_msi_tc      (ven_msi_tc    ),
    .ven_msi_vector  (ven_msi_vector),
    .ven_msi_grant   (ven_msi_grant ),
    .cfg_msi_en      (cfg_msi_en    ),
    .cfg_msi_addr         (cfg_msi_addr       ),
    .cfg_msi_data         (cfg_msi_data       ),
    .cfg_msi_64           (cfg_msi_64         ),
    .cfg_multi_msi_en     (cfg_multi_msi_en   ),
    .cfg_msi_ext_data_en  (cfg_msi_ext_data_en),






    .cfg_tph_req_en      (cfg_tph_req_en    ),
    .cfg_pf_tph_st_mode  (cfg_pf_tph_st_mode),
    .cfg_pf_pasid_en               (cfg_pf_pasid_en             ),
    .cfg_pf_pasid_execute_perm_en  (cfg_pf_pasid_execute_perm_en),
    .cfg_pf_pasid_priv_mode_en     (cfg_pf_pasid_priv_mode_en   ),
    .cfg_atomic_req_en  (cfg_atomic_req_en ),
    .cfg_atomic_egress_block  (cfg_atomic_egress_block ),
    .cfg_dmwr_req_en                (cfg_dmwr_req_en),
    .cfg_obff_en         (cfg_obff_en       ),
    .app_obff_msg_grant  (app_obff_msg_grant),

    .cfg_ltr_m_en        (cfg_ltr_m_en      ),
    .cfg_ltr_max_latency (cfg_ltr_max_latency),
    .cfg_disable_ltr_clr_msg (cfg_disable_ltr_clr_msg),
    .cfg_pwr_budget_data_reg      (cfg_pwr_budget_data_reg    ),
    .cfg_pwr_budget_func_num      (cfg_pwr_budget_func_num    ),
    .cfg_pwr_budget_data_sel_reg  (cfg_pwr_budget_data_sel_reg),
    .cfg_pwr_budget_sel           (cfg_pwr_budget_sel         ),
    .cfg_ari_fwd_en               (cfg_ari_fwd_en             ),
    .ven_msg_fmt       (ven_msg_fmt     ),
    .ven_msg_type      (ven_msg_type    ),
    .ven_msg_tc        (ven_msg_tc      ),
    .ven_msg_td        (ven_msg_td      ),
    .ven_msg_ep        (ven_msg_ep      ),
    .ven_msg_attr      (ven_msg_attr    ),
    .ven_msg_len       (ven_msg_len     ),
    .ven_msg_func_num  (ven_msg_func_num),
    .ven_msg_tag    (ven_msg_tag  ),
    .ven_msg_code   (ven_msg_code ),
    .ven_msg_data   (ven_msg_data ),
    .ven_msg_req    (ven_msg_req  ),
    .ven_msg_grant  (ven_msg_grant),

    .sys_int            (sys_int          ),
    .sys_aux_pwr_det  (sys_aux_pwr_det ),
    .sys_atten_button_pressed   (sys_atten_button_pressed ),
    .sys_pre_det_state          (sys_pre_det_state        ),
    .sys_mrl_sensor_state       (sys_mrl_sensor_state     ),
    .sys_pwr_fault_det          (sys_pwr_fault_det        ),
    .sys_mrl_sensor_chged       (sys_mrl_sensor_chged     ),
    .sys_pre_det_chged          (sys_pre_det_chged        ),
    .sys_cmd_cpled_int          (sys_cmd_cpled_int        ),
    .sys_eml_interlock_engaged  (sys_eml_interlock_engaged),
    .cfg_pwr_ind                (cfg_pwr_ind              ),
    .cfg_atten_ind              (cfg_atten_ind            ),
    .cfg_pwr_ctrler_ctrl        (cfg_pwr_ctrler_ctrl      ),
    .app_unlock_msg             (app_unlock_msg           ),
    .app_obff_idle_msg_req        (app_obff_idle_msg_req      ),
    .app_obff_obff_msg_req        (app_obff_obff_msg_req      ),
    .app_obff_cpu_active_msg_req  (app_obff_cpu_active_msg_req),
    .pm_xtlh_block_tlp  (pm_xtlh_block_tlp),
    .pm_block_all_tlp   (pm_block_all_tlp),
    .cfg_bar0_start  (cfg_bar0_start),
    .cfg_bar1_start  (cfg_bar1_start),
    .cfg_bar0_limit  (cfg_bar0_limit),
    .cfg_bar1_limit  (cfg_bar1_limit),
    .cfg_bar2_start  (cfg_bar2_start),
    .cfg_bar2_limit  (cfg_bar2_limit),
    .cfg_bar3_start  (cfg_bar3_start),
    .cfg_bar3_limit  (cfg_bar3_limit),
    .cfg_bar4_start  (cfg_bar4_start),
    .cfg_bar4_limit  (cfg_bar4_limit),
    .cfg_bar5_start  (cfg_bar5_start),
    .cfg_bar5_limit  (cfg_bar5_limit),
    .cfg_exp_rom_start    (cfg_exp_rom_start  ),
    .cfg_exp_rom_limit    (cfg_exp_rom_limit  ),
    .cfg_bus_master_en    (cfg_bus_master_en  ),
    .cfg_mem_space_en     (cfg_mem_space_en   ),
    .cfg_max_rd_req_size  (cfg_max_rd_req_size),
    .cfg_max_payload_size (cfg_max_payload_size),
    .cfg_memtype_value    (cfg_memtype_value),
    .cfg_memtype_boundary (cfg_memtype_boundary),
    .cfg_ext_tag_en       (cfg_ext_tag_en),
    .cfg_rcb              (cfg_rcb             ),
    .cfg_pm_no_soft_rst   (cfg_pm_no_soft_rst  ),
    .cfg_aer_rc_err_int   (cfg_aer_rc_err_int ),
    .cfg_aer_rc_err_msi   (cfg_aer_rc_err_msi ),
    .cfg_aer_int_msg_num  (cfg_aer_int_msg_num),
    .cfg_sys_err_rc       (cfg_sys_err_rc     ),
    .cfg_pme_int          (cfg_pme_int        ),
    .cfg_pme_msi          (cfg_pme_msi        ),
    .cfg_crs_sw_vis_en    (cfg_crs_sw_vis_en        ),
    .cfg_pcie_cap_int_msg_num  (cfg_pcie_cap_int_msg_num),
    .rdlh_link_up      (rdlh_link_up    ),
    .smlh_ltssm_state  (smlh_ltssm_state_int),
    .ltssm_cxl_enable  (ltssm_cxl_enable),
    .cfg_flit_log_trg_evnt_msi(cfg_flit_log_trg_evnt_msi),

    .cfg_pcie_cap_flit_mode_stat(cfg_pcie_cap_flit_mode_stat),

    .cdm_pm_state_trans_tracker(cdm_pm_state_trans_tracker),
    .pm_cdm_state_trans_tracking(pm_cdm_state_trans_tracking),
    .cfg_flit_latency_msi(cfg_flit_latency_msi),
    .cfg_flit_perf_interr_vec(cfg_flit_perf_interr_vec),
    .cfg_sts_1_ltssm_latency_msi(cfg_sts_1_ltssm_latency_msi),
    .b_cxl_cdm                   ( b_cxl_cdm.master_cdm_mp             ),
    .cxl_ltssm_enable            ( cxl_ltssm_enable                    ),
// Outputs from CXL Register Locator DVSEC
   .cfg_cxl_reg_locator_reg1_bir             (cfg_cxl_reg_locator_reg1_bir),
   .cfg_cxl_reg_locator_reg1_blk_identifier  (cfg_cxl_reg_locator_reg1_blk_identifier),
   .cfg_cxl_reg_locator_reg1_blk_offset_low  (cfg_cxl_reg_locator_reg1_blk_offset_low),
   .cfg_cxl_reg_locator_reg1_blk_offset_high (cfg_cxl_reg_locator_reg1_blk_offset_high),
   .cfg_cxl_reg_locator_reg2_bir             (cfg_cxl_reg_locator_reg2_bir),
   .cfg_cxl_reg_locator_reg2_blk_identifier  (cfg_cxl_reg_locator_reg2_blk_identifier),
   .cfg_cxl_reg_locator_reg2_blk_offset_low  (cfg_cxl_reg_locator_reg2_blk_offset_low),
   .cfg_cxl_reg_locator_reg2_blk_offset_high (cfg_cxl_reg_locator_reg2_blk_offset_high),
   .cfg_cxl_reg_locator_reg3_bir             (cfg_cxl_reg_locator_reg3_bir),
   .cfg_cxl_reg_locator_reg3_blk_identifier  (cfg_cxl_reg_locator_reg3_blk_identifier),
   .cfg_cxl_reg_locator_reg3_blk_offset_low  (cfg_cxl_reg_locator_reg3_blk_offset_low),
   .cfg_cxl_reg_locator_reg3_blk_offset_high (cfg_cxl_reg_locator_reg3_blk_offset_high),
// Outputs from CXL Port GPF DVSEC
   .cfg_cxl_gpf_port_p1_timeout_base         (cfg_cxl_gpf_port_p1_timeout_base),
   .cfg_cxl_gpf_port_p1_timeout_scale        (cfg_cxl_gpf_port_p1_timeout_scale),
   .cfg_cxl_gpf_port_p2_timeout_base         (cfg_cxl_gpf_port_p2_timeout_base),
   .cfg_cxl_gpf_port_p2_timeout_scale        (cfg_cxl_gpf_port_p2_timeout_scale),
    .cxl_dev_cache_invalid       ( cxl_dev_cache_invalid      ),// CXL device indicate cache invalid state
    .cxl_dev_cache_wr_invld_cmpl ( cxl_dev_cache_wr_invld_cmpl),// CXL device indicate cache writeback and invalidation is complete state
    .cxl_volatile_hdm_error      ( cxl_volatile_hdm_error     ),// CXL device indicate Volatile HDM Preservation Error
    .cxl_pm_init_cmpl            ( cxl_pm_init_cmpl       ),   // CXL PM initalization completion state
    .cxl_protocol_cfg            ( cxl_protocol_cfg ),
    .cxl_vlsm_lrsm_req_retrain   ( cxl_vlsm_lrsm_req_retrain  ),    // Pulse: NUM_RETRY reached MAX_NUM_RETRY for Ras D.E.S event counter
    .smlh_link_up      (smlh_link_up    ),
    .smlh_req_rst_not  (smlh_req_rst_not),
    .link_req_rst_not  (link_req_rst_not),
    .brdg_slv_xfer_pending  (brdg_slv_xfer_pending),
    .brdg_dbi_xfer_pending  (brdg_dbi_xfer_pending),
    .brdg_mstr_xfer_pending  (brdg_mstr_xfer_pending),
    .radm_vendor_msg  (radm_vendor_msg),
    .radm_vendor_msg_type (radm_vendor_msg_type),
    .radm_msg_ltr  (radm_msg_ltr),
    .radm_msg_payload  (radm_msg_payload),
    .radm_msg_unlock   (radm_msg_unlock),
    .radm_msg_idle        (radm_msg_idle      ),
    .radm_msg_obff        (radm_msg_obff      ),
    .radm_msg_cpu_active  (radm_msg_cpu_active),
    .radm_msg_req_id      (radm_msg_req_id    ),
    .radm_inta_asserted    (radm_inta_asserted  ),
    .radm_intb_asserted    (radm_intb_asserted  ),
    .radm_intc_asserted    (radm_intc_asserted  ),
    .radm_intd_asserted    (radm_intd_asserted  ),
    .radm_inta_deasserted  (radm_inta_deasserted),
    .radm_intb_deasserted  (radm_intb_deasserted),
    .radm_intc_deasserted  (radm_intc_deasserted),
    .radm_intd_deasserted  (radm_intd_deasserted),
    .radm_correctable_err  (radm_correctable_err),
    .radm_nonfatal_err     (radm_nonfatal_err   ),
    .radm_fatal_err        (radm_fatal_err      ),
    .radm_pm_pme           (radm_pm_pme         ),
    .radm_pm_to_ack        (radm_pm_to_ack      ),
    .radm_pm_turnoff  (radm_pm_turnoff  ),
    .rtlh_rfc_upd   (rtlh_rfc_upd ),
    .rtlh_rfc_data  (rtlh_rfc_data),
    .cfg_eml_control  (cfg_eml_control),
    .hp_pme           (hp_pme         ),
    .hp_int           (hp_int         ),
    .hp_msi           (hp_msi         ),
    .cfg_comm_clk_config    (cfg_comm_clk_config),
    .app_ltssm_enable  (app_ltssm_enable),
    .cfg_pbus_num      (cfg_pbus_num    ),
    .cfg_pbus_dev_num  (cfg_pbus_dev_num),

    .pm_dstate         (pm_dstate       ),
    .pm_status     (pm_status     ),
    .cfg_link_dis          (cfg_link_dis),
    .cfg_link_auto_bw_int  (cfg_link_auto_bw_int),
    .cfg_link_auto_bw_msi  (cfg_link_auto_bw_msi),
    .cfg_bw_mgt_int        (cfg_bw_mgt_int      ),
    .cfg_bw_mgt_msi        (cfg_bw_mgt_msi      ),
    .cfg_link_eq_req_int  (cfg_link_eq_req_int),
    .app_ltr_msg_req       (app_ltr_msg_req     ),
    .app_ltr_msg_grant     (app_ltr_msg_grant   ),
    .app_ltr_msg_latency   (app_ltr_msg_latency ),
    .app_ltr_msg_func_num  (app_ltr_msg_func_num),
    .app_ltr_latency       (app_ltr_latency     ),
    .radm_q_not_empty  (radm_q_not_empty),
    .radm_qoverflow    (radm_qoverflow  ),

    .trgt_cpl_timeout           (trgt_cpl_timeout         ),
    .trgt_timeout_cpl_func_num  (trgt_timeout_cpl_func_num),
    .trgt_timeout_cpl_tc     (trgt_timeout_cpl_tc   ),
    .trgt_timeout_cpl_attr   (trgt_timeout_cpl_attr ),
    .trgt_timeout_cpl_len    (trgt_timeout_cpl_len  ),
    .trgt_timeout_lookup_id  (trgt_timeout_lookup_id),
    .trgt_lookup_id          (trgt_lookup_id        ),
    .trgt_lookup_empty       (trgt_lookup_empty     ),

    .app_hdr_valid  (app_hdr_valid_int),
    .app_hdr_log    (app_hdr_log_int  ),
    .app_hdr_flitmode (app_hdr_flitmode_int),
    .app_hdr_log_size (app_hdr_log_size_int),
    .app_err_bus       (app_err_bus_int     ),
    .app_err_advisory  (app_err_advisory_int),
    .app_poisoned_tlp_type (app_poisoned_tlp_type_int),
    .app_err_func_num  (app_err_func_num_int),
    .phy_cfg_status               (phy_cfg_status              ),
    .mac_phy_txdetectrx_loopback  (mac_phy_txdetectrx_loopback ),
    .mac_phy_rxpolarity           (mac_phy_rxpolarity          ),
    .mac_phy_rate                 (mac_phy_rate                ),
    .mac_phy_txdeemph             (mac_phy_txdeemph            ),
    .cfg_hw_auto_sp_dis           (cfg_hw_auto_sp_dis          ),
    .cfg_phy_control              (pre_cfg_phy_control         ),
    .app_margining_ready            (app_margining_ready),
    .app_margining_software_ready   (app_margining_software_ready),
    .core_clk (core_clk),
    .aux_clk_g             (aux_clk_g            ),
    .radm_clk_g            (radm_clk_g           ),
    .en_radm_clk_g         (en_radm_clk_g        ),
    .radm_idle             (radm_idle            ),
    .pwr_rst_n             (pwr_rst_n            ),
    .sticky_rst_n          (sticky_rst_n         ),
    .non_sticky_rst_n      (non_sticky_rst_n     ),
    .core_rst_n            (core_rst_n           ),
    .pm_sel_aux_clk        (pm_sel_aux_clk       ),
    .device_type_i          (device_type         ),
    .device_type_o          (device_type_o       ),
    .app_req_retry_en      (app_req_retry_en    ),
    .app_pf_req_retry_en   (app_pf_req_retry_en ),
    .app_drs_ready         (app_drs_ready       ),
    .cfg_drs_msi           (cfg_drs_msi         ),
    .cfg_up_drs_to_frs     (cfg_up_drs_to_frs   ),

    .app_pf_frs_ready      (app_pf_frs_ready    ),
    .pf_frs_grant          (pf_frs_grant        ),
    .frsq_msi          (frsq_msi        ),
    .frsq_int_msg_num  (frsq_int_msg_num),


  .radm_formqram_addra_vc0_p            (radm_formqram_addra_vc0_p),
  .radm_formqram_ena_vc0_p              (radm_formqram_ena_vc0_p),
  .radm_formqram_wea_vc0_p              (radm_formqram_wea_vc0_p),
  .radm_formqram_dina_vc0_p             (radm_formqram_dina_vc0_p),
  .radm_formqram_addrb_vc0_p            (radm_formqram_addrb_vc0_p),
  .radm_formqram_enb_vc0_p              (radm_formqram_enb_vc0_p),
  .formqram_radm_doutb_vc0_p            (formqram_radm_doutb_vc0_p),

  .radm_formqram_addra_vc0_np           (radm_formqram_addra_vc0_np ),
  .radm_formqram_ena_vc0_np             (radm_formqram_ena_vc0_np   ),
  .radm_formqram_wea_vc0_np             (radm_formqram_wea_vc0_np   ),
  .radm_formqram_dina_vc0_np            (radm_formqram_dina_vc0_np  ),
  .radm_formqram_addrb_vc0_np           (radm_formqram_addrb_vc0_np ),
  .radm_formqram_enb_vc0_np             (radm_formqram_enb_vc0_np   ),
  .formqram_radm_doutb_vc0_np           (formqram_radm_doutb_vc0_np ),

  .radm_formqram_addra_vc0_cpl          (radm_formqram_addra_vc0_cpl ),
  .radm_formqram_ena_vc0_cpl            (radm_formqram_ena_vc0_cpl   ),
  .radm_formqram_wea_vc0_cpl            (radm_formqram_wea_vc0_cpl   ),
  .radm_formqram_dina_vc0_cpl           (radm_formqram_dina_vc0_cpl  ),
  .radm_formqram_addrb_vc0_cpl          (radm_formqram_addrb_vc0_cpl ),
  .radm_formqram_enb_vc0_cpl            (radm_formqram_enb_vc0_cpl   ),
  .formqram_radm_doutb_vc0_cpl          (formqram_radm_doutb_vc0_cpl ),

  .radm_trgt1_out_p                          (radm_trgt1_out_p),
  .radm_trgt1_p_pending                      (radm_trgt1_p_pending),
  .radm_trgt1_out_np                         (radm_trgt1_out_np),
  .radm_trgt1_out_cpl                        (radm_trgt1_out_cpl),
  .trgt1_radm_intf_p_0_halt                  (trgt1_radm_intf_p_0_halt),
  .trgt1_radm_intf_np_0_halt                 (trgt1_radm_intf_np_0_halt),
  .trgt1_radm_intf_cpl_0_halt                     (trgt1_radm_intf_cpl_0_halt                              ),
  .radm_ras_des_err_info_0                        (s_radm_ras_des_err_info_0),  



    .cdm_ras_des_ec_ram_addra    (cdm_ras_des_ec_ram_addra  ),
    .cdm_ras_des_ec_ram_addrb    (cdm_ras_des_ec_ram_addrb  ),
    .cdm_ras_des_ec_ram_datain   (cdm_ras_des_ec_ram_datain ),
    .cdm_ras_des_ec_ram_wea      (cdm_ras_des_ec_ram_wea    ),
    .cdm_ras_des_ec_ram_ena      (cdm_ras_des_ec_ram_ena    ),
    .cdm_ras_des_ec_ram_enb      (cdm_ras_des_ec_ram_enb    ),
    .cdm_ras_des_ec_ram_dataout  (cdm_ras_des_ec_ram_dataout),

    .cdm_ras_des_tba_ram_addra    (cdm_ras_des_tba_ram_addra  ),
    .cdm_ras_des_tba_ram_addrb    (cdm_ras_des_tba_ram_addrb  ),
    .cdm_ras_des_tba_ram_datain   (cdm_ras_des_tba_ram_datain ),
    .cdm_ras_des_tba_ram_wea      (cdm_ras_des_tba_ram_wea    ),
    .cdm_ras_des_tba_ram_ena      (cdm_ras_des_tba_ram_ena    ),
    .cdm_ras_des_tba_ram_enb      (cdm_ras_des_tba_ram_enb    ),
    .cdm_ras_des_tba_ram_dataout  (cdm_ras_des_tba_ram_dataout),





    .cfg_reg_serren              (cfg_reg_serren       ),
    .cfg_cor_err_rpt_en          (cfg_cor_err_rpt_en   ),
    .cfg_nf_err_rpt_en           (cfg_nf_err_rpt_en    ),
    .cfg_f_err_rpt_en            (cfg_f_err_rpt_en     ),

    .cdm_ras_des_einj0_req   (cdm_ras_des_einj0_req),
    .cdm_ras_des_einj0_ack   (cdm_ras_des_einj0_ack),
    .cdm_ras_des_ec_info_common  (cdm_ras_des_ec_info_common),
    .cdm_ras_des_ec_info_l0      (cdm_ras_des_ec_info_l0    ),
    .cdm_ras_des_ec_info_l1  (cdm_ras_des_ec_info_l1),
    .cdm_ras_des_ec_info_l2  (cdm_ras_des_ec_info_l2),
    .cdm_ras_des_ec_info_l3  (cdm_ras_des_ec_info_l3),
    .cdm_ras_des_ec_info_l4  (cdm_ras_des_ec_info_l4),
    .cdm_ras_des_ec_info_l5  (cdm_ras_des_ec_info_l5),
    .cdm_ras_des_ec_info_l6  (cdm_ras_des_ec_info_l6),
    .cdm_ras_des_ec_info_l7  (cdm_ras_des_ec_info_l7),
    .app_ras_des_sd_hold_ltssm   (app_ras_des_sd_hold_ltssm ),
    .cdm_ras_des_sd_info_common  (cdm_ras_des_sd_info_common),
    .cdm_ras_des_sd_info_l0      (cdm_ras_des_sd_info_l0    ),
    .cdm_ras_des_sd_info_l1      (cdm_ras_des_sd_info_l1    ),
    .cdm_ras_des_sd_info_l2  (cdm_ras_des_sd_info_l2),
    .cdm_ras_des_sd_info_l3  (cdm_ras_des_sd_info_l3),
    .cdm_ras_des_sd_info_l4  (cdm_ras_des_sd_info_l4),
    .cdm_ras_des_sd_info_l5  (cdm_ras_des_sd_info_l5),
    .cdm_ras_des_sd_info_l6  (cdm_ras_des_sd_info_l6),
    .cdm_ras_des_sd_info_l7  (cdm_ras_des_sd_info_l7),
    .cdm_ras_des_sd_info_v0  (cdm_ras_des_sd_info_v0),
    .cdm_ras_des_tba_info_common  (cdm_ras_des_tba_info_common),
    .app_ras_des_tba_ctrl         (app_ras_des_tba_ctrl       ),

    .exp_rom_validation_status_strobe  (exp_rom_validation_status_strobe ),
    .exp_rom_validation_status         (exp_rom_validation_status        ),
    .exp_rom_validation_details_strobe (exp_rom_validation_details_strobe),
    .exp_rom_validation_details        (exp_rom_validation_details       ),
    .cxpl_debug_info        (cxpl_debug_info      )
    ,
    .cfg_vc_enable           (cfg_vc_enable         ),
    .cfg_vc_struc_vc_id_map  (cfg_vc_struc_vc_id_map),
    .cfg_vc_id_vc_struc_map  (cfg_vc_id_vc_struc_map),
    .cfg_tc_enable           (cfg_tc_enable),
    .cfg_tc_struc_vc_map     (cfg_tc_struc_vc_map)
    ,
    .phy_mac_dirfeedback          (phy_mac_dirfeedback        ),
    .phy_mac_fomfeedback          (phy_mac_fomfeedback        ),
    .mac_phy_rxeqeval             (mac_phy_rxeqeval           )
    ,
    .assert_inta_grt    (assert_inta_grt  ),
    .assert_intb_grt    (assert_intb_grt  ),
    .assert_intc_grt    (assert_intc_grt  ),
    .assert_intd_grt    (assert_intd_grt  ),
    .deassert_inta_grt  (deassert_inta_grt),
    .deassert_intb_grt  (deassert_intb_grt),
    .deassert_intc_grt  (deassert_intc_grt),
    .deassert_intd_grt  (deassert_intd_grt),
    .cfg_int_pin        (cfg_int_pin      )

   ,
    .cfg_2ndbus_num  (cfg_2ndbus_num),
    .cfg_subbus_num  (cfg_subbus_num)
   ,.cfg_2nd_reset   (cfg_2nd_reset )
    ,
    .cfg_l1sub_en      (cfg_l1sub_en     )
    ,
    .app_clk_pm_en (app_clk_pm_en)
    ,
    .cfg_end2end_tlp_pfx_blck (cfg_end2end_tlp_pfx_blck)
    ,.aux_clk_active  (aux_clk_active)

    ,.cfg_ido_req_en (cfg_ido_req_en)
    ,.cfg_ido_cpl_en (cfg_ido_cpl_en)

    ,.cfg_send_cor_err   (cfg_send_cor_err  )
    ,.cfg_send_nf_err    (cfg_send_nf_err   )
    ,.cfg_send_f_err     (cfg_send_f_err    )
    ,.cfg_int_disable    (cfg_int_disable   )
    ,.cfg_no_snoop_en    (cfg_no_snoop_en   )
    ,.cfg_relax_order_en (cfg_relax_order_en)

    ,.ptm_context_valid (ptm_context_valid)
    ,.ptm_responder_rdy_to_validate (ptm_responder_rdy_to_validate)
    ,.ptm_local_clock   (ptm_local_clock  )


    ,.ptm_external_master_strobe      (ptm_external_master_strobe     )
    ,.ptm_external_master_time        (ptm_external_master_time       )
    ,.ptm_auto_update_signal  (ptm_auto_update_signal )
    ,.ptm_manual_update_pulse (ptm_manual_update_pulse)
    ,.ptm_clock_updated        (ptm_clock_updated   )
    ,.ptm_clock_correction     (ptm_clock_correction)
    ,.ptm_trigger_allowed      (ptm_trigger_allowed)
    ,.ptm_updating             (ptm_updating)
    ,.ptm_req_response_timeout (ptm_req_response_timeout)
    ,.ptm_req_dup_rx           (ptm_req_dup_rx)
    ,.ptm_req_replay_tx        (ptm_req_replay_tx)
    ,.pm_linkst_in_l0          (pm_linkst_in_l0)
    ,.pm_linkst_in_l0s         (pm_linkst_in_l0s)

    ,.cfg_ats_stu      (cfg_ats_stu     )
    ,.cfg_ats_cache_en (cfg_ats_cache_en)

    ,.surprise_down_err (surprise_down_err)

    ,.prs_res_failure                (prs_res_failure               )
    ,.prs_uprgi                      (prs_uprgi                     )
    ,.prs_stopped                    (prs_stopped                   )
    ,.cfg_prs_enable                 (cfg_prs_enable                )
    ,.cfg_prs_reset                  (cfg_prs_reset                 )
    ,.cfg_prs_stopped                (cfg_prs_stopped               )
    ,.cfg_prs_uprgi                  (cfg_prs_uprgi                 )
    ,.cfg_prs_response_failure       (cfg_prs_response_failure      )
    ,.cfg_prs_outstanding_allocation (cfg_prs_outstanding_allocation)

    ,.cfg_br_ctrl_serren    (cfg_br_ctrl_serren)

    ,.slv_dbi_addr   (slv_dbi_addr)
    ,.slv_dbi_din    (slv_dbi_din )
    ,.slv_dbi_cs     (slv_dbi_cs  )
    ,.slv_dbi_cs2    (slv_dbi_cs2 )
    ,.slv_dbi_wr     (slv_dbi_wr  )
    ,.slv_dbi_func_num (slv_dbi_func_num)
    ,.slv_dbi_bar_num    (slv_dbi_bar_num   )
    ,.slv_dbi_rom_access (slv_dbi_rom_access)
    ,.slv_dbi_io_access  (slv_dbi_io_access )
    ,.slv_lbc_dbi_ack  (slv_lbc_dbi_ack )
    ,.slv_lbc_dbi_dout (slv_lbc_dbi_dout)
    ,.formqram_radm_parerrb    ({`CX_RADM_FORMQ_NQW{1'b0}}             )
    ,.ras_prot_r_disable (ras_prot_r_disable)
    ,.ras_prot_t_disable (ras_prot_t_disable)
    ,.trgt_lookup_id_i        (trgt_lookup_id_i       )




    ,.cfg_rasdp_error_mode_i    (cfg_rasdp_error_mode_i  )
    ,.ras_error_tracer_pending  (ras_error_tracer_pending)
    ,.ras_dp_unc_err            (ras_dp_unc_err)
    ,.ras_dp_cor_err            (ras_dp_cor_err)
    ,.ras_ram_unc_err           (ras_ram_unc_err)
    ,.ras_ram_cor_err           (ras_ram_cor_err)
    ,.axi_bridge_ras_dp_err_log (axi_bridge_ras_dp_err_log)
    ,.out_ras_dp_err_inj        (out_ras_dp_err_inj)
    ,.ras_dp_err_inj_wake_up    (axi_bridge_in_ras_dp_err_inj_wake_up)
    ,.hdma_ras_dp_err_log        (hdma_ras_dp_err_log)
    ,.hdma_ras_dp_err_inj        (hdma_ras_dp_err_inj)
    ,.cfg_rasdp_error_mode_en   (cfg_rasdp_error_mode_en )
    ,.cfg_err_resp       (cfg_err_resp     )
    ,.cfg_order_rule_ctrl          (cfg_order_rule_ctrl       )
    ,.cfg_ax_mstr_ordr_p_event_sel (cfg_ax_mstr_ordr_p_event_sel)
    ,.cfg_ax_snp_en                (cfg_ax_snp_en               )
    ,.cfg_ib_p_id_mng_ctrl         (cfg_ib_p_id_mng_ctrl)
    ,.cfg_mstr_arcache_mode     (cfg_mstr_arcache_mode    )
    ,.cfg_mstr_awcache_mode     (cfg_mstr_awcache_mode    )
    ,.cfg_mstr_arcache_value    (cfg_mstr_arcache_value   )
    ,.cfg_mstr_awcache_value    (cfg_mstr_awcache_value   )
    ,.cfg_aximstr_msg_addr_high (cfg_aximstr_msg_addr_high)
    ,.cfg_aximstr_msg_addr_low  (cfg_aximstr_msg_addr_low )
    ,.cfg_mstr_ardomain_mode   (cfg_mstr_ardomain_mode )
    ,.cfg_mstr_awdomain_mode   (cfg_mstr_awdomain_mode )
    ,.cfg_mstr_ardomain_value  (cfg_mstr_ardomain_value)
    ,.cfg_mstr_awdomain_value  (cfg_mstr_awdomain_value)
    ,.cfg_ax_mstr_zeroread_fw  (cfg_ax_mstr_zeroread_fw)
    ,.cfg_axi_clk_gating_en    (cfg_axi_clk_gating_en)
    ,.int_radm_trgt1_mem_type  (int_radm_trgt1_mem_type)
    ,.atu_reg_out_type         (atu_reg_out_type       )
    ,.atu_reg_out_func_num     (atu_reg_out_func_num   )
    ,.atu_reg_out_func_bypass  (atu_reg_out_func_bypass)
    ,.atu_reg_out_snp          (atu_reg_out_snp        )
    ,.atu_reg_out_en        (atu_reg_out_en      )
    ,.atu_reg_out_base      (atu_reg_out_base    )
    ,.atu_reg_out_upr_base  (atu_reg_out_upr_base)
    ,.atu_reg_out_limit     (atu_reg_out_limit   )
    ,.atu_reg_out_uppr_limit (atu_reg_out_uppr_limit)
    ,.atu_reg_out_incr_rgn_size (atu_reg_out_incr_rgn_size)
    ,.crgb_cdm_rdata (crgb_cdm_rdata)
    ,.crgb_cdm_cs     (crgb_cdm_cs    )
    ,.crgb_cdm_ack    (crgb_cdm_ack   )
    ,.crgb_cdm_addr   (crgb_cdm_addr  )
    ,.crgb_cdm_wdata  (crgb_cdm_wdata )
    ,.crgb_cdm_wr     (crgb_cdm_wr    )
    ,.crgb_cdm_source (crgb_cdm_source)
    ,.radm_trgt1_cpl_lookup_id_rlsd (radm_trgt1_cpl_lookup_id_rlsd)
    ,.radm_trgt1_lookup_id_consmd (radm_trgt1_lookup_id_consmd)


    ,.brdg_slv_flush_ack    (brdg_slv_flush_ack)
    ,.rstctl_slv_flush_req         (rstctl_slv_flush_req )
    ,.rstctl_mstr_flush_req        (rstctl_mstr_flush_req)
    ,.rstctl_flush_done            (rstctl_flush_done)
    ,.pm_current_data_rate_others  (pm_current_data_rate_others)

    ,.client1_tlp_dma          ( '0                    )
    ,.client1_tlp_dma_channel  ( '0                    )
    ,.atu_reg_out_invert       (atu_reg_out_invert)
    ,.cfg_hp_slot_ctrl_access        (cfg_hp_slot_ctrl_access)
    ,.cfg_dll_state_chged_en         (cfg_dll_state_chged_en)
    ,.cfg_cmd_cpled_int_en           (cfg_cmd_cpled_int_en)
    ,.cfg_pre_det_chged_en           (cfg_pre_det_chged_en)
    ,.cfg_mrl_sensor_chged_en        (cfg_mrl_sensor_chged_en)
    ,.cfg_pwr_fault_det_en           (cfg_pwr_fault_det_en)
    ,.cfg_atten_button_pressed_en    (cfg_atten_button_pressed_en)
    ,.cfg_hp_int_en                  (cfg_hp_int_en)
    ,.cfg_acs_validation_en          (cfg_acs_validation_en        )
    ,.cfg_acs_at_blocking_en         (cfg_acs_at_blocking_en       )
    ,.cfg_acs_p2p_req_redirect_en    (cfg_acs_p2p_req_redirect_en  )
    ,.cfg_acs_p2p_compl_redirect_en  (cfg_acs_p2p_compl_redirect_en)
    ,.cfg_acs_up_forward_en          (cfg_acs_up_forward_en        )
    ,.cfg_acs_p2p_egress_ctrl_en     (cfg_acs_p2p_egress_ctrl_en   )
    ,.cfg_acs_p2p_direct_transl_en   (cfg_acs_p2p_direct_transl_en )
    ,.cfg_acs_egress_ctrl_vec        (cfg_acs_egress_ctrl_vec      )

    ,.app_req_flush                  (1'b0)
    ,.cfg_upd_aspm_ctrl              ()
    ,.cfg_aspm_l1_timer_enable       (cfg_aspm_l1_timer_enable)
    ,.cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl)
    ,.cfg_upd_pme_cap                (cfg_upd_pme_cap)
    ,.cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode)
    ,.rstctl_ltssm_enable            (rstctl_ltssm_enable)
    ,.rstctl_core_flush_req          (rstctl_core_flush_req)
    ,.upstream_port                  (upstream_port)
    ,.xdlh_nodllp_pending            (xdlh_nodllp_pending)
    ,.xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack)
    ,.smlh_link_in_training          (smlh_link_in_training)
    ,.xdlh_not_expecting_ack         (xdlh_not_expecting_ack)
    ,.xadm_had_enough_credit         (xadm_had_enough_credit)
    ,.smlh_in_l0                     (smlh_in_l0)
    ,.smlh_in_l0s                    (smlh_in_l0s)
    ,.smlh_in_rl0s                   (smlh_in_rl0s)
    ,.smlh_in_l1                     (smlh_in_l1)
    ,.smlh_in_l23                    (smlh_in_l23)
    ,.xadm_tlp_pending               (xadm_tlp_pending)
    ,.xaim_tlp_pending               (xaim_tlp_pending)
    ,.xtlh_tlp_pending               (xtlh_tlp_pending)
    ,.xadm_no_fc_credit              (xadm_no_fc_credit)
    ,.cfg_aslk_pmctrl                (cfg_aslk_pmctrl)
    ,.cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer)
    ,.cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer)
    ,.cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s)
    ,.cfg_upd_pmcsr                  (cfg_upd_pmcsr)
    ,.cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en)
    ,.cfg_pmstatus_clr               (cfg_pmstatus_clr)
    ,.cfg_pmstate                    (cfg_pmstate)
    ,.cfg_pme_en                     (cfg_pme_en)
    ,.cfg_aux_pm_en                  (cfg_aux_pm_en)
    ,.cfg_upd_req_id                 (cfg_upd_req_id)
    ,.cfg_clk_pm_en                  (cfg_clk_pm_en)
    ,.radm_pm_asnak                  (radm_pm_asnak)
    ,.int_radm_pm_to_ack             (int_radm_pm_to_ack)
    ,.cfg_pme_cap                    (cfg_pme_cap)
    ,.cfg_l1sub_control              (cfg_l1sub_control)
    ,.cfg_pl_l1sub_control           (cfg_pl_l1sub_control)
    ,.cfg_pl_l1_exit_mode            (cfg_pl_l1_exit_mode)
    ,.cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1)
    ,.cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel)
    ,.cfg_p2nobeacon_enable          (cfg_p2nobeacon_enable)
    ,.cfg_utility                    (cfg_utility)
    ,.pm_cfg_utility                 (pm_cfg_utility)
    ,.cfg_pipe_optional_pclkchange_hs(cfg_pipe_optional_pclkchange_hs)
    ,.cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset)
    ,.cfg_phy_rst_timer              (cfg_phy_rst_timer)
    ,.cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer)
    ,.cfg_dsp_pcipm_l1_enter_delay   (cfg_dsp_pcipm_l1_enter_delay)
    ,.cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq)
    ,.cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl)
    ,.pme_to_ack_grt                 (pme_to_ack_grt)
    ,.radm_trgt0_pending             (radm_trgt0_pending)
    ,.lbc_active                     (lbc_active)
    ,.pm_pme_grant                   (pm_pme_grant)
    ,.pme_turn_off_grt               (pme_turn_off_grt)
    ,.int_cfg_pbus_num               (int_cfg_pbus_num)
    ,.int_cfg_pbus_dev_num           (int_cfg_pbus_dev_num)
    ,.msg_gen_asnak_grt              (msg_gen_asnak_grt)
    ,.smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl)
    ,.cfg_link_retrain               (cfg_link_retrain)
    ,.cfg_lpbk_en                    (cfg_lpbk_en)
    ,.cfg_plreg_reset                (cfg_plreg_reset)
    ,.cfg_directed_speed_change      (cfg_directed_speed_change)
    ,.cfg_pl_multilane_control       (cfg_pl_multilane_control)
    ,.msg_gen_unlock_grant           (msg_gen_unlock_grant)
    ,.edma_xfer_pending              (edma_xfer_pending)
    ,.pm_current_data_rate           (int_pm_current_data_rate)
    ,.pm_smlh_l1_exit                (pm_smlh_l1_exit)
    ,.pm_usp_prot_state              (pm_usp_prot_state)
    ,.pm_usp_link_state              (shadow_pm_usp_link_state)
    ,.pm_dsp_prot_state              (pm_dsp_prot_state)
    ,.pm_dsp_link_state              (shadow_pm_dsp_link_state)
    ,.pm_l0s_state                   (pm_l0s_state)
    ,.pm_xmt_asnak                   (pm_xmt_asnak)
    ,.pm_xmt_turnoff                 (pm_xmt_turnoff)
    ,.pm_xmt_to_ack                  (pm_xmt_to_ack)
    ,.pm_xmt_pme                     (pm_xmt_pme)
    ,.pm_turnoff_timeout             (pm_turnoff_timeout)
    ,.pm_bus_num                     (pm_bus_num)
    ,.pm_dev_num                     (pm_dev_num)
    ,.int_phy_txelecidle             (mac_phy_txelecidle)
    ,.pm_pclkack_timeout             (pm_pclkack_timeout)
    ,.l1sub_state                    (pm_l1sub_state)
    ,.pm_in_l11                      (pm_in_l11)
    ,.pm_in_l12                      (pm_in_l12)
    ,.pm_in_l1_short                 (pm_in_l1_short)
    ,.pm_in_l1_cpm                   (pm_in_l1_cpm)
    ,.pm_in_l1_abort                 (pm_in_l1_abort)
    ,.pm_pme_resend_flag             (pm_pme_resend_flag)
    ,.pm_sys_aux_pwr_det             (pm_sys_aux_pwr_det)
    ,.pm_pme_en_split                (pm_pme_en_split)
    ,.pm_aux_pm_en_split             (pm_aux_pm_en_split)
    ,.pm_unlock_msg_req              (pm_unlock_msg_req)
    ,.pm_l1_aspm_entr                (pm_l1_aspm_entr)
    ,.pm_radm_block_tlp              (pm_radm_block_tlp)
    ,.trgt_cpl_lut_empty             (trgt_cpl_lut_empty)
    ,
    .core_in_dpc                        (core_in_dpc),
    .cfg_dpc_int_msg_num                (cfg_dpc_int_msg_num),
    .cfg_dpc_rp_ext_dpc                 (),
    .cfg_dpc_poison_tlp_egr_blk_support (),
    .cfg_dpc_sw_trig_support            (),
    .cfg_dpc_rp_pio_log_size            (),
    .cfg_dpc_dl_active_err_cor_support  (),
    .cfg_dpc_trig_en                    (cfg_dpc_trig_en),
    .cfg_dpc_cpl_cntrl                  (cfg_dpc_cpl_cntrl),
    .cfg_dpc_int_en                     (cfg_dpc_int_en),
    .dpc_int                            (dpc_int),
    .dpc_msi                            (dpc_msi),
    .cfg_dpc_err_cor_en                 (cfg_dpc_err_cor_en),
    .cfg_dpc_poison_tlp_egr_block_en    (cfg_dpc_poison_tlp_egr_block_en),
    .cfg_dpc_sw_trigger                 (cfg_dpc_sw_trigger),
    .cfg_dpc_dl_active_err_cor_en       (cfg_dpc_dl_active_err_cor_en)
    ,.app_dev_num                    (app_dev_num)
    ,.app_bus_num                    (app_bus_num)
    ,.msg_gen_hv                     (msg_gen_hv)
    ,.lbc_cpl_hv                     (lbc_cpl_hv)
    ,.pm_latched_rxdetected        (pm_latched_rxdetected)
    ,.pm_powerdown_status          (pm_powerdown_status)
    ,.cfg_force_powerdown          (cfg_force_powerdown)
    ,
    .cfg_uncor_internal_err_sts         (cfg_uncor_internal_err_sts        ),
    .cfg_rcvr_overflow_err_sts          (cfg_rcvr_overflow_err_sts         ),
    .cfg_fc_protocol_err_sts            (cfg_fc_protocol_err_sts           ),
    .cfg_mlf_tlp_err_sts                (cfg_mlf_tlp_err_sts               ),
    .cfg_surprise_down_er_sts           (cfg_surprise_down_er_sts          ),
    .cfg_dl_protocol_err_sts            (cfg_dl_protocol_err_sts           ),
    .cfg_ecrc_err_sts                   (cfg_ecrc_err_sts                  ),
    .cfg_corrected_internal_err_sts     (cfg_corrected_internal_err_sts    ),
    .cfg_replay_number_rollover_err_sts (cfg_replay_number_rollover_err_sts),
    .cfg_replay_timer_timeout_err_sts   (cfg_replay_timer_timeout_err_sts  ),
    .cfg_bad_dllp_err_sts               (cfg_bad_dllp_err_sts              ),
    .cfg_bad_tlp_err_sts                (cfg_bad_tlp_err_sts               ),
    .cfg_rcvr_err_sts                   (cfg_rcvr_err_sts                  ),
    .cfg_link_capable                   (cfg_link_capable                  ),
    .cfg_advisory_nf_sts                (cfg_advisory_nf_sts               ),
    .cfg_hdr_log_overflow_sts           (cfg_hdr_log_overflow_sts          )



    ,.rplh_flit_unrecognized_flit        (rplh_flit_unrecognized_flit      )
    ,.rplh_flit_ecc_corr_err             (rplh_flit_ecc_corr_err           )
    ,.rplh_flit_ecc_uncorr_err           (rplh_flit_ecc_uncorr_err         )
    ,.rplh_flit_crc_uncorr_err           (rplh_flit_crc_uncorr_err         )

    ,.cfg_pcie_slot_clk_config       (cfg_pcie_slot_clk_config)
    ,.smlh_autoneg_link_sp           (smlh_autoneg_link_sp)
    ,.cfg_neg_link_width            (cfg_neg_link_width             )
    ,.cfg_tx_arb_control            (cfg_tx_arb_control)
    ,.radm_slot_pwr_payload         (radm_slot_pwr_payload)
    ,.radm_slot_pwr_limit           (radm_slot_pwr_limit)
    ,.xdlh_retrybuf_not_empty      (xdlh_retrybuf_not_empty )  

   ,.cfg_p2p_track_cpl_to         (cfg_p2p_track_cpl_to)
   ,.ras_dp_err_log_from_xtlh     (ras_dp_err_log_from_xtlh)
   ,.ras_dp_err_log_from_xdlh     (ras_dp_err_log_from_xdlh)
   ,.ras_dp_err_log_from_xplh     (ras_dp_err_log_from_xplh)
   ,.vlsm_ras_dp_err_log          (vlsm_ras_dp_err_log)
   ,.ras_dp_err_inj               (ras_dp_err_inj)
   ,.smlh_l0p_capable             (smlh_l0p_capable)
   ,.cfg_local_l0p_exit_latency   (cfg_local_l0p_exit_latency)
   ,.cfg_l0p_receiver_support     (cfg_l0p_receiver_support)
   ,.cfg_l0p_enable               (cfg_l0p_enable)
   ,.cfg_l0p_autowidth_dis        (cfg_l0p_autowidth_dis)
   ,.cfg_l0p_priority             (cfg_l0p_priority)
   ,.cfg_l0p_linkmode             (cfg_l0p_linkmode)
   ,.cfg_l0p_linkmode_req         (cfg_l0p_linkmode_req)
   ,.cfg_l0p_max_link_width       (cfg_l0p_max_link_width)
   ,.cfg_l0p_neg_link_width       (cfg_l0p_neg_link_width)
   ,.cfg_pcie_l0p_disable         (cfg_pcie_l0p_disable)
   ,.cfg_pcie_l0p_request         (cfg_pcie_l0p_request)
   ,.cfg_pcie_l0p_priority        (cfg_pcie_l0p_priority)
   ,.cfg_pcie_l0p_linkmode        (cfg_pcie_l0p_linkmode)
   ,.cfg_cxl_l0p_disable          (cfg_cxl_l0p_disable)
   ,.cfg_cxl_l0p_request          (cfg_cxl_l0p_request)
   ,.cfg_cxl_l0p_priority         (cfg_cxl_l0p_priority)
   ,.cfg_cxl_l0p_linkmode         (cfg_cxl_l0p_linkmode)
   ,.cfg_flit_mode_enable         (cfg_flit_mode_enable)
   ,.cfg_pcie_cap_flit_mode_sup   (cfg_pcie_cap_flit_mode_sup)
   ,.cfg_flit_mode_dis            (cfg_flit_mode_dis)
   ,.cfg_flit_sris_clocking       (cfg_flit_sris_clocking)
   ,.cfg_cxl_port_enable          (cfg_cxl_port_enable)
   ,.cfg_cxl_port_vid             (cfg_cxl_port_vid)
   ,.cfg_cxl_retimers_pre_mismatched  (cfg_cxl_retimers_pre_mismatched)
   ,.cfg_retimers_pre_detected    (cfg_retimers_pre_detected)
   ,.cfg_pm_timeout_enable        (cfg_pm_timeout_enable)
   ,.cfg_pm_timeout_value         (cfg_pm_timeout_value)
   ,.cfg_pm_timeout_error         (cfg_pm_timeout_error)
   ,.vlsm_debug_info              (vlsm_debug_info)
   ,.end_device                   (end_device)
   ,.rc_device                    (rc_device)
   ,.cfg_dll_lnk_en               (cfg_dll_lnk_en)
   ,.cfg_ack_freq                 (cfg_ack_freq)
   ,.cfg_ack_latency_timer        (cfg_ack_latency_timer)
   ,.cfg_replay_timer_value       (cfg_replay_timer_value)
   ,.cfg_fc_latency_value         (cfg_fc_latency_value)
   ,.cfg_other_msg_payload        (cfg_other_msg_payload)
   ,.cfg_other_msg_request        (cfg_other_msg_request)
   ,.cfg_corrupt_crc_pattern      (cfg_corrupt_crc_pattern)
   ,.cfg_flow_control_disable     (cfg_flow_control_disable)
   ,.cfg_acknack_disable          (cfg_acknack_disable)
   ,.cfg_scramble_dis             (cfg_scramble_dis)
   ,.cfg_n_fts                    (cfg_n_fts)
   ,.cfg_reset_assert             (cfg_reset_assert)
   ,.cfg_link_num                 (cfg_link_num)
   ,.cfg_ts2_lid_deskew_i         (cfg_ts2_lid_deskew_i)
   ,.cfg_support_part_lanes_rxei_exit  (cfg_support_part_lanes_rxei_exit)
   ,.cfg_forced_link_state        (cfg_forced_link_state)
   ,.cfg_forced_ltssm_cmd         (cfg_forced_ltssm_cmd)
   ,.cfg_force_en                 (cfg_force_en)
   ,.cfg_fast_link_mode           (cfg_fast_link_mode)
   ,.cfg_fast_link_scaling_factor (cfg_fast_link_scaling_factor)
   ,.cfg_l0s_supported            (cfg_l0s_supported)
   ,.cfg_lane_skew                (cfg_lane_skew)
   ,.cfg_deskew_disable           (cfg_deskew_disable)
   ,.cfg_imp_num_lanes            (cfg_imp_num_lanes)
   ,.cfg_skip_interval            (cfg_skip_interval)
   ,.cfg_ext_synch                (cfg_ext_synch)
   ,.cfg_hw_autowidth_dis         (cfg_hw_autowidth_dis)
   ,.cfg_highest_max_payload      (cfg_highest_max_payload)
   ,.cfg_max_payload_size_out_rx  (cfg_max_payload_size_out_rx)
   ,.cfg_fc_wdog_disable          (cfg_fc_wdog_disable)
   ,.cfg_fc_credit_ph             (cfg_fc_credit_ph)
   ,.cfg_fc_credit_nph            (cfg_fc_credit_nph)
   ,.cfg_fc_credit_cplh           (cfg_fc_credit_cplh)
   ,.cfg_fc_credit_pd             (cfg_fc_credit_pd)
   ,.cfg_fc_credit_npd            (cfg_fc_credit_npd)
   ,.cfg_fc_credit_cpld           (cfg_fc_credit_cpld)
   ,.dl_feature_en                (dl_feature_en)
   ,.cfg_remote_feature_ack       (cfg_remote_feature_ack)
   ,.cfg_local_feature_support    (cfg_local_feature_support)
   ,.cfg_dlink_feature_valid      (cfg_dlink_feature_valid)
   ,.hdr_scale_p                  (hdr_scale_p)
   ,.data_scale_p                 (data_scale_p)
   ,.hdr_scale_np                 (hdr_scale_np)
   ,.data_scale_np                (data_scale_np)
   ,.hdr_scale_cpl                (hdr_scale_cpl)
   ,.data_scale_cpl               (data_scale_cpl)
   ,.fc_scaled_en                 (fc_scaled_en)
   ,.cfg_margin_num_timing_steps        (cfg_margin_num_timing_steps)
   ,.cfg_margin_max_timing_offset       (cfg_margin_max_timing_offset)
   ,.cfg_margin_num_voltage_steps       (cfg_margin_num_voltage_steps)
   ,.cfg_margin_max_voltage_offset      (cfg_margin_max_voltage_offset)
   ,.cfg_margin_sample_rate_voltage     (cfg_margin_sample_rate_voltage)
   ,.cfg_margin_sample_rate_timing      (cfg_margin_sample_rate_timing)
   ,.cfg_margin_maxlanes                (cfg_margin_maxlanes)
   ,.cfg_margin_voltage_supported       (cfg_margin_voltage_supported)
   ,.cfg_margin_ind_up_down_voltage     (cfg_margin_ind_up_down_voltage)
   ,.cfg_margin_ind_left_right_timing   (cfg_margin_ind_left_right_timing)
   ,.cfg_margin_sample_reporting_method (cfg_margin_sample_reporting_method)
   ,.cfg_margin_ind_error_sampler       (cfg_margin_ind_error_sampler)
   ,.cfg_rx_message_bus_write_buffer_depth  (cfg_rx_message_bus_write_buffer_depth)
   ,.cfg_pipe_garbage_data_mode             (cfg_pipe_garbage_data_mode)
   ,.cfg_pam4_restricted_levels_requirement (cfg_pam4_restricted_levels_requirement)
   ,.cfg_max_func_num       (cfg_max_func_num)
   ,.cfg_lane_en            (cfg_lane_en)
   ,.cfg_gen1_ei_inference_mode (cfg_gen1_ei_inference_mode)
   ,.cfg_select_deemph_mux_bus  (cfg_select_deemph_mux_bus)
   ,.cfg_lut_ctrl               (cfg_lut_ctrl)
   ,.cfg_rxstandby_control      (cfg_rxstandby_control)
   ,.cfg_pl_gen3_control        (cfg_pl_gen3_control)
   ,.cfg_pl_gen3_eq_control     (cfg_pl_gen3_eq_control)
   ,.cfg_no_seed_value_change   (cfg_no_seed_value_change)
   ,.cfg_fdbk_dirchange_control (cfg_fdbk_dirchange_control)
   ,.cfg_perform_eq             (cfg_perform_eq)
   ,.cfg_ls2_eq_req             (cfg_ls2_eq_req)
   ,.int_cfg_lec_pset_ltx       (int_cfg_lec_pset_ltx)
   ,.int_cfg_lec_pset_lrx       (int_cfg_lec_pset_lrx)
   ,.int_cfg_lec_pset_rtx       (int_cfg_lec_pset_rtx)
   ,.int_cfg_lec_pset_rrx       (int_cfg_lec_pset_rrx)
   ,.cfg_pl_gen4_control        (cfg_pl_gen4_control)
   ,.cfg_pl_gen4_eq_control     (cfg_pl_gen4_eq_control)
   ,.cfg_gen4_fdbk_dirchange_control    (cfg_gen4_fdbk_dirchange_control)
   ,.cfg_lec_g4_pset_lrx        (cfg_lec_g4_pset_lrx)
   ,.cfg_lec_g4_pset_rrx        (cfg_lec_g4_pset_rrx)
   ,.int_cfg_lec_g4_pset_ltx    (int_cfg_lec_g4_pset_ltx)
   ,.int_cfg_lec_g4_pset_rtx    (int_cfg_lec_g4_pset_rtx)
   ,.int_smlh_lec_g4_pset_ltx   (int_smlh_lec_g4_pset_ltx)
   ,.cfg_pl_gen5_control        (cfg_pl_gen5_control)
   ,.cfg_pl_gen5_eq_control     (cfg_pl_gen5_eq_control)
   ,.cfg_gen5_fdbk_dirchange_control    (cfg_gen5_fdbk_dirchange_control)
   ,.cfg_bypass_eq_enable       (cfg_bypass_eq_enable)
   ,.cfg_no_eq_needed_enable    (cfg_no_eq_needed_enable)
   ,.cfg_tx_precode_req         (cfg_tx_precode_req)
   ,.cfg_lec_g5_pset_lrx        (cfg_lec_g5_pset_lrx)
   ,.cfg_lec_g5_pset_rrx        (cfg_lec_g5_pset_rrx)
   ,.int_cfg_lec_g5_pset_ltx    (int_cfg_lec_g5_pset_ltx)
   ,.int_cfg_lec_g5_pset_rtx    (int_cfg_lec_g5_pset_rtx)
   ,.int_smlh_lec_g5_pset_ltx   (int_smlh_lec_g5_pset_ltx)
   ,.cfg_pl_gen6_control        (cfg_pl_gen6_control)
   ,.cfg_pl_gen6_eq_control     (cfg_pl_gen6_eq_control)
   ,.cfg_gen6_fdbk_dirchange_control    (cfg_gen6_fdbk_dirchange_control)
   ,.cfg_g6_tx_precode_req      (cfg_g6_tx_precode_req)
   ,.int_cfg_lec_g6_pset_ltx    (int_cfg_lec_g6_pset_ltx)
   ,.int_cfg_lec_g6_pset_rtx    (int_cfg_lec_g6_pset_rtx)
   ,.int_smlh_lec_g6_pset_ltx   (int_smlh_lec_g6_pset_ltx)
   ,.cfg_alt_protocol_enable    (cfg_alt_protocol_enable)
   ,.cfg_gen2_support           (cfg_gen2_support)
   ,.cfg_gen2_n_fts             (cfg_gen2_n_fts)
   ,.cfg_enter_compliance       (cfg_enter_compliance)
   ,.cfg_sel_de_emphasis        (cfg_sel_de_emphasis)
   ,.cfg_transmit_margin        (cfg_transmit_margin)
   ,.cfg_enter_mod_compliance   (cfg_enter_mod_compliance)
   ,.cfg_compliance_sos         (cfg_compliance_sos)
   ,.cfg_compliance_de_emphasis (cfg_compliance_de_emphasis)
   ,.cfg_pcie_max_link_speed    (cfg_pcie_max_link_speed)
   ,.cfg_target_link_speed      (cfg_target_link_speed)
   ,.cfg_phy_txswing            (cfg_phy_txswing)
   ,.cfg_tx_compliance_rcv      (cfg_tx_compliance_rcv)
   ,.int_rtlh_ph_ca             (int_rtlh_ph_ca)
   ,.int_rtlh_pd_ca             (int_rtlh_pd_ca)
   ,.int_rtlh_nph_ca            (int_rtlh_nph_ca)
   ,.int_rtlh_npd_ca            (int_rtlh_npd_ca)
   ,.int_rtlh_cplh_ca           (int_rtlh_cplh_ca)
   ,.int_rtlh_cpld_ca           (int_rtlh_cpld_ca)
   ,.cfg_rasdp_linkdown_en      (cfg_rasdp_linkdown_en)
   ,.rasdp_linkdown             (rasdp_linkdown)
   ,.xadm_xtlh_pkt              (xadm_xtlh_pkt)
   ,.xtlh_xadm_pkt_halt         (xtlh_xadm_pkt_halt)
   ,.xtlh_xadm_posted_tlp_sent  (xtlh_xadm_posted_tlp_sent)
   ,.xadm_all_type_infinite     (xadm_all_type_infinite)
   ,.cfg_drift_buffer_deskew_enable       (cfg_drift_buffer_deskew_enable)
   ,.correctable_protocol_id_frame_err    (correctable_protocol_id_frame_err)
   ,.uncorrectable_protocol_id_frame_err  (uncorrectable_protocol_id_frame_err)
   ,.unexpected_protocol_id_dropped       (unexpected_protocol_id_dropped)
   ,.ltssm_cxl_mod_ts_phase1_rcvd         (ltssm_cxl_mod_ts_phase1_rcvd)
   ,.ltssm_cxl_retimers_pre_mismatched    (ltssm_cxl_retimers_pre_mismatched)
   ,.ltssm_cxl_flexbus_phase2_mismatched  (ltssm_cxl_flexbus_phase2_mismatched)
   ,.rplh_flit_logging_interface    (rplh_flit_logging_interface)
   ,.rmlh_flit_logging_interface    (rmlh_flit_logging_interface)
   ,.smlh_flit_logging_interface    (smlh_flit_logging_interface)
   ,.cfg_tx_throttling              (cfg_tx_throttling)
   ,.cfg_flit_err_inj_latency         (cfg_flit_err_inj_latency)
   ,.cdm_plh_flit_err_inj_interface   (cdm_plh_flit_err_inj_interface)
   ,.plh_cdm_flit_err_inj_status      (plh_cdm_flit_err_inj_status)
   ,.cfg_os_einj_ctrl_1               (cfg_os_einj_ctrl_1)
   ,.cfg_os_einj_ctrl_2               (cfg_os_einj_ctrl_2)
   ,.xmlh_tx_os_einj_status           (xmlh_tx_os_einj_status)
   ,.cdm_xplh_flit_response_type      (cdm_xplh_flit_response_type)
   ,.cdm_xplh_flit_type_measured      (cdm_xplh_flit_type_measured)
   ,.cdm_xplh_flit_track_mode         (cdm_xplh_flit_track_mode)
   ,.xplh_cdm_flit_latency_tracking   (xplh_cdm_flit_latency_tracking)
   ,.cfg_gen3_eq_fs_lf      (cfg_gen3_eq_fs_lf)
   ,.cfg_gen3_eq_coef       (cfg_gen3_eq_coef)
   ,.cfg_gen4_eq_fs_lf      (cfg_gen4_eq_fs_lf)
   ,.cfg_gen4_eq_coef       (cfg_gen4_eq_coef)
   ,.cfg_gen5_eq_fs_lf      (cfg_gen5_eq_fs_lf)
   ,.cfg_gen5_eq_coef       (cfg_gen5_eq_coef)
   ,.cfg_gen6_eq_fs_lf      (cfg_gen6_eq_fs_lf)
   ,.cfg_gen6_eq_coef       (cfg_gen6_eq_coef)
   ,.cfg_l1sub_t_common_mode          (cfg_l1sub_t_common_mode)
   ,.cfg_max_end2end_tlp_prfxs        (cfg_max_end2end_tlp_prfxs)
   ,.cdm_ras_des_pm_entry_interval        (cdm_ras_des_pm_entry_interval)
   ,.cdm_ras_des_eidle_cnt_sel            (cdm_ras_des_eidle_cnt_sel)
   ,.cdm_ras_des_ltssm_stop               (cdm_ras_des_ltssm_stop)
   ,.cdm_ras_des_recovery_req             (cdm_ras_des_recovery_req)
   ,.cdm_ras_des_ferr_rec_dis             (cdm_ras_des_ferr_rec_dis)
   ,.cdm_ras_des_direct_rcvry_idle_to_cfg (cdm_ras_des_direct_rcvry_idle_to_cfg)
   ,.cdm_ras_des_direct_poll_cmp_to_det   (cdm_ras_des_direct_poll_cmp_to_det)
   ,.cdm_ras_des_direct_lpbk_slave_to_exit  (cdm_ras_des_direct_lpbk_slave_to_exit)
   ,.cdm_ras_des_force_rxdetected_en      (cdm_ras_des_force_rxdetected_en)
   ,.cdm_ras_des_force_linkdown_noack     (cdm_ras_des_force_linkdown_noack)
   ,.cdm_ras_des_ext_eq_to_factor         (cdm_ras_des_ext_eq_to_factor)
   ,.cdm_ras_des_eq_fom_target_en         (cdm_ras_des_eq_fom_target_en)
   ,.cdm_ras_des_eq_force_coef_rtx_en     (cdm_ras_des_eq_force_coef_rtx_en)
   ,.cdm_ras_des_eq_force_pset_lrx_en     (cdm_ras_des_eq_force_pset_lrx_en)
   ,.cdm_ras_des_eq_force_coef_ltx_en     (cdm_ras_des_eq_force_coef_ltx_en)
   ,.cdm_ras_des_eq_force_coef_ltx        (cdm_ras_des_eq_force_coef_ltx)
   ,.cdm_ras_des_eq_force_pset_lrx        (cdm_ras_des_eq_force_pset_lrx)
   ,.cdm_ras_des_eq_force_coef_rtx        (cdm_ras_des_eq_force_coef_rtx)
   ,.cdm_ras_des_eq_force_pset_ltx_en     (cdm_ras_des_eq_force_pset_ltx_en)
   ,.cdm_ras_des_eq_force_usp_pset_ltx    (cdm_ras_des_eq_force_usp_pset_ltx)
   ,.cdm_ras_des_eq_force_coef_rtx_en_g4  (cdm_ras_des_eq_force_coef_rtx_en_g4)
   ,.cdm_ras_des_eq_force_coef_ltx_en_g4  (cdm_ras_des_eq_force_coef_ltx_en_g4)
   ,.cdm_ras_des_eq_force_coef_ltx_g4     (cdm_ras_des_eq_force_coef_ltx_g4)
   ,.cdm_ras_des_eq_force_coef_rtx_g4     (cdm_ras_des_eq_force_coef_rtx_g4)
   ,.cdm_ras_des_eq_force_pset_ltx_en_g4  (cdm_ras_des_eq_force_pset_ltx_en_g4)
   ,.cdm_ras_des_eq_force_usp_pset_ltx_g4 (cdm_ras_des_eq_force_usp_pset_ltx_g4)
   ,.cdm_ras_des_eq_force_coef_rtx_en_g5  (cdm_ras_des_eq_force_coef_rtx_en_g5)
   ,.cdm_ras_des_eq_force_coef_ltx_en_g5  (cdm_ras_des_eq_force_coef_ltx_en_g5)
   ,.cdm_ras_des_eq_force_coef_ltx_g5     (cdm_ras_des_eq_force_coef_ltx_g5)
   ,.cdm_ras_des_eq_force_coef_rtx_g5     (cdm_ras_des_eq_force_coef_rtx_g5)
   ,.cdm_ras_des_eq_force_pset_ltx_en_g5  (cdm_ras_des_eq_force_pset_ltx_en_g5)
   ,.cdm_ras_des_eq_force_usp_pset_ltx_g5 (cdm_ras_des_eq_force_usp_pset_ltx_g5)
   ,.cdm_ras_des_eq_force_coef_rtx_en_g6  (cdm_ras_des_eq_force_coef_rtx_en_g6)
   ,.cdm_ras_des_eq_force_coef_ltx_en_g6  (cdm_ras_des_eq_force_coef_ltx_en_g6)
   ,.cdm_ras_des_eq_force_coef_ltx_g6     (cdm_ras_des_eq_force_coef_ltx_g6)
   ,.cdm_ras_des_eq_force_coef_rtx_g6     (cdm_ras_des_eq_force_coef_rtx_g6)
   ,.cdm_ras_des_eq_force_pset_ltx_en_g6  (cdm_ras_des_eq_force_pset_ltx_en_g6)
   ,.cdm_ras_des_eq_force_usp_pset_ltx_g6 (cdm_ras_des_eq_force_usp_pset_ltx_g6)
   ,.cdm_ras_des_eq_fom_target            (cdm_ras_des_eq_fom_target)
   ,.cdm_ras_des_eq_eval_interval         (cdm_ras_des_eq_eval_interval)
   ,.cdm_ras_des_einj0_enable             (cdm_ras_des_einj0_enable)
   ,.cdm_ras_des_einj0_count              (cdm_ras_des_einj0_count)
   ,.cdm_ras_des_einj0_crc_type           (cdm_ras_des_einj0_crc_type)
   ,.cdm_ras_des_einj1_enable             (cdm_ras_des_einj1_enable)
   ,.cdm_ras_des_einj1_seq_type           (cdm_ras_des_einj1_seq_type)
   ,.cdm_ras_des_einj1_bad_seq            (cdm_ras_des_einj1_bad_seq)
   ,.cdm_ras_des_einj1_count              (cdm_ras_des_einj1_count)
   ,.cdm_ras_des_einj2_enable             (cdm_ras_des_einj2_enable)
   ,.cdm_ras_des_einj2_dllp_type          (cdm_ras_des_einj2_dllp_type)
   ,.cdm_ras_des_einj3_enable             (cdm_ras_des_einj3_enable)
   ,.cdm_ras_des_einj3_count              (cdm_ras_des_einj3_count)
   ,.cdm_ras_des_einj3_smb_type           (cdm_ras_des_einj3_smb_type)
   ,.cdm_ras_des_einj4_enable             (cdm_ras_des_einj4_enable)
   ,.cdm_ras_des_einj4_updfc_type         (cdm_ras_des_einj4_updfc_type)
   ,.cdm_ras_des_einj4_vcnum              (cdm_ras_des_einj4_vcnum)
   ,.cdm_ras_des_einj4_badfc_value        (cdm_ras_des_einj4_badfc_value)
   ,.cdm_ras_des_einj5_enable             (cdm_ras_des_einj5_enable)
   ,.cdm_ras_des_einj5_count              (cdm_ras_des_einj5_count)
   ,.cdm_ras_des_einj5_tlp_type           (cdm_ras_des_einj5_tlp_type)
   ,.smlh_autoneg_link_width              (smlh_autoneg_link_width)
   ,.rplh_link_rxmode                     (rplh_link_rxmode)
   ,.smlh_link_training_in_prog           (smlh_link_training_in_prog)
   ,.latched_flit_mode_enable             (latched_flit_mode_enable)
   ,.smlh_flit_mode_enable                (smlh_flit_mode_enable)
   ,.smlh_bw_mgt_status                   (smlh_bw_mgt_status)
   ,.smlh_link_auto_bw_status             (smlh_link_auto_bw_status)
   ,.smlh_clr_enter_compliance            (smlh_clr_enter_compliance)
   ,.smlh_tx_margin_rst                   (smlh_tx_margin_rst)
   ,.smlh_core_rst_n_release_pulse        (smlh_core_rst_n_release_pulse)
   ,.smlh_dir_spd_chg_rising_edge         (smlh_dir_spd_chg_rising_edge)
   ,.smlh_dir_linkw_chg_started           (smlh_dir_linkw_chg_started)
   ,.smlh_ltssm_in_hotrst_dis_entry       (smlh_ltssm_in_hotrst_dis_entry)
   ,.smlh_ls2_eq_req                      (smlh_ls2_eq_req)
   ,.smlh_ls2_eq_success                  (smlh_ls2_eq_success)
   ,.smlh_ls2_eq_cmpl                     (smlh_ls2_eq_cmpl)
   ,.smlh_ls2_eq_enter                    (smlh_ls2_eq_enter)
   ,.smlh_ltssm_in_detectquiet            (smlh_ltssm_in_detectquiet)
   ,.smlh_ls2_g4_eq_req                   (smlh_ls2_g4_eq_req)
   ,.smlh_ls2_g4_eq_success               (smlh_ls2_g4_eq_success)
   ,.smlh_ls2_g4_eq_cmpl                  (smlh_ls2_g4_eq_cmpl)
   ,.smlh_ls2_g4_eq_enter                 (smlh_ls2_g4_eq_enter)
   ,.smlh_lec_g4_pset_lrx                 (smlh_lec_g4_pset_lrx)
   ,.smlh_retimer_pre_detected            (smlh_retimer_pre_detected)
   ,.smlh_ls2_g5_eq_req                   (smlh_ls2_g5_eq_req)
   ,.smlh_ls2_g5_eq_success               (smlh_ls2_g5_eq_success)
   ,.smlh_ls2_g5_eq_cmpl                  (smlh_ls2_g5_eq_cmpl)
   ,.smlh_ls2_g5_eq_enter                 (smlh_ls2_g5_eq_enter)
   ,.smlh_lec_g5_pset_lrx                 (smlh_lec_g5_pset_lrx)
   ,.smlh_elbc_rcvd                       (smlh_elbc_rcvd)
   ,.smlh_tx_precoding_on                 (smlh_tx_precoding_on)
   ,.smlh_noeq_needed_rcvd                (smlh_noeq_needed_rcvd)
   ,.smlh_ls2_g6_eq_req                   (smlh_ls2_g6_eq_req)
   ,.smlh_ls2_g6_eq_success               (smlh_ls2_g6_eq_success)
   ,.smlh_ls2_g6_eq_cmpl                  (smlh_ls2_g6_eq_cmpl)
   ,.smlh_ls2_g6_eq_enter                 (smlh_ls2_g6_eq_enter)
   ,.smlh_lec_g6_pset_lrx                 (smlh_lec_g6_pset_lrx)
   ,.smlh_g6_tx_precoding_on              (smlh_g6_tx_precoding_on)
   ,.smlh_two_retimers_pre_detected       (smlh_two_retimers_pre_detected)
   ,.smlh_crosslink_resolution            (smlh_crosslink_resolution)
   ,.smlh_margin_ready                    (smlh_margin_ready)
   ,.smlh_mod_ts_rcvd                     (smlh_mod_ts_rcvd)
   ,.mod_ts_data_rcvd                     (mod_ts_data_rcvd)
   ,.mod_ts_data_sent_i                   (mod_ts_data_sent_i)
   ,.rmlh_rcvd_err                        (rmlh_rcvd_err)
   ,.dl_prot_err                          (dl_prot_err)
   ,.rdlh_bad_tlp_err                     (rdlh_bad_tlp_err)
   ,.rdlh_bad_dllp_err                    (rdlh_bad_dllp_err)
   ,.rdlh_dlcntrl_state                   (rdlh_dlcntrl_state)
   ,.rdlh_link_down                       (rdlh_link_down)
   ,.rdlh_rcvd_dl_feature                 (rdlh_rcvd_dl_feature)
   ,.rcvd_dl_feature_content              (rcvd_dl_feature_content)
   ,.replay_num_rlover_err                (replay_num_rlover_err)
   ,.replay_timeout_err                   (replay_timeout_err)
   ,.rtlh_radm                            (rtlh_radm)
   ,.ras_err_inj_en_array                 (ras_err_inj_en_array)
   ,.ras_err_inj_mask                     (ras_err_inj_mask)
   ,.ras_err_inj_done_cx_pl               (ras_err_inj_done_cx_pl)
   ,.rtlh_fc_init_status                  (rtlh_fc_init_status)
   ,.rtlh_crd_not_rtn                     (rtlh_crd_not_rtn)
   ,.rtlh_rcvd_fc                         (rtlh_rcvd_fc)
   ,.retryram_xdlh_depth                  (retryram_xdlh_depth)
   ,.retrysotram_xdlh_depth               (retrysotram_xdlh_depth)
   ,.ras_stat_rdlh_corr                   (ras_stat_rdlh_corr)
   ,.ras_stat_rtlh_corr                   (ras_stat_rtlh_corr)
   ,.ras_stat_rdlh_uncorr                 (ras_stat_rdlh_uncorr)
   ,.ras_stat_rtlh_uncorr                 (ras_stat_rtlh_uncorr)
   ,.cxpl_cdm_ras_des_einj0_ack           (cxpl_cdm_ras_des_einj0_ack)
   ,.rtfcgen_ph_diff                (rtfcgen_ph_diff)
   ,.rtlh_overfl_err                (rtlh_overfl_err)
   ,.xdlh_retry_req                 (xdlh_retry_req)
   ,.rpipe_rxelecidle               (rpipe_rxelecidle)
   ,.rmlh_rpipe_rxoverflow          (rmlh_rpipe_rxoverflow)
   ,.rmlh_rpipe_rxunderflow         (rmlh_rpipe_rxunderflow)
   ,.rmlh_rpipe_rxcodeerror         (rmlh_rpipe_rxcodeerror)
   ,.rmlh_rpipe_rxdisperror         (rmlh_rpipe_rxdisperror)
   ,.rmlh_rpipe_rxskipadded         (rmlh_rpipe_rxskipadded)
   ,.rmlh_rpipe_rxskipremoved       (rmlh_rpipe_rxskipremoved)
   ,.rmlh_skp_parity_err            (rmlh_skp_parity_err)
   ,.rmlh_sync_header_err           (rmlh_sync_header_err)
   ,.rmlh_framing_err               (rmlh_framing_err)
   ,.rmlh_framing_err_ptr           (rmlh_framing_err_ptr)
   ,.rmlh_framing_err_l0            (rmlh_framing_err_l0)
   ,.rmlh_deskew_alignment_err      (rmlh_deskew_alignment_err)
   ,.rmlh_deskew_fifo_ptr           (rmlh_deskew_fifo_ptr)
   ,.rmlh_rxvalid_deasserted        (rmlh_rxvalid_deasserted)
   ,.smlh_eidle_inferred_in_l0      (smlh_eidle_inferred_in_l0)
   ,.smlh_rx_rcvry_req              (smlh_rx_rcvry_req)
   ,.smlh_timeout_nfts              (smlh_timeout_nfts)
   ,.smlh_l0_to_recovery            (smlh_l0_to_recovery)
   ,.smlh_l1_to_recovery            (smlh_l1_to_recovery)
   ,.smlh_rcv_eios_when_l0s_unsprt  (smlh_rcv_eios_when_l0s_unsprt)
   ,.smlh_deskew_uncomplete_err     (smlh_deskew_uncomplete_err)
   ,.smlh_spd_change                (smlh_spd_change)
   ,.smseq_mcs_sts                  (smseq_mcs_sts)
   ,.smlh_lwd_change                (smlh_lwd_change)
   ,.smlh_ltssm_variable            (smlh_ltssm_variable)
   ,.smlh_rxos_type                 (smlh_rxos_type)
   ,.smseq_ts_debug_info            (smseq_ts_debug_info)
   ,.int_ltssm_powerdown            (int_ltssm_powerdown)
   ,.latched_ts_nfts                (latched_ts_nfts)
   ,.init_eq_pending                (init_eq_pending)
   ,.mac_cdm_ras_des_fs             (mac_cdm_ras_des_fs)
   ,.mac_cdm_ras_des_lf             (mac_cdm_ras_des_lf)
   ,.mac_cdm_ras_des_coef_ltx       (mac_cdm_ras_des_coef_ltx)
   ,.phy_cdm_ras_des_fomfeedback    (phy_cdm_ras_des_fomfeedback)
   ,.eqpa_violate_rule_123          (eqpa_violate_rule_123)
   ,.eq_convergence_sts             (eq_convergence_sts)
   ,.mac_cdm_ras_des_coef_rtx       (mac_cdm_ras_des_coef_rtx)
   ,.mac_cdm_ras_des_pset_lrx       (mac_cdm_ras_des_pset_lrx)
   ,.mac_cdm_ras_des_reject_rtx     (mac_cdm_ras_des_reject_rtx)
   ,.init_eq_pending_g4             (init_eq_pending_g4)
   ,.mac_cdm_ras_des_fs_g4          (mac_cdm_ras_des_fs_g4)
   ,.mac_cdm_ras_des_lf_g4          (mac_cdm_ras_des_lf_g4)
   ,.mac_cdm_ras_des_coef_ltx_g4    (mac_cdm_ras_des_coef_ltx_g4)
   ,.phy_cdm_ras_des_fomfeedback_g4 (phy_cdm_ras_des_fomfeedback_g4)
   ,.eqpa_violate_rule_123_g4       (eqpa_violate_rule_123_g4)
   ,.eq_convergence_sts_g4          (eq_convergence_sts_g4)
   ,.mac_cdm_ras_des_coef_rtx_g4    (mac_cdm_ras_des_coef_rtx_g4)
   ,.mac_cdm_ras_des_reject_rtx_g4  (mac_cdm_ras_des_reject_rtx_g4)
   ,.init_eq_pending_g5             (init_eq_pending_g5)
   ,.mac_cdm_ras_des_fs_g5          (mac_cdm_ras_des_fs_g5)
   ,.mac_cdm_ras_des_lf_g5          (mac_cdm_ras_des_lf_g5)
   ,.mac_cdm_ras_des_coef_ltx_g5    (mac_cdm_ras_des_coef_ltx_g5)
   ,.phy_cdm_ras_des_fomfeedback_g5 (phy_cdm_ras_des_fomfeedback_g5)
   ,.eqpa_violate_rule_123_g5       (eqpa_violate_rule_123_g5)
   ,.eq_convergence_sts_g5          (eq_convergence_sts_g5)
   ,.mac_cdm_ras_des_coef_rtx_g5    (mac_cdm_ras_des_coef_rtx_g5)
   ,.mac_cdm_ras_des_reject_rtx_g5  (mac_cdm_ras_des_reject_rtx_g5)
   ,.init_eq_pending_g6             (init_eq_pending_g6)
   ,.mac_cdm_ras_des_fs_g6          (mac_cdm_ras_des_fs_g6)
   ,.mac_cdm_ras_des_lf_g6          (mac_cdm_ras_des_lf_g6)
   ,.mac_cdm_ras_des_coef_ltx_g6    (mac_cdm_ras_des_coef_ltx_g6)
   ,.phy_cdm_ras_des_fomfeedback_g6 (phy_cdm_ras_des_fomfeedback_g6)
   ,.eqpa_violate_rule_123_g6       (eqpa_violate_rule_123_g6)
   ,.eqpa_violate_rule_4_g6         (eqpa_violate_rule_4_g6)
   ,.eq_convergence_sts_g6          (eq_convergence_sts_g6)
   ,.mac_cdm_ras_des_coef_rtx_g6    (mac_cdm_ras_des_coef_rtx_g6)
   ,.mac_cdm_ras_des_reject_rtx_g6  (mac_cdm_ras_des_reject_rtx_g6)
   ,.rl0s_state                     (rl0s_state)
   ,.rdlh_bad_tlp_err_pertlp        (rdlh_bad_tlp_err_pertlp)
   ,.rdlh_lcrc_tlp_err_pertlp       (rdlh_lcrc_tlp_err_pertlp)
   ,.rdlh_nulified_tlp_err_pertlp   (rdlh_nulified_tlp_err_pertlp)
   ,.rdlh_duplicate_tlp_err_pertlp  (rdlh_duplicate_tlp_err_pertlp)
   ,.rdlh_bad_dllp_err_perdllp      (rdlh_bad_dllp_err_perdllp)
   ,.rdlh_rcvd_nack_perdllp         (rdlh_rcvd_nack_perdllp)
   ,.rdlh_rcvd_ack_perdllp          (rdlh_rcvd_ack_perdllp)
   ,.xdlh_nak_sent                  (xdlh_nak_sent)
   ,.xdlh_ack_sent                  (xdlh_ack_sent)
   ,.xdlh_update_fc_sent            (xdlh_update_fc_sent)
   ,.rtlh_req_link_retrain          (rtlh_req_link_retrain)
   ,.rtlh_rcvd_ufc_perdllp          (rtlh_rcvd_ufc_perdllp)
   ,.rtlh_rx_memwr_evt              (rtlh_rx_memwr_evt)
   ,.rtlh_rx_defmemwr_evt           (rtlh_rx_defmemwr_evt)
   ,.rtlh_rx_memrd_evt              (rtlh_rx_memrd_evt)
   ,.rtlh_rx_cfgwr_evt              (rtlh_rx_cfgwr_evt)
   ,.rtlh_rx_cfgrd_evt              (rtlh_rx_cfgrd_evt)
   ,.rtlh_rx_iowr_evt               (rtlh_rx_iowr_evt)
   ,.rtlh_rx_iord_evt               (rtlh_rx_iord_evt)
   ,.rtlh_rx_cplwod_evt             (rtlh_rx_cplwod_evt)
   ,.rtlh_rx_cplwd_evt              (rtlh_rx_cplwd_evt)
   ,.rtlh_rx_msg_evt                (rtlh_rx_msg_evt)
   ,.rtlh_rx_atmcop_evt             (rtlh_rx_atmcop_evt)
   ,.rtlh_rx_tlpwprefix_evt         (rtlh_rx_tlpwprefix_evt)
   ,.rtlh_rx_tlp_dpsize             (rtlh_rx_tlp_dpsize)
   ,.rdlh_vc0_initfc1_status        (rdlh_vc0_initfc1_status)
   ,.rdlh_vc0_initfc2_status        (rdlh_vc0_initfc2_status)
   ,.rdlh_xplh_curnt_rx_ack_seqnum  (rdlh_xplh_curnt_rx_ack_seqnum)
   ,.xdlh_xplh_curnt_seqnum         (xdlh_xplh_curnt_seqnum)
   ,.rtlh_fc_rcvd_ph                (rtlh_fc_rcvd_ph)
   ,.rtlh_fc_rcvd_pd                (rtlh_fc_rcvd_pd)
   ,.rtlh_fc_rcvd_nph               (rtlh_fc_rcvd_nph)
   ,.rtlh_fc_rcvd_npd               (rtlh_fc_rcvd_npd)
   ,.rtlh_fc_rcvd_cplh              (rtlh_fc_rcvd_cplh)
   ,.rtlh_fc_rcvd_cpld              (rtlh_fc_rcvd_cpld)
   ,.rtlh_fc_allctd_ph              (rtlh_fc_allctd_ph)
   ,.rtlh_fc_allctd_pd              (rtlh_fc_allctd_pd)
   ,.rtlh_fc_allctd_nph             (rtlh_fc_allctd_nph)
   ,.rtlh_fc_allctd_npd             (rtlh_fc_allctd_npd)
   ,.rtlh_fc_allctd_cplh            (rtlh_fc_allctd_cplh)
   ,.rtlh_fc_allctd_cpld            (rtlh_fc_allctd_cpld)
   ,.rdlh_einj0_lcrc_evt            (rdlh_einj0_lcrc_evt)
   ,.xmlh_einj0_oscrc_evt           (xmlh_einj0_oscrc_evt)
   ,.xdlh_einj0_lcrc_evt            (xdlh_einj0_lcrc_evt)
   ,.xdlh_einj0_fcrc_evt            (xdlh_einj0_fcrc_evt)
   ,.xdlh_einj0_dllpcrc_evt         (xdlh_einj0_dllpcrc_evt)
   ,.ras_des_einj1_exp_sequm_evt      (ras_des_einj1_exp_sequm_evt)
   ,.ras_des_einj1_ack_nak_sequm_evt  (ras_des_einj1_ack_nak_sequm_evt)
   ,.xdlh_einj2_nak_evt             (xdlh_einj2_nak_evt)
   ,.xmlh_einj3_osmsk_evt           (xmlh_einj3_osmsk_evt)
   ,.rtlh_einj4_fc_evt              (rtlh_einj4_fc_evt)
   ,.xdlh_einj5_nultlp_evt          (xdlh_einj5_nultlp_evt)
   ,.xdlh_einj5_dup_evt             (xdlh_einj5_dup_evt)
   ,.xdlh_ptm_sot           (xdlh_ptm_sot)
   ,.xdlh_ptm_multi_cycle   (xdlh_ptm_multi_cycle)
   ,.xdlh_ptm_request       (xdlh_ptm_request)
   ,.xdlh_ptm_response      (xdlh_ptm_response)
   ,.xdlh_rbuf_replaying    (xdlh_rbuf_replaying)
   ,.rdlh_ptm_sot           (rdlh_ptm_sot)
   ,.rdlh_ptm_multi_cycle   (rdlh_ptm_multi_cycle)
   ,.rdlh_ptm_request       (rdlh_ptm_request)
   ,.rdlh_ptm_response      (rdlh_ptm_response)
   ,.rdlh_duplicate_tlp     (rdlh_duplicate_tlp)
   ,.smlh_ltssm_in_l0p      (smlh_ltssm_in_l0p)
   ,.pm_int_phy_powerdown            (pm_int_phy_powerdown)
   ,.tmp_int_mac_phy_rate            (tmp_int_mac_phy_rate)
   ,.tmp_mac_phy_txdeemph_0          (tmp_mac_phy_txdeemph_0)
   ,.pre_mac_phy_blockaligncontrol_o (pre_mac_phy_blockaligncontrol_o)
   ,.cfg_pipe_loopback      (cfg_pipe_loopback)
   ,.cfg_rxstatus_lane      (cfg_rxstatus_lane)
   ,.cfg_rxstatus_value     (cfg_rxstatus_value)
   ,.cfg_lpbk_rxvalid       (cfg_lpbk_rxvalid)
   ,.int_cfg_margin_control         (int_cfg_margin_control)
   ,.int_smlh_margin_status_valid   (int_smlh_margin_status_valid)
   ,.int_smlh_margin_status         (int_smlh_margin_status)
   ,.int_rmlh_deskew_ctlskp_err     (int_rmlh_deskew_ctlskp_err)
   ,.int_cdm_ras_des_force_rxdetected    (int_cdm_ras_des_force_rxdetected)
   ,.int_rmlh_lane_err        (int_rmlh_lane_err)
   ,.int_smlh_lec_pset_ltx    (int_smlh_lec_pset_ltx)
   ,.int_smlh_lec_pset_lrx    (int_smlh_lec_pset_lrx)
   ,.orig_pipe_rxdata         (orig_pipe_rxdata)
   ,.orig_pipe_rxdatak        (orig_pipe_rxdatak)
   ,.orig_pipe_rxvalid        (orig_pipe_rxvalid)
   ,.orig_pipe_rxdatavalid    (orig_pipe_rxdatavalid)
   ,.orig_pipe_rxstatus       (orig_pipe_rxstatus)
   ,.orig_pipe_rxstartblock   (orig_pipe_rxstartblock)
   ,.orig_pipe_rxsyncheader   (orig_pipe_rxsyncheader)
   ,.phy_mac_phystatus_int          (phy_mac_phystatus_int)
   ,.dpc_fatal_err_gate             (dpc_fatal_err_gate)
   ,.dpc_nonfatal_err_gate          (dpc_nonfatal_err_gate)
   ,.rmlh_prbs_done                 (rmlh_prbs_done)
   ,.rmlh_prbs_fail                 (rmlh_prbs_fail)
   ,.rmlh_prbs_started              (rmlh_prbs_started)
   ,.rmlh_prbs_err_cntr             (rmlh_prbs_err_cntr)
   ,.rmlh_prbs_unexp_fail           (rmlh_prbs_unexp_fail)
   ,.cfg_prbs_en                    (cfg_prbs_en)
   ,.clear_prbs_done                (clear_prbs_done)
   ,.cfg_prbs_lane_sel              (cfg_prbs_lane_sel)
   ,.pcie_link_adm_if               (pcie_link_adm_if)
   ,.b_cfgi_lbc_pcie                (b_cfgi_lbc_pcie.cfgi_slave_mp)
   ,.b_cfgi_lbc_cxl                 (b_cfgi_lbc_cxl.cfgi_slave_mp)


); // u_DWC_pcie_core

cx_top

#( .INST (INST)
) u_cx_pl (
    .cfg_tx_arb_control             (cfg_tx_arb_control),
    .ras_dp_err_log_xtlh            (ras_dp_err_log_from_xtlh),
    .ras_dp_err_log_xdlh            (ras_dp_err_log_from_xdlh),
    .xplh_ras_dp_err_log            (ras_dp_err_log_from_xplh),
    .vlsm_ras_dp_err_log            (vlsm_ras_dp_err_log),
    .ras_dp_err_inj                 (ras_dp_err_inj),
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),
    .cfg_l0p_enable                 (cfg_l0p_enable),
    .cfg_l0p_autowidth_dis          (cfg_l0p_autowidth_dis),
    .cfg_l0p_priority               (cfg_l0p_priority),
    .cfg_l0p_linkmode               (cfg_l0p_linkmode),
    .cfg_l0p_linkmode_req           (cfg_l0p_linkmode_req),
    .cfg_l0p_max_link_width         (cfg_l0p_max_link_width),
    .cfg_l0p_neg_link_width         (cfg_l0p_neg_link_width),
    .cfg_pcie_l0p_disable           (cfg_pcie_l0p_disable),
    .cfg_pcie_l0p_request           (cfg_pcie_l0p_request),
    .cfg_pcie_l0p_priority          (cfg_pcie_l0p_priority),
    .cfg_pcie_l0p_linkmode          (cfg_pcie_l0p_linkmode),
    .app_dynamic_l0p_enable         (cfg_l0p_dynamic_en),
    .app_dynamic_l0p_rejected       (l0p_dynamic_rejected),
    .cfg_flit_mode_enable           (cfg_flit_mode_enable),
    .cfg_pcie_cap_flit_mode_sup     (cfg_pcie_cap_flit_mode_sup),
    .cfg_flit_mode_dis              (cfg_flit_mode_dis),
    .cfg_flit_sris_clocking         (cfg_flit_sris_clocking),
    .cfg_local_l0p_exit_latency     (cfg_local_l0p_exit_latency),
    .cfg_reciver_l0p_supported      (cfg_l0p_receiver_support), // Temporary: Need to change the signal from cfg_l0p_enable to cfg_reciver_l0p_supported
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .pm_block_phystatus             (pm_block_phystatus),
    .pm_prot_req_l2                 (pm_prot_req_l2),
    .vlsm_mc_state                  (vlsm_mc_state),
    .vlsm_io_state                  (vlsm_io_state),
    .b_cxl_vlsm_spif                (b_vlsm_llctrl_mc.master_mp),
    .cfg_cxl_port_enable            (cfg_cxl_port_enable),
    .cfg_cxl_port_vid               (cfg_cxl_port_vid),
    .cfg_cxl_retimers_pre_mismatched (cfg_cxl_retimers_pre_mismatched),
    .cfg_retimers_pre_detected      (cfg_retimers_pre_detected),
    .cfg_pcie_slot_clk_config       (cfg_pcie_slot_clk_config),
    .cfg_vlsm_force_active          ( b_cxl_cdm.s_pl_reg_vlsm_to_active       ),
    .cfg_vlsm_pm_enable             ( b_cxl_cdm.s_pl_reg_vlsm_pm_enable       ),
    .cfg_cxl_io_arb_weight          ( b_cxl_cdm.s_mbar0_arb_mux_cxl_io        ),
    .cfg_cxl_mc_arb_weight          ( b_cxl_cdm.s_mbar0_arb_mux_cxl_cache_mem ),
    .cfg_pm_timeout_enable          ( cfg_pm_timeout_enable                   ),
    .cfg_pm_timeout_value           ( cfg_pm_timeout_value                    ),
    .cfg_pm_timeout_error           ( cfg_pm_timeout_error                    ),
    .vlsm_io_tx_pm_nak              ( vlsm_io_tx_pm_nak                       ),
    .vlsm_mc_tx_pm_nak              ( vlsm_mc_tx_pm_nak                       ),
    .vlsm_io_rx_pm_nak              ( vlsm_io_rx_pm_nak                       ),
    .vlsm_mc_rx_pm_nak              ( vlsm_mc_rx_pm_nak                       ),
    .vlsm_io_rx_pm_req              ( vlsm_io_rx_pm_req                       ),
    .vlsm_mc_rx_pm_req              ( vlsm_mc_rx_pm_req                       ),
    .vlsm_io_pm_timeout             ( vlsm_io_pm_timeout                      ),
    .vlsm_mc_pm_timeout             ( vlsm_mc_pm_timeout                      ),
    .vlsm_ltssm_enable              ( cxl_ltssm_enable                        ),
    .vlsm_debug_info                ( vlsm_debug_info                         ),

    .pm_current_data_rate           (int_pm_current_data_rate),
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .core_clk_ug                    (core_clk_ug),
    .app_init_rst                   (pm_init_rst),                 // only applied to Downstream port
    .app_ltssm_enable               (pm_ltssm_enable),
    .pm_rstctl_core_flush_req       (rstctl_core_flush_req),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .app_sris_mode                  (pm_io_handler_app_sris_mode),
    .cfg_endpoint                   (end_device),
    .cfg_root_compx                 (rc_device),
    .cfg_upstream_port              (upstream_port),
    .cfg_dll_lnk_en                 (cfg_dll_lnk_en),
    .cfg_ack_freq                   (cfg_ack_freq),
    .cfg_ack_latency_timer          (cfg_ack_latency_timer),
    .cfg_replay_timer_value         (cfg_replay_timer_value),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .cfg_other_msg_payload          (cfg_other_msg_payload),
    .cfg_other_msg_request          (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern        (cfg_corrupt_crc_pattern),
    .cfg_flow_control_disable       (cfg_flow_control_disable),
    .cfg_acknack_disable            (cfg_acknack_disable),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode),
    .cfg_scramble_dis               (cfg_scramble_dis),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_link_dis                   (cfg_link_dis),
    .cfg_link_retrain               (pm_smlh_link_retrain),             // Control LTSSM to link recovery
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_reset_assert               (cfg_reset_assert),
    .cfg_link_num                   (cfg_link_num),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew_i),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_forced_link_state          (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),
    .cfg_force_en                   (cfg_force_en),
    .cfg_fast_link_mode             (cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor   (cfg_fast_link_scaling_factor),
    .cfg_l0s_supported              (cfg_l0s_supported),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_lane_skew                  (cfg_lane_skew),
    .cfg_deskew_disable             (cfg_deskew_disable),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_skip_interval              (cfg_skip_interval),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_hw_autowidth_dis           (cfg_hw_autowidth_dis),
    .cfg_max_payload                (cfg_highest_max_payload),
     // In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field
    .cfg_max_payload_rx             (cfg_max_payload_size_out_rx),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .cfg_tc_enable                  (cfg_tc_enable),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),

    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .dl_feature_en                 (dl_feature_en),
    .cfg_remote_feature_ack        (cfg_remote_feature_ack),
    .cfg_local_feature_support     (cfg_local_feature_support),
    .cfg_dlink_feature_valid       (cfg_dlink_feature_valid),
    .hdr_scale_p                   (hdr_scale_p),
    .data_scale_p                  (data_scale_p),
    .hdr_scale_np                  (hdr_scale_np),
    .data_scale_np                 (data_scale_np),
    .hdr_scale_cpl                 (hdr_scale_cpl),
    .data_scale_cpl                (data_scale_cpl),
    .fc_scaled_en                  (fc_scaled_en),
    .cfg_margin_num_timing_steps        (cfg_margin_num_timing_steps),
    .cfg_margin_max_timing_offset       (cfg_margin_max_timing_offset),
    .cfg_margin_num_voltage_steps       (cfg_margin_num_voltage_steps),
    .cfg_margin_max_voltage_offset      (cfg_margin_max_voltage_offset),
    .cfg_margin_sample_rate_voltage     (cfg_margin_sample_rate_voltage),
    .cfg_margin_sample_rate_timing      (cfg_margin_sample_rate_timing),
    .cfg_margin_maxlanes                (cfg_margin_maxlanes),
    .cfg_margin_voltage_supported       (cfg_margin_voltage_supported),
    .cfg_margin_ind_left_right_timing   (cfg_margin_ind_left_right_timing),
    .cfg_margin_ind_up_down_voltage     (cfg_margin_ind_up_down_voltage),
    .cfg_margin_sample_reporting_method (cfg_margin_sample_reporting_method),
    .cfg_margin_ind_error_sampler       (cfg_margin_ind_error_sampler),
    .cfg_rx_message_bus_write_buffer_depth (cfg_rx_message_bus_write_buffer_depth),
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode),
    .cfg_pam4_restricted_levels_requirement (cfg_pam4_restricted_levels_requirement),
    .device_type                    (device_type_o),
    .cfg_lane_en                    (cfg_lane_en),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_pl_gen3_control            (cfg_pl_gen3_control),
    .cfg_pl_gen3_eq_control         (cfg_pl_gen3_eq_control),
    .cfg_no_seed_value_change       (cfg_no_seed_value_change),
    .cfg_fdbk_dirchange_control     (cfg_fdbk_dirchange_control),
    .cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl),
    .cfg_perform_eq                 (cfg_perform_eq),
    .cfg_ls2_eq_req                 (cfg_ls2_eq_req),
    .cfg_pl_gen4_control            (cfg_pl_gen4_control),
    .cfg_pl_gen4_eq_control         (cfg_pl_gen4_eq_control),
    .cfg_gen4_fdbk_dirchange_control(cfg_gen4_fdbk_dirchange_control),
    .cfg_lec_g4_pset_lrx            (cfg_lec_g4_pset_lrx),
    .cfg_lec_g4_pset_rrx            (cfg_lec_g4_pset_rrx),
    .cfg_pl_gen5_control            (cfg_pl_gen5_control),
    .cfg_pl_gen5_eq_control         (cfg_pl_gen5_eq_control),
    .cfg_gen5_fdbk_dirchange_control(cfg_gen5_fdbk_dirchange_control),
    .cfg_pl_gen6_control            (cfg_pl_gen6_control),
    .cfg_pl_gen6_eq_control         (cfg_pl_gen6_eq_control),
    .cfg_gen6_fdbk_dirchange_control(cfg_gen6_fdbk_dirchange_control),
    .cfg_bypass_eq_enable           (cfg_bypass_eq_enable),    // Bypass EQ
    .cfg_no_eq_needed_enable        (cfg_no_eq_needed_enable), // no eq needed
    .cfg_tx_precode_req             (cfg_tx_precode_req),
    .cfg_lec_g5_pset_lrx            (cfg_lec_g5_pset_lrx),
    .cfg_lec_g5_pset_rrx            (cfg_lec_g5_pset_rrx),
    .cfg_lec_g6_pset_lrx            ({`CX_NL{3'h6}}),
    .cfg_lec_g6_pset_rrx            ({`CX_NL{3'h5}}),
    .cfg_g6_tx_precode_req          (cfg_g6_tx_precode_req),
    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable), // Alternate protocol support
    .cfg_pl_multilane_control       (cfg_pl_multilane_control),
    .sticky_rst_n                   (sticky_rst_n),
    .cfg_gen2_support               (cfg_gen2_support),
    .cfg_gen2_n_fts                 (cfg_gen2_n_fts),
    .cfg_enter_compliance           (cfg_enter_compliance),
    .cfg_sel_de_emphasis            (cfg_sel_de_emphasis),
    .cfg_transmit_margin            (cfg_transmit_margin),
    .cfg_enter_mod_compliance       (cfg_enter_mod_compliance),
    .cfg_compliance_sos             (cfg_compliance_sos),
    .cfg_compliance_de_emphasis     (cfg_compliance_de_emphasis),
    .cfg_pcie_max_link_speed        (cfg_pcie_max_link_speed),
    .cfg_target_link_speed          (cfg_target_link_speed),
    .cfg_directed_speed_change      (cfg_directed_speed_change),
    .cfg_phy_txswing                (cfg_phy_txswing),
    .cfg_tx_compliance_rcv          (cfg_tx_compliance_rcv),

    .radm_rtlh_ph_ca                (int_rtlh_ph_ca),
    .radm_rtlh_pd_ca                (int_rtlh_pd_ca),
    .radm_rtlh_nph_ca               (int_rtlh_nph_ca),
    .radm_rtlh_npd_ca               (int_rtlh_npd_ca),
    .radm_rtlh_cplh_ca              (int_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca              (int_rtlh_cpld_ca),

    .cfg_rasdp_linkdown_en          (cfg_rasdp_linkdown_en),
    .cfg_rasdp_error_mode_en        (cfg_rasdp_error_mode_en),
    .rasdp_linkdown                 (rasdp_linkdown),
    .cfg_rasdp_error_mode           (cfg_rasdp_error_mode_i),
    .ras_prot_r_disable             (ras_prot_r_disable[6:0]),
    .ras_prot_t_disable             (ras_prot_t_disable),
    .xadm_xtlh_pkt                  (xadm_xtlh_pkt),
    .xtlh_xadm_pkt_halt             (xtlh_xadm_pkt_halt),
    .xtlh_xadm_posted_tlp_sent      (xtlh_xadm_posted_tlp_sent),
    .pm_smlh_l1_exit                (pm_smlh_l1_exit),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .xadm_all_type_infinite          (xadm_all_type_infinite),
    .phy_mac_dirfeedback               (phy_mac_dirfeedback),
    .phy_mac_fomfeedback               (phy_mac_fomfeedback),
    .mac_phy_powerdown                 (mac_phy_powerdown),
    .phy_mac_phystatus                 (phy_mac_phystatus),
    .pipe_rx_clk                       (pipe_rx_clk),
    .pipe_rx_rst_n                     (pipe_rx_rst_n),
    .phy_mac_rxdata                    (phy_mac_rxdata),
    .phy_mac_rxvalid                   (phy_mac_rxvalid_int),
    .phy_mac_rxstatus                  (phy_mac_rxstatus),
    .phy_mac_rxstandbystatus           (phy_mac_rxstandbystatus),
    .mac_phy_txcompliance              (mac_phy_txcompliance),
    .mac_phy_width                     (mac_phy_width),
    .mac_phy_rate                      (mac_phy_rate),
    .phy_mac_messagebus                (phy_mac_messagebus),
    .pipe_msgbus_rst_n              (pipe_msgbus_rst_n),

    .esm_current_rate               (esm_current_rate),
    .ltssm_cxl_enable               (ltssm_cxl_enable),
    .cfg_drift_buffer_deskew_enable (cfg_drift_buffer_deskew_enable),
    .cxl_link_enable                    (cxl_link_enable),
    .rplh_cxl_corr_pid_err              (correctable_protocol_id_frame_err),
    .rplh_cxl_uncorr_pid_err            (uncorrectable_protocol_id_frame_err),
    .rplh_cxl_unexp_pid_err             (unexpected_protocol_id_dropped),
    .ltssm_cxl_mod_ts_phase1_rcvd       (ltssm_cxl_mod_ts_phase1_rcvd),
    .ltssm_cxl_retimers_pre_mismatched  (ltssm_cxl_retimers_pre_mismatched),
    .ltssm_cxl_flexbus_phase2_mismatched (ltssm_cxl_flexbus_phase2_mismatched),
    .rplh_cdm_flit_logging_interface             (rplh_flit_logging_interface),
    .rmlh_cdm_flit_logging_interface             (rmlh_flit_logging_interface),
    .smlh_cdm_flit_logging_interface             (smlh_flit_logging_interface),
        .cfg_tx_throttling                       (cfg_tx_throttling),
    .cfg_flit_err_inj_latency                (cfg_flit_err_inj_latency),
    .cdm_plh_flit_err_inj_interface          (cdm_plh_flit_err_inj_interface),
    .plh_cdm_flit_err_inj_status             (plh_cdm_flit_err_inj_status),
    .cfg_os_einj_ctrl_1                      (cfg_os_einj_ctrl_1),
    .cfg_os_einj_ctrl_2                      (cfg_os_einj_ctrl_2),
    .xmlh_tx_os_einj_status                  (xmlh_tx_os_einj_status),

    .cdm_xplh_flit_response_type             (cdm_xplh_flit_response_type),
    .cdm_xplh_flit_type_measured             (cdm_xplh_flit_type_measured),
    .cdm_xplh_flit_track_mode                (cdm_xplh_flit_track_mode),
    .xplh_cdm_flit_latency_tracking          (xplh_cdm_flit_latency_tracking),
    .smlh_pm_state_trans1_flag               (smlh_pm_state_trans1_flag),
    .smlh_pm_state_trans2_flag               (smlh_pm_state_trans2_flag),
    .cfg_gen3_eq_fs_lf              (cfg_gen3_eq_fs_lf),
    .cfg_gen3_eq_coef               (cfg_gen3_eq_coef),
    .cfg_gen4_eq_fs_lf              (cfg_gen4_eq_fs_lf),
    .cfg_gen4_eq_coef               (cfg_gen4_eq_coef),
    .cfg_gen5_eq_fs_lf              (cfg_gen5_eq_fs_lf),
    .cfg_gen5_eq_coef               (cfg_gen5_eq_coef),
    .cfg_gen6_eq_fs_lf              (cfg_gen6_eq_fs_lf),
    .cfg_gen6_eq_coef               (cfg_gen6_eq_coef),
    .pm_smlh_l1_2_latched           (pm_smlh_l1_2_latched),
    .pm_smlh_l1_n_latched           (pm_smlh_l1_n_latched),
    .cfg_l1sub_t_common_mode        (cfg_l1sub_t_common_mode),
    .cfg_max_end2end_tlp_prfxs       (cfg_max_end2end_tlp_prfxs),

    .cdm_ras_des_pm_entry_interval      (cdm_ras_des_pm_entry_interval),
    .cdm_ras_des_eidle_cnt_sel          (cdm_ras_des_eidle_cnt_sel),
    .cdm_ras_des_ltssm_stop             (cdm_ras_des_ltssm_stop),
    .cdm_ras_des_recovery_req           (cdm_ras_des_recovery_req),
    .cdm_ras_des_ferr_rec_dis           (cdm_ras_des_ferr_rec_dis),
    .cdm_ras_des_direct_rcvry_idle_to_cfg (cdm_ras_des_direct_rcvry_idle_to_cfg),
    .cdm_ras_des_direct_poll_cmp_to_det (cdm_ras_des_direct_poll_cmp_to_det),
    .cdm_ras_des_direct_lpbk_slave_to_exit (cdm_ras_des_direct_lpbk_slave_to_exit),
    .cdm_ras_des_force_rxdetected_en    (cdm_ras_des_force_rxdetected_en),
    .cdm_ras_des_force_linkdown_noack   (cdm_ras_des_force_linkdown_noack),
    .cdm_ras_des_ext_eq_to_factor       (cdm_ras_des_ext_eq_to_factor),
    .cdm_ras_des_eq_fom_target_en       (cdm_ras_des_eq_fom_target_en),
    .cdm_ras_des_eq_force_coef_rtx_en   (cdm_ras_des_eq_force_coef_rtx_en),
    .cdm_ras_des_eq_force_pset_lrx_en   (cdm_ras_des_eq_force_pset_lrx_en),
    .cdm_ras_des_eq_force_coef_ltx_en   (cdm_ras_des_eq_force_coef_ltx_en),
    .cdm_ras_des_eq_force_coef_ltx      (cdm_ras_des_eq_force_coef_ltx),
    .cdm_ras_des_eq_force_pset_lrx      (cdm_ras_des_eq_force_pset_lrx),
    .cdm_ras_des_eq_force_coef_rtx      (cdm_ras_des_eq_force_coef_rtx),
    .cdm_ras_des_eq_force_pset_ltx_en   (cdm_ras_des_eq_force_pset_ltx_en),
    .cdm_ras_des_eq_force_usp_pset_ltx  (cdm_ras_des_eq_force_usp_pset_ltx),
    .cdm_ras_des_eq_force_coef_rtx_en_g4 (cdm_ras_des_eq_force_coef_rtx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_en_g4 (cdm_ras_des_eq_force_coef_ltx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_g4   (cdm_ras_des_eq_force_coef_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_g4   (cdm_ras_des_eq_force_coef_rtx_g4),
    .cdm_ras_des_eq_force_pset_ltx_en_g4 (cdm_ras_des_eq_force_pset_ltx_en_g4),
    .cdm_ras_des_eq_force_usp_pset_ltx_g4 (cdm_ras_des_eq_force_usp_pset_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_en_g5 (cdm_ras_des_eq_force_coef_rtx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_en_g5 (cdm_ras_des_eq_force_coef_ltx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_g5   (cdm_ras_des_eq_force_coef_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_g5   (cdm_ras_des_eq_force_coef_rtx_g5),
    .cdm_ras_des_eq_force_pset_ltx_en_g5 (cdm_ras_des_eq_force_pset_ltx_en_g5),
    .cdm_ras_des_eq_force_usp_pset_ltx_g5 (cdm_ras_des_eq_force_usp_pset_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_en_g6 (cdm_ras_des_eq_force_coef_rtx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_en_g6 (cdm_ras_des_eq_force_coef_ltx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_g6   (cdm_ras_des_eq_force_coef_ltx_g6),
    .cdm_ras_des_eq_force_coef_rtx_g6   (cdm_ras_des_eq_force_coef_rtx_g6),
    .cdm_ras_des_eq_force_pset_ltx_en_g6 (cdm_ras_des_eq_force_pset_ltx_en_g6),
    .cdm_ras_des_eq_force_usp_pset_ltx_g6 (cdm_ras_des_eq_force_usp_pset_ltx_g6),
    .cdm_ras_des_eq_fom_target          (cdm_ras_des_eq_fom_target),
    .cdm_ras_des_eq_eval_interval       (cdm_ras_des_eq_eval_interval),
    .cdm_ras_des_einj0_enable           (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_count            (cdm_ras_des_einj0_count),
    .cdm_ras_des_einj0_crc_type         (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj1_enable           (cdm_ras_des_einj1_enable),
    .cdm_ras_des_einj1_seq_type         (cdm_ras_des_einj1_seq_type),
    .cdm_ras_des_einj1_bad_seq          (cdm_ras_des_einj1_bad_seq),
    .cdm_ras_des_einj1_count            (cdm_ras_des_einj1_count),
    .cdm_ras_des_einj2_enable           (cdm_ras_des_einj2_enable),
    .cdm_ras_des_einj2_dllp_type        (cdm_ras_des_einj2_dllp_type),
    .cdm_ras_des_einj3_enable           (cdm_ras_des_einj3_enable),
    .cdm_ras_des_einj3_count            (cdm_ras_des_einj3_count),
    .cdm_ras_des_einj3_smb_type         (cdm_ras_des_einj3_smb_type),
    .cdm_ras_des_einj4_enable           (cdm_ras_des_einj4_enable),
    .cdm_ras_des_einj4_updfc_type       (cdm_ras_des_einj4_updfc_type),
    .cdm_ras_des_einj4_vcnum            (cdm_ras_des_einj4_vcnum),
    .cdm_ras_des_einj4_badfc_value      (cdm_ras_des_einj4_badfc_value),
    .cdm_ras_des_einj5_enable           (cdm_ras_des_einj5_enable),
    .cdm_ras_des_einj5_count            (cdm_ras_des_einj5_count),
    .cdm_ras_des_einj5_tlp_type         (cdm_ras_des_einj5_tlp_type),
    .pm_current_powerdown_p1            (pm_current_powerdown_p1),
    .pm_current_powerdown_p0            (pm_current_powerdown_p0),
    .pm_int_phy_powerdown               (pm_int_phy_powerdown),
    .pm_rx_lane_flip_en                (pm_rx_lane_flip_en),
    .pm_tx_lane_flip_en                (pm_tx_lane_flip_en),
    .pm_rx_pol_lane_flip_ctrl          (pm_rx_pol_lane_flip_ctrl),
    .tx_lane_flip_en                   (tx_lane_flip_en),
    .cfg_pm_clk_pm_en                  (cfg_pm_clk_pm_en),
    .software_entr_l1                  (software_entr_l1),
    .software_entr_l23                 (software_entr_l23),
    .pm_aspm_l0s_en                    (pm_aspm_l0s_en),
    .pm_aspm_l1_en                     (pm_aspm_l1_en),
    .cfg_pl_l1_nowait_p1               (cfg_pl_l1_nowait_p1),
    .pm_linkst_in_l0s                  (pm_linkst_in_l0s_o),
    .pm_hold_exit_l1                   (pm_hold_exit_l1),
    .pm_link_exit_l1                   (pm_link_exit_l1),
    .pm_link_exit_l23                  (pm_link_exit_l23),
    .pm_pl_wake_ack                    (pm_pl_wake_ack),
    .pm_pl_clk_req                     (pm_pl_clk_req),
    .pm_pl_phyinl1                     (pm_pl_phyinl1),
    .pm_pl_phyinl2                     (pm_pl_phyinl2),
    .pm_usp_link_state                 (pm_usp_link_state),
    .pm_dsp_link_state                 (pm_dsp_link_state),
    .lbc_active                        (lbc_active),
    .pm_wake_req_exit_l0s              (pm_wake_req_exit_l0s),
    .xadm_tlp_pending                  (xadm_tlp_pending),
    .xaim_tlp_pending                  (xaim_tlp_pending),
    .msg_gen_asnak_grt                 (msg_gen_asnak_grt),
    .pm_l2_entry_flag                  (pm_l2_entry_flag),
    .l0s_entr_latency_timer            (cfg_l0s_entr_latency_timer),
    .l1_entr_latency_timer             (cfg_l1_entr_latency_timer),
    .pm_l1_entr_wo_rl0s                (cfg_l1_entr_wo_rl0s),
    .pm_aspm_l1_timer_enable           (cfg_aspm_l1_timer_enable),
    .xtlh_had_enough_credit            (xadm_had_enough_credit),
    .xadm_no_fc_credit                 (xadm_no_fc_credit),
    .radm_pm_asnak                     (radm_pm_asnak),
    .app_req_entr_l1                   (app_req_entr_l1),
    .radm_trgt0_pending                (radm_trgt0_pending),
    .pm_wake_any_if_pending            (pm_wake_any_if_pending),
    .app_xfer_pending                  (app_xfer_pending),
    .cfg_dsp_pcipm_l1_enter_delay      (cfg_dsp_pcipm_l1_enter_delay),
    .pcie_link_adm_if                  (pcie_link_adm_if),
    .lp_pcie_l1_exit                   (lp_pcie_l1_exit),
    .lp_pcie_clk_ack                   (lp_pcie_clk_ack),
    .lp_pcie_wake_req                  (lp_pcie_wake_req),
    .pl_pcie_wake_ack                  (pl_pcie_wake_ack),
    .pl_pcie_clk_req                   (pl_pcie_clk_req),
    .pl_pcie_phyinl1                   (pl_pcie_phyinl1),
    .pl_pcie_phyinl2                   (pl_pcie_phyinl2),
    .pl_pcie_state_l1                  (pl_pcie_state_l1),
    .pl_pcie_state_l2                  (pl_pcie_state_l2),
    .pl_pcie_state_active              (pl_pcie_state_active),
    .pl_pcie_link_up                   (pl_pcie_link_up),
    .pl_cxl_wake_ack                   (pl_cxl_wake_ack),
    .pl_cxl_clk_req                    (pl_cxl_clk_req),
    .pl_cxl_phyinl1                    (pl_cxl_phyinl1),
    .pl_cxl_phyinl2                    (pl_cxl_phyinl2),
    .pl_cxl_state_l1                   (pl_cxl_state_l1),
    .pl_cxl_state_l2                   (pl_cxl_state_l2),
    .pl_cxl_mode_enable                (pl_cxl_mode_enable),
    .pm_xmt_asnak                      (pm_xmt_asnak),
    .pm_block_all_tlp                  (pm_block_all_tlp),
    .pm_l1_aspm_entr                   (pm_l1_aspm_entr),
    .pm_xdlh_enter_l23                 (pm_xdlh_enter_l23),
    .pm_l1_entry_started               (pm_l1_entry_started),
    .pm_l1_in_progress                 (pm_l1_in_progress),
    .pm_aspm_l1_enter_ready            (pm_aspm_l1_enter_ready),
    .latch_as_entr_l1                  (latch_as_entr_l1),
    .pm_prot_idle_flag                 (pm_prot_idle_flag),
    .lp_sdb_l1sub_aspm                 (lp_sdb_l1sub_aspm),
    .lp_sdb_l1sub_pcipm                (lp_sdb_l1sub_pcipm),
    .pm_usp_prot_state                 (pm_usp_prot_state),
    .pm_dsp_prot_state                 (pm_dsp_prot_state),
    .pm_l0s_state                      (pm_l0s_state     ),
    .smlh_ltssm_state               (smlh_ltssm_state_int),
    .smlh_ltssm_state_o             (smlh_ltssm_state),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .rplh_link_rxmode               (rplh_link_rxmode),
    .smlh_training_rst_n            (training_rst_n),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .smlh_link_up                   (smlh_link_up),
    .latched_flit_mode_enable       (latched_flit_mode_enable),
    .smlh_flit_mode_enable          (smlh_flit_mode_enable),
    .smlh_l0p_capable               (smlh_l0p_capable),
    .xmlh_sris_enable               (xmlh_sris_enable),
    .smlh_req_rst_not               (smlh_req_rst_not),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .smlh_clr_enter_compliance      (smlh_clr_enter_compliance),
    .smlh_tx_margin_rst             (smlh_tx_margin_rst),
    .smlh_core_rst_n_release_pulse  (smlh_core_rst_n_release_pulse),
    .smlh_dir_spd_chg_rising_edge   (smlh_dir_spd_chg_rising_edge),
    .smlh_dir_linkw_chg_started     (smlh_dir_linkw_chg_started),
    .smlh_ltssm_in_hotrst_dis_entry (smlh_ltssm_in_hotrst_dis_entry),
    .smlh_ls2_eq_req                (smlh_ls2_eq_req),
    .smlh_ls2_eq_success            (smlh_ls2_eq_success),
    .smlh_ls2_eq_cmpl               (smlh_ls2_eq_cmpl),
    .smlh_ls2_eq_enter              (smlh_ls2_eq_enter),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_ltssm_state_rcvry_eq      (smlh_ltssm_state_rcvry_eq),
    .usp_g3_eq_redo_executed_int    (usp_g3_eq_redo_executed_int),     // USP gen3 eq redo executed interrupt
    .usp_g4_eq_redo_executed_int    (usp_g4_eq_redo_executed_int),     // USP gen4 eq redo executed interrupt
    .usp_g5_eq_redo_executed_int    (usp_g5_eq_redo_executed_int),     // USP gen5 eq redo executed interrupt
    .smlh_ls2_g4_eq_req             (smlh_ls2_g4_eq_req),
    .smlh_ls2_g4_eq_success         (smlh_ls2_g4_eq_success),
    .smlh_ls2_g4_eq_cmpl            (smlh_ls2_g4_eq_cmpl),
    .smlh_ls2_g4_eq_enter           (smlh_ls2_g4_eq_enter),
    .smlh_lec_g4_pset_lrx           (smlh_lec_g4_pset_lrx),
    .smlh_retimer_pre_detected      (smlh_retimer_pre_detected),
    .smlh_ls2_g5_eq_req             (smlh_ls2_g5_eq_req),
    .smlh_ls2_g5_eq_success         (smlh_ls2_g5_eq_success),
    .smlh_ls2_g5_eq_cmpl            (smlh_ls2_g5_eq_cmpl),
    .smlh_ls2_g5_eq_enter           (smlh_ls2_g5_eq_enter),
    .smlh_lec_g5_pset_lrx           (smlh_lec_g5_pset_lrx),
    .smlh_elbc_rcvd                 (smlh_elbc_rcvd),
    .smlh_tx_precoding_on           (smlh_tx_precoding_on),
    .smlh_noeq_needed_rcvd          (smlh_noeq_needed_rcvd),
    .smlh_ls2_g6_eq_req             (smlh_ls2_g6_eq_req),
    .smlh_ls2_g6_eq_success         (smlh_ls2_g6_eq_success),
    .smlh_ls2_g6_eq_cmpl            (smlh_ls2_g6_eq_cmpl),
    .smlh_ls2_g6_eq_enter           (smlh_ls2_g6_eq_enter),
    .smlh_lec_g6_pset_lrx           (smlh_lec_g6_pset_lrx),
    .smlh_g6_tx_precoding_on        (smlh_g6_tx_precoding_on),
    .smlh_two_retimers_pre_detected (smlh_two_retimers_pre_detected),
    .smlh_crosslink_resolution      (smlh_crosslink_resolution),
    .smlh_margin_ready              (smlh_margin_ready),
    .smlh_mod_ts_rcvd               (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd               (mod_ts_data_rcvd),
    .mod_ts_data_sent               (mod_ts_data_sent_i),
    .rmlh_rcvd_err                  (rmlh_rcvd_err),
    .rmlh_descrambled_even_parity   (rmlh_descrambled_even_parity),
    .xmlh_scramble_even_parity      (xmlh_scramble_even_parity),

    .dl_prot_err                    (dl_prot_err),
    .rdlh_bad_tlp_err               (rdlh_bad_tlp_err),
    .rdlh_bad_dllp_err              (rdlh_bad_dllp_err),
    .rdlh_rtlh_link_state           (rdlh_dlcntrl_state),
    .rdlh_link_up                   (rdlh_link_up),
    .rdlh_link_down                 (rdlh_link_down),

    .rdlh_rcvd_dl_feature           (rdlh_rcvd_dl_feature),
    .rcvd_dl_feature_content        (rcvd_dl_feature_content),

    .xdlh_xplh_replay_num_rlover_err(replay_num_rlover_err),
    .xdlh_xplh_replay_timeout       (replay_timeout_err),
    .xdlh_retrybuf_not_empty        (xdlh_retrybuf_not_empty),
    .xdlh_nodllp_pending            (xdlh_nodllp_pending),
    .xdlh_not_expecting_ack         (xdlh_not_expecting_ack),
    .xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack),

    .rtlh_radm                      (rtlh_radm),
    .ras_err_inj_en_array           (ras_err_inj_en_array),
    .ras_err_inj_mask               (ras_err_inj_mask),
    .ras_err_inj_done               (ras_err_inj_done_cx_pl),
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn),
    .rtlh_rfc                       (rtlh_rcvd_fc),
    .xtlh_tlp_pending               (xtlh_tlp_pending),

    .current_data_rate              (current_data_rate),
    .pm_current_data_rate_others    (pm_current_data_rate_others),
    // Retry buffer external RAM interface

    .xdlh_retryram_par_chk_val      (   ),

    .xdlh_retryram_raddr            (xdlh_retryram_raddr),
    .xdlh_retryram_waddr            (xdlh_retryram_waddr),
    .xdlh_retryram_data             (xdlh_retryram_data),
    .xdlh_retryram_we               (xdlh_retryram_we),
    .xdlh_retryram_en               (xdlh_retryram_en),

    .retryram_xdlh_data             (retryram_xdlh_data),
    .retryram_xdlh_depth            (retryram_xdlh_depth),
    .retryram_xdlh_parerr           ({1{1'b0}}),
    .xdlh_retrysotram_waddr         (xdlh_retrysotram_waddr),
    .xdlh_retrysotram_raddr         (xdlh_retrysotram_raddr),
    .xdlh_retrysotram_data          (xdlh_retrysotram_data),
    .xdlh_retrysotram_en            (xdlh_retrysotram_en),
    .xdlh_retrysotram_we            (xdlh_retrysotram_we),
    .xdlh_retrysotram_par_chk_val   (   ),

    .retrysotram_xdlh_depth         (retrysotram_xdlh_depth),
    .retrysotram_xdlh_parerr        ({1{1'b0}}),
    .retrysotram_xdlh_data          (retrysotram_xdlh_data),
    .ras_stat_rdlh_corr             (ras_stat_rdlh_corr   ),
    .ras_stat_rtlh_corr             (ras_stat_rtlh_corr   ),
    .ras_stat_rdlh_uncorr           (ras_stat_rdlh_uncorr ),
    .ras_stat_rtlh_uncorr           (ras_stat_rtlh_uncorr ),
    .cdm_ras_des_einj0_req          (cdm_ras_des_einj0_req),
    .cdm_ras_des_einj0_ack          (cxpl_cdm_ras_des_einj0_ack),
    // signals for debug purpose
    .cxpl_debug_info                (cxpl_debug_info),
    .cxpl_debug_info_ei             (cxpl_debug_info_ei),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff),
    .rtlh_overfl_err                (rtlh_overfl_err),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),
    .retry_flit                     (xdlh_retry_req),
    .latched_rxdetected             (latched_rxdetected),
    .rpipe_rxelecidle               (rpipe_rxelecidle),
    .rmlh_rpipe_rxoverflow          (rmlh_rpipe_rxoverflow),
    .rmlh_rpipe_rxunderflow         (rmlh_rpipe_rxunderflow),
    .rmlh_rpipe_rxcodeerror         (rmlh_rpipe_rxcodeerror),
    .rmlh_rpipe_rxdisperror         (rmlh_rpipe_rxdisperror),
    .rmlh_rpipe_rxskipadded         (rmlh_rpipe_rxskipadded),
    .rmlh_rpipe_rxskipremoved       (rmlh_rpipe_rxskipremoved),
    .rmlh_skp_parity_err            (rmlh_skp_parity_err),
    .rmlh_sync_header_err           (rmlh_sync_header_err),
    .rmlh_framing_err               (rmlh_framing_err),
    .rmlh_framing_err_ptr           (rmlh_framing_err_ptr),
    .rmlh_framing_err_l0            (rmlh_framing_err_l0),
    .rmlh_deskew_alignment_err      (rmlh_deskew_alignment_err),
    .rmlh_deskew_fifo_ptr           (rmlh_deskew_fifo_ptr),
    .rmlh_rxvalid_deasserted        (rmlh_rxvalid_deasserted),
    .smlh_eidle_inferred_in_l0      (smlh_eidle_inferred_in_l0),
    .smlh_rx_rcvry_req              (smlh_rx_rcvry_req),
    .smlh_timeout_nfts              (smlh_timeout_nfts),
    .smlh_l0_to_recovery            (smlh_l0_to_recovery),
    .smlh_l1_to_recovery            (smlh_l1_to_recovery),
    .smlh_rcv_eios_when_l0s_unsprt  (smlh_rcv_eios_when_l0s_unsprt),
    .smlh_deskew_uncomplete_err     (smlh_deskew_uncomplete_err),
    .smlh_spd_change                (smlh_spd_change),
    .smseq_mcs_sts                  (smseq_mcs_sts),
    .smlh_lwd_change                (smlh_lwd_change),
    .smlh_ltssm_variable            (smlh_ltssm_variable),
    .smlh_rxos_type                 (smlh_rxos_type),
    .smseq_ts_debug_info            (smseq_ts_debug_info),
    .int_ltssm_powerdown            (int_ltssm_powerdown),
    .latched_ts_nfts                (latched_ts_nfts),
    .init_eq_pending                (init_eq_pending),
    .mac_cdm_ras_des_fs             (mac_cdm_ras_des_fs),
    .mac_cdm_ras_des_lf             (mac_cdm_ras_des_lf),
    .mac_cdm_ras_des_coef_ltx       (mac_cdm_ras_des_coef_ltx),
    .phy_cdm_ras_des_fomfeedback    (phy_cdm_ras_des_fomfeedback),
    .eqpa_violate_rule_123          (eqpa_violate_rule_123),
    .eq_convergence_sts             (eq_convergence_sts),
    .mac_cdm_ras_des_coef_rtx       (mac_cdm_ras_des_coef_rtx),
    .mac_cdm_ras_des_pset_lrx       (mac_cdm_ras_des_pset_lrx),
    .mac_cdm_ras_des_reject_rtx     (mac_cdm_ras_des_reject_rtx),
    .init_eq_pending_g4             (init_eq_pending_g4),
    .mac_cdm_ras_des_fs_g4          (mac_cdm_ras_des_fs_g4),
    .mac_cdm_ras_des_lf_g4          (mac_cdm_ras_des_lf_g4),
    .mac_cdm_ras_des_coef_ltx_g4    (mac_cdm_ras_des_coef_ltx_g4),
    .phy_cdm_ras_des_fomfeedback_g4 (phy_cdm_ras_des_fomfeedback_g4),
    .eqpa_violate_rule_123_g4       (eqpa_violate_rule_123_g4),
    .eq_convergence_sts_g4          (eq_convergence_sts_g4),
    .mac_cdm_ras_des_coef_rtx_g4    (mac_cdm_ras_des_coef_rtx_g4),
    .mac_cdm_ras_des_reject_rtx_g4  (mac_cdm_ras_des_reject_rtx_g4),
    .init_eq_pending_g5             (init_eq_pending_g5),
    .mac_cdm_ras_des_fs_g5          (mac_cdm_ras_des_fs_g5),
    .mac_cdm_ras_des_lf_g5          (mac_cdm_ras_des_lf_g5),
    .mac_cdm_ras_des_coef_ltx_g5    (mac_cdm_ras_des_coef_ltx_g5),
    .phy_cdm_ras_des_fomfeedback_g5 (phy_cdm_ras_des_fomfeedback_g5),
    .eqpa_violate_rule_123_g5       (eqpa_violate_rule_123_g5),
    .eq_convergence_sts_g5          (eq_convergence_sts_g5),
    .mac_cdm_ras_des_coef_rtx_g5    (mac_cdm_ras_des_coef_rtx_g5),
    .mac_cdm_ras_des_reject_rtx_g5  (mac_cdm_ras_des_reject_rtx_g5),
    .init_eq_pending_g6             (init_eq_pending_g6),
    .mac_cdm_ras_des_fs_g6          (mac_cdm_ras_des_fs_g6),
    .mac_cdm_ras_des_lf_g6          (mac_cdm_ras_des_lf_g6),
    .mac_cdm_ras_des_coef_ltx_g6    (mac_cdm_ras_des_coef_ltx_g6),
    .phy_cdm_ras_des_fomfeedback_g6 (phy_cdm_ras_des_fomfeedback_g6),
    .eqpa_violate_rule_123_g6       (eqpa_violate_rule_123_g6),
    .eqpa_violate_rule_4_g6         (eqpa_violate_rule_4_g6),
    .eq_convergence_sts_g6          (eq_convergence_sts_g6),
    .mac_cdm_ras_des_coef_rtx_g6    (mac_cdm_ras_des_coef_rtx_g6),
    .mac_cdm_ras_des_reject_rtx_g6  (mac_cdm_ras_des_reject_rtx_g6),
    .rl0s_state                     (rl0s_state),
    .rdlh_bad_tlp_err_pertlp        (rdlh_bad_tlp_err_pertlp),
    .rdlh_lcrc_tlp_err_pertlp       (rdlh_lcrc_tlp_err_pertlp),
    .rdlh_nulified_tlp_err_pertlp   (rdlh_nulified_tlp_err_pertlp),
    .rdlh_duplicate_tlp_err_pertlp  (rdlh_duplicate_tlp_err_pertlp),
    .rdlh_bad_dllp_err_perdllp      (rdlh_bad_dllp_err_perdllp),
    .rcvd_nack_perdllp              (rdlh_rcvd_nack_perdllp),
    .rdlh_rcvd_ack_perdllp          (rdlh_rcvd_ack_perdllp),
    .nak_sent                       (xdlh_nak_sent),
    .ack_sent                       (xdlh_ack_sent),
    .xdlh_update_fc_sent            (xdlh_update_fc_sent),
    .rtlh_req_link_retrain          (rtlh_req_link_retrain),
    .rtlh_rcvd_ufc_perdllp          (rtlh_rcvd_ufc_perdllp),
    .rtlh_rx_memwr_evt              (rtlh_rx_memwr_evt),
    .rtlh_rx_defmemwr_evt           (rtlh_rx_defmemwr_evt),
    .rtlh_rx_memrd_evt              (rtlh_rx_memrd_evt),
    .rtlh_rx_cfgwr_evt              (rtlh_rx_cfgwr_evt),
    .rtlh_rx_cfgrd_evt              (rtlh_rx_cfgrd_evt),
    .rtlh_rx_iowr_evt               (rtlh_rx_iowr_evt),
    .rtlh_rx_iord_evt               (rtlh_rx_iord_evt),
    .rtlh_rx_cplwod_evt             (rtlh_rx_cplwod_evt),
    .rtlh_rx_cplwd_evt              (rtlh_rx_cplwd_evt),
    .rtlh_rx_msg_evt                (rtlh_rx_msg_evt),
    .rtlh_rx_atmcop_evt             (rtlh_rx_atmcop_evt),
    .rtlh_rx_tlpwprefix_evt         (rtlh_rx_tlpwprefix_evt),
    .rtlh_rx_tlp_dpsize             (rtlh_rx_tlp_dpsize),
    .rdlh_vc0_initfc1_status        (rdlh_vc0_initfc1_status),
    .rdlh_vc0_initfc2_status        (rdlh_vc0_initfc2_status),
    .rdlh_xplh_curnt_rx_ack_seqnum  (rdlh_xplh_curnt_rx_ack_seqnum),
    .xdlh_xplh_curnt_seqnum         (xdlh_xplh_curnt_seqnum),
    .rtlh_fc_rcvd_ph                (rtlh_fc_rcvd_ph),
    .rtlh_fc_rcvd_pd                (rtlh_fc_rcvd_pd),
    .rtlh_fc_rcvd_nph               (rtlh_fc_rcvd_nph),
    .rtlh_fc_rcvd_npd               (rtlh_fc_rcvd_npd),
    .rtlh_fc_rcvd_cplh              (rtlh_fc_rcvd_cplh),
    .rtlh_fc_rcvd_cpld              (rtlh_fc_rcvd_cpld),
    .rtlh_fc_allctd_ph              (rtlh_fc_allctd_ph),
    .rtlh_fc_allctd_pd              (rtlh_fc_allctd_pd),
    .rtlh_fc_allctd_nph             (rtlh_fc_allctd_nph),
    .rtlh_fc_allctd_npd             (rtlh_fc_allctd_npd),
    .rtlh_fc_allctd_cplh            (rtlh_fc_allctd_cplh),
    .rtlh_fc_allctd_cpld            (rtlh_fc_allctd_cpld),
    .rdlh_einj0_lcrc_evt            (rdlh_einj0_lcrc_evt),
    .xmlh_einj0_oscrc_evt           (xmlh_einj0_oscrc_evt),
    .xdlh_einj0_lcrc_evt            (xdlh_einj0_lcrc_evt),
    .xdlh_einj0_fcrc_evt            (xdlh_einj0_fcrc_evt),
    .xdlh_einj0_dllpcrc_evt         (xdlh_einj0_dllpcrc_evt),
    .ras_des_einj1_exp_sequm_evt    (ras_des_einj1_exp_sequm_evt), 
    .ras_des_einj1_ack_nak_sequm_evt(ras_des_einj1_ack_nak_sequm_evt),
    .xdlh_einj2_nak_evt             (xdlh_einj2_nak_evt),
    .xmlh_einj3_osmsk_evt           (xmlh_einj3_osmsk_evt),
    .rtlh_einj4_fc_evt              (rtlh_einj4_fc_evt),
    .xdlh_einj5_nultlp_evt          (xdlh_einj5_nultlp_evt),
    .xdlh_einj5_dup_evt             (xdlh_einj5_dup_evt),
    .xdlh_ptm_sot                   (xdlh_ptm_sot),
    .xdlh_ptm_multi_cycle           (xdlh_ptm_multi_cycle),
    .xdlh_ptm_request               (xdlh_ptm_request),
    .xdlh_ptm_response              (xdlh_ptm_response),
    .xdlh_rbuf_replaying            (xdlh_rbuf_replaying),
    .rdlh_ptm_sot                   (rdlh_ptm_sot),
    .rdlh_ptm_multi_cycle           (rdlh_ptm_multi_cycle),
    .rdlh_ptm_request               (rdlh_ptm_request),
    .rdlh_ptm_response              (rdlh_ptm_response),
    .rdlh_duplicate_tlp             (rdlh_duplicate_tlp),
    .smlh_ltssm_in_l0p              (smlh_ltssm_in_l0p),
    .pm_aux_clk                        (pm_aux_clk),
    .pm_en_pulse_det                   (pm_en_pulse_det),
    .pipe_aux_sync_p1_ack              (pipe_aux_sync_p1_ack),
    .pipe_aux_sync_block               (pipe_aux_sync_block),

    .mac_phy_ltssm_link_synchdr_bypass_enabled  (mac_phy_ltssm_link_synchdr_bypass_enabled),
    .mac_phy_cfg_cxl_port_drift_buffer_enabled  (mac_phy_cfg_cxl_port_drift_buffer_enabled),
    .sqlchd_rxelecidle                          (sqlchd_rxelecidle),
    .serdes_pipe_turnoff_lanes                  (pre_serdes_pipe_turnoff_lanes),
    .pre_mac_phy_powerdown                      (pre_mac_phy_powerdown),
    .int_mac_phy_txelecidle                     (int_mac_phy_txelecidle),
    .pre_mac_phy_txdata                         (pre_mac_phy_txdata),
    .pre_mac_phy_txdetectrx_loopback            (core_pre_mac_phy_txdetectrx_loopback),
    .glue_mac_phy_txcompliance                  (glue_mac_phy_txcompliance),
    .pre_mac_phy_rxpolarity                     (pre_mac_phy_rxpolarity),
    .tmp_mac_phy_rxpolarity                     (tmp_mac_phy_rxpolarity),
    .tmp_int_mac_phy_rate                       (tmp_int_mac_phy_rate),
    .tmp_mac_phy_txdeemph_0                     (tmp_mac_phy_txdeemph_0),
    .pre_mac_phy_width                          (pre_mac_phy_width),
    .pre_mac_phy_serdes_arch                    (pre_mac_phy_serdes_arch),
    .pre_mac_phy_rxwidth                        (pre_mac_phy_rxwidth),
    .pre_serdes_pipe_rxready                    (pre_serdes_pipe_rxready),
    .pre_mac_phy_pclk_rate                      (pre_mac_phy_pclk_rate),
    .pre_mac_phy_rxstandby                      (pre_mac_phy_rxstandby),
    .pre_mac_phy_rate                           (pre_mac_phy_rate),
    .pre_mac_phy_txdeemph                       (pre_mac_phy_txdeemph),
    .pre_mac_phy_txdatavalid                    (pre_mac_phy_txdatavalid),
    .pre_mac_phy_rxeqeval                       (pre_mac_phy_rxeqeval),
    .pre_mac_phy_dirchange                      (pre_mac_phy_dirchange),
    .pre_mac_phy_smlh_coef_rtx                  (pre_mac_phy_smlh_coef_rtx),
    .pre_mac_phy_blockaligncontrol_o            (pre_mac_phy_blockaligncontrol_o),
    .pre_mac_phy_mbus                           (pre_mac_phy_mbus),
    .cfg_pipe_loopback                          (cfg_pipe_loopback),
    .cfg_rxstatus_lane                          (cfg_rxstatus_lane),
    .cfg_rxstatus_value                         (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid                           (cfg_lpbk_rxvalid),
    .int_cfg_lec_pset_ltx                       (int_cfg_lec_pset_ltx),
    .int_cfg_lec_pset_lrx                       (int_cfg_lec_pset_lrx),
    .int_cfg_lec_pset_rtx                       (int_cfg_lec_pset_rtx),
    .int_cfg_lec_pset_rrx                       (int_cfg_lec_pset_rrx),
    .int_cfg_lec_g4_pset_ltx                    (int_cfg_lec_g4_pset_ltx),
    .int_cfg_lec_g4_pset_rtx                    (int_cfg_lec_g4_pset_rtx),
    .int_cfg_lec_g5_pset_ltx                    (int_cfg_lec_g5_pset_ltx),
    .int_cfg_lec_g5_pset_rtx                    (int_cfg_lec_g5_pset_rtx),
    .int_cfg_lec_g6_pset_ltx                    (int_cfg_lec_g6_pset_ltx),
    .int_cfg_lec_g6_pset_rtx                    (int_cfg_lec_g6_pset_rtx),
    .int_cfg_margin_control                     (int_cfg_margin_control),
    .int_cdm_ras_des_force_rxdetected           (int_cdm_ras_des_force_rxdetected),
    .int_smlh_margin_status_valid               (int_smlh_margin_status_valid),
    .int_smlh_margin_status                     (int_smlh_margin_status),
    .int_rmlh_deskew_ctlskp_err                 (int_rmlh_deskew_ctlskp_err),
    .int_rmlh_lane_err                          (int_rmlh_lane_err),
    .int_smlh_lec_pset_ltx                      (int_smlh_lec_pset_ltx),
    .int_smlh_lec_pset_lrx                      (int_smlh_lec_pset_lrx),
    .int_smlh_lec_g4_pset_ltx                   (int_smlh_lec_g4_pset_ltx),
    .int_smlh_lec_g5_pset_ltx                   (int_smlh_lec_g5_pset_ltx),
    .int_smlh_lec_g6_pset_ltx                   (int_smlh_lec_g6_pset_ltx),
    .orig_pipe_rxdata                           (orig_pipe_rxdata),
    .orig_pipe_rxdatak                          (orig_pipe_rxdatak),
    .orig_pipe_rxvalid                          (orig_pipe_rxvalid),
    .orig_pipe_rxdatavalid                      (orig_pipe_rxdatavalid),
    .orig_pipe_rxstatus                         (orig_pipe_rxstatus),
    .orig_pipe_rxstartblock                     (orig_pipe_rxstartblock),
    .orig_pipe_rxsyncheader                     (orig_pipe_rxsyncheader),
    .phy_mac_phystatus_int                      (phy_mac_phystatus_int),
    .dpc_fatal_err_gate                         (dpc_fatal_err_gate),
    .dpc_nonfatal_err_gate                      (dpc_nonfatal_err_gate),
    .smlh_link_in_training                      (smlh_link_in_training),
    .rmlh_prbs_done                             (rmlh_prbs_done),
    .rmlh_prbs_fail                             (rmlh_prbs_fail),
    .rmlh_prbs_started                          (rmlh_prbs_started),
    .rmlh_prbs_err_cntr                         (rmlh_prbs_err_cntr),
    .rmlh_prbs_unexp_fail                       (rmlh_prbs_unexp_fail),
    .b_cfgi_lbc                                 (b_cfgi_lbc_pcie.cfgi_master_mp),
    .cfg_prbs_en                                (cfg_prbs_en),
    .clear_prbs_done                            (clear_prbs_done),
    .cfg_prbs_lane_sel                          (cfg_prbs_lane_sel)


);    // u_cx_pl


////////////CXL.cachemem/CXL_ARBMUX spif interface to wire mapping/////

assign usp_eq_redo_executed_int = usp_g3_eq_redo_executed_int | usp_g4_eq_redo_executed_int | usp_g5_eq_redo_executed_int;

// -------------------------------------------------------------------------------------
// DWC CXS Interface Controller Instantiation
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// DWC CXL Controller Instantiation
// -------------------------------------------------------------------------------------

// Interface Declarations
DWC_cxl_clk_rst_if             b_clk();                 // Clock and reset interface
DWC_cxl_rbuf_llctrl_if         b_rbuf_llctrl();         // Retry Buffer Interface

// Clock and Reset Interface Connections
assign b_clk.s_cxl_clk    = cxl_clk;
assign b_clk.s_cxl_rst_n  = cxl_rst_n;
assign b_clk.s_core_clk   = core_clk;
assign b_clk.s_core_rst_n = core_rst_n;

DWC_cxl_app_ch_init_if         b_app_cache_tx_init();   // CXL.Cache Slave (TX) Channel Initialization Interface
DWC_cxl_app_ch_init_if         b_app_cache_rx_init();   // CXL.Cache Master (RX) Channel Initialization Interface
DWC_cxl_app_ch_init_if         b_app_mem_tx_init();     // CXL.Mem Slave (TX) Channel Initialization Interface
DWC_cxl_app_ch_init_if         b_app_mem_rx_init();     // CXL.Mem Master (RX) Channel Initialization Interface
DWC_cxl_app_ch_if              b_app_dev_tx_chi();      // Endpoint TX D2H and S2M Channel Message Interface
DWC_cxl_app_ch_if              b_app_host_rx_chi();     // Endpoint RX H2D and M2S Channel Message Interface
DWC_cxl_app_ch_if              b_app_dev_rx_chi();      // Root Complex TX H2D and M2S Channel Message Interface
DWC_cxl_app_ch_if              b_app_host_tx_chi();     // Root Complex RX D2H and S2M Channel Message Interface

assign cxl_viral_status = b_cxl_cdm.s_cfg_cxl_pl_reg_viral_status;
assign cxl_viral_enable = b_cxl_cdm.s_cfg_cxl_viral_enable;


// -------------------------------------------------------------------------------------
// DWC CXL.Cache Channel Interface Mapping
// -------------------------------------------------------------------------------------
assign cxl_cache_mst_req = b_app_cache_rx_init.s_cxl_init_req;
assign b_app_cache_rx_init.s_cxl_init_ack = cxl_cache_mst_ack;
assign b_app_cache_tx_init.s_cxl_init_req = cxl_cache_slv_req;
assign cxl_cache_slv_ack = b_app_cache_tx_init.s_cxl_init_ack;
assign b_app_cache_tx_init.s_cxl_app_pending = cxl_cache_app_pending;

generate
for (genvar i = 0; i < `CX_CXL_CACHE_H2D_REQ_IFNUM; i++) begin : gen_h2d_req_intf
assign b_app_host_rx_chi.s_cxl_h2d_req_crd[i]     = cxl_mst_h2d_req_crd[i];
assign cxl_mst_h2d_req[i*`CX_CXL_CACHE_H2D_REQ_SIZE +: `CX_CXL_CACHE_H2D_REQ_SIZE]                         = b_app_host_rx_chi.s_cxl_h2d_req[i];
assign cxl_mst_h2d_req_chk[i*`CX_CXL_CACHE_H2D_REQ_CHK_SIZE +: `CX_CXL_CACHE_H2D_REQ_CHK_SIZE]                     = b_app_host_rx_chi.s_cxl_h2d_req_chk[i];
assign cxl_slv_h2d_req_crd[i]                     = b_app_host_tx_chi.s_cxl_h2d_req_crd[i];
assign b_app_host_tx_chi.s_cxl_h2d_req[i]         = cxl_slv_h2d_req[i*`CX_CXL_CACHE_H2D_REQ_SIZE +: `CX_CXL_CACHE_H2D_REQ_SIZE];
assign b_app_host_tx_chi.s_cxl_h2d_req_chk[i]     = cxl_slv_h2d_req_chk[i*`CX_CXL_CACHE_H2D_REQ_CHK_SIZE +: `CX_CXL_CACHE_H2D_REQ_CHK_SIZE];
end : gen_h2d_req_intf

for (genvar i = 0; i < `CX_CXL_CACHE_H2D_RESP_IFNUM; i++) begin : gen_h2d_resp_intf
assign b_app_host_rx_chi.s_cxl_h2d_resp_crd[i]    = cxl_mst_h2d_rsp_crd[i];
assign cxl_mst_h2d_rsp[i*`CX_CXL_CACHE_H2D_RESP_SIZE +: `CX_CXL_CACHE_H2D_RESP_SIZE]                         = b_app_host_rx_chi.s_cxl_h2d_resp[i];
assign cxl_mst_h2d_rsp_chk[i*`CX_CXL_CACHE_H2D_RESP_CHK_SIZE +: `CX_CXL_CACHE_H2D_RESP_CHK_SIZE]                     = b_app_host_rx_chi.s_cxl_h2d_resp_chk[i];
assign cxl_slv_h2d_rsp_crd[i]                     = b_app_host_tx_chi.s_cxl_h2d_resp_crd[i];
assign b_app_host_tx_chi.s_cxl_h2d_resp[i]        = cxl_slv_h2d_rsp[i*`CX_CXL_CACHE_H2D_RESP_SIZE +: `CX_CXL_CACHE_H2D_RESP_SIZE];
assign b_app_host_tx_chi.s_cxl_h2d_resp_chk[i]    = cxl_slv_h2d_rsp_chk[i*`CX_CXL_CACHE_H2D_RESP_CHK_SIZE +: `CX_CXL_CACHE_H2D_RESP_CHK_SIZE];
end : gen_h2d_resp_intf

for (genvar i = 0; i < `CX_CXL_CACHE_H2D_DATA_IFNUM; i++) begin : gen_h2d_data_intf
assign b_app_host_rx_chi.s_cxl_h2d_data_crd[i]    = cxl_mst_h2d_data_crd[i];
assign cxl_mst_h2d_data[i*`CX_CXL_CACHE_H2D_DATA_SIZE +: `CX_CXL_CACHE_H2D_DATA_SIZE]                        = b_app_host_rx_chi.s_cxl_h2d_data[i];
assign cxl_mst_h2d_data_chk[i*`CX_CXL_CACHE_H2D_DATA_CHK_SIZE +: `CX_CXL_CACHE_H2D_DATA_CHK_SIZE]                    = b_app_host_rx_chi.s_cxl_h2d_data_chk[i];
assign cxl_slv_h2d_data_crd[i]                    = b_app_host_tx_chi.s_cxl_h2d_data_crd[i];
assign b_app_host_tx_chi.s_cxl_h2d_data[i]        = cxl_slv_h2d_data[i*`CX_CXL_CACHE_H2D_DATA_SIZE +: `CX_CXL_CACHE_H2D_DATA_SIZE];
assign b_app_host_tx_chi.s_cxl_h2d_data_chk[i]    = cxl_slv_h2d_data_chk[i*`CX_CXL_CACHE_H2D_DATA_CHK_SIZE +: `CX_CXL_CACHE_H2D_DATA_CHK_SIZE];
end : gen_h2d_data_intf

for (genvar i = 0; i < `CX_CXL_CACHE_D2H_REQ_IFNUM; i++) begin : gen_d2h_req_intf
assign cxl_slv_d2h_req_crd[i]                     = b_app_dev_tx_chi.s_cxl_d2h_req_crd[i];
assign b_app_dev_tx_chi.s_cxl_d2h_req[i]          = cxl_slv_d2h_req[i*`CX_CXL_CACHE_D2H_REQ_SIZE +: `CX_CXL_CACHE_D2H_REQ_SIZE];
assign b_app_dev_tx_chi.s_cxl_d2h_req_chk[i]      = cxl_slv_d2h_req_chk[i*`CX_CXL_CACHE_D2H_REQ_CHK_SIZE +: `CX_CXL_CACHE_D2H_REQ_CHK_SIZE];
assign b_app_dev_rx_chi.s_cxl_d2h_req_crd[i]      = cxl_mst_d2h_req_crd[i];
assign cxl_mst_d2h_req[i*`CX_CXL_CACHE_D2H_REQ_SIZE +: `CX_CXL_CACHE_D2H_REQ_SIZE]                         = b_app_dev_rx_chi.s_cxl_d2h_req[i];
assign cxl_mst_d2h_req_chk[i*`CX_CXL_CACHE_D2H_REQ_CHK_SIZE +: `CX_CXL_CACHE_D2H_REQ_CHK_SIZE]                     = b_app_dev_rx_chi.s_cxl_d2h_req_chk[i];
end : gen_d2h_req_intf

for (genvar i = 0; i < `CX_CXL_CACHE_D2H_RESP_IFNUM; i++) begin : gen_d2h_resp_intf
assign cxl_slv_d2h_rsp_crd[i]                     = b_app_dev_tx_chi.s_cxl_d2h_resp_crd[i];
assign b_app_dev_tx_chi.s_cxl_d2h_resp[i]         = cxl_slv_d2h_rsp[i*`CX_CXL_CACHE_D2H_RESP_SIZE +: `CX_CXL_CACHE_D2H_RESP_SIZE];
assign b_app_dev_tx_chi.s_cxl_d2h_resp_chk[i]     = cxl_slv_d2h_rsp_chk[i*`CX_CXL_CACHE_D2H_RESP_CHK_SIZE +: `CX_CXL_CACHE_D2H_RESP_CHK_SIZE];
assign b_app_dev_rx_chi.s_cxl_d2h_resp_crd[i]     = cxl_mst_d2h_rsp_crd[i];
assign cxl_mst_d2h_rsp[i*`CX_CXL_CACHE_D2H_RESP_SIZE +: `CX_CXL_CACHE_D2H_RESP_SIZE]                         = b_app_dev_rx_chi.s_cxl_d2h_resp[i];
assign cxl_mst_d2h_rsp_chk[i*`CX_CXL_CACHE_D2H_RESP_CHK_SIZE +: `CX_CXL_CACHE_D2H_RESP_CHK_SIZE]                     = b_app_dev_rx_chi.s_cxl_d2h_resp_chk[i];
end : gen_d2h_resp_intf

for (genvar i = 0; i < `CX_CXL_CACHE_D2H_DATA_IFNUM; i++) begin : gen_d2h_data_intf
assign cxl_slv_d2h_data_crd[i]                    = b_app_dev_tx_chi.s_cxl_d2h_data_crd[i];
assign b_app_dev_tx_chi.s_cxl_d2h_data[i]         = cxl_slv_d2h_data[i*`CX_CXL_CACHE_D2H_DATA_SIZE +: `CX_CXL_CACHE_D2H_DATA_SIZE];
assign b_app_dev_tx_chi.s_cxl_d2h_data_chk[i]     = cxl_slv_d2h_data_chk[i*`CX_CXL_CACHE_D2H_DATA_CHK_SIZE +: `CX_CXL_CACHE_D2H_DATA_CHK_SIZE];
assign b_app_dev_rx_chi.s_cxl_d2h_data_crd[i]     = cxl_mst_d2h_data_crd[i];
assign cxl_mst_d2h_data[i*`CX_CXL_CACHE_D2H_DATA_SIZE +: `CX_CXL_CACHE_D2H_DATA_SIZE]                        = b_app_dev_rx_chi.s_cxl_d2h_data[i];
assign cxl_mst_d2h_data_chk[i*`CX_CXL_CACHE_D2H_DATA_CHK_SIZE +: `CX_CXL_CACHE_D2H_DATA_CHK_SIZE]                    = b_app_dev_rx_chi.s_cxl_d2h_data_chk[i];
end : gen_d2h_data_intf
endgenerate
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// DWC CXL.Mem Channel Interface Mapping
// -------------------------------------------------------------------------------------
assign cxl_mem_mst_req = b_app_mem_rx_init.s_cxl_init_req;
assign b_app_mem_rx_init.s_cxl_init_ack   = cxl_mem_mst_ack;
assign b_app_mem_tx_init.s_cxl_init_req   = cxl_mem_slv_req;
assign cxl_mem_slv_ack = b_app_mem_tx_init.s_cxl_init_ack;
assign b_app_mem_tx_init.s_cxl_app_pending = cxl_mem_app_pending;

generate
for (genvar i = 0; i < `CX_CXL_MEM_M2S_NDR_IFNUM; i++) begin : gen_m2s_ndr_intf
assign b_app_host_rx_chi.s_cxl_m2s_req_crd[i]     = cxl_mst_m2s_req_crd[i];
assign cxl_mst_m2s_req[i*`CX_CXL_MEM_M2S_NDR_SIZE +: `CX_CXL_MEM_M2S_NDR_SIZE]                         = b_app_host_rx_chi.s_cxl_m2s_req[i];
assign cxl_mst_m2s_req_chk[i*`CX_CXL_MEM_M2S_NDR_CHK_SIZE +: `CX_CXL_MEM_M2S_NDR_CHK_SIZE]             = b_app_host_rx_chi.s_cxl_m2s_req_chk[i];
assign cxl_slv_m2s_req_crd[i]                     = b_app_host_tx_chi.s_cxl_m2s_req_crd[i];
assign b_app_host_tx_chi.s_cxl_m2s_req[i]         = cxl_slv_m2s_req[i*`CX_CXL_MEM_M2S_NDR_SIZE +: `CX_CXL_MEM_M2S_NDR_SIZE];
assign b_app_host_tx_chi.s_cxl_m2s_req_chk[i]     = cxl_slv_m2s_req_chk[i*`CX_CXL_MEM_M2S_NDR_CHK_SIZE +: `CX_CXL_MEM_M2S_NDR_CHK_SIZE];
end : gen_m2s_ndr_intf

for (genvar i = 0; i < `CX_CXL_MEM_M2S_DATA_IFNUM; i++) begin : gen_m2s_data_intf
assign b_app_host_rx_chi.s_cxl_m2s_rwd_crd[i]     = cxl_mst_m2s_rwd_crd[i];
assign cxl_mst_m2s_rwd[i*`CX_CXL_MEM_M2S_DATA_SIZE +: `CX_CXL_MEM_M2S_DATA_SIZE]                       = b_app_host_rx_chi.s_cxl_m2s_rwd[i];
assign cxl_mst_m2s_rwd_chk[i*`CX_CXL_MEM_M2S_DATA_CHK_SIZE +: `CX_CXL_MEM_M2S_DATA_CHK_SIZE]           = b_app_host_rx_chi.s_cxl_m2s_rwd_chk[i];
assign cxl_slv_m2s_rwd_crd[i]                     = b_app_host_tx_chi.s_cxl_m2s_rwd_crd[i];
assign b_app_host_tx_chi.s_cxl_m2s_rwd[i]         = cxl_slv_m2s_rwd[i*`CX_CXL_MEM_M2S_DATA_SIZE +: `CX_CXL_MEM_M2S_DATA_SIZE];
assign b_app_host_tx_chi.s_cxl_m2s_rwd_chk[i]     = cxl_slv_m2s_rwd_chk[i*`CX_CXL_MEM_M2S_DATA_CHK_SIZE +: `CX_CXL_MEM_M2S_DATA_CHK_SIZE];
end : gen_m2s_data_intf

for (genvar i = 0; i < `CX_CXL_MEM_M2S_BI_RSP_IFNUM; i++) begin : gen_m2s_bi_rsp_intf
assign b_app_host_rx_chi.s_cxl_m2s_bi_rsp_crd[i]  = cxl_mst_m2s_bi_rsp_crd[i];
assign cxl_mst_m2s_bi_rsp[i*`CX_CXL_MEM_M2S_BI_RSP_SIZE +: `CX_CXL_MEM_M2S_BI_RSP_SIZE]                      = b_app_host_rx_chi.s_cxl_m2s_bi_rsp[i];
assign cxl_mst_m2s_bi_rsp_chk[i*`CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE +: `CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE]          = b_app_host_rx_chi.s_cxl_m2s_bi_rsp_chk[i];
assign cxl_slv_m2s_bi_rsp_crd[i]                  = b_app_host_tx_chi.s_cxl_m2s_bi_rsp_crd[i];
assign b_app_host_tx_chi.s_cxl_m2s_bi_rsp[i]      = cxl_slv_m2s_bi_rsp[i*`CX_CXL_MEM_M2S_BI_RSP_SIZE +: `CX_CXL_MEM_M2S_BI_RSP_SIZE];
assign b_app_host_tx_chi.s_cxl_m2s_bi_rsp_chk[i]  = cxl_slv_m2s_bi_rsp_chk[i*`CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE +: `CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE];
end : gen_m2s_bi_rsp_intf

for (genvar i = 0; i < `CX_CXL_MEM_S2M_NDR_IFNUM; i++) begin : gen_s2m_ndr_intf
assign b_app_dev_tx_chi.s_cxl_s2m_ndr[i]          = cxl_slv_s2m_ndr[i*`CX_CXL_MEM_S2M_NDR_SIZE +: `CX_CXL_MEM_S2M_NDR_SIZE];
assign cxl_slv_s2m_ndr_crd[i]                     = b_app_dev_tx_chi.s_cxl_s2m_ndr_crd[i];
assign b_app_dev_tx_chi.s_cxl_s2m_ndr_chk[i]      = cxl_slv_s2m_ndr_chk[i*`CX_CXL_MEM_S2M_NDR_CHK_SIZE +: `CX_CXL_MEM_S2M_NDR_CHK_SIZE];
assign b_app_dev_rx_chi.s_cxl_s2m_ndr_crd[i]      = cxl_mst_s2m_ndr_crd[i];
assign cxl_mst_s2m_ndr[i*`CX_CXL_MEM_S2M_NDR_SIZE +: `CX_CXL_MEM_S2M_NDR_SIZE]                         = b_app_dev_rx_chi.s_cxl_s2m_ndr[i];
assign cxl_mst_s2m_ndr_chk[i*`CX_CXL_MEM_S2M_NDR_CHK_SIZE +: `CX_CXL_MEM_S2M_NDR_CHK_SIZE]             = b_app_dev_rx_chi.s_cxl_s2m_ndr_chk[i];
end : gen_s2m_ndr_intf

for (genvar i = 0; i < `CX_CXL_MEM_S2M_DATA_IFNUM; i++) begin : gen_s2m_data_intf
assign cxl_slv_s2m_drc_crd[i]                     = b_app_dev_tx_chi.s_cxl_s2m_drc_crd[i];
assign b_app_dev_tx_chi.s_cxl_s2m_drc[i]          = cxl_slv_s2m_drc[i*`CX_CXL_MEM_S2M_DATA_SIZE +: `CX_CXL_MEM_S2M_DATA_SIZE];
assign b_app_dev_tx_chi.s_cxl_s2m_drc_chk[i]      = cxl_slv_s2m_drc_chk[i*`CX_CXL_MEM_S2M_DATA_CHK_SIZE +: `CX_CXL_MEM_S2M_DATA_CHK_SIZE];
assign b_app_dev_rx_chi.s_cxl_s2m_drc_crd[i]      = cxl_mst_s2m_drc_crd[i];
assign cxl_mst_s2m_drc[i*`CX_CXL_MEM_S2M_DATA_SIZE +: `CX_CXL_MEM_S2M_DATA_SIZE]                     = b_app_dev_rx_chi.s_cxl_s2m_drc[i];
assign cxl_mst_s2m_drc_chk[i*`CX_CXL_MEM_S2M_DATA_CHK_SIZE +: `CX_CXL_MEM_S2M_DATA_CHK_SIZE]         = b_app_dev_rx_chi.s_cxl_s2m_drc_chk[i];
end : gen_s2m_data_intf

for (genvar i = 0; i < `CX_CXL_MEM_S2M_BI_SNP_IFNUM; i++) begin : gen_s2m_bi_snp_intf
assign cxl_slv_s2m_bi_snp_crd[i]                  = b_app_dev_tx_chi.s_cxl_s2m_bi_snp_crd[i];
assign b_app_dev_tx_chi.s_cxl_s2m_bi_snp[i]       = cxl_slv_s2m_bi_snp[i*`CX_CXL_MEM_S2M_BI_SNP_SIZE +: `CX_CXL_MEM_S2M_BI_SNP_SIZE];
assign b_app_dev_tx_chi.s_cxl_s2m_bi_snp_chk[i]   = cxl_slv_s2m_bi_snp_chk[i*`CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE +: `CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE];
assign b_app_dev_rx_chi.s_cxl_s2m_bi_snp_crd[i]   = cxl_mst_s2m_bi_snp_crd[i];
assign cxl_mst_s2m_bi_snp[i*`CX_CXL_MEM_S2M_BI_SNP_SIZE +: `CX_CXL_MEM_S2M_BI_SNP_SIZE]                      = b_app_dev_rx_chi.s_cxl_s2m_bi_snp[i];
assign cxl_mst_s2m_bi_snp_chk[i*`CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE +: `CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE]          = b_app_dev_rx_chi.s_cxl_s2m_bi_snp_chk[i];
end : gen_s2m_bi_snp_intf
endgenerate
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// DWC CXL Controller Message Channels RAM Interface Mapping
// -------------------------------------------------------------------------------------
DWC_cxl_ram2p_if  #( .DATA_WIDTH (`CX_CXL_MST_HREQ_DRESP_RAM_DATAW), .ADDR_WIDTH (`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW) )   b_cxl_mst_hreq_drsp_ram  [0:`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1 ] ();
DWC_cxl_ram2p_if  #( .DATA_WIDTH (`CX_CXL_MST_HRESP_DREQ_RAM_DATAW), .ADDR_WIDTH (`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW) )   b_cxl_mst_hrsp_dreq_ram [0:`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1] ();
DWC_cxl_ram2p_if  #( .DATA_WIDTH (`CX_CXL_MST_HD_DATA_RAM_DATAW   ), .ADDR_WIDTH (`CX_CXL_MST_HD_DATA_RAM_ADDRW   ) )   b_cxl_mst_hd_data_ram [0:`CX_CXL_MST_HD_DDATA_RAM_NUM-1] ();
DWC_cxl_ram2p_if  #( .DATA_WIDTH (`CX_CXL_MST_MS_NDR_RAM_DATAW ), .ADDR_WIDTH (`CX_CXL_MST_MS_NDR_RAM_ADDRW ) )   b_cxl_mst_ms_ndr_ram [0:`CX_CXL_MST_MS_NDR_RAM_NUM-1 ] ();
DWC_cxl_ram2p_if  #( .DATA_WIDTH (`CX_CXL_MST_MS_DATA_RAM_DATAW), .ADDR_WIDTH (`CX_CXL_MST_MS_DATA_RAM_ADDRW) )   b_cxl_mst_ms_data_ram [0:`CX_CXL_MST_MS_DDATA_RAM_NUM-1] ();
DWC_cxl_ram2p_if #( .DATA_WIDTH (`CX_CXL_MST_MS_BI_RAM_DATAW ), .ADDR_WIDTH (`CX_CXL_MST_MS_BI_RAM_ADDRW ) )   b_cxl_mst_mrsp_ssnp_bi_ram [0:`CX_CXL_MST_MS_BI_RAM_NUM-1 ] ();

generate
for (genvar i = 0; i < `CX_CXL_MST_HD_REQ_RESP_RAM_NUM; i++) begin : gen_b_cxl_mst_hreq_drsp_ram
  assign cxl_mst_hreq_drsp_ram_we[i]          = b_cxl_mst_hreq_drsp_ram[i].s_ram_we         ;
  assign cxl_mst_hreq_drsp_ram_wr_addr[i*`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW +: `CX_CXL_MST_HREQ_DRESP_RAM_ADDRW]     = b_cxl_mst_hreq_drsp_ram[i].s_ram_wr_addr    ;
  assign cxl_mst_hreq_drsp_ram_wdata[i*`CX_CXL_MST_HREQ_DRESP_RAM_DATAW +: `CX_CXL_MST_HREQ_DRESP_RAM_DATAW]       = b_cxl_mst_hreq_drsp_ram[i].s_ram_wdata      ;
  assign cxl_mst_hreq_drsp_ram_rd_addr[i*`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW +: `CX_CXL_MST_HREQ_DRESP_RAM_ADDRW]     = b_cxl_mst_hreq_drsp_ram[i].s_ram_rd_addr    ;
  assign cxl_mst_hreq_drsp_ram_rd[i]          = b_cxl_mst_hreq_drsp_ram[i].s_ram_rd         ;
  assign b_cxl_mst_hreq_drsp_ram[i].s_ram_rdata = cxl_mst_hreq_drsp_ram_rdata[i*`CX_CXL_MST_HREQ_DRESP_RAM_DATAW +: `CX_CXL_MST_HREQ_DRESP_RAM_DATAW]            ;
  assign cxl_mst_hreq_drsp_ram_wr_addr_par[i] = b_cxl_mst_hreq_drsp_ram[i].s_ram_wr_addr_par  ;
  assign cxl_mst_hreq_drsp_ram_rd_addr_par[i] = b_cxl_mst_hreq_drsp_ram[i].s_ram_rd_addr_par  ;
end : gen_b_cxl_mst_hreq_drsp_ram


for (genvar i = 0; i < `CX_CXL_MST_HD_RESP_REQ_RAM_NUM; i++) begin : gen_b_cxl_mst_hrsp_dreq_ram
  assign cxl_mst_hrsp_dreq_ram_we[i]         = b_cxl_mst_hrsp_dreq_ram[i].s_ram_we        ;
  assign cxl_mst_hrsp_dreq_ram_wr_addr[i*`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW +: `CX_CXL_MST_HRESP_DREQ_RAM_ADDRW]    = b_cxl_mst_hrsp_dreq_ram[i].s_ram_wr_addr   ;
  assign cxl_mst_hrsp_dreq_ram_wdata[i*`CX_CXL_MST_HRESP_DREQ_RAM_DATAW +: `CX_CXL_MST_HRESP_DREQ_RAM_DATAW]      = b_cxl_mst_hrsp_dreq_ram[i].s_ram_wdata     ;
  assign cxl_mst_hrsp_dreq_ram_rd_addr[i*`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW +: `CX_CXL_MST_HRESP_DREQ_RAM_ADDRW]    = b_cxl_mst_hrsp_dreq_ram[i].s_ram_rd_addr   ;
  assign cxl_mst_hrsp_dreq_ram_rd[i]         = b_cxl_mst_hrsp_dreq_ram[i].s_ram_rd        ;
  assign b_cxl_mst_hrsp_dreq_ram[i].s_ram_rdata = cxl_mst_hrsp_dreq_ram_rdata[i*`CX_CXL_MST_HRESP_DREQ_RAM_DATAW +: `CX_CXL_MST_HRESP_DREQ_RAM_DATAW]          ;
  assign cxl_mst_hrsp_dreq_ram_wr_addr_par[i] = b_cxl_mst_hrsp_dreq_ram[i].s_ram_wr_addr_par  ;
  assign cxl_mst_hrsp_dreq_ram_rd_addr_par[i] = b_cxl_mst_hrsp_dreq_ram[i].s_ram_rd_addr_par  ;
end : gen_b_cxl_mst_hrsp_dreq_ram

for (genvar i = 0; i < `CX_CXL_MST_HD_DDATA_RAM_NUM; i++) begin : gen_b_cxl_mst_hd_data_ram
  assign cxl_mst_hd_data_ram_we[i]                                                  =b_cxl_mst_hd_data_ram[i].s_ram_we;
  assign cxl_mst_hd_data_ram_wr_addr[i*`CX_CXL_MST_HD_DATA_RAM_ADDRW +: `CX_CXL_MST_HD_DATA_RAM_ADDRW]=b_cxl_mst_hd_data_ram[i].s_ram_wr_addr;
  assign cxl_mst_hd_data_ram_wdata[i*`CX_CXL_MST_HD_DATA_RAM_DATAW +: `CX_CXL_MST_HD_DATA_RAM_DATAW]  =b_cxl_mst_hd_data_ram[i].s_ram_wdata;
  assign cxl_mst_hd_data_ram_rd_addr[i*`CX_CXL_MST_HD_DATA_RAM_ADDRW +: `CX_CXL_MST_HD_DATA_RAM_ADDRW]=b_cxl_mst_hd_data_ram[i].s_ram_rd_addr;
  assign cxl_mst_hd_data_ram_rd[i]                                                  =b_cxl_mst_hd_data_ram[i].s_ram_rd;
  assign b_cxl_mst_hd_data_ram[i].s_ram_rdata = cxl_mst_hd_data_ram_rdata[i*`CX_CXL_MST_HD_DATA_RAM_DATAW +: `CX_CXL_MST_HD_DATA_RAM_DATAW];
      assign cxl_mst_hd_data_ram_wr_addr_par[i]    = b_cxl_mst_hd_data_ram[i].s_ram_wr_addr_par;
      assign cxl_mst_hd_data_ram_rd_addr_par[i]    = b_cxl_mst_hd_data_ram[i].s_ram_rd_addr_par;
end : gen_b_cxl_mst_hd_data_ram


for (genvar i = 0; i < `CX_CXL_MST_MS_NDR_RAM_NUM; i++) begin : gen_b_cxl_mst_ms_ndr_ram
  assign cxl_mst_ms_ndr_ram_we[i]        = b_cxl_mst_ms_ndr_ram[i].s_ram_we       ;
  assign cxl_mst_ms_ndr_ram_rd[i]        = b_cxl_mst_ms_ndr_ram[i].s_ram_rd       ;
  assign cxl_mst_ms_ndr_ram_wr_addr[i*`CX_CXL_MST_MS_NDR_RAM_ADDRW +: `CX_CXL_MST_MS_NDR_RAM_ADDRW]   = b_cxl_mst_ms_ndr_ram[i].s_ram_wr_addr  ;
  assign cxl_mst_ms_ndr_ram_wdata[i*`CX_CXL_MST_MS_NDR_RAM_DATAW +: `CX_CXL_MST_MS_NDR_RAM_DATAW]     = b_cxl_mst_ms_ndr_ram[i].s_ram_wdata    ;
  assign cxl_mst_ms_ndr_ram_rd_addr[i*`CX_CXL_MST_MS_NDR_RAM_ADDRW +: `CX_CXL_MST_MS_NDR_RAM_ADDRW]   = b_cxl_mst_ms_ndr_ram[i].s_ram_rd_addr  ;
  assign b_cxl_mst_ms_ndr_ram[i].s_ram_rdata = cxl_mst_ms_ndr_ram_rdata[i*`CX_CXL_MST_MS_NDR_RAM_DATAW +: `CX_CXL_MST_MS_NDR_RAM_DATAW]        ;
      assign cxl_mst_ms_ndr_ram_wr_addr_par[i] = b_cxl_mst_ms_ndr_ram[i].s_ram_wr_addr_par  ;
      assign cxl_mst_ms_ndr_ram_rd_addr_par[i] = b_cxl_mst_ms_ndr_ram[i].s_ram_rd_addr_par  ;
end : gen_b_cxl_mst_ms_ndr_ram

for (genvar i = 0; i < `CX_CXL_MST_MS_DDATA_RAM_NUM; i++) begin : gen_b_cxl_mst_ms_data_ram
  assign cxl_mst_ms_data_ram_we[i]                                                  =b_cxl_mst_ms_data_ram[i].s_ram_we;
  assign cxl_mst_ms_data_ram_rd[i]                                                  =b_cxl_mst_ms_data_ram[i].s_ram_rd;
  assign cxl_mst_ms_data_ram_wr_addr[i*`CX_CXL_MST_MS_DATA_RAM_ADDRW +: `CX_CXL_MST_MS_DATA_RAM_ADDRW]=b_cxl_mst_ms_data_ram[i].s_ram_wr_addr;
  assign cxl_mst_ms_data_ram_wdata[i*`CX_CXL_MST_MS_DATA_RAM_DATAW +: `CX_CXL_MST_MS_DATA_RAM_DATAW]  =b_cxl_mst_ms_data_ram[i].s_ram_wdata;
  assign cxl_mst_ms_data_ram_rd_addr[i*`CX_CXL_MST_MS_DATA_RAM_ADDRW +: `CX_CXL_MST_MS_DATA_RAM_ADDRW]=b_cxl_mst_ms_data_ram[i].s_ram_rd_addr;
  assign b_cxl_mst_ms_data_ram[i].s_ram_rdata = cxl_mst_ms_data_ram_rdata[i*`CX_CXL_MST_MS_DATA_RAM_DATAW +: `CX_CXL_MST_MS_DATA_RAM_DATAW];
      assign cxl_mst_ms_data_ram_wr_addr_par[i] = b_cxl_mst_ms_data_ram[i].s_ram_wr_addr_par;
      assign cxl_mst_ms_data_ram_rd_addr_par[i] = b_cxl_mst_ms_data_ram[i].s_ram_rd_addr_par;
end : gen_b_cxl_mst_ms_data_ram
for (genvar i = 0; i < `CX_CXL_MST_MS_BI_RAM_NUM; i++) begin : gen_b_cxl_mst_mrsp_ssnp_bi_ram
  assign cxl_mst_ms_bi_ram_we[i]                                                    = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_we     ;
  assign cxl_mst_ms_bi_ram_wr_addr[i*`CX_CXL_MST_MS_BI_RAM_ADDRW +: `CX_CXL_MST_MS_BI_RAM_ADDRW]      = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_wr_addr;
  assign cxl_mst_ms_bi_ram_wdata[i*`CX_CXL_MST_MS_BI_RAM_DATAW +: `CX_CXL_MST_MS_BI_RAM_DATAW]        = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_wdata  ;
  assign cxl_mst_ms_bi_ram_rd_addr[i*`CX_CXL_MST_MS_BI_RAM_ADDRW +: `CX_CXL_MST_MS_BI_RAM_ADDRW]      = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_rd_addr;
  assign cxl_mst_ms_bi_ram_rd[i]                                                    = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_rd     ;
  assign b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_rdata = cxl_mst_ms_bi_ram_rdata[i*`CX_CXL_MST_MS_BI_RAM_DATAW +: `CX_CXL_MST_MS_BI_RAM_DATAW]         ;
  assign cxl_mst_ms_bi_ram_wr_addr_par[i]                                       = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_wr_addr_par;
  assign cxl_mst_ms_bi_ram_rd_addr_par[i]                                       = b_cxl_mst_mrsp_ssnp_bi_ram[i].s_ram_rd_addr_par;
end : gen_b_cxl_mst_mrsp_ssnp_bi_ram
// -------------------------------------------------------------------------------------
endgenerate



// -------------------------------------------------------------------------------------
// DWC CXL Controller Retry Buffer RAM Interface Mapping
// -------------------------------------------------------------------------------------
assign cxl_rbuf_ram_addr                  = b_rbuf_llctrl.s_cxl_rbuf_addr[(`CX_CXL_RBUF_RAM_ADDRW - 1):0] ;
assign cxl_rbuf_ram_addr_par              = b_rbuf_llctrl.s_cxl_rbuf_addr_par;
assign cxl_rbuf_ram_wdata                 = b_rbuf_llctrl.s_cxl_rbuf_wdata ;
assign cxl_rbuf_ram_en                    = b_rbuf_llctrl.s_cxl_rbuf_en    ;
assign cxl_rbuf_ram_we                    = b_rbuf_llctrl.s_cxl_rbuf_wen   ;
assign b_rbuf_llctrl.s_rbuf_ram_rdata     = cxl_rbuf_ram_rdata ;


// -------------------------------------------------------------------------------------
// DWC CXL Controller Cache/Mem Core Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_core
 u_DWC_cxl_core (
    .b_clk                       ( b_clk.slave_mp                          ),     // Clock and reset interface
    .b_cxl_cdm                   ( b_cxl_cdm.slave_cdm_mp                  ),     // CDM interface
    .b_vlsm_llctrl               ( b_vlsm_llctrl_mc.slave_mp               ),     // VLSM Link Layer Interface
    .b_cfgi_lbc                  ( b_cfgi_lbc_cxl.cfgi_master_mp           ),     // CFGI SPIF interface
    .b_rbuf_llctrl               ( b_rbuf_llctrl.master_mp                 ),     // Retry Buffer Interface
    .cxl_protocol_cfg            ( cxl_protocol_cfg                        ),     // Protocol Configuration for CXL Controller
    .cxl_link_tx_deinit_req      ( cxl_link_tx_deinit_req                  ),     // Tx Link deinit for app interface
    .lp_cxl_l1_exit              ( lp_cxl_l1_exit                          ),     // PM L1 exit request
    .lp_cxl_clk_ack              ( lp_cxl_clk_ack                          ),     // PM clock acknowledge
    .lp_cxl_wake_req             ( lp_cxl_wake_req                         ),     // PM wakeup request
    .pm_req_l2                   ( pm_prot_req_l2                          )      // PM request L2 Entry
    ,
    .b_app_cache_tx_init         ( b_app_cache_tx_init.slave_mp            ),     // CXL.Cache Slave (TX) Channel Initialization Interface
    .b_app_cache_rx_init         ( b_app_cache_rx_init.master_mp           ),     // CXL.Cache Master (RX) Channel Initialization Interface
    .b_app_mem_tx_init           ( b_app_mem_tx_init.slave_mp              ),     // CXL.Mem Slave (TX) Channel Initialization Interface
    .b_app_mem_rx_init           ( b_app_mem_rx_init.master_mp             ),     // CXL.Mem Master (RX) Channel Initialization Interface
    .b_app_dev_tx_chi            ( b_app_dev_tx_chi.slave_device_mp        ),     // Endpoint TX D2H and S2M message channel interface
    .b_app_host_rx_chi           ( b_app_host_rx_chi.master_host_mp        ),     // Endpoint RX H2D and M2S message channel interface
    .b_app_host_tx_chi           ( b_app_host_tx_chi.slave_host_mp         ),     // Root Complex TX H2D and M2S message channel interfaces
    .b_app_dev_rx_chi            ( b_app_dev_rx_chi.master_device_mp       ),     // Root Complex RX D2H and S2M message channel interface
    // CXL RAS Statistics Interface
    .cxl_ras_stat_rx_corr        ( cxl_ras_stat_rx_corr                    ),     // Correctable Error from RASDP Glue Logic
    .cxl_ras_stat_rx_uncorr      ( cxl_ras_stat_rx_uncorr                  ),     // Uncorrectable Error from RASDP Glue Logic
    .cxl_ras_stat_rx_hdr_log     ( cxl_ras_stat_rx_hdr_log                 ),     // Header Log from RASDP Glue Logic
    .cxl_viral_request           ( cxl_viral_request                       )      // Viral Mode request from the Application
    ,
    // --------------------------------------------------------------------------------------
    // CXL Device Rx Cache Message Channel memory interfaces
    // --------------------------------------------------------------------------------------
    .b_cxl_mst_hreq_drsp_ram     ( b_cxl_mst_hreq_drsp_ram.master_mp       ),     // CXL Receiver H2D Request/D2H Response RAM Interface
    .b_cxl_mst_hrsp_dreq_ram     ( b_cxl_mst_hrsp_dreq_ram.master_mp       ),     // CXL Receiver H2D Response/D2H Request RAM Interface
    .b_cxl_mst_hd_data_ram       ( b_cxl_mst_hd_data_ram.master_mp         )      // CXL Receiver H2D/D2H Data RAM Interface
    ,
    // --------------------------------------------------------------------------------------
    // CXL Device Rx Mem Message Channel memory interfaces
    // --------------------------------------------------------------------------------------
    .b_cxl_mst_ms_ndr_ram        ( b_cxl_mst_ms_ndr_ram.master_mp          ),     // CXL Receiver M2S/S2M NDR RAM Interface
    .b_cxl_mst_ms_data_ram       ( b_cxl_mst_ms_data_ram.master_mp         )      // CXL Receiver M2S/S2M Data RAM Interface
    ,
    .b_cxl_mst_mrsp_ssnp_bi_ram  ( b_cxl_mst_mrsp_ssnp_bi_ram.master_mp    )      // CXL Receiver M2S/S2M BI RAM Interface
      ,.cxl_s2m_data_pis         (cxl_s2m_data_pis                         )
      ,.cxl_m2s_data_pis         (cxl_m2s_data_pis                         )
      ,.cxl_h2d_data_pis         (cxl_h2d_data_pis                         )
      ,.cxl_d2h_data_pis         (cxl_d2h_data_pis                         )
); // u_DWC_cxl_core

assign cxl_vlsm_lrsm_req_retrain = b_vlsm_llctrl_mc.s_lp_state_req == RETRAIN;



// ----------------------------------------------------------------------
// Instantiate reset request control logic
// ----------------------------------------------------------------------



endmodule
