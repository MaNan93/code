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
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tlp_1to2_rtr.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_tlp_1to2_rtr
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter             type P_HEADERTYPE = logic
  ,parameter               ifType_e P_TYPE = E_TLP_HEADER
  ,parameter tlpDmapfTarget_e P_DST1TARGET = E_NOT_DMAPF
  ) 
                                     (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   interface.master_mp                 b_dst1
  ,interface.master_mp                 b_dst2
  ,interface.slave_mp                  b_src
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp   b_clk
  );


// SNPS_SysML_CODE_START

  struct packed {
    logic validTLP1;
    logic validTLP2;
  } r,s;

  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP '0;
    end else begin
      r <= #`TP s;
    end
  end

  logic s_validHeader;
  logic s_validHv1;
  logic s_validHv2;
  logic s_validEot1;
  logic s_validEot2;
  logic s_validDst1;
  logic s_validDst2;
  logic s_validHalt1;
  logic s_validHalt2;

  generate
    if (P_TYPE == E_TLP_FULL) begin : TYPE_TLP_FULL_GEN
      case (P_DST1TARGET)
        default         : begin : DST1TARGET_DEFAULT_GEN
          assign s_validHeader = 1'b0;
        end
        E_NOT_DMAPF     : begin : DST1TARGET_NOT_DMAPF_GEN
          assign s_validHeader = (b_src.w_header.dma.req == E_DMA_BYPASS);
        end
        E_DMAPF_RD_LL   : begin : DST1TARGET_RDLL_GEN
          assign s_validHeader = (b_src.w_header.dma.req == E_DMA_RDCH_LLREAD);
        end
        E_DMAPF_RD_DATA : begin : DST1TARGET_RDDATA_GEN
          always_comb begin : validHeader_PROC
            if (b_cdm.w_cfg_ext_tag_en && b_cdm.w_cfg_10b_tag_en) begin
              s_validHeader = (
                              (b_src.w_header.common1.pcieTag inside {[K_MINDMATAG:K_MAXPCIETAG]}) &&
                              (b_src.w_header.common2.typ ==? 5'b0101x));
            end else if (b_cdm.w_cfg_ext_tag_en) begin
              s_validHeader = (
                              (b_src.w_header.common1.pcieTag inside {[K_MINDMATAG_8BIT:K_MAXPCIETAG_8BIT]}) &&
                              (b_src.w_header.common2.typ ==? 5'b0101x));
            end else begin
              s_validHeader = (
                              (b_src.w_header.common1.pcieTag inside {[K_MINDMATAG_5BIT:K_MAXPCIETAG_5BIT]}) &&
                              (b_src.w_header.common2.typ ==? 5'b0101x));
            end
          end
        end
        E_DMAPF_WR_LL   : begin : DST1TARGET_WRLL_GEN
          assign s_validHeader = (b_src.w_header.dma.req == E_DMA_WRCH_LLREAD);
        end
        E_DMAPF_WR_DATA : begin : DST1TARGET_WRDATA_GEN
          assign s_validHeader = (b_src.w_header.dma.req == E_DMA_WRCH_DATA);
        end
      endcase
    end else begin : TYPE_NOT_TLP_FULL_GEN
      if (P_DST1TARGET == E_NOT_DMAPF) begin : DST1TARGET_NOT_DMAPF_GEN
          always_comb begin : validHeader_PROC
            if (b_cdm.w_cfg_ext_tag_en && b_cdm.w_cfg_10b_tag_en) begin
              s_validHeader = !(b_src.w_header.common1.pcieTag inside {[K_MINDMATAG:K_MAXPCIETAG]});
            end else if (b_cdm.w_cfg_ext_tag_en) begin
              s_validHeader = !(b_src.w_header.common1.pcieTag inside {[K_MINDMATAG_8BIT:K_MAXPCIETAG_8BIT]});
            end else begin
              s_validHeader = !(b_src.w_header.common1.pcieTag inside {[K_MINDMATAG_5BIT:K_MAXPCIETAG_5BIT]});
            end
          end
      end else begin : DST1TARGET_DMAPF_GEN
          always_comb begin : validHeader_PROC
            if (b_cdm.w_cfg_ext_tag_en && b_cdm.w_cfg_10b_tag_en) begin
              s_validHeader = (b_src.w_header.common1.pcieTag inside {[K_MINDMATAG:K_MAXPCIETAG]});
            end else if (b_cdm.w_cfg_ext_tag_en) begin
              s_validHeader = (b_src.w_header.common1.pcieTag inside {[K_MINDMATAG_8BIT:K_MAXPCIETAG_8BIT]});
            end else begin
              s_validHeader = (b_src.w_header.common1.pcieTag inside {[K_MINDMATAG_5BIT:K_MAXPCIETAG_5BIT]});
            end
          end
      end
    end
  endgenerate

  assign s_validHv1 = b_src.w_hv && s_validHeader;
  assign s_validHv2 = b_src.w_hv && !s_validHeader;
  assign s_validDst1 = (s_validHv1 || r.validTLP1);
  assign s_validDst2 = (s_validHv2 || r.validTLP2);

  generate
    if (P_TYPE == E_TLP_HEADER) begin : TLP_HEADER_EOT_GEN
      assign s_validEot1 = '0;
      assign s_validEot2 = '0;
    end else if (P_TYPE == E_TLP_BYPASS) begin : TLP_BYPASS_EOT_GEN
      assign s_validEot1 = b_src.w_eot;
      assign s_validEot2 = b_src.w_eot;
    end else begin : TLP_FULL_EOT_GEN
      assign s_validEot1 = b_src.w_eot && !b_dst1.w_halt;
      assign s_validEot2 = b_src.w_eot && !b_dst2.w_halt;
    end
  endgenerate

  generate
    if (P_TYPE == E_TLP_FULL) begin : TLP_FULL_HALT_GEN
      assign s_validHalt1 = (s_validHv1 || r.validTLP1) && b_dst1.w_halt;
      assign s_validHalt2 = (s_validHv2 || r.validTLP2) && b_dst2.w_halt;
    end else begin : TLP_BYPASS_HALT_GEN
      assign s_validHalt1 = '0;
      assign s_validHalt2 = '0;
    end
  endgenerate

  generate
    if (P_TYPE != E_TLP_HEADER) begin : TLP_BYPASS_VALID_GEN
      always_comb begin : validTLP1_PROC
        case ({s_validHv1,s_validEot1})
          default: s.validTLP1 = r.validTLP1;
          2'b01  : s.validTLP1 = '0         ;
          2'b10  : s.validTLP1 = '1         ;
          2'b11  : s.validTLP1 = '0         ;
        endcase
      end
      always_comb begin : validTLP2_PROC
        case ({s_validHv2,s_validEot2})
          default: s.validTLP2 = r.validTLP2;
          2'b01  : s.validTLP2 = '0         ;
          2'b10  : s.validTLP2 = '1         ;
          2'b11  : s.validTLP2 = '0         ;
        endcase
      end
    end else begin
      assign s.validTLP1 = '0;
      assign s.validTLP2 = '0;
    end
  endgenerate

  assign b_dst1.w_hv         = s_validDst1 ? b_src.w_hv : 1'b0 ;
  assign b_dst2.w_hv         = s_validDst2 ? b_src.w_hv : 1'b0 ;
  assign b_dst1.w_header     = b_src.w_header;
  assign b_dst2.w_header     = b_src.w_header;
  generate
    if (P_TYPE != E_TLP_HEADER) begin : TLP_BYPASS_IF_GEN
      assign b_dst1.w_dv     = s_validDst1 ? b_src.w_dv  : 1'b0 ;
      assign b_dst2.w_dv     = s_validDst2 ? b_src.w_dv  : 1'b0 ;
      assign b_dst1.w_eot    = s_validDst1 ? b_src.w_eot : 1'b0 ;
      assign b_dst2.w_eot    = s_validDst2 ? b_src.w_eot : 1'b0 ;
      assign b_dst1.w_data   = b_src.w_data  ;
      assign b_dst2.w_data   = b_src.w_data  ;
      assign b_dst1.w_headerProt = b_src.w_headerProt;
      assign b_dst2.w_headerProt = b_src.w_headerProt;
      if (P_TYPE == E_TLP_FULL) begin : TLP_FULL_IF_GEN
        assign b_src.w_halt = (s_validHalt1 || s_validHalt2);
      end
    end
  endgenerate


// SNPS_SysML_CODE_END

endmodule
