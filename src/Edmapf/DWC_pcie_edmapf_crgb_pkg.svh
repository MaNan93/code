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
// ---    $DateTime: 2023/04/29 12:35:01 $ 
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_crgb_pkg.svh#6 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_CRGB_PKG__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_CRGB_PKG__SVH__

// SNPS_SysML_CODE_START
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
// SNPS_SysML_CODE_END

package DWC_pcie_edmapf_crgb_pkg;

  import DWC_pcie_edmapf_pkg::*;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  // ##########################################################################
  //                          Data Structures/Unions                           
  // ##########################################################################
  typedef struct packed {
    logic [15:0] abort;
    logic [15:0] done ;
  } edma_abort_done_s;

  typedef struct packed {
    logic [1:0] d_ats           ;
    logic [2:0] d_tc            ;
    logic       reserved_26     ;
    logic       d_ro            ;
    logic       s_sn            ;
    logic       d_sn            ;
    logic       mtyp            ;
    logic [4:0] element_prefetch;
    logic [4:0] d_pf            ;
    logic       nu64d           ;
    logic       nu64s           ;
    logic       llen            ;
    logic       ccs             ;
    logic       reserved_07     ;
    logic [1:0] cs              ;
    logic       rie             ;
    logic       lie             ;
    logic       llp             ;
    logic       pfo             ;
    logic       cb              ;
  } edma_chan_ctx_s;

  typedef struct packed {
    logic       d_th          ;
    logic [1:0] d_ph          ;
    logic [3:0] reserved_28_25;
    logic [7:0] d_st          ;
    logic [7:0] reserved_16_09;
    logic [7:0] d_vf          ;
    logic       d_vf_en       ;
  } edma_chan_dvf_tph_s;

  typedef struct packed {
    logic [30:0] reserved_31_01;
    logic        en            ;
  } edma_chan_en_s;

  typedef struct packed {
    logic [22:0] reserved_31_09;
    logic  [2:0] ctx           ;
    logic  [2:0] crgb          ;
    logic  [2:0] reserved_02_00;
  } edma_ctrl_ctx_arb_s;

  typedef struct packed {
    logic [2:0] cpl2mwr_xali  ;
    logic [2:0] wr_intmsg_xali;
    logic [2:0] rd_intmsg_xali;
    logic [2:0] axali         ;
    logic [2:0] rd_ctrl_xali  ;
    logic [4:0] version       ;
    logic [2:0] rdbuff_trgt   ;
    logic [2:0] rd_ctrl_trgt  ;
    logic [2:0] wr_ctrl_trgt  ;
    logic [2:0] rtrgt1        ;
  } edma_ctrl_data_arb_s;

  typedef struct packed {
    logic [7:0] reserved_31_24 ;
    logic [7:0] num_dma_rd_chan;
    logic [7:0] reserved_15_08 ;
    logic [7:0] num_dma_wr_chan;
  } edma_ctrl_s;

  typedef struct packed {
    logic        stop          ;
    logic [26:0] reserved_30_04;
    logic  [3:0] doorbell      ;
  } edma_doorbell_s;

  typedef struct packed {
    logic        hs_ch15       ;
    logic        hs_ch14       ;
    logic        hs_ch13       ;
    logic        hs_ch12       ;
    logic        hs_ch11       ;
    logic        hs_ch10       ;
    logic        hs_ch9        ;
    logic        hs_ch8        ;
    logic        hs_ch7        ;
    logic        hs_ch6        ;
    logic        hs_ch5        ;
    logic        hs_ch4        ;
    logic        hs_ch3        ;
    logic        hs_ch2        ;
    logic        hs_ch1        ;
    logic        hs_ch0        ;
    logic [14:0] reserved_15_01;
    logic        en            ;
  } edma_en_s;

  typedef struct packed {
    logic [14:0] reserved_31_17;
    logic        en            ;
    logic  [7:0] chan_end      ;
    logic  [7:0] chan_start    ;
  } edma_group_s;

  typedef struct packed {
    logic [2:0] reserved_31_29;
    logic [4:0] ch3           ;
    logic [2:0] reserved_23_21;
    logic [4:0] ch2           ;
    logic [2:0] reserved_15_13;
    logic [4:0] ch1           ;
    logic [2:0] reserved_07_05;
    logic [4:0] ch0           ;
  } edma_hshake_s;

  typedef struct packed {
    logic [15:0] localEn ;
    logic [15:0] remoteEn;
  } edma_llie_s;

  typedef struct packed {
    logic [15:0] ch1;
    logic [15:0] ch0;
  } edma_msgd_s;

  typedef struct packed {
    logic [21:0] reserved_31_10    ;
    logic  [9:0] pf_llqdp_max_depth;
  } edma_pfllq_ctrl_s;

  typedef struct packed {
    logic [7:0] ep_err;
    logic [7:0] to_err;
    logic [7:0] ca_err;
    logic [7:0] ur_err;
  } edma_rd_err_s;

  typedef struct packed {
    logic [15:0] ll_err    ;
    logic [15:0] bridge_err;
  } edma_rdwr_err_s;

  typedef struct packed {
    logic [11:0] reserved_31_20;
    logic  [4:0] ch3           ;
    logic  [4:0] ch2           ;
    logic  [4:0] ch1           ;
    logic  [4:0] ch0           ;
  } edma_weight_s;

  typedef struct packed {
    logic [4:0] reserved_31_27;
    logic [7:0] st            ;
    logic [1:0] ph            ;
    logic       th            ;
    logic [8:0] reserved_15_7 ;
    logic [1:0] at            ;
    logic       ro            ;
    logic       dst_sn        ;
    logic       src_sn        ;
    logic       mtype         ;
    logic       llen          ;
  } hdma_v1_control1_s;

  typedef struct packed {
    logic [29:0] reserved_31_02;
    logic        ccs           ;
    logic        cb            ;
  } hdma_v1_cycle_bit_s;

  typedef struct packed {
    logic [29:0] reserved_31_02;
    logic        db_stop       ;
    logic        db_start      ;
  } hdma_v1_doorbell_s;

  typedef struct packed {
    logic [24:0] reserved_31_07  ;
    logic  [6:0] element_prefetch;
  } hdma_v1_elem_pf_s;

  typedef struct packed {
    logic [30:0] reserved_31_01;
    logic        enable        ;
  } hdma_v1_en_s;

  typedef struct packed {
    logic  [6:0] reserved_31_25;
    logic  [7:0] vf            ;
    logic        vf_en         ;
    logic [10:0] reserved_15_05;
    logic  [4:0] pf            ;
  } hdma_v1_func_num_s;

  typedef struct packed {
    logic [24:0] reserved_31_07;
    logic  [5:0] hs_count      ;
    logic        hs_en         ;
  } hdma_v1_handshake_s;

  typedef struct packed {
    logic [28:0] reserved_31_03;
    logic        abort_clr     ;
    logic        wm_clr        ;
    logic        stop_clr      ;
  } hdma_v1_int_clear_s;

  typedef struct packed {
    logic [24:0] reserved_31_07;
    logic        laie          ;
    logic        raie          ;
    logic        lsie          ;
    logic        rsie          ;
    logic        abort_msk     ;
    logic        wm_msk        ;
    logic        stop_msk      ;
  } hdma_v1_int_setup_s;

  typedef struct packed {
    logic       [24:0] reserved_31_07;
    dmaErrors_e        error         ;
    logic              abort         ;
    logic              watermark     ;
    logic              stop          ;
  } hdma_v1_int_status_s;

  typedef struct packed {
    logic [15:0] reserved_31_16;
    logic [15:0] msgd          ;
  } hdma_v1_msi_msgd_s;

  typedef struct packed {
    logic [5:0] reserved_31_26;
    logic [9:0] pf_depth      ;
    logic [7:0] reserved_15_08;
    logic [4:0] weight        ;
    logic [2:0] tc            ;
  } hdma_v1_qos_s;

  typedef struct packed {
    logic [29:0] reserved_31_02;
    logic  [1:0] status        ;
  } hdma_v1_status_s;

  typedef struct packed {
    logic [29:0] reserved_31_02;
    logic        lwie          ;
    logic        rwie          ;
  } hdma_v1_watermark_en_s;

  typedef union packed {
    edma_chan_dvf_tph_s         dvf_tph      ;
    logic                [31:0] llp          ;
    logic                [31:0] dar          ;
    logic                [31:0] sar          ;
    logic                [31:0] tsize        ;
    logic                [31:0] msgd_addr    ;
    edma_msgd_s                 msgd         ;
    edma_chan_ctx_s             chan_ctx     ;
    edma_chan_en_s              chan_en      ;
    edma_hshake_s               hs_cnt       ;
    edma_group_s                grouping     ;
    edma_rd_err_s               rd_err       ;
    edma_rdwr_err_s             rdwr_err     ;
    edma_llie_s                 llie         ;
    edma_abort_done_s           status       ;
    edma_weight_s               weight       ;
    edma_pfllq_ctrl_s           pfllq        ;
    edma_doorbell_s             doorbell     ;
    edma_en_s                   hs_en        ;
    edma_ctrl_s                 num_chan     ;
    edma_ctrl_ctx_arb_s         ctrl_ctx_arb ;
    edma_ctrl_data_arb_s        ctrl_data_arb;
  } edma_reg_map_u;

  typedef union packed {
    hdma_v1_msi_msgd_s            msi_msgd    ;
    logic                  [31:0] msi_addr    ;
    hdma_v1_int_clear_s           int_clear   ;
    hdma_v1_int_setup_s           int_setup   ;
    hdma_v1_int_status_s          int_status  ;
    hdma_v1_status_s              status      ;
    hdma_v1_qos_s                 qos         ;
    hdma_v1_func_num_s            func_num    ;
    hdma_v1_control1_s            control1    ;
    hdma_v1_watermark_en_s        watermark_en;
    logic                  [31:0] dar         ;
    logic                  [31:0] sar         ;
    logic                  [31:0] tsize       ;
    hdma_v1_cycle_bit_s           cycle       ;
    logic                  [31:0] llp         ;
    hdma_v1_handshake_s           handshake   ;
    hdma_v1_elem_pf_s             elem_pf     ;
    hdma_v1_doorbell_s            doorbell    ;
    hdma_v1_en_s                  en          ;
  } hdma_v1_reg_map_u;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endpackage

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

`endif // __GUARD__DWC_PCIE_EDMAPF_CRGB_PKG__SVH__

