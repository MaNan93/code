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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_timer.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_timer
#(
    parameter WF                    = 16                                // Width of fractional part of local clock register
   )

  (

  input                                   aux_clk,
  input                                   non_sticky_rst_n,
  
  input                                   ptm_timer_run,
  input                                   ptm_timer_re_zero,
  input [7+WF:0]                          ptm_clock_period,
  input                                   ptm_fast_timer,
  input [7:0]                             ptm_long_timer,                       

  output                                  ptm_timer_100us,
  output                                  ptm_timer_10ms
  );


  localparam TP = `TP;

  reg     [27+WF:0]                       ptm_timer_reg;           //1 clk per ns, must be scaled to clk frequency

                           

  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_timer_reg <= #TP 0;

    end else if(ptm_timer_re_zero) begin
      ptm_timer_reg <= #TP 0;

    end else if(ptm_timer_run) begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: ptm_timer_reg wraps around
      ptm_timer_reg <= #TP ptm_timer_reg + ptm_clock_period;
      // spyglass enable_block W164a

    end
  end


  localparam FAST_100US = 'd30000;//'d2000;
  localparam FAST_10MS  = 'd100000;//'d4000;
  localparam HUNDRED_MICRO_SECOND = 'd100000;

  assign ptm_timer_100us  = ptm_timer_re_zero ? 1'b0 : ptm_fast_timer ? (ptm_timer_reg[27+WF:WF] >= FAST_100US) : 
                                             (ptm_timer_reg[27+WF:WF] >= HUNDRED_MICRO_SECOND );

  assign ptm_timer_10ms   = ptm_timer_re_zero ? 1'b0 : ptm_fast_timer ? (ptm_timer_reg[27+WF:WF] >= FAST_10MS) : 
                                             (ptm_timer_reg[27+WF:WF] >= ((ptm_long_timer + 1) * 10 * HUNDRED_MICRO_SECOND ));



endmodule //ptm_timer
