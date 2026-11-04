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
// ---    $DateTime: 2022/04/14 09:36:50 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_mstr_r_if.svh#2 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_MSTR_R_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_MSTR_R_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_mstr_r_if #(

  parameter CC_MSTR_BUS_ID_WIDTH      = `CC_MSTR_BUS_ID_WIDTH,
  parameter CC_MSTR_BUS_DATA_WIDTH    = `CC_MSTR_BUS_DATA_WIDTH,
  parameter MSTR_RESP_MISC_INFO_PW    = `MSTR_RESP_MISC_INFO_PW,
  parameter DC_CPL_STATUS_WD          = `DC_CPL_STATUS_WD

);
 
  logic                                                   valid;
  logic [CC_MSTR_BUS_ID_WIDTH-1:0]                        id;
  logic                                                   last;
  logic [CC_MSTR_BUS_DATA_WIDTH-1:0]                      data;
  logic [MSTR_RESP_MISC_INFO_PW-1:0]                      misc_info;
  logic [1:0]                                             resp;
  logic [DC_CPL_STATUS_WD-1:0]                            misc_info_cpl_stat;
  logic                                                   ready;
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    input  valid
   ,input  id
   ,input  last
   ,input  data
   ,input  misc_info
   ,input  resp
   ,input  misc_info_cpl_stat
   ,output ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    output valid
   ,output id
   ,output last
   ,output data
   ,output misc_info
   ,output resp
   ,output misc_info_cpl_stat
   ,input  ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
endinterface

`endif // __GUARD__DWC_PCIE_AXI_MSTR_R_IF__SVH__

