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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_main_clk_detect.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_main_clk_detect

(
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################

   DWC_pcie_edmapf_aclks_if.slave_mp b_clkrst
  ,output logic                      b_main_clk_detect
  );

// SNPS_SysML_CODE_START
  // ***************************************************
  // Main clock detector
  // ***************************************************
  typedef struct packed {
    logic r_aux_clk_token;
    logic r_main_clk_token;
    logic main_clk_on;
  } st_main_clk_detect;

  st_main_clk_detect main_clk_detect;

  always_ff @ (posedge b_clkrst.w_main_clk or negedge b_clkrst.w_reset_n) begin : PROC_FF_main_clk_detect
    if (!b_clkrst.w_reset_n)
      main_clk_detect.r_main_clk_token <= # `TP '1;
    else begin 
      if (main_clk_detect.main_clk_on)
        main_clk_detect.r_main_clk_token <= # `TP main_clk_detect.r_aux_clk_token;
      else
        main_clk_detect.r_main_clk_token <= # `TP ~main_clk_detect.r_aux_clk_token;
    end
  end

  always_ff @ (posedge b_clkrst.w_aux_clk or negedge b_clkrst.w_reset_n) begin : PROC_FF_main_clk_detect_aux
    if (!b_clkrst.w_reset_n) 
      main_clk_detect.r_aux_clk_token <= # `TP '0;
    else
      main_clk_detect.r_aux_clk_token <= # `TP main_clk_detect.r_main_clk_token;
  end

  assign main_clk_detect.main_clk_on = main_clk_detect.r_aux_clk_token ^ main_clk_detect.r_main_clk_token;

  assign b_main_clk_detect = main_clk_detect.main_clk_on;
// SNPS_SysML_CODE_END

endmodule : DWC_pcie_edmapf_main_clk_detect
