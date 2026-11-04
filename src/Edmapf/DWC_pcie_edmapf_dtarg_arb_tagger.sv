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
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_dtarg_arb_tagger.sv#6 $ 
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

module DWC_pcie_edmapf_dtarg_arb_tagger
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_MAXMWR = 1024
  ,parameter  P_TAGWD = 8
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp    b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp     b_out
  ,DWC_pcie_edmapf_ctxPush_if.master_mp b_push
  );


// SNPS_SysML_CODE_START

  logic s_isMWr   ;
  logic s_isCpl   ;
  logic s_isMsg   ;
  logic s_isDMA   ;
  logic s_isNPReq ;
  logic                   s_isAbort  ;
  logic [K_LUIDMAPWD-1:0] r_push_data;


  assign s_isMWr   = (b_in.w_header ==? K_MWRHEADER);
  assign s_isCpl   = (b_in.w_header ==? K_CPLHEADER);
  assign s_isMsg   = (b_in.w_header ==? K_MSGHEADER);
  assign s_isNPReq = !(s_isMWr || s_isMsg || s_isCpl);
  assign s_isDMA   = !(b_in.w_header.dma.req == E_DMA_BYPASS || b_in.w_header.dma.req == E_DMA_BYPASS_CPL);
  assign s_isAbort = (b_in.w_header.common4.tlp_abort || b_in.w_header.common4.dllp_abort);

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_push_data_PROC
    if (!b_clk.w_reset_n) begin
      r_push_data <= #`TP '0;
    end else begin
      if (b_in.w_hv && s_isNPReq && !b_in.w_eot && !b_out.w_halt) begin
        r_push_data <= #`TP K_LUIDMAPWD'(b_in.w_header.common3.lookupid);
      end
    end  
  end

  always_comb begin : header_PROC
    b_out.w_header = b_in.w_header;
    b_out.w_headerProt = '0;
    if (b_in.w_hv && s_isNPReq) begin
      b_out.w_header.common3.lookupid = b_push.w_tag;
    end
  end

  // Impossible situation which means this code is redundant so it should be moved to an assertion
  always_comb begin : halt_PROC
    if (b_in.w_hv && s_isNPReq && b_push.w_full) begin
      b_out.w_hv  = '0 ;
      b_out.w_dv  = '0 ;
      b_out.w_eot = '0 ;
      b_in.w_halt = '1 ;
    end else begin
      b_out.w_hv  = b_in.w_hv    ;
      b_out.w_dv  = b_in.w_dv    ;
      b_out.w_eot = b_in.w_eot   ;
      b_in.w_halt = b_out.w_halt ;
    end
  end

  assign b_out.w_data   = b_in.w_data   ;
  assign b_push.w_push  = s_isNPReq && !s_isAbort && b_in.w_eot && !b_out.w_halt && !b_push.w_full;
  assign b_push.w_data  = s_isDMA ? K_LUIDMAPWD'(b_in.w_header.tag) : (b_in.w_hv ?  K_LUIDMAPWD'(b_in.w_header.common3.lookupid) : r_push_data);

// SNPS_SysML_CODE_END

endmodule
