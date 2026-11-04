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
// ---    $DateTime: 2023/06/26 08:32:07 $ 
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_cpl2mwr_push.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_cpl2mwr_push
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp    b_clk
  ,DWC_pcie_edmapf_ctxPush_if.master_mp b_ctxPush
  ,DWC_pcie_edmapf_tlp_if.master_mp     b_mwr
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_tlpCtx
  );


// SNPS_SysML_CODE_START
  
  xradm_s r_headerSnap;
  
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : snapshot_PROC
    if (!b_clk.w_reset_n) begin
      r_headerSnap <= #`TP '0;
    end else begin
      if (b_mwr.w_hv && !b_mwr.w_halt) begin
        r_headerSnap <= #`TP b_mwr.w_header;
      end else if (b_mwr.w_eot && !b_mwr.w_halt) begin
        r_headerSnap <= #`TP '0;
      end
    end
  end

  always_comb begin : mwr_PROC
    b_mwr.w_data   = b_tlpCtx.w_data          ;
    b_mwr.w_headerProt = '0;
    if (b_tlpCtx.w_hv) begin
      b_mwr.w_header = b_tlpCtx.w_header.header ;
      if (b_ctxPush.w_full) begin
        b_mwr.w_hv         = '0 ;
        b_mwr.w_dv         = '0 ;
        b_mwr.w_eot        = '0 ;
        b_mwr.w_header     = '0 ;
      end else begin
        b_mwr.w_hv         = b_tlpCtx.w_hv            ;
        b_mwr.w_dv         = b_tlpCtx.w_dv            ;
        b_mwr.w_eot        = b_tlpCtx.w_eot           ;
        b_mwr.w_header.tag = b_ctxPush.w_tag          ;
      end
    end else begin
      b_mwr.w_hv                         = b_tlpCtx.w_hv                          ;
      b_mwr.w_dv                         = b_tlpCtx.w_dv                          ;
      b_mwr.w_eot                        = b_tlpCtx.w_eot                         ;
      b_mwr.w_header                     = r_headerSnap                           ;
      b_mwr.w_header.common4.dwen        = b_tlpCtx.w_header.header.common4.dwen  ;
    end
  end

  assign b_tlpCtx.w_halt = (b_tlpCtx.w_hv && b_ctxPush.w_full) ? '1 : b_mwr.w_halt;
  assign b_ctxPush.w_push   = b_tlpCtx.w_hv && !b_tlpCtx.w_halt;
  assign b_ctxPush.w_data.ovrl   = b_tlpCtx.w_header.ctx.ctx.ovrl;
  assign b_ctxPush.w_data.channel   = b_tlpCtx.w_header.ctx.channel;

// SNPS_SysML_CODE_END

endmodule
