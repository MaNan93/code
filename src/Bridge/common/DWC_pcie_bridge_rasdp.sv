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
// ---    $Revision: #18 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_rasdp.sv#18 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Axi/DWC_pcie_axi_mstr_pkg.svh"
`include "Axi/DWC_pcie_axi_slv_pkg.svh"
`include "Axi/DWC_pcie_axi_xali_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_bridge_rasdp
  import DWC_pcie_axi_mstr_pkg::*;
  import DWC_pcie_axi_slv_pkg::*;
  import DWC_pcie_axi_xali_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter CX_RAS_PROT_RANGE                    = 8,
    parameter CX_RAS_PARITY_MODE                   = `CX_RAS_PARITY_MODE,
    parameter MSTR_ADDR_WD                         = 36,
    parameter MSTR_ADDR_WD_NP                      = 32,
    parameter MSTR_BUS_ADDRP_WIDTH                 = 4,
    parameter MSTR_DATA_WD                         = 36,
    parameter MSTR_DATA_WD_NP                      = 32,
    parameter MSTR_DATAP_WD                        = 4,
    parameter CORE_DATA_BUS_WD                     = 36,
    parameter PCIE_CORE_DATA_BUS_WD                = 32,
    parameter CLIENT_HDR_PROT_WD                   = `CLIENT_HDR_PROT_WD,
    parameter CLIENT_HDR_WD                        = `CLIENT_HDR_WD,
    parameter SLV_BUS_DATA_WIDTH_NP                = 32,
    parameter SLV_BUS_DATA_WIDTH                   = 36,
    parameter SLV_BUS_DATAP_WIDTH                  = 4,
    parameter SLV_BUS_WSTRB_WIDTH                  = 4,
    parameter SLAVE_BUS_ADDR_WIDTH                 = 32,
    parameter SLV_BUS_ADDRP_WIDTH                  = 4,
    parameter SLV_BUS_ADDR_WIDTH                   = 36,
    parameter ADDR_PAR_WD                          = `CX_ADDR_PAR_WD,
    parameter SLV_NPW_SAB_RAM_ADDR_WD              = `CC_SLV_NPW_SAB_RAM_ADDR_WD,
    parameter OB_NPDCMP_RAM_ADDR_WD                = `CC_OB_NPDCMP_RAM_ADDR_WD,
    parameter OB_PDCMP_HDR_RAM_ADDR_WD             = `CC_OB_PDCMP_HDR_RAM_ADDR_WD,
    parameter OB_PDCMP_DATA_RAM_ADDR_WD            = `CC_OB_PDCMP_DATA_RAM_ADDR_WD,
    parameter CC_OB_CCMP_DATA_RAM_ADDR_WD          = `CC_OB_CCMP_DATA_RAM_ADDR_WD,
    parameter CC_OB_CCMP_NSLICES                   = `CC_OB_CCMP_NSLICES,
    parameter CC_IB_RD_REQ_ORDR_RAM_ADDR_WD        = `CC_IB_RD_REQ_ORDR_RAM_ADDR_WD,
    parameter CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD    = `CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD,
    parameter CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD   = `CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD,
    parameter CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD   = `CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD,
    parameter CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD  = `CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD,
    parameter CC_IB_RD_REQ_CDC_RAM_ADDR_WD         = `CC_IB_RD_REQ_CDC_RAM_ADDR_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_ADDR_WD         = `CC_IB_WR_REQ_CDC_RAM_ADDR_WD,
    parameter CC_IB_MCPL_CDC_RAM_ADDR_WD           = `CC_IB_MCPL_CDC_RAM_ADDR_WD,
    parameter CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD       = `CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD,
    parameter OB_NPDCMP_RAM_ADDRP_WD               = `CC_OB_NPDCMP_RAM_ADDRP_WD,
    parameter OB_PDCMP_HDR_RAM_ADDRP_WD            = `CC_OB_PDCMP_HDR_RAM_ADDRP_WD,
    parameter OB_PDCMP_DATA_RAM_ADDRP_WD           = `CC_OB_PDCMP_DATA_RAM_ADDRP_WD,
    parameter SLV_NPW_SAB_RAM_ADDRP_WD             = `CC_SLV_NPW_SAB_RAM_ADDRP_WD,
    parameter CC_OB_CCMP_DATA_RAM_ADDRP_WD         = `CC_OB_CCMP_DATA_RAM_ADDRP_WD,
    parameter CC_IB_RD_REQ_CDC_RAM_ADDRP_WD        = `CC_IB_RD_REQ_CDC_RAM_ADDRP_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_ADDRP_WD        = `CC_IB_WR_REQ_CDC_RAM_ADDRP_WD,
    parameter CC_IB_MCPL_CDC_RAM_ADDRP_WD          = `CC_IB_MCPL_CDC_RAM_ADDRP_WD,
    parameter CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD       = `CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD,
    parameter CC_IB_SCHEDULER_P_HDR_RAM_ADDRP_WD   = `CC_IB_SCHEDULER_P_HDR_RAM_ADDRP_WD,
    parameter CC_IB_SCHEDULER_P_DATA_RAM_ADDRP_WD  = `CC_IB_SCHEDULER_P_DATA_RAM_ADDRP_WD,
    parameter CC_IB_SCHEDULER_NP_HDR_RAM_ADDRP_WD  = `CC_IB_SCHEDULER_NP_HDR_RAM_ADDRP_WD,
    parameter CC_IB_SCHEDULER_NP_DATA_RAM_ADDRP_WD = `CC_IB_SCHEDULER_NP_DATA_RAM_ADDRP_WD,
    parameter CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD      = `CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD,
    parameter NVC_XALI_EXP                    = `CX_NVC_XALI_EXPANSION,
    parameter TP                              = `TP
    )
   (

    input                                        core_clk
   ,input                                        core_rst_n
   ,input                                        mstr_aclk
   ,input                                        mstr_aclk_ug
   ,input                                        mstr_aresetn
   ,input                                        slv_aclk
   ,input                                        slv_aclk_ug
   ,input                                        slv_aresetn
   ,input                                        cfg_rasdp_err_mode
   ,input ras_dp_err_inj_t                       axi_bridge_ras_dp_err_inj_core_clk
   ,input ras_dp_err_inj_t                       core_clk_hp_mstr_ras_dp_err_inj
   ,input                                        cfg_rasdp_err_mode_en_d
   ,input                                        cfg_rasdp_err_mode_en_d1
   ,output                                       mstr_rasdp_err_mode
   ,output                                       slv_rasdp_err_mode
   ,input                                        mcb_ras_par_ib_mcpl_a2c_dt_pulse
   ,output                                       axi_ras_par_ib_mcpl_a2c_dt_pulse
   ,input  [`MASTER_BUS_ADDR_WIDTH-1:0]           msg_addr_int
   ,output [ (`CC_MSTR_BUS_ADDR_WIDTH - `MASTER_BUS_ADDR_WIDTH) -1:0] msg_par

   ,input                                        axigm_ras_par_ibr_rmstr_ad_pulse

   ,input                                        axigm_ras_par_ibr_wmstr_ad_pulse

   ,input                                        axigm_ras_par_ibr_wmstr_dt_pulse


   ,input [NVC_XALI_EXP-1:0]                     client0_tlp_dv
   ,input [NVC_XALI_EXP-1:0]                     xadm_client0_halt

   ,input [(NVC_XALI_EXP*CORE_DATA_BUS_WD)-1:0]  client0_tlp_data
   ,output                                       axi_ras_par_ib_mcpl_dt_pulse
   ,output ras_dp_err_log_t                      axi_ib_mcpl_dt_ras_dp_err_log      // core_clk //


   // ECC and Parity of the AXI Interface Monitoring signals
   ,input  pkg_axi_slv_par_sts                   slv_if_ras_err_sts
   ,output                                       axi_ras_slv_if_uncorr_pulse
   ,input                                        mstr_if_ras_err_sts
   ,output                                       axi_ras_mstr_if_uncorr_pulse

   ,input [(NVC_XALI_EXP*CLIENT_HDR_WD)-1:0]       client0_hdr
   ,output [(NVC_XALI_EXP*CLIENT_HDR_PROT_WD)-1:0] client0_hdr_prot

   ,input  [`SLAVE_BUS_ADDR_WIDTH-1:0]           msg_addr_slv_int
   ,output [`CC_SLV_BUS_ADDR_WIDTH-1:0]          msg_addr_w_par_slv

   ,input                                        sif_ras_par_rslv_dt_pulse

   ,input                                        sif_ras_par_slnull_ad_pulse
   ,output                                       axi_ras_par_slnull_ad_pulse

   ,input                                        sif_ras_par_slnull_dt_pulse
   ,output                                       axi_ras_par_slnull_dt_pulse

   ,input                                        ob_ras_par_npqdec_ad_pulse
   ,output                                       axi_ras_par_npqdec_ad_pulse

   ,input                                        ob_ras_par_pqdec_ad_pulse
   ,output                                       axi_ras_par_pqdec_ad_pulse

   ,input  [NVC_XALI_EXP-1:0]                    client1_tlp_hv
   ,input  [(NVC_XALI_EXP*CORE_DATA_BUS_WD)-1:0] client1_tlp_data
   ,input  [(NVC_XALI_EXP*CLIENT_HDR_WD)-1:0]    client1_hdr
   ,output [(NVC_XALI_EXP*CLIENT_HDR_PROT_WD)-1:0] client1_hdr_prot
   ,input  [NVC_XALI_EXP-1:0]                    client1_tlp_dv
   ,input  [NVC_XALI_EXP-1:0]                    xadm_client1_halt

   ,output                                       axi_ras_par_c1_dt_pulse
   ,output ras_dp_err_log_t                      axi_c1_dt_ras_dp_err_log    // core_clk //

   ,input  [NVC_XALI_EXP-1:0]                    client2_tlp_hv
   ,input  [(NVC_XALI_EXP*CORE_DATA_BUS_WD)-1:0] client2_tlp_data
   ,input  [(NVC_XALI_EXP*CLIENT_HDR_WD)-1:0]    client2_hdr
   ,output [(NVC_XALI_EXP*CLIENT_HDR_PROT_WD)-1:0] client2_hdr_prot
   ,input  [NVC_XALI_EXP-1:0]                    client2_tlp_dv
   ,input  [NVC_XALI_EXP-1:0]                    xadm_client2_halt

   ,output                                       axi_ras_par_c2_dt_pulse
   ,output ras_dp_err_log_t                      axi_c2_dt_ras_dp_err_log    // core_clk //

   ,input [(NVC_XALI_EXP*64)-1:0]                client1_tlp_addr
  ,input [(NVC_XALI_EXP*ADDR_PAR_WD)-1:0]        client1_tlp_addr_par
   ,output                                       axi_ras_par_c1_ad_pulse
   ,output ras_dp_err_log_t                      axi_c1_ad_ras_dp_err_log    // core_clk //

   ,input [(NVC_XALI_EXP*64)-1:0]                client2_tlp_addr
   ,input [(NVC_XALI_EXP*ADDR_PAR_WD)-1:0]       client2_tlp_addr_par
   ,output                                       axi_ras_par_c2_ad_pulse
   ,output ras_dp_err_log_t                      axi_c2_ad_ras_dp_err_log    // core_clk //

   ,input                                        sif_ras_recc_ucorr_cnt_npw_sab_pulse
   ,input [SLV_NPW_SAB_RAM_ADDR_WD-1:0]          sif_ras_recc_cnt_npw_sab_addr
   ,output                                       axi_ras_recc_ucorr_cnt_npw_sab_pulse
   ,output [SLV_NPW_SAB_RAM_ADDR_WD-1:0]         axi_ras_recc_ucorr_cnt_npw_sab_addr

   ,input                                        sif_ras_recc_corr_cnt_npw_sab_pulse
   ,output                                       axi_ras_recc_corr_cnt_npw_sab_pulse
   ,output [SLV_NPW_SAB_RAM_ADDR_WD-1:0]         axi_ras_recc_corr_cnt_npw_sab_addr


   ,input                                        sif_ras_par_swwrap_dt_pulse
   ,input                                        sif_ras_par_swwrap_ad_pulse
   ,input                                        sif_ras_par_srwrap_ad_pulse
   ,output                                       axi_ras_par_swwrap_dt_pulse
   ,output                                       axi_ras_par_swwrap_ad_pulse
   ,output                                       axi_ras_par_srwrap_ad_pulse

   ,input                                        sif_ras_par_swrq_npw_dt_pulse
   ,input                                        sif_ras_par_swrq_npw_ad_pulse
   ,output                                       axi_ras_par_swrq_npw_dt_pulse
   ,output                                       axi_ras_par_swrq_npw_ad_pulse

   ,input                                        ob_ras_par_ob_p_dcmp_inq_dt_pulse
   ,output                                       axi_ras_par_ob_p_dcmp_inq_dt_pulse

   ,input                                        ob_ras_par_ob_np_dcmp_inq_dt_pulse
   ,output                                       axi_ras_par_ob_np_dcmp_inq_dt_pulse

   ,input                                        ob_ras_recc_ucorr_cnt_ob_npdcmp_pulse
   ,input [OB_NPDCMP_RAM_ADDR_WD-1:0]            ob_ras_recc_cnt_ob_npdcmp_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse
   ,output [OB_NPDCMP_RAM_ADDR_WD-1:0]           axi_ras_recc_ucorr_cnt_ob_npdcmp_addr

   ,input                                        ob_ras_recc_corr_cnt_ob_npdcmp_pulse
   ,output                                       axi_ras_recc_corr_cnt_ob_npdcmp_pulse
   ,output [OB_NPDCMP_RAM_ADDR_WD-1:0]           axi_ras_recc_corr_cnt_ob_npdcmp_addr

   ,input                                        ob_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse
   ,input [OB_PDCMP_HDR_RAM_ADDR_WD-1:0]         ob_ras_recc_cnt_ob_pdcmp_hdr_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse
   ,output [OB_PDCMP_HDR_RAM_ADDR_WD-1:0]        axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr

   ,input                                        ob_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse
   ,output                                       axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse
   ,output [OB_PDCMP_HDR_RAM_ADDR_WD-1:0]        axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr

   ,input                                        ob_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse
   ,input [OB_PDCMP_DATA_RAM_ADDR_WD-1:0]        ob_ras_recc_cnt_ob_pdcmp_data_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse
   ,output [OB_PDCMP_DATA_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr

   ,input                                        ob_ras_recc_corr_cnt_ob_pdcmp_data_pulse
   ,output                                       axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse
   ,output [OB_PDCMP_DATA_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ob_pdcmp_data_addr

   ,input                                        ob_ras_recc_ucorr_cnt_ob_ccmp_data_pulse
   ,input [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]      ob_ras_recc_cnt_ob_ccmp_data_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse
   ,output [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]     axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr

   ,input                                        ob_ras_recc_corr_cnt_ob_ccmp_data_pulse
   ,output                                       axi_ras_recc_corr_cnt_ob_ccmp_data_pulse
   ,output [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]     axi_ras_recc_corr_cnt_ob_ccmp_data_addr

   ,input                                                 ibreq_ras_recc_corr_cnt_ib_sch_p_hdr_pulse
   ,output wire                                           axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse
   ,output wire [CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]   axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr
   ,input                                                 ibreq_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse
   ,input       [CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]   ibreq_ras_recc_cnt_ib_sch_p_hdr_addr
   ,output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse
   ,output wire [CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]   axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr

   ,input                                                 ibreq_ras_recc_corr_cnt_ib_sch_p_data_pulse
   ,output wire                                           axi_ras_recc_corr_cnt_ib_sch_p_data_pulse
   ,output wire [CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]  axi_ras_recc_corr_cnt_ib_sch_p_data_addr
   ,input                                                 ibreq_ras_recc_ucorr_cnt_ib_sch_p_data_pulse
   ,input       [CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]  ibreq_ras_recc_cnt_ib_sch_p_data_addr
   ,output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse
   ,output wire [CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]  axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr

   ,input                                                 ibreq_ras_recc_corr_cnt_ib_sch_np_hdr_pulse
   ,output wire                                           axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse
   ,output wire [CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr
   ,input                                                 ibreq_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse
   ,input       [CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]  ibreq_ras_recc_cnt_ib_sch_np_hdr_addr
   ,output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse
   ,output wire [CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr

   ,input                                                 ibreq_ras_recc_corr_cnt_ib_sch_np_data_pulse
   ,output wire                                           axi_ras_recc_corr_cnt_ib_sch_np_data_pulse
   ,output wire [CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_np_data_addr
   ,input                                                 ibreq_ras_recc_ucorr_cnt_ib_sch_np_data_pulse
   ,input       [CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0] ibreq_ras_recc_cnt_ib_sch_np_data_addr
   ,output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse
   ,output wire [CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr
   ,input                                        ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse
   ,input [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]     ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse
   ,output [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]    axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr

   ,input                                        ibreq_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse
   ,output                                       axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse
   ,output [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]    axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr

   ,input                                        ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse
   ,input [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]     ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse
   ,output [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]    axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr

   ,input                                        ibreq_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse
   ,output                                       axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse
   ,output [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]    axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr


   ,input                                        mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse
   ,input [CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]       mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse
   ,output [CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]      axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr

   ,input                                        mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse
   ,output                                       axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse
   ,output [CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]      axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr


   ,input                                        mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse
   ,input [CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]   mcb_ras_recc_cnt_ib_mcpl_sb_addr
   ,output                                       axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse
   ,output [CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]  axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr

   ,input                                        mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse
   ,output                                       axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse
   ,output [CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]  axi_ras_recc_corr_cnt_ib_mcpl_sb_addr




    );

   // ---------------------------------------------------------------------------
   // Local parameters declaration
   // ---------------------------------------------------------------------------
   localparam PARITY_BIT = CX_RAS_PARITY_MODE ? 1'b1 : 1'b0;

   localparam SYNC_TYPE = `CX_PCIE_SYNC_DEPTH; // Forward synchroniser, +ve edge. Reverse synchroniser, +ve edge.
   localparam VERIF_EN  = 1; // Emulate 0 to 1 destination clock cycle sampling error.
   localparam SEND_MODE = 1; // Rising edge transition in, single clock cycle pulse out.

   // ---------------------------------------------------------------------------
   // Wires declaration
   // ---------------------------------------------------------------------------

   logic [NVC_XALI_EXP-1:0][CLIENT_HDR_WD-1:0]      s_client0_hdr_vc;
   logic [NVC_XALI_EXP-1:0][CLIENT_HDR_PROT_WD-1:0] s_client0_hdr_prot_vc;
   xali_exp_client_ras_hdr_s                        s_client0_hdr;

   logic [NVC_XALI_EXP-1:0][CLIENT_HDR_WD-1:0]      s_client1_hdr_vc;
   logic [NVC_XALI_EXP-1:0][CLIENT_HDR_PROT_WD-1:0] s_client1_hdr_prot_vc;
   xali_exp_client_ras_hdr_s                        s_client1_hdr;

   logic [NVC_XALI_EXP-1:0][CLIENT_HDR_WD-1:0]      s_client2_hdr_vc;
   logic [NVC_XALI_EXP-1:0][CLIENT_HDR_PROT_WD-1:0] s_client2_hdr_prot_vc;
   xali_exp_client_ras_hdr_s                        s_client2_hdr;

   ras_xali_data_s [NVC_XALI_EXP-1:0]               s_client1_tlp_data_vc;
   logic [NVC_XALI_EXP-1:0]                         s_chkc1_dt_pulse_vc;
   logic [NVC_XALI_EXP-1:0]                         s_par_c1_dt_pulse_vc;

   ras_xali_data_s [NVC_XALI_EXP-1:0]               s_client2_tlp_data_vc;
   logic [NVC_XALI_EXP-1:0]                         s_chkc2_dt_pulse_vc;
   logic [NVC_XALI_EXP-1:0]                         s_par_c2_dt_pulse_vc;

   logic [NVC_XALI_EXP-1:0][63:0]                   s_client1_tlp_addr_payload_vc;
   logic [NVC_XALI_EXP-1:0][ADDR_PAR_WD-1:0]        s_client1_tlp_addr_parity_vc;
   logic [NVC_XALI_EXP-1:0]                         s_chkc1_ad_pulse_vc;
   logic [NVC_XALI_EXP-1:0]                         s_par_c1_ad_pulse_vc;

   logic [NVC_XALI_EXP-1:0][63:0]                   s_client2_tlp_addr_payload_vc;
   logic [NVC_XALI_EXP-1:0][ADDR_PAR_WD-1:0]        s_client2_tlp_addr_parity_vc;
   logic [NVC_XALI_EXP-1:0]                         s_chkc2_ad_pulse_vc;
   logic [NVC_XALI_EXP-1:0]                         s_par_c2_ad_pulse_vc;

   wire                                          chkc0_ib_mcpl_dt_pulse;
   wire                                          chkc1_dt_pulse;
   wire                                          chkc2_dt_pulse;

   wire                                          chkc1_ad_pulse;
   wire                                          chkc2_ad_pulse;

   wire                                          cdc_mstr_rasdp_err_mode;
   wire                                          s_mstr_rasdp_err_mode;
   reg                                           r_mstr_rasdp_err_mode;
   wire                                          mr_mstr_rasdp_err_mode;
   wire                                          cdc_slv_rasdp_err_mode;
   wire                                          sr_slv_rasdp_err_mode;
   wire                                          s_slv_rasdp_err_mode;
   reg                                           r_slv_rasdp_err_mode;
   reg                                           r_cfg_rasdp_err_mode;
   wire                                          mcb_ras_par_ib_mcpl_a2c_dt_pulse_g;
   wire                                          axigm_ras_par_ibr_rmstr_ad_pulse_g;
   wire                                          axigm_ras_par_ibr_rmstr_dt_pulse_g;
   wire                                          axigm_ras_par_ibr_wmstr_ad_pulse_g;
   wire                                          axigm_ras_par_ibr_wmstr_dt_pulse_g;
   wire                                          sif_ras_par_wslv_ad_pulse_g;
   wire                                          sif_ras_par_wslv_dt_pulse_g;
   wire                                          sif_ras_par_rslv_ad_pulse_g;
   wire                                          sif_ras_par_rslv_dt_pulse_g;
   wire                                          sif_ras_par_slnull_ad_pulse_g;
   wire                                          sif_ras_par_slnull_dt_pulse_g;
   wire                                          ob_ras_par_npqdec_ad_pulse_g;
   wire                                          ob_ras_par_pqdec_ad_pulse_g;
   wire                                          ob_ras_par_pqdec_dt_pulse_g;

   wire                                          sif_ras_par_swwrap_dt_pulse_g;
   wire                                          sif_ras_par_swwrap_ad_pulse_g;
   wire                                          sif_ras_par_srwrap_ad_pulse_g;
   wire                                          sif_ras_par_swrq_npw_dt_pulse_g;
   wire                                          sif_ras_par_swrq_npw_ad_pulse_g;

   wire                                          ob_ras_par_ob_np_dcmp_inq_dt_pulse_g;
   wire                                          ob_ras_par_ob_p_dcmp_inq_dt_pulse_g;

   wire [SLV_BUS_DATA_WIDTH-1:0]                 prswd_wdata_i;



   always @ (posedge core_clk or negedge core_rst_n) begin : PROC_seq_r_cfg_rasdp_err_mode
      if (!core_rst_n)
        r_cfg_rasdp_err_mode <= #TP 1'b0;
      else
        r_cfg_rasdp_err_mode <= #TP cfg_rasdp_err_mode;
   end




   assign mcb_ras_par_ib_mcpl_a2c_dt_pulse_g = mcb_ras_par_ib_mcpl_a2c_dt_pulse & !r_mstr_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_mcpl_a2c_dt
       (
        .clk_s  (mstr_aclk   ),
        .rst_s_n(mstr_aresetn),
        .init_s_n(1'b1),
        .event_s(mcb_ras_par_ib_mcpl_a2c_dt_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_ib_mcpl_a2c_dt_pulse)
        );




logic mstr_if_ras_uncorr_err_group;
assign mstr_if_ras_uncorr_err_group  = |{axigm_ras_par_ibr_wmstr_ad_pulse,
                                         axigm_ras_par_ibr_wmstr_dt_pulse,
                                         axigm_ras_par_ibr_rmstr_ad_pulse
                                        ,mstr_if_ras_err_sts
                                        };

   logic mstr_if_ras_uncorr_err_sts_g;

   assign mstr_if_ras_uncorr_err_sts_g = mstr_if_ras_uncorr_err_group & !r_mstr_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_ibr_rmstr_uncorr
       (
        .clk_s  (mstr_aclk   ),
        .rst_s_n(mstr_aresetn),
        .init_s_n(1'b1),
        .event_s(mstr_if_ras_uncorr_err_sts_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_mstr_if_uncorr_pulse)
        );




  ras_xali_data_s [NVC_XALI_EXP-1:0]  s_client0_tlp_data_vc;
  logic [NVC_XALI_EXP-1:0]            s_chkc0_ib_mcpl_dt_pulse_vc;
  logic [NVC_XALI_EXP-1:0]            s_par_ib_mcpl_dt_pulse_vc;

  assign s_client0_tlp_data_vc = client0_tlp_data;

  generate

    genvar vc_c0_dt;
    for (vc_c0_dt=0; vc_c0_dt < NVC_XALI_EXP; vc_c0_dt++) begin : PROC_g_vc_c0_dt_par_chk

        ras_dp_pipe
         #(
         .PIPELINE_TYPE             (0                            ),
         .RESETVAL                  (0                            ),
         .N_STAGES                  (0                            ),
         .CAN_STALL                 (0                            ),
         .RESET_STALL               (0                            ),
         .BUS_PROTECT_GEN_EN        (0                            ),
         .BUS_PROTECT_CHK_EN        (1                            ),
         .PROT_TYPE                 (1                            ), // parity
         .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
         .PROT_WD                   (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD),
         .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
         .PROT_CORRECT_EN           (0                            ),
         .TOTAL_WIDTH               (PCIE_CORE_DATA_BUS_WD        ),
         .EXCLUDE_PROT_WIDTH        (0                            ),
         .RAS_DP_PROT_CHK_ID_BASE   (`IB_MCPL_DT_RAS_ID + vc_c0_dt)
       ) u_chkc0_dt (
         .clk                       (core_clk                     ),
         .rst_n                     (core_rst_n                   ),
         .din                       (s_client0_tlp_data_vc[vc_c0_dt].payload),
         .din_prot                  (s_client0_tlp_data_vc[vc_c0_dt].parity ),
         .dout                      (  /* Not connected */        ),
         .dout_prot                 (  /* Not connected */        ),
         .en                        (1'b1                         ),
         .bypass                    (1'b0                         ),
         .stall                     (1'b0                         ),
         .stallout                  (  /* Not connected */        ),
         .valid_in                  (client0_tlp_dv[vc_c0_dt]     ),
         .halt_out                  (  /* Not connected */        ),
         .valid_out                 (  /* Not connected */        ),
         .halt_in                   (1'b0                         ),
         .ras_dp_err_inband_kbd_in  (1'b0                         ),
         .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
         .ras_dp_err_log            (axi_ib_mcpl_dt_ras_dp_err_log)
           ,
           .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk)
         );

       assign s_par_ib_mcpl_dt_pulse_vc[vc_c0_dt] = axi_ib_mcpl_dt_ras_dp_err_log.valid;
    end

  assign axi_ras_par_ib_mcpl_dt_pulse = |s_par_ib_mcpl_dt_pulse_vc;

  endgenerate



  assign s_client0_hdr = client0_hdr;

  generate

    genvar vc_c0_hdr;
    for (vc_c0_hdr=0; vc_c0_hdr < NVC_XALI_EXP; vc_c0_hdr++) begin : PROC_g_vc_c0_hdr_par_chk

      assign s_client0_hdr_vc[vc_c0_hdr] = {
          s_client0_hdr.tlp_th[vc_c0_hdr],
          s_client0_hdr.tlp_st[vc_c0_hdr],
          s_client0_hdr.tlp_ph[vc_c0_hdr],
          s_client0_hdr.tlp_func_num[vc_c0_hdr],
          s_client0_hdr.tlp_attr[vc_c0_hdr],
          s_client0_hdr.tlp_ats[vc_c0_hdr],
          s_client0_hdr.tlp_nw[vc_c0_hdr],
          s_client0_hdr.addr_align_en[vc_c0_hdr],
          s_client0_hdr.tlp_byte_en[vc_c0_hdr],
          s_client0_hdr.cpl_cmpltr_id[vc_c0_hdr],
          s_client0_hdr.cpl_status[vc_c0_hdr],
          s_client0_hdr.cpl_bcm[vc_c0_hdr],
          s_client0_hdr.cpl_byte_cnt[vc_c0_hdr],
          s_client0_hdr.tlp_tid[vc_c0_hdr],
          s_client0_hdr.tlp_byte_len[vc_c0_hdr],
          s_client0_hdr.tlp_ep[vc_c0_hdr],
          s_client0_hdr.tlp_td[vc_c0_hdr],
          s_client0_hdr.tlp_tc[vc_c0_hdr],
          s_client0_hdr.tlp_type[vc_c0_hdr],
          s_client0_hdr.tlp_fmt[vc_c0_hdr],
          s_client0_hdr.tlp_addr[vc_c0_hdr]
      };

      bus_protect_gen
      
      #(
        .PROT_TYPE        (1), //Parity protection
        .PROT_RANGE       (CX_RAS_PROT_RANGE),
        .PROT_WD          (CLIENT_HDR_PROT_WD),
        .DATA_WD          (CLIENT_HDR_WD),
        .PARITY_MODE      (CX_RAS_PARITY_MODE),
        .FORCE_ERR_INJ_OFF(1)
        )
    u_c0p(
          .gen     (1'b1),       //Write mode generation enable
          .datain  (s_client0_hdr_vc[vc_c0_hdr]),

          //Error injection not actually implemented
          .core_clk(core_clk),
          .core_rst_n(core_rst_n),
          .error_inj_mask({CLIENT_HDR_PROT_WD+CLIENT_HDR_WD{1'b0}}),
          .error_inj_en(1'b0),
          .error_inj_data_valid(1'b0),
          .error_inj_eot(1'b0),
          .error_inj_done(),

          .dataout(),
          .chkout(s_client0_hdr_prot_vc[vc_c0_hdr])
          );
    end

    assign client0_hdr_prot = s_client0_hdr_prot_vc;

  endgenerate

  logic  slv_if_ras_uncorr_err_group;
  assign slv_if_ras_uncorr_err_group = |{sif_ras_par_rslv_dt_pulse
                                        ,slv_if_ras_err_sts
                                         };

   logic slv_if_ras_uncorr_err_sts_g;

   assign slv_if_ras_uncorr_err_sts_g = slv_if_ras_uncorr_err_group & !r_slv_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_wslv_uncorr
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(slv_if_ras_uncorr_err_sts_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_slv_if_uncorr_pulse)
        );


   assign sif_ras_par_slnull_ad_pulse_g = sif_ras_par_slnull_ad_pulse & !r_slv_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_slnull_ad
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_slnull_ad_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_slnull_ad_pulse)
        );

   assign sif_ras_par_slnull_dt_pulse_g = sif_ras_par_slnull_dt_pulse & !r_slv_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_slnull_dt
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_slnull_dt_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_slnull_dt_pulse)
        );

   assign ob_ras_par_npqdec_ad_pulse_g = ob_ras_par_npqdec_ad_pulse & !r_slv_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_npqdec_ad
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(ob_ras_par_npqdec_ad_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_npqdec_ad_pulse)
        );

   assign ob_ras_par_pqdec_ad_pulse_g = ob_ras_par_pqdec_ad_pulse & !r_slv_rasdp_err_mode;
   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_pqdec_ad
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(ob_ras_par_pqdec_ad_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_pqdec_ad_pulse)
        );


  assign s_client1_tlp_data_vc = client1_tlp_data;

  generate

    genvar vc_c1_dt;
    for (vc_c1_dt=0; vc_c1_dt < NVC_XALI_EXP; vc_c1_dt++) begin : PROC_g_vc_c1_dt_par_chk

     ras_dp_pipe
      #(
      .PIPELINE_TYPE             (0                            ),
      .RESETVAL                  (0                            ),
      .N_STAGES                  (0                            ),
      .CAN_STALL                 (0                            ),
      .RESET_STALL               (0                            ),
      .BUS_PROTECT_GEN_EN        (0                            ),
      .BUS_PROTECT_CHK_EN        (1                            ),
      .PROT_TYPE                 (1                            ), // parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
      .PROT_WD                   (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD),
      .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
      .PROT_CORRECT_EN           (0                            ),
      .TOTAL_WIDTH               (PCIE_CORE_DATA_BUS_WD        ),
      .EXCLUDE_PROT_WIDTH        (0                            ),
      .RAS_DP_PROT_CHK_ID_BASE   (`CLIENT1_DT_RAS_ID + vc_c1_dt)
    ) u_chkc1_dt (
      .clk                       (core_clk                     ),
      .rst_n                     (core_rst_n                   ),
      .din                       (s_client1_tlp_data_vc[vc_c1_dt].payload),
      .din_prot                  (s_client1_tlp_data_vc[vc_c1_dt].parity),
      .dout                      (  /* Not connected */        ),
      .dout_prot                 (  /* Not connected */        ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  (  /* Not connected */        ),
      .valid_in                  (client1_tlp_dv[vc_c1_dt]     ),
      .halt_out                  (  /* Not connected */        ),
      .valid_out                 (  /* Not connected */        ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
      .ras_dp_err_log            (axi_c1_dt_ras_dp_err_log     )
        ,
        .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk)
      );

    assign s_par_c1_dt_pulse_vc[vc_c1_dt] = axi_c1_dt_ras_dp_err_log.valid;
    end

  assign axi_ras_par_c1_dt_pulse = |s_par_c1_dt_pulse_vc;

  endgenerate

  assign s_client2_tlp_data_vc = client2_tlp_data;

  generate

    genvar vc_c2_dt;
    for (vc_c2_dt=0; vc_c2_dt < NVC_XALI_EXP; vc_c2_dt++) begin : PROC_g_vc_c2_dt_par_chk

     ras_dp_pipe
      #(
      .PIPELINE_TYPE             (0                            ),
      .RESETVAL                  (0                            ),
      .N_STAGES                  (0                            ),
      .CAN_STALL                 (0                            ),
      .RESET_STALL               (0                            ),
      .BUS_PROTECT_GEN_EN        (0                            ),
      .BUS_PROTECT_CHK_EN        (1                            ),
      .PROT_TYPE                 (1                            ), // parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
      .PROT_WD                   (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD),
      .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
      .PROT_CORRECT_EN           (0                            ),
      .TOTAL_WIDTH               (PCIE_CORE_DATA_BUS_WD        ),
      .EXCLUDE_PROT_WIDTH        (0                            ),
      .RAS_DP_PROT_CHK_ID_BASE   (`CLIENT2_DT_RAS_ID + vc_c2_dt)
    ) u_chkc2_dt (
      .clk                       (core_clk                     ),
      .rst_n                     (core_rst_n                   ),
      .din                       (s_client2_tlp_data_vc[vc_c2_dt].payload),
      .din_prot                  (s_client2_tlp_data_vc[vc_c2_dt].parity),
      .dout                      (  /* Not connected */        ),
      .dout_prot                 (  /* Not connected */        ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  (  /* Not connected */        ),
      .valid_in                  (client2_tlp_dv[vc_c2_dt]     ),
      .halt_out                  (  /* Not connected */        ),
      .valid_out                 (  /* Not connected */        ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
      .ras_dp_err_log            (axi_c2_dt_ras_dp_err_log     )
        ,
        .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk)
      );

    assign s_par_c2_dt_pulse_vc[vc_c2_dt] = axi_c2_dt_ras_dp_err_log.valid;
    end

  assign axi_ras_par_c2_dt_pulse = |s_par_c2_dt_pulse_vc;

  endgenerate

  assign s_client1_tlp_addr_payload_vc = client1_tlp_addr;
  assign s_client1_tlp_addr_parity_vc = client1_tlp_addr_par;

  generate

    genvar vc_c1_ad;
    for (vc_c1_ad=0; vc_c1_ad < NVC_XALI_EXP; vc_c1_ad++) begin : PROC_g_vc_c1_addr_par_chk

     ras_dp_pipe
      #(
      .PIPELINE_TYPE             (0                            ),
      .RESETVAL                  (0                            ),
      .N_STAGES                  (0                            ),
      .CAN_STALL                 (0                            ),
      .RESET_STALL               (0                            ),
      .BUS_PROTECT_GEN_EN        (0                            ),
      .BUS_PROTECT_CHK_EN        (1                            ),
      .PROT_TYPE                 (1                            ), // parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
      .PROT_WD                   (ADDR_PAR_WD                  ),
      .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
      .PROT_CORRECT_EN           (0                            ),
      .TOTAL_WIDTH               (64                           ),
      .EXCLUDE_PROT_WIDTH        (0                            ),
      .RAS_DP_PROT_CHK_ID_BASE   (`CLIENT1_AD_RAS_ID + vc_c1_ad)
    ) u_chkc1_ad (
      .clk                       (core_clk                     ),
      .rst_n                     (core_rst_n                   ),
      .din                       (s_client1_tlp_addr_payload_vc[vc_c1_ad]),
      .din_prot                  (s_client1_tlp_addr_parity_vc[vc_c1_ad]),
      .dout                      (  /* Not connected */        ),
      .dout_prot                 (  /* Not connected */        ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  (  /* Not connected */        ),
      .valid_in                  (client1_tlp_hv[vc_c1_ad]     ),
      .halt_out                  (  /* Not connected */        ),
      .valid_out                 (  /* Not connected */        ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
      .ras_dp_err_log            (axi_c1_ad_ras_dp_err_log     )
        ,
        .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk)
      );

    assign s_par_c1_ad_pulse_vc[vc_c1_ad] = axi_c1_ad_ras_dp_err_log.valid;
    end

    assign axi_ras_par_c1_ad_pulse = |s_par_c1_ad_pulse_vc;

  endgenerate

  assign s_client2_tlp_addr_payload_vc = client2_tlp_addr;
  assign s_client2_tlp_addr_parity_vc = client2_tlp_addr_par;

  generate

    genvar vc_c2_ad;
    for (vc_c2_ad=0; vc_c2_ad < NVC_XALI_EXP; vc_c2_ad++) begin : PROC_g_vc_c2_addr_par_chk

     ras_dp_pipe
      #(
      .PIPELINE_TYPE             (0                            ),
      .RESETVAL                  (0                            ),
      .N_STAGES                  (0                            ),
      .CAN_STALL                 (0                            ),
      .RESET_STALL               (0                            ),
      .BUS_PROTECT_GEN_EN        (0                            ),
      .BUS_PROTECT_CHK_EN        (1                            ),
      .PROT_TYPE                 (1                            ), // parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
      .PROT_WD                   (ADDR_PAR_WD                  ),
      .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
      .PROT_CORRECT_EN           (0                            ),
      .TOTAL_WIDTH               (64                           ),
      .EXCLUDE_PROT_WIDTH        (0                            ),
      .RAS_DP_PROT_CHK_ID_BASE   (`CLIENT2_AD_RAS_ID + vc_c2_ad)
    ) u_chkc2_ad (
      .clk                       (core_clk                     ),
      .rst_n                     (core_rst_n                   ),
      .din                       (s_client2_tlp_addr_payload_vc[vc_c2_ad]),
      .din_prot                  (s_client2_tlp_addr_parity_vc[vc_c2_ad]),
      .dout                      (  /* Not connected */        ),
      .dout_prot                 (  /* Not connected */        ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  (  /* Not connected */        ),
      .valid_in                  (client2_tlp_hv[vc_c2_ad]     ),
      .halt_out                  (  /* Not connected */        ),
      .valid_out                 (  /* Not connected */        ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out (  /* Not connected */        ),
      .ras_dp_err_log            (axi_c2_ad_ras_dp_err_log     )
        ,
        .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk)
      );

    assign s_par_c2_ad_pulse_vc[vc_c2_ad] = axi_c2_ad_ras_dp_err_log.valid;
    end

    assign axi_ras_par_c2_ad_pulse = |s_par_c2_ad_pulse_vc;

  endgenerate


  assign s_client1_hdr = client1_hdr;

  generate
     genvar vc_c1_hdr;
     for (vc_c1_hdr=0; vc_c1_hdr < NVC_XALI_EXP; vc_c1_hdr++) begin : PROC_g_vc_c1_hdr_par_chk

       assign s_client1_hdr_vc[vc_c1_hdr] = {
           s_client1_hdr.tlp_th[vc_c1_hdr],
           s_client1_hdr.tlp_st[vc_c1_hdr],
           s_client1_hdr.tlp_ph[vc_c1_hdr],
           s_client1_hdr.tlp_func_num[vc_c1_hdr],
           s_client1_hdr.tlp_attr[vc_c1_hdr],
           s_client1_hdr.tlp_ats[vc_c1_hdr],
           s_client1_hdr.tlp_nw[vc_c1_hdr],
           s_client1_hdr.addr_align_en[vc_c1_hdr],
           s_client1_hdr.tlp_byte_en[vc_c1_hdr],
           s_client1_hdr.cpl_cmpltr_id[vc_c1_hdr],
           s_client1_hdr.cpl_status[vc_c1_hdr],
           s_client1_hdr.cpl_bcm[vc_c1_hdr],
           s_client1_hdr.cpl_byte_cnt[vc_c1_hdr],
           s_client1_hdr.tlp_tid[vc_c1_hdr],
           s_client1_hdr.tlp_byte_len[vc_c1_hdr],
           s_client1_hdr.tlp_ep[vc_c1_hdr],
           s_client1_hdr.tlp_td[vc_c1_hdr],
           s_client1_hdr.tlp_tc[vc_c1_hdr],
           s_client1_hdr.tlp_type[vc_c1_hdr],
           s_client1_hdr.tlp_fmt[vc_c1_hdr],
           s_client1_hdr.tlp_addr[vc_c1_hdr]
       };

       bus_protect_gen
       
       #(
         .PROT_TYPE        (1), //Parity protection
         .PROT_RANGE       (CX_RAS_PROT_RANGE),
         .PROT_WD          (CLIENT_HDR_PROT_WD),
         .DATA_WD          (CLIENT_HDR_WD),
         .PARITY_MODE      (CX_RAS_PARITY_MODE),
         .FORCE_ERR_INJ_OFF(1)
         )
     u_c1p(
           .gen     (1'b1),       //Write mode generation enable
           .datain  (s_client1_hdr_vc[vc_c1_hdr]),

           //Error injection not actually implemented
           .core_clk(core_clk),
           .core_rst_n(core_rst_n),
           .error_inj_mask({CLIENT_HDR_PROT_WD+CLIENT_HDR_WD{1'b0}}),
           .error_inj_en(1'b0),
           .error_inj_data_valid(1'b0),
           .error_inj_eot(1'b0),
           .error_inj_done(),

           .dataout(),
           .chkout(s_client1_hdr_prot_vc[vc_c1_hdr])
           );
     end

     assign client1_hdr_prot = s_client1_hdr_prot_vc;

   endgenerate


assign s_client2_hdr = client2_hdr;

    generate
      genvar vc_c2_hdr;
      for (vc_c2_hdr=0; vc_c2_hdr < NVC_XALI_EXP; vc_c2_hdr++) begin : PROC_g_vc_c2_hdr_par_chk

        assign s_client2_hdr_vc[vc_c2_hdr] = {
            s_client2_hdr.tlp_th[vc_c2_hdr],
            s_client2_hdr.tlp_st[vc_c2_hdr],
            s_client2_hdr.tlp_ph[vc_c2_hdr],
            s_client2_hdr.tlp_func_num[vc_c2_hdr],
            s_client2_hdr.tlp_attr[vc_c2_hdr],
            s_client2_hdr.tlp_ats[vc_c2_hdr],
            s_client2_hdr.tlp_nw[vc_c2_hdr],
            s_client2_hdr.addr_align_en[vc_c2_hdr],
            s_client2_hdr.tlp_byte_en[vc_c2_hdr],
            s_client2_hdr.cpl_cmpltr_id[vc_c2_hdr],
            s_client2_hdr.cpl_status[vc_c2_hdr],
            s_client2_hdr.cpl_bcm[vc_c2_hdr],
            s_client2_hdr.cpl_byte_cnt[vc_c2_hdr],
            s_client2_hdr.tlp_tid[vc_c2_hdr],
            s_client2_hdr.tlp_byte_len[vc_c2_hdr],
            s_client2_hdr.tlp_ep[vc_c2_hdr],
            s_client2_hdr.tlp_td[vc_c2_hdr],
            s_client2_hdr.tlp_tc[vc_c2_hdr],
            s_client2_hdr.tlp_type[vc_c2_hdr],
            s_client2_hdr.tlp_fmt[vc_c2_hdr],
            s_client2_hdr.tlp_addr[vc_c2_hdr]
        };

        bus_protect_gen
        
        #(
          .PROT_TYPE        (1), //Parity protection
          .PROT_RANGE       (CX_RAS_PROT_RANGE),
          .PROT_WD          (CLIENT_HDR_PROT_WD),
          .DATA_WD          (CLIENT_HDR_WD),
          .PARITY_MODE      (CX_RAS_PARITY_MODE),
          .FORCE_ERR_INJ_OFF(1)
          )
      u_c2p(
            .gen     (1'b1),       //Write mode generation enable
            .datain  (s_client2_hdr_vc[vc_c2_hdr]),

            //Error injection not actually implemented
            .core_clk(core_clk),
            .core_rst_n(core_rst_n),
            .error_inj_mask({CLIENT_HDR_PROT_WD+CLIENT_HDR_WD{1'b0}}),
            .error_inj_en(1'b0),
            .error_inj_data_valid(1'b0),
            .error_inj_eot(1'b0),
            .error_inj_done(),

            .dataout(),
            .chkout(s_client2_hdr_prot_vc[vc_c2_hdr])
            );
      end

      assign client2_hdr_prot = s_client2_hdr_prot_vc;

    endgenerate


// mstr address in the case of messages
   bus_protect_gen
   
     #(
       .PROT_TYPE (1), //Parity
       .PROT_RANGE(CX_RAS_PROT_RANGE),
       .PROT_WD   (`CC_MSTR_BUS_ADDR_WIDTH - `MASTER_BUS_ADDR_WIDTH ),
       .DATA_WD   (`MASTER_BUS_ADDR_WIDTH),
       .PARITY_MODE(CX_RAS_PARITY_MODE),
       .FORCE_ERR_INJ_OFF(1)
       ) u_msg_addr_par
       (
        .gen     (1'b1),
        .datain  (msg_addr_int),

          //Error injection not actually implemented
        .core_clk(mstr_aclk),
        .core_rst_n(mstr_aresetn),
        .error_inj_mask({`CC_MSTR_BUS_ADDR_WIDTH{1'b0}}),
        .error_inj_en(1'b0),
        .error_inj_data_valid(1'b0),
        .error_inj_eot(1'b0),
        .error_inj_done(),

        .chkout  (msg_par),
        .dataout ()
        );
// slave addr replaced in the case of
logic [(`CC_SLV_BUS_ADDR_WIDTH - `SLAVE_BUS_ADDR_WIDTH)-1:0] msg_par_slv;
   bus_protect_gen
   
     #(
       .PROT_TYPE (1), //Parity
       .PROT_RANGE(CX_RAS_PROT_RANGE),
       .PROT_WD   (`CC_SLV_BUS_ADDR_WIDTH - `SLAVE_BUS_ADDR_WIDTH ),
       .DATA_WD   (`SLAVE_BUS_ADDR_WIDTH),
       .PARITY_MODE(CX_RAS_PARITY_MODE),
       .FORCE_ERR_INJ_OFF(1)
       ) u_msg_addr_par_slv
       (
        .gen     (1'b1),
        .datain  (msg_addr_slv_int),

          //Error injection not actually implemented
        .core_clk(slv_aclk),
        .core_rst_n(mstr_aresetn),
        .error_inj_mask({`CC_SLV_BUS_ADDR_WIDTH{1'b0}}),
        .error_inj_en(1'b0),
        .error_inj_data_valid(1'b0),
        .error_inj_eot(1'b0),
        .error_inj_done(),

        .chkout  (msg_par_slv),
        .dataout ()
        );

  DWC_pcie_bridge_par_encode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(`SLAVE_BUS_ADDR_WIDTH)
  ) u_sisb_aw_msg_encode (
    .data_in   (msg_addr_slv_int),
    .par_in    (msg_par_slv),
    .datap_out (msg_addr_w_par_slv)
  );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(SLV_NPW_SAB_RAM_ADDR_WD)
       ) u_ras_npw_sab_u
       (
        .clk_s      (slv_aclk   ),
        .rst_s_n    (slv_aresetn),
        .clk_d      (core_clk   ),
        .rst_d_n    (core_rst_n ),
        .err_pulse_s(sif_ras_recc_ucorr_cnt_npw_sab_pulse ),
        .ram_addr_s (sif_ras_recc_cnt_npw_sab_addr        ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_npw_sab_pulse ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_npw_sab_addr  )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(SLV_NPW_SAB_RAM_ADDR_WD)
       ) u_ras_npw_sab_c
       (
        .clk_s      (slv_aclk   ),
        .rst_s_n    (slv_aresetn),
        .clk_d      (core_clk   ),
        .rst_d_n    (core_rst_n ),
        .err_pulse_s(sif_ras_recc_corr_cnt_npw_sab_pulse),
        .ram_addr_s (sif_ras_recc_cnt_npw_sab_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_npw_sab_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_npw_sab_addr )
        );



   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_swwrap_dt
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_swwrap_dt_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_swwrap_dt_pulse)
        );

   assign sif_ras_par_swwrap_dt_pulse_g = sif_ras_par_swwrap_dt_pulse & !r_slv_rasdp_err_mode;

   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_swwrap_ad
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_swwrap_ad_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_swwrap_ad_pulse)
        );

   assign sif_ras_par_swwrap_ad_pulse_g = sif_ras_par_swwrap_ad_pulse & !r_slv_rasdp_err_mode;

   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_srwrap_ad
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_srwrap_ad_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_srwrap_ad_pulse)
        );

   assign sif_ras_par_srwrap_ad_pulse_g = sif_ras_par_srwrap_ad_pulse & !r_slv_rasdp_err_mode;



   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_swrq_npw_dt
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_swrq_npw_dt_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_swrq_npw_dt_pulse)
        );

   assign sif_ras_par_swrq_npw_dt_pulse_g = (sif_ras_par_swrq_npw_dt_pulse & !sif_ras_par_slnull_dt_pulse) & !r_slv_rasdp_err_mode;

   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_swrq_npw_ad
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(sif_ras_par_swrq_npw_ad_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_swrq_npw_ad_pulse)
        );

   assign sif_ras_par_swrq_npw_ad_pulse_g = sif_ras_par_swrq_npw_ad_pulse & !r_slv_rasdp_err_mode;


   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_npdcmp_dt
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(ob_ras_par_ob_np_dcmp_inq_dt_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_ob_np_dcmp_inq_dt_pulse)
        );

   assign ob_ras_par_ob_np_dcmp_inq_dt_pulse_g = ob_ras_par_ob_np_dcmp_inq_dt_pulse & !r_slv_rasdp_err_mode;


   DWC_pcie_ctl_bcm23
   
     #(
       .REG_ACK (0),
       .F_SYNC_TYPE (SYNC_TYPE),
       .R_SYNC_TYPE (SYNC_TYPE)
       ) u_pdcmp_dt
       (
        .clk_s  (slv_aclk   ),
        .rst_s_n(slv_aresetn),
        .init_s_n(1'b1),
        .event_s(ob_ras_par_ob_p_dcmp_inq_dt_pulse_g),
        .ack_s  (),
        .busy_s (),
        .clk_d  (core_clk),
        .rst_d_n(core_rst_n),
        .init_d_n(1'b1),
        .event_d(axi_ras_par_ob_p_dcmp_inq_dt_pulse)
        );

   assign ob_ras_par_ob_p_dcmp_inq_dt_pulse_g = ob_ras_par_ob_p_dcmp_inq_dt_pulse & !r_slv_rasdp_err_mode;






   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(OB_NPDCMP_RAM_ADDR_WD)
       ) u_ras_ob_npdcmp_u
       (
        .clk_s      (core_clk   ),
        .rst_s_n    (core_rst_n ),
        .clk_d      (core_clk   ),
        .rst_d_n    (core_rst_n ),
        .err_pulse_s(ob_ras_recc_ucorr_cnt_ob_npdcmp_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_npdcmp_addr        ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ob_npdcmp_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(OB_NPDCMP_RAM_ADDR_WD)
       ) u_ras_ob_npdcmp_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ob_ras_recc_corr_cnt_ob_npdcmp_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_npdcmp_addr       ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ob_npdcmp_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_ob_npdcmp_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(OB_PDCMP_HDR_RAM_ADDR_WD)
       ) u_ras_pdcmp_hdr_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ob_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_pdcmp_hdr_addr        ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(OB_PDCMP_HDR_RAM_ADDR_WD)
       ) u_ras_pdcmp_hdr_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ob_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_pdcmp_hdr_addr       ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(OB_PDCMP_DATA_RAM_ADDR_WD)
       ) u_ras_ob_pdcmp_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ob_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_pdcmp_data_addr        ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(OB_PDCMP_DATA_RAM_ADDR_WD)
       ) u_ras_ob_pdcmp_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ob_ras_recc_corr_cnt_ob_pdcmp_data_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_pdcmp_data_addr       ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_ob_pdcmp_data_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(CC_OB_CCMP_DATA_RAM_ADDR_WD)
       ) u_ras_ob_ccmp_data_u
       (
        .clk_s      (slv_aclk   ),
        .rst_s_n    (slv_aresetn),
        .clk_d      (core_clk   ),
        .rst_d_n    (core_rst_n ),
        .err_pulse_s(ob_ras_recc_ucorr_cnt_ob_ccmp_data_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_ccmp_data_addr        ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(CC_OB_CCMP_DATA_RAM_ADDR_WD)
       ) u_ras_ob_ccmp_data_c
       (
        .clk_s      (slv_aclk   ),
        .rst_s_n    (slv_aresetn),
        .clk_d      (core_clk   ),
        .rst_d_n    (core_rst_n ),
        .err_pulse_s(ob_ras_recc_corr_cnt_ob_ccmp_data_pulse ),
        .ram_addr_s (ob_ras_recc_cnt_ob_ccmp_data_addr       ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ob_ccmp_data_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_ob_ccmp_data_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD)
       ) u_ras_ib_sch_p_hdr_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_p_hdr_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse  ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD)
       ) u_ras_ib_sch_p_hdr_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_corr_cnt_ib_sch_p_hdr_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_p_hdr_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse  ),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD)
       ) u_ras_ib_sch_p_data_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_ucorr_cnt_ib_sch_p_data_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_p_data_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse  ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD)
       ) u_ras_ib_sch_p_data_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_corr_cnt_ib_sch_p_data_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_p_data_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_sch_p_data_pulse  ),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_sch_p_data_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD)
       ) u_ras_ib_sch_np_hdr_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_np_hdr_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse  ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD)
       ) u_ras_ib_sch_np_hdr_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_corr_cnt_ib_sch_np_hdr_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_np_hdr_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse  ),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD)
       ) u_ras_ib_sch_np_data_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_ucorr_cnt_ib_sch_np_data_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_np_data_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse  ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD)
       ) u_ras_ib_sch_np_data_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_corr_cnt_ib_sch_np_data_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_sch_np_data_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_sch_np_data_pulse  ),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_sch_np_data_addr   )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(CC_IB_RD_REQ_CDC_RAM_ADDR_WD)
       ) u_ras_ib_rreq_c2a_u
       (
        .clk_s      (mstr_aclk   ),
        .rst_s_n    (mstr_aresetn),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse  ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr   )
        );


   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(CC_IB_RD_REQ_CDC_RAM_ADDR_WD)
       ) u_ras_ib_rreq_c2a_c
       (
        .clk_s      (mstr_aclk   ),
        .rst_s_n    (mstr_aresetn),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse  ),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr   )
        );


   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(CC_IB_WR_REQ_CDC_RAM_ADDR_WD)
       ) u_ras_ib_wreq_c2a_u
       (
        .clk_s      (mstr_aclk   ),
        .rst_s_n    (mstr_aresetn),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr      ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse ),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr  )
        );


   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(1),
       .DATA_WD(CC_IB_WR_REQ_CDC_RAM_ADDR_WD)
       ) u_ras_ib_wreq_c2a_c
       (
        .clk_s      (mstr_aclk   ),
        .rst_s_n    (mstr_aresetn),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(ibreq_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse),
        .ram_addr_s (ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse ),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr  )
        );


   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_MCPL_CDC_RAM_ADDR_WD)
       ) u_ras_ib_mcpl_a2c_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse),
        .ram_addr_s (mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr )
        );



   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_MCPL_CDC_RAM_ADDR_WD)
       ) u_ras_ib_mcpl_a2c_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse),
        .ram_addr_s (mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr       ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr )
        );





   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD)
       ) u_ras_ib_mcpl_sb_u
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse),
        .ram_addr_s (mcb_ras_recc_cnt_ib_mcpl_sb_addr       ),
        .err_pulse_d(axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse),
        .ram_addr_d (axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr )
        );

   DWC_pcie_bridge_ras2cdm_cdc
   
     #(
       .CLKDIFF(0),
       .DATA_WD(CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD)
       ) u_ras_ib_mcpl_sb_c
       (
        .clk_s      (core_clk  ),
        .rst_s_n    (core_rst_n),
        .clk_d      (core_clk  ),
        .rst_d_n    (core_rst_n),
        .err_pulse_s(mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse),
        .ram_addr_s (mcb_ras_recc_cnt_ib_mcpl_sb_addr      ),
        .err_pulse_d(axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse),
        .ram_addr_d (axi_ras_recc_corr_cnt_ib_mcpl_sb_addr )
        );
   DWC_pcie_ctl_bcm21
   
     #(
       .WIDTH(1),
       .F_SYNC_TYPE (SYNC_TYPE)
       ) u_c2am_rem
       (
        .clk_d   (mstr_aclk_ug),  // in ungated clock to propagate RAS mode when master is idle
        .rst_d_n (mstr_aresetn),
        .data_s  (r_cfg_rasdp_err_mode),
        .data_d  (cdc_mstr_rasdp_err_mode)
        );

   DWC_pcie_bridge_rasdp_mode
   
     #(
       .EVENTB_WD(1
                  + 2
                  + 1
                 )
       ) u_mrmode
       (
        .clk(mstr_aclk_ug), // in ungated clock to propagate RAS mode when master is idle
        .aresetn(mstr_aresetn),

        .cfg_rasdp_err_mode_en(cfg_rasdp_err_mode_en_d1),
        .i_rasdp_mode(cdc_mstr_rasdp_err_mode),
        .eventb(
                {
                 mstr_if_ras_uncorr_err_group
                ,ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse
                ,ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse
                ,mcb_ras_par_ib_mcpl_a2c_dt_pulse
                 }
                ),

        .o_rasdp_mode(mr_mstr_rasdp_err_mode)
        );
   assign s_mstr_rasdp_err_mode = (|{mr_mstr_rasdp_err_mode
                                    ,mstr_if_ras_uncorr_err_group
                                    }) & cfg_rasdp_err_mode_en_d1;
   always @ (posedge mstr_aclk_ug or negedge mstr_aresetn) begin : PROC_seq_mstr_rasdp
      if (!mstr_aresetn)
        r_mstr_rasdp_err_mode <= #TP 1'b0;
      else
        r_mstr_rasdp_err_mode <= #TP s_mstr_rasdp_err_mode;
   end
   assign mstr_rasdp_err_mode = r_mstr_rasdp_err_mode;







   DWC_pcie_ctl_bcm21
   
     #(
       .WIDTH(1),
       .F_SYNC_TYPE (SYNC_TYPE)
       ) u_c2as_rem
       (
        .clk_d   (slv_aclk_ug), // in ungated clock to propagate RAS mode when Slave is idle
        .rst_d_n (slv_aresetn),
        .data_s  (r_cfg_rasdp_err_mode),
        .data_d  (cdc_slv_rasdp_err_mode)
        );

   DWC_pcie_bridge_rasdp_mode
   
     #(
       .EVENTB_WD(9
                  +1
                  +3
                  )
       ) u_srmode
       (
        .clk(slv_aclk_ug), // in ungated clock to propagate RAS mode when Slave is idle
        .aresetn(slv_aresetn),

        .cfg_rasdp_err_mode_en(cfg_rasdp_err_mode_en_d),
        .i_rasdp_mode(cdc_slv_rasdp_err_mode),
        .eventb(
                {
                 slv_if_ras_uncorr_err_group,
                 sif_ras_par_slnull_ad_pulse,
                 sif_ras_par_slnull_dt_pulse,
                 ob_ras_par_npqdec_ad_pulse,
                 ob_ras_par_pqdec_ad_pulse,
                 sif_ras_recc_ucorr_cnt_npw_sab_pulse,
                 sif_ras_par_swwrap_dt_pulse,
                 sif_ras_par_swwrap_ad_pulse,
                 sif_ras_par_srwrap_ad_pulse,
                 ob_ras_par_ob_np_dcmp_inq_dt_pulse,
                 ob_ras_par_ob_p_dcmp_inq_dt_pulse,
                 sif_ras_par_swrq_npw_dt_pulse,
                 sif_ras_par_swrq_npw_ad_pulse
                 }
                ),

        .o_rasdp_mode(sr_slv_rasdp_err_mode)
        );
   assign s_slv_rasdp_err_mode = (sr_slv_rasdp_err_mode
                                  | slv_if_ras_uncorr_err_group
                                  ) & cfg_rasdp_err_mode_en_d;
   always @ (posedge slv_aclk_ug or negedge slv_aresetn) begin : PROC_seq_slv_rasdp
      if (!slv_aresetn)
        r_slv_rasdp_err_mode <= #TP 1'b0;
      else
        r_slv_rasdp_err_mode <= #TP s_slv_rasdp_err_mode;
   end
   assign slv_rasdp_err_mode = r_slv_rasdp_err_mode;






   // ---------------------------------------------------------------------------
   // Functions
   // ---------------------------------------------------------------------------
   function automatic [ADDR_PAR_WD-1:0] swap_addr_par_only;
      input [63 + ADDR_PAR_WD:0]   in_addr;
      integer                      i,j;
      reg [63 + ADDR_PAR_WD:0]     i_swap_addr_par;
      begin
         i_swap_addr_par = {63 + ADDR_PAR_WD{1'b0}};
         for (i=0; i<ADDR_PAR_WD; i=i+1) begin
            for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
               i_swap_addr_par[i*CX_RAS_PROT_RANGE +j] = in_addr[i*CX_RAS_PROT_RANGE +j +i];
            end
            i_swap_addr_par[64 + i] = in_addr[(i+1)*CX_RAS_PROT_RANGE +i];
         end
         swap_addr_par_only = i_swap_addr_par[63 + ADDR_PAR_WD:64];
      end
   endfunction

   // Mask data acording to valid strobes
   function automatic [SLV_BUS_DATA_WIDTH-1:0] fn_mask_data;
      input [SLV_BUS_DATA_WIDTH-1:0] in_data;
      input [SLV_BUS_WSTRB_WIDTH-1:0] in_strb;

      integer i,j;
      reg [SLV_BUS_DATA_WIDTH-1:0] out_data;

      begin
         for (i=0; i<SLV_BUS_WSTRB_WIDTH; i=i+1) begin
            out_data[i*9] = in_strb[i] ? in_data[i*9] : PARITY_BIT;
            for (j=1; j<9; j=j+1) begin
               out_data[i*9+j] = in_strb[i] & in_data[i*9+j];
            end
         end
         fn_mask_data = out_data;
      end
   endfunction

endmodule // DWC_pcie_bridge_rasdp_inc
