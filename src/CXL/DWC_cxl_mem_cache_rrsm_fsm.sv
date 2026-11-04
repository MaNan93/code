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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #8 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rrsm_fsm.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Remote Retry State Machine
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_rrsm_fsm
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)(
// Inputs ------------------------------------------------------------------------------
    input                           core_clk,                 // Core clock
    input                           core_rst_n,               // Core reset
    input                           cxl_rx_retry_req,         // Received Retry.Req
    input                           cxl_rrsm_retry_ack_sent,  // Retry.Ack flit sent
    input                           cxl_vlsm_recovery,        // Transition to recovery occured
    input                           cxl_rbuf_retry_done,      // All flits have been replayed from the Retry Buffer
    input                           cxl_rbuf_empty,           // Retry Buffer Empty Indication
    input [(RBUF_ADD_WD - 1) : 0]   cxl_rbuf_wr_ptr,          // Retry Buffer Write Pointer 
    input [(RBUF_ADD_WD - 1) : 0]   cxl_rbuf_nfree,           // Retry Buffer Num Free Buff 
    input                           cfg_viral_satus,          // Viral indication
    input [(MAX_RETRY_WD - 1) : 0]  cxl_rx_num_retry,         // Echo the NUM_RETRY value from the Retry.Req
    input [(ESEQ_WD - 1) : 0]       cxl_rx_eseq,              // Echo the ESEQ value from the Retry.Req
// Outputs -----------------------------------------------------------------------------
    output logic                    cxl_rrsm_active,          // RRSM is in the active state 
    output logic                    cxl_rrsm_retry_ack,       // RRSM requests Retry.Ack sequence
    output logic [63:0]             cxl_rrsm_retry_payload,   // RRSM requests Retry.Ack payload
    output logic                    cxl_rrsm_rbuf_req,        // RRSM requests retry buffer to replay flits 
    output rrsm_state_e             cxl_rrsm_state            // RRSM State
);

// Declarations
rrsm_state_e        rrsm_state_nxt;   // RRSM FSM Next State
logic [ESEQ_WD-1:0] cxl_rx_eseq_s;    // ESEQ received with Retry.Req - next state
logic [ESEQ_WD-1:0] cxl_rx_eseq_r;    // ESEQ received with Retry.Req - register
logic [15:0]        cfg_viral_ldid_s; // Viral LD ID field to be sent in Retry.Ack

// Output Assignments
assign cxl_rrsm_active    = (cxl_rrsm_state != CXL_RRSM_NORMAL);
assign cxl_rrsm_retry_ack = (cxl_rrsm_state == CXL_RRSM_LRACK);
assign cxl_rrsm_rbuf_req  = (cxl_rrsm_state == CXL_RRSM_RETRY);

// Latch ESEQ value received with Retry.Req to echo it with the Retry.Ack
assign cxl_rx_eseq_s      = cxl_rx_retry_req ? cxl_rx_eseq : cxl_rx_eseq_r;

// Send Viral LDID only if Viral Status is 1
assign cfg_viral_ldid_s   = 16'd0;

// Retry Flit Generation
always_comb begin : rrsm_flit_proc
    unique case(cxl_rrsm_state)
        CXL_RRSM_LRACK: begin
            cxl_rrsm_retry_payload = {16'd0, cfg_viral_ldid_s, cxl_rbuf_nfree, cxl_rx_eseq_r, cxl_rbuf_wr_ptr, cxl_rx_num_retry, 1'b0, cfg_viral_satus, cxl_rbuf_empty};
        end
        default: begin
            cxl_rrsm_retry_payload = 64'd0;
        end
    endcase
end : rrsm_flit_proc

// RRSM State Machine
always_comb begin : rrsm_state_nxt_proc
    if (cxl_vlsm_recovery) begin
        // If Physical recovery is triggered then move back to the NORMAL state
        rrsm_state_nxt = CXL_RRSM_NORMAL;
    end
    else begin
        unique case(cxl_rrsm_state)
            CXL_RRSM_LRACK : begin
                if (cxl_rrsm_retry_ack_sent)
                    rrsm_state_nxt = cxl_rbuf_retry_done ? CXL_RRSM_NORMAL : CXL_RRSM_RETRY;
                else
                    rrsm_state_nxt = CXL_RRSM_LRACK;
            end
            CXL_RRSM_RETRY : begin
                if (cxl_rx_retry_req)
                    rrsm_state_nxt = CXL_RRSM_LRACK;
                else if (cxl_rbuf_retry_done)
                    rrsm_state_nxt = CXL_RRSM_NORMAL;
                else
                    rrsm_state_nxt = CXL_RRSM_RETRY;
            end
            default : begin // CXL_RRSM_NORMAL
                if (cxl_rx_retry_req)
                    rrsm_state_nxt = CXL_RRSM_LRACK;
                else
                    rrsm_state_nxt = CXL_RRSM_NORMAL;
            end
        endcase
    end
end : rrsm_state_nxt_proc

always_ff @(posedge core_clk or negedge core_rst_n) begin : rrsm_state_proc
    if (!core_rst_n) begin
        cxl_rrsm_state <= # TP CXL_RRSM_NORMAL;
        cxl_rx_eseq_r  <= # TP {ESEQ_WD{1'b0}};
    end
    else begin
        cxl_rrsm_state <= # TP rrsm_state_nxt;
        cxl_rx_eseq_r  <= # TP cxl_rx_eseq_s;
    end
end : rrsm_state_proc


endmodule
