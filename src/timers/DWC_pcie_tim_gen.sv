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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/timers/DWC_pcie_tim_gen.sv#8 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module is timing generator for (a) timers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_tim_gen
#(
     parameter CLEAR_CNTR_TO_1=0
)
(
     input          clk
    ,input          rst_n

    ,input  [2:0]   current_data_rate
    ,input          clr_cntr            // clear cycle counter
    
    ,output         cnt_up_en           // timer count-up 
);

parameter   TP = `TP;

logic   [6:0]       gen1_freq;        // 62.5MHz, 125MHz or 250MHz
logic   [6:0]       gen1_freq_l1;     // 62.5MHz, 125MHz or 250MHz
logic   [6:0]       gen1_freq_ratio;
logic   [6:0]       gen2_freq;        // 125MHz, 250MHz or 500MHz
logic   [6:0]       gen2_freq_l1;     // 125MHz, 250MHz or 500MHz
logic   [6:0]       gen2_freq_ratio;
logic   [6:0]       gen3_freq;        // 125MHz, 250MHz, 500MHz or 1000MHz
logic   [6:0]       gen3_freq_l1;     // 125MHz, 250MHz, 500MHz or 1000MHz
logic   [6:0]       gen3_freq_ratio;
logic   [6:0]       gen4_freq;        // 125MHz, 250MHz, 500MHz or 1000MHz
logic   [6:0]       gen4_freq_l1;     // 125MHz, 250MHz, 500MHz or 1000MHz
logic   [6:0]       gen4_freq_ratio;
logic   [6:0]       gen5_freq;        // 250MHz, 500MHz, 1000MHz or 2000MHz
logic   [6:0]       gen5_freq_l1;     // 250MHz, 500MHz, 1000MHz or 2000MHz
logic   [6:0]       gen5_freq_ratio;
logic   [6:0]       gen6_freq;        // 500MHz, 1000MHz, 2000MHz or 4000MHz
logic   [6:0]       gen6_freq_l1;     // 500MHz, 1000MHz, 2000MHz or 4000MHz
logic   [6:0]       gen6_freq_ratio;


// genx_freq :
//  1:31.25MHz
//  2:62.5MHz
//  4:125MHz
//  8:250MHz
//  16:500MHz
//  32:1000MHz

assign gen1_freq_l1 = (`CX_NB_GEN1==1)?8:     // 250MHz
                      (`CX_NB_GEN1==2)?4:     // 125MHz
                      (`CX_NB_GEN1==4)?2:2;   // 62.5MHz
assign gen1_freq = gen1_freq_l1;
assign gen1_freq_ratio = $bits(gen1_freq_ratio)'(`CX_MAC_GEN1_DT_RATE);

assign gen2_freq_l1 = (`CX_NB_GEN2==1)?16:    // 500MHz
                      (`CX_NB_GEN2==2)?8:     // 250MHz
                      (`CX_NB_GEN2==4)?4:4;   // 125MHz
assign gen2_freq = gen2_freq_l1;
assign gen2_freq_ratio = $bits(gen2_freq_ratio)'((gen2_freq / gen1_freq) * `CX_MAC_GEN2_DT_RATE);

assign gen3_freq_l1 = (`CX_NB_GEN3==1)?32:    // 1000MHz
                      (`CX_NB_GEN3==2)?16:    // 500MHz
                      (`CX_NB_GEN3==4)?8:     // 250MHz
                      (`CX_NB_GEN3==8)?4:     // 125MHz
                      (`CX_NB_GEN3==16)?2:    // 62.5MHz
                                        8;    // 250MHz
assign gen3_freq = gen3_freq_l1;
assign gen3_freq_ratio = $bits(gen3_freq_ratio)'((gen3_freq / gen1_freq) * `CX_MAC_GEN3_DT_RATE);

assign gen4_freq_l1 = (`CX_NB_GEN4==2)?32:    // 1000MHz
                      (`CX_NB_GEN4==4)?16:    // 500MHz
                      (`CX_NB_GEN4==8)?8:     // 250MHz
                      (`CX_NB_GEN4==16)?4:    // 125MHz
                                       16;    // 500MHz
assign gen4_freq = gen4_freq_l1;
assign gen4_freq_ratio = $bits(gen4_freq_ratio)'((gen4_freq / gen1_freq) * `CX_MAC_GEN4_DT_RATE);

assign gen5_freq_l1 = (`CX_NB_GEN5==2)?64:    // 2000MHz
                      (`CX_NB_GEN5==4)?32:    // 1000MHz
                      (`CX_NB_GEN5==8)?16:    // 500MHz
                      (`CX_NB_GEN5==16)?8:    // 250MHz
                                       32;    // 1000MHz
assign gen5_freq = gen5_freq_l1;
assign gen5_freq_ratio = $bits(gen5_freq_ratio)'((gen5_freq / gen1_freq) * `CX_MAC_GEN5_DT_RATE);

assign gen6_freq_l1 = (`CX_NB_GEN6==4)?64:    // 2000MHz
                      (`CX_NB_GEN6==8)?32:    // 1000MHz
                      (`CX_NB_GEN6==16)?16:   // 500MHz
                      (`CX_NB_GEN6==32)?8:    // 250MHz
                                       32;    // 1000MHz
assign gen6_freq = gen6_freq_l1;
assign gen6_freq_ratio = $bits(gen6_freq_ratio)'((gen6_freq / gen1_freq) * `CX_MAC_GEN6_DT_RATE);

logic   [5:0]   timer_count; // 
logic           timer2;
logic           timer2_comb;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer_count  <= #TP 0;
    end
    else begin
        if( clr_cntr )begin
            timer_count <= #TP CLEAR_CNTR_TO_1;
        end
        else begin
            timer_count  <= #TP timer_count + 1'b1;
        end
    end
end

always_comb begin
    case(current_data_rate)
        0: timer2_comb = gen_timer2(gen1_freq_ratio,timer_count);
        1: timer2_comb = gen_timer2(gen2_freq_ratio,timer_count);
        2: timer2_comb = gen_timer2(gen3_freq_ratio,timer_count);
        3: timer2_comb = gen_timer2(gen4_freq_ratio,timer_count);
        4: timer2_comb = gen_timer2(gen5_freq_ratio,timer_count);
        5: timer2_comb = gen_timer2(gen6_freq_ratio,timer_count);
        default : timer2_comb = 0;
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer2  <= #TP 1'b0;
    end
    else begin
        if( clr_cntr && 
          !((current_data_rate == `GEN1_RATE)
         || (current_data_rate == `GEN2_RATE && gen2_freq_ratio == 1)
         || (current_data_rate == `GEN3_RATE && gen3_freq_ratio == 1)
         || (current_data_rate == `GEN4_RATE && gen4_freq_ratio == 1)
         || (current_data_rate == `GEN5_RATE && gen5_freq_ratio == 1)
         || (current_data_rate == `GEN6_RATE && gen6_freq_ratio == 1)
           )
        )begin
            timer2  <= #TP 1'b0;
        end
        else if ( current_data_rate == `GEN1_RATE )begin
            timer2  <= #TP 1'b1;
        end
        else begin
          timer2 <= #TP timer2_comb;
        end
    end
end

assign cnt_up_en = timer2;

function automatic gen_timer2;
 input      [6:0] freq_ratio;
 input      [5:0] timer_count;

begin
    case(freq_ratio)
      1:begin
        gen_timer2 = 1'b1;
      end
      2:begin
        if( timer_count[0] )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      4:begin
        if( timer_count[1:0] == 2'h3 )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      8:begin
        if( timer_count[2:0] == 3'h7 )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      16:begin
        if( timer_count[3:0] == 4'hf )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      32:begin
        if( timer_count[4:0] == 5'h1f )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      64:begin
        if( timer_count[5:0] == 6'h3f )begin
            gen_timer2 = 1'b1;
        end
        else begin
            gen_timer2 = 1'b0;
        end
      end
      default:begin
          gen_timer2 = 1'b1;
      end
    endcase
end
endfunction


endmodule
