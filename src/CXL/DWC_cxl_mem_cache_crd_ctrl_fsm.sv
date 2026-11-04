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
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_crd_ctrl_fsm.sv#5 $
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL link layer credit control FSM.
// Credit Initialization process and credit return requests.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_crd_ctrl_fsm
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) (
// Inputs ------------------------------------------------------------------------------
    input                           core_clk,
    input                           core_rst_n,
    input                           cxl_init_crd_req,
    input                           cxl_init_cache_crd,       // Initialize credit for CXL.cache
    input                           cxl_init_mem_crd,         // Initialize credit for CXL.mem
    input [(ACK_CNT_WD - 1) : 0]    cxl_ll_full_ack,          // Acknowledge Counter Value
    input                           cxl_llcrd_sent,           // LLCTRL Flit Generator - LLCRD is sent
    input                           cxl_llcrd_force_req,      // Link Layer requests to force LLCRD
// Outputs -----------------------------------------------------------------------------
    output logic                    cxl_llcrd_force_rst,      // Reset LLCRD forcing request once it is accepted
    output logic                    cxl_llcrd_req,            // LLCTRL Flit Generator - LLCRD request
    output logic [63:0]             cxl_llcrd_payload,        // LLCTRL Flit Generator - LLCRD payload
    output logic                    cxl_crd_ctrl_init_ack     // Credit Initialization complete
    ,
    output logic                    cxl_crd_ctrl_init_mem     // Request CXL.mem Credit Initialization
    ,
    output logic                    cxl_crd_ctrl_init_cache   // Request CXL.cache Credit Initialization
);

// Declarations
crd_state_e   crd_state_r, crd_state_nxt; // Credit Control FSM
logic         llcrd_req_state_s;          // Credit Control FSM in REQ_LLCRD state

// Outputs Assignment
assign cxl_crd_ctrl_init_cache = (crd_state_r == CXL_INIT_CRD) && cxl_init_cache_crd;
// CXL.mem credits are initialized after CXL.cache credits initialization is complete
assign cxl_crd_ctrl_init_mem   = (crd_state_r == CXL_INIT_CRD) && cxl_init_mem_crd && !cxl_init_cache_crd;
// Acknowledge that credit initialization is complete when both CXL.cache and CXL.mem initialization requests are de-asserted
assign cxl_crd_ctrl_init_ack   = (crd_state_r == CXL_INIT_CRD) && !cxl_crd_ctrl_init_cache && !cxl_crd_ctrl_init_mem ;

// Clear LLCRD force request in the Credit Controller when LLCRD is forced
assign llcrd_req_state_s = crd_state_r == CXL_REQ_LLCRD;

// -------------------------------------------------------------------------------------
// Link Credit Control FSM
// -------------------------------------------------------------------------------------
always_comb begin : crd_state_nxt_PROC
    unique case(crd_state_r)
        // Credit Initialization
        CXL_INIT_CRD : begin
            if (cxl_crd_ctrl_init_ack)
                crd_state_nxt = CXL_CRD_IDLE;
            else
                crd_state_nxt = CXL_INIT_CRD;
        end
        // LLCRD flit transmission
        CXL_REQ_LLCRD : begin
            if (cxl_llcrd_sent)
                crd_state_nxt = CXL_CRD_IDLE;
            else
                crd_state_nxt = CXL_REQ_LLCRD;
        end
        default : begin // IDLE
            if (cxl_init_crd_req)
                crd_state_nxt = CXL_INIT_CRD;
            else if (cxl_llcrd_force_req)
                crd_state_nxt = CXL_REQ_LLCRD;
            else
                crd_state_nxt = CXL_CRD_IDLE;
        end
    endcase
end : crd_state_nxt_PROC

// -------------------------------------------------------------------------------------
// LLCRD Flit Generation
// -------------------------------------------------------------------------------------
always_comb begin : llcrd_flit_proc
    unique case(crd_state_r)
        CXL_INIT_CRD: begin
            cxl_llcrd_req     = !cxl_crd_ctrl_init_ack;
            cxl_llcrd_payload = 64'd0;
        end
        CXL_REQ_LLCRD : begin
            cxl_llcrd_req     = 1'b1;
            // Fill LLCRD Payload with Acknowledge information only when forcing LLCRD
            cxl_llcrd_payload = {56'd0, cxl_ll_full_ack[7:4], 1'b0, cxl_ll_full_ack[2:0]};
        end
        default : begin
            cxl_llcrd_req     = 1'b0;
            cxl_llcrd_payload = 64'd0;
        end
    endcase
end : llcrd_flit_proc

always_ff @(posedge core_clk or negedge core_rst_n) begin : crd_state_PROC
    if (!core_rst_n) begin
        crd_state_r               <= # TP CXL_CRD_IDLE;
        cxl_llcrd_force_rst       <= # TP 1'b0;
    end else begin
        crd_state_r               <= # TP crd_state_nxt;
        cxl_llcrd_force_rst       <= # TP llcrd_req_state_s;
    end
end : crd_state_PROC

endmodule
