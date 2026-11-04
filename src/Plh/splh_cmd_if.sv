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
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/splh_cmd_if.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// SPLH CMD IF
//
// Description: This module implements the SPLH Command Interface.
// It observes SPIF interface state request/status and encodes them into commands to XPLH
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module splh_cmd_if
  import cx_pl_pkg::tx_cmd_e;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::CMD_IDLE;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
  import cx_pl_pkg::CMD_PYLD;
  import spif_pkg::state_enc_e;
  import spif_pkg::RESET;
  import spif_pkg::ACTIVE;
  import spif_pkg::RETRAIN;
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
  input                 cmd_if_enable,         // Enable Command Interface  
  input                 splh_flit_mode,        // Flit mode enabled
  // -------------------------------------------------------------------------------------
  // SPIF Interface 
  // -------------------------------------------------------------------------------------
  input                 lp_irdy,               // Link Layer is ready to transfer data
  input   state_enc_e   lp_state_req,          // Link Layer to Packet Layer State Request
  input                 lp_stall_ack,          // Link Layer to Packet Layer Stall Acknowledge
  input   state_enc_e   pl_state_sts,          // Packet Layer to Link Layer State Status
  input                 pl_stall_req,          // Packet Layer to Link Layer Stall Request 
  input                 pl_protocol_vld,       // Packet Layer to Link Layer Protocol Valid
  input                 pl_link_up,            // Packet Layer to Link Layer Link Up
  input                 pl_phyinretrain,       // Packet Layer to Link Layer Recovery Flag
  // -------------------------------------------------------------------------------------
  // SPLH Interface 
  // -------------------------------------------------------------------------------------
  input                 splh_cmd_if_ack,       // Command Complete Acknowledge from XPLH to SPLH
  output  tx_cmd_struct splh_cmd_if_cmd,       // Command from SPLH to XPLH
  output  logic         splh_cmd_if_pmreq_l1,  // Command Interface L1 Entry Request to PM Link FSM
  output  logic         splh_cmd_if_pmreq_l2,  // Command Interface L2 Entry Request to PM Link FSM
  output  logic         splh_cmd_if_pmreq_ack, // Command Interface PM Entry Acknowledge to XMLH
  output  logic         splh_cmd_if_stall_ack, // Command Interface Stall Acknowledge to XMLH
  output  logic         splh_cmd_if_pending    // Command Interface Packet Pending Indication to XMLH
);

// SPLH Command State
typedef enum logic [2:0] {
  CMD_FSM_RESET,     // Reset
  CMD_FSM_ACTIVE,    // Request Payload Data 
  CMD_FSM_ENTER_PM,  // Request Low Power Entry (complete stall_req/ack handshake)
  CMD_FSM_LOW_POWER  // Wait for Low Power Exit (no requests sent)
  ,
  CMD_FSM_IDLE,      // Request IDLE generation 
  CMD_FSM_FLUSH      // Request Flush (exit from ACTIVE state)
} state_e;

state_e       state_r, state_nxt;    // Command Interface FSM
logic         int_cmd_ack_nxt;       // Command Acknowledge Flag (resets on any state transition) - next state
logic         int_cmd_ack_r;         // Command Acknowledge Flag (resets on any state transition) - register
logic         int_cmd_ack_rst_ena_s; // Enable Command Acknowledge Flag reset
logic         int_retrain_state_s;   // RETRAIN state indication on SPIF Interface
state_enc_e   pm_state_sts_nxt;      // Sampled Link Layer PM state request - next state
state_enc_e   pm_state_sts_r;        // Sampled Link Layer PM state request = register
logic         pm_complete_nxt;       // PM Entry Complete - next state
logic         pm_complete_r;         // PM Entry Complete - register

// Interface to PM Link FSM
assign splh_cmd_if_pmreq_l1  = (pm_state_sts_r == IDLE_L1_1);// && lp_stall_ack;//splh_cmd_if_pmreq_ack;
assign splh_cmd_if_pmreq_l2  = (pm_state_sts_r == L2       );// && lp_stall_ack;//splh_cmd_if_pmreq_ack;
// Interface to XMLH
assign splh_cmd_if_pmreq_ack = (state_r == CMD_FSM_LOW_POWER) || (splh_cmd_if_stall_ack && (pm_state_sts_r != RESET));
assign splh_cmd_if_stall_ack = (state_r inside {CMD_FSM_IDLE, CMD_FSM_FLUSH}) && int_cmd_ack_r;
assign splh_cmd_if_pending   = (state_r == CMD_FSM_ACTIVE) || ((state_r == CMD_FSM_FLUSH) && !int_cmd_ack_r);
// if State Status is in RESET assert internal Retrain flag when RX is in recovery and TX is stalled
// otherwise follow RETRAIN indication on State Status
assign int_retrain_state_s   = (pl_state_sts == RESET) ? (pl_phyinretrain && pl_stall_req && lp_stall_ack) : (pl_state_sts == RETRAIN);

// Always reset command acknowledge flag on state transition with the following exceptions:
// 1) On transition to CMD_FSM_ENTER_PM as this state does not request any new command and 
//    there might be a transition back to CMD_FSM_ACTIVE state
// 2) On transition from  CMD_FSM_ENTER_PM to CMD_FSM_ACTIVE (see above)
assign int_cmd_ack_rst_ena_s = (state_nxt != CMD_FSM_ENTER_PM) && !((state_r == CMD_FSM_ENTER_PM) && (state_nxt == CMD_FSM_ACTIVE));

// Sample Command Interface acknowledge until FSM state change
always_comb begin
    if ((state_nxt != state_r) && int_cmd_ack_rst_ena_s)
        int_cmd_ack_nxt = 1'b0;
    else if (splh_cmd_if_ack)
        int_cmd_ack_nxt = 1'b1;
    else
        int_cmd_ack_nxt = int_cmd_ack_r;
end

// Sample Link Layer state request on entry to PM
always_comb begin
    // Reset latched PM request when lp_state_req changes to ACTIVE in CMD_FSM_LOW_POWER state
    // Required to release PM entry request signals to PM Link FSM
    if ((state_r inside {CMD_FSM_RESET, CMD_FSM_ACTIVE , CMD_FSM_IDLE}) || ((state_r == CMD_FSM_LOW_POWER) && (lp_state_req == ACTIVE)))
        pm_state_sts_nxt = RESET;
    else if (state_nxt == CMD_FSM_ENTER_PM)
        pm_state_sts_nxt = lp_state_req;
    else
        pm_state_sts_nxt = pm_state_sts_r;
end

// Sample pl_state_sts change from ACTIVE in CMD_FSM_LOW_POWER state
always_comb begin
    if ((state_r == CMD_FSM_LOW_POWER) && (pl_state_sts != ACTIVE))
        pm_complete_nxt = 1'b1;
    else if (state_r != CMD_FSM_LOW_POWER)
        pm_complete_nxt = 1'b0;
    else
        pm_complete_nxt = pm_complete_r;
end

// -------------------------------------------------------------------------------------
// Command Interface FSM
// -------------------------------------------------------------------------------------
always_comb begin : cmd_state_PROC 
    state_nxt = state_r;
    case (state_r)
        // Request IDLE Flit Generation
        CMD_FSM_IDLE : begin
            // Wait for Physical Layer (smlh_spif) to de-assert pl_stall_req for a transition to CMD_FSM_ACTIVE
            if (!pl_stall_req && int_cmd_ack_r)
                state_nxt = CMD_FSM_ACTIVE;
            // If Loopback mode is entered from the Recovery, pl_link_up is de-asserted on exit from the Loopback.
            // In this case, exit to CMD_FSM_RESET state to reset XPLH.
            else if (!pl_link_up && int_cmd_ack_r)
                state_nxt = CMD_FSM_RESET;
            else
                state_nxt = state_r;
        end
        // Request Flush on exit from ACTIVE state
        CMD_FSM_FLUSH : begin
            // A transition to this state is possible only after completing pl_stall_req/ack handshake on exit from the ACTIVE state. 
            // Move to CMD_FSM_RESET state after flushing XPLH if the flush has not been triggered due to PM request.
            if ((pm_state_sts_r == RESET) && int_cmd_ack_r) begin
                //state_nxt = CMD_FSM_RESET;
                // Code below required not to modify XPLH Control Command Interface logic
                // Wait for either pl_state_sts to change or pl_stall_req to be de-asserted.

                // If after flush Physical Layer changes the state to RETRAIN then move to CMD_FSM_IDLE state to
                // trigger IDLE Sequence Handshake on exit from the recovery
                if (int_retrain_state_s)
                    state_nxt = CMD_FSM_IDLE;
                // If pl_stall_req was de-asserted while the Physical Layer still in ACTIVE state then
                // simply return to ACTIVE state. It is allowed to trigger stall_req/ack in the ACTIVE state.
                else if (pl_state_sts == ACTIVE)
                    state_nxt = !pl_stall_req ? CMD_FSM_ACTIVE : state_r;
                // If the Physical Layer changes its state to any state other than RETRAIN then go to CMD_FSM_RESET state
                // May happen if stall_req/ack was triggered on entry to LINKDISABLE, LINKRESET, etc.
                // As CMD_RESET does not gracefully exit XPLH, stay in CMD_FSM_FLUSH state for now.
                else
                    state_nxt = state_r;//CMD_FSM_RESET;
            end
            // Move to CMD_FSM_LOW_POWER state after flushing XPLH if the flush has been triggered due to PM request.
            else if ((pm_state_sts_r != RESET) && int_cmd_ack_r)
                state_nxt = CMD_FSM_LOW_POWER;
            else
                state_nxt = state_r;
        end
        // Enter Low Power State
        CMD_FSM_ENTER_PM : begin
            // Phase3 starts with Packet Layer flushing the transmit datapath (XPLH) and acknowledging it to
            // PM Link FSM in the Flit mode. In non-Flit mode, move directly to CMD_FSM_LOW_POWER state.
            //
            // Wait to complete stall_req/ack handshake with the Link Layer to flush XPLH
            if ((lp_state_req inside {IDLE_L1_1, L2}) && pl_stall_req && lp_stall_ack)
                state_nxt = splh_flit_mode ? CMD_FSM_FLUSH : CMD_FSM_LOW_POWER;
            else if (pl_stall_req && lp_stall_ack)
                state_nxt = splh_flit_mode ? CMD_FSM_FLUSH : CMD_FSM_RESET;
            else if ((lp_state_req == ACTIVE) && !pl_stall_req && !lp_stall_ack)
                state_nxt = CMD_FSM_ACTIVE;
            else
                state_nxt = state_r;
        end
        // Low Power State
        CMD_FSM_LOW_POWER : begin
            // Wait for Link Layer to start requesting ACTIVE state to start IDLE Flit Handshake
            if ((lp_state_req == ACTIVE) && pm_complete_r)
                state_nxt = splh_flit_mode ? CMD_FSM_IDLE : CMD_FSM_RESET;
            else
                state_nxt = state_r;
        end
        // Request Payload Flits while in ACTIVE state
        CMD_FSM_ACTIVE : begin
            // Phase1 and Phase2 PM Entry is complete and Link Layers request Packet Layer to
            // initiate Phase3 PM Entry and bring the Physical link into electrical idle state.
            if ((lp_state_req inside {IDLE_L1_1, L2}) && !pl_stall_req && int_cmd_ack_r)
                state_nxt = CMD_FSM_ENTER_PM;
            // pl_stall_req/ack handshake is always peformed when exiting from ACTIVE state. Use it as an indication of
            // Link Layer starting an exit away from the ACTIVE state
            //
            // In Flit mode, move to CMD_FSM_FLUSH state to flush XPLH when pl_stall_req/ack handshake on Link Layer is complete.
            // In non-Flit mode, as there is nothing to flush in XPLH, move directly to CMD_FSM_RESET state on completion of pl_stall_req/ack handshake.
            else if (pl_stall_req && lp_stall_ack && int_cmd_ack_r)
                state_nxt = splh_flit_mode ? CMD_FSM_FLUSH : CMD_FSM_RESET;
            else
                state_nxt = state_r;
        end
        default : begin
            // If Flit mode is enabled then transition to CMD_FSM_IDLE state to prepare IDLE flits and
            // wait for the Physical Layer to de-assert pl_stall_req to start a transmission of IDLE flits
            //
            // Note: pl_link_up and pl_state_sts=ACTIVE conditions are required only for the Loopback mode which
            // maps Loopback.Active to the ACTIVE state on the SPIF interface
            if (splh_flit_mode && pl_protocol_vld && pl_link_up && (pl_state_sts inside {RESET, ACTIVE}))
                state_nxt = CMD_FSM_IDLE;
            else
            // Wait for Physical Layer (smlh_spif) to de-assert pl_stall_req for a transition to CMD_FSM_ACTIVE
            if (cmd_if_enable && !pl_stall_req)
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
    splh_cmd_if_cmd = '0;
    splh_cmd_if_cmd.flit_mode = splh_flit_mode;
    case(state_r)
        CMD_FSM_IDLE: begin
            splh_cmd_if_cmd.tx_cmd = CMD_IDLE;
            if(int_cmd_ack_r)
                splh_cmd_if_cmd.req = 1'b0;
            else
                splh_cmd_if_cmd.req = 1'b1;
        end
        CMD_FSM_FLUSH : begin 
            splh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XTLH;
            if(int_cmd_ack_r)
                splh_cmd_if_cmd.req = 1'b0;
            else
                splh_cmd_if_cmd.req = 1'b1;
        end
        CMD_FSM_ENTER_PM, CMD_FSM_LOW_POWER : begin
            splh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XTLH;
            splh_cmd_if_cmd.req = 1'b0;
        end
        CMD_FSM_ACTIVE : begin 
            splh_cmd_if_cmd.tx_cmd = CMD_PYLD;
            if(int_cmd_ack_r)
                splh_cmd_if_cmd.req = 1'b0;
            else
                splh_cmd_if_cmd.req = 1'b1;
        end
        default : begin 
            splh_cmd_if_cmd = '0;
            splh_cmd_if_cmd.flit_mode = splh_flit_mode;
        end
    endcase
end : cmd_out_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        state_r        <= #TP CMD_FSM_RESET;
        pm_state_sts_r <= #TP RESET;
        pm_complete_r  <= #TP 1'b0;
        int_cmd_ack_r  <= #TP 1'b0;
    end else begin
        state_r        <= #TP state_nxt;
        pm_state_sts_r <= #TP pm_state_sts_nxt;
        pm_complete_r  <= #TP pm_complete_nxt;
        int_cmd_ack_r  <= #TP int_cmd_ack_nxt;
    end
end

endmodule
