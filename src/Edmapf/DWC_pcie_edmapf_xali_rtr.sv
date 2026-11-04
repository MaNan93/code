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
// ---    $Revision: #6 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_xali_rtr.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_xali_rtr
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_TLPTYPE = logic
  ,parameter        P_BUSWD = 8
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp   b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_rdll
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_wrdata
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_wrll
  ,DWC_pcie_edmapf_rasdp_if.master_mp  b_ras
  );
  
  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################
  
    localparam N_XALI_RTR_CHK = 2 ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_0();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_1();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_2();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_3();
  ras_dp_err_log_t [N_XALI_RTR_CHK-1:0] xali_rtr_ras_dp_err_logs;
  ras_dp_err_inj_t                      xali_rtr_ras_dp_err_inj;
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_0  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_1  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_2  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_3  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_4  ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_in_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_0.master_mp   )
  ,.b_src    ( b_in                                   )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp )
  );

  
  assign xali_rtr_ras_dp_err_logs = { b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_log,
                                      b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_log
                                    }; 
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = xali_rtr_ras_dp_err_inj;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = xali_rtr_ras_dp_err_inj;
  
  assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = '0;
  
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (N_XALI_RTR_CHK       ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (0                    )
  ) u_xali_rtr_ras_dp_err_mgr (
    .clk                        (b_clk.w_aux_clk          )
   ,.rst_n                      (b_clk.w_reset_n          )
   ,.out_ras_dp_wake_up         (/*Not Connected*/        )
   ,.in_ras_dp_err_inj          (b_ras.w_ras_dp_err_inj   )
   ,.out_ras_dp_err_inj         (xali_rtr_ras_dp_err_inj  )
  ,.in_ras_dp_err_log           (xali_rtr_ras_dp_err_logs )
  ,.out_ras_dp_err_log          (b_ras.w_ras_dp_err_log   )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_CHK_EN                (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID          (RAS_CHK_ID_CPL_RDLL)   
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_rdll_delay (
   .b_dst    ( b_rdll                                 )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp )
  );

  DWC_pcie_edmapf_tlp_1to2_rtr
   #(
   .P_DST1TARGET /* WR_DATA */  (E_DMAPF_WR_DATA)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_rtr_in (
   .b_dst1   ( b_DWC_pcie_edmapf_tlp_if_3.master_mp   )
  ,.b_dst2   ( b_DWC_pcie_edmapf_tlp_if_4.master_mp   )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp    )
  ,.b_cdm    ( b_cdm                                  )
  ,.b_clk    ( b_clk                                  )
  );

  DWC_pcie_edmapf_tlp_1to2_rtr
   #(
   .P_DST1TARGET /* RD_LL */    (E_DMAPF_RD_LL)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_rtr_out (
   .b_dst1   ( b_DWC_pcie_edmapf_tlp_if_2.master_mp   )
  ,.b_dst2   ( b_DWC_pcie_edmapf_tlp_if_1.master_mp   )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp    )
  ,.b_cdm    ( b_cdm                                  )
  ,.b_clk    ( b_clk                                  )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_wrdata_delay (
   .b_dst    ( b_wrdata                               )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_CHK_EN                (E_TRUE)
  ,.RAS_DP_PROT_CHK_ID          (RAS_CHK_ID_CPL_WRLL)   
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_wrll_delay (
   .b_dst    ( b_wrll                                 )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
