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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/sdlh_cmd_if.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// SDLH CMD IF
//
// Description: This module implements the SDLH Command Interface.
// It observes SPIF interface state request/status and encodes them into commands for the upper layers of the transmitter.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module sdlh_cmd_if
  import cx_pl_pkg::tx_cmd_e;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::CMD_RESET;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
  import cx_pl_pkg::CMD_PYLD;
  import cx_pl_pkg::CMD_FLUSH_XAIM;
  import spif_pkg::state_enc_e;
  import spif_pkg::ACTIVE;
  import spif_pkg::ACTIVE_L0S_PMNAK;
  import spif_pkg::IDLE_L1_1;
  import spif_pkg::L2;
#(
  parameter TP  = `TP
) 
                    (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                 core_clk,
  input                 core_rst_n,
  input                 cmd_if_enable,     // Enable Command Interface  
  input                 pcie_flit_mode,    // Flit mode enabled
  // -------------------------------------------------------------------------------------
  // PM Interface 
  // -------------------------------------------------------------------------------------
  input                 pm_block_tlp_req,  // PM Protocol FSM BLOCK_TLP Request
  output                pm_block_tlp_ack,  // PM Protocol FSM BLOCK_TLP Acknowledge
  // -------------------------------------------------------------------------------------
  // SPIF Interface 
  // -------------------------------------------------------------------------------------
  input   state_enc_e   lp_state_req,      // Link Layer to Packet Layer State Request
  input                 lp_stall_ack,      // Link Layer to Packet Layer Stall Acknowledge
  input   state_enc_e   pl_state_sts,      // Packet Layer to Link Layer State Status
  input                 pl_stall_req,      // Packet Layer to Link Layer Stall Request 
  // -------------------------------------------------------------------------------------
  // SDLH Interface 
  // -------------------------------------------------------------------------------------
  input                 sdlh_cmd_if_ack,   // Command Complete Acknowledge from XDLH to SDLH
  output  tx_cmd_struct sdlh_cmd_if_cmd    // Command from SDLH to XDLH
);

// SDLH Command State
typedef enum logic [2:0] {
    CMD_FSM_RESET,     // Reset
    CMD_FSM_ACTIVE,    // Request Payload Data 
    CMD_FSM_RETRAIN,   // Wait for Recovery Exit (no requests sent)
    CMD_FSM_LOW_POWER  // Wait for Low Power Exit (no requests sent)
    ,
    CMD_FSM_ENTER_PM,  // Request Low Power Entry Results in Flush to Application Layer
    CMD_FSM_FLUSH      // Request Flush (exit from ACTIVE state)
} state_e;

state_e  state_r, state_nxt;    // Command Interface FSM
logic    int_cmd_ack_nxt;       // Command Acknowledge Flag (resets on any state transition) - next state
logic    int_cmd_ack_r;         // Command Acknowledge Flag (resets on any state transition) - register state
logic    int_block_tlp_ack_nxt; // PM Protocol FSM Block TLP Request Ackowledgement = next state
logic    int_block_tlp_ack_r;   // PM Protocol FSM Block TLP Request Ackowledgement - register state
logic    int_cmd_retrain_s;     // Command Interface FSM transitions to/from CMD_FSM_RETRAIN
tx_cmd_e int_last_command_r;

// Acknowledge PM BLOCK_TLP request
assign pm_block_tlp_ack = int_block_tlp_ack_r;

// Preserve command acknowledge information on transition to/from CMD_FSM_RETRAIN state.
// Required for not losing the payload command acknowledge from XTLH on transition to the recovery in PCIe non-flit mode.
assign int_cmd_retrain_s = ((state_nxt == CMD_FSM_RETRAIN) || (state_r == CMD_FSM_RETRAIN));

// Sample Command Interface acknowledge until FSM state change
always_comb begin
    if ((state_nxt != state_r) && ( pcie_flit_mode ? 1'b1 : !int_cmd_retrain_s))
        int_cmd_ack_nxt = 1'b0;
    else if (sdlh_cmd_if_ack)
        int_cmd_ack_nxt = 1'b1;
    else
        int_cmd_ack_nxt = int_cmd_ack_r;
end

// Sample Block TPL acknowledge until command changes to CMD_FSM_RESET
always_comb begin
    if (state_r == CMD_FSM_RESET)
        int_block_tlp_ack_nxt = 1'b0;
    else if ((state_r == CMD_FSM_LOW_POWER) || ((state_r == CMD_FSM_ENTER_PM) && int_cmd_ack_r))
        int_block_tlp_ack_nxt = 1'b1;
    else
        int_block_tlp_ack_nxt = int_block_tlp_ack_r;
end

// -------------------------------------------------------------------------------------
// Command Interface FSM
// -------------------------------------------------------------------------------------
always_comb begin : cmd_state_PROC 
    state_nxt = state_r;
    case (state_r)
        // Request Flush on exit from ACTIVE state
        CMD_FSM_FLUSH : begin
            // A transition to this state is possible only after pl_stall_req is asserted
            // in the ACTIVE state. Wait for lp_stall_ack to be asserted by the Link Layer
            // and stall req/ack handshake to complete before moving Command Interface FSM to CMD_FSM_RETRAIN state.
            if (lp_stall_ack && int_cmd_ack_r)
                state_nxt = CMD_FSM_RETRAIN;
            else
                state_nxt = state_r;
        end
        // Request Low Power Entry from ACTIVE state
        CMD_FSM_ENTER_PM : begin
            // If PM Phase 1 entry is complete and lp_state_req changes to L0S, IDLE_L1_1 or L2
            if ((lp_state_req inside {ACTIVE_L0S_PMNAK, IDLE_L1_1, L2}) && int_cmd_ack_r)
                state_nxt = CMD_FSM_LOW_POWER;
            // If Link Layer continues requesting ACTIVE state and PM Controller de-asserts block TLP request
            // then abort L1 entry and return to ACTIVE state (NAK scenario in PCIe flit mode)
            else if ((lp_state_req == ACTIVE) && !pm_block_tlp_req && int_cmd_ack_r)
                state_nxt = CMD_FSM_ACTIVE;
            // If pl_stall_req is asserted to exit from ACTIVE state before Phase 1 entry is complete
            else if (pl_stall_req && int_cmd_ack_r)
                state_nxt = CMD_FSM_FLUSH;
            else
                state_nxt = state_r;
        end
        // Low Power State
        CMD_FSM_LOW_POWER : begin
            // Wait for Link Layer to start requesting ACTIVE state
            if ((lp_state_req == ACTIVE) && !pm_block_tlp_req)
                state_nxt = CMD_FSM_RETRAIN;
            else
                state_nxt = state_r;
        end
        // Request Payload Flits while in ACTIVE state
        CMD_FSM_ACTIVE : begin
            // Request to block TLPs on entry to low power state. This does not change lp_state_req, 
            // it is changed after PM Protocol FSM subsequently reaches L1/L2 state requesting 
            // PM Link FSM to bring the Physical link into electrical idle state for PCIe or requesting
            // Link vLSM to start ALMP negotiation and bring interface state to L1/L2 for CXL.
            if (pm_block_tlp_req && int_cmd_ack_r)
                state_nxt = pcie_flit_mode ? CMD_FSM_ENTER_PM : CMD_FSM_LOW_POWER;
            // Move to CMD_FSM_FLUSH state when pl_stall_req is asserted.
            // pl_stall_req must be always asserted when exiting from ACTIVE state
            else if (pl_stall_req && int_cmd_ack_r)
                state_nxt = pcie_flit_mode ? CMD_FSM_FLUSH : CMD_FSM_RETRAIN;
            else
                state_nxt = state_r;
        end
        default : begin
            // Wait for Packet Layer to change State Status to ACTIVE
            // Check that the Link Layer is not stalled before completing a transition to CMD_FSM_ACTIVE
            if ((pl_state_sts == ACTIVE) && !pl_stall_req && !lp_stall_ack && cmd_if_enable)
                state_nxt = CMD_FSM_ACTIVE;
            else
                state_nxt = state_r;
        end
    endcase
end : cmd_state_PROC

// -------------------------------------------------------------------------------------
// Command Interface Request
// -------------------------------------------------------------------------------------
always_comb begin : cmd_out_PROC
    sdlh_cmd_if_cmd = '0;
    sdlh_cmd_if_cmd.flit_mode = pcie_flit_mode;
    case(state_r)
        CMD_FSM_FLUSH : begin 
            sdlh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XTLH;
            if(int_cmd_ack_r)
                sdlh_cmd_if_cmd.req = 1'b0;
            else
                sdlh_cmd_if_cmd.req = 1'b1;
        end
        CMD_FSM_ENTER_PM : begin 
            sdlh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XAIM;
            if(int_cmd_ack_r)
                sdlh_cmd_if_cmd.req = 1'b0;
            else
                sdlh_cmd_if_cmd.req = 1'b1;
        end
        CMD_FSM_LOW_POWER : begin
            sdlh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XAIM;
            sdlh_cmd_if_cmd.req = 1'b0;
        end
        CMD_FSM_ACTIVE : begin 
            sdlh_cmd_if_cmd.tx_cmd = CMD_PYLD;
            if(int_cmd_ack_r)
                sdlh_cmd_if_cmd.req = 1'b0;
            else
                sdlh_cmd_if_cmd.req = 1'b1;
        end
        default : begin 
            sdlh_cmd_if_cmd.tx_cmd = int_last_command_r;
        end
    endcase
end : cmd_out_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        state_r             <= #TP CMD_FSM_RESET;
        int_cmd_ack_r       <= #TP 1'b0;
        int_block_tlp_ack_r <= #TP 1'b0;
        int_last_command_r  <= #TP CMD_RESET;
    end else begin
        state_r             <= #TP state_nxt;
        int_cmd_ack_r       <= #TP int_cmd_ack_nxt;
        int_block_tlp_ack_r <= #TP int_block_tlp_ack_nxt;
        int_last_command_r  <= #TP sdlh_cmd_if_cmd.tx_cmd;
    end
end

endmodule
