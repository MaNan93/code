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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_slv_aw_if.svh#4 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_SLV_AW_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_SLV_AW_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_slv_aw_if #(

  parameter CC_SLV_BUS_ADDR_WIDTH   = `CC_SLV_BUS_ADDR_WIDTH,
  parameter CC_SLV_BUS_ID_WIDTH     = `CC_SLV_BUS_ID_WIDTH,
  parameter CC_SLV_INT_BURST_LEN_PW = `CC_SLV_INT_BURST_LEN_PW,
  parameter CC_AXI_LOCK_WIDTH       = `CC_AXI_LOCK_WIDTH,
  parameter CX_NFUNC_WD             = `CX_NFUNC_WD,
  parameter CX_NVFUNC_WD            = `CX_NVFUNC_WD,
  parameter TX_TLP_PREFIX_WD        = 32*(`CX_NPRFX)+`CX_PRFX_PAR_WD,
  parameter RID_WD                  = 16,
  parameter CX_TAG_SIZE             = `CX_TAG_SIZE,
  parameter MISC_INFO_TPH_WD        = 11

);

  logic                               valid;
  logic [CC_SLV_BUS_ADDR_WIDTH-1:0]   addr;
  logic [CC_SLV_BUS_ID_WIDTH-1:0]     id;
  logic [CC_SLV_INT_BURST_LEN_PW-1:0] len;
  logic [2:0]                         size;
  logic [1:0]                         burst;
  logic [5:0]                         atop;
  logic [4:0]                         misc_info_type;
  logic                               misc_info_snp;
  logic                               misc_info_ep;
  logic                               misc_info_ns;
  logic                               misc_info_ro;
  logic [2:0]                         misc_info_tc;
  logic [7:0]                         misc_info_msg_code;
  logic                               misc_info_db;
  logic [CX_NFUNC_WD-1:0]             misc_info_func_num;
  logic                               misc_info_nw;
  logic [1:0]                         misc_info_ats;
  logic [TX_TLP_PREFIX_WD-1:0]        misc_info_tlpprfx;
  logic [CX_TAG_SIZE-1:0]             misc_info_p_tag;
  logic [MISC_INFO_TPH_WD-1:0]        misc_info_tph;
  logic                               misc_info_atu_bypass;
  logic                               misc_info_ido;
  logic [8:0]                         misc_info_dst_segment;
  logic                               ready;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    output valid
   ,output addr
   ,output id
   ,output len
   ,output size
   ,output burst
   ,output atop
   ,output misc_info_type
   ,output misc_info_snp
   ,output misc_info_ep
   ,output misc_info_ns
   ,output misc_info_ro
   ,output misc_info_tc
   ,output misc_info_msg_code
   ,output misc_info_db
   ,output misc_info_func_num
   ,output misc_info_nw
   ,output misc_info_ats
   ,output misc_info_tlpprfx
   ,output misc_info_p_tag
   ,output misc_info_tph
   ,output misc_info_atu_bypass
   ,output misc_info_ido
   ,output misc_info_dst_segment
   ,input  ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    input  valid
   ,input  addr
   ,input  id
   ,input  len
   ,input  size
   ,input  burst
   ,input  atop
   ,input  misc_info_type
   ,input  misc_info_snp
   ,input  misc_info_ep
   ,input  misc_info_ns
   ,input  misc_info_ro
   ,input  misc_info_tc
   ,input  misc_info_msg_code
   ,input  misc_info_db
   ,input  misc_info_func_num
   ,input  misc_info_nw
   ,input  misc_info_ats
   ,input  misc_info_tlpprfx
   ,input  misc_info_p_tag
   ,input  misc_info_tph
   ,input  misc_info_atu_bypass
   ,input  misc_info_ido
   ,input  misc_info_dst_segment
   ,output ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
endinterface

`endif // __GUARD__DWC_PCIE_AXI_SLV_AW_IF__SVH__

