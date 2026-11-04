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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #4 $
// ---    $Author: neira $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_ctl_wr.sv#4 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_buf_pkg.svh"

// Module description:
// 1. Receives master CPL information from MCF
// 2. Drives SBC write control
// 2.1. With optional pipeline
// 3. Drives CPLQ push control and data

module DWC_pcie_amba_mstr_cpl_ctl_wr
  import DWC_pcie_amba_mstr_cpl_buf_pkg::*;
  #(
    parameter type P_MCF_TYPE              = logic
   ,parameter type P_SB_PUSH_TYPE          = logic
   ,parameter type P_SB_POP_TYPE           = logic
   ,parameter type P_SB_FLAGS_TYPE         = logic
   ,parameter type P_CPLQ_TYPE             = logic
   ,parameter type P_CPLQ_INFO_TYPE        = logic
   ,parameter type P_MREQ_TYPE             = logic
   ,parameter type P_LUT_CTL_TYPE          = logic
   ,parameter type P_LUT_DATA_TYPE         = logic
   ,parameter      CX_REMOTE_MAX_TAGS      = 1
   ,parameter      CX_REMOTE_MAX_TAGS_WD   = 1
   ,parameter      P_NUM_SEGS              = 1
   ,parameter      P_SEG_SIZE_WD           = 1
   ,parameter      CC_MSTR_CPL_DATA_SEG_DP = 1
   ,parameter      TP                      = `TP
  ) (
    input  logic           i_clk
   ,input  logic           i_rst_n

    // MREQ interface <- u_ibreq
   ,input  P_MREQ_TYPE     i_mreq

    // MCF interface <-> u_mcf
   ,input  P_MCF_TYPE      i_mcf
   ,output logic           o_mcf_halt

    // SBC pop interface for legacy-mode pipelining
   ,input  P_SB_POP_TYPE   i_sb_pop

    // SBC push interface <-> u_sbc / u_chunkwr
   ,input  P_SB_FLAGS_TYPE i_sb_flags
   ,output P_SB_PUSH_TYPE  o_sb_push

   ,output P_LUT_CTL_TYPE  o_lut_ctl
   ,input  P_LUT_DATA_TYPE i_lut_data

    // CPLQ WR interface <-> u_cplq
   ,output P_CPLQ_TYPE     o_cplq_wr
   ,input  logic           i_cplq_halt
  );

  typedef P_CPLQ_TYPE      cplQ_t;
  typedef P_CPLQ_INFO_TYPE cpl_queue_s;
  typedef P_LUT_CTL_TYPE   lutCtl_t;

  localparam L_SEG_SIZES_WD = P_NUM_SEGS * P_SEG_SIZE_WD;

  logic                                      s_push_start;
  logic                                      s_push;
  logic                                      r_core_rst_n;
  logic                                      rr_core_rst_n;
  logic                                      core_rst_n_redge;
  logic                 [P_SEG_SIZE_WD -1:0] s_enc_data_seg_depth;
  logic                [L_SEG_SIZES_WD -1:0] s_enc_data_segs_depth;
  kWrState_e       [CX_REMOTE_MAX_TAGS -1:0] s_wr_cpl_fsm_state_ary;
  kWrState_e       [CX_REMOTE_MAX_TAGS -1:0] r_wr_cpl_fsm_state_ary;
  logic         [CX_REMOTE_MAX_TAGS_WD -1:0] s_mcf_wr_seg_num;
  logic         [CX_REMOTE_MAX_TAGS_WD -1:0] r_mcf_wr_seg_num;
  logic            [CX_REMOTE_MAX_TAGS -1:0] s_wr_full_vec;
  logic                                      s_wr_full;
  logic            [CX_REMOTE_MAX_TAGS -1:0] shifted_segm_sb_full_m_1_o;
  logic            [CX_REMOTE_MAX_TAGS -1:0] s_first_error_det_ary;
  logic            [CX_REMOTE_MAX_TAGS -1:0] r_first_error_det_ary;
  logic            [CX_REMOTE_MAX_TAGS -1:0] s_split_cpl_eot_ary;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_split_cpl_beat_len;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_split_cpl_dw_len;

  // Atomic status handling support
  logic             [`DC_CPL_STATUS_WD -1:0] r_mcf_err_atomic_status_aux
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic            [CX_REMOTE_MAX_TAGS -1:0] r_mcf_err_atomic_flag;
  logic            [CX_REMOTE_MAX_TAGS -1:0] r_mcf_ep_atomic_flag;

  // DMA CPL reorder support
  logic                                      s_radmx_ireq_np_dma;
  logic            [CX_REMOTE_MAX_TAGS -1:0] r_ireq_np_dma_lut;

  // Cut-through split CPL generation support
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_split_cpl_beat_cnt_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_split_cpl_beat_cnt_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];


  always_comb begin : proc_comb_write_cpl_fsm
    integer i;
    // Initialise
    s_push_start           = 1'b0;
    s_push                 = 1'b0;
    s_wr_cpl_fsm_state_ary = r_wr_cpl_fsm_state_ary;
    s_mcf_wr_seg_num       = r_mcf_wr_seg_num;

    case (r_wr_cpl_fsm_state_ary[i_mcf.wr_seg_num])
      ST_WR_CPL_IDLE  : begin
        if (i_mcf.dv && !s_wr_full) begin
          // Push valid data or single errored beat
          if (!r_first_error_det_ary[i_mcf.wr_seg_num]) begin
            if (!i_mcf.atop_wr_rsp) begin
              s_push_start = i_mcf.dv;
              s_push = i_mcf.dv;
            end
          end

          // If change of segment detected then re-initialise all other FSM's to IDLE state.
          // Transiton FSM for alternate segment numbers from
          // ST_WR_MORE_DATA to ST_WR_CPL_IDLE if master response data is
          // interleaved and the last requested beat has not yet been received.
          // Ensures a push start is generated at the start of every interleaved burst of data.
          s_mcf_wr_seg_num = i_mcf.wr_seg_num;
          for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
            if (i!=i_mcf.wr_seg_num) begin
              if (i_mcf.wr_seg_num!=r_mcf_wr_seg_num) begin
                s_wr_cpl_fsm_state_ary[i] = ST_WR_CPL_IDLE;
              end
            end
          end

          if (!i_mcf.last_pkt_beat) begin
            if (!i_mcf.atop_wr_rsp) begin
              // Transition to MORE_DATA state if not the last beat
              s_wr_cpl_fsm_state_ary[i_mcf.wr_seg_num] = ST_WR_MORE_DATA;
            end
          end
        end
      end
      ST_WR_MORE_DATA : begin
        if (i_mcf.dv && !s_wr_full) begin
          // Stop pushing when error detected.
          if (!r_first_error_det_ary[i_mcf.wr_seg_num]) begin
            if (!i_mcf.atop_wr_rsp) begin
              s_push = i_mcf.dv;
            end
          end

          if (i_mcf.last_pkt_beat) begin
            if (!i_mcf.atop_wr_rsp) begin
              // Transition to IDLE on last beat
              s_wr_cpl_fsm_state_ary[i_mcf.wr_seg_num] = ST_WR_CPL_IDLE;
            end
          end
        end
      end
    endcase
  end

  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_write_cpl_fsm
    if (!i_rst_n) begin
      r_wr_cpl_fsm_state_ary <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
      r_mcf_wr_seg_num       <= # TP {CX_REMOTE_MAX_TAGS_WD{1'b0}};
    end else begin
      r_mcf_wr_seg_num       <= # TP s_mcf_wr_seg_num;
      r_wr_cpl_fsm_state_ary <= # TP s_wr_cpl_fsm_state_ary;
    end
  end

  assign shifted_segm_sb_full_m_1_o = i_sb_flags.full_m1;

  assign s_wr_full_vec = shifted_segm_sb_full_m_1_o |
                         {CX_REMOTE_MAX_TAGS{!i_sb_flags.init_done}} |
                         {CX_REMOTE_MAX_TAGS{i_cplq_halt}};

  assign s_wr_full = s_wr_full_vec[i_mcf.wr_seg_num];

  // The split completion tracker function generates eot immediately when an error
  // is detected and stops tracking.
  // If single beat then push the errored data beat. If multi-beat then stop pushing.
  // When the popped segment is flushed generate a CPL TLP with error status.

  always_comb begin : proc_comb_write_error_flag
    s_first_error_det_ary = r_first_error_det_ary;

    if (i_mcf.dv && !s_wr_full & (!i_mcf.atop_wr_rsp)) begin
      if (i_mcf.last_pkt_beat) begin
        s_first_error_det_ary[i_mcf.wr_seg_num] = 1'b0;
      end else if (i_mcf.error) begin
        s_first_error_det_ary[i_mcf.wr_seg_num] = 1'b1;
      end
    end
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin : proc_seq_write_error_flag
    if (!i_rst_n) begin
      r_first_error_det_ary <= # TP {CX_REMOTE_MAX_TAGS{1'b0}};
    end else begin
      r_first_error_det_ary <= # TP s_first_error_det_ary;
    end
  end

  // ------------------------------------------------------------------------------------
  // Track split completion beats per data segment
  // ------------------------------------------------------------------------------------
  always_comb begin : proc_comb_split_cpl_beat_cnt_ary
    integer i;
    // Initialise
    for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
      s_split_cpl_beat_cnt_ary[i] = r_split_cpl_beat_cnt_ary[i];
    end

    // Track beat count per segment
    for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
      if (i_mcf.dv && !s_wr_full && (i==i_mcf.wr_seg_num)) begin
      // Note: dv de-asserted when halt asserted, effectively holding the beat count
        if (i_mcf.error) begin
          // Re-initialise the beat counter.
          s_split_cpl_beat_cnt_ary[i] = {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
        end else if (s_split_cpl_eot_ary[i]) begin
          if (i_mcf.atop_cpl_queue) begin
            // Reload the beat counter.
            s_split_cpl_beat_cnt_ary[i] = i_lut_data.w_ctl.s_beat_len;
          end
        end else begin
          if (!i_mcf.atop_wr_rsp) begin
            // Decrement the beat counter.
            s_split_cpl_beat_cnt_ary[i] = s_split_cpl_beat_cnt_ary[i]-1;
          end
        end
      end

      if (i_lut_data.first_mreq_np_valid && (i==i_mreq.lookup_id)) begin
        // Load the beat counter.
        s_split_cpl_beat_cnt_ary[i] = i_lut_data.w_mreq.s_beat_len;
      end
    end
  end

  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_split_cpl_beat_cnt_ary
    integer i;
    if (!i_rst_n) begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        r_split_cpl_beat_cnt_ary[i] <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
      end
    end else begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        r_split_cpl_beat_cnt_ary[i] <= # TP s_split_cpl_beat_cnt_ary[i];
      end
    end
  end

  // ------------------------------------------------------------------------------------
  // Generate end of split cpl transfer signal
  // ------------------------------------------------------------------------------------
  always_comb begin : proc_comb_split_cpl_eot
    integer i;
    // Initialise
    s_split_cpl_eot_ary = {CX_REMOTE_MAX_TAGS{1'b0}};

    for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
      if (i_mcf.dv && !s_wr_full && (i==i_mcf.wr_seg_num)) begin
        if (i_mcf.error) begin
          if (i_mcf.last_pkt_beat | i_mcf.atop_wr_rsp) begin
            // Push errored transfer info into completion queue on last errored beat.
            s_split_cpl_eot_ary[i] = 1'b1;
          end
        end else begin
          // Assert end of split cpl transfer on the last accepted beat
          s_split_cpl_eot_ary[i] = (i_mcf.atop_cpl_queue & i_mcf.last_pkt_beat & r_mcf_err_atomic_flag[i_mcf.wr_seg_num]) ? 1'b1 : (r_split_cpl_beat_cnt_ary[i]==1);
        end
      end
    end
  end

  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_atomic_status_err
    integer i;
    if (!i_rst_n) begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1)
        r_mcf_err_atomic_status_aux[i] <= #TP {`DC_CPL_STATUS_WD{1'b0}};
        r_mcf_err_atomic_flag <= #TP {CX_REMOTE_MAX_TAGS{1'b0}};
        r_mcf_ep_atomic_flag <= #TP {CX_REMOTE_MAX_TAGS{1'b0}};
    end else begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        if (i==i_mcf.wr_seg_num) begin

          if (i_mcf.dv & i_mcf.error & !i_mcf.atop_cpl_queue & !r_mcf_err_atomic_flag[i]) begin
            r_mcf_err_atomic_status_aux[i] <= #TP i_mcf.status;
            r_mcf_err_atomic_flag[i]       <= #TP 1'b1;
          end else if (i_mcf.dv & i_mcf.atop_cpl_queue & i_mcf.last_pkt_beat & r_mcf_err_atomic_flag[i] & !s_wr_full) begin
            r_mcf_err_atomic_status_aux[i] <= #TP '0;
            r_mcf_err_atomic_flag[i]       <= #TP 1'b0;
          end

          if (i_mcf.dv & !i_mcf.atop_cpl_queue & !r_mcf_ep_atomic_flag[i]) begin
            r_mcf_ep_atomic_flag[i]       <= #TP i_mcf.ep;
          end else if (i_mcf.dv & i_mcf.atop_cpl_queue & i_mcf.last_pkt_beat & r_mcf_ep_atomic_flag[i] & !s_wr_full) begin
            r_mcf_ep_atomic_flag[i]       <= #TP 1'b0;
          end

        end
      end
    end
  end

  assign s_radmx_ireq_np_dma = i_mreq.dma_type inside {`DC_DMA_REQ_WRCH_READ, `DC_DMA_REQ_WRCH_LLREAD, `DC_DMA_REQ_RDCH_LLREAD};

  always_ff @(posedge i_clk, negedge i_rst_n) begin : ireq_np_dma_lut_PROC
    if (!i_rst_n) begin
      r_ireq_np_dma_lut <= #`TP '0;
    end else begin
      foreach (r_ireq_np_dma_lut[i]) begin
        if (i_mreq.valid && i_mreq.lookup_id == i) begin
          r_ireq_np_dma_lut[i] <= #`TP s_radmx_ireq_np_dma;
        end else begin
          r_ireq_np_dma_lut[i] <= #`TP r_ireq_np_dma_lut[i];
        end
      end
    end
  end

  assign o_lut_ctl = lutCtl_t'{
    pop           : s_split_cpl_eot_ary
   ,lookup_tag    : i_mcf.wr_seg_num
   ,atop_cpl_queue: i_mcf.atop_cpl_queue
  };

  assign s_split_cpl_dw_len   = i_lut_data.w_ctl.r_dw_len & {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{~i_mcf.error}};
  assign s_split_cpl_beat_len = i_mcf.error ? 1 : i_lut_data.w_ctl.r_beat_len;

  // -------------------------------------------------------------------------------------
  // Initialise the segment buffer
  // -------------------------------------------------------------------------------------
  // The segment buffer is configured using the following information:
  // - the number of segments (number of outstanding PCIe NP requests)
  // - the segment buffer address width = log2[Segment Buffer Depth]
  // - the data width of each entry pushed or popped from the segment buffer
  //
  // The depth or number of entries per data segment is dynamically controlled and is
  // configured at power on time. The control block sets the depth for each data segment
  // and triggers initialisation of the segment buffer controller when the power on reset
  // is released. The segment buffer automatically calculates the start and end address
  // for each data segment.

  // The segment buffer controller pushes and pops 1,2,4, or 8 DWORD beats to and from the
  // synchronous 2 port RAM.
  // When the AMBA master data bus width is greater than or equal to the PCIe core data
  // width the total number of entries in the RAM is
  // (((CX_MAX_MTU / 4*CC_MSTR_NW) + 2)*CX_REMOTE_MAX_TAGS)
  // When the AMBA master data bus width is less than the PCIe core data width the total
  // number of entries in the RAM is
  // (((CX_MAX_MTU / 4*CX_NW) + 2)*CX_REMOTE_MAX_TAGS.
  // In 64,128 and 256-bit master data width configurations the data word holes in the
  // first data beat are removed by the DWORD alignment block.

  // Generate initialisation pulse
  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_rr_rst_n
    if (!i_rst_n) begin
      r_core_rst_n <= # TP 1'b0;
      rr_core_rst_n <= # TP 1'b0;
    end else begin
      r_core_rst_n <= # TP 1'b1;
      rr_core_rst_n <= # TP  r_core_rst_n;
    end
  end

  assign core_rst_n_redge = r_core_rst_n & ~rr_core_rst_n;

  // Data segment depth encoding: 0: 1 entry, 1: 2 entries, ... N: N+1 entries
  // The data segment depth is used to dynamically calculate the start and end addresses
  // for each data segment. Encoded data segment depth signal width aligned to
  // segment buffer address width.

  assign s_enc_data_seg_depth = (CC_MSTR_CPL_DATA_SEG_DP-1);

  always @(*) begin : proc_comb_enc_data_seg_depths
    integer i,j;
    // Set data segment depth or number of entries
    // Assign data segment depth to all segments
    for (i=0; i<P_NUM_SEGS; i=i+1) begin
     for (j=0; j<P_SEG_SIZE_WD; j=j+1) begin
       s_enc_data_segs_depth[(i*P_SEG_SIZE_WD)+j] = s_enc_data_seg_depth[j];
     end
    end
  end

  assign o_mcf_halt = s_wr_full;

  assign o_sb_push = P_SB_PUSH_TYPE'{
    start         : s_push_start
   ,en            : s_push
   ,seg           : i_mcf.wr_seg_num
   ,init          : core_rst_n_redge
   ,init_num_segs : P_NUM_SEGS
   ,init_seg_sizes: s_enc_data_segs_depth
  };

  assign o_cplq_wr = cplQ_t'{
    default  : '0
   ,q_valid  : |s_split_cpl_eot_ary && i_mcf.atop_cpl_queue && !r_ireq_np_dma_lut[i_mcf.wr_seg_num]
   ,q        : cpl_queue_s'{
                 default : '0
                ,seg_num : i_mcf.wr_seg_num
                ,beat_len: s_split_cpl_beat_len
                ,dw_len  : s_split_cpl_dw_len
                ,status  : (i_mcf.atop_cpl_queue & r_mcf_err_atomic_flag[i_mcf.wr_seg_num]) ? r_mcf_err_atomic_status_aux[i_mcf.wr_seg_num] : i_mcf.status
                ,ep      : (i_mcf.atop_cpl_queue & r_mcf_ep_atomic_flag[i_mcf.wr_seg_num]) ? r_mcf_ep_atomic_flag[i_mcf.wr_seg_num] : i_mcf.ep 
                ,tc      : i_mcf.tc
                ,last_pkt_beat : i_mcf.last_pkt_beat
               }
   ,dma_valid: |s_split_cpl_eot_ary && r_ireq_np_dma_lut[i_mcf.wr_seg_num]
   ,dma      : cpl_queue_s'{
                 default : '0
                ,seg_num : i_mcf.wr_seg_num
                ,beat_len: s_split_cpl_beat_len
                ,dw_len  : s_split_cpl_dw_len
                ,status  : i_mcf.status
                ,ep      : i_mcf.ep
                ,tc      : i_mcf.tc
                ,last_pkt_beat : i_mcf.last_pkt_beat
               }
   ,atop_cpl_queue: i_mcf.atop_cpl_queue
   ,error         : i_mcf.error
  };

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_amba_mstr_cpl_ctl_wr
