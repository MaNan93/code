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
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_ack_cnt.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Ack Counter
// Implements the Ack counter to track received error free flits.
// Implements the Ack flush timer for flushing accumulated Acks during Idle.
// Interfaces with credit control FSM.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_ack_cnt
  import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)(
  input                                 core_clk,                 // Core clock
  input                                 core_rst_n,               // Core reset
  input                                 link_layer_clk,           // Link Layer Clock for Ack Flush Timer
  input                                 cxl_rx_retryable_flit,    // Received an error free retryable flit
  input [(ACK_CNT_WD - 1) : 0]          cxl_flit_full_ack,        // Full Ack field from the LLCRD flit
  input                                 cxl_arb_crdret_empty,     // No Credit Return
  input                                 cxl_fgen_ack_timer_rst,   // Reset Acknowledge Flash Time
  input [(ACK_CNT_WD - 1) : 0]          cfg_ack_force_threshold,  // Ack force threshold
  input [(ACK_FLUSH_TIMER_WD - 1) : 0]  cfg_ack_flush_timer,      // Ack flush timer width
  input                                 cfg_en_ack_flush_timer,   // Enable the ack flush timer
  output logic                          cxl_ack_cnt_ovflw,        // Ack Counter Overflow
  output logic [(ACK_CNT_WD - 1) : 0]   cxl_ack_cnt_full,         // Full Ack Counter
  output logic                          cxl_ack_cnt_flit_ack,     // Set the Ack bit in outgoing flit
  output logic                          cxl_ack_cnt_force_llcrd   // Inject LLCRD flit
);

// Parameters
localparam [(ACK_FLUSH_TIMER_WD - 1) : 0] ACK_FLUSH_RST_VAL = {ACK_FLUSH_TIMER_WD{1'b0}};

// Declarations
logic                                 s_en_ack_flush_timer;
logic [(ACK_FLUSH_TIMER_WD - 1) : 0]  s_incr_flush_timer;
logic                                 s_ack_flush_timeout;
logic                                 s_ack_cnt_force_llcrd;
logic [(ACK_CNT_WD - 1) : 0]          s_ack_cnt;
logic                                 s_ack_cnt_ovflw;

// Enable the ack flush timer when link is idle and ack count is not zero
assign s_en_ack_flush_timer  = cfg_en_ack_flush_timer && (|cfg_ack_flush_timer) && ( (cxl_ack_cnt_full > 'd1) || !cxl_arb_crdret_empty) && link_layer_clk;
assign s_incr_flush_timer    = {{(ACK_FLUSH_TIMER_WD - 1){1'b0}}, 1'b1};
// LLCRD flit forcing when Ack count reaches threshold or Ack flush timer expires
assign s_ack_cnt_force_llcrd = (cxl_ack_cnt_full == cfg_ack_force_threshold) || (s_ack_flush_timeout);

// If Ack count is 8 the Ack bit in the next flit can be set
assign cxl_ack_cnt_flit_ack  = |cxl_ack_cnt_full[ACK_CNT_WD-1:3];
// Ack Counter
assign {s_ack_cnt_ovflw, s_ack_cnt} = {1'b0, cxl_ack_cnt_full} + cxl_rx_retryable_flit - cxl_flit_full_ack;

// Ack flush timer
DWC_cxl_base_timer

  // Parameters
  #(
  .TIMER_WIDTH  (ACK_FLUSH_TIMER_WD),
  .RST_VALUE    (ACK_FLUSH_RST_VAL)
  ) u_ack_flush_timer (
  // Inputs
  .clk          (core_clk),
  .rst_n        (core_rst_n),
  .clear_timer  (cxl_fgen_ack_timer_rst),
  .hold_timer   (1'b0),
  .enable       (s_en_ack_flush_timer),
  .timer_target (cfg_ack_flush_timer),
  .incr         (s_incr_flush_timer),
  // Outputs
  .timeout_r    (s_ack_flush_timeout),
  .timeout      (),
  .timer_r      ()
);

always_ff @(posedge core_clk or negedge core_rst_n) begin : ack_cnt_proc
  if (!core_rst_n) begin
    cxl_ack_cnt_full        <= # TP {ACK_CNT_WD{1'b0}};
    cxl_ack_cnt_ovflw       <= # TP 1'b0;
    cxl_ack_cnt_force_llcrd <= # TP 1'b0;
  end else begin
    cxl_ack_cnt_full        <= # TP s_ack_cnt;
    cxl_ack_cnt_ovflw       <= # TP s_ack_cnt_ovflw;
    cxl_ack_cnt_force_llcrd <= # TP s_ack_cnt_force_llcrd;
  end
end : ack_cnt_proc

endmodule
