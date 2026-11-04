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
// ---    $Revision: #13 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl.sv#13 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_hard_stop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_status_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter           type P_C2W_TLPCTXTYPE = logic
  ,parameter             type P_CTXPIPE_TYPE = logic
  ,parameter                 type P_CTX_TYPE = logic
  ,parameter     type P_DBMNGR_ELPFETCH_TYPE = logic
  ,parameter          type P_DBMNGR_REM_TYPE = logic
  ,parameter              type P_DBMNGR_TYPE = logic
  ,parameter               type P_ERROR_TYPE = logic
  ,parameter                 type P_GLB_TYPE = logic
  ,parameter                 type P_INT_TYPE = logic
  ,parameter            type P_LLQ_PUSH_TYPE = logic
  ,parameter               type P_LLRAM_TYPE = logic
  ,parameter             type P_LL_PUSH_TYPE = logic
  ,parameter          type P_NARROWPIPE_TYPE = logic
  ,parameter                type P_OVRL_TYPE = logic
  ,parameter           type P_POPCTX_LL_TYPE = logic
  ,parameter          type P_PUSHCTX_LL_TYPE = logic
  ,parameter            type P_STSHPIPE_TYPE = logic
  ,parameter                  type P_TLPTYPE = logic
  ,parameter       CC_IF_CTRL_LL_RAM_LATENCY = 1
  ,parameter            CC_IF_CTRL_LL_RAM_WD = 255
  ,parameter           CC_NUM_DMA_CHAN_WIDTH = 4
  ,parameter                      CX_DMA_LLQ = 4
  ,parameter                 CX_NUM_DMA_CHAN = 16
  ,parameter                            P_BA = 0 +1
  ,parameter            P_CTXC2W_RAM_LATENCY = 1
  ,parameter           P_CTXSTSH_RAM_LATENCY = 1
  ,parameter        P_CTX_LLQ_OVERLAY_RAM_DP = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_DP
  ,parameter        P_CTX_LLQ_OVERLAY_RAM_PW = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW
  ,parameter        P_CTX_LLQ_OVERLAY_RAM_WD = `CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD
  ,parameter           P_LL_RAM_ADDR_PROT_WD = 2
  ,parameter           P_LL_RAM_DATA_PROT_WD = 2
  ,parameter                       P_MAXTAGS = 1024
  ,parameter          P_MSI_RAM_ADDR_PROT_WD = 2
  ,parameter          P_MSI_RAM_DATA_PROT_WD = 2
  ,parameter               P_MSI_RAM_LATENCY = 1
  ,parameter      P_MWR2ACK_RAM_ADDR_PROT_WD = 2
  ,parameter      P_MWR2ACK_RAM_DATA_PROT_WD = 2
  ,parameter         P_OVRL_RAM_ADDR_PROT_WD = 2
  ,parameter         P_OVRL_RAM_DATA_PROT_WD = 2
  ,parameter              P_OVRL_RAM_LATENCY = 1
  ,parameter      P_REQ2CPL_RAM_ADDR_PROT_WD = 2
  ,parameter      P_REQ2CPL_RAM_DATA_PROT_WD = 2
  ,parameter                   P_TLP_DATA_WD = 32
  ,parameter          dmaEngType_e P_CHANNEL = E_WRITE
  ,parameter       P_LL_RAM_RAS_CHK_ID       = RAS_CHK_ID_RAM_WR_LL
  ,parameter       P_OVRL_RAM_RAS_CHK_ID     = RAS_CHK_ID_RAM_WR_LLQ
  ,parameter       P_REQ2CPL_RAM_RAS_CHK_ID  = RAS_CHK_ID_RAM_WR_C2WLUT
  ,parameter       P_MWR2ACK_RAM_RAS_CHK_ID  = RAS_CHK_ID_RAM_WR_STSHLUT
  ,parameter       P_MSI_RAM_RAS_CHK_ID      = RAS_CHK_ID_RAM_WR_MSI
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_ram2p_standard_if.master_mp b_c2w_lut_ram
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp         b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp            b_crgb
  ,DWC_pcie_edmapf_wack_if.slave_mp            b_data_ack
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_data_cpl
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_data_req
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_data_wr
  ,DWC_pcie_edmapf_hard_stop_if.slave_mp       b_hard_stop
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_ll_cpl
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_ll_ram
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_ll_req
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_msi
  ,DWC_pcie_edmapf_wack_if.slave_mp            b_msi_ack
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_msi_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_ovrl_ram
  ,DWC_pcie_edmapf_status_if.master_mp         b_status
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_stsh_lut_ram
  ,DWC_pcie_edmapf_rasdp_if.master_mp          b_ras
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_CTXPIPE_WD = $bits(P_CTXPIPE_TYPE)                          ;
    localparam N_CTRL_CHK = 7                                              ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_ChRegfile_DB_if #(
     .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
                                 )   b_DWC_pcie_edmapf_ChRegfile_DB_if_0   ();
  DWC_pcie_edmapf_HubDbOp_if #(
     .CC_NUM_DMA_CHAN      (CX_NUM_DMA_CHAN)
    ,.CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.CX_DMA_LLQ           (CX_DMA_LLQ)
    ,.P_ELPFETCH_TYPE      (P_DBMNGR_ELPFETCH_TYPE)
                            )        b_DWC_pcie_edmapf_HubDbOp_if_0        ();
  DWC_pcie_edmapf_crgb_if            b_DWC_pcie_edmapf_crgb_if_0           ();
  DWC_pcie_edmapf_crgb_if            b_DWC_pcie_edmapf_crgb_if_1           ();
  DWC_pcie_edmapf_crgb_if            b_DWC_pcie_edmapf_crgb_if_2           ();
  DWC_pcie_edmapf_crgb_if            b_DWC_pcie_edmapf_crgb_if_3           ();
  DWC_pcie_edmapf_crgb_if            b_DWC_pcie_edmapf_crgb_if_4           ();
  DWC_pcie_edmapf_ctxPop_haltable_if #(
     .P_DATATYPE /* P_CTXPIPE_TYPE */(P_CTXPIPE_TYPE)
    ,.P_TAGWD /* $clog2(P_MAXTAGS) */($clog2(P_MAXTAGS))
                                    )b_DWC_pcie_edmapf_ctxPop_haltable_if_0();
  DWC_pcie_edmapf_ctxPop_haltable_if #(
     .P_DATATYPE /* P_CTXPIPE_TYPE */(P_CTXPIPE_TYPE)
    ,.P_TAGWD /* $clog2(P_MAXTAGS) */($clog2(P_MAXTAGS))
                                    )b_DWC_pcie_edmapf_ctxPop_haltable_if_1();
  DWC_pcie_edmapf_ctxPush_if #(
     .P_DATATYPE /* P_NARROWPIPE_TYPE */(P_NARROWPIPE_TYPE)
    ,.P_TAGWD /* $clog2(P_MAXTAGS) */   ($clog2(P_MAXTAGS))
                            )        b_DWC_pcie_edmapf_ctxPush_if_0        ();
  DWC_pcie_edmapf_ctxPush_if #(
     .P_DATATYPE /* P_NARROWPIPE_TYPE */(P_NARROWPIPE_TYPE)
    ,.P_TAGWD /* $clog2(P_MAXTAGS) */   ($clog2(P_MAXTAGS))
                            )        b_DWC_pcie_edmapf_ctxPush_if_1        ();
  DWC_pcie_edmapf_dbNtfy_if #(
     .P_CHAN /*CX_NUM_DMA_CHAN*/          (CX_NUM_DMA_CHAN)
    ,.P_CHANWD /* CC_NUM_DMA_CHAN_WIDTH */(CC_NUM_DMA_CHAN_WIDTH)
                           )         b_DWC_pcie_edmapf_dbNtfy_if_0         ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_0    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(glbData_s [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_1    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(glbData_s [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_2    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_3    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_4    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(glbData_s [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_5    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_6    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(P_DBMNGR_REM_TYPE)
                                )    b_DWC_pcie_edmapf_genericData_if_7    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(glbData_s [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_8    ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(glbData_s [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_9    ();
DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [CX_NUM_DMA_CHAN-1:0])
                                )    b_DWC_pcie_edmapf_genericData_if_10   ();
  DWC_pcie_edmapf_llFetchNtfy_if #(
     .CC_NUM_DMA_CHAN      (CX_NUM_DMA_CHAN)
    ,.CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
                                )    b_DWC_pcie_edmapf_llFetchNtfy_if_0    ();
  DWC_pcie_edmapf_llq_fslots_if #(
     .CC_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
    ,.CX_DMA_LLQ     (CX_DMA_LLQ)
                               )     b_DWC_pcie_edmapf_llq_fslots_if_0     ();
  DWC_pcie_edmapf_llq_pop_if #(
     .CC_NUM_DMA_CHAN      (CX_NUM_DMA_CHAN)
    ,.CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.CX_DMA_LLQ           (CX_DMA_LLQ)
    ,.P_CTX_TYPE           (P_CTX_TYPE)
    ,.P_OVRL_TYPE          (P_OVRL_TYPE)
                            )        b_DWC_pcie_edmapf_llq_pop_if_0        ();
  DWC_pcie_edmapf_llq_push_if #(
     .CC_NUM_DMA_CHAN_WIDTH(CC_NUM_DMA_CHAN_WIDTH)
    ,.P_CTX_TYPE           (P_CTX_TYPE)
                             )       b_DWC_pcie_edmapf_llq_push_if_0       ();
  DWC_pcie_edmapf_nullInjection_if #(
     .P_MAXTAGS  (P_MAXTAGS)
    ,.P_NUM_CH   (CX_NUM_DMA_CHAN)
    ,.P_NUM_CH_WD(CC_NUM_DMA_CHAN_WIDTH)
                                  )  b_DWC_pcie_edmapf_nullInjection_if_0  ();
  DWC_pcie_edmapf_nullInjection_if #(
     .P_MAXTAGS  (P_MAXTAGS)
    ,.P_NUM_CH   (CX_NUM_DMA_CHAN)
    ,.P_NUM_CH_WD(CC_NUM_DMA_CHAN_WIDTH)
                                  )  b_DWC_pcie_edmapf_nullInjection_if_1  ();
  DWC_pcie_edmapf_pop_if #(
     .P_DATATYPE(P_DBMNGR_TYPE)
                        )            b_DWC_pcie_edmapf_pop_if_0            ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(P_CTX_LLQ_OVERLAY_RAM_DP)
    ,.PW(P_CTX_LLQ_OVERLAY_RAM_PW)
    ,.WD($bits(fetchQ_s))
                          )          b_DWC_pcie_edmapf_ram2p_if_0          ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(CX_NUM_DMA_CHAN)
    ,.PW(CC_NUM_DMA_CHAN_WIDTH)
    ,.WD($bits(msiInfo_s))
                          )          b_DWC_pcie_edmapf_ram2p_if_1          ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(P_MAXTAGS)
    ,.PW($clog2(P_MAXTAGS))
    ,.WD($bits(P_NARROWPIPE_TYPE))
                          )          b_DWC_pcie_edmapf_ram2p_if_2          ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(CX_NUM_DMA_CHAN)
    ,.PW(CC_NUM_DMA_CHAN_WIDTH)
    ,.WD(CC_IF_CTRL_LL_RAM_WD)
                          )          b_DWC_pcie_edmapf_ram2p_if_3          ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(P_MAXTAGS)
    ,.PW($clog2(P_MAXTAGS))
    ,.WD($bits(P_NARROWPIPE_TYPE))
                          )          b_DWC_pcie_edmapf_ram2p_if_4          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_0          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_1          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_2          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_3          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_4          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_5          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_6          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_7          ();
  DWC_pcie_edmapf_rasdp_if           b_DWC_pcie_edmapf_rasdp_if_8          ();
  ras_dp_err_log_t [N_CTRL_CHK-1:0]  ctrl_ras_dp_err_logs;
  ras_dp_err_inj_t                   ctrl_ras_dp_err_inj;
  DWC_pcie_edmapf_rvData_if #(
     .P_DATATYPE(P_CTXPIPE_TYPE)
                           )         b_DWC_pcie_edmapf_rvData_if_0         ();
  DWC_pcie_edmapf_rvOpData_if #(
     .P_DATATYPE(P_CTXPIPE_TYPE)
    ,.P_OPTYPE  (llPushOp_e)
                             )       b_DWC_pcie_edmapf_rvOpData_if_0       ();
  DWC_pcie_edmapf_tagMngr_cfg_if     b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u  ();
  DWC_pcie_edmapf_tagMngr_cfg_if     b_DWC_pcie_edmapf_tagMngr_cfg_if_1_u  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )            b_DWC_pcie_edmapf_tlp_if_0            ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )            b_DWC_pcie_edmapf_tlp_if_1            ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )            b_DWC_pcie_edmapf_tlp_if_2            ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )            b_DWC_pcie_edmapf_tlp_if_3            ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )            b_DWC_pcie_edmapf_tlp_if_4            ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )            b_DWC_pcie_edmapf_tlp_if_5            ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD ($clog2(P_MAXTAGS))
                         )           b_DWC_pcie_edmapf_wack_if_0           ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_ctrl_cpl2mwr
   #(
   .P_C2W_BUFF_DP /* P_CTXC2W_RAM_LATENCY+4 */(P_CTXC2W_RAM_LATENCY+4)
  ,.P_CHAN /* CX_NUM_DMA_CHAN */              (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL                                 (P_CHANNEL)
  ,.P_CTXTYPE /* P_CTXPIPE_TYPE */            (P_CTXPIPE_TYPE)
  ,.P_TLPCTXTYPE /* P_C2W_TLPCTXTYPE */       (P_C2W_TLPCTXTYPE)
  ) u_cpl2mwr (
   .b_cdm             ( b_cdm                                            )
  ,.b_clk             ( b_clk                                            )
  ,.b_cpl             ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp              )
  ,.b_ctxPop          ( b_DWC_pcie_edmapf_ctxPop_haltable_if_1.slave_mp  )
  ,.b_ctxPush         ( b_DWC_pcie_edmapf_ctxPush_if_0.master_mp         )
  ,.b_mwr             ( b_DWC_pcie_edmapf_tlp_if_2.master_mp             )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_7.master_mp           )
  );

  DWC_pcie_edmapf_crgb_1to5_rtr
  
    u_crgb_rtr (
   .b_in              ( b_crgb                                           )
  ,.b_out1            ( b_DWC_pcie_edmapf_crgb_if_1.master_mp            )
  ,.b_out2            ( b_DWC_pcie_edmapf_crgb_if_2.master_mp            )
  ,.b_out3            ( b_DWC_pcie_edmapf_crgb_if_0.master_mp            )
  ,.b_out4            ( b_DWC_pcie_edmapf_crgb_if_4.master_mp            )
  ,.b_out5            ( b_DWC_pcie_edmapf_crgb_if_3.master_mp            )
  );

  DWC_pcie_edmapf_ctrl_dbMngr
   #(
   .CC_IF_CTRL_LL_RAM_LATENCY(CC_IF_CTRL_LL_RAM_LATENCY)
  ,.CC_IF_CTRL_LL_RAM_WD     (CC_IF_CTRL_LL_RAM_WD)
  ,.CC_NUM_DMA_CHAN_WIDTH    (CC_NUM_DMA_CHAN_WIDTH)
  ,.CX_DMA_LLQ               (CX_DMA_LLQ)
  ,.CX_NUM_DMA_CHAN          (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL                (P_CHANNEL)
  ,.P_DBMNGR_ELPFETCH_TYPE   (P_DBMNGR_ELPFETCH_TYPE)
  ,.P_DBMNGR_REM_TYPE        (P_DBMNGR_REM_TYPE)
  ,.P_DBMNGR_TYPE            (P_DBMNGR_TYPE)
  ) u_dbMngr (
   .b_ChDbFifo        ( b_DWC_pcie_edmapf_pop_if_0.master_mp             )
  ,.b_ChDbRemSlt      ( b_DWC_pcie_edmapf_genericData_if_7.slave_mp      )
  ,.b_ChStop          ( b_DWC_pcie_edmapf_ChRegfile_DB_if_0.slave_mp     )
  ,.b_clk             ( b_clk                                            )
  ,.b_crgb            ( b_DWC_pcie_edmapf_crgb_if_1.slave_mp             )
  ,.b_ctxGlb          ( b_DWC_pcie_edmapf_genericData_if_1.slave_mp      )
  ,.b_doorbellPulse   ( b_DWC_pcie_edmapf_dbNtfy_if_0.master_mp          )
  ,.b_hwStop_active   ( b_DWC_pcie_edmapf_genericData_if_4.slave_mp      )
  ,.b_llFetchNtfy     ( b_DWC_pcie_edmapf_llFetchNtfy_if_0.slave_mp      )
  ,.b_llHubNtfy       ( b_DWC_pcie_edmapf_HubDbOp_if_0.slave_mp          )
  ,.b_stsh2ctx_update ( b_DWC_pcie_edmapf_rvData_if_0.slave_mp           )
  ,.b_swStop          ( b_DWC_pcie_edmapf_genericData_if_0.master_mp     )
  ,.b_token_push      ( b_DWC_pcie_edmapf_rvOpData_if_0.master_mp        )
  ,.b_swStopPulse     ( b_DWC_pcie_edmapf_genericData_if_10.master_mp    )
  );

  DWC_pcie_edmapf_ctrl_fetchQ
   #(
   .CC_NUM_DMA_CHAN         (CX_NUM_DMA_CHAN)
  ,.CC_NUM_DMA_CHAN_WIDTH   (CC_NUM_DMA_CHAN_WIDTH)
  ,.CX_DMA_LLQ              (CX_DMA_LLQ)
  ,.P_CHANNEL               (P_CHANNEL)
  ,.P_CTX_LLQ_OVERLAY_RAM_DP(P_CTX_LLQ_OVERLAY_RAM_DP)
  ,.P_CTX_LLQ_OVERLAY_RAM_PW(P_CTX_LLQ_OVERLAY_RAM_PW)
  ,.P_CTX_LLQ_OVERLAY_RAM_WD(P_CTX_LLQ_OVERLAY_RAM_WD)
  ,.P_CTX_TYPE              (P_CTX_TYPE)
  ,.P_ERROR_TYPE            (P_ERROR_TYPE)
  ,.P_OVRL_TYPE             (P_OVRL_TYPE)
  ,.P_PIPELINE              (P_OVRL_RAM_LATENCY)
  ) u_fetchQ (
   .clk               ( b_clk                                            )
  ,.crgb              ( b_DWC_pcie_edmapf_crgb_if_0.slave_mp             )
  ,.ctx_ovrl_ram      ( b_DWC_pcie_edmapf_ram2p_if_0.master_mp           )
  ,.glbCtx            ( b_DWC_pcie_edmapf_genericData_if_5.slave_mp      )
  ,.pop               ( b_DWC_pcie_edmapf_llq_pop_if_0.master_mp         )
  ,.push              ( b_DWC_pcie_edmapf_llq_push_if_0.slave_mp         )
  ,.slotsReport       ( b_DWC_pcie_edmapf_llq_fslots_if_0.master_mp      )
  );

  DWC_pcie_edmapf_ctrl_glbCtx
   #(
   .CX_NUM_DMA_CHAN(CX_NUM_DMA_CHAN)
  ,.P_CHANNEL      (P_CHANNEL)
  ,.P_GLB_TYPE     (P_GLB_TYPE)
  ) u_glbCtx (
   .b_clk             ( b_clk                                            )
  ,.b_crgb            ( b_DWC_pcie_edmapf_crgb_if_3.slave_mp             )
  ,.b_glbCtxC2W       ( b_DWC_pcie_edmapf_genericData_if_8.master_mp     )
  ,.b_glbCtxDbm       ( b_DWC_pcie_edmapf_genericData_if_1.master_mp     )
  ,.b_glbCtxFetchQ    ( b_DWC_pcie_edmapf_genericData_if_5.master_mp     )
  ,.b_glbCtxLLCtrl    ( b_DWC_pcie_edmapf_genericData_if_9.master_mp     )
  ,.b_glbCtxStsh      ( b_DWC_pcie_edmapf_genericData_if_2.master_mp     )
  );

  DWC_pcie_edmapf_ctrl_hardStopMngr
   #(
   .P_CHAN  (CX_NUM_DMA_CHAN)
  ,.P_CHANWD(CC_NUM_DMA_CHAN_WIDTH)
  ) u_hardStopMngr (
   .b_channelRunning  ( b_DWC_pcie_edmapf_genericData_if_6.slave_mp      )
  ,.b_clk             ( b_clk                                            )
  ,.b_data_cpl_in     ( b_data_cpl                                       )
  ,.b_data_cpl_out    ( b_DWC_pcie_edmapf_tlp_if_4.master_mp             )
  ,.b_hwStop_active   ( b_DWC_pcie_edmapf_genericData_if_4.master_mp     )
  ,.b_hwStop_injected ( b_DWC_pcie_edmapf_genericData_if_3.master_mp     )
  ,.b_hwStop_req      ( b_hard_stop                                      )
  ,.b_ll_cpl_in       ( b_ll_cpl                                         )
  ,.b_ll_cpl_out      ( b_DWC_pcie_edmapf_tlp_if_5.master_mp             )
  ,.b_swStopPulse     ( b_DWC_pcie_edmapf_genericData_if_10.slave_mp     )
  );

  DWC_pcie_edmapf_ctrl_ll
   #(
   .CC_IF_CTRL_LL_RAM_LATENCY(CC_IF_CTRL_LL_RAM_LATENCY)
  ,.CC_IF_CTRL_LL_RAM_WD     (CC_IF_CTRL_LL_RAM_WD)
  ,.CC_NUM_DMA_CHAN_WIDTH    (CC_NUM_DMA_CHAN_WIDTH)
  ,.CX_DMA_LLQ               (CX_DMA_LLQ)
  ,.CX_NUM_DMA_CHAN          (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL                (P_CHANNEL)
  ,.P_CTXPIPE_TYPE           (P_CTXPIPE_TYPE)
  ,.P_CTX_TYPE               (P_CTX_TYPE)
  ,.P_DBMNGR_REM_TYPE        (P_DBMNGR_REM_TYPE)
  ,.P_LLQ_PUSH_TYPE          (P_LLQ_PUSH_TYPE)
  ,.P_LLRAM_TYPE             (P_LLRAM_TYPE)
  ,.P_LL_PUSH_TYPE           (P_LL_PUSH_TYPE)
  ,.P_POPCTX_LL_TYPE         (P_POPCTX_LL_TYPE)
  ,.P_PUSHCTX_LL_TYPE        (P_PUSHCTX_LL_TYPE)
  ,.P_TLPTYPE                (P_TLPTYPE)
  ) u_ll (
   .b_ChDbFifo        ( b_DWC_pcie_edmapf_pop_if_0.slave_mp              )
  ,.b_ChDbRemSlt      ( b_DWC_pcie_edmapf_genericData_if_7.master_mp     )
  ,.b_ChStop          ( b_DWC_pcie_edmapf_ChRegfile_DB_if_0.master_mp    )
  ,.b_cdm             ( b_cdm                                            )
  ,.b_clk             ( b_clk                                            )
  ,.b_cpl_ll          ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp              )
  ,.b_crgb            ( b_DWC_pcie_edmapf_crgb_if_2.slave_mp             )
  ,.b_ctxGlb          ( b_DWC_pcie_edmapf_genericData_if_9.slave_mp      )
  ,.b_llFetchNtfy     ( b_DWC_pcie_edmapf_llFetchNtfy_if_0.master_mp     )
  ,.b_llHubNtfy       ( b_DWC_pcie_edmapf_HubDbOp_if_0.master_mp         )
  ,.b_ll_push         ( b_DWC_pcie_edmapf_llq_push_if_0.master_mp        )
  ,.b_ll_ram          ( b_DWC_pcie_edmapf_ram2p_if_3.master_mp           )
  ,.b_rd_ll           ( b_ll_req                                         )
  ,.b_slotsReport     ( b_DWC_pcie_edmapf_llq_fslots_if_0.slave_mp       )
  ,.b_token_push      ( b_DWC_pcie_edmapf_rvOpData_if_0.slave_mp         )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_5.master_mp           )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP            (CX_NUM_DMA_CHAN)
  ,.PW            (CC_NUM_DMA_CHAN_WIDTH)
  ,.P_ADDR_PROT_WD(P_LL_RAM_ADDR_PROT_WD)
  ,.P_CLK_G       (E_FALSE)
  ,.P_DATA_PROT_WD(P_LL_RAM_DATA_PROT_WD)
  ,.P_PIPELINE    (CC_IF_CTRL_LL_RAM_LATENCY)
  ,.RAS_DP_PROT_CHK_ID (P_LL_RAM_RAS_CHK_ID) 
  ,.WD            (CC_IF_CTRL_LL_RAM_WD)
  ) u_ll_ramAdapter (
   .b_clk             ( b_clk                                            )
  ,.b_external        ( b_ll_ram                                         )
  ,.b_internal        ( b_DWC_pcie_edmapf_ram2p_if_3.slave_mp            )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp           )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP            (CX_NUM_DMA_CHAN)
  ,.PW            (CC_NUM_DMA_CHAN_WIDTH)
  ,.P_ADDR_PROT_WD(P_MSI_RAM_ADDR_PROT_WD)
  ,.P_CLK_G       (E_FALSE)
  ,.P_DATA_PROT_WD(P_MSI_RAM_DATA_PROT_WD)
  ,.P_PIPELINE    (P_MSI_RAM_LATENCY)
  ,.RAS_DP_PROT_CHK_ID (P_MSI_RAM_RAS_CHK_ID)
  ,.WD            ($bits(msiInfo_s))
  ) u_msi_ramAdapter (
   .b_clk             ( b_clk                                            )
  ,.b_external        ( b_msi_ram                                        )
  ,.b_internal        ( b_DWC_pcie_edmapf_ram2p_if_1.slave_mp            )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp           )
  );

  DWC_pcie_edmapf_ctrl_ctx
   #(
   .P_DAMPER_DP(P_CTXSTSH_RAM_LATENCY+int'(3))
  ,.P_DATATYPE (P_NARROWPIPE_TYPE)
  ,.P_MAXTAGS  (P_MAXTAGS)
  ) u_mwr2ack_ctx (
   .b_cfg             ( b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u.slave_mp    )
  ,.b_clk             ( b_clk                                            )
  ,.b_glbCtx          ( b_DWC_pcie_edmapf_genericData_if_2.slave_mp      )
  ,.b_memAccess       ( b_DWC_pcie_edmapf_ram2p_if_4.master_mp           )
  ,.b_pop             ( b_DWC_pcie_edmapf_ctxPop_haltable_if_0.master_mp )
  ,.b_push            ( b_DWC_pcie_edmapf_ctxPush_if_0.slave_mp          )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP            (P_MAXTAGS)
  ,.PW            ($clog2(P_MAXTAGS))
  ,.P_ADDR_PROT_WD(P_MWR2ACK_RAM_ADDR_PROT_WD)
  ,.P_DATA_PROT_WD(P_MWR2ACK_RAM_DATA_PROT_WD)
  ,.P_PIPELINE    (P_CTXSTSH_RAM_LATENCY)
  ,.RAS_DP_PROT_CHK_ID (P_MWR2ACK_RAM_RAS_CHK_ID)
  ,.WD            ($bits(P_NARROWPIPE_TYPE))
  ) u_mwr2ack_ctx_ramAdapter (
   .b_clk             ( b_clk                                            )
  ,.b_external        ( b_stsh_lut_ram                                   )
  ,.b_internal        ( b_DWC_pcie_edmapf_ram2p_if_4.slave_mp            )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp           )
  );

  DWC_pcie_edmapf_ctrl_nullBRespInjection
   #(
   .P_MAXTAGS  (P_MAXTAGS)
  ,.P_NUM_CH   (CX_NUM_DMA_CHAN)
  ,.P_NUM_CH_WD(CC_NUM_DMA_CHAN_WIDTH)
  ) u_nullBRespInj (
   .b_clk             ( b_clk                                            )
  ,.b_dst             ( b_DWC_pcie_edmapf_wack_if_0.master_mp            )
  ,.b_nullHandler     ( b_DWC_pcie_edmapf_nullInjection_if_0.slave_mp    )
  ,.b_src             ( b_data_ack                                       )
  );

  DWC_pcie_edmapf_ctrl_nullCplInjection
   #(
   .P_MAXTAGS  (P_MAXTAGS)
  ,.P_NUM_CH   (CX_NUM_DMA_CHAN)
  ,.P_NUM_CH_WD(CC_NUM_DMA_CHAN_WIDTH)
  ) u_nullCplInj (
   .b_clk             ( b_clk                                            )
  ,.b_dst             ( b_DWC_pcie_edmapf_tlp_if_1.master_mp             )
  ,.b_nullHandler     ( b_DWC_pcie_edmapf_nullInjection_if_1.slave_mp    )
  ,.b_src             ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp              )
  );

  DWC_pcie_edmapf_ctrl_nullFilter
   #(
   .P_MAXTAGS  (P_MAXTAGS)
  ,.P_NUM_CH   (CX_NUM_DMA_CHAN)
  ,.P_NUM_CH_WD(CC_NUM_DMA_CHAN_WIDTH)
  ) u_nullRdFilter (
   .b_clk             ( b_clk                                            )
  ,.b_dst             ( b_data_req                                       )
  ,.b_nullHandler     ( b_DWC_pcie_edmapf_nullInjection_if_1.master_mp   )
  ,.b_src             ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp              )
  );

  DWC_pcie_edmapf_ctrl_nullFilter
   #(
   .P_MAXTAGS  (P_MAXTAGS)
  ,.P_NUM_CH   (CX_NUM_DMA_CHAN)
  ,.P_NUM_CH_WD(CC_NUM_DMA_CHAN_WIDTH)
  ) u_nullWrFilter (
   .b_clk             ( b_clk                                            )
  ,.b_dst             ( b_data_wr                                        )
  ,.b_nullHandler     ( b_DWC_pcie_edmapf_nullInjection_if_0.master_mp   )
  ,.b_src             ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp              )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP            (2**P_CTX_LLQ_OVERLAY_RAM_PW)
  ,.PW            (P_CTX_LLQ_OVERLAY_RAM_PW)
  ,.P_ADDR_PROT_WD(P_OVRL_RAM_ADDR_PROT_WD)
  ,.P_CLK_G       (E_FALSE)
  ,.P_DATA_PROT_WD(P_OVRL_RAM_DATA_PROT_WD)
  ,.P_PIPELINE    (P_OVRL_RAM_LATENCY)
  ,.RAS_DP_PROT_CHK_ID (P_OVRL_RAM_RAS_CHK_ID)
  ,.WD            ($bits(fetchQ_s))
  ) u_ovrl_ramAdapter (
   .b_clk             ( b_clk                                            )
  ,.b_external        ( b_ovrl_ram                                       )
  ,.b_internal        ( b_DWC_pcie_edmapf_ram2p_if_0.slave_mp            )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_6.master_mp           )
  );



  assign ctrl_ras_dp_err_logs = { b_DWC_pcie_edmapf_rasdp_if_7.w_ras_dp_err_log,
                                  b_DWC_pcie_edmapf_rasdp_if_6.w_ras_dp_err_log,
                                  b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_log,
                                  b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_log,
                                  b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_log,
                                  b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_log,
                                  b_DWC_pcie_edmapf_rasdp_if_5.w_ras_dp_err_log
                                 };  
  assign b_DWC_pcie_edmapf_rasdp_if_7.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_6.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_5.w_ras_dp_err_inj = ctrl_ras_dp_err_inj;
  
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = '0;

  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_CTRL_CHK         ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                  )
  ) u_ctrl_ras_dp_err_mgr (
    .clk                        (b_clk.w_aux_clk        )
   ,.rst_n                      (b_clk.w_reset_n        )
   ,.out_ras_dp_wake_up         (/*Not Connected*/      )
   ,.in_ras_dp_err_inj          (b_ras.w_ras_dp_err_inj )
   ,.out_ras_dp_err_inj         (ctrl_ras_dp_err_inj    )
  ,.in_ras_dp_err_log           (ctrl_ras_dp_err_logs   )
  ,.out_ras_dp_err_log          (b_ras.w_ras_dp_err_log )
  );


  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD    (K_COREBUSWD)
  ,.P_HEADERTYPE(xradm_s)
  ,.P_STAGES    (E_FEED_NONE)
  ,.P_TYPE      (E_TLP_FULL)
  ) u_rdReq_delay (
   .b_dst             ( b_DWC_pcie_edmapf_tlp_if_0.master_mp             )
  ,.b_src             ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp              )
  ,.b_clkrst          ( b_clk                                            )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp           )
  );

  DWC_pcie_edmapf_ctrl_ctx
   #(
   .P_DAMPER_DP(P_CTXC2W_RAM_LATENCY+int'(3))
  ,.P_DATATYPE (P_NARROWPIPE_TYPE)
  ,.P_MAXTAGS  (P_MAXTAGS)
  ) u_req2cpl_ctx (
   .b_cfg             ( b_DWC_pcie_edmapf_tagMngr_cfg_if_1_u.slave_mp    )
  ,.b_clk             ( b_clk                                            )
  ,.b_glbCtx          ( b_DWC_pcie_edmapf_genericData_if_8.slave_mp      )
  ,.b_memAccess       ( b_DWC_pcie_edmapf_ram2p_if_2.master_mp           )
  ,.b_pop             ( b_DWC_pcie_edmapf_ctxPop_haltable_if_1.master_mp )
  ,.b_push            ( b_DWC_pcie_edmapf_ctxPush_if_1.slave_mp          )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP            (P_MAXTAGS)
  ,.PW            ($clog2(P_MAXTAGS))
  ,.P_ADDR_PROT_WD(P_REQ2CPL_RAM_ADDR_PROT_WD)
  ,.P_DATA_PROT_WD(P_REQ2CPL_RAM_DATA_PROT_WD)
  ,.P_PIPELINE    (P_CTXC2W_RAM_LATENCY)
  ,.RAS_DP_PROT_CHK_ID (P_REQ2CPL_RAM_RAS_CHK_ID)
  ,.WD            ($bits(P_NARROWPIPE_TYPE))
  ) u_req2cpl_ctx_ramAdapter (
   .b_clk             ( b_clk                                            )
  ,.b_external        ( b_c2w_lut_ram                                    )
  ,.b_internal        ( b_DWC_pcie_edmapf_ram2p_if_2.slave_mp            )
  ,.b_ras             ( b_DWC_pcie_edmapf_rasdp_if_4.master_mp           )
  );

  DWC_pcie_edmapf_ctrl_req
   #(
   .CC_DMA_BA_ENABLE(P_BA)
  ,.CX_DMA_LLQ      (CX_DMA_LLQ)
  ,.CX_NUM_DMA_CHAN (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL       (P_CHANNEL)
  ,.P_CTXPIPE_TYPE  (P_CTXPIPE_TYPE)
  ,.P_CTX_TYPE      (P_CTX_TYPE)
  ,.P_OVRL_TYPE     (P_OVRL_TYPE)
  ) u_requester (
   .b_channelRunning  ( b_DWC_pcie_edmapf_genericData_if_6.slave_mp      )
  ,.b_swStop          ( b_DWC_pcie_edmapf_genericData_if_0.slave_mp      )
  ,.cdm               ( b_cdm                                            )
  ,.clk               ( b_clk                                            )
  ,.ll_pop            ( b_DWC_pcie_edmapf_llq_pop_if_0.slave_mp          )
  ,.rd_data           ( b_DWC_pcie_edmapf_tlp_if_3.master_mp             )
  ,.req_push          ( b_DWC_pcie_edmapf_ctxPush_if_1.master_mp         )
  );

  DWC_pcie_edmapf_ctrl_stsh
   #(
   .P_BA                                     (P_BA)
  ,.P_CHAN /* CX_NUM_DMA_CHAN */             (CX_NUM_DMA_CHAN)
  ,.P_CHANNEL /* P_CHANNEL */                (P_CHANNEL)
  ,.P_CTX_LAT /* 2*P_CTXSTSH_RAM_LATENCY+4 */(P_CTXSTSH_RAM_LATENCY+32'(4))
  ,.P_CTX_TYPE /* P_CTXPIPE_TYPE */          (P_CTXPIPE_TYPE)
  ,.P_INT_TYPE                               (P_INT_TYPE)
  ,.P_PIPE_TYPE /* P_STSHPIPE_TYPE */        (P_STSHPIPE_TYPE)
  ,.P_RAM_LAT /* 2*P_MSI_RAM_LATENCY+2 */    (P_MSI_RAM_LATENCY+32'(2))
  ,.P_TAGWD /* $clog2(P_MAXTAGS) */          ($clog2(P_MAXTAGS))
  ) u_stsh (
   .b_cdm             ( b_cdm                                            )
  ,.b_channelRunning  ( b_DWC_pcie_edmapf_genericData_if_6.master_mp     )
  ,.b_clk             ( b_clk                                            )
  ,.b_crgb            ( b_DWC_pcie_edmapf_crgb_if_4.slave_mp             )
  ,.b_ctxPop          ( b_DWC_pcie_edmapf_ctxPop_haltable_if_0.slave_mp  )
  ,.b_ctxPush         ( b_DWC_pcie_edmapf_rvData_if_0.master_mp          )
  ,.b_doorbell        ( b_DWC_pcie_edmapf_dbNtfy_if_0.slave_mp           )
  ,.b_hwStop          ( b_DWC_pcie_edmapf_genericData_if_3.slave_mp      )
  ,.b_msi             ( b_msi                                            )
  ,.b_msiAck          ( b_msi_ack                                        )
  ,.b_ram             ( b_DWC_pcie_edmapf_ram2p_if_1.master_mp           )
  ,.b_status          ( b_status                                         )
  ,.b_wrAck           ( b_DWC_pcie_edmapf_wack_if_0.slave_mp             )
  );

// SNPS_SysML_CODE_START
  assign b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u.w_update_p = '0;
  assign b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u.w_mode = E_TAGMNGR_NORMAL;
  assign b_DWC_pcie_edmapf_tagMngr_cfg_if_1_u.w_update_p = '0;
  assign b_DWC_pcie_edmapf_tagMngr_cfg_if_1_u.w_mode = E_TAGMNGR_NORMAL;
// SNPS_SysML_CODE_END

endmodule
