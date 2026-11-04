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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_l0s_fsm.sv#2 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contrains an FSM for L0s 
// -----------------------------------------------------------------------------



`include "include/DWC_pcie_ctl_all_defs.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"


module pm_active_l0s_fsm 
import DWC_pcie_pm_pkg::pm_active_l0s_fsm_e;
import DWC_pcie_pm_pkg::L0S_IDLE;
import DWC_pcie_pm_pkg::L0S_BLOCK_TLP;
import DWC_pcie_pm_pkg::L0S_ENTER_L0S;
import DWC_pcie_pm_pkg::L0S_L0S;
import DWC_pcie_pm_pkg::L0S_EXIT;
// parameter
#(
    parameter TP    = `TP
) 
                        (
    // Inputs
    input               core_clk,
    input               core_rst_n,
    input               prot_enter_l0s,             // defined this input 
    input               int_block_tlp_ack,          // ack that no tlp is transmitted
    input               int_l0s_det_idle,           // detect idle state L0s
    input               int_idle_next,              // detect next idle
    input               smlh_in_l0s,
    input               int_l0s_exit,
    // Outputs
    output logic        l0s_l0s_idle,
    output logic        l0s_l0s_block_tlp,
    output logic        l0s_l0s_enter_l0s,
    output logic        l0s_l0s,
    output logic        l0s_l0s_exit,
    output logic        l0s_l0s_finish
    ,output pm_active_l0s_fsm_e pm_l0s_state
);


// ----------------------------------------------------------------------------
// Declarations
// ----------------------------------------------------------------------------

pm_active_l0s_fsm_e state_l0s_r, next_state_l0s_b;
assign pm_l0s_state = state_l0s_r;

always_ff @(posedge core_clk or negedge core_rst_n) begin: pm_active_l0s_fsm_syn_PROC
    if(!core_rst_n)
       state_l0s_r <= #TP L0S_IDLE;
    else begin
       state_l0s_r <= #TP next_state_l0s_b;
    end  
end

// L0s state transition
always_comb begin : pm_active_l0s_fsm_PROC
  if (!prot_enter_l0s) begin
     next_state_l0s_b = L0S_IDLE; 
  end else begin

    case (state_l0s_r)
    L0S_IDLE: begin // IDLE state
     // start ASPM L0s entry
     if (prot_enter_l0s && !l0s_l0s_finish && int_l0s_det_idle)
      next_state_l0s_b =  L0S_BLOCK_TLP;
     else
      next_state_l0s_b =  L0S_IDLE;
    end

    L0S_BLOCK_TLP: begin
     if (!int_l0s_det_idle || int_idle_next)
      next_state_l0s_b =  L0S_IDLE;
     else if (int_block_tlp_ack)
      next_state_l0s_b = L0S_ENTER_L0S;
    else
      next_state_l0s_b = L0S_BLOCK_TLP;
    end

    L0S_ENTER_L0S: begin
     if (int_idle_next)
      next_state_l0s_b = L0S_IDLE;
     else if (smlh_in_l0s)
      next_state_l0s_b = L0S_L0S;
     else
      next_state_l0s_b = L0S_ENTER_L0S;
    end

    L0S_L0S: begin
    // we will exit l0s when
    // 1. there are traffic to transmit
    // 2. when upstream port detect l0s_exit
    // 3. when down stream port detect l0s_exit
    // 5. or upstream port
    // detect all down steam port in L1 and it is enabled for l1
    // entry
    // PS. l1 idle timer will not increase unless the above
    // condition 4 are met
    //    
    // Enter L1 conditions because of ASPM enabled :
    // 1. l1 timer expired in L0s state with upstream port of non
    // switch device
    // 2. l1 timer expired in L0s state with upstream port of
    // swtich device and its downstream ports are all in L0s
    //
    // Exit L0s for switch device:
    // 1. For upstream port of the switch, it exits when one of the
    // dwsp is not in rl0s
    // 2. For donwstream port of the switch, it exits when
    // the upstream port is not in rl0s
     if (int_l0s_exit)
      next_state_l0s_b = L0S_EXIT;
     else
      next_state_l0s_b = L0S_L0S;
    end

    L0S_EXIT: begin
    // In this case LTSSM exits L0S to L0 so we will return to L0 state
    // L1 idle timer will continue to increment (if L1 entry does not depend on L0S)
     if (!smlh_in_l0s)
      next_state_l0s_b = L0S_IDLE;
     else
      next_state_l0s_b = L0S_EXIT;
     end

    default:
      next_state_l0s_b = L0S_IDLE;
    endcase
  end // if(!prot_enter_l0s) begin

end : pm_active_l0s_fsm_PROC


// output driven process
always_ff @(posedge core_clk or negedge core_rst_n) begin : pm_active_l0s_fsm_outputs_PROC
    if (!core_rst_n) begin
       l0s_l0s_idle      <= #TP 1'b0; 
       l0s_l0s_block_tlp <= #TP 1'b0;
       l0s_l0s_enter_l0s <= #TP 1'b0;
       l0s_l0s           <= #TP 1'b0;
       l0s_l0s_exit      <= #TP 1'b0;
       l0s_l0s_finish    <= #TP 1'b0;
    end
    else begin
       l0s_l0s_idle      <= #TP 1'b0; 
       l0s_l0s_block_tlp <= #TP 1'b0;
       l0s_l0s_enter_l0s <= #TP 1'b0;
       l0s_l0s           <= #TP 1'b0;
       l0s_l0s_exit      <= #TP 1'b0;
       l0s_l0s_finish    <= #TP 1'b0;
     case (next_state_l0s_b)
     L0S_IDLE: begin
       l0s_l0s_idle      <= #TP 1'b1; 
       if(!l0s_l0s_idle) begin
         l0s_l0s_finish  <= #TP 1'b1;
       end
     end

     L0S_BLOCK_TLP: begin
       l0s_l0s_block_tlp <= #TP 1'b1;
     end

     L0S_ENTER_L0S: begin
       l0s_l0s_enter_l0s <= #TP 1'b1;
     end

     L0S_L0S: begin
       l0s_l0s           <= #TP 1'b1;
     end

     L0S_EXIT: begin
       l0s_l0s_exit      <= #TP 1'b1;
     end
     endcase
    end
end : pm_active_l0s_fsm_outputs_PROC
endmodule
