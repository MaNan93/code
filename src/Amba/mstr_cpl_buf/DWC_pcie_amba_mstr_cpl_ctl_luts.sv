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
// ---    $Revision: #1 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_ctl_luts.sv#1 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_buf_pkg.svh"

// Module description:

module DWC_pcie_amba_mstr_cpl_ctl_luts
  import DWC_pcie_amba_mstr_cpl_buf_pkg::*;
  #(
    parameter type P_MREQ_TYPE                          = logic
   ,parameter type P_CTL_TYPE                           = logic
   ,parameter type P_DATA_TYPE                          = logic
   ,parameter type P_INNER_DATA_TYPE                    = logic
   ,parameter      CX_REMOTE_MAX_TAGS                   = 1
   ,parameter      CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 = 1
   ,parameter      CX_NFUNC                             = 1
   ,parameter      TP                                   = `TP
  ) (
    input  logic                    i_clk
   ,input  logic                    i_rst_n

   ,input  logic [(3*CX_NFUNC)-1:0] i_cfg_max_payload_size

    // MREQ interface <- u_ibreq
   ,input  P_MREQ_TYPE              i_mreq

   ,input  P_CTL_TYPE               i_ctl
   ,output P_DATA_TYPE              o_data
  );

  typedef P_DATA_TYPE       lutData_t;
  typedef P_INNER_DATA_TYPE lutInnerData_t;

  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_ireq_np_total_dw_len;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -2:0] s_ireq_np_4kb_dw_start_addr;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -2:0] s_ireq_np_4kb_start_addr;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_max_payload_size_dw;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_max_payload_size_dw_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic            [CX_REMOTE_MAX_TAGS -1:0] s_split_cpl_info_valid_ary;
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_split_cpl_dw_len_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_split_cpl_dw_len_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_split_cpl_beat_len_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_split_cpl_beat_len_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -2:0] s_next_split_cpl_start_addr_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -2:0] r_next_split_cpl_start_addr_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] s_remaining_dw_len_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];
  logic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD -1:0] r_remaining_dw_len_ary
                                             [CX_REMOTE_MAX_TAGS-1:0];

  logic                  [(CX_NFUNC*3) -1:0] s_cfg_max_payload_size;

  logic            [CX_REMOTE_MAX_TAGS -1:0] r_first_mreq_np_valid_ary;
  logic                                      s_first_mreq_np_valid;

  // ------------------------------------------------------------------------------------
  // Generate decomposed split completion info per segment
  always_comb begin : proc_comb_calc_split_cpl_dw_len
    integer i;
    // Initialise
    s_split_cpl_info_valid_ary = {CX_REMOTE_MAX_TAGS{1'b0}};
    for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
      s_split_cpl_dw_len_ary[i]           = {`DC_MCB_MAX_CPL_NUM_DWORDS{1'b0}};
      s_next_split_cpl_start_addr_ary[i]  = r_next_split_cpl_start_addr_ary[i];
      s_remaining_dw_len_ary[i]           = r_remaining_dw_len_ary[i];
      s_split_cpl_beat_len_ary[i]         = r_split_cpl_beat_len_ary[i];
    end

    for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
      // Calculate first split completion info
      if (s_first_mreq_np_valid && (i==i_mreq.lookup_id)) begin
        // Generate valid split completion info flag
        s_split_cpl_info_valid_ary[i] = s_first_mreq_np_valid;
        // Calculate the first split completion DWORD length
        s_split_cpl_dw_len_ary[i] = fn_split_cpl_dw_len(s_ireq_np_4kb_start_addr,
                                                        s_max_payload_size_dw,
                                                        s_ireq_np_total_dw_len);
        // Calculate the first split completion beat length
        s_split_cpl_beat_len_ary[i] = fn_split_cpl_dw2beat_len(s_ireq_np_4kb_start_addr,
                                                               s_split_cpl_dw_len_ary[i]);
        // Calculate the next split completion start address
        s_next_split_cpl_start_addr_ary[i] = (`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1)'(s_ireq_np_4kb_start_addr +
                                             s_split_cpl_dw_len_ary[i]);
        // Calculate the remaining number of DWORD's
        // spyglass disable_block W164a
        // SMD: Identifies assignments in which the LHS width is less than the RHS width
        // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
        s_remaining_dw_len_ary[i] = s_ireq_np_total_dw_len - s_split_cpl_dw_len_ary[i];
        // spyglass enable_block W164a
      end
      // Update split completion info on last beat, lsb points to segment 0
      if (i_ctl.pop[i]) begin
        // Generate valid split completion info flag
        s_split_cpl_info_valid_ary[i] = i_ctl.pop[i] & i_ctl.atop_cpl_queue;
        // Calculate the split completion DWORD length
        s_split_cpl_dw_len_ary[i] = fn_split_cpl_dw_len(r_next_split_cpl_start_addr_ary[i],
                                                        r_max_payload_size_dw_ary[i],
                                                        r_remaining_dw_len_ary[i]);
        // Calculate the split completion beat length
        s_split_cpl_beat_len_ary[i] =  (`DC_MCB_MAX_CPL_NUM_DWORDS_WD)'( fn_split_cpl_dw2beat_len
                                                       (r_next_split_cpl_start_addr_ary[i],
                                                        s_split_cpl_dw_len_ary[i]) );
        // Calculate the next split completion start address
        s_next_split_cpl_start_addr_ary[i] = (`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1)'(r_next_split_cpl_start_addr_ary[i] +
                                             s_split_cpl_dw_len_ary[i]);
        // Calculate the remaining number of DWORD's
        // spyglass disable_block W164a
        // SMD: Identifies assignments in which the LHS width is less than the RHS width
        // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
        s_remaining_dw_len_ary[i] = r_remaining_dw_len_ary[i] - s_split_cpl_dw_len_ary[i];
        // spyglass enable_block W164a
      end
    end
  end

  // ------------------------------------------------------------------------------------
  // Store split completion info
  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_calc_split_cpl_dw_len
    integer i;
    if (!i_rst_n) begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        r_next_split_cpl_start_addr_ary[i]  <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
        r_remaining_dw_len_ary[i]           <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
        r_split_cpl_beat_len_ary[i]         <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
        r_split_cpl_dw_len_ary[i]           <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS{1'b0}};
      end
    end else begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        if (s_split_cpl_info_valid_ary[i]) begin
          r_next_split_cpl_start_addr_ary[i] <= # TP s_next_split_cpl_start_addr_ary[i];
          r_remaining_dw_len_ary[i]          <= # TP s_remaining_dw_len_ary[i];
          r_split_cpl_beat_len_ary[i]        <= # TP s_split_cpl_beat_len_ary[i];
          r_split_cpl_dw_len_ary[i]          <= # TP s_split_cpl_dw_len_ary[i]; 
        end
      end
    end
  end

  // Express the total inbound DWORD request length in DWORD's
  assign s_ireq_np_total_dw_len   = `DC_MCB_MAX_CPL_NUM_DWORDS_WD'(i_mreq.dw_len_bytes >> 2);
  // Align the inbound request byte address to DWORD boundaries
  assign s_ireq_np_4kb_dw_start_addr = (`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1)'(i_mreq.s_4kb_start_addr >> 2);
  // Generate the inbound DWORD aligned start address
  always_comb begin : proc_comb_4kb_start_addr
    s_ireq_np_4kb_start_addr = {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};

    if (i_mreq.ncbe) begin
      // If inbound non-posted request contains non-contiguous byte enables then
      // set the start address to the most significant master response DWORD position.
      s_ireq_np_4kb_start_addr[CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2-1:0] =
                               {CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2{1'b1}};
    end else begin
      s_ireq_np_4kb_start_addr = s_ireq_np_4kb_dw_start_addr;
    end
  end

     // Forces the maximum payload size to always match the buffer size when doing descriptors
     always_comb begin : PROC_dmall_np_func
       if ((i_mreq.dma_type ==`DC_DMA_REQ_WRCH_LLREAD) || (i_mreq.dma_type==`DC_DMA_REQ_RDCH_LLREAD)) begin
         case (`CX_MAX_MTU)
           default: s_cfg_max_payload_size = {CX_NFUNC{3'b000}};
           16'd256: s_cfg_max_payload_size = {CX_NFUNC{3'b001}};
           16'd512: s_cfg_max_payload_size = {CX_NFUNC{3'b010}};
           16'd1024:s_cfg_max_payload_size = {CX_NFUNC{3'b011}};
           16'd2048:s_cfg_max_payload_size = {CX_NFUNC{3'b100}};
           16'd4096:s_cfg_max_payload_size = {CX_NFUNC{3'b101}};
         endcase
       end else begin
         s_cfg_max_payload_size = i_cfg_max_payload_size;
       end
     end

  // Extract Max_Payload_Size in DWORD's
  assign s_max_payload_size_dw    = fn_max_payload_size_dw(i_mreq.func[K_NFWD-1:0],
                                                           s_cfg_max_payload_size);

  // Store max payload size per outstanding NP request
  always_ff @(posedge i_clk or negedge i_rst_n) begin : proc_seq_max_pyld_size
    integer i;
    if (!i_rst_n) begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        r_max_payload_size_dw_ary[i] <= # TP {`DC_MCB_MAX_CPL_NUM_DWORDS_WD{1'b0}};
      end
    end else begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        if (s_first_mreq_np_valid && (i==i_mreq.lookup_id)) begin
          r_max_payload_size_dw_ary[i] <= # TP s_max_payload_size_dw;
        end
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // Split completion decomposer
  // -------------------------------------------------------------------------------------
  // Generate decomposed split completion info
  // -------------------------------------------------------------------------------------
  // Detect first decomposed inbound non-posted request
  always_ff @(posedge i_clk, negedge i_rst_n) begin : proc_seq_first_mreq
    integer i;
    if (!i_rst_n) begin
      r_first_mreq_np_valid_ary <= # TP {CX_REMOTE_MAX_TAGS{1'b1}};
    end else begin
      for (i=0; i<CX_REMOTE_MAX_TAGS; i=i+1) begin
        if (i_mreq.valid && i_mreq.last &&
            (i==i_mreq.lookup_id)) begin
          r_first_mreq_np_valid_ary[i] <= # TP 1'b1;
        end else if (i_mreq.valid && (i==i_mreq.lookup_id)) begin
          r_first_mreq_np_valid_ary[i] <= # TP 1'b0;
        end
      end
    end
  end

  assign s_first_mreq_np_valid = i_mreq.valid &
                                 r_first_mreq_np_valid_ary[i_mreq.lookup_id];

  assign o_data = lutData_t'{
    w_ctl: lutInnerData_t'{
      r_dw_len  : r_split_cpl_dw_len_ary[i_ctl.lookup_tag]
     ,r_beat_len: r_split_cpl_beat_len_ary[i_ctl.lookup_tag]
     ,s_beat_len: s_split_cpl_beat_len_ary[i_ctl.lookup_tag]
     ,r_rem_dw_len: r_remaining_dw_len_ary[i_ctl.lookup_tag]
    }
   ,w_mreq: lutInnerData_t'{
      r_dw_len  : r_split_cpl_dw_len_ary[i_mreq.lookup_id]
     ,r_beat_len: r_split_cpl_beat_len_ary[i_mreq.lookup_id]
     ,s_beat_len: s_split_cpl_beat_len_ary[i_mreq.lookup_id]
     ,r_rem_dw_len: r_remaining_dw_len_ary[i_mreq.lookup_id]
    }
   ,first_mreq_np_valid: s_first_mreq_np_valid
  };

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_amba_mstr_cpl_ctl_luts
