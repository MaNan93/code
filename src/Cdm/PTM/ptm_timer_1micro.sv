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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_timer_1micro.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------




`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_timer_1micro
#(
    parameter WF                    = 16                                // Width of fractional part of local clock register
   )

  (
  input                                   aux_clk,
  input                                   non_sticky_rst_n,
  
  input                                   ptm_timer_re_zero,
  input [7+WF:0]                          ptm_clock_period,

  output                                  ptm_timer_1us

  );

  localparam TP = `TP;
  localparam ONE_MICRO_SECOND = 'd1000;


  reg     [10+WF:0]        ptm_timer_1us_reg;           //1 clk per ns




  always@(posedge aux_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      ptm_timer_1us_reg <= #TP ONE_MICRO_SECOND<<WF;

    end else if(ptm_timer_re_zero) begin
      ptm_timer_1us_reg <= #TP 0;

    end else if(!ptm_timer_1us) begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: ptm_timer_1us_reg stops when it reaches 'd1000 (1us)
      ptm_timer_1us_reg <= #TP ptm_timer_1us_reg + ptm_clock_period;
      // spyglass enable_block W164a

    end
  end


  assign ptm_timer_1us    = (ptm_timer_1us_reg[10+WF:WF] >= ONE_MICRO_SECOND );



endmodule //ptm_timer_1us 
