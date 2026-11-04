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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rdbuff_rordr.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Block features:
// - Re-orders completions for each channel number by ensuring only in order segments
// - are released to the rdbuff controllers read segment arbiter.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_edmapf_rdbuff_rordr
  #(
   parameter NUM_DMA_RD_CHAN            = 1,
   parameter NUM_DMA_RD_CHAN_WIDTH      = 1,

   parameter NUM_DMA_RD_SEGMENTS        = 16,
   parameter NUM_DMA_RD_SEGMENTS_WIDTH  = 4
  )
  (
  input  logic                                 clk,
  input  logic                                 reset_n,

  // RD Req Interface
  input  logic                                 tmgr2rordr_req,
  input  logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] tmgr2rordr_req_seg_num,
  input  logic [NUM_DMA_RD_CHAN_WIDTH-1:0]     tmgr2rordr_req_channel,

  // RORDR Interface
  input  logic [NUM_DMA_RD_SEGMENTS-1:0]       seg_pkt_avail,
  input  logic                                 ctrl2rordr_ready,
  output logic                                 rordr2ctrl_valid,
  output logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] rordr2ctrl_seg_num
  );

  typedef struct packed {
    logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] data  ;
    logic                                 valid ;
  } fifoHead_s;

  typedef struct packed {
    logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] tail  ;
    logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] head  ;
    logic                                 valid ;
  } segll_s;

  //******************************************************************************
  // Declare parameters
  //******************************************************************************
  parameter TP                         = `TP;

  localparam NUM_RORD_FIFOS            = NUM_DMA_RD_CHAN;
  localparam NUM_RORD_FIFOS_WIDTH      = $clog2(NUM_RORD_FIFOS);



  // BCM64 transport delay parameters
  localparam integer REG_DELAY_DENOM   = 1000;
  localparam integer REG_DELAY_TIME    = `TP * REG_DELAY_DENOM;


  logic      [NUM_RORD_FIFOS-1:0]                                        push_req_bychan_n_r          ;
  logic      [NUM_RORD_FIFOS-1:0]                                        push_req_bychan_n            ;

  logic      [NUM_RORD_FIFOS-1:0]                                        arb_ch_grant                 ;

  logic      [NUM_RORD_FIFOS-1:0]                                        pop_valid_bychan             ;

  logic      [NUM_RORD_FIFOS-1:0]        [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] pop_seg_num_bychan           ;
  logic      [NUM_RORD_FIFOS-1:0]                                        fifo_empty_bychan            ;
  
  logic      [NUM_RORD_FIFOS-1:0]                                        s_segTableAlmostEmpty        ;
  segll_s    [NUM_RORD_FIFOS-1:0]                                        s_segTable                   ;
  logic      [NUM_DMA_RD_SEGMENTS-1:0]   [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] s_segNext                    ;
  segll_s    [NUM_RORD_FIFOS-1:0]                                        r_segTable                   ;
  logic      [NUM_DMA_RD_SEGMENTS-1:0]   [NUM_DMA_RD_SEGMENTS_WIDTH-1:0] r_segNext                    ;


  //
  // Create a masking push array per channel
  //
  always_comb begin : proc_comb_push_req_bychan
    push_req_bychan_n = push_req_bychan_n_r;
    for (integer i=0;i<NUM_DMA_RD_CHAN;i=i+1) begin
      if (tmgr2rordr_req && i==tmgr2rordr_req_channel) begin
        push_req_bychan_n[i] = 1'b0;
      end else begin
        push_req_bychan_n[i] = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin : proc_seq_push_req_bychan
    if (!reset_n) begin
      push_req_bychan_n_r <= #TP {NUM_RORD_FIFOS{1'b1}};
    end else begin
      push_req_bychan_n_r <= #TP push_req_bychan_n;
    end
  end


  //
  // Match pkt_avail with the next segment to process in each channel. Channel FIFO is ready
  // to pop when it is not empty and there's data already available in SBC for that segment.
  //
  always_comb begin : proc_comb_pop_valid_bychan
    pop_valid_bychan = {NUM_RORD_FIFOS{1'b0}};
    for (integer i=0;i<NUM_RORD_FIFOS;i=i+1) begin
      pop_valid_bychan[i] =  ~fifo_empty_bychan[i] && seg_pkt_avail[pop_seg_num_bychan[i]];
    end
  end

  DWC_pcie_staged_arbiter
   #(
       .P_INPUTS   (NUM_RORD_FIFOS)
      ,.P_STAGES   (3)
      ,.P_DATATYPE (logic [NUM_DMA_RD_SEGMENTS_WIDTH-1:0])
    ) u_rordr_arb(
       .i_clk     (clk)
      ,.i_rst_n   (reset_n)
      ,.i_clr_n   (1'b1)
      ,.i_en      (1'b1)
      ,.i_ready   (ctrl2rordr_ready)
      ,.i_request (pop_valid_bychan)
      ,.i_data    (pop_seg_num_bychan)
      ,.o_grant   (arb_ch_grant)
      ,.o_valid   (rordr2ctrl_valid)
      ,.o_data    (rordr2ctrl_seg_num)
      );

  always_comb begin : pop_seg_num_PROCa
    foreach (pop_seg_num_bychan[i]) begin
      pop_seg_num_bychan[i] = r_segTable[i].head;
      fifo_empty_bychan[i] = !r_segTable[i].valid;
    end
  end

  always_ff @(posedge clk, negedge reset_n) begin : linkedListReg_PROC
    if (!reset_n) begin
      r_segNext  <= #`TP '0;
      r_segTable <= #`TP '0;
    end else begin
      r_segNext  <= #`TP s_segNext;
      r_segTable <= #`TP s_segTable;
    end
  end
 
  always_comb begin : s_segTableAlmostEmpty_PROC
    foreach (s_segTableAlmostEmpty[i]) begin
      s_segTableAlmostEmpty[i] = r_segTable[i].valid && (r_segTable[i].head == r_segTable[i].tail);
    end
  end 

  always_comb begin : s_segTable_PROC
    foreach (s_segTableAlmostEmpty[i]) begin
      case ({r_segTable[i].valid, s_segTableAlmostEmpty[i], arb_ch_grant[i], !push_req_bychan_n[i]})
        4'b0001: /* PUSH      , EMPTY */ s_segTable[i] = '{valid: '1, head: tmgr2rordr_req_seg_num       , tail: tmgr2rordr_req_seg_num};
        4'b1111: /* PUSH & POP, LAST  */ s_segTable[i] = '{valid: '1, head: tmgr2rordr_req_seg_num       , tail: tmgr2rordr_req_seg_num};
        4'b1001: /* PUSH              */ s_segTable[i] = '{valid: '1, head: r_segTable[i].head           , tail: tmgr2rordr_req_seg_num};
        4'b1101: /* PUSH      , LAST  */ s_segTable[i] = '{valid: '1, head: r_segTable[i].head           , tail: tmgr2rordr_req_seg_num};
        4'b1011: /* PUSH & POP        */ s_segTable[i] = '{valid: '1, head: r_segNext[r_segTable[i].head], tail: tmgr2rordr_req_seg_num};
        4'b1010: /*        POP        */ s_segTable[i] = '{valid: '1, head: r_segNext[r_segTable[i].head], tail: r_segTable[i].tail    };
        4'b1110: /*        POP, LAST  */ s_segTable[i] = '{valid: '0, head: '0                           , tail: '0                    };
        default: /* NO UPDATE         */ s_segTable[i] = r_segTable[i];
      endcase
    end
  end 

  always_comb begin : s_segNext_PROC
    s_segNext = r_segNext;
    foreach (s_segTableAlmostEmpty[i]) begin
      case ({r_segTable[i].valid, s_segTableAlmostEmpty[i], arb_ch_grant[i], !push_req_bychan_n[i]})
        4'b1001, /* PUSH              */
        4'b1011, /* PUSH & POP        */
        4'b1101: /* PUSH      , LAST  */ s_segNext[r_segTable[i].tail] = tmgr2rordr_req_seg_num;
      endcase
    end
  end 

endmodule
