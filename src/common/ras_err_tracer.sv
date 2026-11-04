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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/ras_err_tracer.sv#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Cdm/cdm_ras_pkg.svh"

module ras_err_tracer
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::RAS_ERROR_CHK_ID_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_CHK_ID_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_WD;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_LSB_INDEX;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_LSB_WD;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_MSB_INDEX;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_MSB_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
import DWC_pcie_ctl_pkg::MAX_RAS_ERR_LOG_WORD_NUM;
import DWC_pcie_ctl_pkg::CORRECTABLE;
import DWC_pcie_ctl_pkg::UNCORRECTABLE;
import DWC_pcie_ctl_pkg::ERR_INJ_FAILURE;
import DWC_pcie_ctl_pkg::ERR_INJ_SUCCESSFUL;
import DWC_pcie_ctl_pkg::RAS_ERROR_SLICE_ID_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_PROT_RANGE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_PROT_RANGE_WD;
import cdm_ras_pkg::RAS_ERROR_TRACER_FILTER_TAG_WD;
import cdm_ras_pkg::RAS_TRACE_BUFFER_DEPTH;
import cdm_ras_pkg::ras_err_tracer_ctrl_s;
import cdm_ras_pkg::ras_err_tracer_rpt_s;
import cdm_ras_pkg::RAS_ERROR_TRACER_FILTER_NUMBER;
import cdm_ras_pkg::RAS_REG_ERROR_SLICE_ID_WD;
import cdm_ras_pkg::RAS_REG_ERROR_SYNDROME_WD;
import cdm_ras_pkg::ras_err_inj_ack_s;
(
    input  logic                 core_clk,
    input  logic                 core_rst_n,
    
    // RAS DP ERROR MANAGER Interface
    input  ras_dp_err_log_t      in_ras_dp_err_log,
    
    // RAS Error Tracer Interface
    output ras_err_inj_ack_s     ras_err_inj_ack,
    
    // PCIe Controller output interface    
    output logic                 pending_correctable,
    output logic                 pending_uncorrectable,
    output logic                 pending_err_inj_failure,
    output logic                 pending_err_inj_successful,
    output logic                 pulse_ras_dp_unc_err,
    output logic                 pulse_ras_dp_cor_err,
    output logic                 pulse_ras_ram_unc_err,
    output logic                 pulse_ras_ram_cor_err,

    // RAS DP Error Controller Interface
    output logic                 ras_error_tracer_fatal_error,

    // CDM Interface
    input  ras_err_tracer_ctrl_s ras_err_tracer_ctrl,
    output ras_err_tracer_rpt_s  ras_err_tracer_rpt
);


typedef struct packed {
    logic                                      valid;
    logic                                      ras_prot_error_format;
    logic [RAS_ERROR_CHK_ID_WD-1:0]            ras_prot_chk_id;
    logic [RAS_REG_ERROR_SLICE_ID_WD-1:0]      ras_prot_chk_slice_id;
    logic [RAS_ERROR_TYPE_WD-1:0]              ras_prot_error_type;
    logic [RAS_REG_ERROR_SYNDROME_WD-1:0]      ras_prot_syndrome;
    logic [RAS_ERROR_TRACER_FILTER_TAG_WD-1:0] ras_prot_ram_addr;
} ras_err_trace_s;

typedef struct packed {
    logic                                      valid;
    logic [RAS_ERROR_CHK_ID_WD-1:0]            ras_prot_chk_id;
    logic [RAS_REG_ERROR_SLICE_ID_WD-1:0]      ras_prot_chk_slice_id;
    logic [RAS_ERROR_TYPE_WD-1:0]              ras_prot_error_type;
    logic                                      ras_prot_error_format;
    logic [RAS_REG_ERROR_SYNDROME_WD-1:0]      ras_prot_syndrome;
    logic [RAS_ERROR_TRACER_FILTER_TAG_WD-1:0] ras_prot_ram_addr;
    logic [15:0]                               count;
    logic [31:0]                               timestamp;
} ras_err_trace_buffer_entry_s;

ras_err_trace_buffer_entry_s [RAS_TRACE_BUFFER_DEPTH-1:0] ras_trace_buffer;

typedef struct packed {
    logic [$clog2(RAS_TRACE_BUFFER_DEPTH)-1:0] index;
    logic                                      found;
} ras_trace_buffer_look_up_match_s;

function automatic ras_trace_buffer_look_up_match_s ras_trace_buffer_affinity_match (
    input ras_err_trace_buffer_entry_s [RAS_TRACE_BUFFER_DEPTH-1:0] ras_trace_buffer,
    input ras_err_trace_s                                           ras_err_trace,
    input ras_err_tracer_ctrl_s                                     ras_err_tracer_ctrl
);
    begin
        ras_trace_buffer_look_up_match_s lookup_match, valid_match;
        logic lookup_skip, valid_skip;
        lookup_match = '0;
        valid_match = '0;
        lookup_skip = '0;
        valid_skip = '0;
        // look up the buffer to check if there is an entry whose count can be incremented rather than allocating a new entry
        for (int entry = 0; entry < RAS_TRACE_BUFFER_DEPTH; entry++) begin
            if (ras_err_tracer_ctrl.ras_error_tracer_ctrl.count_affinity == 2'b01) begin
                if (!lookup_skip) begin
                    if (ras_trace_buffer[entry].valid) begin
                        if ((ras_trace_buffer[entry].ras_prot_chk_id == ras_err_trace.ras_prot_chk_id)
                        ) begin
                            lookup_match.found = 1'b1;
                            lookup_match.index = entry;
                            lookup_skip = 1'b1;
                        end
                    end
                end
            end else if (ras_err_tracer_ctrl.ras_error_tracer_ctrl.count_affinity == 2'b10) begin
                if (!lookup_skip) begin
                    if (ras_trace_buffer[entry].valid) begin                                                          
                        if ((ras_trace_buffer[entry].ras_prot_chk_id       == ras_err_trace.ras_prot_chk_id)       && 
                            (ras_trace_buffer[entry].ras_prot_chk_slice_id == ras_err_trace.ras_prot_chk_slice_id)    
                        ) begin                                                                                       
                            lookup_match.found = 1'b1;                                                                       
                            lookup_match.index = entry;                                                                      
                            lookup_skip = 1'b1;
                        end                                                                                           
                    end                                                                                               
                end
            end else if (ras_err_tracer_ctrl.ras_error_tracer_ctrl.count_affinity == 2'b11) begin
                if (!lookup_skip) begin
                    if (ras_trace_buffer[entry].valid) begin
                        if ((ras_trace_buffer[entry].ras_prot_chk_id       == ras_err_trace.ras_prot_chk_id)       &&
                            (ras_trace_buffer[entry].ras_prot_chk_slice_id == ras_err_trace.ras_prot_chk_slice_id) &&
                            (ras_trace_buffer[entry].ras_prot_error_type   == ras_err_trace.ras_prot_error_type)
                        ) begin
                            lookup_match.found = 1'b1;
                            lookup_match.index = entry;
                            lookup_skip = 1'b1;
                        end
                    end
                end
            end
        end
        
        if (lookup_match.found) begin
            // an entry was found whose count can be incremented rather than allocating a new entry
            valid_match = lookup_match;
        end else begin
            // no entry was found whose count can be incremented rather than allocating a new entry
            // look up the buffer to check if there is a non valid entry
            for (int entry = 0; entry < RAS_TRACE_BUFFER_DEPTH; entry++) begin
                if (!valid_skip) begin
                    if (!ras_trace_buffer[entry].valid) begin
                        valid_match.found = 1'b1;
                        valid_match.index = entry;
                        valid_skip = 1'b1;
                    end
                end
            end
        end
        return valid_match;
    end
endfunction


// ras dp err log packet word counter
logic [$clog2(MAX_RAS_ERR_LOG_WORD_NUM)-1:0] word_number, c_word_number;

always_comb begin
    if (word_number == 2'b00) begin
        c_word_number = 2'b01;
    end else if (word_number == 2'b01) begin
        if (ras_err_trace.ras_prot_error_format) begin
            c_word_number = 2'b10;
        end else begin
            c_word_number = 2'b00;
        end
    end else if (word_number == 2'b10) begin
        c_word_number = 2'b11;
    end else begin
        c_word_number = 2'b00;
    end
end

always_ff@(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)begin
        word_number <= #TP 2'b00;
    end else begin
        if (in_ras_dp_err_log.valid) begin
            word_number <= #TP c_word_number;
        end
    end
end

always_ff@(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)begin
        ras_err_inj_ack <= #TP '0;
    end else begin
        if (ras_err_inj_ack.valid) begin
            ras_err_inj_ack.valid <= #TP '0;
        end else begin
            if (in_ras_dp_err_log.valid) begin
                if (word_number == '0) begin
                    if (in_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX+1]) begin
                        ras_err_inj_ack.valid <= #TP 1'b1;
                        ras_err_inj_ack.fail  <= #TP !in_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX];
                    end
                end
            end
        end
    end
end

// Accumulator
ras_err_trace_s ras_err_trace;
always_ff@(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)begin
        ras_err_trace <= #TP '0;
    end else begin
        if (in_ras_dp_err_log.valid) begin
            if (word_number == '0) begin
                ras_err_trace.ras_prot_error_type                                                  <= #TP in_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX     +: RAS_ERROR_TYPE_WD];       
                ras_err_trace.ras_prot_error_format                                                <= #TP in_ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX   +: RAS_ERROR_FORMAT_WD];
                // take slice id and syndrome in a raw way: exact bit to be extracted are refined on next cycle
                ras_err_trace.ras_prot_chk_slice_id                                                <= #TP in_ras_dp_err_log.log[RAS_ERROR_SLICE_ID_INDEX +: RAS_REG_ERROR_SLICE_ID_WD];
                ras_err_trace.ras_prot_syndrome                                                    <= #TP {6'b000000, in_ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX-1:3]};
                ras_err_trace.valid                                                                <= #TP 1'b0;
            end else if (word_number == 'd1) begin
                ras_err_trace.ras_prot_chk_id                                                      <= #TP in_ras_dp_err_log.log[RAS_ERROR_CHK_ID_INDEX +: RAS_ERROR_CHK_ID_WD];
                // refine slice id and syndrome depending on error_prot_range
                // 00 => parity, no syndrome, slice id width arbitrarily set to MAX_SUPPORTED_WD/PROT_RANGE bits
                // 01 => ecc32,  7-bits
                // 10 => ecc64,  8-bits
                // 11 => ecc128, 9-bits
                if (in_ras_dp_err_log.log[RAS_ERROR_PROT_RANGE_INDEX +: RAS_ERROR_PROT_RANGE_WD] == 2'b00) begin
                    ras_err_trace.ras_prot_syndrome                                                <= #TP '0;
                end else if (in_ras_dp_err_log.log[RAS_ERROR_PROT_RANGE_INDEX +: RAS_ERROR_PROT_RANGE_WD] == 2'b01) begin
                    ras_err_trace.ras_prot_chk_slice_id[7:6]                                       <= #TP 2'b00;
                    ras_err_trace.ras_prot_syndrome                                                <= #TP {9'b000000000, ras_err_trace.ras_prot_syndrome[9:3]};
                end else if (in_ras_dp_err_log.log[RAS_ERROR_PROT_RANGE_INDEX +: RAS_ERROR_PROT_RANGE_WD] == 2'b10) begin
                    ras_err_trace.ras_prot_chk_slice_id[7:5]                                       <= #TP 3'b000;
                    ras_err_trace.ras_prot_syndrome                                                <= #TP {8'b00000000,  ras_err_trace.ras_prot_syndrome[9:2]};
                end else if (in_ras_dp_err_log.log[RAS_ERROR_PROT_RANGE_INDEX +: RAS_ERROR_PROT_RANGE_WD] == 2'b11) begin
                    ras_err_trace.ras_prot_chk_slice_id[7:4]                                       <= #TP 4'b0000;
                    ras_err_trace.ras_prot_syndrome                                                <= #TP {7'b0000000,   ras_err_trace.ras_prot_syndrome[9:1]};
                end    
                ras_err_trace.valid                                                                <= #TP !ras_err_trace.ras_prot_error_format;                                             
            end else if (word_number == 'd2) begin
                ras_err_trace.ras_prot_ram_addr[RAS_ERROR_LOG_WD-1:0]                              <= #TP in_ras_dp_err_log.log[RAS_RAM_ADDR_LSB_INDEX +: RAS_RAM_ADDR_LSB_WD];
                ras_err_trace.valid                                                                <= #TP 1'b0;
            end else begin
                ras_err_trace.ras_prot_ram_addr[RAS_ERROR_TRACER_FILTER_TAG_WD-1:RAS_ERROR_LOG_WD] <= #TP in_ras_dp_err_log.log[RAS_RAM_ADDR_MSB_INDEX +: (RAS_ERROR_TRACER_FILTER_TAG_WD-RAS_RAM_ADDR_MSB_WD)];
                ras_err_trace.valid                                                                <= #TP 1'b1;
            end
        end else begin
            ras_err_trace.valid <= #TP 1'b0;
        end
    end
end

// Filter based on rules provided by CDM RAS Registers
ras_err_trace_s ras_err_filtered_trace;
always_ff@(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)begin
        ras_err_filtered_trace <= #TP '0;
    end else begin
        ras_err_filtered_trace <= #TP ras_err_trace;
        for (int filter=0; filter<RAS_ERROR_TRACER_FILTER_NUMBER; filter++) begin
            if (ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule_en[filter][0]) begin
                // Filter base on RAS DP Checker Identifier
                if (ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_tag[filter][0] == {{(RAS_ERROR_TRACER_FILTER_TAG_WD-$clog2(MAX_RAS_PROT_CHK_N)){1'b0}},ras_err_trace.ras_prot_chk_id}) begin
                    if (ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule_en[filter][1] && ras_err_trace.ras_prot_error_format) begin
                        // Filter base on RAM Address
                        if (ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_tag[filter][1] == ras_err_trace.ras_prot_ram_addr) begin
                            ras_err_filtered_trace.valid <= #TP 1'b0;
                        end
                    else
                        ras_err_filtered_trace.valid <= #TP 1'b0;
                    end
                end
            end
        end
    end
end

// Timestamp generator
logic [31:0] timestamp, shifted_timestamp;
always_ff@(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        timestamp <= #TP '0;
    end else begin
        if (ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_clr) begin
            timestamp <= #TP '0;
        end else begin
            timestamp <= #TP timestamp + 1;
        end
    end
end

assign shifted_timestamp = (timestamp >> ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_incr);

// Update RAS DP Trace Buffer
ras_trace_buffer_look_up_match_s ras_trace_buffer_look_up_match;
assign ras_trace_buffer_look_up_match = ras_trace_buffer_affinity_match(ras_trace_buffer, ras_err_filtered_trace, ras_err_tracer_ctrl);
always_ff@(posedge core_clk or negedge core_rst_n) begin                                                                      
    if (!core_rst_n) begin
        ras_trace_buffer <= #TP '0;
    end else begin
        for (int entry = 0; entry < RAS_TRACE_BUFFER_DEPTH; entry++) begin
            if (ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_clr) begin
                if (ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id == entry) begin
                    ras_trace_buffer[entry] <= #TP '0;
                end
            end else begin
                if (ras_err_tracer_ctrl.ras_error_tracer_ctrl.enable) begin
                    if (ras_err_filtered_trace.valid) begin
                        if (ras_trace_buffer_look_up_match.found) begin
                            if (ras_trace_buffer_look_up_match.index == entry) begin
                                ras_trace_buffer[entry].valid                  <= #TP 1'b1;
                                ras_trace_buffer[entry].ras_prot_chk_id        <= #TP ras_err_filtered_trace.ras_prot_chk_id;    
                                ras_trace_buffer[entry].ras_prot_chk_slice_id  <= #TP ras_err_filtered_trace.ras_prot_chk_slice_id;
                                ras_trace_buffer[entry].ras_prot_error_type    <= #TP ras_err_filtered_trace.ras_prot_error_type;
                                ras_trace_buffer[entry].ras_prot_error_format  <= #TP ras_err_filtered_trace.ras_prot_error_format;
                                ras_trace_buffer[entry].ras_prot_syndrome      <= #TP ras_err_filtered_trace.ras_prot_syndrome;      
                                ras_trace_buffer[entry].ras_prot_ram_addr      <= #TP ras_err_filtered_trace.ras_prot_ram_addr;        
                                ras_trace_buffer[entry].count                  <= #TP ras_trace_buffer[entry].count + 1;
                                ras_trace_buffer[entry].timestamp              <= #TP shifted_timestamp;           
                            end
                        end
                    end
                end
            end
        end
    end
end

always_comb begin
    pulse_ras_dp_unc_err  = '0;
    pulse_ras_dp_cor_err  = '0;
    pulse_ras_ram_unc_err = '0;
    pulse_ras_ram_cor_err = '0;
    if (ras_err_filtered_trace.valid) begin
        if (ras_err_filtered_trace.ras_prot_error_format) begin
            if (ras_err_filtered_trace.ras_prot_error_type == UNCORRECTABLE) begin
                pulse_ras_ram_unc_err = 1'b1;
            end else if (ras_err_filtered_trace.ras_prot_error_type == CORRECTABLE) begin
                pulse_ras_ram_cor_err = 1'b1;
            end
        end else begin
            if (ras_err_filtered_trace.ras_prot_error_type == UNCORRECTABLE) begin
                pulse_ras_dp_unc_err = 1'b1;
            end else if (ras_err_filtered_trace.ras_prot_error_type == CORRECTABLE) begin
                pulse_ras_dp_cor_err = 1'b1;
            end
       end
    end
end

always_comb begin
    ras_err_tracer_rpt = '0;
    // RAS DP ERROR TRACER CAPABILITY
    ras_err_tracer_rpt.ras_error_tracer_capability.filter_number           = RAS_ERROR_TRACER_FILTER_NUMBER;
    ras_err_tracer_rpt.ras_error_tracer_capability.size                    = RAS_TRACE_BUFFER_DEPTH;
    // RAS DP ERROR TRACER CTRL
    ras_err_tracer_rpt.ras_error_tracer_pending_correctable                = pending_correctable;
    ras_err_tracer_rpt.ras_error_tracer_pending_uncorrectable              = pending_uncorrectable;
    ras_err_tracer_rpt.ras_error_tracer_pending_err_inj_failure            = pending_err_inj_failure;
    ras_err_tracer_rpt.ras_error_tracer_pending_err_inj_successful         = pending_err_inj_successful;
    // RAS DP ERROR TRACER LOG REPORT 0
    ras_err_tracer_rpt.ras_error_tracer_log_report_0.count                 = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].count;
    ras_err_tracer_rpt.ras_error_tracer_log_report_0.syndrome              = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].ras_prot_syndrome;
    // RAS DP ERROR TRACER LOG REPORT 1
    ras_err_tracer_rpt.ras_error_tracer_log_report_1.error_type            = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].ras_prot_error_type;
    ras_err_tracer_rpt.ras_error_tracer_log_report_1.ras_prot_chk_slice_id = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].ras_prot_chk_slice_id;
    ras_err_tracer_rpt.ras_error_tracer_log_report_1.ras_prot_chk_id       = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].ras_prot_chk_id;
    // RAS DP ERROR TRACER LOG REPORT 2
    ras_err_tracer_rpt.ras_error_tracer_log_report_2.addr_log              = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].ras_prot_ram_addr;
    // RAS DP ERROR TRACER LOG REPORT 3
    ras_err_tracer_rpt.ras_error_tracer_log_report_3.timestamp             = ras_trace_buffer[ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id].timestamp;
end

logic c_pending_correctable;
logic c_pending_uncorrectable;
logic c_pending_err_inj_failure;
logic c_pending_err_inj_successful;
always_comb begin
    c_pending_correctable        = 1'b0;
    c_pending_uncorrectable      = 1'b0;
    c_pending_err_inj_failure    = 1'b0;
    c_pending_err_inj_successful = 1'b0;
    for (int entry = 0; entry < RAS_TRACE_BUFFER_DEPTH; entry++) begin
        c_pending_correctable        |= ras_trace_buffer[entry].valid && (ras_trace_buffer[entry].ras_prot_error_type == CORRECTABLE);
        c_pending_uncorrectable      |= ras_trace_buffer[entry].valid && (ras_trace_buffer[entry].ras_prot_error_type == UNCORRECTABLE);
        c_pending_err_inj_failure    |= ras_trace_buffer[entry].valid && (ras_trace_buffer[entry].ras_prot_error_type == ERR_INJ_FAILURE);
        c_pending_err_inj_successful |= ras_trace_buffer[entry].valid && (ras_trace_buffer[entry].ras_prot_error_type == ERR_INJ_SUCCESSFUL);
    end
    
end

always_ff@(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)begin
        pending_correctable        <= #TP '0;
        pending_uncorrectable      <= #TP '0;
        pending_err_inj_failure    <= #TP '0;
        pending_err_inj_successful <= #TP '0;
    end else begin
        if (ras_err_tracer_ctrl.ras_error_tracer_ctrl.ras_error_tracer_pending_enable) begin
            pending_correctable        <= #TP c_pending_correctable;
            pending_uncorrectable      <= #TP c_pending_uncorrectable;
            pending_err_inj_failure    <= #TP c_pending_err_inj_failure;
            pending_err_inj_successful <= #TP c_pending_err_inj_successful;
        end else begin
            pending_correctable        <= #TP '0;
            pending_uncorrectable      <= #TP '0;
            pending_err_inj_failure    <= #TP '0;
            pending_err_inj_successful <= #TP '0;
        end
    end
end

assign ras_error_tracer_fatal_error = pending_uncorrectable | pending_err_inj_failure;

`ifndef SYNTHESIS
`ifdef SNPS_TB_INTERFACE
// Create interface instance for the testbench and insert into the config_db
DwDutRasDpTracerIf u_DwDutRasDpTracerIf(.clk(core_clk), .rst_n(core_rst_n));
initial uvm_pkg::uvm_config_db #(virtual DwDutRasDpTracerIf)::set(uvm_pkg::uvm_root::get(),{"*"},"DwDutRasDpTracerIf",u_DwDutRasDpTracerIf);
reg ras_dp_test_en;
initial
    begin
        ras_dp_test_en=0; //default value
        fork
            begin
                forever @(posedge core_clk) begin
                    if (u_DwDutRasDpTracerIf.fault_inj_en == 1'b1) begin
                        ras_dp_test_en = 1;
                    end
                end
            end
        join
    end

`endif // SNPS_TB_INTERFACE
`endif // SYNTHESIS

endmodule

