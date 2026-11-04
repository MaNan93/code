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
// ---    $Revision: #10 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_crgb_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_wresp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_header_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_hard_stop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_status_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_bypass_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf
  import DWC_pcie_edmapf_crgb_pkg::*;
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp         b_cdm
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_client0_in
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp            b_crgb
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_npReq_out
  ,DWC_pcie_edmapf_wack_if.master_mp           b_pReqOnPipe
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_pReq_out
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdBuffer_ram0
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_c2w_lut_ram
  ,DWC_pcie_edmapf_hard_stop_if.slave_mp       b_rdEng_hard_stop
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_ll_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_msi_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_ovrl_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_stsh_lut_ram
  ,DWC_pcie_edmapf_status_if.master_mp         b_status_rd
  ,DWC_pcie_edmapf_status_if.master_mp         b_status_wr
  ,DWC_pcie_edmapf_tlp_header_if.slave_mp      b_timeout
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_trgt_in
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_trgt_np_out
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_trgt_p_out
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_c2w_lut_ram
  ,DWC_pcie_edmapf_hard_stop_if.slave_mp       b_wrEng_hard_stop
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_ll_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_msi_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_ovrl_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_stsh_lut_ram
  ,DWC_pcie_edmapf_tlp_wresp_if.slave_mp       b_wresp
  ,DWC_pcie_edmapf_rasdp_if.master_mp          b_ras
  );
  
  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################
  
    localparam N_EDMA_PF_CHK = 4 ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_cdmregs_if b_DWC_pcie_edmapf_cdmregs_if_0();
  DWC_pcie_edmapf_crgb_if    b_DWC_pcie_edmapf_crgb_if_0   ();
  DWC_pcie_edmapf_crgb_if    b_DWC_pcie_edmapf_crgb_if_1   ();
  DWC_pcie_edmapf_crgb_if    b_DWC_pcie_edmapf_crgb_if_2   ();
  DWC_pcie_edmapf_ctxPush_if #(
     .P_DATATYPE(edmapf_dmatag_ch_s)
    ,.P_TAGWD   (K_TAGWD)
                            )b_DWC_pcie_edmapf_ctxPush_if_0();
  DWC_pcie_edmapf_rasdp_if   b_DWC_pcie_edmapf_rasdp_if_0  ();
  DWC_pcie_edmapf_rasdp_if   b_DWC_pcie_edmapf_rasdp_if_1  ();
  DWC_pcie_edmapf_rasdp_if   b_DWC_pcie_edmapf_rasdp_if_2  ();
  DWC_pcie_edmapf_rasdp_if   b_DWC_pcie_edmapf_rasdp_if_3  ();
  DWC_pcie_edmapf_rasdp_if   b_DWC_pcie_edmapf_rasdp_if_4  ();
  DWC_pcie_edmapf_rasdp_if   b_DWC_pcie_edmapf_rasdp_if_5  ();
  ras_dp_err_log_t [N_EDMA_PF_CHK-1:0] edmapf_ras_dp_err_logs;
  ras_dp_err_inj_t                     edmapf_ras_dp_err_inj;
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_0    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_1    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_2    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_3    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_4    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_5    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_6    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_7    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_8    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )    b_DWC_pcie_edmapf_tlp_if_9    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )   b_DWC_pcie_edmapf_tlp_if_10   ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )   b_DWC_pcie_edmapf_tlp_if_11   ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD (K_DMATAGWD)
                         )   b_DWC_pcie_edmapf_wack_if_0   ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD (K_DMATAGWD)
                         )   b_DWC_pcie_edmapf_wack_if_1   ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD (K_DMATAGWD)
                         )   b_DWC_pcie_edmapf_wack_if_2   ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD (K_DMATAGWD)
                         )   b_DWC_pcie_edmapf_wack_if_3   ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_cdm_delay
  
    u_cdmp (
   .b_clk           ( b_clk                                    )
  ,.b_dst           ( b_DWC_pcie_edmapf_cdmregs_if_0.master_mp )
  ,.b_src           ( b_cdm                                    )
  );

  DWC_pcie_edmapf_crgb_remapper
  
    u_crgb_remapper (
   .b_clk           ( b_clk                                    )
  ,.b_in            ( b_crgb                                   )
  ,.b_out           ( b_DWC_pcie_edmapf_crgb_if_0.master_mp    )
  );

  DWC_pcie_edmapf_crgb_1to2_rtr
  
    u_crgb_rtr (
   .b_in            ( b_DWC_pcie_edmapf_crgb_if_0.slave_mp     )
  ,.b_out1          ( b_DWC_pcie_edmapf_crgb_if_2.master_mp    )
  ,.b_out2          ( b_DWC_pcie_edmapf_crgb_if_1.master_mp    )
  );

  DWC_pcie_edmapf_dtarg_arb
   #(
   .P_BUSWD /* K_COREBUSWD */              (K_COREBUSWD)
  ,.P_MAXMWR /* `CC_WR_CH_P_REQ_QUEUE_DP */(`CC_WR_CH_P_REQ_QUEUE_DP)
  ,.P_TAGWD /* K_DMATAGWD */               (K_DMATAGWD)
  ,.P_TLPTYPE /* xradm_s */                (xradm_s)
  ) u_edmapf_dtrgt (
   .b_clk           ( b_clk                                    )
  ,.b_data_req      ( b_DWC_pcie_edmapf_tlp_if_7.slave_mp      )
  ,.b_data_wr       ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp      )
  ,.b_ll_req_rd     ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp      )
  ,.b_ll_req_wr     ( b_DWC_pcie_edmapf_tlp_if_10.slave_mp     )
  ,.b_trgt_np       ( b_trgt_np_out                            )
  ,.b_trgt_p        ( b_trgt_p_out                             )
  ,.b_wack          ( b_DWC_pcie_edmapf_wack_if_0.master_mp    )
  ,.b_wresp         ( b_wresp                                  )
  ,.b_ras           ( b_DWC_pcie_edmapf_rasdp_if_4.master_mp   )
  );

  DWC_pcie_edmapf_dxali_arb
   #(
   .P_BUSWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_TAGWD/*K_DMATAGWD*/    (K_DMATAGWD)
  ,.P_TLPTYPE /* xradm_s */  (xradm_s)
  ) u_edmapf_dxali (
   .b_clk           ( b_clk                                    )
  ,.b_npReq         ( b_npReq_out                              )
  ,.b_pReq          ( b_pReq_out                               )
  ,.b_pReq_ack      ( b_pReqOnPipe                             )
  ,.b_push          ( b_DWC_pcie_edmapf_ctxPush_if_0.master_mp )
  ,.b_rdMsi         ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp      )
  ,.b_rdMsi_ack     ( b_DWC_pcie_edmapf_wack_if_3.master_mp    )
  ,.b_rdReq         ( b_DWC_pcie_edmapf_tlp_if_8.slave_mp      )
  ,.b_wrData        ( b_DWC_pcie_edmapf_tlp_if_11.slave_mp     )
  ,.b_wrData_ack    ( b_DWC_pcie_edmapf_wack_if_2.master_mp    )
  ,.b_wrMsi         ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp      )
  ,.b_wrMsi_ack     ( b_DWC_pcie_edmapf_wack_if_1.master_mp    )
  ,.b_ras           ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp   )
  );

  DWC_pcie_edmapf_rdbuff
   #(
   .P_CPLBUF_LATENCY  (`CC_DMA_SEG_BUF_RAM_LATENCY)
  ,.P_MAXPCIETAG_10BIT(K_MAXPCIETAG)
  ,.P_MAXPCIETAG_5BIT (K_MAXPCIETAG_5BIT)
  ,.P_MAXPCIETAG_8BIT (K_MAXPCIETAG_8BIT)
  ,.P_MINPCIETAG_10BIT(K_MINDMATAG)
  ,.P_MINPCIETAG_5BIT (K_MINDMATAG_5BIT)
  ,.P_MINPCIETAG_8BIT (K_MINDMATAG_8BIT)
  ,.P_SEG_DP          (`CC_DMA_SEG_DEPTH)
  ) u_edmapf_rdbuff (
   .b_cdm           ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp  )
  ,.b_clk           ( b_clk                                    )
  ,.b_cpl           ( b_DWC_pcie_edmapf_tlp_if_3.master_mp     )
  ,.b_push          ( b_DWC_pcie_edmapf_ctxPush_if_0.slave_mp  )
  ,.b_rdBuffer_ram0 ( b_rdBuffer_ram0                          )
  ,.b_timeout       ( b_timeout                                )
  ,.b_trgt          ( b_trgt_in                                )
  ,.b_ras           ( b_DWC_pcie_edmapf_rasdp_if_5.master_mp   )
  );

  DWC_pcie_edmapf_ctrl
   #(
   .CC_IF_CTRL_LL_RAM_LATENCY (`CC_IF_RDCTRL_LL_RAM_LATENCY)
  ,.CC_IF_CTRL_LL_RAM_WD      (`CC_IF_RDCTRL_LL_RAM_BASE_WD)
  ,.CC_NUM_DMA_CHAN_WIDTH     (`CC_NUM_DMA_RD_CHAN_WIDTH)
  ,.CX_DMA_LLQ                (`CX_DMA_RD_LLQ)
  ,.CX_NUM_DMA_CHAN           (`CX_NUM_DMA_RD_CHAN)
  ,.P_C2W_TLPCTXTYPE          (dmaTlpCtxRd_s)
  ,.P_CHANNEL                 (E_READ)
  ,.P_CTXC2W_RAM_LATENCY      (`CC_IF_RD_CTXC2W_RAM_LATENCY)
  ,.P_CTXPIPE_TYPE            (dmaRdEngCtx_s)
  ,.P_CTXSTSH_RAM_LATENCY     (`CC_IF_RD_CTXSTSH_RAM_LATENCY)
  ,.P_CTX_LLQ_OVERLAY_RAM_DP  (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_DP)
  ,.P_CTX_LLQ_OVERLAY_RAM_PW  (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW)
  ,.P_CTX_LLQ_OVERLAY_RAM_WD  (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD)
  ,.P_CTX_TYPE                (fullCtxRd_s)
  ,.P_DBMNGR_ELPFETCH_TYPE    (DbMngrRdElPfetch_t)
  ,.P_DBMNGR_REM_TYPE         (DbMngrRemRdEng_s)
  ,.P_DBMNGR_TYPE             (DbMngrRdEng_s)
  ,.P_ERROR_TYPE              (dmaErrors_e)
  ,.P_GLB_TYPE                (glbData_s)
  ,.P_INT_TYPE                (interruptsRd_s)
  ,.P_LLQ_PUSH_TYPE           (dmaRdEng_llq_push_s)
  ,.P_LLRAM_TYPE              (dmaRdEng_llRam_s)
  ,.P_LL_PUSH_TYPE            (dmaRdEng_llPush_s)
  ,.P_LL_RAM_ADDR_PROT_WD     (`CC_IF_RDCTRL_LL_RAM_PW_PAR)
  ,.P_LL_RAM_DATA_PROT_WD     (`CC_IF_RDCTRL_LL_RAM_ECC_WD)
  ,.P_LL_RAM_RAS_CHK_ID       (RAS_CHK_ID_RAM_RD_LL)
  ,.P_MAXTAGS                 (K_DMATAGS)
  ,.P_MSI_RAM_ADDR_PROT_WD    (`CC_IF_RD_MSI_RAM_PW_PAR)
  ,.P_MSI_RAM_DATA_PROT_WD    (`CC_IF_RD_MSI_RAM_ECC_WD)
  ,.P_MSI_RAM_LATENCY         (`CC_IF_RD_MSI_RAM_LATENCY)
  ,.P_MSI_RAM_RAS_CHK_ID      (RAS_CHK_ID_RAM_RD_MSI)
  ,.P_MWR2ACK_RAM_ADDR_PROT_WD(`CC_IF_RD_CTXSTSH_RAM_PW_PAR)
  ,.P_MWR2ACK_RAM_DATA_PROT_WD(`CC_IF_RD_CTXSTSH_RAM_ECC_WD)
  ,.P_MWR2ACK_RAM_RAS_CHK_ID  (RAS_CHK_ID_RAM_RD_STSHLUT)
  ,.P_NARROWPIPE_TYPE         (rdEngNarrowPipe_s)
  ,.P_OVRL_RAM_ADDR_PROT_WD   (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW_PAR)
  ,.P_OVRL_RAM_DATA_PROT_WD   (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_ECC_WD)
  ,.P_OVRL_RAM_LATENCY        (`CC_IF_RDCTX_LLQ_OVERLAY_RAM_LATENCY)
  ,.P_OVRL_RAM_RAS_CHK_ID     (RAS_CHK_ID_RAM_RD_LLQ)
  ,.P_OVRL_TYPE               (elemCtxRd_s)
  ,.P_POPCTX_LL_TYPE          (dmaRdEngllCtxPop_s)
  ,.P_PUSHCTX_LL_TYPE         (dmaRdEngllCtxPush_s)
  ,.P_REQ2CPL_RAM_ADDR_PROT_WD(`CC_IF_RD_CTXC2W_RAM_PW_PAR)
  ,.P_REQ2CPL_RAM_DATA_PROT_WD(`CC_IF_RD_CTXC2W_RAM_ECC_WD)
  ,.P_REQ2CPL_RAM_RAS_CHK_ID  (RAS_CHK_ID_RAM_RD_C2WLUT)
  ,.P_STSHPIPE_TYPE           (stshPipeRd_s)
  ,.P_TLPTYPE                 (xradm_s)
  ,.P_TLP_DATA_WD             (K_COREBUSWD)
  ) u_edmapf_rdctrl (
   .b_c2w_lut_ram   ( b_rdEng_c2w_lut_ram                      )
  ,.b_cdm           ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp  )
  ,.b_clk           ( b_clk                                    )
  ,.b_crgb          ( b_DWC_pcie_edmapf_crgb_if_2.slave_mp     )
  ,.b_data_ack      ( b_DWC_pcie_edmapf_wack_if_0.slave_mp     )
  ,.b_data_cpl      ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp      )
  ,.b_data_req      ( b_DWC_pcie_edmapf_tlp_if_8.master_mp     )
  ,.b_data_wr       ( b_DWC_pcie_edmapf_tlp_if_5.master_mp     )
  ,.b_hard_stop     ( b_rdEng_hard_stop                        )
  ,.b_ll_cpl        ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp      )
  ,.b_ll_ram        ( b_rdEng_ll_ram                           )
  ,.b_ll_req        ( b_DWC_pcie_edmapf_tlp_if_1.master_mp     )
  ,.b_msi           ( b_DWC_pcie_edmapf_tlp_if_2.master_mp     )
  ,.b_msi_ack       ( b_DWC_pcie_edmapf_wack_if_3.slave_mp     )
  ,.b_msi_ram       ( b_rdEng_msi_ram                          )
  ,.b_ovrl_ram      ( b_rdEng_ovrl_ram                         )
  ,.b_status        ( b_status_rd                              )
  ,.b_stsh_lut_ram  ( b_rdEng_stsh_lut_ram                     )
  ,.b_ras           ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp   )
  );

  DWC_pcie_edmapf_ctrl
   #(
   .CC_IF_CTRL_LL_RAM_LATENCY (`CC_IF_WRCTRL_LL_RAM_LATENCY)
  ,.CC_IF_CTRL_LL_RAM_WD      (`CC_IF_WRCTRL_LL_RAM_BASE_WD)
  ,.CC_NUM_DMA_CHAN_WIDTH     (`CC_NUM_DMA_WR_CHAN_WIDTH)
  ,.CX_DMA_LLQ                (`CX_DMA_WR_LLQ)
  ,.CX_NUM_DMA_CHAN           (`CX_NUM_DMA_WR_CHAN)
  ,.P_C2W_TLPCTXTYPE          (dmaTlpCtxWr_s)
  ,.P_CHANNEL                 (E_WRITE)
  ,.P_CTXC2W_RAM_LATENCY      (`CC_IF_WR_CTXC2W_RAM_LATENCY)
  ,.P_CTXPIPE_TYPE            (dmaWrEngCtx_s)
  ,.P_CTXSTSH_RAM_LATENCY     (`CC_IF_WR_CTXSTSH_RAM_LATENCY)
  ,.P_CTX_LLQ_OVERLAY_RAM_DP  (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_DP)
  ,.P_CTX_LLQ_OVERLAY_RAM_PW  (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW)
  ,.P_CTX_LLQ_OVERLAY_RAM_WD  (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD)
  ,.P_CTX_TYPE                (fullCtxWr_s)
  ,.P_DBMNGR_ELPFETCH_TYPE    (DbMngrWrElPfetch_t)
  ,.P_DBMNGR_REM_TYPE         (DbMngrRemWrEng_s)
  ,.P_DBMNGR_TYPE             (DbMngrWrEng_s)
  ,.P_ERROR_TYPE              (dmaErrors_e)
  ,.P_GLB_TYPE                (glbData_s)
  ,.P_INT_TYPE                (interruptsWr_s)
  ,.P_LLQ_PUSH_TYPE           (dmaWrEng_llq_push_s)
  ,.P_LLRAM_TYPE              (dmaWrEng_llRam_s)
  ,.P_LL_PUSH_TYPE            (dmaWrEng_llPush_s)
  ,.P_LL_RAM_ADDR_PROT_WD     (`CC_IF_WRCTRL_LL_RAM_PW_PAR)
  ,.P_LL_RAM_DATA_PROT_WD     (`CC_IF_WRCTRL_LL_RAM_ECC_WD)
  ,.P_LL_RAM_RAS_CHK_ID       (RAS_CHK_ID_RAM_WR_LL)
  ,.P_MAXTAGS                 (K_DMATAGS)
  ,.P_MSI_RAM_ADDR_PROT_WD    (`CC_IF_WR_MSI_RAM_PW_PAR)
  ,.P_MSI_RAM_DATA_PROT_WD    (`CC_IF_WR_MSI_RAM_ECC_WD)
  ,.P_MSI_RAM_LATENCY         (`CC_IF_WR_MSI_RAM_LATENCY)
  ,.P_MSI_RAM_RAS_CHK_ID      (RAS_CHK_ID_RAM_WR_MSI)
  ,.P_MWR2ACK_RAM_ADDR_PROT_WD(`CC_IF_WR_CTXSTSH_RAM_PW_PAR)
  ,.P_MWR2ACK_RAM_DATA_PROT_WD(`CC_IF_WR_CTXSTSH_RAM_ECC_WD)
  ,.P_MWR2ACK_RAM_RAS_CHK_ID  (RAS_CHK_ID_RAM_WR_STSHLUT)
  ,.P_NARROWPIPE_TYPE         (wrEngNarrowPipe_s)
  ,.P_OVRL_RAM_ADDR_PROT_WD   (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW_PAR)
  ,.P_OVRL_RAM_DATA_PROT_WD   (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_ECC_WD)
  ,.P_OVRL_RAM_LATENCY        (`CC_IF_WRCTX_LLQ_OVERLAY_RAM_LATENCY)
  ,.P_OVRL_RAM_RAS_CHK_ID     (RAS_CHK_ID_RAM_WR_LLQ)
  ,.P_OVRL_TYPE               (elemCtxWr_s)
  ,.P_POPCTX_LL_TYPE          (dmaWrEngllCtxPop_s)
  ,.P_PUSHCTX_LL_TYPE         (dmaWrEngllCtxPush_s)
  ,.P_REQ2CPL_RAM_ADDR_PROT_WD(`CC_IF_WR_CTXC2W_RAM_PW_PAR)
  ,.P_REQ2CPL_RAM_DATA_PROT_WD(`CC_IF_WR_CTXC2W_RAM_ECC_WD)
  ,.P_REQ2CPL_RAM_RAS_CHK_ID  (RAS_CHK_ID_RAM_WR_C2WLUT)
  ,.P_STSHPIPE_TYPE           (stshPipeWr_s)
  ,.P_TLPTYPE                 (xradm_s)
  ,.P_TLP_DATA_WD             (K_COREBUSWD)
  ) u_edmapf_wrctrl (
   .b_c2w_lut_ram   ( b_wrEng_c2w_lut_ram                      )
  ,.b_cdm           ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp  )
  ,.b_clk           ( b_clk                                    )
  ,.b_crgb          ( b_DWC_pcie_edmapf_crgb_if_1.slave_mp     )
  ,.b_data_ack      ( b_DWC_pcie_edmapf_wack_if_2.slave_mp     )
  ,.b_data_cpl      ( b_DWC_pcie_edmapf_tlp_if_9.slave_mp      )
  ,.b_data_req      ( b_DWC_pcie_edmapf_tlp_if_7.master_mp     )
  ,.b_data_wr       ( b_DWC_pcie_edmapf_tlp_if_11.master_mp    )
  ,.b_hard_stop     ( b_wrEng_hard_stop                        )
  ,.b_ll_cpl        ( b_DWC_pcie_edmapf_tlp_if_6.slave_mp      )
  ,.b_ll_ram        ( b_wrEng_ll_ram                           )
  ,.b_ll_req        ( b_DWC_pcie_edmapf_tlp_if_10.master_mp    )
  ,.b_msi           ( b_DWC_pcie_edmapf_tlp_if_4.master_mp     )
  ,.b_msi_ack       ( b_DWC_pcie_edmapf_wack_if_1.slave_mp     )
  ,.b_msi_ram       ( b_wrEng_msi_ram                          )
  ,.b_ovrl_ram      ( b_wrEng_ovrl_ram                         )
  ,.b_status        ( b_status_wr                              )
  ,.b_stsh_lut_ram  ( b_wrEng_stsh_lut_ram                     )
  ,.b_ras           ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp   )
  );

  
  assign edmapf_ras_dp_err_logs = { b_DWC_pcie_edmapf_rasdp_if_5.w_ras_dp_err_log,
                                    b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_log,
                                    b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_log,
                                    b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_log
                                   }; 
  assign b_DWC_pcie_edmapf_rasdp_if_5.w_ras_dp_err_inj = edmapf_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = edmapf_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = edmapf_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = edmapf_ras_dp_err_inj;
  
  assign b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = '0;

  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_EDMA_PF_CHK             ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                         )
  ) u_edmapf_core_ras_dp_err_mgr (                                 
    .clk                        ( b_clk.w_aux_clk              )
   ,.rst_n                      ( b_clk.w_reset_n              )
   ,.out_ras_dp_wake_up         ( /*Not Connected*/            )
   ,.in_ras_dp_err_inj          ( b_ras.w_ras_dp_err_inj       )
   ,.out_ras_dp_err_inj         ( edmapf_ras_dp_err_inj        )
  ,.in_ras_dp_err_log           ( edmapf_ras_dp_err_logs       )
  ,.out_ras_dp_err_log          ( b_ras.w_ras_dp_err_log       )
  );

  DWC_pcie_edmapf_xali_rtr
   #(
   .P_BUSWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_TLPTYPE /* xradm_s */  (xradm_s)
  ) u_xali_monitor (
   .b_cdm           ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp  )
  ,.b_clk           ( b_clk                                    )
  ,.b_in            ( b_client0_in                             )
  ,.b_rdll          ( b_DWC_pcie_edmapf_tlp_if_0.master_mp     )
  ,.b_wrdata        ( b_DWC_pcie_edmapf_tlp_if_9.master_mp     )
  ,.b_wrll          ( b_DWC_pcie_edmapf_tlp_if_6.master_mp     )
  ,.b_ras           ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp   )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
