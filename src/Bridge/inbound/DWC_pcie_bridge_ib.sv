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
// ---    $Revision: #27 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib.sv#27 $
// ---------------------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Bridge/inbound/DWC_pcie_bridge_atop_pkg.svh"

`include "Axi/svif/DWC_pcie_axi_mstr_ar_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_aw_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_w_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_r_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_b_if.svh"

`include "DWC_pcie_ctl_pkg.svh"
 module DWC_pcie_bridge_ib

  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    // -------------------------------------------------------------------------------------
    // Master
    parameter MAX_MSTR_TAGS          = `CC_MAX_MSTR_TAGS,
    parameter MAX_MSTR_TAG_PW        = `CC_MAX_MSTR_TAG_PW,
    parameter MSTR_BE_CTRL_WD        = `CC_MSTR_BE_CTRL_WIDTH,
    parameter MSTR_MTU_PW            = `CC_MSTR_MTU_PW,
    parameter MSTR_DATA_WD           = `CC_MSTR_BUS_DATA_WIDTH,
    parameter MSTR_DATAP_WD          = `CC_MSTR_BUS_DATAP_WIDTH,
    parameter MSTR_ADDR_WD           = `CC_MSTR_BUS_ADDR_WIDTH,
    parameter MSTR_ADDR_WD_NP        = `MASTER_BUS_ADDR_WIDTH,
    parameter MSTR_BUS_ADDRP_WIDTH   = `CC_MSTR_BUS_ADDRP_WIDTH,
    parameter MSTR_LOCK_WD           = `CC_AXI_LOCK_WIDTH,
    parameter MSTR_WSTRB_WD          = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter MSTR_ID_WD             = `CC_MSTR_BUS_ID_WIDTH_NP,
    parameter MSTR_BURST_LEN_PW      = `CC_MSTR_BURST_LEN_PW,
    parameter MSTR_MISC_INFO_PW      = `MSTR_MISC_INFO_PW,
    parameter MSTR_RESP_MISC_INFO_PW = `MSTR_RESP_MISC_INFO_PW,
    parameter MSTR_MISC_INFO_WD      = `MSTR_MISC_INFO_WD,
    parameter MSTR_RESP_MISC_INFO_WD = `MSTR_RESP_MISC_INFO_WD,
    parameter CORE_DATA_BUS_WD       = `CC_CORE_DATA_BUS_WD,
    parameter CORE_DATA_BUS_WSTRB_WD = `CC_CORE_DATA_BUS_WSTRB_WD,
    parameter MSTR_DATA_WD_GT_CORE_DATA_WD = MSTR_DATA_WD > CORE_DATA_BUS_WD,
    parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 = `CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2,

    parameter MSTR_RSP_BYTE_WD                = `CC_MSTR_RSP_BYTE_WD,
    parameter MSTR_RSP_DATA_WD                = `CC_MSTR_RSP_DATA_WD,
    parameter MSTR_BUS_WSTRB_WIDTH            = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter MSTR_NW                         = `CC_MSTR_NW,
    parameter MASTER_BUS_DATA_SIZE_ENC        = `CC_MASTER_BUS_DATA_SIZE_ENC,
    parameter CX_REMOTE_MAX_TAG               = `CX_REMOTE_MAX_TAG,
    parameter CX_REMOTE_MAX_TAGS              = `CX_REMOTE_MAX_TAGS,

    parameter MSTR_MAX_SPLIT_PACK_PW          = `CC_MSTR_MAX_SPLIT_PACK_PW,

    // Generic Master
    parameter AXI_AWPROT_0              = `GMX_AXI_AWPROT_0,
    parameter AXI_AWPROT_1              = `GMX_AXI_AWPROT_1,
    parameter AXI_AWPROT_2              = `GMX_AXI_AWPROT_2,
    parameter AXI_ARPROT_0              = `GMX_AXI_ARPROT_0,
    parameter AXI_ARPROT_1              = `GMX_AXI_ARPROT_1,
    parameter AXI_ARPROT_2              = `GMX_AXI_ARPROT_2,

    parameter CC_WR_CH_NP_RSP_QUEUE_DP      = `CC_WR_CH_NP_RSP_QUEUE_DP,
    parameter CC_WR_CH_NP_RSP_QUEUE_DP_LOG2 = `CC_WR_CH_NP_RSP_QUEUE_DP_LOG2,

    //---------------------
    parameter PF_WD                     = `CX_NFUNC_WD,
    parameter VF_WD                     = `CX_NVFUNC_WD,

    parameter TPH_ST_WD                 = 8,
    parameter TPH_PH_WD                 = 2,
    parameter TPH_TH_WD                 = 1,
    parameter MISC_INFO_TPH_WD          = TPH_ST_WD + TPH_PH_WD + TPH_TH_WD,


    //----------------------

    parameter DC_INBD_HEADER_PNP_1STG_WD         = `DC_INBD_HEADER_PNP_1STG_WD,
    parameter DC_INBD_HEADER_PNP_1STG_WD_NP      = `DC_INBD_HEADER_PNP_1STG_WD_NP,
    parameter DC_INBD_HEADER_PNP_WD              = `DC_INBD_HEADER_PNP_WD,
    parameter DC_INBD_MISCINFO_WD                = `DC_INBD_MISCINFO_WD,
    parameter CORE_REQ_DATA_BUS_WD               = MSTR_DATA_WD_GT_CORE_DATA_WD ? MSTR_DATA_WD : CORE_DATA_BUS_WD,
    parameter CX_RAS_RAM_PROT_RANGE              = `CX_RAS_RAM_PROT_RANGE,
    parameter CC_MRF_C2A_FIFO_SYNC_REGS          = 2, // double registered CDC
    parameter CC_MRF_A2C_FIFO_SYNC_REGS          = 2, // double registered CDC
    parameter CC_MRF_C2A_FIFO_HOLD_RD_ADDR       = 1, //If the full flag is used the push interface will clobber the held read data.
    parameter CC_MSTR_NUM_CONV_WD                = `CC_MSTR_NUM_CONV_WD,
    parameter CX_NW                              = `CX_NW,
    parameter CC_AMBA_TLP_SEQ_WD                 = `CC_AMBA_TLP_SEQ_WD    ,
    parameter CX_NFUNC                           = `CX_NFUNC               ,
    parameter RADMX_TRGT1_REQ_HDR_WD             = `CC_RADMX_TRGT1_REQ_HDR_WD ,
    parameter CX_NFUNC_WD                        = `CX_NFUNC_WD            ,
    parameter REMOTE_MAX_RD_SIZE_PW              = `CX_REMOTE_RD_REQ_SIZE_PW  ,
    parameter CX_REMOTE_MAX_TAGS_WD              = `CX_REMOTE_MAX_TAGS_WD,


    parameter DC_DMA_TYPE_WIDTH                  = `DC_DMA_TYPE_WIDTH,
    parameter CC_NUM_DMA_RD_CHAN                 = `CC_NUM_DMA_RD_CHAN,
    parameter CC_NUM_DMA_WR_CHAN                 = `CC_NUM_DMA_WR_CHAN,
    parameter CC_NUM_DMA_RD_CHAN_WIDTH           = `CC_NUM_DMA_RD_CHAN_WIDTH,
    parameter CC_NUM_DMA_WR_CHAN_WIDTH           = `CC_NUM_DMA_WR_CHAN_WIDTH,
    parameter CC_NUM_DMA_MAX_CHAN_WIDTH          = `CC_NUM_DMA_MAX_CHAN_WIDTH,
    parameter CORE_REQ_DATA_BUS_WSTRB_WD         = MSTR_DATA_WD_GT_CORE_DATA_WD ? MSTR_BUS_WSTRB_WIDTH : CORE_DATA_BUS_WSTRB_WD,
    parameter REQ_NW                             = MSTR_DATA_WD_GT_CORE_DATA_WD ? MSTR_NW : CX_NW,
    parameter CX_NVC_LOG2                        = `CX_NVC_LOG2,

    parameter RX_TLP_PREFIX_WD          = `FLT_Q_PRFX_WIDTH,
    parameter NW_PRFX                   = `CX_NPRFX,
    parameter PRFX_PAR_WD               = `CX_PRFX_PAR_WD,
    parameter TX_TLP_PREFIX_WD          = (32*NW_PRFX)+ PRFX_PAR_WD,
    parameter ADDR_PAR_WD               = `CX_ADDR_PAR_WD,


    parameter CX_TAG_SIZE               = `CX_TAG_SIZE,
    parameter CX_REMOTE_LOOKUPID_WD     = `CX_REMOTE_LOOKUPID_WD,
    parameter P_N_PRESP_STREAMS         = 1,
    parameter P_N_PRESP_STREAMS_WD      = 1,
    parameter P_N_PRESP_STREAMS_W_RO_WD = 1,
    parameter P_NP_PASS_P_WD     = 1 + `CX_NVC - 1 ,
    parameter type P_CFG_IB_P_ID_MNG_CTRL_TYPE = logic,

    // -------------------------------------------------------------------------------------
    // Master completion buffer
    parameter MSTR_CPL_DATA_SEG_DP            = `CC_MSTR_CPL_DATA_SEG_DP,
    parameter MSTR_CPL_SEG_DATA_WD            = `CC_MSTR_CPL_SEG_DATA_WD,
    parameter MSTR_CPL_SEG_DATA_WD_NP         = `CC_MSTR_CPL_SEG_DATA_WD_NP,
    parameter MSTR_CPL_SEG_DATA_NUM_DWORDS    = `CC_MSTR_CPL_SEG_DATA_NUM_DWORDS,
    parameter MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 = `CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2,
    parameter MSTR_CPL_SEG_DATA_NUM_BYTES     = `CC_MSTR_CPL_SEG_DATA_NUM_BYTES,
    parameter MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2  = `CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2,
    parameter MSTR_CPL_SEG_DATA_SIZE_ENC      = `CC_MSTR_CPL_SEG_DATA_SIZE_ENC,
    parameter MSTR_CPL_DATA_WD                = `CC_MSTR_CPL_DATA_WD,
    parameter PCIE_CORE_NUM_BYTES             = `CC_PCIE_CORE_NUM_BYTES,
    parameter MSTR_RSP_INTF_WD                = `CC_MSTR_RSP_INTF_WD,
    parameter MSTR_RSP_INTF_WD_NP             = `CC_MSTR_RSP_INTF_WD_NP,


    // -------------------------------------------------------------------------------------
    // External RAMs
    // Master read/write request CDC FIFO RAMs
    parameter CC_IB_RD_REQ_CDC_RAM_DP            = `CC_IB_RD_REQ_CDC_RAM_DP,
    parameter CC_IB_WR_REQ_CDC_RAM_DP            = `CC_IB_WR_REQ_CDC_RAM_DP,
    parameter CC_IB_RD_REQ_CDC_RAM_ADDR_WD       = `CC_IB_RD_REQ_CDC_RAM_ADDR_WD,
    parameter CC_IB_RD_REQ_CDC_RAM_ADDRP_WD      = `CC_IB_RD_REQ_CDC_RAM_ADDRP_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_ADDR_WD       = `CC_IB_WR_REQ_CDC_RAM_ADDR_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_ADDRP_WD      = `CC_IB_WR_REQ_CDC_RAM_ADDRP_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_DATA_WD       = `CC_IB_WR_REQ_CDC_RAM_DATA_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC = `CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC,
    parameter CC_IB_RD_REQ_CDC_RAM_DATA_WD       = `CC_IB_RD_REQ_CDC_RAM_DATA_WD,
    parameter CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC = `CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC,
    // Master request Order FIFO RAM
    parameter CC_IB_RD_REQ_ORDR_RAM_ADDR_WD      = `CC_IB_RD_REQ_ORDR_RAM_ADDR_WD,
    parameter CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD     = `CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD,
    parameter CC_IB_RD_REQ_ORDR_RAM_DATA_WD      = `CC_IB_RD_REQ_ORDR_RAM_DATA_WD,
    // Master Completion Buffer
    parameter CC_IB_MCPL_SEG_BUF_RAM_DATA_WD     = `CC_IB_MCPL_SEG_BUF_RAM_DATA_WD,
    parameter CC_IB_MCPL_SEG_BUF_RAM_DP          = `CC_IB_MCPL_SEG_BUF_RAM_DP,
    parameter CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD     = `CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD,
    parameter CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD    = `CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD,
    parameter CC_IB_MCPL_CDC_RAM_ADDR_WD         = `CC_IB_MCPL_CDC_RAM_ADDR_WD,
    parameter CC_IB_MCPL_CDC_RAM_ADDRP_WD        = `CC_IB_MCPL_CDC_RAM_ADDRP_WD,
    parameter CC_IB_MCPL_CDC_RAM_DATA_WD         = `CC_IB_MCPL_CDC_RAM_DATA_WD,
    parameter CC_IB_MCPL_CDC_RAM_RD_LATENCY      = `CC_IB_MCPL_CDC_RAM_RD_LATENCY,
    parameter CC_IB_MCPL_CDC_RAM_DP              = `CC_IB_MCPL_CDC_RAM_DP,
    parameter CC_MSTR_CPL_C2A_FIFO_DEPTH         = `CC_MSTR_CPL_C2A_FIFO_DEPTH,
    parameter CC_MSTR_CPL_C2A_FIFO_WD            = `CC_MSTR_CPL_C2A_FIFO_WD,
    parameter CC_MSTR_CPL_QUEUE_DP               = `CC_MSTR_CPL_QUEUE_DP,
    parameter CC_MSTR_CPL_QUEUE_DP_LOG2          = `CC_MSTR_CPL_QUEUE_DP_LOG2,
    //-----------------

    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------

    parameter TP       = 0.1

    )
   
                          (
    input                                                  mstr_aclk, // Bridge Master Interface Clock
    input                                                  mstr_arstn, // Bridge Master Clock Reset

    input                                                  core_clk,
    input                                                  core_rstn,

    // -------------------------------------------------------------------------------------
    // Flush interface
    // -------------------------------------------------------------------------------------
    input                                                  rstctl_mstr_flush_req,


    // -------------------------------------------------------------------------------------
    // Configuration interface
    // -------------------------------------------------------------------------------------

    input [(3*CX_NFUNC)-1:0]                               cfg_max_payload_size,

    input [3:0]                                            cfg_mstr_arcache_mode,
    input [3:0]                                            cfg_mstr_awcache_mode,
    input [3:0]                                            cfg_mstr_arcache_value,
    input [3:0]                                            cfg_mstr_awcache_value,
    input [1:0]                                            cfg_mstr_ardomain_mode,
    input [1:0]                                            cfg_mstr_awdomain_mode,
    input [1:0]                                            cfg_mstr_ardomain_value,
    input [1:0]                                            cfg_mstr_awdomain_value,

    input                                                  cfg_ax_mstr_zeroread_fw,

    input [31:0]                                           cfg_aximstr_msg_addr_high_d1,
    input [31:0]                                           cfg_aximstr_msg_addr_low_d1,

    input P_CFG_IB_P_ID_MNG_CTRL_TYPE                      cfg_ib_p_id_mng_ctrl,

    input [MSTR_ADDR_WD_NP-1:0]                            msg_addr,
    input [ (MSTR_ADDR_WD - MSTR_ADDR_WD_NP) -1:0]         msg_addrp,

    // -------------------------------------------------------------------------------------
    // RAS
    // -------------------------------------------------------------------------------------

    input                                                  cfg_rdq_mrf_ras_recc_correct,
    output                                                 rdq_mrf_ras_recc_corr_cnt_pulse,
    output                                                 rdq_mrf_ras_recc_ucorr_cnt_pulse,
    output [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]              rdq_mrf_ras_recc_cnt_addr,

    output ras_dp_err_log_t                                wrq_mrf_recc_cnt_ras_dp_err_log,
    output ras_dp_err_log_t                                rdq_mrf_recc_cnt_ras_dp_err_log,
    input  ras_dp_err_inj_t                                axi_bridge_ras_dp_err_inj_core_clk,
    input  ras_dp_err_inj_t                                core_clk_hp_mstr_ras_dp_err_inj,
    input  ras_dp_err_inj_t                                ras_dp_err_inj_mstr_aclk,
    input                                                  cfg_wrq_mrf_ras_recc_correct,
    output                                                 wrq_mrf_ras_recc_corr_cnt_pulse,
    output                                                 wrq_mrf_ras_recc_ucorr_cnt_pulse,
    output [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]              wrq_mrf_ras_recc_cnt_addr,
    input                                                  cfg_ras_recc_ib_mcpl_a2c_cdc_correct,
    output wire                                            mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse,
    output wire                                            mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse,
    output wire [CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]           mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr,
    output                                                 mcb_ras_par_ib_mcpl_a2c_dt_pulse,

    output ras_dp_err_log_t                                mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log,
    output ras_dp_err_log_t                                mcb_ib_mcpl_a2c_dt_ras_dp_err_log,
    input                                                  cfg_ras_recc_ib_mcpl_sb_correct,
    output wire                                            mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse,
    output wire                                            mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse,
    output wire [CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]       mcb_ras_recc_cnt_ib_mcpl_sb_addr,
    output wire                                            mcb_ras_par_ib_mcpl_sb_dt_pulse,
    output ras_dp_err_log_t                                axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log,
    output ras_dp_err_log_t                                mcb_ib_mcpl_sb_dt_ras_dp_err_log,

    output wire                                            axi_ras_par_ibr_rmstr_ad_pulse,
    output wire                                            axi_ras_par_ibr_wmstr_ad_pulse,
    output wire                                            axi_ras_par_ibr_wmstr_dt_pulse,
    output ras_dp_err_log_t                                axi_ibr_rmstr_ad_ras_dp_err_log,
    output ras_dp_err_log_t                                axi_ibr_wmstr_ad_ras_dp_err_log,
    output ras_dp_err_log_t                                axi_ibr_wmstr_dt_ras_dp_err_log,




    input [DC_INBD_HEADER_PNP_1STG_WD-1:0]                 inbd_header_pnp_wr,
    input [63:0]                                           radm_trgt1_hdr_uppr_bytes,
    input [CORE_DATA_BUS_WD-1:0]                           inbd_data_pnp_wr,
    output wire                                            inbd_halt_pnp_wr,

    input [DC_INBD_HEADER_PNP_1STG_WD-1:0]                 inbd_header_pnp_rd,
    output wire                                            inbd_halt_pnp_rd,

    //2pRAM interface
    output wire [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]         ib_rreq_c2a_cdc_ram_addra,
    output wire [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]         ib_rreq_c2a_cdc_ram_addrb,
    output wire                                            ib_rreq_c2a_cdc_ram_wea,
    output wire                                            ib_rreq_c2a_cdc_ram_enb,
    input [CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]               ib_rreq_c2a_cdc_ram_doutb,
    output wire [CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]         ib_rreq_c2a_cdc_ram_dina,

    output wire [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]         ib_wreq_c2a_cdc_ram_addra,
    output wire [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]         ib_wreq_c2a_cdc_ram_addrb,
    output wire                                            ib_wreq_c2a_cdc_ram_wea,
    output wire                                            ib_wreq_c2a_cdc_ram_enb,
    input [CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]               ib_wreq_c2a_cdc_ram_doutb,
    output wire [CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]         ib_wreq_c2a_cdc_ram_dina,

    // Master completion buffer segment buffer RAM outputs
    output [CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]            ib_mcpl_sb_ram_addra,
    output                                                 ib_mcpl_sb_ram_wea,
    output [CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]            ib_mcpl_sb_ram_dina,
    output [CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]            ib_mcpl_sb_ram_addrb,
    output                                                 ib_mcpl_sb_ram_enb,
    input [CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]             ib_mcpl_sb_ram_doutb,
    // Master completion buffer AMBA to PCIe core clock domain crossing FIFO RAM outputs
    output [CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]                ib_mcpl_a2c_cdc_ram_addra,
    output                                                 ib_mcpl_a2c_cdc_ram_wea,
    output [CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]                ib_mcpl_a2c_cdc_ram_dina,
    output [CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]                ib_mcpl_a2c_cdc_ram_addrb,
    output                                                 ib_mcpl_a2c_cdc_ram_enb,
    input [CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]                 ib_mcpl_a2c_cdc_ram_doutb,

    output                                                 axi_ras_par_ibrd_dcmp_ad_pulse_g,
    output                                                 axi_ras_par_ibwr_dcmp_ad_pulse_g,
    output                                                 axi_ras_par_ibwr_dcmp_dt_pulse_g,
    output ras_dp_err_log_t                                axi_ibrd_dcmp_ad_ras_dp_err_log_g,
    output ras_dp_err_log_t                                axi_ibwr_dcmp_ad_ras_dp_err_log_g,
    output ras_dp_err_log_t                                axi_trgt1_dt_ras_dp_err_log_g,
    output                                                 axi_ras_par_ibrd_mrf_ad_pulse_g,
    output                                                 axi_ras_par_ibwq_mrf_ad_pulse_g,
    output                                                 axi_ras_par_ibwq_mrf_dt_pulse_g,
    output ras_dp_err_log_t                                axi_mstr_req_rd_ad_ras_dp_err_log_g,
    output ras_dp_err_log_t                                axi_mstr_req_wr_ad_ras_dp_err_log_g,
    output ras_dp_err_log_t                                axi_mstr_req_dt_ras_dp_err_log_g,

    // -------------------------------------------------------------------------------------
    // DMA RD Engine LL back-pressure signal
    // -------------------------------------------------------------------------------------
    input [CC_NUM_DMA_RD_CHAN-1:0]                         dma_mcb_rdll_halt,
    input [CC_NUM_DMA_WR_CHAN-1:0]                         dma_mcb_wrll_halt,

    // -------------------------------------------------------------------------------------
    // Client interface
    // -------------------------------------------------------------------------------------
    output wire                                            ibc0_tlp_hv,
    output wire [`DC_FMT_WD-1:0]                           ibc0_tlp_fmt,
    output wire [`DC_TYPE_WD-1:0]                          ibc0_tlp_type,
    output wire [CX_NFUNC_WD-1:0]                          ibc0_tlp_func_num,
    output wire [`DC_CPL_STATUS_WD-1:0]                    ibc0_cpl_status,
    output wire                                            ibc0_tlp_ep,
    output wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]         ibc0_tlp_byte_len,
    output wire [CX_REMOTE_LOOKUPID_WD-1:0]                ibc0_cpl_lookup_id,
    output [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                 ibc0_tlp_dma_channel,
    output [DC_DMA_TYPE_WIDTH-1:0]                         ibc0_tlp_dma,
    output                                                 ibc0_tlp_prv_dma,
    output [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                 ibc0_tlp_prv_dma_chan,
    output wire                                            ibc0_tlp_dv,
    output wire [MSTR_CPL_DATA_WD-1:0]                     ibc0_tlp_data,
    output wire                                            ibc0_tlp_eot,
    output wire                                            ibc0_tlp_bad_eot,
    output wire                                            ibc0_cpl_last,
    output wire                                            ibc0_addr_align_en,
    output wire                                            ibc0_cpl_bcm,
    output wire                                            ibc0_tlp_td,
    output wire [`FLT_Q_ATTR_WIDTH-1:0]                    ibc0_tlp_attr,
    output wire [`DC_CPL_BYTE_CNT_WD-1:0]                  ibc0_cpl_byte_cnt,
    output wire [`DC_CPL_AT_WD-1:0]                        ibc0_tlp_ats,
    output wire                                            ibc0_tlp_atu_bypass,
    output wire [`DC_TC_WD-1:0]                            ibc0_tlp_tc,

    output wire [CX_TAG_SIZE-1:0]                          ibc0_tlp_tid,
    output wire [(`DC_CPL_ADDR_WD+ADDR_PAR_WD)-1:0]        ibc0_tlp_addr,
    output wire [`DC_CPL_BYTE_EN_WD-1:0]                   ibc0_tlp_byte_en,
    output wire [`DC_CPL_CMPLTR_ID_WD-1:0]                 ibc0_cpl_cmpltr_id,
    input                                                  xadm_ibc0_halt,

    output wire                                            ibreq_presp_cmplt,
    output wire [CC_AMBA_TLP_SEQ_WD-1:0]                   ibreq_presp_rpseq,
    output wire [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]             ibreq_presp_dma_chan_num,
    output wire                                            ibreq_presp_dma_err,
    output wire [1:0]                                      ibreq_presp_type,
    output wire [P_N_PRESP_STREAMS-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] ibreq_cfg_rpseq,

    //---------------------------------
    // AXI Master
    //---------------------------------

    DWC_pcie_axi_mstr_ar_if.mstr_mp                        mstr_ar,
    DWC_pcie_axi_mstr_aw_if.mstr_mp                        mstr_aw,
    DWC_pcie_axi_mstr_w_if.mstr_mp                         mstr_w,
    DWC_pcie_axi_mstr_r_if.mstr_mp                         mstr_r,
    DWC_pcie_axi_mstr_b_if.mstr_mp                         mstr_b,


  // AXI low power
  input                                              csysreq, // Request
  output wire                                        csysack, // Acknowledge
  output wire                                        cactive // Active

    );

   /////////////////////////////////////////////////////////
  // Internal Wires
   /////////////////////////////////////////////////////////

   // -------------------------------------------------------------------------------------
   // Inbound decomposer PCIe NP request info interface
   // -------------------------------------------------------------------------------------
   wire                                                               reqmcb_hdr_np_valid;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]                                   reqmcb_hdr_lookupid;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]                                   reqmcb_hdr_mstrid;
   wire                                                               reqmcb_hdr_last;
   wire                                                               reqmcb_hdr_ncbe;
   wire [DC_DMA_TYPE_WIDTH-1:0]                                       reqmcb_hdr_dma_type;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                               reqmcb_hdr_dma_chan;
   wire [REMOTE_MAX_RD_SIZE_PW -1:0]                                  reqmcb_hdr_dw_len_bytes;
   wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]                            reqmcb_hdr_low_addr;
   wire [PF_WD-1:0]                                                   reqmcb_hdr_func;

   wire                                                               ibmrf_reqmcb_np_valid;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]                                   ibmrf_reqmcb_mstrid;
   wire                                                               ibmrf_reqmcb_last;

   logic                                                              ibmrf_reqmcb_atomic;


   // GENERIC Master INTERFACE
   wire                                                               wrq_svalid;
   wire                                                               wrq_slast;
   wire [(MSTR_DATA_WD)-1:0]                                          wrq_sdata;
   wire [(MSTR_RESP_MISC_INFO_WD)-1:0]                                wrq_smisc_info;
   wire [DC_INBD_MISCINFO_WD-1:0]                                     wrq_mmisc_info;
   wire                                                               wrq_mmem_type;
   wire [2:0]                                                         wrq_sresp;
   wire [(MSTR_ADDR_WD)-1:0]                                          wrq_maddr;
   wire                                                               wrq_mwrite;
   wire [MSTR_MTU_PW -1:0]                                            wrq_mlen;
   wire [(MSTR_DATA_WD)-1:0]                                          wrq_mdata;
   wire [(MSTR_WSTRB_WD)-1:0]                                         wrq_mbe;
   wire [MSTR_BE_CTRL_WD-1:0]                                         wrq_mbe_ctrl;
   wire [MSTR_ID_WD-2:0]                                              wrq_mid;
   wire                                                               wrq_mabort;
   wire                                                               wrq_last;
   wire                                                               wrq_saccept;

   wire                                                               rdq_svalid;
   wire                                                               rdq_slast;
   wire [(MSTR_DATA_WD)-1:0]                                          rdq_sdata;
   wire [(MSTR_RESP_MISC_INFO_WD)-1:0]                                rdq_smisc_info;
   wire [DC_INBD_MISCINFO_WD-1:0]                                     rdq_mmisc_info;
   wire                                                               rdq_mread;
   wire [(MSTR_ADDR_WD)-1:0]                                          rdq_maddr;
   wire [MSTR_MTU_PW -1:0]                                            rdq_mlen;
   wire [(MSTR_DATA_WD)-1:0]                                          rdq_mdata;
   wire [(MSTR_WSTRB_WD)-1:0]                                         rdq_mbe;
   wire [MSTR_BE_CTRL_WD-1:0]                                         rdq_mbe_ctrl;
   wire [MSTR_ID_WD-2:0]                                              rdq_mid;
   wire                                                               rdq_mabort;
   wire                                                               rdq_last;
   wire                                                               rdq_saccept;


   // -------------------------------------------------------------------------------------
   // Posted Response bus
   // -------------------------------------------------------------------------------------
   wire [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                                axigm_presp_dma_chan_num ;
   wire                                                               axigm_presp_dma_err      ;
   wire                                                               ibreq_presp_cdc_halt     ;
   wire                                                               ibreq_presp_cfg_cdc_halt ;
   wire                                                               ibreq_presp_cfg_cdc_alm_halt ;


   // -------------------------------------------------------------------------------------
   // Master completion buffer interfaces
   // -------------------------------------------------------------------------------------
   wire                                                               mstr_svalid;
   wire [MSTR_DATA_WD-1:0]                                            mstr_sdata;
   wire                                                               mstr_slast;
   wire [MSTR_ID_WD -2:0]                                             mstr_sid;
   wire [MSTR_WSTRB_WD -1:0]                                          mstr_sbyte_en;
   wire [2:0]                                                         mstr_sresp;
   wire [`DC_CPL_STATUS_WD-1:0]                                       mstr_smisc_info_cpl_stat;
   wire [MSTR_RESP_MISC_INFO_WD-1:0]                                  mstr_smisc_info;

   wire                                                               mcb_ready;

   wire [`DC_SRESP_WD-1:0]                                            s_sresp;
   wire [`DC_CPL_STATUS_WD-1:0]                                       s_smisc_info_cpl_stat;
   wire                                                               s_sresp_wr_not_rd;
   wire                                                               s_sresp_np_not_p;
   wire                                                               s_smisc_info_ep;
   wire [`DC_TC_WD-1:0]                                               s_smisc_info_tc;
   wire                                                               s_smisc_info_bad_eot;

   wire [`DC_FMT_WD-1:0]                                              mcb_fmt;
   wire [`DC_TYPE_WD-1:0]                                             mcb_type;
   wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]                            mcb_dw_len_bytes;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]                                   mcb_ireq_np_lookup_id;
   wire                                                               mcb_ep;
   wire [CX_NFUNC_WD-1:0]                                             mcb_func;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                               mcb_dma_chan;
   wire [DC_DMA_TYPE_WIDTH-1:0]                                       mcb_dma_type;
   wire                                                               mcb_prv_dma;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                               mcb_prv_dma_chan;
   wire [`DC_CPL_STATUS_WD-1:0]                                       mcb_status;
   wire [MSTR_CPL_DATA_WD-1:0]                                        mcb_data;
   wire                                                               mcb_bad_eot;

   wire                                                               mcb_last;
   wire                                                               mcb_addr_align_en;
   wire                                                               mcb_bcm;
   wire                                                               mcb_td;
   wire [`FLT_Q_ATTR_WIDTH-1:0]                                       mcb_attr;
   wire [`DC_CPL_BYTE_CNT_WD-1:0]                                     mcb_byte_cnt;
   wire [`DC_CPL_AT_WD-1:0]                                           mcb_ats;
   wire [`DC_TC_WD-1:0]                                               mcb_tc;

   wire [CX_TAG_SIZE-1:0]                                             mcb_tid;
   wire [(`DC_CPL_ADDR_WD+ADDR_PAR_WD)-1:0]                           mcb_addr;
   wire [`DC_CPL_BYTE_EN_WD-1:0]                                      mcb_byte_en;
   wire [`DC_CPL_CMPLTR_ID_WD-1:0]                                    mcb_cmpltr_id;

//   logic [MSTR_ID_WD-1:0]                                             s_arid;
  // logic [MSTR_ID_WD-1:0]                                             s_awid;
//`ifndef CC_AXI4_ENABLE
  // logic [MSTR_ID_WD-1:0]                                             s_wid;
//`endif // CC_AXI4_ENABLE

   wire                                                               axigm_presp_cmplt;
   wire [CC_AMBA_TLP_SEQ_WD-1:0]                                      axigm_presp_rpseq;
   wire [1:0]                                                         axigm_presp_type;
   wire [P_N_PRESP_STREAMS_WD-1:0]                                    axigm_presp_stream;

   wire                                                               axigm_presp_cfg_cmplt;
   wire [CC_AMBA_TLP_SEQ_WD-1:0]                                      axigm_presp_cfg_rpseq;
   wire                                                               axigm_presp_cfg_type;
   wire [P_N_PRESP_STREAMS_WD-1:0]                                    axigm_presp_cfg_stream;

  typedef struct packed {
    logic    [`CC_MSTR_BUS_ID_WIDTH_NP -1:0] id;
    logic [`CX_IB_P_ID_MNG_EXTRA_ID_WD -1:0] id_extra;
  } ibidExtra_s;

  ibidExtra_s s_bidExtra
             ,s_ridExtra;

  // Resize NP-sized ID bus to P-sized ID bus
  // NP transactions padded with 0's
  // P transactions concatenate id with id_extra
  function automatic logic [`CC_MSTR_BUS_ID_WIDTH-1:0] f_idExtraBits_toIntf(
    input ibidExtra_s i_idExtra
  );
    f_idExtraBits_toIntf = i_idExtra.id[`CC_MSTR_BUS_ID_WIDTH_NP-1]
                           ? {1'b1, {`CX_IB_P_ID_MNG_EXTRA_ID_WD{1'b0}}, i_idExtra.id[MSTR_ID_WD-2:0]}
                           : {1'b0,                  i_idExtra.id_extra, i_idExtra.id[MSTR_ID_WD-2:0]};
  endfunction

  // Inverse operation of f_idExtraBits_toIntf
  function automatic ibidExtra_s f_idExtraBits_fromIntf(
    input logic [`CC_MSTR_BUS_ID_WIDTH-1:0] i_intf_id
  );
    f_idExtraBits_fromIntf = '{id      : {i_intf_id[`CC_MSTR_BUS_ID_WIDTH-1], i_intf_id[`CC_MSTR_BUS_ID_WIDTH_NP-2:0]}
                              ,id_extra:  i_intf_id[`CC_MSTR_BUS_ID_WIDTH-2:`CC_MSTR_BUS_ID_WIDTH_NP-1]};
  endfunction

   // AXI Write Request
   wire                                                   awvalid;                      assign mstr_aw.valid                     = awvalid;
   wire [MSTR_ID_WD-1:0]                                  awid;
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0]                 awid_extra;
   assign mstr_aw.id = f_idExtraBits_toIntf('{id:awid, id_extra:awid_extra});
   wire [MSTR_ADDR_WD-1:0]                                awaddr;                       assign mstr_aw.addr                      = awaddr;
   wire [MSTR_BURST_LEN_PW -1:0]                          awlen;                        assign mstr_aw.len                       = awlen;
   wire [2:0]                                             awsize;                       assign mstr_aw.size                      = awsize;
   wire [1:0]                                             awburst;                      assign mstr_aw.burst                     = awburst;
   wire [MSTR_LOCK_WD-1:0]                                awlock;                       assign mstr_aw.lock                      = awlock;
   wire [3:0]                                             awcache;                      assign mstr_aw.cache                     = awcache;
   wire [2:0]                                             awprot;                       assign mstr_aw.prot                      = awprot;
   wire [CX_TAG_SIZE+39:0]                                awmisc_info;                  assign mstr_aw.misc_info                 = awmisc_info;
   wire [63:0]                                            awmisc_info_hdr_34dw;         assign mstr_aw.misc_info_hdr_34dw        = awmisc_info_hdr_34dw;
   wire                                                   awmisc_info_last_dcmp_tlp;    assign mstr_aw.misc_info_last_dcmp_tlp   = awmisc_info_last_dcmp_tlp;
   wire                                                   awmisc_info_nw;               assign mstr_aw.misc_info_nw              = awmisc_info_nw;
   wire                                                   awmisc_info_cxlsrc;           assign mstr_aw.misc_info_cxlsrc          = awmisc_info_cxlsrc;
   wire [1:0]                                             awmisc_info_ats;              assign mstr_aw.misc_info_ats             = awmisc_info_ats;
   wire                                                   awmisc_info_ep;               assign mstr_aw.misc_info_ep              = awmisc_info_ep;
   wire [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0]  awmisc_info_dma;              assign mstr_aw.misc_info_dma             = awmisc_info_dma;
   wire [RX_TLP_PREFIX_WD-1:0]                            awmisc_info_tlpprfx;          assign mstr_aw.misc_info_tlpprfx         = awmisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]                            awmisc_info_tph;              assign mstr_aw.misc_info_tph             = awmisc_info_tph;
   wire                                                   awmisc_info_ido;              assign mstr_aw.misc_info_ido             = awmisc_info_ido;
   wire [8:0]                                             awmisc_info_dst_segment;      assign mstr_aw.misc_info_dst_segment     = awmisc_info_dst_segment;
   wire [8:0]                                             awmisc_info_req_segment;      assign mstr_aw.misc_info_req_segment     = awmisc_info_req_segment;
   wire [3:0]                                             awqos;                        assign mstr_aw.qos                       = awqos;
   wire [1:0]                                             awdomain;                     assign mstr_aw.domain                    = awdomain;
   wire [1:0]                                             awbar;                        assign mstr_aw.bar                       = awbar;
   wire [`CC_AXIJ_DMWR_VALUE *2+2:0]                      awsnoop;                      assign mstr_aw.snoop                     = awsnoop;
   wire [5:0]                                             awatop;                       assign mstr_aw.atop                      = awatop;
   wire                                                   awready;                      assign awready                           = mstr_aw.ready;
   // AXI Write Data
   wire                                                   wvalid;                       assign mstr_w.valid                      = wvalid;
   wire                                                   wlast;                        assign mstr_w.last                       = wlast;
   wire [MSTR_DATA_WD-1:0]                                wdata;                        assign mstr_w.data                       = wdata;
   wire [MSTR_WSTRB_WD-1:0]                               wstrb;                        assign mstr_w.strb                       = wstrb;
   wire                                                   wready;                       assign wready                            = mstr_w.ready;
    // AXI Write Response
   wire                                                   bvalid;                       assign bvalid                            = mstr_b.valid;
   wire [MSTR_ID_WD-1:0]                                  bid;
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0]                 bid_extra;
   assign s_bidExtra = f_idExtraBits_fromIntf(mstr_b.id);
   assign bid        = s_bidExtra.id;
   assign bid_extra  = s_bidExtra.id_extra;
   wire [1:0]                                             bresp;                        assign bresp                             = mstr_b.resp;
   wire [`DC_CPL_STATUS_WD-1:0]                           bmisc_info_cpl_stat;          assign bmisc_info_cpl_stat               = mstr_b.misc_info_cpl_stat;
   wire                                                   bready;                       assign mstr_b.ready                      = bready;
   // AXI Read Request
   wire                                                   arvalid;                      assign mstr_ar.valid                     = arvalid;
   wire [MSTR_ID_WD-1:0]                                  arid;
   assign mstr_ar.id = f_idExtraBits_toIntf('{id:arid, id_extra:0});
   wire [MSTR_ADDR_WD-1:0]                                araddr;                       assign mstr_ar.addr                      = araddr;
   wire [MSTR_BURST_LEN_PW -1:0]                          arlen;                        assign mstr_ar.len                       = arlen;
   wire [2:0]                                             arsize;                       assign mstr_ar.size                      = arsize;
   wire [1:0]                                             arburst;                      assign mstr_ar.burst                     = arburst;
   wire [MSTR_LOCK_WD-1:0]                                arlock;                       assign mstr_ar.lock                      = arlock;
   wire [3:0]                                             arcache;                      assign mstr_ar.cache                     = arcache;
   wire [2:0]                                             arprot;                       assign mstr_ar.prot                      = arprot;
   wire [CX_TAG_SIZE+39:0]                                armisc_info;                  assign mstr_ar.misc_info                 = armisc_info;
   wire                                                   armisc_info_last_dcmp_tlp;    assign mstr_ar.misc_info_last_dcmp_tlp   = armisc_info_last_dcmp_tlp;
   wire                                                   armisc_info_nw;               assign mstr_ar.misc_info_nw              = armisc_info_nw;
   wire                                                   armisc_info_cxlsrc;           assign mstr_ar.misc_info_cxlsrc          = armisc_info_cxlsrc;
   wire [1:0]                                             armisc_info_ats;              assign mstr_ar.misc_info_ats             = armisc_info_ats;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] armisc_info_dma;              assign mstr_ar.misc_info_dma             = armisc_info_dma;
   wire [RX_TLP_PREFIX_WD-1:0]                            armisc_info_tlpprfx;          assign mstr_ar.misc_info_tlpprfx         = armisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]                            armisc_info_tph;              assign mstr_ar.misc_info_tph             = armisc_info_tph;
   wire                                                   armisc_info_ido;              assign mstr_ar.misc_info_ido             = armisc_info_ido;
   wire [8:0]                                             armisc_info_dst_segment;      assign mstr_ar.misc_info_dst_segment     = armisc_info_dst_segment;
   wire [8:0]                                             armisc_info_req_segment;      assign mstr_ar.misc_info_req_segment     = armisc_info_req_segment;
   wire                                                   armisc_info_zeroread;         assign mstr_ar.misc_info_zeroread        = armisc_info_zeroread;
   wire [3:0]                                             arqos;                        assign mstr_ar.qos                       = arqos;
   wire [1:0]                                             ardomain;                     assign mstr_ar.domain                    = ardomain;
   wire [1:0]                                             arbar;                        assign mstr_ar.bar                       = arbar;
   wire [3:0]                                             arsnoop;                      assign mstr_ar.snoop                     = arsnoop;
   wire                                                   arready;                      assign arready                           = mstr_ar.ready;
   // AXI read response & read data
   wire                                                   rvalid;                       assign rvalid                            = mstr_r.valid;
   wire [MSTR_ID_WD-1:0]                                  rid;
  assign s_ridExtra = f_idExtraBits_fromIntf(mstr_r.id);
  assign rid        = s_ridExtra.id;
   wire                                                   rlast;                        assign rlast                             = mstr_r.last;
   wire [MSTR_DATA_WD-1:0]                                rdata;                        assign rdata                             = mstr_r.data;
   wire [MSTR_RESP_MISC_INFO_PW-1:0]                      rmisc_info;                   assign rmisc_info                        = mstr_r.misc_info;
   wire [1:0]                                             rresp;                        assign rresp                             = mstr_r.resp;
   wire [`DC_CPL_STATUS_WD-1:0]                           rmisc_info_cpl_stat;          assign rmisc_info_cpl_stat               = mstr_r.misc_info_cpl_stat;
   wire                                                   rready;                       assign mstr_r.ready                      = rready;

   /////////////////////////////////////////////////////////
   // Design starts here
   // ---------------------------------------------------------------------------
   // Instantiate Inbound Requesting
   // ---------------------------------------------------------------------------
   DWC_pcie_bridge_ibreq
   
     #(
       .DC_INBD_HEADER_PNP_1STG_WD         (DC_INBD_HEADER_PNP_1STG_WD         ),
       .DC_INBD_HEADER_PNP_1STG_WD_NP      (DC_INBD_HEADER_PNP_1STG_WD_NP      ),
       .DC_INBD_HEADER_PNP_WD              (DC_INBD_HEADER_PNP_WD              ),
       .DC_INBD_MISCINFO_WD                (DC_INBD_MISCINFO_WD                ),
       .CX_RAS_RAM_PROT_RANGE              (CX_RAS_RAM_PROT_RANGE              ),
       .CC_IB_RD_REQ_CDC_RAM_DP            (CC_IB_RD_REQ_CDC_RAM_DP            ),
       .CC_IB_WR_REQ_CDC_RAM_DP            (CC_IB_WR_REQ_CDC_RAM_DP            ),
       .CC_IB_RD_REQ_CDC_RAM_ADDR_WD       (CC_IB_RD_REQ_CDC_RAM_ADDR_WD       ),
       .CC_IB_WR_REQ_CDC_RAM_ADDR_WD       (CC_IB_WR_REQ_CDC_RAM_ADDR_WD       ),
       .CC_MRF_C2A_FIFO_SYNC_REGS          (CC_MRF_C2A_FIFO_SYNC_REGS          ),
       .CC_MRF_A2C_FIFO_SYNC_REGS          (CC_MRF_A2C_FIFO_SYNC_REGS          ),
       .CC_MRF_C2A_FIFO_HOLD_RD_ADDR       (CC_MRF_C2A_FIFO_HOLD_RD_ADDR       ),
       .CC_IB_WR_REQ_CDC_RAM_DATA_WD       (CC_IB_WR_REQ_CDC_RAM_DATA_WD       ),
       .CC_IB_RD_REQ_CDC_RAM_DATA_WD       (CC_IB_RD_REQ_CDC_RAM_DATA_WD       ),
       .CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC (CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC ),
       .CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC (CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC ),
       .DC_DMA_TYPE_WIDTH                  (DC_DMA_TYPE_WIDTH                  ),
       .CC_NUM_DMA_RD_CHAN_WIDTH           (CC_NUM_DMA_RD_CHAN_WIDTH           ),
       .CC_NUM_DMA_MAX_CHAN_WIDTH          (CC_NUM_DMA_MAX_CHAN_WIDTH          ),
       .MSTR_DATA_WD_GT_CORE_DATA_WD       (MSTR_DATA_WD_GT_CORE_DATA_WD       ),
       .CC_MSTR_BUS_DATA_WIDTH             (MSTR_DATA_WD                       ),
       .CC_MSTR_BUS_WSTRB_WIDTH            (MSTR_WSTRB_WD                      ),
       .CC_MSTR_BUS_ADDR_WIDTH             (MSTR_ADDR_WD                       ),
       .CC_MAX_MSTR_TAG_PW                 (MSTR_ID_WD-1                         ),
       .CC_MSTR_BE_CTRL_WIDTH              (MSTR_BE_CTRL_WD                    ),
       .CC_MSTR_NW                         (MSTR_NW                            ),
       .CC_MSTR_NUM_CONV_WD                (CC_MSTR_NUM_CONV_WD                ),
       .CX_NW                              (CX_NW                              ),
       .CC_MSTR_MTU_PW                     (MSTR_MTU_PW                        ),
       .CC_AMBA_TLP_SEQ_WD                 (CC_AMBA_TLP_SEQ_WD                 ),
       .CX_NFUNC                           (CX_NFUNC                           ),
       .RADMX_TRGT1_REQ_HDR_WD             (RADMX_TRGT1_REQ_HDR_WD             ),
       .CC_CORE_DATA_BUS_WD                (CORE_DATA_BUS_WD                   ),
       .CX_NFUNC_WD                        (CX_NFUNC_WD                        ),
       .CX_REMOTE_MAX_TAGS_WD              (MAX_MSTR_TAG_PW                    ),
       .REMOTE_MAX_RD_SIZE_PW              (REMOTE_MAX_RD_SIZE_PW              )
      ,.P_N_PRESP_STREAMS                  (P_N_PRESP_STREAMS                  )
      ,.P_N_PRESP_STREAMS_WD               (P_N_PRESP_STREAMS_WD               )
       )
   u_ibreq
     (
       .core_clk                         (core_clk      )
      ,.core_rstn                        (core_rstn     )
      ,.mstr_aclk                        (mstr_aclk     )
      ,.mstr_arstn                       (mstr_arstn    )
      ,.trgt1_addr_parerr                ({
                                           axi_ras_par_ibrd_dcmp_ad_pulse_g,
                                           axi_ras_par_ibwr_dcmp_ad_pulse_g
                                           })
      ,.trgt1_data_parerr                (axi_ras_par_ibwr_dcmp_dt_pulse_g)
      ,.trgt1_dt_ras_dp_err_log          (axi_trgt1_dt_ras_dp_err_log_g)
      ,.trgt1_ad_ras_dp_err_log          ({
                                           axi_ibrd_dcmp_ad_ras_dp_err_log_g,
                                           axi_ibwr_dcmp_ad_ras_dp_err_log_g
                                           })
      ,.cfg_rdq_mrf_ras_recc_correct     (cfg_rdq_mrf_ras_recc_correct    )
      ,.rdq_mrf_ras_recc_corr_cnt_pulse  (rdq_mrf_ras_recc_corr_cnt_pulse )
      ,.rdq_mrf_ras_recc_ucorr_cnt_pulse (rdq_mrf_ras_recc_ucorr_cnt_pulse)
      ,.rdq_mrf_ras_recc_cnt_addr        (rdq_mrf_ras_recc_cnt_addr       )
      ,.cfg_wrq_mrf_ras_recc_correct     (cfg_wrq_mrf_ras_recc_correct    )
      ,.wrq_mrf_ras_recc_corr_cnt_pulse  (wrq_mrf_ras_recc_corr_cnt_pulse )
      ,.wrq_mrf_ras_recc_ucorr_cnt_pulse (wrq_mrf_ras_recc_ucorr_cnt_pulse)
      ,.wrq_mrf_ras_recc_cnt_addr        (wrq_mrf_ras_recc_cnt_addr       )
      ,.mstr_req_addr_parerr             ({
                                           axi_ras_par_ibrd_mrf_ad_pulse_g,
                                           axi_ras_par_ibwq_mrf_ad_pulse_g
                                           })
      ,.mstr_req_data_parerr             (axi_ras_par_ibwq_mrf_dt_pulse_g)
      ,.wrq_mrf_recc_cnt_ras_dp_err_log (wrq_mrf_recc_cnt_ras_dp_err_log)
      ,.rdq_mrf_recc_cnt_ras_dp_err_log (rdq_mrf_recc_cnt_ras_dp_err_log)
      ,.mstr_req_ad_ras_dp_err_log       ({
                                          axi_mstr_req_rd_ad_ras_dp_err_log_g,
                                          axi_mstr_req_wr_ad_ras_dp_err_log_g
                                           })
      ,.mstr_req_dt_ras_dp_err_log       (axi_mstr_req_dt_ras_dp_err_log_g )
        ,.axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk)
        ,.ras_dp_err_inj_mstr_aclk (ras_dp_err_inj_mstr_aclk)
        ,.core_clk_hp_mstr_ras_dp_err_inj  (core_clk_hp_mstr_ras_dp_err_inj)
      ,.inbd_header_pnp_wr               (inbd_header_pnp_wr)
      ,.radm_trgt1_hdr_uppr_bytes        (radm_trgt1_hdr_uppr_bytes)
      ,.inbd_data_pnp_wr                 (inbd_data_pnp_wr  )
      ,.inbd_halt_pnp_wr                 (inbd_halt_pnp_wr  )
      ,.inbd_header_pnp_rd               (inbd_header_pnp_rd)
      ,.inbd_halt_pnp_rd                 (inbd_halt_pnp_rd  )
      // -------------------------------------------------------------------------
      // Inbound read request queue Core to Amba clock CDC RAM
      ,.ib_rreq_c2a_cdc_ram_addra (ib_rreq_c2a_cdc_ram_addra )
      ,.ib_rreq_c2a_cdc_ram_addrb (ib_rreq_c2a_cdc_ram_addrb )
      ,.ib_rreq_c2a_cdc_ram_wea   (ib_rreq_c2a_cdc_ram_wea   )
      ,.ib_rreq_c2a_cdc_ram_enb   (ib_rreq_c2a_cdc_ram_enb   )
      ,.ib_rreq_c2a_cdc_ram_doutb (ib_rreq_c2a_cdc_ram_doutb )
      ,.ib_rreq_c2a_cdc_ram_dina  (ib_rreq_c2a_cdc_ram_dina  )
      // -------------------------------------------------------------------------
      // Inbound write request queue Core to Amba clock CDC RAM
      ,.ib_wreq_c2a_cdc_ram_addra (ib_wreq_c2a_cdc_ram_addra )
      ,.ib_wreq_c2a_cdc_ram_addrb (ib_wreq_c2a_cdc_ram_addrb )
      ,.ib_wreq_c2a_cdc_ram_wea   (ib_wreq_c2a_cdc_ram_wea   )
      ,.ib_wreq_c2a_cdc_ram_enb   (ib_wreq_c2a_cdc_ram_enb   )
      ,.ib_wreq_c2a_cdc_ram_doutb (ib_wreq_c2a_cdc_ram_doutb )
      ,.ib_wreq_c2a_cdc_ram_dina  (ib_wreq_c2a_cdc_ram_dina  )
      // -------------------------------------------------------------------------
      // Master Completion Buffer, request interface
      ,.reqmcb_hdr_np_valid      (reqmcb_hdr_np_valid     )
      ,.reqmcb_hdr_ncbe          (reqmcb_hdr_ncbe         )
      ,.reqmcb_hdr_low_addr      (reqmcb_hdr_low_addr     )
      ,.reqmcb_hdr_dw_len_bytes  (reqmcb_hdr_dw_len_bytes )
      ,.reqmcb_hdr_lookupid      (reqmcb_hdr_lookupid     )
      ,.reqmcb_hdr_func          (reqmcb_hdr_func         )
      ,.reqmcb_hdr_dma_type      (reqmcb_hdr_dma_type     )
      ,.reqmcb_hdr_dma_chan      (reqmcb_hdr_dma_chan     )
      ,.reqmcb_hdr_mstrid        (reqmcb_hdr_mstrid       )
      ,.reqmcb_hdr_last          (reqmcb_hdr_last         )
      ,.ibmrf_reqmcb_np_valid    (ibmrf_reqmcb_np_valid   )
      ,.ibmrf_reqmcb_mstrid      (ibmrf_reqmcb_mstrid     )
      ,.ibmrf_reqmcb_last        (ibmrf_reqmcb_last       )
      ,.ibmrf_reqmcb_atomic      (ibmrf_reqmcb_atomic     )
      ,.wrq_maddr                (wrq_maddr               )
      ,.wrq_mwrite               (wrq_mwrite              )
      ,.wrq_mwrite_last          (                        ) // Not used
      ,.wrq_mbe                  (wrq_mbe                 )
      ,.wrq_mlen                 (wrq_mlen                )
      ,.wrq_mdata                (wrq_mdata               )
      ,.wrq_mbe_ctrl             (wrq_mbe_ctrl            )
      ,.wrq_mid                  (wrq_mid                 )
      ,.wrq_mabort               (wrq_mabort              )
      ,.wrq_mlast                (wrq_last                )
      ,.wrq_mmisc                (wrq_mmisc_info          )
      ,.wrq_saccept              (wrq_saccept             )
      ,.rdq_maddr                (rdq_maddr               )
      ,.rdq_mread                (rdq_mread               )
      ,.rdq_mlen                 (rdq_mlen                )
      ,.rdq_mdata                (rdq_mdata               )
      ,.rdq_mbe                  (rdq_mbe                 )
      ,.rdq_mbe_ctrl             (rdq_mbe_ctrl            )
      ,.rdq_mid                  (rdq_mid                 )
      ,.rdq_mabort               (rdq_mabort              )
      ,.rdq_mlast                (rdq_last                )
      ,.rdq_mmisc                (rdq_mmisc_info          )
      ,.rdq_saccept              (rdq_saccept             )
      ,.axigm_presp_cmplt        (axigm_presp_cmplt       )
      ,.axigm_presp_rpseq        (axigm_presp_rpseq       )
      ,.axigm_presp_type         (axigm_presp_type        )
      ,.axigm_presp_stream       (axigm_presp_stream      )
      ,.axigm_presp_dma_chan_num (axigm_presp_dma_chan_num)
      ,.axigm_presp_dma_err      (axigm_presp_dma_err     )
      ,.axigm_presp_cfg_cmplt    (axigm_presp_cfg_cmplt   )
      ,.axigm_presp_cfg_rpseq    (axigm_presp_cfg_rpseq   )
      ,.axigm_presp_cfg_type     (axigm_presp_cfg_type    )
      ,.axigm_presp_cfg_stream   (axigm_presp_cfg_stream  )
      ,.ibreq_presp_cdc_halt     (ibreq_presp_cdc_halt    )
      ,.ibreq_presp_cfg_cdc_halt (ibreq_presp_cfg_cdc_halt)
      ,.ibreq_presp_cfg_cdc_alm_halt(ibreq_presp_cfg_cdc_alm_halt)
      ,.ibreq_presp_cmplt        (ibreq_presp_cmplt       )
      ,.ibreq_presp_rpseq        (ibreq_presp_rpseq       )
      ,.ibreq_presp_dma_chan_num (ibreq_presp_dma_chan_num)
      ,.ibreq_presp_dma_err      (ibreq_presp_dma_err     )
      ,.ibreq_presp_type         (ibreq_presp_type        )
      ,.ibreq_cfg_rpseq          (ibreq_cfg_rpseq         )
      );

   // ---------------------------------------------------------------------------
   // Instantiate AXI Master Gasket
   // ---------------------------------------------------------------------------

   // Map additional misc_info bits to internal misc_info bus
   wire [MSTR_RESP_MISC_INFO_WD-1:0]                                  int_mstr_rmisc_info;
   assign int_mstr_rmisc_info = {rmisc_info,2'd0};

   wire [MSTR_ID_WD-1:0]                                              unconn_mstr_wid;
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0]                             unconn_mstr_wid_extra;
   DWC_pcie_axi_gm
   
     #(
       .AXI_DATA_WIDTH                (MSTR_DATA_WD                 ),
       .AXI_ADDR_WIDTH                (MSTR_ADDR_WD                 ),
       .AXI_LOCK_WIDTH                (MSTR_LOCK_WD                 ),
       .AXI_ID_WIDTH                  (MSTR_ID_WD                   ),
       .DC_INBD_MISCINFO_WD           (DC_INBD_MISCINFO_WD          ),
       .MSTR_MISC_INFO_WD             (MSTR_MISC_INFO_WD            ),
       .RESP_MISC_INFO_WD             (MSTR_RESP_MISC_INFO_WD       ),
       .BURST_LEN_PW                  (MSTR_BURST_LEN_PW            ),
       .AXI_AWPROT_0                  (AXI_AWPROT_0                 ),
       .AXI_AWPROT_1                  (AXI_AWPROT_1                 ),
       .AXI_AWPROT_2                  (AXI_AWPROT_2                 ),
       .AXI_ARPROT_0                  (AXI_ARPROT_0                 ),
       .AXI_ARPROT_1                  (AXI_ARPROT_1                 ),
       .AXI_ARPROT_2                  (AXI_ARPROT_2                 ),
       .CC_WR_CH_NP_RSP_QUEUE_DP      (CC_WR_CH_NP_RSP_QUEUE_DP     ),
       .CC_WR_CH_NP_RSP_QUEUE_DP_LOG2 (CC_WR_CH_NP_RSP_QUEUE_DP_LOG2),
       .AXI_STRB_WIDTH                (MSTR_WSTRB_WD                ),
       .AXI_MTU_PW                    (MSTR_MTU_PW                  ),
       .BE_CTRL_WD                    (MSTR_BE_CTRL_WD              ),
       .DC_DMA_TYPE_WIDTH             (DC_DMA_TYPE_WIDTH            ),
       .CC_NUM_DMA_RD_CHAN            (CC_NUM_DMA_RD_CHAN           ),
       .CC_NUM_DMA_WR_CHAN            (CC_NUM_DMA_WR_CHAN           ),
       .CC_NUM_DMA_RD_CHAN_WIDTH      (CC_NUM_DMA_RD_CHAN_WIDTH     ),
       .CC_NUM_DMA_WR_CHAN_WIDTH      (CC_NUM_DMA_WR_CHAN_WIDTH     ),
       .CC_NUM_DMA_MAX_CHAN_WIDTH     (CC_NUM_DMA_MAX_CHAN_WIDTH    ),
       .NUM_AXI_ID                    (MAX_MSTR_TAGS                ),
       .MAX_MSTR_TAGS                 (MAX_MSTR_TAGS                ),
       .RX_TLP_PREFIX_WD              (RX_TLP_PREFIX_WD             ),
       .TPH_ST_WD                     (TPH_ST_WD                    ),
       .TPH_PH_WD                     (TPH_PH_WD                    ),
       .TPH_TH_WD                     (TPH_TH_WD                    ),
       .P_N_PRESP_STREAMS             (P_N_PRESP_STREAMS            ),
       .P_N_PRESP_STREAMS_WD          (P_N_PRESP_STREAMS_WD         ),
       .P_N_PRESP_STREAMS_W_RO_WD     (P_N_PRESP_STREAMS_W_RO_WD    ),
       .P_CFG_IB_P_ID_MNG_CTRL_TYPE   (P_CFG_IB_P_ID_MNG_CTRL_TYPE  ),
       .CX_NVC_LOG2                   (CX_NVC_LOG2                  ),
       .P_NP_PASS_P_WD                (P_NP_PASS_P_WD               )
       )
   u_axigm
     (
      .aclk                     (mstr_aclk                 )
      ,.aresetn                 (mstr_arstn                )
      ,.gclken                  (1'b1                      )

      ,.cfg_mstr_arcache_mode    (cfg_mstr_arcache_mode           )
      ,.cfg_mstr_awcache_mode    (cfg_mstr_awcache_mode           )
      ,.cfg_mstr_arcache_value   (cfg_mstr_arcache_value          )
      ,.cfg_mstr_awcache_value   (cfg_mstr_awcache_value          )
      ,.cfg_mstr_ardomain_mode   (cfg_mstr_ardomain_mode          )
      ,.cfg_mstr_awdomain_mode   (cfg_mstr_awdomain_mode          )
      ,.cfg_mstr_ardomain_value  (cfg_mstr_ardomain_value         )
      ,.cfg_mstr_awdomain_value  (cfg_mstr_awdomain_value         )
      ,.cfg_ax_mstr_zeroread_fw  (cfg_ax_mstr_zeroread_fw         )
      ,.cfg_ib_p_id_mng_ctrl     (cfg_ib_p_id_mng_ctrl            )
      ,.axi_ras_par_ibr_rmstr_ad_pulse(axi_ras_par_ibr_rmstr_ad_pulse)
      ,.axi_ras_par_ibr_wmstr_ad_pulse(axi_ras_par_ibr_wmstr_ad_pulse)
      ,.axi_ras_par_ibr_wmstr_dt_pulse(axi_ras_par_ibr_wmstr_dt_pulse)
      ,.axi_ibr_rmstr_ad_ras_dp_err_log(axi_ibr_rmstr_ad_ras_dp_err_log)
      ,.axi_ibr_wmstr_ad_ras_dp_err_log(axi_ibr_wmstr_ad_ras_dp_err_log)
      ,.axi_ibr_wmstr_dt_ras_dp_err_log(axi_ibr_wmstr_dt_ras_dp_err_log)
      ,.ras_dp_err_inj_aclk (ras_dp_err_inj_mstr_aclk)

      // -------------------------------------------------------------------------
      // Interface with MRF (write channel)
      ,.wrq_maddr                (wrq_maddr[MSTR_ADDR_WD-1:0]                          )
      ,.wrq_mwrite               (wrq_mwrite                                           )
      ,.wrq_mlen                 (wrq_mlen                                             )
      ,.wrq_mdata                (wrq_mdata[MSTR_DATA_WD-1:0]                          )
      ,.wrq_mwstrb               (wrq_mbe                                              )
      ,.wrq_mmisc_info           (wrq_mmisc_info                                       )
      ,.wrq_mid                  (wrq_mid                                              )
      ,.wrq_mbe_ctrl             (wrq_mbe_ctrl                                         )
      ,.wrq_mabort               (wrq_mabort                                           )
      ,.wrq_mlast_tlp            (wrq_last                                             )
      ,.wrq_saccept              (wrq_saccept                                          )
      // -------------------------------------------------------------------------
      // Interface with Master Completion Buffer
      ,.svalid                   (mstr_svalid                                          )
      ,.sdata                    (mstr_sdata                                           )
      ,.slast                    (mstr_slast                                           )
      ,.sresp                    (mstr_sresp[3*1-1:3*0]                                )
      ,.smisc_info_cpl_stat      (mstr_smisc_info_cpl_stat                             )
      ,.sid                      (mstr_sid                                             )
      ,.sbyte_en                 (mstr_sbyte_en                                        )
      ,.smisc_info               (mstr_smisc_info                                      )
      ,.mready                   (mcb_ready                                            )
      // -------------------------------------------------------------------------
      // Interface with MRF (Read Channel)
      ,.rdq_maddr                (rdq_maddr[MSTR_ADDR_WD-1:0]                          )
      ,.rdq_mread                (rdq_mread                                            )
      ,.rdq_mlen                 (rdq_mlen                                             )
      ,.rdq_mdata                (rdq_mdata[MSTR_DATA_WD-1:0]                          )
      ,.rdq_mwstrb               (rdq_mbe                                              )
      ,.rdq_mmisc_info           (rdq_mmisc_info                                       )
      ,.rdq_mid                  (rdq_mid                                              )
      ,.rdq_mbe_ctrl             (rdq_mbe_ctrl                                         )
      ,.rdq_mabort               (rdq_mabort                                           )
      ,.rdq_mlast_tlp            (rdq_last                                             )
      ,.rdq_saccept              (rdq_saccept                                          )
      // AW Interface
      ,.awid                     (awid                                            )
      ,.awid_extra               (awid_extra                                      )
      ,.awvalid                  (awvalid                                         )
      ,.awaddr                   (awaddr                                         )
      ,.awlen                    (awlen[MSTR_BURST_LEN_PW*1-1:MSTR_BURST_LEN_PW*0])
      ,.awsize                   (awsize[3*1-1:3*0]                               )
      ,.awburst                  (awburst[2*1-1:2*0]                              )
      ,.awlock                   (awlock[MSTR_LOCK_WD-1:0]                        )
      ,.awcache                  (awcache[4*1-1:4*0]                              )
      ,.awprot                   (awprot[3*1-1:3*0]                               )
      ,.awready                  (awready                                         )
      ,.awmisc_info              (awmisc_info                                     )
      ,.awmisc_info_hdr_34dw     (awmisc_info_hdr_34dw                            )
      ,.awmisc_info_last_dcmp_tlp(awmisc_info_last_dcmp_tlp                       )
      ,.msg_addr                 (msg_addr                                        )
      ,.msg_addrp                (msg_addrp                                       )
      ,.awmisc_info_nw           (awmisc_info_nw                                  )
      ,.awmisc_info_cxlsrc       (awmisc_info_cxlsrc                              )
      ,.awmisc_info_ats          (awmisc_info_ats                                 )
      ,.awmisc_info_ep           (awmisc_info_ep                                  )
      ,.awmisc_info_dma          (awmisc_info_dma                                 )
      ,.awmisc_info_tlpprfx      (awmisc_info_tlpprfx                             )
      ,.awmisc_info_tph          (awmisc_info_tph                                 )
      ,.awmisc_info_ido          (awmisc_info_ido                                 )
      ,.awmisc_info_dst_segment  (awmisc_info_dst_segment                         )
      ,.awmisc_info_req_segment  (awmisc_info_req_segment                         )
      ,.awqos                    (awqos                                           )
      ,.awdomain                 (awdomain                                        )
      ,.awbar                    (awbar                                           )
      ,.awsnoop                  (awsnoop                                         )
      ,.awatop                   (awatop                                          )
      ,.arid                     (arid                                            )
      ,.arvalid                  (arvalid                                         )
      ,.araddr                   (araddr                                         )
      ,.arlen                    (arlen[MSTR_BURST_LEN_PW*1-1:MSTR_BURST_LEN_PW*0])
      ,.arsize                   (arsize[3*1-1:3*0]                               )
      ,.arburst                  (arburst[2*1-1:2*0]                              )
      ,.arlock                   (arlock[MSTR_LOCK_WD-1:0]                        )
      ,.arcache                  (arcache[4*1-1:4*0]                              )
      ,.arprot                   (arprot[3*1-1:3*0]                               )
      ,.arready                  (arready                                         )
      ,.armisc_info              (armisc_info                                     )
      ,.armisc_info_last_dcmp_tlp(armisc_info_last_dcmp_tlp                       )
      ,.armisc_info_nw           (armisc_info_nw                                  )
      ,.armisc_info_cxlsrc       (armisc_info_cxlsrc                              )
      ,.armisc_info_ats          (armisc_info_ats                                 )
      ,.armisc_info_dma          (armisc_info_dma                                 )
      ,.armisc_info_tlpprfx      (armisc_info_tlpprfx                             )
      ,.armisc_info_tph          (armisc_info_tph                                 )
      ,.armisc_info_ido          (armisc_info_ido                                 )
      ,.armisc_info_dst_segment  (armisc_info_dst_segment                         )
      ,.armisc_info_req_segment  (armisc_info_req_segment                         )
      ,.armisc_info_zeroread     (armisc_info_zeroread                            )
      ,.arqos                    (arqos                                           )
      ,.ardomain                 (ardomain                                        )
      ,.arbar                    (arbar                                           )
      ,.arsnoop                  (arsnoop                                         )


      ,.rid                      (rid [MSTR_ID_WD-2:0]                            )
      ,.rvalid                   (rvalid                                          )
      ,.rlast                    (rlast                                           )
      ,.rdata                    (rdata                                           )
      ,.rresp                    (rresp[2*1-1:2*0]                                )
      ,.rmisc_info_cpl_stat      (rmisc_info_cpl_stat                             )
      ,.rmisc_info               (int_mstr_rmisc_info                             )

      ,.rready                   (rready                                          )
      ,.wid                      (unconn_mstr_wid[MSTR_ID_WD-1:0]                 )
      ,.wid_extra                (unconn_mstr_wid_extra                           )
      ,.wvalid                   (wvalid                                          )
      ,.wlast                    (wlast                                           )
      ,.wdata                    (wdata                                           )
      ,.wstrb                    (wstrb[MSTR_WSTRB_WD-1:0]                        )
      ,.wready                   (wready                                          )
      ,.bid                      (bid[MSTR_ID_WD-1:0]                         )
      ,.bid_extra                (bid_extra                                       )
      ,.bvalid                   (bvalid                                          )
      ,.bresp                    (bresp[2*1-1:2*0]                                )
      ,.bmisc_info_cpl_stat      (bmisc_info_cpl_stat                             )
      ,.bready                   (bready                                          )
      ,.b_rsp_atop_flag          (bid[MSTR_ID_WD-1]                           )
      ,.csysreq                  (csysreq                                         )
      ,.csysack                  (csysack                                         )
      ,.cactive                  (cactive                                         )
      ,.stop_req                 (1'b0                                            )
      ,.stop_done                (/*UNCONNECTED*/                                 )
      ,.stop_resp_done           (/*UNCONNECTED*/                                 )
      ,.rtime_cdc_halt           (ibreq_presp_cdc_halt                            )
      ,.rtime_cfg_cdc_halt       (ibreq_presp_cfg_cdc_halt                        )
      ,.rtime_cfg_cdc_alm_halt   (ibreq_presp_cfg_cdc_alm_halt                    )
      ,.gm_presp_dma_chan_num    (axigm_presp_dma_chan_num                        )
      ,.gm_presp_dma_err         (axigm_presp_dma_err                             )
      ,.gm_presp_cmplt           (axigm_presp_cmplt                               )
      ,.gm_presp_rpseq           (axigm_presp_rpseq                               )
      ,.gm_presp_type            (axigm_presp_type                                )
      ,.gm_presp_stream          (axigm_presp_stream                              )

      ,.gm_presp_cfg_cmplt       (axigm_presp_cfg_cmplt                           )
      ,.gm_presp_cfg_rpseq       (axigm_presp_cfg_rpseq                           )
      ,.gm_presp_cfg_type        (axigm_presp_cfg_type                            )
      ,.gm_presp_cfg_stream      (axigm_presp_cfg_stream                          )
      );

   // ---------------------------------------------------------------------------
   // Instantiate Master Completion Buffer
   // ---------------------------------------------------------------------------
   assign s_sresp               = mstr_sresp[2:1];
   assign s_smisc_info_cpl_stat = mstr_smisc_info_cpl_stat;
   assign s_sresp_wr_not_rd     = mstr_sresp[0];
   assign s_sresp_np_not_p      = mstr_smisc_info[`MSTR_RESP_MISC_INFO_NP_HIGH:`MSTR_RESP_MISC_INFO_NP_LOW];
   assign s_smisc_info_ep       = mstr_smisc_info[`MSTR_RESP_MISC_INFO_EP_HIGH];
   assign s_smisc_info_tc       = mstr_smisc_info[`MSTR_RESP_MISC_INFO_TC_HIGH:`MSTR_RESP_MISC_INFO_TC_LOW];
   assign s_smisc_info_bad_eot  = mstr_smisc_info[`MSTR_RESP_MISC_INFO_BADEOT_HIGH];
   DWC_pcie_amba_mstr_cpl_buf
   
     #(
       .AXI_ENABLED                          (1                                ),
       .CX_RAS_RAM_PROT_RANGE                (CX_RAS_RAM_PROT_RANGE            ),
       .CC_MAX_MSTR_TAGS                     (MAX_MSTR_TAGS                    ),
       .CC_MAX_MSTR_TAG_PW                   (MAX_MSTR_TAG_PW                  ),
       .NSEGMENTS                            (MAX_MSTR_TAGS                    ),
       .NSEGMENTS_WD                         (MAX_MSTR_TAG_PW                  ),

       .CC_MSTR_RSP_DATA_WD                  (MSTR_RSP_DATA_WD                 ),
       .CC_MSTR_BUS_WSTRB_WIDTH              (MSTR_BUS_WSTRB_WIDTH             ),
       .CX_REMOTE_MAX_TAGS                   (MAX_MSTR_TAGS                    ),
       .CX_REMOTE_MAX_TAGS_WD                (MAX_MSTR_TAG_PW                  ),
       .CC_MSTR_MAX_SPLIT_PACK_PW            (MSTR_MAX_SPLIT_PACK_PW           ),
       .CX_NFUNC                             (CX_NFUNC                         ),
       .CX_NFUNC_WD                          (CX_NFUNC_WD                      ),
       .DC_DMA_TYPE_WIDTH                    (DC_DMA_TYPE_WIDTH                ),
       .CC_NUM_DMA_RD_CHAN                   (CC_NUM_DMA_RD_CHAN               ),
       .CC_NUM_DMA_WR_CHAN                   (CC_NUM_DMA_WR_CHAN               ),
       .CC_NUM_DMA_RD_CHAN_WIDTH             (CC_NUM_DMA_RD_CHAN_WIDTH         ),
       .CC_NUM_DMA_WR_CHAN_WIDTH             (CC_NUM_DMA_WR_CHAN_WIDTH         ),
       .CC_NUM_DMA_MAX_CHAN_WIDTH            (CC_NUM_DMA_MAX_CHAN_WIDTH        ),
       .CC_MSTR_CPL_DATA_SEG_DP              (MSTR_CPL_DATA_SEG_DP             ),
       .CC_MSTR_CPL_SEG_DATA_WD              (MSTR_CPL_SEG_DATA_WD             ),
       .CC_MSTR_CPL_SEG_DATA_WD_NP           (MSTR_CPL_SEG_DATA_WD_NP          ),
       .CC_MSTR_CPL_SEG_BUF_ADDR_WD          (CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD   ),
       .CC_MSTR_CPL_SEG_BUF_DATA_WD          (CC_IB_MCPL_SEG_BUF_RAM_DATA_WD   ),
       .CC_MSTR_CPL_SEG_DATA_NUM_DWORDS      (MSTR_CPL_SEG_DATA_NUM_DWORDS     ),
       .CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 (MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2),
       .CC_MSTR_CPL_SEG_DATA_NUM_BYTES       (MSTR_CPL_SEG_DATA_NUM_BYTES      ),
       .CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2  (MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 ),
       .CC_MSTR_CPL_SEG_DATA_SIZE_ENC        (MSTR_CPL_SEG_DATA_SIZE_ENC       ),
       .CC_MSTR_CPL_DATA_WD                  (MSTR_CPL_DATA_WD                 ),
       .CX_ADDR_PAR_WD                       (ADDR_PAR_WD                      ),
       .CC_MSTR_RSP_INTF_WD                  (MSTR_RSP_INTF_WD                 ),
       .CC_MSTR_RSP_INTF_WD_NP               (MSTR_RSP_INTF_WD_NP              ),
       .CC_MCB_A2C_FIFO_DEPTH                (CC_IB_MCPL_CDC_RAM_DP            ),
       .CC_MCB_A2C_FIFO_ADDR_WD              (CC_IB_MCPL_CDC_RAM_ADDR_WD       ),
       .CC_MCB_A2C_FIFO_DATA_WD              (CC_IB_MCPL_CDC_RAM_DATA_WD       ),
       .CC_MCB_A2C_FIFO_RD_LATENCY           (CC_IB_MCPL_CDC_RAM_RD_LATENCY    ),
       .CC_MSTR_CPL_C2A_FIFO_DEPTH           (CC_MSTR_CPL_C2A_FIFO_DEPTH       ),
       .CC_MSTR_CPL_C2A_FIFO_WD              (CC_MSTR_CPL_C2A_FIFO_WD          ),
       .CC_MSTR_CPL_QUEUE_DP                 (CC_MSTR_CPL_QUEUE_DP             ),
       .CC_MSTR_CPL_QUEUE_DP_LOG2            (CC_MSTR_CPL_QUEUE_DP_LOG2        )
       )
   u_mcb
     (
      .core_clk                     (core_clk    )
      ,.core_rst_n                  (core_rstn   )
      ,.mstr_aclk                   (mstr_aclk   )
      ,.mstr_aresetn                (mstr_arstn  )
      // -------------------------------------------------------------------------
      // Configuration inputs
      ,.cfg_max_payload_size         (cfg_max_payload_size )
      // -------------------------------------------------------------------------
      // RAS interface
      ,.cfg_ras_recc_ib_mcpl_a2c_cdc_correct        (cfg_ras_recc_ib_mcpl_a2c_cdc_correct        )
      ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse (mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse )
      ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse(mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse)
      ,.axi_ras_recc_cnt_ib_mcpl_a2c_cdc_addr       (mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr       ) //This generates the correctable and uncorrectable version
      ,.axi_ras_par_ib_mcpl_a2c_dt_pulse            (mcb_ras_par_ib_mcpl_a2c_dt_pulse            )
      ,.axi_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log (mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log )
      ,.axi_ib_mcpl_a2c_dt_ras_dp_err_log           (mcb_ib_mcpl_a2c_dt_ras_dp_err_log           )
      ,.axi_bridge_ras_dp_err_inj_core_clk          (axi_bridge_ras_dp_err_inj_core_clk     )
      ,.core_clk_hp_mstr_ras_dp_err_inj             (core_clk_hp_mstr_ras_dp_err_inj        )
      ,.ras_dp_err_inj_mstr_aclk                    (ras_dp_err_inj_mstr_aclk               )
      ,.cfg_ras_recc_ib_mcpl_sb_correct             (cfg_ras_recc_ib_mcpl_sb_correct        )
      ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse      (mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse )
      ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse     (mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse)
      ,.axi_ras_recc_cnt_ib_mcpl_sb_addr            (mcb_ras_recc_cnt_ib_mcpl_sb_addr       ) //This generates the correctable and uncorrectable version
      ,.axi_ras_par_ib_mcpl_sb_dt_pulse             (mcb_ras_par_ib_mcpl_sb_dt_pulse        )
      ,.axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log      (axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log )
      ,.axi_ib_mcpl_sb_dt_ras_dp_err_log            (mcb_ib_mcpl_sb_dt_ras_dp_err_log       )
      // -------------------------------------------------------------------------
      // Flush interface
      ,.rstctl_mstr_flush_req        (rstctl_mstr_flush_req   )
      // -------------------------------------------------------------------------
      // Master request information interface
      ,.radmx_mreq_np_valid          (reqmcb_hdr_np_valid     )
      ,.radmx_ireq_np_lookup_id      (reqmcb_hdr_lookupid     )
      ,.radmx_ireq_np_func           (reqmcb_hdr_func         )
      ,.radmx_ireq_np_ncbe           (reqmcb_hdr_ncbe         )
      ,.radmx_ireq_np_4kb_start_addr (reqmcb_hdr_low_addr     )
      ,.radmx_ireq_np_dw_len_bytes   (reqmcb_hdr_dw_len_bytes)
      ,.radmx_ireq_np_dma_type       (reqmcb_hdr_dma_type     )
      ,.radmx_ireq_np_dma_chan       (reqmcb_hdr_dma_chan     )
      ,.radmx_mreq_np_id             (reqmcb_hdr_mstrid       )
      ,.radmx_mreq_np_last           (reqmcb_hdr_last         )

      ,.mrf_mreq_np_valid            (ibmrf_reqmcb_np_valid   )
      ,.mrf_mreq_np_id               (ibmrf_reqmcb_mstrid     )
      ,.mrf_mreq_np_last             (ibmrf_reqmcb_last       )
      ,.mrf_mreq_np_atomic           (ibmrf_reqmcb_atomic     )
      // -------------------------------------------------------------------------
      // Master response interface
      ,.svalid                       (mstr_svalid             )
      ,.sid                          (mstr_sid                )
      ,.sresp_wr_not_rd              (s_sresp_wr_not_rd       )
      ,.sresp_np_not_p               (s_sresp_np_not_p        )
      ,.sresp                        (s_sresp                 )
      ,.smisc_info_cpl_stat          (s_smisc_info_cpl_stat   )
      ,.smisc_info_ep                (s_smisc_info_ep         )
      ,.smisc_info_tc                (s_smisc_info_tc         )
      ,.smisc_info_bad_eot           (s_smisc_info_bad_eot    )
      ,.sbyte_en                     (mstr_sbyte_en           )
      ,.sdata                        (mstr_sdata              )
      ,.slast                        (mstr_slast              )
      ,.mcb_ready                    (mcb_ready               )
      // -------------------------------------------------------------------------
      // Master response segment buffer RAM interface
      ,.mcb_sb_waddr                 (ib_mcpl_sb_ram_addra    )
      ,.mcb_sb_wen                   (ib_mcpl_sb_ram_wea      )
      ,.mcb_sb_wdata                 (ib_mcpl_sb_ram_dina     )
      ,.mcb_sb_raddr                 (ib_mcpl_sb_ram_addrb    )
      ,.mcb_sb_ren                   (ib_mcpl_sb_ram_enb      )
      ,.sb_rdata                     (ib_mcpl_sb_ram_doutb    )
      // -------------------------------------------------------------------------
      // External master response AMBA to Core clock crossing RAM interface
      ,.mcb_a2c_wen                  (ib_mcpl_a2c_cdc_ram_wea  )
      ,.mcb_a2c_waddr                (ib_mcpl_a2c_cdc_ram_addra)
      ,.mcb_a2c_wdata                (ib_mcpl_a2c_cdc_ram_dina )
      ,.mcb_a2c_raddr                (ib_mcpl_a2c_cdc_ram_addrb)
      ,.mcb_a2c_ren                  (ib_mcpl_a2c_cdc_ram_enb  )
      ,.a2c_rdata                    (ib_mcpl_a2c_cdc_ram_doutb)
      // -------------------------------------------------------------------------
      ,.dma_mcb_rdll_halt            (dma_mcb_rdll_halt       )
      ,.dma_mcb_wrll_halt            (dma_mcb_wrll_halt       )
      // Client interface
      ,.mcb_hv                       (ibc0_tlp_hv             )
      ,.mcb_fmt                      (mcb_fmt                 )
      ,.mcb_type                     (mcb_type                )
      ,.mcb_ireq_np_lookup_id        (mcb_ireq_np_lookup_id   )
      ,.mcb_dw_len_bytes             (mcb_dw_len_bytes        )
      ,.mcb_func                     (mcb_func                )
      ,.mcb_status                   (mcb_status              )
      ,.mcb_ep                       (mcb_ep                  )
      ,.mcb_dma_chan                 (mcb_dma_chan            )
      ,.mcb_dma_type                 (mcb_dma_type            )
      ,.mcb_prv_dma                  (mcb_prv_dma             )
      ,.mcb_prv_dma_chan             (mcb_prv_dma_chan        )
      ,.mcb_dv                       (ibc0_tlp_dv             )
      ,.mcb_data                     (mcb_data                )
      ,.mcb_bad_eot                  (mcb_bad_eot             )
      ,.mcb_eot                      (ibc0_tlp_eot            )
      ,.mcb_last                     (mcb_last                )
      ,.mcb_bcm                      (mcb_bcm                 )
      ,.mcb_addr_align_en            (mcb_addr_align_en       )
      ,.mcb_td                       (mcb_td                  )
      ,.mcb_attr                     (mcb_attr                )
      ,.mcb_byte_cnt                 (mcb_byte_cnt            )
      ,.mcb_ats                      (mcb_ats                 )
      ,.mcb_tc                       (mcb_tc                  )
      ,.mcb_tid                      (mcb_tid                 )
      ,.mcb_addr                     (mcb_addr                )
      ,.mcb_byte_en                  (mcb_byte_en             )
      ,.mcb_cmpltr_id                (mcb_cmpltr_id           )
      ,.mcb_addr_parerr              ()
      ,.halt                         (xadm_ibc0_halt          )
      );

   // ---------------------------------------------------------------------------
   // Client 0 interface
   assign ibc0_addr_align_en    = mcb_addr_align_en         ;
   assign ibc0_tlp_fmt          = mcb_fmt                   ;
   assign ibc0_tlp_type         = mcb_type                  ;
   assign ibc0_tlp_bad_eot      = mcb_bad_eot               ;
   assign ibc0_cpl_last         = mcb_last                  ;
   assign ibc0_cpl_bcm          = mcb_bcm                   ;
   assign ibc0_cpl_byte_cnt     = mcb_byte_cnt              ;
   assign ibc0_tlp_td           = mcb_td                    ;
   assign ibc0_tlp_ep           = mcb_ep                    ;
   assign ibc0_tlp_attr         = mcb_attr                  ;
   assign ibc0_tlp_ats          = mcb_ats                   ;
   assign ibc0_tlp_atu_bypass   = '0                        ;
   assign ibc0_tlp_tc           = mcb_tc                    ;
   assign ibc0_cpl_lookup_id    = {{(CX_REMOTE_LOOKUPID_WD-MAX_MSTR_TAG_PW){1'b0}},mcb_ireq_np_lookup_id} ;
   assign ibc0_tlp_tid          = mcb_tid                   ;
   assign ibc0_tlp_addr         = mcb_addr                  ;
   assign ibc0_tlp_func_num     = mcb_func                  ;
   assign ibc0_cpl_cmpltr_id    = mcb_cmpltr_id             ;
   assign ibc0_cpl_status       = mcb_status                ;
   assign ibc0_tlp_byte_en      = mcb_byte_en               ;
   assign ibc0_tlp_data         = mcb_data                  ;
   assign ibc0_tlp_byte_len     = mcb_dw_len_bytes          ;
   assign ibc0_tlp_dma          = mcb_dma_type              ;
   assign ibc0_tlp_dma_channel  = mcb_dma_chan              ;
   assign ibc0_tlp_prv_dma      = mcb_prv_dma               ;
   assign ibc0_tlp_prv_dma_chan = mcb_prv_dma_chan          ;


endmodule
