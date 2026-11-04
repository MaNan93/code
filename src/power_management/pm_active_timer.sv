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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_timer.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// --- This module implements a watchdog timer for the pm_active_ctrl FSM 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_active_timer
  // Parameters
  #(
  parameter TP = `TP
  )
  
                         (
  // Inputs
  input       core_clk,     // Timer clock
  input       core_rst_n,   // Reset
  input       smlh_in_rl0s, // LTSSM is in rL0s
  input       usp_prot_wait_dstate_update, // usp link fsm is in wait_dstate_update.
  input       smlh_in_l0,   // LTSSM is in L0
  // Outputs
  output wire pm_timeout    // Timeout
);

// ----------------------------------------------------------------------------
// Parameter Declarations
// ----------------------------------------------------------------------------
localparam  SCALE_WD = 2,
            TARGET_WD = 8;

localparam  [SCALE_WD - 1 : 0]  SCALE = 2'b11;
localparam  [TARGET_WD - 1 : 0] TARGET = 8'hff;

// ----------------------------------------------------------------------------
// Net Declarations
// ----------------------------------------------------------------------------
wire int_enable_timer;
wire  int_hold_timer;

// The timer is enabled in the WAIT_DSTATE_UPDATE state and acts as
// a watchdog in case CfgWr did not target the PMCSR and L1 entry
// conditions remain satisfied after the CfgWr
assign int_enable_timer = usp_prot_wait_dstate_update;

// If the LTSSM is not in L0 the timer holds its value
assign int_hold_timer = !smlh_in_l0 && !smlh_in_rl0s && int_enable_timer;

// Timer instantiation
pm_timer

  #(
  .SCALE_WD   (SCALE_WD),
  .TARGET_WD  (TARGET_WD)
  ) u_pm_timer (
  // Inputs
  .aux_clk          (core_clk),
  .pwr_rst_n        (core_rst_n),
  .scale            (SCALE),
  .target           (TARGET),  
  .enable           (int_enable_timer),
  .hold_timer       (int_hold_timer),
  // Outputs
  .pm_timer_timeout (pm_timeout)
);


endmodule
