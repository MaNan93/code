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
// ---    $DateTime: 2023/12/15 12:36:02 $
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_svc_fc_merge.sv#15 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module receives 1 interface per FC and merges into a single per VC stream 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_svc_fc_merge
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
  import  xtlh_ms_pkg::P_CTL_CNT_WD;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  xtlh_ms_pkg::count_dw;
  import  cx_pl_pkg::P_NW;
#(
  parameter TP        = `TP
) 
                          (
  input                             core_clk,
  input                             core_rst_n,
  input                             halt_in,                        // Downstream Halt
  input   xtlh_vc_pkt_struct        p_pkt_in,                       // Posted Interface from FC Packer
  input   xtlh_vc_pkt_struct        np_pkt_in,                      // Non-Posted Interface from FC Packer
  input   xtlh_vc_pkt_struct        cpl_pkt_in,                     // CPL Interface from FC Packer
  input                             p_pkt_sot_last,
  input                             p_pkt_eot_last,
  input                             np_pkt_sot_last,
  input                             np_pkt_eot_last,
  input                             cpl_pkt_sot_last,
  input                             cpl_pkt_eot_last,
  input                             rstctl_core_flush_req           // Reset Flush request
  ,
  input                             flit_mode_en,                   // Flit mode
  input                             flit_marker_sent,               // Indicates a flit marker was sent
  output  logic                     xtlh_svc_fc_merge_p_fm_pend,    // Posted Flit Marker Pending
  output  logic                     xtlh_svc_fc_merge_np_fm_pend,   // Non-Posted Flit Marker Pending
  output  logic                     xtlh_svc_fc_merge_cpl_fm_pend,  // CPL Flit Marker Pending
  output  logic                     xtlh_svc_fc_merge_pending,      // Merge is idle
  output  logic                     xtlh_svc_fc_merge_halt_p,       // Halt Posted FC Packer
  output  logic                     xtlh_svc_fc_merge_halt_np,      // Halt Non-Posted FC Packer
  output  logic                     xtlh_svc_fc_merge_halt_cpl,     // Halt CPL FC Packer
  output  xtlh_vc_pkt_struct        xtlh_svc_fc_merge_pkt_out       // Merged Packet Interface
  ,
  output  logic [P_NW_CNT_WD-1:0]   xtlh_svc_fc_merge_next_sot_cnt  // SOT count for next packet
);

localparam P_VC_STRUCT_WD = $bits(xtlh_vc_pkt_struct);

logic                           int_pipe_pending_r;
logic                           int_p_in_progress_r;
logic                           int_np_in_progress_r;
logic                           int_cpl_in_progress_r;
logic                           int_p_pending;
logic                           int_np_pending;
logic                           int_cpl_pending;
logic                           int_merge_halt_p_r;
logic                           int_merge_halt_np_r;
logic                           int_merge_halt_cpl_r;
logic                           int_svc_fc_merge_halt_p;
logic                           int_svc_fc_merge_halt_np;
logic                           int_svc_fc_merge_halt_cpl;
logic                           int_en_pkt_pipe;
logic                           int_svc_merge_halt;
logic [P_NW_CNT_WD-1:0]         int_merge_pkt_sot_cnt;

xtlh_vc_pkt_struct              int_merge_pkt_out;
xtlh_vc_pkt_struct              int_merge_pkt_out_r;
genvar e, s;

typedef enum {
  IDLE,
  POSTED,
  NON_POSTED,
  CPL
  ,
  P_FLIT_MARKER,
  NP_FLIT_MARKER,
  CPL_FLIT_MARKER,
  SEND_FLIT_MARKER
} state_e;

state_e state_r,  next_state;

logic int_send_1cycle_np_fm;
logic int_send_1cycle_cpl_fm;


assign int_send_1cycle_np_fm = ((|np_pkt_in.badeot) || (|np_pkt_in.ep)) && np_pkt_in.sot[0];
assign int_send_1cycle_cpl_fm = ((|cpl_pkt_in.badeot) || (|cpl_pkt_in.ep)) && cpl_pkt_in.sot[0];

always_comb begin : fc_state_PROC
  next_state = state_r;
  case(state_r)
    // Order is P/NP/CPL
    POSTED : begin
      if(!xtlh_svc_fc_merge_halt_p) begin
        if(((|p_pkt_in.badeot) || (|p_pkt_in.ep)) && flit_mode_en)
          next_state = P_FLIT_MARKER;
        else if((int_p_pending == '0) && np_pkt_in.dv)
          next_state = NON_POSTED;
        else if((int_p_pending == '0) && cpl_pkt_in.dv)
          next_state = CPL;
        else
          next_state = POSTED;
      end
    end
    // Order is NP/CPL/P
    NON_POSTED : begin
      if(!xtlh_svc_fc_merge_halt_np) begin
        if(((|np_pkt_in.badeot) || (|np_pkt_in.ep)) && flit_mode_en)
          next_state = NP_FLIT_MARKER;
        else if((int_np_pending == '0) && cpl_pkt_in.dv)
          next_state = CPL;
        else if((int_np_pending == '0) && p_pkt_in.dv)
          next_state = POSTED;
        else
          next_state = NON_POSTED;
      end
    end
    // Order is CPL/P/NP
    CPL : begin
      if(!xtlh_svc_fc_merge_halt_cpl) begin
        if((|(cpl_pkt_in.badeot) || |(cpl_pkt_in.ep)) && flit_mode_en)
          next_state = CPL_FLIT_MARKER;
        else if((int_cpl_pending == '0) && p_pkt_in.dv)
          next_state = POSTED;
        else if((int_cpl_pending == '0) && np_pkt_in.dv)
          next_state = NON_POSTED;
        else
          next_state = CPL;
      end
    end
    P_FLIT_MARKER : begin
      if((|int_merge_pkt_out_r.ep) || (|int_merge_pkt_out_r.badeot))
        next_state = SEND_FLIT_MARKER;
      else
        next_state = P_FLIT_MARKER;
    end
    NP_FLIT_MARKER : begin
      if((|int_merge_pkt_out_r.ep) || (|int_merge_pkt_out_r.badeot))
        next_state = SEND_FLIT_MARKER;
      else
        next_state = NP_FLIT_MARKER;
    end
    CPL_FLIT_MARKER : begin
      if((|int_merge_pkt_out_r.ep) || (|int_merge_pkt_out_r.badeot))
        next_state = SEND_FLIT_MARKER;
      else
        next_state = CPL_FLIT_MARKER;
    end
    SEND_FLIT_MARKER : begin
      if(flit_marker_sent || rstctl_core_flush_req)
        next_state = IDLE;
    end
    default : begin
      if(((|p_pkt_in.badeot) || (|p_pkt_in.ep)) && flit_mode_en)
        next_state = P_FLIT_MARKER;
      else if(int_send_1cycle_np_fm && flit_mode_en)
        next_state = NP_FLIT_MARKER;
      else if(int_send_1cycle_cpl_fm && flit_mode_en)
        next_state = CPL_FLIT_MARKER;
      else if(p_pkt_in.dv)
        next_state = POSTED;
      else if(np_pkt_in.dv)
        next_state = NON_POSTED;
      else if(cpl_pkt_in.dv)
        next_state = CPL;
      else
        next_state = IDLE;
    end
  endcase
end : fc_state_PROC

// No more packet in pipeline
assign xtlh_svc_fc_merge_pending = int_p_in_progress_r || int_np_in_progress_r || int_cpl_in_progress_r || int_merge_pkt_out_r.dv || int_pipe_pending_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin : p_in_prog_PROC
  if(!core_rst_n)
    int_p_in_progress_r <= #TP '0;
  else begin
    if(!xtlh_svc_fc_merge_halt_p) begin
      if(int_p_in_progress_r && p_pkt_eot_last)
        int_p_in_progress_r <= #TP 1'b0;
      else if(p_pkt_sot_last)
        int_p_in_progress_r <= #TP 1'b1;
    end
  end
end : p_in_prog_PROC

// Posted packet ending or posted packet outstanding
assign int_p_pending = (int_p_in_progress_r && !(!xtlh_svc_fc_merge_halt_p && p_pkt_eot_last)) || (!xtlh_svc_fc_merge_halt_p && p_pkt_sot_last);

always_ff @(posedge core_clk or negedge core_rst_n) begin : np_in_prog_PROC
  if(!core_rst_n)
    int_np_in_progress_r <= #TP '0;
  else begin
    if(!xtlh_svc_fc_merge_halt_np) begin
      if(int_np_in_progress_r && np_pkt_eot_last)
        int_np_in_progress_r <= #TP 1'b0;
      else if(np_pkt_sot_last)
        int_np_in_progress_r <= #TP 1'b1;
    end
  end
end : np_in_prog_PROC

assign int_np_pending = (int_np_in_progress_r  && !(!xtlh_svc_fc_merge_halt_np && np_pkt_eot_last)) || (!xtlh_svc_fc_merge_halt_np && np_pkt_sot_last);

always_ff @(posedge core_clk or negedge core_rst_n) begin : cpl_in_prog_PROC
  if(!core_rst_n)
    int_cpl_in_progress_r <= #TP '0;
  else begin
    if(!xtlh_svc_fc_merge_halt_cpl) begin
      if(int_cpl_in_progress_r && cpl_pkt_eot_last)
        int_cpl_in_progress_r <= #TP 1'b0;
      else if(cpl_pkt_sot_last)
        int_cpl_in_progress_r <= #TP 1'b1;
    end
  end
end : cpl_in_prog_PROC

assign int_cpl_pending = (int_cpl_in_progress_r && !(!xtlh_svc_fc_merge_halt_cpl && cpl_pkt_eot_last)) || (!xtlh_svc_fc_merge_halt_cpl && cpl_pkt_sot_last);

always_ff @(posedge core_clk or negedge core_rst_n) begin : fsm_out_sync_PROC
  if(!core_rst_n) begin
    int_merge_halt_p_r    <= #TP '0;
    int_merge_halt_np_r   <= #TP '0;
    int_merge_halt_cpl_r  <= #TP '0;
    state_r               <= #TP IDLE;
  end else begin
    state_r               <= #TP next_state;
    int_merge_halt_p_r    <= #TP int_svc_fc_merge_halt_p;
    int_merge_halt_np_r   <= #TP int_svc_fc_merge_halt_np;
    int_merge_halt_cpl_r  <= #TP int_svc_fc_merge_halt_cpl;
  end
end : fsm_out_sync_PROC

// All TLP's are accepted but they will not be transmitted from XTLH to XDLH
assign xtlh_svc_fc_merge_halt_p   = !rstctl_core_flush_req && int_svc_fc_merge_halt_p;
assign xtlh_svc_fc_merge_halt_np  = !rstctl_core_flush_req && int_svc_fc_merge_halt_np;
assign xtlh_svc_fc_merge_halt_cpl = !rstctl_core_flush_req && int_svc_fc_merge_halt_cpl;

always_comb begin : fsm_out_PROC
  int_svc_fc_merge_halt_p   = int_merge_halt_p_r;
  int_svc_fc_merge_halt_np  = int_merge_halt_np_r;
  int_svc_fc_merge_halt_cpl = int_merge_halt_cpl_r;
  int_merge_pkt_out = '0;
  unique case(state_r)
    POSTED : begin
      int_svc_fc_merge_halt_p   = int_svc_merge_halt && p_pkt_in.dv;
      int_svc_fc_merge_halt_np  = 1'b1;
      int_svc_fc_merge_halt_cpl = 1'b1;
      int_merge_pkt_out = p_pkt_in;
    end
    NON_POSTED : begin
      int_svc_fc_merge_halt_p   = 1'b1;
      int_svc_fc_merge_halt_np  = int_svc_merge_halt && np_pkt_in.dv;
      int_merge_pkt_out = np_pkt_in; 
      int_svc_fc_merge_halt_cpl = 1'b1;
    end
    CPL : begin
      int_svc_fc_merge_halt_p   = 1'b1;
      int_svc_fc_merge_halt_np  = 1'b1;
      int_svc_fc_merge_halt_cpl = int_svc_merge_halt && cpl_pkt_in.dv;
      int_merge_pkt_out = cpl_pkt_in;
    end
    P_FLIT_MARKER : begin
      int_svc_fc_merge_halt_p   = int_svc_merge_halt && p_pkt_in.dv;
      int_svc_fc_merge_halt_np  = 1'b1;
      int_svc_fc_merge_halt_cpl = 1'b1;
      int_merge_pkt_out = p_pkt_in; 
    end
    NP_FLIT_MARKER : begin
      int_svc_fc_merge_halt_p   = 1'b1;
      int_svc_fc_merge_halt_cpl = 1'b1;
      int_svc_fc_merge_halt_np  = int_svc_merge_halt && np_pkt_in.dv;
      int_merge_pkt_out = np_pkt_in; 
    end
    CPL_FLIT_MARKER : begin
      int_svc_fc_merge_halt_p   = 1'b1;
      int_svc_fc_merge_halt_np  = 1'b1;
      int_svc_fc_merge_halt_cpl = int_svc_merge_halt && cpl_pkt_in.dv;
      int_merge_pkt_out = cpl_pkt_in;
    end
    SEND_FLIT_MARKER : begin
      int_svc_fc_merge_halt_p   = 1'b1;
      int_svc_fc_merge_halt_np  = 1'b1;
      int_svc_fc_merge_halt_cpl = 1'b1;
      int_merge_pkt_out = '0;
    end
    default : begin // IDLE
      int_svc_fc_merge_halt_p   = 1'b1;
      int_svc_fc_merge_halt_np  = 1'b1;
      int_svc_fc_merge_halt_cpl = 1'b1;
      int_merge_pkt_out = '0;
    end
  endcase
end : fsm_out_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : fm_pend_PROC
  if(!core_rst_n) begin
    xtlh_svc_fc_merge_p_fm_pend     <= #TP '0;
    xtlh_svc_fc_merge_np_fm_pend    <= #TP '0;
    xtlh_svc_fc_merge_cpl_fm_pend   <= #TP '0;
  end else begin
    if(state_r == P_FLIT_MARKER)
      xtlh_svc_fc_merge_p_fm_pend   <= #TP '1;
    else if(flit_marker_sent)
      xtlh_svc_fc_merge_p_fm_pend   <= #TP '0;
    else
      xtlh_svc_fc_merge_p_fm_pend   <= #TP xtlh_svc_fc_merge_p_fm_pend;
    // Qualify with next state since NP_FLIT_MARKER may not result in flit marker being sent due to ordering
    if((state_r == NP_FLIT_MARKER) && (next_state == SEND_FLIT_MARKER))
      xtlh_svc_fc_merge_np_fm_pend  <= #TP '1;
    else if(flit_marker_sent)
      xtlh_svc_fc_merge_np_fm_pend  <= #TP '0;
    else
      xtlh_svc_fc_merge_np_fm_pend  <= #TP xtlh_svc_fc_merge_np_fm_pend;
    // Qualify with next state since CPL_FLIT_MARKER may not result in flit marker being sent due to ordering
    if((state_r == CPL_FLIT_MARKER) && (next_state == SEND_FLIT_MARKER))
      xtlh_svc_fc_merge_cpl_fm_pend  <= #TP '1;
    else if(flit_marker_sent)
      xtlh_svc_fc_merge_cpl_fm_pend  <= #TP '0;
    else
      xtlh_svc_fc_merge_cpl_fm_pend  <= #TP xtlh_svc_fc_merge_cpl_fm_pend;
  end
end : fm_pend_PROC

// Register incoming packet when available
assign int_en_pkt_pipe = (int_merge_pkt_out.dv && !int_svc_merge_halt) || (!int_merge_pkt_out.dv && int_merge_pkt_out_r.dv && !int_svc_merge_halt);

// Register the packet structure output
// This is the result of the arbitration
delay_n_w_enable
 #(
  .N          (1),
  .WD         (P_VC_STRUCT_WD)
) u_svc_merge_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .en         (int_en_pkt_pipe),
  .clear      (1'b0),
  .din        (int_merge_pkt_out),
  .dout       (int_merge_pkt_out_r)
);

// Track the number of SOT's per cycle only when the first DW contains an SOT
assign int_merge_pkt_sot_cnt = int_merge_pkt_out_r.sot[0] ? count_dw(int_merge_pkt_out_r.sot) : '0;

// Extra Pipeline stage to break the path from the halt back to the arbitration logic
localparam P_PKT_OUT_PIPE_WD = $bits(int_merge_pkt_out_r) + P_NW_CNT_WD;
delay_n_w_stalling
 #(
  .N          (1),
  .CAN_STALL  (1),
  .WD         (P_PKT_OUT_PIPE_WD)
) u_pkt_out_pipe (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .stall      (halt_in),
  .clear      (rstctl_core_flush_req),
  .din        ({int_merge_pkt_out_r, int_merge_pkt_sot_cnt}),
  .dout       ({xtlh_svc_fc_merge_pkt_out, xtlh_svc_fc_merge_next_sot_cnt}),
  .stallout   (int_svc_merge_halt)
);

always_ff @(posedge core_clk or negedge core_rst_n) begin : pipe_pending_PROC
  if(!core_rst_n)
    int_pipe_pending_r  <= #TP 1'b0;
  else begin
    if(rstctl_core_flush_req)
      int_pipe_pending_r  <= #TP 1'b0;
    else if(int_merge_pkt_out_r.dv && !int_svc_merge_halt)
      int_pipe_pending_r  <= #TP 1'b1;
    else if(xtlh_svc_fc_merge_pkt_out.dv && !halt_in)
      int_pipe_pending_r  <= #TP 1'b0;
  end
end : pipe_pending_PROC

endmodule
