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
// ---    $Author: lnicola $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_dsp_prot_fsm.sv#2 $
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module uses FSM for L1/L23 protocol nogotiation in Downstream
// --- Port. It handle L1/L23 enter and respond to upstream port's L1/L23
// --- negotiation. It is only used in RC or Downstream port of DM/SW. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
`include "products/cx_pl_pkg.svh"

module pm_active_dsp_prot_fsm
  import DWC_pcie_pm_pkg::dsp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::DSP_PROT_RST;
  import DWC_pcie_pm_pkg::DSP_PROT_RECOVERY;
  import DWC_pcie_pm_pkg::DSP_PROT_ACTIVE;
  import DWC_pcie_pm_pkg::DSP_PROT_RESPOND_NAK;
  import DWC_pcie_pm_pkg::DSP_PROT_NAK_BLOCK_TLP;
  import DWC_pcie_pm_pkg::DSP_PROT_WAIT_NAK_TLP_ACK;
  import DWC_pcie_pm_pkg::DSP_PROT_WAIT_NAK_TIMER;
  import DWC_pcie_pm_pkg::DSP_PROT_BLOCK_TLP;
  import DWC_pcie_pm_pkg::DSP_PROT_WAIT_LAST_TLP_ACK;
  import DWC_pcie_pm_pkg::DSP_PROT_WAIT_LAST_PMDLLP;
  import DWC_pcie_pm_pkg::DSP_PROT_ENTER_L1;
  import DWC_pcie_pm_pkg::DSP_PROT_ENTER_L23;
  import DWC_pcie_pm_pkg::DSP_PROT_ENTER_L0S;
  import DWC_pcie_pm_pkg::DSP_PROT_WAIT_CXS_IDLE;
// Parameters
#(
  parameter TP          = `TP
) 
                               (
// Inputs
  input                                 core_clk,                  // Core clock
  input                                 core_rst_n,                // Core reset
  input                                 upstream_port,             // Indicates upstream port in DM/SW
  input                                 spif_enable,               // SPIF Enable
  input                                 pm_dllp_enable,            // Enable DLLP exchange for PM negotiation
  input                                 smlh_link_up,              // LogPHY is in link up
  input                                 latched_entr_l23,          // Latched L23 entry condition
  input                                 link_to_prot_to_active,    // Requests entry to ACTIVE state from RST/RECOVERY
  input                                 link_to_prot_l1_finish,    // Requests exit from L1 state
  input                                 link_to_prot_l23_finish,   // Requests exit from L23 state
  input                                 l0s_l0s_finish,            // Requests exit from L0S state
  input                                 pm_enter_recovery,         // Requests entry to RECOVERY
  input                                 pm_enter_l0s,              // Requests entry to ENTER_L0S state from ACTIVE
  input                                 pm_next_resp_nak,          // Requests entry to RESPOND_NAK state from ACTIVE
  input                                 pm_enter_block_tlp,        // Requests entry to BLOCK_TLP state from ACTIVE
  input                                 pm_block_tlp_ack,          // Block TLP acknowledge, Protocol FSM can move out of BLOCK_TLP
  input                                 pm_last_dllp_ack,          // DSP Protocol FSM: Last PM DLLP acknowledge
  input                                 pm_nak_timer_expire,       // NAK timer expired. For CIO wait for a number of L1 request DLLPs to be dropped.
  input                                 msg_gen_asnak_grt,         // MSGGEN: Indication from msg_gen that PM_Active_State_Nak has been granted
  input                                 xdlh_retry_pending,        // XDLH Retry is pending
// Outputs
  output logic                          dsp_prot_rst,               // DSP Protocol FSM is in RST state
  output logic                          dsp_prot_recovery,          // DSP Protocol FSM is in RECOVERY
  output logic                          dsp_prot_active,            // DSP Protocol FSM is in ACTIVE
  output logic                          dsp_prot_respond_nak,       // DSP Protocol FSM is in RESPOND_NAK
  output logic                          dsp_prot_nak_block_tlp,     // DSP Protocol FSM is in NAK_BLOCK_TLP
  output logic                          dsp_prot_wait_nak_tlp_ack,  // DSP Protocol FSM is in WAIT_NAK_TLP_ACK
  output logic                          dsp_prot_wait_nak_timer,    // DSP Protocol FSM is in WAIT_NAK_TIMER
  output logic                          dsp_prot_block_tlp,         // DSP Protocol FSM is in BLOCK_TLP
  output logic                          dsp_prot_wait_last_tlp_ack, // DSP Protocol FSM is in WAIT_LAST_TLP_ACK
  output logic                          dsp_prot_wait_last_pmdllp,  // DSP Protocol FSM is in WAIT_LAST_PMDLLP
  output logic                          dsp_prot_enter_l1,          // DSP Protocol FSM is in ENTER_L1
  output logic                          dsp_prot_enter_l23,         // DSP Protocol FSM is in ENTER_L23
  output logic                          dsp_prot_enter_l0s          // DSP Protocol FSM is in ENTER_L0S
  ,output dsp_prot_fsm_state_e          pm_dsp_prot_state           // DSP Protocol FSM state
);

// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------

dsp_prot_fsm_state_e dsp_prot_state_r, next_dsp_prot_state_b;

// ----------------------------------------------------------------------------
// Register types
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Wire types
// ----------------------------------------------------------------------------
assign pm_dsp_prot_state = dsp_prot_state_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin : dsp_prot_fsm_sync_PROC
  if(!core_rst_n) begin
    dsp_prot_state_r          <= #TP DSP_PROT_RST;
  end 
  else begin
    if (upstream_port)
      dsp_prot_state_r          <= #TP DSP_PROT_RST;
    else
      dsp_prot_state_r          <= #TP next_dsp_prot_state_b;
  end
end : dsp_prot_fsm_sync_PROC

always_comb begin : dsp_prot_fsm_PROC
  case(dsp_prot_state_r)
    DSP_PROT_RST : begin
      // Go to Active
      if(link_to_prot_to_active)
        next_dsp_prot_state_b = DSP_PROT_ACTIVE;
      else
        next_dsp_prot_state_b = DSP_PROT_RST;
    end
    DSP_PROT_RECOVERY : begin
      // Go to Active
      if(link_to_prot_to_active)
        next_dsp_prot_state_b = DSP_PROT_ACTIVE;
      else
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
    end
    DSP_PROT_ACTIVE : begin
      // Go to Recovery
      if(pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Requirement:  When received DLLP of AS request enter L1,
      // a NAK or ACK has to be immediately scheduled. And the
      // decision made for ACK or NAK has to be maintain. It is not
      // allowed to answer both ACK and NAK for the same L1 request
      // protocol. This change is due to the errata of the PCIE spec.
      // when request enter L1 by ASPM protocol but the entering L1
      // conditions are not met
      else if (pm_next_resp_nak)
        next_dsp_prot_state_b = DSP_PROT_RESPOND_NAK;
      // accept the L1 or L23 enter request
      else if (pm_enter_block_tlp) begin
        next_dsp_prot_state_b = DSP_PROT_BLOCK_TLP;
      end
      // Enter L0s. Assume smlh_in_l0 in active state.
      else if (pm_enter_l0s)
        next_dsp_prot_state_b = DSP_PROT_ENTER_L0S;
      else
        next_dsp_prot_state_b = DSP_PROT_ACTIVE;
    end
    DSP_PROT_RESPOND_NAK : begin
      // Go to Recovery
      if(!smlh_link_up)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Assumption: when the LTSSM is in L0s receiver state, it
      // means that the initiator of ASPM L1 has received the NAK and
      // properly terminated its L1 request protocol
      else if(msg_gen_asnak_grt)
        next_dsp_prot_state_b = DSP_PROT_NAK_BLOCK_TLP;
      else
        next_dsp_prot_state_b = DSP_PROT_RESPOND_NAK;
    end
    DSP_PROT_NAK_BLOCK_TLP : begin
      // Go to Recovery
      if(!smlh_link_up)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Block TLP transmission until the PM_Active_State_Nak has been transmitted
      else if(pm_block_tlp_ack)
        next_dsp_prot_state_b = DSP_PROT_WAIT_NAK_TLP_ACK;
      else
        next_dsp_prot_state_b = DSP_PROT_NAK_BLOCK_TLP;
    end
    DSP_PROT_WAIT_NAK_TLP_ACK : begin
      // Go to Recovery
      if(!smlh_link_up)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Block TLP transmission until the PM_Active_State_Nak has been acknowledged by link partner
      // no TLP being replayed and all TLP's acknowledged
      else if(!xdlh_retry_pending)
        next_dsp_prot_state_b = DSP_PROT_WAIT_NAK_TIMER;
      else
        next_dsp_prot_state_b = DSP_PROT_WAIT_NAK_TLP_ACK;
    end
    DSP_PROT_WAIT_NAK_TIMER : begin
      // Wait for 9.5us timer to expire
      // Included in pm_nak_timer_expire for CIO:
      // wait for a number of L1 req DLLP to be dropped
      if(pm_nak_timer_expire)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      else
        next_dsp_prot_state_b = DSP_PROT_WAIT_NAK_TIMER;
    end
    DSP_PROT_BLOCK_TLP : begin
      // Go to Recovery
      if(pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      else if(pm_block_tlp_ack)
        next_dsp_prot_state_b = DSP_PROT_WAIT_LAST_TLP_ACK;
      else
        next_dsp_prot_state_b = DSP_PROT_BLOCK_TLP;
    end
    DSP_PROT_WAIT_LAST_TLP_ACK : begin
      // Go to Recovery
      if(pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // no TLP being replayed and all TLP's acknowledged
      else if(!xdlh_retry_pending)
        next_dsp_prot_state_b = pm_dllp_enable ? DSP_PROT_WAIT_LAST_PMDLLP : (latched_entr_l23 ? DSP_PROT_ENTER_L23 : DSP_PROT_ENTER_L1);
      else
        next_dsp_prot_state_b = DSP_PROT_WAIT_LAST_TLP_ACK;
    end
    DSP_PROT_WAIT_LAST_PMDLLP : begin
      // Go to Recovery
      if(pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      else if(latched_entr_l23 && pm_last_dllp_ack)
        next_dsp_prot_state_b = DSP_PROT_ENTER_L23;
      else if(pm_last_dllp_ack)
        next_dsp_prot_state_b = DSP_PROT_ENTER_L1;
      else
        next_dsp_prot_state_b = DSP_PROT_WAIT_LAST_PMDLLP;
    end
    DSP_PROT_ENTER_L23 : begin
      // Go to Recovery
      if(pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Go to Active after exit from L23
      else if(link_to_prot_l23_finish)
        next_dsp_prot_state_b = DSP_PROT_ACTIVE;
      else
        next_dsp_prot_state_b = DSP_PROT_ENTER_L23;
    end
    DSP_PROT_ENTER_L1 : begin
      // Go to Recovery
      if (pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Go to Active after exit from L1
      else if(link_to_prot_l1_finish)
        next_dsp_prot_state_b = DSP_PROT_ACTIVE;
      else
        next_dsp_prot_state_b = DSP_PROT_ENTER_L1;
    end
    DSP_PROT_ENTER_L0S : begin
      // Go to Recovery
      if(pm_enter_recovery)
        next_dsp_prot_state_b = DSP_PROT_RECOVERY;
      // Go to Active after exit from L0
      else if(l0s_l0s_finish)
        next_dsp_prot_state_b = DSP_PROT_ACTIVE;
      else
        next_dsp_prot_state_b = DSP_PROT_ENTER_L0S;
    end
    default :
      next_dsp_prot_state_b = DSP_PROT_RST;
  endcase
end : dsp_prot_fsm_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : dsp_prot_fsm_outputs_PROC
  if(!core_rst_n) begin
    dsp_prot_rst                  <= #TP 1'b1;
    dsp_prot_recovery             <= #TP 1'b0;
    dsp_prot_active               <= #TP 1'b0;
    dsp_prot_respond_nak          <= #TP 1'b0;
    dsp_prot_nak_block_tlp        <= #TP 1'b0;
    dsp_prot_wait_nak_tlp_ack     <= #TP 1'b0;
    dsp_prot_wait_nak_timer       <= #TP 1'b0;
    dsp_prot_block_tlp            <= #TP 1'b0;
    dsp_prot_wait_last_tlp_ack    <= #TP 1'b0;
    dsp_prot_wait_last_pmdllp     <= #TP 1'b0;
    dsp_prot_enter_l1             <= #TP 1'b0;
    dsp_prot_enter_l23            <= #TP 1'b0;
    dsp_prot_enter_l0s            <= #TP 1'b0;
  end
  else begin
    dsp_prot_rst                  <= #TP 1'b0;
    dsp_prot_recovery             <= #TP 1'b0;
    dsp_prot_active               <= #TP 1'b0;
    dsp_prot_respond_nak          <= #TP 1'b0;
    dsp_prot_nak_block_tlp        <= #TP 1'b0;
    dsp_prot_wait_nak_tlp_ack     <= #TP 1'b0;
    dsp_prot_wait_nak_timer       <= #TP 1'b0;
    dsp_prot_block_tlp            <= #TP 1'b0;
    dsp_prot_wait_last_tlp_ack    <= #TP 1'b0;
    dsp_prot_wait_last_pmdllp     <= #TP 1'b0;
    dsp_prot_enter_l1             <= #TP 1'b0;
    dsp_prot_enter_l23            <= #TP 1'b0;
    dsp_prot_enter_l0s            <= #TP 1'b0;
    case(next_dsp_prot_state_b)
      DSP_PROT_RST : begin
        dsp_prot_rst                  <= #TP 1'b1;
      end
      DSP_PROT_RECOVERY : begin
        dsp_prot_recovery             <= #TP 1'b1;
      end
      DSP_PROT_ACTIVE : begin
        dsp_prot_active               <= #TP 1'b1;
      end
      DSP_PROT_RESPOND_NAK : begin
        dsp_prot_respond_nak          <= #TP 1'b1;
      end
      DSP_PROT_NAK_BLOCK_TLP : begin
        dsp_prot_nak_block_tlp        <= #TP 1'b1;
      end
      DSP_PROT_WAIT_NAK_TLP_ACK : begin
        dsp_prot_wait_nak_tlp_ack     <= #TP 1'b1;
      end
      DSP_PROT_WAIT_NAK_TIMER : begin
        dsp_prot_wait_nak_timer       <= #TP 1'b1;
      end
      DSP_PROT_BLOCK_TLP : begin
        dsp_prot_block_tlp            <= #TP 1'b1;
      end
      DSP_PROT_WAIT_LAST_TLP_ACK : begin
        dsp_prot_wait_last_tlp_ack    <= #TP 1'b1;
      end
      DSP_PROT_WAIT_LAST_PMDLLP : begin
        dsp_prot_wait_last_pmdllp     <= #TP 1'b1;
      end
      DSP_PROT_ENTER_L1 : begin
        dsp_prot_enter_l1             <= #TP 1'b1;
      end
      DSP_PROT_ENTER_L23 : begin
        dsp_prot_enter_l23            <= #TP 1'b1;
      end
      DSP_PROT_ENTER_L0S : begin
        dsp_prot_enter_l0s            <= #TP 1'b1;
      end
    endcase
  end
end : dsp_prot_fsm_outputs_PROC


endmodule : pm_active_dsp_prot_fsm
