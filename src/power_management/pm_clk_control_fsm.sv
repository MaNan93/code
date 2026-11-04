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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_clk_control_fsm.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Clock control FSM 
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_clk_control_fsm
  #(
    parameter TP = `TP
  )
  (
    input         sel_aux_clk, // request to switch aux_clk to the slow clock
    input         perst_sel_aux_clk, // perst is asserted so switch to the slow clock
    input         en_core_clk, // request to gate off core_clk
    input         aux_clk_active, // aux_clk switch complete indication
    input         aux_clk, // clock
    input         pwr_rst_n, // reset
    input         pm_drive_pd, // power management logic is driving powerdown to the PHY
    input         gasket_maxpclk_removed,     // Indicate if maxpclk is turned off or not
    output  logic pm_en_core_clk, // enable core clock
    output  logic pm_sel_aux_clk, // switch aux_clk to the slow clock
    output  logic pm_aux_clk_active // aux_clk_active indication
    ,output  logic pm_aux_clk_inactive // aux_clk_inactive indication
  );


typedef enum logic [2:0] {IDLE, SW_AUX_TO_CORE, WAIT_CORE_CLK_EN, EN_CORE_CLK, CORE_CLK_ACTIVE, SW_AUX_CLK, GATE_CORE_CLK, AUX_CLK_ACTIVE} pm_clk_state_e;

pm_clk_state_e rstate, snext_state;

logic s_aux_to_core;

// switch the aux clock to core clock when not selecting aux_clk
assign s_aux_to_core = !sel_aux_clk && !gasket_maxpclk_removed;

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : rstate_PROC
  if (!pwr_rst_n) begin
    rstate <= #TP IDLE;
  end else begin
    rstate <= #TP snext_state;
  end
end : rstate_PROC

always_comb begin : snext_state_PROC
  unique case (rstate)
    SW_AUX_TO_CORE : begin
      // aux_clk switch completed enable core_clk
      if (!aux_clk_active) begin
        snext_state = WAIT_CORE_CLK_EN;
      // If perst is asserted switch aux_clk back to the slow clock
      end else if (perst_sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      end else begin
        snext_state = SW_AUX_TO_CORE;
      end
    end
    WAIT_CORE_CLK_EN : begin
      if (!aux_clk_active && !pm_drive_pd) begin
        snext_state = EN_CORE_CLK;
      // If perst is asserted switch aux_clk back to the slow clock
      end else if (perst_sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      end else begin
        snext_state = WAIT_CORE_CLK_EN;
      end
    end
    EN_CORE_CLK : begin
      // If perst is asserted switch aux_clk back to the slow clock
      if (perst_sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      end
      // Wait for exit from low power state to complete before requesting clock-gating again
      else if (!sel_aux_clk) begin
        snext_state = CORE_CLK_ACTIVE;
      end else begin
        snext_state = EN_CORE_CLK;
      end
    end
    CORE_CLK_ACTIVE : begin
      // request to switch aux_clk to slow
      if (sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      // request to gate core_clk
      end else if (!en_core_clk) begin
        snext_state = GATE_CORE_CLK;
      end else begin
        snext_state = CORE_CLK_ACTIVE;
      end
    end
    SW_AUX_CLK : begin
      // aux_clk switch complete
      if (aux_clk_active) begin
        snext_state = AUX_CLK_ACTIVE;
      end else begin
        snext_state = SW_AUX_CLK;
      end
    end
    GATE_CORE_CLK : begin
      // request to switch aux_clk to slow
      if (sel_aux_clk) begin
        snext_state = SW_AUX_CLK;
      // enable core_clk
      end else if (en_core_clk) begin
        snext_state = CORE_CLK_ACTIVE;
      end else begin
        snext_state = GATE_CORE_CLK;
      end
    end
    AUX_CLK_ACTIVE : begin
      // switch aux_clk to core_clk
      if (s_aux_to_core) begin
        snext_state = SW_AUX_TO_CORE;
      end else begin
        snext_state = AUX_CLK_ACTIVE;
      end
    end
    default : begin
      // request to switch aux_clk to core_clk
      if (s_aux_to_core) begin
        snext_state = SW_AUX_TO_CORE;
      end else begin
        snext_state = IDLE;
      end
    end
  endcase
end : snext_state_PROC

assign pm_en_core_clk = (rstate == EN_CORE_CLK) || (rstate == CORE_CLK_ACTIVE);
assign pm_sel_aux_clk = (rstate == IDLE) || (rstate == SW_AUX_CLK) || (rstate == AUX_CLK_ACTIVE);
assign pm_aux_clk_active = aux_clk_active && pm_sel_aux_clk;
assign pm_aux_clk_inactive = !aux_clk_active && !pm_sel_aux_clk;

endmodule
