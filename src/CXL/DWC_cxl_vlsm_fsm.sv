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
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #11 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_vlsm_fsm.sv#11 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This is the resolved VLSM which provides an interface between the link VLSM's
// and the LTSSM.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"

module DWC_cxl_vlsm_fsm
  import spif_pkg::*;                                          // Import SPIF package
#(
  parameter  TP            = `TP
) 
                         (
  // Inputs
  input                                core_clk,
  input                                core_rst_n,
  input                                pcie_mode_enable,       // PCIe Mode is enabled
  input                                cxl_mode_enable,        // CXL Mode is enabled
  input                                vlsm_pl_rx_active_req,  // Physical Layer asserts this signal to request the Link Layer to open its
  input                                vlsm_pl_stall_req,      // Physical Layer to Link Layer request to flush all packets
  input  state_enc_e                   vlsm_pl_state_sts,      // Physical Layer to Link Layer state status
  input                                vlsm_pl_phyinretrain,   // Physical Layer is in Retrain
  input                                almp_rx_repl_error,     // ALMP replication error, must request link retrain
  input  state_enc_e                   vlsm_io_lp_state_req,   // CXL.io vLSM State Request
  input                                vlsm_io_active_req,     // CXL.io VLSM Active Request
  input                                vlsm_mc_active_req,     // CXL.mem/cache VLSM Active Request
  input                                vlsm_io_retrain_req,    // CXL.io VLSM Retrain Request
  input                                vlsm_mc_retrain_req,    // CXL.mem/cache VLSM Retrain Request
  input                                vlsm_io_disable_req,    // CXL.io VLSM Link Disable Request
  input                                vlsm_mc_disable_req,    // CXL.mem/cache VLSM Link Disable Request
  input                                vlsm_io_linkreset_req,  // CXL.io VLSM Link Reset Request
  input                                vlsm_mc_linkreset_req,  // CXL.mem/CXL.cache VLSM Link Reset Request
  input  state_enc_e                   vlsm_io_link_state,     // CXL.io VLSM Link State
  input  state_enc_e                   vlsm_mc_link_state,     // CXL.cache/mem VLSM Link State
  input                                vlsm_io_linkerror,      // CXL.io Link Layer Error
  input                                vlsm_mc_linkerror,      // CXL.cachemem Link Layer Error
  input                                vlsm_io_wake_req,       // CXL.io Link Layer Wakeup Request
  input                                vlsm_mc_wake_req,       // CXL.cachemem Link Layer Wakeup Request
  input                                vlsm_io_clk_ack,        // CXL.io Link Layer Clock Acknowledgement
  input                                vlsm_mc_clk_ack,        // CXL.cachemem Link Layer Clock Acknowledgement
  input                                vlsm_io_rx_active_sts,  // CXL.io RX activation status acknowledgement
  input                                vlsm_mc_rx_active_sts,  // CXL.cachemem RX activation status acknowledgement
  input                                vlsm_io_dl_active,      // CXL.io Link Layer activation status
  input                                vlsm_mc_dl_active,      // CXL.cachemem Link Layer activation status
  input                                vlsm_io_stall_ack,      // CXL.io stall acknowledgement
  input                                vlsm_mc_stall_ack,      // CXL.cachemem stall acknowledgement
  input                                vlsm_arbmux_stall_ack,  // ARB/MUX stall acknowledgement
  // Outputs
  output logic                         vlsm_arbmux_stall_req,  // ARB/MUX stall request
  output logic                         vlsm_lp_linkerror,      // Link Layer to Packet Layer indication of fatal error that requires link down or link disable
  output logic                         vlsm_lp_wake_req,       // Wakeup request
  output logic                         vlsm_lp_clk_ack,        // Clock acknowledgement
  output logic                         vlsm_lp_dl_active,      // DL Active
  output logic                         vlsm_lp_rx_active_sts,  // Link Layer responds to pl_rx_active_req after it is ready to receive and parse protocol data or Flits.
  output logic                         vlsm_lp_stall_ack,      // Link Layer to Physical Layer stall request acknowledge
  output state_enc_e                   vlsm_lp_state_req,      // Link Layer to Physical Layer state change request
  output logic                         ltssm_in_training,      // Physical Link is in RCVRY state
  output logic                         ltssm_in_l0,            // Physical Link is in L0 state
  output logic                         vlsm_state_l1,          // vLSM FSM is in L1 state
  output logic                         vlsm_state_l2,          // vLSM FSM is in L2 state
  output logic                         vlsm_ltssm_enable       // Enable core_rst_n assertion
);

// Local declarations
state_enc_e   vlsm_state_req_s;
logic         link_pm_exit_req_r, link_pm_exit_req_nxt;
logic         link_retrain_req_s;
logic         link_retrain_req_r, link_retrain_req_nxt;

// ----------------------------------------------------------------------------
// CXL Reset Controller
//
// This block delays core_rst_n assertion after Hot Reset (Link Down) until CXL Controller
// deactivation is complete
// ----------------------------------------------------------------------------
// For graceful reset during link down event (LINKERROR), wait for the receive datapath deactivation before allowing reset propagation
logic  vlsm_gracerst_rdy;
assign vlsm_gracerst_rdy = ((vlsm_io_link_state == LINKERROR) ? !vlsm_io_rx_active_sts : 1'b1) && ((vlsm_mc_link_state == LINKERROR) ? !vlsm_mc_rx_active_sts : 1'b1);

assign vlsm_ltssm_enable = ((vlsm_io_link_state == RESET) && (vlsm_mc_link_state == RESET)) ? 1'b1 : vlsm_gracerst_rdy;
// ----------------------------------------------------------------------------

assign ltssm_in_training = (vlsm_pl_state_sts == RETRAIN);
assign ltssm_in_l0       = (vlsm_pl_state_sts == ACTIVE);

// ----------------------------------------------------------------------------
// Link retrain request handshake in case of almp_rx_repl_error
// ----------------------------------------------------------------------------
assign link_retrain_req_s = vlsm_io_retrain_req || vlsm_mc_retrain_req || almp_rx_repl_error;

always_comb begin
    // Set when link_retrain_req_s is asserted and there is no retrain request in progress
    if (link_retrain_req_s && !vlsm_pl_phyinretrain)
        link_retrain_req_nxt = 1'b1;
    // Clear when the retrain request is accepted by LTSSM and it transitions to the Recovery
    else if (link_retrain_req_r && vlsm_pl_phyinretrain)
        link_retrain_req_nxt = 1'b0;
    else
        link_retrain_req_nxt = link_retrain_req_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
       link_retrain_req_r <= #TP 1'b0;
    end else begin
       link_retrain_req_r <= #TP link_retrain_req_nxt;
    end
end
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Link Layer requests the physical layer exit from PM state (Phase 3)
// ----------------------------------------------------------------------------
always_comb begin
    // If Physical Layer is in PM state and either CXL.cachemem or CXL.io Link Layer requests exit from PM
    if ((vlsm_pl_state_sts inside {IDLE_L1_1, L2}) && (vlsm_io_active_req || vlsm_mc_active_req))
        link_pm_exit_req_nxt = 1'b1;
    // Stop requesting PM exit when Link Layer that was requesting PM exit returns to ACTIVE state
    else if (vlsm_state_req_s == ACTIVE)
        link_pm_exit_req_nxt = 1'b0;
    else
        link_pm_exit_req_nxt = link_pm_exit_req_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
       link_pm_exit_req_r <= #TP 1'b0;
    end else begin
       link_pm_exit_req_r <= #TP link_pm_exit_req_nxt;
    end
end
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// VLSM Control/Status Outputs
// ----------------------------------------------------------------------------
logic  lp_rx_active_sts_r;
logic  lp_dl_active_r;

assign vlsm_lp_linkerror     = vlsm_io_linkerror || vlsm_mc_linkerror;
assign vlsm_lp_wake_req      = vlsm_io_wake_req || vlsm_mc_wake_req;
assign vlsm_lp_clk_ack       = vlsm_io_clk_ack && vlsm_mc_clk_ack;
assign vlsm_lp_rx_active_sts = lp_rx_active_sts_r;
assign vlsm_lp_dl_active     = lp_dl_active_r;
assign vlsm_lp_stall_ack     = vlsm_arbmux_stall_ack;

assign vlsm_arbmux_stall_req = vlsm_pl_stall_req && vlsm_io_stall_ack && vlsm_mc_stall_ack;

always_comb begin
    if (vlsm_io_disable_req || vlsm_mc_disable_req)
        vlsm_lp_state_req = DISABLED;
    else if (vlsm_io_linkreset_req || vlsm_mc_linkreset_req)
        vlsm_lp_state_req = LINKRESET;
    else if (link_retrain_req_r)
        vlsm_lp_state_req = RETRAIN;
    else if (ltssm_in_training || link_pm_exit_req_r)
        vlsm_lp_state_req = ACTIVE;
    else if (cxl_mode_enable)
        vlsm_lp_state_req = vlsm_state_req_s;
    else if (pcie_mode_enable)
        vlsm_lp_state_req = vlsm_io_lp_state_req;
    else
        vlsm_lp_state_req = RESET;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
       lp_rx_active_sts_r <= #TP 1'b0;
       lp_dl_active_r     <= #TP 1'b0;
    end else begin
       // Reflect back RX activation request as an acknowledge
       lp_rx_active_sts_r <= #TP vlsm_pl_rx_active_req;
       // If either CXL.io or CXL.cachemem link initialization is complete then
       // reflect DL Active to the LogPHY.
       //
       // TBD: review implementation from the general rule perspective which requires
       // that link cannot operate for any other protocols if CXL.io protocol is down
       lp_dl_active_r     <= #TP vlsm_io_dl_active || vlsm_mc_dl_active;
    end
end

assign vlsm_state_l1         = vlsm_lp_state_req == IDLE_L1_1;
assign vlsm_state_l2         = vlsm_lp_state_req == L2;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// ARB/MUX Multiple Virtual LSM Resolution Table
// ----------------------------------------------------------------------------
//
// ------------------------------------------------------
// |          | Reset    | Active  | L1.0    | SLEEP_L2 |
// |----------|----------|---------|---------|----------|
// | Reset    | RESET    | Active  | L1.0    | SLEEP_L2 |
// | Active   | Active   | Active  | Active  | Active   |
// | L1.0     | L1.0     | Active  | L1.0    | L1.0     |
// | SLEEP_L2 | SLEEP_L2 | Active  | L1.0    | SLEEP_L2 |
// ------------------------------------------------------
//
// ----------------------------------------------------------------------------
always_comb begin
    if ((vlsm_io_link_state == RESET) && (vlsm_mc_link_state == RESET)) begin
        vlsm_state_req_s = RESET;
    end
    else if ((vlsm_io_link_state == ACTIVE) || (vlsm_mc_link_state == ACTIVE) || (vlsm_mc_link_state == ACTIVE_L0S_PMNAK) || (vlsm_io_link_state == ACTIVE_L0S_PMNAK)) begin
        vlsm_state_req_s = ACTIVE;
    end
    else if ((vlsm_io_link_state == RETRAIN) || (vlsm_mc_link_state == RETRAIN)) begin
        vlsm_state_req_s = ACTIVE;
    end
    else if ((vlsm_io_link_state == IDLE_L1_1) && !(vlsm_mc_link_state == ACTIVE) && !(vlsm_mc_link_state == ACTIVE_L0S_PMNAK)) begin
        vlsm_state_req_s = IDLE_L1_1;
    end
    else if ((vlsm_mc_link_state == IDLE_L1_1) && !(vlsm_io_link_state == ACTIVE) && !(vlsm_io_link_state == ACTIVE_L0S_PMNAK) ) begin
        vlsm_state_req_s = IDLE_L1_1;
    end
    else if ((vlsm_io_link_state == L2) && ((vlsm_mc_link_state == RESET) || (vlsm_mc_link_state == L2))) begin
        vlsm_state_req_s = L2;
    end
    else if ((vlsm_mc_link_state == L2) && ((vlsm_io_link_state == RESET) || (vlsm_io_link_state == L2))) begin
        vlsm_state_req_s = L2;
    end
    else begin
        vlsm_state_req_s = RESET;
    end
end
// ----------------------------------------------------------------------------

endmodule
