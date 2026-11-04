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
// ---    $Revision: #9 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_glbCtx_registers.sv#9 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_glbCtx_registers
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter        type P_GLB_TYPE = glbData_s
  ,parameter        CX_NUM_DMA_CHAN = `CC_NUM_DMA_WR_CHAN
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp        b_clk
  ,DWC_pcie_edmapf_ram1p_if.slave_mp        b_crgb
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxC2W
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxDbm
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxFetchQ
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxLLCtrl
  ,DWC_pcie_edmapf_genericData_if.master_mp b_glbCtxStsh
  );


// SNPS_SysML_CODE_START
  /*
     ---------------------------------------------------------------------------------------------------------------------------------------------------
     ||          || t_bit_src ||   t_bit   ||s_sn ||d_sn ||d_ats||          TLP Common           ||       tph       ||weight ||mtype||ll_en||pf_depth ||
     ||----------||-----------||-----------||-----||-----||-----||-------------------------------||-----------------||-------||-----||-----||---------||
     ||          || t_bit_src ||   t_bit   ||s_sn ||d_sn ||d_ats||d_ro |d_tc |d_pf |d_vf |d_vf_en||d_th |d_ph |d_st ||weight ||mtype||ll_en||pf_depth ||
     ||----------||-----------||-----------||-----||-----||-----||-----|-----|-----|-----|-------||-----|-----|-----||-------||-----||-----||---------||
     ||fetch ctrl||           ||     X     ||  X  ||     ||     ||  X  |  X  |  X  |  X  |   X   ||     |     |     ||       ||  X  ||  X  ||         || -> f_glbCtxLLCtrl
     ||----------||-----------||-----------||-----||-----||-----||-----|-----|-----|-----|-------||-----|-----|-----||-------||-----||-----||---------||
     ||db_mngr   ||           ||           ||     ||     ||     ||     |     |     |     |       ||     |     |     ||       ||     ||  X  ||         || -> f_glbCtxDbm
     ||----------||-----------||-----------||-----||-----||-----||-----|-----|-----|-----|-------||-----|-----|-----||-------||-----||-----||---------||
     ||requester ||           ||     X     ||  X  ||     ||  X  ||  X  |  X  |  X  |  X  |   X   ||     |     |     ||   X   ||  X  ||     ||    X    || -> f_glbCtxFetchQ
     ||----------||-----------||-----------||-----||-----||-----||-----|-----|-----|-----|-------||-----|-----|-----||-------||-----||-----||---------||
     ||cpl2mwr   ||     X     ||     X     ||     ||  X  ||  X  ||  X  |  X  |  X  |  X  |   X   ||  X  |  X  |  X  ||       ||  X  ||     ||         || -> f_glbCtxC2W
     ||----------||-----------||-----------||-----||-----||-----||-----|-----|-----|-----|-------||-----|-----|-----||-------||-----||-----||---------||
     ||stsh      ||           ||     X     ||     ||  X  ||  X  ||  X  |  X  |  X  |  X  |   X   ||     |     |     ||       ||     ||  X  ||         || -> f_glbCtxStsh
     ---------------------------------------------------------------------------------------------------------------------------------------------------
  */

  ////////////////////////////////////////////////////
  
  typedef struct packed {
    logic [9:0] pf_depth;
  } pf_depth_s;

  typedef struct packed {
    logic ll_en;
  } ll_en_s;

  typedef struct packed {
    logic mtype;
  } mtype_s;

  typedef struct packed {
    logic [4:0] weight   ;
  } weight_s;

  typedef struct packed {
    logic       d_th;
    logic [1:0] d_ph;
    logic [7:0] d_st;
  } tph_s;

  typedef struct packed {
    logic [7:0] d_pf   ;
    logic [2:0] d_tc   ;
    logic       d_ro   ;
  } tlpCommon_s;

  typedef struct packed {
    logic [1:0] d_ats  ;
  } d_ats_s;

  typedef struct packed {
    logic d_sn;
  } d_sn_s;

  typedef struct packed {
    logic s_sn;
  } s_sn_s;
  
  ////////////////////////////////////////////////////
  
  typedef struct packed {
    pf_depth_s  pf_depth ;
    ll_en_s     ll_en    ;
    mtype_s     mtype    ;
    weight_s    weight   ;
    tph_s       tph      ;
    tlpCommon_s tlpCommon;
    d_ats_s     d_ats    ;
    d_sn_s      d_sn     ;
    s_sn_s      s_sn     ;
  } glbCtx_s;

  ////////////////////////////////////////////////////
  
  glbCtx_s [CX_NUM_DMA_CHAN-1:0] r_glbCtx;

  /*
    Writing process of Global Context
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : s_b_glbCtx_PROC
    if (!b_clk.w_reset_n) begin
      foreach (r_glbCtx[i]) begin
        r_glbCtx[i] <= #`TP '{
           default : '0
          ,weight  : 5'b00001
          ,pf_depth: (P_CHANNEL == E_WRITE) ? `CC_HDMA_REG_WR_PF_DEPTH : `CC_HDMA_REG_RD_PF_DEPTH
        };
      end
      b_crgb.w_wdone  <= #`TP '0;
    end else begin
      if(b_crgb.w_wren) begin
        r_glbCtx[b_crgb.w_addr] <= #`TP f_storingGlbCtx(b_crgb.w_din);
        b_crgb.w_wdone          <= #`TP '1;
      end else begin
        b_crgb.w_wdone <= #`TP '0;
      end
    end
  end : s_b_glbCtx_PROC

  /*
    Reading process of Global Context
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : s_b_crgb_PROC
    if (!b_clk.w_reset_n) begin
      b_crgb.w_dout  <= #`TP '0;
      b_crgb.w_rdone <= #`TP '0;
    end else begin
      if(b_crgb.w_rden) begin
        b_crgb.w_dout  <= #`TP f_expandGlbCtx(r_glbCtx[b_crgb.w_addr]);
        b_crgb.w_rdone <= #`TP '1;
      end else begin
        b_crgb.w_dout  <= #`TP '0;
        b_crgb.w_rdone <= #`TP '0;
      end
    end
  end : s_b_crgb_PROC

  /*
    Assigning the internal register to the b_glbCtx interface
  */
  always_comb begin : c_b_glbCtx_PROC
    foreach(r_glbCtx[i]) begin
      b_glbCtxFetchQ.w_data[i] = f_glbCtxFetchQ(r_glbCtx[i]);
      b_glbCtxLLCtrl.w_data[i] = f_glbCtxLLCtrl(r_glbCtx[i]);
      b_glbCtxC2W.w_data[i]    = f_glbCtxC2W(r_glbCtx[i])   ;
      b_glbCtxStsh.w_data[i]   = f_glbCtxStsh(r_glbCtx[i])  ;
      b_glbCtxDbm.w_data[i]    = f_glbCtxDbm(r_glbCtx[i])   ;
    end
  end : c_b_glbCtx_PROC

  function automatic glbCtx_s f_storingGlbCtx(P_GLB_TYPE data);
    f_storingGlbCtx                     = '0                              ;
    f_storingGlbCtx.pf_depth.pf_depth   = data.pf_depth                   ;
    f_storingGlbCtx.weight.weight       = data.weight                     ;
    f_storingGlbCtx.ll_en.ll_en         = data.ll_en                      ;
    f_storingGlbCtx.mtype.mtype         = data.tlpSettings.mtype          ;
    f_storingGlbCtx.d_sn.d_sn           = data.tlpSettings.d_sn           ;
    f_storingGlbCtx.d_ats.d_ats         = data.tlpSettings.d_ats          ;
    f_storingGlbCtx.tlpCommon.d_pf      = data.tlpSettings.d_pf           ;
    f_storingGlbCtx.tlpCommon.d_tc      = data.tlpSettings.d_tc           ;
    f_storingGlbCtx.tlpCommon.d_ro      = data.tlpSettings.d_ro           ;
    f_storingGlbCtx.tph.d_th            = data.tlpSettings.d_th           ;
    f_storingGlbCtx.tph.d_ph            = data.tlpSettings.d_ph           ;
    f_storingGlbCtx.tph.d_st            = data.tlpSettings.d_st           ;
    f_storingGlbCtx.s_sn.s_sn           = data.tlpSettings.s_sn           ;
    return f_storingGlbCtx;
  endfunction

  function automatic P_GLB_TYPE f_expandGlbCtx(glbCtx_s data);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_expandGlbCtx                             = '0;
    f_expandGlbCtx.pf_depth                    = data.pf_depth.pf_depth   ;
    f_expandGlbCtx.weight                      = data.weight.weight       ;
    f_expandGlbCtx.ll_en                       = data.ll_en.ll_en         ;
    f_expandGlbCtx.tlpSettings.mtype           = data.mtype.mtype         ;
    f_expandGlbCtx.tlpSettings.d_sn            = data.d_sn.d_sn           ;
    f_expandGlbCtx.tlpSettings.d_ats           = data.d_ats.d_ats         ;
    f_expandGlbCtx.tlpSettings.d_pf            = data.tlpCommon.d_pf      ;
    f_expandGlbCtx.tlpSettings.d_tc            = data.tlpCommon.d_tc      ;
    f_expandGlbCtx.tlpSettings.d_ro            = data.tlpCommon.d_ro      ;
    f_expandGlbCtx.tlpSettings.d_th            = data.tph.d_th            ;
    f_expandGlbCtx.tlpSettings.d_ph            = data.tph.d_ph            ;
    f_expandGlbCtx.tlpSettings.d_st            = data.tph.d_st            ;
    f_expandGlbCtx.tlpSettings.s_sn            = data.s_sn.s_sn           ;
  // spyglass enable_block W239
    return f_expandGlbCtx;
  endfunction

  function automatic P_GLB_TYPE f_glbCtxFetchQ(glbCtx_s data);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_glbCtxFetchQ                             = '0                       ; 
    f_glbCtxFetchQ.pf_depth                    = data.pf_depth.pf_depth   ;
    f_glbCtxFetchQ.weight                      = data.weight.weight       ;
    f_glbCtxFetchQ.ll_en                       = data.ll_en.ll_en         ;
    f_glbCtxFetchQ.tlpSettings.mtype           = data.mtype.mtype         ;
    f_glbCtxFetchQ.tlpSettings.d_sn            = '0                       ;
    f_glbCtxFetchQ.tlpSettings.d_ats           = data.d_ats.d_ats         ;
    f_glbCtxFetchQ.tlpSettings.d_pf            = data.tlpCommon.d_pf      ;
    f_glbCtxFetchQ.tlpSettings.d_tc            = data.tlpCommon.d_tc      ;
    f_glbCtxFetchQ.tlpSettings.d_ro            = data.tlpCommon.d_ro      ;
    f_glbCtxFetchQ.tlpSettings.d_th            = '0                       ;
    f_glbCtxFetchQ.tlpSettings.d_ph            = '0                       ;
    f_glbCtxFetchQ.tlpSettings.d_st            = '0                       ;
    f_glbCtxFetchQ.tlpSettings.s_sn            = data.s_sn.s_sn           ;
  // spyglass enable_block W239
    return f_glbCtxFetchQ;
  endfunction

  function automatic P_GLB_TYPE f_glbCtxLLCtrl(glbCtx_s data);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_glbCtxLLCtrl                             = '0                       ;
    f_glbCtxLLCtrl.pf_depth                    = '0                       ;
    f_glbCtxLLCtrl.weight                      = '0                       ;
    f_glbCtxLLCtrl.ll_en                       = data.ll_en.ll_en         ;
    f_glbCtxLLCtrl.tlpSettings.mtype           = data.mtype.mtype         ;
    f_glbCtxLLCtrl.tlpSettings.d_sn            = '0                       ;
    f_glbCtxLLCtrl.tlpSettings.d_ats           = '0                       ;
    f_glbCtxLLCtrl.tlpSettings.d_pf            = data.tlpCommon.d_pf      ;
    f_glbCtxLLCtrl.tlpSettings.d_tc            = data.tlpCommon.d_tc      ;
    f_glbCtxLLCtrl.tlpSettings.d_ro            = data.tlpCommon.d_ro      ;
    f_glbCtxLLCtrl.tlpSettings.d_th            = '0                       ;
    f_glbCtxLLCtrl.tlpSettings.d_ph            = '0                       ;
    f_glbCtxLLCtrl.tlpSettings.d_st            = '0                       ;
    f_glbCtxLLCtrl.tlpSettings.s_sn            = data.s_sn.s_sn           ;
  // spyglass enable_block W239
    return f_glbCtxLLCtrl;
  endfunction

  function automatic P_GLB_TYPE f_glbCtxC2W(glbCtx_s data);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239                
    f_glbCtxC2W                               = '0                                       ;
    f_glbCtxC2W.pf_depth                      = '0                                       ;
    f_glbCtxC2W.weight                        = '0                                       ;
    f_glbCtxC2W.ll_en                         = '0                                       ;
    f_glbCtxC2W.tlpSettings.mtype             = data.mtype.mtype                         ;
    f_glbCtxC2W.tlpSettings.d_sn              = data.d_sn.d_sn                           ;
    f_glbCtxC2W.tlpSettings.d_ats             = data.d_ats.d_ats                         ;
    f_glbCtxC2W.tlpSettings.d_pf              = data.tlpCommon.d_pf                      ;
    f_glbCtxC2W.tlpSettings.d_tc              = data.tlpCommon.d_tc                      ;
    f_glbCtxC2W.tlpSettings.d_ro              = data.tlpCommon.d_ro                      ;
    f_glbCtxC2W.tlpSettings.d_th              = data.tph.d_th                            ;
    f_glbCtxC2W.tlpSettings.d_ph              = data.tph.d_ph                            ;
    f_glbCtxC2W.tlpSettings.d_st              = data.tph.d_st                            ;
    f_glbCtxC2W.tlpSettings.s_sn              = '0                                       ;
  // spyglass enable_block W239
    return f_glbCtxC2W;
  endfunction

  function automatic P_GLB_TYPE f_glbCtxStsh(glbCtx_s data);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_glbCtxStsh                              = '0                       ;
    f_glbCtxStsh.pf_depth                     = '0                       ;
    f_glbCtxStsh.weight                       = '0                       ;
    f_glbCtxStsh.ll_en                        = data.ll_en.ll_en         ;
    f_glbCtxStsh.tlpSettings.mtype            = '0                       ;
    f_glbCtxStsh.tlpSettings.d_sn             = data.d_sn.d_sn           ;
    f_glbCtxStsh.tlpSettings.d_ats            = data.d_ats.d_ats         ;
    f_glbCtxStsh.tlpSettings.d_pf             = data.tlpCommon.d_pf      ;
    f_glbCtxStsh.tlpSettings.d_tc             = data.tlpCommon.d_tc      ;
    f_glbCtxStsh.tlpSettings.d_ro             = data.tlpCommon.d_ro      ;
    f_glbCtxStsh.tlpSettings.d_th             = '0                       ;
    f_glbCtxStsh.tlpSettings.d_ph             = '0                       ;
    f_glbCtxStsh.tlpSettings.d_st             = '0                       ;
    f_glbCtxStsh.tlpSettings.s_sn             = '0                       ;
  // spyglass enable_block W239
    return f_glbCtxStsh;
  endfunction
  
  function automatic P_GLB_TYPE f_glbCtxDbm(glbCtx_s data);
  // SMD: Reports hierarchical references that are not synthesizable.
  // SJ:  The Spyglass cannot identify the type propagated by the parameter. It's a tool issue.
  // spyglass disable_block W239
    f_glbCtxDbm                              = '0               ;
    f_glbCtxDbm.pf_depth                     = '0               ;
    f_glbCtxDbm.weight                       = '0               ;
    f_glbCtxDbm.ll_en                        = data.ll_en.ll_en ;
    f_glbCtxDbm.tlpSettings.mtype            = '0               ;
    f_glbCtxDbm.tlpSettings.d_sn             = '0               ;
    f_glbCtxDbm.tlpSettings.d_ats            = '0               ;
    f_glbCtxDbm.tlpSettings.d_pf             = '0               ;
    f_glbCtxDbm.tlpSettings.d_tc             = '0               ;
    f_glbCtxDbm.tlpSettings.d_ro             = '0               ;
    f_glbCtxDbm.tlpSettings.d_th             = '0               ;
    f_glbCtxDbm.tlpSettings.d_ph             = '0               ;
    f_glbCtxDbm.tlpSettings.d_st             = '0               ;
    f_glbCtxDbm.tlpSettings.s_sn             = '0               ;
  // spyglass enable_block W239
    return f_glbCtxDbm;
  endfunction 
// SNPS_SysML_CODE_END

endmodule
