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
// ---   $Revision: #9 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_lrsm.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Local Retry State Machine
// Responsible for generating Retry.Req after CRC error is received.
// Handles the Retry.Req/Retry.Ack handshake.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_lrsm
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)(
// Inputs ------------------------------------------------------------------------------
    input                             core_clk,                 // Core clock
    input                             core_rst_n,               // Core reset
    input [(MAX_RETRY_WD - 1) : 0]    cfg_max_retry,            // Maximum number of retries before triggering a retrain
    input [(MAX_REINIT_WD - 1) : 0]   cfg_max_reinit,           // Maximum number of PHY retrains before triggering abort of retry
    input [(RETRY_TIMER_WD - 1) : 0]  cfg_retry_timer,          // Retry timer target value
    input                             cxl_rx_retryable_flit,    // Received a retryable Flit
    input                             cxl_rx_crc_err,           // CRC error received
    input                             cxl_rx_retry_ack,         // Retry.Ack received
    input                             cxl_rx_retry_ack_empty,   // Empty bit indicates that the LLR contains no valid data
    input [(MAX_RETRY_WD - 1) : 0]    cxl_rx_ack_num_retry,     // Num Retry Field from the Retry.Ack flit
    input                             cxl_vlsm_recovery,        // VLSM is in Recovery
    input                             cxl_vlsm_active,          // VLSM active
    input                             cxl_tx_flit_valid,        // When set to 1 indicates that a flit is being transmitted
    input [(ESEQ_WD - 1) : 0]         cxl_rbuf_eseq,            // Sequence number from the retry buffer
    input                             cxl_packer_halt,          // Packer halt
    input                             cxl_lrsm_retry_req_sent,  // LRSM Retry.Req sent
    input                             flit_clk               ,  // Flit Clock
// Outputs -----------------------------------------------------------------------------
    output logic                      cxl_lrsm_retry_req,       // LRSM requests Retry.Req sequence
    output logic [63:0]               cxl_lrsm_retry_payload,   // LRSM requests Retry.Req payload
    output logic                      cxl_lrsm_idle_req,        // LRSM requests Retry.Idle flit
    output logic                      cxl_lrsm_retry_hit,       // LRSM Retry Threshold Hit
    output logic                      cxl_lrsm_reinit_hit,      // LRSM Reinit Threshold Hit
    output logic                      cxl_lrsm_uc_err,          // LRSM error conditions either LRSM Abort or unexpected Retry.Ack 
    output logic                      cxl_lrsm_drop_flits,      // LRSM is active this means all received non LLCTRL retry flits must be discarded
    output logic                      cxl_lrsm_req_retrain,     // LRSM requests a transition to Recovery
    output logic                      cxl_lrsm_inc_eseq,        // Increment expected sequence number - ESeq
    output lrsm_state_e               cxl_lrsm_state            // LRSM State
);

// Declarations
logic                           lrsm_uc_err_s;                        // LRSM Uncorrectable Error
logic [(MAX_RETRY_WD - 1) : 0]  num_retry_cnt_latch_r;                // Latch Number of Retry when Retry is requested
logic                           num_retry_match_s;                    // Number of Retry Match
logic                           lrsm_abort_req_s;                     // LRSM Abort Request
// LRSM FSM states
logic                           cxl_lrsm_normal;                      // LRSM FSM is in NORMAL state
logic                           cxl_lrsm_abort;                       // LRSM FSM is in ABORT state
// LRSM Counters
logic [MAX_RETRY_WD-1:0]        num_retry_cnt_r, num_retry_cnt_nxt;   // Number of Retry Counter
logic [MAX_REINIT_WD-1:0]       num_reinit_cnt_r, num_reinit_cnt_nxt; // Number of PHY Reinit Counter
logic [RETRY_TIMER_WD-1:0]      num_rtimer_cnt_r, num_rtimer_cnt_nxt; // Retry Timer Counter
// LRSM Timer Expiration Signals
logic                           num_retry_timeout_s;                  // Number of Retry Counter Done
logic                           num_reinit_timeout_s;                 // Number of PHY Reinit Counter Done
logic                           rtimer_timeout_s;                     // Retry Timer Counter Done
// LRSM Timers Control Signals
logic                           cxl_lrsm_rst_num_retry;               // Number of Retry Counter Reset
logic                           cxl_lrsm_inc_num_retry;               // Number of Retry Counter Increment
logic                           cxl_lrsm_rst_num_reinit;              // Number of PHY Reinit Counter Reset
logic                           cxl_lrsm_inc_num_reinit;              // Number of PHY Reinit Counter Increment
logic                           cxl_lrsm_rst_timeout_cnt;             // Retry Timer Counter Reset
logic                           cxl_lrsm_inc_timeout_cnt;             // Retry Timer Counter Increment

// Check if NUM_RETRY from Retry.Ack matches the value transmitted in the Retry.Req
assign num_retry_match_s = (num_retry_cnt_latch_r == cxl_rx_ack_num_retry);

// Request Abort when both Reinit and Retry counters are expired
assign lrsm_abort_req_s = num_reinit_timeout_s && num_retry_timeout_s;

assign cxl_lrsm_retry_hit  = num_retry_timeout_s && cxl_lrsm_retry_req;
assign cxl_lrsm_reinit_hit = num_reinit_timeout_s && num_retry_timeout_s && cxl_lrsm_retry_req;

// -------------------------------------------------------------------------------------
// LRSM FSM Instantiation
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_lrsm_fsm
 u_lrsm_fsm (
    // Inputs
    .core_clk                 ( core_clk                 ),
    .core_rst_n               ( core_rst_n               ),
    .cxl_rx_retryable_flit    ( cxl_rx_retryable_flit    ),
    .cxl_rx_crc_err           ( cxl_rx_crc_err           ),
    .cxl_rx_retry_ack         ( cxl_rx_retry_ack         ),
    .cxl_rx_retry_ack_empty   ( cxl_rx_retry_ack_empty   ),
    .cxl_num_retry_match      ( num_retry_match_s        ),
    .cxl_retry_timeout        ( rtimer_timeout_s         ),
    .cxl_vlsm_recovery        ( cxl_vlsm_recovery        ),
    .cxl_req_retrain          ( num_retry_timeout_s      ),
    .cxl_req_abort            ( lrsm_abort_req_s         ),
    .cxl_vlsm_active          ( cxl_vlsm_active          ),
    .cxl_lrsm_retry_req_sent  ( cxl_lrsm_retry_req_sent  ),
    .cxl_eseq                 ( cxl_rbuf_eseq            ),
    .cxl_num_retry            ( num_retry_cnt_r          ),
    .cxl_num_reinit           ( num_reinit_cnt_r         ),
    // Outputs
    .cxl_lrsm_inc_eseq        ( cxl_lrsm_inc_eseq        ),
    .cxl_lrsm_normal          ( cxl_lrsm_normal          ),
    .cxl_lrsm_drop_flits      ( cxl_lrsm_drop_flits      ),
    .cxl_lrsm_retry_req       ( cxl_lrsm_retry_req       ),
    .cxl_lrsm_retry_payload   ( cxl_lrsm_retry_payload   ),
    .cxl_lrsm_idle_req        ( cxl_lrsm_idle_req        ),
    .cxl_lrsm_req_retrain     ( cxl_lrsm_req_retrain     ),
    .cxl_lrsm_abort           ( cxl_lrsm_abort           ),
    .cxl_lrsm_rst_num_retry   ( cxl_lrsm_rst_num_retry   ),
    .cxl_lrsm_inc_num_retry   ( cxl_lrsm_inc_num_retry   ),
    .cxl_lrsm_rst_num_reinit  ( cxl_lrsm_rst_num_reinit  ),
    .cxl_lrsm_inc_num_reinit  ( cxl_lrsm_inc_num_reinit  ),
    .cxl_lrsm_rst_timeout_cnt ( cxl_lrsm_rst_timeout_cnt ),
    .cxl_lrsm_inc_timeout_cnt ( cxl_lrsm_inc_timeout_cnt ),
    .cxl_lrsm_state           ( cxl_lrsm_state           )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Error Reporting
// -------------------------------------------------------------------------------------
// LRSM Uncorrectable error due to LRSM abort or unexpected Retry.Ack
assign lrsm_uc_err_s = cxl_lrsm_abort || (!cxl_lrsm_idle_req && cxl_rx_retry_ack); 

// triplication of the control signals
DWC_pcie_ctl_bcm95
 #(
  .TMR    (TMR_EN),
  .WIDTH  (1)
) u_lrsm_ctrl_tmr (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .d_in   (lrsm_uc_err_s),
  .d_out  (cxl_lrsm_uc_err)
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// NUM_RETRY Counter
// -------------------------------------------------------------------------------------
assign num_retry_timeout_s = (num_retry_cnt_r == cfg_max_retry);

always_comb begin
    if (cxl_lrsm_rst_num_retry)
        num_retry_cnt_nxt = '0;
    else if (cxl_lrsm_inc_num_retry)
        num_retry_cnt_nxt = num_retry_cnt_r + 1;
    else
        num_retry_cnt_nxt = num_retry_cnt_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        num_retry_cnt_r  <= # TP '0;
    end else begin
        num_retry_cnt_r  <= # TP num_retry_cnt_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// NUM_PHY_REINIT Counter
// -------------------------------------------------------------------------------------
assign num_reinit_timeout_s = (num_reinit_cnt_r == cfg_max_reinit);

always_comb begin
    if (cxl_lrsm_rst_num_reinit)
        num_reinit_cnt_nxt = '0;
    else if (cxl_lrsm_inc_num_reinit)
        num_reinit_cnt_nxt = num_reinit_cnt_r + 1;
    else
        num_reinit_cnt_nxt = num_reinit_cnt_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        num_reinit_cnt_r  <= # TP '0;
    end else begin
        num_reinit_cnt_r  <= # TP num_reinit_cnt_nxt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Retry Timer
// -------------------------------------------------------------------------------------
assign rtimer_timeout_s = (num_rtimer_cnt_r == cfg_retry_timer);

always_comb begin
    if (cxl_lrsm_rst_timeout_cnt)
        num_rtimer_cnt_nxt = '0;
    else if (cxl_lrsm_inc_timeout_cnt & flit_clk)
        num_rtimer_cnt_nxt = num_rtimer_cnt_r + 1;
    else
        num_rtimer_cnt_nxt = num_rtimer_cnt_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        num_rtimer_cnt_r  <= # TP '0;
    end else begin
        num_rtimer_cnt_r  <= # TP num_rtimer_cnt_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Latch Number of Retry Counter in the Register
// -------------------------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin : lrsm_ctrl_proc
    if (!core_rst_n) begin
        num_retry_cnt_latch_r   <= # TP {MAX_RETRY_WD{1'b0}};
    end else begin
        // register the counter values in the LLREQ state
        if (cxl_lrsm_retry_req) begin
            num_retry_cnt_latch_r   <= # TP num_retry_cnt_r;
        end
    end
end : lrsm_ctrl_proc
// -------------------------------------------------------------------------------------






endmodule
