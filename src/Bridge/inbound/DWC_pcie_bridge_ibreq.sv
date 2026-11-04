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
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ibreq.sv#17 $
// ---------------------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_bridge_ibreq
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter DC_INBD_HEADER_PNP_1STG_WD         = `DC_INBD_HEADER_PNP_1STG_WD,
    parameter DC_INBD_HEADER_PNP_1STG_WD_NP      = `DC_INBD_HEADER_PNP_1STG_WD_NP,
    parameter DC_INBD_HEADER_PNP_WD              = `DC_INBD_HEADER_PNP_WD,
    parameter DC_INBD_MISCINFO_WD                = `DC_INBD_MISCINFO_WD,
    parameter MSTR_DATA_WD_GT_CORE_DATA_WD       = `CC_MSTR_BUS_DATA_WIDTH > `CC_CORE_DATA_BUS_WD,
    parameter CORE_REQ_DATA_BUS_WD               = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_BUS_DATA_WIDTH : `CC_CORE_DATA_BUS_WD,
    parameter CX_RAS_RAM_PROT_RANGE              = `CX_RAS_RAM_PROT_RANGE,
    parameter CC_IB_RD_REQ_CDC_RAM_DP            = `CC_IB_RD_REQ_CDC_RAM_DP,
    parameter CC_IB_WR_REQ_CDC_RAM_DP            = `CC_IB_WR_REQ_CDC_RAM_DP,
    parameter CC_IB_RD_REQ_CDC_RAM_ADDR_WD       = `CC_IB_RD_REQ_CDC_RAM_ADDR_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_ADDR_WD       = `CC_IB_WR_REQ_CDC_RAM_ADDR_WD,
    parameter CC_MRF_C2A_FIFO_SYNC_REGS          = 2, // double registered CDC
    parameter CC_MRF_A2C_FIFO_SYNC_REGS          = 2, // double registered CDC
    parameter CC_MRF_C2A_FIFO_HOLD_RD_ADDR       = 1, //If the full flag is used the push interface will clobber the held read data.
    parameter CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC = `CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC,
    parameter CC_IB_WR_REQ_CDC_RAM_DATA_WD       = `CC_IB_WR_REQ_CDC_RAM_DATA_WD,
    parameter CC_IB_WR_REQ_CDC_RAM_RD_LATENCY    = `CC_IB_WR_REQ_CDC_RAM_RD_LATENCY,
    parameter CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC = `CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC,
    parameter CC_IB_RD_REQ_CDC_RAM_DATA_WD       = `CC_IB_RD_REQ_CDC_RAM_DATA_WD,
    parameter CC_IB_RD_REQ_CDC_RAM_RD_LATENCY    = `CC_IB_RD_REQ_CDC_RAM_RD_LATENCY,
    parameter CX_AXI_MSTR_PRESP_CDC_FIFO_DP      = `CX_AXI_MSTR_PRESP_CDC_FIFO_DP,
    parameter CX_AXI_MSTR_PRESP_CDC_FIFO_DP_LOG2 = `CX_AXI_MSTR_PRESP_CDC_FIFO_DP_LOG2,
    parameter CC_MSTR_BUS_DATA_WIDTH             = `CC_MSTR_BUS_DATA_WIDTH,
    parameter CC_MSTR_BUS_WSTRB_WIDTH            = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter CC_MSTR_BUS_ADDR_WIDTH             = `CC_MSTR_BUS_ADDR_WIDTH,
    parameter CC_MAX_MSTR_TAG_PW                 = `CC_MAX_MSTR_TAG_PW,
    parameter CC_MSTR_BE_CTRL_WIDTH              = `CC_MSTR_BE_CTRL_WIDTH,
    parameter CC_MSTR_NW                         = `CC_MSTR_NW,
    parameter CC_MSTR_NUM_CONV_WD                = `CC_MSTR_NUM_CONV_WD,
    parameter CX_NW                              = `CX_NW,
    parameter CC_MSTR_MTU_PW                     = `CC_MSTR_MTU_PW,
    parameter CC_AMBA_TLP_SEQ_WD                 = `CC_AMBA_TLP_SEQ_WD    ,
    parameter CX_NFUNC                           = `CX_NFUNC               ,
    parameter RADMX_TRGT1_REQ_HDR_WD             = `CC_RADMX_TRGT1_REQ_HDR_WD ,
    parameter CC_CORE_DATA_BUS_WD                = `CC_CORE_DATA_BUS_WD    ,
    parameter CX_NFUNC_WD                        = `CX_NFUNC_WD            ,
    parameter REMOTE_MAX_RD_SIZE_PW              = `CX_REMOTE_RD_REQ_SIZE_PW  ,
    parameter CX_REMOTE_MAX_TAGS_WD              = `CX_REMOTE_MAX_TAGS_WD,
    parameter DC_DMA_TYPE_WIDTH                  = `DC_DMA_TYPE_WIDTH,
    parameter CC_NUM_DMA_RD_CHAN_WIDTH           = `CC_NUM_DMA_RD_CHAN_WIDTH,
    parameter CC_NUM_DMA_MAX_CHAN_WIDTH          = `CC_NUM_DMA_MAX_CHAN_WIDTH,
    parameter P_N_PRESP_STREAMS                  = `CX_NVC,
    parameter P_N_PRESP_STREAMS_WD               = `CX_NVC_LOG2,
    parameter MSTR_ADDR_WD                       = `CC_MSTR_BUS_ADDR_WIDTH,
    parameter BE_CTRL_WD                         = `CC_MSTR_BE_CTRL_WIDTH,
    parameter ID_WD                              = `GMX_AXI_ID_WIDTH,
    parameter CORE_REQ_DATA_BUS_WSTRB_WD         = MSTR_DATA_WD_GT_CORE_DATA_WD ? CC_MSTR_BUS_WSTRB_WIDTH : `CC_CORE_DATA_BUS_WSTRB_WD,
    parameter REQ_NW                             = MSTR_DATA_WD_GT_CORE_DATA_WD ? CC_MSTR_NW : CX_NW,
    parameter CX_NVC_LOG2                        = `CX_NVC_LOG2,
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


    input                                                  cfg_rdq_mrf_ras_recc_correct,
    output                                                 rdq_mrf_ras_recc_corr_cnt_pulse,
    output                                                 rdq_mrf_ras_recc_ucorr_cnt_pulse,
    output [CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]              rdq_mrf_ras_recc_cnt_addr,
    input                                                  cfg_wrq_mrf_ras_recc_correct,
    output                                                 wrq_mrf_ras_recc_corr_cnt_pulse,
    output                                                 wrq_mrf_ras_recc_ucorr_cnt_pulse,
    output [CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]              wrq_mrf_ras_recc_cnt_addr,
    output ras_dp_err_log_t                                wrq_mrf_recc_cnt_ras_dp_err_log,
    output ras_dp_err_log_t                                rdq_mrf_recc_cnt_ras_dp_err_log,
    input  ras_dp_err_inj_t                                axi_bridge_ras_dp_err_inj_core_clk,
    input  ras_dp_err_inj_t                                core_clk_hp_mstr_ras_dp_err_inj,
    input  ras_dp_err_inj_t                                ras_dp_err_inj_mstr_aclk,


    input [DC_INBD_HEADER_PNP_1STG_WD-1:0]                 inbd_header_pnp_wr,
    input [63:0]                                           radm_trgt1_hdr_uppr_bytes,
    input [CC_CORE_DATA_BUS_WD-1:0]                        inbd_data_pnp_wr,
    output wire                                            inbd_halt_pnp_wr,

    input [DC_INBD_HEADER_PNP_1STG_WD-1:0]                 inbd_header_pnp_rd,
    output wire                                            inbd_halt_pnp_rd,
    // -------------------------------------------------------------------------------------
    // Parity error detection
    // -------------------------------------------------------------------------------------
    output wire [1:0]                                      trgt1_addr_parerr,
    output wire                                            trgt1_data_parerr,
    output ras_dp_err_log_t                                trgt1_dt_ras_dp_err_log,
    output ras_dp_err_log_t [1:0]                          trgt1_ad_ras_dp_err_log,
    output wire [1:0]                                      mstr_req_addr_parerr,
    output wire                                            mstr_req_data_parerr,
    output ras_dp_err_log_t [1:0]                          mstr_req_ad_ras_dp_err_log,
    output ras_dp_err_log_t                                mstr_req_dt_ras_dp_err_log,

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

    // Interface with Master Completion Buffer
    output reg                                             reqmcb_hdr_np_valid,
    output reg                                             reqmcb_hdr_ncbe,
    output reg [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]          reqmcb_hdr_low_addr,
    output reg [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]          reqmcb_hdr_dw_len_bytes,
    output reg [CX_REMOTE_MAX_TAGS_WD-1:0]                 reqmcb_hdr_lookupid,
    output reg [CX_NFUNC_WD-1:0]                           reqmcb_hdr_func,
    output reg [DC_DMA_TYPE_WIDTH-1:0]                     reqmcb_hdr_dma_type,
    output reg [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]             reqmcb_hdr_dma_chan,
    output reg [CX_REMOTE_MAX_TAGS_WD-1:0]                 reqmcb_hdr_mstrid, //AMBA ID
    output reg                                             reqmcb_hdr_last,

    output reg                                             ibmrf_reqmcb_np_valid,
    output reg [CX_REMOTE_MAX_TAGS_WD-1:0]                 ibmrf_reqmcb_mstrid,
    output reg                                             ibmrf_reqmcb_last,
    output reg                                             ibmrf_reqmcb_atomic,


    // Interface with the AXI master
    // AMBA master request interface
    output wire [MSTR_ADDR_WD-1:0]                         wrq_maddr,
    output wire                                            wrq_mwrite,
    output wire                                            wrq_mwrite_last,
    output wire [CC_MSTR_MTU_PW -1:0]                      wrq_mlen,
    output wire [CC_MSTR_BUS_DATA_WIDTH-1:0]               wrq_mdata,
    output wire [CC_MSTR_BUS_WSTRB_WIDTH-1:0]              wrq_mbe,
    output wire [BE_CTRL_WD-1:0]                           wrq_mbe_ctrl,
    output wire [ID_WD-1 :0]                               wrq_mid,
    output wire                                            wrq_mabort,
    output wire                                            wrq_mlast,
    output wire [DC_INBD_MISCINFO_WD-1:0]                  wrq_mmisc,
    input                                                  wrq_saccept,

    output wire [MSTR_ADDR_WD-1:0]                         rdq_maddr,
    output wire                                            rdq_mread,
    output wire [CC_MSTR_MTU_PW -1:0]                      rdq_mlen,
    output wire [CC_MSTR_BUS_DATA_WIDTH-1:0]               rdq_mdata,
    output wire [CC_MSTR_BUS_WSTRB_WIDTH-1:0]              rdq_mbe,
    output wire [BE_CTRL_WD-1:0]                           rdq_mbe_ctrl,
    output wire [ID_WD-1 :0]                               rdq_mid,
    output wire                                            rdq_mabort,
    output wire                                            rdq_mlast,
    output wire [DC_INBD_MISCINFO_WD-1:0]                  rdq_mmisc,
    input                                                  rdq_saccept,

  // -------------------------------------------------------------------------------------
  // Responses from the AMBA master in the master clock domain
  // -------------------------------------------------------------------------------------
    input                                                  axigm_presp_cmplt,
    input [CC_AMBA_TLP_SEQ_WD-1:0]                         axigm_presp_rpseq,
    input [1:0]                                            axigm_presp_type,
    input [P_N_PRESP_STREAMS_WD-1:0]                       axigm_presp_stream,
    input [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                   axigm_presp_dma_chan_num ,
    input                                                  axigm_presp_dma_err,
    input                                                  axigm_presp_cfg_cmplt,
    input [CC_AMBA_TLP_SEQ_WD-1:0]                         axigm_presp_cfg_rpseq,
    input                                                  axigm_presp_cfg_type,
    input [P_N_PRESP_STREAMS_WD-1:0]                       axigm_presp_cfg_stream,
    output wire                                            ibreq_presp_cdc_halt,
    output wire                                            ibreq_presp_cfg_cdc_halt,
    output wire                                            ibreq_presp_cfg_cdc_alm_halt,
  // -------------------------------------------------------------------------------------
  // Responses from the AMBA master in the core clock domain
  // -------------------------------------------------------------------------------------
    output wire                                            ibreq_presp_cmplt,
    output wire [CC_AMBA_TLP_SEQ_WD-1:0]                   ibreq_presp_rpseq,
    output wire [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]             ibreq_presp_dma_chan_num ,
    output wire                                            ibreq_presp_dma_err ,
   output logic [P_N_PRESP_STREAMS-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] ibreq_cfg_rpseq,
    output wire [1:0]                                      ibreq_presp_type

   );

   /////////////////////////////////////////////////////////
   // Internal Wires
   /////////////////////////////////////////////////////////

   // Master request information interface arbiter
   // halt the read queue, when wrq_inbd_hdr_np_valid is
   // asserted
   wire                                     arb_halt_wrq_dcp;
   wire                                     arb_halt_rdq_dcp;

   wire [DC_INBD_HEADER_PNP_WD-1:0]         rdq_inbd_hdr_pnp;
   wire [DC_INBD_HEADER_PNP_WD-1:0]         wrq_inbd_hdr_pnp;

   wire                                     wrq_inbd_hdr_dmwr;

   wire                                     rdq_inbd_hdr_np_valid;
   wire                                     wrq_inbd_hdr_np_valid;
   wire                                     rdq_inbd_hdr_ncbe;
   wire                                     wrq_inbd_hdr_ncbe;

   wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]  wrq_inbd_hdr_low_addr;
   wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]  rdq_inbd_hdr_low_addr;

   wire [REMOTE_MAX_RD_SIZE_PW-1:0]         wrq_inbd_hdr_byte_len;
   wire [REMOTE_MAX_RD_SIZE_PW-1:0]         rdq_inbd_hdr_byte_len;

   wire [CX_REMOTE_MAX_TAGS_WD-1:0]         wrq_inbd_hdr_lookupid;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]         rdq_inbd_hdr_lookupid;

   wire [CX_REMOTE_MAX_TAGS_WD-1:0]         wrq_inbd_hdr_mstr_id;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]         rdq_inbd_hdr_mstr_id;

   wire                                     wrq_inbd_hdr_last;
   wire                                     rdq_inbd_hdr_last;


   wire [CX_NFUNC_WD-1:0]                   wrq_inbd_hdr_func;
   wire [CX_NFUNC_WD-1:0]                   rdq_inbd_hdr_func;

   wire [DC_DMA_TYPE_WIDTH-1:0]             wrq_inbd_hdr_dma_type;
   wire [DC_DMA_TYPE_WIDTH-1:0]             rdq_inbd_hdr_dma_type;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]     wrq_inbd_hdr_dma_chan;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]     rdq_inbd_hdr_dma_chan;

   wire                                     wrq_mrf_reqmcb_np_valid;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]         wrq_mrf_reqmcb_mstrid;
   wire                                     wrq_mrf_reqmcb_last;

   logic                                    wrq_mrf_reqmcb_atomic;
   wire                                     arbmcb_halt_wrq_mrf;
   wire                                     arbmcb_halt_rdq_mrf;
   wire                                     rdq_mrf_reqmcb_np_valid;
   wire [CX_REMOTE_MAX_TAGS_WD-1:0]         rdq_mrf_reqmcb_mstrid;
   wire                                     rdq_mrf_reqmcb_last;

   wire                                     presp_sel_bchan;


   wire [CC_AMBA_TLP_SEQ_WD-1:0]            ibreq_presp_cfg_rpseq;


  logic [P_N_PRESP_STREAMS-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] s_ibreq_presp_rpseq_ps, s_ibreq_presp_cfg_rpseq_ps;
  logic [P_N_PRESP_STREAMS-1:0] [CC_AMBA_TLP_SEQ_WD-1:0] r_ibreq_presp_rpseq_ps, r_ibreq_presp_cfg_rpseq_ps;

  logic [P_N_PRESP_STREAMS_WD-1:0] ibreq_presp_cfg_stream;
  logic [P_N_PRESP_STREAMS_WD-1:0] ibreq_presp_stream;

   /////////////////////////////////////////////////////////
   // Design starts here
   /////////////////////////////////////////////////////////

   /////////////////////////////////////////////////////////
   // Master posted response bus register
   /////////////////////////////////////////////////////////
   // Selects B channel when asserted
   assign presp_sel_bchan = 1'b1;

   logic ibreq_presp_cfg_cmplt;
   wire [1:0] ibreq_presp_cfg_type;

   // -------------------------------------------------------------------------------------
   // Posted completion bus retime
   // -------------------------------------------------------------------------------------
   DWC_pcie_amba_presp_retime
    #(
      .CC_DMA_ENABLE_VALUE(1),
      .CC_NUM_DMA_RD_CHAN_WIDTH(CC_NUM_DMA_RD_CHAN_WIDTH),
      .P_N_PRESP_STREAMS_WD(P_N_PRESP_STREAMS_WD),
      .CDC_FIFO_DEPTH(CX_AXI_MSTR_PRESP_CDC_FIFO_DP),
      .CDC_FIFO_ADDR_WIDTH(CX_AXI_MSTR_PRESP_CDC_FIFO_DP_LOG2),
      .CX_NVC_LOG2(CX_NVC_LOG2),
      .CC_AMBA_TLP_SEQ_WD(CC_AMBA_TLP_SEQ_WD)
      ) u_presp_retime(
        .mstr_aclk             ( mstr_aclk                        ),
        .mstr_aresetn          ( mstr_arstn                       ),
        .core_clock            ( core_clk                         ),
        .core_reset_n          ( core_rstn                        ),
        .gm_presp_cmplt        ( axigm_presp_cmplt                ),
        .gm_presp_rpseq        ( axigm_presp_rpseq                ),
        .gm_presp_type         ( axigm_presp_type                 ),
        .gm_presp_stream       ( axigm_presp_stream               ),
        .gm_presp_dma_chan_num ( axigm_presp_dma_chan_num         ),
        .gm_presp_dma_err      ( axigm_presp_dma_err              ),
        .rtime_dma_chan_num    ( ibreq_presp_dma_chan_num         ),
        .rtime_dma_err         ( ibreq_presp_dma_err              ),
        .rtime_cdc_halt        ( ibreq_presp_cdc_halt             ),
        .rtime_cdc_alm_halt    (                                  ),
        .rtime_cmplt           ( ibreq_presp_cmplt                ),
        .rtime_rpseq           ( ibreq_presp_rpseq                ),
        .rtime_stream          ( ibreq_presp_stream               ),
        .rtime_type            ( ibreq_presp_type                 )
        );
   // -------------------------------------------------------------------------------------
   DWC_pcie_amba_presp_retime
    #(
      .CC_DMA_ENABLE_VALUE(0),
      .CC_NUM_DMA_RD_CHAN_WIDTH(CC_NUM_DMA_RD_CHAN_WIDTH),
      .P_N_PRESP_STREAMS_WD(P_N_PRESP_STREAMS_WD),
      .CDC_FIFO_DEPTH(CX_AXI_MSTR_PRESP_CDC_FIFO_DP),
      .CDC_FIFO_ADDR_WIDTH(CX_AXI_MSTR_PRESP_CDC_FIFO_DP_LOG2),
      .CX_NVC_LOG2(CX_NVC_LOG2),
      .CC_AMBA_TLP_SEQ_WD(CC_AMBA_TLP_SEQ_WD)
      ) u_presp_cfg_retime(
        .mstr_aclk             ( mstr_aclk                        ),
        .mstr_aresetn          ( mstr_arstn                       ),
        .core_clock            ( core_clk                         ),
        .core_reset_n          ( core_rstn                        ),

        .gm_presp_cmplt        ( axigm_presp_cfg_cmplt            ),
        .gm_presp_rpseq        ( axigm_presp_cfg_rpseq            ),
        .gm_presp_type         ( {1'b0,axigm_presp_cfg_type}      ),
        .gm_presp_stream       ( axigm_presp_cfg_stream           ),
        .gm_presp_dma_chan_num ( {CC_NUM_DMA_RD_CHAN_WIDTH{1'b0}} ),
        .gm_presp_dma_err      ( 1'b0                             ),
        .rtime_dma_chan_num    (        /* unconnected */         ),
        .rtime_dma_err         (        /* unconnected */         ),
        .rtime_cdc_halt        ( ibreq_presp_cfg_cdc_halt         ),
        .rtime_cdc_alm_halt    ( ibreq_presp_cfg_cdc_alm_halt     ),
        .rtime_cmplt           ( ibreq_presp_cfg_cmplt            ),
        .rtime_rpseq           ( ibreq_presp_cfg_rpseq            ),
        .rtime_stream          ( ibreq_presp_cfg_stream           ),
        .rtime_type            ( ibreq_presp_cfg_type             )
        );
   // -------------------------------------------------------------------------------------

  assign ibreq_cfg_rpseq = presp_sel_bchan ? s_ibreq_presp_rpseq_ps : s_ibreq_presp_cfg_rpseq_ps;

  always_comb begin : CPROC_s_ibreq_presp_rpseq_ps
    s_ibreq_presp_rpseq_ps = r_ibreq_presp_rpseq_ps;
    s_ibreq_presp_cfg_rpseq_ps = r_ibreq_presp_cfg_rpseq_ps;

    if(ibreq_presp_cmplt && !ibreq_presp_type[0])
      s_ibreq_presp_rpseq_ps[ibreq_presp_stream] = ibreq_presp_rpseq;

    if(ibreq_presp_cfg_cmplt && !ibreq_presp_cfg_type[0])
      s_ibreq_presp_cfg_rpseq_ps[ibreq_presp_cfg_stream] = ibreq_presp_cfg_rpseq;
  end : CPROC_s_ibreq_presp_rpseq_ps

  always_ff @(posedge core_clk, negedge core_rstn) begin : SPROC_r_ibreq_presp_rpseq_ps
    if(!core_rstn) begin
      r_ibreq_presp_rpseq_ps     <= #TP '0;
      r_ibreq_presp_cfg_rpseq_ps <= #TP '0;
    end else begin
      r_ibreq_presp_rpseq_ps     <= #TP s_ibreq_presp_rpseq_ps;
      r_ibreq_presp_cfg_rpseq_ps <= #TP s_ibreq_presp_cfg_rpseq_ps;
    end
  end : SPROC_r_ibreq_presp_rpseq_ps


   //---------------------------------------------------------
   // Master Completion buffer request I/F arbiter @ core_clk
   //---------------------------------------------------------

   // Never halts the write queue
   // The read queue is halted when there's a simultaneous event
   // on both ends of the design
   assign arb_halt_wrq_dcp = 1'b0;
   assign arb_halt_rdq_dcp = rdq_inbd_hdr_np_valid && wrq_inbd_hdr_np_valid;

   assign wrq_inbd_hdr_dmwr = (wrq_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW] == `DMWR_TYPE);


  // Arbitrates who will have access to report to MCB

  always @(posedge core_clk or negedge core_rstn) begin : PROC_seq_mcbreq_arb
    if (!core_rstn) begin
      reqmcb_hdr_np_valid     <= # TP 0;
      reqmcb_hdr_ncbe         <= # TP 0;
      reqmcb_hdr_low_addr     <= # TP 0;
      reqmcb_hdr_dw_len_bytes <= # TP 0;
      reqmcb_hdr_lookupid     <= # TP 0;
      reqmcb_hdr_func         <= # TP 0;
      reqmcb_hdr_dma_type     <= # TP 0;
      reqmcb_hdr_dma_chan     <= # TP 0;
      reqmcb_hdr_mstrid       <= # TP 0;
      reqmcb_hdr_last         <= # TP 0;
    end else begin
      if (wrq_inbd_hdr_np_valid) begin
         reqmcb_hdr_np_valid     <= # TP wrq_inbd_hdr_np_valid ;
         reqmcb_hdr_ncbe         <= # TP wrq_inbd_hdr_ncbe     ;
         reqmcb_hdr_low_addr     <= # TP wrq_inbd_hdr_low_addr ;
         reqmcb_hdr_dw_len_bytes <= # TP wrq_inbd_hdr_dmwr ? 4 : wrq_inbd_hdr_byte_len;
         reqmcb_hdr_lookupid     <= # TP wrq_inbd_hdr_lookupid;
         reqmcb_hdr_func         <= # TP wrq_inbd_hdr_func;
         reqmcb_hdr_dma_type     <= # TP wrq_inbd_hdr_dma_type;

         reqmcb_hdr_dma_chan     <= # TP wrq_inbd_hdr_dma_chan;
         reqmcb_hdr_mstrid       <= # TP wrq_inbd_hdr_mstr_id;
         reqmcb_hdr_last         <= # TP wrq_inbd_hdr_last;
      end else begin
         reqmcb_hdr_np_valid     <= # TP rdq_inbd_hdr_np_valid ;
         reqmcb_hdr_ncbe         <= # TP rdq_inbd_hdr_ncbe     ;
         reqmcb_hdr_low_addr     <= # TP rdq_inbd_hdr_low_addr ;
         reqmcb_hdr_dw_len_bytes <= # TP rdq_inbd_hdr_byte_len;
         reqmcb_hdr_lookupid     <= # TP rdq_inbd_hdr_lookupid;
         reqmcb_hdr_func         <= # TP rdq_inbd_hdr_func;
         reqmcb_hdr_dma_type     <= # TP rdq_inbd_hdr_dma_type;
         reqmcb_hdr_dma_chan     <= # TP rdq_inbd_hdr_dma_chan;
         reqmcb_hdr_mstrid       <= # TP rdq_inbd_hdr_mstr_id;
         reqmcb_hdr_last         <= # TP rdq_inbd_hdr_last;
      end
    end
  end

   //---------------------------------------------------------
   // Master Completion buffer request I/F arbiter @ mstr_aclk
   //---------------------------------------------------------
   // Never halts the write queue
   // The read queue is halted when there's a simultaneous event
   // on both ends of the design
   assign arbmcb_halt_wrq_mrf = 1'b0;
   assign arbmcb_halt_rdq_mrf = wrq_mrf_reqmcb_np_valid && rdq_mrf_reqmcb_np_valid;

   always @ ( * ) begin : PROC_comb_mrd_mcbreq_arb
      if (wrq_mrf_reqmcb_np_valid) begin
         ibmrf_reqmcb_np_valid = wrq_mrf_reqmcb_np_valid;
         ibmrf_reqmcb_mstrid   = wrq_mrf_reqmcb_mstrid;
         ibmrf_reqmcb_last     = wrq_mrf_reqmcb_last;
         ibmrf_reqmcb_atomic   = wrq_mrf_reqmcb_atomic;
      end else begin
         ibmrf_reqmcb_np_valid = rdq_mrf_reqmcb_np_valid;
         ibmrf_reqmcb_mstrid   = rdq_mrf_reqmcb_mstrid;
         ibmrf_reqmcb_last     = rdq_mrf_reqmcb_last;
         // There's no read atomic operation
         ibmrf_reqmcb_atomic   = '0;
      end
   end

   DWC_pcie_bridge_rdwr_queue
   
     #(
       .WR_NOT_RD_QUEUE               (1'b0                               ),
       .DC_INBD_HEADER_PNP_1STG_WD    (DC_INBD_HEADER_PNP_1STG_WD         ),
       .DC_INBD_HEADER_PNP_WD         (DC_INBD_HEADER_PNP_WD              ),
       .DC_INBD_MISCINFO_WD           (DC_INBD_MISCINFO_WD                ),
       .CX_RAS_RAM_PROT_RANGE         (CX_RAS_RAM_PROT_RANGE              ),
       .DC_DMA_TYPE_WIDTH             (DC_DMA_TYPE_WIDTH                  ),
       .CC_NUM_DMA_CHAN_WIDTH         (CC_NUM_DMA_MAX_CHAN_WIDTH          ),
       .IB_REQ_CDC_RAM_DP             (CC_IB_RD_REQ_CDC_RAM_DP            ),
       .IB_REQ_CDC_RAM_ADDR_WD        (CC_IB_RD_REQ_CDC_RAM_ADDR_WD       ),
       .IB_REQ_CDC_RAM_DATA_WD        (CC_IB_RD_REQ_CDC_RAM_DATA_WD       ),
       .IB_REQ_CDC_RAM_DATA_WD_NOECC  (CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC ),
       .IB_REQ_CDC_RAM_RD_LATENCY     (CC_IB_RD_REQ_CDC_RAM_RD_LATENCY    ),
       .CC_MRF_C2A_FIFO_SYNC_REGS     (CC_MRF_C2A_FIFO_SYNC_REGS          ),
       .CC_MRF_A2C_FIFO_SYNC_REGS     (CC_MRF_A2C_FIFO_SYNC_REGS          ),
       .CC_MRF_C2A_FIFO_HOLD_RD_ADDR  (CC_MRF_C2A_FIFO_HOLD_RD_ADDR       ),
       .MSTR_DATA_WD_GT_CORE_DATA_WD  (MSTR_DATA_WD_GT_CORE_DATA_WD       ),
       .CORE_REQ_DATA_BUS_WD          (CORE_REQ_DATA_BUS_WD               ),
       .REQ_NW                        (REQ_NW                             ),
       .CC_MSTR_BUS_DATA_WIDTH        (CC_MSTR_BUS_DATA_WIDTH             ),
       .CC_MSTR_BUS_WSTRB_WIDTH       (CC_MSTR_BUS_WSTRB_WIDTH            ),
       .CC_MSTR_BUS_ADDR_WIDTH        (CC_MSTR_BUS_ADDR_WIDTH             ),
       .CC_MAX_MSTR_TAG_PW            (CC_MAX_MSTR_TAG_PW                 ),
       .CC_MSTR_BE_CTRL_WIDTH         (CC_MSTR_BE_CTRL_WIDTH              ),
       .CC_MSTR_NW                    (CC_MSTR_NW                         ),
       .CC_MSTR_NUM_CONV_WD           (CC_MSTR_NUM_CONV_WD                ),
       .CX_NW                         (CX_NW                              ),
       .CC_MSTR_MTU_PW                (CC_MSTR_MTU_PW                     ),
       .CORE_REQ_DATA_BUS_WSTRB_WD    (CORE_REQ_DATA_BUS_WSTRB_WD         ),
       .CX_REMOTE_MAX_TAGS_WD         (CC_MAX_MSTR_TAG_PW                 ),
       .CX_NFUNC                      (CX_NFUNC                           ),
       .RADMX_TRGT1_REQ_HDR_WD        (RADMX_TRGT1_REQ_HDR_WD             ),
       .CC_CORE_DATA_BUS_WD           (CC_CORE_DATA_BUS_WD                ),
       .CX_NFUNC_WD                   (CX_NFUNC_WD                        ),
       .RAS_DP_ID                     (`MSTR_REQ_RD_AD_RAS_ID             ),
       .RAM_RAS_DP_ID                 (`MRF_RECC_CNT_RD_RAS_ID            ),
       .REMOTE_MAX_RD_SIZE_PW         (REMOTE_MAX_RD_SIZE_PW              )
       ) u_rdq
       (
         .core_clk                            ( core_clk                                     )
        ,.core_rstn                           ( core_rstn                                    )
        ,.mstr_aclk                           ( mstr_aclk                                    )
        ,.mstr_arstn                          ( mstr_arstn                                   )

    // ---------------------------------------------------------------------------
    // RAS.DP register interface
    // ---------------------------------------------------------------------------
        ,.cfg_rdwr_mrf_ras_recc_correct       ( cfg_rdq_mrf_ras_recc_correct                 )
        ,.rdwrq_mrf_ras_recc_corr_cnt_pulse   ( rdq_mrf_ras_recc_corr_cnt_pulse              )
        ,.rdwrq_mrf_ras_recc_ucorr_cnt_pulse  ( rdq_mrf_ras_recc_ucorr_cnt_pulse             )
        ,.rdwrq_mrf_ras_recc_cnt_addr         ( rdq_mrf_ras_recc_cnt_addr                    )
        ,.mrf_recc_cnt_ras_dp_err_log         ( rdq_mrf_recc_cnt_ras_dp_err_log              )


        ,.inbd_hdr_pnp                        ( inbd_header_pnp_rd                           )
        ,.radm_trgt1_hdr_uppr_bytes           (64'd0                                         )
        ,.inbd_data_pnp                       ( {CC_CORE_DATA_BUS_WD{1'b0}}                  )
        ,.inbd_halt_pnp                       ( inbd_halt_pnp_rd                             )

        ,.trgt1_addr_parerr                   ( trgt1_addr_parerr[1]                         )
        ,.trgt1_data_parerr                   (              /*Not connected*/               )
        ,.trgt1_dt_ras_dp_err_log             (              /*Not connected*/               )
        ,.trgt1_ad_ras_dp_err_log             ( trgt1_ad_ras_dp_err_log[1]                   )
        ,.axi_bridge_ras_dp_err_inj_core_clk  (axi_bridge_ras_dp_err_inj_core_clk            )
        ,.core_clk_hp_mstr_ras_dp_err_inj     (core_clk_hp_mstr_ras_dp_err_inj               )
        ,.ras_dp_err_inj_mstr_aclk            (ras_dp_err_inj_mstr_aclk                      )
        ,.mstr_req_addr_parerr                ( mstr_req_addr_parerr[1]                      )
        ,.mstr_req_data_parerr                (              /**Not connected*/              )
        ,.mstr_req_ad_ras_dp_err_log          ( mstr_req_ad_ras_dp_err_log[1]                )
        ,.mstr_req_dt_ras_dp_err_log          (              /**Not connected*/              )

        ,.rdwrq_c2a_ram_addra                 ( ib_rreq_c2a_cdc_ram_addra                    )
        ,.rdwrq_c2a_ram_addrb                 ( ib_rreq_c2a_cdc_ram_addrb                    )
        ,.rdwrq_c2a_ram_wea                   ( ib_rreq_c2a_cdc_ram_wea                      )
        ,.rdwrq_c2a_ram_enb                   ( ib_rreq_c2a_cdc_ram_enb                      )
        ,.rdwrq_c2a_ram_doutb                 ( ib_rreq_c2a_cdc_ram_doutb                    )
        ,.rdwrq_c2a_ram_dina                  ( ib_rreq_c2a_cdc_ram_dina                     )
        ,.dcp_inbd_hdr_pnp                    ( rdq_inbd_hdr_pnp                             )
        ,.dcp_inbd_hdr_np_valid               ( rdq_inbd_hdr_np_valid                        )
        ,.dcp_inbd_hdr_ncbe                   ( rdq_inbd_hdr_ncbe                            )
        ,.dcp_inbd_hdr_low_addr               ( rdq_inbd_hdr_low_addr                        )
        ,.dcp_inbd_hdr_byte_len               ( rdq_inbd_hdr_byte_len                        )
        ,.dcp_inbd_hdr_mstr_id                ( rdq_inbd_hdr_mstr_id                         )
        ,.dcp_inbd_hdr_lookupid               ( rdq_inbd_hdr_lookupid                        )
        ,.dcp_inbd_hdr_func                   ( rdq_inbd_hdr_func                            )
        ,.dcp_inbd_hdr_dma_type               ( rdq_inbd_hdr_dma_type                        )
        ,.dcp_inbd_hdr_dma_chan               ( rdq_inbd_hdr_dma_chan                        )
        ,.dcp_inbd_hdr_last                   ( rdq_inbd_hdr_last                            )


        ,.halt_dcp                            ( arb_halt_rdq_dcp                             )

        ,.mrf_reqmcb_np_valid                 ( rdq_mrf_reqmcb_np_valid                      )
        ,.mrf_reqmcb_mstrid                   ( rdq_mrf_reqmcb_mstrid                        )
        ,.mrf_reqmcb_last                     ( rdq_mrf_reqmcb_last                          )
        ,.mrf_reqmcb_atomic                   (              /*Not connected*/               )
        ,.arbmcb_halt_mrf                     ( arbmcb_halt_rdq_mrf                          )

        ,.maddr                               ( rdq_maddr                                    )
        ,.mstrobe                             ( rdq_mread                                    )
        ,.mstrobe_last                        (                                              ) // Not used
        ,.mlen                                ( rdq_mlen                                     )
        ,.mdata                               ( rdq_mdata                                    )
        ,.mbe                                 ( rdq_mbe                                      )
        ,.mbe_ctrl                            ( rdq_mbe_ctrl                                 )
        ,.mid                                 ( rdq_mid                                      )
        ,.mabort                              ( rdq_mabort                                   )
        ,.mlast                               ( rdq_mlast                                    )
        ,.mmisc                               ( rdq_mmisc                                    )
        ,.saccept                             ( rdq_saccept                                  )

        ,.presp_cmplt                         ( 1'b0                                         ) //Not used
        ,.presp_stream                        ( '0                                           )
        ,.presp_type                          ( 2'b00                                        )

        );


   DWC_pcie_bridge_rdwr_queue
   
     #(
       .WR_NOT_RD_QUEUE              (1'b1                               ),
       .DC_INBD_HEADER_PNP_1STG_WD   (DC_INBD_HEADER_PNP_1STG_WD         ),
       .DC_INBD_HEADER_PNP_WD        (DC_INBD_HEADER_PNP_WD              ),
       .DC_INBD_MISCINFO_WD          (DC_INBD_MISCINFO_WD                ),
       .CX_RAS_RAM_PROT_RANGE        (CX_RAS_RAM_PROT_RANGE              ),
       .P_N_PRESP_STREAMS            (P_N_PRESP_STREAMS                  ),
       .P_N_PRESP_STREAMS_WD         (P_N_PRESP_STREAMS_WD               ),
       .DC_DMA_TYPE_WIDTH            (DC_DMA_TYPE_WIDTH                  ),
       .CC_NUM_DMA_CHAN_WIDTH        (CC_NUM_DMA_MAX_CHAN_WIDTH          ),
       .IB_REQ_CDC_RAM_DP            (CC_IB_WR_REQ_CDC_RAM_DP            ),
       .IB_REQ_CDC_RAM_ADDR_WD       (CC_IB_WR_REQ_CDC_RAM_ADDR_WD       ),
       .IB_REQ_CDC_RAM_DATA_WD_NOECC (CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC ),
       .IB_REQ_CDC_RAM_RD_LATENCY    (CC_IB_WR_REQ_CDC_RAM_RD_LATENCY    ),
       .IB_REQ_CDC_RAM_DATA_WD       (CC_IB_WR_REQ_CDC_RAM_DATA_WD       ),
       .CC_MRF_C2A_FIFO_SYNC_REGS    (CC_MRF_C2A_FIFO_SYNC_REGS          ),
       .CC_MRF_A2C_FIFO_SYNC_REGS    (CC_MRF_A2C_FIFO_SYNC_REGS          ),
       .CC_MRF_C2A_FIFO_HOLD_RD_ADDR (CC_MRF_C2A_FIFO_HOLD_RD_ADDR       ),
       .MSTR_DATA_WD_GT_CORE_DATA_WD (MSTR_DATA_WD_GT_CORE_DATA_WD       ),
       .CORE_REQ_DATA_BUS_WD         (CORE_REQ_DATA_BUS_WD               ),
       .REQ_NW                       (REQ_NW                             ),
       .CC_MSTR_BUS_DATA_WIDTH       (CC_MSTR_BUS_DATA_WIDTH             ),
       .CC_MSTR_BUS_WSTRB_WIDTH      (CC_MSTR_BUS_WSTRB_WIDTH            ),
       .CC_MSTR_BUS_ADDR_WIDTH       (CC_MSTR_BUS_ADDR_WIDTH             ),
       .CC_MAX_MSTR_TAG_PW           (CC_MAX_MSTR_TAG_PW                 ),
       .CC_MSTR_BE_CTRL_WIDTH        (CC_MSTR_BE_CTRL_WIDTH              ),
       .CC_MSTR_NW                   (CC_MSTR_NW                         ),
       .CC_MSTR_NUM_CONV_WD          (CC_MSTR_NUM_CONV_WD                ),
       .CX_NW                        (CX_NW                              ),
       .CC_MSTR_MTU_PW               (CC_MSTR_MTU_PW                     ),
       .CORE_REQ_DATA_BUS_WSTRB_WD   (CORE_REQ_DATA_BUS_WSTRB_WD         ),
       .CX_NFUNC                     (CX_NFUNC                           ),
       .RADMX_TRGT1_REQ_HDR_WD       (RADMX_TRGT1_REQ_HDR_WD             ),
       .CC_CORE_DATA_BUS_WD          (CC_CORE_DATA_BUS_WD                ),
       .CX_REMOTE_MAX_TAGS_WD        (CC_MAX_MSTR_TAG_PW                 ),
       .CX_NFUNC_WD                  (CX_NFUNC_WD                        ),
       .RAS_DP_ID                    (`MSTR_REQ_WR_AD_RAS_ID             ),
       .RAM_RAS_DP_ID                (`MRF_RECC_CNT_WR_RAS_ID            ),
       .REMOTE_MAX_RD_SIZE_PW        (REMOTE_MAX_RD_SIZE_PW              )
       ) u_wrq
       (
         .core_clk                            ( core_clk                                     )
        ,.core_rstn                           ( core_rstn                                    )
        ,.mstr_aclk                           ( mstr_aclk                                    )
        ,.mstr_arstn                          ( mstr_arstn                                   )

        ,.cfg_rdwr_mrf_ras_recc_correct       ( cfg_wrq_mrf_ras_recc_correct                 )
        ,.rdwrq_mrf_ras_recc_corr_cnt_pulse   ( wrq_mrf_ras_recc_corr_cnt_pulse              )
        ,.rdwrq_mrf_ras_recc_ucorr_cnt_pulse  ( wrq_mrf_ras_recc_ucorr_cnt_pulse             )
        ,.rdwrq_mrf_ras_recc_cnt_addr         ( wrq_mrf_ras_recc_cnt_addr                    )
        ,.mrf_recc_cnt_ras_dp_err_log         ( wrq_mrf_recc_cnt_ras_dp_err_log              )


        ,.inbd_hdr_pnp                        ( inbd_header_pnp_wr                           )
        ,.radm_trgt1_hdr_uppr_bytes           (radm_trgt1_hdr_uppr_bytes                     )
        ,.inbd_data_pnp                       ( inbd_data_pnp_wr                             )
        ,.inbd_halt_pnp                       ( inbd_halt_pnp_wr                             )

        ,.trgt1_addr_parerr                   ( trgt1_addr_parerr[0]                         )
        ,.trgt1_data_parerr                   ( trgt1_data_parerr                            )
        ,.trgt1_dt_ras_dp_err_log             ( trgt1_dt_ras_dp_err_log                      )
        ,.trgt1_ad_ras_dp_err_log             ( trgt1_ad_ras_dp_err_log[0]                   )
        ,.axi_bridge_ras_dp_err_inj_core_clk  (axi_bridge_ras_dp_err_inj_core_clk            )
        ,.core_clk_hp_mstr_ras_dp_err_inj     (core_clk_hp_mstr_ras_dp_err_inj               )
        ,.ras_dp_err_inj_mstr_aclk            (ras_dp_err_inj_mstr_aclk                      )
        ,.mstr_req_addr_parerr                ( mstr_req_addr_parerr[0]                      )
        ,.mstr_req_data_parerr                ( mstr_req_data_parerr                         )
        ,.mstr_req_ad_ras_dp_err_log          ( mstr_req_ad_ras_dp_err_log[0]                )
        ,.mstr_req_dt_ras_dp_err_log          ( mstr_req_dt_ras_dp_err_log                   )

        ,.rdwrq_c2a_ram_addra                 ( ib_wreq_c2a_cdc_ram_addra)
        ,.rdwrq_c2a_ram_addrb                 ( ib_wreq_c2a_cdc_ram_addrb)
        ,.rdwrq_c2a_ram_wea                   ( ib_wreq_c2a_cdc_ram_wea  )
        ,.rdwrq_c2a_ram_enb                   ( ib_wreq_c2a_cdc_ram_enb  )
        ,.rdwrq_c2a_ram_doutb                 ( ib_wreq_c2a_cdc_ram_doutb)
        ,.rdwrq_c2a_ram_dina                  ( ib_wreq_c2a_cdc_ram_dina )
        ,.dcp_inbd_hdr_pnp                    ( wrq_inbd_hdr_pnp                             )
        ,.dcp_inbd_hdr_np_valid               ( wrq_inbd_hdr_np_valid                        )
        ,.dcp_inbd_hdr_ncbe                   ( wrq_inbd_hdr_ncbe                            )
        ,.dcp_inbd_hdr_low_addr               ( wrq_inbd_hdr_low_addr                        )
        ,.dcp_inbd_hdr_byte_len               ( wrq_inbd_hdr_byte_len                        )
        ,.dcp_inbd_hdr_mstr_id                ( wrq_inbd_hdr_mstr_id                         )
        ,.dcp_inbd_hdr_lookupid               ( wrq_inbd_hdr_lookupid                        )
        ,.dcp_inbd_hdr_func                   ( wrq_inbd_hdr_func                            )
        ,.dcp_inbd_hdr_dma_type               ( wrq_inbd_hdr_dma_type                        )
        ,.dcp_inbd_hdr_dma_chan               ( wrq_inbd_hdr_dma_chan                        )
        ,.dcp_inbd_hdr_last                   ( wrq_inbd_hdr_last                            )

        ,.halt_dcp                            ( arb_halt_wrq_dcp                             )

        ,.mrf_reqmcb_np_valid                 ( wrq_mrf_reqmcb_np_valid                      )
        ,.mrf_reqmcb_mstrid                   ( wrq_mrf_reqmcb_mstrid                        )
        ,.mrf_reqmcb_last                     ( wrq_mrf_reqmcb_last                          )
        ,.mrf_reqmcb_atomic                   ( wrq_mrf_reqmcb_atomic                        )
        ,.arbmcb_halt_mrf                     ( arbmcb_halt_wrq_mrf                          )

        ,.maddr                               ( wrq_maddr                                    )
        ,.mstrobe                             ( wrq_mwrite                                   )
        ,.mstrobe_last                        ( wrq_mwrite_last                              )
        ,.mlen                                ( wrq_mlen                                     )
        ,.mdata                               ( wrq_mdata                                    )
        ,.mbe                                 ( wrq_mbe                                      )
        ,.mbe_ctrl                            ( wrq_mbe_ctrl                                 )
        ,.mid                                 ( wrq_mid                                      )
        ,.mabort                              ( wrq_mabort                                   )
        ,.mlast                               ( wrq_mlast                                    )
        ,.mmisc                               ( wrq_mmisc                                    )
        ,.saccept                             ( wrq_saccept                                  )

        ,.presp_cmplt                         ( ibreq_presp_cmplt                            )
        ,.presp_stream                        ( ibreq_presp_stream                           )
        ,.presp_type                          ( ibreq_presp_type                             )
        );



endmodule
