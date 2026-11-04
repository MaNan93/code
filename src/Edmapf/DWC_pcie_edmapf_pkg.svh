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
// ---    $Revision: #13 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_pkg.svh#13 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_PKG__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_PKG__SVH__

// SNPS_SysML_CODE_START
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
// SNPS_SysML_CODE_END

package DWC_pcie_edmapf_pkg;

  import DWC_pcie_tlp_pkg::*;

// SNPS_SysML_CODE_START
  localparam              K_DMA_WR_RR_STAGES     = (K_WR_DMACHAN==1) ? 1 : ($clog2(K_WR_DMACHAN)/3 + |($clog2(K_WR_DMACHAN)%3));
  localparam              K_DMA_RD_RR_STAGES     = (K_RD_DMACHAN==1) ? 1 : ($clog2(K_RD_DMACHAN)/3 + |($clog2(K_RD_DMACHAN)%3));
  localparam              K_CRGB_ADDR_WIDTH      = `CC_CRGB_ADDR_WIDTH;
  localparam              K_DMA_WR_LLQ           = `CX_DMA_WR_LLQ;
  localparam              K_DMA_RD_LLQ           = `CX_DMA_RD_LLQ;
  localparam              K_DMA_WR_LLQ_REQ_LAT   = K_DMA_WR_RR_STAGES+10+`CC_IF_WRCTX_LLQ_OVERLAY_RAM_LATENCY;
  localparam              K_DMA_RD_LLQ_REQ_LAT   = K_DMA_RD_RR_STAGES+10+`CC_IF_RDCTX_LLQ_OVERLAY_RAM_LATENCY;
  localparam logic [12:0] K_MSTR_WD_BYTES        = `MASTER_BUS_DATA_WIDTH / 8;
  localparam              K_MSTR_WD_BYTES_WD     = $clog2(K_MSTR_WD_BYTES-1);
  localparam              K_CH_SEP               = `CX_DMAREG_CHADDR_SPACE;
  localparam              K_DMA_WR_LLQWD         = $clog2((K_WR_DMACHAN * K_DMA_WR_LLQ)+1);
  localparam              K_DMA_RD_LLQWD         = $clog2((K_RD_DMACHAN * K_DMA_RD_LLQ)+1);
  localparam              K_DMA_WR_LL_REQ_STAGES = (K_WR_DMACHAN<K_DMA_WR_LLQ_REQ_LAT) ? K_WR_DMACHAN : K_DMA_WR_LLQ_REQ_LAT;
  localparam              K_DMA_RD_LL_REQ_STAGES = (K_RD_DMACHAN<K_DMA_RD_LLQ_REQ_LAT) ? K_RD_DMACHAN : K_DMA_RD_LLQ_REQ_LAT;
  localparam              K_RDBUFFER_RAM_DP      = `CC_DMA_SEG_DEPTH*`CC_NUM_DMA_RD_TAG;
  localparam              K_RDBUFFER_RAM_PW      = $clog2(`CC_DMA_SEG_DEPTH*`CC_NUM_DMA_RD_TAG);
  localparam              K_RDBUFFER_RAM_WD      =  `CC_DMA_SEG_BUF_DATA_WECC_WIDTH;
  localparam              K_RDBUFFER_RAM_WD_NECC =  `CC_DMA_SEG_BUF_DATA_WIDTH;
  localparam              K_RDBUFFER_INT_RAM_WD  = K_RDBUFFER_RAM_WD;
  localparam              K_RDBUFFER_RAM_N       = 1;
  localparam              K_RDBUFFER_RAM_PRW     = `CC_DMA_SEG_BUF_NW_ADDRP_WIDTH;

// SNPS_SysML_CODE_END

  // ##########################################################################
  //                                Enumerations                               
  // ##########################################################################
  typedef enum logic {
     E_FALSE = 0
    ,E_TRUE  = 1
  } bool_e;

  typedef enum logic [1:0] {
     E_CS_RESERVED = 2'b00
    ,E_CS_RUNNING  = 2'b01
    ,E_CS_ABORTED  = 2'b10
    ,E_CS_STOPED   = 2'b11
  } chStatus_e;

  typedef enum logic [1:0] {
     E_FEED_ALL  = 0
    ,E_FEED_HALT = 1
    ,E_FEED_NONE = 2
  } dlyType_e;

  typedef enum logic {
     E_WRITE = 0
    ,E_READ  = 1
  } dmaEngType_e;

  typedef enum logic [3:0] {
     E_DMAERR_NONE             = 4'b0000
    ,E_DMAERR_LL_CPL_UR        = 4'b0001
    ,E_DMAERR_LL_CPL_CA        = 4'b0010
    ,E_DMAERR_LL_CPL_EP        = 4'b0011
    ,E_DMAERR_DATA_CPL_TIMEOUT = 4'b1000
    ,E_DMAERR_DATA_CPL_UR      = 4'b1001
    ,E_DMAERR_DATA_CPL_CA      = 4'b1010
    ,E_DMAERR_DATA_CPL_EP      = 4'b1011
    ,E_DMAERR_DATA_MWR         = 4'b1100
  } dmaErrors_e;

  typedef enum logic {
     E_BRIDGE = 0
    ,E_CORE   = 1
  } dmaTarget_e;

  typedef enum logic [1:0] {
     idle            = 0
    ,setActiveChNum  = 1
    ,rdActiveChNum   = 2
    ,rdDepthFetchMax = 3
  } e_llqRegOp;

  typedef enum logic [1:0] {
     E_CNT_NONE  = 0
    ,E_CNT_INC   = 1
    ,E_CNT_RESET = 2
    ,E_CNT_SET   = 3
  } fetchCounter_e;

  typedef enum logic [1:0] {
     E_ERR_NONE  = 0
    ,E_ERR_RESET = 1
    ,E_ERR_SET   = 2
  } fetchError_e;

  typedef enum logic [1:0] {
     E_STOP_NONE  = 0
    ,E_STOP_SET   = 1
    ,E_STOP_RESET = 2
  } fetchStop_e;

  typedef enum logic [1:0] {
     E_TRGT_NONE = 0
    ,E_TRGT_HEAD = 1
    ,E_TRGT_TAIL = 2
  } fetchTarget_e;

  typedef enum logic [1:0] {
     E_TOKEN_NONE  = 0
    ,E_TOKEN_SET   = 1
    ,E_TOKEN_RESET = 2
  } fetchToken_e;

  typedef enum logic [2:0] {
     E_HDMAREGZONE_LL         = 0
    ,E_HDMAREGZONE_GLOBAL     = 1
    ,E_HDMAREGZONE_OVERLAY    = 2
    ,E_HDMAREGZONE_MSI        = 3
    ,E_HDMAREGZONE_DBMNGR     = 4
    ,E_HDMAREGZONE_HANDSHAKE  = 5
    ,E_HDMAREGZONE_INTERRUPTS = 6
  } hdmaRegZones_e;

  typedef enum logic [7:0] {
     E_HDMAREG_EN                      = 8'h00
    ,E_HDMAREG_DOORBELL                = 8'h04
    ,E_HDMAREG_ELEM_PF                 = 8'h08
    ,E_HDMAREG_HANDSHAKE               = 8'h0C
    ,E_HDMAREG_LLP_LOW                 = 8'h10
    ,E_HDMAREG_LLP_HIGH                = 8'h14
    ,E_HDMAREG_CYCLE                   = 8'h18
    ,E_HDMAREG_XFERSIZE                = 8'h1C
    ,E_HDMAREG_SAR_LOW                 = 8'h20
    ,E_HDMAREG_SAR_HIGH                = 8'h24
    ,E_HDMAREG_DAR_LOW                 = 8'h28
    ,E_HDMAREG_DAR_HIGH                = 8'h2C
    ,E_HDMAREG_WATERMARK_EN            = 8'h30
    ,E_HDMAREG_CONTROL1                = 8'h34
    ,E_HDMAREG_FUNC_NUM                = 8'h38
    ,E_HDMAREG_QOS                     = 8'h3C
    ,E_HDMAREG_STATUS                  = 8'h80
    ,E_HDMAREG_INT_STATUS              = 8'h84
    ,E_HDMAREG_INT_SETUP               = 8'h88
    ,E_HDMAREG_INT_CLEAR               = 8'h8C
    ,E_HDMAREG_MSI_ADDR_STOP_LOW       = 8'h90
    ,E_HDMAREG_MSI_ADDR_STOP_HIGH      = 8'h94
    ,E_HDMAREG_MSI_ADDR_WATERMARK_LOW  = 8'h98
    ,E_HDMAREG_MSI_ADDR_WATERMARK_HIGH = 8'h9C
    ,E_HDMAREG_MSI_ADDR_ABORT_LOW      = 8'hA0
    ,E_HDMAREG_MSI_ADDR_ABORT_HIGH     = 8'hA4
    ,E_HDMAREG_MSI_MSGD                = 8'hA8
  } hdmaRegs_e;

  typedef enum logic [1:0] {
     E_INT_STOP      = 0
    ,E_INT_WATERMARK = 1
    ,E_INT_ABORT     = 2
  } intType_e;

  typedef enum logic [2:0] {
     E_NLL_TRIGGER = 0
    ,E_PUSH        = 1
    ,E_EOT_TOKEN   = 2
    ,E_TRIG_TOKEN  = 3
    ,E_LL_ERR      = 4
    ,E_ERR_TOKEN   = 5
    ,E_LL_END      = 6
    ,E_STSH_LL     = 7
  } llPushOp_e;

  typedef enum logic [1:0] {
     E_TAGMNGR_NORMAL = 0
    ,E_TAGMNGR_LOW    = 1
    ,E_TAGMNGR_VLOW   = 2
  } tagMngrMode_e;

  // ##########################################################################
  //                          Data Structures/Unions                           
  // ##########################################################################
  typedef struct packed {
    logic [K_DMA_RD_LLQWD-1:0] llNslotsReq    ;
    logic [K_DMA_RD_LLQWD-1:0] llNreads       ;
    logic                      llNslotsOutsLst;
    logic [K_DMA_RD_LLQWD-1:0] llNslotsOuts   ;
    logic [K_DMA_RD_LLQWD-1:0] ElPfetch       ;
    logic [K_RD_DMACHANWD-1:0] channel        ;
  } DbMngrRdEng_s;

  typedef struct packed {
    logic                      valid   ;
    logic [K_DMA_RD_LLQWD-1:0] llNslots;
    logic [K_RD_DMACHANWD-1:0] channel ;
    logic                      llDrop  ;
  } DbMngrRemRdEng_s;

  typedef struct packed {
    logic                      valid   ;
    logic [K_DMA_WR_LLQWD-1:0] llNslots;
    logic [K_WR_DMACHANWD-1:0] channel ;
    logic                      llDrop  ;
  } DbMngrRemWrEng_s;

  typedef struct packed {
    logic [K_DMA_WR_LLQWD-1:0] llNslotsReq    ;
    logic [K_DMA_WR_LLQWD-1:0] llNreads       ;
    logic                      llNslotsOutsLst;
    logic [K_DMA_WR_LLQWD-1:0] llNslotsOuts   ;
    logic [K_DMA_WR_LLQWD-1:0] ElPfetch       ;
    logic [K_WR_DMACHANWD-1:0] channel        ;
  } DbMngrWrEng_s;

  typedef struct packed {
    logic        [K_CRGB_ADDR_WIDTH-10:0] chanNumber ;
    dmaEngType_e                          chanType   ;
    hdmaRegs_e                            slot       ;
  } crgbAddr_s;

  typedef struct packed {
    logic        rie          ;
    logic        lie          ;
    logic        llp          ;
    logic [31:0] darHigh      ;
    logic [31:0] darLow       ;
    logic [31:0] sarHigh      ;
    logic [31:0] sarLow       ;
    logic [31:0] xferSize     ;
    logic        ll_laei      ;
    logic        ll_raei      ;
    logic        abort_mask   ;
    logic        done_mask    ;
    logic        ll_err       ;
    logic        ur_err       ;
    logic        ca_err       ;
    logic        to_err       ;
    logic        ep_err       ;
    logic        app_error    ;
    logic        abort        ;
    logic        done         ;
    logic        hs_en        ;
    logic  [5:0] handshake_cnt;
    logic  [7:0] d_vf         ;
    logic        d_vf_en      ;
    logic  [4:0] ch_weight    ;
    logic  [7:0] d_pf         ;
    logic  [1:0] d_ats        ;
    logic  [2:0] d_tc         ;
    logic        d_ro         ;
    logic        d_sn         ;
  } dmaPfCtxReq;

  typedef struct packed {
    logic [K_DMA_RD_LLQWD-1:0] db_llNreads         ;
    logic                      db_llNslotsOutStdLst;
    logic [K_DMA_RD_LLQWD-1:0] db_llNslotsOutStd   ;
    logic               [31:0] stsh_llpHighReg     ;
    logic               [31:0] stsh_llpLowReg      ;
    logic               [31:0] ctx_llpHighReg      ;
    logic               [31:0] ctx_llpLowReg       ;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaRdEng_llRam_s;

  typedef struct packed {
    logic [K_DMA_RD_LLQWD-1:0] db_llNreads         ;
    logic                      db_llNslotsOutStdLst;
    logic [K_DMA_RD_LLQWD-1:0] db_llNslotsOutStd   ;
    logic [K_RD_DMACHANWD-1:0] channel             ;
    logic               [63:0] ctx_ll_ptr          ;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaRdEngllCtxPop_s;

  typedef struct packed {
    logic [K_RD_DMACHANWD-1:0] channel             ;
    logic               [63:0] ctx_ll_ptr          ;
    logic                [6:0] ctx_element_prefetch;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaRdEngllCtxPush_s;

  typedef struct packed {
    logic [K_DMA_WR_LLQWD-1:0] db_llNreads         ;
    logic                      db_llNslotsOutStdLst;
    logic [K_DMA_WR_LLQWD-1:0] db_llNslotsOutStd   ;
    logic               [31:0] stsh_llpHighReg     ;
    logic               [31:0] stsh_llpLowReg      ;
    logic               [31:0] ctx_llpHighReg      ;
    logic               [31:0] ctx_llpLowReg       ;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaWrEng_llRam_s;

  typedef struct packed {
    logic [K_DMA_WR_LLQWD-1:0] db_llNreads         ;
    logic                      db_llNslotsOutStdLst;
    logic [K_DMA_WR_LLQWD-1:0] db_llNslotsOutStd   ;
    logic [K_WR_DMACHANWD-1:0] channel             ;
    logic               [63:0] ctx_ll_ptr          ;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaWrEngllCtxPop_s;

  typedef struct packed {
    logic [K_WR_DMACHANWD-1:0] channel             ;
    logic               [63:0] ctx_ll_ptr          ;
    logic                [6:0] ctx_element_prefetch;
    logic                      ctx_pfo             ;
    logic                      ctx_ccs             ;
    logic                      ctx_Cb              ;
  } dmaWrEngllCtxPush_s;

  typedef struct packed {
    fetchStop_e     stop   ;
    fetchToken_e    token  ;
    fetchError_e    errors ;
    fetchCounter_e  counter;
    fetchTarget_e   target ;
  } fetchOpMode_s;

  typedef struct packed {
    logic  lie;
    logic  rie;
  } intEn_s;

  typedef struct packed {
    logic  abort    ;
    logic  watermark;
    logic  stop     ;
  } intTypes_s;

  typedef struct packed {
    dmaErrors_e  errors  ;
    intTypes_s   pins    ;
    intEn_s      abortEn ;
    intEn_s      stopEn  ;
    intTypes_s   masks   ;
    intTypes_s   clears  ;
    chStatus_e   chStatus;
    logic        chEnable;
  } interruptsRd_s;

  typedef struct packed {
    dmaErrors_e  errors  ;
    intTypes_s   pins    ;
    intEn_s      abortEn ;
    intEn_s      stopEn  ;
    intTypes_s   masks   ;
    intTypes_s   clears  ;
    chStatus_e   chStatus;
    logic        chEnable;
  } interruptsWr_s;

  typedef struct packed {
    logic    abort     ;
    logic    stop      ;
    intEn_s  abortIntEn;
    intEn_s  stopIntEn ;
    logic    abort_msk ;
    logic    stop_msk  ;
    logic    abort_clr ;
    logic    stop_clr  ;
  } interrupts_s;

  typedef struct packed {
    logic   [6:0] elemPf     ;
    bool_e        pfOvrl     ;
    logic         ccs        ;
    logic         cb         ;
    logic  [31:0] elemPtrHigh;
    logic  [31:0] elemPtrLow ;
  } llData_s;

  typedef struct packed {
    logic [15:0] msgd          ;
    logic [63:0] abort_addr    ;
    logic [63:0] watermark_addr;
    logic [63:0] stop_addr     ;
  } msiInfo_s;

  typedef struct packed {
    intEn_s        watermarkEn;
    logic   [31:0] darHigh    ;
    logic   [31:0] darLow     ;
    logic   [31:0] sarHigh    ;
    logic   [31:0] sarLow     ;
    logic   [31:0] xferSize   ;
  } ovrlData_s;

  typedef struct packed {
    logic  t_bit_src;
    logic  t_bit    ;
  } t_bit_s;

  typedef struct packed {
    logic [2:0] d_tc     ;
    logic [7:0] d_vf     ;
    logic       d_vf_en  ;
    logic [7:0] d_pf     ;
    logic [7:0] d_st     ;
    logic [1:0] d_ph     ;
    logic       d_th     ;
    logic   [1:0] d_ats  ;
    logic         d_ro   ;
    logic         d_sn   ;
    logic         s_sn   ;
    logic         mtype  ;
  } tlpCtxSettings_s;

  typedef struct packed {
    intTypes_s  interrupt  ;
    logic       xferPending;
    logic       enabled    ;
  } chStatus_s;

  typedef struct packed {
    dmaErrors_e  errors  ;
    logic        token   ;
    logic        stop    ;
    llData_s     llData  ;
    ovrlData_s   ovrlData;
  } elemCtxRd_s;

  typedef struct packed {
    dmaErrors_e  errors  ;
    logic        token   ;
    logic        stop    ;
    llData_s     llData  ;
    ovrlData_s   ovrlData;
  } elemCtxWr_s;

  typedef struct packed {
    llData_s    llData  ;
    ovrlData_s  ovrlData;
  } fetchQ_s;

  typedef struct packed {
    logic            [9:0] pf_depth   ;
    logic            [4:0] weight     ;
    tlpCtxSettings_s       tlpSettings;
    logic                  ll_en      ;
  } glbData_s;

  typedef struct packed {
    logic       [K_RD_DMACHANWD-1:0] channel;
    elemCtxRd_s                      ovrl   ;
  } rdEngNarrowPipe_s;

  typedef struct packed {
    glbData_s                           globalCtx  ;
    logic          [K_RD_DMACHANWD-1:0] channel    ;
    intEn_s                             watermarkEn;
    interruptsRd_s                      interrupts ;
  } stshPipeRd_s;

  typedef struct packed {
    glbData_s                           globalCtx  ;
    logic          [K_WR_DMACHANWD-1:0] channel    ;
    intEn_s                             watermarkEn;
    interruptsWr_s                      interrupts ;
  } stshPipeWr_s;

  typedef struct packed {
    logic       [K_WR_DMACHANWD-1:0] channel;
    elemCtxWr_s                      ovrl   ;
  } wrEngNarrowPipe_s;

  typedef struct packed {
    elemCtxRd_s  ovrl;
    glbData_s    glb ;
  } fullCtxRd_s;

  typedef struct packed {
    elemCtxWr_s  ovrl;
    glbData_s    glb ;
  } fullCtxWr_s;

  typedef struct packed {
    fullCtxRd_s                      ctx    ;
    logic       [K_RD_DMACHANWD-1:0] channel;
  } dmaRdEngCtx_s;

  typedef struct packed {
    logic                            stop        ;
    logic                            last        ;
    logic                            flush       ;
    bool_e                           ElemOvrl_TCB;
    bool_e                           ElemOvrl_LLP;
    logic                            desc_valid  ;
    llPushOp_e                       pushOp      ;
    fullCtxRd_s                      ctxElem     ;
    logic       [K_RD_DMACHANWD-1:0] reqCh       ;
  } dmaRdEng_llPush_s;

  typedef struct packed {
    logic       [K_RD_DMACHANWD-1:0] reqCh  ;
    llPushOp_e                       pushOp ;
    fullCtxRd_s                      ctxElem;
  } dmaRdEng_llq_push_s;

  typedef struct packed {
    dmaRdEngCtx_s  ctx   ;
    xradm_s        header;
  } dmaTlpCtxRd_s;

  typedef struct packed {
    fullCtxWr_s                      ctx    ;
    logic       [K_WR_DMACHANWD-1:0] channel;
  } dmaWrEngCtx_s;

  typedef struct packed {
    logic                            stop        ;
    logic                            last        ;
    logic                            flush       ;
    bool_e                           ElemOvrl_TCB;
    bool_e                           ElemOvrl_LLP;
    logic                            desc_valid  ;
    llPushOp_e                       pushOp      ;
    fullCtxWr_s                      ctxElem     ;
    logic       [K_WR_DMACHANWD-1:0] reqCh       ;
  } dmaWrEng_llPush_s;

  typedef struct packed {
    logic       [K_WR_DMACHANWD-1:0] reqCh  ;
    llPushOp_e                       pushOp ;
    fullCtxWr_s                      ctxElem;
  } dmaWrEng_llq_push_s;

  typedef struct packed {
    dmaWrEngCtx_s  ctx   ;
    xradm_s        header;
  } dmaTlpCtxWr_s;

// SNPS_SysML_CODE_START
   // type alias used by doorbell manager module to store el_prefetch value
   typedef logic [K_WR_DMACHAN-1:0] [K_DMA_WR_LLQWD-1:0] DbMngrWrElPfetch_t;
   typedef logic [K_RD_DMACHAN-1:0] [K_DMA_RD_LLQWD-1:0] DbMngrRdElPfetch_t;
   //*********************************************************
   //** Calculates the next TLP MRD maximum request size
   //** Based on core configuration per function
   //********************************************************
   localparam K_MAX_MTU_PW = `CX_MAX_MTU_PW;
   localparam K_NFUNC      = `CX_NFUNC;     
   
   function automatic [12:0] 
     dmactrl_max_pload_calc(
                            input logic                    WRITE_CH_NOT_READ_CH, //Are we doing a write or a read channel
                            input logic [7:0]              pf, //Current physical function
                            input logic [(3*K_NFUNC)-1:0] cfg_max_payload_size,
                            input logic [(3*K_NFUNC)-1:0] cfg_max_rd_req_size,
                            input logic [2:0]              cfg_remote_rd_req_bridge_size
                            );
      
      begin : func_dmactrl_max_pload_calc
         integer a, b;
         reg [2:0] pcie_func_payload_size;
         reg [2:0] pcie_func_max_rd_req_size;
         reg [2:0] max_ch_payload_size;
         
         logic [2:0] MAX_MTU_PW_MINUS_7;

         MAX_MTU_PW_MINUS_7 = K_MAX_MTU_PW - 7;
         
         pcie_func_payload_size   = 3'd0;
         pcie_func_max_rd_req_size = 3'd0;
         
         // Assign maxpayload size according Function Number
         // Assign max rd req size according Function Number
         for(a=0; a<K_NFUNC; a=a+1)
           if(pf == a)
             for(b=0; b<3; b=b+1) begin
                pcie_func_payload_size[b]    = cfg_max_payload_size[3*a+b];
                pcie_func_max_rd_req_size[b] = cfg_max_rd_req_size[3*a+b];
             end
         
         
         
         //If read channel consider just the MTU
         if (!WRITE_CH_NOT_READ_CH) begin
            pcie_func_payload_size[2:0] = MAX_MTU_PW_MINUS_7 ;
         end
         
         // Inbound requests: Compare read bridge size with max payload size -> to avoid multiple completions during decomposition, the minor size must be used
         // Outbound requests: Compare max read request size with max payload size -> to avoid overflow on buffer in readbuffer block, the minor size must be used
         
         max_ch_payload_size = (WRITE_CH_NOT_READ_CH) ?
                               (cfg_remote_rd_req_bridge_size < pcie_func_payload_size ? cfg_remote_rd_req_bridge_size : pcie_func_payload_size) :
                               (pcie_func_max_rd_req_size     < pcie_func_payload_size ? pcie_func_max_rd_req_size     : pcie_func_payload_size);
         
         case (max_ch_payload_size)
           // ccx_line_begin: u_edma_ctrl_tlptf,u_edma_cpld2mwr; REDUNDANT_CONFIG_ONLY, MAX MTU
           3'b000:  dmactrl_max_pload_calc  = 128;
           3'b001:  dmactrl_max_pload_calc  = 256;
           3'b010:  dmactrl_max_pload_calc  = 512;
           3'b011:  dmactrl_max_pload_calc  = 1024;
           3'b100:  dmactrl_max_pload_calc  = 2048;
           3'b101:  dmactrl_max_pload_calc  = 4096;
           default: dmactrl_max_pload_calc  = 128;
           // ccx_line_end
         endcase
         
      end
   endfunction // dmactrl_max_pload_calc


   //*********************************************************
   //** Calculates the next TLP MRD request size
   //** taking in consideration the request transfer size
   //** and PCIe 4K boundaries
   //********************************************************
   function automatic [31:0] dmactrl_4k_byte_calc;
      
      input [11:0] tlp_daddr;          //TLP Transaction address where the 4K check must be carried out
      input [1:0]  tlp_saddr;          // Source Address need to unaligned
      input [12:0] tlp_cfg_pload_size;//Configured xfer payload size
      input [31:0] xact_xfer_size;    //Transaction transfer size set up by the application
      
      begin : func_dmactrl_4k_byte_calc
         reg [12:0] bytes2nxt_pboundary;
         reg        addrcross_pboundary_i;
         reg [12:0] bytes2nxt_max_pboundary_i;
         reg [12:0] bytes2nxt_4kpboundary_i;
         reg [31:0] dmactrl_4k_byte_calc_aux;
         
         
         // Calculate the number of bytes from DAR to the next MTU boundary (WRITE/READ CHANNEL)
         // Distance to MTU boundary is MTU minus adress masked by  ~(12'b0 - tlp_cfg_pload_size)
         bytes2nxt_pboundary =  ~(12'b0 - tlp_cfg_pload_size) & (tlp_cfg_pload_size - tlp_daddr);
         
         // Calculate the number of bytes from DAR to the next 4K page boundary (WRITE/READ CHANNEL)
         bytes2nxt_4kpboundary_i = (13'h1000 - tlp_daddr[11:0]);
         
         // Detect if we have transfer size greater to the distance to 4K boundary cross
         addrcross_pboundary_i = (xact_xfer_size > {19'd0, bytes2nxt_4kpboundary_i});
         
         // Number of bytes according transfer size and address not aligned
         if ((xact_xfer_size + tlp_daddr[1:0]) < {19'd0, tlp_cfg_pload_size}) begin
            if (addrcross_pboundary_i)
              dmactrl_4k_byte_calc_aux = {19'd0, bytes2nxt_4kpboundary_i};
            else
              dmactrl_4k_byte_calc_aux = xact_xfer_size;
         end
         else begin
            if (bytes2nxt_pboundary != 13'h0)
              dmactrl_4k_byte_calc_aux = {19'd0, bytes2nxt_pboundary};
            else
              dmactrl_4k_byte_calc_aux = {19'd0, tlp_cfg_pload_size};
         end
         
         // Number of bytes according transfer size and address not aligned
         // When SAR is not aligned the DWORD LENGTH must be MAXT_MTU - 1 DWORD
         // to prevent split completions from the bridge
         if ((dmactrl_4k_byte_calc_aux + tlp_saddr[1:0]) > {19'd0, tlp_cfg_pload_size})
           // ccx_line: u_DWC_pcie_edma.u_edma_cpld2mwr,u_edma_wrctrl.u_edma_ctrl_tlptf ; STIMULUS: Verification hole due to insufficient randomization. Covered on coverage database. Testbench needs to be improved to be always covered.
           dmactrl_4k_byte_calc = {19'd0, tlp_cfg_pload_size} - {30'd0, tlp_saddr[1:0]};
         else
           dmactrl_4k_byte_calc = dmactrl_4k_byte_calc_aux;
         
      end
   endfunction
   
   
   //*********************************************************
   // WRITE CHANNEL: Calculates the TLP MRd (DMA -> Bridge)
   // request size, taking in consideration the request
   // transfer size, MAX_MTU and SAR
   //********************************************************
   function automatic [31:0] dmactrl_wrch_byte_calc;

      input [11:0] tlp_sar;            // TLP SAR
      input [12:0] tlp_cfg_pload_size; // Configured MAX_MTU
      input [31:0] xact_xfer_size;     // Transaction transfer size set up by the application
      
      begin : func_dmactrl_wrch_byte_calc
         // Number of bytes according transfer size and address not aligned
         // When SAR is not aligned the DWORD LENGTH must be MAXT_MTU - 1 DWORD
         // to prevent split completions from the bridge
         if ((xact_xfer_size + tlp_sar[1:0]) <= {19'd0, tlp_cfg_pload_size})
           dmactrl_wrch_byte_calc = xact_xfer_size;
         else
           dmactrl_wrch_byte_calc = {19'd0, tlp_cfg_pload_size} - ({30'd0, tlp_sar[1:0]});
      end
   endfunction
   
   //*********************************************************
   // READ CHANNEL: Calculates the TLP MRd (DMA -> Core)
   // request size, taking in consideration the request
   // transfer size, MAX_MTU and SAR
   //********************************************************
   function automatic [31:0] dmactrl_rdch_byte_calc;

      input [11:0] tlp_addr;          //TLP Transaction address where the 4K check must be carried out
      input [1:0]  tlp_dar_addr;
      input [12:0] tlp_cfg_pload_size;//Configured xfer payload size
      input [31:0] xact_xfer_size;    //Transaction transfer size set up by the application
      
      begin : func_dmactrl_rdch_byte_calc
         reg [12:0] bytes2nxt_pboundary;
         reg        addrcross_pboundary_i;
         reg [12:0] bytes2nxt_max_pboundary_i;
         reg [12:0] bytes2nxt_4kpboundary_i;
         reg [31:0] dmactrl_byte_calc_i;

         
         // Calculate the number of bytes from DAR to the next MTU boundary (WRITE/READ CHANNEL)
         // Distance to MTU boundary is MTU minus adress masked by  ~(12'b0 - tlp_cfg_pload_size)
         bytes2nxt_pboundary =  ~(12'b0 - tlp_cfg_pload_size) & (tlp_cfg_pload_size - tlp_addr);
         
         // Calculate the number of bytes from DAR to the next 4K page boundary (WRITE/READ CHANNEL)
         bytes2nxt_4kpboundary_i = (13'h1000 - tlp_addr[11:0]);

         // Detect if we have transfer size greater to the distance to 4K boundary cross
         addrcross_pboundary_i = (xact_xfer_size > {19'd0, bytes2nxt_4kpboundary_i});
         
         // Number of bytes according transfer size and address not aligned
         if ((xact_xfer_size + tlp_addr[1:0]) <= {19'd0, tlp_cfg_pload_size}) begin
            if (addrcross_pboundary_i)
              dmactrl_byte_calc_i = {19'd0, bytes2nxt_4kpboundary_i};
            else
              dmactrl_byte_calc_i = xact_xfer_size;
         end
         else begin
            if (bytes2nxt_pboundary != 13'h0)
              dmactrl_byte_calc_i = {19'd0, bytes2nxt_pboundary};
            else begin
               dmactrl_byte_calc_i = {19'd0, tlp_cfg_pload_size};
            end
         end
         
         if (dmactrl_byte_calc_i + {30'd0, tlp_dar_addr[1:0]} > 4096)
           // ccx_line:u_edma_rdbuff.u_edma_cpld2mwr,u_edma_rdctrl.u_edma_ctrl_tlptf; REDUNDANT_CONFIG_ONLY, MAX MTU
           dmactrl_rdch_byte_calc = {20'd0, (12'd2048 - {1'b0, tlp_addr[10:0]})};
         else
           dmactrl_rdch_byte_calc = dmactrl_byte_calc_i;
         
      end
   endfunction
   

   //*********************************************************
   //** Calculates the next TLP MRD request size
   //** taking in consideration the request transfer size,
   //** PCIe 4K boundaries and DAR not aligned to the DWORD
   //********************************************************
   function automatic [31:0] dmactrl_byte_calc;
      
      input [11:0] tlp_dar;
      input [11:0] tlp_addr;          //TLP Transaction address where the 4K check must be carried out
      input [12:0] tlp_cfg_pload_size;//Configured xfer payload size
      input [31:0] xact_xfer_size;    //Transaction transfer size set up by the application
      
      begin : func_dmactrl_byte_calc
         reg [12:0] bytes2nxt_pboundary_i;
         reg        addrcross_pboundary_i;
         reg [12:0] bytes2nxt_max_pboundary_i;
         
         dmactrl_byte_calc = 32'd0; // Initial value
         //Check if DAR is not aligned to the DWORD
         if (|tlp_dar[1:0]) begin
            if (tlp_dar[1:0] == 2'b01)
              dmactrl_byte_calc = 32'd3;
            else begin
               if (tlp_dar[1:0] == 2'b10)
                 dmactrl_byte_calc = 32'd2;
               else begin
                  if (tlp_dar[1:0] == 2'b11)
                    dmactrl_byte_calc = 32'd1;
               end
            end
         end
         else begin
            // Calculate the number of bytes from DAR to the next 4K page boundary (WRITE/READ CHANNEL)
            bytes2nxt_pboundary_i = (13'h1000 - tlp_addr[11:0]);
            
            // The number of bytes from DAR to the next MAX PAYLOAD BOUNDARY
            bytes2nxt_max_pboundary_i = |(bytes2nxt_pboundary_i & (tlp_cfg_pload_size - 1)) ? (bytes2nxt_pboundary_i & (tlp_cfg_pload_size - 1)) :
                                        tlp_cfg_pload_size;
            // Detect if we have  4K boundary cross
            addrcross_pboundary_i = |(bytes2nxt_pboundary_i) ? (xact_xfer_size > {19'd0, bytes2nxt_pboundary_i}) : 0;
            
            // To calculate the number of bytes for the first read request:
            if (xact_xfer_size < {19'd0, tlp_cfg_pload_size})
              if (addrcross_pboundary_i) dmactrl_byte_calc  = {19'd0, bytes2nxt_pboundary_i};
              else                       dmactrl_byte_calc  = xact_xfer_size;
            else begin
               if ({19'd0, bytes2nxt_pboundary_i} > xact_xfer_size)
                 dmactrl_byte_calc = {19'd0, tlp_cfg_pload_size};
               else
                 dmactrl_byte_calc = {19'd0, bytes2nxt_max_pboundary_i};
            end
         end
      end
   endfunction
   

   
   //*********************************************************
   //** Check if request cross the PCIe 4K boudary
   //********************************************************
   function automatic dmactrl_addrcross_pboundary;
      
      input [11:0] tlp_addr;          //TLP Transaction address where the 4K check must be carried out
      input [12:0] tlp_cfg_pload_size;//Configured xfer payload size
      input [31:0] xact_xfer_size;    //Transaction transfer size set up by the application
      
      begin : func_dmactrl_addrcross_pboundary
         reg [12:0] bytes2nxt_pboundary_i;
         reg        addrcross_pboundary_i;
         reg [12:0] bytes2nxt_max_pboundary_i;
         
         
         // Calculate the number of bytes from DAR to the next 4K page boundary (WRITE/READ CHANNEL)
         bytes2nxt_pboundary_i = (13'h1000 - tlp_addr[11:0]);
         
         // Detect if we have  4K boundary cross
         dmactrl_addrcross_pboundary = |(bytes2nxt_pboundary_i) ? ((xact_xfer_size > {19'd0, bytes2nxt_pboundary_i}) && (tlp_cfg_pload_size > bytes2nxt_pboundary_i)) : 0;
         
      end
   endfunction

   //*********************************************************
   //** Calculates the next TLP MRD request size
   //** taking in consideration the request transfer size
   //** and PCIe 4K boundaries
   //********************************************************
   function automatic [31:0] dmactrl_4k_byte_calc_nba;
      
      input [11:0]  tlp_addr;          //TLP Transaction address where the 4K check must be carried out
      input [12:0]  tlp_cfg_pload_size;//Configured xfer payload size
      input [31:0]  xact_xfer_size;    //Transaction transfer size set up by the application
      
      begin : func_dmactrl_4k_byte_calc
         reg [12:0] bytes2nxt_pboundary_i;
         reg        addrcross_pboundary_i;
         reg [12:0] bytes2nxt_max_pboundary_i;
         
         
         // Calculate the number of bytes from DAR to the next 4K page boundary (WRITE/READ CHANNEL)
         bytes2nxt_pboundary_i = (13'h1000 - tlp_addr[11:0]);
         
         // The number of bytes from DAR to the next MAX PAYLOAD BOUNDARY
         bytes2nxt_max_pboundary_i = |(bytes2nxt_pboundary_i & (tlp_cfg_pload_size - 1)) ? (bytes2nxt_pboundary_i & (tlp_cfg_pload_size - 1)) :
                                     tlp_cfg_pload_size;
         // Detect if we have  4K boundary cross
         addrcross_pboundary_i = |(bytes2nxt_pboundary_i) ? (xact_xfer_size > {19'd0, bytes2nxt_pboundary_i}) : 1'b0;
         
         // To calculate the number of bytes for the first read request:
         if (xact_xfer_size < {19'd0, tlp_cfg_pload_size})
           if (addrcross_pboundary_i) dmactrl_4k_byte_calc_nba  = {19'd0, bytes2nxt_pboundary_i};
           else                       dmactrl_4k_byte_calc_nba  = xact_xfer_size;
         else begin
            if ({19'd0, bytes2nxt_pboundary_i} > xact_xfer_size)
              dmactrl_4k_byte_calc_nba = {19'd0, tlp_cfg_pload_size};
            else
              dmactrl_4k_byte_calc_nba = {19'd0, bytes2nxt_max_pboundary_i};
         end
      end
   endfunction

    // ##########################################################################
   // Calculates DMA's next TLP size
   // ##########################################################################
   
   function automatic logic [7:0] dma_byte_enables
     (
      input logic [31:0] addressLow,
      input logic [31:0] payloadSize
    );
    logic [3:0]  s_last_be;
    logic [3:0]  s_first_be;
    logic [3:0]  aux_last_byte_en;
    logic [3:0]  aux_first_byte_en;

    // Calculates the first DW enable
    if (payloadSize >= 32'd4) begin
      case(addressLow[1:0])
        2'b00:   s_first_be = 4'b1111;
        2'b01:   s_first_be = 4'b1110;
        2'b10:   s_first_be = 4'b1100;
        default: s_first_be = 4'b1000;
      endcase
    end else if (payloadSize > '0) begin
      case (payloadSize[1:0])
        // Zero case is unreachable in this branch
        default: aux_first_byte_en = 4'b0111;
        2'b01:   aux_first_byte_en = 4'b0001;
        2'b10:   aux_first_byte_en = 4'b0011;
      endcase
      case(addressLow[1:0])
        2'b00:   s_first_be = aux_first_byte_en;
        2'b01:   s_first_be = {aux_first_byte_en[2:0], 1'd0};
        2'b10:   s_first_be = {aux_first_byte_en[1:0], 2'd0};
        default: s_first_be = {aux_first_byte_en[0]  , 3'd0};
      endcase
    end else begin// zero case
      s_first_be = '0;
    end

    // Calculates the last DW enable

    if (payloadSize > 4) begin
      aux_last_byte_en = {2'd0, addressLow[1:0]} + {2'd0, payloadSize[1:0]};
      case (aux_last_byte_en[1:0])
        2'b00: s_last_be    = 4'b1111;
        2'b01: s_last_be    = 4'b0001;
        2'b10: s_last_be    = 4'b0011;
        //11
        default: s_last_be = 4'b0111;
      endcase // case (aux_last_byte_en)
    end else if (payloadSize > 0) begin
      aux_last_byte_en = {2'd0, addressLow[1:0]} + {1'b0, payloadSize[2:0]};
      case (aux_last_byte_en)
        4'b0000: s_last_be    = 4'b0000;
        4'b0001: s_last_be    = 4'b0000;
        4'b0010: s_last_be    = 4'b0000;
        4'b0011: s_last_be    = 4'b0000;
        4'b0100: s_last_be    = 4'b0000;
        4'b0101: s_last_be    = 4'b0001;
        4'b0110: s_last_be    = 4'b0011;
        //1111
        default: s_last_be = 4'b0111;
      endcase // case (aux_last_byte_en)
    end else begin //Zero transfer
      aux_last_byte_en = '0;
      s_last_be = '0;
    end

   return {s_last_be, s_first_be};

   endfunction : dma_byte_enables

   // ##########################################################################
   // Calculates DMA's next TLP size
   // ##########################################################################
   
   function automatic logic [31:0] dma_xferSize_calc
     (
      // Design parameterization
      input logic        WRITE_CH_NOT_READ_CH,
      // Design function configuration
      input logic [12:0] mtu,
      // channel context data
      input logic [63:0] ctrl_ch_dar_ptr,
      input logic [63:0] ctrl_ch_sar_ptr,
      input logic [31:0] ctrl_ch_xfersize
      
      );
      
      logic [12:0]      bytes2transfer;
      logic [12:0]      bytes2alignAppAddress;
      logic [12:0]      bytes2cross4kWire;
      logic [12:0]      bytes2cross4kApp;
      logic [63:0]      appAddress;
      logic [63:0]      wireAddress;

      if (WRITE_CH_NOT_READ_CH) begin
        appAddress = ctrl_ch_sar_ptr;
        wireAddress = ctrl_ch_dar_ptr;
      end else begin
        appAddress = ctrl_ch_dar_ptr;
        wireAddress = ctrl_ch_sar_ptr;
      end

      bytes2alignAppAddress  = 13'(mtu - (13)'(appAddress[K_MSTR_WD_BYTES_WD-1:0]));
      bytes2cross4kWire      = (13'h1000 - (13)'(wireAddress[11:0]));
      bytes2cross4kApp       = (13'h1000 - (13)'(appAddress[11:0]));
      
     if(ctrl_ch_xfersize > 32'(mtu) - 32'(appAddress[1:0])) begin
       if(bytes2alignAppAddress > bytes2cross4kApp) begin
         bytes2transfer = bytes2cross4kApp;
       end else begin
         bytes2transfer = bytes2alignAppAddress;
       end
     end else begin
       if(ctrl_ch_xfersize > 32'(bytes2cross4kApp)) begin
         bytes2transfer = bytes2cross4kApp;
       end else begin
         bytes2transfer = 13'(ctrl_ch_xfersize);
       end
     end

      if (bytes2transfer > mtu - (13)'(wireAddress[1:0])) begin
        if (mtu == 13'd128 && K_MSTR_WD_BYTES == 13'd128) begin
          bytes2transfer = 13'(mtu - (13)'(appAddress[1:0]) - 13'd4);
        end else begin
          bytes2transfer = mtu - (13)'(appAddress[1:0]) - K_MSTR_WD_BYTES;
        end 
      end

      if (bytes2transfer > bytes2cross4kWire) begin
        bytes2transfer = bytes2cross4kWire;
      end

      return 32'(bytes2transfer);
   endfunction : dma_xferSize_calc
   
   // ##########################################################################
   // Calculates DMA's next TLP size
   // ##########################################################################
  
   function automatic logic [31:0] dma_fetch_tlp_calc_size
     (
      // Design parameterization
      input logic                    WRITE_CH_NOT_READ_CH,
      // Design function configuration
      input logic [(3*K_NFUNC)-1:0] cfg_max_payload_size,
      input logic [(3*K_NFUNC)-1:0] cfg_max_rd_req_size,
      input logic [2:0]              cfg_remote_rd_req_bridge_size,
      // channel context data
      input logic [7:0]              pf, // physical function
      input logic [63:0]             ctrl_ch_dar_ptr,
      input logic [63:0]             ctrl_ch_sar_ptr,
      input logic [31:0]             ctrl_ch_xfersize
      
      );

      logic [12:0]      mtu;

      mtu
        = dmactrl_max_pload_calc(
                                 .WRITE_CH_NOT_READ_CH         (WRITE_CH_NOT_READ_CH         ),
                                 .pf                           (pf                           ), 
                                 .cfg_max_payload_size         (cfg_max_payload_size         ),
                                 .cfg_max_rd_req_size          (cfg_max_rd_req_size          ),
                                 .cfg_remote_rd_req_bridge_size(cfg_remote_rd_req_bridge_size)
                                 );

      return dma_xferSize_calc(
                               .WRITE_CH_NOT_READ_CH (WRITE_CH_NOT_READ_CH),
                               .mtu                  (mtu                 ),
                               .ctrl_ch_dar_ptr      (ctrl_ch_dar_ptr     ),
                               .ctrl_ch_sar_ptr      (ctrl_ch_sar_ptr     ),
                               .ctrl_ch_xfersize     (ctrl_ch_xfersize    )
                              );
 
   endfunction : dma_fetch_tlp_calc_size

   // function to calculate the number of ones on a logic array
   function automatic logic [$clog2(`CX_NW):0] TlpCountDWRD_f(
     input logic [`CX_NW-1:0] b_dwen
     );
     logic [$clog2(`CX_NW):0] countOnes;

     countOnes = '0;
     foreach (b_dwen[i])
       if (b_dwen[i])
         countOnes++;

     TlpCountDWRD_f = countOnes;
   endfunction                
   
// SNPS_SysML_CODE_END

endpackage

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

`endif // __GUARD__DWC_PCIE_EDMAPF_PKG__SVH__

