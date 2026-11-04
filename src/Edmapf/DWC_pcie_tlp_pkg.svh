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
// ---    $Revision: #9 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_tlp_pkg.svh#9 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_TLP_PKG__SVH__
`define __GUARD__DWC_PCIE_TLP_PKG__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

package DWC_pcie_tlp_pkg;

// SNPS_SysML_CODE_START
  localparam K_RD_DMACHAN        = `CC_NUM_DMA_RD_CHAN;
  localparam K_WR_DMACHAN        = `CC_NUM_DMA_WR_CHAN;
  localparam K_DMATAGS           = `CC_DMATAGS;
  localparam K_ATTRWD            = `FLT_Q_ATTR_WIDTH;
  localparam K_MAX_LUID          = `CX_REMOTE_MAX_TAG;
  localparam K_LUID              = `CX_REMOTE_MAX_TAGS;
  localparam K_LUIDWD            = `CX_REMOTE_MAX_TAGS_WD;
  localparam K_NW                = `CX_NW;
  localparam K_PFWD              = `CX_NFUNC_WD;
  localparam K_PRFXWD            = `CX_NPRFX > 0 ? (32*`CX_NPRFX)+`CX_PRFX_PAR_WD : 1;
  localparam K_TAGWD             = `CX_TAG_SIZE;
  localparam K_VFWD              = `CX_NVFUNC_WD;
  localparam K_COREBUSWD         = `CC_CORE_DATA_BUS_WD;
  localparam K_COREBUSWD_WO_PROT = `PCIE_CORE_DATA_BUS_WD;
  localparam K_COREBUSPROTWD     = `CC_CORE_DATA_BUS_WD - `PCIE_CORE_DATA_BUS_WD;
  localparam K_MAXPCIETAG        = `CC_DMA_RD_TAG_HIGH;       
  localparam K_MINDMATAG         = `CC_DMA_RD_TAG_LOW ;      
  localparam K_MAXPCIETAG_8BIT   = `CC_DMA_RD_8BIT_TAG_HIGH;  
  localparam K_MINDMATAG_8BIT    = `CC_DMA_RD_8BIT_TAG_LOW;  
  localparam K_MAXPCIETAG_5BIT   = `CC_DMA_RD_5BIT_TAG_HIGH;  
  localparam K_MINDMATAG_5BIT    = `CC_DMA_RD_5BIT_TAG_LOW;  
  localparam K_PRFXDEFAULT       = { {(`CX_PRFX_PAR_WD){1'(`CX_RAS_PARITY_MODE)}} , {(K_PRFXWD-`CX_PRFX_PAR_WD){1'b0}} };
  localparam K_ORD_WD            = `CX_RADM_PKT_ORD_WD;
  localparam K_RD_DMACHANWD      = K_RD_DMACHAN > 1 ? $clog2(K_RD_DMACHAN) : 1;
  localparam K_WR_DMACHANWD      = K_WR_DMACHAN > 1 ? $clog2(K_WR_DMACHAN) : 1;
  localparam K_DMACHAN           = K_RD_DMACHAN > K_WR_DMACHAN ? K_RD_DMACHAN : K_WR_DMACHAN;
  localparam K_DMACHANWD         = K_DMACHAN > 1 ? $clog2(K_DMACHAN) : 1;
  localparam K_DMATAGWD          = $clog2(K_DMATAGS);
  localparam K_LUIDMAPWD         = K_LUIDWD > K_DMATAGWD ? K_LUIDWD : K_DMATAGWD;
// SNPS_SysML_CODE_END

  // ##########################################################################
  //                                Enumerations                               
  // ##########################################################################
  typedef enum logic [2:0] {
     E_DMA_BYPASS      = 0
    ,E_DMA_WRCH_DATA   = 1
    ,E_DMA_BYPASS_CPL  = 2
    ,E_DMA_RDCH_DATA   = 3
    ,E_DMA_WRCH_INT    = 4
    ,E_DMA_WRCH_LLREAD = 5
    ,E_DMA_RDCH_INT    = 6
    ,E_DMA_RDCH_LLREAD = 7
    ,E_DMA_UNKNOWN     = 'X
  } dma_req_type_e;

  typedef enum logic [1:0] {
     E_TLP_HEADER = 0
    ,E_TLP_BYPASS = 1
    ,E_TLP_FULL   = 2
  } ifType_e;

  typedef enum logic {
     E_TAG_LUID = 0
    ,E_TAG_PCIE = 1
  } tagType_e;

  typedef enum logic [2:0] {
     E_CPL_STATUS_SC  = 0
    ,E_CPL_STATUS_UR  = 1
    ,E_CPL_STATUS_CRS = 2
    ,E_CPL_STATUS_CA  = 4
  } tlpCplStatus_e;

  typedef enum logic [2:0] {
     E_NOT_DMAPF      = 0
    ,E_DMAPF_WR_LL    = 1
    ,E_DMAPF_WR_DATA  = 2
    ,E_DMAPF_RD_LL    = 3
    ,E_DMAPF_RD_DATA  = 4
    ,E_TARGET_UNKNOWN = 'X
  } tlpDmapfTarget_e;

  // ##########################################################################
  //                          Data Structures/Unions                           
  // ##########################################################################
  typedef struct packed {
    dma_req_type_e                   req    ;
    logic          [K_DMACHANWD-1:0] channel;
  } dmaExtra_s;

  typedef struct packed {
    logic  [K_DMATAGWD-1:0] tag    ;
    logic [K_DMACHANWD-1:0] channel;
  } edmapf_dmatag_ch_s;

  typedef struct packed {
    logic     [K_TAGWD-1:0] segment;
    logic     [K_TAGWD-1:0] pcieTag;
    logic [K_DMACHANWD-1:0] channel;
  } edmapf_pcietag_ch_s;

  typedef struct packed {
    logic [8:0] dst_sgmt;
    logic [8:0] req_sgmt;
    logic [7:0] cpl_sgmt;
  } flit_mode_s;

  typedef struct packed {
    logic          [2:0] outbound;
    logic [K_ORD_WD-1:0] inbound ;
  } order_seqnum_s;

  typedef struct packed {
    logic [63:0] uppr_bytes      ;
    logic        uppr_bytes_valid;
    logic        mem_type        ;
    logic  [2:0] vc_num          ;
  } radmExtra_s;

  typedef struct packed {
    logic  free   ;
    logic  consume;
  } tagUsage_s;

  typedef struct packed {
    logic [11:0] len;
  } timeoutExtra_s;

  typedef struct packed {
    logic  idOrder   ;
    logic  relaxOrder;
    logic  snoop     ;
  } tlpAttr_s;

  typedef struct packed {
    logic      [K_VFWD-2:0] vfunc_num   ;
    logic                   vfunc_active;
    logic             [2:0] tc          ;
    logic      [K_PFWD-1:0] pfunc_num   ;
    logic     [K_TAGWD-1:0] pcieTag     ;
    logic                   ln          ;
    tlpAttr_s               attr        ;
  } tlpCommon1_s;

  typedef struct packed {
    logic          [4:0] typ       ;
    logic                tph_th    ;
    logic          [7:0] tph_st    ;
    logic          [1:0] tph_ph    ;
    logic                td        ;
    logic [K_PRFXWD-1:0] prfx      ;
    logic                poisoned  ;
    logic          [3:0] last_be   ;
    logic          [1:0] fmt       ;
    logic          [3:0] first_be  ;
    logic          [9:0] dw_len    ;
    logic          [2:0] cpl_status;
    logic                cpl_bcm   ;
    logic         [15:0] cmpltr_id ;
    logic         [11:0] byte_cnt  ;
    logic          [1:0] ats       ;
    logic         [63:0] addr      ;
  } tlpCommon2_s;

  typedef struct packed {
    logic                cxlsrc  ;
    logic                nw      ;
    logic [K_LUIDWD-1:0] lookupid;
  } tlpCommon3_s;

  typedef struct packed {
    logic            tlp_abort      ;
    logic            rom_in_range   ;
    logic     [15:0] req_id         ;
    logic            io_req_in_range;
    logic      [2:0] in_membar_range;
    logic            ecrc_err       ;
    logic [K_NW-1:0] dwen           ;
    logic            dllp_abort     ;
    logic            cpl_last       ;
  } tlpCommon4_s;

  typedef struct packed {
    logic [12:0] tlp_byte_len ;
    logic        bad_eot      ;
    logic        atu_bypass   ;
    logic        addr_align_en;
  } xadmExtra_s;

  typedef struct packed {
    xadmExtra_s   extra  ;
    dmaExtra_s    dma    ;
    tlpCommon3_s  common3;
    tlpCommon2_s  common2;
    tlpCommon1_s  common1;
  } xadm_s;

  typedef struct packed {
    order_seqnum_s                  order_seq_no;
    flit_mode_s                     flit_mode   ;
    logic          [K_DMATAGWD-1:0] tag         ;
    xadmExtra_s                     xadmPort    ;
    radmExtra_s                     radmPort    ;
    dmaExtra_s                      dma         ;
    tlpCommon4_s                    common4     ;
    tlpCommon3_s                    common3     ;
    tlpCommon2_s                    common2     ;
    tlpCommon1_s                    common1     ;
  } xradm_s;

  typedef struct packed {
    tlpCommon4_s  common3;
    tlpCommon2_s  common2;
    tlpCommon1_s  common1;
  } bypass_s;

  typedef struct packed {
    radmExtra_s   extra  ;
    dmaExtra_s    dma    ;
    tlpCommon4_s  common4;
    tlpCommon3_s  common3;
    tlpCommon2_s  common2;
    tlpCommon1_s  common1;
  } dradm_s;

  typedef struct packed {
    radmExtra_s   extra  ;
    tlpCommon4_s  common4;
    tlpCommon3_s  common3;
    tlpCommon2_s  common2;
    tlpCommon1_s  common1;
  } radm_s;

  typedef struct packed {
    timeoutExtra_s  extra  ;
    tlpCommon1_s    common1;
  } timeout_s;

// SNPS_SysML_CODE_START

  localparam xradm_s K_NULLHEADER = '{
    dma: '{req:E_DMA_UNKNOWN, channel:'X},
    default: 'X,
    common2:'{
      default  : 'X,
      first_be : 4'b0000,
      last_be  : 4'b0000,
      dw_len   : 10'b00_0000_0001
    }
  };

  localparam xradm_s K_CPLHEADER = '{
    default: 'X,
    dma: '{
      channel: 'X,
      req: E_DMA_UNKNOWN
    },
    common2: '{
      default: 'X,
      fmt: 2'bX0,
      typ: 5'b0101X
    }
  };

  localparam xradm_s K_MRDHEADER = '{
    default: 'X,
    dma: '{
      channel: 'X,
      req: E_DMA_UNKNOWN
    },
    common2: '{
      default: 'X,
      fmt: 2'b0X,
      typ: 5'b000XX
    }
  };

  localparam xradm_s K_MSGHEADER = '{
    default: 'X,
    dma: '{
      channel: 'X,
      req: E_DMA_UNKNOWN
    },
    common2: '{
      default: 'X,
      fmt: 2'bX1,
      typ: 5'b10XXX
    }
  };

  localparam xradm_s K_MWRHEADER = '{
    default: 'X,
    dma: '{
      channel: 'X,
      req: E_DMA_UNKNOWN
    },
    common2: '{
      default: 'X,
      fmt: 2'b1X,
      typ: 5'b00000
    }
  };

  // **************************************************************************
  // Function to convert from TLP DW length 1 DW to 1024 DW coded by zero
  // to byte length. Since it does not accounts with byte enables the byte
  // length range is from 4 to 4096
  // **************************************************************************
  function automatic [12:0] f_tlp_dwlen2bytelen(
    input logic [9:0] dw_len
    );
    f_tlp_dwlen2bytelen = (dw_len == '0) ? 13'd4096 :{1'b0, dw_len, 2'b00};
  endfunction

  // **************************************************************************
  // Inverse of f_tlp_dwlen2bytelen
  // **************************************************************************
  function automatic [9:0] f_tlp_bytelen2dwlen(
    input logic [12:0] byte_len
    );
    f_tlp_bytelen2dwlen = (byte_len == 13'd4096) ? 10'd0 : byte_len[11:2];
  endfunction

// SNPS_SysML_CODE_END

endpackage

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

`endif // __GUARD__DWC_PCIE_TLP_PKG__SVH__

