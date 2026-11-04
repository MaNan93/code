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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/svif/DW_sbc_cdc_pop_ctl_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DW_SBC_CDC_POP_CTL_IF__SVH__
`define __GUARD__DW_SBC_CDC_POP_CTL_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DW_sbc_cdc_pop_ctl_if
  import DW_sbc_cdc_pkg::*;
  #(
   parameter LP_CTR_W = 5
  ,parameter  P_NSEGS = 5
  ,parameter  P_RAM_W = 64
  ,parameter P_SEG_AW = $clog2(P_NSEGS)
  );

  popCommand_e                             w_pop             ;
  logic        [P_NSEGS-1:0][LP_CTR_W-1:0] w_pop_ctr_local   ;
  logic                      [P_RAM_W-1:0] w_pop_data_d      ;
  logic                                    w_pop_data_valid  ;
  logic                     [P_SEG_AW-1:0] w_pop_seg         ;
  logic        [P_NSEGS-1:0][LP_CTR_W-1:0] w_push_ctr_remote ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    input  w_pop
   ,output w_pop_ctr_local
   ,output w_pop_data_d
   ,output w_pop_data_valid
   ,input  w_pop_seg
   ,input  w_push_ctr_remote
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    output w_pop
   ,input  w_pop_ctr_local
   ,input  w_pop_data_d
   ,input  w_pop_data_valid
   ,output w_pop_seg
   ,output w_push_ctr_remote
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface : DW_sbc_cdc_pop_ctl_if

`endif // __GUARD__DW_SBC_CDC_POP_CTL_IF__SVH__

