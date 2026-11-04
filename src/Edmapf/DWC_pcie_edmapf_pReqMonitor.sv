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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #1 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_pReqMonitor.sv#1 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_pReqMonitor
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_genericData_if.master_mp b_clientPending
  ,DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_wack_if.slave_mp         b_reqIn
  ,DWC_pcie_edmapf_wack_if.slave_mp         b_reqOut
  );


// SNPS_SysML_CODE_START
  struct packed {
    logic [K_DMATAGWD-1:0] tag;
    logic                  valid;
  } r_data;
  
  
  /*
    <Comments>
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_r_data_PROC
    if (!b_clk.w_reset_n) begin
      r_data <= #`TP '0;
    end else begin
      if (b_reqIn.w_valid) begin
        r_data <= #`TP '{tag: b_reqIn.w_tag, valid: '1};
      end else if (b_reqOut.w_valid && (b_reqOut.w_tag == r_data.tag) && !b_reqIn.w_valid) begin
        r_data <= #`TP '0;
      end
    end
  end : s_r_data_PROC
  
  assign b_clientPending.w_data = r_data.valid;
  assign b_reqIn.w_halt = '0;
  assign b_reqOut.w_halt ='0;
// SNPS_SysML_CODE_END

endmodule
