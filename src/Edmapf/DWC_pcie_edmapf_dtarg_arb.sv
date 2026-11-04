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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_dtarg_arb.sv#7 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_wresp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_dtarg_arb
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter type P_TLPTYPE = xradm_s
  ,parameter        P_BUSWD = 8
  ,parameter       P_MAXMWR = 2
  ,parameter        P_TAGWD = 10
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp     b_clk
  ,DWC_pcie_edmapf_tlp_if.slave_mp       b_data_req
  ,DWC_pcie_edmapf_tlp_if.slave_mp       b_data_wr
  ,DWC_pcie_edmapf_tlp_if.slave_mp       b_ll_req_rd
  ,DWC_pcie_edmapf_tlp_if.slave_mp       b_ll_req_wr
  ,DWC_pcie_edmapf_tlp_if.master_mp      b_trgt_np
  ,DWC_pcie_edmapf_tlp_if.master_mp      b_trgt_p
  ,DWC_pcie_edmapf_wack_if.master_mp     b_wack
  ,DWC_pcie_edmapf_tlp_wresp_if.slave_mp b_wresp
  ,DWC_pcie_edmapf_rasdp_if.master_mp    b_ras
  );

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_0();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_1();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_2();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_3();
  DWC_pcie_edmapf_rasdp_if b_DWC_pcie_edmapf_rasdp_if_4();
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
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_in1_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_1.master_mp   )
  ,.b_src    ( b_ll_req_rd                            )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_4.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_in2_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_2.master_mp   )
  ,.b_src    ( b_ll_req_wr                            )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_0.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_STAGES /* E_FEED_HALT */  (E_FEED_HALT)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_in3_delay (
   .b_dst    ( b_DWC_pcie_edmapf_tlp_if_0.master_mp   )
  ,.b_src    ( b_data_req                             )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_3.master_mp )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_GEN_EN                (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_in4_delay (
   .b_dst    ( b_trgt_p                               )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_4.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_1.master_mp )
  );

  DWC_pcie_edmapf_tlp_3to1_arb
  
    u_np_arb (
   .b_clk    ( b_clk                                  )
  ,.b_dst    ( b_DWC_pcie_edmapf_tlp_if_3.master_mp   )
  ,.b_src1   ( b_DWC_pcie_edmapf_tlp_if_1.slave_mp    )
  ,.b_src2   ( b_DWC_pcie_edmapf_tlp_if_2.slave_mp    )
  ,.b_src3   ( b_DWC_pcie_edmapf_tlp_if_0.slave_mp    )
  );

  DWC_pcie_edmapf_tlp_delay
   #(
   .P_DATAWD /* P_BUSWD */      (P_BUSWD)
  ,.P_HEADERTYPE /* P_TLPTYPE */(P_TLPTYPE)
  ,.P_RAS_GEN_EN                (E_TRUE)
  ,.P_STAGES /* E_FEED_NONE */  (E_FEED_NONE)
  ,.P_TYPE /* E_TLP_FULL */     (E_TLP_FULL)
  ) u_out_delay (
   .b_dst    ( b_trgt_np                              )
  ,.b_src    ( b_DWC_pcie_edmapf_tlp_if_3.slave_mp    )
  ,.b_clkrst ( b_clk                                  )
  ,.b_ras    ( b_DWC_pcie_edmapf_rasdp_if_2.master_mp )
  );

  assign b_ras.w_ras_dp_err_log                        = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_2.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_1.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_4.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_0.w_ras_dp_err_inj = '0;
  assign b_DWC_pcie_edmapf_rasdp_if_3.w_ras_dp_err_inj = '0;

  DWC_pcie_edmapf_wackAdapter
   #(
   .P_MAXMWR(P_MAXMWR)
  ,.P_TAGWD (P_TAGWD)
  ) u_wackAdapter (
   .b_clk    ( b_clk                                  )
  ,.b_mwrIn  ( b_data_wr                              )
  ,.b_mwrOut ( b_DWC_pcie_edmapf_tlp_if_4.master_mp   )
  ,.b_wack   ( b_wack                                 )
  ,.b_wresp  ( b_wresp                                )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
