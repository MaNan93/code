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
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rdbuff_core.sv#14 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_header_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_bypass_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_rdbuff_core
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       CC_CORE_DATA_BUS_WD = `CC_CORE_DATA_BUS_WD
  ,parameter        CC_DMA_RD_TAG_HIGH = `CC_DMA_RD_TAG_HIGH
  ,parameter         CC_DMA_RD_TAG_LOW = `CC_DMA_RD_TAG_LOW
  ,parameter CC_DMA_SEG_BUF_DATA_WIDTH = `CC_DMA_SEG_BUF_DATA_WIDTH
  ,parameter          CC_DMA_SEG_DEPTH = `CC_DMA_SEG_DEPTH
  ,parameter        CC_NUM_DMA_RD_CHAN = `CC_NUM_DMA_RD_CHAN
  ,parameter               CX_NFUNC_WD = `CX_NFUNC_WD
  ,parameter              CX_NVFUNC_WD = `CX_NVFUNC_WD
  ,parameter                     CX_NW = `CX_NW
  ,parameter               CX_TAG_SIZE = `CX_TAG_SIZE
  ,parameter          FLT_Q_ATTR_WIDTH = `FLT_Q_ATTR_WIDTH
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tlp_bypass_if.slave_mp b_bypass
  ,DWC_pcie_edmapf_cdmregs_if.slave_mp    b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp      b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp       b_cpl
  ,DWC_pcie_edmapf_rvData_if.slave_mp     b_push
  ,DWC_pcie_edmapf_ram2p_if.master_mp     b_ram0
  ,DWC_pcie_edmapf_tlp_header_if.slave_mp b_timeout
  ,DWC_pcie_edmapf_rasdp_if.master_mp     b_ras
  );


// SNPS_SysML_CODE_START

  localparam CC_NUM_DMA_RD_TAG              = CC_DMA_RD_TAG_HIGH - CC_DMA_RD_TAG_LOW + 1;
  localparam CC_DMA_SEG_BUF_NW_ADDR         = CC_NUM_DMA_RD_TAG * CC_DMA_SEG_DEPTH ;
  localparam CC_DMA_RD_TAG_HIGH_WIDTH       = $clog2(CC_DMA_RD_TAG_HIGH      ) ;
  localparam CC_DMA_SEG_ADDR_WIDTH          = $clog2(CC_DMA_SEG_DEPTH        ) ;
  localparam CC_DMA_SEG_BUF_NW_ADDR_WIDTH   = $clog2(CC_DMA_SEG_BUF_NW_ADDR  ) ;
  localparam CC_NUM_DMA_RD_CHAN_WIDTH       = (CC_NUM_DMA_RD_CHAN == 1) ? 1 : $clog2(CC_NUM_DMA_RD_CHAN) ;
  localparam CC_NUM_DMA_RD_TAG_WIDTH        = $clog2(CC_NUM_DMA_RD_TAG       ) ;
  localparam CX_NW_LOG2                     = $clog2(CX_NW                   ) ;
  localparam NUM_DMA_RD_SEGMENTS            = CC_NUM_DMA_RD_TAG         ;
  localparam NUM_DMA_RD_SEGMENTS_WIDTH      = CC_NUM_DMA_RD_TAG_WIDTH   ;
  localparam CC_DMA_SEG_BUF_DATA_WECC_WIDTH = `CC_DMA_SEG_BUF_DATA_WECC_WIDTH;
  localparam CC_DMA_SEG_BUF_DATA_WPAR_WIDTH = `CC_DMA_SEG_BUF_DATA_WPAR_WIDTH;
  localparam L_NUM_SEG_5_BIT                = K_MAXPCIETAG_5BIT-K_MINDMATAG_5BIT+1;
  localparam NUM_DMA_RD_SEGMENTS_WIDTH_5BIT = $clog2(L_NUM_SEG_5_BIT);
  localparam SEG_5BIT_DIF                   = NUM_DMA_RD_SEGMENTS_WIDTH - NUM_DMA_RD_SEGMENTS_WIDTH_5BIT;
  localparam L_NUM_SEG_8_BIT                = K_MAXPCIETAG_8BIT-K_MINDMATAG_8BIT+1;
  localparam NUM_DMA_RD_SEGMENTS_WIDTH_8BIT = $clog2(L_NUM_SEG_8_BIT);
  localparam SEG_8BIT_DIF                   = NUM_DMA_RD_SEGMENTS_WIDTH - NUM_DMA_RD_SEGMENTS_WIDTH_8BIT;
  localparam CC_DMA_SEG_BUF_NW_ADDRP_WIDTH  = `CC_DMA_SEG_BUF_NW_ADDRP_WIDTH;
  localparam DWORD_PROT_BITS                = 4;
  localparam CX_RAS_RAM_PROT_RANGE          = `CX_RAS_RAM_PROT_RANGE;
  localparam CX_RAS_PROT_RANGE              = `CX_RAS_PROT_RANGE;
  localparam CX_RAS_PARITY_MODE             = `CX_RAS_PARITY_MODE;
  localparam TRGT_DATA_PROT_WD              = `TRGT_DATA_PROT_WD;
  localparam RAM_ECC_WD                     = CC_DMA_SEG_BUF_DATA_WECC_WIDTH - CC_DMA_SEG_BUF_DATA_WIDTH;
  
  typedef struct packed {
    logic [9:0]                  dw_len    ;
    logic [FLT_Q_ATTR_WIDTH-1:0] attr      ;
    logic                        poisoned  ;
    logic                        td        ;
    logic [2:0]                  tc        ;
    logic [2:0]                  cplStatus ;
    logic [15:0]                 cplId     ;
  } hdrWrap_s;


  ras_dp_err_log_t                                               rdbuff_ras_dp_err_log_core;
  ras_dp_err_inj_t                                               rdbuff_ras_dp_err_inj_core;

  logic                                                          tag_5bit_en                          ;
  logic                                                          tag_8bit_en                          ;
  logic                                                          tag_10bit_en                         ;  
  logic                                                          cmwr2dalgn_halt                      ;
  logic                                                          rcv2rdbuff_hv                        ;
  logic                                                          rcv2rdbuff_dv                        ;
  logic                                                          rcv2rdbuff_eot                       ;
  logic                                                          rcv2rdbuff_last                      ;
  logic                                                          rcv2rdbuff_tlp_abort                 ;
  logic                                                          rcv2rdbuff_dllp_abort                ;
  logic                                                          rcv2rdbuff_ecrc_err                  ;
  logic [CX_NFUNC_WD-1:0]                                        rcv2rdbuff_func_num                  ;
  logic [CX_TAG_SIZE-1:0]                                        rcv2rdbuff_tag                       ;
  logic [9:0]                                                    rcv2rdbuff_len_dw                    ;
  logic [FLT_Q_ATTR_WIDTH-1:0]                                   rcv2rdbuff_attr                      ;
  logic                                                          rcv2rdbuff_ep                        ;
  logic                                                          rcv2rdbuff_td                        ;
  logic [2:0]                                                    rcv2rdbuff_tc                        ;
  logic [2:0]                                                    rcv2rdbuff_status                    ;
  logic [15:0]                                                   rcv2rdbuff_cplid                     ;
  logic [CC_DMA_SEG_BUF_DATA_WIDTH-1:0]                          rcv2rdbuff_data                      ;
  logic [CX_NW-1:0]                                              rcv2rdbuff_dwen                      ;
  logic                                                          rcv2rdbuff_cpl_timeout               ;
  logic [CX_TAG_SIZE-1:0]                                        rcv2rdbuff_timeout_cpl_tag           ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       rdbuff2sram_rd_addr                  ;
  logic                                                          rdbuff2sram_rd_en                    ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       rdbuff2sram_wr_addr                  ;
  logic [CC_DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     rdbuff2sram_wr_data                  ;
  logic                                                          rdbuff2sram_wr_en                    ;
  logic                                                          sram2rdbuff_rd_ack                   ;
  logic [CC_DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     sram2rdbuff_rd_data                  ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_cpl_tag                     ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_error_tag                   ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2lut_rd_seg_num                  ;
  logic                                                          ctrl2lut_rd_seg_num_recycle          ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2lut_timeout_seg_num_async       ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2lut_timeout_seg_num             ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_timeout_tag                 ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_cpl_tag_5bit                ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_error_tag_5bit              ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]                     ctrl2lut_rd_seg_num_5bit             ;
  logic                                                          ctrl2lut_rd_seg_num_recycle_5bit     ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]                     ctrl2lut_timeout_seg_num_async_5bit  ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]                     ctrl2lut_timeout_seg_num_5bit        ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_timeout_tag_5bit            ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_cpl_tag_8bit                ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_error_tag_8bit              ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]                     ctrl2lut_rd_seg_num_8bit             ;
  logic                                                          ctrl2lut_rd_seg_num_recycle_8bit     ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]                     ctrl2lut_timeout_seg_num_async_8bit  ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]                     ctrl2lut_timeout_seg_num_8bit        ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_timeout_tag_8bit            ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_cpl_tag_10bit               ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_error_tag_10bit             ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2lut_rd_seg_num_10bit            ;
  logic                                                          ctrl2lut_rd_seg_num_recycle_10bit    ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2lut_timeout_seg_num_async_10bit ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2lut_timeout_seg_num_10bit       ;
  logic [CX_TAG_SIZE-1:0]                                        ctrl2lut_timeout_tag_10bit           ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           ctrl2pdly_channel                    ;
  logic [CC_DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     ctrl2pdly_data                       ;
  logic                                                          ctrl2pdly_dv                         ;
  logic [CX_NW-1 :0]                                             ctrl2pdly_dwen                       ;
  logic                                                          ctrl2pdly_eot                        ;
  logic                                                          ctrl2pdly_error                      ;
  logic [CX_NFUNC_WD-1:0]                                        ctrl2pdly_func_num                   ;
  logic                                                          ctrl2pdly_hv                         ;
  logic                                                          ctrl2pdly_last                       ;
  logic                                                          ctrl2rordr_rd_seg_num_recycle        ;
  logic                                                          ctrl2rordr_ready                     ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                ctrl2rordr_seg_pkt_avail_mask        ;
  logic                                                          ctrl2sbc_drop                        ;
  logic                                                          ctrl2sbc_init                        ;
  logic [(CC_DMA_SEG_BUF_NW_ADDR_WIDTH*NUM_DMA_RD_SEGMENTS)-1:0] ctrl2sbc_init_seg_sizes              ;
  logic                                                          ctrl2sbc_keep                        ;
  logic                                                          ctrl2sbc_pop                         ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2sbc_pop_seg_num                 ;
  logic [CC_DMA_SEG_BUF_DATA_WIDTH-1:0]                          ctrl2sbc_push_data                   ;
  logic                                                          ctrl2sbc_push                        ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          ctrl2sbc_push_seg_num                ;
  logic                                                          ctrl2sbc_push_start                  ;
  logic [CC_DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     ctrl2sbc_rdata                       ;
  logic                                                          dalgn2cmwr_dv                        ;
  logic                                                          dalgn2cmwr_hv                        ;
  logic                                                          dalgn2cmwr_eot                       ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           dalgn2cmwr_chan_num                  ;
  logic                                                          dalgn2cmwr_last                      ;
  logic [CX_NW-1:0]                                              dalgn2cmwr_dwen                      ;
  logic [CC_DMA_SEG_BUF_DATA_WIDTH-1:0]                          dalgn2cmwr_data                      ;
  logic [CX_NFUNC_WD-1:0]                                        dalgn2cmwr_func_num                  ;
  logic                                                          dalgn2pdly_halt                      ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_channel                     ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_error_chan_num              ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          lut2ctrl_req_seg_num                 ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_async       ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel             ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_chan_num            ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          lut2ctrl_timeout_seg_num             ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_channel_5bit                ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_error_chan_num_5bit         ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]                     lut2ctrl_req_seg_num_5bit            ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_async_5bit  ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_5bit        ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_chan_num_5bit       ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]                     lut2ctrl_timeout_seg_num_5bit        ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_channel_8bit                ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_error_chan_num_8bit         ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]                     lut2ctrl_req_seg_num_8bit            ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_async_8bit  ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_8bit        ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_chan_num_8bit       ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]                     lut2ctrl_timeout_seg_num_8bit        ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_channel_10bit               ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_error_chan_num_10bit        ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          lut2ctrl_req_seg_num_10bit           ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_async_10bit ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_channel_10bit       ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           lut2ctrl_timeout_chan_num_10bit      ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          lut2ctrl_timeout_seg_num_10bit       ;
  logic                                                          pdly2ctrl_halt                       ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           pdly2dalgn_chan_num                  ;
  logic [CC_DMA_SEG_BUF_DATA_WIDTH-1:0]                          pdly2dalgn_data                      ;
  logic                                                          pdly2dalgn_dv                        ; 
  logic [CX_NW-1 :0]                                             pdly2dalgn_dwen                      ;
  logic                                                          pdly2dalgn_eot                       ;
  logic                                                          pdly2dalgn_error                     ;
  logic [CX_NFUNC_WD-1:0]                                        pdly2dalgn_func_num                  ;
  logic                                                          pdly2dalgn_hv                        ;
  logic                                                          pdly2dalgn_last                      ;
  logic                                                          rawreg2rdctrl_en_true                ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          rordr2ctrl_seg_num                   ;
  logic                                                          rordr2ctrl_valid                     ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                sbc2ctrl_empty                       ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                sbc2ctrl_empty_p_1                   ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                sbc2ctrl_full_m_1                    ;
  logic [CC_DMA_SEG_BUF_DATA_WECC_WIDTH-1:0]                     sbc2ctrl_pop_data                    ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       sbc2ctrl_raddr                       ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                sbc2ctrl_seg_pkt_avail               ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       sbc2ctrl_waddr                       ;
  logic [CC_DMA_SEG_BUF_DATA_WIDTH-1:0]                          sbc2ctrl_wdata                       ;
  logic                                                          sbc2ctrl_wen_n                       ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH:0]                            sbc_num_segs                         ;
  logic                                                          sbc_init_done                        ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                seg_pkt_avail                        ;
  logic                                                          tmgr2lut_req                         ;
  logic [CX_TAG_SIZE-1:0]                                        tmgr2lut_req_tag                     ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          tmgr2lut_req_seg_num                 ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           tmgr2lut_req_channel                 ;
  logic                                                          tmgr2lut_req_5bit                    ;
  logic [CX_TAG_SIZE-1:0]                                        tmgr2lut_req_tag_5bit                ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]                     tmgr2lut_req_seg_num_5bit            ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           tmgr2lut_req_channel_5bit            ;
  logic                                                          tmgr2lut_req_8bit                    ;
  logic [CX_TAG_SIZE-1:0]                                        tmgr2lut_req_tag_8bit                ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]                     tmgr2lut_req_seg_num_8bit            ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           tmgr2lut_req_channel_8bit            ;
  logic                                                          tmgr2lut_req_10bit                   ;
  logic [CX_TAG_SIZE-1:0]                                        tmgr2lut_req_tag_10bit               ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          tmgr2lut_req_seg_num_10bit           ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           tmgr2lut_req_channel_10bit           ;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                           tmgr2rordr_req_channel               ;
  logic                                                          tmgr2rordr_req                       ;
  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0]                          tmgr2rordr_req_seg_num               ;
  logic [NUM_DMA_RD_SEGMENTS-1:0]                                sbc2ctrl_seg_pkt_avail_r             ;
  logic [TRGT_DATA_PROT_WD-1:0]                                  rcv2rdbuff_data_prot                 ;
  logic [RAM_ECC_WD-1:0]                                         sbc2ctrl_wdata_prot                  ;
  logic [RAM_ECC_WD-1:0]                                         ctrl2sbc_push_data_prot              ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       ras_rd_addr                          ;
  logic                                                          rdbuff_ctrl_ras_par_dt_pulse         ;
  logic                                                          cfg_ras_recc_rbuff_correct           ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       ras_addr_ecc_corr_out                ;
  logic [CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]                       ras_addr_ecc_ucorr_out               ;
  logic                                                          ras_data_ecc_corr_err                ;
  logic                                                          ras_data_ecc_ucorr_err               ;
  logic [TRGT_DATA_PROT_WD-1:0]                                  pdly2dalgn_data_prot                 ;
  logic [TRGT_DATA_PROT_WD-1:0]                                  dalgn2cmwr_data_prot                 ;
  hdrWrap_s                                                      ctrl2pdly_hdr                        ;
  hdrWrap_s                                                      pdly2dalgn_hdr                       ;
  hdrWrap_s                                                      dalgn2cmwr_hdr                       ;

  typedef struct packed {
    logic [CX_TAG_SIZE-1:0] pcieTag;
  } reqInfoLutData_s;

  reqInfoLutData_s [NUM_DMA_RD_SEGMENTS-1:0]       r_reqInfoLut     ;
  logic            [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] s_reqInfoLutSeg  ;
  reqInfoLutData_s                                 s_reqInfoLutData ;
  logic                                            s_reqInfoLutEn   ;
  logic                                            s_tagFifo_push_req_n ;
  logic                                            s_tagFifo_pop_req_n  ;
  logic            [CX_TAG_SIZE-1:0]               s_tagFifo_data_in    ;
  logic            [CX_TAG_SIZE-1:0]               w_tagFifo_data_out   ;

  
  assign s_reqInfoLutEn           = b_push.w_valid;
  assign s_reqInfoLutData.pcieTag = b_push.w_data.pcieTag;
  assign s_reqInfoLutSeg          = b_push.w_data.segment[NUM_DMA_RD_SEGMENTS_WIDTH-1:0];
  
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : reqInfoLut_PROC
    if (!b_clk.w_reset_n) begin
      r_reqInfoLut <= #`TP '0;
    end else begin
      foreach (r_reqInfoLut[i]) begin
        if (s_reqInfoLutEn && (i == s_reqInfoLutSeg)) begin
          r_reqInfoLut[i] <= #`TP s_reqInfoLutData;
        end else begin
          r_reqInfoLut[i] <= #`TP r_reqInfoLut[i];
        end
      end
    end
  end

  assign s_tagFifo_push_req_n = !(rordr2ctrl_valid && ctrl2rordr_ready);
  assign s_tagFifo_pop_req_n  = !(b_cpl.w_eot && (b_cpl.w_dv || b_cpl.w_hv)) || b_cpl.w_halt;
  assign s_tagFifo_data_in    = r_reqInfoLut[rordr2ctrl_seg_num].pcieTag;

  localparam integer LP_REG_DELAY_DENOM  = 1000;
  localparam integer LP_REG_DELAY_TIME   = `TP * LP_REG_DELAY_DENOM;

 DWC_pcie_ctl_bcm65_td
   #(
     .WIDTH           ( CX_TAG_SIZE               )
    ,.DEPTH           ( NUM_DMA_RD_SEGMENTS       )
    ,.AE_LEVEL        ( 1                         )
    ,.AF_LEVEL        ( 1                         )
    ,.ERR_MODE        ( 2                         )
    ,.RST_MODE        ( 0                         )
    ,.ADDR_WIDTH      ( NUM_DMA_RD_SEGMENTS_WIDTH )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME         )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM        )
  )
  u_tagFifo(
     .clk             ( b_clk.w_main_clk          )
    ,.rst_n           ( b_clk.w_reset_n           )
    ,.init_n          ( 1'b1                      )
    ,.push_req_n      ( s_tagFifo_push_req_n      )
    ,.pop_req_n       ( s_tagFifo_pop_req_n       )
    ,.data_in         ( s_tagFifo_data_in         )
    ,.data_out        ( w_tagFifo_data_out        )
    ,.diag_n          ( 1'b0                      )
    // SMD: Output port to an instance is not connected
    // SJ:  These ports are not used.
    // spyglass disable_block W287b
    ,.full            ( /* NC */                  )
    ,.empty           ( /* NC */                  )
    ,.almost_empty    ( /* NC */                  )
    ,.half_full       ( /* NC */                  )
    ,.almost_full     ( /* NC */                  )
    ,.error           ( /* NC */                  )
    // spyglass enable_block W287b
    // SMD: A signal or variable is set but never read.     
    // SJ:  Variable used in the assertion
    // spyglass disable_block W528
    // spyglass enable_block W528
    );


  DWC_pcie_edmapf_rdbuff_rordr
   #(
     .NUM_DMA_RD_CHAN                  ( CC_NUM_DMA_RD_CHAN                            )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH                      )
    ,.NUM_DMA_RD_SEGMENTS              ( NUM_DMA_RD_SEGMENTS                           )
    ,.NUM_DMA_RD_SEGMENTS_WIDTH        ( NUM_DMA_RD_SEGMENTS_WIDTH                     )
    ) u_rordr(
       .clk                            ( b_clk.w_main_clk                              )
      ,.reset_n                        ( b_clk.w_reset_n                               )
      ,.tmgr2rordr_req                 ( tmgr2rordr_req                                )
      ,.tmgr2rordr_req_seg_num         ( tmgr2rordr_req_seg_num                        )
      ,.tmgr2rordr_req_channel         ( tmgr2rordr_req_channel                        )
      ,.seg_pkt_avail                  ( seg_pkt_avail                                 )
      ,.ctrl2rordr_ready               ( ctrl2rordr_ready                              )
      ,.rordr2ctrl_valid               ( rordr2ctrl_valid                              )
      ,.rordr2ctrl_seg_num             ( rordr2ctrl_seg_num                            )
      );

  logic [NUM_DMA_RD_SEGMENTS -1:0] lut2ctrl_active;
  logic [NUM_DMA_RD_SEGMENTS -1:0] lut2ctrl_active_10bit;
  logic [L_NUM_SEG_8_BIT     -1:0] lut2ctrl_active_8bit;
  logic [L_NUM_SEG_5_BIT     -1:0] lut2ctrl_active_5bit;

  DWC_pcie_edma_rdbuff_ctrl
   #(
     .NUM_DMA_RD_CHAN                  ( CC_NUM_DMA_RD_CHAN                            )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH                      )
    ,.NUM_DMA_RD_TAG                   ( CC_NUM_DMA_RD_TAG                             )
    ,.NUM_DMA_RD_TAG_WIDTH             ( CC_NUM_DMA_RD_TAG_WIDTH                       )
    ,.NUM_DMA_RD_SEGMENTS              ( NUM_DMA_RD_SEGMENTS                           )
    ,.DMA_SEG_BUF_DATA_WIDTH           ( CC_DMA_SEG_BUF_DATA_WIDTH                     )
    ,.DMA_SEG_BUF_DATA_WECC_WIDTH      ( CC_DMA_SEG_BUF_DATA_WECC_WIDTH                )
    ,.DMA_SEG_BUF_NW_ADDR_WIDTH        ( CC_DMA_SEG_BUF_NW_ADDR_WIDTH                  )
    ,.DMA_SEG_DEPTH                    ( CC_DMA_SEG_DEPTH                              )
    ,.DMA_SEG_ADDR_WIDTH               ( CC_DMA_SEG_ADDR_WIDTH                         )
    ,.CORE_DATA_BUS_WD                 ( CC_CORE_DATA_BUS_WD                           )
    ,.NW                               ( CX_NW                                         )
    ,.NW_LOG2                          ( CX_NW_LOG2                                    )
    ,.HDR_WIDTH                        ( $bits(hdrWrap_s)                              )
    ,.NFUNC_WD                         ( CX_NFUNC_WD                                   )
    ,.DBUS_DWORD_WD                    ( 32                                            )
    ,.DMA_SEG_BUF_NW_ADDRP_WIDTH       ( CC_DMA_SEG_BUF_NW_ADDRP_WIDTH                 )
    ,.DWORD_PROT_BITS                  ( DWORD_PROT_BITS                               )
    ,.PM                               ( CX_RAS_PARITY_MODE                            )
    ,.RAS_RAM_PROT_RANGE               ( CX_RAS_RAM_PROT_RANGE                         )
    ,.RAS_PROT_RANGE                   ( CX_RAS_PROT_RANGE                             )
    ,.RAS_PARITY_MODE                  ( CX_RAS_PARITY_MODE                            )
    ,.DATA_PROT_WD                     ( TRGT_DATA_PROT_WD                             )
    ,.DATA_WIDTH                       ( CC_DMA_SEG_BUF_DATA_WIDTH                     )
  ) u_ctrl(
       .clk                            ( b_clk.w_main_clk                              )
      ,.reset_n                        ( b_clk.w_reset_n                               )
      ,.rawreg2rdctrl_en               ( rawreg2rdctrl_en_true                         )
      ,.cfg_max_non_dma_tag_init       ( '0                                            )
      ,.rcv2rdbuff_hv                  ( rcv2rdbuff_hv                                 )
      ,.rcv2rdbuff_dv                  ( rcv2rdbuff_dv                                 )
      ,.rcv2rdbuff_eot                 ( rcv2rdbuff_eot                                )
      ,.rcv2rdbuff_last                ( rcv2rdbuff_last                               )
      ,.rcv2rdbuff_tlp_abort           ( rcv2rdbuff_tlp_abort                          )
      ,.rcv2rdbuff_dllp_abort          ( rcv2rdbuff_dllp_abort                         )
      ,.rcv2rdbuff_ecrc_err            ( rcv2rdbuff_ecrc_err                           )
      ,.rcv2rdbuff_func_num            ( rcv2rdbuff_func_num                           )
      ,.rcv2rdbuff_tag                 ( rcv2rdbuff_tag                                )
      ,.rcv2rdbuff_len_dw              ( rcv2rdbuff_len_dw                             )
      ,.rcv2rdbuff_attr                ( rcv2rdbuff_attr                               )
      ,.rcv2rdbuff_ep                  ( rcv2rdbuff_ep                                 )
      ,.rcv2rdbuff_td                  ( rcv2rdbuff_td                                 )
      ,.rcv2rdbuff_tc                  ( rcv2rdbuff_tc                                 )
      ,.rcv2rdbuff_status              ( rcv2rdbuff_status                             )
      ,.rcv2rdbuff_cplid               ( rcv2rdbuff_cplid                              )
      ,.rcv2rdbuff_data                ( rcv2rdbuff_data                               )
      ,.rcv2rdbuff_dwen                ( rcv2rdbuff_dwen                               )
      ,.lut2ctrl_req_seg_num           ( lut2ctrl_req_seg_num                          )
      ,.lut2ctrl_timeout_seg_num       ( lut2ctrl_timeout_seg_num                      )
      ,.lut2ctrl_timeout_chan_num      ( lut2ctrl_timeout_chan_num                     )
      ,.lut2ctrl_error_chan_num        ( lut2ctrl_error_chan_num                       )
      ,.lut2ctrl_channel               ( lut2ctrl_channel                              )
      ,.lut2ctrl_timeout_channel       ( lut2ctrl_timeout_channel                      )
      ,.lut2ctrl_timeout_channel_async ( lut2ctrl_timeout_channel_async                )
      ,.lut2ctrl_active                ( lut2ctrl_active                               )
      ,.sbc2ctrl_full_m_1              ( sbc2ctrl_full_m_1                             )
      ,.sbc2ctrl_seg_pkt_avail         ( sbc2ctrl_seg_pkt_avail                        )
      ,.sbc2ctrl_empty_p_1             ( sbc2ctrl_empty_p_1                       )
      ,.sbc2ctrl_empty                 ( sbc2ctrl_empty                                )
      ,.sbc2ctrl_pop_data              ( sbc2ctrl_pop_data                             )
      ,.sbc2ctrl_waddr                 ( sbc2ctrl_waddr                                )
      ,.sbc2ctrl_wen_n                 ( sbc2ctrl_wen_n                                )
      ,.sbc2ctrl_wdata                 ( sbc2ctrl_wdata                                )
      ,.sbc2ctrl_raddr                 ( sbc2ctrl_raddr                                )
      ,.rordr2ctrl_last_chan_req       ( '0                                            )
      ,.sarb2rdbuff_rd_ack             ( sram2rdbuff_rd_ack                            )
      ,.sarb2rdbuff_rd_data            ( sram2rdbuff_rd_data                           )
      ,.pdly2ctrl_halt                 ( pdly2ctrl_halt                                )
      ,.rcv2rdbuff_cpl_timeout         ( rcv2rdbuff_cpl_timeout                        )
      ,.rcv2rdbuff_timeout_cpl_tag     ( rcv2rdbuff_timeout_cpl_tag                    )
      ,.rawreg2rdctrl_doorbell         ( '0                                            )
      ,.rawreg2rdctrl_doorbell_toggle  ( '0                                            )
      ,.rawreg2rdctrl_doorbell_stop    ( '0                                            )
      ,.ctrl2lut_cpl_tag               ( ctrl2lut_cpl_tag                              )
      ,.ctrl2lut_timeout_tag           ( ctrl2lut_timeout_tag                          )
      ,.ctrl2lut_error_tag             ( ctrl2lut_error_tag                            )
      ,.ctrl2lut_timeout_seg_num       ( ctrl2lut_timeout_seg_num                      )
      ,.ctrl2lut_timeout_seg_num_async ( ctrl2lut_timeout_seg_num_async                )
      ,.ctrl2lut_rd_seg_num_recycle    ( ctrl2lut_rd_seg_num_recycle                   )
      ,.ctrl2lut_rd_seg_num            ( ctrl2lut_rd_seg_num                           )
      ,.ctrl2sbc_init                  ( ctrl2sbc_init                                 )
      ,.ctrl2sbc_init_seg_sizes        ( ctrl2sbc_init_seg_sizes                       )
      ,.ctrl2sbc_push_start            ( ctrl2sbc_push_start                           )
      ,.ctrl2sbc_push                  ( ctrl2sbc_push                                 )
      ,.ctrl2sbc_push_seg_num          ( ctrl2sbc_push_seg_num                         )
      ,.ctrl2sbc_keep                  ( ctrl2sbc_keep                                 )
      ,.ctrl2sbc_drop                  ( ctrl2sbc_drop                                 )
      ,.ctrl2sbc_push_data             ( ctrl2sbc_push_data                            )
      ,.ctrl2sbc_pop                   ( ctrl2sbc_pop                                  )
      ,.ctrl2sbc_pop_seg_num           ( ctrl2sbc_pop_seg_num                          )
      ,.ctrl2sbc_rdata                 ( ctrl2sbc_rdata                                )
      ,.ctrl2sarb_wr_addr              ( rdbuff2sram_wr_addr                           )
      ,.ctrl2sarb_wr_en                ( rdbuff2sram_wr_en                             )
      ,.ctrl2sarb_wr_data              ( rdbuff2sram_wr_data                           )
      ,.ctrl2sarb_rd_addr              ( rdbuff2sram_rd_addr                           )
      ,.ctrl2sarb_rd_en                ( rdbuff2sram_rd_en                             )
      ,.ctrl2pdly_hv                   ( ctrl2pdly_hv                                  )
      ,.ctrl2pdly_hdr                  ( ctrl2pdly_hdr                                 )
      ,.ctrl2pdly_func_num             ( ctrl2pdly_func_num                            )
      ,.ctrl2pdly_channel              ( ctrl2pdly_channel                             )
      ,.ctrl2pdly_dv                   ( ctrl2pdly_dv                                  )
      ,.ctrl2pdly_data                 ( ctrl2pdly_data                                )
      ,.ctrl2pdly_dwen                 ( ctrl2pdly_dwen                                )
      ,.ctrl2pdly_eot                  ( ctrl2pdly_eot                                 )
      ,.ctrl2pdly_error                ( ctrl2pdly_error                               )
      ,.ctrl2pdly_last                 ( ctrl2pdly_last                                )
      ,.ctrl2rordr_rd_seg_num_recycle  ( ctrl2rordr_rd_seg_num_recycle                 )
      ,.ctrl2rordr_ready               ( ctrl2rordr_ready                              )
      ,.ctrl2rordr_seg_pkt_avail_mask  ( ctrl2rordr_seg_pkt_avail_mask                 )
      ,.rordr2ctrl_valid               ( rordr2ctrl_valid                              )
      ,.rordr2ctrl_seg_num             ( rordr2ctrl_seg_num                            )
      ,.rcv2rdbuff_data_prot           ( rcv2rdbuff_data_prot                          )
      ,.sbc2ctrl_wdata_prot            ( sbc2ctrl_wdata_prot                           )
      ,.ctrl2sbc_push_data_prot        ( ctrl2sbc_push_data_prot                       )
      ,.ras_rd_addr                    ( ras_rd_addr                                   )
      ,.rdbuff_ctrl_ras_par_dt_pulse   ( rdbuff_ctrl_ras_par_dt_pulse                  )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.ctrl2rordr_rd_seg_num          ( /* NC */                                      )
      ,.ctrl2tmgr_chan_tag_req_halt    ( /* NC */                                      )
      ,.ctrl2tmgr_rd_seg_num_recycle   ( /* NC */                                      )
      ,.ctrl2tmgr_rd_seg_num           ( /* NC */                                      )
      ,.ctrl2sarb_wr_eot               ( /* NC */                                      )
      // spyglass enable_block W287b
      );

  DWC_pcie_edma_rdbuff_pipe_delay
   #(
     .HDR_WIDTH                        ( $bits(hdrWrap_s)                              )
    ,.NFUNC_WD                         ( CX_NFUNC_WD                                   )
    ,.NUM_DMA_RD_CHAN                  ( CC_NUM_DMA_RD_CHAN                            )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH                      )
    ,.DATA_WIDTH                       ( CC_DMA_SEG_BUF_DATA_WIDTH                     )
    ,.DATA_WECC_WIDTH                  ( CC_DMA_SEG_BUF_DATA_WECC_WIDTH                )
    ,.NW                               ( CX_NW                                         )
    ,.RAS_RAM_PROT_RANGE               ( CX_RAS_RAM_PROT_RANGE                         )
    ,.RAS_PROT_RANGE                   ( CX_RAS_PROT_RANGE                             )
    ,.RAS_PARITY_MODE                  ( CX_RAS_PARITY_MODE                            )
    ,.DATA_PROT_WD                     ( TRGT_DATA_PROT_WD                             )
    ,.ADDR_PROT_WD                     ( CC_DMA_SEG_BUF_NW_ADDR_WIDTH                  )
    ) u_pipe_delay(
       .clk                            ( b_clk.w_main_clk                              )
      ,.reset_n                        ( b_clk.w_reset_n                               )
      ,.header_valid_in                ( ctrl2pdly_hv                                  )
      ,.header_in                      ( ctrl2pdly_hdr                                 )
      ,.func_num_in                    ( ctrl2pdly_func_num                            )
      ,.chan_num_in                    ( ctrl2pdly_channel                             )
      ,.data_valid_in                  ( ctrl2pdly_dv                                  )
      ,.data_in_ramValid               ( b_ram0.w_validb                               )
      ,.data_word_enable_in            ( ctrl2pdly_dwen                                )
      ,.data_in                        ( ctrl2pdly_data                                )
      ,.end_of_transfer_in             ( ctrl2pdly_eot                                 )
      ,.error_in                       ( ctrl2pdly_error                               )
      ,.last_in                        ( ctrl2pdly_last                                )
      ,.halt_in                        ( dalgn2pdly_halt                               )
      ,.header_valid_out               ( pdly2dalgn_hv                                 )
      ,.header_out                     ( pdly2dalgn_hdr                                )
      ,.func_num_out                   ( pdly2dalgn_func_num                           )
      ,.chan_num_out                   ( pdly2dalgn_chan_num                           )
      ,.data_valid_out                 ( pdly2dalgn_dv                                 )
      ,.data_word_enable_out           ( pdly2dalgn_dwen                               )
      ,.data_out                       ( pdly2dalgn_data                               )
      ,.end_of_transfer_out            ( pdly2dalgn_eot                                )
      ,.error_out                      ( pdly2dalgn_error                              )
      ,.last_out                       ( pdly2dalgn_last                               )
      ,.halt_out                       ( pdly2ctrl_halt                                )
      ,.ras_data_prot_out              ( pdly2dalgn_data_prot                          )
      ,.ras_addr_in                    ( ras_rd_addr                                   )
      ,.rdbuff_ras_dp_err_log_core     ( rdbuff_ras_dp_err_log_core                    )
      ,.rdbuff_ras_dp_err_inj_core     ( rdbuff_ras_dp_err_inj_core                    )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.tlp_in_fligh                   ( /* NC */                                      )
      // spyglass enable_block W287b
      );

  DW_sbc
   #(
     .SEGS                             ( NUM_DMA_RD_SEGMENTS                           )
    ,.SEG_W                            ( NUM_DMA_RD_SEGMENTS_WIDTH                     )
    ,.RAM_W                            ( CC_DMA_SEG_BUF_DATA_WECC_WIDTH                )
    ,.RAM_WEC                          ( CC_DMA_SEG_BUF_DATA_WECC_WIDTH                )
    ,.RAM_AW                           ( CC_DMA_SEG_BUF_NW_ADDR_WIDTH                  )
    ,.GEN_STARTEND_ADDRS               ( 1                                             )
    ,.HOLD_RADDR                       ( 1                                             )
    ,.NHQ                              ( 1                                             )
    ) u_sbc(
       .clk                            ( b_clk.w_main_clk                              )
      ,.rst_n                          ( b_clk.w_reset_n                               )
      ,.srst_n                         ( rawreg2rdctrl_en_true                         )
      ,.sb_init_i                      ( ctrl2sbc_init                                 )
      ,.sb_init_seg_sizes_i            ( ctrl2sbc_init_seg_sizes                       )
      ,.sb_init_num_segs_i             ( sbc_num_segs                                  )
      ,.sb_push_i                      ( ctrl2sbc_push                                 )
      ,.sb_push_start_i                ( ctrl2sbc_push_start                           )
      ,.sb_push_keep_i                 ( ctrl2sbc_keep                                 )
      ,.sb_push_drop_i                 ( ctrl2sbc_drop                                 )
      ,.sb_push_seg_i                  ( ctrl2sbc_push_seg_num                         )
      ,.sb_reset_push_ptr              ( '0                                            )
      ,.sb_reset_push_seg_i            ( '0                                            )
      ,.sb_pop_i                       ( ctrl2sbc_pop                                  )
      ,.sb_pop_seg_i                   ( ctrl2sbc_pop_seg_num                          )
      ,.sb_pop_look_i                  ( '0                                            )
      ,.sb_reset_pop_ptr               ( '0                                            )
      ,.sb_reset_pop_seg_i             ( '0                                            )
      ,.sb_seg_start_i                 ( '0                                            )
      ,.sb_seg_end_i                   ( '0                                            )
      ,.sb_rdata_i                     ( ctrl2sbc_rdata                                )
      ,.sb_pop_data_o                  ( sbc2ctrl_pop_data                             )
      ,.sb_empty_o                     ( sbc2ctrl_empty                                )
      ,.sb_empty_p_1_o                 ( sbc2ctrl_empty_p_1                            )
      ,.sb_full_m_1_o                  ( sbc2ctrl_full_m_1                             )
      ,.sb_seg_pkt_avail_o             ( sbc2ctrl_seg_pkt_avail                        )
      ,.sb_waddr_o                     ( sbc2ctrl_waddr                                )
      ,.sb_wen_n_o                     ( sbc2ctrl_wen_n                                )
      ,.sb_raddr_o                     ( sbc2ctrl_raddr                                )
      ,.sb_wdata_o                     ( {sbc2ctrl_wdata_prot,sbc2ctrl_wdata}          )
      ,.sb_push_data_i                 ( {ctrl2sbc_push_data_prot,ctrl2sbc_push_data}  )
      ,.sb_init_done_o                 ( sbc_init_done                                 )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.sb_full_o                      ( /* NC */                                      )
      ,.sb_full_m_2_o                  ( /* NC */                                      )
      ,.sb_ren_n_o                     ( /* NC */                                      )
      ,.sb_par_chk_val_o               ( /* NC */                                      )
      // spyglass enable_block W287b
      );

  DWC_pcie_edma_rdbuff_lut
   #(
     .NUM_DMA_RD_TAG                   ( CC_NUM_DMA_RD_TAG                             )
    ,.NUM_DMA_RD_TAG_WIDTH             ( CC_NUM_DMA_RD_TAG_WIDTH                       )
    ,.NUM_DMA_RD_SEGMENTS              ( NUM_DMA_RD_SEGMENTS                           )
    ,.NUM_DMA_RD_SEGMENTS_WIDTH        ( NUM_DMA_RD_SEGMENTS_WIDTH                     )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH                      )
    ,.DMA_RD_TAG_HIGH                  ( CC_DMA_RD_TAG_HIGH                            )
    ,.DMA_RD_TAG_HIGH_WIDTH            ( CC_DMA_RD_TAG_HIGH_WIDTH                      )
    ,.DMA_RD_TAG_LOW                   ( CC_DMA_RD_TAG_LOW                             )
    ) u_lut_10bit(
       .clk                            ( b_clk.w_main_clk                              )
      ,.reset_n                        ( b_clk.w_reset_n                               )
      ,.rawreg2rdctrl_en               ( rawreg2rdctrl_en_true                         )
      ,.tmgr2lut_req                   ( tmgr2lut_req_10bit                            )
      ,.tmgr2lut_req_tag               ( tmgr2lut_req_tag_10bit                        )
      ,.tmgr2lut_req_seg_num           ( tmgr2lut_req_seg_num_10bit                    )
      ,.tmgr2lut_channel               ( tmgr2lut_req_channel_10bit                    )
      ,.ctrl2lut_cpl_tag               ( ctrl2lut_cpl_tag_10bit                        )
      ,.ctrl2lut_timeout_tag           ( ctrl2lut_timeout_tag_10bit                    )
      ,.ctrl2lut_error_tag             ( ctrl2lut_error_tag_10bit                      )
      ,.ctrl2lut_timeout_seg_num       ( ctrl2lut_timeout_seg_num_10bit                )
      ,.ctrl2lut_timeout_seg_num_async ( ctrl2lut_timeout_seg_num_async_10bit          )
      ,.ctrl2lut_rd_seg_num_recycle    ( ctrl2lut_rd_seg_num_recycle_10bit             )
      ,.ctrl2lut_rd_seg_num            ( ctrl2lut_rd_seg_num_10bit                     )
      ,.lut2ctrl_req_seg_num           ( lut2ctrl_req_seg_num_10bit                    )
      ,.lut2ctrl_timeout_seg_num       ( lut2ctrl_timeout_seg_num_10bit                )
      ,.lut2ctrl_timeout_chan_num      ( lut2ctrl_timeout_chan_num_10bit               )
      ,.lut2ctrl_error_chan_num        ( lut2ctrl_error_chan_num_10bit                 )
      ,.lut2ctrl_channel               ( lut2ctrl_channel_10bit                        )
      ,.lut2ctrl_timeout_channel       ( lut2ctrl_timeout_channel_10bit                )
      ,.lut2ctrl_timeout_channel_async ( lut2ctrl_timeout_channel_async_10bit          )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.lut2ctrl_error                 ( /* NC */                                      )
      // spyglass enable_block W287b
      ,.lut2ctrl_active                ( lut2ctrl_active_10bit                         )
      );

  DWC_pcie_edma_rdbuff_lut
   #(
     .NUM_DMA_RD_TAG                   ( L_NUM_SEG_8_BIT                               )
    ,.NUM_DMA_RD_TAG_WIDTH             ( NUM_DMA_RD_SEGMENTS_WIDTH_8BIT                )
    ,.NUM_DMA_RD_SEGMENTS              ( L_NUM_SEG_8_BIT                               )
    ,.NUM_DMA_RD_SEGMENTS_WIDTH        ( NUM_DMA_RD_SEGMENTS_WIDTH_8BIT                )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH                      )
    ,.DMA_RD_TAG_HIGH                  ( K_MAXPCIETAG_8BIT                             )
    ,.DMA_RD_TAG_HIGH_WIDTH            ( CC_DMA_RD_TAG_HIGH_WIDTH                      )
    ,.DMA_RD_TAG_LOW                   ( K_MINDMATAG_8BIT                              )
    ) u_lut_8bit(
       .clk                            ( b_clk.w_main_clk                              )
      ,.reset_n                        ( b_clk.w_reset_n                               )
      ,.rawreg2rdctrl_en               ( rawreg2rdctrl_en_true                         )
      ,.tmgr2lut_req                   ( tmgr2lut_req_8bit                             )
      ,.tmgr2lut_req_tag               ( tmgr2lut_req_tag_8bit                         )
      ,.tmgr2lut_req_seg_num           ( tmgr2lut_req_seg_num_8bit                     )
      ,.tmgr2lut_channel               ( tmgr2lut_req_channel_8bit                     )
      ,.ctrl2lut_cpl_tag               ( ctrl2lut_cpl_tag_8bit                         )
      ,.ctrl2lut_timeout_tag           ( ctrl2lut_timeout_tag_8bit                     )
      ,.ctrl2lut_error_tag             ( ctrl2lut_error_tag_8bit                       )
      ,.ctrl2lut_timeout_seg_num       ( ctrl2lut_timeout_seg_num_8bit                 )
      ,.ctrl2lut_timeout_seg_num_async ( ctrl2lut_timeout_seg_num_async_8bit           )
      ,.ctrl2lut_rd_seg_num_recycle    ( ctrl2lut_rd_seg_num_recycle_8bit              )
      ,.ctrl2lut_rd_seg_num            ( ctrl2lut_rd_seg_num_8bit                      )
      ,.lut2ctrl_req_seg_num           ( lut2ctrl_req_seg_num_8bit                     )
      ,.lut2ctrl_timeout_seg_num       ( lut2ctrl_timeout_seg_num_8bit                 )
      ,.lut2ctrl_timeout_chan_num      ( lut2ctrl_timeout_chan_num_8bit                )
      ,.lut2ctrl_error_chan_num        ( lut2ctrl_error_chan_num_8bit                  )
      ,.lut2ctrl_channel               ( lut2ctrl_channel_8bit                         )
      ,.lut2ctrl_timeout_channel       ( lut2ctrl_timeout_channel_8bit                 )
      ,.lut2ctrl_timeout_channel_async ( lut2ctrl_timeout_channel_async_8bit           )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.lut2ctrl_error                 ( /* NC */                                      )
      // spyglass enable_block W287b
      ,.lut2ctrl_active                ( lut2ctrl_active_8bit                          )
      );

  DWC_pcie_edma_rdbuff_lut
   #(
     .NUM_DMA_RD_TAG                   ( L_NUM_SEG_5_BIT                               )
    ,.NUM_DMA_RD_TAG_WIDTH             ( NUM_DMA_RD_SEGMENTS_WIDTH_5BIT                )
    ,.NUM_DMA_RD_SEGMENTS              ( L_NUM_SEG_5_BIT                               )
    ,.NUM_DMA_RD_SEGMENTS_WIDTH        ( NUM_DMA_RD_SEGMENTS_WIDTH_5BIT                )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH                      )
    ,.DMA_RD_TAG_HIGH                  ( K_MAXPCIETAG_5BIT                             )
    ,.DMA_RD_TAG_HIGH_WIDTH            ( CC_DMA_RD_TAG_HIGH_WIDTH                      )
    ,.DMA_RD_TAG_LOW                   ( K_MINDMATAG_5BIT                              )
    ) u_lut_5bit(
       .clk                            ( b_clk.w_main_clk                              )
      ,.reset_n                        ( b_clk.w_reset_n                               )
      ,.rawreg2rdctrl_en               ( rawreg2rdctrl_en_true                         )
      ,.tmgr2lut_req                   ( tmgr2lut_req_5bit                             )
      ,.tmgr2lut_req_tag               ( tmgr2lut_req_tag_5bit                         )
      ,.tmgr2lut_req_seg_num           ( tmgr2lut_req_seg_num_5bit                     )
      ,.tmgr2lut_channel               ( tmgr2lut_req_channel_5bit                     )
      ,.ctrl2lut_cpl_tag               ( ctrl2lut_cpl_tag_5bit                         )
      ,.ctrl2lut_timeout_tag           ( ctrl2lut_timeout_tag_5bit                     )
      ,.ctrl2lut_error_tag             ( ctrl2lut_error_tag_5bit                       )
      ,.ctrl2lut_timeout_seg_num       ( ctrl2lut_timeout_seg_num_5bit                 )
      ,.ctrl2lut_timeout_seg_num_async ( ctrl2lut_timeout_seg_num_async_5bit           )
      ,.ctrl2lut_rd_seg_num_recycle    ( ctrl2lut_rd_seg_num_recycle_5bit              )
      ,.ctrl2lut_rd_seg_num            ( ctrl2lut_rd_seg_num_5bit                      )
      ,.lut2ctrl_req_seg_num           ( lut2ctrl_req_seg_num_5bit                     )
      ,.lut2ctrl_timeout_seg_num       ( lut2ctrl_timeout_seg_num_5bit                 )
      ,.lut2ctrl_timeout_chan_num      ( lut2ctrl_timeout_chan_num_5bit                )
      ,.lut2ctrl_error_chan_num        ( lut2ctrl_error_chan_num_5bit                  )
      ,.lut2ctrl_channel               ( lut2ctrl_channel_5bit                         )
      ,.lut2ctrl_timeout_channel       ( lut2ctrl_timeout_channel_5bit                 )
      ,.lut2ctrl_timeout_channel_async ( lut2ctrl_timeout_channel_async_5bit           )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.lut2ctrl_error                 ( /* NC */                                      )
      // spyglass enable_block W287b
      ,.lut2ctrl_active                ( lut2ctrl_active_5bit                          )
      );

  assign tag_5bit_en  = !b_cdm.w_cfg_ext_tag_en;
  assign tag_10bit_en =  b_cdm.w_cfg_ext_tag_en && b_cdm.w_cfg_10b_tag_en;
  assign tag_8bit_en  = !tag_5bit_en && !tag_10bit_en;
  
  assign tmgr2lut_req_5bit                    = tag_5bit_en  ? tmgr2lut_req                                             : '0 ;
  assign tmgr2lut_req_tag_5bit                = tag_5bit_en  ? tmgr2lut_req_tag                                         : '0 ;
  assign tmgr2lut_req_seg_num_5bit            = tag_5bit_en  ? tmgr2lut_req_seg_num[NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0] : '0 ;
  assign tmgr2lut_req_channel_5bit            = tag_5bit_en  ? tmgr2lut_req_channel                                     : '0 ;
  assign tmgr2lut_req_8bit                    = tag_8bit_en  ? tmgr2lut_req                                             : '0 ;
  assign tmgr2lut_req_tag_8bit                = tag_8bit_en  ? tmgr2lut_req_tag                                         : '0 ;
  assign tmgr2lut_req_seg_num_8bit            = tag_8bit_en  ? tmgr2lut_req_seg_num[NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0] : '0 ;
  assign tmgr2lut_req_channel_8bit            = tag_8bit_en  ? tmgr2lut_req_channel                                     : '0 ;
  assign tmgr2lut_req_10bit                   = tag_10bit_en ? tmgr2lut_req                                             : '0 ;
  assign tmgr2lut_req_tag_10bit               = tag_10bit_en ? tmgr2lut_req_tag                                         : '0 ;
  assign tmgr2lut_req_seg_num_10bit           = tag_10bit_en ? tmgr2lut_req_seg_num                                     : '0 ;
  assign tmgr2lut_req_channel_10bit           = tag_10bit_en ? tmgr2lut_req_channel                                     : '0 ;
  
  assign ctrl2lut_cpl_tag_5bit                = tag_5bit_en  ? ctrl2lut_cpl_tag                                                   : '0 ;
  assign ctrl2lut_timeout_tag_5bit            = tag_5bit_en  ? ctrl2lut_timeout_tag                                               : '0 ;
  assign ctrl2lut_error_tag_5bit              = tag_5bit_en  ? ctrl2lut_error_tag                                                 : '0 ;
  assign ctrl2lut_timeout_seg_num_5bit        = tag_5bit_en  ? ctrl2lut_timeout_seg_num[NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]       : '0 ;
  assign ctrl2lut_timeout_seg_num_async_5bit  = tag_5bit_en  ? ctrl2lut_timeout_seg_num_async[NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0] : '0 ;
  assign ctrl2lut_rd_seg_num_recycle_5bit     = tag_5bit_en  ? ctrl2lut_rd_seg_num_recycle                                        : '0 ;
  assign ctrl2lut_rd_seg_num_5bit             = tag_5bit_en  ? ctrl2lut_rd_seg_num[NUM_DMA_RD_SEGMENTS_WIDTH_5BIT-1:0]            : '0 ;
  assign ctrl2lut_cpl_tag_8bit                = tag_8bit_en  ? ctrl2lut_cpl_tag                                                   : '0 ;
  assign ctrl2lut_timeout_tag_8bit            = tag_8bit_en  ? ctrl2lut_timeout_tag                                               : '0 ;
  assign ctrl2lut_error_tag_8bit              = tag_8bit_en  ? ctrl2lut_error_tag                                                 : '0 ;
  assign ctrl2lut_timeout_seg_num_8bit        = tag_8bit_en  ? ctrl2lut_timeout_seg_num[NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]       : '0 ;
  assign ctrl2lut_timeout_seg_num_async_8bit  = tag_8bit_en  ? ctrl2lut_timeout_seg_num_async [NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]: '0 ;
  assign ctrl2lut_rd_seg_num_recycle_8bit     = tag_8bit_en  ? ctrl2lut_rd_seg_num_recycle                                        : '0 ;
  assign ctrl2lut_rd_seg_num_8bit             = tag_8bit_en  ? ctrl2lut_rd_seg_num[NUM_DMA_RD_SEGMENTS_WIDTH_8BIT-1:0]            : '0 ;
  assign ctrl2lut_cpl_tag_10bit               = tag_10bit_en ? ctrl2lut_cpl_tag                                                   : '0 ;
  assign ctrl2lut_timeout_tag_10bit           = tag_10bit_en ? ctrl2lut_timeout_tag                                               : '0 ;
  assign ctrl2lut_error_tag_10bit             = tag_10bit_en ? ctrl2lut_error_tag                                                 : '0 ;
  assign ctrl2lut_timeout_seg_num_10bit       = tag_10bit_en ? ctrl2lut_timeout_seg_num                                           : '0 ;
  assign ctrl2lut_timeout_seg_num_async_10bit = tag_10bit_en ? ctrl2lut_timeout_seg_num_async                                     : '0 ;
  assign ctrl2lut_rd_seg_num_recycle_10bit    = tag_10bit_en ? ctrl2lut_rd_seg_num_recycle                                        : '0 ;
  assign ctrl2lut_rd_seg_num_10bit            = tag_10bit_en ? ctrl2lut_rd_seg_num                                                : '0 ;

  assign lut2ctrl_req_seg_num           = tag_10bit_en ? lut2ctrl_req_seg_num_10bit                             :  
                                          tag_5bit_en  ? {{SEG_5BIT_DIF{1'b0}}, lut2ctrl_req_seg_num_5bit    }  : {{SEG_8BIT_DIF{1'b0}}, lut2ctrl_req_seg_num_8bit    } ;
  assign lut2ctrl_timeout_seg_num       = tag_10bit_en ? lut2ctrl_timeout_seg_num_10bit                         :  
                                          tag_5bit_en  ? {{SEG_5BIT_DIF{1'b0}}, lut2ctrl_timeout_seg_num_5bit}  : {{SEG_8BIT_DIF{1'b0}}, lut2ctrl_timeout_seg_num_8bit} ;
  assign lut2ctrl_timeout_chan_num      = tag_10bit_en ? lut2ctrl_timeout_chan_num_10bit                        :    
                                          tag_5bit_en  ? lut2ctrl_timeout_chan_num_5bit                         : lut2ctrl_timeout_chan_num_8bit                        ;
  assign lut2ctrl_error_chan_num        = tag_10bit_en ? lut2ctrl_error_chan_num_10bit                          :    
                                          tag_5bit_en  ? lut2ctrl_error_chan_num_5bit                           : lut2ctrl_error_chan_num_8bit                          ;
  assign lut2ctrl_channel               = tag_10bit_en ? lut2ctrl_channel_10bit                                 :    
                                          tag_5bit_en  ? lut2ctrl_channel_5bit                                  : lut2ctrl_channel_8bit                                 ;
  assign lut2ctrl_timeout_channel       = tag_10bit_en ? lut2ctrl_timeout_channel_10bit                         :    
                                          tag_5bit_en  ? lut2ctrl_timeout_channel_5bit                          : lut2ctrl_timeout_channel_8bit                         ;
  assign lut2ctrl_timeout_channel_async = tag_10bit_en ? lut2ctrl_timeout_channel_async_10bit                   :    
                                          tag_5bit_en  ? lut2ctrl_timeout_channel_async_5bit                    : lut2ctrl_timeout_channel_async_8bit                   ;
  assign lut2ctrl_active                = tag_10bit_en ? lut2ctrl_active_10bit                                  :    
                                          tag_5bit_en  ? (NUM_DMA_RD_SEGMENTS)'(lut2ctrl_active_5bit)           : (NUM_DMA_RD_SEGMENTS)'(lut2ctrl_active_8bit)          ;

  DWC_pcie_edma_rdbuff_dword_align
   #(
     .HDR_WIDTH                        ( $bits(hdrWrap_s)                    )
    ,.NW                               ( CX_NW                               )
    ,.NFUNC_WD                         ( CX_NFUNC_WD                         )
    ,.NVFUNC_WD                        ( CX_NVFUNC_WD                        )
    ,.NUM_DMA_RD_CHAN_WIDTH            ( CC_NUM_DMA_RD_CHAN_WIDTH            )
    ,.DBUS_DWORD_WD                    ( 32                                  )
    ,.DMA_SEG_BUF_DATA_WIDTH           ( CC_DMA_SEG_BUF_DATA_WIDTH           )
    ,.RAS_PROT_RANGE                   (CX_RAS_PROT_RANGE                    )
    ,.RAS_PARITY_MODE                  (CX_RAS_PARITY_MODE                   )
    ,.DATA_PROT_WD                     (TRGT_DATA_PROT_WD                    )
    ,.DWORD_PROT_BITS                  (DWORD_PROT_BITS                      )
    ,.PM                               (CX_RAS_PARITY_MODE                   )
    ) u_edma_rdbuff_dword_align(
       .clk                            ( b_clk.w_main_clk                    )
      ,.reset_n                        ( b_clk.w_reset_n                     )
      ,.cmwr2dalgn_halt                ( cmwr2dalgn_halt                     )
      ,.dalgn2cmwr_chan_num            ( dalgn2cmwr_chan_num                 )
      ,.dalgn2cmwr_data                ( dalgn2cmwr_data                     )
      ,.dalgn2cmwr_dv                  ( dalgn2cmwr_dv                       )
      ,.dalgn2cmwr_dwen                ( dalgn2cmwr_dwen                     )
      ,.dalgn2cmwr_eot                 ( dalgn2cmwr_eot                      )
      ,.dalgn2cmwr_func_num            ( dalgn2cmwr_func_num                 )
      ,.dalgn2cmwr_hdr                 ( dalgn2cmwr_hdr                      )
      ,.dalgn2cmwr_hv                  ( dalgn2cmwr_hv                       )
      ,.dalgn2cmwr_last                ( dalgn2cmwr_last                     )
      ,.dalgn2pdly_halt                ( dalgn2pdly_halt                     )
      ,.pdly2dalgn_chan_num            ( pdly2dalgn_chan_num                 )
      ,.pdly2dalgn_data                ( pdly2dalgn_data                     )
      ,.pdly2dalgn_dv                  ( pdly2dalgn_dv                       )
      ,.pdly2dalgn_dwen                ( pdly2dalgn_dwen                     )
      ,.pdly2dalgn_eot                 ( pdly2dalgn_eot                      )
      ,.pdly2dalgn_error               ( pdly2dalgn_error                    )
      ,.pdly2dalgn_func_num            ( pdly2dalgn_func_num                 )
      ,.pdly2dalgn_hdr                 ( pdly2dalgn_hdr                      )
      ,.pdly2dalgn_hv                  ( pdly2dalgn_hv                       )
      ,.pdly2dalgn_last                ( pdly2dalgn_last                     )
      ,.rawreg2rdctrl_en               ( rawreg2rdctrl_en_true               )
      ,.pdly2dalgn_data_prot           ( pdly2dalgn_data_prot                )
      ,.dalgn2cmwr_data_prot           ( dalgn2cmwr_data_prot                )
      );

  assign sbc_num_segs           = NUM_DMA_RD_SEGMENTS                                    ;
  assign tmgr2lut_req           = b_push.w_valid                                         ;
  assign tmgr2lut_req_tag       = b_push.w_data.pcieTag                                  ;
  assign tmgr2lut_req_channel   = b_push.w_data.channel[CC_NUM_DMA_RD_CHAN_WIDTH-1:0]    ;
  assign tmgr2lut_req_seg_num   = b_push.w_data.segment[NUM_DMA_RD_SEGMENTS_WIDTH-1:0]   ;
  assign tmgr2rordr_req         = tmgr2lut_req                                           ;
  assign tmgr2rordr_req_channel = tmgr2lut_req_channel                                   ;
  assign tmgr2rordr_req_seg_num = tmgr2lut_req_seg_num                                   ;
  //FIXME: this is tied for now, not sure about wxtrackrdbuff and gated role in the system
    assign rawreg2rdctrl_en_true  = '1;
  //assign rawreg2rdctrl_en_true  =  rawreg2rdctrl_en_wxtrackrdbuff | rawreg2rdctrl_en_gated  ;
  
  assign seg_pkt_avail          = sbc2ctrl_seg_pkt_avail_r & ctrl2rordr_seg_pkt_avail_mask ;

  always_comb begin : cpl_PROC
    cmwr2dalgn_halt    = b_cpl.w_halt;
    b_cpl.w_hv         = dalgn2cmwr_hv;
    b_cpl.w_dv         = dalgn2cmwr_dv;
    b_cpl.w_eot        = dalgn2cmwr_eot;
    b_cpl.w_data       = {dalgn2cmwr_data_prot, dalgn2cmwr_data};
    b_cpl.w_headerProt = '0;
    b_cpl.w_header     = '{
       default: '0
      ,common1: '{
        default : '0
        ,tc : dalgn2cmwr_hdr.tc
        ,attr : dalgn2cmwr_hdr.attr
        ,pcieTag : w_tagFifo_data_out
        ,pfunc_num : dalgn2cmwr_func_num
      }
      ,common2: '{
        default : '0
        ,td : dalgn2cmwr_hdr.td
        ,dw_len : dalgn2cmwr_hdr.dw_len
        ,poisoned : dalgn2cmwr_hdr.poisoned
        ,cmpltr_id : dalgn2cmwr_hdr.cplId
        ,cpl_status : dalgn2cmwr_hdr.cplStatus
        ,fmt: {dalgn2cmwr_dv,1'b0}
        ,typ: 5'b01010
        ,prfx: K_PRFXDEFAULT
      }
      ,common3: '{
        default : '0
      }
      ,common4: '{
        default : '0
        ,cpl_last: '1 //dalgn2cmwr_last
        ,dwen: dalgn2cmwr_dwen
        ,in_membar_range: '1
      }
      ,radmPort: '{
        default : '0
      }
      ,xadmPort: '{
        default : '0
      }
      ,dma: '{
        default : '0
        ,channel : K_DMACHANWD'(dalgn2cmwr_chan_num)
        ,req     : E_DMA_RDCH_DATA
      }
    };
  end
  

  always_comb begin : bypass_PROC
    rcv2rdbuff_hv         = b_bypass.w_hv ;
    rcv2rdbuff_dv         = b_bypass.w_dv ;
    rcv2rdbuff_eot        = b_bypass.w_eot ;
    rcv2rdbuff_data       = b_bypass.w_dv ? b_bypass.w_data[CC_DMA_SEG_BUF_DATA_WIDTH-1:0] : '0;
    rcv2rdbuff_data_prot  = b_bypass.w_dv ? b_bypass.w_data[CC_CORE_DATA_BUS_WD-1 -: TRGT_DATA_PROT_WD] : {TRGT_DATA_PROT_WD{1'(K_RAS_PARITY_MODE)}};
    rcv2rdbuff_attr       = b_bypass.w_header.common1.attr;
    rcv2rdbuff_func_num   = b_bypass.w_header.common1.pfunc_num;
    rcv2rdbuff_tag        = b_bypass.w_header.common1.pcieTag;
    rcv2rdbuff_tc         = b_bypass.w_header.common1.tc;
    rcv2rdbuff_len_dw     = b_bypass.w_header.common2.dw_len;
    rcv2rdbuff_ep         = b_bypass.w_header.common2.poisoned;
    rcv2rdbuff_td         = b_bypass.w_header.common2.td;
    rcv2rdbuff_status     = b_bypass.w_header.common2.cpl_status;
    rcv2rdbuff_cplid      = b_bypass.w_header.common2.cmpltr_id;
    rcv2rdbuff_dwen       = b_bypass.w_header.common4.dwen;
    rcv2rdbuff_last       = b_bypass.w_header.common4.cpl_last;
    rcv2rdbuff_tlp_abort  = b_bypass.w_header.common4.tlp_abort;
    rcv2rdbuff_dllp_abort = b_bypass.w_header.common4.dllp_abort;
    rcv2rdbuff_ecrc_err   = b_bypass.w_header.common4.ecrc_err;
  end

  
  always_comb begin : push_PROC
    b_push.w_ready = sbc_init_done;
  end

  always_comb begin : timeout_PROC
    rcv2rdbuff_cpl_timeout     = b_timeout.w_hv ;
    rcv2rdbuff_timeout_cpl_tag = b_timeout.w_header.common1.pcieTag ;
  end

  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n)
    if(!b_clk.w_reset_n) begin
      b_ram0.w_addrb <= #`TP '0;
      b_ram0.w_enb   <= #`TP '0;
      b_ram0.w_addra <= #`TP '0;
      b_ram0.w_dina  <= #`TP '0;
      b_ram0.w_ena   <= #`TP '0;
      b_ram0.w_wea   <= #`TP '0;
    end else begin
      b_ram0.w_addrb <= #`TP rdbuff2sram_rd_addr;
      b_ram0.w_enb   <= #`TP rdbuff2sram_rd_en;
      b_ram0.w_addra <= #`TP rdbuff2sram_wr_addr;
      b_ram0.w_dina  <= #`TP rdbuff2sram_wr_data;
      b_ram0.w_ena   <= #`TP rdbuff2sram_wr_en;
      b_ram0.w_wea   <= #`TP rdbuff2sram_wr_en;
    end

  assign sram2rdbuff_rd_data = b_ram0.w_validb ? b_ram0.w_doutb : '0;

  //FIXME: The original readbuffer was badly implemented, without this and no ram pipeline and it does not work.
  //sram2rdbuff_rd_ack  = b_ram0.w_validb;
  assign sram2rdbuff_rd_ack = '1;

  // 
  // segbuff pop asserts the correspondent bit on seg_pkt_avail. But ram write enable
  // is a registred version of segbuff pop, thus we need to register seg_pkt_avail to
  // avoid start reading while data is effectively being written on RAM.
  //
  always @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : proc_seq_sbc2ctrl_seg_pkt_avail
     integer i;
     if (!b_clk.w_reset_n) begin
       sbc2ctrl_seg_pkt_avail_r <= # `TP {NUM_DMA_RD_SEGMENTS{1'b0}};
     end else if (!rawreg2rdctrl_en_true) begin
       sbc2ctrl_seg_pkt_avail_r <= # `TP {NUM_DMA_RD_SEGMENTS{1'b0}};
     end else begin
       sbc2ctrl_seg_pkt_avail_r <= # `TP  sbc2ctrl_seg_pkt_avail;
     end
  end

  assign b_ras.w_ras_dp_err_log     = rdbuff_ras_dp_err_log_core;
  assign rdbuff_ras_dp_err_inj_core = b_ras.w_ras_dp_err_inj;

// SNPS_SysML_CODE_END

endmodule
