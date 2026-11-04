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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_mstr_pkg.svh#10 $
// -------------------------------------------------------------------------
// --- Description: AXI Master Interface Package
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_AXI_MSTR_PKG__SVH__
`define __GUARD__DWC_PCIE_AXI_MSTR_PKG__SVH__

package DWC_pcie_axi_mstr_pkg;

// SNPS_SysML_CODE_START
  localparam MSTR_AW_EXTRA_PYLD_WIDTH     = `CC_MSTR_AW_EXTRA_PYLD_WIDTH;
  localparam MSTR_AR_EXTRA_PYLD_WIDTH     = `CC_MSTR_AR_EXTRA_PYLD_WIDTH;
  localparam MSTR_R_EXTRA_PYLD_WIDTH      = `CC_MSTR_R_EXTRA_PYLD_WIDTH ;
  localparam MSTR_B_EXTRA_PYLD_WIDTH      = `CC_MSTR_B_EXTRA_PYLD_WIDTH ;

  localparam MSTR_AW_EXTRA_PYLD_PAR_WIDTH = `CC_MSTR_AW_EXTRA_PYLD_PAR_WIDTH;
  localparam MSTR_AR_EXTRA_PYLD_PAR_WIDTH = `CC_MSTR_AR_EXTRA_PYLD_PAR_WIDTH;
  localparam MSTR_R_EXTRA_PYLD_PAR_WIDTH  = `CC_MSTR_R_EXTRA_PYLD_PAR_WIDTH ;
  localparam MSTR_B_EXTRA_PYLD_PAR_WIDTH  = `CC_MSTR_B_EXTRA_PYLD_PAR_WIDTH ;

  localparam MSTR_AW_USER_SIZE            = `CC_MSTR_AW_USER_WIDTH;
  localparam MSTR_W_USER_SIZE             = `CC_MSTR_W_USER_WIDTH ;
  localparam MSTR_AR_USER_SIZE            = `CC_MSTR_AR_USER_WIDTH;
  localparam MSTR_R_USER_SIZE             = `CC_MSTR_R_USER_WIDTH ;
  localparam MSTR_B_USER_SIZE             = `CC_MSTR_B_USER_WIDTH ;

  localparam NFUNC_WD                     = `CX_NFUNC_WD              ;
  localparam NVFUNC_WD                    = `CX_NVFUNC_WD             ;
  localparam NUM_DMA_RD_CHAN_WIDTH        = `CC_NUM_DMA_RD_CHAN_WIDTH ;
  localparam DMA_TYPE_WIDTH               = `DC_DMA_TYPE_WIDTH        ;
  localparam NPRFX                        = `CX_NPRFX                 ;

  localparam MAX_MSTR_TAG                 = `CC_MSTR_BUS_ID_WIDTH     ;

 // `ifdef CX_ATOMIC_ENABLE
 // localparam MAX_MSTR_TAG                 = `CC_MAX_MSTR_TAG_PW + 1   ;
 // `else // !CX_ATOMIC_ENABLE
 // localparam MAX_MSTR_TAG                 = `CC_MAX_MSTR_TAG_PW       ;
 // `endif // CX_ATOMIC_ENABLE

  localparam MSTR_BURST_LEN_PW            = `CC_MSTR_BURST_LEN_PW     ;
  localparam AXI_LOCK_WIDTH               = `CC_AXI_LOCK_WIDTH        ;
  localparam MSTR_MISC_INFO_PWD           = `MSTR_MISC_INFO_PW        ;
  localparam MSTR_BUS_WSTRB_WIDTH         = `CC_MSTR_BUS_WSTRB_WIDTH  ;
  localparam NUM_DMA_MAX_CHAN_WIDTH       = `CC_NUM_DMA_MAX_CHAN_WIDTH;
  localparam MSTR_RESP_MISC_INFO_PWD      = `MSTR_RESP_MISC_INFO_PW   ;
// SNPS_SysML_CODE_END
  localparam AXI_MSTR_AMBA_PAR_LOG_WD = 13;


//----------------------------------------------------------------------\\
//------------------------------AW CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic                                last_dcmp_tlp;
    logic [63:0]                         hdr_34dw;
    logic                                nw;
    logic                                cxlsrc;
    logic [1:0]                          ats;
    logic                                ep;
    logic [NUM_DMA_RD_CHAN_WIDTH
          +DMA_TYPE_WIDTH-1:0]           dma;
    logic [(32*NPRFX) -1:0]              tlpprfx;
    logic [10:0]                         tph;
    logic                                ido;
    logic [8:0]                          req_segment;
    logic [8:0]                          dst_segment;
  } pkg_axi_mstr_awmisc_info_s;


  typedef struct packed {
    logic [MAX_MSTR_TAG -1:0]            id;
    logic                                valid;
    logic [MSTR_BURST_LEN_PW -1:0]       len;
    logic [2:0]                          size;
    logic [1:0]                          burst;
    logic [AXI_LOCK_WIDTH-1:0]           lock;
    logic [3:0]                          cache;
    logic [2:0]                          prot;
    logic [MSTR_MISC_INFO_PWD-1:0]       misc_info;
    pkg_axi_mstr_awmisc_info_s           misc_info_s;
    logic [3:0]                          qos;
    logic [1:0]                          bar;
    logic [1:0]                          domain;
    logic [`CC_AXIJ_DMWR_VALUE *2+2:0]   snoop;
    logic [5:0]                          atop;
  } pkg_axi_mstr_aw_s;


//----------------------------------------------------------------------\\
//-------------------------------W CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic                                valid;
    logic                                last;
    logic [MSTR_BUS_WSTRB_WIDTH-1:0]     strb;
  } pkg_axi_mstr_w_s;


//----------------------------------------------------------------------\\
//------------------------------AR CHANNEL------------------------------\\
//----------------------------------------------------------------------\\
 //
  typedef struct packed {
    logic                                last_dcmp_tlp;
    logic                                nw;
    logic                                cxlsrc;
    logic [1:0]                          ats;
     logic [NUM_DMA_MAX_CHAN_WIDTH
          +DMA_TYPE_WIDTH-1:0]           dma;
    logic [(32*NPRFX) -1:0]              tlpprfx;
    logic [10:0]                         tph;
    logic                                ido;
    logic [8:0]                          req_segment;
    logic [8:0]                          dst_segment;
    logic                                zeroread;
  } pkg_axi_mstr_armisc_info_s;

  typedef struct packed {
    logic [MAX_MSTR_TAG-1:0]             id;
    logic                                valid;
    logic [MSTR_BURST_LEN_PW-1:0]        len;
    logic [2:0]                          size;
    logic [1:0]                          burst;
    logic [AXI_LOCK_WIDTH-1:0]           lock;
    logic [3:0]                          cache;
    logic [2:0]                          prot;
    logic [MSTR_MISC_INFO_PWD -1 :0]     misc_info;
    pkg_axi_mstr_armisc_info_s           misc_info_s;
    logic [3:0]                          qos;
    logic [1:0]                          bar;
    logic [1:0]                          domain;
    logic [3:0]                          snoop;
  } pkg_axi_mstr_ar_s;


//----------------------------------------------------------------------\\
//-------------------------------R CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic [2:0]                          cpl_stat;
  } pkg_axi_mstr_rmisc_info_s;

  typedef struct packed {
    logic [MAX_MSTR_TAG -1:0]            id;
    logic                                valid;
    logic                                last;
    logic [1:0]                          resp;
    logic [MSTR_RESP_MISC_INFO_PWD -1:0] misc_info;
    pkg_axi_mstr_rmisc_info_s            misc_info_s;
  } pkg_axi_mstr_r_s;


//----------------------------------------------------------------------\\
//-------------------------------B CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic [2:0]                          cpl_stat;
  } pkg_axi_mstr_bmisc_info_s;

  typedef struct packed {
    logic [MAX_MSTR_TAG -1:0]            id;
    logic                                valid;
    logic [`CC_AXIJ_DMWR_VALUE +1:0]     resp;
    pkg_axi_mstr_bmisc_info_s            misc_info_s;
  } pkg_axi_mstr_b_s;


//----------------------------------------------------------------------\\
//------------------------------ERROR STATUS----------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic                     awready;
    logic                     wready ;
    logic                     arready;
    logic                     rvalid ;
    logic                     rpyld0 ;
    logic                     rpyld1 ;
    logic                     rpyld2 ;
    logic                     bvalid ;
    logic                     bpyld0 ;
    logic                     bpyld1 ;
  } pkg_axi_mstr_err_parity;

  typedef struct packed {
    logic                     rpyld0;
    logic                     rpyld1;
    logic                     bpyld0;
  } pkg_axi_mstr_err_un_corr;

  typedef struct packed {
    pkg_axi_mstr_err_un_corr  corr  ;
    pkg_axi_mstr_err_un_corr  uncorr;
  } pkg_axi_mstr_err_ecc;

  typedef struct packed {
    pkg_axi_mstr_err_parity   parity;
    pkg_axi_mstr_err_ecc      ecc   ;
  } pkg_axi_mstr_err_sts;

//----------------------------------------------------------------------\\
//---------------------Inbound Posted ID Management --------------------\\
//----------------------------------------------------------------------\\

// Parameterize IBR (ibrouted) rpseqn stream inferface (IB + IBH)
localparam K_N_IBR_DMA_STREAMS       = 1;
localparam K_N_IBR_RO_STREAMS        = `CC_WR_CH_P_REQ_QUEUE_DP;
localparam K_N_IBR_VC_STREAMS        = `CX_NVC;
localparam K_N_IBR_PRESP_STREAMS     = K_N_IBR_VC_STREAMS

 + K_N_IBR_DMA_STREAMS
                                      ;
localparam K_N_IBR_PRESP_STREAMS_WD  = (K_N_IBR_PRESP_STREAMS < 2) ? 1 : $clog2(K_N_IBR_PRESP_STREAMS);
localparam K_N_IBR_PRESP_STREAMS_W_RO_WD = 1 ? `CX_IB_P_ID_MNG_MAX_IBR_ID_WD :  `CC_WR_CH_P_REQ_QUEUE_DP_LOG2 ;

localparam K_SEQN_RANGE_IBR_VC_LOW   = 0;
localparam K_SEQN_RANGE_IBR_VC_HIGH  = K_SEQN_RANGE_IBR_VC_LOW + K_N_IBR_VC_STREAMS - 1;
localparam K_SEQN_RANGE_IBR_IDO_LOW  = K_SEQN_RANGE_IBR_VC_HIGH ;
localparam K_SEQN_RANGE_IBR_IDO_HIGH = K_SEQN_RANGE_IBR_IDO_LOW ;
localparam K_SEQN_RANGE_IBR_DMA_LOW  = K_SEQN_RANGE_IBR_IDO_HIGH + 1 ;
localparam K_SEQN_RANGE_IBR_DMA_HIGH = K_SEQN_RANGE_IBR_DMA_LOW + K_N_IBR_DMA_STREAMS - 1 ;
localparam K_SEQN_RANGE_IBR_RO_LOW   = K_SEQN_RANGE_IBR_DMA_HIGH + 1 ;
localparam K_SEQN_RANGE_IBR_RO_HIGH  = K_SEQN_RANGE_IBR_RO_LOW + K_N_IBR_RO_STREAMS - 1 ;

// Parameterize LPM rpseqn stream inferface (IB)
localparam K_N_IB_DMA_STREAMS       = 1;
localparam K_N_IB_RO_STREAMS        = `CC_WR_CH_P_REQ_QUEUE_DP;
localparam K_N_IB_VC_STREAMS        = `CX_NVC ;
localparam K_N_IB_PRESP_STREAMS     = K_N_IB_VC_STREAMS

 + K_N_IB_DMA_STREAMS
                                      ;
localparam K_N_IB_PRESP_STREAMS_WD  = (K_N_IB_PRESP_STREAMS < 2) ? 1 : $clog2(K_N_IB_PRESP_STREAMS);
localparam K_N_IB_PRESP_STREAMS_W_RO_WD = 1 ? `CX_IB_P_ID_MNG_MAX_IB_ID_WD :  `CC_WR_CH_P_REQ_QUEUE_DP_LOG2 ;

localparam K_SEQN_RANGE_IB_VC_LOW   = 0;
localparam K_SEQN_RANGE_IB_VC_HIGH  = K_SEQN_RANGE_IB_VC_LOW + K_N_IB_VC_STREAMS - 1;
localparam K_SEQN_RANGE_IB_IDO_LOW  = K_SEQN_RANGE_IB_VC_HIGH ;
localparam K_SEQN_RANGE_IB_IDO_HIGH = K_SEQN_RANGE_IB_IDO_LOW ;
localparam K_SEQN_RANGE_IB_DMA_LOW  = K_SEQN_RANGE_IB_IDO_HIGH + 1 ;
localparam K_SEQN_RANGE_IB_DMA_HIGH = K_SEQN_RANGE_IB_DMA_LOW + K_N_IB_DMA_STREAMS - 1 ;
localparam K_SEQN_RANGE_IB_RO_LOW   = K_SEQN_RANGE_IB_DMA_HIGH + 1 ;
localparam K_SEQN_RANGE_IB_RO_HIGH  = K_SEQN_RANGE_IB_RO_LOW + K_N_IB_RO_STREAMS - 1 ;


typedef logic [`CC_AMBA_TLP_SEQ_WD -1:0] kPseqn_t;

typedef kPseqn_t [K_N_IBR_DMA_STREAMS -1:0] kIbrDmaRpseqn_t;
typedef kPseqn_t [K_N_IB_DMA_STREAMS  -1:0] kIbDmaRpseqn_t;


typedef kPseqn_t [K_N_IBR_VC_STREAMS  -1:0] kIbrVcRpseqn_t;
typedef kPseqn_t [K_N_IB_VC_STREAMS   -1:0] kIbVcRpseqn_t;

// Define IBR types
typedef struct packed {
  kIbrDmaRpseqn_t dma;
  kIbrVcRpseqn_t  vc;
} kIbrRpseqn_t;

typedef union packed {
  kIbrRpseqn_t                          s_struct;
  kPseqn_t [K_N_IBR_PRESP_STREAMS -1:0] s_bus;
} kIbrRpseqn_u;

// Define LPM types
typedef struct packed {
  kIbDmaRpseqn_t dma;
  kIbVcRpseqn_t  vc;
} kIbRpseqn_t;

typedef union packed {
  kIbRpseqn_t                          s_struct;
  kPseqn_t [K_N_IB_PRESP_STREAMS -1:0] s_bus;
} kIbRpseqn_u;


typedef struct packed {
  logic [`CX_NVC-1:0] vc_remap_en;
} cdmIbrPIdMngCtrl_s;

typedef struct packed {
  logic               global_disable;
  logic [`CX_NVC-1:0] vc_remap_en;
} cdmIbPIdMngCtrl_s;


function automatic cdmIbPIdMngCtrl_s f_kIbPIdMngCtrl_toIb(
  input cdmIbrPIdMngCtrl_s i_ibr
);
  f_kIbPIdMngCtrl_toIb = '{global_disable: ~|i_ibr.vc_remap_en, vc_remap_en: i_ibr.vc_remap_en[`CX_NVC-1:0]};
endfunction

// Transform kIbrRpseqn_u.s_bus index to kIbRpseqn_u.s_bus index
function automatic logic [K_N_IB_PRESP_STREAMS_WD -1:0] f_kStrictStream_IbrToIb(
  input logic [`CC_MAX_MSTR_TAG_PW -1:0] i_ibr_stream
);
  // In practice, decrements 1 to ibr_streams above CX_NVC-1 if HPmaster defined
  // Example
  // For 2 VC + 2 IDO with HPMaster
  // IB_VC in [0], IB_IDO in [1:2]. IBR_VC in [0,1], IBR_IDO in [2:3]
  // ibr_stream    K_SEQN_RANGE_IBR_x_LOW    K_SEQN_RANGE_IB_x_LOW    ib_stream     tlp possible?
  // 0             0                         0                        0             yes
  // 1             0                         0                        1 (wrong)     no - vc1 is routed to hpm
  // 2             2                         1                        1             yes
  // 3             2                         1                        2             yes
  f_kStrictStream_IbrToIb = (i_ibr_stream inside {[K_SEQN_RANGE_IBR_VC_LOW :K_SEQN_RANGE_IBR_VC_HIGH ]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_VC_LOW  + K_SEQN_RANGE_IB_VC_LOW ) :
                            (i_ibr_stream inside {[K_SEQN_RANGE_IBR_IDO_LOW:K_SEQN_RANGE_IBR_IDO_HIGH]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_IDO_LOW + K_SEQN_RANGE_IB_IDO_LOW) :
                            (i_ibr_stream inside {[K_SEQN_RANGE_IBR_DMA_LOW:K_SEQN_RANGE_IBR_DMA_HIGH]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_DMA_LOW + K_SEQN_RANGE_IB_DMA_LOW) :
                            '0;
endfunction

function automatic logic [K_N_IB_PRESP_STREAMS_W_RO_WD -1:0] f_kRelaxedStream_IbrToIb(
  input logic [K_N_IBR_PRESP_STREAMS_W_RO_WD -1:0] i_ibr_stream
);
  f_kRelaxedStream_IbrToIb = (i_ibr_stream inside {[K_SEQN_RANGE_IBR_VC_LOW :K_SEQN_RANGE_IBR_VC_HIGH ]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_VC_LOW  + K_SEQN_RANGE_IB_VC_LOW ) :
                             (i_ibr_stream inside {[K_SEQN_RANGE_IBR_IDO_LOW:K_SEQN_RANGE_IBR_IDO_HIGH]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_IDO_LOW + K_SEQN_RANGE_IB_IDO_LOW) :
                             (i_ibr_stream inside {[K_SEQN_RANGE_IBR_DMA_LOW:K_SEQN_RANGE_IBR_DMA_HIGH]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_DMA_LOW + K_SEQN_RANGE_IB_DMA_LOW) :
                             (i_ibr_stream inside {[K_SEQN_RANGE_IBR_RO_LOW :K_SEQN_RANGE_IBR_RO_HIGH ]}) ? (i_ibr_stream - K_SEQN_RANGE_IBR_RO_LOW  + K_SEQN_RANGE_IB_RO_LOW ) :
                             '0;
endfunction

function automatic logic [K_N_IBR_PRESP_STREAMS_W_RO_WD -1:0] f_kRelaxedStream_IbToIbr(
  input logic [K_N_IB_PRESP_STREAMS_W_RO_WD -1:0] i_ib_stream
);
  f_kRelaxedStream_IbToIbr = (i_ib_stream inside {[K_SEQN_RANGE_IB_VC_LOW :K_SEQN_RANGE_IB_VC_HIGH ]}) ? (i_ib_stream - K_SEQN_RANGE_IB_VC_LOW  + K_SEQN_RANGE_IBR_VC_LOW ) :
                             (i_ib_stream inside {[K_SEQN_RANGE_IB_IDO_LOW:K_SEQN_RANGE_IB_IDO_HIGH]}) ? (i_ib_stream - K_SEQN_RANGE_IB_IDO_LOW + K_SEQN_RANGE_IBR_IDO_LOW) :
                             (i_ib_stream inside {[K_SEQN_RANGE_IB_DMA_LOW:K_SEQN_RANGE_IB_DMA_HIGH]}) ? (i_ib_stream - K_SEQN_RANGE_IB_DMA_LOW + K_SEQN_RANGE_IBR_DMA_LOW) :
                             (i_ib_stream inside {[K_SEQN_RANGE_IB_RO_LOW :K_SEQN_RANGE_IB_RO_HIGH ]}) ? (i_ib_stream - K_SEQN_RANGE_IB_RO_LOW  + K_SEQN_RANGE_IBR_RO_LOW ) :
                             '0;
endfunction


// Inbound Posted ID Management Stage 1+ Support: VC/IDO strict streams
function automatic logic [`CC_MAX_MSTR_TAG_PW -1:0] f_kGetPostedStream(
  input logic [`DC_INBD_HEADER_PNP_1STG_WD -1:0] i_header
);
  logic [`CC_MAX_MSTR_TAG_PW -1:0] l_vc_stream;
  logic                               l_is_dma;
  logic [`CC_MAX_MSTR_TAG_PW -1:0] l_dma_stream;

  l_is_dma = |(i_header[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW]);
  l_dma_stream = (`CC_MAX_MSTR_TAG_PW)'(K_SEQN_RANGE_IBR_DMA_LOW);

  l_vc_stream = '0;

  f_kGetPostedStream = l_is_dma ? l_dma_stream :

                       l_vc_stream;
endfunction

function automatic logic [`DC_INBD_HEADER_PNP_1STG_WD -1:0] f_kInjectLookupID(
  input logic [`DC_INBD_HEADER_PNP_1STG_WD -1:0] i_header
 ,input logic      [`CC_MAX_MSTR_TAG_PW -1:0] i_lookupid
);
  logic [`DC_INBD_HEADER_PNP_1STG_WD -1:0] l_outHeader;

  l_outHeader = i_header;
  l_outHeader[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW] = i_lookupid;

  f_kInjectLookupID = l_outHeader;
endfunction

// If the header corresponds to a Posted request, change its lookupID
function automatic logic [`DC_INBD_HEADER_PNP_1STG_WD -1:0] f_kInjectPostedID(
  input logic [`DC_INBD_HEADER_PNP_1STG_WD -1:0] i_header
);
  logic [`CC_MAX_MSTR_TAG_PW -1:0] l_posted_lookupid;
  logic                      [7 -1:0] l_fmt_type;
  logic                               l_is_posted;

  l_fmt_type = {i_header[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], i_header[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]};

  l_is_posted = i_header[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]
                && (   (l_fmt_type      == `MWR32             )
                    || (l_fmt_type      == `MWR64             )
                    || (l_fmt_type[6:3] == 4'b0110 /* MSG  */ )
                    || (l_fmt_type[6:3] == 4'b1110 /* MSGD */ )
                   )
                ;

  l_posted_lookupid = f_kGetPostedStream(i_header);

  f_kInjectPostedID = l_is_posted ? f_kInjectLookupID(i_header, l_posted_lookupid) : i_header;
endfunction

endpackage : DWC_pcie_axi_mstr_pkg

`endif //__GUARD__DWC_PCIE_AXI_MSTR_PKG__SVH__

