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
// ---    $Revision: #7 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_mwr2wack.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_mwr2wack
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter P_CHANWD = 2
  ,parameter  P_TAGWD = 2
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp   b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp  b_out
  ,DWC_pcie_edmapf_wack_if.master_mp b_wack
  );


// SNPS_SysML_CODE_START

  typedef struct packed {
    logic [P_TAGWD-1:0]  tag  ;
    logic [P_CHANWD-1:0] chan ;
  } wack_s;

  struct packed {
    wack_s wackSaved ;
    wack_s wackOut   ;
    logic  validSaved;
    logic  validOut  ;
  } s,r;

  /*
  * r register.
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP '0;
    end else begin
      r <= #`TP s;
    end
  end : r_PROC

  logic s_valid   ;
  logic s_release ;
  logic s_mwr;
  logic s_dma;
  logic s_halt;

  assign s_valid   = b_in.w_hv  && !b_in.w_halt && s_dma && s_mwr;
  assign s_release = (s_valid && b_in.w_eot) || (b_in.w_dv && !b_in.w_halt && r.validSaved && b_in.w_eot );

  assign s_mwr     = (b_in.w_header ==? K_MWRHEADER);
  assign s_dma     = (b_in.w_header.dma.req != E_DMA_BYPASS);

  always_comb begin : saved_PROC
    if (s_valid) begin
      s.wackSaved.tag  = b_in.w_header.tag;
      s.wackSaved.chan = b_in.w_header.dma.channel;
    end else begin
      s.wackSaved= r.wackSaved;
    end
  end

  always_comb begin : validSaved_PROC
    if (s_release) begin
      s.validSaved = 1'b0;
    end else if (s_valid) begin
      s.validSaved = 1'b1;
    end else begin
      s.validSaved = r.validSaved;
    end
  end

  always_comb begin : tagOut_PROC
    if (s_release) begin
      if (s_valid) begin
        s.wackOut.tag  = b_in.w_header.tag;
        s.wackOut.chan = b_in.w_header.dma.channel;
      end else if (r.validSaved) begin
        s.wackOut = r.wackSaved;
      end else begin
        s.wackOut = '0;
      end
    end else if (!b_wack.w_halt) begin
      s.wackOut = '0;
    end else begin
      s.wackOut = r.wackOut;
    end
  end

  always_comb begin : validOut_PROC
    if (s_release) begin
      s.validOut = 1'b1;
    end else if (!b_wack.w_halt) begin
      s.validOut = 1'b0;
    end else begin
      s.validOut = r.validOut;
    end
  end

  assign s_halt             = b_wack.w_halt && b_wack.w_valid;
  // Register the tag on hv to reply to the wresp on eot
  assign b_wack.w_error     = '0                                                ;
  assign b_wack.w_tag       = r.wackSaved.tag                                   ;
  assign b_wack.w_channel   = r.wackSaved.chan                                  ;
  assign b_wack.w_valid     = r.validOut                                        ;

  assign b_out.w_header     = b_in.w_header                                     ;
  assign b_out.w_headerProt = b_in.w_headerProt                                 ;
  assign b_out.w_data       = b_in.w_data                                       ;
  assign b_out.w_hv         = b_in.w_hv && !s_halt                              ;
  assign b_out.w_dv         = b_in.w_dv && !s_halt                              ;
  assign b_out.w_eot        = b_in.w_eot && !s_halt                             ;
  assign b_in.w_halt        = b_out.w_halt || s_halt                            ;

// SNPS_SysML_CODE_END

endmodule
