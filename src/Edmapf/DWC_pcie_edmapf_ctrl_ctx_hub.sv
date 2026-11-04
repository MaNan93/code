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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ctx_hub.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ctx_hub
  import DWC_pcie_edmapf_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp            b_clk
  ,DWC_pcie_edmapf_genericData_if.slave_mp      b_glbCtx
  ,DWC_pcie_edmapf_ctxPop_haltable_if.master_mp b_pop
  ,DWC_pcie_edmapf_ctxPop_haltable_if.slave_mp  b_push
  );


// SNPS_SysML_CODE_START
  /*
    Joining the ovrl and global data
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_b_pop_PROC
    if (!b_clk.w_reset_n) begin
      b_pop.w_data  <= #`TP '0;
      b_pop.w_valid <= #`TP '0;
    end else begin
      if (!b_pop.w_halt || !b_pop.w_valid) begin
        b_pop.w_data.channel  <= #`TP b_push.w_data.channel;
        b_pop.w_data.ctx.ovrl <= #`TP b_push.w_data.ovrl;
        b_pop.w_data.ctx.glb  <= #`TP b_glbCtx.w_data[b_push.w_data.channel];
        b_pop.w_valid         <= #`TP b_push.w_valid;
      end
    end
  end : s_b_pop_PROC
  
  /*
    Connecting the interfaces
  */
  always_comb begin : c_b_push_PROC
    b_push.w_halt = b_pop.w_halt && b_pop.w_valid;
    b_push.w_pop  = b_pop.w_pop;
    b_push.w_tag  = b_pop.w_tag;
  end : c_b_push_PROC
  
// SNPS_SysML_CODE_END

endmodule
