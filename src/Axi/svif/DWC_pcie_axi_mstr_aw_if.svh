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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_mstr_aw_if.svh#4 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_MSTR_AW_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_MSTR_AW_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_mstr_aw_if #(

  parameter CC_MSTR_BUS_ADDR_WIDTH    = `CC_MSTR_BUS_ADDR_WIDTH,
  parameter CC_MSTR_BUS_ID_WIDTH      = `CC_MSTR_BUS_ID_WIDTH,
  parameter CC_MSTR_BURST_LEN_PW      = `CC_MSTR_BURST_LEN_PW,
  parameter CC_AXI_LOCK_WIDTH         = `CC_AXI_LOCK_WIDTH,
  parameter CX_TAG_SIZE               = `CX_TAG_SIZE,
  parameter CX_NFUNC_WD               = `CX_NFUNC_WD,
  parameter CX_NVFUNC_WD              = `CX_NVFUNC_WD,
  parameter CC_NUM_DMA_RD_CHAN_WIDTH  = `CC_NUM_DMA_RD_CHAN_WIDTH,
  parameter DC_DMA_TYPE_WIDTH         = `DC_DMA_TYPE_WIDTH,
  parameter RX_TLP_PREFIX_WD          = `FLT_Q_PRFX_WIDTH,
  parameter MISC_INFO_TPH_WD          = 11

);

  logic                                                   valid;
  logic [CC_MSTR_BUS_ID_WIDTH-1:0]                        id;
  logic [CC_MSTR_BUS_ADDR_WIDTH-1:0]                      addr;
  logic [CC_MSTR_BURST_LEN_PW -1:0]                       len;
  logic [2:0]                                             size;
  logic [1:0]                                             burst;
  logic [CC_AXI_LOCK_WIDTH-1:0]                           lock;
  logic [3:0]                                             cache;
  logic [2:0]                                             prot;
  logic [CX_TAG_SIZE+39:0]                                misc_info;
  logic [63:0]                                            misc_info_hdr_34dw;
  logic                                                   misc_info_last_dcmp_tlp;
  logic                                                   misc_info_nw;
  logic                                                   misc_info_cxlsrc;
  logic [1:0]                                             misc_info_ats;
  logic                                                   misc_info_ep;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH+DC_DMA_TYPE_WIDTH-1:0]  misc_info_dma;
  logic [RX_TLP_PREFIX_WD-1:0]                            misc_info_tlpprfx;
  logic [MISC_INFO_TPH_WD-1:0]                            misc_info_tph;
  logic                                                   misc_info_ido;
  logic [8:0]                                             misc_info_dst_segment;
  logic [8:0]                                             misc_info_req_segment;
  logic [3:0]                                             qos;
  logic [1:0]                                             domain;
  logic [1:0]                                             bar;
  logic [`CC_AXIJ_DMWR_VALUE *2+2:0]                      snoop;
  logic [5:0]                                             atop;
  logic                                                   ready;
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    output valid
   ,output id
   ,output addr
   ,output len
   ,output size
   ,output burst
   ,output lock
   ,output cache
   ,output prot
   ,output misc_info
   ,output misc_info_hdr_34dw
   ,output misc_info_last_dcmp_tlp
   ,output misc_info_nw
   ,output misc_info_cxlsrc
   ,output misc_info_ats
   ,output misc_info_ep
   ,output misc_info_dma
   ,output misc_info_tlpprfx
   ,output misc_info_tph
   ,output misc_info_ido
   ,output misc_info_dst_segment
   ,output misc_info_req_segment
   ,output qos
   ,output domain
   ,output bar
   ,output snoop
   ,output atop
   ,input  ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    input  valid
   ,input  id
   ,input  addr
   ,input  len
   ,input  size
   ,input  burst
   ,input  lock
   ,input  cache
   ,input  prot
   ,input  misc_info
   ,input  misc_info_hdr_34dw
   ,input  misc_info_last_dcmp_tlp
   ,input  misc_info_nw
   ,input  misc_info_cxlsrc
   ,input  misc_info_ats
   ,input  misc_info_ep
   ,input  misc_info_dma
   ,input  misc_info_tlpprfx
   ,input  misc_info_tph
   ,input  misc_info_ido
   ,input  misc_info_dst_segment
   ,input  misc_info_req_segment
   ,input  qos
   ,input  domain
   ,input  bar
   ,input  snoop
   ,input  atop
   ,output ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
    
endinterface

`endif // __GUARD__DWC_PCIE_AXI_MSTR_AW_IF__SVH__

