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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_crgb_1to2_rtr.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_crgb_1to2_rtr
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter CC_CRGB_ADDR_WIDTH = `CC_CRGB_ADDR_WIDTH
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_crgb_if.slave_mp  b_in
  ,DWC_pcie_edmapf_crgb_if.master_mp b_out1
  ,DWC_pcie_edmapf_crgb_if.master_mp b_out2
  );


// SNPS_SysML_CODE_START


   //out1 - outputs
   assign b_out1.w_wren            = b_in.w_wren           ;
   assign b_out1.w_source          = b_in.w_source         ;
   assign b_out1.w_rden            = b_in.w_rden           ;
   assign b_out1.w_address         = b_in.w_address        ;
   assign b_out1.w_wr_data         = b_in.w_wr_data        ;
   assign b_out1.w_wr_mask         = b_in.w_wr_mask        ;           

   //out2 - outputs
   assign b_out2.w_wren            = b_in.w_wren           ;
   assign b_out2.w_source          = b_in.w_source         ;
   assign b_out2.w_rden            = b_in.w_rden           ;
   assign b_out2.w_address         = b_in.w_address        ;
   assign b_out2.w_wr_data         = b_in.w_wr_data        ;
   assign b_out2.w_wr_mask         = b_in.w_wr_mask        ;           

   //in - outputs
   assign b_in.w_rd_data           = b_out1.w_rd_data        | b_out2.w_rd_data;
   assign b_in.w_ack               = b_out1.w_ack            | b_out2.w_ack;


// SNPS_SysML_CODE_END

endmodule
