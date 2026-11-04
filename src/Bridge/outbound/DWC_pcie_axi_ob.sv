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

// ---------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_ob.sv#21 $
// ---------------------------------------------------------------------------------------
// --- Module Description:
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Axi/DWC_pcie_axi_xali_pkg.svh"

 module DWC_pcie_axi_ob
 import DWC_pcie_axi_xali_pkg::*;
//import DWC_pcie_ctl_pkg::ATTR_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  parameter SLV_BUS_ADDR_WIDTH             = 32,
  parameter SLAVE_BUS_ADDR_WIDTH           = 32,
  parameter ADDR_PAR_WD                    = 4,
  parameter CX_RAS_PROT_RANGE              = 8,
  parameter SLV_BUS_NPDATA_WIDTH           = `CC_SLV_BUS_NPDATA_WIDTH,
  parameter SLV_BUS_NPWSTRB_WIDTH          = `CC_SLV_BUS_NPWSTRB_WIDTH,
  parameter SLV_BUS_DATA_WIDTH             = 32,
  parameter SLV_BUS_ID_WIDTH               = 5,
  parameter SLV_MAX_RD_SIZE_PW             = 5,
  parameter SLV_BURST_LEN_PW               = 3,
  parameter SLV_BUS_WSTRB_WIDTH            = 3,
  parameter SLV_MTU_PW                     = 7,
  parameter SLV_CONV_FAC_WIDTH             = 2,
  parameter SLV_MISC_INFO_WD               = 13,
  parameter SLV_NUM_OUTSTD_WR_RESP         = 32,
  parameter SLV_NUM_OUTSTD_WR_RESP_LOG2    = 32,
  parameter NFUNC                          = 1,
  parameter NFUNC_WD                       = 3,
  parameter DC_CPL_STATUS_WD               = `DC_CPL_STATUS_WD,
  parameter PF_WD_MIN3                     = 3,
  parameter MISC_INFO_TPH_WD               = 11,
  parameter TX_TLP_PREFIX_WD               = 32,
  parameter ATTR_WD                        = 3,
  parameter CX_TAG_SIZE                         = `CX_TAG_SIZE,
  parameter MAX_SLV_TAG_PW                      = 5,
  parameter MAX_WIRE_TAG                        = 32,
  parameter MAX_WIRE_TAG_PW                     = 5,
  parameter SLV_DECOMP_TAG_LOW                  = 0,
  parameter SLV_DECOMP_TAG_HIGH                 = 31,
  parameter SLV_DECOMP_TAG_DP_PW                = 5,
  parameter SLV_DECOMP_TAG_DP_CW                = 6,
  parameter CORE_ADDR_BUS_WD                    = 32,
  parameter FLT_Q_ATTR_WIDTH                    = 2,
  parameter CORE_DATA_BUS_WD                    = 32,
  parameter DC_INBD_HEADER_CPL_WD               = 100,
  parameter NW                                  = 1,
  parameter NPRSPF_TLP_DATA_WIDTH               = 32,
  parameter NPRSPF_TLP_DATA_WIDTH_NP            = 32,
  parameter NPRSPF_TLP_NUM_DWORDS               = 1,
  parameter NPRSPF_TLP_NUM_STRBS                = 4,
  parameter COMPOSER_HDR_WD                     = 64,
  parameter CC_OB_CCMP_DATA_RAM_DATA_WD         = `CC_OB_CCMP_DATA_RAM_DATA_WD,
  parameter CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC   = `CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC,
  parameter CC_OB_CCMP_DATA_RAM_ADDR_WD         = `CC_OB_CCMP_DATA_RAM_ADDR_WD,
  parameter PRF_TLP_DATA_WIDTH                  = 32,
  parameter PRF_TLP_NUM_WSTRBS                  = 8,
  parameter PRF_TLP_NUM_WSTRBS_GT_4             = 0,
  parameter PRF_TLP_NUM_DWORDS                  = 3,
  parameter OB_NPDCMP_RAM_DP                    = `CC_OB_NPDCMP_RAM_DP,
  parameter OB_NPDCMP_RAM_DATA_WD               = `CC_OB_NPDCMP_RAM_DATA_WD,
  parameter OB_NPDCMP_RAM_ADDR_WD               = `CC_OB_NPDCMP_RAM_ADDR_WD,
  parameter OB_NPDCMP_RAM_PTR_WD                = `CC_OB_NPDCMP_RAM_PTR_WD,
  parameter PRF_HDRQ_WD                         = `CC_PRF_HDRQ_WD,
  parameter OB_PDCMP_HDR_RAM_DP                 = `CC_OB_PDCMP_HDR_RAM_DP,
  parameter OB_PDCMP_HDR_RAM_DATA_WD            = `CC_OB_PDCMP_HDR_RAM_DATA_WD,
  parameter OB_PDCMP_HDR_RAM_ADDR_WD            = `CC_OB_PDCMP_HDR_RAM_ADDR_WD,
  parameter OB_PDCMP_HDR_RAM_PTR_WD             = `CC_OB_PDCMP_HDR_RAM_PTR_WD,
  parameter OB_PDCMP_DATA_RAM_DP                = `CC_OB_PDCMP_DATA_RAM_DP,
  parameter OB_PDCMP_DATA_RAM_DATA_WD           = `CC_OB_PDCMP_DATA_RAM_DATA_WD,
  parameter OB_PDCMP_DATA_RAM_ADDR_WD           = `CC_OB_PDCMP_DATA_RAM_ADDR_WD,
  parameter OB_PDCMP_DATA_RAM_PTR_WD            = `CC_OB_PDCMP_DATA_RAM_PTR_WD,
  parameter SYNC_DEPTH                          = 2,
   parameter CX_RAS_RAM_PROT_RANGE              = `CX_RAS_RAM_PROT_RANGE,
  parameter CC_AMBA_TLP_SEQ_WD                  = `CC_AMBA_TLP_SEQ_WD,
  parameter CX_NVC_LOG2                         = `CX_NVC_LOG2,
  parameter CX_NVC                              = `CX_NVC,
  parameter CC_ORDRB_NIDO                       = `CC_ORDRB_NIDO,
  parameter CC_ORDRB_NIDO_WD                    = `CC_ORDRB_NIDO_WD,
  parameter CC_NUM_DMA_RD_CHAN_WIDTH            = `CC_NUM_DMA_RD_CHAN_WIDTH,
  parameter TP                                  = `TP
  )
  
                        (
  input wire                                      core_clk,
  input wire                                      aux_clk_g,
  input wire                                      core_rst_n,
  input wire                                      slv_aclk,
  input wire                                      slv_aresetn,
  // ---------------------------------------------------------------------------
  // Configuration
  input wire [(3*NFUNC)-1:0]                      cfg_max_rd_req_size,
  input wire [(3*NFUNC)-1:0]                      cfg_max_payload_size,
  input  vc_map_s                                cfg_tc_struc_vc_map,
  input wire                                      cfg_ext_tag_en,
  input wire                                      cfg_10b_tag_en,
  input wire                                      cfg_10b_tag_en_cclk,
  input wire                                      cfg_ax_snp_en,
  input                                           cfg_ras_recc_ob_ccmp_data_correct,
  output wire                                     axi_ras_recc_corr_cnt_ob_ccmp_data_pulse,
  output wire                                     axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse,
  output wire [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]   axi_ras_recc_cnt_ob_ccmp_data_addr,
  output wire                                     axi_ras_par_ob_cpl_comp_dt_pulse,
  output ras_dp_err_log_t                         ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log,
  output ras_dp_err_log_t                         ob_cpl_comp_dt_ras_dp_err_log,

  input                                           cfg_ras_recc_ob_npdcmp_correct,
  output wire                                     axi_ras_recc_corr_cnt_ob_npdcmp_pulse,
  output wire                                     axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse,
  output wire [OB_NPDCMP_RAM_ADDR_WD-1:0]         axi_ras_recc_cnt_ob_npdcmp_addr,
  output ras_dp_err_log_t                         axi_recc_cnt_ob_npdcmp_ras_dp_err_log,

  input                                           cfg_ras_recc_ob_pdcmp_hdr_correct,
  output wire                                     axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse,
  output wire                                     axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse,
  output wire [OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      axi_ras_recc_cnt_ob_pdcmp_hdr_addr,

  input                                           cfg_ras_recc_ob_pdcmp_data_correct,
  output wire                                     axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse,
  output wire                                     axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse,
  output wire [OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     axi_ras_recc_cnt_ob_pdcmp_data_addr,
  output ras_dp_err_log_t                         axi_recc_cnt_ob_pdcmp_ras_dp_err_log,
  output ras_dp_err_log_t                         axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log,
  // ---------------------------------------------------------------------------
  // Slave Non-Posted Interface
  input wire                                      sif_np_rd,
  input wire                                      sif_np_wr,
  input wire                                      sif_np_atomic,
  input wire                                      sif_np_dmwr,
  input wire                                      sif_np_first_wrp_split_xact,
  input wire                                      sif_np_wrp_valid,
  input wire [MAX_SLV_TAG_PW-1:0]                 sif_np_tag,
  input wire [SLV_BUS_ADDR_WIDTH-1:0]             sif_np_addr,
  input wire [SLV_BUS_ID_WIDTH-1:0]               sif_np_id,
  input wire [SLV_BURST_LEN_PW-1:0]               sif_np_len,
  input wire [2:0]                                sif_np_size,
  input wire [1:0]                                sif_np_burst,
  input wire [SLV_BUS_NPWSTRB_WIDTH-1:0]          sif_np_strb,
  input wire [SLV_BUS_NPDATA_WIDTH-1:0]           sif_np_data,
  input wire [4:0]                                sif_np_type,
  input wire                                      sif_np_snp,
  input wire                                      sif_np_ns,
  input wire                                      sif_np_ro,
  input wire [2:0]                                sif_np_tc,
  input                                           sif_np_ep,
  input [NFUNC_WD-1:0]                            sif_np_func_num,
  input                                           sif_np_nw,
  input [1:0]                                     sif_np_ats,
  input [TX_TLP_PREFIX_WD-1:0]                    sif_np_tlpprfx,
  input [MISC_INFO_TPH_WD-1:0]                    sif_np_tph,
  input                                           sif_np_atu_bypass,
  input [8:0]                                     sif_np_dst_segment,
  input                                           sif_np_ido,
  input [DC_CPL_STATUS_WD-1:0]                    sif_np_cpl_stat,
  output wire                                     nprf_ready,
  // ---------------------------------------------------------------------------
  // TLP Non-Posted Interface
  output wire                                     client1_tlp_hv,
  output wire                                     client1_tlp_dv,
  output wire                                     client1_tlp_eot,
  output wire [7:0]                               client1_tlp_byte_en,
  output wire [1:0]                               client1_tlp_fmt,
  output wire [4:0]                               client1_tlp_type,
  output wire [2:0]                               client1_tlp_tc,
  output wire                                     client1_tlp_ep,
  output wire [ATTR_WD-1:0]                       client1_tlp_attr,
  output wire [12:0]                              client1_tlp_byte_len,
  output wire [CX_TAG_SIZE-1:0]                   client1_tlp_tid,
  output wire [63+ADDR_PAR_WD:0]                  client1_tlp_addr,
  output wire [CORE_DATA_BUS_WD-1:0]              client1_tlp_data,
  output wire [NFUNC_WD-1:0]                      client1_tlp_func_num,
  output wire [1:0]                               client1_tlp_ats,
  output wire                                     client1_tlp_nw,
  output wire                                     client1_tlp_th,
  output wire [1:0]                               client1_tlp_ph,
  output wire [7:0]                               client1_tlp_st,
  output wire [TX_TLP_PREFIX_WD-1:0]              client1_tlp_prfx,
  output wire                                     client1_tlp_atu_bypass,
  output wire [8:0]                               client1_tlp_dst_segment,
  input                                           xadm_client1_halt,
  // ---------------------------------------------------------------------------
  // Inbound Router interface
  input [DC_INBD_HEADER_CPL_WD-1:0]               ibrtr_inbd_header_cpl,
  input [CC_AMBA_TLP_SEQ_WD-1:0]                  ibrtr_inbd_header_cpl_pseq,
  input                                           ibrtr_inbd_header_cpl_pass_p,
  input [CORE_DATA_BUS_WD-1:0]                    ibrtr_inbd_data_cpl ,
  input [CX_NVC-1:0]                              trgt1_p_xfer_pend_per_vc,
  // ---------------------------------------------------------------------------
  // Completion Timeout Interface
  input                                           radm_cpl_timeout,
  input [2:0]                                     radm_timeout_cpl_tc,
  input [1:0]                                     radm_timeout_cpl_attr,
  input [CX_TAG_SIZE-1:0]                         radm_timeout_cpl_tag,
  input [NFUNC_WD-1:0]                            radm_timeout_func_num,
  // ---------------------------------------------------------------------------
  // Slave Completion Interface
  output wire                                     nprspf_valid,
  output wire                                     nprspf_last,
  output wire [SLV_BUS_DATA_WIDTH-1:0]            nprspf_data,
  output wire [MAX_SLV_TAG_PW-1:0]                nprspf_tag,
  output wire                                     nprspf_to,
  output wire                                     nprspf_ido,
  output wire                                     nprspf_ro,
  output wire                                     nprspf_ns,
  output wire [2:0]                               nprspf_tc,
  output wire [2:0]                               nprspf_func_num,
  output wire [2:0]                               nprspf_status,
  output wire                                     nprspf_ep,
  output wire [7:0]                               nprspf_cpl_segment,
  output wire [8:0]                               nprspf_dst_segment,
  input                                           sif_np_ready,
  // ---------------------------------------------------------------------------
  // Slave Posted Interface
  input                                           sif_p_valid,
  input [SLV_BUS_ADDR_WIDTH-1:0]                  sif_p_addr,
  input [SLV_BUS_ID_WIDTH-1:0]                    sif_p_id,
  input [2:0]                                     sif_p_size,
  input [SLV_BURST_LEN_PW-1:0]                    sif_p_len,
  input [DC_CPL_STATUS_WD-1:0]                    sif_p_cpl_stat,
  input                                           sif_p_last,
  input [SLV_BUS_WSTRB_WIDTH-1:0]                 sif_p_strb,
  input [SLV_BUS_WSTRB_WIDTH-1:0]                 sif_p_ep_strb,
  input [SLV_BUS_WSTRB_WIDTH-1:0]                 sif_p_silentDrop_strb,
  input [SLV_BUS_WSTRB_WIDTH-1:0]                 sif_p_silentDrop_strb_masked,
  input [SLV_BUS_DATA_WIDTH-1:0]                  sif_p_data,
  input [7:0]                                     sif_p_msg_code,
  input [4:0]                                     sif_p_type,
  input [2:0]                                     sif_p_tc,
  input                                           sif_p_ep,
  input                                           sif_p_ro,
  input                                           sif_p_ns,
  input                                           sif_p_first_wrp_split_xact,
  input                                           sif_p_wrp_valid,
  input [1:0]                                     sif_p_ats,
  input                                           sif_p_nw,
  input wire [NFUNC_WD-1:0]                       sif_p_func_num,
  input wire [MISC_INFO_TPH_WD-1:0]               sif_p_tph,
  input wire [TX_TLP_PREFIX_WD-1:0]               sif_p_prfx,
  input  wire [CX_TAG_SIZE-1:0]                   sif_p_tag,
  input wire                                      sif_p_atu_bypass,
  input wire [8:0]                                sif_p_dst_segment,
  input wire                                      sif_p_ido,
  output wire                                     prf_p_ready,
  // ---------------------------------------------------------------------------
  // TLP Posted Interface
  output wire                                     client2_tlp_hv,
  output wire                                     client2_tlp_dv,
  output wire                                     client2_tlp_eot,
  output wire [7:0]                               client2_tlp_byte_en,
  output wire [1:0]                               client2_tlp_fmt,
  output wire [4:0]                               client2_tlp_type,
  output wire [2:0]                               client2_tlp_tc,
  output wire                                     client2_tlp_ep,
  output wire                                     client2_tlp_silentDrop,
  output wire [ATTR_WD-1:0]                       client2_tlp_attr,
  output wire [12:0]                              client2_tlp_byte_len,
  output wire [63+ADDR_PAR_WD:0]                  client2_tlp_addr,
  output wire [CORE_DATA_BUS_WD-1:0]              client2_tlp_data,
  output wire [NFUNC_WD-1:0]                      client2_tlp_func_num,
  output wire [1:0]                               client2_tlp_ats,
  output wire                                     client2_tlp_nw,
  output wire                                     client2_tlp_th,
  output wire [1:0]                               client2_tlp_ph,
  output wire [7:0]                               client2_tlp_st,
  output wire [TX_TLP_PREFIX_WD-1:0]              client2_tlp_prfx,
  output wire [CX_TAG_SIZE-1:0]                   client2_p_tag,
  output wire                                     client2_tlp_atu_bypass,
  output wire [8:0]                               client2_tlp_dst_segment,
  input wire                                      xadm_client2_halt,
  // ---------------------------------------------------------------------------
  // Posted Response Interface
  output wire                                     pdcmp_p_rsp_valid,
  output wire [SLV_BUS_ID_WIDTH-1:0]              pdcmp_p_rsp_id,
  output wire [DC_CPL_STATUS_WD-1:0]              pdcmp_p_rsp_cpl_stat,
  output wire                                     pdcmp_p_rsp_null_or_err,
  output wire                                     pdcmp_p_rsp_last,
  output wire [2:0]                               pdcmp_p_rsp_vc_num,
  // -------------------------------------------------------------------------
  // Non Posted Atomic Response Interface
  output wire                                     npdcmp_np_atomic_rsp_valid,
  output wire [SLV_BUS_ID_WIDTH-1:0]              npdcmp_np_atomic_rsp_id,

  // ---------------------------------------------------------------------------
  // External RAM interfaces
  output wire [OB_NPDCMP_RAM_ADDR_WD-1:0]         npdcmp_ram_addra,
  output wire                       npdcmp_ram_wea,
  output wire [OB_NPDCMP_RAM_DATA_WD-1:0]         npdcmp_ram_dina,
  output wire [OB_NPDCMP_RAM_ADDR_WD-1:0]         npdcmp_ram_addrb,
  output wire                                     npdcmp_ram_enb,
  input wire [OB_NPDCMP_RAM_DATA_WD-1:0]          npdcmp_ram_doutb,

  output wire [OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      pdcmp_hdr_ram_addra,
  output wire                                     pdcmp_hdr_ram_wea,
  output wire [OB_PDCMP_HDR_RAM_DATA_WD-1:0]      pdcmp_hdr_ram_dina,
  output wire [OB_PDCMP_HDR_RAM_ADDR_WD-1:0]      pdcmp_hdr_ram_addrb,
  output wire                                     pdcmp_hdr_ram_enb,
  input wire [OB_PDCMP_HDR_RAM_DATA_WD-1:0]       pdcmp_hdr_ram_doutb,

  output wire [OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     pdcmp_data_ram_addra,
  output wire                                     pdcmp_data_ram_wea,
  output wire [OB_PDCMP_DATA_RAM_DATA_WD-1:0]     pdcmp_data_ram_dina,
  output wire [OB_PDCMP_DATA_RAM_ADDR_WD-1:0]     pdcmp_data_ram_addrb,
  output wire                                     pdcmp_data_ram_enb,
  input wire [OB_PDCMP_DATA_RAM_DATA_WD-1:0]      pdcmp_data_ram_doutb,

  output wire [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]   ccmp_data_ram_addra,
  output wire                                     ccmp_data_ram_wea,
  output wire [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]   ccmp_data_ram_dina,
  output wire [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]   ccmp_data_ram_addrb,
  output wire                                     ccmp_data_ram_enb,
  input wire [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]    ccmp_data_ram_doutb,
  // ---------------------------------------------------------------------------
  // Parity error interface
  output wire                                     client1_addr_parerr,
  output wire                                     client2_addr_parerr,
  output ras_dp_err_log_t                         npdcmp_ad_ras_dp_err_log,

  output wire                                     npdcmp_inq_data_parerr,
  output ras_dp_err_log_t                         npdcmp_inq_dt_ras_dp_err_log,
  output wire                                     pdcmp_inq_data_parerr,
  output ras_dp_err_log_t                         pdcmp_ad_ras_dp_err_log,
  output ras_dp_err_log_t                         pdcmp_inq_dt_ras_dp_err_log,
input ras_dp_err_inj_t                            ras_dp_err_inj_slv_aclk,
input ras_dp_err_inj_t                            axi_bridge_ras_dp_err_inj_core_clk,
input ras_dp_err_inj_t                            core_clk_ordrb_ras_dp_err_inj,
input ras_dp_err_inj_t                            core_clk_high_freq_ras_dp_err_inj,
input ras_dp_err_inj_t                            core_clk_hp_mstr_ras_dp_err_inj,
  // ---------------------------------------------------------------------------
  // Completed posted request sequence number interface
  input                  [CC_AMBA_TLP_SEQ_WD-1:0] ib_last_presp_rpseq_per_vc [       CX_NVC-1:0],
  // ---------------------------------------------------------------------------
  // CPL Composition Error
  output wire                                     radmx_cmposer_lookup_err
  );
  // ---------------------------------------------------------------------------
  // Local parameters
  // ---------------------------------------------------------------------------
  // Input packet length is max{slave read req size, slave max_mtu}
  localparam X1_IN_PKT_LEN_PW = (SLV_MAX_RD_SIZE_PW > SLV_MTU_PW) ? SLV_MAX_RD_SIZE_PW : SLV_MTU_PW;

  // Output packet length is max{cx_max_mtu, max read_req_size}.
  // Since max read request size is configured by host, worst case scenario is 4k = 13
  localparam X1_OUT_PKT_LEN_PW = 13;
  // Since max read request size is request by AXI, it's the slave's max read req size
  localparam X1_MAX_RD_SIZE_PW = SLV_MAX_RD_SIZE_PW;

  localparam X1_DATA_WIDTH                  = `CC_CORE_DATA_BUS_WD;
  localparam X1_USE_DWNCNVRT                = 0;
  localparam X1_DWNCNVRT_CONV_FAC_WIDTH     = 0;
  localparam X1_NW                          = `CX_NW;

  // ---------------------------------------------------------------------------
  // Internal Wires
  // ---------------------------------------------------------------------------
  // Slave Non-Posted Interface
//  wire [SLV_MISC_INFO_WD -1:0]             s_sif_misc_info;

  // Formed Non-Posted TLP Interface
  wire                                     nprf_hv;
  wire                                     nprf_dv;
  wire                                     nprf_eot;
  wire                                     nprf_bad_eot;
  wire [TX_TLP_PREFIX_WD-1:0]              nprf_prfx;
  wire                                     nprf_th;
  wire [1:0]                               nprf_ph;
  wire [7:0]                               nprf_st;
  wire                                     nprf_atu_bypass;
  wire [8:0]                               nprf_dst_segment;
  wire [1:0]                               nprf_ats;
  wire                                     nprf_nw;
  wire                                     nprf_first_wrp_split_xact;
  wire                                     nprf_wrp_valid;
  wire [MAX_SLV_TAG_PW -1:0]               nprf_tag;
  wire [SLV_BUS_ADDR_WIDTH-1 : 0]          nprf_addr;
  wire [SLV_BUS_NPDATA_WIDTH-1:0]          nprf_data;
  wire [1:0]                               nprf_fmt;
  wire [4:0]                               nprf_type;
  wire [2:0]                               nprf_tc;
  wire [ATTR_WD-1:0]                       nprf_attr;
  wire [DC_CPL_STATUS_WD -1:0]             nprf_cpl_stat;
  wire [SLV_MTU_PW -1:0]                   nprf_byte_len;
  wire                                     nprf_bcm;
  wire                                     nprf_snp;
  wire                                     nprf_ep;
  wire [7:0]                               nprf_be;
  wire [SLV_BUS_ID_WIDTH:0]                nprf_id;
  wire                                     npdcmp_halt;

  // Non-Posted Decomposer Request Info Interface
  wire                                     npdcmp_req_info_valid_hl;
  wire [SLV_BUS_ID_WIDTH:0]                npdcmp_req_info_id;
  wire [MAX_SLV_TAG_PW -1:0]               npdcmp_req_info_axi_tag;
  wire [MAX_WIRE_TAG_PW -1:0]              npdcmp_req_info_tlp_tag;
  wire [SLV_MAX_RD_SIZE_PW -1:0]           npdcmp_req_info_byte_len;
  wire                                     npdcmp_req_info_np_rd;
  wire                                     npdcmp_req_info_last_tlp;
  wire [DC_CPL_STATUS_WD-1:0]              npdcmp_req_info_cpl_stat;
  wire [NFUNC_WD-1:0]                      npdcmp_req_info_func_num;
  wire [2:0]                               npdcmp_req_info_tc;
  wire                                     cpl_cmp_err_req_halt;
  wire                                     s_xadm_client1_halt;

  // Completion Tag Recycle Interface
  wire                                     cmp_recycle_cpl_tag_hl;
  wire [MAX_WIRE_TAG_PW -1:0]              cmp_recycle_cpl_tag;
  wire                                     cmp_sb_init_done;

  // Non-Posted Decomposer
  wire                                     npdcmp_hv;
  wire                                     npdcmp_dv;
  wire                                     npdcmp_eot;
  wire [7:0]                               npdcmp_byte_en;
  wire [1:0]                               npdcmp_fmt;
  wire [4:0]                               npdcmp_type;
  wire [2:0]                               npdcmp_tc;
  wire                                     npdcmp_ep;
  wire [ATTR_WD-1:0]                       npdcmp_attr;
  wire [12:0]                              npdcmp_byte_len;
  wire [SLV_MAX_RD_SIZE_PW -1:0]           npdcmp_req_byte_len;
  wire [CX_TAG_SIZE-1:0]                   npdcmp_tid;
  wire [SLV_BUS_ID_WIDTH:0]                npdcmp_axi_id;
  wire [63+ADDR_PAR_WD:0]                  npdcmp_addr;
  wire [MAX_SLV_TAG_PW -1:0]               npdcmp_in_tag;
  wire [MAX_WIRE_TAG_PW -1:0]              npdcmp_out_tag;
  wire [CORE_DATA_BUS_WD-1:0]              npdcmp_data;
  wire [NFUNC_WD-1:0]                      npdcmp_func_num;
  wire [DC_CPL_STATUS_WD-1:0]              npdcmp_cpl_stat;
  wire [1:0]                               npdcmp_ats;
  wire                                     npdcmp_nw;
  wire                                     npdcmp_th;
  wire [1:0]                               npdcmp_ph;
  wire [7:0]                               npdcmp_st;
  wire [TX_TLP_PREFIX_WD-1:0]              npdcmp_prfx;
  wire                                     npdcmp_atu_bypass;
  wire [8:0]                               npdcmp_dst_segment;




  reg  [CX_TAG_SIZE-1:0]                   s_client1_tlp_tid;

  // Completion Composer
  reg  [PF_WD_MIN3-1:0]                    s_radm_timeout_func_num;
  wire [CX_TAG_SIZE-1:0]                   s_radm_timeout_cpl_tag;

  wire [MAX_SLV_TAG_PW-1:0]                slv_lookup_apptag;
  wire                                     slv_pop_wiretag;

  wire [MAX_WIRE_TAG_PW-1:0]               slv_lookup_wiretag;
  wire                                     slv_lookup_wiretag_is_last;

  wire [MAX_WIRE_TAG_PW-1:0]               rdr_lookup_wiretag;
  wire                                     rdr_pop_wiretag;

  // Composed Completion Response Interface
  wire                                     cmp_cpl_hv;
  wire                                     cmp_cpl_dv;
  wire                                     cmp_cpl_eot;
  wire [NPRSPF_TLP_DATA_WIDTH-1:0]         cmp_cpl_data;
  wire [SLV_MTU_PW-1:0]                    cmp_cpl_byte_len;
  wire [MAX_SLV_TAG_PW-1:0]                cmp_cpl_tag;
  wire                                     cmp_cpl_to;
  wire                                     cmp_cpl_ido;
  wire                                     cmp_cpl_ro;
  wire                                     cmp_cpl_ns;
  wire                               [2:0] cmp_cpl_tc;
  wire                               [2:0] cmp_cpl_func_num;
  wire [DC_CPL_STATUS_WD-1:0]              cmp_cpl_status;
  wire                                     cmp_cpl_ep;
  wire [7:0]                               cmp_cpl_cpl_segment;
  wire [8:0]                               cmp_cpl_dst_segment;
  wire                                     nprspf_halt;

  // Formed Posted Request Interface
  wire [7:0]                               prf_tlp_byte_en;
  wire                                     prf_tlp_dv;
  wire                                     prf_tlp_eot;
  wire                                     prf_tlp_hv;
  wire [1:0]                               prf_tlp_fmt;
  wire [4:0]                               prf_tlp_type;
  wire [2:0]                               prf_tlp_tc;
  wire                                     prf_tlp_ep;
  wire [ATTR_WD-1:0]                       prf_tlp_attr;
  wire [DC_CPL_STATUS_WD -1:0]             prf_tlp_cpl_stat;
  wire [SLV_MTU_PW-1:0]                    prf_tlp_byte_len;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            prf_tlp_addr;
  wire [PRF_TLP_DATA_WIDTH-1:0]            prf_tlp_data;
  wire [PRF_TLP_NUM_WSTRBS-1:0]            prf_tlp_ep_strb;
  wire [PRF_TLP_NUM_WSTRBS-1:0]            prf_tlp_silentDrop_strb;
  wire [PRF_TLP_NUM_WSTRBS-1:0]            prf_tlp_silentDrop_strb_masked;
  wire [PRF_TLP_NUM_WSTRBS-1:0]            prf_tlp_strb;
  wire [1:0]                               prf_tlp_ats;
  wire                                     prf_tlp_nw;
  wire [NFUNC_WD-1:0]                      prf_tlp_func_num;
  wire                                     prf_tlp_th;
  wire [1:0]                               prf_tlp_ph;
  wire [7:0]                               prf_tlp_st;
  wire [TX_TLP_PREFIX_WD-1:0]              prf_tlp_prfx;
  wire [CX_TAG_SIZE-1:0]                   prf_tlp_p_tag;
  wire                                     prf_tlp_atu_bypass;
  wire [8:0]                               prf_tlp_dst_segment;
  wire [SLV_BUS_ID_WIDTH-1:0]              prf_tlp_axi_id;
  wire                                     prf_first_wrp_split_xact;
  wire                                     prf_wrp_valid;
  wire                                     pdcmp_halt;

  wire                                     npdcmp_addr_parerr;
  wire                                     pdcmp_addr_parerr;

  wire                                     pdcmp_tlp_hv;
  wire                                     pdcmp_tlp_dv;
  wire                                     pdcmp_tlp_eot;
  wire [7:0]                               pdcmp_tlp_byte_en;
  wire [1:0]                               pdcmp_tlp_fmt;
  wire [4:0]                               pdcmp_tlp_type;
  wire [2:0]                               pdcmp_tlp_tc;
  wire                                     pdcmp_tlp_ep;
  wire                                     pdcmp_tlp_silentDrop;
  wire [ATTR_WD-1:0]                       pdcmp_tlp_attr;
  wire [12:0]                              pdcmp_tlp_byte_len;
  wire [63+ADDR_PAR_WD:0]                  pdcmp_tlp_addr;
  wire [CORE_DATA_BUS_WD-1:0]              pdcmp_tlp_data;
  wire [NFUNC_WD-1:0]                      pdcmp_tlp_func_num;
  wire [1:0]                               pdcmp_tlp_ats;
  wire                                     pdcmp_tlp_nw;
  wire                                     pdcmp_tlp_th;
  wire [1:0]                               pdcmp_tlp_ph;
  wire [7:0]                               pdcmp_tlp_st;
  wire [TX_TLP_PREFIX_WD-1:0]              pdcmp_tlp_prfx;
  wire [CX_TAG_SIZE-1:0]                   pdcmp_tlp_p_tag;
  wire                                     pdcmp_tlp_atu_bypass;
  wire [8:0]                               pdcmp_tlp_dst_segment;
  wire                                     dwnstrm_halt;


  // Design
  // ---------------------------------------------------------------------------
  assign xadmx1_decomp_hdr_ram_enb  = 1'b1; // dnolan
  assign xadmx1_decomp_data_ram_enb = 1'b1;
  assign radmx_asyn_ram_enb         = 1'b1;

  DWC_pcie_axi_ob_np_formation
  
  u_nprf
   (
    .slv_aclk                       ( slv_aclk                    ),
    .slv_aresetn                    ( slv_aresetn                 ),
  // ---------------------------------------------------------------------------
  // AXI Non-Posted request interface
    .sif_np_cpl_stat                ( sif_np_cpl_stat             ),
    .sif_np_tlpprfx                 ( sif_np_tlpprfx              ),
    .sif_np_th                      ( sif_np_tph[0]               ),
    .sif_np_ph                      ( sif_np_tph[2:1]             ),
    .sif_np_st                      ( sif_np_tph[10:3]            ),
    .sif_np_atu_bypass              ( sif_np_atu_bypass           ),
    .sif_np_dst_segment             ( sif_np_dst_segment          ),
    .sif_np_nw                      ( sif_np_nw                   ),
    .sif_np_ats                     ( sif_np_ats                  ),
    .sif_np_ido                     ( sif_np_ido                  ),
    .sif_np_snp                     ( sif_np_snp                  ),
    .sif_np_size                    ( sif_np_size                 ),
    .sif_np_burst                   ( sif_np_burst                ),
    .sif_np_tag                     ( sif_np_tag                  ),
    .sif_np_id                      ( sif_np_id                   ),
    .sif_np_len                     ( sif_np_len                  ),
    .sif_np_tc                      ( sif_np_tc                   ),
    .sif_np_ep                      ( sif_np_ep                   ),
    .sif_np_ro                      ( sif_np_ro                   ),
    .sif_np_ns                      ( sif_np_ns                   ),
    .sif_np_wr                      ( sif_np_wr                   ),
    .sif_np_rd                      ( sif_np_rd                   ),
    .sif_np_atomic                  ( sif_np_atomic               ),
    .sif_np_dmwr                    ( sif_np_dmwr                 ),
    .sif_np_first_wrp_split_xact    ( sif_np_first_wrp_split_xact ),
    .sif_np_wrp_valid               ( sif_np_wrp_valid            ),
    .sif_np_type                    ( sif_np_type                 ),
    .sif_np_addr                    ( sif_np_addr                 ),
    .sif_np_strb                    ( sif_np_strb                 ),
    .sif_np_data                    ( sif_np_data                 ),
    .nprf_ready                     ( nprf_ready                  ),
// -------------------------------------------------------------------------------------
// TLP Non-Posted request interface
    .nprf_cpl_stat                  ( nprf_cpl_stat               ),
    .nprf_prfx                      ( nprf_prfx                   ),
    .nprf_th                        ( nprf_th                     ),
    .nprf_ph                        ( nprf_ph                     ),
    .nprf_st                        ( nprf_st                     ),
    .nprf_atu_bypass                ( nprf_atu_bypass             ),
    .nprf_dst_segment               ( nprf_dst_segment            ),
    .nprf_ats                       ( nprf_ats                    ),
    .nprf_nw                        ( nprf_nw                     ),
    .nprf_first_wrp_split_xact      ( nprf_first_wrp_split_xact   ),
    .nprf_wrp_valid                 ( nprf_wrp_valid              ),
    .nprf_snp                       ( nprf_snp                    ),
    .nprf_tag                       ( nprf_tag                    ),
    .nprf_id                        ( nprf_id                     ),
    .nprf_byte_len                  ( nprf_byte_len               ),
    .nprf_tc                        ( nprf_tc                     ),
    .nprf_be                        ( nprf_be                     ),
    .nprf_ep                        ( nprf_ep                     ),
    .nprf_attr                      ( nprf_attr                   ),
    .nprf_fmt                       ( nprf_fmt                    ),
    .nprf_type                      ( nprf_type                   ),
    .nprf_addr                      ( nprf_addr                   ),
    .nprf_data                      ( nprf_data                   ),
    .nprf_hv                        ( nprf_hv                     ),
    .nprf_dv                        ( nprf_dv                     ),
    .nprf_eot                       ( nprf_eot                    ),
    .nprf_bad_eot                   ( nprf_bad_eot                ),
    .npdcmp_halt                    ( npdcmp_halt                 )
  );

assign s_radm_timeout_cpl_tag = radm_timeout_cpl_tag - ( cfg_10b_tag_en_cclk ? 10'h100 : 10'h000 );

logic [MAX_WIRE_TAG :0] s_wtag_active_lut;

DWC_pcie_bridge_ob_np_dcmp

  u_npdcmp (
    .slv_aclk                               ( slv_aclk                               ),
    .slv_aresetn                            ( slv_aresetn                            ),
    .core_clk                               ( core_clk                               ),
    .core_rst_n                             ( core_rst_n                             ),

    // Configuration interface
    .cfg_ext_tag_en                         ( cfg_ext_tag_en                         ),
    .cfg_10b_tag_en                         ( cfg_10b_tag_en                         ),
    .cfg_max_rd_req_size                    ( cfg_max_rd_req_size                    ),
    .cfg_ax_snp_en                          ( cfg_ax_snp_en                          ),
    .cfg_ras_recc_ob_npdcmp_correct         ( cfg_ras_recc_ob_npdcmp_correct         ),
    .axi_ras_recc_corr_cnt_ob_npdcmp_pulse  ( axi_ras_recc_corr_cnt_ob_npdcmp_pulse  ),
    .axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse ( axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse ),
    .axi_ras_recc_cnt_ob_npdcmp_addr        ( axi_ras_recc_cnt_ob_npdcmp_addr        ),
    .axi_recc_cnt_ob_npdcmp_ras_dp_err_log  ( axi_recc_cnt_ob_npdcmp_ras_dp_err_log  ),
    // Request packet interface
    .npdcmp_halt                            ( npdcmp_halt                            ),
    .nprf_hv                                ( nprf_hv                                ),
    .nprf_dv                                ( nprf_dv                                ),
    .nprf_eot                               ( nprf_eot                               ),
    .nprf_bad_eot                           ( nprf_bad_eot                           ),
    .nprf_tlp_prfx                          ( nprf_prfx                              ),
    .nprf_th                                ( nprf_th                                ),
    .nprf_ph                                ( nprf_ph                                ),
    .nprf_st                                ( nprf_st                                ),
    .nprf_atu_bypass                        ( nprf_atu_bypass                        ),
    .nprf_dst_segment                       ( nprf_dst_segment                       ),
    .nprf_ats                               ( nprf_ats                               ),
    .nprf_nw                                ( nprf_nw                                ),
    .nprf_first_wrp_split_xact              ( nprf_first_wrp_split_xact              ),
    .nprf_wrp_valid                         ( nprf_wrp_valid                         ),
    .nprf_snp                               ( nprf_snp                               ),
    .nprf_tag                               ( nprf_tag                               ),
    .nprf_id                                ( nprf_id                                ),
    .nprf_cpl_stat                          ( nprf_cpl_stat                          ),
    .nprf_byte_len                          ( nprf_byte_len                          ),
    .nprf_tc                                ( nprf_tc                                ),
    .nprf_ep                                ( nprf_ep                                ),
    .nprf_attr                              ( nprf_attr                              ),
    .nprf_be                                ( nprf_be                                ),
    .nprf_fmt                               ( nprf_fmt                               ),
    .nprf_type                              ( nprf_type                              ),
    .nprf_addr                              ( nprf_addr                              ),
    .nprf_data                              ( nprf_data                              ),
    .ibrtr_inbd_hv                          ( ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_HV_HIGH         : `INBD_HDR_CPL_RANGE_HV_LOW]         ),
    .ibrtr_inbd_tag                         ( ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_TAG_HIGH        : `INBD_HDR_CPL_RANGE_TAG_LOW ]       ),
    .ibrtr_inbd_last                        ( ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_LAST_HIGH       : `INBD_HDR_CPL_RANGE_LAST_LOW]       ),
    .ibrtr_inbd_dllp_abort                  ( ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_DLLP_ABORT_HIGH : `INBD_HDR_CPL_RANGE_DLLP_ABORT_LOW] ),
    .ibrtr_inbd_tlp_abort                   ( ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_TLP_ABORT_HIGH  : `INBD_HDR_CPL_RANGE_TLP_ABORT_LOW]  ),
    .ibrtr_inbd_eot                         ( ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_EOT_HIGH        : `INBD_HDR_CPL_RANGE_EOT_LOW ]       ),
    .radm_cpl_timeout                       ( radm_cpl_timeout                       ),
    .radm_timeout_cpl_tag                   ( s_radm_timeout_cpl_tag                 ),
    .client1_halt                           ( s_xadm_client1_halt                    ),
    .npdcmp_hv                              ( npdcmp_hv                              ),
    .npdcmp_dv                              ( npdcmp_dv                              ),
    .npdcmp_eot                             ( npdcmp_eot                             ),
    .npdcmp_tlp_prfx                        ( npdcmp_prfx                            ),
    .npdcmp_th                              ( npdcmp_th                              ),
    .npdcmp_ph                              ( npdcmp_ph                              ),
    .npdcmp_st                              ( npdcmp_st                              ),
    .npdcmp_atu_bypass                      ( npdcmp_atu_bypass                      ),
    .npdcmp_dst_segment                     ( npdcmp_dst_segment                     ),
    .npdcmp_ats                             ( npdcmp_ats                             ),
    .npdcmp_nw                              ( npdcmp_nw                              ),
    .npdcmp_func_num                        ( npdcmp_func_num                        ),
    .npdcmp_last_tlp                        ( npdcmp_last_tlp                        ),
    .npdcmp_4rd                             ( npdcmp_4rd                             ),
    .npdcmp_req_byte_len                    ( npdcmp_req_byte_len                    ),
    .npdcmp_in_tag                          ( npdcmp_in_tag                          ),
    .npdcmp_axi_id                          ( npdcmp_axi_id                          ),
    .npdcmp_out_tag                         ( npdcmp_out_tag                         ),
    .npdcmp_cpl_stat                        ( npdcmp_cpl_stat                        ),
    .npdcmp_byte_len                        ( npdcmp_byte_len                        ),
    .npdcmp_tc                              ( npdcmp_tc                              ),
    .npdcmp_ep                              ( npdcmp_ep                              ),
    .npdcmp_attr                            ( npdcmp_attr                            ),
    .npdcmp_byte_en                         ( npdcmp_byte_en                         ),
    .npdcmp_fmt                             ( npdcmp_fmt                             ),
    .npdcmp_type                            ( npdcmp_type                            ),
    .npdcmp_addr                            ( npdcmp_addr                            ),
    .npdcmp_data                            ( npdcmp_data                            ),
    // Non Posted Atomic Response Interface
    .npdcmp_np_atomic_rsp_valid             ( npdcmp_np_atomic_rsp_valid             ),
    .npdcmp_np_atomic_rsp_id                ( npdcmp_np_atomic_rsp_id                ),
    .npdcmp_ram_addra                       ( npdcmp_ram_addra                       ),
    .npdcmp_ram_wea                         ( npdcmp_ram_wea                         ),
    .npdcmp_ram_dina                        ( npdcmp_ram_dina                        ),
    .npdcmp_ram_addrb                       ( npdcmp_ram_addrb                       ),
    .npdcmp_ram_enb                         ( npdcmp_ram_enb                         ),
    .npdcmp_ram_doutb                       ( npdcmp_ram_doutb                       ),

    .npdcmp_addr_parerr                     ( npdcmp_addr_parerr                     ),
    .npdcmp_inq_data_parerr                 ( npdcmp_inq_data_parerr                 ),
    .npdcmp_inq_dt_ras_dp_err_log           ( npdcmp_inq_dt_ras_dp_err_log           ),
    .npdcmp_ad_ras_dp_err_log               ( npdcmp_ad_ras_dp_err_log               ),
    .ras_dp_err_inj_slv_aclk                ( ras_dp_err_inj_slv_aclk                ),
    .axi_bridge_ras_dp_err_inj_core_clk     ( core_clk_high_freq_ras_dp_err_inj      ),  // u_npdcmp.u_hdf

    .rls_tag                                ( cmp_recycle_cpl_tag_hl                 ),
    .rls_tag_num                            ( cmp_recycle_cpl_tag                    ),
    .cmp_sb_init_done                       ( cmp_sb_init_done                       ),

    .slv_lookup_apptag                      ( slv_lookup_apptag                      ),
    .slv_pop_wiretag                        ( slv_pop_wiretag                        ),
    .slv_lookup_wiretag                     ( slv_lookup_wiretag                     ),
    .slv_lookup_wiretag_is_last             ( slv_lookup_wiretag_is_last             )

   ,.rdr_lookup_wiretag                     ( rdr_lookup_wiretag                     )
   ,.rdr_pop_wiretag                        ( rdr_pop_wiretag                        )

   ,.s_wtag_active_lut                      ( s_wtag_active_lut                      )
   );

assign npdcmp_err_req           = npdcmp_cpl_stat != {(DC_CPL_STATUS_WD){1'b0}};

assign npdcmp_req_info_valid_hl = npdcmp_err_req ? ( npdcmp_hv && !cpl_cmp_err_req_halt ) : ( client1_tlp_hv && !xadm_client1_halt );
assign s_xadm_client1_halt      = npdcmp_err_req ? cpl_cmp_err_req_halt : xadm_client1_halt;

assign client1_tlp_hv           = npdcmp_hv  && !npdcmp_err_req;
assign client1_tlp_dv           = npdcmp_dv  && !npdcmp_err_req;
assign client1_tlp_eot          = npdcmp_eot && !npdcmp_err_req;
assign client1_tlp_prfx         = npdcmp_prfx;
assign client1_tlp_th           = npdcmp_th;
assign client1_tlp_ph           = npdcmp_ph;
assign client1_tlp_st           = npdcmp_st;
assign client1_tlp_atu_bypass   = npdcmp_atu_bypass;
assign client1_tlp_dst_segment  = npdcmp_dst_segment;
assign client1_tlp_ats          = npdcmp_ats;
assign client1_tlp_nw           = npdcmp_nw;
assign client1_tlp_func_num     = npdcmp_func_num;
assign client1_tlp_byte_len     = npdcmp_byte_len;
assign client1_tlp_tc           = npdcmp_tc;
assign client1_tlp_ep           = npdcmp_ep;
assign client1_tlp_attr         = npdcmp_attr;
assign client1_tlp_byte_en      = npdcmp_byte_en;
assign client1_tlp_fmt          = npdcmp_fmt;
assign client1_tlp_type         = npdcmp_type;
assign client1_tlp_addr         = npdcmp_addr;
assign client1_tlp_data         = npdcmp_data;

assign npdcmp_req_info_last_tlp = npdcmp_last_tlp;
assign npdcmp_req_info_cpl_stat = npdcmp_cpl_stat;
assign npdcmp_req_info_np_rd    = npdcmp_4rd;
assign npdcmp_req_info_byte_len = npdcmp_req_byte_len;
assign npdcmp_req_info_axi_tag  = npdcmp_in_tag;
assign npdcmp_req_info_id       = npdcmp_axi_id;
assign npdcmp_req_info_tlp_tag  = npdcmp_out_tag;
assign npdcmp_req_info_func_num = npdcmp_func_num;
assign npdcmp_req_info_tc       = npdcmp_tc;

  always @(*) begin : proc_comb_np_tag
   s_client1_tlp_tid = {{(10-MAX_WIRE_TAG_PW){1'b0}},npdcmp_out_tag} + ( cfg_10b_tag_en_cclk ? 10'h100 : 10'h000 );
  end

  assign client1_tlp_tid = s_client1_tlp_tid;


  assign client1_addr_parerr = npdcmp_addr_parerr;
  assign client2_addr_parerr = pdcmp_addr_parerr;
  //assign client2_data_parerr = pdcmp_data_parerr;


  // ---------------------------------------------------------------------------
  // Completion Composer
  // ---------------------------------------------------------------------------
  always @ (*) begin : proc_gen_timeout_func_num
   integer i;
   s_radm_timeout_func_num = 0;

   for (i=0; i<NFUNC_WD; i=i+1)
     s_radm_timeout_func_num[i] = radm_timeout_func_num[i];
  end

  logic consumed_tag_from_nprf;
  assign consumed_tag_from_nprf = (!npdcmp_halt) && nprf_hv && (!nprf_wrp_valid || !nprf_first_wrp_split_xact);

  DWC_pcie_axi_cpl_comp
  
  #(
  .SLV_BUS_ID_WIDTH                 (SLV_BUS_ID_WIDTH       ),
  .MAX_SLV_TAG_PW                   (MAX_SLV_TAG_PW         ),
  .MAX_WIRE_TAG                     (MAX_WIRE_TAG           ),
  .MAX_WIRE_TAG_PW                  (MAX_WIRE_TAG_PW        ),
  .SLV_MAX_RD_SIZE_PW               (SLV_MAX_RD_SIZE_PW     ),
  .NFUNC_WD                         (NFUNC_WD               ),
  .NW                               (NW                     ),
  .CORE_DATA_BUS_WD                 (CORE_DATA_BUS_WD       ),
  .DC_INBD_HEADER_CPL_WD            (DC_INBD_HEADER_CPL_WD),
  .PF_WD_MIN3                       (PF_WD_MIN3             ),
  .NPRSPF_TLP_DATA_WIDTH            (NPRSPF_TLP_DATA_WIDTH  ),
  .NPRSPF_TLP_DATA_WIDTH_NP         (NPRSPF_TLP_DATA_WIDTH_NP ),
  .NPRSPF_TLP_NUM_DWORDS            (NPRSPF_TLP_NUM_DWORDS  ),
  .CC_RADMX_COMPOSER_HDR_WD         (COMPOSER_HDR_WD        ),
  .CC_OB_CCMP_DATA_RAM_DATA_WD      (CC_OB_CCMP_DATA_RAM_DATA_WD),
  .CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC(CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC),
  .CC_OB_CCMP_DATA_RAM_ADDR_WD      (CC_OB_CCMP_DATA_RAM_ADDR_WD),
  .SYNC_DEPTH                       (SYNC_DEPTH             )
  )
  u_cmp
  (
  // ---------------------------------------------------------------------------
  // Clocks and resets
   .core_clk                                  ( core_clk                                  )
  ,.core_rst_n                                ( core_rst_n                                )
  ,.slv_aclk                                  ( slv_aclk                                  )
  ,.slv_aresetn                               ( slv_aresetn                               )
  // ---------------------------------------------------------------------------
  // Configuration signals
  // ---------------------------------------------------------------------------
  // RAS signals
  ,.cfg_ras_recc_ob_ccmp_data_correct         ( cfg_ras_recc_ob_ccmp_data_correct         )
  ,.axi_ras_recc_corr_cnt_ob_ccmp_data_pulse  ( axi_ras_recc_corr_cnt_ob_ccmp_data_pulse  )
  ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse ( axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse )
  ,.axi_ras_recc_cnt_ob_ccmp_data_addr        ( axi_ras_recc_cnt_ob_ccmp_data_addr        )
  ,.axi_ras_par_ob_cpl_comp_dt_pulse          ( axi_ras_par_ob_cpl_comp_dt_pulse          )
  ,.ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log    ( ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log    )
  ,.ob_cpl_comp_dt_ras_dp_err_log             ( ob_cpl_comp_dt_ras_dp_err_log             )
  ,.axi_bridge_ras_dp_err_inj_core_clk       (axi_bridge_ras_dp_err_inj_core_clk)
  ,.ras_dp_err_inj_slv_aclk                  (ras_dp_err_inj_slv_aclk)
  ,.core_clk_ordrb_ras_dp_err_inj            (core_clk_ordrb_ras_dp_err_inj)
  // ---------------------------------------------------------------------------
  // Inbound router interface
  ,.ibrtr_inbd_header_cpl                     ( ibrtr_inbd_header_cpl                     )
  ,.ibrtr_inbd_header_cpl_pseq                ( ibrtr_inbd_header_cpl_pseq                )
  ,.ibrtr_inbd_header_cpl_pass_p              ( ibrtr_inbd_header_cpl_pass_p              )
  ,.ibrtr_inbd_data_cpl                       ( ibrtr_inbd_data_cpl                       )
  ,.trgt1_p_xfer_pend_per_vc                  ( trgt1_p_xfer_pend_per_vc                  )
  // ---------------------------------------------------------------------------
  // Completion timeout interface
  ,.radm_cpl_timeout                          ( radm_cpl_timeout                          )
  ,.radm_cpl_timeout_tc                       ( radm_timeout_cpl_tc                       )
  ,.radm_cpl_timeout_attr                     ( radm_timeout_cpl_attr                     )
  ,.radm_cpl_timeout_tag                      ( s_radm_timeout_cpl_tag                    )
  ,.radm_timeout_func_num                     ( s_radm_timeout_func_num                   )
  // ---------------------------------------------------------------------------
  // Outbound Non Posted Decomposer request interface
  ,.cpl_cmp_err_req_halt                      ( cpl_cmp_err_req_halt                      )
  ,.npdcmp_req_tag_consumed                   ( npdcmp_req_info_valid_hl                  )
  ,.npdcmp_req_cpl_stat                       ( npdcmp_req_info_cpl_stat                  )
  ,.npdcmp_req_app_tag                        ( npdcmp_req_info_axi_tag                   )
  ,.npdcmp_req_wire_tag                       ( npdcmp_req_info_tlp_tag                   )
  ,.npdcmp_req_last_tlp                       ( npdcmp_req_info_last_tlp                  )
  ,.npdcmp_req_4rd                            ( npdcmp_req_info_np_rd                     ) // dnolan: redundant
  ,.npdcmp_req_byte_len                       ( npdcmp_req_info_byte_len                  )
  ,.npdcmp_req_axi_id                         ( npdcmp_req_info_id                        )
  ,.npdcmp_req_func_num                       ( npdcmp_req_info_func_num                  )
  ,.npdcmp_req_tc                             ( npdcmp_req_info_tc                        )
  // ---------------------------------------------------------------------------
  // Completion Composer interface
  ,.cmp_cpl_hv                                ( cmp_cpl_hv                                )
  ,.cmp_cpl_dv                                ( cmp_cpl_dv                                )
  ,.cmp_cpl_eot                               ( cmp_cpl_eot                               )
  ,.cmp_cpl_data                              ( cmp_cpl_data                              )
  ,.cmp_cpl_byte_len                          ( cmp_cpl_byte_len                          )
  ,.cmp_cpl_tag                               ( cmp_cpl_tag                               )
  ,.cmp_cpl_to                                ( cmp_cpl_to                                )
  ,.cmp_cpl_ido                               ( cmp_cpl_ido                               )
  ,.cmp_cpl_ro                                ( cmp_cpl_ro                                )
  ,.cmp_cpl_ns                                ( cmp_cpl_ns                                )
  ,.cmp_cpl_tc                                ( cmp_cpl_tc                                )
  ,.cmp_cpl_func_num                          ( cmp_cpl_func_num                          )
  ,.cmp_cpl_status                            ( cmp_cpl_status                            )
  ,.cmp_cpl_ep                                ( cmp_cpl_ep                                )
  ,.cmp_cpl_cpl_segment                       ( cmp_cpl_cpl_segment                       )
  ,.cmp_cpl_dst_segment                       ( cmp_cpl_dst_segment                       )
  ,.slv_rsp_cycle_halt                        ( nprspf_halt                               )
  ,.consumed_tag_from_nprf                    ( consumed_tag_from_nprf                    )
  ,.nprf_id                                   ( nprf_id                                   )
  ,.nprf_tag                                  ( nprf_tag                                  )
  // ---------------------------------------------------------------------------
  // Segmented Buffer RAM interface
  // ---------------------------------------------------------------------------
  ,.ccmp_data_ram_doutb                       ( ccmp_data_ram_doutb                       )
  ,.ccmp_data_ram_addra                       ( ccmp_data_ram_addra                       )
  ,.ccmp_data_ram_addrb                       ( ccmp_data_ram_addrb                       )
  ,.ccmp_data_ram_dina                        ( ccmp_data_ram_dina                        )
  ,.ccmp_data_ram_enb                         ( ccmp_data_ram_enb                         )
  ,.ccmp_data_ram_wea                         ( ccmp_data_ram_wea                         )
  ,.cmp_lookup_err                            ( radmx_cmposer_lookup_err                  )
  ,.cmp_tag_released                          ( cmp_recycle_cpl_tag_hl                    )
  ,.cmp_tag_num                               ( cmp_recycle_cpl_tag                       )
  ,.cmp_sb_init_done                          ( cmp_sb_init_done                          )

  ,.slv_lookup_apptag                         ( slv_lookup_apptag                         )
  ,.slv_pop_wiretag                           ( slv_pop_wiretag                           )
  ,.slv_lookup_wiretag                        ( slv_lookup_wiretag                        )
  ,.slv_lookup_wiretag_is_last                ( slv_lookup_wiretag_is_last                )

  ,.rdr_lookup_wiretag                        ( rdr_lookup_wiretag                        )
  ,.rdr_pop_wiretag                           ( rdr_pop_wiretag                           )
  ,.ib_last_presp_rpseq_per_vc                ( ib_last_presp_rpseq_per_vc                )
  ,.s_wtag_active_lut                         ( s_wtag_active_lut                         )

  );


  // ---------------------------------------------------------------------------
  // Non-Posted Response Formation
  DWC_pcie_axi_ob_rsp_formation
  
  #(.SLV_MAX_RD_SIZE_PW               (SLV_MAX_RD_SIZE_PW)
   ,.SLV_BUS_DATA_WIDTH               (SLV_BUS_DATA_WIDTH)
   ,.NPRSPF_TLP_DATA_WIDTH            (NPRSPF_TLP_DATA_WIDTH)
   ,.NPRSPF_TLP_NUM_STRBS             (NPRSPF_TLP_NUM_STRBS)
   ,.SLV_CONV_FAC_WIDTH               (SLV_CONV_FAC_WIDTH)
   ,.NFUNC_WD                         (3)
   ,.SLV_MTU_PW                       (SLV_MTU_PW)
   ,.MAX_SLV_TAG_PW                   (MAX_SLV_TAG_PW)
   ,.NW                               (NW)
  )
  u_nprspf
  (.slv_aclk                          (slv_aclk)
  ,.slv_aresetn                       (slv_aresetn)
  // ---------------------------------------------------------------------------
  // Composed completion interface
  ,.cmp_cpl_hv                        (cmp_cpl_hv)
  ,.cmp_cpl_dv                        (cmp_cpl_dv)
  ,.cmp_cpl_eot                       (cmp_cpl_eot)
  ,.cmp_cpl_data                      (cmp_cpl_data)
  ,.cmp_cpl_byte_len                  (cmp_cpl_byte_len)
  ,.cmp_cpl_tag                       (cmp_cpl_tag[MAX_SLV_TAG_PW-1:0])
  ,.cmp_cpl_to                        (cmp_cpl_to)
  ,.cmp_cpl_ido                       (cmp_cpl_ido)
  ,.cmp_cpl_ro                        (cmp_cpl_ro)
  ,.cmp_cpl_ns                        (cmp_cpl_ns)
  ,.cmp_cpl_tc                        (cmp_cpl_tc)
  ,.cmp_cpl_func_num                  (cmp_cpl_func_num)
  ,.cmp_cpl_status                    (cmp_cpl_status)
  ,.cmp_cpl_ep                        (cmp_cpl_ep)
  ,.cmp_cpl_cpl_segment               (cmp_cpl_cpl_segment)
  ,.cmp_cpl_dst_segment               (cmp_cpl_dst_segment)
  ,.nprspf_halt                       (nprspf_halt)
  // ---------------------------------------------------------------------------
  // AXI Slave response interface
  ,.nprspf_valid                      (nprspf_valid)
  ,.nprspf_last                       (nprspf_last)
  ,.nprspf_data                       (nprspf_data)
  ,.nprspf_tag                        (nprspf_tag)
  ,.nprspf_to                         (nprspf_to)
  ,.nprspf_ido                        (nprspf_ido)
  ,.nprspf_ro                         (nprspf_ro)
  ,.nprspf_ns                         (nprspf_ns)
  ,.nprspf_tc                         (nprspf_tc)
  ,.nprspf_func_num                   (nprspf_func_num)
  ,.nprspf_status                     (nprspf_status)
  ,.nprspf_ep                         (nprspf_ep)
  ,.nprspf_cpl_segment                (nprspf_cpl_segment)
  ,.nprspf_dst_segment                (nprspf_dst_segment)
  ,.sif_np_ready                      (sif_np_ready)
  );

  // ---------------------------------------------------------------------------
  // Posted Request Formation
  DWC_pcie_axi_ob_p_formation
  
  #(.SLV_BUS_ID_WIDTH                 (SLV_BUS_ID_WIDTH)
   ,.SLV_BUS_ADDR_WIDTH               (SLV_BUS_ADDR_WIDTH)
   ,.SLAVE_BUS_ADDR_WIDTH             (SLAVE_BUS_ADDR_WIDTH)
   ,.SLV_BURST_LEN_PW                 (SLV_BURST_LEN_PW)
   ,.SLV_BUS_WSTRB_WIDTH              (SLV_BUS_WSTRB_WIDTH)
   ,.SLV_BUS_DATA_WIDTH               (SLV_BUS_DATA_WIDTH)
   ,.NFUNC_WD                         (NFUNC_WD)
   ,.MISC_INFO_TPH_WD                 (MISC_INFO_TPH_WD)
   ,.TX_TLP_PREFIX_WD                 (TX_TLP_PREFIX_WD)
   ,.SLV_MTU_PW                       (SLV_MTU_PW)
   ,.PRF_TLP_DATA_WIDTH               (PRF_TLP_DATA_WIDTH)
   ,.PRF_TLP_NUM_WSTRBS               (PRF_TLP_NUM_WSTRBS)
   ,.PRF_TLP_NUM_WSTRBS_GT_4          (PRF_TLP_NUM_WSTRBS_GT_4)
   ,.PRF_TLP_NUM_DWORDS               (PRF_TLP_NUM_DWORDS)
   ,.SLV_CONV_FAC_WIDTH               (SLV_CONV_FAC_WIDTH)
   ,.CX_RAS_PROT_RANGE                (CX_RAS_PROT_RANGE)
  )
  u_prf
  (
  // Clocks and Resets
  .slv_aclk                                (slv_aclk),
  .slv_aresetn                             (slv_aresetn),
  // Slave Posted Request interface
  .sif_p_valid                             (sif_p_valid),
  .sif_p_axi_id                            (sif_p_id),
  .sif_p_addr                              (sif_p_addr),
  .sif_p_size                              (sif_p_size),
  .sif_p_cpl_stat                          (sif_p_cpl_stat),
  .sif_p_len                               (sif_p_len),
  .sif_p_last                              (sif_p_last),
  .sif_p_strb                              (sif_p_strb),
  .sif_p_ep_strb                           (sif_p_ep_strb),
  .sif_p_silentDrop_strb                   (sif_p_silentDrop_strb),
  .sif_p_silentDrop_strb_masked            (sif_p_silentDrop_strb_masked),
  .sif_p_data                              (sif_p_data),
  .sif_p_msg_code                          (sif_p_msg_code),
  .sif_p_type                              (sif_p_type),
  .sif_p_tc                                (sif_p_tc),
  .sif_p_ep                                (sif_p_ep),
  .sif_p_ro                                (sif_p_ro),
  .sif_p_ns                                (sif_p_ns),
  .sif_p_first_wrp_split_xact              (sif_p_first_wrp_split_xact),
  .sif_p_wrp_valid                         (sif_p_wrp_valid),
  .sif_p_nw                                (sif_p_nw),
  .sif_p_ats                               (sif_p_ats),
  .sif_p_func_num                          (sif_p_func_num),
  .sif_p_tph                               (sif_p_tph),
  .sif_p_prfx                              (sif_p_prfx),
  .sif_p_tag                               (sif_p_tag),
  .sif_p_atu_bypass                        (sif_p_atu_bypass),
  .sif_p_dst_segment                       (sif_p_dst_segment),
  .sif_p_ido                               (sif_p_ido),
  .prf_p_ready                             (prf_p_ready),
   // Formed Posted  Request TLP Interface
  .prf_tlp_byte_en                         (prf_tlp_byte_en),
  .prf_tlp_dv                              (prf_tlp_dv),
  .prf_tlp_eot                             (prf_tlp_eot),
  .prf_tlp_hv                              (prf_tlp_hv),
  .prf_tlp_fmt                             (prf_tlp_fmt),
  .prf_tlp_type                            (prf_tlp_type),
  .prf_tlp_tc                              (prf_tlp_tc),
  .prf_tlp_ep                              (prf_tlp_ep),
  .prf_tlp_attr                            (prf_tlp_attr),
  .prf_tlp_cpl_stat                        (prf_tlp_cpl_stat),
  .prf_tlp_byte_len                        (prf_tlp_byte_len),
  .prf_tlp_addr                            (prf_tlp_addr),
  .prf_tlp_data                            (prf_tlp_data),
  .prf_tlp_strb                            (prf_tlp_strb),
  .prf_tlp_ep_strb                         (prf_tlp_ep_strb),
  .prf_tlp_silentDrop_strb                 (prf_tlp_silentDrop_strb),
  .prf_tlp_silentDrop_strb_masked          (prf_tlp_silentDrop_strb_masked),
  .prf_tlp_ats                             (prf_tlp_ats),
  .prf_tlp_nw                              (prf_tlp_nw),
  .prf_tlp_func_num                        (prf_tlp_func_num),
  .prf_tlp_th                              (prf_tlp_th),
  .prf_tlp_ph                              (prf_tlp_ph),
  .prf_tlp_st                              (prf_tlp_st),
  .prf_tlp_prfx                            (prf_tlp_prfx),
  .prf_p_tag                               (prf_tlp_p_tag),
  .prf_tlp_atu_bypass                      (prf_tlp_atu_bypass),
  .prf_tlp_dst_segment                     (prf_tlp_dst_segment),
  .prf_tlp_axi_id                          (prf_tlp_axi_id),
  .prf_first_wrp_split_xact                (prf_first_wrp_split_xact),
  .prf_wrp_valid                           (prf_wrp_valid),
  .pdcmp_halt                              (pdcmp_halt)
  );


  // ---------------------------------------------------------------------------
  // Posted Request Decomposer
  // ---------------------------------------------------------------------------
  DWC_pcie_bridge_ob_p_dcmp
  
  u_pdcmp
  (
  .slv_aclk                                    ( slv_aclk                                   ),
  .slv_aresetn                                 ( slv_aresetn                                ),
  .core_clk                                    ( core_clk                                   ),
  .core_rst_n                                  ( core_rst_n                                 ),

    // Configuration interface
  .cfg_max_payload_size                        ( cfg_max_payload_size                       ),

  .cfg_tc_struc_vc_map                         ( cfg_tc_struc_vc_map                        ),
   .cfg_ras_recc_ob_pdcmp_hdr_correct          ( cfg_ras_recc_ob_pdcmp_hdr_correct          ),
   .axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse   ( axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse   ),
   .axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse  ( axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse  ),
   .axi_ras_recc_cnt_ob_pdcmp_hdr_addr         ( axi_ras_recc_cnt_ob_pdcmp_hdr_addr         ),

   .cfg_ras_recc_ob_pdcmp_data_correct         ( cfg_ras_recc_ob_pdcmp_data_correct         ),
   .axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse  ( axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse  ),
   .axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse ( axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse ),
   .axi_ras_recc_cnt_ob_pdcmp_data_addr        ( axi_ras_recc_cnt_ob_pdcmp_data_addr        ),
   .axi_recc_cnt_ob_pdcmp_ras_dp_err_log       ( axi_recc_cnt_ob_pdcmp_ras_dp_err_log       ),
   .axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log   ( axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log   ),
   .ras_dp_err_inj_slv_aclk                    (ras_dp_err_inj_slv_aclk                     ),
   .axi_bridge_ras_dp_err_inj_core_clk         (core_clk_hp_mstr_ras_dp_err_inj             ),

    // Request packet interface
  .pdcmp_halt                                  ( pdcmp_halt                                 ),
  .prf_hv                                      ( prf_tlp_hv                                 ),
  .prf_dv                                      ( prf_tlp_dv                                 ),
  .prf_eot                                     ( prf_tlp_eot                                ),
  .prf_prfx                                    ( prf_tlp_prfx                               ),
  .prf_p_tag                                  (prf_tlp_p_tag                               ),
  .prf_th                                      ( prf_tlp_th                                 ),
  .prf_ph                                      ( prf_tlp_ph                                 ),
  .prf_st                                      ( prf_tlp_st                                 ),
  .prf_atu_bypass                              ( prf_tlp_atu_bypass                         ),
  .prf_dst_segment                             ( prf_tlp_dst_segment                        ),
  .prf_ats                                     ( prf_tlp_ats                                ),
  .prf_nw                                      ( prf_tlp_nw                                 ),
  .prf_first_wrp_split_xact                    ( prf_first_wrp_split_xact                   ),
  .prf_wrp_valid                               ( prf_wrp_valid                              ),
  .prf_axi_id                                  ( prf_tlp_axi_id                             ),
  .prf_cpl_stat                                ( prf_tlp_cpl_stat                           ),
  .prf_byte_len                                ( prf_tlp_byte_len                           ),
  .prf_tc                                      ( prf_tlp_tc                                 ),
  .prf_ep                                      ( prf_tlp_ep                                 ),
  .prf_attr                                    ( prf_tlp_attr                               ),
  .prf_fmt                                     ( prf_tlp_fmt                                ),
  .prf_type                                    ( prf_tlp_type                               ),
  .prf_byte_en                                 ( prf_tlp_byte_en                            ),
  .prf_addr                                    ( prf_tlp_addr                               ),
  .prf_data                                    ( prf_tlp_data                               ),
  .prf_ep_strb                                 ( prf_tlp_ep_strb                            ),
  .prf_silentDrop_strb                         ( prf_tlp_silentDrop_strb                    ),
  .prf_silentDrop_strb_masked                  ( prf_tlp_silentDrop_strb_masked             ),
  .prf_strb                                    ( prf_tlp_strb                               ),
  .pdcmp_addr_parerr                           ( pdcmp_addr_parerr                          ),
  .pdcmp_inq_data_parerr                       ( pdcmp_inq_data_parerr                      ),
  .pdcmp_ad_ras_dp_err_log                     ( pdcmp_ad_ras_dp_err_log                    ),
  .pdcmp_inq_dt_ras_dp_err_log                 ( pdcmp_inq_dt_ras_dp_err_log                ),
  .pdcmp_hdr_ram_addra                         ( pdcmp_hdr_ram_addra                        ),
  .pdcmp_hdr_ram_wea                           ( pdcmp_hdr_ram_wea                          ),
  .pdcmp_hdr_ram_dina                          ( pdcmp_hdr_ram_dina                         ),
  .pdcmp_hdr_ram_addrb                         ( pdcmp_hdr_ram_addrb                        ),
  .pdcmp_hdr_ram_enb                           ( pdcmp_hdr_ram_enb                          ),
  .pdcmp_hdr_ram_doutb                         ( pdcmp_hdr_ram_doutb                        ),

  .pdcmp_data_ram_addra                        ( pdcmp_data_ram_addra                       ),
  .pdcmp_data_ram_wea                          ( pdcmp_data_ram_wea                         ),
  .pdcmp_data_ram_dina                         ( pdcmp_data_ram_dina                        ),
  .pdcmp_data_ram_addrb                        ( pdcmp_data_ram_addrb                       ),
  .pdcmp_data_ram_enb                          ( pdcmp_data_ram_enb                         ),
  .pdcmp_data_ram_doutb                        ( pdcmp_data_ram_doutb                       ),


  .pdcmp_p_rsp_valid                           ( pdcmp_p_rsp_valid                          ),
  .pdcmp_p_rsp_id                              ( pdcmp_p_rsp_id                             ),
  .pdcmp_p_rsp_cpl_stat                        ( pdcmp_p_rsp_cpl_stat                       ),
  .pdcmp_p_rsp_null_or_err                     ( pdcmp_p_rsp_null_or_err                    ),
  .pdcmp_p_rsp_last                            ( pdcmp_p_rsp_last                           ),
  .pdcmp_p_rsp_vc_num                          ( pdcmp_p_rsp_vc_num                         ),
  .pdcmp_hv                                    ( pdcmp_tlp_hv                               ),
  .pdcmp_dv                                    ( pdcmp_tlp_dv                               ),
  .pdcmp_eot                                   ( pdcmp_tlp_eot                              ),
  .pdcmp_prfx                                  ( pdcmp_tlp_prfx                             ),
  .pdcmp_p_tag                                 ( pdcmp_tlp_p_tag                            ),
  .pdcmp_th                                    ( pdcmp_tlp_th                               ),
  .pdcmp_ph                                    ( pdcmp_tlp_ph                               ),
  .pdcmp_st                                    ( pdcmp_tlp_st                               ),
  .pdcmp_atu_bypass                            ( pdcmp_tlp_atu_bypass                       ),
  .pdcmp_dst_segment                           ( pdcmp_tlp_dst_segment                      ),
  .pdcmp_ats                                   ( pdcmp_tlp_ats                              ),
  .pdcmp_nw                                    ( pdcmp_tlp_nw                               ),
  .pdcmp_func_num                              ( pdcmp_tlp_func_num                         ),
  .pdcmp_byte_len                              ( pdcmp_tlp_byte_len                         ),
  .pdcmp_tc                                    ( pdcmp_tlp_tc                               ),
  .pdcmp_ep                                    ( pdcmp_tlp_ep                               ),
  .pdcmp_silentDrop                            ( pdcmp_tlp_silentDrop                       ),
  .pdcmp_attr                                  ( pdcmp_tlp_attr                             ),
  .pdcmp_fmt                                   ( pdcmp_tlp_fmt                              ),
  .pdcmp_type                                  ( pdcmp_tlp_type                             ),
  .pdcmp_byte_en                               ( pdcmp_tlp_byte_en                          ),
  .pdcmp_addr                                  ( pdcmp_tlp_addr                             ),
  .pdcmp_data                                  ( pdcmp_tlp_data                             ),
  .xadm_client2_halt                           ( dwnstrm_halt                               )

  );

  assign client2_tlp_hv          = pdcmp_tlp_hv;
  assign client2_tlp_dv          = pdcmp_tlp_dv;
  assign client2_tlp_eot         = pdcmp_tlp_eot;
  assign dwnstrm_halt            = xadm_client2_halt;

assign client2_tlp_prfx          = pdcmp_tlp_prfx;
assign client2_p_tag             = pdcmp_tlp_p_tag;
assign client2_tlp_th            = pdcmp_tlp_th;
assign client2_tlp_ph            = pdcmp_tlp_ph;
assign client2_tlp_st            = pdcmp_tlp_st;
assign client2_tlp_atu_bypass    = pdcmp_tlp_atu_bypass;
assign client2_tlp_dst_segment   = pdcmp_tlp_dst_segment;
assign client2_tlp_ats           = pdcmp_tlp_ats;
assign client2_tlp_nw            = pdcmp_tlp_nw;
assign client2_tlp_func_num      = pdcmp_tlp_func_num;
assign client2_tlp_byte_len      = pdcmp_tlp_byte_len;
assign client2_tlp_tc            = pdcmp_tlp_tc;
assign client2_tlp_ep            = pdcmp_tlp_ep;
assign client2_tlp_silentDrop    = pdcmp_tlp_silentDrop;
assign client2_tlp_attr          = pdcmp_tlp_attr;
assign client2_tlp_fmt           = pdcmp_tlp_fmt;
assign client2_tlp_type          = pdcmp_tlp_type;
assign client2_tlp_byte_en       = pdcmp_tlp_byte_en;
assign client2_tlp_addr          = pdcmp_tlp_addr;
assign client2_tlp_data          = pdcmp_tlp_data;





endmodule
