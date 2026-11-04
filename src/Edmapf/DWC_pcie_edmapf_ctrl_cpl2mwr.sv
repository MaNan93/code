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
// ---    $Revision: #9 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_cpl2mwr.sv#9 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_cpl2mwr
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter         type P_CTXTYPE = dmaWrEngCtx_s
  ,parameter      type P_TLPCTXTYPE = dmaTlpCtxWr_s
  ,parameter         type P_TLPTYPE = xradm_s
  ,parameter          P_C2W_BUFF_DP = 3
  ,parameter                 P_CHAN = 8
  ,parameter               P_DATAWD = K_COREBUSWD
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp         b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp             b_cpl
  ,DWC_pcie_edmapf_ctxPop_haltable_if.slave_mp b_ctxPop
  ,DWC_pcie_edmapf_ctxPush_if.master_mp        b_ctxPush
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_mwr
  ,DWC_pcie_edmapf_rasdp_if.master_mp          b_ras
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################
  
    localparam N_CPL2MWR_CHK = 3 +1 ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_0();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_1();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_2();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_3();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_4();
  ras_dp_err_log_t [N_CPL2MWR_CHK-1:0] cpl2mwr_ras_dp_err_logs;
  ras_dp_err_inj_t                     cpl2mwr_ras_dp_err_inj;
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_0  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPCTXTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_1  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_2  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPCTXTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_3  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPCTXTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_4  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPCTXTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_5  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPCTXTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_6  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_DATAWD)
    ,.P_HEADERTYPE(P_TLPCTXTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_7  ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD    (P_DATAWD)
  ,.P_HEADERTYPE(P_TLPCTXTYPE)
  ,.P_STAGES    (E_FEED_NONE)
  ,.P_TYPE      (E_TLP_FULL)
  ) u_cpl_delay (
   .b_dst     ( b_DWC_pcie_edmapf_tlp_if_3.master_mp   )
  ,.b_src     ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp    )
  ,.b_clkrst  ( b_clk                                  )
  ,.b_ras     ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD                       (P_DATAWD)
  ,.P_HEADERTYPE /* P_TLPCTXTYPE */(P_TLPCTXTYPE)
  ,.P_RAS_CHK_EN                   (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID             ((P_CHANNEL == E_WRITE ? RAS_CHK_ID_CPL2MWR_BA_WR : RAS_CHK_ID_CPL2MWR_BA_RD))
  ,.P_RAS_GEN_EN                   (E_TRUE)
  ,.P_STAGES /* E_FEED_HALT */     (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */        (E_TLP_FULL)
  ) u_dataAligner (
   .b_dst     ( b_DWC_pcie_edmapf_tlp_if_4.master_mp   )
  ,.b_src     ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp    )
  ,.b_clkrst  ( b_clk                                  )
  ,.b_ras     ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp )
  );

  DWC_pcie_edmapf_ctrl_cpl2mwr_flush
   #(
   .P_CHAN             (P_CHAN)
  ,.P_CHANNEL          (P_CHANNEL)
  ,.RAS_DP_PROT_CHK_ID ((P_CHANNEL == E_WRITE ? RAS_CHK_ID_CPL2MWR_FLUSH_WR : RAS_CHK_ID_CPL2MWR_FLUSH_RD))
  ) u_flush (
   .b_clk     ( b_clk                                  )
  ,.b_in      ( b_DWC_pcie_edmapf_tlp_if_7.slave_mp    )
  ,.b_out     ( b_DWC_pcie_edmapf_tlp_if_6.master_mp   )
  ,.b_ras     ( b_DWC_pcie_edmapf_rasdp_if_4.master_mp )
  );

  DWC_pcie_edmapf_ctrl_cpl2mwr_pop
   #(
   .P_C2W_BUFF_DP(P_C2W_BUFF_DP)
  ,.P_CHANNEL    (P_CHANNEL)
  ,.P_CTXTYPE    (P_CTXTYPE)
  ,.P_DATAWD     (P_DATAWD)
  ,.P_TLPTYPE    (P_TLPTYPE)
  ) u_pop (
   .b_clk     ( b_clk                                  )
  ,.b_cpl     ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp    )
  ,.b_ctxPop  ( b_ctxPop                               )
  ,.b_tlpCtx  ( b_DWC_pcie_edmapf_tlp_if_1.master_mp   )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD                    (P_DATAWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_CHK_EN                (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID          ((P_CHANNEL == E_WRITE ? RAS_CHK_ID_CPL2MWR_WR : RAS_CHK_ID_CPL2MWR_RD))
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_pop_delay (
   .b_dst     ( b_DWC_pcie_edmapf_tlp_if_2.master_mp   )
  ,.b_src     ( b_cpl                                  )
  ,.b_clkrst  ( b_clk                                  )
  ,.b_ras     ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp )
  );

  DWC_pcie_edmapf_ctrl_cpl2mwr_push
  
    u_push (
   .b_clk     ( b_clk                                  )
  ,.b_ctxPush ( b_ctxPush                              )
  ,.b_mwr     ( b_DWC_pcie_edmapf_tlp_if_0.master_mp   )
  ,.b_tlpCtx  ( b_DWC_pcie_edmapf_tlp_if_6.slave_mp    )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD                    (P_DATAWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_CHK_EN                (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID          ((P_CHANNEL == E_WRITE ? RAS_CHK_ID_CPL2MWR_MWR_WR : RAS_CHK_ID_CPL2MWR_MWR_RD))
  ,.P_RAS_GEN_EN                (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_push_delay (
   .b_dst     ( b_mwr                                  )
  ,.b_src     ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp    )
  ,.b_clkrst  ( b_clk                                  )
  ,.b_ras     ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp )
  );


  
  assign cpl2mwr_ras_dp_err_logs = { b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_log,
                                     b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_log,
                                     b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_log
                                     ,
                                     b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_log
                                    };  
  assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = cpl2mwr_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = cpl2mwr_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = cpl2mwr_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_inj = cpl2mwr_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = '0;
  
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_CPL2MWR_CHK        ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (0                    )
  ) u_cpl2mwr_ras_dp_err_mgr (
    .clk                        (b_clk.w_aux_clk          )
   ,.rst_n                      (b_clk.w_reset_n          )
   ,.out_ras_dp_wake_up         (/*Not Connected*/        )
   ,.in_ras_dp_err_inj          (b_ras.w_ras_dp_err_inj   )
   ,.out_ras_dp_err_inj         (cpl2mwr_ras_dp_err_inj   )
  ,.in_ras_dp_err_log           (cpl2mwr_ras_dp_err_logs  )
  ,.out_ras_dp_err_log          (b_ras.w_ras_dp_err_log   )
  );

  DWC_pcie_edmapf_ctrl_cpl2mwr_update
   #(
   .P_CHAN   (P_CHAN)
  ,.P_CHANNEL(P_CHANNEL)
  ) u_update (
   .b_cdm     ( b_cdm                                  )
  ,.b_clk     ( b_clk                                  )
  ,.b_future  ( b_DWC_pcie_edmapf_tlp_if_5.master_mp   )
  ,.b_in      ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp    )
  ,.b_out     ( b_DWC_pcie_edmapf_tlp_if_7.master_mp   )
  ,.b_present ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp    )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
