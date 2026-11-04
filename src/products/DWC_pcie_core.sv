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
// ---    $DateTime: 2024/01/26 07:16:49 $
// ---    $Revision: #122 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/DWC_pcie_core.sv#122 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module description:  This is for core only wrapper for dual mode/end device/root complex/switch application.
// --- core only modules:
// --- * radm_dm        : Rcvd ADM for dual-mode application
// --- * radm_ep        : Rcvd ADM for end-point application
// --- * radm_rc        : Rcvd ADM for root application
// --- * radm_sw        : Rcvd ADM for switch application
// --- * xadm           : Txmt ADM
// --- * cdm            : Type 0 CDM
// --- * lbc            : Local bus controller
// --- * msg_gen        : Message TLP Generation
// -----------------------------------------------------------------------------
//
//

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "Cdm/cdm_pkg.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_cdmregs_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "products/pcie_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS

 module DWC_pcie_core
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_CFG_COMPLETE;
import DWC_pcie_core_pkg::rtlh_rfc_t;
import DWC_pcie_core_pkg::tlp_order_t;
import DWC_pcie_ctl_pkg::APP_CRD_WD;
import DWC_pcie_ctl_pkg::MSG_TLP_WD;
import DWC_pcie_ctl_pkg::ORIG_DATA_WD;
import DWC_pcie_ctl_pkg::DCA_WD;
  import DWC_pcie_ctl_pkg::ATU_REG_LWR_WD;
  import DWC_pcie_core_pkg::radm_hdr_log_s;
import cdm_pkg::*;
import DWC_pcie_ctl_pkg::N_XADM_P_IF;
  import radm_ms_pkg::*;
  import DWC_pcie_core_pkg::xadm_xmt_pci_errors_t;
  import DWC_pcie_core_pkg::xadm_pkt_t;
  import DWC_pcie_core_pkg::xtlh_pkt_t;
  import DWC_pcie_core_pkg::radm_xadm_rcvd_cpl_t;
  import DWC_pcie_core_pkg::radm_xadm_timeout_npr_t;
  import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
  import DWC_pcie_ctl_pkg::xali_pkt_t;
  import DWC_pcie_ctl_pkg::np_req_tx_type_e;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_core_pkg::xadm_rasdes_tlp_trace_t;
  import DWC_pcie_core_pkg::rplh_flit_logging_interface_struct;
  import DWC_pcie_core_pkg::rmlh_flit_logging_interface_struct;
  import DWC_pcie_core_pkg::smlh_flit_logging_interface_struct;
  import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
  import DWC_pcie_core_pkg::flit_err_inj_status_struct;
  import DWC_pcie_core_pkg::cfg_os_einj_ctrl_1_t;
  import DWC_pcie_core_pkg::cfg_os_einj_ctrl_2_t;
  import DWC_pcie_core_pkg::cfg_os_einj_status_t;
  import DWC_pcie_core_pkg::xplh_cdm_flit_latency_track_t;
  import DWC_pcie_core_pkg::pm_cdm_state_trans_track_t;
import DWC_pcie_core_pkg::LBC_MSG_HDR_WD;
  import DWC_pcie_core_pkg::CORE_ADDR_PAR_WD;
`ifndef SYNTHESIS
`endif
  import pcie_pkg::fc_type_e;
  import pcie_pkg::E_P;
  import pcie_pkg::E_NP;
  import pcie_pkg::E_CPL;
  import spif_pkg::link_adm_if_t;
  import spif_pkg::protocol_cfg_t;
  import spif_pkg::LINKRESET;
  import spif_pkg::DISABLED;
  import DWC_cxl_pkg::vlsm_almp_debug_t;
  import DWC_cxl_pkg::vlsm_link_debug_t;
  import DWC_cxl_pkg::vlsm_info_debug_t;
  import DWC_cxl_pkg::vlsm_debug_t;
  import DWC_pcie_pm_pkg::*;
  import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
  import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
  import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
  import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
  import DWC_pcie_core_pkg::CFG_CXL_PORT_ENABLE_WD;
   #(
    parameter INST   = 0  // The uniquifying parameter for each port logic instance.
)

                     (
  // list of port declarations
     input                       core_clk

  ,input xali_pkt_t[`N_XALI_IF-1:0]   xali_xaim_pkt
  ,output logic[`N_XALI_IF-1:0]       xaim_xali_halt
      ,input [8:0]                     app_segment_id
      ,output [8:0]                    cfg_segment_id
  ,output logic [`N_XADM_P_IF-1:0]      xali_posted_tlp_sent










 // end xadm ports will present no matter AMBA_POPULATED is defined or not

    ,output                              radm_cpl_timeout
    ,output  [`CX_NFUNC_WD-1:0]          radm_timeout_func_num
    ,output  [2:0]                       radm_timeout_cpl_tc
    ,output  [1:0]                       radm_timeout_cpl_attr
    ,output  [11:0]                      radm_timeout_cpl_len
    ,output  [`CX_TAG_SIZE-1:0]          radm_timeout_cpl_tag





    ,output [`CX_NFUNC-1:0]             cfg_10b_tag_req_en


    ,input                     app_dbi_ro_wr_disable      // Set dbi_ro_wr_en to 0 disable write to DBI_RO_WR_EN bit


   ,input                               ext_lbc_override_en
   ,input   [`CX_NFUNC-1:0]                    ext_lbc_ack
   ,input   [(`CX_LBC_NW*32*`CX_NFUNC)-1:0]    ext_lbc_din
   ,output  [`CX_LBC_EXT_AW-1:0]        lbc_ext_addr
   ,output  [`CX_LBC_NW*32-1:0]         lbc_ext_dout
   ,output  [`CX_NFUNC-1:0]             lbc_ext_valid
   ,output  [`CX_NFUNC-1:0]             lbc_ext_cs
   ,output  [(4*`CX_LBC_NW)-1:0]        lbc_ext_wr
    ,output  [(4*`CX_LBC_NW)-1:0]        lbc_ext_rd
    ,output                              lbc_ext_dbi_access
    ,output                              lbc_ext_cxl_mbar0_access
    ,output                              lbc_ext_rom_access
    ,output                              lbc_ext_io_access
    ,output  [2:0]                       lbc_ext_bar_num
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






    ,output [(2*`CX_NFUNC)-1:0]          cfg_tph_req_en
    ,output [(3*`CX_NFUNC)-1:0]          cfg_pf_tph_st_mode
    ,output reg [`CX_NFUNC-1:0]          cfg_pf_pasid_en
    ,output reg [`CX_NFUNC-1:0]          cfg_pf_pasid_execute_perm_en
    ,output reg [`CX_NFUNC-1:0]          cfg_pf_pasid_priv_mode_en
    ,output logic [`CX_NFUNC-1:0]          cfg_atomic_req_en
    ,output [`CX_NFUNC-1:0]                cfg_atomic_egress_block

    ,output [`CX_NFUNC-1:0]                cfg_dmwr_req_en

    ,output  [1:0]                         cfg_obff_en
    ,output                                app_obff_msg_grant

    ,output                              cfg_ltr_m_en
    ,output [(32*`CX_NFUNC)-1:0]         cfg_ltr_max_latency
    ,output                              cfg_disable_ltr_clr_msg
    ,input   [31:0]                      cfg_pwr_budget_data_reg
    ,input   [`CX_NFUNC_WD-1:0]          cfg_pwr_budget_func_num
    ,output  [7:0]                       cfg_pwr_budget_data_sel_reg
    ,output  [`CX_PB_NFUNC-1:0]          cfg_pwr_budget_sel
    ,output  [`CX_NFUNC-1:0]             cfg_ari_fwd_en
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
    ,input   [`CX_NFUNC-1:0]             sys_int
    ,input                               sys_aux_pwr_det // unused
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
    ,input                               app_unlock_msg  // unused
    ,input                               app_obff_idle_msg_req
    ,input                               app_obff_obff_msg_req
    ,input                               app_obff_cpu_active_msg_req
    ,input                               pm_xtlh_block_tlp
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
    ,output  [`CX_NFUNC-1:0]             cfg_ext_tag_en
    ,output                              cfg_memtype_value
    ,output      [`FLT_Q_ADDR_WIDTH-3:0] cfg_memtype_boundary

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
    ,input                               rdlh_link_up
    ,input   ltssm_state_e               smlh_ltssm_state
    ,input   ltssm_cxl_enable_t          ltssm_cxl_enable
    ,output                              cfg_flit_log_trg_evnt_msi
    ,output                              cfg_pcie_cap_flit_mode_stat
    ,input   pm_cdm_state_trans_track_t  pm_cdm_state_trans_tracking
    ,output  [4:0]                       cdm_pm_state_trans_tracker
    ,output                              cfg_flit_latency_msi
    ,output [9:0]                        cfg_flit_perf_interr_vec
    ,output                              cfg_sts_1_ltssm_latency_msi
    ,DWC_cxl_cdmregs_if.master_cdm_mp    b_cxl_cdm
    ,input  protocol_cfg_t               cxl_protocol_cfg             // Protocol Configuration for CXL Controller
    ,input                               cxl_ltssm_enable             // Enable core_rst_n assertion
    ,input                               cxl_dev_cache_invalid        // CXL device indicate cache invalid state
    ,input                               cxl_dev_cache_wr_invld_cmpl  // CXL device indicate cache writeback and invalidation is complete state
    ,input                               cxl_pm_init_cmpl         // CXL PM initalization completion state
    ,input [`CX_CXL_NLD_PLUS_1-1:0]      cxl_volatile_hdm_error       // CXL device indicate Volatile HDM Preservation Error
// Outputs from CXL Register Locator DVSEC
    ,output [`CX_CXL_NLD_PLUS_1-1:0][2:0]         cfg_cxl_reg_locator_reg1_bir
    ,output [`CX_CXL_NLD_PLUS_1-1:0][7:0]         cfg_cxl_reg_locator_reg1_blk_identifier
    ,output [`CX_CXL_NLD_PLUS_1-1:0][15:0]        cfg_cxl_reg_locator_reg1_blk_offset_low
    ,output [`CX_CXL_NLD_PLUS_1-1:0][31:0]        cfg_cxl_reg_locator_reg1_blk_offset_high
    ,output [`CX_CXL_NLD_PLUS_1-1:0][2:0]         cfg_cxl_reg_locator_reg2_bir
    ,output [`CX_CXL_NLD_PLUS_1-1:0][7:0]         cfg_cxl_reg_locator_reg2_blk_identifier
    ,output [`CX_CXL_NLD_PLUS_1-1:0][15:0]        cfg_cxl_reg_locator_reg2_blk_offset_low
    ,output [`CX_CXL_NLD_PLUS_1-1:0][31:0]        cfg_cxl_reg_locator_reg2_blk_offset_high
    ,output [`CX_CXL_NLD_PLUS_1-1:0][2:0]         cfg_cxl_reg_locator_reg3_bir
    ,output [`CX_CXL_NLD_PLUS_1-1:0][7:0]         cfg_cxl_reg_locator_reg3_blk_identifier
    ,output [`CX_CXL_NLD_PLUS_1-1:0][15:0]        cfg_cxl_reg_locator_reg3_blk_offset_low
    ,output [`CX_CXL_NLD_PLUS_1-1:0][31:0]        cfg_cxl_reg_locator_reg3_blk_offset_high  
// Outputs from CXL Port GPF DVSEC
    ,output [3:0]                        cfg_cxl_gpf_port_p1_timeout_base
    ,output [3:0]                        cfg_cxl_gpf_port_p1_timeout_scale
    ,output [3:0]                        cfg_cxl_gpf_port_p2_timeout_base
    ,output [3:0]                        cfg_cxl_gpf_port_p2_timeout_scale
    ,input                               cxl_vlsm_lrsm_req_retrain    // Pulse: NUM_RETRY reached MAX_NUM_RETRY for Ras D.E.S event counter

    ,input                               smlh_link_up
    ,input                               smlh_req_rst_not
    ,output                              link_req_rst_not
    ,input                               brdg_slv_xfer_pending
    ,input                               brdg_dbi_xfer_pending
    ,input                               brdg_mstr_xfer_pending
    ,input                               edma_xfer_pending
    ,output logic  [MSG_TLP_WD-1:0]      radm_vendor_msg
    ,output logic  [MSG_TLP_WD-1:0]      radm_vendor_msg_type
    ,output  logic                       radm_msg_ltr
    ,output logic [(MSG_TLP_WD*64)-1:0]  radm_msg_payload
    ,output  logic                       radm_msg_unlock
    ,output logic                         radm_msg_idle
    ,output logic                         radm_msg_obff
    ,output logic                         radm_msg_cpu_active
    ,output  logic [(MSG_TLP_WD*16)-1:0]  radm_msg_req_id
    ,output logic                         radm_inta_asserted
    ,output logic                         radm_intb_asserted
    ,output logic                         radm_intc_asserted
    ,output logic                         radm_intd_asserted
    ,output logic                         radm_inta_deasserted
    ,output logic                         radm_intb_deasserted
    ,output logic                         radm_intc_deasserted
    ,output logic                         radm_intd_deasserted
    ,output logic                         radm_correctable_err
    ,output logic                         radm_nonfatal_err
    ,output logic                         radm_fatal_err
    ,output logic                         radm_pm_pme
    ,output logic                         radm_pm_to_ack
    ,output logic                         radm_pm_turnoff
    ,output  [`CX_RX_NDLLP-1:0]           rtlh_rfc_upd
    ,output  [(32*`CX_RX_NDLLP)-1:0]      rtlh_rfc_data
    ,output  [`CX_NFUNC-1:0]              cfg_eml_control
    ,output  [`CX_NFUNC-1:0]              hp_pme
    ,output  [`CX_NFUNC-1:0]              hp_int
    ,output  [`CX_NFUNC-1:0]              hp_msi
    ,output                              cfg_comm_clk_config
    ,input                               app_ltssm_enable
    ,output  [`CX_BUSNUM_WD-1:0]         cfg_pbus_num
    ,output  [`CX_DEVNUM_WD-1:0]         cfg_pbus_dev_num
    ,input  [(3*`CX_NFUNC)-1:0]          pm_dstate
    ,input  [`CX_NFUNC-1:0]              pm_status
    ,output                              cfg_link_dis
    ,output                              cfg_link_auto_bw_int
    ,output                              cfg_link_auto_bw_msi
    ,output                              cfg_bw_mgt_int
    ,output                              cfg_bw_mgt_msi
    ,output                              cfg_link_eq_req_int
    ,input                               app_ltr_msg_req
    ,output                              app_ltr_msg_grant
    ,input   [31:0]                      app_ltr_msg_latency
    ,input   [`CX_NFUNC_WD-1:0]          app_ltr_msg_func_num
    ,output  [31:0]                      app_ltr_latency
    ,output  logic [`CX_NVC-1:0]         radm_q_not_empty
    ,output  logic [`CX_NVC-1:0]         radm_qoverflow

    ,output                              trgt_cpl_timeout
    ,output  [`CX_NFUNC_WD-1:0]          trgt_timeout_cpl_func_num
    ,output  [2:0]                       trgt_timeout_cpl_tc
    ,output  [1:0]                       trgt_timeout_cpl_attr
    ,output  [11:0]                      trgt_timeout_cpl_len
    ,output  [`CX_REMOTE_LOOKUPID_WD-1:0]trgt_timeout_lookup_id
    ,output  [`CX_REMOTE_LOOKUPID_WD-1:0]trgt_lookup_id
    ,output                              trgt_lookup_empty

    ,input                               app_hdr_valid
    ,input   [`CX_APP_HDR_LOG_WIDTH-1:0] app_hdr_log
    ,input                               app_hdr_flitmode
    ,input [`CX_APP_HDR_LOG_SZ_WIDTH-1:0]       app_hdr_log_size
    ,input   [`CX_ERR_BUS_WD-1:0]        app_err_bus
    ,input                               app_err_advisory
    ,input                               app_poisoned_tlp_type
    ,input   [`CX_NFUNC_WD-1:0]          app_err_func_num
    ,input   [31:0]                      phy_cfg_status

    ,input  [`CX_NL-1:0]                 mac_phy_txdetectrx_loopback
    ,input  [`CX_NL-1:0]                 mac_phy_rxpolarity
    ,input  [`CX_PHY_RATE_WD-1:0]        mac_phy_rate
    ,input  [`CX_PHY_TXDEEMPH_WD-1:0]    mac_phy_txdeemph
    ,output                              cfg_hw_auto_sp_dis
    ,input                               app_margining_ready
    ,input                               app_margining_software_ready
    ,output  [31:0]                      cfg_phy_control
    ,input                               aux_clk_g
    ,input                               radm_clk_g
    ,output                              en_radm_clk_g
    ,output                              radm_idle
    ,input                               pwr_rst_n // unused
    ,input                               sticky_rst_n
    ,input                               non_sticky_rst_n
    ,input                               core_rst_n
    ,input                               pm_sel_aux_clk
    ,input   [3:0]                       device_type_i
    ,output logic  [3:0]                 device_type_o
    ,input                               app_req_retry_en
    ,input   [`CX_NFUNC-1:0]             app_pf_req_retry_en
    ,input                               app_drs_ready
    ,output [`CX_NFUNC-1:0]              cfg_drs_msi
    ,output [`CX_NFUNC-1:0]              cfg_up_drs_to_frs


    ,input  [`CX_NFUNC-1:0]              app_pf_frs_ready
    ,output [`CX_NFUNC-1:0]              pf_frs_grant
    ,output                              frsq_msi

    ,output [4:0]                        frsq_int_msg_num


  ,output [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_P-1:0]                 radm_formqram_addra_vc0_p         // RAM write address
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_ena_vc0_p           // RAM enable A
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_wea_vc0_p           // RAM write enable A
  ,output [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_P-1:0]                 radm_formqram_dina_vc0_p          // RAM write data A
  ,output [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_P-1:0]                 radm_formqram_addrb_vc0_p         // RAM read address B
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_enb_vc0_p           // RAM enable B
  ,input  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_P-1:0]                 formqram_radm_doutb_vc0_p         // RAM read data B

  ,output [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_NP-1:0]                radm_formqram_addra_vc0_np         // RAM write address
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_ena_vc0_np           // RAM enable A
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_wea_vc0_np           // RAM write enable A
  ,output [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_NP-1:0]                radm_formqram_dina_vc0_np          // RAM write data A
  ,output [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_NP-1:0]                radm_formqram_addrb_vc0_np         // RAM read address B
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_enb_vc0_np           // RAM enable B
  ,input  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_NP-1:0]                formqram_radm_doutb_vc0_np         // RAM read data B

  ,output [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_CPL-1:0]               radm_formqram_addra_vc0_cpl         // RAM write address
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_ena_vc0_cpl           // RAM enable A
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_wea_vc0_cpl           // RAM write enable A
  ,output [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_CPL-1:0]               radm_formqram_dina_vc0_cpl          // RAM write data A
  ,output [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_CPL-1:0]               radm_formqram_addrb_vc0_cpl         // RAM read address B
  ,output [`CX_RADM_FORMQ_NQW-1:0]                               radm_formqram_enb_vc0_cpl           // RAM enable B
  ,input  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_CPL-1:0]               formqram_radm_doutb_vc0_cpl         // RAM read data B

    ///////////////////////////////////////////////////////
    // trgt1 p interfaces
    //
    ,input  logic                            trgt1_radm_intf_p_0_halt

    ////////////////////////////////////////////
    // trgt1 np interfaces
    //
    ,input logic                             trgt1_radm_intf_np_0_halt

    //////////////////////////////////////////
    // trgt1 CPL interface
    //
    ,output trgt1_p_out_s [`CX_RADM_NFC_TRGT_INTF-1:0]      radm_trgt1_out_p
    ,output trgt1_np_out_s [`CX_RADM_NFC_TRGT_INTF-1:0]     radm_trgt1_out_np
    ,output trgt1_cpl_out_s [`CX_RADM_NFC_TRGT_INTF-1:0]    radm_trgt1_out_cpl
    ,output logic                                           radm_trgt1_p_pending
    ,output ras_des_dbg_ntrgt_ntlp_s                        radm_ras_des_err_info_0
    ,input logic                             trgt1_radm_intf_cpl_0_halt




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






    ,output  [`CX_NFUNC-1:0]                    cfg_reg_serren
    ,output  [`CX_NFUNC-1:0]                    cfg_cor_err_rpt_en
    ,output  [`CX_NFUNC-1:0]                    cfg_nf_err_rpt_en
    ,output  [`CX_NFUNC-1:0]                    cfg_f_err_rpt_en
    ,input   [1:0]                       cdm_ras_des_einj0_req
    ,output  [1:0]                       cdm_ras_des_einj0_ack
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
    ,input   [63:0]                      cxpl_debug_info
    
    ,output  [(`CX_NVC)-1:0]             cfg_vc_enable
    ,output  [(`CX_NVC*3)-1:0]           cfg_vc_struc_vc_id_map
    ,output  [23:0]                      cfg_vc_id_vc_struc_map
    ,output  [7:0]                       cfg_tc_enable
    ,output  [23:0]                      cfg_tc_struc_vc_map
    ,input [`CX_NL*`CX_FOMFEEDBACK_WD-1:0]   phy_mac_fomfeedback
    ,input [`CX_NL*`DIRFEEDBACK_WD-1:0]      phy_mac_dirfeedback
    ,input          [`CX_NL-1:0]                 mac_phy_rxeqeval
    
    ,output                              assert_inta_grt
    ,output                              assert_intb_grt
    ,output                              assert_intc_grt
    ,output                              assert_intd_grt
    ,output                              deassert_inta_grt
    ,output                              deassert_intb_grt
    ,output                              deassert_intc_grt
    ,output                              deassert_intd_grt
    ,output  [(8*`CX_NFUNC)-1:0]         cfg_int_pin
   
    ,output  logic [7:0]                 cfg_2ndbus_num
    ,output  logic [7:0]                 cfg_subbus_num
   ,output                               cfg_2nd_reset
    ,output                  cfg_l1sub_en
    
    ,input                   app_clk_pm_en
    
    ,output [`CX_NFUNC-1:0]         cfg_end2end_tlp_pfx_blck
    ,input                  aux_clk_active

    ,output [`CX_NFUNC-1:0]           cfg_ido_req_en
    ,output [`CX_NFUNC-1:0]           cfg_ido_cpl_en

    ,output  [`CX_NFUNC-1:0]          cfg_send_cor_err
    ,output  [`CX_NFUNC-1:0]          cfg_send_nf_err
    ,output  [`CX_NFUNC-1:0]          cfg_send_f_err
    ,output  [`CX_NFUNC-1:0]          cfg_int_disable
    ,output  [`CX_NFUNC-1:0]          cfg_no_snoop_en
    ,output  [`CX_NFUNC-1:0]          cfg_relax_order_en

    ,output                           ptm_context_valid
    ,output                           ptm_responder_rdy_to_validate
    ,output [63:0]                    ptm_local_clock

    ,input                             ptm_external_master_strobe
    ,input [63:0]                      ptm_external_master_time

    ,input                            ptm_auto_update_signal
    ,input                            ptm_manual_update_pulse

    ,output                           ptm_clock_updated
    ,output [63:0]                    ptm_clock_correction
    ,output                           ptm_trigger_allowed
    ,output                           ptm_updating
    ,output                           ptm_req_response_timeout
    ,output                           ptm_req_dup_rx
    ,output                           ptm_req_replay_tx
    ,input                            pm_linkst_in_l0
    ,input                            pm_linkst_in_l0s



    ,output   [(5*`CX_NFUNC)-1:0]     cfg_ats_stu
    ,output   [`CX_NFUNC-1:0]         cfg_ats_cache_en

    ,output   [`CX_NFUNC-1:0]         surprise_down_err

    ,input    [`CX_NFUNC-1:0]         prs_res_failure
    ,input    [`CX_NFUNC-1:0]         prs_uprgi
    ,input    [`CX_NFUNC-1:0]         prs_stopped
    ,output   [`CX_NFUNC-1:0]         cfg_prs_enable
    ,output   [`CX_NFUNC-1:0]         cfg_prs_reset
    ,output   [`CX_NFUNC-1:0]         cfg_prs_stopped
    ,output   [`CX_NFUNC-1:0]         cfg_prs_uprgi
    ,output   [`CX_NFUNC-1:0]         cfg_prs_response_failure
    ,output   [(32*`CX_NFUNC)-1:0]    cfg_prs_outstanding_allocation

    ,output   [`CX_NFUNC-1:0]         cfg_br_ctrl_serren

    ,input    [31:0]                  slv_dbi_addr                   // address in DBI interface
    ,input    [31:0]                  slv_dbi_din                    // wire  data in DBI interface
    ,input                            slv_dbi_cs                     // Chip select to program configuration space registers
    ,input                            slv_dbi_cs2                    // Chip select2 wire  for DBI bus.  Used for changing
    ,input    [3:0]                   slv_dbi_wr                     // Byte write enable
    ,input    [`CX_NFUNC_WD-1:0]      slv_dbi_func_num               // Function number of the DBI access
    ,input    [2:0]                   slv_dbi_bar_num                // BAR number of the DBI access
    ,input                            slv_dbi_rom_access             // ROM BAR of the DBI access
    ,input                            slv_dbi_io_access              // IO BAR of the DBI access
    ,output                           slv_lbc_dbi_ack                // When asserted, indicates that the read/write operation
                                                                     // is completed.
    ,output   [31:0]                  slv_lbc_dbi_dout               // Register read back data bus

    ,input    [`CX_RADM_FORMQ_NQW-1:0]       formqram_radm_parerrb
    ,output   [8:0]                          ras_prot_r_disable
    ,output   [6:0]                          ras_prot_t_disable
    ,output  [`CX_REMOTE_LOOKUPID_WD-1:0] trgt_lookup_id_i




    // RASDP error mode indication from cdm registers
    ,output                             cfg_rasdp_error_mode_i
    ,output logic                       ras_error_tracer_pending
    ,output logic                       ras_dp_unc_err 
    ,output logic                       ras_dp_cor_err 
    ,output logic                       ras_ram_unc_err
    ,output logic                       ras_ram_cor_err
    ,input  ras_dp_err_log_t            axi_bridge_ras_dp_err_log
    ,output ras_dp_err_inj_t            out_ras_dp_err_inj
    ,output logic                       ras_dp_err_inj_wake_up
    ,input  ras_dp_err_log_t            hdma_ras_dp_err_log
    ,output ras_dp_err_inj_t            hdma_ras_dp_err_inj
    // RASDP error mode enable
    ,output                             cfg_rasdp_error_mode_en
    ,output [15:0]                      cfg_err_resp

    ,output [15:0]                      cfg_order_rule_ctrl
    ,output [1:0]                       cfg_ax_mstr_ordr_p_event_sel
    ,output                             cfg_ax_snp_en
    ,output [`CX_NVC-1:0]               cfg_ib_p_id_mng_ctrl
    ,output [3:0]                       cfg_mstr_arcache_mode
    ,output [3:0]                       cfg_mstr_awcache_mode
    ,output [3:0]                       cfg_mstr_arcache_value
    ,output [3:0]                       cfg_mstr_awcache_value
    ,output [31:0]                      cfg_aximstr_msg_addr_high
    ,output [31:0]                      cfg_aximstr_msg_addr_low
    ,output [1:0]                       cfg_mstr_ardomain_mode
    ,output [1:0]                       cfg_mstr_awdomain_mode
    ,output [1:0]                       cfg_mstr_ardomain_value
    ,output [1:0]                       cfg_mstr_awdomain_value
    ,output                             cfg_ax_mstr_zeroread_fw
    ,output                             cfg_axi_clk_gating_en
    ,output                             int_radm_trgt1_mem_type
    ,output [5*`CX_ATU_OUT_NREGIONS_MIN1-1:0]        atu_reg_out_type
    ,output [`CX_NFUNC_WD*`CX_ATU_OUT_NREGIONS_MIN1-1:0]    atu_reg_out_func_num
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]          atu_reg_out_func_bypass
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]          atu_reg_out_snp
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]          atu_reg_out_en
    ,output [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_base
    ,output [`CX_ATU_BASE_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_upr_base
    ,output [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_limit
    ,output [`CX_ATU_MAX_REGION_SIZE*`CX_ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_uppr_limit
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                atu_reg_out_incr_rgn_size
    ,input [`CC_CRGB_DATA_WIDTH - 1:0]      crgb_cdm_rdata
    ,output                                 crgb_cdm_cs
    ,input                                  crgb_cdm_ack
    ,output [`CC_CRGB_ADDR_WIDTH - 1:0]     crgb_cdm_addr
    ,output [`CC_CRGB_DATA_WIDTH - 1:0]     crgb_cdm_wdata
    ,output [`CC_CRGB_BE_WIDTH - 1:0]       crgb_cdm_wr
    ,output                                 crgb_cdm_source
    ,output [`CX_NVC-1:0]                   radm_trgt1_cpl_lookup_id_rlsd // Indicates to the received completion is the last one
    ,output                             radm_trgt1_lookup_id_consmd


    ,input                              brdg_slv_flush_ack

    ,output                             rstctl_slv_flush_req
    ,output                             rstctl_mstr_flush_req
    ,output                             rstctl_flush_done
    ,input  [2:0]                       pm_current_data_rate_others    // reg pm_current_data_rate using core_clk to resolve massive fan-out issues
                                                                    // only used in blocks other than layer1

    ,input  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]    client1_tlp_dma
    ,input  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client1_tlp_dma_channel
    ,output [`CX_ATU_OUT_NREGIONS_MIN1-1:0]       atu_reg_out_invert
    ,output [`CX_NFUNC-1:0]                   cfg_hp_slot_ctrl_access
    ,output [`CX_NFUNC-1:0]                   cfg_dll_state_chged_en
    ,output [`CX_NFUNC-1:0]                   cfg_cmd_cpled_int_en
    ,output [`CX_NFUNC-1:0]                   cfg_pre_det_chged_en
    ,output [`CX_NFUNC-1:0]                   cfg_mrl_sensor_chged_en
    ,output [`CX_NFUNC-1:0]                   cfg_pwr_fault_det_en
    ,output [`CX_NFUNC-1:0]                   cfg_atten_button_pressed_en
    ,output [`CX_NFUNC-1:0]                   cfg_hp_int_en
    ,output                                   cfg_acs_validation_en
    ,output                                   cfg_acs_at_blocking_en
    ,output [`CX_NFUNC-1:0]                   cfg_acs_p2p_req_redirect_en
    ,output [`CX_NFUNC-1:0]                   cfg_acs_p2p_compl_redirect_en
    ,output                                   cfg_acs_up_forward_en
    ,output [`CX_NFUNC-1:0]                   cfg_acs_p2p_egress_ctrl_en
    ,output [`CX_NFUNC-1:0]                   cfg_acs_p2p_direct_transl_en
    ,output [(`ACS_CTRL_VEC_WD*`CX_NFUNC)-1:0]cfg_acs_egress_ctrl_vec

    
    ,input                               app_req_flush
    ,output                             cfg_upd_aspm_ctrl
    ,output                             cfg_aspm_l1_timer_enable
    ,output [(`CX_NFUNC - 1) : 0]       cfg_upd_aslk_pmctrl
    ,output [`CX_NFUNC-1:0]             cfg_upd_pme_cap
    ,output                             cfg_elastic_buffer_mode
    ,output                             rstctl_ltssm_enable
    ,output                             rstctl_core_flush_req
    ,output                             upstream_port
    ,input                              xdlh_nodllp_pending
    ,input                              xdlh_xmt_pme_ack
    ,input                              smlh_link_in_training
    ,input                              xdlh_not_expecting_ack
    ,output [`CX_NVC-1:0]               xadm_had_enough_credit
    ,input                              smlh_in_l0
    ,input                              smlh_in_l0s
    ,input                              smlh_in_rl0s
    ,input                              smlh_in_l1
    ,input                              smlh_in_l23
    ,output                             xaim_tlp_pending
    ,output                             xadm_tlp_pending
    ,input                              xtlh_tlp_pending
    ,output [`CX_NVC-1:0]               xadm_no_fc_credit
    ,output [(2*`CX_NFUNC)-1:0]         cfg_aslk_pmctrl
    ,output [2:0]                       cfg_l0s_entr_latency_timer
    ,output [2:0]                       cfg_l1_entr_latency_timer
    ,output                             cfg_l1_entr_wo_rl0s
    ,output [`CX_NFUNC-1:0]             cfg_upd_pmcsr
    ,output [`CX_NFUNC-1:0]             cfg_upd_aux_pm_en
    ,output [`CX_NFUNC-1:0]             cfg_pmstatus_clr
    ,output [(3*`CX_NFUNC)-1:0]         cfg_pmstate
    ,output [`CX_NFUNC-1:0]             cfg_pme_en
    ,output [`CX_NFUNC-1:0]             cfg_aux_pm_en
    ,output [`CX_NFUNC-1:0]             cfg_upd_req_id
    ,output                             cfg_clk_pm_en
    ,output logic                       radm_pm_asnak
    ,output logic                       int_radm_pm_to_ack
    ,output [(5*`CX_NFUNC)-1:0]         cfg_pme_cap
    ,output [`CX_L1SUB_CONTROL_WD-1:0]    cfg_l1sub_control
    ,output [`CX_PL_L1SUB_CONTROL_WD-1:0] cfg_pl_l1sub_control
    ,output                               cfg_pl_l1_exit_mode
    ,output                             cfg_pl_l1_nowait_p1
    ,output                             cfg_pl_l1_clk_sel
    ,output                             cfg_p2nobeacon_enable
    ,output wire [31:0]                 cfg_utility
    ,input wire [31:0]                  pm_cfg_utility
    ,output                             cfg_pipe_optional_pclkchange_hs
    ,output                             cfg_phy_perst_on_warm_reset
    ,output [17:0]                      cfg_phy_rst_timer
    ,output [5:0]                       cfg_pma_phy_rst_delay_timer
    ,output [3:0]                       cfg_dsp_pcipm_l1_enter_delay
    ,output [`CX_PL_AUX_CLK_FREQ_WD-1:0]cfg_pl_aux_clk_freq
    ,output                             cfg_pl_gen3_zrxdc_noncompl
    ,output                             pme_to_ack_grt
    ,output                             radm_trgt0_pending
    ,output                             lbc_active
    ,output [`CX_NFUNC-1:0]             pm_pme_grant
    ,output                             pme_turn_off_grt
    ,output [7:0]                       int_cfg_pbus_num
    ,output [4:0]                       int_cfg_pbus_dev_num
    ,output                             msg_gen_asnak_grt
    ,input  [`CX_L2NL-1:0]              smlh_lane_flip_ctrl  //flip lanes with latched for gen3/4 enter polling.Compliance
    ,output                             cfg_link_retrain
    ,output                             cfg_lpbk_en
    ,output                             cfg_plreg_reset
    ,output                             cfg_directed_speed_change      // config bit to start speed change
    ,output [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control
    ,output                             msg_gen_unlock_grant
    ,input [2:0]                        pm_current_data_rate       // current_data_rate shadowed in pm_ctrl
    ,input                              pm_smlh_l1_exit
    ,input usp_link_fsm_state_e         pm_usp_link_state
    ,input usp_prot_fsm_state_e         pm_usp_prot_state
    ,input dsp_link_fsm_state_e         pm_dsp_link_state
    ,input dsp_prot_fsm_state_e         pm_dsp_prot_state
    ,input pm_active_l0s_fsm_e          pm_l0s_state
    ,input                              pm_xmt_asnak
    ,input                              pm_xmt_turnoff
    ,input [`CX_NFUNC-1:0]              pm_xmt_to_ack
    ,input [`CX_NFUNC-1:0]              pm_xmt_pme
    ,input                              pm_turnoff_timeout
    ,input [`CX_BUSNUM_WD -1:0]         pm_bus_num
    ,input [`CX_DEVNUM_WD -1:0]         pm_dev_num
    ,input [(`CX_PHY_PDOWN_WD - 1) : 0] pm_int_phy_powerdown
    ,input [2:0]                        l1sub_state
    ,input                              pm_in_l11      // Level: L1.1 Entry for Ras D.E.S event counter
    ,input                              pm_in_l12      // Level: L1.2 Entry for Ras D.E.S event counter
    ,input                              pm_in_l1_short // Level: L1 short duration for Ras D.E.S event counter
    ,input                              pm_in_l1_cpm   // Level: L1 Clock PM (L1 with REFCLK removal/PLL Off) for Ras D.E.S event counter
    ,input                              pm_in_l1_abort // Level: L1.2 abort for Ras D.E.S event counter
    ,input                              pm_pme_resend_flag  // Level : PME Re-Send flag
    ,input [`CX_NL*`CX_PHY_TXEI_WD-1:0] int_phy_txelecidle
    ,input                              pm_sys_aux_pwr_det
    ,input [`CX_NFUNC-1:0]              pm_pme_en_split
    ,input [`CX_NFUNC-1:0]              pm_aux_pm_en_split
    ,input                              pm_unlock_msg_req
    ,input                              pm_l1_aspm_entr
    ,input                              pm_block_all_tlp
    ,input [`CX_NFUNC-1:0]              pm_radm_block_tlp
    ,output                             trgt_cpl_lut_empty


    ,output logic                           core_in_dpc                 // When asserted core is in Downstream Port Containment mode and LTSSM is in DISABLE state.
    ,output  logic    [4:0]                 cfg_dpc_int_msg_num                  // DPC Interrupt Message Number
    ,output  logic                          cfg_dpc_rp_ext_dpc                   // DPC Root Port Extensions for DPC
    ,output  logic                          cfg_dpc_poison_tlp_egr_blk_support   // DPC Poisoned TLP Egress Blocking Supported
    ,output  logic                          cfg_dpc_sw_trig_support              // DPC Software Triggering Supported
    ,output  logic    [3:0]                 cfg_dpc_rp_pio_log_size              // DPC RP PIO Log Size
    ,output                                 cfg_dpc_dl_active_err_cor_support    // DPC DL_Active ERR_COR Signaling Supported
    ,output   logic   [1:0]                 cfg_dpc_trig_en                      // DPC Trigger Enable
    ,output  logic                          cfg_dpc_cpl_cntrl                    // DPC Completion Control
    ,output logic                           cfg_dpc_int_en                       // DPC Interrupt Enable
    ,output  logic                          dpc_int                              // DPC Interrupt for INTx signalling
    ,output  logic                          dpc_msi                              // DPC Interrupt for MSI signalling
    ,output logic                           cfg_dpc_err_cor_en                   // DPC ERR_COR Enable
    ,output  logic                          cfg_dpc_poison_tlp_egr_block_en      // Poisoned TLP Egress Blocking Enable
    ,output  logic                          cfg_dpc_sw_trigger                   // DPC Software Trigger
    ,output  logic                          cfg_dpc_dl_active_err_cor_en          // DL_Active ERR_COR Enable
    ,input     [4:0]                  app_dev_num                   // Device number set by application
    ,input     [7:0]                  app_bus_num                   // Bus number    set by application
    ,output                           msg_gen_hv // header valid for message generation
    ,output                           lbc_cpl_hv // header valid for CPL
    ,input  [`CX_NL-1:0]                              pm_latched_rxdetected
    ,input  [(2 * `CX_PHY_PDOWN_WD) - 1 : 0]      pm_powerdown_status
    ,output                                       cfg_force_powerdown
    ,output                                       cfg_uncor_internal_err_sts
    ,output                                       cfg_rcvr_overflow_err_sts
    ,output                                       cfg_fc_protocol_err_sts
    ,output                                       cfg_mlf_tlp_err_sts
    ,output                                       cfg_surprise_down_er_sts
    ,output                                       cfg_dl_protocol_err_sts
    ,output                                       cfg_ecrc_err_sts
    ,output                                       cfg_corrected_internal_err_sts
    ,output                                       cfg_replay_number_rollover_err_sts
    ,output                                       cfg_replay_timer_timeout_err_sts
    ,output                                       cfg_bad_dllp_err_sts
    ,output                                       cfg_bad_tlp_err_sts
    ,output                                       cfg_rcvr_err_sts
    ,output [5:0]                                 cfg_link_capable
    ,output [`CX_NFUNC-1:0]                       cfg_advisory_nf_sts
    ,output [`CX_NFUNC-1:0]                       cfg_hdr_log_overflow_sts    // Header Log Overflow Status ,found in Correctable Error Status Register

    ,output     logic [31:0]                      radm_slot_pwr_payload
    ,output    logic                              radm_slot_pwr_limit






   ,output rplh_flit_unrecognized_flit
   ,output rplh_flit_ecc_corr_err
   ,output rplh_flit_ecc_uncorr_err
   ,output rplh_flit_crc_uncorr_err
   ,input pm_pclkack_timeout                       // t_pclkack timeout trigger internal error
   ,output       cfg_pcie_slot_clk_config
   ,input [3:0]  smlh_autoneg_link_sp
   ,output [5:0] cfg_neg_link_width
    ,input                                               xdlh_retrybuf_not_empty    
,output logic                cfg_p2p_track_cpl_to
,input ras_dp_err_log_t      ras_dp_err_log_from_xtlh
,input ras_dp_err_log_t      ras_dp_err_log_from_xdlh
,input ras_dp_err_log_t      ras_dp_err_log_from_xplh
,input ras_dp_err_log_t      vlsm_ras_dp_err_log
,output  ras_dp_err_inj_t    ras_dp_err_inj
,output logic [6:0]         cfg_tx_arb_control
,input                       smlh_l0p_capable
,output logic [2:0]          cfg_local_l0p_exit_latency
,output logic                cfg_l0p_receiver_support   // L0p Receiver Support
,output logic                cfg_l0p_enable             // L0p Enable
,output logic                cfg_l0p_autowidth_dis      // Hardware Autonomous Width Disable bit in the Link Control register (bit[9])
,output logic                cfg_l0p_priority           // Port Logic register bit to set L0p.Priority bit in DLLP
,output logic [2:0]          cfg_l0p_linkmode           // Target Link Width in Device Control 3 Register (bit[6:4])
,output logic                cfg_l0p_linkmode_req       // Link Width change request asserted on the write access to Device Control 3 Register
,output logic [5:0]          cfg_l0p_max_link_width     // Maximum supported Link Width
,output logic [5:0]          cfg_l0p_neg_link_width     // Negotiated Link Width
,output logic                cfg_pcie_l0p_disable       // PCIe/CXL.io: Disable dynamic L0p
,output logic                cfg_pcie_l0p_request       // PCIe/CXL.io: L0p Request bit
,output logic                cfg_pcie_l0p_priority      // PCIe/CXL.io: L0p Priority bit
,output logic  [2:0]         cfg_pcie_l0p_linkmode      // PCIe/CXL.io: L0p Target Link Width
,output logic                cfg_cxl_l0p_disable        // CXL.cachemem: Disable dynamic L0p
,output logic                cfg_cxl_l0p_request        // CXL.cachemem: L0p Request bit
,output logic                cfg_cxl_l0p_priority       // CXL.cachemem: L0p Priority bit
,output logic  [2:0]         cfg_cxl_l0p_linkmode       // CXL.cachemem: L0p Target Link Width
,output logic                cfg_flit_mode_enable
,output logic                cfg_pcie_cap_flit_mode_sup
,output logic                cfg_flit_mode_dis
,output logic                cfg_flit_sris_clocking
,output logic  [CFG_CXL_PORT_ENABLE_WD-1:0]  cfg_cxl_port_enable
,output logic  [15:0]                        cfg_cxl_port_vid
,output logic                                cfg_cxl_retimers_pre_mismatched
,output logic    [1:0]                       cfg_retimers_pre_detected
,output logic                      cfg_pm_timeout_enable     // ARB/MUX PM Timeout Control Register - PM Timeout Enable
,output logic [1:0]                cfg_pm_timeout_value      // ARB/MUX PM Timeout Control Register - PM Timeout Value
,input                             cfg_pm_timeout_error      // ARB/MUX Uncorrectable Error Status Register - PM Timeout Error
,input vlsm_debug_t                vlsm_debug_info         // vLSM Debug Information Bus
,output logic                      end_device
,output logic                      rc_device
,output logic                      cfg_dll_lnk_en
,output logic  [7:0]               cfg_ack_freq
,output logic  [15:0]              cfg_ack_latency_timer
,output logic  [16:0]              cfg_replay_timer_value
,output logic  [12:0]              cfg_fc_latency_value
,output logic  [31:0]              cfg_other_msg_payload
,output logic                      cfg_other_msg_request
,output logic  [31:0]              cfg_corrupt_crc_pattern
,output logic                      cfg_flow_control_disable       // disable the automatic flowcontrol built in this core
,output logic                      cfg_acknack_disable
,output logic                      cfg_scramble_dis
,output logic  [7:0]               cfg_n_fts
,output logic                      cfg_reset_assert
,output logic  [7:0]               cfg_link_num
,output logic                      cfg_ts2_lid_deskew_i
,output logic                      cfg_support_part_lanes_rxei_exit
,output logic  [5:0]               cfg_forced_link_state
,output logic  [3:0]               cfg_forced_ltssm_cmd
,output logic                      cfg_force_en
,output logic                      cfg_fast_link_mode
,output logic  [1:0]               cfg_fast_link_scaling_factor
,output logic                      cfg_l0s_supported
,output logic  [22:0]              cfg_lane_skew
,output logic                      cfg_deskew_disable
,output logic  [3:0]               cfg_imp_num_lanes
,output logic  [10:0]              cfg_skip_interval
,output logic                      cfg_ext_synch
,output logic                      cfg_hw_autowidth_dis
,output logic  [2:0]               cfg_highest_max_payload
,output logic  [2:0]               cfg_max_payload_size_out_rx // In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field .
,output logic                      cfg_fc_wdog_disable
,output logic  [(`CX_NVC*8)-1:0]   cfg_fc_credit_ph
,output logic  [(`CX_NVC*8)-1:0]   cfg_fc_credit_nph
,output logic  [(`CX_NVC*8)-1:0]   cfg_fc_credit_cplh
,output logic  [(`CX_NVC*12)-1:0]  cfg_fc_credit_pd
,output logic  [(`CX_NVC*12)-1:0]  cfg_fc_credit_npd
,output logic  [(`CX_NVC*12)-1:0]  cfg_fc_credit_cpld             // (PL) Flow Control credits - Completion Data
,output logic                      dl_feature_en                  // indicates Data Link Features supported
,output logic                      cfg_remote_feature_ack         // Indicates remote Data Link Features handshake completed
,output logic  [22:0]              cfg_local_feature_support      // Local Feature (Including local scaled flow control) Support
,output logic                      cfg_dlink_feature_valid
,output logic  [(`CX_NVC*2)-1:0]   hdr_scale_p                    // The HdrScale field contains the scaling factor for headers of the indicated type
,output logic  [(`CX_NVC*2)-1:0]   data_scale_p                   // The DataScale field contains the scaling factor for payload data of the indicated type
,output logic  [(`CX_NVC*2)-1:0]   hdr_scale_np                   // The HdrScale field contains the scaling factor for headers of the indicated type
,output logic  [(`CX_NVC*2)-1:0]   data_scale_np                  // The DataScale field contains the scaling factor for payload data of the indicated type
,output logic  [(`CX_NVC*2)-1:0]   hdr_scale_cpl                  // The HdrScale field contains the scaling factor for headers of the indicated type
,output logic  [(`CX_NVC*2)-1:0]   data_scale_cpl                 // The DataScale field contains the scaling factor for payload data of the indicated type
,output logic                      fc_scaled_en
,output logic  [5:0]               cfg_margin_num_timing_steps
,output logic  [5:0]               cfg_margin_max_timing_offset
,output logic  [6:0]               cfg_margin_num_voltage_steps
,output logic  [5:0]               cfg_margin_max_voltage_offset
,output logic  [5:0]               cfg_margin_sample_rate_voltage
,output logic  [5:0]               cfg_margin_sample_rate_timing
,output logic  [4:0]               cfg_margin_maxlanes
,output logic                      cfg_margin_voltage_supported
,output logic                      cfg_margin_ind_up_down_voltage
,output logic                      cfg_margin_ind_left_right_timing
,output logic                      cfg_margin_sample_reporting_method
,output logic                      cfg_margin_ind_error_sampler
,output logic  [3:0]               cfg_rx_message_bus_write_buffer_depth
,output logic                      cfg_pipe_garbage_data_mode
,output logic                      cfg_pam4_restricted_levels_requirement
,output logic  [`CX_NFUNC_WD-1:0]     cfg_max_func_num
,output logic    [8:0]                       cfg_lane_en                    // pre-determined number of lanes
,output logic                                cfg_gen1_ei_inference_mode     // EI inference mode for Gen1. default 0 - using rxelecidle==1, 1 - using rxvalid==0
,output logic    [1:0]                       cfg_select_deemph_mux_bus      // sel deemphasis {bit, var}
,output logic    [`CX_LUT_PL_WD-1:0]         cfg_lut_ctrl                   // lane under test + gen5 control
,output logic    [7:0]                       cfg_rxstandby_control          // Rxstandby Control
,output logic    [`CX_PL_GEN3_CONTROL_WD-1:0]    cfg_pl_gen3_control
,output logic    [`CX_PL_GEN3_EQ_CONTROL_WD-1:0] cfg_pl_gen3_eq_control
,output logic                                    cfg_no_seed_value_change
,output logic    [`CX_DIR_CHANGE_CONTROL_WD-1:0] cfg_fdbk_dirchange_control
,output logic                                    cfg_perform_eq
,output logic                                    cfg_ls2_eq_req
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_pset_ltx
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         int_cfg_lec_pset_lrx
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_pset_rtx
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         int_cfg_lec_pset_rrx
,output logic    [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen4_control
,output logic    [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen4_eq_control
,output logic    [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen4_fdbk_dirchange_control
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         cfg_lec_g4_pset_lrx
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]         cfg_lec_g4_pset_rrx
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_g4_pset_ltx
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_cfg_lec_g4_pset_rtx
,input    [`CX_NL*`CX_TX_PSET_WD-1:0]                int_smlh_lec_g4_pset_ltx
,output logic    [`CX_PL_GEN4_CONTROL_WD-1:0]    cfg_pl_gen5_control
,output logic    [`CX_PL_GEN4_EQ_CONTROL_WD-1:0] cfg_pl_gen5_eq_control
,output logic    [`CX_GEN4_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen5_fdbk_dirchange_control
,output logic                                cfg_bypass_eq_enable
,output logic                                cfg_no_eq_needed_enable
,output logic                                cfg_tx_precode_req
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g5_pset_lrx
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g5_pset_rrx
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g5_pset_ltx
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g5_pset_rtx
,input    [`CX_NL*`CX_TX_PSET_WD-1:0]            int_smlh_lec_g5_pset_ltx
,output logic    [`CX_PL_GEN6_CONTROL_WD-1:0]    cfg_pl_gen6_control
,output logic    [`CX_PL_GEN6_EQ_CONTROL_WD-1:0] cfg_pl_gen6_eq_control
,output logic    [`CX_GEN6_DIR_CHANGE_CONTROL_WD-1:0] cfg_gen6_fdbk_dirchange_control
,output logic                                    cfg_g6_tx_precode_req
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g6_pset_ltx
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]     int_cfg_lec_g6_pset_rtx
,input    [`CX_NL*`CX_TX_PSET_WD-1:0]            int_smlh_lec_g6_pset_ltx
,output logic                                cfg_alt_protocol_enable
,output logic                                cfg_gen2_support               // core is enabled to run at gen 2 speeds
,output logic    [7:0]                       cfg_gen2_n_fts                 // number of fts's to send in gen 2 speeds
,output logic                                cfg_enter_compliance           // config bit to enter the compliance state
,output logic                                cfg_sel_de_emphasis
,output logic    [2:0]                       cfg_transmit_margin
,output logic                                cfg_enter_mod_compliance
,output logic                                cfg_compliance_sos
,output logic    [3:0]                       cfg_compliance_de_emphasis
,output logic    [3:0]                       cfg_pcie_max_link_speed        // Max link speed
,output logic    [3:0]                       cfg_target_link_speed          // Target link speed
,output logic                                cfg_phy_txswing                // controls mac_phy_txswing signal to the phy
,output logic                                cfg_tx_compliance_rcv          // Sets the compliance received bit in the TS1
,output logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_ph_ca                // Credit allocated (posted header)
,output logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_pd_ca                // Credit allocated (posted data)
,output logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_nph_ca               // Credit allocated (non-posted heade
,output logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_npd_ca               // Credit allocated (non-posted data)
,output logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_cplh_ca              // Credit allocated (completion heade
,output logic    [DCA_WD*`CX_NVC-1:0]            int_rtlh_cpld_ca              // Credit allocated (completion data)
,output logic                                  cfg_rasdp_linkdown_en       // Enable Link Down on RASDP uncorrectable error
,output logic                                  rasdp_linkdown
,output xtlh_pkt_t [`N_XADM_IF-1:0]             xadm_xtlh_pkt                  // XADM XTLH Packet Interfaces
,input             [`N_XADM_IF-1:0]             xtlh_xadm_pkt_halt             // XTLH XADM Packet Halts
,input             [`N_XADM_P_IF-1:0]           xtlh_xadm_posted_tlp_sent
,output logic                                xadm_all_type_infinite
,output logic                                cfg_drift_buffer_deskew_enable
,input          correctable_protocol_id_frame_err
,input          uncorrectable_protocol_id_frame_err
,input          unexpected_protocol_id_dropped
,input [23:0]   ltssm_cxl_mod_ts_phase1_rcvd    // Received Modified TS Data Phase1
,input          ltssm_cxl_retimers_pre_mismatched   // Set CXL_Retimers_Present_Mismatched bit
,input          ltssm_cxl_flexbus_phase2_mismatched // Set FlexBusEnableBits_Phase2_Mismatch bit
,input rplh_flit_logging_interface_struct rplh_flit_logging_interface
,input rmlh_flit_logging_interface_struct rmlh_flit_logging_interface
,input smlh_flit_logging_interface_struct smlh_flit_logging_interface
,output logic                             cfg_tx_throttling
,output logic                          cfg_flit_err_inj_latency
,output flit_err_inj_interface_struct  cdm_plh_flit_err_inj_interface
,input flit_err_inj_status_struct      plh_cdm_flit_err_inj_status
,output cfg_os_einj_ctrl_1_t           cfg_os_einj_ctrl_1
,output cfg_os_einj_ctrl_2_t           cfg_os_einj_ctrl_2
,input cfg_os_einj_status_t            xmlh_tx_os_einj_status
,output logic  [2:0]         cdm_xplh_flit_response_type
,output logic  [1:0]         cdm_xplh_flit_type_measured
,output logic                cdm_xplh_flit_track_mode
,input  xplh_cdm_flit_latency_track_t        xplh_cdm_flit_latency_tracking
,output logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen3_eq_fs_lf              // programmable FS and LF for equalization
,output logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen3_eq_coef               // programmable FS and LF for equalization
,output logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen4_eq_fs_lf              // programmable FS and LF for equalization
,output logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen4_eq_coef               // programmable FS and LF for equalization
,output logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen5_eq_fs_lf              // programmable FS and LF for equalization
,output logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen5_eq_coef               // programmable FS and LF for equalization
,output logic    [`CX_TX_FSLF_WD-1:0]              cfg_gen6_eq_fs_lf              // programmable FS and LF for equalization
,output logic    [(11*`CX_TX_COEF_WD)-1:0]          cfg_gen6_eq_coef               // programmable FS and LF for equalization
,output logic    [7:0]                     cfg_l1sub_t_common_mode
,output logic    [(2*`CX_NFUNC)-1:0]       cfg_max_end2end_tlp_prfxs   // the maximum number of End-End TLP Prefixes supported, DBI writeable.
,output logic    [1:0]                     cdm_ras_des_pm_entry_interval            // Level : Low Power Entry Interval Time for Ras D.E.S Silicon Debug
,output logic    [1:0]                     cdm_ras_des_eidle_cnt_sel                // Level : Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_ltssm_stop                   // Level : Low Power Entry Interval Time for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_recovery_req                 // Level : Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_ferr_rec_dis                 // Level : Disable Recovery state transition at Framing Error for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_direct_rcvry_idle_to_cfg     // Level : Direct LTSSM from Recovery.Idle to Configuration for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_direct_poll_cmp_to_det       // Level : Direct LTSSM from Polling.Compliance to Detect for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_direct_lpbk_slave_to_exit    // Level : Direct LTSSM from Loopback(Slave) to Exit for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_force_rxdetected_en          // Level : Force Detect Lane Num enable for Ras D.E.S Silicon Debug
,output logic                              cdm_ras_des_force_linkdown_noack         // Level : Force Link down when MAC does not receive ACK DLLP for long time
,output logic    [1:0]                     cdm_ras_des_ext_eq_to_factor             // Extend the eq 24/32ms timeout x2/x10
,output logic                              cdm_ras_des_eq_fom_target_en             // FOM target enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en         // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_lrx_en         // Force Local Rx Preset Hint Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en         // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ ControlQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_ltx            // Level : Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_RX_PSET_WD-1:0]   cdm_ras_des_eq_force_pset_lrx            // Level : Force Local Receiver Preset Hint for Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_rtx            // Level : Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en         // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx        // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en_g4      // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en_g4      // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ ControlQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_ltx_g4         // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_rtx_g4         // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en_g4      // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx_g4     // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en_g5      // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en_g5      // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ ControlQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_ltx_g5         // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_rtx_g5         // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en_g5      // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx_g5     // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_rtx_en_g6      // Force Remote Tx Cursor Coefficient Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_coef_ltx_en_g6      // Force local Tx Cursor Coefficient Enable for Ras D.E.S Silicon Debug EQ ControlQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_ltx_g6         // Force Local Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_COEF_WD-1:0]   cdm_ras_des_eq_force_coef_rtx_g6         // Force Remote Transmitter cursor coefficient  for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL-1:0]                  cdm_ras_des_eq_force_pset_ltx_en_g6      // Force Local Tx Preset Enable for  Ras D.E.S Silicon Debug EQ Control
,output logic    [`CX_NL*`CX_TX_PSET_WD-1:0]   cdm_ras_des_eq_force_usp_pset_ltx_g6     // force upstream port's initial tx preset value for RASDES Silicon Debug EQ Control
,output logic    [`CX_FOMFEEDBACK_WD-1:0]  cdm_ras_des_eq_fom_target                // Level : FOM Target value for Ras D.E.S Silicon Debug EQ Control
,output logic    [1:0]                     cdm_ras_des_eq_eval_interval             // Level : EVAL Interval Time for Ras D.E.S Silicon Debug EQ Control
    
,output logic                              cdm_ras_des_einj0_enable                 // Error injection 0 enable
,output logic    [7:0]                     cdm_ras_des_einj0_count                  // Error injection 0 count
,output logic    [3:0]                     cdm_ras_des_einj0_crc_type               // Error injection 0 CRC type
,output logic                              cdm_ras_des_einj1_enable                 // Error injection 1 enable
,output logic                              cdm_ras_des_einj1_seq_type               // Error injection 1 seq# type
,output logic    [12:0]                    cdm_ras_des_einj1_bad_seq                // Error injection 1 bad seq# value
,output logic    [7:0]                     cdm_ras_des_einj1_count                  // Error injection 1 count
,output logic                              cdm_ras_des_einj2_enable                 // Error injection 2 enable
,output logic    [1:0]                     cdm_ras_des_einj2_dllp_type              // Error injection 2 DLLP type
,output logic                              cdm_ras_des_einj3_enable                 // Error injection 3 8b/10b K-code mask enable
,output logic    [7:0]                     cdm_ras_des_einj3_count                  // Error injection 3 8b/10b K-code mask count
,output logic    [2:0]                     cdm_ras_des_einj3_smb_type               // Error injection 3 8b/10b K-code mask type
,output logic                              cdm_ras_des_einj4_enable                 // Error injection 4 enable
,output logic    [2:0]                     cdm_ras_des_einj4_updfc_type             // Error injection 4 UpdateFC type
,output logic    [2:0]                     cdm_ras_des_einj4_vcnum                  // Error injection 4 VC number
,output logic    [12:0]                    cdm_ras_des_einj4_badfc_value            // Error injection 4 bad FC value
,output logic                              cdm_ras_des_einj5_enable                 // Error injection 5 enable
,output logic    [7:0]                     cdm_ras_des_einj5_count                  // Error injection 5 count
,output logic                              cdm_ras_des_einj5_tlp_type               // Error injection 5 tlp type (dup/nul)
,input    [5:0]                       smlh_autoneg_link_width
,input    [5:0]                       rplh_link_rxmode
,input                                smlh_link_training_in_prog
,input                                 latched_flit_mode_enable // Drives XADM/XAIM/RADM/IDE
,input                                 smlh_flit_mode_enable
,input                               smlh_bw_mgt_status             // Indicate that link retraining (via retrain bit) or HW autonomous link speed change has occurred
                                                                    // without the port transitioning through DL_Down status
,input                               smlh_link_auto_bw_status       // Indicate that hardware has autonomously changed link speed or width, without the port transitioning through
                                                                    // DL_Down status, for reasons other than to attempt to correct unreliable link operation.
,input                                smlh_clr_enter_compliance      // Signal the cdm that the "Enter Compliance" bit in the "Link Control" register should be cleared
,input                                smlh_tx_margin_rst             // Signal the cdm to reset the transmit margin
,input                                smlh_core_rst_n_release_pulse  // assign DEFAULT_GEN2_SPEED_CHANGE to cfg_directed_speed_change
,input                                smlh_dir_spd_chg_rising_edge   // clear cfg_directed_speed_change
,input                                smlh_dir_linkw_chg_started     // clear cfg_directed_link_width_change
,input                                smlh_ltssm_in_hotrst_dis_entry
,input                                smlh_ls2_eq_req                // Equalization Request
,input    [3:1]                       smlh_ls2_eq_success            // Equalization Successful {Phase 3, Phase 2, Phase 1}
,input                                smlh_ls2_eq_cmpl               // Equalization Complete
,input                                smlh_ls2_eq_enter              // Equalization Entered
,input                                smlh_ltssm_in_detectquiet
,input                                smlh_ls2_g4_eq_req                // Equalization Request
,input    [3:1]                       smlh_ls2_g4_eq_success            // Equalization Successful {Phase 3, Phase 2, Phase 1}
,input                                smlh_ls2_g4_eq_cmpl               // Equalization Complete
,input                                smlh_ls2_g4_eq_enter              // Equalization Entered
,input    [`CX_NL*`CX_RX_PSET_WD-1:0]     smlh_lec_g4_pset_lrx
,input                                smlh_retimer_pre_detected
,input                                smlh_ls2_g5_eq_req                // Equalization Request
,input    [3:1]                       smlh_ls2_g5_eq_success            // Equalization Successful {Phase 3, Phase 2, Phase 1}
,input                                smlh_ls2_g5_eq_cmpl               // Equalization Complete
,input                                smlh_ls2_g5_eq_enter              // Equalization Entered
,input    [`CX_NL*`CX_RX_PSET_WD-1:0]     smlh_lec_g5_pset_lrx
,input    [1:0]                       smlh_elbc_rcvd
,input                                smlh_tx_precoding_on
,input                                smlh_noeq_needed_rcvd
,input                                smlh_ls2_g6_eq_req                // Equalization Request
,input    [3:1]                       smlh_ls2_g6_eq_success            // Equalization Successful {Phase 3, Phase 2, Phase 1}
,input                                smlh_ls2_g6_eq_cmpl               // Equalization Complete
,input                                smlh_ls2_g6_eq_enter              // Equalization Entered
,input    [`CX_NL*`CX_RX_PSET_WD-1:0]     smlh_lec_g6_pset_lrx
,input                                smlh_g6_tx_precoding_on
,input                                smlh_two_retimers_pre_detected
,input  [1:0]                         smlh_crosslink_resolution
,input                                smlh_margin_ready
,input                                smlh_mod_ts_rcvd
,input  [55:0]                        mod_ts_data_rcvd   // {info2[23:0], vendor_id[15:0], info1[15:5], ap_negotiation[1:0], mod_ts_usage_mode[2:0]}
,input  [55:0]                        mod_ts_data_sent_i // {info2[23:0], vendor_id[15:0], info1[15:5], ap_negotiation[1:0], mod_ts_usage_mode[2:0]}
,input                                rmlh_rcvd_err
,input                                dl_prot_err
,input                                rdlh_bad_tlp_err
,input                                rdlh_bad_dllp_err
,input    [1:0]                       rdlh_dlcntrl_state
,input                                rdlh_link_down
,input                                rdlh_rcvd_dl_feature           // Feature DLLP Received
,input [31:0]                         rcvd_dl_feature_content        // 32 bits indicates the rcvd special dllp content
,input                              replay_num_rlover_err
,input                              replay_timeout_err
,input rtlh_radm_datapath_t         rtlh_radm
,output logic [`CX_RAS_ERROR_INJ_EN_WD-1:0]  ras_err_inj_en_array
,output logic [`CX_RAS_ERROR_INJ_MASK_WD-1:0]ras_err_inj_mask
,input                                       ras_err_inj_done_cx_pl
,input    [`CX_NVC-1:0]               rtlh_fc_init_status
,input    [`CX_NVC-1:0]               rtlh_crd_not_rtn
,input rtlh_rfc_t                     rtlh_rcvd_fc                   // Received FC update: Update Transmit credit information
,output logic    [`RBUF_PW -1:0]             retryram_xdlh_depth
,output logic    [`SOTBUF_L2DEPTH -1:0]      retrysotram_xdlh_depth
,input [ `CX_RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_corr
,input [ `CX_RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_corr
,input [ `CX_RAS_RDLH_COUNTERS-1:0] ras_stat_rdlh_uncorr
,input [ `CX_RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_uncorr
,input   [1:0]                                cxpl_cdm_ras_des_einj0_ack
,input    [7:0]                       rtfcgen_ph_diff
,input                                rtlh_overfl_err
,input                                xdlh_retry_req                           // Puls : Retry Event
,input    [`CX_NL-1:0]                  rpipe_rxelecidle                         // Level : PIPE: RxElecIdle for Ras D.E.S Silicon Debug
,input    [`CX_NL-1:0]                  rmlh_rpipe_rxoverflow                    // Pulse: Rx elastic buffer overflow error status if the corresponding lane detected a lane-based error
,input    [`CX_NL-1:0]                  rmlh_rpipe_rxunderflow                   // Pulse: Rx elastic buffer underflow error status if the corresponding lane detected a lane-based error
,input    [`CX_NL-1:0]                  rmlh_rpipe_rxcodeerror                   // Pulse: Rx symbol error status if the corresponding lane detected a lane-based error
,input    [`CX_NL-1:0]                  rmlh_rpipe_rxdisperror                   // Pulse: Rx running disparity error if the corresponding lane detected a lane-based error
,input    [`CX_NL-1:0]                  rmlh_rpipe_rxskipadded                   // Pulse: Rx skip added in elastic buffer
,input    [`CX_NL-1:0]                  rmlh_rpipe_rxskipremoved                 // Pulse: Rx skip removed in elastic buffer
,input    [`CX_NL-1:0]                  rmlh_skp_parity_err                      // Pulse: Rx skip ordered set parity error
,input    [`CX_NL-1:0]                  rmlh_sync_header_err                     // Pulse: Rx sync header undefined error
,input                                  rmlh_framing_err                         // Pulse: Rx framing error in gen3 rate
,input    [6:0]                         rmlh_framing_err_ptr                     // Pulse: Rx framing error pointer in gen3 rate
,input                                  rmlh_framing_err_l0                      // Pulse :Rx framing error in gen3 rate when L0 state
,input                                  rmlh_deskew_alignment_err                // Level: Rx deskew alignment error
,input    [(`CX_NL*8)-1:0]              rmlh_deskew_fifo_ptr                     // Pulse: Rx deskew pointer address
,input    [`CX_NL-1:0]                  rmlh_rxvalid_deasserted                  // Pulse: Rx valid deasserted without EIOS
,input                              smlh_eidle_inferred_in_l0                // Level: Detect EI Infer for Ras D.E.S event counter
,input                              smlh_rx_rcvry_req                        // Level: Rx Recovery Request for Ras D.E.S event counter
,input                              smlh_timeout_nfts                        // Level: N_FTS Timeout for Ras D.E.S event counter
,input                              smlh_l0_to_recovery                      // Pulse: L0 to Recovery for Ras D.E.S event counter
,input                              smlh_l1_to_recovery                      // Pulse: L1 to Recovery for Ras D.E.S event counter
,input                              smlh_rcv_eios_when_l0s_unsprt            // pulse: Received EIOS when L0s is not supported and not directed L1 or L2 for Ras D.E.S event counter
,input                              smlh_deskew_uncomplete_err               // Pulse: Deskew uncompleted error for Ras D.E.S event counter
,input                              smlh_spd_change                          // Level: Speed Change for Ras D.E.S event counter
,input    [`CX_NL*8-1:0]            smseq_mcs_sts                            // Level: Modified compliance ERR symbol for Ras D.E.S trace FIFO
,input                              smlh_lwd_change                          // Level: Link Width Change for Ras D.E.S event counter
,input    [15:0]                    smlh_ltssm_variable                      // Level: Ltssm specific parameters for Ras D.E.S event counter
,input    [`CX_NL*16-1:0]           smlh_rxos_type
,input    [`CX_NL*64-1:0]           smseq_ts_debug_info                      // Level: TS parameter for Ras D.E.S trace FIFO
,input    [1:0]                     int_ltssm_powerdown
,input    [7:0]                     latched_ts_nfts                          // Level: Latched NFTS for Ras D.E.S Silicon Debug
,input                          init_eq_pending
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx
,input    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback
,input    [`CX_NL*3-1:0]                eqpa_violate_rule_123
,input    [`CX_NL*2-1:0]                eq_convergence_sts
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx
,input    [`CX_NL*`CX_RX_PSET_WD-1:0]   mac_cdm_ras_des_pset_lrx
,input    [`CX_NL-1:0]                  mac_cdm_ras_des_reject_rtx
,input                          init_eq_pending_g4
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs_g4
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf_g4
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx_g4
,input    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g4
,input    [`CX_NL*3-1:0]                eqpa_violate_rule_123_g4
,input    [`CX_NL*2-1:0]                eq_convergence_sts_g4
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx_g4
,input    [`CX_NL-1:0]                  mac_cdm_ras_des_reject_rtx_g4
,input                          init_eq_pending_g5
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs_g5
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf_g5
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx_g5
,input    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g5
,input    [`CX_NL*3-1:0]                eqpa_violate_rule_123_g5
,input    [`CX_NL*2-1:0]                eq_convergence_sts_g5
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx_g5
,input    [`CX_NL-1:0]                  mac_cdm_ras_des_reject_rtx_g5
,input                          init_eq_pending_g6
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_fs_g6
,input    [`CX_NL*`CX_TX_FS_WD-1:0]     mac_cdm_ras_des_lf_g6
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_ltx_g6
,input    [`CX_NL*`CX_FOMFEEDBACK_WD-1:0] phy_cdm_ras_des_fomfeedback_g6
,input    [`CX_NL*3-1:0]                eqpa_violate_rule_123_g6
,input    [`CX_NL-1:0]                  eqpa_violate_rule_4_g6
,input    [`CX_NL*2-1:0]                eq_convergence_sts_g6
,input    [`CX_NL*`CX_TX_COEF_WD-1:0]   mac_cdm_ras_des_coef_rtx_g6
,input    [`CX_NL-1:0]                  mac_cdm_ras_des_reject_rtx_g6
,input    [1:0]                         rl0s_state
,input    [`CX_RX_TLP-1:0]              rdlh_bad_tlp_err_pertlp                  // Pulse : Rx Bad TLP Event per TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rdlh_lcrc_tlp_err_pertlp                 // Pulse : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rdlh_nulified_tlp_err_pertlp             // Pulse : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rdlh_duplicate_tlp_err_pertlp            // Pulse : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
,input    [`CX_RX_NDLLP-1:0]            rdlh_bad_dllp_err_perdllp                // Pulse : Rx Bad DLLP Event per DLLP for Ras D.E.S event counter
,input    [`CX_RX_NDLLP-1:0]            rdlh_rcvd_nack_perdllp                   // Pulse : Rx Nak DLLP Event per DLLP for Ras D.E.S event counter
,input    [`CX_RX_NDLLP-1:0]            rdlh_rcvd_ack_perdllp                    // Pulse : Rx Ack DLLP Event per DLLP for Ras D.E.S event counter
,input                                  xdlh_nak_sent                            // Pulse : Tx Nak DLLP Event per TLP for Ras D.E.S event counter
,input                                  xdlh_ack_sent                            // Pulse : Tx Ack DLLP Event per TLP for Ras D.E.S event counter
,input    [`CX_TX_NDLLP-1:0]            xdlh_update_fc_sent                      // Pulse : Tx Update-FC DLLP Event per TLP for Ras D.E.S event counter
,input                                  rtlh_req_link_retrain                    // Pulse : FC Timeout Event per TLP for Ras D.E.S event counter
,input    [`CX_RX_NDLLP -1:0]           rtlh_rcvd_ufc_perdllp                    // Pulse : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_memwr_evt                        // Pulse : Rx Memory Write TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_defmemwr_evt                     // Pulse : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_memrd_evt                        // Pulse : Rx Memory Read TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_cfgwr_evt                        // Pulse : Rx Config Write TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_cfgrd_evt                        // Pulse : Rx Config Read TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_iowr_evt                         // Pulse : Rx I/O Write TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_iord_evt                         // Pulse : Rx I/O Read TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_cplwod_evt                       // Pulse : Rx Completion without Data TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_cplwd_evt                        // Pulse : Rx Completion with Data TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_msg_evt                          // Pulse : Rx Message TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_atmcop_evt                       // Pulse : Rx AtomicOp TLP for Ras D.E.S event counter
,input    [`CX_RX_TLP-1:0]              rtlh_rx_tlpwprefix_evt                   // Pulse : Rx TLP with Prefix for Ras D.E.S event counter
,input    [`CX_RX_TLP*11-1:0]           rtlh_rx_tlp_dpsize                       // Receiving TLP's data payload size[DW]
,input                              rdlh_vc0_initfc1_status                  // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
,input                              rdlh_vc0_initfc2_status                  // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug
,input    [11:0]                    rdlh_xplh_curnt_rx_ack_seqnum            // Level : Current Rx Ack Sequence number status for Ras D.E.S Silicon Debug
,input    [11:0]                    xdlh_xplh_curnt_seqnum                   // Level : Current Tx Sequence number status for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_rcvd_ph                          // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_rcvd_pd                          // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_rcvd_nph                         // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_rcvd_npd                         // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_rcvd_cplh                        // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_rcvd_cpld                        // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_allctd_ph                        // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_allctd_pd                        // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_allctd_nph                       // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_allctd_npd                       // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_HCRD_WD)-1:0]       rtlh_fc_allctd_cplh                      // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug
,input    [(`CX_NVC*`CX_DCRD_WD)-1:0]       rtlh_fc_allctd_cpld                      // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug
,input    [2:0]                     rdlh_einj0_lcrc_evt                      // Error injection 0 event flag
,input                              xmlh_einj0_oscrc_evt                     // Error injection 0 CRC error event
,input    [1:0]                     xdlh_einj0_lcrc_evt                      // Error injection 0 LCRC event
,input                              xdlh_einj0_fcrc_evt                      // Error injection 0 ECRC event
,input    [1:0]                     xdlh_einj0_dllpcrc_evt                   // Error injection 0 DLLP CRC event
,input    [1:0]                     ras_des_einj1_exp_sequm_evt   
,input                              ras_des_einj1_ack_nak_sequm_evt
,input                              xdlh_einj2_nak_evt                       // Error injection 2 NAK event
,input    [1:0]                     xmlh_einj3_osmsk_evt                     // Error injection 3 8b/10b K-code mask event
,input                              rtlh_einj4_fc_evt                        // Error injection 4 FC event
,input                              xdlh_einj5_nultlp_evt                    // Error injection 5 nullified TLP event
,input                              xdlh_einj5_dup_evt                       // Error injection 5 Duplicate TLP event
,input                                xdlh_ptm_sot
,input                                xdlh_ptm_multi_cycle
,input                                xdlh_ptm_request
,input                                xdlh_ptm_response
,input                                xdlh_rbuf_replaying
,input                                rdlh_ptm_sot
,input                                rdlh_ptm_multi_cycle
,input                                rdlh_ptm_request
,input                                rdlh_ptm_response
,input                                rdlh_duplicate_tlp
,input                                smlh_ltssm_in_l0p                        // Level: L0p
,input [2:0]                           tmp_int_mac_phy_rate
,input                                 tmp_mac_phy_txdeemph_0
,input [`CX_BAC_WD-1:0]                pre_mac_phy_blockaligncontrol_o
,output logic                                cfg_pipe_loopback
,output logic    [5:0]                       cfg_rxstatus_lane          // Lane to inject rxstatus value(bit6 = all lanes)
,output logic    [2:0]                       cfg_rxstatus_value         // rxstatus value to inject
,output logic    [`CX_NL-1:0]                cfg_lpbk_rxvalid           // rxvalid value to use during loopback
,output logic  [`CX_NL*16-1:0]               int_cfg_margin_control
,input  [`CX_NL-1:0]                         int_smlh_margin_status_valid
,input  [`CX_NL*16-1:0]                      int_smlh_margin_status
,input  [`CX_NL*5-1:0]                       int_rmlh_deskew_ctlskp_err
,output logic    [`CX_NL-1:0]              int_cdm_ras_des_force_rxdetected
,input    [`CX_NL-1:0]                    int_rmlh_lane_err
,input    [`CX_NL*`CX_TX_PSET_WD-1:0]         int_smlh_lec_pset_ltx
,input    [`CX_NL*`CX_RX_PSET_WD-1:0]         int_smlh_lec_pset_lrx
,input    [(`CX_NL*ORIG_DATA_WD)-1:0]     orig_pipe_rxdata
,input    [(`CX_NL*`CX_PHY_NB)-1:0]       orig_pipe_rxdatak
,input    [`CX_NL-1:0]                    orig_pipe_rxvalid
,input    [`CX_NL-1:0]                    orig_pipe_rxdatavalid
,input    [(`CX_NL*3)-1:0]                orig_pipe_rxstatus
,input    [(`CX_NL*`CX_PHY_RXSB_WD)-1:0]  orig_pipe_rxstartblock
,input    [(`CX_NL*`CX_PHY_RXSH_WD)-1:0]  orig_pipe_rxsyncheader
,input [`CX_NL-1:0]                       phy_mac_phystatus_int
,output                                    dpc_fatal_err_gate             // DPC trigger gating for fatal error message
,output                                    dpc_nonfatal_err_gate          // DPC trigger gating for non-fatal error message
,input                                     rmlh_prbs_done              // Finished PBRS Loopback
,input                                     rmlh_prbs_fail              // PRBS Comparison error occurred
,input  [`CX_NL-1:0]                       rmlh_prbs_started           // PRBS started status
,input  [`CX_NL-1:0][7:0]                  rmlh_prbs_err_cntr          // PRBS comparison error counter
,input  [`CX_NL-1:0]                       rmlh_prbs_unexp_fail        // PRBS unexpeced error occurred
,output logic                              cfg_prbs_en                 // PRBS Loopback Enable. Need to be set before being set cfg_lpbk_en
,output logic                              clear_prbs_done             // Clear PRBS Status regisers
,output logic   [3:0]                      cfg_prbs_lane_sel           // PRBS lane select for status registers
,input  link_adm_if_t                      pcie_link_adm_if            // SPIF: PCIe Link Layer to ADM Interface
,spif_if.cfgi_slave_mp                     b_cfgi_lbc_pcie
,spif_if.cfgi_slave_mp                     b_cfgi_lbc_cxl

);

// ------------------------------------------------------------------------------------------
// macros
// ------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------
// local parameters
// ------------------------------------------------------------------------------------------
localparam FX_TLP_ADR_DEC = `CX_FX_TLP - `CX_RADM_NFC_TRGT_INTF;  // In MS, more than 1 address decodging is required and that is only for P and NP (For CPL TLP addr dec is not required)
localparam FX_TLP_NF      = `CX_FX_TLP; // In MS, The multiples PFs arrays between CDM-RADM are deleted.
localparam FX_TLP_NF_PER_FILTER = 1; // "aperture" of the CDM-RADM errors. Each filter has 1 bit in case of multistream, and CX_NFUNC for legacy arch.

localparam TX_DATAK_WD = `CX_NL * `CX_PHY_NB;
localparam PASID_CNTRL_WD = `CX_PASID_CONTROL_WD;   // PASID Control width
localparam NF_PASID_CNTRL_WD = `CX_NFUNC*PASID_CNTRL_WD; // PASID Control width times Number of Physical Functions

localparam NXQDW       = (`CX_NW==16) ? 2*(`CX_NW / 4) : 0; // Number of 128-bit qdwords extracted in rtlh_tlp_extract
localparam QDW_W_PROT  = 128 + `CX_RAS_QDW_PROT_WD;         // Generic qdword width including parity bits
localparam SPIF_NCFG = `CX_SPIF_NCFG;

// ------------------------------------------------------------------------------------------
// genvar declarations
// ------------------------------------------------------------------------------------------
genvar func;  // used to instantiate per-function logic
genvar rx_tlp; // used to instantiate per-TLP logic

genvar j; //used for xali expansion
// ------------------------------------------------------------------------------------------
// Interface Signal Descriptions
// ------------------------------------------------------------------------------------------


//L0p Support
logic cfg_reciver_l0p_supported;
// Both the TS1 and the TS2 ordered sets (original and modified) use the logic
// expression of the flit_mode_suuported and flit_mode enabled for the Flit
// mode vlaue in the data-rate-identifier field of the OS.
assign cfg_flit_mode_enable = cfg_pcie_cap_flit_mode_sup & ~cfg_flit_mode_dis;
assign cfg_local_l0p_exit_latency = 3'b000; //Temporary assignment



    // ELBI interface

// completion timeout interface

wire                               cfg_acs_validation_cap;
wire                               cfg_acs_at_blocking_cap;
wire                               cfg_acs_up_forward_cap;



assign cfg_l1sub_t_common_mode = cfg_l1sub_control[`CX_L1SUB_CONTROL_T_COMM_MODE_RANGE]; // common mode time in us




wire      [(64*`CX_NFUNC)-1:0]             cfg_bar0_mask;
wire      [(32*`CX_NFUNC)-1:0]             cfg_bar1_mask;
wire      [(64*`CX_NFUNC)-1:0]             cfg_bar2_mask;
wire      [(32*`CX_NFUNC)-1:0]             cfg_bar3_mask;
wire      [(64*`CX_NFUNC)-1:0]             cfg_bar4_mask;
wire      [(32*`CX_NFUNC)-1:0]             cfg_bar5_mask;
wire      [(32*`CX_NFUNC)-1:0]             cfg_rom_mask;

wire [`CX_RADM_PQ_D_ADDRBITS-1:0] p_dataq_err_addr;
wire [`CX_RADM_SBUF_HDRQ_ERR_ADDR_WD-1:0] p_hdrq_err_addr;

// TO DO : radm_ms_cfg
assign p_dataq_err_addr = 'd0;
assign p_hdrq_err_addr  = 'd0;


logic                          radm_rasdp_cpl_lut_valid;

wire ras_prot_adm_disable;

assign ras_prot_adm_disable = ras_prot_t_disable [6] || ras_prot_t_disable [0] ;



// ------------------------------------------------------------------------------------------
// SPIF MUX on ADM Interface (TBD: consider a register stage on input to DWC_pcie_core)
// ------------------------------------------------------------------------------------------
wire           int_smlh_link_up;
wire   [2:0]   int_current_data_rate;
wire   [6:0]   int_esm_current_rate;
wire           int_flit_mode_enable;
wire           int_rstctl_flush_enable;

assign int_smlh_link_up        = pcie_link_adm_if.pl_protocol_cfg.spif_enable ? pcie_link_adm_if.pl_link_up       : smlh_link_up;
assign int_current_data_rate   = pcie_link_adm_if.pl_protocol_cfg.spif_enable ? pcie_link_adm_if.pl_speedmode     : pm_current_data_rate_others;
assign int_esm_current_rate    = {6'b000000, 1'b1}; // No ESM
assign int_flit_mode_enable    = pcie_link_adm_if.pl_protocol_cfg.spif_enable ? pcie_link_adm_if.pl_protocol_cfg.pcie_flit_mode : latched_flit_mode_enable;
assign int_rstctl_flush_enable = pcie_link_adm_if.pl_protocol_cfg.spif_enable ? (pcie_link_adm_if.pl_state_sts inside {LINKRESET, DISABLED}) : smlh_ltssm_in_hotrst_dis_entry;
// ------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------
// Reconstructing LTSSM CXL Enable bus on CDM inputs from SPIF Protocol Configuration Structure
// ------------------------------------------------------------------------------------------
ltssm_cxl_enable_t  int_ltssm_cxl_enable; // LTSSM CXL Enable Bus as seen on SPIF Interface
ltssm_cxl_enable_t  phy_ltssm_cxl_enable; // LTSSM CXL Enable Bus as negotiated by the LogPHY

assign phy_ltssm_cxl_enable = ltssm_cxl_enable;

always_comb begin
    int_ltssm_cxl_enable = ltssm_cxl_enable;

    int_ltssm_cxl_enable.io_enabled              = cxl_protocol_cfg.cxl_mode_enable    ;
    int_ltssm_cxl_enable.mem_enabled             = cxl_protocol_cfg.cxl_mem_enable     ;
    int_ltssm_cxl_enable.cache_enabled           = cxl_protocol_cfg.cxl_cache_enable   ;
    int_ltssm_cxl_enable.cxl_68B_flit_vh_enabled = cxl_protocol_cfg.cxl_vh_enable      ;
end
// ------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------
// Internal Signal declaration
// ------------------------------------------------------------------------------------------





// From CDM to LBC
wire          dbi_ro_wr_en;



// From CDM to LBC
wire [63:0]          rcrb_mbar0_base_addr;        // RCRB MEMBAR0 base address from CDM to LBC
wire [`CX_CXL_NLD_PLUS_1-1:0][63:0]               cxl_2_0_comp_reg_offset;     // Offset of CXL 2.0 Component Specific Register Space within Func 0, BAR 0

// From CDM to RADM_*
wire [(`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)-1:0]    cfg_rcrb_match;               //The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
wire [(`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)-1:0]    cfg_rcrb_mbar0_match;       //RCRB MEMBAR0 for configuring the CXL subsystem components
wire [(`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)-1:0]    cfg_rcrb_mbar0_match_int;       //RCRB MEMBAR0 for configuring the CXL subsystem components in CDM


// From LBC to CDM
wire          lbc_cdm_rcrb_wire;               // LBC indicates to CDM that it is an RCRB wire access
wire          lbc_cdm_rcrb_dbi;                // LBC indicates to CDM that it is an RCRB dbi access
wire          lbc_cdm_rcrb_mbar0_wire;         // LBC indicates to CDM that it is an RCRB MEMBAR wire access
wire          lbc_cdm_rcrb_mbar0_dbi;          // LBC indicates to CDM that it is an RCRB MEMBAR dbi access
wire [51:0]   rcrb_base_addr;              // The RCRB base address as captured by LBC
wire          rcrb_base_addr_valid;        // The RCRB base address valid as captured by LBC
wire [51:0]   rcrb_address_reg;

// From LBC to ELBI
wire  [`CX_NFUNC-1:0]                     temp_lbc_ext_cs;
wire                               lbc_mbar0_link_cap_access;

// From ELBI to LBC
wire  [`CX_NFUNC-1:0]                     mbar0_link_cap_ext_lbc_ack;
wire  [(`CX_LBC_NW*32*`CX_NFUNC)-1:0]     mbar0_link_cap_ext_lbc_din;


wire       cfg_cxl_alt_mse;                   // Alternate Memory Space Enable
wire       cfg_cxl_alt_bme;                   // Alternate Bus Master Enable
wire [7:0] cfg_cxl_alt_bus_base;              // Alternate Memory Base
wire [7:0] cfg_cxl_alt_bus_limit;             // Alternate Memory Limit

assign cfg_cxl_alt_mse       = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mse;
assign cfg_cxl_alt_bme       = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bme;
assign cfg_cxl_alt_bus_base  = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bus_base;
assign cfg_cxl_alt_bus_limit = b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bus_limit;

wire          viral_status                        = b_cxl_cdm.s_cfg_cxl_dev_viral_status_set;
wire          pl_reg_viral_status_set             = b_cxl_cdm.s_cfg_cxl_pl_reg_viral_status_set;

wire          cxl_rcrb_enable;      // If CX_CXL_RCRB_SUPPORT is enabled
reg           upstream_port_ff;     // If CX_CXL_RCRB_SUPPORT is enabled
wire          cxl_mbar0_enable;     // If CX_CXL_VH_SUPPORT is enabled
wire   cxl_vh_enable; // CXL Virtual Hierarchy Support
assign cxl_vh_enable = 1'b0 || cxl_protocol_cfg.cxl_vh_enable || cxl_protocol_cfg.cxl_pcie_flit_mode;

// For Upstream Port enable RCRB when neither in 256B Flit Mode nor CXL VH support is enabled in 68B Flit Mode
// For Downstream Port do not enable RCRB.
assign        cxl_rcrb_enable  = upstream_port_ff ? (cxl_protocol_cfg.cxl_mode_enable && !cxl_vh_enable) : 1'b0;
// For Upstream/Downstream Port enable MBAR0 when link is negotiated either in 256B Flit Mode or in 68B Flit Mode with CXL VH support is enabled
assign        cxl_mbar0_enable = cxl_protocol_cfg.cxl_mode_enable && cxl_vh_enable;

//A register is added to avoid feedthrough from input port 'device_type[3:0]' to some output ports driven by cxl_rcrb_enable in the CDM
always_ff @(posedge core_clk or negedge core_rst_n) begin : upstream_port_PROC
  if(!core_rst_n) begin
    upstream_port_ff  <= #`TP 1'b0;
  end else begin
    upstream_port_ff  <= #`TP upstream_port;
  end
end

// Outputs from CDM
wire [5:0]  cxl2p0_port_fields              ;
wire [1:0]  cxl_lopt_port_fields            ; // Latency-optimized Flit Enable/Capable bits
wire [1:0]  cxl_pbr_port_fields             ; // Port Based Routing Flit Enable/Capable bits
wire [23:0] cxl_port_rcvd_mod_ts_data_phase1;

// CDM Inputs
wire        cxl_retimers_present_mismatched;
wire        flexbusenablebits_phase2_mismatch;

assign cxl2p0_port_fields                = {b_cxl_cdm.s_pl_reg_apn_sw_mode, b_cxl_cdm.s_cfg_cxl_port_disable_cxl1p1_training, b_cxl_cdm.s_cfg_cxl_port_mld_enable, b_cxl_cdm.s_cfg_cxl_port_68B_flit_vh_enable, b_cxl_cdm.s_cfg_cxl_port_mld_capable, b_cxl_cdm.s_cfg_cxl_port_68B_flit_vh_capable};
assign cxl_port_rcvd_mod_ts_data_phase1  = ltssm_cxl_mod_ts_phase1_rcvd;
assign cxl_retimers_present_mismatched   = ltssm_cxl_retimers_pre_mismatched;
assign flexbusenablebits_phase2_mismatch = ltssm_cxl_flexbus_phase2_mismatched;
assign cfg_cxl_retimers_pre_mismatched   = b_cxl_cdm.s_cfg_cxl_port_retimers_pre_mismatched;


assign cxl_lopt_port_fields              = 2'b00;

assign cxl_pbr_port_fields               = 2'b00;

assign cfg_cxl_port_enable = { 2'b00, // NOP Hint Cap/En
                              cxl_lopt_port_fields,
                              cxl_pbr_port_fields,
                              cxl2p0_port_fields,
                              b_cxl_cdm.s_pl_reg_apn_bypass_enable, b_cxl_cdm.s_cfg_cxl_port_mem_enable, b_cxl_cdm.s_cfg_cxl_port_io_enable, b_cxl_cdm.s_cfg_cxl_port_cache_enable,
                              b_cxl_cdm.s_cfg_cxl_port_retimer2_present, b_cxl_cdm.s_cfg_cxl_port_retimer1_present,
                              b_cxl_cdm.s_cfg_cxl_port_drift_buffer_enable, b_cxl_cdm.s_cfg_cxl_port_sync_hdr_bypass_enable,
                              b_cxl_cdm.s_cfg_cxl_port_mem_capable, b_cxl_cdm.s_cfg_cxl_port_cache_capable};
assign cfg_cxl_port_vid    =  b_cxl_cdm.s_cfg_cxl_port_vid;


wire  [7:0]                      radm_trgt1_msgcode;

 wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]         client0_req_id;                 // bus and dev number are set based on per function
 wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]         client1_req_id;                 // bus and dev number are set based on per function
  wire  [(`CX_NVC_XALI_EXPANSION*16)-1:0]         client2_req_id;                 // bus and dev number are set based on per function

wire  [`CX_CPL_LUT_DEPTH-1:0]           radm_cpl_lut_valid;         // completion lookup table valid indication

logic    [(`CX_FX_TLP*8)-1:0]          radm_mlf_tlp_err_ptr;                     // malformed TLP 1st error pointer (enabled by radm_mlf_tlp_err)
wire    [`CX_NL-1:0]                  rmlh_ebuf_rxoverflow;                     // Pulse: Rx elastic buffer overflow error status if the corresponding lane detected a lane-based error
wire    [`CX_NL-1:0]                  rmlh_ebuf_rxunderflow;                    // Pulse: Rx elastic buffer underflow error status if the corresponding lane detected a lane-based error
wire    [`CX_NL-1:0]                  rmlh_phy_rxcodeerror;                     // Pulse: Rx symbol error status if the corresponding lane detected a lane-based error
wire    [`CX_NL-1:0]                  rmlh_phy_rxdisperror;                     // Pulse: Rx running disparity error if the corresponding lane detected a lane-based error
wire    [`CX_NL-1:0]                  rmlh_rxskipadded;                         // Pulse: Rx skip added in elastic buffer
wire    [`CX_NL-1:0]                  rmlh_rxskipremoved;                       // Pulse: Rx skip removed in elastic buffer
wire    [1:0]                     ltssm_powerdown;                          // Level: PIPE: Power Down for Ras D.E.S Silicon Debug
xadm_rasdes_tlp_trace_t           xadm_rasdes_tlp_trace;
wire    [`N_XADM_P_IF-1:0]        xtlh_tx_memwr_evt;                        // Pulse : Tx Memory Write TLP Event for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_defmemwr_evt;                     // Pulse : Tx Deferrable Memory Write TLP Event for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_memrd_evt;                        // Pulse : Tx Memory Read TLP Event TLP for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_cfgwr_evt;                        // Pulse : Tx Config Write TLP for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_cfgrd_evt;                        // Pulse : Tx Config Read TLP for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_iowr_evt;                         // Pulse : Tx I/O Write TLP for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_iord_evt;                         // Pulse : Tx I/O Read TLP for Ras D.E.S event counter
wire    [`N_XADM_CPL_IF-1:0]      xtlh_tx_cplwod_evt;                       // Pulse : Tx Completion with data TLP for Ras D.E.S event counter
wire    [`N_XADM_CPL_IF-1:0]      xtlh_tx_cplwd_evt;                        // Pulse : Tx Completion without data TLP for Ras D.E.S event counter
wire    [`N_XADM_P_IF-1:0]        xtlh_tx_msg_evt;                          // Pulse : Tx Message TLP for Ras D.E.S event counter
wire    [`N_XADM_NP_IF-1:0]       xtlh_tx_atmcop_evt;                       // Pulse : Tx AtomicOP TLP for Ras D.E.S event counter
wire    [`N_XADM_IF-1:0]          xtlh_tx_tlpwprefix_evt;                   // Pulse : Tx TLP with Prefix for Ras D.E.S event counter
wire    [`N_XADM_IF*11-1:0]       xtlh_tx_tlp_dpsize;                       // Transmitting TLP data payload size[DW]
wire    [`N_XADM_IF-1:0]          xadm_tx_nullify_evt;                    // Pulse : Tx Nullified or dropped TLP for Ras D.E.S event counter
wire    [`CX_NL*`CX_PHY_TXEI_WD-1:0]  mac_phy_txelec_txburst;                   // Level : PIPE: TxElecIdle/TxBurst for Ras D.E.S Silicon Debug
wire    [`CX_NL-1:0]                  phy_mac_rxelec_rxh8exit;                  // Level : PIPE: RxElecIdle/RxHibern8ExitType1 for Ras D.E.S Silicon Debug
wire    [`CX_NL-1:0]                  phy_mac_rxvalid_rxburst;                  // Level : PIPE: RxValid/RxBurst for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_HCRD_WD)-1:0]       xadm_fc_cnsmd_ph;                         // Level : Current FC Credit Consumed(Posted Header) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_DCRD_WD)-1:0]       xadm_fc_cnsmd_pd;                         // Level : Current FC Credit Consumed(Posted Data) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_HCRD_WD)-1:0]       xadm_fc_cnsmd_nph;                        // Level : Current FC Credit Consumed(Non-Posted Header) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_DCRD_WD)-1:0]       xadm_fc_cnsmd_npd;                        // Level : Current FC Credit Consumed(Non-Posted Data) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_HCRD_WD)-1:0]       xadm_fc_cnsmd_cplh;                       // Level : Current FC Credit Consumed(Completion Header) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_DCRD_WD)-1:0]       xadm_fc_cnsmd_cpld;                       // Level : Current FC Credit Consumed(Completion Data) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_HCRD_WD)-1:0]       xadm_fc_limit_ph;                         // Level : Current FC Credit limit(Posted Header) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_DCRD_WD)-1:0]       xadm_fc_limit_pd;                         // Level : Current FC Credit limit(Posted Data) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_HCRD_WD)-1:0]       xadm_fc_limit_nph;                        // Level : Current FC Credit limit(Non-Posted Header) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_DCRD_WD)-1:0]       xadm_fc_limit_npd;                        // Level : Current FC Credit limit(Non-Posted Data) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_HCRD_WD)-1:0]       xadm_fc_limit_cplh;                       // Level : Current FC Credit limit(Completion Header) for Ras D.E.S Silicon Debug
wire    [(`CX_NVC*`CX_DCRD_WD)-1:0]       xadm_fc_limit_cpld;                       // Level : Current FC Credit limit(Completion Data) for Ras D.E.S Silicon Debug
wire    [15:0]                    cdm_ras_des_force_rxdetected;             // Level : Force Detect Lane Num for Ras D.E.S Silicon Debug
assign int_cdm_ras_des_force_rxdetected = cdm_ras_des_force_rxdetected[`CX_NL-1:0];
logic [2:0]                       cdm_ras_des_einj0_ecrc_vc_sel;            // Error injection 0 ECRC Virtual Channel Selection
fc_type_e                         cdm_ras_des_einj0_ecrc_fc_sel;            // Error injection 0 ECRC Flow Control Selection
logic                             cdm_ras_des_einj0_ecrc_intf_sel;          // Error injection 0 ECRC Interface Selection
wire                              cdm_ras_des_einj6_enable;                 // Error Injection 6 Enable
wire    [31:0]                    cdm_ras_des_einj6_cmp_point_h0;           // Error Injection 6 header compare point byte0-3
wire    [31:0]                    cdm_ras_des_einj6_cmp_point_h1;           // Error Injection 6 header compare point byte4-7
wire    [31:0]                    cdm_ras_des_einj6_cmp_point_h2;           // Error Injection 6 header compare point byte8-11
wire    [31:0]                    cdm_ras_des_einj6_cmp_point_h3;           // Error Injection 6 header compare point byte12-15
wire    [31:0]                    cdm_ras_des_einj6_cmp_value_h0;           // Error Injection 6 header compare value byte0-3
wire    [31:0]                    cdm_ras_des_einj6_cmp_value_h1;           // Error Injection 6 header compare value byte4-7
wire    [31:0]                    cdm_ras_des_einj6_cmp_value_h2;           // Error Injection 6 header compare value byte8-11
wire    [31:0]                    cdm_ras_des_einj6_cmp_value_h3;           // Error Injection 6 header compare value byte12-15
wire    [31:0]                    cdm_ras_des_einj6_chg_point_h0;           // Error Injection 6 header change point byte0-3
wire    [31:0]                    cdm_ras_des_einj6_chg_point_h1;           // Error Injection 6 header change point byte4-7
wire    [31:0]                    cdm_ras_des_einj6_chg_point_h2;           // Error Injection 6 header change point byte8-11
wire    [31:0]                    cdm_ras_des_einj6_chg_point_h3;           // Error Injection 6 header change point byte12-15
wire    [31:0]                    cdm_ras_des_einj6_chg_value_h0;           // Error Injection 6 header change value byte0-3
wire    [31:0]                    cdm_ras_des_einj6_chg_value_h1;           // Error Injection 6 header change value byte4-7
wire    [31:0]                    cdm_ras_des_einj6_chg_value_h2;           // Error Injection 6 header change value byte8-11
wire    [31:0]                    cdm_ras_des_einj6_chg_value_h3;           // Error Injection 6 header change value byte12-15
wire    [7:0]                     cdm_ras_des_einj6_count;                  // Error Injection 6 count
wire                              cdm_ras_des_einj6_invt_cont;              // Error Injection 6 inversion control
wire    [2:0]                     cdm_ras_des_einj6_pkt_type;               // Error Injection 6 packet type
wire    [2:0]                     radm_einj0_ecrc_evt;                      // Error injection 0 Rx ECRC TLP event
wire                              xadm_einj0_ecrc_evt;                      // Error injection 0 Tx ECRC TLP event
wire [$clog2(`N_XALI_IF+2)-1:0]   xaim_einj6_tlp_evt;                       // Error Injection 6 TLP header event flag


wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_addr_align_en_ii           ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]        client1_tlp_byte_en_ii             ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]        client1_cpl_status_ii              ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_cpl_bcm_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]       client1_remote_req_id_ii           ;
wire   [(`CX_NVC_XALI_EXPANSION*12)-1:0]       client1_cpl_byte_cnt_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]        client1_tlp_tc_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0]  client1_tlp_attr_ii                ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client1_tlp_ats_ii                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_tlp_nw_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client1_tlp_fmt_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*5)-1:0]        client1_tlp_type_ii                ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_tlp_td_ii                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_tlp_ep_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*13)-1:0]       client1_tlp_byte_len_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0] client1_tlp_tid_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*64)-1:0]       client1_tlp_addr_ii                ;
// wire   [`CX_RAS_PCIE_EXTENDED_HDR_PROT_WD-1:0]           client1_hdr_prot_i                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_hdr_err_detect             ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_hdr_err_multpl             ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client1_tlp_th_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]        client1_tlp_st_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client1_tlp_ph_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]    client1_tlp_func_num_ii            ;

wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_addr_align_en_ii           ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]        client2_tlp_byte_en_ii             ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]        client2_cpl_status_ii              ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_cpl_bcm_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]       client2_remote_req_id_ii           ;
wire   [(`CX_NVC_XALI_EXPANSION*12)-1:0]       client2_cpl_byte_cnt_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]        client2_tlp_tc_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0]  client2_tlp_attr_ii                ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client2_tlp_ats_ii                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_tlp_nw_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client2_tlp_fmt_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*5)-1:0]        client2_tlp_type_ii                ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_tlp_td_ii                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_tlp_ep_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*13)-1:0]       client2_tlp_byte_len_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0] client2_tlp_tid_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*64)-1:0]       client2_tlp_addr_ii                ;
// wire   [`CX_RAS_PCIE_EXTENDED_HDR_PROT_WD-1:0]           client2_hdr_prot_i                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_hdr_err_detect             ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_hdr_err_multpl             ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client2_tlp_th_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]        client2_tlp_st_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client2_tlp_ph_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]    client2_tlp_func_num_ii            ;

wire   [`CX_NVC_XALI_EXPANSION-1:0]            client0_hdr_err_detect             ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]            client0_hdr_err_multpl             ;



logic ras_err_inj_done;
assign ras_err_inj_en_array = '0;
assign ras_err_inj_mask = '0;

 wire ras_err_inj_done_client0_hdr;
 wire ras_err_inj_done_client1_hdr;
 wire [`CX_NVC_XALI_EXPANSION-1:0] ras_err_inj_done_client2_hdr;
    wire ras_err_inj_done_xadm;

    wire ras_err_inj_done_msg_gen;
    wire ras_err_inj_done_lbc;



logic ras_err_inj_done_radm;

assign ras_err_inj_done =
                          (|ras_err_inj_done_client0_hdr) | (|ras_err_inj_done_client1_hdr) |
                          (|ras_err_inj_done_client2_hdr) |
                          ras_err_inj_done_xadm |
                          ras_err_inj_done_msg_gen |
                          ras_err_inj_done_lbc |
                          ras_err_inj_done_radm |
                          ras_err_inj_done_cx_pl ;



wire   [(`CX_NVC_XALI_EXPANSION*`TRGT_DATA_WD)-1:0]client0_tlp_data_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]   client0_tlp_func_num_i      ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_addr_align_en_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]       client0_tlp_byte_en_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]       client0_cpl_status_i               ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_cpl_bcm_i                  ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]      client0_remote_req_id_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*12)-1:0]      client0_cpl_byte_cnt_i             ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]       client0_tlp_tc_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0] client0_tlp_attr_i       ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_dv_i                   ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_eot_i                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_bad_eot_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]      client0_req_id_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]       client0_tlp_fmt_i                  ;
wire   [(`CX_NVC_XALI_EXPANSION*5)-1:0]       client0_tlp_type_i                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_td_i                   ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_ep_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*13)-1:0]      client0_tlp_byte_len_i             ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]client0_tlp_tid_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*64)-1:0]      client0_tlp_addr_i                 ;

wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_addr_align_en_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]       client1_tlp_byte_en_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]       client1_cpl_status_i               ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_cpl_bcm_i                  ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]      client1_remote_req_id_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*12)-1:0]      client1_cpl_byte_cnt_i             ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]       client1_tlp_tc_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0] client1_tlp_attr_i       ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_dv_i                   ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_eot_i                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_bad_eot_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]      client1_req_id_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]       client1_tlp_fmt_i                  ;
wire   [(`CX_NVC_XALI_EXPANSION*5)-1:0]       client1_tlp_type_i                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_td_i                   ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_ep_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*13)-1:0]      client1_tlp_byte_len_i             ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]client1_tlp_tid_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*64)-1:0]      client1_tlp_addr_i                 ;
wire   [(`CX_NVC_XALI_EXPANSION*`TRGT_DATA_WD)-1:0]client1_tlp_data_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]   client1_tlp_func_num_i      ;
// Client2 XADM interconnect signals
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_addr_align_en_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]       client2_tlp_byte_en_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]       client2_cpl_status_i               ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_cpl_bcm_i                  ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]      client2_remote_req_id_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*12)-1:0]      client2_cpl_byte_cnt_i             ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]       client2_tlp_tc_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0] client2_tlp_attr_i       ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_tlp_dv_i                   ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_tlp_eot_i                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_tlp_bad_eot_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]       client2_tlp_fmt_i                  ;
wire   [(`CX_NVC_XALI_EXPANSION*5)-1:0]       client2_tlp_type_i                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_tlp_td_i                   ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]           client2_tlp_ep_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*13)-1:0]      client2_tlp_byte_len_i             ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]client2_tlp_tid_i              ;
wire   [(`CX_NVC_XALI_EXPANSION*64)-1:0]      client2_tlp_addr_i                 ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]      client2_req_id_i                   ;
wire   [(`CX_NVC_XALI_EXPANSION*`TRGT_DATA_WD)-1:0]client2_tlp_data_i            ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]   client2_tlp_func_num_i      ;

// wire   [`CX_RAS_PCIE_EXTENDED_HDR_PROT_WD-1:0]           client0_hdr_prot_i  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_addr_align_en_ii           ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]      client0_tlp_byte_en_ii             ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]      client0_cpl_status_ii              ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_cpl_bcm_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*16)-1:0]     client0_remote_req_id_ii           ;
wire   [(`CX_NVC_XALI_EXPANSION*12)-1:0]     client0_cpl_byte_cnt_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*3)-1:0]      client0_tlp_tc_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0]client0_tlp_attr_ii      ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_ats_ii                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_nw_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_fmt_ii                 ;
wire   [(`CX_NVC_XALI_EXPANSION*5)-1:0]      client0_tlp_type_ii                ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_td_ii                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_ep_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*13)-1:0]     client0_tlp_byte_len_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]client0_tlp_tid_ii            ;
wire   [(`CX_NVC_XALI_EXPANSION*64)-1:0]     client0_tlp_addr_ii                ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_th_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*8)-1:0]      client0_tlp_st_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_ph_ii                  ;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]  client0_tlp_func_num_ii     ;

// START_IO:XALI0 Descriptions
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_nw_i                   ;

wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]    client0_tlp_ats_i                    ;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_th_i;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_ph_i;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]      client0_tlp_st_i;
wire   [(`CX_NVC_XALI_EXPANSION*`CX_PRFX_DW)-1:0]client0_tlp_prfx_i                 ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]         xadm_client0_halt_i                ;
wire [(`CX_NVC_XALI_EXPANSION*`CX_REMOTE_LOOKUPID_WD)-1:0]client0_cpl_lookup_id_i            ;

wire  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]         client0_tlp_dma_i;
wire  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client0_tlp_dma_channel_i;
wire  [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_atu_bypass_i           ;
// END_IO:XALI0 Descriptions

// START_IO:XALI1 Descriptions


wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client1_tlp_ats_i                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client1_tlp_nw_i                   ;
wire  [(`CX_NVC_XALI_EXPANSION*`CX_PRFX_DW)-1:0] client1_tlp_prfx_i                 ;

wire  [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_th_i                   ;
wire  [(`CX_NVC_XALI_EXPANSION*2)-1:0]       client1_tlp_ph_i                   ;
wire  [(`CX_NVC_XALI_EXPANSION*8)-1:0]       client1_tlp_st_i                   ;
wire  [`CX_NVC_XALI_EXPANSION-1:0]           xadm_client1_halt_i                ;
wire  [(`CX_NVC_XALI_EXPANSION*`CX_REMOTE_LOOKUPID_WD)-1:0]client1_cpl_lookup_id_i            ;


wire  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]         client1_tlp_dma_i;
wire  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client1_tlp_dma_channel_i;
wire  [`CX_NVC_XALI_EXPANSION-1:0]           client1_tlp_atu_bypass_i           ;
// END_IO:XALI1 Descriptions

// Client2 XADM interconnect signals
wire   [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client2_tlp_ats_i                  ;
wire   [`CX_NVC_XALI_EXPANSION-1:0]          client2_tlp_nw_i                   ;
wire [`CX_NVC_XALI_EXPANSION-1:0]            client2_tlp_th_i                   ;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]        client2_tlp_ph_i                   ;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]        client2_tlp_st_i                   ;
wire  [(`CX_NVC_XALI_EXPANSION*`CX_PRFX_DW)-1:0] client2_tlp_prfx_i                 ;
wire [(`CX_NVC_XALI_EXPANSION*`CX_REMOTE_LOOKUPID_WD)-1:0]client2_cpl_lookup_id_i            ;
wire  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]         client2_tlp_dma_i;
wire  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client2_tlp_dma_channel_i;
wire  [`CX_NVC_XALI_EXPANSION-1:0]           client2_tlp_atu_bypass_i           ;
wire  [`CX_NVC_XALI_EXPANSION-1:0]           xadm_client2_halt_i                ;
//--------------------------------
//     TRGT1 Interface
//--------------------------------
wire [`TRGT_HDR_WD-1:0]           radm_trgt1_hdr_i                      ;
wire                              trgt1_radm_halt_i                     ;
wire                              radm_trgt1_tlp_abort_i                ;
wire                              radm_trgt1_dllp_abort_i               ;
wire                              radm_trgt1_ecrc_err_i                 ;
wire  [`CX_PRFX_W_PAR-1:0]        radm_trgt1_tlp_prfx_i                 ;
wire                              radm_trgt1_th_i                       ;
wire [1:0]                        radm_trgt1_ph_i                       ;
wire [7:0]                        radm_trgt1_st_i                       ;
wire  [`CX_NW-1:0]                radm_trgt1_dwen_i                     ;
wire  [1:0]                       radm_trgt1_fmt_i                      ;
wire  [4:0]                       radm_trgt1_type_i                     ;
wire  [2:0]                       radm_trgt1_tc_i                       ;
wire  [`FLT_Q_ATTR_WIDTH-1:0]     radm_trgt1_attr_i                     ;
wire  [15:0]                      radm_trgt1_reqid_i                    ;
wire  [`CX_TAG_SIZE-1:0]          radm_trgt1_tag_i                      ;
wire  [`CX_NFUNC_WD-1:0]          radm_trgt1_func_num_i                 ;
wire [`CX_RASDP_TRGT1_HDR_PROT_WD-1:0] radm_trgt1_hdr_prot_i                ;
wire                              radm_trgt1_td_i                       ;
wire                              radm_trgt1_poisoned_i                 ;
wire  [9:0]                       radm_trgt1_dw_len_i                   ;
wire  [3:0]                       radm_trgt1_first_be_i                 ;
wire  [3:0]                       radm_trgt1_last_be_i                  ;
wire [`FLT_Q_ADDR_WIDTH -1:0]     radm_trgt1_hdr_uppr_bytes_i;
wire [63:0]                       radm_trgt1_hdr_uppr_bytes_tmp;
wire  [`FLT_Q_ADDR_WIDTH -1:0]    radm_trgt1_addr_out_i                 ;
wire                              radm_trgt1_io_req_in_range_i          ;
wire                              radm_trgt1_rom_in_range_i             ;
wire  [2:0]                       radm_trgt1_in_membar_range_i          ;
wire  [2:0]                       radm_trgt1_cpl_status_i               ;
wire [1:0]                        radm_trgt1_ats_i                      ;
wire                              radm_trgt1_nw_i                       ;
wire                              radm_trgt1_cxlsrc_i                   ;
wire                              radm_trgt1_bcm_i                      ;
wire                              radm_trgt1_cpl_last_i                 ;
wire [11:0]                       radm_trgt1_byte_cnt_i                 ;
wire [15:0]                       radm_trgt1_cmpltr_id_i                ;
wire  [`CX_CPL_LUT_DEPTH-1:0]     radm_cpl_lut_valid_i                  ;


wire                                radm_cpl_timeout_i                  ;
wire                                radm_cpl_timeout_cdm_i              ;
wire    [`CX_NFUNC_WD-1:0]          radm_timeout_func_num_i             ;
wire    [2:0]                       radm_timeout_cpl_tc_i               ;
wire    [1:0]                       radm_timeout_cpl_attr_i             ;
wire    [11:0]                      radm_timeout_cpl_len_i              ;
wire    [`CX_TAG_SIZE-1:0]          radm_timeout_cpl_tag_i              ;

//--------------------------------
//     RADM Bypass interface
//--------------------------------
wire    [`CX_NW-1:0]                    radm_bypass_dwen_i               ;
wire    [`CX_NHQ-1:0]                   radm_bypass_dv_i                 ;
wire    [`CX_NHQ-1:0]                   radm_bypass_hv_i                 ;
wire    [`CX_NHQ-1:0]                   radm_bypass_eot_i                ;
wire    [`CX_NHQ-1:0]                   radm_bypass_dllp_abort_i         ;
wire    [`CX_NHQ-1:0]                   radm_bypass_tlp_abort_i          ;
wire    [`CX_NHQ-1:0]                   radm_bypass_ecrc_err_i           ;
wire    [`CX_NHQ-1:0]                   radm_bypass_bcm_i                ;
wire    [`CX_NHQ-1:0]                   radm_bypass_cpl_last_i           ;
wire    [`CX_NHQ*3-1:0]                 radm_bypass_cpl_status_i         ;
wire    [`CX_NHQ*2-1:0]                 radm_bypass_ats_i                ;
wire    [`CX_NHQ*`CX_PRFX_W_PAR-1:0]    radm_bypass_tlp_prfx_i           ;

wire    [`CX_NHQ-1:0]                   radm_bypass_th_i                 ;
wire    [`CX_NHQ*2-1:0]                 radm_bypass_ph_i                 ;
wire    [`CX_NHQ*8-1:0]                 radm_bypass_st_i                 ;
wire    [`CX_NHQ*16-1:0]                radm_bypass_cmpltr_id_i          ;
wire    [`CX_NHQ*2-1:0]                 radm_bypass_fmt_i                ;
wire    [`CX_NHQ*5-1:0]                 radm_bypass_type_i               ;
wire    [`CX_NHQ*3-1:0]                 radm_bypass_tc_i                 ;
wire    [`CX_NHQ*`FLT_Q_ATTR_WIDTH-1:0] radm_bypass_attr_i               ;
wire    [`CX_NHQ*16-1:0]                radm_bypass_reqid_i              ;
wire    [`CX_NHQ*`CX_TAG_SIZE-1:0]      radm_bypass_tag_i                ;
wire    [`CX_NHQ*`CX_NFUNC_WD-1:0]      radm_bypass_func_num_i           ;
wire    [`CX_NHQ-1:0]                   radm_bypass_td_i                 ;
wire    [`CX_NHQ-1:0]                   radm_bypass_poisoned_i           ;
wire    [`CX_NHQ*10-1:0]                radm_bypass_dw_len_i             ;
wire    [`CX_NHQ*4-1:0]                 radm_bypass_first_be_i           ;
wire    [`CX_NHQ*4-1:0]                 radm_bypass_last_be_i            ;
wire    [`CX_NHQ-1:0]                   radm_bypass_rom_in_range_i       ;
wire    [`CX_NHQ-1:0]                   radm_bypass_io_req_in_range_i    ;
wire    [`CX_NHQ*3-1:0]                 radm_bypass_in_membar_range_i    ;

wire  [`CX_NFUNC-1:0]  cfg_auto_slot_pwr_lmt_dis; // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.

logic trgt1_radm_intf_np_0_halt_int;


// -------------------------------------------------------------------------------------
// XADM/RADM interconnect signals.


// Assignments valid for Core only, Core+AMBA, Core+AMBA+DMA configurations

assign trgt_lookup_id             =   trgt_lookup_id_i                ;

assign radm_cpl_timeout          =  radm_cpl_timeout_i                      ;

assign radm_timeout_cpl_tc       =  radm_timeout_cpl_tc_i                   ;
assign radm_timeout_cpl_attr     =  radm_timeout_cpl_attr_i                 ;
assign radm_timeout_cpl_len      =  radm_timeout_cpl_len_i                  ;
assign radm_timeout_cpl_tag      =  radm_timeout_cpl_tag_i                  ;
assign radm_timeout_func_num     =  radm_timeout_func_num_i                 ;






assign radm_cpl_lut_valid         =   radm_cpl_lut_valid_i            ;

wire [(FX_TLP_NF)-1:0] radm_rcvd_cdm_acs_err;
wire [(FX_TLP_NF)-1:0] radm_rcvd_acs_err;
assign radm_rcvd_cdm_acs_err     =   radm_rcvd_acs_err               ;


wire                              cfg_nond0_vdm_block;
wire                              cfg_client0_block_new_tlp;
wire                              cfg_client1_block_new_tlp;
wire                              cfg_client2_block_new_tlp;

wire        ras_prot_t_disable_7;        // CXS Receiver disable error correction bit
wire        ras_prot_t_disable_8;        // DTIM Tx Path
wire        ras_prot_t_disable_9;        // CXL Transmitter disable error correction bit

assign ras_prot_t_disable_7 = '0;
assign ras_prot_t_disable_8 = '0;
assign ras_prot_t_disable_9 = '0;
assign ras_prot_r_disable = '0;
assign ras_prot_t_disable = '0;

//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  localparam CLIENT_HDR_WD     = `CLIENT_HDR_WD;

assign ras_err_inj_done_client0_hdr = 1'b0;
assign ras_err_inj_done_client1_hdr = 1'b0;
assign ras_err_inj_done_client2_hdr = '0;


//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

wire    [3:0]                       device_type;

wire                                xadm_msg_halt;
wire                                cfg_elastic_buffer_mode_i;
// if Gen1/2 rate, always half full mode. if Gen3/4 rate, use regsiter bit cfg_elastic_buffer_mode_i
assign                              cfg_elastic_buffer_mode = cfg_elastic_buffer_mode_i;

wire    [3:0]                       cfg_pcie_max_link_speed_cdm;    // Max link speed
wire    [3:0]                       cfg_target_link_speed_cdm;      // Target link speed
// in case of gen6 config && linkup = 1 && flit_mode = 0 agreed with, if set target_link_speed = gen6, hardware will limit it to gen5 because flit_mode must be enabled for gen6 rate
assign cfg_pcie_max_link_speed = (cfg_pcie_cap_flit_mode_sup || smlh_flit_mode_enable) ? cfg_pcie_max_link_speed_cdm : cfg_pcie_max_link_speed_cdm >= `GEN6_LINK_SP ? `GEN5_LINK_SP : cfg_pcie_max_link_speed_cdm;
assign cfg_target_link_speed   = (cfg_flit_mode_enable       || smlh_flit_mode_enable) ? cfg_target_link_speed_cdm   : cfg_target_link_speed_cdm   >= `GEN6_LINK_SP ? `GEN5_LINK_SP : cfg_target_link_speed_cdm;
assign cfg_gen2_support = (cfg_pcie_max_link_speed != `GEN1_LINK_SP);  // Gen2 Supported if Max Link Speed is greater than Gen1

xadm_radm_tx_npr_t                  xadm_radm_tx_npr;
 `ifndef SYNTHESIS
wire  DWC_pcie_core_pkg::radm_tb_tlp_ordering_t              radm_tlp_order;
wire [`CX_RADM_NFC_TRGT_INTF-1:0]                            radm_flt_pkt_num_p_valid;
wire [(`CX_RADM_NFC_TRGT_INTF*`CX_RADM_PKT_ORD_WD)-1:0]      radm_flt_pkt_num_p;
wire [`CX_RADM_NFC_TRGT_INTF-1:0]                            radm_flt_pkt_num_np_valid;
wire [(`CX_RADM_NFC_TRGT_INTF*`CX_RADM_PKT_ORD_WD)-1:0]      radm_flt_pkt_num_np;
wire [`CX_RADM_NFC_TRGT_INTF-1:0]                            radm_flt_pkt_num_cpl_valid;
wire [(`CX_RADM_NFC_TRGT_INTF*`CX_RADM_PKT_ORD_WD)-1:0]      radm_flt_pkt_num_cpl;
 `endif // !SYNTHESIS
assign rtlh_rfc_upd  = rtlh_rcvd_fc.upd;
assign rtlh_rfc_data = rtlh_rcvd_fc.data;

logic [2:0] cfg_optional_ohc;


wire                                pm_asnak;


localparam RAS_RADM_COUNTERS = `CX_RAS_RADM_COUNTERS; // only valid for segbuf for now

logic [RAS_RADM_COUNTERS-1:0] ras_stat_radm_corr;
logic [RAS_RADM_COUNTERS-1:0] ras_stat_radm_uncorr;




localparam RAS_XADM_COUNTERS = `CX_RAS_XADM_COUNTERS;
localparam RAS_RDLH_COUNTERS = `CX_RAS_RDLH_COUNTERS;
localparam RAS_RTLH_COUNTERS = `CX_RAS_RTLH_COUNTERS;

wire                         ras_stat_xaim_corr;
wire                         ras_stat_xaim_uncorr;

wire [RAS_XADM_COUNTERS-1:0] ras_stat_xadm_corr;
wire [RAS_XADM_COUNTERS-1:0] ras_stat_xadm_uncorr;

wire [RAS_XADM_COUNTERS+3-1:0] ras_stat_xadm_corr_i;
wire [RAS_XADM_COUNTERS+3-1:0] ras_stat_xadm_uncorr_i;


// RAS DP:
// Central RAS DP ERROR Manager
localparam BLOCK_RAS_DP_PROT_CHK_N =
                                     1 + // VLSM
                                     1 + // AXI Bridge
                                     1 + // HDMA
                                     1 + // XAIM
                                     1 + // XADM
                                     1 + // XTLH
                                     1 + // XDLH
                                     1 + // XPLH
                                     0 + // RDLH
                                     0 + // RTLH
                                     1 + // CXL
                                     1;  // RADM

ras_dp_err_log_t ras_dp_err_log_from_xaim;
ras_dp_err_log_t ras_dp_err_log_from_xadm;
ras_dp_err_log_t ras_dp_err_log_from_radm;



ras_dp_err_log_t ras_dp_err_log_from_cxl;

ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0] ras_dp_err_log_array;
assign ras_dp_err_log_array = {
    vlsm_ras_dp_err_log,
    axi_bridge_ras_dp_err_log,
    hdma_ras_dp_err_log,
    ras_dp_err_log_from_xaim,
    ras_dp_err_log_from_xadm,
    ras_dp_err_log_from_xtlh,
    ras_dp_err_log_from_xdlh,
    ras_dp_err_log_from_xplh,
    ras_dp_err_log_from_cxl,
    ras_dp_err_log_from_radm
};

ras_dp_err_log_t ras_dp_err_log_to_cdm;
ras_dp_err_inj_t ras_dp_err_inj_from_cdm;

assign ras_dp_err_log_from_cxl    = b_cxl_cdm.s_ras_dp_err_log;
assign b_cxl_cdm.s_ras_dp_err_inj = ras_dp_err_inj;


logic unused_out_ras_dp_wake_up;
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (BLOCK_RAS_DP_PROT_CHK_N),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr (
    .clk                (core_clk                 ),
    .rst_n              (core_rst_n               ),
    .out_ras_dp_wake_up (unused_out_ras_dp_wake_up),
    .in_ras_dp_err_inj  (ras_dp_err_inj_from_cdm  ),
    .out_ras_dp_err_inj (ras_dp_err_inj           ),
    .in_ras_dp_err_log  (ras_dp_err_log_array     ),
    .out_ras_dp_err_log (ras_dp_err_log_to_cdm    )
);

assign out_ras_dp_err_inj = ras_dp_err_inj;



assign hdma_ras_dp_err_inj = ras_dp_err_inj;



logic ras_stat_radm_bypass_uncorr;


wire                                lbc_cpl_dv;
wire                                lbc_cpl_eot;
wire    [`TRGT_DATA_WD-1:0]         lbc_cpl_data;
wire    [LBC_MSG_HDR_WD-1:0]        lbc_cpl_hdr;
//DE:Deadlock Fix
wire                                lbc_deadlock_det;
wire                                msg_gen_dv;
wire                                msg_gen_eot;
wire    [`TRGT_DATA_WD-1:0]         msg_gen_data;
wire    [LBC_MSG_HDR_WD-1:0]        msg_gen_hdr;
wire    [`TRGT_DATA_WD-1:0]         radm_trgt0_data;
wire    [`CX_NW-1:0]                radm_trgt0_dwen;

wire    [`TRGT_HDR_WD-1:0]          radm_trgt0_hdr;
wire                                radm_trgt0_eot;
wire                                radm_trgt0_dv;
wire                                radm_trgt0_hv;
wire                                radm_trgt0_np_rsvd;
wire                                radm_trgt0_abort;
wire                                int_dpc_rp_busy;            // it indicates that the Root Port is busy with internal activity when set.

// Local bus controller interface
wire    [31:0]                      lbc_cdm_addr;
wire    [31:0]                      lbc_cdm_data;
wire    [3:0]                       lbc_cdm_wr;



// From  RADM queue
wire [`CX_NVC-1:0]                      radm_rtlh_ph_ca;                // Credit allocated (posted header)
wire [DCA_WD*`CX_NVC-1:0]               radm_rtlh_pd_ca;                // Credit allocated (posted data)
wire [`CX_NVC-1:0]                      radm_rtlh_nph_ca;               // Credit allocated (non-posted header)
wire [DCA_WD*`CX_NVC-1:0]               radm_rtlh_npd_ca;               // Credit allocated (non-posted data)
wire [`CX_NVC-1:0]                      radm_rtlh_cplh_ca;              // Credit allocated (completion header)
wire [DCA_WD*`CX_NVC-1:0]               radm_rtlh_cpld_ca;              // Credit allocated (completion data)


logic    [`CX_NFUNC-1:0]            radm_cpl_pending;


wire    [`CX_NVC*`CX_HCRD_WD-1:0]           xadm_ph_cdts;                   // header for P dedicated credits
wire    [`CX_NVC*`CX_DCRD_WD-1:0]           xadm_pd_cdts;                   // data for P dedicated credits
wire    [`CX_NVC*`CX_HCRD_WD-1:0]           xadm_nph_cdts;                  // header for NPR dedicated credits
wire    [`CX_NVC*`CX_DCRD_WD-1:0]           xadm_npd_cdts;                  // data for NPR dedicated credits
wire    [`CX_NVC*`CX_HCRD_WD-1:0]           xadm_cplh_cdts;                 // header for cPL dedicated credits
wire    [`CX_NVC*`CX_DCRD_WD-1:0]           xadm_cpld_cdts;                 // data for cPL dedicated credits
wire    [        `CX_HCRD_WD-1:0]           xadm_ph_shrd_cdts;              // header for P shared credits
wire    [        `CX_DCRD_WD-1:0]           xadm_pd_shrd_cdts;              // data for P shared credits
wire    [        `CX_HCRD_WD-1:0]           xadm_nph_shrd_cdts;             // header for NPR shared credits
wire    [        `CX_DCRD_WD-1:0]           xadm_npd_shrd_cdts;             // data for NPR shared credits
wire    [        `CX_HCRD_WD-1:0]           xadm_cplh_shrd_cdts;            // header for cPL shared credits
wire    [        `CX_DCRD_WD-1:0]           xadm_cpld_shrd_cdts;            // data for cPL shared credits

logic [(MSG_TLP_WD-1):0]                 radm_drs_msg;
logic [(MSG_TLP_WD-1):0]                 radm_frs_msg;
logic [(MSG_TLP_WD*4)-1:0]               radm_frs_msg_reason;
wire [`CX_NFUNC-1:0]                     pmstate_d3hot_to_d0;

// declaration for multi-func purpose
//  input signals of cdm
// -----------------------------------------------------------------------------
logic    [(FX_TLP_NF)-1:0]           radm_rcvd_wreq_poisoned;
xadm_xmt_pci_errors_t xadm_xmt_pci_errors;
logic    [(FX_TLP_NF)-1:0]           radm_mlf_tlp_err;
logic    [(FX_TLP_NF)-1:0]           radm_rcvd_cpl_poisoned;
logic    [(FX_TLP_NF)-1:0]           radm_ecrc_err;
logic    [(`CX_FX_TLP*`CX_NFUNC)-1:0]radm_hdr_log_valid;


logic    [(`CX_FX_TLP*128)-1:0]          radm_hdr_log;
logic    [(`CX_FX_TLP*128)-1:0]          radm_tlp_prfx_log;


wire    [`CX_NFUNC-1:0]              rtlh_overfl_err_nf;
logic    [(FX_TLP_NF)-1:0]           radm_rcvd_cpl_ur;

logic    [(FX_TLP_NF)-1:0]           radm_rcvd_cpl_ca;
logic    [(`CX_FX_TLP*`CX_NFUNC)-1:0]radm_rcvd_req_ur;
logic    [(FX_TLP_NF)-1:0]           radm_rcvd_req_ca;
logic    [(FX_TLP_NF)-1:0]           radm_unexp_cpl_err;
logic    [`CX_FX_TLP-1:0]            cdm_err_advisory;

wire                                cfg_clk_pm_en_tmp;
assign cfg_clk_pm_en = cfg_clk_pm_en_tmp;


// declaration for multi-func purpose
//  output signals of cdm
// ----------------------------------------------------------------------------

wire    [(32*`CX_NFUNC)-1:0]               cdm_lbc_data;
wire    [`CX_NFUNC-1:0]                    cdm_lbc_ack;
wire    [`CX_NFUNC-1:0]                    lbc_cdm_cs;

wire                                cfg_ts2_lid_deskew;
wire                                diag_fast_link_mode;
wire                                int_cfg_fast_link_mode;
assign                              cfg_fast_link_mode = int_cfg_fast_link_mode;
wire    [`CX_NFUNC-1:0]             cfg_ecrc_chk_en;

wire    [`CX_NFUNC-1:0]             cfg_ecrc_gen_en;
wire    [(16*`CX_NFUNC)-1:0]        cfg_io_limit_upper16;
wire    [(16*`CX_NFUNC)-1:0]        cfg_io_base_upper16;
wire    [(8*`CX_NFUNC)-1:0]         cfg_io_limit;
wire    [(8*`CX_NFUNC)-1:0]         cfg_io_base;
wire    [`CX_NFUNC-1:0]             cfg_io_space_en;
wire                                bridge_device;
wire    [(4*`CX_NFUNC)-1:0]         cfg_cpl_timeout_range;
wire    [`CX_NFUNC-1:0]             cfg_cpl_timeout_disable;
wire    [`CX_NFUNC-1:0]             cfg_adv_cor_err_int;
wire    [`CX_NFUNC-1:0]             cfg_adv_nf_err_int;
wire    [`CX_NFUNC-1:0]             cfg_adv_f_err_int;
wire    [2:0]                       int_cfg_remote_rd_req_bridge_size;
assign int_cfg_remote_rd_req_bridge_size = `DC_MAX_PYLD_SIZE_4096_BYTES_ENC;

wire    [`CX_REMOTE_LUT_PTR_WIDTH-1:0] int_cfg_remote_max_bridge_tag;
assign int_cfg_remote_max_bridge_tag = `CX_REMOTE_MAX_TAG;

wire                                    cdm_dpc_triggered;           // DPC has been triggered indication
wire                                    cdm_aer_dpc_triggered;       // DPC has been triggered by AER uncorrectable error indication
wire                                    cdm_core_in_dpc;             // When asserted, core is in Downstream Port Containment mode and LTSSM is in DISABLE state.
assign core_in_dpc = cdm_core_in_dpc;


wire                                       int_cfg_auto_flush_en;
wire                                       cfg_auto_flush_en = int_cfg_auto_flush_en;
wire     [7:0]                             cfg_auto_flush_timeout;
wire                                       cfg_link_timeout_en_n;
wire      [`LINK_TIMEOUT_PERIOD_WIDTH-1:0] cfg_link_timeout_period;


// ATU outbound Region controls
wire      [3*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_tc;
wire      [`FLT_Q_ATTR_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_attr;
wire      [2*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_at;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_dma_bypass;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_inhibit_payload;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_hdr_substitute_en;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_tag_substitute_en;
wire      [`CX_TAG_SIZE*`CX_ATU_OUT_NREGIONS_MIN1-1:0]       atu_reg_out_tag;
wire      [8*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_msg_code;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_th;
wire      [2*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_ph;
wire      [8*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                  atu_reg_out_st;
// Mode Settings
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_shift;
wire      [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]atu_reg_out_lwr_trgt;
wire      [`CX_ATU_BASE_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_upr_trgt;
wire      [ATU_REG_LWR_WD*`CX_ATU_OUT_NREGIONS_MIN1-1:0]     atu_reg_out_lwr_trgt_lwr;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                    atu_reg_out_hdr_flds_bypass;  // TLP Header fields bypass control bit

// ATU inbound Region controls
wire      [5*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_type;
wire      [3*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_tc;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_td;
wire      [`FLT_Q_ATTR_WIDTH*`CX_ATU_IN_NREGIONS_MIN1 -1:0]  atu_reg_in_attr;
wire      [2*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_at;
wire      [`CX_NFUNC_WD*`CX_ATU_IN_NREGIONS_MIN1 -1:0]       atu_reg_in_func_num;
wire      [8*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_msg_code;
wire      [3*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_bar_num;
wire      [`CX_ATU_IN_NREGIONS_MIN1-1:0]                     atu_reg_in_th;
wire      [2*`CX_ATU_IN_NREGIONS_MIN1-1:0]                   atu_reg_in_ph;
wire      [8*`CX_ATU_IN_NREGIONS_MIN1-1:0]                   atu_reg_in_st;
// Inbound field match enables
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_tc_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_td_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_attr_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_at_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_func_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_msgcode_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_th_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_ph_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_st_match_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_single_addr_loc_en;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_msg_type_match_mode;
// Response and mode settings
wire      [2*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_rsp_code;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_fuzzy;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_shift;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_invert;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_bar_match;
// Region Enable
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_en;
// Base, Limit and Target Registers
wire      [`CX_ATU_REGION_WIDTH*`CX_ATU_IN_NREGIONS_MIN1 -1:0]atu_reg_in_base;
wire      [`CX_ATU_BASE_WIDTH*`CX_ATU_IN_NREGIONS_MIN1 -1:0] atu_reg_in_upr_base;
wire      [`CX_ATU_REGION_WIDTH*`CX_ATU_IN_NREGIONS_MIN1 -1:0]atu_reg_in_limit;
wire      [4*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_cbuf_incr;
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_cbuf_restart;
wire      [4*`CX_ATU_IN_NREGIONS_MIN1 -1:0]                  atu_reg_in_cbuf_incr_zeros = {4*`CX_ATU_IN_NREGIONS_MIN1{1'b0}};
wire      [`CX_ATU_IN_NREGIONS_MIN1 -1:0]                    atu_reg_in_cbuf_restart_zeros = {`CX_ATU_IN_NREGIONS_MIN1{1'b0}};
wire      [`CX_ATU_MAX_REGION_SIZE*`CX_ATU_IN_NREGIONS_MIN1-1:0] atu_reg_in_uppr_limit;
wire      [`CX_ATU_REGION_WIDTH*`CX_ATU_IN_NREGIONS_MIN1 -1:0]atu_reg_in_lwr_trgt;
wire      [`CX_ATU_BASE_WIDTH*`CX_ATU_IN_NREGIONS_MIN1 -1:0] atu_reg_in_upr_trgt;
wire      [`CX_ATU_IN_NREGIONS_MIN1-1:0]                     atu_reg_in_incr_rgn_size;    // Maximum region size control bit

wire    [`CX_NFUNC-1:0]                        cfg_slot_pwr_limit_wr;
wire    [63:0]                      msix_addr;
wire    [31:0]                      msix_data;
wire    [`CX_NFUNC-1:0]             cfg_msix_en;
wire    [`CX_NFUNC-1:0]                    cfg_msix_func_mask;

logic    [31:0]                      radm_msg_ltr_latency;
wire                                xadm_msg_ltr;
wire    [31:0]                      xadm_msg_ltr_latency;
wire                                msg_ltr_det;
wire    [31:0]                      msg_ltr_latency;
wire                                cdm2msgg_ltr_clr_msg_req;
wire                                msgg2cdm_ltr_clr_msg_grant;
wire    [7:0]                       cfg_slot_pwr_limit_val;
wire    [1:0]                       cfg_slot_pwr_limit_scale;
wire    [(3*`CX_NFUNC)-1:0]         cfg_func_spec_err;


// -----------------------------------------------------------------------------

logic    [(`CX_FX_TLP*`CX_NFUNC_WD)-1:0]       flt_cdm_pf;
logic    [((FX_TLP_ADR_DEC)*64)-1:0]           flt_cdm_addr;
logic    [FX_TLP_ADR_DEC-1:0]                  flt_cdm_addr_valid;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]      cfg_io_match;

logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]      cfg_config_above_match;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]      cfg_rom_match;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC*6)-1:0]    cfg_bar_match;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]      cfg_prefmem_match;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]      cfg_mem_match;
logic    [`CX_NFUNC-1:0][(`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)-1:0]        cfg_cxl_2_0_mbar0_match;
logic                   [(`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)-1:0]        cxl_2_0_mbar0_access_int;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]           cfg_cxl_alt_prefmem_match;
logic    [((`CX_FX_TLP-`CX_RADM_NFC_TRGT_INTF)*`CX_NFUNC)-1:0]           cfg_cxl_alt_mem_match;

wire    [(`CX_NFUNC*6)-1:0]             cfg_bar_is_io;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g6_pset_lrx;
wire    [`CX_NL*`CX_RX_PSET_WD-1:0]     cfg_lec_g6_pset_rrx;
wire  [55:0]                        mod_ts_data_sent = (smlh_ltssm_state == S_CFG_COMPLETE) ? mod_ts_data_sent_i : 56'h0;

wire    [`CX_N_FLT_MASK-1:0]        cfg_filter_rule_mask;

wire                                xadm_cpl_halt;
wire    [3*`CX_NVC-1:0]             trgt0_radm_halt;
wire                                lbc_cdm_dbi;
wire                                lbc_cdm_dbi2;

wire                                lbc_cdm_unroll;

wire    [`CX_NFUNC-1:0]             lbc_xmt_cpl_ca;
wire    [23:0]                      cfg_tc_vc_map;                  // TC to VC Structure mapping
wire                                ptm_request_msg;
wire                                cfg_ptm_enable;
wire                                ptm_res_msg;
wire                                ptm_res_d_msg;
wire    [63:0]                      ptm_master_time;
wire    [31:0]                      ptm_prop_delay;
logic                               radm_ptm_req;
logic                               radm_ptm_res_msg;
logic                               radm_ptm_res_d_msg;
logic    [63:0]                     radm_ptm_master_time;
logic    [31:0]                     radm_ptm_prop_delay;

wire    [`CX_NW-1:0]                rdlh_rtlh_tlp_sot;              // When asserted, it indicates the Start of a TLP pkt


// Retry buffer external RAM interface
// Depth of retry buffer
assign  retryram_xdlh_depth         = `CX_RBUF_DEPTH -1;                // this signal is defined to be the value of the top pointer of a RAM designed in our core

// Depth of retry buffer
assign  retrysotram_xdlh_depth      = `SOTBUF_DEPTH -1;                 // this signal is defined to be the value of the top pointer of a RAM designed in our core

logic                               radm_parerr;
wire                                rtlh_parerr;
wire                                xadm_parerr_detected;
wire    [(`CX_NFUNC*6)-1:0]         target_mem_map;                 // Each bit of this vector indicates which target receives memory transactions for that bar #
wire    [ `CX_NFUNC-1:0]            target_rom_map;                 // Each bit of this vector indicates which target receives rom    transactions for that bar #
wire                                inta_wire;
wire                                intb_wire;
wire                                intc_wire;
wire                                intd_wire;
wire    [`CX_NFUNC-1:0]              msggen_cdm_send_f_err;
wire    [`CX_NFUNC-1:0]              msggen_cdm_send_nf_err;
wire    [2:0]                       cfg_dbi_func_bank_select;



logic                                radm_snoop_upd;
logic    [7:0]                       radm_snoop_bus_num;
logic    [4:0]                       radm_snoop_dev_num;
wire                                 rtlh_fc_prot_err;
assign rtlh_fc_prot_err = 1'b0;
delay_n
 #(1, 2) u_ras_des_einj0_ack_pipe (.dout(cdm_ras_des_einj0_ack), .din({xadm_einj0_ecrc_evt, cxpl_cdm_ras_des_einj0_ack[0]}), .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0));

assign msg_ltr_det     = upstream_port ? xadm_msg_ltr         : radm_msg_ltr;
assign msg_ltr_latency = upstream_port ? xadm_msg_ltr_latency : radm_msg_ltr_latency;
wire int_cfg_obff_en;
assign int_cfg_obff_en = |cfg_obff_en;


wire    [NF_PASID_CNTRL_WD-1:0] cfg_pf_pasid_control;          // PF PASID control signals bus
wire    [11:0]                  xdlh_rbuf_pkt_cnt;            // XDLH packet counter it is routed to top-level to resolve multisim issues with hdl backdoor usage in VTB

wire                                    default_target;
wire                                    cfg_cfg_tlp_bypass_en;
wire [9:0]                              cfg_config_limit;
wire [1:0]                              cfg_target_above_config_limit;
wire                                    ur_ca_mask_4_trgt1;


//  MUX for CPCIE outputs
// ----------------------------------------------------------------------------


//  MUX for MPCIE outputs
// ----------------------------------------------------------------------------




 assign mac_phy_txelec_txburst  = int_phy_txelecidle            ;
 assign phy_mac_rxelec_rxh8exit = rpipe_rxelecidle              ;
 assign phy_mac_rxvalid_rxburst = orig_pipe_rxvalid             ;
 assign rmlh_ebuf_rxoverflow    = rmlh_rpipe_rxoverflow         ;
 assign rmlh_ebuf_rxunderflow   = rmlh_rpipe_rxunderflow        ;
 assign rmlh_phy_rxcodeerror    = rmlh_rpipe_rxcodeerror        ;
 assign rmlh_phy_rxdisperror    = rmlh_rpipe_rxdisperror        ;
 assign rmlh_rxskipadded        = rmlh_rpipe_rxskipadded        ;
 assign rmlh_rxskipremoved      = rmlh_rpipe_rxskipremoved      ;


 assign pm_asnak = (upstream_port)? radm_pm_asnak : pm_xmt_asnak;

// =============================================================================
// APP FLR pipeline signaling

// =============================================================================
localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(device_type_i)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_device_type (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (core_rst_n),
`endif // SYNTHESIS
  .data_s  (device_type_i),
  .data_d  (device_type)
);

reg    [3:0]    int_device_type;                    // internal device type. (can be change when crosslink is enabled)
logic [3:0] dm_sw_device_type;

 // Insert register in path to avoid feedback path between RADM input
 // (device_type) and output (radm_byp_addr)

 reg  [3:0]      device_type_reg_to_bcm36; // registered device_type
 wire [3:0]      device_type_reg;
 always @(posedge core_clk or negedge core_rst_n)
     if(!core_rst_n)
         device_type_reg_to_bcm36            <= #(`TP) `CX_DEVICE_TYPE;
     else
         device_type_reg_to_bcm36            <= #(`TP) device_type;    // device_type_reg_to_bcm36 gets valid type one cycle after reset, but this is ok for RADM block.

DWC_pcie_ctl_bcm36_nhs
 #(
  .WIDTH      ($bits(device_type_reg_to_bcm36)),
  .DATA_DELAY (DATA_DELAY_BCM36_NHS)
) u_bcm36_nhs_device_type_reg (
`ifndef SYNTHESIS
  .clk_d   (core_clk),
  .rst_d_n (core_rst_n),
`endif // SYNTHESIS
  .data_s  (device_type_reg_to_bcm36),
  .data_d  (device_type_reg)
);


assign device_type_o     = device_type;
assign dm_sw_device_type = device_type_reg;

assign  msix_addr = 64'd0;
assign  msix_data = 32'd0;

assign  cfg_reset_assert            = (cfg_2nd_reset & !upstream_port) | cfg_plreg_reset;  // two resets from CDM. One is for RC mode only, it is the secondary bridge reset, the other one is for debug PL register.


assign  int_cfg_pbus_num            = Bget(cfg_pbus_num, cfg_upd_req_id);
assign  int_cfg_pbus_dev_num        = Qget(cfg_pbus_dev_num, cfg_upd_req_id);

assign rtlh_overfl_err_nf = {`CX_NFUNC{rtlh_overfl_err}};

 assign int_rtlh_ph_ca              = credit_mapping(radm_rtlh_ph_ca);
 assign int_rtlh_pd_ca              = radm_rtlh_pd_ca;
 assign int_rtlh_nph_ca             = credit_mapping(radm_rtlh_nph_ca);
 assign int_rtlh_npd_ca             = radm_rtlh_npd_ca;
 assign int_rtlh_cplh_ca            = credit_mapping(radm_rtlh_cplh_ca);
 assign int_rtlh_cpld_ca            = radm_rtlh_cpld_ca;

wire    [(`CX_NVC*9)-1:0]               cfg_radm_q_mode;                // (PL) Queue Mode: CPL(BP/CT/SF), NP(BP/CT/SF), P(BP/CT/SF)
wire    [`CX_NVC-1:0]                   cfg_radm_order_rule;            // (PL) Order Selection: 0 - Strict Priority, 1 - Complies with Ordering Rule
wire                                cfg_radm_strict_vc_prior;       // (PL) VC Priority: 0 - Round Robin, 1 - Strict Priority
wire    [(`CX_NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0] cfg_hq_depths;          // (PL) Indicates the depth of the header queues per type per vc
wire    [(`CX_NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]cfg_dq_depths;          // (PL) Indicates the depth of the data queues per type per vc



wire    [31:0]                      cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry
wire    [2:0]                       cfg_clock_gating_ctrl; // {axi_clk_gating_en, radm_clk_gating_en}


// for multifunction device, bus and dev number are based on per func.
// Here the request ID is the request ID of a transaction request and a completer's ID if it is a completion




assign  radm_pm_to_ack              = int_radm_pm_to_ack | pm_turnoff_timeout; // Turnoff timeout is treated as if TO ACK message is received.

//
// XADM Module
//

localparam WRR_ARB_WD = `CX_XADM_ARB_WRR_WEIGHT_BIT_WIDTH;

wire    [(8*WRR_ARB_WD)-1:0]        cfg_lpvc_wrr_weight;
wire    [63:0]                      int_cfg_lpvc_wrr_weight;
wire    [1:0]                       cfg_lpvc_wrr_phase;
wire    [2:0]                       cfg_lpvc;
wire    [2:0]                       cfg_vc_arb_sel;


wire                                xadm_fc_prot_err;

assign cfg_lpvc_wrr_weight  = {int_cfg_lpvc_wrr_weight[(8*7+WRR_ARB_WD)-1:8*7],
                               int_cfg_lpvc_wrr_weight[(8*6+WRR_ARB_WD)-1:8*6],
                               int_cfg_lpvc_wrr_weight[(8*5+WRR_ARB_WD)-1:8*5],
                               int_cfg_lpvc_wrr_weight[(8*4+WRR_ARB_WD)-1:8*4],
                               int_cfg_lpvc_wrr_weight[(8*3+WRR_ARB_WD)-1:8*3],
                               int_cfg_lpvc_wrr_weight[(8*2+WRR_ARB_WD)-1:8*2],
                               int_cfg_lpvc_wrr_weight[(8*1+WRR_ARB_WD)-1:8*1],
                               int_cfg_lpvc_wrr_weight[(8*0+WRR_ARB_WD)-1:8*0]};
assign cfg_lpvc_wrr_phase   = cfg_vc_arb_sel[1:0];



// Since AXI_BRIDGE does the parity location different from the core's parity location, we will need to swap the parity location







logic    [MSG_TLP_WD-1:0]                int_radm_pm_pme;

assign radm_pm_pme          = |int_radm_pm_pme;
logic    [MSG_TLP_WD-1:0]                int_radm_correctable_err;           // RC Mode Only:
logic    [MSG_TLP_WD-1:0]                int_radm_nonfatal_err;              // RC Mode Only:
logic    [MSG_TLP_WD-1:0]                int_radm_fatal_err;                 // RC Mode Only:
assign radm_correctable_err = |int_radm_correctable_err;
assign radm_nonfatal_err    = |int_radm_nonfatal_err;
assign radm_fatal_err       = |int_radm_fatal_err;

wire    [MSG_TLP_WD*`CX_NFUNC-1:0] cdm_radm_correctable_err;           // RC Mode Only:
wire    [MSG_TLP_WD*`CX_NFUNC-1:0] cdm_radm_nonfatal_err;              // RC Mode Only:
wire    [MSG_TLP_WD*`CX_NFUNC-1:0] cdm_radm_fatal_err;                 // RC Mode Only:
wire    [MSG_TLP_WD*`CX_NFUNC-1:0] cdm_radm_pm_pme;                    // RC Mode Only:

assign cdm_radm_correctable_err = {`CX_NFUNC{int_radm_correctable_err}};
assign cdm_radm_nonfatal_err    = {`CX_NFUNC{int_radm_nonfatal_err}};
assign cdm_radm_fatal_err       = {`CX_NFUNC{int_radm_fatal_err}};
assign cdm_radm_pm_pme          = {`CX_NFUNC{int_radm_pm_pme}};

assign int_radm_trgt1_mem_type = 1'b0;


cxl_mbar0_link_cap_reg

#(
     .INST (0)
    ,.NF ( `CX_NFUNC )
    ,.LBC_EXT_AW ( `CX_LBC_EXT_AW    )
    ,.LBC_EXT_DW ( 32*`CX_LBC_NW )
) u_cxl_mbar0_link_cap_reg (

 //---------------Inputs-----------------------

                         .core_clk                                 ( aux_clk_g                                           )
                        ,.non_sticky_rst_n                         ( non_sticky_rst_n                                    )
                        ,.sticky_rst_n                             ( sticky_rst_n                                        )
                        ,.rdlh_link_up                             ( rdlh_link_up                                        )
                        ,.dbi_ro_wr_en                             ( dbi_ro_wr_en                                        )
                        ,.upstream_port                            ( upstream_port                                       )
                        ,.lbc_mbar0_link_cap_access                ( lbc_mbar0_link_cap_access                           )
                        ,.lbc_ext_dbi_access                       ( lbc_ext_dbi_access                                  )
                        ,.temp_lbc_ext_cs                          ( temp_lbc_ext_cs                                     )
                        ,.lbc_ext_addr                             ( lbc_ext_addr                                        )
                        ,.lbc_ext_dout                             ( lbc_ext_dout                                        )
                        ,.lbc_ext_wr                               ( lbc_ext_wr                                          )
                        ,.ext_lbc_override_en                      ( ext_lbc_override_en                                 )
                        ,.temp_ext_lbc_ack                         ( ext_lbc_ack                                         )
                        ,.temp_ext_lbc_din                         ( ext_lbc_din                                         )
                        ,.mbar0_link_ver_received                  ( b_cxl_cdm.s_mbar0_link_ver_received                 )
                        ,.mbar0_link_llr_wrap_val_received         ( b_cxl_cdm.s_mbar0_link_llr_wrap_val_received        )
                        ,.mbar0_link_num_retry_received            ( b_cxl_cdm.s_mbar0_link_num_retry_received           )
                        ,.mbar0_link_num_phy_reinit_received       ( b_cxl_cdm.s_mbar0_link_num_phy_reinit_received      )
                        ,.mbar0_link_wr_ptr_received               ( b_cxl_cdm.s_mbar0_link_wr_ptr_received              )
                        ,.mbar0_link_echo_eseq_received            ( b_cxl_cdm.s_mbar0_link_echo_eseq_received           )
                        ,.mbar0_link_num_free_buf_received         ( b_cxl_cdm.s_mbar0_link_num_free_buf_received        )
                        ,.mbar0_link_ll_reset_clr                  ( b_cxl_cdm.s_mbar0_link_ll_reset_clr                 )
                        ,.mbar0_link_init_state                    ( b_cxl_cdm.s_mbar0_link_init_state                   )
                        ,.mbar0_link_ll_retry_buffer_consumed      ( b_cxl_cdm.s_mbar0_link_ll_retry_buffer_consumed     )
                        ,.mbar0_link_rx_cache_req_credits_stat     ( b_cxl_cdm.s_mbar0_link_rx_cache_req_credits_stat    )
                        ,.mbar0_link_rx_cache_rsp_credits_stat     ( b_cxl_cdm.s_mbar0_link_rx_cache_rsp_credits_stat    )
                        ,.mbar0_link_rx_cache_data_credits_stat    ( b_cxl_cdm.s_mbar0_link_rx_cache_data_credits_stat   )
                        ,.mbar0_link_rx_mem_req_rsp_credits_stat   ( b_cxl_cdm.s_mbar0_link_rx_mem_req_rsp_credits_stat  )
                        ,.mbar0_link_rx_mem_data_credits_stat      ( b_cxl_cdm.s_mbar0_link_rx_mem_data_credits_stat     )
                        ,.mbar0_link_rx_mem_bi_credits_stat      ( b_cxl_cdm.s_mbar0_link_rx_mem_bi_credits_stat     )
                        ,.mbar0_link_tx_cache_req_credits_stat     ( b_cxl_cdm.s_mbar0_link_tx_cache_req_credits_stat    )
                        ,.mbar0_link_tx_cache_rsp_credits_stat     ( b_cxl_cdm.s_mbar0_link_tx_cache_rsp_credits_stat    )
                        ,.mbar0_link_tx_cache_data_credits_stat    ( b_cxl_cdm.s_mbar0_link_tx_cache_data_credits_stat   )
                        ,.mbar0_link_tx_mem_req_rsp_credits_stat   ( b_cxl_cdm.s_mbar0_link_tx_mem_req_rsp_credits_stat  )
                        ,.mbar0_link_tx_mem_data_credits_stat      ( b_cxl_cdm.s_mbar0_link_tx_mem_data_credits_stat     )
                        ,.mbar0_link_tx_mem_bi_credits_stat        (b_cxl_cdm.s_mbar0_link_tx_mem_bi_credits_stat)   

//---------------Outputs-----------------------
                        ,.mbar0_link_cap_lbc_ext_cs                ( lbc_ext_cs                                    )
                        ,.mbar0_link_cap_ext_lbc_ack               ( mbar0_link_cap_ext_lbc_ack                    )
                        ,.mbar0_link_cap_ext_lbc_din               ( mbar0_link_cap_ext_lbc_din                    )

                        ,.mbar0_link_ver_supported                 ( b_cxl_cdm.s_mbar0_link_ver_supported          )
                        ,.mbar0_link_llr_wrap_val_supported        ( b_cxl_cdm.s_mbar0_link_llr_wrap_val_supported )
                        ,.mbar0_link_ll_reset                      ( b_cxl_cdm.s_mbar0_link_ll_reset               )
                        ,.mbar0_link_ll_init_stall                 ( b_cxl_cdm.s_mbar0_link_ll_init_stall          )
                        ,.mbar0_link_ll_crd_stall                  ( b_cxl_cdm.s_mbar0_link_ll_crd_stall           )
                        ,.mbar0_link_rx_cache_req_credits          ( b_cxl_cdm.s_mbar0_link_rx_cache_req_credits   )
                        ,.mbar0_link_rx_cache_rsp_credits          ( b_cxl_cdm.s_mbar0_link_rx_cache_rsp_credits   )
                        ,.mbar0_link_rx_cache_data_credits         ( b_cxl_cdm.s_mbar0_link_rx_cache_data_credits  )
                        ,.mbar0_link_rx_mem_req_rsp_credits        ( b_cxl_cdm.s_mbar0_link_rx_mem_req_rsp_credits )
                        ,.mbar0_link_rx_mem_data_credits           ( b_cxl_cdm.s_mbar0_link_rx_mem_data_credits    )
                        ,.mbar0_link_rx_mem_bi_credits             (b_cxl_cdm.s_mbar0_link_rx_mem_bi_credits       )
                        ,.mbar0_link_ack_force_threshold           ( b_cxl_cdm.s_mbar0_link_ack_force_threshold    )
                        ,.mbar0_link_ack_flush_retimer             ( b_cxl_cdm.s_mbar0_link_ack_flush_retimer      )
                        ,.mbar0_link_mdh_disable                   ( b_cxl_cdm.s_mbar0_link_mdh_disable            )

                        ); // cxl_mbar0_link_cap_reg


logic [8:0] cfg_segment_id_int;
logic [8:0] radm_np_segment_id;
assign cfg_segment_id = cfg_segment_id_int;

xadm_pkt_t [`N_XALI_IF-1:0] xaim_xadm_xali_pkt;
xadm_pkt_t xaim_xadm_msg_pkt;
xadm_pkt_t xaim_xadm_lbc_pkt;
logic xaim_msg_halt;
logic xaim_cpl_halt;
logic [`N_XALI_IF-1:0]    xadm_xaim_xali_halt;
trgt1_np_out_s [`CX_RADM_NFC_TRGT_INTF-1:0]              radm_trgt1_out_np_int;

// RADM_PKT_GRANT_ISSUE
logic             radm_trgt1_np_0_hv_int;
logic             radm_trgt1_np_0_dv_int;
logic             radm_trgt1_np_0_eot_int;
logic [3*`CX_NVC-1:0] radm_grant_tlp_type;
logic [3*`CX_NVC-1:0] trgt_lut_trgt1_radm_pkt_halt;

always_comb
begin
  radm_trgt1_out_np = radm_trgt1_out_np_int;
  radm_trgt1_out_np[0].flt_q_hv            = radm_trgt1_out_np_int[0].flt_q_hv & trgt_lookup_empty;
  radm_trgt1_out_np[0].flt_q_dv            = radm_trgt1_out_np_int[0].flt_q_dv & trgt_lookup_empty;
  radm_trgt1_out_np[0].flt_q_eot           = radm_trgt1_out_np_int[0].flt_q_eot & trgt_lookup_empty;
  radm_grant_tlp_type                      = {3{radm_trgt1_out_np_int[0].flt_q_hv}} & {3{~trgt1_radm_intf_np_0_halt_int}}; //({3{~trgt1_radm_intf_np_0_halt_int}} | {3{~|trgt_lut_trgt1_radm_pkt_halt}}); // TODO: Should be connected to IDE pkt_grant input.
end

// RADM_PKT_GRANT_ISSUE

//generate
//  for(genvar i = 0; i < `N_XALI_IF; i++) begin: gen_xali_interfaces
//assign client_tlp_pkt_xaim_in[i].xali_client_tlp = xali_xaim_pkt[i];
//  end //gen_xali_interfaces
//endgenerate
xaim_ms
 u_xaim_ms (
    // ------ Inputs ------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    // CMD FLUSH Interface
    //`ifndef CX_IS_SW
    //.rstctl_core_flush_req          (rstctl_core_flush_req    ),
    //`else // CX_IS_SW
    //.rstctl_core_flush_req          (int_rstctl_core_flush_req),
    //`endif // CX_IS_SW
    .rstctl_core_flush_req          (rstctl_core_flush_req    ),
    .cfg_max_payload_size           (cfg_highest_max_payload),
    .cfg_ecrc_gen_en                (cfg_ecrc_gen_en),
    .cfg_trgt_cpl_lut_delete_entry  (cfg_trgt_cpl_lut_delete_entry),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size),
    .ras_prot_t_disable             (ras_prot_t_disable),
    .cdm_ras_des_einj6_enable       (cdm_ras_des_einj6_enable),
    .cdm_ras_des_einj6_cmp_point_h0 (cdm_ras_des_einj6_cmp_point_h0),
    .cdm_ras_des_einj6_cmp_point_h1 (cdm_ras_des_einj6_cmp_point_h1),
    .cdm_ras_des_einj6_cmp_point_h2 (cdm_ras_des_einj6_cmp_point_h2),
    .cdm_ras_des_einj6_cmp_point_h3 (cdm_ras_des_einj6_cmp_point_h3),
    .cdm_ras_des_einj6_cmp_value_h0 (cdm_ras_des_einj6_cmp_value_h0),
    .cdm_ras_des_einj6_cmp_value_h1 (cdm_ras_des_einj6_cmp_value_h1),
    .cdm_ras_des_einj6_cmp_value_h2 (cdm_ras_des_einj6_cmp_value_h2),
    .cdm_ras_des_einj6_cmp_value_h3 (cdm_ras_des_einj6_cmp_value_h3),
    .cdm_ras_des_einj6_chg_point_h0 (cdm_ras_des_einj6_chg_point_h0),
    .cdm_ras_des_einj6_chg_point_h1 (cdm_ras_des_einj6_chg_point_h1),
    .cdm_ras_des_einj6_chg_point_h2 (cdm_ras_des_einj6_chg_point_h2),
    .cdm_ras_des_einj6_chg_point_h3 (cdm_ras_des_einj6_chg_point_h3),
    .cdm_ras_des_einj6_chg_value_h0 (cdm_ras_des_einj6_chg_value_h0),
    .cdm_ras_des_einj6_chg_value_h1 (cdm_ras_des_einj6_chg_value_h1),
    .cdm_ras_des_einj6_chg_value_h2 (cdm_ras_des_einj6_chg_value_h2),
    .cdm_ras_des_einj6_chg_value_h3 (cdm_ras_des_einj6_chg_value_h3),
    .cdm_ras_des_einj6_count        (cdm_ras_des_einj6_count),
    .cdm_ras_des_einj6_invt_cont    (cdm_ras_des_einj6_invt_cont),
    .cdm_ras_des_einj6_pkt_type     (cdm_ras_des_einj6_pkt_type),
    .xaim_einj6_tlp_evt             (xaim_einj6_tlp_evt),

    .ras_dp_err_log           (ras_dp_err_log_from_xaim ),
    .ras_dp_err_inj           (ras_dp_err_inj  ),



    .device_type                    (device_type_o),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_2ndbus_num                 (cfg_2ndbus_num),
    .radm_trgt1_cpl_lookup_id_rlsd   (radm_trgt1_cpl_lookup_id_rlsd),
    //.radm_trgt1_lookup_id_consmd,
    .cfg_client_p_block_new_tlp      (cfg_client0_block_new_tlp),
    .cfg_client_np_block_new_tlp     (cfg_client1_block_new_tlp),
    .cfg_client_cpl_block_new_tlp    (cfg_client2_block_new_tlp),
    .pm_xtlh_block_tlp               (pm_xtlh_block_tlp),
    .pm_block_all_tlp                (pm_block_all_tlp),
    .atu_reg_out_type               (atu_reg_out_type),
    .atu_reg_out_tc                 (atu_reg_out_tc),
    .atu_reg_out_attr               (atu_reg_out_attr),
    .atu_reg_out_at                 (atu_reg_out_at),
    .atu_reg_out_func_num           (atu_reg_out_func_num),
    .atu_reg_out_func_bypass        (atu_reg_out_func_bypass),
    .atu_reg_out_dma_bypass         (atu_reg_out_dma_bypass),
    .atu_reg_out_inhibit_payload    (atu_reg_out_inhibit_payload),
    .atu_reg_out_hdr_substitute_en  (atu_reg_out_hdr_substitute_en),
    .atu_reg_out_tag_substitute_en  (atu_reg_out_tag_substitute_en),
    .atu_reg_out_tag                (atu_reg_out_tag),
    .atu_reg_out_msg_code           (atu_reg_out_msg_code),
    .atu_reg_out_th                 (atu_reg_out_th),
    .atu_reg_out_ph                 (atu_reg_out_ph),
    .atu_reg_out_st                 (atu_reg_out_st),
// Mode Settings
    .atu_reg_out_shift              (atu_reg_out_shift),
    .atu_reg_out_invert             (atu_reg_out_invert),
// Region Enable
    .atu_reg_out_en                 (atu_reg_out_en),
// Base, Limit and Target Registers
    .atu_reg_out_base               (atu_reg_out_base),
    .atu_reg_out_upr_base           (atu_reg_out_upr_base),
    .atu_reg_out_limit              (atu_reg_out_limit),
    .atu_reg_out_uppr_limit         (atu_reg_out_uppr_limit),
    .atu_reg_out_lwr_trgt           (atu_reg_out_lwr_trgt),
    .atu_reg_out_upr_trgt           (atu_reg_out_upr_trgt),
    .atu_reg_out_lwr_trgt_lwr       (atu_reg_out_lwr_trgt_lwr),
    .atu_reg_out_incr_rgn_size      (atu_reg_out_incr_rgn_size),
    .atu_reg_out_hdr_flds_bypass    (atu_reg_out_hdr_flds_bypass),
    .radm_trgt1_hv                  (radm_trgt1_out_np_int[0].flt_q_hv),        // RADM_PKT_GRANT_ISSUE
    .radm_trgt1_eot                 (radm_trgt1_out_np_int[0].flt_q_eot),       // RADM_PKT_GRANT_ISSUE
    .radm_trgt1_tlp_abort           (radm_trgt1_out_np_int[0].flt_q_tlp_abort),
    .radm_trgt1_dllp_abort          (radm_trgt1_out_np_int[0].flt_q_dllp_abort),
    .radm_trgt1_fmt                 (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_fmt),
    .radm_trgt1_type                (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_type),
    .radm_trgt1_dw_len              (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_dw_len),
    .radm_trgt1_addr                (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_addr[6:0]),
    .radm_trgt1_cpl_last            (radm_trgt1_out_cpl[0].flt_q_hdr.flt_q_cpl_last),
    .radm_trgt1_cpl_status          (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_cpl_status),
    .radm_trgt1_byte_cnt            ( '0 ),
    .radm_trgt1_tc                  (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_tc),
    .radm_trgt1_tag                 (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_TAG),
    .trgt1_radm_halt                (trgt1_radm_intf_np_0_halt),
    .radm_cpl_timeout               (radm_cpl_timeout_i),
    .radm_timeout_cpl_byte_len      (radm_timeout_cpl_len_i),
    .radm_timeout_cpl_tc            (radm_timeout_cpl_tc_i),
    .radm_timeout_cpl_tag           (radm_timeout_cpl_tag_i),
    .cfg_remote_max_bridge_tag      (int_cfg_remote_max_bridge_tag),
    .radm_trgt1_lookup_id_consmd    (radm_trgt1_lookup_id_consmd),
    .current_data_rate              (int_current_data_rate),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .radm_trgt1_np_0_reqtr_sgmt     (radm_trgt1_out_np_int[0].flt_q_hdr.hdr_dec_flt_reqtr_seg),
    .radm_trgt1_ecrc_err            (radm_trgt1_out_np_int[0].flt_q_ecrc_err),
    .radm_trgt1_attr                (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_attr),
    .radm_trgt1_reqid               (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_REQID),
    .radm_trgt1_first_be            (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_first_be),
    .radm_trgt1_last_be             (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_last_be),
    .radm_trgt1_func_num            (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_func_nmbr),
    .radm_grant_tlp_type            (radm_grant_tlp_type),           // RADM_PKT_GRANT_ISSUE
    .trgt_lut_trgt1_radm_pkt_halt   (trgt_lut_trgt1_radm_pkt_halt),  // RADM_PKT_GRANT_ISSUE
    .radm_trgt1_dma_grant           ('0),
    .radm_trgt1_dma_cpl_rlsd        ('0),
    .trgt_lut_dma_pkt_halt          ( ),
    .radm_trgt1_at                  (radm_trgt1_out_np_int[0].flt_q_hdr.flt_q_ats),
    .cfg_rcb_128                    (cfg_rcb[0]),
    .trgt_lookup_id                 (trgt_lookup_id_i),
    .trgt_lookup_empty              (trgt_lookup_empty),
    .trgt_cpl_lut_empty             (trgt_cpl_lut_empty),
    .trgt_timeout_cpl_func_num      (trgt_timeout_cpl_func_num),
    .trgt_cpl_timeout               (trgt_cpl_timeout),
    .trgt_timeout_cpl_tc            (trgt_timeout_cpl_tc),
    .trgt_timeout_cpl_attr          (trgt_timeout_cpl_attr),
    .trgt_timeout_cpl_len           (trgt_timeout_cpl_len),
    .trgt_timeout_lookup_id         (trgt_timeout_lookup_id),
    .xadm_xaim_xali_halt            (xadm_xaim_xali_halt), //GEN6_TODO
    .xadm_xaim_msg_halt             (xadm_xaim_msg_halt), //GEN6_TODO
    .xadm_xaim_cpl_halt             (xadm_xaim_lbc_halt), //GEN6_TODO
    //.client_tlp_pkt                 (client_tlp_pkt_xaim_in.xali_pkt_t_mp),
    .xali_xaim_pkt                  (xali_xaim_pkt),
    .xaim_xali_halt                 (xaim_xali_halt),
    .xaim_msg_halt                  (xaim_msg_halt),
    .xaim_cpl_halt                  (xaim_cpl_halt),
    .xaim_xadm_xali_pkt             (xaim_xadm_xali_pkt),
    .xaim_xadm_msg_pkt              (xaim_xadm_msg_pkt),
    .xaim_xadm_lbc_pkt              (xaim_xadm_lbc_pkt),
    .xaim_pm_pkt_pending            (xaim_tlp_pending),
     .flit_mode                     (int_flit_mode_enable),
     .cfg_segment_id                (cfg_segment_id_int),
     .cfg_optional_ohc              (cfg_optional_ohc),
    .lbc_cpl_hv                     (lbc_cpl_hv),
    .lbc_cpl_dv                     (lbc_cpl_dv),
    .lbc_cpl_data                   (lbc_cpl_data),
    .lbc_cpl_hdr                    (lbc_cpl_hdr),
    .lbc_cpl_eot                    (lbc_cpl_eot),


    .msg_gen_hv                     (msg_gen_hv),
    .msg_gen_dv                     (msg_gen_dv),
    .msg_gen_eot                    (msg_gen_eot),
    .msg_gen_data                   (msg_gen_data),
    .msg_gen_hdr                    (msg_gen_hdr)
);


wire cfg_can_transmit_atomic = 1'b0 || |(cfg_atomic_req_en | ~cfg_atomic_egress_block );
wire cfg_can_transmit_dmwr   = 1'b0 || |(cfg_dmwr_req_en );
logic xadm_radm_wakeup;

assign xadm_diag_status = '0;
xadm_ms
 u_xadm_ms (
    .core_clk                   (core_clk                 ),
    .core_rst_n                 (core_rst_n               ),

    // From/to CDM
    .cfg_vc_id                  (cfg_vc_struc_vc_id_map   ),
    .cfg_vc_enable              (cfg_vc_enable            ),
    .cfg_fc_scaled_en           (fc_scaled_en             ),
    .cfg_max_payload_size       (cfg_highest_max_payload  ),
    .cfg_can_transmit_atomic    (cfg_can_transmit_atomic  ),
    .cfg_can_transmit_dmwr      (cfg_can_transmit_dmwr    ),
    .xadm_xmt_pci_errors        (xadm_xmt_pci_errors      ),

    .xadm_msg_ltr               (xadm_msg_ltr),
    .xadm_msg_ltr_latency       (xadm_msg_ltr_latency),

    .xadm_fc_prot_err           (xadm_fc_prot_err         ),

    // From/to RADM

    .xadm_radm_tx_npr           (xadm_radm_tx_npr         ),
    .xadm_radm_wakeup           (xadm_radm_wakeup         ),

    // From/to RDLH
    .rdlh_link_down             (rdlh_link_down           ),

    // From/to RTLH
    .rtlh_fc_init_status        (rtlh_fc_init_status      ),
    .rtlh_rfc                   (rtlh_rcvd_fc             ),

    // From/to XTLH
    .xtlh_flit_mode_enable      (int_flit_mode_enable  ),

    // From/to PM
    .xadm_pm_no_fc_credit       (xadm_no_fc_credit        ),
    .xadm_pm_had_enough_credit  (xadm_had_enough_credit   ),
    .xadm_pm_pkt_pending        (xadm_tlp_pending         ),

    // CMD FLUSH Interface
    .rstctl_core_flush_req      (rstctl_core_flush_req    ),
    // xali posted tlp sent interface
    .xtlh_xadm_posted_tlp_sent  (xtlh_xadm_posted_tlp_sent),
    .xali_posted_tlp_sent       (xali_posted_tlp_sent),


    .diag_ctrl                  (cdm_ras_des_einj0_req[1]),
    .einj0_enable               (cdm_ras_des_einj0_enable),
    .einj0_count                (cdm_ras_des_einj0_count),
    .einj0_crc_type             (cdm_ras_des_einj0_crc_type),
    .einj0_ecrc_vc_sel          (cdm_ras_des_einj0_ecrc_vc_sel),
    .einj0_ecrc_fc_sel          (cdm_ras_des_einj0_ecrc_fc_sel),
    .einj0_ecrc_intf_sel        (cdm_ras_des_einj0_ecrc_intf_sel),
    .einj0_ecrc_evt             (xadm_einj0_ecrc_evt),

    // RASDES Interface
    .xadm_fc_cnsmd_ph           (xadm_fc_cnsmd_ph         ),
    .xadm_fc_cnsmd_pd           (xadm_fc_cnsmd_pd         ),
    .xadm_fc_limit_ph           (xadm_fc_limit_ph         ),
    .xadm_fc_limit_pd           (xadm_fc_limit_pd         ),
    .xadm_fc_cnsmd_nph          (xadm_fc_cnsmd_nph        ),
    .xadm_fc_cnsmd_npd          (xadm_fc_cnsmd_npd        ),
    .xadm_fc_limit_nph          (xadm_fc_limit_nph        ),
    .xadm_fc_limit_npd          (xadm_fc_limit_npd        ),
    .xadm_fc_cnsmd_cplh         (xadm_fc_cnsmd_cplh       ),
    .xadm_fc_cnsmd_cpld         (xadm_fc_cnsmd_cpld       ),
    .xadm_fc_limit_cplh         (xadm_fc_limit_cplh       ),
    .xadm_fc_limit_cpld         (xadm_fc_limit_cpld       ),
    .xadm_rasdes_tlp_trace      (xadm_rasdes_tlp_trace    ),

    .xadm_ph_cdts               (xadm_ph_cdts             ),
    .xadm_pd_cdts               (xadm_pd_cdts             ),
    .xadm_nph_cdts              (xadm_nph_cdts            ),
    .xadm_npd_cdts              (xadm_npd_cdts            ),
    .xadm_cplh_cdts             (xadm_cplh_cdts           ),
    .xadm_cpld_cdts             (xadm_cpld_cdts           ),
    .xadm_ph_shrd_cdts          (xadm_ph_shrd_cdts        ),
    .xadm_pd_shrd_cdts          (xadm_pd_shrd_cdts        ),
    .xadm_nph_shrd_cdts         (xadm_nph_shrd_cdts       ),
    .xadm_npd_shrd_cdts         (xadm_npd_shrd_cdts       ),
    .xadm_cplh_shrd_cdts        (xadm_cplh_shrd_cdts      ),
    .xadm_cpld_shrd_cdts        (xadm_cpld_shrd_cdts      ),

    // XAIM/XADM PKT interfaces (XALI, DMA, CCIX)
    .xaim_xadm_msg_pkt          (xaim_xadm_msg_pkt        ),
    .xadm_xaim_msg_halt         (xadm_xaim_msg_halt       ),
    .xaim_xadm_lbc_pkt          (xaim_xadm_lbc_pkt        ),
    .xadm_xaim_lbc_halt         (xadm_xaim_lbc_halt       ),
    .xaim_xadm_xali_pkt         (xaim_xadm_xali_pkt       ),
    .xadm_xaim_xali_halt        (xadm_xaim_xali_halt      ),

    .xaim_xadm_dma_pkt          ('0                       ), //TODO
    .xadm_xaim_dma_halt         (                         ),

    // IDE PKT Interface
    // XADM/XTLH PKT Interface
    .xadm_xtlh_pkt              (xadm_xtlh_pkt            ),
    .xtlh_xadm_pkt_halt         (xtlh_xadm_pkt_halt       ),
    .xadm_all_type_infinite     (xadm_all_type_infinite   )

    ,
    .rasdp_error_mode           (cfg_rasdp_error_mode_i)
    ,
    .ras_dp_err_log             (ras_dp_err_log_from_xadm)
    ,
    .ras_dp_err_inj             (ras_dp_err_inj  )
    ); // u_xadm_ms

// The *_evt cannot scale to the wider MS configuration (many VCs/FCs), so this is a temporary mapping which works only for maximum 6 channels (e.g. 1 VC with 2 channels per FC or 2 VCs with 1 channel per FC)
assign xtlh_tx_memwr_evt         = xadm_rasdes_tlp_trace.xadm_tx_memwr_evt;
assign xtlh_tx_msg_evt           = xadm_rasdes_tlp_trace.xadm_tx_msg_evt;
assign xtlh_tx_defmemwr_evt      = xadm_rasdes_tlp_trace.xadm_tx_defmemwr_evt;
assign xtlh_tx_memrd_evt         = xadm_rasdes_tlp_trace.xadm_tx_memrd_evt;
assign xtlh_tx_cfgwr_evt         = xadm_rasdes_tlp_trace.xadm_tx_cfgwr_evt;
assign xtlh_tx_cfgrd_evt         = xadm_rasdes_tlp_trace.xadm_tx_cfgrd_evt;
assign xtlh_tx_iowr_evt          = xadm_rasdes_tlp_trace.xadm_tx_iowr_evt;
assign xtlh_tx_iord_evt          = xadm_rasdes_tlp_trace.xadm_tx_iord_evt;
assign xtlh_tx_atmcop_evt        = xadm_rasdes_tlp_trace.xadm_tx_atmcop_evt;
assign xtlh_tx_cplwod_evt        = xadm_rasdes_tlp_trace.xadm_tx_cplwod_evt;
assign xtlh_tx_cplwd_evt         = xadm_rasdes_tlp_trace.xadm_tx_cplwd_evt;
assign xtlh_tx_tlpwprefix_evt    = xadm_rasdes_tlp_trace.xadm_tx_tlpwprefix_evt;
assign xtlh_tx_tlp_dpsize = xadm_rasdes_tlp_trace.xadm_tx_tlp_dpsize;
assign xadm_tx_nullify_evt = xadm_rasdes_tlp_trace.xadm_tx_null_evt;

//assign ras_stat_xadm_corr   = '0;
//assign ras_stat_xadm_uncorr = '0;
assign ras_err_inj_done_xadm = 1'b0;


wire trgt1_np_xfer_done;
assign trgt1_np_xfer_done  = |radm_trgt1_cpl_lookup_id_rlsd;



logic cfg_p2p_err_rpt_ctrl;
logic radm_formq_not_empty;
logic radm_formq_read_err;
logic radm_formq_overflow;



//
// RADM module for EP application
//

//==================================================================
// Structure map for config signals
//==================================================================
// Config structure map
radm_cfg_i_s                    radm_cfg_i_int;
radm_cfg_ntlp_ntrgt_i_s         radm_cfg_ntlp_ntrgt_i_int;
radm_cfg_ntlp_ntrgt_o_s         radm_cfg_ntlp_ntrgt_o_int;
// Header Logging Interface
radm_hdr_log_s                  int_radm_hdr_log ;
//-------------------------
radm_cfg_atu_s                  radm_cfg_atu_in;
// RADM diag interface:TODO
   logic [`CX_NVC-1:0]                           radm_qoverflow_ms;
   logic [`CX_NVC-1:0]                           radm_q_not_empty_ms;
   logic                                     radm_formq_read_err_ms;
   logic                                     radm_formq_overflow_ms;
  logic                                     radm_formq_not_empty_ms;

logic int_radm_inta_asserted ;
logic int_radm_intb_asserted ;
logic int_radm_intc_asserted;
logic int_radm_intd_asserted;

    assign trgt1_radm_intf_np_0_halt_int = (trgt1_radm_intf_np_0_halt | ~trgt_lookup_empty);


logic [`CX_REMOTE_RD_REQ_SIZE_PW-1:0] cfg_remote_rd_req_bridge_size_dec_in;

// simple function for minimum (saturation check)
function automatic integer min;
  input integer  a;
  input integer  b;

begin
  min = (a<b)? a:b;
end
endfunction

always_comb
begin
  case (int_cfg_remote_rd_req_bridge_size)
   3'b000 :cfg_remote_rd_req_bridge_size_dec_in = min(128,`CX_REMOTE_RD_REQ_SIZE);
   3'b001 :cfg_remote_rd_req_bridge_size_dec_in = min(256,`CX_REMOTE_RD_REQ_SIZE);
   3'b010 :cfg_remote_rd_req_bridge_size_dec_in = min(512,`CX_REMOTE_RD_REQ_SIZE);
   3'b011 :cfg_remote_rd_req_bridge_size_dec_in = min(1024,`CX_REMOTE_RD_REQ_SIZE);
   3'b100 :cfg_remote_rd_req_bridge_size_dec_in = min(2048,`CX_REMOTE_RD_REQ_SIZE);
   3'b101 :cfg_remote_rd_req_bridge_size_dec_in = min(4096,`CX_REMOTE_RD_REQ_SIZE);
   default :cfg_remote_rd_req_bridge_size_dec_in = min(128,`CX_REMOTE_RD_REQ_SIZE);
  endcase
end

always_comb 
begin
  for (int i = 0; i < `CX_RADM_NFC_TRGT_INTF; i = i + 1) begin
    radm_msg_payload[i*64+63 -: 64] =  radm_cfg_ntlp_ntrgt_o_int.radm_msg_payload[i*3*64+63 -: 64];
    radm_msg_req_id[i*16+15 -: 16]  =  radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_tlp_req_id[i*3*16+15 -: 16];
    radm_vendor_msg[i]              =  radm_cfg_ntlp_ntrgt_o_int.radm_vendor_msg[i*3]; 
    radm_vendor_msg_type[i]         =  radm_cfg_ntlp_ntrgt_o_int.radm_vendor_msg_type[i*3]; 
    int_radm_pm_pme[i]              =  radm_cfg_ntlp_ntrgt_o_int.int_radm_pm_pme[i*3];
    int_radm_correctable_err[i]        = radm_cfg_ntlp_ntrgt_o_int.radm_err_cor[i*3];
    int_radm_nonfatal_err[i]           = radm_cfg_ntlp_ntrgt_o_int.radm_err_nf[i*3];
    int_radm_fatal_err[i]              = radm_cfg_ntlp_ntrgt_o_int.radm_err_f[i*3];    
      radm_drs_msg[i]                           =  radm_cfg_ntlp_ntrgt_o_int.radm_drs_msg[i*3] ;
      radm_frs_msg[i]                           =  radm_cfg_ntlp_ntrgt_o_int.radm_frs_msg[i*3] ;
      radm_frs_msg_reason[i*4+3 -: 4]           = radm_cfg_ntlp_ntrgt_o_int.radm_frs_msg_reason[i*3*4+3 -: 4];
  end
end

always_comb
begin
  // Configurations
  radm_cfg_i_int.cfg_ecrc_chk_en                                =  cfg_ecrc_chk_en;
    radm_cfg_i_int.cfg_ltr_m_en                                 =  cfg_ltr_m_en;
  radm_cfg_i_int.cfg_bar_is_io                                  =  cfg_bar_is_io;
  radm_cfg_ntlp_ntrgt_i_int.cfg_io_match                        =  cfg_io_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_config_above_match              =  cfg_config_above_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_bar_match                       =  cfg_bar_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_rom_match                       =  cfg_rom_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_prefmem_match                  = cfg_prefmem_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_mem_match                      = cfg_mem_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_rcrb_match                     = cfg_rcrb_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_cxl_mbar0_match                = cfg_cxl_2_0_mbar0_match;
  radm_cfg_ntlp_ntrgt_i_int.cxl_2_0_mbar0_access_int           = cxl_2_0_mbar0_access_int;
  radm_cfg_ntlp_ntrgt_i_int.cfg_cxl_alt_mem_match              = cfg_cxl_alt_mem_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_cxl_alt_prefmem_match          = cfg_cxl_alt_prefmem_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_rcrb_mbar0_match               = cfg_rcrb_mbar0_match;
  radm_cfg_ntlp_ntrgt_i_int.cfg_rcrb_mbar0_match_int           = cfg_rcrb_mbar0_match_int;


  radm_cfg_i_int.cxl_rcrb_enable                                = cxl_rcrb_enable;
  radm_cfg_i_int.cfg_cxl_alt_bme                                = cfg_cxl_alt_bme;
  radm_cfg_i_int.cfg_cxl_alt_bus_base                           = cfg_cxl_alt_bus_base;
  radm_cfg_i_int.cfg_cxl_alt_bus_limit                          = cfg_cxl_alt_bus_limit;

  radm_cfg_i_int.device_type                                    =  device_type_o;
  radm_cfg_i_int.cfg_tc_struc_vc_map                            =  cfg_tc_struc_vc_map;
  radm_cfg_i_int.cfg_tc_enable                                  =  cfg_tc_enable;
  radm_cfg_i_int.cfg_filter_rule_mask                           =  cfg_filter_rule_mask;
  radm_cfg_i_int.cfg_rcb_128                                    =  cfg_rcb[0];
  radm_cfg_i_int.cfg_max_func_num                               =  cfg_max_func_num;
// In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
  radm_cfg_i_int.cfg_max_payload                                =  cfg_max_payload_size_out_rx;
  radm_cfg_i_int.cfg_upstream_port                              =  upstream_port;
  radm_cfg_i_int.cfg_root_compx                                 =  rc_device;
  radm_cfg_i_int.cfg_endpoint                                   =  end_device;
    radm_cfg_i_int.cfg_obff_en                                  =  int_cfg_obff_en;
  radm_cfg_i_int.pm_radm_block_tlp                              =  pm_radm_block_tlp;

    radm_cfg_i_int.ras_radm_prot_disable                        =  ras_prot_r_disable[6:0];
      radm_cfg_i_int.ras_err_inj_en_array                       =  ras_err_inj_en_array;
      radm_cfg_i_int.ras_err_inj_mask                           =  ras_err_inj_mask;
    radm_cfg_i_int.cfg_max_end2end_tlp_prfxs                    =  cfg_max_end2end_tlp_prfxs;
    radm_cfg_i_int.default_target                               =  default_target;
    radm_cfg_i_int.ur_ca_mask_4_trgt1                           =  ur_ca_mask_4_trgt1;
    radm_cfg_i_int.cfg_target_above_config_limit                =  cfg_target_above_config_limit;
    radm_cfg_i_int.cfg_cfg_tlp_bypass_en                        =  cfg_cfg_tlp_bypass_en;
    radm_cfg_i_int.upstream_port                                =  upstream_port;
    //radm_cfg_ntlp_ntrgt_i_int.vendor_msg_id_match               =  'd0;
    radm_cfg_i_int.target_mem_map                               =  target_mem_map;
    radm_cfg_i_int.target_rom_map                               =  target_rom_map;


  radm_cfg_i_int.cfg_pbus_num                                   =  cfg_pbus_num;
  radm_cfg_i_int.cfg_pbus_dev_num                               =  cfg_pbus_dev_num;
    radm_cfg_i_int.cfg_ptm_enable                               =  cfg_ptm_enable;
    radm_cfg_i_int.cfg_remote_rd_req_bridge_size_dec            =  cfg_remote_rd_req_bridge_size_dec_in;

   radm_cfg_i_int.cdm_core_in_dpc      =   cdm_core_in_dpc;
   radm_cfg_i_int.dpc_fatal_err_gate   =   dpc_fatal_err_gate;         // DPC trigger gating for fatal error message
   radm_cfg_i_int.dpc_nonfatal_err_gate =   dpc_nonfatal_err_gate;

   radm_cfg_i_int.cfg_p2p_err_rpt_ctrl =   cfg_p2p_err_rpt_ctrl;
      radm_cfg_i_int.cfg_2ndbus_num    = cfg_2ndbus_num;
    radm_cfg_i_int.cfg_subbus_num    = cfg_subbus_num;

  radm_cfg_i_int.cfg_acs_validation_cap = cfg_acs_validation_cap;
  radm_cfg_i_int.cfg_acs_at_blocking_cap = cfg_acs_at_blocking_cap;
  radm_cfg_i_int.cfg_acs_up_forward_cap = cfg_acs_up_forward_cap;
  radm_cfg_i_int.cfg_acs_validation_en = cfg_acs_validation_en;
  radm_cfg_i_int.cfg_acs_at_blocking_en = cfg_acs_at_blocking_en;
  radm_cfg_i_int.cfg_acs_up_forward_en = cfg_acs_up_forward_en;

  //==============================================
  // Configurations output

     radm_ptm_req                                  =  |radm_cfg_ntlp_ntrgt_o_int.radm_ptm_req;
     radm_ptm_res_msg                              =  |radm_cfg_ntlp_ntrgt_o_int.radm_ptm_res_msg;
     radm_ptm_res_d_msg                            =  |radm_cfg_ntlp_ntrgt_o_int.radm_ptm_res_d_msg;
     radm_ptm_master_time                          =  radm_cfg_ntlp_ntrgt_o_int.radm_ptm_master_time[63:0]; // Taken it only for Posted TLP
     radm_ptm_prop_delay                           =  radm_cfg_ntlp_ntrgt_o_int.radm_ptm_prop_delay[31:0]; // Taken it only for Posted TLP
   flt_cdm_pf                                     =  radm_cfg_ntlp_ntrgt_o_int.flt_cdm_pf;
    radm_ecrc_err                                  =  radm_cfg_ntlp_ntrgt_o_int.radm_ecrc_err;
    radm_mlf_tlp_err                               =  radm_cfg_ntlp_ntrgt_o_int.radm_mlf_tlp_err;

        ras_stat_radm_bypass_uncorr = 'd0;
         radm_rasdp_cpl_lut_valid = 'd0;
      radm_parerr        ='d0;


   int_radm_inta_asserted = |radm_cfg_ntlp_ntrgt_o_int.radm_inta_asserted;
   int_radm_intb_asserted = |radm_cfg_ntlp_ntrgt_o_int.radm_intb_asserted;
   int_radm_intc_asserted = |radm_cfg_ntlp_ntrgt_o_int.radm_intc_asserted;
   int_radm_intd_asserted = |radm_cfg_ntlp_ntrgt_o_int.radm_intd_asserted;


   radm_inta_asserted = int_radm_inta_asserted;
   radm_intb_asserted = int_radm_intb_asserted;
   radm_intc_asserted = int_radm_intc_asserted;
   radm_intd_asserted = int_radm_intd_asserted;


   radm_inta_deasserted = |radm_cfg_ntlp_ntrgt_o_int.radm_inta_deasserted ;
   radm_intb_deasserted = |radm_cfg_ntlp_ntrgt_o_int.radm_intb_deasserted;
   radm_intc_deasserted = |radm_cfg_ntlp_ntrgt_o_int.radm_intc_deasserted;
   radm_intd_deasserted = |radm_cfg_ntlp_ntrgt_o_int.radm_intd_deasserted;

  cdm_err_advisory                = {`CX_FX_TLP{1'b0}};



     radm_mlf_tlp_err_ptr                          =  radm_cfg_ntlp_ntrgt_o_int.radm_mlf_tlp_err_ptr;
    radm_rcvd_wreq_poisoned                        =  {|radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_wreq_poisoned[3*`CX_NFUNC-1:2*`CX_NFUNC],|radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_wreq_poisoned[2*`CX_NFUNC-1:`CX_NFUNC],|radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_wreq_poisoned[`CX_NFUNC-1:0]};
    radm_rcvd_req_ur                               =  radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_req_ur;
    radm_rcvd_req_ca                               =  radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_req_ca;
    radm_hdr_log_valid                             =  radm_cfg_ntlp_ntrgt_o_int.radm_hdr_log_valid;
    radm_hdr_log                                   =  radm_cfg_ntlp_ntrgt_o_int.radm_hdr_log;
     radm_tlp_prfx_log                             =  radm_cfg_ntlp_ntrgt_o_int.radm_tlp_prfx_log;


   radm_slot_pwr_payload                           = radm_cfg_ntlp_ntrgt_o_int.radm_msg_payload[31:0];
   radm_slot_pwr_limit                             =  |radm_cfg_ntlp_ntrgt_o_int.radm_slot_pwr_limit;
   int_radm_pm_to_ack                              =  |radm_cfg_ntlp_ntrgt_o_int.radm_pm_to_ack;

   radm_pm_asnak                                   =  |radm_cfg_ntlp_ntrgt_o_int.radm_pm_asnak;
   radm_pm_turnoff                                 =  |radm_cfg_ntlp_ntrgt_o_int.radm_pm_turnoff;
   radm_msg_unlock                                 =  |radm_cfg_ntlp_ntrgt_o_int.radm_msg_unlock;






     radm_msg_idle                                 =  radm_cfg_ntlp_ntrgt_o_int.radm_msg_idle[0];
     radm_msg_obff                                 =  radm_cfg_ntlp_ntrgt_o_int.radm_msg_obff[0];
     radm_msg_cpu_active                           =  radm_cfg_ntlp_ntrgt_o_int.radm_msg_cpu_active[0];
       // TODO : Need to check and remove if not needed
       ras_err_inj_done_radm                       =  1'd0;
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //   ccix_tlp                          =  radm_cfg_ntlp_ntrgt_o_int.ccix_tlp;
    //  `endif // CX_CCIX_INTERFACE_ENABLE
   // flt_dwlenEq0                                   =  radm_cfg_ntlp_ntrgt_o_int.flt_dwlenEq0;
   // tlp_poisoned                                   =  radm_cfg_ntlp_ntrgt_o_int.tlp_poisoned;
    radm_snoop_upd                                 =  radm_cfg_ntlp_ntrgt_o_int.radm_snoop_upd;
    radm_snoop_bus_num                             =  radm_cfg_ntlp_ntrgt_o_int.radm_snoop_bus_num[15:8]; // Take value from the NP filter
    radm_snoop_dev_num                             =  radm_cfg_ntlp_ntrgt_o_int.radm_snoop_dev_num[9:5];  // Take value from the NP filter
    radm_np_segment_id                             =  radm_cfg_ntlp_ntrgt_o_int.cfg_segment_id[17:9];  // Take value from the NP filter

    radm_rcvd_cpl_poisoned                         =  radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_cpl_poisoned;
    radm_rcvd_cpl_ur                               =  radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_cpl_ur;
    radm_rcvd_cpl_ca                               =  radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_cpl_ca;
    radm_unexp_cpl_err                             =  radm_cfg_ntlp_ntrgt_o_int.radm_unexp_cpl_err;


    radm_msg_ltr                                   =  |radm_cfg_ntlp_ntrgt_o_int.radm_msg_ltr;
    radm_msg_ltr_latency                           =  radm_cfg_ntlp_ntrgt_o_int.radm_msg_ltr_latency[31:0];


  // ATU
  // ATU inbound Region controls
  radm_cfg_atu_in.atu_reg_in_type                                 =  atu_reg_in_type;
  radm_cfg_atu_in.atu_reg_in_tc                                   =  atu_reg_in_tc;
  radm_cfg_atu_in.atu_reg_in_td                                   =  atu_reg_in_td;
  radm_cfg_atu_in.atu_reg_in_attr                                 =  atu_reg_in_attr;
    radm_cfg_atu_in.atu_reg_in_at                                 =  atu_reg_in_at;
  radm_cfg_atu_in.atu_reg_in_func_num                             =  atu_reg_in_func_num;
  radm_cfg_atu_in.atu_reg_in_msg_code                             =  atu_reg_in_msg_code;
    radm_cfg_atu_in.atu_reg_in_th                                 =  atu_reg_in_th;
    radm_cfg_atu_in.atu_reg_in_ph                                 =  atu_reg_in_ph;
    radm_cfg_atu_in.atu_reg_in_st                                 =  atu_reg_in_st;
  radm_cfg_atu_in.atu_reg_in_bar_num                              =  atu_reg_in_bar_num;
  // Inbound field match enables
  radm_cfg_atu_in.atu_reg_in_tc_match_en                          =  atu_reg_in_tc_match_en;
  radm_cfg_atu_in.atu_reg_in_td_match_en                          =  atu_reg_in_td_match_en;
  radm_cfg_atu_in.atu_reg_in_attr_match_en                        =  atu_reg_in_attr_match_en;
    radm_cfg_atu_in.atu_reg_in_at_match_en                        =  atu_reg_in_at_match_en;
  radm_cfg_atu_in.atu_reg_in_func_match_en                        =  atu_reg_in_func_match_en;
  radm_cfg_atu_in.atu_reg_in_msgcode_match_en                     =  atu_reg_in_msgcode_match_en;
    radm_cfg_atu_in.atu_reg_in_th_match_en                        =  atu_reg_in_th_match_en;
    radm_cfg_atu_in.atu_reg_in_ph_match_en                        =  atu_reg_in_ph_match_en;
    radm_cfg_atu_in.atu_reg_in_st_match_en                        =  atu_reg_in_st_match_en;
  radm_cfg_atu_in.atu_reg_in_single_addr_loc_en                   =  atu_reg_in_single_addr_loc_en;
  radm_cfg_atu_in.atu_reg_in_msg_type_match_mode                  =  atu_reg_in_msg_type_match_mode;
  // Response and mode settings
  radm_cfg_atu_in.atu_reg_in_rsp_code                             =  atu_reg_in_rsp_code;
  radm_cfg_atu_in.atu_reg_in_fuzzy                                =  atu_reg_in_fuzzy;
  radm_cfg_atu_in.atu_reg_in_shift                                =  atu_reg_in_shift;
  radm_cfg_atu_in.atu_reg_in_invert                               =  atu_reg_in_invert;
  radm_cfg_atu_in.atu_reg_in_bar_match                            =  atu_reg_in_bar_match;
  // Region Enable
  radm_cfg_atu_in.atu_reg_in_en                                   =  atu_reg_in_en;
  // Base, Limit and Target Registers
  radm_cfg_atu_in.atu_reg_in_base                                 =  atu_reg_in_base;
  radm_cfg_atu_in.atu_reg_in_upr_base                             =  atu_reg_in_upr_base;
  radm_cfg_atu_in.atu_reg_in_limit                                =  atu_reg_in_limit;
    radm_cfg_atu_in.atu_reg_in_cbuf_incr                          =  atu_reg_in_cbuf_incr;
    radm_cfg_atu_in.atu_reg_in_cbuf_restart                       =  atu_reg_in_cbuf_restart;
    //radm_cfg_atu_in.radm_outq_pkt_eot                             =  radm_outq_pkt_eot;
    radm_cfg_atu_in.radm_outq_pkt_eot                             =  0;

    radm_cfg_atu_in.atu_reg_in_uppr_limit                         =  atu_reg_in_uppr_limit;
  radm_cfg_atu_in.atu_reg_in_lwr_trgt                             =  atu_reg_in_lwr_trgt;
  radm_cfg_atu_in.atu_reg_in_upr_trgt                             =  atu_reg_in_upr_trgt;
  radm_cfg_atu_in.atu_reg_in_incr_rgn_size                        =  atu_reg_in_incr_rgn_size;

  //radm_cfg_atu_in.halt_in                                         =  halt_in;
  radm_cfg_atu_in.halt_in                                         =  0;

  radm_cfg_atu_in.cfg_bar0_mask                                   =  cfg_bar0_mask;
  radm_cfg_atu_in.cfg_bar1_mask                                   =  cfg_bar1_mask;
  radm_cfg_atu_in.cfg_bar2_mask                                   =  cfg_bar2_mask;
  radm_cfg_atu_in.cfg_bar3_mask                                   =  cfg_bar3_mask;
  radm_cfg_atu_in.cfg_bar4_mask                                   =  cfg_bar4_mask;
  radm_cfg_atu_in.cfg_bar5_mask                                   =  cfg_bar5_mask;
  radm_cfg_atu_in.cfg_rom_mask                                    =  cfg_rom_mask;

  radm_qoverflow               = radm_qoverflow_ms;
  radm_q_not_empty             = radm_q_not_empty_ms;
  radm_formq_read_err          = radm_formq_read_err_ms;
  radm_formq_overflow          = radm_formq_overflow_ms;
  radm_formq_not_empty         = radm_formq_not_empty_ms;

end

assign radm_rcvd_acs_err = radm_cfg_ntlp_ntrgt_o_int.radm_rcvd_acs_err;

logic  [2:0] radm_timeout_cpl_attr_i_int;
assign radm_timeout_cpl_attr_i = radm_timeout_cpl_attr_i_int[1:0];

// Config structure map end
//==================================================================
radm
 u_radm
(
  //.flit_mode_en                         (FlitModeEn),
  .non_sticky_rst_n                     (non_sticky_rst_n),
  .flit_mode_en                         (int_flit_mode_enable),
  .radm_clk_ug                          (core_clk),
    .cfg_radm_clk_control           (cfg_clock_gating_ctrl[0]),
  .rstctl_core_flush_req                (rstctl_core_flush_req),
  .pm_l1_aspm_entr                      (pm_l1_aspm_entr),
  //--------------- Interace from RTLH ---------------------
  .rtlh_radm                            (rtlh_radm),
  `ifndef SYNTHESIS
  .radm_tlp_order                       (radm_tlp_order),
  .radm_flt_pkt_num_p_valid             (radm_flt_pkt_num_p_valid),
  .radm_flt_pkt_num_p                   (radm_flt_pkt_num_p),
  .radm_flt_pkt_num_np_valid            (radm_flt_pkt_num_np_valid),
  .radm_flt_pkt_num_np                  (radm_flt_pkt_num_np),
  .radm_flt_pkt_num_cpl_valid           (radm_flt_pkt_num_cpl_valid),
  .radm_flt_pkt_num_cpl                 (radm_flt_pkt_num_cpl),
  `endif // !SYNTHESIS
  //--------------- Interface from XADM --------------------
  .xadm_radm_tx_npr                     (xadm_radm_tx_npr),
  //-------- Interface with CDM HDR & PRFX LOGGING ---------
  .radm_hdr_log                         (int_radm_hdr_log),
  //-----------------   --------------------------
  //--------------- External Memory Interfaces -------------

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
  .radm_rtlh_ph_ca                    (radm_rtlh_ph_ca),
  .radm_rtlh_pd_ca                    (radm_rtlh_pd_ca),
  .radm_rtlh_nph_ca                   (radm_rtlh_nph_ca),
  .radm_rtlh_npd_ca                  (radm_rtlh_npd_ca),
  .radm_rtlh_cplh_ca                 (radm_rtlh_cplh_ca),
  .radm_rtlh_cpld_ca                 (radm_rtlh_cpld_ca),
  ///////////////////  CPL LUT signals  //////////
  .cfg_p2p_track_cpl_to                 (cfg_p2p_track_cpl_to),
  .cfg_p2p_err_rpt_ctrl                 (cfg_p2p_err_rpt_ctrl),
    .device_type                        (device_type_o),
    .cdm_dpc_triggered                  (cdm_dpc_triggered),
    .cdm_core_in_dpc                    (cdm_core_in_dpc),
    .cfg_dpc_cpl_cntrl                  (cfg_dpc_cpl_cntrl),
  // Config signals
  .radm_cfg_i                           (radm_cfg_i_int),
  .radm_cfg_ntlp_ntrgt_i                (radm_cfg_ntlp_ntrgt_i_int),
  .radm_cfg_ntlp_ntrgt_o                (radm_cfg_ntlp_ntrgt_o_int),
  .flt_cdm_addr_o                       (flt_cdm_addr),
  .flt_cdm_addr_valid_o                 (flt_cdm_addr_valid),
  .radm_cfg_atu_in                      (radm_cfg_atu_in),
  //////////////// completion packet signals ///////////////////
    .rcrb_base_addr                                       (rcrb_base_addr                               ),
    .rcrb_base_addr_valid                                 (rcrb_base_addr_valid                         ),


    .cfg_cpl_timeout_range              (cfg_cpl_timeout_range),
  .cfg_cpl_timeout_disable              (cfg_cpl_timeout_disable),
  .current_data_rate                    (int_current_data_rate),
  .radm_cpl_pending                     (radm_cpl_pending),
  //          radm_cpl_lut_busy,
  // Completion Timeout Interface
  .radm_cpl_timeout                     (radm_cpl_timeout_i),
  .radm_cpl_timeout_cdm                 (radm_cpl_timeout_cdm_i),
  .radm_timeout_func_num                (radm_timeout_func_num_i),
  .radm_timeout_cpl_tc                  (radm_timeout_cpl_tc_i),
  .radm_timeout_cpl_attr                (radm_timeout_cpl_attr_i_int),
  .radm_timeout_cpl_len                 (radm_timeout_cpl_len_i),
  .radm_timeout_cpl_tag                 (radm_timeout_cpl_tag_i),

  .radm_cpl_lut_valid                   (radm_cpl_lut_valid_i),
  .xtlh_np_tlp_early                    (xadm_radm_wakeup),
  /////////////////////////////////// TRGT1 Signals ///////////////////////////////////////
  .app_req_retry_en                     (app_req_retry_en),
  .app_pf_req_retry_en                  (app_pf_req_retry_en),
  // configurations end
  // Posted


  // --------------- Inputs ---------------------
  // cpl
  .trgt1_radm_intf_halt_cpl             (trgt1_radm_intf_cpl_0_halt),

  // posted
  .trgt0_radm_halt                      (|trgt0_radm_halt),
    .trgt1_radm_intf_halt_p             (trgt1_radm_intf_p_0_halt),
  // non posted

  // Filter I/O

    .trgt1_radm_intf_halt_np            (trgt1_radm_intf_np_0_halt_int),


  //////////// Output port for TRGT1  ///////
  .radm_trgt1_out_p                 (radm_trgt1_out_p),
  .radm_trgt1_out_np                (radm_trgt1_out_np_int),
  .radm_trgt1_out_cpl               (radm_trgt1_out_cpl),
  .radm_trgt1_p_pending             (radm_trgt1_p_pending),

  // For completion

/*
  `ifdef CX_SRIOV_ENABLE
  .radm_rcvd_cpl_0_poisoned_vf                   (radm_rcvd_cpl_0_poisoned_vf                              ),
  .radm_rcvd_cpl_0_ur_vf                         (radm_rcvd_cpl_0_ur_vf                                    ),
  .radm_rcvd_cpl_0_ca_vf                         (radm_rcvd_cpl_0_ca_vf                                    ),
  `endif // CX_SRIOV_ENABLE

  .radm_unexp_cpl_0_err                          (radm_unexp_cpl_0_err                                     ),
  .radm_rcvd_cpl_0_ca                            (radm_rcvd_cpl_0_ca                                       ),
  .radm_rcvd_cpl_0_ur                            (radm_rcvd_cpl_0_ur                                       ),
  .cpl_0_tlp_cpl                                 (cpl_0_tlp_cpl                                            ),

  .cpl_0_flt_q_rcvd_cpl_tlp_tag                  (cpl_0_flt_q_rcvd_cpl_tlp_tag                             ),
  .cpl_0_status_cpl                              (cpl_0_status_cpl                                         ),
  .radm_snoop_cpl_0_upd                          (radm_snoop_cpl_0_upd                                     ),
*/

//  .filt_ord_halt_in_cpl                         (filt_ord_halt_in_cpl                                    ),
 // .dmux_trgt0_cpl_0_req                          (dmux_trgt0_cpl_0_req                                     ),
  .radm_trgt0_data                               (radm_trgt0_data),
  .radm_trgt0_abort                              (radm_trgt0_abort),
  .radm_trgt0_dv                                 (radm_trgt0_dv),
  .radm_trgt0_dwen                               (radm_trgt0_dwen),
  .radm_trgt0_ecrc_err                           (),
  .radm_trgt0_eot                                (radm_trgt0_eot),
  .radm_trgt0_hdr                                (radm_trgt0_hdr),
  .radm_trgt0_hv                                 (radm_trgt0_hv),
  .radm_trgt0_np_rsvd                            (radm_trgt0_np_rsvd),
  .radm_trgt0_pending                            (radm_trgt0_pending),
  .radm_qoverflow_ms                             (radm_qoverflow_ms),
  .radm_q_not_empty_ms                           (radm_q_not_empty_ms),
  .radm_formq_read_err_ms                        (radm_formq_read_err_ms),
  .radm_formq_overflow_ms                        (radm_formq_overflow_ms),
  .radm_formq_not_empty_ms                       (radm_formq_not_empty_ms)

  ,.core_clk                             (radm_clk_g),
  .core_rst_n                            (core_rst_n)

 // IDE PKT Interface
 ,.radm_idle                       (radm_idle)
 ,.radm_clk_en                     (en_radm_clk_g)
 ,
 .rasdp_error_mode                  (cfg_rasdp_error_mode_i),
 .ras_dp_err_log                    (ras_dp_err_log_from_radm)
 ,
 .ras_dp_err_inj_wake_up            (ras_dp_err_inj_wake_up),
 .ras_dp_err_inj                    (ras_dp_err_inj)
    ,
    .cdm_ras_des_einj0_enable        (cdm_ras_des_einj0_enable  ),
    .cdm_ras_des_einj0_crc_type      (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj0_count         (cdm_ras_des_einj0_count   ),
    .cdm_ras_des_einj0_vc_sel        (cdm_ras_des_einj0_ecrc_vc_sel),
    .cdm_ras_des_einj0_fc_sel        (cdm_ras_des_einj0_ecrc_fc_sel),
    .cdm_ras_des_einj0_intf_sel      (cdm_ras_des_einj0_ecrc_intf_sel),
    .radm_einj0_ecrc_evt             (radm_einj0_ecrc_evt       )
  ,
  .radm_ras_des_err_info_0            (radm_ras_des_err_info_0)
); // u_radm







// START_IO:DBI Signal Descriptions.
wire    [31:0]                      int_dbi_addr;
wire    [31:0]                      int_dbi_din;
wire                                int_dbi_cs;
wire                                int_dbi_cs2;
wire    [3:0]                       int_dbi_wr;
wire                                int_lbc_dbi_ack;
wire    [31:0]                      int_lbc_dbi_dout;

wire    [`CX_NFUNC_WD-1:0]                 int_dbi_func_num;                   // Function number of the DBI access
wire    [`CX_NFUNC_WD-1:0]                 muxd_slv_dbi_func_num;              // Function number (up to 256 for ARI devices) from AXI Bridge for DBI access

wire    [2:0]                       int_dbi_bar_num;                    // BAR number of the DBI access
wire                                int_dbi_rom_access;                 // ROM BAR of the DBI access
wire                                int_dbi_io_access;                  // IO BAR of the DBI access

assign muxd_slv_dbi_func_num = slv_dbi_func_num; // Function number from AXI Bridge for DBI access via LBC

     assign int_dbi_addr        = slv_dbi_addr;
     assign int_dbi_din         = slv_dbi_din;
     assign int_dbi_cs          = slv_dbi_cs;
     assign int_dbi_cs2         = slv_dbi_cs2;
     assign int_dbi_wr          = slv_dbi_wr;
      assign int_dbi_func_num = muxd_slv_dbi_func_num;
       assign int_dbi_bar_num     = slv_dbi_bar_num;
       assign int_dbi_rom_access  = slv_dbi_rom_access;
       assign int_dbi_io_access   = slv_dbi_io_access;
     assign slv_lbc_dbi_ack     = int_lbc_dbi_ack;
     assign slv_lbc_dbi_dout    = int_lbc_dbi_dout;

//
// CDM Module (default configuration is TYPE 0 header type)
//

// Assign individual output signals:
always @(*) begin : extract_pf_pasid_control
    integer i;
    for(i = 0; i < `CX_NFUNC; i = i + 1) begin           // Repaet for every allocated prefix slot
       cfg_pf_pasid_en[i]              = cfg_pf_pasid_control[PASID_CNTRL_WD*i];
       cfg_pf_pasid_execute_perm_en[i] = cfg_pf_pasid_control[(PASID_CNTRL_WD*i) + 1];
       cfg_pf_pasid_priv_mode_en[i]    = cfg_pf_pasid_control[(PASID_CNTRL_WD*i) + 2];
    end
end



//
// Any changes made to u_cdm MUST also be made to u_cdm_b
//

cdm

#(
  .INST(INST)
  )
u_cdm (
    // ------------- inputs --------------
    .core_clk                       (aux_clk_g),
    .non_sticky_rst_n               (non_sticky_rst_n),
    .sticky_rst_n                   (sticky_rst_n),
    .device_type                    (device_type_o),
    .app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable),

    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_cs                     (lbc_cdm_cs),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    .cxl_rcrb_enable                (cxl_rcrb_enable),
    .cxl_mbar0_enable               (cxl_mbar0_enable),
    .lbc_cdm_rcrb_wire              (lbc_cdm_rcrb_wire),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .lbc_cdm_rcrb_mbar0_wire        (lbc_cdm_rcrb_mbar0_wire),
    .lbc_cdm_rcrb_mbar0_dbi         (lbc_cdm_rcrb_mbar0_dbi),
    .lbc_cdm_unroll                 (lbc_cdm_unroll),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_xmt_cpl_ca                 (lbc_xmt_cpl_ca),
    .sys_int                        (sys_int),                      // not applicable to RC
    .sys_aux_pwr_det                (pm_sys_aux_pwr_det),
    .sys_pre_det_chged              (sys_pre_det_chged),
    .sys_atten_button_pressed       (sys_atten_button_pressed),
    .sys_pwr_fault_det              (sys_pwr_fault_det),
    .sys_mrl_sensor_chged           (sys_mrl_sensor_chged),
    .sys_cmd_cpled_int              (sys_cmd_cpled_int),
    .sys_pre_det_state              (sys_pre_det_state),
    .sys_mrl_sensor_state           (sys_mrl_sensor_state),
    .sys_eml_interlock_engaged      (sys_eml_interlock_engaged),

    .phy_cfg_status                 (phy_cfg_status),
    .cxpl_debug_info                (cxpl_debug_info),
    .smlh_autoneg_link_width        (smlh_autoneg_link_width),
    .rplh_link_rxmode               (rplh_link_rxmode),
    .smlh_autoneg_link_sp           (smlh_autoneg_link_sp),
    .smlh_link_training_in_prog     (smlh_link_training_in_prog),
    .rmlh_rcvd_err                  (rmlh_rcvd_err),
    .xadm_xmt_pci_errors            (xadm_xmt_pci_errors),

    .radm_hdrlog                   (int_radm_hdr_log),


    .app_hdr_valid                  (app_hdr_valid),
    .app_hdr_log                    (app_hdr_log),
    .app_hdr_flitmode               (app_hdr_flitmode),
    .app_hdr_log_size               (app_hdr_log_size),

    .app_err_bus                    (app_err_bus),
    .app_err_advisory               (app_err_advisory),
    .app_poisoned_tlp_type          (app_poisoned_tlp_type),
    .app_err_func_num               (app_err_func_num),

    .rtlh_overfl_err                (rtlh_overfl_err_nf),
    .rtlh_fc_init_status            (rtlh_fc_init_status),

    .xal_xmt_cpl_ca                 ({`CX_NFUNC{1'b0}}),
    .xal_rcvd_cpl_ca                ({`CX_NFUNC{1'b0}}),
    .xal_rcvd_cpl_ur                ({`CX_NFUNC{1'b0}}),
    .xal_perr                       ({`CX_NFUNC{1'b0}}),
    .xal_serr                       ({`CX_NFUNC{1'b0}}),
    .xal_set_trgt_abort_primary     ({`CX_NFUNC{1'b0}}),
    .xal_set_mstr_abort_primary     ({`CX_NFUNC{1'b0}}),
    .xal_pci_addr_perr              ({`CX_NFUNC{1'b0}}),
    //input
    .radm_pm_to_ack                 (radm_pm_to_ack),
    .pm_xmt_turnoff                 (pm_xmt_turnoff),
    //output
    .surprise_down_err              (surprise_down_err),
    .rdlh_dlcntrl_state             (rdlh_dlcntrl_state),
    .rdlh_rcvd_dl_feature           (rdlh_rcvd_dl_feature),
    .rcvd_dl_feature_content        (rcvd_dl_feature_content),
    .dl_prot_err                    (dl_prot_err),
    .rdlh_bad_tlp_err               (rdlh_bad_tlp_err),
    .rdlh_bad_dllp_err              (rdlh_bad_dllp_err),
    .rdlh_link_up                   (rdlh_link_up),
    .xdlh_replay_num_rlover_err     (replay_num_rlover_err),
    .xdlh_replay_timeout_err        (replay_timeout_err),
    .smlh_link_up                   (smlh_link_up),
    .smlh_bw_mgt_status             (smlh_bw_mgt_status),
    .smlh_link_auto_bw_status       (smlh_link_auto_bw_status),
    .current_data_rate              (pm_current_data_rate),
    .tmp_int_mac_phy_rate           (tmp_int_mac_phy_rate),
    .smlh_clr_enter_compliance      (smlh_clr_enter_compliance),
    .smlh_tx_margin_rst             (smlh_tx_margin_rst),
    .smlh_core_rst_n_release_pulse  (smlh_core_rst_n_release_pulse),
    .smlh_dir_spd_chg_rising_edge   (smlh_dir_spd_chg_rising_edge),
    .mac_phy_txdeemph               (tmp_mac_phy_txdeemph_0),
    .smlh_dir_linkw_chg_started     (smlh_dir_linkw_chg_started),
    .cfg_pwr_budget_data_reg        (cfg_pwr_budget_data_reg),
    .cfg_pwr_budget_func_num        (cfg_pwr_budget_func_num),
    .radm_cpl_pending               (radm_cpl_pending),
    .radm_cpl_timeout               (radm_cpl_timeout_cdm_i),
    .radm_timeout_func_num           (radm_timeout_func_num_i),
    .radm_set_slot_pwr_limit        ({`CX_NFUNC{radm_slot_pwr_limit}}),
    .radm_slot_pwr_payload          (radm_slot_pwr_payload),

    .radm_msg_req_id                (radm_msg_req_id),
    .radm_pm_pme                    (cdm_radm_pm_pme),            // Only for RC
    .radm_drs_msg                   (radm_drs_msg),
    .smlh_ltssm_state               (smlh_ltssm_state),
    .radm_frs_msg                   (radm_frs_msg),
    .radm_frs_msg_reason            (radm_frs_msg_reason),  //req id already input above
    .pmstate_d3hot_to_d0            (pmstate_d3hot_to_d0),

    .radm_correctable_err           (cdm_radm_correctable_err),   // Only for RC or SW
    .radm_nonfatal_err              (cdm_radm_nonfatal_err),      // Only for RC or SW
    .radm_fatal_err                 (cdm_radm_fatal_err),         // Only for RC or SW
    .xtlh_xadm_ph_cdts              (xadm_ph_cdts[`CX_HCRD_WD-1:0]),
    .xtlh_xadm_nph_cdts             (xadm_nph_cdts[`CX_HCRD_WD-1:0]),
    .xtlh_xadm_cplh_cdts            (xadm_cplh_cdts[`CX_HCRD_WD-1:0]),
    .xtlh_xadm_pd_cdts              (xadm_pd_cdts[`CX_DCRD_WD-1:0]),
    .xtlh_xadm_npd_cdts             (xadm_npd_cdts[`CX_DCRD_WD-1:0]),
    .xtlh_xadm_cpld_cdts            (xadm_cpld_cdts[`CX_DCRD_WD-1:0]),

    .radm_qoverflow                 (|radm_qoverflow),
    .radm_q_not_empty               (radm_q_not_empty[0]),
    .radm_formq_read_err            (radm_formq_read_err),
    .radm_formq_overflow            (radm_formq_overflow),
    .radm_formq_not_empty           (radm_formq_not_empty),
    .xdlh_retrybuf_not_empty        (xdlh_retrybuf_not_empty),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn[0]),

    // aux power reserved signals
    .pm_status                      (pm_status),
    .pm_pme_en                      (pm_pme_en_split),
    .aux_pm_en                      (pm_aux_pm_en_split),
    .flt_cdm_addr                   (flt_cdm_addr),
    .flt_cdm_pf                     (flt_cdm_pf),
    .pm_radm_block_tlp              (pm_radm_block_tlp),
    .flt_cdm_addr_valid             (flt_cdm_addr_valid),
    .xadm_fc_prot_err               (xadm_fc_prot_err),



    .rmlh_lane_err                  (int_rmlh_lane_err),
    .smlh_ls2_eq_req                (smlh_ls2_eq_req),
    .smlh_ls2_eq_success            (smlh_ls2_eq_success),
    .smlh_ls2_eq_cmpl               (smlh_ls2_eq_cmpl),
    .smlh_ls2_eq_enter              (smlh_ls2_eq_enter),
    .smlh_ltssm_in_detectquiet      (smlh_ltssm_in_detectquiet),
    .smlh_lec_pset_ltx              (int_smlh_lec_pset_ltx),
    .smlh_lec_pset_lrx              (int_smlh_lec_pset_lrx),
    .smlh_ls2_g4_eq_req             (smlh_ls2_g4_eq_req),
    .smlh_ls2_g4_eq_success         (smlh_ls2_g4_eq_success),
    .smlh_ls2_g4_eq_cmpl            (smlh_ls2_g4_eq_cmpl),
    .smlh_ls2_g4_eq_enter           (smlh_ls2_g4_eq_enter),
    .smlh_lec_g4_pset_ltx           (int_smlh_lec_g4_pset_ltx),
    .smlh_lec_g4_pset_lrx           (smlh_lec_g4_pset_lrx),
    .smlh_ls2_g5_eq_req             (smlh_ls2_g5_eq_req),
    .smlh_ls2_g5_eq_success         (smlh_ls2_g5_eq_success),
    .smlh_ls2_g5_eq_cmpl            (smlh_ls2_g5_eq_cmpl),
    .smlh_ls2_g5_eq_enter           (smlh_ls2_g5_eq_enter),
    .smlh_lec_g5_pset_ltx           (int_smlh_lec_g5_pset_ltx),
    .smlh_lec_g5_pset_lrx           (smlh_lec_g5_pset_lrx),
    .smlh_elbc_rcvd                 (smlh_elbc_rcvd),
    .smlh_tx_precoding_on           (smlh_tx_precoding_on),
    .smlh_noeq_needed_rcvd          (smlh_noeq_needed_rcvd),
    .smlh_ls2_g6_eq_req             (smlh_ls2_g6_eq_req),
    .smlh_ls2_g6_eq_success         (smlh_ls2_g6_eq_success),
    .smlh_ls2_g6_eq_cmpl            (smlh_ls2_g6_eq_cmpl),
    .smlh_ls2_g6_eq_enter           (smlh_ls2_g6_eq_enter),
    .smlh_lec_g6_pset_ltx           (int_smlh_lec_g6_pset_ltx),
    .smlh_lec_g6_pset_lrx           (smlh_lec_g6_pset_lrx),
    .smlh_g6_tx_precoding_on        (smlh_g6_tx_precoding_on),
    .smlh_retimer_pre_detected      (smlh_retimer_pre_detected),
    .smlh_two_retimers_pre_detected (smlh_two_retimers_pre_detected),
    .smlh_crosslink_resolution      (smlh_crosslink_resolution),
    .rmlh_deskew_ctlskp_err         (int_rmlh_deskew_ctlskp_err),
    .smlh_margin_status_valid       (int_smlh_margin_status_valid),
    .smlh_margin_status             (int_smlh_margin_status),
    .smlh_margin_ready              (smlh_margin_ready),
    .app_margining_ready            (app_margining_ready),
    .app_margining_software_ready   (app_margining_software_ready),
    .smlh_mod_ts_rcvd               (smlh_mod_ts_rcvd),
    .mod_ts_data_rcvd               (mod_ts_data_rcvd),
    .mod_ts_data_sent               (mod_ts_data_sent),
    .app_ltr_msg_req                (app_ltr_msg_req),
    .msg_ltr_det                    (msg_ltr_det),
    .msg_ltr_latency                (msg_ltr_latency),
    .msgg2cdm_ltr_clr_msg_grant     (msgg2cdm_ltr_clr_msg_grant),
    .xdlh_retry_req                 (xdlh_retry_req),
    .exp_rom_validation_status_strobe            (exp_rom_validation_status_strobe ),
    .exp_rom_validation_status                   (exp_rom_validation_status        ),
    .exp_rom_validation_details_strobe           (exp_rom_validation_details_strobe),
    .exp_rom_validation_details                  (exp_rom_validation_details       ),
    .app_ras_des_tba_ctrl           (app_ras_des_tba_ctrl),
    .cdm_ras_des_ec_ram_dataout     (cdm_ras_des_ec_ram_dataout),
    .cdm_ras_des_tba_ram_dataout    (cdm_ras_des_tba_ram_dataout),
    .rmlh_ebuf_rxoverflow           (rmlh_ebuf_rxoverflow),
    .rmlh_ebuf_rxunderflow          (rmlh_ebuf_rxunderflow),
    .rmlh_phy_rxcodeerror           (rmlh_phy_rxcodeerror),
    .rmlh_phy_rxdisperror           (rmlh_phy_rxdisperror),
    .rmlh_skp_parity_err            (rmlh_skp_parity_err),
    .rmlh_sync_header_err           (rmlh_sync_header_err),
    .rmlh_framing_err               (rmlh_framing_err),
    .rmlh_framing_err_l0            (rmlh_framing_err_l0),
    .rmlh_deskew_alignment_err      (rmlh_deskew_alignment_err),
    .rmlh_rxskipadded               (rmlh_rxskipadded),
    .rmlh_rxskipremoved             (rmlh_rxskipremoved),
    .rmlh_deskew_fifo_ptr           (rmlh_deskew_fifo_ptr),
    .rmlh_rxvalid_deasserted        (rmlh_rxvalid_deasserted),
    .rmlh_framing_err_ptr           (rmlh_framing_err_ptr),
    .smlh_eidle_inferred_in_l0      (smlh_eidle_inferred_in_l0),
    .smlh_rx_rcvry_req              (smlh_rx_rcvry_req),
    .smlh_timeout_nfts              (smlh_timeout_nfts),
    .smlh_l0_to_recovery            (smlh_l0_to_recovery),
    .smlh_l1_to_recovery            (smlh_l1_to_recovery ),
    .smlh_ltssm_variable            (smlh_ltssm_variable ),
    .ltssm_powerdown                (ltssm_powerdown),
    .latched_ts_nfts                (latched_ts_nfts),
    .smlh_ltssm_in_l0p              (smlh_ltssm_in_l0p),
    .smlh_link_in_training          (smlh_link_in_training),
    .smlh_in_l0s                    (smlh_in_l0s),
    .smlh_in_rl0s                   (smlh_in_rl0s),
    .smlh_rcv_eios_when_l0s_unsprt  (smlh_rcv_eios_when_l0s_unsprt),
    .smlh_deskew_uncomplete_err     (smlh_deskew_uncomplete_err),
    .cxl_almp_rx_repl_error         (vlsm_debug_info.pl_info.almp_repl_err),
    .cxl_vlsm_unexp_error           (vlsm_debug_info.pl_info.almp_unexp_err),
    .cxl_vlsm_lrsm_req_retrain      (cxl_vlsm_lrsm_req_retrain),
    .pm_asnak                       (pm_asnak),
    .l1sub_state                    (l1sub_state),
    .pm_in_l11                      (pm_in_l11),
    .pm_in_l12                      (pm_in_l12),
    .pm_in_l1_short                 (pm_in_l1_short),
    .pm_in_l1_cpm                   (pm_in_l1_cpm),
    .pm_in_l1_abort                 (pm_in_l1_abort),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_spd_change                (smlh_spd_change),
    .smlh_lwd_change                (smlh_lwd_change),
    .rdlh_bad_tlp_err_pertlp        (rdlh_bad_tlp_err_pertlp),
    .rdlh_lcrc_tlp_err_pertlp       (rdlh_lcrc_tlp_err_pertlp),
    .rdlh_nulified_tlp_err_pertlp   (rdlh_nulified_tlp_err_pertlp),
    .rdlh_duplicate_tlp_err_pertlp   (rdlh_duplicate_tlp_err_pertlp),
    .rdlh_bad_dllp_err_perdllp      (rdlh_bad_dllp_err_perdllp),
    .rdlh_rcvd_nack_perdllp         (rdlh_rcvd_nack_perdllp),
    .rdlh_rcvd_ack_perdllp          (rdlh_rcvd_ack_perdllp),
    .xdlh_nak_sent                  (xdlh_nak_sent),
    .xdlh_ack_sent                  (xdlh_ack_sent),
    .xdlh_update_fc_sent            (xdlh_update_fc_sent),
    .xadm_tx_nullify_evt            (xadm_tx_nullify_evt),
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
    .xtlh_tx_memwr_evt              (xtlh_tx_memwr_evt),
    .xtlh_tx_defmemwr_evt           (xtlh_tx_defmemwr_evt),
    .xtlh_tx_memrd_evt              (xtlh_tx_memrd_evt),
    .xtlh_tx_cfgwr_evt              (xtlh_tx_cfgwr_evt),
    .xtlh_tx_cfgrd_evt              (xtlh_tx_cfgrd_evt),
    .xtlh_tx_iowr_evt               (xtlh_tx_iowr_evt),
    .xtlh_tx_iord_evt               (xtlh_tx_iord_evt),
    .xtlh_tx_cplwod_evt             (xtlh_tx_cplwod_evt),
    .xtlh_tx_cplwd_evt              (xtlh_tx_cplwd_evt),
    .xtlh_tx_msg_evt                (xtlh_tx_msg_evt),
    .xtlh_tx_atmcop_evt             (xtlh_tx_atmcop_evt),
    .xtlh_tx_tlpwprefix_evt         (xtlh_tx_tlpwprefix_evt),
    .xtlh_tx_tlp_dpsize             (xtlh_tx_tlp_dpsize),
    .mac_phy_txelec_txburst         (mac_phy_txelec_txburst),
    .mac_phy_rxpolarity             (mac_phy_rxpolarity),
    .phy_mac_rxelec_rxh8exit        (phy_mac_rxelec_rxh8exit),
    .phy_mac_rxvalid_rxburst        (phy_mac_rxvalid_rxburst),
    .orig_pipe_rxdata               (orig_pipe_rxdata),
    .orig_pipe_rxdatak              (orig_pipe_rxdatak),
    .orig_pipe_rxdatavalid          (orig_pipe_rxdatavalid),
    .orig_pipe_rxstatus             (orig_pipe_rxstatus),
    .orig_pipe_rxstartblock         (orig_pipe_rxstartblock),
    .orig_pipe_rxsyncheader         (orig_pipe_rxsyncheader),
    .orig_pipe_blockaligncontrol    (pre_mac_phy_blockaligncontrol_o[0]),
    .latched_rxdetected             (pm_latched_rxdetected),
    .pm_pme_resend_flag             (pm_pme_resend_flag),
    .smlh_lane_reversed             (|smlh_lane_flip_ctrl),
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
    .mac_cdm_ras_des_txdeemph       (mac_phy_txdeemph),
    .mac_phy_rate                   (mac_phy_rate),
    .mac_phy_powerdown              (pm_int_phy_powerdown[1:0]),
    .mac_phy_txdetectrx_loopback    (mac_phy_txdetectrx_loopback),
    .mac_phy_rxeqeval               (mac_phy_rxeqeval),
      .phy_mac_phystatus              (phy_mac_phystatus_int),
    .phy_mac_dirfeedback            (phy_mac_dirfeedback),
    .phy_mac_fomfeedback            (phy_mac_fomfeedback),
    .smlh_rxos_type                 (smlh_rxos_type),
    .smseq_mcs_sts                  (smseq_mcs_sts),
    .smseq_ts_debug_info            (smseq_ts_debug_info),
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
    .xadm_fc_cnsmd_ph               (xadm_fc_cnsmd_ph),
    .xadm_fc_cnsmd_pd               (xadm_fc_cnsmd_pd),
    .xadm_fc_cnsmd_nph              (xadm_fc_cnsmd_nph),
    .xadm_fc_cnsmd_npd              (xadm_fc_cnsmd_npd),
    .xadm_fc_cnsmd_cplh             (xadm_fc_cnsmd_cplh),
    .xadm_fc_cnsmd_cpld             (xadm_fc_cnsmd_cpld),
    .xadm_fc_limit_ph               (xadm_fc_limit_ph),
    .xadm_fc_limit_pd               (xadm_fc_limit_pd),
    .xadm_fc_limit_nph              (xadm_fc_limit_nph),
    .xadm_fc_limit_npd              (xadm_fc_limit_npd),
    .xadm_fc_limit_cplh             (xadm_fc_limit_cplh),
    .xadm_fc_limit_cpld             (xadm_fc_limit_cpld),
    .rdlh_einj0_lcrc_evt            (rdlh_einj0_lcrc_evt),
    .radm_einj0_ecrc_evt            (radm_einj0_ecrc_evt),
    .xmlh_einj0_oscrc_evt           (xmlh_einj0_oscrc_evt),
    .xdlh_einj0_lcrc_evt            (xdlh_einj0_lcrc_evt),
    .xdlh_einj0_fcrc_evt            (xdlh_einj0_fcrc_evt),
    .xdlh_einj0_dllpcrc_evt         (xdlh_einj0_dllpcrc_evt),
    .xadm_einj0_ecrc_evt            (xadm_einj0_ecrc_evt),
    .ras_des_einj1_exp_sequm_evt    (ras_des_einj1_exp_sequm_evt),  
    .ras_des_einj1_ack_nak_sequm_evt(ras_des_einj1_ack_nak_sequm_evt),
    .xdlh_einj2_nak_evt             (xdlh_einj2_nak_evt),
    .xmlh_einj3_osmsk_evt           (xmlh_einj3_osmsk_evt),
    .rtlh_einj4_fc_evt              (rtlh_einj4_fc_evt),
    .xdlh_einj5_nultlp_evt          (xdlh_einj5_nultlp_evt),
    .xdlh_einj5_dup_evt             (xdlh_einj5_dup_evt),
    .xaim_einj6_tlp_evt             (xaim_einj6_tlp_evt),
    .radm_mlf_tlp_err_ptr           (radm_mlf_tlp_err_ptr),

    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l1                     (smlh_in_l1),

    .radm_ptm_req                   (radm_ptm_req),                    //input from RADM
    .radm_ptm_res_msg               (radm_ptm_res_msg),                   //input from RADM
    .radm_ptm_res_d_msg             (radm_ptm_res_d_msg),                         //input from RADM
    .radm_ptm_master_time           (radm_ptm_master_time),              //input from RADM
    .radm_ptm_prop_delay            (radm_ptm_prop_delay),
    .xdlh_ptm_sot                   (xdlh_ptm_sot),
    .xdlh_ptm_multi_cycle           (xdlh_ptm_multi_cycle),
    .xdlh_ptm_request               (xdlh_ptm_request),
    .xdlh_ptm_response              (xdlh_ptm_response),
    .xdlh_rbuf_replaying            (xdlh_rbuf_replaying),
    .rdlh_ptm_sot                   (rdlh_ptm_sot),
    .rdlh_ptm_request               (rdlh_ptm_request),
    .rdlh_ptm_multi_cycle           (rdlh_ptm_multi_cycle),
    .rdlh_ptm_response              (rdlh_ptm_response),
    .rdlh_duplicate_tlp             (rdlh_duplicate_tlp),
    .ptm_external_master_strobe     (ptm_external_master_strobe),
    .ptm_external_master_time       (ptm_external_master_time),
    .ptm_auto_update_signal         (ptm_auto_update_signal),
    .ptm_manual_update_pulse        (ptm_manual_update_pulse),
    .pm_linkst_in_l0                (pm_linkst_in_l0),
    .pm_linkst_in_l0s               (pm_linkst_in_l0s),
    .pm_sel_aux_clk                 (pm_sel_aux_clk),
    .aux_clk_active                 (aux_clk_active),
    .radm_snoop_upd                 (radm_snoop_upd),
    .radm_snoop_bus_num             (radm_snoop_bus_num),
    .radm_snoop_dev_num             (radm_snoop_dev_num),

    .prs_res_failure                (prs_res_failure),
    .prs_uprgi                      (prs_uprgi),
    .prs_stopped                    (prs_stopped),

    .app_clk_pm_en                  (app_clk_pm_en),


    .app_dev_num                    (app_dev_num),
    .app_bus_num                    (app_bus_num),
    .rplh_flit_logging_interface             (rplh_flit_logging_interface),
    .rmlh_flit_logging_interface             (rmlh_flit_logging_interface),
    .smlh_flit_logging_interface             (smlh_flit_logging_interface),
    .cfg_flit_log_trg_evnt_msi               (cfg_flit_log_trg_evnt_msi),
    .plh_cdm_flit_err_inj_status             (plh_cdm_flit_err_inj_status),
    .xmlh_tx_os_einj_status                  (xmlh_tx_os_einj_status),
    .xplh_cdm_flit_latency_tracking          (xplh_cdm_flit_latency_tracking),
    .cfg_flit_perf_interr_vec                (cfg_flit_perf_interr_vec),
    .pm_cdm_state_trans_tracking             (pm_cdm_state_trans_tracking),
    .pm_pclkack_timeout             (pm_pclkack_timeout),
    .rcrb_base_addr                           (rcrb_base_addr),
    .rcrb_base_addr_valid                     (rcrb_base_addr_valid),
    .ltssm_cxl_enable                         (int_ltssm_cxl_enable),
    .phy_ltssm_cxl_enable                     (phy_ltssm_cxl_enable),
    .correctable_protocol_id_frame_err        ( correctable_protocol_id_frame_err                   ),
    .uncorrectable_protocol_id_frame_err      ( uncorrectable_protocol_id_frame_err                 ),
    .unexpected_protocol_id_dropped           ( unexpected_protocol_id_dropped                      ),
    .viral_status                             ( viral_status                                        ),
    .pl_reg_viral_status_set                  ( pl_reg_viral_status_set                             ),
    .cxl_port_rcvd_mod_ts_data_phase1         ( cxl_port_rcvd_mod_ts_data_phase1                    ),
    .cxl_retimers_present_mismatched          ( cxl_retimers_present_mismatched                     ),
    .flexbusenablebits_phase2_mismatch        ( flexbusenablebits_phase2_mismatch                   ),
    .cxl_mode_enable                          ( cxl_protocol_cfg.cxl_mode_enable                    ),
    .cxl_dev_cache_invalid                    ( cxl_dev_cache_invalid                               ),
    .cxl_dev_cache_wr_invld_cmpl              ( cxl_dev_cache_wr_invld_cmpl                         ),
    .cxl_pm_init_cmpl                         ( cxl_pm_init_cmpl                                    ),
    .cxl_volatile_hdm_error                   ( cxl_volatile_hdm_error                              ),
    .mbar0_ras_unc_cache_data_parity          ( b_cxl_cdm.s_mbar0_ras_unc_cache_data_parity         ),
    .mbar0_ras_unc_cache_addr_parity          ( b_cxl_cdm.s_mbar0_ras_unc_cache_addr_parity         ),
    .mbar0_ras_unc_cache_be_parity            ( b_cxl_cdm.s_mbar0_ras_unc_cache_be_parity           ),
    .mbar0_ras_unc_cache_data_ecc             ( b_cxl_cdm.s_mbar0_ras_unc_cache_data_ecc            ),
    .mbar0_ras_unc_mem_data_parity            ( b_cxl_cdm.s_mbar0_ras_unc_mem_data_parity           ),
    .mbar0_ras_unc_mem_addr_parity            ( b_cxl_cdm.s_mbar0_ras_unc_mem_addr_parity           ),
    .mbar0_ras_unc_mem_be_parity              ( b_cxl_cdm.s_mbar0_ras_unc_mem_be_parity             ),
    .mbar0_ras_unc_mem_data_ecc               ( b_cxl_cdm.s_mbar0_ras_unc_mem_data_ecc              ),
    .mbar0_ras_unc_reinit_threshold           ( b_cxl_cdm.s_mbar0_ras_unc_reinit_threshold          ),
    .mbar0_ras_unc_rsvd_encoding_violation    ( b_cxl_cdm.s_mbar0_ras_unc_rsvd_encoding_violation   ),
    .mbar0_ras_unc_poison_received            ( b_cxl_cdm.s_mbar0_ras_unc_poison_received           ),
    .mbar0_ras_unc_receiver_overflow          ( b_cxl_cdm.s_mbar0_ras_unc_receiver_overflow         ),
    .mbar0_ras_unc_internal_error             ( b_cxl_cdm.s_mbar0_ras_unc_internal_error            ),
    .mbar0_ras_unc_cxl_ide_tx_error           ( b_cxl_cdm.s_mbar0_ras_unc_cxl_ide_tx_error          ),
    .mbar0_ras_unc_cxl_ide_rx_error           ( b_cxl_cdm.s_mbar0_ras_unc_cxl_ide_rx_error          ),
    .mbar0_ras_corr_cache_data_ecc            ( b_cxl_cdm.s_mbar0_ras_corr_cache_data_ecc           ),
    .mbar0_ras_corr_mem_data_ecc              ( b_cxl_cdm.s_mbar0_ras_corr_mem_data_ecc             ),
    .mbar0_ras_corr_crc_threshold             ( b_cxl_cdm.s_mbar0_ras_corr_crc_threshold            ),
    .mbar0_ras_corr_retry_threshold           ( b_cxl_cdm.s_mbar0_ras_corr_retry_threshold          ),
    .mbar0_ras_corr_cache_poison_received     ( b_cxl_cdm.s_mbar0_ras_corr_cache_poison_received    ),
    .mbar0_ras_corr_mem_poison_received       ( b_cxl_cdm.s_mbar0_ras_corr_mem_poison_received      ),
    .mbar0_ras_corr_physical_layer_error      ( b_cxl_cdm.s_mbar0_ras_corr_physical_layer_error     ),
    .mbar0_ras_header_log_reg0                ( b_cxl_cdm.s_mbar0_ras_header_log_reg0               ),
    .mbar0_ras_header_log_reg1                ( b_cxl_cdm.s_mbar0_ras_header_log_reg1               ),
    .mbar0_ras_header_log_reg2                ( b_cxl_cdm.s_mbar0_ras_header_log_reg2               ),
    .mbar0_ras_header_log_reg3                ( b_cxl_cdm.s_mbar0_ras_header_log_reg3               ),
    .mbar0_ras_header_log_reg4                ( b_cxl_cdm.s_mbar0_ras_header_log_reg4               ),
    .mbar0_ras_header_log_reg5                ( b_cxl_cdm.s_mbar0_ras_header_log_reg5               ),
    .mbar0_ras_header_log_reg6                ( b_cxl_cdm.s_mbar0_ras_header_log_reg6               ),
    .mbar0_ras_header_log_reg7                ( b_cxl_cdm.s_mbar0_ras_header_log_reg7               ),
    .mbar0_ras_header_log_reg8                ( b_cxl_cdm.s_mbar0_ras_header_log_reg8               ),
    .mbar0_ras_header_log_reg9                ( b_cxl_cdm.s_mbar0_ras_header_log_reg9               ),
    .mbar0_ras_header_log_reg10               ( b_cxl_cdm.s_mbar0_ras_header_log_reg10              ),
    .mbar0_ras_header_log_reg11               ( b_cxl_cdm.s_mbar0_ras_header_log_reg11              ),
    .mbar0_ras_header_log_reg12               ( b_cxl_cdm.s_mbar0_ras_header_log_reg12              ),
    .mbar0_ras_header_log_reg13               ( b_cxl_cdm.s_mbar0_ras_header_log_reg13              ),
    .mbar0_ras_header_log_reg14               ( b_cxl_cdm.s_mbar0_ras_header_log_reg14              ),
    .mbar0_ras_header_log_reg15               ( b_cxl_cdm.s_mbar0_ras_header_log_reg15              ),
//------------------------------------------------
// Inputs to u_cdm_pl_reg
//------------------------------------------------
    .cxl_pl_reg_vlsm_state                               ( vlsm_debug_info.pl_info.pl_state_sts                   ),
    .cxl_pl_reg_cache_mem_vlsm_state                     ( vlsm_debug_info.pl_info.mc_state_sts                   ),
    .cxl_pl_reg_io_vlsm_state                            ( vlsm_debug_info.pl_info.io_state_sts                   ),
    .cxl_pl_reg_mc_almp_unexp_error                      ( vlsm_debug_info.mc_almp.almp_unexp_info                ),
    .cxl_pl_reg_io_almp_unexp_error                      ( vlsm_debug_info.io_almp.almp_unexp_info                ),
    .cxl_pl_reg_lrsm_state                               ( b_cxl_cdm.s_pl_reg_lrsm_state                          ),
    .cxl_pl_reg_lrsm_fatal_error                         ( b_cxl_cdm.s_pl_reg_lrsm_fatal_error                    ),
    .cxl_pl_reg_fatal_error                              ( b_cxl_cdm.s_pl_reg_fatal_error                         ),
    .cxl_pl_reg_cm_ll_cache_poison_injection_busy        ( b_cxl_cdm.s_pl_reg_cm_ll_cache_poison_injection_busy   ),
    .cxl_pl_reg_cm_ll_mem_poison_injection_busy          ( b_cxl_cdm.s_pl_reg_cm_ll_mem_poison_injection_busy     ),
    .cxl_pl_reg_cm_ll_io_poison_injection_busy           ( 1'b0 /* Error Injection Not Implemented             */ ),
    .cxl_pl_reg_cm_ll_cache_mem_crc_injection_busy       ( b_cxl_cdm.s_pl_reg_cm_ll_cache_mem_crc_injection_busy  ),
    .cxl_pl_reg_io_ll_io_poison_injection_busy           ( 1'b0 /* Error Injection Not Implemented             */ ),
    .cxl_pl_reg_io_ll_flow_ctrl_error_injection_busy     ( 1'b0 /* Error Injection Not Implemented             */ ),
    .cxl_pl_reg_fb_phy_protid_injection_busy             ( 1'b0 /* Error Injection Not Implemented             */ ),
    .flit_mode_enable                                    (smlh_flit_mode_enable),
      .app_segment_id                                    (app_segment_id),
      .radm_np_segment_id                                (radm_np_segment_id),
    .cfg_segment_id                                      (cfg_segment_id_int),

    // -------------------------------- outputs -------------------------------------------------
    .msggen_cdm_send_f_err                               (msggen_cdm_send_f_err),
    .msggen_cdm_send_nf_err                              (msggen_cdm_send_nf_err),
    .pm_usp_prot_state              (pm_usp_prot_state),
    .pm_usp_link_state              (pm_usp_link_state),
    .pm_dsp_prot_state              (pm_dsp_prot_state),
    .pm_dsp_link_state              (pm_dsp_link_state),
    .pm_l0s_state                   (pm_l0s_state),
    .rmlh_prbs_done                  (rmlh_prbs_done),
    .rmlh_prbs_fail                  (rmlh_prbs_fail),
    .rmlh_prbs_started               (rmlh_prbs_started),
    .rmlh_prbs_err_cntr              (rmlh_prbs_err_cntr),
    .rmlh_prbs_unexp_fail            (rmlh_prbs_unexp_fail),
// -------------------------------- outputs -------------------------------------------------
    //
    .cdm_plh_flit_err_inj_interface          (cdm_plh_flit_err_inj_interface),
    .cfg_os_einj_ctrl_1                      (cfg_os_einj_ctrl_1),
    .cfg_os_einj_ctrl_2                      (cfg_os_einj_ctrl_2),
    .cdm_xplh_flit_response_type             (cdm_xplh_flit_response_type),
    .cdm_xplh_flit_type_measured             (cdm_xplh_flit_type_measured),
    .cdm_xplh_flit_track_mode                (cdm_xplh_flit_track_mode),
    .cfg_flit_latency_msi                    (cfg_flit_latency_msi),
    .cdm_pm_state_trans_tracker              (cdm_pm_state_trans_tracker),
    .cfg_sts_1_ltssm_latency_msi             (cfg_sts_1_ltssm_latency_msi),


    .cfg_acs_validation_cap                      (cfg_acs_validation_cap),
    .cfg_acs_at_blocking_cap                     (cfg_acs_at_blocking_cap),
    .cfg_acs_up_forward_cap                      (cfg_acs_up_forward_cap),
    .cfg_acs_validation_en                       (cfg_acs_validation_en),
    .cfg_acs_at_blocking_en                      (cfg_acs_at_blocking_en),
    .cfg_acs_p2p_req_redirect_en                 (cfg_acs_p2p_req_redirect_en),
    .cfg_acs_p2p_compl_redirect_en               (cfg_acs_p2p_compl_redirect_en),
    .cfg_acs_up_forward_en                       (cfg_acs_up_forward_en),
    .cfg_acs_p2p_egress_ctrl_en                  (cfg_acs_p2p_egress_ctrl_en),
    .cfg_acs_p2p_direct_transl_en                (cfg_acs_p2p_direct_transl_en),
    .cfg_acs_egress_ctrl_vec                     (cfg_acs_egress_ctrl_vec),
    .cfg_upd_aspm_ctrl              (cfg_upd_aspm_ctrl),
    .cfg_aspm_l1_timer_enable       (cfg_aspm_l1_timer_enable),
    .cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl),
    .cfg_upd_pme_cap                (cfg_upd_pme_cap),
    .cfg_mem_match                  (cfg_mem_match),
    .cfg_prefmem_match              (cfg_prefmem_match),
    .rcrb_mbar0_base_addr           (rcrb_mbar0_base_addr),
    .cfg_rcrb_match                 (cfg_rcrb_match),
    .cfg_rcrb_mbar0_match           (cfg_rcrb_mbar0_match),
    .cfg_rcrb_mbar0_match_int       (cfg_rcrb_mbar0_match_int),
    .rcrb_address_reg               (rcrb_address_reg),
    .cfg_cxl_2_0_mbar0_match                (cfg_cxl_2_0_mbar0_match),
    .cxl_2_0_mbar0_access_match             (cxl_2_0_mbar0_access_int),
    .cfg_cxl_alt_mem_match                  (cfg_cxl_alt_mem_match),
    .cfg_cxl_alt_prefmem_match              (cfg_cxl_alt_prefmem_match),
    .cfg_config_above_match         (cfg_config_above_match),
    .cfg_io_match                   (cfg_io_match),
    .cfg_bar_match                  (cfg_bar_match),
    .cfg_bar_is_io                  (cfg_bar_is_io),
    .cfg_rom_match                  (cfg_rom_match),
    .cfg_l1sub_control              (cfg_l1sub_control),
    .cfg_l1sub_en                   (cfg_l1sub_en),
    .cfg_pl_l1sub_control           (cfg_pl_l1sub_control),
    .cfg_pl_l1_exit_mode            (cfg_pl_l1_exit_mode),
    .cfg_pl_l1_nowait_p1            (cfg_pl_l1_nowait_p1),
    .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
    .cfg_p2nobeacon_enable          (cfg_p2nobeacon_enable),
    .cfg_utility                    (cfg_utility),
    .pm_cfg_utility                 (pm_cfg_utility),
    .cfg_pipe_optional_pclkchange_hs(cfg_pipe_optional_pclkchange_hs),
    .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
    .cfg_phy_rst_timer              (cfg_phy_rst_timer),
    .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
    .cfg_dsp_pcipm_l1_enter_delay   (cfg_dsp_pcipm_l1_enter_delay),
    .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
    .cfg_filter_rule_mask           (cfg_filter_rule_mask),

    .cdm_lbc_data                   (cdm_lbc_data),
    .cdm_lbc_ack                    (cdm_lbc_ack),

    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_2ndbus_num                 (cfg_2ndbus_num),
    .cfg_subbus_num                 (cfg_subbus_num),
    .cfg_aslk_pmctrl                (cfg_aslk_pmctrl),
    .cfg_clk_pm_en                  (cfg_clk_pm_en_tmp),

    .cfg_relax_ord_en               (cfg_relax_order_en),
    .cfg_no_snoop_en                (cfg_no_snoop_en),

    .cfg_ext_tag_en                 (cfg_ext_tag_en),
    .cfg_phantom_fun_en             (),
    .cfg_aux_pm_en                  (cfg_aux_pm_en),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size),
    .cfg_bridge_crs_en              (),
    .cfg_rcb                        (cfg_rcb),
    .cfg_comm_clk_config            (cfg_comm_clk_config),
    .cfg_hw_autowidth_dis           (cfg_hw_autowidth_dis),
    .cfg_max_payload_size           (cfg_max_payload_size),
    .cfg_highest_max_payload        (cfg_highest_max_payload),
// In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
    .cfg_max_payload_size_out_rx    (cfg_max_payload_size_out_rx),
    .cfg_ack_freq                   (cfg_ack_freq),
    .cfg_ack_latency_timer          (cfg_ack_latency_timer),
    .cfg_replay_timer_value         (cfg_replay_timer_value),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .cfg_other_msg_payload          (cfg_other_msg_payload),
    .cfg_other_msg_request          (cfg_other_msg_request),
    .cfg_corrupt_crc_pattern        (cfg_corrupt_crc_pattern),
    .cfg_scramble_dis               (cfg_scramble_dis),
    .cfg_n_fts                      (cfg_n_fts),
    .cfg_link_dis                   (cfg_link_dis),
    .cfg_link_retrain               (cfg_link_retrain),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_pipe_loopback              (cfg_pipe_loopback),
    .cfg_rxstatus_lane              (cfg_rxstatus_lane),
    .cfg_rxstatus_value             (cfg_rxstatus_value),
    .cfg_lpbk_rxvalid               (cfg_lpbk_rxvalid),
    .cfg_plreg_reset                (cfg_plreg_reset),
    .cfg_link_num                   (cfg_link_num),
    .cfg_support_part_lanes_rxei_exit (cfg_support_part_lanes_rxei_exit),
    .cfg_ts2_lid_deskew             (cfg_ts2_lid_deskew),
    .cfg_forced_link_state          (cfg_forced_link_state),
    .cfg_forced_ltssm_cmd           (cfg_forced_ltssm_cmd),

    .cfg_force_en                   (cfg_force_en),
    .cfg_lane_skew                  (cfg_lane_skew),
    .cfg_drift_buffer_deskew_enable (cfg_drift_buffer_deskew_enable),
    .cfg_deskew_disable             (cfg_deskew_disable),
    .cfg_imp_num_lanes              (cfg_imp_num_lanes),
    .cfg_elastic_buffer_mode        (cfg_elastic_buffer_mode_i),
    .cfg_flow_control_disable       (cfg_flow_control_disable),
    .cfg_acknack_disable            (cfg_acknack_disable),
    .cfg_link_capable               (cfg_link_capable),
    .cfg_eidle_timer                (),
    .cfg_skip_interval              (cfg_skip_interval),
    .cfg_link_rate                  (),
    .cfg_retimers_pre_detected      (cfg_retimers_pre_detected),
    .cfg_fast_link_mode             (int_cfg_fast_link_mode),
    .cfg_fast_link_scaling_factor   (cfg_fast_link_scaling_factor),
    .cfg_l0s_supported              (cfg_l0s_supported),
    .cfg_dll_lnk_en                 (cfg_dll_lnk_en),
    .cfg_soft_rst_n                 (),
    .cfg_2nd_reset                  (cfg_2nd_reset),
    .cfg_ecrc_gen_en                (cfg_ecrc_gen_en),
    .cfg_ecrc_chk_en                (cfg_ecrc_chk_en),
    .cfg_bar0_start                 (cfg_bar0_start),
    .cfg_bar0_limit                 (cfg_bar0_limit),
    .cfg_bar0_mask                  (cfg_bar0_mask),
    .cfg_bar1_start                 (cfg_bar1_start),
    .cfg_bar1_limit                 (cfg_bar1_limit),
    .cfg_bar1_mask                  (cfg_bar1_mask),
    .cfg_bar2_start                 (cfg_bar2_start),
    .cfg_bar2_limit                 (cfg_bar2_limit),
    .cfg_bar2_mask                  (cfg_bar2_mask),
    .cfg_bar3_start                 (cfg_bar3_start),
    .cfg_bar3_limit                 (cfg_bar3_limit),
    .cfg_bar3_mask                  (cfg_bar3_mask),
    .cfg_bar4_start                 (cfg_bar4_start),
    .cfg_bar4_limit                 (cfg_bar4_limit),
    .cfg_bar4_mask                  (cfg_bar4_mask),
    .cfg_bar5_start                 (cfg_bar5_start),
    .cfg_bar5_limit                 (cfg_bar5_limit),
    .cfg_bar5_mask                  (cfg_bar5_mask),
    .cfg_rom_mask                   (cfg_rom_mask),
    .cfg_mem_base                   (),
    .cfg_mem_limit                  (),
    .cfg_pref_mem_base              (),
    .cfg_pref_mem_limit             (),
    .cfg_exp_rom_start              (cfg_exp_rom_start),
    .cfg_exp_rom_limit              (cfg_exp_rom_limit),
    .cfg_io_limit_upper16           (cfg_io_limit_upper16),
    .cfg_io_base_upper16            (cfg_io_base_upper16),
    .cfg_io_base                    (cfg_io_base),
    .cfg_io_limit                   (cfg_io_limit),
    .cfg_hdr_type                   (),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_io_space_en                (cfg_io_space_en),
    .cfg_mem_space_en               (cfg_mem_space_en),
    .cfg_phy_control                (cfg_phy_control),
    .upstream_port                  (upstream_port),
    .switch_device                  (),
    .end_device                     (end_device),
    .rc_device                      (rc_device),
    .bridge_device                  (bridge_device),
    .cfg_upd_req_id                 (cfg_upd_req_id),
    .cfg_upd_pmcsr                  (cfg_upd_pmcsr),
    .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr),
    .cfg_pmstate                    (cfg_pmstate),
    .cfg_pme_en                     (cfg_pme_en),
    .cfg_pm_no_soft_rst             (cfg_pm_no_soft_rst),
    .cfg_bus_master_en              (cfg_bus_master_en),
    .cfg_err_resp                   (cfg_err_resp),
    .cfg_auto_flush_en              (int_cfg_auto_flush_en),
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
    .cfg_aximstr_msg_addr_high      (cfg_aximstr_msg_addr_high),
    .cfg_aximstr_msg_addr_low       (cfg_aximstr_msg_addr_low),
    .cfg_mstr_ardomain_mode         (cfg_mstr_ardomain_mode),
    .cfg_mstr_awdomain_mode         (cfg_mstr_awdomain_mode),
    .cfg_mstr_ardomain_value        (cfg_mstr_ardomain_value),
    .cfg_mstr_awdomain_value        (cfg_mstr_awdomain_value),
    .cfg_ax_mstr_zeroread_fw        (cfg_ax_mstr_zeroread_fw),
    .cfg_memtype_value              (cfg_memtype_value),
    .cfg_memtype_boundary           (cfg_memtype_boundary),
// ATU outbound Region controls
    .atu_reg_out_type               (atu_reg_out_type),
    .atu_reg_out_tc                 (atu_reg_out_tc),
    .atu_reg_out_td                 (),                      // outbound TD field is deprecated.
    .atu_reg_out_attr               (atu_reg_out_attr),
    .atu_reg_out_at                 (atu_reg_out_at),
    .atu_reg_out_func_num           (atu_reg_out_func_num),
    .atu_reg_out_func_bypass        (atu_reg_out_func_bypass),
    .atu_reg_out_snp                (atu_reg_out_snp),
    .atu_reg_out_dma_bypass         (atu_reg_out_dma_bypass),
    .atu_reg_out_inhibit_payload    (atu_reg_out_inhibit_payload),
    .atu_reg_out_hdr_substitute_en  (atu_reg_out_hdr_substitute_en),
    .atu_reg_out_tag_substitute_en  (atu_reg_out_tag_substitute_en),
    .atu_reg_out_tag                (atu_reg_out_tag),
    .atu_reg_out_msg_code           (atu_reg_out_msg_code),
    .atu_reg_out_th                 (atu_reg_out_th),
    .atu_reg_out_ph                 (atu_reg_out_ph),
    .atu_reg_out_st                 (atu_reg_out_st),

// Mode Settings
    .atu_reg_out_shift              (atu_reg_out_shift),
    .atu_reg_out_invert             (atu_reg_out_invert),
// Region Enable
    .atu_reg_out_en                 (atu_reg_out_en),
// Base, Limit and Target Registers
    .atu_reg_out_base               (atu_reg_out_base),
    .atu_reg_out_upr_base           (atu_reg_out_upr_base),
    .atu_reg_out_limit              (atu_reg_out_limit),
    .atu_reg_out_uppr_limit         (atu_reg_out_uppr_limit),
    .atu_reg_out_lwr_trgt           (atu_reg_out_lwr_trgt),
    .atu_reg_out_upr_trgt           (atu_reg_out_upr_trgt),
    .atu_reg_out_lwr_trgt_lwr       (atu_reg_out_lwr_trgt_lwr),
    .atu_reg_out_incr_rgn_size      (atu_reg_out_incr_rgn_size),
    .atu_reg_out_hdr_flds_bypass    (atu_reg_out_hdr_flds_bypass),

// ATU inbound Region controls
    .atu_reg_in_type                (atu_reg_in_type),
    .atu_reg_in_tc                  (atu_reg_in_tc),
    .atu_reg_in_td                  (atu_reg_in_td),
    .atu_reg_in_attr                (atu_reg_in_attr),
    .atu_reg_in_at                  (atu_reg_in_at),
    .atu_reg_in_func_num            (atu_reg_in_func_num),
    .atu_reg_in_msg_code            (atu_reg_in_msg_code),
    .atu_reg_in_bar_num             (atu_reg_in_bar_num),
    .atu_reg_in_th                  (atu_reg_in_th),
    .atu_reg_in_ph                  (atu_reg_in_ph),
    .atu_reg_in_st                  (atu_reg_in_st),
// Inbound field match enables
    .atu_reg_in_tc_match_en         (atu_reg_in_tc_match_en),
    .atu_reg_in_td_match_en         (atu_reg_in_td_match_en),
    .atu_reg_in_attr_match_en       (atu_reg_in_attr_match_en),
    .atu_reg_in_at_match_en         (atu_reg_in_at_match_en),
    .atu_reg_in_func_match_en       (atu_reg_in_func_match_en),
    .atu_reg_in_msgcode_match_en    (atu_reg_in_msgcode_match_en),
    .atu_reg_in_th_match_en         (atu_reg_in_th_match_en),
    .atu_reg_in_ph_match_en         (atu_reg_in_ph_match_en),
    .atu_reg_in_st_match_en         (atu_reg_in_st_match_en),
    .atu_reg_in_single_addr_loc_en  (atu_reg_in_single_addr_loc_en),
    .atu_reg_in_msg_type_match_mode  (atu_reg_in_msg_type_match_mode),
// Response and mode settings
    .atu_reg_in_rsp_code            (atu_reg_in_rsp_code),
    .atu_reg_in_fuzzy               (atu_reg_in_fuzzy),
    .atu_reg_in_shift               (atu_reg_in_shift),
    .atu_reg_in_invert              (atu_reg_in_invert),
    .atu_reg_in_bar_match           (atu_reg_in_bar_match),
// Region Enable
    .atu_reg_in_en                  (atu_reg_in_en),
// Base, Limit and Target Registers
    .atu_reg_in_base                (atu_reg_in_base),
    .atu_reg_in_upr_base            (atu_reg_in_upr_base),
    .atu_reg_in_limit               (atu_reg_in_limit),
     .atu_reg_in_cbuf_incr          (atu_reg_in_cbuf_incr),
     .atu_reg_in_cbuf_restart       (atu_reg_in_cbuf_restart),
    .atu_reg_in_uppr_limit          (atu_reg_in_uppr_limit),
    .atu_reg_in_lwr_trgt            (atu_reg_in_lwr_trgt),
    .atu_reg_in_upr_trgt            (atu_reg_in_upr_trgt),
    .atu_reg_in_incr_rgn_size       (atu_reg_in_incr_rgn_size),
    .cfg_reg_serren                 (cfg_reg_serren),
    .cfg_cor_err_rpt_en             (cfg_cor_err_rpt_en),
    .cfg_nf_err_rpt_en              (cfg_nf_err_rpt_en),
    .cfg_f_err_rpt_en               (cfg_f_err_rpt_en),
    .cfg_pme_cap                    (cfg_pme_cap),
    .cfg_l0s_entr_latency_timer     (cfg_l0s_entr_latency_timer),
    .cfg_l1_entr_latency_timer      (cfg_l1_entr_latency_timer),
    .cfg_l1_entr_wo_rl0s            (cfg_l1_entr_wo_rl0s),
    .cfg_isa_enable                 (),
    .cfg_vga_enable                 (),
    .cfg_vga16_decode               (),
    .cfg_send_cor_err               (cfg_send_cor_err),
    .cfg_send_nf_err                (cfg_send_nf_err),
    .cfg_send_f_err                 (cfg_send_f_err),
    .cfg_func_spec_err              (cfg_func_spec_err),
    .cfg_sys_err_rc                 (cfg_sys_err_rc),
    .cfg_aer_rc_err_int             (cfg_aer_rc_err_int),
    .cfg_aer_rc_err_msi             (cfg_aer_rc_err_msi),
    .cfg_aer_int_msg_num            (cfg_aer_int_msg_num),
    .cfg_pme_int                    (cfg_pme_int),
    .cfg_pme_msi                    (cfg_pme_msi),
    .cfg_crs_sw_vis_en              (cfg_crs_sw_vis_en),
    .cfg_pcie_cap_int_msg_num       (cfg_pcie_cap_int_msg_num),
    .cfg_ari_fwd_en                 (cfg_ari_fwd_en),
    .cfg_cpl_timeout_range          (cfg_cpl_timeout_range),
    .cfg_cpl_timeout_disable        (cfg_cpl_timeout_disable),
    .cfg_atomic_req_en              (cfg_atomic_req_en),
    .cfg_atomic_egress_block        (cfg_atomic_egress_block),
    .cfg_dmwr_req_en                (cfg_dmwr_req_en),
    .cfg_tx_arb_control             (cfg_tx_arb_control),
    .smlh_l0p_capable               (smlh_l0p_capable),
    .cfg_l0p_receiver_support       (cfg_l0p_receiver_support),
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
    .cfg_cxl_l0p_disable            (cfg_cxl_l0p_disable),
    .cfg_cxl_l0p_request            (cfg_cxl_l0p_request),
    .cfg_cxl_l0p_priority           (cfg_cxl_l0p_priority),
    .cfg_cxl_l0p_linkmode           (cfg_cxl_l0p_linkmode),
    .cfg_flit_err_inj_latency       (cfg_flit_err_inj_latency),
    .cfg_obff_en                    (cfg_obff_en),
    .cfg_ltr_m_en                   (cfg_ltr_m_en),
    .cfg_ltr_max_latency            (cfg_ltr_max_latency),
    .cfg_disable_ltr_clr_msg        (cfg_disable_ltr_clr_msg),
    .app_ltr_latency                (app_ltr_latency),
    .cdm2msgg_ltr_clr_msg_req       (cdm2msgg_ltr_clr_msg_req),
    .cfg_lane_en                    (cfg_lane_en),
    .cfg_gen1_ei_inference_mode     (cfg_gen1_ei_inference_mode),
    .cfg_select_deemph_mux_bus      (cfg_select_deemph_mux_bus),
    .cfg_lut_ctrl                   (cfg_lut_ctrl),
    .cfg_rxstandby_control          (cfg_rxstandby_control),
    .cfg_link_auto_bw_int           (cfg_link_auto_bw_int),
    .cfg_bw_mgt_int                 (cfg_bw_mgt_int),
    .cfg_link_auto_bw_msi           (cfg_link_auto_bw_msi),
    .cfg_bw_mgt_msi                 (cfg_bw_mgt_msi),
    .cfg_gen2_n_fts                 (cfg_gen2_n_fts),
    .cfg_directed_speed_change      (cfg_directed_speed_change),
    .cfg_phy_txswing                (cfg_phy_txswing),
    .cfg_tx_compliance_rcv          (cfg_tx_compliance_rcv),
    .cfg_pcie_max_link_speed        (cfg_pcie_max_link_speed_cdm),
    .cfg_target_link_speed          (cfg_target_link_speed_cdm),
    .cfg_enter_compliance           (cfg_enter_compliance),
    .cfg_hw_auto_sp_dis             (cfg_hw_auto_sp_dis),
    .cfg_sel_de_emphasis            (cfg_sel_de_emphasis),
    .cfg_transmit_margin            (cfg_transmit_margin),
    .cfg_enter_mod_compliance       (cfg_enter_mod_compliance),
    .cfg_compliance_sos             (cfg_compliance_sos),
    .cfg_compliance_de_emphasis     (cfg_compliance_de_emphasis),
    .cfg_pwr_ind                    (cfg_pwr_ind),
    .cfg_atten_ind                  (cfg_atten_ind),
    .cfg_pwr_ctrler_ctrl            (cfg_pwr_ctrler_ctrl),
    .cfg_eml_control                (cfg_eml_control),
    .cfg_slot_pwr_limit_wr          (cfg_slot_pwr_limit_wr),
    .cfg_int_disable                (cfg_int_disable),
    .cfg_msi_addr                   (cfg_msi_addr),
    .cfg_msi_data                   (cfg_msi_data),
    .cfg_msi_64                     (cfg_msi_64),
    .cfg_msi_en                     (cfg_msi_en),
    .cfg_multi_msi_en               (cfg_multi_msi_en),
    .cfg_msi_ext_data_en            (cfg_msi_ext_data_en),
    .cfg_msix_en                    (cfg_msix_en),
    .cfg_msix_func_mask             (cfg_msix_func_mask),
    .ras_dp_err_log                 (ras_dp_err_log_to_cdm),
    .ras_dp_err_inj                 (ras_dp_err_inj_from_cdm),
    .ras_dp_err_inj_wake_up         (ras_dp_err_inj_wake_up),
    .ras_error_tracer_pending       (ras_error_tracer_pending),
    .ras_dp_unc_err                 (ras_dp_unc_err),
    .ras_dp_cor_err                 (ras_dp_cor_err),
    .ras_ram_unc_err                (ras_ram_unc_err),
    .ras_ram_cor_err                (ras_ram_cor_err),
    .cfg_pwr_budget_data_sel_reg    (cfg_pwr_budget_data_sel_reg),
    .cfg_pwr_budget_sel             (cfg_pwr_budget_sel),
    .set_slot_pwr_limit_val         (cfg_slot_pwr_limit_val),
    .set_slot_pwr_limit_scale       (cfg_slot_pwr_limit_scale),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .cfg_tc_enable                  (cfg_tc_enable),
    .cfg_tc_vc_map                  (cfg_tc_vc_map),
    .cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map),
    .cfg_lpvc                       (cfg_lpvc),
    .cfg_vc_arb_sel                 (cfg_vc_arb_sel),
    .cfg_lpvc_wrr_weight            (int_cfg_lpvc_wrr_weight),
    .cfg_max_func_num               (cfg_max_func_num),
    .cfg_trgt_cpl_lut_delete_entry  (cfg_trgt_cpl_lut_delete_entry),
    .cfg_clock_gating_ctrl          (cfg_clock_gating_ctrl),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .cfg_radm_q_mode                (cfg_radm_q_mode),
    .cfg_radm_order_rule            (cfg_radm_order_rule),
    .cfg_order_rule_ctrl            (cfg_order_rule_ctrl),
    .cfg_radm_strict_vc_prior       (cfg_radm_strict_vc_prior),
    .cfg_hq_depths                  (cfg_hq_depths),
    .cfg_dq_depths                  (cfg_dq_depths),
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
    .target_mem_map                 (target_mem_map),
    .target_rom_map                 (target_rom_map),
    .inta_wire                      (inta_wire),
    .intb_wire                      (intb_wire),
    .intc_wire                      (intc_wire),
    .intd_wire                      (intd_wire),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_pl_multilane_control       (cfg_pl_multilane_control)
    ,
    .cfg_link_eq_req_int            (cfg_link_eq_req_int),
    .cfg_pl_gen3_control            (cfg_pl_gen3_control),
    .cfg_pl_gen3_eq_control         (cfg_pl_gen3_eq_control),
    .cfg_no_seed_value_change       (cfg_no_seed_value_change),
    .cfg_fdbk_dirchange_control     (cfg_fdbk_dirchange_control),
    .cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl),
    .cfg_perform_eq                 (cfg_perform_eq),
    .cfg_lec_pset_ltx               (int_cfg_lec_pset_ltx),
    .cfg_lec_pset_lrx               (int_cfg_lec_pset_lrx),
    .cfg_lec_pset_rtx               (int_cfg_lec_pset_rtx),
    .cfg_lec_pset_rrx               (int_cfg_lec_pset_rrx),
    .cfg_ls2_eq_req                 (cfg_ls2_eq_req)
    ,
    .cfg_pl_gen4_control            (cfg_pl_gen4_control),
    .cfg_pl_gen4_eq_control         (cfg_pl_gen4_eq_control),
    .cfg_gen4_fdbk_dirchange_control(cfg_gen4_fdbk_dirchange_control),
    .cfg_lec_g4_pset_ltx            (int_cfg_lec_g4_pset_ltx),
    .cfg_lec_g4_pset_lrx            (cfg_lec_g4_pset_lrx),
    .cfg_lec_g4_pset_rtx            (int_cfg_lec_g4_pset_rtx),
    .cfg_lec_g4_pset_rrx            (cfg_lec_g4_pset_rrx),

    .cfg_margin_control             (int_cfg_margin_control)
    ,
    .cfg_pl_gen5_control            (cfg_pl_gen5_control),
    .cfg_pl_gen5_eq_control         (cfg_pl_gen5_eq_control),
    .cfg_gen5_fdbk_dirchange_control(cfg_gen5_fdbk_dirchange_control),
    .cfg_bypass_eq_enable           (cfg_bypass_eq_enable),   // Bypass EQ
    .cfg_no_eq_needed_enable        (cfg_no_eq_needed_enable),// no eq needed
    .cfg_tx_precode_req             (cfg_tx_precode_req),// Transmitted Precode Request
    .cfg_lec_g5_pset_ltx            (int_cfg_lec_g5_pset_ltx),
    .cfg_lec_g5_pset_lrx            (cfg_lec_g5_pset_lrx),
    .cfg_lec_g5_pset_rtx            (int_cfg_lec_g5_pset_rtx),
    .cfg_lec_g5_pset_rrx            (cfg_lec_g5_pset_rrx)
    ,
    .cfg_pl_gen6_control            (cfg_pl_gen6_control),
    .cfg_pl_gen6_eq_control         (cfg_pl_gen6_eq_control),
    .cfg_g6_tx_precode_req          (cfg_g6_tx_precode_req)// Transmitted Precode Request
    ,
    .cfg_gen6_fdbk_dirchange_control(cfg_gen6_fdbk_dirchange_control)
    ,
    .cfg_lec_g6_pset_ltx            (int_cfg_lec_g6_pset_ltx),
    .cfg_lec_g6_pset_rtx            (int_cfg_lec_g6_pset_rtx)
    ,
    .cfg_alt_protocol_enable        (cfg_alt_protocol_enable) // Alternate protocol support
    ,
    .cfg_tph_req_en                 (cfg_tph_req_en),
    .cfg_pf_tph_st_mode             (cfg_pf_tph_st_mode)
    ,
    .crgb_cdm_cs                    (crgb_cdm_cs),
    .crgb_cdm_ack                   (crgb_cdm_ack),
    .crgb_cdm_addr                  (crgb_cdm_addr),
    .crgb_cdm_rdata                 (crgb_cdm_rdata),
    .crgb_cdm_wdata                 (crgb_cdm_wdata),
    .crgb_cdm_wr                    (crgb_cdm_wr),
    .crgb_cdm_source                (crgb_cdm_source)
    ,
    .cfg_gen3_eq_fs_lf              (cfg_gen3_eq_fs_lf),
    .cfg_gen3_eq_coef               (cfg_gen3_eq_coef)
    ,
    .cfg_gen4_eq_fs_lf              (cfg_gen4_eq_fs_lf),
    .cfg_gen4_eq_coef               (cfg_gen4_eq_coef)
    ,
    .cfg_gen5_eq_fs_lf              (cfg_gen5_eq_fs_lf),
    .cfg_gen5_eq_coef               (cfg_gen5_eq_coef)
    ,
    .cfg_gen6_eq_fs_lf              (cfg_gen6_eq_fs_lf),
    .cfg_gen6_eq_coef               (cfg_gen6_eq_coef)
    ,
    .cfg_int_pin                    (cfg_int_pin)
    ,
    .cfg_end2end_tlp_pfx_blck        (cfg_end2end_tlp_pfx_blck),
    .cfg_max_end2end_tlp_prfxs      (cfg_max_end2end_tlp_prfxs)
    ,
    .cfg_pf_pasid_control           (cfg_pf_pasid_control)




    ,
    .default_target                 (default_target),
    .cfg_cfg_tlp_bypass_en          (cfg_cfg_tlp_bypass_en),
    .cfg_config_limit               (cfg_config_limit),
    .cfg_target_above_config_limit  (cfg_target_above_config_limit),
    .cfg_p2p_track_cpl_to           (cfg_p2p_track_cpl_to),
    .cfg_p2p_err_rpt_ctrl           (cfg_p2p_err_rpt_ctrl),
    .ur_ca_mask_4_trgt1             (ur_ca_mask_4_trgt1)
    ,
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
    .cfg_margin_ind_error_sampler         (cfg_margin_ind_error_sampler)
    ,
    .cfg_rx_message_bus_write_buffer_depth (cfg_rx_message_bus_write_buffer_depth)
    ,
    .cfg_pipe_garbage_data_mode     (cfg_pipe_garbage_data_mode)
    ,
    .cfg_pam4_restricted_levels_requirement (cfg_pam4_restricted_levels_requirement)
    ,
    .cfg_rasdp_linkdown_en          (cfg_rasdp_linkdown_en),
    .cfg_rasdp_error_mode_en        (cfg_rasdp_error_mode_en),
    .rasdp_linkdown                 (rasdp_linkdown),
    .cfg_rasdp_error_mode           (cfg_rasdp_error_mode_i)
    ,.cfg_optional_ohc               (cfg_optional_ohc)
    ,
    .frsq_msi                       (frsq_msi),
    .frsq_int_msg_num               (frsq_int_msg_num)

    ,
    .cfg_drs_msi                    (cfg_drs_msi)
    ,
    .cfg_up_drs_to_frs              (cfg_up_drs_to_frs)
    ,
    .cfg_ido_req_en                 (cfg_ido_req_en),
    .cfg_ido_cpl_en                 (cfg_ido_cpl_en)
    ,
    .cdm_ras_des_ec_info_common     (cdm_ras_des_ec_info_common),
    .cdm_ras_des_ec_info_l0         (cdm_ras_des_ec_info_l0),
    .cdm_ras_des_ec_info_l1         (cdm_ras_des_ec_info_l1),
    .cdm_ras_des_ec_info_l2         (cdm_ras_des_ec_info_l2),
    .cdm_ras_des_ec_info_l3         (cdm_ras_des_ec_info_l3),
    .cdm_ras_des_ec_info_l4         (cdm_ras_des_ec_info_l4),
    .cdm_ras_des_ec_info_l5         (cdm_ras_des_ec_info_l5),
    .cdm_ras_des_ec_info_l6         (cdm_ras_des_ec_info_l6),
    .cdm_ras_des_ec_info_l7         (cdm_ras_des_ec_info_l7),
    .app_ras_des_sd_hold_ltssm      (app_ras_des_sd_hold_ltssm),
    .cdm_ras_des_sd_info_common     (cdm_ras_des_sd_info_common),
    .cdm_ras_des_sd_info_l0         (cdm_ras_des_sd_info_l0),
    .cdm_ras_des_sd_info_l1         (cdm_ras_des_sd_info_l1),
    .cdm_ras_des_sd_info_l2         (cdm_ras_des_sd_info_l2),
    .cdm_ras_des_sd_info_l3         (cdm_ras_des_sd_info_l3),
    .cdm_ras_des_sd_info_l4         (cdm_ras_des_sd_info_l4),
    .cdm_ras_des_sd_info_l5         (cdm_ras_des_sd_info_l5),
    .cdm_ras_des_sd_info_l6         (cdm_ras_des_sd_info_l6),
    .cdm_ras_des_sd_info_l7         (cdm_ras_des_sd_info_l7),
    .cdm_ras_des_sd_info_v0         (cdm_ras_des_sd_info_v0),
    .cdm_ras_des_tba_info_common    (cdm_ras_des_tba_info_common),

    .cdm_ras_des_ec_ram_ena         (cdm_ras_des_ec_ram_ena),
    .cdm_ras_des_ec_ram_wea         (cdm_ras_des_ec_ram_wea),
    .cdm_ras_des_ec_ram_addra       (cdm_ras_des_ec_ram_addra),
    .cdm_ras_des_ec_ram_datain      (cdm_ras_des_ec_ram_datain),
    .cdm_ras_des_ec_ram_enb         (cdm_ras_des_ec_ram_enb),
    .cdm_ras_des_ec_ram_addrb       (cdm_ras_des_ec_ram_addrb),
    .cdm_ras_des_tba_ram_ena        (cdm_ras_des_tba_ram_ena),
    .cdm_ras_des_tba_ram_wea        (cdm_ras_des_tba_ram_wea),
    .cdm_ras_des_tba_ram_addra      (cdm_ras_des_tba_ram_addra),
    .cdm_ras_des_tba_ram_datain     (cdm_ras_des_tba_ram_datain),
    .cdm_ras_des_tba_ram_enb        (cdm_ras_des_tba_ram_enb),
    .cdm_ras_des_tba_ram_addrb      (cdm_ras_des_tba_ram_addrb),
    .cdm_ras_des_pm_entry_interval       (cdm_ras_des_pm_entry_interval),
    .cdm_ras_des_eidle_cnt_sel           (cdm_ras_des_eidle_cnt_sel),
    .cdm_ras_des_ltssm_stop              (cdm_ras_des_ltssm_stop),
    .cdm_ras_des_recovery_req            (cdm_ras_des_recovery_req),
    .cdm_ras_des_ferr_rec_dis            (cdm_ras_des_ferr_rec_dis),
    .cdm_ras_des_direct_rcvry_idle_to_cfg(cdm_ras_des_direct_rcvry_idle_to_cfg),
    .cdm_ras_des_direct_poll_cmp_to_det  (cdm_ras_des_direct_poll_cmp_to_det),
    .cdm_ras_des_direct_lpbk_slave_to_exit(cdm_ras_des_direct_lpbk_slave_to_exit),
    .cdm_ras_des_force_rxdetected_en     (cdm_ras_des_force_rxdetected_en),
    .cdm_ras_des_force_rxdetected        (cdm_ras_des_force_rxdetected),
    .cdm_ras_des_force_linkdown_noack    (cdm_ras_des_force_linkdown_noack)
    ,
    .cdm_ras_des_ext_eq_to_factor       (cdm_ras_des_ext_eq_to_factor),
    .cdm_ras_des_eq_fom_target_en       (cdm_ras_des_eq_fom_target_en),
    .cdm_ras_des_eq_force_coef_rtx_en   (cdm_ras_des_eq_force_coef_rtx_en),
    .cdm_ras_des_eq_force_pset_lrx_en   (cdm_ras_des_eq_force_pset_lrx_en),
    .cdm_ras_des_eq_force_coef_ltx_en   (cdm_ras_des_eq_force_coef_ltx_en),
    .cdm_ras_des_eq_force_coef_ltx       (cdm_ras_des_eq_force_coef_ltx),
    .cdm_ras_des_eq_force_pset_lrx       (cdm_ras_des_eq_force_pset_lrx),
    .cdm_ras_des_eq_force_coef_rtx       (cdm_ras_des_eq_force_coef_rtx),
    .cdm_ras_des_eq_force_pset_ltx_en   (cdm_ras_des_eq_force_pset_ltx_en),
    .cdm_ras_des_eq_force_usp_pset_ltx   (cdm_ras_des_eq_force_usp_pset_ltx)
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g4 (cdm_ras_des_eq_force_coef_rtx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_en_g4 (cdm_ras_des_eq_force_coef_ltx_en_g4),
    .cdm_ras_des_eq_force_coef_ltx_g4    (cdm_ras_des_eq_force_coef_ltx_g4),
    .cdm_ras_des_eq_force_coef_rtx_g4    (cdm_ras_des_eq_force_coef_rtx_g4),
    .cdm_ras_des_eq_force_pset_ltx_en_g4 (cdm_ras_des_eq_force_pset_ltx_en_g4),
    .cdm_ras_des_eq_force_usp_pset_ltx_g4 (cdm_ras_des_eq_force_usp_pset_ltx_g4)
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g5 (cdm_ras_des_eq_force_coef_rtx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_en_g5 (cdm_ras_des_eq_force_coef_ltx_en_g5),
    .cdm_ras_des_eq_force_coef_ltx_g5    (cdm_ras_des_eq_force_coef_ltx_g5),
    .cdm_ras_des_eq_force_coef_rtx_g5    (cdm_ras_des_eq_force_coef_rtx_g5),
    .cdm_ras_des_eq_force_pset_ltx_en_g5 (cdm_ras_des_eq_force_pset_ltx_en_g5),
    .cdm_ras_des_eq_force_usp_pset_ltx_g5 (cdm_ras_des_eq_force_usp_pset_ltx_g5)
    ,
    .cdm_ras_des_eq_force_coef_rtx_en_g6 (cdm_ras_des_eq_force_coef_rtx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_en_g6 (cdm_ras_des_eq_force_coef_ltx_en_g6),
    .cdm_ras_des_eq_force_coef_ltx_g6    (cdm_ras_des_eq_force_coef_ltx_g6),
    .cdm_ras_des_eq_force_coef_rtx_g6    (cdm_ras_des_eq_force_coef_rtx_g6),
    .cdm_ras_des_eq_force_pset_ltx_en_g6 (cdm_ras_des_eq_force_pset_ltx_en_g6),
    .cdm_ras_des_eq_force_usp_pset_ltx_g6 (cdm_ras_des_eq_force_usp_pset_ltx_g6)
    ,
    .cdm_ras_des_eq_fom_target           (cdm_ras_des_eq_fom_target),
    .cdm_ras_des_eq_eval_interval        (cdm_ras_des_eq_eval_interval)
  
    ,
    .cdm_ras_des_einj0_enable       (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_count        (cdm_ras_des_einj0_count),
    .cdm_ras_des_einj0_crc_type     (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj0_ecrc_vc_sel  (cdm_ras_des_einj0_ecrc_vc_sel),  
    .cdm_ras_des_einj0_ecrc_fc_sel  (cdm_ras_des_einj0_ecrc_fc_sel),  
    .cdm_ras_des_einj0_ecrc_intf_sel(cdm_ras_des_einj0_ecrc_intf_sel),
    .cdm_ras_des_einj1_enable       (cdm_ras_des_einj1_enable),
    .cdm_ras_des_einj1_seq_type     (cdm_ras_des_einj1_seq_type),
    .cdm_ras_des_einj1_bad_seq      (cdm_ras_des_einj1_bad_seq),
    .cdm_ras_des_einj1_count        (cdm_ras_des_einj1_count),
    .cdm_ras_des_einj2_enable       (cdm_ras_des_einj2_enable),
    .cdm_ras_des_einj2_dllp_type    (cdm_ras_des_einj2_dllp_type),
    .cdm_ras_des_einj3_enable       (cdm_ras_des_einj3_enable),
    .cdm_ras_des_einj3_count        (cdm_ras_des_einj3_count),
    .cdm_ras_des_einj3_smb_type     (cdm_ras_des_einj3_smb_type),
    .cdm_ras_des_einj4_enable       (cdm_ras_des_einj4_enable),
    .cdm_ras_des_einj4_updfc_type   (cdm_ras_des_einj4_updfc_type),
    .cdm_ras_des_einj4_vcnum        (cdm_ras_des_einj4_vcnum),
    .cdm_ras_des_einj4_badfc_value  (cdm_ras_des_einj4_badfc_value),
    .cdm_ras_des_einj5_enable       (cdm_ras_des_einj5_enable),
    .cdm_ras_des_einj5_count        (cdm_ras_des_einj5_count),
    .cdm_ras_des_einj5_tlp_type     (cdm_ras_des_einj5_tlp_type),
    .cdm_ras_des_einj6_enable       (cdm_ras_des_einj6_enable),
    .cdm_ras_des_einj6_cmp_point_h0 (cdm_ras_des_einj6_cmp_point_h0),
    .cdm_ras_des_einj6_cmp_point_h1 (cdm_ras_des_einj6_cmp_point_h1),
    .cdm_ras_des_einj6_cmp_point_h2 (cdm_ras_des_einj6_cmp_point_h2),
    .cdm_ras_des_einj6_cmp_point_h3 (cdm_ras_des_einj6_cmp_point_h3),
    .cdm_ras_des_einj6_cmp_value_h0 (cdm_ras_des_einj6_cmp_value_h0),
    .cdm_ras_des_einj6_cmp_value_h1 (cdm_ras_des_einj6_cmp_value_h1),
    .cdm_ras_des_einj6_cmp_value_h2 (cdm_ras_des_einj6_cmp_value_h2),
    .cdm_ras_des_einj6_cmp_value_h3 (cdm_ras_des_einj6_cmp_value_h3),
    .cdm_ras_des_einj6_chg_point_h0 (cdm_ras_des_einj6_chg_point_h0),
    .cdm_ras_des_einj6_chg_point_h1 (cdm_ras_des_einj6_chg_point_h1),
    .cdm_ras_des_einj6_chg_point_h2 (cdm_ras_des_einj6_chg_point_h2),
    .cdm_ras_des_einj6_chg_point_h3 (cdm_ras_des_einj6_chg_point_h3),
    .cdm_ras_des_einj6_chg_value_h0 (cdm_ras_des_einj6_chg_value_h0),
    .cdm_ras_des_einj6_chg_value_h1 (cdm_ras_des_einj6_chg_value_h1),
    .cdm_ras_des_einj6_chg_value_h2 (cdm_ras_des_einj6_chg_value_h2),
    .cdm_ras_des_einj6_chg_value_h3 (cdm_ras_des_einj6_chg_value_h3),
    .cdm_ras_des_einj6_count        (cdm_ras_des_einj6_count),
    .cdm_ras_des_einj6_invt_cont    (cdm_ras_des_einj6_invt_cont),
    .cdm_ras_des_einj6_pkt_type     (cdm_ras_des_einj6_pkt_type)

    ,
    .ptm_clock_updated              (ptm_clock_updated),
    .ptm_clock_correction           (ptm_clock_correction),
    .ptm_trigger_allowed            (ptm_trigger_allowed),          // top level output
    .ptm_updating                   (ptm_updating),
    .ptm_req_response_timeout       (ptm_req_response_timeout),     // top level output
    .ptm_req_dup_rx                 (ptm_req_dup_rx),               // top level output
    .ptm_req_replay_tx              (ptm_req_replay_tx)             // top level output

    ,
    .ptm_request_msg                (ptm_request_msg),
    .ptm_res_msg                    (ptm_res_msg),
    .ptm_res_d_msg                  (ptm_res_d_msg),
    .ptm_master_time                (ptm_master_time),
    .ptm_prop_delay                 (ptm_prop_delay),
    .cfg_ptm_enable                 (cfg_ptm_enable),
    .ptm_context_valid              (ptm_context_valid),
    .ptm_responder_rdy_to_validate  (ptm_responder_rdy_to_validate),
    .ptm_local_clock                (ptm_local_clock)


    ,
    .cfg_ats_stu                    (cfg_ats_stu),
    .cfg_ats_cache_en               (cfg_ats_cache_en)

    ,
    .cfg_10b_tag_req_en             (cfg_10b_tag_req_en)

    ,
    .cfg_prs_enable                 (cfg_prs_enable),
    .cfg_prs_reset                  (cfg_prs_reset),
    .cfg_prs_stopped                (cfg_prs_stopped),
    .cfg_prs_uprgi                  (cfg_prs_uprgi),
    .cfg_prs_response_failure       (cfg_prs_response_failure),
    .cfg_prs_outstanding_allocation (cfg_prs_outstanding_allocation)


  ,
  .cfg_nond0_vdm_block              (cfg_nond0_vdm_block),
  .cfg_client0_block_new_tlp        (cfg_client0_block_new_tlp),
  .cfg_client1_block_new_tlp        (cfg_client1_block_new_tlp),
  .cfg_client2_block_new_tlp        (cfg_client2_block_new_tlp)

    ,
    .cdm_hp_pme                     (hp_pme),
    .cdm_hp_int                     (hp_int),
    .cdm_hp_msi                     (hp_msi)
    ,
    .cfg_auto_slot_pwr_lmt_dis      (cfg_auto_slot_pwr_lmt_dis),
    .cfg_hp_slot_ctrl_access        (cfg_hp_slot_ctrl_access),
    .cfg_dll_state_chged_en         (cfg_dll_state_chged_en),
    .cfg_cmd_cpled_int_en           (cfg_cmd_cpled_int_en),
    .cfg_pre_det_chged_en           (cfg_pre_det_chged_en),
    .cfg_mrl_sensor_chged_en        (cfg_mrl_sensor_chged_en),
    .cfg_pwr_fault_det_en           (cfg_pwr_fault_det_en),
    .cfg_atten_button_pressed_en    (cfg_atten_button_pressed_en),
    .cfg_hp_int_en                  (cfg_hp_int_en)
    ,
    .cfg_br_ctrl_serren             (cfg_br_ctrl_serren)


    ,
    .cdm_dpc_triggered                  (cdm_dpc_triggered),
    .cdm_aer_dpc_triggered              (cdm_aer_dpc_triggered),
    .cdm_core_in_dpc                    (cdm_core_in_dpc),
    .dpc_fatal_err_gate                 (dpc_fatal_err_gate),
    .dpc_nonfatal_err_gate              (dpc_nonfatal_err_gate),
    .cfg_dpc_int_msg_num                (cfg_dpc_int_msg_num),
    .cfg_dpc_rp_ext_dpc                 (cfg_dpc_rp_ext_dpc),
    .cfg_dpc_poison_tlp_egr_blk_support (cfg_dpc_poison_tlp_egr_blk_support),
    .cfg_dpc_sw_trig_support            (cfg_dpc_sw_trig_support),
    .cfg_dpc_rp_pio_log_size            (cfg_dpc_rp_pio_log_size),
    .cfg_dpc_dl_active_err_cor_support  (cfg_dpc_dl_active_err_cor_support),
    .cfg_dpc_trig_en                    (cfg_dpc_trig_en),
    .cfg_dpc_cpl_cntrl                  (cfg_dpc_cpl_cntrl),
    .cfg_dpc_int_en                     (cfg_dpc_int_en),
    .dpc_int                            (dpc_int),
    .dpc_msi                            (dpc_msi),
    .cfg_dpc_err_cor_en                 (cfg_dpc_err_cor_en),
    .cfg_dpc_poison_tlp_egr_block_en    (cfg_dpc_poison_tlp_egr_block_en),
    .cfg_dpc_sw_trigger                 (cfg_dpc_sw_trigger),
    .cfg_dpc_dl_active_err_cor_en       (cfg_dpc_dl_active_err_cor_en)
    ,.pm_powerdown_status          (pm_powerdown_status)
    ,.cfg_force_powerdown          (cfg_force_powerdown)
    ,
    .cfg_pcie_slot_clk_config           (cfg_pcie_slot_clk_config          ),
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
    .cfg_advisory_nf_sts                (cfg_advisory_nf_sts               ),
    .cfg_hdr_log_overflow_sts           (cfg_hdr_log_overflow_sts          )


//------------------------------------------------
//  Ouputs from u_cdm_cxl_port_reg
//------------------------------------------------
  ,.cfg_cxl_port_cache_capable            ( b_cxl_cdm.s_cfg_cxl_port_cache_capable            ),
   .cfg_cxl_port_mem_capable              ( b_cxl_cdm.s_cfg_cxl_port_mem_capable              ),
   .cfg_cxl_port_vid                      ( b_cxl_cdm.s_cfg_cxl_port_vid                      ),
   .cfg_cxl_port_68B_flit_vh_capable      ( b_cxl_cdm.s_cfg_cxl_port_68B_flit_vh_capable      ),
   .cfg_cxl_port_mld_capable              ( b_cxl_cdm.s_cfg_cxl_port_mld_capable              ),
   .cfg_cxl_port_68B_flit_vh_enable       ( b_cxl_cdm.s_cfg_cxl_port_68B_flit_vh_enable       ),
   .cfg_cxl_port_mld_enable               ( b_cxl_cdm.s_cfg_cxl_port_mld_enable               ),
   .cfg_cxl_port_disable_cxl1p1_training  ( b_cxl_cdm.s_cfg_cxl_port_disable_cxl1p1_training  ),
   .cfg_cxl_port_cache_enable             ( b_cxl_cdm.s_cfg_cxl_port_cache_enable             ),
   .cfg_cxl_port_io_enable                ( b_cxl_cdm.s_cfg_cxl_port_io_enable                ),
   .cfg_cxl_port_mem_enable               ( b_cxl_cdm.s_cfg_cxl_port_mem_enable               ),
   .cfg_cxl_port_sync_hdr_bypass_enable   ( b_cxl_cdm.s_cfg_cxl_port_sync_hdr_bypass_enable   ),
   .cfg_cxl_port_drift_buffer_enable      ( b_cxl_cdm.s_cfg_cxl_port_drift_buffer_enable      ),
   .cfg_cxl_port_retimer1_present         ( b_cxl_cdm.s_cfg_cxl_port_retimer1_present         ),
   .cfg_cxl_port_retimer2_present         ( b_cxl_cdm.s_cfg_cxl_port_retimer2_present         ),
   .cfg_cxl_port_retimers_pre_mismatched  ( b_cxl_cdm.s_cfg_cxl_port_retimers_pre_mismatched  ),
   .cfg_cxl_port_lopt_flit_capable        ( b_cxl_cdm.s_cfg_cxl_port_lopt_flit_capable        ),
   .cfg_cxl_port_lopt_flit_enable         ( b_cxl_cdm.s_cfg_cxl_port_lopt_flit_enable         ),
   .cfg_cxl_port_pbr_flit_capable         ( b_cxl_cdm.s_cfg_cxl_port_pbr_flit_capable         ),
   .cfg_cxl_port_pbr_flit_enable          ( b_cxl_cdm.s_cfg_cxl_port_pbr_flit_enable          ),
   .cfg_cxl_port_nop_hint_capable         ( b_cxl_cdm.s_cfg_cxl_port_nop_hint_capable         ),
   .cfg_cxl_port_nop_hint_enable          ( b_cxl_cdm.s_cfg_cxl_port_nop_hint_enable          ),
   .cfg_cxl_pl_reg_viral_status           ( b_cxl_cdm.s_cfg_cxl_pl_reg_viral_status),
   .cfg_cxl_viral_enable                  ( b_cxl_cdm.s_cfg_cxl_viral_enable                  ),
   .cfg_cxl_viral_status                  ( b_cxl_cdm.s_cfg_cxl_viral_status                  ),

//------------------------------------------------
//  Ouputs from u_cdm_cxl_device_reg
//------------------------------------------------
   .cfg_cxl_dev_cache_enable              ( b_cxl_cdm.s_cfg_cxl_dev_cache_enable              ),
   .cfg_cxl_dev_io_enable                 ( b_cxl_cdm.s_cfg_cxl_dev_io_enable                 ),
   .cfg_cxl_dev_mem_enable                ( b_cxl_cdm.s_cfg_cxl_dev_mem_enable                ),
   .cfg_cxl_dev_cache_sf_coverage         ( b_cxl_cdm.s_cfg_cxl_dev_cache_sf_coverage         ),
   .cfg_cxl_dev_cache_sf_granularity      ( b_cxl_cdm.s_cfg_cxl_dev_cache_sf_granularity      ),
   .cfg_cxl_dev_cache_clean_eviction      ( b_cxl_cdm.s_cfg_cxl_dev_cache_clean_eviction      ),
   .cfg_cxl_dev_viral_enable              ( b_cxl_cdm.s_cfg_cxl_dev_viral_enable              ),
   .cfg_cxl_dev_cxl_rst_mem_clr_enable    ( b_cxl_cdm.s_cfg_cxl_dev_cxl_rst_mem_clr_enable    ),
   .cfg_cxl_dev_post_cold_rst_volatile_hdm_default ( b_cxl_cdm.s_cfg_cxl_dev_post_cold_rst_volatile_hdm_default ),
   .cfg_cxl_dev_post_warm_rst_volatile_hdm_default ( b_cxl_cdm.s_cfg_cxl_dev_post_warm_rst_volatile_hdm_default ),
   .cfg_cxl_dev_post_hot_rst_volatile_hdm_default  ( b_cxl_cdm.s_cfg_cxl_dev_post_hot_rst_volatile_hdm_default  ),
   .cfg_cxl_dev_post_hot_rst_volatile_hdm_desired  ( b_cxl_cdm.s_cfg_cxl_dev_post_hot_rst_volatile_hdm_desired  ),
   .cfg_cxl_dev_viral_status              ( b_cxl_cdm.s_cfg_cxl_dev_viral_status              ),
   .cfg_cxl_dev_disable_caching           ( b_cxl_cdm.s_cfg_cxl_dev_disable_caching           ),
   .cfg_cxl_dev_initiate_cache_wr_invld   ( b_cxl_cdm.s_cfg_cxl_dev_initiate_cache_wr_invld   ),
   .cfg_cxl_dev_initiate_cxl_rst          ( b_cxl_cdm.s_cfg_cxl_dev_initiate_cxl_rst          ),
   .cfg_cxl_dev_range1_mem_size_high      ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_size_high      ),
   .cfg_cxl_dev_range1_mem_info_valid     ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_info_valid     ),
   .cfg_cxl_dev_range1_mem_active         ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_active         ),
   .cfg_cxl_dev_range1_desired_interleave ( b_cxl_cdm.s_cfg_cxl_dev_range1_desired_interleave ),
   .cfg_cxl_dev_range1_mem_active_timeout ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_active_timeout ),
   .cfg_cxl_dev_range1_mem_size_low       ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_size_low       ),
   .cfg_cxl_dev_range1_mem_base_high      ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_base_high      ),
   .cfg_cxl_dev_range1_mem_base_low       ( b_cxl_cdm.s_cfg_cxl_dev_range1_mem_base_low       ),
   .cfg_cxl_dev_range2_mem_size_high      ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_size_high      ),
   .cfg_cxl_dev_range2_mem_info_valid     ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_info_valid     ),
   .cfg_cxl_dev_range2_mem_active         ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_active         ),
   .cfg_cxl_dev_range2_desired_interleave ( b_cxl_cdm.s_cfg_cxl_dev_range2_desired_interleave ),
   .cfg_cxl_dev_range2_mem_active_timeout ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_active_timeout ),
   .cfg_cxl_dev_range2_mem_size_low       ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_size_low       ),
   .cfg_cxl_dev_range2_mem_base_high      ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_base_high      ),
   .cfg_cxl_dev_range2_mem_base_low       ( b_cxl_cdm.s_cfg_cxl_dev_range2_mem_base_low       ),

//------------------------------------------------
// Ouputs from u_cdm_cxl_mbar0
//------------------------------------------------
    .mbar0_ras_uncorr_error_mask       ( b_cxl_cdm.s_mbar0_ras_uncorr_error_mask       ),
    .mbar0_ras_uncorr_error_severity   ( b_cxl_cdm.s_mbar0_ras_uncorr_error_severity   ),
    .mbar0_ras_corr_error_mask         ( b_cxl_cdm.s_mbar0_ras_corr_error_mask         ),
    .mbar0_ras_poison_enabled          ( b_cxl_cdm.s_mbar0_ras_poison_enabled          ),
    .mbar0_security_device_trust_level ( b_cxl_cdm.s_mbar0_security_device_trust_level ),

    .mbar0_arb_mux_cxl_io              ( b_cxl_cdm.s_mbar0_arb_mux_cxl_io              ),
    .mbar0_arb_mux_cxl_cache_mem       ( b_cxl_cdm.s_mbar0_arb_mux_cxl_cache_mem       ),
    .mbar0_arb_mux_pmtimeout_en        ( cfg_pm_timeout_enable                         ),
    .mbar0_arb_mux_pmtimeout_val       ( cfg_pm_timeout_value                          ),
    .mbar0_arb_mux_pmtimeout_err       ( cfg_pm_timeout_error                          ),
    .mbar0_arb_mux_l0ptimeout_err      ( 1'b0                                          ),
    .mbar0_cap_header_reg              ( b_cxl_cdm.s_mbar0_cap_header_reg              ),
    .mbar0_ras_cap_header_reg          ( b_cxl_cdm.s_mbar0_ras_cap_header_reg          ),
    .mbar0_security_cap_header_reg     ( b_cxl_cdm.s_mbar0_security_cap_header_reg     ),
    .mbar0_link_cap_header_reg         ( b_cxl_cdm.s_mbar0_link_cap_header_reg         ),
    .mbar0_ras_corr_reg                ( b_cxl_cdm.s_mbar0_ras_corr_reg                ),
    .mbar0_ras_uncorr_reg              ( b_cxl_cdm.s_mbar0_ras_uncorr_reg              ),
//------------------------------------------------
// Ouputs from u_cdm_pl_reg
//------------------------------------------------
    .cxl_fatal_error_reg               ( b_cxl_cdm.s_cxl_fatal_error_reg                 ),
    .cxl_pl_reg_vlsm_pm_enable         ( b_cxl_cdm.s_pl_reg_vlsm_pm_enable               ),
    .cxl_pl_reg_apn_bypass_enable      ( b_cxl_cdm.s_pl_reg_apn_bypass_enable            ),
    .cxl_pl_reg_apn_sw_mode            ( b_cxl_cdm.s_pl_reg_apn_sw_mode                  ),
    .cxl_pl_reg_vlsm_to_active         ( b_cxl_cdm.s_pl_reg_vlsm_to_active               ),
    .cxl_pl_reg_max_num_retry          ( b_cxl_cdm.s_pl_reg_max_num_retry                ),
    .cxl_pl_reg_max_num_reinit         ( b_cxl_cdm.s_pl_reg_max_num_reinit               ),
    .cxl_pl_reg_lrsm_timeout_threshold ( b_cxl_cdm.s_pl_reg_lrsm_timeout_threshold       ),
    .cxl_pl_reg_crc_threshold          ( b_cxl_cdm.s_pl_reg_crc_threshold                ),
    .cxl_pl_reg_cm_ll_cache_poison_injection_start       ( b_cxl_cdm.s_pl_reg_cm_ll_cache_poison_injection_start     ),
    .cxl_pl_reg_cm_ll_mem_poison_injection_start         ( b_cxl_cdm.s_pl_reg_cm_ll_mem_poison_injection_start       ),
    .cxl_pl_reg_cm_ll_io_poison_injection_start          ( /* Error Injection Not Implemented                     */ ),
    .cxl_pl_reg_cm_ll_cache_mem_crc_injection            ( b_cxl_cdm.s_pl_reg_cm_ll_cache_mem_crc_injection          ),
    .cxl_pl_reg_cm_ll_cache_mem_crc_injection_count      ( b_cxl_cdm.s_pl_reg_cm_ll_cache_mem_crc_injection_count    ),

    .cxl_pl_reg_io_ll_io_poison_injection_start          ( /* Error Injection Not Implemented                     */ ),
    .cxl_pl_reg_io_ll_flow_ctrl_error_injection          ( /* Error Injection Not Implemented                     */ ),

    .cxl_pl_reg_fb_phy_cor_protid_error_injection        ( /* Error Injection Not Implemented                     */ ),
    .cxl_pl_reg_fb_phy_uncor_protid_error_injection      ( /* Error Injection Not Implemented                     */ ),
    .cxl_pl_reg_fb_phy_unexp_protid_error_injection      ( /* Error Injection Not Implemented                     */ )


//------------------------------------------------
// Ouputs from u_cdm_cxl_2_0_ext_reg
//------------------------------------------------
   ,.cfg_cxl_2_0_ext_viral_status            ( b_cxl_cdm.s_cfg_cxl_2_0_ext_viral_status            )
   ,.cfg_cxl_2_0_ext_unmask_sbr              ( b_cxl_cdm.s_cfg_cxl_2_0_ext_unmask_sbr              )
   ,.cfg_cxl_2_0_ext_unmask_ld               ( b_cxl_cdm.s_cfg_cxl_2_0_ext_unmask_ld               )
   ,.cfg_cxl_2_0_ext_alt_mse                 ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mse                 )
   ,.cfg_cxl_2_0_ext_alt_bme                 ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bme                 )
   ,.cfg_cxl_2_0_ext_viral_en                ( b_cxl_cdm.s_cfg_cxl_2_0_ext_viral_en                )
   ,.cfg_cxl_2_0_ext_alt_bus_base            ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bus_base            )
   ,.cfg_cxl_2_0_ext_alt_bus_limit           ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_bus_limit           )
   ,.cfg_cxl_2_0_ext_alt_mem_base            ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mem_base            )
   ,.cfg_cxl_2_0_ext_alt_mem_limit           ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_mem_limit           )
   ,.cfg_cxl_2_0_ext_alt_pref_mem_base       ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_base       )
   ,.cfg_cxl_2_0_ext_alt_pref_mem_limit      ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_limit      )
   ,.cfg_cxl_2_0_ext_alt_pref_mem_base_high  ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_base_high  )
   ,.cfg_cxl_2_0_ext_alt_pref_mem_limit_high ( b_cxl_cdm.s_cfg_cxl_2_0_ext_alt_pref_mem_limit_high )
   ,.cfg_cxl_2_0_ext_rcrb_en                 ( b_cxl_cdm.s_cfg_cxl_2_0_ext_rcrb_en                 )
   ,.cfg_cxl_2_0_ext_rcrb_base_addr_low      ( b_cxl_cdm.s_cfg_cxl_2_0_ext_rcrb_base_addr_low      )
   ,.cfg_cxl_2_0_ext_rcrb_base_addr_high     ( b_cxl_cdm.s_cfg_cxl_2_0_ext_rcrb_base_addr_high     )
//------------------------------------------------
// Ouputs from u_cdm_cxl_reg_locator_reg
//------------------------------------------------
   ,.cxl_2_0_comp_reg_offset                  (cxl_2_0_comp_reg_offset)
   ,.cfg_cxl_reg_locator_reg1_bir             (cfg_cxl_reg_locator_reg1_bir)
   ,.cfg_cxl_reg_locator_reg1_blk_identifier  (cfg_cxl_reg_locator_reg1_blk_identifier)
   ,.cfg_cxl_reg_locator_reg1_blk_offset_low  (cfg_cxl_reg_locator_reg1_blk_offset_low)
   ,.cfg_cxl_reg_locator_reg1_blk_offset_high (cfg_cxl_reg_locator_reg1_blk_offset_high)
   ,.cfg_cxl_reg_locator_reg2_bir             (cfg_cxl_reg_locator_reg2_bir)
   ,.cfg_cxl_reg_locator_reg2_blk_identifier  (cfg_cxl_reg_locator_reg2_blk_identifier)
   ,.cfg_cxl_reg_locator_reg2_blk_offset_low  (cfg_cxl_reg_locator_reg2_blk_offset_low)
   ,.cfg_cxl_reg_locator_reg2_blk_offset_high (cfg_cxl_reg_locator_reg2_blk_offset_high)
   ,.cfg_cxl_reg_locator_reg3_bir             (cfg_cxl_reg_locator_reg3_bir)
   ,.cfg_cxl_reg_locator_reg3_blk_identifier  (cfg_cxl_reg_locator_reg3_blk_identifier)
   ,.cfg_cxl_reg_locator_reg3_blk_offset_low  (cfg_cxl_reg_locator_reg3_blk_offset_low)
   ,.cfg_cxl_reg_locator_reg3_blk_offset_high (cfg_cxl_reg_locator_reg3_blk_offset_high)
// ------------------------------------------------------------
// Outputs from u_cdm_cxl_gpf_port_reg
// ------------------------------------------------------------
   ,.cfg_cxl_gpf_port_p1_timeout_base         (cfg_cxl_gpf_port_p1_timeout_base)
   ,.cfg_cxl_gpf_port_p1_timeout_scale        (cfg_cxl_gpf_port_p1_timeout_scale)
   ,.cfg_cxl_gpf_port_p2_timeout_base         (cfg_cxl_gpf_port_p2_timeout_base)
   ,.cfg_cxl_gpf_port_p2_timeout_scale        (cfg_cxl_gpf_port_p2_timeout_scale)
    ,.cfg_dbi_func_bank_select           (cfg_dbi_func_bank_select)
    ,.dbi_ro_wr_en                       (dbi_ro_wr_en)
    ,.cfg_neg_link_width                 (cfg_neg_link_width)
    ,.cfg_pcie_cap_flit_mode_sup         (cfg_pcie_cap_flit_mode_sup)
    ,.cfg_flit_mode_dis                  (cfg_flit_mode_dis)
    ,.cfg_flit_sris_clocking             (cfg_flit_sris_clocking)
    ,.cfg_pcie_cap_flit_mode_stat        (cfg_pcie_cap_flit_mode_stat)
    ,.cfg_tx_throttling                  (cfg_tx_throttling)
    ,.cfg_prbs_en                  (cfg_prbs_en)
    ,.clear_prbs_done              (clear_prbs_done)
    ,.cfg_prbs_lane_sel            (cfg_prbs_lane_sel)

);  // u_cdm





//
// CX-PL core for xN
//

// do deskew using ts2 -> LogicIdle transition always for flit mode at gen1/2 rate
assign cfg_ts2_lid_deskew_i = smlh_flit_mode_enable ? 1'b1 : cfg_ts2_lid_deskew;

`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS


assign rplh_flit_unrecognized_flit = rplh_flit_logging_interface.rplh_flit_unrecognized_flit;
assign rplh_flit_ecc_corr_err      = rplh_flit_logging_interface.rplh_flit_fec_uncorr_error ? 1'b0 : rplh_flit_logging_interface.rplh_flit_fec_corr_error;
assign rplh_flit_ecc_uncorr_err    = rplh_flit_logging_interface.rplh_flit_fec_uncorr_error;
assign rplh_flit_crc_uncorr_err    = rplh_flit_logging_interface.rplh_flit_crc_uncorr_error;
assign ltssm_powerdown = int_ltssm_powerdown;





//------------------------
// The Local Bus Controller
lbc

#(INST) u_lbc (
    // -- inputs --
    .core_clk                       (aux_clk_g),
    .core_rst_n                     (core_rst_n),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .device_type                    (device_type_o),
    .cfg_bar0_mask                  (cfg_bar0_mask),
    .cfg_bar1_mask                  (cfg_bar1_mask),
    .cfg_bar2_mask                  (cfg_bar2_mask),
    .cfg_bar3_mask                  (cfg_bar3_mask),
    .cfg_bar4_mask                  (cfg_bar4_mask),
    .cfg_bar5_mask                  (cfg_bar5_mask),
    .radm_dv                        (radm_trgt0_dv),
    .radm_hv                        (radm_trgt0_hv),
    .radm_fm_np_rsvd                (radm_trgt0_np_rsvd),
    .radm_hdr                       (radm_trgt0_hdr[`RADM_P_HWD-1:0]),
    .radm_data                      (radm_trgt0_data[32*`CX_NW-1:0]),
    .radm_eot                       (radm_trgt0_eot),
    .radm_abort                     (radm_trgt0_abort),
    .radm_trgt0_pending             (radm_trgt0_pending),

    // local bus interface with external registers
    .ext_lbc_override_en            (ext_lbc_override_en),
    .ext_lbc_ack                    (mbar0_link_cap_ext_lbc_ack),
    .ext_lbc_din                    (mbar0_link_cap_ext_lbc_din),
    // from cdm
    .cdm_lbc_din                    (cdm_lbc_data),
    .cdm_lbc_ack                    (cdm_lbc_ack),
    .cxl_link_enable                (cxl_rcrb_enable),
    .cxl_mbar0_enable               (cxl_mbar0_enable),
    .cxl_2_0_comp_reg_offset        (cxl_2_0_comp_reg_offset[0]),
    .rcrb_mbar0_base_addr           (rcrb_mbar0_base_addr),
    .rcrb_base_addr                 (rcrb_address_reg),
   // from  XADM
    .xadm_cpl_halt                  (xaim_cpl_halt),

    //memory mapped device
    // external dbi interface designed for outband access
    .dbi_addr                       (int_dbi_addr),
    .dbi_din                        (int_dbi_din),
    .dbi_cs                         (int_dbi_cs),
    .dbi_cs2                        (int_dbi_cs2),
    .dbi_wr                         (int_dbi_wr),
    .dbi_ro_wr_en                   (dbi_ro_wr_en),
    .dbi_func_num                   (int_dbi_func_num),
    .dbi_bar_num                    (int_dbi_bar_num),
    .dbi_rom_access                 (int_dbi_rom_access),
    .dbi_io_access                  (int_dbi_io_access),


    .ras_err_inj_en_array           (ras_err_inj_en_array),
    .ras_err_inj_mask               (ras_err_inj_mask),

    .cfg_config_limit               (cfg_config_limit),


//----------- outputs -------------------------
    .ras_err_inj_done               (ras_err_inj_done_lbc),
    // external dbi interface designed for outband access
    .lbc_dbi_dout                   (int_lbc_dbi_dout),
    .lbc_dbi_ack                    (int_lbc_dbi_ack),

    // to XADM as completion request of device local bus read or write
    .lbc_cpl_hv                     (lbc_cpl_hv),
    .lbc_cpl_dv                     (lbc_cpl_dv),
    .lbc_cpl_hdr                    (lbc_cpl_hdr),
    .lbc_cpl_data                   (lbc_cpl_data),
    .lbc_cpl_eot                    (lbc_cpl_eot),
    .lbc_xmt_cpl_ca                 (lbc_xmt_cpl_ca),

    // local bus interface with cdm to read registers locally
    .lbc_cdm_addr                   (lbc_cdm_addr),
    .lbc_cdm_data                   (lbc_cdm_data),
    .lbc_cdm_cs                     (lbc_cdm_cs),
    .lbc_cdm_wr                     (lbc_cdm_wr),
    .lbc_cdm_dbi                    (lbc_cdm_dbi),
    .lbc_cdm_dbi2                   (lbc_cdm_dbi2),
    .lbc_cdm_unroll                 (lbc_cdm_unroll),
    .lbc_cdm_rcrb_wire              (lbc_cdm_rcrb_wire),
    .lbc_cdm_rcrb_dbi               (lbc_cdm_rcrb_dbi),
    .lbc_cdm_rcrb_mbar0_wire        (lbc_cdm_rcrb_mbar0_wire),
    .lbc_cdm_rcrb_mbar0_dbi         (lbc_cdm_rcrb_mbar0_dbi),
    // local bus interface with external registers
    .lbc_ext_addr                   (lbc_ext_addr),
    .lbc_ext_dout                   (lbc_ext_dout),
    
    .lbc_ext_cs                     (temp_lbc_ext_cs), // To CXL MEMBAR0 Link Cap Reg
    .lbc_ext_valid                  (lbc_ext_valid),
    .lbc_ext_dbi_access             (lbc_ext_dbi_access),
    .lbc_ext_cxl_mbar0_access       (lbc_ext_cxl_mbar0_access),
    .lbc_mbar0_link_cap_access      (lbc_mbar0_link_cap_access),
    .lbc_ext_wr                     (lbc_ext_wr),
    .lbc_ext_rd                     (lbc_ext_rd),
    .lbc_ext_rom_access             (lbc_ext_rom_access),
    .lbc_ext_io_access              (lbc_ext_io_access),
    .lbc_ext_bar_num                (lbc_ext_bar_num),





    //DE: Deadlock fix
    .pm_l1_aspm_entr                (pm_l1_aspm_entr),
    .lbc_deadlock_det               (lbc_deadlock_det),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff),         //input

    // radm block interface control signal to allowback pressure applied to radm queues.
    .trgt0_radm_halt                (trgt0_radm_halt),
    .lbc_active                     (lbc_active)

    ,.b_cfgi_lbc_pcie               (b_cfgi_lbc_pcie)
    ,.b_cfgi_lbc_cxl                (b_cfgi_lbc_cxl)
); // lbc

// -----------------------------------------------------------------------------
// Message TLP Generation
// -----------------------------------------------------------------------------

msg_gen

#(INST) u_msg_gen(
// ---------- Inputs --------
    .core_rst_n                     (core_rst_n),
    .core_clk                       (core_clk),
    .device_type                    (device_type_o),
    .pm_xtlh_block_tlp              (pm_xtlh_block_tlp),
    .cfg_nond0_vdm_block            (cfg_nond0_vdm_block),
    .pm_pme                         (pm_xmt_pme),
    .pm_asnak                       (pm_xmt_asnak),                 // N/A for endpoint
    .pme_turn_off                   (pm_xmt_turnoff),               // N/A for endpoint
    .pme_to_ack                     (pm_xmt_to_ack),
    .send_cor_err                   (cfg_send_cor_err),
    .send_nf_err                    (cfg_send_nf_err),
    .send_f_err                     (cfg_send_f_err),
    .cfg_func_spec_err              (cfg_func_spec_err),
    .unlock                         (pm_unlock_msg_req),            // N/A for endpoint
    .idle_msg                       (app_obff_idle_msg_req),
    .obff_msg                       (app_obff_obff_msg_req),
    .cpu_active_msg                 (app_obff_cpu_active_msg_req),
    .inta_wire                      (inta_wire),
    .intb_wire                      (intb_wire),
    .intc_wire                      (intc_wire),
    .intd_wire                      (intd_wire),
//    .nhp_int                        ({`CX_NFUNC{1'b0}}),                   // not used
    .cfg_bus_master_en              (cfg_bus_master_en),
    .cfg_slot_pwr_limit_wr          (cfg_slot_pwr_limit_wr[0]),     // N/A for endpoint
    .rdlh_link_up                   (rdlh_link_up),
    .pm_bus_num                     (pm_bus_num),
    .pm_dev_num                     (pm_dev_num),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_msi_addr                   (cfg_msi_addr),
    .cfg_msi_data                   (cfg_msi_data),
    .cfg_msi_64                     (cfg_msi_64),
    .cfg_multi_msi_en               (cfg_multi_msi_en),
    .cfg_msix_en                    (cfg_msix_en),                  // N/A for RC
    .msix_addr                      (msix_addr),                    // N/A for RC
    .msix_data                      (msix_data),                    // N/A for RC
    .app_ltr_msg_req                (app_ltr_msg_req),
    .app_ltr_msg_latency            (app_ltr_msg_latency),
    .app_ltr_msg_func_num           (app_ltr_msg_func_num),
    .cdm2msgg_ltr_clr_msg_req       (cdm2msgg_ltr_clr_msg_req),
    .ven_msi_req                    (ven_msi_req),                  // N/A for RC
    .ven_msi_func_num               (ven_msi_func_num),              // N/A for RC
    .ven_msi_tc                     (ven_msi_tc),                   // N/A for RC
    .ven_msi_vector                 (ven_msi_vector),               // N/A for RC

    .xadm_msg_halt                  (xaim_msg_halt),
    .set_slot_pwr_limit_val         (cfg_slot_pwr_limit_val),
    .set_slot_pwr_limit_scale       (cfg_slot_pwr_limit_scale),

    .ven_msg_fmt                    (ven_msg_fmt),
    .ven_msg_type                   (ven_msg_type),
    .ven_msg_tc                     (ven_msg_tc),
    .ven_msg_td                     (ven_msg_td),
    .ven_msg_ep                     (ven_msg_ep),
    .ven_msg_attr                   (ven_msg_attr),
    .ven_msg_len                    (ven_msg_len),
    .ven_msg_func_num               (ven_msg_func_num),
    .ven_msg_tag                    (ven_msg_tag),
    .ven_msg_code                   (ven_msg_code),
    .ven_msg_data                   (ven_msg_data),
    .ven_msg_req                    (ven_msg_req),

    .pm_dstate                      (pm_dstate),
    .app_req_retry_en               (app_req_retry_en),
    .app_pf_req_retry_en            (app_pf_req_retry_en),
    .app_drs_ready                  (app_drs_ready),
    .app_pf_frs_ready               (app_pf_frs_ready),
    .cfg_rasdp_error_mode           (cfg_rasdp_error_mode_i),
    .ras_err_inj_en_array           (ras_err_inj_en_array),
    .ras_err_inj_mask               (ras_err_inj_mask),

    .ptm_request_msg                (ptm_request_msg),
    .ptm_res_msg                    (ptm_res_msg),
    .ptm_res_d_msg                  (ptm_res_d_msg),
    .ptm_master_time                (ptm_master_time),
    .ptm_prop_delay                 (ptm_prop_delay),
    .cfg_auto_slot_pwr_lmt_dis      (cfg_auto_slot_pwr_lmt_dis),


// ---------- Outputs --------
    .ras_err_inj_done               (ras_err_inj_done_msg_gen),
    .msg_gen_hv                     (msg_gen_hv),
    .msg_gen_dv                     (msg_gen_dv),
    .msg_gen_eot                    (msg_gen_eot),
    .msg_gen_data                   (msg_gen_data),
    .msg_gen_hdr                    (msg_gen_hdr),
    .app_obff_msg_grant             (app_obff_msg_grant),

    .pf_frs_grant                   (pf_frs_grant),
    .app_ltr_msg_grant              (app_ltr_msg_grant),
    .msgg2cdm_ltr_clr_msg_grant     (msgg2cdm_ltr_clr_msg_grant),
    .assert_inta_grt            (assert_inta_grt),
    .assert_intb_grt            (assert_intb_grt),
    .assert_intc_grt            (assert_intc_grt),
    .assert_intd_grt            (assert_intd_grt),
    .deassert_inta_grt          (deassert_inta_grt),
    .deassert_intb_grt          (deassert_intb_grt),
    .deassert_intc_grt          (deassert_intc_grt),
    .deassert_intd_grt          (deassert_intd_grt),
    .ven_msg_grant                  (ven_msg_grant),
    .ven_msi_grant                  (ven_msi_grant),                // N/A for RC
    .pme_to_ack_grt                 (pme_to_ack_grt),
    .pm_pme_grant                   (pm_pme_grant),
    .pme_turn_off_grt               (pme_turn_off_grt)
    ,
    .pmstate_d3hot_to_d0            (pmstate_d3hot_to_d0)
    ,
    .msg_gen_asnak_grt              (msg_gen_asnak_grt),
    .msg_gen_unlock_grant           (msg_gen_unlock_grant)
    ,.msggen_cdm_send_f_err         (msggen_cdm_send_f_err  )
    ,.msggen_cdm_send_nf_err        (msggen_cdm_send_nf_err )
); // msg_gen

// ----------------------------------------------------------------------
// Instantiate reset request control logic
// ----------------------------------------------------------------------

logic     int_flush_ack;
logic     int_brdg_slv_xfer_pending;
logic     int_brdg_dbi_xfer_pending;
assign int_flush_ack             = brdg_slv_flush_ack;
assign int_brdg_slv_xfer_pending = brdg_slv_xfer_pending;
assign int_brdg_dbi_xfer_pending = brdg_dbi_xfer_pending;


  DWC_pcie_rst_ctl
  
  u_rstctl
  (
  // Clocks and resets
  .core_clk                           (core_clk)
  ,.core_rst_n                        (core_rst_n)
  // Configuration interface
  ,.cfg_fast_link_mode                (cfg_fast_link_mode)
  ,.cfg_fast_link_scaling_factor      (cfg_fast_link_scaling_factor)
  ,.cfg_auto_flush_en                 (cfg_auto_flush_en)
  ,.cfg_auto_flush_timeout            (cfg_auto_flush_timeout)
  // Application Reset Control Interface
  ,.app_ltssm_enable                  (app_ltssm_enable & cxl_ltssm_enable)
  ,.rstctl_ltssm_enable               (rstctl_ltssm_enable)
  // Link Status Interface
  ,.smlh_ltssm_in_hotrst_dis_entry    (int_rstctl_flush_enable)
  ,.smlh_req_rst_not                  (smlh_req_rst_not)
  ,.smlh_link_up                      (int_smlh_link_up)
  ,.rdlh_link_up                      (rdlh_link_up)
  // Link Timer Interface
  ,.cfg_link_timeout_en_n             (cfg_link_timeout_en_n)
  ,.cfg_link_timeout_period           (cfg_link_timeout_period)
  ,.current_data_rate                 (int_current_data_rate)


  // Transfer Pending Interface
  ,.brdg_dbi_xfer_pending             (int_brdg_dbi_xfer_pending)
  ,.brdg_slv_xfer_pending             (int_brdg_slv_xfer_pending)
  ,.edma_xfer_pending                 (edma_xfer_pending)
  ,.brdg_mstr_xfer_pending            (brdg_mstr_xfer_pending)
  ,.radm_idle                         (radm_idle)
  // Flush Control Interface
  ,.rstctl_core_flush_req             (rstctl_core_flush_req)
  ,.rstctl_mstr_flush_req             (rstctl_mstr_flush_req)
  ,.rstctl_slv_flush_req              (rstctl_slv_flush_req)
  ,.rstctl_flush_done                 (rstctl_flush_done)
  ,.flush_ack                         (int_flush_ack)
  ,.app_req_flush                     (app_req_flush)
  // Reset Request Interface
  ,.rstctl_req_rst_not                (link_req_rst_not)
  );


//---------------------------------------------------------------------------------------
// Assign Outputs
//---------------------------------------------------------------------------------------
  assign cfg_axi_clk_gating_en = cfg_clock_gating_ctrl[1];

// ================================= Diagnostic Bus Assignment =================================================
// Diagnostic mechanism is designed in core by routing the important internal signals to application dynamically.
// Diagnostic mechanism is designed in core by taking control signals from application to insert a defined behavor of the core.
// Diagnotic status signals are groupped together from different layers of the core


//---------------------------------------------------------------------------------------
// Functions
//---------------------------------------------------------------------------------------
 // Function to grab a byte from a bus
function automatic [15:0] get_req_id;
input   [`CX_BUSNUM_WD -1:0]            bus_num;
input   [`CX_DEVNUM_WD -1:0]            dev_num;
input   [`CX_NFUNC_WD-1:0]                 func_num;
input    [3:0]                      device_type;
integer                             i;
reg     [7:0]                       int_bus_num;
reg     [4:0]                       int_dev_num;
reg     [7:0]                       int_func_num;

begin
    int_bus_num = 0;
    int_dev_num = 0;
    int_func_num = 0;
    int_func_num[`CX_NFUNC_WD-1:0]    = func_num[`CX_NFUNC_WD-1:0]   ;
    int_bus_num = bus_num;
    int_dev_num = dev_num;
    get_req_id     = {int_bus_num, int_dev_num, int_func_num[2:0]};
end
endfunction

// Function to grab a byte from a bus
function automatic [7:0] Bget;
input   [`CX_BUSNUM_WD-1:0]                vector;
input   [`CX_NFUNC-1:0]                    onehot_index;
integer                             i;

begin
    Bget = vector[7:0];
end
endfunction

// Function to grab a 5-bit slice from a bus
function automatic [4:0] Qget;
input   [`CX_DEVNUM_WD-1:0]                vector;
input   [`CX_NFUNC-1:0]                    onehot_index;
integer                             i;

begin
    Qget = vector[4:0];
end
endfunction

function automatic [`TRGT_DATA_WD -1:0] add_data_par;
input [32*`CX_NW -1:0]   in_data;
input [`TRGT_DATA_PROT_WD -1:0]   in_par;
integer i, j;
begin
    add_data_par = 'd0;
    for (i=0; i<`TRGT_DATA_PROT_WD; i=i+1) begin
       for (j=0; j<`DATA_BUS_PAR_CALC_WIDTH; j=j+1) begin
        add_data_par[i*`DATA_BUS_PAR_CALC_WIDTH +j+i] = in_data[i*`DATA_BUS_PAR_CALC_WIDTH +j];
       end
        add_data_par[(i + 1)*`DATA_BUS_PAR_CALC_WIDTH + i] = in_par[i];
    end
end
endfunction

function automatic [`DATA_BUS_PAR_CALC_WIDTH -1:0] Vecget_data;
input [32*`CX_NW -1:0]   vector;
input integer            index;

integer i;
begin
    for (i=`DATA_BUS_PAR_CALC_WIDTH -1; i>=0; i=i-1) begin
        Vecget_data[i] = vector[index*`DATA_BUS_PAR_CALC_WIDTH +i];
    end
end
endfunction

function automatic [`TRGT_DATA_PROT_WD -1:0] calc_data_par;
input [32*`CX_NW -1:0]   in_data;
integer i;
begin
    calc_data_par =0;
    for (i=0; i<`TRGT_DATA_PROT_WD; i=i+1) begin
        calc_data_par[i] = ^Vecget_data(in_data, i);
    end
end
endfunction

localparam IN_PAR_WD = (`CC_DEVICE_TYPE==`CC_EP) ? CORE_ADDR_PAR_WD : `CX_ADDR_PAR_WD;
function automatic  [`CC_CORE_ADDR_BUS_WD -1 :0] add_addr_par;
input [63 : 0]   in_addr;
input [IN_PAR_WD-1:0]   in_par;
integer i, j;
reg [71:0] out_addr;
begin
    out_addr =0;
    for (i=0; i<IN_PAR_WD; i=i+1) begin
       for (j=0; j<`ADDR_BUS_PAR_CALC_WIDTH; j=j+1) begin
        out_addr[i*`ADDR_BUS_PAR_CALC_WIDTH +j+i] = in_addr[i*`ADDR_BUS_PAR_CALC_WIDTH +j];
       end
        out_addr[(i+1)*`ADDR_BUS_PAR_CALC_WIDTH + i] = in_par[i];
    end
    add_addr_par = out_addr[`CC_CORE_ADDR_BUS_WD -1 : 0];
end
endfunction

localparam IN_ADDR_WD = (`CC_DEVICE_TYPE==`CC_EP) ? `FLT_Q_ADDR_WIDTH : 64;
function automatic [`ADDR_BUS_PAR_CALC_WIDTH -1:0] Vecget_addr;
input [IN_ADDR_WD-1:0]   vector;
input integer  index;

integer i;
begin
    for (i=`ADDR_BUS_PAR_CALC_WIDTH -1; i>=0; i=i-1) begin
        Vecget_addr[i] = vector[index*`ADDR_BUS_PAR_CALC_WIDTH +i];
    end
end
endfunction

function automatic [IN_PAR_WD-1:0] calc_addr_par;
input [IN_ADDR_WD-1:0]   in_addr;
integer i;
begin
    calc_addr_par =0;
    for (i=0; i<IN_PAR_WD; i=i+1) begin
        calc_addr_par[i] = ^Vecget_addr(in_addr, i);
    end
end
endfunction

// Function to assign 1 bit radm_rtlh_*h_ca to multi-bits int_rtlh_*h_ca
function automatic [DCA_WD*`CX_NVC-1:0] credit_mapping;
input   [`CX_NVC-1:0]                radm_h_ca;
integer                             i;

begin
    credit_mapping = 0;
    for(i=0;i<`CX_NVC;i=i+1) begin
            credit_mapping[i*DCA_WD] = radm_h_ca[i];
    end
end
endfunction




`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule

