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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/svif/ramRd_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__RAMRD_IF__SVH__
`define __GUARD__RAMRD_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface ramRd_if #(
   parameter P_RAM_AW = 6
  ,parameter  P_RAM_W = 64
  );

  logic [P_RAM_AW-1:0] w_raddr ;
  logic  [P_RAM_W-1:0] w_rdata ;
  logic                w_ren_n ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_raddr
   ,output w_rdata
   ,input  w_ren_n
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_raddr
   ,input  w_rdata
   ,output w_ren_n
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface : ramRd_if

`endif // __GUARD__RAMRD_IF__SVH__

