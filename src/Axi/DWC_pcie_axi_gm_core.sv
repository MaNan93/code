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
// ---    $Revision: #43 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_gm_core.sv#43 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//
//  DWC_pcie_axi_gm_core.v Verilog module for DW_pcie design. This module
//  connects the AXI bus and the Master Request Formation modules, and controls the
//  request and repsponse data and control flow between the two.
//
//
//------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Bridge/inbound/DWC_pcie_bridge_atop_pkg.svh"
`include "Axi/DWC_pcie_axi_mstr_pkg.svh"

 module DWC_pcie_axi_gm_core (

          // Outputs
          saccept     ,
          svalid      ,
          slast       ,
          sid         ,
          sbyte_en    ,
          sdata       ,
          sresp       ,
          smisc_info_cpl_stat,
          smisc_info  ,
          stall_mwr_ready_atop,
          rdq_mwr_stall,
          o_awid      ,
          o_awid_extra,
          o_awid_ro_remapped,
          awvalid     ,
          awaddr      ,
          awlen       ,
          awsize      ,
          awburst     ,
          awlock      ,
          awcache     ,
          awmisc_info ,
          awmisc_info_is_p,
          awmisc_info_hdr_uppr_bytes_valid,
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

          awqos,
          awdomain,
          awbar,
          awsnoop,
          awatop,
          o_wid       ,
          o_wid_extra ,
          wvalid      ,
          wlast       ,
          wdata       ,
          wstrb       ,
          wstream     ,
          wmisc_info_is_p,
          bready      ,
          o_arid      ,
          arvalid     ,
          araddr      ,
          arlen       ,
          arsize      ,
          arburst     ,
          arlock      ,
          arcache     ,

          armisc_info ,
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
          arqos,
          ardomain,
          arbar,
          arsnoop,
          rready      ,
          csysack     ,
          cactive     ,

          // Inputs
          aclk        ,
          aresetn     ,
          gclken      ,

          cfg_mstr_arcache_mode  ,
          cfg_mstr_awcache_mode  ,
          cfg_mstr_arcache_value ,
          cfg_mstr_awcache_value ,
          cfg_mstr_ardomain_mode ,
          cfg_mstr_ardomain_value,
          cfg_mstr_awdomain_mode ,
          cfg_mstr_awdomain_value,
          cfg_ib_p_id_mng_ctrl,
          cfg_ax_mstr_zeroread_fw,
          awready     ,
          wready      ,
          bid         ,
          bid_extra   ,
          bvalid      ,
          bresp       ,
          bmisc_info_cpl_stat,
          b_rsp_atop_flag,
          arready     ,
          rid         ,
          rvalid      ,
          rlast       ,
          rdata       ,
          rresp       ,
          rmisc_info_cpl_stat,
          rmisc_info  ,
          csysreq,
      //Posted Responses
          rtime_cdc_halt,
          rtime_cfg_cdc_halt,
          rtime_cfg_cdc_alm_halt,
          rs_awvalid,
          rs_awid,
          rs_awready,
          rs_awmisc_info_is_p,
          rs_wvalid,
          rs_wready,
          rs_wlast,
          rs_wmisc_info_is_p,
          gm_presp_dma_chan_num,
          gm_presp_dma_err,
          gm_presp_cmplt,
          gm_presp_rpseq,
          gm_presp_type,
          gm_presp_stream,

          gm_presp_cfg_cmplt,
          gm_presp_cfg_rpseq,
          gm_presp_cfg_type,
          gm_presp_cfg_stream,
          gm_presp_cfg_empty,
          maddr       ,
          mread       ,
          mwrite      ,
          mlen        ,
          mdata       ,
          mwstrb      ,
          mready      ,
          mid         ,
          mbe_ctrl    ,
          mabort      ,
          mlast_tlp   ,
          mmisc_info
         ,writeq
          );

   import DWC_pcie_bridge_atop_pkg::*;
import DWC_pcie_axi_mstr_pkg::*;

   // -----------------------------------------------------------------
   // Parameters
   // -----------------------------------------------------------------
   // Static parameters
   parameter AXI_DATA_WIDTH           = `CC_MSTR_BUS_DATA_WIDTH;
   parameter AXI_ADDR_WIDTH           = `CC_MSTR_BUS_ADDR_WIDTH;
   parameter AXI_LOCK_WIDTH           = `CC_AXI_LOCK_WIDTH;
   parameter AXI_ID_WIDTH             = `CC_MAX_MSTR_TAG_PW;
   parameter AXI_ID_WIDTH_EXT         = `CC_MSTR_BUS_ID_WIDTH_NP;
   parameter CX_TAG_SIZE              = `CX_TAG_SIZE;
   parameter DC_INBD_MISCINFO_WD      = `DC_INBD_MISCINFO_WD;
   parameter MSTR_MISC_INFO_WD        = `MSTR_MISC_INFO_WD;
   parameter RESP_MISC_INFO_WD        = `MSTR_RESP_MISC_INFO_WD;

   parameter RX_TLP_PREFIX_WD         = `FLT_Q_PRFX_WIDTH;


   parameter TPH_ST_WD                = 8;
   parameter TPH_PH_WD                = 2;
   parameter TPH_TH_WD                = 1;
   parameter MISC_INFO_TPH_WD         = TPH_ST_WD + TPH_PH_WD + TPH_TH_WD;

   parameter AXI_STRB_WIDTH           = `CC_MSTR_BUS_WSTRB_WIDTH;
   parameter AXI_STRB_PW              = `CC_MSTR_BUS_WSTRB_WIDTH_PW;
   parameter AXI_BUS_BYTECNT_PW       = AXI_STRB_PW +1;

   //NCBE
   parameter BE_CTRL_WD               = `CC_MSTR_BE_CTRL_WIDTH;

   // Low Power FSM
   parameter BURST_LEN_PW             = `CC_MSTR_BURST_LEN_PW;
   parameter MSTR_MTU_PW              = `CC_MSTR_MTU_PW;
   parameter MSTR_BURST_TYPE          = `MSTR_BURST_TYPE;
   parameter MSTR_BURST_TYPE_WRAP      = `MSTR_BURST_TYPE_WRAP;
   parameter GM_AXI_SIZE              = `CC_GM_AMBA_SIZE;

   parameter DATA_BYTE_WD_W_PARITY    = AXI_DATA_WIDTH/AXI_STRB_WIDTH ;
   parameter CC_MAX_MSTR_TAGS         = `CC_MAX_MSTR_TAGS;

   parameter CC_WR_CH_P_REQ_QUEUE_DP      = `CC_WR_CH_P_REQ_QUEUE_DP;
   parameter CC_WR_CH_P_REQ_QUEUE_DP_LOG2 = `CC_WR_CH_P_REQ_QUEUE_DP_LOG2;

   parameter CC_MSTR_MAX_SPLIT_PACK_NARROW_RD    = `CC_MSTR_MAX_SPLIT_PACK_NARROW_RD;
   parameter CC_MSTR_MAX_SPLIT_PACK_NARROW_RD_PW = `CC_MSTR_MAX_SPLIT_PACK_NARROW_RD_PW;

   parameter CC_WR_CH_NP_RSP_QUEUE_DP      = `CC_WR_CH_NP_RSP_QUEUE_DP;
   parameter CC_WR_CH_NP_RSP_QUEUE_DP_LOG2 = `CC_WR_CH_NP_RSP_QUEUE_DP_LOG2;

   parameter CX_NVC_LOG2              = `CX_NVC_LOG2;
   parameter CC_AMBA_TLP_SEQ_WD       = `CC_AMBA_TLP_SEQ_WD;

   // Dynamic parameters
   parameter logic WR_NOT_RD_QUEUE    = 0;
   // Derived parameters
   // Since the maximum selectable AXI data width is 1024
   // the maximum AXI strobe PW is 7.
   parameter MAX_AXI_STRB_PW          = 7;
   //Physical function number width up to the max of 3
   parameter MAX3_NFUNC_WD            = (`CX_NFUNC_WD > 3) ? 3 : `CX_NFUNC_WD;

   parameter DC_DMA_TYPE_WIDTH                  = `DC_DMA_TYPE_WIDTH;
   parameter CC_NUM_DMA_RD_CHAN                 = `CC_NUM_DMA_RD_CHAN;
   parameter CC_NUM_DMA_RD_CHAN_WIDTH           = `CC_NUM_DMA_RD_CHAN_WIDTH;
   parameter CC_NUM_DMA_MAX_CHAN_WIDTH          = `CC_NUM_DMA_MAX_CHAN_WIDTH;
    parameter P_N_PRESP_STREAMS  = `CX_NVC;
    parameter P_N_PRESP_STREAMS_WD = `CX_NVC_LOG2;
    parameter P_N_PRESP_STREAMS_W_RO_WD = 1;
   parameter P_NP_PASS_P_WD     = 1 + `CX_NVC - 1 ;
   parameter type P_CFG_IB_P_ID_MNG_CTRL_TYPE = cdmIbPIdMngCtrl_s;

   parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 = `CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2;

   parameter TP                       = `TP; // Clock to Q delay (simulator insurance)

   // -------------------------------------------------------------------------------------
   // Local parameters
   // -------------------------------------------------------------------------------------
   localparam MEMWR       = 5'b00000;
   localparam MSG         = 2'b10;
   localparam NONPOSTED   = 1;

   localparam POSTED      = 0;
   localparam POSTED_DMA  = 1;

   //NCBE
   localparam RESP_ERRBUS_WD         = 2 ;
   localparam GM_DATA_WIDTH          = 32 ;
   localparam MSTR_WSTRB_WD          = 4;
   // NCBE FSM State Labels
   localparam NO_OF_NCBE_STATES      = 11;
   localparam S_NCBE_IDLE            = 11'b00000000001;
   localparam S_NCBE_DW1_0           = 11'b00000000010;
   localparam S_NCBE_DW1_1           = 11'b00000000100;
   localparam S_NCBE_DW1_2           = 11'b00000001000;
   localparam S_NCBE_DW1_3           = 11'b00000010000;
   localparam S_NCBE_DW2_0           = 11'b00000100000;
   localparam S_NCBE_DW2_1           = 11'b00001000000;
   localparam S_NCBE_DW2_2           = 11'b00010000000;
   localparam S_NCBE_DW2_3           = 11'b00100000000;
   localparam S_NCBE_SEND_DW1        = 11'b01000000000;
   localparam S_NCBE_SEND_DW2        = 11'b10000000000;

   localparam OKAY                   = 2'b00;
   localparam EXOKAY                 = 2'b01;
   localparam SLVERR                 = 2'b10;
   localparam DECERR                 = 2'b11;

   localparam SU                     = 3'b000;
   localparam UR                     = 3'b001;
   localparam CRS                    = 3'b010;
   localparam CA                     = 3'b100;
   localparam MRS                    = 3'b101;
   localparam SU1                    = 3'b111;
   localparam NCBE_PARITY_WD         = 1;
   localparam NCBE_PARITY_OFFSET     = 4;

   // Write channel posted request info queue
   localparam WR_CH_P_REQ_QUEUE_WD       = 1;
   // B channel non-posted response info queue


   localparam WR_CH_NP_RSP_QUEUE_WD      = 2 +                  // bresp[1:0] +
                                           `DC_CPL_STATUS_WD +  // bmisc_info_cpl_stat[2:0]
                                           AXI_ID_WIDTH;   // bid


   localparam WR_CH_NP_RESP_QUEUE_MINFO_HIGH = 0;
   localparam WR_CH_NP_RESP_QUEUE_MINFO_LOW  = WR_CH_NP_RSP_QUEUE_WD;

   localparam WR_CH_NP_RESP_QUEUE_PRFX_HIGH  = 0;
   localparam WR_CH_NP_RESP_QUEUE_PRFX_LOW   = WR_CH_NP_RESP_QUEUE_MINFO_LOW;

   localparam WR_CH_NP_RESP_QUEUE_LN = WR_CH_NP_RESP_QUEUE_PRFX_LOW;
   localparam WR_CH_NP_RESP_QUEUE_CID_HIGH  = 0;
   localparam WR_CH_NP_RESP_QUEUE_CID_LOW   = WR_CH_NP_RESP_QUEUE_LN;
   localparam WR_CH_NP_RESP_QUEUE_DST_SEGMENT_HIGH  = 0;
   localparam WR_CH_NP_RESP_QUEUE_DST_SEGMENT_LOW   = WR_CH_NP_RESP_QUEUE_CID_LOW;

   localparam WR_CH_NP_RESP_QUEUE_ID_HIGH    = WR_CH_NP_RESP_QUEUE_DST_SEGMENT_LOW - 1;
   localparam WR_CH_NP_RESP_QUEUE_ID_LOW     = WR_CH_NP_RESP_QUEUE_ID_HIGH - AXI_ID_WIDTH + 1;
   localparam WR_CH_NP_RESP_QUEUE_RESP_HIGH  = WR_CH_NP_RESP_QUEUE_ID_LOW -1;
   localparam WR_CH_NP_RESP_QUEUE_RESP_LOW   = WR_CH_NP_RESP_QUEUE_RESP_HIGH - 1;
   localparam WR_CH_NP_RESP_QUEUE_CPL_STAT_HIGH = WR_CH_NP_RESP_QUEUE_RESP_LOW - 1;
   localparam WR_CH_NP_RESP_QUEUE_CPL_STAT_LOW  = WR_CH_NP_RESP_QUEUE_CPL_STAT_HIGH - `DC_CPL_STATUS_WD + 1;

   localparam MSTR_MISC_INFO_NOSNOOP = 16;

   localparam AWID0_OUTSTAND_PNP_ARY_WD = CC_WR_CH_P_REQ_QUEUE_DP + CC_MSTR_MAX_SPLIT_PACK_NARROW_RD;
   //This will be the optimum size both parameter are a power of 2
   localparam AWID0_OUTSTAND_PNP_ARY_PW = $clog2(CC_WR_CH_P_REQ_QUEUE_DP + CC_MSTR_MAX_SPLIT_PACK_NARROW_RD);

   localparam BYTE_WIDTH               = 9;
   localparam [8:0] AXI_DATA_INIT_BYTE = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;

   localparam AXI_DATA_N_BYTES   = `MASTER_BUS_DATA_WIDTH/8;

   localparam AXI_BUS_INIT = {AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};

   //Masks to generate 0 with odd parity interleaved
   localparam DATA_SHIFT_4   = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<   4*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_8   = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<   8*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_12  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  12*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_16  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  16*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_20  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  20*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_24  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  24*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_28  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  28*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_32  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  32*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_36  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  36*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_40  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  40*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_44  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  44*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_48  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  48*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_52  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  52*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_56  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  56*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_60  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  60*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_64  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  64*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_68  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  68*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_72  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  72*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_76  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  76*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_80  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  80*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_84  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  84*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_88  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  88*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_92  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  92*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_96  = (~(({2*AXI_DATA_WIDTH{1'b1}}) <<  96*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_100 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 100*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_104 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 104*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_108 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 108*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_112 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 112*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_116 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 116*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_120 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 120*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
   localparam DATA_SHIFT_124 = (~(({2*AXI_DATA_WIDTH{1'b1}}) << 124*DATA_BYTE_WD_W_PARITY)) & {2*AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};

  localparam L_NVC_STREAMS = K_N_IB_VC_STREAMS;
  localparam L_NVC_STREAMS_WD = (L_NVC_STREAMS > 1) ? $clog2(L_NVC_STREAMS) : 1;

   // -----------------------------------------------------------------
   // Ports
   // -----------------------------------------------------------------

   // System
   input                         aclk    ;            // AXI Clock
   input                         aresetn ;            // AXI Async Reset
   input                         gclken  ;            // Clock Enable


   input [3:0]                   cfg_mstr_arcache_mode;
   input [3:0]                   cfg_mstr_awcache_mode;
   input [3:0]                   cfg_mstr_arcache_value;
   input [3:0]                   cfg_mstr_awcache_value;
   input [1:0]                   cfg_mstr_ardomain_mode;
   input [1:0]                   cfg_mstr_awdomain_mode;
   input [1:0]                   cfg_mstr_ardomain_value;
   input [1:0]                   cfg_mstr_awdomain_value;
   input P_CFG_IB_P_ID_MNG_CTRL_TYPE cfg_ib_p_id_mng_ctrl;
   input                         cfg_ax_mstr_zeroread_fw;
   // Generic Interface

   // GIF Request
   input [AXI_ADDR_WIDTH-1:0]     maddr      ;        // Address
   input                          mread      ;        // Read Req
   input                          mwrite     ;        // Write Req
   input [MSTR_MTU_PW -1:0]       mlen       ;        // Length
   input [AXI_ID_WIDTH -1:0]      mid        ;        // ID
   input [BE_CTRL_WD-1:0]         mbe_ctrl   ;        // byte enable ctrl for NCBE
   input [AXI_DATA_WIDTH -1:0]    mdata      ;        // Write Data
   input [AXI_STRB_WIDTH -1:0]    mwstrb     ;        // Write Strobes
   input [DC_INBD_MISCINFO_WD-1:0]mmisc_info ;        // Misc Info
   input                          mabort     ;        // Aborted request (TLP, DLLP, ECRC)
   input                          mlast_tlp  ;
   output                         saccept    ;        // Accept
   output                         stall_mwr_ready_atop;
   input                          rdq_mwr_stall;
   input pkg_atop_writeq_to_gmread_s writeq  ;

   // GIF Response
   output                         svalid     ;        // Valid
   output                         slast      ;        // Last
   output [AXI_DATA_WIDTH-1:0]    sdata      ;        // Read Data
   output [RESP_MISC_INFO_WD-1:0] smisc_info ;        // Misc Info
   output [2:0]                   sresp      ;        // Response
   output [`DC_CPL_STATUS_WD-1:0] smisc_info_cpl_stat; // completion status selection
   output [AXI_ID_WIDTH-1:0]      sid        ;        // ID
   output [AXI_STRB_WIDTH -1:0]   sbyte_en   ;        // byte enable of response data bus
   input                          mready     ;        // Ready

   // AXI Master

   // AXI Write Request
   output [AXI_ID_WIDTH_EXT-1:0] o_awid       ;       // ID
   output [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] o_awid_extra;
   output                        o_awid_ro_remapped;
   output                        awvalid      ;       // Valid
   output [AXI_ADDR_WIDTH-1:0]   awaddr       ;       // Address
   output [BURST_LEN_PW-1:0]     awlen        ;       // Length
   output [2:0]                  awsize       ;       // Size
   output [1:0]                  awburst      ;       // Burst Type
   output [AXI_LOCK_WIDTH-1:0]   awlock       ;       // Lock
   output [3:0]                  awcache      ;       // Cache

   output [CX_TAG_SIZE+39:0]     awmisc_info;
   output                        awmisc_info_is_p;
   output                        awmisc_info_hdr_uppr_bytes_valid;
   output                        awmisc_info_nw;
   output                        awmisc_info_cxlsrc;
   output [1:0]                  awmisc_info_ats;
   output                        awmisc_info_ep;
   output [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] awmisc_info_dma;
   output [RX_TLP_PREFIX_WD-1:0] awmisc_info_tlpprfx;
   output [MISC_INFO_TPH_WD-1:0] awmisc_info_tph;
   output                        awmisc_info_ido;
   output [8:0]                  awmisc_info_dst_segment;
   output [8:0]                  awmisc_info_req_segment;
   output [3:0]                  awqos        ; // Quality of Service
   output [1:0]                  awdomain     ; // Domain
   output [1:0]                  awbar        ; // Barrier
   output [`CC_AXIJ_DMWR_VALUE *2+2:0] awsnoop; // Snoop
   output pkg_atop_awatop_e      awatop       ;       // Atomic Op code
   input                         awready      ;       // Ready

   // AXI Write Data
   output [AXI_ID_WIDTH_EXT-1:0] o_wid        ;       // ID
   output [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] o_wid_extra;
   output                        wvalid       ;       // Valid
   output                        wlast        ;       // Last
   output [AXI_DATA_WIDTH -1:0]  wdata        ;       // Wr Data
   output [AXI_STRB_WIDTH -1:0]  wstrb        ;       // Strobe
   output [P_N_PRESP_STREAMS_WD-1:0] wstream  ;       // Stream
   output                        wmisc_info_is_p;
   input                         wready       ;       // Ready

   // AXI Write Response
   input [AXI_ID_WIDTH_EXT-1:0]  bid      ;       // ID
   input [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] bid_extra;
   input                         bvalid       ;       // Valid
   input [1:0]                   bresp        ;       // Response
   input [`DC_CPL_STATUS_WD-1:0] bmisc_info_cpl_stat; // MISC info wr channel copletion status
   output                        bready       ;       // Ready
   input                         b_rsp_atop_flag;     // Flag indicating which B response is from an atomic transaction with ID 0
   // AXI Read Request
   output [AXI_ID_WIDTH_EXT-1:0] o_arid      ;        // ID
   output                        arvalid     ;        // Valid
   output [AXI_ADDR_WIDTH-1:0]   araddr      ;        // Address
   output [BURST_LEN_PW-1:0]     arlen       ;        // Length
   output [2:0]                  arsize      ;        // Size
   output [1:0]                  arburst     ;        // Burst Type
   output [AXI_LOCK_WIDTH-1:0]   arlock      ;        // Lock
   output [3:0]                  arcache     ;        // Cache
   output [CX_TAG_SIZE+39:0]     armisc_info;
   output                        armisc_info_nw;
   output                        armisc_info_cxlsrc;
   output [1:0]                  armisc_info_ats;
   output [CC_NUM_DMA_MAX_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] armisc_info_dma;
   output [RX_TLP_PREFIX_WD-1:0] armisc_info_tlpprfx;
   output [MISC_INFO_TPH_WD-1:0] armisc_info_tph;
   output                        armisc_info_ido;
   output [8:0]                  armisc_info_dst_segment;
   output [8:0]                  armisc_info_req_segment;
   output                        armisc_info_zeroread;

   output [3:0]                  arqos        ; // Quality of Service
   output [1:0]                  ardomain     ; // Domain
   output [1:0]                  arbar        ; // Barrier
   output [3:0]                  arsnoop      ; // Snoop
   input                         arready     ; // Ready

   // AXI read response & read data
   input [AXI_ID_WIDTH-1:0]      rid         ;        // ID
   input                         rvalid      ;        // Valid
   input                         rlast       ;        // Last
   input [AXI_DATA_WIDTH-1:0]    rdata       ;        // Data
   input [RESP_MISC_INFO_WD-1:0] rmisc_info  ;        // Misc Info
   input [1:0]                   rresp       ;        // Response
   input [`DC_CPL_STATUS_WD-1:0] rmisc_info_cpl_stat;  // MISC Info read channel cpl status select

   output                        rready      ;        // Ready

   // AXI low power
   input                         csysreq     ;        // Request
   output                        csysack     ;        // Acknowledge
   output                        cactive     ;        // Active
   // Posted responses
  output                                gm_presp_cmplt        ;
  output [CC_AMBA_TLP_SEQ_WD-1:0]       gm_presp_rpseq        ;
  output [1:0]                          gm_presp_type         ;
  output [P_N_PRESP_STREAMS_WD-1:0]     gm_presp_stream       ;
  output [CC_NUM_DMA_RD_CHAN_WIDTH-1:0] gm_presp_dma_chan_num    ;
  output                                gm_presp_dma_err      ;

  output                                gm_presp_cfg_cmplt    ;
  output [CC_AMBA_TLP_SEQ_WD-1:0]       gm_presp_cfg_rpseq    ;
  output [1:0]                          gm_presp_cfg_type     ;
  output [P_N_PRESP_STREAMS_WD-1:0]     gm_presp_cfg_stream   ;
  output                                gm_presp_cfg_empty    ;

  // When a register slice is instantiated, the tracker needs
  // to follow the output directly
  input                                 rs_awvalid            ;
  input [AXI_ID_WIDTH-1:0]              rs_awid               ;
  input                                 rs_awready            ;
  input                                 rs_awmisc_info_is_p   ;
  input                                 rs_wvalid             ;
  input                                 rs_wready             ;
  input                                 rs_wlast              ;
  input                                 rs_wmisc_info_is_p   ;

  input                                 rtime_cdc_halt        ;
  input                                 rtime_cfg_cdc_halt    ;
  input                                 rtime_cfg_cdc_alm_halt;

   // -----------------------------------------------------------------
   // Output Wires
   // -----------------------------------------------------------------

   // GIF Request
   wire                           saccept     ; // Accept

   // GIF Response
   logic                           svalid, svalid_i ; // Valid
   wire                           slast       ; // Last
   reg  [AXI_DATA_WIDTH-1:0]      sdata       ; // Read Data
   wire [RESP_MISC_INFO_WD-1:0]   smisc_info  ; // Misc Info
   wire [2:0]                     sresp       ; // Response
   wire [`DC_CPL_STATUS_WD-1:0]   smisc_info_cpl_stat; // completion status selection

   wire [AXI_ID_WIDTH-1:0]        sid         ; // ID
   wire [AXI_STRB_WIDTH -1:0]     sbyte_en    ; // byte enable of response bus

   // AXI Write Request
   wire [AXI_ID_WIDTH-1:0]        awid        ; // ID
   wire [AXI_ID_WIDTH_EXT-1:0]    o_awid      ; // ID
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] o_awid_extra;
   wire                           o_awid_ro_remapped;
   logic                          s_relax_order;
   wire                           awvalid     ; // Valid
   wire [AXI_ADDR_WIDTH-1:0]      awaddr      ; // Address
   wire [BURST_LEN_PW-1:0]        awlen       ; // Length
   wire [2:0]                     awsize      ; // Size
   wire [1:0]                     awburst     ; // Burst Type
   wire [AXI_LOCK_WIDTH-1:0]      awlock      ; // Lock
   wire [3:0]                     awcache     ; // Cache
   wire [CX_TAG_SIZE+39:0]        awmisc_info ; // Misc Info
   wire [RX_TLP_PREFIX_WD-1:0]    awmisc_info_tlpprfx; // Misc Info TLP Prefix
   wire [MISC_INFO_TPH_WD-1:0]    awmisc_info_tph;     // Misc Info TLP Processing Hints
   wire                           awmisc_info_ido;
   wire [8:0]                     awmisc_info_dst_segment;
   wire [8:0]                     awmisc_info_req_segment;
   wire [3:0]                     awqos       ; // Quality of Service
   wire [1:0]                     awdomain    ; // Domain
   wire [1:0]                     awbar       ; // Barrier
   wire [`CC_AXIJ_DMWR_VALUE *2+2:0] awsnoop  ; // Snoop

   // AXI Write Data
   wire [AXI_ID_WIDTH-1:0]        wid          ; // ID
   wire [AXI_ID_WIDTH_EXT-1:0]    o_wid        ; // ID
   wire [`CX_IB_P_ID_MNG_EXTRA_ID_WD-1:0] o_wid_extra;
   wire                           wvalid       ; // Valid
   wire                           wlast        ; // Last
   wire [AXI_DATA_WIDTH -1:0]     wdata        ; // Wr Data
   wire [AXI_STRB_WIDTH -1:0]     wstrb        ; // Strobe

   // AXI Write Response
   wire                           bready      ; // Ready

   // AXI Read Request
   wire [AXI_ID_WIDTH-1:0]        arid        ; // ID
   wire [AXI_ID_WIDTH_EXT-1:0]    o_arid      ;       // ID
   wire                           arvalid     ; // Valid
   wire [AXI_ADDR_WIDTH-1:0]      araddr      ; // Address
   wire [BURST_LEN_PW-1:0]        arlen       ; // Length
   wire [2:0]                     arsize      ; // Size
   wire [1:0]                     arburst     ; // Burst Type
   wire [AXI_LOCK_WIDTH-1:0]      arlock      ; // Lock
   wire [3:0]                     arcache     ; // Cache
   reg  [CX_TAG_SIZE+39:0]        armisc_info ; // Misc Info
   wire [RX_TLP_PREFIX_WD-1:0]    armisc_info_tlpprfx; // Misc Info TLP Prefix
   wire [MISC_INFO_TPH_WD-1:0]    armisc_info_tph;     // Misc Info TLP Processing Hints
   wire                           armisc_info_ido;
   wire [8:0]                     armisc_info_dst_segment;
   wire [8:0]                     armisc_info_req_segment;
   wire                           armisc_info_zeroread;
   wire [3:0]                     arqos       ; // Quality of Service
   wire [1:0]                     ardomain    ; // Domain
   wire [1:0]                     arbar       ; // Barrier
   wire [3:0]                     arsnoop     ; // Snoop

   // AXI read response & read data
   wire                           rready      ; // Ready



   // -----------------------------------------------------------------
   // Internal Signals
   // -----------------------------------------------------------------

   wire              collect_required;

   reg               saccept_r                 ; // Pre Saccept
   reg [BURST_LEN_PW -1:0]   wburst_gif_count  ; // Wr Burst Count
   wire              rready_gc_tmp             ; // Pre Rready
   wire              bready_gc_tmp             ; // Pre Bready
   wire              rready_gc                 ; // Pre Rready
   wire              bready_gc                 ; // Pre Bready
   wire              cactive                   ; // Sys Active
   wire              csysack                   ; // Sys Ack
   wire              gvalid                    ; // Resp Valid Sel
   reg [BURST_LEN_PW -1:0]   wburst_count      ; // Wr Burst Count

   wire              saccept_wr                ; // Slave has accepted write
   wire              saccept_wr_eot            ; // Flags end of transfer when slaves accepts addr and data
   wire              saccept_wrdata_set        ; // Set saccept_wrdata
   reg               saccept_wrdata            ; // Slave has accepted write data
   reg               saccept_wraddr            ; // Slave has accepted write address
   wire              saccept_rd                ; // Rd req Sacc
   wire              gready                    ; // Ready Mux

   wire [RESP_MISC_INFO_WD-1:0] rmisc_info_int ; // Misc Info_ int
   wire [RESP_MISC_INFO_WD-1:0] imisc_info_int_ncbe1 ; // Misc Info_ int
   wire [RESP_MISC_INFO_WD-1:0] imisc_info_int_ncbe2 ; // Misc Info_ int
   wire [RESP_MISC_INFO_WD-1:0] nr_rmisc_info_int; //Null Read Misc Info
   wire [RESP_MISC_INFO_WD-1:0] bmisc_info_int ; // Misc Info_ int
   wire [BURST_LEN_PW -1:0]      wlen          ; // Write Length
   wire              no_pend_trans             ; // Pend Transact
   wire              wburst_gif_active         ; // Wr Burst Act
   reg               awvalid_hold              ; // Hold awvalid unit address accepted

   reg               s_aw_w_cnt;
   reg               r_aw_w_cnt;

   reg               r_wr_in_burst,
                     s_wr_in_burst             ; // wready Reg
   reg               r_aw_accepted,
                     s_aw_accepted             ;
   wire              int_mwrite                ; // Internal int_mwrite
   wire  [2:0]                                       rd_msize                 ;
   wire  [2:0]                                       int_rd_msize             ; // internal
   wire  [2:0]                                       wr_msize                 ;
   wire  [BURST_LEN_PW -1:0]                         rd_len_in_beats          ;
   wire  [MSTR_MTU_PW-1:0]                           int_rd_len_in_beats      ; // internal
   wire  [MSTR_MTU_PW-1:0]                           wr_len_in_beats          ;
   wire  [AXI_BUS_BYTECNT_PW -1 :0]                  req_remain_bytes         ;
   wire  [2:0]                                       resp_size                ;
   wire  [AXI_STRB_PW -1:0]                          resp_low_addr            ;
   wire  [MAX_AXI_STRB_PW -1:0]                      int_resp_low_addr        ;
   wire  [BURST_LEN_PW -1:0]                         resp_rd_len_in_beats     ;
   wire                                               resp_wrq_atop;
   wire  [MSTR_MTU_PW -1:0]                          total_mlen               ;
   wire  [MSTR_MTU_PW -1:0]                          s_mlen                   ;
   reg                                               extra_beat               ;
   wire                                              tmp_extra_beat           ;
   reg   [AXI_STRB_PW -1 :0]                         latchd_low_addr          ;
   wire                                              hold_gif_last_data       ;
   wire  [MSTR_MTU_PW -1:0]                          dword_aligned_mlen       ;
   wire  [CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 -1 :0] tmp_low_maddr            ;
   wire  [MAX_AXI_STRB_PW -1 :0]                     addr_offset              ;
   reg                                               arvalid_int              ;
   wire                                              mread_nullrd_det         ; //detects null reads
   reg                                               r_nread_svalid           ; //stores the null-read until it can be offloaded
   reg   [2:0]                                       sub_bus_size             ;
   wire                                              sub_bus_size_aligned     ; // indicates the detection of a sub-bus sized aligned transfer
   reg                                               mlen_align_n_pow2        ; // indicates the detection of a size aligned power of 2 data payload
   wire                                              sub_bus_size_we          ;
   wire                                              sub_bus_size_re          ;

   wire                                              sub_bus_size_rd_valid_rd ; // indicate the sub_bus_size_rd_valid for the completion
   reg                                               is_mlen_pow2_rd          ; // indicate if the data length received from sl is the power of 2
   reg                                               is_maddr_align_rd        ; // given the is_mlen_pow2 is 1, indicate if resp_low_addr is aligned

   wire [`DC_CPL_STATUS_WD-1:0]                      imisc_info_cpl_stat;
   // Outstanding Posted write ID. We support 64 outstanding posted writes
   reg [CC_WR_CH_P_REQ_QUEUE_DP_LOG2:0] owid_p;
   //Detects a posted transaction
   wire                               awmisc_info_is_p;
   wire                               aw_is_nposted;
   logic                              aw_is_atomic;
   wire                               sel_misc_info_is_p;
   wire                               cfg_valid;
   wire                               cfg_ready;

   //--------------------------------------------------------------------------------------
   // Add request info (tc, func, attr) to internal sideband bus
   //--------------------------------------------------------------------------------------
   localparam WIDTH       = 9;
   localparam DEPTH       = CC_MAX_MSTR_TAGS;

   wire                               arready_int;
   reg [AXI_ID_WIDTH-1:0]             r_nread_sid;
   wire [WIDTH-1:0]                   selected_nrmisc_info;

   reg [WIDTH-2:0]                    rmisc_info_lut[0:DEPTH-1]; //Outstanding IDs don't need posted always 1

   wire [WIDTH-1:0]                   selected_rmisc_info;
   wire [WIDTH-1:0]                   selected_bmisc_info;
   reg [WIDTH-2:0]                    bmisc_info_lut[0:DEPTH-1]; //Outstanding IDs


   //Detects a b response of a posted transaction
   wire                                bid_posted;

   wire nowrites;
   wire block_p_wr;
   wire nowrites_aw_w_ordering_change;
   wire mwrite_w_aw_event;
   logic wlast_outstanding;
   wire aw_w_wlast_ordering;
   wire rs_awstream_wlast_ordering;
   wire mstream_wlast_ordering;

   wire gm_wr_err_dma; // eDMA Read channel write error
  reg [CC_NUM_DMA_MAX_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0] armisc_info_dma;
  reg [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0]  awmisc_info_dma;

   // B channel non-posted response info queue
   wire                                        s_b_ch_np_rsp_q_wr;
   wire                                        s_b_ch_np_rsp_q_rd;
   wire [WR_CH_NP_RSP_QUEUE_WD-1:0]            s_b_ch_np_rsp_q_wr_info;
   reg  [WR_CH_NP_RSP_QUEUE_WD-1:0]            s_b_ch_np_rsp_q_rd_info;
   reg  [WR_CH_NP_RSP_QUEUE_WD-1:0]            s_b_ch_np_rsp_q_ary [CC_WR_CH_NP_RSP_QUEUE_DP-1:0];
   reg  [WR_CH_NP_RSP_QUEUE_WD-1:0]            r_b_ch_np_rsp_q_ary [CC_WR_CH_NP_RSP_QUEUE_DP-1:0];
   reg  [CC_WR_CH_NP_RSP_QUEUE_DP_LOG2-1:0]    s_b_ch_np_rsp_q_rd_ptr;
   reg  [CC_WR_CH_NP_RSP_QUEUE_DP_LOG2-1:0]    r_b_ch_np_rsp_q_rd_ptr;
   reg  [CC_WR_CH_NP_RSP_QUEUE_DP_LOG2-1:0]    s_b_ch_np_rsp_q_wr_ptr;
   reg  [CC_WR_CH_NP_RSP_QUEUE_DP_LOG2-1:0]    r_b_ch_np_rsp_q_wr_ptr;
   reg                                         s_b_ch_np_rsp_q_empty;
   reg                                         r_b_ch_np_rsp_q_empty;
   reg                                         s_b_ch_np_rsp_q_full;
   reg                                         r_b_ch_np_rsp_q_full;

   wire                                        s_bready_gc;
   wire                                        s_b_ch_np_rsp_q_xfer_pending;
   reg                                         s_b_ch_np_rsp_accptd;

   wire [1:0]                                  s_np_write_bresp;
   wire [`DC_CPL_STATUS_WD-1:0]                s_np_write_bmisc_info_cpl_stat;
   wire [AXI_ID_WIDTH-1:0]                     s_np_write_bid;

   wire                                        nosnoop;
   assign nosnoop = mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_NS_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_NS_LOW];

   wire                                        th_value;
   assign th_value = mmisc_info[`MSTR_MISCINF_RANGE_TPH_TH_HIGH:`MSTR_MISCINF_RANGE_TPH_TH_LOW];


   wire                                        presp_sstall;
   wire                                        presp_mstall;
   wire                                        presp_cfg_mstall;

   wire                                        mmem_type;
   //wire                                        is_msg;



  pkg_atop_fmt_type_e                          atop_pkt_fmt_type        ;
  logic [2:0]                                  atop_size                ;
  logic [4:0]                                  atop_size_aux            ;
  logic [2:0]                                  wrq_atop_size            ;
  logic [MSTR_MTU_PW-1:0]                      wrq_total_mlen           ;
  logic [AXI_BUS_BYTECNT_PW-1:0]               wrq_req_remain_bytes     ;
  logic [2:0]                                  wrq_rd_msize             ;
  logic [BURST_LEN_PW-1:0]                     wrq_rd_len_in_beats      ;
  logic                                        wrq_sub_bus_size_aligned ;
  logic                                        wrq_mlen_align_n_pow2    ;
  logic [2:0]                                  wrq_sub_bus_size         ;
  logic [MAX_AXI_STRB_PW -1 :0]                wrq_addr_offset          ;
  logic                                        maddr_naligned           ;

   logic                   [AXI_ID_WIDTH -1:0] r_mid            ;        // ID
   logic                      [BE_CTRL_WD-1:0] r_mbe_ctrl       ;        // NCBE Byte Enable
   logic               [RESP_MISC_INFO_WD-1:0] r_mmisc_info_int ;        // Misc Info
   logic                                 [2:0] r_mmisc_info_tc  ;        // Misc Info
   logic                                       r_mmisc_info_ro  ;        // Misc Info
   logic                                       r_mmisc_info_ns  ;        // Misc Info
   logic                   [AXI_ID_WIDTH -1:0] r_mid_r_atop            ; // ID
   logic               [RESP_MISC_INFO_WD-1:0] r_mmisc_info_int_r_atop ; // Misc Info
   logic                                 [2:0] r_mmisc_info_tc_r_atop  ; // Misc Info
   logic                                       r_mmisc_info_ro_r_atop  ; // Misc Info
   logic                                       r_mmisc_info_ns_r_atop  ; // Misc Info

  logic [P_NP_PASS_P_WD-1:0] cfg_ax_mstr_np_pass_p_aux;

  logic                                      s_presp_ro_tag_valid;
  logic      [P_N_PRESP_STREAMS_W_RO_WD-1:0] s_presp_ro_tag;

  logic        [`CC_MAX_MSTR_TAG_PW -1:0] mstream_strictOuter;
  logic        [`CC_MAX_MSTR_TAG_PW -1:0] mstream_vc_strictOuter;
  logic          [P_N_PRESP_STREAMS_WD -1:0] mstream_strictInner;
  logic          [P_N_PRESP_STREAMS_WD -1:0] mstream_vc_strictInner;
  logic     [P_N_PRESP_STREAMS_W_RO_WD -1:0] mstream_relaxedInner;
  logic [K_N_IBR_PRESP_STREAMS_W_RO_WD -1:0] mstream_relaxedOuter;

  logic [K_N_IBR_PRESP_STREAMS_W_RO_WD -1:0] bstream_relaxedOuter;
  logic     [P_N_PRESP_STREAMS_W_RO_WD -1:0] bstream_relaxedInner;

  logic [K_N_IBR_PRESP_STREAMS_W_RO_WD -1:0] rs_awstream_relaxedOuter;
  logic     [P_N_PRESP_STREAMS_W_RO_WD -1:0] rs_awstream_relaxedInner;

  logic     [P_N_PRESP_STREAMS_W_RO_WD -1:0] cfg_bstream_relaxedInner;

reg [2:0] state, next_state;

reg  [1:0]                   collected_rresp_d [CC_MAX_MSTR_TAGS-1:0];
wire [1:0]                   collected_rresp;
reg  [`DC_CPL_STATUS_WD-1:0] collected_rmisc_info_cpl_stat_d [CC_MAX_MSTR_TAGS-1:0];
wire [`DC_CPL_STATUS_WD-1:0] collected_rmisc_info_cpl_stat;
reg                          collected_rmisc_info_ep_d [CC_MAX_MSTR_TAGS-1:0];
wire                         collected_rmisc_info_ep;
reg                          r_sresp_cpl_stat_err [CC_MAX_MSTR_TAGS-1:0]; // set high when first error has been encountered (rresp/cpl_stat)

logic [AXI_BUS_BYTECNT_PW -1 :0] resp_remain_bytes;
logic [AXI_STRB_PW -1 :0]     collected_bytecnt   [CC_MAX_MSTR_TAGS-1:0];
logic [CC_MAX_MSTR_TAGS-1:0]  rd_resp_in_progress;
logic                         resp_first_stretch, resp_last_stretch, s_nread_svalid_pls, s_rd_ctrl_ncbe_sid, s_rd_first_beat_sid, s_svalid, prefetch_disable;
logic [AXI_ID_WIDTH-1:0]      s_sid;
logic [7:0]                   s_rd_ctrl_be_sid;
logic [AXI_ID_WIDTH-1:0]      rid_latch;


localparam ST_MW_1ST_BEAT    = 3'b000;
localparam ST_MW_1ST_BEAT_W  = 3'b010;
localparam ST_MW_1ST_BEAT_WL = 3'b110;
localparam ST_MW_1ST_BEAT_AW = 3'b001;
localparam ST_MW_INT_BEAT    = 3'b011;

reg [7:0] rd_ctrl_be_ary [CC_MAX_MSTR_TAGS -1:0];
reg [CC_MAX_MSTR_TAGS -1:0] rd_ctrl_ncbe_ary;
reg [CC_MAX_MSTR_TAGS -1:0] rd_first_beat_ary;

   // -------------------------------------------------------------------------------------
   // Internal design
   // -------------------------------------------------------------------------------------
   generate
   if (WR_NOT_RD_QUEUE) begin : GEN_SNCBE_RVALID_WRQ
   end else begin : GEN_SNCBE_RVALID_RDQ
   end
   endgenerate

   assign mmem_type = mmisc_info[`MSTR_MISCINF_RANGE_MEM_TYPE_HIGH:`MSTR_MISCINF_RANGE_MEM_TYPE_LOW];
   // Stall last response if CDC fifo gets full
   assign bready = ~(r_b_ch_np_rsp_q_full | presp_sstall);

  // Decode messages
  reg s_tlp_msg, s_tlp_msgd, s_tlp_msg_or, ss_tlp_msg_or;
  reg [4:0] s_tlp_type;
  reg [1:0] s_tlp_fmt;
  reg [7:0] s_msg_code;
  always @(*) begin : proc_comb_tlp_msg
      s_tlp_fmt  = mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW];
      s_tlp_type = mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW];
      // Decode FMT[1:0] and TYPE[4:3]
      s_tlp_msg    = ({s_tlp_fmt,s_tlp_type[4:3]} == `MSG_4);
      s_tlp_msgd   = ({s_tlp_fmt,s_tlp_type[4:3]} == `MSGD_4);

      s_tlp_msg_or = s_tlp_msg | s_tlp_msgd;
      ss_tlp_msg_or = s_tlp_msg | s_tlp_msgd;

      s_msg_code = { mmisc_info[`MSTR_MISCINF_RANGE_LAST_BE_HIGH:`MSTR_MISCINF_RANGE_LAST_BE_LOW],
                     mmisc_info[`MSTR_MISCINF_RANGE_FIRST_BE_HIGH:`MSTR_MISCINF_RANGE_FIRST_BE_LOW]
                   };
  end

   // -----------------------------------------------------------------
   // REQUEST PHASE
   // -----------------------------------------------------------------

// Masking awready with stop request
assign awready_int = awready;
assign wready_int = wready;

assign sub_bus_size_we = 1'b0;

assign sub_bus_size_re = 1'b0;

//assign is_msg       =    ({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH-1]} == 4'b0110 /*`MSG*/) |
//                         ({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH-1]} == 4'b1110 /*`MSGD*/) ;

// preventing address alignment for msgs as address is not really an address
assign  tmp_low_maddr      = s_tlp_msg_or  ? {CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2{1'b0}} :  (atop_pkt_fmt_type inside {CAS32,CAS64} && mlen == 8 ) ? {maddr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:3],3'd0} :
  (atop_pkt_fmt_type inside {CAS32,CAS64} && mlen == 16) ? {maddr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:4],4'd0} :
 (atop_pkt_fmt_type inside {CAS32,CAS64} && mlen == 32) ? {maddr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:5],5'd0} :
 maddr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 -1 :0];
//assign  tmp_low_maddr      = is_msg  ? {AXI_STRB_PW{1'b0}} : maddr[AXI_STRB_PW -1 :0];

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign  dword_aligned_mlen = mlen + tmp_low_maddr[1:0];
// spyglass enable_block W164a

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign total_mlen          =  dword_aligned_mlen + {tmp_low_maddr[AXI_STRB_PW -1 : 2], 2'b00};
// spyglass enable_block W164a

assign int_rd_msize        = (GM_AXI_SIZE);
assign req_remain_bytes    = (total_mlen < AXI_STRB_WIDTH) ?  s_mlen[AXI_BUS_BYTECNT_PW -1 :0]
                             : (total_mlen == AXI_STRB_WIDTH) ? {1'b1, {(AXI_BUS_BYTECNT_PW -1){1'b0}}}
                             : {1'b0, total_mlen[AXI_BUS_BYTECNT_PW -1 -1 :0]};
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign int_rd_len_in_beats = ((total_mlen >> GM_AXI_SIZE) + (|total_mlen[AXI_BUS_BYTECNT_PW -1 -1 :0]) - (|total_mlen)) ;
// spyglass enable_block W164a


assign int_mwrite = mwrite && ~mabort;

// HL: When single beat sub-bus transfers have been configured and
// sub_bus_size_aligned is asserted, rd_msize is assigned sub_bus
// sized transfer sizes. Otherwise it is assigned a transfer size that
// corresponds to the complete bus width in Bytes.
assign rd_msize = sub_bus_size_re && sub_bus_size_aligned ? sub_bus_size : int_rd_msize;

generate
if (BURST_LEN_PW <= MSTR_MTU_PW) begin: gen_BURST_LEN_PW_LT_EQ_MSTR_MTU_PW_rd_len_in_beats
assign rd_len_in_beats = sub_bus_size_re && sub_bus_size_aligned ? 0 : int_rd_len_in_beats[BURST_LEN_PW-1:0];
end else begin: gen_BURST_LEN_PW_GT_MSTR_MTU_PW_rd_len_in_beats
assign rd_len_in_beats = sub_bus_size_re && sub_bus_size_aligned ? 0 : {{(BURST_LEN_PW-MSTR_MTU_PW){1'b0}},int_rd_len_in_beats};
end
endgenerate

// MW: The sub_bus_size_aligned signal is asserted when a sub-bus sized
// transfer that is transfer size aligned and the data payload (in Bytes)
// is a power of 2, is detected.
assign sub_bus_size_aligned = (s_mlen < AXI_STRB_WIDTH) && mlen_align_n_pow2;

// MW: For the alignment calculation the below case statement is equivalent
// to the result of: ((addr_offset > 0) ? (addr_offset%mlen == 0) : 1'b1).
// Since the AXI data bus width can be a maximum of 1024 bits the
// largest sub-bus sized transfer that can be performed is a 512 bits
// (64 Bytes) or an a*size of 6.
always@(s_mlen or addr_offset or atop_pkt_fmt_type)
  begin
    case (s_mlen)
      1:
        begin
          mlen_align_n_pow2 = 1'b1;
          sub_bus_size      = 3'b000;
        end
      2:
        begin
          mlen_align_n_pow2 = (addr_offset[0]==1'b0) ? 1'b1 : 1'b0;
          sub_bus_size      = 3'b001;
        end
      4:
        begin
          mlen_align_n_pow2 = (addr_offset[1:0]==2'b00) ? 1'b1 : 1'b0;
          sub_bus_size      = 3'b010;
        end
      8:
        begin
          mlen_align_n_pow2 = (addr_offset[2:0]==3'b000) || (atop_pkt_fmt_type inside {CAS32,CAS64} && addr_offset[1:0]==2'b00) ? 1'b1 : 1'b0;
          sub_bus_size      = 3'b011;
        end
      16:
         begin
          mlen_align_n_pow2 = (addr_offset[3:0]==4'b0000) || (atop_pkt_fmt_type inside {CAS32,CAS64} && addr_offset[2:0]==3'b000) ? 1'b1 : 1'b0;
          sub_bus_size      = 3'b100;
        end
      32:
         begin
          mlen_align_n_pow2 = (addr_offset[4:0]==5'b00000) || (atop_pkt_fmt_type inside {CAS32,CAS64} && addr_offset[3:0]==4'b0000) ? 1'b1 : 1'b0;
          sub_bus_size      = 3'b101;
        end
      64:
         begin
          mlen_align_n_pow2 = (addr_offset[5:0]==6'b000000) || (atop_pkt_fmt_type inside {CAS32,CAS64} && addr_offset[4:0]==5'b00000) ? 1'b1 : 1'b0;
          sub_bus_size      = 3'b110;
        end
      default:
        begin
          mlen_align_n_pow2 = 1'b0;
          sub_bus_size      = 3'b000;
        end
    endcase
  end // always@ (resp_size or resp_low_addr)
// preventing address offset from triggering any alignment issues.. as address is not really an address for msgs (3rd and 4th PCIe header DWs)
assign addr_offset = s_tlp_msg_or ? {MAX_AXI_STRB_PW{1'b0}} : { {(MAX_AXI_STRB_PW - AXI_STRB_PW){1'b0}}, maddr[AXI_STRB_PW-1:0] };
//assign addr_offset = is_msg ? {MAX_AXI_STRB_PW{1'b0}} : { {(MAX_AXI_STRB_PW - AXI_STRB_PW){1'b0}}, maddr[AXI_STRB_PW-1:0] };

// MW: When single beat sub-bus transfers have been configured and
// sub_bus_size_aligned is asserted, wr_msize is assigned sub_bus
// sized transfer sizes. Otherwise it is assigned a transfer size that
// corresponds to the complete bus width in Bytes.
  assign atop_size            = log2(s_mlen);
  assign wr_msize             = (atop_pkt_fmt_type inside {
                                FETCHADD32
                               ,FETCHADD64
                               ,SWAP32
                               ,SWAP64
                               ,CAS32
                               ,CAS64
                               } && sub_bus_size_aligned) ? atop_size : (sub_bus_size_we && sub_bus_size_aligned) ? sub_bus_size: GM_AXI_SIZE;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign wr_len_in_beats = ((total_mlen >> GM_AXI_SIZE) + (|total_mlen[GM_AXI_SIZE -1 :0])) - (|total_mlen);
// spyglass enable_block W164a

wire [MSTR_MTU_PW-1:0]     tmp_len_in_beats;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign tmp_len_in_beats = ((dword_aligned_mlen >> GM_AXI_SIZE) + (|dword_aligned_mlen[GM_AXI_SIZE -1 :0])) - (|dword_aligned_mlen);
// spyglass enable_block W164a
assign tmp_extra_beat   = (wr_len_in_beats > tmp_len_in_beats);

always@(posedge aclk or negedge aresetn)
begin
    if(~aresetn) begin
      extra_beat           <= #TP 1'b0;
    end else if (wvalid && wready_int && wlast) begin  // for one extra beat only
      extra_beat           <= #TP 1'b0;
    end else if (wvalid && wready_int) begin
      extra_beat           <= #TP tmp_extra_beat;
    end
end

always@(posedge aclk or negedge aresetn)
begin
    if(~aresetn) begin
      latchd_low_addr      <= #TP {AXI_STRB_PW{1'b0}};
    end else if (wvalid && wready_int) begin
      latchd_low_addr      <= #TP tmp_low_maddr[AXI_STRB_PW-1:0];
    end
end

wire  [AXI_DATA_WIDTH -1 :0] tmp_mdata;
reg   [AXI_DATA_WIDTH -1 :0] latchd_mdata;
wire  [(2*AXI_DATA_WIDTH) -1 :0] tmp_cat_mdata;
wire  [(2*AXI_DATA_WIDTH) -1 :0] shiftd_tmp_cat_mdata;

wire [AXI_STRB_WIDTH -1 :0] tmp_mwstrb;
reg [AXI_STRB_WIDTH -1 :0] latchd_mwstrb;
wire [(2*AXI_STRB_WIDTH) -1 :0] tmp_cat_mwstrb;
wire [(2*AXI_STRB_WIDTH) -1 :0] shiftd_tmp_cat_mwstrb;

always@(posedge aclk or negedge aresetn)
begin
    if(~aresetn) begin
      latchd_mdata            <= #TP {AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
    end else if (wvalid && wready_int && wlast) begin
      latchd_mdata            <= #TP {AXI_DATA_N_BYTES{AXI_DATA_INIT_BYTE}};
    end else if (wvalid && wready_int) begin
      latchd_mdata            <= #TP mdata;
    end
end

always@(posedge aclk or negedge aresetn)
begin
    if(~aresetn) begin
      latchd_mwstrb            <= #TP {AXI_STRB_WIDTH{1'b0}};
    end else if (wvalid && wready_int && wlast) begin
      latchd_mwstrb            <= #TP {AXI_STRB_WIDTH{1'b0}};
    end else if (wvalid && wready_int) begin
      latchd_mwstrb            <= #TP mwstrb;
    end
end

assign tmp_cat_mdata   = {mdata,latchd_mdata};
assign tmp_cat_mwstrb  = {(mwstrb & {AXI_STRB_WIDTH{!(extra_beat && wlast && r_wr_in_burst)}}),latchd_mwstrb};


assign shiftd_tmp_cat_mwstrb    = (!r_wr_in_burst && (|tmp_low_maddr[5:2])) ? (tmp_cat_mwstrb << (4*tmp_low_maddr[5:2]))
                                  : (r_wr_in_burst && (|latchd_low_addr[5:2])) ? (tmp_cat_mwstrb << (4*latchd_low_addr[5:2]))
                                   : tmp_cat_mwstrb;

wire  [AXI_STRB_PW -1 :0]      muxd_low_maddr;
assign muxd_low_maddr = r_wr_in_burst ? latchd_low_addr : tmp_low_maddr[AXI_STRB_PW -1 :0];

reg   [(2*AXI_DATA_WIDTH) -1 :0] reg_shiftd_tmp_cat_mdata;
always@(muxd_low_maddr or tmp_cat_mdata)
begin
         case  (muxd_low_maddr[5:2])
         4'b0000:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << 0);
         4'b0001:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (4 *DATA_BYTE_WD_W_PARITY)) | DATA_SHIFT_4;
         4'b0010:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (8 *DATA_BYTE_WD_W_PARITY)) | DATA_SHIFT_8;
         4'b0011:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (12 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_12;
         4'b0100:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (16 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_16;
         4'b0101:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (20 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_20;
         4'b0110:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (24 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_24;
         4'b0111:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (28 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_28;
         4'b1000:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (32 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_32;
         4'b1001:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (36 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_36;
         4'b1010:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (40 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_40;
         4'b1011:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (44 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_44;
         4'b1100:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (48 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_48;
         4'b1101:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (52 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_52;
         4'b1110:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (56 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_56;
         4'b1111:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << (60 *DATA_BYTE_WD_W_PARITY))| DATA_SHIFT_60;
         default:
             reg_shiftd_tmp_cat_mdata     = (tmp_cat_mdata << 0);
         endcase
end
assign shiftd_tmp_cat_mdata     = reg_shiftd_tmp_cat_mdata;


assign tmp_mwstrb    = shiftd_tmp_cat_mwstrb[(2*AXI_STRB_WIDTH) -1 : AXI_STRB_WIDTH];
assign tmp_mdata     = shiftd_tmp_cat_mdata[(2*AXI_DATA_WIDTH) -1 : AXI_DATA_WIDTH];



  // -------------------------------------------------------------------------------------
  // Posted and Non-Posted Write Tracker
  // -------------------------------------------------------------------------------------
   assign awmisc_info_is_p = ({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]} == `MWR32) |
                         ({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]} == `MWR64) |
                         ({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH-1]} == 4'b0110 /*`MSG*/) |
                         ({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH-1]} == 4'b1110 /*`MSGD*/) ;


   assign aw_is_nposted = {mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]}
                          inside {
                            `IOWR,`CFGWR0,`CFGWR1 ,`FETCHADD32,`FETCHADD64,`SWAP32,`SWAP64,`CAS32,`CAS64 , `DMWR32, `DMWR64
                          };

   assign aw_is_atomic = {mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW],mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]} inside {`FETCHADD32,`FETCHADD64,`SWAP32,`SWAP64,`CAS32,`CAS64};

assign cfg_ax_mstr_np_pass_p_aux = '0;

generate
  if (WR_NOT_RD_QUEUE) begin : GEN_PRESP_STREAMS_LP_HP_COMMON
    // Evaluate whether Posted transaction AXI ID will be RO-remapped
    assign o_awid_ro_remapped = ~cfg_ib_p_id_mng_ctrl.global_disable                                                            // RO remap is globally enabled
                                & (s_presp_ro_tag_valid & awmisc_info_is_p & mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_RO_LOW])   // And is RO Posted
                                & ( (cfg_ib_p_id_mng_ctrl.vc_remap_en[mstream_vc_strictInner[L_NVC_STREAMS_WD-1:0]])            // And is VC RO remap enabled
                                   | (|mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW])            //     or DMA
                                  );
    assign s_relax_order =  o_awid_ro_remapped;

    // MSTREAMs -------------------------------------------------------------------------
    // 1. A strict stream is received from IBREQ (IBR map)
    // REQ strict stream - IBR perspective
    // This is the strict stream received from IBREQ (>> K_N_IBR_PRESP_STREAMS)
    // CC_MAX_MSTR_TAG_PW
    assign mstream_vc_strictOuter = '0;
    assign mstream_strictOuter =                                 mid[`CC_MAX_MSTR_TAG_PW-1:0];

    // 3. PRESP may relax stream (RO attribute) (PRESP map)
    // REQ relaxed stream - IB/IBH perspective
    // This is the relaxed stream as mapped by PRESP (>> K_N_IB_PRESP_STREAMS + K_N_IB_RO_STREAMS / K_N_IBH_PRESP_STREAMS + K_N_IBH_RO_STREAMS)
    // P_N_PRESP_STREAMS_W_RO_WD
    assign mstream_relaxedInner =                                  o_awid_ro_remapped ? s_presp_ro_tag :
                                  (P_N_PRESP_STREAMS_W_RO_WD)'(mstream_strictInner);

    // BSTREAMs -------------------------------------------------------------------------
    // 1. A relaxed stream is received from AXI (IBR map)
    // This is the relaxed stream as mapped to AXI (>> K_N_IBR_PRESP_STREAMS + K_N_IBR_RO_STREAMS)
    // AXI_ID_WIDTH_EXT-1 -> K_N_IBR_PRESP_STREAMS_W_RO_WD
    assign bstream_relaxedOuter = (K_N_IBR_PRESP_STREAMS_W_RO_WD)'({bid[AXI_ID_WIDTH_EXT-1], bid_extra, bid[AXI_ID_WIDTH_EXT-2:0]});
    assign rs_awstream_relaxedOuter = (K_N_IBR_PRESP_STREAMS_W_RO_WD)'(rs_awid);
  end else begin : GEN_PRESP_STREAMS_RDQ_COMMON
    assign o_awid_ro_remapped       = '0;
    assign mstream_vc_strictOuter   = '0;
    assign mstream_strictOuter      = '0;
    assign mstream_relaxedInner     = '0;
    assign bstream_relaxedOuter     = '0;
    assign rs_awstream_relaxedOuter = '0;
  end
endgenerate

generate
  if (WR_NOT_RD_QUEUE ) begin : GEN_PRESP_STREAMS_LP
    // MSTREAMs -------------------------------------------------------------------------
    // 2. The strict stream is remapped to PRESP map
    // REQ strict stream - IB/IBH perspective
    // This is the strict stream mapped to PRESP stream (>> K_N_IB_PRESP_STREAMS / K_N_IBH_PRESP_STREAMS)
    // CC_MAX_MSTR_TAG_PW -> P_N_PRESP_STREAMS_WD
    assign mstream_vc_strictInner   = f_kStrictStream_IbrToIb(mstream_vc_strictOuter);
    assign mstream_strictInner      = f_kStrictStream_IbrToIb(mstream_strictOuter);

    // 4. The relaxed stream is remapped to IBR map
    // REQ relaxed stream - IBR perspective
    // This is the relaxed stream as mapped to AXI (>> K_N_IBR_PRESP_STREAMS + K_N_IBR_RO_STREAMS)
    // P_N_PRESP_STREAMS_W_RO_WD -> AXI_ID_WIDTH_EXT-1
    assign mstream_relaxedOuter     = f_kRelaxedStream_IbToIbr(mstream_relaxedInner);

    // BSTREAMs -------------------------------------------------------------------------
    // 2. The relaxed stream is remapped to PRESP map
    // This is the relaxed stream as mapped by PRESP (>> K_N_IB_PRESP_STREAMS + K_N_IB_RO_STREAMS / K_N_IBH_PRESP_STREAMS + K_N_IBH_RO_STREAMS)
    // K_N_IBR_PRESP_STREAMS_W_RO_WD -> P_N_PRESP_STREAMS_W_RO_WD
    assign bstream_relaxedInner     = f_kRelaxedStream_IbrToIb(bstream_relaxedOuter);
    assign rs_awstream_relaxedInner = f_kRelaxedStream_IbrToIb(rs_awstream_relaxedOuter);
  end else begin : GEN_PRESP_STREAMS_RDQ
    assign mstream_vc_strictInner   = '0;
    assign mstream_strictInner      = '0;
    assign mstream_relaxedOuter     = '0;
    assign bstream_relaxedInner     = '0;
    assign rs_awstream_relaxedInner = '0;
  end
endgenerate

   generate
     if (WR_NOT_RD_QUEUE) begin : GEN_OWID_P
       // Maintain table of outstanding writes
       // Only tracks for posted requests and responses. When an atomic response with a lookup_id equal to 0 arrives, it should not affect this table.
       function automatic logic [CC_WR_CH_P_REQ_QUEUE_DP_LOG2:0] f_nextOwid(
         input logic [CC_WR_CH_P_REQ_QUEUE_DP_LOG2:0] i_owid_p
        ,input logic i_cfg_ax_mstr_np_pass_p_aux
        ,input logic i_awvalid
        ,input logic i_awready_int
        ,input logic i_bvalid
        ,input logic i_bready
        ,input logic i_awmisc_info_is_p
        ,input logic i_bid_msb
        ,input logic i_mstream_match
        ,input logic i_bstream_match
       );
         logic [CC_WR_CH_P_REQ_QUEUE_DP_LOG2:0] l_owid_p;

         l_owid_p = i_owid_p;

          //Disable NP ordering
          if (i_cfg_ax_mstr_np_pass_p_aux)
            l_owid_p = 0;
          else if (i_awvalid && i_awready_int && i_bvalid && i_bready && i_mstream_match && i_bstream_match) begin
            if (i_awmisc_info_is_p) begin
              if (i_bid_msb) begin
                l_owid_p = l_owid_p + 1;
              end
            end else begin
              if (!i_bid_msb) begin
                l_owid_p = l_owid_p - 1;
              end
            end
          end else if (i_awvalid && i_awready_int && i_mstream_match) begin
            if (i_awmisc_info_is_p) begin
              l_owid_p = l_owid_p + 1;
            end
          end else if (i_bvalid && i_bready && i_bstream_match) begin
            if (!i_bid_msb) begin
              l_owid_p = l_owid_p - 1;
            end
          end

         f_nextOwid = l_owid_p;
       endfunction

       always_ff @(posedge aclk, negedge aresetn)
         if(!aresetn) owid_p <= #`TP '0;
         else         owid_p <= #`TP f_nextOwid(owid_p, 1? 1'b0 : |cfg_ax_mstr_np_pass_p_aux, awvalid, awready_int, bvalid, bready, awmisc_info_is_p, bid[AXI_ID_WIDTH_EXT-1], 1, 1);


     end : GEN_OWID_P
   endgenerate


   generate
      if (WR_NOT_RD_QUEUE) begin : GEN_BLOCKAGES

         // prest_mstall reports that response queue is full so it will
         // block further writes
         assign block_p_wr = awmisc_info_is_p
                             // If Posted, block if Max Posteds outstanding OR if PRESP is halting ibreq
                             ? ((owid_p == CC_WR_CH_P_REQ_QUEUE_DP) | ((presp_mstall || presp_cfg_mstall) && (~awvalid_hold)))
                             // If Non-Posted, block if (there is any Posted outstanding for the ordering stream) and (NP is not RO). Checks for aw_is_nposted to confirm valid fmt,type
                             : (aw_is_nposted & nowrites);

         assign mwrite_w_aw_event = 1'b0;
         assign nowrites_aw_w_ordering_change = 1'b0;

         //Block NP writes until all BRESPs are received, except if the RO bit is set
         // IB scheduler takes core of NP ordering, no need to do this here
         assign nowrites = 1'b0;
      end else begin : GEN_NOT_BLOCKAGES
         assign block_p_wr = 1'b0;
         assign nowrites = 1'b0;
         assign mwrite_w_aw_event = 1'b0;
         assign nowrites_aw_w_ordering_change = 1'b0;
      end
   endgenerate


   wire mmsi_rcvd_pls;
   generate
      if (WR_NOT_RD_QUEUE) begin : gen_prespwr





  // -------------------------------------------------------------------------------------
  // Outstanding posted response tracker
  // -------------------------------------------------------------------------------------
  assign bid_posted = (bid[AXI_ID_WIDTH_EXT-1] == 1'b0) ;


  DWC_pcie_axi_presp_redo
   #(
    .P_INPUT_PIPE_M_INTF          ( 1 )
   ,.P_INPUT_PIPE_B_INTF          ( 1 )
   ,.P_OUTPUT_PIPE_PRESP_INTF     ( 1 )
   ,.CC_AMBA_TLP_SEQ_WD           ( CC_AMBA_TLP_SEQ_WD )
   ,.P_N_PRESP_STREAMS            ( P_N_PRESP_STREAMS )
   ,.P_N_PRESP_STREAMS_WD         ( P_N_PRESP_STREAMS_WD )
   ,.P_N_PRESP_STREAMS_W_RO_WD    ( P_N_PRESP_STREAMS_W_RO_WD )
   ,.DC_DMA_TYPE_WIDTH            ( DC_DMA_TYPE_WIDTH )
   ,.CC_NUM_DMA_RD_CHAN           ( CC_NUM_DMA_RD_CHAN )
   ,.CC_NUM_DMA_RD_CHAN_WIDTH     ( CC_NUM_DMA_RD_CHAN_WIDTH )
   ,.CC_NUM_DMA_MAX_CHAN_WIDTH    ( `CC_NUM_DMA_MAX_CHAN_WIDTH )
   ,.CC_WR_CH_P_REQ_QUEUE_DP      ( CC_WR_CH_P_REQ_QUEUE_DP )
   ,.CC_WR_CH_P_REQ_QUEUE_DP_LOG2 ( CC_WR_CH_P_REQ_QUEUE_DP_LOG2 )
   ,.P_SYN_GOAL                   ( `CX_AXI_PRESP_SYN_GOAL )
  ) u_presp_redo (
    .i_clk                   ( aclk )
   ,.i_rst_n                 ( aresetn )
   ,.i_mvalid                ( awvalid )
   ,.i_mready                ( awready )
   ,.i_m_is_posted           ( awmisc_info_is_p )
   ,.i_mpseq                 ( mmisc_info[`MSTR_MISCINF_RANGE_PSEQ_HIGH:`MSTR_MISCINF_RANGE_PSEQ_LOW] )
   ,.i_mwrite                ( mwrite )
   ,.i_mabort                ( mabort )
   ,.i_mlast_tlp             ( mlast_tlp )
   ,.i_mstream               ( mstream_strictInner )
   ,.i_mdma                  ( mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW] )
   ,.i_mdma_chan             ( mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_LOW] )
   ,.i_relax_order           ( s_relax_order )
   ,.o_presp_mstall          ( presp_mstall )
   ,.i_bvalid                ( bvalid )
   ,.i_bready                ( bready )
   ,.i_bid_posted            ( bid_posted )
   ,.i_bresp                 ( bresp )
   ,.i_bstream               ( bstream_relaxedInner )
   ,.o_presp_sstall          ( presp_sstall )
   ,.o_presp_cmplt           ( gm_presp_cmplt )
   ,.o_presp_rpseq           ( gm_presp_rpseq )
   ,.o_presp_stream          ( gm_presp_stream )
   ,.o_presp_type_dma        ( gm_presp_type[0] )
   ,.o_presp_dma_chan_num    ( gm_presp_dma_chan_num )
   ,.o_presp_dma_err         ( gm_presp_dma_err )
   ,.o_presp_empty           ( )
   ,.i_rtime_cdc_alm_halt    ( 1'b0 )
   ,.i_rtime_cdc_halt        ( rtime_cdc_halt )
   ,.o_ro_tag_valid          ( s_presp_ro_tag_valid )
   ,.o_ro_tag                ( s_presp_ro_tag )
  );

  // IB scheduler always selects BCh ordering event - no need for CFG presp
  assign presp_cfg_mstall             = '0;
  assign gm_presp_cfg_cmplt           = '0;
  assign gm_presp_cfg_rpseq           = '0;
  assign gm_presp_cfg_stream          = '0;
  assign gm_presp_cfg_type            = '0;
  assign gm_presp_cfg_empty           = '1;

  localparam CFG_PRESP_EVENT_FIFO_DP = 3;

  reg [CFG_PRESP_EVENT_FIFO_DP-1:0] aw_event_fifo;
  reg [CFG_PRESP_EVENT_FIFO_DP-1:0]  w_event_fifo;
  logic [2:0] [P_N_PRESP_STREAMS_W_RO_WD-1:0] aw_stream_fifo, s_aw_stream_fifo;
  logic       [P_N_PRESP_STREAMS_W_RO_WD-1:0] aw_w_ordering_stream_relaxedInner;

  wire aw_event;
  wire w_event;

  wire push_aw_event;
  wire push_w_event;
  wire pop_aw_event;
  wire pop_w_event;

  wire aw_w_ordering_event;
  wire wlast_event;
  wire awlast_event;

  always @(posedge aclk or negedge aresetn) begin : proc_seq_aw_fifo_fsm
    if(!aresetn)begin
      aw_event_fifo <= #TP {CFG_PRESP_EVENT_FIFO_DP{1'b0}};
    end else begin
      case({pop_aw_event,push_aw_event})
        2'b01 : aw_event_fifo[CFG_PRESP_EVENT_FIFO_DP-1:0] <= #TP {aw_event_fifo[CFG_PRESP_EVENT_FIFO_DP-2:0],1'b1};
        2'b10 : aw_event_fifo[CFG_PRESP_EVENT_FIFO_DP-1:0] <= #TP {1'b0,aw_event_fifo[CFG_PRESP_EVENT_FIFO_DP-1:1]};
      endcase
    end
  end

  always @(posedge aclk or negedge aresetn) begin : proc_seq_awstream_fifo_fsm
    if(!aresetn)begin
      aw_stream_fifo <= #TP '0;
    end else begin
      aw_stream_fifo <= #TP s_aw_stream_fifo;
    end
  end

  always_comb begin
    // aw_event_fifo is actually a LIFO
    // map aw_stream_fifo to FIFO scheme
    s_aw_stream_fifo = aw_stream_fifo;
    if(push_aw_event) begin
      // Push without pop
      // Push to first available position
      s_aw_stream_fifo = (aw_event_fifo == 3'b000) ? {aw_stream_fifo[2:1], rs_awstream_relaxedInner                     } : // wr at 0
                         (aw_event_fifo == 3'b001) ? {aw_stream_fifo[2],   rs_awstream_relaxedInner, aw_stream_fifo[0]  } : // wr at 1
                         (aw_event_fifo == 3'b011) ? {                     rs_awstream_relaxedInner, aw_stream_fifo[1:0]} : // wr at 2
                         '0;
    end else if(pop_aw_event) begin
      // Pop without push
      // Pop position 0
      s_aw_stream_fifo = { {P_N_PRESP_STREAMS_W_RO_WD{1'b0}}, aw_stream_fifo[2:1] }; // pop 0, mv 2:1 to 1:0
    end else if(aw_event && w_event && aw_event_fifo[0]) begin
      // Push-pop with FIFO data refresh
      // Pop position 0
      // Push to first available position
      s_aw_stream_fifo = (aw_event_fifo == 3'b001) ? {aw_stream_fifo[2:1], rs_awstream_relaxedInner                     } : // pop 0, wr at 0
                         (aw_event_fifo == 3'b011) ? {aw_stream_fifo[2],   rs_awstream_relaxedInner, aw_stream_fifo[1]  } : // pop 0, mv 1 to 0, wr at 1
                         (aw_event_fifo == 3'b111) ? {                     rs_awstream_relaxedInner, aw_stream_fifo[2:1]} : // pop 0, mv 2:1 to 1:0, wr at 2
                         '0;
    end
  end

`ifndef SYNTHESIS
`endif // SYNTHESIS

  always @(posedge aclk or negedge aresetn) begin : proc_seq_w_fifo_fsm
    if(!aresetn)begin
      w_event_fifo <= #TP 3'b000;
    end else begin
      case({pop_w_event,push_w_event})
        2'b01 : w_event_fifo[CFG_PRESP_EVENT_FIFO_DP-1:0] <= #TP {w_event_fifo[CFG_PRESP_EVENT_FIFO_DP-2:0],1'b1};
        2'b10 : w_event_fifo[CFG_PRESP_EVENT_FIFO_DP-1:0] <= #TP {1'b0,w_event_fifo[CFG_PRESP_EVENT_FIFO_DP-1:1]};
      endcase
    end
  end

  assign aw_event = rs_awvalid && rs_awready             && rs_awmisc_info_is_p;
  assign w_event  = rs_wvalid  && rs_wready  && rs_wlast && rs_wmisc_info_is_p;

  assign push_aw_event = aw_event && !( w_event ||  w_event_fifo[0]);
  assign push_w_event  =  w_event && !(aw_event || aw_event_fifo[0]);
  assign pop_aw_event  = aw_event_fifo[0] &&  w_event && !aw_event;
  assign pop_w_event   =  w_event_fifo[0] && aw_event &&  !w_event;

  assign aw_w_ordering_event = ( aw_event_fifo[0] &&  w_event) ||
                               (  w_event_fifo[0] && aw_event) ||
                               ( !aw_event_fifo[0] && !w_event_fifo[0] && w_event && aw_event);

  // Never wlast-order with ORDRB
  assign aw_w_wlast_ordering = 1'b0;
  assign rs_awstream_wlast_ordering = 1'b0;
  assign mstream_wlast_ordering = 1'b0;

  assign wlast_event  = aw_w_wlast_ordering && aw_w_ordering_event;
  assign awlast_event = !rs_awstream_wlast_ordering && rs_awvalid && rs_awready && rs_awmisc_info_is_p;


  assign aw_w_ordering_stream_relaxedInner = aw_event_fifo[0] ? aw_stream_fifo[0] : rs_awstream_relaxedInner;

  assign cfg_bstream_relaxedInner = rs_awstream_relaxedInner;

  assign cfg_valid          = rs_awvalid;
  assign cfg_ready          = rs_awready;
  assign sel_misc_info_is_p = rs_awmisc_info_is_p;



      end else begin : gen_presprd // block: gen_prespwr

         assign mmsi_rcvd_pls = 0;
         assign bid_posted = 0;
         assign gm_presp_cmplt = 0;
         assign gm_presp_rpseq = 0;
         assign gm_presp_type[0] = 0;
         assign gm_presp_stream = 0;

         assign gm_presp_dma_chan_num = 0;
         assign gm_presp_dma_err = 0;
         assign presp_sstall = 0;
         assign presp_mstall = 0;
         assign presp_cfg_mstall = 0;
         assign gm_presp_cfg_cmplt = 0;
         assign gm_presp_cfg_rpseq = 0;
         assign gm_presp_cfg_type  = 0;
         assign gm_presp_cfg_stream = 0;
         assign gm_presp_cfg_empty = 0;
         assign cfg_valid          = 0;
         assign cfg_ready          = 0;
         assign sel_misc_info_is_p = 0;
      end
   endgenerate

   assign gm_presp_type[1] = 1'b0;

   assign armisc_info_dma = { mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_LOW],
                              mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW] };
   assign awmisc_info_dma = (CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH)'({ mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_LOW],
                              mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW] });

  // -------------------------------------------------------------------------------------
  // Non-Posted Write Response Info Queue
  // -------------------------------------------------------------------------------------
   generate
      if (WR_NOT_RD_QUEUE) begin : GEN_PST_XFERS
         always @(*) begin : proc_comb_det_pst_xfers
            s_b_ch_np_rsp_accptd = 1'b0;
            if (bvalid && ((bid[AXI_ID_WIDTH_EXT-1] == 1'b1) || b_rsp_atop_flag) && bready) begin
               s_b_ch_np_rsp_accptd = 1'b1;
            end
         end
         assign s_b_ch_np_rsp_q_wr      = s_b_ch_np_rsp_accptd;
      end else begin : GEN_NOT_PST_XFERS
         assign s_b_ch_np_rsp_q_wr      = 1'b0;
      end
   endgenerate



assign s_b_ch_np_rsp_q_wr_info = {                                           bid[AXI_ID_WIDTH-1 : 0],
                                           bresp,
                                           bmisc_info_cpl_stat
                                           };




  always @(*) begin : proc_comb_b_ch_np_rsp_q
    integer i;
    // Initialise
    for (i=0; i<CC_WR_CH_NP_RSP_QUEUE_DP; i=i+1) begin
      // Update contents on a write, hold data.
      s_b_ch_np_rsp_q_ary[i] = r_b_ch_np_rsp_q_ary[i];
    end
    s_b_ch_np_rsp_q_rd_ptr   = r_b_ch_np_rsp_q_rd_ptr;
    s_b_ch_np_rsp_q_wr_ptr   = r_b_ch_np_rsp_q_wr_ptr;
    s_b_ch_np_rsp_q_empty    = r_b_ch_np_rsp_q_empty;
    s_b_ch_np_rsp_q_full     = r_b_ch_np_rsp_q_full;

    // Increment read pointer
    if (s_b_ch_np_rsp_q_rd) begin
      s_b_ch_np_rsp_q_rd_ptr = (s_b_ch_np_rsp_q_rd_ptr == CC_WR_CH_NP_RSP_QUEUE_DP-1) ? 0 : s_b_ch_np_rsp_q_rd_ptr + 1; // 2n counter, auto wraps at zero
    end
    // Increment write pointer
    if (s_b_ch_np_rsp_q_wr) begin
      s_b_ch_np_rsp_q_wr_ptr = (s_b_ch_np_rsp_q_wr_ptr == CC_WR_CH_NP_RSP_QUEUE_DP-1) ? 0 : s_b_ch_np_rsp_q_wr_ptr + 1; // 2n counter, auto wraps at zero
    end
    // Generate empty status flag.
    if (s_b_ch_np_rsp_q_rd) begin
      if (s_b_ch_np_rsp_q_wr_ptr==s_b_ch_np_rsp_q_rd_ptr) begin
        // If reading and pointers are equal then assert empty flag
        s_b_ch_np_rsp_q_empty = 1'b1;
      end
    end else if (s_b_ch_np_rsp_q_wr) begin
      // If not reading and write active then de-assert empty flag
      s_b_ch_np_rsp_q_empty = 1'b0;
    end
    // Generate full status flag. Used to back pressure Write FSM.
    if (s_b_ch_np_rsp_q_wr) begin
      if (s_b_ch_np_rsp_q_wr_ptr==s_b_ch_np_rsp_q_rd_ptr) begin
        // If writing and pointers are equal then assert full flag
        s_b_ch_np_rsp_q_full = 1'b1; // ccx_line: u_axi_bridge.u_ib.u_axigm.u_aximw; REDUNDANT: Master completion buffer is sized to take all NP write responses so this queue never goes full
      end
    end else if (s_b_ch_np_rsp_q_rd) begin
      // If not writng and read active then de-assert full flag
      s_b_ch_np_rsp_q_full = 1'b0;
    end
    // Write the read segment information to the completion queue
    if (s_b_ch_np_rsp_q_wr) begin
      s_b_ch_np_rsp_q_ary[r_b_ch_np_rsp_q_wr_ptr] = s_b_ch_np_rsp_q_wr_info;
    end
    // Extract read segment information from the completion queue.
    s_b_ch_np_rsp_q_rd_info = r_b_ch_np_rsp_q_ary[r_b_ch_np_rsp_q_rd_ptr];
  end

  always @(posedge aclk or negedge aresetn) begin : proc_seq_b_ch_np_rsp_q
    integer i;
    if (!aresetn) begin
      r_b_ch_np_rsp_q_rd_ptr <= # TP {CC_WR_CH_NP_RSP_QUEUE_DP_LOG2{1'b0}};
      r_b_ch_np_rsp_q_wr_ptr <= # TP {CC_WR_CH_NP_RSP_QUEUE_DP_LOG2{1'b0}};
      r_b_ch_np_rsp_q_empty  <= # TP 1'b1;
      r_b_ch_np_rsp_q_full   <= # TP 1'b0;
      for (i=0; i<CC_WR_CH_NP_RSP_QUEUE_DP; i=i+1) begin
        r_b_ch_np_rsp_q_ary[i] <= # TP {WR_CH_NP_RSP_QUEUE_WD{1'b0}};
      end
    end else begin
      r_b_ch_np_rsp_q_wr_ptr <= # TP s_b_ch_np_rsp_q_wr_ptr;
      r_b_ch_np_rsp_q_full   <= # TP s_b_ch_np_rsp_q_full;
      r_b_ch_np_rsp_q_rd_ptr <= # TP s_b_ch_np_rsp_q_rd_ptr;
      r_b_ch_np_rsp_q_empty  <= # TP s_b_ch_np_rsp_q_empty;
      for (i=0; i<CC_WR_CH_NP_RSP_QUEUE_DP; i=i+1) begin
        r_b_ch_np_rsp_q_ary[i] <= # TP s_b_ch_np_rsp_q_ary[i];
      end
    end
  end


  // Detect B channel NP response queue entry
  assign s_b_ch_np_rsp_q_xfer_pending = !r_b_ch_np_rsp_q_empty;
  // Pop queue
  assign s_b_ch_np_rsp_q_rd = !r_b_ch_np_rsp_q_empty & s_bready_gc;
  // Extract B channel NP response info
  assign s_np_write_bresp              = s_b_ch_np_rsp_q_rd_info[WR_CH_NP_RESP_QUEUE_RESP_HIGH :WR_CH_NP_RESP_QUEUE_RESP_LOW ];
  assign s_np_write_bmisc_info_cpl_stat= s_b_ch_np_rsp_q_rd_info[WR_CH_NP_RESP_QUEUE_CPL_STAT_HIGH :WR_CH_NP_RESP_QUEUE_CPL_STAT_LOW];
  assign s_np_write_bid                = s_b_ch_np_rsp_q_rd_info[WR_CH_NP_RESP_QUEUE_ID_HIGH   :WR_CH_NP_RESP_QUEUE_ID_LOW   ];

  //--------------------------------------------------------------------------------------
  //Sequential Logic
  // rmisc_info lookup table

   always @(posedge aclk or negedge aresetn) begin: proc_rmisc_info_lut
   integer i;
     if (~aresetn)
       for(i=0;i< DEPTH; i=i+1) begin
         rmisc_info_lut[i] <= #TP {WIDTH{1'b0}};
       end
     else begin
       if ((arvalid && arready_int) || mread_nullrd_det)  begin// READ CHANNEL
          rmisc_info_lut[arid] <= #TP {mmisc_info[`MSTR_MISCINF_RANGE_TC_HIGH:`MSTR_MISCINF_RANGE_TC_LOW],
                                       mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_RO_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_NS_LOW],3'd0};
       end

       if (writeq.w_wq_write && writeq.w_wq_ready && (writeq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64})) begin
          rmisc_info_lut[writeq.w_wq_id] <= #TP {
                                                 writeq.w_wq_mmisc_info_tc,
                                                 writeq.w_wq_mmisc_info_ro,
                                                 writeq.w_wq_mmisc_info_ns,
                                                 3'd0
                                                };
       end
     end
   end // block: proc_rmisc_info_lut

   // bmisc_info lookup table
   // dn : RO & NS request info is stored in the MCB. This LUT is redundant.
   // Leave here for now to maintain formal equivalence.
   always @(posedge aclk or negedge aresetn) begin: proc_bmisc_info_lut
   integer i;
     if (~aresetn)
       for(i=0;i< DEPTH; i=i+1) begin
         bmisc_info_lut[i] <= #TP {WIDTH-1{1'b0}};
       end
     else begin
       if(awvalid && awready_int && !awmisc_info_is_p) begin  //WRITE CHANNEL
         bmisc_info_lut[awid] <= #TP {mmisc_info[`MSTR_MISCINF_RANGE_TC_HIGH:`MSTR_MISCINF_RANGE_TC_LOW],
                                      mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_RO_LOW], mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_NS_LOW],3'd0};
       end
     end
   end

  //--------------------------------------------------------------------------------------
  // dn: BMISC INFO is redundant. Leave here for now to maintain formal equivalence.
   assign arready_int        = arready;
   assign selected_rmisc_info  = {1'b1, rmisc_info_lut[rid]};
   assign selected_nrmisc_info = {1'b1, rmisc_info_lut[r_nread_sid]};
   // The response generated to MCB will always be a non-posted response
   assign selected_bmisc_info = {!r_b_ch_np_rsp_q_empty,bmisc_info_lut[s_np_write_bid]};
   assign rmisc_info_int     = {selected_rmisc_info[8], selected_rmisc_info[2:0], rmisc_info[`MSTR_RESP_MISC_INFO_TD_HIGH:`MSTR_RESP_MISC_INFO_TD_LOW],
                                collected_rmisc_info_ep, rmisc_info[`MSTR_RESP_MISC_INFO_BCM_HIGH:`MSTR_RESP_MISC_INFO_BCM_LOW],
                                selected_rmisc_info[7:5], 1'b0, selected_rmisc_info[4:3],
                                rmisc_info[`MSTR_RESP_MISC_INFO_ATS_HIGH:`MSTR_RESP_MISC_INFO_ATS_LOW]};
   // -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
   assign nr_rmisc_info_int =  {selected_nrmisc_info[8], selected_nrmisc_info[2:0], 1'b0, //TD bit is set to zero
                                1'b0, /*EP bit set to low*/  1'b0, /*BCM seto to low*/
                                selected_nrmisc_info[7:5], 1'b0, selected_nrmisc_info[4:3],
                                2'b00/*ATS all zeros*/};
   // -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
   assign bmisc_info_int     = {selected_bmisc_info[8], selected_bmisc_info[2:0], {`MSTR_RESP_MISC_INFO_TD_HIGH-`MSTR_RESP_MISC_INFO_TD_LOW+1{1'b0}},
                                1'b0, {`MSTR_RESP_MISC_INFO_BCM_HIGH-`MSTR_RESP_MISC_INFO_BCM_LOW+1{1'b0}},
                                selected_bmisc_info[7:5], 1'b0, selected_bmisc_info[4:3],
                                {`MSTR_RESP_MISC_INFO_ATS_HIGH-`MSTR_RESP_MISC_INFO_ATS_LOW+1{1'b0}}};




  //--------------------------------------------------------------------------------------
  // AXI Read Address Channel
  //--------------------------------------------------------------------------------------
  // DMA PF can generate null reads that shall never be forwarded to the application
  // 'd5 - write engine LL read
  // 'd7 - read engine LL read
  // 'd1 - DMA write engine data read
   wire   misc_info_dma_reads;
   assign misc_info_dma_reads =   (mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW] == 3'd5) ||
                                  (mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW] == 3'd7) ||
                                  (mmisc_info[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW] == 3'd1);
   assign araddr  = maddr[AXI_ADDR_WIDTH -1 :0];
   assign arlen   = rd_len_in_beats;
   assign arsize  = rd_msize;
   assign arburst = MSTR_BURST_TYPE;

   assign arlock  = {AXI_LOCK_WIDTH{1'b0}};
   assign s_mlen = (mlen == {MSTR_MTU_PW{1'b0}}) && (cfg_ax_mstr_zeroread_fw || misc_info_dma_reads)  ? {{MSTR_MTU_PW-1{1'b0}}, 1'b1} : mlen;

   assign armisc_info_zeroread = mread && (mlen == {MSTR_MTU_PW{1'b0}}) && (cfg_ax_mstr_zeroread_fw || misc_info_dma_reads);

   generate
   if (!WR_NOT_RD_QUEUE) begin : GEN_NCBE_ARVAL_RD// NCBE not required for WR Instance

      always @(*) begin : proc_comb_arvalid_int
         arvalid_int = mread && (mread_nullrd_det == 1'b0);
      end

      //Null read detection: 1 DWORD and Byte Enables Off
      assign mread_nullrd_det = mread && (mlen == {MSTR_MTU_PW{1'b0}}) && ((!cfg_ax_mstr_zeroread_fw) && (!misc_info_dma_reads)) ;

      assign arvalid = arvalid_int;
   end else begin : GEN_WR_NOT_RD_QUEUE

      always @(*) begin : proc_comb_wr_arvalid_int
         arvalid_int = mread;
      end

      assign mread_nullrd_det = 1'b0;
      assign arvalid = arvalid_int;
   end
   endgenerate


   assign arid    = mid;
   always @ ( * ) begin : PROC_comb_armisc_info

      armisc_info                        = {(CX_TAG_SIZE+40){1'b0}};
      armisc_info[CX_TAG_SIZE+39:40]     = mmisc_info[`MSTR_MISCINF_RANGE_TLP_TAG_HIGH:`MSTR_MISCINF_RANGE_TLP_TAG_LOW];
      armisc_info[39:24]                 = mmisc_info[`MSTR_MISCINF_RANGE_REQID_HIGH:`MSTR_MISCINF_RANGE_REQID_LOW];
      armisc_info[23:19]                 = mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW];
      armisc_info[18:16]                 = mmisc_info[`MSTR_MISCINF_RANGE_TC_HIGH:`MSTR_MISCINF_RANGE_TC_LOW];
      armisc_info[15]                    = mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_RO_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_RO_LOW];
      armisc_info[14]                    = mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_NS_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_NS_LOW];
      armisc_info[13:11]                 = 3'd0;
      //Function number width is truncated if the width is > 3
      armisc_info[11+MAX3_NFUNC_WD-1:11] = mmisc_info[`MSTR_MISCINF_RANGE_FUNC_NUM_LOW+MAX3_NFUNC_WD-1:`MSTR_MISCINF_RANGE_FUNC_NUM_LOW];
      armisc_info[10]                    = mmisc_info[`MSTR_MISCINF_RANGE_ROM_IN_RANGE_HIGH:`MSTR_MISCINF_RANGE_ROM_IN_RANGE_LOW];
      armisc_info[9]                     = mmisc_info[`MSTR_MISCINF_RANGE_IO_REQ_IN_RANGE_HIGH:`MSTR_MISCINF_RANGE_IO_REQ_IN_RANGE_LOW];

      if (WR_NOT_RD_QUEUE && ss_tlp_msg_or) begin
         armisc_info[8]                  = 1'd0;
         armisc_info[7:0]                = s_msg_code; // Note: awmisc_info initialised with armisc_info
      end else begin
         armisc_info[8:6]                = mmisc_info[`MSTR_MISCINF_RANGE_IN_MEMBAR_RANGE_HIGH:`MSTR_MISCINF_RANGE_IN_MEMBAR_RANGE_LOW];
         armisc_info[5:0]                = 6'd0;
      end

   end


   assign armisc_info_tlpprfx            = mmisc_info[`MSTR_MISCINF_RANGE_TLP_PRFX_HIGH:`MSTR_MISCINF_RANGE_TLP_PRFX_LOW];


   assign armisc_info_tph                = {mmisc_info[`MSTR_MISCINF_RANGE_TPH_SET_HIGH:`MSTR_MISCINF_RANGE_TPH_SET_LOW],
                                            mmisc_info[`MSTR_MISCINF_RANGE_TPH_PH_HIGH:`MSTR_MISCINF_RANGE_TPH_PH_LOW],
                                            mmisc_info[`MSTR_MISCINF_RANGE_TPH_TH_HIGH:`MSTR_MISCINF_RANGE_TPH_TH_LOW]};
   assign armisc_info_ido                = mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_IDO_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_IDO_LOW];
   assign armisc_info_dst_segment        = mmisc_info[`MSTR_MISCINF_RANGE_DST_SEGMENT_HIGH:`MSTR_MISCINF_RANGE_DST_SEGMENT_LOW];
   assign armisc_info_req_segment        = mmisc_info[`MSTR_MISCINF_RANGE_REQ_SEGMENT_HIGH:`MSTR_MISCINF_RANGE_REQ_SEGMENT_LOW];

   assign armisc_info_nw                 = mmisc_info[`MSTR_MISCINF_RANGE_NW_HIGH:`MSTR_MISCINF_RANGE_NW_LOW];
   assign armisc_info_cxlsrc             = mmisc_info[`MSTR_MISCINF_RANGE_CXLSRC_HIGH:`MSTR_MISCINF_RANGE_CXLSRC_LOW];
   assign armisc_info_ats                = mmisc_info[`MSTR_MISCINF_RANGE_ATS_HIGH:`MSTR_MISCINF_RANGE_ATS_LOW];


   assign arcache  = // CC_LTIM_ENABLE
                     { (~cfg_mstr_arcache_mode[3] ?                 mmem_type && ~nosnoop : cfg_mstr_arcache_value[3]),
                       (~cfg_mstr_arcache_mode[2] ?     mmem_type && th_value && ~nosnoop : cfg_mstr_arcache_value[2]),
                       (~cfg_mstr_arcache_mode[1] ?                             mmem_type : cfg_mstr_arcache_value[1]),
                       (~cfg_mstr_arcache_mode[0] ?                 mmem_type && ~nosnoop : cfg_mstr_arcache_value[0]) };

   assign arqos    = 4'b0000;
   assign ardomain = // CC_LTIM_ENABLE
                     { (~cfg_mstr_ardomain_mode[1] ?                                 1'b1 : cfg_mstr_ardomain_value[1]),
                       (~cfg_mstr_ardomain_mode[0] ? ~mmem_type || (mmem_type && nosnoop) : cfg_mstr_ardomain_value[0]) };
   assign arsnoop  = 4'b0000;
   assign arbar    = 2'b00;

   assign atop_pkt_fmt_type = pkg_atop_fmt_type_e'({mmisc_info[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW],mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]});

wire [BURST_LEN_PW-1:0] int_wr_len_in_beats;

generate
if (BURST_LEN_PW <= MSTR_MTU_PW) begin: gen_BURST_LEN_PW_LT_EQ_MSTR_MTU_PW_int_wr_len_in_beats
assign int_wr_len_in_beats = wr_len_in_beats[BURST_LEN_PW-1:0];
end else begin: gen_BURST_LEN_PW_GT_MSTR_MTU_PW_int_wr_len_in_beats
assign int_wr_len_in_beats = {{(BURST_LEN_PW-MSTR_MTU_PW){1'b0}},wr_len_in_beats};
end
endgenerate

generate
  if (WR_NOT_RD_QUEUE) begin : GEN_AXIWR_WRQ// NCBE not required for WR Instance
  //--------------------------------------------------------------------------------------
  // AXI Write Address Channel
  //--------------------------------------------------------------------------------------
   assign awaddr  = maddr[AXI_ADDR_WIDTH -1 :0];
   assign awlen   = int_wr_len_in_beats[BURST_LEN_PW-1:0];
   assign awsize  = wr_msize;
   assign maddr_naligned = addr_naligned(maddr,awsize,awlen);
  // In the presence of a CAS Atomic operation with an address which is not aligned to the total size of the data, the Burst should be of type WRAP
   assign awburst = ((atop_pkt_fmt_type inside {CAS32,CAS64}) && maddr_naligned) ? MSTR_BURST_TYPE_WRAP : MSTR_BURST_TYPE;
   assign awlock  = {AXI_LOCK_WIDTH{1'b0}};
   assign awvalid = (int_mwrite && !block_p_wr && (state == ST_MW_1ST_BEAT)) || (state == ST_MW_1ST_BEAT_W) || (state == ST_MW_1ST_BEAT_WL);
   assign awid    = mid;
   assign awmisc_info    = armisc_info;
   assign awmisc_info_hdr_uppr_bytes_valid = mmisc_info[`MSTR_MISCINF_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`MSTR_MISCINF_RANGE_HDR_UPPR_BYTES_VALID_LOW];
   assign awmisc_info_tlpprfx = mmisc_info[`MSTR_MISCINF_RANGE_TLP_PRFX_HIGH:`MSTR_MISCINF_RANGE_TLP_PRFX_LOW]; // Misc Info TLP Prefix


   assign awmisc_info_tph = {mmisc_info[`MSTR_MISCINF_RANGE_TPH_SET_HIGH:`MSTR_MISCINF_RANGE_TPH_SET_LOW],
                             mmisc_info[`MSTR_MISCINF_RANGE_TPH_PH_HIGH:`MSTR_MISCINF_RANGE_TPH_PH_LOW],
                             mmisc_info[`MSTR_MISCINF_RANGE_TPH_TH_HIGH:`MSTR_MISCINF_RANGE_TPH_TH_LOW]};
   assign awmisc_info_ido = mmisc_info[`MSTR_MISCINF_RANGE_TLP_ATTR_IDO_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_IDO_LOW];
   assign awmisc_info_dst_segment = mmisc_info[`MSTR_MISCINF_RANGE_DST_SEGMENT_HIGH:`MSTR_MISCINF_RANGE_DST_SEGMENT_LOW];
   assign awmisc_info_req_segment = mmisc_info[`MSTR_MISCINF_RANGE_REQ_SEGMENT_HIGH:`MSTR_MISCINF_RANGE_REQ_SEGMENT_LOW];

   assign awmisc_info_nw = mmisc_info[`MSTR_MISCINF_RANGE_NW_HIGH:`MSTR_MISCINF_RANGE_NW_LOW];
   assign awmisc_info_cxlsrc = mmisc_info[`MSTR_MISCINF_RANGE_CXLSRC_HIGH:`MSTR_MISCINF_RANGE_CXLSRC_LOW];
   assign awmisc_info_ats = mmisc_info[`MSTR_MISCINF_RANGE_ATS_HIGH:`MSTR_MISCINF_RANGE_ATS_LOW];
   assign awmisc_info_ep                 = mmisc_info[`MSTR_MISCINF_RANGE_EP_HIGH];

   assign awcache  = (mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH-1] == MSG) ? 4'b0000 : (
                     { (~cfg_mstr_awcache_mode[3] ?     mmem_type && th_value && ~nosnoop : cfg_mstr_awcache_value[3]),
                       (~cfg_mstr_awcache_mode[2] ?                 mmem_type && ~nosnoop : cfg_mstr_awcache_value[2]),
                       (~cfg_mstr_awcache_mode[1] ?                             mmem_type : cfg_mstr_awcache_value[1]),
                       (~cfg_mstr_awcache_mode[0] ?                 mmem_type && ~nosnoop : cfg_mstr_awcache_value[0]) })
                     ;

   assign awqos    = 4'b0000;
   assign awdomain = (mmisc_info[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH-1] == MSG)
                      ? 2'b11 :(
                     { (~cfg_mstr_awdomain_mode[1] ?                                    1 : cfg_mstr_awdomain_value[1]),
                       (~cfg_mstr_awdomain_mode[0] ? ~mmem_type || (mmem_type && nosnoop) : cfg_mstr_awdomain_value[0]) });
   assign awsnoop  = 3'b000;
   assign awbar    = 2'b00;
  // Set the AXI Atomic operation code according to the FMT and Type parameters of the package
   assign awatop   = (atop_pkt_fmt_type inside {FETCHADD32,FETCHADD64}) ? LOAD_LE :
                     (atop_pkt_fmt_type inside {SWAP32,SWAP64})         ? SWAP    :
                     (atop_pkt_fmt_type inside {CAS32,CAS64})           ? CAS     :
                      NONE;

   assign saccept_wrdata_set = wvalid && wready_int && ((!wlast && !hold_gif_last_data) || wlast);

   // saccept_wr is pulsed each time the slave accepts a beat of write data.
   // This allows the bridge to know when to present the next beat of write
   // data or the next write transfer on the master interface.
   // For the last beat of a burst, saccept_wr is not pulsed unless the
   // address information has already been accepted by the slave. If the
   // address information has not been accepted, saccept_wr for the last
   // beat is not pulsed until awvalid & awready are asserted.
   assign saccept_wr     = (saccept_wrdata_set & !wlast)
                         | (saccept_wrdata_set & (saccept_wraddr|(awvalid & awready_int)))
                         | (saccept_wrdata & (awvalid & awready_int))
;

   // The end of transfer when the slave has accepted the write transaction
   // occurs when either the last beat of write data is accepted and the
   // address data has already been accepted by the slave or else
   // when the slave accepts the address data after already having accepted
   // all of the write data
   assign saccept_wr_eot = (wlast & (saccept_wrdata_set & (saccept_wraddr|(awvalid & awready_int))))
                           | (saccept_wrdata & (awvalid & awready_int));

   //--------------------------------------------------------------------------------------
   // AXI Write Data Channel
   //--------------------------------------------------------------------------------------
  reg [AXI_DATA_WIDTH-1:0] masked_mdata;
  
  always@(*)begin
    integer i;
    
    masked_mdata = tmp_mdata;
    
    for(i=0;i<AXI_STRB_WIDTH;i=i+1)begin
      if(!tmp_mwstrb[i] || !wvalid)begin
        masked_mdata[i*BYTE_WIDTH+:BYTE_WIDTH] = AXI_DATA_INIT_BYTE;
      end  
    end
  end

         assign wdata  = masked_mdata;
         assign wstrb  = tmp_mwstrb;
         assign wlen   = int_wr_len_in_beats[BURST_LEN_PW-1:0];
         assign wvalid = (int_mwrite || (extra_beat && wlast)) && ((!block_p_wr && (state == ST_MW_1ST_BEAT)) || (state == ST_MW_1ST_BEAT_AW) || (state == ST_MW_INT_BEAT)) && (state != ST_MW_1ST_BEAT_W) && (state != ST_MW_1ST_BEAT_WL);
         assign wmisc_info_is_p = awmisc_info_is_p;
         assign wid    = mid;

         always@(posedge aclk or negedge aresetn)
           if(~aresetn)
             saccept_wrdata <= #TP 1'b0;
           else if (saccept_wrdata_set & wlast & !saccept_wr)
             saccept_wrdata <= #TP 1'b1; // Slave has accepted all write data // ccx_line: u_axi_bridge.u_ib.u_axigm.u_aximw; REDUNDANT: Register slice on the master AW channel ensures the awvalid from this block is always accepted before the last data beat so saccept_wr is never low.
           else if (saccept_wr)
             saccept_wrdata <= #TP 1'b0;

         always@(posedge aclk or negedge aresetn)
           if(~aresetn)
             saccept_wraddr <= #TP 1'b0;
           else if (awvalid & awready_int & !saccept_wr_eot)
             saccept_wraddr <= #TP 1'b1; // Slave has accepted write address
           else if (saccept_wr_eot)
             saccept_wraddr <= #TP 1'b0;

         always@(posedge aclk or negedge aresetn)
           if(~aresetn)
             awvalid_hold <= #TP 1'b0;
           else if (awvalid && !awready_int) // Hold awvalid asserted
             awvalid_hold <= #TP 1'b1;
           else if (awvalid && awready_int)  // Release when address accepted
             awvalid_hold <= #TP 1'b0;

         always@(posedge aclk or negedge aresetn)begin
           if(~aresetn)begin
             state <= #TP ST_MW_1ST_BEAT;
           end else begin
             state <= #TP next_state;
           end
         end

         always@(*) begin

           next_state = state;

           case(state)
             ST_MW_1ST_BEAT    : begin
                                   if(block_p_wr || !int_mwrite)begin
                                     next_state = ST_MW_1ST_BEAT;
                                   end else begin
                                     if(awvalid && awready)begin
                                       if(wvalid && wready)begin
                                         if(wlast)begin
                                           next_state = ST_MW_1ST_BEAT;
                                         end else begin
                                           next_state = ST_MW_INT_BEAT;
                                         end
                                       end else begin
                                         next_state = ST_MW_1ST_BEAT_AW;
                                       end
                                     end else begin
                                       if(wvalid && wready)begin
                                         if(wlast)begin
                                           next_state = ST_MW_1ST_BEAT_WL;
                                         end else begin
                                           next_state = ST_MW_1ST_BEAT_W;
                                         end
                                       end else begin
                                         next_state = ST_MW_1ST_BEAT;
                                       end
                                     end
                                   end
                                 end
             ST_MW_1ST_BEAT_W  : begin
                                   if(awvalid && awready)begin
                                     next_state = ST_MW_INT_BEAT;
                                   end else begin
                                     next_state = ST_MW_1ST_BEAT_W;
                                   end
                                 end
             ST_MW_1ST_BEAT_WL : begin
                                   if(awvalid && awready)begin
                                     next_state = ST_MW_1ST_BEAT;
                                   end else begin
                                     next_state = ST_MW_1ST_BEAT_WL;
                                   end
                                 end
             ST_MW_1ST_BEAT_AW : begin
                                   if(wvalid && wready)begin
                                     if(wlast)begin
                                       next_state = ST_MW_1ST_BEAT;
                                     end else begin
                                       next_state = ST_MW_INT_BEAT;
                                     end
                                   end else begin
                                     next_state = ST_MW_1ST_BEAT_AW;
                                   end
                                 end
             ST_MW_INT_BEAT    : begin
                                   if(wvalid && wready)begin
                                     if(wlast)begin
                                       next_state = ST_MW_1ST_BEAT;
                                     end else begin
                                       next_state = ST_MW_INT_BEAT;
                                     end
                                   end else begin
                                     next_state = ST_MW_INT_BEAT;
                                   end
                                 end
             default:            begin
                                   next_state = ST_MW_1ST_BEAT;
                                 end
           endcase
         end

`ifndef SYNTHESIS
wire    [32*8:0]         ST_MW_STATE;

assign  ST_MW_STATE   =      (state == ST_MW_1ST_BEAT   ) ? "ST_MW_1ST_BEAT"    :
                             (state == ST_MW_1ST_BEAT_W ) ? "ST_MW_1ST_BEAT_W"  :
                             (state == ST_MW_1ST_BEAT_WL) ? "ST_MW_1ST_BEAT_WL" :
                             (state == ST_MW_1ST_BEAT_AW) ? "ST_MW_1ST_BEAT_AW" :
                             (state == ST_MW_INT_BEAT   ) ? "ST_MW_INT_BEAT"    : "ERROR";

`endif // SYNTHESIS

         always@(posedge aclk or negedge aresetn) begin
            if(~aresetn)
              r_wr_in_burst <= #TP 1'b0;
            else
              r_wr_in_burst <= #TP s_wr_in_burst;
         end

         always @ ( * ) begin
            if (wvalid && wready_int && wlast)
              s_wr_in_burst = 1'b0;
            else if (wvalid && wready_int)
              s_wr_in_burst = 1'b1;
            else
              s_wr_in_burst = r_wr_in_burst;
         end

         always@(posedge aclk or negedge aresetn) begin
            if(~aresetn)
              r_aw_accepted <= #TP 1'b0;
            else
              r_aw_accepted <= #TP s_aw_accepted;
         end

         always @ ( * ) begin
            if (wvalid && wready_int && wlast)
              s_aw_accepted = 1'b0;
            else if (awvalid && awready_int)
              s_aw_accepted = 1'b1;
            else
              s_aw_accepted = r_aw_accepted;
         end

      end else begin : GEN_AXIWR_RDQ

         assign saccept_wr                       = 1'b0;

         assign awaddr                           = {(AXI_ADDR_WIDTH){1'b0}};
         assign awlen                            = {(BURST_LEN_PW){1'b0}};
         assign awsize                           = 3'b000;
         assign awburst                          = 2'b00;
         assign awlock                           = {AXI_LOCK_WIDTH{1'b0}};
         assign awvalid                          = 1'b0;
         assign awid                             = {(AXI_ID_WIDTH){1'b0}};
         assign awmisc_info                      = {(CX_TAG_SIZE+40){1'b0}};
         assign awmisc_info_hdr_uppr_bytes_valid = 1'b0;
         assign awmisc_info_tlpprfx              = {(RX_TLP_PREFIX_WD){1'b0}};


         assign awmisc_info_tph                  = {(MISC_INFO_TPH_WD){1'b0}};
         assign awmisc_info_ido                  = 1'b0;
         assign awmisc_info_dst_segment          = '0;
         assign awmisc_info_req_segment          = '0;

         assign awmisc_info_nw                   = 1'b0;
         assign awmisc_info_cxlsrc               = 1'b0;
         assign awmisc_info_ats                  = 2'b00;
         assign awmisc_info_ep                   = 1'b0;

         assign awcache                          = 4'b0000;
         assign awqos                            = 4'b0000;
         assign awdomain                         = 2'b00;
         assign awsnoop                          = 3'b000;
         assign awbar                            = 2'b00;
         assign awatop                           = NONE;

         assign wdata                            = {AXI_DATA_WIDTH{1'b0}};
         assign wstrb                            = {AXI_STRB_WIDTH{1'b0}};
         assign wlen                             = {BURST_LEN_PW{1'b0}};
         assign wvalid                           = 1'b0;
         assign wmisc_info_is_p                  = 1'b0;
         assign wid                              = {AXI_ID_WIDTH{1'b0}};

         always @ ( awvalid or awready or wvalid or wready ) begin
            saccept_wrdata = 1'b0;
            saccept_wraddr = 1'b0;
            awvalid_hold   = 1'b0;
            s_aw_w_cnt     = 1'b0;
            r_aw_w_cnt     = 1'b0;
            r_wr_in_burst  = 1'b0;
            s_wr_in_burst  = 1'b0;
         end

      end
   endgenerate

   generate
      if (!WR_NOT_RD_QUEUE) begin : GEN_SACCEPTRD_RDQ
         assign saccept_rd = (arvalid && arready) || (mread_nullrd_det && (!r_nread_svalid));
      end else begin : GEN_SACCEPTRD_WRQ
         assign saccept_rd = 1'b0;
      end
   endgenerate

   generate
   if (!WR_NOT_RD_QUEUE) begin : GEN_SACCEPT_RDQ // NCBE not required for WR Instance
      assign saccept = ((saccept_wr ||
                         saccept_rd));
   end else begin : GEN_SACCEPT_WRQ
      assign saccept = ((saccept_wr || (mabort && !presp_mstall) ||
                        saccept_rd));
   end
   endgenerate

   // Indicates write burst in progress on AXI side.
   always@(posedge aclk or negedge aresetn) begin : wburst_count_PROC
      if(~aresetn)
         wburst_count <= #TP 'd0;
      else begin
         if((wburst_count==wlen) && (wready_int && wvalid)) begin
            wburst_count <= #TP 'd0;
         end else if(wready_int && wvalid) begin
            wburst_count <= #TP wburst_count + 'd1;
         end
     end
   end

   assign wlast              = (wburst_count==wlen) && (int_mwrite || extra_beat);
   assign hold_gif_last_data = ((tmp_extra_beat && !r_wr_in_burst) | (extra_beat && r_wr_in_burst)) && (wburst_count == (wlen -1));


   generate
   if (!WR_NOT_RD_QUEUE) begin : GEN_GVALID_RDQ// RD
      assign gvalid        = rvalid & (!collect_required | rlast);
      assign rready_gc_tmp = gready ;
      assign bready_gc_tmp = 1'b0;
   end else begin : GEN_GVALID_WRQ // WR
      assign gvalid        = s_b_ch_np_rsp_q_xfer_pending;
      assign bready_gc_tmp = gready;
      assign rready_gc_tmp = 1'b0;
   end
   endgenerate

   assign gready = mready;


  // -------------------------------------------------------------------------------------
  // Collect Responses
  // -------------------------------------------------------------------------------------
wire   int_prefetch_disable;
assign int_prefetch_disable = (resp_size == 0) || resp_wrq_atop;
assign prefetch_disable = sub_bus_size_rd_valid_rd ? 1'b1 : int_prefetch_disable;

assign sub_bus_size_rd_valid_rd = sub_bus_size_re && is_mlen_pow2_rd && is_maddr_align_rd && (resp_rd_len_in_beats < 1);

// simple fix for 2,4,8 ...AXI_STRB_WIDTH/2  unaligned memory read
assign int_resp_low_addr = { {(MAX_AXI_STRB_PW - AXI_STRB_PW){1'b0}}, resp_low_addr};
always@(resp_size or int_resp_low_addr)
  begin
    case (resp_size)
      3'b010:
        begin
           is_mlen_pow2_rd = 1'b1;
           is_maddr_align_rd = (int_resp_low_addr[1:0]==2'b00) ? 1'b1 : 1'b0;
        end
      3'b011:
        begin
           is_mlen_pow2_rd = 1'b1;
           is_maddr_align_rd = (int_resp_low_addr[2:0]==3'b000) ? 1'b1 : 1'b0;
        end
      3'b100:
        begin
           is_mlen_pow2_rd = 1'b1;
           is_maddr_align_rd = (int_resp_low_addr[3:0]==4'b0000) ? 1'b1 : 1'b0;
        end
      3'b101:
        begin
           is_mlen_pow2_rd = 1'b1;
           is_maddr_align_rd = (int_resp_low_addr[4:0]==5'b00000) ? 1'b1 : 1'b0;
        end
      default:
         begin
           is_mlen_pow2_rd = 1'b0;
           is_maddr_align_rd = 1'b0;
         end
    endcase
  end

logic [AXI_STRB_WIDTH -1 :0]  tmp_byte_en;
`ifndef SYNTHESIS
wire [AXI_STRB_WIDTH -1 :0]  tmp_byte_en_lgcy;
`endif // SYNTHESIS
wire [AXI_STRB_WIDTH -1 :0]  resp_remain_byte_en;
wire [AXI_STRB_WIDTH -1 :0]  resp_addr_mask;
wire [AXI_STRB_WIDTH -1 :0]  resp_byte_en;

assign resp_addr_mask    = get_addr_mask(resp_low_addr);
assign resp_byte_en      = get_byte_en(resp_remain_bytes);

assign resp_remain_byte_en = resp_addr_mask & resp_byte_en;


wire start_rd_resp;
wire [AXI_STRB_PW -1 :0] collected_bytecnt_rid;

assign collected_bytecnt_rid = collected_bytecnt[rid];

always@(posedge aclk or negedge aresetn)
if(~aresetn)
   rd_resp_in_progress <= #TP { CC_MAX_MSTR_TAGS {1'b0}};
else if (rlast && rready && rvalid)
   rd_resp_in_progress[rid] <= #TP 1'b0;
else if (rvalid && rready)
   rd_resp_in_progress[rid] <= #TP 1'b1;

reg [CC_MAX_MSTR_TAGS-1:0] collected_1st_beat;
always@(posedge aclk or negedge aresetn)
if(~aresetn)
   collected_1st_beat <= #TP 1'b0;
else if (rlast && rready && rvalid)
   collected_1st_beat[rid] <= #TP 1'b0;
else if ((((&collected_bytecnt[rid]) && rd_resp_in_progress[rid]) || ((&resp_low_addr) && !rd_resp_in_progress[rid])) && rvalid && rready && prefetch_disable)
   collected_1st_beat[rid] <= #TP 1'b1;

wire [(2*AXI_STRB_WIDTH) -1 :0]  shift_resp_byte_en;
assign shift_resp_byte_en = ({{AXI_STRB_WIDTH{1'b0}}, resp_byte_en} << resp_low_addr);
assign start_rd_resp    = rvalid && !rd_resp_in_progress[rid];


logic first_beat_detect_no_prefetch;
logic first_beat_detect_w_prefetch;
logic last_beat_detect;

`ifndef SYNTHESIS
// Retain legacy byte_enable generation proc for debug purposes
// byte_en differnt from 0x...FF only possible for first or last response of a set of decomposed responses
assign tmp_byte_en_lgcy = (!collected_1st_beat[rid] && prefetch_disable) && (resp_last_stretch || resp_first_stretch) ? shift_resp_byte_en[AXI_STRB_WIDTH -1 :0]  //first - f(resp_low_addr, rd_remain_byte)
                          : (rlast && prefetch_disable)  && (resp_last_stretch || resp_first_stretch) ? (shift_resp_byte_en[(2*AXI_STRB_WIDTH) -1 : AXI_STRB_WIDTH]) //last - f(resp_low_addr, rd_remain_byte)
                          : (start_rd_resp && !prefetch_disable && !rlast)  && (resp_last_stretch || resp_first_stretch) ? (resp_addr_mask) // first - f(resp_low_addr)
                          : (start_rd_resp && !prefetch_disable && rlast) && (resp_last_stretch || resp_first_stretch) ? (resp_byte_en << resp_low_addr) //first or last -f(resp_low_addr, rd_remain_byte)
                          : (rlast && !prefetch_disable) && (resp_last_stretch || resp_first_stretch) ? (resp_byte_en) // last - f(resp_low_addr, rd_remain_byte)
                          : (rd_resp_in_progress[rid] && !prefetch_disable) || !(resp_last_stretch || resp_first_stretch) ? {AXI_STRB_WIDTH{1'b1}} // intermediate request - all byte_enable set
                          : {AXI_STRB_WIDTH{1'b0}};



`endif // SYNTHESIS

always_comb begin : cproc_tmp_byte_en


  // As the ancient scriptures of the axi_gm_core dictate, 1st burst beat is different depending on prefetchability
  first_beat_detect_no_prefetch = !collected_1st_beat[rid];
  first_beat_detect_w_prefetch  = start_rd_resp;
  last_beat_detect              = rlast;

  // If we are in either the first or last decomposed burst we need to trim the byte_enables of first and last beats
  if( resp_first_stretch || resp_last_stretch) begin

    // And not prefetching
    if( prefetch_disable) begin
      // First beat of 2-beat burst OR single beat burst
      if(first_beat_detect_no_prefetch) begin tmp_byte_en = shift_resp_byte_en[AXI_STRB_WIDTH -1 :0];                   end
      // Last beat of 2-beat burst
      else if(last_beat_detect)         begin tmp_byte_en = shift_resp_byte_en[(2*AXI_STRB_WIDTH) -1 : AXI_STRB_WIDTH]; end
      // Bursts without prefetch do not have more than 2 beats
      else                              begin tmp_byte_en = '0;                                                         end
    end

    // And prefetching
    else begin
      // First beat of long burst
      if(first_beat_detect_w_prefetch && !last_beat_detect)     begin tmp_byte_en = resp_addr_mask;                end
      // Single beat burst on mstr_fixed_size_enable
      else if(first_beat_detect_w_prefetch && last_beat_detect) begin tmp_byte_en = resp_byte_en << resp_low_addr; end
      // Last beat of long burst OR single beat burst on non-mstr_fixed_size_enable
      else if(last_beat_detect)                                 begin tmp_byte_en = resp_byte_en;                  end
      // Middle beats of long burst
      else if( rd_resp_in_progress[rid])                         begin tmp_byte_en = '1;                            end
      // Unreachable statement, probably
      else                                                      begin tmp_byte_en = '0;                            end
    end

  end

  // If response is to a middle decomposed burst
  else begin
    tmp_byte_en = '1;
  end
end : cproc_tmp_byte_en


always@(posedge aclk or negedge aresetn)
begin : COLLECTED_BYTECNT_PROC
integer i;
  if(~aresetn)
      for(i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
          collected_bytecnt[i]  <= #TP {AXI_STRB_PW{1'b0}};
      end
  else if (rlast && rready && rvalid)
     collected_bytecnt[rid] <= #TP {AXI_STRB_PW{1'b0}};
  else if (rvalid && rready && rd_resp_in_progress[rid] && prefetch_disable)
     collected_bytecnt[rid] <= #TP collected_bytecnt[rid] +1;
  else if (rvalid && rready && !rd_resp_in_progress[rid] &&  prefetch_disable)
     collected_bytecnt[rid] <= #TP collected_bytecnt[rid] + resp_low_addr +1;
end


// the first error is propagated to MCB
always@(posedge aclk or negedge aresetn)
begin: COLLECT_RRESP
integer i;
   if(~aresetn) begin
      for (i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        collected_rresp_d[i] <= #TP 2'b00;
        collected_rmisc_info_cpl_stat_d[i] <= #TP {(`DC_CPL_STATUS_WD){1'b0}};
        r_sresp_cpl_stat_err[i]  <= # TP 1'b0;
        collected_rmisc_info_ep_d[i] <= #TP 1'b0;
      end
   end else if (rvalid && rready && rlast) begin
      collected_rresp_d[rid] <= #TP 2'b00;
      collected_rmisc_info_cpl_stat_d[rid] <= #TP {(`DC_CPL_STATUS_WD){1'b0}};
      r_sresp_cpl_stat_err[rid]  <= # TP 1'b0;
      collected_rmisc_info_ep_d[rid] <= # TP 1'b0;
   end else if (rvalid && rready) begin
      if (r_sresp_cpl_stat_err[rid] == 0 && (rresp!=0 || (rmisc_info_cpl_stat!=SU) )) begin // the first error, either in cpl stat or resp is propagated to the MCB
          r_sresp_cpl_stat_err[rid] <=  # TP 1'b1;
          collected_rresp_d[rid] <=  # TP rresp;
          collected_rmisc_info_cpl_stat_d[rid]<=  # TP rmisc_info_cpl_stat;
      end
      if(rmisc_info[`MSTR_RESP_MISC_INFO_EP_HIGH:`MSTR_RESP_MISC_INFO_EP_LOW]) begin
        collected_rmisc_info_ep_d[rid] <= # TP 1'b1;
      end
   end
end

assign collected_rresp =r_sresp_cpl_stat_err[rid]? collected_rresp_d[rid] : rresp;
assign collected_rmisc_info_cpl_stat = r_sresp_cpl_stat_err[rid]? collected_rmisc_info_cpl_stat_d[rid] : rmisc_info_cpl_stat;
assign collected_rmisc_info_ep = collected_rmisc_info_ep_d[rid] | rmisc_info[`MSTR_RESP_MISC_INFO_EP_HIGH:`MSTR_RESP_MISC_INFO_EP_LOW];



// For all intermediate response collect_required must be '0'
assign collect_required = (resp_last_stretch || resp_first_stretch) ? prefetch_disable && ((!(&collected_bytecnt[rid]) && rd_resp_in_progress[rid]) || (!(&resp_low_addr) && !rd_resp_in_progress[rid]) || rlast) && (!(is_mlen_pow2_rd)&&!(is_maddr_align_rd)) : 1'b0;

// Avoiding changes in the rid/id when rvalid/bvalid are deasserted
reg [AXI_ID_WIDTH-1:0] rid_d;


assign rid_latch = rvalid ? rid : rid_d;

always@(posedge aclk or negedge aresetn)
   if(~aresetn)
      rid_d <= #TP {CC_WR_CH_P_REQ_QUEUE_DP_LOG2{1'b0}};
   else if (rvalid)
      rid_d <= #TP rid;


   // -------------------------------------------------------------------------------------
   // --- Null read response synthesizer ---
   // -------------------------------------------------------------------------------------
   // The null read is not propagated to the AR channel, so this code synthesizes the
   // response. Back to back reads are not dispatched back 2 back, however it does not
   // realistic to expect and resolve back 2 back null reads, so this will not create a
   // real performance bottleneck



   generate
     if (!WR_NOT_RD_QUEUE) begin : GEN_NREAD_RDQ
       always @ (posedge aclk or negedge aresetn) begin : PROC_SEQ_nread
         if(~aresetn) begin
           r_nread_svalid      <= #TP 1'b0;
           r_nread_sid         <= #TP {AXI_ID_WIDTH{1'b0}};
         end else begin
           if (s_nread_svalid_pls) begin
             r_nread_svalid    <= #TP 1'b0;
           end else if(mread_nullrd_det && saccept_rd) begin
             r_nread_svalid    <= #TP 1'b1;
           end
           if(mread_nullrd_det && saccept_rd && (!r_nread_svalid)) begin
             r_nread_sid       <= #TP mid;
           end
         end
       end // block: PROC_SEQ_nread

       // If the interface to the MCB is idle, take the oportunity to offload it
       assign s_nread_svalid_pls = (!svalid_i && r_nread_svalid && mready);
     end else begin : GEN_NREAD_WRQ // if (!WR_NOT_RD_QUEUE)
       always_comb begin
         r_nread_svalid = 1'b0;
         r_nread_sid    = {AXI_ID_WIDTH{1'b0}};
       end
       assign s_nread_svalid_pls = 1'b0;
     end
   endgenerate



  assign stall_mwr_ready_atop = '0;


   assign s_svalid = svalid_i || s_nread_svalid_pls;
   assign svalid = s_svalid;


  // -------------------------------------------------------------------------------------
  // GIF Response Channel Outputs
  // -------------------------------------------------------------------------------------
   generate
   if (!WR_NOT_RD_QUEUE) begin : GEN_RREADY_GC_RDQ// RD
      assign rready_gc  = rready_gc_tmp;
   end else begin : GEN_RREADY_GC_WRQ // WR
      assign rready_gc  = rready_gc_tmp;
   end
   endgenerate
   assign bready_gc  = bready_gc_tmp;


generate
 if (!WR_NOT_RD_QUEUE) begin : GEN_SVALID_RDQ // NCBE not required for WR Instance
   assign svalid_i            =  gvalid;
   assign s_sid               =  s_nread_svalid_pls ? r_nread_sid : rid_latch;
   assign sid                 =  s_sid;
   assign slast               =  rlast    || s_nread_svalid_pls;

   assign sbyte_en            =  s_nread_svalid_pls ? {{AXI_STRB_WIDTH-1{1'b0}},1'b1} : tmp_byte_en;

   assign sresp               =  s_nread_svalid_pls ? 3'd0 : {collected_rresp, 1'b0};
   assign smisc_info_cpl_stat =  s_nread_svalid_pls ? {(`DC_CPL_STATUS_WD){1'b0}} : imisc_info_cpl_stat;
   assign imisc_info_cpl_stat =  collected_rmisc_info_cpl_stat;
   assign smisc_info          =  s_nread_svalid_pls ? nr_rmisc_info_int : rmisc_info_int;
 end
 else begin : GEN_SVALID_WRQ
   assign svalid_i   = (gvalid);
   //assign svalid     = s_svalid;
   assign s_sid      = s_np_write_bid[AXI_ID_WIDTH-1:0];
   assign sid        = s_sid;
   assign slast      = 1'b1;

   assign sbyte_en   = {AXI_STRB_WIDTH{1'b0}};


   assign sresp      = {s_np_write_bresp, 1'b1};
   assign smisc_info_cpl_stat = imisc_info_cpl_stat;
   assign imisc_info_cpl_stat = {s_np_write_bmisc_info_cpl_stat};
   assign smisc_info = bmisc_info_int;


 end
endgenerate
generate
 if (!WR_NOT_RD_QUEUE) begin : GEN_RREADY_RDQ // NCBE not required for WR Instance
   assign rready      = rready_gc ;
   assign s_bready_gc = bready_gc ;
 end
 else begin : GEN_RREADY_WRQ
   assign rready      = rready_gc;
   assign s_bready_gc = bready_gc ;
 end
endgenerate

  wire [AXI_STRB_WIDTH+3:0] s_fbe_mask_tmp;
  wire [AXI_STRB_WIDTH+3:0] s_lbe_mask_tmp;
  wire [AXI_STRB_WIDTH-1:0] s_fbe_mask;
  wire [AXI_STRB_WIDTH-1:0] s_lbe_mask;

  assign s_rd_ctrl_be_sid    = rd_ctrl_be_ary[s_sid];
  assign s_rd_ctrl_ncbe_sid  = rd_ctrl_ncbe_ary[s_sid];
  assign s_rd_first_beat_sid = rd_first_beat_ary[s_sid];

generate
if(!WR_NOT_RD_QUEUE && AXI_STRB_WIDTH==4)begin : GEN_BE_MASK_RD_DATA_EQ_32
  assign s_fbe_mask     = s_rd_ctrl_be_sid[3:0];
  assign s_lbe_mask     = s_rd_ctrl_be_sid[7:4];
end else if (!WR_NOT_RD_QUEUE)begin : GEN_BE_MASK_RD_DATA_GT_32
  assign s_fbe_mask_tmp = {{AXI_STRB_WIDTH{1'b0}},s_rd_ctrl_be_sid[3:0]} <<  {resp_low_addr[AXI_STRB_PW-1:2],2'b00};
  assign s_lbe_mask_tmp = {{AXI_STRB_WIDTH{1'b0}},s_rd_ctrl_be_sid[7:4]} << ({resp_low_addr[AXI_STRB_PW-1:2],2'b00} + {{(AXI_STRB_PW-3){1'b0}},3'b100});
  assign s_fbe_mask     = s_fbe_mask_tmp[AXI_STRB_WIDTH-1:0];
  assign s_lbe_mask     = s_lbe_mask_tmp[AXI_STRB_WIDTH-1:0];
end else begin : GEN_BE_MASK_WR
  assign s_fbe_mask     = '0;
  assign s_lbe_mask     = '0;
end
endgenerate


generate
 if (!WR_NOT_RD_QUEUE) begin : GEN_SDATA_RDQ // NCBE not required for WR Instance//data must not be collected for intermediate responses

  always @(*) begin : proc_comb_sdata
    integer i;

    sdata = AXI_BUS_INIT;
    for(i=0;i<AXI_STRB_WIDTH;i=i+1)begin
      if ( s_nread_svalid_pls || (s_rd_ctrl_be_sid == '0)) begin
         sdata[i*BYTE_WIDTH+:BYTE_WIDTH] = AXI_DATA_INIT_BYTE;
      end else begin
        if(sbyte_en[i])begin
          if(!s_rd_ctrl_ncbe_sid || (s_rd_first_beat_sid && s_fbe_mask[i]) || (slast && s_lbe_mask[i]))begin
            sdata[i*BYTE_WIDTH+:BYTE_WIDTH] = rdata[i*BYTE_WIDTH+:BYTE_WIDTH] ;
          end else begin
            sdata[i*BYTE_WIDTH+:BYTE_WIDTH] = AXI_DATA_INIT_BYTE;
          end
        end else begin
          sdata[i*BYTE_WIDTH+:BYTE_WIDTH] = AXI_DATA_INIT_BYTE;
        end
      end
    end
  end
 end
 else begin : GEN_SDATA_WRQ
  always @(*) begin : proc_comb_sdata
    sdata = rdata;
  end
 end
endgenerate

  //--------------------------------------------------------------------------------------
  // Low Power Support.
  //--------------------------------------------------------------------------------------
   // The gasket will go into a fail-safe state by driving all ready and valid
   // outputs low. The gasket makes sure there are no pending requests
   // before it acknowledges a low power request.
   assign no_pend_trans = !(s_svalid || mread || int_mwrite);

   assign cactive          = 1'b1;
   assign csysack          = 1'b1;



function automatic [AXI_STRB_WIDTH -1:0] get_byte_en;
    input   [AXI_BUS_BYTECNT_PW -1:0]   offset;
    integer i;
begin
     get_byte_en = { AXI_STRB_WIDTH {1'b0}};
     for (i=0; i<AXI_STRB_WIDTH; i=i+1) begin
          get_byte_en[i] =  (i <= (offset -1));
     end
end
endfunction

function automatic [AXI_STRB_WIDTH -1:0] get_addr_mask;
    input   [AXI_STRB_PW -1:0]   offset;
    integer i;
begin
     get_addr_mask = 'd0;
     for (i=0; i<AXI_STRB_WIDTH; i=i+1) begin
          get_addr_mask[i] = (i >= offset);
     end
end
endfunction


  //--------------------------------------------------------------------------------------
  // REQUEST COUNTER
  //--------------------------------------------------------------------------------------
reg [AXI_ID_WIDTH-1:0] arid_del;
reg [AXI_ID_WIDTH-1:0] rid_del;
reg saccept_rd_lowp_del; // dn: redundant code
wire saccept_rd_lowp;
wire saccept_pulse;

assign saccept_rd_lowp= saccept_rd;

always@(posedge aclk or negedge aresetn)
begin: ID_DELAY_BLK

  if (~aresetn) begin
    rid_del        <= #TP {AXI_ID_WIDTH{1'b0}};
    arid_del       <= #TP {AXI_ID_WIDTH{1'b0}};
    saccept_rd_lowp_del    <= #TP 1'b0;
  end else begin
    rid_del                <= #TP rid;
    saccept_rd_lowp_del    <= #TP saccept_rd_lowp;
    if (mread && saccept) arid_del <= #TP arid;
  end
end

assign saccept_pulse = saccept_rd_lowp ;


reg  [`CC_MSTR_MAX_SPLIT_PACK_PW -1:0] req_cnt [CC_MAX_MSTR_TAGS -1:0];
wire [`CC_MSTR_MAX_SPLIT_PACK_PW -1:0] req_cnt_arid_plus1;
wire [`CC_MSTR_MAX_SPLIT_PACK_PW -1:0] req_cnt_arid;
wire [`CC_MSTR_MAX_SPLIT_PACK_PW -1:0] req_cnt_rid;
wire [`CC_MSTR_MAX_SPLIT_PACK_PW -1:0] req_cnt_rid_del;
wire req_first;
wire req_last;
wire resp_first;
wire resp_last;

logic [CC_MAX_MSTR_TAGS -1:0] req_atomic_active_request;

reg  [CC_MAX_MSTR_TAGS -1:0] resp_first_latch;
reg  [CC_MAX_MSTR_TAGS -1:0] resp_last_latch;

assign req_cnt_arid = req_cnt[arid];
assign req_cnt_rid = req_cnt[rid];
assign req_cnt_rid_del = req_cnt[rid_del];
assign req_cnt_arid_plus1 = req_cnt[arid] + 1;
assign req_first = (req_cnt_arid == 0) ? 1'b1 : 1'b0;
assign req_last = mlast_tlp;


always@(posedge aclk or negedge aresetn)
begin: REQUEST_COUNTER_BLK
integer i;

  if (~aresetn) begin

    for(i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        req_cnt[i]  <= #TP { `CC_MSTR_MAX_SPLIT_PACK_PW {1'b0}};
    end

  end else begin
    // at each new req
    if (saccept_pulse && mread && !mread_nullrd_det) begin
        req_cnt[arid] <= #TP req_cnt_arid_plus1;
    end

    // Can be set to 1 since there'll only be one active request for each atomic ID
  if ((writeq.w_wq_write & writeq.w_wq_ready) && ~req_atomic_active_request[writeq.w_wq_id] && (writeq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64})) begin
        req_cnt[writeq.w_wq_id] <= #TP `CC_MSTR_MAX_SPLIT_PACK_PW'(1'b1);
    end

    // response completed => counter is reset
    if (resp_last) begin
         req_cnt[rid] <= #TP { `CC_MSTR_MAX_SPLIT_PACK_PW {1'b0}};
    end
  end
end

always@(posedge aclk or negedge aresetn) begin
  if (~aresetn) begin
    req_atomic_active_request <= #TP '0;
  end else begin
    if (writeq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64}) begin
      if (req_atomic_active_request[writeq.w_wq_id] & writeq.w_wq_write & writeq.w_wq_ready & writeq.w_wq_last)
        req_atomic_active_request[writeq.w_wq_id] <= #TP 1'b0;
      else if (~req_atomic_active_request[writeq.w_wq_id] & writeq.w_wq_write & writeq.w_wq_ready & ~writeq.w_wq_last)
        req_atomic_active_request[writeq.w_wq_id] <= #TP 1'b1;
    end
  end
end

  //--------------------------------------------------------------------------------------
  // RESPONSE COUNTER
  //--------------------------------------------------------------------------------------
// start_rd_resp
reg [CC_MAX_MSTR_TAGS-1:0] rd_resp_in_progress_mod;
wire  start_rd_resp_mod;

always@(posedge aclk or negedge aresetn)
if(~aresetn)
   rd_resp_in_progress_mod <= #TP { CC_MAX_MSTR_TAGS {1'b0}};
else if (rlast && rready && rvalid)
   rd_resp_in_progress_mod[rid] <= #TP 1'b0;
else if (rvalid)
   rd_resp_in_progress_mod[rid] <= #TP 1'b1;

assign start_rd_resp_mod    = rvalid && !rd_resp_in_progress_mod[rid];

reg  [`CC_MSTR_MAX_SPLIT_PACK_PW -1:0] resp_cnt [CC_MAX_MSTR_TAGS-1:0];
reg  [CC_MAX_MSTR_TAGS -1:0] last_req_issued;
wire [`CC_MSTR_MAX_SPLIT_PACK_PW- 1 : 0] resp_cnt_rid;
wire [`CC_MSTR_MAX_SPLIT_PACK_PW- 1 : 0] resp_cnt_rid_del;
wire [`CC_MSTR_MAX_SPLIT_PACK_PW- 1 : 0] resp_cnt_rid_plus1;

assign resp_cnt_rid = resp_cnt[rid];
assign resp_cnt_rid_del = resp_cnt[rid_del];
assign resp_cnt_rid_plus1 = resp_cnt_rid + 1;
assign resp_first = (resp_cnt_rid == 0) ? 1'b1 : 1'b0;
assign resp_last = start_rd_resp_mod && (resp_cnt_rid_plus1==req_cnt_rid) && last_req_issued[rid];

assign resp_first_stretch = start_rd_resp_mod ? resp_first : resp_first_latch[rid];
assign resp_last_stretch = start_rd_resp_mod ? resp_last : resp_last_latch[rid];

always@(posedge aclk or negedge aresetn)
begin: RESP_FIRST_LAST_LATCH

  if(~aresetn) begin

    resp_first_latch <= #TP { CC_MAX_MSTR_TAGS {1'b0}};
    resp_last_latch <= #TP { CC_MAX_MSTR_TAGS {1'b0}};

  end else begin

    if (start_rd_resp_mod) begin
      resp_first_latch[rid]  <= #TP resp_first;
      resp_last_latch[rid] <= #TP resp_last;

    end


  end
end


always@(posedge aclk or negedge aresetn)
begin: RESPONSE_COUNTER_BLK
integer i;
  if(~aresetn) begin

    for(i=0; i<CC_MAX_MSTR_TAGS; i=i+1) begin
        resp_cnt[i]  <= #TP { `CC_MSTR_MAX_SPLIT_PACK_PW {1'b0}};
    end

  end else begin

    // at each start of burst increment
    if (start_rd_resp_mod) begin
      resp_cnt[rid] <= #TP resp_cnt_rid_plus1;
    end

    // response completed => cleared counter
    if (resp_last) begin
      resp_cnt[rid] <= #TP { `CC_MSTR_MAX_SPLIT_PACK_PW {1'b0}};
    end

  end
end

  //--------------------------------------------------------------------------------------
  // LAST REQUEST ISSUED
  //--------------------------------------------------------------------------------------

always@(posedge aclk or negedge aresetn)
begin: LAST_REQ_ISSUED_BLK

  if (~aresetn) begin

    last_req_issued <= #TP {CC_MAX_MSTR_TAGS{1'b0}};

  end else begin

    // last request has been issued
    if (saccept_pulse && mread && mlast_tlp && !mread_nullrd_det) begin
       last_req_issued [arid] <= #TP 1'b1;
    end

    // Every atomic request is the last request issued
  if (writeq.w_wq_write && ~req_atomic_active_request[writeq.w_wq_id] && writeq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64} && writeq.w_wq_ready) begin
      last_req_issued [writeq.w_wq_id] <= #TP 1'b1;
    end

    // last response has been received
    if (resp_last) begin
       last_req_issued [rid] <= #TP 1'b0; // HL: rid_del to rid
    end

  end

end

  //--------------------------------------------------------------------------------------
  // STORING INFO
  //--------------------------------------------------------------------------------------
wire                                               pkt_idx_get;
wire [2:0]                                         resp_size_modi;
wire [CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 -1:0]    resp_low_addr_modi;
wire [AXI_BUS_BYTECNT_PW -1 :0]                    resp_remain_bytes_modi;
wire [BURST_LEN_PW -1:0]                           resp_rd_len_in_beats_modi;

reg  [AXI_BUS_BYTECNT_PW -1 :0] rd_remain_bytecnt_info_ary [CC_MAX_MSTR_TAGS -1:0] [1:0] ;
reg  [CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1 : 0] rd_low_addr_info_ary [CC_MAX_MSTR_TAGS -1:0] [1:0] ;
reg  [2:0] rd_size_info_ary [CC_MAX_MSTR_TAGS -1:0] [1:0] ;
reg  [ BURST_LEN_PW-1 : 0] rd_len_in_beats_info_ary [CC_MAX_MSTR_TAGS -1:0] [1:0] ;
reg rd_wrq_atop_ary [CC_MAX_MSTR_TAGS -1:0] [1:0];


always@(posedge aclk or negedge aresetn)
begin: STORING_INFO_BLK
integer i;
integer j;
  if(~aresetn) begin

    for (j=0;j<CC_MAX_MSTR_TAGS;j=j+1) begin
      for (i=0;i<2;i=i+1) begin
        rd_remain_bytecnt_info_ary [j] [i] <= #TP { AXI_BUS_BYTECNT_PW {1'b0}};
        rd_low_addr_info_ary [j] [i] <= #TP { CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 {1'b0}};
        rd_size_info_ary [j] [i] <= #TP 3'd0;
        rd_len_in_beats_info_ary [j] [i] <= #TP { BURST_LEN_PW {1'b0}};
        rd_wrq_atop_ary [j] [i] <= #TP 1'b0;
      end
        rd_ctrl_be_ary [j] <= #TP '0;
        rd_ctrl_ncbe_ary [j]  <= #TP '0;
    end

  end else begin
    if (mread && saccept) begin
      if (req_first || req_last) begin
        if (req_first) begin
          rd_remain_bytecnt_info_ary [arid] [0] <= #TP req_remain_bytes;
          rd_low_addr_info_ary [arid] [0] <= #TP tmp_low_maddr;
          rd_size_info_ary [arid] [0] <= #TP rd_msize;
          rd_len_in_beats_info_ary [arid] [0] <= #TP rd_len_in_beats;
          rd_ctrl_be_ary [arid]  <= #TP mbe_ctrl;
          rd_ctrl_ncbe_ary [arid]  <= #TP ncbe_1dw(mbe_ctrl) || ncbe_2dw(mbe_ctrl);
        end else begin
          rd_remain_bytecnt_info_ary [arid] [1] <= #TP req_remain_bytes;
          rd_low_addr_info_ary [arid] [1] <= #TP tmp_low_maddr;
          rd_size_info_ary [arid] [1] <= #TP rd_msize;
          rd_len_in_beats_info_ary [arid] [1] <= #TP rd_len_in_beats;
        end
        rd_wrq_atop_ary [arid] [0] <= #TP 1'b0;
        rd_wrq_atop_ary [arid] [1] <= #TP 1'b0;
      end
    end
    if (writeq.w_wq_write && writeq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64}) begin
      rd_remain_bytecnt_info_ary [writeq.w_wq_id] [0] <= #TP wrq_req_remain_bytes;
      rd_remain_bytecnt_info_ary [writeq.w_wq_id] [1] <= #TP wrq_req_remain_bytes;
      rd_low_addr_info_ary       [writeq.w_wq_id] [0] <= #TP writeq.w_wq_addr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:0];
      rd_low_addr_info_ary       [writeq.w_wq_id] [1] <= #TP writeq.w_wq_addr[CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2-1:0];
      rd_ctrl_be_ary             [writeq.w_wq_id]     <= #TP 8'hff;
      rd_ctrl_ncbe_ary           [writeq.w_wq_id]     <= #TP 1'b0;
      rd_size_info_ary           [writeq.w_wq_id] [0] <= #TP wrq_rd_msize;
      rd_size_info_ary           [writeq.w_wq_id] [1] <= #TP wrq_rd_msize;
      rd_len_in_beats_info_ary   [writeq.w_wq_id] [0] <= #TP wrq_rd_len_in_beats;
      rd_len_in_beats_info_ary   [writeq.w_wq_id] [1] <= #TP wrq_rd_len_in_beats;
      rd_wrq_atop_ary            [writeq.w_wq_id] [0] <= #TP 1'b1;
      rd_wrq_atop_ary            [writeq.w_wq_id] [1] <= #TP 1'b1;
    end
  end
end

always@(posedge aclk or negedge aresetn)begin: R_FIRST_BEAT_ARY_SEQ_PROC
  integer i;

  if(~aresetn) begin
    for (i=0;i<CC_MAX_MSTR_TAGS;i=i+1) begin
      rd_first_beat_ary [i]  <= #TP 1;
    end
  end else begin
    if (mread && saccept && req_first) begin
      rd_first_beat_ary [arid]  <= #TP 1;
    end
    if (writeq.w_wq_write && writeq.w_wq_fmt_type inside {FETCHADD32,FETCHADD64,SWAP32,SWAP64,CAS32,CAS64}) begin
      rd_first_beat_ary [writeq.w_wq_id]  <= #TP 1;
    end
    if(s_svalid && mready)begin
      rd_first_beat_ary [s_sid]  <= #TP 0;
    end
  end
end




// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign wrq_total_mlen = writeq.w_wq_len + {writeq.w_wq_addr[AXI_STRB_PW-1:2],2'b00};
// spyglass enable_block W164a

  assign wrq_sub_bus_size_aligned = (writeq.w_wq_len < AXI_STRB_WIDTH) && wrq_mlen_align_n_pow2;

  assign wrq_addr_offset ={{(MAX_AXI_STRB_PW - AXI_STRB_PW){1'b0}}, writeq.w_wq_addr[AXI_STRB_PW-1:0]};

  assign wrq_atop_size = log2(writeq.w_wq_len);
  assign wrq_rd_msize = (writeq.w_wq_fmt_type inside {
                        FETCHADD32
                       ,FETCHADD64
                       ,SWAP32
                       ,SWAP64
                       ,CAS32
                       ,CAS64
                       } && wrq_sub_bus_size_aligned) ? wrq_atop_size :
                       (sub_bus_size_we && wrq_sub_bus_size_aligned) ? wrq_sub_bus_size : GM_AXI_SIZE;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign wrq_rd_len_in_beats = (BURST_LEN_PW)'(((wrq_total_mlen >> GM_AXI_SIZE) + (|wrq_total_mlen[GM_AXI_SIZE -1 :0])) - (|wrq_total_mlen));
// spyglass enable_block W164a
//
  assign wrq_req_remain_bytes = (wrq_total_mlen < AXI_STRB_WIDTH)  ? writeq.w_wq_len[AXI_BUS_BYTECNT_PW -1 :0]
                       : (wrq_total_mlen == AXI_STRB_WIDTH) ? {1'b1, {(AXI_BUS_BYTECNT_PW -1){1'b0}}}
                       : {1'b0, wrq_total_mlen[AXI_BUS_BYTECNT_PW -1 -1 :0]};

always@(writeq.w_wq_len or wrq_addr_offset or writeq.w_wq_fmt_type)
  begin
    case (writeq.w_wq_len)
      1:
        begin
          wrq_mlen_align_n_pow2 = 1'b1;
          wrq_sub_bus_size      = 3'b000;
        end
      2:
        begin
          wrq_mlen_align_n_pow2 = (wrq_addr_offset[0]==1'b0) ? 1'b1 : 1'b0;
          wrq_sub_bus_size      = 3'b001;
        end
      4:
        begin
          wrq_mlen_align_n_pow2 = (wrq_addr_offset[1:0]==2'b00) ? 1'b1 : 1'b0;
          wrq_sub_bus_size      = 3'b010;
        end
      8:
        begin
          wrq_mlen_align_n_pow2 = (wrq_addr_offset[2:0]==3'b000) || (writeq.w_wq_fmt_type inside {CAS32,CAS64} && wrq_addr_offset[1:0]==2'b00) ? 1'b1 : 1'b0;
          wrq_sub_bus_size      = 3'b011;
        end
      16:
         begin
          wrq_mlen_align_n_pow2 = (wrq_addr_offset[3:0]==4'b0000) || (writeq.w_wq_fmt_type inside {CAS32,CAS64} && wrq_addr_offset[2:0]==3'b000) ? 1'b1 : 1'b0;
          wrq_sub_bus_size      = 3'b100;
        end
      32:
         begin
          wrq_mlen_align_n_pow2 = (wrq_addr_offset[4:0]==5'b00000) || (writeq.w_wq_fmt_type inside {CAS32,CAS64} && wrq_addr_offset[3:0]==4'b0000) ? 1'b1 : 1'b0;
          wrq_sub_bus_size      = 3'b101;
        end
      default:
        begin
          wrq_mlen_align_n_pow2 = 1'b0;
          wrq_sub_bus_size      = 3'b000;
        end
    endcase
  end // always@ (resp_size or resp_low_addr)

assign pkt_idx_get = resp_first_stretch ? 1'b0 : 1'b1;
assign resp_remain_bytes_modi     = rd_remain_bytecnt_info_ary [rid ][pkt_idx_get];
assign resp_low_addr_modi         = rd_low_addr_info_ary [rid ][pkt_idx_get];
assign resp_size_modi             = rd_size_info_ary [rid ][pkt_idx_get];
assign resp_rd_len_in_beats_modi  = !(resp_first_stretch ||  resp_last_stretch) ?  (`CC_MSTR_MTU/(`MASTER_BUS_DATA_WIDTH/8))-1 : rd_len_in_beats_info_ary [rid ][pkt_idx_get];


assign resp_remain_bytes     = resp_remain_bytes_modi;
assign resp_low_addr         = resp_low_addr_modi[AXI_STRB_PW -1:0];
assign resp_size             = resp_size_modi;
assign resp_rd_len_in_beats  = resp_rd_len_in_beats_modi;
assign resp_wrq_atop         = rd_wrq_atop_ary [rid][pkt_idx_get];
//--------------------------------------------------------------------------
// Functions
//--------------------------------------------------------------------------
//--------------------------------------------------------------------------
// Determines if a 1DW Request has Non-Contiguous Byte Enables
function automatic ncbe_1dw;
  input   [7:0] req_pkt_byte_en;
  begin
    case(req_pkt_byte_en)
      // Allowed combinations of non-contiguous byte enables
      8'b0000_0101,
      8'b0000_1001,
      8'b0000_1010,
      8'b0000_1011,
      8'b0000_1101: ncbe_1dw = 1'b1; // Non-Contiguous
      default     : ncbe_1dw = 1'b0; // Contiguous
    endcase
  end
endfunction // ncbe_1dw

//--------------------------------------------------------------------------
// Determines if a 2DW Request has Non-Contiguous Byte Enables
function automatic ncbe_2dw;
  input   [7:0] req_pkt_byte_en;
  reg           cbe;
  begin
    case(req_pkt_byte_en)
      // Allowed combinations of contiguous byte enables
      8'b1111_1111,
      8'b1111_1110,
      8'b1111_1100,
      8'b1111_1000,
      8'b0111_1111,
      8'b0111_1110,
      8'b0111_1100,
      8'b0111_1000,
      8'b0011_1111,
      8'b0011_1110,
      8'b0011_1100,
      8'b0011_1000,
      8'b0001_1111,
      8'b0001_1110,
      8'b0001_1100,
      8'b0001_1000: cbe = 1'b1; // Contiguous
      default     : cbe = 1'b0; // Non-Contiguous
    endcase
     // Last DW Byte Enable not allowed to be 4'b0000
     // Therefore, only valid 2DW byte enable
     // combination if this value is not equal to 4'b0000
     ncbe_2dw = (req_pkt_byte_en[7:4]==4'b0000) ? 1'b0 : ~cbe;
  end
endfunction // ncbe_2dw
//--------------------------------------------------------------------------

// Aligns output AWID/WID to the AW internal bus
// Only actually needed for WID (AXI3) but makes debugging easier
logic [K_N_IBR_PRESP_STREAMS_W_RO_WD   -1:0] mstream_relaxedOuter_latched;
logic [K_N_IBR_PRESP_STREAMS_W_RO_WD+1 -1:0] w_idbl_i, w_idbl_o, w_idbl_mask;

assign w_idbl_mask = {1'b1   , {K_N_IBR_PRESP_STREAMS_W_RO_WD{1'b0}}};
assign w_idbl_i    = {awvalid, mstream_relaxedOuter                 };

DWC_pcie_bus_latch
 #(
  .P_BUS_T    ( logic [K_N_IBR_PRESP_STREAMS_W_RO_WD:0]   )
 ,.P_IDLE_BUS ( {(K_N_IBR_PRESP_STREAMS_W_RO_WD+1){1'b0}} )
) u_idbl (
  .i_clk        ( aclk        )
 ,.i_rst_n      ( aresetn     )
 ,.i_mask       ( w_idbl_mask )
 ,.i_mask_level ( w_idbl_mask )
 ,.i_bus        ( w_idbl_i    )
 ,.o_bus        ( w_idbl_o    )
);

assign mstream_relaxedOuter_latched = w_idbl_o[K_N_IBR_PRESP_STREAMS_W_RO_WD-1:0];

assign o_awid = (aw_is_nposted) ? {1'b1,awid} : {1'b0, (AXI_ID_WIDTH_EXT-1)'(mstream_relaxedOuter_latched)};
assign o_wid  = (aw_is_nposted) ? {1'b1, wid} : {1'b0, (AXI_ID_WIDTH_EXT-1)'(mstream_relaxedOuter_latched)};
assign o_awid_extra = aw_is_nposted ? '0 : mstream_relaxedOuter_latched[(K_N_IBR_PRESP_STREAMS_W_RO_WD-1) -:`CX_IB_P_ID_MNG_EXTRA_ID_WD];
assign o_wid_extra  = aw_is_nposted ? '0 : mstream_relaxedOuter_latched[(K_N_IBR_PRESP_STREAMS_W_RO_WD-1) -:`CX_IB_P_ID_MNG_EXTRA_ID_WD];
assign o_arid = {1'b0,arid};


assign wstream = mstream_strictInner;

// -------------------------------------------------------------------------------------
// Functions
// -------------------------------------------------------------------------------------


endmodule
