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
// ---    $DateTime: 2023/09/27 02:27:25 $ 
// ---    $Revision: #2 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_presp_core.sv#2 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Axi/DWC_pcie_axi_mstr_pkg.svh"

// Module description:

// DESIGN DOCUMENTATION: See P80001562-136307
module DWC_pcie_axi_presp_core
  import DWC_pcie_axi_mstr_pkg::*;
  #(
    parameter TP = `TP

    // -------------------------------------------------------------------------------------
    // Pipeline configuration
    // -------------------------------------------------------------------------------------
   ,parameter      P_INPUT_PIPE_REQ_INTF     = 1
   ,parameter      P_INPUT_PIPE_BRESP_INTF   = 1
   ,parameter      P_OUTPUT_PIPE_RESP_INTF   = 1

    // -------------------------------------------------------------------------------------
    // Data Type configuration
    // -------------------------------------------------------------------------------------
   ,parameter type P_DATA_BUS_TYPE           = logic
   ,parameter type P_REQ_BUS_TYPE            = logic
   ,parameter type P_RESP_BUS_TYPE           = logic
   ,parameter type P_BRESP_BUS_TYPE          = logic
   ,parameter type P_DMA_DATA_BUS_TYPE       = logic

    // -------------------------------------------------------------------------------------
    // Queue Size configuration
    // -------------------------------------------------------------------------------------
   ,parameter      P_N_PRESP_STREAMS         = 1
   ,parameter      P_N_PRESP_STREAMS_WD      = 1
   ,parameter      P_N_PRESP_STREAMS_W_RO_WD = 1
   ,parameter      P_QUEUE_DP                = 1
   ,parameter      P_QUEUE_DP_WD             = 1
   ,parameter      P_NVC_STREAMS             = 1
   ,parameter      P_NUM_DMA_RD_CHAN         = 1
   ,parameter      P_LOW_LATENCY_RESP        = (P_N_PRESP_STREAMS <= 8) ? 1 : 0
   ,parameter      P_BACKPRESSURE_BCH        = P_LOW_LATENCY_RESP ? 1 : 0
  ) (
    // -------------------------------------------------------------------------------------
    // Clocking
    // -------------------------------------------------------------------------------------
    input  logic                                  i_clk
   ,input  logic                                  i_rst_n

    // -------------------------------------------------------------------------------------
    // Bus Interfaces
    // -------------------------------------------------------------------------------------
   ,input  P_REQ_BUS_TYPE                         i_req
   ,output logic                                  o_req_halt

   ,input  P_BRESP_BUS_TYPE                       i_bresp
   ,output logic                                  o_bresp_halt

   ,output P_RESP_BUS_TYPE                        o_resp
   ,input  logic                                  i_resp_halt

    // -------------------------------------------------------------------------------------
    // Relaxed Tag Ordering Interface
    // -------------------------------------------------------------------------------------
   ,output logic                                  o_ro_tag_valid
   ,output logic [P_N_PRESP_STREAMS_W_RO_WD -1:0] o_ro_tag
  );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam SLVERR                  = 2'b10;
  localparam DECERR                  = 2'b11;
  // Output arbitration
  localparam integer REG_DELAY_DENOM = 1000;
  localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;
  localparam L_ARB_EXISTS            = (P_N_PRESP_STREAMS == 1) ? 0 : 1;
  localparam L_ARB_N                 = P_N_PRESP_STREAMS;
  localparam L_ARB_P_WIDTH           = (P_NVC_STREAMS > 1) ? $clog2(P_NVC_STREAMS) : 1;
  localparam L_ARB_PARK_MODE         = 0;
  localparam L_ARB_OUTPUT_MODE       = 0;
  localparam L_ARB_INDEX_WIDTH       = (L_ARB_N > 1) ? $clog2(L_ARB_N) : 1;

  // -------------------------------------------------------------------------------------
  // Type declarations
  // -------------------------------------------------------------------------------------
  typedef struct packed {
    logic                       req_received;
    logic                       resp_received;
    logic  [P_QUEUE_DP_WD -1:0] next_resp;
    logic  [P_QUEUE_DP_WD -1:0] next_bresp;
  } transactionTrackingHeader_s;

  typedef struct packed {
    transactionTrackingHeader_s tracking;
    P_DATA_BUS_TYPE             data;
  } transactionLutEntry_s;

  typedef struct packed {
    logic                       v;
    logic  [P_QUEUE_DP_WD -1:0] head;
    logic  [P_QUEUE_DP_WD -1:0] tail;
  } linkedListHeader_s;

  typedef struct packed {
    logic                      v;        // Write DMA error
    logic [P_QUEUE_DP_WD -1:0] stream;   // transaction_lut index of DMA error
    P_DMA_DATA_BUS_TYPE        dma_data; // transaction_lut data of DMA error
  } dmaErrorCtrl_s;

  typedef struct packed {
    logic [L_ARB_N -1:0] arb_request;
    dmaErrorCtrl_s       dmaErrorCtrl;
  } lowLatencyResp_s;

  // -------------------------------------------------------------------------------------
  // Internal signal declaration
  // -------------------------------------------------------------------------------------
  // Pipelines
  P_REQ_BUS_TYPE                                 s_req;
  P_RESP_BUS_TYPE                                s_resp;
  logic                                          s_resp_halt;
  P_BRESP_BUS_TYPE                               s_bresp, s_bresp_at_lut;
  logic                                          s_bresp_halt;

  // LUT
  transactionLutEntry_s        [P_QUEUE_DP -1:0] s_transaction_lut, r_transaction_lut;
  logic                        [P_QUEUE_DP -1:0] s_lutPush, s_lutEdit, s_lutPop;
  dmaErrorCtrl_s                                 s_dmaErrorCtrl;
  logic                 [P_NUM_DMA_RD_CHAN -1:0] s_dmaErrorLatch, r_dmaErrorLatch, s_dmaErrorResp;
  logic                 [P_NUM_DMA_RD_CHAN -1:0] s_dmaChanClear;
  transactionLutEntry_s                          s_dmaErrorTransactionLut;

  // LLs
  linkedListHeader_s         [P_N_PRESP_STREAMS -1:0] s_ll_resp , r_ll_resp;
  linkedListHeader_s         [P_N_PRESP_STREAMS -1:0] s_ll_bresp, r_ll_bresp;
  logic                      [P_N_PRESP_STREAMS -1:0] s_llPush_resp , s_llPop_resp;
  logic                      [P_N_PRESP_STREAMS -1:0] s_llPush_bresp, s_llPop_bresp;
  transactionLutEntry_s      [P_N_PRESP_STREAMS -1:0] s_llHeadTransactionEntries;
  logic [P_N_PRESP_STREAMS -1:0] [P_QUEUE_DP_WD -1:0] s_llNextTransactions_resp;
  logic [P_N_PRESP_STREAMS -1:0] [P_QUEUE_DP_WD -1:0] s_llNextTransactions_bresp;

  // Tag management
  logic                     [P_QUEUE_DP_WD -1:0] s_req_tag, s_i_req_tag, r_req_tag;
  logic                                          s_tagEmpty, r_tagEmpty;
  logic                                          s_tagPush_v;
  logic                     [P_QUEUE_DP_WD -1:0] s_tagPush_tag;

  // Arbitration
  lowLatencyResp_s                               s_lowLatencyResp;
  logic                           [L_ARB_N -1:0] s_arb_request;
  logic                           [L_ARB_N -1:0] s_arb_request_hl;
  logic                           [L_ARB_N -1:0] s_arb_mask;
  logic                           [L_ARB_N -1:0] s_arb_grant;
  logic                                          s_arb_granted;
  logic                 [L_ARB_INDEX_WIDTH -1:0] s_arb_grant_index;

  // -------------------------------------------------------------------------------------
  // Desgin
  // -------------------------------------------------------------------------------------
  // 1. Tag management
  //    Needs to be performed before pipeline so o_ro_tag matches pipeline of i_req

  // Tag is returned when it is granted by the output arbiter
  assign s_tagPush_v = s_arb_granted;
  assign s_tagPush_tag = r_ll_resp[s_arb_grant_index].head;

  DWC_pcie_tagMngr
   #(
    .P_MAXTAG      ( P_QUEUE_DP-1  )
   ,.P_MAXTAG_LOW  ( P_QUEUE_DP-1  )
   ,.P_MAXTAG_VLOW ( P_QUEUE_DP-1  )
   ,.P_TAGWD       ( P_QUEUE_DP_WD )
  ) u_tagger (
    .clk           ( i_clk         )
   ,.rst_n         ( i_rst_n       )

   ,.mode          ( '0            )
   ,.update_p      ( '0            )

   ,.pop_en        ( i_req.ctrl.v  )
   ,.pop_tag       ( s_i_req_tag   )
   ,.pop_tag_info  ( /* NC */      )
   ,.pop_empty     ( s_tagEmpty    )

   ,.push_en       ( s_tagPush_v   )
   ,.push_tag      ( s_tagPush_tag )
   ,.push_tag_info ( '0            )
  );

  assign o_ro_tag_valid = ~s_tagEmpty;
  assign o_ro_tag       =  s_i_req_tag + P_N_PRESP_STREAMS;

  assign o_req_halt = s_tagEmpty;

  // -------------------------------------------------------------------------------------
  // 2. Pipeline input interfaces
  // No halting of inputs beyond this point
  generate
    if(P_INPUT_PIPE_REQ_INTF == 0) begin : gen_no_req_pipe
      assign s_req     = s_tagEmpty ? '0 : i_req;
      assign s_req_tag = s_i_req_tag;
    end else begin : gen_req_pipe
      P_REQ_BUS_TYPE r_req;

      always_ff @(posedge i_clk, negedge i_rst_n)
        if(!i_rst_n) r_req <= #TP '0;
        else         r_req <= #TP i_req;

      always_ff @(posedge i_clk, negedge i_rst_n)
        if(!i_rst_n) {r_tagEmpty, s_req_tag} <= #TP '0;
        else         {r_tagEmpty, s_req_tag} <= #TP {s_tagEmpty, s_i_req_tag};

      assign s_req = r_tagEmpty ? '0 : r_req;
    end
  endgenerate

  generate
    if(P_INPUT_PIPE_BRESP_INTF == 0) begin : gen_no_bresp_pipe
      assign s_bresp      = i_bresp;
      assign o_bresp_halt = s_bresp_halt;
    end else if(P_BACKPRESSURE_BCH == 0) begin : gen_bresp_pipe_no_backpressure_bch
      always_ff @(posedge i_clk, negedge i_rst_n)
        if(!i_rst_n) s_bresp <= #TP '0;
        else         s_bresp <= #TP i_bresp;

      assign o_bresp_halt = 1'b0;
    end else begin : gen_bresp_pipe_backpressure_bch
      P_BRESP_BUS_TYPE w_bresp;
      P_BRESP_BUS_TYPE w_bli_bresp;
      P_BRESP_BUS_TYPE w_bli_bmask;
      logic            w_bresp_valid;
      logic            w_bresp_src_rdy;
      logic            w_bresp_dst_rdy;

      assign o_bresp_halt = ~w_bresp_src_rdy;

      DWC_pcie_axi_rs
       #(
        .P_FEED_READY ( 0                       )
       ,.CHAN_WD      ( $bits(P_BRESP_BUS_TYPE) )
      ) u_bresp_rs (
        .clk            ( i_clk           )
       ,.rstn           ( i_rst_n         )
       ,.clrn           ( 1'b1            )
       ,.vld_from_src   ( i_bresp.v       )
       ,.chanl_from_src ( i_bresp         )
       ,.rdy_from_dest  ( w_bresp_dst_rdy )
       ,.vld_to_dest    ( w_bresp_valid   )
       ,.chanl_to_dest  ( w_bresp         )
       ,.rdy_to_src     ( w_bresp_src_rdy )
      );

      assign w_bresp_dst_rdy = ~s_bresp_halt;

      assign w_bli_bresp = (w_bresp_valid & ~s_bresp_halt) ? w_bresp : '0;
      assign w_bli_bmask = '{default:'0,v:1'b1};

      DWC_pcie_bus_latch
       #(
        .P_BUS_T    ( P_BRESP_BUS_TYPE              )
       ,.P_IDLE_BUS ( P_BRESP_BUS_TYPE'{default:'0} )
      ) u_bresp_bl (
        .i_clk        ( i_clk       )
       ,.i_rst_n      ( i_rst_n     )
       ,.i_mask       ( w_bli_bmask )
       ,.i_mask_level ( w_bli_bmask )
       ,.i_bus        ( w_bli_bresp )
       ,.o_bus        ( s_bresp     )
      );
    end
  endgenerate

  generate
    if(P_BACKPRESSURE_BCH == 0) begin : gen_s_bresp_halt_no_backpressure_bch
      assign s_bresp_halt = 1'b0;
    end else begin : gen_s_bresp_halt_backpressure_bch
      assign s_bresp_halt = |s_arb_request_hl;
    end
  endgenerate

  // -------------------------------------------------------------------------------------
  // 3. LinkedList management
  // Two linked lists are required to detach resp backpressure from bresp intf and to allow bresps to write ahead of queued autopops
  always_ff @(posedge i_clk, negedge i_rst_n)
    if(!i_rst_n) r_ll_resp <= #TP '0;
    else         r_ll_resp <= #TP s_ll_resp;

  generate
    if(P_BACKPRESSURE_BCH == 0) begin : gen_r_ll_bresp_no_backpressure_bch
      always_ff @(posedge i_clk, negedge i_rst_n)
        if(!i_rst_n) r_ll_bresp <= #TP '0;
        else         r_ll_bresp <= #TP s_ll_bresp;
    end else begin : gen_r_ll_bresp_backpressure_bch
      assign r_ll_bresp = r_ll_resp;
    end
  endgenerate

  // When a request is received, write to resp LL
  assign s_llPush_resp = s_req.ctrl.v ? (P_N_PRESP_STREAMS)'(1 << s_req.data.stream) : '0;
  // When a request is pushed to output queue, pop resp LL
  assign s_llPop_resp  = s_arb_grant;

  // When a non-autopop request is received, write to bresp LL - we only need to write Strict order reqs, as the tag from ROs comes in the strem
  assign s_llPush_bresp = (s_req.ctrl.v & ~s_req.ctrl.is_relax_order & (~s_req.data.is_autopop) ) ? (P_N_PRESP_STREAMS)'(1 << s_req.data.stream) : '0;
  // When a bresp is received, for a SO pop bresp LL
  always_comb foreach(s_llPop_bresp[i]) s_llPop_bresp[i] = r_ll_bresp[i].v & (s_bresp.stream inside {[0:P_N_PRESP_STREAMS-1]}) & s_lutEdit[r_ll_bresp[i].head];

  // Helper proc for gathering all head transactions
  always_comb foreach(s_llHeadTransactionEntries[i]) s_llHeadTransactionEntries[i] = r_transaction_lut[r_ll_resp[i].head ];
  always_comb foreach(s_llNextTransactions_resp[i])  s_llNextTransactions_resp[i]  = r_transaction_lut[r_ll_resp[i].head ].tracking.next_resp;
  always_comb foreach(s_llNextTransactions_bresp[i]) s_llNextTransactions_bresp[i] = r_transaction_lut[r_ll_bresp[i].head].tracking.next_bresp;

  // Generic LL pushpop proc
  function automatic linkedListHeader_s [P_N_PRESP_STREAMS -1:0] f_next_ll (
    input linkedListHeader_s             [P_N_PRESP_STREAMS -1:0] i_ll
   ,input logic                          [P_N_PRESP_STREAMS -1:0] i_llPush
   ,input logic                          [P_N_PRESP_STREAMS -1:0] i_llPop
   ,input logic                          [P_QUEUE_DP_WD -1:0] i_pushTransaction
   ,input logic [P_N_PRESP_STREAMS -1:0] [P_QUEUE_DP_WD -1:0] i_nextTransactions
  );
    linkedListHeader_s [P_N_PRESP_STREAMS -1:0] l_next_ll;

    foreach(i_ll[i])
      case({i_llPush[i], i_llPop[i]})
        2'b00: l_next_ll[i] = i_ll[i];
        2'b01: l_next_ll[i] = '{
                 v   : (i_ll[i].head == i_ll[i].tail) ? 1'b0 : i_ll[i].v
                ,head: (i_ll[i].head == i_ll[i].tail) ? i_ll[i].head : i_nextTransactions[i]
                ,tail:  i_ll[i].tail
               };
        2'b10: l_next_ll[i] = '{
                 v   : 1'b1
                ,head: i_ll[i].v ? i_ll[i].head : i_pushTransaction
                ,tail: i_pushTransaction
               };
        2'b11: l_next_ll[i] = '{
                 v   : i_ll[i].v
                ,head: (i_ll[i].head == i_ll[i].tail) ? i_pushTransaction : i_nextTransactions[i]
                ,tail: i_pushTransaction
               };
      endcase

    f_next_ll = l_next_ll;
  endfunction

  assign s_ll_resp = f_next_ll(
                       .i_ll               (r_ll_resp)
                      ,.i_llPush           (s_llPush_resp)
                      ,.i_llPop            (s_llPop_resp)
                      ,.i_pushTransaction  (s_req_tag)
                      ,.i_nextTransactions (s_llNextTransactions_resp)
                     );

  generate
    if(P_BACKPRESSURE_BCH == 0) begin : gen_s_ll_bresp_no_backpressure_bch
      assign s_ll_bresp = f_next_ll(
                            .i_ll               (r_ll_bresp)
                           ,.i_llPush           (s_llPush_bresp)
                           ,.i_llPop            (s_llPop_bresp)
                           ,.i_pushTransaction  (s_req_tag)
                           ,.i_nextTransactions (s_llNextTransactions_bresp)
                          );
    end else begin : gen_s_ll_bresp_backpressure_bch
      assign s_ll_bresp = s_ll_resp;
    end
  endgenerate

`ifndef SYNTHESIS
`endif // SYNTHESIS

  // -------------------------------------------------------------------------------------
  // 4. TransactionLUT management
  always_ff @(posedge i_clk, negedge i_rst_n)
    if(!i_rst_n) r_transaction_lut <= #TP '0;
    else         r_transaction_lut <= #TP s_transaction_lut;

  // For SOs look at llHead to find corresponding transaction ID
  // For ROs the transaction ID is direct from the interface
  assign s_bresp_at_lut = '{
    v: s_bresp.v
   ,resp: s_bresp.resp
   ,stream: (s_bresp.stream inside {[0:P_N_PRESP_STREAMS-1]}) ? r_ll_bresp[s_bresp.stream[P_N_PRESP_STREAMS_WD-1:0]].head : (s_bresp.stream - P_N_PRESP_STREAMS)
  };

  // Catch and latch errored AXI responses to DMA requests (per DMA channel)
  always_ff @(posedge i_clk, negedge i_rst_n)
    if(!i_rst_n) r_dmaErrorLatch <= #TP '0;
    else         r_dmaErrorLatch <= #TP s_dmaErrorLatch;

  // Latch error when errored AXI beat received
  assign s_dmaErrorCtrl = '{
    v       : s_bresp_at_lut.v & s_bresp_at_lut.resp inside {SLVERR, DECERR}
   ,stream  : s_bresp_at_lut.stream
   ,dma_data: r_transaction_lut[s_bresp_at_lut.stream[P_QUEUE_DP_WD-1:0]].data.dma
  };

  // Clear latched errors when 'last' response sent
  assign s_dmaChanClear = (s_resp.ctrl.v & s_resp.data.dma.v & s_resp.data.is_last) ? (P_NUM_DMA_RD_CHAN)'(1 << s_resp.data.dma.chan) : '0;

  // If we respond to a DMA decomposed with DMA error, we need to latch the DMA error status for the channel
  assign s_dmaErrorResp = (s_resp.ctrl.v & s_resp.data.dma.v & s_resp.data.dma.err) ? (P_NUM_DMA_RD_CHAN)'(1 << s_resp.data.dma.chan) : '0;

  always_comb
    foreach(s_dmaErrorLatch[i])                   // Per DMA channel
      if(r_dmaErrorLatch[i])                      //   if a DMA error is latched
        s_dmaErrorLatch[i] = ~s_dmaChanClear[i];  //     clear it if signalling DMA error to a last decomposition
      else                                        //   else,
        s_dmaErrorLatch[i] = ~s_dmaChanClear[i]   //     latch if not signalling DMA error to a last decomposition
                             & s_dmaErrorResp[i]; //     and response has DMA error status

  // When editing transaction LUT, set DMA err field
  assign s_dmaErrorTransactionLut = '{
    default:'0
   ,data   : '{
      default:'0
     ,dma    : '{
        default:'0
       ,err    : s_dmaErrorCtrl.v
      } // dma
    } // data
  };

  // lutPush: Write a new entry to the LUT
  // lutEdit: Set resp_received to 1 in the entry
  // lutPop : Set req_received to 0 in the entry
  assign s_lutPush = s_req.ctrl.v     ? (1 << s_req_tag)             : '0;
  assign s_lutEdit = s_bresp_at_lut.v ? (1 << s_bresp_at_lut.stream) : '0;
  assign s_lutPop  = s_tagPush_v      ? (1 << s_tagPush_tag)         : '0;

  // Main LUT proc
  always_comb foreach(s_transaction_lut[i]) begin
    case({s_lutPush[i], s_lutEdit[i], s_lutPop[i]})
      3'b000
     ,3'b110
     ,3'b111: s_transaction_lut[i] = r_transaction_lut[i];
      3'b001
     ,3'b011: s_transaction_lut[i] = '{
        tracking: '{
          req_received : 1'b0
         ,resp_received: r_transaction_lut[i].tracking.resp_received
         ,next_resp    : r_transaction_lut[i].tracking.next_resp
         ,next_bresp   : r_transaction_lut[i].tracking.next_bresp
        }
       ,data: r_transaction_lut[i].data
      };
      3'b010: s_transaction_lut[i] = '{
        tracking: '{
          req_received : r_transaction_lut[i].tracking.req_received
         ,resp_received: 1'b1
         ,next_resp    : r_transaction_lut[i].tracking.next_resp
         ,next_bresp   : r_transaction_lut[i].tracking.next_bresp
        }
       ,data: r_transaction_lut[i].data | ({$bits(transactionLutEntry_s){r_transaction_lut[i].data.dma.v}} & s_dmaErrorTransactionLut)
      };
      3'b100
     ,3'b101: s_transaction_lut[i] = '{
        tracking: '{
          req_received : 1'b1
         ,resp_received: s_req.data.is_autopop
         ,next_resp    : i
         ,next_bresp   : i
        }
       ,data: s_req.data
      };
    endcase

    // If llPush update next of previous tail
    foreach(r_ll_resp[j])
      if(s_llPush_resp[j] & r_ll_resp[j].v & (i == r_ll_resp[j].tail))
        s_transaction_lut[i].tracking.next_resp = s_req_tag;

    if(P_BACKPRESSURE_BCH == 0)
      foreach(r_ll_bresp[k])
        if(s_llPush_bresp[k] & r_ll_bresp[k].v & (i == r_ll_bresp[k].tail))
          s_transaction_lut[i].tracking.next_bresp = s_req_tag;
  end

  // -------------------------------------------------------------------------------------
  // 5. Output arbitration
  generate
    if(P_LOW_LATENCY_RESP == 0) begin : gen_no_lowLatencyResp
      assign s_lowLatencyResp = '0;
    end else begin : gen_lowLatencyResp
      always_comb begin
        foreach(s_lowLatencyResp.arb_request[i])
          s_lowLatencyResp.arb_request[i] = s_lutEdit[r_ll_resp[i].head];
        s_lowLatencyResp.dmaErrorCtrl = s_dmaErrorCtrl;
      end
    end
  endgenerate

  // Read to read when either (response has been received previously but not yet read) | (response is being received this cycle)
  always_comb foreach(s_arb_request_hl[i]) s_arb_request_hl[i] = r_ll_resp[i].v & s_llHeadTransactionEntries[i].tracking.req_received & s_llHeadTransactionEntries[i].tracking.resp_received;
  always_comb foreach(s_arb_request[i])    s_arb_request[i]    = s_arb_request_hl[i] | (r_ll_resp[i].v & s_lowLatencyResp.arb_request[i]);

  assign s_arb_mask = {L_ARB_N{s_resp_halt}};

  generate
  if(L_ARB_N > 1) begin : gen_output_arb
    logic [L_ARB_N-1:0] s_arb_req_masked;

    assign s_arb_req_masked = s_arb_request & ~s_arb_mask;

    DWC_pcie_generic_arbiter
     #(
      .P_INPUTS   ( L_ARB_N )
     ,.P_WEIGHTWD ( 1       )
     ,.P_TYPE     ( 2'b01   ) // Round Robin
    ) u_arb (
      .i_clk     ( i_clk             )
     ,.i_rst_n   ( i_rst_n           )
     ,.i_clr_n   ( 1'b1              )

     ,.i_en      ( |s_arb_req_masked )
     ,.i_request (  s_arb_req_masked )
     ,.i_weight  ( '1                )

     ,.o_granted ( s_arb_granted     )
     ,.o_grant   ( s_arb_grant       )
     ,.o_weight  ( /* NC */          )
    );

    always_comb begin : s_arb_grant_index_cproc
      s_arb_grant_index = '0;
      foreach(s_arb_grant[i])
        if(s_arb_grant[i]) s_arb_grant_index = i;
    end : s_arb_grant_index_cproc
  end else begin : gen_no_output_arb
    // If single ordering stream, no arbiter needed
    assign s_arb_granted     = s_arb_request & (~s_arb_mask);
    assign s_arb_grant       = s_arb_granted;
    assign s_arb_grant_index = '0;
  end
  endgenerate

  // -------------------------------------------------------------------------------------
  // 6. Output data
  always_comb begin
    s_resp = '{
      ctrl: '{
        v: s_arb_granted
       ,is_empty: 1'b0 // Not used
      }
     ,data: s_llHeadTransactionEntries[s_arb_grant_index].data
    };

    // Flag DMA error if:
    // 1.    Stored DMA error for this decomposition
    // 2. or stored DMA error for a previous decomposition
    // 3. or DMA error this cycle
    // 4. or stored LTI faulted response for the transaction
    if(s_resp.data.dma.v)
      s_resp.data.dma.err = s_resp.data.dma.err
                            | r_dmaErrorLatch[s_resp.data.dma.chan]
                            | (s_lowLatencyResp.dmaErrorCtrl.v & (s_lowLatencyResp.dmaErrorCtrl.stream == r_ll_resp[s_arb_grant_index].head))
                            ;
    else
      s_resp.data.dma.err = 1'b0; // Non-DMA is never DMA error
  end

  // -------------------------------------------------------------------------------------
  // 7. Pipeline output interface
  generate
    if(P_OUTPUT_PIPE_RESP_INTF == 0) begin : gen_no_resp_pipe
      assign o_resp      = s_resp;
      assign s_resp_halt = i_resp_halt;
    end else begin : gen_resp_pipe
      P_RESP_BUS_TYPE w_resp;
      P_RESP_BUS_TYPE w_bli_resp;
      P_RESP_BUS_TYPE w_bli_rmask;
      logic           w_resp_valid;
      logic           w_resp_src_rdy;
      logic           w_resp_dst_rdy;

      assign s_resp_halt = ~w_resp_src_rdy;

      DWC_pcie_axi_rs
       #(
        .P_FEED_READY ( 1                      )
       ,.CHAN_WD      ( $bits(P_RESP_BUS_TYPE) )
      ) u_resp_rs (
        .clk            ( i_clk          )
       ,.rstn           ( i_rst_n        )
       ,.clrn           ( 1'b1           )
       ,.vld_from_src   ( s_resp.ctrl.v  )
       ,.chanl_from_src ( s_resp         )
       ,.rdy_from_dest  ( w_resp_dst_rdy )
       ,.vld_to_dest    ( w_resp_valid   )
       ,.chanl_to_dest  ( w_resp         )
       ,.rdy_to_src     ( w_resp_src_rdy )
      );

      assign w_resp_dst_rdy = ~i_resp_halt;

      assign w_bli_resp  = w_resp_valid ? w_resp : '0;
      assign w_bli_rmask = '{
        default: '0
       ,ctrl: '{default:'0, v:1'b1}
      };

      DWC_pcie_bus_latch
       #(
        .P_BUS_T    ( P_RESP_BUS_TYPE              )
       ,.P_IDLE_BUS ( P_RESP_BUS_TYPE'{default:'0} )
      ) u_resp_bl (
        .i_clk        ( i_clk       )
       ,.i_rst_n      ( i_rst_n     )
       ,.i_mask       ( w_bli_rmask )
       ,.i_mask_level ( w_bli_rmask )
       ,.i_bus        ( w_bli_resp  )
       ,.o_bus        ( o_resp      )
      );
    end
  endgenerate

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_axi_presp_core
