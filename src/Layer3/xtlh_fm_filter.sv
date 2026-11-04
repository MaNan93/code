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
// ---    $DateTime: 2024/02/16 12:12:17 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_fm_filter.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- FC Interface filter for flit mode packing 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_fm_filter
  import  xtlh_ms_pkg::P_MERGE_MAX_CNT_WD;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  xtlh_ms_pkg::xtlh_vc_pkt_struct;
#(
  parameter TP  = `TP
) 
                       (
  input                                 core_clk,
  input                                 core_rst_n,
  input                                 flit_mode_en,
  input                                 rstctl_core_flush_req,
  input   xtlh_vc_pkt_struct            p_pkt_in,
  input   xtlh_vc_pkt_struct            np_pkt_in,
  input   xtlh_vc_pkt_struct            cpl_pkt_in,
  input                                 halt_in,
  input                                 p_halt,
  input                                 np_halt,
  input                                 cpl_halt,
  input   [P_NW_CNT_WD - 1 : 0]         p_sot_cnt,
  input   [P_NW_CNT_WD - 1 : 0]         np_sot_cnt,
  input   [P_NW_CNT_WD - 1 : 0]         cpl_sot_cnt,
  input   [P_MERGE_MAX_CNT_WD - 1 : 0]  p_tlp_cnt,
  input   [P_MERGE_MAX_CNT_WD - 1 : 0]  np_tlp_cnt,
  input   [P_MERGE_MAX_CNT_WD - 1 : 0]  cpl_tlp_cnt,
  output  xtlh_vc_pkt_struct            xtlh_fm_filter_p_pkt,   // Posted packet
  output  xtlh_vc_pkt_struct            xtlh_fm_filter_np_pkt,  // Non Posted packet
  output  xtlh_vc_pkt_struct            xtlh_fm_filter_cpl_pkt, // CPL packet
  output  logic                         xtlh_fm_filter_p_halt,
  output  logic                         xtlh_fm_filter_np_halt,
  output  logic                         xtlh_fm_filter_cpl_halt,
  output  logic                         xtlh_fm_filter_stall_req
);

localparam  P_FLIT_CNT_WD = 2;
localparam P_FLIT_CYCLE_WD = $clog2(P_FLIT_CNT_WD);

logic                               int_en_flit_window;
logic                               int_en_flit_window_r;
logic                               int_en_flit_window_re;
logic [P_MERGE_MAX_CNT_WD + 1 : 0]  int_running_tlp_cnt;
logic [P_NW_CNT_WD : 0]             int_running_sot_cnt_r;
logic [P_NW_CNT_WD + 1 : 0]         int_running_sot_cnt;
logic [P_NW_CNT_WD - 1 : 0]         int_p_sot_cnt;
logic [P_NW_CNT_WD - 1 : 0]         int_np_sot_cnt;
logic [P_NW_CNT_WD - 1 : 0]         int_cpl_sot_cnt;
logic [P_MERGE_MAX_CNT_WD + 1 : 0]  int_next_np_sot_cnt;
logic [P_MERGE_MAX_CNT_WD + 1 : 0]  int_next_cpl_sot_cnt;
logic [P_MERGE_MAX_CNT_WD + 1 : 0]  int_next_p_sot_cnt;
logic [P_FLIT_CNT_WD - 1 : 0]       int_flit_window_r;
logic [P_FLIT_CYCLE_WD - 1 : 0]     r_flit_cycle_cnt;
logic                               int_stall_req;
logic                               int_stall_req_r;
logic [P_NW_CNT_WD : 0]             int_total_sot_cnt_r [2:0];
logic [P_NW_CNT_WD : 0]             int_total_sot_cnt;

// spyglass disable_block W164a W164b
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: LHS is sized to accomodate overflow
assign int_total_sot_cnt = int_p_sot_cnt + int_np_sot_cnt + int_cpl_sot_cnt;
// spyglass enable_block W164a W164b

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    for(int i = 0; i < 3; i++)
      int_total_sot_cnt_r[i] <= #TP '0;
  end else begin
    if(rstctl_core_flush_req) begin
      for(int i = 0; i < 3; i++)
        int_total_sot_cnt_r[i] <= #TP '0;
    // shift and load
    end else if(!(p_halt && np_halt && cpl_halt))
      int_total_sot_cnt_r <= #TP {int_total_sot_cnt_r[1:0], int_total_sot_cnt};
    // clear the highest entry after decrementing from the running sot count
    else if(!(int_total_sot_cnt_r[2] == '0)) begin
      int_total_sot_cnt_r[2]    <= #TP '0;
      int_total_sot_cnt_r[1:0]  <= #TP int_total_sot_cnt_r[1:0];
    end
  end
end

always_comb begin : p_sot_cnt_PROC
  int_p_sot_cnt = '0;
  if(!xtlh_fm_filter_p_halt)
    int_p_sot_cnt = p_sot_cnt;
end : p_sot_cnt_PROC

always_comb begin : np_sot_cnt_PROC
  int_np_sot_cnt = '0;
  if(!xtlh_fm_filter_np_halt)
    int_np_sot_cnt = np_sot_cnt;
end : np_sot_cnt_PROC

always_comb begin : cpl_sot_cnt_PROC
  int_cpl_sot_cnt = '0;
  if(!xtlh_fm_filter_cpl_halt)
    int_cpl_sot_cnt = cpl_sot_cnt;
end : cpl_sot_cnt_PROC

// Filtering of packer interfaces based on whether accumulation of more SOT's is possible
always_comb begin : p_pkt_filter_PROC
  if(!flit_mode_en) begin
    xtlh_fm_filter_p_pkt = p_pkt_in;
    xtlh_fm_filter_p_halt = p_halt;
  end else begin
    if(p_pkt_in.sot[0] && ((int_next_p_sot_cnt > 7) || (|int_flit_window_r))) begin
      xtlh_fm_filter_p_pkt = '0;
      xtlh_fm_filter_p_halt = 1'b1;
    end else begin
      xtlh_fm_filter_p_pkt = p_pkt_in;
      xtlh_fm_filter_p_halt = p_halt;
    end
  end
end : p_pkt_filter_PROC

// Filtering of packer interfaces based on whether accumulation of more SOT's is possible
always_comb begin : np_pkt_filter_PROC
  if(!flit_mode_en) begin
    xtlh_fm_filter_np_pkt = np_pkt_in;
    xtlh_fm_filter_np_halt = np_halt;
  end else begin
    if(np_pkt_in.sot[0] && ((int_next_np_sot_cnt > 7) || (|int_flit_window_r))) begin
      xtlh_fm_filter_np_pkt = '0;
      xtlh_fm_filter_np_halt = 1'b1;
    end else begin
      xtlh_fm_filter_np_pkt = np_pkt_in;
      xtlh_fm_filter_np_halt = np_halt;
    end
  end
end : np_pkt_filter_PROC

// Filtering of packer interfaces based on whether accumulation of more SOT's is possible
always_comb begin : cpl_pkt_filter_PROC
  if(!flit_mode_en) begin
    xtlh_fm_filter_cpl_pkt = cpl_pkt_in;
    xtlh_fm_filter_cpl_halt = cpl_halt;
  end else begin
    if(cpl_pkt_in.sot[0] && ((int_next_cpl_sot_cnt > 7) || (|int_flit_window_r))) begin
      xtlh_fm_filter_cpl_pkt = '0;
    xtlh_fm_filter_cpl_halt = 1'b1;
    end else begin
      xtlh_fm_filter_cpl_pkt = cpl_pkt_in;
      xtlh_fm_filter_cpl_halt = cpl_halt;
    end
  end
end : cpl_pkt_filter_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_cycle_PROC
  if(!core_rst_n)
    r_flit_cycle_cnt    <= #TP '0;
  else begin
    if(int_running_sot_cnt_r == 'd0)
      r_flit_cycle_cnt  <= #TP '0;
    else if(!halt_in) begin
      if(&r_flit_cycle_cnt)
        r_flit_cycle_cnt  <= #TP '0;
      else if(!(int_running_sot_cnt_r == 'd0))
        r_flit_cycle_cnt  <= #TP r_flit_cycle_cnt + 1;
      else
        r_flit_cycle_cnt  <= #TP r_flit_cycle_cnt;
    end
  end
end : flit_cycle_PROC

// spyglass disable_block W164a W164b
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: LHS is sized to accomodate overflow
assign int_running_tlp_cnt = p_tlp_cnt + np_tlp_cnt + cpl_tlp_cnt;
assign int_running_sot_cnt = int_running_sot_cnt_r + int_p_sot_cnt + int_np_sot_cnt + int_cpl_sot_cnt;
assign int_next_p_sot_cnt = int_running_sot_cnt_r + p_sot_cnt;
assign int_next_np_sot_cnt = int_running_sot_cnt_r + np_sot_cnt;
assign int_next_cpl_sot_cnt = int_running_sot_cnt_r + cpl_sot_cnt;
// spyglass enable_block W164a W164b

// If total number of TLP's in merge stage or running sot count is greater than or equal to 6 stall the input to allow completion of any in progress TLP before potential halting
assign int_stall_req = ((int_running_sot_cnt_r > 0) && (int_running_tlp_cnt >= 'd6)) || (int_running_sot_cnt >= 'd6);

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_stall_req_r <= #TP 1'b0;
  else begin
    if(int_stall_req_r && !halt_in)
      int_stall_req_r <= #TP 1'b0;
    else if(int_stall_req)
      int_stall_req_r <= #TP int_stall_req;
  end
end

// Once the flit packing limit is reached stall until some TLP's are offloaded when the data path is unhalted
assign xtlh_fm_filter_stall_req = int_stall_req || int_stall_req_r;

assign int_en_flit_window = (int_running_sot_cnt >= 'd6) || (int_en_flit_window_r && !(int_running_sot_cnt_r == 'd0));
assign int_en_flit_window_re = int_en_flit_window && !int_en_flit_window_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_en_flit_window_r  <= #TP 1'b0;
  else
    int_en_flit_window_r  <= #TP int_en_flit_window;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin : running_cnt_PROC
  if(!core_rst_n)
    int_running_sot_cnt_r <= #TP '0;
  else begin
    if(rstctl_core_flush_req)
      int_running_sot_cnt_r <= #TP '0;
    else
// spyglass disable_block W164a W164b
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: LHS is sized to accomodate maximum value of sum of all sot counters
      int_running_sot_cnt_r <= #TP int_running_sot_cnt[P_NW_CNT_WD : 0] - int_total_sot_cnt_r[2];
// spyglass enable_block W164a W164b
  end
end : running_cnt_PROC

// Generate a half flit window where no more TLP's are accepted
always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_window_PROC 
  if(!core_rst_n)
    int_flit_window_r <= #TP '0;
  else begin
    if(rstctl_core_flush_req)
      int_flit_window_r <= #TP '0;
    else begin
      if(int_running_sot_cnt_r == 'd0)
        int_flit_window_r <= #TP '0;
      else if(int_en_flit_window_re)
        int_flit_window_r <= #TP {{(P_FLIT_CNT_WD-1){1'b0}}, 1'b1};
      else if(int_en_flit_window && !halt_in)
        int_flit_window_r <= #TP {int_flit_window_r[P_FLIT_CNT_WD-2:0], 1'b0};
      else
        int_flit_window_r <= #TP int_flit_window_r;
    end
  end
end : flit_window_PROC 


endmodule
