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
// ---    $DateTime: 2024/01/24 06:45:16 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/DWC_pcie_app_layer.sv#12 $
// -------------------------------------------------------------------------
// --- Module description: App layer Top level module that groups CDM-CRGB; DMA and AMBA modules in a single module 
// --- Top level modules:
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Axi/DWC_pcie_axi_bridge_pkg.svh"
`include "Axi/DWC_pcie_axi_mstr_pkg.svh"
`include "Axi/DWC_pcie_axi_slv_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Cdm/cdm_pkg.svh"

 module DWC_pcie_app_layer
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_edmapf_pkg::*;

import cdm_pkg::*; 
#(
// module parameter port list
    parameter INST              = 0  // The uniquifying parameter for each port logic instance.
) 

                          (
   //----------------------------------
   // PORT DECLARATIONS
   //----------------------------------
    input logic                                  aux_clk_g
   ,input logic [3:0]                            device_type
   ,input logic                                           aux_clk
   ,input logic [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]    atu_reg_out_base
   ,input logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                         atu_reg_out_en
   ,input logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                         atu_reg_out_invert
   ,input logic [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]    atu_reg_out_limit
   ,input logic [`CX_ATU_MAX_REGION_SIZE*`CX_ATU_OUT_NREGIONS_MIN1-1:0] atu_reg_out_uppr_limit
   ,input logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                         atu_reg_out_incr_rgn_size

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

   ,input logic [5*`CX_ATU_OUT_NREGIONS_MIN1-1:0]                       atu_reg_out_type
   ,input logic [`CX_ATU_BASE_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]      atu_reg_out_upr_base

//ccx_tgl: ; atu_reg_out_func_num; ; When the Number of Functions is equals to 1 this signal won't toggle.

   ,input logic [`CX_NFUNC_WD*`CX_ATU_OUT_NREGIONS_MIN1-1:0]            atu_reg_out_func_num
   ,input logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                         atu_reg_out_func_bypass
   ,input logic [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                         atu_reg_out_snp
   ,input logic                                          cfg_axi_clk_gating_en
   ,input logic [3:0]                                    cfg_mstr_arcache_mode
   ,input logic [3:0]                                    cfg_mstr_awcache_mode
   ,input logic [3:0]                                    cfg_mstr_arcache_value
   ,input logic [3:0]                                    cfg_mstr_awcache_value
   ,input logic [31:0]                                   cfg_aximstr_msg_addr_high
   ,input logic [31:0]                                   cfg_aximstr_msg_addr_low
   ,input logic [1:0]                                    cfg_mstr_ardomain_mode
   ,input logic [1:0]                                    cfg_mstr_awdomain_mode
   ,input logic [1:0]                                    cfg_mstr_ardomain_value
   ,input logic [1:0]                                    cfg_mstr_awdomain_value
   ,input logic                                          cfg_ax_mstr_zeroread_fw

//ccx_tgl: ; cfg_max_payload_size[2]; ; The configured maximum payload size cannot be greater than the CX_MAX_MTU parameter

   ,input logic [(3*`CX_NFUNC)-1:0]                      cfg_max_payload_size

//ccx_tgl: ; cfg_max_rd_req_size[2]; ; The configured read request size cannot be greater than the CC_SLV_RD_REQ_SIZE parameter

   ,input logic [(3*`CX_NFUNC)-1:0]                      cfg_max_rd_req_size
   ,input logic [`CX_NFUNC-1:0]                          cfg_ext_tag_en
   ,input logic [`CX_NFUNC-1:0]                          cfg_10b_tag_en
   ,input logic [`CX_NFUNC-1:0]                          cfg_dmwr_req_en 
   ,input logic                                          cfg_memtype_value
   ,input logic [`FLT_Q_ADDR_WIDTH-3:0]                  cfg_memtype_boundary
   ,input logic [15:0]                                   cfg_order_rule_ctrl
   ,input logic [1:0]                                    cfg_ax_mstr_ordr_p_event_sel
   ,input logic                                          cfg_ax_snp_en
   ,input logic [`CX_NVC-1:0]                            cfg_ib_p_id_mng_ctrl
   ,input logic [23:0]                                   cfg_tc_struc_vc_map
   ,input logic [`N_XADM_P_IF-1:0]                        xali_posted_tlp_sent
   // ***************************************************
   // RAS.DP IO
   // ***************************************************
   ,input logic                                          cfg_rasdp_err_mode
   ,input logic [8:0]                                    ras_prot_r_disable
   ,input logic [6:0]                                    ras_prot_t_disable
   ,input logic                                          cfg_rasdp_err_mode_en
   ,output ras_dp_err_log_t                              axi_bridge_out_ras_dp_err_log
   ,input ras_dp_err_inj_t                               axi_bridge_in_ras_dp_err_inj
   ,input logic                                          axi_bridge_in_ras_dp_err_inj_wake_up
    ,output ras_dp_err_log_t                             hdma_ras_dp_err_log
    ,input  ras_dp_err_inj_t                             hdma_ras_dp_err_inj
 // RAS ECC RAM interface



   ,input logic                                          core_clk
   ,input logic                                          core_rst_n

   //CDM-CRGB interface
   ,input logic                                          crgb_cdm_cs
   ,input logic [`CC_CRGB_ADDR_WIDTH - 1:0]              crgb_cdm_addr
   ,input logic [`CC_CRGB_DATA_WIDTH - 1:0]              crgb_cdm_wdata
   ,input logic [`CC_CRGB_BE_WIDTH - 1:0]                crgb_cdm_wr
   ,input logic                                          crgb_cdm_source
   ,input logic                                          dbi_ack
   ,input logic [31:0]                                   dbi_dout


   ,input logic                                          test_clk_en
   ,input logic                                          test_rst_en
   // Clock & Reset
   ,output logic                                         mstr_aclk_g
   ,output logic                                         mstr_aresetn
   ,input logic                                          mstr_aclk
   ,output logic                                         mstr_rasdp_err_mode
   // AXI master write request
   ,input logic                                          mstr_awready

   // AXI master write data
   ,input logic                                          mstr_wready

   // AXI master write response
   ,input logic [`CC_MSTR_BUS_ID_WIDTH -1:0]             mstr_bid
   ,input logic                                          mstr_bvalid
   
   ,input logic [`CC_AXIJ_DMWR_VALUE+1:0]                mstr_bresp
   ,input logic [2:0]                                    mstr_bmisc_info_cpl_stat


   // AXI master read request
   ,input logic                                          mstr_arready

   // AXI master read response & read data

//ccx_tgl: ; mstr_rid[9:5]; ; Unreachable CC_MAX_MSTR_TAGS_AXI == 64.

   ,input logic [`CC_MSTR_BUS_ID_WIDTH -1:0]             mstr_rid
   ,input logic                                          mstr_rvalid
   ,input logic                                          mstr_rlast
   ,input logic [`MASTER_BUS_DATA_WIDTH -1:0]            mstr_rdata
   ,input logic [`CC_MSTR_R_USER_WIDTH-1:0]              mstr_ruser
   ,input logic [1:0]                                    mstr_rresp
   //ccx_tgl: ; mstr_rmisc_info_cpl_stat[1]; ; Only SC, CA and UR in cpl_stat are supported. Bridge don't support cfg_retry.
   ,input logic [2:0]                                    mstr_rmisc_info_cpl_stat
   ,input logic [`MSTR_RESP_MISC_INFO_PW -1:0]           mstr_rmisc_info

  
   // AXI master low power
   ,input logic                                          mstr_csysreq
   ,input logic [`CX_REMOTE_LOOKUPID_WD-1:0]             trgt_lookup_id

   ,input logic                                          radm_trgt1_p_0_pending

   ,input logic [`TRGT_DATA_WD-1:0]                      radm_trgt1_p_0_data
   ,input logic [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0]      radm_trgt1_p_0_hdr_prot
   ,input logic [`CX_PRFX_W_PAR-1:0]                     radm_trgt1_p_0_prfx
   ,input logic [`CX_NW-1:0]                             radm_trgt1_p_0_dwen
   ,input logic                                          radm_trgt1_p_0_dv
   ,input logic                                          radm_trgt1_p_0_hv
   ,input logic                                          radm_trgt1_p_0_eot
   ,input logic                                          radm_trgt1_p_0_dllp_abort
   ,input logic                                          radm_trgt1_p_0_tlp_abort
   ,input logic                                          radm_trgt1_p_0_ecrc_err
   ,input logic [1:0]                                    radm_trgt1_p_0_fmt
   //ccx_tgl: ; radm_trgt1_p_0_type[3]; ; No completions for TRGT1.
   ,input logic [4:0]                                    radm_trgt1_p_0_type
   ,input logic [2:0]                                    radm_trgt1_p_0_tc
   ,input logic [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_p_0_attr
   ,input logic [15:0]                                   radm_trgt1_p_0_reqid
   ,input logic [`CX_TAG_SIZE-1:0]                       radm_trgt1_p_0_tag
   ,input logic [`CX_NFUNC_WD-1:0]                       radm_trgt1_p_0_func_num
   ,input logic                                          radm_trgt1_p_0_td
   ,input logic                                          radm_trgt1_p_0_poisoned
   ,input logic [9:0]                                    radm_trgt1_p_0_dw_len
   ,input logic [3:0]                                    radm_trgt1_p_0_first_be
   ,input logic [`CX_NVC_LOG2-1:0]                       radm_trgt1_p_0_vc_num
   ,input logic [2:0]                                    radm_trgt1_p_0_cpl_status
   ,input logic [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_p_0_addr
   ,input logic [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_p_0_hdr_uppr_bytes
   ,input logic                                          radm_trgt1_p_0_rom_in_range
   ,input logic                                          radm_trgt1_p_0_io_req_in_range
   ,input logic [2:0]                                    radm_trgt1_p_0_in_membar_range
   ,input logic [3:0]                                    radm_trgt1_p_0_last_be
   ,input logic [1:0]                                    radm_trgt1_p_0_ats
   ,input logic                                          radm_trgt1_p_0_nw
   ,input logic                                          radm_trgt1_p_0_th
   ,input logic [1:0]                                    radm_trgt1_p_0_ph
   ,input logic [7:0]                                    radm_trgt1_p_0_st
   ,input logic                                          radm_trgt1_p_0_hdr_uppr_bytes_valid
   ,input logic [8:0]                                    radm_trgt1_p_0_reqtr_sgmt
   ,input logic [8:0]                                    radm_trgt1_p_0_dest_sgmt
   ,input logic [`CX_RADM_PKT_ORD_WD-1:0]                radm_trgt1_p_0_pkt_order_no
   ,input logic [`TRGT_DATA_WD-1:0]                      radm_trgt1_np_0_data
   ,input logic [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]     radm_trgt1_np_0_hdr_prot
   ,input logic [`CX_PRFX_W_PAR-1:0]                     radm_trgt1_np_0_prfx
   ,input logic [`CX_NW-1:0]                             radm_trgt1_np_0_dwen
   ,input logic                                          radm_trgt1_np_0_dv
   ,input logic                                          radm_trgt1_np_0_hv
   ,input logic                                          radm_trgt1_np_0_eot
   ,input logic                                          radm_trgt1_np_0_dllp_abort
   ,input logic                                          radm_trgt1_np_0_tlp_abort
   ,input logic                                          radm_trgt1_np_0_ecrc_err
   ,input logic [1:0]                                    radm_trgt1_np_0_fmt
   ,input logic [4:0]                                    radm_trgt1_np_0_type
   ,input logic [2:0]                                    radm_trgt1_np_0_tc
   ,input logic [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_np_0_attr
   ,input logic [15:0]                                   radm_trgt1_np_0_reqid
   ,input logic [`CX_TAG_SIZE-1:0]                       radm_trgt1_np_0_tag
   ,input logic [`CX_NFUNC_WD-1:0]                       radm_trgt1_np_0_func_num
   ,input logic [2:0]                                    radm_trgt1_np_0_cpl_status
   ,input logic                                          radm_trgt1_np_0_td
   ,input logic                                          radm_trgt1_np_0_poisoned
   ,input logic [9:0]                                    radm_trgt1_np_0_dw_len
   ,input logic [3:0]                                    radm_trgt1_np_0_first_be
   ,input logic [`CX_NVC_LOG2-1:0]                       radm_trgt1_np_0_vc_num

   ,input logic [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_np_0_addr
   ,input logic [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_np_0_hdr_uppr_bytes

   ,input logic                                          radm_trgt1_np_0_rom_in_range
   ,input logic                                          radm_trgt1_np_0_io_req_in_range
   ,input logic [2:0]                                    radm_trgt1_np_0_in_membar_range
   ,input logic [3:0]                                    radm_trgt1_np_0_last_be
   ,input logic [1:0]                                    radm_trgt1_np_0_ats
   ,input logic                                          radm_trgt1_np_0_nw
   //ccx_tgl: ; radm_trgt1_np_0_cxlsrc; ; This signal is tied to zero for DTI Version 1.
   ,input logic                                          radm_trgt1_np_0_cxlsrc
   ,input logic                                          radm_trgt1_np_0_th
   ,input logic [1:0]                                    radm_trgt1_np_0_ph
   ,input logic [7:0]                                    radm_trgt1_np_0_st
   ,input logic [8:0]                                    radm_trgt1_np_0_reqtr_sgmt
   ,input logic [8:0]                                    radm_trgt1_np_0_dest_sgmt
   ,input logic [`CX_RADM_PKT_ORD_WD-1:0]                radm_trgt1_np_0_pkt_order_no

   ,input logic [`TRGT_DATA_WD-1:0]                      radm_trgt1_cpl_0_data
   ,input logic [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]    radm_trgt1_cpl_0_hdr_prot
   ,input logic [`CX_PRFX_W_PAR-1:0]                     radm_trgt1_cpl_0_prfx
   ,input logic [`CX_NW-1:0]                             radm_trgt1_cpl_0_dwen
   ,input logic                                          radm_trgt1_cpl_0_dv
   ,input logic                                          radm_trgt1_cpl_0_hv
   ,input logic                                          radm_trgt1_cpl_0_eot
   ,input logic                                          radm_trgt1_cpl_0_dllp_abort
   ,input logic                                          radm_trgt1_cpl_0_tlp_abort
   ,input logic                                          radm_trgt1_cpl_0_ecrc_err
//ccx_tgl: ; radm_trgt1_cpl_0_fmt[0]; ; Unreachable due Completion type, because all completions are 3DW.
   ,input logic [1:0]                                    radm_trgt1_cpl_0_fmt
   //ccx_tgl: ; radm_trgt1_cpl_0_type[4:1]; ; For Completions, this bits are always 0.
   ,input logic [4:0]                                    radm_trgt1_cpl_0_type
   ,input logic [2:0]                                    radm_trgt1_cpl_0_tc
   ,input logic [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_cpl_0_attr
   ,input logic [15:0]                                   radm_trgt1_cpl_0_reqid
   ,input logic [`CX_TAG_SIZE-1:0]                       radm_trgt1_cpl_0_tag
   ,input logic [`CX_NFUNC_WD-1:0]                       radm_trgt1_cpl_0_func_num
   ,input logic [2:0]                                    radm_trgt1_cpl_0_cpl_status
   ,input logic                                          radm_trgt1_cpl_0_td
   ,input logic                                          radm_trgt1_cpl_0_poisoned
   ,input logic [9:0]                                    radm_trgt1_cpl_0_dw_len
   //ccx_tgl: ; radm_trgt1_cpl_0_bcm; ; The Byte Count Modified bit is not applicable for an endpoint device.
   ,input logic                                          radm_trgt1_cpl_0_bcm

//ccx_tgl: ; radm_trgt1_cpl_0_byte_cnt[11:10]; ; The largest packet payload that the device supports is 9.

   ,input logic [11:0]                                   radm_trgt1_cpl_0_byte_cnt
   ,input logic [15:0]                                   radm_trgt1_cpl_0_cmpltr_id
   ,input logic                                          radm_trgt1_cpl_0_last
   ,input logic [`CX_NVC_LOG2-1:0]                       radm_trgt1_cpl_0_vc_num
   ,input logic [`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0]        radm_trgt1_cpl_0_addr
   ,input logic [8:0]                                    radm_trgt1_cpl_0_dest_sgmt
   ,input logic [7:0]                                    radm_trgt1_cpl_0_cpl_sgmt
   ,input logic [`CX_RADM_PKT_ORD_WD -1 :0]              radm_trgt1_cpl_0_pkt_order_no

   ,output logic                                         trgt1_radm_intf_cpl_0_halt
   ,output logic                                         trgt1_radm_intf_p_0_halt
   ,output logic                                         trgt1_radm_intf_np_0_halt

   ,input logic                                          radm_cpl_timeout
   ,input logic [1:0]                                    radm_timeout_cpl_attr

//ccx_tgl: ; radm_timeout_cpl_tag[13:9]; ; The CX_MAX_TAG controls the maximum number of tags.

   ,input logic [`CX_TAG_SIZE-1:0]                       radm_timeout_cpl_tag
   ,input logic [2:0]                                    radm_timeout_cpl_tc
   ,input logic [`CX_NFUNC_WD-1:0]                       radm_timeout_func_num
   // Clock & Reset
   ,output logic                                         slv_aclk_g
   ,output logic                                         slv_aresetn
   ,input logic                                          slv_aclk
   ,output logic                                         slv_rasdp_err_mode
   // AXI slave Write address channel
   ,input logic [`SLAVE_BUS_ADDR_WIDTH -1:0]             slv_awaddr
   ,input logic [`CC_SLV_AW_USER_WIDTH-1:0]              slv_awuser
   ,input logic [1:0]                                    slv_awburst
   ,input logic [3:0]                                    slv_awcache
   ,input logic [`CC_SLV_BUS_ID_WIDTH -1:0]              slv_awid
   ,input logic [`CC_SLV_BURST_LEN_PW -1:0]              slv_awlen 
   ,input logic [`CC_AXI_LOCK_WIDTH-1:0]                 slv_awlock

//ccx_tgl: ; slv_awmisc_info[24:22]; ; Function numbering of the TLP. 


   ,input logic [`SLV_MISC_INFO_PW -1:0]                 slv_awmisc_info
   ,input logic [63:0]                                   slv_awmisc_info_hdr_34dw
   ,input logic                                          slv_awmisc_info_nw
   ,input logic [1:0]                                    slv_awmisc_info_ats
   ,input logic [`CX_AXI_PRFX_WIDTH-1:0]                 slv_awmisc_info_tlpprfx
   ,input logic [`CX_TAG_SIZE-1:0]                       slv_awmisc_info_p_tag
   ,input logic [`CX_MISC_INFO_TPH_WD-1:0]               slv_awmisc_info_tph
   ,input logic                                          slv_awmisc_info_atu_bypass
   ,input logic                                          slv_awmisc_info_ido
   ,input logic [8:0]                                    slv_awmisc_info_dst_segment
   ,input logic [2:0]                                    slv_awprot
   ,input logic [2:0]                                    slv_awsize
   ,input logic                                          slv_awvalid
   ,input logic [3:0]                                    slv_awqos
   //ccx_tgl: ; slv_awbar[1:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields
   ,input logic [1:0]                                    slv_awbar
   ,input logic [1:0]                                    slv_awdomain
   //ccx_tgl: ; slv_awsnoop[3:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields
   ,input logic [`CC_AXIJ_DMWR_VALUE *2+2:0]             slv_awsnoop
   //ccx_tgl: ; slv_awatop[2:1]; ; Not supported, we only support AtomicSwap, AtomicCompare and AtomicStore (Operation -> ADD)
   ,input logic [5:0]                                    slv_awatop


   // AXI slave Write data channel
   ,input logic [`SLAVE_BUS_DATA_WIDTH -1:0]             slv_wdata
   ,input logic [`CC_SLV_W_USER_WIDTH-1:0]               slv_wuser
   ,input logic                                          slv_wlast
   ,input logic [`CC_SLV_BUS_WSTRB_WIDTH -1:0]           slv_wstrb
   ,input logic                                          slv_wvalid
   ,input logic                                          slv_wmisc_info_ep
   ,input logic                                          slv_wmisc_info_silentDrop

 
   // AXI slave Write response channel
   ,input logic                                          slv_bready

   // AXI slave Read address channel
   ,input logic [`SLAVE_BUS_ADDR_WIDTH -1:0]             slv_araddr
   ,input logic [`CC_SLV_AR_USER_WIDTH-1:0]              slv_aruser
   ,input logic [1:0]                                    slv_arburst
   //ccx_tgl: ; slv_arcache; ; Cache is not supported
   ,input logic [3:0]                                    slv_arcache
   ,input logic [`CC_SLV_BUS_ID_WIDTH -1:0]              slv_arid
   ,input logic [`CC_SLV_BURST_LEN_PW -1:0]              slv_arlen
   //ccx_tgl: ; slv_arlock; ; Locked transactions not supported
   ,input logic [`CC_AXI_LOCK_WIDTH-1:0]                 slv_arlock
   //ccx_tgl: ; slv_armisc_info[20]; ; There is no valid message code with MSB=1


//ccx_tgl: ; slv_armisc_info[24:22]; ; Function numbering of the TLP. 


   ,input logic [`SLV_MISC_INFO_PW -1:0]                 slv_armisc_info
   ,input logic                                          slv_armisc_info_nw
   ,input logic [1:0]                                    slv_armisc_info_ats
   ,input logic [`CX_AXI_PRFX_WIDTH-1:0]                 slv_armisc_info_tlpprfx
   ,input logic [`CX_MISC_INFO_TPH_WD-1:0]               slv_armisc_info_tph
   ,input logic                                          slv_armisc_info_atu_bypass
   ,input logic                                          slv_armisc_info_ido
   ,input logic [8:0]                                    slv_armisc_info_dst_segment
   ,input logic [2:0]                                    slv_arprot
   ,input logic [2:0]                                    slv_arsize
   ,input logic                                          slv_arvalid
   ,input logic [3:0]                                    slv_arqos
   //ccx_tgl: ; slv_arbar[1:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields.
   ,input logic [1:0]                                    slv_arbar
   ,input logic [1:0]                                    slv_ardomain
   //ccx_tgl: ; slv_arsnoop[3:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields.
   ,input logic [3:0]                                    slv_arsnoop


   // AXI slave Read data channel
   ,input logic                                          slv_rready

   // AXI slave Low-power Channel
   ,input logic                                          slv_csysreq
   ,input logic [`CX_DEVNUM_WD-1:0]                      cfg_pbus_dev_num
   ,input logic [`CX_BUSNUM_WD-1:0]                      cfg_pbus_num
   ,input logic [7:0]                                    cfg_subbus_num
   ,input logic [7:0]                                    cfg_2ndbus_num
   ,input logic [15:0]                                   cfg_err_resp

   ,input logic [`CX_NVC-1:0]                            radm_trgt1_cpl_lookup_id_rlsd
   ,input logic                                          radm_trgt1_lookup_id_consmd


   ,output xali_pkt_t[`N_XALI_IF-1:0]                     xali_xaim_pkt
   ,input logic[`N_XALI_IF-1:0]                           xaim_xali_halt
   ,output logic                             crgb_cdm_ack
   ,output logic [`CC_CRGB_DATA_WIDTH-1:0]   crgb_cdm_rdata


//ccx_tgl: ; dbi_addr[18:16]; ; This bits depend on the number of functions, when the No. of funtions is 1 this bits wont toggle. 


   //ccx_tgl: ; dbi_addr[1:0]; ; The DBI address must be a DWORD address (*addr[1:0] =2b00)
   ,output logic [31:0]                                  dbi_addr
   ,output logic [31:0]                                  dbi_din
   ,output logic                                         dbi_cs
   ,output logic                                         dbi_cs2
   ,output logic [3:0]                                   dbi_wr
   ,output logic [2:0]                                   dbi_bar_num
   //ccx_tgl: ; dbi_func_num; ; When the CX_NFUNC parameter equals 1 this signal won't toggle.


//ccx_tgl: ; dbi_func_num[3:1]; ; The number of functions is controled by the CX_NFUNC parameter.

   ,output logic [`CX_NFUNC_WD-1:0]                      dbi_func_num
   ,output logic                                         dbi_io_access
   ,output logic                                         dbi_rom_access


   ,output logic [`CC_NUM_DMA_WR_CHAN+`CC_NUM_DMA_RD_CHAN-1:0] edma_int
   ,output logic                                         edma_xfer_pending
   // AXI master write request
   ,output logic [`MASTER_BUS_ADDR_WIDTH -1:0]           mstr_awaddr
   ,output logic [`CC_MSTR_AW_USER_WIDTH-1:0]            mstr_awuser
   //ccx_tgl: ; mstr_awburst; ; Only INCR transactions are supported
   ,output logic [1:0]                                   mstr_awburst
   ,output logic [3:0]                                   mstr_awcache
   ,output logic [`CC_MSTR_BUS_ID_WIDTH -1:0]            mstr_awid
   ,output logic [`CC_MSTR_BURST_LEN_PW -1:0]            mstr_awlen
   //ccx_tgl: ; mstr_awlock; ; Locked transactions not supported
   ,output logic [`CC_AXI_LOCK_WIDTH-1:0]                mstr_awlock

//ccx_tgl: ; mstr_awmisc_info[13:11]; ; The number of functions is controled by the CX_NFUNC parameter.


   //ccx_tgl: ; mstr_awmisc_info[22]; ; No completions on AW-Channel
   ,output logic [`MSTR_MISC_INFO_PW -1:0]               mstr_awmisc_info
   ,output logic                                         mstr_awmisc_info_last_dcmp_tlp
   ,output logic [63:0]                                  mstr_awmisc_info_hdr_34dw
   ,output logic                                         mstr_awmisc_info_nw
   //ccx_tgl: ; mstr_awmisc_info_cxlsrc; ; This signal is tied to zero for DTI Version 1.
   ,output logic                                         mstr_awmisc_info_cxlsrc
   ,output logic [1:0]                                   mstr_awmisc_info_ats
   ,output logic                                         mstr_awmisc_info_ep
   //ccx_tgl: ; mstr_awmisc_info_dma[2]; ; DMA never issue LL accesses on AW-Channel
   ,output logic [`CC_NUM_DMA_RD_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_awmisc_info_dma
   ,output logic [`CX_AXI_PRFX_WIDTH-1:0]                mstr_awmisc_info_tlpprfx
   ,output logic [`CX_MISC_INFO_TPH_WD-1:0]              mstr_awmisc_info_tph
   ,output logic                                         mstr_awmisc_info_ido
   ,output logic [8:0]                                   mstr_awmisc_info_dst_segment
   ,output logic [8:0]                                   mstr_awmisc_info_req_segment
   //ccx_tgl: ; mstr_awprot; ; Transactions protection not supported
   ,output logic [2:0]                                   mstr_awprot



//ccx_tgl: ; mstr_awsize[0]; ; Uses Full Size method for executing Narrow Inbound Writes at AXI Master Interface.







   ,output logic [2:0]                                   mstr_awsize
   ,output logic                                         mstr_awvalid


   // AXI master write data
   ,output logic [`MASTER_BUS_DATA_WIDTH -1:0]           mstr_wdata
   ,output logic [`CC_MSTR_W_USER_WIDTH-1:0]             mstr_wuser
   ,output logic                                         mstr_wlast
   ,output logic [`CC_MSTR_BUS_WSTRB_WIDTH -1:0]         mstr_wstrb
   ,output logic                                         mstr_wvalid



   // AXI master write response
   //ccx_tgl: ; mstr_bready; ; Missing stimulus, refer JIRA P80001562-415476.
   ,output logic                                         mstr_bready

   // AXI master read request
   ,output logic [`MASTER_BUS_ADDR_WIDTH -1:0]           mstr_araddr
   ,output logic [`CC_MSTR_AR_USER_WIDTH-1:0]            mstr_aruser
   //ccx_tgl: ; mstr_arburst[1]; ; AXI master interface of the controller generates only INCR Bursts.
   ,output logic [1:0]                                   mstr_arburst
   ,output logic [3:0]                                   mstr_arcache
   ,output logic [`CC_MSTR_BUS_ID_WIDTH -1:0]            mstr_arid

//ccx_tgl: ; mstr_arlen[8:3]; ; The maximum burst length of an AXI transfer at the master interface is 3


   ,output logic [`CC_MSTR_BURST_LEN_PW -1:0]            mstr_arlen
   //ccx_tgl: ; mstr_arlock; ; indicates whether the transfer is a normal; exclusive; or locked access. The controller does not use this signal and sets all bits inactive
   ,output logic [`CC_AXI_LOCK_WIDTH-1:0]                mstr_arlock
   //ccx_tgl: ; mstr_armisc_info[5:0]; ; Reserved field
   //ccx_tgl: ; mstr_armisc_info[23]; ; No Message Request types (Writes) on AR-Channel
    //ccx_tgl: ; mstr_armisc_info[22]; ; No completions on AR-Channel


//ccx_tgl: ; mstr_armisc_info[13:11]; ; The number of functions is controled by the CX_NFUNC parameter.


   ,output logic [`MSTR_MISC_INFO_PW -1:0]               mstr_armisc_info
   ,output logic                                         mstr_armisc_info_last_dcmp_tlp
   ,output logic                                         mstr_armisc_info_nw
   //ccx_tgl: ; mstr_armisc_info_cxlsrc; ; This signal is tied to zero for DTI Version 1.
   ,output logic                                         mstr_armisc_info_cxlsrc
   ,output logic [1:0]                                   mstr_armisc_info_ats
   ,output logic [`CC_NUM_DMA_MAX_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_armisc_info_dma
   ,output logic [`CX_AXI_PRFX_WIDTH-1:0]                mstr_armisc_info_tlpprfx
   ,output logic [`CX_MISC_INFO_TPH_WD-1:0]              mstr_armisc_info_tph
   ,output logic                                         mstr_armisc_info_ido
   ,output logic                                         mstr_armisc_info_zeroread
   ,output logic                                  [8:0] mstr_armisc_info_dst_segment
   ,output logic                                  [8:0] mstr_armisc_info_req_segment
   //ccx_tgl: ; mstr_arprot[2:0]; ; Indicates unprivileged; non-secure; or data protection access level. The controller assigns this signal a value of 010.
   ,output logic [2:0]                                   mstr_arprot




//ccx_tgl: ; mstr_arsize[0]; ; Uses Approximate Full Size method for executing Narrow Inbound Reads at AXI Master Interface.







   ,output logic [2:0]                                   mstr_arsize
   ,output logic                                         mstr_arvalid


   // AXI master read response & read data
   ,output logic                                         mstr_rready

   //ccx_tgl: ; mstr_awqos; ; No AXI QoS supported
   ,output logic [3:0]                                   mstr_awqos
   ,output logic [1:0]                                   mstr_awbar
   ,output logic [1:0]                                   mstr_awdomain
   ,output logic [`CC_AXIJ_DMWR_VALUE *2+2:0]            mstr_awsnoop
   ,output logic [5:0]                                   mstr_awatop
   //ccx_tgl: ; mstr_arqos; ; No AXI QoS supported
   ,output logic [3:0]                                   mstr_arqos
   ,output logic [1:0]                                   mstr_arbar
   ,output logic [1:0]                                   mstr_ardomain
   ,output logic [3:0]                                   mstr_arsnoop

   // AXI master low power
   //ccx_tgl: ; mstr_csysack; ; AXI Low Power Interface not used
   //ccx_tgl: ; mstr_cactive; ; AXI Low Power Interface not used
   ,output logic                                         mstr_cactive
   ,output logic                                         mstr_csysack
   // AXI slave Write address channel
   ,output logic                                         slv_awready

   // AXI slave Write data channel
   ,output logic                                         slv_wready

   // AXI slave Write response channel
   ,output logic [`CC_SLV_BUS_ID_WIDTH -1:0]             slv_bid
   ,output logic [`SLV_RESP_MISC_INFO_PW -1:0]           slv_bmisc_info
   ,output logic [8:0]                                   slv_bmisc_info_dst_segment
   ,output logic [7:0]                                   slv_bmisc_info_cpl_segment
   ,output logic [`CC_AXIJ_DMWR_VALUE+1:0]               slv_bresp
   ,output logic                                         slv_bvalid


   // AXI slave Read address channel
   ,output logic                                         slv_arready

   // AXI slave Read data channel
   ,output logic [`SLAVE_BUS_DATA_WIDTH -1:0]            slv_rdata
   ,output logic [`CC_SLV_R_USER_WIDTH-1:0]              slv_ruser
   ,output logic [`CC_SLV_BUS_ID_WIDTH -1:0]             slv_rid
   ,output logic                                         slv_rlast
   ,output logic [`SLV_RESP_MISC_INFO_PW -1:0]           slv_rmisc_info
   ,output logic                                         slv_rmisc_info_ido
   ,output logic [8:0]                                   slv_rmisc_info_dst_segment
   ,output logic [7:0]                                   slv_rmisc_info_cpl_segment
   ,output logic [1:0]                                   slv_rresp
   ,output logic                                         slv_rvalid


   // AXI slave Low-power Channel
   ,output logic                                         slv_cactive
   ,output logic                                         slv_csysack
   ,output logic                                         brdg_mstr_xfer_pending
   ,input logic                                          trgt_cpl_lut_empty
   ,output logic                                         brdg_slv_xfer_pending
   ,input logic                                          app_xfer_pending
   ,output logic                                         brdg_dbi_xfer_pending
   ,input logic                                          rstctl_slv_flush_req
   ,input logic                                          rstctl_mstr_flush_req
   ,output logic                                         brdg_slv_flush_ack
  // External RAM interfaces
  // Inbound
  // Inbound Read Request Clock Domain Crossing FIFO RAM
   ,output logic [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     ib_rreq_c2a_cdc_ram_addra
   ,output logic                                         ib_rreq_c2a_cdc_ram_wea
   //ccx_tgl: ; ib_rreq_c2a_cdc_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]     ib_rreq_c2a_cdc_ram_dina
   ,output logic [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     ib_rreq_c2a_cdc_ram_addrb
   ,output logic                                         ib_rreq_c2a_cdc_ram_enb
   ,input logic [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]     ib_rreq_c2a_cdc_ram_doutb
 // Inbound Write Request Clock Domain Crossing FIFO RAM
   ,output logic [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     ib_wreq_c2a_cdc_ram_addra
   ,output logic                                         ib_wreq_c2a_cdc_ram_wea
   //ccx_tgl: ; ib_wreq_c2a_cdc_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]     ib_wreq_c2a_cdc_ram_dina
   ,output logic [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     ib_wreq_c2a_cdc_ram_addrb
   ,output logic                                         ib_wreq_c2a_cdc_ram_enb
   ,input logic [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]     ib_wreq_c2a_cdc_ram_doutb
  // Inbound Master Completion Clock Domain Crossing FIFO RAM
   ,output logic [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       ib_mcpl_a2c_cdc_ram_addra
   ,output logic                                         ib_mcpl_a2c_cdc_ram_wea
   //ccx_tgl: ; ib_mcpl_a2c_cdc_ram_dina[33]; ; Randomization of access to the RAM.
   //ccx_tgl: ; ib_mcpl_a2c_cdc_ram_dina[38]; ; Randomization of access to the RAM.
   ,output logic [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]       ib_mcpl_a2c_cdc_ram_dina
   ,output logic [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       ib_mcpl_a2c_cdc_ram_addrb
   ,output logic                                         ib_mcpl_a2c_cdc_ram_enb
   ,input logic [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]       ib_mcpl_a2c_cdc_ram_doutb

  // Inbound Master Completion Data Segment FIFO RAM
    // Master completion buffer segment buffer RAM outputs
   ,output logic [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]          ib_mcpl_sb_ram_addra
   ,output logic                                                ib_mcpl_sb_ram_wea
   //ccx_tgl: ; ib_mcpl_sb_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]          ib_mcpl_sb_ram_dina
   ,output logic [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]          ib_mcpl_sb_ram_addrb
   ,output logic                                                ib_mcpl_sb_ram_enb
   ,input logic [`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]           ib_mcpl_sb_ram_doutb
   ,output logic                                                ib_scheduler_p_hdr_ram_wea
   ,output logic [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addra
   //ccx_tgl: ; ib_scheduler_p_hdr_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_dina
   ,output logic [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addrb
   ,output logic                                                ib_scheduler_p_hdr_ram_enb
   ,input logic [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]        ib_scheduler_p_hdr_ram_doutb

   ,output logic                                                ib_scheduler_p_data_ram_wea
   ,output logic [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addra
   ,output logic [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_dina
   ,output logic [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addrb
   ,output logic                                                ib_scheduler_p_data_ram_enb
   ,input logic [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]       ib_scheduler_p_data_ram_doutb

   ,output logic                                                ib_scheduler_np_hdr_ram_wea
   ,output logic [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addra
   //ccx_tgl: ; ib_scheduler_np_hdr_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_dina
   ,output logic [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addrb
   ,output logic                                                ib_scheduler_np_hdr_ram_enb
   ,input logic [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]       ib_scheduler_np_hdr_ram_doutb

   ,output logic                                                ib_scheduler_np_data_ram_wea
   ,output logic [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addra
   ,output logic [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_dina
   ,output logic [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addrb
   ,output logic                                                ib_scheduler_np_data_ram_enb
   ,input logic [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]      ib_scheduler_np_data_ram_doutb
 
  // Outbound
  // Slave Non-Posted Write Set-Aside RAM
   ,output logic [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]       slv_npw_sab_ram_addra
   ,output logic                                         slv_npw_sab_ram_wea
   //ccx_tgl: ; slv_npw_sab_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]       slv_npw_sab_ram_dina
   ,output logic [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]       slv_npw_sab_ram_addrb
   ,output logic                                         slv_npw_sab_ram_enb
   ,input logic [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]       slv_npw_sab_ram_doutb
  // Outbound Posted/Non-Posted TLP Decomposer FIFO RAM
   ,output logic [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]         ob_npdcmp_ram_addra
   ,output logic                                         ob_npdcmp_ram_wea
   //ccx_tgl: ; ob_npdcmp_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]         ob_npdcmp_ram_dina
   ,output logic [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]         ob_npdcmp_ram_addrb
   ,output logic                                         ob_npdcmp_ram_enb
   ,input logic [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]         ob_npdcmp_ram_doutb
  // Outbound Posted TLP Decomposer Header FIFO RAM
   ,output logic [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      ob_pdcmp_hdr_ram_addra
   ,output logic                                         ob_pdcmp_hdr_ram_wea
   //ccx_tgl: ; ob_pdcmp_hdr_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]      ob_pdcmp_hdr_ram_dina
   ,output logic [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      ob_pdcmp_hdr_ram_addrb
   ,output logic                                         ob_pdcmp_hdr_ram_enb
   ,input logic [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]      ob_pdcmp_hdr_ram_doutb
 // Outbound Posted TLP Decomposer Data FIFO RAM
   ,output logic [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     ob_pdcmp_data_ram_addra
   ,output logic                                         ob_pdcmp_data_ram_wea
   ,output logic [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]     ob_pdcmp_data_ram_dina
   ,output logic [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     ob_pdcmp_data_ram_addrb
   ,output logic                                         ob_pdcmp_data_ram_enb
   ,input logic [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]     ob_pdcmp_data_ram_doutb
   ,output logic [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      ob_ccmp_data_ram_addra
   ,output logic                                         ob_ccmp_data_ram_wea
   //ccx_tgl: ; ob_ccmp_data_ram_dina; ; Randomization of access to the RAM.
   ,output logic [`CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]      ob_ccmp_data_ram_dina
   ,output logic [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      ob_ccmp_data_ram_addrb
   ,output logic                                         ob_ccmp_data_ram_enb
   ,input logic [`CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]      ob_ccmp_data_ram_doutb
  // Read buffer
   ,output logic [`CX_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]     edmarbuff2ram_addra
   ,output logic [`CX_DMA_RBUF_NSLICES-1:0]                                   edmarbuff2ram_we
   ,output logic [`CX_DMA_RBUF_NSLICES*`CX_DMA_RBUF_SLICE_WD-1:0]               edmarbuff2ram_dout
   ,output logic [`CX_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]     edmarbuff2ram_addrb
   ,output logic [`CX_DMA_RBUF_NSLICES-1:0]                                   edmarbuff2ram_re
   ,input logic [`CX_DMA_RBUF_NSLICES*`CX_DMA_RBUF_SLICE_WD-1:0]               ram2edmarbuff_din
  // RD Engine Linked List Pointers
   ,output logic           [`CC_IF_RDCTRL_LL_RAM_PW-1:0] edma_rd_eng_ll_addra_ram
   ,output logic           [`CC_IF_RDCTRL_LL_RAM_PW-1:0] edma_rd_eng_ll_addrb_ram
   //ccx_tgl: ; edma_rd_eng_ll_dout_ram; ; Randomization of access to the RAM.
   ,output logic           [`CC_IF_RDCTRL_LL_RAM_WD-1:0] edma_rd_eng_ll_dout_ram
   ,output logic                                         edma_rd_eng_ll_we_ram
   ,output logic                                         edma_rd_eng_ll_re_ram
   ,input logic           [`CC_IF_RDCTRL_LL_RAM_WD-1:0] edma_rd_eng_ll_din_ram
  // WR Engine Linked List Pointers
   ,output logic           [`CC_IF_WRCTRL_LL_RAM_PW-1:0] edma_wr_eng_ll_addra_ram
   ,output logic           [`CC_IF_WRCTRL_LL_RAM_PW-1:0] edma_wr_eng_ll_addrb_ram
   //ccx_tgl: ; edma_wr_eng_ll_dout_ram; ; Randomization of access to the RAM.
   ,output logic           [`CC_IF_WRCTRL_LL_RAM_WD-1:0] edma_wr_eng_ll_dout_ram
   ,output logic                                         edma_wr_eng_ll_we_ram
   ,output logic                                         edma_wr_eng_ll_re_ram
   ,input logic           [`CC_IF_WRCTRL_LL_RAM_WD-1:0] edma_wr_eng_ll_din_ram
  // RD Engine Descriptors Queue
   ,output logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_rd_eng_ovrl_addra_ram
   ,output logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_rd_eng_ovrl_addrb_ram
   //ccx_tgl: ; edma_rd_eng_ovrl_dout_ram; ; Randomization of access to the RAM.
   ,output logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_rd_eng_ovrl_dout_ram
   ,output logic                                         edma_rd_eng_ovrl_we_ram
   ,output logic                                         edma_rd_eng_ovrl_re_ram
   ,input logic   [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_rd_eng_ovrl_din_ram
  // WR Engine Descriptors Queue
   ,output logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_wr_eng_ovrl_addra_ram
   ,output logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_wr_eng_ovrl_addrb_ram
   //ccx_tgl: ; edma_wr_eng_ovrl_dout_ram; ; Randomization of access to the RAM.
   ,output logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_wr_eng_ovrl_dout_ram
   ,output logic                                         edma_wr_eng_ovrl_we_ram
   ,output logic                                         edma_wr_eng_ovrl_re_ram
   ,input logic   [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_wr_eng_ovrl_din_ram
  // RD Engine Completion to Memory Write LUT
   ,output logic           [`CC_IF_RD_CTXC2W_RAM_PW-1:0] edma_rd_eng_c2w_lut_addra_ram
   ,output logic           [`CC_IF_RD_CTXC2W_RAM_PW-1:0] edma_rd_eng_c2w_lut_addrb_ram
   //ccx_tgl: ; edma_rd_eng_c2w_lut_dout_ram; ; Randomization of access to the RAM.
   ,output logic           [`CC_IF_RD_CTXC2W_RAM_WD-1:0] edma_rd_eng_c2w_lut_dout_ram
   ,output logic                                         edma_rd_eng_c2w_lut_we_ram
   ,output logic                                         edma_rd_eng_c2w_lut_re_ram
   ,input logic           [`CC_IF_RD_CTXC2W_RAM_WD-1:0] edma_rd_eng_c2w_lut_din_ram
  // WR Engine Completion to Memory Write LUT
   ,output logic           [`CC_IF_WR_CTXC2W_RAM_PW-1:0] edma_wr_eng_c2w_lut_addra_ram
   ,output logic           [`CC_IF_WR_CTXC2W_RAM_PW-1:0] edma_wr_eng_c2w_lut_addrb_ram
   //ccx_tgl: ; edma_wr_eng_c2w_lut_dout_ram; ; Randomization of access to the RAM.
   ,output logic           [`CC_IF_WR_CTXC2W_RAM_WD-1:0] edma_wr_eng_c2w_lut_dout_ram
   ,output logic                                         edma_wr_eng_c2w_lut_we_ram
   ,output logic                                         edma_wr_eng_c2w_lut_re_ram
   ,input logic           [`CC_IF_WR_CTXC2W_RAM_WD-1:0] edma_wr_eng_c2w_lut_din_ram
  // RD Engine Status Handler LUT
   ,output logic          [`CC_IF_RD_CTXSTSH_RAM_PW-1:0] edma_rd_eng_stsh_lut_addra_ram
   ,output logic          [`CC_IF_RD_CTXSTSH_RAM_PW-1:0] edma_rd_eng_stsh_lut_addrb_ram
   //ccx_tgl: ; edma_rd_eng_stsh_lut_dout_ram; ; Randomization of access to the RAM.
   ,output logic          [`CC_IF_RD_CTXSTSH_RAM_WD-1:0] edma_rd_eng_stsh_lut_dout_ram
   ,output logic                                         edma_rd_eng_stsh_lut_we_ram
   ,output logic                                         edma_rd_eng_stsh_lut_re_ram
   ,input logic          [`CC_IF_RD_CTXSTSH_RAM_WD-1:0] edma_rd_eng_stsh_lut_din_ram
  // WR Engine Status Handler LUT
   ,output logic          [`CC_IF_WR_CTXSTSH_RAM_PW-1:0] edma_wr_eng_stsh_lut_addra_ram
   ,output logic          [`CC_IF_WR_CTXSTSH_RAM_PW-1:0] edma_wr_eng_stsh_lut_addrb_ram
   //ccx_tgl: ; edma_wr_eng_stsh_lut_dout_ram; ; Randomization of access to the RAM.
   ,output logic          [`CC_IF_WR_CTXSTSH_RAM_WD-1:0] edma_wr_eng_stsh_lut_dout_ram
   ,output logic                                         edma_wr_eng_stsh_lut_we_ram
   ,output logic                                         edma_wr_eng_stsh_lut_re_ram
   ,input logic          [`CC_IF_WR_CTXSTSH_RAM_WD-1:0] edma_wr_eng_stsh_lut_din_ram
  // RD Engine MSI Pointers
   ,output logic              [`CC_IF_RD_MSI_RAM_PW-1:0] edma_rd_eng_msi_addra_ram
   ,output logic              [`CC_IF_RD_MSI_RAM_PW-1:0] edma_rd_eng_msi_addrb_ram
   //ccx_tgl: ; edma_rd_eng_msi_dout_ram; ; Randomization of access to the RAM.
   ,output logic              [`CC_IF_RD_MSI_RAM_WD-1:0] edma_rd_eng_msi_dout_ram
   ,output logic                                         edma_rd_eng_msi_we_ram
   ,output logic                                         edma_rd_eng_msi_re_ram
   ,input logic              [`CC_IF_RD_MSI_RAM_WD-1:0] edma_rd_eng_msi_din_ram
  // WR Engine MSI Pointers
   ,output logic              [`CC_IF_WR_MSI_RAM_PW-1:0] edma_wr_eng_msi_addra_ram
   ,output logic              [`CC_IF_WR_MSI_RAM_PW-1:0] edma_wr_eng_msi_addrb_ram
   //ccx_tgl: ; edma_wr_eng_msi_dout_ram; ; Randomization of access to the RAM.
   ,output logic              [`CC_IF_WR_MSI_RAM_WD-1:0] edma_wr_eng_msi_dout_ram
   ,output logic                                         edma_wr_eng_msi_we_ram
   ,output logic                                         edma_wr_eng_msi_re_ram
   ,input logic              [`CC_IF_WR_MSI_RAM_WD-1:0] edma_wr_eng_msi_din_ram
   ,input  logic                                        edma_rd_eng_hard_stop_req
   ,input  logic        [`CC_NUM_DMA_RD_CHAN_WIDTH-1:0] edma_rd_eng_hard_stop_channel
   ,output logic                                        edma_rd_eng_hard_stop_ack  
   ,input  logic                                        edma_wr_eng_hard_stop_req
   ,input  logic        [`CC_NUM_DMA_WR_CHAN_WIDTH-1:0] edma_wr_eng_hard_stop_channel
   ,output logic                                        edma_wr_eng_hard_stop_ack     
   // Completions Status during DPC
   ,input logic                                                 core_in_dpc_i
   ,input logic                                                 cfg_dpc_cpl_cntrl_i

); //DWC_pcie_app_layer

// ------------------------------------------------------------------------------------------
// MACROS
// ------------------------------------------------------------------------------------------
`define AMBA_TOP DWC_pcie_edma_amba_bridge
      `define AMBA_INST u_DWC_pcie_edma_axi_bridge

   //--------------------------------------
   // INTERNAL SIGNALS DECLARATION
   //--------------------------------------

localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs
// BCM36_NHS for quasi static device_type input
   logic [3:0] s_device_type;
   
   DWC_pcie_ctl_bcm36_nhs
    #(
     .WIDTH      ( $bits(device_type)   ),
     .DATA_DELAY ( DATA_DELAY_BCM36_NHS )
   ) u_bcm36_nhs_device_type (
  `ifndef SYNTHESIS
     .clk_d   ( aux_clk_g     ),
     .rst_d_n ( core_rst_n    ),
  `endif // SYNTHESIS
     .data_s  ( device_type   ),
     .data_d  ( s_device_type )
   );           

   logic s_cfg_10b_tag_en;
    assign s_cfg_10b_tag_en = (s_device_type == `PCIE_RC) ? cfg_10b_tag_en[0] : (|cfg_10b_tag_en);




   //CRGB DMA interface
   logic [`CC_CRGB_ADDR_WIDTH-1:0] crgb_address;
   logic                           crgb_rden;
   logic                           crgb_source;
   logic [`CC_CRGB_DATA_WIDTH-1:0] crgb_wr_data;
   logic                           crgb_wren;
   logic                           crgb_ack;
   logic [`CC_CRGB_DATA_WIDTH-1:0] crgb_rd_data;


// RAS ECC RAM interface
logic                                          cfg_ras_recc_npw_sab_correct;
logic                                          axi_ras_recc_corr_cnt_npw_sab_pulse;
logic [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]        axi_ras_recc_corr_cnt_npw_sab_addr;
logic                                          axi_ras_recc_ucorr_cnt_npw_sab_pulse;
logic [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]        axi_ras_recc_ucorr_cnt_npw_sab_addr;
// ras_prot_t_disable[2]: Error protection disable - AXI bridge Outbound Request
// ras_prot_t_disable[0]: Error protection disable - transmit (all layers)
assign cfg_ras_recc_npw_sab_correct = ~ (ras_prot_t_disable[2] |  ras_prot_t_disable[0]);

logic                                          cfg_ras_recc_ob_npdcmp_correct;
logic                                          axi_ras_recc_corr_cnt_ob_npdcmp_pulse;
logic [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]          axi_ras_recc_corr_cnt_ob_npdcmp_addr;
logic                                          axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse;
logic [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]          axi_ras_recc_ucorr_cnt_ob_npdcmp_addr;
// ras_prot_t_disable[2]: Error protection disable - AXI bridge Outbound Request
// ras_prot_t_disable[0]: Error protection disable - transmit (all layers)
assign cfg_ras_recc_ob_npdcmp_correct  = ~ (ras_prot_t_disable[2] |  ras_prot_t_disable[0]);

logic                                          cfg_ras_recc_ob_pdcmp_hdr_correct;
logic                                          axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse;
logic [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr;
logic                                          axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse;
logic [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr;
// ras_prot_t_disable[2]: Error protection disable - AXI bridge Outbound Request
// ras_prot_t_disable[0]: Error protection disable - transmit (all layers)
assign cfg_ras_recc_ob_pdcmp_hdr_correct  = ~ (ras_prot_t_disable[2] |  ras_prot_t_disable[0]);

logic                                          cfg_ras_recc_ob_pdcmp_data_correct;
logic                                          axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse;
logic [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]      axi_ras_recc_corr_cnt_ob_pdcmp_data_addr;
logic                                          axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse;
logic [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]      axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr;
// ras_prot_t_disable[2]: Error protection disable - AXI bridge Outbound Request
// ras_prot_t_disable[0]: Error protection disable - transmit (all layers)
assign cfg_ras_recc_ob_pdcmp_data_correct  = ~ (ras_prot_t_disable[2] |  ras_prot_t_disable[0]);

logic                                          cfg_ras_recc_ob_ccmp_data_correct;
logic                                          axi_ras_recc_corr_cnt_ob_ccmp_data_pulse;
logic [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ob_ccmp_data_addr;
logic                                          axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse;
logic [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr;
// ras_prot_r_disable[1]: Error protection disable - AXI bridge Inbound Completion
// ras_prot_r_disable[0]: Error protection disable - receive (all layers)
assign cfg_ras_recc_ob_ccmp_data_correct = ~(ras_prot_r_disable[1] | ras_prot_r_disable[0]);

logic                                           cfg_ras_recc_ib_sch_p_hdr_correct;
logic                                           axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse;
logic [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr;
logic                                           axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse;
logic [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr;
assign cfg_ras_recc_ib_sch_p_hdr_correct = ~(ras_prot_r_disable[2] | ras_prot_r_disable[0]);

logic                                           cfg_ras_recc_ib_sch_p_data_correct;
logic                                           axi_ras_recc_corr_cnt_ib_sch_p_data_pulse;
logic [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_p_data_addr;
logic                                           axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse;
logic [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr;
assign cfg_ras_recc_ib_sch_p_data_correct = ~(ras_prot_r_disable[2] | ras_prot_r_disable[0]);

logic                                           cfg_ras_recc_ib_sch_np_hdr_correct;
logic                                           axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse;
logic [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr;
logic                                           axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse;
logic [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr;
assign cfg_ras_recc_ib_sch_np_hdr_correct = ~(ras_prot_r_disable[2] | ras_prot_r_disable[0]);

logic                                           cfg_ras_recc_ib_sch_np_data_correct;
logic                                           axi_ras_recc_corr_cnt_ib_sch_np_data_pulse;
logic [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_corr_cnt_ib_sch_np_data_addr;
logic                                           axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse;
logic [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr;

logic                                           axi_ras_par_rtrgt_p_ad_pulse;
logic                                           axi_ras_par_rtrgt_p_dt_pulse;
logic                                           axi_ras_par_rtrgt_np_ad_pulse;
logic                                           axi_ras_par_rtrgt_np_dt_pulse;
logic                                           axi_ras_par_rtrgt_cpl_ad_pulse;
logic                                           axi_ras_par_rtrgt_cpl_dt_pulse;

assign cfg_ras_recc_ib_sch_np_data_correct = ~(ras_prot_r_disable[2] | ras_prot_r_disable[0]);
logic                                          cfg_ras_recc_ib_rreq_c2a_cdc_correct;
logic                                          axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse;
logic [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]      axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr;
logic                                          axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse;
logic [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]      axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr;
// ras_prot_r_disable[2]: Error protection disable - AXI bridge Inbound Request
// ras_prot_r_disable[0]: Error protection disable - receive (all layers)
assign cfg_ras_recc_ib_rreq_c2a_cdc_correct = ~(ras_prot_r_disable[2] | ras_prot_r_disable[0]);


logic                                          cfg_ras_recc_ib_wreq_c2a_cdc_correct;
logic                                          axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse;
logic [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]      axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr;
logic                                          axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse;
logic [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]      axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr;
// ras_prot_r_disable[2]: Error protection disable - AXI bridge Inbound Request
// ras_prot_r_disable[0]: Error protection disable - receive (all layers)
assign cfg_ras_recc_ib_wreq_c2a_cdc_correct = ~(ras_prot_r_disable[2] | ras_prot_r_disable[0]);


logic                                          cfg_ras_recc_ib_mcpl_a2c_cdc_correct;
logic                                          axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse;
logic [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]        axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr;
logic                                          axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse;
logic [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]        axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr;


// ras_prot_t_disable[1]: Error protection disable - AXI bridge Master Completion
// ras_prot_t_disable[0]: Error protection disable - transmit (all layers)
assign cfg_ras_recc_ib_mcpl_a2c_cdc_correct = ~(ras_prot_t_disable[1] | ras_prot_t_disable[0]);


logic                                          cfg_ras_recc_ib_mcpl_sb_correct;
logic                                          axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse;
logic [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]    axi_ras_recc_corr_cnt_ib_mcpl_sb_addr;
logic                                          axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse;
logic [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]    axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr;
// ras_prot_t_disable[1]: Error protection disable - AXI bridge Master Completion
// ras_prot_t_disable[0]: Error protection disable - transmit (all layers)
assign cfg_ras_recc_ib_mcpl_sb_correct = ~(ras_prot_t_disable[1] | ras_prot_t_disable[0]);





logic                                          axi_ras_par_ib_mcpl_dt_pulse;



logic                                          axi_ras_par_ibwr_dcmp_dt_pulse;
logic                                          axi_ras_par_ibwr_dcmp_ad_pulse;
logic                                          axi_ras_par_ibrd_dcmp_ad_pulse;

logic                                          axi_ras_par_ib_sch_p_ad_pulse;
logic                                          axi_ras_par_ib_sch_p_dt_pulse;
logic                                          axi_ras_par_ib_sch_np_ad_pulse;
logic                                          axi_ras_par_ib_sch_np_dt_pulse;
logic                                          axi_ras_par_ib_mcpl_a2c_dt_pulse;
logic                                          axi_ras_par_ib_mcpl_sb_dt_pulse;

logic                                          axi_ras_par_ibwq_mrf_dt_pulse;
logic                                          axi_ras_par_ibwq_mrf_ad_pulse;
logic                                          axi_ras_par_ibrd_mrf_ad_pulse;

logic                                          axi_ras_par_npqdec_ad_pulse;

logic                                          axi_ras_par_pqdec_ad_pulse;
logic                                          axi_ras_par_pqdec_dt_pulse;
logic                                          axi_ras_par_swwrap_dt_pulse;
logic                                          axi_ras_par_swwrap_ad_pulse;
logic                                          axi_ras_par_srwrap_ad_pulse;
logic                                          axi_ras_par_swrq_npw_dt_pulse;
logic                                          axi_ras_par_swrq_npw_ad_pulse;

logic                                          axi_ras_par_slnull_dt_pulse;
logic                                          axi_ras_par_slnull_ad_pulse;

logic                                          axi_ras_par_ob_np_dcmp_inq_dt_pulse;
logic                                          axi_ras_par_ob_p_dcmp_inq_dt_pulse;
logic                                          axi_ras_par_ob_cpl_comp_dt_pulse;

logic                                          axi_ras_par_c2_ad_pulse;
logic                                          axi_ras_par_c2_dt_pulse;
logic                                          axi_ras_par_c1_ad_pulse;
logic                                          axi_ras_par_c1_dt_pulse;

logic                                         axi_slv_sisb_uncorr_pulse;
logic                                         axi_mstr_misb_uncorr_pulse;





  //--------------------------------------
  // Enable of the DWC_pcie_axi_clkrst
  //--------------------------------------
  DWC_pcie_axi_clkrst
   u_DWC_pcie_axi_clkrst(
    .test_clk_en           (test_clk_en)
    ,.test_rst_en          (test_rst_en)
    ,.core_rst_n           (core_rst_n)
    ,.mstr_aclk            (mstr_aclk)
    ,.en_mstr_aclk_g       (en_mstr_aclk_g)
    ,.mstr_aclk_g          (mstr_aclk_g)
    ,.mstr_aresetn         (mstr_aresetn) 
    ,.slv_aclk             (slv_aclk)
    ,.en_slv_aclk_g        (en_slv_aclk_g)
    ,.slv_aclk_g           (slv_aclk_g)
    ,.slv_aresetn          (slv_aresetn)
  ); //u_DWC_pcie_axi_clkrst 

   //--------------------------------------
   // CDM-CRGB INSTANCE
   //--------------------------------------

DWC_pcie_edma_cdm_crgb

#(
     .INST (INST)
    ,.ADDR_WIDTH(`CC_CRGB_ADDR_WIDTH)
    ,.DATA_WIDTH(`CC_CRGB_DATA_WIDTH)
    ,.BE_WIDTH(`CC_CRGB_BE_WIDTH)
)
 u_DWC_pcie_edma_cdm_crgb (

     .clk                            ( aux_clk_g    )
    ,.reset_n                        ( core_rst_n   )
    //CRGB _ INTERFACE
    ,.crgb_addr                      ( crgb_address )
    ,.crgb_re                        ( crgb_rden)
    ,.crgb_we                        ( crgb_wren)
    ,.crgb_dout                      ( crgb_wr_data)
    ,.crgb_din                       ( crgb_rd_data)

    ,.crgb_byte_en                   (/*NOT USED*/           )
    ,.crgb_source                    ( crgb_source           )
    ,.crgb_ready                     ( crgb_ack              )

    //CRGB _ INTERFACE
    ,.cdm_cs                         ( crgb_cdm_cs           )
    ,.cdm_ack                        ( crgb_cdm_ack          )
    ,.cdm_addr                       ( crgb_cdm_addr         )
    ,.cdm_datain                     ( crgb_cdm_wdata        )
    ,.cdm_dataout                    ( crgb_cdm_rdata        )

    ,.cdm_wr                         ( crgb_cdm_wr           )
    ,.cdm_source                     ( crgb_cdm_source       )

 ); //DWC_pcie_edma_cdm_crgb

   //--------------------------------------
   // Enable of the axi_core_clk_g
   //--------------------------------------

   //--------------------------------------
   // DMA/BRIDGE INSTANCE
   //--------------------------------------
`AMBA_TOP
 `AMBA_INST (
     .core_rst_n                     ( core_rst_n )
    ,.core_clk                       ( core_clk )
    ,.crgb_address                   ( crgb_address )
    ,.crgb_rden                      ( crgb_rden    )
    ,.crgb_source                    ( crgb_source  )
    ,.crgb_wr_data                   ( crgb_wr_data )
    ,.crgb_wren                      ( crgb_wren    )
    ,.aux_clk_g                      (aux_clk_g)
    ,.aux_clk                        (aux_clk)
    ,.cfg_axi_clk_gating_en          (cfg_axi_clk_gating_en)
    ,.mstr_aclk_g                    (mstr_aclk_g)
    ,.mstr_aresetn                   (mstr_aresetn)
    ,.mstr_aclk                      (mstr_aclk)
    ,.en_mstr_aclk_g                 (en_mstr_aclk_g)
    ,.mstr_rasdp_err_mode            (mstr_rasdp_err_mode)
    ,.mstr_awid                      (mstr_awid)
    ,.mstr_awvalid                   (mstr_awvalid)
    ,.mstr_awaddr                    (mstr_awaddr)
    ,.mstr_awuser                    (mstr_awuser)
    ,.mstr_awlen                     (mstr_awlen)
    ,.mstr_awsize                    (mstr_awsize)
    ,.mstr_awburst                   (mstr_awburst)
    ,.mstr_awlock                    (mstr_awlock)
    ,.mstr_awcache                   (mstr_awcache)
    ,.mstr_awprot                    (mstr_awprot)
    ,.mstr_awready                   (mstr_awready)
    ,.mstr_awmisc_info               (mstr_awmisc_info)
    ,.mstr_awmisc_info_last_dcmp_tlp (mstr_awmisc_info_last_dcmp_tlp)
    ,.mstr_awmisc_info_hdr_34dw      (mstr_awmisc_info_hdr_34dw)
    ,.mstr_awmisc_info_tlpprfx       (mstr_awmisc_info_tlpprfx)
    ,.mstr_awmisc_info_tph           (mstr_awmisc_info_tph)
    ,.mstr_awmisc_info_ido           (mstr_awmisc_info_ido)
    ,.mstr_awmisc_info_dst_segment   (mstr_awmisc_info_dst_segment)
    ,.mstr_awmisc_info_req_segment   (mstr_awmisc_info_req_segment)
    ,.mstr_awmisc_info_dma          (mstr_awmisc_info_dma)
    ,.mstr_awmisc_info_nw            (mstr_awmisc_info_nw)
    ,.mstr_awmisc_info_cxlsrc        (mstr_awmisc_info_cxlsrc)
    ,.mstr_awmisc_info_ats           (mstr_awmisc_info_ats)
    ,.mstr_awmisc_info_ep            (mstr_awmisc_info_ep)
    ,.mstr_awqos                     (mstr_awqos)
    ,.mstr_awbar                     (mstr_awbar)
    ,.mstr_awdomain                  (mstr_awdomain)
    ,.mstr_awsnoop                   (mstr_awsnoop)
    ,.mstr_awatop                    (mstr_awatop)
    ,.mstr_wready                    (mstr_wready)
    ,.mstr_wdata                     (mstr_wdata)
    ,.mstr_wuser                     (mstr_wuser)
    ,.mstr_wstrb                     (mstr_wstrb)
    ,.mstr_wlast                     (mstr_wlast)
    ,.mstr_wvalid                    (mstr_wvalid)
    ,.mstr_bready                    (mstr_bready)
    ,.mstr_bid                       (mstr_bid)
    ,.mstr_bvalid                    (mstr_bvalid)
    ,.mstr_bresp                     (mstr_bresp)
    ,.mstr_bmisc_info_cpl_stat       (mstr_bmisc_info_cpl_stat)
    ,.mstr_arid                      (mstr_arid)
    ,.mstr_arvalid                   (mstr_arvalid)
    ,.mstr_araddr                    (mstr_araddr)
    ,.mstr_aruser                    (mstr_aruser)
    ,.mstr_arlen                     (mstr_arlen)
    ,.mstr_arsize                    (mstr_arsize)
    ,.mstr_arburst                   (mstr_arburst)
    ,.mstr_arlock                    (mstr_arlock)
    ,.mstr_arcache                   (mstr_arcache)
    ,.mstr_arprot                    (mstr_arprot)
    ,.mstr_armisc_info               (mstr_armisc_info)
    ,.mstr_armisc_info_last_dcmp_tlp (mstr_armisc_info_last_dcmp_tlp)
    ,.mstr_armisc_info_tlpprfx       (mstr_armisc_info_tlpprfx)
    ,.mstr_armisc_info_tph           (mstr_armisc_info_tph)
    ,.mstr_armisc_info_ido           (mstr_armisc_info_ido)
    ,.mstr_armisc_info_zeroread      (mstr_armisc_info_zeroread)
    ,.mstr_armisc_info_dma           (mstr_armisc_info_dma)
    ,.mstr_armisc_info_nw            (mstr_armisc_info_nw)
    ,.mstr_armisc_info_cxlsrc        (mstr_armisc_info_cxlsrc)
    ,.mstr_armisc_info_ats           (mstr_armisc_info_ats)
    ,.mstr_armisc_info_dst_segment   (mstr_armisc_info_dst_segment)
    ,.mstr_armisc_info_req_segment   (mstr_armisc_info_req_segment)
    ,.mstr_arready                   (mstr_arready)
    ,.mstr_arqos                     (mstr_arqos)
    ,.mstr_arbar                     (mstr_arbar)
    ,.mstr_ardomain                  (mstr_ardomain)
    ,.mstr_arsnoop                   (mstr_arsnoop)


    ,.mstr_rready                    (mstr_rready)
    ,.mstr_rid                       (mstr_rid)
    ,.mstr_rvalid                    (mstr_rvalid)
    ,.mstr_rlast                     (mstr_rlast)
    ,.mstr_rdata                     (mstr_rdata)
    ,.mstr_ruser                     (mstr_ruser)
    ,.mstr_rresp                     (mstr_rresp)
    ,.mstr_rmisc_info                (mstr_rmisc_info)
    ,.mstr_rmisc_info_cpl_stat       (mstr_rmisc_info_cpl_stat)
    ,.mstr_csysack                   (mstr_csysack)
    ,.mstr_cactive                   (mstr_cactive)
    ,.mstr_csysreq                   (mstr_csysreq)
    // Slave interfaces of AXI
    ,.slv_aclk_g                     (slv_aclk_g)
    ,.slv_aresetn                    (slv_aresetn)
    ,.slv_aclk                       (slv_aclk)
    ,.en_slv_aclk_g                  (en_slv_aclk_g)
    ,.slv_rasdp_err_mode             (slv_rasdp_err_mode)
    ,.slv_awid                       (slv_awid)
    ,.slv_awaddr                     (slv_awaddr)
    ,.slv_awuser                     (slv_awuser)
    ,.slv_awlen                      (slv_awlen[`CC_SLV_INT_BURST_LEN_PW-1:0])
    ,.slv_awsize                     (slv_awsize)
    ,.slv_awburst                    (slv_awburst)
    ,.slv_awlock                     (slv_awlock)
    ,.slv_awcache                    (slv_awcache)
    ,.slv_awprot                     (slv_awprot)
    ,.slv_awvalid                    (slv_awvalid)
    ,.slv_awready                    (slv_awready)
  
    ,.slv_awqos                      (slv_awqos)
    ,.slv_awbar                      (slv_awbar)
    ,.slv_awdomain                   (slv_awdomain)
    ,.slv_awsnoop                    (slv_awsnoop)
    ,.slv_awatop                     (slv_awatop)
    ,.slv_awmisc_info                (slv_awmisc_info)
    ,.slv_awmisc_info_hdr_34dw       (slv_awmisc_info_hdr_34dw)
    ,.slv_awmisc_info_tlpprfx        (slv_awmisc_info_tlpprfx)
    ,.slv_awmisc_info_p_tag          (slv_awmisc_info_p_tag)
    ,.slv_awmisc_info_tph            (slv_awmisc_info_tph)
    ,.slv_awmisc_info_atu_bypass     (slv_awmisc_info_atu_bypass)
    ,.slv_awmisc_info_ido            (slv_awmisc_info_ido)
    ,.slv_awmisc_info_dst_segment    (slv_awmisc_info_dst_segment)
    ,.slv_awmisc_info_nw             (slv_awmisc_info_nw)
    ,.slv_awmisc_info_ats            (slv_awmisc_info_ats)

    ,.slv_wdata                      (slv_wdata)
    ,.slv_wuser                      (slv_wuser)
    ,.slv_wstrb                      (slv_wstrb)
    ,.slv_wlast                      (slv_wlast)
    ,.slv_wvalid                     (slv_wvalid)
    ,.slv_wready                     (slv_wready)
    ,.slv_wmisc_info_ep              (slv_wmisc_info_ep)
    ,.slv_wmisc_info_silentDrop      (slv_wmisc_info_silentDrop)

    ,.slv_bid                        (slv_bid)
    ,.slv_bresp                      (slv_bresp)
    ,.slv_bvalid                     (slv_bvalid)
    ,.slv_bready                     (slv_bready)
    ,.slv_bmisc_info                 (slv_bmisc_info)
    ,.slv_bmisc_info_cpl_segment     (slv_bmisc_info_cpl_segment)
    ,.slv_bmisc_info_dst_segment     (slv_bmisc_info_dst_segment)
    ,.slv_arid                       (slv_arid)
    ,.slv_araddr                     (slv_araddr)
    ,.slv_aruser                     (slv_aruser)
    ,.slv_arlen                      (slv_arlen[`CC_SLV_INT_BURST_LEN_PW-1:0])
    ,.slv_arsize                     (slv_arsize)
    ,.slv_arburst                    (slv_arburst)
    ,.slv_arlock                     (slv_arlock)
    ,.slv_arcache                    (slv_arcache)
    ,.slv_arprot                     (slv_arprot)
    ,.slv_armisc_info                (slv_armisc_info)
    ,.slv_armisc_info_tlpprfx        (slv_armisc_info_tlpprfx)
    ,.slv_armisc_info_tph            (slv_armisc_info_tph)
    ,.slv_armisc_info_atu_bypass     (slv_armisc_info_atu_bypass)
    ,.slv_armisc_info_ido            (slv_armisc_info_ido)
    ,.slv_armisc_info_dst_segment    (slv_armisc_info_dst_segment)
    ,.slv_armisc_info_nw             (slv_armisc_info_nw)
    ,.slv_armisc_info_ats            (slv_armisc_info_ats)
    ,.slv_arvalid                    (slv_arvalid)
    ,.slv_arready                    (slv_arready)

    ,.slv_arqos                      (slv_arqos)
    ,.slv_arbar                      (slv_arbar)
    ,.slv_ardomain                   (slv_ardomain)
    ,.slv_arsnoop                    (slv_arsnoop)

    ,.slv_rid                        (slv_rid)
    ,.slv_rdata                      (slv_rdata)
    ,.slv_ruser                      (slv_ruser)
    ,.slv_rresp                      (slv_rresp)
    ,.slv_rlast                      (slv_rlast)
    ,.slv_rvalid                     (slv_rvalid)
    ,.slv_rmisc_info                 (slv_rmisc_info)
    ,.slv_rmisc_info_ido             (slv_rmisc_info_ido)
    ,.slv_rmisc_info_cpl_segment     (slv_rmisc_info_cpl_segment)
    ,.slv_rmisc_info_dst_segment     (slv_rmisc_info_dst_segment)
    ,.slv_rready                     (slv_rready)

    ,.slv_csysreq                    (slv_csysreq)
    ,.slv_csysack                    (slv_csysack)
    ,.slv_cactive                    (slv_cactive)
    ,.cfg_pbus_dev_num               (cfg_pbus_dev_num[4:0])
    ,.cfg_pbus_num                   (cfg_pbus_num[7:0])
    ,.cfg_subbus_num                 (cfg_subbus_num)
    ,.cfg_2ndbus_num                 (cfg_2ndbus_num)
    ,.rstctl_mstr_flush_req          (rstctl_mstr_flush_req)
    ,.rstctl_slv_flush_req           (rstctl_slv_flush_req)
    ,.brdg_slv_flush_ack             (brdg_slv_flush_ack)
    ,.brdg_slv_xfer_pending          (brdg_slv_xfer_pending)
    ,.brdg_mstr_xfer_pending         (brdg_mstr_xfer_pending)
    ,.app_xfer_pending               (app_xfer_pending)
    ,.trgt_cpl_lut_empty             (trgt_cpl_lut_empty)
    ,.brdg_dbi_xfer_pending          (brdg_dbi_xfer_pending)

    ,.radm_cpl_timeout               (radm_cpl_timeout)
    ,.radm_timeout_cpl_tc            (radm_timeout_cpl_tc)
    ,.radm_timeout_cpl_attr          (radm_timeout_cpl_attr)
    ,.radm_timeout_cpl_tag           (radm_timeout_cpl_tag)
    ,.radm_timeout_func_num          (radm_timeout_func_num)

    ,.trgt_lookup_id                       ( trgt_lookup_id                      )

    ,.radm_trgt1_p_0_pending               ( radm_trgt1_p_0_pending              )

    ,.radm_trgt1_p_0_data                  ( radm_trgt1_p_0_data                 )
    ,.radm_trgt1_p_0_hdr_prot              ( radm_trgt1_p_0_hdr_prot             )
    ,.radm_trgt1_p_0_prfx                  ( radm_trgt1_p_0_prfx                 )
    ,.radm_trgt1_p_0_dwen                  ( radm_trgt1_p_0_dwen                 )
    ,.radm_trgt1_p_0_dv                    ( radm_trgt1_p_0_dv                   )
    ,.radm_trgt1_p_0_hv                    ( radm_trgt1_p_0_hv                   )
    ,.radm_trgt1_p_0_eot                   ( radm_trgt1_p_0_eot                  )
    ,.radm_trgt1_p_0_dllp_abort            ( radm_trgt1_p_0_dllp_abort           )
    ,.radm_trgt1_p_0_tlp_abort             ( radm_trgt1_p_0_tlp_abort            )
    ,.radm_trgt1_p_0_ecrc_err              ( radm_trgt1_p_0_ecrc_err             )
    ,.radm_trgt1_p_0_fmt                   ( radm_trgt1_p_0_fmt                  )
    ,.radm_trgt1_p_0_type                  ( radm_trgt1_p_0_type                 )
    ,.radm_trgt1_p_0_tc                    ( radm_trgt1_p_0_tc                   )
    ,.radm_trgt1_p_0_attr                  ( radm_trgt1_p_0_attr                 )
    ,.radm_trgt1_p_0_reqid                 ( radm_trgt1_p_0_reqid                )
    ,.radm_trgt1_p_0_tag                   ( radm_trgt1_p_0_tag                  )
    ,.radm_trgt1_p_0_func_num              ( radm_trgt1_p_0_func_num             )
    ,.radm_trgt1_p_0_td                    ( radm_trgt1_p_0_td                   )
    ,.radm_trgt1_p_0_cpl_status            ( radm_trgt1_p_0_cpl_status           )
    ,.radm_trgt1_p_0_poisoned              ( radm_trgt1_p_0_poisoned             )
    ,.radm_trgt1_p_0_dw_len                ( radm_trgt1_p_0_dw_len               )
    ,.radm_trgt1_p_0_first_be              ( radm_trgt1_p_0_first_be             )
    ,.radm_trgt1_p_0_vc_num                ( radm_trgt1_p_0_vc_num               )
    ,.radm_trgt1_p_0_addr                  ( radm_trgt1_p_0_addr                 )
    ,.radm_trgt1_p_0_hdr_uppr_bytes        ( radm_trgt1_p_0_hdr_uppr_bytes       )
    ,.radm_trgt1_p_0_rom_in_range          ( radm_trgt1_p_0_rom_in_range         )
    ,.radm_trgt1_p_0_io_req_in_range       ( radm_trgt1_p_0_io_req_in_range      )
    ,.radm_trgt1_p_0_in_membar_range       ( radm_trgt1_p_0_in_membar_range      )
    ,.radm_trgt1_p_0_last_be               ( radm_trgt1_p_0_last_be              )
    ,.radm_trgt1_p_0_ats                   ( radm_trgt1_p_0_ats                  )
    ,.radm_trgt1_p_0_nw                    ( radm_trgt1_p_0_nw                   )
    ,.radm_trgt1_p_0_cxlsrc                ( 1'b0                                )
    ,.radm_trgt1_p_0_th                    ( radm_trgt1_p_0_th                   )
    ,.radm_trgt1_p_0_ph                    ( radm_trgt1_p_0_ph                   )
    ,.radm_trgt1_p_0_st                    ( radm_trgt1_p_0_st                   )
    ,.radm_trgt1_p_0_hdr_uppr_bytes_valid  ( radm_trgt1_p_0_hdr_uppr_bytes_valid )
    ,.radm_trgt1_p_0_reqtr_sgmt            ( radm_trgt1_p_0_reqtr_sgmt           )
    ,.radm_trgt1_p_0_dest_sgmt             ( radm_trgt1_p_0_dest_sgmt            )
    ,.radm_trgt1_p_0_pkt_order_no          ( radm_trgt1_p_0_pkt_order_no         )

    ,.radm_trgt1_np_0_data                 ( radm_trgt1_np_0_data                )
    ,.radm_trgt1_np_0_hdr_prot             ( radm_trgt1_np_0_hdr_prot            )
    ,.radm_trgt1_np_0_prfx                 ( radm_trgt1_np_0_prfx                )
    ,.radm_trgt1_np_0_dwen                 ( radm_trgt1_np_0_dwen                )
    ,.radm_trgt1_np_0_dv                   ( radm_trgt1_np_0_dv                  )
    ,.radm_trgt1_np_0_hv                   ( radm_trgt1_np_0_hv                  )
    ,.radm_trgt1_np_0_eot                  ( radm_trgt1_np_0_eot                 )
    ,.radm_trgt1_np_0_dllp_abort           ( radm_trgt1_np_0_dllp_abort          )
    ,.radm_trgt1_np_0_tlp_abort            ( radm_trgt1_np_0_tlp_abort           )
    ,.radm_trgt1_np_0_ecrc_err             ( radm_trgt1_np_0_ecrc_err            )
    ,.radm_trgt1_np_0_fmt                  ( radm_trgt1_np_0_fmt                 )
    ,.radm_trgt1_np_0_type                 ( radm_trgt1_np_0_type                )
    ,.radm_trgt1_np_0_tc                   ( radm_trgt1_np_0_tc                  )
    ,.radm_trgt1_np_0_attr                 ( radm_trgt1_np_0_attr                )
    ,.radm_trgt1_np_0_reqid                ( radm_trgt1_np_0_reqid               )
    ,.radm_trgt1_np_0_tag                  ( radm_trgt1_np_0_tag                 )
    ,.radm_trgt1_np_0_func_num             ( radm_trgt1_np_0_func_num            )
    ,.radm_trgt1_np_0_cpl_status           ( radm_trgt1_np_0_cpl_status          )
    ,.radm_trgt1_np_0_td                   ( radm_trgt1_np_0_td                  )
    ,.radm_trgt1_np_0_poisoned             ( radm_trgt1_np_0_poisoned            )
    ,.radm_trgt1_np_0_dw_len               ( radm_trgt1_np_0_dw_len              )
    ,.radm_trgt1_np_0_first_be             ( radm_trgt1_np_0_first_be            )
    ,.radm_trgt1_np_0_vc_num               ( radm_trgt1_np_0_vc_num              )

    ,.radm_trgt1_np_0_addr                 ( radm_trgt1_np_0_addr                )
    ,.radm_trgt1_np_0_hdr_uppr_bytes       ( radm_trgt1_np_0_hdr_uppr_bytes      )

    ,.radm_trgt1_np_0_rom_in_range         ( radm_trgt1_np_0_rom_in_range        )
    ,.radm_trgt1_np_0_io_req_in_range      ( radm_trgt1_np_0_io_req_in_range     )
    ,.radm_trgt1_np_0_in_membar_range      ( radm_trgt1_np_0_in_membar_range     )
    ,.radm_trgt1_np_0_last_be              ( radm_trgt1_np_0_last_be             )
    ,.radm_trgt1_np_0_ats                  ( radm_trgt1_np_0_ats                 )
    ,.radm_trgt1_np_0_nw                   ( radm_trgt1_np_0_nw                  )
    ,.radm_trgt1_np_0_cxlsrc               ( radm_trgt1_np_0_cxlsrc              )
    ,.radm_trgt1_np_0_th                   ( radm_trgt1_np_0_th                  )
    ,.radm_trgt1_np_0_ph                   ( radm_trgt1_np_0_ph                  )
    ,.radm_trgt1_np_0_st                   ( radm_trgt1_np_0_st                  )

    ,.radm_trgt1_np_0_reqtr_sgmt           ( radm_trgt1_np_0_reqtr_sgmt          )
    ,.radm_trgt1_np_0_dest_sgmt            ( radm_trgt1_np_0_dest_sgmt           )
    ,.radm_trgt1_np_0_pkt_order_no         ( radm_trgt1_np_0_pkt_order_no        )

    ,.radm_trgt1_cpl_0_data                ( radm_trgt1_cpl_0_data               )
    ,.radm_trgt1_cpl_0_hdr_prot            ( radm_trgt1_cpl_0_hdr_prot           )
    ,.radm_trgt1_cpl_0_prfx                ( radm_trgt1_cpl_0_prfx               )
    ,.radm_trgt1_cpl_0_dwen                ( radm_trgt1_cpl_0_dwen               )
    ,.radm_trgt1_cpl_0_dv                  ( radm_trgt1_cpl_0_dv                 )
    ,.radm_trgt1_cpl_0_hv                  ( radm_trgt1_cpl_0_hv                 )
    ,.radm_trgt1_cpl_0_eot                 ( radm_trgt1_cpl_0_eot                )
    ,.radm_trgt1_cpl_0_dllp_abort          ( radm_trgt1_cpl_0_dllp_abort         )
    ,.radm_trgt1_cpl_0_tlp_abort           ( radm_trgt1_cpl_0_tlp_abort          )
    ,.radm_trgt1_cpl_0_ecrc_err            ( radm_trgt1_cpl_0_ecrc_err           )
    ,.radm_trgt1_cpl_0_fmt                 ( radm_trgt1_cpl_0_fmt                )
    ,.radm_trgt1_cpl_0_type                ( radm_trgt1_cpl_0_type               )
    ,.radm_trgt1_cpl_0_tc                  ( radm_trgt1_cpl_0_tc                 )
    ,.radm_trgt1_cpl_0_attr                ( radm_trgt1_cpl_0_attr               )
    ,.radm_trgt1_cpl_0_reqid               ( radm_trgt1_cpl_0_reqid              )
    ,.radm_trgt1_cpl_0_tag                 ( radm_trgt1_cpl_0_tag                )
    ,.radm_trgt1_cpl_0_func_num            ( radm_trgt1_cpl_0_func_num           )
    ,.radm_trgt1_cpl_0_cpl_status          ( radm_trgt1_cpl_0_cpl_status         )
    ,.radm_trgt1_cpl_0_td                  ( radm_trgt1_cpl_0_td                 )
    ,.radm_trgt1_cpl_0_poisoned            ( radm_trgt1_cpl_0_poisoned           )
    ,.radm_trgt1_cpl_0_dw_len              ( radm_trgt1_cpl_0_dw_len             )
    ,.radm_trgt1_cpl_0_bcm                 ( radm_trgt1_cpl_0_bcm                )
    ,.radm_trgt1_cpl_0_byte_cnt            ( radm_trgt1_cpl_0_byte_cnt           )
    ,.radm_trgt1_cpl_0_cmpltr_id           ( radm_trgt1_cpl_0_cmpltr_id          )
    ,.radm_trgt1_cpl_0_last                ( radm_trgt1_cpl_0_last               )
    ,.radm_trgt1_cpl_0_vc_num              ( radm_trgt1_cpl_0_vc_num             )

    ,.radm_trgt1_cpl_0_addr                ( {{(`FLT_Q_ADDR_WIDTH -`FLT_Q_CPL_LOWER_ADDR_WIDTH){1'b0}},radm_trgt1_cpl_0_addr} )

    ,.radm_trgt1_cpl_0_dest_sgmt           ( radm_trgt1_cpl_0_dest_sgmt          )
    ,.radm_trgt1_cpl_0_cpl_sgmt            ( radm_trgt1_cpl_0_cpl_sgmt           )
    ,.radm_trgt1_cpl_0_pkt_order_no        ( radm_trgt1_cpl_0_pkt_order_no       )

    ,.trgt1_radm_intf_cpl_0_halt           ( trgt1_radm_intf_cpl_0_halt          )
    ,.trgt1_radm_intf_p_0_halt             ( trgt1_radm_intf_p_0_halt            )
    ,.trgt1_radm_intf_np_0_halt            ( trgt1_radm_intf_np_0_halt           )

    ,.xali_xaim_pkt  (xali_xaim_pkt)
    ,.xaim_xali_halt (xaim_xali_halt)
    ,.crgb_ack                       (crgb_ack)
    ,.crgb_rd_data                   (crgb_rd_data)
    // DBI interface
    ,.dbi_addr                       (dbi_addr)
    ,.dbi_din                        (dbi_din)
    ,.dbi_cs                         (dbi_cs)
    ,.dbi_cs2                        (dbi_cs2)
    ,.dbi_wr                         (dbi_wr)
    ,.dbi_func_num                   (dbi_func_num)
    ,.dbi_bar_num                    (dbi_bar_num)
    ,.dbi_io_access                  (dbi_io_access)
    ,.dbi_rom_access                 (dbi_rom_access)
    ,.dbi_ack                        (dbi_ack)
    ,.dbi_dout                       (dbi_dout)
  // External RAM Interfaces
  // Inbound
  // Inbound Scheduler Posted Request Header RAM
    ,.ib_scheduler_p_hdr_ram_addra         (ib_scheduler_p_hdr_ram_addra       )
    ,.ib_scheduler_p_hdr_ram_wea           (ib_scheduler_p_hdr_ram_wea         )
    ,.ib_scheduler_p_hdr_ram_dina          (ib_scheduler_p_hdr_ram_dina        )
    ,.ib_scheduler_p_hdr_ram_addrb         (ib_scheduler_p_hdr_ram_addrb       )
    ,.ib_scheduler_p_hdr_ram_enb           (ib_scheduler_p_hdr_ram_enb         )
    ,.ib_scheduler_p_hdr_ram_doutb         (ib_scheduler_p_hdr_ram_doutb       )
  // Inbound Scheduler Posted Request Data RAM
    ,.ib_scheduler_p_data_ram_addra        (ib_scheduler_p_data_ram_addra      )
    ,.ib_scheduler_p_data_ram_wea          (ib_scheduler_p_data_ram_wea        )
    ,.ib_scheduler_p_data_ram_dina         (ib_scheduler_p_data_ram_dina       )
    ,.ib_scheduler_p_data_ram_addrb        (ib_scheduler_p_data_ram_addrb      )
    ,.ib_scheduler_p_data_ram_enb          (ib_scheduler_p_data_ram_enb        )
    ,.ib_scheduler_p_data_ram_doutb        (ib_scheduler_p_data_ram_doutb      )
  // Inbound Scheduler Non-Posted Request Header RAM
    ,.ib_scheduler_np_hdr_ram_addra        (ib_scheduler_np_hdr_ram_addra      )
    ,.ib_scheduler_np_hdr_ram_wea          (ib_scheduler_np_hdr_ram_wea        )
    ,.ib_scheduler_np_hdr_ram_dina         (ib_scheduler_np_hdr_ram_dina       )
    ,.ib_scheduler_np_hdr_ram_addrb        (ib_scheduler_np_hdr_ram_addrb      )
    ,.ib_scheduler_np_hdr_ram_enb          (ib_scheduler_np_hdr_ram_enb        )
    ,.ib_scheduler_np_hdr_ram_doutb        (ib_scheduler_np_hdr_ram_doutb      )
  // Inbound Scheduler Non-Posted Request Data RAM
    ,.ib_scheduler_np_data_ram_addra       (ib_scheduler_np_data_ram_addra     )
    ,.ib_scheduler_np_data_ram_wea         (ib_scheduler_np_data_ram_wea       )
    ,.ib_scheduler_np_data_ram_dina        (ib_scheduler_np_data_ram_dina      )
    ,.ib_scheduler_np_data_ram_addrb       (ib_scheduler_np_data_ram_addrb     )
    ,.ib_scheduler_np_data_ram_enb         (ib_scheduler_np_data_ram_enb       )
    ,.ib_scheduler_np_data_ram_doutb       (ib_scheduler_np_data_ram_doutb     )
    // Inbound Read Request Clock Domain Crossing FIFO RAM
    ,.ib_rreq_c2a_cdc_ram_addra      (ib_rreq_c2a_cdc_ram_addra)
    ,.ib_rreq_c2a_cdc_ram_wea        (ib_rreq_c2a_cdc_ram_wea)
    ,.ib_rreq_c2a_cdc_ram_dina       (ib_rreq_c2a_cdc_ram_dina)
    ,.ib_rreq_c2a_cdc_ram_addrb      (ib_rreq_c2a_cdc_ram_addrb)
    ,.ib_rreq_c2a_cdc_ram_enb        (ib_rreq_c2a_cdc_ram_enb)
    ,.ib_rreq_c2a_cdc_ram_doutb      (ib_rreq_c2a_cdc_ram_doutb)
    // Inbound Write Request Clock Domain Crossing FIFO RAM
    ,.ib_wreq_c2a_cdc_ram_addra      (ib_wreq_c2a_cdc_ram_addra)
    ,.ib_wreq_c2a_cdc_ram_wea        (ib_wreq_c2a_cdc_ram_wea)
    ,.ib_wreq_c2a_cdc_ram_dina       (ib_wreq_c2a_cdc_ram_dina)
    ,.ib_wreq_c2a_cdc_ram_addrb      (ib_wreq_c2a_cdc_ram_addrb)
    ,.ib_wreq_c2a_cdc_ram_enb        (ib_wreq_c2a_cdc_ram_enb)
    ,.ib_wreq_c2a_cdc_ram_doutb      (ib_wreq_c2a_cdc_ram_doutb)

    // Inbound Master Completion Clock Domain Crossing FIFO RAM
    ,.ib_mcpl_a2c_cdc_ram_addra      (ib_mcpl_a2c_cdc_ram_addra)
    ,.ib_mcpl_a2c_cdc_ram_wea        (ib_mcpl_a2c_cdc_ram_wea)
    ,.ib_mcpl_a2c_cdc_ram_dina       (ib_mcpl_a2c_cdc_ram_dina)
    ,.ib_mcpl_a2c_cdc_ram_addrb      (ib_mcpl_a2c_cdc_ram_addrb)
    ,.ib_mcpl_a2c_cdc_ram_enb        (ib_mcpl_a2c_cdc_ram_enb)
    ,.ib_mcpl_a2c_cdc_ram_doutb      (ib_mcpl_a2c_cdc_ram_doutb)
    // Inbound Master Completion Data Segment FIFO RAM
    ,.ib_mcpl_sb_ram_addra           (ib_mcpl_sb_ram_addra)
    ,.ib_mcpl_sb_ram_wea             (ib_mcpl_sb_ram_wea)
    ,.ib_mcpl_sb_ram_dina            (ib_mcpl_sb_ram_dina)
    ,.ib_mcpl_sb_ram_addrb           (ib_mcpl_sb_ram_addrb)
    ,.ib_mcpl_sb_ram_enb             (ib_mcpl_sb_ram_enb)
    ,.ib_mcpl_sb_ram_doutb           (ib_mcpl_sb_ram_doutb)
   // Outbound
   // Slave Non-Posted Write Set-Aside RAM // To do : change names
    ,.slv_npw_sab_ram_addra            (slv_npw_sab_ram_addra)
    ,.slv_npw_sab_ram_wea              (slv_npw_sab_ram_wea)
    ,.slv_npw_sab_ram_dina             (slv_npw_sab_ram_dina)
    ,.slv_npw_sab_ram_addrb            (slv_npw_sab_ram_addrb)
    ,.slv_npw_sab_ram_enb              (slv_npw_sab_ram_enb)
    ,.slv_npw_sab_ram_doutb            (slv_npw_sab_ram_doutb)
  // Outbound Non-Posted TLP Decomposer Header/Data FIFO RAM
    ,.ob_npdcmp_ram_addra              (ob_npdcmp_ram_addra)
    ,.ob_npdcmp_ram_wea                (ob_npdcmp_ram_wea)
    ,.ob_npdcmp_ram_dina               (ob_npdcmp_ram_dina)
    ,.ob_npdcmp_ram_addrb              (ob_npdcmp_ram_addrb)
    ,.ob_npdcmp_ram_enb                (ob_npdcmp_ram_enb)
    ,.ob_npdcmp_ram_doutb              (ob_npdcmp_ram_doutb)
  // Outbound Posted TLP Decomposer Header FIFO RAM
    ,.ob_pdcmp_hdr_ram_addra           (ob_pdcmp_hdr_ram_addra)
    ,.ob_pdcmp_hdr_ram_wea             (ob_pdcmp_hdr_ram_wea)
    ,.ob_pdcmp_hdr_ram_dina            (ob_pdcmp_hdr_ram_dina)
    ,.ob_pdcmp_hdr_ram_addrb           (ob_pdcmp_hdr_ram_addrb)
    ,.ob_pdcmp_hdr_ram_enb             (ob_pdcmp_hdr_ram_enb)
    ,.ob_pdcmp_hdr_ram_doutb           (ob_pdcmp_hdr_ram_doutb)
  // Outbound Posted TLP Decomposer Data FIFO RAM
    ,.ob_pdcmp_data_ram_addra          (ob_pdcmp_data_ram_addra)
    ,.ob_pdcmp_data_ram_wea            (ob_pdcmp_data_ram_wea)
    ,.ob_pdcmp_data_ram_dina           (ob_pdcmp_data_ram_dina)
    ,.ob_pdcmp_data_ram_addrb          (ob_pdcmp_data_ram_addrb)
    ,.ob_pdcmp_data_ram_enb            (ob_pdcmp_data_ram_enb)
    ,.ob_pdcmp_data_ram_doutb          (ob_pdcmp_data_ram_doutb)
  // Outbound Composer Segmented Buffer RAM
    ,.ob_ccmp_data_ram_addra          (ob_ccmp_data_ram_addra)
    ,.ob_ccmp_data_ram_wea            (ob_ccmp_data_ram_wea)
    ,.ob_ccmp_data_ram_dina           (ob_ccmp_data_ram_dina)
    ,.ob_ccmp_data_ram_addrb          (ob_ccmp_data_ram_addrb)
    ,.ob_ccmp_data_ram_enb            (ob_ccmp_data_ram_enb)
    ,.ob_ccmp_data_ram_doutb          (ob_ccmp_data_ram_doutb)
    ,.edma_rd_eng_ll_addra_ram            (edma_rd_eng_ll_addra_ram)
    ,.edma_rd_eng_ll_addrb_ram            (edma_rd_eng_ll_addrb_ram)
    ,.edma_rd_eng_ll_dout_ram             (edma_rd_eng_ll_dout_ram)
    ,.edma_rd_eng_ll_we_ram               (edma_rd_eng_ll_we_ram)
    ,.edma_rd_eng_ll_re_ram               (edma_rd_eng_ll_re_ram)
    ,.edma_rd_eng_ll_din_ram              (edma_rd_eng_ll_din_ram)
    ,.edma_wr_eng_ll_addra_ram            (edma_wr_eng_ll_addra_ram)
    ,.edma_wr_eng_ll_addrb_ram            (edma_wr_eng_ll_addrb_ram)
    ,.edma_wr_eng_ll_dout_ram             (edma_wr_eng_ll_dout_ram)
    ,.edma_wr_eng_ll_we_ram               (edma_wr_eng_ll_we_ram)
    ,.edma_wr_eng_ll_re_ram               (edma_wr_eng_ll_re_ram)
    ,.edma_wr_eng_ll_din_ram              (edma_wr_eng_ll_din_ram)
    ,.edma_rd_eng_ovrl_addra_ram          (edma_rd_eng_ovrl_addra_ram)
    ,.edma_rd_eng_ovrl_addrb_ram          (edma_rd_eng_ovrl_addrb_ram)
    ,.edma_rd_eng_ovrl_dout_ram           (edma_rd_eng_ovrl_dout_ram)
    ,.edma_rd_eng_ovrl_we_ram             (edma_rd_eng_ovrl_we_ram)
    ,.edma_rd_eng_ovrl_re_ram             (edma_rd_eng_ovrl_re_ram)
    ,.edma_rd_eng_ovrl_din_ram            (edma_rd_eng_ovrl_din_ram)
    ,.edma_wr_eng_ovrl_addra_ram          (edma_wr_eng_ovrl_addra_ram)
    ,.edma_wr_eng_ovrl_addrb_ram          (edma_wr_eng_ovrl_addrb_ram)
    ,.edma_wr_eng_ovrl_dout_ram           (edma_wr_eng_ovrl_dout_ram)
    ,.edma_wr_eng_ovrl_we_ram             (edma_wr_eng_ovrl_we_ram)
    ,.edma_wr_eng_ovrl_re_ram             (edma_wr_eng_ovrl_re_ram)
    ,.edma_wr_eng_ovrl_din_ram            (edma_wr_eng_ovrl_din_ram)
    ,.edma_rd_eng_c2w_lut_addra_ram       (edma_rd_eng_c2w_lut_addra_ram)
    ,.edma_rd_eng_c2w_lut_addrb_ram       (edma_rd_eng_c2w_lut_addrb_ram)
    ,.edma_rd_eng_c2w_lut_dout_ram        (edma_rd_eng_c2w_lut_dout_ram)
    ,.edma_rd_eng_c2w_lut_we_ram          (edma_rd_eng_c2w_lut_we_ram)
    ,.edma_rd_eng_c2w_lut_re_ram          (edma_rd_eng_c2w_lut_re_ram)
    ,.edma_rd_eng_c2w_lut_din_ram         (edma_rd_eng_c2w_lut_din_ram)
    ,.edma_wr_eng_c2w_lut_addra_ram       (edma_wr_eng_c2w_lut_addra_ram)
    ,.edma_wr_eng_c2w_lut_addrb_ram       (edma_wr_eng_c2w_lut_addrb_ram)
    ,.edma_wr_eng_c2w_lut_dout_ram        (edma_wr_eng_c2w_lut_dout_ram)
    ,.edma_wr_eng_c2w_lut_we_ram          (edma_wr_eng_c2w_lut_we_ram)
    ,.edma_wr_eng_c2w_lut_re_ram          (edma_wr_eng_c2w_lut_re_ram)
    ,.edma_wr_eng_c2w_lut_din_ram         (edma_wr_eng_c2w_lut_din_ram)
    ,.edma_rd_eng_stsh_lut_addra_ram      (edma_rd_eng_stsh_lut_addra_ram)
    ,.edma_rd_eng_stsh_lut_addrb_ram      (edma_rd_eng_stsh_lut_addrb_ram)
    ,.edma_rd_eng_stsh_lut_dout_ram       (edma_rd_eng_stsh_lut_dout_ram)
    ,.edma_rd_eng_stsh_lut_we_ram         (edma_rd_eng_stsh_lut_we_ram)
    ,.edma_rd_eng_stsh_lut_re_ram         (edma_rd_eng_stsh_lut_re_ram)
    ,.edma_rd_eng_stsh_lut_din_ram        (edma_rd_eng_stsh_lut_din_ram)
    ,.edma_wr_eng_stsh_lut_addra_ram      (edma_wr_eng_stsh_lut_addra_ram)
    ,.edma_wr_eng_stsh_lut_addrb_ram      (edma_wr_eng_stsh_lut_addrb_ram)
    ,.edma_wr_eng_stsh_lut_dout_ram       (edma_wr_eng_stsh_lut_dout_ram)
    ,.edma_wr_eng_stsh_lut_we_ram         (edma_wr_eng_stsh_lut_we_ram)
    ,.edma_wr_eng_stsh_lut_re_ram         (edma_wr_eng_stsh_lut_re_ram)
    ,.edma_wr_eng_stsh_lut_din_ram        (edma_wr_eng_stsh_lut_din_ram)
    ,.edma_rd_eng_msi_addra_ram           (edma_rd_eng_msi_addra_ram)
    ,.edma_rd_eng_msi_addrb_ram           (edma_rd_eng_msi_addrb_ram)
    ,.edma_rd_eng_msi_dout_ram            (edma_rd_eng_msi_dout_ram)
    ,.edma_rd_eng_msi_we_ram              (edma_rd_eng_msi_we_ram)
    ,.edma_rd_eng_msi_re_ram              (edma_rd_eng_msi_re_ram)
    ,.edma_rd_eng_msi_din_ram             (edma_rd_eng_msi_din_ram)
    ,.edma_wr_eng_msi_addra_ram           (edma_wr_eng_msi_addra_ram)
    ,.edma_wr_eng_msi_addrb_ram           (edma_wr_eng_msi_addrb_ram)
    ,.edma_wr_eng_msi_dout_ram            (edma_wr_eng_msi_dout_ram)
    ,.edma_wr_eng_msi_we_ram              (edma_wr_eng_msi_we_ram)
    ,.edma_wr_eng_msi_re_ram              (edma_wr_eng_msi_re_ram)
    ,.edma_wr_eng_msi_din_ram             (edma_wr_eng_msi_din_ram)
    ,.edma_rd_eng_hard_stop_req           (edma_rd_eng_hard_stop_req)
    ,.edma_rd_eng_hard_stop_channel       (edma_rd_eng_hard_stop_channel)
    ,.edma_rd_eng_hard_stop_ack           (edma_rd_eng_hard_stop_ack)
    ,.edma_wr_eng_hard_stop_req           (edma_wr_eng_hard_stop_req)
    ,.edma_wr_eng_hard_stop_channel       (edma_wr_eng_hard_stop_channel)
    ,.edma_wr_eng_hard_stop_ack           (edma_wr_eng_hard_stop_ack)
    //DMA read buffer interface
    ,.edmarbuff2ram_addra            (edmarbuff2ram_addra)
    ,.edmarbuff2ram_we               (edmarbuff2ram_we)
    ,.edmarbuff2ram_dout             (edmarbuff2ram_dout)
    ,.edmarbuff2ram_addrb            (edmarbuff2ram_addrb)
    ,.edmarbuff2ram_re               (edmarbuff2ram_re)
    ,.ram2edmarbuff_din              (ram2edmarbuff_din)
     //DMA Local Interrupt
    ,.edma_int                        (edma_int)
     // DMA Read/Write Channel transfer pending
    ,.edma_xfer_pending               (edma_xfer_pending)
    ,.radm_trgt1_cpl_lookup_id_rlsd   (radm_trgt1_cpl_lookup_id_rlsd)
    // Indicates non-posted TLP
    ,.radm_trgt1_lookup_id_consmd    (radm_trgt1_lookup_id_consmd)

    ,.cfg_slv_resp_err_map           (cfg_err_resp[15:10])
    ,.cfg_ax_mstr_np_pass_p          (cfg_order_rule_ctrl[7:0])
    ,.cfg_ax_mstr_ordr_p_event_sel   (cfg_ax_mstr_ordr_p_event_sel)
    ,.cfg_ax_ib_cpl_pass_p           (cfg_order_rule_ctrl[15:8])
    ,.cfg_ax_snp_en                  (cfg_ax_snp_en)
    ,.cfg_ib_p_id_mng_ctrl           (cfg_ib_p_id_mng_ctrl)
    ,.cfg_tc_struc_vc_map            (cfg_tc_struc_vc_map)
    ,.xali_posted_tlp_sent           (xali_posted_tlp_sent)
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
    ,.atu_reg_out_upr_base           (atu_reg_out_upr_base)
    ,.atu_reg_out_en                 (atu_reg_out_en)
    ,.atu_reg_out_type               (atu_reg_out_type)
    ,.atu_reg_out_base               (atu_reg_out_base)
    ,.atu_reg_out_limit              (atu_reg_out_limit)
    ,.atu_reg_out_uppr_limit         (atu_reg_out_uppr_limit)
    ,.atu_reg_out_incr_rgn_size      (atu_reg_out_incr_rgn_size)
    ,.atu_reg_out_invert             (atu_reg_out_invert)
    ,.atu_reg_out_func_num           (atu_reg_out_func_num)
    ,.atu_reg_out_func_bypass        (atu_reg_out_func_bypass)
    ,.atu_reg_out_snp                (atu_reg_out_snp)
    ,.cfg_rasdp_err_mode             (cfg_rasdp_err_mode)
    ,.axi_bridge_out_ras_dp_err_log        (axi_bridge_out_ras_dp_err_log)
    ,.axi_bridge_in_ras_dp_err_inj         (axi_bridge_in_ras_dp_err_inj)
    ,.axi_bridge_in_ras_dp_err_inj_wake_up (axi_bridge_in_ras_dp_err_inj_wake_up)
    ,.hdma_ras_dp_err_log                  (hdma_ras_dp_err_log)
    ,.hdma_ras_dp_err_inj                  (hdma_ras_dp_err_inj)
    ,.cfg_rasdp_err_mode_en                (cfg_rasdp_err_mode_en)

    // RAS ECC RAM interface
    ,.cfg_ras_recc_npw_sab_correct                  (cfg_ras_recc_npw_sab_correct)
    ,.axi_ras_recc_corr_cnt_npw_sab_pulse           (axi_ras_recc_corr_cnt_npw_sab_pulse)
    ,.axi_ras_recc_corr_cnt_npw_sab_addr            (axi_ras_recc_corr_cnt_npw_sab_addr)
    ,.axi_ras_recc_ucorr_cnt_npw_sab_pulse          (axi_ras_recc_ucorr_cnt_npw_sab_pulse)
    ,.axi_ras_recc_ucorr_cnt_npw_sab_addr           (axi_ras_recc_ucorr_cnt_npw_sab_addr)

    ,.cfg_ras_recc_ob_npdcmp_correct                (cfg_ras_recc_ob_npdcmp_correct)
    ,.axi_ras_recc_corr_cnt_ob_npdcmp_pulse         (axi_ras_recc_corr_cnt_ob_npdcmp_pulse)
    ,.axi_ras_recc_corr_cnt_ob_npdcmp_addr          (axi_ras_recc_corr_cnt_ob_npdcmp_addr)
    ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse        (axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse)
    ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_addr         (axi_ras_recc_ucorr_cnt_ob_npdcmp_addr)

    ,.cfg_ras_recc_ob_pdcmp_hdr_correct             (cfg_ras_recc_ob_pdcmp_hdr_correct)
    ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse      (axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse)
    ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr       (axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr)
    ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse     (axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse)
    ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr      (axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr)

    ,.cfg_ras_recc_ob_pdcmp_data_correct            (cfg_ras_recc_ob_pdcmp_data_correct)
    ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse     (axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse)
    ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_addr      (axi_ras_recc_corr_cnt_ob_pdcmp_data_addr)
    ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse    (axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse)
    ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr     (axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr)

    ,.cfg_ras_recc_ob_ccmp_data_correct             (cfg_ras_recc_ob_ccmp_data_correct)
    ,.axi_ras_recc_corr_cnt_ob_ccmp_data_pulse      (axi_ras_recc_corr_cnt_ob_ccmp_data_pulse)
    ,.axi_ras_recc_corr_cnt_ob_ccmp_data_addr       (axi_ras_recc_corr_cnt_ob_ccmp_data_addr)
    ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse     (axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse)
    ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr      (axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr)

    ,.cfg_ras_recc_ib_sch_p_hdr_correct             (cfg_ras_recc_ib_sch_p_hdr_correct)
    ,.axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse      (axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse)
    ,.axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr       (axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse     (axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr      (axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr)
    ,.cfg_ras_recc_ib_sch_p_data_correct            (cfg_ras_recc_ib_sch_p_data_correct)
    ,.axi_ras_recc_corr_cnt_ib_sch_p_data_pulse     (axi_ras_recc_corr_cnt_ib_sch_p_data_pulse)
    ,.axi_ras_recc_corr_cnt_ib_sch_p_data_addr      (axi_ras_recc_corr_cnt_ib_sch_p_data_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse    (axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr     (axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr)
    ,.cfg_ras_recc_ib_sch_np_hdr_correct            (cfg_ras_recc_ib_sch_np_hdr_correct)
    ,.axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse     (axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse)
    ,.axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr      (axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse    (axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr     (axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr)
    ,.cfg_ras_recc_ib_sch_np_data_correct           (cfg_ras_recc_ib_sch_np_data_correct)
    ,.axi_ras_recc_corr_cnt_ib_sch_np_data_pulse    (axi_ras_recc_corr_cnt_ib_sch_np_data_pulse)
    ,.axi_ras_recc_corr_cnt_ib_sch_np_data_addr     (axi_ras_recc_corr_cnt_ib_sch_np_data_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse   (axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr    (axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr)
    ,.cfg_ras_recc_ib_rreq_c2a_cdc_correct          (cfg_ras_recc_ib_rreq_c2a_cdc_correct)
    ,.axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse   (axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse)
    ,.axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr    (axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse  (axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr   (axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr)

    ,.cfg_ras_recc_ib_wreq_c2a_cdc_correct          (cfg_ras_recc_ib_wreq_c2a_cdc_correct)
    ,.axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse   (axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse)
    ,.axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr    (axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse  (axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr   (axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr)

    ,.cfg_ras_recc_ib_mcpl_a2c_cdc_correct          (cfg_ras_recc_ib_mcpl_a2c_cdc_correct)
    ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse   (axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse)
    ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr    (axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse  (axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr   (axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr)


    ,.cfg_ras_recc_ib_mcpl_sb_correct               (cfg_ras_recc_ib_mcpl_sb_correct)
    ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse        (axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse)
    ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_addr         (axi_ras_recc_corr_cnt_ib_mcpl_sb_addr)
    ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse       (axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse)
    ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr        (axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr)




    ,.axi_ras_par_rtrgt_p_ad_pulse                  (axi_ras_par_rtrgt_p_ad_pulse)
    ,.axi_ras_par_rtrgt_p_dt_pulse                  (axi_ras_par_rtrgt_p_dt_pulse)
    ,.axi_ras_par_rtrgt_np_ad_pulse                 (axi_ras_par_rtrgt_np_ad_pulse)
    ,.axi_ras_par_rtrgt_np_dt_pulse                 (axi_ras_par_rtrgt_np_dt_pulse)
    ,.axi_ras_par_rtrgt_cpl_ad_pulse                (axi_ras_par_rtrgt_cpl_ad_pulse)
    ,.axi_ras_par_rtrgt_cpl_dt_pulse                (axi_ras_par_rtrgt_cpl_dt_pulse)
    ,.axi_ras_par_ib_mcpl_dt_pulse                  (axi_ras_par_ib_mcpl_dt_pulse)




    ,.axi_ras_par_ibwr_dcmp_dt_pulse                (axi_ras_par_ibwr_dcmp_dt_pulse)
    ,.axi_ras_par_ibwr_dcmp_ad_pulse                (axi_ras_par_ibwr_dcmp_ad_pulse)
    ,.axi_ras_par_ibrd_dcmp_ad_pulse                (axi_ras_par_ibrd_dcmp_ad_pulse)


    ,.axi_ras_par_ib_sch_p_ad_pulse                 (axi_ras_par_ib_sch_p_ad_pulse)
    ,.axi_ras_par_ib_sch_p_dt_pulse                 (axi_ras_par_ib_sch_p_dt_pulse)
    ,.axi_ras_par_ib_sch_np_ad_pulse                (axi_ras_par_ib_sch_np_ad_pulse)
    ,.axi_ras_par_ib_sch_np_dt_pulse                (axi_ras_par_ib_sch_np_dt_pulse)
     ,.axi_ras_par_ib_mcpl_a2c_dt_pulse               (axi_ras_par_ib_mcpl_a2c_dt_pulse)
    ,.axi_ras_par_ib_mcpl_sb_dt_pulse               (axi_ras_par_ib_mcpl_sb_dt_pulse)

    ,.axi_ras_par_ibwq_mrf_dt_pulse                 (axi_ras_par_ibwq_mrf_dt_pulse)
    ,.axi_ras_par_ibwq_mrf_ad_pulse                 (axi_ras_par_ibwq_mrf_ad_pulse)
    ,.axi_ras_par_ibrd_mrf_ad_pulse                 (axi_ras_par_ibrd_mrf_ad_pulse)

    ,.axi_ras_par_npqdec_ad_pulse                   (axi_ras_par_npqdec_ad_pulse)

    ,.axi_ras_par_pqdec_ad_pulse                    (axi_ras_par_pqdec_ad_pulse)
    ,.axi_ras_par_swwrap_dt_pulse                   (axi_ras_par_swwrap_dt_pulse)
    ,.axi_ras_par_swwrap_ad_pulse                   (axi_ras_par_swwrap_ad_pulse)
    ,.axi_ras_par_srwrap_ad_pulse                   (axi_ras_par_srwrap_ad_pulse)


    ,.axi_ras_par_swrq_npw_dt_pulse                 (axi_ras_par_swrq_npw_dt_pulse)
    ,.axi_ras_par_swrq_npw_ad_pulse                 (axi_ras_par_swrq_npw_ad_pulse)

    ,.axi_ras_par_slnull_dt_pulse                   (axi_ras_par_slnull_dt_pulse)
    ,.axi_ras_par_slnull_ad_pulse                   (axi_ras_par_slnull_ad_pulse)

    ,.axi_ras_par_ob_np_dcmp_inq_dt_pulse           (axi_ras_par_ob_np_dcmp_inq_dt_pulse)
    ,.axi_ras_par_ob_p_dcmp_inq_dt_pulse            (axi_ras_par_ob_p_dcmp_inq_dt_pulse)
    ,.axi_ras_par_ob_cpl_comp_dt_pulse              (axi_ras_par_ob_cpl_comp_dt_pulse)

    ,.axi_ras_par_c2_ad_pulse                       (axi_ras_par_c2_ad_pulse)
    ,.axi_ras_par_c2_dt_pulse                       (axi_ras_par_c2_dt_pulse)
    ,.axi_ras_par_c1_ad_pulse                       (axi_ras_par_c1_ad_pulse)
    ,.axi_ras_par_c1_dt_pulse                       (axi_ras_par_c1_dt_pulse)

    ,.axi_slv_sisb_uncorr_pulse                     (axi_slv_sisb_uncorr_pulse)
    ,.axi_mstr_misb_uncorr_pulse                    (axi_mstr_misb_uncorr_pulse)

    ,.cfg_err_resp_mode              (cfg_err_resp[4:0])
    ,.cfg_memtype_value              (cfg_memtype_value)
    ,.cfg_memtype_boundary           (cfg_memtype_boundary)
    ,.cfg_ext_tag_en                 (|cfg_ext_tag_en[`CX_NFUNC-1:0])
    ,.cfg_10b_tag_en                 (s_cfg_10b_tag_en)
    ,.cfg_dmwr_req_en                ( |cfg_dmwr_req_en[`CX_NFUNC-1:0] )
    ,.cfg_max_rd_req_size            (cfg_max_rd_req_size)
    ,.cfg_max_payload_size           (cfg_max_payload_size)


    // Completions Status during DPC
    ,.core_in_dpc_i                (core_in_dpc_i      )
    ,.cfg_dpc_cpl_cntrl_i          (cfg_dpc_cpl_cntrl_i)
); // `AMBA_TOP instance

 


assign ordrb_error_corr                   = '0;


assign ordrb_error_uncorr         = '0;






endmodule
