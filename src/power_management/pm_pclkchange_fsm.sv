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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_pclkchange_fsm.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module contains a FSM for pclk change, for PCLK as PHY input.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module pm_pclkchange_fsm #(
    // module parameter port list
    parameter INST              = 0,
    parameter P_R_WD            = `PCLK_RATE_WD,
    parameter PHY_RATE_WD       = (`CX_GEN5_SPEED_VALUE == 1) ? 3 : (`CX_GEN3_SPEED_VALUE == 1) ? 2 : 1,
    parameter NL                = `CX_NL,
    parameter TP                = `TP
)
(
    input                aux_clk,
    input                pipe_clk,
    input                pwr_rst_n,
    input                perst_n,
// ---- inputs ---------------
    input [NL-1:0]       pm_lane_active,
    input [NL-1:0]       phy_mac_pclkchangeok,
    input [NL-1:0]       phy_mac_phystatus,
    input [P_R_WD-1 : 0] phy_if_cpcie_pclk_rate,
    input [(PHY_RATE_WD - 1) : 0] phy_if_cpcie_rate,
    input                pm_req_phy_rst,
    input                link_req_rst_not,
    input                phystatus_done,
    input                pm_pipe_optional_pclkchange_hs,
    input                pclk_hs_rst,
// ---- outputs ---------------
    output logic [6:0]   pm_div_max_pclk_ratio,
    output logic [NL-1:0] mac_phy_pclkchangeack
);



// ------------------------------------------------------------------------------------------
// Logic Declaration
// ------------------------------------------------------------------------------------------
// FSM states

import DWC_pcie_pm_pkg::pclk_change_fsm_state_e;
import DWC_pcie_pm_pkg::PCLK_CHANGE_IDLE;
import DWC_pcie_pm_pkg::WAIT_CHANGEOK_RISE;
import DWC_pcie_pm_pkg::DRV_CLK_DIV;
import DWC_pcie_pm_pkg::DRV_CHANGE_ACK;
import DWC_pcie_pm_pkg::WAIT_CHANGEOK_FALL;
pclk_change_fsm_state_e state_r, next_state_b;

// ----------------------------------------------------------------------------
// Local parameter
// ----------------------------------------------------------------------------
localparam MAX_PCLK_FREQ = `CX_PHY_MAX_PCLK_FREQ_MHZ;
// Convert the MAX PCLK from Mhz to the integer times of 62.5 Mhz.
localparam [6:0] MAX_PCLK_RATE = (MAX_PCLK_FREQ==125)  ?  2 
                               : (MAX_PCLK_FREQ==250)  ?  4
                               : (MAX_PCLK_FREQ==500)  ?  8 
                               : (MAX_PCLK_FREQ==1000) ? 16
                               : (MAX_PCLK_FREQ==2000) ? 32
                               : (MAX_PCLK_FREQ==4000) ? 64 : 0;
// The reset value of mac_phy_pclk_rate
localparam [6:0] MAC_PHY_PCLK_RATE_RST = (`CX_PHY_FREQ ==   4) ? 4  : // 1000MHz
                                         (`CX_PHY_FREQ ==   0) ? 3  : // 500MHz
                                         (`CX_PHY_FREQ ==   1) ? 2  : // 250MHz
                                         (`CX_PHY_FREQ ==   2) ? 1  : // 125MHz
                                                                 0  ; // 62.5MHz
// The reset value of pm_div_max_pclk_ratio
localparam [6:0] DIV_MAX_PCLK_RATIO = MAX_PCLK_RATE >> MAC_PHY_PCLK_RATE_RST;

// ----------------------------------------------------------------------------
// Register types
// ----------------------------------------------------------------------------
logic [NL-1:0] pclkchangeok_r;
logic clock_rate_change;
logic [P_R_WD-1 : 0] pclk_rate_r;
logic [(PHY_RATE_WD - 1) : 0] rate_r;

// ----------------------------------------------------------------------------
// Wire types
// ----------------------------------------------------------------------------
logic pclkchangeok_high;
logic pclkchangeok_fe;
logic [NL-1:0] pclkchangeok_deassert;
logic [6:0] next_div_clock_ratio;
logic phy_status_non_zero;


assign pclkchangeok_high = & (phy_mac_pclkchangeok | ~pm_lane_active); // indicate that all the bits in pclkchangeok are high

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pclkchange_edge_PROC
  if(!pwr_rst_n) begin
    pclkchangeok_r          <= #TP {NL{1'b0}};
  end
  else begin
    if(pclk_hs_rst) begin
      pclkchangeok_r          <= #TP {NL{1'b0}};
    end else begin
      pclkchangeok_r          <= #TP phy_mac_pclkchangeok;
    end 
  end
end : pclkchange_edge_PROC

// Detect pclkchangeok deassertion per lane.
always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pclkchangeok_deassert_PROC
  if (!pwr_rst_n) begin
    pclkchangeok_deassert<= #TP '0;
  end else begin
    foreach(pclkchangeok_deassert[lane]) begin
      if (state_r == PCLK_CHANGE_IDLE) begin
        pclkchangeok_deassert[lane] <= #TP 1'b0;
      end else if (!phy_mac_pclkchangeok[lane] & pclkchangeok_r[lane]) begin
        pclkchangeok_deassert[lane] <= #TP 1'b1;
      end else begin
        pclkchangeok_deassert[lane] <= #TP pclkchangeok_deassert[lane];
      end
    end
  end
end : pclkchangeok_deassert_PROC

assign pclkchangeok_fe = & (pclkchangeok_deassert | ~pm_lane_active);


always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pclk_rate_PROC
  if(!pwr_rst_n) begin
    pclk_rate_r           <= #TP {P_R_WD{1'b0}};
  end
  else begin
    if(pclk_hs_rst) begin
      pclk_rate_r           <= #TP {P_R_WD{1'b0}};
    end else begin
      pclk_rate_r           <= #TP phy_if_cpcie_pclk_rate;
    end
  end
end : pclk_rate_PROC

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : rate_PROC
  if(!pwr_rst_n) begin
    rate_r           <= #TP {PHY_RATE_WD{1'b0}};
  end
  else begin
    if(pclk_hs_rst) begin
      rate_r           <= #TP {PHY_RATE_WD{1'b0}};
    end else begin
      rate_r           <= #TP phy_if_cpcie_rate;
    end
  end
end : rate_PROC

assign clock_rate_change = pm_pipe_optional_pclkchange_hs ? (rate_r != phy_if_cpcie_rate)
                                                          : (pclk_rate_r != phy_if_cpcie_pclk_rate);

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pclkchange_fsm_sync_PROC
  if(!pwr_rst_n) begin
    state_r                 <= #TP PCLK_CHANGE_IDLE;
  end
  else begin
     // fundamental reset puts the FSM back to its IDLE state
    if(pclk_hs_rst) begin
      state_r                 <= #TP PCLK_CHANGE_IDLE;
    end else begin
      state_r                 <= #TP next_state_b;
    end
  end
end : pclkchange_fsm_sync_PROC

assign phy_status_non_zero = |(phy_mac_phystatus & pm_lane_active);

always_comb begin : pclkchange_fsm_PROC
  case(state_r)
    PCLK_CHANGE_IDLE : begin
      if(clock_rate_change && !phy_status_non_zero )
        next_state_b = WAIT_CHANGEOK_RISE;
      else
        next_state_b = PCLK_CHANGE_IDLE;
    end
    WAIT_CHANGEOK_RISE : begin
      if(pclkchangeok_high)
        next_state_b = DRV_CLK_DIV;
      else
        next_state_b = WAIT_CHANGEOK_RISE;
    end
    DRV_CLK_DIV : begin
      next_state_b = DRV_CHANGE_ACK;
    end
    DRV_CHANGE_ACK : begin
      next_state_b = WAIT_CHANGEOK_FALL;
    end
    WAIT_CHANGEOK_FALL : begin
      if(pclkchangeok_fe && phystatus_done)
        next_state_b = PCLK_CHANGE_IDLE;
      else
        next_state_b = WAIT_CHANGEOK_FALL;
    end
    default :
      next_state_b = PCLK_CHANGE_IDLE;
  endcase
end : pclkchange_fsm_PROC

// Calculate the clock ratio for the dividor.
// The valid value range for phy_if_cpcie_pclk_rate is: 0-6, corresponding to 62.5Mhz-4000Mhz.
// The valid value range for MAX_PCLK_RATE is: 2, 4, 8, 16, 32, 64, corresponding to 125Mhz to 4000Mhz.
assign next_div_clock_ratio = MAX_PCLK_RATE >> phy_if_cpcie_pclk_rate;

always_ff @(posedge aux_clk or negedge pwr_rst_n) begin : pd_fsm_outputs_PROC
  if(!pwr_rst_n) begin
    pm_div_max_pclk_ratio           <= #TP DIV_MAX_PCLK_RATIO;
    mac_phy_pclkchangeack           <= #TP {NL{1'b0}};
  end
  else begin
    if(pclk_hs_rst) begin
      pm_div_max_pclk_ratio           <= #TP DIV_MAX_PCLK_RATIO;
      mac_phy_pclkchangeack           <= #TP {NL{1'b0}};
    end else begin
      case(next_state_b)
        PCLK_CHANGE_IDLE : begin
          mac_phy_pclkchangeack       <= #TP {NL{1'b0}};
          pm_div_max_pclk_ratio       <= #TP pm_div_max_pclk_ratio;
        end
        WAIT_CHANGEOK_RISE: begin
          pm_div_max_pclk_ratio       <= #TP pm_div_max_pclk_ratio;
        end
        DRV_CLK_DIV: begin
          pm_div_max_pclk_ratio       <= #TP next_div_clock_ratio;
        end
        DRV_CHANGE_ACK: begin
          mac_phy_pclkchangeack       <= #TP {NL{1'b1}};
          pm_div_max_pclk_ratio       <= #TP pm_div_max_pclk_ratio;
        end
        WAIT_CHANGEOK_FALL: begin
          pm_div_max_pclk_ratio       <= #TP pm_div_max_pclk_ratio;
        end
        default : begin
          mac_phy_pclkchangeack       <= #TP {NL{1'b0}};
        end
      endcase
    end
  end
end : pd_fsm_outputs_PROC

`ifndef SYNTHESIS
initial begin if(MAX_PCLK_RATE == 0) begin $display("%t %m: ERROR: MAX PCLK FREQUENCY should not be 0.", $time); $finish; end end
`endif // !SYNTHESIS

endmodule
