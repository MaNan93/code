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
// ---    $DateTime: 2022/05/05 01:39:57 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_compat.sv#3 $ 
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

module DW_sbc_cdc_compat
  import DW_sbc_cdc_pkg::*;
  #(
    parameter            SEGS                   = 4
   ,parameter            SEG_W                  = 2
   ,parameter            RAM_W                  = 64
   ,parameter            RAM_AW                 = 8
   ,parameter            HOLD_RADDR             = 1
   ,parameter            P_SEG_DP               = 17
   ,parameter            P_RAM_LATENCY          = 2
   ,parameter syncArch_e P_CDC_ARCH             = E_DEFAULT_ARCH
   ,parameter            P_RAM_REGOUT           = 1
   ,parameter            P_RAM_REGIN            = 1
   ,parameter bool_e     P_SVA_MAY_POP_EMPTY    = E_FALSE
   ,parameter            P_PUSH2POP_SYNC_DP     = 2
   ,parameter            P_POP2PUSH_SYNC_DP     = 2
  ) (
    input  logic                              clk_push
   ,input  logic                              clk_pop
   ,input  logic                              pop_rst_n
   ,input  logic                              push_rst_n

   ,input  logic                              sb_init_i           /* not used */
   ,input  logic                [SEG_W    :0] sb_init_num_segs_i  /*          */
   ,input  logic  [SEGS   -1:0] [RAM_AW -1:0] sb_init_seg_sizes_i /*          */
   ,output logic                              sb_init_done_o

   ,input  logic                              sb_push_start_i
   ,input  logic                              sb_push_i
   ,input  logic                [SEG_W  -1:0] sb_push_seg_i
   ,input  logic                [RAM_W  -1:0] sb_push_data_i
   ,input  logic                              sb_push_keep_i
   ,input  logic                              sb_push_drop_i
   ,input  logic                              sb_reset_push_ptr   /* not used */
   ,input  logic                [SEG_W  -1:0] sb_reset_push_seg_i /*          */
   ,output logic                [SEGS   -1:0] sb_full_o
   ,output logic                [SEGS   -1:0] sb_full_m_1_o
   ,output logic                [SEGS   -1:0] sb_full_m_2_o

   ,input  logic                              sb_pop_i
   ,input  logic                              sb_pop_look_i
   ,input  logic                [SEG_W  -1:0] sb_pop_seg_i
   ,output logic                [RAM_W  -1:0] sb_pop_data_o
   ,output logic                [SEGS   -1:0] sb_seg_pkt_avail_o
   ,input  logic                              sb_reset_pop_ptr    /* not used */
   ,input  logic                [SEG_W  -1:0] sb_reset_pop_seg_i  /*          */
   ,output logic                [SEGS   -1:0] sb_empty_o
   ,output logic                [SEGS   -1:0] sb_empty_p_1_o

   ,input  logic  [SEGS   -1:0] [RAM_AW -1:0] sb_seg_start_i      /* not used */
   ,input  logic  [SEGS   -1:0] [RAM_AW -1:0] sb_seg_end_i        /*          */

   ,output logic                              sb_wen_n_o
   ,output logic                [RAM_AW -1:0] sb_waddr_o
   ,output logic                [RAM_W  -1:0] sb_wdata_o
   ,output logic                [RAM_AW -1:0] sb_raddr_o
   ,output logic                              sb_ren_n_o
   ,input  logic                [RAM_W  -1:0] sb_rdata_i
   ,output logic                              sb_par_chk_val_o
  );

  localparam P_NSEGS       = SEGS        ;
  localparam P_SEG_AW      = SEG_W       ;
  localparam P_HOLD_RADDR  = HOLD_RADDR  ;
  localparam P_RAM_AW      = RAM_AW      ;
  localparam P_RAM_W       = RAM_W       ;
  localparam LP_CTR_W      = P_SEG_AW + 1;

  DW_sbc_cdc_clk_if    #()                                                              b_clk  ();
  DW_sbc_cdc_e_info_if #(.LP_CTR_W(LP_CTR_W), .P_NSEGS (P_NSEGS )                     ) b_einfo();
  DW_sbc_cdc_f_info_if #(.LP_CTR_W(LP_CTR_W), .P_NSEGS (P_NSEGS )                     ) b_finfo();
  DW_sbc_cdc_pop_if    #(.P_RAM_W (P_RAM_W ), .P_NSEGS (P_NSEGS ), .P_SEG_AW(P_SEG_AW)) b_pop  ();
  DW_sbc_cdc_push_if   #(.P_RAM_W (P_RAM_W ), .P_NSEGS (P_NSEGS ), .P_SEG_AW(P_SEG_AW)) b_push ();
  ramRd_if             #(.P_RAM_W (P_RAM_W ), .P_RAM_AW(P_RAM_AW)                     ) b_ramr ();
  ramWr_if             #(.P_RAM_W (P_RAM_W ), .P_RAM_AW(P_RAM_AW)                     ) b_ramw ();

  /* Connect clock interface */
  assign  b_clk.w_pop_clk    = clk_pop   ;
  assign  b_clk.w_push_clk   = clk_push  ;
  assign  b_clk.w_push_rst_n = push_rst_n;
  assign  b_clk.w_pop_rst_n  = pop_rst_n ;

  /* Connect init interface */
  assign sb_init_done_o = 1'b1;

  /* Connect pop interface */
  assign  b_pop.w_pop_seg     = sb_pop_seg_i;
  assign        sb_pop_data_o = b_pop.w_pop_data_d;

  /* Connect push interface */
  assign b_push.w_push_seg   = sb_push_seg_i ;
  assign b_push.w_push_data  = sb_push_data_i;

  /* Connect empty interface */
  assign sb_empty_o          =  b_einfo.w_empty   ;
  assign sb_empty_p_1_o       =  b_einfo.w_empty_p1;
  assign sb_seg_pkt_avail_o  = ~b_einfo.w_empty   ;
  assign sb_par_chk_val_o    =                1'b1; /* ! not driven ! */

  /* Connect full interface */
  assign sb_full_o     = b_finfo.w_full   ;
  assign sb_full_m_1_o = b_finfo.w_full_m1;
  assign sb_full_m_2_o =                '0; /* ! not driven ! */

  /* Connect RAM W interface */
  assign sb_wen_n_o = b_ramw.w_wen_n;
  assign sb_waddr_o = b_ramw.w_waddr;
  assign sb_wdata_o = b_ramw.w_wdata;

  /* Connect RAM R interface */
  assign        sb_ren_n_o     = b_ramr.w_ren_n   ;
  assign        sb_raddr_o     = b_ramr.w_raddr   ;
  assign b_ramr.w_rdata        =        sb_rdata_i;

  DW_sbc_cdc
   #(
     .P_HOLD_RADDR       (P_HOLD_RADDR       )
    ,.P_NSEGS            (P_NSEGS            )
    ,.P_RAM_AW           (P_RAM_AW           )
    ,.P_RAM_W            (P_RAM_W            )
    ,.P_SEG_AW           (P_SEG_AW           )
    ,.P_SEG_DP           (P_SEG_DP           )
    ,.P_CDC_ARCH         (P_CDC_ARCH         )
    ,.P_RAM_LATENCY      (P_RAM_LATENCY      )
    ,.P_FFLAGS_EARLY     (0                  )
    ,.P_EFLAGS_EARLY     (0                  )
    ,.P_RAM_REGOUT       (P_RAM_REGOUT       )
    ,.P_RAM_REGIN        (P_RAM_REGIN        )
    ,.P_SVA_MAY_POP_EMPTY(P_SVA_MAY_POP_EMPTY)
    ,.P_PUSH2POP_SYNC_DP (P_PUSH2POP_SYNC_DP )
    ,.P_POP2PUSH_SYNC_DP (P_POP2PUSH_SYNC_DP )
  ) u_sbc_cdc (
     .b_clk   (  b_clk.slave_mp )
    ,.b_einfo (b_einfo.master_mp)
    ,.b_finfo (b_finfo.master_mp)
    ,.b_pop   (  b_pop.master_mp)
    ,.b_push  ( b_push.slave_mp )
    ,.b_ramr  ( b_ramr.slave_mp )
    ,.b_ramw  ( b_ramw.master_mp)
  );

  always_comb begin : b_push_w_push_PROC
    if(~sb_push_i)                                 /* DW_sbc spec  : proper explicit drop         */
      b_push.w_push = sb_push_drop_i ? E_DROP : E_PUSH_IDLE;
    else begin
      if(sb_push_drop_i)                           /* rdbuff compat: explicit drop + packet start */
        b_push.w_push = E_DROPSTART;
      else if( sb_push_start_i && ~sb_push_keep_i) /* DW_sbc spec  : proper packet start          */
        b_push.w_push = E_START;
      else if(~sb_push_start_i &&  sb_push_keep_i) /* DW_sbc spec  : proper packet end            */
        b_push.w_push = E_KEEP;
      else if( sb_push_start_i &&  sb_push_keep_i) /* rdbuff compat: implicit drop + single push  */
        b_push.w_push = E_DROPSTARTKEEP;
      else
        b_push.w_push = E_PUSH;                    /* DW_sbc spec  : generic push                 */
    end
  end : b_push_w_push_PROC

  always_comb begin : b_pop_w_pop_PROC
    if(~sb_pop_i)
      b_pop.w_pop = E_POP_IDLE;
    else begin
      if(sb_pop_look_i)
        b_pop.w_pop = E_PEEK;
      else
        b_pop.w_pop = E_POP;
    end
  end : b_pop_w_pop_PROC
endmodule : DW_sbc_cdc_compat
