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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tlp_2to1_arb.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_tlp_2to1_arb
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp b_clkrst
  ,DWC_pcie_edmapf_tlp_if.master_mp  b_dst
  ,DWC_pcie_edmapf_tlp_if.slave_mp   b_src1
  ,DWC_pcie_edmapf_tlp_if.slave_mp   b_src2
  );


// SNPS_SysML_CODE_START

  logic       r_sel    ;
  logic       s_sel    ;
  logic       r_xfp    ;
  logic       s_xfp    ;
  logic       s_req_en ;
  
  logic [1:0] s_hv    ;
  logic [1:0] s_eot   ;
  logic [1:0] s_multi ; // multi clock cycle tlp
  
  assign s_hv[0]    = b_src1.w_hv;
  assign s_hv[1]    = b_src2.w_hv;
  assign s_eot[0]   = b_src1.w_eot;
  assign s_eot[1]   = b_src2.w_eot;

  assign s_multi  = s_hv & ~s_eot;
  
  assign s_req_en = (|s_hv) && !r_xfp;

  assign b_dst.w_data       =  s_sel ? b_src2.w_data       : b_src1.w_data      ;
  assign b_dst.w_header     =  s_sel ? b_src2.w_header     : b_src1.w_header    ;
  assign b_dst.w_hv         =  s_sel ? b_src2.w_hv         : b_src1.w_hv        ;
  assign b_dst.w_dv         =  s_sel ? b_src2.w_dv         : b_src1.w_dv        ;
  assign b_dst.w_eot        =  s_sel ? b_src2.w_eot        : b_src1.w_eot       ;
  assign b_dst.w_headerProt =  s_sel ? b_src2.w_headerProt : b_src1.w_headerProt;

  assign b_src1.w_halt      = !s_sel ? b_dst.w_halt        : 1'b1               ;
  assign b_src2.w_halt      =  s_sel ? b_dst.w_halt        : 1'b1               ;

  always_comb begin : s_xfp_PROC
    if (r_xfp && s_eot[s_sel]) begin
      s_xfp = '0;
    end else if (!r_xfp && s_multi[s_sel]) begin
      s_xfp = '1;
    end else begin
      s_xfp = r_xfp;
    end
  end

  always_comb begin : s_sel_PROC
    if (s_req_en) begin
      case (s_hv)
        2'b01: s_sel = 1'b0;
        2'b10: s_sel = 1'b1;
        2'b11: s_sel = !r_sel;
        default: s_sel = r_sel;
      endcase
    end else begin
      s_sel = r_sel;
    end
  end

  always_ff @(posedge b_clkrst.w_main_clk, negedge b_clkrst.w_reset_n) begin : r_sel_PROC
    if (!b_clkrst.w_reset_n) begin
      r_sel <= #`TP '0;
    end else begin
      if (b_dst.w_halt) begin
        r_sel <= #`TP r_sel;
      end else begin
        r_sel <= #`TP s_sel;
      end
    end
  end : r_sel_PROC
  
  always_ff @(posedge b_clkrst.w_main_clk, negedge b_clkrst.w_reset_n) begin : r_xfp_PROC
    if (!b_clkrst.w_reset_n) begin
      r_xfp <= #`TP '0;
    end else begin
      if (b_dst.w_halt) begin
        r_xfp <= #`TP r_xfp;
      end else begin
        r_xfp <= #`TP s_xfp;
      end
    end
  end : r_xfp_PROC

  `ifndef SYNTHESIS
  `endif

// SNPS_SysML_CODE_END

endmodule
