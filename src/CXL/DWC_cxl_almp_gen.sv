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
// ---   $Revision: #14 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_almp_gen.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//
// ALMP Generator
//
// This module generates ALMPs based on the handshake requested by Link VLSM.
// The following ALMP Handshake sequences are handled by ALMP Generator:
// * TX ALMP Request-Status - Send ALMP Request and wait for ALMP Status
// * RX ALMP Request-Status - Receive Request ALMP and respond with ALMP Status
// * Status ALMP Exchange   - Send and Receive Status ALMP
//
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"

module DWC_cxl_almp_gen
  import spif_pkg::state_enc_e;
  import spif_pkg::RESET;
  import spif_pkg::ACTIVE;
  import spif_pkg::ACTIVE_L0S_PMNAK;
  import spif_pkg::IDLE_L1_1;
  import spif_pkg::L2;
  import spif_pkg::RETRAIN;
  import DWC_cxl_pkg::*;
#(
  parameter   TP               = `TP,
  parameter   VLSM_IO_INSTANCE = 1'b0  // 0 CXL.IO, 1 CXL.mem/CXL.cache
) 
                         (
  input                      core_clk,
  input                      core_rst_n,
  input                      cxl_device_type,       // CXL Device type
  input                      cxl_pcie_flit_mode,    // CXL 256B Flit Mode
  input                      cfg_pm_timeout_enable, // ARB/MUX PM Timeout Control Register - PM Timeout Enable
  input  [1:0]               cfg_pm_timeout_value,  // ARB/MUX PM Timeout Control Register - PM Timeout Value
  input                      link_in_training,      // Link is in training notification from LTSSM
  input                      almp_tx_en,            // Enable ALMP Transmit path
  input                      almp_arb_halt,         // ALMP Message Halt by ARB/MUX
  input                      almp_bypass,           // Bypass ALMP generation
  input                      almp_rx_request,       // ALMP Request is received
  input                      almp_rx_status,        // ALMP Status is received
  input  state_enc_e         almp_rx_link_state,    // ALMP Received Link State
  input                      almp_tx_request,       // VLSM requests to transmit ALMP Request
  input                      almp_tx_status,        // VLSM requests to transmit ALMP Status
  input                      almp_tx_sts_ena,       // VLSM enables ALMP Status Response to the received ALMP Request
  input  state_enc_e         vlsm_link_sts_state,   // VLSM Link Status State
  input  state_enc_e         vlsm_link_req_state,   // VLSM Link Request State
  output logic               vlsm_rx_req_done,      // VLSM RX Request-Status Handshake Done
  output logic               vlsm_tx_req_done,      // VLSM TX Request-Status Handshake Done
  output logic               vlsm_tx_sts_done,      // VLSM TX Status Exchange Handshake Done
  output logic               vlsm_tx_sts_error,     // VLSM TX Status Exchange Handshake Error
  output logic               almp_pm_req_timeout,   // PM Request ALMP Timeout
  output logic               almp_pm_req_rcvd,      // PM Request ALMP Received
  output logic               almp_rx_sts_pmnak,     // ALMP Status(Active.PMNAK) is received
  output logic               almp_rx_pm_nak,        // ALMP Status(Active.PMNAK) is received (registered to the Application IF)
  output logic               almp_rx_req_active,    // ALMP Request(Active) received on ARB/MUX IF
  output logic               vlsm_almp_req_sent,    // VLSM ALMP Request transmitted
  output logic               vlsm_almp_req_l1_rcvd, // ALMP Request(Active) received 
  output logic               vlsm_almp_req_l2_rcvd, // ALMP Request(Active) received
  output logic               vlsm_almp_unexp_error, // VLSM Unexpected ALMP error 
  output state_enc_e          vlsm_almp_rslvd_state, // VLSM Resolved State
  output vlsm_almp_debug_t   vlsm_almp_debug_info,  // ALMP Debug Information
  output logic               almp_valid,            // ALMP Message Valid to ARB/MUX
  output logic [127:0]       almp_data              // ALMP Message Data to ARB/MUX
);

// ALMP Generator FSM encoding
typedef enum logic [3:0] {
    ALMP_GEN_IDLE  = 4'b0001,
    ALMP_GEN_RX    = 4'b0010,
    ALMP_GEN_TX    = 4'b0100,
    ALMP_GEN_DONE  = 4'b1000
} almp_gen_state_e;

// Declarations
almp_gen_state_e  almp_rx_fsm_state_r, almp_rx_fsm_state_nxt;     // ALMP Generator RX FSM
almp_gen_state_e  almp_tx_fsm_state_r, almp_tx_fsm_state_nxt;     // ALMP Generator TX FSM
state_enc_e       almp_rx_link_state_r, almp_rx_link_state_nxt;   // Registered RX ALMP Received Link State
state_enc_e       almp_rx_req_state_r, almp_rx_req_state_nxt;     // Registered RX Request ALMP Link State
state_enc_e       almp_status_res_state_s;                        // vLSM State Resolution After Status Exchange
logic             almp_tx_request_r;                              // Register TX Request to preserve vlsm_almp_req_sent flag on a cycle it is de-asserted.
logic [2:0]       almp_unexp_error_s;                             // Unexpected ALMP Error
logic             almp_tx_request_ena_s;                          // Enable Request ALMP TX
logic             almp_tx_status_ena_s;                           // Enable Status ALMP TX
logic             almp_tx_req_sts_ena_r, almp_tx_req_sts_ena_nxt; // Enable Request/Status ALMP TX
logic             almp_1us_timeout_s;                             // PM 1us Timer Timeout
logic             almp_pm_req_timeout_s;                          // PM Request ALMP Timeout
logic             almp_pm_timeout_s;                              // PM Timeout: 10us timeout for DSP and 1ms timeout for USP in 256B Flit Mode
logic             almp_pm_req_rcvd_s;                             // PM Request ALMP Received
almp_struct       almp_gen_data;                                  // ALMP to ARB/MUX

// Outputs Assignment
assign vlsm_rx_req_done  = almp_bypass ? 1'b1 : (!almp_tx_status && (almp_rx_fsm_state_r == ALMP_GEN_DONE));
assign vlsm_tx_req_done  = almp_bypass ? 1'b1 : (almp_tx_request_r && (almp_tx_fsm_state_r == ALMP_GEN_DONE));
assign vlsm_tx_sts_done  = almp_bypass ? 1'b1 : (almp_tx_status && (almp_rx_fsm_state_r == ALMP_GEN_DONE) && (almp_tx_fsm_state_r == ALMP_GEN_DONE));
assign vlsm_tx_sts_error = almp_bypass ? 1'b0 : (vlsm_tx_sts_done && (vlsm_link_req_state != almp_status_res_state_s));

assign vlsm_almp_rslvd_state = almp_status_res_state_s;

assign vlsm_almp_req_sent    = (almp_tx_request || almp_tx_request_r) && (((almp_tx_fsm_state_r == ALMP_GEN_TX) && !almp_arb_halt) || (almp_tx_fsm_state_r == ALMP_GEN_RX) || (almp_tx_fsm_state_r == ALMP_GEN_DONE));

assign vlsm_almp_req_l1_rcvd = almp_rx_request && (almp_rx_link_state == IDLE_L1_1);
assign vlsm_almp_req_l2_rcvd = almp_rx_request && (almp_rx_link_state == L2);
// Request(Active) ALMP is received
assign almp_rx_req_active    = almp_rx_request && (almp_rx_link_state == ACTIVE);
assign almp_pm_req_rcvd_s    = vlsm_almp_req_l1_rcvd || vlsm_almp_req_l2_rcvd;
assign almp_rx_sts_pmnak     = vlsm_tx_req_done && (almp_rx_link_state_r == ACTIVE_L0S_PMNAK);

// ALMP interface to ARB/MUX
assign almp_valid = almp_gen_data.valid;
assign almp_data  = cxl_pcie_flit_mode ? {80'd0, almp_gen_data[16:1], 16'h0800, 16'h0000} : {4{almp_gen_data[16:1], 16'h0800}};



// -------------------------------------------------------------------------------------
// ALMP Generator Debug Information Bus
// -------------------------------------------------------------------------------------
assign vlsm_almp_debug_info = '{
    almp_state_req  : almp_tx_request,
    almp_state_sts  : almp_tx_status,
    almp_state_rsp  : almp_tx_sts_ena,
    almp_state_err  : vlsm_tx_sts_error,
    almp_unexp_err  : vlsm_almp_unexp_error,
    almp_unexp_info : almp_unexp_error_s,
    almp_tx_fsm     : almp_rx_fsm_state_r,
    almp_rx_fsm     : almp_rx_fsm_state_r,
    almp_tx_req     : vlsm_link_req_state,
    almp_tx_sts     : vlsm_link_sts_state,
    almp_rx_req     : almp_rx_req_state_r,
    almp_rx_sts     : almp_rx_link_state_r
};
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Unexpected ALMP Status for CXL1.1/CXL2.0 only
// -------------------------------------------------------------------------------------
// The following situations describe circumstances where an unexpected ALMP will cause
// entry to Retrain State:
// * When in the Synchronization portion on exit from Retrain, any ALMP other than a
//   Status ALMP is considered an unexpected ALMP and will trigger recovery.
// * When an Active Request ALMP has been sent, any ALMP other than an Active State
//   Status ALMP that is sent in response is considered an unexpected ALMP and will
//   trigger recovery.
// * Status ALMP is considered an unexpected ALMP and will trigger recovery, if 
//   it is received without first sending a Request ALMP or it is received outside of 
//   the Synchronization portion on exit from Retrain.
// -------------------------------------------------------------------------------------
// Status Exchange is requested and either Request ALMP is received
assign almp_unexp_error_s[2] = almp_tx_status  && (almp_rx_request/* || (almp_rx_fsm_state_r == ALMP_GEN_TX)*/);
// Active Request ALMP is sent and Status or Request ALMP other than Active is received
assign almp_unexp_error_s[1] = almp_tx_request && (almp_tx_fsm_state_r == ALMP_GEN_RX) && (almp_rx_request || almp_rx_status) && (vlsm_link_req_state == ACTIVE) && (almp_rx_link_state != ACTIVE);
// Status ALMP Received and neither Status Exchange nor Request ALMP is sent
assign almp_unexp_error_s[0] = almp_rx_status  && !almp_tx_status && !(almp_tx_request && (almp_tx_fsm_state_r == ALMP_GEN_RX));

assign vlsm_almp_unexp_error = (almp_bypass || cxl_pcie_flit_mode) ? 1'b0 : (|almp_unexp_error_s);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// vLSM State Resolution After Status Exchange
// No. Sent    Received Resolved
//  1. Reset   Reset    Reset
//  2. Reset   Active   Active
//  3. Reset   L2       Reset
//  4. Active  Reset    Active
//  5. Active  Active   Active
//  6. Active  Retrain  Active
//  7. Active  L1.x     Retrain
//  8. Active  L2       Reset
//  9. Retrain Active   Active
// 10. Retrain Retrain  Retrain
// 11. Retrain L1.x     Retrain
// 12. L1.x    Active   L1.x
// 13. L1.x    Retrain  L1.x
// 14. L1.x    L1.x     L1.x
// 15. L2      Active   L2
// 16. L2      Reset    L2
// 17. L2      L2       L2
// -------------------------------------------------------------------------------------
always_comb begin
    case ({vlsm_link_sts_state, almp_rx_link_state_r})
        { RESET     , RESET     } : almp_status_res_state_s = RESET;
        { RESET     , ACTIVE    } : almp_status_res_state_s = ACTIVE;
        { RESET     , L2        } : almp_status_res_state_s = RESET;
        { ACTIVE    , RESET     } : almp_status_res_state_s = ACTIVE;
        { ACTIVE    , ACTIVE    } : almp_status_res_state_s = ACTIVE;
        { ACTIVE    , RETRAIN   } : almp_status_res_state_s = ACTIVE;
        { ACTIVE    , IDLE_L1_1 } : almp_status_res_state_s = RETRAIN;
        { ACTIVE    , L2        } : almp_status_res_state_s = RESET;
        { RETRAIN   , ACTIVE    } : almp_status_res_state_s = ACTIVE;
        { RETRAIN   , RETRAIN   } : almp_status_res_state_s = RETRAIN;
        { RETRAIN   , IDLE_L1_1 } : almp_status_res_state_s = RETRAIN;
        { IDLE_L1_1 , ACTIVE    } : almp_status_res_state_s = IDLE_L1_1;
        { IDLE_L1_1 , RETRAIN   } : almp_status_res_state_s = IDLE_L1_1;
        { IDLE_L1_1 , IDLE_L1_1 } : almp_status_res_state_s = IDLE_L1_1;
        { L2        , ACTIVE    } : almp_status_res_state_s = L2;
        { L2        , RESET     } : almp_status_res_state_s = L2;
        { L2        , L2        } : almp_status_res_state_s = L2;
        // For combinations not captured in CXL Spec table resolve to the received state as previously
        default: almp_status_res_state_s = almp_rx_link_state_r;
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Received Status ALMP state register
// -------------------------------------------------------------------------------------
// We need to register Received Status ALMP when Status ALMP is requested as it may be
// received earlier than we transmit during Status Exchange.
always_comb begin
    if (almp_rx_status) begin
        almp_rx_link_state_nxt = almp_rx_link_state;
    end
    else begin
        almp_rx_link_state_nxt = almp_rx_link_state_r;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Received Request ALMP state register
// -------------------------------------------------------------------------------------
always_comb begin
    if (almp_rx_request) begin
        almp_rx_req_state_nxt = almp_rx_link_state;
    end
    else begin
        almp_rx_req_state_nxt = almp_rx_req_state_r;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// ALMP RX Request-Status Handshake
// -------------------------------------------------------------------------------------
always_comb begin
    almp_rx_fsm_state_nxt = almp_rx_fsm_state_r;

    case (almp_rx_fsm_state_r)
        ALMP_GEN_TX: begin
            // If Status Exchange is requested while previous RX Request-Status Handshake is not complete then exit to ALMP_GEN_RX state
            // If Status ALMP is received in the same cycle as almp_tx_status is asserted then transit to DONE state
            if (almp_tx_status) 
                almp_rx_fsm_state_nxt = almp_rx_status ? ALMP_GEN_DONE : ALMP_GEN_RX;
            // If Request ALMP was received and Status ALMP is sent then indicate
            // RX Request-Status Handshake completion
            else if (almp_gen_data.valid && (almp_gen_data.almp_type == STATUS) && !almp_arb_halt) 
                almp_rx_fsm_state_nxt = ALMP_GEN_DONE;
        end
        ALMP_GEN_RX: begin
            // If request is de-asserted transition back to IDLE state
            if (!almp_tx_status)
                almp_rx_fsm_state_nxt = ALMP_GEN_IDLE;
            // If Status ALMP is received when Status ALMP Exchange is requested then
            // transit to ALMP_GEN_DONE to indicate that Status ALMP is received
            else if (almp_rx_status && !almp_bypass) 
                almp_rx_fsm_state_nxt = ALMP_GEN_DONE;
        end
        ALMP_GEN_DONE: begin
            // If Request ALMP is received then send Status ALMP in response
            if (almp_rx_request && !almp_tx_status && !almp_bypass) 
                almp_rx_fsm_state_nxt = ALMP_GEN_TX;
            // If both TX and RX Request-Status Handshake was requested (4 ALMP exchange
            // during Activation sequence) then wait for both handshakes to complete before 
            // exiting to the IDLE state
            // If Status ALMP Exchange request was requested then wait for either the request
            // signal to be de-asserted or Status Exchange to be complete before exiting to IDLE state.
            // Otherwise, exit to IDLE state immediately after RX Request-Status sequence is completed.
            else if (almp_tx_request ? vlsm_tx_req_done : (almp_tx_status ? vlsm_tx_sts_done : 1'b1))
                almp_rx_fsm_state_nxt = ALMP_GEN_IDLE;
        end
        default: begin // ALMP_GEN_IDLE
            // If Request ALMP is received then send Status ALMP in response
            if (almp_rx_request && !almp_tx_status && !almp_bypass) 
                almp_rx_fsm_state_nxt = ALMP_GEN_TX;
            // Wait for Status ALMP to be received as a part of Status Exchange sequence
            // If Status ALMP is received in the same cycle as almp_tx_status is asserted then transit to DONE state
            else if (almp_tx_status) 
                almp_rx_fsm_state_nxt = almp_rx_status ? ALMP_GEN_DONE : ALMP_GEN_RX;
        end
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// ALMP TX Request-Status Handshake
// -------------------------------------------------------------------------------------
always_comb begin
    almp_tx_fsm_state_nxt = almp_tx_fsm_state_r;
    case (almp_tx_fsm_state_r)
        ALMP_GEN_TX: begin
            if (almp_gen_data.valid && !almp_arb_halt) begin
                // If Request ALMP was sent then wait for Status ALMP to be received
                if (almp_tx_request && (almp_gen_data.almp_type == REQUEST))
                    almp_tx_fsm_state_nxt = ALMP_GEN_RX;
                // If Status ALMP was sent then indicate completion
                else if (almp_tx_status && (almp_gen_data.almp_type == STATUS))
                    almp_tx_fsm_state_nxt = ALMP_GEN_DONE;
            end
            // If neither TX Request-Status nor TX Status Exchange request is asserted then terminate 
            // the handshake and exit to IDLE state
            else if (!almp_tx_request && !almp_tx_status) begin
                almp_tx_fsm_state_nxt = ALMP_GEN_IDLE;
            end
        end
        ALMP_GEN_RX: begin
            // If PM Request ALMP has been sent, any ALMP other than corresponding PM State
            // Status ALMP that is sent in response is considered an unexpected ALMP and will
            // trigger a new attempt to send PM Request ALMP.
            if (almp_rx_status) begin
                if ((vlsm_link_req_state == ACTIVE) || (vlsm_link_req_state == almp_rx_link_state))
                    almp_tx_fsm_state_nxt = ALMP_GEN_DONE;
                else if (cxl_device_type && cxl_pcie_flit_mode && (almp_rx_link_state==ACTIVE_L0S_PMNAK) &&
                       ((vlsm_link_req_state == IDLE_L1_1) || (vlsm_link_req_state == L2)))
                    almp_tx_fsm_state_nxt = ALMP_GEN_DONE;
                else
                    almp_tx_fsm_state_nxt = ALMP_GEN_TX;
            end
            // In 68B Flit Mode, if PM Request ALMP has been sent and 1 ms timeout was triggered waiting for Status ALMP 
            // to be received, then make a new attempt to send Request ALMP
            // In 256B Flit Mode, if PM Request ALMP has been sent and 1 ms timeout was triggered waiting for Status ALMP 
            // to be received, then complete the handshake and indicate PM Timeout Error
            else if (almp_pm_timeout_s)
                almp_tx_fsm_state_nxt = cxl_pcie_flit_mode ? ALMP_GEN_DONE : ALMP_GEN_TX;
            // If TX Request-Status request is de-asserted then terminate the handshake and exit to IDLE state
            else if (!almp_tx_request)
                almp_tx_fsm_state_nxt = ALMP_GEN_IDLE;
        end
        ALMP_GEN_DONE: begin
            // Exit to IDLE state f TX Request-Status Handshake is de-asserted and either TX Status exchange is complete or 
            // TX Status Exchange request is de-asserted
            if (!almp_tx_request && (almp_tx_status ? vlsm_tx_sts_done : 1'b1))
                almp_tx_fsm_state_nxt = ALMP_GEN_IDLE;
        end
        default: begin // ALMP_GEN_IDLE
            // If TX Request-Status ALMP handshake is requested then send Request ALMP
            if (almp_tx_request && !almp_bypass && almp_tx_request_ena_s) almp_tx_fsm_state_nxt = ALMP_GEN_TX;
            // If TX Status Exchange ALMP handshake is requested then send Status ALMP
            else if (almp_tx_status && !almp_bypass) almp_tx_fsm_state_nxt = ALMP_GEN_TX;
        end
    endcase
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// PM L1 Request Timeout Counter
//
// Not applicable for L2 request. Protocol must ensure that Upstream component is directed to 
// enter L2 before setting up the conditions for the Downstream Component to request entry 
// into L2 state. This ensures that L2 abort or L2 Retry conditions do not exist
// -------------------------------------------------------------------------------------
logic almp_1us_timeout_ena_nxt;  // Request(L1) ALMP timeout counter enable - next state
logic almp_1us_timeout_ena_r;    // Request(L1) ALMP timeout counter enable - register
logic almp_1us_timeout_ena_s;    // Request(L1) ALMP timeout counter enable if not in Recovery
logic almp_1us_timeout_set_s;    // Request(L1) ALMP timeout counter set enable flag
logic almp_1us_timeout_rst_s;    // Request(L1) ALMP timeout counter reset enable flag
logic almp_1us_timeout_clr_s;    // Request(L1) ALMP timeout counter clear

assign almp_pm_req_timeout_s = almp_pm_timeout_s;

// Enable counter while waiting for Status(L1) ALMP response from Upstream Component (not
// including time spent in recovery states)
assign almp_1us_timeout_ena_s = almp_1us_timeout_ena_r && !link_in_training;

always_comb begin
    almp_1us_timeout_set_s = 1'b0;
    almp_1us_timeout_rst_s = 1'b0;
    almp_1us_timeout_clr_s = 1'b0;

    // Downstream Port in 256B Flit Mode
    if (!cxl_device_type && cxl_pcie_flit_mode) begin
        // Enable 1us timer after receiving PM Request ALMP
        almp_1us_timeout_set_s = almp_rx_request && (almp_rx_link_state == IDLE_L1_1);
        // Disable 1us timer after sending PM Status ALMP
        almp_1us_timeout_rst_s = vlsm_rx_req_done;
        // Clear 1us timer when 1us timer is disabled
        almp_1us_timeout_clr_s = almp_1us_timeout_rst_s;
    end
    // Upstream Port in 256B Flit Mode
    if (cxl_device_type && cxl_pcie_flit_mode) begin
        // Enable 1us timer after sending PM Request ALMP if PM Timeout is enabled
        almp_1us_timeout_set_s = cfg_pm_timeout_enable && vlsm_almp_req_sent && (vlsm_link_req_state == IDLE_L1_1);
        // Disable 1us timer after receiving PM Status ALMP, either PM or PMNAK Status ALMP must be received
        almp_1us_timeout_rst_s = vlsm_tx_req_done;
        // Clear 1us timer when 1us timer is disabled
        almp_1us_timeout_clr_s = almp_1us_timeout_rst_s || (almp_tx_request && (almp_tx_fsm_state_r == ALMP_GEN_TX));
    end
    // Upstream Port in 68B Flit Mode
    if (cxl_device_type && !cxl_pcie_flit_mode) begin
        // Enable 1us timer after sending PM Request ALMP
        almp_1us_timeout_set_s = vlsm_almp_req_sent && (vlsm_link_req_state == IDLE_L1_1);
        // Disable 1us timer after receiving PM Status ALMP or when ACTIVE State is requested aborting PM entry attempts (only for 68B flit mode)
        // In 256B flit mode, either PM or PMNAK Status ALMP must be received
        almp_1us_timeout_rst_s = (almp_tx_request && vlsm_tx_req_done) || ((vlsm_link_req_state == ACTIVE) && (almp_tx_fsm_state_r == ALMP_GEN_TX));
        // Clear 1us timer when 1us timer is disabled or each time Request ALMP is being transmitted (only for 68B flit mode)
        almp_1us_timeout_clr_s = almp_1us_timeout_rst_s || (almp_tx_request && (almp_tx_fsm_state_r == ALMP_GEN_TX));
    end
end

always_comb begin
    if (almp_1us_timeout_set_s)
        almp_1us_timeout_ena_nxt = 1'b1;
    else if (almp_1us_timeout_rst_s)
        almp_1us_timeout_ena_nxt = 1'b0;
    else
        almp_1us_timeout_ena_nxt = almp_1us_timeout_ena_r;
end

// Enables Request ALMP for Upstream Port in 68B flit mode and Status ALMP for Downstream Port in 256B flit mode
always_comb begin
    // Set TX ALMP enable flag when 1us timer is either cleared or expired
    if (almp_1us_timeout_clr_s || (cxl_device_type ? almp_pm_timeout_s : almp_1us_timeout_s) )
        almp_tx_req_sts_ena_nxt = 1'b1;
    // Reset TX ALMP enable flag after setting 1us timer
    else if (almp_1us_timeout_set_s)
        almp_tx_req_sts_ena_nxt = 1'b0;
    else
        almp_tx_req_sts_ena_nxt = almp_tx_req_sts_ena_r;
end

DWC_cxl_base_timer

 #(
    .TIMER_WIDTH  (CXL_ALMP_L1REQ_TIMEOUT_WIDTH)
) u_almp_tx_req_timeout (
    // Inputs
    .clk          (core_clk),
    .rst_n        (core_rst_n),
    .clear_timer  (almp_1us_timeout_clr_s),
    .hold_timer   (1'b0),
    .enable       (almp_1us_timeout_ena_s),
    .timer_target ('1),
    .incr         ({{(CXL_ALMP_L1REQ_TIMEOUT_WIDTH-1){1'b0}},1'b1}),
    // Outputs
    .timeout_r    (almp_1us_timeout_s),
    .timeout      (),
    .timer_r      ()
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Enable Request/Status ALMP TX
// -------------------------------------------------------------------------------------
// Always enable State Request ALMP to be transmitted if the requested state is not L1
// otherwise wait for ALMP transmit enable flag to be set after 1us
assign almp_tx_request_ena_s    = (cxl_device_type && (vlsm_link_req_state == IDLE_L1_1)) ? almp_tx_req_sts_ena_r : 1'b1;

// Always enable State Status ALMP to be transmitted if the state status is not ACTIVE_PMNAK
// otherwise wait for State Status ALMP transmit enable flag to be set after 1us
assign almp_tx_status_ena_s    = (cxl_pcie_flit_mode && !cxl_device_type && (vlsm_link_sts_state == ACTIVE_L0S_PMNAK)) ? almp_tx_req_sts_ena_r : !almp_rx_request;
// -------------------------------------------------------------------------------------

// CX_CXL_PM_TIMER_ENABLE = CX_CXL_UPSTREAM_PORT || CX_CXL_256B_FLIT_ENABLE
// -------------------------------------------------------------------------------------
// CXL PM Timeouts
// 68B, 256B Upstream Port : 1ms timeout to report uncorrectable error 
//      256B Dowstream Port: 10us timeout to send ACTIVE.PMNAK Status
// -------------------------------------------------------------------------------------
logic [9:0] almp_1us_timeout_cnt_nxt; // Number of 1us timeouts - next state
logic [9:0] almp_1us_timeout_cnt_r;   // Number of 1us timeouts - register

assign almp_pm_timeout_s = almp_1us_timeout_cnt_r == (cxl_device_type ? 10'd1000 : 10'd10);

always_comb begin
    if (almp_1us_timeout_clr_s)
        almp_1us_timeout_cnt_nxt = 10'd0;
    else if (almp_1us_timeout_s && !almp_pm_timeout_s)
        almp_1us_timeout_cnt_nxt = almp_1us_timeout_cnt_r + 10'd1;
    else
        almp_1us_timeout_cnt_nxt = almp_1us_timeout_cnt_r;
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// TX ALMP Generation
// -------------------------------------------------------------------------------------
always_comb begin
    // Reset ALMP data
    almp_gen_data           = '0;

    if (almp_bypass) begin
        almp_gen_data           = '0;
    end
    // Send Status ALMP either in response to the received Request ALMP or as part Status Exchange sequence
    else if (almp_tx_en && (almp_tx_sts_ena && almp_tx_status_ena_s && (almp_rx_fsm_state_r == ALMP_GEN_TX) || almp_tx_status && (almp_tx_fsm_state_r == ALMP_GEN_TX))) begin
        almp_gen_data.vlsm_inst = (VLSM_IO_INSTANCE == 1'b1) ? CXL_IO : CXL_MEM_CACHE;
        almp_gen_data.almp_type = STATUS;
        almp_gen_data.almp_enc  = vlsm_link_sts_state;
        almp_gen_data.valid     = 1'b1;
    end
    // VLSM requests to send ALMP Request, must wait for Status Response to complete handshake
    else if (almp_tx_en && almp_tx_request && (almp_tx_fsm_state_r == ALMP_GEN_TX)) begin
        almp_gen_data.vlsm_inst = (VLSM_IO_INSTANCE == 1'b1) ? CXL_IO : CXL_MEM_CACHE;
        almp_gen_data.almp_type = REQUEST;
        almp_gen_data.almp_enc  = vlsm_link_req_state;
        almp_gen_data.valid     = 1'b1;
    end
end
// -------------------------------------------------------------------------------------


always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        almp_tx_fsm_state_r      <= # TP ALMP_GEN_IDLE;
        almp_rx_fsm_state_r      <= # TP ALMP_GEN_IDLE;
        almp_rx_link_state_r     <= # TP RESET;
        almp_rx_req_state_r      <= # TP RESET;
        almp_tx_request_r        <= # TP 1'b0;
        almp_tx_req_sts_ena_r    <= # TP 1'b0;
        almp_1us_timeout_ena_r   <= # TP 1'b0;
        almp_pm_req_timeout      <= # TP 1'b0;
        almp_1us_timeout_cnt_r   <= # TP 10'd0;
        almp_pm_req_rcvd         <= # TP 1'b0;
        almp_rx_pm_nak           <= # TP 1'b0;
    end else if (almp_bypass) begin
        almp_tx_fsm_state_r      <= # TP ALMP_GEN_IDLE;
        almp_rx_fsm_state_r      <= # TP ALMP_GEN_IDLE;
        almp_rx_link_state_r     <= # TP RESET;
        almp_rx_req_state_r      <= # TP RESET;
        almp_tx_request_r        <= # TP almp_tx_request;
        almp_tx_req_sts_ena_r    <= # TP almp_tx_req_sts_ena_nxt;
        almp_1us_timeout_ena_r   <= # TP almp_1us_timeout_ena_nxt;
        almp_pm_req_timeout      <= # TP almp_pm_req_timeout_s;
        almp_1us_timeout_cnt_r   <= # TP almp_1us_timeout_cnt_nxt;
        almp_pm_req_rcvd         <= # TP almp_pm_req_rcvd_s;
        almp_rx_pm_nak           <= # TP almp_rx_sts_pmnak;
    end else begin
        almp_tx_fsm_state_r      <= # TP almp_tx_fsm_state_nxt;
        almp_rx_fsm_state_r      <= # TP almp_rx_fsm_state_nxt;
        almp_rx_link_state_r     <= # TP almp_rx_link_state_nxt;
        almp_rx_req_state_r      <= # TP almp_rx_req_state_nxt;
        almp_tx_request_r        <= # TP almp_tx_request;
        almp_tx_req_sts_ena_r    <= # TP almp_tx_req_sts_ena_nxt;
        almp_1us_timeout_ena_r   <= # TP almp_1us_timeout_ena_nxt;
        almp_pm_req_timeout      <= # TP almp_pm_req_timeout_s;
        almp_1us_timeout_cnt_r   <= # TP almp_1us_timeout_cnt_nxt;
        almp_pm_req_rcvd         <= # TP almp_pm_req_rcvd_s;
        almp_rx_pm_nak           <= # TP almp_rx_sts_pmnak;
    end
end


// -------------------------------------------------------------------------------------
// ALMP Generator Assertions
//
// ALMP TX Request-Status Handshake Errors:
// * If Status ALMP received before Request ALMP is sent
// * If ALMP Status received after ALMP Request-Status is complete
// * If received Status ALMP state does not match the Request ALMP state
//
// ALMP RX Request-Status Handshake Errors:
// * A new Request ALMP received while previous RX Request-Status ALMP handshake is not complete
//
// ALMP Status Exchange Handshake Errors:
// * If Status ALMP is received after ALMP Status Exchange is complete
// * Request ALMP is received during ALMP Status Exchange
//
// -------------------------------------------------------------------------------------
//VCS coverage off
`define CXL_ASSERTIONS_DISABLE

//VCS coverage on
// -------------------------------------------------------------------------------------

endmodule
