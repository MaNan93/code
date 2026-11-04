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
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tlp_3to1_arb.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_tlp_3to1_arb
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp  b_dst
  ,DWC_pcie_edmapf_tlp_if.slave_mp   b_src1
  ,DWC_pcie_edmapf_tlp_if.slave_mp   b_src2
  ,DWC_pcie_edmapf_tlp_if.slave_mp   b_src3
  );


// SNPS_SysML_CODE_START
  typedef enum logic [1:0] {
    E_SEL_SRC1
   ,E_SEL_SRC2
   ,E_SEL_SRC3
  } arbSel_e;

  arbSel_e    r_sel    ;
  arbSel_e    s_sel    ;
  logic       r_xfp    ;
  logic       s_xfp    ;
  logic       s_req_en ;
  
  logic [2:0] s_hv    ;
  logic [2:0] s_eot   ;
  logic [2:0] s_multi ; // multi clock cycle tlp
  
  assign s_hv[E_SEL_SRC1]    = b_src1.w_hv;
  assign s_hv[E_SEL_SRC2]    = b_src2.w_hv;
  assign s_hv[E_SEL_SRC3]    = b_src3.w_hv;
  assign s_eot[E_SEL_SRC1]   = (b_src1.w_hv | b_src1.w_dv) & b_src1.w_eot;
  assign s_eot[E_SEL_SRC2]   = (b_src2.w_hv | b_src2.w_dv) & b_src2.w_eot;
  assign s_eot[E_SEL_SRC3]   = (b_src3.w_hv | b_src3.w_dv) & b_src3.w_eot;

  assign s_multi  = s_hv & ~s_eot;
  
  assign s_req_en = (|s_hv) && !r_xfp;
  
  always_comb begin : b_dst_PROC
    case (s_sel)
      E_SEL_SRC1: begin
        b_dst.w_data       = b_src1.w_data       ;
        b_dst.w_header     = b_src1.w_header     ;
        b_dst.w_hv         = b_src1.w_hv         ;
        b_dst.w_dv         = b_src1.w_dv         ;
        b_dst.w_eot        = b_src1.w_eot        ;
        b_dst.w_headerProt =  b_src1.w_headerProt;
      end
      E_SEL_SRC2: begin
        b_dst.w_data       = b_src2.w_data       ;
        b_dst.w_header     = b_src2.w_header     ;
        b_dst.w_hv         = b_src2.w_hv         ;
        b_dst.w_dv         = b_src2.w_dv         ;
        b_dst.w_eot        = b_src2.w_eot        ;
        b_dst.w_headerProt =  b_src2.w_headerProt;
      end
      E_SEL_SRC3: begin
        b_dst.w_data       = b_src3.w_data       ;
        b_dst.w_header     = b_src3.w_header     ;
        b_dst.w_hv         = b_src3.w_hv         ;
        b_dst.w_dv         = b_src3.w_dv         ;
        b_dst.w_eot        = b_src3.w_eot        ;
        b_dst.w_headerProt =  b_src3.w_headerProt;
      end
      default: begin
        b_dst.w_data       = b_src1.w_data       ;
        b_dst.w_header     = b_src1.w_header     ;
        b_dst.w_hv         = b_src1.w_hv         ;
        b_dst.w_dv         = b_src1.w_dv         ;
        b_dst.w_eot        = b_src1.w_eot        ;
        b_dst.w_headerProt =  b_src1.w_headerProt;
      end
    endcase
  end

  always_comb begin : b_src_PROC
    case (s_sel)
      E_SEL_SRC1: begin
        b_src1.w_halt  = b_dst.w_halt ;
        b_src2.w_halt  = 1'b1         ;
        b_src3.w_halt  = 1'b1         ;
      end
      E_SEL_SRC2: begin
        b_src1.w_halt  = 1'b1         ;
        b_src2.w_halt  = b_dst.w_halt ;
        b_src3.w_halt  = 1'b1         ;
      end
      E_SEL_SRC3: begin
        b_src1.w_halt  = 1'b1         ;
        b_src2.w_halt  = 1'b1         ;
        b_src3.w_halt  = b_dst.w_halt ;
      end
      default: begin
        b_src1.w_halt  = b_dst.w_halt ;
        b_src2.w_halt  = 1'b1         ;
        b_src3.w_halt  = 1'b1         ;
      end
    endcase
  end

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
      case (r_sel)
        E_SEL_SRC1 : begin
          if (s_hv[E_SEL_SRC2]) begin
            s_sel = E_SEL_SRC2;
          end else if (s_hv[E_SEL_SRC3]) begin
            s_sel = E_SEL_SRC3;
          end else begin
            s_sel = E_SEL_SRC1;
          end
        end
        E_SEL_SRC2 : begin
          if (s_hv[E_SEL_SRC3]) begin
            s_sel = E_SEL_SRC3;
          end else if (s_hv[E_SEL_SRC1]) begin
            s_sel = E_SEL_SRC1;
          end else begin
            s_sel = E_SEL_SRC2;
          end
        end
        E_SEL_SRC3 : begin
          if (s_hv[E_SEL_SRC1]) begin
            s_sel = E_SEL_SRC1;
          end else if (s_hv[E_SEL_SRC2]) begin
            s_sel = E_SEL_SRC2;
          end else begin
            s_sel = E_SEL_SRC3;
          end
        end
        default: s_sel = r_sel;
      endcase
    end else begin
      s_sel = r_sel;
    end
  end

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_sel_PROC
    if (!b_clk.w_reset_n) begin
      r_sel <= #`TP E_SEL_SRC1;
    end else begin
      if (b_dst.w_halt) begin
        r_sel <= #`TP r_sel;
      end else begin
        r_sel <= #`TP s_sel;
      end
    end
  end : r_sel_PROC
  
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_xfp_PROC
    if (!b_clk.w_reset_n) begin
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
