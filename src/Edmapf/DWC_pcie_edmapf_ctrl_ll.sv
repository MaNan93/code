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
// ---    $DateTime: 2023/09/27 02:27:25 $ 
// ---    $Revision: #7 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ll.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_push_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_pop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llFetchNtfy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ChRegfile_DB_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_HubDbOp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_fslots_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvOpData_if.svh"
// SNPS_SysML_CODE_START
`include "Edmapf/svif/DWC_pcie_edmapf_readyValid_if.svh"
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ll
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       type P_CTXPIPE_TYPE = logic
  ,parameter           type P_CTX_TYPE = logic
  ,parameter    type P_DBMNGR_REM_TYPE = logic
  ,parameter      type P_LLQ_PUSH_TYPE = logic
  ,parameter         type P_LLRAM_TYPE = logic
  ,parameter       type P_LL_PUSH_TYPE = logic
  ,parameter     type P_POPCTX_LL_TYPE = logic
  ,parameter    type P_PUSHCTX_LL_TYPE = logic
  ,parameter            type P_TLPTYPE = logic
  ,parameter CC_IF_CTRL_LL_RAM_LATENCY = 1
  ,parameter      CC_IF_CTRL_LL_RAM_WD = 256
  ,parameter     CC_NUM_DMA_CHAN_WIDTH = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter                CX_DMA_LLQ = 4
  ,parameter           CX_NUM_DMA_CHAN = `CX_NUM_DMA_WR_CHAN
  ,parameter    dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_pop_if.slave_mp           b_ChDbFifo
  ,DWC_pcie_edmapf_genericData_if.master_mp  b_ChDbRemSlt
  ,DWC_pcie_edmapf_ChRegfile_DB_if.master_mp b_ChStop
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp       b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp         b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp           b_cpl_ll
  ,DWC_pcie_edmapf_crgb_if.slave_mp          b_crgb
  ,DWC_pcie_edmapf_genericData_if.slave_mp   b_ctxGlb
  ,DWC_pcie_edmapf_llFetchNtfy_if.master_mp  b_llFetchNtfy
  ,DWC_pcie_edmapf_HubDbOp_if.master_mp      b_llHubNtfy
  ,DWC_pcie_edmapf_llq_push_if.master_mp     b_ll_push
  ,DWC_pcie_edmapf_ram2p_if.master_mp        b_ll_ram
  ,DWC_pcie_edmapf_tlp_if.master_mp          b_rd_ll
  ,DWC_pcie_edmapf_llq_fslots_if.slave_mp    b_slotsReport
  ,DWC_pcie_edmapf_rvOpData_if.slave_mp      b_token_push
  ,DWC_pcie_edmapf_rasdp_if.master_mp        b_ras
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_crPopRdy_if #(
     .P_DATATYPE(P_POPCTX_LL_TYPE)
    ,.P_TAGWD   (CC_NUM_DMA_CHAN_WIDTH)
                             )          b_DWC_pcie_edmapf_crPopRdy_if_0          ();
  DWC_pcie_edmapf_ctxPop_haltableRdy_if #(
     .P_DATATYPE(P_POPCTX_LL_TYPE)
    ,.P_TAGWD   (CC_NUM_DMA_CHAN_WIDTH)
                                       )b_DWC_pcie_edmapf_ctxPop_haltableRdy_if_0();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic[CX_NUM_DMA_CHAN-1:0])
                                )       b_DWC_pcie_edmapf_genericData_if_0       ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(P_POPCTX_LL_TYPE)
                                )       b_DWC_pcie_edmapf_genericData_if_1       ();
  DWC_pcie_edmapf_ram1p_if #(
     .PW(CC_NUM_DMA_CHAN_WIDTH)
    ,.WD(int'(32)*int'(3))
                          )             b_DWC_pcie_edmapf_ram1p_if_0             ();
  DWC_pcie_edmapf_ram1p_if #(
     .PW(CC_NUM_DMA_CHAN_WIDTH)
    ,.WD(int'(32)*int'(3))
                          )             b_DWC_pcie_edmapf_ram1p_if_1             ();
  DWC_pcie_edmapf_readyValid_if #(
     .P_DATATYPE(P_LLQ_PUSH_TYPE)
                               )        b_DWC_pcie_edmapf_readyValid_if_0        ();
  DWC_pcie_edmapf_readyValid_if #(
     .P_DATATYPE(P_LL_PUSH_TYPE)
                               )        b_DWC_pcie_edmapf_readyValid_if_1        ();
  DWC_pcie_edmapf_readyValid_if #(
     .P_DATATYPE(P_LL_PUSH_TYPE)
                               )        b_DWC_pcie_edmapf_readyValid_if_2        ();
  DWC_pcie_edmapf_readyValid_if #(
     .P_DATATYPE(P_LL_PUSH_TYPE)
                               )        b_DWC_pcie_edmapf_readyValid_if_3        ();
  DWC_pcie_edmapf_readyValid_if #(
     .P_DATATYPE(P_LLQ_PUSH_TYPE)
                               )        b_DWC_pcie_edmapf_readyValid_if_4        ();
  DWC_pcie_edmapf_readyValid_if #(
     .P_DATATYPE(P_LL_PUSH_TYPE)
                               )        b_DWC_pcie_edmapf_readyValid_if_5        ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )               b_DWC_pcie_edmapf_tlp_if_0               ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_rslice_dly
   #(
   .P_AUX_CLK (1)
  ,.P_DATATYPE(P_LLQ_PUSH_TYPE)
  ) u0nll_rdly (
   .b_dst         ( b_DWC_pcie_edmapf_readyValid_if_4.master_mp         )
  ,.b_src         ( b_DWC_pcie_edmapf_readyValid_if_0.slave_mp          )
  ,.b_clkrst      ( b_clk                                               )
  );

  DWC_pcie_edmapf_rslice_dly
   #(
   .P_DATATYPE(P_LL_PUSH_TYPE)
  ) u1ll_rdly (
   .b_dst         ( b_DWC_pcie_edmapf_readyValid_if_1.master_mp         )
  ,.b_src         ( b_DWC_pcie_edmapf_readyValid_if_5.slave_mp          )
  ,.b_clkrst      ( b_clk                                               )
  );

  DWC_pcie_edmapf_rslice_dly
   #(
   .P_DATATYPE(P_LL_PUSH_TYPE)
  ,.P_STAGES  (E_FEED_HALT)
  ) u2ll_rdly (
   .b_dst         ( b_DWC_pcie_edmapf_readyValid_if_2.master_mp         )
  ,.b_src         ( b_DWC_pcie_edmapf_readyValid_if_3.slave_mp          )
  ,.b_clkrst      ( b_clk                                               )
  );

  DWC_pcie_edmapf_ctrl_ll_cpl
   #(
   .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
  ,.CX_DMA_LLQ           (CX_DMA_LLQ)
  ,.CX_NUM_DMA_CHAN      (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL            (P_CHANNEL)
  ,.P_CTX_TYPE           (P_CTX_TYPE)
  ,.P_POPCTX_LL_TYPE     (P_POPCTX_LL_TYPE)
  ) u_cpl (
   .b_HubDbErr    ( b_DWC_pcie_edmapf_genericData_if_0.slave_mp         )
  ,.clk           ( b_clk                                               )
  ,.cpl_ll        ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp                 )
  ,.ctx           ( b_DWC_pcie_edmapf_genericData_if_1.slave_mp         )
  ,.ll_push       ( b_DWC_pcie_edmapf_readyValid_if_5.master_mp         )
  ,.b_ras         ( b_ras                                               )
  );

  DWC_pcie_edmapf_crgb
   #(
   .P_CHANNEL    (P_CHANNEL)
  ,.P_RAM        (E_HDMAREGZONE_LL)
  ,.P_RAM_ADDR_WD(CC_NUM_DMA_CHAN_WIDTH)
  ,.P_RAM_DATA_WD(int'(32)*int'(3))
  ) u_crgb (
   .b_clk         ( b_clk                                               )
  ,.b_crgb        ( b_crgb                                              )
  ,.b_ram         ( b_DWC_pcie_edmapf_ram1p_if_0.master_mp              )
  );

  DWC_pcie_edmapf_damper
   #(
   .P_DAMPER_DP  (CC_IF_CTRL_LL_RAM_LATENCY+ int'(7))
  ,.P_DATATYPE   (P_POPCTX_LL_TYPE)
  ,.P_POPTYPE_RDY(E_TRUE)
  ,.P_POPTYPE_REG(E_TRUE)
  ,.P_TAGWD      (CC_NUM_DMA_CHAN_WIDTH)
  ) u_damper (
   .b_pop         ( b_DWC_pcie_edmapf_crPopRdy_if_0.slave_mp            )
  ,.b_popHaltable ( b_DWC_pcie_edmapf_ctxPop_haltableRdy_if_0.master_mp )
  ,.b_clk         ( b_clk                                               )
  );

  DWC_pcie_edmapf_ctrl_ll_fetch
   #(
   .CC_IF_CTRL_LL_RAM_LATENCY(CC_IF_CTRL_LL_RAM_LATENCY)
  ,.CC_IF_CTRL_LL_RAM_WD     (CC_IF_CTRL_LL_RAM_WD)
  ,.CC_NUM_DMA_CHAN_WIDTH    (CC_NUM_DMA_CHAN_WIDTH)
  ,.CX_DMA_LLQ               (CX_DMA_LLQ)
  ,.CX_NUM_DMA_CHAN          (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL                (P_CHANNEL)
  ,.P_DBMNGR_REM_TYPE        (P_DBMNGR_REM_TYPE)
  ,.P_LLRAM_TYPE             (P_LLRAM_TYPE)
  ) u_fetch (
   .b_ChDbFifo    ( b_ChDbFifo                                          )
  ,.b_ChDbRemSlt  ( b_ChDbRemSlt                                        )
  ,.b_PushLLCtx   ( b_DWC_pcie_edmapf_readyValid_if_2.slave_mp          )
  ,.b_glbCtx      ( b_ctxGlb                                            )
  ,.b_llFetchNtfy ( b_llFetchNtfy                                       )
  ,.b_rd_ll       ( b_rd_ll                                             )
  ,.cdm           ( b_cdm                                               )
  ,.clk           ( b_clk                                               )
  ,.crgbdata      ( b_DWC_pcie_edmapf_ram1p_if_1.slave_mp               )
  ,.ll_ram        ( b_ll_ram                                            )
  ,.non_ll_push   ( b_DWC_pcie_edmapf_readyValid_if_0.master_mp         )
  ,.popCtx        ( b_DWC_pcie_edmapf_crPopRdy_if_0.master_mp           )
  );

  DWC_pcie_edmapf_ctrl_ll_hub
   #(
   .CX_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
  ,.P_CTXPIPE_TYPE (P_CTXPIPE_TYPE)
  ,.P_CTX_TYPE     (P_CTX_TYPE)
  ) u_hub (
   .b_ChStop      ( b_ChStop                                            )
  ,.b_HubDbErr    ( b_DWC_pcie_edmapf_genericData_if_0.master_mp        )
  ,.b_PushLLCtx   ( b_DWC_pcie_edmapf_readyValid_if_3.master_mp         )
  ,.b_clk         ( b_clk                                               )
  ,.b_llHubNtfy   ( b_llHubNtfy                                         )
  ,.b_ll_push     ( b_DWC_pcie_edmapf_readyValid_if_1.slave_mp          )
  ,.b_non_ll_push ( b_DWC_pcie_edmapf_readyValid_if_4.slave_mp          )
  ,.b_opush       ( b_ll_push                                           )
  ,.b_slotsReport ( b_slotsReport                                       )
  ,.b_token_push  ( b_token_push                                        )
  );

  DWC_pcie_edmapf_ram1p_delay
   #(
   .PW(CC_NUM_DMA_CHAN_WIDTH)
  ,.WD(int'(32)*int'(3))
  ) u_ram_reg (
   .b_clk         ( b_clk                                               )
  ,.b_iram        ( b_DWC_pcie_edmapf_ram1p_if_0.slave_mp               )
  ,.b_oram        ( b_DWC_pcie_edmapf_ram1p_if_1.master_mp              )
  );

  DWC_pcie_edmapf_ctrl_ll_tlpctx
   #(
   .CC_IF_CTRL_LL_RAM_LATENCY(CC_IF_CTRL_LL_RAM_LATENCY+ int'(7))
  ,.CX_NUM_DMA_CHAN          (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL                (P_CHANNEL)
  ,.P_POPCTX_LL_TYPE         (P_POPCTX_LL_TYPE)
  ,.P_TLPTYPE                (P_TLPTYPE)
  ) u_tlpctx (
   .clk           ( b_clk                                               )
  ,.ctx           ( b_DWC_pcie_edmapf_genericData_if_1.master_mp        )
  ,.pop           ( b_DWC_pcie_edmapf_ctxPop_haltableRdy_if_0.slave_mp  )
  ,.tlp_dst       ( b_DWC_pcie_edmapf_tlp_if_0.master_mp                )
  ,.tlp_src       ( b_cpl_ll                                            )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
