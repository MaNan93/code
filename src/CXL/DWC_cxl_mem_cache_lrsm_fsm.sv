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
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_lrsm_fsm.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Local Retry State Machine
// Responsible for generating Retry.Req after CRC error is received.
// Handles the Retry.Req/Retry.Ack handshake.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_lrsm_fsm
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)(
// Inputs ------------------------------------------------------------------------------
    input                           core_clk,                 // Core clock
    input                           core_rst_n,               // Core reset
    input                           cxl_rx_retryable_flit,    // Received a retryable Flit
    input                           cxl_rx_crc_err,           // Receiver detected CRC error
    input                           cxl_rx_retry_ack,         // Received Retry.Ack
    input                           cxl_rx_retry_ack_empty,   // Empty bit indicates that the LLR contains no valid data
    input                           cxl_num_retry_match,      // Retry.Ack[NUM_RETRY] matches the expected NUM_RETRY
    input                           cxl_lrsm_retry_req_sent,  // Retry.Req flit sent
    input                           cxl_retry_timeout,        // Retry timeout occured
    input                           cxl_vlsm_recovery,        // Transition to recovery occured
    input                           cxl_req_retrain,          // Maximum number of retries reached trigger a transition to Recovery
    input                           cxl_req_abort,            // Maximum number of trips to recovery reached abort the process
    input                           cxl_vlsm_active,          // VLSM is in the active state
    input [(ESEQ_WD - 1) : 0]       cxl_eseq,                 // Retry Sequence Number (ESEQ) for the Retry.Req
    input [(MAX_RETRY_WD - 1) : 0]  cxl_num_retry,            // NUM_RETRY for the Retry.Req flit
    input [(MAX_REINIT_WD - 1) : 0] cxl_num_reinit,           // NUM_REINIT for the Retry.Req flit
// Outputs -----------------------------------------------------------------------------
    output logic                    cxl_lrsm_drop_flits,      // When asserted the receiver should discard all non LLCTRL retry flits
    output logic                    cxl_lrsm_normal,          // LRSM is in the normal state 
    output logic                    cxl_lrsm_retry_req,       // LRSM requests Retry.Req sequence
    output logic [63:0]             cxl_lrsm_retry_payload,   // LRSM requests Retry.Req payload
    output logic                    cxl_lrsm_idle_req,        // LRSM requests Retry.Idle flit
    output logic                    cxl_lrsm_req_retrain,     // LRSM requests PHY recovery
    output logic                    cxl_lrsm_abort,           // LRSM in abort state
    output logic                    cxl_lrsm_inc_eseq,        // Increment expected sequence number - ESeq
    output logic                    cxl_lrsm_rst_num_retry,   // Reset NUM_RETRY counter
    output logic                    cxl_lrsm_inc_num_retry,   // Increment NUM_RETRY counter
    output logic                    cxl_lrsm_rst_num_reinit,  // Reset NUM_PHY_REINIT counter
    output logic                    cxl_lrsm_inc_num_reinit,  // Increment NUM_PHY_REINIT counter
    output logic                    cxl_lrsm_rst_timeout_cnt, // Reset Timeout counter
    output logic                    cxl_lrsm_inc_timeout_cnt, // Increment Timeout counter
    output lrsm_state_e             cxl_lrsm_state            // LRSM State
);

// Declarations
lrsm_state_e                             lrsm_state_nxt;
logic                                    cxl_lrsm_req_retrain_nxt;

assign cxl_lrsm_drop_flits  = (cxl_lrsm_state != CXL_LRSM_NORMAL);
assign cxl_lrsm_normal      = (cxl_lrsm_state == CXL_LRSM_NORMAL);
assign cxl_lrsm_retry_req   = (cxl_lrsm_state == CXL_LRSM_LLREQ);
assign cxl_lrsm_idle_req    = (cxl_lrsm_state == CXL_LRSM_IDLE);
assign cxl_lrsm_abort       = (cxl_lrsm_state == CXL_LRSM_ABORT);

// Retry Flit Generation
always_comb begin : lrsm_flit_proc
    unique case(cxl_lrsm_state)
        CXL_LRSM_LLREQ : begin
            cxl_lrsm_retry_payload = {38'd0, cxl_num_reinit, cxl_num_retry, 8'd0, cxl_eseq};
        end
        default : begin // CXL_LRSM_GEN_NULL
            cxl_lrsm_retry_payload = 64'd0;
        end
    endcase
end : lrsm_flit_proc

always_comb begin : lrsm_state_nxt_proc
    cxl_lrsm_inc_eseq        = 1'b0;
    cxl_lrsm_rst_num_retry   = 1'b0;
    cxl_lrsm_inc_num_retry   = 1'b0;
    cxl_lrsm_rst_num_reinit  = 1'b0;
    cxl_lrsm_inc_num_reinit  = 1'b0;
    cxl_lrsm_rst_timeout_cnt = 1'b0;
    cxl_lrsm_inc_timeout_cnt = 1'b0;
    cxl_lrsm_req_retrain_nxt = cxl_lrsm_req_retrain;
    // If PHY_RESET/PHY_REINIT detected in any state 
    if (cxl_vlsm_recovery && !cxl_lrsm_abort && !cxl_lrsm_normal) begin
        cxl_lrsm_req_retrain_nxt = 1'b0;
        lrsm_state_nxt = CXL_LRSM_PHY_REINIT;
    end
    else begin
        unique case (cxl_lrsm_state)
            CXL_LRSM_LLREQ : begin
                // If (NUM_RETRY==MAX_NUM_RETRY) and (NUM_PHY_REINIT==MAX_NUM_PHY_REINIT) then
                // indicate link failure.
                if(cxl_req_abort) begin
                    lrsm_state_nxt = CXL_LRSM_ABORT;
                end
                // If (NUM_RETRY==MAX_NUM_RETRY) and (NUM_PHY_REINIT < MAX_NUM_PHY_REINIT) then
                // reset sent to physical layer. Increment NUM_PHY_REINIT.
                else if (cxl_req_retrain) begin
                    cxl_lrsm_req_retrain_nxt = 1'b1;
                    cxl_lrsm_inc_num_reinit  = 1'b1;
                    lrsm_state_nxt = CXL_LRSM_PHY_REINIT;
                end
                // If (NUM_RETRY < MAX_NUM_RETRY) and a Retry.Req sequence has been sent then
                // increment NUM_RETRY.
                else if (cxl_lrsm_retry_req_sent) begin
                    cxl_lrsm_inc_num_retry = 1'b1;
                    lrsm_state_nxt = CXL_LRSM_IDLE;
                end
                // If (NUM_RETRY < MAX_NUM_RETRY) and a Retry.Req sequence has not been sent then
                // stay in CXL_LRSM_LLREQ
                else begin
                    lrsm_state_nxt = CXL_LRSM_LLREQ;
                end
            end
            CXL_LRSM_IDLE : begin
                // Retry.Ack sequence is received and NUM_RETRY from Retry.Ack
                // matches the value in the local entity
                if(cxl_rx_retry_ack && cxl_num_retry_match) begin
                    // If Retry.Ack sequence is received with Empty bit set, NUM_RETRY is
                    // reset to 0 and NUM_PHY_REINIT is reset to 0.
                    if (cxl_rx_retry_ack_empty) begin
                      cxl_lrsm_rst_num_retry  = 1'b1;
                      cxl_lrsm_rst_num_reinit = 1'b1;
                    end

                    // The TIMEOUT counter is reset to  whenever the LRSM state changes 
                    // from RETRY_LOCAL_IDLE to RETRY_LOCAL_NORMAL
                    cxl_lrsm_rst_timeout_cnt = 1'b1;
                    lrsm_state_nxt = CXL_LRSM_NORMAL;
                end
                // TIMEOUT has reached its threshold.
                else if(cxl_retry_timeout) begin
                    // The TIMEOUT counter is reset to  whenever the LRSM state changes 
                    // from RETRY_LOCAL_IDLE to RETRY_LLRREQ
                    cxl_lrsm_rst_timeout_cnt = 1'b1;
                    lrsm_state_nxt = CXL_LRSM_LLREQ;
                end
                else begin
                    cxl_lrsm_inc_timeout_cnt = 1'b1;
                    lrsm_state_nxt = CXL_LRSM_IDLE;
                end
            end
            CXL_LRSM_PHY_REINIT : begin
                // Physical layer returns from Reinit.
                // NUM_RETRY is reset to 0.
                if (!cxl_lrsm_req_retrain && cxl_vlsm_active) begin
                   // The TIMEOUT counter is also reset when the Physical layer returns from 
                   // re-initialization (the LRSM transition through RETRY_PHY_REINIT to RETRY_LLRREQ).
                    cxl_lrsm_rst_timeout_cnt = 1'b1;
                    cxl_lrsm_rst_num_retry   = 1'b1;
                    lrsm_state_nxt = CXL_LRSM_LLREQ;
                end
                else begin
                    lrsm_state_nxt = CXL_LRSM_PHY_REINIT;
                end
            end
            CXL_LRSM_ABORT : begin
                lrsm_state_nxt = CXL_LRSM_ABORT;
            end
            default : begin // CXL_LRSM_NORMAL
                // Error is detected on a received flit
                if (cxl_rx_crc_err) begin
                    lrsm_state_nxt = CXL_LRSM_LLREQ;
                end
                else begin
                    // If an error free retryable flit is received.
                    // NUM_RETRY is reset to 0 and NUM_PHY_REINIT is reset to 0.
                    if (cxl_rx_retryable_flit) begin
                        cxl_lrsm_inc_eseq       = 1'b1;
                        cxl_lrsm_rst_num_retry  = 1'b1;
                        cxl_lrsm_rst_num_reinit = 1'b1;
                    end
                   
                    lrsm_state_nxt = cxl_vlsm_recovery ? CXL_LRSM_PHY_REINIT : CXL_LRSM_NORMAL;
                end
            end
        endcase
    end
end : lrsm_state_nxt_proc


always_ff @(posedge core_clk or negedge core_rst_n) begin : lrsm_state_proc
    if (!core_rst_n) begin
        cxl_lrsm_state       <= # TP CXL_LRSM_PHY_REINIT;
        cxl_lrsm_req_retrain <= # TP 1'b0;
    end
    else begin
        cxl_lrsm_state       <= # TP lrsm_state_nxt;
        cxl_lrsm_req_retrain <= # TP cxl_lrsm_req_retrain_nxt;
    end
end : lrsm_state_proc

endmodule
