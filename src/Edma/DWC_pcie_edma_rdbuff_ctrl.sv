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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_rdbuff_ctrl.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// This module accepts completion TLP's on rcv2rdbuff* and writes same to the
// segment buffer via the segment buffer controller interface, sbc2ctrl*.
// Completion reads from the segment buffer are scheduled by the CplD re-ordering module
// via the rordr2ctrl* interface. Completion data is output from the segment buffer to the
// pipeline module via the ctrl2pdly* interface.
// Completion status/timeout errors are detected and segment buffers flushed
// accordingly. Errors are reported to the software via the ctrl2regfile* interface.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_edma_rdbuff_ctrl #(
  parameter TP                             = `TP                                            ,
  parameter NUM_DMA_RD_CHAN                = 1                                              ,
  parameter NUM_DMA_RD_CHAN_WIDTH          = 1                                              ,
  parameter NUM_DMA_RD_TAG                 = 16                                             ,
  parameter NUM_DMA_RD_TAG_WIDTH           = 4                                              ,
  parameter NUM_DMA_RD_SEGMENTS            = NUM_DMA_RD_TAG                                 ,
  parameter NUM_DMA_RD_SEGMENTS_WIDTH      = NUM_DMA_RD_TAG_WIDTH                           ,
  parameter CX_TAG_SIZE                    = `CX_TAG_SIZE                                   ,
  parameter DMA_SEG_BUF_DATA_WIDTH         = 32                                             , // Specifies the segment buffer data width (1/2/4 data words)
  parameter DMA_SEG_BUF_DATA_WECC_WIDTH    = 32                                             , // Specifies the segment buffer data width (1/2/4 data words) including Parity and ECC when RASDP is enabled
  parameter DMA_SEG_BUF_NW_ADDR_WIDTH      = 10                                             , // Specifies the segment buffer entry address width.
  parameter DMA_SEG_BUF_NW_ADDRP_WIDTH     = `CC_DMA_SEG_BUF_NW_ADDRP_WIDTH                 , // Read channel segment buffer parity width
  parameter DMA_SEG_DEPTH                  = 64                                             , // Specifies the number of entries per segment.
  parameter DMA_SEG_ADDR_WIDTH             = 6                                              , // Specifies the segment entry address width.
  parameter CORE_DATA_BUS_WD               = 32                                             , 
  parameter NW                             = 1                                              , 
  parameter NW_LOG2                        = 0                                              , 
  parameter FLT_Q_ATTR_WIDTH               = `FLT_Q_ATTR_WIDTH                              , 
  parameter HDR_WIDTH                      = 34 + FLT_Q_ATTR_WIDTH, // {len, attr, ep, td, tc, cpl_status, cplid} or {ide_prfx,len, ep, td, cpl_status}
  parameter NFUNC_WD                       = 3                                              , // Note: set to 3 in common constants file if SRIOV not enabled.
  parameter DBUS_DWORD_WD                  = 32                                             , 
  parameter DWORD_PROT_BITS                = 4                                              , // Number of protection bits per DWord
  parameter PM                             = `CX_RAS_PARITY_MODE                            , 
  parameter RAS_RAM_PROT_RANGE             = `CX_RAS_RAM_PROT_RANGE                         ,
  parameter RAS_PROT_RANGE                 = `CX_RAS_PROT_RANGE                             ,
  parameter RAS_PARITY_MODE                = `CX_RAS_PARITY_MODE                            ,
  parameter DATA_PROT_WD                   = `TRGT_DATA_PROT_WD                             ,
  parameter DATA_WIDTH                     = DMA_SEG_BUF_DATA_WIDTH                         ,
  parameter RAM_ECC_WD                     = DMA_SEG_BUF_DATA_WECC_WIDTH - DMA_SEG_BUF_DATA_WIDTH ,
  parameter CPL_ERR_STATUS                 = 3'b111                                         , // Read segment completion status encoding
  parameter TO_CPL_STATUS                  = 3'b101                                         
)(
  input                                                        clk                            ,
  input                                                        reset_n                        ,
  input                                                        rawreg2rdctrl_en               ,// eDMA Read enable                                                , active high
  input                                                        cfg_max_non_dma_tag_init       ,// Pulse to re-initialise segment buffer controller (phase 2)
  input                                                        rcv2rdbuff_hv                  ,
  input                                                        rcv2rdbuff_dv                  ,
  input                                                        rcv2rdbuff_eot                 ,
  input                                                        rcv2rdbuff_last                ,
  input                                                        rcv2rdbuff_tlp_abort           ,
  input                                                        rcv2rdbuff_dllp_abort          ,
  input                                                        rcv2rdbuff_ecrc_err            ,
  input [NFUNC_WD-1:0]                                         rcv2rdbuff_func_num            ,
  input [CX_TAG_SIZE-1:0]                                      rcv2rdbuff_tag                 ,
  input [9:0]                                                  rcv2rdbuff_len_dw              ,
  input [FLT_Q_ATTR_WIDTH-1:0]                                 rcv2rdbuff_attr                ,
  input                                                        rcv2rdbuff_ep                  ,
  input                                                        rcv2rdbuff_td                  ,
  input [2:0]                                                  rcv2rdbuff_tc                  ,
  input [2:0]                                                  rcv2rdbuff_status              ,
  input [15:0]                                                 rcv2rdbuff_cplid               ,
  input [DMA_SEG_BUF_DATA_WIDTH-1:0]                           rcv2rdbuff_data                ,
  input [NW-1:0]                                               rcv2rdbuff_dwen                ,
  input [DATA_PROT_WD-1:0]                                     rcv2rdbuff_data_prot           ,
  input [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                        lut2ctrl_req_seg_num           ,// Allocated segment number associated with received completion tag.
  input [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                        lut2ctrl_timeout_seg_num       ,// Allocated segment number associated with timeout tag.
  input [NUM_DMA_RD_CHAN_WIDTH-1:0]                            lut2ctrl_timeout_chan_num      ,//
  input [NUM_DMA_RD_CHAN_WIDTH-1:0]                            lut2ctrl_error_chan_num        ,//
  input [NUM_DMA_RD_CHAN_WIDTH-1:0]                            lut2ctrl_channel               ,// Request channel number
  input [NUM_DMA_RD_CHAN_WIDTH-1:0]                            lut2ctrl_timeout_channel       ,// Request timeout channel number
  input [NUM_DMA_RD_CHAN_WIDTH-1:0]                            lut2ctrl_timeout_channel_async ,// Request timeout channel number
  input [NUM_DMA_RD_SEGMENTS-1:0]                              lut2ctrl_active                ,// Segment is expecting request arrival
  input [NUM_DMA_RD_SEGMENTS-1:0]                              sbc2ctrl_full_m_1              ,// Segment "One from Full" flag
  input [NUM_DMA_RD_SEGMENTS-1:0]                              sbc2ctrl_seg_pkt_avail         ,// Segment available flag
  input [NUM_DMA_RD_SEGMENTS-1:0]                              sbc2ctrl_empty_p_1             ,// Segment "One from empty" flag
  input [NUM_DMA_RD_SEGMENTS-1:0]                              sbc2ctrl_empty                 ,// Segment "One from empty" flag
  input [DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                      sbc2ctrl_pop_data              ,
  input [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                        sbc2ctrl_waddr                 ,
  input                                                        sbc2ctrl_wen_n                 ,
  input [DMA_SEG_BUF_DATA_WIDTH-1:0]                           sbc2ctrl_wdata                 ,
  input [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                        sbc2ctrl_raddr                 ,
  input [RAM_ECC_WD-1:0]                                       sbc2ctrl_wdata_prot            ,
  input [NUM_DMA_RD_CHAN-1:0]                                  rordr2ctrl_last_chan_req       ,// Last outstanding channel request
  input                                                        sarb2rdbuff_rd_ack             ,
  input [DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                      sarb2rdbuff_rd_data            ,
  input                                                        pdly2ctrl_halt                 ,
  input                                                        rcv2rdbuff_cpl_timeout         ,
  input [CX_TAG_SIZE-1:0]                                      rcv2rdbuff_timeout_cpl_tag     ,
  input [2:0]                                                  rawreg2rdctrl_doorbell         ,
  input                                                        rawreg2rdctrl_doorbell_toggle  ,
  input                                                        rawreg2rdctrl_doorbell_stop    ,
  input                                                        rordr2ctrl_valid               ,
  input  [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       rordr2ctrl_seg_num             ,
  output [CX_TAG_SIZE-1:0]                                     ctrl2lut_cpl_tag               ,
  output [CX_TAG_SIZE-1:0]                                     ctrl2lut_timeout_tag           ,
  output [CX_TAG_SIZE-1:0]                                     ctrl2lut_error_tag             ,
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2lut_timeout_seg_num       ,
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2lut_timeout_seg_num_async ,
  output                                                       ctrl2lut_rd_seg_num_recycle    ,
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2lut_rd_seg_num            ,
  output                                                       ctrl2sbc_init                  ,
  output [(DMA_SEG_BUF_NW_ADDR_WIDTH*NUM_DMA_RD_SEGMENTS)-1:0] ctrl2sbc_init_seg_sizes        ,
  output                                                       ctrl2sbc_push_start            ,// Segment buffer push start signal
  output                                                       ctrl2sbc_push                  ,// Segment buffer push signal
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2sbc_push_seg_num          ,// Segment buffer push segment number
  output                                                       ctrl2sbc_keep                  ,// Segment buffer keep signal
  output                                                       ctrl2sbc_drop                  ,// Segment buffer drop signal
  output [DMA_SEG_BUF_DATA_WIDTH-1:0]                          ctrl2sbc_push_data             ,
  output [RAM_ECC_WD-1:0]                                      ctrl2sbc_push_data_prot        ,
  output                                                       ctrl2sbc_pop                   ,// Segment buffer pop signal
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2sbc_pop_seg_num           ,
  output [DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     ctrl2sbc_rdata                 ,
  output [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       ctrl2sarb_wr_addr              ,
  output                                                       ctrl2sarb_wr_en                ,
  output                                                       ctrl2sarb_wr_eot               ,
  output [DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     ctrl2sarb_wr_data              ,
  output [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       ctrl2sarb_rd_addr              ,
  output                                                       ctrl2sarb_rd_en                ,
  output [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       ras_rd_addr                    ,
  output                                                       ctrl2pdly_hv                   ,
  output [HDR_WIDTH-1:0]                                       ctrl2pdly_hdr                  ,
  output [NFUNC_WD-1:0]                                        ctrl2pdly_func_num             ,
  output [NUM_DMA_RD_CHAN_WIDTH-1:0]                           ctrl2pdly_channel              ,
  output                                                       ctrl2pdly_dv                   ,
  output [DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     ctrl2pdly_data                 ,
  output [NW-1:0]                                              ctrl2pdly_dwen                 ,
  output                                                       ctrl2pdly_eot                  ,
  output                                                       ctrl2pdly_error                ,
  output                                                       ctrl2pdly_last                 ,
  output                                                       ctrl2tmgr_rd_seg_num_recycle   ,
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2tmgr_rd_seg_num           ,
  output [NUM_DMA_RD_CHAN-1:0]                                 ctrl2tmgr_chan_tag_req_halt    ,
  output                                                       ctrl2rordr_rd_seg_num_recycle  ,
  output [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                       ctrl2rordr_rd_seg_num          ,
  output                                                       rdbuff_ctrl_ras_par_dt_pulse   ,
  output                                                       ctrl2rordr_ready               ,
  output [NUM_DMA_RD_SEGMENTS-1:0]                             ctrl2rordr_seg_pkt_avail_mask  
  );

//******************************************************************************
// Internal design
//******************************************************************************

   localparam PARITY_BIT                    = PM ? 1'b1 : 1'b0                                     ;
   localparam ST_WR_IDLE                    = 2'b00                                                ;
   localparam ST_WR_REQ                     = 2'b01                                                ;
   localparam ST_WR_MORE_DATA               = 2'b10                                                ;
   localparam ST_WR_WAIT                    = 2'b11                                                ;
   localparam ST_RD_IDLE                    = 2'b00                                                ;
   localparam ST_RD_REQ                     = 2'b01                                                ;
   localparam ST_RD_MORE_DATA               = 2'b10                                                ;
   localparam DWEN_LUT_DATA_WIDTH           = ((NW +DMA_SEG_ADDR_WIDTH +1) +NW)                    ;
   localparam DWEN_LUT_FIRST_DWEN_HIGH      = (DWEN_LUT_DATA_WIDTH-1)                              ;
   localparam DWEN_LUT_FIRST_DWEN_LOW       = (DWEN_LUT_DATA_WIDTH-NW)                             ;
   localparam DWEN_LUT_FIRST_DWEN_PTR_HIGH  = (DWEN_LUT_FIRST_DWEN_HIGH-NW)                        ;
   localparam DWEN_LUT_FIRST_DWEN_PTR_LOW   = (DWEN_LUT_FIRST_DWEN_LOW-DMA_SEG_ADDR_WIDTH)         ;
   localparam DWEN_LUT_FIRST_DWEN_PTR_VALID = (DWEN_LUT_FIRST_DWEN_PTR_HIGH-DMA_SEG_ADDR_WIDTH)    ;
   localparam DWEN_LUT_LAST_DWEN_HIGH       = (DWEN_LUT_FIRST_DWEN_PTR_VALID-1)                    ;
   localparam DWEN_LUT_LAST_DWEN_LOW        = (DWEN_LUT_FIRST_DWEN_PTR_VALID-NW)                   ;

  localparam HDR_INFO_SEG_WD               = 15                                               ; // {ide_prfx,len, ep, td, cpl_status} with ide, {len, ep, td, cpl_status} without 
  localparam HDR_INFO_SEG_LEN_HIGH         = 0 + HDR_INFO_SEG_WD-1 ;
  localparam HDR_INFO_SEG_LEN_LOW          = HDR_INFO_SEG_LEN_HIGH-9                                                             ; 
  localparam HDR_INFO_SEG_EP               = HDR_INFO_SEG_LEN_LOW-1                                                              ; 
  localparam HDR_INFO_SEG_TD               = HDR_INFO_SEG_EP-1                                                                   ; 
  localparam HDR_INFO_SEG_CPL_STATUS_HIGH  = HDR_INFO_SEG_TD-1                                                                   ; 
  localparam HDR_INFO_SEG_CPL_STATUS_LOW   = HDR_INFO_SEG_CPL_STATUS_HIGH-2                                                      ; 
  localparam HDR_INFO_CHAN_WD              = 19+FLT_Q_ATTR_WIDTH                                                                 ; // {attr, tc, cplid}
  localparam HDR_INFO_CHAN_ATTR_HIGH       = HDR_INFO_CHAN_WD-1                                                                  ;
  localparam HDR_INFO_CHAN_ATTR_LOW        = HDR_INFO_CHAN_ATTR_HIGH - FLT_Q_ATTR_WIDTH + 1                                      ;
  localparam HDR_INFO_CHAN_TC_HIGH         = HDR_INFO_CHAN_ATTR_LOW-1                                                            ;
  localparam HDR_INFO_CHAN_TC_LOW          = HDR_INFO_CHAN_TC_HIGH-2                                                             ;
  localparam HDR_INFO_CHAN_CPLID_HIGH      = HDR_INFO_CHAN_TC_LOW-1                                                              ;
  localparam HDR_INFO_CHAN_CPLID_LOW       = HDR_INFO_CHAN_CPLID_HIGH-15                                                         ;
  localparam HDR_INFO_EP                   = 23                                                                                  ;
  localparam HDR_INFO_CPL_STATUS_HIGH      = 18                                                                                  ;
  localparam HDR_INFO_CPL_STATUS_LOW       = 16                                                                                  ;

   logic                                                     reset_r                          ;
   logic                                                     reset_rr                         ;
   logic                                                     rawreg2rdctrl_en_r               ;
   logic                                                     rawreg2rdctrl_en_rr              ;
   logic [DMA_SEG_BUF_NW_ADDR_WIDTH*NUM_DMA_RD_SEGMENTS-1:0] s_ctrl2sbc_init_seg_sizes        ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]                           ctrl2sbc_drop_r                  ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]                           segment_ovrflw                   ;
   logic [1:0]                                               wr_current_state                 ;
   logic [1:0]                                               wr_next_state                    ;
   logic                                                     ctrl2sbc_push_start_en           ; // Segment buffer push start signal
   logic                                                     ctrl2sbc_push_en                 ; // Segment buffer push signal
   logic                                                     rd_req_queue_push_timeout        ; // Internal timeout push request
   logic                                                     rd_req_queue_push_timeout_1d     ;
   logic                                                     rd_req_queue_push_timeout_2d     ;
   logic [NUM_DMA_RD_SEGMENTS-1:0][DMA_SEG_ADDR_WIDTH-1:0]   seg_push_cnt_ary                 ;
   logic                                                     rcv2rdbuff_eot_1d                ;
   logic                                                     rcv2rdbuff_last_1d               ;
   logic                                                     rcv_wr_error_1d                  ;
   logic [NW-1:0]                                            rcv2rdbuff_dwen_1d               ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                     ctrl2sbc_push_seg_num_r          ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]                           timeout_seg_num_vec              ; // Timeout segment number bit vector
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                     timeout_push_seg_num             ; // Pushed timeout segment number
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                     timeout_push_seg_num_1d          ;
   logic                                                     rd_req_queue_push                ; // Read requets queue push signal
   logic                                                     timeout_seg_num_valid            ;
   logic [NUM_DMA_RD_CHAN_WIDTH:0]                           rdbuff2ctrlChgrp_timeout_async_s ;
   logic [NW-1:0][31:0]                                      rcv_wr_data_mask                 ;
   logic [NW-1:0][3:0]                                       rcv_wr_data_prot_mask            ;
   logic                                                     ctrl2sarb_wr_en_r                ;
   logic [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                     ctrl2sarb_wr_addr_r              ;
   logic [DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                   ctrl2sarb_wr_data_r              ;
   logic [DATA_PROT_WD-1:0]                                  sbc2ctrl_wr_data_prot_r          ;
   logic [DATA_PROT_WD-1:0]                                  r_ctrl2sbc_push_data_prot        ;
   logic                                                     ctrl2sarb_wr_eot_r               ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                     rd_req_queue_seg_num_r           ;
   logic                                                     rd_req_queue_seg_num_vld_r       ;
   logic [9:0]                                               rcv_len_dw                       ;
   logic [FLT_Q_ATTR_WIDTH-1:0]                              rcv_attr                         ;
   logic                                                     rcv_ep                           ;
   logic                                                     rcv_td                           ;
   logic [2:0]                                               rcv_tc                           ;
   logic [2:0]                                               rcv_cpl_status                   ;
   logic [15:0]                                              rcv_cplid                        ;
   logic [NFUNC_WD-1:0]                                      rcv_func_num                     ;
   logic [NUM_DMA_RD_CHAN_WIDTH-1:0]                         rcv_chan_num                     ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                     rcv_seg_num                      ;
   logic [NUM_DMA_RD_SEGMENTS-1:0][HDR_INFO_SEG_WD-1:0]      rcv_cpl_hv_info_seg_lut          ;
   logic [NUM_DMA_RD_SEGMENTS-1:0][NUM_DMA_RD_CHAN_WIDTH-1:0]rcv_chan_num_lut                 ;
   logic [NUM_DMA_RD_CHAN-1:0][HDR_INFO_CHAN_WD-1:0]         rcv_cpl_hv_info_chan_lut         ;
   logic [NUM_DMA_RD_CHAN-1:0][NFUNC_WD-1:0]                 rcv_cpl_func_info_chan_lut       ;
   logic [NUM_DMA_RD_CHAN-1:0]                               ctrl2tmgr_chan_tag_req_halt_r    ;
   logic                                                     rawreg2rdctrl_doorbell_toggle_r  ;
   logic [1:0]                                               rd_current_state                 ;
   logic [1:0]                                               rd_next_state                    ;
   logic                                                     new_seg_req_ready                ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]                           seg_pkt_avail_mask               ;
   logic                                                     s_ctrl2sbc_pop                   ;
   logic                                                     s_ctrl2pdly_dv                   ;
   logic [DMA_SEG_ADDR_WIDTH-1:0]                            seg_pop_cnt                      ;
   logic [NUM_DMA_RD_SEGMENTS-1:0][DWEN_LUT_DATA_WIDTH-1:0]  dwen_lut                         ;
   logic [NUM_DMA_RD_SEGMENTS-1:0][NW-1:0]                   ctrl2pdly_dwen_int_r             ;
   logic                                                     ctrl2sbc_pop_r                   ;
   logic [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                     ras_rd_addr_r                    ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]                           rd_req_queue_seg_error_vec       ;
   logic [NUM_DMA_RD_CHAN-1:0]                               channel_rd_seg_error_det_vec     ;
   logic [NUM_DMA_RD_CHAN-1:0]                               channel_error_det_vec            ;
   logic                                                     ctrl2sbc_push_start_en_1d        ;
   logic                                                     ctrl2sbc_push_en_1d              ;
   logic                                                     ctrl2sbc_keep_data_1d            ;
   logic                                                     ctrl2sbc_keep_data_2d            ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                     lut2ctrl_req_seg_num_1d          ;
   logic [NUM_DMA_RD_CHAN_WIDTH-1:0]                         lut2ctrl_channel_1d              ;
   logic                                                     r_ctrl2sbc_drop                  ;
   logic [DMA_SEG_BUF_DATA_WIDTH-1:0]                        r_ctrl2sbc_push_data             ;
   logic [DMA_SEG_BUF_DATA_WIDTH-1:0]                        s_ctrl2sbc_push_data_ras         ;

   logic                                                     r_poppedLast                     ;
   logic [9:0]                                               rcv2rdbuff_len_dw_1d             ;
   logic [FLT_Q_ATTR_WIDTH-1:0]                              rcv2rdbuff_attr_1d               ;
   logic                                                     rcv2rdbuff_ep_1d                 ;
   logic                                                     rcv2rdbuff_td_1d                 ;
   logic [2:0]                                               rcv2rdbuff_tc_1d                 ;
   logic [2:0]                                               rcv2rdbuff_status_1d             ;
   logic [15:0]                                              rcv2rdbuff_cplid_1d              ;
   logic [NFUNC_WD-1:0]                                      rcv2rdbuff_func_num_1d           ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] rd_req_queue_push_seg_num    ; // Read request queue push segment number.
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] rd_req_queue_push_seg_num_1d ; // Read request queue push segment number.
   logic [DMA_SEG_BUF_NW_ADDR_WIDTH-1:0] seg_size                     ;
   logic                                 rd_req                       ;
   logic                                 rcv_wr_error                 ; // TLP completion aborted
   logic                                 ctrl2sbc_keep_data           ; // Segment buffer keep data signal
   logic [RAM_ECC_WD-1:0]                ctrl2sarb_wr_data_prot       ;
   logic [RAM_ECC_WD-1:0]                s_ctrl2sbc_push_data_ecc     ;
   logic [RAM_ECC_WD-1:0]                r_ctrl2sbc_push_data_ecc     ;
   logic                                 rdbuff_ctrl_dt_raserr        ;
   logic [DATA_PROT_WD-1:0]              s_ctrl2sbc_push_data_prot    ;
   logic [9:0]                           len_dw                       ;
   logic [9:0]                           len_dw_lut                   ;
   logic                                 carry_a                      ;
   logic                                 ep                           ;
   logic                                 ep_lut                       ;
   logic [HDR_INFO_SEG_WD-1:0]           rcv_cpl_hv_info_seg_vec      ;
   logic [HDR_INFO_CHAN_WD-1:0]          rcv_cpl_hv_info_chan_vec     ;
   logic                                 rcv_status_su                ;
   logic                                 rawreg2rdctrl_doorbell_det   ;
   logic                                 rd_ack                       ;
   logic [HDR_INFO_CHAN_WD-1:0]          pdly_hv_info_chan_vec        ;
   logic [HDR_INFO_SEG_WD-1:0]           pdly_hv_info_seg_vec         ;
   logic [HDR_WIDTH-1:0]                 pdly_hv_info_vec             ;
   logic                                 rd_hdr_ep_err                ;
   logic                                 rd_hdr_ur_err                ;
   logic                                 rd_hdr_ca_err                ;
   logic                                 rd_hdr_to_err                ;
   logic                                 ctrl2sbc_pop_fall            ;
   logic                                 rdbuff2ctrl_channel_err_det  ;
   logic [DMA_SEG_BUF_DATA_WIDTH-1:0]    s_ctrl2sbc_push_data         ;
   logic                                 s_ctrl2sbc_drop              ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] ctrl2lut_timeout_seg_num_1d  ;
   logic                                 r_dont_push                  ;
   logic                                 r_cpl_inflight               ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]       r_trashing_lut               ;
   logic                                 r_trashing_cpl               ;
   logic                                 s_trash_cpl                  ;
   logic                                 s_trash_tout                 ;
   logic                                 int_ctrl2sbc_push            ;
   logic                                 int_ctrl2sbc_push_start      ;
   logic                                 int_ctrl2sbc_keep            ;
   logic                                 int_ctrl2sbc_drop            ;
   logic                                 int_ctrl2sbc_last            ;
   logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] int_ctrl2sbc_push_seg_num    ;
   logic [NW-1:0]                        int_rcv2rdbuff_dwen_1d       ;
   logic [DMA_SEG_BUF_DATA_WIDTH-1:0]    int_ctrl2sbc_push_data       ;
   logic [NUM_DMA_RD_SEGMENTS-1:0]       int_sbc2ctrl_full_m_1        ;

  logic                                 s_rcv2rdbuff_hv , r_rcv2rdbuff_hv;
  logic                                 s_rcv2rdbuff_dv , r_rcv2rdbuff_dv;
  logic                                 s_rcv2rdbuff_eot , r_rcv2rdbuff_eot;
  logic                                 s_rcv2rdbuff_last , r_rcv2rdbuff_last;
  logic                                 s_rcv2rdbuff_tlp_abort , r_rcv2rdbuff_tlp_abort;
  logic                                 s_rcv2rdbuff_dllp_abort , r_rcv2rdbuff_dllp_abort;
  logic                                 s_rcv2rdbuff_ecrc_err , r_rcv2rdbuff_ecrc_err;
  logic [NFUNC_WD-1:0]                  s_rcv2rdbuff_func_num , r_rcv2rdbuff_func_num;
  logic [CX_TAG_SIZE-1:0]               s_rcv2rdbuff_tag , r_rcv2rdbuff_tag;
  logic [9:0]                           s_rcv2rdbuff_len_dw , r_rcv2rdbuff_len_dw;
  logic [FLT_Q_ATTR_WIDTH-1:0]          s_rcv2rdbuff_attr , r_rcv2rdbuff_attr;
  logic                                 s_rcv2rdbuff_ep , r_rcv2rdbuff_ep;
  logic                                 s_rcv2rdbuff_td , r_rcv2rdbuff_td;
  logic [2:0]                           s_rcv2rdbuff_tc , r_rcv2rdbuff_tc;
  logic [2:0]                           s_rcv2rdbuff_status , r_rcv2rdbuff_status;
  logic [15:0]                          s_rcv2rdbuff_cplid , r_rcv2rdbuff_cplid;
  logic [DMA_SEG_BUF_DATA_WIDTH-1:0]    s_rcv2rdbuff_data , r_rcv2rdbuff_data;
  logic [NW-1:0]                        s_rcv2rdbuff_dwen , r_rcv2rdbuff_dwen;
  logic [DATA_PROT_WD-1:0]              s_rcv2rdbuff_data_prot , r_rcv2rdbuff_data_prot;
  logic                                 s_rcv2rdbuff_cpl_timeout , r_rcv2rdbuff_cpl_timeout;
  logic [CX_TAG_SIZE-1:0]               s_rcv2rdbuff_timeout_cpl_tag , r_rcv2rdbuff_timeout_cpl_tag;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] s_lut2ctrl_req_seg_num , r_lut2ctrl_req_seg_num;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] s_lut2ctrl_timeout_seg_num , r_lut2ctrl_timeout_seg_num;
  logic [NUM_DMA_RD_CHAN_WIDTH-1:0]     s_lut2ctrl_timeout_chan_num , r_lut2ctrl_timeout_chan_num;
  logic [NUM_DMA_RD_CHAN_WIDTH-1:0]     s_lut2ctrl_error_chan_num , r_lut2ctrl_error_chan_num;
  logic [NUM_DMA_RD_CHAN_WIDTH-1:0]     s_lut2ctrl_channel , r_lut2ctrl_channel;
  logic [NUM_DMA_RD_SEGMENTS-1:0]       s_lut2ctrl_active , r_lut2ctrl_active;

   logic [NUM_DMA_RD_SEGMENTS-1:0]      s_mark_avail_p, w_mark_avail_p;   // Added to the top of the signals declaration


logic                                 ctrl2pdly_hv_s;
logic [HDR_WIDTH-1:0]                 ctrl2pdly_hdr_s;
logic [NFUNC_WD-1:0]                  ctrl2pdly_func_num_s;
logic [NUM_DMA_RD_CHAN_WIDTH-1:0]     ctrl2pdly_channel_s;
logic                                 ctrl2pdly_dv_s;
logic [NW-1:0]                        ctrl2pdly_dwen_s;
logic                                 ctrl2pdly_eot_s;




  always_ff @(posedge clk, negedge reset_n) begin : proc_inReg_SEQ_PROC
    if(!reset_n) begin
     r_rcv2rdbuff_hv                  <= #`TP '0;
     r_rcv2rdbuff_dv                  <= #`TP '0;
     r_rcv2rdbuff_eot                 <= #`TP '0;
     r_rcv2rdbuff_last                <= #`TP '0;
     r_rcv2rdbuff_tlp_abort           <= #`TP '0;
     r_rcv2rdbuff_dllp_abort          <= #`TP '0;
     r_rcv2rdbuff_ecrc_err            <= #`TP '0;
     r_rcv2rdbuff_func_num            <= #`TP '0;
     r_rcv2rdbuff_tag                 <= #`TP '0;
     r_rcv2rdbuff_len_dw              <= #`TP '0;
     r_rcv2rdbuff_attr                <= #`TP '0;
     r_rcv2rdbuff_ep                  <= #`TP '0;
     r_rcv2rdbuff_td                  <= #`TP '0;
     r_rcv2rdbuff_tc                  <= #`TP '0;
     r_rcv2rdbuff_status              <= #`TP '0;
     r_rcv2rdbuff_cplid               <= #`TP '0;
     r_rcv2rdbuff_data                <= #`TP '0;
     r_rcv2rdbuff_dwen                <= #`TP '0;
     r_rcv2rdbuff_data_prot           <= #`TP '0;
     r_rcv2rdbuff_cpl_timeout         <= #`TP '0;
     r_rcv2rdbuff_timeout_cpl_tag     <= #`TP '0;
     r_lut2ctrl_req_seg_num           <= #`TP '0;
     r_lut2ctrl_timeout_seg_num       <= #`TP '0;
     r_lut2ctrl_timeout_chan_num      <= #`TP '0;
     r_lut2ctrl_error_chan_num        <= #`TP '0;
     r_lut2ctrl_channel               <= #`TP '0;
     r_lut2ctrl_active                <= #`TP '0;
    end else begin
     r_rcv2rdbuff_hv                  <= #`TP rcv2rdbuff_hv              ;
     r_rcv2rdbuff_dv                  <= #`TP rcv2rdbuff_dv              ;
     r_rcv2rdbuff_eot                 <= #`TP rcv2rdbuff_eot             ;
     r_rcv2rdbuff_last                <= #`TP rcv2rdbuff_last            ;
     r_rcv2rdbuff_tlp_abort           <= #`TP rcv2rdbuff_tlp_abort       ;
     r_rcv2rdbuff_dllp_abort          <= #`TP rcv2rdbuff_dllp_abort      ;
     r_rcv2rdbuff_ecrc_err            <= #`TP rcv2rdbuff_ecrc_err        ;
     r_rcv2rdbuff_func_num            <= #`TP rcv2rdbuff_func_num        ;
     r_rcv2rdbuff_tag                 <= #`TP rcv2rdbuff_tag             ;
     r_rcv2rdbuff_len_dw              <= #`TP rcv2rdbuff_len_dw          ;
     r_rcv2rdbuff_attr                <= #`TP rcv2rdbuff_attr            ;
     r_rcv2rdbuff_ep                  <= #`TP rcv2rdbuff_ep              ;
     r_rcv2rdbuff_td                  <= #`TP rcv2rdbuff_td              ;
     r_rcv2rdbuff_tc                  <= #`TP rcv2rdbuff_tc              ;
     r_rcv2rdbuff_status              <= #`TP rcv2rdbuff_status          ;
     r_rcv2rdbuff_cplid               <= #`TP rcv2rdbuff_cplid           ;
     r_rcv2rdbuff_data                <= #`TP rcv2rdbuff_data            ;
     r_rcv2rdbuff_dwen                <= #`TP rcv2rdbuff_dwen            ;
     r_rcv2rdbuff_data_prot           <= #`TP rcv2rdbuff_data_prot       ;
     r_rcv2rdbuff_cpl_timeout         <= #`TP rcv2rdbuff_cpl_timeout     ;
     r_rcv2rdbuff_timeout_cpl_tag     <= #`TP rcv2rdbuff_timeout_cpl_tag ;
     r_lut2ctrl_req_seg_num           <= #`TP lut2ctrl_req_seg_num       ;
     r_lut2ctrl_timeout_seg_num       <= #`TP lut2ctrl_timeout_seg_num   ;
     r_lut2ctrl_timeout_chan_num      <= #`TP lut2ctrl_timeout_chan_num  ;
     r_lut2ctrl_error_chan_num        <= #`TP lut2ctrl_error_chan_num    ;
     r_lut2ctrl_channel               <= #`TP lut2ctrl_channel           ;
     r_lut2ctrl_active                <= #`TP lut2ctrl_active            ;
    end
  end : proc_inReg_SEQ_PROC

  assign s_rcv2rdbuff_hv                  = r_rcv2rdbuff_hv              ;
  assign s_rcv2rdbuff_dv                  = r_rcv2rdbuff_dv              ;
  assign s_rcv2rdbuff_eot                 = r_rcv2rdbuff_eot             ;
  assign s_rcv2rdbuff_last                = r_rcv2rdbuff_last            ;
  assign s_rcv2rdbuff_tlp_abort           = r_rcv2rdbuff_tlp_abort       ;
  assign s_rcv2rdbuff_dllp_abort          = r_rcv2rdbuff_dllp_abort      ;
  assign s_rcv2rdbuff_ecrc_err            = r_rcv2rdbuff_ecrc_err        ;
  assign s_rcv2rdbuff_func_num            = r_rcv2rdbuff_func_num        ;
  assign s_rcv2rdbuff_tag                 = r_rcv2rdbuff_tag             ;
  assign s_rcv2rdbuff_len_dw              = r_rcv2rdbuff_len_dw          ;
  assign s_rcv2rdbuff_attr                = r_rcv2rdbuff_attr            ;
  assign s_rcv2rdbuff_ep                  = r_rcv2rdbuff_ep              ;
  assign s_rcv2rdbuff_td                  = r_rcv2rdbuff_td              ;
  assign s_rcv2rdbuff_tc                  = r_rcv2rdbuff_tc              ;
  assign s_rcv2rdbuff_status              = r_rcv2rdbuff_status          ;
  assign s_rcv2rdbuff_cplid               = r_rcv2rdbuff_cplid           ;
  assign s_rcv2rdbuff_data                = r_rcv2rdbuff_data            ;
  assign s_rcv2rdbuff_dwen                = r_rcv2rdbuff_dwen            ;
  assign s_rcv2rdbuff_data_prot           = r_rcv2rdbuff_data_prot       ;
  assign s_rcv2rdbuff_cpl_timeout         = r_rcv2rdbuff_cpl_timeout     ;
  assign s_rcv2rdbuff_timeout_cpl_tag     = r_rcv2rdbuff_timeout_cpl_tag ;
  assign s_lut2ctrl_req_seg_num           = r_lut2ctrl_req_seg_num       ;
  assign s_lut2ctrl_timeout_seg_num       = r_lut2ctrl_timeout_seg_num   ;
  assign s_lut2ctrl_timeout_chan_num      = r_lut2ctrl_timeout_chan_num  ;
  assign s_lut2ctrl_error_chan_num        = r_lut2ctrl_error_chan_num    ;
  assign s_lut2ctrl_channel               = r_lut2ctrl_channel           ;
  assign s_lut2ctrl_active                = r_lut2ctrl_active            ;

// ----------------------------------------------------------------------------
// Generate the segment buffer initialisation pulse on power up
// ----------------------------------------------------------------------------

   always @(posedge clk or negedge reset_n) begin : proc_seq_reset_pulse
      if (!reset_n) begin
        reset_r  <= # TP 1'b0;
        reset_rr <= # TP 1'b0;
      end else begin
        reset_r  <= # TP 1'b1;
        reset_rr <= # TP reset_r;
      end
   end


   always @ ( posedge clk or negedge reset_n) begin : proc_seq_en_pulse
      if (!reset_n) begin
         rawreg2rdctrl_en_r  <= #TP 1'b0;
         rawreg2rdctrl_en_rr <= #TP 1'b0;
      end else begin
         rawreg2rdctrl_en_r  <= #TP rawreg2rdctrl_en;
         rawreg2rdctrl_en_rr <= #TP rawreg2rdctrl_en_r;
      end
   end

  assign ctrl2sbc_init = (reset_r & ~reset_rr) | (rawreg2rdctrl_en_r & ~rawreg2rdctrl_en_rr);

// ----------------------------------------------------------------------------
// Initialise the segment buffer
// ----------------------------------------------------------------------------
// The segment buffer uses the following hardwired configuration parmeters:
// - the number of segments and the binary width for same;
// - the number of bits or width of each entry pushed or popped from the segment buffer and
// - the segment buffer entry address width = log2[total number of entries in the RAM].
// The physical 2-port RAM is fixed at 8 data words per entry. The SRAM arbiter packs and unpacks
// 1/2/4 data word write and read transactions respectively depending on the data width of the core.
// From the rdbuff block perspective the SRAM interface appears as a 1/2/4 data word 2 port RAM interface.
// The total number of entries in the RAM as viewed by the segment buffer controller is equal to
// ((CX_MAX_MTU / 4*CX_NW) * NUM_DMA_RD_SEGMENTS).
// In 64-bit and 128-bit core configurations data word holes, incurred when the completion is split, are
// removed by the rdbuff_dword_align block when data is written to the segment buffer.

   // ----------------------------------------------------------------------------
   // Build the segment size initialisation array ([Number of segments][Segment depth].
   // The depth of each segment is equal to the number of entries and
   // is fixed at (Max_Payload_Size_Supported / Core data width).
   // ----------------------------------------------------------------------------

   assign seg_size = (DMA_SEG_DEPTH-1); // Segment size=0 is interpreted as size=1

   always @(*) begin : proc_comb_init_seg_sizes
      integer i,j;

      s_ctrl2sbc_init_seg_sizes = {DMA_SEG_BUF_NW_ADDR_WIDTH*NUM_DMA_RD_SEGMENTS{1'b0}};

      for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
         for (j=0; j<DMA_SEG_BUF_NW_ADDR_WIDTH; j=j+1) begin
            s_ctrl2sbc_init_seg_sizes[i*DMA_SEG_BUF_NW_ADDR_WIDTH+j] = seg_size[j];
         end
      end
   end

   assign ctrl2sbc_init_seg_sizes = s_ctrl2sbc_init_seg_sizes;

   //-------------------------------------------------
   // CPL filter. Filters out unexpected compleations
   //-------------------------------------------------

   always_ff @(posedge clk, negedge reset_n) begin : trashing_lut_PROC
     if (!reset_n) begin
       r_trashing_lut <= #`TP '0;
     end else begin
       foreach (r_trashing_lut[i]) begin
         if (ctrl2sbc_pop && ctrl2sbc_pop_seg_num == i && sbc2ctrl_empty_p_1[i]) begin
           r_trashing_lut[i] <= #`TP '0;
         end else if (s_rcv2rdbuff_eot && s_rcv2rdbuff_last && !s_rcv2rdbuff_tlp_abort && !s_rcv2rdbuff_dllp_abort && s_lut2ctrl_req_seg_num == i) begin
           r_trashing_lut[i] <= #`TP '1;
         end else if (s_rcv2rdbuff_cpl_timeout && s_lut2ctrl_timeout_seg_num == i) begin
           r_trashing_lut[i] <= #`TP '1;
         end else begin
           r_trashing_lut[i] <= #`TP r_trashing_lut[i];
         end
       end
     end
   end

   always_ff @(posedge clk, negedge reset_n) begin : trashing_cpl_PROC
     if (!reset_n) begin
       r_trashing_cpl <= #`TP '0;
     end else begin
       if (s_rcv2rdbuff_eot) begin
         r_trashing_cpl <= #`TP '0;
       end else if (s_rcv2rdbuff_hv && (r_trashing_lut[s_lut2ctrl_req_seg_num] || !s_lut2ctrl_active[s_lut2ctrl_req_seg_num] )) begin
         r_trashing_cpl <= #`TP '1;
       end else begin
         r_trashing_cpl <= #`TP r_trashing_cpl;
       end
     end
   end

   always_comb s_trash_cpl  = s_rcv2rdbuff_hv ? (r_trashing_lut[s_lut2ctrl_req_seg_num    ] || !s_lut2ctrl_active[s_lut2ctrl_req_seg_num    ] ) : r_trashing_cpl;
   assign      s_trash_tout =                    r_trashing_lut[s_lut2ctrl_timeout_seg_num] || !s_lut2ctrl_active[s_lut2ctrl_timeout_seg_num]   ;

//--------------------------------------------------------------------
// Write FSM
//--------------------------------------------------------------------
// State machine to control write transactions to the segment buffer
//--------------------------------------------------------------------
// Encoding for state machine
//--------------------------------------------------------------------
// Write FSM control inputs
//--------------------------------------------------------------------
   //--------------------------------------------------------------------
   // Check for segment overflow during write transfer.
   // If detected then block push to data segment.
   //--------------------------------------------------------------------

   always @(posedge clk or negedge reset_n) begin : proc_seq_drop_r
      integer i;

      if (!reset_n) begin
        ctrl2sbc_drop_r <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
        ctrl2sbc_drop_r <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
          if ((i==int_ctrl2sbc_push_seg_num) && int_ctrl2sbc_push && int_ctrl2sbc_drop) begin
          // Set flag if completion discarded and write pointer rolled back
            ctrl2sbc_drop_r[i] <= # TP 1'b1;
          end else if ((i==int_ctrl2sbc_push_seg_num) && int_ctrl2sbc_push_start) begin
          // Clear flag on next push to data segment, i.e. start of next CPL or completion timeout
            ctrl2sbc_drop_r[i] <= # TP 1'b0;
          end
        end
      end
   end
   
   always @(posedge clk or negedge reset_n) begin : proc_seq_seg_overflow
      integer i;

      if (!reset_n) begin
        segment_ovrflw <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
        segment_ovrflw <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
          // Clear overflow flag on last aborted beat
          if ((i==int_ctrl2sbc_push_seg_num) && (int_ctrl2sbc_drop || int_ctrl2sbc_keep)) begin
            segment_ovrflw[i] <= # TP 1'b0;
          // Detect overflow if more data than expected pushed to segment.
          // Note: If the CPL is aborted one from full the SBC still asserts the
          // sbc2ctrl_full_m_1 flag.
          // On the next hv the write pointer will be rolled back.
          // To avoid blocking the replayed completion the segment overflow flag
          // is not asserted.
          // In addition if the CPL is aborted when the buffer is full the
          // overflow flag is not asserted.
          end else if ((i==int_ctrl2sbc_push_seg_num) && int_ctrl2sbc_push
                        && !ctrl2sbc_drop_r[i]
                        && (int_sbc2ctrl_full_m_1[i])) begin
            segment_ovrflw[i] <= # TP 1'b1;
          end
        end
      end
   end

//--------------------------------------------------------------------
// Write FSM Sequential process
//--------------------------------------------------------------------

   always @(posedge clk or negedge reset_n) begin : proc_seq_write_fsm
      if (!reset_n) begin
        wr_current_state <= # TP ST_WR_IDLE;
      end else if (!rawreg2rdctrl_en) begin
        wr_current_state <= # TP ST_WR_IDLE;
      end else begin
        wr_current_state <= # TP wr_next_state;
      end
   end

//--------------------------------------------------------------------
// Write FSM combinational process
//--------------------------------------------------------------------
   always @(*) begin : proc_comb_write_fsm

      // Default assignments: if the following case statement does not
      // set a signal to a new value, then hold the old value.
      wr_next_state = wr_current_state;

      // Only valid DMA completions are routed to the read buffer.
      // Filtering performed by the rcv_route block (range CX_MAX_TAG to (CX_MAX_TAG - CC_NUM_DMA_RD_TAG).
      // Tags outside of DMA range routed to the bridge (range CC_DMA_NUM_DMA_RD_TAG-1 to 0 only accepted).
      case (wr_current_state)
          ST_WR_IDLE      : begin
            // Write FSM transitons from ST_WR_IDLE for valid multi-beat CplD's only.
            // Remains in ST_WR_IDLE if a one beat CplD or a Cpl (e.g. completion with cpl_status = UR/CA),
            // or a completion timeout is received.
            // In addition protect buffer if unexpected CPL aborted and tlp_abort asserted with hv.
            if (s_rcv2rdbuff_hv && s_rcv2rdbuff_dv && !s_rcv2rdbuff_eot && !s_trash_cpl) begin
              wr_next_state = ST_WR_REQ;
            end
          end
          ST_WR_REQ : begin
            if (s_rcv2rdbuff_dv && s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_IDLE;
            end else if (!s_rcv2rdbuff_dv && !s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_WAIT;
            end else if (s_rcv2rdbuff_dv && !s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_MORE_DATA;
            end
          end
          ST_WR_MORE_DATA : begin
            if (s_rcv2rdbuff_dv && s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_IDLE;
            end else if (!s_rcv2rdbuff_dv && !s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_WAIT;
            end
          end
          ST_WR_WAIT      : begin
            if (s_rcv2rdbuff_dv && s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_IDLE;
            end else if (s_rcv2rdbuff_dv && !s_rcv2rdbuff_eot) begin
              wr_next_state = ST_WR_MORE_DATA;
            end
          end
          default          : begin
            // Illegal states (X, Z), should never be reached.
            wr_next_state = ST_WR_IDLE;
          end
      endcase
   end

//--------------------------------------------------------------------
// Write FSM control outputs
//--------------------------------------------------------------------
   //--------------------------------------------------------------------
   // Segment buffer push control
   //--------------------------------------------------------------------

   always @(*) begin : proc_comb_sbc_push

     ctrl2sbc_push_start_en = 1'b0;
     ctrl2sbc_push_en = 1'b0;

       case (wr_current_state)
         // Push valid single beat CplD's, Cpl's (errored completions with cpl_tatus != SU or EP=1)
         // and completion timeout requests.
         ST_WR_IDLE                             : begin
           if ((s_rcv2rdbuff_hv && !s_trash_cpl) || rd_req_queue_push_timeout) begin
             ctrl2sbc_push_start_en = 1'b1;
             ctrl2sbc_push_en = 1'b1;
           end
         end
         // Push valid multi-beat CplD's
         ST_WR_REQ, ST_WR_WAIT, ST_WR_MORE_DATA : begin
           if (s_rcv2rdbuff_dv) begin
             ctrl2sbc_push_en = 1'b1;
           end
         end
         default                                : begin
             ctrl2sbc_push_start_en = 1'b0;
             ctrl2sbc_push_en = 1'b0;
         end
       endcase
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_sbc_push_start_en_1d
     if (!reset_n) begin
       ctrl2sbc_push_start_en_1d <= # TP '0;
     end else begin
       if (ctrl2sbc_push_start_en ^ ctrl2sbc_push_start_en_1d) begin
         ctrl2sbc_push_start_en_1d <= # TP ctrl2sbc_push_start_en;
       end else begin
         ctrl2sbc_push_start_en_1d <= # TP ctrl2sbc_push_start_en_1d;
       end
     end
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_sbc_push_en_1d
     if (!reset_n) begin
       ctrl2sbc_push_en_1d <= # TP '0;
     end else begin
       if (ctrl2sbc_push_en ^ ctrl2sbc_push_en_1d) begin
         ctrl2sbc_push_en_1d <= # TP ctrl2sbc_push_en;
       end else begin
         ctrl2sbc_push_en_1d <= # TP ctrl2sbc_push_en_1d;
       end
     end
   end

   //--------------------------------------------------------------------
   // Segment buffer keep/drop control
   //--------------------------------------------------------------------

   // The TLP completion packet is kept in the segment buffer if the following conditions are met:
   // - the receive TLP tag is inside the valid range of eDMA read tags
   // - the error signals dllp_abort or tlp_abort are not asserted by the
   //   core bypass/cpl/trgt completion interface. Note: the error signals are normally asserted
   //   in conjunction with s_rcv2rdbuff_eot.
   assign rcv_wr_error = ((s_rcv2rdbuff_eot && !s_trash_cpl)
                          && (s_rcv2rdbuff_tlp_abort || s_rcv2rdbuff_dllp_abort));

   assign ctrl2sbc_keep_data = rcv_wr_error ? 1'b0 : s_rcv2rdbuff_eot && !s_trash_cpl;

   always @(posedge clk or negedge reset_n) begin : proc_seq_ctrl2sbc_keep_data_1d
     if (!reset_n) begin
       ctrl2sbc_keep_data_1d <= # TP '0;
     end else begin
       if (ctrl2sbc_keep_data ^ ctrl2sbc_keep_data_1d) begin
         ctrl2sbc_keep_data_1d <= # TP ctrl2sbc_keep_data;
       end else begin
         ctrl2sbc_keep_data_1d <= # TP ctrl2sbc_keep_data_1d;
       end
     end
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_ctrl2sbc_keep_data_2d
     if (!reset_n) begin
       ctrl2sbc_keep_data_2d <= # TP '0;
     end else begin
       if (ctrl2sbc_keep_data_1d ^ ctrl2sbc_keep_data_2d) begin
         ctrl2sbc_keep_data_2d <= # TP ctrl2sbc_keep_data_1d;
       end else begin
         ctrl2sbc_keep_data_2d <= # TP ctrl2sbc_keep_data_2d;
       end
     end
   end
   assign s_ctrl2sbc_drop = rcv_wr_error ? s_rcv2rdbuff_eot && !s_trash_cpl : 1'b0;

   always @(posedge clk or negedge reset_n) begin : proc_seq_r_ctrl2sbc_drop
     if (!reset_n) begin
       r_ctrl2sbc_drop <= # TP '0;
     end else begin
       if (r_ctrl2sbc_drop ^ s_ctrl2sbc_drop) begin
         r_ctrl2sbc_drop <= # TP s_ctrl2sbc_drop;
       end else begin
         r_ctrl2sbc_drop <= # TP r_ctrl2sbc_drop;
       end
     end
   end

   assign int_ctrl2sbc_drop = !r_dont_push & r_ctrl2sbc_drop;

   assign int_ctrl2sbc_keep = !r_dont_push & (ctrl2sbc_keep_data_1d | rd_req_queue_push_timeout_1d);

   assign int_ctrl2sbc_push_start = !r_dont_push & ctrl2sbc_push_start_en_1d & ~segment_ovrflw[int_ctrl2sbc_push_seg_num];
   assign int_ctrl2sbc_push       = !r_dont_push & ctrl2sbc_push_en_1d & ~segment_ovrflw[int_ctrl2sbc_push_seg_num];


   assign ctrl2pdly_hv       = ctrl2pdly_hv_s;
   assign ctrl2pdly_hdr      = ctrl2pdly_hdr_s;
   assign ctrl2pdly_func_num = ctrl2pdly_func_num_s;
   assign ctrl2pdly_channel  = ctrl2pdly_channel_s;
   assign ctrl2pdly_dv       = ctrl2pdly_dv_s;
   assign ctrl2pdly_dwen     = ctrl2pdly_dwen_s;
   assign ctrl2pdly_eot      = ctrl2pdly_eot_s;

   assign ctrl2sbc_push = int_ctrl2sbc_push;
   assign ctrl2sbc_push_start = int_ctrl2sbc_push_start;
   assign ctrl2sbc_keep = int_ctrl2sbc_keep;
   assign ctrl2sbc_drop = int_ctrl2sbc_drop;
   assign ctrl2sbc_push_seg_num = int_ctrl2sbc_push_seg_num;
   assign rcv2rdbuff_dwen_1d = int_rcv2rdbuff_dwen_1d;
   assign ctrl2sbc_push_data = int_ctrl2sbc_push_data;

   assign int_sbc2ctrl_full_m_1 = sbc2ctrl_full_m_1;

      //--------------------------------------------------------------------
      // Generate segment entry push data count for first split completion.
      // Split completions per tag can be received in any order. Therefore
      // we need to track push count per segment.
      //--------------------------------------------------------------------

      always @(posedge clk or negedge reset_n) begin : proc_seq_rcv2rdbuff_eot_1d
        if (!reset_n) begin
          rcv2rdbuff_eot_1d      <= # TP '0;
          rcv_wr_error_1d        <= # TP '0;
          int_rcv2rdbuff_dwen_1d <= # TP '0;
          rcv2rdbuff_last_1d     <= # TP '0;
        end else begin
          if (s_rcv2rdbuff_eot && !s_trash_cpl) begin
            rcv2rdbuff_eot_1d      <= # TP 1'b1;
            rcv_wr_error_1d        <= # TP (s_rcv2rdbuff_tlp_abort || s_rcv2rdbuff_dllp_abort);
            int_rcv2rdbuff_dwen_1d <= # TP s_rcv2rdbuff_dwen;
            rcv2rdbuff_last_1d     <= # TP s_rcv2rdbuff_last;
          end else begin
            rcv2rdbuff_eot_1d      <= # TP 1'b0;
            rcv_wr_error_1d        <= # TP rcv_wr_error_1d;
            int_rcv2rdbuff_dwen_1d <= # TP int_rcv2rdbuff_dwen_1d;
            rcv2rdbuff_last_1d     <= # TP rcv2rdbuff_last_1d;
          end
        end
      end
 
      always @(posedge clk or negedge reset_n) begin : proc_seq_seg_push_cnt
         integer i;

         if (!reset_n) begin
           for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             seg_push_cnt_ary[i] <= # TP 'd0;
           end
         end else if ( !rawreg2rdctrl_en) begin
           for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             seg_push_cnt_ary[i] <= # TP 'd0;
           end
         end else begin
           for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             if ((i==ctrl2sbc_push_seg_num) && (rcv2rdbuff_eot_1d || rd_req_queue_push_timeout_1d)) begin
                seg_push_cnt_ary[i] <= # TP 'd0;
              end else if ((i==ctrl2sbc_push_seg_num) && ctrl2sbc_push) begin
                seg_push_cnt_ary[i] <= # TP seg_push_cnt_ary[i] +1;
              end
           end
         end
      end

   //--------------------------------------------------------------------
   // Lookup the segment number associated with the completion.
   //--------------------------------------------------------------------
   assign ctrl2lut_cpl_tag = rcv2rdbuff_tag; // Pass PCIe tag to segment number LUT

   // Hold segment number valid for duration of segment buffer write data transfer,
   // not just when ctrl2sbc_push is valid.

   always @(posedge clk or negedge reset_n) begin : proc_seq_lut2ctrl_req_seg_num_1d
      if (!reset_n) begin
        lut2ctrl_req_seg_num_1d <= # TP '0;
      end else if (|(lut2ctrl_req_seg_num_1d ^ s_lut2ctrl_req_seg_num)) begin
        lut2ctrl_req_seg_num_1d <= # TP s_lut2ctrl_req_seg_num;
      end else begin
        lut2ctrl_req_seg_num_1d <= # TP lut2ctrl_req_seg_num_1d;
      end
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_push_seg_num
      if (!reset_n) begin
        ctrl2sbc_push_seg_num_r <= # TP {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
        ctrl2sbc_push_seg_num_r <= # TP {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
      end else if (ctrl2sbc_push_start_en_1d) begin
        ctrl2sbc_push_seg_num_r <= # TP lut2ctrl_req_seg_num_1d;
      end
   end

   // Push segment number. Timeout segment number only valid for one cycle.
   assign int_ctrl2sbc_push_seg_num = (rd_req_queue_push_timeout_1d) ? ctrl2lut_timeout_seg_num_1d :
                                      (ctrl2sbc_push_start_en_1d & ~rd_req_queue_push_timeout_1d) ? lut2ctrl_req_seg_num_1d :
                                      ctrl2sbc_push_seg_num_r;

   //--------------------------------------------------------------------
   // Generate the read request queue push signal.
   //--------------------------------------------------------------------
   // Push the read request queue on the last completion write to the segment buffer or when
   // a completion timeout occurs. The 2 conditions to push the read request queue can occur simultaneously.
   // The segment number corresponding to the timeout is stored locally and pushed into the read request queue
   // after the segment write completes.

   // If the last compeltion is not successfull we set a flag to inform the Read FSM to flush
   // the corresponding segment. When the segment read is scheduled the Read FSM will flush one or more completions
   // depending on the completion transaction , i.e split or non-split.

   // When a completion timeout occurs we pop the header information from the completion header
   // look up table.
   // Note: a timeout is generated by the PCie core after tlp_abort/dllp_abort/ecrc_rror asserted
   // to enable the controller to refresh the tag pool and generate the completion error response.
   //--------------------------------------------------------------------
   // Lookup segment number corresponding with timeout tag.
   assign ctrl2lut_timeout_tag = rcv2rdbuff_timeout_cpl_tag;


   // Track timeout segment number requests.
   // Handle back to back completion timeouts for the number of outstanding outbound read requests.
   always @(posedge clk or negedge reset_n) begin : proc_seq_timeout_seg_num
      integer i;

      if (!reset_n) begin
          timeout_seg_num_vec <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
          timeout_seg_num_vec <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else begin
         for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
            // Set timeout segment number pointer.
            if ((i==s_lut2ctrl_timeout_seg_num) && s_rcv2rdbuff_cpl_timeout && !s_trash_tout) begin
               timeout_seg_num_vec[i] <= # TP 1'b1;
            // Clear the timeout segment number pointer when the timeout segment number
            // is pushed into the read request queue.
            end else if ((i==timeout_push_seg_num) && rd_req_queue_push_timeout) begin
               timeout_seg_num_vec[i] <= # TP 1'b0;
            end
         end
      end
   end

   // Search completion timeout queue for next completion timeout segment number.
   // Note: timeout requests can be received back to back. Therefore we need to store each
   // timeout request and process in sequence when there is no contention with completion
   // writes to segment buffer.

   always @(*) begin : proc_comb_timeout_seg_req
      {timeout_seg_num_valid, timeout_push_seg_num} = binsearch(timeout_seg_num_vec);
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_timeout_push_seg_num_1d
      if (!reset_n) begin
        timeout_push_seg_num_1d <= # TP '0;
      end else if (timeout_seg_num_valid) begin
        timeout_push_seg_num_1d <= # TP timeout_push_seg_num;
      end else begin
        timeout_push_seg_num_1d <= # TP timeout_push_seg_num_1d;
      end
   end

   //--------------------------------------------------------------------
   // Generate the read request queue push signal and segment number
   //--------------------------------------------------------------------
   always @(*) begin : proc_comb_push_timeout
       // Initialise
       rd_req_queue_push = 1'b0;
       rd_req_queue_push_timeout = 1'b0;

      // Detect when segment write complete
      // Push write completion segment number into read request queue.
      if (ctrl2sbc_keep_data && s_rcv2rdbuff_last) begin
        rd_req_queue_push = 1'b1;
        rd_req_queue_push_timeout = 1'b0;
      // Push the timeout segment number into the read request queue and the
      // corrresponding header info into the rcv_cpl_hv_info_seg_lut LUT.
      // Avoid contention with good completions associated with different tags and
      // unexpected completiond for same tag.
      // Note: for dllp aborted completions the write FSM transitions from the IDLE state
      // holding off the pending timeout event.
      end else if (timeout_seg_num_valid && !s_rcv2rdbuff_hv && wr_current_state == ST_WR_IDLE) begin
         rd_req_queue_push_timeout = 1'b1;
         rd_req_queue_push = 1'b1;
      end
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_rd_req_queue_push_timeout_1d
      if (!reset_n) begin
        rd_req_queue_push_timeout_1d <= # TP '0;
      end else if (rd_req_queue_push_timeout_1d ^ rd_req_queue_push_timeout) begin
        rd_req_queue_push_timeout_1d <= # TP rd_req_queue_push_timeout;
      end else begin
        rd_req_queue_push_timeout_1d <= # TP rd_req_queue_push_timeout_1d;
      end
   end

   always @(posedge clk or negedge reset_n) begin : proc_seq_rd_req_queue_push_timeout_2d
      if (!reset_n) begin
        rd_req_queue_push_timeout_2d <= # TP '0;
      end else if (rd_req_queue_push_timeout_2d ^ rd_req_queue_push_timeout_1d) begin
        rd_req_queue_push_timeout_2d <= # TP rd_req_queue_push_timeout_1d;
      end else begin
        rd_req_queue_push_timeout_2d <= # TP rd_req_queue_push_timeout_2d;
      end
   end
   assign rd_req_queue_push_seg_num    = rd_req_queue_push ? (rd_req_queue_push_timeout ? timeout_push_seg_num : s_lut2ctrl_req_seg_num) : '0 ;
   assign rd_req_queue_push_seg_num_1d = rd_req_queue_push_timeout_1d ? timeout_push_seg_num_1d : lut2ctrl_req_seg_num_1d;

   // Output timeout segment number to rdbuff LUT block, extract timeout channel number.
   // Timeout channel number pushed into channel LUT, rcv_chan_num_lut, when rd_req_queue_push_timeout is valid.
   //assign ctrl2lut_timeout_seg_num       = rd_req_queue_push_timeout ? rd_req_queue_push_seg_num : {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
   assign ctrl2lut_timeout_seg_num       = ctrl2lut_timeout_seg_num_1d;
   assign ctrl2lut_timeout_seg_num_async = timeout_push_seg_num;
   assign ctrl2lut_timeout_seg_num_1d    = rd_req_queue_push_timeout_1d ? rd_req_queue_push_seg_num_1d : {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
//--------------------------------------------------------------------
//  Mask valid data depending on data word enable lines
//--------------------------------------------------------------------
// The number of valid words on the data bus depends on the word enable lines, s_rcv2rdbuff_dwen.
// The number of enables lines depends on the data bus width (32/64/128-bits).
// The completer can split completions on RCB boundaries (64/128bytes).
// The controller masks the valid data when writing to the segment buffer and sets invalid data words to all zeros.

   always_comb begin : proc_comb_wr_data_mask
     rcv_wr_data_mask = '0;
     rcv_wr_data_prot_mask = '0;
     foreach (s_rcv2rdbuff_dwen[i]) begin
       if (s_rcv2rdbuff_dwen[i]) begin
         rcv_wr_data_mask[i] = '1;
         rcv_wr_data_prot_mask[i] = '1;
       end else begin
         rcv_wr_data_mask[i] = '0;
         rcv_wr_data_prot_mask[i] = '0;
       end
     end
   end

   assign s_ctrl2sbc_push_data = !rd_req_queue_push_timeout ? rcv_wr_data_mask & s_rcv2rdbuff_data : '0;

   if (RAS_PARITY_MODE) begin // ODD
     assign s_ctrl2sbc_push_data_prot = !rd_req_queue_push_timeout ? ~rcv_wr_data_prot_mask | (rcv_wr_data_prot_mask & s_rcv2rdbuff_data_prot) : '1;
   end else begin
     assign s_ctrl2sbc_push_data_prot = !rd_req_queue_push_timeout ? rcv_wr_data_prot_mask & s_rcv2rdbuff_data_prot : '0;
   end


   always @(posedge clk or negedge reset_n) begin : proc_seq_r_ctrl2sbc_push_data
     if (!reset_n) begin
       r_ctrl2sbc_push_data      <= #TP '0;
       r_ctrl2sbc_push_data_prot <= #TP PM ? '1 : '0;
       r_ctrl2sbc_push_data_ecc  <= #TP PM ? '1 : '0;
     end else begin
       if (((s_rcv2rdbuff_dv || s_rcv2rdbuff_hv) && !s_trash_cpl) || rd_req_queue_push_timeout) begin
         r_ctrl2sbc_push_data      <= # TP s_ctrl2sbc_push_data;
         r_ctrl2sbc_push_data_prot <= # TP s_ctrl2sbc_push_data_prot;
         r_ctrl2sbc_push_data_ecc  <= # TP s_ctrl2sbc_push_data_ecc ;
       end else begin
         r_ctrl2sbc_push_data      <= # TP r_ctrl2sbc_push_data;
         r_ctrl2sbc_push_data_prot <= # TP r_ctrl2sbc_push_data_prot;
         r_ctrl2sbc_push_data_ecc  <= # TP r_ctrl2sbc_push_data_ecc ;
       end
     end
   end

   always @(posedge clk or negedge reset_n) begin : proc_dont_push_cpl
     if (!reset_n) begin
       r_dont_push      <= #TP '0;
     end else begin
       if (s_rcv2rdbuff_hv) begin
         if (s_rcv2rdbuff_tlp_abort || s_rcv2rdbuff_dllp_abort) begin
           r_dont_push  <= # TP '1;
         end else begin
           r_dont_push  <= # TP '0;
         end
       end else if (rd_req_queue_push_timeout) begin
         r_dont_push    <= # TP '0;
       end else begin
         r_dont_push    <= # TP r_dont_push;
       end
     end
   end

   assign int_ctrl2sbc_push_data   = r_ctrl2sbc_push_data;
   //Duplicated signal to allow error insertion without contaminating the ECC data
   assign s_ctrl2sbc_push_data_ras = r_ctrl2sbc_push_data;

   // RAM ECC insertion
   assign ctrl2sbc_push_data_prot = r_ctrl2sbc_push_data_ecc;
   
   // In case of CX_MULTISTREAM_ARCH data_ecc go to sbc tied to zero and overwritten after data back from sbc
   // This is because ctrl2sarb_wr_addr calculated inside sbc needed to calculate data_ecc
   assign s_ctrl2sbc_push_data_ecc = '0;

      // Generator
      ras_dp_pipe
       #(
        .PIPELINE_TYPE              (0                                                 ), // 0: delay_n
        .RESETVAL                   (0                                                 ),
        .N_STAGES                   (0                                                 ),
        .CAN_STALL                  (0                                                 ),
        .RESET_STALL                (0                                                 ),
        .BUS_PROTECT_GEN_EN         (1                                                 ), // 1: Bus Protection Generator is present
        .BUS_PROTECT_CHK_EN         (0                                                 ), // 0: Bus Protection Checker is not present (ECC/Parity)
        .PROT_TYPE                  (0                                                 ), // 0=Ecc, 1=Simple Parity
        .PROT_RANGE                 (RAS_RAM_PROT_RANGE                                ), // Number of bits to calculate parity/ECC on
        .PROT_WD                    (RAM_ECC_WD                                        ), // Selects the width of the din_prot/dout_prot signals
        .PARITY_MODE                (RAS_PARITY_MODE                                   ), // selects the type of parity: 0=Even, 1=Odd
        .PROT_CORRECT_EN            (/* NC */                                          ), // 0: no correction on single-errors, 1: correction on single-errors
        .TOTAL_WIDTH                (DMA_SEG_BUF_NW_ADDR_WIDTH + DMA_SEG_BUF_DATA_WIDTH), 
        .EXCLUDE_PROT_WIDTH         (0                                                 ),
        .RAS_DP_PROT_CHK_ID_BASE    (/* NC */                                          ), // Associates the Bus Protection Checker with a unique identifier
        .ADDR_ECC_PROT_EN           (1                                                 ),
        .ADDR_LOG_EN                (1                                                 ),
        .ADDR_INDEX                 (DMA_SEG_BUF_DATA_WIDTH                            ),
        .ADDR_WD                    (DMA_SEG_BUF_NW_ADDR_WIDTH                         )
      ) u_rdbuff_dt_addr_ecc_gen (
        .clk                        ( clk                                              )
        ,.rst_n                     ( reset_n                                          )
        ,.din                       ( {ctrl2sarb_wr_addr,
                                       ctrl2sarb_wr_data[0 +: DMA_SEG_BUF_DATA_WIDTH]} )
        ,.din_prot                  ( {RAM_ECC_WD{1'b0}}                               )
        ,.dout                      ( /* NC */                                         )
        ,.dout_prot                 ( ctrl2sarb_wr_data_prot                           ) // used to overwrite ctrl2sarb_wr_data protection part with correct value
        ,.en                        ( 1'b1                                             )
        ,.bypass                    ( 1'b0                                             )
        ,.stall                     ( 1'b0                                             )
        ,.stallout                  ( /* Not Connected */                              )
        ,.valid_in                  ( ctrl2sarb_wr_en                                  ) 
        ,.halt_out                  ( /* Not Connected */                              )
        ,.valid_out                 ( /* Not Connected */                              )
        ,.halt_in                   ( 1'b0                                             )
        ,.ras_dp_err_inband_kbd_in  ( 1'b0                                             )
        ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                              )
        ,.ras_dp_err_log            ( /* Not Connected */                              )
          ,.ras_dp_err_inj          ( '0                                               )
      );
      

  bus_protect_chk
   #(
  .PROT_TYPE       (1                        ),
  .PROT_RANGE      (RAS_PROT_RANGE           ),
  .PROT_WD         (DATA_PROT_WD             ),
  .DATA_WD         (DATA_WIDTH               ),
  .PARITY_MODE     (RAS_PARITY_MODE          )
  )
  u_radm_bypass_dt_par_chk(
    .correct_n     (1'b0                     ),
    .chkin         (r_ctrl2sbc_push_data_prot),
    .datain        (s_ctrl2sbc_push_data_ras ),
  //---------- Outputs --------------
    .err_detect    (                         ),
    .err_multpl    (rdbuff_ctrl_dt_raserr    ),
    .dataout       (                         ),
    .chkout        (                         ),
    .syndout       (                         )
  );

  assign rdbuff_ctrl_ras_par_dt_pulse = (ctrl2sbc_push_en_1d || int_ctrl2sbc_drop) && rdbuff_ctrl_dt_raserr;



   //--------------------------------------------------------------------
   // Retime write memory control/data signals
   //--------------------------------------------------------------------

   always @(posedge clk or negedge reset_n) begin : proc_seq_wrmem_intf_retime
       if (!reset_n) begin
         ctrl2sarb_wr_en_r       <= # TP 1'b0;
         ctrl2sarb_wr_addr_r     <= # TP {DMA_SEG_BUF_NW_ADDR_WIDTH{1'b0}};
         ctrl2sarb_wr_data_r     <= # TP {DMA_SEG_BUF_DATA_WECC_WIDTH{1'b0}};
         ctrl2sarb_wr_eot_r      <= # TP 1'b0;
       end else if (!rawreg2rdctrl_en) begin
         ctrl2sarb_wr_en_r       <= # TP 1'b0;
         ctrl2sarb_wr_addr_r     <= # TP {DMA_SEG_BUF_NW_ADDR_WIDTH{1'b0}};
         ctrl2sarb_wr_data_r     <= # TP {DMA_SEG_BUF_DATA_WECC_WIDTH{1'b0}};
         ctrl2sarb_wr_eot_r     <= # TP 1'b0;
       end else if (!sbc2ctrl_wen_n) begin
         ctrl2sarb_wr_en_r       <= # TP !sbc2ctrl_wen_n;
         ctrl2sarb_wr_addr_r     <= # TP sbc2ctrl_waddr;
         ctrl2sarb_wr_data_r     <= # TP {sbc2ctrl_wdata_prot,sbc2ctrl_wdata};
         ctrl2sarb_wr_eot_r      <= # TP (ctrl2sbc_keep_data_1d | rd_req_queue_push_timeout_1d);
       end else begin
         ctrl2sarb_wr_en_r       <= # TP !sbc2ctrl_wen_n;
       end
   end



   assign ctrl2sarb_wr_en   = ctrl2sarb_wr_en_r;
   assign ctrl2sarb_wr_addr = ctrl2sarb_wr_addr_r;
   assign ctrl2sarb_wr_data ={ ctrl2sarb_wr_data_prot, ctrl2sarb_wr_data_r[0 +: DMA_SEG_BUF_DATA_WIDTH]};
   assign ctrl2sarb_wr_eot  = ctrl2sarb_wr_eot_r;


   //--------------------------------------------------------------------
   // Generate valid vector of pending read requests
   //--------------------------------------------------------------------
   //
   // Capture the next segment to process
   //
   always @(posedge clk or negedge reset_n) begin : proc_seq_next_seg_num
      if (!reset_n) begin
        rd_req_queue_seg_num_r <= # TP {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
        rd_req_queue_seg_num_vld_r <= # TP 1'b0;
      end else if (!rawreg2rdctrl_en) begin
        rd_req_queue_seg_num_r <= # TP {NUM_DMA_RD_SEGMENTS_WIDTH{1'b0}};
        rd_req_queue_seg_num_vld_r <= # TP 1'b0;
      end else begin
        if (ctrl2rordr_ready && rordr2ctrl_valid) begin
           rd_req_queue_seg_num_r <= # TP rordr2ctrl_seg_num;
           rd_req_queue_seg_num_vld_r <= #TP 1'b1;
        end else if (ctrl2pdly_eot_s) begin
           rd_req_queue_seg_num_vld_r <= #TP 1'b0;
        end
      end
   end


//--------------------------------------------------------------------
// Store header information
//--------------------------------------------------------------------
// The completion header contains the same values for the Requester ID, Tag, Attribute,
// and Traffic Class as were supplied in the header of the corresponding Request.
// In the case of split completion the final Completion ends with the length specified
// by the Request.
// The Completion header info is stored per segment number when the last completion
// is pushed into the segment buffer.
// When a completion timeout segment is pushed in to the read request queue the
// completion status is forced to UR to enable the cpl2mwr block to detect an error.
// When an error occurs the controller outputs an errored TLP (status != SU) with no data.
// The associated channel number is recoverd from the channel LUT in the rdbuff_rordr block.
// Header info associated with the timeout eDMA Channel Read request is defined in the
// channel context memory.


  always @(posedge clk or negedge reset_n) begin : proc_seq_rcv_hdr_1d
    if (!reset_n) begin
      rcv2rdbuff_len_dw_1d   <= # TP '0;
      rcv2rdbuff_attr_1d     <= # TP '0;
      rcv2rdbuff_ep_1d       <= # TP '0;
      rcv2rdbuff_td_1d       <= # TP '0;
      rcv2rdbuff_tc_1d       <= # TP '0;
      rcv2rdbuff_status_1d   <= # TP '0;
      rcv2rdbuff_cplid_1d    <= # TP '0;
      rcv2rdbuff_func_num_1d <= # TP '0;
      lut2ctrl_channel_1d    <= # TP '0;
    end else begin
      if (ctrl2sbc_keep_data) begin
        rcv2rdbuff_len_dw_1d   <= # TP s_rcv2rdbuff_len_dw   ;
        rcv2rdbuff_attr_1d     <= # TP s_rcv2rdbuff_attr     ;
        rcv2rdbuff_ep_1d       <= # TP s_rcv2rdbuff_ep       ;
        rcv2rdbuff_td_1d       <= # TP s_rcv2rdbuff_td       ;
        rcv2rdbuff_tc_1d       <= # TP s_rcv2rdbuff_tc       ;
        rcv2rdbuff_status_1d   <= # TP s_rcv2rdbuff_status   ;
        rcv2rdbuff_cplid_1d    <= # TP s_rcv2rdbuff_cplid    ;
        rcv2rdbuff_func_num_1d <= # TP s_rcv2rdbuff_func_num ;
        lut2ctrl_channel_1d    <= # TP s_lut2ctrl_channel    ;
      end else begin
        rcv2rdbuff_len_dw_1d   <= # TP rcv2rdbuff_len_dw_1d   ;
        rcv2rdbuff_attr_1d     <= # TP rcv2rdbuff_attr_1d     ;
        rcv2rdbuff_ep_1d       <= # TP rcv2rdbuff_ep_1d       ;
        rcv2rdbuff_td_1d       <= # TP rcv2rdbuff_td_1d       ;
        rcv2rdbuff_tc_1d       <= # TP rcv2rdbuff_tc_1d       ;
        rcv2rdbuff_status_1d   <= # TP rcv2rdbuff_status_1d   ;
        rcv2rdbuff_cplid_1d    <= # TP rcv2rdbuff_cplid_1d    ;
        rcv2rdbuff_func_num_1d <= # TP rcv2rdbuff_func_num_1d ;
        lut2ctrl_channel_1d    <= # TP lut2ctrl_channel_1d    ;
      end
    end
  end
  always @(posedge clk or negedge reset_n) begin : proc_seq_rcv_hdr_info
    if (!reset_n) begin
      rcv_len_dw     <= # TP '0;
      rcv_attr       <= # TP '0;
      rcv_ep         <= # TP '0;
      rcv_td         <= # TP '0;
      rcv_tc         <= # TP '0;
      rcv_cpl_status <= # TP '0;
      rcv_cplid      <= # TP '0;
      rcv_func_num   <= # TP '0;
      rcv_chan_num   <= # TP '0;
      rcv_seg_num    <= # TP '0;
    end else begin
      if (rd_req_queue_push_timeout_1d) begin
        rcv_len_dw     <= # TP 10'b0;
        rcv_attr       <= # TP {FLT_Q_ATTR_WIDTH{1'b0}};
        rcv_ep         <= # TP 1'b0;
        rcv_td         <= # TP 1'b0;
        rcv_tc         <= # TP 3'b0;
        rcv_cpl_status <= # TP TO_CPL_STATUS;
        rcv_cplid      <= # TP 16'b0;
        rcv_func_num   <= # TP {NFUNC_WD{1'b0}};
        rcv_chan_num   <= # TP lut2ctrl_timeout_channel;
        rcv_seg_num    <= # TP rd_req_queue_push_seg_num_1d;
      end else begin
        rcv_len_dw     <= # TP rcv2rdbuff_len_dw_1d;
        rcv_attr       <= # TP rcv2rdbuff_attr_1d;
        rcv_ep         <= # TP rcv2rdbuff_ep_1d;
        rcv_td         <= # TP rcv2rdbuff_td_1d;
        rcv_tc         <= # TP rcv2rdbuff_tc_1d;
        rcv_cpl_status <= # TP rcv2rdbuff_status_1d;
        rcv_cplid      <= # TP rcv2rdbuff_cplid_1d;
        rcv_func_num   <= # TP rcv2rdbuff_func_num_1d;
        rcv_chan_num   <= # TP lut2ctrl_channel_1d;
        rcv_seg_num    <= # TP lut2ctrl_req_seg_num_1d;
      end
   end

  end
   // For split completions accumulate header length per CplD.
   // Note: accumulating header length is sufficient when the requested start address is data word aligned.
   // For byte aligned start addresses (phase 2) the maximum total number of dwords received is 1024 + 1
   // with holes in the first and last dwords. In this case we need to widen the length field by 1 and provide
   // the low address for the first TLP to enable the cpld2mwr block to calculate the first and last byte enables.
   assign len_dw_lut = rcv_cpl_hv_info_seg_lut[rcv_seg_num][HDR_INFO_SEG_LEN_HIGH:HDR_INFO_SEG_LEN_LOW];
   // Update dword length at end of valid completion. Note: if number of dwords accumulates to 1024 then len_dw rolls
   // over to 0 which is the correct encoding for the length field of the converted MWr TLP.
   assign {carry_a, len_dw} = ctrl2sbc_keep_data_2d ? ({1'b0, len_dw_lut} + {1'b0, rcv_len_dw}) : 11'd0;

   // Accumulate EP error over multiple split completions.
   assign ep_lut = rcv_cpl_hv_info_seg_lut[rcv_seg_num][HDR_INFO_SEG_EP];
   assign ep = ctrl2sbc_keep_data_2d ? (ep_lut | rcv_ep) : 1'b0;
  
   // Build segment header info vector 
   //                                 14:5   4     3         2:0
   assign rcv_cpl_hv_info_seg_vec = {len_dw, ep, rcv_td, rcv_cpl_status};

   always @(posedge clk or negedge reset_n) begin : proc_seq_cpl_hv_info_seg_lut
      integer i;

      if (!reset_n) begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
           rcv_cpl_hv_info_seg_lut[i] <= # TP {HDR_INFO_SEG_WD{1'b0}};
           rcv_chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
        end
      end else if (!rawreg2rdctrl_en) begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
           rcv_cpl_hv_info_seg_lut[i] <= # TP {HDR_INFO_SEG_WD{1'b0}};
           rcv_chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
        end
      end else begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
           // Store CplD TLP header info (split and non split completions) at the end of the transfer
           // if ecrc/tlp_abort/dllp_abort not asserted.
           // Header info valid for duration of the completion transfer.
           // Also store timeout status info and channel number when timeout transaction pushed into read request queue.
           // Note: Split and non-split completion hdr info and timeout hdr info push signals are mutually exclusive.
           if ((i==rcv_seg_num) && (ctrl2sbc_keep_data_2d || rd_req_queue_push_timeout_2d)) begin
             rcv_cpl_hv_info_seg_lut[i] <= # TP rcv_cpl_hv_info_seg_vec;
             rcv_chan_num_lut[i] <= # TP rcv_chan_num;
           // Re-initialise the stored header info (len_dw & ep) when composed segment read complete
           end else if ((rd_req_queue_seg_num_r==i) && rd_req_queue_seg_num_vld_r && ctrl2pdly_eot_s) begin
             rcv_cpl_hv_info_seg_lut[i] <= # TP {HDR_INFO_SEG_WD{1'b0}};
             rcv_chan_num_lut[i] <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
           end
        end
      end
   end

   // Build channel header info vector
   //                                    20:19      18:16     15:0
   assign rcv_cpl_hv_info_chan_vec = { rcv_attr, rcv_tc, rcv_cplid };


   always @(posedge clk or negedge reset_n) begin : proc_seq_cpl_hv_info_chan_lut
      integer i;

      if (!reset_n) begin
        for (i=0; i<NUM_DMA_RD_CHAN; i=i+1) begin
           rcv_cpl_hv_info_chan_lut[i] <= # TP {HDR_INFO_CHAN_WD{1'b0}};
           rcv_cpl_func_info_chan_lut[i] <= # TP {NFUNC_WD{1'b0}};
        end
      end else if (!rawreg2rdctrl_en) begin
        for (i=0; i<NUM_DMA_RD_CHAN; i=i+1) begin
           rcv_cpl_hv_info_chan_lut[i] <= # TP {HDR_INFO_CHAN_WD{1'b0}};
           rcv_cpl_func_info_chan_lut[i] <= # TP {NFUNC_WD{1'b0}};
        end
      end else begin
        for (i=0; i<NUM_DMA_RD_CHAN; i=i+1) begin
           if ((i==rcv_chan_num) && ctrl2sbc_keep_data_2d) begin
              rcv_cpl_hv_info_chan_lut[i] <= # TP rcv_cpl_hv_info_chan_vec;
              rcv_cpl_func_info_chan_lut[i] <= # TP rcv_func_num;
           end
        end
      end
   end

//--------------------------------------------------------------------
// Generate channel tag request halt vector when completion error detected.
//--------------------------------------------------------------------
   // Channel in progress info bus, bit 3=channel active, bits[2:0]=channel number

   //detects start doorbell


   always @ (posedge clk or negedge reset_n) begin : proc_seq_det_doorbell
      if (!reset_n) begin
         rawreg2rdctrl_doorbell_toggle_r <= # TP 1'b0;
      end else if (!rawreg2rdctrl_en) begin
         rawreg2rdctrl_doorbell_toggle_r <= # TP 1'b0;
      end else begin
         rawreg2rdctrl_doorbell_toggle_r <= # TP rawreg2rdctrl_doorbell_toggle;
      end
   end
   assign rawreg2rdctrl_doorbell_det = rawreg2rdctrl_doorbell_toggle ^rawreg2rdctrl_doorbell_toggle_r;


   always @(posedge clk or negedge reset_n) begin : proc_seq_chan_tag_req_halt
      integer i;

      if (!reset_n) begin
        ctrl2tmgr_chan_tag_req_halt_r <= # TP {NUM_DMA_RD_CHAN{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
        ctrl2tmgr_chan_tag_req_halt_r <= # TP {NUM_DMA_RD_CHAN{1'b0}};
      end else begin
        for (i=0; i<NUM_DMA_RD_CHAN; i=i+1) begin
           // NACK read channel tag requests if errored completion or completion
           // timeout received. If aborted completion received then ignore CplD.
           if (((s_lut2ctrl_channel==i) && !rcv_status_su && ctrl2sbc_keep_data)
               || ((lut2ctrl_timeout_channel_async==i) && timeout_seg_num_valid)) begin
             ctrl2tmgr_chan_tag_req_halt_r[i] <= # TP 1'b1;
           // ACK future read channel tag requests after channel requests halted and
           // channel id doorbelled again.
           end else if (
                        rawreg2rdctrl_doorbell_det &&
                        (i == rawreg2rdctrl_doorbell) &&
                        !rawreg2rdctrl_doorbell_stop
                        ) begin
             ctrl2tmgr_chan_tag_req_halt_r[i] <= # TP 1'b0;
           end
        end
      end
   end

   assign ctrl2tmgr_chan_tag_req_halt = ctrl2tmgr_chan_tag_req_halt_r;

//--------------------------------------------------------------------
// Read FSM
//--------------------------------------------------------------------
// State machine to control read transactions from the segment buffer
//--------------------------------------------------------------------
   // Encoding for state machine

   //--------------------------------------------------------------------
   // Read FSM sequential process
   //--------------------------------------------------------------------

   always @(posedge clk or negedge reset_n) begin : proc_seq_rd_fsm
      if (!reset_n) begin
        rd_current_state <= # TP ST_RD_IDLE;
      end else if (!rawreg2rdctrl_en) begin
        rd_current_state <= # TP ST_RD_IDLE;
      end else begin
        rd_current_state <= # TP rd_next_state;
      end
   end

   //--------------------------------------------------------------------
   // Read FSM combinational process
   //--------------------------------------------------------------------
   assign rd_ack = sarb2rdbuff_rd_ack;


   always @(*) begin : proc_comb_read_fsm

      // Default assignments: if the following case statement does not
      // set a signal to a new value, then hold the old value.
      rd_next_state = rd_current_state;

      case (rd_current_state)
        ST_RD_IDLE      : begin
          if (!pdly2ctrl_halt) begin
            if (rd_req) begin
              rd_next_state = ST_RD_REQ;
            end
          end else begin
            rd_next_state = ST_RD_IDLE;
          end
        end
        ST_RD_REQ       : begin
          if (!pdly2ctrl_halt) begin
            if (rd_req) begin
               rd_next_state = ST_RD_MORE_DATA;
            end else begin
               rd_next_state = ST_RD_IDLE;
            end
          end else begin
            rd_next_state = ST_RD_IDLE;
          end
        end
        ST_RD_MORE_DATA : begin
          if (!pdly2ctrl_halt) begin
            if (!rd_req) begin
               rd_next_state = ST_RD_IDLE;
            end
          end else begin
            rd_next_state = ST_RD_IDLE;
          end
        end
        default         : begin
          // Illegal states (X, Z), should never be reached.
          rd_next_state = ST_RD_IDLE;
        end
      endcase
   end


   // Generate a pop_ready signal to new rordr block so that a new segment
   // id is generated

   // A new segment is ready to be processed as the current transfer is
   // being completed.
   always @(posedge clk or negedge reset_n) begin : proc_seq_new_seg_req_ready
      if (!reset_n) begin
        new_seg_req_ready <= # TP 1'b1;
      end else if (!rawreg2rdctrl_en) begin
        new_seg_req_ready <= # TP 1'b1;
      end else begin
        if (rordr2ctrl_valid) begin
           new_seg_req_ready <= # TP 1'b0;
        end else if (ctrl2pdly_eot_s) begin
           new_seg_req_ready <= # TP 1'b1;
        end
      end
   end

   assign ctrl2rordr_ready = (ctrl2pdly_eot_s) ? 1'b1 : new_seg_req_ready;


   //
   // seg_pkt_avail is updated whenever a CplD is stored in SBC. For split CplD
   // the correspondent bit of seg_pkt_avail will be true upon the first eot.
   // Thus, we need to mask seg_pkt_avail against the last CplD so that the
   // ctrl will not start popping data from a segment that isn't tottaly written
   // in SBC.
   //
   

   assign s_mark_avail_p = ( (NUM_DMA_RD_SEGMENTS)'(s_rcv2rdbuff_eot && !s_trash_cpl && !rcv_wr_error && s_rcv2rdbuff_last) << s_lut2ctrl_req_seg_num) |
                           ( (NUM_DMA_RD_SEGMENTS)'(rd_req_queue_push_timeout)                                              << timeout_push_seg_num  );

   logic [NUM_DMA_RD_SEGMENTS-1:0] r_mark_avail_p;

   always_ff @(posedge clk, negedge reset_n)
     if(!reset_n) r_mark_avail_p <= #`TP '0;
     else         r_mark_avail_p <= #`TP s_mark_avail_p;

   assign w_mark_avail_p = r_mark_avail_p;

   always @(posedge clk or negedge reset_n) begin : proc_seq_seg_pkt_avail_mask
      integer i;
      if (!reset_n) begin
        seg_pkt_avail_mask <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
        seg_pkt_avail_mask <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else begin
        for (i=0;i<NUM_DMA_RD_SEGMENTS;i=i+1) begin
          if (w_mark_avail_p[i]) begin
            seg_pkt_avail_mask[i] <= # TP 1'b1;
          end else if (
                !pdly2ctrl_halt && 
                (ctrl2sbc_pop_seg_num==i) && rd_req_queue_seg_num_vld_r && sbc2ctrl_empty_p_1[i] &&
                !(ctrl2sbc_push && (ctrl2sbc_push_seg_num==i))
          ) begin
            // Clear the segment push counter and valid flag when composed segment is read from segment buffer.
            seg_pkt_avail_mask[i] <= # TP 1'b0;
          end
        end
      end
   end

   assign ctrl2rordr_seg_pkt_avail_mask = seg_pkt_avail_mask & sbc2ctrl_seg_pkt_avail;

   always_ff @(posedge clk or negedge reset_n) begin : proc_seq_poppedLast
     if (!reset_n) begin
       r_poppedLast <= # TP 1'b0;
     end else begin
       if (sbc2ctrl_empty_p_1[ctrl2sbc_pop_seg_num] && ctrl2sbc_pop) begin
         r_poppedLast <= # TP 1'b1;
       end else begin
         r_poppedLast <= # TP 1'b0;
       end
     end
   end



  assign rd_req = rd_req_queue_seg_num_vld_r && (!r_poppedLast || (rordr2ctrl_valid && ctrl2rordr_ready));


   //--------------------------------------------------------------------
   // Read FSM control output generation.
   //--------------------------------------------------------------------
   // Segment buffer pop signal

   always @(*) begin : proc_comb_ctrl2sbc_pop

     s_ctrl2sbc_pop = 1'b0;

     if (!pdly2ctrl_halt) begin
       case (rd_current_state)
         ST_RD_IDLE                             : begin
           if (rd_req) begin
             s_ctrl2sbc_pop = 1'b1;
           end
         end
         ST_RD_REQ, ST_RD_MORE_DATA : begin
           if (rd_req && rd_ack) begin
             s_ctrl2sbc_pop = 1'b1;
           end
         end
         default                                : begin
             s_ctrl2sbc_pop = 1'b0;
         end
       endcase
     end
   end

   // Output the segment number to the segment buffer controller.
   assign ctrl2sbc_pop_seg_num = (ctrl2rordr_ready && rordr2ctrl_valid) ? rordr2ctrl_seg_num : rd_req_queue_seg_num_r;
   assign ctrl2sbc_pop = s_ctrl2sbc_pop;


   //--------------------------------------------------------------------
   // Pipe delay data valid signal
   //--------------------------------------------------------------------

   always @(*) begin : proc_comb_ctrl2pdly_dv

     s_ctrl2pdly_dv = 1'b0;

     case (rd_current_state)
       ST_RD_REQ, ST_RD_MORE_DATA : begin
         if (rd_ack) begin
           s_ctrl2pdly_dv = 1'b1;
         end
       end
       default                                : begin
           s_ctrl2pdly_dv = 1'b0;
       end
     endcase
   end

  assign ctrl2pdly_dv_s = s_ctrl2pdly_dv;

   //--------------------------------------------------------------------
   // Pipe delay end of transfer signal
   //--------------------------------------------------------------------

   always_ff @(posedge clk, negedge reset_n) begin : cpl_inflight
     if (!reset_n) begin
       r_cpl_inflight <= #`TP '0;
     end else begin
      if (ctrl2pdly_hv_s && !ctrl2pdly_eot_s) begin
         r_cpl_inflight <= #`TP '1;
      end else if (ctrl2pdly_eot_s) begin
         r_cpl_inflight <= #`TP '0;
       end else begin
         r_cpl_inflight <= #`TP r_cpl_inflight;
       end
     end
   end

  assign ctrl2pdly_hv_s = ctrl2pdly_dv_s && !r_cpl_inflight;
  assign ctrl2pdly_eot_s = r_poppedLast && (ctrl2pdly_dv_s || ctrl2pdly_hv_s);

   //--------------------------------------------------------------------
   // Generate the read request queue pop signal to remove the current segment
   // number from the queue and point to the next segment number.
   //--------------------------------------------------------------------
  assign rd_req_queue_pop = ctrl2pdly_eot_s;

   //--------------------------------------------------------------------
   // Generate segment entry pop count.
   // Used to map the data word enable (ctrl2pdly_dwen) to the segment data
   // when data word holes are present in the core 64/128-bit data beat.
   //--------------------------------------------------------------------

      always @(posedge clk or negedge reset_n) begin : proc_seq_seg_pop_cnt
         if (!reset_n) begin
           seg_pop_cnt <= # TP {DMA_SEG_ADDR_WIDTH{1'b0}};
         end else if (!rawreg2rdctrl_en) begin
           seg_pop_cnt <= # TP {DMA_SEG_ADDR_WIDTH{1'b0}};
        end else if (ctrl2sbc_pop && sbc2ctrl_empty_p_1[ctrl2sbc_pop_seg_num]) begin
           // Re-initialise pop counter on last pop from the segment buffer.
           seg_pop_cnt <= # TP {DMA_SEG_ADDR_WIDTH{1'b0}};
         end else if (ctrl2sbc_pop) begin
           // Increment pop counter
           seg_pop_cnt <= # TP seg_pop_cnt +1;
         end
      end

//--------------------------------------------------------------------
// Extract the read segment header information, the channel number
// and the function number from the request info look up tables.
//--------------------------------------------------------------------
   // Channel number
   assign ctrl2pdly_channel_s = rcv_chan_num_lut[rd_req_queue_seg_num_r];

   assign pdly_hv_info_chan_vec = rcv_cpl_hv_info_chan_lut[ctrl2pdly_channel_s];

   // CplD TLP info
   assign pdly_hv_info_seg_vec = rcv_cpl_hv_info_seg_lut[rd_req_queue_seg_num_r];

   // {ide_prfx, len_dw, rcv_attr, ep, rcv_td, rcv_tc, rcv_cpl_status, rcv_cplid};
   //   67:36    35:26    25:24    23   22     21:19       18:16         15:0
    // {len_dw, rcv_attr, ep, rcv_td, rcv_tc, rcv_cpl_status, rcv_cplid};
    //  35:26    25:24    23   22     21:19       18:16         15:0
    assign pdly_hv_info_vec = { pdly_hv_info_seg_vec[HDR_INFO_SEG_LEN_HIGH:HDR_INFO_SEG_LEN_LOW],
                                pdly_hv_info_chan_vec[HDR_INFO_CHAN_ATTR_HIGH:HDR_INFO_CHAN_ATTR_LOW],
                                pdly_hv_info_seg_vec[HDR_INFO_SEG_EP],
                                pdly_hv_info_seg_vec[HDR_INFO_SEG_TD],
                                pdly_hv_info_chan_vec[HDR_INFO_CHAN_TC_HIGH:HDR_INFO_CHAN_TC_LOW],
                                pdly_hv_info_seg_vec[HDR_INFO_SEG_CPL_STATUS_HIGH:HDR_INFO_SEG_CPL_STATUS_LOW],
                                pdly_hv_info_chan_vec[HDR_INFO_CHAN_CPLID_HIGH:HDR_INFO_CHAN_CPLID_LOW] };

   // CplD TLP header
   // Force error completion status when an errored read segment detected.
   // Any successful completion received after the first errored completion is deemed to be an errored
   // completion and is not converted to a memory write.
   assign ctrl2pdly_hdr_s = pdly_hv_info_vec;

   // Function number
   assign ctrl2pdly_func_num_s = rcv_cpl_func_info_chan_lut[ctrl2pdly_channel_s];

   // CplD TLP header error info
  

//--------------------------------------------------------------------
// Output the read data to the pipe delay block
//--------------------------------------------------------------------
   // Route segment buffer data to SBC controller
   assign ctrl2sbc_rdata = sarb2rdbuff_rd_data;
   // Route SBC pop data to pipe delay block
   assign ctrl2pdly_data = sbc2ctrl_pop_data;

//--------------------------------------------------------------------
// Output the read data word enable to the pipe delay block
//--------------------------------------------------------------------

      always @(posedge clk or negedge reset_n) begin : proc_seq_dwen_lut
        integer i;

        if (!reset_n) begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             dwen_lut[i] <= # TP {DWEN_LUT_DATA_WIDTH{1'b0}};
          end
        end else if (!rawreg2rdctrl_en) begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             dwen_lut[i] <= # TP {DWEN_LUT_DATA_WIDTH{1'b0}};
          end
        end else begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
               // Detect the segment entries with possible data word holes, i.e. the last entry
               // of the first split completion and the last entry of the last split completion.
               // Store the data word enable bits and the associated entry pointer for the first split
               // completion and the data word enable bits only for the last split completion.
             if ((i==lut2ctrl_req_seg_num_1d) && rcv2rdbuff_eot_1d && !rcv_wr_error_1d && rcv2rdbuff_last_1d) begin
               // Set the last CplD dwen bits
               dwen_lut[i][DWEN_LUT_LAST_DWEN_HIGH:DWEN_LUT_LAST_DWEN_LOW] <= # TP rcv2rdbuff_dwen_1d;
             end else if ((i==lut2ctrl_req_seg_num_1d) && (rcv2rdbuff_dwen_1d != {NW{1'b1}}) &&
                          rcv2rdbuff_eot_1d && !rcv_wr_error_1d && !rcv2rdbuff_last_1d) begin
               // Set the first CplD dwen bits
               dwen_lut[i][DWEN_LUT_FIRST_DWEN_HIGH:DWEN_LUT_FIRST_DWEN_PTR_LOW] <= # TP {rcv2rdbuff_dwen_1d, seg_push_cnt_ary[i]};
               // Set the segment push counter valid flag
               dwen_lut[i][DWEN_LUT_FIRST_DWEN_PTR_VALID] <= # TP 1'b1;
             end else if ((rd_req_queue_seg_num_r==i) && rd_req_queue_seg_num_vld_r && sbc2ctrl_empty_p_1[i]) begin
               // Clear the segment push counter and valid flag when composed segment is read from segment buffer.
               dwen_lut[i][DWEN_LUT_FIRST_DWEN_HIGH:DWEN_LUT_FIRST_DWEN_PTR_LOW] <= # TP 'd0;
               dwen_lut[i][DWEN_LUT_FIRST_DWEN_PTR_VALID] <= # TP 1'b0;
             end
          end
        end
      end

      // Extract the per segment read data word enable bits.
      // Data word enable bits popped from LUT simultaneous with popping data from the segment buffer.

      // detect falling edge of ctrl2sbc_pop to set ctrl2pdly_dwen_int_r to 0
      always @(posedge clk or negedge reset_n) begin : proc_ctrl2sbc_pop_delayed
        if (!reset_n) begin
          ctrl2sbc_pop_r <= # TP 1'b0;
        end else begin
          ctrl2sbc_pop_r <= # TP ctrl2sbc_pop;
        end
      end

      assign ctrl2sbc_pop_fall = !ctrl2sbc_pop && ctrl2sbc_pop_r;

      always @(posedge clk or negedge reset_n) begin : proc_seq_ctrl2pdly_dwen_int_r
        integer i;

        if (!reset_n) begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             ctrl2pdly_dwen_int_r[i] <= # TP {NW{1'b0}};
          end

        end else if (!rawreg2rdctrl_en) begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
             ctrl2pdly_dwen_int_r[i] <= # TP {NW{1'b0}};
          end
        end else if (ctrl2sbc_pop) begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
               if ((ctrl2sbc_pop_seg_num==i) && rd_req_queue_seg_num_vld_r
                   // Validate seg_pop_cnt otherwise we will always pop dwen when seg_pop_cnt=0.
                   && (dwen_lut[i][DWEN_LUT_FIRST_DWEN_PTR_VALID]==1'b1)
                   // Extract first split CplD dwen bits
                   && (seg_pop_cnt==dwen_lut[i][DWEN_LUT_FIRST_DWEN_PTR_HIGH:DWEN_LUT_FIRST_DWEN_PTR_LOW])) begin
                 ctrl2pdly_dwen_int_r[i] <= # TP dwen_lut[i][DWEN_LUT_FIRST_DWEN_HIGH:DWEN_LUT_FIRST_DWEN_LOW];
               end else if ((ctrl2sbc_pop_seg_num==i) && rd_req_queue_seg_num_vld_r && sbc2ctrl_empty_p_1[i]) begin
                 // Pop the last data word enable bits on the last pop from the segment buffer.
                 ctrl2pdly_dwen_int_r[i] <= # TP dwen_lut[i][DWEN_LUT_LAST_DWEN_HIGH:DWEN_LUT_LAST_DWEN_LOW];
               end else begin
                 ctrl2pdly_dwen_int_r[i] <= # TP {NW{1'b1}};
               end
          end
        end else if (ctrl2sbc_pop_fall) begin
          for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
            ctrl2pdly_dwen_int_r[i] <= # TP {NW{1'b0}};
          end
        end
      end

      assign ctrl2pdly_dwen_s = ctrl2pdly_dwen_int_r[rd_req_queue_seg_num_r];

//--------------------------------------------------------------------
// Push the segment number back into the pool of available segments when
// the segment read transfer is complete.
//--------------------------------------------------------------------
   assign ctrl2tmgr_rd_seg_num_recycle = ctrl2pdly_eot_s;
   assign ctrl2tmgr_rd_seg_num = rd_req_queue_seg_num_r;

   assign ctrl2rordr_rd_seg_num_recycle = ctrl2pdly_eot_s;
   assign ctrl2rordr_rd_seg_num = rd_req_queue_seg_num_r;

   // Recycled segment number output to LUT, diagnostic purposes only
   assign ctrl2lut_rd_seg_num_recycle = ctrl2pdly_eot_s;
   assign ctrl2lut_rd_seg_num = rd_req_queue_seg_num_r;

//--------------------------------------------------------------------
// Generate the read port control signals to the SRAM arbiter.
//--------------------------------------------------------------------
   assign ctrl2sarb_rd_addr = sbc2ctrl_raddr;
   // Note: segment buffer controller drives sb_ren_n_o to 0. Use pop signal
   // to validate RAM read address.
   assign ctrl2sarb_rd_en = ctrl2sbc_pop;

//--------------------------------------------------------------------
// Align read address with data to keep track of data location in case
// of RAS event on read buffer
//--------------------------------------------------------------------
   always @(posedge clk or negedge reset_n) begin : proc_seq_ras_rd_addr
      if (!reset_n) begin
         ras_rd_addr_r <= {DMA_SEG_BUF_NW_ADDR_WIDTH{1'b0}};
      end else if (ctrl2sarb_rd_en) begin
         ras_rd_addr_r <= ctrl2sarb_rd_addr;
      end
   end

   assign ras_rd_addr = ras_rd_addr_r;

//--------------------------------------------------------------------
// Check if a segment error has been detected during a multi-completion write transfer.
//--------------------------------------------------------------------
// The read segment error detect enables the Read FSM to drain the segment buffer and mask the
// write transfer to the ctrl2cmwr interface when an unsuccessfull completion is
// received during a multi-completion write transfer.
// Note: when a CplD in the sequence of split CplD's is generated with a Completion Status other than Successfull
// then this completion will be the final completion associated with the outstanding request.
// Receiving subsequent completions, post the errored CplD, with the same tag is not allowed.
// The following conditions result in a segment error:
// - completion status not successfull;
// - completion poisoned (EP set by the core if the payload is poisoned and the poisoned mask bit,
//   CX_FLT_MASK_UR_POIS, is not set. If set the poisoned TLP si treated as an UR by the core which
//   results in a completion timeout);
// - completion timeout.
// When a read segment error is detected previously stored split data is flushed from the segment buffer.

   // Detect sucessfull completions
   assign rcv_status_su = ((s_rcv2rdbuff_status == `SU_CPL_STATUS) && !s_rcv2rdbuff_ep);

   // Detect the read segment error

   always @(posedge clk or negedge reset_n) begin : proc_seq_rd_seg_error
      integer i;

      if (!reset_n) begin
        rd_req_queue_seg_error_vec <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else if (!rawreg2rdctrl_en) begin
        rd_req_queue_seg_error_vec <= # TP {NUM_DMA_RD_SEGMENTS{1'b0}};
      end else begin
        for (i=0; i<NUM_DMA_RD_SEGMENTS; i=i+1) begin
           // Capture the write segment error.
           // The push write segment and push timeout requests are mutually exclusive.
           if ((ctrl2sbc_keep_data && (s_lut2ctrl_req_seg_num==i) && ~rcv_status_su) ||
               (s_rcv2rdbuff_cpl_timeout && !s_trash_tout && (i==s_lut2ctrl_timeout_seg_num))) begin
             rd_req_queue_seg_error_vec[i] <= # TP 1'b1;
           // Clear the segment error signal on last beat of the segment read.
           end else if ((rd_req_queue_seg_num_r==i) && rd_req_queue_seg_num_vld_r && ctrl2pdly_eot_s) begin
             rd_req_queue_seg_error_vec[i] <= # TP 1'b0;
           end
        end
      end
   end

   assign ctrl2pdly_error = '0;
   assign ctrl2pdly_last = '0;


   assign ctrl2lut_error_tag = rcv2rdbuff_tag;



//--------------------------------------------------------------------
// Functions
//--------------------------------------------------------------------
   //Do a binary search over the LUT and find the index of the 1st free tag
   function automatic [NUM_DMA_RD_SEGMENTS_WIDTH:0] binsearch;
      input [NUM_DMA_RD_SEGMENTS-1:0] ary;

      //This function is able to handle up to 512 buffers, internally it's fixed to 512.
      //Un-used logic is tied to 0's, since it detects the first one in the RD SEGMENT ARY

      reg [511:0]         int_ary;

      //Search net matrix
      reg [511:0]         matrix_0_search;
      reg [255:0]         matrix_1_search;
      reg [127:0]         matrix_2_search;
      reg [63:0]          matrix_3_search;
      reg [31:0]          matrix_4_search;
      reg [15:0]          matrix_5_search;
      reg [7:0]           matrix_6_search;
      reg [3:0]           matrix_7_search;
      reg [1:0]           matrix_8_search;

      //Mux selection for the search matrix
      reg [8:0]           mux_sel;
      
      begin : func_binsearch
         int_ary = '0;
         int_ary[NUM_DMA_RD_SEGMENTS-1: 0] = ary[NUM_DMA_RD_SEGMENTS-1: 0];

         matrix_0_search[511:0] = int_ary;

         mux_sel[8] = !(|matrix_0_search[255:0]);
         matrix_1_search[255:0] = mux_sel[8] ? matrix_0_search[511:256] : matrix_0_search[255:0];
         
         mux_sel[7] = !(|matrix_1_search[127:0]);
         matrix_2_search[127:0] = mux_sel[7] ? matrix_1_search[255:128] : matrix_1_search[127:0];

         mux_sel[6] = !(|matrix_2_search[63:0]);
         matrix_3_search[63:0]  = mux_sel[6] ? matrix_2_search[127:64]  : matrix_2_search[63:0];

         mux_sel[5] = !(|matrix_3_search[31:0]);
         matrix_4_search[31:0]  = mux_sel[5] ? matrix_3_search[63:32]   : matrix_3_search[31:0];

         mux_sel[4] = !(|matrix_4_search[15:0]);
         matrix_5_search[15:0]  = mux_sel[4] ? matrix_4_search[31:16]   : matrix_4_search[15:0];

         mux_sel[3] = !(|matrix_5_search[7:0]);
         matrix_6_search[7:0]   = mux_sel[3] ? matrix_5_search[15:8]    : matrix_5_search[7:0];

         mux_sel[2] = !(|matrix_6_search[3:0]);
         matrix_7_search[3:0]   = mux_sel[2] ? matrix_6_search[7:4]     : matrix_6_search[3:0];

         mux_sel[1] = !(|matrix_7_search[1:0]);
         matrix_8_search[1:0]   = mux_sel[1] ? matrix_7_search[3:2]     : matrix_7_search[1:0];

         mux_sel[0] = !(matrix_8_search[0]);

         binsearch[NUM_DMA_RD_SEGMENTS_WIDTH-1:0] = mux_sel[NUM_DMA_RD_SEGMENTS_WIDTH-1:0];

         binsearch[NUM_DMA_RD_SEGMENTS_WIDTH] = |ary;

      end

   endfunction



`ifndef SYNTHESIS

//--------------------------------------------------------------------
// Enumerate FSM states
//--------------------------------------------------------------------
   wire [16*8:1] WR_CURRENT_STATE;
   assign WR_CURRENT_STATE = (wr_current_state == ST_WR_IDLE) ? "ST_WR_IDLE          ":
                             (wr_current_state == ST_WR_REQ) ? "ST_WR_REQ            ":
                             (wr_current_state == ST_WR_MORE_DATA) ? "ST_WR_MORE_DATA":
                             (wr_current_state == ST_WR_WAIT) ? "ST_WR_WAIT          ":
                             "UNDEF";

   wire [16*8:1] RD_CURRENT_STATE;
   assign RD_CURRENT_STATE = (rd_current_state == ST_RD_IDLE) ? "ST_RD_IDLE          ":
                             (rd_current_state == ST_RD_REQ) ? "ST_RD_REQ            ":
                             (rd_current_state == ST_RD_MORE_DATA) ? "ST_RD_MORE_DATA":
                             "UNDEF";

      `define DMA_SEG_BUF_RAM_DT_PTR 0
      `define DMA_SEG_BUF_RAM_DT_PTRW `CC_DMA_SEG_BUF_DATA_WIDTH

`endif // SYNTHESIS

endmodule
