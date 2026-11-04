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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ll_tlpctx.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltableRdy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ll_tlpctx
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter     type P_POPCTX_LL_TYPE = logic
  ,parameter            type P_TLPTYPE = logic
  ,parameter CC_IF_CTRL_LL_RAM_LATENCY = 1
  ,parameter           CX_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter    dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp              clk
  ,DWC_pcie_edmapf_genericData_if.master_mp       ctx
  ,DWC_pcie_edmapf_ctxPop_haltableRdy_if.slave_mp pop
  ,DWC_pcie_edmapf_tlp_if.master_mp               tlp_dst
  ,DWC_pcie_edmapf_tlp_if.slave_mp                tlp_src
  );


// SNPS_SysML_CODE_START
  localparam LP_NUM_DMA_CHANWD = (CX_NUM_DMA_CHAN == 1) ? 1 : $clog2(CX_NUM_DMA_CHAN);


  DWC_pcie_edmapf_genericData_if s_enable();


  DWC_pcie_edmapf_genericData_if s_fFull();


  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                 ) s_dst ();

  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                 ) s_src ();

  DWC_pcie_edmapf_tlp_fifo
   #(
   .P_DEPTH  (CC_IF_CTRL_LL_RAM_LATENCY)
  ,.P_TLPTYPE(P_TLPTYPE)
  ,.P_DATAWD (K_COREBUSWD)
  ) u_tlp_fifo (
   .b_clkrst ( clk               )
  ,.b_dst    ( s_dst.master_mp   )
  ,.b_enable ( s_enable.slave_mp )
  ,.b_fFull  ( s_fFull.master_mp )
  ,.b_src    ( s_src.slave_mp    )
  );

 typedef enum logic[1:0] {
    E_TLP_HV = 0
   ,E_TLP_DV = 1
   ,E_TLP_NULL = 2
  } tlp_e;

  tlp_e tlp_dst_head_body;

  always_comb begin : PROC_cb_tlp_body
    unique case ({s_dst.w_hv, s_dst.w_dv})
      default:      tlp_dst_head_body = E_TLP_NULL;
      2'b10, 2'b11: tlp_dst_head_body = E_TLP_HV;
      2'b01:        tlp_dst_head_body = E_TLP_DV;
    endcase
  end


  assign pop.w_tag  = tlp_src.w_header.dma.channel[LP_NUM_DMA_CHANWD-1:0];
  // pop must only happen when FIFO is ready to accept the data
  assign pop.w_pop  = tlp_src.w_hv && !s_fFull.w_data;
  // pop.w_halt back pressures the pop.w_valid when TLP destinatin is busy
  assign pop.w_halt = (tlp_dst.w_eot && !tlp_dst.w_halt) ? '0 : '1; 

  assign tlp_dst.w_hv  = (((tlp_dst_head_body == E_TLP_HV ) && pop.w_valid));
  assign tlp_dst.w_dv  = (((tlp_dst_head_body == E_TLP_HV ) && pop.w_valid) || (tlp_dst_head_body == E_TLP_DV)) && s_dst.w_dv;
  assign tlp_dst.w_eot = (((tlp_dst_head_body == E_TLP_HV ) && pop.w_valid) || (tlp_dst_head_body == E_TLP_DV)) && s_dst.w_eot;

  assign s_dst.w_halt = !(
                          (tlp_dst.w_hv == s_dst.w_hv ) &&
                          (tlp_dst.w_dv == s_dst.w_dv ) &&
                          (tlp_dst.w_eot== s_dst.w_eot)
                          ) ||
                           tlp_dst.w_halt;

  assign tlp_dst.w_header = s_dst.w_header;
  assign tlp_dst.w_data   = s_dst.w_data;
  assign tlp_dst.w_headerProt = s_dst.w_headerProt;

  // Saves the context to be available during the streaming of the CPL
  // This is used when multiple descriptors are fetched on 1 go
  P_POPCTX_LL_TYPE r_ctx_data;
  always_ff @ (posedge clk.w_main_clk or negedge clk.w_reset_n) begin : PROC_FF_ctx
     if (!clk.w_reset_n) begin
        r_ctx_data <= # `TP P_POPCTX_LL_TYPE'(0);
    end else begin
        if (tlp_dst.w_hv)
          r_ctx_data <= # `TP pop.w_data;
    end
 end
  
  // The context is valid with the header valid of the TLP
  assign ctx.w_data = tlp_dst.w_hv ? pop.w_data : r_ctx_data;

  assign s_enable.w_data = !tlp_src.w_halt;

  assign s_src.w_data       = tlp_src.w_data      ;
  assign s_src.w_dv         = tlp_src.w_dv        ;
  assign s_src.w_eot        = tlp_src.w_eot       ;
  assign s_src.w_header     = tlp_src.w_header    ;
  assign s_src.w_hv         = tlp_src.w_hv        ;
  assign s_src.w_headerProt = tlp_src.w_headerProt;
  assign tlp_src.w_halt = s_fFull.w_data || (pop.w_pop && !pop.w_ready);
// SNPS_SysML_CODE_END

endmodule
