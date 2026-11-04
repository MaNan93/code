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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/DWC_pcie_phystatus_fsm.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains an FSM which performs the Phystatus handshake
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_phystatus_fsm
  // Parameters
  #(
    parameter TP = `TP
  ) (
  // Inputs
  input         aux_clk,
  input         pwr_rst_n,
  input         req_phystatus_hs,     // Request to start Phystatus handshake process
  input         phystatus_low,        // Phystatus is low on all active lanes
  input         phystatus_high,       // Phystatus is high on all active lanes
  input         force_transition,     // For debug purposes allow forcing of the Phystatus handshake
  input         phystatus_pclk_ready, // Phystatus sampled low after reset indicating PCLK is stable
  input         pm_perst_powerdown,   // Indicate there is PMA or PIPE reset
  // Outputs
  output  logic phystatus_hs_done_r,  // Indicates that the Phystatus handshake has completed
  output  logic sel_aux_clk_r         // Request to select slow clock as aux_clk and gate off core_clk
);

// -------------------------------------------------------------------------------------
// Logic Declaration
// -------------------------------------------------------------------------------------
logic sel_aux_clk_b;
logic phystatus_hs_done_b;

// -------------------------------------------------------------------------------------
// Types Declaration
// -------------------------------------------------------------------------------------
typedef enum logic [2:0] {
  POR,                  // Power on reset wait for Phystatus to be low before enabling core_clk
  IDLE,                 // Idle state
  WAIT_PHYSTATUS_HIGH,  // Wait for Phystatus to be detected high
  WAIT_PHYSTATUS_LOW,   // Wait for Phystatus to be detected low (1->0 transition)
  CMD_DONE              // Phystatus 0->1->0 transition completed
} PHYSTATUS_STATE_t;

PHYSTATUS_STATE_t state_r, next_state_b;

always_comb begin : phystatus_fsm_PROC
  case (state_r)
    // Initiate Phystatus detection
    IDLE : begin
      if(req_phystatus_hs)
        next_state_b = WAIT_PHYSTATUS_HIGH;
      else
        next_state_b = IDLE;
    end
    // Wait for Phystatus high indication
    WAIT_PHYSTATUS_HIGH : begin
      if(phystatus_high || force_transition || pm_perst_powerdown)
        next_state_b = WAIT_PHYSTATUS_LOW;
      else
        next_state_b = WAIT_PHYSTATUS_HIGH;
    end
    // Wait for Phystatus low indication
    WAIT_PHYSTATUS_LOW : begin
      if(phystatus_low || force_transition || pm_perst_powerdown)
        next_state_b = CMD_DONE;
      else
        next_state_b = WAIT_PHYSTATUS_LOW;
    end
    // Indicate the handshake is done and wait for the request to be cleared
    CMD_DONE : begin
      if(!req_phystatus_hs)
        next_state_b = IDLE;
      else
        next_state_b = CMD_DONE;
    end
    default : begin
      if(phystatus_pclk_ready)
        next_state_b = IDLE;
      else
        next_state_b = POR;
    end // POR
  endcase
end : phystatus_fsm_PROC

assign sel_aux_clk_b = (state_r == POR);
assign phystatus_hs_done_b = (state_r == CMD_DONE);

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin
  if (!pwr_rst_n) begin
    state_r             <= #TP POR;
    sel_aux_clk_r       <= #TP 1'b1;
    phystatus_hs_done_r <= #TP 1'b0;
  end
  else begin
    state_r             <= #TP next_state_b;
    sel_aux_clk_r       <= #TP sel_aux_clk_b;
    phystatus_hs_done_r <= #TP phystatus_hs_done_b;
  end
end

endmodule
