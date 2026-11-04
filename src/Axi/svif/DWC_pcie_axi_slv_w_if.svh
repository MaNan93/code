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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_slv_w_if.svh#1 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_SLV_W_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_SLV_W_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_slv_w_if #(

  parameter CC_SLV_BUS_ID_WIDTH    = `CC_SLV_BUS_ID_WIDTH,
  parameter CC_SLV_BUS_DATA_WIDTH  = `CC_SLV_BUS_DATA_WIDTH,
  parameter CC_SLV_BUS_WSTRB_WIDTH = `CC_SLV_BUS_WSTRB_WIDTH

);

  logic                              valid;
  logic [CC_SLV_BUS_DATA_WIDTH-1:0]  data;
  logic [CC_SLV_BUS_WSTRB_WIDTH-1:0] strb;
  logic                              last;
  logic                              misc_info_ep;
  logic                              misc_info_silentDrop;
  logic                              ready;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    output valid
   ,output data
   ,output strb
   ,output last
   ,output misc_info_ep
   ,output misc_info_silentDrop
   ,input  ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    input  valid
   ,input  data
   ,input  strb
   ,input  last
   ,input  misc_info_ep
   ,input  misc_info_silentDrop
   ,output ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );

endinterface

`endif // __GUARD__DWC_PCIE_AXI_SLV_W_IF__SVH__

