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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2022/04/14 09:36:50 $
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_prot_fsm.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transaction Layer Protocol Link Initialization FSM
//
// Description: Link initialization is a mechanism provided for a CXL channel interfaces of a
// given protocol to move between a full running operational state and a low power state.
// A four phase, request and acknowledge handshake mechanism is implemented for both
// CXL.cache and CXL.mem protocols which synchronizes the state of the link between
// Application Layer and CXL Controller.
//
// Four states are defined for the interface operation:
// * IDLE: The interface is in a low power state and it is not operational.
// * INIT: This state is used when moving from the IDLE state to the RUN state.
// * RUN: There is an ongoing exchange of messages and credits on protocol channel interfaces.
// * DEINIT: This state is used when moving from the RUN state to the IDLE state.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_cxl_mem_cache_tx_tl_prot_fsm #(
  parameter TP = `TP
)(
    // -------------------------------------------------------------------------------------
    // Clock and Reset
    // -------------------------------------------------------------------------------------
    input                         cxl_clk,                 // CXL clock
    input                         cxl_rst_n,               // CXL active low asynchronous reset
    // -------------------------------------------------------------------------------------
    // Configuration Interface
    // -------------------------------------------------------------------------------------
    input                         cfg_cxl_prot_capable,    // Enable CXL protocol
    // -------------------------------------------------------------------------------------
    // Low Power Handshake Interface
    // -------------------------------------------------------------------------------------
    input                         cxl_lp_req,              // Low Power mode request
    output                        cxl_lp_ack,              // Low Power mode acknowledge
    // -------------------------------------------------------------------------------------
    // Link Status Interface
    // -------------------------------------------------------------------------------------
    input                         core_link_up,            // Data Link Layer Up/Down Indicator
    input                         cxl_tx_idle,             // Indicates that CXL Transmitter is in IDLE state
    // -------------------------------------------------------------------------------------
    // CXL Protocol Link Initialization Interface
    // -------------------------------------------------------------------------------------
    input                         cxl_prot_init_req,       // Link Initialization Request from Application
    output                        cxl_prot_init_ack,       // Link Initialization Acknowledge from CXL Controller
    output                        cxl_prot_crd_ena,        // Protocol Channels Credit Enable signal
    output                        cxl_prot_crd_rst         // Protocol Channels Credit Reset signal
);

// -------------------------------------------------------------------------------------
// Types declaration
// -------------------------------------------------------------------------------------

// 4 phase active state
typedef enum {
   IDLE,
   INIT,
   RUN,
   DEINIT_MST,
   DEINIT_SLV
} ACTIVE_STATE_t;

// -------------------------------------------------------------------------------------
// Signals declaration
// -------------------------------------------------------------------------------------
ACTIVE_STATE_t  act_state_r, act_state_nxt;     // Protocol Link Initialization FSM
logic           activeack_r, activeack_nxt;     // Activation Acknowledge
logic [3:0]     cxl_tx_idle_r, cxl_tx_idle_nxt; // Accumulate TX Idle flag for 4 consecutive cycles
logic           cxl_tx_idle_s;                  // Ensure that TX Idle condition persists for N consecutive cycles to
                                                // allow the message sent on the last cycle before cxl_prot_init_req
                                                // de-assertion to propagate through TX Transaction Layer

assign cxl_tx_idle_s = &{cxl_tx_idle, cxl_tx_idle_r};

assign cxl_prot_init_ack = activeack_r;
// Reset Protocol credit counters when making a transition from DEINIT to the IDLE state
assign cxl_prot_crd_rst   = ((act_state_r == DEINIT_MST) || (act_state_r == DEINIT_SLV)) && (act_state_nxt == IDLE);
assign cxl_prot_crd_ena   = ((act_state_r == RUN) || (act_state_r == DEINIT_SLV)) && cxl_prot_init_req;
assign cxl_lp_ack         = ((act_state_r == IDLE) && cxl_tx_idle) || ((act_state_r == INIT) && !core_link_up);

// -------------------------------------------------------------------------------------
// TX Idle condition to persist for N clock cycles before transition to IDLE state
// -------------------------------------------------------------------------------------
always_comb begin
    if (act_state_nxt inside {IDLE, INIT, RUN}) begin
        cxl_tx_idle_nxt = '0;
    end
    else begin
        cxl_tx_idle_nxt = {cxl_tx_idle, cxl_tx_idle_r[3:1]};
    end
end

// -------------------------------------------------------------------------------------
// Flow Control -> Activation Acknowledge
// -------------------------------------------------------------------------------------
always_comb begin : cxl_prot_fsm_activeack_PROC
    activeack_nxt = activeack_r;
    case (act_state_r)
        IDLE: begin
            activeack_nxt = 1'b0;
        end
        INIT: begin
            if (core_link_up) activeack_nxt = 1'b1;
        end
        RUN: begin
            // If the link is active and the receiver intends to enter into Low Power mode,
            // it must first de-assert cxl_prot_init_ack signaling to the Application to
            // complete all ongoing transaction on Protocol Channels and de-assert
            // cxl_prot_init_req in response so it can transit to the IDLE state hence entering into LP mode.
            if (cxl_lp_req/* | ~core_link_up*/) activeack_nxt = 1'b0;
        end
        DEINIT_MST: begin
            // If Link Deactivation is initiated by the Application wait for CXL Controller to process
            // all data from channel buffers
            activeack_nxt = activeack_r & ~cxl_tx_idle_s;
        end
    endcase
end

// -------------------------------------------------------------------------------------
// Active state FSM
// -------------------------------------------------------------------------------------
always_comb begin : cxs_prot_fsm_act_state_PROC
    act_state_nxt = act_state_r;

    case (act_state_r)
        IDLE: begin
            // When Activation Request is asserted transit to INIT state
            // if Protocol Capability is enabled and Controller is not in Low Power mode
            if (cxl_prot_init_req & cfg_cxl_prot_capable & ~cxl_lp_req) act_state_nxt = INIT;
        end
        INIT: begin
            // If Link is up make transition to the RUN state acknowledging the request
            if (core_link_up) act_state_nxt = RUN;
        end
        RUN: begin
            // Remain in the RUN state until the Link De-activation is initiated either by the
            // Application de-asserting activation request or by the Controller asserting
            // Low Power mode request or when link is going down.
            if (~cxl_prot_init_req) act_state_nxt = DEINIT_MST;
            else if (cxl_lp_req/* | ~core_link_up*/) act_state_nxt = DEINIT_SLV;
        end
        DEINIT_MST: begin
            // CXL Slave Interface must wait for the core to complete all ongoing
            // transactions before entering the IDLE state.
            if (cxl_tx_idle_s) act_state_nxt = IDLE;
        end
        DEINIT_SLV: begin
            // CXL Slave Interface must wait for CXL Master Interface to deassert
            // cxl_prot_slv_req before entering the IDLE state.
            // If there are still transactions in the message buffers, transit to DIEINIT_MST state to flush them
            // before going into IDLE state
            if (~cxl_prot_init_req) act_state_nxt = cxl_tx_idle_s ? IDLE : DEINIT_MST;
        end
    endcase
end

always_ff @(posedge cxl_clk or negedge cxl_rst_n) begin
    if (!cxl_rst_n) begin
        act_state_r   <= #TP IDLE;
        activeack_r   <= #TP '0;
        cxl_tx_idle_r <= #TP '0;
    end
    else begin
        act_state_r   <= #TP act_state_nxt;
        activeack_r   <= #TP activeack_nxt;
        cxl_tx_idle_r <= #TP cxl_tx_idle_nxt;
    end
end

endmodule : DWC_cxl_mem_cache_tx_tl_prot_fsm
