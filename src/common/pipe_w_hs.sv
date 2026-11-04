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
// ---    $DateTime: 2022/05/05 01:39:57 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_w_hs.sv#2 $
// -------------------------------------------------------------------------
// ---
// --- This is a pipeline with hand-shakes on both side.
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
module pipe_w_hs
import DWC_pcie_ctl_pkg::TP;
 #(
    parameter WD            = 1, // Width of datapath
    parameter FORWARD_PIPE  = 1, // timing arc is broken on the forward way (i.e. valid)
    parameter BACKWARD_PIPE = 1, // timing arc is broken on the backward way (i.e. halt)
    parameter FIFO_DEPTH    = 2  // can be 2 or any higher power of two
 )
 
                (
    input  logic          clk,
    input  logic          rst_n,

    input  logic          valid_in,
    input  logic [WD-1:0] d_in,
    output logic          halt_out,

    output logic          valid_out,
    output logic [WD-1:0] d_out,
    input  logic          halt_in
);

generate
    if (FORWARD_PIPE == 1 && BACKWARD_PIPE == 1) begin : forward_and_backward_gen
        logic                          hs_in;
        logic                          hs_out;
        logic [$clog2(FIFO_DEPTH)  :0] next_pending_count, pending_count;
        logic [$clog2(FIFO_DEPTH)-1:0] read_ptr;
        logic [$clog2(FIFO_DEPTH)-1:0] write_ptr;
        logic [FIFO_DEPTH-1:0][WD-1:0] data;

        assign hs_in  = valid_in  && (!halt_out);
        assign hs_out = valid_out && (!halt_in);

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
                valid_out <= #TP 1'b0;
            end else begin
                valid_out <= #TP |next_pending_count;
            end
        end

        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                halt_out <= #TP 1'b0;
            end else begin
                halt_out <= #TP next_pending_count[$clog2(FIFO_DEPTH)];
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
        assign d_out = data[read_ptr];

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
                    data[write_ptr] <= #TP d_in;
                end
            end
        end
    end else if (FORWARD_PIPE == 0 && BACKWARD_PIPE == 0 ) begin : no_pipe_gen
        assign valid_out = valid_in;
        assign halt_out  = halt_in;
        assign d_out     = d_in;
    end
endgenerate


//assert fifo power of two
endmodule

