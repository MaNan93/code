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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/ras_err_inj_mgr.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Cdm/cdm_ras_pkg.svh"

module ras_err_inj_mgr
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import cdm_ras_pkg::ras_err_inj_mgr_ctrl_s;
import cdm_ras_pkg::ras_err_inj_ack_s;
(
    input  logic                  core_clk,
    input  logic                  core_rst_n,
    
    // RAS DP ERROR MANAGER Interface
    output ras_dp_err_inj_t       out_ras_dp_err_inj,
    output logic                  ras_dp_err_inj_wake_up,
    
    // RAS Error Tracer Interface
    input  ras_err_inj_ack_s      ras_err_inj_ack,
    
    // CDM Interface
    input  ras_err_inj_mgr_ctrl_s ras_err_inj_mgr_ctrl,
    output logic                  trigger_fatal_error
);

logic err_inj_session_ongoing;
logic err_inj_super_session_ongoing;


always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        err_inj_session_ongoing <= #TP '0;
    end else begin
        if (err_inj_session_ongoing) begin
            // a session is ongoing
            if ( ras_err_inj_ack.valid) begin
                err_inj_session_ongoing <= #TP '0;
            end
        end else begin
            // a session is not ongoing
            if (ras_err_inj_mgr_ctrl.start_err_inj) begin
                // start command received in this cycle
                err_inj_session_ongoing <= #TP 1'b1;
            end else begin
                // start command not received in this cycle
                    // Repetition is not configured
                    err_inj_session_ongoing <= #TP ras_err_inj_mgr_ctrl.start_err_inj;
            end
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        err_inj_super_session_ongoing <= #TP '0;
    end else begin
        if (err_inj_super_session_ongoing) begin
            // a super-session is ongoing
                // stop command not received in this cycle
                if (ras_err_inj_ack.valid && ras_err_inj_ack.fail) begin
                    // any session gives a fail ack in this cycle
                    err_inj_super_session_ongoing <= #TP '0;
                end
        end else begin
            // a super-session is not ongoing
            err_inj_super_session_ongoing <= #TP ras_err_inj_mgr_ctrl.start_err_inj;
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        out_ras_dp_err_inj <= #TP '0;
    end else begin
        if (out_ras_dp_err_inj.valid) begin
            out_ras_dp_err_inj <= #TP '0;
        end else begin
            if (out_ras_dp_err_inj.valid) begin
                out_ras_dp_err_inj.valid <= #TP 1'b0;
            end else begin
                out_ras_dp_err_inj.valid <= #TP ras_err_inj_mgr_ctrl.start_err_inj;
            end
            out_ras_dp_err_inj.ras_prot_chk_id <= #TP ras_err_inj_mgr_ctrl.ras_prot_chk_id;
        end
    end
end

assign ras_dp_err_inj_wake_up = err_inj_session_ongoing;

logic single_chk_err_inj;
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        single_chk_err_inj <= #TP '0;
    end else begin
        if (ras_err_inj_ack.valid) begin
            single_chk_err_inj <= #TP '0;
        end else begin
            if (out_ras_dp_err_inj.valid && (!(&out_ras_dp_err_inj.ras_prot_chk_id))) begin
                single_chk_err_inj <= #TP 1'b1;
            end
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        trigger_fatal_error <= #TP '0;
    end else begin
        if (trigger_fatal_error) begin
            trigger_fatal_error <= #TP '0;
        end else begin
            trigger_fatal_error <= #TP ras_err_inj_ack.valid && single_chk_err_inj;
        end
    end
end

endmodule

