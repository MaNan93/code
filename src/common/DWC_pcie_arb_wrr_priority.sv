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
// --- RCS information:
// ---   $DateTime: 2024/01/10 14:23:51 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_arb_wrr_priority.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: weight-2-priority converter (intened to be used for ARB/MUX arbitration)
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_arb_wrr_priority
#(
    parameter TP       = `TP,
    parameter N        = 2,
    parameter WT_WIDTH = 4
) 
                                (
// Inputs ------------------------------------------------------------------------------
    input                             core_clk,               // Core clock
    input                             core_rst_n,             // Core reset
    input                             enable,                 // enable arbitration request
    input   [N-1:0][WT_WIDTH-1:0]     cfg_weight,             // client Weighted Round Robin Arbitration Weight
    input   [N-1:0]                   gnt_in,                 // grant bus
// Outputs ------------------------------------------------------------------------------    
    output  logic [N-1:0]             pri_out                 // priority bus
);

logic [N-1:0][WT_WIDTH-1:0]       wt_cnt_nxt, wt_cnt_r;       // weight counts
logic [N-1:0]                     pri_sel_nxt, pri_sel_r;     // active high priority
logic [N-1:0]                     wt_done;                    // combinatinal flag when weight_count reaches cfg_weight

// assign priority during active weight counts
always_comb begin
    for (integer i=0; i <N; i++) begin
        pri_out[i] = pri_sel_r[i] && !wt_done[i];
    end
end

// -------------------------------------------------------------------------------------
// weight to priority conversion based on the arbiter grant
// -------------------------------------------------------------------------------------
always_comb begin
    wt_cnt_nxt  = wt_cnt_r;
    pri_sel_nxt = pri_sel_r;
    
    for (integer i=0; i <N; i++) begin
        wt_done[i] = 1'b0;

        // use priority only when weights are enabled
        if (gnt_in[i] && |cfg_weight[i]) begin
            pri_sel_nxt[i] = 1'b0;
            // when granted and enabled and wt then increment the weight counts
            if (wt_cnt_r[i] < cfg_weight[i]) begin
                //set priority that next grant will be the same if there is another request from same client
                pri_sel_nxt[i] = 1'b1;
                if (enable) begin
                    wt_cnt_nxt[i] = wt_cnt_r[i] + 1'b1;
                end   
            end

            // reset weight counters when all weight counters reached their configured value
            if ((wt_cnt_r[0]==cfg_weight[0]) && (wt_cnt_r[1]==cfg_weight[1])) begin    
                wt_cnt_nxt = '0;
                pri_sel_nxt = '0;
                // if enable is set (68B mode continuously set) then set priority and increment wt_cnt for this grant
                if (enable) begin
                    pri_sel_nxt[i] = 1'b1;
                    wt_cnt_nxt[i]  = 4'b1;  // if enabled (68B mode) then current flit counts at 0 and next will be 1
                end 
            end
        end // gnt_in[i]
        
        // combinatinal logic wt_done must be separated from gnt to avoid sim hangs/comb loops 
        if (wt_cnt_r[i] == cfg_weight[i]) begin
            wt_done[i] = 1'b1;
        end
    end
end

// -------------------------------------------------------------------------------------
// clocked process
// -------------------------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        wt_cnt_r     <= # TP '0;
        pri_sel_r    <= # TP '0;
    end
    else begin 
        wt_cnt_r     <= # TP wt_cnt_nxt;
        pri_sel_r    <= # TP pri_sel_nxt;
    end
end

endmodule
