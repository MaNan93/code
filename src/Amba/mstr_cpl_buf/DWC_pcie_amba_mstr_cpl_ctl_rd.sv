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
// ---    $Revision: #3 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_ctl_rd.sv#3 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_buf_pkg.svh"

// Module description:

module DWC_pcie_amba_mstr_cpl_ctl_rd
  import DWC_pcie_amba_mstr_cpl_buf_pkg::*;
  #(
    parameter type P_CPLQ_TYPE        = logic
   ,parameter type P_CPLQ_POP_TYPE    = logic
   ,parameter type P_SB_POP_TYPE      = logic
   ,parameter type P_SB_FLAGS_TYPE    = logic
   ,parameter type P_RD_CTL_TYPE      = logic
   ,parameter type P_MREQ_TYPE        = logic
   ,parameter type P_SB_PUSH_TYPE     = logic
   ,parameter      CX_REMOTE_MAX_TAGS = 1
   ,parameter      CX_NFUNC_WD        = 1
   ,parameter      TP                 = `TP
  ) (
    input  logic i_clk
   ,input  logic i_rst_n

   ,input  P_MREQ_TYPE i_mreq

   ,input  P_CPLQ_TYPE i_cplq
   ,output P_CPLQ_POP_TYPE o_cplq_pop

   ,input  P_SB_PUSH_TYPE   i_sb_push

    // SBC pop interface <-> u_sbc / u_chunkrd + u_rd_ltcy
   ,output P_SB_POP_TYPE    o_sb_pop
   ,input  P_SB_FLAGS_TYPE  i_sb_flags
   ,input  logic            i_halt

   ,output P_RD_CTL_TYPE    o_rd_ndly_ctl
   ,output P_CPLQ_TYPE      o_rd_ndly_q
  );

  localparam IREQ_NP_INFO_WD = CX_NFUNC_WD; // Physical function number
  localparam IREQ_NP_INFO_FUNC_MSB = IREQ_NP_INFO_WD-1;

  logic s_sb_ram_rd_en;
  logic r_sb_ram_rd_en;

  P_SB_POP_TYPE   s_sb_pop;
  P_CPLQ_POP_TYPE s_cplq_pop;

  P_RD_CTL_TYPE s_ctl, r_ctl;
  P_CPLQ_TYPE   r_cplq;

  kRdState_e r_rd_cpl_fsm_state;
  kRdState_e s_rd_cpl_fsm_state;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_rd_beat_cnt;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_rd_beat_cnt;

  logic [CX_REMOTE_MAX_TAGS -1:0] shifted_sbc_sb_empty_p_1_o;
  logic [CX_REMOTE_MAX_TAGS -1:0] shifted_sbc_sb_empty_o;

  logic [IREQ_NP_INFO_WD-1:0]                 s_ireq_np_info;
  logic  [IREQ_NP_INFO_WD-1:0]                 r_ireq_np_info_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [IREQ_NP_INFO_WD-1:0]                 s_cpl_rd_info;
  logic [CX_NFUNC_WD-1:0]                     s_cpl_rd_info_func;



  // Read FSM combinational
  always_comb begin : proc_comb_read_cpl_fsm
    // Initialise
    s_sb_ram_rd_en     = r_sb_ram_rd_en;
    // Stop popping header and data queues when halted
    s_sb_pop.en         = 1'b0;
    s_cplq_pop.q_pop    = 1'b0;
    s_cplq_pop.dma_pop = 1'b0;
    // Hold read control signals when halted
    s_ctl.hv = r_ctl.hv;
    s_ctl.dv = r_ctl.dv;
    s_ctl.eot = r_ctl.eot;
    s_ctl.func = '0; // Assigned on another proc
    s_rd_beat_cnt      = r_rd_beat_cnt;
    s_rd_cpl_fsm_state = r_rd_cpl_fsm_state;

    case (r_rd_cpl_fsm_state)
      ST_RD_CPL_IDLE  : begin
        // Drive cpl header/data q control signals to zero when halted
        // For completion queue read pointer stops advancing, next header info
        // held while halt asserted.
        // For seg buf stop ram address advancing, next data held while halt asserted.
        if (!i_halt ) begin // halt active when request pending at client interface (see pipe delay block)
          if (i_cplq.q_valid) begin // split completion available
            // Assert RAM read enable
            s_sb_ram_rd_en = 1'b1;
            // Process read request
            if (i_cplq.q.status==`SU_CPL_STATUS) begin
              s_ctl.dv = 1'b1;
              s_ctl.hv = 1'b1;
              if (i_cplq.q.beat_len!=1) begin
                // If multi-beat completion decrement beat cntr, move to next state
                s_rd_cpl_fsm_state = ST_RD_CPL_MULTI_BEAT;
                // Load beat counter
                s_rd_beat_cnt = i_cplq.q.beat_len-1;
                // Single beat preceeding multi-beat
                s_ctl.eot = 1'b0;
              end else begin
                // Single beat transfer
                if (i_cplq.dma_valid) begin
                  s_cplq_pop.dma_pop = 1'b1;
                end else begin
                  s_cplq_pop.q_pop = 1'b1; // Advance completion q read pointer on end of transfer
                end
                s_ctl.eot = 1'b1;
              end
              // Advance data segment read pointer, next data beat available on next cycle
              s_sb_pop.en = 1'b1;
            end else begin // !SU_CPL_STATUS
              // Errored completion, flush remaining data beats
              // Flush required to preserve integrity of full and empty flags
              if (!shifted_sbc_sb_empty_o[i_cplq.q.seg_num]) begin
                s_sb_pop.en = 1'b1;
              end
              // Assert eot on last flushed data beat.
              // Generate single beat errored completion CPL TLP.
              if (shifted_sbc_sb_empty_p_1_o[i_cplq.q.seg_num]) begin
                s_ctl.eot = 1'b1;
                if (i_cplq.dma_valid) begin
                  s_cplq_pop.dma_pop = 1'b1;
                end else begin
                  s_cplq_pop.q_pop = 1'b1; // Advance completion q read pointer on end of transfer
                end
              end else begin
                s_ctl.eot = 1'b0;
              end
            end

          end else begin
            // De-assert control signals when we have no more entries in the
            // completion header queue
            s_sb_ram_rd_en = 1'b0;
            s_ctl.hv    = 1'b0;
            s_ctl.dv    = 1'b0;
            s_ctl.eot   = 1'b0;
          end
        end
      end
      ST_RD_CPL_MULTI_BEAT : begin
        if (!i_halt) begin
          s_sb_ram_rd_en = 1'b1; // Assert RAM read enable
          s_ctl.hv = 1'b0; // De-assert header valid
          if (s_rd_beat_cnt==1) begin
              // Detect last cycle of split completion; re-intialise FSM, assert eot
              s_rd_cpl_fsm_state = ST_RD_CPL_IDLE;
              s_rd_beat_cnt = {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
              // Pop next entry from the completion queue, assert eot
              s_ctl.eot = 1'b1;
              if (i_cplq.dma_valid) begin
                s_cplq_pop.dma_pop = 1'b1;
              end else begin
                s_cplq_pop.q_pop = 1'b1; // Advance completion q read pointer on end of transfer
              end
          end else begin
              // Decrement
              s_rd_beat_cnt = s_rd_beat_cnt-1;
          end
          s_sb_pop.en = 1'b1;
        end
      end
      default : begin
        s_sb_ram_rd_en     = r_sb_ram_rd_en;
        s_sb_pop.en        = 1'b0;
        s_cplq_pop.q_pop   = 1'b0;
        s_cplq_pop.dma_pop = 1'b0;
        s_ctl.hv        = r_ctl.hv;
        s_ctl.dv        = r_ctl.dv;
        s_ctl.eot       = r_ctl.eot;
        s_rd_beat_cnt      = r_rd_beat_cnt;
        s_rd_cpl_fsm_state = r_rd_cpl_fsm_state;
      end
    endcase

    s_sb_pop.seg       = i_cplq.q.seg_num;
    s_sb_pop.ram_rd_en = (s_sb_ram_rd_en | r_sb_ram_rd_en);
  end

  // Read FSM sequential
  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_read_cpl_fsm
    if (!i_rst_n) begin
      r_rd_cpl_fsm_state <= # TP ST_RD_CPL_IDLE;
      r_sb_ram_rd_en     <= # TP 1'b0;
      r_ctl.hv        <= # TP 1'b0;
      r_ctl.dv        <= # TP 1'b0;
      r_ctl.eot       <= # TP 1'b0;
      r_ctl.last      <= # TP 1'b0;
      r_ctl.func      <= # TP '0;
      r_rd_beat_cnt      <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
    end else if (!i_halt) begin
      r_rd_cpl_fsm_state <= # TP s_rd_cpl_fsm_state;
      r_sb_ram_rd_en     <= # TP s_sb_ram_rd_en;
      r_ctl.hv        <= # TP s_ctl.hv;
      r_ctl.dv        <= # TP s_ctl.dv;
      r_ctl.eot       <= # TP s_ctl.eot;
      r_ctl.last      <= # TP i_cplq.q.last_pkt_beat;
      r_ctl.func      <= # TP '0;
      r_rd_beat_cnt   <= # TP s_rd_beat_cnt;
    end
  end

  assign shifted_sbc_sb_empty_p_1_o = i_sb_flags.empty_p1;
  assign shifted_sbc_sb_empty_o     = i_sb_flags.empty;


  // -------------------------------------------------------------------------------------
  // Align header info with segment pop data.
  // -------------------------------------------------------------------------------------
  always_ff @(posedge i_clk, negedge i_rst_n)
    if(!i_rst_n)     r_cplq <= #TP '0;
    else if(!i_halt) r_cplq <= #TP i_cplq;

  // -------------------------------------------------------------------------------------
  // Store NP request info
  // -------------------------------------------------------------------------------------
  assign s_ireq_np_info = i_mreq.func;

  // Store non-posted request info
  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_ireq_np_info
    integer i;
    if (!i_rst_n) begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        r_ireq_np_info_ary[i] <= # TP {IREQ_NP_INFO_WD{1'b0}};
      end
    end else begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
       if (i_mreq.valid && (i==i_mreq.lookup_id)) begin
         r_ireq_np_info_ary[i] <= # TP s_ireq_np_info;
       end
      end
    end
  end

  // Extract the read segment info
  assign s_cpl_rd_info   = r_ireq_np_info_ary[r_cplq.q.seg_num];
  assign s_cpl_rd_info_func = s_cpl_rd_info[IREQ_NP_INFO_FUNC_MSB -: CX_NFUNC_WD];


  assign o_sb_pop = s_sb_pop;

  assign o_cplq_pop = P_CPLQ_POP_TYPE'{
    q_pop     : s_cplq_pop.q_pop
   ,dma_pop   : s_cplq_pop.dma_pop
   ,halt      : i_halt
  };

  assign o_rd_ndly_ctl = P_RD_CTL_TYPE'{
    hv  : r_ctl.hv
   ,dv  : r_ctl.dv
   ,eot : r_ctl.eot
   ,last: r_ctl.last
   ,func: s_cpl_rd_info_func
  };

  assign o_rd_ndly_q = r_cplq;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_amba_mstr_cpl_ctl_rd
