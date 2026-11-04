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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_crgb_1to5_rtr.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_crgb_1to5_rtr
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
  ,DWC_pcie_edmapf_crgb_if.master_mp b_out3
  ,DWC_pcie_edmapf_crgb_if.master_mp b_out4
  ,DWC_pcie_edmapf_crgb_if.master_mp b_out5
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_crgb_if b_DWC_pcie_edmapf_crgb_if_0();
  DWC_pcie_edmapf_crgb_if b_DWC_pcie_edmapf_crgb_if_1();
  DWC_pcie_edmapf_crgb_if b_DWC_pcie_edmapf_crgb_if_2();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_crgb_1to2_rtr
  
    u0_2to1_crgb (
   .b_in   ( b_in                                  )
  ,.b_out1 ( b_DWC_pcie_edmapf_crgb_if_0.master_mp )
  ,.b_out2 ( b_DWC_pcie_edmapf_crgb_if_1.master_mp )
  );

  DWC_pcie_edmapf_crgb_1to2_rtr
  
    u1_2to1_crgb (
   .b_in   ( b_DWC_pcie_edmapf_crgb_if_0.slave_mp  )
  ,.b_out1 ( b_out1                                )
  ,.b_out2 ( b_out2                                )
  );

  DWC_pcie_edmapf_crgb_1to2_rtr
  
    u2_2to1_crgb (
   .b_in   ( b_DWC_pcie_edmapf_crgb_if_1.slave_mp  )
  ,.b_out1 ( b_out3                                )
  ,.b_out2 ( b_DWC_pcie_edmapf_crgb_if_2.master_mp )
  );

  DWC_pcie_edmapf_crgb_1to2_rtr
  
    u3_2to1_crgb (
   .b_in   ( b_DWC_pcie_edmapf_crgb_if_2.slave_mp  )
  ,.b_out1 ( b_out4                                )
  ,.b_out2 ( b_out5                                )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
