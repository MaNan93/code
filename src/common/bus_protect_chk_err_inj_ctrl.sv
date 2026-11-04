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


// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module takes care of flipping the bits going to a checker for error
// injection. An outer loop takes care of single bit injection, while an inner
// loop takes care of double bit injection.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module bus_protect_chk_err_inj_ctrl
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
#(
    parameter PROT_TYPE                 = 0,
    parameter RAS_PROT_CHK_ID           = 0,
    parameter ERR_INJ_INDEX_WIDTH       = 72,
    parameter ERR_INJ_INDEX_WIDTH_EXTRA = 72
)   
(
    input  logic                           clk,
    input  logic                           rst_n,
    input  ras_dp_err_inj_t                ras_dp_err_inj,
    output logic                           err_inj_ongoing,
    output logic                           err_inj_last,
    input  logic                           err_inj_failure,
    output logic                           err_inj_double,
    output logic [ERR_INJ_INDEX_WIDTH-1:0] err_inj_bit_index_0_oh,
    output logic [ERR_INJ_INDEX_WIDTH-1:0] err_inj_bit_index_1_oh,
    output logic                           err_inj_extra_inst_in_range
);

// on cycles where error injection mechanism is happening, err_inj_ongoing is set
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        err_inj_ongoing <= #TP '0;
    end else begin
        if (err_inj_ongoing) begin
            err_inj_ongoing <= #TP !(err_inj_last || err_inj_failure);
        end else begin
            err_inj_ongoing <= #TP ras_dp_err_inj.valid && ((ras_dp_err_inj.ras_prot_chk_id == RAS_PROT_CHK_ID) || (ras_dp_err_inj.ras_prot_chk_id == {($clog2(MAX_RAS_PROT_CHK_N)){1'b1}}));
        end
    end
end

// outer loop
logic [ERR_INJ_INDEX_WIDTH-1:0] c_err_inj_bit_index_0_oh;
always_comb begin
    if (!err_inj_ongoing) begin
        c_err_inj_bit_index_0_oh = (ERR_INJ_INDEX_WIDTH)'(1);
    end else begin
        if (err_inj_bit_index_0_oh == (1 << (ERR_INJ_INDEX_WIDTH-1))) begin
            c_err_inj_bit_index_0_oh = (ERR_INJ_INDEX_WIDTH)'(1);
        end else begin
            c_err_inj_bit_index_0_oh = (err_inj_bit_index_0_oh << 1);
        end
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        err_inj_bit_index_0_oh <= #TP (ERR_INJ_INDEX_WIDTH)'(1);
    end else begin
        if (err_inj_ongoing) begin
            err_inj_bit_index_0_oh <= #TP c_err_inj_bit_index_0_oh;
        end
    end
end



generate
    if (PROT_TYPE == 0) begin : g_double_error
        // inner bit loop
        logic [ERR_INJ_INDEX_WIDTH-1:0] c_err_inj_bit_index_1_oh;
        always_comb begin
            if (!err_inj_ongoing) begin
                c_err_inj_bit_index_1_oh = (ERR_INJ_INDEX_WIDTH)'(1);
            end else begin
                if (err_inj_bit_index_0_oh == (1 << (ERR_INJ_INDEX_WIDTH-1))) begin
                    if (err_inj_bit_index_1_oh == (1 << (ERR_INJ_INDEX_WIDTH-1))) begin
                        c_err_inj_bit_index_1_oh = (ERR_INJ_INDEX_WIDTH)'(1);
                    end else begin
                        c_err_inj_bit_index_1_oh = (err_inj_bit_index_1_oh << 1);
                    end
                end else begin
                    c_err_inj_bit_index_1_oh = err_inj_bit_index_1_oh;
                end
            end
        end
        
        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                err_inj_bit_index_1_oh <= #TP (ERR_INJ_INDEX_WIDTH)'(1);
            end else begin
                if (err_inj_ongoing) begin
                    err_inj_bit_index_1_oh <= #TP c_err_inj_bit_index_1_oh;
                end
            end
        end

        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                err_inj_extra_inst_in_range <= #TP '0;
            end else begin
                if (err_inj_ongoing) begin
                    err_inj_extra_inst_in_range <= #TP !((|c_err_inj_bit_index_0_oh[ERR_INJ_INDEX_WIDTH-1:ERR_INJ_INDEX_WIDTH_EXTRA]) | (|c_err_inj_bit_index_1_oh[ERR_INJ_INDEX_WIDTH-1:ERR_INJ_INDEX_WIDTH_EXTRA]));
                end
            end
        end

        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                err_inj_double <= #TP '0;
            end else begin
                if (err_inj_ongoing) begin
                    err_inj_double <= #TP (c_err_inj_bit_index_0_oh != c_err_inj_bit_index_1_oh);
                end
            end
        end

        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                err_inj_last <= #TP '0;
            end else begin
                if (err_inj_ongoing) begin
                    err_inj_last <= #TP (c_err_inj_bit_index_0_oh == (1 << (ERR_INJ_INDEX_WIDTH-1))) && (c_err_inj_bit_index_1_oh == (1 << (ERR_INJ_INDEX_WIDTH-1)));
                end
            end
        end

    end else begin : g_single_error_only
        assign err_inj_double          = 0;

        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                err_inj_last <= #TP '0;
            end else begin
                if (err_inj_ongoing) begin
                    err_inj_last <= #TP (c_err_inj_bit_index_0_oh == (1 << (ERR_INJ_INDEX_WIDTH-1)));
                end
            end
        end

        assign err_inj_bit_index_1_oh  = '0;

        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                err_inj_extra_inst_in_range <= #TP '0;
            end else begin
                if (err_inj_ongoing) begin
                    err_inj_extra_inst_in_range <= #TP !(|c_err_inj_bit_index_0_oh[ERR_INJ_INDEX_WIDTH-1:ERR_INJ_INDEX_WIDTH_EXTRA]);
                end
            end
        end
    end
endgenerate

endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_chk_err_inj_ctrl.sv#3 $
