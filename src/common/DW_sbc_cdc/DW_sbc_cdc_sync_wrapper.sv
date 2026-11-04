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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #4 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_sync_wrapper.sv#4 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_clk_if.svh"
`include "common/DW_sbc_cdc/svif/DW_sbc_cdc_sync_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DW_sbc_cdc_sync_wrapper
  import DW_sbc_cdc_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter              LP_CTR_W = 9
  ,parameter             P_FIFO_DP = 8
  ,parameter               P_NSEGS = 5
  ,parameter            P_PUSH2POP = 0
  ,parameter              P_RAM_AW = 6
  ,parameter              P_SEG_DP = 8
  ,parameter syncType_e P_SYNCTYPE = E_SYNC_HSK
  ,parameter              P_SEG_AW = $clog2(P_NSEGS)
  ,parameter          P_SYNC_DP_FW = 2
  ,parameter          P_SYNC_DP_BW = 2
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DW_sbc_cdc_clk_if.slave_mp   b_clk
  ,DW_sbc_cdc_sync_if.slave_mp  b_sync_ib
  ,DW_sbc_cdc_sync_if.master_mp b_sync_ob
  );


// SNPS_SysML_CODE_START

  /* The interfaces are decomposed back into logics because
   * interface connections inside 'generate'd blocks is not
   * properly supported by tools
   */
  logic                                b_in_w_active_last    ;
  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] b_in_w_counter        ;
  logic                [P_SEG_AW -1:0] b_in_w_seg_active_last;

  logic                                b_out_w_active_last    ;
  logic [P_NSEGS -1:0] [LP_CTR_W -1:0] b_out_w_counter        ;
  logic                [P_SEG_AW -1:0] b_out_w_seg_active_last;

  assign b_in_w_active_last      = b_sync_ib.w_active_last    ;
  assign b_in_w_counter          = b_sync_ib.w_counter        ;
  assign b_in_w_seg_active_last  = b_sync_ib.w_seg_active_last;

  assign b_sync_ob.w_active_last     = b_out_w_active_last    ;
  assign b_sync_ob.w_counter         = b_out_w_counter        ;
  assign b_sync_ob.w_seg_active_last = b_out_w_seg_active_last;

  generate
    case (P_SYNCTYPE)
      E_SYNC_GRAY: begin : GEN_GRAY_SYNCER
        DW_sbc_cdc_sync_gray
         #(
          .P_NSEGS   (P_NSEGS     )
         ,.P_SEG_DP  (P_SEG_DP    )
         ,.P_PUSH2POP(P_PUSH2POP  )
         ,.P_SEG_AW  (P_SEG_AW    )
         ,.LP_CTR_W  (LP_CTR_W    )
         ,.P_SYNC_DP (P_SYNC_DP_FW)
        ) u_sync (
          .b_in_w_active_last     (b_in_w_active_last     )
         ,.b_in_w_counter         (b_in_w_counter         )
         ,.b_in_w_seg_active_last (b_in_w_seg_active_last )
         ,.b_out_w_active_last    (b_out_w_active_last    )
         ,.b_out_w_counter        (b_out_w_counter        )
         ,.b_out_w_seg_active_last(b_out_w_seg_active_last)
         ,.b_clk                  (b_clk                  )
        );
      end
      E_SYNC_FIFO: begin : GEN_FIFO_SYNCER
        DW_sbc_cdc_sync_fifo
         #(
          .P_NSEGS     (P_NSEGS     )
         ,.P_SEG_DP    (P_SEG_DP    )
         ,.P_PUSH2POP  (P_PUSH2POP  )
         ,.P_FIFO_DP   (P_FIFO_DP   )
         ,.P_SEG_AW    (P_SEG_AW    )
         ,.LP_CTR_W    (LP_CTR_W    )
         ,.P_RAM_AW    (P_RAM_AW    )
         ,.P_SYNC_DP_FW(P_SYNC_DP_FW)
         ,.P_SYNC_DP_BW(P_SYNC_DP_BW)
        ) u_sync (
          .b_in_w_active_last     (b_in_w_active_last     )
         ,.b_in_w_counter         (b_in_w_counter         )
         ,.b_in_w_seg_active_last (b_in_w_seg_active_last )
         ,.b_out_w_active_last    (b_out_w_active_last    )
         ,.b_out_w_counter        (b_out_w_counter        )
         ,.b_out_w_seg_active_last(b_out_w_seg_active_last)
         ,.b_clk                  (b_clk                  )
        );
      end
      E_SYNC_HSK : begin : GEN_HSK_SYNCER
        DW_sbc_cdc_sync_hsk
         #(
          .P_NSEGS     (P_NSEGS     )
         ,.P_SEG_DP    (P_SEG_DP    )
         ,.P_PUSH2POP  (P_PUSH2POP  )
         ,.P_SEG_AW    (P_SEG_AW    )
         ,.LP_CTR_W    (LP_CTR_W    )
         ,.P_SYNC_DP_FW(P_SYNC_DP_FW)
         ,.P_SYNC_DP_BW(P_SYNC_DP_BW)
        ) u_sync (
          .b_in_w_active_last     (b_in_w_active_last     )
         ,.b_in_w_counter         (b_in_w_counter         )
         ,.b_in_w_seg_active_last (b_in_w_seg_active_last )
         ,.b_out_w_active_last    (b_out_w_active_last    )
         ,.b_out_w_counter        (b_out_w_counter        )
         ,.b_out_w_seg_active_last(b_out_w_seg_active_last)
         ,.b_clk                  (b_clk                  )
        );
      end
      E_SYNC_OFF: begin : GEN_SYNC_OFF
        assign b_out_w_counter         = b_in_w_counter;
        assign b_out_w_active_last     = 1'b0;
        assign b_out_w_seg_active_last = '0;
      end
      E_SYNC_TIE_LOW: begin : GEN_SYNC_TIE_LOW
        assign b_out_w_counter         = '0;
        assign b_out_w_active_last     = 1'b0;
        assign b_out_w_seg_active_last = '0;
      end
    endcase
  endgenerate
// SNPS_SysML_CODE_END

endmodule : DW_sbc_cdc_sync_wrapper
