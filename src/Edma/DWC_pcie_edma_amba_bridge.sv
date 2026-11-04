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
// ---    $DateTime: 2024/02/16 06:53:13 $
// ---    $Revision: #55 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_amba_bridge.sv#55 $
// -------------------------------------------------------------------------
// --- Module description:
// --- Top level modules:
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Axi/DWC_pcie_axi_mstr_pkg.svh"
`include "Axi/DWC_pcie_axi_slv_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Axi/DWC_pcie_axi_bridge_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_hard_stop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_status_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_bypass_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_header_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_wresp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"


 module DWC_pcie_edma_amba_bridge
import DWC_pcie_ctl_pkg::N_XADM_P_IF;
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_ctl_pkg::PRFX_W_PAR;
import DWC_pcie_edmapf_pkg::*;
//import DWC_pcie_tlp_pkg::*;
import DWC_pcie_tlp_pkg::xradm_s;
import DWC_pcie_tlp_pkg::timeout_s;
import DWC_pcie_tlp_pkg::f_tlp_bytelen2dwlen;
import DWC_pcie_tlp_pkg::f_tlp_dwlen2bytelen;
import DWC_pcie_tlp_pkg::dma_req_type_e;
import DWC_pcie_tlp_pkg::E_DMA_BYPASS_CPL;
import DWC_pcie_tlp_pkg::E_DMA_BYPASS;
import DWC_pcie_tlp_pkg::E_DMA_RDCH_DATA;
import DWC_pcie_tlp_pkg::K_PRFXWD;
import DWC_pcie_ctl_pkg::K_DMA_RBUF_SLICE_WD;
import DWC_pcie_ctl_pkg::K_DMA_RBUF_NSLICES;
import DWC_pcie_ctl_pkg::CRGB_DATA_WIDTH;
import DWC_pcie_ctl_pkg::ATU_OUT_NREGIONS_MIN1;

import DWC_pcie_axi_bridge_pkg::TX_TLP_PREFIX_WD;
import DWC_pcie_axi_bridge_pkg::PRFX_WIDTH;
import DWC_pcie_axi_bridge_pkg::TPH_ST_WD;
import DWC_pcie_axi_bridge_pkg::TPH_PH_WD;
import DWC_pcie_axi_bridge_pkg::TPH_TH_WD;
import DWC_pcie_axi_bridge_pkg::MISC_INFO_TPH_WD;
import DWC_pcie_axi_bridge_pkg::HDR_UPPR_BYTES_WD;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 (
                                  // Inputs

                                  cfg_axi_clk_gating_en,
                                  cfg_err_resp_mode,
                                  cfg_slv_resp_err_map,
                                  cfg_max_payload_size,
                                  cfg_max_rd_req_size,
                                  cfg_ext_tag_en,
                                  cfg_10b_tag_en,
                                  cfg_dmwr_req_en,
                                  cfg_memtype_value,
                                  cfg_memtype_boundary,
                                  cfg_ax_mstr_np_pass_p,
                                  cfg_ax_mstr_ordr_p_event_sel,
                                  cfg_ax_ib_cpl_pass_p,
                                  cfg_ax_snp_en,
                                  cfg_ib_p_id_mng_ctrl,
                                  cfg_tc_struc_vc_map,
                                  xali_posted_tlp_sent,
   // ***************************************************
   // RAS.DP IO
   // ***************************************************
   cfg_rasdp_err_mode,
   cfg_rasdp_err_mode_en,
   axi_bridge_out_ras_dp_err_log,
   axi_bridge_in_ras_dp_err_inj,
   axi_bridge_in_ras_dp_err_inj_wake_up,
    hdma_ras_dp_err_log,
    hdma_ras_dp_err_inj,
   // RAS ECC RAM interface
   cfg_ras_recc_npw_sab_correct,
   axi_ras_recc_corr_cnt_npw_sab_pulse,
   axi_ras_recc_corr_cnt_npw_sab_addr,
   axi_ras_recc_ucorr_cnt_npw_sab_pulse,
   axi_ras_recc_ucorr_cnt_npw_sab_addr,

   cfg_ras_recc_ob_npdcmp_correct,
   axi_ras_recc_corr_cnt_ob_npdcmp_pulse,
   axi_ras_recc_corr_cnt_ob_npdcmp_addr,
   axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse,
   axi_ras_recc_ucorr_cnt_ob_npdcmp_addr,

   cfg_ras_recc_ob_pdcmp_hdr_correct,
   axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse,
   axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr,
   axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse,
   axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr,

   cfg_ras_recc_ob_pdcmp_data_correct,
   axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse,
   axi_ras_recc_corr_cnt_ob_pdcmp_data_addr,
   axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse,
   axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr,

   cfg_ras_recc_ob_ccmp_data_correct,
   axi_ras_recc_corr_cnt_ob_ccmp_data_pulse,
   axi_ras_recc_corr_cnt_ob_ccmp_data_addr,
   axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse,
   axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr,

   cfg_ras_recc_ib_sch_p_hdr_correct,
   axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse,
   axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr,
   axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse,
   axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr,
   cfg_ras_recc_ib_sch_p_data_correct,
   axi_ras_recc_corr_cnt_ib_sch_p_data_pulse,
   axi_ras_recc_corr_cnt_ib_sch_p_data_addr,
   axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse,
   axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr,
   cfg_ras_recc_ib_sch_np_hdr_correct,
   axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse,
   axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr,
   axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse,
   axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr,
   cfg_ras_recc_ib_sch_np_data_correct,
   axi_ras_recc_corr_cnt_ib_sch_np_data_pulse,
   axi_ras_recc_corr_cnt_ib_sch_np_data_addr,
   axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse,
   axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr,
   cfg_ras_recc_ib_rreq_c2a_cdc_correct,
   axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse,
   axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr,
   axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse,
   axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr,

   cfg_ras_recc_ib_wreq_c2a_cdc_correct,
   axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse,
   axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr,
   axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse,
   axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr,

   cfg_ras_recc_ib_mcpl_a2c_cdc_correct,
   axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse,
   axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr,
   axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse,
   axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr,


   cfg_ras_recc_ib_mcpl_sb_correct,
   axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse,
   axi_ras_recc_corr_cnt_ib_mcpl_sb_addr,
   axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse,
   axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr,



    axi_ras_par_rtrgt_p_ad_pulse,
    axi_ras_par_rtrgt_p_dt_pulse,
    axi_ras_par_rtrgt_np_ad_pulse,
    axi_ras_par_rtrgt_np_dt_pulse,
    axi_ras_par_rtrgt_cpl_ad_pulse,
    axi_ras_par_rtrgt_cpl_dt_pulse,
    axi_ras_par_ib_mcpl_dt_pulse,



    axi_ras_par_ibwr_dcmp_dt_pulse,
    axi_ras_par_ibwr_dcmp_ad_pulse,
    axi_ras_par_ibrd_dcmp_ad_pulse,



    axi_ras_par_ib_sch_p_ad_pulse,
    axi_ras_par_ib_sch_p_dt_pulse,
    axi_ras_par_ib_sch_np_ad_pulse,
    axi_ras_par_ib_sch_np_dt_pulse,
    axi_ras_par_ib_mcpl_a2c_dt_pulse,
    axi_ras_par_ib_mcpl_sb_dt_pulse,

    axi_ras_par_ibwq_mrf_dt_pulse,
    axi_ras_par_ibwq_mrf_ad_pulse,
    axi_ras_par_ibrd_mrf_ad_pulse,

    axi_ras_par_npqdec_ad_pulse,

    axi_ras_par_pqdec_ad_pulse,
    axi_ras_par_swwrap_dt_pulse,
    axi_ras_par_swwrap_ad_pulse,
    axi_ras_par_srwrap_ad_pulse,
    axi_ras_par_swrq_npw_dt_pulse,
    axi_ras_par_swrq_npw_ad_pulse,
    axi_ras_par_slnull_dt_pulse,
    axi_ras_par_slnull_ad_pulse,

    axi_ras_par_c2_ad_pulse,
    axi_ras_par_c2_dt_pulse,
    axi_ras_par_c1_ad_pulse,
    axi_ras_par_c1_dt_pulse,

    axi_ras_par_ob_np_dcmp_inq_dt_pulse,
    axi_ras_par_ob_p_dcmp_inq_dt_pulse,
    axi_ras_par_ob_cpl_comp_dt_pulse,
    axi_slv_sisb_uncorr_pulse,
    axi_mstr_misb_uncorr_pulse,



                                  cfg_mstr_arcache_mode,
                                  cfg_mstr_awcache_mode,
                                  cfg_mstr_arcache_value,
                                  cfg_mstr_awcache_value,
                                  cfg_aximstr_msg_addr_high,
                                  cfg_aximstr_msg_addr_low,
                                  cfg_mstr_ardomain_mode,
                                  cfg_mstr_awdomain_mode,
                                  cfg_mstr_ardomain_value,
                                  cfg_mstr_awdomain_value,
                                  cfg_ax_mstr_zeroread_fw,
                                  atu_reg_out_base,
                                  atu_reg_out_en,
                                  atu_reg_out_invert,
                                  atu_reg_out_limit,
                                  atu_reg_out_uppr_limit,
                                  atu_reg_out_incr_rgn_size,
                                  atu_reg_out_type,
                                  atu_reg_out_upr_base,
                                  atu_reg_out_func_num,
                                  atu_reg_out_func_bypass,
                                  atu_reg_out_snp,
                                  core_clk,
                                  core_rst_n,
                                  crgb_address,
                                  crgb_rden,
                                  crgb_source,
                                  crgb_wr_data,
                                  crgb_wren,


                                  mstr_aclk_g,
                                  mstr_aresetn,
                                  mstr_aclk,
                                  en_mstr_aclk_g,
                                  mstr_rasdp_err_mode,
                                  mstr_awready,
                                  mstr_wready,
                                  mstr_bid,
                                  mstr_bvalid,
                                  mstr_bresp,
                                  mstr_bmisc_info_cpl_stat,
                                  mstr_arready,
                                  mstr_rid,
                                  mstr_rvalid,
                                  mstr_rlast,
                                  mstr_rdata,
                                  mstr_ruser,
                                  mstr_rresp,
                                  mstr_rmisc_info_cpl_stat,
                                  mstr_rmisc_info,
  
                                  mstr_csysreq,
                                  mstr_awqos,
                                  mstr_awbar,
                                  mstr_awdomain,
                                  mstr_awsnoop,
                                  mstr_awatop,
                                  mstr_arqos,
                                  mstr_arbar,
                                  mstr_ardomain,
                                  mstr_arsnoop,



                                  trgt_lookup_id,

                                  radm_trgt1_p_0_pending,

                                  radm_trgt1_p_0_data,
                                  radm_trgt1_p_0_hdr_prot,
                                  radm_trgt1_p_0_prfx,
                                  radm_trgt1_p_0_dwen,
                                  radm_trgt1_p_0_dv,
                                  radm_trgt1_p_0_hv,
                                  radm_trgt1_p_0_eot,
                                  radm_trgt1_p_0_dllp_abort,
                                  radm_trgt1_p_0_tlp_abort,
                                  radm_trgt1_p_0_ecrc_err,
                                  radm_trgt1_p_0_fmt,
                                  radm_trgt1_p_0_type,
                                  radm_trgt1_p_0_tc,
                                  radm_trgt1_p_0_attr,
                                  radm_trgt1_p_0_reqid,
                                  radm_trgt1_p_0_tag,
                                  radm_trgt1_p_0_func_num,
                                  radm_trgt1_p_0_td,
                                  radm_trgt1_p_0_poisoned,
                                  radm_trgt1_p_0_dw_len,
                                  radm_trgt1_p_0_first_be,
                                  radm_trgt1_p_0_vc_num,
                                  radm_trgt1_p_0_cpl_status,
                                  radm_trgt1_p_0_addr,
                                  radm_trgt1_p_0_hdr_uppr_bytes,
                                  radm_trgt1_p_0_rom_in_range,
                                  radm_trgt1_p_0_io_req_in_range,
                                  radm_trgt1_p_0_in_membar_range,
                                  radm_trgt1_p_0_last_be,
                                  radm_trgt1_p_0_ats,
                                  radm_trgt1_p_0_nw,
                                  radm_trgt1_p_0_cxlsrc,
                                  radm_trgt1_p_0_th,
                                  radm_trgt1_p_0_ph,
                                  radm_trgt1_p_0_st,
                                  radm_trgt1_p_0_hdr_uppr_bytes_valid,
                                  radm_trgt1_p_0_reqtr_sgmt,
                                  radm_trgt1_p_0_dest_sgmt,
                                  radm_trgt1_p_0_pkt_order_no,

                                  radm_trgt1_np_0_data,
                                  radm_trgt1_np_0_hdr_prot,
                                  radm_trgt1_np_0_prfx,
                                  radm_trgt1_np_0_dwen,
                                  radm_trgt1_np_0_dv,
                                  radm_trgt1_np_0_hv,
                                  radm_trgt1_np_0_eot,
                                  radm_trgt1_np_0_dllp_abort,
                                  radm_trgt1_np_0_tlp_abort,
                                  radm_trgt1_np_0_ecrc_err,
                                  radm_trgt1_np_0_fmt,
                                  radm_trgt1_np_0_type,
                                  radm_trgt1_np_0_tc,
                                  radm_trgt1_np_0_attr,
                                  radm_trgt1_np_0_reqid,
                                  radm_trgt1_np_0_tag,
                                  radm_trgt1_np_0_func_num,
                                  radm_trgt1_np_0_cpl_status,
                                  radm_trgt1_np_0_td,
                                  radm_trgt1_np_0_poisoned,
                                  radm_trgt1_np_0_dw_len,
                                  radm_trgt1_np_0_first_be,
                                  radm_trgt1_np_0_vc_num,
                                  radm_trgt1_np_0_addr,
                                  radm_trgt1_np_0_hdr_uppr_bytes,
                                  radm_trgt1_np_0_rom_in_range,
                                  radm_trgt1_np_0_io_req_in_range,
                                  radm_trgt1_np_0_in_membar_range,
                                  radm_trgt1_np_0_last_be,
                                  radm_trgt1_np_0_ats,
                                  radm_trgt1_np_0_nw,
                                  radm_trgt1_np_0_cxlsrc,
                                  radm_trgt1_np_0_th,
                                  radm_trgt1_np_0_ph,
                                  radm_trgt1_np_0_st,
                                  radm_trgt1_np_0_reqtr_sgmt,
                                  radm_trgt1_np_0_dest_sgmt,
                                  radm_trgt1_np_0_pkt_order_no,

                                  radm_trgt1_cpl_0_data,
                                  radm_trgt1_cpl_0_hdr_prot,
                                  radm_trgt1_cpl_0_prfx,
                                  radm_trgt1_cpl_0_dwen,
                                  radm_trgt1_cpl_0_dv,
                                  radm_trgt1_cpl_0_hv,
                                  radm_trgt1_cpl_0_eot,
                                  radm_trgt1_cpl_0_dllp_abort,
                                  radm_trgt1_cpl_0_tlp_abort,
                                  radm_trgt1_cpl_0_ecrc_err,
                                  radm_trgt1_cpl_0_fmt,
                                  radm_trgt1_cpl_0_type,
                                  radm_trgt1_cpl_0_tc,
                                  radm_trgt1_cpl_0_attr,
                                  radm_trgt1_cpl_0_reqid,
                                  radm_trgt1_cpl_0_tag,
                                  radm_trgt1_cpl_0_func_num,
                                  radm_trgt1_cpl_0_cpl_status,
                                  radm_trgt1_cpl_0_td,
                                  radm_trgt1_cpl_0_poisoned,
                                  radm_trgt1_cpl_0_dw_len,
                                  radm_trgt1_cpl_0_bcm,
                                  radm_trgt1_cpl_0_byte_cnt,
                                  radm_trgt1_cpl_0_cmpltr_id,
                                  radm_trgt1_cpl_0_last,
                                  radm_trgt1_cpl_0_vc_num,
                                  radm_trgt1_cpl_0_addr,
                                  radm_trgt1_cpl_0_dest_sgmt,
                                  radm_trgt1_cpl_0_cpl_sgmt,
                                  radm_trgt1_cpl_0_pkt_order_no,

                                  trgt1_radm_intf_cpl_0_halt,
                                  trgt1_radm_intf_p_0_halt,
                                  trgt1_radm_intf_np_0_halt,
                                  radm_cpl_timeout,
                                  radm_timeout_cpl_attr,
                                  radm_timeout_cpl_tag,
                                  radm_timeout_cpl_tc,
                                  radm_timeout_func_num,
                                  slv_aclk_g,
                                  slv_aresetn,
                                  slv_aclk,
                                  en_slv_aclk_g,
                                  slv_rasdp_err_mode,
                                  slv_awaddr,
                                  slv_awuser,
                                  slv_awburst,
                                  slv_awcache,
                                  slv_awid,
                                  slv_awlen,
                                  slv_awlock,
                                  slv_awmisc_info,
                                  slv_awmisc_info_hdr_34dw,
                                  slv_awmisc_info_nw,
                                  slv_awmisc_info_ats,
                                  slv_awmisc_info_tlpprfx,
                                  slv_awmisc_info_p_tag,
                                  slv_awmisc_info_tph,
                                  slv_awmisc_info_atu_bypass,
                                  slv_awmisc_info_ido,
                                  slv_awmisc_info_dst_segment,
                                  slv_awprot,
                                  slv_awsize,
                                  slv_awvalid,
  
                                  slv_wdata,
                                  slv_wuser,
                                  slv_wlast,
                                  slv_wstrb,
                                  slv_wvalid,
                                  slv_wmisc_info_ep,
                                  slv_wmisc_info_silentDrop,

                                  slv_bready,
                                  slv_araddr,
                                  slv_aruser,
                                  slv_arburst,
                                  slv_arcache,
                                  slv_arid,
                                  slv_arlen,
                                  slv_arlock,
                                  slv_armisc_info,
                                  slv_armisc_info_nw,
                                  slv_armisc_info_ats,
                                  slv_armisc_info_tlpprfx,
                                  slv_armisc_info_tph,
                                  slv_armisc_info_atu_bypass,
                                  slv_armisc_info_ido,
                                  slv_armisc_info_dst_segment,
                                  slv_arprot,
                                  slv_arsize,
                                  slv_arvalid,

                                  slv_rready,
                                  slv_csysreq,

                                  cfg_pbus_dev_num,
                                  cfg_pbus_num,
                                  cfg_subbus_num,
                                  cfg_2ndbus_num,
                                  radm_trgt1_cpl_lookup_id_rlsd,
                                  radm_trgt1_lookup_id_consmd,

                                  // Outputs
                                  xali_xaim_pkt,
                                  xaim_xali_halt,
                                  crgb_ack,
                                  crgb_rd_data,


     dbi_addr,
     dbi_din,
     dbi_cs,
     dbi_cs2,
     dbi_wr,
     dbi_bar_num,
     dbi_func_num,
     dbi_rom_access,
     dbi_io_access,
     dbi_ack,
     dbi_dout,



                                  mstr_awaddr,
                                  mstr_awuser,
                                  mstr_awburst,
                                  mstr_awcache,
                                  mstr_awid,
                                  mstr_awlen,
                                  mstr_awlock,
                                  mstr_awmisc_info,
                                  mstr_awmisc_info_last_dcmp_tlp,
                                  mstr_awmisc_info_hdr_34dw,
                                  mstr_awmisc_info_nw,
                                  mstr_awmisc_info_cxlsrc,
                                  mstr_awmisc_info_ats,
                                  mstr_awmisc_info_ep,
                                  mstr_awmisc_info_dma,
                                  mstr_awmisc_info_tlpprfx,
                                  mstr_awmisc_info_tph,
                                  mstr_awmisc_info_ido,
                                  mstr_awmisc_info_dst_segment,
                                  mstr_awmisc_info_req_segment,
                                  mstr_awprot,
                                  mstr_awsize,
                                  mstr_awvalid,
                                  mstr_wdata,
                                  mstr_wuser,
                                  mstr_wlast,
                                  mstr_wstrb,
                                  mstr_wvalid,
                                  mstr_bready,
                                  mstr_araddr,
                                  mstr_aruser,
                                  mstr_arburst,
                                  mstr_arcache,
                                  mstr_arid,
                                  mstr_arlen,
                                  mstr_arlock,
                                  mstr_armisc_info,
                                  mstr_armisc_info_last_dcmp_tlp,
                                  mstr_armisc_info_nw,
                                  mstr_armisc_info_cxlsrc,
                                  mstr_armisc_info_ats,
                                  mstr_armisc_info_dma,
                                  mstr_armisc_info_tlpprfx,
                                  mstr_armisc_info_tph,
                                  mstr_armisc_info_ido,
                                  mstr_armisc_info_zeroread,
                                  mstr_armisc_info_dst_segment,
                                  mstr_armisc_info_req_segment,
                                  mstr_arprot,
                                  mstr_arsize,
                                  mstr_arvalid,
                                  mstr_rready,
                                  mstr_cactive,
                                  mstr_csysack,
                                  slv_awready,
                                  slv_wready,
                                  slv_bid,
                                  slv_bmisc_info,
                                  slv_bmisc_info_dst_segment,
                                  slv_bmisc_info_cpl_segment,
                                  slv_bresp,
                                  slv_bvalid,
 
                                  slv_arready,
                                  slv_rdata,
                                  slv_ruser,
                                  slv_rid,
                                  slv_rlast,
                                  slv_rmisc_info,
                                  slv_rmisc_info_ido,
                                  slv_rmisc_info_dst_segment,
                                  slv_rmisc_info_cpl_segment,
                                  slv_rresp,
                                  slv_rvalid,
  
                                  slv_cactive,
                                  slv_csysack,
                                  slv_awqos,
                                  slv_awbar,
                                  slv_awdomain,
                                  slv_awsnoop,
                                  slv_awatop,
                                  slv_arqos,
                                  slv_arbar,
                                  slv_ardomain,
                                  slv_arsnoop,
                                  brdg_mstr_xfer_pending,
                                  trgt_cpl_lut_empty,
                                  brdg_slv_xfer_pending,
                                  app_xfer_pending,
                                  brdg_dbi_xfer_pending,
                                  rstctl_slv_flush_req,
                                  rstctl_mstr_flush_req,
                                  brdg_slv_flush_ack,
  // External RAM Interfaces
  // Inbound
  // Inbound Read Request Clock Domain Crossing FIFO RAM
  ib_rreq_c2a_cdc_ram_addra,
  ib_rreq_c2a_cdc_ram_wea,
  ib_rreq_c2a_cdc_ram_dina,
  ib_rreq_c2a_cdc_ram_addrb,
  ib_rreq_c2a_cdc_ram_enb,
  ib_rreq_c2a_cdc_ram_doutb,
  // Inbound Write Request Clock Domain Crossing FIFO RAM
  ib_wreq_c2a_cdc_ram_addra,
  ib_wreq_c2a_cdc_ram_wea,
  ib_wreq_c2a_cdc_ram_dina,
  ib_wreq_c2a_cdc_ram_addrb,
  ib_wreq_c2a_cdc_ram_enb,
  ib_wreq_c2a_cdc_ram_doutb,
  // Inbound Master Completion Clock Domain Crossing FIFO RAM
  ib_mcpl_a2c_cdc_ram_addra,
  ib_mcpl_a2c_cdc_ram_wea,
  ib_mcpl_a2c_cdc_ram_dina,
  ib_mcpl_a2c_cdc_ram_addrb,
  ib_mcpl_a2c_cdc_ram_enb,
  ib_mcpl_a2c_cdc_ram_doutb,
  // Inbound Master Completion Data Segment FIFO RAM
  ib_mcpl_sb_ram_addra,
  ib_mcpl_sb_ram_wea,
  ib_mcpl_sb_ram_dina,
  ib_mcpl_sb_ram_addrb,
  ib_mcpl_sb_ram_enb,
  ib_mcpl_sb_ram_doutb,
  ib_scheduler_p_hdr_ram_wea,
  ib_scheduler_p_hdr_ram_addra,
  ib_scheduler_p_hdr_ram_dina,
  ib_scheduler_p_hdr_ram_addrb,
  ib_scheduler_p_hdr_ram_enb,
  ib_scheduler_p_hdr_ram_doutb,
  ib_scheduler_p_data_ram_wea,
  ib_scheduler_p_data_ram_addra,
  ib_scheduler_p_data_ram_dina,
  ib_scheduler_p_data_ram_addrb,
  ib_scheduler_p_data_ram_enb,
  ib_scheduler_p_data_ram_doutb,
  ib_scheduler_np_hdr_ram_wea,
  ib_scheduler_np_hdr_ram_addra,
  ib_scheduler_np_hdr_ram_dina,
  ib_scheduler_np_hdr_ram_addrb,
  ib_scheduler_np_hdr_ram_enb,
  ib_scheduler_np_hdr_ram_doutb,
  ib_scheduler_np_data_ram_wea,
  ib_scheduler_np_data_ram_addra,
  ib_scheduler_np_data_ram_dina,
  ib_scheduler_np_data_ram_addrb,
  ib_scheduler_np_data_ram_enb,
  ib_scheduler_np_data_ram_doutb,
  // Outbound
  // Slave Non-Posted Write Set-Aside RAM
  slv_npw_sab_ram_addra,
  slv_npw_sab_ram_wea,
  slv_npw_sab_ram_dina,
  slv_npw_sab_ram_addrb,
  slv_npw_sab_ram_enb,
  slv_npw_sab_ram_doutb,
  // Outbound Non-Posted TLP Decomposer FIFO RAM
  ob_npdcmp_ram_addra,
  ob_npdcmp_ram_wea,
  ob_npdcmp_ram_dina,
  ob_npdcmp_ram_addrb,
  ob_npdcmp_ram_enb,
  ob_npdcmp_ram_doutb,
  // Outbound Posted TLP Decomposer Header FIFO RAM
  ob_pdcmp_hdr_ram_addra,
  ob_pdcmp_hdr_ram_wea,
  ob_pdcmp_hdr_ram_dina,
  ob_pdcmp_hdr_ram_addrb,
  ob_pdcmp_hdr_ram_enb,
  ob_pdcmp_hdr_ram_doutb,
// Outbound Posted TLP Decomposer Data FIFO RAM
ob_pdcmp_data_ram_addra,
ob_pdcmp_data_ram_wea,
ob_pdcmp_data_ram_dina,
ob_pdcmp_data_ram_addrb,
ob_pdcmp_data_ram_enb,
ob_pdcmp_data_ram_doutb,
ob_ccmp_data_ram_addra,
ob_ccmp_data_ram_wea,
ob_ccmp_data_ram_dina,
ob_ccmp_data_ram_addrb,
ob_ccmp_data_ram_enb,
ob_ccmp_data_ram_doutb,
// Read buffer
edmarbuff2ram_addra,
edmarbuff2ram_we,
edmarbuff2ram_dout,
edmarbuff2ram_addrb,
edmarbuff2ram_re,
ram2edmarbuff_din,
edma_rd_eng_ll_addra_ram,
edma_rd_eng_ll_addrb_ram,
edma_rd_eng_ll_dout_ram,
edma_rd_eng_ll_we_ram,
edma_rd_eng_ll_re_ram,
edma_rd_eng_ll_din_ram,
edma_wr_eng_ll_addra_ram,
edma_wr_eng_ll_addrb_ram,
edma_wr_eng_ll_dout_ram,
edma_wr_eng_ll_we_ram,
edma_wr_eng_ll_re_ram,
edma_wr_eng_ll_din_ram,
edma_rd_eng_ovrl_addra_ram,
edma_rd_eng_ovrl_addrb_ram,
edma_rd_eng_ovrl_dout_ram,
edma_rd_eng_ovrl_we_ram,
edma_rd_eng_ovrl_re_ram,
edma_rd_eng_ovrl_din_ram,
edma_wr_eng_ovrl_addra_ram,
edma_wr_eng_ovrl_addrb_ram,
edma_wr_eng_ovrl_dout_ram,
edma_wr_eng_ovrl_we_ram,
edma_wr_eng_ovrl_re_ram,
edma_wr_eng_ovrl_din_ram,
edma_rd_eng_c2w_lut_addra_ram,
edma_rd_eng_c2w_lut_addrb_ram,
edma_rd_eng_c2w_lut_dout_ram,
edma_rd_eng_c2w_lut_we_ram,
edma_rd_eng_c2w_lut_re_ram,
edma_rd_eng_c2w_lut_din_ram,
edma_wr_eng_c2w_lut_addra_ram,
edma_wr_eng_c2w_lut_addrb_ram,
edma_wr_eng_c2w_lut_dout_ram,
edma_wr_eng_c2w_lut_we_ram,
edma_wr_eng_c2w_lut_re_ram,
edma_wr_eng_c2w_lut_din_ram,
edma_rd_eng_stsh_lut_addra_ram,
edma_rd_eng_stsh_lut_addrb_ram,
edma_rd_eng_stsh_lut_dout_ram,
edma_rd_eng_stsh_lut_we_ram,
edma_rd_eng_stsh_lut_re_ram,
edma_rd_eng_stsh_lut_din_ram,
edma_wr_eng_stsh_lut_addra_ram,
edma_wr_eng_stsh_lut_addrb_ram,
edma_wr_eng_stsh_lut_dout_ram,
edma_wr_eng_stsh_lut_we_ram,
edma_wr_eng_stsh_lut_re_ram,
edma_wr_eng_stsh_lut_din_ram,
edma_rd_eng_msi_addra_ram,
edma_rd_eng_msi_addrb_ram,
edma_rd_eng_msi_dout_ram,
edma_rd_eng_msi_we_ram,
edma_rd_eng_msi_re_ram,
edma_rd_eng_msi_din_ram,
edma_wr_eng_msi_addra_ram,
edma_wr_eng_msi_addrb_ram,
edma_wr_eng_msi_dout_ram,
edma_wr_eng_msi_we_ram,
edma_wr_eng_msi_re_ram,
edma_wr_eng_msi_din_ram,
edma_rd_eng_hard_stop_req,
edma_rd_eng_hard_stop_channel,
edma_rd_eng_hard_stop_ack,
edma_wr_eng_hard_stop_req,
edma_wr_eng_hard_stop_channel,
edma_wr_eng_hard_stop_ack,

edma_xfer_pending,
edma_int,
   // Completions Status during DPC
   core_in_dpc_i      ,
   cfg_dpc_cpl_cntrl_i,
aux_clk_g,
aux_clk
);

import DWC_pcie_axi_mstr_pkg::*;
import DWC_pcie_axi_slv_pkg::*;

 // ccx_module: DWC_pcie_ctl_bcm85; Designware Library block extensively used in multiple IPs and  verified in a stand-alone testbench
 // ccx_module: DWC_pcie_ctl_bcm86; Designware Library block extensively used in multiple IPs and  verified in a stand-alone testbench
 // ccx_module: DWC_pcie_ctl_bcm57; Designware Library block extensively used in multiple IPs and  verified in a stand-alone testbench


`define BRIDGE_TOP axi_bridge
  `define BRIDGE_INST u_axi_bridge

   //----------------------------------
   // PORT DECLARATIONS
   //----------------------------------
   // Inputs


  input                                           aux_clk_g;
  input                                           aux_clk;

   input [`CX_ATU_REGION_WIDTH*ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_base;
   input [ATU_OUT_NREGIONS_MIN1-1:0]                       atu_reg_out_en;
   input [ATU_OUT_NREGIONS_MIN1-1:0]                       atu_reg_out_invert;
   input [`CX_ATU_REGION_WIDTH*ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_limit;
   input [`CX_ATU_MAX_REGION_SIZE*ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_uppr_limit;
   input [ATU_OUT_NREGIONS_MIN1-1:0]                       atu_reg_out_incr_rgn_size;    // Maximum region size control bit

//ccx_tgl: ; atu_reg_out_type[3]; ; Bit 3 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[8]; ; Bit 8 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[13]; ; Bit 13 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[18]; ; Bit 18 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[23]; ; Bit 23 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[28]; ; Bit 28 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[33]; ; Bit 33 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[38]; ; Bit 38 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[43]; ; Bit 43 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[48]; ; Bit 48 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[53]; ; Bit 53 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[58]; ; Bit 58 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[63]; ; Bit 63 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[68]; ; Bit 68 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[73]; ; Bit 73 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[78]; ; Bit 78 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 

   input [5*ATU_OUT_NREGIONS_MIN1-1:0]            atu_reg_out_type;
   input [`CX_ATU_BASE_WIDTH*ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_upr_base;


//ccx_tgl: ; atu_reg_out_func_num; ; When the Number of Functions is equals to 1 this signal won't toggle.

   input [`CX_NFUNC_WD*ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_func_num;

   input [ATU_OUT_NREGIONS_MIN1-1:0]              atu_reg_out_func_bypass;
   input [ATU_OUT_NREGIONS_MIN1-1:0]              atu_reg_out_snp;
   input                                          cfg_axi_clk_gating_en;
   input [3:0]                                    cfg_mstr_arcache_mode;
   input [3:0]                                    cfg_mstr_awcache_mode;
   input [3:0]                                    cfg_mstr_arcache_value;
   input [3:0]                                    cfg_mstr_awcache_value;
   input [31:0]                                   cfg_aximstr_msg_addr_high;
   input [31:0]                                   cfg_aximstr_msg_addr_low;
   input [1:0]                                    cfg_mstr_ardomain_mode;
   input [1:0]                                    cfg_mstr_awdomain_mode;
   input [1:0]                                    cfg_mstr_ardomain_value;
   input [1:0]                                    cfg_mstr_awdomain_value;
   input                                          cfg_ax_mstr_zeroread_fw;

//ccx_tgl: ; cfg_max_payload_size[2]; ; The configured maximum payload size cannot be greater than the CX_MAX_MTU parameter

   input [(3*`CX_NFUNC)-1:0]                      cfg_max_payload_size;

//ccx_tgl: ; cfg_max_rd_req_size[2]; ; The configured read request size cannot be greater than the CC_SLV_RD_REQ_SIZE parameter

   input [(3*`CX_NFUNC)-1:0]                      cfg_max_rd_req_size;
   input                                          cfg_ext_tag_en;
   input                                          cfg_10b_tag_en;
   input                                          cfg_dmwr_req_en; // When asserted allows Deferrable Memory Write requests to be issued using the AXI slave
    input                                         cfg_memtype_value;
    input [`FLT_Q_ADDR_WIDTH-3:0]                 cfg_memtype_boundary;

//ccx_tgl: ; cfg_ax_mstr_np_pass_p[7:1]; ; Only 1 Virtual Functions supported 


   input [7:0]                                    cfg_ax_mstr_np_pass_p;
   input [1:0]                                    cfg_ax_mstr_ordr_p_event_sel;
   input [7:0]                                    cfg_ax_ib_cpl_pass_p;
   input                                          cfg_ax_snp_en;
   input cdmIbrPIdMngCtrl_s                       cfg_ib_p_id_mng_ctrl;
    input [23:0]                                  cfg_tc_struc_vc_map;
    input [`N_XADM_P_IF-1:0]                       xali_posted_tlp_sent;
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   

   // ***************************************************
   // RAS.DP IO
   // ***************************************************
   input                                          cfg_rasdp_err_mode;
   input                                          cfg_rasdp_err_mode_en;
   
    output ras_dp_err_log_t                       axi_bridge_out_ras_dp_err_log;
    input  ras_dp_err_inj_t                       axi_bridge_in_ras_dp_err_inj;
    input  logic                                  axi_bridge_in_ras_dp_err_inj_wake_up;

    output ras_dp_err_log_t                       hdma_ras_dp_err_log;
    input  ras_dp_err_inj_t                       hdma_ras_dp_err_inj;
   
   // RAS ECC RAM interface
   input                                          cfg_ras_recc_npw_sab_correct;
   //ccx_tgl: ; axi_ras_recc_corr_cnt_npw_sab_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output                                         axi_ras_recc_corr_cnt_npw_sab_pulse;
   output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_npw_sab_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_npw_sab_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                         axi_ras_recc_ucorr_cnt_npw_sab_pulse;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_npw_sab_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_npw_sab_addr;

   input                                          cfg_ras_recc_ob_npdcmp_correct;
   //ccx_tgl: ; axi_ras_recc_corr_cnt_ob_npdcmp_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                         axi_ras_recc_corr_cnt_ob_npdcmp_pulse;
   output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]         axi_ras_recc_corr_cnt_ob_npdcmp_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                         axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse;
   output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]         axi_ras_recc_ucorr_cnt_ob_npdcmp_addr;

   input                                          cfg_ras_recc_ob_pdcmp_hdr_correct;
   output                                         axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse;
   output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                         axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse;
   output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr;

   input                                          cfg_ras_recc_ob_pdcmp_data_correct;
   output                                         axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse;
   output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     axi_ras_recc_corr_cnt_ob_pdcmp_data_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                         axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse;
   output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr;

   input                                          cfg_ras_recc_ob_ccmp_data_correct;
   output                                         axi_ras_recc_corr_cnt_ob_ccmp_data_pulse;
   //ccx_tgl: ; axi_ras_recc_corr_cnt_ob_ccmp_data_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      axi_ras_recc_corr_cnt_ob_ccmp_data_addr;
   output                                         axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr;

   //ccx_tgl: ; cfg_ras_recc_ib_sch_p_hdr_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   input                                                 cfg_ras_recc_ib_sch_p_hdr_correct;
   output                                           axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse;
   output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                           axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse;
   output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr;
   //ccx_tgl: ; cfg_ras_recc_ib_sch_p_data_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   input                                            cfg_ras_recc_ib_sch_p_data_correct;
   output                                           axi_ras_recc_corr_cnt_ib_sch_p_data_pulse;
   output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_p_data_addr;
   output                                           axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse;
   output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr;
   //ccx_tgl: ; cfg_ras_recc_ib_sch_np_hdr_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   input                                            cfg_ras_recc_ib_sch_np_hdr_correct;
   output                                           axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse;
   output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                           axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse;
   output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr;
   //ccx_tgl: ; cfg_ras_recc_ib_sch_np_data_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   input                                            cfg_ras_recc_ib_sch_np_data_correct;
   output                                           axi_ras_recc_corr_cnt_ib_sch_np_data_pulse;
   //ccx_tgl: ; axi_ras_recc_corr_cnt_ib_sch_np_data_addr; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_corr_cnt_ib_sch_np_data_addr;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output                                           axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr;
   //ccx_tgl: ; cfg_ras_recc_ib_rreq_c2a_cdc_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   input                                          cfg_ras_recc_ib_rreq_c2a_cdc_correct;
   output                                         axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse;
   //ccx_tgl: ; axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr;
   output                                         axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr;

   //ccx_tgl: ; cfg_ras_recc_ib_wreq_c2a_cdc_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
   input                                          cfg_ras_recc_ib_wreq_c2a_cdc_correct;
   output                                         axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse;
   //ccx_tgl: ; axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr;
   output                                         axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse;
   //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
   output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr;

   input                                          cfg_ras_recc_ib_mcpl_a2c_cdc_correct;
   output                                         axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse;
   output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr;
   output                                         axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse;
   output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr;


   input                                          cfg_ras_recc_ib_mcpl_sb_correct;
   output                                         axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse;
   output [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]   axi_ras_recc_corr_cnt_ib_mcpl_sb_addr;
   output                                         axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse;
   output [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]   axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr;


    output wire                                   axi_ras_par_rtrgt_p_ad_pulse;
    output wire                                   axi_ras_par_rtrgt_p_dt_pulse;
    output wire                                   axi_ras_par_rtrgt_np_ad_pulse;
    output wire                                   axi_ras_par_rtrgt_np_dt_pulse;
    output wire                                   axi_ras_par_rtrgt_cpl_ad_pulse;
    output wire                                   axi_ras_par_rtrgt_cpl_dt_pulse;
   output wire                                    axi_ras_par_ib_mcpl_dt_pulse;



   output wire                                    axi_ras_par_ibwr_dcmp_dt_pulse;
   output wire                                    axi_ras_par_ibwr_dcmp_ad_pulse;
   output wire                                    axi_ras_par_ibrd_dcmp_ad_pulse;


   output wire                                    axi_ras_par_ib_sch_p_ad_pulse;
   output wire                                    axi_ras_par_ib_sch_p_dt_pulse;
   output wire                                    axi_ras_par_ib_sch_np_ad_pulse;
   output wire                                    axi_ras_par_ib_sch_np_dt_pulse;
   output wire                                    axi_ras_par_ib_mcpl_a2c_dt_pulse;
   output wire                                    axi_ras_par_ib_mcpl_sb_dt_pulse;

   output wire                                    axi_ras_par_ibwq_mrf_dt_pulse;
   output wire                                    axi_ras_par_ibwq_mrf_ad_pulse;
   output wire                                    axi_ras_par_ibrd_mrf_ad_pulse;

   output wire                                    axi_ras_par_npqdec_ad_pulse;

   output wire                                    axi_ras_par_pqdec_ad_pulse;
   output wire                                    axi_ras_par_swwrap_dt_pulse;
   output wire                                    axi_ras_par_swwrap_ad_pulse;
   output wire                                    axi_ras_par_srwrap_ad_pulse;
   //ccx_tgl: ; axi_ras_par_swrq_npw_dt_pulse; ; Missing stimulus, refer JIRA P80001562-408415.
   output wire                                    axi_ras_par_swrq_npw_dt_pulse;
   output wire                                    axi_ras_par_swrq_npw_ad_pulse;

   output wire                                    axi_ras_par_slnull_dt_pulse;
   output wire                                    axi_ras_par_slnull_ad_pulse;

   output wire                                    axi_ras_par_c2_ad_pulse;
   output wire                                    axi_ras_par_c2_dt_pulse;
   output wire                                    axi_ras_par_c1_ad_pulse;
   output wire                                    axi_ras_par_c1_dt_pulse;

   output wire                                    axi_ras_par_ob_np_dcmp_inq_dt_pulse;
   output wire                                    axi_ras_par_ob_p_dcmp_inq_dt_pulse;
   output wire                                    axi_ras_par_ob_cpl_comp_dt_pulse;
   //ccx_tgl: ; axi_slv_sisb_uncorr_pulse; ; Missing stimulus, refer JIRA P80001562-408415.
   output                                         axi_slv_sisb_uncorr_pulse;
   //ccx_tgl: ; axi_mstr_misb_uncorr_pulse; ; Missing stimulus, refer JIRA P80001562-408415.
   output                                         axi_mstr_misb_uncorr_pulse;



   input                                          core_clk;
   input                                          core_rst_n;
   //ccx_tgl: ; crgb_address[1:0]; ; Address is always DW aligned

   input [`CC_CRGB_ADDR_WIDTH-1:0]                crgb_address;
   input                                          crgb_rden;
   input                                          crgb_source;
   input [CRGB_DATA_WIDTH-1:0]                    crgb_wr_data;
   input                                          crgb_wren;
     input                                          dbi_ack;
     input [31:0]                                   dbi_dout;


   // Clock & Reset
   input                                          mstr_aclk_g;    // for internal modules or signals, mstr_aclk_g = mstr_aclk
   input                                          mstr_aresetn;
   input                                          mstr_aclk;      // for internal modules or signals, mstr_aclk = mstr_aclk_ug
   output                                         en_mstr_aclk_g; // for internal modules or signals, en_mstr_aclk_g = mstr_aclk_active
   output wire                                    mstr_rasdp_err_mode;
   // AXI master write request
   input                                          mstr_awready;

   // AXI master write data
   input                                          mstr_wready;

   // AXI master write response
   input [`CC_MSTR_BUS_ID_WIDTH -1:0]             mstr_bid;
   input                                          mstr_bvalid;
   
   input [`CC_AXIJ_DMWR_VALUE+1:0]                mstr_bresp;
   input [2:0]                                    mstr_bmisc_info_cpl_stat;
  
   // AXI master read request
   input                                          mstr_arready;

   // AXI master read response & read data

//ccx_tgl: ; mstr_rid[9:5]; ; Unreachable CC_MAX_MSTR_TAGS_AXI == 64.

   input [`CC_MSTR_BUS_ID_WIDTH -1:0]             mstr_rid;
   input                                          mstr_rvalid;
   input                                          mstr_rlast;
   input [`MASTER_BUS_DATA_WIDTH -1:0]            mstr_rdata;
   input [`CC_MSTR_R_USER_WIDTH-1:0]              mstr_ruser;
   input [1:0]                                    mstr_rresp;
   //ccx_tgl: ; mstr_rmisc_info_cpl_stat[1]; ; Only SC, CA and UR in cpl_stat are supported. Bridge don't support cfg_retry.
   input [2:0]                                    mstr_rmisc_info_cpl_stat;
   input [`MSTR_RESP_MISC_INFO_PW -1:0]           mstr_rmisc_info;
  
   // AXI master low power
   input                                          mstr_csysreq;
   input [`CX_REMOTE_LOOKUPID_WD-1:0]             trgt_lookup_id;

   input                                          radm_trgt1_p_0_pending;

   input [`TRGT_DATA_WD-1:0]                      radm_trgt1_p_0_data;
   input [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0]      radm_trgt1_p_0_hdr_prot;
   input [PRFX_W_PAR-1:0]                         radm_trgt1_p_0_prfx;
   input [`CX_NW-1:0]                             radm_trgt1_p_0_dwen;
   input                                          radm_trgt1_p_0_dv;
   input                                          radm_trgt1_p_0_hv;
   input                                          radm_trgt1_p_0_eot;
   input                                          radm_trgt1_p_0_dllp_abort;
   input                                          radm_trgt1_p_0_tlp_abort;
   input                                          radm_trgt1_p_0_ecrc_err;
   input [1:0]                                    radm_trgt1_p_0_fmt;
   //ccx_tgl: ; radm_trgt1_p_0_type[3]; ; No completions for TRGT1.
   input [4:0]                                    radm_trgt1_p_0_type;
   input [2:0]                                    radm_trgt1_p_0_tc;
   input [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_p_0_attr;
   input [15:0]                                   radm_trgt1_p_0_reqid;
   input [`CX_TAG_SIZE-1:0]                       radm_trgt1_p_0_tag;
   input [`CX_NFUNC_WD-1:0]                       radm_trgt1_p_0_func_num;
   input                                          radm_trgt1_p_0_td;
   input                                          radm_trgt1_p_0_poisoned;
   input [9:0]                                    radm_trgt1_p_0_dw_len;
   input [3:0]                                    radm_trgt1_p_0_first_be;
   input [`CX_NVC_LOG2-1:0]                       radm_trgt1_p_0_vc_num;
   input [2:0]                                    radm_trgt1_p_0_cpl_status;
   input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_p_0_addr;
   input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_p_0_hdr_uppr_bytes;
   input                                          radm_trgt1_p_0_rom_in_range;
   input                                          radm_trgt1_p_0_io_req_in_range;
   input [2:0]                                    radm_trgt1_p_0_in_membar_range;
   input [3:0]                                    radm_trgt1_p_0_last_be;
   input [1:0]                                    radm_trgt1_p_0_ats;
   input                                          radm_trgt1_p_0_nw;
   input                                          radm_trgt1_p_0_cxlsrc;
   input                                          radm_trgt1_p_0_th;
   input [1:0]                                    radm_trgt1_p_0_ph;
   input [7:0]                                    radm_trgt1_p_0_st;
   input                                          radm_trgt1_p_0_hdr_uppr_bytes_valid;
   input [8:0]                                    radm_trgt1_p_0_reqtr_sgmt;
   input [8:0]                                    radm_trgt1_p_0_dest_sgmt;
   input [`CX_RADM_PKT_ORD_WD-1:0]                radm_trgt1_p_0_pkt_order_no;
   input [`TRGT_DATA_WD-1:0]                      radm_trgt1_np_0_data;
   input [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]     radm_trgt1_np_0_hdr_prot;
   input [PRFX_W_PAR-1:0]                         radm_trgt1_np_0_prfx;
   input [`CX_NW-1:0]                             radm_trgt1_np_0_dwen;
   input                                          radm_trgt1_np_0_dv;
   input                                          radm_trgt1_np_0_hv;
   input                                          radm_trgt1_np_0_eot;
   input                                          radm_trgt1_np_0_dllp_abort;
   input                                          radm_trgt1_np_0_tlp_abort;
   input                                          radm_trgt1_np_0_ecrc_err;
   input [1:0]                                    radm_trgt1_np_0_fmt;
   input [4:0]                                    radm_trgt1_np_0_type;
   input [2:0]                                    radm_trgt1_np_0_tc;
   input [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_np_0_attr;
   input [15:0]                                   radm_trgt1_np_0_reqid;
   input [`CX_TAG_SIZE-1:0]                       radm_trgt1_np_0_tag;
   input [`CX_NFUNC_WD-1:0]                       radm_trgt1_np_0_func_num;
   input [2:0]                                    radm_trgt1_np_0_cpl_status;
   input                                          radm_trgt1_np_0_td;
   input                                          radm_trgt1_np_0_poisoned;
   input [9:0]                                    radm_trgt1_np_0_dw_len;
   input [3:0]                                    radm_trgt1_np_0_first_be;
   input [`CX_NVC_LOG2-1:0]                       radm_trgt1_np_0_vc_num;

   input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_np_0_addr;
   input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_np_0_hdr_uppr_bytes;

   input                                          radm_trgt1_np_0_rom_in_range;
   input                                          radm_trgt1_np_0_io_req_in_range;
   input [2:0]                                    radm_trgt1_np_0_in_membar_range;
   input [3:0]                                    radm_trgt1_np_0_last_be;
   input [1:0]                                    radm_trgt1_np_0_ats;
   input                                          radm_trgt1_np_0_nw;
   //ccx_tgl: ; radm_trgt1_np_0_cxlsrc; ; This signal is tied to zero for DTI Version 1.
   input                                          radm_trgt1_np_0_cxlsrc;
   input                                          radm_trgt1_np_0_th;
   input [1:0]                                    radm_trgt1_np_0_ph;
   input [7:0]                                    radm_trgt1_np_0_st;
   input [8:0]                                    radm_trgt1_np_0_reqtr_sgmt;
   input [8:0]                                    radm_trgt1_np_0_dest_sgmt;
   input [`CX_RADM_PKT_ORD_WD-1:0]                radm_trgt1_np_0_pkt_order_no;

   input [`TRGT_DATA_WD-1:0]                      radm_trgt1_cpl_0_data;
   input [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]    radm_trgt1_cpl_0_hdr_prot;
   input [PRFX_W_PAR-1:0]                         radm_trgt1_cpl_0_prfx;
   input [`CX_NW-1:0]                             radm_trgt1_cpl_0_dwen;
   input                                          radm_trgt1_cpl_0_dv;
   input                                          radm_trgt1_cpl_0_hv;
   input                                          radm_trgt1_cpl_0_eot;
   input                                          radm_trgt1_cpl_0_dllp_abort;
   input                                          radm_trgt1_cpl_0_tlp_abort;
   input                                          radm_trgt1_cpl_0_ecrc_err;
//ccx_tgl: ; radm_trgt1_cpl_0_fmt[0]; ; Unreachable due Completion type, because all completions are 3DW.
   input [1:0]                                    radm_trgt1_cpl_0_fmt;
   //ccx_tgl: ; radm_trgt1_cpl_0_type[4:1]; ; For Completions, this bits are always 0.
   input [4:0]                                    radm_trgt1_cpl_0_type;
   input [2:0]                                    radm_trgt1_cpl_0_tc;
   input [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_cpl_0_attr;
   input [15:0]                                   radm_trgt1_cpl_0_reqid;
   input [`CX_TAG_SIZE-1:0]                       radm_trgt1_cpl_0_tag;
   input [`CX_NFUNC_WD-1:0]                       radm_trgt1_cpl_0_func_num;
   input [2:0]                                    radm_trgt1_cpl_0_cpl_status;
   input                                          radm_trgt1_cpl_0_td;
   input                                          radm_trgt1_cpl_0_poisoned;
   input [9:0]                                    radm_trgt1_cpl_0_dw_len;
   //ccx_tgl: ; radm_trgt1_cpl_0_bcm; ; The Byte Count Modified bit is not applicable for an endpoint device.
   input                                          radm_trgt1_cpl_0_bcm;

//ccx_tgl: ; radm_trgt1_cpl_0_byte_cnt[11:10]; ; The largest packet payload that the device supports is 9.

   input [11:0]                                   radm_trgt1_cpl_0_byte_cnt;
   input [15:0]                                   radm_trgt1_cpl_0_cmpltr_id;
   input                                          radm_trgt1_cpl_0_last;
   input [`CX_NVC_LOG2-1:0]                       radm_trgt1_cpl_0_vc_num;

   input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_cpl_0_addr;

   input [8:0]                                    radm_trgt1_cpl_0_dest_sgmt;
   input [7:0]                                    radm_trgt1_cpl_0_cpl_sgmt;
   input [`CX_RADM_PKT_ORD_WD -1 :0]              radm_trgt1_cpl_0_pkt_order_no;

   output logic                                   trgt1_radm_intf_cpl_0_halt;
   output logic                                   trgt1_radm_intf_p_0_halt;
   output logic                                   trgt1_radm_intf_np_0_halt;

   input                                          radm_cpl_timeout;
   input [1:0]                                    radm_timeout_cpl_attr;

//ccx_tgl: ; radm_timeout_cpl_tag[13:9]; ; The CX_MAX_TAG controls the maximum number of tags.

   input [`CX_TAG_SIZE-1:0]                       radm_timeout_cpl_tag;
   input [2:0]                                    radm_timeout_cpl_tc;
   input [`CX_NFUNC_WD-1:0]                       radm_timeout_func_num;
   // Clock & Reset
   input                                          slv_aclk_g;    // for internal modules or signals, slv_aclk_g = slv_aclk
   input                                          slv_aresetn;
   input                                          slv_aclk;      // for internal modules or signals, slv_aclk = slv_aclk_ug
   output                                         en_slv_aclk_g; // for internal modules or signals, en_slv_aclk_g = slv_aclk_active
   output wire                                    slv_rasdp_err_mode;
   // AXI slave Write address channel
   input [`SLAVE_BUS_ADDR_WIDTH -1:0]             slv_awaddr;
   input [`CC_SLV_AW_USER_WIDTH-1:0]              slv_awuser;
   input [1:0]                                    slv_awburst;
   input [3:0]                                    slv_awcache;
   input [`CC_SLV_BUS_ID_WIDTH -1:0]              slv_awid;
   input [`CC_SLV_INT_BURST_LEN_PW -1:0]          slv_awlen;
   input [`CC_AXI_LOCK_WIDTH-1:0]                 slv_awlock;

//ccx_tgl: ; slv_awmisc_info[24:22]; ; Function numbering of the TLP. 


   input [`SLV_MISC_INFO_PW -1:0]                 slv_awmisc_info;
   input [63:0]                                   slv_awmisc_info_hdr_34dw;
   input                                          slv_awmisc_info_nw;
   input [1:0]                                    slv_awmisc_info_ats;
   input [PRFX_WIDTH-1:0]                         slv_awmisc_info_tlpprfx;
   input [`CX_TAG_SIZE-1:0]                       slv_awmisc_info_p_tag;
   input [MISC_INFO_TPH_WD-1:0]                   slv_awmisc_info_tph;
   input                                          slv_awmisc_info_atu_bypass;
   input                                          slv_awmisc_info_ido;
   input [8:0]                                    slv_awmisc_info_dst_segment;
   input [2:0]                                    slv_awprot;
   input [2:0]                                    slv_awsize;
   input                                          slv_awvalid;
   input [3:0]                                    slv_awqos;
   //ccx_tgl: ; slv_awbar[1:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields
   input [1:0]                                    slv_awbar;
   input [1:0]                                    slv_awdomain;
   //ccx_tgl: ; slv_awsnoop[3:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields
   input [`CC_AXIJ_DMWR_VALUE *2+2:0]             slv_awsnoop;
   //ccx_tgl: ; slv_awatop[2:1]; ; Not supported, we only support AtomicSwap, AtomicCompare and AtomicStore (Operation -> ADD)
   input [5:0]                                    slv_awatop;

   // AXI slave Write data channel
   input [`SLAVE_BUS_DATA_WIDTH -1:0]             slv_wdata;
   input [`CC_SLV_W_USER_WIDTH-1:0]               slv_wuser;
   input                                          slv_wlast;
   input [`CC_SLV_BUS_WSTRB_WIDTH -1:0]           slv_wstrb;
   input                                          slv_wvalid;
   input                                          slv_wmisc_info_ep;
   input                                          slv_wmisc_info_silentDrop;

   // AXI slave Write response channel
   input                                          slv_bready;

   // AXI slave Read address channel
   input [`SLAVE_BUS_ADDR_WIDTH -1:0]             slv_araddr;
   input [`CC_SLV_AR_USER_WIDTH-1:0]              slv_aruser;
   input [1:0]                                    slv_arburst;
   //ccx_tgl: ; slv_arcache; ; Cache is not supported
   input [3:0]                                    slv_arcache;
   input [`CC_SLV_BUS_ID_WIDTH -1:0]              slv_arid;
   input [`CC_SLV_INT_BURST_LEN_PW -1:0]          slv_arlen;
   //ccx_tgl: ; slv_arlock; ; Locked transactions not supported
   input [`CC_AXI_LOCK_WIDTH-1:0]                 slv_arlock;
   //ccx_tgl: ; slv_armisc_info[20]; ; There is no valid message code with MSB=1


//ccx_tgl: ; slv_armisc_info[24:22]; ; Function numbering of the TLP. 


   input [`SLV_MISC_INFO_PW -1:0]                 slv_armisc_info;
   input                                          slv_armisc_info_nw;
   input [1:0]                                    slv_armisc_info_ats;
   input [PRFX_WIDTH-1:0]                         slv_armisc_info_tlpprfx;
   input [MISC_INFO_TPH_WD-1:0]                   slv_armisc_info_tph;
   input                                          slv_armisc_info_atu_bypass;
   input                                          slv_armisc_info_ido;
   input [8:0]                                    slv_armisc_info_dst_segment;
   input [2:0]                                    slv_arprot;
   input [2:0]                                    slv_arsize;
   input                                          slv_arvalid;
   input [3:0]                                    slv_arqos;
   //ccx_tgl: ; slv_arbar[1:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields.
   input [1:0]                                    slv_arbar;
   input [1:0]                                    slv_ardomain;
   //ccx_tgl: ; slv_arsnoop[3:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields.
   input [3:0]                                    slv_arsnoop;

   // AXI slave Read data channel
   input                                          slv_rready;

   // AXI slave Low-power Channel
   input                                          slv_csysreq;
   input [4:0]                                    cfg_pbus_dev_num;
   input [7:0]                                    cfg_pbus_num;
   input [7:0]                                    cfg_subbus_num;
   input [7:0]                                    cfg_2ndbus_num;
   input [4:0]                                    cfg_err_resp_mode;
   input [5:0]                                    cfg_slv_resp_err_map;
   input [`CX_NVC-1:0]                            radm_trgt1_cpl_lookup_id_rlsd;
   input                                          radm_trgt1_lookup_id_consmd;


   // Outputs
    output xali_pkt_t[`N_XALI_IF-1:0]                     xali_xaim_pkt;
    input logic[`N_XALI_IF-1:0]                           xaim_xali_halt;
   output                             crgb_ack;
   output [CRGB_DATA_WIDTH-1:0]       crgb_rd_data;



//ccx_tgl: ; dbi_addr[18:16]; ; This bits depend on the number of functions, when the No. of funtions is 1 this bits wont toggle. 



     //ccx_tgl: ; dbi_addr[1:0]; ; The DBI address must be a DWORD address (*addr[1:0] =2b00)
     output [31:0]                                  dbi_addr;
     output [31:0]                                  dbi_din;
     output                                         dbi_cs;
     output                                         dbi_cs2;
     output [3:0]                                   dbi_wr;
     output [2:0]                                   dbi_bar_num;
     //ccx_tgl: ; dbi_func_num; ; When the CX_NFUNC parameter equals 1 this signal won't toggle.


//ccx_tgl: ; dbi_func_num[3:1]; ; The number of functions is controled by the CX_NFUNC parameter.

     output [`CX_NFUNC_WD-1:0]                      dbi_func_num;
     output                                         dbi_io_access;
     output                                         dbi_rom_access;


   output [`CC_NUM_DMA_WR_CHAN+`CC_NUM_DMA_RD_CHAN-1:0] edma_int;
   output                                         edma_xfer_pending;
   // AXI master write request
   output [`MASTER_BUS_ADDR_WIDTH -1:0]           mstr_awaddr;
   output [`CC_MSTR_AW_USER_WIDTH-1:0]            mstr_awuser;
   //ccx_tgl: ; mstr_awburst; ; Only INCR transactions are supported
   output [1:0]                                   mstr_awburst;
   output [3:0]                                   mstr_awcache;
   output [`CC_MSTR_BUS_ID_WIDTH -1:0]            mstr_awid;
   output [`CC_MSTR_BURST_LEN_PW -1:0]            mstr_awlen;
   //ccx_tgl: ; mstr_awlock; ; Locked transactions not supported
   output [`CC_AXI_LOCK_WIDTH-1:0]                mstr_awlock;

//ccx_tgl: ; mstr_awmisc_info[13:11]; ; The number of functions is controled by the CX_NFUNC parameter.


   //ccx_tgl: ; mstr_awmisc_info[22]; ; No completions on AW-Channel
   output [`MSTR_MISC_INFO_PW -1:0]               mstr_awmisc_info;
   output                                         mstr_awmisc_info_last_dcmp_tlp;
   output [63:0]                                  mstr_awmisc_info_hdr_34dw;
   output                                         mstr_awmisc_info_nw;
   //ccx_tgl: ; mstr_awmisc_info_cxlsrc; ; This signal is tied to zero for DTI Version 1.
   output                                         mstr_awmisc_info_cxlsrc;
   output [1:0]                                   mstr_awmisc_info_ats;
   output                                         mstr_awmisc_info_ep;
   //ccx_tgl: ; mstr_awmisc_info_dma[2]; ; DMA never issue LL accesses on AW-Channel
   output [`CC_NUM_DMA_RD_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_awmisc_info_dma;
   output [PRFX_WIDTH-1:0]                        mstr_awmisc_info_tlpprfx;
   output [MISC_INFO_TPH_WD-1:0]                  mstr_awmisc_info_tph;
   output                                         mstr_awmisc_info_ido;
   output [8:0]                                   mstr_awmisc_info_dst_segment;
   output [8:0]                                   mstr_awmisc_info_req_segment;
   //ccx_tgl: ; mstr_awprot; ; Transactions protection not supported
   output [2:0]                                   mstr_awprot;



//ccx_tgl: ; mstr_awsize[0]; ; Uses Full Size method for executing Narrow Inbound Writes at AXI Master Interface.







   output [2:0]                                   mstr_awsize;
   output                                         mstr_awvalid;

   // AXI master write data
   output [`MASTER_BUS_DATA_WIDTH -1:0]           mstr_wdata;
   output [`CC_MSTR_W_USER_WIDTH-1:0]             mstr_wuser;
   output                                         mstr_wlast;
   output [`CC_MSTR_BUS_WSTRB_WIDTH -1:0]         mstr_wstrb;
   output                                         mstr_wvalid;

   // AXI master write response
   //ccx_tgl: ; mstr_bready; ; Missing stimulus, refer JIRA P80001562-415476.
   output                                         mstr_bready;

   // AXI master read request
   output [`MASTER_BUS_ADDR_WIDTH -1:0]           mstr_araddr;
   output [`CC_MSTR_AR_USER_WIDTH-1:0]            mstr_aruser;
   //ccx_tgl: ; mstr_arburst[1]; ; AXI master interface of the controller generates only INCR Bursts.
   output [1:0]                                   mstr_arburst;
   output [3:0]                                   mstr_arcache;
   output [`CC_MSTR_BUS_ID_WIDTH -1:0]            mstr_arid;   


//ccx_tgl: ; mstr_arlen[8:3]; ; The maximum burst length of an AXI transfer at the master interface is 3


   output [`CC_MSTR_BURST_LEN_PW -1:0]            mstr_arlen;
   //ccx_tgl: ; mstr_arlock; ; indicates whether the transfer is a normal, exclusive, or locked access. The controller does not use this signal and sets all bits inactive
   output [`CC_AXI_LOCK_WIDTH-1:0]                mstr_arlock;
   //ccx_tgl: ; mstr_armisc_info[5:0]; ; Reserved field
   //ccx_tgl: ; mstr_armisc_info[23]; ; No Message Request types (Writes) on AR-Channel
   //ccx_tgl: ; mstr_armisc_info[22]; ; No completions on AR-Channel


//ccx_tgl: ; mstr_armisc_info[13:11]; ; The number of functions is controled by the CX_NFUNC parameter.


   output [`MSTR_MISC_INFO_PW -1:0]               mstr_armisc_info;
   output                                         mstr_armisc_info_last_dcmp_tlp;
   output                                         mstr_armisc_info_nw;
   //ccx_tgl: ; mstr_armisc_info_cxlsrc; ; This signal is tied to zero for DTI Version 1.
   output                                         mstr_armisc_info_cxlsrc;
   output [1:0]                                   mstr_armisc_info_ats;
   output [`CC_NUM_DMA_MAX_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_armisc_info_dma;
   output [PRFX_WIDTH-1:0]                        mstr_armisc_info_tlpprfx;
   output [MISC_INFO_TPH_WD-1:0]                  mstr_armisc_info_tph;
   output                                         mstr_armisc_info_ido;
   output                                         mstr_armisc_info_zeroread;
    output                                  [8:0] mstr_armisc_info_dst_segment;
    output                                  [8:0] mstr_armisc_info_req_segment;
   //ccx_tgl: ; mstr_arprot[2:0]; ; Indicates unprivileged, non-secure, or data protection access level. The controller assigns this signal a value of 010.
   output [2:0]                                   mstr_arprot;




//ccx_tgl: ; mstr_arsize[0]; ; Uses Approximate Full Size method for executing Narrow Inbound Reads at AXI Master Interface.







   
   output [2:0]                                   mstr_arsize;
   output                                         mstr_arvalid;

   // AXI master read response & read data
   output                                         mstr_rready;

   //ccx_tgl: ; mstr_awqos; ; No AXI QoS supported
   output [3:0]                                   mstr_awqos;
   output [1:0]                                   mstr_awbar;
   output [1:0]                                   mstr_awdomain;
   output [`CC_AXIJ_DMWR_VALUE *2+2:0]            mstr_awsnoop;
   output [5:0]                                   mstr_awatop;
   //ccx_tgl: ; mstr_arqos; ; No AXI QoS supported
   output [3:0]                                   mstr_arqos;
   output [1:0]                                   mstr_arbar;
   output [1:0]                                   mstr_ardomain;
   output [3:0]                                   mstr_arsnoop;

   // AXI master low power
   //ccx_tgl: ; mstr_csysack; ; AXI Low Power Interface not used
   //ccx_tgl: ; mstr_cactive; ; AXI Low Power Interface not used
   output                                         mstr_cactive;
   output                                         mstr_csysack;
   // AXI slave Write address channel
   output                                         slv_awready;

   // AXI slave Write data channel
   output                                         slv_wready;

   // AXI slave Write response channel
   output [`CC_SLV_BUS_ID_WIDTH -1:0]             slv_bid;
   output [`SLV_RESP_MISC_INFO_PW -1:0]           slv_bmisc_info;
   output [8:0]                                   slv_bmisc_info_dst_segment;
   output [7:0]                                   slv_bmisc_info_cpl_segment;
   output [`CC_AXIJ_DMWR_VALUE+1:0]               slv_bresp;
   output                                         slv_bvalid;

   // AXI slave Read address channel
   output                                         slv_arready;

   // AXI slave Read data channel
   output [`SLAVE_BUS_DATA_WIDTH -1:0]            slv_rdata;
   output [`CC_SLV_R_USER_WIDTH-1:0]              slv_ruser;
   output [`CC_SLV_BUS_ID_WIDTH -1:0]             slv_rid;
   output                                         slv_rlast;
   output [`SLV_RESP_MISC_INFO_PW -1:0]           slv_rmisc_info;
   output                                         slv_rmisc_info_ido;
   output [8:0]                                   slv_rmisc_info_dst_segment;
   output [7:0]                                   slv_rmisc_info_cpl_segment;
   output [1:0]                                   slv_rresp;
   output                                         slv_rvalid;

   // AXI slave Low-power Channel
   output                                         slv_cactive;
   output                                         slv_csysack;
   output                                         brdg_mstr_xfer_pending;
   input                                          trgt_cpl_lut_empty;
   output                                         brdg_slv_xfer_pending;
   input                                          app_xfer_pending;
   output wire                                    brdg_dbi_xfer_pending;
   input                                          rstctl_slv_flush_req;
   input                                          rstctl_mstr_flush_req;
   output                                         brdg_slv_flush_ack;
  // External RAM interfaces
  // Inbound
  // Inbound Read Request Clock Domain Crossing FIFO RAM
  output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     ib_rreq_c2a_cdc_ram_addra;
  output                                         ib_rreq_c2a_cdc_ram_wea;
  //ccx_tgl: ; ib_rreq_c2a_cdc_ram_dina; ; Randomization of access to the RAM.
  output [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]     ib_rreq_c2a_cdc_ram_dina;
  output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     ib_rreq_c2a_cdc_ram_addrb;
  output                                         ib_rreq_c2a_cdc_ram_enb;
  input  [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]     ib_rreq_c2a_cdc_ram_doutb;
 // Inbound Write Request Clock Domain Crossing FIFO RAM
  output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     ib_wreq_c2a_cdc_ram_addra;
  output                                         ib_wreq_c2a_cdc_ram_wea;
  //ccx_tgl: ; ib_wreq_c2a_cdc_ram_dina; ; Randomization of access to the RAM.
  output [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]     ib_wreq_c2a_cdc_ram_dina;
  output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     ib_wreq_c2a_cdc_ram_addrb;
  output                                         ib_wreq_c2a_cdc_ram_enb;
  input  [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]     ib_wreq_c2a_cdc_ram_doutb;
  // Inbound Master Completion Clock Domain Crossing FIFO RAM
  output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       ib_mcpl_a2c_cdc_ram_addra;
  output                                         ib_mcpl_a2c_cdc_ram_wea;
  //ccx_tgl: ; ib_mcpl_a2c_cdc_ram_dina[33]; ; Randomization of access to the RAM.
  //ccx_tgl: ; ib_mcpl_a2c_cdc_ram_dina[38]; ; Randomization of access to the RAM.
  output [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]       ib_mcpl_a2c_cdc_ram_dina;
  output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       ib_mcpl_a2c_cdc_ram_addrb;
  output                                         ib_mcpl_a2c_cdc_ram_enb;
  input  [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]       ib_mcpl_a2c_cdc_ram_doutb;

  // Inbound Master Completion Data Segment FIFO RAM
    // Master completion buffer segment buffer RAM outputs
    output [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]          ib_mcpl_sb_ram_addra;
    output                                                ib_mcpl_sb_ram_wea;
    //ccx_tgl: ; ib_mcpl_sb_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]          ib_mcpl_sb_ram_dina;
    output [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]          ib_mcpl_sb_ram_addrb;
    output                                                ib_mcpl_sb_ram_enb;
    //ccx_tgl: ; ib_mcpl_sb_ram_doutb; ; Randomization of access to the RAM.
    input [`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]           ib_mcpl_sb_ram_doutb;
    output                                                ib_scheduler_p_hdr_ram_wea;
    output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addra;
    //ccx_tgl: ; ib_scheduler_p_hdr_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_dina;
    output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addrb;
    output                                                ib_scheduler_p_hdr_ram_enb;
    input  [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_doutb;

    output                                                ib_scheduler_p_data_ram_wea;
    output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addra;
    output [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_dina;
    output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addrb;
    output                                                ib_scheduler_p_data_ram_enb;
    input  [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_doutb;

    output                                                ib_scheduler_np_hdr_ram_wea;
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addra;
    //ccx_tgl: ; ib_scheduler_np_hdr_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_dina;
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addrb;
    output                                                ib_scheduler_np_hdr_ram_enb;
    input  [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_doutb;

    output                                                ib_scheduler_np_data_ram_wea;
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addra;
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_dina;
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addrb;
    output                                                ib_scheduler_np_data_ram_enb;
    input  [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_doutb;
 
  // Outbound
  // Slave Non-Posted Write Set-Aside RAM
  output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]       slv_npw_sab_ram_addra;
  output                                         slv_npw_sab_ram_wea;
  //ccx_tgl: ; slv_npw_sab_ram_dina; ; Randomization of access to the RAM.
  output [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]       slv_npw_sab_ram_dina;
  output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]       slv_npw_sab_ram_addrb;
  output                                         slv_npw_sab_ram_enb;
  input  [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]       slv_npw_sab_ram_doutb;
  // Outbound Posted/Non-Posted TLP Decomposer FIFO RAM
  output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]         ob_npdcmp_ram_addra;
  output                                         ob_npdcmp_ram_wea;
  //ccx_tgl: ; ob_npdcmp_ram_dina; ; Randomization of access to the RAM.
  output [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]         ob_npdcmp_ram_dina;
  output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]         ob_npdcmp_ram_addrb;
  output                                         ob_npdcmp_ram_enb;
  input  [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]         ob_npdcmp_ram_doutb;
  // Outbound Posted TLP Decomposer Header FIFO RAM
  output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      ob_pdcmp_hdr_ram_addra;
  output                                         ob_pdcmp_hdr_ram_wea;
  //ccx_tgl: ; ob_pdcmp_hdr_ram_dina; ; Randomization of access to the RAM.
  output [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]      ob_pdcmp_hdr_ram_dina;
  output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      ob_pdcmp_hdr_ram_addrb;
  output                                         ob_pdcmp_hdr_ram_enb;
  input  [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]      ob_pdcmp_hdr_ram_doutb;
 // Outbound Posted TLP Decomposer Data FIFO RAM
  output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     ob_pdcmp_data_ram_addra;
  output                                         ob_pdcmp_data_ram_wea;
  output [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]     ob_pdcmp_data_ram_dina;
  output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     ob_pdcmp_data_ram_addrb;
  output                                         ob_pdcmp_data_ram_enb;
  input  [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]     ob_pdcmp_data_ram_doutb;
  output [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      ob_ccmp_data_ram_addra;
  output                                         ob_ccmp_data_ram_wea;
  //ccx_tgl: ; ob_ccmp_data_ram_dina; ; Randomization of access to the RAM.
  output [`CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]      ob_ccmp_data_ram_dina;
  output [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      ob_ccmp_data_ram_addrb;
  output                                         ob_ccmp_data_ram_enb;
  input  [`CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]      ob_ccmp_data_ram_doutb;
  // Read buffer
  output [K_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]     edmarbuff2ram_addra;
  output [K_DMA_RBUF_NSLICES-1:0]                                   edmarbuff2ram_we;
  output [K_DMA_RBUF_NSLICES*K_DMA_RBUF_SLICE_WD-1:0]               edmarbuff2ram_dout;
  output [K_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]     edmarbuff2ram_addrb;
  output [K_DMA_RBUF_NSLICES-1:0]                                   edmarbuff2ram_re;
  input  [K_DMA_RBUF_NSLICES*K_DMA_RBUF_SLICE_WD-1:0]               ram2edmarbuff_din;
  // RD Engine Linked List Pointers
  output logic           [`CC_IF_RDCTRL_LL_RAM_PW-1:0] edma_rd_eng_ll_addra_ram;
  output logic           [`CC_IF_RDCTRL_LL_RAM_PW-1:0] edma_rd_eng_ll_addrb_ram;
  //ccx_tgl: ; edma_rd_eng_ll_dout_ram; ; Randomization of access to the RAM.
  output logic           [`CC_IF_RDCTRL_LL_RAM_WD-1:0] edma_rd_eng_ll_dout_ram;
  output logic                                         edma_rd_eng_ll_we_ram;
  output logic                                         edma_rd_eng_ll_re_ram;
  input  logic           [`CC_IF_RDCTRL_LL_RAM_WD-1:0] edma_rd_eng_ll_din_ram;
  // WR Engine Linked List Pointers
  output logic           [`CC_IF_WRCTRL_LL_RAM_PW-1:0] edma_wr_eng_ll_addra_ram;
  output logic           [`CC_IF_WRCTRL_LL_RAM_PW-1:0] edma_wr_eng_ll_addrb_ram;
  //ccx_tgl: ; edma_wr_eng_ll_dout_ram; ; Randomization of access to the RAM.
  output logic           [`CC_IF_WRCTRL_LL_RAM_WD-1:0] edma_wr_eng_ll_dout_ram;
  output logic                                         edma_wr_eng_ll_we_ram;
  output logic                                         edma_wr_eng_ll_re_ram;
  input  logic           [`CC_IF_WRCTRL_LL_RAM_WD-1:0] edma_wr_eng_ll_din_ram;
  // RD Engine Descriptors Queue
  output logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_rd_eng_ovrl_addra_ram;
  output logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_rd_eng_ovrl_addrb_ram;
  //ccx_tgl: ; edma_rd_eng_ovrl_dout_ram; ; Randomization of access to the RAM.
  output logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_rd_eng_ovrl_dout_ram;
  output logic                                         edma_rd_eng_ovrl_we_ram;
  output logic                                         edma_rd_eng_ovrl_re_ram;
  input  logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_rd_eng_ovrl_din_ram;
  // WR Engine Descriptors Queue
  output logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_wr_eng_ovrl_addra_ram;
  output logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_wr_eng_ovrl_addrb_ram;
  //ccx_tgl: ; edma_wr_eng_ovrl_dout_ram; ; Randomization of access to the RAM.
  output logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_wr_eng_ovrl_dout_ram;
  output logic                                         edma_wr_eng_ovrl_we_ram;
  output logic                                         edma_wr_eng_ovrl_re_ram;
  input  logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_wr_eng_ovrl_din_ram;
  // RD Engine Completion to Memory Write LUT
  output logic           [`CC_IF_RD_CTXC2W_RAM_PW-1:0] edma_rd_eng_c2w_lut_addra_ram;
  output logic           [`CC_IF_RD_CTXC2W_RAM_PW-1:0] edma_rd_eng_c2w_lut_addrb_ram;
  //ccx_tgl: ; edma_rd_eng_c2w_lut_dout_ram; ; Randomization of access to the RAM.
  output logic           [`CC_IF_RD_CTXC2W_RAM_WD-1:0] edma_rd_eng_c2w_lut_dout_ram;
  output logic                                         edma_rd_eng_c2w_lut_we_ram;
  output logic                                         edma_rd_eng_c2w_lut_re_ram;
  input  logic           [`CC_IF_RD_CTXC2W_RAM_WD-1:0] edma_rd_eng_c2w_lut_din_ram;
  // WR Engine Completion to Memory Write LUT
  output logic           [`CC_IF_WR_CTXC2W_RAM_PW-1:0] edma_wr_eng_c2w_lut_addra_ram;
  output logic           [`CC_IF_WR_CTXC2W_RAM_PW-1:0] edma_wr_eng_c2w_lut_addrb_ram;
  //ccx_tgl: ; edma_wr_eng_c2w_lut_dout_ram; ; Randomization of access to the RAM.
  output logic           [`CC_IF_WR_CTXC2W_RAM_WD-1:0] edma_wr_eng_c2w_lut_dout_ram;
  output logic                                         edma_wr_eng_c2w_lut_we_ram;
  output logic                                         edma_wr_eng_c2w_lut_re_ram;
  input  logic           [`CC_IF_WR_CTXC2W_RAM_WD-1:0] edma_wr_eng_c2w_lut_din_ram;
  // RD Engine Status Handler LUT
  output logic          [`CC_IF_RD_CTXSTSH_RAM_PW-1:0] edma_rd_eng_stsh_lut_addra_ram;
  output logic          [`CC_IF_RD_CTXSTSH_RAM_PW-1:0] edma_rd_eng_stsh_lut_addrb_ram;
  //ccx_tgl: ; edma_rd_eng_stsh_lut_dout_ram; ; Randomization of access to the RAM.
  output logic          [`CC_IF_RD_CTXSTSH_RAM_WD-1:0] edma_rd_eng_stsh_lut_dout_ram;
  output logic                                         edma_rd_eng_stsh_lut_we_ram;
  output logic                                         edma_rd_eng_stsh_lut_re_ram;
  input  logic          [`CC_IF_RD_CTXSTSH_RAM_WD-1:0] edma_rd_eng_stsh_lut_din_ram;
  // WR Engine Status Handler LUT
  output logic          [`CC_IF_WR_CTXSTSH_RAM_PW-1:0] edma_wr_eng_stsh_lut_addra_ram;
  output logic          [`CC_IF_WR_CTXSTSH_RAM_PW-1:0] edma_wr_eng_stsh_lut_addrb_ram;
  //ccx_tgl: ; edma_wr_eng_stsh_lut_dout_ram; ; Randomization of access to the RAM.
  output logic          [`CC_IF_WR_CTXSTSH_RAM_WD-1:0] edma_wr_eng_stsh_lut_dout_ram;
  output logic                                         edma_wr_eng_stsh_lut_we_ram;
  output logic                                         edma_wr_eng_stsh_lut_re_ram;
  input  logic          [`CC_IF_WR_CTXSTSH_RAM_WD-1:0] edma_wr_eng_stsh_lut_din_ram;
  // RD Engine MSI Pointers
  output logic              [`CC_IF_RD_MSI_RAM_PW-1:0] edma_rd_eng_msi_addra_ram;
  output logic              [`CC_IF_RD_MSI_RAM_PW-1:0] edma_rd_eng_msi_addrb_ram;
  //ccx_tgl: ; edma_rd_eng_msi_dout_ram; ; Randomization of access to the RAM.
  output logic              [`CC_IF_RD_MSI_RAM_WD-1:0] edma_rd_eng_msi_dout_ram;
  output logic                                         edma_rd_eng_msi_we_ram;
  output logic                                         edma_rd_eng_msi_re_ram;
  input  logic              [`CC_IF_RD_MSI_RAM_WD-1:0] edma_rd_eng_msi_din_ram;
  // WR Engine MSI Pointers
  output logic              [`CC_IF_WR_MSI_RAM_PW-1:0] edma_wr_eng_msi_addra_ram;
  output logic              [`CC_IF_WR_MSI_RAM_PW-1:0] edma_wr_eng_msi_addrb_ram;
  //ccx_tgl: ; edma_wr_eng_msi_dout_ram; ; Randomization of access to the RAM.
  output logic              [`CC_IF_WR_MSI_RAM_WD-1:0] edma_wr_eng_msi_dout_ram;
  output logic                                         edma_wr_eng_msi_we_ram;
  output logic                                         edma_wr_eng_msi_re_ram;
  input  logic              [`CC_IF_WR_MSI_RAM_WD-1:0] edma_wr_eng_msi_din_ram;
  input  logic                                         edma_rd_eng_hard_stop_req;
  input  logic         [`CC_NUM_DMA_RD_CHAN_WIDTH-1:0] edma_rd_eng_hard_stop_channel;
  output logic                                         edma_rd_eng_hard_stop_ack;   
  input  logic                                         edma_wr_eng_hard_stop_req;
  input  logic         [`CC_NUM_DMA_WR_CHAN_WIDTH-1:0] edma_wr_eng_hard_stop_channel; 
  output logic                                         edma_wr_eng_hard_stop_ack;
  // Completions Status during DPC
  input                                                 core_in_dpc_i      ;
  input                                                 cfg_dpc_cpl_cntrl_i;

   //--------------------------------------
   // INTERNAL REG DECLARATION
   //--------------------------------------
   // Hardwired configuration inputs
   wire [`CX_REMOTE_LUT_PTR_WIDTH-1:0]            cfg_remote_max_bridge_tag;
   wire [2:0]                                     cfg_remote_rd_req_bridge_size;
   // Bridge -> DMA
   wire                                           d_trgt1_wreq_cmplt_dma;
   wire [`CC_NUM_DMA_RD_CHAN_WIDTH-1:0]           d_trgt1_wreq_cmplt_dma_channel;
   wire                                           d_trgt1_wreq_err_dma;

   //--------------------------------------
   // WIRE DECLARATION
   //--------------------------------------
   logic                                          crgb_ack;
   logic [CRGB_DATA_WIDTH-1:0]                    crgb_rd_data;


     wire [31:0]                                    dbi_addr;
     wire [31:0]                                    dbi_din;
     wire                                           dbi_cs;
     wire                                           dbi_cs2;
     wire [3:0]                                     dbi_wr;
     wire [2:0]                                     dbi_bar_num;
     wire [`CX_NFUNC_WD-1:0]                        dbi_func_num;
     wire                                           dbi_rom_access;
     wire                                           dbi_io_access;



   wire [K_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]   edmarbuff2ram_addra;
   wire [K_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]   edmarbuff2ram_addrb;
   wire [K_DMA_RBUF_NSLICES*K_DMA_RBUF_SLICE_WD-1:0]         edmarbuff2ram_dout;
   wire [K_DMA_RBUF_NSLICES-1:0]                             edmarbuff2ram_re;
   wire [K_DMA_RBUF_NSLICES-1:0]                             edmarbuff2ram_we;

   logic [`CC_NUM_DMA_WR_CHAN+`CC_NUM_DMA_RD_CHAN-1:0] edma_int;
   logic                                               edma_xfer_pending;
   // AXI master write request
   wire [`MASTER_BUS_ADDR_WIDTH -1:0]             mstr_awaddr;
   wire [`CC_MSTR_AW_USER_WIDTH-1:0]              mstr_awuser;
   wire [1:0]                                     mstr_awburst;
   wire [3:0]                                     mstr_awcache;
   wire [`CC_MSTR_BUS_ID_WIDTH -1:0]              mstr_awid;
   wire [`CC_MSTR_BURST_LEN_PW -1:0]              mstr_awlen;
   wire [`CC_AXI_LOCK_WIDTH-1:0]                  mstr_awlock;
   wire [`MSTR_MISC_INFO_PW -1:0]                 mstr_awmisc_info;
   wire                                           mstr_awmisc_info_last_dcmp_tlp;
   wire                                           mstr_awmisc_info_nw;
   wire                                           mstr_awmisc_info_cxlsrc;
   wire [1:0]                                     mstr_awmisc_info_ats;
   wire                                           mstr_awmisc_info_ep;
   wire [`CC_NUM_DMA_RD_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_awmisc_info_dma;
   wire [PRFX_WIDTH-1:0]                          mstr_awmisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]                    mstr_awmisc_info_tph;
   wire                                           mstr_awmisc_info_ido;
   wire [8:0]                                     mstr_awmisc_info_dst_segment;
   wire [8:0]                                     mstr_awmisc_info_req_segment;
   wire [2:0]                                     mstr_awprot;
   wire [2:0]                                     mstr_awsize;
   wire                                           mstr_awvalid;

   // AXI master write data
   wire [`MASTER_BUS_DATA_WIDTH -1:0]             mstr_wdata;
   wire [`CC_MSTR_W_USER_WIDTH-1:0]               mstr_wuser;
   wire                                           mstr_wlast;
   wire [`CC_MSTR_BUS_WSTRB_WIDTH -1:0]           mstr_wstrb;
   wire                                           mstr_wvalid;

   // AXI master write response
   wire                                           mstr_bready;

   // AXI master read request
   wire [`MASTER_BUS_ADDR_WIDTH -1:0]             mstr_araddr;
   wire [`CC_MSTR_AR_USER_WIDTH-1:0]              mstr_aruser;
   wire [1:0]                                     mstr_arburst;
   wire [3:0]                                     mstr_arcache;
   wire [`CC_MSTR_BUS_ID_WIDTH -1:0]              mstr_arid;
   wire [`CC_MSTR_BURST_LEN_PW -1:0]              mstr_arlen;
   wire [`CC_AXI_LOCK_WIDTH-1:0]                  mstr_arlock;
   wire [`MSTR_MISC_INFO_PW -1:0]                 mstr_armisc_info;
   wire                                           mstr_armisc_info_last_dcmp_tlp;
   wire                                           mstr_armisc_info_nw;
   wire                                           mstr_armisc_info_cxlsrc;
   wire [1:0]                                     mstr_armisc_info_ats;
   wire [`CC_NUM_DMA_MAX_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_armisc_info_dma;
   wire [PRFX_WIDTH-1:0]                          mstr_armisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]                    mstr_armisc_info_tph;
   wire                                           mstr_armisc_info_ido;
   wire                                           mstr_armisc_info_zeroread;
   wire [8:0]                                     mstr_armisc_info_dst_segment;
   wire [8:0]                                     mstr_armisc_info_req_segment;
   wire [2:0]                                     mstr_arprot;
   wire [2:0]                                     mstr_arsize;
   wire                                           mstr_arvalid;

   // AXI master read response & read data
   wire                                           mstr_rready;
   wire [3:0]                                     mstr_awqos;
   wire [1:0]                                     mstr_awbar;
   wire [1:0]                                     mstr_awdomain;
   wire [`CC_AXIJ_DMWR_VALUE *2+2:0]              mstr_awsnoop;
   wire [5:0]                                     mstr_awatop;
   wire [3:0]                                     mstr_arqos;
   wire [1:0]                                     mstr_arbar;
   wire [1:0]                                     mstr_ardomain;
   wire [3:0]                                     mstr_arsnoop;

   // AXI master low power
   wire                                           mstr_cactive;
   wire                                           mstr_csysack;


   wire [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]       ib_rreq_c2a_cdc_ram_addra;
   wire [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]       ib_rreq_c2a_cdc_ram_addrb;
   wire                                           ib_rreq_c2a_cdc_ram_wea;
   wire                                           ib_rreq_c2a_cdc_ram_enb;
   wire [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]       ib_rreq_c2a_cdc_ram_dina;
   wire [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]       ib_wreq_c2a_cdc_ram_addra;
   wire [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]       ib_wreq_c2a_cdc_ram_addrb;
   wire                                           ib_wreq_c2a_cdc_ram_wea;
   wire                                           ib_wreq_c2a_cdc_ram_enb;
   wire [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]       ib_wreq_c2a_cdc_ram_dina;

   // AXI slave Write address channel
   wire                                           slv_awready;

   // AXI slave Write data channel
   wire                                           slv_wready;

   // AXI slave Write response channel
   wire [`CC_SLV_BUS_ID_WIDTH -1:0]               slv_bid;
   wire [`SLV_RESP_MISC_INFO_PW -1:0]             slv_bmisc_info;
   wire [8:0]                                     slv_bmisc_info_dst_segment;
   wire [7:0]                                     slv_bmisc_info_cpl_segment;
   wire [`CC_AXIJ_DMWR_VALUE+1:0]                 slv_bresp;
   wire                                           slv_bvalid;

   // AXI slave Read address channel
   wire                                           slv_arready;

   // AXI slave Read data channel
   wire [`SLAVE_BUS_DATA_WIDTH-1:0]               slv_rdata;
   wire [`CC_SLV_BUS_DATAP_WIDTH-1:0]             slv_rdatap;
   wire [`CC_SLV_BUS_ID_WIDTH -1:0]               slv_rid;
   wire                                           slv_rlast;

   wire [`SLV_RESP_MISC_INFO_PW -1:0]             slv_rmisc_info;
   wire                                           slv_rmisc_info_ido;
   wire [8:0]                                     slv_rmisc_info_dst_segment;
   wire [7:0]                                     slv_rmisc_info_cpl_segment;
   wire [1:0]                                     slv_rresp;
   wire                                           slv_rvalid;

   // AXI slave Low-power Channel
   wire                                           slv_cactive;
   wire                                           slv_csysack;
   wire                                           brdg_mstr_xfer_pending;
   wire                                           trgt_cpl_lut_empty;
   wire                                           brdg_slv_xfer_pending; 
   wire                                           brdg_slv_flush_ack;
   wire                                           s_brdg_slv_xfer_pending;

   //--------------------------------------
   // INTERNAL WIRE DECLARATION
   //--------------------------------------
   logic                                          mstr_aclk_active_axi;

   logic                          int_radm_cpl_timeout;
   logic [1:0]                    int_radm_timeout_cpl_attr;
   logic [`CX_TAG_SIZE-1:0]       int_radm_timeout_cpl_tag;
   logic [2:0]                    int_radm_timeout_cpl_tc;
   logic [`CX_NFUNC_WD-1:0]       int_radm_timeout_func_num; 
   logic [`CX_NVC-1:0]                   trgt1_p_xfer_pend_per_vc;

   xali_pkt_t[`N_XALI_IF-1:0]    int_xali_xaim_pkt;
   logic[`N_XALI_IF-1:0]         int_xaim_xali_halt;

   xali_pkt_t[`N_XALI_IF-1:0]    d_xali_xaim_pkt;
   logic[`N_XALI_IF-1:0]         d_xaim_xali_halt;

   logic                         radm_edma_p_pending;
   
   logic [`CX_REMOTE_LOOKUPID_WD-1:0] int_radm_trgt1_np_0_lookup_id;
   logic [`CX_REMOTE_MAX_TAGS_WD-1:0] int_xali2_cpl_lookup_id;

   logic [`TRGT_DATA_WD-1:0]     int_radm_trgt1_p_0_data;
   logic [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0] int_radm_trgt1_p_0_hdr_prot;
   logic [PRFX_W_PAR-1:0]        int_radm_trgt1_p_0_prfx;
   logic [`CX_NW-1:0]            int_radm_trgt1_p_0_dwen;
   logic                         int_radm_trgt1_p_0_dv;
   logic                         int_radm_trgt1_p_0_hv;
   logic                         int_radm_trgt1_p_0_eot;
   logic                         int_radm_trgt1_p_0_dllp_abort;
   logic                         int_radm_trgt1_p_0_tlp_abort;
   logic                         int_radm_trgt1_p_0_ecrc_err;
   logic [1:0]                   int_radm_trgt1_p_0_fmt;
   logic [4:0]                   int_radm_trgt1_p_0_type;
   logic [2:0]                   int_radm_trgt1_p_0_tc;
   logic [`FLT_Q_ATTR_WIDTH-1:0] int_radm_trgt1_p_0_attr;
   logic [15:0]                   int_radm_trgt1_p_0_reqid;
   logic [`CX_TAG_SIZE-1:0]       int_radm_trgt1_p_0_tag;
   logic [`CX_NFUNC_WD-1:0]       int_radm_trgt1_p_0_func_num;
   logic                          int_radm_trgt1_p_0_td;
   logic                          int_radm_trgt1_p_0_poisoned;
   logic [9:0]                    int_radm_trgt1_p_0_dw_len;
   logic [3:0]                    int_radm_trgt1_p_0_first_be;
   logic [`CX_NVC_LOG2-1:0]       int_radm_trgt1_p_0_vc_num;
   logic [2:0]                    int_radm_trgt1_p_0_cpl_status;
   logic [`FLT_Q_ADDR_WIDTH-1:0]  int_radm_trgt1_p_0_addr;
   logic [`FLT_Q_ADDR_WIDTH-1:0]  int_radm_trgt1_p_0_hdr_uppr_bytes;
   logic                          int_radm_trgt1_p_0_rom_in_range;
   logic                          int_radm_trgt1_p_0_io_req_in_range;
   logic [2:0]                    int_radm_trgt1_p_0_in_membar_range;
   logic [3:0]                    int_radm_trgt1_p_0_last_be;
   logic [1:0]                    int_radm_trgt1_p_0_ats;
   logic                          int_radm_trgt1_p_0_nw;
   logic                          int_radm_trgt1_p_0_cxlsrc;
   logic                          int_radm_trgt1_p_0_th;
   logic [1:0]                    int_radm_trgt1_p_0_ph;
   logic [7:0]                    int_radm_trgt1_p_0_st;
   logic                          int_radm_trgt1_p_0_hdr_uppr_bytes_valid;
   logic [`DC_DMA_TYPE_WIDTH-1:0]        int_radm_trgt1_p_0_req_dma;
   logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]int_radm_trgt1_p_0_req_dma_channel;
   logic                          int_radm_trgt1_p_0_mem_type;
   logic [8:0]                    int_radm_trgt1_p_0_reqtr_sgmt;
   logic [8:0]                    int_radm_trgt1_p_0_dest_sgmt;
   logic [`CX_RADM_PKT_ORD_WD-1:0]int_radm_trgt1_p_0_pkt_order_no;
   
   logic [`TRGT_DATA_WD-1:0]      int_radm_trgt1_np_0_data;
   logic [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]  int_radm_trgt1_np_0_hdr_prot;
   logic [PRFX_W_PAR-1:0]         int_radm_trgt1_np_0_prfx;
   logic [`CX_NW-1:0]             int_radm_trgt1_np_0_dwen;
   logic                          int_radm_trgt1_np_0_dv;
   logic                          int_radm_trgt1_np_0_hv;
   logic                          int_radm_trgt1_np_0_eot;
   logic                          int_radm_trgt1_np_0_dllp_abort;
   logic                          int_radm_trgt1_np_0_tlp_abort;
   logic                          int_radm_trgt1_np_0_ecrc_err;
   logic [1:0]                    int_radm_trgt1_np_0_fmt;
   logic [4:0]                    int_radm_trgt1_np_0_type;
   logic [2:0]                    int_radm_trgt1_np_0_tc;
   logic [`FLT_Q_ATTR_WIDTH-1:0]  int_radm_trgt1_np_0_attr;
   logic [15:0]                   int_radm_trgt1_np_0_reqid;
   logic [`CX_TAG_SIZE-1:0]       int_radm_trgt1_np_0_tag;
   logic [`CX_NFUNC_WD-1:0]       int_radm_trgt1_np_0_func_num;
   logic [2:0]                    int_radm_trgt1_np_0_cpl_status;
   logic                          int_radm_trgt1_np_0_td;
   logic                          int_radm_trgt1_np_0_poisoned;
   logic [9:0]                    int_radm_trgt1_np_0_dw_len;
   logic [3:0]                    int_radm_trgt1_np_0_first_be;
   logic [`CX_NVC_LOG2-1:0]       int_radm_trgt1_np_0_vc_num;

   logic [`FLT_Q_ADDR_WIDTH-1:0]  int_radm_trgt1_np_0_addr;
   logic [`FLT_Q_ADDR_WIDTH-1:0]  int_radm_trgt1_np_0_hdr_uppr_bytes;

   logic                          int_radm_trgt1_np_0_rom_in_range;
   logic                          int_radm_trgt1_np_0_io_req_in_range;
   logic [2:0]                    int_radm_trgt1_np_0_in_membar_range;
   logic [3:0]                    int_radm_trgt1_np_0_last_be;
   logic [1:0]                    int_radm_trgt1_np_0_ats;
   logic                          int_radm_trgt1_np_0_nw;
   logic                          int_radm_trgt1_np_0_cxlsrc;
   logic                          int_radm_trgt1_np_0_th;
   logic [1:0]                    int_radm_trgt1_np_0_ph;
   logic [7:0]                    int_radm_trgt1_np_0_st;
   logic [`DC_DMA_TYPE_WIDTH-1:0]        int_radm_trgt1_np_0_req_dma;
   logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]int_radm_trgt1_np_0_req_dma_channel;
   logic                          int_radm_trgt1_np_0_mem_type;
   logic [8:0]                    int_radm_trgt1_np_0_reqtr_sgmt;
   logic [8:0]                    int_radm_trgt1_np_0_dest_sgmt;
   logic [`CX_RADM_PKT_ORD_WD-1:0]int_radm_trgt1_np_0_pkt_order_no;

   logic [`TRGT_DATA_WD-1:0]      int_radm_trgt1_cpl_0_data;
   logic [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]  int_radm_trgt1_cpl_0_hdr_prot;
   logic [PRFX_W_PAR-1:0]         int_radm_trgt1_cpl_0_prfx;
   logic [`CX_NW-1:0]             int_radm_trgt1_cpl_0_dwen;
   logic                          int_radm_trgt1_cpl_0_dv;
   logic                          int_radm_trgt1_cpl_0_hv;
   logic                          int_radm_trgt1_cpl_0_eot;
   logic                          int_radm_trgt1_cpl_0_dllp_abort;
   logic                          int_radm_trgt1_cpl_0_tlp_abort;
   logic                          int_radm_trgt1_cpl_0_ecrc_err;
   logic [1:0]                    int_radm_trgt1_cpl_0_fmt;
   logic [4:0]                    int_radm_trgt1_cpl_0_type;
   logic [2:0]                    int_radm_trgt1_cpl_0_tc;
   logic [`FLT_Q_ATTR_WIDTH-1:0]  int_radm_trgt1_cpl_0_attr;
   logic [15:0]                   int_radm_trgt1_cpl_0_reqid;
   logic [`CX_TAG_SIZE-1:0]       int_radm_trgt1_cpl_0_tag;
   logic [`CX_NFUNC_WD-1:0]       int_radm_trgt1_cpl_0_func_num;
   logic [2:0]                    int_radm_trgt1_cpl_0_cpl_status;
   logic                          int_radm_trgt1_cpl_0_td;
   logic                          int_radm_trgt1_cpl_0_poisoned;
   logic [9:0]                    int_radm_trgt1_cpl_0_dw_len;
   logic                          int_radm_trgt1_cpl_0_bcm;
   logic [11:0]                   int_radm_trgt1_cpl_0_byte_cnt;
   logic [15:0]                   int_radm_trgt1_cpl_0_cmpltr_id;
   logic                          int_radm_trgt1_cpl_0_last;
   logic [`CX_NVC_LOG2-1:0]       int_radm_trgt1_cpl_0_vc_num;
   
   logic [`FLT_Q_ADDR_WIDTH-1:0]  int_radm_trgt1_cpl_0_addr;
   
   logic [8:0]                    int_radm_trgt1_cpl_0_dest_sgmt;
   logic [7:0]                    int_radm_trgt1_cpl_0_cpl_sgmt;
   logic [`CX_RADM_PKT_ORD_WD -1 :0]int_radm_trgt1_cpl_0_pkt_order_no;
 
   logic                          int_trgt1_radm_intf_cpl_0_halt;
   logic                          int_trgt1_radm_intf_p_0_halt;
   logic                          int_trgt1_radm_intf_np_0_halt;
   
   logic [`DC_DMA_TYPE_WIDTH-1:0]        int_radm_trgt1_cpl_0_req_dma;
   logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]int_radm_trgt1_cpl_0_req_dma_channel;

   logic [`CC_NUM_DMA_RD_CHAN-1:0] dma_mcb_rdll_halt;
   logic [`CC_NUM_DMA_WR_CHAN-1:0] dma_mcb_wrll_halt;






  DWC_pcie_edmapf_aclks_if     b_edma_clk();
  DWC_pcie_edmapf_cdmregs_if   b_edma_cdm();
  DWC_pcie_edmapf_crgb_if      b_edma_crgb();

  DWC_pcie_edmapf_hard_stop_if #(
     .P_CHANWD      ( `CC_NUM_DMA_RD_CHAN_WIDTH )
  ) b_rdEng_hard_stop ();

  DWC_pcie_edmapf_hard_stop_if #(
     .P_CHANWD      ( `CC_NUM_DMA_WR_CHAN_WIDTH )
    ) b_wrEng_hard_stop ();
  
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE    ( logic       )
   ) b_clientPending();

  DWC_pcie_edmapf_tlp_wresp_if #(
     .P_CHANWD      ( `CC_NUM_DMA_RD_CHAN_WIDTH )
   ) b_edma_wresp();

  DWC_pcie_edmapf_status_if #(
     .P_CHAN      ( `CC_NUM_DMA_RD_CHAN ) 
    ) b_edma_status_rd();

  DWC_pcie_edmapf_status_if #(
     .P_CHAN      ( `CC_NUM_DMA_WR_CHAN )
    ) b_edma_status_wr();

  DWC_pcie_edmapf_tlp_if #(
     .P_HEADERTYPE ( xradm_s                            )
    ,.P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CX_RASDP_TRGT1_P_HDR_PROT_WD      )
    ) b_app_trgt_p();

  DWC_pcie_edmapf_tlp_if #(
     .P_HEADERTYPE ( xradm_s                            )
    ,.P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CX_RASDP_TRGT1_NP_HDR_PROT_WD     )
    ) b_app_trgt_np();
    
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CLIENT_HDR_PROT_WD                )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_app_client_cpl();    

  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CLIENT_HDR_PROT_WD                )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_app_client_p();

  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CLIENT_HDR_PROT_WD                )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_app_client_np();  
  
  DWC_pcie_edmapf_tlp_if #(
     .P_HEADERTYPE ( xradm_s                            )
    ,.P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CX_RASDP_TRGT1_CPL_HDR_PROT_WD    )
    ) b_app_trgt_cpl() ;
    
  DWC_pcie_edmapf_tlp_header_if #(
    .P_HEADERTYPE  ( timeout_s        )
  ) b_app_trgt_timeout();  

  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CX_RASDP_TRGT1_P_HDR_PROT_WD      )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_core_trgt_p();

  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CX_RASDP_TRGT1_NP_HDR_PROT_WD     )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_core_trgt_np();
  
  DWC_pcie_edmapf_tlp_if #(
     .P_HEADERTYPE ( xradm_s                            )
    ,.P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CLIENT_HDR_PROT_WD                )
    ) b_core_client_cpl();

  DWC_pcie_edmapf_tlp_if #(
     .P_HEADERTYPE ( xradm_s                            )
    ,.P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CLIENT_HDR_PROT_WD                )
    ) b_core_client_p();    
    
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CLIENT_HDR_PROT_WD                )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_core_client_np();

  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD     ( `CC_CORE_DATA_BUS_WD               )
    ,.P_HDR_PROT_WD( `CX_RASDP_TRGT1_CPL_HDR_PROT_WD    )
    ,.P_HEADERTYPE ( xradm_s                            )
  ) b_core_trgt_cpl();
  
    DWC_pcie_edmapf_tlp_header_if #(
    .P_HEADERTYPE  ( timeout_s        )
  ) b_core_trgt_timeout(); 

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP             (K_RDBUFFER_RAM_DP )
    ,.PW             (K_RDBUFFER_RAM_PW )
    ,.WD             (K_RDBUFFER_RAM_WD )
    ,.P_ADDR_PROT_WD (K_RDBUFFER_RAM_PRW)
  ) b_rdBuffer_ram0();


  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CC_DMATAGS)
    ,.PW ($clog2(`CC_DMATAGS))
    ,.WD (`CC_IF_RD_CTXC2W_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_RD_CTXC2W_RAM_PW_PAR)
  ) b_rdEng_c2w_lut_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_DP)
    ,.PW (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW)
    ,.WD (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW_PAR)
  ) b_rdEng_ovrl_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CX_NUM_DMA_RD_CHAN)
    ,.PW (`CC_NUM_DMA_RD_CHAN_WIDTH)
    ,.WD (`CC_IF_RDCTRL_LL_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_RDCTRL_LL_RAM_PW_PAR)
  ) b_rdEng_ll_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CX_NUM_DMA_RD_CHAN)
    ,.PW (`CC_NUM_DMA_RD_CHAN_WIDTH)
    ,.WD (`CC_IF_RD_MSI_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_RD_MSI_RAM_PW_PAR)
  ) b_rdEng_msi_lut_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CC_DMATAGS)
    ,.PW ($clog2(`CC_DMATAGS))
    ,.WD (`CC_IF_RD_CTXSTSH_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_RD_CTXSTSH_RAM_PW_PAR)
  ) b_rdEng_stsh_lut_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CC_DMATAGS)
    ,.PW ($clog2(`CC_DMATAGS))
    ,.WD (`CC_IF_WR_CTXC2W_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_WR_CTXC2W_RAM_PW_PAR)
  ) b_wrEng_c2w_lut_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_DP)
    ,.PW (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW)
    ,.WD (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW_PAR)
  ) b_wrEng_ovrl_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CX_NUM_DMA_WR_CHAN)
    ,.PW (`CC_NUM_DMA_WR_CHAN_WIDTH)
    ,.WD (`CC_IF_WRCTRL_LL_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_WRCTRL_LL_RAM_PW_PAR)
  ) b_wrEng_ll_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CX_NUM_DMA_WR_CHAN)
    ,.PW (`CC_NUM_DMA_WR_CHAN_WIDTH)
    ,.WD (`CC_IF_WR_MSI_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_WR_MSI_RAM_PW_PAR)
  ) b_wrEng_msi_lut_ram();

  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP (`CC_DMATAGS)
    ,.PW ($clog2(`CC_DMATAGS))
    ,.WD (`CC_IF_WR_CTXSTSH_RAM_WD)
    ,.P_ADDR_PROT_WD (`CC_IF_WR_CTXSTSH_RAM_PW_PAR)
  ) b_wrEng_stsh_lut_ram();
  
  DWC_pcie_edmapf_rasdp_if  b_DWC_pcie_edmapf_rasdp_if_0 ();

  logic s_brdg_slv_core_client_p;

   //--------------------------------------
   // BRIDGE INSTANCE
   //--------------------------------------

`ifndef UTB_NATIVE_AXI
  wire brdg_trgt1_p_xfer_done;
  DWC_pcie_bridge_ib_trgt1_trkr
  

    u_ib_trgt1_trkr (
       .clk                       ( core_clk                      )
      ,.rstn                      ( core_rst_n                    )

      ,.radm_trgt1_p_0_pending    ( radm_trgt1_p_0_pending        )
      ,.radm_trgt1_p_0_hv         ( radm_trgt1_p_0_hv             )
      ,.radm_trgt1_p_0_eot        ( b_app_trgt_p.w_eot                       )
      ,.radm_trgt1_p_0_dllp_abort ( b_app_trgt_p.w_header.common4.dllp_abort )
      ,.trgt1_radm_intf_p_0_halt  ( trgt1_radm_intf_p_0_halt      )
      ,.brdg_radm_intf_p_0_halt   ( int_trgt1_radm_intf_p_0_halt  )

      ,.trgt_cpl_lut_empty        ( trgt_cpl_lut_empty            )
      ,.brdg_trgt1_p_xfer_done    ( brdg_trgt1_p_xfer_done        )
      ,.brdg_mstr_xfer_pending    ( brdg_mstr_xfer_pending        )
      ,.radm_edma_p_pending       ( radm_edma_p_pending           )
     );


   `BRIDGE_TOP
       `BRIDGE_INST  (
                         .core_clk                       (core_clk)
                        ,.core_rst_n                     (core_rst_n)
                        ,.aux_clk                        (aux_clk)
                        ,.aux_clk_g                      (aux_clk_g)
                        ,.cfg_axi_clk_gating_en          (cfg_axi_clk_gating_en)
                        ,.cfg_slv_resp_err_map           (cfg_slv_resp_err_map)
                        ,.cfg_err_resp_mode              (cfg_err_resp_mode)
                        ,.cfg_max_payload_size           (cfg_max_payload_size)
                        ,.cfg_max_rd_req_size            (cfg_max_rd_req_size)
                        ,.cfg_ext_tag_en                 (cfg_ext_tag_en)
                        ,.cfg_10b_tag_en                 (cfg_10b_tag_en)
                        ,.cfg_dmwr_req_en                (cfg_dmwr_req_en)
                        ,.cfg_memtype_value              (cfg_memtype_value)
                        ,.cfg_memtype_boundary           (cfg_memtype_boundary)
                        ,.cfg_pbus_dev_num               (cfg_pbus_dev_num)
                        ,.cfg_pbus_num                   (cfg_pbus_num)
                        ,.cfg_subbus_num                 (cfg_subbus_num)
                        ,.cfg_2ndbus_num                 (cfg_2ndbus_num)
                        ,.cfg_ax_ib_cpl_pass_p           (cfg_ax_ib_cpl_pass_p)
                        ,.cfg_ax_snp_en                  (cfg_ax_snp_en)
                        ,.cfg_ib_p_id_mng_ctrl           (cfg_ib_p_id_mng_ctrl)
                        ,.cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map)
                        ,.xali_posted_tlp_sent           (xali_posted_tlp_sent)
                        ,.cfg_ax_mstr_np_pass_p          (cfg_ax_mstr_np_pass_p)
                        ,.cfg_ax_mstr_ordr_p_event_sel   (cfg_ax_mstr_ordr_p_event_sel)
                        ,.cfg_mstr_arcache_mode          (cfg_mstr_arcache_mode)
                        ,.cfg_mstr_awcache_mode          (cfg_mstr_awcache_mode)
                        ,.cfg_mstr_arcache_value         (cfg_mstr_arcache_value)
                        ,.cfg_mstr_awcache_value         (cfg_mstr_awcache_value)
                        ,.cfg_aximstr_msg_addr_high      (cfg_aximstr_msg_addr_high)
                        ,.cfg_aximstr_msg_addr_low       (cfg_aximstr_msg_addr_low)

                        ,.cfg_mstr_ardomain_mode         (cfg_mstr_ardomain_mode)
                        ,.cfg_mstr_awdomain_mode         (cfg_mstr_awdomain_mode)
                        ,.cfg_mstr_ardomain_value        (cfg_mstr_ardomain_value)
                        ,.cfg_mstr_awdomain_value        (cfg_mstr_awdomain_value)
                        ,.cfg_ax_mstr_zeroread_fw        (cfg_ax_mstr_zeroread_fw)
    // ***************************************************
    // RAS.DP IO
    // ***************************************************
                        ,.cfg_rasdp_err_mode                          (cfg_rasdp_err_mode                 )
                        ,.cfg_rasdp_err_mode_en                       (cfg_rasdp_err_mode_en              )
                        ,.axi_bridge_out_ras_dp_err_log               (axi_bridge_out_ras_dp_err_log      )
                        ,.axi_bridge_in_ras_dp_err_inj                (axi_bridge_in_ras_dp_err_inj       )
                        ,.axi_bridge_in_ras_dp_err_inj_wake_up        (axi_bridge_in_ras_dp_err_inj_wake_up)
                        ,.cfg_ras_recc_npw_sab_correct                (cfg_ras_recc_npw_sab_correct       )
                        ,.axi_ras_recc_corr_cnt_npw_sab_pulse         (axi_ras_recc_corr_cnt_npw_sab_pulse)
                        ,.axi_ras_recc_corr_cnt_npw_sab_addr          (axi_ras_recc_corr_cnt_npw_sab_addr )
                        ,.axi_ras_recc_ucorr_cnt_npw_sab_pulse        (axi_ras_recc_ucorr_cnt_npw_sab_pulse)
                        ,.axi_ras_recc_ucorr_cnt_npw_sab_addr         (axi_ras_recc_ucorr_cnt_npw_sab_addr)

                        ,.cfg_ras_recc_ob_npdcmp_correct              (cfg_ras_recc_ob_npdcmp_correct            )
                        ,.axi_ras_recc_corr_cnt_ob_npdcmp_pulse       (axi_ras_recc_corr_cnt_ob_npdcmp_pulse     )
                        ,.axi_ras_recc_corr_cnt_ob_npdcmp_addr        (axi_ras_recc_corr_cnt_ob_npdcmp_addr      )
                        ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse      (axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse    )
                        ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_addr       (axi_ras_recc_ucorr_cnt_ob_npdcmp_addr     )

                        ,.cfg_ras_recc_ob_pdcmp_hdr_correct           (cfg_ras_recc_ob_pdcmp_hdr_correct         )
                        ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse    (axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse  )
                        ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr     (axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr   )
                        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse   (axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse )
                        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr    (axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr  )

                        ,.cfg_ras_recc_ob_pdcmp_data_correct          (cfg_ras_recc_ob_pdcmp_data_correct        )
                        ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse   (axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse )
                        ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_addr    (axi_ras_recc_corr_cnt_ob_pdcmp_data_addr  )
                        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse  (axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse)
                        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr   (axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr )

                        ,.cfg_ras_recc_ob_ccmp_data_correct           (cfg_ras_recc_ob_ccmp_data_correct         )
                        ,.axi_ras_recc_corr_cnt_ob_ccmp_data_pulse    (axi_ras_recc_corr_cnt_ob_ccmp_data_pulse  )
                        ,.axi_ras_recc_corr_cnt_ob_ccmp_data_addr     (axi_ras_recc_corr_cnt_ob_ccmp_data_addr   )
                        ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse   (axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse )
                        ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr    (axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr  )

                        ,.cfg_ras_recc_ib_sch_p_hdr_correct           (cfg_ras_recc_ib_sch_p_hdr_correct           )
                        ,.axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse    (axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse    )
                        ,.axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr     (axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr     )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse   (axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse   )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr    (axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr    )
                        ,.cfg_ras_recc_ib_sch_p_data_correct          (cfg_ras_recc_ib_sch_p_data_correct          )
                        ,.axi_ras_recc_corr_cnt_ib_sch_p_data_pulse   (axi_ras_recc_corr_cnt_ib_sch_p_data_pulse   )
                        ,.axi_ras_recc_corr_cnt_ib_sch_p_data_addr    (axi_ras_recc_corr_cnt_ib_sch_p_data_addr    )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse  (axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse  )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr   (axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr   )
                        ,.cfg_ras_recc_ib_sch_np_hdr_correct          (cfg_ras_recc_ib_sch_np_hdr_correct          )
                        ,.axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse   (axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse   )
                        ,.axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr    (axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr    )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse  (axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse  )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr   (axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr   )
                        ,.cfg_ras_recc_ib_sch_np_data_correct         (cfg_ras_recc_ib_sch_np_data_correct         )
                        ,.axi_ras_recc_corr_cnt_ib_sch_np_data_pulse  (axi_ras_recc_corr_cnt_ib_sch_np_data_pulse  )
                        ,.axi_ras_recc_corr_cnt_ib_sch_np_data_addr   (axi_ras_recc_corr_cnt_ib_sch_np_data_addr   )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse (axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse )
                        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr  (axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr  )
                        ,.cfg_ras_recc_ib_rreq_c2a_cdc_correct        (cfg_ras_recc_ib_rreq_c2a_cdc_correct        )
                        ,.axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse (axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse )
                        ,.axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr  (axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr  )
                        ,.axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse(axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse)
                        ,.axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr (axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr )

                        ,.cfg_ras_recc_ib_wreq_c2a_cdc_correct        (cfg_ras_recc_ib_wreq_c2a_cdc_correct        )
                        ,.axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse (axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse )
                        ,.axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr  (axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr  )
                        ,.axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse(axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse)
                        ,.axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr (axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr )

                        ,.cfg_ras_recc_ib_mcpl_a2c_cdc_correct        (cfg_ras_recc_ib_mcpl_a2c_cdc_correct        )
                        ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse (axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse )
                        ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr  (axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr  )
                        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse(axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse)
                        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr (axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr )


                        ,.cfg_ras_recc_ib_mcpl_sb_correct             (cfg_ras_recc_ib_mcpl_sb_correct             )
                        ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse      (axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse      )
                        ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_addr       (axi_ras_recc_corr_cnt_ib_mcpl_sb_addr       )
                        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse     (axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse     )
                        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr      (axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr      )


                        ,.axi_ras_par_rtrgt_p_ad_pulse                (axi_ras_par_rtrgt_p_ad_pulse                )
                        ,.axi_ras_par_rtrgt_p_dt_pulse                (axi_ras_par_rtrgt_p_dt_pulse                )
                        ,.axi_ras_par_rtrgt_np_ad_pulse               (axi_ras_par_rtrgt_np_ad_pulse               )
                        ,.axi_ras_par_rtrgt_np_dt_pulse               (axi_ras_par_rtrgt_np_dt_pulse               )
                        ,.axi_ras_par_rtrgt_cpl_ad_pulse              (axi_ras_par_rtrgt_cpl_ad_pulse              )
                        ,.axi_ras_par_rtrgt_cpl_dt_pulse              (axi_ras_par_rtrgt_cpl_dt_pulse              )
                        ,.axi_ras_par_ib_mcpl_dt_pulse                (axi_ras_par_ib_mcpl_dt_pulse                )



                        ,.axi_ras_par_ibwr_dcmp_dt_pulse              (axi_ras_par_ibwr_dcmp_dt_pulse              )
                        ,.axi_ras_par_ibwr_dcmp_ad_pulse              (axi_ras_par_ibwr_dcmp_ad_pulse              )
                        ,.axi_ras_par_ibrd_dcmp_ad_pulse              (axi_ras_par_ibrd_dcmp_ad_pulse              )


                        ,.axi_ras_par_ib_sch_p_ad_pulse               (axi_ras_par_ib_sch_p_ad_pulse               )
                        ,.axi_ras_par_ib_sch_p_dt_pulse               (axi_ras_par_ib_sch_p_dt_pulse               )
                        ,.axi_ras_par_ib_sch_np_ad_pulse              (axi_ras_par_ib_sch_np_ad_pulse              )
                        ,.axi_ras_par_ib_sch_np_dt_pulse              (axi_ras_par_ib_sch_np_dt_pulse              )

                        ,.axi_ras_par_ib_mcpl_a2c_dt_pulse            (axi_ras_par_ib_mcpl_a2c_dt_pulse            )
                        ,.axi_ras_par_ib_mcpl_sb_dt_pulse             (axi_ras_par_ib_mcpl_sb_dt_pulse             )
                        ,.axi_ras_par_ibwq_mrf_dt_pulse               (axi_ras_par_ibwq_mrf_dt_pulse               )
                        ,.axi_ras_par_ibwq_mrf_ad_pulse               (axi_ras_par_ibwq_mrf_ad_pulse               )
                        ,.axi_ras_par_ibrd_mrf_ad_pulse               (axi_ras_par_ibrd_mrf_ad_pulse               )

                        ,.axi_ras_par_npqdec_ad_pulse                 (axi_ras_par_npqdec_ad_pulse                 )

                        ,.axi_ras_par_pqdec_ad_pulse                  (axi_ras_par_pqdec_ad_pulse                  )
                        ,.axi_ras_par_swwrap_dt_pulse                 (axi_ras_par_swwrap_dt_pulse                 )
                        ,.axi_ras_par_swwrap_ad_pulse                 (axi_ras_par_swwrap_ad_pulse                 )
                        ,.axi_ras_par_srwrap_ad_pulse                 (axi_ras_par_srwrap_ad_pulse                 )
                        ,.axi_ras_par_swrq_npw_dt_pulse               (axi_ras_par_swrq_npw_dt_pulse               )
                        ,.axi_ras_par_swrq_npw_ad_pulse               (axi_ras_par_swrq_npw_ad_pulse               )

                        ,.axi_ras_par_slnull_dt_pulse                 (axi_ras_par_slnull_dt_pulse                 )
                        ,.axi_ras_par_slnull_ad_pulse                 (axi_ras_par_slnull_ad_pulse                 )

                        ,.axi_ras_par_c2_ad_pulse                     (axi_ras_par_c2_ad_pulse                     )
                        ,.axi_ras_par_c2_dt_pulse                     (axi_ras_par_c2_dt_pulse                     )
                        ,.axi_ras_par_c1_ad_pulse                     (axi_ras_par_c1_ad_pulse                     )
                        ,.axi_ras_par_c1_dt_pulse                     (axi_ras_par_c1_dt_pulse                     )
                        ,.axi_ras_par_ob_np_dcmp_inq_dt_pulse         (axi_ras_par_ob_np_dcmp_inq_dt_pulse         )
                        ,.axi_ras_par_ob_p_dcmp_inq_dt_pulse          (axi_ras_par_ob_p_dcmp_inq_dt_pulse          )
                        ,.axi_ras_par_ob_cpl_comp_dt_pulse            (axi_ras_par_ob_cpl_comp_dt_pulse            )
                        ,.axi_slv_sisb_uncorr_pulse                   (axi_slv_sisb_uncorr_pulse                   )
                        ,.axi_mstr_misb_uncorr_pulse                  (axi_mstr_misb_uncorr_pulse                  )

                        ,.atu_reg_out_base               (atu_reg_out_base)
                        ,.atu_reg_out_en                 (atu_reg_out_en)
                        ,.atu_reg_out_invert             (atu_reg_out_invert)
                        ,.atu_reg_out_limit              (atu_reg_out_limit)
                        ,.atu_reg_out_uppr_limit         (atu_reg_out_uppr_limit)
                        ,.atu_reg_out_incr_rgn_size      (atu_reg_out_incr_rgn_size)
                        ,.atu_reg_out_type               (atu_reg_out_type)
                        ,.atu_reg_out_func_num           (atu_reg_out_func_num)
                        ,.atu_reg_out_func_bypass        (atu_reg_out_func_bypass)
                        ,.atu_reg_out_upr_base           (atu_reg_out_upr_base)
                        ,.atu_reg_out_snp                (atu_reg_out_snp)

                        ,.brdg_slv_xfer_pending          (s_brdg_slv_xfer_pending)
                        ,.brdg_trgt1_p_xfer_done         (brdg_trgt1_p_xfer_done)
                        ,.brdg_mstr_xfer_pending         (brdg_mstr_xfer_pending)
                        ,.app_xfer_pending               (app_xfer_pending)
                        ,.edma_xfer_pending              (edma_xfer_pending)
                        ,.brdg_dbi_xfer_pending          (brdg_dbi_xfer_pending)
                        ,.rstctl_slv_flush_req           (rstctl_slv_flush_req)
                        ,.rstctl_mstr_flush_req          (rstctl_mstr_flush_req)
                        ,.brdg_slv_flush_ack             (brdg_slv_flush_ack)
                        ,.ib_mcpl_sb_ram_doutb           (ib_mcpl_sb_ram_doutb)
                        ,.ib_mcpl_a2c_cdc_ram_doutb      (ib_mcpl_a2c_cdc_ram_doutb)
                        ,.mstr_aclk_g                    (mstr_aclk_g)
                        ,.mstr_aresetn                   (mstr_aresetn)
                        ,.mstr_aclk                      (mstr_aclk)
                        ,.en_mstr_aclk_g                 (mstr_aclk_active_axi)
                        ,.mstr_rasdp_err_mode            (mstr_rasdp_err_mode)
                        ,.mstr_awready                   (mstr_awready)
                        ,.mstr_wready                    (mstr_wready)
                        ,.mstr_bid                       (mstr_bid)
                        ,.mstr_bvalid                    (mstr_bvalid)
                        ,.mstr_bresp                     (mstr_bresp)
                        ,.mstr_bmisc_info_cpl_stat       (mstr_bmisc_info_cpl_stat)
  
                        ,.mstr_arready                   (mstr_arready)
                        ,.mstr_rid                       (mstr_rid)
                        ,.mstr_rvalid                    (mstr_rvalid)
                        ,.mstr_rlast                     (mstr_rlast)
                        ,.mstr_rdata                     (mstr_rdata)
                        ,.mstr_ruser                     (mstr_ruser)
                        ,.mstr_rresp                     (mstr_rresp)
                        ,.mstr_rmisc_info_cpl_stat       (mstr_rmisc_info_cpl_stat)
                        ,.mstr_rmisc_info                (mstr_rmisc_info)
 
                        ,.mstr_csysreq                   (mstr_csysreq)
                        ,.radm_cpl_timeout               (int_radm_cpl_timeout)
                        ,.radm_timeout_cpl_attr          (int_radm_timeout_cpl_attr)
                        ,.radm_timeout_cpl_tag           (int_radm_timeout_cpl_tag)
                        ,.radm_timeout_cpl_tc            (int_radm_timeout_cpl_tc)
                        ,.radm_timeout_func_num          (int_radm_timeout_func_num)
                        ,.trgt_lookup_id                      (int_radm_trgt1_np_0_lookup_id          )

                        ,.radm_trgt1_p_0_pending              (radm_edma_p_pending                    )

                        ,.radm_trgt1_p_0_data                 (int_radm_trgt1_p_0_data                )
                        ,.radm_trgt1_p_0_hdr_prot             (int_radm_trgt1_p_0_hdr_prot            )
                        ,.radm_trgt1_p_0_prfx                 (int_radm_trgt1_p_0_prfx                )
                        ,.radm_trgt1_p_0_dwen                 (int_radm_trgt1_p_0_dwen                )
                        ,.radm_trgt1_p_0_dv                   (int_radm_trgt1_p_0_dv                  )
                        ,.radm_trgt1_p_0_hv                   (int_radm_trgt1_p_0_hv                  )
                        ,.radm_trgt1_p_0_eot                  (int_radm_trgt1_p_0_eot                 )
                        ,.radm_trgt1_p_0_dllp_abort           (int_radm_trgt1_p_0_dllp_abort          )
                        ,.radm_trgt1_p_0_tlp_abort            (int_radm_trgt1_p_0_tlp_abort           )
                        ,.radm_trgt1_p_0_ecrc_err             (int_radm_trgt1_p_0_ecrc_err            )
                        ,.radm_trgt1_p_0_fmt                  (int_radm_trgt1_p_0_fmt                 )
                        ,.radm_trgt1_p_0_type                 (int_radm_trgt1_p_0_type                )
                        ,.radm_trgt1_p_0_tc                   (int_radm_trgt1_p_0_tc                  )
                        ,.radm_trgt1_p_0_attr                 (int_radm_trgt1_p_0_attr                )
                        ,.radm_trgt1_p_0_reqid                (int_radm_trgt1_p_0_reqid               )
                        ,.radm_trgt1_p_0_tag                  (int_radm_trgt1_p_0_tag                 )
                        ,.radm_trgt1_p_0_func_num             (int_radm_trgt1_p_0_func_num            )
                        ,.radm_trgt1_p_0_td                   (int_radm_trgt1_p_0_td                  )
                        ,.radm_trgt1_p_0_poisoned             (int_radm_trgt1_p_0_poisoned            )
                        ,.radm_trgt1_p_0_dw_len               (int_radm_trgt1_p_0_dw_len              )
                        ,.radm_trgt1_p_0_first_be             (int_radm_trgt1_p_0_first_be            )
                        ,.radm_trgt1_p_0_vc_num               (int_radm_trgt1_p_0_vc_num              )
                        ,.radm_trgt1_p_0_cpl_status           (int_radm_trgt1_p_0_cpl_status          )
                        ,.radm_trgt1_p_0_addr                 (int_radm_trgt1_p_0_addr                )
                        ,.radm_trgt1_p_0_hdr_uppr_bytes       (int_radm_trgt1_p_0_hdr_uppr_bytes      )
                        ,.radm_trgt1_p_0_rom_in_range         (int_radm_trgt1_p_0_rom_in_range        )
                        ,.radm_trgt1_p_0_io_req_in_range      (int_radm_trgt1_p_0_io_req_in_range     )
                        ,.radm_trgt1_p_0_in_membar_range      (int_radm_trgt1_p_0_in_membar_range     )
                        ,.radm_trgt1_p_0_last_be              (int_radm_trgt1_p_0_last_be             )
                        ,.radm_trgt1_p_0_ats                  (int_radm_trgt1_p_0_ats                 )
                        ,.radm_trgt1_p_0_nw                   (int_radm_trgt1_p_0_nw                  )
                        ,.radm_trgt1_p_0_th                   (int_radm_trgt1_p_0_th                  )
                        ,.radm_trgt1_p_0_ph                   (int_radm_trgt1_p_0_ph                  )
                        ,.radm_trgt1_p_0_st                   (int_radm_trgt1_p_0_st                  )
                        ,.radm_trgt1_p_0_hdr_uppr_bytes_valid (int_radm_trgt1_p_0_hdr_uppr_bytes_valid)
                        ,.radm_trgt1_p_0_req_dma              (int_radm_trgt1_p_0_req_dma             )
                        ,.radm_trgt1_p_0_req_dma_channel      (int_radm_trgt1_p_0_req_dma_channel     )
                        ,.radm_trgt1_p_0_req_dma_mem_type     (int_radm_trgt1_p_0_mem_type            )
                        ,.radm_trgt1_p_0_reqtr_sgmt           (int_radm_trgt1_p_0_reqtr_sgmt          )
                        ,.radm_trgt1_p_0_dest_sgmt            (int_radm_trgt1_p_0_dest_sgmt           )
                        ,.radm_trgt1_p_0_pkt_order_no         (int_radm_trgt1_p_0_pkt_order_no        )
                        ,.radm_trgt1_np_0_data                (int_radm_trgt1_np_0_data               )
                        ,.radm_trgt1_np_0_hdr_prot            (int_radm_trgt1_np_0_hdr_prot           )
                        ,.radm_trgt1_np_0_prfx                (int_radm_trgt1_np_0_prfx               )
                        ,.radm_trgt1_np_0_dwen                (int_radm_trgt1_np_0_dwen               )
                        ,.radm_trgt1_np_0_dv                  (int_radm_trgt1_np_0_dv                 )
                        ,.radm_trgt1_np_0_hv                  (int_radm_trgt1_np_0_hv                 )
                        ,.radm_trgt1_np_0_eot                 (int_radm_trgt1_np_0_eot                )
                        ,.radm_trgt1_np_0_dllp_abort          (int_radm_trgt1_np_0_dllp_abort         )
                        ,.radm_trgt1_np_0_tlp_abort           (int_radm_trgt1_np_0_tlp_abort          )
                        ,.radm_trgt1_np_0_ecrc_err            (int_radm_trgt1_np_0_ecrc_err           )
                        ,.radm_trgt1_np_0_fmt                 (int_radm_trgt1_np_0_fmt                )
                        ,.radm_trgt1_np_0_type                (int_radm_trgt1_np_0_type               )
                        ,.radm_trgt1_np_0_tc                  (int_radm_trgt1_np_0_tc                 )
                        ,.radm_trgt1_np_0_attr                (int_radm_trgt1_np_0_attr               )
                        ,.radm_trgt1_np_0_reqid               (int_radm_trgt1_np_0_reqid              )
                        ,.radm_trgt1_np_0_tag                 (int_radm_trgt1_np_0_tag                )
                        ,.radm_trgt1_np_0_func_num            (int_radm_trgt1_np_0_func_num           )
                        ,.radm_trgt1_np_0_cpl_status          (int_radm_trgt1_np_0_cpl_status         )
                        ,.radm_trgt1_np_0_td                  (int_radm_trgt1_np_0_td                 )
                        ,.radm_trgt1_np_0_poisoned            (int_radm_trgt1_np_0_poisoned           )
                        ,.radm_trgt1_np_0_dw_len              (int_radm_trgt1_np_0_dw_len             )
                        ,.radm_trgt1_np_0_first_be            (int_radm_trgt1_np_0_first_be           )
                        ,.radm_trgt1_np_0_vc_num              (int_radm_trgt1_np_0_vc_num             )

                        ,.radm_trgt1_np_0_addr                (int_radm_trgt1_np_0_addr               )
                        ,.radm_trgt1_np_0_hdr_uppr_bytes      (int_radm_trgt1_np_0_hdr_uppr_bytes     )

                        ,.radm_trgt1_np_0_rom_in_range        (int_radm_trgt1_np_0_rom_in_range       )
                        ,.radm_trgt1_np_0_io_req_in_range     (int_radm_trgt1_np_0_io_req_in_range    )
                        ,.radm_trgt1_np_0_in_membar_range     (int_radm_trgt1_np_0_in_membar_range    )
                        ,.radm_trgt1_np_0_last_be             (int_radm_trgt1_np_0_last_be            )
                        ,.radm_trgt1_np_0_ats                 (int_radm_trgt1_np_0_ats                )
                        ,.radm_trgt1_np_0_nw                  (int_radm_trgt1_np_0_nw                 )
                        ,.radm_trgt1_np_0_cxlsrc              (int_radm_trgt1_np_0_cxlsrc             )
                        ,.radm_trgt1_np_0_th                  (int_radm_trgt1_np_0_th                 )
                        ,.radm_trgt1_np_0_ph                  (int_radm_trgt1_np_0_ph                 )
                        ,.radm_trgt1_np_0_st                  (int_radm_trgt1_np_0_st                 )
                        ,.radm_trgt1_np_0_req_dma             (int_radm_trgt1_np_0_req_dma            )
                        ,.radm_trgt1_np_0_req_dma_channel     (int_radm_trgt1_np_0_req_dma_channel    )
                        ,.radm_trgt1_np_0_req_dma_mem_type    (int_radm_trgt1_np_0_mem_type           )

                        ,.radm_trgt1_np_0_reqtr_sgmt          (int_radm_trgt1_np_0_reqtr_sgmt         )
                        ,.radm_trgt1_np_0_dest_sgmt           (int_radm_trgt1_np_0_dest_sgmt          )
                        ,.radm_trgt1_np_0_pkt_order_no        (int_radm_trgt1_np_0_pkt_order_no       )

                        ,.radm_trgt1_cpl_0_data               (int_radm_trgt1_cpl_0_data              )
                        ,.radm_trgt1_cpl_0_hdr_prot           (int_radm_trgt1_cpl_0_hdr_prot          )
                        ,.radm_trgt1_cpl_0_prfx               (int_radm_trgt1_cpl_0_prfx              )
                        ,.radm_trgt1_cpl_0_dwen               (int_radm_trgt1_cpl_0_dwen              )
                        ,.radm_trgt1_cpl_0_dv                 (int_radm_trgt1_cpl_0_dv                )
                        ,.radm_trgt1_cpl_0_hv                 (int_radm_trgt1_cpl_0_hv                )
                        ,.radm_trgt1_cpl_0_eot                (int_radm_trgt1_cpl_0_eot               )
                        ,.radm_trgt1_cpl_0_dllp_abort         (int_radm_trgt1_cpl_0_dllp_abort        )
                        ,.radm_trgt1_cpl_0_tlp_abort          (int_radm_trgt1_cpl_0_tlp_abort         )
                        ,.radm_trgt1_cpl_0_ecrc_err           (int_radm_trgt1_cpl_0_ecrc_err          )
                        ,.radm_trgt1_cpl_0_fmt                (int_radm_trgt1_cpl_0_fmt               )
                        ,.radm_trgt1_cpl_0_type               (int_radm_trgt1_cpl_0_type              )
                        ,.radm_trgt1_cpl_0_tc                 (int_radm_trgt1_cpl_0_tc                )
                        ,.radm_trgt1_cpl_0_attr               (int_radm_trgt1_cpl_0_attr              )
                        ,.radm_trgt1_cpl_0_reqid              (int_radm_trgt1_cpl_0_reqid             )
                        ,.radm_trgt1_cpl_0_tag                (int_radm_trgt1_cpl_0_tag               )
                        ,.radm_trgt1_cpl_0_func_num           (int_radm_trgt1_cpl_0_func_num          )
                        ,.radm_trgt1_cpl_0_cpl_status         (int_radm_trgt1_cpl_0_cpl_status        )
                        ,.radm_trgt1_cpl_0_td                 (int_radm_trgt1_cpl_0_td                )
                        ,.radm_trgt1_cpl_0_poisoned           (int_radm_trgt1_cpl_0_poisoned          )
                        ,.radm_trgt1_cpl_0_dw_len             (int_radm_trgt1_cpl_0_dw_len            )
                        ,.radm_trgt1_cpl_0_bcm                (int_radm_trgt1_cpl_0_bcm               )
                        ,.radm_trgt1_cpl_0_byte_cnt           (int_radm_trgt1_cpl_0_byte_cnt          )
                        ,.radm_trgt1_cpl_0_cmpltr_id          (int_radm_trgt1_cpl_0_cmpltr_id         )
                        ,.radm_trgt1_cpl_0_last               (int_radm_trgt1_cpl_0_last              )
                        ,.radm_trgt1_cpl_0_vc_num             (int_radm_trgt1_cpl_0_vc_num            )
                        ,.radm_trgt1_cpl_0_addr               (int_radm_trgt1_cpl_0_addr              )

                        ,.radm_trgt1_cpl_0_dest_sgmt          (int_radm_trgt1_cpl_0_dest_sgmt         )
                        ,.radm_trgt1_cpl_0_cpl_sgmt           (int_radm_trgt1_cpl_0_cpl_sgmt          )
                        ,.radm_trgt1_cpl_0_pkt_order_no       (int_radm_trgt1_cpl_0_pkt_order_no      )

                        ,.trgt1_radm_intf_cpl_0_halt          (int_trgt1_radm_intf_cpl_0_halt         )
                        ,.trgt1_radm_intf_p_0_halt            (int_trgt1_radm_intf_p_0_halt           )
                        ,.trgt1_radm_intf_np_0_halt           (int_trgt1_radm_intf_np_0_halt          )

                        ,.ib_rreq_c2a_cdc_ram_doutb      (ib_rreq_c2a_cdc_ram_doutb)
                        ,.ib_wreq_c2a_cdc_ram_doutb      (ib_wreq_c2a_cdc_ram_doutb)
                        ,.slv_aclk_g                     (slv_aclk_g)
                        ,.slv_aresetn                    (slv_aresetn)
                        ,.slv_aclk                       (slv_aclk)
                        ,.en_slv_aclk_g                  (en_slv_aclk_g)
                        ,.slv_rasdp_err_mode             (slv_rasdp_err_mode)
                        ,.slv_awaddr                     (slv_awaddr)
                        ,.slv_awuser                     (slv_awuser)
                        ,.slv_awburst                    (slv_awburst)
                        ,.slv_awcache                    (slv_awcache)
                        ,.slv_awid                       (slv_awid)
                        ,.slv_awlen                      (slv_awlen)
                        ,.slv_awlock                     (slv_awlock)
                        ,.slv_awmisc_info                (slv_awmisc_info)
                        ,.slv_awmisc_info_hdr_34dw       (slv_awmisc_info_hdr_34dw)
                        ,.slv_awmisc_info_nw             (slv_awmisc_info_nw)
                        ,.slv_awmisc_info_ats            (slv_awmisc_info_ats)
                        ,.slv_awmisc_info_tlpprfx        (slv_awmisc_info_tlpprfx)
                        ,.slv_awmisc_info_p_tag          (slv_awmisc_info_p_tag)
                        ,.slv_awmisc_info_tph            (slv_awmisc_info_tph)
                        ,.slv_awmisc_info_atu_bypass     (slv_awmisc_info_atu_bypass)
                        ,.slv_awmisc_info_ido            (slv_awmisc_info_ido)
                        ,.slv_awmisc_info_dst_segment    (slv_awmisc_info_dst_segment)
                        ,.slv_awprot                     (slv_awprot)
                        ,.slv_awsize                     (slv_awsize)
                        ,.slv_awvalid                    (slv_awvalid)
                        ,.slv_awqos                      (slv_awqos)
                        ,.slv_awbar                      (slv_awbar)
                        ,.slv_awdomain                   (slv_awdomain)
                        ,.slv_awsnoop                    (slv_awsnoop)
                        ,.slv_awatop                     (slv_awatop)

                        ,.slv_wdata                      (slv_wdata)
                        ,.slv_wuser                      (slv_wuser)
                        ,.slv_wlast                      (slv_wlast)
                        ,.slv_wstrb                      (slv_wstrb)
                        ,.slv_wvalid                     (slv_wvalid)
                        ,.slv_wmisc_info_ep              (slv_wmisc_info_ep)
                        ,.slv_wmisc_info_silentDrop      (slv_wmisc_info_silentDrop)

                        ,.slv_bready                     (slv_bready)
                        ,.slv_araddr                     (slv_araddr)
                        ,.slv_aruser                     (slv_aruser)
                        ,.slv_arburst                    (slv_arburst)
                        ,.slv_arcache                    (slv_arcache)
                        ,.slv_arid                       (slv_arid)
                        ,.slv_arlen                      (slv_arlen)
                        ,.slv_arlock                     (slv_arlock)
                        ,.slv_armisc_info                (slv_armisc_info)
                        ,.slv_armisc_info_nw             (slv_armisc_info_nw)
                        ,.slv_armisc_info_ats            (slv_armisc_info_ats)
                        ,.slv_armisc_info_tlpprfx        (slv_armisc_info_tlpprfx)
                        ,.slv_armisc_info_tph            (slv_armisc_info_tph)
                        ,.slv_armisc_info_atu_bypass     (slv_armisc_info_atu_bypass)
                        ,.slv_armisc_info_ido            (slv_armisc_info_ido)
                        ,.slv_armisc_info_dst_segment    (slv_armisc_info_dst_segment)
                        ,.slv_arprot                     (slv_arprot)
                        ,.slv_arsize                     (slv_arsize)
                        ,.slv_arvalid                    (slv_arvalid)
                        ,.slv_arqos                      (slv_arqos)
                        ,.slv_arbar                      (slv_arbar)
                        ,.slv_ardomain                   (slv_ardomain)
                        ,.slv_arsnoop                    (slv_arsnoop)

                        ,.slv_rready                     (slv_rready)
                        ,.slv_csysreq                    (slv_csysreq)

                        ,.dma_mcb_rdll_halt              (dma_mcb_rdll_halt)
                        ,.dma_mcb_wrll_halt              (dma_mcb_wrll_halt)
                        // Outputs
                        ,.xali_xaim_pkt                  (int_xali_xaim_pkt)
                        ,.xaim_xali_halt                 (int_xaim_xali_halt)                     

                          ,.dbi_addr                       (dbi_addr)
                          ,.dbi_din                        (dbi_din)
                          ,.dbi_cs                         (dbi_cs)
                          ,.dbi_cs2                        (dbi_cs2)
                          ,.dbi_wr                         (dbi_wr)
                          ,.dbi_bar_num                    (dbi_bar_num)
                          ,.dbi_func_num                   (dbi_func_num)
                          ,.dbi_rom_access                 (dbi_rom_access)
                          ,.dbi_io_access                  (dbi_io_access)
                          ,.dbi_ack                        (dbi_ack)
                          ,.dbi_dout                       (dbi_dout)


                        ,.d_trgt1_wreq_cmplt_dma         (d_trgt1_wreq_cmplt_dma)
                        ,.d_trgt1_wreq_cmplt_dma_channel (d_trgt1_wreq_cmplt_dma_channel)
                        ,.d_trgt1_wreq_err_dma           (d_trgt1_wreq_err_dma)
                        ,.ib_mcpl_sb_ram_addra           (ib_mcpl_sb_ram_addra)
                        ,.ib_mcpl_sb_ram_wea             (ib_mcpl_sb_ram_wea)
                        ,.ib_mcpl_sb_ram_dina            (ib_mcpl_sb_ram_dina)
                        ,.ib_mcpl_sb_ram_addrb           (ib_mcpl_sb_ram_addrb)
                        ,.ib_mcpl_sb_ram_enb             (ib_mcpl_sb_ram_enb)

                        ,.ib_mcpl_a2c_cdc_ram_addra      (ib_mcpl_a2c_cdc_ram_addra)
                        ,.ib_mcpl_a2c_cdc_ram_wea        (ib_mcpl_a2c_cdc_ram_wea)
                        ,.ib_mcpl_a2c_cdc_ram_dina       (ib_mcpl_a2c_cdc_ram_dina)
                        ,.ib_mcpl_a2c_cdc_ram_addrb      (ib_mcpl_a2c_cdc_ram_addrb)
                        ,.ib_mcpl_a2c_cdc_ram_enb        (ib_mcpl_a2c_cdc_ram_enb)

                        ,.ib_scheduler_p_hdr_ram_wea     (ib_scheduler_p_hdr_ram_wea)
                        ,.ib_scheduler_p_hdr_ram_addra   (ib_scheduler_p_hdr_ram_addra)
                        ,.ib_scheduler_p_hdr_ram_dina    (ib_scheduler_p_hdr_ram_dina)
                        ,.ib_scheduler_p_hdr_ram_addrb   (ib_scheduler_p_hdr_ram_addrb)
                        ,.ib_scheduler_p_hdr_ram_enb     (ib_scheduler_p_hdr_ram_enb)
                        ,.ib_scheduler_p_hdr_ram_doutb   (ib_scheduler_p_hdr_ram_doutb)
                        ,.ib_scheduler_p_data_ram_wea    (ib_scheduler_p_data_ram_wea)
                        ,.ib_scheduler_p_data_ram_addra  (ib_scheduler_p_data_ram_addra)
                        ,.ib_scheduler_p_data_ram_dina   (ib_scheduler_p_data_ram_dina)
                        ,.ib_scheduler_p_data_ram_addrb  (ib_scheduler_p_data_ram_addrb)
                        ,.ib_scheduler_p_data_ram_enb    (ib_scheduler_p_data_ram_enb)
                        ,.ib_scheduler_p_data_ram_doutb  (ib_scheduler_p_data_ram_doutb)
                        ,.ib_scheduler_np_hdr_ram_wea    (ib_scheduler_np_hdr_ram_wea)
                        ,.ib_scheduler_np_hdr_ram_addra  (ib_scheduler_np_hdr_ram_addra)
                        ,.ib_scheduler_np_hdr_ram_dina   (ib_scheduler_np_hdr_ram_dina)
                        ,.ib_scheduler_np_hdr_ram_addrb  (ib_scheduler_np_hdr_ram_addrb)
                        ,.ib_scheduler_np_hdr_ram_enb    (ib_scheduler_np_hdr_ram_enb)
                        ,.ib_scheduler_np_hdr_ram_doutb  (ib_scheduler_np_hdr_ram_doutb)
                        ,.ib_scheduler_np_data_ram_wea   (ib_scheduler_np_data_ram_wea)
                        ,.ib_scheduler_np_data_ram_addra (ib_scheduler_np_data_ram_addra)
                        ,.ib_scheduler_np_data_ram_dina  (ib_scheduler_np_data_ram_dina)
                        ,.ib_scheduler_np_data_ram_addrb (ib_scheduler_np_data_ram_addrb)
                        ,.ib_scheduler_np_data_ram_enb   (ib_scheduler_np_data_ram_enb)
                        ,.ib_scheduler_np_data_ram_doutb (ib_scheduler_np_data_ram_doutb)
 

                        ,.mstr_awaddr                    (mstr_awaddr)
                        ,.mstr_awuser                    (mstr_awuser)
                        ,.mstr_awburst                   (mstr_awburst)
                        ,.mstr_awcache                   (mstr_awcache)
                        ,.mstr_awid                      (mstr_awid)
                        ,.mstr_awlen                     (mstr_awlen)
                        ,.mstr_awlock                    (mstr_awlock)
                        ,.mstr_awmisc_info               (mstr_awmisc_info)
                        ,.mstr_awmisc_info_last_dcmp_tlp (mstr_awmisc_info_last_dcmp_tlp)
                        ,.mstr_awmisc_info_hdr_34dw      (mstr_awmisc_info_hdr_34dw)
                        ,.mstr_awmisc_info_nw            (mstr_awmisc_info_nw)
                        ,.mstr_awmisc_info_cxlsrc        (mstr_awmisc_info_cxlsrc)
                        ,.mstr_awmisc_info_ats           (mstr_awmisc_info_ats)
                        ,.mstr_awmisc_info_ep            (mstr_awmisc_info_ep)
                        ,.mstr_awmisc_info_dma           (mstr_awmisc_info_dma)
                        ,.mstr_awmisc_info_tlpprfx       (mstr_awmisc_info_tlpprfx)
                        ,.mstr_awmisc_info_tph           (mstr_awmisc_info_tph)
                        ,.mstr_awmisc_info_ido           (mstr_awmisc_info_ido)
                        ,.mstr_awmisc_info_dst_segment   (mstr_awmisc_info_dst_segment)
                        ,.mstr_awmisc_info_req_segment   (mstr_awmisc_info_req_segment)
                        ,.mstr_awprot                    (mstr_awprot)
                        ,.mstr_awsize                    (mstr_awsize)
                        ,.mstr_awvalid                   (mstr_awvalid)
 
                        ,.mstr_wdata                     (mstr_wdata)
                        ,.mstr_wuser                     (mstr_wuser)
                        ,.mstr_wlast                     (mstr_wlast)
                        ,.mstr_wstrb                     (mstr_wstrb)
                        ,.mstr_wvalid                    (mstr_wvalid)
  
                        ,.mstr_bready                    (mstr_bready)
                        ,.mstr_araddr                    (mstr_araddr)
                        ,.mstr_aruser                    (mstr_aruser)
                        ,.mstr_arburst                   (mstr_arburst)
                        ,.mstr_arcache                   (mstr_arcache)
                        ,.mstr_arid                      (mstr_arid)
                        ,.mstr_arlen                     (mstr_arlen)
                        ,.mstr_arlock                    (mstr_arlock)
                        ,.mstr_armisc_info               (mstr_armisc_info)
                        ,.mstr_armisc_info_last_dcmp_tlp (mstr_armisc_info_last_dcmp_tlp)
                        ,.mstr_armisc_info_nw            (mstr_armisc_info_nw)
                        ,.mstr_armisc_info_cxlsrc        (mstr_armisc_info_cxlsrc)
                        ,.mstr_armisc_info_ats           (mstr_armisc_info_ats)
                        ,.mstr_armisc_info_dma           (mstr_armisc_info_dma)
                        ,.mstr_armisc_info_tlpprfx       (mstr_armisc_info_tlpprfx)
                        ,.mstr_armisc_info_tph           (mstr_armisc_info_tph)
                        ,.mstr_armisc_info_ido           (mstr_armisc_info_ido)
                        ,.mstr_armisc_info_zeroread      (mstr_armisc_info_zeroread)
                        ,.mstr_armisc_info_dst_segment   (mstr_armisc_info_dst_segment)
                        ,.mstr_armisc_info_req_segment   (mstr_armisc_info_req_segment)
                        ,.mstr_arprot                    (mstr_arprot)
                        ,.mstr_arsize                    (mstr_arsize)
                        ,.mstr_arvalid                   (mstr_arvalid)
                        ,.mstr_rready                    (mstr_rready)
  
                        ,.mstr_awqos                     (mstr_awqos)
                        ,.mstr_awbar                     (mstr_awbar)
                        ,.mstr_awdomain                  (mstr_awdomain)
                        ,.mstr_awsnoop                   (mstr_awsnoop)
                        ,.mstr_awatop                    (mstr_awatop)
                        ,.mstr_arqos                     (mstr_arqos)
                        ,.mstr_arbar                     (mstr_arbar)
                        ,.mstr_ardomain                  (mstr_ardomain)
                        ,.mstr_arsnoop                   (mstr_arsnoop)
                        ,.mstr_cactive                   (mstr_cactive)
                        ,.mstr_csysack                   (mstr_csysack)
                        ,.ob_ccmp_data_ram_addra         (ob_ccmp_data_ram_addra)
                        ,.ob_ccmp_data_ram_addrb         (ob_ccmp_data_ram_addrb)
                        ,.ob_ccmp_data_ram_dina          (ob_ccmp_data_ram_dina)
                        ,.ob_ccmp_data_ram_enb           (ob_ccmp_data_ram_enb)
                        ,.ob_ccmp_data_ram_wea           (ob_ccmp_data_ram_wea)
                        ,.ob_ccmp_data_ram_doutb         (ob_ccmp_data_ram_doutb)
                        ,.ib_rreq_c2a_cdc_ram_addra      (ib_rreq_c2a_cdc_ram_addra)
                        ,.ib_rreq_c2a_cdc_ram_addrb      (ib_rreq_c2a_cdc_ram_addrb)
                        ,.ib_rreq_c2a_cdc_ram_wea        (ib_rreq_c2a_cdc_ram_wea  )
                        ,.ib_rreq_c2a_cdc_ram_enb        (ib_rreq_c2a_cdc_ram_enb  )
                        ,.ib_rreq_c2a_cdc_ram_dina       (ib_rreq_c2a_cdc_ram_dina )
                        ,.ib_wreq_c2a_cdc_ram_addra      (ib_wreq_c2a_cdc_ram_addra)
                        ,.ib_wreq_c2a_cdc_ram_addrb      (ib_wreq_c2a_cdc_ram_addrb)
                        ,.ib_wreq_c2a_cdc_ram_wea        (ib_wreq_c2a_cdc_ram_wea  )
                        ,.ib_wreq_c2a_cdc_ram_enb        (ib_wreq_c2a_cdc_ram_enb  )
                        ,.ib_wreq_c2a_cdc_ram_dina       (ib_wreq_c2a_cdc_ram_dina )
                        ,.slv_awready                    (slv_awready)
                        ,.slv_wready                     (slv_wready)
                        ,.slv_bid                        (slv_bid)
                        ,.slv_bmisc_info                 (slv_bmisc_info)
                        ,.slv_bmisc_info_dst_segment     (slv_bmisc_info_dst_segment)
                        ,.slv_bmisc_info_cpl_segment     (slv_bmisc_info_cpl_segment)
                        ,.slv_bresp                      (slv_bresp)
                        ,.slv_bvalid                     (slv_bvalid)

                        ,.slv_arready                    (slv_arready)
                        ,.slv_rdata                      (slv_rdata)
                        ,.slv_ruser                      (slv_ruser)
                        ,.slv_rid                        (slv_rid)
                        ,.slv_rlast                      (slv_rlast)
                        ,.slv_rmisc_info                 (slv_rmisc_info)
                        ,.slv_rmisc_info_ido             (slv_rmisc_info_ido)
                        ,.slv_rmisc_info_dst_segment     (slv_rmisc_info_dst_segment)
                        ,.slv_rmisc_info_cpl_segment     (slv_rmisc_info_cpl_segment)
                        ,.slv_rresp                      (slv_rresp)
                        ,.slv_rvalid                     (slv_rvalid)

                        ,.slv_cactive                    (slv_cactive)
                        ,.slv_csysack                    (slv_csysack)

// -------------------------------------------------------------------------------------
// Power Management Interface (Bridge Power down)
// -------------------------------------------------------------------------------------



                 ,.ob_npdcmp_ram_addra            (ob_npdcmp_ram_addra)
                 ,.ob_npdcmp_ram_wea              (ob_npdcmp_ram_wea)
                 ,.ob_npdcmp_ram_dina             (ob_npdcmp_ram_dina)
                 ,.ob_npdcmp_ram_addrb            (ob_npdcmp_ram_addrb)
                 ,.ob_npdcmp_ram_enb              (ob_npdcmp_ram_enb)
                 ,.ob_npdcmp_ram_doutb            (ob_npdcmp_ram_doutb)

                 ,.ob_pdcmp_hdr_ram_addra         (ob_pdcmp_hdr_ram_addra)
                 ,.ob_pdcmp_hdr_ram_wea           (ob_pdcmp_hdr_ram_wea)
                 ,.ob_pdcmp_hdr_ram_dina          (ob_pdcmp_hdr_ram_dina )
                 ,.ob_pdcmp_hdr_ram_addrb         (ob_pdcmp_hdr_ram_addrb)
                 ,.ob_pdcmp_hdr_ram_enb           (ob_pdcmp_hdr_ram_enb)
                 ,.ob_pdcmp_hdr_ram_doutb         (ob_pdcmp_hdr_ram_doutb)

                 ,.ob_pdcmp_data_ram_addra        (ob_pdcmp_data_ram_addra)
                 ,.ob_pdcmp_data_ram_wea          (ob_pdcmp_data_ram_wea)
                 ,.ob_pdcmp_data_ram_dina         (ob_pdcmp_data_ram_dina )
                 ,.ob_pdcmp_data_ram_addrb        (ob_pdcmp_data_ram_addrb)
                 ,.ob_pdcmp_data_ram_enb          (ob_pdcmp_data_ram_enb)
                 ,.ob_pdcmp_data_ram_doutb        (ob_pdcmp_data_ram_doutb)

                 // Slave Non-Posted Write Set-Aside RAM
                 ,.slv_npw_sab_ram_addra          (slv_npw_sab_ram_addra)
                 ,.slv_npw_sab_ram_wea            (slv_npw_sab_ram_wea)
                 ,.slv_npw_sab_ram_dina           (slv_npw_sab_ram_dina)
                 ,.slv_npw_sab_ram_addrb          (slv_npw_sab_ram_addrb)
                 ,.slv_npw_sab_ram_enb            (slv_npw_sab_ram_enb)
                 ,.slv_npw_sab_ram_doutb          (slv_npw_sab_ram_doutb)
  // Completions Status during DPC
  ,.core_in_dpc_i                   (core_in_dpc_i      )
  ,.cfg_dpc_cpl_cntrl_i             (cfg_dpc_cpl_cntrl_i)
                        );
`endif // !UTB_NATIVE_AXI

//Bridge Subordinate transfer pending  
assign brdg_slv_xfer_pending = s_brdg_slv_xfer_pending || s_brdg_slv_core_client_p;
 
`ifndef UTB_NATIVE_AXI


   

   // Set max NP bridge request number to CX_REMOTE_MAX_TAG
   assign cfg_remote_max_bridge_tag     = `CX_REMOTE_MAX_TAG;
   // Hardwire max remote read request size to 4KBytes
   assign cfg_remote_rd_req_bridge_size = `DC_MAX_PYLD_SIZE_4096_BYTES_ENC;

     DWC_pcie_edmapf_interconnect
      
       u_DWC_pcie_hyper_dma (
           .b_clk                ( b_edma_clk.slave_mp            )
          ,.b_core_cdm           ( b_edma_cdm.slave_mp            )
          ,.b_crgb               ( b_edma_crgb.slave_mp           )
          ,.b_clientPending      ( b_clientPending.master_mp      )
          ,.b_app_trgt_p         ( b_app_trgt_p.master_mp         ) 
          ,.b_app_trgt_np        ( b_app_trgt_np.master_mp        )
          ,.b_app_client_cpl     ( b_app_client_cpl.slave_mp      )
          ,.b_app_client_p       ( b_app_client_p.slave_mp        )
          ,.b_app_client_np      ( b_app_client_np.slave_mp       )
          ,.b_app_trgt_cpl       ( b_app_trgt_cpl.master_mp       )
          ,.b_app_trgt_timeout   ( b_app_trgt_timeout.master_mp   )
          ,.b_core_trgt_p        ( b_core_trgt_p.slave_mp         )
          ,.b_core_trgt_np       ( b_core_trgt_np.slave_mp        )
          ,.b_core_client_cpl    ( b_core_client_cpl.master_mp    )
          ,.b_core_client_p      ( b_core_client_p.master_mp      )
          ,.b_core_client_np     ( b_core_client_np.master_mp     )
          ,.b_core_trgt_cpl      ( b_core_trgt_cpl.slave_mp       )
          ,.b_core_trgt_timeout  ( b_core_trgt_timeout.slave_mp   )
          ,.b_wresp              ( b_edma_wresp.slave_mp          )
          ,.b_status_wr          ( b_edma_status_wr.master_mp     )
          ,.b_status_rd          ( b_edma_status_rd.master_mp     )
          ,.b_rdEng_c2w_lut_ram  ( b_rdEng_c2w_lut_ram.master_mp  )
          ,.b_rdEng_hard_stop    ( b_rdEng_hard_stop.slave_mp     )
          ,.b_rdEng_ll_ram       ( b_rdEng_ll_ram.master_mp       )
          ,.b_rdEng_msi_lut_ram  ( b_rdEng_msi_lut_ram.master_mp  )
          ,.b_rdEng_ovrl_ram     ( b_rdEng_ovrl_ram.master_mp     )
          ,.b_rdEng_stsh_lut_ram ( b_rdEng_stsh_lut_ram.master_mp )          
          ,.b_wrEng_c2w_lut_ram  ( b_wrEng_c2w_lut_ram.master_mp  )
          ,.b_wrEng_hard_stop    ( b_wrEng_hard_stop.slave_mp     )
          ,.b_wrEng_ll_ram       ( b_wrEng_ll_ram.master_mp       )
          ,.b_wrEng_msi_lut_ram  ( b_wrEng_msi_lut_ram.master_mp  )
          ,.b_wrEng_ovrl_ram     ( b_wrEng_ovrl_ram.master_mp     )
          ,.b_wrEng_stsh_lut_ram ( b_wrEng_stsh_lut_ram.master_mp )
          ,.b_rdBuffer_ram0      ( b_rdBuffer_ram0.master_mp      )
          ,.b_ras                ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp ) 
          );     
 

   assign hdma_ras_dp_err_log = b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_log;
   assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = hdma_ras_dp_err_inj;
  
  

  assign xali_xaim_pkt    = d_xali_xaim_pkt;
  assign d_xaim_xali_halt = xaim_xali_halt; 
 
  always_comb begin : b_edma_clk_PROC
    b_edma_clk.w_aux_clk  = aux_clk_g  ;
    b_edma_clk.w_main_clk = core_clk   ;
    b_edma_clk.w_reset_n  = core_rst_n ;
  end
 
  always_comb begin : b_edma_cdm_PROC
    b_edma_cdm.w_cfg_bridge_sb_init_i          = '0                            ;
    b_edma_cdm.w_cfg_max_payload_size          = cfg_max_payload_size          ;
    b_edma_cdm.w_cfg_max_rd_req_size           = cfg_max_rd_req_size           ;
    b_edma_cdm.w_cfg_remote_max_bridge_tag     = cfg_remote_max_bridge_tag     ;
    b_edma_cdm.w_cfg_remote_rd_req_bridge_size = cfg_remote_rd_req_bridge_size ;
    b_edma_cdm.w_cfg_ext_tag_en                = cfg_ext_tag_en                ;
    b_edma_cdm.w_cfg_10b_tag_en                = cfg_10b_tag_en                ;
  end
  
  always_comb begin : b_edma_crgb_PROC
    b_edma_crgb.w_address         = crgbAddr_s'(crgb_address)    ;
    b_edma_crgb.w_rden            = crgb_rden                    ;
    b_edma_crgb.w_source          = crgb_source                  ;
    b_edma_crgb.w_wr_data         = crgb_wr_data                 ;
    b_edma_crgb.w_wren            = crgb_wren                    ;
    b_edma_crgb.w_wr_mask         = '1                           ;
    crgb_ack                      = b_edma_crgb.w_ack            ;
    crgb_rd_data                  = b_edma_crgb.w_rd_data        ;
  end

  always_comb begin : b_edma_hard_stop_PROC
    b_rdEng_hard_stop.w_req     = edma_rd_eng_hard_stop_req     ;
    b_rdEng_hard_stop.w_channel = edma_rd_eng_hard_stop_channel ;
    b_wrEng_hard_stop.w_req     = edma_wr_eng_hard_stop_req     ;    
    b_wrEng_hard_stop.w_channel = edma_wr_eng_hard_stop_channel ;        
    edma_rd_eng_hard_stop_ack   = b_rdEng_hard_stop.w_ack       ;
    edma_wr_eng_hard_stop_ack   = b_wrEng_hard_stop.w_ack       ;
  end

  always_comb begin : b_edma_wresp_PROC
    b_edma_wresp.w_valid   = d_trgt1_wreq_cmplt_dma         ;
    b_edma_wresp.w_channel = d_trgt1_wreq_cmplt_dma_channel ;
    b_edma_wresp.w_error   = d_trgt1_wreq_err_dma           ;
  end
  
  always_comb begin : b_edma_status_PROC
    logic [`CC_NUM_DMA_WR_CHAN-1:0] s_wr_interrupt   ;
    logic [`CC_NUM_DMA_WR_CHAN-1:0] s_wr_xferPending ;
    logic [`CC_NUM_DMA_WR_CHAN-1:0] s_wr_enabled     ;
    logic [`CC_NUM_DMA_RD_CHAN-1:0] s_rd_interrupt   ;
    logic [`CC_NUM_DMA_RD_CHAN-1:0] s_rd_xferPending ;
    logic [`CC_NUM_DMA_RD_CHAN-1:0] s_rd_enabled     ;
    logic                           s_rd_xfer_pending;
    logic                           s_wr_xfer_pending;

    foreach (s_wr_interrupt[i]) begin
      s_wr_interrupt[i]   = |b_edma_status_wr.w_channel[i].interrupt   ;
      s_wr_xferPending[i] =  b_edma_status_wr.w_channel[i].xferPending ;
      s_wr_enabled[i]     =  b_edma_status_wr.w_channel[i].enabled     ;
    end

    foreach (s_rd_interrupt[j]) begin
      s_rd_interrupt[j]   = |b_edma_status_rd.w_channel[j].interrupt   ;
      s_rd_xferPending[j] =  b_edma_status_rd.w_channel[j].xferPending ;
      s_rd_enabled[j]     =  b_edma_status_rd.w_channel[j].enabled     ;
    end

    s_rd_xfer_pending = |s_rd_xferPending || (b_app_trgt_p.w_dv && (b_app_trgt_p.w_header.dma.req == E_DMA_RDCH_DATA));
    s_wr_xfer_pending = |s_wr_xferPending || b_clientPending.w_data || (d_xali_xaim_pkt[0].hdr.tlp_dv && d_xali_xaim_pkt[0].is_dma);
    edma_xfer_pending = s_rd_xfer_pending || s_wr_xfer_pending; 
    edma_int          = { s_rd_interrupt    ,  s_wr_interrupt  };
  end 
  
  always_comb begin : b_app_trgt_p_PROC
    b_app_trgt_p.w_halt                     = int_trgt1_radm_intf_p_0_halt                             ;
    int_radm_trgt1_p_0_addr                 = b_app_trgt_p.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0];
    int_radm_trgt1_p_0_attr                 = b_app_trgt_p.w_header.common1.attr                       ;
    int_radm_trgt1_p_0_data                 = b_app_trgt_p.w_data                                      ;
    int_radm_trgt1_p_0_dllp_abort           = b_app_trgt_p.w_header.common4.dllp_abort                 ;
    int_radm_trgt1_p_0_dv                   = b_app_trgt_p.w_dv                                        ;
    int_radm_trgt1_p_0_dw_len               = b_app_trgt_p.w_header.common2.dw_len                     ;
    int_radm_trgt1_p_0_dwen                 = b_app_trgt_p.w_header.common4.dwen                       ;
    int_radm_trgt1_p_0_ecrc_err             = b_app_trgt_p.w_header.common4.ecrc_err                   ;
    int_radm_trgt1_p_0_eot                  = b_app_trgt_p.w_eot                                       ;
    int_radm_trgt1_p_0_first_be             = b_app_trgt_p.w_header.common2.first_be                   ;
    int_radm_trgt1_p_0_fmt                  = b_app_trgt_p.w_header.common2.fmt                        ;
    int_radm_trgt1_p_0_func_num             = b_app_trgt_p.w_header.common1.pfunc_num                  ;
    int_radm_trgt1_p_0_hv                   = b_app_trgt_p.w_hv                                        ;
    int_radm_trgt1_p_0_in_membar_range      = b_app_trgt_p.w_header.common4.in_membar_range            ;
    int_radm_trgt1_p_0_io_req_in_range      = b_app_trgt_p.w_header.common4.io_req_in_range            ;
    int_radm_trgt1_p_0_last_be              = b_app_trgt_p.w_header.common2.last_be                    ;
    int_radm_trgt1_p_0_poisoned             = b_app_trgt_p.w_eot ? b_app_trgt_p.w_header.common2.poisoned : '0;
    int_radm_trgt1_p_0_reqid                = b_app_trgt_p.w_header.common4.req_id                     ;
    int_radm_trgt1_p_0_rom_in_range         = b_app_trgt_p.w_header.common4.rom_in_range               ;
    int_radm_trgt1_p_0_tag                  = b_app_trgt_p.w_header.common1.pcieTag                    ;
    int_radm_trgt1_p_0_tc                   = b_app_trgt_p.w_header.common1.tc                         ;
    int_radm_trgt1_p_0_td                   = b_app_trgt_p.w_header.common2.td                         ;
    int_radm_trgt1_p_0_tlp_abort            = b_app_trgt_p.w_header.common4.tlp_abort                  ;
    int_radm_trgt1_p_0_type                 = b_app_trgt_p.w_header.common2.typ                        ;
    int_radm_trgt1_p_0_hdr_uppr_bytes       = b_app_trgt_p.w_header.radmPort.uppr_bytes[`FLT_Q_ADDR_WIDTH-1:0] ;
    int_radm_trgt1_p_0_cpl_status           = b_app_trgt_p.w_header.common2.cpl_status                 ;
    int_radm_trgt1_p_0_req_dma              = b_app_trgt_p.w_header.dma.req                            ;
    int_radm_trgt1_p_0_req_dma_channel      = b_app_trgt_p.w_header.dma.channel                        ;
    int_radm_trgt1_p_0_mem_type             = b_app_trgt_p.w_header.radmPort.mem_type                  ;
    int_radm_trgt1_p_0_ats                  = b_app_trgt_p.w_header.common2.ats                        ;
    int_radm_trgt1_p_0_nw                   = b_app_trgt_p.w_header.common3.nw                         ;
    int_radm_trgt1_p_0_cxlsrc               = b_app_trgt_p.w_header.common3.cxlsrc                     ;
    int_radm_trgt1_p_0_prfx                 = b_app_trgt_p.w_header.common2.prfx                       ;
    int_radm_trgt1_p_0_ph                   = b_app_trgt_p.w_header.common2.tph_ph                     ;
    int_radm_trgt1_p_0_st                   = b_app_trgt_p.w_header.common2.tph_st                     ;
    int_radm_trgt1_p_0_th                   = b_app_trgt_p.w_header.common2.tph_th                     ;
    int_radm_trgt1_p_0_vc_num               = `CX_NVC_LOG2'(b_app_trgt_p.w_header.radmPort.vc_num)     ;
    int_radm_trgt1_p_0_hdr_uppr_bytes_valid = b_app_trgt_p.w_header.radmPort.uppr_bytes_valid          ;
    int_radm_trgt1_p_0_hdr_prot             = b_app_trgt_p.w_headerProt                                ;
    int_radm_trgt1_p_0_reqtr_sgmt           = b_app_trgt_p.w_header.flit_mode.req_sgmt                 ;
    int_radm_trgt1_p_0_dest_sgmt            = b_app_trgt_p.w_header.flit_mode.dst_sgmt                 ;
    int_radm_trgt1_p_0_pkt_order_no         = b_app_trgt_p.w_header.order_seq_no.inbound               ;
  end
  
  always_comb begin : b_app_trgt_np_PROC
    b_app_trgt_np.w_halt                     = int_trgt1_radm_intf_np_0_halt                             ;
    int_radm_trgt1_np_0_addr                 = b_app_trgt_np.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0];
    int_radm_trgt1_np_0_attr                 = b_app_trgt_np.w_header.common1.attr                       ;
    int_radm_trgt1_np_0_cpl_status           = b_app_trgt_np.w_header.common2.cpl_status                 ;
    int_radm_trgt1_np_0_data                 = b_app_trgt_np.w_data                                      ;
    int_radm_trgt1_np_0_dllp_abort           = b_app_trgt_np.w_header.common4.dllp_abort                 ;
    int_radm_trgt1_np_0_dv                   = b_app_trgt_np.w_dv                                        ;
    int_radm_trgt1_np_0_dw_len               = b_app_trgt_np.w_header.common2.dw_len                     ;
    int_radm_trgt1_np_0_dwen                 = b_app_trgt_np.w_header.common4.dwen                       ;
    int_radm_trgt1_np_0_ecrc_err             = b_app_trgt_np.w_header.common4.ecrc_err                   ;
    int_radm_trgt1_np_0_eot                  = b_app_trgt_np.w_eot                                       ;
    int_radm_trgt1_np_0_first_be             = b_app_trgt_np.w_header.common2.first_be                   ;
    int_radm_trgt1_np_0_fmt                  = b_app_trgt_np.w_header.common2.fmt                        ;
    int_radm_trgt1_np_0_func_num             = b_app_trgt_np.w_header.common1.pfunc_num                  ;
    int_radm_trgt1_np_0_hv                   = b_app_trgt_np.w_hv                                        ;
    int_radm_trgt1_np_0_in_membar_range      = b_app_trgt_np.w_header.common4.in_membar_range            ;
    int_radm_trgt1_np_0_io_req_in_range      = b_app_trgt_np.w_header.common4.io_req_in_range            ;
    int_radm_trgt1_np_0_last_be              = b_app_trgt_np.w_header.common2.last_be                    ;
    int_radm_trgt1_np_0_lookup_id            = `CX_REMOTE_LOOKUPID_WD'(b_app_trgt_np.w_header.common3.lookupid) ;
    int_radm_trgt1_np_0_poisoned             = b_app_trgt_np.w_eot ? b_app_trgt_np.w_header.common2.poisoned : '0;
    int_radm_trgt1_np_0_reqid                = b_app_trgt_np.w_header.common4.req_id                     ;
    int_radm_trgt1_np_0_rom_in_range         = b_app_trgt_np.w_header.common4.rom_in_range               ;
    int_radm_trgt1_np_0_tag                  = b_app_trgt_np.w_header.common1.pcieTag                    ;
    int_radm_trgt1_np_0_tc                   = b_app_trgt_np.w_header.common1.tc                         ;
    int_radm_trgt1_np_0_td                   = b_app_trgt_np.w_header.common2.td                         ;
    int_radm_trgt1_np_0_tlp_abort            = b_app_trgt_np.w_header.common4.tlp_abort                  ;
    int_radm_trgt1_np_0_type                 = b_app_trgt_np.w_header.common2.typ                        ;
    int_radm_trgt1_np_0_req_dma              = b_app_trgt_np.w_header.dma.req                            ;
    int_radm_trgt1_np_0_req_dma_channel      = b_app_trgt_np.w_header.dma.channel                        ;
    int_radm_trgt1_np_0_mem_type             = b_app_trgt_np.w_header.radmPort.mem_type                  ;
    int_radm_trgt1_np_0_hdr_uppr_bytes       = b_app_trgt_np.w_header.radmPort.uppr_bytes[`FLT_Q_ADDR_WIDTH-1:0] ;
    int_radm_trgt1_np_0_ats                  = b_app_trgt_np.w_header.common2.ats                        ;
    int_radm_trgt1_np_0_nw                   = b_app_trgt_np.w_header.common3.nw                         ;
    int_radm_trgt1_np_0_cxlsrc               = b_app_trgt_np.w_header.common3.cxlsrc                     ;
    int_radm_trgt1_np_0_prfx                 = b_app_trgt_np.w_header.common2.prfx                       ;
    int_radm_trgt1_np_0_ph                   = b_app_trgt_np.w_header.common2.tph_ph                     ;
    int_radm_trgt1_np_0_st                   = b_app_trgt_np.w_header.common2.tph_st                     ;
    int_radm_trgt1_np_0_th                   = b_app_trgt_np.w_header.common2.tph_th                     ;
    int_radm_trgt1_np_0_vc_num               = `CX_NVC_LOG2'(b_app_trgt_np.w_header.radmPort.vc_num)     ;
    int_radm_trgt1_np_0_hdr_prot             = b_app_trgt_np.w_headerProt                                ;
    int_radm_trgt1_np_0_reqtr_sgmt           = b_app_trgt_np.w_header.flit_mode.req_sgmt                 ;
    int_radm_trgt1_np_0_dest_sgmt            = b_app_trgt_np.w_header.flit_mode.dst_sgmt                 ;
    int_radm_trgt1_np_0_pkt_order_no         = b_app_trgt_np.w_header.order_seq_no.inbound               ;
  end
  
  always_comb begin : b_app_trgt_cpl_PROC
    b_app_trgt_cpl.w_halt                     = int_trgt1_radm_intf_cpl_0_halt                             ;
    int_radm_trgt1_cpl_0_addr                 = b_app_trgt_cpl.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0]    ;
    int_radm_trgt1_cpl_0_attr                 = b_app_trgt_cpl.w_header.common1.attr                       ;
    int_radm_trgt1_cpl_0_cpl_status           = b_app_trgt_cpl.w_header.common2.cpl_status                 ;
    int_radm_trgt1_cpl_0_data                 = b_app_trgt_cpl.w_data                                      ;
    int_radm_trgt1_cpl_0_dllp_abort           = b_app_trgt_cpl.w_header.common4.dllp_abort                 ;
    int_radm_trgt1_cpl_0_dv                   = b_app_trgt_cpl.w_dv                                        ;
    int_radm_trgt1_cpl_0_dw_len               = b_app_trgt_cpl.w_header.common2.dw_len                     ;
    int_radm_trgt1_cpl_0_dwen                 = b_app_trgt_cpl.w_header.common4.dwen                       ;
    int_radm_trgt1_cpl_0_ecrc_err             = b_app_trgt_cpl.w_header.common4.ecrc_err                   ;
    int_radm_trgt1_cpl_0_eot                  = b_app_trgt_cpl.w_eot                                       ;
    int_radm_trgt1_cpl_0_fmt                  = b_app_trgt_cpl.w_header.common2.fmt                        ;
    int_radm_trgt1_cpl_0_func_num             = b_app_trgt_cpl.w_header.common1.pfunc_num                  ;
    int_radm_trgt1_cpl_0_hv                   = b_app_trgt_cpl.w_hv                                        ;
    int_radm_trgt1_cpl_0_poisoned             = b_app_trgt_cpl.w_eot ? b_app_trgt_cpl.w_header.common2.poisoned : '0;
    int_radm_trgt1_cpl_0_reqid                = b_app_trgt_cpl.w_header.common4.req_id                     ;
    int_radm_trgt1_cpl_0_tag                  = b_app_trgt_cpl.w_header.common1.pcieTag                    ;
    int_radm_trgt1_cpl_0_tc                   = b_app_trgt_cpl.w_header.common1.tc                         ;
    int_radm_trgt1_cpl_0_td                   = b_app_trgt_cpl.w_header.common2.td                         ;
    int_radm_trgt1_cpl_0_tlp_abort            = b_app_trgt_cpl.w_header.common4.tlp_abort                  ;
    int_radm_trgt1_cpl_0_type                 = b_app_trgt_cpl.w_header.common2.typ                        ;
    int_radm_trgt1_cpl_0_req_dma              = b_app_trgt_cpl.w_header.dma.req                            ;
    int_radm_trgt1_cpl_0_req_dma_channel      = b_app_trgt_cpl.w_header.dma.channel                        ;
    int_radm_trgt1_cpl_0_prfx                 = b_app_trgt_cpl.w_header.common2.prfx                       ;
    int_radm_trgt1_cpl_0_bcm                  = b_app_trgt_cpl.w_header.common2.cpl_bcm                    ;
    int_radm_trgt1_cpl_0_byte_cnt             = b_app_trgt_cpl.w_header.common2.byte_cnt                   ;
    int_radm_trgt1_cpl_0_cmpltr_id            = b_app_trgt_cpl.w_header.common2.cmpltr_id                  ;
    int_radm_trgt1_cpl_0_vc_num               = `CX_NVC_LOG2'(b_app_trgt_cpl.w_header.radmPort.vc_num)     ;
    int_radm_trgt1_cpl_0_hdr_prot             = b_app_trgt_cpl.w_headerProt                                ;
    int_radm_trgt1_cpl_0_dest_sgmt            = b_app_trgt_cpl.w_header.flit_mode.dst_sgmt                 ;
    int_radm_trgt1_cpl_0_cpl_sgmt             = b_app_trgt_cpl.w_header.flit_mode.cpl_sgmt                 ;
    int_radm_trgt1_cpl_0_pkt_order_no         = b_app_trgt_cpl.w_header.order_seq_no.inbound               ; 
    int_radm_trgt1_cpl_0_last                 = b_app_trgt_cpl.w_header.common4.cpl_last                   ;
  end  
  
  xradm_s r_trgt_p_header;
  
  always_ff @(posedge core_clk, negedge core_rst_n) begin : s_r_trgt_p_header_PROC
    if (!core_rst_n) begin
      r_trgt_p_header <= #`TP '0;
    end else begin
      if (radm_trgt1_p_0_eot) begin
        r_trgt_p_header <= #`TP '0;
      end else if (radm_trgt1_p_0_hv) begin
        r_trgt_p_header <= #`TP b_core_trgt_p.w_header;
      end
    end
  end : s_r_trgt_p_header_PROC
  
  always_comb begin : b_core_trgt_p_PROC
    trgt1_radm_intf_p_0_halt   = b_core_trgt_p.w_halt ;
    b_core_trgt_p.w_hv         = radm_trgt1_p_0_hv    ;
    b_core_trgt_p.w_dv         = radm_trgt1_p_0_dv    ;
    b_core_trgt_p.w_eot        = radm_trgt1_p_0_eot   ;
    b_core_trgt_p.w_data       = radm_trgt1_p_0_dv ? radm_trgt1_p_0_data           : '0;
    b_core_trgt_p.w_headerProt = radm_trgt1_p_0_hv ? radm_trgt1_p_0_hdr_prot       : '0;
    b_core_trgt_p.w_header = '{
       default: '0
      ,common1: '{
         default: '0
        ,attr            : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_attr                 : r_trgt_p_header.common1.attr
        ,pfunc_num       : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_func_num             : r_trgt_p_header.common1.pfunc_num
        ,pcieTag         : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_tag                  : r_trgt_p_header.common1.pcieTag
        ,tc              : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_tc                   : r_trgt_p_header.common1.tc
      }
      ,common2: '{
         default: '0
        ,addr            : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_addr                 : r_trgt_p_header.common2.addr
        ,cpl_status      : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_cpl_status           : r_trgt_p_header.common2.cpl_status
        ,dw_len          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_dw_len               : r_trgt_p_header.common2.dw_len
        ,first_be        : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_first_be             : r_trgt_p_header.common2.first_be
        ,fmt             : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_fmt                  : r_trgt_p_header.common2.fmt
        ,last_be         : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_last_be              : r_trgt_p_header.common2.last_be
        ,poisoned        : radm_trgt1_p_0_eot ? radm_trgt1_p_0_poisoned             : '0
        ,td              : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_td                   : r_trgt_p_header.common2.td
        ,typ             : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_type                 : r_trgt_p_header.common2.typ
        ,ats             : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_ats                  : r_trgt_p_header.common2.ats
        ,prfx            : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_prfx                 : r_trgt_p_header.common2.prfx
        ,tph_ph          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_ph                   : r_trgt_p_header.common2.tph_ph
        ,tph_st          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_st                   : r_trgt_p_header.common2.tph_st
        ,tph_th          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_th                   : r_trgt_p_header.common2.tph_th
  //`ifdef RADM_SEG_BUF
        //,cpl_bcm         : radm_trgt1_p_0_bcm
        //,byte_cnt        : radm_trgt1_p_0_byte_cnt
        //,cmpltr_id       : radm_trgt1_p_0_cmpltr_id
  //`endif //RADM_SEG_BUF
      }
      ,common3: '{
         default: '0
        //,lookupid        : radm_trgt1_p_0_lookup_id[`CX_REMOTE_MAX_TAGS_WD-1:0]
        ,nw              : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_nw                   : r_trgt_p_header.common3.nw
        ,cxlsrc          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_cxlsrc               : r_trgt_p_header.common3.cxlsrc
      }
      ,common4: '{
         default: '0
        ,dllp_abort      : radm_trgt1_p_0_eot ? radm_trgt1_p_0_dllp_abort           : '0
        ,dwen            : radm_trgt1_p_0_dv  ? radm_trgt1_p_0_eot ? radm_trgt1_p_0_dwen : '1 : '0
        ,ecrc_err        : radm_trgt1_p_0_eot ? radm_trgt1_p_0_ecrc_err             : '0
        ,in_membar_range : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_in_membar_range      : r_trgt_p_header.common4.in_membar_range
        ,io_req_in_range : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_io_req_in_range      : r_trgt_p_header.common4.io_req_in_range
        ,req_id          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_reqid                : r_trgt_p_header.common4.req_id
        ,rom_in_range    : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_rom_in_range         : r_trgt_p_header.common4.rom_in_range
        ,tlp_abort       : radm_trgt1_p_0_eot ? radm_trgt1_p_0_tlp_abort            : '0
        //,cpl_last        : radm_trgt1_p_0_cpl_last
      }
      ,radmPort: '{
         default: '0
        ,uppr_bytes      : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_hdr_uppr_bytes       : r_trgt_p_header.radmPort.uppr_bytes
        ,uppr_bytes_valid: radm_trgt1_p_0_hv  ? radm_trgt1_p_0_hdr_uppr_bytes_valid : r_trgt_p_header.radmPort.uppr_bytes_valid
        ,mem_type        : radm_trgt1_p_0_hv  ? ( radm_trgt1_p_0_addr[`FLT_Q_ADDR_WIDTH-1:0] >= {cfg_memtype_boundary,2'b00} ? ~cfg_memtype_value : cfg_memtype_value ) : r_trgt_p_header.radmPort.mem_type
        ,vc_num          : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_vc_num               : r_trgt_p_header.radmPort.vc_num
      }
      ,dma: '{
         default: '0
        ,req             : E_DMA_BYPASS
        ,channel         : '0
      }
      ,order_seq_no: '{
         default: '0
        ,inbound         : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_pkt_order_no         : r_trgt_p_header.order_seq_no.inbound
      }
      ,flit_mode: '{
         default: '0
        ,dst_sgmt        : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_dest_sgmt            : r_trgt_p_header.flit_mode.dst_sgmt
        ,req_sgmt        : radm_trgt1_p_0_hv  ? radm_trgt1_p_0_reqtr_sgmt           : r_trgt_p_header.flit_mode.req_sgmt
      }
    };
  end

  xradm_s r_trgt_np_header;
  
  always_ff @(posedge core_clk, negedge core_rst_n) begin : s_r_trgt_np_header_PROC
    if (!core_rst_n) begin
      r_trgt_np_header <= #`TP '0;
    end else begin
      if (radm_trgt1_np_0_eot) begin
        r_trgt_np_header <= #`TP '0;
      end else if (radm_trgt1_np_0_hv) begin
        r_trgt_np_header <= #`TP b_core_trgt_np.w_header;
      end
    end
  end : s_r_trgt_np_header_PROC
  
  always_comb begin : b_core_trgt_np_PROC
    trgt1_radm_intf_np_0_halt   = b_core_trgt_np.w_halt ;
    b_core_trgt_np.w_hv         = radm_trgt1_np_0_hv    ;
    b_core_trgt_np.w_dv         = radm_trgt1_np_0_dv    ;
    b_core_trgt_np.w_eot        = radm_trgt1_np_0_eot   ;
    b_core_trgt_np.w_data       = radm_trgt1_np_0_dv ? radm_trgt1_np_0_data                 : '0;
    b_core_trgt_np.w_headerProt = radm_trgt1_np_0_hv ? radm_trgt1_np_0_hdr_prot             : '0;
    b_core_trgt_np.w_header = '{
       default: '0
      ,common1: '{
         default: '0
        ,attr            : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_attr                       : r_trgt_np_header.common1.attr
        ,pfunc_num       : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_func_num                   : r_trgt_np_header.common1.pfunc_num
        ,pcieTag         : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_tag                        : r_trgt_np_header.common1.pcieTag
        ,tc              : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_tc                         : r_trgt_np_header.common1.tc
      }
      ,common2: '{
         default: '0
        ,addr            : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_addr                       : r_trgt_np_header.common2.addr
        ,cpl_status      : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_cpl_status                 : r_trgt_np_header.common2.cpl_status
        ,dw_len          : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_dw_len                     : r_trgt_np_header.common2.dw_len
        ,first_be        : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_first_be                   : r_trgt_np_header.common2.first_be
        ,fmt             : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_fmt                        : r_trgt_np_header.common2.fmt
        ,last_be         : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_last_be                    : r_trgt_np_header.common2.last_be
        ,poisoned        : radm_trgt1_np_0_eot ? radm_trgt1_np_0_poisoned                   : '0
        ,td              : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_td                         : r_trgt_np_header.common2.td
        ,typ             : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_type                       : r_trgt_np_header.common2.typ
        ,ats             : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_ats                        : r_trgt_np_header.common2.ats
        ,prfx            : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_prfx                       : r_trgt_np_header.common2.prfx
        ,tph_ph          : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_ph                         : r_trgt_np_header.common2.tph_ph
        ,tph_st          : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_st                         : r_trgt_np_header.common2.tph_st
        ,tph_th          : radm_trgt1_np_0_hv  ?  radm_trgt1_np_0_th                        : r_trgt_np_header.common2.tph_th
  //`ifdef RADM_SEG_BUF
        //,cpl_bcm         : radm_trgt1_np_0_bcm
        //,byte_cnt        : radm_trgt1_np_0_byte_cnt
        //,cmpltr_id       : radm_trgt1_np_0_cmpltr_id
  //`endif //RADM_SEG_BUF
      }
      ,common3: '{
         default: '0
        ,lookupid        : radm_trgt1_np_0_hv  ? trgt_lookup_id                             : r_trgt_np_header.common3.lookupid
        ,nw              : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_nw                         : r_trgt_np_header.common3.nw
        ,cxlsrc          : radm_trgt1_np_0_hv  ? radm_trgt1_np_0_cxlsrc                     : r_trgt_np_header.common3.cxlsrc
      }
      ,common4: '{
         default: '0
        ,dllp_abort      : radm_trgt1_np_0_eot ? radm_trgt1_np_0_dllp_abort                 : r_trgt_np_header.common4.dllp_abort
        ,dwen            : radm_trgt1_np_0_dv  ? radm_trgt1_np_0_eot ? radm_trgt1_np_0_dwen : '1 :'0
        ,ecrc_err        : radm_trgt1_np_0_eot ? radm_trgt1_np_0_ecrc_err                   : '0
        ,in_membar_range : radm_trgt1_np_0_hv  ?  radm_trgt1_np_0_in_membar_range           : r_trgt_np_header.common4.in_membar_range
        ,io_req_in_range : radm_trgt1_np_0_hv  ?  radm_trgt1_np_0_io_req_in_range           : r_trgt_np_header.common4.io_req_in_range
        ,req_id          : radm_trgt1_np_0_hv  ?  radm_trgt1_np_0_reqid                     : r_trgt_np_header.common4.req_id
        ,rom_in_range    : radm_trgt1_np_0_hv  ?  radm_trgt1_np_0_rom_in_range              : r_trgt_np_header.common4.rom_in_range
        ,tlp_abort       : radm_trgt1_np_0_eot ? radm_trgt1_np_0_tlp_abort                  : '0
  //`ifdef RADM_SEG_BUF
        //,cpl_last        : radm_trgt1_np_0_cpl_last
  //`endif //RADM_SEG_BUF
      }
      ,radmPort: '{
         default: '0
        ,uppr_bytes      : radm_trgt1_np_0_hv ?  radm_trgt1_np_0_hdr_uppr_bytes             : r_trgt_np_header.radmPort.uppr_bytes
        //,uppr_bytes_valid: radm_trgt1_np_0_hdr_uppr_bytes_valid
        ,mem_type        : radm_trgt1_np_0_hv ? ( radm_trgt1_np_0_addr[`FLT_Q_ADDR_WIDTH-1:0] >= {cfg_memtype_boundary,2'b00} ? ~cfg_memtype_value : cfg_memtype_value ) : r_trgt_np_header.radmPort.mem_type
        ,vc_num          : radm_trgt1_np_0_hv ?  radm_trgt1_np_0_vc_num                     : r_trgt_np_header.radmPort.vc_num
      }
      ,dma: '{
         default: '0
        ,req             : E_DMA_BYPASS
        ,channel         : '0
      }
      ,order_seq_no: '{
         default: '0
        ,inbound         : radm_trgt1_np_0_hv ?  radm_trgt1_np_0_pkt_order_no               : r_trgt_np_header.order_seq_no.inbound
      }
      ,flit_mode: '{
         default: '0
        ,dst_sgmt        : radm_trgt1_np_0_hv ?  radm_trgt1_np_0_dest_sgmt                  : r_trgt_np_header.flit_mode.dst_sgmt
        ,req_sgmt        : radm_trgt1_np_0_hv ?  radm_trgt1_np_0_reqtr_sgmt                 : r_trgt_np_header.flit_mode.req_sgmt
      }
    };
  end  
  
  xradm_s r_trgt_cpl_header;
  
  always_ff @(posedge core_clk, negedge core_rst_n) begin : s_r_trgt_cpl_header_PROC
    if (!core_rst_n) begin
      r_trgt_cpl_header <= #`TP '0;
    end else begin
      if (radm_trgt1_cpl_0_eot) begin
        r_trgt_cpl_header <= #`TP '0;
      end else if (radm_trgt1_cpl_0_hv) begin
        r_trgt_cpl_header <= #`TP b_core_trgt_cpl.w_header;
      end
    end
  end : s_r_trgt_cpl_header_PROC
  
  always_comb begin : b_core_trgt_cpl_PROC
    trgt1_radm_intf_cpl_0_halt   = b_core_trgt_cpl.w_halt ;
    b_core_trgt_cpl.w_hv         = radm_trgt1_cpl_0_hv    ;
    b_core_trgt_cpl.w_dv         = radm_trgt1_cpl_0_dv    ;
    b_core_trgt_cpl.w_eot        = radm_trgt1_cpl_0_eot   ;
    b_core_trgt_cpl.w_data       = radm_trgt1_cpl_0_dv ? radm_trgt1_cpl_0_data        : '0;
    b_core_trgt_cpl.w_headerProt = radm_trgt1_cpl_0_hv ? radm_trgt1_cpl_0_hdr_prot    : '0;
    b_core_trgt_cpl.w_header = '{
       default: '0
      ,common1: '{
         default: '0
        ,attr            : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_attr               : r_trgt_cpl_header.common1.attr
        ,pfunc_num       : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_func_num           : r_trgt_cpl_header.common1.pfunc_num
        ,pcieTag         : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_tag                : r_trgt_cpl_header.common1.pcieTag
        ,tc              : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_tc                 : r_trgt_cpl_header.common1.tc
      }
      ,common2: '{
         default: '0
        ,addr            : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_addr               : r_trgt_cpl_header.common2.addr
        ,cpl_status      : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_cpl_status         : r_trgt_cpl_header.common2.cpl_status
        ,dw_len          : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_dw_len             : r_trgt_cpl_header.common2.dw_len
//         ,first_be        : radm_trgt1_cpl_0_first_be
        ,fmt             : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_fmt                : r_trgt_cpl_header.common2.fmt
//         ,last_be         : radm_trgt1_cpl_0_last_be
        ,poisoned        : radm_trgt1_cpl_0_eot ? radm_trgt1_cpl_0_poisoned           : '0
        ,td              : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_td                 : r_trgt_cpl_header.common2.td
        ,typ             : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_type               : r_trgt_cpl_header.common2.typ
//        ,ats             : radm_trgt1_cpl_0_ats
        ,prfx            : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_prfx               : r_trgt_cpl_header.common2.prfx
//   `ifdef CX_TPH_ENABLE
//         ,tph_ph          : radm_trgt1_cpl_0_ph
//         ,tph_st          : radm_trgt1_cpl_0_st
//         ,tph_th          : radm_trgt1_cpl_0_th
//   `endif //CX_TPH_ENABLE
        ,cpl_bcm         : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_bcm                : r_trgt_cpl_header.common2.cpl_bcm
        ,byte_cnt        : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_byte_cnt           : r_trgt_cpl_header.common2.byte_cnt
        ,cmpltr_id       : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_cmpltr_id          : r_trgt_cpl_header.common2.cmpltr_id
      }
      ,common3: '{
         default: '0
        //,lookupid        : radm_trgt1_cpl_0_lookup_id[`CX_REMOTE_MAX_TAGS_WD-1:0]
//   `ifdef ATS_RX_ENABLE
//         ,nw              : radm_trgt1_cpl_0_nw
//   `endif //ATS_RX_ENABLE
      }
      ,common4: '{
         default: '0
        ,dllp_abort      : radm_trgt1_cpl_0_eot ? radm_trgt1_cpl_0_dllp_abort         : '0
        ,dwen            : radm_trgt1_cpl_0_dv  ? radm_trgt1_cpl_0_eot ? radm_trgt1_cpl_0_dwen : '1 : '0
        ,ecrc_err        : radm_trgt1_cpl_0_eot ? radm_trgt1_cpl_0_ecrc_err           : '0
//         ,in_membar_range : radm_trgt1_cpl_0_in_membar_range
//         ,io_req_in_range : radm_trgt1_cpl_0_io_req_in_range
        ,req_id          : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_reqid              : r_trgt_cpl_header.common4.req_id
//         ,rom_in_range    : radm_trgt1_cpl_0_rom_in_range
        ,tlp_abort       : radm_trgt1_cpl_0_eot ? radm_trgt1_cpl_0_tlp_abort          : '0
        ,cpl_last        : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_last               : r_trgt_cpl_header.common4.cpl_last
      }
      ,radmPort: '{
         default: '0
//         ,uppr_bytes      : radm_trgt1_cpl_0_hdr_uppr_bytes
        //,uppr_bytes_valid: radm_trgt1_cpl_0_hdr_uppr_bytes_valid
        //,mem_type        : radm_trgt1_cpl_0_mem_type
        ,vc_num          : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_vc_num             : r_trgt_cpl_header.radmPort.vc_num
      }
      ,dma: '{
         default: '0
        ,req             : radm_trgt1_cpl_0_hv  ? (radm_trgt1_cpl_0_type ==? 5'b101X) ? 
                                                     E_DMA_BYPASS_CPL : E_DMA_BYPASS  : r_trgt_cpl_header.dma.req
        ,channel         : '0
      }
      ,order_seq_no: '{
         default: '0
        ,inbound         : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_pkt_order_no       : r_trgt_cpl_header.order_seq_no.inbound
      }
      ,flit_mode: '{
         default: '0
        ,dst_sgmt        : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_dest_sgmt          : r_trgt_cpl_header.flit_mode.dst_sgmt
        ,cpl_sgmt        : radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_cpl_sgmt           : r_trgt_cpl_header.flit_mode.cpl_sgmt
      }
    };
  end
  
  always_comb begin : b_app_trgt_timeout_PROC
    int_radm_cpl_timeout          = b_app_trgt_timeout.w_hv                          ;
    int_radm_timeout_cpl_attr     = b_app_trgt_timeout.w_header.common1.attr         ;
    //int_radm_timeout_cpl_len      = b_app_trgt_timeout.w_header.extra.len            ;
    int_radm_timeout_cpl_tag      = b_app_trgt_timeout.w_header.common1.pcieTag      ;
    int_radm_timeout_cpl_tc       = b_app_trgt_timeout.w_header.common1.tc           ;
    int_radm_timeout_func_num     = b_app_trgt_timeout.w_header.common1.pfunc_num    ;
  end
  
  logic [2:0] r_xali_xaim_pkt_order_seqnum [`N_XALI_IF-1:0];
  always@(posedge core_clk or negedge core_rst_n) begin: SEQ_CLIENT_ORDR_SEQNUM_PROC
    integer i,j;

    if(!core_rst_n)begin
      for (i=0;i<`N_XALI_IF;i=i+1)
        r_xali_xaim_pkt_order_seqnum[i] <= #`TP '0;
    end else begin
      for (j=0;j<`N_XALI_IF;j=j+1)
        r_xali_xaim_pkt_order_seqnum[j] <= #`TP r_xali_xaim_pkt_order_seqnum[j] + ((d_xali_xaim_pkt[j].hdr.tlp_eot && !d_xaim_xali_halt[j]) ? 3'b001 : 3'b000);
    end
  end
  
  always_comb begin : b_core_client_p_PROC
    b_core_client_p.w_halt                  = d_xaim_xali_halt[0]                                                                ;
    d_xali_xaim_pkt[0].prfx                 = b_core_client_p.w_header.common2.prfx[K_PRFXWD-`CX_PRFX_PAR_WD-1:0]                ;
    d_xali_xaim_pkt[0].hdr.cpl_bcm          = b_core_client_p.w_header.common2.cpl_bcm                                           ;
    d_xali_xaim_pkt[0].hdr.cpl_status       = b_core_client_p.w_header.common2.cpl_status                                        ;
    d_xali_xaim_pkt[0].hdr.tlp_addr         = b_core_client_p.w_header.common2.addr                                              ;
    d_xali_xaim_pkt[0].hdr.tlp_attr         = b_core_client_p.w_header.common1.attr                                              ;
    d_xali_xaim_pkt[0].hdr.tlp_byte_len     = b_core_client_p.w_header.dma.req == E_DMA_BYPASS ? 
                                                 b_core_client_p.w_header.xadmPort.tlp_byte_len
                                               : f_tlp_dwlen2bytelen(b_core_client_p.w_header.common2.dw_len)                    ;
    d_xali_xaim_pkt[0].hdr.tlp_dv           = b_core_client_p.w_dv                                                               ;
    d_xali_xaim_pkt[0].hdr.tlp_eot          = b_core_client_p.w_eot                                                              ;
    d_xali_xaim_pkt[0].hdr.tlp_fmt          = b_core_client_p.w_header.common2.fmt                                               ;
    d_xali_xaim_pkt[0].hdr.tlp_func_num     = b_core_client_p.w_header.common1.pfunc_num                                         ;
    d_xali_xaim_pkt[0].hdr.tlp_hv           = b_core_client_p.w_hv                                                               ;
    d_xali_xaim_pkt[0].hdr.tlp_tc           = b_core_client_p.w_header.common1.tc                                                ;
    d_xali_xaim_pkt[0].hdr.tlp_tid          = b_core_client_p.w_header.common1.pcieTag                                           ;
    d_xali_xaim_pkt[0].hdr.tlp_ats          = b_core_client_p.w_header.common2.ats                                               ;
    d_xali_xaim_pkt[0].hdr.addr_align_en    = b_core_client_p.w_header.xadmPort.addr_align_en                                    ;
    d_xali_xaim_pkt[0].hdr.cpl_last         = b_core_client_p.w_header.common4.cpl_last                                          ;
    d_xali_xaim_pkt[0].hdr.cpl_byte_cnt     = b_core_client_p.w_header.common2.byte_cnt                                          ;
    d_xali_xaim_pkt[0].hdr.remote_req_id    = b_core_client_p.w_header.common2.cmpltr_id                                         ;
    d_xali_xaim_pkt[0].hdr.cpl_lookup_id    = `CX_REMOTE_LOOKUPID_WD'(b_core_client_p.w_header.common3.lookupid)                            ;
    d_xali_xaim_pkt[0].hdr.tlp_bad_eot      = b_core_client_p.w_header.xadmPort.bad_eot                                          ;
    d_xali_xaim_pkt[0].hdr.tlp_byte_en      ={b_core_client_p.w_header.common2.last_be,b_core_client_p.w_header.common2.first_be};
    d_xali_xaim_pkt[0].hdr.tlp_dma          = b_core_client_p.w_header.dma.req                                                   ;
    d_xali_xaim_pkt[0].hdr.tlp_dma_channel  = b_core_client_p.w_header.dma.channel                                               ;
    d_xali_xaim_pkt[0].hdr.tlp_ep           = b_core_client_p.w_header.common2.poisoned                                          ;
    d_xali_xaim_pkt[0].hdr.tlp_td           = b_core_client_p.w_header.common2.td                                                ;
    d_xali_xaim_pkt[0].hdr.tlp_type         = b_core_client_p.w_header.common2.typ                                               ;
    d_xali_xaim_pkt[0].hdr.tlp_nw           = b_core_client_p.w_header.common3.nw                                                ;
    d_xali_xaim_pkt[0].hdr.tlp_atu_bypass   = b_core_client_p.w_header.xadmPort.atu_bypass                                       ;
    d_xali_xaim_pkt[0].hdr.tlp_ph           = b_core_client_p.w_header.common2.tph_ph                                            ;
    d_xali_xaim_pkt[0].hdr.tlp_st           = b_core_client_p.w_header.common2.tph_st                                            ;
    d_xali_xaim_pkt[0].hdr.tlp_th           = b_core_client_p.w_header.common2.tph_th                                            ;
    d_xali_xaim_pkt[0].hdr.tlp_segment      = b_core_client_p.w_header.flit_mode.req_sgmt                                        ;
    d_xali_xaim_pkt[0].hdr.tlp_dst_segment  = b_core_client_p.w_header.flit_mode.dst_sgmt                                        ;
    d_xali_xaim_pkt[0].data                 = b_core_client_p.w_data[(32*`CX_NW)-1:0]                                            ;
    d_xali_xaim_pkt[0].prfx_prot            = b_core_client_p.w_header.common2.prfx[K_PRFXWD-1:K_PRFXWD-`CX_PRFX_PAR_WD]         ;
    d_xali_xaim_pkt[0].hdr_prot             = b_core_client_p.w_headerProt                                                       ;
    d_xali_xaim_pkt[0].data_prot            = b_core_client_p.w_data[`CC_CORE_DATA_BUS_WD-1:(32*`CX_NW)]                         ;
    d_xali_xaim_pkt[0].order_seqnum         = r_xali_xaim_pkt_order_seqnum[0]                                                    ;
    d_xali_xaim_pkt[0].is_dma               = |b_core_client_p.w_header.dma.req                                                  ;
  end
  
  always_comb begin : b_core_client_np_PROC
    b_core_client_np.w_halt                 = d_xaim_xali_halt[1]                                                                 ;
    d_xali_xaim_pkt[1].prfx                 = b_core_client_np.w_header.common2.prfx[K_PRFXWD-`CX_PRFX_PAR_WD-1:0]                ;
    d_xali_xaim_pkt[1].hdr.cpl_bcm          = b_core_client_np.w_header.common2.cpl_bcm                                           ;
    d_xali_xaim_pkt[1].hdr.cpl_status       = b_core_client_np.w_header.common2.cpl_status                                        ;
    d_xali_xaim_pkt[1].hdr.tlp_addr         = b_core_client_np.w_header.common2.addr                                              ;
    d_xali_xaim_pkt[1].hdr.tlp_attr         = b_core_client_np.w_header.common1.attr                                              ;
    d_xali_xaim_pkt[1].hdr.tlp_byte_len     = b_core_client_np.w_header.dma.req == E_DMA_BYPASS ? 
                                                 b_core_client_np.w_header.xadmPort.tlp_byte_len
                                               : f_tlp_dwlen2bytelen(b_core_client_np.w_header.common2.dw_len)                    ;
    d_xali_xaim_pkt[1].hdr.tlp_dv           = b_core_client_np.w_dv                                                               ;
    d_xali_xaim_pkt[1].hdr.tlp_eot          = b_core_client_np.w_eot                                                              ;
    d_xali_xaim_pkt[1].hdr.tlp_fmt          = b_core_client_np.w_header.common2.fmt                                               ;
    d_xali_xaim_pkt[1].hdr.tlp_func_num     = b_core_client_np.w_header.common1.pfunc_num                                         ;
    d_xali_xaim_pkt[1].hdr.tlp_hv           = b_core_client_np.w_hv                                                               ;
    d_xali_xaim_pkt[1].hdr.tlp_tc           = b_core_client_np.w_header.common1.tc                                                ;
    d_xali_xaim_pkt[1].hdr.tlp_tid          = b_core_client_np.w_header.common1.pcieTag                                           ;
    d_xali_xaim_pkt[1].hdr.tlp_ats          = b_core_client_np.w_header.common2.ats                                               ;
    d_xali_xaim_pkt[1].hdr.addr_align_en    = b_core_client_np.w_header.xadmPort.addr_align_en                                    ;
    d_xali_xaim_pkt[1].hdr.cpl_last         = b_core_client_np.w_header.common4.cpl_last                                          ;
    d_xali_xaim_pkt[1].hdr.cpl_byte_cnt     = b_core_client_np.w_header.common2.byte_cnt                                          ;
    d_xali_xaim_pkt[1].hdr.remote_req_id    = b_core_client_np.w_header.common2.cmpltr_id                                         ;
    d_xali_xaim_pkt[1].hdr.cpl_lookup_id    = `CX_REMOTE_LOOKUPID_WD'(b_core_client_np.w_header.common3.lookupid)                            ;
    d_xali_xaim_pkt[1].hdr.tlp_bad_eot      = b_core_client_np.w_header.xadmPort.bad_eot                                          ;
    d_xali_xaim_pkt[1].hdr.tlp_byte_en      ={b_core_client_np.w_header.common2.last_be,b_core_client_np.w_header.common2.first_be};
    d_xali_xaim_pkt[1].hdr.tlp_dma          = b_core_client_np.w_header.dma.req                                                   ;
    d_xali_xaim_pkt[1].hdr.tlp_dma_channel  = b_core_client_np.w_header.dma.channel                                               ;
    d_xali_xaim_pkt[1].hdr.tlp_ep           = b_core_client_np.w_header.common2.poisoned                                          ;
    d_xali_xaim_pkt[1].hdr.tlp_td           = b_core_client_np.w_header.common2.td                                                ;
    d_xali_xaim_pkt[1].hdr.tlp_type         = b_core_client_np.w_header.common2.typ                                               ;
    d_xali_xaim_pkt[1].hdr.tlp_nw           = b_core_client_np.w_header.common3.nw                                                ;
    d_xali_xaim_pkt[1].hdr.tlp_atu_bypass   = b_core_client_np.w_header.xadmPort.atu_bypass                                       ;
    d_xali_xaim_pkt[1].hdr.tlp_ph           = b_core_client_np.w_header.common2.tph_ph                                            ;
    d_xali_xaim_pkt[1].hdr.tlp_st           = b_core_client_np.w_header.common2.tph_st                                            ;
    d_xali_xaim_pkt[1].hdr.tlp_th           = b_core_client_np.w_header.common2.tph_th                                            ;
    d_xali_xaim_pkt[1].hdr.tlp_segment      = b_core_client_np.w_header.flit_mode.req_sgmt                                        ;
    d_xali_xaim_pkt[1].hdr.tlp_dst_segment  = b_core_client_np.w_header.flit_mode.dst_sgmt                                        ;
    d_xali_xaim_pkt[1].data                 = b_core_client_np.w_data[(32*`CX_NW)-1:0]                                            ;
    d_xali_xaim_pkt[1].prfx_prot            = b_core_client_np.w_header.common2.prfx[K_PRFXWD-1:K_PRFXWD-`CX_PRFX_PAR_WD]         ;
    d_xali_xaim_pkt[1].hdr_prot             = b_core_client_np.w_headerProt                                                       ;
    d_xali_xaim_pkt[1].data_prot            = b_core_client_np.w_data[`CC_CORE_DATA_BUS_WD-1:(32*`CX_NW)]                         ;
    d_xali_xaim_pkt[1].order_seqnum         = r_xali_xaim_pkt_order_seqnum[1]                                                     ;
    d_xali_xaim_pkt[1].is_dma               = |b_core_client_np.w_header.dma.req                                                  ;
  end
  
  always_comb begin : b_core_client_cpl_PROC
    b_core_client_cpl.w_halt                = d_xaim_xali_halt[2]                                                                  ;
    d_xali_xaim_pkt[2].prfx                 =  '0                                                                                  ;
    d_xali_xaim_pkt[2].hdr.cpl_bcm          = b_core_client_cpl.w_header.common2.cpl_bcm                                           ;
    d_xali_xaim_pkt[2].hdr.cpl_status       = b_core_client_cpl.w_header.common2.cpl_status                                        ;
    d_xali_xaim_pkt[2].hdr.tlp_addr         = b_core_client_cpl.w_header.common2.addr                                              ;
    d_xali_xaim_pkt[2].hdr.tlp_attr         = b_core_client_cpl.w_header.common1.attr                                              ;
    d_xali_xaim_pkt[2].hdr.tlp_byte_len     = b_core_client_cpl.w_header.dma.req == E_DMA_BYPASS ? 
                                                 b_core_client_cpl.w_header.xadmPort.tlp_byte_len
                                               : f_tlp_dwlen2bytelen(b_core_client_cpl.w_header.common2.dw_len)                    ;
    d_xali_xaim_pkt[2].hdr.tlp_dv           = b_core_client_cpl.w_dv                                                               ;
    d_xali_xaim_pkt[2].hdr.tlp_eot          = b_core_client_cpl.w_eot                                                              ;
    d_xali_xaim_pkt[2].hdr.tlp_fmt          = b_core_client_cpl.w_header.common2.fmt                                               ;
    d_xali_xaim_pkt[2].hdr.tlp_func_num     = b_core_client_cpl.w_header.common1.pfunc_num                                         ;
    d_xali_xaim_pkt[2].hdr.tlp_hv           = b_core_client_cpl.w_hv                                                               ;
    d_xali_xaim_pkt[2].hdr.tlp_tc           = b_core_client_cpl.w_header.common1.tc                                                ;
    d_xali_xaim_pkt[2].hdr.tlp_tid          = b_core_client_cpl.w_header.common1.pcieTag                                           ;
    d_xali_xaim_pkt[2].hdr.tlp_ats          = b_core_client_cpl.w_header.common2.ats                                               ;
    d_xali_xaim_pkt[2].hdr.addr_align_en    = b_core_client_cpl.w_header.xadmPort.addr_align_en                                    ;
    d_xali_xaim_pkt[2].hdr.cpl_last         = b_core_client_cpl.w_header.common4.cpl_last                                          ;
    d_xali_xaim_pkt[2].hdr.cpl_byte_cnt     = b_core_client_cpl.w_header.common2.byte_cnt                                          ;
    d_xali_xaim_pkt[2].hdr.remote_req_id    = b_core_client_cpl.w_header.common2.cmpltr_id                                         ;
    d_xali_xaim_pkt[2].hdr.cpl_lookup_id    = `CX_REMOTE_LOOKUPID_WD'(b_core_client_cpl.w_header.common3.lookupid)                            ;
    d_xali_xaim_pkt[2].hdr.tlp_bad_eot      = b_core_client_cpl.w_header.xadmPort.bad_eot                                          ;
    d_xali_xaim_pkt[2].hdr.tlp_byte_en      ={b_core_client_cpl.w_header.common2.last_be,b_core_client_cpl.w_header.common2.first_be};
    d_xali_xaim_pkt[2].hdr.tlp_dma          = b_core_client_cpl.w_header.dma.req                                                   ;
    d_xali_xaim_pkt[2].hdr.tlp_dma_channel  = b_core_client_cpl.w_header.dma.channel                                               ;
    d_xali_xaim_pkt[2].hdr.tlp_ep           = b_core_client_cpl.w_header.common2.poisoned                                          ;
    d_xali_xaim_pkt[2].hdr.tlp_td           = b_core_client_cpl.w_header.common2.td                                                ;
    d_xali_xaim_pkt[2].hdr.tlp_type         = b_core_client_cpl.w_header.common2.typ                                               ;
    d_xali_xaim_pkt[2].hdr.tlp_nw           = b_core_client_cpl.w_header.common3.nw                                                ;
    d_xali_xaim_pkt[2].hdr.tlp_atu_bypass   = b_core_client_cpl.w_header.xadmPort.atu_bypass                                       ;
    d_xali_xaim_pkt[2].hdr.tlp_ph           = b_core_client_cpl.w_header.common2.tph_ph                                            ;
    d_xali_xaim_pkt[2].hdr.tlp_st           = b_core_client_cpl.w_header.common2.tph_st                                            ;
    d_xali_xaim_pkt[2].hdr.tlp_th           = b_core_client_cpl.w_header.common2.tph_th                                            ;
    d_xali_xaim_pkt[2].hdr.tlp_segment      = b_core_client_cpl.w_header.flit_mode.req_sgmt                                        ;
    d_xali_xaim_pkt[2].hdr.tlp_dst_segment  = b_core_client_cpl.w_header.flit_mode.dst_sgmt                                        ;
    d_xali_xaim_pkt[2].data                 = b_core_client_cpl.w_data[(32*`CX_NW)-1:0]                                            ;
    d_xali_xaim_pkt[2].prfx_prot            = `CX_RAS_PARITY_MODE ? '1 : '0                                                        ;
    d_xali_xaim_pkt[2].hdr_prot             = b_core_client_cpl.w_headerProt                                                       ;
    d_xali_xaim_pkt[2].data_prot            = b_core_client_cpl.w_data[`CC_CORE_DATA_BUS_WD-1:(32*`CX_NW)]                         ;
    d_xali_xaim_pkt[2].order_seqnum         = r_xali_xaim_pkt_order_seqnum[2]                                                      ;
    d_xali_xaim_pkt[2].is_dma               = |b_core_client_cpl.w_header.dma.req                                                  ;
  end
  
  always_comb begin : b_app_client_p_PROC
    int_xaim_xali_halt[0]                                          = b_app_client_p.w_halt             ;
    b_app_client_p.w_data[(32*`CX_NW)-1:0]                         = int_xali_xaim_pkt[0].data         ;
    b_app_client_p.w_data[`CC_CORE_DATA_BUS_WD-1:(32*`CX_NW)]      = int_xali_xaim_pkt[0].data_prot    ;
    b_app_client_p.w_dv                                            = int_xali_xaim_pkt[0].hdr.tlp_dv   ;
    b_app_client_p.w_eot                                           = int_xali_xaim_pkt[0].hdr.tlp_eot  ;
    b_app_client_p.w_hv                                            = int_xali_xaim_pkt[0].hdr.tlp_hv   ;
    b_app_client_p.w_headerProt = int_xali_xaim_pkt[0].hdr_prot;
    b_app_client_p.w_header = '{
       default: '0
      ,common1: '{
         default: '0
        ,attr          : int_xali_xaim_pkt[0].hdr.tlp_attr
        ,pfunc_num     : int_xali_xaim_pkt[0].hdr.tlp_func_num
        ,tc            : int_xali_xaim_pkt[0].hdr.tlp_tc
        ,pcieTag       : int_xali_xaim_pkt[0].hdr.tlp_tid
      }
      ,common2: '{
         default: '0
        ,cpl_bcm       : int_xali_xaim_pkt[0].hdr.cpl_bcm
        ,byte_cnt      : int_xali_xaim_pkt[0].hdr.cpl_byte_cnt
        ,cmpltr_id     : int_xali_xaim_pkt[0].hdr.remote_req_id
        ,cpl_status    : int_xali_xaim_pkt[0].hdr.cpl_status
        ,addr          : int_xali_xaim_pkt[0].hdr.tlp_addr
        ,first_be      : int_xali_xaim_pkt[0].hdr.tlp_byte_en[3:0]
        ,last_be       : int_xali_xaim_pkt[0].hdr.tlp_byte_en[7:4]
        ,dw_len        : f_tlp_bytelen2dwlen(int_xali_xaim_pkt[0].hdr.tlp_byte_len)
        ,poisoned      : int_xali_xaim_pkt[0].hdr.tlp_ep
        ,fmt           : int_xali_xaim_pkt[0].hdr.tlp_fmt
        ,td            : int_xali_xaim_pkt[0].hdr.tlp_td
        ,typ           : int_xali_xaim_pkt[0].hdr.tlp_type
        ,ats           : int_xali_xaim_pkt[0].hdr.tlp_ats
        ,tph_ph        : int_xali_xaim_pkt[0].hdr.tlp_ph
        ,tph_st        : int_xali_xaim_pkt[0].hdr.tlp_st
        ,tph_th        : int_xali_xaim_pkt[0].hdr.tlp_th
        ,prfx          : { int_xali_xaim_pkt[0].prfx_prot, int_xali_xaim_pkt[0].prfx}
      }
      ,common3: '{
         default: '0
        ,lookupid      : int_xali_xaim_pkt[0].hdr.cpl_lookup_id[`CX_REMOTE_MAX_TAGS_WD-1:0]
        ,nw            : int_xali_xaim_pkt[0].hdr.tlp_nw
      }
      ,common4: '{
         default: '0        
        //,cpl_last      : int_xali_xaim_pkt[0].hdr.cpl_last
        //,req_id        : int_xali_xaim_pkt[0].hdr.app_dev_id
      }
      ,xadmPort: '{
         default: '0
        ,tlp_byte_len  : int_xali_xaim_pkt[0].hdr.tlp_byte_len
        ,addr_align_en : int_xali_xaim_pkt[0].hdr.addr_align_en
        ,bad_eot       : int_xali_xaim_pkt[0].hdr.tlp_bad_eot
        ,atu_bypass    : int_xali_xaim_pkt[0].hdr.tlp_atu_bypass
      }
      ,dma: '{
         default: '0
        ,req           : dma_req_type_e'(int_xali_xaim_pkt[0].hdr.tlp_dma)
        ,channel       : int_xali_xaim_pkt[0].hdr.tlp_dma_channel
      }
      ,order_seq_no: '{
         default: '0
        ,outbound: int_xali_xaim_pkt[0].order_seqnum
      }
      ,flit_mode: '{
         default: '0
        ,dst_sgmt: int_xali_xaim_pkt[0].hdr.tlp_dst_segment
        ,req_sgmt: int_xali_xaim_pkt[0].hdr.tlp_segment
      }
    };
  end

  always_comb begin : b_app_client_np_PROC
    int_xaim_xali_halt[1]                                           = b_app_client_np.w_halt            ;
    b_app_client_np.w_data[(32*`CX_NW)-1:0]                         = int_xali_xaim_pkt[1].data         ;
    b_app_client_np.w_data[`CC_CORE_DATA_BUS_WD-1:(32*`CX_NW)]      = int_xali_xaim_pkt[1].data_prot    ;
    b_app_client_np.w_dv                                            = int_xali_xaim_pkt[1].hdr.tlp_dv   ;
    b_app_client_np.w_eot                                           = int_xali_xaim_pkt[1].hdr.tlp_eot  ;
    b_app_client_np.w_hv                                            = int_xali_xaim_pkt[1].hdr.tlp_hv   ;
    b_app_client_np.w_headerProt = int_xali_xaim_pkt[1].hdr_prot;
    b_app_client_np.w_header = '{
       default: '0
      ,common1: '{
         default: '0
        ,attr          : int_xali_xaim_pkt[1].hdr.tlp_attr
        ,pfunc_num     : int_xali_xaim_pkt[1].hdr.tlp_func_num
        ,tc            : int_xali_xaim_pkt[1].hdr.tlp_tc
        ,pcieTag       : int_xali_xaim_pkt[1].hdr.tlp_tid
      }
      ,common2: '{
         default: '0
        ,cpl_bcm       : int_xali_xaim_pkt[1].hdr.cpl_bcm
        ,byte_cnt      : int_xali_xaim_pkt[1].hdr.cpl_byte_cnt
        ,cmpltr_id     : int_xali_xaim_pkt[1].hdr.remote_req_id
        ,cpl_status    : int_xali_xaim_pkt[1].hdr.cpl_status
        ,addr          : int_xali_xaim_pkt[1].hdr.tlp_addr
        ,first_be      : int_xali_xaim_pkt[1].hdr.tlp_byte_en[3:0]
        ,last_be       : int_xali_xaim_pkt[1].hdr.tlp_byte_en[7:4]
        ,dw_len        : f_tlp_bytelen2dwlen(int_xali_xaim_pkt[1].hdr.tlp_byte_len)
        ,poisoned      : int_xali_xaim_pkt[1].hdr.tlp_ep
        ,fmt           : int_xali_xaim_pkt[1].hdr.tlp_fmt
        ,td            : int_xali_xaim_pkt[1].hdr.tlp_td
        ,typ           : int_xali_xaim_pkt[1].hdr.tlp_type
        ,ats           : int_xali_xaim_pkt[1].hdr.tlp_ats
        ,tph_ph        : int_xali_xaim_pkt[1].hdr.tlp_ph
        ,tph_st        : int_xali_xaim_pkt[1].hdr.tlp_st
        ,tph_th        : int_xali_xaim_pkt[1].hdr.tlp_th
        ,prfx          : { int_xali_xaim_pkt[1].prfx_prot, int_xali_xaim_pkt[1].prfx}
      }
      ,common3: '{
         default: '0
        ,lookupid      : int_xali_xaim_pkt[1].hdr.cpl_lookup_id[`CX_REMOTE_MAX_TAGS_WD-1:0]
        ,nw            : int_xali_xaim_pkt[1].hdr.tlp_nw
      }
      ,common4: '{
         default: '0        
        //,cpl_last      : int_xali_xaim_pkt[1].hdr.cpl_last
        //,req_id        : int_xali_xaim_pkt[1].hdr.app_dev_id
      }
      ,xadmPort: '{
         default: '0
        ,tlp_byte_len  : int_xali_xaim_pkt[1].hdr.tlp_byte_len
        ,addr_align_en : int_xali_xaim_pkt[1].hdr.addr_align_en
        ,bad_eot       : int_xali_xaim_pkt[1].hdr.tlp_bad_eot
        ,atu_bypass    : int_xali_xaim_pkt[1].hdr.tlp_atu_bypass
      }
      ,dma: '{
         default: '0
        ,req           : dma_req_type_e'(int_xali_xaim_pkt[1].hdr.tlp_dma)
        ,channel       : int_xali_xaim_pkt[1].hdr.tlp_dma_channel
      }
      ,order_seq_no: '{
         default : '0
        ,outbound : int_xali_xaim_pkt[1].order_seqnum
      }
      ,flit_mode: '{
         default: '0
        ,dst_sgmt: int_xali_xaim_pkt[1].hdr.tlp_dst_segment
        ,req_sgmt: int_xali_xaim_pkt[1].hdr.tlp_segment
      }
    };
  end  
  
  always_comb begin : b_app_client_cpl_PROC
    int_xaim_xali_halt[2]                                            = b_app_client_cpl.w_halt           ;
    b_app_client_cpl.w_data[(32*`CX_NW)-1:0]                         = int_xali_xaim_pkt[2].data         ;
    b_app_client_cpl.w_data[`CC_CORE_DATA_BUS_WD-1:(32*`CX_NW)]      = int_xali_xaim_pkt[2].data_prot    ;
    b_app_client_cpl.w_dv                                            = int_xali_xaim_pkt[2].hdr.tlp_dv   ;
    b_app_client_cpl.w_eot                                           = int_xali_xaim_pkt[2].hdr.tlp_eot  ;
    b_app_client_cpl.w_hv                                            = int_xali_xaim_pkt[2].hdr.tlp_hv   ;
    b_app_client_cpl.w_headerProt = int_xali_xaim_pkt[2].hdr_prot;
    b_app_client_cpl.w_header = '{
       default: '0
      ,common1: '{
         default: '0
        ,attr          : int_xali_xaim_pkt[2].hdr.tlp_attr
        ,pfunc_num     : int_xali_xaim_pkt[2].hdr.tlp_func_num
        ,tc            : int_xali_xaim_pkt[2].hdr.tlp_tc
        ,pcieTag       : int_xali_xaim_pkt[2].hdr.tlp_tid
      }
      ,common2: '{
         default: '0
        ,cpl_bcm       : int_xali_xaim_pkt[2].hdr.cpl_bcm
        ,byte_cnt      : int_xali_xaim_pkt[2].hdr.cpl_byte_cnt
        ,cmpltr_id     : int_xali_xaim_pkt[2].hdr.remote_req_id
        ,cpl_status    : int_xali_xaim_pkt[2].hdr.cpl_status
        ,addr          : int_xali_xaim_pkt[2].hdr.tlp_addr
        ,first_be      : int_xali_xaim_pkt[2].hdr.tlp_byte_en[3:0]
        ,last_be       : int_xali_xaim_pkt[2].hdr.tlp_byte_en[7:4]
        ,dw_len        : f_tlp_bytelen2dwlen(int_xali_xaim_pkt[2].hdr.tlp_byte_len)
        ,poisoned      : int_xali_xaim_pkt[2].hdr.tlp_ep
        ,fmt           : int_xali_xaim_pkt[2].hdr.tlp_fmt
        ,td            : int_xali_xaim_pkt[2].hdr.tlp_td
        ,typ           : int_xali_xaim_pkt[2].hdr.tlp_type
        ,ats           : int_xali_xaim_pkt[2].hdr.tlp_ats
        ,tph_ph        : int_xali_xaim_pkt[2].hdr.tlp_ph
        ,tph_st        : int_xali_xaim_pkt[2].hdr.tlp_st
        ,tph_th        : int_xali_xaim_pkt[2].hdr.tlp_th
      }
      ,common3: '{
         default: '0
        ,lookupid      : int_xali_xaim_pkt[2].hdr.cpl_lookup_id[`CX_REMOTE_MAX_TAGS_WD-1:0]
        ,nw            : int_xali_xaim_pkt[2].hdr.tlp_nw
      }
      ,common4: '{
         default: '0        
        ,cpl_last      : int_xali_xaim_pkt[2].hdr.cpl_last
        //,req_id        : int_xali_xaim_pkt[2].hdr.app_dev_id
      }
      ,xadmPort: '{
         default: '0
        ,tlp_byte_len  : int_xali_xaim_pkt[2].hdr.tlp_byte_len
        ,addr_align_en : int_xali_xaim_pkt[2].hdr.addr_align_en
        ,bad_eot       : int_xali_xaim_pkt[2].hdr.tlp_bad_eot
        ,atu_bypass    : int_xali_xaim_pkt[2].hdr.tlp_atu_bypass
      }
      ,dma: '{
         default: '0
        ,req           : dma_req_type_e'(int_xali_xaim_pkt[2].hdr.tlp_dma)
        ,channel       : int_xali_xaim_pkt[2].hdr.tlp_dma_channel
      }
      ,order_seq_no: '{
         default : '0
        ,outbound : int_xali_xaim_pkt[2].order_seqnum
      }
      ,flit_mode: '{
         default: '0
        ,dst_sgmt: int_xali_xaim_pkt[2].hdr.tlp_dst_segment
        ,req_sgmt: int_xali_xaim_pkt[2].hdr.tlp_segment
      }
    };
  end
  
  always_comb begin : b_core_trgt_timeout_PROC
    b_core_trgt_timeout.w_hv = radm_cpl_timeout ;
    b_core_trgt_timeout.w_header = '{
      default: '0,
      common1: '{
         default      : '0
        ,attr         : radm_timeout_cpl_attr
        ,pcieTag      : radm_timeout_cpl_tag
        ,tc           : radm_timeout_cpl_tc
        ,pfunc_num    : radm_timeout_func_num
      },
      extra:'{
         default      : '0
        ,len          : '0 //radm_timeout_cpl_len
      }
    };
  end
    
  always_comb begin : tied_wires_PROC
    dma_mcb_rdll_halt         = '0 ;
    dma_mcb_wrll_halt         = '0 ;
  end
  
  //------------------------------------------------------------------------
  // Segmented Buffer
  //------------------------------------------------------------------------
  assign edmarbuff2ram_addra                = b_rdBuffer_ram0.w_addra          ;
  assign edmarbuff2ram_addrb                = b_rdBuffer_ram0.w_addrb          ;
  assign edmarbuff2ram_dout                 = b_rdBuffer_ram0.w_dina           ;
  assign edmarbuff2ram_we                   = b_rdBuffer_ram0.w_ena            ;
  assign edmarbuff2ram_re                   = b_rdBuffer_ram0.w_enb            ;
  assign b_rdBuffer_ram0.w_doutb            = ram2edmarbuff_din                ;
  //------------------------------------------------------------------------
  // RD Engine Linked List Pointers
  //------------------------------------------------------------------------
  assign edma_rd_eng_ll_addra_ram           = b_rdEng_ll_ram.w_addra           ;
  assign edma_rd_eng_ll_addrb_ram           = b_rdEng_ll_ram.w_addrb           ;
  assign edma_rd_eng_ll_dout_ram            = b_rdEng_ll_ram.w_dina            ;
  assign edma_rd_eng_ll_we_ram              = b_rdEng_ll_ram.w_ena             ;
  assign edma_rd_eng_ll_re_ram              = b_rdEng_ll_ram.w_enb             ;
  assign b_rdEng_ll_ram.w_doutb             = edma_rd_eng_ll_din_ram           ;
  //------------------------------------------------------------------------
  // WR Engine Linked List Pointers
  //------------------------------------------------------------------------
  assign edma_wr_eng_ll_addra_ram           = b_wrEng_ll_ram.w_addra           ;
  assign edma_wr_eng_ll_addrb_ram           = b_wrEng_ll_ram.w_addrb           ;
  assign edma_wr_eng_ll_dout_ram            = b_wrEng_ll_ram.w_dina            ;
  assign edma_wr_eng_ll_we_ram              = b_wrEng_ll_ram.w_ena             ;
  assign edma_wr_eng_ll_re_ram              = b_wrEng_ll_ram.w_enb             ;
  assign b_wrEng_ll_ram.w_doutb             = edma_wr_eng_ll_din_ram           ;
  //------------------------------------------------------------------------
  // RD Engine Descriptors Queue
  //------------------------------------------------------------------------
  assign edma_rd_eng_ovrl_addra_ram         = b_rdEng_ovrl_ram.w_addra         ;
  assign edma_rd_eng_ovrl_addrb_ram         = b_rdEng_ovrl_ram.w_addrb         ;
  assign edma_rd_eng_ovrl_dout_ram          = b_rdEng_ovrl_ram.w_dina          ;
  assign edma_rd_eng_ovrl_we_ram            = b_rdEng_ovrl_ram.w_ena           ;
  assign edma_rd_eng_ovrl_re_ram            = b_rdEng_ovrl_ram.w_enb           ;
  assign b_rdEng_ovrl_ram.w_doutb           = edma_rd_eng_ovrl_din_ram         ;
  //------------------------------------------------------------------------
  // WR Engine Descriptors Queue
  //------------------------------------------------------------------------
  assign edma_wr_eng_ovrl_addra_ram         = b_wrEng_ovrl_ram.w_addra         ;
  assign edma_wr_eng_ovrl_addrb_ram         = b_wrEng_ovrl_ram.w_addrb         ;
  assign edma_wr_eng_ovrl_dout_ram          = b_wrEng_ovrl_ram.w_dina          ;
  assign edma_wr_eng_ovrl_we_ram            = b_wrEng_ovrl_ram.w_ena           ;
  assign edma_wr_eng_ovrl_re_ram            = b_wrEng_ovrl_ram.w_enb           ;
  assign b_wrEng_ovrl_ram.w_doutb           = edma_wr_eng_ovrl_din_ram         ;
  //------------------------------------------------------------------------
  // RD Engine Completion to Memory Write LUT
  //------------------------------------------------------------------------
  assign edma_rd_eng_c2w_lut_addra_ram      = b_rdEng_c2w_lut_ram.w_addra      ;
  assign edma_rd_eng_c2w_lut_addrb_ram      = b_rdEng_c2w_lut_ram.w_addrb      ;
  assign edma_rd_eng_c2w_lut_dout_ram       = b_rdEng_c2w_lut_ram.w_dina       ;
  assign edma_rd_eng_c2w_lut_we_ram         = b_rdEng_c2w_lut_ram.w_ena        ;
  assign edma_rd_eng_c2w_lut_re_ram         = b_rdEng_c2w_lut_ram.w_enb        ;
  assign b_rdEng_c2w_lut_ram.w_doutb        = edma_rd_eng_c2w_lut_din_ram      ;
  //------------------------------------------------------------------------
  // WR Engine Completion to Memory Write LUT
  //------------------------------------------------------------------------
  assign edma_wr_eng_c2w_lut_addra_ram      = b_wrEng_c2w_lut_ram.w_addra      ;
  assign edma_wr_eng_c2w_lut_addrb_ram      = b_wrEng_c2w_lut_ram.w_addrb      ;
  assign edma_wr_eng_c2w_lut_dout_ram       = b_wrEng_c2w_lut_ram.w_dina       ;
  assign edma_wr_eng_c2w_lut_we_ram         = b_wrEng_c2w_lut_ram.w_ena        ;
  assign edma_wr_eng_c2w_lut_re_ram         = b_wrEng_c2w_lut_ram.w_enb        ;
  assign b_wrEng_c2w_lut_ram.w_doutb        = edma_wr_eng_c2w_lut_din_ram      ;
  //------------------------------------------------------------------------
  // RD Engine Status Handler LUT
  //------------------------------------------------------------------------
  assign edma_rd_eng_stsh_lut_addra_ram     = b_rdEng_stsh_lut_ram.w_addra     ;
  assign edma_rd_eng_stsh_lut_addrb_ram     = b_rdEng_stsh_lut_ram.w_addrb     ;
  assign edma_rd_eng_stsh_lut_dout_ram      = b_rdEng_stsh_lut_ram.w_dina      ;
  assign edma_rd_eng_stsh_lut_we_ram        = b_rdEng_stsh_lut_ram.w_ena       ;
  assign edma_rd_eng_stsh_lut_re_ram        = b_rdEng_stsh_lut_ram.w_enb       ;
  assign b_rdEng_stsh_lut_ram.w_doutb       = edma_rd_eng_stsh_lut_din_ram     ;
  //------------------------------------------------------------------------
  // WR Engine Status Handler LUT
  //------------------------------------------------------------------------
  assign edma_wr_eng_stsh_lut_addra_ram     = b_wrEng_stsh_lut_ram.w_addra     ;
  assign edma_wr_eng_stsh_lut_addrb_ram     = b_wrEng_stsh_lut_ram.w_addrb     ;
  assign edma_wr_eng_stsh_lut_dout_ram      = b_wrEng_stsh_lut_ram.w_dina      ;
  assign edma_wr_eng_stsh_lut_we_ram        = b_wrEng_stsh_lut_ram.w_ena       ;
  assign edma_wr_eng_stsh_lut_re_ram        = b_wrEng_stsh_lut_ram.w_enb       ;
  assign b_wrEng_stsh_lut_ram.w_doutb       = edma_wr_eng_stsh_lut_din_ram     ;
  //------------------------------------------------------------------------
  // RD Engine MSI Pointers
  //---------------------------------------------------------- --------------
  assign edma_rd_eng_msi_addra_ram          = b_rdEng_msi_lut_ram.w_addra      ;
  assign edma_rd_eng_msi_addrb_ram          = b_rdEng_msi_lut_ram.w_addrb      ;
  assign edma_rd_eng_msi_dout_ram           = b_rdEng_msi_lut_ram.w_dina       ;
  assign edma_rd_eng_msi_we_ram             = b_rdEng_msi_lut_ram.w_ena        ;
  assign edma_rd_eng_msi_re_ram             = b_rdEng_msi_lut_ram.w_enb        ;
  assign b_rdEng_msi_lut_ram.w_doutb        = edma_rd_eng_msi_din_ram          ;
  //------------------------------------------------------------------------
  // WR Engine MSI Pointers
  //------------------------------------------------------------------------
  assign edma_wr_eng_msi_addra_ram          = b_wrEng_msi_lut_ram.w_addra      ;
  assign edma_wr_eng_msi_addrb_ram          = b_wrEng_msi_lut_ram.w_addrb      ;
  assign edma_wr_eng_msi_dout_ram           = b_wrEng_msi_lut_ram.w_dina       ;
  assign edma_wr_eng_msi_we_ram             = b_wrEng_msi_lut_ram.w_ena        ;
  assign edma_wr_eng_msi_re_ram             = b_wrEng_msi_lut_ram.w_enb        ;
  assign b_wrEng_msi_lut_ram.w_doutb        = edma_wr_eng_msi_din_ram          ;

  // AXI Bridge Subordinate P requests registered on DMA
  assign s_brdg_slv_core_client_p = ((d_xali_xaim_pkt[0].hdr.tlp_hv || d_xali_xaim_pkt[0].hdr.tlp_dv) && !d_xali_xaim_pkt[0].is_dma);


`endif // !UTB_NATIVE_AXI

  localparam AMBA_ERR_LOG_WD = 
                                 + 2 // u_ordrb_np & u_ordrb_p
                                 ;
                                 
  logic ras_err_wake_up;
  logic ras_err_wake_up_sync;
  logic ltim_np_ras_dp_wake_up_core;
  logic ltim_p_ras_dp_wake_up_core;
  logic msigic_reqid_ras_dp_wake_up_aclk;
  logic msigic_msidata_ras_dp_wake_up_aclk;
  logic msigic_reqid_ras_dp_wake_up_core;
  logic msigic_msidata_ras_dp_wake_up_core;
  logic mgr_ras_dp_wake_up;
  

  ras_dp_err_log_t                            ordrb_p_ras_dp_err_log;
  ras_dp_err_log_t                            ordrb_np_ras_dp_err_log;
  ras_dp_err_log_t                            msigic_ras_err_log_reqid ;
  ras_dp_err_log_t                            msigic_ras_err_log_msidata;
  ras_dp_err_log_t [AMBA_ERR_LOG_WD-1:0]      ras_err_log_mgr_amba;
  ras_dp_err_inj_t                            ras_err_inj_mgr_amba;
  



   assign en_mstr_aclk_g = mstr_aclk_active_axi 
   ;







endmodule
