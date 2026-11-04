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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_scheduler.sv#5 $
// ---------------------------------------------------------------------------------------
// Module Description:
// Does muxing of the inbound traffic, depending on the configuration
// Stamps to the incoming TLP a sequence number
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_bridge_ib_scheduler

  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter DC_INBD_HEADER_PNP_WD        = `DC_INBD_HEADER_PNP_WD,
    parameter DC_INBD_HEADER_PNP_1STG_WD   = `DC_INBD_HEADER_PNP_1STG_WD,
    parameter DC_INBD_HEADER_PNP_1STG_WD_NP= `DC_INBD_HEADER_PNP_1STG_WD_NP,
    parameter CC_MSTR_BUS_DATA_WIDTH       = `CC_MSTR_BUS_DATA_WIDTH,
    parameter DC_INBD_HEADER_CPL_WD        = `DC_INBD_HEADER_CPL_WD,
    parameter CC_SLV_BUS_DATA_WIDTH        = `CC_SLV_BUS_DATA_WIDTH,
    parameter PCIE_CORE_DATA_BUS_WD        = `PCIE_CORE_DATA_BUS_WD, //No ECC data width
    parameter CORE_DATA_BUS_WD             = `CC_CORE_DATA_BUS_WD,
    parameter CC_PCIE_CORE_NUM_BYTES       = `CC_PCIE_CORE_NUM_BYTES,
    parameter NW                           = `CX_NW,
    parameter PF_WD                        = `CX_NFUNC_WD,
    parameter CORE_ADDR_BUS_WD             = `CC_CORE_ADDR_BUS_WD,
    parameter FLT_Q_ADDR_WIDTH             = `FLT_Q_ADDR_WIDTH,
    parameter CX_TAG_SIZE                  = `CX_TAG_SIZE,
    parameter CX_REMOTE_LOOKUPID_WD        = `CX_REMOTE_LOOKUPID_WD,
    parameter CX_RAS_PROT_RANGE            = `CX_RAS_PROT_RANGE,
    parameter CX_RAS_RAM_PROT_RANGE        = `CX_RAS_RAM_PROT_RANGE,
    parameter CX_RAS_PARITY_MODE           = `CX_RAS_PARITY_MODE,
    parameter MAX_WIRE_TAG_PW              = 5,
    parameter MAX_WIRE_TAG                 = 128,

    parameter RX_TLP_PREFIX_WD             = `FLT_Q_PRFX_WIDTH,
    parameter TPH_ST_WD                    = 8,
    parameter TPH_PH_WD                    = 2,
    parameter TPH_TH_WD                    = 1,
    parameter VF_WD                        = `CX_NVFUNC_WD,
    parameter CC_AMBA_TLP_SEQ_WD           = `CC_AMBA_TLP_SEQ_WD,
    parameter CX_NVC_LOG2                  = `CX_NVC_LOG2,
    parameter CX_NVC                       = `CX_NVC,
    parameter CC_P_REQ_MAX_LOG2            = `CC_P_REQ_MAX_LOG2,
    parameter CX_REMOTE_MAX_TAGS_WD        = `CX_REMOTE_MAX_TAGS_WD,
    parameter CC_MAX_MSTR_TAG_PW           = `CC_MAX_MSTR_TAG_PW,
    parameter FLT_Q_ATTR_WIDTH             = `FLT_Q_ATTR_WIDTH,
    parameter DC_DMA_TYPE_WIDTH            = `DC_DMA_TYPE_WIDTH,
    parameter CC_NUM_DMA_RD_CHAN_WIDTH     = `CC_NUM_DMA_RD_CHAN_WIDTH,
    parameter CC_NUM_DMA_MAX_CHAN_WIDTH    = `CC_NUM_DMA_MAX_CHAN_WIDTH,
    parameter DC_DMA_REQ_BYPASS            = `DC_DMA_REQ_BYPASS,
    parameter DC_DMA_REQ_BYPASS_CPL        = `DC_DMA_REQ_BYPASS_CPL,

    parameter CC_IB_SCHEDULER_P_HDR_RAM_DP        = `CC_IB_SCHEDULER_P_HDR_RAM_DP       ,
    parameter CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD   = `CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD  ,
    parameter CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD   = `CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD  ,
    parameter CC_IB_SCHEDULER_P_DATA_RAM_DP       = `CC_IB_SCHEDULER_P_DATA_RAM_DP      ,
    parameter CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD  = `CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD ,
    parameter CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD  = `CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD ,
    parameter CC_IB_SCHEDULER_P_RAM_RD_LATENCY    = `CC_IB_SCHEDULER_P_RAM_RD_LATENCY   ,
    parameter CC_IB_SCHEDULER_P_RAM_REGIN         = `CC_IB_SCHEDULER_P_RAM_REGIN        ,
    parameter CC_IB_SCHEDULER_NP_HDR_RAM_DP       = `CC_IB_SCHEDULER_NP_HDR_RAM_DP      ,
    parameter CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD  = `CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD ,
    parameter CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD  = `CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD ,
    parameter CC_IB_SCHEDULER_NP_DATA_RAM_DP      = `CC_IB_SCHEDULER_NP_DATA_RAM_DP     ,
    parameter CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD = `CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD,
    parameter CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD = `CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD,
    parameter CC_IB_SCHEDULER_NP_RAM_RD_LATENCY   = `CC_IB_SCHEDULER_NP_RAM_RD_LATENCY  ,
    parameter CC_IB_SCHEDULER_NP_RAM_REGIN        = `CC_IB_SCHEDULER_NP_RAM_REGIN       ,
    
    parameter RASDP_TRGT1_HDR_PROT_WD      = `CX_RASDP_TRGT1_HDR_PROT_WD,
    parameter RASDP_TRGT1_HDR_WD           = `CX_RASDP_TRGT1_HDR_WD,
    parameter RASDP_BYPASS_HDR_PROT_WD     = `CX_RASDP_BYPASS_HDR_PROT_WD,
    parameter RASDP_BYPASS_HDR_WD          = `CX_RASDP_BYPASS_HDR_WD,

    parameter RADM_RASDP_TRGT1_P_HDR_WD        = `CX_RASDP_TRGT1_P_HDR_WD,
    parameter RADM_RASDP_TRGT1_NP_HDR_WD       = `CX_RASDP_TRGT1_NP_HDR_WD,
    parameter RADM_RASDP_TRGT1_CPL_HDR_WD      = `CX_RASDP_TRGT1_CPL_HDR_WD,
    parameter RADM_RASDP_TRGT1_P_HDR_PROT_WD   = `CX_RASDP_TRGT1_P_HDR_PROT_WD,
    parameter RADM_RASDP_TRGT1_NP_HDR_PROT_WD  = `CX_RASDP_TRGT1_NP_HDR_PROT_WD,
    parameter RADM_RASDP_TRGT1_CPL_HDR_PROT_WD = `CX_RASDP_TRGT1_CPL_HDR_PROT_WD,

    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    parameter TP       = `TP
    )
   
                                      (
     input                                          clk
    ,input                                          rstn

    ,input [7:0]                                    cfg_ax_mstr_np_pass_p
    ,input [`CX_NVC-1:0]                            cfg_ax_mstr_ro_p_en
    ,input                                          cfg_10b_tag_en
    ,input                                          cfg_memtype_value
    ,input [`FLT_Q_ADDR_WIDTH-3:0]                  cfg_memtype_boundary

    ,output reg  [DC_INBD_HEADER_PNP_1STG_WD-1:0]   inbd_header_pnp_wr
    ,output wire [FLT_Q_ADDR_WIDTH-1:0]             inbd_header_pnp_wr_uppr_bytes

    ,output reg  [CORE_DATA_BUS_WD-1:0]             inbd_data_pnp_wr
    ,input                                          inbd_halt_pnp_wr

    ,output logic [DC_INBD_HEADER_PNP_1STG_WD-1:0]  inbd_header_pnp_rd
    ,input                                          inbd_halt_pnp_rd

    ,output wire [DC_INBD_HEADER_CPL_WD-1:0]        inbd_header_cpl
    ,output wire [CC_AMBA_TLP_SEQ_WD-1:0]           inbd_header_cpl_pseq
    ,output wire [CORE_DATA_BUS_WD-1:0]             inbd_data_cpl
    ,input                                          inbd_halt_cpl

    ,input [CX_REMOTE_LOOKUPID_WD-1:0]              trgt_lookup_id
    ,input                                          radm_trgt1_p_0_pending
    ,input [CORE_DATA_BUS_WD-1:0]                   radm_trgt1_p_0_data
    ,input [RADM_RASDP_TRGT1_P_HDR_PROT_WD-1:0]     radm_trgt1_p_0_hdr_prot
    ,input [RX_TLP_PREFIX_WD-1:0]                   radm_trgt1_p_0_prfx
    ,input [NW-1:0]                                 radm_trgt1_p_0_dwen
    ,input                                          radm_trgt1_p_0_dv
    ,input                                          radm_trgt1_p_0_hv
    ,input                                          radm_trgt1_p_0_eot
    ,input                                          radm_trgt1_p_0_dllp_abort
    ,input                                          radm_trgt1_p_0_tlp_abort
    ,input                                          radm_trgt1_p_0_ecrc_err
    ,input [1:0]                                    radm_trgt1_p_0_fmt
    ,input [4:0]                                    radm_trgt1_p_0_type
    ,input [2:0]                                    radm_trgt1_p_0_tc
    ,input [FLT_Q_ATTR_WIDTH-1:0]                   radm_trgt1_p_0_attr
    ,input [15:0]                                   radm_trgt1_p_0_reqid
    ,input [CX_TAG_SIZE-1:0]                        radm_trgt1_p_0_tag
    ,input [PF_WD-1:0]                              radm_trgt1_p_0_func_num
    ,input                                          radm_trgt1_p_0_td
    ,input [2:0]                                    radm_trgt1_p_0_cpl_status
    ,input                                          radm_trgt1_p_0_poisoned
    ,input [9:0]                                    radm_trgt1_p_0_dw_len
    ,input [3:0]                                    radm_trgt1_p_0_first_be
    ,input [CX_NVC_LOG2-1:0]                        radm_trgt1_p_0_vc_num
    ,input [FLT_Q_ADDR_WIDTH-1:0]                   radm_trgt1_p_0_addr
    ,input [FLT_Q_ADDR_WIDTH-1:0]                   radm_trgt1_p_0_hdr_uppr_bytes
    ,input                                          radm_trgt1_p_0_rom_in_range
    ,input                                          radm_trgt1_p_0_io_req_in_range
    ,input [2:0]                                    radm_trgt1_p_0_in_membar_range
    ,input [3:0]                                    radm_trgt1_p_0_last_be
    ,input [1:0]                                    radm_trgt1_p_0_ats
    ,input                                          radm_trgt1_p_0_nw
    ,input                                          radm_trgt1_p_0_th
    ,input [1:0]                                    radm_trgt1_p_0_ph
    ,input [7:0]                                    radm_trgt1_p_0_st
    ,input                                          radm_trgt1_p_0_hdr_uppr_bytes_valid
    ,input [DC_DMA_TYPE_WIDTH-1:0]                  radm_trgt1_p_0_req_dma
    ,input [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]          radm_trgt1_p_0_req_dma_channel
    ,input                                          radm_trgt1_p_0_req_dma_mem_type
    ,input [8:0]                                    radm_trgt1_p_0_reqtr_sgmt
    ,input [8:0]                                    radm_trgt1_p_0_dest_sgmt
    ,input [CC_AMBA_TLP_SEQ_WD-1:0]                 radm_trgt1_p_0_pkt_order_no
    ,input [CORE_DATA_BUS_WD-1:0]                   radm_trgt1_np_0_data
    ,input [RADM_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]    radm_trgt1_np_0_hdr_prot
    ,input [RX_TLP_PREFIX_WD-1:0]                   radm_trgt1_np_0_prfx
    ,input [NW-1:0]                                 radm_trgt1_np_0_dwen
    ,input                                          radm_trgt1_np_0_dv
    ,input                                          radm_trgt1_np_0_hv
    ,input                                          radm_trgt1_np_0_eot
    ,input                                          radm_trgt1_np_0_dllp_abort
    ,input                                          radm_trgt1_np_0_tlp_abort
    ,input                                          radm_trgt1_np_0_ecrc_err
    ,input [1:0]                                    radm_trgt1_np_0_fmt
    ,input [4:0]                                    radm_trgt1_np_0_type
    ,input [2:0]                                    radm_trgt1_np_0_tc
    ,input [FLT_Q_ATTR_WIDTH-1:0]                   radm_trgt1_np_0_attr
    ,input [15:0]                                   radm_trgt1_np_0_reqid
    ,input [CX_TAG_SIZE-1:0]                        radm_trgt1_np_0_tag
    ,input [PF_WD-1:0]                              radm_trgt1_np_0_func_num
    ,input [2:0]                                    radm_trgt1_np_0_cpl_status
    ,input                                          radm_trgt1_np_0_td
    ,input                                          radm_trgt1_np_0_poisoned
    ,input [9:0]                                    radm_trgt1_np_0_dw_len
    ,input [3:0]                                    radm_trgt1_np_0_first_be
    ,input [CX_NVC_LOG2-1:0]                        radm_trgt1_np_0_vc_num

    ,input [FLT_Q_ADDR_WIDTH-1:0]                   radm_trgt1_np_0_addr
    ,input [FLT_Q_ADDR_WIDTH-1:0]                   radm_trgt1_np_0_hdr_uppr_bytes

    ,input                                          radm_trgt1_np_0_rom_in_range
    ,input                                          radm_trgt1_np_0_io_req_in_range
    ,input [2:0]                                    radm_trgt1_np_0_in_membar_range
    ,input [3:0]                                    radm_trgt1_np_0_last_be
    ,input [1:0]                                    radm_trgt1_np_0_ats
    ,input                                          radm_trgt1_np_0_nw
    ,input                                          radm_trgt1_np_0_cxlsrc
    ,input                                          radm_trgt1_np_0_th
    ,input [1:0]                                    radm_trgt1_np_0_ph
    ,input [7:0]                                    radm_trgt1_np_0_st
    ,input [DC_DMA_TYPE_WIDTH-1:0]                  radm_trgt1_np_0_req_dma
    ,input [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]          radm_trgt1_np_0_req_dma_channel
    ,input                                          radm_trgt1_np_0_req_dma_mem_type
    ,input [8:0]                                    radm_trgt1_np_0_reqtr_sgmt
    ,input [8:0]                                    radm_trgt1_np_0_dest_sgmt
    ,input [CC_AMBA_TLP_SEQ_WD-1:0]                 radm_trgt1_np_0_pkt_order_no

    ,input [CORE_DATA_BUS_WD-1:0]                   radm_trgt1_cpl_0_data
    ,input [RADM_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]   radm_trgt1_cpl_0_hdr_prot
    ,input [RX_TLP_PREFIX_WD-1:0]                   radm_trgt1_cpl_0_prfx
    ,input [NW-1:0]                                 radm_trgt1_cpl_0_dwen
    ,input                                          radm_trgt1_cpl_0_dv
    ,input                                          radm_trgt1_cpl_0_hv
    ,input                                          radm_trgt1_cpl_0_eot
    ,input                                          radm_trgt1_cpl_0_dllp_abort
    ,input                                          radm_trgt1_cpl_0_tlp_abort
    ,input                                          radm_trgt1_cpl_0_ecrc_err
    ,input [1:0]                                    radm_trgt1_cpl_0_fmt
    ,input [4:0]                                    radm_trgt1_cpl_0_type
    ,input [2:0]                                    radm_trgt1_cpl_0_tc
    ,input [FLT_Q_ATTR_WIDTH-1:0]                   radm_trgt1_cpl_0_attr
    ,input [15:0]                                   radm_trgt1_cpl_0_reqid
    ,input [CX_TAG_SIZE-1:0]                        radm_trgt1_cpl_0_tag
    ,input [PF_WD-1:0]                              radm_trgt1_cpl_0_func_num
    ,input [2:0]                                    radm_trgt1_cpl_0_cpl_status
    ,input                                          radm_trgt1_cpl_0_td
    ,input                                          radm_trgt1_cpl_0_poisoned
    ,input [9:0]                                    radm_trgt1_cpl_0_dw_len
    ,input                                          radm_trgt1_cpl_0_bcm
    ,input [11:0]                                   radm_trgt1_cpl_0_byte_cnt
    ,input [15:0]                                   radm_trgt1_cpl_0_cmpltr_id
    ,input                                          radm_trgt1_cpl_0_last
    ,input [CX_NVC_LOG2-1:0]                        radm_trgt1_cpl_0_vc_num

    ,input [FLT_Q_ADDR_WIDTH-1:0]                   radm_trgt1_cpl_0_addr

    ,input [8:0]                                    radm_trgt1_cpl_0_dest_sgmt
    ,input [7:0]                                    radm_trgt1_cpl_0_cpl_sgmt
    ,input [CC_AMBA_TLP_SEQ_WD -1 :0]               radm_trgt1_cpl_0_pkt_order_no

    ,output wire                                    trgt1_radm_intf_cpl_0_halt
    ,output wire                                    trgt1_radm_intf_p_0_halt
    ,output wire                                    trgt1_radm_intf_np_0_halt

    ,output                                         d_trgt1_wreq_cmplt_dma // eDMA memory write request complete pulse
    ,output [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]          d_trgt1_wreq_cmplt_dma_channel // eDMA memory write request complete channel number
    ,output                                         d_trgt1_wreq_err_dma // eDMA memory write request error status. Valid when d_trgt1_wreq_cmplt_dma asserted.

    ,input                                                 cfg_sch_p_hdr_ras_recc_correct
    ,output wire                                           sch_p_hdr_ras_recc_corr_cnt_pulse
    ,output wire                                           sch_p_hdr_ras_recc_ucorr_cnt_pulse
    ,output wire [CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]   sch_p_hdr_ras_recc_cnt_addr
    ,output wire                                           axi_ras_par_ib_sch_p_ad_pulse
    ,input                                                 cfg_sch_p_data_ras_recc_correct
    ,output wire                                           sch_p_data_ras_recc_corr_cnt_pulse
    ,output wire                                           sch_p_data_ras_recc_ucorr_cnt_pulse
    ,output wire [CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]  sch_p_data_ras_recc_cnt_addr
    ,output wire                                           axi_ras_par_ib_sch_p_dt_pulse
    ,input                                                 cfg_sch_np_hdr_ras_recc_correct
    ,output wire                                           sch_np_hdr_ras_recc_corr_cnt_pulse
    ,output wire                                           sch_np_hdr_ras_recc_ucorr_cnt_pulse
    ,output wire [CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]  sch_np_hdr_ras_recc_cnt_addr
    ,output wire                                           axi_ras_par_ib_sch_np_ad_pulse
    ,input                                                 cfg_sch_np_data_ras_recc_correct
    ,output wire                                           sch_np_data_ras_recc_corr_cnt_pulse
    ,output wire                                           sch_np_data_ras_recc_ucorr_cnt_pulse
    ,output wire [CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0] sch_np_data_ras_recc_cnt_addr
    ,output wire                                           axi_ras_par_ib_sch_np_dt_pulse
    ,output wire                                           axi_ras_par_rtrgt_p_ad_pulse
    ,output wire                                           axi_ras_par_rtrgt_p_dt_pulse
    ,output wire                                           axi_ras_par_rtrgt_np_ad_pulse
    ,output wire                                           axi_ras_par_rtrgt_np_dt_pulse
    ,output wire                                           axi_ras_par_rtrgt_cpl_ad_pulse
    ,output wire                                           axi_ras_par_rtrgt_cpl_dt_pulse
    ,output ras_dp_err_log_t                               axi_rtrgt_p_ad_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_rtrgt_p_dt_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_rtrgt_np_ad_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_rtrgt_np_dt_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_rtrgt_cpl_ad_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_rtrgt_cpl_dt_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_ib_sch_p_ad_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_ib_sch_p_dt_ras_dp_err_log
    ,output ras_dp_err_log_t                               sch_p_data_recc_corr_cnt_ras_dp_err_log
    ,output ras_dp_err_log_t                               sch_p_hdr_recc_corr_cnt_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_ib_sch_np_ad_ras_dp_err_log
    ,output ras_dp_err_log_t                               axi_ib_sch_np_dt_ras_dp_err_log
    ,output ras_dp_err_log_t                               sch_np_data_recc_corr_cnt_ras_dp_err_log
    ,output ras_dp_err_log_t                               sch_np_hdr_recc_corr_cnt_ras_dp_err_log
    ,input  ras_dp_err_inj_t                               core_clk_ordrb_ras_dp_err_inj
    

    // Posted response interface
    ,input [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                  ibreq_presp_dma_chan_num
    ,input                                                 ibreq_presp_dma_err
    ,input                                                 ibreq_presp_cmplt
    ,input  [1:0]                                          ibreq_presp_type
    ,input  [CX_NVC-1:0] [CC_AMBA_TLP_SEQ_WD-1:0]          ibreq_cfg_rpseq
    ,input  [CX_NVC-1:0] [CC_AMBA_TLP_SEQ_WD-1:0]          ibreq_presp_rpseq
    ,output [CX_NVC-1:0]                                   trgt1_p_xfer_pend_per_vc

    ,output                                                ib_scheduler_p_hdr_ram_wea
    ,output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addra
    ,output [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_dina
    ,output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addrb
    ,output                                                ib_scheduler_p_hdr_ram_enb
    ,input  [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_doutb

    ,output                                                ib_scheduler_p_data_ram_wea
    ,output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addra
    ,output [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_dina
    ,output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addrb
    ,output                                                ib_scheduler_p_data_ram_enb
    ,input  [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_doutb

    ,output                                                ib_scheduler_np_hdr_ram_wea
    ,output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addra
    ,output [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_dina
    ,output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addrb
    ,output                                                ib_scheduler_np_hdr_ram_enb
    ,input  [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_doutb

    ,output                                                ib_scheduler_np_data_ram_wea
    ,output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addra
    ,output [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_dina
    ,output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addrb
    ,output                                                ib_scheduler_np_data_ram_enb
    ,input  [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_doutb

    );

   ///////////////////////////////////
   // Internal parameters
   //////////////////////////////////

   localparam [8:0] INIT_BYTE = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;

   localparam [CORE_DATA_BUS_WD-1:0] BUS_INIT = {CC_PCIE_CORE_NUM_BYTES{INIT_BYTE}};

   localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

   ///////////////////////////////////
   // Wire declaration
   //////////////////////////////////


   //Sequence number generation signals
   wire [CC_AMBA_TLP_SEQ_WD-1:0]                  pseq_nbr;
   wire [CC_AMBA_TLP_SEQ_WD-1:0]                  pseq_nbr_d;



   wire [6:0]                                     radm_trgt1_cpl_0_low_addr;       // Address, it is valid when mux mode of completion is asserted
   wire                                           s_cpl_out_of_max_tag;
   wire                                           s_radm_trgt1_cpl_0_hv_masked;
   wire                                           s_radm_trgt1_cpl_0_dv_masked;
   wire                                           s_radm_trgt1_cpl_0_eot_masked;
   wire                                           s_radm_trgt1_cpl_0_dllp_abort_masked;
   wire                                           s_radm_trgt1_cpl_0_tlp_abort_masked;
   wire [CX_TAG_SIZE-1:0]                         s_radm_trgt1_cpl_0_tag_masked;


   wire [CORE_ADDR_BUS_WD -1:0]                   i_radm_trgt1_np_0_addr;
   wire [CORE_DATA_BUS_WD -1:0]                   i_radm_trgt1_np_0_data;
   wire [CORE_ADDR_BUS_WD -1:0]                   i_radm_trgt1_p_0_addr;
   wire [CORE_DATA_BUS_WD -1:0]                   i_radm_trgt1_p_0_data;
   wire [CORE_ADDR_BUS_WD -1:0]                   i_radm_trgt1_cpl_0_addr;
   wire [CORE_DATA_BUS_WD -1:0]                   i_radm_trgt1_cpl_0_data;

   wire                                           ordr_inbd_hdr_np_halt;
   
   wire [DC_INBD_HEADER_PNP_1STG_WD-1:0]               i_inbd_header_pnp_wr;
   wire [CORE_DATA_BUS_WD-1:0]                    i_inbd_data_pnp_wr;
   reg                                            w_inbd_halt_pnp_wr;

   wire                                           ibr_decode_mwr_p_pseq;

   reg                   [CC_AMBA_TLP_SEQ_WD-1:0] last_pseq_per_vc [CX_NVC-1:0];

   wire  [DC_INBD_HEADER_PNP_1STG_WD-1:0]         s_inbd_header_p           , ss_inbd_header_p;
   wire  [DC_INBD_HEADER_PNP_1STG_WD-1:0]         s_inbd_header_np          , ss_inbd_header_np;
   wire  [FLT_Q_ADDR_WIDTH-1:0]                   s_inbd_header_p_uppr_bytes, ss_inbd_header_p_uppr_bytes;
   wire                                                                       ss_radm_trgt1_p_0_hv;
   wire                                                                       ss_radm_trgt1_p_0_dv;
   wire                                                                       ss_radm_trgt1_p_0_eot;

   wire  [`CC_IB_SCHEDULER_P_DATA_WD-1:0]         s_inbd_data_p             , ss_inbd_data_p;
   wire  [`CC_IB_SCHEDULER_NP_DATA_WD-1:0]        s_inbd_data_np            , ss_inbd_data_np;
   wire                                                                                    ss_radm_trgt1_np_0_hv;
   wire                                                                                    ss_radm_trgt1_np_0_dv;
   wire                                                                                    ss_radm_trgt1_np_0_eot;

   reg [1:0]      wr_mux_state;
   reg [1:0] next_wr_mux_state;

   reg       radm_trgt_wr_mux;
   reg       r_last_wr_type;


  reg [RADM_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]   r_radm_trgt1_cpl_0_hdr_prot;
  reg [RX_TLP_PREFIX_WD-1:0]                   r_radm_trgt1_cpl_0_prfx;
  reg                                          r_radm_trgt1_cpl_0_tlp_abort;
  reg [1:0]                                    r_radm_trgt1_cpl_0_fmt;
  reg [4:0]                                    r_radm_trgt1_cpl_0_type;
  reg [2:0]                                    r_radm_trgt1_cpl_0_tc;
  reg [FLT_Q_ATTR_WIDTH-1:0]                   r_radm_trgt1_cpl_0_attr;
  reg [15:0]                                   r_radm_trgt1_cpl_0_reqid;
  reg [CX_TAG_SIZE-1:0]                        r_radm_trgt1_cpl_0_tag;
  reg [PF_WD-1:0]                              r_radm_trgt1_cpl_0_func_num;
  reg                                          r_radm_trgt1_cpl_0_td;
  reg                                          r_radm_trgt1_cpl_0_poisoned;
  reg [9:0]                                    r_radm_trgt1_cpl_0_dw_len;
  reg [2:0]                                    r_radm_trgt1_cpl_0_cpl_status;
  reg                                          r_radm_trgt1_cpl_0_bcm;
  reg [15:0]                                   r_radm_trgt1_cpl_0_cmpltr_id;
  reg [11:0]                                   r_radm_trgt1_cpl_0_byte_cnt;
  reg [3:0]                                    r_radm_trgt1_cpl_0_first_be;
  reg [CX_NVC_LOG2-1:0]                        r_radm_trgt1_cpl_0_vc_num;
  reg [CORE_ADDR_BUS_WD-1:0]                   r_radm_trgt1_cpl_0_addr;
  reg                                          r_radm_trgt1_cpl_0_rom_in_range;
  reg                                          r_radm_trgt1_cpl_0_io_req_in_range;
  reg [2:0]                                    r_radm_trgt1_cpl_0_in_membar_range;
  reg [3:0]                                    r_radm_trgt1_cpl_0_last_be;
  reg                                          r_radm_trgt1_cpl_0_last;
  reg [1:0]                                    r_radm_trgt1_cpl_0_ats;
  reg                                          r_radm_trgt1_cpl_0_nw;
  reg                                          r_radm_trgt1_cpl_0_th;
  reg [1:0]                                    r_radm_trgt1_cpl_0_ph;
  reg [7:0]                                    r_radm_trgt1_cpl_0_st;
  reg [7:0]                                    r_radm_trgt1_cpl_0_cpl_sgmt;
  reg [8:0]                                    r_radm_trgt1_cpl_0_dest_sgmt;
  reg [CC_AMBA_TLP_SEQ_WD-1:0]                 r_radm_trgt1_cpl_0_pkt_order_no;

  wire [NW-1:0]                                s_radm_trgt1_cpl_0_dwen;
  wire [RADM_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]  s_radm_trgt1_cpl_0_hdr_prot;
  wire [RX_TLP_PREFIX_WD-1:0]                  s_radm_trgt1_cpl_0_prfx;
  wire                                         s_radm_trgt1_cpl_0_tlp_abort;
  wire [1:0]                                   s_radm_trgt1_cpl_0_fmt;
  wire [4:0]                                   s_radm_trgt1_cpl_0_type;
  wire [2:0]                                   s_radm_trgt1_cpl_0_tc;
  wire [FLT_Q_ATTR_WIDTH-1:0]                  s_radm_trgt1_cpl_0_attr;
  wire [15:0]                                  s_radm_trgt1_cpl_0_reqid;
  wire [CX_TAG_SIZE-1:0]                       s_radm_trgt1_cpl_0_tag;
  wire [PF_WD-1:0]                             s_radm_trgt1_cpl_0_func_num;
  wire                                         s_radm_trgt1_cpl_0_td;
  wire                                         s_radm_trgt1_cpl_0_poisoned;
  wire [9:0]                                   s_radm_trgt1_cpl_0_dw_len;
  wire [2:0]                                   s_radm_trgt1_cpl_0_cpl_status;
  wire                                         s_radm_trgt1_cpl_0_bcm;
  wire [15:0]                                  s_radm_trgt1_cpl_0_cmpltr_id;
  wire [11:0]                                  s_radm_trgt1_cpl_0_byte_cnt;
  wire [3:0]                                   s_radm_trgt1_cpl_0_first_be;
  wire [CX_NVC_LOG2-1:0]                       s_radm_trgt1_cpl_0_vc_num;
  wire [CORE_ADDR_BUS_WD-1:0]                  s_radm_trgt1_cpl_0_addr;
  wire                                         s_radm_trgt1_cpl_0_rom_in_range;
  wire                                         s_radm_trgt1_cpl_0_io_req_in_range;
  wire [2:0]                                   s_radm_trgt1_cpl_0_in_membar_range;
  wire [3:0]                                   s_radm_trgt1_cpl_0_last_be;
  wire                                         s_radm_trgt1_cpl_0_last;
  wire [1:0]                                   s_radm_trgt1_cpl_0_ats;
  wire                                         s_radm_trgt1_cpl_0_nw;
  wire                                         s_radm_trgt1_cpl_0_th;
  wire [1:0]                                   s_radm_trgt1_cpl_0_ph;
  wire [7:0]                                   s_radm_trgt1_cpl_0_st;
  wire [7:0]                                   s_radm_trgt1_cpl_0_cpl_sgmt;
  wire [8:0]                                   s_radm_trgt1_cpl_0_dest_sgmt;

  reg [RADM_RASDP_TRGT1_P_HDR_PROT_WD-1:0]     r_radm_trgt1_p_0_hdr_prot;
  reg [RX_TLP_PREFIX_WD-1:0]                   r_radm_trgt1_p_0_prfx;
  reg                                          r_radm_trgt1_p_0_tlp_abort;
  reg [1:0]                                    r_radm_trgt1_p_0_fmt;
  reg [4:0]                                    r_radm_trgt1_p_0_type;
  reg [2:0]                                    r_radm_trgt1_p_0_tc;
  reg [FLT_Q_ATTR_WIDTH-1:0]                   r_radm_trgt1_p_0_attr;
  reg [15:0]                                   r_radm_trgt1_p_0_reqid;
  reg [CX_TAG_SIZE-1:0]                        r_radm_trgt1_p_0_tag;
  reg [PF_WD-1:0]                              r_radm_trgt1_p_0_func_num;
  reg                                          r_radm_trgt1_p_0_td;
  reg                                          r_radm_trgt1_p_0_poisoned;
  reg [9:0]                                    r_radm_trgt1_p_0_dw_len;
  reg [3:0]                                    r_radm_trgt1_p_0_first_be;
  reg [CX_NVC_LOG2-1:0]                        r_radm_trgt1_p_0_vc_num;
  reg [CORE_ADDR_BUS_WD-1:0]                   r_radm_trgt1_p_0_addr;
  reg [FLT_Q_ADDR_WIDTH-1:0]                   r_radm_trgt1_p_0_hdr_uppr_bytes;
  reg                                          r_radm_trgt1_p_0_rom_in_range;
  reg                                          r_radm_trgt1_p_0_io_req_in_range;
  reg [2:0]                                    r_radm_trgt1_p_0_in_membar_range;
  reg [3:0]                                    r_radm_trgt1_p_0_last_be;
  reg [1:0]                                    r_radm_trgt1_p_0_ats;
  reg                                          r_radm_trgt1_p_0_nw;
  reg                                          r_radm_trgt1_p_0_th;
  reg [1:0]                                    r_radm_trgt1_p_0_ph;
  reg [7:0]                                    r_radm_trgt1_p_0_st;
  reg                                          r_radm_trgt1_p_0_hdr_uppr_bytes_valid;
  reg [DC_DMA_TYPE_WIDTH-1:0]                  r_radm_trgt1_p_0_req_dma;
  reg [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]          r_radm_trgt1_p_0_req_dma_channel;
  reg [8:0]                                    r_radm_trgt1_p_0_reqtr_sgmt;
  reg [8:0]                                    r_radm_trgt1_p_0_dest_sgmt;
  reg                                          r_radm_trgt1_p_0_mem_type;
  reg [CC_AMBA_TLP_SEQ_WD-1:0]                 r_radm_trgt1_p_0_pkt_order_no;
  
  wire [RADM_RASDP_TRGT1_P_HDR_PROT_WD-1:0]    s_radm_trgt1_p_0_hdr_prot;
  wire [CC_AMBA_TLP_SEQ_WD-1:0]                s_radm_trgt1_p_0_pkt_order_no;
  wire                                         s_errored_req;

  reg [RADM_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]    r_radm_trgt1_np_0_hdr_prot;
  reg [RX_TLP_PREFIX_WD-1:0]                   r_radm_trgt1_np_0_prfx;
  reg                                          r_radm_trgt1_np_0_tlp_abort;
  reg [1:0]                                    r_radm_trgt1_np_0_fmt;
  reg [4:0]                                    r_radm_trgt1_np_0_type;
  reg [2:0]                                    r_radm_trgt1_np_0_tc;
  reg [FLT_Q_ATTR_WIDTH-1:0]                   r_radm_trgt1_np_0_attr;
  reg [15:0]                                   r_radm_trgt1_np_0_reqid;
  reg [CX_TAG_SIZE-1:0]                        r_radm_trgt1_np_0_tag;
  reg [PF_WD-1:0]                              r_radm_trgt1_np_0_func_num;
  reg                                          r_radm_trgt1_np_0_td;
  reg                                          r_radm_trgt1_np_0_poisoned;
  reg [9:0]                                    r_radm_trgt1_np_0_dw_len;
  reg [3:0]                                    r_radm_trgt1_np_0_first_be;
  reg [CX_NVC_LOG2-1:0]                        r_radm_trgt1_np_0_vc_num;
  reg [CORE_ADDR_BUS_WD-1:0]                   r_radm_trgt1_np_0_addr;
  reg                                          r_radm_trgt1_np_0_rom_in_range;
  reg                                          r_radm_trgt1_np_0_io_req_in_range;
  reg [2:0]                                    r_radm_trgt1_np_0_in_membar_range;
  reg [3:0]                                    r_radm_trgt1_np_0_last_be;
  reg [1:0]                                    r_radm_trgt1_np_0_ats;
  reg                                          r_radm_trgt1_np_0_nw;
  reg                                          r_radm_trgt1_np_0_cxlsrc;
  reg                                          r_radm_trgt1_np_0_th;
  reg [1:0]                                    r_radm_trgt1_np_0_ph;
  reg [7:0]                                    r_radm_trgt1_np_0_st;
  reg [DC_DMA_TYPE_WIDTH-1:0]                  r_radm_trgt1_np_0_req_dma;
  reg [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]          r_radm_trgt1_np_0_req_dma_channel;
  reg [8:0]                                    r_radm_trgt1_np_0_reqtr_sgmt;
  reg [8:0]                                    r_radm_trgt1_np_0_dest_sgmt;
  reg [CX_REMOTE_LOOKUPID_WD-1:0]              r_trgt_lookup_id;
  reg                                          r_radm_trgt1_np_0_mem_type;
  reg [CC_AMBA_TLP_SEQ_WD-1:0]                 r_radm_trgt1_np_0_pkt_order_no;
  
  wire [RADM_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]   s_radm_trgt1_np_0_hdr_prot;
  wire [CC_AMBA_TLP_SEQ_WD-1:0]                s_radm_trgt1_np_0_pkt_order_no;

  wire                                         radm_trgt1_p_0_mem_type;
  wire                                         radm_trgt1_np_0_mem_type;

   ///////////////////////////////////
   // Internal Design
   //////////////////////////////////

/*
  Generating posted transfer pending output flag
  We compare the sequence numbers of the last received request and completion, per VC;
  if they all match then there are no outstanding P requests
*/

  reg [CC_AMBA_TLP_SEQ_WD-1:0] r_last_req_pseq;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] r_previous_req_pseq;
  wire                         s_trgt1_p_xfer_pend_per_vc;

  always@(posedge clk or negedge rstn)begin: R_PSEQ_NUM_IN_SEQ_PROC
    if(!rstn)begin
        r_last_req_pseq     <= #TP '0;
        r_previous_req_pseq <= #TP '0;
    end else begin
      if(!trgt1_radm_intf_p_0_halt && (radm_trgt1_p_0_req_dma == 0) )begin
        if(radm_trgt1_p_0_eot && !radm_trgt1_p_0_dllp_abort)begin
          r_previous_req_pseq <= #TP radm_trgt1_p_0_hv ? radm_trgt1_p_0_pkt_order_no : r_last_req_pseq;
        end
        if(radm_trgt1_p_0_hv)begin
          if(!radm_trgt1_p_0_eot || !radm_trgt1_p_0_dllp_abort)begin
            r_last_req_pseq     <= #TP radm_trgt1_p_0_pkt_order_no;
          end
        end else if(radm_trgt1_p_0_eot && radm_trgt1_p_0_dllp_abort)begin
          r_last_req_pseq      <= #TP r_previous_req_pseq;
        end 
      end
    end
  end

  assign s_trgt1_p_xfer_pend_per_vc = ( r_last_req_pseq != ibreq_presp_rpseq ) || radm_trgt1_p_0_pending;

assign trgt1_p_xfer_pend_per_vc = s_trgt1_p_xfer_pend_per_vc;




   //Bridge internally is still parity interleaved, this makes that conversion
   wire [CORE_ADDR_BUS_WD - FLT_Q_ADDR_WIDTH -1:0] trgta_p_par;
   bus_protect_gen
   
     #(
       .PROT_TYPE (1), //Parity
       .PROT_RANGE(CX_RAS_PROT_RANGE),
       .PROT_WD   (CORE_ADDR_BUS_WD - FLT_Q_ADDR_WIDTH),
       .DATA_WD   (FLT_Q_ADDR_WIDTH),
       .PARITY_MODE(CX_RAS_PARITY_MODE),
       .FORCE_ERR_INJ_OFF(1)
       ) u_trgta_p_par
       (
        .gen     (1'b1),
        .datain  (radm_trgt1_p_0_addr),

          //Error injection not actually implemented
        .core_clk(clk),
        .core_rst_n(rstn),
        .error_inj_mask({CORE_ADDR_BUS_WD - FLT_Q_ADDR_WIDTH + FLT_Q_ADDR_WIDTH{1'b0}}),
        .error_inj_en(1'b0),
        .error_inj_data_valid(1'b0),
        .error_inj_eot(1'b0),
        .error_inj_done(),

        .chkout  (trgta_p_par),
        .dataout ()
        );

   wire [CORE_ADDR_BUS_WD - FLT_Q_ADDR_WIDTH -1:0] trgta_np_par;
   bus_protect_gen
   
     #(
       .PROT_TYPE (1), //Parity
       .PROT_RANGE(CX_RAS_PROT_RANGE),
       .PROT_WD   (CORE_ADDR_BUS_WD - FLT_Q_ADDR_WIDTH),
       .DATA_WD   (FLT_Q_ADDR_WIDTH),
       .PARITY_MODE(CX_RAS_PARITY_MODE),
       .FORCE_ERR_INJ_OFF(1)
       ) u_trgta_np_par
       (
        .gen     (1'b1),
        .datain  (radm_trgt1_np_0_addr),

          //Error injection not actually implemented
        .core_clk(clk),
        .core_rst_n(rstn),
        .error_inj_mask({CORE_ADDR_BUS_WD - FLT_Q_ADDR_WIDTH + FLT_Q_ADDR_WIDTH{1'b0}}),
        .error_inj_en(1'b0),
        .error_inj_data_valid(1'b0),
        .error_inj_eot(1'b0),
        .error_inj_done(),

        .chkout  (trgta_np_par),
        .dataout ()
        );

   assign i_radm_trgt1_np_0_addr   = add_addr_par(radm_trgt1_np_0_addr  [FLT_Q_ADDR_WIDTH-1:0]     , trgta_np_par);
   assign i_radm_trgt1_np_0_data   = add_data_par(radm_trgt1_np_0_data  [PCIE_CORE_DATA_BUS_WD-1:0], radm_trgt1_np_0_data[CORE_DATA_BUS_WD-1:PCIE_CORE_DATA_BUS_WD]);
   assign i_radm_trgt1_p_0_addr    = add_addr_par(radm_trgt1_p_0_addr   [FLT_Q_ADDR_WIDTH-1:0]     , trgta_p_par);
   assign i_radm_trgt1_p_0_data    = add_data_par(radm_trgt1_p_0_data   [PCIE_CORE_DATA_BUS_WD-1:0], radm_trgt1_p_0_data [CORE_DATA_BUS_WD-1:PCIE_CORE_DATA_BUS_WD]);
   assign i_radm_trgt1_cpl_0_addr  = '0;
   assign i_radm_trgt1_cpl_0_data  = add_data_par(radm_trgt1_cpl_0_data [PCIE_CORE_DATA_BUS_WD-1:0], radm_trgt1_cpl_0_data [CORE_DATA_BUS_WD-1:PCIE_CORE_DATA_BUS_WD]);


   assign d_trgt1_wreq_cmplt_dma          = ibreq_presp_cmplt && ibreq_presp_type[0];
   assign d_trgt1_wreq_cmplt_dma_channel  = ibreq_presp_dma_chan_num;
   assign d_trgt1_wreq_err_dma            = ibreq_presp_dma_err;

  // ---------------------------------------------------------------------------
   // Masking all the signals starting the processing inside the composer
   // if there is an invalid tag
   // ---------------------------------------------------------------------------

always@(posedge clk or negedge rstn) begin: SEQ_RADM_TRGT1_CPL_0_PROC
  if(!rstn)begin
    r_radm_trgt1_cpl_0_hdr_prot             <= #TP '0;
    r_radm_trgt1_cpl_0_prfx                 <= #TP '0;
    r_radm_trgt1_cpl_0_tlp_abort            <= #TP '0;
    r_radm_trgt1_cpl_0_fmt                  <= #TP '0;
    r_radm_trgt1_cpl_0_type                 <= #TP '0;
    r_radm_trgt1_cpl_0_tc                   <= #TP '0;
    r_radm_trgt1_cpl_0_attr                 <= #TP '0;
    r_radm_trgt1_cpl_0_reqid                <= #TP '0;
    r_radm_trgt1_cpl_0_tag                  <= #TP '0;
    r_radm_trgt1_cpl_0_func_num             <= #TP '0;
    r_radm_trgt1_cpl_0_td                   <= #TP '0;
    r_radm_trgt1_cpl_0_poisoned             <= #TP '0;
    r_radm_trgt1_cpl_0_dw_len               <= #TP '0;
    r_radm_trgt1_cpl_0_cpl_status           <= #TP '0;
    r_radm_trgt1_cpl_0_bcm                  <= #TP '0;
    r_radm_trgt1_cpl_0_cmpltr_id            <= #TP '0;
    r_radm_trgt1_cpl_0_byte_cnt             <= #TP '0;
    r_radm_trgt1_cpl_0_vc_num               <= #TP '0;
    r_radm_trgt1_cpl_0_addr                 <= #TP '0;
    r_radm_trgt1_cpl_0_last                 <= #TP '0;
    r_radm_trgt1_cpl_0_cpl_sgmt             <= #TP '0;
    r_radm_trgt1_cpl_0_dest_sgmt            <= #TP '0;
    r_radm_trgt1_cpl_0_pkt_order_no         <= #TP '0;
  end else begin
    if(radm_trgt1_cpl_0_hv)begin
      r_radm_trgt1_cpl_0_hdr_prot             <= #TP   radm_trgt1_cpl_0_hdr_prot;
      r_radm_trgt1_cpl_0_prfx                 <= #TP   radm_trgt1_cpl_0_prfx;
      r_radm_trgt1_cpl_0_tlp_abort            <= #TP   radm_trgt1_cpl_0_tlp_abort;
      r_radm_trgt1_cpl_0_fmt                  <= #TP   radm_trgt1_cpl_0_fmt;
      r_radm_trgt1_cpl_0_type                 <= #TP   radm_trgt1_cpl_0_type;
      r_radm_trgt1_cpl_0_tc                   <= #TP   radm_trgt1_cpl_0_tc;
      r_radm_trgt1_cpl_0_attr                 <= #TP   radm_trgt1_cpl_0_attr;
      r_radm_trgt1_cpl_0_reqid                <= #TP   radm_trgt1_cpl_0_reqid;
      r_radm_trgt1_cpl_0_tag                  <= #TP   radm_trgt1_cpl_0_tag;
      r_radm_trgt1_cpl_0_func_num             <= #TP   radm_trgt1_cpl_0_func_num;
      r_radm_trgt1_cpl_0_td                   <= #TP   radm_trgt1_cpl_0_td;
      r_radm_trgt1_cpl_0_poisoned             <= #TP   radm_trgt1_cpl_0_poisoned;
      r_radm_trgt1_cpl_0_dw_len               <= #TP   radm_trgt1_cpl_0_dw_len;
      r_radm_trgt1_cpl_0_cpl_status           <= #TP   radm_trgt1_cpl_0_cpl_status;
      r_radm_trgt1_cpl_0_bcm                  <= #TP   radm_trgt1_cpl_0_bcm;
      r_radm_trgt1_cpl_0_cmpltr_id            <= #TP   radm_trgt1_cpl_0_cmpltr_id;
      r_radm_trgt1_cpl_0_byte_cnt             <= #TP   radm_trgt1_cpl_0_byte_cnt;
      r_radm_trgt1_cpl_0_vc_num               <= #TP   radm_trgt1_cpl_0_vc_num;
      r_radm_trgt1_cpl_0_addr                 <= #TP i_radm_trgt1_cpl_0_addr;
      r_radm_trgt1_cpl_0_last                 <= #TP   radm_trgt1_cpl_0_last;
      r_radm_trgt1_cpl_0_cpl_sgmt             <= #TP   radm_trgt1_cpl_0_cpl_sgmt;
      r_radm_trgt1_cpl_0_dest_sgmt            <= #TP   radm_trgt1_cpl_0_dest_sgmt;
      r_radm_trgt1_cpl_0_pkt_order_no         <= #TP   radm_trgt1_cpl_0_pkt_order_no;
    end
  end
end

  assign s_radm_trgt1_cpl_0_vc_num             = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_vc_num          : r_radm_trgt1_cpl_0_vc_num;

  assign s_radm_trgt1_cpl_0_tlp_abort          = radm_trgt1_cpl_0_eot ?   radm_trgt1_cpl_0_tlp_abort       : 1'b0;//radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_tlp_abort       : r_radm_trgt1_cpl_0_tlp_abort;
  assign s_radm_trgt1_cpl_0_reqid              = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_reqid           : r_radm_trgt1_cpl_0_reqid;
  assign s_radm_trgt1_cpl_0_ecrc_err           = radm_trgt1_cpl_0_eot ?   radm_trgt1_cpl_0_ecrc_err        : 1'b0;
  assign s_radm_trgt1_cpl_0_dwen               = radm_trgt1_cpl_0_dv  ?  (radm_trgt1_cpl_0_eot ? radm_trgt1_cpl_0_dwen            : {NW{1'b1}}) : {NW{1'b0}};
  assign s_radm_trgt1_cpl_0_dllp_abort         = radm_trgt1_cpl_0_eot ?   radm_trgt1_cpl_0_dllp_abort      : 1'b0;
  assign s_radm_trgt1_cpl_0_last               = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_last            : r_radm_trgt1_cpl_0_last;

  assign s_radm_trgt1_cpl_0_type               = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_type            : r_radm_trgt1_cpl_0_type;
  assign s_radm_trgt1_cpl_0_td                 = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_td              : r_radm_trgt1_cpl_0_td;
  assign s_radm_trgt1_cpl_0_prfx               = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_prfx            : r_radm_trgt1_cpl_0_prfx;
  assign s_radm_trgt1_cpl_0_poisoned           = radm_trgt1_cpl_0_eot ?   radm_trgt1_cpl_0_poisoned : 1'b0; //radm_trgt1_cpl_0_hv  ? radm_trgt1_cpl_0_poisoned        : r_radm_trgt1_cpl_0_poisoned;
  assign s_radm_trgt1_cpl_0_fmt                = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_fmt             : r_radm_trgt1_cpl_0_fmt;
  assign s_radm_trgt1_cpl_0_dw_len             = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_dw_len          : r_radm_trgt1_cpl_0_dw_len;
  assign s_radm_trgt1_cpl_0_cpl_status         = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_cpl_status      : r_radm_trgt1_cpl_0_cpl_status;
  assign s_radm_trgt1_cpl_0_bcm                = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_bcm             : r_radm_trgt1_cpl_0_bcm;
  assign s_radm_trgt1_cpl_0_cmpltr_id          = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_cmpltr_id       : r_radm_trgt1_cpl_0_cmpltr_id;
  assign s_radm_trgt1_cpl_0_byte_cnt           = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_byte_cnt        : r_radm_trgt1_cpl_0_byte_cnt;
  assign s_radm_trgt1_cpl_0_addr               = radm_trgt1_cpl_0_hv  ? i_radm_trgt1_cpl_0_addr            : r_radm_trgt1_cpl_0_addr;

  assign s_radm_trgt1_cpl_0_vfunc_num          = '0;
  assign s_radm_trgt1_cpl_0_vfunc_active       = '0;
  assign s_radm_trgt1_cpl_0_tc                 = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_tc              : r_radm_trgt1_cpl_0_tc;
  assign s_radm_trgt1_cpl_0_func_num           = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_func_num        : r_radm_trgt1_cpl_0_func_num;
  assign s_radm_trgt1_cpl_0_tag                = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_tag             : r_radm_trgt1_cpl_0_tag;
  assign s_radm_trgt1_cpl_0_ln                 = '0;
  assign s_radm_trgt1_cpl_0_attr               = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_attr            : r_radm_trgt1_cpl_0_attr;

  assign s_radm_trgt1_cpl_0_hdr_prot           = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_hdr_prot        : r_radm_trgt1_cpl_0_hdr_prot;
  assign s_radm_trgt1_cpl_0_cpl_sgmt           = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_cpl_sgmt        : r_radm_trgt1_cpl_0_cpl_sgmt;
  assign s_radm_trgt1_cpl_0_dest_sgmt          = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_dest_sgmt       : r_radm_trgt1_cpl_0_dest_sgmt;


   assign s_cpl_out_of_max_tag                 = cfg_10b_tag_en ? ((s_radm_trgt1_cpl_0_tag<256) || ((MAX_WIRE_TAG < 767) && (s_radm_trgt1_cpl_0_tag>(MAX_WIRE_TAG+256)))) : (s_radm_trgt1_cpl_0_tag>255);
   assign s_radm_trgt1_cpl_0_hv_masked         = s_cpl_out_of_max_tag ? 1'b0 : radm_trgt1_cpl_0_hv;
   assign s_radm_trgt1_cpl_0_dv_masked         = s_cpl_out_of_max_tag ? 1'b0 : radm_trgt1_cpl_0_dv;
   assign s_radm_trgt1_cpl_0_eot_masked        = s_cpl_out_of_max_tag ? 1'b0 : radm_trgt1_cpl_0_eot;
   assign s_radm_trgt1_cpl_0_dllp_abort_masked = s_cpl_out_of_max_tag ? 1'b0 : s_radm_trgt1_cpl_0_dllp_abort;
   assign s_radm_trgt1_cpl_0_tlp_abort_masked  = s_cpl_out_of_max_tag ? 1'b0 : s_radm_trgt1_cpl_0_tlp_abort;
   assign s_radm_trgt1_cpl_0_tag_masked        = s_cpl_out_of_max_tag ? {CX_TAG_SIZE{1'b0}} : s_radm_trgt1_cpl_0_tag - ( cfg_10b_tag_en ? 10'h100: 10'h000 );

   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_DV_HIGH:`INBD_HDR_CPL_RANGE_DV_LOW]                   = s_radm_trgt1_cpl_0_dv_masked;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_HV_HIGH:`INBD_HDR_CPL_RANGE_HV_LOW]                   = s_radm_trgt1_cpl_0_hv_masked;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_EOT_HIGH:`INBD_HDR_CPL_RANGE_EOT_LOW]                 = s_radm_trgt1_cpl_0_eot_masked;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_DWEN_HIGH:`INBD_HDR_CPL_RANGE_DWEN_LOW]               = s_radm_trgt1_cpl_0_dwen;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_CPL_RANGE_DLLP_ABORT_LOW]   = s_radm_trgt1_cpl_0_dllp_abort_masked;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_TLP_ABORT_HIGH:`INBD_HDR_CPL_RANGE_TLP_ABORT_LOW]     = s_radm_trgt1_cpl_0_tlp_abort_masked;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_CPL_RANGE_ECRC_ABORT_LOW]   = s_radm_trgt1_cpl_0_ecrc_err;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_LAST_HIGH:`INBD_HDR_CPL_RANGE_LAST_LOW]               = s_radm_trgt1_cpl_0_last;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_STATUS_HIGH:`INBD_HDR_CPL_RANGE_CPL_STATUS_LOW]   = s_radm_trgt1_cpl_0_cpl_status;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_BYTE_CNT_HIGH:`INBD_HDR_CPL_RANGE_BYTE_CNT_LOW]       = s_radm_trgt1_cpl_0_byte_cnt;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_FMT_HIGH:`INBD_HDR_CPL_RANGE_FMT_LOW]                 = s_radm_trgt1_cpl_0_fmt;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_TYPE_HIGH:`INBD_HDR_CPL_RANGE_TYPE_LOW]               = s_radm_trgt1_cpl_0_type;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_TC_HIGH:`INBD_HDR_CPL_RANGE_TC_LOW]                   = s_radm_trgt1_cpl_0_tc;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_ATTR_HIGH:`INBD_HDR_CPL_RANGE_ATTR_LOW]               = s_radm_trgt1_cpl_0_attr;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_ATS_HIGH:`INBD_HDR_CPL_RANGE_ATS_LOW]                 = '0;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_TAG_HIGH:`INBD_HDR_CPL_RANGE_TAG_LOW]                 = s_radm_trgt1_cpl_0_tag_masked[MAX_WIRE_TAG_PW-1:0];
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_DW_LEN_HIGH:`INBD_HDR_CPL_RANGE_DW_LEN_LOW]           = s_radm_trgt1_cpl_0_dw_len;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_LOW_ADDR_HIGH:`INBD_HDR_CPL_RANGE_LOW_ADDR_LOW]       = s_radm_trgt1_cpl_0_addr[6:0];
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPLID_HIGH:`INBD_HDR_CPL_RANGE_CPLID_LOW]             = s_radm_trgt1_cpl_0_cmpltr_id;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_REQID_HIGH:`INBD_HDR_CPL_RANGE_REQID_LOW]             = s_radm_trgt1_cpl_0_reqid;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_TD_HIGH:`INBD_HDR_CPL_RANGE_TD_LOW]                   = s_radm_trgt1_cpl_0_td;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_POISONED_HIGH:`INBD_HDR_CPL_RANGE_POISONED_LOW]       = s_radm_trgt1_cpl_0_poisoned;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_BCM_HIGH:`INBD_HDR_CPL_RANGE_BCM_LOW]                 = s_radm_trgt1_cpl_0_bcm;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_LOCK_HIGH:`INBD_HDR_CPL_RANGE_CPL_LOCK_LOW]       = s_radm_trgt1_cpl_0_type[0];
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_WO_DATA_HIGH:`INBD_HDR_CPL_RANGE_CPL_WO_DATA_LOW] =  {s_radm_trgt1_cpl_0_fmt, s_radm_trgt1_cpl_0_type[4:1]} == 6'b000101;

   assign inbd_header_cpl_pseq                                                                      = radm_trgt1_cpl_0_hv  ?   radm_trgt1_cpl_0_pkt_order_no         : r_radm_trgt1_cpl_0_pkt_order_no;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_DST_SEGMENT_HIGH:`INBD_HDR_CPL_RANGE_DST_SEGMENT_LOW] =  s_radm_trgt1_cpl_0_dest_sgmt;
   assign inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_SEGMENT_HIGH:`INBD_HDR_CPL_RANGE_CPL_SEGMENT_LOW] =  s_radm_trgt1_cpl_0_cpl_sgmt;


   assign inbd_data_cpl                                                                             = inbd_header_cpl[`INBD_HDR_CPL_RANGE_DV_HIGH:`INBD_HDR_CPL_RANGE_DV_LOW] ? i_radm_trgt1_cpl_0_data : BUS_INIT;

   assign trgt1_radm_intf_cpl_0_halt                                                                = 1'b0;

   assign radm_trgt1_p_0_mem_type  = radm_trgt1_p_0_req_dma_mem_type;

always@(posedge clk or negedge rstn) begin: SEQ_RADM_TRGT1_P_0_PROC
  if(!rstn)begin
    r_radm_trgt1_p_0_hdr_prot             <= #TP '0;
    r_radm_trgt1_p_0_prfx                 <= #TP '0;
    r_radm_trgt1_p_0_tlp_abort            <= #TP '0;
    r_radm_trgt1_p_0_fmt                  <= #TP '0;
    r_radm_trgt1_p_0_type                 <= #TP '0;
    r_radm_trgt1_p_0_tc                   <= #TP '0;
    r_radm_trgt1_p_0_attr                 <= #TP '0;
    r_radm_trgt1_p_0_reqid                <= #TP '0;
    r_radm_trgt1_p_0_tag                  <= #TP '0;
    r_radm_trgt1_p_0_func_num             <= #TP '0;
    r_radm_trgt1_p_0_td                   <= #TP '0;
    r_radm_trgt1_p_0_poisoned             <= #TP '0;
    r_radm_trgt1_p_0_dw_len               <= #TP '0;
    r_radm_trgt1_p_0_first_be             <= #TP '0;
    r_radm_trgt1_p_0_vc_num               <= #TP '0;
    r_radm_trgt1_p_0_addr                 <= #TP '0;
    r_radm_trgt1_p_0_hdr_uppr_bytes       <= #TP '0;
    r_radm_trgt1_p_0_rom_in_range         <= #TP '0;
    r_radm_trgt1_p_0_io_req_in_range      <= #TP '0;
    r_radm_trgt1_p_0_in_membar_range      <= #TP '0;
    r_radm_trgt1_p_0_last_be              <= #TP '0;
    r_radm_trgt1_p_0_ats                  <= #TP '0;
    r_radm_trgt1_p_0_nw                   <= #TP '0;
    r_radm_trgt1_p_0_th                   <= #TP '0;
    r_radm_trgt1_p_0_ph                   <= #TP '0;
    r_radm_trgt1_p_0_st                   <= #TP '0;
    r_radm_trgt1_p_0_hdr_uppr_bytes_valid <= #TP '0;
    r_radm_trgt1_p_0_req_dma              <= #TP '0;
    r_radm_trgt1_p_0_req_dma_channel      <= #TP '0;
    r_radm_trgt1_p_0_reqtr_sgmt           <= #TP '0;
    r_radm_trgt1_p_0_dest_sgmt            <= #TP '0;
    r_radm_trgt1_p_0_mem_type             <= #TP '0;
    r_radm_trgt1_p_0_pkt_order_no         <= #TP '0;
  end else begin
    if(radm_trgt1_p_0_hv)begin
      r_radm_trgt1_p_0_hdr_prot             <= #TP radm_trgt1_p_0_hdr_prot;
      r_radm_trgt1_p_0_prfx                 <= #TP radm_trgt1_p_0_prfx;
      r_radm_trgt1_p_0_tlp_abort            <= #TP radm_trgt1_p_0_tlp_abort;
      r_radm_trgt1_p_0_fmt                  <= #TP radm_trgt1_p_0_fmt;
      r_radm_trgt1_p_0_type                 <= #TP radm_trgt1_p_0_type;
      r_radm_trgt1_p_0_tc                   <= #TP radm_trgt1_p_0_tc;
      r_radm_trgt1_p_0_attr                 <= #TP radm_trgt1_p_0_attr;
      r_radm_trgt1_p_0_reqid                <= #TP radm_trgt1_p_0_reqid;
      r_radm_trgt1_p_0_tag                  <= #TP radm_trgt1_p_0_tag;
      r_radm_trgt1_p_0_func_num             <= #TP radm_trgt1_p_0_func_num;
      r_radm_trgt1_p_0_td                   <= #TP radm_trgt1_p_0_td;
      r_radm_trgt1_p_0_poisoned             <= #TP radm_trgt1_p_0_poisoned;
      r_radm_trgt1_p_0_dw_len               <= #TP radm_trgt1_p_0_dw_len;
      r_radm_trgt1_p_0_first_be             <= #TP radm_trgt1_p_0_first_be;
      r_radm_trgt1_p_0_vc_num               <= #TP radm_trgt1_p_0_vc_num;
      r_radm_trgt1_p_0_addr                 <= #TP i_radm_trgt1_p_0_addr;
      r_radm_trgt1_p_0_hdr_uppr_bytes       <= #TP radm_trgt1_p_0_hdr_uppr_bytes;
      r_radm_trgt1_p_0_rom_in_range         <= #TP radm_trgt1_p_0_rom_in_range;
      r_radm_trgt1_p_0_io_req_in_range      <= #TP radm_trgt1_p_0_io_req_in_range;
      r_radm_trgt1_p_0_in_membar_range      <= #TP radm_trgt1_p_0_in_membar_range;
      r_radm_trgt1_p_0_last_be              <= #TP radm_trgt1_p_0_last_be;
      r_radm_trgt1_p_0_ats                  <= #TP radm_trgt1_p_0_ats;
      r_radm_trgt1_p_0_nw                   <= #TP radm_trgt1_p_0_nw;
      r_radm_trgt1_p_0_th                   <= #TP radm_trgt1_p_0_th;
      r_radm_trgt1_p_0_ph                   <= #TP radm_trgt1_p_0_ph;
      r_radm_trgt1_p_0_st                   <= #TP radm_trgt1_p_0_st;
      r_radm_trgt1_p_0_hdr_uppr_bytes_valid <= #TP radm_trgt1_p_0_hdr_uppr_bytes_valid;
      r_radm_trgt1_p_0_req_dma              <= #TP radm_trgt1_p_0_req_dma;
      r_radm_trgt1_p_0_req_dma_channel      <= #TP radm_trgt1_p_0_req_dma_channel;
      r_radm_trgt1_p_0_reqtr_sgmt           <= #TP radm_trgt1_p_0_reqtr_sgmt;
      r_radm_trgt1_p_0_dest_sgmt            <= #TP radm_trgt1_p_0_dest_sgmt;
      r_radm_trgt1_p_0_mem_type             <= #TP radm_trgt1_p_0_mem_type;
      r_radm_trgt1_p_0_pkt_order_no         <= #TP radm_trgt1_p_0_pkt_order_no;
    end
  end
end



  assign s_inbd_data_p                                                                                               = radm_trgt1_p_0_dv  ? i_radm_trgt1_p_0_data                                            : BUS_INIT; 

  assign s_errored_req                                                                                               = radm_trgt1_p_0_eot ? radm_trgt1_p_0_tlp_abort || radm_trgt1_p_0_dllp_abort : 1'b0;
  assign s_inbd_header_p_uppr_bytes                                                                                  = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_hdr_uppr_bytes       : r_radm_trgt1_p_0_hdr_uppr_bytes;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW] = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_hdr_uppr_bytes_valid : r_radm_trgt1_p_0_hdr_uppr_bytes_valid;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]                                     = radm_trgt1_p_0_hv;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]                                     = radm_trgt1_p_0_dv;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]                                   = radm_trgt1_p_0_eot;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_MEM_TYPE_HIGH:`INBD_HDR_PNP_RANGE_MEM_TYPE_LOW]                         = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_mem_type             : r_radm_trgt1_p_0_mem_type;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_BCM_HIGH:`INBD_HDR_PNP_RANGE_BCM_LOW]                                   = 1'b0;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW]                           = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_req_dma              : r_radm_trgt1_p_0_req_dma;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_LOW]                 = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_req_dma_channel      : r_radm_trgt1_p_0_req_dma_channel;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_REQ_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_REQ_SEGMENT_LOW]                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_reqtr_sgmt           : r_radm_trgt1_p_0_reqtr_sgmt;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_DST_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_DST_SEGMENT_LOW]                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_dest_sgmt            : r_radm_trgt1_p_0_dest_sgmt;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW]                       = radm_trgt1_p_0_eot ?   radm_trgt1_p_0_tlp_abort            : 1'b0;//radm_trgt1_p_0_hv  ? radm_trgt1_p_0_tlp_abort       : r_radm_trgt1_p_0_tlp_abort;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_LOW]                 = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_rom_in_range         : r_radm_trgt1_p_0_rom_in_range;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_REQID_HIGH:`INBD_HDR_PNP_RANGE_REQID_LOW]                               = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_reqid                : r_radm_trgt1_p_0_reqid;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_LOW]           = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_io_req_in_range      : r_radm_trgt1_p_0_io_req_in_range;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_LOW]           = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_in_membar_range      : r_radm_trgt1_p_0_in_membar_range;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW]                     = radm_trgt1_p_0_eot ?   radm_trgt1_p_0_ecrc_err             : 1'b0;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_DWEN_HIGH:`INBD_HDR_PNP_RANGE_DWEN_LOW]                                 = s_errored_req      ?  1 :
                                                                                                                       radm_trgt1_p_0_dv  ? (radm_trgt1_p_0_eot ? radm_trgt1_p_0_dwen : {NW{1'b1}}) : {NW{1'b0}};
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW]                     = radm_trgt1_p_0_eot ?   radm_trgt1_p_0_dllp_abort           : 1'b0;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_NW_HIGH:`INBD_HDR_PNP_RANGE_NW_LOW]                                     = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_nw                   : r_radm_trgt1_p_0_nw;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_CXLSRC_HIGH:`INBD_HDR_PNP_RANGE_CXLSRC_LOW]                             = 1'b0;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_ATS_HIGH:`INBD_HDR_PNP_RANGE_ATS_LOW]                                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_ats                  : r_radm_trgt1_p_0_ats;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]                                 = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_type                 : r_radm_trgt1_p_0_type;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TPH_SET_HIGH:`INBD_HDR_PNP_RANGE_TPH_SET_LOW]                           = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_st                   : r_radm_trgt1_p_0_st;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TPH_PH_HIGH :`INBD_HDR_PNP_RANGE_TPH_PH_LOW]                            = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_ph                   : r_radm_trgt1_p_0_ph;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TPH_TH_HIGH :`INBD_HDR_PNP_RANGE_TPH_TH_LOW]                            = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_th                   : r_radm_trgt1_p_0_th;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TD_HIGH:`INBD_HDR_PNP_RANGE_TD_LOW]                                     = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_td                   : r_radm_trgt1_p_0_td;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TLP_PRFX_HIGH:`INBD_HDR_PNP_RANGE_TLP_PRFX_LOW]                         = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_prfx                 : r_radm_trgt1_p_0_prfx;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_POISONED_HIGH:`INBD_HDR_PNP_RANGE_POISONED_LOW]                         = radm_trgt1_p_0_eot ?   radm_trgt1_p_0_poisoned             : 1'b0; //radm_trgt1_p_0_hv  ? radm_trgt1_p_0_poisoned        : r_radm_trgt1_p_0_poisoned;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]                           = s_errored_req      ? '0 :
                                                                                                                       radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_last_be              : r_radm_trgt1_p_0_last_be;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]                                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_fmt                  : r_radm_trgt1_p_0_fmt;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]                         = s_errored_req      ? '0 :
                                                                                                                       radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_first_be             : r_radm_trgt1_p_0_first_be;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW]                             = s_errored_req      ?  1 :
                                                                                                                       radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_dw_len               : r_radm_trgt1_p_0_dw_len;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW]                                 = radm_trgt1_p_0_hv  ? i_radm_trgt1_p_0_addr                 : r_radm_trgt1_p_0_addr;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TC_HIGH:`INBD_HDR_PNP_RANGE_TC_LOW]                                     = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_tc                   : r_radm_trgt1_p_0_tc;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]                         = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_func_num             : r_radm_trgt1_p_0_func_num;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_TAG_HIGH:`INBD_HDR_PNP_RANGE_TAG_LOW]                                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_tag                  : r_radm_trgt1_p_0_tag;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_ATTR_HIGH:`INBD_HDR_PNP_RANGE_ATTR_LOW]                                 = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_attr                 : r_radm_trgt1_p_0_attr;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]                       = '0;
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW]                 = 1'b0;  
  assign s_inbd_header_p[`INBD_HDR_PNP_RANGE_SEQ_HIGH:`INBD_HDR_PNP_RANGE_SEQ_LOW]                                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_pkt_order_no         : r_radm_trgt1_p_0_pkt_order_no;

  assign s_radm_trgt1_p_0_hdr_prot                                                                                   = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_hdr_prot             : r_radm_trgt1_p_0_hdr_prot;
  assign s_radm_trgt1_p_0_pkt_order_no                                                                               = radm_trgt1_p_0_hv  ?   radm_trgt1_p_0_pkt_order_no         : r_radm_trgt1_p_0_pkt_order_no;

  // assign trgt1_radm_intf_p_0_halt                                                                                       = ib_hf_p_f || ib_df_p_f; // radm_trgt_wr_mux || inbd_halt_pnp_wr;

  DWC_pcie_bridge_ib_scheduler_buf
  
  #(
     .SEGNUM                ( `CC_IB_SCHEDULER_P_REQ_NUM                )
    ,.SEGNUM_LOG2           ( `CC_IB_SCHEDULER_P_REQ_NUM_LOG2           )
    ,.SEGDEPTH              ( `CC_IB_SCHEDULER_P_REQ_DATA_SEG_DP        )
    ,.SEGDEPTH_LOG2         ( `CC_IB_SCHEDULER_P_REQ_DATA_SEG_DP_LOG2   )
    ,.P_NP_BUFFER           ( 1                                         )
    ,.RAM_REG_IN            ( `CC_IB_SCHEDULER_P_RAM_REGIN              )
    ,.RAM_RD_LATENCY        ( `CC_IB_SCHEDULER_P_RAM_RD_LATENCY         )
    ,.HDR_WD                ( `CC_IB_SCHEDULER_P_HDR_WD                 )
    ,.DATA_WD               ( `CC_IB_SCHEDULER_P_DATA_WD                )
    ,.HDR_WD_NP             ( `CC_IB_SCHEDULER_P_HDR_WD_NP              )
    ,.ADDR_WD_NP            ( `FLT_Q_ADDR_WIDTH                         )
    ,.DATA_WD_NP            ( `CC_IB_SCHEDULER_P_DATA_WD_NP             )
    ,.ADDR_WD               ( `CC_CORE_ADDR_BUS_WD                      )
    ,.DATA_BYTES            ( PCIE_CORE_DATA_BUS_WD/8                   )
    ,.HDR_RAM_ADDR_WD       ( `CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD        )
    ,.HDR_RAM_DATA_WD       ( `CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD        )
    ,.HDR_RAM_DEPTH         ( `CC_IB_SCHEDULER_P_HDR_RAM_DP             )
    ,.DATA_RAM_ADDR_WD      ( `CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD       )
    ,.DATA_RAM_DATA_WD      ( `CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD       )
    ,.DATA_RAM_DEPTH        ( `CC_IB_SCHEDULER_P_DATA_RAM_DP            )
    ,.NVC                   ( CX_NVC                                    )
    ,.NVC_WD                ( CX_NVC_LOG2                               )
    ,.NIDO_WD               ( 2                                         )
    ,.PSEQNUM_WD            ( 8                                         )
    ,.HDR_RAM_ECC_WD        ( `CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD -`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD_NOECC  )
    ,.DATA_RAM_ECC_WD       ( `CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD_NOECC )
    ,.RAS_RAM_PROT_RANGE    ( CX_RAS_RAM_PROT_RANGE                     )
    ,.RAS_PARITY_MODE       ( CX_RAS_PARITY_MODE                        )
    ,.HDR_RAS_DP_ID         ( `IB_SCH_AD_P_RAS_ID                       )
    ,.DT_RAS_DP_ID          ( `IB_SCH_DT_P_RAS_ID                       )
    ,.HQ_RAS_DP_ID          ( `HQ_RAS_RECC_CNT_P_RAS_ID                 )
    ,.DQ_RAS_DP_ID          ( `DQ_RAS_RECC_CNT_P_RAS_ID                 )
   ) u_p_buf  (
     .clk                         ( clk                                               )
    ,.rstn                        ( rstn                                              )

    ,.cfg_ax_mstr_np_pass_p       ( cfg_ax_mstr_np_pass_p                             )
    ,.cfg_enhanced_ordering_en    ( cfg_ax_mstr_ro_p_en                               )
    ,.trgt1_p_xfer_pend_per_vc    ( '0                                                )   
    ,.hdr_in                      ({s_inbd_header_p_uppr_bytes,
                                    s_inbd_header_p[DC_INBD_HEADER_PNP_1STG_WD-1:3]}  )
    ,.data_in                     ( s_inbd_data_p                                     )
    ,.pseq_num_in                 ( s_radm_trgt1_p_0_pkt_order_no                     )
    ,.hv_in                       ( radm_trgt1_p_0_hv                                 )
    ,.dv_in                       ( radm_trgt1_p_0_dv                                 )
    ,.eot_in                      ( radm_trgt1_p_0_eot                                )
    ,.halt_out                    ( trgt1_radm_intf_p_0_halt                          )
    ,.hdr_out                     ({ss_inbd_header_p_uppr_bytes,
                                    ss_inbd_header_p[DC_INBD_HEADER_PNP_1STG_WD-1:3]} )
    ,.data_out                    ( ss_inbd_data_p                                    )
    ,.hv_out                      ( ss_radm_trgt1_p_0_hv                              )
    ,.dv_out                      ( ss_radm_trgt1_p_0_dv                              )
    ,.eot_out                     ( ss_radm_trgt1_p_0_eot                             )
    ,.halt_in                     ((radm_trgt_wr_mux || inbd_halt_pnp_wr)             )

    ,.ibreq_presp_rpseq           ( ibreq_presp_rpseq                                 )
    ,.ibreq_cfg_rpseq             ( ibreq_presp_rpseq                                 )
    ,.last_req_pseq               ( r_last_req_pseq                                   )

    ,.hdr_ram_wea                 ( ib_scheduler_p_hdr_ram_wea                        )
    ,.hdr_ram_addra               ( ib_scheduler_p_hdr_ram_addra                      )
    ,.hdr_ram_dina                ( ib_scheduler_p_hdr_ram_dina                       )
    ,.hdr_ram_addrb               ( ib_scheduler_p_hdr_ram_addrb                      )
    ,.hdr_ram_enb                 ( ib_scheduler_p_hdr_ram_enb                        )
    ,.hdr_ram_doutb               ( ib_scheduler_p_hdr_ram_doutb                      )

    ,.data_ram_wea                ( ib_scheduler_p_data_ram_wea                       )
    ,.data_ram_addra              ( ib_scheduler_p_data_ram_addra                     )
    ,.data_ram_dina               ( ib_scheduler_p_data_ram_dina                      )
    ,.data_ram_addrb              ( ib_scheduler_p_data_ram_addrb                     )
    ,.data_ram_enb                ( ib_scheduler_p_data_ram_enb                       )
    ,.data_ram_doutb              ( ib_scheduler_p_data_ram_doutb                     )
    ,.axi_ras_par_ib_sch_ad_pulse ( axi_ras_par_ib_sch_p_ad_pulse                     )
    ,.axi_ras_par_ib_sch_dt_pulse ( axi_ras_par_ib_sch_p_dt_pulse                     )
    ,.cfg_hq_ras_recc_correct     ( cfg_sch_p_hdr_ras_recc_correct                    )
    ,.hq_ras_recc_corr_cnt_pulse  ( sch_p_hdr_ras_recc_corr_cnt_pulse                 )
    ,.hq_ras_recc_ucorr_cnt_pulse ( sch_p_hdr_ras_recc_ucorr_cnt_pulse                )
    ,.hq_ras_recc_cnt_addr        ( sch_p_hdr_ras_recc_cnt_addr                       )
    ,.cfg_dq_ras_recc_correct     ( cfg_sch_p_data_ras_recc_correct                   )
    ,.dq_ras_recc_corr_cnt_pulse  ( sch_p_data_ras_recc_corr_cnt_pulse                )
    ,.dq_ras_recc_ucorr_cnt_pulse ( sch_p_data_ras_recc_ucorr_cnt_pulse               )
    ,.dq_ras_recc_cnt_addr        ( sch_p_data_ras_recc_cnt_addr                      )
    ,.axi_ib_sch_ad_ras_dp_err_log   (axi_ib_sch_p_ad_ras_dp_err_log                  )
    ,.axi_ib_sch_dt_ras_dp_err_log   (axi_ib_sch_p_dt_ras_dp_err_log                  )
    ,.dq_ras_recc_cnt_ras_dp_err_log (sch_p_data_recc_corr_cnt_ras_dp_err_log         )
    ,.hq_ras_recc_cnt_ras_dp_err_log (sch_p_hdr_recc_corr_cnt_ras_dp_err_log          )
    ,.core_clk_ordrb_ras_dp_err_inj  (core_clk_ordrb_ras_dp_err_inj                   )
   );

  assign ss_inbd_header_p[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]   = ss_radm_trgt1_p_0_hv;
  assign ss_inbd_header_p[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]   = ss_radm_trgt1_p_0_dv;
  assign ss_inbd_header_p[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW] = ss_radm_trgt1_p_0_eot;

  assign radm_trgt1_np_0_mem_type = radm_trgt1_np_0_req_dma_mem_type ;


always@(posedge clk or negedge rstn) begin: SEQ_RADM_TRGT1_NP_0_PROC
  if(!rstn)begin
    r_radm_trgt1_np_0_hdr_prot             <= #TP '0;
    r_radm_trgt1_np_0_prfx                 <= #TP '0;
    r_radm_trgt1_np_0_tlp_abort            <= #TP '0;
    r_radm_trgt1_np_0_fmt                  <= #TP '0;
    r_radm_trgt1_np_0_type                 <= #TP '0;
    r_radm_trgt1_np_0_tc                   <= #TP '0;
    r_radm_trgt1_np_0_attr                 <= #TP '0;
    r_radm_trgt1_np_0_reqid                <= #TP '0;
    r_radm_trgt1_np_0_tag                  <= #TP '0;
    r_radm_trgt1_np_0_func_num             <= #TP '0;
    r_radm_trgt1_np_0_td                   <= #TP '0;
    r_radm_trgt1_np_0_poisoned             <= #TP '0;
    r_radm_trgt1_np_0_dw_len               <= #TP '0;
    r_radm_trgt1_np_0_first_be             <= #TP '0;
    r_radm_trgt1_np_0_vc_num               <= #TP '0;
    r_radm_trgt1_np_0_addr                 <= #TP '0;
    r_radm_trgt1_np_0_rom_in_range         <= #TP '0;
    r_radm_trgt1_np_0_io_req_in_range      <= #TP '0;
    r_radm_trgt1_np_0_in_membar_range      <= #TP '0;
    r_radm_trgt1_np_0_last_be              <= #TP '0;
    r_radm_trgt1_np_0_ats                  <= #TP '0;
    r_radm_trgt1_np_0_nw                   <= #TP '0;
    r_radm_trgt1_np_0_cxlsrc               <= #TP '0;
    r_radm_trgt1_np_0_th                   <= #TP '0;
    r_radm_trgt1_np_0_ph                   <= #TP '0;
    r_radm_trgt1_np_0_st                   <= #TP '0;
    r_radm_trgt1_np_0_req_dma              <= #TP '0;
    r_radm_trgt1_np_0_req_dma_channel      <= #TP '0;
    r_radm_trgt1_np_0_reqtr_sgmt           <= #TP '0;
    r_radm_trgt1_np_0_dest_sgmt            <= #TP '0;
    r_trgt_lookup_id                       <= #TP '0;
    r_radm_trgt1_np_0_pkt_order_no         <= #TP '0;
    r_radm_trgt1_np_0_mem_type             <= #TP '0;
  end else begin
    if(radm_trgt1_np_0_hv)begin
      r_radm_trgt1_np_0_hdr_prot             <= #TP   radm_trgt1_np_0_hdr_prot;
      r_radm_trgt1_np_0_prfx                 <= #TP   radm_trgt1_np_0_prfx;
      r_radm_trgt1_np_0_tlp_abort            <= #TP   radm_trgt1_np_0_tlp_abort;
      r_radm_trgt1_np_0_fmt                  <= #TP   radm_trgt1_np_0_fmt;
      r_radm_trgt1_np_0_type                 <= #TP   radm_trgt1_np_0_type;
      r_radm_trgt1_np_0_tc                   <= #TP   radm_trgt1_np_0_tc;
      r_radm_trgt1_np_0_attr                 <= #TP   radm_trgt1_np_0_attr;
      r_radm_trgt1_np_0_reqid                <= #TP   radm_trgt1_np_0_reqid;
      r_radm_trgt1_np_0_tag                  <= #TP   radm_trgt1_np_0_tag;
      r_radm_trgt1_np_0_func_num             <= #TP   radm_trgt1_np_0_func_num;
      r_radm_trgt1_np_0_td                   <= #TP   radm_trgt1_np_0_td;
      r_radm_trgt1_np_0_poisoned             <= #TP   radm_trgt1_np_0_poisoned;
      r_radm_trgt1_np_0_dw_len               <= #TP   radm_trgt1_np_0_dw_len;
      r_radm_trgt1_np_0_first_be             <= #TP   radm_trgt1_np_0_first_be;
      r_radm_trgt1_np_0_vc_num               <= #TP   radm_trgt1_np_0_vc_num;
      r_radm_trgt1_np_0_addr                 <= #TP i_radm_trgt1_np_0_addr;
      r_radm_trgt1_np_0_rom_in_range         <= #TP   radm_trgt1_np_0_rom_in_range;
      r_radm_trgt1_np_0_io_req_in_range      <= #TP   radm_trgt1_np_0_io_req_in_range;
      r_radm_trgt1_np_0_in_membar_range      <= #TP   radm_trgt1_np_0_in_membar_range;
      r_radm_trgt1_np_0_last_be              <= #TP   radm_trgt1_np_0_last_be;
      r_radm_trgt1_np_0_ats                  <= #TP   radm_trgt1_np_0_ats;
      r_radm_trgt1_np_0_nw                   <= #TP   radm_trgt1_np_0_nw;
      r_radm_trgt1_np_0_cxlsrc               <= #TP   radm_trgt1_np_0_cxlsrc;
      r_radm_trgt1_np_0_th                   <= #TP   radm_trgt1_np_0_th;
      r_radm_trgt1_np_0_ph                   <= #TP   radm_trgt1_np_0_ph;
      r_radm_trgt1_np_0_st                   <= #TP   radm_trgt1_np_0_st;
      r_radm_trgt1_np_0_req_dma              <= #TP   radm_trgt1_np_0_req_dma;
      r_radm_trgt1_np_0_req_dma_channel      <= #TP   radm_trgt1_np_0_req_dma_channel;
      r_radm_trgt1_np_0_reqtr_sgmt           <= #TP   radm_trgt1_np_0_reqtr_sgmt;
      r_radm_trgt1_np_0_dest_sgmt            <= #TP   radm_trgt1_np_0_dest_sgmt;
      r_trgt_lookup_id                       <= #TP   trgt_lookup_id;
      r_radm_trgt1_np_0_mem_type             <= #TP   radm_trgt1_np_0_mem_type;
      r_radm_trgt1_np_0_pkt_order_no         <= #TP   radm_trgt1_np_0_pkt_order_no;
    end
  end
end

  assign s_inbd_data_np                                                                                               = radm_trgt1_np_0_dv  ? i_radm_trgt1_np_0_data[`CC_IB_SCHEDULER_NP_DATA_WD-1:0] : BUS_INIT;
  //assign s_inbd_data_np                                                                                               = radm_trgt1_np_0_dv  ?   radm_trgt1_np_0_data[PCIE_CORE_DATA_BUS_WD-1:0]                 : '0;

  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW] = 1'b0;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]                                     = radm_trgt1_np_0_hv && radm_trgt1_np_0_dv ;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]                                     = radm_trgt1_np_0_dv;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]                                   = radm_trgt1_np_0_eot && radm_trgt1_np_0_dv ;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_MEM_TYPE_HIGH:`INBD_HDR_PNP_RANGE_MEM_TYPE_LOW]                         = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_mem_type             : r_radm_trgt1_np_0_mem_type;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_BCM_HIGH:`INBD_HDR_PNP_RANGE_BCM_LOW]                                   = 1'b0;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW]                           = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_req_dma              : r_radm_trgt1_np_0_req_dma;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_LOW]                 = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_req_dma_channel      : r_radm_trgt1_np_0_req_dma_channel;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_REQ_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_REQ_SEGMENT_LOW]                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_reqtr_sgmt           : r_radm_trgt1_np_0_reqtr_sgmt;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_DST_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_DST_SEGMENT_LOW]                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_dest_sgmt            : r_radm_trgt1_np_0_dest_sgmt;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW]                       = radm_trgt1_np_0_eot ?   radm_trgt1_np_0_tlp_abort            : 1'b0;//radm_trgt1_p_0_hv  ? radm_trgt1_p_0_tlp_abort       : r_radm_trgt1_p_0_tlp_abort;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_LOW]                 = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_rom_in_range         : r_radm_trgt1_np_0_rom_in_range;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_REQID_HIGH:`INBD_HDR_PNP_RANGE_REQID_LOW]                               = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_reqid                : r_radm_trgt1_np_0_reqid;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_LOW]           = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_io_req_in_range      : r_radm_trgt1_np_0_io_req_in_range;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_LOW]           = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_in_membar_range      : r_radm_trgt1_np_0_in_membar_range;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW]                     = radm_trgt1_np_0_eot ?   radm_trgt1_np_0_ecrc_err             : 1'b0;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_DWEN_HIGH:`INBD_HDR_PNP_RANGE_DWEN_LOW]                                 = radm_trgt1_np_0_dv  ?  (radm_trgt1_np_0_eot ? radm_trgt1_np_0_dwen : {NW{1'b1}}) : {NW{1'b0}};
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW]                     = radm_trgt1_np_0_eot ?   radm_trgt1_np_0_dllp_abort           : 1'b0;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_NW_HIGH:`INBD_HDR_PNP_RANGE_NW_LOW]                                     = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_nw                   : r_radm_trgt1_np_0_nw;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_CXLSRC_HIGH:`INBD_HDR_PNP_RANGE_CXLSRC_LOW]                             = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_cxlsrc               : r_radm_trgt1_np_0_cxlsrc;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_ATS_HIGH:`INBD_HDR_PNP_RANGE_ATS_LOW]                                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_ats                  : r_radm_trgt1_np_0_ats;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]                                 = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_type                 : r_radm_trgt1_np_0_type;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TPH_SET_HIGH:`INBD_HDR_PNP_RANGE_TPH_SET_LOW]                           = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_st                   : r_radm_trgt1_np_0_st;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TPH_PH_HIGH :`INBD_HDR_PNP_RANGE_TPH_PH_LOW]                            = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_ph                   : r_radm_trgt1_np_0_ph;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TPH_TH_HIGH :`INBD_HDR_PNP_RANGE_TPH_TH_LOW]                            = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_th                   : r_radm_trgt1_np_0_th;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TD_HIGH:`INBD_HDR_PNP_RANGE_TD_LOW]                                     = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_td                   : r_radm_trgt1_np_0_td;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TLP_PRFX_HIGH:`INBD_HDR_PNP_RANGE_TLP_PRFX_LOW]                         = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_prfx                 : r_radm_trgt1_np_0_prfx;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_POISONED_HIGH:`INBD_HDR_PNP_RANGE_POISONED_LOW]                         = radm_trgt1_np_0_eot ?   radm_trgt1_np_0_poisoned             : 1'b0; //radm_trgt1_p_0_hv  ? radm_trgt1_p_0_poisoned        : r_radm_trgt1_p_0_poisoned;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]                           = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_last_be              : r_radm_trgt1_np_0_last_be;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]                                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_fmt                  : r_radm_trgt1_np_0_fmt;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]                         = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_first_be             : r_radm_trgt1_np_0_first_be;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW]                             = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_dw_len               : r_radm_trgt1_np_0_dw_len;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW]                                 = radm_trgt1_np_0_hv  ? i_radm_trgt1_np_0_addr                 : r_radm_trgt1_np_0_addr;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TC_HIGH:`INBD_HDR_PNP_RANGE_TC_LOW]                                     = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_tc                   : r_radm_trgt1_np_0_tc;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]                         = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_func_num             : r_radm_trgt1_np_0_func_num;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_TAG_HIGH:`INBD_HDR_PNP_RANGE_TAG_LOW]                                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_tag                  : r_radm_trgt1_np_0_tag;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_ATTR_HIGH:`INBD_HDR_PNP_RANGE_ATTR_LOW]                                 = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_attr                 : r_radm_trgt1_np_0_attr;
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]                       = radm_trgt1_np_0_hv  ?   trgt_lookup_id[CX_REMOTE_MAX_TAGS_WD-1:0] : r_trgt_lookup_id[CX_REMOTE_MAX_TAGS_WD-1:0];
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW]                 = 1'b1;  
  assign s_inbd_header_np[`INBD_HDR_PNP_RANGE_SEQ_HIGH:`INBD_HDR_PNP_RANGE_SEQ_LOW]                                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_pkt_order_no         : r_radm_trgt1_np_0_pkt_order_no;



  assign s_radm_trgt1_np_0_hdr_prot                                                                                   = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_hdr_prot             : r_radm_trgt1_np_0_hdr_prot;
  assign s_radm_trgt1_np_0_pkt_order_no                                                                               = radm_trgt1_np_0_hv  ?   radm_trgt1_np_0_pkt_order_no         : r_radm_trgt1_np_0_pkt_order_no;

  //assign trgt1_radm_intf_np_0_halt                                                                                      = ib_hf_np_f || ib_df_np_f; // radm_trgt1_np_0_dv ? (!radm_trgt_wr_mux || inbd_halt_pnp_wr) : inbd_halt_pnp_rd;

wire ss_inbd_halt_np;

assign ss_inbd_halt_np = ss_radm_trgt1_np_0_dv ? (!radm_trgt_wr_mux || inbd_halt_pnp_wr) : inbd_halt_pnp_rd;

  DWC_pcie_bridge_ib_scheduler_buf
  
  #(
     .SEGNUM                ( `CC_IB_SCHEDULER_NP_REQ_NUM                )
    ,.SEGNUM_LOG2           ( `CC_IB_SCHEDULER_NP_REQ_NUM_LOG2           )
    ,.SEGDEPTH              ( `CC_IB_SCHEDULER_NPW_REQ_DATA_SEG_DP       )
    ,.SEGDEPTH_LOG2         ( `CC_IB_SCHEDULER_NPW_REQ_DATA_SEG_DP_LOG2  )
    ,.P_NP_BUFFER           ( 0                                          )
    ,.RAM_REG_IN            ( `CC_IB_SCHEDULER_NP_RAM_REGIN              )
    ,.RAM_RD_LATENCY        ( `CC_IB_SCHEDULER_NP_RAM_RD_LATENCY         )
    ,.HDR_WD                ( `CC_IB_SCHEDULER_NP_HDR_WD                 )
    ,.DATA_WD               ( `CC_IB_SCHEDULER_NP_DATA_WD                )
    ,.HDR_WD_NP             ( `CC_IB_SCHEDULER_NP_HDR_WD_NP              )
    ,.ADDR_WD_NP            ( `FLT_Q_ADDR_WIDTH                          )
    ,.DATA_WD_NP            ( `CC_IB_SCHEDULER_NP_DATA_WD_NP             )
    ,.ADDR_WD               ( `CC_CORE_ADDR_BUS_WD                       )
    ,.DATA_BYTES            ( `CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD_NOECC/8)
    ,.HDR_RAM_ADDR_WD       ( `CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD        )
    ,.HDR_RAM_DATA_WD       ( `CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD        )
    ,.HDR_RAM_DEPTH         ( `CC_IB_SCHEDULER_NP_HDR_RAM_DP             )
    ,.DATA_RAM_ADDR_WD      ( `CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD       )
    ,.DATA_RAM_DATA_WD      ( `CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD       )
    ,.DATA_RAM_DEPTH        ( `CC_IB_SCHEDULER_NP_DATA_RAM_DP            )
    ,.NVC                   ( CX_NVC                                     )
    ,.NVC_WD                ( CX_NVC_LOG2                                )
    ,.NIDO_WD               ( 2                                          )
    ,.PSEQNUM_WD            ( 8                                          )
    ,.HDR_RAM_ECC_WD        ( `CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD -`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD_NOECC  )
    ,.DATA_RAM_ECC_WD       ( `CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD_NOECC )
    ,.RAS_RAM_PROT_RANGE    ( CX_RAS_RAM_PROT_RANGE                      )
    ,.RAS_PARITY_MODE       ( CX_RAS_PARITY_MODE                         )
    ,.HDR_RAS_DP_ID         ( `IB_SCH_AD_NP_RAS_ID                       )
    ,.DT_RAS_DP_ID          ( `IB_SCH_DT_NP_RAS_ID                       )
    ,.HQ_RAS_DP_ID          ( `HQ_RAS_RECC_CNT_NP_RAS_ID                 )
    ,.DQ_RAS_DP_ID          ( `DQ_RAS_RECC_CNT_NP_RAS_ID                 )
   ) u_np_buf  (
     .clk                         ( clk                                               )
    ,.rstn                        ( rstn                                              )

    ,.cfg_ax_mstr_np_pass_p       ( cfg_ax_mstr_np_pass_p                             )
    ,.cfg_enhanced_ordering_en    ( 1'b1                                              )
    ,.trgt1_p_xfer_pend_per_vc    ( trgt1_p_xfer_pend_per_vc                          )   
    ,.hdr_in                      ( s_inbd_header_np[DC_INBD_HEADER_PNP_1STG_WD-1:3]  )
    ,.data_in                     ( s_inbd_data_np                                    )
    ,.pseq_num_in                 ( s_radm_trgt1_np_0_pkt_order_no                    )
    ,.hv_in                       ( radm_trgt1_np_0_hv                                )
    ,.dv_in                       ( radm_trgt1_np_0_dv                                )
    ,.eot_in                      ( radm_trgt1_np_0_eot                               )
    ,.halt_out                    ( trgt1_radm_intf_np_0_halt                         )

    ,.hdr_out                     ( ss_inbd_header_np[DC_INBD_HEADER_PNP_1STG_WD-1:3] )
    ,.data_out                    ( ss_inbd_data_np                                   )
    ,.hv_out                      ( ss_radm_trgt1_np_0_hv                             )
    ,.dv_out                      ( ss_radm_trgt1_np_0_dv                             )
    ,.eot_out                     ( ss_radm_trgt1_np_0_eot                            )
    ,.halt_in                     ( ss_inbd_halt_np                                   )

    ,.hdr_ram_wea                 ( ib_scheduler_np_hdr_ram_wea                       )
    ,.hdr_ram_addra               ( ib_scheduler_np_hdr_ram_addra                     )
    ,.hdr_ram_dina                ( ib_scheduler_np_hdr_ram_dina                      )
    ,.hdr_ram_addrb               ( ib_scheduler_np_hdr_ram_addrb                     )
    ,.hdr_ram_enb                 ( ib_scheduler_np_hdr_ram_enb                       )
    ,.hdr_ram_doutb               ( ib_scheduler_np_hdr_ram_doutb                     )

    ,.ibreq_presp_rpseq           ( ibreq_presp_rpseq                                 )
    ,.ibreq_cfg_rpseq             ( ibreq_cfg_rpseq                                   )
    ,.last_req_pseq               ( r_last_req_pseq                                   )

    ,.data_ram_wea                ( ib_scheduler_np_data_ram_wea                      )
    ,.data_ram_addra              ( ib_scheduler_np_data_ram_addra                    )
    ,.data_ram_dina               ( ib_scheduler_np_data_ram_dina                     )
    ,.data_ram_addrb              ( ib_scheduler_np_data_ram_addrb                    )
    ,.data_ram_enb                ( ib_scheduler_np_data_ram_enb                      )
    ,.data_ram_doutb              ( ib_scheduler_np_data_ram_doutb                    )
    ,.axi_ras_par_ib_sch_ad_pulse ( axi_ras_par_ib_sch_np_ad_pulse                    )
    ,.axi_ras_par_ib_sch_dt_pulse ( axi_ras_par_ib_sch_np_dt_pulse                    )
    ,.cfg_hq_ras_recc_correct     ( cfg_sch_np_hdr_ras_recc_correct                   )
    ,.hq_ras_recc_corr_cnt_pulse  ( sch_np_hdr_ras_recc_corr_cnt_pulse                )
    ,.hq_ras_recc_ucorr_cnt_pulse ( sch_np_hdr_ras_recc_ucorr_cnt_pulse               )
    ,.hq_ras_recc_cnt_addr        ( sch_np_hdr_ras_recc_cnt_addr                      )
    ,.cfg_dq_ras_recc_correct     ( cfg_sch_np_data_ras_recc_correct                  )
    ,.dq_ras_recc_corr_cnt_pulse  ( sch_np_data_ras_recc_corr_cnt_pulse               )
    ,.dq_ras_recc_ucorr_cnt_pulse ( sch_np_data_ras_recc_ucorr_cnt_pulse              )
    ,.dq_ras_recc_cnt_addr        ( sch_np_data_ras_recc_cnt_addr                     )
    ,.axi_ib_sch_ad_ras_dp_err_log   (axi_ib_sch_np_ad_ras_dp_err_log                 )
    ,.axi_ib_sch_dt_ras_dp_err_log   (axi_ib_sch_np_dt_ras_dp_err_log                 )
    ,.dq_ras_recc_cnt_ras_dp_err_log (sch_np_data_recc_corr_cnt_ras_dp_err_log        )
    ,.hq_ras_recc_cnt_ras_dp_err_log (sch_np_hdr_recc_corr_cnt_ras_dp_err_log         )
    ,.core_clk_ordrb_ras_dp_err_inj  (core_clk_ordrb_ras_dp_err_inj                   )

   );

  assign ss_inbd_header_np[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]   = ss_radm_trgt1_np_0_hv;
  assign ss_inbd_header_np[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]   = ss_radm_trgt1_np_0_dv;
  assign ss_inbd_header_np[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW] = ss_radm_trgt1_np_0_eot;

  localparam WR_MUX_SEL  = 2'b00;
  localparam WR_MUX_P    = 2'b01;
  localparam WR_MUX_NP   = 2'b10;
  
  always@(*) begin: COMB_WR_MUX_PROC
    next_wr_mux_state = WR_MUX_SEL;
    radm_trgt_wr_mux  = 0;          // if no request available change priority to P while waiting
    
    case(wr_mux_state)
      WR_MUX_SEL : begin
                     if (ss_radm_trgt1_p_0_hv) begin
                       if(ss_radm_trgt1_np_0_hv && ss_radm_trgt1_np_0_dv && !r_last_wr_type)begin // if last WR was P and there is an NP waiting grant priority to NP 
                         radm_trgt_wr_mux = 1;
                         if(!ss_radm_trgt1_np_0_eot || inbd_halt_pnp_wr)begin
                           next_wr_mux_state = WR_MUX_NP;
                         end else begin
                           next_wr_mux_state = WR_MUX_SEL;
                         end
                       end else begin                                   // if last WR was NP or there is no NP waiting grant priority to P
                         radm_trgt_wr_mux = 0;
                         if(!ss_radm_trgt1_p_0_eot || inbd_halt_pnp_wr)begin
                           next_wr_mux_state = WR_MUX_P;
                         end else begin
                           next_wr_mux_state = WR_MUX_SEL;
                         end
                       end
                     end else if(ss_radm_trgt1_np_0_hv && ss_radm_trgt1_np_0_dv)begin            // if there is no P waiting grant priority to NP
                       radm_trgt_wr_mux = 1;
                       if(!ss_radm_trgt1_np_0_eot || inbd_halt_pnp_wr)begin
                         next_wr_mux_state = WR_MUX_NP;
                       end else begin
                         next_wr_mux_state = WR_MUX_SEL;
                       end
                     end     
                   end
      WR_MUX_P   : begin
                     radm_trgt_wr_mux = 0;
                     if (ss_radm_trgt1_p_0_eot && !inbd_halt_pnp_wr) begin
                       next_wr_mux_state = WR_MUX_SEL;
                     end else begin
                       next_wr_mux_state = WR_MUX_P;
                     end
                   end
      WR_MUX_NP  : begin
                     radm_trgt_wr_mux = 1;
                     if (ss_radm_trgt1_np_0_eot && !inbd_halt_pnp_wr)
                       next_wr_mux_state = WR_MUX_SEL;
                     else
                       next_wr_mux_state = WR_MUX_NP;
                   end
      default    : next_wr_mux_state = WR_MUX_SEL;
    endcase

  end

  always @(posedge clk or negedge rstn)  begin: SEQ_WR_MUX_PROC
    if(!rstn)begin
      wr_mux_state   <= #TP WR_MUX_SEL;
      r_last_wr_type <= #TP 1'b0;
    end else begin
      wr_mux_state   <= #TP next_wr_mux_state;
      r_last_wr_type <= #TP radm_trgt_wr_mux;
    end
  end

  generate
    if (CORE_DATA_BUS_WD > `CC_IB_SCHEDULER_NP_DATA_WD) begin
      assign inbd_data_pnp_wr               = radm_trgt_wr_mux ? {{CC_PCIE_CORE_NUM_BYTES-(`CC_IB_SCHEDULER_NP_DATA_WD/9){INIT_BYTE}} ,ss_inbd_data_np}  : ss_inbd_data_p;
    end else begin
      assign inbd_data_pnp_wr               = radm_trgt_wr_mux ? ss_inbd_data_np : ss_inbd_data_p;
    end
  endgenerate

   assign inbd_header_pnp_wr_uppr_bytes = radm_trgt_wr_mux ? '0                : ss_inbd_header_p_uppr_bytes;
   assign inbd_header_pnp_wr            = radm_trgt_wr_mux ? (ss_radm_trgt1_np_0_dv ? ss_inbd_header_np : '0) : ss_inbd_header_p;


   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]                                     = ss_radm_trgt1_np_0_hv  && !ss_radm_trgt1_np_0_dv;
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_DV_HIGH: `INBD_HDR_PNP_RANGE_DV_LOW]                                    = ss_radm_trgt1_np_0_dv;
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]                                   = ss_radm_trgt1_np_0_eot && !ss_radm_trgt1_np_0_dv;
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_DWEN_HIGH:`INBD_HDR_PNP_RANGE_DWEN_LOW]                                 = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_DWEN_HIGH:`INBD_HDR_PNP_RANGE_DWEN_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW]                     = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW]                       = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW]                     = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]                                   = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]                                 = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TC_HIGH:`INBD_HDR_PNP_RANGE_TC_LOW]                                     = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TC_HIGH:`INBD_HDR_PNP_RANGE_TC_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_ATTR_HIGH:`INBD_HDR_PNP_RANGE_ATTR_LOW]                                 = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_ATTR_HIGH:`INBD_HDR_PNP_RANGE_ATTR_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW] = 1'b0;
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_ATS_HIGH:`INBD_HDR_PNP_RANGE_ATS_LOW]                                   = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_ATS_HIGH:`INBD_HDR_PNP_RANGE_ATS_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_NW_HIGH:`INBD_HDR_PNP_RANGE_NW_LOW]                                     = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_NW_HIGH:`INBD_HDR_PNP_RANGE_NW_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_CXLSRC_HIGH:`INBD_HDR_PNP_RANGE_CXLSRC_LOW]                             = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_CXLSRC_HIGH:`INBD_HDR_PNP_RANGE_CXLSRC_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_REQID_HIGH:`INBD_HDR_PNP_RANGE_REQID_LOW]                               = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_REQID_HIGH:`INBD_HDR_PNP_RANGE_REQID_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TAG_HIGH:`INBD_HDR_PNP_RANGE_TAG_LOW]                                   = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TAG_HIGH:`INBD_HDR_PNP_RANGE_TAG_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]                       = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]                         = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TD_HIGH:`INBD_HDR_PNP_RANGE_TD_LOW]                                     = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TD_HIGH:`INBD_HDR_PNP_RANGE_TD_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_POISONED_HIGH:`INBD_HDR_PNP_RANGE_POISONED_LOW]                         = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_POISONED_HIGH:`INBD_HDR_PNP_RANGE_POISONED_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW]                             = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]                         = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW]                                 = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_LOW]                 = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_LOW]           = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_LOW]           = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]                           = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TLP_PRFX_HIGH:`INBD_HDR_PNP_RANGE_TLP_PRFX_LOW]                         = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TLP_PRFX_HIGH:`INBD_HDR_PNP_RANGE_TLP_PRFX_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TPH_SET_HIGH:`INBD_HDR_PNP_RANGE_TPH_SET_LOW]                           = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TPH_SET_HIGH:`INBD_HDR_PNP_RANGE_TPH_SET_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TPH_PH_HIGH :`INBD_HDR_PNP_RANGE_TPH_PH_LOW]                            = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TPH_PH_HIGH :`INBD_HDR_PNP_RANGE_TPH_PH_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_TPH_TH_HIGH :`INBD_HDR_PNP_RANGE_TPH_TH_LOW]                            = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_TPH_TH_HIGH :`INBD_HDR_PNP_RANGE_TPH_TH_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_MEM_TYPE_HIGH:`INBD_HDR_PNP_RANGE_MEM_TYPE_LOW]                         = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_MEM_TYPE_HIGH:`INBD_HDR_PNP_RANGE_MEM_TYPE_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_BCM_HIGH:`INBD_HDR_PNP_RANGE_BCM_LOW]                                   = 1'b0;

   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW]                           = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_LOW]                 = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH: `INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW]                = 1'b1;
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_SEQ_HIGH:`INBD_HDR_PNP_RANGE_SEQ_LOW]                                   = '0;

   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_REQ_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_REQ_SEGMENT_LOW]                   = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_REQ_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_REQ_SEGMENT_LOW];
   assign inbd_header_pnp_rd[`INBD_HDR_PNP_RANGE_DST_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_DST_SEGMENT_LOW]                   = ss_inbd_header_np[`INBD_HDR_PNP_RANGE_DST_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_DST_SEGMENT_LOW];



    ras_dp_pipe
     #(
      .PIPELINE_TYPE             (0                             ),
      .RESETVAL                  (0                             ),
      .N_STAGES                  (0                             ),
      .CAN_STALL                 (0                             ),
      .RESET_STALL               (0                             ),
      .BUS_PROTECT_GEN_EN        (0                             ),
      .BUS_PROTECT_CHK_EN        (1                             ),
      .PROT_TYPE                 (1                             ), //0: ECC, 1: Parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE             ),
      .PROT_WD                   (RADM_RASDP_TRGT1_P_HDR_PROT_WD),
      .PARITY_MODE               (CX_RAS_PARITY_MODE            ),
      .PROT_CORRECT_EN           (0                             ),
      .TOTAL_WIDTH               (RADM_RASDP_TRGT1_P_HDR_WD     ),
      .EXCLUDE_PROT_WIDTH        (0                             ),
      .RAS_DP_PROT_CHK_ID_BASE   (`RTRGT_P_AD_RAS_ID            )
    ) u_chktrgt_p_0_hdr (
      .clk                       (clk                                 ),
      .rst_n                     (rstn                                ),
      .din                       (
                                  {
                                   radm_trgt1_p_0_hdr_uppr_bytes[`FLT_Q_ADDR_WIDTH-1:0],
                                   radm_trgt1_p_0_pkt_order_no,
                                   radm_trgt1_p_0_hdr_uppr_bytes_valid,
                                   radm_trgt1_p_0_ph,
                                   radm_trgt1_p_0_st,
                                   radm_trgt1_p_0_dest_sgmt,
                                   radm_trgt1_p_0_reqtr_sgmt,
                                   radm_trgt1_p_0_last_be,
                                   radm_trgt1_p_0_ats,
                                   radm_trgt1_p_0_poisoned,
                                   radm_trgt1_p_0_th,
                                   radm_trgt1_p_0_td,
                                   radm_trgt1_p_0_addr,
                                   radm_trgt1_p_0_first_be,
                                   radm_trgt1_p_0_rom_in_range,
                                   radm_trgt1_p_0_in_membar_range,
                                   radm_trgt1_p_0_dw_len,
                                   radm_trgt1_p_0_cpl_status,
                                   radm_trgt1_p_0_func_num,
                                   radm_trgt1_p_0_tag,
                                   radm_trgt1_p_0_reqid,
                                   radm_trgt1_p_0_attr,
                                   radm_trgt1_p_0_tc,
                                   radm_trgt1_p_0_type,
                                   radm_trgt1_p_0_fmt
                                  }
                                                                      ),
      .din_prot                  ( radm_trgt1_p_0_hdr_prot            ),
      .dout                      ( /* not connected */                ),
      .dout_prot                 ( /* not connected */                ),
      .en                        (1'b1                                ),
      .bypass                    (1'b0                                ),
      .stall                     (1'b0                                ),
      .stallout                  ( /* not connected */                ),
      .valid_in                  ( radm_trgt1_p_0_hv                  ),
      .halt_out                  ( /* not connected */                ),
      .valid_out                 ( /* not connected */                ),
      .halt_in                   (1'b0                                ),
      .ras_dp_err_inband_kbd_in  (1'b0                                ),
      .ras_dp_err_inband_kbd_out ( /* not connected */                ),
      .ras_dp_err_log            ( axi_rtrgt_p_ad_ras_dp_err_log      )
        ,
        .ras_dp_err_inj          ( core_clk_ordrb_ras_dp_err_inj      )
      );

   assign axi_ras_par_rtrgt_p_ad_pulse = axi_rtrgt_p_ad_ras_dp_err_log.valid;

    ras_dp_pipe
     #(
      .PIPELINE_TYPE             (0                            ),
      .RESETVAL                  (0                            ),
      .N_STAGES                  (0                            ),
      .CAN_STALL                 (0                            ),
      .RESET_STALL               (0                            ),
      .BUS_PROTECT_GEN_EN        (0                            ),
      .BUS_PROTECT_CHK_EN        (1                            ),
      .PROT_TYPE                 (1                            ), //0: ECC, 1: Parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
      .PROT_WD                   (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD),
      .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
      .PROT_CORRECT_EN           (0                            ),
      .TOTAL_WIDTH               (PCIE_CORE_DATA_BUS_WD        ),
      .EXCLUDE_PROT_WIDTH        (0                            ),
      .RAS_DP_PROT_CHK_ID_BASE   (`RTRGT_P_DT_RAS_ID           )
    ) u_chktrgt_p_0_data (
      .clk                       (clk                          ),
      .rst_n                     (rstn                         ),
      .din                       (radm_trgt1_p_0_data[PCIE_CORE_DATA_BUS_WD-1:0]),
      .din_prot                  (radm_trgt1_p_0_data[CORE_DATA_BUS_WD-1:PCIE_CORE_DATA_BUS_WD]),
      .dout                      ( /* not connected */         ),
      .dout_prot                 ( /* not connected */         ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  ( /* not connected */         ),
      .valid_in                  (radm_trgt1_p_0_dv            ),
      .halt_out                  ( /* not connected */         ),
      .valid_out                 ( /* not connected */         ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out ( /* not connected */         ),
      .ras_dp_err_log            (axi_rtrgt_p_dt_ras_dp_err_log)
        ,
        .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj)
      );

   assign axi_ras_par_rtrgt_p_dt_pulse = axi_rtrgt_p_dt_ras_dp_err_log.valid;


    ras_dp_pipe
     #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (0                              ),
      .BUS_PROTECT_CHK_EN        (1                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
      .PROT_WD                   (RADM_RASDP_TRGT1_NP_HDR_PROT_WD),
      .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (RADM_RASDP_TRGT1_NP_HDR_WD     ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (`RTRGT_NP_AD_RAS_ID            )
    ) u_chktrgt_np_0_hdr (
      .clk                       (clk                                 ),
      .rst_n                     (rstn                                ),
      .din                       (
                                  {
                                   radm_trgt1_np_0_pkt_order_no,
                                   radm_trgt1_np_0_nw,
                                   radm_trgt1_np_0_cxlsrc,
                                   radm_trgt1_np_0_ph,
                                   radm_trgt1_np_0_st,
                                   radm_trgt1_np_0_dest_sgmt,
                                   radm_trgt1_np_0_reqtr_sgmt,
                                   radm_trgt1_np_0_last_be,
                                   radm_trgt1_np_0_ats,
                                   radm_trgt1_np_0_poisoned,
                                   radm_trgt1_np_0_th,
                                   radm_trgt1_np_0_td,
                                   radm_trgt1_np_0_addr,
                                   radm_trgt1_np_0_first_be,
                                   radm_trgt1_np_0_io_req_in_range,
                                   radm_trgt1_np_0_rom_in_range,
                                   radm_trgt1_np_0_in_membar_range,
                                   radm_trgt1_np_0_dw_len,
                                   radm_trgt1_np_0_cpl_status,
                                   radm_trgt1_np_0_func_num,
                                   radm_trgt1_np_0_tag,
                                   radm_trgt1_np_0_reqid,
                                   radm_trgt1_np_0_attr,
                                   radm_trgt1_np_0_tc,
                                   radm_trgt1_np_0_type,
                                   radm_trgt1_np_0_fmt
                                  }
                                                                      ),
      .din_prot                  (radm_trgt1_np_0_hdr_prot            ),
      .dout                      ( /* not connected */                ),
      .dout_prot                 ( /* not connected */                ),
      .en                        (1'b1                                ),
      .bypass                    (1'b0                                ),
      .stall                     (1'b0                                ),
      .stallout                  ( /* not connected */                ),
      .valid_in                  ( radm_trgt1_np_0_hv                 ),
      .halt_out                  ( /* not connected */                ),
      .valid_out                 ( /* not connected */                ),
      .halt_in                   (1'b0                                ),
      .ras_dp_err_inband_kbd_in  (1'b0                                ),
      .ras_dp_err_inband_kbd_out ( /* not connected */                ),
      .ras_dp_err_log            ( axi_rtrgt_np_ad_ras_dp_err_log     )
        ,
        .ras_dp_err_inj          ( core_clk_ordrb_ras_dp_err_inj      )
      );

   assign axi_ras_par_rtrgt_np_ad_pulse = axi_rtrgt_np_ad_ras_dp_err_log.valid;


    ras_dp_pipe
     #(
      .PIPELINE_TYPE             (0                            ),
      .RESETVAL                  (0                            ),
      .N_STAGES                  (0                            ),
      .CAN_STALL                 (0                            ),
      .RESET_STALL               (0                            ),
      .BUS_PROTECT_GEN_EN        (0                            ),
      .BUS_PROTECT_CHK_EN        (1                            ),
      .PROT_TYPE                 (1                            ), //0: ECC, 1: Parity
      .PROT_RANGE                (CX_RAS_PROT_RANGE            ),
      .PROT_WD                   (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD),
      .PARITY_MODE               (CX_RAS_PARITY_MODE           ),
      .PROT_CORRECT_EN           (0                            ),
      .TOTAL_WIDTH               (PCIE_CORE_DATA_BUS_WD        ),
      .EXCLUDE_PROT_WIDTH        (0                            ),
      .RAS_DP_PROT_CHK_ID_BASE   (`RTRGT_NP_DT_RAS_ID          )
    ) u_chktrgt_np_0_data (
      .clk                       (clk                          ),
      .rst_n                     (rstn                         ),
      .din                       (radm_trgt1_np_0_data[PCIE_CORE_DATA_BUS_WD-1:0]),
      .din_prot                  (radm_trgt1_np_0_data[CORE_DATA_BUS_WD-1:PCIE_CORE_DATA_BUS_WD]),
      .dout                      ( /* not connected */         ),
      .dout_prot                 ( /* not connected */         ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  ( /* not connected */         ),
      .valid_in                  (radm_trgt1_np_0_dv           ),
      .halt_out                  ( /* not connected */         ),
      .valid_out                 ( /* not connected */         ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out ( /* not connected */         ),
      .ras_dp_err_log            (axi_rtrgt_np_dt_ras_dp_err_log)
        ,
        .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj)
      );

   assign axi_ras_par_rtrgt_np_dt_pulse = axi_rtrgt_np_dt_ras_dp_err_log.valid;


    ras_dp_pipe
     #(
      .PIPELINE_TYPE           (0                               ),
      .RESETVAL                (0                               ),
      .N_STAGES                (0                               ),
      .CAN_STALL               (0                               ),
      .RESET_STALL             (0                               ),
      .BUS_PROTECT_GEN_EN      (0                               ),
      .BUS_PROTECT_CHK_EN      (1                               ),
      .PROT_TYPE               (1                               ), //0: ECC, 1: Parity
      .PROT_RANGE              (CX_RAS_PROT_RANGE               ),
      .PROT_WD                 (RADM_RASDP_TRGT1_CPL_HDR_PROT_WD),
      .PARITY_MODE             (CX_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN         (0                               ),
      .TOTAL_WIDTH             (RADM_RASDP_TRGT1_CPL_HDR_WD     ),
      .EXCLUDE_PROT_WIDTH      (0                               ),
      .RAS_DP_PROT_CHK_ID_BASE (`RTRGT_CPL_AD_RAS_ID            )
    ) u_chktrgt_cpl_0_hdr (
      .clk                       (clk                          ),
      .rst_n                     (rstn                         ),
      .din                       (
                                  {
                                   radm_trgt1_cpl_0_pkt_order_no,
                                   radm_trgt1_cpl_0_cpl_sgmt,
                                   radm_trgt1_cpl_0_dest_sgmt,
                                   radm_trgt1_cpl_0_last,
                                   radm_trgt1_cpl_0_poisoned,
                                   radm_trgt1_cpl_0_td,
                                   radm_trgt1_cpl_0_addr[`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0],
                                   radm_trgt1_cpl_0_bcm,
                                   radm_trgt1_cpl_0_cmpltr_id,
                                   radm_trgt1_cpl_0_byte_cnt,
                                   radm_trgt1_cpl_0_dw_len,
                                   radm_trgt1_cpl_0_cpl_status,
                                   radm_trgt1_cpl_0_func_num,
                                   radm_trgt1_cpl_0_tag,
                                   radm_trgt1_cpl_0_reqid,
                                   radm_trgt1_cpl_0_attr,
                                   radm_trgt1_cpl_0_tc,
                                   radm_trgt1_cpl_0_type,
                                   radm_trgt1_cpl_0_fmt
                                  }
                                                                      ),
      .din_prot                  ( radm_trgt1_cpl_0_hdr_prot          ),
      .dout                      ( /* not connected */                ),
      .dout_prot                 ( /* not connected */                ),
      .en                        ( 1'b1                               ),
      .bypass                    ( 1'b0                               ),
      .stall                     ( 1'b0                               ),
      .stallout                  ( /* not connected */                ),
      .valid_in                  ( radm_trgt1_cpl_0_hv                ),
      .halt_out                  ( /* not connected */                ),
      .valid_out                 ( /* not connected */                ),
      .halt_in                   ( 1'b0                               ),
      .ras_dp_err_inband_kbd_in  ( 1'b0                               ),
      .ras_dp_err_inband_kbd_out ( /* not connected */                ),
      .ras_dp_err_log            ( axi_rtrgt_cpl_ad_ras_dp_err_log    )
        ,
        .ras_dp_err_inj          ( core_clk_ordrb_ras_dp_err_inj      )
      );

   assign axi_ras_par_rtrgt_cpl_ad_pulse = axi_rtrgt_cpl_ad_ras_dp_err_log.valid;


    ras_dp_pipe
     #(
      .PIPELINE_TYPE           (0                       ),
      .RESETVAL                (0                       ),
      .N_STAGES                (0                       ),
      .CAN_STALL               (0                       ),
      .RESET_STALL             (0                       ),
      .BUS_PROTECT_GEN_EN      (0                       ),
      .BUS_PROTECT_CHK_EN      (1                       ),
      .PROT_TYPE               (1                       ), //0: ECC, 1: Parity
      .PROT_RANGE              (CX_RAS_PROT_RANGE       ),
      .PROT_WD                 (CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD),
      .PARITY_MODE             (CX_RAS_PARITY_MODE      ),
      .PROT_CORRECT_EN         (0                       ),
      .TOTAL_WIDTH             (PCIE_CORE_DATA_BUS_WD   ),
      .EXCLUDE_PROT_WIDTH      (0                       ),
      .RAS_DP_PROT_CHK_ID_BASE (`RTRGT_CPL_DT_RAS_ID    )
    ) u_chktrgt_cpl_0_data (
      .clk                       (clk                          ),
      .rst_n                     (rstn                         ),
      .din                       (radm_trgt1_cpl_0_data[PCIE_CORE_DATA_BUS_WD-1:0]),
      .din_prot                  (radm_trgt1_cpl_0_data[CORE_DATA_BUS_WD-1:PCIE_CORE_DATA_BUS_WD]),
      .dout                      ( /* not connected */         ),
      .dout_prot                 ( /* not connected */         ),
      .en                        (1'b1                         ),
      .bypass                    (1'b0                         ),
      .stall                     (1'b0                         ),
      .stallout                  ( /* not connected */         ),
      .valid_in                  (radm_trgt1_cpl_0_dv          ),
      .halt_out                  ( /* not connected */         ),
      .valid_out                 ( /* not connected */         ),
      .halt_in                   (1'b0                         ),
      .ras_dp_err_inband_kbd_in  (1'b0                         ),
      .ras_dp_err_inband_kbd_out ( /* not connected */         ),
      .ras_dp_err_log            (axi_rtrgt_cpl_dt_ras_dp_err_log)
        ,
        .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj)
      );

   assign axi_ras_par_rtrgt_cpl_dt_pulse = axi_rtrgt_cpl_dt_ras_dp_err_log.valid;


  


// SMD: Self determined expression present in the design
// SJ: Operations over integers. No overflow possible on the configuration space. Any error would be detected by simulation of the RAS.DP framework.
// spyglass disable_block SelfDeterminedExpr-ML

   //Function to interleave the parity data
   function automatic [CORE_DATA_BUS_WD -1:0] add_data_par;
      input [PCIE_CORE_DATA_BUS_WD -1:0] in_data;
      input [CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD-1:0] in_par;
      integer                  i, j;
      reg [CORE_DATA_BUS_WD -1:0] out_data;
      begin
         out_data = {CORE_DATA_BUS_WD{1'b0}};
         for (i=0; i<(CORE_DATA_BUS_WD-PCIE_CORE_DATA_BUS_WD); i=i+1) begin
            for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
               if (((i*CX_RAS_PROT_RANGE +j) < PCIE_CORE_DATA_BUS_WD) && ((i*CX_RAS_PROT_RANGE +j+i) < CORE_DATA_BUS_WD))
                 out_data[i*CX_RAS_PROT_RANGE +j+i] = in_data[i*CX_RAS_PROT_RANGE +j];
            end
            if (((i + 1)*CX_RAS_PROT_RANGE + i) < CORE_DATA_BUS_WD)
              out_data[(i + 1)*CX_RAS_PROT_RANGE + i] = in_par[i];
         end
         add_data_par = out_data;
      end
   endfunction

   //Function to interleave the parity address
   function automatic [CORE_ADDR_BUS_WD -1 :0] add_addr_par;
      input [FLT_Q_ADDR_WIDTH-1:0]   in_addr;
      input [(CORE_ADDR_BUS_WD-FLT_Q_ADDR_WIDTH)-1:0] in_par;
      integer               i, j;
      reg [CORE_ADDR_BUS_WD-1:0] out_addr;
      begin
         out_addr =0;
         for (i=0; i<(CORE_ADDR_BUS_WD-FLT_Q_ADDR_WIDTH); i=i+1) begin
            for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
               if (((i*CX_RAS_PROT_RANGE +j)<FLT_Q_ADDR_WIDTH) && ((i*CX_RAS_PROT_RANGE+j+i) < CORE_ADDR_BUS_WD))
                 out_addr[i*CX_RAS_PROT_RANGE +j+i] = in_addr[i*CX_RAS_PROT_RANGE +j];
            end
            if (((i+1)*CX_RAS_PROT_RANGE + i)<CORE_ADDR_BUS_WD)
              out_addr[(i+1)*CX_RAS_PROT_RANGE + i] = in_par[i];
         end
         add_addr_par = out_addr[CORE_ADDR_BUS_WD -1 : 0];
      end
   endfunction
      
// spyglass enable_block SelfDeterminedExpr-ML


`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule
