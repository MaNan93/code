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
// ---    $DateTime: 2024/01/19 09:25:58 $ 
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/ramRd_if.svh"
`include "common/DW_sbc_cdc/svif/ramWr_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_pop_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_push_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_e_info_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_f_info_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter             P_EFLAGS_EARLY = 0
  ,parameter             P_FFLAGS_EARLY = 0
  ,parameter                  P_FIFO_DP = 8
  ,parameter               P_HOLD_RADDR = 1
  ,parameter                    P_NSEGS = 4
  ,parameter                   P_RAM_AW = 6
  ,parameter              P_RAM_LATENCY = 1
  ,parameter                    P_RAM_W = 64
  ,parameter                   P_SEG_AW = $clog2(P_NSEGS)
  ,parameter                   P_SEG_DP = 16
  ,parameter      syncArch_e P_CDC_ARCH = E_DEFAULT_ARCH
  ,parameter               P_RAM_REGOUT = 1
  ,parameter                P_RAM_REGIN = 1
  ,parameter bool_e P_SVA_MAY_POP_EMPTY = E_FALSE
  ,parameter         P_PUSH2POP_SYNC_DP = 2
  ,parameter         P_POP2PUSH_SYNC_DP = 2
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp     b_clk
  ,DW_sbc_cdc_e_info_if.master_mp b_einfo
  ,DW_sbc_cdc_f_info_if.master_mp b_finfo
  ,DW_sbc_cdc_pop_if.master_mp    b_pop
  ,DW_sbc_cdc_push_if.slave_mp    b_push
  ,ramRd_if.slave_mp              b_ramr
  ,ramWr_if.master_mp             b_ramw
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################
  localparam syncType_e LP_POP2PUSH_SYNCTYPE = ( (P_CDC_ARCH == E_CDC_DISABLED) ? E_SYNC_OFF  :
                                                 (P_CDC_ARCH == E_PSH_FASTER  ) ? E_SYNC_FIFO :
                                                 (P_CDC_ARCH == E_LEAVE_UNCONNECTED) ? E_SYNC_TIE_LOW :
                                                                                  E_SYNC_HSK   );

  localparam syncType_e LP_PUSH2POP_SYNCTYPE = ( (P_CDC_ARCH == E_CDC_DISABLED) ? E_SYNC_OFF  :
                                                 (P_CDC_ARCH == E_POP_FASTER  ) ? E_SYNC_FIFO :
                                                 (P_CDC_ARCH == E_LEAVE_UNCONNECTED) ? E_SYNC_TIE_LOW :
                                                                                  E_SYNC_HSK   );

  localparam LP_CTR_W                        = $clog2(P_SEG_DP)+1             ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DW_sbc_cdc_pop_ctl_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
    ,.P_RAM_W (P_RAM_W)
    ,.P_SEG_AW(P_SEG_AW)
                       ) b_DW_sbc_cdc_pop_ctl_if_0 ();

  DW_sbc_cdc_push_ctl_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
    ,.P_RAM_W (P_RAM_W)
    ,.P_SEG_AW(P_SEG_AW)
                        )b_DW_sbc_cdc_push_ctl_if_0();

  DW_sbc_cdc_sync_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
    ,.P_SEG_AW(P_SEG_AW)
                    )    b_DW_sbc_cdc_sync_if_0    ();

  DW_sbc_cdc_sync_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
    ,.P_SEG_AW(P_SEG_AW)
                    )    b_DW_sbc_cdc_sync_if_1    ();

  DW_sbc_cdc_sync_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
    ,.P_SEG_AW(P_SEG_AW)
                    )    b_DW_sbc_cdc_sync_if_2    ();

  DW_sbc_cdc_sync_if #(
     .LP_CTR_W(LP_CTR_W)
    ,.P_NSEGS (P_NSEGS)
    ,.P_SEG_AW(P_SEG_AW)
                    )    b_DW_sbc_cdc_sync_if_3    ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DW_sbc_cdc_sync_wrapper
   #(
   .LP_CTR_W    (LP_CTR_W)
  ,.P_FIFO_DP   (P_FIFO_DP)
  ,.P_NSEGS     (P_NSEGS)
  ,.P_PUSH2POP  (0)
  ,.P_RAM_AW    (P_RAM_AW)
  ,.P_SEG_DP    (P_SEG_DP)
  ,.P_SYNCTYPE  (LP_POP2PUSH_SYNCTYPE)
  ,.P_SEG_AW    (P_SEG_AW)
  ,.P_SYNC_DP_FW(P_POP2PUSH_SYNC_DP)
  ,.P_SYNC_DP_BW(P_PUSH2POP_SYNC_DP)
  ) u_pop2push (
   .b_clk              ( b_clk                                )
  ,.b_sync_ib          ( b_DW_sbc_cdc_sync_if_3.slave_mp      )
  ,.b_sync_ob          ( b_DW_sbc_cdc_sync_if_0.master_mp     )
  );

  DW_sbc_cdc_pop_ctl
   #(
   .LP_CTR_W      (LP_CTR_W)
  ,.P_EFLAGS_EARLY(P_EFLAGS_EARLY)
  ,.P_HOLD_RADDR  (P_HOLD_RADDR)
  ,.P_NSEGS       (P_NSEGS)
  ,.P_RAM_AW      (P_RAM_AW)
  ,.P_RAM_LATENCY (P_RAM_LATENCY)
  ,.P_RAM_W       (P_RAM_W)
  ,.P_SEG_AW      (P_SEG_AW)
  ,.P_SEG_DP      (P_SEG_DP)
  ,.P_RAM_REGIN   (P_RAM_REGIN)
  ,.P_SVA_MAY_POP_EMPTY(P_SVA_MAY_POP_EMPTY)
  ) u_pop_ctl (
   .b_clk              ( b_clk                                )
  ,.b_einfo            ( b_einfo                              )
  ,.b_pop_ctl          ( b_DW_sbc_cdc_pop_ctl_if_0.master_mp  )
  ,.b_ramr             ( b_ramr                               )
  );

  DW_sbc_cdc_pop_tap
   #(
   .P_SEG_AW(P_SEG_AW)
  ) u_pop_tap (
   .b_clk              ( b_clk                                )
  ,.b_pop              ( b_pop                                )
  ,.b_pop_ctl          ( b_DW_sbc_cdc_pop_ctl_if_0.slave_mp   )
  ,.b_pop_sync_local   ( b_DW_sbc_cdc_sync_if_3.master_mp     )
  ,.b_push_sync_remote ( b_DW_sbc_cdc_sync_if_2.slave_mp      )
  );

  DW_sbc_cdc_sync_wrapper
   #(
   .LP_CTR_W    (LP_CTR_W)
  ,.P_FIFO_DP   (P_FIFO_DP)
  ,.P_NSEGS     (P_NSEGS)
  ,.P_PUSH2POP  (1)
  ,.P_RAM_AW    (P_RAM_AW)
  ,.P_SEG_DP    (P_SEG_DP)
  ,.P_SYNCTYPE  (LP_PUSH2POP_SYNCTYPE)
  ,.P_SEG_AW    (P_SEG_AW)
  ,.P_SYNC_DP_FW(P_PUSH2POP_SYNC_DP)
  ,.P_SYNC_DP_BW(P_POP2PUSH_SYNC_DP)
  ) u_push2pop (
   .b_clk              ( b_clk                                )
  ,.b_sync_ib          ( b_DW_sbc_cdc_sync_if_1.slave_mp      )
  ,.b_sync_ob          ( b_DW_sbc_cdc_sync_if_2.master_mp     )
  );

  DW_sbc_cdc_push_ctl
   #(
   .LP_CTR_W      (LP_CTR_W)
  ,.P_FFLAGS_EARLY(P_FFLAGS_EARLY)
  ,.P_NSEGS       (P_NSEGS)
  ,.P_RAM_AW      (P_RAM_AW)
  ,.P_RAM_W       (P_RAM_W)
  ,.P_SEG_DP      (P_SEG_DP)
  ,.P_RAM_REGOUT  (P_RAM_REGOUT)
  ) u_push_ctl (
   .b_clk              ( b_clk                                )
  ,.b_finfo            ( b_finfo                              )
  ,.b_push_ctl         ( b_DW_sbc_cdc_push_ctl_if_0.slave_mp  )
  ,.b_ramw             ( b_ramw                               )
  );

  DW_sbc_cdc_push_tap
   #(
   .P_SEG_AW(P_SEG_AW)
  ) u_push_tap (
   .b_clk              ( b_clk                                )
  ,.b_pop_sync_remote  ( b_DW_sbc_cdc_sync_if_0.slave_mp      )
  ,.b_push             ( b_push                               )
  ,.b_push_ctl         ( b_DW_sbc_cdc_push_ctl_if_0.master_mp )
  ,.b_push_sync_local  ( b_DW_sbc_cdc_sync_if_1.master_mp     )
  );

// SNPS_SysML_CODE_START
`ifndef SYNTHESIS
`endif // SYNTHESIS
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc
