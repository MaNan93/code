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

// -----------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_usp_link_fsm.sv#3 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// ---- This module contains the Upstream Physical Link Control FSM
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"


module pm_active_usp_link_fsm 
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::USP_LINK_RST;
import DWC_pcie_pm_pkg::USP_LINK_RECOVERY;
import DWC_pcie_pm_pkg::USP_LINK_ABORT;
import DWC_pcie_pm_pkg::USP_LINK_L0;
import DWC_pcie_pm_pkg::USP_LINK_PREP_4L1;
import DWC_pcie_pm_pkg::USP_LINK_L1_LINK_ENTR_L1;
import DWC_pcie_pm_pkg::USP_LINK_L1;
import DWC_pcie_pm_pkg::USP_LINK_L1_EXIT;
import DWC_pcie_pm_pkg::USP_LINK_WAIT_DSTATE_UPDATE;
import DWC_pcie_pm_pkg::USP_LINK_PREP_4L23;
import DWC_pcie_pm_pkg::USP_LINK_L23_ENTR_L23;
import DWC_pcie_pm_pkg::USP_LINK_L23RDY;
import DWC_pcie_pm_pkg::USP_LINK_L23RDY_WAIT4ALIVE;
// Parameters
#(
    parameter TP          = `TP
)

                             (

// ---- inputs ---------------
    input                         core_clk,                    // Core clock
    input                         core_rst_n,                  // Core reset
    input                         upstream_port,               // Indicates upstream port in DM/SW
    input                         spif_enable,                 // SPIF is enabled
    input                         smlh_link_up,                // LTSSM is in link up
    input                         smlh_in_l0,                  // LTSSM is in L0
    input                         smlh_in_l1,                  // LTSSM is in L1
    input                         smlh_in_l23,                 // LTSSM is in L23
    input                         prot_to_link_abort_l1,       // Link Layer (Protocol FSM) requests L1 abort (CXL-only)
    input                         prot_to_link_enter_l1,       // Link Layer (Protocol FSM) requests L1 entry
    input                         prot_to_link_enter_l23,      // Link Layer (Protocol FSM) requests L23 entry
    input                         pm_link_entr_l1,             // TOBEREMOVED: PM Protocol FSM (Link Layer) requests ASPM L1 entry
    input                         pm_hold_exit_l1,             // PM Active Controller indication that the controller is not ready for L1 exit
    input                         pm_link_exit_l1,             // PM Active Controller requests L1 exit
    input                         pm_link_exit_l23,            // PM Active Controller requests L23 exit
    input                         software_entr_l1,            // TOBEREMOVED: Ready to start L1 negotiation
    input                         software_entr_l23,           // TOBEREMOVED: PM Turnoff handshake done, ready to start L23 negotiation
    input                         lbc_active,                  // TOBEREMOVED: The LBC may require a CPL to be sent, stop L1 timer
    input                         pm_timeout,                  // TOBEREMOVED: Watchdog timer for USP_LINK_WAIT_DSTATE_UPDATE state of the USP PROT FSM
    input                         int_link_up_not_rcvry,       // indicate PHY link up and LTSSM not in recovery
    input                         int_idle_next,               // FSM returns to RST/RECOVERY state if Recovery or link goes down
// ---- outputs ---------------
    output logic                  usp_link_rst,                // USP Link FSM is in RESET state
    output logic                  usp_link_recovery,           // USP Link FSM is in RECOVERY state
    output logic                  usp_link_l0,                 // USP Link FSM is in L0 state
    output logic                  usp_link_prep_4l1,           // USP Link FSM is in PREPARE_4L1 state
    output logic                  usp_link_l1_link_entr_l1,    // USP Link FSM is in ENTER_L1 state
    output logic                  usp_link_l1,                 // USP Link FSM is in L1 state
    output logic                  usp_link_l1_exit,            // USP Link FSM is in L1_EXIT state
    output logic                  usp_link_prep_4l23,          // USP Link FSM is in PREP_4L23 state
    output logic                  usp_link_l23_entr_l23,       // USP Link FSM is in ENTER_L23 state
    output logic                  usp_link_l23rdy,             // USP Link FSM is in L23RDY state
    output logic                  usp_link_l23rdy_wait4alive,  // TOBEREMOVED: USP Link FSM is in L23RDY_WAIT4ALIVE state
    output logic                  usp_link_wait_dstate_update, // TOBEREMOVED: USP Link FSM is in WAIT_DSTATE_UPDATE state
    output logic                  usp_link_abort,              // USP Link FSM is in L1_ABORT state
    output logic                  usp_link_l1_finish,          // USP Link FSM is on exit from L1
    output logic                  usp_link_l23_finish,         // USP Link FSM is on exit from L23
    output usp_link_fsm_state_e   pm_usp_link_state
);

// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------

usp_link_fsm_state_e usp_link_state_r, next_usp_link_state_b;

// ----------------------------------------------------------------------------
// Register types
// ----------------------------------------------------------------------------
logic int_prev_l1_exit_r;
logic int_prev_l23_r;

// ----------------------------------------------------------------------------
// Wire types
// ----------------------------------------------------------------------------
assign pm_usp_link_state = usp_link_state_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin : usp_link_fsm_sync_PROC
  if(!core_rst_n) begin
    usp_link_state_r      <= #TP USP_LINK_RST;
  end
  else begin
    if (!upstream_port)
      usp_link_state_r      <= #TP USP_LINK_RST;
    else
      usp_link_state_r      <= #TP next_usp_link_state_b;
  end
end : usp_link_fsm_sync_PROC 


always_comb begin : usp_link_fsm_PROC
  case(usp_link_state_r)

    USP_LINK_RST: begin // consider adding warm reset condition.
      if (int_link_up_not_rcvry && smlh_in_l0)
          next_usp_link_state_b = USP_LINK_L0; 
      else  
          next_usp_link_state_b = USP_LINK_RST; 
    end

    USP_LINK_RECOVERY: begin
      if (int_link_up_not_rcvry && smlh_in_l0)
          next_usp_link_state_b =  USP_LINK_L0;
      else
          next_usp_link_state_b =  USP_LINK_RECOVERY;
    end

    USP_LINK_ABORT: begin
      if (int_idle_next)
          next_usp_link_state_b =  USP_LINK_RECOVERY;
      else 
          next_usp_link_state_b =  USP_LINK_ABORT;
    end
    
    USP_LINK_L0: begin
      if (int_idle_next)
          next_usp_link_state_b =  USP_LINK_RECOVERY;
      else if (prot_to_link_enter_l23 & !(usp_link_l1_finish || usp_link_l23_finish ))
          next_usp_link_state_b =  USP_LINK_PREP_4L23; 
      else if (prot_to_link_enter_l1 &  !(usp_link_l1_finish || usp_link_l23_finish ))
          next_usp_link_state_b =  USP_LINK_PREP_4L1;
      else 
          next_usp_link_state_b =  USP_LINK_L0;
    end

    USP_LINK_PREP_4L1: begin
      if (prot_to_link_abort_l1)
          next_usp_link_state_b =  USP_LINK_ABORT;
      else 
          next_usp_link_state_b =  USP_LINK_L1_LINK_ENTR_L1; 
    end
    
    USP_LINK_L1_LINK_ENTR_L1: begin
      if (int_idle_next)
          next_usp_link_state_b =  USP_LINK_RECOVERY; 
      else if (smlh_in_l1)
          next_usp_link_state_b =  USP_LINK_L1; 
      else if (prot_to_link_abort_l1)
          next_usp_link_state_b =  USP_LINK_ABORT; 
      else 
          next_usp_link_state_b =  USP_LINK_L1_LINK_ENTR_L1; 
    end

    USP_LINK_L1: begin
      if (pm_hold_exit_l1)
          next_usp_link_state_b =  USP_LINK_L1;
      else if (!smlh_link_up)
          next_usp_link_state_b =  USP_LINK_RECOVERY; 
      else if (pm_link_exit_l1)
          next_usp_link_state_b =  USP_LINK_L1_EXIT; 
      else 
          next_usp_link_state_b =  USP_LINK_L1; 
    end

    USP_LINK_L1_EXIT: begin
      // If SPIF interface is enable then WAIT_DSTATE_UPDATE is a Protocol FSM state
      if (!pm_link_entr_l1 && smlh_in_l0 && !spif_enable)
          next_usp_link_state_b =  USP_LINK_WAIT_DSTATE_UPDATE; 
      else if (smlh_in_l0)
        // Instead of going to USP_LINK_L0, 
        // go to USP_LINK_RECOVERY to avoid triggering L1 entry again.
        // since prot_to_link_enter_l1 won't be de-asserted until next cycle.
          next_usp_link_state_b =  USP_LINK_RECOVERY; 
      else if (!smlh_link_up)
          next_usp_link_state_b =  USP_LINK_RECOVERY; 
      else 
          next_usp_link_state_b =  USP_LINK_L1_EXIT; 
    end

    USP_LINK_WAIT_DSTATE_UPDATE: begin
      if (software_entr_l23 || (!software_entr_l1 && !lbc_active) || pm_timeout)
        // Instead of going to USP_LINK_L0, 
        // go to USP_LINK_RECOVERY to avoid triggering L1 entry again.
        // since prot_to_link_enter_l1 won't be de-asserted until next cycle.
          next_usp_link_state_b =  USP_LINK_RECOVERY; 
      else
          next_usp_link_state_b =  USP_LINK_WAIT_DSTATE_UPDATE; 
    end

    USP_LINK_PREP_4L23: begin
      next_usp_link_state_b =  USP_LINK_L23_ENTR_L23; 
    end

    USP_LINK_L23_ENTR_L23: begin
      if (int_idle_next)
          next_usp_link_state_b =  USP_LINK_RECOVERY; 
      else if (smlh_in_l23) 
          next_usp_link_state_b =  USP_LINK_L23RDY; 
      else 
          next_usp_link_state_b =  USP_LINK_L23_ENTR_L23; 
    end

    USP_LINK_L23RDY: begin
      if (pm_link_exit_l23)
          next_usp_link_state_b =  USP_LINK_RECOVERY;
      else
          next_usp_link_state_b =  USP_LINK_L23RDY;
    end

    // TBD: This state is not required anymore should be removed
    USP_LINK_L23RDY_WAIT4ALIVE: begin
      next_usp_link_state_b =  USP_LINK_RECOVERY;
    end

    default :
      next_usp_link_state_b = USP_LINK_RST;

  endcase
end : usp_link_fsm_PROC 


always_ff @(posedge core_clk or negedge core_rst_n) begin : usp_link_fsm_output_PROC 
  if(!core_rst_n) begin
    usp_link_rst                  <= #TP 1'b0;
    usp_link_recovery             <= #TP 1'b0;
    usp_link_l0                   <= #TP 1'b0;
    usp_link_prep_4l1             <= #TP 1'b0;
    usp_link_l1_link_entr_l1      <= #TP 1'b0;
    usp_link_l1                   <= #TP 1'b0;
    usp_link_l1_exit              <= #TP 1'b0;
    usp_link_prep_4l23            <= #TP 1'b0;
    usp_link_l23_entr_l23         <= #TP 1'b0;
    usp_link_l23rdy               <= #TP 1'b0;
    usp_link_l23rdy_wait4alive    <= #TP 1'b0;
    usp_link_wait_dstate_update   <= #TP 1'b0;
    usp_link_abort                <= #TP 1'b0;
    usp_link_l1_finish            <= #TP 1'b0;
    usp_link_l23_finish           <= #TP 1'b0;
    int_prev_l1_exit_r            <= #TP 1'b0;
    int_prev_l23_r                <= #TP 1'b0;
  end
  else begin
    usp_link_rst                  <= #TP 1'b0;
    usp_link_recovery             <= #TP 1'b0;
    usp_link_l0                   <= #TP 1'b0;
    usp_link_prep_4l1             <= #TP 1'b0;
    usp_link_l1_link_entr_l1      <= #TP 1'b0;
    usp_link_l1                   <= #TP 1'b0;
    usp_link_l1_exit              <= #TP 1'b0;
    usp_link_prep_4l23            <= #TP 1'b0;
    usp_link_l23_entr_l23         <= #TP 1'b0;
    usp_link_l23rdy               <= #TP 1'b0;
    usp_link_l23rdy_wait4alive    <= #TP 1'b0;
    usp_link_wait_dstate_update   <= #TP 1'b0;
    usp_link_abort                <= #TP 1'b0;
    usp_link_l1_finish            <= #TP 1'b0;
    usp_link_l23_finish           <= #TP 1'b0;

    case(next_usp_link_state_b)

    USP_LINK_RST: begin
      usp_link_rst                  <= #TP 1'b1;
    end

    USP_LINK_RECOVERY: begin
      usp_link_recovery             <= #TP 1'b1;
      if (int_prev_l23_r) begin
        int_prev_l23_r                <= #TP 1'b0;
        usp_link_l23_finish           <= #TP 1'b1;
      end
      if (int_prev_l1_exit_r) begin
        int_prev_l1_exit_r            <= #TP 1'b0;
        usp_link_l1_finish            <= #TP 1'b1;
      end
    end

    USP_LINK_L0: begin
      usp_link_l0                   <= #TP 1'b1;
    end

    USP_LINK_PREP_4L1: begin
      usp_link_prep_4l1             <= #TP 1'b1;
    end

    USP_LINK_L1_LINK_ENTR_L1: begin
      usp_link_l1_link_entr_l1      <= #TP 1'b1;
    end

    USP_LINK_L1: begin
      usp_link_l1                   <= #TP 1'b1;
    end

    USP_LINK_L1_EXIT: begin
      usp_link_l1_exit              <= #TP 1'b1;
      int_prev_l1_exit_r            <= #TP 1'b1;
    end

    USP_LINK_PREP_4L23: begin
      usp_link_prep_4l23            <= #TP 1'b1;
      int_prev_l23_r                <= #TP 1'b1;
    end

    USP_LINK_L23_ENTR_L23: begin
      usp_link_l23_entr_l23         <= #TP 1'b1;
      int_prev_l23_r                <= #TP 1'b1;
    end

    USP_LINK_L23RDY: begin
      usp_link_l23rdy               <= #TP 1'b1;
      int_prev_l23_r                <= #TP 1'b1;
    end

    USP_LINK_L23RDY_WAIT4ALIVE: begin
      usp_link_l23rdy_wait4alive    <= #TP 1'b1;
      int_prev_l23_r                <= #TP 1'b1;
    end

    USP_LINK_WAIT_DSTATE_UPDATE: begin
      usp_link_wait_dstate_update   <= #TP 1'b1;
    end

    USP_LINK_ABORT: begin
      usp_link_abort                <= #TP 1'b1;
    end
    endcase

  end
end : usp_link_fsm_output_PROC 


endmodule  // pm_active_usp_link_fsm 
