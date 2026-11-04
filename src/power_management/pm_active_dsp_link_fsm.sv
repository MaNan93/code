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
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_dsp_link_fsm.sv#2 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module uses FSM for link control in Downstream Port.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"

module pm_active_dsp_link_fsm
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_pm_pkg::DSP_LINK_RST;
import DWC_pcie_pm_pkg::DSP_LINK_RECOVERY;
import DWC_pcie_pm_pkg::DSP_LINK_L0;
import DWC_pcie_pm_pkg::DSP_LINK_ACK_WAIT4IDLE;
import DWC_pcie_pm_pkg::DSP_LINK_ENTR_L23;
import DWC_pcie_pm_pkg::DSP_LINK_L23RDY;
import DWC_pcie_pm_pkg::DSP_LINK_L23RDY_WAIT4ALIVE;
import DWC_pcie_pm_pkg::DSP_LINK_ENTR_L1;
import DWC_pcie_pm_pkg::DSP_LINK_L1;
import DWC_pcie_pm_pkg::DSP_LINK_L1_EXIT;
import DWC_pcie_pm_pkg::DSP_LINK_ABORT;
// Parameters
#(
   parameter TP          = `TP
)

                             (
// Inputs
    input                         core_clk,                    // Core clock
    input                         core_rst_n,                  // Core reset
    input                         upstream_port,               // Indicates upstream port in DM/SW
    input                         smlh_link_up,                // LTSSM is in link up
    input                         smlh_in_l0,                  // LTSSM is in L0
    input                         smlh_in_l1,                  // LTSSM is in L1
    input                         smlh_in_l23,                 // LTSSM is in L23
    input                         smlh_l123_eidle_timeout,     // LTSSM 2ms Timer Timed out while waiting for EIDLE
    input                         latched_rcvd_eidle_set,      // LTSSM latched received eidle ordered set indication from RMLH
    input                         prot_to_link_abort_l1,       // Link Layer (Protocol FSM) requests L1 abort (CXL-only)
    input                         prot_to_link_enter_l1,       // Link Layer (Protocol FSM) requests L1 entry
    input                         prot_to_link_enter_l23,      // Link Layer (Protocol FSM) requests L23 entry
    input                         pm_hold_exit_l1,             // PM Active Controller indication that the controller is not ready for L1 exit
    input                         pm_link_exit_l1,             // PM Active Controller requests L1 exit
    input                         pm_link_entr_l23,            // Link Layer (PM Protocol) FSM requests L1 entry
    input                         pm_link_exit_l23,            // PM Active Controller requests L23 exit
    input                         int_link_up_not_rcvry,       //
    input                         int_idle_next,               // 
// Outputs
    output logic                  dsp_link_rst,                // DSP Link FSM is in RESET state
    output logic                  dsp_link_recovery,           // DSP Link FSM is in RECOVERY state
    output logic                  dsp_link_l0,                 // DSP Link FSM is in L0 state
    output logic                  dsp_link_ack_wait4idle,      // DSP Link FSM is in ACK_WAIT4IDLE state
    output logic                  dsp_link_abort,              // DSP Link FSM is in ABORT state
    output logic                  dsp_link_enter_l23,          // DSP Link FSM is in ENTER_L23 state
    output logic                  dsp_link_l23rdy,             // DSP Link FSM is in L23RDY state
    output logic                  dsp_link_l23rdy_wait4alive,  // TOBEREMOVED: DSP Link FSM is in L23RDY_WAIT4ALIVE state
    output logic                  dsp_link_entr_l1,            // DSP Link FSM is in ENTER_L1 state
    output logic                  dsp_link_l1,                 // DSP Link FSM is in L1 state
    output logic                  dsp_link_l1_exit,            // DSP Link FSM is in L1_EXIT state
    output logic                  dsp_link_l1_finish,          // DSP Link FSM is on exit from L1
    output logic                  dsp_link_l23_finish,         // DSP Link FSM is on exit from L23
    output dsp_link_fsm_state_e   pm_dsp_link_state            // DSP Link FSM state
);

// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------

dsp_link_fsm_state_e dsp_link_state_r, next_dsp_link_state_b;

// ----------------------------------------------------------------------------
// Register types
// ----------------------------------------------------------------------------
logic int_prev_l1_exit; //
logic int_prev_l23; //

// ----------------------------------------------------------------------------
// Wire types
// ----------------------------------------------------------------------------
assign pm_dsp_link_state = dsp_link_state_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin : dsp_link_fsm_sync_PROC
  if(!core_rst_n) begin
    dsp_link_state_r          <= #TP DSP_LINK_RST;
  end
  else begin
    if (upstream_port)
      dsp_link_state_r          <= #TP DSP_LINK_RST;
    else
      dsp_link_state_r          <= #TP next_dsp_link_state_b;
  end
end : dsp_link_fsm_sync_PROC

always_comb begin : dsp_link_fsm_PROC
  case(dsp_link_state_r)
    DSP_LINK_RST : begin
      // Go to Active
      if(int_link_up_not_rcvry)
        next_dsp_link_state_b = DSP_LINK_L0;
      else
        next_dsp_link_state_b = DSP_LINK_RST;
    end
    DSP_LINK_RECOVERY : begin
      // Go to Active
      if(int_link_up_not_rcvry)
        next_dsp_link_state_b = DSP_LINK_L0;
      else
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
    end
    DSP_LINK_L0 : begin
      // If LTSSM enters Recovery the FSM transitions back to recovery
      if(int_idle_next)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      // Trigger LTSSM to go to EIdle
        // we need to consider the case that phy is not reporting
        // rxelectric idle, so that we need to enter L1 state.
        // Here smlh_in_l1 is asserted in the condition for this
        // purposes. Note there is no check that the PM_Request_Ack DLLP
        // has been sent since we will proceed to low power state anyway
        // once electrical idle is detected
      else if ( (prot_to_link_enter_l1 || prot_to_link_enter_l23)
                & !(dsp_link_l1_finish || dsp_link_l23_finish) )
        next_dsp_link_state_b = DSP_LINK_ACK_WAIT4IDLE;
      else
        next_dsp_link_state_b = DSP_LINK_L0;
    end
    DSP_LINK_ACK_WAIT4IDLE : begin
      // If LTSSM enters Recovery the FSM transitions back to recovery
      if(int_idle_next)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      // Trigger LTSSM recovery if the L1 enter condition is not valid
      // Or there is condition to abort L1 entery.
      else if(!pm_link_entr_l23 && prot_to_link_abort_l1)
        next_dsp_link_state_b = DSP_LINK_L0;//DSP_LINK_ABORT;
      // Enter L23 when EIdle is set
      else if(pm_link_entr_l23 && (latched_rcvd_eidle_set || smlh_l123_eidle_timeout))
        next_dsp_link_state_b = DSP_LINK_ENTR_L23;
      // Enter L1 when EIdle is set
      else if(latched_rcvd_eidle_set || smlh_l123_eidle_timeout)
        next_dsp_link_state_b = DSP_LINK_ENTR_L1;
      else
        next_dsp_link_state_b = DSP_LINK_ACK_WAIT4IDLE;
    end
    // AI: Henry to review. LINK_ABORT state is redundant for Downstream Port, should be removed.
    DSP_LINK_ABORT : begin
      // If LTSSM enters Recovery the FSM transitions back to recovery
      if(int_idle_next)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      else
        next_dsp_link_state_b = DSP_LINK_ABORT;
    end
    DSP_LINK_ENTR_L23 : begin
      // If LTSSM enters Recovery the FSM transitions back to recovery
      if(int_idle_next)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      else if(smlh_in_l23)
        next_dsp_link_state_b = DSP_LINK_L23RDY;
      else
        next_dsp_link_state_b = DSP_LINK_ENTR_L23;
    end
    DSP_LINK_L23RDY : begin
      if (pm_link_exit_l23)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      else
        next_dsp_link_state_b = DSP_LINK_L23RDY;
    end
    // TBD: This state is not required anymore, should be removed
    DSP_LINK_L23RDY_WAIT4ALIVE : begin
      next_dsp_link_state_b = DSP_LINK_RECOVERY;
    end
    DSP_LINK_ENTR_L1 : begin
      // If LTSSM enters Recovery the FSM transitions back to recovery
      if(int_idle_next)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      else if(smlh_in_l1)
        next_dsp_link_state_b = DSP_LINK_L1;
      else
        next_dsp_link_state_b = DSP_LINK_ENTR_L1;
    end
    DSP_LINK_L1 : begin
      // keep the LINK FSM into L1 until l1sub_state == L1_U
      if(pm_hold_exit_l1)
        next_dsp_link_state_b = DSP_LINK_L1;
      else if(!smlh_link_up)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      // when there is a tlp pending for transimission or received detect the exit of elecidle
      else if(pm_link_exit_l1)
        next_dsp_link_state_b = DSP_LINK_L1_EXIT;
      else
        next_dsp_link_state_b = DSP_LINK_L1;
    end
    DSP_LINK_L1_EXIT : begin
      if(smlh_in_l0 || !smlh_link_up)
        next_dsp_link_state_b = DSP_LINK_RECOVERY;
      else
        next_dsp_link_state_b = DSP_LINK_L1_EXIT;
    end
    default :
      next_dsp_link_state_b = DSP_LINK_RST;
  endcase
end : dsp_link_fsm_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : dsp_link_fsm_outputs_PROC
  if(!core_rst_n) begin
    dsp_link_rst                  <= #TP 1'b1;
    dsp_link_recovery             <= #TP 1'b0;
    dsp_link_l0                   <= #TP 1'b0;
    dsp_link_ack_wait4idle        <= #TP 1'b0;
    dsp_link_abort                <= #TP 1'b0;
    dsp_link_enter_l23            <= #TP 1'b0;
    dsp_link_l23rdy               <= #TP 1'b0;
    dsp_link_l23rdy_wait4alive    <= #TP 1'b0;
    dsp_link_entr_l1              <= #TP 1'b0;
    dsp_link_l1                   <= #TP 1'b0;
    dsp_link_l1_exit              <= #TP 1'b0;
    dsp_link_l1_finish            <= #TP 1'b0;
    dsp_link_l23_finish           <= #TP 1'b0;
    int_prev_l1_exit              <= #TP 1'b0;
    int_prev_l23                  <= #TP 1'b0;
  end
  else begin
    dsp_link_rst                  <= #TP 1'b0;
    dsp_link_recovery             <= #TP 1'b0;
    dsp_link_l0                   <= #TP 1'b0;
    dsp_link_ack_wait4idle        <= #TP 1'b0;
    dsp_link_abort                <= #TP 1'b0;
    dsp_link_enter_l23            <= #TP 1'b0;
    dsp_link_l23rdy               <= #TP 1'b0;
    dsp_link_l23rdy_wait4alive    <= #TP 1'b0;
    dsp_link_entr_l1              <= #TP 1'b0;
    dsp_link_l1                   <= #TP 1'b0;
    dsp_link_l1_exit              <= #TP 1'b0;
    dsp_link_l1_finish            <= #TP 1'b0;
    dsp_link_l23_finish           <= #TP 1'b0;
    case(next_dsp_link_state_b)
      DSP_LINK_RST : begin
        dsp_link_rst                  <= #TP 1'b1;
      end
      DSP_LINK_RECOVERY : begin
        dsp_link_recovery             <= #TP 1'b1;
        if (int_prev_l23) begin
          int_prev_l23                <= #TP 1'b0;
          dsp_link_l23_finish         <= #TP 1'b1;
        end
      end
      DSP_LINK_L0 : begin
        dsp_link_l0                   <= #TP 1'b1;
        if (int_prev_l1_exit) begin
          int_prev_l1_exit              <= #TP 1'b0;
          dsp_link_l1_finish            <= #TP 1'b1;
        end
      end
      DSP_LINK_ACK_WAIT4IDLE : begin
        dsp_link_ack_wait4idle        <= #TP 1'b1;
      end
      DSP_LINK_ABORT : begin
        dsp_link_abort                <= #TP 1'b1;
      end
      DSP_LINK_ENTR_L23 : begin
        dsp_link_enter_l23            <= #TP 1'b1;
        int_prev_l23                  <= #TP 1'b1;
      end
      DSP_LINK_L23RDY : begin
        dsp_link_l23rdy               <= #TP 1'b1;
        int_prev_l23                  <= #TP 1'b1;
      end
      DSP_LINK_L23RDY_WAIT4ALIVE : begin
        dsp_link_l23rdy_wait4alive    <= #TP 1'b1;
        int_prev_l23                  <= #TP 1'b1;
      end
      DSP_LINK_ENTR_L1 : begin
        dsp_link_entr_l1              <= #TP 1'b1;
      end
      DSP_LINK_L1 : begin
        dsp_link_l1                   <= #TP 1'b1;
      end
      DSP_LINK_L1_EXIT : begin
        dsp_link_l1_exit              <= #TP 1'b1;
        int_prev_l1_exit              <= #TP 1'b1;
      end
    endcase
  end
end : dsp_link_fsm_outputs_PROC

endmodule : pm_active_dsp_link_fsm
