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
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_ctl.sv#20 $
// -------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 module DWC_pcie_amba_mstr_cpl_ctl
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter CX_REMOTE_MAX_TAGS                  = 8,
  parameter CX_REMOTE_MAX_TAGS_WD               = 3,
  parameter NSEGMENTS                           = 8,
  parameter NSEGMENTS_WD                        = 3,
  parameter CX_NFUNC                            = 8,
  parameter CX_NFUNC_WD                         = 3,
  parameter CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2= 2,
  parameter CC_MSTR_CPL_DATA_SEG_DP             = 10,
  parameter CC_MSTR_CPL_SEG_BUF_ADDR_WD         = 7,
  parameter CC_MSTR_CPL_SEG_DATA_NUM_DWORDS     = 2,
  parameter MSTR_CPL_SEG_BUF_INIT_SEG_SIZES     = 56,
  parameter CC_MSTR_CPL_QUEUE_DP                = 8,
  parameter CC_MSTR_CPL_QUEUE_DP_LOG2           = 3,
  // Master Completion Buffer Read Latency
  parameter CC_MSTR_CPL_SEG_BUF_RAM_RD_LATENCY  = `CC_MSTR_CPL_SEG_BUF_RAM_RD_LATENCY,
  // Registers the Master Completion Buffer RAM Write Control and Data and
  // Read Control Interface signals.
  parameter CC_MSTR_CPL_CTL_RAM_REGIN           = `CC_MSTR_CPL_CTL_RAM_REGIN,
  parameter DC_MCB_MAX_CPL_NUM_DWORDS_WD        = `DC_MCB_MAX_CPL_NUM_DWORDS_WD,
  parameter DC_CPL_STATUS_WD                    = `DC_CPL_STATUS_WD,
  parameter DC_TC_WD                            = `DC_TC_WD,
  parameter DC_DMA_TYPE_WIDTH                   = `DC_DMA_TYPE_WIDTH,
  parameter CC_NUM_DMA_RD_CHAN                  = `CC_NUM_DMA_RD_CHAN,
  parameter CC_NUM_DMA_WR_CHAN                  = `CC_NUM_DMA_WR_CHAN,
  parameter CC_NUM_DMA_RD_CHAN_WIDTH            = `CC_NUM_DMA_RD_CHAN_WIDTH,
  parameter CC_NUM_DMA_WR_CHAN_WIDTH            = `CC_NUM_DMA_WR_CHAN_WIDTH,
  parameter CC_NUM_DMA_MAX_CHAN_WIDTH           = `CC_NUM_DMA_MAX_CHAN_WIDTH,
  //Delay from SBC pop signal to the aligned RAM read data minus 1 cycle
  parameter MSTR_CPL_CTRL_DELAY                 =   CC_MSTR_CPL_SEG_BUF_RAM_RD_LATENCY
                                                  + CC_MSTR_CPL_CTL_RAM_REGIN
                                                  ,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                                  = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                             core_clk,                               // Clock synchronicity anotated below for all pins
  input                                             core_rst_n,                             // As of writing this comment, CX_MCCTL_CDC=1 implies and assumes CX_AXI_RCHUNK_ENABLE=1
  input                                             mstr_aclk,
  input                                             mstr_aresetn,
  // -------------------------------------------------------------------------------------
  // Configuration
  // -------------------------------------------------------------------------------------
  input [(3*CX_NFUNC)-1:0]                          cfg_max_payload_size,                   // quasi-static
  // -------------------------------------------------------------------------------------
  // Master non-posted request interface
  // -------------------------------------------------------------------------------------
  // radmx_ireq_np_dw_len_bytes: Total Number of DWORD's in bytes
  // radmx_ireq_np_4kb_start_addr: Lower 4KByte start address, byte aligned.
  input                                             radmx_mreq_np_valid,                    // core_clk
  input [CX_REMOTE_MAX_TAGS_WD-1:0]                 radmx_ireq_np_lookup_id,                // core_clk
  input [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]          radmx_ireq_np_4kb_start_addr,           // core_clk
  input [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]          radmx_ireq_np_dw_len_bytes,             // core_clk
  input [CX_NFUNC_WD-1:0]                           radmx_ireq_np_func,                     // core_clk
  input                                             radmx_ireq_np_ncbe,                     // core_clk
  input                                             radmx_mreq_np_last,                     // core_clk
  input [DC_DMA_TYPE_WIDTH-1:0]                     radmx_ireq_np_dma_type,                 // core_clk
  // -------------------------------------------------------------------------------------
  // Master completion response interface
  // -------------------------------------------------------------------------------------
  // Write data valid
  input                                             mcf_dv,                                 // mstr_aclk if CX_MCCTL_CDC else core_clk
  // Write segment number, value updated when write data valid is asserted.
  input [CX_REMOTE_MAX_TAGS_WD-1:0]                 mcf_wr_seg_num,                         // mstr_aclk if CX_MCCTL_CDC else core_clk
  input [`DC_CPL_STATUS_WD-1:0]                     mcf_status,                             // mstr_aclk if CX_MCCTL_CDC else core_clk
  input                                             mcf_ep,                                 // mstr_aclk if CX_MCCTL_CDC else core_clk
  input [`DC_TC_WD-1:0]                             mcf_tc,                                 // mstr_aclk if CX_MCCTL_CDC else core_clk
  input                                             mcf_error,                              // mstr_aclk if CX_MCCTL_CDC else core_clk
  input                                             mcf_last_pkt_beat,                      // mstr_aclk if CX_MCCTL_CDC else core_clk



  // Atomic operations flags
   // mcf_atop_wr_rsp = 1 when receiving an atomic response from the B channel.
   // mcf_atop_cpl_queue = 0 only when it has received the first response of an atomic operation
  input                                             mcf_atop_wr_rsp,                        // mstr_aclk if CX_MCCTL_CDC else core_clk
  input                                             mcf_atop_cpl_queue,                     // mstr_aclk if CX_MCCTL_CDC else core_clk
  output wire                                       mcctl_halt,                             // mstr_aclk if CX_MCCTL_CDC else core_clk
  // -------------------------------------------------------------------------------------
  // Segment buffer initialisation interface
  // -------------------------------------------------------------------------------------
  output wire                                       mcctl_sb_init_i,                        // quasi-static if CX_MCCTL_CDC else core_clk
  output wire [CX_REMOTE_MAX_TAGS_WD:0]             mcctl_sb_init_num_segs_i,               // quasi-static
  output wire [MSTR_CPL_SEG_BUF_INIT_SEG_SIZES-1:0] mcctl_sb_init_seg_sizes_i,              // quasi-static
  // -------------------------------------------------------------------------------------
  // Segment buffer push interface
  // -------------------------------------------------------------------------------------
  output wire                                       mcctl_sb_reset_push_ptr,                // quasi-static
  output wire                                       mcctl_sb_push_start_i,                  // mstr_aclk if CX_MCCTL_CDC else core_clk
  output wire                                       mcctl_sb_push_i,                        // mstr_aclk if CX_MCCTL_CDC else core_clk
  output wire                                       mcctl_sb_push_keep_i,                   // quasi-static
  output wire                                       mcctl_sb_push_drop_i,                   // quasi-static
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]           mcctl_sb_reset_push_seg_i,              // quasi-static
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]           mcctl_sb_push_seg_i,                    // mstr_aclk if CX_MCCTL_CDC else core_clk
  input [CX_REMOTE_MAX_TAGS-1:0]                    sbc_sb_full_m_1_o,                      // quasi-static if CX_MCCTL_CDC else core_clk
  input wire                                        sbc_sb_init_done_o,                     // quasi-static if CX_MCCTL_CDC else core_clk
  // -------------------------------------------------------------------------------------
  // Segment buffer pop interface
  // -------------------------------------------------------------------------------------
  output wire                                       mcctl_sb_reset_pop_ptr,                 // quasi-static
  output wire                                       mcctl_sb_pop_i,                         // core_clk
  output wire                                       mcctl_sb_pop_look_i,                    // quasi-static
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]           mcctl_sb_reset_pop_seg_i,               // quasi-static
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]           mcctl_sb_pop_seg_i,                     // core_clk
  input [CX_REMOTE_MAX_TAGS-1:0]                    sbc_sb_empty_o,                         // quasi-static if CX_MCCTL_CDC else core_clk
  input [CX_REMOTE_MAX_TAGS-1:0]                    sbc_sb_empty_p_1_o,                     // quasi-static if CX_MCCTL_CDC else core_clk
  input [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]       sbc_sb_pop_dw_en,                       // core_clk
  output wire                                       mcctl_sb_ram_rd_en,                     // core_clk
  // -------------------------------------------------------------------------------------
  // Client completion interface
  // -------------------------------------------------------------------------------------
  output wire                                       mcctl_hv,                               // core_clk
  output wire                                       mcctl_dv,                               // core_clk
  output wire                                       mcctl_eot,                              // core_clk
  output wire                                       mcctl_last,                             // core_clk
  output wire [`DC_FMT_WD-1:0]                      mcctl_fmt,                              // core_clk
  output wire [`DC_TYPE_WD-1:0]                     mcctl_type,                             // core_clk
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]           mcctl_ireq_np_lookup_id,                // core_clk
  output wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]    mcctl_dw_len_bytes,                     // core_clk
  output wire [`DC_CPL_STATUS_WD-1:0]               mcctl_status,                           // core_clk
  output wire [CX_NFUNC_WD-1:0]                     mcctl_func,                             // core_clk
  output wire                                       mcctl_ep,                               // core_clk
  output wire [`DC_TC_WD-1:0]                       mcctl_tc,                               // core_clk
  output wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]       mcctl_dma_chan,                         // core_clk
  output wire [DC_DMA_TYPE_WIDTH-1:0]               mcctl_dma_type,                         // core_clk
  input                                             halt                                    // core_clk
  // -------------------------------------------------------------------------------------
  // DMA CPL RORDR <-> MCB CTRL interfaces
  // -------------------------------------------------------------------------------------
  ,output logic                                     cpl_q_dma_wr_valid                      // core_clk
  ,output logic [CX_REMOTE_MAX_TAGS_WD-1:0]         cpl_q_dma_wr_seg_num                    // core_clk
  ,output logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0]  cpl_q_dma_wr_beat_len                   // core_clk
  ,output logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0]  cpl_q_dma_wr_dw_len                     // core_clk
  ,output logic [DC_CPL_STATUS_WD-1:0]              cpl_q_dma_wr_status                     // core_clk
  ,output logic                                     cpl_q_dma_wr_ep                         // core_clk
  ,output logic                                     cpl_q_dma_wr_last_pkt_beat              // core_clk
  ,output logic                                     cpl_q_dma_rd_ready                      // core_clk
  ,input  logic                                     cpl_q_dma_rd_valid                      // core_clk
  ,input  logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]     cpl_q_dma_rd_dma_chan                   // core_clk
  ,input  logic [DC_DMA_TYPE_WIDTH-1:0]             cpl_q_dma_rd_dma_type                   // core_clk
  ,input  logic [CX_REMOTE_MAX_TAGS_WD-1:0]         cpl_q_dma_rd_seg_num                    // core_clk
  ,input  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0]  cpl_q_dma_rd_beat_len                   // core_clk
  ,input  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0]  cpl_q_dma_rd_dw_len                     // core_clk
  ,input  logic [DC_CPL_STATUS_WD-1:0]              cpl_q_dma_rd_status                     // core_clk
  ,input  logic                                     cpl_q_dma_rd_ep                         // core_clk
  ,input  logic [DC_TC_WD-1:0]                      cpl_q_dma_rd_tc                         // core_clk
  ,input  logic                                     cpl_q_dma_rd_last_pkt_beat              // core_clk
);

// -------------------------------------------------------------------------------------
// Type definitions
// -------------------------------------------------------------------------------------
 typedef struct packed {
   logic [CX_REMOTE_MAX_TAGS_WD-1:0]        seg_num       ;
   logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] beat_len      ;
   logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] dw_len        ;
   logic [DC_CPL_STATUS_WD-1:0]             status        ;
   logic                                    ep            ;
   logic [DC_TC_WD-1:0]                     tc            ;
   logic                                    last_pkt_beat ;
 } cpl_queue_s;


  typedef struct packed {
    logic                              dv;
    logic [CX_REMOTE_MAX_TAGS_WD -1:0] wr_seg_num;
    logic     [`DC_CPL_STATUS_WD -1:0] status;
    logic                              ep;
    logic              [`DC_TC_WD-1:0] tc;
    logic                              error;
    logic                              last_pkt_beat;
    logic                              atop_wr_rsp;
    logic                              atop_cpl_queue;
  } mcf_t;

  typedef struct packed {
    logic                                        start;
    logic                                        en;
    logic           [CX_REMOTE_MAX_TAGS_WD -1:0] seg;
    logic                                        init;
    logic         [CX_REMOTE_MAX_TAGS_WD+1 -1:0] init_num_segs;
    logic [MSTR_CPL_SEG_BUF_INIT_SEG_SIZES -1:0] init_seg_sizes;
  } sbPush_t;

  typedef struct packed {
    logic                              en;
    logic [CX_REMOTE_MAX_TAGS_WD -1:0] seg;
    logic                              ram_rd_en;
  } sbPop_t;

  typedef struct packed {
    logic    [CX_REMOTE_MAX_TAGS -1:0] full_m1;
    logic    [CX_REMOTE_MAX_TAGS -1:0] empty;
    logic    [CX_REMOTE_MAX_TAGS -1:0] empty_p1;
    logic                              init_done;
  } sbFlags_t;

  typedef struct packed {
    logic                                  q_valid;
    cpl_queue_s                            q;
    logic                                  dma_valid;
    cpl_queue_s                            dma;
    logic [CC_NUM_DMA_MAX_CHAN_WIDTH -1:0] dma_chan;
    logic         [DC_DMA_TYPE_WIDTH -1:0] dma_type;
    logic                                  atop_cpl_queue;
    logic                                  error;
  } cplQ_t;

  typedef struct packed {
    logic                              valid;
    logic [CX_REMOTE_MAX_TAGS_WD-1:0]  lookup_id;
    logic [DC_DMA_TYPE_WIDTH-1:0]      dma_type;
  } wrMreq_t;

  typedef struct packed {
    logic                              valid;
    logic [CX_REMOTE_MAX_TAGS_WD-1:0]  lookup_id;
    logic [CX_NFUNC_WD-1:0]            func;
  } rdMreq_t;

  typedef struct packed {
    logic                                    valid;
    logic [CX_REMOTE_MAX_TAGS_WD-1:0]        lookup_id;
    logic [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0] dw_len_bytes;
    logic [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0] s_4kb_start_addr;
    logic                                    ncbe;
    logic [CX_NFUNC_WD-1:0]                  func;
    logic                                    last;
    logic            [DC_DMA_TYPE_WIDTH-1:0] dma_type;
  } lutMreq_t;

  typedef struct packed {
    logic    [CX_REMOTE_MAX_TAGS -1:0] pop;
    logic [CX_REMOTE_MAX_TAGS_WD -1:0] lookup_tag;
    logic                              atop_cpl_queue;
  } lutCtl_t;

  typedef struct packed {
    logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_beat_len;
    logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_beat_len;
    logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_dw_len;
    logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_rem_dw_len;
  } lutInnerData_t;

  typedef struct packed {
    logic          first_mreq_np_valid;
    lutInnerData_t w_ctl;
    lutInnerData_t w_mreq;
  } lutData_t;

  typedef struct packed {
    logic q_pop;
    logic dma_pop;
    logic halt;
  } cplQPop_t;

  typedef struct packed {
    logic hv;
    logic dv;
    logic eot;
    logic [CX_NFUNC_WD -1:0] func;
    logic last;
  } rdCtl_t;


  typedef struct packed {
    logic                                     hv;
    logic                                     dv;
    logic                                     eot;
    logic                                     last;
    logic                   [`DC_FMT_WD -1:0] fmt;
    logic                  [`DC_TYPE_WD -1:0] stype;
    logic        [CX_REMOTE_MAX_TAGS_WD -1:0] lookup_id;
    logic [`DC_MCB_MAX_CPL_NUM_BYTES_WD -1:0] dw_len_bytes;
    logic            [`DC_CPL_STATUS_WD -1:0] status;
    logic                  [CX_NFUNC_WD -1:0] func;
    logic                                     ep;
    logic                     [`DC_TC_WD-1:0] tc;
    logic    [CC_NUM_DMA_MAX_CHAN_WIDTH -1:0] dma_chan;
    logic            [DC_DMA_TYPE_WIDTH -1:0] dma_type;
  } mcctl_t;


// -------------------------------------------------------------------------------------
// Internal wires/regs
// -------------------------------------------------------------------------------------
  logic mcbwr_clk;
  logic mcbwr_rst_n;

   wire [CX_REMOTE_MAX_TAGS-1:0]             segm_sb_full_m_1_o;
   wire [CX_REMOTE_MAX_TAGS-1:0]             segm_sb_empty_o;
   wire [CX_REMOTE_MAX_TAGS-1:0]             segm_sb_empty_p_1_o;

  // Create data structs

  // 1. Split CPL LUTs
  lutMreq_t   s_lut_mreq;
  lutCtl_t    s_lut_ctl;
  lutData_t   s_lut_data;

  // 2. WR Control
  mcf_t       s_wr_mcf;
  logic       s_wr_mcf_halt;
  wrMreq_t    s_wr_mreq;
  sbPush_t    s_sb_push;
  sbPop_t     s_sb_pop;
  sbFlags_t   s_sb_flags;

  // 3. CPL Queue
  cplQ_t      s_cplq_wr;
  logic       s_cplq_wr_halt;
  cplQ_t      so_cplq_dma;
  cplQ_t      si_cplq_dma;
  logic       s_cplq_dma_pop;
  cplQ_t      s_cplq_rd;
  cplQPop_t   s_cplq_pop;

  // 4. RD Control
  rdMreq_t s_rd_mreq;
  rdCtl_t  s_rd_ndly_ctl;
  cplQ_t   s_rd_ndly_q;

  // 5. Alignment of RD Control with RD Data
  mcctl_t  s_mcctl;

  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------
  assign mcbwr_clk = core_clk;
  assign mcbwr_rst_n = core_rst_n;

   assign segm_sb_full_m_1_o  = sbc_sb_full_m_1_o;
   assign segm_sb_empty_o     = sbc_sb_empty_o;
   assign segm_sb_empty_p_1_o = sbc_sb_empty_p_1_o;

  // ---------------------------------------------------------------------------------------
  // 1. Split CPL LUTs
  // ---------------------------------------------------------------------------------------
  // 1.1. Assign from inputs
  assign s_lut_mreq = lutMreq_t'{
    valid           : radmx_mreq_np_valid
   ,lookup_id       : radmx_ireq_np_lookup_id
   ,dw_len_bytes    : radmx_ireq_np_dw_len_bytes
   ,s_4kb_start_addr: radmx_ireq_np_4kb_start_addr
   ,ncbe            : radmx_ireq_np_ncbe
   ,func            : radmx_ireq_np_func
   ,last            : radmx_mreq_np_last
   ,dma_type        : radmx_ireq_np_dma_type
  };

  // 1.2. Instantiate logic
  DWC_pcie_amba_mstr_cpl_ctl_luts
   #(
    .P_MREQ_TYPE                          ( lutMreq_t                            )
   ,.P_CTL_TYPE                           ( lutCtl_t                             )
   ,.P_DATA_TYPE                          ( lutData_t                            )
   ,.P_INNER_DATA_TYPE                    ( lutInnerData_t                       )
   ,.CX_REMOTE_MAX_TAGS                   ( CX_REMOTE_MAX_TAGS                   )
   ,.CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 ( CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 )
   ,.CX_NFUNC                             ( CX_NFUNC                             )
  ) u_luts (
    .i_clk                  ( core_clk             )
   ,.i_rst_n                ( core_rst_n           )

   ,.i_cfg_max_payload_size ( cfg_max_payload_size )

   ,.i_mreq                 ( s_lut_mreq           )

   ,.i_ctl                  ( s_lut_ctl            )
   ,.o_data                 ( s_lut_data           )
  );

  // 1.3. Assign to outputs - no outputs to assign

  // ---------------------------------------------------------------------------------------
  // 2. WR control
  // ---------------------------------------------------------------------------------------
  // 2.1. Assign from inputs
  assign s_wr_mreq = wrMreq_t'{
    valid    : radmx_mreq_np_valid
   ,lookup_id: radmx_ireq_np_lookup_id
   ,dma_type : radmx_ireq_np_dma_type
  };

  assign s_wr_mcf = mcf_t'{
    dv            : mcf_dv
   ,wr_seg_num    : mcf_wr_seg_num
   ,status        : mcf_status
   ,ep            : mcf_ep
   ,tc            : mcf_tc
   ,error         : mcf_error
   ,last_pkt_beat : mcf_last_pkt_beat
   ,atop_wr_rsp   : mcf_atop_wr_rsp
   ,atop_cpl_queue: mcf_atop_cpl_queue
  };

  assign s_sb_flags = sbFlags_t'{
    init_done: sbc_sb_init_done_o
   ,full_m1  : segm_sb_full_m_1_o
   ,empty_p1 : segm_sb_empty_p_1_o
   ,empty    : segm_sb_empty_o
  };

  // 2.2. Instantiate logic
  // Control path from mcf into RAM WR and CPLQ WR
  DWC_pcie_amba_mstr_cpl_ctl_wr
   #(
    .P_MCF_TYPE              ( mcf_t                       )
   ,.P_SB_PUSH_TYPE          ( sbPush_t                    )
   ,.P_SB_POP_TYPE           ( sbPop_t                     )
   ,.P_LUT_CTL_TYPE          ( lutCtl_t                    )
   ,.P_LUT_DATA_TYPE         ( lutData_t                   )
   ,.P_SB_FLAGS_TYPE         ( sbFlags_t                   )
   ,.P_CPLQ_TYPE             ( cplQ_t                      )
   ,.P_CPLQ_INFO_TYPE        ( cpl_queue_s                 )
   ,.P_MREQ_TYPE             ( wrMreq_t                    )
   ,.CX_REMOTE_MAX_TAGS      ( CX_REMOTE_MAX_TAGS          )
   ,.CX_REMOTE_MAX_TAGS_WD   ( CX_REMOTE_MAX_TAGS_WD       )
   ,.P_NUM_SEGS              ( CX_REMOTE_MAX_TAGS          )
   ,.P_SEG_SIZE_WD           ( CC_MSTR_CPL_SEG_BUF_ADDR_WD )
   ,.CC_MSTR_CPL_DATA_SEG_DP ( CC_MSTR_CPL_DATA_SEG_DP     )
  ) u_wr (
    .i_clk       ( mcbwr_clk      )
   ,.i_rst_n     ( mcbwr_rst_n    )

   ,.i_mreq      ( s_wr_mreq      )

    // MCF interface <-> u_mcf
   ,.i_mcf       ( s_wr_mcf       )
   ,.o_mcf_halt  ( s_wr_mcf_halt  )

    // SBC pop interface for legacy-mode pipelining
   ,.i_sb_pop    ( s_sb_pop       )

    // SBC push interface --> u_sbc / u_chunkwr
   ,.i_sb_flags  ( s_sb_flags     )
   ,.o_sb_push   ( s_sb_push      )

   ,.o_lut_ctl   ( s_lut_ctl      )
   ,.i_lut_data  ( s_lut_data     )

    // CPLQ WR interface <-> u_cplq
   ,.o_cplq_wr   ( s_cplq_wr      )
   ,.i_cplq_halt ( s_cplq_wr_halt )
  );

  // 2.3. Assign to outputs
  // Connect u_wr.o_sb_push to output
  assign mcctl_sb_reset_push_ptr   = '0;
  assign mcctl_sb_reset_push_seg_i = '0;
  assign mcctl_sb_push_start_i     = s_sb_push.start;
  assign mcctl_sb_push_i           = s_sb_push.en;
  assign mcctl_sb_push_keep_i      = s_sb_push.en;
  assign mcctl_sb_push_drop_i      = 1'b0;
  assign mcctl_sb_init_i           = s_sb_push.init;
  assign mcctl_sb_init_num_segs_i  = s_sb_push.init_num_segs;
  assign mcctl_sb_init_seg_sizes_i = s_sb_push.init_seg_sizes;
  assign mcctl_sb_push_seg_i       = s_sb_push.seg;
  // mcf interface halt
  assign mcctl_halt                = s_wr_mcf_halt;

  // ---------------------------------------------------------------------------------------
  // 3. CPL Queue
  // ---------------------------------------------------------------------------------------
  // CPL wr-rd-decoupling FIFO, split CPL generation, CDC if RCHUNK and MSTR_CLK_DIFF
  // 3.1. Assign from inputs - DMA only
  // Connect DMA reorder interface inputs
  assign si_cplq_dma = cplQ_t'{
    default: '0
   ,dma_valid         : cpl_q_dma_rd_valid
   ,dma_chan          : cpl_q_dma_rd_dma_chan
   ,dma_type          : cpl_q_dma_rd_dma_type
   ,dma               : cpl_queue_s'{
                          default       : '0
                         ,seg_num       : cpl_q_dma_rd_seg_num
                         ,beat_len      : cpl_q_dma_rd_beat_len
                         ,dw_len        : cpl_q_dma_rd_dw_len
                         ,status        : cpl_q_dma_rd_status
                         ,ep            : cpl_q_dma_rd_ep
                         ,tc            : cpl_q_dma_rd_tc
                         ,last_pkt_beat : cpl_q_dma_rd_last_pkt_beat
                        }
  };

  // 3.2. Instantiate logic
  DWC_pcie_amba_mstr_cpl_ctl_cplq
   #(
    .P_CPLQ_TYPE               ( cplQ_t                    )
   ,.P_CPLQ_INFO_TYPE          ( cpl_queue_s               )
   ,.P_CPLQ_POP_TYPE           ( cplQPop_t                 )
   ,.CC_MSTR_CPL_QUEUE_DP      ( CC_MSTR_CPL_QUEUE_DP      )
   ,.CC_MSTR_CPL_QUEUE_DP_LOG2 ( CC_MSTR_CPL_QUEUE_DP_LOG2 )
  ) u_cplq (
    .i_wr_clk        ( mcbwr_clk        )
   ,.i_wr_rst_n      ( mcbwr_rst_n      )
   ,.i_rd_clk        ( core_clk         )
   ,.i_rd_rst_n      ( core_rst_n       )

    // CPLQ WR interface <-> u_wr
   ,.i_cplq_wr       ( s_cplq_wr        )
   ,.o_cplq_wr_halt  ( s_cplq_wr_halt   )


    // CPLQ DMA Reorder interface
   ,.o_cplq_dma      ( so_cplq_dma      )
   ,.i_cplq_dma      ( si_cplq_dma      )
   ,.o_cplq_dma_pop  ( s_cplq_dma_pop   )

    // CPLQ RD interface <-> u_rd
   ,.o_cplq_rd       ( s_cplq_rd        )
   ,.i_cplq_pop      ( s_cplq_pop       )
  );

  // 3.3. Assign to outputs - DMA only
  // Connect DMA reorder interface outputs
assign cpl_q_dma_wr_valid            = so_cplq_dma.dma_valid;
assign cpl_q_dma_wr_seg_num          = so_cplq_dma.dma.seg_num;
assign cpl_q_dma_wr_beat_len         = so_cplq_dma.dma.beat_len;
assign cpl_q_dma_wr_dw_len           = so_cplq_dma.dma.dw_len;
assign cpl_q_dma_wr_status           = so_cplq_dma.dma.status;
assign cpl_q_dma_wr_ep               = so_cplq_dma.dma.ep;
assign cpl_q_dma_wr_last_pkt_beat    = so_cplq_dma.dma.last_pkt_beat;

assign cpl_q_dma_rd_ready            = s_cplq_dma_pop;

  // ---------------------------------------------------------------------------------------
  // 4. Read Control
  // ---------------------------------------------------------------------------------------
  // 4.1. Assign from inputs
  assign s_rd_mreq = rdMreq_t'{
    valid    : radmx_mreq_np_valid
   ,lookup_id: radmx_ireq_np_lookup_id
   ,func     : radmx_ireq_np_func
  };


  // 4.2. Instantiate logic
  // Control path from CPLQ to RAM RD
  DWC_pcie_amba_mstr_cpl_ctl_rd
   #(
    .P_CPLQ_TYPE        ( cplQ_t             )
   ,.P_CPLQ_POP_TYPE    ( cplQPop_t          )
   ,.P_SB_POP_TYPE      ( sbPop_t            )
   ,.P_SB_FLAGS_TYPE    ( sbFlags_t          )
   ,.P_RD_CTL_TYPE      ( rdCtl_t            )
   ,.P_MREQ_TYPE        ( rdMreq_t           )
   ,.P_SB_PUSH_TYPE     ( sbPush_t           )
   ,.CX_REMOTE_MAX_TAGS ( CX_REMOTE_MAX_TAGS )
   ,.CX_NFUNC_WD        ( CX_NFUNC_WD        )
  ) u_rd (
    .i_clk         ( core_clk             )
   ,.i_rst_n       ( core_rst_n           )

   ,.i_mreq        ( s_rd_mreq            )

   ,.i_cplq        ( s_cplq_rd            )
   ,.o_cplq_pop    ( s_cplq_pop           )

   ,.i_sb_push     ( s_sb_push            )

    // SBC pop interface <-> u_sbc / u_chunkrd + u_rd_ltcy
   ,.o_sb_pop      ( s_sb_pop             )
   ,.i_sb_flags    ( s_sb_flags           )
   ,.i_halt        ( halt                 )

   ,.o_rd_ndly_ctl ( s_rd_ndly_ctl        )
   ,.o_rd_ndly_q   ( s_rd_ndly_q          )
  );

  // 4.3. Assign to outputs
assign mcctl_sb_pop_i             = s_sb_pop.en;
assign mcctl_sb_reset_pop_ptr     = 1'b0;
assign mcctl_sb_reset_pop_seg_i   = '0;
assign mcctl_sb_pop_look_i        = 1'b0;
assign mcctl_sb_pop_seg_i         = s_sb_pop.seg;
// Select synchronous segment buffer RAM on read transfers.
assign mcctl_sb_ram_rd_en         = s_sb_pop.ram_rd_en;

  // ---------------------------------------------------------------------------------------
  // 5. Alignment of Read Control with Read Data
  // ---------------------------------------------------------------------------------------
  // 5.1. Assign from inputs - no inputs to assign

  // 5.2. Instantiate logic
  // Control path from RAM RD to datapath-out
  DWC_pcie_amba_mstr_cpl_ctl_rd_dly
   #(
    .P_CPLQ_TYPE                     ( cplQ_t                          )
   ,.P_RD_CTL_TYPE                   ( rdCtl_t                         )
   ,.P_MCCTL_TYPE                    ( mcctl_t                         )
   ,.CC_MSTR_CPL_SEG_DATA_NUM_DWORDS ( CC_MSTR_CPL_SEG_DATA_NUM_DWORDS )
   ,.MSTR_CPL_CTRL_DELAY             ( MSTR_CPL_CTRL_DELAY             )
  ) u_rd_dly (
    .i_clk         ( core_clk         )
   ,.i_rst_n       ( core_rst_n       )

    // SBC pop interface <-- u_rd / u_sbc (legacy) / u_chunkrd (axi-g)
   ,.i_rd_ndly_ctl ( s_rd_ndly_ctl    )
   ,.i_rd_ndly_q   ( s_rd_ndly_q      )
   ,.i_sb_dwen     ( sbc_sb_pop_dw_en )

    // SBC control latency-delayed --> u_rrlb
   ,.o_mcctl       ( s_mcctl          )
  );

  // 5.3. Assign to outputs
assign mcctl_hv                = s_mcctl.hv;
assign mcctl_dv                = s_mcctl.dv;
assign mcctl_eot               = s_mcctl.eot;
assign mcctl_last              = s_mcctl.last;
assign mcctl_fmt               = s_mcctl.fmt;
assign mcctl_type              = s_mcctl.stype;
assign mcctl_ireq_np_lookup_id = s_mcctl.lookup_id;
assign mcctl_dw_len_bytes      = s_mcctl.dw_len_bytes;
assign mcctl_status            = s_mcctl.status;
assign mcctl_func              = s_mcctl.func;
assign mcctl_ep                = s_mcctl.ep;
assign mcctl_tc                = s_mcctl.tc;
assign mcctl_dma_chan          = s_mcctl.dma_chan;
assign mcctl_dma_type          = s_mcctl.dma_type;

endmodule
