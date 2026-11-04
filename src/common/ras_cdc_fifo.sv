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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/ras_cdc_fifo.sv#1 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
module ras_cdc_fifo
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_INDEX;
#(
   parameter WD            = 1, // Width of datapath
   parameter FIFO_DEPTH    = 2  // can be 2 or any higher power of two
)

                   (
    input  logic            clk,
    input  logic            rst_n,

    input  ras_dp_err_log_t in_ras_dp_err_log,

    output ras_dp_err_log_t out_ras_dp_err_log,
    input  logic            halt_in
);

logic                          hs_in;
logic                          hs_out;
logic [$clog2(FIFO_DEPTH)  :0] next_pending_count, pending_count, required_length;
logic [$clog2(FIFO_DEPTH)-1:0] read_ptr;
logic [$clog2(FIFO_DEPTH)-1:0] write_ptr;
logic [FIFO_DEPTH-1:0][WD-1:0] data;

logic                          err_format;
logic [$clog2(FIFO_DEPTH)-1:0] word_number, c_word_number;
logic                          c_filter, r_filter;

always_comb begin
    if (word_number == 2'b00) begin
        c_word_number = 2'b01;
    end else if (word_number == 2'b01) begin
        if (err_format == 1'b1) begin
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

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        word_number <= #TP 2'b00;
    end else begin
        if (in_ras_dp_err_log.valid) begin
            word_number <= #TP c_word_number;
        end
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        err_format <= #TP 2'b00;
    end else begin
        if (in_ras_dp_err_log.valid) begin
            if (word_number == 2'b00) begin
                err_format <= #TP in_ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX];
            end
        end
    end
end

assign required_length = in_ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX]? 4 : 2;

always_comb begin
    c_filter = r_filter;
    if (word_number == 2'b00) begin
        c_filter = (FIFO_DEPTH-pending_count < required_length);
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_filter <= #TP 1'b0;
    end else begin
        if (in_ras_dp_err_log.valid) begin
            r_filter <= #TP c_filter;
        end
    end
end

assign hs_in  = in_ras_dp_err_log.valid && (!c_filter);
assign hs_out = out_ras_dp_err_log.valid && (!halt_in);

always_comb begin
    case ({hs_in, hs_out})
        2'b01   : next_pending_count = pending_count - 1;
        2'b10   : next_pending_count = pending_count + 1;
        default : next_pending_count = pending_count;
    endcase
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pending_count <= #TP '0;
    end else begin
        pending_count <= #TP next_pending_count;
    end
end
        
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_ras_dp_err_log.valid <= #TP 1'b0;
    end else begin
        out_ras_dp_err_log.valid <= #TP |next_pending_count;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        read_ptr <= #TP '0;
    end else begin
        if (hs_out) begin
            read_ptr <= #TP read_ptr + 1;
        end
    end
end
assign out_ras_dp_err_log.log = data[read_ptr];

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        write_ptr <= #TP '0;
    end else begin
        if (hs_in) begin
            write_ptr <= #TP write_ptr + 1;
        end
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        data <= #TP '0;
    end else begin
        if (hs_in) begin
            data[write_ptr] <= #TP in_ras_dp_err_log.log;
        end
    end
end

endmodule
