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
// ---    $DateTime: 2023/11/03 11:28:55 $ 
// ---    $Revision: #6 $ 
// ---    $Author: jduarte $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_presp_redo.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Axi/DWC_pcie_axi_mstr_pkg.svh"

// Module description:

// DESIGN DOCUMENTATION: See P80001562-136307
module DWC_pcie_axi_presp_redo
  import DWC_pcie_axi_mstr_pkg::*;
  #(
    parameter TP = `TP

    // -------------------------------------------------------------------------------------
    // Pipeline configuration
    // -------------------------------------------------------------------------------------
   ,parameter P_INPUT_PIPE_M_INTF          = 1
   ,parameter P_INPUT_PIPE_B_INTF          = 1
   ,parameter P_OUTPUT_PIPE_PRESP_INTF     = 1

    // -------------------------------------------------------------------------------------
    // Data Type configuration
    // -------------------------------------------------------------------------------------
   ,parameter CC_AMBA_TLP_SEQ_WD           = 1
   ,parameter P_N_PRESP_STREAMS            = 1
   ,parameter P_N_PRESP_STREAMS_WD         = 1
   ,parameter P_N_PRESP_STREAMS_W_RO_WD    = 1
   ,parameter DC_DMA_TYPE_WIDTH            = 1
   ,parameter CC_NUM_DMA_RD_CHAN           = 1
   ,parameter CC_NUM_DMA_RD_CHAN_WIDTH     = 1
   ,parameter CC_NUM_DMA_MAX_CHAN_WIDTH    = 1
   ,parameter P_SYN_GOAL                   = 4

    // -------------------------------------------------------------------------------------
    // Queue Size configuration
    // -------------------------------------------------------------------------------------
   ,parameter CC_WR_CH_P_REQ_QUEUE_DP      = 1
   ,parameter CC_WR_CH_P_REQ_QUEUE_DP_LOG2 = 1
  ) (
    // -------------------------------------------------------------------------------------
    // Clocking
    // -------------------------------------------------------------------------------------
    input  logic                                  i_clk
   ,input  logic                                  i_rst_n

    // -------------------------------------------------------------------------------------
    // IBREQ Request Interface
    // -------------------------------------------------------------------------------------
   ,input  logic                                  i_mvalid
   ,input  logic                                  i_mready
   ,input  logic                                  i_m_is_posted
   ,input  logic        [CC_AMBA_TLP_SEQ_WD -1:0] i_mpseq
   ,input  logic                                  i_mwrite
   ,input  logic                                  i_mabort
   ,input  logic                                  i_mlast_tlp
   ,input  logic      [P_N_PRESP_STREAMS_WD -1:0] i_mstream
   ,input  logic         [DC_DMA_TYPE_WIDTH -1:0] i_mdma
   ,input  logic [CC_NUM_DMA_MAX_CHAN_WIDTH -1:0] i_mdma_chan
   ,input  logic                                  i_relax_order
   ,output logic                                  o_presp_mstall

    // -------------------------------------------------------------------------------------
    // AXI BCh Response Interface
    // -------------------------------------------------------------------------------------
   ,input  logic                                  i_bvalid
   ,input  logic                                  i_bready
   ,input  logic                                  i_bid_posted
   ,input  logic                         [2 -1:0] i_bresp
   ,input  logic [P_N_PRESP_STREAMS_W_RO_WD -1:0] i_bstream
   ,output logic                                  o_presp_sstall

    // -------------------------------------------------------------------------------------
    // IBREQ Response Interface
    // -------------------------------------------------------------------------------------
   ,output logic                                  o_presp_cmplt
   ,output logic        [CC_AMBA_TLP_SEQ_WD -1:0] o_presp_rpseq
   ,output logic      [P_N_PRESP_STREAMS_WD -1:0] o_presp_stream
   ,output logic                                  o_presp_type_dma
   ,output logic  [CC_NUM_DMA_RD_CHAN_WIDTH -1:0] o_presp_dma_chan_num
   ,output logic                                  o_presp_dma_err
   ,output logic                                  o_presp_empty
   ,input  logic                                  i_rtime_cdc_alm_halt
   ,input  logic                                  i_rtime_cdc_halt

    // -------------------------------------------------------------------------------------
    // Relaxed Tag Ordering Interface
    // -------------------------------------------------------------------------------------
   ,output logic                                  o_ro_tag_valid
   ,output logic [P_N_PRESP_STREAMS_W_RO_WD -1:0] o_ro_tag
  );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam L_N_PRESP_STREAMS         = 1 -1 + P_N_PRESP_STREAMS ;
  localparam L_N_PRESP_STREAMS_WD      = 1 -1 + P_N_PRESP_STREAMS_WD ;
  localparam L_N_PRESP_STREAMS_W_RO_WD = CC_WR_CH_P_REQ_QUEUE_DP_LOG2 - CC_WR_CH_P_REQ_QUEUE_DP_LOG2 + P_N_PRESP_STREAMS_W_RO_WD ;
  localparam L_IDO_STREAM_RANGE_LOW    = K_SEQN_RANGE_IB_IDO_LOW;
  localparam L_IDO_STREAM_RANGE_HIGH   = K_SEQN_RANGE_IB_IDO_HIGH;
  localparam L_NVC_STREAMS             = K_N_IB_VC_STREAMS;

  typedef enum logic [1:0] {
    // { P_BACKPRESSURE_BCH, P_LOW_LATENCY_RESP }
    E_GOAL_TIMING = 2'b00
   ,E_GOAL_PERF   = 2'b01
   ,E_GOAL_QOR    = 2'b10
   ,E_GOAL_AREA   = 2'b11
  } synGoal_e;

  localparam synGoal_e L_GOAL_AUTO = (L_N_PRESP_STREAMS <= 8) ? E_GOAL_AREA : E_GOAL_TIMING;

  localparam synGoal_e L_SYN_GOAL = (P_SYN_GOAL == 3) ? E_GOAL_AREA   :
                                    (P_SYN_GOAL == 2) ? E_GOAL_QOR    :
                                    (P_SYN_GOAL == 1) ? E_GOAL_PERF   :
                                    (P_SYN_GOAL == 0) ? E_GOAL_TIMING :
                                                        L_GOAL_AUTO;

  localparam L_BACKPRESSURE_BCH = L_SYN_GOAL inside {E_GOAL_QOR , E_GOAL_AREA} ? 1 : 0;
  localparam L_LOW_LATENCY_RESP = L_SYN_GOAL inside {E_GOAL_PERF, E_GOAL_AREA} ? 1 : 0;

  // -------------------------------------------------------------------------------------
  // Type declarations
  // -------------------------------------------------------------------------------------



  typedef struct packed {
    logic                                 v;
    logic [CC_NUM_DMA_RD_CHAN_WIDTH -1:0] chan;
    logic                                 err;
  } nativeDataDmaBus_s;


  typedef struct packed {
    logic       [CC_AMBA_TLP_SEQ_WD -1:0] pseq;
    logic                                 is_last;
    logic                                 is_autopop;
    logic     [L_N_PRESP_STREAMS_WD -1:0] stream;
    nativeDataDmaBus_s                    dma;
    logic                                 is_abort;
  } nativeDataBus_s;

  typedef struct packed {
    logic                                 v;
    logic                                 is_relax_order;
  } nativeReqCtrlBus_s;

  typedef struct packed {
    logic                                 v;
    logic                                 is_empty;
  } nativeRespCtrlBus_s;

  typedef struct packed {
    nativeReqCtrlBus_s                    ctrl;
    nativeDataBus_s                       data;
  } nativeReqBus_s;

  typedef struct packed {
    nativeRespCtrlBus_s                   ctrl;
    nativeDataBus_s                       data;
  } nativeRespBus_s;

  typedef struct packed {
    logic                                  v;
    logic                         [2 -1:0] resp;
    logic [L_N_PRESP_STREAMS_W_RO_WD -1:0] stream;
  } nativeBRespBus_s;

  // -------------------------------------------------------------------------------------
  // Internal signal declaration
  // -------------------------------------------------------------------------------------
  nativeReqBus_s                         w_nativeReq;
  logic                                  w_nativeReq_halt;

  nativeRespBus_s                        w_nativeResp;
  logic                                  w_nativeResp_halt;

  nativeBRespBus_s                       w_nativeBResp;
  logic                                  w_nativeBResp_halt;

  logic                                  w_nativeROTag_valid;
  logic [P_N_PRESP_STREAMS_W_RO_WD -1:0] w_nativeROTag;


  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // 1. Assign input interfaces

  assign w_nativeReq = nativeReqBus_s'{
    ctrl: nativeReqCtrlBus_s'{
      v: (i_mvalid & i_mready & i_m_is_posted)
         || (i_mwrite && i_mabort)
     ,is_relax_order: i_relax_order 
    }
   ,data: nativeDataBus_s'{
      pseq: i_mpseq
     ,is_last: i_mlast_tlp
     ,is_autopop: 1'b0
                  || (i_mwrite && i_mabort)
     ,stream: i_mstream
     ,dma: nativeDataDmaBus_s'{
        v: |i_mdma
       ,chan: i_mdma_chan[CC_NUM_DMA_RD_CHAN_WIDTH-1:0]
       ,err: 1'b0
      }
     ,is_abort: (i_mwrite && i_mabort)
    }
  };

  assign o_presp_mstall = w_nativeReq_halt;

  assign w_nativeBResp = nativeBRespBus_s'{
    v: (i_bvalid & i_bready & i_bid_posted)
   ,resp: i_bresp
   ,stream: i_bstream
  };

  // 2. Instantiate native presp logic
  DWC_pcie_axi_presp_core
   #(
    .P_INPUT_PIPE_REQ_INTF     (P_INPUT_PIPE_M_INTF)
   ,.P_INPUT_PIPE_BRESP_INTF   (P_INPUT_PIPE_B_INTF)
   ,.P_OUTPUT_PIPE_RESP_INTF   (P_OUTPUT_PIPE_PRESP_INTF)

   ,.P_DATA_BUS_TYPE           (nativeDataBus_s)
   ,.P_REQ_BUS_TYPE            (nativeReqBus_s)
   ,.P_RESP_BUS_TYPE           (nativeRespBus_s)
   ,.P_BRESP_BUS_TYPE          (nativeBRespBus_s)
   ,.P_DMA_DATA_BUS_TYPE       (nativeDataDmaBus_s)

   ,.P_N_PRESP_STREAMS         (L_N_PRESP_STREAMS)
   ,.P_N_PRESP_STREAMS_WD      (L_N_PRESP_STREAMS_WD)
   ,.P_N_PRESP_STREAMS_W_RO_WD (L_N_PRESP_STREAMS_W_RO_WD)
   ,.P_QUEUE_DP                (CC_WR_CH_P_REQ_QUEUE_DP)
   ,.P_QUEUE_DP_WD             (CC_WR_CH_P_REQ_QUEUE_DP_LOG2)
   ,.P_NVC_STREAMS             (L_NVC_STREAMS)
   ,.P_NUM_DMA_RD_CHAN         (CC_NUM_DMA_RD_CHAN)

   ,.P_BACKPRESSURE_BCH        (L_BACKPRESSURE_BCH)
   ,.P_LOW_LATENCY_RESP        (L_LOW_LATENCY_RESP)
  ) u_presp_core (
    .i_clk          (i_clk)
   ,.i_rst_n        (i_rst_n)

   ,.i_req          (w_nativeReq)
   ,.o_req_halt     (w_nativeReq_halt)

   ,.i_bresp        (w_nativeBResp)
   ,.o_bresp_halt   (w_nativeBResp_halt)

   ,.o_resp         (w_nativeResp)
   ,.i_resp_halt    (w_nativeResp_halt)

   ,.o_ro_tag_valid (w_nativeROTag_valid)
   ,.o_ro_tag       (w_nativeROTag)
  );

  // 3. Assign output interface
  assign o_presp_cmplt           = w_nativeResp.ctrl.v & w_nativeResp.data.is_last 
 ;
  assign o_presp_rpseq           = w_nativeResp.data.pseq;
  assign o_presp_stream          = w_nativeResp.data.stream;
  assign o_presp_type_dma        = w_nativeResp.data.dma.v;
  assign o_presp_dma_chan_num    = w_nativeResp.data.dma.chan;
  assign o_presp_dma_err         = w_nativeResp.data.dma.err;
  assign o_presp_type_abort      = w_nativeResp.data.is_abort;
  assign o_presp_empty           = w_nativeResp.ctrl.is_empty;
  assign o_ro_tag_valid          = w_nativeROTag_valid;
  assign o_ro_tag                = w_nativeROTag;

  assign w_nativeResp_halt       = 1'b0
                                   | i_rtime_cdc_halt
                                   ;

  assign o_presp_sstall          = w_nativeBResp_halt;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_axi_presp_redo
