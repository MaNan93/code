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
// ---    $Revision: #4 $
// ---    $Author: lnicola $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_ctl_cplq.sv#4 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

// Module description:

module DWC_pcie_amba_mstr_cpl_ctl_cplq
  #(
    parameter type P_CPLQ_TYPE               = logic
   ,parameter type P_CPLQ_INFO_TYPE          = logic
   ,parameter type P_CPLQ_POP_TYPE           = logic
   ,parameter      CC_MSTR_CPL_QUEUE_DP      = 1
   ,parameter      CC_MSTR_CPL_QUEUE_DP_LOG2 = 1
   ,parameter      TP                        = `TP
  ) (
    input logic            i_wr_clk
   ,input logic            i_wr_rst_n
   ,input logic            i_rd_clk
   ,input logic            i_rd_rst_n

    // CPLQ WR interface <-> u_wr
   ,input  P_CPLQ_TYPE     i_cplq_wr
   ,output logic           o_cplq_wr_halt


    // CPLQ DMA Reorder interface
   ,output P_CPLQ_TYPE     o_cplq_dma
   ,input  P_CPLQ_TYPE     i_cplq_dma
   ,output logic           o_cplq_dma_pop

    // CPLQ RD interface <-> u_rd
   ,output P_CPLQ_TYPE     o_cplq_rd
   ,input  P_CPLQ_POP_TYPE i_cplq_pop
  );

  localparam SYNC_DEPTH  = `CX_PCIE_SYNC_DEPTH;
  

  logic                                      s_cpl_q_wr;
  P_CPLQ_INFO_TYPE                           r_cpl_q_ary [CC_MSTR_CPL_QUEUE_DP-1:0];
  P_CPLQ_INFO_TYPE                           s_cpl_q_ary [CC_MSTR_CPL_QUEUE_DP-1:0];
  logic [CC_MSTR_CPL_QUEUE_DP_LOG2-1:0]      s_cpl_q_wr_ptr;
  logic [CC_MSTR_CPL_QUEUE_DP_LOG2-1:0]      r_cpl_q_wr_ptr;
  logic [CC_MSTR_CPL_QUEUE_DP_LOG2-1:0]      s_cpl_q_rd_ptr;
  logic [CC_MSTR_CPL_QUEUE_DP_LOG2-1:0]      r_cpl_q_rd_ptr;
  logic                                      s_cpl_q_full;
  logic                                      r_cpl_q_full;
  logic                                      s_cpl_q_empty;
  logic                                      r_cpl_q_empty;
  P_CPLQ_INFO_TYPE                           s_cpl_q_rd_info;
  logic                                      s_cpl_q_xfer_pending;
  logic                                      r_cpl_q_dma_xfer_pending;

  // Stage 0 and Stage 1 CPLQ bus
  // Optional stage 0 is AXIG reorder pre-CPL FIFO
  // Mandatory stage 1 is RD/WR decoupling CPL FIFO
  P_CPLQ_TYPE      s0_cplq, s1_cplq;
  logic            s0_halt, s1_halt;
  P_CPLQ_INFO_TYPE s_cpl_q_wr_info;

  assign s0_cplq        = i_cplq_wr;
  assign o_cplq_wr_halt = s0_halt;

  // ---------------------------------------------------------------------------------------
  // 1. Stage 0: AXIG Pre-CPL FIFO
  //           : CDC from i_wr_clk to i_rd_clk
  // ---------------------------------------------------------------------------------------
  // Stage 0 passthrough
  assign s1_cplq = s0_cplq;
  assign s0_halt = s1_halt;

  // ---------------------------------------------------------------------------------------
  // 2. Stage 1: Split CPL FIFO
  //           : Synchronous to i_rd_clk
  // ---------------------------------------------------------------------------------------
  assign s_cpl_q_wr      = s1_cplq.q_valid;
  assign s_cpl_q_wr_info = s1_cplq.q;

  assign o_cplq_dma = P_CPLQ_TYPE'{
    default  : '0
   ,dma_valid: s1_cplq.dma_valid
   ,dma      : s1_cplq.dma
  };

  // Read from completion queue when
  // - first entry written or
  // - current segment data read complete
  // By design the read FSM will not read from the completion queue when empty.
  // SVA: read_when_empty = s_cpl_q_rd && r_cpl_q_empty;
  // Read FSM reads segment data when the completion queue is not empty and
  // advances the read pointer on the last beat of the de-queued split completion.

  // Completion queue combinational
  always_comb begin : proc_comb_cpl_q
    integer i;
    // Initialise
    for (i=0; i<CC_MSTR_CPL_QUEUE_DP; i=i+1) begin
      // Update contents on a write, hold data.
      s_cpl_q_ary[i] = r_cpl_q_ary[i];
    end
    s_cpl_q_rd_ptr   = r_cpl_q_rd_ptr;
    s_cpl_q_wr_ptr   = r_cpl_q_wr_ptr;
    s_cpl_q_empty    = r_cpl_q_empty;
    s_cpl_q_full     = r_cpl_q_full;

    // Increment read pointer
    if (i_cplq_pop.q_pop) begin
      s_cpl_q_rd_ptr = (s_cpl_q_rd_ptr == (CC_MSTR_CPL_QUEUE_DP-1))? 0 : s_cpl_q_rd_ptr + 1; // 2n counter, auto wraps at zero
    end
    // Increment write pointer
    if (s_cpl_q_wr) begin
      s_cpl_q_wr_ptr = (s_cpl_q_wr_ptr == (CC_MSTR_CPL_QUEUE_DP-1))? 0 : s_cpl_q_wr_ptr + 1; // 2n counter, auto wraps at zero
    end
    // Generate empty status flag. Read FSM de-queues completion info and starts
    // reading segment data if the queue is not empty. On the last beat of the
    // transmitted split completion the read pointer is advanced. If the completion
    // queue is not empty the Read FSM starts transmiting the next split completion.
    if (i_cplq_pop.q_pop) begin
      if (s_cpl_q_wr_ptr==s_cpl_q_rd_ptr) begin
        // If reading and pointers are equal then assert empty flag
        s_cpl_q_empty = 1'b1;
      end
    end else if (s_cpl_q_wr) begin
      // If not reading and write active then de-assert empty flag
      s_cpl_q_empty = 1'b0;
    end
    // Generate full status flag. Used to back pressure Write FSM.
    if (s_cpl_q_wr) begin
      if (s_cpl_q_wr_ptr==s_cpl_q_rd_ptr) begin
        // If writing and pointers are equal then assert full flag
        s_cpl_q_full = 1'b1;
      end
    end else if (i_cplq_pop.q_pop) begin
      // If not writng and read active then de-assert full flag
      s_cpl_q_full = 1'b0;
    end
    // Write the read segment information to the completion queue
    if (s_cpl_q_wr) begin
      s_cpl_q_ary[r_cpl_q_wr_ptr] = s_cpl_q_wr_info;
    end
    // Extract read segment information from the completion queue.
    s_cpl_q_rd_info = r_cpl_q_ary[r_cpl_q_rd_ptr];
  end

  // Completion queue sequential
  always_ff @(posedge i_rd_clk, negedge i_rd_rst_n) begin : proc_seq_cpl_q
    integer i;
    if (!i_rd_rst_n) begin
      r_cpl_q_rd_ptr <= # TP {CC_MSTR_CPL_QUEUE_DP_LOG2{1'b0}};
      r_cpl_q_wr_ptr <= # TP {CC_MSTR_CPL_QUEUE_DP_LOG2{1'b0}};
      r_cpl_q_empty  <= # TP 1'b1;
      r_cpl_q_full   <= # TP 1'b0;
      for (i=0; i<CC_MSTR_CPL_QUEUE_DP; i=i+1) begin
        r_cpl_q_ary[i] <= # TP '0;
      end
    end else begin
      r_cpl_q_wr_ptr <= # TP s_cpl_q_wr_ptr;
      r_cpl_q_full   <= # TP s_cpl_q_full;
      r_cpl_q_rd_ptr <= # TP s_cpl_q_rd_ptr;
      r_cpl_q_empty  <= # TP s_cpl_q_empty;
      for (i=0; i<CC_MSTR_CPL_QUEUE_DP; i=i+1) begin
        r_cpl_q_ary[i] <= # TP s_cpl_q_ary[i];
      end
    end
  end

  assign s1_halt = r_cpl_q_full;

  // -------------------------------------------------------------------------------------
  // Extract completion queue header info
  // -------------------------------------------------------------------------------------
  assign s_cpl_q_xfer_pending = !r_cpl_q_empty || i_cplq_dma.dma_valid;

    always_ff @(posedge i_rd_clk, negedge i_rd_rst_n) begin : r_cpl_q_dma_xfer_pending_PROC
      if (!i_rd_rst_n) begin
        r_cpl_q_dma_xfer_pending <= #`TP '0;
      end else begin
        if (!i_cplq_pop.halt && i_cplq_pop.dma_pop) begin
          r_cpl_q_dma_xfer_pending <= #`TP '0;
        end else if (!i_cplq_pop.halt && i_cplq_dma.dma_valid && r_cpl_q_empty) begin
          r_cpl_q_dma_xfer_pending <= #`TP '1;
        end else begin
          r_cpl_q_dma_xfer_pending <= #`TP r_cpl_q_dma_xfer_pending;
        end
      end
    end

  always_comb begin : cpl_q_info_rd_PROC
    // o_cplq_rd.dma not populated from now on, o_cplq_rd.q merges both DMA and non-DMA
    // o_cplq_rd.dma_valid signals to u_rd that this is a dma transaction

    if (i_cplq_dma.dma_valid && r_cpl_q_empty || r_cpl_q_dma_xfer_pending) begin
      o_cplq_rd = P_CPLQ_TYPE'{
        default  : '0
       ,q_valid  : s_cpl_q_xfer_pending
       ,q        : i_cplq_dma.dma
       ,dma_valid: 1'b1
       ,dma_type : i_cplq_dma.dma_type
       ,dma_chan : i_cplq_dma.dma_chan
      };
    end else begin
      o_cplq_rd = P_CPLQ_TYPE'{
        default: '0
       ,q_valid: s_cpl_q_xfer_pending
       ,q      : s_cpl_q_rd_info
      };
    end
  end : cpl_q_info_rd_PROC

  // Pass halt from rd control to DMA re-order
  assign o_cplq_dma_pop = i_cplq_pop.dma_pop;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_amba_mstr_cpl_ctl_cplq
