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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_mstr_w_if.svh#2 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_MSTR_W_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_MSTR_W_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_mstr_w_if #(

  parameter CC_MSTR_BUS_DATA_WIDTH    = `CC_MSTR_BUS_DATA_WIDTH,
  parameter CC_MSTR_BUS_WSTRB_WIDTH   = `CC_MSTR_BUS_WSTRB_WIDTH

);
 
  logic                                                   valid;
  logic                                                   last;
  logic [CC_MSTR_BUS_DATA_WIDTH-1:0]                      data;
  logic [CC_MSTR_BUS_WSTRB_WIDTH-1:0]                     strb;
  logic                                                   ready;
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    output valid
   ,output last
   ,output data
   ,output strb
   ,input  ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    input  valid
   ,input  last
   ,input  data
   ,input  strb
   ,output ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
endinterface

`endif // __GUARD__DWC_PCIE_AXI_MSTR_W_IF__SVH__

