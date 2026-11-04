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
// ---    $DateTime: 2023/12/22 07:15:34 $ 
// ---    $Revision: #10 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_untagger.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_untagger
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter   type P_HEADERTYPE = xradm_s
  ,parameter            P_DATAWD = 32
  ,parameter              P_DTAG = 10
  ,parameter             P_TAGWD = 10
  ,parameter tagType_e P_TAGTYPE = E_TAG_LUID
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp          b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp           b_dst
  ,DWC_pcie_edmapf_tlp_if.slave_mp            b_src
  ,DWC_pcie_edmapf_crPop_haltable_if.slave_mp b_tag
  );


// SNPS_SysML_CODE_START

  localparam integer LP_REG_DELAY_DENOM = 1000;
  localparam integer LP_REG_DELAY_TIME  = `TP * LP_REG_DELAY_DENOM;

  typedef struct packed {
    logic              hv     ;
    logic              dv     ;
    logic              eot    ;
    P_HEADERTYPE       header ;
    logic [P_DATAWD:1] data   ;
  } tlpFifo_s;

  struct packed {
    logic [P_TAGWD:1] tag      ;
    logic [P_TAGWD:1] dstTag   ;
    logic             isSrcCpl ;
    logic             isDstCpl ;
    logic             isDstDMA ;
  } r,s;

  logic     s_tlpFifo_push_req_n ;
  logic     s_tlpFifo_pop_req_n  ;
  tlpFifo_s s_tlpFifo_data_in    ;
  tlpFifo_s w_tlpFifo_data_out   ;
  logic     w_tlpFifo_full       ;
  logic     w_tlpFifo_empty      ;
  logic     s_wasTagRequested    ;
  logic     s_wasTagPopped       ;

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP '0;
    end else begin
      r <= #`TP s;
    end
  end

  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( $bits(tlpFifo_s)        )
    ,.DEPTH           ( 3                       )
    ,.AE_LEVEL        ( 1                       )
    ,.AF_LEVEL        ( 1                       )
    ,.ERR_MODE        ( 2                       )
    ,.RST_MODE        ( 0                       )
    ,.ADDR_WIDTH      ( 2                       )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME       )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM      )
  )
  u_tlpFifo(
     .clk           ( b_clk.w_main_clk        )
    ,.rst_n         ( b_clk.w_reset_n         )
    ,.init_n        ( 1'b1                    )
    ,.push_req_n    ( s_tlpFifo_push_req_n    )
    ,.pop_req_n     ( s_tlpFifo_pop_req_n     )
    ,.data_in       ( s_tlpFifo_data_in       )
    ,.data_out      ( w_tlpFifo_data_out      )
    ,.full          ( w_tlpFifo_full          )
    ,.empty         ( w_tlpFifo_empty         )
      ,.diag_n      ( 1'b0                    )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.almost_empty  ( /* NC */                )
    ,.half_full     ( /* NC */                )
    ,.almost_full   ( /* NC */                )
    ,.error         ( /* NC */                )
    // spyglass enable_block W287b
    );


    assign s_tlpFifo_push_req_n = b_src.w_halt || !(b_src.w_dv || b_src.w_hv);
    assign s_tlpFifo_pop_req_n  = b_dst.w_halt || !(b_dst.w_dv || b_dst.w_hv);
    assign s_tlpFifo_data_in    = tlpFifo_s'{
       hv     : b_src.w_hv
      ,dv     : b_src.w_dv
      ,eot    : b_src.w_eot
      ,header : b_src.w_header
      ,data   : b_src.w_data
    };

    assign s.isSrcCpl = b_src.w_hv            ? (b_src.w_header ==? K_CPLHEADER)                                                                             : r.isSrcCpl;
    assign s.isDstCpl = w_tlpFifo_data_out.hv ? (w_tlpFifo_data_out.header ==? K_CPLHEADER)                                                                  : r.isDstCpl;
    assign s.isDstDMA = w_tlpFifo_data_out.hv ? (w_tlpFifo_data_out.header.dma.req != E_DMA_BYPASS && w_tlpFifo_data_out.header.dma.req != E_DMA_BYPASS_CPL) : r.isDstDMA;
    assign s_wasTagRequested = (w_tlpFifo_data_out.hv) && s.isDstCpl;
    assign s_wasTagPopped    = (w_tlpFifo_data_out.hv || w_tlpFifo_data_out.dv) && w_tlpFifo_data_out.eot && w_tlpFifo_data_out.header.common4.cpl_last && s.isSrcCpl;

    always_comb begin : b_dst_PROC
      b_dst.w_hv             = !w_tlpFifo_empty && w_tlpFifo_data_out.hv  && (b_tag.w_valid || !s_wasTagRequested) ;
      b_dst.w_dv             = !w_tlpFifo_empty && w_tlpFifo_data_out.dv  && (b_tag.w_valid || !s_wasTagRequested) ;
      b_dst.w_eot            = !w_tlpFifo_empty && w_tlpFifo_data_out.eot && (b_tag.w_valid || !s_wasTagRequested) ;
      b_dst.w_data           = w_tlpFifo_data_out.data                                                             ;
      b_dst.w_header         = w_tlpFifo_data_out.header                                                           ;
      if (s.isDstCpl) begin
        if (s.isDstDMA) begin
          b_dst.w_header.tag = b_dst.w_hv ? b_tag.w_data : K_DMATAGWD'(r.dstTag);
        end else begin
          b_dst.w_header.common3.lookupid = b_dst.w_hv ? b_tag.w_data : K_LUIDWD'(r.dstTag);
        end
      end
      b_dst.w_headerProt = '0;
    end

    assign b_src.w_halt      = w_tlpFifo_full && b_dst.w_halt;

    assign s.dstTag = b_dst.w_hv ? b_tag.w_data : r.dstTag ;

    generate
      if (P_TAGTYPE == E_TAG_LUID) begin : LUID_GEN
        assign s.tag = b_src.w_hv && !b_src.w_halt ? b_src.w_header.common3.lookupid[P_TAGWD-1:0] : r.tag;
      end else begin : PCIE_GEN
        assign s.tag = b_src.w_hv && !b_src.w_halt ? b_src.w_header.common1.pcieTag[P_TAGWD-1:0] : r.tag ;
      end
    endgenerate

    assign b_tag.w_tag  = s.tag ;
    assign b_tag.w_pop  = (b_src.w_hv || b_src.w_dv) && b_src.w_eot && !b_src.w_halt && b_src.w_header.common4.cpl_last && s.isSrcCpl;
    assign b_tag.w_peek = b_src.w_hv && !b_src.w_halt && s.isSrcCpl;
    assign b_tag.w_halt = !(s_wasTagRequested || s_wasTagPopped) || b_dst.w_halt;

// SNPS_SysML_CODE_END

endmodule
