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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_ctrl_aux_timer.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- The following module provides a 1us clock enable reference to allow other modules to count time using aux_clk.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module pm_active_ctrl_aux_timer
//#(
//    //parameter ...
//)
(
    input       aux_clk,
    input       pwr_rst_n,
    input [9:0] aux_clk_freq, // aux_clk frequency in MHz, 10 bits (1024 =~ 10^3) are needed to cover a 1000x range (1MHz-1GHz)
                              // aux_clk frequencies lower than 1MHz imply a loss of accuracy. A value of 0 is interpreted as 1024.
    input       timer2,
    input       aux_clk_active,

    output reg  en_1us // clock enable to mark 1us time intervals
);

parameter TP = `TP;                  // Clock to Q delay (simulator insurance)
localparam US_BASETIMER_1US = `CX_US_BASETIMER_1US;
localparam US_BASE_TIMER_WD = `CX_US_BASE_TIMER_WD;

reg [9:0] aux_timer;
wire [10:0] aux_time_1us; // The number of aux_clk cycles in a 1us interval.
reg [US_BASE_TIMER_WD-1 :0]    us_base_timer;
reg                            core_clk_en_1us;
reg                            aux_clk_en_1us; // aux_clk_en_1us is internal signal for pclk as phy input


assign aux_time_1us = (aux_clk_freq==0) ? 1024 : {1'b0, aux_clk_freq}; // 0 is treated as 1024

always @(posedge aux_clk or negedge pwr_rst_n) begin : aux_clk_en_1us_PROC
    if (!pwr_rst_n) begin
        aux_timer <= #TP 0;
        aux_clk_en_1us <= #TP 0;
    end else if (aux_timer >= (aux_time_1us - 1)) begin
        aux_timer <= #TP 0;
        aux_clk_en_1us <= #TP 1;
    end else begin
        aux_timer <= #TP aux_timer + 1;
        aux_clk_en_1us <= #TP 0;
    end
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n) begin
        us_base_timer   <= #TP 0;
        core_clk_en_1us <= #TP 0;
    end else if (us_base_timer >= US_BASETIMER_1US-1) begin
        us_base_timer   <= #TP 0;
        core_clk_en_1us <= #TP 1;
    end else begin
        us_base_timer   <= #TP us_base_timer + (timer2 ? 1'b1 : 1'b0);
        core_clk_en_1us <= #TP 0;
    end
end

assign en_1us = aux_clk_active ? aux_clk_en_1us : core_clk_en_1us;


endmodule // pm_active_ctrl_aux_timer
