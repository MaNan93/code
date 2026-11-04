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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/min_max_coef.sv#5 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// A queue of coefficients, that is searched every time a new value is pushed,
// to determine if the values contained are converging. The result is provided
// after a fixed amount of clock cycles during which each entry of the queue
// is serially inspected.
// ~1.2 kgates in 65nm with QD=16
// -------------------------------------------------------------------------
module min_max_coef
#(
    parameter CW         = 6, // coefficient width
    parameter QD         = 16, // queue depth
    parameter N_EVALS_WD = 5, // the number of bits used to define the number of consecutive evaluations required for convergence
    // derived
    parameter TP         = `TP,
    parameter QPW        = `CX_LOGBASE2(QD) // queue pointer width
)
(
    input                  core_clk,
    input                  core_rst_n,
    input         [CW-1:0] coef_in,
    input                  coef_in_push,
    input [N_EVALS_WD-1:0] n_evals,
    input [N_EVALS_WD-2:0] max_delta, // the maximum delta betwewen coefficients in the queue, assuming +/-1 changes
    input                  ftune_rtx,
    output                 optimal,
    output                 optimal_upd_pulse
);

reg [CW-1:0] coef_array [QD-1:0];
reg [QPW-1:0] curnt_ptr;
reg [CW-1:0] coef_min, coef_max;
wire ptr_tc;
reg ptr_tc_d;
reg [3:0] ptr_tc_pulse;
reg [CW-1:0] int_delta;
reg int_optimal;
reg [N_EVALS_WD-1:0] push_cnt;
wire n_evals_reached;

// coefficient array
always @(posedge core_clk or negedge core_rst_n) begin : coef_array_seq_PROC
    integer i;
    if (!core_rst_n) begin
        for(i=0; i<QD; i=i+1) begin
            coef_array[i] <= #TP '0;
        end
    end else begin
        if(coef_in_push) begin
            coef_array[0] <= #TP coef_in;
            for(i=1; i<QD; i=i+1) begin
                coef_array[i] <= #TP coef_array[i-1];
            end
        end
    end
end

// count the number of pushes
always @(posedge core_clk or negedge core_rst_n) begin : push_cnt_seq_PROC
    if (!core_rst_n) begin
        push_cnt <= #TP '0;
    end else begin
        if (!ftune_rtx) begin
            push_cnt <= #TP '0;
        end else if (coef_in_push && push_cnt < n_evals) begin // www: reset in case of invalid request not yet implemented
            push_cnt <= #TP push_cnt + 1;
        end
    end
end

// needed to qualify the "optimal" flag
assign n_evals_reached = (push_cnt == n_evals);

// at every push scan the first n_evals locations in the array
always @(posedge core_clk or negedge core_rst_n) begin : curnt_ptr_seq_PROC
    if (!core_rst_n) begin
        curnt_ptr <= #TP QD-1;
    end else begin
        if( coef_in_push || (n_evals == 0) ) begin
            curnt_ptr <= #TP '0;
        end else if (curnt_ptr < (n_evals-1)) begin
            curnt_ptr <= #TP curnt_ptr + 1;
        end
    end
end

// while scanning the array extract min/max values
always @(posedge core_clk or negedge core_rst_n) begin : coef_min_max_seq_PROC
    if (!core_rst_n) begin
        coef_min <= #TP '0;
        coef_max <= #TP '0;
    end else begin
        if(curnt_ptr==0) begin
            coef_min <= #TP coef_array[0];
            coef_max <= #TP coef_array[0];
        end else begin
            if(coef_array[curnt_ptr] < coef_min) begin
                coef_min <= #TP coef_array[curnt_ptr];
            end else if(coef_array[curnt_ptr] > coef_max) begin
                coef_max <= #TP coef_array[curnt_ptr];
            end
        end
    end
end

// total count after n_evals iterations
assign ptr_tc = ( (!coef_in_push && (curnt_ptr == (n_evals-1)) && (n_evals > 0)) || (ftune_rtx & (n_evals == 0)) );

always @(posedge core_clk or negedge core_rst_n) begin : ptr_tc_d_seq_PROC
    if (!core_rst_n) begin
        ptr_tc_d <= #TP '0;
    end else begin
        ptr_tc_d <= #TP ptr_tc;
    end
end

always @(*) begin : ptr_tc_pulse_comb_PROC
    ptr_tc_pulse[0] = ptr_tc & ~ptr_tc_d;
end

// delayed pulsed versions of total count
always @(posedge core_clk or negedge core_rst_n) begin : ptr_tc_pulse_seq_PROC
    if (!core_rst_n) begin
        ptr_tc_pulse[3:1] <= #TP '0;
    end else begin
        ptr_tc_pulse[1] <= #TP ptr_tc_pulse[0];
        ptr_tc_pulse[2] <= #TP ptr_tc_pulse[1];
        ptr_tc_pulse[3] <= #TP ptr_tc_pulse[2];
    end
end

// update the "delta" register one cycle after total count
always @(posedge core_clk or negedge core_rst_n) begin : int_delta_seq_PROC
    if (!core_rst_n) begin
        int_delta <= #TP '0;
    end else begin
        if(ptr_tc_pulse[1]) begin // one cycle after the ptr reaches the tc
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
            int_delta <= #TP coef_max - coef_min;
// spyglass enable_block W164a
        end
    end
end

// update the "optimal" register two cycles after total count
always @(posedge core_clk or negedge core_rst_n) begin : delta_seq_PROC
    if (!core_rst_n) begin
        int_optimal <= #TP 1'b0;
    end else begin
        if (!ftune_rtx) begin
            int_optimal <= #TP '0;
        end else if (ptr_tc_pulse[2] && n_evals_reached) begin // two cycles after the ptr reaches the tc
            int_optimal <= #TP (int_delta > {2'h0,max_delta}) ? 1'b0 : 1'b1; // 2'h0, for spyglass cleaning
        end
    end
end

assign optimal_upd_pulse = ptr_tc_pulse[3];
assign optimal = int_optimal;

`ifndef SYNTHESIS
`ifndef SYNTHESIS
`endif // SYNTHESIS
`endif // !SYNTHESIS


endmodule // min_max_coef
