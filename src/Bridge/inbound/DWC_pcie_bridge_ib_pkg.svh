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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_pkg.svh#9 $
// -------------------------------------------------------------------------
// --- Description: 
// -------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_BRIDGE_IB_PKG__SVH__
`define __GUARD__DWC_PCIE_BRIDGE_IB_PKG__SVH__


package DWC_pcie_bridge_ib_pkg;

//#########################################################
//                  Local Parameters
//#########################################################
//---------------------------------------------------------- Local Parameters ---------------------------------------------------------------------------
localparam PKG_FLT_Q_PRFX_WIDTH       = `FLT_Q_PRFX_WIDTH;
localparam PKG_CX_NVFUNC_WD           = `CX_NVFUNC_WD;
localparam PKG_CX_NVC_LOG2            = `CX_NVC_LOG2;
localparam PKG_CC_CORE_ADDR_BUS_WD    = `FLT_Q_ADDR_WIDTH;
localparam PKG_CX_NFUNC_WD            = `CX_NFUNC_WD;
localparam PKG_CX_NFUNC_WD_OPT        = `CX_NFUNC_WD_OPT;
localparam PKG_CX_REMOTE_MAX_TAGS_WD  = `CC_MAX_MSTR_TAG_PW;
localparam PKG_CX_TAG_SIZE            = `CX_TAG_SIZE;
localparam PKG_FLT_Q_ATTR_WIDTH       = `FLT_Q_ATTR_WIDTH;
localparam PKG_CX_NW                  = `CX_NW;
localparam PKG_CC_AMBA_TLP_SEQ_WD     = `CC_AMBA_TLP_SEQ_WD;
localparam PKG_DMA_CHAN_WIDTH         = `CC_NUM_DMA_MAX_CHAN_WIDTH;
localparam PKG_DMA_REQ_WIDTH          = `DC_DMA_TYPE_WIDTH;
localparam PKG_CC_MSTR_BE_CTRL_WIDTH  = `CC_MSTR_BE_CTRL_WIDTH;
localparam PKG_MSTR_MTU_PW            = `CC_MSTR_MTU_PW;

//#########################################################
//                  Data Structures
//#########################################################
typedef struct packed {
   logic                                  radm_trgt1_hdr_uppr_bytes_valid;
   logic                                  inbd_mcb_np_valid;
   logic       [PKG_FLT_Q_PRFX_WIDTH-1:0] radm_trgt1_tlp_prfx;
   logic         [PKG_DMA_CHAN_WIDTH-1:0] d_trgt1_req_dma_channel;
   logic          [PKG_DMA_REQ_WIDTH-1:0] d_trgt1_req_dma;
   logic                                  radm_trgt1_bcm;
   logic                                  radm_trgt1_mem_type;
   logic                                  radm_trgt1_th;
   logic                            [1:0] radm_trgt1_ph;
   logic                            [7:0] radm_trgt1_st;
   logic                            [2:0] radm_trgt1_in_membar_range;
   logic                                  radm_trgt1_io_req_in_range;
   logic                                  radm_trgt1_rom_in_range;
   logic    [PKG_CC_CORE_ADDR_BUS_WD-1:0] radm_trgt1_addr_intp;
   logic                            [3:0] radm_trgt1_last_be;
   logic                            [3:0] radm_trgt1_first_be;
   logic                            [9:0] radm_trgt1_dw_len;
   logic                                  radm_trgt1_poisoned;
   logic                                  radm_trgt1_td;
   logic            [PKG_CX_NFUNC_WD-1:0] radm_trgt1_func_num;
   logic  [PKG_CX_REMOTE_MAX_TAGS_WD-1:0] radm_trgt1_lookup_id;
   logic            [PKG_CX_TAG_SIZE-1:0] radm_trgt1_tag;
   logic                           [15:0] radm_trgt1_reqid;
   logic                                  radm_trgt1_nw;
   logic                                  radm_trgt1_cxlsrc;
   logic                            [1:0] radm_trgt1_ats;
   logic       [PKG_FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_attr;
   logic                            [2:0] radm_trgt1_tc;
   logic                            [4:0] radm_trgt1_type;
   logic                            [1:0] radm_trgt1_fmt;
   logic                                  radm_trgt1_ecrc_err;
   logic                                  radm_trgt1_tlp_abort;
   logic                                  radm_trgt1_dllp_abort;
   logic                  [PKG_CX_NW-1:0] radm_trgt1_dwen;
   logic     [PKG_CC_AMBA_TLP_SEQ_WD-1:0] pseq_nbr;
   logic                                  radm_trgt1_eot;
   logic                                  radm_trgt1_dv;
   logic                                  radm_trgt1_hv;

} ib_rd_bus;

typedef struct packed {
   logic          [PKG_FLT_Q_PRFX_WIDTH-1:0] radm_trgt1_tlp_prfx;
   logic            [PKG_DMA_CHAN_WIDTH-1:0] d_trgt1_req_dma_channel;
   logic             [PKG_DMA_REQ_WIDTH-1:0] d_trgt1_req_dma;
   logic                                     radm_trgt1_mem_type;
   logic                                     radm_trgt1_th;
   logic                               [1:0] radm_trgt1_ph;
   logic                               [7:0] radm_trgt1_st;
   logic                               [2:0] radm_trgt1_in_membar_range;
   logic                                     radm_trgt1_io_req_in_range;
   logic                                     radm_trgt1_rom_in_range;
   logic       [PKG_CC_CORE_ADDR_BUS_WD-3:0] radm_trgt1_addr_intp;
   logic                               [3:0] radm_trgt1_last_be;
   logic                               [3:0] radm_trgt1_first_be;
   logic                               [9:0] radm_trgt1_dw_len;
   logic                                     radm_trgt1_td;
   logic     [PKG_CX_REMOTE_MAX_TAGS_WD-1:0] radm_trgt1_lookup_id;
   logic               [PKG_CX_TAG_SIZE-1:0] radm_trgt1_tag;
   logic                              [15:0] radm_trgt1_reqid;
   logic                                     radm_trgt1_nw;
   logic                                     radm_trgt1_cxlsrc;
   logic                               [1:0] radm_trgt1_ats;
   logic          [PKG_FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_attr;
   logic                               [2:0] radm_trgt1_tc;
   logic                               [2:0] radm_trgt1_type;
   logic                                     radm_trgt1_fmt;
   logic        [PKG_CC_AMBA_TLP_SEQ_WD-1:0] pseq_nbr;

} ib_rd_bus_ram;

typedef struct packed {
   logic                           [12:0] decmp_byte_len;
   logic  [PKG_CC_MSTR_BE_CTRL_WIDTH-1:0] decmp_byte_en_ctrl;
   logic                                  decmp_last;
   logic                            [8:0] req_segment;
   logic                            [8:0] dst_segment;
   logic                                  radm_trgt1_hdr_uppr_bytes_valid;
   logic                                  inbd_mcb_np_valid;
   logic       [PKG_FLT_Q_PRFX_WIDTH-1:0] radm_trgt1_tlp_prfx;
   logic         [PKG_DMA_CHAN_WIDTH-1:0] d_trgt1_req_dma_channel;
   logic          [PKG_DMA_REQ_WIDTH-1:0] d_trgt1_req_dma;
   logic                                  radm_trgt1_bcm;
   logic                                  radm_trgt1_mem_type;
   logic                                  radm_trgt1_th;
   logic                            [1:0] radm_trgt1_ph;
   logic                            [7:0] radm_trgt1_st;
   logic                            [2:0] radm_trgt1_in_membar_range;
   logic                                  radm_trgt1_io_req_in_range;
   logic                                  radm_trgt1_rom_in_range;
   logic    [PKG_CC_CORE_ADDR_BUS_WD-1:0] radm_trgt1_addr_intp;
   logic                            [3:0] radm_trgt1_last_be;
   logic                            [3:0] radm_trgt1_first_be;
   logic                            [9:0] radm_trgt1_dw_len;
   logic                                  radm_trgt1_poisoned;
   logic                                  radm_trgt1_td;
   logic            [PKG_CX_NFUNC_WD-1:0] radm_trgt1_func_num;
   logic  [PKG_CX_REMOTE_MAX_TAGS_WD-1:0] radm_trgt1_lookup_id;
   logic            [PKG_CX_TAG_SIZE-1:0] radm_trgt1_tag;
   logic                           [15:0] radm_trgt1_reqid;
   logic                                  radm_trgt1_nw;
   logic                                  radm_trgt1_cxlsrc;
   logic                            [1:0] radm_trgt1_ats;
   logic       [PKG_FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_attr;
   logic                            [2:0] radm_trgt1_tc;
   logic                            [4:0] radm_trgt1_type;
   logic                            [1:0] radm_trgt1_fmt;
   logic                                  radm_trgt1_ecrc_err;
   logic                                  radm_trgt1_tlp_abort;
   logic                                  radm_trgt1_dllp_abort;
   logic                  [PKG_CX_NW-1:0] radm_trgt1_dwen;
   logic     [PKG_CC_AMBA_TLP_SEQ_WD-1:0] pseq_nbr;
   logic                                  radm_trgt1_eot;
   logic                                  radm_trgt1_dv;
   logic                                  radm_trgt1_hv;
  } ib_rd_cdc_bus;

typedef struct packed {
   logic               [PKG_MSTR_MTU_PW-3:0] decmp_byte_len;
   logic     [PKG_CC_MSTR_BE_CTRL_WIDTH-1:0] decmp_byte_en_ctrl;
   logic                                     decmp_last;
   logic                               [8:0] req_segment;
   logic                               [8:0] dst_segment;
   logic          [PKG_FLT_Q_PRFX_WIDTH-1:0] radm_trgt1_tlp_prfx;
   logic            [PKG_DMA_CHAN_WIDTH-1:0] d_trgt1_req_dma_channel;
   logic             [PKG_DMA_REQ_WIDTH-1:0] d_trgt1_req_dma;
   logic                                     radm_trgt1_mem_type;
   logic                                     radm_trgt1_th;
   logic                               [1:0] radm_trgt1_ph;
   logic                               [7:0] radm_trgt1_st;
   logic                               [2:0] radm_trgt1_in_membar_range;
   logic                                     radm_trgt1_io_req_in_range;
   logic                                     radm_trgt1_rom_in_range;
   logic       [PKG_CC_CORE_ADDR_BUS_WD-3:0] radm_trgt1_addr_intp;
   logic                               [3:0] radm_trgt1_last_be;
   logic                               [3:0] radm_trgt1_first_be;
   logic                               [9:0] radm_trgt1_dw_len;
   logic                                     radm_trgt1_td;
   logic     [PKG_CX_REMOTE_MAX_TAGS_WD-1:0] radm_trgt1_lookup_id;
   logic               [PKG_CX_TAG_SIZE-1:0] radm_trgt1_tag;
   logic                              [15:0] radm_trgt1_reqid;
   logic                                     radm_trgt1_nw;
   logic                                     radm_trgt1_cxlsrc;
   logic                               [1:0] radm_trgt1_ats;
   logic          [PKG_FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_attr;
   logic                               [2:0] radm_trgt1_tc;
   logic                               [2:0] radm_trgt1_type;
   logic                                     radm_trgt1_fmt;
   logic        [PKG_CC_AMBA_TLP_SEQ_WD-1:0] pseq_nbr;

} ib_rd_cdc_bus_ram;

//#########################################################
//                    Functions
//#########################################################
  function automatic ib_rd_bus_ram fn_rd_ordr_ram_opt;
    input ib_rd_bus inbd_hdr;
    begin
      fn_rd_ordr_ram_opt.radm_trgt1_tlp_prfx              = inbd_hdr.radm_trgt1_tlp_prfx;
      fn_rd_ordr_ram_opt.d_trgt1_req_dma_channel          = inbd_hdr.d_trgt1_req_dma_channel;
      fn_rd_ordr_ram_opt.d_trgt1_req_dma                  = inbd_hdr.d_trgt1_req_dma;
      fn_rd_ordr_ram_opt.radm_trgt1_mem_type              = inbd_hdr.radm_trgt1_mem_type;
      fn_rd_ordr_ram_opt.radm_trgt1_th                    = inbd_hdr.radm_trgt1_th;
      fn_rd_ordr_ram_opt.radm_trgt1_ph                    = inbd_hdr.radm_trgt1_ph;
      fn_rd_ordr_ram_opt.radm_trgt1_st                    = inbd_hdr.radm_trgt1_st;
      fn_rd_ordr_ram_opt.radm_trgt1_in_membar_range       = inbd_hdr.radm_trgt1_in_membar_range;
      fn_rd_ordr_ram_opt.radm_trgt1_io_req_in_range       = inbd_hdr.radm_trgt1_io_req_in_range;
      fn_rd_ordr_ram_opt.radm_trgt1_rom_in_range          = inbd_hdr.radm_trgt1_rom_in_range;
      fn_rd_ordr_ram_opt.radm_trgt1_addr_intp             = inbd_hdr.radm_trgt1_addr_intp[PKG_CC_CORE_ADDR_BUS_WD-1:2];
      fn_rd_ordr_ram_opt.radm_trgt1_last_be               = inbd_hdr.radm_trgt1_last_be;
      fn_rd_ordr_ram_opt.radm_trgt1_first_be              = inbd_hdr.radm_trgt1_first_be;
      fn_rd_ordr_ram_opt.radm_trgt1_dw_len                = inbd_hdr.radm_trgt1_dw_len;
      fn_rd_ordr_ram_opt.radm_trgt1_td                    = inbd_hdr.radm_trgt1_td;
      fn_rd_ordr_ram_opt.radm_trgt1_lookup_id             = inbd_hdr.radm_trgt1_lookup_id;
      fn_rd_ordr_ram_opt.radm_trgt1_tag                   = inbd_hdr.radm_trgt1_tag;
      fn_rd_ordr_ram_opt.radm_trgt1_reqid                 = inbd_hdr.radm_trgt1_reqid;
      fn_rd_ordr_ram_opt.radm_trgt1_nw                    = inbd_hdr.radm_trgt1_nw;
      fn_rd_ordr_ram_opt.radm_trgt1_cxlsrc                = inbd_hdr.radm_trgt1_cxlsrc;
      fn_rd_ordr_ram_opt.radm_trgt1_ats                   = inbd_hdr.radm_trgt1_ats;
      fn_rd_ordr_ram_opt.radm_trgt1_attr                  = inbd_hdr.radm_trgt1_attr;
      fn_rd_ordr_ram_opt.radm_trgt1_tc                    = inbd_hdr.radm_trgt1_tc;
      fn_rd_ordr_ram_opt.radm_trgt1_type                  = inbd_hdr.radm_trgt1_type[2:0];
      fn_rd_ordr_ram_opt.radm_trgt1_fmt                   = inbd_hdr.radm_trgt1_fmt[0];
      fn_rd_ordr_ram_opt.pseq_nbr                         = inbd_hdr.pseq_nbr;
    end
  endfunction : fn_rd_ordr_ram_opt

  function automatic ib_rd_bus fn_rd_ordr_ram_reconstruction;
    input ib_rd_bus_ram inbd_hdr;
    begin
      fn_rd_ordr_ram_reconstruction.radm_trgt1_hdr_uppr_bytes_valid = 1'b0;
      fn_rd_ordr_ram_reconstruction.inbd_mcb_np_valid               = 1'b1;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_tlp_prfx             = inbd_hdr.radm_trgt1_tlp_prfx;
      fn_rd_ordr_ram_reconstruction.d_trgt1_req_dma_channel         = inbd_hdr.d_trgt1_req_dma_channel;
      fn_rd_ordr_ram_reconstruction.d_trgt1_req_dma                 = inbd_hdr.d_trgt1_req_dma;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_bcm                  = 1'b0;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_mem_type             = inbd_hdr.radm_trgt1_mem_type;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_th                   = inbd_hdr.radm_trgt1_th;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_ph                   = inbd_hdr.radm_trgt1_ph;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_st                   = inbd_hdr.radm_trgt1_st;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_in_membar_range      = inbd_hdr.radm_trgt1_in_membar_range;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_io_req_in_range      = inbd_hdr.radm_trgt1_io_req_in_range;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_rom_in_range         = inbd_hdr.radm_trgt1_rom_in_range;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_addr_intp            = {inbd_hdr.radm_trgt1_addr_intp, 2'd0};
      fn_rd_ordr_ram_reconstruction.radm_trgt1_last_be              = inbd_hdr.radm_trgt1_last_be;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_first_be             = inbd_hdr.radm_trgt1_first_be;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_dw_len               = inbd_hdr.radm_trgt1_dw_len;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_poisoned             = 1'b0;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_td                   = inbd_hdr.radm_trgt1_td;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_func_num             = {PKG_CX_NFUNC_WD{1'b0}};
      fn_rd_ordr_ram_reconstruction.radm_trgt1_lookup_id            = inbd_hdr.radm_trgt1_lookup_id;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_tag                  = inbd_hdr.radm_trgt1_tag;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_reqid                = inbd_hdr.radm_trgt1_reqid;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_nw                   = inbd_hdr.radm_trgt1_nw;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_cxlsrc               = inbd_hdr.radm_trgt1_cxlsrc;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_ats                  = inbd_hdr.radm_trgt1_ats;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_attr                 = inbd_hdr.radm_trgt1_attr;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_tc                   = inbd_hdr.radm_trgt1_tc;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_type                 = {2'd0, inbd_hdr.radm_trgt1_type};
      fn_rd_ordr_ram_reconstruction.radm_trgt1_fmt                  = {1'b0, inbd_hdr.radm_trgt1_fmt};
      fn_rd_ordr_ram_reconstruction.radm_trgt1_ecrc_err             = 1'b0;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_tlp_abort            = 1'b0;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_dllp_abort           = 1'b0;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_dwen                 = {PKG_CX_NW{1'b0}};
      fn_rd_ordr_ram_reconstruction.pseq_nbr                        = inbd_hdr.pseq_nbr;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_eot                  = 1'b1;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_dv                   = 1'b0;
      fn_rd_ordr_ram_reconstruction.radm_trgt1_hv                   = 1'b1;
    end
  endfunction : fn_rd_ordr_ram_reconstruction

  function automatic ib_rd_cdc_bus_ram fn_rd_cdc_ram_opt;
    input ib_rd_cdc_bus inbd_hdr;
    begin
      fn_rd_cdc_ram_opt.req_segment                      = inbd_hdr.req_segment;
      fn_rd_cdc_ram_opt.dst_segment                      = inbd_hdr.dst_segment;
      fn_rd_cdc_ram_opt.decmp_byte_len                   = inbd_hdr.decmp_byte_len[PKG_MSTR_MTU_PW-1:2];
      fn_rd_cdc_ram_opt.decmp_byte_en_ctrl               = inbd_hdr.decmp_byte_en_ctrl;
      fn_rd_cdc_ram_opt.decmp_last                       = inbd_hdr.decmp_last;
      fn_rd_cdc_ram_opt.radm_trgt1_tlp_prfx              = inbd_hdr.radm_trgt1_tlp_prfx;
      fn_rd_cdc_ram_opt.d_trgt1_req_dma_channel          = inbd_hdr.d_trgt1_req_dma_channel;
      fn_rd_cdc_ram_opt.d_trgt1_req_dma                  = inbd_hdr.d_trgt1_req_dma;
      fn_rd_cdc_ram_opt.radm_trgt1_mem_type              = inbd_hdr.radm_trgt1_mem_type;
      fn_rd_cdc_ram_opt.radm_trgt1_th                    = inbd_hdr.radm_trgt1_th;
      fn_rd_cdc_ram_opt.radm_trgt1_ph                    = inbd_hdr.radm_trgt1_ph;
      fn_rd_cdc_ram_opt.radm_trgt1_st                    = inbd_hdr.radm_trgt1_st;
      fn_rd_cdc_ram_opt.radm_trgt1_in_membar_range       = inbd_hdr.radm_trgt1_in_membar_range;
      fn_rd_cdc_ram_opt.radm_trgt1_io_req_in_range       = inbd_hdr.radm_trgt1_io_req_in_range;
      fn_rd_cdc_ram_opt.radm_trgt1_rom_in_range          = inbd_hdr.radm_trgt1_rom_in_range;
      fn_rd_cdc_ram_opt.radm_trgt1_addr_intp             = inbd_hdr.radm_trgt1_addr_intp[PKG_CC_CORE_ADDR_BUS_WD-1:2];
      fn_rd_cdc_ram_opt.radm_trgt1_last_be               = inbd_hdr.radm_trgt1_last_be;
      fn_rd_cdc_ram_opt.radm_trgt1_first_be              = inbd_hdr.radm_trgt1_first_be;
      fn_rd_cdc_ram_opt.radm_trgt1_dw_len                = inbd_hdr.radm_trgt1_dw_len;
      fn_rd_cdc_ram_opt.radm_trgt1_td                    = inbd_hdr.radm_trgt1_td;
      fn_rd_cdc_ram_opt.radm_trgt1_lookup_id             = inbd_hdr.radm_trgt1_lookup_id;
      fn_rd_cdc_ram_opt.radm_trgt1_tag                   = inbd_hdr.radm_trgt1_tag;
      fn_rd_cdc_ram_opt.radm_trgt1_reqid                 = inbd_hdr.radm_trgt1_reqid;
      fn_rd_cdc_ram_opt.radm_trgt1_nw                    = inbd_hdr.radm_trgt1_nw;
      fn_rd_cdc_ram_opt.radm_trgt1_cxlsrc                = inbd_hdr.radm_trgt1_cxlsrc;
      fn_rd_cdc_ram_opt.radm_trgt1_ats                   = inbd_hdr.radm_trgt1_ats;
      fn_rd_cdc_ram_opt.radm_trgt1_attr                  = inbd_hdr.radm_trgt1_attr;
      fn_rd_cdc_ram_opt.radm_trgt1_tc                    = inbd_hdr.radm_trgt1_tc;
      fn_rd_cdc_ram_opt.radm_trgt1_type                  = inbd_hdr.radm_trgt1_type[2:0];
      fn_rd_cdc_ram_opt.radm_trgt1_fmt                   = inbd_hdr.radm_trgt1_fmt[0];
      fn_rd_cdc_ram_opt.pseq_nbr                         = inbd_hdr.pseq_nbr;
    end
  endfunction : fn_rd_cdc_ram_opt

  function automatic ib_rd_cdc_bus fn_rd_cdc_ram_reconstruction;
    input ib_rd_cdc_bus_ram inbd_hdr;
    begin
      fn_rd_cdc_ram_reconstruction.req_segment                     = inbd_hdr.req_segment;
      fn_rd_cdc_ram_reconstruction.dst_segment                     = inbd_hdr.dst_segment;
      fn_rd_cdc_ram_reconstruction.decmp_byte_len                  = { {13-PKG_MSTR_MTU_PW{1'b0}}, inbd_hdr.decmp_byte_len[PKG_MSTR_MTU_PW-3:0], 2'b0};
      fn_rd_cdc_ram_reconstruction.decmp_byte_en_ctrl              = inbd_hdr.decmp_byte_en_ctrl;
      fn_rd_cdc_ram_reconstruction.decmp_last                      = inbd_hdr.decmp_last;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_hdr_uppr_bytes_valid = 1'b0;
      fn_rd_cdc_ram_reconstruction.inbd_mcb_np_valid               = 1'b1;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_tlp_prfx             = inbd_hdr.radm_trgt1_tlp_prfx;
      fn_rd_cdc_ram_reconstruction.d_trgt1_req_dma_channel         = inbd_hdr.d_trgt1_req_dma_channel;
      fn_rd_cdc_ram_reconstruction.d_trgt1_req_dma                 = inbd_hdr.d_trgt1_req_dma;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_bcm                  = 1'b0;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_mem_type             = inbd_hdr.radm_trgt1_mem_type;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_th                   = inbd_hdr.radm_trgt1_th;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_ph                   = inbd_hdr.radm_trgt1_ph;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_st                   = inbd_hdr.radm_trgt1_st;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_in_membar_range      = inbd_hdr.radm_trgt1_in_membar_range;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_io_req_in_range      = inbd_hdr.radm_trgt1_io_req_in_range;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_rom_in_range         = inbd_hdr.radm_trgt1_rom_in_range;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_addr_intp            = {inbd_hdr.radm_trgt1_addr_intp, 2'd0};
      fn_rd_cdc_ram_reconstruction.radm_trgt1_last_be              = inbd_hdr.radm_trgt1_last_be;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_first_be             = inbd_hdr.radm_trgt1_first_be;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_dw_len               = inbd_hdr.radm_trgt1_dw_len;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_poisoned             = 1'b0;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_td                   = inbd_hdr.radm_trgt1_td;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_func_num             = {PKG_CX_NFUNC_WD{1'b0}};
      fn_rd_cdc_ram_reconstruction.radm_trgt1_lookup_id            = inbd_hdr.radm_trgt1_lookup_id;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_tag                  = inbd_hdr.radm_trgt1_tag;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_reqid                = inbd_hdr.radm_trgt1_reqid;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_nw                   = inbd_hdr.radm_trgt1_nw;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_cxlsrc               = inbd_hdr.radm_trgt1_cxlsrc;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_ats                  = inbd_hdr.radm_trgt1_ats;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_attr                 = inbd_hdr.radm_trgt1_attr;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_tc                   = inbd_hdr.radm_trgt1_tc;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_type                 = {2'd0, inbd_hdr.radm_trgt1_type};
      fn_rd_cdc_ram_reconstruction.radm_trgt1_fmt                  = {1'b0, inbd_hdr.radm_trgt1_fmt};
      fn_rd_cdc_ram_reconstruction.radm_trgt1_ecrc_err             = 1'b0;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_tlp_abort            = 1'b0;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_dllp_abort           = 1'b0;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_dwen                 = {PKG_CX_NW{1'b0}};
      fn_rd_cdc_ram_reconstruction.pseq_nbr                        = inbd_hdr.pseq_nbr;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_eot                  = 1'b1;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_dv                   = 1'b0;
      fn_rd_cdc_ram_reconstruction.radm_trgt1_hv                   = 1'b1;
    end
  endfunction : fn_rd_cdc_ram_reconstruction


endpackage : DWC_pcie_bridge_ib_pkg

`endif // __GUARD__DWC_PCIE_BRIDGE_IB_PKG__SVH__

