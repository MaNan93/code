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
// ---    $DateTime: 2022/04/14 09:36:50 $ 
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_stsh_stsHub.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_status_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_stsh_stsHub
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_CHAN = 16
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_genericData_if.master_mp b_channelRunning
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_enabled
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_interrupts
  ,DWC_pcie_edmapf_status_if.master_mp      b_status
  ,DWC_pcie_edmapf_genericData_if.slave_mp  b_xferPending
  );


// SNPS_SysML_CODE_START
  always_comb begin : status_PROC
    int i;
    for (i = 0; i < P_CHAN; i += 1) begin
      b_status.w_channel[i].interrupt   = b_interrupts.w_data[i] ;
      b_status.w_channel[i].xferPending = b_xferPending.w_data[i];
      b_status.w_channel[i].enabled     = b_enabled.w_data[i]    ;
      b_channelRunning.w_data[i]        = b_xferPending.w_data[i];
    end
  end
// SNPS_SysML_CODE_END

endmodule
