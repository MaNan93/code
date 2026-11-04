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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_slv_r_if.svh#2 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_SLV_R_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_SLV_R_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_slv_r_if #(

  parameter CC_SLV_BUS_ID_WIDTH    = `CC_SLV_BUS_ID_WIDTH,
  parameter FLT_Q_PRFX_WIDTH       = `FLT_Q_PRFX_WIDTH,
  parameter CC_SLV_BUS_DATA_WIDTH  = `CC_SLV_BUS_DATA_WIDTH

);

  logic                              valid;
  logic [CC_SLV_BUS_ID_WIDTH-1:0]    id;
  logic                              timeout;
  logic                              ep;
  logic [2:0]                        tc;
  logic                              ns;
  logic                              ro;
  logic [2:0]                        status;
  logic                              cpl;
  logic                              ido;
  logic [8:0]                        dst_segment;
  logic [7:0]                        cpl_segment;
  logic [1:0]                        resp;
  logic [CC_SLV_BUS_DATA_WIDTH-1:0]  data;
  logic                              last;
  logic                              ready;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    input  valid
   ,input  id
   ,input  timeout
   ,input  ep
   ,input  tc
   ,input  ns
   ,input  ro
   ,input  status
   ,input  cpl
   ,input  ido
   ,input  dst_segment
   ,input  cpl_segment
   ,input  resp
   ,input  data
   ,input  last
   ,output ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    output valid
   ,output id
   ,output timeout
   ,output ep
   ,output tc
   ,output ns
   ,output ro
   ,output status
   ,output cpl
   ,output ido
   ,output dst_segment
   ,output cpl_segment
   ,output resp
   ,output data
   ,output last
   ,input  ready
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );

endinterface

`endif // __GUARD__DWC_PCIE_AXI_SLV_R_IF__SVH__

