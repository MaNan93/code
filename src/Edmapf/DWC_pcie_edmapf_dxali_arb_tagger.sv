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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_dxali_arb_tagger.sv#5 $ 
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

module DWC_pcie_edmapf_dxali_arb_tagger
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp    b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp     b_out
  ,DWC_pcie_edmapf_ctxPush_if.master_mp b_push
  );


// SNPS_SysML_CODE_START

  assign b_push.w_push  = b_in.w_hv && !b_in.w_halt && b_in.w_header ==? K_MRDHEADER;
  assign b_push.w_data  = {b_in.w_header.tag, b_in.w_header.dma.channel};

  always_comb begin : b_out_PROC
    b_out.w_data       = b_in.w_data  ;
    b_out.w_header     = b_in.w_header;
    b_out.w_headerProt = '0;
    if (b_in.w_hv) begin
      if (!b_push.w_full) begin
          b_out.w_eot                    = b_in.w_eot   ;
          b_out.w_dv                     = b_in.w_dv    ;
          b_out.w_hv                     = b_in.w_hv    ;
          if (b_in.w_header ==? K_MWRHEADER) begin
            b_out.w_header.common1.pcieTag = '0;
          end else begin
            b_out.w_header.common1.pcieTag = b_push.w_tag ;
          end
          b_in.w_halt                    = b_out.w_halt ;
      end else begin
        b_out.w_eot     = '0 ;
        b_out.w_dv      = '0 ;
        b_out.w_hv      = '0 ;
        b_in.w_halt     = '1 ;
      end
    end else begin
      b_out.w_eot     = b_in.w_eot   ;
      b_out.w_dv      = b_in.w_dv    ;
      b_out.w_hv      = b_in.w_hv    ;
      b_in.w_halt     = b_out.w_halt ;
    end
  end
// SNPS_SysML_CODE_END

endmodule
