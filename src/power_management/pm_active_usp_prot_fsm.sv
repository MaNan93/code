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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_usp_prot_fsm.sv#2 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// ---- This module contains the Upstream Port PM Protocol FSM
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"


module pm_active_usp_prot_fsm 
  import DWC_pcie_pm_pkg::usp_prot_fsm_state_e;
  import DWC_pcie_pm_pkg::USP_PROT_RST;
  import DWC_pcie_pm_pkg::USP_PROT_RECOVERY;
  import DWC_pcie_pm_pkg::USP_PROT_ACTIVE;
  import DWC_pcie_pm_pkg::USP_PROT_ENTER_L0S;
  import DWC_pcie_pm_pkg::USP_PROT_ENTER_L1;
  import DWC_pcie_pm_pkg::USP_PROT_L1_BLOCK_TLP;
  import DWC_pcie_pm_pkg::USP_PROT_L1_WAIT_LAST_TLP_ACK;
  import DWC_pcie_pm_pkg::USP_PROT_L1_WAIT_PMDLLP_ACK;
  import DWC_pcie_pm_pkg::USP_PROT_ENTER_L23;
  import DWC_pcie_pm_pkg::USP_PROT_L23_BLOCK_TLP;
  import DWC_pcie_pm_pkg::USP_PROT_L23_WAIT_LAST_TLP_ACK;
  import DWC_pcie_pm_pkg::USP_PROT_L23_WAIT_PMDLLP_ACK;
  import DWC_pcie_pm_pkg::USP_PROT_WAIT_PMCSR_CPL_SENT;
  import DWC_pcie_pm_pkg::USP_PROT_WAIT_LAST_PMDLLP;
  import DWC_pcie_pm_pkg::USP_PROT_WAIT_CXS_IDLE;
  import DWC_pcie_pm_pkg::USP_PROT_WAIT_DSTATE_UPDATE;
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::NOP_DLLP;
// Parameters
#(
  parameter TP          = `TP,
  parameter NVC         = `CX_NVC
) 
                               (
// ---- inputs ---------------
  input                                core_clk,                       // Core clock
  input                                core_rst_n,                     // Core reset
  input                                upstream_port,                  // indicate upstream port
  input                                pm_dllp_enable,                 // Enable DLLP exchange for PM negotiation
  input                                smlh_link_up,                   // PHY link up
  input                                link_to_prot_to_active,         // Requests entry to ACTIVE state from RST/RECOVERY
  input                                link_to_prot_l1_finish,         // Requests exit from L1 state
  input                                link_to_prot_l23_finish,        // Requests exit from L23 state
  input                                l0s_l0s_finish,                 // Requests exit from L0S state
  input                                software_entr_l23,              // start l23 negotiation 
  input                                int_start_l1_nego,              // start L1 negotiation
  input                                pm_enter_recovery,              // Requests entry to RECOVERY
  input                                pm_enter_l0s,                   // Requests entry to ENTER_L0S state from ACTIVE
  input                                pm_block_tlp_ack ,              // Block TLP acknowledge, Protocol FSM can move out of BLOCK_TLP
  input                                pm_l2_entry_flag,               // PM_Turnoff message has been received so L2 negotiation should start
  input                                pm_l23_entry_flag,              // L23 Ready entry flag
  input                                pm_l1_pcipm_hs_done,            // PM_Enter_L1 requested by PM block and sent by XDLH
  input                                pm_l1_aspm_hs_done,             // PM_Active_State_Request_L1 requested by PM block and sent by XDLH
  input                                pm_l23_hs_done,                 // PM_Enter_L23 requested by PM block and sent by XDLH
  input                                pm_csr_cpl_sent,                // CSR Completion sent, move to BLOCK_TLP from WAIT_PMCSR_CPL_SENT
  input  dllp_struct                   pm_dllp_ack,                    // XDLH PM DLLP (NOP) acknowledge
  input                                pm_link_wait_dstate_update,     // TOBEREMOVED: USP Link FSM is in WAIT_DSTATE_UPDATE state
  input                                pm_entr_dstate_update,          // USP Protocol FSM to enter into WAIT_DSTATE_UPDATE state
  input                                pm_exit_dstate_update,          // USP Protocol FSM to exit from WAIT_DSTATE_UPDATE state
  input                                latch_as_entr_l1,               // PM Protocol FSM indication of ASPM enter L1
  input                                radm_pm_asnak,                  // RADM PM_Active_State_Nak received
  input                                xdlh_retry_pending,             // TLP pending for replay in Layer2 transmit path
  input  [NVC-1:0]                     xtlh_had_enough_credit,         // XTLH had enough credit
  input                                rdlh_rcvd_pm_req_ack,           // RDLH received PM_REQ_ACK
// ---- outputs ---------------      
  output logic                         usp_prot_rst,                   // USP Protocol FSM is in RESET state
  output logic                         usp_prot_recovery,              // USP Protocol FSM is in RECOVERY state
  output logic                         usp_prot_active,                // USP Protocol FSM is in ACTIVE state
  output logic                         usp_prot_enter_l0s,             // USP Protocol FSM is in ENTER_L0S state
  output logic                         usp_prot_l1_block_tlp,          // USP Protocol FSM is in L1_BLOCK_TLP state
  output logic                         usp_prot_l1_wait_last_tlp_ack,  // USP Protocol FSM is in L1_WAIT_LAST_TLP_ACK state
  output logic                         usp_prot_l1_wait_pmdllp_ack,    // USP Protocol FSM is in L1_WAIT_PMDLLP_ACK state
  output logic                         usp_prot_enter_l1,              // USP Protocol FSM is in ENTER_L1 state
  output logic                         usp_prot_l23_block_tlp,         // USP Protocol FSM is in L23_BLOCK_TLP state
  output logic                         usp_prot_l23_wait_last_tlp_ack, // USP Protocol FSM is in L23_WAIT_LAST_TLP_ACK state
  output logic                         usp_prot_l23_wait_pmdllp_ack,   // USP Protocol FSM is in L23_WAIT_PMDLLP_ACK state
  output logic                         usp_prot_enter_l23,             // USP Protocol FSM is in ENTER_L23 state
  output logic                         usp_prot_wait_pmcsr_cpl_sent,   // USP Protocol FSM is in WAIT_PMCSR_CPL_SENT state
  output logic                         usp_prot_wait_last_pmdllp       // USP Protocol FSM is in WAIT_LAST_PMDLLP state
 ,output logic                         usp_prot_wait_dstate_update     // USP Protocol FSM is in WAIT_DSTATE_UPDATE state 
 ,output usp_prot_fsm_state_e          pm_usp_prot_state               // USP Protocol FSM state
);

// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------

usp_prot_fsm_state_e usp_prot_state_r, next_usp_prot_state_b; 

// ----------------------------------------------------------------------------
// Register types
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Wire types
// ----------------------------------------------------------------------------
assign pm_usp_prot_state = usp_prot_state_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin : usp_prot_fsm_sync_PROC
  if(!core_rst_n) begin
    usp_prot_state_r      <= #TP USP_PROT_RST;
  end
  else begin
    if (!upstream_port)
      usp_prot_state_r      <= #TP USP_PROT_RST;
    else
      usp_prot_state_r      <= #TP next_usp_prot_state_b;
  end
end : usp_prot_fsm_sync_PROC 


// A always_ff is used to:
// 1. Initial the FSM with reset state
// 2. Update the state with next_usp_prot_state_b 
always_comb begin : usp_prot_fsm_PROC
    case(usp_prot_state_r)

    USP_PROT_RST: begin 
      if (link_to_prot_to_active)
            next_usp_prot_state_b = USP_PROT_ACTIVE;
      else 
            next_usp_prot_state_b = USP_PROT_RST;
    end

    USP_PROT_RECOVERY: begin 
      if (link_to_prot_to_active)
            next_usp_prot_state_b = USP_PROT_ACTIVE;
      else 
            next_usp_prot_state_b = USP_PROT_RECOVERY;
    end

    USP_PROT_ACTIVE: begin 
      if (pm_enter_recovery)
            next_usp_prot_state_b = USP_PROT_RECOVERY;
      else if (pm_link_wait_dstate_update)
          // Hold when USP LINK FSM waits for dstate update (L1 exit)
            next_usp_prot_state_b =  USP_PROT_ACTIVE;
      // Start L2 entry negotiation
      else if (software_entr_l23)
            next_usp_prot_state_b = USP_PROT_L23_BLOCK_TLP;
      else if (int_start_l1_nego)
            next_usp_prot_state_b = USP_PROT_WAIT_PMCSR_CPL_SENT;
      else if (!pm_l2_entry_flag && pm_enter_l0s)
            next_usp_prot_state_b = USP_PROT_ENTER_L0S;
      else  
            next_usp_prot_state_b = USP_PROT_ACTIVE;
    end



    USP_PROT_L1_BLOCK_TLP: begin 
        if (pm_enter_recovery)
              next_usp_prot_state_b = USP_PROT_RECOVERY;
        else if (pm_block_tlp_ack)
              next_usp_prot_state_b = USP_PROT_L1_WAIT_LAST_TLP_ACK;
        else 
              next_usp_prot_state_b = USP_PROT_L1_BLOCK_TLP;
    end

    USP_PROT_L1_WAIT_LAST_TLP_ACK: begin
        if (pm_enter_recovery)
              next_usp_prot_state_b = USP_PROT_RECOVERY;
        // no TLP being replayed and all TLP's acknowledged and sufficient credits to send maximum sized TLP
        else if (!xdlh_retry_pending && (&xtlh_had_enough_credit))
              next_usp_prot_state_b = pm_dllp_enable ? USP_PROT_L1_WAIT_PMDLLP_ACK : USP_PROT_ENTER_L1;
        else 
              next_usp_prot_state_b = USP_PROT_L1_WAIT_LAST_TLP_ACK;
    end

    USP_PROT_L1_WAIT_PMDLLP_ACK: begin 
        if (pm_enter_recovery)
                next_usp_prot_state_b = USP_PROT_RECOVERY;
        else if (latch_as_entr_l1 && radm_pm_asnak)
                next_usp_prot_state_b =  USP_PROT_ACTIVE; // designed for pipe line of xdlh to be cleared                
        else if (rdlh_rcvd_pm_req_ack && (pm_l1_pcipm_hs_done || pm_l1_aspm_hs_done))
                next_usp_prot_state_b = USP_PROT_WAIT_LAST_PMDLLP;
        else 
                next_usp_prot_state_b = USP_PROT_L1_WAIT_PMDLLP_ACK;
    end
 
    USP_PROT_ENTER_L0S: begin
        if (pm_enter_recovery)
                next_usp_prot_state_b = USP_PROT_RECOVERY;
        else if (l0s_l0s_finish)
                next_usp_prot_state_b = USP_PROT_ACTIVE;                 
        else 
                next_usp_prot_state_b = USP_PROT_ENTER_L0S; 
    end

    USP_PROT_ENTER_L1: begin
        if (pm_enter_recovery)
                next_usp_prot_state_b = pm_entr_dstate_update ? USP_PROT_WAIT_DSTATE_UPDATE : USP_PROT_RECOVERY;
        else if (link_to_prot_l1_finish)
                next_usp_prot_state_b = pm_entr_dstate_update ? USP_PROT_WAIT_DSTATE_UPDATE : USP_PROT_ACTIVE;
        else 
                next_usp_prot_state_b = USP_PROT_ENTER_L1;
    end

    USP_PROT_WAIT_DSTATE_UPDATE: begin
      if (pm_exit_dstate_update)
          next_usp_prot_state_b =  pm_enter_recovery ? USP_PROT_RECOVERY : USP_PROT_ACTIVE; 
      else
          next_usp_prot_state_b =  USP_PROT_WAIT_DSTATE_UPDATE; 
    end

    USP_PROT_L23_BLOCK_TLP: begin
       if (pm_enter_recovery)
                next_usp_prot_state_b   = USP_PROT_RECOVERY;
       else if (pm_block_tlp_ack)
                next_usp_prot_state_b   = USP_PROT_L23_WAIT_LAST_TLP_ACK;
       else 
                next_usp_prot_state_b = USP_PROT_L23_BLOCK_TLP;
    end


    USP_PROT_L23_WAIT_LAST_TLP_ACK: begin
        if (pm_enter_recovery)
                next_usp_prot_state_b = USP_PROT_RECOVERY;
        // no TLP being replayed and all TLP's acknowledged and sufficient credits to send maximum sized TLP
        else if (!xdlh_retry_pending && (&xtlh_had_enough_credit))
                next_usp_prot_state_b = pm_dllp_enable ? USP_PROT_L23_WAIT_PMDLLP_ACK : USP_PROT_ENTER_L23;
        else 
                next_usp_prot_state_b = USP_PROT_L23_WAIT_LAST_TLP_ACK;
    end 

    USP_PROT_L23_WAIT_PMDLLP_ACK: begin
         if (pm_enter_recovery)
                next_usp_prot_state_b   =  USP_PROT_RECOVERY;
         else if (rdlh_rcvd_pm_req_ack && pm_l23_hs_done)
                next_usp_prot_state_b   =  USP_PROT_WAIT_LAST_PMDLLP;
         else 
                next_usp_prot_state_b   =  USP_PROT_L23_WAIT_PMDLLP_ACK;
    end


    USP_PROT_ENTER_L23: begin
        if (pm_enter_recovery)
                next_usp_prot_state_b    = USP_PROT_RECOVERY;
        else if (link_to_prot_l23_finish)
                next_usp_prot_state_b    = USP_PROT_ACTIVE;
        else 
                next_usp_prot_state_b    = USP_PROT_ENTER_L23;
    end

    USP_PROT_WAIT_LAST_PMDLLP: begin
         if (pm_enter_recovery)
                next_usp_prot_state_b    =  USP_PROT_RECOVERY;
         else if ((pm_dllp_ack.dllp_type==NOP_DLLP) && pm_l23_entry_flag)
                next_usp_prot_state_b    = USP_PROT_ENTER_L23;
         else if (pm_dllp_ack.dllp_type==NOP_DLLP)
                next_usp_prot_state_b    = USP_PROT_ENTER_L1;
         else
                next_usp_prot_state_b    = USP_PROT_WAIT_LAST_PMDLLP;
     end

    USP_PROT_WAIT_PMCSR_CPL_SENT: begin
         if (pm_csr_cpl_sent)
                next_usp_prot_state_b = USP_PROT_L1_BLOCK_TLP;
         else
                next_usp_prot_state_b = USP_PROT_WAIT_PMCSR_CPL_SENT;
    end


    default :
      next_usp_prot_state_b = USP_PROT_RST;
  endcase
end : usp_prot_fsm_PROC 


always_ff @(posedge core_clk or negedge core_rst_n) begin : usp_prot_fsm_output_PROC 
  if(!core_rst_n) begin
      usp_prot_rst                    <= #TP 1'b1;
      usp_prot_recovery               <= #TP 1'b0;
      usp_prot_active                 <= #TP 1'b0;
      usp_prot_enter_l0s              <= #TP 1'b0;
      usp_prot_l1_block_tlp           <= #TP 1'b0;
      usp_prot_l1_wait_last_tlp_ack   <= #TP 1'b0;
      usp_prot_l1_wait_pmdllp_ack     <= #TP 1'b0;
      usp_prot_enter_l1               <= #TP 1'b0;
      usp_prot_l23_block_tlp          <= #TP 1'b0;
      usp_prot_l23_wait_last_tlp_ack  <= #TP 1'b0;
      usp_prot_l23_wait_pmdllp_ack    <= #TP 1'b0;
      usp_prot_enter_l23              <= #TP 1'b0;
      usp_prot_wait_pmcsr_cpl_sent    <= #TP 1'b0;
      usp_prot_wait_last_pmdllp       <= #TP 1'b0;
      usp_prot_wait_dstate_update     <= #TP 1'b0;
  end
  else begin
      usp_prot_rst                    <= #TP 1'b1;
      usp_prot_recovery               <= #TP 1'b0;
      usp_prot_active                 <= #TP 1'b0;
      usp_prot_enter_l0s              <= #TP 1'b0;
      usp_prot_l1_block_tlp           <= #TP 1'b0;
      usp_prot_l1_wait_last_tlp_ack   <= #TP 1'b0;
      usp_prot_l1_wait_pmdllp_ack     <= #TP 1'b0;
      usp_prot_enter_l1               <= #TP 1'b0;
      usp_prot_l23_block_tlp          <= #TP 1'b0;
      usp_prot_l23_wait_last_tlp_ack  <= #TP 1'b0;
      usp_prot_l23_wait_pmdllp_ack    <= #TP 1'b0;
      usp_prot_enter_l23              <= #TP 1'b0;
      usp_prot_wait_pmcsr_cpl_sent    <= #TP 1'b0;
      usp_prot_wait_last_pmdllp       <= #TP 1'b0;
      usp_prot_wait_dstate_update     <= #TP 1'b0;


    case(next_usp_prot_state_b)

    USP_PROT_RST: begin
      usp_prot_rst                    <= #TP 1'b1;
    end

    USP_PROT_RECOVERY: begin
      usp_prot_recovery                  <= #TP 1'b1;
    end

    USP_PROT_ACTIVE: begin
      usp_prot_active                 <= #TP 1'b1;
    end

    USP_PROT_L1_BLOCK_TLP: begin
      usp_prot_l1_block_tlp           <= #TP 1'b1;
    end

    USP_PROT_L1_WAIT_LAST_TLP_ACK: begin
      usp_prot_l1_wait_last_tlp_ack   <= #TP 1'b1;
    end

    USP_PROT_L1_WAIT_PMDLLP_ACK: begin
      usp_prot_l1_wait_pmdllp_ack     <= #TP 1'b1;
    end

    USP_PROT_ENTER_L0S: begin
      usp_prot_enter_l0s              <= #TP 1'b1;
    end

    USP_PROT_ENTER_L1: begin
      usp_prot_enter_l1               <= #TP 1'b1;
    end

    USP_PROT_L23_BLOCK_TLP: begin
      usp_prot_l23_block_tlp          <= #TP 1'b1;
    end

    USP_PROT_L23_WAIT_LAST_TLP_ACK: begin
      usp_prot_l23_wait_last_tlp_ack  <= #TP 1'b1;
    end

    USP_PROT_L23_WAIT_PMDLLP_ACK: begin
      usp_prot_l23_wait_pmdllp_ack    <= #TP 1'b1;
   end

    USP_PROT_ENTER_L23: begin
      usp_prot_enter_l23              <= #TP 1'b1;
    end

    USP_PROT_WAIT_LAST_PMDLLP: begin 
      usp_prot_wait_last_pmdllp       <= #TP 1'b1;
    end


    USP_PROT_WAIT_PMCSR_CPL_SENT: begin
      usp_prot_wait_pmcsr_cpl_sent    <= #TP 1'b1;
    end
    USP_PROT_WAIT_DSTATE_UPDATE: begin
      usp_prot_wait_dstate_update     <= #TP 1'b1;
    end
    endcase
  end

end : usp_prot_fsm_output_PROC 

endmodule  // pm_active_usp_prot_fsm 
