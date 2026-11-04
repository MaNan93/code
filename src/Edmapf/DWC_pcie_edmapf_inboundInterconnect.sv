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
// ---    $Revision: #3 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_inboundInterconnect.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_header_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_inboundInterconnect
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tlp_if.slave_mp         b_app_client_cpl
  ,DWC_pcie_edmapf_tlp_if.master_mp        b_app_trgt_np
  ,DWC_pcie_edmapf_tlp_if.master_mp        b_app_trgt_p
  ,DWC_pcie_edmapf_tlp_header_if.master_mp b_app_trgt_timeout
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp     b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp       b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp        b_core_client_cpl
  ,DWC_pcie_edmapf_tlp_if.master_mp        b_core_dma_cpl
  ,DWC_pcie_edmapf_tlp_header_if.master_mp b_core_dma_timeout
  ,DWC_pcie_edmapf_tlp_if.slave_mp         b_core_trgt_np
  ,DWC_pcie_edmapf_tlp_if.slave_mp         b_core_trgt_p
  ,DWC_pcie_edmapf_tlp_header_if.slave_mp  b_core_trgt_timeout
  ,DWC_pcie_edmapf_tlp_if.slave_mp         b_dma_app_np
  ,DWC_pcie_edmapf_tlp_if.slave_mp         b_dma_app_p
  ,DWC_pcie_edmapf_rasdp_if.master_mp      b_ras
  );

  // ##########################################################################
  //                               Local Parameters                          
  // ##########################################################################
    localparam N_IB_CHK = 8 ;
  
  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_crPop_haltable_if #(
     .P_DATATYPE(logic [K_LUIDMAPWD:1])
    ,.P_TAGWD   (K_LUIDWD)
                                   )b_DWC_pcie_edmapf_crPop_haltable_if_0();
  DWC_pcie_edmapf_crPop_if #(
     .P_DATATYPE(logic [K_LUIDMAPWD:1])
    ,.P_TAGWD   (K_LUIDWD)
                          )         b_DWC_pcie_edmapf_crPop_if_0         ();
  DWC_pcie_edmapf_ctxPush_if #(
     .P_DATATYPE(logic [K_LUIDMAPWD:1])
    ,.P_TAGWD   (K_LUIDWD)
                            )       b_DWC_pcie_edmapf_ctxPush_if_0       ();
  DWC_pcie_edmapf_ram2p_if #(
     .DP(K_LUID)
    ,.PW(K_LUIDWD)
    ,.WD(K_LUIDMAPWD)
                          )         b_DWC_pcie_edmapf_ram2p_if_0         ();
  DWC_pcie_edmapf_ram2p_standard_if #(
     .DP            (K_LUID)
    ,.PW            (K_LUIDWD)
    ,.P_ADDR_PROT_WD(`CC_IF_LUID_RAM_PW_PAR  /* NOT USED */)
    ,.WD            (K_LUIDMAPWD)
                                   )b_DWC_pcie_edmapf_ram2p_standard_if_0();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_0_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_1_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_2_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_3_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_4_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_5_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_6_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_7_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_8_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_9_u       ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_10_u      ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_11_u      ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_12_u      ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_13_u      ();
  DWC_pcie_edmapf_rasdp_if          b_DWC_pcie_edmapf_rasdp_if_14_u      ();
  DWC_pcie_edmapf_tagMngr_cfg_if    b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u ();
  DWC_pcie_edmapf_tlp_header_if #(
     .P_HEADERTYPE(timeout_s)
                               )    b_DWC_pcie_edmapf_tlp_header_if_0    ();
  DWC_pcie_edmapf_tlp_header_if #(
     .P_HEADERTYPE(timeout_s)
                               )    b_DWC_pcie_edmapf_tlp_header_if_1    ();
  DWC_pcie_edmapf_tlp_header_if #(
     .P_HEADERTYPE(timeout_s)
                               )    b_DWC_pcie_edmapf_tlp_header_if_2    ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_0           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_1           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_2           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_3           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_4           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_5           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_6           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_7           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_8           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )           b_DWC_pcie_edmapf_tlp_if_9           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          b_DWC_pcie_edmapf_tlp_if_10           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          b_DWC_pcie_edmapf_tlp_if_11           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          b_DWC_pcie_edmapf_tlp_if_12           ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_core_trgt_p                         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_core_trgt_np                        ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_app_trgt_p                          ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_app_trgt_np                         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_core_client_cpl                     ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_app_client_cpl                      ();
  ras_dp_err_log_t [N_IB_CHK-1:0]  ib_ras_dp_err_logs                      ;
    ras_dp_err_inj_t               ib_ras_dp_err_inj                       ;
  logic [12:0]                     tlp_byte_len_core_client_cpl            ; 
    
    
  // ##########################################################################
  //                              Wiring Connections                        
  // ##########################################################################
    
        assign s_app_client_cpl.w_header     = b_app_client_cpl.w_header   ;
        assign s_app_client_cpl.w_hv         = b_app_client_cpl.w_hv       ;
        assign s_app_client_cpl.w_data       = b_app_client_cpl.w_data     ;
        assign s_app_client_cpl.w_dv         = b_app_client_cpl.w_dv       ;
        assign s_app_client_cpl.w_eot        = b_app_client_cpl.w_eot      ;
        assign b_app_client_cpl.w_halt       = s_app_client_cpl.w_halt     ;
        assign s_app_client_cpl.w_headerProt= '0                           ;
         
        assign b_core_client_cpl.w_header    = s_core_client_cpl.w_header  ;
        assign b_core_client_cpl.w_hv        = s_core_client_cpl.w_hv      ;
        assign b_core_client_cpl.w_data      = s_core_client_cpl.w_data    ;
        assign b_core_client_cpl.w_dv        = s_core_client_cpl.w_dv      ;
        assign b_core_client_cpl.w_eot       = s_core_client_cpl.w_eot     ;
        assign s_core_client_cpl.w_halt      = b_core_client_cpl.w_halt    ;
      
        assign b_app_trgt_np.w_header        = s_app_trgt_np.w_header      ;
        assign b_app_trgt_np.w_hv            = s_app_trgt_np.w_hv          ;
        assign b_app_trgt_np.w_data          = s_app_trgt_np.w_data        ;
        assign b_app_trgt_np.w_dv            = s_app_trgt_np.w_dv          ;
        assign b_app_trgt_np.w_eot           = s_app_trgt_np.w_eot         ;
        assign s_app_trgt_np.w_halt          = b_app_trgt_np.w_halt        ;
      
      
        assign s_core_trgt_np.w_header       = b_core_trgt_np.w_header     ;
        assign s_core_trgt_np.w_hv           = b_core_trgt_np.w_hv         ;
        assign s_core_trgt_np.w_data         = b_core_trgt_np.w_data       ;
        assign s_core_trgt_np.w_dv           = b_core_trgt_np.w_dv         ;
        assign s_core_trgt_np.w_eot          = b_core_trgt_np.w_eot        ;
        assign b_core_trgt_np.w_halt         = s_core_trgt_np.w_halt       ;
        assign s_core_trgt_np.w_headerProt   = '0                          ;
      
        assign b_app_trgt_p.w_header         = s_app_trgt_p.w_header       ;
        assign b_app_trgt_p.w_hv             = s_app_trgt_p.w_hv           ;
        assign b_app_trgt_p.w_data           = s_app_trgt_p.w_data         ;
        assign b_app_trgt_p.w_dv             = s_app_trgt_p.w_dv           ;
        assign b_app_trgt_p.w_eot            = s_app_trgt_p.w_eot          ;
        assign s_app_trgt_p.w_halt           = b_app_trgt_p.w_halt         ;
      
      
        assign s_core_trgt_p.w_header       = b_core_trgt_p.w_header      ;
        assign s_core_trgt_p.w_hv           = b_core_trgt_p.w_hv          ;
        assign s_core_trgt_p.w_data         = b_core_trgt_p.w_data        ;
        assign s_core_trgt_p.w_dv           = b_core_trgt_p.w_dv          ;
        assign s_core_trgt_p.w_eot          = b_core_trgt_p.w_eot         ;
        assign b_core_trgt_p.w_halt          = s_core_trgt_p.w_halt       ;
        assign s_core_trgt_p.w_headerProt = '0                         ;
       
        assign tlp_byte_len_core_client_cpl  = (b_core_client_cpl.w_header.dma.req == E_DMA_BYPASS) ? b_core_client_cpl.w_header.xadmPort.tlp_byte_len  : f_tlp_dwlen2bytelen(b_core_client_cpl.w_header.common2.dw_len );


  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################
   

  assign ib_ras_dp_err_logs [N_IB_CHK-1:3]  = { b_DWC_pcie_edmapf_rasdp_if_12_u.w_ras_dp_err_log,
                                                b_DWC_pcie_edmapf_rasdp_if_5_u.w_ras_dp_err_log,
                                                b_DWC_pcie_edmapf_rasdp_if_2_u.w_ras_dp_err_log,
                                                b_DWC_pcie_edmapf_rasdp_if_1_u.w_ras_dp_err_log,
                                                b_DWC_pcie_edmapf_rasdp_if_0_u.w_ras_dp_err_log
                                               };
  assign b_DWC_pcie_edmapf_rasdp_if_12_u.w_ras_dp_err_inj = ib_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_5_u.w_ras_dp_err_inj  = ib_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_2_u.w_ras_dp_err_inj  = ib_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_1_u.w_ras_dp_err_inj  = ib_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_0_u.w_ras_dp_err_inj  = ib_ras_dp_err_inj;
  
  assign b_DWC_pcie_edmapf_rasdp_if_3_u.w_ras_dp_err_inj  = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_4_u.w_ras_dp_err_inj  = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_6_u.w_ras_dp_err_inj  = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_7_u.w_ras_dp_err_inj  = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_8_u.w_ras_dp_err_inj  = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_9_u.w_ras_dp_err_inj  = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_10_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_11_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_13_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_14_u.w_ras_dp_err_inj = '0;

  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_IB_CHK                ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (0                       )
  ) u_ib_ras_dp_err_mgr (                                 
    .clk                            ( b_clk.w_aux_clk        )
   ,.rst_n                          ( b_clk.w_reset_n        )
   ,.out_ras_dp_wake_up             ( /* not connected */    )
   ,.in_ras_dp_err_inj              ( b_ras.w_ras_dp_err_inj )
   ,.out_ras_dp_err_inj             ( ib_ras_dp_err_inj      )
  ,.in_ras_dp_err_log               ( ib_ras_dp_err_logs     )
  ,.out_ras_dp_err_log              ( b_ras.w_ras_dp_err_log )
  );

  // HDR Checkers                        

   ras_dp_pipe
    #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (0                              ),
      .BUS_PROTECT_CHK_EN        (1                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (K_RAS_PROT_RANGE               ),
      .PROT_WD                   (`CLIENT_HDR_PROT_WD            ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CLIENT_HDR_WD                 ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (RAS_CHK_ID_CLIENT_CPL          )
    ) u_chk_client_cpl_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_app_client_cpl.w_header.common2.tph_th,
                                   b_app_client_cpl.w_header.common2.tph_st,
                                   b_app_client_cpl.w_header.common2.tph_ph,
                                   b_app_client_cpl.w_header.common1.pfunc_num,
                                   b_app_client_cpl.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_app_client_cpl.w_header.common2.ats,
                                   b_app_client_cpl.w_header.common3.nw,
                                   b_app_client_cpl.w_header.xadmPort.addr_align_en,
                                   b_app_client_cpl.w_header.common2.last_be,
                                   b_app_client_cpl.w_header.common2.first_be,
                                   b_app_client_cpl.w_header.common2.cmpltr_id,
                                   b_app_client_cpl.w_header.common2.cpl_status,
                                   b_app_client_cpl.w_header.common2.cpl_bcm,
                                   b_app_client_cpl.w_header.common2.byte_cnt,
                                   b_app_client_cpl.w_header.common1.pcieTag,
                                   b_app_client_cpl.w_header.xadmPort.tlp_byte_len,
                                   b_app_client_cpl.w_header.common2.poisoned,
                                   b_app_client_cpl.w_header.common2.td,
                                   b_app_client_cpl.w_header.common1.tc,
                                   b_app_client_cpl.w_header.common2.typ,
                                   b_app_client_cpl.w_header.common2.fmt,
                                   b_app_client_cpl.w_header.common2.addr
                                  }
                                                                      )
     ,.din_prot                  ( b_app_client_cpl.w_headerProt      )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( /* not connected */                )
     ,.en                        ( 1'b1                               )
     ,.bypass                    ( 1'b0                               )
     ,.stall                     ( 1'b0                               )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_app_client_cpl.w_hv              )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   ( 1'b0                               )
     ,.ras_dp_err_inband_kbd_in  ( 1'b0                               )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( ib_ras_dp_err_logs[0]              )
     ,.ras_dp_err_inj            ( ib_ras_dp_err_inj                  )
      );
      
      
     ras_dp_pipe
      #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (0                              ),
      .BUS_PROTECT_CHK_EN        (1                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (K_RAS_PROT_RANGE               ),
      .PROT_WD                   (`CX_RASDP_TRGT1_NP_HDR_PROT_WD ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CX_RASDP_TRGT1_NP_HDR_WD      ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (RAS_CHK_ID_TRGT_NP             )
    ) u_chk_trgt_np_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                 {
                                  b_core_trgt_np.w_header.order_seq_no.inbound,
                                  b_core_trgt_np.w_header.common3.nw,
                                  b_core_trgt_np.w_header.common3.cxlsrc,
                                  b_core_trgt_np.w_header.common2.tph_ph,
                                  b_core_trgt_np.w_header.common2.tph_st,
                                  b_core_trgt_np.w_header.flit_mode.dst_sgmt,
                                  b_core_trgt_np.w_header.flit_mode.req_sgmt,
                                  b_core_trgt_np.w_header.common2.last_be ,
                                  //radm_trgt1_np_0_ats,
                                  b_core_trgt_np.w_header.common2.ats,
                                  b_core_trgt_np.w_header.common2.poisoned,
                                  b_core_trgt_np.w_header.common2.tph_th,
                                  b_core_trgt_np.w_header.common2.td,
                                  b_core_trgt_np.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0],
                                  b_core_trgt_np.w_header.common2.first_be,
                                  b_core_trgt_np.w_header.common4.io_req_in_range,
                                  b_core_trgt_np.w_header.common4.rom_in_range,
                                  b_core_trgt_np.w_header.common4.in_membar_range,
                                  b_core_trgt_np.w_header.common2.dw_len,
                                  b_core_trgt_np.w_header.common2.cpl_status,
                                  b_core_trgt_np.w_header.common1.pfunc_num,
                                  b_core_trgt_np.w_header.common1.pcieTag,
                                  b_core_trgt_np.w_header.common4.req_id,
                                  b_core_trgt_np.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                  b_core_trgt_np.w_header.common1.tc,
                                  b_core_trgt_np.w_header.common2.typ,
                                  b_core_trgt_np.w_header.common2.fmt
                                 }
                                                                      )
     ,.din_prot                  ( b_core_trgt_np.w_headerProt        )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( /* not connected */                )
     ,.en                        ( 1'b1                               )
     ,.bypass                    ( 1'b0                               )
     ,.stall                     ( 1'b0                               )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_core_trgt_np.w_hv                )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   ( 1'b0                               )
     ,.ras_dp_err_inband_kbd_in  ( 1'b0                               )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( ib_ras_dp_err_logs[1]              )
     ,.ras_dp_err_inj            ( ib_ras_dp_err_inj                  )
     );
      
      
   ras_dp_pipe
    #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (0                              ),
      .BUS_PROTECT_CHK_EN        (1                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (K_RAS_PROT_RANGE               ),
      .PROT_WD                   (`CX_RASDP_TRGT1_P_HDR_PROT_WD  ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CX_RASDP_TRGT1_P_HDR_WD       ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (RAS_CHK_ID_TRGT_P              )
    ) u_chk_trgt_p_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                 {
                                  b_core_trgt_p.w_header.radmPort.uppr_bytes[`FLT_Q_ADDR_WIDTH-1:0],
                                  b_core_trgt_p.w_header.order_seq_no.inbound,
                                  b_core_trgt_p.w_header.radmPort.uppr_bytes_valid,
                                  b_core_trgt_p.w_header.common2.tph_ph,
                                  b_core_trgt_p.w_header.common2.tph_st,
                                  b_core_trgt_p.w_header.flit_mode.dst_sgmt,
                                  b_core_trgt_p.w_header.flit_mode.req_sgmt,
                                  b_core_trgt_p.w_header.common2.last_be ,
                                  b_core_trgt_p.w_header.common2.ats,
                                  b_core_trgt_p.w_header.common2.poisoned,
                                  b_core_trgt_p.w_header.common2.tph_th,
                                  
                                  b_core_trgt_p.w_header.common2.td,
                                  b_core_trgt_p.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0],
                                  b_core_trgt_p.w_header.common2.first_be,
                                  b_core_trgt_p.w_header.common4.rom_in_range,
                                  b_core_trgt_p.w_header.common4.in_membar_range,
                                  b_core_trgt_p.w_header.common2.dw_len,
                                  b_core_trgt_p.w_header.common2.cpl_status,
                                  b_core_trgt_p.w_header.common1.pfunc_num,
                                  b_core_trgt_p.w_header.common1.pcieTag,
                                  b_core_trgt_p.w_header.common4.req_id,
                                  b_core_trgt_p.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                  b_core_trgt_p.w_header.common1.tc,
                                  b_core_trgt_p.w_header.common2.typ,
                                  b_core_trgt_p.w_header.common2.fmt
                                 }
                                                                      )
     ,.din_prot                  ( b_core_trgt_p.w_headerProt         )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( /* not connected */                )
     ,.en                        ( 1'b1                               )
     ,.bypass                    ( 1'b0                               )
     ,.stall                     ( 1'b0                               )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_core_trgt_p.w_hv                 )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   ( 1'b0                               )
     ,.ras_dp_err_inband_kbd_in  ( 1'b0                               )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( ib_ras_dp_err_logs[2]              )
     ,.ras_dp_err_inj            ( ib_ras_dp_err_inj                  )
     );
      
  // HDR Generators                        
     
   ras_dp_pipe
    #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (1                              ),
      .BUS_PROTECT_CHK_EN        (0                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (K_RAS_PROT_RANGE               ),
      .PROT_WD                   (`CLIENT_HDR_PROT_WD            ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CLIENT_HDR_WD                 ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (/* not connected */            )
    ) u_gen_client_cpl_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_core_client_cpl.w_header.common2.tph_th,
                                   b_core_client_cpl.w_header.common2.tph_st,
                                   b_core_client_cpl.w_header.common2.tph_ph,
                                   b_core_client_cpl.w_header.common1.pfunc_num,
                                   b_core_client_cpl.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_core_client_cpl.w_header.common2.ats,
                                   b_core_client_cpl.w_header.common3.nw,
                                   b_core_client_cpl.w_header.xadmPort.addr_align_en,
                                   b_core_client_cpl.w_header.common2.last_be,
                                   b_core_client_cpl.w_header.common2.first_be,
                                   b_core_client_cpl.w_header.common2.cmpltr_id,
                                   b_core_client_cpl.w_header.common2.cpl_status,
                                   b_core_client_cpl.w_header.common2.cpl_bcm,
                                   b_core_client_cpl.w_header.common2.byte_cnt,
                                   b_core_client_cpl.w_header.common1.pcieTag,
                                   tlp_byte_len_core_client_cpl,
                                   b_core_client_cpl.w_header.common2.poisoned,
                                   b_core_client_cpl.w_header.common2.td,
                                   b_core_client_cpl.w_header.common1.tc,
                                   b_core_client_cpl.w_header.common2.typ,
                                   b_core_client_cpl.w_header.common2.fmt,
                                   b_core_client_cpl.w_header.common2.addr
                                  }
                                                                        )
     ,.din_prot                  ( {`CLIENT_HDR_PROT_WD{1'b0}}          )
     ,.dout                      ( /* not connected */                  )
     ,.dout_prot                 ( b_core_client_cpl.w_headerProt       )
     ,.en                        (1'b1                                  )
     ,.bypass                    (1'b0                                  )
     ,.stall                     (1'b0                                  )
     ,.stallout                  ( /* not connected */                  )
     ,.valid_in                  ( b_core_client_cpl.w_hv               )
     ,.halt_out                  ( /* not connected */                  )
     ,.valid_out                 ( /* not connected */                  )
     ,.halt_in                   (1'b0                                  )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                  )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                  )
     ,.ras_dp_err_log            ( /* not connected */                  )
     ,.ras_dp_err_inj            ( '0                                   )
      );
      
     
     ras_dp_pipe
      #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (1                              ),
      .BUS_PROTECT_CHK_EN        (0                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (K_RAS_PROT_RANGE               ),
      .PROT_WD                   (`CX_RASDP_TRGT1_NP_HDR_PROT_WD ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CX_RASDP_TRGT1_NP_HDR_WD      ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (/* not connected */            )
    ) u_gen_trgt_np_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_app_trgt_np.w_header.order_seq_no.inbound,
                                   b_app_trgt_np.w_header.common3.nw ,
                                  b_app_trgt_np.w_header.common3.cxlsrc,
                                   b_app_trgt_np.w_header.common2.tph_ph,
                                   b_app_trgt_np.w_header.common2.tph_st,
                                   b_app_trgt_np.w_header.flit_mode.dst_sgmt,
                                   b_app_trgt_np.w_header.flit_mode.req_sgmt,
                                   b_app_trgt_np.w_header.common2.last_be ,
                                   b_app_trgt_np.w_header.common2.ats,
                                   b_app_trgt_np.w_header.common2.poisoned,
                                   b_app_trgt_np.w_header.common2.tph_th,
                                   b_app_trgt_np.w_header.common2.td,
                                   b_app_trgt_np.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0],
                                   b_app_trgt_np.w_header.common2.first_be,
                                   b_app_trgt_np.w_header.common4.io_req_in_range,
                                   b_app_trgt_np.w_header.common4.rom_in_range,
                                   b_app_trgt_np.w_header.common4.in_membar_range,
                                   b_app_trgt_np.w_header.common2.dw_len,
                                   b_app_trgt_np.w_header.common2.cpl_status,
                                   b_app_trgt_np.w_header.common1.pfunc_num,
                                   b_app_trgt_np.w_header.common1.pcieTag,
                                   b_app_trgt_np.w_header.common4.req_id,
                                   b_app_trgt_np.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_app_trgt_np.w_header.common1.tc,
                                   b_app_trgt_np.w_header.common2.typ,
                                   b_app_trgt_np.w_header.common2.fmt
                                  }
                                                                        )
     ,.din_prot                  ({`CX_RASDP_TRGT1_NP_HDR_PROT_WD{1'b0}})
     ,.dout                      ( /* not connected */                  )
     ,.dout_prot                 (b_app_trgt_np.w_headerProt            )
     ,.en                        (1'b1                                  )
     ,.bypass                    (1'b0                                  )
     ,.stall                     (1'b0                                  )
     ,.stallout                  ( /* not connected */                  )
     ,.valid_in                  ( b_app_trgt_np.w_hv                   )
     ,.halt_out                  ( /* not connected */                  )
     ,.valid_out                 ( /* not connected */                  )
     ,.halt_in                   (1'b0                                  )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                  )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                  )
     ,.ras_dp_err_log            ( /* not connected */                  )
     ,.ras_dp_err_inj            ( '0                                   )
      );
      
      
   ras_dp_pipe
    #(
      .PIPELINE_TYPE             (0                              ),
      .RESETVAL                  (0                              ),
      .N_STAGES                  (0                              ),
      .CAN_STALL                 (0                              ),
      .RESET_STALL               (0                              ),
      .BUS_PROTECT_GEN_EN        (1                              ),
      .BUS_PROTECT_CHK_EN        (0                              ),
      .PROT_TYPE                 (1                              ), //0: ECC, 1: Parity
      .PROT_RANGE                (K_RAS_PROT_RANGE               ),
      .PROT_WD                   (`CX_RASDP_TRGT1_P_HDR_PROT_WD  ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CX_RASDP_TRGT1_P_HDR_WD       ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (/* not connected */            )
    ) u_gen_trgt_p_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_app_trgt_p.w_header.radmPort.uppr_bytes[`FLT_Q_ADDR_WIDTH-1:0],
                                   b_app_trgt_p.w_header.order_seq_no.inbound,
                                   b_app_trgt_p.w_header.radmPort.uppr_bytes_valid,
                                   b_app_trgt_p.w_header.common2.tph_ph,
                                   b_app_trgt_p.w_header.common2.tph_st,
                                   b_app_trgt_p.w_header.flit_mode.dst_sgmt,
                                   b_app_trgt_p.w_header.flit_mode.req_sgmt,
                                   b_app_trgt_p.w_header.common2.last_be ,
                                   b_app_trgt_p.w_header.common2.ats,
                                   b_app_trgt_p.w_header.common2.poisoned,
                                   b_app_trgt_p.w_header.common2.tph_th,
                                   b_app_trgt_p.w_header.common2.td,
                                   b_app_trgt_p.w_header.common2.addr[`FLT_Q_ADDR_WIDTH-1:0],
                                   b_app_trgt_p.w_header.common2.first_be,
                                   b_app_trgt_p.w_header.common4.rom_in_range,
                                   b_app_trgt_p.w_header.common4.in_membar_range,
                                   b_app_trgt_p.w_header.common2.dw_len,
                                   b_app_trgt_p.w_header.common2.cpl_status,
                                   b_app_trgt_p.w_header.common1.pfunc_num,
                                   b_app_trgt_p.w_header.common1.pcieTag,
                                   b_app_trgt_p.w_header.common4.req_id,
                                   b_app_trgt_p.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_app_trgt_p.w_header.common1.tc,
                                   b_app_trgt_p.w_header.common2.typ,
                                   b_app_trgt_p.w_header.common2.fmt
                                  }
                                                                        )
     ,.din_prot                  ({`CX_RASDP_TRGT1_P_HDR_PROT_WD{1'b0}} )
     ,.dout                      ( /* not connected */                  )
     ,.dout_prot                 (b_app_trgt_p.w_headerProt             )
     ,.en                        (1'b1                                  )
     ,.bypass                    (1'b0                                  )
     ,.stall                     (1'b0                                  )
     ,.stallout                  ( /* not connected */                  )
     ,.valid_in                  ( b_app_trgt_p.w_hv                    )
     ,.halt_out                  ( /* not connected */                  )
     ,.valid_out                 ( /* not connected */                  )
     ,.halt_in                   (1'b0                                  )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                  )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                  )
     ,.ras_dp_err_log            ( /* not connected */                  )
     ,.ras_dp_err_inj            ( '0                                   )
      );
     


  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_APP_CLIENT_CPL)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_client_cpl_delay (
   .b_dst          ( b_DWC_pcie_edmapf_tlp_if_5.master_mp            )
  ,.b_src          ( s_app_client_cpl.slave_mp                       )
  ,.b_clkrst       ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_0_u.master_mp         )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_APP_TRGT_NP)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_trgt_np_delay (
   .b_dst         ( s_app_trgt_np.master_mp                         )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp             )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_1_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_APP_TRGT_P)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_trgt_p_delay (
   .b_dst         ( s_app_trgt_p.master_mp                          )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp             )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_2_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */  (K_COREBUSWD)
  ,.P_HEADERTYPE /* timeout_s */(timeout_s)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_HEADER */   (E_TLP_HEADER)
  ) u_app_trgt_timeout_delay (
   .b_dst         ( b_app_trgt_timeout                              )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_header_if_1.slave_mp      )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_3_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */  (K_COREBUSWD)
  ,.P_HEADERTYPE /* timeout_s */(timeout_s)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_HEADER */   (E_TLP_HEADER)
  ) u_core_app_timeout_delay (
   .b_dst         ( b_core_dma_timeout                              )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_header_if_2.slave_mp      )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_4_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_CORE_CLIENT_CPL)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_client_cpl_delay (
   .b_dst         ( s_core_client_cpl.master_mp                     )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp             )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_5_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_dma_cpl_delay (
   .b_dst         ( b_core_dma_cpl                                  )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_10.slave_mp            )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_6_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */  (K_COREBUSWD)
  ,.P_HEADERTYPE /* timeout_s */(timeout_s)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_HEADER */   (E_TLP_HEADER)
  ) u_core_timeout_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_header_if_0.master_mp     )
  ,.b_src         ( b_core_trgt_timeout                             )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_7_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_trgt_np_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_8.master_mp            )
  ,.b_src         ( s_core_trgt_np.slave_mp                         )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_8_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_trgt_p_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_6.master_mp            )
  ,.b_src         ( s_core_trgt_p.slave_mp                          )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_9_u.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_dma_app_np_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_12.master_mp           )
  ,.b_src         ( b_dma_app_np                                    )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_10_u.master_mp       )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_dma_app_p_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_3.master_mp            )
  ,.b_src         ( b_dma_app_p                                     )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_11_u.master_mp       )
  );

  DWC_pcie_edmapf_tlp_1to2_rtr
   #(
   .P_DST1TARGET /* NOT_DMA */(E_NOT_DMAPF)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_ib_cpl_rtr (
   .b_dst1        ( b_DWC_pcie_edmapf_tlp_if_0.master_mp            )
  ,.b_dst2        ( b_DWC_pcie_edmapf_tlp_if_10.master_mp           )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_9.slave_mp             )
  ,.b_cdm         ( b_cdm                                           )
  ,.b_clk         ( b_clk                                           )
  );

  DWC_pcie_edmapf_tlp_2to1_arb
  
    u_ib_np_arb (
   .b_clkrst      ( b_clk                                           )
  ,.b_dst         ( b_DWC_pcie_edmapf_tlp_if_2.master_mp            )
  ,.b_src1        ( b_DWC_pcie_edmapf_tlp_if_12.slave_mp            )
  ,.b_src2        ( b_DWC_pcie_edmapf_tlp_if_8.slave_mp             )
  );

  DWC_pcie_edmapf_tlp_2to1_arb
  
    u_ib_p_arb (
   .b_clkrst      ( b_clk                                           )
  ,.b_dst         ( b_DWC_pcie_edmapf_tlp_if_4.master_mp            )
  ,.b_src1        ( b_DWC_pcie_edmapf_tlp_if_6.slave_mp             )
  ,.b_src2        ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp             )
  );

  DWC_pcie_edmapf_tlp_1to2_rtr
   #(
   .P_DST1TARGET /* NOT_DMA */  (E_NOT_DMAPF)
  ,.P_HEADERTYPE /* timeout_s */(timeout_s)
  ,.P_TYPE /* E_TLP_HEADER */   (E_TLP_HEADER)
  ) u_ib_timeout_rtr (
   .b_dst1        ( b_DWC_pcie_edmapf_tlp_header_if_1.master_mp     )
  ,.b_dst2        ( b_DWC_pcie_edmapf_tlp_header_if_2.master_mp     )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_header_if_0.slave_mp      )
  ,.b_cdm         ( b_cdm                                           )
  ,.b_clk         ( b_clk                                           )
  );

  DWC_pcie_edmapf_lutMngr
   #(
   .P_MAXTAG /* K_MAX_LUID */(K_MAX_LUID)
  ,.P_MINTAG /* 0 */         (0)
  ) u_mngr (
   .b_cfg         ( b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u.slave_mp   )
  ,.b_clk         ( b_clk                                           )
  ,.b_memAccess   ( b_DWC_pcie_edmapf_ram2p_if_0.master_mp          )
  ,.b_pop         ( b_DWC_pcie_edmapf_crPop_if_0.master_mp          )
  ,.b_push        ( b_DWC_pcie_edmapf_ctxPush_if_0.slave_mp         )
  );

  DWC_pcie_edmapf_damper
   #(
   .P_DAMPER_DP /* 3 */                   (3)
  ,.P_DATATYPE /* logic [K_LUIDMAPWD:1] */(logic [K_LUIDMAPWD:1])
  ,.P_POPTYPE_PEEK /* E_TRUE */           (E_TRUE)
  ) u_mngr_damper (
   .b_pop         ( b_DWC_pcie_edmapf_crPop_if_0.slave_mp           )
  ,.b_popHaltable ( b_DWC_pcie_edmapf_crPop_haltable_if_0.master_mp )
  ,.b_clk         ( b_clk                                           )
  );

  DWC_pcie_edmapf_ram2p_wrapper
   #(
   .DP /* K_LUID */        (K_LUID)
  ,.PW /* K_LUIDWD */      (K_LUIDWD)
  ,.P_FLIPFLOP /* E_TRUE */(E_TRUE)
  ,.WD /* K_LUIDMAPWD */   (K_LUIDMAPWD)
  ) u_mngr_lut (
   .clk           ( b_clk                                           )
  ,.pins          ( b_DWC_pcie_edmapf_ram2p_standard_if_0.slave_mp  )
  );

  DWC_pcie_edmapf_ram2p_interfaceAdapter
   #(
   .DP /* K_LUID*/    (K_LUID)
  ,.PW /* K_LUIDWD */ (K_LUIDWD)
  ,.P_RAS_DATA_BYPASS(E_TRUE)
  ,.P_PIPELINE /* 1 */  (1)
  ,.P_REG_IF /* 0 */    (0)
  ,.WD /* K_LUIDMAPWD */(K_LUIDMAPWD)
  ) u_mngr_lut_adaptar (
   .b_clk         ( b_clk                                           )
  ,.b_external    ( b_DWC_pcie_edmapf_ram2p_standard_if_0.master_mp )
  ,.b_internal    ( b_DWC_pcie_edmapf_ram2p_if_0.slave_mp           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_13_u.master_mp       )
  );

  DWC_pcie_edmapf_dtarg_arb_tagger
  
    u_tagger (
   .b_clk         ( b_clk                                           )
  ,.b_in          ( b_DWC_pcie_edmapf_tlp_if_7.slave_mp             )
  ,.b_out         ( b_DWC_pcie_edmapf_tlp_if_1.master_mp            )
  ,.b_push        ( b_DWC_pcie_edmapf_ctxPush_if_0.master_mp        )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_TAGGER_TRGT_NP)
  ,.P_STAGES /* E_FEED_ALL */ (E_FEED_ALL)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_tagger_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_7.master_mp            )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp             )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_12_u.master_mp       )
  );

  DWC_pcie_edmapf_untagger
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_DTAG /* K_LUIDMAPWD */  (K_LUIDMAPWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_TAGTYPE /* E_TAG_LUID */(E_TAG_LUID)
  ,.P_TAGWD /* K_LUIDWD */    (K_LUIDWD)
  ) u_untagger (
   .b_clk         ( b_clk                                           )
  ,.b_dst         ( b_DWC_pcie_edmapf_tlp_if_11.master_mp           )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp             )
  ,.b_tag         ( b_DWC_pcie_edmapf_crPop_haltable_if_0.slave_mp  )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /* E_FEED_HALT */(E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_untagger_delay (
   .b_dst         ( b_DWC_pcie_edmapf_tlp_if_9.master_mp            )
  ,.b_src         ( b_DWC_pcie_edmapf_tlp_if_11.slave_mp            )
  ,.b_clkrst      ( b_clk                                           )
  ,.b_ras         ( b_DWC_pcie_edmapf_rasdp_if_14_u.master_mp       )
  );

// SNPS_SysML_CODE_START
  
  /*
    Tying unused signals of the interface
  */
  always_comb begin : c_tyingInterfaces_PROC
    b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u.w_update_p = '0;
    b_DWC_pcie_edmapf_tagMngr_cfg_if_0_u.w_mode     = E_TAGMNGR_NORMAL;
  end : c_tyingInterfaces_PROC

// SNPS_SysML_CODE_END

endmodule
