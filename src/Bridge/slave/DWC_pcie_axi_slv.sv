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

// -------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv.sv#20 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "Axi/svif/DWC_pcie_axi_slv_ar_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_aw_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_w_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_r_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_b_if.svh"

 module DWC_pcie_axi_slv
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  parameter SLV_BUS_ID_WIDTH                 = 5,
  parameter SLV_BURST_LEN_PW                 = 4,
  parameter SLV_BUS_ADDR_WIDTH               = 36,
  parameter SLAVE_BUS_ADDR_WIDTH             = 32,
  parameter SLV_BUS_DATA_WIDTH               = `CC_SLV_BUS_DATA_WIDTH,
  parameter SLV_BUS_WSTRB_WIDTH              = `CC_SLV_BUS_WSTRB_WIDTH,
  parameter SLV_BUS_NPDATA_WIDTH             = `CC_SLV_BUS_NPDATA_WIDTH,
  parameter SLV_BUS_NPDATA_WIDTH_NP          = `CC_SLV_BUS_NPDATA_WIDTH_NP,
  parameter SLV_BUS_NPWSTRB_WIDTH            = `CC_SLV_BUS_NPWSTRB_WIDTH,
  parameter SLV_BUS_WREQ_NPDATA_WIDTH        = `CC_SLV_BUS_WREQ_NPDATA_WIDTH,
  parameter SLV_BUS_WREQ_NPDATA_WIDTH_NP     = `CC_SLV_BUS_WREQ_NPDATA_WIDTH,
  parameter SLV_BUS_WREQ_NPWSTRB_WIDTH       = `CC_SLV_BUS_WREQ_NPWSTRB_WIDTH,
  parameter SLV_BUS_WSTRB_PW                 = 2,
  parameter SLV_MISC_INFO_WD                 = 10,
  parameter AXI_LOCK_WIDTH                   = 1,
  parameter NFUNC_WD                         = 3,
  parameter TX_TLP_PREFIX_WD                 = 32,
  parameter MISC_INFO_TPH_WD                 = 11,
  parameter ATU_OUT_REGIONS                  = 2,
  parameter ATU_BASE_WD                      = 32,
  parameter ATU_REG_WD                       = 16,
  parameter ATU_UPR_LMT_WD                   = 8,
  parameter ATU_OUT_MIN1                     = 1,
  parameter MAX_SLV_TAG                      = 32,
  parameter MAX_SLV_TAG_PW                   = 5,
  parameter CX_TAG_SIZE                      = `CX_TAG_SIZE,
  parameter SLV_NUM_OUTSTND_WR_REQ           = 16,
  parameter SLV_NUM_OUTSTND_WR_REQ_LOG2      = 4,
  parameter DBI_SLV_BUS_ADDR_WIDTH           = 32,
  parameter SLV_WRP_RSP_ROB_FIFO_DP           = `CC_SLV_WRP_RSP_ROB_FIFO_DP,
  parameter SLV_WRP_RSP_ROB_FIFO_ADDR_WD      = `CC_SLV_WRP_RSP_ROB_FIFO_ADDR_WD,
  parameter SLV_NPW_SAB_RAM_DATA_WD          = `CC_SLV_NPW_SAB_RAM_DATA_WD,
  parameter SLV_NPW_SAB_RAM_DATA_WD_NOECC    = `CC_SLV_NPW_SAB_RAM_DATA_WD_NOECC,
  parameter SLV_NPW_SAB_RAM_DP               = `CC_SLV_NPW_SAB_RAM_DP,
  parameter SLV_NPW_SAB_RAM_ADDR_WD          = `CC_SLV_NPW_SAB_RAM_ADDR_WD,
  parameter CX_RAS_PROT_RANGE                = `CX_RAS_PROT_RANGE,
  parameter CX_RAS_PARITY_MODE               = `CX_RAS_PARITY_MODE,
  parameter DC_CPL_STATUS_WD                 = `DC_CPL_STATUS_WD,
  parameter TP                               = `TP
  )
  
                          (
  input                                         slv_aclk,
  input                                         slv_aclk_ug,
  input                                         slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Error response configuration interface
  input [4:0]                                   cfg_err_resp_mode,
  input [5:0]                                   cfg_err_resp_map,
  input                                         cfg_dmwr_req_en,
  // -------------------------------------------------------------------------------------
  // Enhanced Configuration Access Mechanism (ECAM)
  // -------------------------------------------------------------------------------------
  // Flush control
  input                                         flshctl_sif_flush_req,
  output wire                                   sif_flush_ack,
  // -------------------------------------------------------------------------------------
  // ATU Configuration Interface
  input [(ATU_BASE_WD*ATU_OUT_MIN1)-1:0]        atu_reg_out_upr_base,
  input [ATU_OUT_MIN1-1:0]                      atu_reg_out_en,
  input [5*ATU_OUT_MIN1-1:0]                    atu_reg_out_type,
  input [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]         atu_reg_out_base,
  input [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]         atu_reg_out_limit,
  input [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0]       atu_reg_out_uppr_limit,
  input [ATU_OUT_MIN1-1:0]                      atu_reg_out_incr_rgn_size,    // Maximum region size control bit
  input [ATU_OUT_MIN1-1:0]                      atu_reg_out_invert,
  input [(NFUNC_WD*ATU_OUT_MIN1)-1:0]           atu_reg_out_func_num,
  input [ATU_OUT_MIN1-1:0]                      atu_reg_out_func_bypass,
  input [ATU_OUT_MIN1-1:0]                      atu_reg_out_snp,
  output wire                                   axi_ras_par_rslv_dt_pulse,
  output ras_dp_err_log_t                       axi_srsp_rslv_dt_ras_dp_err_log,
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_ar_if.slv_mp                 slv_ar,
  DWC_pcie_axi_slv_r_if.slv_mp                  slv_r,
  DWC_pcie_axi_slv_aw_if.slv_mp                 slv_aw,
  DWC_pcie_axi_slv_w_if.slv_mp                  slv_w,
  DWC_pcie_axi_slv_b_if.slv_mp                  slv_b,
  // -------------------------------------------------------------------------------------
  // Client Non-Posted Request Interface
  output wire                                   sif_np_rd,
  output wire                                   sif_np_wr,
  output wire                                   sif_np_atomic,
  output wire                                   sif_np_dmwr,
  output wire                                   sif_np_first_wrp_split_xact,
  output wire                                   sif_np_wrp_valid,
  output wire [MAX_SLV_TAG_PW-1:0]              sif_np_tag,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]          sif_np_addr,
  output wire [SLV_BUS_ID_WIDTH-1:0]            sif_np_id,
  output wire [SLV_BURST_LEN_PW-1:0]            sif_np_len,
  output wire [2:0]                             sif_np_size,
  output wire [1:0]                             sif_np_burst,
  output wire                                   sif_np_last,
  output wire [SLV_BUS_NPWSTRB_WIDTH-1:0]       sif_np_strb,
  output wire [SLV_BUS_NPDATA_WIDTH-1:0]        sif_np_data,
  output wire [4:0]                             sif_np_type,
  output wire                                   sif_np_snp,
  output wire                                   sif_np_ido,
  output wire                                   sif_np_ns,
  output wire                                   sif_np_ro,
  output wire [2:0]                             sif_np_tc,
  output wire                                   sif_np_ep,
  output wire [NFUNC_WD-1:0]                    sif_np_func_num,
  output wire                                   sif_np_nw,
  output wire [1:0]                             sif_np_ats,
  output wire [TX_TLP_PREFIX_WD-1:0]            sif_np_tlpprfx,
  output wire [MISC_INFO_TPH_WD-1:0]            sif_np_tph,
  output wire                                   sif_np_atu_bypass,
  output wire [8:0]                             sif_np_dst_segment,
  output wire [2:0]                             sif_np_cpl_stat,
  input                                         nprf_ready,
  // -------------------------------------------------------------------------------------
  // Data Bus Non-Posted Request Interface
  output wire                                   sif_db_rd,
  output wire                                   sif_db_wr,
  output wire                                   sif_db_vldrq,
  output wire [MAX_SLV_TAG_PW-1:0]              sif_db_tag,
  output wire [DBI_SLV_BUS_ADDR_WIDTH-1:0]      sif_db_addr,
  output wire [3:0]                             sif_db_strb,
  output wire [SLV_BURST_LEN_PW-1:0]            sif_db_len,
  output wire [31:0]                            sif_db_data,
  input                                         dbi_ready,
  // -------------------------------------------------------------------------------------
  // Client Non-Posted Response Interface
  input                                         nprspf_valid,
  input [MAX_SLV_TAG_PW-1:0]                    nprspf_tag,
  input                                         nprspf_to,
  input                                         nprspf_ep,
  input [2:0]                                   nprspf_tc,
  input                                         nprspf_ido,
  input                                         nprspf_ns,
  input                                         nprspf_ro,
  input [2:0]                                   nprspf_status,
  input                                         nprspf_cpl,
  input [1:0] nprspf_resp,
  input [SLV_BUS_DATA_WIDTH-1:0]                nprspf_data,
  input                                         nprspf_last,
  input [7:0]                                   nprspf_cpl_segment,
  input [8:0]                                   nprspf_dst_segment,
  output wire                                   sif_np_ready,
  // -------------------------------------------------------------------------------------
  // Data Bus Non-Posted Response Interface
  input                                         dbi_valid,
  input                                         dbi_last,
  input [MAX_SLV_TAG_PW-1:0]                    dbi_tag,
  input [1:0] dbi_resp,
  input [31:0]                                  dbi_data,
  output wire                                   sif_db_ready,
  // -------------------------------------------------------------------------------------
  // Client Posted Request Interface
  output wire                                   sif_p_valid,
  output wire [SLV_BUS_ID_WIDTH-1:0]            sif_p_id,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]          sif_p_addr,
  output wire [2:0]                             sif_p_size,
  output wire [SLV_BURST_LEN_PW-1:0]            sif_p_len,
  output wire                                   sif_p_last,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]         sif_p_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]         sif_p_ep_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]         sif_p_silentDrop_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]         sif_p_silentDrop_strb_masked,
  output wire [SLV_BUS_DATA_WIDTH-1:0]          sif_p_data,
  output wire [7:0]                             sif_p_msg_code,
  output wire [4:0]                             sif_p_type,
  output wire [2:0]                             sif_p_tc,
  output wire                                   sif_p_ep,
  output wire                                   sif_p_ido,
  output wire                                   sif_p_ro,
  output wire                                   sif_p_ns,
  output wire                                   sif_p_first_wrp_split_xact,
  output wire                                   sif_p_wrp_valid,
  output wire                                   sif_p_nw,
  output wire [1:0]                             sif_p_ats,
  output wire [NFUNC_WD-1:0]                    sif_p_func_num,
  output wire [MISC_INFO_TPH_WD-1:0]            sif_p_tph,
  output wire [TX_TLP_PREFIX_WD-1:0]            sif_p_tlpprfx,
  output wire [CX_TAG_SIZE-1:0]                 sif_p_tag,
  output wire                                   sif_p_atu_bypass,
  output wire [8:0]                             sif_p_dst_segment,
  output wire [DC_CPL_STATUS_WD-1:0]            sif_p_cpl_stat,
  input                                         prf_ready,
  // -------------------------------------------------------------------------------------
  // Posted Response Interface
  input                                         pdcmp_p_rsp_valid_hl,
  input [SLV_BUS_ID_WIDTH-1:0]                  pdcmp_p_rsp_id,
  input [DC_CPL_STATUS_WD-1:0]                  pdcmp_p_rsp_cpl_stat,
  // -------------------------------------------------------------------------------------
  // Non Posted Atomic Response Interface
  input                                         npdcmp_np_atomic_rsp_valid_hl,
  input [SLV_BUS_ID_WIDTH-1:0]                  npdcmp_np_atomic_rsp_id,
  // -------------------------------------------------------------------------------------
  // Parity Error Interface
  output wire                                   sif_addr_parerr,
  output wire                                   sif_data_parerr,
    input  ras_dp_err_inj_t                    ras_dp_err_inj_slv_aclk,
  output ras_dp_err_log_t                       sif_swrq_dt_ras_dp_err_log,
  output ras_dp_err_log_t                       sif_swrq_ad_ras_dp_err_log,
  output wire                                   sif_ras_par_swwrap_dt_pulse,
  output wire                                   sif_ras_par_swwrap_ad_pulse,
  output ras_dp_err_log_t                       sif_swrq_swwrap_dt_ras_dp_err_log,
  output ras_dp_err_log_t                       sif_swrq_swwrap_ad_ras_dp_err_log,
  // -------------------------------------------------------------------------------------
  // Slave Non-Posted Write Set-Aside RAM
  output wire [SLV_NPW_SAB_RAM_ADDR_WD-1:0]     sif_npw_sab_ram_addra,
  output wire                                   sif_npw_sab_ram_wea,
  output wire [SLV_NPW_SAB_RAM_DATA_WD-1:0]     sif_npw_sab_ram_dina,
  output wire [SLV_NPW_SAB_RAM_ADDR_WD-1:0]     sif_npw_sab_ram_addrb,
  output wire                                   sif_npw_sab_ram_enb,
  input [SLV_NPW_SAB_RAM_DATA_WD-1:0]           sif_npw_sab_ram_doutb,
  input                                         cfg_ras_recc_npw_sab_correct,
  output wire                                   sif_ras_recc_corr_cnt_npw_sab_pulse,
  output wire                                   sif_ras_recc_ucorr_cnt_npw_sab_pulse,
  output wire [SLV_NPW_SAB_RAM_ADDR_WD-1:0]     sif_ras_recc_cnt_npw_sab_addr,
  output ras_dp_err_log_t                       sif_recc_npw_sab_ras_dp_err_log,
  output wire                                   sif_ras_par_srwrap_ad_pulse,
  output ras_dp_err_log_t                       sif_srrp_srwrap_ad_ras_dp_err_log,
  output wire                                   sif_ras_par_swrq_npw_dt_pulse,
  output wire                                   sif_ras_par_swrq_npw_ad_pulse,

  output ras_dp_err_log_t                       sif_swrq_npw_dt_ras_dp_err_log,
  output ras_dp_err_log_t                       sif_swrq_npw_ad_ras_dp_err_log,
  //--------------------------------------------------------------------------------------
  // Power Management Interface (Powr Down)

  //--------------------------------------------------------------------------------------
  // Activity Tracking Interface
  output wire                                   sif_xfer_pending_db,
  output wire                                   sif_xfer_pending,
  // -------------------------------------------------------------------------------------
  // Completions Status during DPC
  input                                         cdc_core_in_dpc_i      ,
  input                                         qst_cfg_dpc_cpl_cntrl_i,
  // -------------------------------------------------------------------------------------
  // Low Power Interface
  input                                         csysreq,
  output wire                                   sif_csysack,
  output wire                                   sif_cactive

  );
  // -------------------------------------------------------------------------------------
  // Internal Wire/Reg
  // -------------------------------------------------------------------------------------
  // u_atm
  wire                                     s_sif_np_wr;
  wire                                     atm_np_tag_fifo_full;
  wire [MAX_SLV_TAG_PW-1:0]                atm_np_tag;
  wire [SLV_BUS_ID_WIDTH-1:0]              atm_np_id;
  wire [SLV_BUS_WSTRB_PW-1:0]              atm_np_addr_low;
  wire [SLV_BURST_LEN_PW-1:0]              atm_np_len;
  wire [2:0]                               atm_np_size;
  wire                                     atm_np_wr;
  wire                                     atm_np_atomic;
  wire [3:0]                               atm_np_wrap_beat_offset;
  wire                                     atm_np_ven_id_rd;
  wire                                     atm_dbi_req_halt;
  wire [MAX_SLV_TAG -1:0]                  atm_cpl_seg_halt;
  wire                                     srrq_np_tag_consumed;
  wire                                     srrq_npw_ready;
  wire [SLV_BUS_WSTRB_PW-1:0]              srrq_np_addr_low;
  wire                                     srrq_np_ven_id_rd;
  wire [3:0]                               srrq_np_wrap_beat_offset;

  wire                                     swrq_wr_valid_hl,
                                           swrq_wr_p,
                                           swrq_wr_np,
                                           swrq_wr_np_atomic,
                                           swrq_wr_last_null_writes;
  wire                                     srq_wr_db;
  wire [SLV_BUS_ID_WIDTH-1:0]              swrq_wr_id;
  wire                                     swrq_awready;
  wire                                     swrq_wready;
  wire                                     s_sif_xfer_pending;

  // Non-Posted Write Request Interface
  wire                                     swrq_npw_valid;
  wire [SLV_BUS_ID_WIDTH-1:0]              swrq_npw_id;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            swrq_npw_addr;

  wire [2:0]                               swrq_npw_size;
  wire [SLV_BURST_LEN_PW-1:0]              swrq_npw_len;
  wire                                     swrq_npw_last;
  wire [SLV_BUS_WREQ_NPWSTRB_WIDTH-1:0]    swrq_npw_strb;
  wire [SLV_BUS_WREQ_NPDATA_WIDTH-1:0]     swrq_npw_data;
  wire [4:0]                               swrq_npw_type;
  wire                                     swrq_npw_snp;
  wire [2:0]                               swrq_npw_tc;
  wire                                     swrq_npw_ep;
  wire                                     swrq_npw_atomic_load_be;
  wire                                     swrq_npw_atomic_cas_wrap;
  wire                                     swrq_npw_ns;
  wire                                     swrq_npw_ro;
  wire                                     swrq_npw_nw;
  wire [1:0]                               swrq_npw_ats;
  wire [MISC_INFO_TPH_WD-1:0]              swrq_npw_tph;
  wire                                     swrq_npw_first_wrp_split_xact;
  wire                                     swrq_npw_wrp_valid;
  wire                                     swrq_npw_db;
  wire                                     swrq_npw_db_vldrq;
  wire [NFUNC_WD-1:0]                      swrq_npw_func_num;
  wire [TX_TLP_PREFIX_WD-1:0]              swrq_npw_tlpprfx;
  wire                                     swrq_npw_atu_bypass;
  wire [8:0]                               swrq_npw_dst_segment;
  wire                                     swrq_npw_ido;
  wire [2:0]                               swrq_npw_cpl_stat;

 // Non-Posted Response Interface
  wire                                     s_nprsp_valid;
  wire [MAX_SLV_TAG_PW-1:0]                s_nprsp_tag;
  wire                                     s_nprsp_to;
  wire                                     s_nprsp_ep;
  wire [2:0]                               s_nprsp_tc;
 // DBI indication nprsp rtr to slv rsp
  wire                                     s_dbi_response;
 // rd/wr dbi rsp indication to slv trkr
  wire                                     dbi_wr_rsp;
  wire                                     dbi_rd_rsp;
  wire                                     s_nprsp_ido;
  wire                                     s_nprsp_ns;
  wire                                     s_nprsp_ro;
  wire [2:0]                               s_nprsp_status;
  wire                                     s_nprsp_cpl;
  wire [7:0]                               s_nprsp_cpl_segment;
  wire [8:0]                               s_nprsp_dst_segment;
  
  wire [1:0] s_nprsp_resp;
  
  wire [SLV_BUS_DATA_WIDTH-1:0]            s_nprsp_data;
  wire                                     s_nprsp_last;
  wire                                     srsp_np_ready;

  wire                                     srsp_np_tag_recycled;
  wire [MAX_SLV_TAG_PW-1:0]                srsp_np_tag;

  wire                                     strkr_awvalid;
  wire                                     strkr_wvalid;
  wire                                     strkr_wlast;

   wire                                    srsp_rvalid;
   wire [SLV_BUS_ID_WIDTH-1:0]             srsp_rid;
   wire                                    srsp_rto;
   wire                                    srsp_rep;
   wire [2:0]                              srsp_rtc;
   wire                                    srsp_rns;
   wire                                    srsp_rro;
   wire [2:0]                              srsp_rstatus;
   wire                                    srsp_rcpl;
   wire                                    srsp_rido;
   wire [7:0]                              srsp_rcpl_segment;
   wire [8:0]                              srsp_rdst_segment;
   wire [1:0]                              srsp_rresp;
   wire [SLV_BUS_DATA_WIDTH-1:0]           srsp_rdata;
   wire                                    srsp_rlast;

  // -------------------------------------------------------------------------------------
  // Instantiate AXI Non-Posted Tag Manager
  // -------------------------------------------------------------------------------------
  // Store non-posted write info per tag
  assign s_sif_np_wr = sif_np_wr || sif_db_wr;

wire s_srrq_np_tag_consumed;



  DWC_pcie_axi_slv_tag_mngr
  
  #(.SLV_BUS_ID_WIDTH                (SLV_BUS_ID_WIDTH)
   ,.SLV_BURST_LEN_PW                (SLV_BURST_LEN_PW)
   ,.SLV_BUS_STRB_PW                 (SLV_BUS_WSTRB_PW)
   ,.MAX_SLV_TAG                     (MAX_SLV_TAG)
   ,.MAX_SLV_TAG_PW                  (MAX_SLV_TAG_PW)
  )
  u_atm
  (.slv_aclk                         (slv_aclk)
  ,.slv_aresetn                      (slv_aresetn)
  // -------------------------------------------------------------------------------------
  // Tag request interface
  ,.srrq_np_tag_consumed             (s_srrq_np_tag_consumed)
  ,.sif_np_id                        (sif_np_id)
  ,.srrq_np_addr_low                 (srrq_np_addr_low)
  ,.sif_np_len                       (sif_np_len)
  ,.sif_np_size                      (sif_np_size)
  ,.srrq_np_wr                       (s_sif_np_wr)
  ,.srrq_np_atomic                   (sif_np_atomic)
  ,.srrq_np_type                     (sif_np_type)
  ,.srrq_np_wrap_beat_offset         (srrq_np_wrap_beat_offset)
  ,.srrq_np_ven_id_rd                (srrq_np_ven_id_rd)
  ,.sif_np_dbi                       (sif_db_rd || sif_db_wr)
  ,.atm_np_tag                       (atm_np_tag)
  ,.atm_np_tag_fifo_full             (atm_np_tag_fifo_full)
  // -------------------------------------------------------------------------------------
  // Tag response interface
  ,.srsp_np_tag_recycled             (srsp_np_tag_recycled)
  ,.srsp_np_tag                      (srsp_np_tag)
  ,.atm_np_id                        (atm_np_id)
  ,.atm_np_addr_low                  (atm_np_addr_low)
  ,.atm_np_len                       (atm_np_len)
  ,.atm_np_size                      (atm_np_size)
  ,.atm_np_wr                        (atm_np_wr)
  ,.atm_np_atomic                    (atm_np_atomic)
  ,.atm_np_wrap_beat_offset          (atm_np_wrap_beat_offset)
  ,.atm_np_ven_id_rd                 (atm_np_ven_id_rd)
  // -------------------------------------------------------------------------------------
  // Completion order information interface
  ,.atm_dbi_req_halt                 (atm_dbi_req_halt)
  ,.atm_cpl_seg_halt                 (atm_cpl_seg_halt)
  );


  // Assign tag

  reg [MAX_SLV_TAG_PW-1:0] r_atm_np_tag;

  always@(posedge slv_aclk or negedge slv_aresetn) begin
    if(!slv_aresetn)
      r_atm_np_tag <= #TP {(MAX_SLV_TAG_PW){1'b0}};
    else begin
      if(s_sif_np_wr && sif_np_dmwr && sif_np_wrp_valid && sif_np_first_wrp_split_xact && nprf_ready)
        r_atm_np_tag <= #TP atm_np_tag;
    end
  end

  assign sif_np_tag = ( s_sif_np_wr && sif_np_dmwr && sif_np_wrp_valid && !sif_np_first_wrp_split_xact ) ? r_atm_np_tag : atm_np_tag;
  assign s_srrq_np_tag_consumed = srrq_np_tag_consumed && !(s_sif_np_wr && sif_np_dmwr && sif_np_wrp_valid && !sif_np_first_wrp_split_xact);


  assign sif_db_tag = atm_np_tag;

  // -------------------------------------------------------------------------------------
  // Instantiate Slave Read Request block
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_rreq
  
  #(.SLV_BUS_ID_WIDTH                      (SLV_BUS_ID_WIDTH)
   ,.SLV_BUS_ADDR_WIDTH                    (SLV_BUS_ADDR_WIDTH)
   ,.SLAVE_BUS_ADDR_WIDTH                  (SLAVE_BUS_ADDR_WIDTH)
   ,.SLV_BUS_NPWSTRB_WIDTH                 (SLV_BUS_NPWSTRB_WIDTH)
   ,.SLV_BUS_NPDATA_WIDTH                  (SLV_BUS_NPDATA_WIDTH)
   ,.SLV_BUS_NPDATA_WIDTH_NP               (SLV_BUS_NPDATA_WIDTH_NP)
   ,.SLV_BUS_WREQ_NPWSTRB_WIDTH            (SLV_BUS_WREQ_NPWSTRB_WIDTH)
   ,.SLV_BUS_WREQ_NPDATA_WIDTH             (SLV_BUS_WREQ_NPDATA_WIDTH)
   ,.SLV_BUS_WREQ_NPDATA_WIDTH_NP          (SLV_BUS_WREQ_NPDATA_WIDTH_NP)
   ,.CX_RAS_PROT_RANGE                     (CX_RAS_PROT_RANGE)
   ,.SLV_BURST_LEN_PW                      (SLV_BURST_LEN_PW)
   ,.NFUNC_WD                              (NFUNC_WD)
   ,.TX_TLP_PREFIX_WD                      (TX_TLP_PREFIX_WD)
   ,.MISC_INFO_TPH_WD                      (MISC_INFO_TPH_WD)
   ,.ATU_OUT_REGIONS                       (ATU_OUT_REGIONS)
   ,.ATU_BASE_WD                           (ATU_BASE_WD)
   ,.ATU_REG_WD                            (ATU_REG_WD)
   ,.ATU_OUT_MIN1                          (ATU_OUT_MIN1)
   ,.ATU_UPR_LMT_WD                        (ATU_UPR_LMT_WD)
   ,.SLV_BUS_STRB_PW                       (SLV_BUS_WSTRB_PW)
   ,.DBI_SLV_BUS_ADDR_WIDTH                (DBI_SLV_BUS_ADDR_WIDTH)
   ,.SLV_NPW_SAB_RAM_DATA_WD               (SLV_NPW_SAB_RAM_DATA_WD)
   ,.SLV_NPW_SAB_RAM_DATA_WD_NOECC         (SLV_NPW_SAB_RAM_DATA_WD_NOECC)
   ,.SLV_NPW_SAB_RAM_DP                    (SLV_NPW_SAB_RAM_DP)
   ,.SLV_NPW_SAB_RAM_ADDR_WD               (SLV_NPW_SAB_RAM_ADDR_WD)
  )
  u_srrq
  (.slv_aclk                         (slv_aclk)
  ,.slv_aclk_ug                      (slv_aclk_ug)
  ,.slv_aresetn                      (slv_aresetn)
  // -------------------------------------------------------------------------------------
  // Flush control
  ,.flshctl_sif_flush_req            (flshctl_sif_flush_req)
  // -------------------------------------------------------------------------------------
  // Power Down Interface
   // ATU control interface
  ,.atu_reg_out_upr_base             (atu_reg_out_upr_base)
  ,.atu_reg_out_en                   (atu_reg_out_en)
  ,.atu_reg_out_type                 (atu_reg_out_type)
  ,.atu_reg_out_base                 (atu_reg_out_base)
  ,.atu_reg_out_limit                (atu_reg_out_limit)
  ,.atu_reg_out_uppr_limit           (atu_reg_out_uppr_limit)
  ,.atu_reg_out_incr_rgn_size        (atu_reg_out_incr_rgn_size)
  ,.atu_reg_out_invert               (atu_reg_out_invert)
  ,.atu_reg_out_func_num             (atu_reg_out_func_num)
  ,.atu_reg_out_func_bypass          (atu_reg_out_func_bypass)
  ,.atu_reg_out_snp                  (atu_reg_out_snp)
   // -------------------------------------------------------------------------------------
   // AXI read request interface
  ,.arvalid                          (slv_ar.valid)
  ,.araddr                           (slv_ar.addr)
  ,.arid                             (slv_ar.id)
  ,.arlen                            (slv_ar.len)
  ,.arsize                           (slv_ar.size)
  ,.arburst                          (slv_ar.burst)
  ,.armisc_info_type                 (slv_ar.misc_info_type)
  ,.armisc_info_snp                  (slv_ar.misc_info_snp)
  ,.armisc_info_ns                   (slv_ar.misc_info_ns)
  ,.armisc_info_ro                   (slv_ar.misc_info_ro)
  ,.armisc_info_tc                   (slv_ar.misc_info_tc)
  ,.armisc_info_db                   (slv_ar.misc_info_db)
  ,.armisc_info_func_num             (slv_ar.misc_info_func_num)
  ,.armisc_info_nw                   (slv_ar.misc_info_nw)
  ,.armisc_info_ats                  (slv_ar.misc_info_ats)
  ,.armisc_info_tlpprfx              (slv_ar.misc_info_tlpprfx)
  ,.armisc_info_tph                  (slv_ar.misc_info_tph)
  ,.armisc_info_atu_bypass           (slv_ar.misc_info_atu_bypass)
  ,.armisc_info_dst_segment          (slv_ar.misc_info_dst_segment)
  ,.armisc_info_ido                  (slv_ar.misc_info_ido)
  ,.srrq_np_arready                  (slv_ar.ready)
   // -------------------------------------------------------------------------------------
   // AXI tag manager control interface
  ,.srrq_np_tag_consumed             (srrq_np_tag_consumed)
  ,.tag_fifo_full                    (atm_np_tag_fifo_full)
  // -------------------------------------------------------------------------------------
  // Non-Posted Write Request Interface
  ,.swrq_npw_valid                   (swrq_npw_valid)
  ,.swrq_npw_id                      (swrq_npw_id)
  ,.swrq_npw_addr                    (swrq_npw_addr)
  ,.swrq_npw_size                    (swrq_npw_size)
  ,.swrq_npw_len                     (swrq_npw_len)
  ,.swrq_npw_last                    (swrq_npw_last)
  ,.swrq_npw_strb                    (swrq_npw_strb)
  ,.swrq_npw_data                    (swrq_npw_data)
  ,.swrq_npw_type                    (swrq_npw_type)
  ,.swrq_npw_snp                     (swrq_npw_snp)
  ,.swrq_npw_tc                      (swrq_npw_tc)
  ,.swrq_npw_ep                      (swrq_npw_ep)
  ,.swrq_npw_atomic_load_be          (swrq_npw_atomic_load_be)
  ,.swrq_npw_atomic_cas_wrap         (swrq_npw_atomic_cas_wrap)
  ,.swrq_npw_tph                     (swrq_npw_tph)
  ,.swrq_npw_nw                      (swrq_npw_nw)
  ,.swrq_npw_ats                     (swrq_npw_ats)
  ,.swrq_npw_ns                      (swrq_npw_ns)
  ,.swrq_npw_ro                      (swrq_npw_ro)
  ,.swrq_npw_first_wrp_split_xact    (swrq_npw_first_wrp_split_xact)
  ,.swrq_npw_wrp_valid               (swrq_npw_wrp_valid)
  ,.swrq_npw_db                      (swrq_npw_db)
  ,.swrq_npw_db_vldrq                (swrq_npw_db_vldrq)
  ,.swrq_npw_func_num                (swrq_npw_func_num)
  ,.swrq_npw_tlpprfx                 (swrq_npw_tlpprfx)
  ,.swrq_npw_atu_bypass              (swrq_npw_atu_bypass)
  ,.swrq_npw_ido                     (swrq_npw_ido)
  ,.swrq_npw_dst_segment             (swrq_npw_dst_segment)
  ,.swrq_npw_cpl_stat                (swrq_npw_cpl_stat)
  ,.srrq_npw_ready                   (srrq_npw_ready)
  // -------------------------------------------------------------------------------------
  // Non-Posted request interface
  ,.srrq_np_rd                       (sif_np_rd)
  ,.srrq_np_wr                       (sif_np_wr)
  ,.srrq_np_atomic                   (sif_np_atomic)
  ,.srrq_np_dmwr                     (sif_np_dmwr)
  ,.srrq_np_first_wrp_split_xact     (sif_np_first_wrp_split_xact)
  ,.srrq_np_wrp_valid                (sif_np_wrp_valid)
  ,.srrq_np_addr                     (sif_np_addr)
  ,.srrq_np_addr_low                 (srrq_np_addr_low)
  ,.srrq_np_ven_id_rd                (srrq_np_ven_id_rd)
  ,.srrq_np_id                       (sif_np_id)
  ,.srrq_np_len                      (sif_np_len)
  ,.srrq_np_size                     (sif_np_size)
  ,.srrq_np_burst                    (sif_np_burst)
  ,.srrq_np_wrap_beat_offset         (srrq_np_wrap_beat_offset)
  ,.srrq_np_last                     (sif_np_last)
  ,.srrq_np_strb                     (sif_np_strb)
  ,.srrq_np_data                     (sif_np_data)
  ,.srrq_np_type                     (sif_np_type)
  ,.srrq_np_snp                      (sif_np_snp)
  ,.srrq_np_ns                       (sif_np_ns)
  ,.srrq_np_ro                       (sif_np_ro)
  ,.srrq_np_tc                       (sif_np_tc)
  ,.srrq_np_ep                       (sif_np_ep)
  ,.srrq_np_func_num                 (sif_np_func_num)
  ,.srrq_np_nw                       (sif_np_nw)
  ,.srrq_np_ats                      (sif_np_ats)
  ,.srrq_np_tlpprfx                  (sif_np_tlpprfx)
  ,.srrq_np_tph                      (sif_np_tph)
  ,.srrq_np_atu_bypass               (sif_np_atu_bypass)
  ,.srrq_np_dst_segment              (sif_np_dst_segment)
  ,.srrq_np_cpl_stat                 (sif_np_cpl_stat)
  ,.srrq_np_ido                      (sif_np_ido)
  ,.nprf_ready                       (nprf_ready)
  // -------------------------------------------------------------------------------------
  // Data Bus Non-Posted Request Interface
  ,.srrq_db_rd                       (sif_db_rd)
  ,.srrq_db_wr                       (sif_db_wr)
  ,.srrq_db_vldrq                    (sif_db_vldrq)
  ,.srrq_db_addr                     (sif_db_addr)
  ,.srrq_db_strb                     (sif_db_strb)
  ,.srrq_db_len                      (sif_db_len)
  ,.srrq_db_data                     (sif_db_data)
  ,.dbi_ready                        (dbi_ready)
  ,.atm_dbi_req_halt                 (atm_dbi_req_halt)
  // Slave Non-Posted Write Set-Aside RAM
  ,.srrq_npw_sab_addra               (sif_npw_sab_ram_addra)
  ,.srrq_npw_sab_wea                 (sif_npw_sab_ram_wea)
  ,.srrq_npw_sab_dina                (sif_npw_sab_ram_dina)
  ,.srrq_npw_sab_addrb               (sif_npw_sab_ram_addrb)
  ,.srrq_npw_sab_enb                 (sif_npw_sab_ram_enb)
  ,.ram_npw_sab_doutb                (sif_npw_sab_ram_doutb)
  ,.cfg_ras_recc_npw_sab_correct         (cfg_ras_recc_npw_sab_correct        )
  ,.srrp_ras_recc_corr_cnt_npw_sab_pulse (sif_ras_recc_corr_cnt_npw_sab_pulse )
  ,.srrp_ras_recc_ucorr_cnt_npw_sab_pulse(sif_ras_recc_ucorr_cnt_npw_sab_pulse)
  ,.srrp_ras_recc_cnt_npw_sab_addr       (sif_ras_recc_cnt_npw_sab_addr       )
  ,.ras_dp_err_inj_slv_aclk              (ras_dp_err_inj_slv_aclk)
  ,.srrp_recc_npw_sab_ras_dp_err_log     (sif_recc_npw_sab_ras_dp_err_log     )
  ,.srrp_ras_par_srwrap_ad_pulse     (sif_ras_par_srwrap_ad_pulse)
  ,.srrp_srwrap_ad_ras_dp_err_log    (sif_srrp_srwrap_ad_ras_dp_err_log)
  ,.swrq_ras_par_npw_dt_pulse        (sif_ras_par_swrq_npw_dt_pulse)
  ,.swrq_ras_par_npw_ad_pulse        (sif_ras_par_swrq_npw_ad_pulse)
  ,.swrq_npw_dt_ras_dp_err_log       (sif_swrq_npw_dt_ras_dp_err_log)
  ,.swrq_npw_ad_ras_dp_err_log       (sif_swrq_npw_ad_ras_dp_err_log)
  // -------------------------------------------------------------------------------------
  // Low power interface
  ,.csysreq                          (csysreq)
  ,.csysack                          (sif_csysack)
  ,.cactive                          (sif_cactive)
  );





  // -------------------------------------------------------------------------------------
  // Instantiate Slave Write Request block
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_wreq
  
 #(.SLV_BUS_ID_WIDTH                       (SLV_BUS_ID_WIDTH)
  ,.SLV_BUS_ADDR_WIDTH                     (SLV_BUS_ADDR_WIDTH)
  ,.SLAVE_BUS_ADDR_WIDTH                   (SLAVE_BUS_ADDR_WIDTH)
  ,.CX_RAS_PROT_RANGE                      (CX_RAS_PROT_RANGE)
  ,.SLV_BURST_LEN_PW                       (SLV_BURST_LEN_PW)
  ,.SLV_BUS_DATA_WIDTH                     (SLV_BUS_DATA_WIDTH)
  ,.SLV_BUS_WSTRB_WIDTH                    (SLV_BUS_WSTRB_WIDTH)
  ,.SLV_BUS_WSTRB_PW                       (SLV_BUS_WSTRB_PW)
  ,.SLV_BUS_WREQ_NPWSTRB_WIDTH             (SLV_BUS_WREQ_NPWSTRB_WIDTH)
  ,.SLV_BUS_WREQ_NPDATA_WIDTH              (SLV_BUS_WREQ_NPDATA_WIDTH)
  ,.AXI_LOCK_WIDTH                         (AXI_LOCK_WIDTH)
  ,.SLV_MISC_INFO_WD                       (SLV_MISC_INFO_WD)
  ,.MISC_INFO_TPH_WD                       (MISC_INFO_TPH_WD)
  ,.TX_TLP_PREFIX_WD                       (TX_TLP_PREFIX_WD)
  ,.NFUNC_WD                               (NFUNC_WD)
  ,.ATU_OUT_MIN1                           (ATU_OUT_MIN1)
  ,.ATU_OUT_REGIONS                        (ATU_OUT_REGIONS)
  ,.ATU_BASE_WD                            (ATU_BASE_WD)
  ,.ATU_REG_WD                             (ATU_REG_WD)
  ,.ATU_UPR_LMT_WD                         (ATU_UPR_LMT_WD)
  )
  u_swrq
  (.slv_aclk                         (slv_aclk)
  ,.slv_aresetn                      (slv_aresetn)
  ,.cfg_dmwr_req_en                  (cfg_dmwr_req_en)
  // -------------------------------------------------------------------------------------
  // ATU interface
  ,.atu_reg_out_upr_base             (atu_reg_out_upr_base)
  ,.atu_reg_out_en                   (atu_reg_out_en)
  ,.atu_reg_out_type                 (atu_reg_out_type)
  ,.atu_reg_out_base                 (atu_reg_out_base)
  ,.atu_reg_out_limit                (atu_reg_out_limit)
  ,.atu_reg_out_uppr_limit           (atu_reg_out_uppr_limit)
  ,.atu_reg_out_incr_rgn_size        (atu_reg_out_incr_rgn_size)
  ,.atu_reg_out_invert               (atu_reg_out_invert)
  ,.atu_reg_out_func_num             (atu_reg_out_func_num)
  ,.atu_reg_out_func_bypass          (atu_reg_out_func_bypass)
  ,.atu_reg_out_snp                  (atu_reg_out_snp)
  // -------------------------------------------------------------------------------------
  // Slave Write Address Channel
  ,.awvalid                          (strkr_awvalid)
  ,.awaddr                           (slv_aw.addr)
  ,.awid                             (slv_aw.id)
  ,.awlen                            (slv_aw.len)
  ,.awsize                           (slv_aw.size)
  ,.awburst                          (slv_aw.burst)
  ,.awatop                           (slv_aw.atop)
  ,.awmisc_info_type                 (slv_aw.misc_info_type)
  ,.awmisc_info_snp                  (slv_aw.misc_info_snp)
  ,.awmisc_info_ep                   (slv_aw.misc_info_ep)
  ,.awmisc_info_ns                   (slv_aw.misc_info_ns)
  ,.awmisc_info_ro                   (slv_aw.misc_info_ro)
  ,.awmisc_info_tc                   (slv_aw.misc_info_tc)
  ,.awmisc_info_msg_code             (slv_aw.misc_info_msg_code)
  ,.awmisc_info_db                   (slv_aw.misc_info_db)
  ,.awmisc_info_func_num             (slv_aw.misc_info_func_num)
  ,.awmisc_info_nw                   (slv_aw.misc_info_nw)
  ,.awmisc_info_ats                  (slv_aw.misc_info_ats)
  ,.awmisc_info_tlpprfx              (slv_aw.misc_info_tlpprfx)
  ,.awmisc_info_p_tag                (slv_aw.misc_info_p_tag)
  ,.awmisc_info_tph                  (slv_aw.misc_info_tph)
  ,.awmisc_info_atu_bypass           (slv_aw.misc_info_atu_bypass)
  ,.awmisc_info_dst_segment          (slv_aw.misc_info_dst_segment)
  ,.awmisc_info_ido                  (slv_aw.misc_info_ido)
  ,.awready                          (swrq_awready)
  // -------------------------------------------------------------------------------------
  // Slave Write Data Channel
  ,.wvalid                           (strkr_wvalid)
  ,.wid                              ({SLV_BUS_ID_WIDTH{1'b0}})
  ,.wdata                            (slv_w.data)
  ,.wstrb                            (slv_w.strb)
  ,.wlast                            (strkr_wlast)
  ,.wready                           (swrq_wready)
  ,.wmisc_info_ep                    (slv_w.misc_info_ep)
  ,.wmisc_info_silentDrop            (slv_w.misc_info_silentDrop)
   // -------------------------------------------------------------------------------------
   // AXI Write request information interface
  ,.swrq_wr_valid_hl                 (swrq_wr_valid_hl)
  ,.swrq_wr_id                       (swrq_wr_id)
  ,.swrq_wr_p                        (swrq_wr_p)
  ,.swrq_wr_np                       (swrq_wr_np)
  ,.swrq_wr_np_atomic                (swrq_wr_np_atomic)
  ,.swrq_wr_last_null_writes         (swrq_wr_last_null_writes)
  // -------------------------------------------------------------------------------------
  // Slave Posted Request Interface
  ,.swrq_p_valid                     (sif_p_valid)
  ,.swrq_p_id                        (sif_p_id)
  ,.swrq_p_addr                      (sif_p_addr)
  ,.swrq_p_size                      (sif_p_size)
  ,.swrq_p_len                       (sif_p_len)
  ,.swrq_p_last                      (sif_p_last)
  ,.swrq_p_strb                      (sif_p_strb)
  ,.swrq_p_ep_strb                   (sif_p_ep_strb)
  ,.swrq_p_silentDrop_strb           (sif_p_silentDrop_strb)
  ,.swrq_p_silentDrop_strb_masked    (sif_p_silentDrop_strb_masked)
  ,.swrq_p_data                      (sif_p_data)
  ,.swrq_p_msg_code                  (sif_p_msg_code)
  ,.swrq_p_type                      (sif_p_type)
  ,.swrq_p_tc                        (sif_p_tc)
  ,.swrq_p_ep                        (sif_p_ep)
  ,.swrq_p_ro                        (sif_p_ro)
  ,.swrq_p_ns                        (sif_p_ns)
  ,.swrq_p_first_wrp_split_xact      (sif_p_first_wrp_split_xact)
  ,.swrq_p_wrp_valid                 (sif_p_wrp_valid)
  ,.swrq_p_nw                        (sif_p_nw)
  ,.swrq_p_ats                       (sif_p_ats)
  ,.swrq_p_func_num                  (sif_p_func_num)
  ,.swrq_p_tph                       (sif_p_tph)
  ,.swrq_p_tlpprfx                   (sif_p_tlpprfx)
  ,.swrq_p_tag                       (sif_p_tag)
  ,.swrq_p_atu_bypass                (sif_p_atu_bypass)
  ,.swrq_p_dst_segment               (sif_p_dst_segment)
  ,.swrq_p_cpl_stat                  (sif_p_cpl_stat)
  ,.swrq_p_ido                       (sif_p_ido)
  ,.prf_ready                        (prf_ready)
  // -------------------------------------------------------------------------------------
  // Non-Posted Write Request Interface
  ,.swrq_npw_valid                   (swrq_npw_valid)
  ,.swrq_npw_id                      (swrq_npw_id)
  ,.swrq_npw_addr                    (swrq_npw_addr)
  ,.swrq_npw_size                    (swrq_npw_size)
  ,.swrq_npw_len                     (swrq_npw_len)
  ,.swrq_npw_last                    (swrq_npw_last)
  ,.swrq_npw_strb                    (swrq_npw_strb)
  ,.swrq_npw_data                    (swrq_npw_data)
  ,.swrq_npw_type                    (swrq_npw_type)
  ,.swrq_npw_snp                     (swrq_npw_snp)
  ,.swrq_npw_tc                      (swrq_npw_tc)
  ,.swrq_npw_ep                      (swrq_npw_ep)
  ,.swrq_npw_atomic_load_be          (swrq_npw_atomic_load_be)
  ,.swrq_npw_atomic_cas_wrap         (swrq_npw_atomic_cas_wrap)
  ,.swrq_npw_ns                      (swrq_npw_ns)
  ,.swrq_npw_ro                      (swrq_npw_ro)
  ,.swrq_npw_nw                      (swrq_npw_nw)
  ,.swrq_npw_ats                     (swrq_npw_ats)
  ,.swrq_npw_tph                     (swrq_npw_tph)
  ,.swrq_npw_first_wrp_split_xact    (swrq_npw_first_wrp_split_xact)
  ,.swrq_npw_wrp_valid               (swrq_npw_wrp_valid)
  ,.swrq_npw_db                      (swrq_npw_db)
  ,.swrq_npw_db_vldrq                (swrq_npw_db_vldrq)
  ,.swrq_npw_func_num                (swrq_npw_func_num)
  ,.swrq_npw_tlpprfx                 (swrq_npw_tlpprfx)
  ,.swrq_npw_atu_bypass              (swrq_npw_atu_bypass)
  ,.swrq_npw_dst_segment             (swrq_npw_dst_segment)
  ,.swrq_npw_ido                     (swrq_npw_ido)
  ,.swrq_npw_cpl_stat                (swrq_npw_cpl_stat)
  ,.srrq_npw_ready                   (srrq_npw_ready)
  // -------------------------------------------------------------------------------------
  // Parity error interface
  ,.swrq_addr_parerr                 (sif_addr_parerr)
  ,.swrq_data_parerr                 (sif_data_parerr)
  ,.ras_dp_err_inj_slv_aclk          (ras_dp_err_inj_slv_aclk)
  ,.swrq_dt_ras_dp_err_log           (sif_swrq_dt_ras_dp_err_log)
  ,.swrq_ad_ras_dp_err_log           (sif_swrq_ad_ras_dp_err_log)
  ,.swrq_ras_par_swwrap_dt_pulse     (sif_ras_par_swwrap_dt_pulse)
  ,.swrq_ras_par_swwrap_ad_pulse     (sif_ras_par_swwrap_ad_pulse)
  ,.swrq_swwrap_dt_ras_dp_err_log    (sif_swrq_swwrap_dt_ras_dp_err_log)
  ,.swrq_swwrap_ad_ras_dp_err_log    (sif_swrq_swwrap_ad_ras_dp_err_log)
  );

  // -------------------------------------------------------------------------------------
  // Instantiate Slave Non-Posted Response block
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_np_rsp_rtr
  
  #(.MAX_SLV_TAG                       (MAX_SLV_TAG)
   ,.MAX_SLV_TAG_PW                    (MAX_SLV_TAG_PW)
   ,.CX_RAS_PROT_RANGE                 (CX_RAS_PROT_RANGE)
   ,.SLV_BUS_DATA_WIDTH                (SLV_BUS_DATA_WIDTH)
   ,.SLV_BURST_LEN_PW                  (SLV_BURST_LEN_PW)
  )
  u_nprsp
  (.slv_aclk                         (slv_aclk)
  ,.slv_aresetn                      (slv_aresetn)
  // -------------------------------------------------------------------------------------
  // Client Non-Posted Response Interface
  ,.nprspf_valid                     (nprspf_valid)
  ,.nprspf_tag                       (nprspf_tag)
  ,.nprspf_to                        (nprspf_to)
  ,.nprspf_ep                        (nprspf_ep)
  ,.nprspf_tc                        (nprspf_tc)
  ,.nprspf_ido                       (nprspf_ido)
  ,.nprspf_ns                        (nprspf_ns)
  ,.nprspf_ro                        (nprspf_ro)
  ,.nprspf_status                    (nprspf_status)
  ,.nprspf_cpl                       (nprspf_cpl)
  ,.nprspf_cpl_segment               (nprspf_cpl_segment)
  ,.nprspf_dst_segment               (nprspf_dst_segment)
  ,.nprspf_resp                      (nprspf_resp)
  ,.nprspf_data                      (nprspf_data)
  ,.nprspf_last                      (nprspf_last)
  ,.nprsp_np_ready                   (sif_np_ready)
  // -------------------------------------------------------------------------------------
  // Data Bus Non-Posted Response Interface
  ,.dbi_valid                        (dbi_valid)
  ,.dbi_last                         (dbi_last)
  ,.dbi_tag                          (dbi_tag)
  ,.dbi_resp                         (dbi_resp)
  ,.dbi_data                         (dbi_data)
  ,.nprsp_db_ready                   (sif_db_ready)
  // DBIresponse indicatio to slave response
  ,.dbi_response                     (s_dbi_response)
  // -------------------------------------------------------------------------------------
  // Response order information interface
  ,.atm_cpl_seg_halt                 (atm_cpl_seg_halt)
  // -------------------------------------------------------------------------------------
  // Muxed Non-Posted Response Interface
  ,.nprsp_valid                      (s_nprsp_valid)
  ,.nprsp_tag                        (s_nprsp_tag)
  ,.nprsp_to                         (s_nprsp_to)
  ,.nprsp_ep                         (s_nprsp_ep)
  ,.nprsp_tc                         (s_nprsp_tc)
  ,.nprsp_ido                        (s_nprsp_ido)
  ,.nprsp_ns                         (s_nprsp_ns)
  ,.nprsp_ro                         (s_nprsp_ro)
  ,.nprsp_status                     (s_nprsp_status)
  ,.nprsp_cpl                        (s_nprsp_cpl)
  ,.nprsp_cpl_segment                (s_nprsp_cpl_segment)
  ,.nprsp_dst_segment                (s_nprsp_dst_segment)
  ,.nprsp_resp                       (s_nprsp_resp)
  ,.nprsp_data                       (s_nprsp_data)
  ,.nprsp_last                       (s_nprsp_last)
  ,.srsp_np_ready                    (srsp_np_ready)
  );

  // -------------------------------------------------------------------------------------
  // Instantiate Slave Response block
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_rsp
  
  #(.SLV_BUS_ID_WIDTH                      (SLV_BUS_ID_WIDTH)
   ,.SLV_BURST_LEN_PW                      (SLV_BURST_LEN_PW)
   ,.NFUNC_WD                              (3)
   ,.MISC_INFO_TPH_WD                      (MISC_INFO_TPH_WD)
   ,.SLV_BUS_STRB_WIDTH                    (SLV_BUS_WSTRB_WIDTH)
   ,.SLV_BUS_STRB_PW                       (SLV_BUS_WSTRB_PW)
   ,.SLV_BUS_DATA_WIDTH                    (SLV_BUS_DATA_WIDTH)
   ,.SLV_NUM_OUTSTND_WR_REQ                (SLV_NUM_OUTSTND_WR_REQ)
   ,.SLV_NUM_OUTSTND_WR_REQ_LOG2           (SLV_NUM_OUTSTND_WR_REQ_LOG2)
   ,.SLV_WRP_RSP_ROB_FIFO_DP                (SLV_WRP_RSP_ROB_FIFO_DP)
   ,.SLV_WRP_RSP_ROB_FIFO_ADDR_WD           (SLV_WRP_RSP_ROB_FIFO_ADDR_WD)
   ,.MAX_SLV_TAG                           (MAX_SLV_TAG)
   ,.MAX_SLV_TAG_PW                        (MAX_SLV_TAG_PW)
  )
  u_srsp
  (.slv_aclk                         (slv_aclk)
  ,.slv_aresetn                      (slv_aresetn)
   ,.srsp_ras_par_rslv_dt_pulse      (axi_ras_par_rslv_dt_pulse)
   ,.srsp_rslv_dt_ras_dp_err_log     (axi_srsp_rslv_dt_ras_dp_err_log)
   ,.ras_dp_err_inj_slv_aclk         (ras_dp_err_inj_slv_aclk)
  // -------------------------------------------------------------------------------------
  // Error response configuration interface
  ,.cfg_err_resp_mode                (cfg_err_resp_mode)
  ,.cfg_err_resp_map                 (cfg_err_resp_map)
  // -------------------------------------------------------------------------------------
  // AXI Write request information interface
  ,.swrq_wr_valid_hl                 (swrq_wr_valid_hl)
  ,.swrq_wr_id                       (swrq_wr_id)
  ,.swrq_wr_p                        (swrq_wr_p)
  ,.swrq_wr_np                       (swrq_wr_np)
  ,.swrq_wr_np_atomic                (swrq_wr_np_atomic)
  ,.swrq_wr_last_null_writes         (swrq_wr_last_null_writes)
  // DBI indication in
  ,.dbi_response                     (s_dbi_response)
  // Non-Posted Response interface
  ,.nprspf_valid                     (s_nprsp_valid)
  ,.nprspf_tag                       (s_nprsp_tag)
  ,.nprspf_to                        (s_nprsp_to)
  ,.nprspf_ep                        (s_nprsp_ep)
  ,.nprspf_tc                        (s_nprsp_tc)
  ,.nprspf_ido                       (s_nprsp_ido)
  ,.nprspf_ns                        (s_nprsp_ns)
  ,.nprspf_ro                        (s_nprsp_ro)
  ,.nprspf_status                    (s_nprsp_status)
  ,.nprspf_cpl                       (s_nprsp_cpl)
  ,.nprspf_cpl_segment               (s_nprsp_cpl_segment)
  ,.nprspf_dst_segment               (s_nprsp_dst_segment)
  ,.nprspf_resp                      (s_nprsp_resp)
  ,.nprspf_data                      (s_nprsp_data)
  ,.nprspf_last                      (s_nprsp_last)
  ,.srsp_np_ready                    (srsp_np_ready)
  // -------------------------------------------------------------------------------------
  // AXI tag manager control interface
  ,.srsp_np_tag_recycled             (srsp_np_tag_recycled)
  ,.srsp_np_tag                      (srsp_np_tag)
  ,.atm_np_wr                        (atm_np_wr)
  ,.atm_np_id                        (atm_np_id)
  ,.atm_np_addr_low                  (atm_np_addr_low)
  ,.atm_np_len                       (atm_np_len)
  ,.atm_np_size                      (atm_np_size)
  ,.atm_np_atomic                    (atm_np_atomic)
  ,.atm_np_wrap_beat_offset          (atm_np_wrap_beat_offset)
  ,.atm_np_ven_id_rd                 (atm_np_ven_id_rd)
  // -------------------------------------------------------------------------------------
  // Read response interface
  ,.srsp_rvalid                      (slv_r.valid)
  ,.srsp_rid                         (slv_r.id)
  ,.srsp_rto                         (slv_r.timeout)
  ,.srsp_rep                         (slv_r.ep)
  ,.srsp_rtc                         (slv_r.tc)
  ,.srsp_rido                        (slv_r.ido)
  ,.srsp_rns                         (slv_r.ns)
  ,.srsp_rro                         (slv_r.ro)
  ,.srsp_rstatus                     (slv_r.status)
  ,.srsp_rcpl                        (slv_r.cpl)
  ,.srsp_rresp                       (slv_r.resp)
  ,.srsp_rdata                       (slv_r.data)
  ,.srsp_rlast                       (slv_r.last)
  ,.rready                           (slv_r.ready)
  ,.srsp_rcpl_segment                (slv_r.cpl_segment)
  ,.srsp_rdst_segment                (slv_r.dst_segment)
  // DBIresponse indication
  ,.dbi_response_rd                  (dbi_rd_rsp)
  ,.dbi_response_wr                  (dbi_wr_rsp)
  // -------------------------------------------------------------------------------------
  // Posted Response Interface
  ,.pdcmp_p_rsp_valid_hl             (pdcmp_p_rsp_valid_hl)
  ,.pdcmp_p_rsp_id                   (pdcmp_p_rsp_id)
  ,.pdcmp_p_rsp_cpl_stat             (pdcmp_p_rsp_cpl_stat)
  // -------------------------------------------------------------------------------------
  // Non Posted Atomic Response Interface
  ,.npdcmp_np_atomic_rsp_valid_hl    (npdcmp_np_atomic_rsp_valid_hl)
  ,.npdcmp_np_atomic_rsp_id          (npdcmp_np_atomic_rsp_id)
  // -------------------------------------------------------------------------------------
  // AXI Write Response Interface
  ,.srsp_bvalid_hl                   (slv_b.valid)
  ,.srsp_bid                         (slv_b.id)
  ,.srsp_bresp                       (slv_b.resp)
  ,.srsp_bto                         (slv_b.timeout)
  ,.srsp_bep                         (slv_b.ep)
  ,.srsp_btc                         (slv_b.tc)
  ,.srsp_bns                         (slv_b.ns)
  ,.srsp_bro                         (slv_b.ro)
  ,.srsp_bstatus                     (slv_b.status)
  ,.srsp_bcpl                        (slv_b.cpl)
  ,.srsp_bcpl_segment                (slv_b.cpl_segment)
  ,.srsp_bdst_segment                (slv_b.dst_segment)
  ,.bready                           (slv_b.ready)
  // Completions Status during DPC
  ,.cdc_core_in_dpc_i                (cdc_core_in_dpc_i      )
  ,.qst_cfg_dpc_cpl_cntrl_i          (qst_cfg_dpc_cpl_cntrl_i)
  );

  // -------------------------------------------------------------------------------------
  // Instantiate AXI Slave activity tracker
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_trkr
  
 #(.SLV_NUM_OUTSTND_WR_REQ                 (SLV_NUM_OUTSTND_WR_REQ)
  ,.SLV_NUM_OUTSTND_WR_REQ_LOG2            (SLV_NUM_OUTSTND_WR_REQ_LOG2)
  ,.MAX_SLV_TAG_PW                         (MAX_SLV_TAG_PW)
  )
  u_strkr
  (.slv_aclk                         (slv_aclk)
  ,.slv_aclk_ug                      (slv_aclk_ug)
  ,.slv_aresetn                      (slv_aresetn)
  // Flush control interface
  ,.flshctl_sif_flush_req            (flshctl_sif_flush_req)
  ,.strkr_flush_ack                  (sif_flush_ack)
  // AXI Write address channel
  ,.slv_awvalid                      (slv_aw.valid)
  ,.slv_awatop                       (slv_aw.atop)
  ,.strkr_awready                    (slv_aw.ready)
  // Tracker write address channel
  ,.strkr_awvalid                    (strkr_awvalid)
  ,.swrq_awready                     (swrq_awready)
  // AXI Write data channel
  ,.slv_wvalid                       (slv_w.valid)
  ,.slv_wlast                        (slv_w.last)
  ,.slv_wready                       (slv_w.ready)
  // Tracker write data channel
  ,.strkr_wvalid                     (strkr_wvalid)
  ,.strkr_wlast                      (strkr_wlast)
  ,.swrq_wready                      (swrq_wready)
  // AXI Write response interface
  ,.slv_bvalid                       (slv_b.valid)
  ,.slv_bready                       (slv_b.ready)
  // AXI Read request interface
  ,.slv_arvalid                      (slv_ar.valid)
  ,.slv_arready                      (slv_ar.ready)
  // AXI Read response interface
  ,.slv_rvalid                       (slv_r.valid)
  ,.slv_rlast                        (slv_r.last)
  ,.slv_rready                       (slv_r.ready)
  // Power Down Interface
  // AXI shared DBI access notification (AR & AW)
  ,.slv_ar_db                        (slv_ar.misc_info_db)
  ,.slv_aw_db                        (slv_aw.misc_info_db)
  ,.dbi_wr_rsp                       (dbi_wr_rsp    )
  ,.dbi_rd_rsp                       (dbi_rd_rsp    )
  // DBI transfer pending signal
  ,.strkr_xfer_pending_db            (sif_xfer_pending_db)
  // Slave transaction pending interface
  ,.strkr_xfer_pending               (s_sif_xfer_pending)
  );

  assign sif_xfer_pending = s_sif_xfer_pending ;



  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------

endmodule
