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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_interconnect.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_header_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_wresp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_hard_stop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_status_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_interconnect
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tlp_if.slave_mp             b_app_client_cpl
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_app_client_np
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_app_client_p
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_app_trgt_cpl
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_app_trgt_np
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_app_trgt_p
  ,DWC_pcie_edmapf_tlp_header_if.master_mp     b_app_trgt_timeout
  ,DWC_pcie_edmapf_genericData_if.master_mp    b_clientPending
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp         b_core_cdm
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_core_client_cpl
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_core_client_np
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_core_client_p
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_core_trgt_cpl
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_core_trgt_np
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_core_trgt_p
  ,DWC_pcie_edmapf_tlp_header_if.slave_mp      b_core_trgt_timeout
  ,DWC_pcie_edmapf_crgb_if.slave_mp            b_crgb
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdBuffer_ram0
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_c2w_lut_ram
  ,DWC_pcie_edmapf_hard_stop_if.slave_mp       b_rdEng_hard_stop
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_ll_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_msi_lut_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_ovrl_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_rdEng_stsh_lut_ram
  ,DWC_pcie_edmapf_status_if.master_mp         b_status_rd
  ,DWC_pcie_edmapf_status_if.master_mp         b_status_wr
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_c2w_lut_ram
  ,DWC_pcie_edmapf_hard_stop_if.slave_mp       b_wrEng_hard_stop
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_ll_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_msi_lut_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_ovrl_ram
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_wrEng_stsh_lut_ram
  ,DWC_pcie_edmapf_tlp_wresp_if.slave_mp       b_wresp
  ,DWC_pcie_edmapf_rasdp_if.master_mp          b_ras
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_cdmregs_if    b_DWC_pcie_edmapf_cdmregs_if_0     ();
  DWC_pcie_edmapf_rasdp_if      b_DWC_pcie_edmapf_rasdp_if_0_u     ();
  DWC_pcie_edmapf_rasdp_if      b_DWC_pcie_edmapf_rasdp_if_1_u     ();
  DWC_pcie_edmapf_rasdp_if      b_DWC_pcie_edmapf_rasdp_if_2_u     ();
  DWC_pcie_edmapf_tlp_bypass_if b_DWC_pcie_edmapf_tlp_bypass_if_0_u();
  DWC_pcie_edmapf_tlp_header_if #(
     .P_HEADERTYPE(timeout_s)
                               )  b_DWC_pcie_edmapf_tlp_header_if_0  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )         b_DWC_pcie_edmapf_tlp_if_0         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
    ,.P_HDR_PROT_WD(`CLIENT_HDR_PROT_WD)
                        )         b_DWC_pcie_edmapf_tlp_if_1         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )         b_DWC_pcie_edmapf_tlp_if_2         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )         b_DWC_pcie_edmapf_tlp_if_3         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )         b_DWC_pcie_edmapf_tlp_if_4         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )         b_DWC_pcie_edmapf_tlp_if_5         ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (K_COREBUSWD)
    ,.P_HEADERTYPE(xradm_s)
                        )         b_DWC_pcie_edmapf_tlp_if_6         ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD (K_DMATAGWD)
                         )        b_DWC_pcie_edmapf_wack_if_0        ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(K_DMACHANWD)
    ,.P_TAGWD (K_DMATAGWD)
                         )        b_DWC_pcie_edmapf_wack_if_1        ();
  // ##########################################################################
  //                               Local Parameters                          
  // ##########################################################################
    localparam N_IC_CHK = 3 ;
  
  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################
    ras_dp_err_log_t [N_IC_CHK-1:0]  inter_ras_dp_err_logs     ;
      ras_dp_err_inj_t               inter_ras_dp_err_inj      ;

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################
  
    assign inter_ras_dp_err_logs = { b_DWC_pcie_edmapf_rasdp_if_0_u.w_ras_dp_err_log,
                                     b_DWC_pcie_edmapf_rasdp_if_1_u.w_ras_dp_err_log,
                                     b_DWC_pcie_edmapf_rasdp_if_2_u.w_ras_dp_err_log
                                    };
    assign b_DWC_pcie_edmapf_rasdp_if_0_u.w_ras_dp_err_inj = inter_ras_dp_err_inj;
    assign b_DWC_pcie_edmapf_rasdp_if_1_u.w_ras_dp_err_inj = inter_ras_dp_err_inj;
    assign b_DWC_pcie_edmapf_rasdp_if_2_u.w_ras_dp_err_inj = inter_ras_dp_err_inj;
    
    ras_dp_err_mgr
    
    #(
     .BLOCK_RAS_DP_PROT_CHK_N         (N_IC_CHK                  ),
     .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                         )
    ) u_edmapf_ras_dp_err_mgr (                                 
      .clk                            ( b_clk.w_aux_clk          )
     ,.rst_n                          ( b_clk.w_reset_n          )
     ,.out_ras_dp_wake_up             ( /*Not Connected*/        )
     ,.in_ras_dp_err_inj              ( b_ras.w_ras_dp_err_inj   )
     ,.out_ras_dp_err_inj             ( inter_ras_dp_err_inj     )
    ,.in_ras_dp_err_log               ( inter_ras_dp_err_logs    )
    ,.out_ras_dp_err_log              ( b_ras.w_ras_dp_err_log   )
    );

  DWC_pcie_edmapf_cdm_delay
  
    u_cdm_delay (
   .b_clk                ( b_clk                                         )
  ,.b_dst                ( b_DWC_pcie_edmapf_cdmregs_if_0.master_mp      )
  ,.b_src                ( b_core_cdm                                    )
  );

  DWC_pcie_edmapf
  
    u_hyperDMA_core (
   .b_cdm                ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp       )
  ,.b_client0_in         ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp           )
  ,.b_clk                ( b_clk                                         )
  ,.b_crgb               ( b_crgb                                        )
  ,.b_npReq_out          ( b_DWC_pcie_edmapf_tlp_if_4.master_mp          )
  ,.b_pReqOnPipe         ( b_DWC_pcie_edmapf_wack_if_0.master_mp         )
  ,.b_pReq_out           ( b_DWC_pcie_edmapf_tlp_if_5.master_mp          )
  ,.b_rdBuffer_ram0      ( b_rdBuffer_ram0                               )
  ,.b_rdEng_c2w_lut_ram  ( b_rdEng_c2w_lut_ram                           )
  ,.b_rdEng_hard_stop    ( b_rdEng_hard_stop                             )
  ,.b_rdEng_ll_ram       ( b_rdEng_ll_ram                                )
  ,.b_rdEng_msi_ram      ( b_rdEng_msi_lut_ram                           )
  ,.b_rdEng_ovrl_ram     ( b_rdEng_ovrl_ram                              )
  ,.b_rdEng_stsh_lut_ram ( b_rdEng_stsh_lut_ram                          )
  ,.b_status_rd          ( b_status_rd                                   )
  ,.b_status_wr          ( b_status_wr                                   )
  ,.b_timeout            ( b_DWC_pcie_edmapf_tlp_header_if_0.slave_mp    )
  ,.b_trgt_in            ( b_DWC_pcie_edmapf_tlp_if_6.slave_mp           )
  ,.b_trgt_np_out        ( b_DWC_pcie_edmapf_tlp_if_2.master_mp          )
  ,.b_trgt_p_out         ( b_DWC_pcie_edmapf_tlp_if_3.master_mp          )
  ,.b_wrEng_c2w_lut_ram  ( b_wrEng_c2w_lut_ram                           )
  ,.b_wrEng_hard_stop    ( b_wrEng_hard_stop                             )
  ,.b_wrEng_ll_ram       ( b_wrEng_ll_ram                                )
  ,.b_wrEng_msi_ram      ( b_wrEng_msi_lut_ram                           )
  ,.b_wrEng_ovrl_ram     ( b_wrEng_ovrl_ram                              )
  ,.b_wrEng_stsh_lut_ram ( b_wrEng_stsh_lut_ram                          )
  ,.b_wresp              ( b_wresp                                       )
  ,.b_ras                ( b_DWC_pcie_edmapf_rasdp_if_0_u.master_mp      )
  );

  DWC_pcie_edmapf_inboundInterconnect
  
    u_ib_interconnect (
   .b_app_client_cpl     ( b_app_client_cpl                              )
  ,.b_app_trgt_np        ( b_app_trgt_np                                 )
  ,.b_app_trgt_p         ( b_app_trgt_p                                  )
  ,.b_app_trgt_timeout   ( b_app_trgt_timeout                            )
  ,.b_cdm                ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp       )
  ,.b_clk                ( b_clk                                         )
  ,.b_core_client_cpl    ( b_core_client_cpl                             )
  ,.b_core_dma_cpl       ( b_DWC_pcie_edmapf_tlp_if_0.master_mp          )
  ,.b_core_dma_timeout   ( b_DWC_pcie_edmapf_tlp_header_if_0.master_mp   )
  ,.b_core_trgt_np       ( b_core_trgt_np                                )
  ,.b_core_trgt_p        ( b_core_trgt_p                                 )
  ,.b_core_trgt_timeout  ( b_core_trgt_timeout                           )
  ,.b_dma_app_np         ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp           )
  ,.b_dma_app_p          ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp           )
  ,.b_ras                ( b_DWC_pcie_edmapf_rasdp_if_1_u.master_mp      )
  );

  DWC_pcie_edmapf_outboundInterconnect
  
    u_ob_interconnect (
   .b_app_client_np      ( b_app_client_np                               )
  ,.b_app_client_p       ( b_app_client_p                                )
  ,.b_app_dma_cpl        ( b_DWC_pcie_edmapf_tlp_if_6.master_mp          )
  ,.b_app_trgt_cpl       ( b_app_trgt_cpl                                )
  ,.b_cdm                ( b_DWC_pcie_edmapf_cdmregs_if_0.slave_mp       )
  ,.b_clk                ( b_clk                                         )
  ,.b_core_client_np     ( b_core_client_np                              )
  ,.b_core_client_p      ( b_DWC_pcie_edmapf_tlp_if_1.master_mp          )
  ,.b_core_trgt_cpl      ( b_core_trgt_cpl                               )
  ,.b_dma_core_np        ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp           )
  ,.b_dma_core_p         ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp           )
  ,.b_ras                ( b_DWC_pcie_edmapf_rasdp_if_2_u.master_mp      )
  );

  DWC_pcie_edmapf_pReqMonitor
  
    u_pReqClientPending (
   .b_clientPending      ( b_clientPending                               )
  ,.b_clk                ( b_clk                                         )
  ,.b_reqIn              ( b_DWC_pcie_edmapf_wack_if_0.slave_mp          )
  ,.b_reqOut             ( b_DWC_pcie_edmapf_wack_if_1.slave_mp          )
  );

  DWC_pcie_edmapf_mwr2wack
   #(
   .P_CHANWD(K_DMACHANWD)
  ,.P_TAGWD (K_DMATAGWD)
  ) u_pReq_ack (
   .b_clk                ( b_clk                                         )
  ,.b_in                 ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp           )
  ,.b_out                ( b_core_client_p                               )
  ,.b_wack               ( b_DWC_pcie_edmapf_wack_if_1.master_mp         )
  );

// SNPS_SysML_CODE_START
  
  /*
    Tying unused signals of the interface
  */
  always_comb begin : c_tyingInterfaces_PROC
    b_DWC_pcie_edmapf_tlp_bypass_if_0_u.w_data       = '0;
    b_DWC_pcie_edmapf_tlp_bypass_if_0_u.w_dv         = '0;
    b_DWC_pcie_edmapf_tlp_bypass_if_0_u.w_eot        = '0;
    b_DWC_pcie_edmapf_tlp_bypass_if_0_u.w_header     = '0;
    b_DWC_pcie_edmapf_tlp_bypass_if_0_u.w_hv         = '0;
    b_DWC_pcie_edmapf_tlp_bypass_if_0_u.w_headerProt = '0;
  end : c_tyingInterfaces_PROC
  
// SNPS_SysML_CODE_END

endmodule
