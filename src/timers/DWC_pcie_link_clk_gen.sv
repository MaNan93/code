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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/timers/DWC_pcie_link_clk_gen.sv#1 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Link Layer clock generator with optional cycle counter
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_link_clk_gen #(
// Parameters
    parameter TIMER_WD  = 1,
    parameter REGOUT_EN = 1,
    parameter TP        = `TP
) (
// -----------------------------------------------------------------------------
// Clock&Reset Interface
// -----------------------------------------------------------------------------
    input                  clk,                     // Clock
    input                  rst_n,                   // Active low asynchronous reset
// -----------------------------------------------------------------------------
// Configuration Interface
// -----------------------------------------------------------------------------
    input  [2:0]           current_data_rate,       // Current data rate
    input  [2:0]           current_cclk_rate,       // Link Layer to LogPHY bandwidth ratio
// -----------------------------------------------------------------------------
// Link Layer Clock Generator Interface
// -----------------------------------------------------------------------------
    input                  link_rst,                // Reset Link Layer clock generator
    input                  link_ena,                // Enable Link Layer clock generator
    output                 link_clk,                // Link Layer clock
// -----------------------------------------------------------------------------
// Link Layer Cycle Counter Interface
// -----------------------------------------------------------------------------
    input                  timer_rst,               // Reset Link Layer cycle counter
    input                  timer_ena,               // Enable Link Layer cycle counter
    input  [TIMER_WD-1:0]  timer_trgt,              // Link Layer cycle counter target value
    output                 timer_done               // Link Layer cycle counter done signal
);

// -------------------------------------------------------------------------
// Internal declarations
// -------------------------------------------------------------------------
logic                  data_rate_cntr_clear;    // Internal clear signal, asserted when clock generator is not enabled
logic                  data_rate_cntr_done;     // Data rate counter done signal (pulse)
logic                  cclk_rate_cntr_done;     // Current Clock rate counter done signal (pulse)
logic  [2:0]           cclk_rate_cntr_nxt;      // Current Clock rate counter - next state
logic  [2:0]           cclk_rate_cntr_r;        // Current Clock rate counter
logic                  link_cclk_cntr_done;     // Link Layer clock cycles counter done signal (pulse)

// -------------------------------------------------------------------------
// Internal assignments
// -------------------------------------------------------------------------
assign data_rate_cntr_clear = !link_ena || link_rst;
assign cclk_rate_cntr_done  = link_ena && data_rate_cntr_done && (cclk_rate_cntr_r == current_cclk_rate);

// -------------------------------------------------------------------------
// Optional Output Register
// -------------------------------------------------------------------------
delay_n
 #(
    .N  (REGOUT_EN),
    .WD (2)
) u_delay_out_reg (
    .clk   (clk),
    .rst_n (rst_n),
    .clear (1'b0),
    .din   ({link_cclk_cntr_done, cclk_rate_cntr_done}),
    .dout  ({timer_done, link_clk})
);

// -------------------------------------------------------------------------
// Generates Link Layer clock based on the current data rate.
// If frequency step is enabled, it also accounts for Link Layer to LogPHY bandwidth ratio.
// -------------------------------------------------------------------------
DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_timer (
    .clk                (clk),
    .rst_n              (rst_n),
    .current_data_rate  (current_data_rate),
    .clr_cntr           (data_rate_cntr_clear),
    .cnt_up_en          (data_rate_cntr_done)
);
// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
// Generates Link Layer clock based on the Link Layer to LogPHY bandwidth ratio
// -------------------------------------------------------------------------
always_comb begin
    if (data_rate_cntr_clear || cclk_rate_cntr_done) begin
        cclk_rate_cntr_nxt = 'd1;
    end else if (data_rate_cntr_done) begin
        cclk_rate_cntr_nxt = cclk_rate_cntr_r + 'd1;
    end else begin
        cclk_rate_cntr_nxt = cclk_rate_cntr_r;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cclk_rate_cntr_r <= #TP '0;
    end else begin
        cclk_rate_cntr_r <= #TP cclk_rate_cntr_nxt;
    end
end
// -------------------------------------------------------------------------

generate
  if (TIMER_WD > 1) begin : gen_timer
// -------------------------------------------------------------------------
// Counts Link Layer clocks until target value
// -------------------------------------------------------------------------
logic                  link_cclk_cntr_clear;    // Internal clear signal, asserted when timer is not enabled
logic  [TIMER_WD-1:0]  link_cclk_cntr_nxt;      // Link Layer clock cycles counter - next state
logic  [TIMER_WD-1:0]  link_cclk_cntr_r;        // Link Layer clock cycles counter

assign link_cclk_cntr_clear = !timer_ena || timer_rst;
assign link_cclk_cntr_done  = timer_ena && cclk_rate_cntr_done && (link_cclk_cntr_r == timer_trgt);

always_comb begin
    if (link_cclk_cntr_clear || link_cclk_cntr_done) begin
        link_cclk_cntr_nxt = 'd1;
    end else if (cclk_rate_cntr_done) begin
        link_cclk_cntr_nxt = link_cclk_cntr_r + 'd1;
    end else begin
        link_cclk_cntr_nxt = link_cclk_cntr_r;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        link_cclk_cntr_r <= #TP '0;
    end else begin
        link_cclk_cntr_r <= #TP link_cclk_cntr_nxt;
    end
end
// -------------------------------------------------------------------------
  end else begin : gen_no_timer
// If Link Layer cycle counter is not enabled (TIMER_WD < 2) then 
// assert done signal with link layer clock pulse
assign link_cclk_cntr_done = timer_ena && cclk_rate_cntr_done;
  end
endgenerate

endmodule
