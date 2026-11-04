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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/timers/DWC_pcie_symbol_timer.sv#7 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module is timing generator for (a) timers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_symbol_timer
(
     input          core_clk
    ,input          core_rst_n
    ,input  [2:0]   current_data_rate
    
    ,output         cnt_up_en           // timer count-up 
);

parameter   TP = `TP;

reg       timer2;

localparam TIM_WD        = 4 ;
localparam [5:0] DIV_GEN6 = `CX_TIME_GEN6_DW;
localparam [5:0] DIV_GEN5 = `CX_TIME_GEN5_DW;
localparam [5:0] DIV_GEN4 = `CX_TIME_GEN4_DW;
localparam [5:0] DIV_GEN3 = `CX_TIME_GEN3_DW;
localparam [5:0] DIV_GEN2 = `CX_TIME_GEN2_DW;
localparam [5:0] DIV_GEN1 = `CX_TIME_GEN1_DW;

reg [TIM_WD-1:0] timer_count;
wire       [4:0] tmp_timer_count;  
always @(posedge core_clk or negedge core_rst_n) begin : g4_mix_timer_count_PROC
    if (!core_rst_n)
        timer_count  <= #TP 0;
    else
        timer_count  <= #TP timer_count + 1'b1;
end

assign tmp_timer_count = $bits(tmp_timer_count)'(timer_count);

function automatic gen_timer2;
 input        [5:0] freq_ratio;
 input        [4:0] timer_count;
 input              timer2; 

begin
    case(freq_ratio)
      1:begin
        gen_timer2 = 1'b1;
      end
      2:begin
        gen_timer2 = ~timer2;
      end
      4:begin
        gen_timer2 = &timer_count[1:0];
      end
      8:begin
        gen_timer2 = &timer_count[2:0];
      end
      16:begin
        gen_timer2 = &timer_count[3:0];
      end
      default:begin
          gen_timer2 = 1'b1;
      end
    endcase
end
endfunction

always @(posedge core_clk or negedge core_rst_n) begin : g4_mix_timer2_PROC
    if (!core_rst_n)
        timer2  <= #TP 1'b0;
    else if (current_data_rate == `GEN6_RATE)
        timer2  <= #TP gen_timer2(DIV_GEN6,tmp_timer_count,timer2);
    else if (current_data_rate == `GEN5_RATE)
        timer2  <= #TP gen_timer2(DIV_GEN5,tmp_timer_count,timer2);
    else if (current_data_rate == `GEN4_RATE)
        timer2  <= #TP gen_timer2(DIV_GEN4,tmp_timer_count,timer2);
    else if (current_data_rate == `GEN3_RATE)
        timer2  <= #TP gen_timer2(DIV_GEN3,tmp_timer_count,timer2);
    else if (current_data_rate == `GEN2_RATE) begin
        timer2  <= #TP gen_timer2(DIV_GEN2,tmp_timer_count,timer2);
    end
    else if (current_data_rate == `GEN1_RATE) begin
        timer2  <= #TP gen_timer2(DIV_GEN1,tmp_timer_count,timer2);
    end
end
assign cnt_up_en = timer2;


endmodule
