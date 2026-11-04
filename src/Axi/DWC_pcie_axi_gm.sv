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
// ---    $Revision: #26 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_gm.sv#26 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Bridge/inbound/DWC_pcie_bridge_atop_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_axi_gm
  import DWC_pcie_bridge_atop_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    // ----------------------------------------------------------------
    // PARAMETERS
    // ----------------------------------------------------------------

    // External
    parameter AXI_DATA_WIDTH    = `CC_MSTR_BUS_DATA_WIDTH ,
    parameter AXI_ADDR_WIDTH    = `CC_MSTR_BUS_ADDR_WIDTH ,
    parameter AXI_LOCK_WIDTH    = `CC_AXI_LOCK_WIDTH ,
    parameter AXI_ID_WIDTH      = `CC_MSTR_BUS_ID_WIDTH_NP ,
   // parameter AXI_ID_WIDTH_EXT  = `CC_MSTR_BUS_ID_WIDTH_NP,
    parameter DC_INBD_MISCINFO_WD= `DC_INBD_MISCINFO_WD,
    parameter MSTR_MISC_INFO_WD = `MSTR_MISC_INFO_WD ,
    parameter RESP_MISC_INFO_WD = `MSTR_RESP_MISC_INFO_WD ,
    parameter BURST_LEN_PW      = `CC_MSTR_BURST_LEN_PW ,
    parameter MAX_MSTR_TAGS     = `CC_MAX_MSTR_TAGS,

    parameter AXI_AWPROT_0      = `GMX_AXI_AWPROT_0 ,
    parameter AXI_AWPROT_1      = `GMX_AXI_AWPROT_1 ,
    parameter AXI_AWPROT_2      = `GMX_AXI_AWPROT_2 ,

    parameter AXI_ARPROT_0      = `GMX_AXI_ARPROT_0 ,
    parameter AXI_ARPROT_1      = `GMX_AXI_ARPROT_1 ,
    parameter AXI_ARPROT_2      = `GMX_AXI_ARPROT_2 ,
    parameter CC_WR_CH_NP_RSP_QUEUE_DP      = `CC_WR_CH_NP_RSP_QUEUE_DP,
    parameter CC_WR_CH_NP_RSP_QUEUE_DP_LOG2 = `CC_WR_CH_NP_RSP_QUEUE_DP_LOG2,
    parameter CX_RAS_PROT_RANGE = `CX_RAS_PROT_RANGE,
    parameter CX_RAS_PARITY_MODE= `CX_RAS_PARITY_MODE,

    // Derived
    parameter AXI_STRB_WIDTH    = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter AXI_MTU_PW        = `CC_MSTR_MTU_PW,
    //NCBE
    parameter BE_CTRL_WD   = `CC_MSTR_BE_CTRL_WIDTH,

    parameter DC_DMA_TYPE_WIDTH         = `DC_DMA_TYPE_WIDTH,
    parameter CC_NUM_DMA_RD_CHAN        = `CC_NUM_DMA_RD_CHAN,
    parameter CC_NUM_DMA_WR_CHAN        = `CC_NUM_DMA_WR_CHAN,
    parameter CC_NUM_DMA_RD_CHAN_WIDTH  = `CC_NUM_DMA_RD_CHAN_WIDTH,
    parameter CC_NUM_DMA_WR_CHAN_WIDTH  = `CC_NUM_DMA_WR_CHAN_WIDTH,
    parameter CC_NUM_DMA_MAX_CHAN_WIDTH = `CC_NUM_DMA_MAX_CHAN_WIDTH,
    parameter NUM_AXI_ID                = `CC_MAX_MSTR_TAGS,

   parameter RX_TLP_PREFIX_WD  = `FLT_Q_PRFX_WIDTH,


    parameter TPH_ST_WD         = 8,
    parameter TPH_PH_WD         = 2,
    parameter TPH_TH_WD         = 1,
    parameter MISC_INFO_TPH_WD  = TPH_ST_WD + TPH_PH_WD + TPH_TH_WD,
    parameter CX_NVC_LOG2        = `CX_NVC_LOG2,
    parameter CC_AMBA_TLP_SEQ_WD = `CC_AMBA_TLP_SEQ_WD,
    parameter CX_TAG_SIZE        = `CX_TAG_SIZE,
    parameter P_N_PRESP_STREAMS  = `CX_NVC,
    parameter P_N_PRESP_STREAMS_WD = `CX_NVC_LOG2,
    parameter P_N_PRESP_STREAMS_W_RO_WD = 1,
    parameter P_NP_PASS_P_WD     = 1 + `CX_NVC - 1 ,
    parameter type P_CFG_IB_P_ID_MNG_CTRL_TYPE = logic,
    parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 = `CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2,
    parameter TP                 = `TP // Clock to Q delay (simulator insurance)

    )
   
                         (
    // System
    input                                      aclk, // AXI Clock
    input                                      aresetn, // AXI Async Reset
    input                                      gclken, // Clock Enable

    input [3:0]                                cfg_mstr_arcache_mode,
    input [3:0]                                cfg_mstr_awcache_mode,
    input [3:0]                                cfg_mstr_arcache_value,
    input [3:0]                                cfg_mstr_awcache_value,
    input [1:0]                                cfg_mstr_ardomain_mode,
    input [1:0]                                cfg_mstr_awdomain_mode,
    input [1:0]                                cfg_mstr_ardomain_value,
    input [1:0]                                cfg_mstr_awdomain_value,
    input                                      cfg_ax_mstr_zeroread_fw,



    input P_CFG_IB_P_ID_MNG_CTRL_TYPE          cfg_ib_p_id_mng_ctrl,

    output wire                                axi_ras_par_ibr_rmstr_ad_pulse,
    output wire                                axi_ras_par_ibr_wmstr_ad_pulse,
    output wire                                axi_ras_par_ibr_wmstr_dt_pulse,
    output ras_dp_err_log_t                    axi_ibr_rmstr_ad_ras_dp_err_log,
    output ras_dp_err_log_t                    axi_ibr_wmstr_ad_ras_dp_err_log,
    output ras_dp_err_log_t                    axi_ibr_wmstr_dt_ras_dp_err_log,
    input ras_dp_err_inj_t                     ras_dp_err_inj_aclk,
  // Generic Interface
  // GIF Request
    input [AXI_ADDR_WIDTH-1:0]                 wrq_maddr, // Address
    input                                      wrq_mwrite, // Write Req
    input [AXI_MTU_PW -1:0]                    wrq_mlen, // Length
    input [AXI_ID_WIDTH-2:0]                   wrq_mid, // ID
    input [BE_CTRL_WD-1:0]                     wrq_mbe_ctrl, // byte enable ctrl for NCBE
    input                                      wrq_mlast_tlp, // last tlp req
    input [AXI_DATA_WIDTH-1:0]                 wrq_mdata, // Write Data
    input [AXI_STRB_WIDTH-1:0]                 wrq_mwstrb, // Write Strobes
    input [DC_INBD_MISCINFO_WD-1:0]            wrq_mmisc_info, // Misc Info
    input                                      wrq_mabort, // Aborted request (TLP, DLLP, ECRC)
    output wire                                wrq_saccept, // Accept
    input [AXI_ADDR_WIDTH-1:0]                 rdq_maddr, // Address
    input                                      rdq_mread, // Read Req
    input [AXI_MTU_PW -1:0]                    rdq_mlen, // Length
    input [AXI_ID_WIDTH-2:0]                   rdq_mid, // ID
    input [BE_CTRL_WD-1:0]                     rdq_mbe_ctrl, // byte enable ctrl for NCBE
    input                                      rdq_mlast_tlp, // last tlp req
    input [AXI_DATA_WIDTH-1:0]                 rdq_mdata, // Write Data
    input [AXI_STRB_WIDTH-1:0]                 rdq_mwstrb, // Write Strobes
    input [DC_INBD_MISCINFO_WD-1:0]            rdq_mmisc_info, // Misc Info
    input                                      rdq_mabort, // Aborted request (TLP, DLLP, ECRC)
    output wire                                rdq_saccept, // Accept


    // MCB Response
    output logic                                svalid, // Valid
    output logic                                slast, // Last
    output logic [AXI_DATA_WIDTH-1:0]           sdata,
    output logic [RESP_MISC_INFO_WD-1:0]        smisc_info, // Misc Info
    output logic [2:0]                          sresp, // Response
    output logic [`DC_CPL_STATUS_WD-1:0]        smisc_info_cpl_stat, // MISC Info completion status
    output logic [AXI_ID_WIDTH-2:0]             sid, // ID
    output logic [AXI_STRB_WIDTH -1:0]          sbyte_en, // byte enable
    input                                       mready, // Ready

  // AXI Master

  // AXI Write Request
    output wire [AXI_ID_WIDTH-1:0]             awid, // ID
    output wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] awid_extra,
    output wire                                awvalid, // Valid
    output wire [AXI_ADDR_WIDTH-1:0]           awaddr, // Address
    output wire [BURST_LEN_PW -1:0]            awlen, // Length
    output wire [2:0]                          awsize, // Size
    output wire [1:0]                          awburst, // Burst Type
    output wire [AXI_LOCK_WIDTH-1:0]           awlock, // Lock
    output wire [3:0]                          awcache, // Cache
    output wire [2:0]                          awprot, // Protect

    output wire [CX_TAG_SIZE+39:0]             awmisc_info,
    output wire [63:0]                         awmisc_info_hdr_34dw,
    output wire                                awmisc_info_last_dcmp_tlp,
    input  wire [`MASTER_BUS_ADDR_WIDTH-1:0]   msg_addr,
    input  wire [(`CC_MSTR_BUS_ADDR_WIDTH-`MASTER_BUS_ADDR_WIDTH)-1:0] msg_addrp,
    output wire                                awmisc_info_nw,
    output wire                                awmisc_info_cxlsrc,
    output wire [1:0]                          awmisc_info_ats,
    output wire                                awmisc_info_ep,
    output wire [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] awmisc_info_dma,
    output wire [RX_TLP_PREFIX_WD-1:0]         awmisc_info_tlpprfx,
    output wire [MISC_INFO_TPH_WD-1:0]         awmisc_info_tph,
    output wire                                awmisc_info_ido,
    output wire [8:0]                          awmisc_info_dst_segment,
    output wire [8:0]                          awmisc_info_req_segment,
    output wire [3:0]                          awqos, // Quality of Service
    output wire [1:0]                          awdomain, // Domain
    output wire [1:0]                          awbar, // Barrier
    output wire [`CC_AXIJ_DMWR_VALUE *2+2:0]   awsnoop, // Snoop
    output pkg_atop_awatop_e                   awatop, // Atomic Op code
    input                                      awready, // Ready

  // AXI Write Data
    output wire [AXI_ID_WIDTH-1:0]             wid, // ID
    output wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] wid_extra,
    output wire                                wvalid, // Valid
    output wire                                wlast, // Last
    output wire [AXI_DATA_WIDTH-1:0]           wdata, // Wr Data
    output wire [AXI_STRB_WIDTH-1:0]           wstrb, // Strobe
    input                                      wready, // Ready

  // AXI Write Response
    input [AXI_ID_WIDTH-1:0]                   bid, // ID
    input [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0]    bid_extra,
    input                                      bvalid, // Valid
    input [1:0]                                bresp, // Response
    input [`DC_CPL_STATUS_WD-1:0]              bmisc_info_cpl_stat, // MISC info completion status selction
    output                                     bready, // Ready
    input                                      b_rsp_atop_flag, // Flag for Atomic Response, exclusive for ID 0.
  // AXI Read Request
    output wire [AXI_ID_WIDTH-1:0]             arid, // ID
    output wire                                arvalid, // Valid
    output wire [AXI_ADDR_WIDTH-1:0]           araddr, // Address
    output wire [BURST_LEN_PW -1:0]            arlen, // Length
    output wire [2:0]                          arsize, // Size
    output wire [1:0]                          arburst, // Burst Type
    output wire [AXI_LOCK_WIDTH-1:0]           arlock, // Lock
    output wire [3:0]                          arcache, // Cache
    output wire [2:0]                          arprot, // Protect

    output wire [CX_TAG_SIZE+39:0]             armisc_info,
    output wire                                armisc_info_last_dcmp_tlp,
    output wire                                armisc_info_nw,
    output wire                                armisc_info_cxlsrc,
    output wire [1:0]                          armisc_info_ats,
    output wire [CC_NUM_DMA_MAX_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] armisc_info_dma,
    output wire [RX_TLP_PREFIX_WD-1:0]         armisc_info_tlpprfx,
    output wire [MISC_INFO_TPH_WD-1:0]         armisc_info_tph,
    output wire                                armisc_info_ido,
    output wire [8:0]                          armisc_info_dst_segment,
    output wire [8:0]                          armisc_info_req_segment,
    output wire                                armisc_info_zeroread,
    output wire [3:0]                          arqos, // Quality of Service
    output wire [1:0]                          ardomain, // Domain
    output wire [1:0]                          arbar, // Barrier
    output wire [3:0]                          arsnoop, // Snoop
    input                                      arready, // Ready

    // AXI read response & read data
    input [AXI_ID_WIDTH-2:0]                   rid, // ID
    input                                      rvalid, // Valid
    input                                      rlast, // Last
    input [AXI_DATA_WIDTH-1:0]                 rdata, // Data
    input [RESP_MISC_INFO_WD-1:0]              rmisc_info, // Misc Info
    input [1:0]                                rresp, // Response
    input [`DC_CPL_STATUS_WD-1:0]              rmisc_info_cpl_stat, // Completion status selection for read requests
    output wire                                rready, // Ready

  // AXI low power
    input                                      csysreq, // Request
    output wire                                csysack, // Acknowledge
    output wire                                cactive, // Active

    // Posted responses
    output wire                                gm_presp_cmplt ,
    output wire [CC_AMBA_TLP_SEQ_WD-1:0]       gm_presp_rpseq ,
    output wire [1:0]                          gm_presp_type ,
    output wire [P_N_PRESP_STREAMS_WD-1:0]     gm_presp_stream,
    output wire [CC_NUM_DMA_RD_CHAN_WIDTH-1:0] gm_presp_dma_chan_num ,
    output wire                                gm_presp_dma_err ,
    output wire                                gm_presp_cfg_cmplt,
    output wire [CC_AMBA_TLP_SEQ_WD-1:0]       gm_presp_cfg_rpseq,
    output wire                                gm_presp_cfg_type,
    output wire [P_N_PRESP_STREAMS_WD-1:0]     gm_presp_cfg_stream,
    input                                      rtime_cdc_halt,
    input                                      rtime_cfg_cdc_halt,
    input                                      rtime_cfg_cdc_alm_halt,
    // Graceful termination
    input                                      stop_req,
    output wire                                stop_done,
    output wire                                stop_resp_done

    );

   localparam [8:0] AXI_DATA_INIT_BYTE = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
    // Number of parity address blocks per 32/64 bit address
   localparam NUM_ADDR_PAR_BLOCKS  = `MASTER_BUS_ADDR_WIDTH / `CX_RAS_PROT_RANGE;
   localparam NUM_DATA_PAR_BLOCKS  = `MASTER_BUS_DATA_WIDTH / `CX_RAS_PROT_RANGE;
   localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

   localparam WMSTR_AD_RAS_ID =  `IBR_WMSTR_AD_RAS_ID;
   localparam RMSTR_AD_RAS_ID =  `IBR_RMSTR_AD_RAS_ID;
   localparam WMSTR_DT_RAS_ID =  `IBR_WMSTR_DT_RAS_ID;

   localparam AXI_DATA_N_BYTES   = `MASTER_BUS_DATA_WIDTH/8;

   localparam P_FEED_READY_RS = 1
                                - 1
                                 ;

   wire                                        wrq_svalid;
   wire                                        wrq_slast;
   wire [RESP_MISC_INFO_WD-1:0]                wrq_smisc_info;
   wire [2:0]                                  wrq_sresp;
   wire [`DC_CPL_STATUS_WD-1:0]                wrq_smisc_info_cpl_stat;
   wire [AXI_ID_WIDTH-2:0]                     wrq_sid;
   wire [AXI_STRB_WIDTH -1:0]                  wrq_sbyte_en;
   wire                                        wrq_mready;

   wire                                        rdq_svalid;
   wire                                        rdq_slast;
   wire [AXI_DATA_WIDTH-1:0]                   rdq_sdata;
   wire [RESP_MISC_INFO_WD-1:0]                rdq_smisc_info;
   wire [2:0]                                  rdq_sresp;
   wire [`DC_CPL_STATUS_WD-1:0]                rdq_smisc_info_cpl_stat;
   wire [AXI_ID_WIDTH-2:0]                     rdq_sid;
   wire [AXI_STRB_WIDTH -1:0]                  rdq_sbyte_en;
   wire                                        rdq_mready;

   wire [AXI_ID_WIDTH-1:0]      gmc_arid;

   // AXI read response & read data RS stands for register slice
   wire                                aximr_rvalid              ;
   wire [AXI_ID_WIDTH-2:0]             aximr_rid                 ;
   wire                                aximr_rlast               ;
   wire [AXI_DATA_WIDTH-1:0]           aximr_rdata               ;
   wire [RESP_MISC_INFO_WD-1:0]        aximr_rmisc_info          ;
   wire [1:0]                          aximr_rresp               ;
   wire [`DC_CPL_STATUS_WD-1:0]        aximr_rmisc_info_cpl_stat ;
   wire                                aximr_rready              ;

    // ARB MCB Response
   wire                                ma_svalid; // Valid
   wire                                ma_slast; // Last
   wire [AXI_DATA_WIDTH-1:0]           ma_sdata;
   wire [RESP_MISC_INFO_WD-1:0]        ma_smisc_info; // Misc Info

   wire [2:0]                          ma_sresp; // Response
   wire [`DC_CPL_STATUS_WD-1:0]        ma_smisc_info_cpl_stat; // MISC Info completion status
   wire [AXI_ID_WIDTH-2:0]             ma_sid; // ID
   wire [AXI_STRB_WIDTH -1:0]          ma_sbyte_en; // byte enable
   wire                                dly_mready;
   wire                                dly_mready_n;
   wire                                mready_n;

   wire                                rs_wmisc_info_is_p;
   wire                                rs_wvalid;
   wire                                rs_wready;
   wire                                rs_wready_int;
   wire                                rs_wlast;

   wire [AXI_ID_WIDTH-1:0]             mw_arid;
   wire                                mw_arvalid;
   wire [AXI_ADDR_WIDTH-1:0]           mw_araddr;
   wire [BURST_LEN_PW -1:0]            mw_arlen;
   wire [2:0]                          mw_arsize;
   wire [1:0]                          mw_arburst;
   wire [AXI_LOCK_WIDTH-1:0]           mw_arlock;
   wire [3:0]                          mw_arcache;
   wire [CX_TAG_SIZE+39:0]             mw_armisc_info;
   wire                                mw_armisc_info_last_dcmp_tlp;
   wire                                mw_armisc_info_nw;
   wire                                mw_armisc_info_cxlsrc;
   wire [1:0]                          mw_armisc_info_ats;
   wire [CC_NUM_DMA_MAX_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] mw_armisc_info_dma;
   wire [RX_TLP_PREFIX_WD-1:0]         mw_armisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]         mw_armisc_info_tph;
   wire                                mw_armisc_info_ido;
   wire [8:0]                          mw_armisc_info_dst_segment;
   wire [8:0]                          mw_armisc_info_req_segment;
   wire                                mw_armisc_info_zeroread;
   wire [3:0]                          mw_arqos;
   wire [1:0]                          mw_ardomain;
   wire [1:0]                          mw_arbar;
   wire [3:0]                          mw_arsnoop;
   wire                                rs_arready;

   wire [AXI_ID_WIDTH-1:0]             mw_awid;
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] mw_awid_extra;
   wire                                mw_awid_ro_remapped;
   wire                                mw_awvalid;
   wire                                mw_awvalid_int;
   wire [AXI_ADDR_WIDTH-1:0]           mw_awaddr;
   wire [BURST_LEN_PW -1:0]            mw_awlen;
   wire [2:0]                          mw_awsize;
   wire [1:0]                          mw_awburst;
   wire [AXI_LOCK_WIDTH-1:0]           mw_awlock;
   wire [3:0]                          mw_awcache;

   wire                                mw_awmisc_info_nw;
   wire                                mw_awmisc_info_cxlsrc;
   wire [1:0]                          mw_awmisc_info_ats;
   wire                                mw_awmisc_info_ep;
   wire [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] mw_awmisc_info_dma;
   wire [RX_TLP_PREFIX_WD-1:0]         mw_awmisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]         mw_awmisc_info_tph;
   wire                                mw_awmisc_info_ido;
   wire [8:0]                          mw_awmisc_info_dst_segment;
   wire [8:0]                          mw_awmisc_info_req_segment;
   wire [3:0]                          mw_awqos;
   wire [1:0]                          mw_awdomain;
   wire [1:0]                          mw_awbar;
   wire [`CC_AXIJ_DMWR_VALUE *2+2:0]   mw_awsnoop;
   pkg_atop_awatop_e                   mw_awatop;
   wire [CX_TAG_SIZE+39:0]             mw_awmisc_info;
   wire                                mw_awmisc_info_is_p;
   wire                                mw_awmisc_info_last_dcmp_tlp;
   wire [63:0]                         mw_awmisc_info_hdr_34dw;
   wire [63:0]                         mw_awmisc_info_hdr_34dw_addr;

   wire [AXI_ID_WIDTH-1:0]             s_mw_awid;
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] s_mw_awid_extra;
   wire                                s_mw_awid_ro_remapped;
   wire                                s_mw_awvalid;
   wire                                s_mw_awvalid_int;
   wire [AXI_ADDR_WIDTH-1:0]           s_mw_awaddr;
   wire [BURST_LEN_PW -1:0]            s_mw_awlen;
   wire [2:0]                          s_mw_awsize;
   wire [1:0]                          s_mw_awburst;
   wire [AXI_LOCK_WIDTH-1:0]           s_mw_awlock;
   wire [3:0]                          s_mw_awcache;

   wire                                s_mw_awmisc_info_nw;
   wire                                s_mw_awmisc_info_cxlsrc;
   wire [1:0]                          s_mw_awmisc_info_ats;
   wire                                s_mw_awmisc_info_ep;
   wire [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] s_mw_awmisc_info_dma;
   wire [RX_TLP_PREFIX_WD-1:0]         s_mw_awmisc_info_tlpprfx;
   wire [MISC_INFO_TPH_WD-1:0]         s_mw_awmisc_info_tph;
   wire                                s_mw_awmisc_info_ido;
   wire [8:0]                          s_mw_awmisc_info_dst_segment;
   wire [8:0]                          s_mw_awmisc_info_req_segment;
   wire [3:0]                          s_mw_awqos;
   wire [1:0]                          s_mw_awdomain;
   wire [1:0]                          s_mw_awbar;
   wire [`CC_AXIJ_DMWR_VALUE *2+2:0]   s_mw_awsnoop;
   pkg_atop_awatop_e                   s_mw_awatop;
   wire [CX_TAG_SIZE+39:0]             s_mw_awmisc_info;
   wire                                s_mw_awmisc_info_is_p;
   wire                                s_mw_awmisc_info_last_dcmp_tlp;
   wire [63:0]                         s_mw_awmisc_info_hdr_34dw;

   wire                                rs_awready;
   wire                                rs_awready_int;

   wire [AXI_ID_WIDTH-1:0]             mw_wid;
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] mw_wid_extra;
   wire                                mw_wvalid;
   wire                                mw_wvalid_int;
   wire                                mw_wlast;
   wire [AXI_DATA_WIDTH-1:0]           mw_wdata;
   wire [AXI_STRB_WIDTH-1:0]           mw_wstrb;
   wire                                mw_wmisc_info_is_p;

   wire                                is_msg_not_xlate;

   wire                                is_msg_xlate;



    logic                              wrq_saccept_aux;
   pkg_atop_writeq_to_gmread_s         wrq_to_rdq     ;
   pkg_atop_writeq_to_gmread_s         wrq_filler     ;
    logic                              rdq_mwr_stall  ;

  // Address from cdm reg interleaved with parity generated in RASDP block
   wire [AXI_ADDR_WIDTH -1 : 0]        msg_addr_wpar;

   logic s_enforce_wlast_ordering;
   logic [P_N_PRESP_STREAMS_WD -1:0] mw_wstream;

   //Gracedull reset not supported yet
   assign stop_done = 1'b0;
   assign stop_resp_done = 1'b0;

   // Static Outputs For Now
   assign awprot[0] = AXI_AWPROT_0;
   assign awprot[1] = AXI_AWPROT_1;
   assign awprot[2] = AXI_AWPROT_2;
   assign arprot[0] = AXI_ARPROT_0;
   assign arprot[1] = AXI_ARPROT_1;
   assign arprot[2] = AXI_ARPROT_2;

   //AXI read response channel pipelining (register slicing)
   DWC_pcie_axi_rs
   
     #(
       .P_FEED_READY (P_FEED_READY_RS)
      ,.CHAN_WD      (
                      AXI_ID_WIDTH-1 +
                      1+
                      AXI_DATA_WIDTH+
                      RESP_MISC_INFO_WD+
                      2+
                      `DC_CPL_STATUS_WD
                      )
       ) u_readRegSlice(
        .clk           (aclk),
        .rstn          (aresetn),
        .clrn          (1'b1),
        .vld_from_src  (rvalid),
        .chanl_from_src({
                         rid,
                         rlast,
                         rdata,
                         rmisc_info,
                         rresp,
                         rmisc_info_cpl_stat
                         }),
        .rdy_from_dest (aximr_rready),
        .vld_to_dest   (aximr_rvalid),
        .chanl_to_dest ({
                         aximr_rid,
                         aximr_rlast,
                         aximr_rdata,
                         aximr_rmisc_info,
                         aximr_rresp,
                         aximr_rmisc_info_cpl_stat
                         }),
        .rdy_to_src    (rready)
        );

   wire [1:0]                        i_gm_presp_cfg_type;
   assign gm_presp_cfg_type = i_gm_presp_cfg_type[0];

   wire [AXI_ADDR_WIDTH -1 : 0] mw_awaddr_int;
   wire mw_awmisc_info_hdr_uppr_bytes_valid;

   assign wrq_filler.w_wq_write    = '0 ;
   assign wrq_filler.w_wq_ready    = '0 ;
   assign wrq_filler.w_wq_id       = '0 ;
   assign wrq_filler.w_wq_len      = '0 ;
   assign wrq_filler.w_wq_last     = '0 ;
   assign wrq_filler.w_wq_addr     = '0 ;
   assign wrq_filler.w_wq_fmt_type = pkg_atop_fmt_type_e'({wrq_mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH :`MSTR_MISCINF_RANGE_TLP_FMT_LOW ],
                                                           wrq_mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]}
                                                         );
   assign wrq_filler.w_wq_mmisc_info_tc = '0;
   assign wrq_filler.w_wq_mmisc_info_ro = '0;
   assign wrq_filler.w_wq_mmisc_info_ns = '0;

   DWC_pcie_axi_gm_core
   
     #(
        .WR_NOT_RD_QUEUE                (1                            ) //write instance
        ,.AXI_DATA_WIDTH                (AXI_DATA_WIDTH               )
        ,.AXI_ADDR_WIDTH                (AXI_ADDR_WIDTH               )
        ,.AXI_ID_WIDTH                  (AXI_ID_WIDTH-1               )
        ,.DC_INBD_MISCINFO_WD           (DC_INBD_MISCINFO_WD          )
        ,.MSTR_MISC_INFO_WD             (MSTR_MISC_INFO_WD            )
        ,.RESP_MISC_INFO_WD             (RESP_MISC_INFO_WD            )
        ,.TPH_ST_WD                     (TPH_ST_WD                    )
        ,.TPH_PH_WD                     (TPH_PH_WD                    )
        ,.TPH_TH_WD                     (TPH_TH_WD                    )
        ,.MISC_INFO_TPH_WD              (MISC_INFO_TPH_WD             )
        ,.CC_AMBA_TLP_SEQ_WD            (CC_AMBA_TLP_SEQ_WD           )
        ,.CC_WR_CH_NP_RSP_QUEUE_DP      (CC_WR_CH_NP_RSP_QUEUE_DP     )
        ,.CC_WR_CH_NP_RSP_QUEUE_DP_LOG2 (CC_WR_CH_NP_RSP_QUEUE_DP_LOG2)
        ,.DC_DMA_TYPE_WIDTH             (DC_DMA_TYPE_WIDTH            )
        ,.CC_NUM_DMA_RD_CHAN            (CC_NUM_DMA_RD_CHAN           )
        ,.CC_NUM_DMA_RD_CHAN_WIDTH      (CC_NUM_DMA_RD_CHAN_WIDTH     )
        ,.CC_NUM_DMA_MAX_CHAN_WIDTH     (CC_NUM_DMA_MAX_CHAN_WIDTH    )
        ,.P_N_PRESP_STREAMS             (P_N_PRESP_STREAMS            )
        ,.P_N_PRESP_STREAMS_WD          (P_N_PRESP_STREAMS_WD         )
        ,.P_N_PRESP_STREAMS_W_RO_WD     (P_N_PRESP_STREAMS_W_RO_WD    )
        ,.P_CFG_IB_P_ID_MNG_CTRL_TYPE   (P_CFG_IB_P_ID_MNG_CTRL_TYPE  )
        ,.P_NP_PASS_P_WD                (P_NP_PASS_P_WD               )
        ) u_aximw
       (
        .aclk                             (aclk),
        .aresetn                          (aresetn),
        .gclken                           (gclken),
        .cfg_mstr_arcache_mode            (cfg_mstr_arcache_mode),
        .cfg_mstr_awcache_mode            (cfg_mstr_awcache_mode),
        .cfg_mstr_arcache_value           (cfg_mstr_arcache_value),
        .cfg_mstr_awcache_value           (cfg_mstr_awcache_value),
        .cfg_mstr_ardomain_mode           (cfg_mstr_ardomain_mode),
        .cfg_mstr_awdomain_mode           (cfg_mstr_awdomain_mode),
        .cfg_mstr_ardomain_value          (cfg_mstr_ardomain_value),
        .cfg_mstr_awdomain_value          (cfg_mstr_awdomain_value),
        .cfg_ib_p_id_mng_ctrl             (cfg_ib_p_id_mng_ctrl),
        .cfg_ax_mstr_zeroread_fw          (1'b1),
        .slast                            (wrq_slast),
        .sdata                            (),
        .sresp                            (wrq_sresp),
        .smisc_info_cpl_stat              (wrq_smisc_info_cpl_stat),
        .sid                              (wrq_sid),
        .sbyte_en                         (wrq_sbyte_en),
        .smisc_info                       (wrq_smisc_info),
        .awvalid                          (mw_awvalid_int),
        .awaddr                           (mw_awaddr_int),
        .awlen                            (mw_awlen),
        .awsize                           (mw_awsize),
        .awburst                          (mw_awburst),
        .awlock                           (mw_awlock),
        .awcache                          (mw_awcache),
        .awready                          (rs_awready_int),
        .o_awid                           (mw_awid),
        .o_awid_extra                     (mw_awid_extra),
        .o_awid_ro_remapped               (mw_awid_ro_remapped),
        .awmisc_info                      (mw_awmisc_info),
        .awmisc_info_is_p                 (mw_awmisc_info_is_p),

        .awmisc_info_hdr_uppr_bytes_valid (mw_awmisc_info_hdr_uppr_bytes_valid),
        .awmisc_info_nw                   (mw_awmisc_info_nw),
        .awmisc_info_cxlsrc               (mw_awmisc_info_cxlsrc),
        .awmisc_info_ats                  (mw_awmisc_info_ats),
        .awmisc_info_ep                   (mw_awmisc_info_ep),
        .awmisc_info_dma                  (mw_awmisc_info_dma),
        .awmisc_info_tlpprfx              (mw_awmisc_info_tlpprfx),
        .awmisc_info_tph                  (mw_awmisc_info_tph),
        .awmisc_info_ido                  (mw_awmisc_info_ido),
        .awmisc_info_dst_segment          (mw_awmisc_info_dst_segment),
        .awmisc_info_req_segment          (mw_awmisc_info_req_segment),

        .awqos                            (mw_awqos),
        .awdomain                         (mw_awdomain),
        .awbar                            (mw_awbar),
        .awsnoop                          (mw_awsnoop),
        .awatop                           (mw_awatop),
        .wvalid                           (mw_wvalid_int),
        .wlast                            (mw_wlast),
        .wdata                            (mw_wdata),
        .wstrb                            (mw_wstrb),
        .wmisc_info_is_p                  (mw_wmisc_info_is_p),
        .wstream                          (mw_wstream),
        .wready                           (rs_wready_int),
        .o_wid                            (mw_wid),
        .o_wid_extra                      (mw_wid_extra),
        .bvalid                           (bvalid),
        .bresp                            (bresp),
        .bmisc_info_cpl_stat              (bmisc_info_cpl_stat),
        .bready                           (bready),
        .bid                              (bid),
        .bid_extra                        (bid_extra),
        .b_rsp_atop_flag                  (b_rsp_atop_flag),
        .arvalid                          (/*arvalid*/),
        .araddr                           (/*araddr*/),
        .arlen                            (/*arlen*/),
        .arsize                           (/*arsize*/),
        .arburst                          (/*arburst*/),
        .arlock                           (/*arlock*/),
        .arcache                          (/*arcache*/),
        .arready                          (1'b0),
        .o_arid                           (/*gmc_arid*/),

        .armisc_info                      (),
        .armisc_info_nw                   (),
        .armisc_info_cxlsrc               (),
        .armisc_info_ats                  (),
        .armisc_info_dma                  (),
        .armisc_info_tlpprfx              (),
        .armisc_info_tph                  (),
        .armisc_info_ido                  (),
        .armisc_info_dst_segment          (),
        .armisc_info_req_segment          (),
        .armisc_info_zeroread             (),
        .arqos                            (/*arqos*/),
        .ardomain                         (/*ardomain*/),
        .arbar                            (/*arbar*/),
        .arsnoop                          (/*arsnoop*/),
        .rvalid                           (1'b0),
        .rlast                            (1'b0),
        .rdata                            ({AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}}),

        .rid                              ({(AXI_ID_WIDTH-1){1'b0}}),
        .rresp                            (2'h0),
        .rmisc_info_cpl_stat              ({(`DC_CPL_STATUS_WD){1'b0}}),
        .rmisc_info                       ({RESP_MISC_INFO_WD{1'b0}}),
        .rready                           (/*rready*/),
        .csysreq                          (1'b0),
        .csysack                          (),
        .cactive                          (),
        //Posted Responses
        .rtime_cdc_halt                   (rtime_cdc_halt),
        .rtime_cfg_cdc_halt               (rtime_cfg_cdc_halt),
        .rtime_cfg_cdc_alm_halt           (rtime_cfg_cdc_alm_halt),
        .gm_presp_dma_chan_num            (gm_presp_dma_chan_num),
        .gm_presp_dma_err                 (gm_presp_dma_err     ),
        .gm_presp_cmplt                   (gm_presp_cmplt ),
        .gm_presp_rpseq                   (gm_presp_rpseq),
        .gm_presp_type                    (gm_presp_type  ),
        .gm_presp_stream                  (gm_presp_stream),

        .gm_presp_cfg_cmplt               (gm_presp_cfg_cmplt),
        .gm_presp_cfg_rpseq               (gm_presp_cfg_rpseq),
        .gm_presp_cfg_type                (i_gm_presp_cfg_type),
        .gm_presp_cfg_stream              (gm_presp_cfg_stream),
        .gm_presp_cfg_empty               (/*gm_presp_cfg_empty*/),

        //Picks up the AXI AW W channel at the output after the
        //register slice
        .rs_awvalid                       (awvalid),
        .rs_awid                          (awid[AXI_ID_WIDTH-2:0]),
        .rs_awready                       (awready),
        .rs_awmisc_info_is_p              (awmisc_info_is_p),
        .rs_wvalid                        (wvalid),
        .rs_wready                        (wready),
        .rs_wlast                         (wlast),
        .rs_wmisc_info_is_p               (rs_wmisc_info_is_p),
        .maddr                            (wrq_maddr),
        .mread                            (1'b0),
        .mwrite                           (wrq_mwrite),
        .mlen                             (wrq_mlen),
        .mready                           (wrq_mready),
        .mdata                            (wrq_mdata),
        .mwstrb                           (wrq_mwstrb),
        .mmisc_info                       (wrq_mmisc_info),
        .mid                              (wrq_mid),
        .mbe_ctrl                         (wrq_mbe_ctrl),
        .mabort                           (wrq_mabort),
        .mlast_tlp                        (wrq_mlast_tlp),
        .saccept                          (wrq_saccept_aux),
        .svalid                           (wrq_svalid)
       ,.stall_mwr_ready_atop             ()
       ,.rdq_mwr_stall                    (rdq_mwr_stall)
       ,.writeq                           (wrq_filler)
        );
assign wrq_saccept = wrq_saccept_aux
    & !rdq_mwr_stall
;

// Parity checker has been introduced after Msg/MsgD mux
// Addr taken from the CDM reg in the case if Msg/MsgD and needs check after the Mux
// Addr from the client interface in the case it is NOT a Msg/MsgD needs check after the Mux
  wire                              waddr_chk_en;
  assign  waddr_chk_en = mw_awvalid & rs_awready;


  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ), // Parity mode
    .PROT_RANGE                (`CX_RAS_PROT_RANGE             ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS            ),
    .PARITY_MODE               (`CX_RAS_PARITY_MODE            ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (`MASTER_BUS_ADDR_WIDTH         ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (WMSTR_AD_RAS_ID                )
  ) u_waddr_chk (
    .clk                       ( aclk                          ),
    .rst_n                     ( aresetn                       ),
    .din                       ( fn_addr_wo_par  (mw_awaddr)   ),
    .din_prot                  ( fn_prot_chkin_ad(mw_awaddr)   ),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( waddr_chk_en                  ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            (axi_ibr_wmstr_ad_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_aclk)
    );
   assign axi_ras_par_ibr_wmstr_ad_pulse   = axi_ibr_wmstr_ad_ras_dp_err_log.valid;

   wire                                wdata_chk_en;
   assign wdata_chk_en = mw_wvalid & rs_wready;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                           ),
    .RESETVAL                  (0                           ),
    .N_STAGES                  (0                           ),
    .CAN_STALL                 (0                           ),
    .RESET_STALL               (0                           ),
    .BUS_PROTECT_GEN_EN        (0                           ),
    .BUS_PROTECT_CHK_EN        (1                           ),
    .PROT_TYPE                 (1                           ), // Parity mode
    .PROT_RANGE                (CX_RAS_PROT_RANGE           ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS         ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE          ),
    .PROT_CORRECT_EN           (0                           ),
    .TOTAL_WIDTH               (`MASTER_BUS_DATA_WIDTH      ),
    .EXCLUDE_PROT_WIDTH        (0                           ),
    .RAS_DP_PROT_CHK_ID_BASE   (WMSTR_DT_RAS_ID             )
  ) u_wdata_chk (
    .clk                       ( aclk                       ),
    .rst_n                     ( aresetn                    ),
    .din                       ( fn_data_wo_par  (mw_wdata) ),
    .din_prot                  ( fn_prot_chkin_d (mw_wdata) ),
    .dout                      ( /* Not Connected */        ),
    .dout_prot                 ( /* Not Connected */        ),
    .en                        (1'b1                        ),
    .bypass                    (1'b0                        ),
    .stall                     (1'b0                        ),
    .stallout                  ( /* Not Connected */        ),
    .valid_in                  ( wdata_chk_en               ),
    .halt_out                  ( /* Not Connected */        ),
    .valid_out                 ( /* Not Connected */        ),
    .halt_in                   (1'b0                        ),
    .ras_dp_err_inband_kbd_in  (1'b0                        ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */        ),
    .ras_dp_err_log            (axi_ibr_wmstr_dt_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_aclk)
    );
   assign axi_ras_par_ibr_wmstr_dt_pulse   = axi_ibr_wmstr_dt_ras_dp_err_log.valid;


   //Function to interleave the parity address
   function automatic [AXI_ADDR_WIDTH -1 :0] add_addr_par;
      input [`MASTER_BUS_ADDR_WIDTH -1:0]   in_addr;
      input [(AXI_ADDR_WIDTH - `MASTER_BUS_ADDR_WIDTH)-1:0] in_par;
      integer               i, j;
      reg [AXI_ADDR_WIDTH-1:0] out_addr;
      begin
         out_addr =0;
         for (i=0; i<(AXI_ADDR_WIDTH - `MASTER_BUS_ADDR_WIDTH); i=i+1) begin
            for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
               out_addr[i*CX_RAS_PROT_RANGE +j+i] = in_addr[i*CX_RAS_PROT_RANGE +j];
            end
            out_addr[(i+1)*CX_RAS_PROT_RANGE + i] = in_par[i];
         end
         add_addr_par = out_addr[AXI_ADDR_WIDTH -1 : 0];
      end
   endfunction

   assign mw_awmisc_info_last_dcmp_tlp = wrq_mlast_tlp;
   assign mw_armisc_info_last_dcmp_tlp = rdq_mlast_tlp;



  // The AW address bus carries the pre-programmed address in case the transaction is a Msg/ MsgD type
  // the info on the address bus (actually the 3rd and 4th header DWs) would be on a separate MiscInfo bus
  // If the Msg has been translated by the ATU -(with single addr en), the  u_ibreq/u_msg_hdlr puts the 3rd and 4th DWs into
  // the first two beats of data payload. So if hdr_uppr_bytes_valid is set, awmisc_info_hdr_34dw is set to the first 2 data DWs
  assign is_msg_not_xlate = (mw_awmisc_info[23:22]==2'b10) && (!mw_awmisc_info_hdr_uppr_bytes_valid);
  assign is_msg_xlate     = (mw_awmisc_info[23:22]==2'b10) && (mw_awmisc_info_hdr_uppr_bytes_valid);

  logic [`MASTER_BUS_ADDR_WIDTH-1:0] mw_awmisc_info_hdr_34dw_addr_msaw;
  // parity decode for addr from Client in the case its a msg and is routed through a dedicated MiscInfo bus
  DWC_pcie_bridge_par_decode
  
    #(
      .CX_RAS_PROT_RANGE(CX_RAS_PROT_RANGE),
      .DBUS_WD_NP(`MASTER_BUS_ADDR_WIDTH)
     ) u_pr_msg_34dw_addr
     (
      .datap_in (mw_awaddr_int),
      .data_out (mw_awmisc_info_hdr_34dw_addr_msaw),
      .par_out  (/*not connected*/)
     );
  assign mw_awmisc_info_hdr_34dw_addr = {{(64-`MASTER_BUS_ADDR_WIDTH){1'b0}},mw_awmisc_info_hdr_34dw_addr_msaw};



  wire [63:0] mw_awmisc_info_hdr_34dw_data;


  wire [63:0] mw_wdata_34dw;

  // parity decode for data from Client in the case its an ATU translated msg and is routed through a dedicated
  // misc_info bus; misc_info doesn't have parity bits so we need to remove them before routing the data to the
  // misc_info
  DWC_pcie_bridge_par_decode
  
    #(
      .CX_RAS_PROT_RANGE(CX_RAS_PROT_RANGE),
      .DBUS_WD_NP(64)
     ) u_pr_msg_34dw_data
     (
      .datap_in (mw_wdata[(63+(64/CX_RAS_PROT_RANGE)):0]),
      .data_out (mw_wdata_34dw),
      .par_out  (/*not connected*/)
     );

  reg  [63:0] r_wdata_hdr_34dw;
  reg         r_reg_wdata_hdr_34dw;


  always@(posedge aclk or negedge aresetn) begin
    if(!aresetn)begin
      r_reg_wdata_hdr_34dw <= #TP 1'b0;
      r_wdata_hdr_34dw     <= #TP 64'h0;
    end else begin
      if(is_msg_xlate && mw_awvalid && !rs_awready)begin
        if(mw_wvalid && rs_wready && !r_reg_wdata_hdr_34dw) begin
          r_reg_wdata_hdr_34dw <= #TP 1'b1;
          r_wdata_hdr_34dw     <= #TP mw_wdata_34dw;
        end
      end else begin
        r_reg_wdata_hdr_34dw <= #TP 1'b0;
        r_wdata_hdr_34dw     <= #TP 64'h0;
      end
    end
  end

  assign mw_awmisc_info_hdr_34dw_data = r_reg_wdata_hdr_34dw ? r_wdata_hdr_34dw : mw_wdata_34dw;

  assign mw_awvalid     = mw_awvalid_int;
  assign rs_awready_int = rs_awready;
  assign mw_wvalid      = mw_wvalid_int;
  assign rs_wready_int  = rs_wready;

  assign mw_awmisc_info_hdr_34dw      = is_msg_not_xlate ? { { (64-`MASTER_BUS_ADDR_WIDTH){1'b0} }, mw_awmisc_info_hdr_34dw_addr[`MASTER_BUS_ADDR_WIDTH -1:0] } :
                                        is_msg_xlate     ? mw_awmisc_info_hdr_34dw_data :
                                                           64'h0;

  assign s_mw_awid                      = mw_awid;
  assign s_mw_awid_extra                = mw_awid_extra;
  assign s_mw_awid_ro_remapped          = mw_awid_ro_remapped;
  assign s_mw_awaddr                    = mw_awaddr;
  assign s_mw_awlen                     = mw_awlen;
  assign s_mw_awsize                    = mw_awsize;
  assign s_mw_awburst                   = mw_awburst;
  assign s_mw_awlock                    = mw_awlock;
  assign s_mw_awcache                   = mw_awcache;
  assign s_mw_awqos                     = mw_awqos;
  assign s_mw_awdomain                  = mw_awdomain;
  assign s_mw_awbar                     = mw_awbar;
  assign s_mw_awsnoop                   = mw_awsnoop;
  assign s_mw_awatop                    = mw_awatop;
  assign s_mw_awmisc_info_nw            = mw_awmisc_info_nw;
  assign s_mw_awmisc_info_cxlsrc        = mw_awmisc_info_cxlsrc;
  assign s_mw_awmisc_info_ats           = mw_awmisc_info_ats;
  assign s_mw_awmisc_info_ep            = mw_awmisc_info_ep;
  assign s_mw_awmisc_info_dma           = mw_awmisc_info_dma;
  assign s_mw_awmisc_info_tlpprfx       = mw_awmisc_info_tlpprfx;
  assign s_mw_awmisc_info_tph           = mw_awmisc_info_tph;
  assign s_mw_awmisc_info_ido           = mw_awmisc_info_ido;
  assign s_mw_awmisc_info_dst_segment   = mw_awmisc_info_dst_segment;
  assign s_mw_awmisc_info_req_segment   = mw_awmisc_info_req_segment;
  assign s_mw_awmisc_info_is_p          = mw_awmisc_info_is_p;
  assign s_mw_awmisc_info               = mw_awmisc_info;
  assign s_mw_awmisc_info_last_dcmp_tlp = mw_awmisc_info_last_dcmp_tlp;
  assign s_mw_awmisc_info_hdr_34dw      = mw_awmisc_info_hdr_34dw;







  assign msg_addr_wpar                = add_addr_par(msg_addr,msg_addrp);
  assign mw_awaddr                    = is_msg_not_xlate ? msg_addr_wpar: mw_awaddr_int;


  logic [5:0] awatop_s;
   //****************** Master Channel register slices ***************
   DWC_pcie_axi_rs
   
     #(
       .CHAN_WD(
                AXI_ID_WIDTH+
                `CX_IB_P_ID_MNG_EXTRA_ID_WD+
                AXI_ADDR_WIDTH+
                BURST_LEN_PW+
                3+
                2+
                AXI_LOCK_WIDTH+
                4+
                4+
                2+
                2+
                3+ `CC_AXIJ_DMWR_VALUE *2 +
                // awsnoop
                6+
                1+
                1+
                2+
                1+
                CC_NUM_DMA_RD_CHAN_WIDTH+
                DC_DMA_TYPE_WIDTH+
                RX_TLP_PREFIX_WD+
                MISC_INFO_TPH_WD+
                1+
                9+
                9+
                1+
                CX_TAG_SIZE+
                40+
                1+ // awmisc_info_ep
                64
                )
       ) u_awrs
       (
        .clk           (aclk),
        .rstn          (aresetn),
        .clrn          (1'b1),

        .vld_from_src  (mw_awvalid),
        .chanl_from_src({
                         s_mw_awid,
                         s_mw_awid_extra,
                         s_mw_awaddr,
                         s_mw_awlen,
                         s_mw_awsize,
                         s_mw_awburst,
                         s_mw_awlock,
                         s_mw_awcache,
                         s_mw_awqos,
                         s_mw_awdomain,
                         s_mw_awbar,
                         s_mw_awsnoop,
                         s_mw_awatop,
                         s_mw_awmisc_info_nw,
                         s_mw_awmisc_info_cxlsrc,
                         s_mw_awmisc_info_ats,
                         s_mw_awmisc_info_ep,
                         s_mw_awmisc_info_dma,
                         s_mw_awmisc_info_tlpprfx,
                         s_mw_awmisc_info_tph,
                         s_mw_awmisc_info_ido,
                         s_mw_awmisc_info_dst_segment,
                         s_mw_awmisc_info_req_segment,
                         s_mw_awmisc_info_is_p,
                         s_mw_awmisc_info,
                         s_mw_awmisc_info_last_dcmp_tlp,
                         s_mw_awmisc_info_hdr_34dw
                         }),
        .rdy_from_dest (awready),

        .vld_to_dest   (awvalid),
        .chanl_to_dest ({
                         awid,
                         awid_extra,
                         awaddr,
                         awlen,
                         awsize,
                         awburst,
                         awlock,
                         awcache,
                         awqos,
                         awdomain,
                         awbar,
                         awsnoop,
                         awatop_s,
                         awmisc_info_nw,
                         awmisc_info_cxlsrc,
                         awmisc_info_ats,
                         awmisc_info_ep,
                         awmisc_info_dma,
                         awmisc_info_tlpprfx,
                         awmisc_info_tph,
                         awmisc_info_ido,
                         awmisc_info_dst_segment,
                         awmisc_info_req_segment,
                         awmisc_info_is_p,
                         awmisc_info,
                         awmisc_info_last_dcmp_tlp,
                         awmisc_info_hdr_34dw
                         }),
        .rdy_to_src    (rs_awready)
        );

 assign awatop = pkg_atop_awatop_e'(awatop_s);
   DWC_pcie_axi_rs
   
     #(
       .CHAN_WD(
                AXI_ID_WIDTH+
                `CX_IB_P_ID_MNG_EXTRA_ID_WD+
                1+
                AXI_DATA_WIDTH+
                AXI_STRB_WIDTH+
                1
                )
       ) u_wrs
       (
        .clk           (aclk),
        .rstn          (aresetn),
        .clrn          (1'b1),

        .vld_from_src  (mw_wvalid),
        .chanl_from_src({
                         mw_wid,
                         mw_wid_extra,
                         mw_wlast,
                         mw_wdata,
                         mw_wstrb,
                         mw_wmisc_info_is_p
                         }),
        .rdy_from_dest (wready),

        .vld_to_dest   (wvalid),
        .chanl_to_dest ({
                         wid,
                         wid_extra,
                         wlast,
                         wdata,
                         wstrb,
                         rs_wmisc_info_is_p
                         }),
        .rdy_to_src    (rs_wready)
        );

   DWC_pcie_axi_rs
   
     #(
       .P_FEED_READY(P_FEED_READY_RS)
      ,.CHAN_WD(
                AXI_ID_WIDTH+
                AXI_ADDR_WIDTH+
                BURST_LEN_PW+
                3+
                2+
                AXI_LOCK_WIDTH+
                4+
                4+
                2+
                2+
                4+
                1+
                1+
                2+
                CC_NUM_DMA_MAX_CHAN_WIDTH+
                DC_DMA_TYPE_WIDTH+
                RX_TLP_PREFIX_WD+
                MISC_INFO_TPH_WD+
                1+
                9+
                9+
                1+
                CX_TAG_SIZE+
                40+
                1
                )
       ) u_arrs
       (
        .clk           (aclk),
        .rstn          (aresetn),
        .clrn          (1'b1),

        .vld_from_src  (mw_arvalid),
        .chanl_from_src({
                         mw_arid,
                         mw_araddr,
                         mw_arlen,
                         mw_arsize,
                         mw_arburst,
                         mw_arlock,
                         mw_arcache,
                         mw_arqos,
                         mw_ardomain,
                         mw_arbar,
                         mw_arsnoop,
                         mw_armisc_info_nw,
                         mw_armisc_info_cxlsrc,
                         mw_armisc_info_ats,
                         mw_armisc_info_dma,
                         mw_armisc_info_tlpprfx,
                         mw_armisc_info_tph,
                         mw_armisc_info_ido,
                         mw_armisc_info_dst_segment,
                         mw_armisc_info_req_segment,
                         mw_armisc_info_zeroread,
                         mw_armisc_info,
                         mw_armisc_info_last_dcmp_tlp
                         }),
        .rdy_from_dest (arready),

        .vld_to_dest   (arvalid),
        .chanl_to_dest ({
                         arid,
                         araddr,
                         arlen,
                         arsize,
                         arburst,
                         arlock,
                         arcache,
                         arqos,
                         ardomain,
                         arbar,
                         arsnoop,
                         armisc_info_nw,
                         armisc_info_cxlsrc,
                         armisc_info_ats,
                         armisc_info_dma,
                         armisc_info_tlpprfx,
                         armisc_info_tph,
                         armisc_info_ido,
                         armisc_info_dst_segment,
                         armisc_info_req_segment,
                         armisc_info_zeroread,
                         armisc_info,
                         armisc_info_last_dcmp_tlp
                         }),
        .rdy_to_src    (rs_arready)
        );


  logic [AXI_MTU_PW-1:0] wrq_burst_cnt;
  always@(posedge aclk or negedge aresetn) begin : wrq_burst_count
    if(~aresetn)
      wrq_burst_cnt <= #TP '0;
    else begin
      if (wrq_to_rdq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64}) begin
        if (wrq_mlen <= (wrq_burst_cnt + AXI_STRB_WIDTH) && wrq_saccept && wrq_mwrite) begin
          wrq_burst_cnt <= #TP '0;
        end else if (wrq_saccept & wrq_mwrite) begin
          wrq_burst_cnt <= #TP wrq_burst_cnt + AXI_STRB_WIDTH;
        end
      end
    end
  end
   assign wrq_to_rdq.w_wq_write    = wrq_mwrite            ;
   assign wrq_to_rdq.w_wq_ready    = wrq_saccept || awready;
   assign wrq_to_rdq.w_wq_id       = wrq_mid               ;
   assign wrq_to_rdq.w_wq_len      = wrq_to_rdq.w_wq_fmt_type inside {CAS32,CAS64} ? wrq_mlen >> 1 : wrq_mlen;
   assign wrq_to_rdq.w_wq_last     = (wrq_mlen <= (wrq_burst_cnt + AXI_STRB_WIDTH) && wrq_saccept && wrq_mwrite) ? 1'b1 : 1'b0   ;
   assign wrq_to_rdq.w_wq_addr     = wrq_maddr             ;
   assign wrq_to_rdq.w_wq_fmt_type = pkg_atop_fmt_type_e'({wrq_mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH :`MSTR_MISCINF_RANGE_TLP_FMT_LOW ],
                                                           wrq_mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]}
                                                         ) ;
   assign wrq_to_rdq.w_wq_mmisc_info_tc = wrq_mmisc_info[`MSTR_MISCINF_RANGE_TC_HIGH:`MSTR_MISCINF_RANGE_TC_LOW];
   assign wrq_to_rdq.w_wq_mmisc_info_ro = wrq_mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_RO_LOW];
   assign wrq_to_rdq.w_wq_mmisc_info_ns = wrq_mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_NS_LOW];

   DWC_pcie_axi_gm_core
   
     #(  .WR_NOT_RD_QUEUE               (0                  ) //read instance
        ,.AXI_DATA_WIDTH                ( AXI_DATA_WIDTH    )
        ,.AXI_ADDR_WIDTH                ( AXI_ADDR_WIDTH    )
        ,.AXI_ID_WIDTH                  ( AXI_ID_WIDTH-1    )
        ,.DC_INBD_MISCINFO_WD           (DC_INBD_MISCINFO_WD)
        ,.MSTR_MISC_INFO_WD             ( MSTR_MISC_INFO_WD )
        ,.RESP_MISC_INFO_WD             ( RESP_MISC_INFO_WD )
        ,.TPH_ST_WD                     ( TPH_ST_WD         )
        ,.TPH_PH_WD                     ( TPH_PH_WD         )
        ,.TPH_TH_WD                     ( TPH_TH_WD         )
        ,.MISC_INFO_TPH_WD              ( MISC_INFO_TPH_WD  )
        ,.DC_DMA_TYPE_WIDTH             (DC_DMA_TYPE_WIDTH            )
        ,.CC_NUM_DMA_RD_CHAN            (CC_NUM_DMA_RD_CHAN           )
        ,.CC_NUM_DMA_RD_CHAN_WIDTH      (CC_NUM_DMA_RD_CHAN_WIDTH     )
        ,.CC_NUM_DMA_MAX_CHAN_WIDTH     (CC_NUM_DMA_MAX_CHAN_WIDTH    )
        ,.P_N_PRESP_STREAMS             (P_N_PRESP_STREAMS            )
        ,.P_N_PRESP_STREAMS_WD          (P_N_PRESP_STREAMS_WD         )
        ,.P_N_PRESP_STREAMS_W_RO_WD     (P_N_PRESP_STREAMS_W_RO_WD    )
        ) u_aximr (
                   .aclk                   (aclk),
                   .aresetn                (aresetn),
                   .gclken                 (gclken),

                   .cfg_mstr_arcache_mode  (cfg_mstr_arcache_mode),
                   .cfg_mstr_awcache_mode  (cfg_mstr_awcache_mode),
                   .cfg_mstr_arcache_value (cfg_mstr_arcache_value),
                   .cfg_mstr_awcache_value (cfg_mstr_awcache_value),
                   .cfg_mstr_ardomain_mode (cfg_mstr_ardomain_mode),
                   .cfg_mstr_awdomain_mode (cfg_mstr_awdomain_mode),
                   .cfg_mstr_ardomain_value(cfg_mstr_ardomain_value),
                   .cfg_mstr_awdomain_value(cfg_mstr_awdomain_value),
                   .cfg_ib_p_id_mng_ctrl   ('0),
                   .cfg_ax_mstr_zeroread_fw(cfg_ax_mstr_zeroread_fw),
                   .saccept                (rdq_saccept),
                   .svalid                 (rdq_svalid),
                   .slast                  (rdq_slast),
                   .sdata                  (rdq_sdata),
                   .sresp                  (rdq_sresp),
                   .smisc_info_cpl_stat    (rdq_smisc_info_cpl_stat),
                   .sid                    (rdq_sid),
                   .sbyte_en               (rdq_sbyte_en),
                   .smisc_info             (rdq_smisc_info),
                   .awvalid                (),
                   .awaddr                 (),
                   .awlen                  (),
                   .awsize                 (),
                   .awburst                (),
                   .awlock                 (),
                   .awcache                (),
                   .awready                (1'b0),
                   .o_awid                 (),
                   .o_awid_extra           (),
                   .o_awid_ro_remapped     (),
                   .awmisc_info            (),
                   .awmisc_info_is_p       (),

                   .awmisc_info_hdr_uppr_bytes_valid  (),
                   .awmisc_info_nw          (),
                   .awmisc_info_cxlsrc      (),
                   .awmisc_info_ats         (),
                   .awmisc_info_ep          (),
                   .awmisc_info_dma         (),
                   .awmisc_info_tlpprfx     (),
                   .awmisc_info_tph         (),
                   .awmisc_info_ido         (),
                   .awmisc_info_dst_segment (),
                   .awmisc_info_req_segment (),

                   .awqos                  (),
                   .awdomain               (),
                   .awbar                  (),
                   .awsnoop                (),
                   .awatop                 (),
                   .wvalid                 (/*wvalid*/),
                   .wlast                  (/*wlast*/),
                   .wdata                  (/*wdata*/),
                   .wstrb                  (/*wstrb*/),
                   .wmisc_info_is_p        (/*wmisc_info_is_p*/),
                   .wstream                (/*wstream*/),
                   .wready                 (1'b0),
                   .o_wid                  (/*wid*/),
                   .o_wid_extra            (),
                   .bvalid                 (1'b0),
                   .bresp                  (2'h0),
                   .bmisc_info_cpl_stat    ({(`DC_CPL_STATUS_WD){1'b0}}),
                   .bready                 (/*bready*/),
                   .bid                    ({AXI_ID_WIDTH{1'b0}}),
                   .bid_extra              ('0),

                   .b_rsp_atop_flag        (1'b0),
                   .arvalid                (mw_arvalid),
                   .araddr                 (mw_araddr),
                   .arlen                  (mw_arlen),
                   .arsize                 (mw_arsize),
                   .arburst                (mw_arburst),
                   .arlock                 (mw_arlock),
                   .arcache                (mw_arcache),
                   .arready                (rs_arready),
                   .o_arid                 (gmc_arid),

                   .armisc_info             (mw_armisc_info),
                   .armisc_info_nw          (mw_armisc_info_nw),
                   .armisc_info_cxlsrc      (mw_armisc_info_cxlsrc),
                   .armisc_info_ats         (mw_armisc_info_ats),
                   .armisc_info_dma         (mw_armisc_info_dma),
                   .armisc_info_tlpprfx     (mw_armisc_info_tlpprfx),
                   .armisc_info_tph         (mw_armisc_info_tph),
                   .armisc_info_ido         (mw_armisc_info_ido),
                   .armisc_info_dst_segment (mw_armisc_info_dst_segment),
                   .armisc_info_req_segment (mw_armisc_info_req_segment),
                   .armisc_info_zeroread    (mw_armisc_info_zeroread),
                   .arqos                  (mw_arqos),
                   .ardomain               (mw_ardomain),
                   .arbar                  (mw_arbar),
                   .arsnoop                (mw_arsnoop),
                   .rvalid                 (aximr_rvalid),
                   .rlast                  (aximr_rlast),
                   .rdata                  (aximr_rdata),
                   .rid                    (aximr_rid),
                   .rresp                  (aximr_rresp),
                   .rmisc_info_cpl_stat    (aximr_rmisc_info_cpl_stat),
                   .rmisc_info             (aximr_rmisc_info),
                   .rready                 (aximr_rready),
                   .csysreq                (1'b0),
                   .csysack                (),
                   .cactive                (),
                       //Posted Responses
                   .rtime_cdc_halt         (rtime_cdc_halt),
                   .rtime_cfg_cdc_halt     (rtime_cfg_cdc_halt),
                   .rtime_cfg_cdc_alm_halt (rtime_cfg_cdc_alm_halt),
                   .gm_presp_dma_chan_num  (/*gm_presp_dma_chan_num*/),
                   .gm_presp_dma_err       (/*gm_presp_dma_err     */),
                   .gm_presp_cmplt         (/*gm_presp_cmplt */),
                   .gm_presp_rpseq         (/*gm_presp_rpseq*/),
                   .gm_presp_type          (/*gm_presp_type  */),
                   .gm_presp_stream        (/*gm_presp_stream*/),

                   .gm_presp_cfg_cmplt     (/*gm_presp_cfg_cmplt*/),
                   .gm_presp_cfg_rpseq     (/*gm_presp_cfg_rpseq*/),
                   .gm_presp_cfg_type      (/*i_gm_presp_cfg_type*/),
                   .gm_presp_cfg_stream    (/*gm_presp_cfg_stream*/),
                   .gm_presp_cfg_empty     (/*gm_presp_cfg_empty*/),

                   .rs_awvalid             (awvalid),
                   .rs_awid                (awid[AXI_ID_WIDTH-2:0]),
                   .rs_awready             (awready),
                   .rs_awmisc_info_is_p    (awmisc_info_is_p),
                   .rs_wvalid              (wvalid),
                   .rs_wready              (wready),
                   .rs_wlast               (wlast),
                   .rs_wmisc_info_is_p     (rs_wmisc_info_is_p),
                   .maddr                  (rdq_maddr),
                   .mread                  (rdq_mread),
                   .mwrite                 (1'b0),
                   .mlen                   (rdq_mlen),
                   .mready                 (rdq_mready),
                   .mdata                  (rdq_mdata),
                   .mwstrb                 (rdq_mwstrb),
                   .mmisc_info             (rdq_mmisc_info),
                   .mid                    (rdq_mid),
                   .mbe_ctrl               (rdq_mbe_ctrl),
                   .mabort                 (rdq_mabort),
                   .mlast_tlp              (rdq_mlast_tlp)
                  ,.stall_mwr_ready_atop   (rdq_mwr_stall)
                  ,.rdq_mwr_stall          (1'b0)
                  ,.writeq                 (wrq_to_rdq)
                   );

   DWC_pcie_axi_gm_mcb_arb
   
     #(
       .RESP_MISC_INFO_WD(RESP_MISC_INFO_WD),
       .AXI_ID_WIDTH     (AXI_ID_WIDTH-1    ),
       .AXI_STRB_WIDTH   (AXI_STRB_WIDTH   )
       ) u_marb
       (
                .clk                   (aclk                  ),
                .rstn                  (aresetn               ),
                .wrq_svalid            (wrq_svalid            ),
                .wrq_slast             (wrq_slast             ),
                .wrq_smisc_info        (wrq_smisc_info        ),
                .wrq_sresp             (wrq_sresp             ),
                .wrq_smisc_info_cpl_stat (wrq_smisc_info_cpl_stat),
                .wrq_sid               (wrq_sid               ),
                .wrq_sbyte_en          (wrq_sbyte_en          ),
                .wrq_mready            (wrq_mready            ),
                .rdq_svalid            (rdq_svalid            ),
                .rdq_sdata             (rdq_sdata             ),
                .rdq_slast             (rdq_slast             ),
                .rdq_smisc_info        (rdq_smisc_info        ),
                .rdq_sresp             (rdq_sresp             ),
                .rdq_smisc_info_cpl_stat (rdq_smisc_info_cpl_stat),
                .rdq_sid               (rdq_sid               ),
                .rdq_sbyte_en          (rdq_sbyte_en          ),
                .rdq_mready            (rdq_mready            ),

                .svalid                (ma_svalid             ),
                .slast                 (ma_slast              ),
                .sdata                 (ma_sdata              ),
                .smisc_info            (ma_smisc_info         ),
                .sresp                 (ma_sresp              ),
                .smisc_info_cpl_stat   (ma_smisc_info_cpl_stat),
                .sid                   (ma_sid                ),
                .sbyte_en              (ma_sbyte_en           ),
                .mready                ( dly_mready)
                );

                    assign mready_n = ~mready;
   assign dly_mready = ~dly_mready_n;

   delay_1_w_stalling
   
     #(.DELAY_EN   (1)
       ,.WD        (
                    1+
                    1+
                    AXI_DATA_WIDTH +
                    RESP_MISC_INFO_WD +
                    3 +
                    `DC_CPL_STATUS_WD +
                    (AXI_ID_WIDTH-1) +
                    AXI_STRB_WIDTH
                    )
       ,.CAN_STALL (1)
       )
   u_pdly1
     (
      .clk        (aclk),
      .rst_n      (aresetn),
      .din        (
                   {ma_svalid,
                    ma_slast,
                    ma_sdata,
                    ma_smisc_info,
                    ma_sresp,
                    ma_smisc_info_cpl_stat,
                    ma_sid,
                    ma_sbyte_en}
                    ),
      .stallout   (dly_mready_n),
      .clear      (1'b0),

      .dout       (
                   {svalid,
                    slast,
                    sdata,
                    smisc_info,
                    sresp,
                    smisc_info_cpl_stat,
                    sid,
                    sbyte_en}
                   ),
      .stall      (mready_n)
      );



   wire                                raddr_chk_en;
   assign  raddr_chk_en = mw_arvalid & rs_arready;
  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ), // Parity mode
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (`MASTER_BUS_ADDR_WIDTH         ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   ( RMSTR_AD_RAS_ID               )
  ) u_raddr_chk (
    .clk                       ( aclk                          ),
    .rst_n                     ( aresetn                       ),
    .din                       ( fn_addr_wo_par  (mw_araddr)   ),
    .din_prot                  ( fn_prot_chkin_ad(mw_araddr)   ),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( raddr_chk_en                  ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            (axi_ibr_rmstr_ad_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_aclk)
    );
   assign axi_ras_par_ibr_rmstr_ad_pulse   = axi_ibr_rmstr_ad_ras_dp_err_log.valid;

   // Internal wire assignments
   assign mw_arid = gmc_arid;

   assign cactive          = 1'b1;
   assign csysack          = 1'b1;


// -------------------------------------------------------------------------------------
// Functions
// -------------------------------------------------------------------------------------
  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [AXI_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  // Address without parity
  function automatic [`MASTER_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [AXI_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [AXI_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [`MASTER_BUS_DATA_WIDTH-1:0] fn_data_wo_par;
    input [AXI_DATA_WIDTH-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

endmodule
