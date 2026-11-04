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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/svif/ramWr_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__RAMWR_IF__SVH__
`define __GUARD__RAMWR_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface ramWr_if #(
   parameter P_RAM_AW = 6
  ,parameter  P_RAM_W = 64
  );

  logic [P_RAM_AW-1:0] w_waddr ;
  logic  [P_RAM_W-1:0] w_wdata ;
  logic                w_wen_n ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_waddr
   ,output w_wdata
   ,output w_wen_n
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_waddr
   ,input  w_wdata
   ,input  w_wen_n
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface : ramWr_if

`endif // __GUARD__RAMWR_IF__SVH__

