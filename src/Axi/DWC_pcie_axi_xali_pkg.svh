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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_xali_pkg.svh#4 $
// -------------------------------------------------------------------------
// --- Description: AXI Slave Interface Package
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_AXI_XALI_PKG__SVH__
`define __GUARD__DWC_PCIE_AXI_XALI_PKG__SVH__

`include "include/DWC_pcie_ctl_all_defs.svh"

package DWC_pcie_axi_xali_pkg;

  localparam K_PF_WD                     = `CX_NFUNC_WD;
  localparam K_VF_WD                     = `CX_NVFUNC_WD;
  localparam K_FLT_Q_ATTR_WIDTH          = `FLT_Q_ATTR_WIDTH;
  localparam K_CX_TAG_SIZE               = `CX_TAG_SIZE;
  localparam K_CX_REMOTE_LOOKUPID_WD     = `CX_REMOTE_LOOKUPID_WD;
  localparam K_CORE_DATA_BUS_WD          = `CC_CORE_DATA_BUS_WD;
  localparam K_PCIE_CORE_DATA_BUS_WD     = `PCIE_CORE_DATA_BUS_WD;
  localparam K_DC_CPL_BYTE_EN_WD         = `DC_CPL_BYTE_EN_WD;
  localparam K_NW_PRFX                   = `CX_NPRFX;
  localparam K_PRFX_PAR_WD               = `CX_PRFX_PAR_WD;
  localparam K_TX_TLP_PREFIX_WD          = (32*K_NW_PRFX)+ K_PRFX_PAR_WD;
  localparam K_DC_DMA_TYPE_WIDTH         = `DC_DMA_TYPE_WIDTH;
  localparam K_CC_NUM_DMA_RD_CHAN        = `CC_NUM_DMA_RD_CHAN;
  localparam K_CC_NUM_DMA_WR_CHAN        = `CC_NUM_DMA_WR_CHAN;
  localparam K_CC_NUM_DMA_RD_CHAN_WIDTH  = `CC_NUM_DMA_RD_CHAN_WIDTH;
  localparam K_CC_NUM_DMA_WR_CHAN_WIDTH  = `CC_NUM_DMA_WR_CHAN_WIDTH;
  localparam K_CC_NUM_DMA_MAX_CHAN_WIDTH = `CC_NUM_DMA_MAX_CHAN_WIDTH;
  localparam K_CLIENT_HDR_PROT_WD        = `CLIENT_HDR_PROT_WD;
  localparam NVC_XALI_EXP                = `CX_AXI_NVC_XALI_EXPANSION;
  localparam K_ADDR_PAR_WD               = `CX_ADDR_PAR_WD;
  localparam K_CID_WD                    = `CX_CID_WD;
  localparam K_RID_WD                    = `CX_RID_WD;


  typedef struct packed {
    logic                                   tlp_hv;
    logic                                   tlp_dv;
    logic                                   tlp_eot;
    logic [1:0]                             tlp_fmt;
    logic [4:0]                             tlp_type;
    logic                                   tlp_td;
    logic                                   tlp_ep;
    logic [K_FLT_Q_ATTR_WIDTH-1:0]          tlp_attr;
    logic                                   tlp_bad_eot;
    logic                                   addr_align_en;
    logic [K_PF_WD-1:0]                     tlp_func_num;
    logic [15:0]                            cpl_cmpltr_id;
    logic [2:0]                             cpl_status;
    logic                                   cpl_bcm;
    logic [11:0]                            cpl_byte_cnt;
    logic                                   cpl_last;
    logic [1:0]                             tlp_ats;
    logic                                   tlp_nw;
    logic [K_CX_TAG_SIZE-1:0]               tlp_tid;
    logic [12:0]                            tlp_byte_len;
    logic [63+K_ADDR_PAR_WD:0]              tlp_addr;
    logic [K_DC_CPL_BYTE_EN_WD-1:0]         tlp_byte_en;
    logic [2:0]                             tlp_tc;
    logic [K_CORE_DATA_BUS_WD -1:0]         tlp_data;
    logic [K_CX_REMOTE_LOOKUPID_WD-1:0]     cpl_lookup_id;
    logic                                   tlp_atu_bypass;
    logic [K_DC_DMA_TYPE_WIDTH-1:0]         tlp_dma;
    logic [K_CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] tlp_dma_channel;
    logic                                   tlp_prv_dma;
    logic [K_CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] tlp_prv_dma_chan;
    logic                                   tlp_th;
    logic [1:0]                             tlp_ph;
    logic [7:0]                             tlp_st;
    logic [8:0]                             tlp_dst_segment;
    logic [2:0]                             tlp_order_seqnum;
  } axi_xali_client0_s;


  typedef struct packed {
    logic                                   tlp_hv;
    logic                                   tlp_dv;
    logic                                   tlp_eot;
    logic [1:0]                             tlp_fmt;
    logic [4:0]                             tlp_type;
    logic                                   tlp_td;
    logic                                   tlp_ep;
    logic [K_FLT_Q_ATTR_WIDTH-1:0]          tlp_attr;
    logic                                   tlp_bad_eot;
    logic                                   addr_align_en;
    logic [K_PF_WD-1:0]                     tlp_func_num;
    logic [15:0]                            cpl_cmpltr_id;
    logic [2:0]                             cpl_status;
    logic                                   cpl_bcm;
    logic [11:0]                            cpl_byte_cnt;
    logic [1:0]                             tlp_ats;
    logic                                   tlp_nw;
    logic [K_CX_TAG_SIZE-1:0]               tlp_tid;
    logic [12:0]                            tlp_byte_len;
    logic [63+K_ADDR_PAR_WD:0]              tlp_addr;
    logic [7:0]                             tlp_byte_en;
    logic [2:0]                             tlp_tc;
    logic [K_CORE_DATA_BUS_WD -1:0]         tlp_data;
    logic [K_CX_REMOTE_LOOKUPID_WD-1:0]     cpl_lookup_id;
    logic [K_TX_TLP_PREFIX_WD-1:0]          tlp_prfx;
    logic                                   tlp_atu_bypass;
    logic [K_DC_DMA_TYPE_WIDTH-1:0]         tlp_dma;
    logic [K_CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] tlp_dma_channel;
    logic                                   tlp_th;
    logic [1:0]                             tlp_ph;
    logic [7:0]                             tlp_st;
    logic [8:0]                             tlp_dst_segment;
    logic [2:0]                             tlp_order_seqnum;
  } axi_xali_client1_s;


  typedef struct packed {
    logic                                   tlp_hv;
    logic                                   tlp_dv;
    logic                                   tlp_eot;
    logic [1:0]                             tlp_fmt;
    logic [4:0]                             tlp_type;
    logic [2:0]                             tlp_tc;
    logic                                   tlp_td;
    logic                                   tlp_ep;
    logic [K_FLT_Q_ATTR_WIDTH-1:0]          tlp_attr;
    logic                                   tlp_bad_eot;
    logic                                   addr_align_en;
    logic [K_PF_WD-1:0]                     tlp_func_num;
    logic [15:0]                            remote_req_id;
    logic [2:0]                             cpl_status;
    logic                                   cpl_bcm;
    logic [11:0]                            cpl_byte_cnt;
    logic [1:0]                             tlp_ats;
    logic                                   tlp_nw;
    logic [K_CX_TAG_SIZE-1:0]               tlp_tid;
    logic [12:0]                            tlp_byte_len;
    logic [63+K_ADDR_PAR_WD:0]              tlp_addr;
    logic [7:0]                             tlp_byte_en;
    logic [K_CORE_DATA_BUS_WD-1:0]          tlp_data;
    logic [K_CX_REMOTE_LOOKUPID_WD-1:0]     cpl_lookup_id;
    logic [K_TX_TLP_PREFIX_WD-1:0]          tlp_prfx;
    logic                                   tlp_atu_bypass;
    logic [K_DC_DMA_TYPE_WIDTH-1:0]         tlp_dma;
    logic [K_CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] tlp_dma_channel;
    logic                                   tlp_th;
    logic [1:0]                             tlp_ph;
    logic [7:0]                             tlp_st;
    logic [8:0]                             tlp_dst_segment;
    logic [2:0]                             tlp_order_seqnum;
  } axi_xali_client2_s;


  typedef struct packed {
    logic [NVC_XALI_EXP-1:0]                               tlp_hv;
    logic [NVC_XALI_EXP-1:0]                               tlp_dv;
    logic [NVC_XALI_EXP-1:0]                               tlp_eot;
    logic [NVC_XALI_EXP-1:0]                               tlp_bad_eot;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_fmt;
    logic [(NVC_XALI_EXP*5)-1:0]                           tlp_type;
    logic [NVC_XALI_EXP-1:0]                               tlp_td;
    logic [NVC_XALI_EXP-1:0]                               tlp_ep;
    logic [(NVC_XALI_EXP*K_FLT_Q_ATTR_WIDTH)-1:0]          tlp_attr;
    logic [NVC_XALI_EXP-1:0]                               addr_align_en;
    logic [(NVC_XALI_EXP*K_PF_WD)-1:0]                     tlp_func_num;
    logic [(NVC_XALI_EXP*16)-1:0]                          cpl_cmpltr_id;
    logic [(NVC_XALI_EXP*3)-1:0]                           cpl_status;
    logic [NVC_XALI_EXP-1:0]                               cpl_bcm;
    logic [(NVC_XALI_EXP*12)-1:0]                          cpl_byte_cnt;
    logic [NVC_XALI_EXP-1:0]                               cpl_last;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_ats;
    logic [NVC_XALI_EXP-1:0]                               tlp_nw;
    logic [(NVC_XALI_EXP*K_CX_TAG_SIZE)-1:0]               tlp_tid;
    logic [(NVC_XALI_EXP*13)-1:0]                          tlp_byte_len;
    logic [(NVC_XALI_EXP*64)-1:0]                          tlp_addr;
    logic [(NVC_XALI_EXP*K_ADDR_PAR_WD)-1:0]               tlp_addr_par;
    logic [(NVC_XALI_EXP*K_DC_CPL_BYTE_EN_WD)-1:0]         tlp_byte_en;
    logic [(NVC_XALI_EXP*3)-1:0]                           tlp_tc;
    logic [(NVC_XALI_EXP*K_CORE_DATA_BUS_WD)-1:0]          tlp_data;
    logic [(NVC_XALI_EXP*K_CX_REMOTE_LOOKUPID_WD)-1:0]     cpl_lookup_id;
    logic [NVC_XALI_EXP-1:0]                               tlp_atu_bypass;
    logic [(NVC_XALI_EXP*K_DC_DMA_TYPE_WIDTH)-1:0]         tlp_dma;
    logic [(NVC_XALI_EXP*K_CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] tlp_dma_channel;
    logic [NVC_XALI_EXP-1:0]                               tlp_prv_dma;
    logic [(NVC_XALI_EXP*K_CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] tlp_prv_dma_chan;
    logic [NVC_XALI_EXP-1:0]                               tlp_th;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_ph;
    logic [(NVC_XALI_EXP*8)-1:0]                           tlp_st;
    logic [(NVC_XALI_EXP*9)-1:0]                           tlp_dst_segment;
    logic [(NVC_XALI_EXP*3)-1:0]                           tlp_order_seqnum;
  } axi_xali_exp_client0_s;


  typedef struct packed {
    logic [NVC_XALI_EXP-1:0]                               tlp_hv;
    logic [NVC_XALI_EXP-1:0]                               tlp_dv;
    logic [NVC_XALI_EXP-1:0]                               tlp_eot;
    logic [NVC_XALI_EXP-1:0]                               tlp_bad_eot;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_fmt;
    logic [(NVC_XALI_EXP*5)-1:0]                           tlp_type;
    logic [NVC_XALI_EXP-1:0]                               tlp_td;
    logic [NVC_XALI_EXP-1:0]                               tlp_ep;
    logic [(NVC_XALI_EXP*K_FLT_Q_ATTR_WIDTH)-1:0]          tlp_attr;
    logic [NVC_XALI_EXP-1:0]                               addr_align_en;
    logic [(NVC_XALI_EXP*K_PF_WD)-1:0]                     tlp_func_num;
    logic [(NVC_XALI_EXP*16)-1:0]                          cpl_cmpltr_id;
    logic [(NVC_XALI_EXP*3)-1:0]                           cpl_status;
    logic [NVC_XALI_EXP-1:0]                               cpl_bcm;
    logic [(NVC_XALI_EXP*12)-1:0]                          cpl_byte_cnt;
    logic [NVC_XALI_EXP-1:0]                               tlp_nw;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_ats;
    logic [(NVC_XALI_EXP*K_CX_TAG_SIZE)-1:0]               tlp_tid;
    logic [(NVC_XALI_EXP*13)-1:0]                          tlp_byte_len;
    logic [(NVC_XALI_EXP*64)-1:0]                          tlp_addr;
    logic [(NVC_XALI_EXP*K_ADDR_PAR_WD)-1:0]               tlp_addr_par;
    logic [(NVC_XALI_EXP*8)-1:0]                           tlp_byte_en;
    logic [(NVC_XALI_EXP*3)-1:0]                           tlp_tc;
    logic [(NVC_XALI_EXP*K_CORE_DATA_BUS_WD)-1:0]          tlp_data;
    logic [(NVC_XALI_EXP*K_CX_REMOTE_LOOKUPID_WD)-1:0]     cpl_lookup_id;
    logic [(NVC_XALI_EXP*K_TX_TLP_PREFIX_WD)-1:0]          tlp_prfx;
    logic [(NVC_XALI_EXP*K_DC_DMA_TYPE_WIDTH)-1:0]         tlp_dma;
    logic [(NVC_XALI_EXP*K_CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] tlp_dma_channel;
    logic [NVC_XALI_EXP-1:0]                               tlp_th;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_ph;
    logic [(NVC_XALI_EXP*8)-1:0]                           tlp_st;
    logic [NVC_XALI_EXP-1:0]                               tlp_atu_bypass;
    logic [(NVC_XALI_EXP*9)-1:0]                           tlp_dst_segment;
    logic [(NVC_XALI_EXP*3)-1:0]                           tlp_order_seqnum;
  } axi_xali_exp_client1_s;


  typedef struct packed {
    logic [NVC_XALI_EXP-1:0]                               tlp_hv;
    logic [NVC_XALI_EXP-1:0]                               tlp_dv;
    logic [NVC_XALI_EXP-1:0]                               tlp_eot;
    logic [NVC_XALI_EXP-1:0]                               tlp_bad_eot;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_fmt;
    logic [(NVC_XALI_EXP*5)-1:0]                           tlp_type;
    logic [(NVC_XALI_EXP*3)-1:0]                           tlp_tc;
    logic [NVC_XALI_EXP-1:0]                               tlp_td;
    logic [NVC_XALI_EXP-1:0]                               tlp_ep;
    logic [(NVC_XALI_EXP*K_FLT_Q_ATTR_WIDTH)-1:0]          tlp_attr;
    logic [(NVC_XALI_EXP*K_CX_REMOTE_LOOKUPID_WD-1):0]     cpl_lookup_id;
    logic [NVC_XALI_EXP-1:0]                               addr_align_en;
    logic [(NVC_XALI_EXP*8)-1:0]                           tlp_byte_en;
    logic [(NVC_XALI_EXP*16)-1:0]                          remote_req_id;
    logic [(NVC_XALI_EXP*3)-1:0]                           cpl_status;
    logic [NVC_XALI_EXP-1:0]                               cpl_bcm;
    logic [(NVC_XALI_EXP*12)-1:0]                          cpl_byte_cnt;
    logic [(NVC_XALI_EXP*13)-1:0]                          tlp_byte_len;
    logic [(NVC_XALI_EXP*K_CX_TAG_SIZE)-1:0]               tlp_tid;
    logic [(NVC_XALI_EXP*64)-1:0]                          tlp_addr;
    logic [(NVC_XALI_EXP*K_ADDR_PAR_WD)-1:0]               tlp_addr_par;
    logic [(NVC_XALI_EXP*K_CORE_DATA_BUS_WD)-1:0]          tlp_data;
    logic [(NVC_XALI_EXP*K_PF_WD)-1:0]                     tlp_func_num;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_ats;
    logic [NVC_XALI_EXP-1:0]                               tlp_nw;
    logic [(NVC_XALI_EXP*K_DC_DMA_TYPE_WIDTH)-1:0]         tlp_dma;
    logic [(NVC_XALI_EXP*K_CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] tlp_dma_channel;
    logic [NVC_XALI_EXP-1:0]                               tlp_th;
    logic [(NVC_XALI_EXP*2)-1:0]                           tlp_ph;
    logic [(NVC_XALI_EXP*8)-1:0]                           tlp_st;
    logic [(NVC_XALI_EXP*K_TX_TLP_PREFIX_WD)-1:0]          tlp_prfx;
    logic [NVC_XALI_EXP-1:0]                               tlp_atu_bypass;
    logic [(NVC_XALI_EXP*9)-1:0]                           tlp_dst_segment;
    logic [(NVC_XALI_EXP*3)-1:0]                           tlp_order_seqnum;
  } axi_xali_exp_client2_s;



  typedef struct packed {
    logic [(K_CORE_DATA_BUS_WD - K_PCIE_CORE_DATA_BUS_WD)-1:0]   parity;
    logic [K_PCIE_CORE_DATA_BUS_WD-1:0]                          payload;
  } ras_xali_data_s;


  typedef struct packed {
    logic [NVC_XALI_EXP-1:0][0:0]                          tlp_th;
    logic [NVC_XALI_EXP-1:0][7:0]                          tlp_st;
    logic [NVC_XALI_EXP-1:0][1:0]                          tlp_ph;
    logic [NVC_XALI_EXP-1:0][K_PF_WD-1:0]                  tlp_func_num;
    logic [NVC_XALI_EXP-1:0][K_FLT_Q_ATTR_WIDTH-1:0]       tlp_attr;
    logic [NVC_XALI_EXP-1:0][1:0]                          tlp_ats;
    logic [NVC_XALI_EXP-1:0][0:0]                          tlp_nw;
    logic [NVC_XALI_EXP-1:0][0:0]                          addr_align_en;
    logic [NVC_XALI_EXP-1:0][K_DC_CPL_BYTE_EN_WD-1:0]      tlp_byte_en;
    logic [NVC_XALI_EXP-1:0][15:0]                         cpl_cmpltr_id;
    logic [NVC_XALI_EXP-1:0][2:0]                          cpl_status;
    logic [NVC_XALI_EXP-1:0][0:0]                          cpl_bcm;
    logic [NVC_XALI_EXP-1:0][11:0]                         cpl_byte_cnt;
    logic [NVC_XALI_EXP-1:0][K_CX_TAG_SIZE-1:0]            tlp_tid;
    logic [NVC_XALI_EXP-1:0][12:0]                         tlp_byte_len;
    logic [NVC_XALI_EXP-1:0][0:0]                          tlp_ep;
    logic [NVC_XALI_EXP-1:0][0:0]                          tlp_td;
    logic [NVC_XALI_EXP-1:0][2:0]                          tlp_tc;
    logic [NVC_XALI_EXP-1:0][4:0]                          tlp_type;
    logic [NVC_XALI_EXP-1:0][1:0]                          tlp_fmt;
    logic [NVC_XALI_EXP-1:0][63:0]                         tlp_addr;
  } xali_exp_client_ras_hdr_s;



  typedef struct packed {
    logic [2:0]   tc7_vc_map;
    logic [2:0]   tc6_vc_map;
    logic [2:0]   tc5_vc_map;
    logic [2:0]   tc4_vc_map;
    logic [2:0]   tc3_vc_map;
    logic [2:0]   tc2_vc_map;
    logic [2:0]   tc1_vc_map;
    logic [2:0]   tc0_vc_map;
  } vc_map_s;


  function automatic logic xaliPSent(input logic [6:0] xaliVcTlpSent);
    xaliPSent = (xaliVcTlpSent[4] == 1'b1);
  endfunction


  function automatic logic [2:0] getVcOfTc(input logic [2:0] tc, input vc_map_s vcMap);
      case (tc)
        3'b000:  getVcOfTc = vcMap.tc0_vc_map;
        3'b001:  getVcOfTc = vcMap.tc1_vc_map;
        3'b010:  getVcOfTc = vcMap.tc2_vc_map;
        3'b011:  getVcOfTc = vcMap.tc3_vc_map;
        3'b100:  getVcOfTc = vcMap.tc4_vc_map;
        3'b101:  getVcOfTc = vcMap.tc5_vc_map;
        3'b110:  getVcOfTc = vcMap.tc6_vc_map;
        default: getVcOfTc = vcMap.tc7_vc_map;
      endcase
  endfunction

endpackage

`endif //__GUARD__DWC_PCIE_AXI_XALI_PKG__SVH__

