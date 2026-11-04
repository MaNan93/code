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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DW_SBC_CDC_CLK_IF__SVH__
`define __GUARD__DW_SBC_CDC_CLK_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DW_sbc_cdc_clk_if
  import DW_sbc_cdc_pkg::*;
  ();

  logic  w_pop_clk    ;
  logic  w_pop_rst_n  ;
  logic  w_push_clk   ;
  logic  w_push_rst_n ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_pop_clk
   ,output w_pop_rst_n
   ,output w_push_clk
   ,output w_push_rst_n
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_pop_clk
   ,input  w_pop_rst_n
   ,input  w_push_clk
   ,input  w_push_rst_n
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface : DW_sbc_cdc_clk_if

`endif // __GUARD__DW_SBC_CDC_CLK_IF__SVH__

