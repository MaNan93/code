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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_dxali_arb.sv#9 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_dxali_arb
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_TLPTYPE = xradm_s
  ,parameter        P_BUSWD = 8
  ,parameter        P_TAGWD = 2
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp    b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp     b_npReq
  ,DWC_pcie_edmapf_tlp_if.master_mp     b_pReq
  ,DWC_pcie_edmapf_wack_if.master_mp    b_pReq_ack
  ,DWC_pcie_edmapf_ctxPush_if.master_mp b_push
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_rdMsi
  ,DWC_pcie_edmapf_wack_if.master_mp    b_rdMsi_ack
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_rdReq
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_wrData
  ,DWC_pcie_edmapf_wack_if.master_mp    b_wrData_ack
  ,DWC_pcie_edmapf_tlp_if.slave_mp      b_wrMsi
  ,DWC_pcie_edmapf_wack_if.master_mp    b_wrMsi_ack
  ,DWC_pcie_edmapf_rasdp_if.master_mp   b_ras
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_0();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_1();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_2();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_3();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_4();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_5();
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
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_5  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_6  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_7  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_8  ();
  DWC_pcie_edmapf_tlp_if #(
     .P_DATAWD    (P_BUSWD)
    ,.P_HEADERTYPE(P_TLPTYPE)
                        )  b_DWC_pcie_edmapf_tlp_if_9  ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_GEN_EN                (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_npReq_delay (
   .b_dst    ( b_npReq                                )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_9.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_5.master_mp )
  );

  DWC_pcie_edmapf_tlp_3to1_arb
  
    u_pReqArb (
   .b_clk    ( b_clk                                  )
  ,.b_dst    ( b_DWC_pcie_edmapf_tlp_if_0.master_mp   )
  ,.b_src1   ( b_DWC_pcie_edmapf_tlp_if_5.slave_mp    )
  ,.b_src2   ( b_DWC_pcie_edmapf_tlp_if_7.slave_mp    )
  ,.b_src3   ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp    )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_GEN_EN                (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_pReq_delay (
   .b_dst    ( b_pReq                                 )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_8.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp )
  );

  DWC_pcie_edmapf_mwr2wack
   #(
   .P_CHANWD(K_DMACHANWD)
  ,.P_TAGWD (K_DMATAGWD)
  ) u_pReq_monitor (
   .b_clk    ( b_clk                                  )
  ,.b_in     ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp    )
  ,.b_out    ( b_DWC_pcie_edmapf_tlp_if_8.master_mp   )
  ,.b_wack   ( b_pReq_ack                             )
  );

  assign b_ras.w_ras_dp_err_log                        = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_5.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = '0;

  DWC_pcie_edmapf_mwr2wack
   #(
   .P_CHANWD(K_DMACHANWD)
  ,.P_TAGWD (K_DMATAGWD)
  ) u_rdMsi_ack (
   .b_clk    ( b_clk                                  )
  ,.b_in     ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp    )
  ,.b_out    ( b_DWC_pcie_edmapf_tlp_if_5.master_mp   )
  ,.b_wack   ( b_rdMsi_ack                            )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_rdMsi_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_4.master_mp   )
  ,.b_src    ( b_rdMsi                                )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_4.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_rdReq_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_2.master_mp   )
  ,.b_src    ( b_rdReq                                )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp )
  );

  DWC_pcie_edmapf_dxali_arb_tagger
  
    u_tagger (
   .b_clk    ( b_clk                                  )
  ,.b_in     ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp    )
  ,.b_out    ( b_DWC_pcie_edmapf_tlp_if_9.master_mp   )
  ,.b_push   ( b_push                                 )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_wrData_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_3.master_mp   )
  ,.b_src    ( b_wrData                               )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp )
  );

  DWC_pcie_edmapf_mwr2wack
   #(
   .P_CHANWD(K_DMACHANWD)
  ,.P_TAGWD (K_DMATAGWD)
  ) u_wrMsi_ack (
   .b_clk    ( b_clk                                  )
  ,.b_in     ( b_DWC_pcie_edmapf_tlp_if_6.slave_mp    )
  ,.b_out    ( b_DWC_pcie_edmapf_tlp_if_7.master_mp   )
  ,.b_wack   ( b_wrMsi_ack                            )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_wrMsi_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_6.master_mp   )
  ,.b_src    ( b_wrMsi                                )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp )
  );

  DWC_pcie_edmapf_mwr2wack
   #(
   .P_CHANWD(K_DMACHANWD)
  ,.P_TAGWD (K_DMATAGWD)
  ) w_wrData_ack (
   .b_clk    ( b_clk                                  )
  ,.b_in     ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp    )
  ,.b_out    ( b_DWC_pcie_edmapf_tlp_if_1.master_mp   )
  ,.b_wack   ( b_wrData_ack                           )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
