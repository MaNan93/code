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
// ---    $Revision: #2 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_outboundInterconnect.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_outboundInterconnect
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_tlp_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tlp_if.slave_mp     b_app_client_np
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_app_client_p
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_app_dma_cpl
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_app_trgt_cpl
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp   b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_core_client_np
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_core_client_p
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_core_trgt_cpl
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_dma_core_np
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_dma_core_p
  ,DWC_pcie_edmapf_rasdp_if.master_mp  b_ras
  );

  // ##########################################################################
  //                               Local Parameters                          
  // ##########################################################################
    localparam N_OB_CHK = 6 ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_0_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_1_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_2_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_3_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_4_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_5_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_6_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_7_u();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_8_u();
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
                        )          s_core_client_p         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_core_client_np        ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_app_client_p          ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_app_client_np         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_core_trgt_cpl         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )          s_app_trgt_cpl          ();
                        
  ras_dp_err_log_t [N_OB_CHK-1:0]  ob_ras_dp_err_logs        ;
    ras_dp_err_inj_t               ob_ras_dp_err_inj         ;
  logic [12:0] tlp_byte_len_core_client_p ;
  logic [12:0] tlp_byte_len_core_client_np;


  // ##########################################################################
  //                              Wiring Connections                        
  // ##########################################################################
        assign s_app_client_p.w_header       = b_app_client_p.w_header     ;
        assign s_app_client_p.w_hv           = b_app_client_p.w_hv         ;
        assign s_app_client_p.w_data         = b_app_client_p.w_data       ;
        assign s_app_client_p.w_dv           = b_app_client_p.w_dv         ;
        assign s_app_client_p.w_eot          = b_app_client_p.w_eot        ;
        assign b_app_client_p.w_halt         = s_app_client_p.w_halt       ;
        assign s_app_client_p.w_headerProt   = '0                        ;
      
        assign s_app_client_np.w_header      = b_app_client_np.w_header    ;
        assign s_app_client_np.w_hv          = b_app_client_np.w_hv        ;
        assign s_app_client_np.w_data        = b_app_client_np.w_data      ;
        assign s_app_client_np.w_dv          = b_app_client_np.w_dv        ;
        assign s_app_client_np.w_eot         = b_app_client_np.w_eot       ;
        assign b_app_client_np.w_halt        = s_app_client_np.w_halt      ;
        assign s_app_client_np.w_headerProt  = '0                        ;
      
      
        assign b_core_client_np.w_header     = s_core_client_np.w_header   ;
        assign b_core_client_np.w_hv         = s_core_client_np.w_hv       ;
        assign b_core_client_np.w_data       = s_core_client_np.w_data     ;
        assign b_core_client_np.w_dv         = s_core_client_np.w_dv       ;
        assign b_core_client_np.w_eot        = s_core_client_np.w_eot      ;
        assign s_core_client_np.w_halt       = b_core_client_np.w_halt     ;
      
        assign b_core_client_p.w_header      = s_core_client_p.w_header    ;
        assign b_core_client_p.w_hv          = s_core_client_p.w_hv        ;
        assign b_core_client_p.w_data        = s_core_client_p.w_data      ;
        assign b_core_client_p.w_dv          = s_core_client_p.w_dv        ;
        assign b_core_client_p.w_eot         = s_core_client_p.w_eot       ;
        assign s_core_client_p.w_halt        = b_core_client_p.w_halt      ;
      
      
      
        assign b_app_trgt_cpl.w_header       = s_app_trgt_cpl.w_header     ;
        assign b_app_trgt_cpl.w_hv           = s_app_trgt_cpl.w_hv         ;
        assign b_app_trgt_cpl.w_data         = s_app_trgt_cpl.w_data       ;
        assign b_app_trgt_cpl.w_dv           = s_app_trgt_cpl.w_dv         ;
        assign b_app_trgt_cpl.w_eot          = s_app_trgt_cpl.w_eot        ;
        assign s_app_trgt_cpl.w_halt         = b_app_trgt_cpl.w_halt       ;
      
      
        assign s_core_trgt_cpl.w_header      = b_core_trgt_cpl.w_header    ;
        assign s_core_trgt_cpl.w_hv          = b_core_trgt_cpl.w_hv        ;
        assign s_core_trgt_cpl.w_data        = b_core_trgt_cpl.w_data      ;
        assign s_core_trgt_cpl.w_dv          = b_core_trgt_cpl.w_dv        ;
        assign s_core_trgt_cpl.w_eot         = b_core_trgt_cpl.w_eot       ;
        assign b_core_trgt_cpl.w_halt        = s_core_trgt_cpl.w_halt      ;
        assign s_core_trgt_cpl.w_headerProt = '0                           ;
   
        assign tlp_byte_len_core_client_p  = (b_core_client_p.w_header.dma.req  == E_DMA_BYPASS) ? b_core_client_p.w_header.xadmPort.tlp_byte_len  : f_tlp_dwlen2bytelen(b_core_client_p.w_header.common2.dw_len );
        assign tlp_byte_len_core_client_np = (b_core_client_np.w_header.dma.req == E_DMA_BYPASS) ? b_core_client_np.w_header.xadmPort.tlp_byte_len : f_tlp_dwlen2bytelen(b_core_client_np.w_header.common2.dw_len);
    
  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################
  

  assign ob_ras_dp_err_logs [N_OB_CHK-1:3]  = { b_DWC_pcie_edmapf_rasdp_if_5_u.w_ras_dp_err_log,
                                                b_DWC_pcie_edmapf_rasdp_if_4_u.w_ras_dp_err_log,
                                                b_DWC_pcie_edmapf_rasdp_if_3_u.w_ras_dp_err_log
                                               };
  assign b_DWC_pcie_edmapf_rasdp_if_5_u.w_ras_dp_err_inj = ob_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_4_u.w_ras_dp_err_inj = ob_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_3_u.w_ras_dp_err_inj = ob_ras_dp_err_inj;

  assign b_DWC_pcie_edmapf_rasdp_if_0_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_1_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_2_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_6_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_7_u.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_8_u.w_ras_dp_err_inj = '0;
  
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_OB_CHK             ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (0                    )
  ) u_ob_ras_dp_err_mgr (                                 
    .clk                        ( b_clk.w_aux_clk         )
   ,.rst_n                      ( b_clk.w_reset_n         )
   ,.out_ras_dp_wake_up         ( /* not connected */     )
   ,.in_ras_dp_err_inj          ( b_ras.w_ras_dp_err_inj  )
   ,.out_ras_dp_err_inj         ( ob_ras_dp_err_inj       )
  ,.in_ras_dp_err_log           ( ob_ras_dp_err_logs      )
  ,.out_ras_dp_err_log          ( b_ras.w_ras_dp_err_log  )
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
      .RAS_DP_PROT_CHK_ID_BASE   (RAS_CHK_ID_CLIENT_NP           )
    ) u_chk_client_np_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_app_client_np.w_header.common2.tph_th,
                                   b_app_client_np.w_header.common2.tph_st,
                                   b_app_client_np.w_header.common2.tph_ph,
                                   b_app_client_np.w_header.common1.pfunc_num,
                                   b_app_client_np.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_app_client_np.w_header.common2.ats,
                                   b_app_client_np.w_header.common3.nw,
                                   b_app_client_np.w_header.xadmPort.addr_align_en,
                                   b_app_client_np.w_header.common2.last_be,
                                   b_app_client_np.w_header.common2.first_be,
                                   b_app_client_np.w_header.common2.cmpltr_id,
                                   b_app_client_np.w_header.common2.cpl_status,
                                   b_app_client_np.w_header.common2.cpl_bcm,
                                   b_app_client_np.w_header.common2.byte_cnt,
                                   b_app_client_np.w_header.common1.pcieTag,
                                   b_app_client_np.w_header.xadmPort.tlp_byte_len,
                                   b_app_client_np.w_header.common2.poisoned,
                                   b_app_client_np.w_header.common2.td,
                                   b_app_client_np.w_header.common1.tc,
                                   b_app_client_np.w_header.common2.typ,
                                   b_app_client_np.w_header.common2.fmt,
                                   b_app_client_np.w_header.common2.addr
                                  }
                                                                      )
     ,.din_prot                  ( b_app_client_np.w_headerProt       )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( /* not connected */                )
     ,.en                        (1'b1                                )
     ,.bypass                    (1'b0                                )
     ,.stall                     (1'b0                                )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_app_client_np.w_hv               )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   (1'b0                                )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( ob_ras_dp_err_logs[0]              )
     ,.ras_dp_err_inj            ( ob_ras_dp_err_inj                  )
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
      .PROT_WD                   (`CLIENT_HDR_PROT_WD            ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CLIENT_HDR_WD                 ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (RAS_CHK_ID_CLIENT_P            )
    ) u_chk_client_p_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_app_client_p.w_header.common2.tph_th,
                                   b_app_client_p.w_header.common2.tph_st,
                                   b_app_client_p.w_header.common2.tph_ph,
                                   b_app_client_p.w_header.common1.pfunc_num,
                                   b_app_client_p.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_app_client_p.w_header.common2.ats,
                                   b_app_client_p.w_header.common3.nw,
                                   b_app_client_p.w_header.xadmPort.addr_align_en,
                                   b_app_client_p.w_header.common2.last_be,
                                   b_app_client_p.w_header.common2.first_be,
                                   b_app_client_p.w_header.common2.cmpltr_id,
                                   b_app_client_p.w_header.common2.cpl_status,
                                   b_app_client_p.w_header.common2.cpl_bcm,
                                   b_app_client_p.w_header.common2.byte_cnt,
                                   b_app_client_p.w_header.common1.pcieTag,
                                   b_app_client_p.w_header.xadmPort.tlp_byte_len,
                                   b_app_client_p.w_header.common2.poisoned,
                                   b_app_client_p.w_header.common2.td,
                                   b_app_client_p.w_header.common1.tc,
                                   b_app_client_p.w_header.common2.typ,
                                   b_app_client_p.w_header.common2.fmt,
                                   b_app_client_p.w_header.common2.addr
                                  }
                                                                      )
     ,.din_prot                  ( b_app_client_p.w_headerProt        )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( /* not connected */                )
     ,.en                        (1'b1                                )
     ,.bypass                    (1'b0                                )
     ,.stall                     (1'b0                                )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_app_client_p.w_hv                )
     ,.halt_out                  ( /* not connected */                )      
     ,.valid_out                 ( /* not connected */                )      
     ,.halt_in                   (1'b0                                )      
     ,.ras_dp_err_inband_kbd_in  (1'b0                                )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( ob_ras_dp_err_logs[1]              )
     ,.ras_dp_err_inj            ( ob_ras_dp_err_inj                  )
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
      .PROT_WD                   (`CX_RASDP_TRGT1_CPL_HDR_PROT_WD),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CX_RASDP_TRGT1_CPL_HDR_WD     ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   (RAS_CHK_ID_TRGT_CPL            )
    ) u_chk_trgt_cpl_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_core_trgt_cpl.w_header.order_seq_no.inbound,
                                   b_core_trgt_cpl.w_header.flit_mode.cpl_sgmt,
                                   b_core_trgt_cpl.w_header.flit_mode.dst_sgmt,
                                   b_core_trgt_cpl.w_header.common4.cpl_last,
                                   b_core_trgt_cpl.w_header.common2.poisoned,
                                   b_core_trgt_cpl.w_header.common2.td,
                                   b_core_trgt_cpl.w_header.common2.addr[`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0],
                                   b_core_trgt_cpl.w_header.common2.cpl_bcm,
                                   b_core_trgt_cpl.w_header.common2.cmpltr_id,
                                   b_core_trgt_cpl.w_header.common2.byte_cnt,
                                   b_core_trgt_cpl.w_header.common2.dw_len,
                                   b_core_trgt_cpl.w_header.common2.cpl_status,
                                   b_core_trgt_cpl.w_header.common1.pfunc_num,
                                   b_core_trgt_cpl.w_header.common1.pcieTag,
                                   b_core_trgt_cpl.w_header.common4.req_id,
                                   b_core_trgt_cpl.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_core_trgt_cpl.w_header.common1.tc,
                                   b_core_trgt_cpl.w_header.common2.typ,
                                   b_core_trgt_cpl.w_header.common2.fmt
                                  }
                                                                      )
     ,.din_prot                  ( b_core_trgt_cpl.w_headerProt       )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( /* not connected */                )
     ,.en                        (1'b1                                )
     ,.bypass                    (1'b0                                )
     ,.stall                     (1'b0                                )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_core_trgt_cpl.w_hv               )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   (1'b0                                )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( ob_ras_dp_err_logs[2]              )
     ,.ras_dp_err_inj            ( ob_ras_dp_err_inj                  )
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
      .RAS_DP_PROT_CHK_ID_BASE   ( /* not connected */           )
    ) u_gen_client_np_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_core_client_np.w_header.common2.tph_th,
                                   b_core_client_np.w_header.common2.tph_st,
                                   b_core_client_np.w_header.common2.tph_ph,
                                   b_core_client_np.w_header.common1.pfunc_num,
                                   b_core_client_np.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_core_client_np.w_header.common2.ats,
                                   b_core_client_np.w_header.common3.nw,
                                   b_core_client_np.w_header.xadmPort.addr_align_en,
                                   b_core_client_np.w_header.common2.last_be,
                                   b_core_client_np.w_header.common2.first_be,
                                   b_core_client_np.w_header.common2.cmpltr_id,
                                   b_core_client_np.w_header.common2.cpl_status,
                                   b_core_client_np.w_header.common2.cpl_bcm,
                                   b_core_client_np.w_header.common2.byte_cnt,
                                   b_core_client_np.w_header.common1.pcieTag,
                                   tlp_byte_len_core_client_np,
                                   b_core_client_np.w_header.common2.poisoned,
                                   b_core_client_np.w_header.common2.td,
                                   b_core_client_np.w_header.common1.tc,
                                   b_core_client_np.w_header.common2.typ,
                                   b_core_client_np.w_header.common2.fmt,
                                   b_core_client_np.w_header.common2.addr
                                  }
                                                                      )
     ,.din_prot                  ( {`CLIENT_HDR_PROT_WD{1'b0}}        )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( b_core_client_np.w_headerProt      )
     ,.en                        (1'b1                                )
     ,.bypass                    (1'b0                                )
     ,.stall                     (1'b0                                )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_core_client_np.w_hv              )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   (1'b0                                )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( /* not connected */                )
     ,.ras_dp_err_inj            ( '0                                 )
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
      .PROT_WD                   (`CLIENT_HDR_PROT_WD            ),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CLIENT_HDR_WD                 ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   ( /* not connected*/            )
    ) u_gen_client_p_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_core_client_p.w_header.common2.tph_th,
                                   b_core_client_p.w_header.common2.tph_st,
                                   b_core_client_p.w_header.common2.tph_ph,
                                   b_core_client_p.w_header.common1.pfunc_num,
                                   b_core_client_p.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_core_client_p.w_header.common2.ats,
                                   b_core_client_p.w_header.common3.nw,
                                   b_core_client_p.w_header.xadmPort.addr_align_en,
                                   b_core_client_p.w_header.common2.last_be,
                                   b_core_client_p.w_header.common2.first_be,
                                   b_core_client_p.w_header.common2.cmpltr_id,
                                   b_core_client_p.w_header.common2.cpl_status,
                                   b_core_client_p.w_header.common2.cpl_bcm,
                                   b_core_client_p.w_header.common2.byte_cnt,
                                   b_core_client_p.w_header.common1.pcieTag,
                                   tlp_byte_len_core_client_p,
                                   b_core_client_p.w_header.common2.poisoned,
                                   b_core_client_p.w_header.common2.td,
                                   b_core_client_p.w_header.common1.tc,
                                   b_core_client_p.w_header.common2.typ,
                                   b_core_client_p.w_header.common2.fmt,
                                   b_core_client_p.w_header.common2.addr
                                  }
                                                                      )
     ,.din_prot                  ( {`CLIENT_HDR_PROT_WD{1'b0}}        )
     ,.dout                      ( /* not connected */                )
     ,.dout_prot                 ( b_core_client_p.w_headerProt       )
     ,.en                        (1'b1                                )
     ,.bypass                    (1'b0                                )
     ,.stall                     (1'b0                                )
     ,.stallout                  ( /* not connected */                )
     ,.valid_in                  ( b_core_client_p.w_hv               )
     ,.halt_out                  ( /* not connected */                )
     ,.valid_out                 ( /* not connected */                )
     ,.halt_in                   (1'b0                                )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                )
     ,.ras_dp_err_inband_kbd_out ( /* not connected */                )
     ,.ras_dp_err_log            ( /* not connected */                )
     ,.ras_dp_err_inj            ( '0                                 )
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
      .PROT_WD                   (`CX_RASDP_TRGT1_CPL_HDR_PROT_WD),
      .PARITY_MODE               (K_RAS_PARITY_MODE              ),
      .PROT_CORRECT_EN           (0                              ),
      .TOTAL_WIDTH               (`CX_RASDP_TRGT1_CPL_HDR_WD     ),
      .EXCLUDE_PROT_WIDTH        (0                              ),
      .RAS_DP_PROT_CHK_ID_BASE   ( /* not connected */           )
    ) u_gen_trgt_cpl_0_hdr (
      .clk                       ( b_clk.w_aux_clk               )
     ,.rst_n                     ( b_clk.w_reset_n               )
     ,.din                       (
                                  {
                                   b_app_trgt_cpl.w_header.order_seq_no.inbound,
                                   b_app_trgt_cpl.w_header.flit_mode.cpl_sgmt,
                                   b_app_trgt_cpl.w_header.flit_mode.dst_sgmt,
                                   b_app_trgt_cpl.w_header.common4.cpl_last,
                                   b_app_trgt_cpl.w_header.common2.poisoned,
                                   b_app_trgt_cpl.w_header.common2.td,
                                   b_app_trgt_cpl.w_header.common2.addr[`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0],
                                   b_app_trgt_cpl.w_header.common2.cpl_bcm,
                                   b_app_trgt_cpl.w_header.common2.cmpltr_id,
                                   b_app_trgt_cpl.w_header.common2.byte_cnt,
                                   b_app_trgt_cpl.w_header.common2.dw_len,
                                   b_app_trgt_cpl.w_header.common2.cpl_status,
                                   b_app_trgt_cpl.w_header.common1.pfunc_num,
                                   b_app_trgt_cpl.w_header.common1.pcieTag,
                                   b_app_trgt_cpl.w_header.common4.req_id,
                                   b_app_trgt_cpl.w_header.common1.attr [`FLT_Q_ATTR_WIDTH-1:0],
                                   b_app_trgt_cpl.w_header.common1.tc,
                                   b_app_trgt_cpl.w_header.common2.typ,
                                   b_app_trgt_cpl.w_header.common2.fmt
                                  }
                                                                         )
     ,.din_prot                  ({`CX_RASDP_TRGT1_CPL_HDR_PROT_WD{1'b0}})
     ,.dout                      ( /* not connected */                   )
     ,.dout_prot                 (b_app_trgt_cpl.w_headerProt            )
     ,.en                        (1'b1                                   )
     ,.bypass                    (1'b0                                   )
     ,.stall                     (1'b0                                   )
     ,.stallout                  ( /* not connected */                   )
     ,.valid_in                  ( b_app_trgt_cpl.w_hv                   )
     ,.halt_out                  ( /* not connected */                   )
     ,.valid_out                 ( /* not connected */                   )
     ,.halt_in                   (1'b0                                   )
     ,.ras_dp_err_inband_kbd_in  (1'b0                                   )
     ,.ras_dp_err_inband_kbd_out (  /* not connected */                  )
     ,.ras_dp_err_log            (  /* not connected */                  )
     ,.ras_dp_err_inj            ( '0                                    )
      );
     



  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_client_np_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_8.master_mp     )
  ,.b_src    ( s_app_client_np.slave_mp                 )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_0_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_client_p (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_1.master_mp     )
  ,.b_src    ( s_app_client_p.slave_mp                  )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_1_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_dma_cpl_delay (
   .b_dst    ( b_app_dma_cpl                            )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_7.slave_mp      )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_2_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_APP_TRGT_CPL)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_app_trgt_cpl_delay (
   .b_dst    ( s_app_trgt_cpl.master_mp                 )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp      )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_3_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_CORE_CLIENT_NP)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_client_np_delay (
   .b_dst    ( s_core_client_np.master_mp               )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp      )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_4_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_CHK_EN              (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID        (RAS_CHK_ID_CORE_CLIENT_P)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_client_p_delay (
   .b_dst    ( s_core_client_p.master_mp                )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_6.slave_mp      )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_5_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_RAS_GEN_EN              (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_core_trgt_cpl_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_3.master_mp     )
  ,.b_src    ( s_core_trgt_cpl.slave_mp                 )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_6_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_dma_core_np_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_0.master_mp     )
  ,.b_src    ( b_dma_core_np                            )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_7_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* K_COREBUSWD */(K_COREBUSWD)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_STAGES /* E_FEED_NONE */(E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_dma_core_p_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_2.master_mp     )
  ,.b_src    ( b_dma_core_p                             )
  ,.b_clkrst ( b_clk                                    )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_8_u.master_mp )
  );

  DWC_pcie_edmapf_tlp_1to2_rtr
   #(
   .P_DST1TARGET /* RD_DATA */(E_DMAPF_RD_DATA)
  ,.P_HEADERTYPE /* xradm_s */(xradm_s)
  ,.P_TYPE /* E_TLP_FULL */   (E_TLP_FULL)
  ) u_ob_cpl_rtr (
   .b_dst1   ( b_DWC_pcie_edmapf_tlp_if_7.master_mp     )
  ,.b_dst2   ( b_DWC_pcie_edmapf_tlp_if_4.master_mp     )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp      )
  ,.b_cdm    ( b_cdm                                    )
  ,.b_clk    ( b_clk                                    )
  );

  DWC_pcie_edmapf_tlp_2to1_arb
  
    u_ob_np_arb (
   .b_clkrst ( b_clk                                    )
  ,.b_dst    ( b_DWC_pcie_edmapf_tlp_if_5.master_mp     )
  ,.b_src1   ( b_DWC_pcie_edmapf_tlp_if_8.slave_mp      )
  ,.b_src2   ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp      )
  );

  DWC_pcie_edmapf_tlp_2to1_arb
  
    u_ob_p_arb (
   .b_clkrst ( b_clk                                    )
  ,.b_dst    ( b_DWC_pcie_edmapf_tlp_if_6.master_mp     )
  ,.b_src1   ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp      )
  ,.b_src2   ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp      )
  );

// SNPS_SysML_CODE_START
  
  /*
    Tying unused signals of the interface
  */

// SNPS_SysML_CODE_END

endmodule
