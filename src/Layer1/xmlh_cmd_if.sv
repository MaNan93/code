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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_cmd_if.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XMLH CMD IF
//
// Description: This module implements the XMLH Command Interface.
// It receives signals from SMLH and encodes them into commands for the upper layers of the transmitter.
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xmlh_cmd_if
  import cx_pl_pkg::tx_cmd_e;
  import cx_pl_pkg::tx_cmd_struct;
  import cx_pl_pkg::CMD_IDLE;
  import cx_pl_pkg::CMD_FLUSH_XTLH;
  import cx_pl_pkg::CMD_ABANDON_LP;
  import cx_pl_pkg::CMD_PYLD;
  import cx_pl_pkg::CMD_FLUSH_XAIM;
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_RCVRY_LOCK;
  import DWC_pcie_core_pkg::S_RCVRY_SPEED;
  import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
  import DWC_pcie_core_pkg::S_L1_IDLE;
  import DWC_pcie_core_pkg::S_L2_IDLE;
  import DWC_pcie_core_pkg::S_L2_WAKE;
  import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT;
  import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
  import DWC_pcie_core_pkg::S_RCVRY_EQ0;
  import DWC_pcie_core_pkg::S_RCVRY_EQ1;
  import DWC_pcie_core_pkg::S_RCVRY_EQ2;
  import DWC_pcie_core_pkg::S_RCVRY_EQ3;
#(
  parameter TP  = `TP
) (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                 core_clk,
  input                 core_rst_n,
  // -------------------------------------------------------------------------------------
  // SMLH Interface 
  // -------------------------------------------------------------------------------------
  input ltssm_state_e   smlh_ltssm_state,         // LTSSM State
  input                 smlh_link_up,             // LTSSM indicates that the link is up
  input                 smlh_flit_mode_enable,    // Flit mode enabled
  output  logic         xmlh_cmd_if_flush_ack,    // Flush Command Ack
  input                 ltssm_idl_hs_done,        // IDLE Handshake Complete
  input                 lpbk_master,              // LTSSM is loopback master
  input                 smlh_in_l0,               // L0 with no EQ Pending
  // -------------------------------------------------------------------------------------
  // XPLH Interface 
  // -------------------------------------------------------------------------------------
  input                 xplh_xmlh_cmd_ack,        // Command Complete Acknowledge from XPLH
  output  tx_cmd_struct xmlh_cmd_if_cmd,          // Command to XPLH
  // -------------------------------------------------------------------------------------
  // PM Interface 
  // -------------------------------------------------------------------------------------
  input                 pm_xmlh_lp_req,           // PM Request to enter low power
  output  logic         xmlh_cmd_if_lp_ack,       // Acknowledge to PM
  // -------------------------------------------------------------------------------------
  // XMLH Interface 
  // -------------------------------------------------------------------------------------
  output  logic         xmlh_cmd_if_pending       // Packet pending indication for Flit Mode
);

// XMLH Command State
typedef enum logic [4:0] {
  RESET,            // Reset
  PYLD,             // Request Payload Data 
  ENTER_LOW_POWER   // Request Low Power Entry Results in Flush to Application Layer
  ,
  ABANDON_LP,       // Abandon low power entry and return to L0
  LOW_POWER,        // Low Power State
  IDLE,             // Request IDLE generation 
  FLUSH             // Request Flush (recovery entry)
} state_e;

state_e next_state, state_r;

logic int_cmd_ack_r;
logic int_smlh_pre_rcvry_idle;
logic int_flit_mode_r;
logic int_cmd_if_lp_ack;

assign int_smlh_pre_rcvry_idle = ((smlh_ltssm_state == S_RCVRY_LOCK) || (smlh_ltssm_state == S_RCVRY_EQ0) || (smlh_ltssm_state == S_RCVRY_EQ1) || (smlh_ltssm_state == S_RCVRY_EQ2) ||
(smlh_ltssm_state == S_RCVRY_EQ3) || (smlh_ltssm_state == S_RCVRY_RCVRCFG) || (smlh_ltssm_state == S_RCVRY_SPEED) || (smlh_ltssm_state == S_LPBK_EXIT) || (smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT) || (smlh_ltssm_state == S_PRE_DETECT_QUIET));

logic int_idle_to_pyld;

// In Loopback Master wait until RX completes IDLE Handshake
assign int_idle_to_pyld = ((smlh_ltssm_state == S_LPBK_ACTIVE) && lpbk_master) ? ltssm_idl_hs_done : smlh_in_l0;

// Rising edge detect of command acknowledge
always_ff @(posedge core_clk or negedge core_rst_n) begin : cmd_ack_re_PROC
  if(!core_rst_n)
    int_cmd_ack_r <= #TP 1'b0;
  else
    if(next_state != state_r)
      int_cmd_ack_r <= #TP 1'b0;
    else if(xplh_xmlh_cmd_ack)
      int_cmd_ack_r <= #TP 1'b1;
    else
      int_cmd_ack_r <= #TP int_cmd_ack_r;
end : cmd_ack_re_PROC

always_comb begin : cmd_state_PROC 
  next_state = state_r;
  case (state_r)
    // Request IDLE Flit Generation 
    IDLE : begin
      // LTSSM is in L0 and XPLH command acknowledged
      // In Loopback Master when LTSSM is in Loopback.Active begin the sequence number handshake
      if(int_idle_to_pyld && int_cmd_ack_r)
        next_state = PYLD;
    end
    // Request Flush 
    FLUSH : begin
      // Flush Acknowledged and exited Recovery Lock prepare IDLE Flits
      // Hold in Flush State sending NOP Flits if LTSSM is in Loopback.Exit or Loopback.Exit Timeout
      // Expectation is that after Loopback the link will enter Detect and reset
      if(!int_smlh_pre_rcvry_idle && int_cmd_ack_r)
        next_state = IDLE;
    end
    // Low Power State wait to start IDLE Flit Handshake
    LOW_POWER : begin
      if(!(int_smlh_pre_rcvry_idle || ((smlh_ltssm_state == S_L2_IDLE) || (smlh_ltssm_state == S_L2_WAKE) || (smlh_ltssm_state == S_L1_IDLE))))
        next_state = IDLE;
    end
    ABANDON_LP : begin
      if(int_cmd_ack_r)
        next_state = PYLD;
    end
    // Request Payload Flits
    PYLD : begin
      // Request to enter low power state
      if(pm_xmlh_lp_req && int_cmd_ack_r)
        next_state = ENTER_LOW_POWER;
      // Request to enter Recovery or loopback or detect
      else if(smlh_flit_mode_enable && (smlh_ltssm_state == S_RCVRY_LOCK || smlh_ltssm_state == S_LPBK_EXIT || smlh_ltssm_state == S_PRE_DETECT_QUIET) && int_cmd_ack_r)
        next_state = FLUSH;
      else
        next_state = PYLD;
    end
    // Request Low Power Entry
    ENTER_LOW_POWER : begin
      // Low Power Request Acknowledged prepare IDLE Flits on transition to Recovery
      if(smlh_flit_mode_enable && ((smlh_ltssm_state == S_L2_IDLE) || (smlh_ltssm_state == S_L1_IDLE)) && int_cmd_ack_r)
        next_state = LOW_POWER;
      // Abandon low power entry to return to L0
      else if(smlh_flit_mode_enable && !pm_xmlh_lp_req && int_cmd_ack_r && smlh_in_l0)
        next_state = ABANDON_LP;
      // Abandon low power entry to go to recovery
      else if(smlh_flit_mode_enable && !pm_xmlh_lp_req && int_cmd_ack_r)
        next_state = FLUSH;
      else if(!smlh_flit_mode_enable && (smlh_ltssm_state == S_RCVRY_LOCK) && int_cmd_ack_r)
        next_state = RESET;
    end
    default : begin
      if(smlh_flit_mode_enable)
        next_state = IDLE;
    end
  endcase
end : cmd_state_PROC

always_comb begin : cmd_out_PROC
  xmlh_cmd_if_cmd = '0;
  xmlh_cmd_if_cmd.flit_mode = int_flit_mode_r;
  case(state_r)
    IDLE      : begin
      xmlh_cmd_if_cmd.tx_cmd = CMD_IDLE;
      if(int_cmd_ack_r)
        xmlh_cmd_if_cmd.req = 1'b0;
      else
        xmlh_cmd_if_cmd.req = 1'b1;
    end
    FLUSH     : begin 
      xmlh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XTLH;
      if(int_cmd_ack_r)
        xmlh_cmd_if_cmd.req = 1'b0;
      else
        xmlh_cmd_if_cmd.req = 1'b1;
    end
    LOW_POWER : begin
      xmlh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XAIM;
      xmlh_cmd_if_cmd.req = 1'b0;
    end
    ABANDON_LP : begin
      xmlh_cmd_if_cmd.tx_cmd = CMD_ABANDON_LP;
      if(int_cmd_ack_r)
        xmlh_cmd_if_cmd.req = 1'b0;
      else
        xmlh_cmd_if_cmd.req = 1'b1;
    end
    PYLD      : begin 
      xmlh_cmd_if_cmd.tx_cmd = CMD_PYLD;
      if(int_cmd_ack_r)
        xmlh_cmd_if_cmd.req = 1'b0;
      else
        xmlh_cmd_if_cmd.req = 1'b1;
    end
    ENTER_LOW_POWER : begin 
      xmlh_cmd_if_cmd.tx_cmd = CMD_FLUSH_XAIM;
      if(int_cmd_ack_r)
        xmlh_cmd_if_cmd.req = 1'b0;
      else
        xmlh_cmd_if_cmd.req = 1'b1;
    end
    default   : begin 
      xmlh_cmd_if_cmd = '0;
      xmlh_cmd_if_cmd.flit_mode = int_flit_mode_r;
    end
  endcase
end : cmd_out_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : cmd_sync_PROC
  if(!core_rst_n) begin
    state_r           <= #TP RESET;
    int_flit_mode_r   <= #TP '0;
  end else begin
    int_flit_mode_r   <= #TP smlh_flit_mode_enable;
    // Reset if link goes down
    if(!smlh_link_up && !(smlh_ltssm_state == S_LPBK_ACTIVE))
      state_r         <= #TP RESET;
    else
      state_r         <= #TP next_state;
  end
end : cmd_sync_PROC

assign int_cmd_if_lp_ack     = ((state_r == ENTER_LOW_POWER) && int_cmd_ack_r) || !smlh_flit_mode_enable;

always_ff @(posedge core_clk or negedge core_rst_n) begin : lp_ack_PROC
  if(!core_rst_n)
    xmlh_cmd_if_lp_ack  <= #TP '0;
  else
    xmlh_cmd_if_lp_ack  <= #TP int_cmd_if_lp_ack;
end : lp_ack_PROC

assign xmlh_cmd_if_flush_ack  = (state_r inside {IDLE, FLUSH}) && int_cmd_ack_r;
assign xmlh_cmd_if_pending    = (state_r == PYLD) || ((state_r == FLUSH) && !xmlh_cmd_if_flush_ack);

endmodule
