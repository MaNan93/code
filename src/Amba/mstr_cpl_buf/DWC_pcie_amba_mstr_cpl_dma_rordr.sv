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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_dma_rordr.sv#5 $
// -------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 module DWC_pcie_amba_mstr_cpl_dma_rordr #(
   parameter CX_REMOTE_MAX_TAGS           = `CX_REMOTE_MAX_TAGS
  ,parameter CX_REMOTE_MAX_TAGS_WD        = `CX_REMOTE_MAX_TAGS_WD
  ,parameter DC_MCB_MAX_CPL_NUM_DWORDS_WD = `DC_MCB_MAX_CPL_NUM_DWORDS_WD
  ,parameter DC_CPL_STATUS_WD             = `DC_CPL_STATUS_WD
  ,parameter DC_DMA_TYPE_WIDTH            = `DC_DMA_TYPE_WIDTH
  ,parameter CC_NUM_DMA_RD_CHAN           = `CC_NUM_DMA_RD_CHAN
  ,parameter CC_NUM_DMA_WR_CHAN           = `CC_NUM_DMA_WR_CHAN
  ,parameter CC_NUM_DMA_RD_CHAN_WIDTH     = `CC_NUM_DMA_RD_CHAN_WIDTH
  ,parameter CC_NUM_DMA_WR_CHAN_WIDTH     = `CC_NUM_DMA_WR_CHAN_WIDTH
  ,parameter CC_NUM_DMA_MAX_CHAN_WIDTH    = `CC_NUM_DMA_MAX_CHAN_WIDTH
 )(
   // -------------------------------------------------------------------------------------
   // Clocks and resets
   // -------------------------------------------------------------------------------------
   input  logic                                    core_clk
  ,input  logic                                    core_rst_n
   // -------------------------------------------------------------------------------------
   // Master non-posted request interface
   // -------------------------------------------------------------------------------------
  ,input  logic                                    radmx_mreq_np_valid
  ,input  logic                                    radmx_mreq_np_last
  ,input  logic [CX_REMOTE_MAX_TAGS_WD-1:0]        radmx_ireq_np_lookup_id
  ,input  logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]    radmx_ireq_np_dma_chan
  ,input  logic [DC_DMA_TYPE_WIDTH-1:0]            radmx_ireq_np_dma_type
   // -------------------------------------------------------------------------------------
   // DMA Early fetch, LL descriptor backpressure
   // -------------------------------------------------------------------------------------
  ,input  logic [CC_NUM_DMA_RD_CHAN-1:0]           dma_mcb_rdll_halt
  ,input  logic [CC_NUM_DMA_WR_CHAN-1:0]           dma_mcb_wrll_halt
   // -------------------------------------------------------------------------------------
   // Write compleation info ready to be scheduled
   // -------------------------------------------------------------------------------------
  ,input  logic                                    cpl_q_wr_valid
  ,input  logic [CX_REMOTE_MAX_TAGS_WD-1:0]        cpl_q_wr_seg_num
  ,input  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_wr_beat_len
  ,input  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_wr_dw_len
  ,input  logic [DC_CPL_STATUS_WD-1:0]             cpl_q_wr_status
  ,input  logic                                    cpl_q_wr_ep
  ,input  logic                                    cpl_q_wr_last_pkt_beat
   // -------------------------------------------------------------------------------------
   // Read next compleation info to be released from sbc
   // -------------------------------------------------------------------------------------
  ,input  logic                                    cpl_q_rd_ready
  ,output logic                                    cpl_q_rd_valid
  ,output logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]    cpl_q_rd_dma_chan
  ,output logic [DC_DMA_TYPE_WIDTH-1:0]            cpl_q_rd_dma_type
  ,output logic [CX_REMOTE_MAX_TAGS_WD-1:0]        cpl_q_rd_seg_num
  ,output logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_rd_beat_len
  ,output logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_rd_dw_len
  ,output logic [DC_CPL_STATUS_WD-1:0]             cpl_q_rd_status
  ,output logic                                    cpl_q_rd_ep
  ,output logic                                    cpl_q_rd_last_pkt_beat
);

  localparam L_NUM_DMA_WR_LL_QUEUES = CC_NUM_DMA_WR_CHAN;
  localparam L_NUM_DMA_RD_LL_QUEUES = CC_NUM_DMA_RD_CHAN;
  localparam L_NUM_LL_QUEUES = CC_NUM_DMA_WR_CHAN  + L_NUM_DMA_WR_LL_QUEUES + L_NUM_DMA_RD_LL_QUEUES;

  logic [CC_NUM_DMA_WR_CHAN_WIDTH-1:0] radmx_ireq_np_dma_wrchan;
  logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0] radmx_ireq_np_dma_rdchan;

  assign radmx_ireq_np_dma_wrchan = CC_NUM_DMA_WR_CHAN_WIDTH'(radmx_ireq_np_dma_chan); 
  assign radmx_ireq_np_dma_rdchan = CC_NUM_DMA_RD_CHAN_WIDTH'(radmx_ireq_np_dma_chan);

  // -------------------------------------------------------------------------------------
  // Linked-List Queues, one per compleation type, and common next pointer lut
  // -------------------------------------------------------------------------------------
  typedef struct packed {
    logic [CX_REMOTE_MAX_TAGS_WD-1:0] tail  ;
    logic [CX_REMOTE_MAX_TAGS_WD-1:0] head  ;
    logic                             valid ;
  } llSeg_s;

  typedef struct packed {
    logic [CX_REMOTE_MAX_TAGS_WD-1:0] pushSeg     ;
    logic                             push        ;
    logic                             pop         ;
    logic                             almostEmpty ;
  } llSegAux_s;

  function automatic llSeg_s f_updatell(
     input llSeg_s i_ll
    ,input llSegAux_s i_llAux
    ,input logic      [CX_REMOTE_MAX_TAGS-1:0] [CX_REMOTE_MAX_TAGS_WD-1:0] i_segNext
    );
    case ({i_ll.valid, i_llAux.almostEmpty, i_llAux.pop, i_llAux.push})
      4'b0001: /* PUSH      , EMPTY */ f_updatell = '{valid: '1, head: i_llAux.pushSeg     , tail: i_llAux.pushSeg};
      4'b1111: /* PUSH & POP, LAST  */ f_updatell = '{valid: '1, head: i_llAux.pushSeg     , tail: i_llAux.pushSeg};
      4'b1001: /* PUSH              */ f_updatell = '{valid: '1, head: i_ll.head           , tail: i_llAux.pushSeg};
      4'b1101: /* PUSH      , LAST  */ f_updatell = '{valid: '1, head: i_ll.head           , tail: i_llAux.pushSeg};
      4'b1011: /* PUSH & POP        */ f_updatell = '{valid: '1, head: i_segNext[i_ll.head], tail: i_llAux.pushSeg};
      4'b1010: /*        POP        */ f_updatell = '{valid: '1, head: i_segNext[i_ll.head], tail: i_ll.tail      };
      4'b1110: /*        POP, LAST  */ f_updatell = '{valid: '0, head: '0                  , tail: '0             };
      default: /* NO UPDATE         */ f_updatell = i_ll;
    endcase
  endfunction

  llSegAux_s [CC_NUM_DMA_WR_CHAN-1:0]                             s_wrDataQueueStatus ;
  llSeg_s    [CC_NUM_DMA_WR_CHAN-1:0]                             s_wrDataQueue       ;
  llSeg_s    [CC_NUM_DMA_WR_CHAN-1:0]                             r_wrDataQueue       ;

  llSegAux_s [L_NUM_DMA_WR_LL_QUEUES-1:0]                         s_wrllQueueStatus   ;
  llSeg_s    [L_NUM_DMA_WR_LL_QUEUES-1:0]                         s_wrllQueue         ;
  llSeg_s    [L_NUM_DMA_WR_LL_QUEUES-1:0]                         r_wrllQueue         ;

  llSegAux_s [L_NUM_DMA_RD_LL_QUEUES-1:0]                         s_rdllQueueStatus   ;
  llSeg_s    [L_NUM_DMA_RD_LL_QUEUES-1:0]                         s_rdllQueue         ;
  llSeg_s    [L_NUM_DMA_RD_LL_QUEUES-1:0]                         r_rdllQueue         ;

  logic      [CX_REMOTE_MAX_TAGS-1:0] [CX_REMOTE_MAX_TAGS_WD-1:0] s_segNext           ;
  logic      [CX_REMOTE_MAX_TAGS-1:0] [CX_REMOTE_MAX_TAGS_WD-1:0] r_segNext           ;

  llSeg_s                                                         s_pushedQueue       ;
  llSegAux_s                                                      s_pushedQueueStatus ;

  always_ff @(posedge core_clk, negedge core_rst_n) begin : llRegs_PROC
    if (!core_rst_n) begin
      r_segNext     <= #`TP '0;
      r_wrDataQueue <= #`TP '0;
      r_wrllQueue   <= #`TP '0;
      r_rdllQueue   <= #`TP '0;
    end else begin
      r_segNext     <= #`TP s_segNext;
      r_wrDataQueue <= #`TP s_wrDataQueue;
      r_wrllQueue   <= #`TP s_wrllQueue;
      r_rdllQueue   <= #`TP s_rdllQueue;
    end
  end

  always_comb begin : segNext_PROC
    foreach (s_segNext[i]) begin
      if (i == s_pushedQueue.tail) begin
        case ({s_pushedQueue.valid, s_pushedQueueStatus.almostEmpty, s_pushedQueueStatus.pop, s_pushedQueueStatus.push})
          4'b1001, /* PUSH              */
          4'b1011, /* PUSH & POP        */
          4'b1101: /* PUSH      , LAST  */ s_segNext[i] = radmx_ireq_np_lookup_id;
          default: s_segNext[i] = r_segNext[i];
        endcase
      end else begin
        s_segNext[i] = r_segNext[i];
      end
    end
  end
 
  always_comb begin : wrDataQueue_PROC
    foreach (r_wrDataQueue[i]) begin
      s_wrDataQueue[i] = f_updatell(r_wrDataQueue[i], s_wrDataQueueStatus[i], r_segNext);
    end
  end 

  always_comb begin : wrllQueue_PROC
    foreach (r_wrllQueue[i]) begin
      s_wrllQueue[i] = f_updatell(r_wrllQueue[i], s_wrllQueueStatus[i], r_segNext);
    end
  end 

  always_comb begin : rdllQueue_PROC
    foreach (r_rdllQueue[i]) begin
      s_rdllQueue[i] = f_updatell(r_rdllQueue[i], s_rdllQueueStatus[i], r_segNext);
    end
  end 

  // -------------------------------------------------------------------------------------
  // Segment info LUT
  // -------------------------------------------------------------------------------------
  typedef struct packed {
    logic                                    valid         ;
    logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] beat_len      ;
    logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] dw_len        ;
    logic [DC_CPL_STATUS_WD-1:0]             status        ;
    logic                                    ep            ;
    logic                                    last_pkt_beat ;
  } segInfoLut_s;

  segInfoLut_s [CX_REMOTE_MAX_TAGS-1:0] s_segInfoLut;
  segInfoLut_s [CX_REMOTE_MAX_TAGS-1:0] r_segInfoLut;

  always_ff @(posedge core_clk, negedge core_rst_n) begin : segInfoLutReg_PROC
    if (!core_rst_n) begin
      r_segInfoLut <= #`TP '0;
    end else begin
      r_segInfoLut <= #`TP s_segInfoLut;
    end
  end

  always_comb begin : segInfoLutNext_PROC
    foreach (s_segInfoLut[i]) begin
      if (cpl_q_rd_valid && cpl_q_rd_ready && cpl_q_rd_seg_num == i) begin
        s_segInfoLut[i] = '0;
      end else if (cpl_q_wr_valid && cpl_q_wr_seg_num == i) begin //cpl_q_wr and cpl_q_rd are exclusive
        s_segInfoLut[i] = '{
           valid         : '1
          ,beat_len      : cpl_q_wr_beat_len
          ,dw_len        : cpl_q_wr_dw_len
          ,status        : cpl_q_wr_status
          ,ep            : cpl_q_wr_ep
          ,last_pkt_beat : cpl_q_wr_last_pkt_beat
        };
      end else begin
        s_segInfoLut[i] = r_segInfoLut[i];
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // Round Robin channel arbiter per compleation type
  // -------------------------------------------------------------------------------------
  typedef struct packed {
    logic [CX_REMOTE_MAX_TAGS_WD-1:0]    segment ;
    logic [CC_NUM_DMA_WR_CHAN_WIDTH-1:0] channel ;
  } wrEngArbData_s;

  typedef struct packed {
    logic [CX_REMOTE_MAX_TAGS_WD-1:0]    segment ;
    logic [CC_NUM_DMA_RD_CHAN_WIDTH-1:0] channel ;
  } rdEngArbData_s;

  logic                                       s_wrDataArbReady       ;
  logic          [CC_NUM_DMA_WR_CHAN-1:0]     s_wrDataArbRequest     ;
  logic                                       s_wrDataArbValid       ;
  wrEngArbData_s [CC_NUM_DMA_WR_CHAN-1:0]     s_wrDataArbRequestData ;
  logic          [CC_NUM_DMA_WR_CHAN-1:0]     s_wrDataArbGrant       ;
  wrEngArbData_s                              s_wrDataArbValidData   ;

  logic                                       s_wrllArbReady         ;
  logic          [L_NUM_DMA_WR_LL_QUEUES-1:0] s_wrllArbRequest       ;
  logic                                       s_wrllArbValid         ;
  wrEngArbData_s [L_NUM_DMA_WR_LL_QUEUES-1:0] s_wrllArbRequestData   ;
  logic          [L_NUM_DMA_WR_LL_QUEUES-1:0] s_wrllArbGrant         ;
  wrEngArbData_s                              s_wrllArbValidData     ;

  logic                                       s_rdllArbReady         ;
  logic          [L_NUM_DMA_RD_LL_QUEUES-1:0] s_rdllArbRequest       ;
  logic                                       s_rdllArbValid         ;
  rdEngArbData_s [L_NUM_DMA_RD_LL_QUEUES-1:0] s_rdllArbRequestData   ;
  logic          [L_NUM_DMA_RD_LL_QUEUES-1:0] s_rdllArbGrant         ;
  rdEngArbData_s                              s_rdllArbValidData     ;

  always_comb begin : wrDataArbRequest_PROC
    s_wrDataArbRequest = '0;
    s_wrDataArbRequestData = '0;
    foreach (s_wrDataArbRequest[i]) begin
      s_wrDataArbRequest[i]     =  r_wrDataQueue[i].valid && r_segInfoLut[r_wrDataQueue[i].head].valid;
      s_wrDataArbRequestData[i] = '{segment: r_wrDataQueue[i].head, channel: CC_NUM_DMA_WR_CHAN_WIDTH'(i)};
    end
  end

  always_comb begin : wrllArbRequest_PROC
    s_wrllArbRequest = '0;
    s_wrllArbRequestData = '0;
    foreach (s_wrllArbRequest[i]) begin
      s_wrllArbRequest[i]     =  r_wrllQueue[i].valid && r_segInfoLut[r_wrllQueue[i].head].valid  && !dma_mcb_wrll_halt[i];
      s_wrllArbRequestData[i] = '{segment: r_wrllQueue[i].head, channel: CC_NUM_DMA_WR_CHAN_WIDTH'(i)};
    end
  end

  always_comb begin : rdllArbRequest_PROC
    s_rdllArbRequest = '0;
    s_rdllArbRequestData = '0;
    foreach (s_rdllArbRequest[i]) begin
      s_rdllArbRequest[i]     =  r_rdllQueue[i].valid && r_segInfoLut[r_rdllQueue[i].head].valid && !dma_mcb_rdll_halt[i];
      s_rdllArbRequestData[i] = '{segment: r_rdllQueue[i].head, channel: CC_NUM_DMA_RD_CHAN_WIDTH'(i)};
    end
  end

  DWC_pcie_staged_arbiter
   #(
       .P_INPUTS   (CC_NUM_DMA_WR_CHAN)
      ,.P_STAGES   (3                 )
      ,.P_DATATYPE (wrEngArbData_s    )
    ) u_wrDataArb(
       .i_clk     (core_clk              )
      ,.i_rst_n   (core_rst_n            )
      ,.i_clr_n   (1'b1                  )
      ,.i_en      (1'b1                  )
      ,.i_ready   (s_wrDataArbReady      )
      ,.i_request (s_wrDataArbRequest    )
      ,.i_data    (s_wrDataArbRequestData)
      ,.o_grant   (s_wrDataArbGrant      )
      ,.o_valid   (s_wrDataArbValid      )
      ,.o_data    (s_wrDataArbValidData  )
      );

  DWC_pcie_staged_arbiter
   #(
       .P_INPUTS   (L_NUM_DMA_WR_LL_QUEUES)
      ,.P_STAGES   (3                     )
      ,.P_DATATYPE (wrEngArbData_s        )
    ) u_wrllArb(
       .i_clk     (core_clk            )
      ,.i_rst_n   (core_rst_n          )
      ,.i_clr_n   (1'b1                )
      ,.i_en      (1'b1                )
      ,.i_ready   (s_wrllArbReady      )
      ,.i_request (s_wrllArbRequest    )
      ,.i_data    (s_wrllArbRequestData)
      ,.o_grant   (s_wrllArbGrant      )
      ,.o_valid   (s_wrllArbValid      )
      ,.o_data    (s_wrllArbValidData  )
      );

  DWC_pcie_staged_arbiter
   #(
       .P_INPUTS   (L_NUM_DMA_RD_LL_QUEUES)
      ,.P_STAGES   (3                     )
      ,.P_DATATYPE (rdEngArbData_s        )
    ) u_rdllArb(
       .i_clk     (core_clk            )
      ,.i_rst_n   (core_rst_n          )
      ,.i_clr_n   (1'b1                )
      ,.i_en      (1'b1                )
      ,.i_ready   (s_rdllArbReady      )
      ,.i_request (s_rdllArbRequest    )
      ,.i_data    (s_rdllArbRequestData)
      ,.o_grant   (s_rdllArbGrant      )
      ,.o_valid   (s_rdllArbValid      )
      ,.o_data    (s_rdllArbValidData  )
      );

  // -------------------------------------------------------------------------------------
  // Push and pop segments from queues
  // -------------------------------------------------------------------------------------
  always_comb begin : QueuePushPop_PROC
    foreach (s_wrDataQueueStatus[i]) begin
      s_wrDataQueueStatus[i].push = '0;
      s_wrDataQueueStatus[i].pushSeg = '0;
      s_wrDataQueueStatus[i].pop = s_wrDataArbGrant[i];
      s_wrDataQueueStatus[i].almostEmpty = r_wrDataQueue[i].valid && (r_wrDataQueue[i].head == r_wrDataQueue[i].tail);
    end
    foreach (s_wrllQueueStatus[i]) begin
      s_wrllQueueStatus[i].push = '0;
      s_wrllQueueStatus[i].pushSeg = '0;
      s_wrllQueueStatus[i].pop = s_wrllArbGrant[i];
      s_wrllQueueStatus[i].almostEmpty = r_wrllQueue[i].valid && (r_wrllQueue[i].head == r_wrllQueue[i].tail);
    end
    foreach (s_rdllQueueStatus[i]) begin
      s_rdllQueueStatus[i].push = '0;
      s_rdllQueueStatus[i].pushSeg = '0;
      s_rdllQueueStatus[i].pop = s_rdllArbGrant[i];
      s_rdllQueueStatus[i].almostEmpty = r_rdllQueue[i].valid && (r_rdllQueue[i].head == r_rdllQueue[i].tail);
    end
    s_pushedQueue = '0;
    s_pushedQueueStatus = '0;
    if (radmx_mreq_np_valid && radmx_mreq_np_last) begin
      // SMD: Not all conditions are covered for the combinational logic
      //  SJ: All signals are initialized so no latch is generated 
      // spyglass disable_block AlwaysCombExhaustive-ML
      if (radmx_ireq_np_dma_type == `DC_DMA_REQ_WRCH_READ) begin
        s_wrDataQueueStatus[radmx_ireq_np_dma_wrchan].push = '1;
        s_wrDataQueueStatus[radmx_ireq_np_dma_wrchan].pushSeg = radmx_ireq_np_lookup_id;
        s_pushedQueue = r_wrDataQueue[radmx_ireq_np_dma_wrchan];
        s_pushedQueueStatus = s_wrDataQueueStatus[radmx_ireq_np_dma_wrchan];
      end
      if (radmx_ireq_np_dma_type == `DC_DMA_REQ_WRCH_LLREAD) begin
        s_wrllQueueStatus[radmx_ireq_np_dma_wrchan].push = '1;
        s_wrllQueueStatus[radmx_ireq_np_dma_wrchan].pushSeg = radmx_ireq_np_lookup_id;
        s_pushedQueue = r_wrllQueue[radmx_ireq_np_dma_wrchan];
        s_pushedQueueStatus = s_wrllQueueStatus[radmx_ireq_np_dma_wrchan];
      end
      if (radmx_ireq_np_dma_type == `DC_DMA_REQ_RDCH_LLREAD) begin
        s_rdllQueueStatus[radmx_ireq_np_dma_rdchan].push = '1;
        s_rdllQueueStatus[radmx_ireq_np_dma_rdchan].pushSeg = radmx_ireq_np_lookup_id;
        s_pushedQueue = r_rdllQueue[radmx_ireq_np_dma_rdchan];
        s_pushedQueueStatus = s_rdllQueueStatus[radmx_ireq_np_dma_rdchan];
      end
      // spyglass enable_block AlwaysCombExhaustive-ML
    end
  end

  // -------------------------------------------------------------------------------------
  // Output registers with isolated ready
  // -------------------------------------------------------------------------------------
  logic s_outputReady;
  segInfoLut_s                          r_outSegInfo;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]     r_outSegNum ;
  logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] r_outChan   ;
  logic [DC_DMA_TYPE_WIDTH-1:0]         r_outType   ;
  segInfoLut_s                          r_bpSegInfo ;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]     r_bpSegNum  ;
  logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] r_bpChan    ;
  logic [DC_DMA_TYPE_WIDTH-1:0]         r_bpType    ;
  segInfoLut_s                          s_outSegInfo;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]     s_outSegNum ;
  logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] s_outChan   ;
  logic [DC_DMA_TYPE_WIDTH-1:0]         s_outType   ;

  always_ff @(posedge core_clk, negedge core_rst_n) begin : outputReg_PROC
    if (!core_rst_n) begin
      r_outSegInfo <= #`TP '0;
      r_outSegNum  <= #`TP '0;
      r_outChan    <= #`TP '0;
      r_outType    <= #`TP '0;
      r_bpSegInfo  <= #`TP '0;
      r_bpSegNum   <= #`TP '0;
      r_bpChan     <= #`TP '0;
      r_bpType     <= #`TP '0;
    end else begin
      if (!r_outSegInfo.valid || cpl_q_rd_ready) begin
        if (r_bpSegInfo.valid) begin
          r_outSegInfo <= #`TP r_bpSegInfo;
          r_outSegNum  <= #`TP r_bpSegNum ;
          r_outChan    <= #`TP r_bpChan   ;
          r_outType    <= #`TP r_bpType   ;
        end else begin
          r_outSegInfo <= #`TP s_outSegInfo;
          r_outSegNum  <= #`TP s_outSegNum ;
          r_outChan    <= #`TP s_outChan   ;
          r_outType    <= #`TP s_outType   ;
        end
      end
      if (cpl_q_rd_ready) begin
        r_bpSegInfo <= #`TP '0;
        r_bpSegNum  <= #`TP '0;
        r_bpChan    <= #`TP '0;
        r_bpType    <= #`TP '0;
      end else if (r_outSegInfo.valid && !r_bpSegInfo.valid) begin
        r_bpSegInfo <= #`TP s_outSegInfo;
        r_bpSegNum  <= #`TP s_outSegNum ;
        r_bpChan    <= #`TP s_outChan   ;
        r_bpType    <= #`TP s_outType   ;
      end
    end
  end

  assign s_outputReady = !r_bpSegInfo.valid;

  assign cpl_q_rd_valid         = r_outSegInfo.valid         ;
  assign cpl_q_rd_dma_chan      = r_outChan                  ;
  assign cpl_q_rd_dma_type      = r_outType                  ;
  assign cpl_q_rd_seg_num       = r_outSegNum                ;
  assign cpl_q_rd_beat_len      = r_outSegInfo.beat_len      ;
  assign cpl_q_rd_dw_len        = r_outSegInfo.dw_len        ;
  assign cpl_q_rd_status        = r_outSegInfo.status        ;
  assign cpl_q_rd_ep            = r_outSegInfo.ep            ;
  assign cpl_q_rd_last_pkt_beat = r_outSegInfo.last_pkt_beat ;

  // -------------------------------------------------------------------------------------
  // Double stage arbiter 
  //  - strict arbiter gives priority to LL compleations over data compleations
  //  - Round robin picks which engine will have its LL compleation released
  // Gathers the compleation info and drives the output register
  // -------------------------------------------------------------------------------------
  logic [1:0] s_llArbRequest;
  logic [1:0] s_llArbGrant  ;
  logic       s_llArbEnable ;

  DWC_pcie_generic_arbiter
   #(
    .P_INPUTS   (2    )
   ,.P_TYPE     (2'b01) // Round-robin
  ) u_llArb(
    .i_clk     (core_clk      )
   ,.i_rst_n   (core_rst_n    )
   ,.i_clr_n   (1'b1          )
   ,.i_en      (s_llArbEnable )
   ,.i_request (s_llArbRequest)
   ,.i_weight  ('0            )
   ,.o_grant   (s_llArbGrant  )
   ,.o_granted ( /* NC */     )
   ,.o_weight  ( /* NC */     )
  );

  always_comb begin : outputDrivers_PROC
    s_wrDataArbReady = '0;
    s_wrllArbReady = '0;
    s_rdllArbReady = '0;
    if (|s_llArbRequest) begin
      if (s_llArbGrant == 2'b01) begin //WR ENG LL
        s_outSegInfo   = r_segInfoLut[s_wrllArbValidData.segment];
        s_outSegNum    = s_wrllArbValidData.segment;
        s_outChan      = CC_NUM_DMA_MAX_CHAN_WIDTH'(s_wrllArbValidData.channel);
        s_outType      = `DC_DMA_REQ_WRCH_LLREAD;
        s_wrllArbReady = s_outputReady;
      end else begin //RD ENG LL
        s_outSegInfo   = r_segInfoLut[s_rdllArbValidData.segment];
        s_outSegNum    = s_rdllArbValidData.segment;
        s_outChan      = CC_NUM_DMA_MAX_CHAN_WIDTH'(s_rdllArbValidData.channel);
        s_outType      = `DC_DMA_REQ_RDCH_LLREAD;
        s_rdllArbReady = s_outputReady;
      end
    end else if (s_wrDataArbValid) begin
      s_outSegInfo     = r_segInfoLut[s_wrDataArbValidData.segment];
      s_outSegNum      = s_wrDataArbValidData.segment;
      s_outChan        = CC_NUM_DMA_MAX_CHAN_WIDTH'(s_wrDataArbValidData.channel);
      s_outType        = `DC_DMA_REQ_WRCH_READ;
      s_wrDataArbReady = s_outputReady;
    end else begin
      s_outSegInfo = '0;
      s_outSegNum  = '0;
      s_outChan    = '0;
      s_outType    = '0;
    end
  end
  
  assign s_llArbRequest = {s_rdllArbValid,s_wrllArbValid};
  assign s_llArbEnable = s_outputReady;

endmodule
