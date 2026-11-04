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
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh#5 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_RAM1P_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_RAM1P_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_ram1p_if #(
   parameter DP = 4096
  ,parameter PW = 12
  ,parameter WD = 12
  );

  logic [PW-1:0] w_addr        ;
  logic [WD-1:0] w_din         ;
  logic [WD-1:0] w_dout        ;
  logic          w_lock        ;
  logic          w_rden        ;
  logic          w_rdone       ;
  logic          w_wdone       ;
  logic          w_wren        ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_addr
   ,output w_din
   ,input  w_dout
   ,output w_lock
   ,output w_rden
   ,input  w_rdone
   ,input  w_wdone
   ,output w_wren
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_addr
   ,input  w_din
   ,output w_dout
   ,input  w_lock
   ,input  w_rden
   ,output w_rdone
   ,output w_wdone
   ,input  w_wren
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_RAM1P_IF__SVH__

