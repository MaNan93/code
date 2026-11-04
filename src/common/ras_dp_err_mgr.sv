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


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module ras_dp_err_mgr
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::ERR_INJ_FAILURE;
import DWC_pcie_ctl_pkg::ERR_INJ_SUCCESSFUL;
import DWC_pcie_ctl_pkg::CORRECTABLE;
import DWC_pcie_ctl_pkg::UNCORRECTABLE;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_WD;
import DWC_pcie_ctl_pkg::MAX_RAS_ERR_LOG_WORD_NUM;
#(
    parameter BLOCK_RAS_DP_PROT_CHK_N         = 64,
    parameter CAN_RECEIVE_LONG_ERR_LOG_FORMAT = 0
)
(
    input  logic                                          clk,
    input  logic                                          rst_n,
    
    output logic                                          out_ras_dp_wake_up,
    
    input  ras_dp_err_inj_t                               in_ras_dp_err_inj,
    output ras_dp_err_inj_t                               out_ras_dp_err_inj,
    input  ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0] in_ras_dp_err_log,
    output ras_dp_err_log_t                               out_ras_dp_err_log
);

logic [BLOCK_RAS_DP_PROT_CHK_N-1:0]       c_err_log_status,           r_err_log_status;
logic [BLOCK_RAS_DP_PROT_CHK_N-1:0]       c_in_err_log_second_cycle,  r_in_err_log_second_cycle;
logic [$clog2(MAX_RAS_PROT_CHK_N)-1:0]    c_out_err_ras_prot_chk_id,  r_out_err_ras_prot_chk_id;
logic                                     c_out_err_log_second_cycle, r_out_err_log_second_cycle;
logic                                     c_err_inj_ongoing,          r_err_inj_ongoing;
logic [BLOCK_RAS_DP_PROT_CHK_N-1:0]       c_err_inj_done,             r_err_inj_done;
logic                                     local_disable;
logic                                     uncorr_err_detect;
logic                                     err_inj_fail;
logic [0:$clog2(BLOCK_RAS_DP_PROT_CHK_N)] err_max_index;
logic [BLOCK_RAS_DP_PROT_CHK_N-1:0]       latch_in_ras_dp_err_log_valid;
logic [BLOCK_RAS_DP_PROT_CHK_N-1:0]       local_in_ras_dp_err_log_valid;
logic [($clog2(MAX_RAS_PROT_CHK_N)-1):0]  local_in_ras_dp_err_log_log;
logic                                     all_done_ras_dp_err_valid;
logic [$clog2(MAX_RAS_PROT_CHK_N)-1:0]    local_out_err_inj_ras_dp_prot_chk_id;
logic                                     mask_ras_dp_err_log;

// err_inj_ongoing: flags error injection operation
always_comb begin
    if (r_err_inj_ongoing) begin
        c_err_inj_ongoing = !c_out_err_log_second_cycle;
    end else begin
        c_err_inj_ongoing = out_ras_dp_err_inj.valid && (out_ras_dp_err_inj.ras_prot_chk_id == {($clog2(MAX_RAS_PROT_CHK_N)){1'b1}});
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_err_inj_ongoing <= #TP '0;
    end else begin
        r_err_inj_ongoing <= #TP c_err_inj_ongoing;
    end
end

// out_ras_dp_err_inj: propagates input error injection command to checkers
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_ras_dp_err_inj <= #TP '0;
    end else begin
        if (!r_err_inj_ongoing) begin
            out_ras_dp_err_inj <= #TP in_ras_dp_err_inj;
        end
    end
end

// err_inj_done: for each checker, records respective completion
always_comb begin
    c_err_inj_done = r_err_inj_done;
    if (r_err_inj_ongoing) begin
        for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
            if (in_ras_dp_err_log[chker].valid && (!r_in_err_log_second_cycle[chker])) begin
                c_err_inj_done[chker]   = 1'b1;
            end
        end
    end else begin
        c_err_inj_done = '0;
    end
end
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_err_inj_done <= #TP '0;
    end else begin
        r_err_inj_done <= #TP c_err_inj_done;
    end
end

// err_log_status: for each checker, records respective completion outcome
always_comb begin
    c_err_log_status = r_err_log_status;
    for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
        if (in_ras_dp_err_log[chker].valid && (!r_in_err_log_second_cycle[chker])) begin
            if (r_err_inj_ongoing) begin
                c_err_log_status[chker] = (in_ras_dp_err_log[chker].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == ERR_INJ_FAILURE);
            end else begin
                c_err_log_status[chker] = (in_ras_dp_err_log[chker].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE);
            end
        end
    end
end


always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_err_log_status <= #TP '0;
    end else begin
        r_err_log_status <= #TP c_err_log_status;
    end
end

// in_err_log_second_cycle: on each input error logging interfaces, signals the second cycle of an error log transaction
always_comb begin
    c_in_err_log_second_cycle = r_in_err_log_second_cycle;
    for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
        if (r_in_err_log_second_cycle[chker]) begin
            c_in_err_log_second_cycle[chker] = '0;
        end else begin
            c_in_err_log_second_cycle[chker] = in_ras_dp_err_log[chker].valid;
        end
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_in_err_log_second_cycle <= #TP '0;
    end else begin
        r_in_err_log_second_cycle <= #TP c_in_err_log_second_cycle;
    end
end

// out_err_ras_prot_chk_id: in case of an error injection failure, records the failing checker ID
always_comb begin
    c_out_err_ras_prot_chk_id = '0;
    for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
        if (r_in_err_log_second_cycle[chker] && r_err_log_status[chker]) begin
            c_out_err_ras_prot_chk_id = in_ras_dp_err_log[chker].log[$clog2(MAX_RAS_PROT_CHK_N)-1:0];
        end
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_out_err_ras_prot_chk_id <= #TP '0;
    end else begin
        r_out_err_ras_prot_chk_id <= #TP c_out_err_ras_prot_chk_id;
    end
end

// out_err_log_second_cycle: on the output error logging interface, signals the second cycle of an error log transaction
always_comb begin
    if (r_out_err_log_second_cycle) begin
        c_out_err_log_second_cycle = '0;
    end else begin
        c_out_err_log_second_cycle = out_ras_dp_err_log.valid;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_out_err_log_second_cycle <= #TP '0;
    end else begin
        r_out_err_log_second_cycle <= #TP c_out_err_log_second_cycle;
    end
end

localparam  BLOCK_RAS_DP_PROT_CHK_N_INT = (BLOCK_RAS_DP_PROT_CHK_N > 1) ? $clog2(BLOCK_RAS_DP_PROT_CHK_N) : BLOCK_RAS_DP_PROT_CHK_N; 

typedef struct packed {
    logic [BLOCK_RAS_DP_PROT_CHK_N_INT-1:0] index;
    logic                                       valid;
} ras_dp_err_log_look_up_match_s;

function automatic ras_dp_err_log_look_up_match_s ras_dp_err_log_select_entry (
    input ras_dp_err_log_t [BLOCK_RAS_DP_PROT_CHK_N-1:0] ras_dp_err_log
);
    begin
        ras_dp_err_log_look_up_match_s select_entry;
        logic                          err_inj_found;
        logic                          at_least_one_uncorr_found;
        select_entry              = '0;
        err_inj_found             = '0;
        at_least_one_uncorr_found = '0;
        // find valid
        for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
            select_entry.valid |= ras_dp_err_log[chker].valid;
        end
        // find if there is at least one uncorrectable (and respective index)
        for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
            if (ras_dp_err_log[chker].valid) begin
                if ((ras_dp_err_log[chker].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == ERR_INJ_FAILURE) || (ras_dp_err_log[chker].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == ERR_INJ_SUCCESSFUL)) begin
                    err_inj_found = 1'b1;
                    select_entry.index  = chker;
                end
            end
        end
        // find if there is at least one uncorrectable (and respective index)
        if (!err_inj_found) begin
            for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
                if (ras_dp_err_log[chker].valid) begin
                    if (ras_dp_err_log[chker].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) begin
                        at_least_one_uncorr_found |= 1'b1;
                        select_entry.index              = chker;
                    end
                end
            end
        end
        // find index for correctable if no uncorrectable was seen on any ras dp err log interface
        if ((!err_inj_found) && (!at_least_one_uncorr_found)) begin
            for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
                if (ras_dp_err_log[chker].valid) begin
                    if (ras_dp_err_log[chker].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] ==   CORRECTABLE) begin
                        select_entry.index = chker;
                    end
                end
            end
        end
        return select_entry;
    end
endfunction
ras_dp_err_log_look_up_match_s ras_dp_err_log_look_up_uncorr_match;
assign ras_dp_err_log_look_up_uncorr_match = ras_dp_err_log_select_entry(in_ras_dp_err_log);

// ras dp err log packet word counter
logic [$clog2(MAX_RAS_ERR_LOG_WORD_NUM)-1:0] out_err_word_number, c_out_err_word_number;

always_comb begin
    if (out_err_word_number == 2'b00) begin
        if (mask_ras_dp_err_log) begin
            c_out_err_word_number = 2'b01;
        end else begin
            c_out_err_word_number = 2'b00;
        end
    end else if (out_err_word_number == 2'b01) begin
        if ((CAN_RECEIVE_LONG_ERR_LOG_FORMAT == 1) && out_ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX +: RAS_ERROR_FORMAT_WD] && !r_err_inj_ongoing) begin
            c_out_err_word_number = 2'b10;
        end else begin
            c_out_err_word_number = 2'b00;
        end
    end else if (out_err_word_number == 2'b10) begin
        c_out_err_word_number = 2'b11;
    end else begin
        c_out_err_word_number = 2'b00;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_err_word_number <= #TP 2'b00;
    end else begin
        if (ras_dp_err_log_look_up_uncorr_match.valid && (!r_err_inj_ongoing)) begin
            out_err_word_number <= #TP c_out_err_word_number;
        end
    end
end

// count packet cycle for each in ras dp err log
logic [BLOCK_RAS_DP_PROT_CHK_N-1:0][$clog2(MAX_RAS_ERR_LOG_WORD_NUM)-1:0] c_in_ras_dp_err_log_err_word_number, in_ras_dp_err_log_err_word_number;

generate
if (CAN_RECEIVE_LONG_ERR_LOG_FORMAT == 1) begin : g_long_err_log_format_in
    // Logic to filter in ras dp err log packets that start after an in ras dp err log already started
    // save packet format (2 or 4 cycles) for each in ras dp err log
    logic [BLOCK_RAS_DP_PROT_CHK_N-1:0] in_ras_dp_err_log_format;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            in_ras_dp_err_log_format <= #TP '0;
        end else begin
            for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
                in_ras_dp_err_log_format[chker] <= #TP in_ras_dp_err_log[chker].valid && in_ras_dp_err_log[chker].log[RAS_ERROR_FORMAT_INDEX +: RAS_ERROR_FORMAT_WD];
            end
        end
    end

    always_comb begin                                                             
        for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin       
            if (in_ras_dp_err_log_err_word_number[chker] == 2'b00) begin          
                c_in_ras_dp_err_log_err_word_number[chker] = 2'b01;               
            end else if (out_err_word_number == 2'b01) begin                      
                if (in_ras_dp_err_log_format[chker] && !r_err_inj_ongoing) begin  
                    c_in_ras_dp_err_log_err_word_number[chker] = 2'b10;           
                end else begin                                                    
                    c_in_ras_dp_err_log_err_word_number[chker] = 2'b00;           
                end                                                               
            end else if (in_ras_dp_err_log_err_word_number[chker] == 2'b10) begin 
                c_in_ras_dp_err_log_err_word_number[chker] = 2'b11;               
            end else begin                                                        
                c_in_ras_dp_err_log_err_word_number[chker] = 2'b00;               
            end                                                                   
        end                                                                       
    end                                                                           
end else begin : g_no_long_err_log_format_in
    always_comb begin                                                             
        for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin       
            c_in_ras_dp_err_log_err_word_number[chker] = 2'b00;               
            if (in_ras_dp_err_log_err_word_number[chker] == 2'b00) begin          
                c_in_ras_dp_err_log_err_word_number[chker] = 2'b01;               
            end else if (out_err_word_number == 2'b01) begin                      
                c_in_ras_dp_err_log_err_word_number[chker] = 2'b00;           
            end                                                                   
        end                                                                       
    end                                                                           
end
endgenerate

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        in_ras_dp_err_log_err_word_number <= #TP 2'b00;
    end else begin
        for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
            if (in_ras_dp_err_log[chker].valid && (!r_err_inj_ongoing)) begin
                in_ras_dp_err_log_err_word_number[chker] <= #TP c_in_ras_dp_err_log_err_word_number[chker];
            end
        end
    end
end

// filter packets
assign mask_ras_dp_err_log = !(|in_ras_dp_err_log_err_word_number);

logic [BLOCK_RAS_DP_PROT_CHK_N_INT-1:0] save_slice_index;
// out_ras_dp_err_log: propagates input error log commands from checkers to the central aggregator
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_ras_dp_err_log <= #TP '0;
        save_slice_index   <= #TP '0;
    end else begin
        if (r_err_inj_ongoing) begin
            // broadcast error injection is ongoing (on a single checker or on all checkers): drive output error log with error injection input error log coming from checkers
            if (c_out_err_log_second_cycle) begin
                // second cycle: chker ID
                out_ras_dp_err_log.valid                               <= #TP 1'b1;
                out_ras_dp_err_log.log[$clog2(MAX_RAS_PROT_CHK_N)-1:0] <= #TP r_out_err_ras_prot_chk_id;
            end else begin
                // first cycle: ERROR TYPE (SLICE and SYNDROME are don't care)
                if (r_err_inj_done == {(BLOCK_RAS_DP_PROT_CHK_N){1'b1}}) begin
                    out_ras_dp_err_log.valid <= #TP 1'b1;
                    if (|r_err_log_status) begin 
                        out_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] <= #TP ERR_INJ_FAILURE;
                    end else begin
                        out_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] <= #TP ERR_INJ_SUCCESSFUL;
                    end
                end
            end
        end else begin
            if (out_err_word_number == 'd0) begin
                // broadcast error injection is not ongoing: drive output error log with error injection input error log coming from checkers
                out_ras_dp_err_log.valid <= #TP ras_dp_err_log_look_up_uncorr_match.valid && mask_ras_dp_err_log;
                out_ras_dp_err_log.log   <= #TP in_ras_dp_err_log[ras_dp_err_log_look_up_uncorr_match.index].log;
                save_slice_index         <= #TP ras_dp_err_log_look_up_uncorr_match.index;
            end else begin
                out_ras_dp_err_log.log   <= #TP in_ras_dp_err_log[save_slice_index].log;
            end
        end
    end
end

logic [BLOCK_RAS_DP_PROT_CHK_N-1:0] out_ras_dp_wake_up_ras_dp_err_log_valid;
always_comb begin
    for (int chker = 0; chker < BLOCK_RAS_DP_PROT_CHK_N; chker++) begin
        out_ras_dp_wake_up_ras_dp_err_log_valid[chker] = in_ras_dp_err_log[chker].valid;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_ras_dp_wake_up <= #TP 1'b0;
    end else begin
        out_ras_dp_wake_up <= #TP (|out_ras_dp_wake_up_ras_dp_err_log_valid) | in_ras_dp_err_inj.valid;
    end
end

endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/ras_dp_err_mgr.sv#3 $
