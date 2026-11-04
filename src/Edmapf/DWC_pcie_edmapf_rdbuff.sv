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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rdbuff.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_header_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_bypass_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_rdbuff
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter  type P_BYPASS_TYPE = bypass_s
  ,parameter type P_TIMEOUT_TYPE = timeout_s
  ,parameter      type P_TLPTYPE = xradm_s
  ,parameter             P_BUSWD = K_COREBUSWD
  ,parameter              P_CHAN = K_RD_DMACHAN
  ,parameter    P_CPLBUF_LATENCY = `CC_DMA_SEG_BUF_RAM_LATENCY
  ,parameter          P_DMATAGWD = K_DMATAGWD
  ,parameter  P_MAXPCIETAG_10BIT = 1023
  ,parameter   P_MAXPCIETAG_5BIT = 31
  ,parameter   P_MAXPCIETAG_8BIT = 255
  ,parameter  P_MINPCIETAG_10BIT = 512
  ,parameter   P_MINPCIETAG_5BIT = 16
  ,parameter   P_MINPCIETAG_8BIT = 128
  ,parameter                P_NW = K_NW
  ,parameter              P_PFWD = K_PFWD
  ,parameter            P_SEG_DP = 1024
  ,parameter            P_SEG_WD = K_RDBUFFER_INT_RAM_WD
  ,parameter              P_VFWD = K_VFWD
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp         b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_cpl
  ,DWC_pcie_edmapf_ctxPush_if.slave_mp         b_push
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdBuffer_ram0
  ,DWC_pcie_edmapf_tlp_header_if.slave_mp      b_timeout
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_trgt
  ,DWC_pcie_edmapf_rasdp_if.master_mp          b_ras
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_PCIETAGS   = P_MAXPCIETAG_10BIT - P_MINPCIETAG_10BIT + 1                          ;
  localparam L_PCIETAGSWD = $clog2(P_MAXPCIETAG_10BIT+1)                                         ;
  localparam L_CPLBUF_DP  = P_SEG_DP * L_PCIETAGS                                                ;
  localparam N_RDBUFF_CHK = 2 ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_crPop_haltable_if #(
     .P_DATATYPE(logic [P_DMATAGWD-1:0])
    ,.P_TAGWD   (L_PCIETAGSWD)
                                   )b_DWC_pcie_edmapf_crPop_haltable_if_0();
  DWC_pcie_edmapf_crPop_if #(
     .P_DATATYPE(logic [P_DMATAGWD-1:0])
    ,.P_TAGWD   (L_PCIETAGSWD)
                          )         b_DWC_pcie_edmapf_crPop_if_0         ();
  DWC_pcie_edmapf_ctxPush_if #(
     .P_DATATYPE(logic [P_DMATAGWD-1:0])
    ,.P_TAGWD   (L_PCIETAGSWD)
                            )       b_DWC_pcie_edmapf_ctxPush_if_0       ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(L_PCIETAGS)
    ,.PW($clog2(L_PCIETAGS))
    ,.WD(P_DMATAGWD)
                          )         b_DWC_pcie_edmapf_ram2p_if_0         ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(L_CPLBUF_DP)
    ,.PW($clog2(L_CPLBUF_DP))
    ,.WD(P_SEG_WD)
                          )         b_DWC_pcie_edmapf_ram2p_if_1         ();
  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP            (L_PCIETAGS)
    ,.PW            ($clog2(L_PCIETAGS))
    ,.P_ADDR_PROT_WD(`CC_IF_DMATAGS_RAM_PW_PAR /* NOT USED */)
    ,.WD            (P_DMATAGWD)
                                   )b_DWC_pcie_edmapf_ram2p_standard_if_0();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_1         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_2         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_3         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_4         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_5         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_6         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_7         ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_8         ();
  ras_dp_err_log_t [N_RDBUFF_CHK-1:0] rdbuff_ras_dp_err_logs;
  ras_dp_err_inj_t                    rdbuff_ras_dp_err_inj;
  DWC_pcie_edmapf_rvData_if #(
     .P_DATATYPE(edmapf_pcietag_ch_s)
                           )        b_DWC_pcie_edmapf_rvData_if_0        ();
  DWC_pcie_edmapf_tagMngr_cfg_if    b_DWC_pcie_edmapf_tagMngr_cfg_if_0   ();
  DWC_pcie_edmapf_tlp_bypass_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                               )    b_DWC_pcie_edmapf_tlp_bypass_if_0    ();
  DWC_pcie_edmapf_tlp_header_if #(
     .P_HEADERTYPE(P_TIMEOUT_TYPE)
                               )    b_DWC_pcie_edmapf_tlp_header_if_0    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )           b_DWC_pcie_edmapf_tlp_if_0           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )           b_DWC_pcie_edmapf_tlp_if_1           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )           b_DWC_pcie_edmapf_tlp_if_2           ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################


  DWC_pcie_edmapf_rdbuff_cdm2cfg
  
    u_cdm2tagMngrCfg (
   .b_cdm         ( b_cdm                                           )
  ,.b_cfg         ( b_DWC_pcie_edmapf_tagMngr_cfg_if_0.master_mp    )
  ,.b_clk         ( b_clk                                           )
  );

  DWC_pcie_edmapf_rdbuff_core
   #(
   .CC_CORE_DATA_BUS_WD /* P_BUSWD */          (P_BUSWD)
  ,.CC_DMA_RD_TAG_HIGH /* P_MAXPCIETAG_10BIT */(P_MAXPCIETAG_10BIT)
  ,.CC_DMA_SEG_DEPTH /* P_SEG_DP */            (P_SEG_DP)
  ,.CC_NUM_DMA_RD_CHAN /* P_CHAN */            (P_CHAN)
  ,.CX_NFUNC_WD /* P_PFWD */                   (P_PFWD)
  ,.CX_NVFUNC_WD /* P_VFWD */                  (P_VFWD)
  ,.CX_NW /* P_NW */                           (P_NW)
  ) u_core (
   .b_bypass      ( b_DWC_pcie_edmapf_tlp_bypass_if_0.slave_mp      )
  ,.b_cdm         ( b_cdm                                           )
  ,.b_clk         ( b_clk                                           )
  ,.b_cpl         ( b_DWC_pcie_edmapf_tlp_if_2.master_mp            )
  ,.b_push        ( b_DWC_pcie_edmapf_rvData_if_0.slave_mp          )
  ,.b_ram0        ( b_DWC_pcie_edmapf_ram2p_if_1.master_mp          )
  ,.b_timeout     ( b_DWC_pcie_edmapf_tlp_header_if_0.slave_mp      )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp          ) 
  );


  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP               (L_CPLBUF_DP)
  ,.PW               ($clog2(L_CPLBUF_DP))
  ,.P_ADDR_PROT_WD   (`CC_DMA_SEG_BUF_NW_ADDRP_WIDTH)
  ,.P_DATA_PROT_WD   ( 1)
  ,.P_PIPELINE       (P_CPLBUF_LATENCY)
  ,.RAS_DP_PROT_CHK_ID (RAS_CHK_ID_RAM_RDBUF)
  ,.P_RAS_DATA_BYPASS( E_TRUE)
  ,.P_REG_IF         (`CC_DMA_SEG_BUF_RAM_REG_IF)
  ,.WD               (P_SEG_WD)
  ) u_cplBuffer_ramAdapter (
   .b_clk         ( b_clk                                           )
  ,.b_external    ( b_rdBuffer_ram0                                 )
  ,.b_internal    ( b_DWC_pcie_edmapf_ram2p_if_1.slave_mp           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_4.master_mp          )
  );



  DWC_pcie_edmapf_rdbuff_cplMux
  
    u_cplMux (
   .b_clk         ( b_clk                                           )
  ,.b_cpl         ( b_DWC_pcie_edmapf_tlp_bypass_if_0.master_mp     )
  ,.b_trgt        ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp             )
  );

  DWC_pcie_edmapf_ram2p_wrapper
   #(
   .DP /* L_PCIETAGS */    (L_PCIETAGS)
  ,.PW                     ($clog2(L_PCIETAGS))
  ,.P_FLIPFLOP /* E_TRUE */(E_TRUE)
  ,.WD /* P_DMATAGWD */    (P_DMATAGWD)
  ) u_dmaTags (
   .clk           ( b_clk                                           )
  ,.pins          ( b_DWC_pcie_edmapf_ram2p_standard_if_0.slave_mp  )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP               (L_PCIETAGS)
  ,.PW               ($clog2(L_PCIETAGS))
  ,.P_ADDR_PROT_WD   (`CC_IF_DMATAGS_RAM_PW_PAR /* NOT USED */)
  ,.P_PIPELINE       (1)
  ,.P_RAS_DATA_BYPASS(E_TRUE)
  ,.P_REG_IF         (0)
  ,.WD               (P_DMATAGWD)
  ) u_dmaTags_ramAdapter (
   .b_clk         ( b_clk                                           )
  ,.b_external    ( b_DWC_pcie_edmapf_ram2p_standard_if_0.master_mp )
  ,.b_internal    ( b_DWC_pcie_edmapf_ram2p_if_0.slave_mp           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp          )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /*P_BUSWD*/      (P_BUSWD)
  ,.P_HEADERTYPE /*P_TLPTYPE*/(P_TLPTYPE)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /*E_FEED_NONE*/  (E_FEED_NONE)
  ,.P_TYPE /*E_TLP_FULL*/     (E_TLP_FULL)
  ) u_outReg_delay (
   .b_dst         ( b_cpl                                           )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp             )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp          )
  );

  DWC_pcie_edmapf_lutMngr
   #(
   .P_MAXTAG /* P_MAXPCIETAG_10BIT */    (P_MAXPCIETAG_10BIT)
  ,.P_MAXTAG_LOW /* P_MAXPCIETAG_8BIT */ (P_MAXPCIETAG_8BIT)
  ,.P_MAXTAG_VLOW /* P_MAXPCIETAG_5BIT */(P_MAXPCIETAG_5BIT)
  ,.P_MINTAG /* P_MINPCIETAG_10BIT */    (P_MINPCIETAG_10BIT)
  ,.P_MINTAG_LOW /* P_MINPCIETAG_8BIT */ (P_MINPCIETAG_8BIT)
  ,.P_MINTAG_VLOW /* P_MINPCIETAG_5BIT */(P_MINPCIETAG_5BIT)
  ,.P_MULTIMODE /* E_TRUE */             (E_TRUE)
  ) u_pcieTagMngr (
   .b_cfg         ( b_DWC_pcie_edmapf_tagMngr_cfg_if_0.slave_mp     )
  ,.b_clk         ( b_clk                                           )
  ,.b_memAccess   ( b_DWC_pcie_edmapf_ram2p_if_0.master_mp          )
  ,.b_pop         ( b_DWC_pcie_edmapf_crPop_if_0.master_mp          )
  ,.b_push        ( b_DWC_pcie_edmapf_ctxPush_if_0.slave_mp         )
  );

  
  assign rdbuff_ras_dp_err_logs = { 
                                    b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_log, //ram0
                                    b_DWC_pcie_edmapf_rasdp_if_7.w_ras_dp_err_log
                                   };
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = rdbuff_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_7.w_ras_dp_err_inj = rdbuff_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_8.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_6.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_5.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = '0;

  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_RDBUFF_CHK         ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                    )
  ) u_rdbuff_ras_dp_err_mgr (
    .clk                        (b_clk.w_aux_clk          )
   ,.rst_n                      (b_clk.w_reset_n          )
   ,.out_ras_dp_wake_up         (/*Not Connected*/        )
   ,.in_ras_dp_err_inj          (b_ras.w_ras_dp_err_inj   )
   ,.out_ras_dp_err_inj         (rdbuff_ras_dp_err_inj    )
  ,.in_ras_dp_err_log           (rdbuff_ras_dp_err_logs   )
  ,.out_ras_dp_err_log          (b_ras.w_ras_dp_err_log   )
  );


  DWC_pcie_edmapf_rdbuff_splitter
   #(
   .P_TAGWD /* K_TAGWD */(K_TAGWD)
  ) u_spliter (
   .b_cloakroom   ( b_DWC_pcie_edmapf_ctxPush_if_0.master_mp        )
  ,.b_core        ( b_DWC_pcie_edmapf_rvData_if_0.master_mp         )
  ,.b_in          ( b_push                                          )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */           (P_BUSWD)
  ,.P_HEADERTYPE /* P_TIMEOUT_TYPE */(P_TIMEOUT_TYPE)
  ,.P_STAGES /* E_FEED_NONE */       (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_HEADER */        (E_TLP_HEADER)
  ) u_timeout_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_header_if_0.master_mp     )
  ,.b_src         ( b_timeout                                       )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_6.master_mp          )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_CHK_EN                (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID          (RAS_CHK_ID_RDBUF_TRGT)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_trgt_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_1.master_mp            )
  ,.b_src         ( b_trgt                                          )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_7.master_mp          )
  );

  DWC_pcie_edmapf_untagger
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_DTAG /* P_DMATAGWD */     (P_DMATAGWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_TAGTYPE /* E_TAG_PCIE */  (E_TAG_PCIE)
  ,.P_TAGWD /* L_PCIETAGSWD */  (L_PCIETAGSWD)
  ) u_untagger (
   .b_clk         ( b_clk                                           )
  ,.b_dst         ( b_DWC_pcie_edmapf_tlp_if_0.master_mp            )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp             )
  ,.b_tag         ( b_DWC_pcie_edmapf_crPop_haltable_if_0.slave_mp  )
  );

  DWC_pcie_edmapf_damper
   #(
   .P_DAMPER_DP /* 3 */                    (3)
  ,.P_DATATYPE /* logic [P_DMATAGWD-1:0] */(logic [P_DMATAGWD-1:0])
  ,.P_POPTYPE_PEEK /* E_TRUE */            (E_TRUE)
  ) u_untagger_damper (
   .b_pop         ( b_DWC_pcie_edmapf_crPop_if_0.slave_mp           )
  ,.b_popHaltable ( b_DWC_pcie_edmapf_crPop_haltable_if_0.master_mp )
  ,.b_clk         ( b_clk                                           )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
